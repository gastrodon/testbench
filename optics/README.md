# optics

A LEGO Technic + printed-collar coupler to hold the bench webcam ([../README.md](../README.md))
rigidly against the toy microscope's eyepiece (Smithsonian/NSI B24014N,
[EVA-295](https://linear.app/gastrodon/issue/EVA-295)) — so the agent-operable
bench can look at small things, not just the desk. Full research + design
plan: [webcam-microscope-coupler.md](https://linear.app/gastrodon/document/webcam-microscope-coupler-lego-printed-collar-996d07bbeda7)
(Obsidian: `~/notes/project/Lab/webcam-microscope-coupler.md`).

## Status: tooling verified, design not started

Stage 0 (measure the eyepiece, confirm you own common Technic pins/beams) is
a physical task, not something this repo can do. Everything here is Stage 1
— toolchain setup — done and confirmed working, so real design work can
start the moment measurements exist.

## Toolchain

```
./fetch-libs.sh    # vendors lib/Technic.scad and lib/PELA-blocks, pinned commits
```

- **OpenSCAD** (`nix shell nixpkgs#openscad`, or the `openscad-unstable` in
  `module/cad.nix` once that's switched) — fully CLI-drivable, no GUI needed.
- **[cfinke/Technic.scad](https://github.com/cfinke/Technic.scad)** — beams,
  pins, axles, gears. Confirmed working: `technic_beam()` renders to a valid
  manifold STL (~53s on this machine — OpenSCAD's CGAL renderer is slow but
  correct; expect real render times, not something to iterate on rapidly).
- **[paulirotta/PELA-blocks](https://github.com/paulirotta/PELA-blocks)** —
  parametric Technic-compatible parts with FDM fit tuning
  (`top_tweak`/`bottom_tweak`/`axle_hole_tweak`), including a print
  calibration beam. This is the one that matters for actually getting a
  clean fit on the Ender 3.
- Libraries are **fetched, not vendored** (`lib/` is gitignored) — third-party
  MIT/CC-BY-SA code, pinned by commit hash in `fetch-libs.sh` for
  reproducibility rather than checked into this repo.

### A real OpenSCAD gotcha, found by testing

`include <file.scad>` does **not** protect a variable you assigned before
the include — the included file's own top-level assignment silently wins,
with only a console warning (`WARNING: X was assigned ... but was
overwritten in file Y`). Confirmed by direct test. The only override that
reliably sticks is a `-D` flag on the command line:

```
openscad -o calibration.stl -D '_large_nozzle=false' calibration.scad
```

`calibration.scad` in this directory documents this — don't try to override
PELA's customizer defaults by assigning variables before its `include` line,
it won't do anything.

## Print the calibration beam first

Before any real part: print PELA's calibration beam, measure which
tolerance segment actually fits your printer + filament, and record the
offset. Every part after this uses that number.

```
openscad -o calibration.stl -D '_large_nozzle=false' calibration.scad
```

(`_large_nozzle=false` because the Ender 3's stock nozzle is 0.4mm, below
PELA's own 0.5mm default threshold — verified this actually changes
behavior, not just cosmetic.) Add `-D '_beam_length=N'` to shorten/lengthen
the printed strip; smaller prints faster if you just want to confirm the
pipeline (a 2-segment beam renders in ~11s here; the fuller default is
slower and untested end-to-end — expect a few minutes).

## Stage 0 — blocking, physical, not automatable

- [ ] Caliper the B24014N eyepiece OD, and figure out if it's removable
  from the microscope body or fixed in place. **This single measurement
  decides the whole collar design** — do not design anything before this.
- [ ] Confirm (Brickit scan, or just eyeballing the bins) that common
  Technic pins/beams are actually in the pile before designing around them.

## The two experiments to run once a collar exists

Per the research findings, this specific webcam (NexiGo N60, confirmed
fixed-focus, 110° FOV) is not a great afocal candidate on its own — its
wide field of view will vignette hard against a toy-scope exit pupil. Two
things worth actually trying, not just one:

1. **Afocal, lens-on**: camera lens intact, positioned at the eyepiece's
   eye relief distance, centered on-axis. Use `zoom_absolute=20` (the
   confirmed-real 2× digital crop) to cut the vignette at the cost of
   resolution. Rack the *microscope's* focus slightly past visual-focus to
   compensate for the camera's non-infinity fixed focus (~0.5m-4m) — small
   correction, well inside a microscope's focus travel.
2. **Lens-off, prime focus**: remove the webcam's own lens, let the
   eyepiece (or the microscope's optics directly) project onto the bare
   sensor. Sidesteps the 110° FOV problem entirely — likely the better
   result on this specific hardware, at the cost of a more invasive,
   less reversible camera modification.

Build the collar to support trying both before committing to one.
