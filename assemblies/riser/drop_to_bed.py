#!/usr/bin/env python3
"""Translate each print-oriented STL so it rests on Z=0.

print.scad states rotations. It cannot state landing heights, because
OpenSCAD cannot ask a solid for its bounding box -- so any Z there would
be a hand-computed number restating geometry the part already owns. The
first attempt did that and got five parts of nine wrong, one of them by
32mm, and every one of those files still rendered and still looked right.

Here the drop is MEASURED off the mesh, and asserted afterwards.
"""
import sys
from pathlib import Path

import numpy as np
import trimesh

BUILD = Path(__file__).parent / "build" / "print"
bad = []
for f in sorted(BUILD.glob("*.stl")):
    m = trimesh.load(f)
    dz = -m.bounds[0][2]
    if abs(dz) > 1e-9:
        m.apply_translation([0, 0, dz])
        m.export(f)
    m2 = trimesh.load(f)
    lo = m2.bounds[0][2]
    hi = m2.bounds[1][2]
    fp = m2.bounds[1][:2] - m2.bounds[0][:2]
    if abs(lo) > 1e-3:
        bad.append(f.stem)
    print(f"  {f.stem:<14} z {lo:6.3f}..{hi:6.1f}   bed "
          f"{fp[0]:5.0f} x {fp[1]:5.0f} mm")
if bad:
    sys.exit(f"drop_to_bed: still off the bed: {bad}")
