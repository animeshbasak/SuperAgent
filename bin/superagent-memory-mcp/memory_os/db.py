"""SQLite storage with FTS5 for memory entries.

Single file at ~/.superagent/memory-os/memory.db. Tables:

  entries          — main store (id, namespace, kind, content, ts, access_ct, pinned, forgotten, tags)
  entries_fts      — FTS5 virtual table over content
  audit            — append-only log of writes/deletes/sanitization events
  pins             — pointer table: entry_id → workspace pin path

Idempotent schema: CREATE IF NOT EXISTS everywhere; safe to call connect()
on every server start.
"""

from __future__ import annotations

import json
import os
import re
import sqlite3
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

DEFAULT_DB_DIR = Path(os.environ.get("SUPERAGENT_MEMORY_HOME", "~/.superagent/memory-os")).expanduser()
DEFAULT_DB_PATH = DEFAULT_DB_DIR / "memory.db"

KINDS = ("fact", "decision", "feedback", "snippet", "session")

# Namespaces become filename components (pin files) and SQL parameters, so the
# alphabet is locked down: no path separators, no traversal, no control chars.
# Covers the 16-hex git-root hashes, `__global__`, and readable custom names.
_NAMESPACE_RE = re.compile(r"^[A-Za-z0-9_.-]{1,64}$")


def validate_namespace(namespace: str) -> str:
    """Return ``namespace`` if it is safe to store; raise ValueError otherwise."""
    if not _NAMESPACE_RE.match(namespace) or ".." in namespace:
        raise ValueError(
            f"invalid namespace {namespace!r}: must match [A-Za-z0-9_.-]{{1,64}} without '..'"
        )
    return namespace


@dataclass(frozen=True)
class Entry:
    id: str
    namespace: str
    kind: str
    content: str
    ts: float
    access_count: int
    pinned: bool
    forgotten: bool
    tags: tuple[str, ...]
    score: float | None = None  # populated by recall queries

    def to_dict(self) -> dict:
        d = {
            "id": self.id,
            "namespace": self.namespace,
            "kind": self.kind,
            "content": self.content,
            "ts": self.ts,
            "access_count": self.access_count,
            "pinned": self.pinned,
            "forgotten": self.forgotten,
            "tags": list(self.tags),
        }
        if self.score is not None:
            d["score"] = self.score
        return d


def connect(db_path: Path | None = None) -> sqlite3.Connection:
    """Open the memory DB, creating the schema on first use."""
    path = db_path or DEFAULT_DB_PATH
    path.parent.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(path, isolation_level=None)  # autocommit
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA foreign_keys = ON")
    _init_schema(conn)
    return conn


