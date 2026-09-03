# Making CAD models legible to an agent

How to verify OpenSCAD geometry programmatically instead of rendering a
picture and squinting at it. Written after four bugs in the rack-and-pinion
focus mechanism survived visual review of a perspective render.

## The problem

OpenSCAD is **write-only**. It renders geometry but cannot be asked
questions about it. There is no way to ask "are these two parts touching",
"how far apart are they", "do they interfere" — you find out by looking at
a picture.

BOSL2's anchors do not close this gap. They are declarative points computed
from a primitive's *nominal* geometry, before any boolean runs — not
measurements of the actual resulting solid.

### The bugs this let through

All four were in a rack-and-pinion mechanism that had been rendered,
reviewed, and reported as working:

1. **Rack teeth faced the wrong way.** `rotate([0,90,0])` maps +Z to +X,
   pointing the teeth into the carrier plate instead of at the pinion.
   `rotate([0,-90,0])` is correct.
2. **Pinion center distance wrong.** Used `pitch_radius()` (6.000mm)
   instead of `gear_dist()` (6.298mm) — see below.
3. **Gear was in a different plane from the rack.** `focus_pinion()`
   stacked the knob at local z=0..10 and the gear at z=10..18, so after
   the assembly's `rotate([90,0,0])` the gear landed at y=-18..-10 while
   the rack sat at y=-4..+4. The 12-flute knob reads exactly like gear
   teeth in an isometric view, so the render looked like a working mesh.
4. **Pinion attached to nothing.** No frame part existed to ground its
   shaft.

Bugs 1, 2 and 3 were all visible in a single **orthographic view down the
pinion axis** — and all invisible in the perspective isometric view that
had been used for review.

## gear_dist() vs pitch_radius()

BOSL2's `spur_gear()` defaults to `profile_shift="auto"`. Below ~17 teeth,
a standard involute tooth undercuts at the root, so the generator shifts
the tooth form outward to compensate. That shift changes the operating
center distance.

    module 1, 12 teeth, 20 deg pressure angle:
      pitch_radius()  = 6.0000 mm      <- naive, WRONG for meshing
      gear_dist()     = 6.2981 mm      <- correct
      auto profile shift = 0.2981

Using `pitch_radius()` buries the teeth 0.3mm too deep and the pair binds.
**Always `gear_dist()` for center distance; `pitch_radius()` only for the
rolling/travel relationship.**

Travel per pinion revolution is unaffected by profile shift:
`pi * module * teeth` = 37.699 mm/rev here.

## Tooling: trimesh + manifold3d

Both are cached in nixpkgs — no compilation. Wired into `flake.nix` as
`opticsPython`, available in `nix develop`.

    python3Packages.trimesh      # queries
    python3Packages.manifold3d   # boolean engine (trimesh ships none)
    python3Packages.rtree        # REQUIRED: proximity queries import it
    python3Packages.scipy        #   lazily, so they fail at call time
    python3Packages.numpy

`rtree`/`scipy` are not optional. `mesh.nearest.on_surface()` imports them
at call time, not import time, so their absence surfaces as a crash
mid-run rather than an ImportError up front.

Evaluated and rejected:

- **CadQuery / build123d** — genuinely better query APIs (real B-rep,
  selectors, `distToShape()`), but neither is in nixpkgs and both need OCP
  wheels that are painful under Nix. More importantly, their joints would
  NOT have caught bug 2: that was a wrong *number*, not a wrongly applied
  *transform*. Joints apply whatever value you give them, precisely.
- **PyBullet / MuJoCo** — rigid-body engines use convex decomposition,
  which mangles involute tooth profiles. Wrong tool for gear verification.
- **Open3D** — not in nixpkgs. Exact BVH distance queries would beat
  trimesh's sampling, but not worth the dependency here.
- **FreeCAD headless** — installed, same OCCT primitives, useful as an
  interop bridge for STEP/STL from elsewhere. Heavier API; not needed yet.

## The verification that matters

`assemblies/optics/check.py`. The critical design point, because it is easy to get
wrong:

> **"The parts never intersect" is not evidence that a gear pair meshes.**
> Two gears parked a metre apart also never intersect.

Tooth engagement requires **both** conditions, at every step of a sweep:

