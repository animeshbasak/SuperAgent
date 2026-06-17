"""The 5 memory tools exposed via MCP.

Each function returns plain dicts (JSON-serializable) and accepts a single
connection argument so the same code paths can be unit-tested against an
in-memory SQLite DB without spinning up an MCP transport.
"""

from __future__ import annotations

import sqlite3
import time
from pathlib import Path
from typing import Iterable

from . import db, vector
from .ccr import CCRStore
from .sanitize import sanitize

PIN_DIR_DEFAULT = db.DEFAULT_DB_DIR / "pinned"

# How many extra candidates each leg fetches before fusion. Over-fetching lets
# RRF promote a doc that is, say, #2 by vectors but #25 by FTS into the top-k.
HYBRID_FANOUT = 3


def memory_recall(
    conn: sqlite3.Connection,
    *,
    query: str,
    limit: int = 10,
    namespace: str,
    embed_fn=None,
) -> dict:
    """Return ranked memory hits in the given namespace.

    Default: BM25-ranked FTS recall (``mode="fts"``). When
    ``SUPERAGENT_MEMORY_VECTOR`` is on, blends FTS with vector cosine results
    via reciprocal rank fusion (``mode="hybrid"``) so synonym/semantic queries
    surface hits that pure keyword search misses. ``embed_fn`` is injectable
    for tests; production uses the Ollama→OpenRouter chain.
    """
    db.bump_counter(conn, "recall", namespace)
    if not vector.is_enabled():
        entries = db.recall(conn, namespace=namespace, query=query, limit=limit)
        return {
            "namespace": namespace,
            "query": query,
            "mode": "fts",
            "count": len(entries),
            "hits": [e.to_dict() for e in entries],
        }

    fan = max(limit * HYBRID_FANOUT, limit)
    fts_entries = db.recall(conn, namespace=namespace, query=query, limit=fan)
    vec_hits = vector.vector_search(query=query, namespace=namespace, limit=fan, embed_fn=embed_fn)

    fts_ids = [e.id for e in fts_entries]
    vec_ids = [h.id for h in vec_hits]

    if vec_ids:
        ranked = vector.reciprocal_rank_fusion(fts_ids, vec_ids)[:limit]
    else:
        # Vector backend unreachable → behave exactly like FTS-only recall.
        ranked = fts_ids[:limit]

    by_id = {e.id: e for e in fts_entries}
    missing = [i for i in ranked if i not in by_id]
    if missing:
        by_id.update(db.get_entries_by_ids(conn, namespace=namespace, ids=missing))

    hits = [by_id[i].to_dict() for i in ranked if i in by_id]
    return {
        "namespace": namespace,
        "query": query,
        "mode": "hybrid",
        "count": len(hits),
        "hits": hits,
    }


def memory_write(
    conn: sqlite3.Connection,
    *,
    content: str,
    kind: str,
    namespace: str,
    tags: Iterable[str] = (),
    embed_fn=None,
) -> dict:
    """Sanitize then store. Refuse storage on high-density attacks.

    When ``SUPERAGENT_MEMORY_VECTOR`` is on, the sanitized content is also
    embedded and upserted into the vector index (best-effort — a failed embed
    never fails the write; ``indexed`` reports whether it succeeded).
    """
    result = sanitize(content)
    if result.rejected:
        return {
            "ok": False,
            "rejected": True,
            "reason": "high-density-attack",
            "hits": list(result.hits),
        }

    entry = db.write_entry(
        conn,
        namespace=namespace,
        kind=kind,
        content=result.text,
        tags=tags,
    )

    db.bump_counter(conn, "write", namespace)
    out = {
        "ok": True,
        "id": entry.id,
        "namespace": entry.namespace,
        "sanitized": not result.clean,
        "sanitize_hits": list(result.hits),
    }
    if vector.is_enabled():
        out["indexed"] = vector.index_entry(
            entry_id=entry.id,
            content=result.text,
            namespace=namespace,
            embed_fn=embed_fn,
        )
    return out


def memory_list(
    conn: sqlite3.Connection,
    *,
    namespace: str,
    kind: str | None = None,
    since: float | None = None,
    limit: int = 50,
) -> dict:
    entries = db.list_entries(conn, namespace=namespace, kind=kind, since=since, limit=limit)
    return {
        "namespace": namespace,
        "count": len(entries),
        "entries": [e.to_dict() for e in entries],
    }


def memory_pin(
    conn: sqlite3.Connection,
    *,
    entry_id: str,
    pin_dir: Path = PIN_DIR_DEFAULT,
) -> dict:
    try:
        path = db.pin_entry(conn, entry_id, pin_dir)
    except KeyError:
        return {"ok": False, "reason": "not-found", "id": entry_id}
    return {"ok": True, "id": entry_id, "pinned_path": str(path)}


def memory_forget(
    conn: sqlite3.Connection,
    *,
    id_or_pattern: str,
    namespace: str,
) -> dict:
    deleted = db.forget_entries(conn, namespace=namespace, id_or_pattern=id_or_pattern)
    if deleted and vector.is_enabled():
        for entry_id in deleted:
            vector.delete_entry(entry_id=entry_id)
    return {
        "ok": True,
        "deleted": len(deleted),
        "ids": deleted,
        "namespace": namespace,
    }


def memory_retrieve(
    conn: sqlite3.Connection,
    *,
    token: str,
    query: str | None = None,
) -> dict:
    """Retrieve the original content for a CCR sentinel token or bare hash.

    Returns the entry dict on success, or ``{ok: False, reason: ...}`` when
    the token is not found or has expired.
    """
    store = CCRStore(conn)
    result = store.retrieve(token, query=query)
    if result is None:
        return {"ok": False, "reason": "not-found-or-expired", "token": token}
    return {"ok": True, **result}


# Helpers for the MCP server layer ---------------------------------------------


def now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
