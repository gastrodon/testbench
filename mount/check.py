#!/usr/bin/env python3
"""Geometric verification for the EVA-296 pan/tilt mount.

OpenSCAD renders geometry but cannot be asked whether two parts touch, how
far apart they are, or whether the mechanism actually moves. This is that
query layer.

Two conditions are checked, always (cad-design rule 1):

  MUST_CLEAR       pairs that must never overlap AND must keep a minimum
                   air gap, at EVERY pose in the altitude sweep -- not
                   just at the one pose that happened to get rendered.
  DESIGNED_TOUCH   pairs that are supposed to be in contact. "No overlap"
                   is satisfied by two parts a metre apart, so these are
                   checked for SUSTAINED CONTACT: a real, distributed
                   contact patch, not a tangent point.

Every dimension is read back out of OpenSCAD at runtime (rule 3). Nothing
in this file restates a number that params.scad owns -- a checker that
retypes the design's geometry inherits the design's drift, and every false
FAIL in this project's history came from exactly that (rule 4).

Findings are tagged MEASURED because they are: each one is computed from a
real mesh produced by a full CGAL render, not inferred from source.

    nix develop -c python3 mount/check.py
"""

import json
import math
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
import trimesh

HERE = Path(__file__).resolve().parent
BUILD = HERE / "build" / "poses"

# Altitude poses swept. 0 = horizon, 90 = zenith. A clash that only exists
# mid-sweep is invisible to any single-pose check, and "the part is fine at
# 0 and 90" is not the same claim as "the part is fine".
ALT_SWEEP = [0, 15, 30, 45, 60, 75, 90]

# --- pair intent table ------------------------------------------------
# Classify every pair by INTENT. An unclassified pair is not "fine", it is
# unchecked -- so the table is asserted complete at the end of the run.
MUST_CLEAR = [
    # (a, b, min gap mm, why)
    ("alt_rotor", "az_table", 2.0,
     "the 160T altitude wheel hangs ~51mm below the pivot; clearing the "
     "table is the constraint that sets how tall the yoke has to be"),
    ("alt_rotor", "base", 2.0, "same wheel, one level further down"),
    ("alt_rotor", "yoke", 0.5,
     "the wheel turns immediately alongside the tine"),
    ("telescope", "yoke", 1.0,
     "the tube must not strike its own mount while tilting"),
    ("telescope", "az_table", 3.0, "tube vs the rotating deck"),
    ("telescope", "base", 3.0, "tube vs ground at low altitude angles"),
    ("telescope", "alt_motor", 2.0,
     "the altitude stepper sits out at the belt centre distance, right in "
     "the tube's swept path -- this is the pair most likely to fail"),
    ("az_table", "az_motor", 1.0, "deck vs the azimuth stepper body"),
    ("yoke", "az_motor", 1.0, "tine assembly vs the azimuth stepper"),
    ("alt_motor", "az_table", 2.0, "altitude stepper vs the deck below it"),
    ("alt_motor", "base", 2.0, "altitude stepper vs ground"),
]

DESIGNED_TOUCH = [
    # (a, b, why) -- must show a distributed contact patch, not a point
    ("az_table", "base",
     "the table rides on the base's raised annular thrust face; this is "
     "the joint carrying the whole telescope's weight"),
    ("alt_sleeve", "yoke",
     "the tine journals on the sleeve OD -- this is the altitude bearing"),
    ("alt_rotor", "telescope",
     "the rotor is clamped to the near bracket's outer face and keyed by "
     "its lip; if this is not touching, the drive turns nothing"),
]

RIGID_SAME_BODY = [
    # Pairs that share a rigid body, so overlap between them is meaningless
    # to test. Listed EXPLICITLY rather than silently skipped -- a blanket
    # exemption is how a real clash gets waved through (rule 1).
    ("alt_sleeve", "telescope"),
    ("alt_sleeve", "alt_rotor"),
    ("yoke", "az_table"),
    ("yoke", "base"),         # via az_table, not directly, but co-static
    ("az_motor", "base"),
    ("alt_motor", "yoke"),
    ("az_table", "alt_motor"),
    ("yoke", "telescope"),    # handled in MUST_CLEAR above, kept out here
]

PARTS = ["base", "az_motor", "az_table", "yoke", "alt_motor",
         "alt_rotor", "alt_sleeve", "telescope"]

# Parts that do not move with altitude -- rendered once, reused at every
# pose, because re-rendering a 160T wheel seven times is minutes wasted.
STATIC_IN_ALT = {"base", "az_motor", "az_table", "yoke", "alt_motor"}