- no interference — boolean intersection volume ~ 0
- actual contact — min surface distance stays near 0

Checking only the first is a silent false pass that a too-far-apart or
wrong-facing pair sails through.

### The sweep, and its sign

For theta across one tooth period, rotate the pinion by theta and
translate the rack by the rolling-without-slipping distance, then test
both conditions.

**The travel sign is not arbitrary.** The contact point sits at (+r,0,0)
from the pinion center; rotating +theta about +Y maps it to
(r*cos, 0, -r*sin) — toward -Z. So the rack travels -Z.

Getting this backwards drives the teeth together and reports a ~34 mm^3
clash on a pair that is actually fine. That false FAIL looks exactly like
a real center-distance bug. Observed directly:

    travel = +   worst_overlap = 33.7816 mm^3   (false FAIL)
    travel = -   worst_overlap =  0.0001 mm^3   (correct: meshes)

Its signature is diagnostic: overlap peaking mid-tooth and vanishing at
the symmetric poses (theta=0 and half-period) means a direction error, not
a distance error. A real center-distance error clashes at *every* pose.

### Two gaps a naive sweep has

**Sweep several tooth periods, not one.** A travel rate derived from a
slightly wrong radius stays inside tolerance through the first period and
drifts out of phase over later ones. Phase error accumulates linearly, so
a single-period sweep passes a pair that crashes a few periods later.
`check.py` sweeps 4 periods and reports the worst gap per period — a
rising trend across periods means a wrong travel rate, distinct from a
wrong center distance.

**Keep the contact tolerance tight.** A loose bound is how the "no
interference" check quietly becomes the false pass it was meant to
prevent: a pair spaced too far to ever touch satisfies it trivially. At
module 1 a printed pair wants ~0.05-0.15mm backlash, so a few tenths is
the honest ceiling. `CONTACT_TOL_MM = 0.30`. Millimetre-scale tolerances
here would accept a mechanism that never engages.

### The profile-shift identity, worth asserting

Pitch radius `r = m*N/2` is fixed by module and teeth alone; profile shift
does **not** move it. What the shift moves is the *operating* center
distance:

    gear_dist  ==  pitch_radius + x * module

Verified exactly for this pair (difference 0.0 to full precision):

    profile_shift x  = 0.298133
    r_pitch          = 6.00000
    r_pitch + x*mod  = 6.29813
    gear_dist()      = 6.29813

Undercut threshold is `2/sin^2(alpha)` = 17.10 teeth at 20 deg, and this
pinion has 12 — comfortably below, so the shift is applied and is not
incidental. Asserting the identity means a later change to module, teeth,
or pressure angle cannot silently invalidate a hand-copied center
distance.

## The checker is a bug source too

Every false FAIL in this project so far has come from the checker, not
the design. Both had the same root cause: **check.py restating geometry
that a .scad file already owns.**

1. **Travel sign.** The sweep translated the rack +Z when rolling
   contact requires -Z, reporting a 34 mm^3 clash on a sound pair.
2. **Stale rack_y.** The CAD moved the rack from `-(plate_d/2 - 2)` to
   `-plate_d/2`; check.py kept the old formula, placed the pinion 2mm
   too close, and reported 80 mm^3 of buried teeth.

Fix: `scad_value(expr, includes=[...])` pulls values straight out of the
part files via `include<>` (`use<>` imports modules but not variables).
No dimension is retyped in Python. The derived positions print on every
run so drift is visible rather than silent.

**Operational rule: on a FAIL, ask "is the checker right?" before
touching the CAD.** A verification tool built alongside the design
inherits the design's drift. Diagnostic signatures help:

- overlap peaking mid-tooth and vanishing at the symmetric poses
  => direction/sign error, not a distance error
- a real center-distance error clashes at *every* pose

## Classify pairs by intent, not one global tolerance

Parts designed to touch (a gear mesh) can never satisfy a global
interference limit — faceted involute flanks always interpenetrate a
little. But simply raising the limit for them re-opens the hole a 392
mm^3 knob-through-plate collision already slipped through.

So `check_assembly()` classifies each pair:

| mode | meaning | rule |
| -- | -- | -- |
| `True` | must stay clear | no overlap, and real separation |
| `False` | slip fit | no overlap, but not so far it isn't a fit |
| `"mesh"` | contact expected | thin sliver only, and non-zero |

The mesh rule tests **shape, not just magnitude**: real tooth
tessellation is 4.0 mm^3 spread over the full 8mm face width in 3
discrete tooth patches but only **1.5mm thick**, while a part genuinely
buried in another is chunky in every direction (the bad case measured
3.38mm thick). Requiring a thin sliver tolerates the first and catches
the second, and survives a change to `$fn` that shifts the volume.

A blanket exemption on a pair is not the same as an exemption on the one
feature that justifies it — excluding pinion-vs-carrier wholesale
because gear and rack are *supposed* to touch is exactly what let the
knob collision through.

## Two more real bugs the renders never showed

- **Knob coaxial with the gear.** A 28mm knob has a radius far larger
  than the gap between the pinion axis and the carrier plate, so it
  sweeps through the plate from *any* Z position — not fixable by
  repositioning. 392 mm^3. The gear and knob are now separate printed
  parts on a common 4mm shaft, knob outboard past the plate's X edge,
  which is how real microscope focus blocks are built and decouples
  knob diameter from clearance entirely.
- **Rack backing fouling the tube.** Checking the rack's *pitch line*
  against the tube radius (11.5 > 9) looked fine, but BOSL2's rack
  backing extends `2*dedendum + addendum` behind the pitch line,
  reaching y=-8.875 against a 9mm tube — a 0.125mm interference, small
  enough to read as rounding error. Rack pitch line now sits flush with
  the plate edge: +1.875mm clearance.

## The bug class no interference check can catch

The pinion was originally translated with the carrier, so it rode along
instead of being grounded to the frame. Every part was individually
well-formed and non-interfering, and the mechanism still could not
function, because the wrong body was held fixed.

That is a **kinematic** error, not a geometric one. No clearance or
interference test detects it — it needs someone to ask what is supposed
to move relative to what. `assembly.scad` now derives the carrier's
position FROM the pinion angle via the rolling relationship, so the two
cannot drift out of step, and the pinion's Z is explicitly independent
of carrier travel.

### What the sweep does NOT prove

- Nothing about **backlash adequacy for a printed part** — it tests
  nominal geometry, not as-printed dimensions with elephant-foot,
  over-extrusion, or shrinkage.
- Nothing about **binding under load**, friction, or torque.
- Min-distance is **sampled**, so it is an upper bound on the true
  minimum — a clearance check, not metrology.
- It verifies the pair in **isolation**. It cannot see that the pinion is
  attached to nothing (bug 4) — that is an assembly-level question.

## Rendering, for the cases where looking is still the tool

VLM spatial reasoning has real limits (benchmarks put inter-object
relational accuracy below 0.3; mental rotation is the weakest category).
Do not trust a render for metric judgments. Orientation and
contact/no-contact *are* reliable — but only if the render shows the
discriminating feature. The job is converting "requires mental
simulation" into "requires recognition":

    openscad -o view.png --imgsize=1000,1000 --projection=ortho \
      --autocenter --viewall --render --camera=0,0,0,<rot>,140 model.scad

- **`--render` matters.** Default preview mode can hide boolean/manifold
  errors that full CGAL evaluation exposes.
- **Orthographic, down the axis of interest.** Perspective isometric views
  hide axial offsets and make tangency ambiguous — that is what let bugs
  1-3 through.
- Canonical view rotations (`rot_x,rot_y,rot_z` in the 7-number gimbal
  form): top `0,0,0`, front `90,0,0`, right `90,0,270`, left `90,0,90`,
  iso `55,0,25`. Combine with `--autocenter --viewall` and only the
  rotation matters.
- **Contact sheets**: render N canonical views, tile with
  `magick montage ... -tile 2x2 -label '%f'`. Labels matter — without
  them a view can be misattributed.
- **`#` to highlight a suspect part, `%` to ghost its neighbours.** The
  highest-leverage trick for "is this actually attached".
- **Cutaway** via `difference()` with a half-space cube, for interior and
  contact questions a solid exterior render hides.

Render for orientation and topology. Assert for numbers.
