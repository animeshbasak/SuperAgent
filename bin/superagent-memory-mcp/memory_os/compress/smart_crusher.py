"""Statistical compression of JSON arrays-of-objects (Wave 4 SmartCrusher).

Ported in spirit from the ``headroom`` project's INPUT-token reduction pass.

Algorithm — salience scoring (applied per row when the input is a homogeneous
JSON array of dicts):

  1. **Rarity**: for every string field, count how many other rows share the
     same value. Rows with more unique field values score higher; near-duplicate
     rows score lower (their salience is divided by the duplicate count).

  2. **Numeric outlier**: for every numeric field, compute the z-score across
     the column. A row with |z| > 1.5 on any field gets a bonus proportional to
     the max |z| score — this retains statistical outliers that carry signal.

  3. **Content length**: long string values carry more information than short
     ones; the per-row total character count contributes a minor bonus
     (normalised to [0, 1] over the array) to break ties.

Anchor rows (first and last) are always kept regardless of salience so that
structural context is never lost.

Dropped rows are replaced by exactly ONE sentinel element:
  ``{"__ccr_dropped__": "ccr:<HASH12>:<N>"}``
where HASH12 = first 12 hex chars of sha256(original_serialised_content) and
N = number of rows dropped. The standalone sentinel string is ``ccr:<HASH12>:<N>``.
"""

from __future__ import annotations

import hashlib
import json
import math
import re
from dataclasses import dataclass
from typing import Any


# ---------------------------------------------------------------------------
# Public dataclass
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class CrushResult:
    """Outcome of a crush() call.

    Attributes:
        compressed:    The reduced structure (same type as the input if no
                       compression applied; a list with sentinel otherwise).
        sentinel:      The standalone sentinel string ``ccr:<hash>:<n>`` when
                       rows were dropped, else ``None``.
        original_hash: First 12 hex chars of sha256 of the original serialised
                       content.
        dropped:       Number of rows removed.
        kept:          Number of rows retained (including sentinel row).
    """

    compressed: Any
    sentinel: str | None
    original_hash: str
    dropped: int
    kept: int


# ---------------------------------------------------------------------------
# Sentinel helpers (MUST match the contract — other waves depend on this)
# ---------------------------------------------------------------------------

_SENTINEL_RE = re.compile(r"^ccr:([0-9a-f]{12}):(\d+)$")


def make_sentinel(original_str: str, dropped: int) -> str:
    """Return ``ccr:<hash12>:<n>`` for the given original content string."""
    h = hashlib.sha256(original_str.encode()).hexdigest()[:12]
    return f"ccr:{h}:{dropped}"


def parse_sentinel(s: str) -> tuple[str, int] | None:
    """Parse a sentinel string; return ``(hash12, n)`` or ``None`` if not a sentinel."""
    m = _SENTINEL_RE.match(s)
    if m is None:
        return None
    return m.group(1), int(m.group(2))


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _serialise(data: Any) -> str:
    return json.dumps(data, ensure_ascii=False, separators=(",", ":"))


def _is_homogeneous(rows: list[Any]) -> bool:
    """True when every element is a dict with at least one shared key."""
    if not rows or not isinstance(rows[0], dict):
        return False
    first_keys = set(rows[0].keys())
    return all(isinstance(r, dict) and set(r.keys()) == first_keys for r in rows)


def _salience_scores(rows: list[dict]) -> list[float]:
    """Return a salience float per row (higher = more important to keep)."""
    n = len(rows)
    keys = list(rows[0].keys())

    # --- rarity scores (string fields) ---
    rarity: list[float] = [0.0] * n
    for k in keys:
        value_count: dict[Any, int] = {}
        for r in rows:
            v = r.get(k)
            if isinstance(v, str):
                value_count[v] = value_count.get(v, 0) + 1
        for i, r in enumerate(rows):
            v = r.get(k)
            if isinstance(v, str):
                cnt = value_count[v]
                # Unique value → full rarity bonus; shared value → penalty
                rarity[i] += 1.0 / cnt

    # --- numeric outlier scores (z-score) ---
    outlier: list[float] = [0.0] * n
    for k in keys:
        col: list[tuple[int, float]] = []
        for i, r in enumerate(rows):
            v = r.get(k)
            if isinstance(v, (int, float)) and not isinstance(v, bool):
                col.append((i, float(v)))
        if len(col) < 2:
            continue
        vals = [v for _, v in col]
        mean = sum(vals) / len(vals)
        variance = sum((v - mean) ** 2 for v in vals) / len(vals)
        std = math.sqrt(variance)
        if std == 0.0:
            continue
        for i, v in col:
            z = abs(v - mean) / std
            if z > 1.5:
                outlier[i] = max(outlier[i], z)

    # --- content length bonus ---
    lengths = [
        sum(len(str(v)) for v in r.values() if isinstance(v, str))
        for r in rows
    ]
    max_len = max(lengths) if max(lengths) > 0 else 1
    length_bonus = [l / max_len for l in lengths]

    # Combine: rarity dominates, outlier is a large bonus, length breaks ties
    scores = [
        rarity[i] + outlier[i] * 2.0 + length_bonus[i] * 0.1
        for i in range(n)
    ]
    return scores


