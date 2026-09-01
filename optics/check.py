#!/usr/bin/env python3
"""Geometric verification for the optics parts.

OpenSCAD is write-only: it renders geometry but cannot be asked questions
about it. This closes that gap — it exports parts to STL and queries the
meshes directly, so design errors fail an assertion instead of hiding in
a render that looks plausible.

Motivating case: the rack-and-pinion focus mechanism shipped three bugs
at once (rack teeth facing away from the pinion, pinion center distance
taken from pitch_radius() instead of gear_dist(), and the gear sitting a
whole knob-height out of the rack's plane). All three survived visual
review of a perspective render. None survive this script.

  nix develop --command python optics/check.py

THE CENTRAL CAVEAT, since it is easy to get wrong: "the parts never
intersect" is NOT evidence that a gear pair meshes. Two gears parked a
metre apart also never intersect. Tooth engagement needs BOTH:

  * no interference  -> intersection volume ~ 0 at every sweep step
  * actual contact   -> min surface distance stays near 0 at every step

Checking only the first is the classic false pass. Both are asserted
below, and the proximity bound is what makes the test meaningful.
"""

import math
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
import trimesh

HERE = Path(__file__).resolve().parent
LIB = HERE / "lib"

# Sweep resolution. One tooth period is 360/teeth degrees; sampling well
# inside that catches a clash mid-engagement rather than only at the
# tooth-aligned poses, which are the poses least likely to collide.
SWEEP_STEPS_PER_PERIOD = 12

# Sweep several tooth periods, not one. A travel rate derived from a
# slightly wrong radius stays within tolerance for the first period and
# drifts out of phase over later ones — a single-period sweep passes it.
# Phase error accumulates linearly, so 4 periods makes it visible.
SWEEP_PERIODS = 4

# Tolerances, mm. INTERFERE_TOL is a hair above zero to absorb the STL
# tessellation of an involute curve — a perfectly meshing pair still
# shows a few um of facet overlap.
INTERFERE_TOL_MM3 = 1.0

# CONTACT_TOL bounds how far the surfaces may drift apart before the pair
# is not meaningfully engaged. Keep this TIGHT: a loose value is how the
# "no interference" check becomes a false pass, since a pair spaced too
# far to ever touch trivially satisfies it. At module 1 a printed pair
# wants ~0.05-0.15mm backlash, so a few tenths is the honest ceiling —
# not millimetres.
CONTACT_TOL_MM = 0.30

SAMPLE_POINTS = 4000

# Pairs that are DESIGNED to touch (a gear mesh) need their own rule.
# Faceted involute flanks in contact always interpenetrate a little, so
# they can never satisfy the global interference limit. But simply
# raising that limit for them would re-open the hole a 392 mm^3
# knob-through-plate collision already slipped through once.
#
# So discriminate by SHAPE, not just magnitude. Measured, real tooth
# tessellation is a thin sliver: 4.0 mm^3 spread over the full 8mm face
# width and 3 separate tooth patches, but only 1.5mm thick. A part
# genuinely buried in another is chunky in every direction. Requiring
# the overlap to be thin catches the second while tolerating the first,
# and stays meaningful even if the volume grows with a finer $fn.
MESH_CONTACT_TOL_MM3 = 8.0
MESH_SLIVER_MAX_MM = 2.5    # max of the overlap's SMALLEST bbox extent


def scad_render(body: str, out_stl: Path, extra_header: str = "") -> trimesh.Trimesh:
    """Render an inline OpenSCAD snippet to STL and load it."""
    src = f"""
include <params.scad>
include <lib/BOSL2/std.scad>
include <lib/BOSL2/gears.scad>
$slop = 0.1;
{extra_header}
{body}
"""
    with tempfile.NamedTemporaryFile("w", suffix=".scad", dir=HERE, delete=False) as fh:
        fh.write(src)
        tmp = Path(fh.name)
    try:
        proc = subprocess.run(
            ["openscad", "-o", str(out_stl), str(tmp)],
            capture_output=True, text=True,
        )
        if proc.returncode != 0:
            raise RuntimeError(f"openscad failed:\n{proc.stderr[-2000:]}")
    finally:
        tmp.unlink(missing_ok=True)
    return trimesh.load(out_stl, force="mesh")


