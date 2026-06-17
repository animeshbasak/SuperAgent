"""Compress-Cache-Retrieve (CCR) — reversible compression for MCP context.

Bulky content is replaced in-context with a sentinel token; the LLM can
retrieve the original on demand via the ``memory_retrieve`` MCP tool.

Sentinel format: ``ccr:<12-char-hex-hash>:<dropped-int>``

Example: ``ccr:a3f9c2d1e84b:1``
"""

from __future__ import annotations

import hashlib
import re
import sqlite3
import time
from typing import Tuple

_TOKEN_RE = re.compile(r"^ccr:([0-9a-f]+):(\d+)$", re.IGNORECASE)


def make_token(hash_: str, dropped: int) -> str:
    """Return the canonical sentinel string for a cached entry."""
    return f"ccr:{hash_}:{dropped}"


def parse_token(s: str) -> Tuple[str, int] | None:
    """Parse a CCR sentinel token; return (hash, dropped) or None if malformed.

    Liberal: accepts any hex-length hash and any non-negative dropped int so
    tokens emitted by memory_os/compress (same format) are accepted.
    """
    m = _TOKEN_RE.match(s.strip())
    if m is None:
        return None
    return m.group(1), int(m.group(2))


class CCRStore:
    """Wraps a sqlite3 connection for CCR cache operations."""

    def __init__(self, conn: sqlite3.Connection) -> None:
        self._conn = conn

    def cache(
        self,
        original: str,
        compressed: str | None = None,
        kind: str = "text",
        dropped: int = 0,
        ttl_seconds: int = 1800,
    ) -> str:
        """Store ``original`` in the CCR cache and return its sentinel token.

        Uses sha256(original).hexdigest()[:12] as the key.  Calling cache()
        twice with the same content is idempotent — the row is upserted.
        """
        hash_ = hashlib.sha256(original.encode("utf-8")).hexdigest()[:12]
        now = int(time.time())
        self._conn.execute(
            """
            INSERT INTO ccr_cache
                (hash, original_content, compressed_content, kind, dropped, created_ts, ttl_seconds, retrieval_count)
            VALUES (?, ?, ?, ?, ?, ?, ?, 0)
            ON CONFLICT(hash) DO UPDATE SET
                original_content   = excluded.original_content,
                compressed_content = excluded.compressed_content,
                kind               = excluded.kind,
                dropped            = excluded.dropped,
                created_ts         = excluded.created_ts,
                ttl_seconds        = excluded.ttl_seconds
            """,
            (hash_, original, compressed, kind, dropped, now, ttl_seconds),
        )
        return make_token(hash_, dropped)

    def retrieve(self, token_or_hash: str, query: str | None = None) -> dict | None:
        """Fetch an entry by token or bare hash.

        Increments retrieval_count.  If ``query`` is given, filters to lines
        that contain ALL query terms (case-insensitive substring, AND logic).
        Returns None when the entry is missing or expired.
        """
        parsed = parse_token(token_or_hash)
        hash_ = parsed[0] if parsed is not None else token_or_hash.strip()

        row = self._conn.execute(
            "SELECT hash, original_content, kind, dropped, created_ts, ttl_seconds, retrieval_count "
            "FROM ccr_cache WHERE hash = ?",
            (hash_,),
        ).fetchone()

        if row is None:
            return None

        if self.is_expired(row, int(time.time())):
            return None

        self._conn.execute(
            "UPDATE ccr_cache SET retrieval_count = retrieval_count + 1 WHERE hash = ?",
            (hash_,),
        )

        original = row["original_content"]
        truncated = False

        if query:
            terms = [t.lower() for t in query.split() if t.strip()]
            if terms:
                matching = [
                    line for line in original.splitlines()
                    if all(t in line.lower() for t in terms)
                ]
                content = "\n".join(matching)
                truncated = content != original
            else:
                content = original
        else:
            content = original

        return {
            "hash": row["hash"],
            "kind": row["kind"],
            "content": content,
            "truncated_by_query": truncated,
        }

    @staticmethod
    def is_expired(row, now: int) -> bool:
        """Return True if the row has passed its TTL.

        ``ttl_seconds <= 0`` means never expire.
        """
        ttl = row["ttl_seconds"]
        if ttl is None or ttl <= 0:
            return False
        return (row["created_ts"] + ttl) < now

    def prune_expired(self, now: int | None = None) -> int:
        """Delete all expired rows. Returns number of rows deleted."""
        now = now if now is not None else int(time.time())
        cur = self._conn.execute(
            "DELETE FROM ccr_cache WHERE ttl_seconds > 0 AND (created_ts + ttl_seconds) < ?",
            (now,),
        )
        return cur.rowcount
