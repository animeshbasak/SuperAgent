"""Content-type router — classifies text and dispatches to the right compressor.

``detect()`` uses cheap heuristics (no ML, no external deps) to classify
content as one of: ``json | code | log | diff | text``.

``route_compress()`` applies SmartCrusher for JSON content.  All other content
types (``code``, ``log``, ``diff``, ``text``) are stubs that pass content
through unchanged — future waves will plug in dedicated compressors here:

  TODO code:  strip comments, collapse identical import blocks.
  TODO log:   collapse repeated lines, keep ERROR/WARN frames.
  TODO diff:  summarise context-only hunks, keep +/- lines verbatim.
"""

from __future__ import annotations

import json

from .smart_crusher import CrushResult, crush, _original_hash, _serialise


# ---------------------------------------------------------------------------
# Detector
# ---------------------------------------------------------------------------

_CODE_TOKENS = ("def ", "function ", "class ", "import ", "from ", "const ", "var ", "let ")
_LOG_TOKENS = ("ERROR", "WARN", "WARNING", "FATAL", "Traceback", "Exception", "at ")
_DIFF_LEADING = frozenset(("+", "-", "@"))


def detect(content: str) -> str:
    """Return the content type as one of ``json | code | log | diff | text``.

    Detection is strictly ordered: json → diff → code → log → text.
    """
    # json: try a cheap parse
    stripped = content.strip()
    if stripped.startswith(("{", "[")):
        try:
            json.loads(stripped)
            return "json"
        except json.JSONDecodeError:
            pass

    # diff: majority of non-blank lines start with +/- or @@
    lines = [l for l in content.splitlines() if l.strip()]
    if lines:
        diff_lines = sum(1 for l in lines if l[:1] in _DIFF_LEADING)
        if diff_lines / len(lines) > 0.3:
            return "diff"

    # code: keyword presence
    for tok in _CODE_TOKENS:
        if tok in content:
            return "code"

    # log: error/warn/traceback markers
    for tok in _LOG_TOKENS:
        if tok in content:
            return "log"

    return "text"


# ---------------------------------------------------------------------------
# Router
# ---------------------------------------------------------------------------


def route_compress(content: str, **kw) -> CrushResult:
    """Detect content type and apply the appropriate compressor.

    Currently only ``json`` content is actively compressed via
    :func:`~memory_os.compress.smart_crusher.crush`.  All other types are
    returned as-is wrapped in a ``CrushResult`` with ``dropped=0``.
    """
    kind = detect(content)
    h = _original_hash(content)

    if kind == "json":
        return crush(content, **kw)

    # Stubs — TODO: plug in specialised compressors per type
    return CrushResult(
        compressed=content,
        sentinel=None,
        original_hash=h,
        dropped=0,
        kept=0,
    )