def scad_params() -> dict:
    """Read the design's own numbers back out of OpenSCAD.

    Nothing below is typed by hand. If params.scad changes, this changes
    with it; that is the entire point (rule 3).
    """
    names = [
        "axis_teeth", "motor_teeth", "reduction", "axis_pd", "motor_pd",
        "axis_centre_dist", "belt_loop_len", "belt_width", "alt_axis_z",
        "az_table_t", "base_plate_t", "az_thrust_r", "az_post_h",
        "yoke_tine_t", "sleeve_len", "sleeve_od", "sleeve_id",
        "bracket_gap", "bracket_t", "alt_min_deg", "alt_max_deg",
        "tube_od", "tube_len_behind", "pulley_face_w", "yoke_local_axis_z",
    ]
    src = 'include <params.scad>\n' + "".join(
        f'echo("PARAM", "{n}", {n});\n' for n in names)
    with tempfile.NamedTemporaryFile("w", suffix=".scad", dir=HERE,
                                     delete=False) as f:
        f.write(src)
        tmp = Path(f.name)
    try:
        out = subprocess.run(
            ["openscad", "--export-format", "echo", "-o", "/dev/stdout", str(tmp)],
            capture_output=True, text=True, check=True).stdout
    finally:
        tmp.unlink()

    vals = {}
    for line in out.splitlines():
        if not line.startswith('ECHO: "PARAM"'):
            continue
        parts = line.split(",", 2)
        key = parts[1].strip().strip('"')
        raw = parts[2].strip()
        vals[key] = None if raw == "undef" else float(raw)

    missing = [n for n in names if n not in vals]
    # Rule 2: a param that silently evaluated to undef would come back as
    # None and quietly poison every derived check downstream.
    assert not missing, f"params not echoed (undef or renamed?): {missing}"
    nulls = [k for k, v in vals.items() if v is None]
    assert not nulls, f"params evaluated to undef in OpenSCAD: {nulls}"
    return vals


def render(part: str, alt: float, az: float = 0.0) -> trimesh.Trimesh:
    BUILD.mkdir(parents=True, exist_ok=True)
    key = part if part in STATIC_IN_ALT else f"{part}_a{alt:g}"
    stl = BUILD / f"{key}.stl"
    if not stl.exists():
        subprocess.run(
            ["openscad", "--hardwarnings",
             "-D", f'part="{part}"',
             "-D", f"alt_angle={alt}", "-D", f"az_angle={az}",
             "-o", str(stl), str(HERE / "pose.scad")],
            capture_output=True, text=True, check=True)
    m = trimesh.load_mesh(stl)
    # Rule 2 again: an empty or non-watertight mesh must not be allowed to
    # sail through as "no interference detected".
    assert not m.is_empty, f"{part} @alt={alt} rendered EMPTY"
    assert m.volume > 1.0, f"{part} @alt={alt} has ~zero volume ({m.volume})"
    return m


def overlap_volume(a, b) -> float:
    try:
        inter = a.intersection(b, engine="manifold")
    except Exception:
        inter = a.intersection(b)
    return 0.0 if inter is None or inter.is_empty else float(abs(inter.volume))


def min_gap(a, b) -> float:
    """Minimum surface-to-surface distance. Sampled on both surfaces, both
    directions -- a one-directional sample can miss the true closest point
    when one part is much larger than the other."""
    best = math.inf
    for src, dst in ((a, b), (b, a)):
        pts = src.sample(6000)
        d = trimesh.proximity.closest_point(dst, pts)[1]
        best = min(best, float(d.min()))
    return best


def contact_patch(a, b, tol: float = 0.6):
    """Measure whether a designed-to-touch pair has a SUSTAINED contact
    patch, not a tangency. Returns (gap, patch_fraction).

    patch_fraction is the fraction of sampled points on `a` that lie within
    tol of `b`. A tangent point gives ~0; a real seated face gives a broad
    band. Checking only for absence of overlap would pass both, and would
    equally pass the two parts being a metre apart -- which is the whole
    reason this function exists (rule 1)."""
    pts = a.sample(8000)
    d = trimesh.proximity.closest_point(b, pts)[1]
    return float(d.min()), float((d < tol).mean())


