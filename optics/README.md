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

Everything's a Nix flake now (`../flake.nix`) — the two libraries are flake
inputs, pinned by commit and content-hashed, not an imperative fetch script:

```
nix develop            # whole toolchain on PATH + optics/lib symlinked to the pinned libs
nix build .#optics-calibration   # renders the calibration STL, verified working
```

- **OpenSCAD** — fully CLI-drivable, no GUI needed.
- **[cfinke/Technic.scad](https://github.com/cfinke/Technic.scad)** — beams,
  pins, axles, gears. Confirmed working: `technic_beam()` renders to a valid
  manifold STL (~53s on this machine — OpenSCAD's CGAL renderer is slow but
  correct; expect real render times, not something to iterate on rapidly).
- **[paulirotta/PELA-blocks](https://github.com/paulirotta/PELA-blocks)** —
  parametric Technic-compatible parts with FDM fit tuning
  (`top_tweak`/`bottom_tweak`/`axle_hole_tweak`), including a print
  calibration beam. This is the one that matters for actually getting a
  clean fit on the Ender 3.
- Libraries are **flake inputs, not vendored** (`lib/` is gitignored, and
  is now a symlink into the Nix store, created by `nix develop`'s
  shellHook) — third-party MIT/CC-BY-SA code, pinned by commit hash +
  content hash in `flake.lock` rather than checked into this repo or
  fetched by a shell script.

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
nix build .#optics-calibration    # -> result/calibration.stl, verified working (~1 min render)
```

Or, inside `nix develop` (equivalent, but lets you pass your own `-D`
flags — e.g. a shorter beam while just checking the pipeline runs):

```
openscad -o calibration.stl -D '_large_nozzle=false' -D '_beam_length=2' calibration.scad
```

(`_large_nozzle=false` because the Ender 3's stock nozzle is 0.4mm, below
PELA's own 0.5mm default threshold — verified this actually changes
behavior, not just cosmetic. The packaged `optics-calibration` build
already bakes this in at the full default beam length — confirmed
rendering real, valid geometry: 19154 vertices, `Simple: yes`, 128
volumes.)

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
