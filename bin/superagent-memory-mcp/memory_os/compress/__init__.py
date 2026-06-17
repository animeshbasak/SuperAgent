"""INPUT-token compression — statistical JSON crusher + content router.

Public surface:
    from memory_os.compress import crush, CrushResult, detect, route_compress
    from memory_os.compress import make_sentinel, parse_sentinel
"""

from .smart_crusher import CrushResult, crush, make_sentinel, parse_sentinel
from .router import detect, route_compress

__all__ = [
    "CrushResult",
    "crush",
    "make_sentinel",
    "parse_sentinel",
    "detect",
    "route_compress",
]
