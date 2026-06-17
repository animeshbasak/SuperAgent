"""Tests for CCR (Compress-Cache-Retrieve) — ccr.py + memory_retrieve tool.

Uses a temp SQLite file (same pattern as test_tools.py).  At least 12 cases.
"""

from __future__ import annotations

import time
from pathlib import Path

import pytest

from memory_os import db, tools
from memory_os.ccr import CCRStore, make_token, parse_token


@pytest.fixture
def conn():
    import tempfile
    tmp = Path(tempfile.mkdtemp()) / "ccr_test.db"
    c = db.connect(tmp)
    yield c
    c.close()


@pytest.fixture
def store(conn):
    return CCRStore(conn)


# --- make_token / parse_token -------------------------------------------------

def test_make_token_format():
    token = make_token("a3f9c2d1e84b", 1)
    assert token == "ccr:a3f9c2d1e84b:1"


def test_parse_token_roundtrip():
    token = make_token("a3f9c2d1e84b", 0)
    result = parse_token(token)
    assert result == ("a3f9c2d1e84b", 0)


def test_parse_token_rejects_malformed():
    assert parse_token("not-a-token") is None
    assert parse_token("ccr:") is None
    assert parse_token("ccr:abc") is None
    assert parse_token("ccr:abc:-1") is None
    assert parse_token("") is None


def test_parse_token_liberal_hash_length():
    # Accepts hashes longer or shorter than 12 chars
    result = parse_token("ccr:deadbeef:2")
    assert result == ("deadbeef", 2)
    result = parse_token("ccr:deadbeefdeadbeefdeadbeef:0")
    assert result is not None
    assert result[1] == 0


# --- cache → retrieve round-trip ----------------------------------------------

def test_cache_returns_sentinel_token(store):
    token = store.cache("hello world", compressed="hello…", kind="text", dropped=0)
    parsed = parse_token(token)
    assert parsed is not None
    hash_, dropped = parsed
    assert len(hash_) == 12
    assert dropped == 0


def test_retrieve_by_full_token(store):
    original = "The quick brown fox jumps over the lazy dog"
    token = store.cache(original, kind="text", dropped=0)
    result = store.retrieve(token)
    assert result is not None
    assert result["content"] == original
    assert result["truncated_by_query"] is False


def test_retrieve_by_bare_hash(store):
    original = "bare hash lookup test"
    token = store.cache(original, kind="text", dropped=1)
    hash_ = parse_token(token)[0]
    result = store.retrieve(hash_)
    assert result is not None
    assert result["content"] == original
    assert result["hash"] == hash_


def test_retrieval_count_increments(store):
    token = store.cache("count me", kind="text", dropped=0)
    hash_ = parse_token(token)[0]

    store.retrieve(token)
    store.retrieve(token)
    store.retrieve(token)

    row = store._conn.execute(
        "SELECT retrieval_count FROM ccr_cache WHERE hash = ?", (hash_,)
    ).fetchone()
    assert row["retrieval_count"] == 3


def test_query_filtered_retrieve_returns_matching_lines(store):
    original = "alpha line one\nbeta line two\nalpha beta line three\ngamma line four"
    token = store.cache(original, kind="text", dropped=0)
    result = store.retrieve(token, query="alpha beta")
    assert result is not None
    assert result["truncated_by_query"] is True
    lines = result["content"].splitlines()
    assert all("alpha" in l.lower() and "beta" in l.lower() for l in lines)
    assert "gamma" not in result["content"]


def test_query_filtered_no_match_returns_empty(store):
    original = "foo bar\nbaz qux"
    token = store.cache(original, kind="text", dropped=0)
    result = store.retrieve(token, query="zzz")
    assert result is not None
    assert result["content"] == ""
    assert result["truncated_by_query"] is True


# --- expiry / TTL -------------------------------------------------------------

def test_expired_entry_not_returned(store):
    token = store.cache("will expire", kind="text", dropped=0, ttl_seconds=1)
    hash_ = parse_token(token)[0]
    future = int(time.time()) + 9999
    result = store.retrieve(token, )
    # Simulate expiry by checking is_expired directly
    row = store._conn.execute(
        "SELECT created_ts, ttl_seconds FROM ccr_cache WHERE hash = ?", (hash_,)
    ).fetchone()
    assert store.is_expired(row, future) is True


def test_retrieve_returns_none_for_expired(store, conn):
    # Insert a row that was created far in the past
    import hashlib
    original = "old content"
    hash_ = hashlib.sha256(original.encode()).hexdigest()[:12]
    past = int(time.time()) - 9999
    conn.execute(
        "INSERT OR REPLACE INTO ccr_cache "
        "(hash, original_content, kind, dropped, created_ts, ttl_seconds, retrieval_count) "
        "VALUES (?, ?, 'text', 0, ?, 1, 0)",
        (hash_, original, past),
    )
    result = store.retrieve(hash_)
    assert result is None


def test_ttl_zero_never_expires(store):
    token = store.cache("immortal", kind="text", dropped=0, ttl_seconds=0)
    hash_ = parse_token(token)[0]
    row = store._conn.execute(
        "SELECT created_ts, ttl_seconds FROM ccr_cache WHERE hash = ?", (hash_,)
    ).fetchone()
    assert store.is_expired(row, int(time.time()) + 10_000_000) is False


def test_prune_expired_removes_rows(store, conn):
    import hashlib
    for i in range(3):
        original = f"expired content {i}"
        hash_ = hashlib.sha256(original.encode()).hexdigest()[:12]
        past = int(time.time()) - 9999
        conn.execute(
            "INSERT OR REPLACE INTO ccr_cache "
            "(hash, original_content, kind, dropped, created_ts, ttl_seconds, retrieval_count) "
            "VALUES (?, ?, 'text', 0, ?, 1, 0)",
            (hash_, original, past),
        )
    # One live entry
    store.cache("live content", kind="text", dropped=0, ttl_seconds=3600)
    removed = store.prune_expired()
    assert removed == 3
    remaining = conn.execute("SELECT COUNT(*) AS n FROM ccr_cache").fetchone()["n"]
    assert remaining == 1


# --- missing hash -------------------------------------------------------------

def test_retrieve_missing_returns_none(store):
    result = store.retrieve("000000000000")
    assert result is None


def test_retrieve_bad_token_falls_back_to_hash_lookup(store):
    # "badtoken" is not ccr:<hash>:<n> format, so it's treated as a bare hash
    # that doesn't exist → None
    result = store.retrieve("badtoken")
    assert result is None


# --- memory_retrieve tool handler --------------------------------------------

def test_memory_retrieve_tool_found(conn):
    store = CCRStore(conn)
    original = "production DB is Postgres on port 5432"
    token = store.cache(original, kind="fact", dropped=1)
    result = tools.memory_retrieve(conn, token=token)
    assert result["ok"] is True
    assert result["content"] == original
    assert result["hash"] is not None


def test_memory_retrieve_tool_not_found(conn):
    result = tools.memory_retrieve(conn, token="ccr:000000000000:0")
    assert result["ok"] is False
    assert result["reason"] == "not-found-or-expired"
    assert "000000000000" in result["token"]


def test_memory_retrieve_tool_with_query(conn):
    store = CCRStore(conn)
    original = "line one alpha\nline two beta\nline three alpha beta"
    token = store.cache(original, kind="text", dropped=0)
    result = tools.memory_retrieve(conn, token=token, query="alpha")
    assert result["ok"] is True
    assert "beta" in result["content"] or "alpha" in result["content"]
    assert all("alpha" in line.lower() for line in result["content"].splitlines() if line)
