#!/usr/bin/env python3
"""Measured verification for riser/.

Two conditions, always (cad-design rule 1): nothing interferes, AND the
things that are supposed to touch actually do. "Nothing intersects" is
equally true of two parts a metre apart, so an overlap check alone is a
silent false pass on every designed contact in the mechanism.

Every dimension is READ BACK OUT of OpenSCAD at runtime (rule 3). There
is not one geometric constant typed into this file. What IS typed in here
is intent -- which pairs must clear, which must touch -- because that is
the one thing the CAD cannot state.

And rule 4: suspect this file before the design. Every false FAIL in this
repo's history came from the checker restating geometry the CAD already
owned, or measuring the right number against the wrong reference.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

import numpy as np
import trimesh

HERE = Path(__file__).parent
BUILD = HERE / "build" / "chk"
BUILD.mkdir(parents=True, exist_ok=True)

FAILURES: list[str] = []
WARNINGS: list[str] = []
CHECKS = 0


def fail(msg: str) -> None:
    FAILURES.append(msg)
    print(f"  FAIL  {msg}")


def warn(msg: str) -> None:
    WARNINGS.append(msg)
    print(f"  WARN  {msg}")


def ok(msg: str) -> None:
    print(f"  ok    {msg}")


# ---------------------------------------------------------------------
# Read the parameters out of OpenSCAD, rather than restating them here.
# ---------------------------------------------------------------------
def scad_params(scad_dir: Path, names: list[str]) -> dict:
    """Echo the named variables out of <scad_dir>/params.scad and parse."""
    body = "include <params.scad>\n"
    for n in names:
        body += f'echo("PARAM", "{n}", {n});\n'
    src = scad_dir / "_dump_params.scad"
    src.write_text(body)
    try:
        r = subprocess.run(
            ["openscad", "-o", str(BUILD / "dump.stl"), str(src)],
            capture_output=True, text=True, cwd=scad_dir)
    finally:
        src.unlink(missing_ok=True)
    out = {}
    for line in r.stderr.splitlines():
        m = re.match(r'ECHO: "PARAM", "([A-Za-z0-9_]+)", (.*)$', line.strip())
        if m:
            raw = m.group(2).strip()
            try:
                out[m.group(1)] = float(raw)
            except ValueError:
                out[m.group(1)] = raw.strip('"')
    missing = [n for n in names if n not in out]
    if missing:
        # Rule 2: an undefined name in OpenSCAD evaluates to undef and
        # warns. If this checker silently skipped it, every assert that
        # depends on it would quietly stop existing.
        raise SystemExit(f"check.py: params not readable: {missing}")
    return out


P = scad_params(HERE, [
    "tilt_max_deg", "tilt_axis_z", "payload_face_z", "payload_r",
    "payload_arm_r", "az_gear_cd", "tilt_gear_cd", "az_gear_teeth",
    "tilt_wheel_teeth", "tilt_pinion_teeth", "az_journal_fit", "tilt_fit",
    "clearance", "stud_protrude", "tripod_bolt_r", "tripod_plate_d",
    "knob_force_req", "knob_force_limit",
    "tilt_clamp_force", "clamp_hand_limit", "az_thrust_r", "base_plate_r",
    "riser_rise", "tilt_arm_y", "stud_len", "tilt_ratio",
    "az_gear_z0", "az_gear_z1", "tilt_arm_y_out", "tilt_gear_standoff",
    "tilt_gear_face", "column_top_z", "yoke_bottom_z", "az_knob_top_z",
])
MOUNT = scad_params(HERE.parent / "mount", ["tripod_nut_t", "base_plate_r"])


# ---------------------------------------------------------------------
# Posing. pose.scad emits one body at its assembly pose, from the SAME
# code the assembly draws with -- so nothing here is a second copy of a
# transform.
# ---------------------------------------------------------------------
_cache: dict = {}


# Posing is done NUMERICALLY here, not by re-rendering. Rendering every
# part at every pose is the obviously-correct approach and it is not
# affordable: one posed handle is ~50 seconds of CGAL, so a real sweep
# would be most of an hour and would therefore not get run.
#
# The obvious danger is that these matrices become a second, drifting copy
# of assembly.scad's transforms -- which is precisely the failure rule 4
# warns about, the checker being wrong rather than the design. So they are
# CHECKED: verify_poses() below renders each part through pose.scad at a
# non-trivial pose and requires the rendered result and the numeric one to
# agree on volume, centroid and bounding box. Two independent walks that
# must land on the same place, the same guard ../mount/alt_rotor.scad puts
# on its axle stations.
def Rz(deg):
    return trimesh.transformations.rotation_matrix(np.radians(deg), [0, 0, 1])


def Ry(deg):
    return trimesh.transformations.rotation_matrix(np.radians(deg), [0, 1, 0])


def T(x, y, z):
    return trimesh.transformations.translation_matrix([x, y, z])


def about(deg, z0, axis="y"):
    """Rotate about a horizontal axis at height z0."""
    return T(0, 0, z0) @ (Ry(deg) if axis == "y" else Rz(deg)) @ T(0, 0, -z0)


def pose_matrix(part, az, tilt):
    z0 = P["tilt_axis_z"]
    zk = P["tilt_axis_z"] - P["tilt_gear_cd"]
    if part in ("pedestal", "tripod_nut"):
        return np.eye(4)
    if part in ("az_column", "yoke"):
        return Rz(az)
    if part in ("az_handle", "az_pinion"):
        return T(P["az_gear_cd"], 0, 0) @ Rz(-az) @ T(-P["az_gear_cd"], 0, 0)
    if part in ("tilt_platter", "tilt_wheel", "payload", "payload_disc"):
        return Rz(az) @ about(tilt, z0)
    if part in ("tilt_handle", "tilt_pinion"):
        return Rz(az) @ about(-tilt * P["tilt_ratio"], zk)
    raise KeyError(part)


_zero: dict = {}

# Newest source in the directory. Anything cached older than this is stale.
# Learned the hard way in this very file: a run after four real fixes
# reported the four old failure volumes to the DIGIT, because the cache
# was keyed on the filename and nothing else. A checker that confidently
# reports last hour's geometry is worse than one that is merely slow.
SRC_MTIME = max(p.stat().st_mtime for p in HERE.glob("*.scad"))


def zero_body(part: str) -> trimesh.Trimesh:
    """The part as pose.scad draws it at az=0, tilt=0."""
    if part in _zero:
        return _zero[part]
    out = BUILD / f"{part}_zero.stl"
    if out.exists() and out.stat().st_mtime < SRC_MTIME:
        out.unlink()
    if not out.exists():
        r = subprocess.run(
            ["openscad", "-o", str(out), "--hardwarnings",
             "-D", f'part="{part}"', "-D", "az=0", "-D", "tilt=0",
             "pose.scad"], capture_output=True, text=True, cwd=HERE)
        if r.returncode != 0 or not out.exists():
            raise SystemExit(f"check.py: cannot pose {part}:\n{r.stderr[-2000:]}")
    _zero[part] = trimesh.load(out)
    return _zero[part]


_cache: dict = {}


def body(part: str, az: float = 0.0, tilt: float = 0.0) -> trimesh.Trimesh:
    key = (part, round(az, 4), round(tilt, 4))
    if key in _cache:
        return _cache[key]
    m = zero_body(part).copy()
    # Relative to the zero pose, because a part's local frame is its own
    # business -- az_pinion is modelled at the origin and assembled out at
    # the centre distance, and nothing here needs to know that.
    rel = pose_matrix(part, az, tilt) @ np.linalg.inv(pose_matrix(part, 0, 0))
    m.apply_transform(rel)
    _cache[key] = m
    return m


def verify_poses(cases):
    """Render through pose.scad and require the numeric pose to match."""
    global CHECKS
    print("\n== pose transforms, against pose.scad ==")
    for part, az, tilt in cases:
        CHECKS += 1
        out = BUILD / f"v_{part}_{az:.0f}_{tilt:.0f}.stl".replace("-", "m")
        if out.exists() and out.stat().st_mtime < SRC_MTIME:
            out.unlink()
        if not out.exists():
            r = subprocess.run(
                ["openscad", "-o", str(out), "--hardwarnings",
                 "-D", f'part="{part}"', "-D", f"az={az}", "-D", f"tilt={tilt}",
                 "pose.scad"], capture_output=True, text=True, cwd=HERE)
            if r.returncode != 0 or not out.exists():
                fail(f"{part}: pose.scad will not render at az={az} tilt={tilt}")
                continue
        rendered = trimesh.load(out)
        numeric = body(part, az, tilt)
        dc = float(np.linalg.norm(rendered.centroid - numeric.centroid))
        db = float(np.abs(rendered.bounds - numeric.bounds).max())
        dv = abs(rendered.volume - numeric.volume) / max(rendered.volume, 1)
        if dc > 0.05 or db > 0.05 or dv > 1e-3:
            fail(f"{part} at az={az} tilt={tilt}: the numeric pose and "
                 f"pose.scad disagree (centroid {dc:.3f} mm, bbox {db:.3f} mm, "
                 f"volume {dv*100:.2f}%). Suspect this checker, not the CAD.")
        else:
            ok(f"{part} at az={az} tilt={tilt}: matches pose.scad "
               f"(centroid {dc:.3f} mm)")


def bbox_gap(a: trimesh.Trimesh, b: trimesh.Trimesh) -> float:
    """A sound LOWER BOUND on the gap, from bounding boxes alone.

    Cheap, and never optimistic: if this says the boxes are 4mm apart the
    solids are at least 4mm apart. Used only to skip pairs that obviously
    cannot touch. Reported as ">= bound", never as an exact distance --
    a bound dressed up as a measurement is exactly the summarized-standing-
    in-for-real failure rule 7 warns about.
    """
    lo = np.maximum(a.bounds[0], b.bounds[0])
    hi = np.minimum(a.bounds[1], b.bounds[1])
    d = lo - hi
    d = d[d > 0]
    return float(np.linalg.norm(d)) if len(d) else 0.0


def overlap_volume(a: trimesh.Trimesh, b: trimesh.Trimesh) -> float:
    if bbox_gap(a, b) > 0:
        return 0.0
    try:
        inter = a.intersection(b)
    except Exception:
        return float("nan")
    return 0.0 if inter is None or inter.is_empty else float(inter.volume)


def min_distance(a: trimesh.Trimesh, b: trimesh.Trimesh, n=1500) -> float:
    """Surface-to-surface minimum, sampled both ways."""
    pa = a.sample(n)
    pb = b.sample(n)
    da = trimesh.proximity.closest_point(b, pa)[1].min()
    db = trimesh.proximity.closest_point(a, pb)[1].min()
    return float(min(da, db))


def contact_area(a, b, thresh, n=6000) -> float:
    """Estimated area of the contact patch, in mm^2.

    A raw count of sampled points is a measure of how big the PART is, not
    how big the contact is: the same 84mm2 collar face read 333 points
    against one part and 16 against another, and the 16 failed. Scaling
    the hit fraction by the sampled body's surface area turns it back into
    a physical quantity that means the same thing on every pair.

    Taken as the smaller of the two directions, which is the conservative
    reading when the two disagree.
    """
    out = []
    for x, y in ((a, b), (b, a)):
        px = x.sample(n)
        d = trimesh.proximity.closest_point(y, px)[1]
        out.append(float((d < thresh).sum()) / n * float(x.area))
    return min(out)


# ---------------------------------------------------------------------
# 1. Every part is ONE body.
# ---------------------------------------------------------------------
# Not decoration. A boolean that severs a post from its own plate leaves a
# model that is watertight, renders identically, and is in pieces. It
# happened twice while building this directory, and a body count is the
# only thing that saw it.
print("\n== part integrity ==")
# tilt_wheel and tilt_pinion are the SAME printed part at two stations.
# Both are listed: integrity is then checked on one file twice, which
# costs nothing, and every pair below can name the station it means.
PARTS = ["pedestal", "az_column", "yoke", "az_pinion", "az_handle",
         "tilt_platter", "tilt_wheel", "tilt_pinion", "tilt_handle",
         "tripod_nut"]
for p in PARTS:
    CHECKS += 1
    m = body(p)
    solids = [c for c in m.split(only_watertight=False) if c.volume > 1.0]
    slivers = len(m.split(only_watertight=False)) - len(solids)
    if len(solids) != 1:
        fail(f"{p}: {len(solids)} separate solids, expected 1")
    elif not m.is_watertight:
        fail(f"{p}: not watertight")
    else:
        note = f", {slivers} zero-volume slivers" if slivers else ""
        ok(f"{p}: 1 solid, watertight, {m.volume/1000:.1f} cm3{note}")


# ---------------------------------------------------------------------
# 2. The gears have the teeth they claim to.
# ---------------------------------------------------------------------
# A gear generator that silently produced a smooth disc would pass every
# other check in this file. ../mount shipped exactly that defect on a
# 160-tooth pulley -- watertight, valid, and unable to drive anything.
print("\n== tooth counts ==")


def count_teeth(mesh, centre, axis, r_lo, r_hi, a_lo, a_hi, bins=240) -> int:
    """Count tooth crests on ONE gear inside a part that has other features.

    The window is radial AND axial. Radial alone is not enough: az_column
    carries a 30mm column and a 62mm table as well as its gear, and every
    one of those lands in some radius band. Selecting on radius only
    counted 73 teeth on a 20-tooth pinion -- the knob's own three lobes
    and the gear, binned together.
    """
    v = mesh.vertices - np.array(centre)
    axis = np.array(axis, dtype=float)
    axis = axis / np.linalg.norm(axis)
    along = v @ axis
    radial = v - np.outer(along, axis)
    r = np.linalg.norm(radial, axis=1)
    sel = (r > r_lo) & (r < r_hi) & (along > a_lo) & (along < a_hi)
    if sel.sum() < 50:
        return -1
    # Angle in the plane normal to the axis.
    e1 = np.array([axis[1], -axis[0], 0.0])
    if np.linalg.norm(e1) < 1e-6:
        e1 = np.array([1.0, 0.0, 0.0])
    e1 /= np.linalg.norm(e1)
    e2 = np.cross(axis, e1)
    ang = np.arctan2(radial[sel] @ e2, radial[sel] @ e1)
    idx = ((ang + np.pi) / (2 * np.pi) * bins).astype(int) % bins
    prof = np.full(bins, np.nan)
    for i, rr in zip(idx, r[sel]):
        if np.isnan(prof[i]) or rr > prof[i]:
            prof[i] = rr
    valid = ~np.isnan(prof)
    # 1200 bins over a 20-tooth gear left most bins empty and this guard
    # rejected every gear in the directory as "could not resolve". The bin
    # count has to be scaled to the feature being counted, not to the
    # precision one would like.
    if valid.sum() < bins * 0.3:
        return -1
    p = prof[valid]
    thresh = (p.max() + p.min()) / 2
    above = p > thresh
    return int(np.sum(above & ~np.roll(above, 1)))


# The axial window has to INCLUDE the gear's end faces. A linear-extruded
# gear has vertices only on its two rims, so a window set to the interior
# of the face selects the one part of the mesh that has no vertices at
# all -- and every gear in the directory reported "could not resolve a
# tooth profile" while being perfectly well formed.
_gz = (P["az_gear_z0"] - 0.1, P["az_gear_z1"] + 0.1)
_gy = P["tilt_arm_y_out"] - P["tilt_gear_standoff"]
_ty = (_gy - P["tilt_gear_face"] - 0.1, _gy + 0.1)
for part, teeth, centre, axis, lo, hi, alo, ahi in [
    ("az_column", P["az_gear_teeth"], (0, 0, 0), (0, 0, 1), 12, 26, *_gz),
    ("az_pinion", P["az_gear_teeth"], (P["az_gear_cd"], 0, 0), (0, 0, 1),
     12, 26, *_gz),
    ("tilt_wheel", P["tilt_wheel_teeth"],
     (0, 0, P["tilt_axis_z"]), (0, 1, 0), 15, 32, *_ty),
    ("tilt_pinion", P["tilt_pinion_teeth"],
     (0, 0, P["tilt_axis_z"] - P["tilt_gear_cd"]), (0, 1, 0), 15, 32, *_ty),
]:
    CHECKS += 1
    n = count_teeth(body(part), centre, axis, lo, hi, alo, ahi,
                    bins=int(teeth) * 12)
    if n == int(teeth):
        ok(f"{part}: {n} teeth")
    elif n < 0:
        warn(f"{part}: could not resolve a tooth profile in r={lo}..{hi}")
    else:
        fail(f"{part}: counted {n} teeth, expected {int(teeth)}")


# ---------------------------------------------------------------------
# 3. Pair intent. This is the part the CAD cannot state for itself.
# ---------------------------------------------------------------------
MUST_CLEAR = "must-clear"      # never touch; a minimum gap is required
RUNNING_FIT = "running-fit"    # bounded on BOTH sides: a bearing
MESH = "mesh"                  # gear teeth: must not overlap, must engage
DESIGNED_TOUCH = "touch"       # bears load; must contact, must not merge
RIGID = "rigid"                # keyed together; overlap-only
THREADED = "threaded"          # a screwed joint. See below.

PAIRS = [
    # --- the load path, ground upward ---
    ("pedestal", "az_column", DESIGNED_TOUCH, "table on the thrust ring"),
    ("az_column", "yoke", RIGID, "yoke keyed into the column's mortise"),
    ("yoke", "tilt_platter", DESIGNED_TOUCH,
     "trunnion flange journal, and the +Y stub in its open seat"),
    ("tilt_platter", "payload", DESIGNED_TOUCH, "payload bolted to the platter"),
    ("tilt_platter", "payload_disc", DESIGNED_TOUCH,
     "payload disc resting on the platter"),
    # A SCREWED joint. How far two mating threads overlap in a static pose
    # is a fact about the angle the nut happened to be drawn at, not about
    # the design -- the mating phase is set by how far it is screwed on.
    # Bounded rather than required to be zero: a real diameter clash
    # between an M10 stud and its nut is thousands of mm3.
    ("pedestal", "tripod_nut", THREADED, "M10 stud in the hand nut"),

    # --- the two hand drives ---
    # The handles' COLLARS bear on the faces behind them -- that collar is
    # what sets each gear's standoff, so it is a thrust face, not a gap.
    # Classified as a running fit, the checker correctly reported 0.00mm
    # and correctly called it a failure; the intent was what was wrong.
    ("pedestal", "az_handle", DESIGNED_TOUCH,
     "az handle collar on the pocket floor"),
    ("az_handle", "az_pinion", RIGID, "az pinion keyed on the handle's hex"),
    ("az_column", "az_pinion", MESH, "azimuth 1:1 pair"),
    ("yoke", "tilt_handle", DESIGNED_TOUCH,
     "tilt handle collar on the tine's face"),
    ("tilt_handle", "tilt_pinion", RIGID,
     "tilt pinion keyed on the handle's hex"),
    ("tilt_wheel", "tilt_pinion", MESH, "tilt 1:1 pair"),
    ("tilt_platter", "tilt_wheel", RIGID, "tilt wheel keyed on the stub"),

    # --- the gears must not rub the parts they turn beside ---
    ("yoke", "tilt_wheel", MUST_CLEAR, "wheel clear of the tine face"),
    ("yoke", "tilt_pinion", MUST_CLEAR, "pinion clear of the tine face"),
    ("az_column", "az_handle", MUST_CLEAR, "az handle clear of the column"),
    ("pedestal", "az_pinion", MUST_CLEAR, "az pinion clear of its pocket"),

    # --- the payload, both ways it has to be true ---
    ("az_column", "payload_disc", MUST_CLEAR,
     "column clear of the payload at EVERY mounting orientation"),
    ("yoke", "payload_disc", MUST_CLEAR,
     "yoke clear of the payload at EVERY mounting orientation"),
    ("az_handle", "payload_disc", MUST_CLEAR, "az handle clear of the payload"),
    ("tilt_handle", "payload_disc", MUST_CLEAR,
     "tilt handle clear of the payload"),
    ("pedestal", "payload_disc", MUST_CLEAR, "base clear of the payload"),
    ("az_column", "payload", MUST_CLEAR,
     "column clear of the REAL payload at the specified orientation"),
    ("yoke", "payload", MUST_CLEAR,
     "yoke clear of the REAL payload at the specified orientation"),
    ("tilt_handle", "payload", MUST_CLEAR,
     "tilt handle clear of the real payload"),
]

# Everything left over. Most are obviously far apart, which is exactly why
# they need declaring: "obviously" is not a measurement, and the
# bounding-box early-out makes them nearly free to check properly.
_ALL = PARTS + ["payload", "payload_disc"]
_named = {(a, b) for a, b, _, _ in PAIRS} | {(b, a) for a, b, _, _ in PAIRS}
# payload / payload_disc are the same body modelled two ways -- the real
# mesh, and the disc that is true at every orientation the mount could be
# screwed down at. Checking them against each other asks whether an object
# overlaps itself, and it answered 68,010 mm3. Excluded by name, so the
# coverage check still accounts for it rather than quietly ignoring it.
EXCLUDED = {("payload", "payload_disc")}
for _i, _a in enumerate(_ALL):
    for _b in _ALL[_i + 1:]:
        if (_a, _b) in _named or (_b, _a) in _named:
            continue
        if (_a, _b) in EXCLUDED or (_b, _a) in EXCLUDED:
            continue
        PAIRS.append((_a, _b, MUST_CLEAR, "remainder"))

MIN_GAP = 1.0        # must-clear pairs
MESH_MAX = 0.8       # a pair further apart than this is not engaged
TOUCH_EPS = 2.0      # mm3 of overlap tolerated on a bearing face
MIN_PATCH = 15.0     # mm2. Below this a "bearing face" is an edge, and an
                     # edge concentrates the whole load onto a line of
                     # printed plastic.

# Kept short on purpose. Each entry is a real OpenSCAD render of every
# part at that pose, and the knobs are the expensive ones. 37 rather than
# 45 for azimuth so the pose never lands on the pedestal's own 8-fold
# lightening symmetry -- a sweep that only samples symmetric poses is a
# sweep that cannot see an asymmetric clash.
# Posing is numeric now, so a fine sweep is affordable. 37 rather than 45
# for azimuth so it never lands on the pedestal's own 8-fold lightening
# symmetry -- a sweep that only samples symmetric poses cannot see an
# asymmetric clash.
AZ_SWEEP = [0.0, 23.0, 37.0, 90.0]
TILT_SWEEP = [0.0, 8.0, 16.0, 24.0, 32.0, float(P["tilt_max_deg"])]

verify_poses([("az_column", 37.0, 0.0), ("az_handle", 37.0, 0.0),
              ("az_pinion", 37.0, 0.0), ("yoke", 37.0, 0.0),
              ("tilt_platter", 37.0, 25.0), ("tilt_wheel", 0.0, 25.0),
              ("tilt_handle", 0.0, 25.0), ("tilt_pinion", 0.0, 25.0),
              ("payload", 37.0, 25.0), ("pedestal", 37.0, 25.0),
              ("tripod_nut", 37.0, 25.0)])

print("\n== pairs, swept ==")


def rel_key(a, b, az, tilt):
    """A pose is only interesting if it moves the two bodies RELATIVE to
    each other. Two parts that rotate together are in the same place at
    every azimuth, and measuring that 24 times is 24 times the cost for
    one answer. Rounded, so float noise does not defeat the dedup."""
    r = np.linalg.inv(pose_matrix(a, az, tilt)) @ pose_matrix(b, az, tilt)
    return tuple(np.round(r.ravel(), 6))


covered = set()
for a, b, intent, why in PAIRS:
    CHECKS += 1
    covered.add((a, b))
    seen, poses = set(), []
    for az in AZ_SWEEP:
        for tl in TILT_SWEEP:
            k = rel_key(a, b, az, tl)
            if k not in seen:
                seen.add(k)
                poses.append((az, tl))
    worst_gap, worst_ov, worst_pose, gap_pose = 1e9, 0.0, None, None
    exact = False
    for az, tl in poses:
        ma, mb = body(a, az, tl), body(b, az, tl)
        ov = overlap_volume(ma, mb)
        if ov > worst_ov:
            worst_ov, worst_pose = ov, (az, tl)
        lb = bbox_gap(ma, mb)
        if intent == MUST_CLEAR and lb > MIN_GAP + 1.0:
            g = lb          # a sound LOWER bound, never optimistic
        else:
            g = min_distance(ma, mb)
            exact = True
        if g < worst_gap:
            worst_gap, gap_pose = g, (az, tl)
    if worst_pose is None:
        worst_pose = gap_pose
    tag = "exact" if exact else ">="
    pose = f"az={gap_pose[0]:.0f} tilt={gap_pose[1]:.0f}"
    npose = f"[{len(poses)} distinct of {len(AZ_SWEEP)*len(TILT_SWEEP)}]"

    if intent == MUST_CLEAR:
        if worst_ov > 0.5:
            fail(f"{a}/{b}: {worst_ov:.1f} mm3 of interference at "
                 f"az={worst_pose[0]:.0f} tilt={worst_pose[1]:.0f} -- {why}")
        elif worst_gap < MIN_GAP:
            fail(f"{a}/{b}: closes to {worst_gap:.2f} mm at {pose} "
                 f"(need {MIN_GAP}) -- {why}")
        else:
            ok(f"{a}/{b}: clear, {tag} {worst_gap:.2f} mm {npose} -- {why}")
    elif intent == RUNNING_FIT:
        # Bounded on BOTH sides. Bounded only below, a bearing that had
        # fallen apart into a 5mm rattle would pass; bounded only above,
        # a seized one would.
        lo, hi = 0.10, 0.60
        if worst_ov > 0.5:
            fail(f"{a}/{b}: {worst_ov:.1f} mm3 of interference -- {why}")
        elif not (lo <= worst_gap <= hi):
            fail(f"{a}/{b}: running fit is {worst_gap:.2f} mm, outside "
                 f"{lo}..{hi} -- {why}")
        else:
            ok(f"{a}/{b}: running fit {worst_gap:.2f} mm -- {why}")
    elif intent == MESH:
        if worst_ov > 0.5:
            fail(f"{a}/{b}: teeth interfere by {worst_ov:.1f} mm3 at "
                 f"az={worst_pose[0]:.0f} tilt={worst_pose[1]:.0f} -- {why}")
        elif worst_gap > MESH_MAX:
            fail(f"{a}/{b}: teeth never come closer than {worst_gap:.2f} mm "
                 f"-- they are not engaged. {why}")
        else:
            ok(f"{a}/{b}: meshed, closest {worst_gap:.2f} mm -- {why}")
    elif intent == DESIGNED_TOUCH:
        patch = contact_area(body(a), body(b), 0.25)
        if worst_ov > TOUCH_EPS:
            fail(f"{a}/{b}: bearing faces interpenetrate by {worst_ov:.1f} "
                 f"mm3 -- {why}")
        elif worst_gap > 0.15:
            fail(f"{a}/{b}: never touches (closest {worst_gap:.2f} mm) -- "
                 f"{why}. A load path that does not touch carries nothing.")
        elif patch < MIN_PATCH:
            fail(f"{a}/{b}: contact patch is only {patch:.0f} mm2 -- a corner "
                 f"or an edge, not a bearing face. {why}")
        else:
            ok(f"{a}/{b}: bears on {patch:.0f} mm2 -- {why}")
    elif intent == THREADED:
        if worst_ov > 200:
            fail(f"{a}/{b}: {worst_ov:.0f} mm3 of thread interference -- "
                 f"too much to be flank phase. The diameters clash. {why}")
        else:
            ok(f"{a}/{b}: threads clear ({worst_ov:.0f} mm3 of flank "
               f"overlap at an arbitrary phase) -- {why}")
    elif intent == RIGID:
        if worst_ov > 0.5:
            fail(f"{a}/{b}: {worst_ov:.1f} mm3 of interference -- {why}")
        else:
            ok(f"{a}/{b}: keyed, no interference -- {why}")

# Nothing unchecked. A pair nobody classified is a pair nobody looked at.
print("\n== coverage ==")
ALL = PARTS + ["payload", "payload_disc"]
unchecked = []
for i, a in enumerate(ALL):
    for b in ALL[i + 1:]:
        if (a, b) in EXCLUDED or (b, a) in EXCLUDED:
            continue
        if (a, b) not in covered and (b, a) not in covered:
            unchecked.append(f"{a}/{b}")
CHECKS += 1
if unchecked:
    warn(f"{len(unchecked)} pairs carry no declared intent: "
         + ", ".join(unchecked))
else:
    ok("every pair has a declared intent")


# ---------------------------------------------------------------------
# 4. Cross-project: the two claims this directory makes about ../mount.
# ---------------------------------------------------------------------
print("\n== against ../mount ==")
pay = trimesh.load(HERE.parent / "mount" / "build" / "base.stl")
v = pay.vertices
r = np.hypot(v[:, 0], v[:, 1])
CHECKS += 1
if r.max() > P["payload_arm_r"]:
    fail(f"payload reaches {r.max():.1f} mm, past the {P['payload_arm_r']:.0f} "
         f"mm this riser designs to")
else:
    ok(f"payload arm reaches {r.max():.1f} mm <= {P['payload_arm_r']:.0f} mm")

# The disc, separately: the part of the footprint that is true at EVERY
# orientation the payload could be screwed down at.
CHECKS += 1
disc_r = np.percentile(r, 90)
if P["payload_r"] < MOUNT["base_plate_r"]:
    fail(f"payload_r {P['payload_r']:.0f} is under ../mount's own "
         f"base_plate_r {MOUNT['base_plate_r']:.0f} -- the disc does not fit")
else:
    ok(f"payload_r {P['payload_r']:.0f} >= mount base_plate_r "
       f"{MOUNT['base_plate_r']:.0f}")

# The stud has to actually reach the nut it is supposed to thread into.
# Read from ../mount, not copied.
CHECKS += 1
if P["stud_protrude"] < MOUNT["tripod_nut_t"]:
    fail(f"the platter's stud stands proud {P['stud_protrude']:.1f} mm but "
         f"../mount's captured nut is {MOUNT['tripod_nut_t']:.1f} mm thick "
         f"-- it never fully engages")
else:
    ok(f"stud {P['stud_protrude']:.1f} mm engages mount's "
       f"{MOUNT['tripod_nut_t']:.1f} mm nut")

# The riser's own bottom end no longer has a 1/4-20 socket at all -- it
# bolts straight to the tripod's plate with three posts and a big stud.
# There is nothing left here to check against ../mount, and an assert that
# cannot fail is worse than no assert: it reads as coverage.


# ---------------------------------------------------------------------
# 5. Range of motion, and the things that are not geometry.
# ---------------------------------------------------------------------
print("\n== range and hand loads ==")
reached, first_clash = None, None
for tl in np.arange(0, float(P["tilt_max_deg"]) + 5.001, 5.0):
    clash = False
    for other in ("az_column", "yoke", "az_handle", "pedestal",
                  "tilt_handle"):
        if overlap_volume(body(other, 0.0, float(tl)),
                          body("payload_disc", 0.0, float(tl))) > 0.5:
            clash = True
            break
    if clash:
        first_clash = float(tl)
        break
    reached = float(tl)
CHECKS += 1
if reached is not None and reached >= float(P["tilt_max_deg"]):
    ok(f"tilt reaches the designed {P['tilt_max_deg']:.0f} deg with the "
       f"payload clear")
else:
    fail(f"tilt only reaches {reached} deg; first clash at {first_clash}")

# NOT asserts. These rest on two payload numbers nobody has weighed, and a
# geometric checker has no business failing a build over a claim about a
# human hand. Reported, and reported as what they are.
CHECKS += 1
if P["knob_force_req"] > P["knob_force_limit"]:
    warn(f"the tilt knob needs {P['knob_force_req']:.0f} N at the rim against "
         f"a {P['knob_force_limit']:.0f} N comfort limit "
         f"({P['knob_force_req']/P['knob_force_limit']:.1f}x). REASONED from "
         f"ASSUMED payload mass and CG height -- weigh the mount. The fix is "
         f"a different tooth split at the same centre distance.")
else:
    ok(f"tilt knob rim force {P['knob_force_req']:.0f} N")

CHECKS += 1
if P["tilt_clamp_force"] > P["clamp_hand_limit"]:
    warn(f"the trunnion needs {P['tilt_clamp_force']:.0f} N of preload, past "
         f"the ~{P['clamp_hand_limit']:.0f} N a hand reaches on a wing nut")
else:
    ok(f"trunnion preload {P['tilt_clamp_force']:.0f} N is hand-reachable")


print(f"\n{'='*66}")
print(f"{CHECKS} checks, {len(FAILURES)} failed, {len(WARNINGS)} warnings")
for f in FAILURES:
    print(f"  FAIL  {f}")
for w in WARNINGS:
    print(f"  WARN  {w}")
sys.exit(1 if FAILURES else 0)
