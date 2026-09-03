#!/usr/bin/env python3
"""Pack the viewer meshes into one quantized binary blob + an index.

Positions are int16 over a shared bounding box (0.005mm per step across
this model, which is two orders finer than the 0.35mm fits the design
turns on). Normals are int8. Stride is padded to 12 bytes so every
attribute lands on an aligned offset.
"""
import base64
import json
import struct
import sys
from pathlib import Path

import numpy as np
import trimesh

HERE = Path(__file__).parent
VIEW = HERE / "build" / "view"
PARTS = ["tripod_nut", "pedestal", "az_column", "yoke", "az_pinion",
         "az_handle", "tilt_platter", "tilt_wheel", "tilt_pinion",
         "tilt_handle", "payload"]

# STALENESS GUARD. The viewer is the one artifact a person judges the
# design by, and it is assembled from meshes exported by a separate step
# -- so it is the easiest thing in the directory to publish out of date.
# It already happened once: every view mesh was older than the newest
# source, and the page still built and still looked right.
#
# check.py learned this same lesson about its own cache. Refusing is the
# only version that works; a warning gets read after the publish.
SRC_MTIME = max(p.stat().st_mtime for p in HERE.glob("*.scad"))
stale = [p for p in PARTS
         if (VIEW / f"{p}.stl").stat().st_mtime < SRC_MTIME]
if stale:
    raise SystemExit(
        "pack_viewer: these meshes are older than the newest .scad and "
        f"would publish a design nobody is looking at: {stale}\n"
        "Re-export them before packing.")

meshes = {}
for p in PARTS:
    m = trimesh.load(VIEW / f"{p}.stl")
    meshes[p] = m

allv = np.vstack([m.vertices for m in meshes.values()])
lo, hi = allv.min(axis=0), allv.max(axis=0)
centre = (lo + hi) / 2
half = float(np.abs(np.vstack([lo - centre, hi - centre])).max()) * 1.001
scale = half / 32767.0

chunks, index, off = [], [], 0
for p in PARTS:
    m = meshes[p]
    tri = m.vertices[m.faces]                       # (F,3,3)
    n = m.face_normals                              # (F,3)
    verts = tri.reshape(-1, 3)
    norms = np.repeat(n, 3, axis=0)
    q = np.round((verts - centre) / scale).astype(np.int16)
    qn = np.clip(np.round(norms * 127), -127, 127).astype(np.int8)
    buf = np.zeros((len(verts), 12), dtype=np.uint8)
    buf[:, 0:6] = q.view(np.uint8).reshape(-1, 6)
    buf[:, 6:9] = qn.view(np.uint8).reshape(-1, 3)
    b = buf.tobytes()
    chunks.append(b)
    index.append({"name": p, "offset": off, "count": len(verts)})
    off += len(b)

blob = b"".join(chunks)
meta = {"scale": scale, "centre": list(map(float, centre)), "parts": index}
out = {"meta": meta, "blob": base64.b64encode(blob).decode()}
(HERE / "build" / "viewer_data.json").write_text(json.dumps(out))
print(f"{len(blob)/1e6:.2f} MB raw, {len(out['blob'])/1e6:.2f} MB base64, "
      f"{sum(i['count'] for i in index)//3} triangles")