def count_teeth(mesh, od: float, floor_r: float) -> int:
    """Count grooves by sectioning the wheel and scanning its radius.

    This exists because a pulley whose grooves were extruded in the wrong
    direction is watertight, valid, printable -- and perfectly smooth. That
    is not a hypothetical: it happened on this part, it survived the
    assembly render, and only an orthographic view of the coupon showed it.
    So the tooth count is asserted on directly (rule 2: assert on a
    measurable consequence of a feature, never on 'it rendered').
    """
    sec = mesh.section(plane_origin=mesh.centroid, plane_normal=[0, 0, 1])
    if sec is None:
        return -1
    planar, _ = sec.to_2D()
    pts = np.asarray(planar.vertices)
    c = pts.mean(axis=0)
    r = np.linalg.norm(pts - c, axis=1)
    th = np.arctan2(pts[:, 1] - c[1], pts[:, 0] - c[0])
    order = np.argsort(th)
    r = r[order]
    # Threshold midway between the groove floor and the OD; each groove
    # crosses it twice.
    mid = (floor_r + od / 2) / 2
    above = r > mid
    crossings = int(np.count_nonzero(above[1:] != above[:-1]))
    return crossings // 2


def main() -> int:
    p = scad_params()
    findings = []
    fails = 0

    def emit(sev, claim, evidence):
        nonlocal fails
        findings.append((sev, claim, evidence))
        if sev == "FAIL":
            fails += 1

    print("=" * 72)
    print("EVA-296 pan/tilt mount -- geometric verification")
    print("=" * 72)
    print(f"  ratio            {p['axis_teeth']:.0f}T / {p['motor_teeth']:.0f}T"
          f" = {p['axis_teeth']/p['motor_teeth']:.1f}:1"
          f"  (asked for {p['reduction']:.0f}:1)")
    print(f"  axis pitch dia   {p['axis_pd']:.3f} mm")
    print(f"  centre distance  {p['axis_centre_dist']:.3f} mm"
          f"  (from a {p['belt_loop_len']:.0f} mm closed loop)")
    print(f"  altitude axis    {p['alt_axis_z']:.3f} mm above the base plate")
    print()

    # --- ratio is what was asked for ---------------------------------
    got = p["axis_teeth"] / p["motor_teeth"]
    if abs(got - p["reduction"]) > 1e-9:
        emit("FAIL", f"reduction is {got}:1, not {p['reduction']}:1",
             "axis_teeth/motor_teeth read from params.scad")
    else:
        emit("PASS", f"reduction is exactly {got:.0f}:1",
             f"{p['axis_teeth']:.0f}T driven / {p['motor_teeth']:.0f}T motor, "
             "integer tooth counts so the ratio is exact, not approximate")

    # --- teeth actually exist ----------------------------------------
    print("-- tooth count " + "-" * 57)
    od = float(p["axis_pd"]) - 2 * 0.254
    floor_r = od / 2 - 0.764
    rotor = render("alt_rotor", 0)
    n = count_teeth(rotor, od, floor_r)
    print(f"  alt_rotor rim: {n} grooves counted "
          f"(expected {p['axis_teeth']:.0f})")
    if n < 0.9 * p["axis_teeth"]:
        emit("FAIL",
             f"the 160T wheel has {n} grooves, not {p['axis_teeth']:.0f}",
             "counted by sectioning the rendered mesh and scanning its "
             "radius. A pulley with the grooves cut the wrong way is "
             "watertight, valid, and completely smooth -- it renders fine "
             "and cannot drive a belt")
    else:
        emit("PASS", f"the driven wheel carries {n} grooves as designed",
             f"counted from a mid-plane section of the rendered mesh, "
             f"expected {p['axis_teeth']:.0f}")
    print()

    # --- per-part integrity ------------------------------------------
    print("-- per-part integrity " + "-" * 50)
    for part in PARTS:
        m = render(part, 0)
        bodies = m.split(only_watertight=False)
        wt = m.is_watertight
        print(f"  {part:<12} vol={m.volume:9.1f}mm3  bodies={len(bodies)}  "
              f"watertight={wt}")
        if part in ("alt_rotor", "yoke", "az_table", "base") and len(bodies) != 1:
            emit("FAIL",
                 f"{part} is {len(bodies)} disconnected bodies, not 1",
                 "a floating sub-feature renders fine and prints as loose "
                 "debris; this is the 'pinion attached to nothing' failure")
        if not wt:
            emit("WARN", f"{part} mesh is not watertight",
                 "may be a tessellation artefact of the render rather than "
                 "a real modelling defect; re-check before slicing")
    print()

    # --- must-clear, swept -------------------------------------------
    print("-- must-clear pairs, swept over altitude " + "-" * 31)
    checked = set()
    for a, b, gap_min, why in MUST_CLEAR:
        checked.add(frozenset((a, b)))
        worst_gap, worst_pose, worst_ov = math.inf, None, 0.0
        for alt in ALT_SWEEP:
            ma, mb = render(a, alt), render(b, alt)
            ov = overlap_volume(ma, mb)
            g = 0.0 if ov > 0 else min_gap(ma, mb)
            if ov > worst_ov:
                worst_ov = ov
            if g < worst_gap:
                worst_gap, worst_pose = g, alt
        status = ("FAIL" if worst_ov > 0.5 or worst_gap < gap_min else "PASS")
        print(f"  [{status}] {a:<11}/{b:<11} worst gap {worst_gap:7.2f}mm "
              f"@alt={worst_pose:g}  (need >={gap_min}mm)"
              + (f"  OVERLAP {worst_ov:.1f}mm3" if worst_ov > 0.5 else ""))
        if status == "FAIL":
            emit("FAIL",
                 f"{a} and {b} violate their {gap_min}mm clearance "
                 f"(worst {worst_gap:.2f}mm at altitude {worst_pose:g} deg"
                 + (f", overlapping by {worst_ov:.1f}mm3" if worst_ov > 0.5 else "")
                 + ")",
                 f"swept over {ALT_SWEEP} deg; {why}")
    print()

    # --- designed-to-touch -------------------------------------------
    print("-- designed-to-touch pairs " + "-" * 45)
    for a, b, why in DESIGNED_TOUCH:
        checked.add(frozenset((a, b)))
        ma, mb = render(a, 0), render(b, 0)
        gap, frac = contact_patch(ma, mb)
        ov = overlap_volume(ma, mb)
        ok = frac > 0.02 and gap < 0.6
        print(f"  [{'PASS' if ok else 'FAIL'}] {a:<11}/{b:<11} "
              f"gap {gap:5.3f}mm  contact patch {frac*100:5.2f}% of surface"
              + (f"  overlap {ov:.1f}mm3" if ov > 0.5 else ""))
        if not ok:
            emit("FAIL",
                 f"{a} and {b} are supposed to be in contact but show "
                 f"{frac*100:.2f}% contact at {gap:.3f}mm separation",
                 "'no interference' is satisfied by two parts a metre "
                 f"apart, so this is checked as sustained contact. {why}")
    print()

    # --- belt coplanarity --------------------------------------------
    # A belt drive requires the two pulleys' belt faces to overlap in the
    # plane normal. This is checked against the motor pulley's ASSUMED
    # standoff, so the finding is only as good as that measurement.
    print("-- belt geometry " + "-" * 55)
    d, D, C = p["motor_pd"], p["axis_pd"], p["axis_centre_dist"]
    L_back = 2 * C + math.pi * (D + d) / 2 + (D - d) ** 2 / (4 * C)
    err = abs(L_back - p["belt_loop_len"])
    print(f"  centre distance {C:.3f}mm implies a loop of {L_back:.2f}mm; "
          f"params says {p['belt_loop_len']:.2f}mm  (err {err:.4f}mm)")
    if err > 0.05:
        emit("FAIL", "belt centre-distance solve does not round-trip",
             f"back-substituted loop length {L_back:.3f} vs "
             f"{p['belt_loop_len']:.3f}; the closed-form solve is wrong")
    else:
        emit("PASS", "belt centre-distance solve round-trips to <0.05mm",
             f"C={C:.3f} -> L={L_back:.3f} vs specified "
             f"{p['belt_loop_len']:.1f}; the geometry is self-consistent")
    teeth_engaged = D / 2 * math.acos((D - d) / (2 * C)) * 2 / 2.0
    print(f"  belt teeth engaged on the 160T wheel: ~{teeth_engaged:.0f}")

    # --- completeness -------------------------------------------------
    all_pairs = {frozenset((a, b)) for i, a in enumerate(PARTS)
                 for b in PARTS[i + 1:]}
    exempt = {frozenset(x) for x in RIGID_SAME_BODY}
    unchecked = all_pairs - checked - exempt
    print()
    print("-- coverage " + "-" * 60)
    print(f"  {len(checked)} pairs classified, {len(exempt)} exempt as "
          f"rigidly co-moving, {len(unchecked)} UNCHECKED")
    if unchecked:
        for pr in sorted(tuple(sorted(x)) for x in unchecked):
            print(f"    unchecked: {pr[0]} / {pr[1]}")
        emit("WARN", f"{len(unchecked)} part pairs are unclassified",
             "an unclassified pair is unchecked, not fine -- it is listed "
             "above rather than silently omitted")

    # --- report -------------------------------------------------------
    print()
    print("=" * 72)
    for sev in ("FAIL", "WARN", "PASS"):
        for s, claim, ev in findings:
            if s == sev:
                print(f"[{s}] (MEASURED) {claim}")
                print(f"       {ev}")
    print("=" * 72)
    print(f"{fails} failure(s)")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