def scad_value(expr: str, includes=()) -> float:
    """Evaluate a scalar OpenSCAD expression, so Python never restates a
    number the .scad files already own.

    `includes` pulls in a part file's own top-level variables (include<>,
    not use<>, since use<> imports modules but not values). Restating a
    dimension here instead has produced two false FAILs already: a
    hardcoded rack_y that drifted when the CAD moved the rack, and a
    hand-derived travel sign. If a number lives in a .scad file, ask
    OpenSCAD for it — do not retype it."""
    extra = "\n".join(f"include <{f}>" for f in includes)
    src = f"""
include <params.scad>
include <lib/BOSL2/std.scad>
include <lib/BOSL2/gears.scad>
{extra}
echo(RESULT={expr});
"""
    with tempfile.NamedTemporaryFile("w", suffix=".scad", dir=HERE, delete=False) as fh:
        fh.write(src)
        tmp = Path(fh.name)
    try:
        # needs a real suffix; openscad picks its exporter from the
        # extension and refuses /dev/null
        sink = tmp.with_suffix(".csg")
        proc = subprocess.run(
            ["openscad", "-o", str(sink), str(tmp)],
            capture_output=True, text=True,
        )
        sink.unlink(missing_ok=True)
        for line in proc.stderr.splitlines():
            if "RESULT" in line:
                return float(line.split("RESULT =")[1].strip().rstrip(")"))
        raise RuntimeError(f"no RESULT echoed for {expr!r}:\n{proc.stderr[-1500:]}")
    finally:
        tmp.unlink(missing_ok=True)


def min_surface_distance(a: trimesh.Trimesh, b: trimesh.Trimesh) -> float:
    """Approximate min surface-to-surface distance by sampling A and
    querying B's nearest surface. Sampling, so it is an upper bound on
    the true minimum — fine for a clearance check, not for metrology."""
    pts, _ = trimesh.sample.sample_surface(a, SAMPLE_POINTS)
    _, dist, _ = b.nearest.on_surface(pts)
    return float(dist.min())


def interference(a: trimesh.Trimesh, b: trimesh.Trimesh):
    """Boolean intersection. Returns (volume_mm3, min_bbox_extent_mm,
    n_bodies). The extent and body count are what let a caller tell a
    tessellation sliver from a part genuinely buried in another."""
    # cheap reject: disjoint AABBs cannot overlap
    amin, amax = a.bounds
    bmin, bmax = b.bounds
    if np.any(amax < bmin) or np.any(bmax < amin):
        return 0.0, float("inf"), 0
    inter = trimesh.boolean.intersection([a, b], engine="manifold", check_volume=False)
    if inter is None or inter.is_empty:
        return 0.0, float("inf"), 0
    return (abs(float(inter.volume)),
            float(min(inter.extents)),
            len(inter.split(only_watertight=False)))


def interference_volume(a: trimesh.Trimesh, b: trimesh.Trimesh) -> float:
    return interference(a, b)[0]