def _original_hash(original_str: str) -> str:
    return hashlib.sha256(original_str.encode()).hexdigest()[:12]


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def crush(
    data: list | dict | str,
    *,
    keep: float = 0.3,
    min_rows: int = 3,
) -> CrushResult:
    """Compress a JSON array-of-objects by dropping low-salience rows.

    Parameters
    ----------
    data:
        A Python list/dict, or a raw JSON string. If a string, it is parsed
        first; if parsing fails it is returned unchanged.
    keep:
        Fraction of rows to retain (0 < keep <= 1). First and last rows are
        always kept in addition.
    min_rows:
        Do not compress arrays shorter than ``min_rows * 2`` (not enough rows
        to make compression worthwhile).

    Returns
    -------
    CrushResult
        ``.dropped == 0`` and ``.sentinel is None`` when no compression was
        applied.
    """
    if not 0.0 < keep <= 1.0:
        raise ValueError("keep must be in (0, 1]")

    # --- parse if string ---
    original_str: str
    parsed: Any
    if isinstance(data, str):
        original_str = data
        try:
            parsed = json.loads(data)
        except json.JSONDecodeError:
            h = _original_hash(original_str)
            return CrushResult(
                compressed=data,
                sentinel=None,
                original_hash=h,
                dropped=0,
                kept=0,
            )
    else:
        parsed = data
        original_str = _serialise(data)

    h = _original_hash(original_str)

    # --- must be a list ---
    if not isinstance(parsed, list):
        return CrushResult(compressed=parsed, sentinel=None, original_hash=h, dropped=0, kept=0)

    # --- must be long enough ---
    if len(parsed) < min_rows * 2:
        return CrushResult(compressed=parsed, sentinel=None, original_hash=h, dropped=0, kept=0)

    # --- must be homogeneous ---
    if not _is_homogeneous(parsed):
        return CrushResult(compressed=parsed, sentinel=None, original_hash=h, dropped=0, kept=0)

    rows: list[dict] = parsed  # type: ignore[assignment]
    n = len(rows)

    # Number of rows to keep (excluding guaranteed first/last anchors)
    target_keep = max(1, round(n * keep))

    scores = _salience_scores(rows)

    # Anchor indices
    anchors = {0, n - 1}

    # Rank non-anchor rows by score descending
    non_anchor_indices = sorted(
        (i for i in range(n) if i not in anchors),
        key=lambda i: scores[i],
        reverse=True,
    )

    # We keep target_keep total rows; first & last always kept, so budget the rest
    budget = max(0, target_keep - len(anchors))
    chosen_middle = set(non_anchor_indices[:budget])

    kept_indices = sorted(anchors | chosen_middle)
    dropped_indices = [i for i in range(n) if i not in (anchors | chosen_middle)]

    if not dropped_indices:
        return CrushResult(compressed=parsed, sentinel=None, original_hash=h, dropped=0, kept=n)

    n_dropped = len(dropped_indices)
    sentinel_str = make_sentinel(original_str, n_dropped)
    sentinel_elem = {"__ccr_dropped__": sentinel_str}

    # Build output: kept rows with ONE sentinel inserted after the first anchor
    result: list[Any] = [rows[0], sentinel_elem] + [rows[i] for i in kept_indices if i != 0]

    return CrushResult(
        compressed=result,
        sentinel=sentinel_str,
        original_hash=h,
        dropped=n_dropped,
        kept=len(kept_indices),
    )
