"""Semantic dedup — merges near-duplicate memory entries (Phase 4.2).

Ported in spirit from memory-os ``scripts/semantic_dedup.py``. Depends on the
Phase 5 vector embeddings: two entries are considered duplicates when the
cosine similarity of their embeddings is ``>= threshold`` (default 0.92).

Dedup runs *within* a namespace only — entries from different projects are
never merged, which keeps the cross-project isolation guarantee. Within a
namespace it is a greedy single-pass clustering:

  1. Order live, non-pinned entries by value: access_count DESC, then oldest
     first (ts ASC), then id — so the most-used/original entry anchors a
     cluster and is the one kept.
  2. Walk the list; each entry is compared to the existing cluster
     representatives. If it is ``>= threshold`` similar to one, it is a
     duplicate of that representative; otherwise it becomes a new
     representative.
  3. Each duplicate is soft-deleted (``forgotten = 1``), its ``access_count``
     is folded into the surviving canonical entry, the merge is recorded in
     ``audit`` (action ``dedup``), and the duplicate is dropped from the
     vector index so recall stays consistent.

Embeddings come from the same provider chain as recall (Ollama → OpenRouter);
an entry whose content cannot be embedded is skipped, never merged. ``embed_fn``
is injectable for deterministic testing.

Run via the CLI: ``superagent-memory dedup [--dry-run] [--threshold T] [--namespace NS]``.
"""

from __future__ import annotations

import sqlite3
from dataclasses import dataclass
from typing import Callable

from .. import db

Vector = list[float]
EmbedFn = Callable[[str], Vector]

DEFAULT_THRESHOLD = 0.92


@dataclass(frozen=True)
class Merge:
    duplicate_id: str
    canonical_id: str
    namespace: str
    similarity: float

    def to_dict(self) -> dict:
        return {
            "duplicate_id": self.duplicate_id,
            "canonical_id": self.canonical_id,
            "namespace": self.namespace,
            "similarity": round(self.similarity, 4),
        }


@dataclass(frozen=True)
class DedupResult:
    scanned: int
    merged: int
    clusters: int
    merges: tuple[Merge, ...]
    dry_run: bool
    threshold: float
    skipped_unembeddable: int

    def to_dict(self) -> dict:
        return {
            "scanned": self.scanned,
            "merged": self.merged,
            "clusters": self.clusters,
            "merges": [m.to_dict() for m in self.merges],
            "dry_run": self.dry_run,
            "threshold": self.threshold,
            "skipped_unembeddable": self.skipped_unembeddable,
        }


def dedup(
    conn: sqlite3.Connection,
    *,
    namespace: str | None = None,
    threshold: float = DEFAULT_THRESHOLD,
    dry_run: bool = False,
    embed_fn: EmbedFn | None = None,
) -> DedupResult:
    """Merge near-duplicate entries. Returns a :class:`DedupResult` summary.

    ``namespace`` limits the pass to one project store; ``None`` dedups each
    namespace independently. ``dry_run`` reports the merges it would make
    without mutating anything.
    """
    if not 0.0 < threshold <= 1.0:
        raise ValueError("threshold must be in (0, 1]")

    fn = embed_fn or _default_embed

    namespaces = [namespace] if namespace is not None else _all_namespaces(conn)

    cosine = _import_cosine()
    scanned = 0
    skipped = 0
    clusters = 0
    merges: list[Merge] = []

    for ns in namespaces:
        rows = conn.execute(
            """
            SELECT id, content, access_count
            FROM entries
            WHERE namespace = ? AND forgotten = 0 AND pinned = 0
            ORDER BY access_count DESC, ts ASC, id ASC
            """,
            (ns,),
        ).fetchall()

        embedded: list[tuple[str, Vector]] = []
        for r in rows:
            try:
                embedded.append((r["id"], fn(r["content"])))
            except Exception:
                skipped += 1
        scanned += len(embedded)

        reps: list[tuple[str, Vector]] = []  # (canonical_id, vector)
        for eid, vec in embedded:
            best_id: str | None = None
            best_sim = -1.0
            for rep_id, rep_vec in reps:
                sim = cosine(vec, rep_vec)
                if sim > best_sim:
                    best_sim, best_id = sim, rep_id
            if best_id is not None and best_sim >= threshold:
                merges.append(Merge(duplicate_id=eid, canonical_id=best_id, namespace=ns, similarity=best_sim))
            else:
                reps.append((eid, vec))
                clusters += 1

    if not dry_run and merges:
        _apply_merges(conn, merges)

    return DedupResult(
        scanned=scanned,
        merged=len(merges),
        clusters=clusters,
        merges=tuple(merges),
        dry_run=dry_run,
        threshold=threshold,
        skipped_unembeddable=skipped,
    )


def _apply_merges(conn: sqlite3.Connection, merges: list[Merge]) -> None:
    from ..vector import delete_entry  # best-effort index cleanup

    for m in merges:
        # Fold the duplicate's access_count into the survivor so the canonical
        # entry inherits the combined usage signal (it stays out of decay).
        conn.execute(
            "UPDATE entries SET access_count = access_count + "
            "COALESCE((SELECT access_count FROM entries WHERE id = ?), 0) "
            "WHERE id = ?",
            (m.duplicate_id, m.canonical_id),
        )
        conn.execute("UPDATE entries SET forgotten = 1 WHERE id = ?", (m.duplicate_id,))
        db._audit(
            conn,
            "dedup",
            m.duplicate_id,
            m.namespace,
            {"merged_into": m.canonical_id, "similarity": round(m.similarity, 4)},
        )
        delete_entry(entry_id=m.duplicate_id)


def _all_namespaces(conn: sqlite3.Connection) -> list[str]:
    rows = conn.execute(
        "SELECT DISTINCT namespace FROM entries WHERE forgotten = 0 AND pinned = 0 ORDER BY namespace"
    ).fetchall()
    return [r["namespace"] for r in rows]


def _default_embed(text: str) -> Vector:
    from ..vector import embed as embed_mod

    return embed_mod.embed(text)


def _import_cosine():
    from ..vector.store import cosine

    return cosine