def check_rack_and_pinion(workdir: Path) -> bool:
    print("=" * 72)
    print("RACK AND PINION — tooth engagement sweep")
    print("=" * 72)

    mod = scad_value("gear_mod")
    teeth = scad_value("pinion_teeth")
    dist = scad_value(
        "gear_dist(mod=gear_mod, teeth1=pinion_teeth, teeth2=0,"
        " pressure_angle=gear_pressure_angle)"
    )
    naive = scad_value("pitch_radius(mod=gear_mod, teeth=pinion_teeth)")
    shift = scad_value(
        "auto_profile_shift(teeth=pinion_teeth, pressure_angle=gear_pressure_angle)"
    )
    pa = scad_value("gear_pressure_angle")
    travel_per_rev = math.pi * mod * teeth
    undercut_teeth = 2.0 / math.sin(math.radians(pa)) ** 2

    print(f"  module {mod}, {int(teeth)} teeth, {pa:.0f} deg pressure angle")
    print(f"  gear_dist()    = {dist:.4f} mm   <- correct mesh distance")
    print(f"  pitch_radius() = {naive:.4f} mm   <- naive, {dist - naive:+.4f} mm error")
    print(f"  travel/rev     = {travel_per_rev:.3f} mm")
    print()

    # Profile shift identity. Below the undercut threshold BOSL2 silently
    # applies a positive shift, and the operating distance becomes
    # r_pitch + x*mod. Asserting the identity means a future change to
    # module/teeth/pressure_angle that alters the shift cannot quietly
    # invalidate a hand-copied center distance.
    print(f"  undercut threshold 2/sin^2(a) = {undercut_teeth:.2f} teeth")
    print(f"  {int(teeth)} teeth is "
          f"{'BELOW' if teeth < undercut_teeth else 'above'} it "
          f"-> profile shift x = {shift:.6f}")
    identity_err = abs(dist - (naive + shift * mod))
    ok_identity = identity_err < 1e-4
    print(f"  gear_dist == r_pitch + x*mod ? err={identity_err:.2e} "
          f"-> {'PASS' if ok_identity else 'FAIL'}")
    print()

    # Pinion: axis along Y, centered on origin.
    pinion = scad_render(
        "rotate([90,0,0]) spur_gear(mod=gear_mod, teeth=pinion_teeth,"
        " thickness=gear_thickness, pressure_angle=gear_pressure_angle,"
        " shaft_diam=0, anchor=CENTER);",
        workdir / "pinion.stl",
    )
    # Rack: pitch line at x=+gear_dist, teeth pointing -X (toward the
    # pinion at the origin), length along Z (the travel axis).
    rack = scad_render(
        "translate([gear_dist(mod=gear_mod, teeth1=pinion_teeth, teeth2=0,"
        " pressure_angle=gear_pressure_angle), 0, 0])"
        " rotate([0,-90,0]) rack(mod=gear_mod, teeth=14,"
        " thickness=gear_thickness, pressure_angle=gear_pressure_angle,"
        " anchor=CENTER);",
        workdir / "rack.stl",
    )

    print(f"  pinion watertight: {pinion.is_watertight}   "
          f"rack watertight: {rack.is_watertight}")
    if not (pinion.is_watertight and rack.is_watertight):
        print("  !! non-watertight input; boolean results are unreliable")
    print()

    tooth_period = 360.0 / teeth
    worst_overlap = 0.0
    worst_gap = 0.0
    rows = []
    total_steps = SWEEP_STEPS_PER_PERIOD * SWEEP_PERIODS

    for i in range(total_steps):
        theta = tooth_period * i / SWEEP_STEPS_PER_PERIOD   # degrees
        # Rolling without slipping, and the SIGN IS NOT ARBITRARY. The
        # contact point sits at (+r,0,0) from the pinion center; rotating
        # +theta about +Y maps it to (r*cos, 0, -r*sin), i.e. toward -Z.
        # So the rack travels -Z as the pinion turns +theta. Getting this
        # backwards drives the teeth into each other and reports a 34
        # mm^3 clash on a pair that is actually fine — a false FAIL that
        # looks exactly like a real center-distance bug.
        travel = -travel_per_rev * theta / 360.0         # mm

        p = pinion.copy()
        p.apply_transform(
            trimesh.transformations.rotation_matrix(math.radians(theta), [0, 1, 0])
        )
        r = rack.copy()
        r.apply_transform(trimesh.transformations.translation_matrix([0, 0, travel]))

        vol = interference_volume(p, r)
        gap = min_surface_distance(p, r)
        worst_overlap = max(worst_overlap, vol)
        worst_gap = max(worst_gap, gap)
        rows.append((theta, vol, gap))

    for theta, vol, gap in rows[:: max(1, total_steps // 10)]:
        print(f"    theta={theta:7.2f} deg   overlap={vol:9.4f} mm^3   gap={gap:6.4f} mm")
    print()

    # Per-period worst gap. If the travel rate is subtly wrong, phase
    # drifts and the later periods degrade relative to the first — that
    # trend is the signal a single-period sweep cannot show.
    per_period = []
    for p in range(SWEEP_PERIODS):
        chunk = rows[p * SWEEP_STEPS_PER_PERIOD:(p + 1) * SWEEP_STEPS_PER_PERIOD]
        per_period.append(max(g for _, _, g in chunk))
    print("  worst gap by tooth period (drift check):")
    print("    " + "  ".join(f"P{p + 1}={g:.4f}" for p, g in enumerate(per_period)))
    drift = max(per_period) - min(per_period)
    ok_phase = drift <= CONTACT_TOL_MM / 2
    print(f"    spread = {drift:.4f} mm -> {'PASS' if ok_phase else 'FAIL'}"
          "  (rising trend => wrong travel rate)")
    print()

    ok_no_clash = worst_overlap <= INTERFERE_TOL_MM3
    ok_engaged = worst_gap <= CONTACT_TOL_MM

    print(f"  worst interference : {worst_overlap:9.4f} mm^3  "
          f"(tol {INTERFERE_TOL_MM3})  -> {'PASS' if ok_no_clash else 'FAIL'}")
    print(f"  worst surface gap  : {worst_gap:9.4f} mm    "
          f"(tol {CONTACT_TOL_MM})  -> {'PASS' if ok_engaged else 'FAIL'}")
    if not ok_no_clash:
        print("    teeth collide — center distance too small, or wrong tooth form")
    if not ok_engaged:
        print("    teeth never approach — parts too far apart, or teeth face")
        print("    the wrong way. THIS is the check that a bare intersection")
        print("    test would have silently passed.")
    print()
    return ok_no_clash and ok_engaged and ok_phase and ok_identity


def check_integrity(workdir: Path) -> bool:
    """Per-part sanity that interference testing structurally cannot do.

    Both checks here exist because a human spotted the defect in a render
    after every clearance test passed. Neither failure mode involves two
    parts touching, so no pairwise check could ever have seen them:

      * a DISCONNECTED body floats free, attached to nothing. It is still
        watertight and still interferes with nothing.
      * a BLOCKED optical bore is solid where light must pass. It also
        interferes with nothing — it is missing absence, not present
        excess.
    """
    print("=" * 72)
    print("PART INTEGRITY — connectivity and the optical path")
    print("=" * 72)

    # expected connected-body count. focus_pinion() is an assembly of
    # three genuinely separate objects (gear, knob, stock axle), so 3 is
    # correct there; the printed parts must each be exactly 1.
    parts = [
        ("base_mount", "use <objective_focus_mount.scad>\n", "base_mount();", 1),
        ("carrier", "use <pcb_carrier.scad>\n", "pcb_carrier();", 1),
        # one body now: gear, shaft and knob are a single printed part.
        # They always rotated together; the separate rod only existed
        # because closed bearing bores could not be threaded past the
        # gear, and the snap-fit bearings removed that constraint.
        ("pinion", "use <focus_pinion.scad>\n", "focus_pinion();", 1),
    ]
    ok_all = True
    meshes = {}
    for name, hdr, body, want in parts:
        m = scad_render(body, workdir / f"int_{name}.stl", extra_header=hdr)
        meshes[name] = m
        bodies = m.split(only_watertight=False)
        ok = len(bodies) == want
        ok_all &= ok
        note = "" if ok else f"  <- expected {want}; something is floating free"
        print(f"  {name:12s} {len(bodies)} connected "
              f"{'body ' if len(bodies) == 1 else 'bodies'}  "
              f"watertight={m.is_watertight}  {'PASS' if ok else 'FAIL'}{note}")
        if not ok:
            for i, b in enumerate(sorted(bodies, key=lambda x: -abs(x.volume))):
                print(f"      body{i}: vol={abs(b.volume):9.1f} mm^3  "
                      f"bbox {b.bounds[0].round(1)} .. {b.bounds[1].round(1)}")
    print()

    # Does the bearing actually EXIST? A running-fit distance check
    # cannot tell a real bore from a deleted one: with the boss removed
    # entirely, nearby arm material still returned a plausible 0.175mm
    # gap and the pair passed. An over-large edge chamfer silently
    # deleted both bosses exactly this way. So probe for solid material
    # in a ring around the bore axis, in each arm.
    base = meshes["base_mount"]
    py = scad_value("rack_y - gear_dist(mod=gear_mod, teeth1=pinion_teeth,"
                    " teeth2=0, pressure_angle=gear_pressure_angle)")
    pz = scad_value("pinion_z")
    ax = scad_value("arm_x", includes=["objective_focus_mount.scad"])
    bore_r = scad_value("bearing_d", includes=["objective_focus_mount.scad"]) / 2
    ring_r = bore_r + 1.4
    for sgn in (-1, 1):
        angles = np.arange(0, 360, 15)
        pts = np.column_stack([
            np.full_like(angles, sgn * ax, dtype=float),
            py + ring_r * np.cos(np.radians(angles)),
            pz + ring_r * np.sin(np.radians(angles)),
        ])
        solid = base.contains(pts)
        # the snap throat is a deliberate gap at the top, so not every
        # sample can be solid — but most of the ring must be
        frac = solid.mean()
        ok = frac >= 0.6
        ok_all &= ok
        centre_open = not base.contains(np.array([[sgn * ax, py, pz]]))[0]
        ok_all &= centre_open
        print(f"  bearing x={sgn * ax:+.1f}: {frac * 100:.0f}% of the ring is solid, "
              f"bore centre {'open' if centre_open else 'BLOCKED'}  "
              f"{'PASS' if ok and centre_open else 'FAIL'}")
    print()

    # The light path: march up the optical axis through the base. Any
    # sample inside the solid means the bore is closed.
    zs = np.arange(-1.0, base.bounds[1][2] + 1.0, 0.25)
    axis = np.column_stack([np.zeros_like(zs), np.zeros_like(zs), zs])
    inside = base.contains(axis)
    clear = not inside.any()
    ok_all &= clear
    if clear:
        print(f"  optical axis CLEAR through the base "
              f"(z {zs.min():.1f} .. {zs.max():.1f})   PASS")
        for z in (0.5, 4.0, 6.0, 8.0):
            r = np.arange(0, 11, 0.1)
            p = np.column_stack([r, np.zeros_like(r), np.full_like(r, z)])
            ins = base.contains(p)
            rad = r[ins].min() if ins.any() else r.max()
            print(f"      z={z:4.1f} mm   clear to r={rad:.2f} mm")
    else:
        blocked = zs[inside]
        print(f"  optical axis BLOCKED at z={blocked.min():.2f}..{blocked.max():.2f}"
              f"   FAIL  <- no light path")
    print()
    return ok_all


def check_assembly(workdir: Path) -> bool:
    """Whole-assembly pairwise interference, parts in their assembled
    positions. Answers the question a per-part check cannot: given these
    transforms, does anything collide that shouldn't, and does anything
    that should be a sliding fit actually have clearance?"""
    print("=" * 72)
    print("ASSEMBLY — pairwise interference at assembled positions")
    print("=" * 72)

    tube_len = scad_value("tube_len_nominal")
    holder_h = scad_value("holder_h")
    clearance = scad_value("clearance")
    carrier_z = tube_len + holder_h

    # Read straight out of pcb_carrier.scad rather than restating them.
    rack_y = scad_value("rack_y", includes=["pcb_carrier.scad"])
    engage_margin = scad_value("rack_engage_margin", includes=["pcb_carrier.scad"])
    pinion_dist = scad_value(
        "gear_dist(mod=gear_mod, teeth1=pinion_teeth, teeth2=0,"
        " pressure_angle=gear_pressure_angle)"
    )
    pinion_z = carrier_z - engage_margin   # grounded just below the plate
    print(f"  rack_y={rack_y:.3f}  gear_dist={pinion_dist:.4f}  "
          f"pinion_y={rack_y - pinion_dist:.3f}  pinion_z={pinion_z:.1f}")

    parts = {
        "base_mount": "base_mount();",
        "carrier": f"translate([0,0,{carrier_z}]) pcb_carrier();",
        # The whole pinion INCLUDING the knob. Leaving the knob out of
        # the assembly check is what let a 392 mm^3 knob-through-plate
        # collision ship: the pinion pair was excluded wholesale on the
        # reasoning that gear and rack are *supposed* to touch, and that
        # exemption silently covered the knob too.
        "pinion": f"translate([0,{rack_y - pinion_dist},{pinion_z}])"
                  f" rotate([0,90,0]) focus_pinion();",
    }
    hdr = ("use <objective_focus_mount.scad>\n"
           "use <pcb_carrier.scad>\n"
           "use <focus_pinion.scad>\n")

    meshes = {}
    for name, body in parts.items():
        meshes[name] = scad_render(body, workdir / f"asm_{name}.stl",
                                   extra_header=hdr)
        m = meshes[name]
        print(f"  {name:14s} watertight={m.is_watertight}  "
              f"vol={m.volume:9.1f} mm^3  bbox={np.round(m.extents, 2)}")
    print()

    # (a, b, must_not_touch, label)
    # inner/outer tube are a deliberate slip fit: they must NOT interfere
    # but SHOULD sit within a couple of clearances of each other.
    pairs = [
        # The carrier's tube slides in the base's bore — that IS the
        # linear bearing, so they must stay close but never interfere.
        ("carrier", "base_mount", False,
         f"tube-in-sleeve bearing (design clearance {clearance} mm/side)"),
        # Gear and rack SHOULD touch, so this pair is allowed contact —
        # but only tooth-flank contact. Anything past a few mm^3 means
        # some other part of the pinion assembly (in practice the knob)
        # is buried in the carrier.
        ("pinion", "carrier", "mesh",
         "gear meshes with rack; knob and axle must clear the carrier"),
        # The axle runs THROUGH the yoke bearings on a running fit: it
        # must be closely surrounded but never actually touch. That is a
        # fit, not a mesh — calling it "mesh" demands contact the design
        # deliberately avoids, and reports a bearing working correctly as
        # a failure.
        ("pinion", "base_mount", False,
         "axle running fit in the yoke bearings"),
    ]

    ok_all = True
    for a_name, b_name, mode, label in pairs:
        a, b = meshes[a_name], meshes[b_name]
        vol, sliver, bodies = interference(a, b)
        gap = min_surface_distance(a, b)
        note = ""

        if mode == "mesh":
            # Contact is expected. Allow it only as a thin sliver — a
            # buried part is chunky in every direction.
            ok = vol <= MESH_CONTACT_TOL_MM3 and sliver <= MESH_SLIVER_MAX_MM
            # Order matters: with no overlap at all, sliver is +inf, so
            # testing thickness first reports "inf mm thick" — technically
            # true, completely misleading. Check for no-contact first.
            if vol == 0.0:
                ok = False
                note = "  <- no contact at all; the pair is not engaged"
            elif vol > MESH_CONTACT_TOL_MM3:
                note = "  <- overlap too large for tooth contact"
            elif sliver > MESH_SLIVER_MAX_MM:
                note = f"  <- overlap is {sliver:.2f}mm thick, not a contact sliver"
        else:
            ok = vol <= INTERFERE_TOL_MM3
            if not ok:
                note = "  <- COLLISION"
            elif mode is True and gap < 0.5:
                ok = False
                note = "  <- too close, expected clear separation"
            elif mode is False and gap > 4 * clearance:
                ok = False
                note = "  <- gap far exceeds design clearance; not a fit"

        ok_all &= ok
        extra = (f"  sliver={sliver:.2f}mm bodies={bodies}"
                 if mode == "mesh" and vol > 0 else "")
        print(f"  {a_name:12s} vs {b_name:12s} overlap={vol:8.3f} mm^3  "
              f"gap={gap:6.3f} mm  {'PASS' if ok else 'FAIL'}{note}")
        print(f"    {label}{extra}")
    print()
    return ok_all


def main() -> int:
    if not LIB.exists():
        print("optics/lib missing — run inside `nix develop`", file=sys.stderr)
        return 2
    if shutil.which("openscad") is None:
        print("openscad not on PATH — run inside `nix develop`", file=sys.stderr)
        return 2

    workdir = Path(tempfile.mkdtemp(prefix="optics-check-"))
    try:
        results = {
            "integrity": check_integrity(workdir),
            "rack_and_pinion": check_rack_and_pinion(workdir),
            "assembly": check_assembly(workdir),
        }
    finally:
        shutil.rmtree(workdir, ignore_errors=True)

    print("=" * 72)
    failed = [k for k, v in results.items() if not v]
    for name, ok in results.items():
        print(f"  {'PASS' if ok else 'FAIL'}  {name}")
    print("=" * 72)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
