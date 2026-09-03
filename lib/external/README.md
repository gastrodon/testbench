# `lib/external/` — things we did not make

Every other `.scad` file in this repo describes something we intend to
produce. These describe things that already exist: bought, salvaged or
scavenged objects, modelled so a design can be built *around* them.

That difference changes what a file here is for, and what counts as a
defect in one.

- **The deliverable is the envelope and the interface**, not the part. A
  spoked hub drawn as a solid disc is fine — better than fine, it is the
  conservative answer to the only questions these files exist to answer.
  A bore diameter that is off by 0.3mm is not fine, because something
  will be printed to fit it.
- **Every dimension carries its provenance**, in the file, next to the
  number: `MEASURED`, `DERIVED` (computed from measurements), `INFERRED`
  / `REASONED` (argued for from other readings — say from what), or
  `DRAWN` (shape only; nothing depends on it fitting). A number with no
  tag is a bug. This is `AGENTS.md`'s rule 7 for findings, applied to
  constants, and it exists because "we measured that" and "that looked
  about right" are indistinguishable six weeks later.
- **Sheet letters are kept verbatim.** Each file names its source field
  sheet and labels each constant with that sheet's letter, so a
  re-measure can be diffed against the file letter by letter instead of
  by guessing which caliper reading became which variable.
- **Self-contained, like the rest of `lib/`.** No `params.scad`, no
  BOSL2, no assembly-specific anything. Same reasoning as
  `../motors/nema17.scad`: a dryer roller is not a feature of any one
  build here, and the next project that has one should be able to copy
  one file.
- **Origin is the interface, stated explicitly at the top of every
  module.** The pivot for a strut, the axle centreline for a wheel, the
  socket end for a tube. A part positioned by its own mounting feature
  does not need every caller to rediscover the same offset.

## What is here

| File | Part | Source sheet | State |
| --- | --- | --- | --- |
| `roller_wheel.scad` | Dryer drum support roller, 80.1mm OD | `wheel-field-sheet.html` | recorded, mm |
| `threaded_tube.scad` | Tube section, male stud / female socket | `tube-field-sheet.html` | recorded, inches |
| `extension_spring.scad` | Extension spring, hook both ends | `spring-field-sheet.html` | recorded, inches |
| `friction_strut.scad` | Sliding lid-stay: plastic housing + steel rod | `friction-strut-field-sheet.html` | **not measured** |

Two of the sheets record in **inches**. Those files convert in source
(`tube_in()`, `spring_in()`) and never in a person's head, so the
constants can still be read straight off the sheet.

## The one that is not done

**`friction_strut.scad` has no measurements.** Its field sheet has all
twelve letters drawn with leader lines and not one value behind them,
where the other three sheets say "recorded" and carry their readings. The
file therefore models the shape and takes every lettered dimension as a
required argument: calling it without one asserts, naming the letter.

Nothing can be fitted to that strut until someone spends ten minutes with
calipers and the sheet. It is not blocked on modelling.

## What is unverified, per part

Worth knowing before something gets printed against one of these:

- **Roller wheel, letter F (overall width, 32.85mm).** Inferred from the
  axle's stopper span, not a caliper reading — the sheet says so itself.
  Every other wheel dimension is measured, and the tread thickness is
  double-measured and agrees to the digit (asserted in the file). A
  pocket sized to hold this wheel is resting on the one number nobody
  took directly.
- **Threaded tube, the female thread's major diameter.** The sheet's
  derived readout says it equals the through bore, which cannot be true
  — the part's own male stud is 0.095" larger than that and the two ends
  plainly chain. Modelled as a counterbore at the stud's major diameter;
  the full argument is in the file. One caliper reading down the socket
  settles it.
- **Threaded tube, letter N (female thread count).** Never recorded, so
  the female pitch is assumed equal to the male. Fine for envelope, not
  for cutting a mating thread.
- **Extension spring, coil count and rate.** Nobody counted the coils;
  the count is derived from the body length on the (strong, but still
  inferred) grounds that an extension spring is wound closed. The
  material was never established, so `spring_rate()` takes the modulus as
  a required argument, and it ignores initial tension entirely — any
  force it yields is a floor, not a prediction.

## Verification

Rendered and measured with OpenSCAD directly (2026-09-03): every module
here exports a manifold solid whose bounding box matches its measured
overall dimensions, sectioned to confirm the internal features (bore
diameters, counterbore depth, neck OD) land where the sheets put them.
`friction_strut.scad` was exercised with placeholder numbers only, since
it has none of its own — that check proves the geometry composes, not
that it matches the real strut.
