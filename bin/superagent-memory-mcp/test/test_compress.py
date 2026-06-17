"""Wave 4 SmartCrusher + content router tests.

Hermetic: pure stdlib, no network, no db.  All fixtures are constructed
in-process.
"""

from __future__ import annotations

import json

import pytest

from memory_os.compress import (
    CrushResult,
    crush,
    detect,
    make_sentinel,
    parse_sentinel,
    route_compress,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


def _make_rows(n: int, *, value_fn=None) -> list[dict]:
    """Return n homogeneous dicts with fields: id, name, score, note."""
    rows = []
    for i in range(n):
        rows.append(
            {
                "id": i,
                "name": f"item-{i % 5}",  # repeated to test rarity
                "score": float(i),
                "note": f"note for item {i} with extra text to vary length",
            }
        )
    if value_fn:
        for i, r in enumerate(rows):
            value_fn(i, r)
    return rows


def _make_outlier_rows(n: int, outlier_idx: int, outlier_score: float) -> list[dict]:
    """All rows have score ~1.0 except one clear outlier."""
    rows = []
    for i in range(n):
        rows.append({"id": i, "name": f"item-{i}", "score": 1.0, "note": "normal"})
    rows[outlier_idx]["score"] = outlier_score
    return rows


# ---------------------------------------------------------------------------
# crush() — basic compression
# ---------------------------------------------------------------------------


def test_crush_reduces_20_row_array():
    rows = _make_rows(20)
    result = crush(rows, keep=0.3, min_rows=3)
    assert result.dropped > 0
    assert result.kept + result.dropped == 20
    # output list must be shorter than input
    assert len(result.compressed) < 20


def test_crush_keeps_first_and_last_row():
    rows = _make_rows(20)
    result = crush(rows, keep=0.3, min_rows=3)
    output = result.compressed
    # first row of original must appear as first element of output
    assert output[0]["id"] == rows[0]["id"]
    # last row of original must appear as last element of output
    assert output[-1]["id"] == rows[-1]["id"]


def test_crush_inserts_exactly_one_sentinel():
    rows = _make_rows(20)
    result = crush(rows, keep=0.3, min_rows=3)
    output = result.compressed
    sentinel_elems = [e for e in output if isinstance(e, dict) and "__ccr_dropped__" in e]
    assert len(sentinel_elems) == 1


def test_crush_accounting_correct():
    rows = _make_rows(20)
    result = crush(rows, keep=0.3, min_rows=3)
    assert result.dropped + result.kept == 20
    assert result.dropped > 0
    assert result.kept > 0


def test_crush_output_is_valid_json():
    rows = _make_rows(20)
    result = crush(rows, keep=0.3, min_rows=3)
    # Must serialise and re-parse without error
    serialised = json.dumps(result.compressed)
    reparsed = json.loads(serialised)
    assert isinstance(reparsed, list)


# ---------------------------------------------------------------------------
# sentinel round-trip
# ---------------------------------------------------------------------------


def test_sentinel_roundtrip():
    original = "some content string"
    n = 7
    s = make_sentinel(original, n)
    parsed = parse_sentinel(s)
    assert parsed is not None
    h, count = parsed
    assert count == n
    assert len(h) == 12
    # hash must match what make_sentinel embeds
    assert s == f"ccr:{h}:{count}"


def test_sentinel_format_string():
    s = make_sentinel("abc", 3)
    assert s.startswith("ccr:")
    parts = s.split(":")
    assert len(parts) == 3
    assert len(parts[1]) == 12
    assert parts[2] == "3"


def test_parse_sentinel_returns_none_for_non_sentinel():
    assert parse_sentinel("not-a-sentinel") is None
    assert parse_sentinel("ccr:tooshort:5") is None
    assert parse_sentinel("ccr:abcdef012345:notanumber") is None


def test_crush_sentinel_in_result_matches_sentinel_elem():
    rows = _make_rows(20)
    result = crush(rows, keep=0.3, min_rows=3)
    assert result.sentinel is not None
    sentinel_elems = [
        e for e in result.compressed
        if isinstance(e, dict) and "__ccr_dropped__" in e
    ]
    assert sentinel_elems[0]["__ccr_dropped__"] == result.sentinel


# ---------------------------------------------------------------------------
# short / heterogeneous / non-JSON pass-through
# ---------------------------------------------------------------------------


def test_short_array_returned_unchanged():
    rows = _make_rows(4)  # < min_rows * 2 (=6)
    result = crush(rows, keep=0.3, min_rows=3)
    assert result.sentinel is None
    assert result.dropped == 0
    assert result.compressed == rows


def test_heterogeneous_array_returned_unchanged():
    rows = [{"a": 1}, {"a": 2, "b": 3}, {"c": 4}]
    result = crush(rows, keep=0.3, min_rows=1)
    assert result.sentinel is None
    assert result.dropped == 0


def test_non_json_string_returned_unchanged():
    s = "this is not JSON at all"
    result = crush(s)
    assert result.sentinel is None
    assert result.compressed == s
    assert result.dropped == 0


def test_dict_input_returned_unchanged():
    d = {"key": "value"}
    result = crush(d)
    assert result.sentinel is None
    assert result.dropped == 0
    assert result.compressed == d


# ---------------------------------------------------------------------------
# numeric outlier retention
# ---------------------------------------------------------------------------


def test_numeric_outlier_row_is_retained():
    """A row with an extreme z-score must survive even under heavy compression."""
    rows = _make_outlier_rows(20, outlier_idx=10, outlier_score=1000.0)
    result = crush(rows, keep=0.2, min_rows=3)
    output = result.compressed
    non_sentinel = [e for e in output if not (isinstance(e, dict) and "__ccr_dropped__" in e)]
    ids_kept = {e["id"] for e in non_sentinel if isinstance(e, dict)}
    assert 10 in ids_kept, "outlier row must be retained"


# ---------------------------------------------------------------------------
# detect() classification
# ---------------------------------------------------------------------------


def test_detect_json():
    assert detect('[{"a": 1}]') == "json"
    assert detect('{"key": "val"}') == "json"


def test_detect_code():
    assert detect("def foo():\n    return 1\n") == "code"
    assert detect("import os\nimport sys\n") == "code"
    assert detect("class Foo:\n    pass\n") == "code"


def test_detect_log():
    assert detect("ERROR: something went wrong\nTraceback (most recent call last):\n") == "log"


def test_detect_diff():
    diff = "+++ b/file.py\n--- a/file.py\n@@ -1,3 +1,4 @@\n+ new line\n- old line\n"
    assert detect(diff) == "diff"


def test_detect_text():
    assert detect("Hello world, this is plain text.") == "text"


# ---------------------------------------------------------------------------
# route_compress()
# ---------------------------------------------------------------------------


def test_route_compress_crushes_json():
    rows = _make_rows(20)
    content = json.dumps(rows)
    result = route_compress(content, keep=0.3, min_rows=3)
    assert result.dropped > 0


def test_route_compress_passes_text_through():
    content = "plain text content with no compression"
    result = route_compress(content)
    assert result.compressed == content
    assert result.dropped == 0
    assert result.sentinel is None


def test_route_compress_passes_code_through():
    content = "def foo():\n    return 42\n"
    result = route_compress(content)
    assert result.compressed == content
    assert result.dropped == 0


def test_route_compress_returns_crush_result():
    result = route_compress("plain text")
    assert isinstance(result, CrushResult)