def _init_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS entries (
            id           TEXT PRIMARY KEY,
            namespace    TEXT NOT NULL,
            kind         TEXT NOT NULL,
            content      TEXT NOT NULL,
            ts           REAL NOT NULL,
            access_count INTEGER NOT NULL DEFAULT 0,
            last_access  REAL NOT NULL DEFAULT 0,
            pinned       INTEGER NOT NULL DEFAULT 0,
            forgotten    INTEGER NOT NULL DEFAULT 0,
            tags_json    TEXT NOT NULL DEFAULT '[]'
        );

        CREATE INDEX IF NOT EXISTS idx_entries_ns_ts    ON entries(namespace, ts DESC);
        CREATE INDEX IF NOT EXISTS idx_entries_ns_kind  ON entries(namespace, kind);
        CREATE INDEX IF NOT EXISTS idx_entries_pinned   ON entries(namespace, pinned) WHERE pinned = 1;

        CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts USING fts5(
            content,
            content='entries',
            content_rowid='rowid',
            tokenize='porter unicode61'
        );

        CREATE TRIGGER IF NOT EXISTS entries_ai AFTER INSERT ON entries BEGIN
            INSERT INTO entries_fts(rowid, content) VALUES (new.rowid, new.content);
        END;
        CREATE TRIGGER IF NOT EXISTS entries_ad AFTER DELETE ON entries BEGIN
            INSERT INTO entries_fts(entries_fts, rowid, content) VALUES('delete', old.rowid, old.content);
        END;
        CREATE TRIGGER IF NOT EXISTS entries_au AFTER UPDATE ON entries BEGIN
            INSERT INTO entries_fts(entries_fts, rowid, content) VALUES('delete', old.rowid, old.content);
            INSERT INTO entries_fts(rowid, content) VALUES (new.rowid, new.content);
        END;

        CREATE TABLE IF NOT EXISTS audit (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            ts          REAL NOT NULL,
            action      TEXT NOT NULL,
            entry_id    TEXT,
            namespace   TEXT,
            payload     TEXT
        );

        CREATE TABLE IF NOT EXISTS pins (
            entry_id    TEXT PRIMARY KEY REFERENCES entries(id) ON DELETE CASCADE,
            pinned_path TEXT NOT NULL,
            ts          REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS counters (
            name        TEXT NOT NULL,
            namespace   TEXT NOT NULL DEFAULT '',
            count       INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (name, namespace)
        );

        CREATE TABLE IF NOT EXISTS schema_version (version INTEGER PRIMARY KEY);
        INSERT OR IGNORE INTO schema_version (version) VALUES (1);

        CREATE TABLE IF NOT EXISTS ccr_cache (
            hash              TEXT PRIMARY KEY,
            original_content  TEXT NOT NULL,
            compressed_content TEXT,
            kind              TEXT,
            dropped           INTEGER DEFAULT 0,
            created_ts        INTEGER NOT NULL,
            ttl_seconds       INTEGER DEFAULT 1800,
            retrieval_count   INTEGER DEFAULT 0
        );
        """
    )
    _migrate(conn)


def _migrate(conn: sqlite3.Connection) -> None:
    """Apply idempotent column migrations to a pre-existing entries table.

    v1 → v2: add ``last_access`` (REAL). SQLite cannot ALTER ... ADD COLUMN
    with a non-constant default, so we add it with default 0 then backfill
    each row's last_access from its creation ts.
    """
    cols = {row["name"] for row in conn.execute("PRAGMA table_info(entries)").fetchall()}
    if "last_access" not in cols:
        conn.execute("ALTER TABLE entries ADD COLUMN last_access REAL NOT NULL DEFAULT 0")

    # Backfill any rows (fresh or migrated) that never recorded an access time.
    conn.execute("UPDATE entries SET last_access = ts WHERE last_access = 0")
    conn.execute("INSERT OR IGNORE INTO schema_version (version) VALUES (2)")


def write_entry(
    conn: sqlite3.Connection,
    *,
    namespace: str,
    kind: str,
    content: str,
    tags: Iterable[str] = (),
) -> Entry:
    if kind not in KINDS:
        raise ValueError(f"unknown kind {kind!r}; expected one of {KINDS}")
    validate_namespace(namespace)

    entry_id = uuid.uuid4().hex[:16]
    ts = time.time()
    tags_tuple = tuple(tags)

    conn.execute(
        "INSERT INTO entries (id, namespace, kind, content, ts, last_access, tags_json) "
        "VALUES (?, ?, ?, ?, ?, ?, ?)",
        (entry_id, namespace, kind, content, ts, ts, json.dumps(tags_tuple)),
    )
    _audit(conn, "write", entry_id, namespace, {"kind": kind, "tag_count": len(tags_tuple)})

    return Entry(
        id=entry_id,
        namespace=namespace,
        kind=kind,
        content=content,
        ts=ts,
        access_count=0,
        pinned=False,
        forgotten=False,
        tags=tags_tuple,
    )


def recall(
    conn: sqlite3.Connection,
    *,
    namespace: str,
    query: str,
    limit: int = 10,
) -> list[Entry]:
    """BM25-ranked FTS recall within a namespace.

    Returns entries ordered by FTS rank ascending (lower = better match in
    SQLite's bm25() output). Each hit's ``score`` is the negated rank so
    consumers can sort descending for "most relevant first".

    Side effect: bumps access_count on every returned row.
    """
    if not query.strip():
        return []

    # Escape FTS5 query — wrap in quotes to treat as phrase, but allow
    # standard FTS5 operators when caller passes a structured query.
    safe_query = _normalize_fts_query(query)

    rows = conn.execute(
        """
        SELECT
            e.id, e.namespace, e.kind, e.content, e.ts, e.access_count,
            e.pinned, e.forgotten, e.tags_json,
            bm25(entries_fts) AS rank
        FROM entries_fts
        JOIN entries e ON e.rowid = entries_fts.rowid
        WHERE entries_fts MATCH ?
          AND e.namespace = ?
          AND e.forgotten = 0
        ORDER BY rank
        LIMIT ?
        """,
        (safe_query, namespace, limit),
    ).fetchall()

    if not rows:
        return []

    ids = [row["id"] for row in rows]
    conn.execute(
        f"UPDATE entries SET access_count = access_count + 1, last_access = ? "
        f"WHERE id IN ({','.join('?' * len(ids))})",
        [time.time(), *ids],
    )

    return [_row_to_entry(row, score=-row["rank"]) for row in rows]


def get_entries_by_ids(
    conn: sqlite3.Connection,
    *,
    namespace: str,
    ids: Iterable[str],
) -> dict[str, Entry]:
    """Fetch live (non-forgotten) entries by id within a namespace.

    Returns a ``{id: Entry}`` map (missing/forgotten ids are simply absent).
    Used by hybrid recall to hydrate vector-only hits that FTS didn't surface.
    """
    id_list = [i for i in ids]
    if not id_list:
        return {}
    rows = conn.execute(
        f"""
        SELECT id, namespace, kind, content, ts, access_count, pinned, forgotten, tags_json
        FROM entries
        WHERE namespace = ? AND forgotten = 0
          AND id IN ({','.join('?' * len(id_list))})
        """,
        [namespace, *id_list],
    ).fetchall()
    return {row["id"]: _row_to_entry(row) for row in rows}


def list_entries(
    conn: sqlite3.Connection,
    *,
    namespace: str,
    kind: str | None = None,
    since: float | None = None,
    limit: int = 50,
) -> list[Entry]:
    clauses = ["namespace = ?", "forgotten = 0"]
    params: list = [namespace]
    if kind:
        clauses.append("kind = ?")
        params.append(kind)
    if since is not None:
        clauses.append("ts >= ?")
        params.append(since)
    params.append(limit)

    rows = conn.execute(
        f"""
        SELECT id, namespace, kind, content, ts, access_count, pinned, forgotten, tags_json
        FROM entries
        WHERE {' AND '.join(clauses)}
        ORDER BY ts DESC
        LIMIT ?
        """,
        params,
    ).fetchall()
    return [_row_to_entry(row) for row in rows]


def pin_entry(conn: sqlite3.Connection, entry_id: str, pin_dir: Path) -> Path:
    row = conn.execute(
        "SELECT namespace, content, kind FROM entries WHERE id = ? AND forgotten = 0",
        (entry_id,),
    ).fetchone()
    if not row:
        raise KeyError(entry_id)

    pin_dir.mkdir(parents=True, exist_ok=True)
    pin_path = pin_dir / f"{row['namespace']}__{entry_id}.md"
    # Belt-and-braces: write_entry validates namespaces, but never write a pin
    # outside the pin dir even if a hostile row predates validation.
    if pin_path.resolve().parent != pin_dir.resolve():
        raise ValueError(f"pin path escapes pin dir: {pin_path}")
    pin_path.write_text(
        f"<!-- pinned from superagent-memory entry {entry_id} ({row['kind']}) -->\n{row['content']}\n",
        encoding="utf-8",
    )
    conn.execute("UPDATE entries SET pinned = 1 WHERE id = ?", (entry_id,))
    conn.execute(
        "INSERT OR REPLACE INTO pins (entry_id, pinned_path, ts) VALUES (?, ?, ?)",
        (entry_id, str(pin_path), time.time()),
    )
    _audit(conn, "pin", entry_id, row["namespace"], {"path": str(pin_path)})
    return pin_path


def forget_entries(
    conn: sqlite3.Connection,
    *,
    namespace: str,
    id_or_pattern: str,
) -> list[str]:
    """Soft-delete: mark entries with forgotten=1. Audit row records the action.

    ``id_or_pattern`` is treated as an exact id first; if no row matches and
    the string contains '%' or '_', it is interpreted as a SQL LIKE pattern
    over content.
    """
    direct = conn.execute(
        "SELECT id FROM entries WHERE id = ? AND namespace = ? AND forgotten = 0",
        (id_or_pattern, namespace),
    ).fetchall()
    if direct:
        ids = [row["id"] for row in direct]
    elif any(ch in id_or_pattern for ch in "%_"):
        # Guard against mass-forget: a pattern must carry at least 3 literal
        # characters ("%", "_%_", etc. would soft-wipe the whole namespace —
        # a cheap prompt-injection target).
        literal = id_or_pattern.replace("%", "").replace("_", "").strip()
        if len(literal) < 3:
            return []
        rows = conn.execute(
            "SELECT id FROM entries WHERE namespace = ? AND content LIKE ? AND forgotten = 0",
            (namespace, id_or_pattern),
        ).fetchall()
        ids = [row["id"] for row in rows]
    else:
        return []

    if not ids:
        return []

    conn.execute(
        f"UPDATE entries SET forgotten = 1 WHERE id IN ({','.join('?' * len(ids))})",
        ids,
    )
    for entry_id in ids:
        _audit(conn, "forget", entry_id, namespace, {"by": "pattern" if id_or_pattern != entry_id else "id"})
    return ids


def telemetry_enabled() -> bool:
    """Local-only counters; on by default, opt out with SUPERAGENT_MEMORY_TELEMETRY=off."""
    return os.environ.get("SUPERAGENT_MEMORY_TELEMETRY", "on").strip().lower() not in (
        "off", "0", "false", "no",
    )


def bump_counter(conn: sqlite3.Connection, name: str, namespace: str = "", by: int = 1) -> None:
    """Increment a local usage counter. No-op when telemetry is off or by <= 0.

    Counters never leave the SQLite file — they exist so `superagent-memory
    stats` can show usage without any network call.
    """
    if by <= 0 or not telemetry_enabled():
        return
    conn.execute(
        "INSERT INTO counters (name, namespace, count) VALUES (?, ?, ?) "
        "ON CONFLICT(name, namespace) DO UPDATE SET count = count + excluded.count",
        (name, namespace, by),
    )


def stats(conn: sqlite3.Connection) -> dict:
    """Aggregate store stats + usage counters for `superagent-memory stats`."""
    entries = conn.execute(
        """
        SELECT
            COUNT(*)                                        AS total,
            SUM(CASE WHEN forgotten = 0 THEN 1 ELSE 0 END)  AS live,
            SUM(CASE WHEN forgotten = 1 THEN 1 ELSE 0 END)  AS archived,
            SUM(CASE WHEN pinned = 1 THEN 1 ELSE 0 END)     AS pinned,
            COUNT(DISTINCT namespace)                       AS namespaces
        FROM entries
        """
    ).fetchone()
    by_kind = {
        row["kind"]: row["n"]
        for row in conn.execute(
            "SELECT kind, COUNT(*) AS n FROM entries WHERE forgotten = 0 GROUP BY kind ORDER BY n DESC"
        )
    }
    counters = {}
    for row in conn.execute("SELECT name, SUM(count) AS n FROM counters GROUP BY name ORDER BY name"):
        counters[row["name"]] = row["n"]
    return {
        "entries": {
            "total": entries["total"] or 0,
            "live": entries["live"] or 0,
            "archived": entries["archived"] or 0,
            "pinned": entries["pinned"] or 0,
            "namespaces": entries["namespaces"] or 0,
            "by_kind": by_kind,
        },
        "counters": counters,
        "telemetry": "on" if telemetry_enabled() else "off",
    }


def _audit(conn: sqlite3.Connection, action: str, entry_id: str | None, namespace: str | None, payload: dict) -> None:
    conn.execute(
        "INSERT INTO audit (ts, action, entry_id, namespace, payload) VALUES (?, ?, ?, ?, ?)",
        (time.time(), action, entry_id, namespace, json.dumps(payload)),
    )


def _row_to_entry(row: sqlite3.Row, score: float | None = None) -> Entry:
    return Entry(
        id=row["id"],
        namespace=row["namespace"],
        kind=row["kind"],
        content=row["content"],
        ts=row["ts"],
        access_count=row["access_count"],
        pinned=bool(row["pinned"]),
        forgotten=bool(row["forgotten"]),
        tags=tuple(json.loads(row["tags_json"])),
        score=score,
    )


def _normalize_fts_query(query: str) -> str:
    """Escape user input for FTS5 MATCH.

    FTS5 query syntax allows operators (AND, OR, NOT, NEAR, ", *, -, :).
    When the user passes a freeform query, naive insertion can fail. We
    wrap each whitespace-separated token in double-quotes (FTS5 phrase
    syntax) which neutralizes operator interpretation while preserving
    multi-token matching.
    """
    tokens = [t for t in query.split() if t.strip()]
    if not tokens:
        return ""
    return " ".join(f'"{t.replace(chr(34), "")}"' for t in tokens)
