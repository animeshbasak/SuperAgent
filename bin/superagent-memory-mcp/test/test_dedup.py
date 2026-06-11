"""Phase 4.2 semantic-dedup tests.

Hermetic: an injected deterministic ``embed_fn`` (bag-of-words over a tiny
vocab) stands in for the real Ollama/OpenRouter chain, so no network and no
Qdrant. Near-duplicate content maps to identical/adjacent vectors, exact
duplicates to identical vectors.
"""

from __future__ import annotations

import tempfile
from pathlib import Path

import pytest

from memory_os import db, vector
from memory_os.jobs import dedup as dedup_job


@pytest.fixture
def conn():
    tmp = Path(tempfile.mkdtemp()) / "memory.db"
    c = db.connect(tmp)
    yield c
    c.close()


@pytest.fixture(autouse=True)
def fresh_store():
    vector.reset_store()
    yield
    vector.reset_store()


VOCAB = ["postgres", "database", "prod", "redis", "cache", "auth", "login", "bug"]
SYNONYMS = {"db": "database", "production": "prod", "signin": "login"}


def fake_embed(text: str) -> list[float]:
    words = [SYNONYMS.get(w, w) for w in text.lower().replace(",", " ").split()]
    return [float(words.count(term)) for term in VOCAB]


def _live(conn, namespace="ns"):
    return db.list_entries(conn, namespace=namespace, limit=100)


# --- core behaviour ----------------------------------------------------------

def test_exact_duplicates_merge(conn):
    a = db.write_entry(conn, namespace="ns", kind="fact", content="postgres is the prod database")
    b = db.write_entry(conn, namespace="ns", kind="fact", content="postgres is the prod database")
    res = dedup_job.dedup(conn, namespace="ns", embed_fn=fake_embed)
    assert res.merged == 1
    assert res.clusters == 1
    survivors = {e.id for e in _live(conn)}
    # Exactly one of the pair survives.
    assert len({a.id, b.id} & survivors) == 1


def test_distinct_entries_not_merged(conn):
    db.write_entry(conn, namespace="ns", kind="fact", content="postgres prod database")
    db.write_entry(conn, namespace="ns", kind="fact", content="redis cache layer")
    res = dedup_job.dedup(conn, namespace="ns", embed_fn=fake_embed)
    assert res.merged == 0
    assert res.clusters == 2
    assert len(_live(conn)) == 2


def test_canonical_keeps_most_accessed(conn):
    keep = db.write_entry(conn, namespace="ns", kind="fact", content="postgres prod database")
    drop = db.write_entry(conn, namespace="ns", kind="fact", content="postgres prod database")
    # Bump access on `keep` so it anchors the cluster.
    conn.execute("UPDATE entries SET access_count = 5 WHERE id = ?", (keep.id,))
    dedup_job.dedup(conn, namespace="ns", embed_fn=fake_embed)
    survivors = {e.id for e in _live(conn)}
    assert keep.id in survivors
    assert drop.id not in survivors


def test_access_count_folded_into_survivor(conn):
    keep = db.write_entry(conn, namespace="ns", kind="fact", content="postgres prod database")
    drop = db.write_entry(conn, namespace="ns", kind="fact", content="postgres prod database")
    conn.execute("UPDATE entries SET access_count = 5 WHERE id = ?", (keep.id,))
    conn.execute("UPDATE entries SET access_count = 3 WHERE id = ?", (drop.id,))
    dedup_job.dedup(conn, namespace="ns", embed_fn=fake_embed)
    row = conn.execute("SELECT access_count FROM entries WHERE id = ?", (keep.id,)).fetchone()
    assert row["access_count"] == 8  # 5 + folded 3


def test_dry_run_mutates_nothing(conn):
    db.write_entry(conn, namespace="ns", kind="fact", content="postgres prod database")
    db.write_entry(conn, namespace="ns", kind="fact", content="postgres prod database")
    res = dedup_job.dedup(conn, namespace="ns", dry_run=True, embed_fn=fake_embed)
    assert res.merged == 1
    assert res.dry_run is True
    assert len(_live(conn)) == 2  # nothing actually archived


def test_pinned_entries_are_never_merged(conn):
    a = db.write_entry(conn, namespace="ns", kind="fact", content="postgres prod database")
    b = db.write_entry(conn, namespace="ns", kind="fact", content="postgres prod database")
    conn.execute("UPDATE entries SET pinned = 1 WHERE id IN (?, ?)", (a.id, b.id))
    res = dedup_job.dedup(conn, namespace="ns", embed_fn=fake_embed)
    assert res.merged == 0
    assert len(_live(conn)) == 2


def test_dedup_is_namespace_scoped(conn):
    db.write_entry(conn, namespace="ns1", kind="fact", content="postgres prod database")
    db.write_entry(conn, namespace="ns2", kind="fact", content="postgres prod database")
    res = dedup_job.dedup(conn, embed_fn=fake_embed)  # all namespaces
    # Identical content in *different* namespaces must NOT merge.
    assert res.merged == 0
    assert res.clusters == 2


def test_audit_records_merge(conn):
    db.write_entry(conn, namespace="ns", kind="fact", content="postgres prod database")
    db.write_entry(conn, namespace="ns", kind="fact", content="postgres prod database")
    dedup_job.dedup(conn, namespace="ns", embed_fn=fake_embed)
    row = conn.execute("SELECT action, payload FROM audit WHERE action = 'dedup'").fetchone()
    assert row is not None
    assert "merged_into" in row["payload"]


def test_threshold_validation(conn):
    with pytest.raises(ValueError):
        dedup_job.dedup(conn, namespace="ns", threshold=0.0, embed_fn=fake_embed)
    with pytest.raises(ValueError):
        dedup_job.dedup(conn, namespace="ns", threshold=1.5, embed_fn=fake_embed)


def test_unembeddable_entry_skipped_not_merged(conn):
    db.write_entry(conn, namespace="ns", kind="fact", content="postgres prod database")
    db.write_entry(conn, namespace="ns", kind="fact", content="boom")

    def selective_embed(text: str) -> list[float]:
        if "boom" in text:
            raise RuntimeError("embed failed")
        return fake_embed(text)

    res = dedup_job.dedup(conn, namespace="ns", embed_fn=selective_embed)
    assert res.skipped_unembeddable == 1
    assert res.merged == 0
    assert len(_live(conn)) == 2  # the unembeddable row is untouched


def test_three_way_cluster_merges_two(conn):
    db.write_entry(conn, namespace="ns", kind="fact", content="postgres prod database")
    db.write_entry(conn, namespace="ns", kind="fact", content="postgres prod database")
    db.write_entry(conn, namespace="ns", kind="fact", content="postgres prod database")
    res = dedup_job.dedup(conn, namespace="ns", embed_fn=fake_embed)
    assert res.merged == 2
    assert res.clusters == 1
    assert len(_live(conn)) == 1
