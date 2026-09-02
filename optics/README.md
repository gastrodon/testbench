# optics

A prime-focus digital microscope: the bench webcam's bare sensor sits
behind a toy microscope's 150x objective (Smithsonian/NSI B24014N,
[EVA-295](https://linear.app/gastrodon/issue/EVA-295)) with no eyepiece
and no camera lens in between — so the agent-operable bench can look at
small things, not just the desk. Full derivation and rationale:
[design doc](https://linear.app/gastrodon/document/microscope-camera-design-doc-15a95f836b98).

The webcam is a NexiGo N60; the bench itself is [../README.md](../README.md).

## How it works

Four printed parts. Two of them are the mechanism:

- **`objective_focus_mount.scad`** (`base_mount()`) — FIXED. Holds the
  objective on a real printed thread in its floor, and carries the sleeve
  bore the carrier's tube slides in, plus the pinion yoke.
- **`pcb_carrier.scad`** (`pcb_carrier()`) — MOVING. Screws onto the
  camera's own M12 lens thread (not the two PCB screw holes — the M12
  thread is concentric with the sensor, so it references the carrier to
  the optical axis directly instead of loosely, through hole spacing).
  Carries an integrated rack, and a tube that rides in the base's sleeve.

The tube-in-sleeve fit **is** the linear bearing — no guide rods, no
bushings. Turning **`focus_pinion.scad`**'s knob drives the rack, which
slides the carrier, which changes the sensor-to-objective distance. That
distance is the focus, because the base (and the objective in it) does
not move — only the carrier does.

`technic_adapter.scad` bolts to the side of the base and gives the whole
assembly a LEGO Technic pin interface — provisional structure, until
something more permanent replaces it.

## Why one file per printed body

Each part is its own `.scad` file, matching a physical boundary: a file
is a thing that comes off the bed on its own, in its own best print
orientation (`base_mount()` floor-down, `pcb_carrier_printable()` face-
down, `focus_pinion_printable()` knob-down — each derives its own flip
from its own dimensions rather than a magic number kept elsewhere).
Splitting further, or merging any of these, would break that
correspondence. Shared numbers that more than one part must agree on —
thread specs, gear geometry, the rack/yoke slot width — live in
`params.scad`, included everywhere, so no dimension is ever retyped in a
second file. Retyping is exactly how this project has been bitten before:
a slot half-width once existed under three different names in three
files, and a safety check ended up validating its own private copy
instead of the real one.

Test coupons have all been retired — each settled its question and was
deleted rather than kept as archaeology (the findings live in
`params.scad`, at the values they produced). `assembly.scad` (interactive
Customizer view), `check.py` (geometric proof), and `animate.scad`
(video choreography) are three separate concerns reading the same parts
via `use<>` — kept apart deliberately rather than merged, since each has
a different audience and a different render mode.

## Build and check

```
cd ~/code/testbench
nix build .#optics-stl              # every printable part, pre-oriented -> result/*.stl
nix develop --command python3 optics/check.py
```

`check.py` is the thing that actually proves the design, not a render.
OpenSCAD is write-only — it draws geometry but cannot answer "do these
parts touch" or "does this gear pair mesh." **A bare interference test is
not enough**: two gears parked a metre apart also never intersect. So the
rack-and-pinion check sweeps the mesh through several tooth periods and
asserts *both* no interference *and* sustained near-contact at every
step. It has caught real bugs (wrong travel sign, wrong center distance,
gear and rack in different planes, a knob punched straight through the
carrier plate) that all survived visual review of a rendered assembly.
Read [model-analysis.md](model-analysis.md) before extending `check.py` —
especially: **on a FAIL, ask "is the checker right?" before touching the
CAD.** Every false FAIL so far has come from the checker restating a
number a `.scad` file already owns, not from a real design bug.

To look instead of prove: `openscad optics/assembly.scad`, Window >
Customizer, `focus_t` (0..1 along the travel) and `explode` (0..1). Use
Preview (F5) — a full render (F6) discards `color()`. `optics/lib` must
exist first; it's a symlink into the Nix store that `nix develop`'s
shellHook creates and that Nix garbage-collects periodically — if
OpenSCAD can't find `lib/BOSL2/std.scad`, just re-enter `nix develop`.

## What's settled, what's open

Settled by test print, recorded in `params.scad`:

- Objective cell thread: **M9 x 0.5**. Calipers on the root diameter read
  0.75 and were wrong by exactly one standard pitch — reading a thread by
  hand at this scale isn't accurate enough to pick between adjacent
  standards; a printed 0.5/0.75/1.0 coupon settled it by fit.
- Camera M12 mount: **nominal 11.88mm**, printed at true size, no
  undersize compensation. 11.88 threads into the camera's own holder
  cleanly; 11.68 (0.2 under, the usual bulge-compensation guess) is loose
  enough to slip.
- Labels printed flat on the build sheet beside a part, one layer, no
  brim: **DejaVu Sans ExtraLight at size 5** — a measured 0.35mm stem,
  which is 0.8 of one 0.42mm extrusion — printed with `z_offset` 0.05
  (pressing into the sheet), bed 40C and a 4mm/s first layer. Measured
  stems for reference, since font weight and size together set stroke
  width and neither alone is the dial: Bold@5 1.305mm (~3 passes, the
  original failure), Book@5 0.685 (1.6, the worst case — one bead plus
  ragged gap-fill), Book@3.1 0.425 (1.0 but tiny), ExtraLight@6 0.423
  (1.0), ExtraLight@5 0.35 (0.8, and the one that read best).
  Settled by a strip carrying six font/size candidates side by side.
  Two results worth keeping: a bed at 60C holds PLA at its glass
  transition, which is fine for a solid part but leaves a single-bead
  stroke soft enough to curl off the sheet — 40C fixed the peeling. And
  the *small* candidates read best; size 5 is 0.8 extrusion passes,
  thinner than one bead, and was predicted to drop strokes. It did not.
  Heavier strokes are what fill the counters of 8, 6 and 0, so restraint
  in size beat hitting a whole number of passes.

Still open — nothing has printed far enough to answer these:

- The snap-fit throat that lets the pinion drop into its yoke bearings.
  Its coupon is gone; the real `base_mount` carries the feature and is
  the test now.
- The tube-in-sleeve sliding fit, the mechanism's one bearing. Likewise
  answered by printing the real pair rather than a stand-in.
- Tube length: `tube_len_nominal` in `params.scad` is a starting point
  derived from an *assumed* objective focal length (8-14mm plausible
  range), not a measured one.
- The full assembly has never been printed. Everything above the coupon
  level is proven by `check.py`, not by a physical build.

## Traps that have already cost real time

- **`use<file>` imports modules and functions, not variables.** A part
  file's own top-level assignments are invisible to a `use<>`r. Reading a
  variable that way silently yields `undef`; OpenSCAD prints a warning
  and keeps going, producing a watertight STL with a feature just
  missing — no error, no non-manifold geometry, nothing to catch it. Use
  `include<>` when a file's constants are genuinely needed elsewhere
  (`check.py`'s `scad_value(..., includes=[...])` does this), and prefer
  putting anything two files must agree on in `params.scad` in the first
  place.
- **Never retype a dimension.** If a number lives in a `.scad` file, read
  it from there — `check.py` asks OpenSCAD to `echo()` values rather than
  hand-copying them, specifically because two earlier hand-copies drifted
  and produced false FAILs.
- **`include <file>` does not protect a variable assigned before it** —
  the included file's own assignment silently wins. Only a `-D` flag on
  the command line reliably overrides a Customizer default.

## Toolchain

Nix flake, `../flake.nix`. Both CAD libraries are flake inputs, pinned by
commit and content hash, not vendored or fetched by a shell script:

- **OpenSCAD** — fully CLI-drivable.
- **[cfinke/Technic.scad](https://github.com/cfinke/Technic.scad)** —
  LEGO Technic beams, pins, axles, used for the provisional frame
  interface.
- **[BOSL2](https://github.com/BelfrySCAD/BOSL2)** — general solid
  modelling plus `gears.scad`, used for the rack and pinion. Note:
  `gears.scad` is a separate include from `std.scad` — omitting it lets
  `gear_dist()` resolve to `undef` with only a warning, which has
  produced a watertight, fully-interference-clean STL with the gear
  station built at a garbage position.
- `optics/lib` is gitignored — a symlink to the Nix store, recreated by
  `nix develop`'s shellHook.
