# AGENTS.md — testbench

Orientation for an agent starting a fresh session in this repo. Read
`README.md` and `PROTOCOL.md` for what things do; this file is for how to
not re-break things that were already fixed once.

## What this is

Firmware + host client turning an Arduino Uno into a serial GPIO probe
(`firmware/`, `host/`), plus three unrelated 3D-printed projects that
happen to live in the same repo:

- `optics/` — a prime-focus microscope camera, superseding the earlier
  LEGO/eyepiece-collar plan that older text in `optics/README.md` still
  describes.
- `tele/` — the prime-focus telescope nosepiece (EVA-319), the same
  bare-sensor principle pointed at a 0.965" refractor.
- `mount/` — a motorized alt-az pan/tilt mount for that telescope
  (EVA-296), driven by GT2 belts off the Afinia-salvage steppers.
  `mount/README.md` is current and worth reading first, especially the
  part where the salvaged steppers turn out to carry GT2 PULLEYS, not
  gears. `mount/nema17.scad` is deliberately self-contained (no
  `params.scad`, no telescope) so it can be copied into the other builds
  running on the same four motors.

Part of the
[Shop testbench](https://linear.app/gastrodon/document/testbench-agent-operable-hardware-bench-41d0596a0f66)
— the bench camera and udev plumbing live in `module/hw-bench.nix` in
[gastrodon/dotfiles](https://github.com/gastrodon/dotfiles), not here.

## Ground rules

- **Two separate Go modules on purpose** (`firmware/go.mod`,
  `host/go.mod`). `firmware/` targets bare-metal AVR via TinyGo and must
  stay free of anything TinyGo can't compile. Don't merge them, don't
  import one from the other.
- **Nix-first.** `nix develop` for the toolchain, `nix build .#<name>` for
  reproducible artifacts. Don't reach for `go install`/global package
  managers/imperative fetch scripts if a flake input or derivation can do
  it — see the git log for why (`fetch-libs.sh` → flake inputs,
  `setup-editor.sh` → a devShell-managed derivation, both replaced for
  the same reason: reproducibility, no manual re-run drift).
- **Test before trusting, always.** Every non-obvious fact in this repo
  (below) was found by actually building/flashing/running something, not
  by reasoning about what should work. If you're about to write something
  that "should" work based on how a tool is documented, try it on the real
  thing first — this repo's history is a long list of "should have worked,
  didn't" corrected by testing.
- **Real hardware may be attached.** The Uno enumerates at `/dev/ttyACM0`
  (or `/dev/hw-bench/uno` once `hw-bench.nix` is switched on the host).
  Needs `dialout` group — if your shell session predates that grant, wrap
  commands in `sg dialout -c '...'`. Wrap serial commands in `timeout` to
  avoid hangs.

## Gotchas already found — don't rediscover these

- **Opening the Uno's serial port resets the board** (DTR auto-reset),
  wiping any `MODE` a previous connection configured. Stateful command
  sequences need one held-open connection — `probe`'s batch/stdin mode,
  not separate one-shot CLI invocations. (`host/README` usage section,
  `PROTOCOL.md`)
- **OpenSCAD's `include <file>` does not protect a variable assigned
  before the include line** — the included file's own top-level
  assignment silently wins (console warning only, easy to miss). The only
  override that reliably sticks is `-D` on the command line. (verified by
  direct test, see `optics/README.md`)
- **`-D` does not override OpenSCAD's special (`$`-prefixed) variables.**
  `-D '$t=0.4'` is silently ignored — frames come out byte-identical. The
  only way to drive `$t` is `--animate N`. Cost a confusing round of
  "why do all four spot-check frames look the same".
- **A full render (`--render`, CGAL) discards `color()`.** Review renders
  come out monochrome and unreadable. Use preview mode (the default) for
  anything you intend to *look* at; geometry validity is `check.py`'s job,
  not an eye's.
- **`--viewall --autocenter` reframe every frame independently.** Fine for
  a single still, disastrous for an animation — the model jumps and
  rescales each frame. Animations need a fixed explicit `--camera` sized
  for the *largest* state (usually fully exploded).
- **BOSL2 auto-applies a profile shift below ~17 teeth**
  (`2/sin²(pressure_angle)`), so the operating center distance is
  `pitch_radius + x*module`, not `pitch_radius`. Use `gear_dist()`. The
  naive value buries the teeth (0.3mm at mod 1, 12T) and the pair binds.
- **Union needs volumetric overlap, not contact.** A tab tangent to a
  curved wall (line contact) or a part flush against a face (zero-depth
  contact) both produce non-manifold CGAL output. Overlap deliberately,
  ~1mm.
- **`hull()` fills its own concavity.** Hulling a saddle onto a tube and
  subtracting the bore *first* lets the flare bridge across the passage.
  Subtract critical voids last.
- **trimesh's proximity queries import `rtree` and `scipy` lazily** — they
  fail at call time, not import time, so a missing dep surfaces as a
  crash mid-run rather than an ImportError. Both are in `opticsPython`;
  don't drop them as "unused".
- **`optics/lib` is a Nix-store symlink created by the devShell hook and
  Nix garbage-collects it.** `Can't open include file 'lib/BOSL2/std.scad'`
  means only this; `nix develop` recreates it.
- **`WARNING: Can't open include file 'lib/gears/gears.scad'` is expected
  and harmless** — vendored `Technic.scad` reaching for its own bundled
  gear library, which ships as an empty directory upstream. Nothing here
  calls Technic's gear modules.
- **Merging Go's `runtime` package wholesale (real stdlib + TinyGo's own)
  trips a real Go toolchain safety check** — a cross-platform
  case-insensitivity guard on `asm_386.s` vs `asm_386.S` coexisting, even
  on a case-sensitive Linux filesystem. Fix: only *add* TinyGo-exclusive
  subdirectories/packages, never merge an entire colliding directory.
  (`flake.nix`, `firmwareGoroot`)
- **`cp -rs` (recursive + symlink) inherits the *source's* permission
  bits on newly created destination directories** — copying from the Nix
  store (read-only) produces destination directories you can't write into
  afterward, even though you "own" them. Symlink per-top-level-entry
  instead of copying when merging trees sourced partly from `/nix/store`.
- **A gitignore pattern with a trailing slash (`lib/`) matches plain
  directories but not a symlink pointing at one.** If a Nix-managed
  symlink is showing up as untracked, check for this before assuming
  something else is wrong. (`optics/.gitignore`)
- **`nix run .#<pkg>` assumes the binary is named after the package's
  `pname`.** If the actual binary is named differently (Go names it after
  the `cmd/` subdirectory), `nix run` fails to find it unless
  `meta.mainProgram` is set explicitly.
- **TinyGo shells out to `go` underneath**, which wants a writable `$HOME`
  for its cache — the Nix build sandbox gives none by default
  (`mkdir /homeless-shelter: permission denied`). Set `HOME=$TMPDIR` in
  any derivation that invokes `tinygo build`.
- **`machine` (TinyGo's hardware package) is not a fetchable Go module**
  — no `go.mod`, and its own imports (`device/avr`, `runtime/volatile`)
  assume GOROOT-style resolution. `go.mod` `replace` directives and GOPATH
  are both the wrong tool; a real merged GOROOT (`packages.firmware-goroot`
  in `flake.nix`) is what actually works, verified with `gopls check`.
- **Grabbing a single frame (`ffmpeg -frames:v 1`) right after a state
  change (turning an LED on/off, moving something into frame) can return a
  stale buffered frame from *before* the change** — UVC/V4L2 devices don't
  guarantee the first frame served after a change is a fresh one. Grab
  3-4 frames and use the last, not the first, if you're photographing
  something that just changed. Cost a real misdiagnosis once (reported an
  LED as "not lighting" when it was, in fact, lit — the photo was just
  old).
- **PWM duty cycle is "fraction of time HIGH"** (`PWM <pin> 0` = pin held
  LOW, `PWM <pin> 255` = pin held HIGH). For an LED wired **common-anode**
  with its cathode on the GPIO pin, that's inverted from intuition: `0` is
  brightest (pin sinking current = LED conducting), `255` is fully off.
  Confirm polarity (diode-mode multimeter check: current only flows one
  way) before assuming higher value means brighter.
- **`-tags=arduino_uno` alone isn't enough for gopls to resolve everything
  `tinygo build` can see.** It resolves board-specific files fine
  (`machine.D0`, board pin constants) but leaves chip-specific ones like
  `machine.PWM`/`Timer0`-`Timer2` undefined, since those live behind
  `//go:build avr && (atmega328p || atmega328pb)` — tags `arduino_uno`
  doesn't include. Run `tinygo info -target=arduino-uno` to get the
  *complete* real tag list TinyGo uses internally; `firmware/.vscode/settings.json`
  has the current full list for this target.
- **A flake's `./path` sources only see git-tracked (or staged) files,
  not arbitrary untracked ones in the working tree.** Adding a new file
  and immediately `nix build`ing against it fails confusingly ("directory
  not found") until it's at least `git add`ed — doesn't need to be
  committed, just staged.

## Working on geometry (`optics/`)

**OpenSCAD is write-only: it renders geometry but cannot be asked
questions about it.** You cannot ask whether two parts touch, how far
apart they are, or whether a gear pair engages. BOSL2's anchors don't
close this — they're points on *nominal* primitive geometry, computed
before any boolean runs. So there is a separate query layer, and the
workflow below exists because four real defects shipped past visual
review before it did.

Full write-up with the reasoning: **`optics/model-analysis.md`**. Read it
before extending `check.py`.

### Validate with `check.py`, not with your eyes

```
nix develop --command python optics/check.py
```

trimesh (queries) + manifold3d (booleans). It answers: does anything
interfere, how close is anything, is every part watertight, and does the
rack-and-pinion actually engage across a multi-period sweep.

Four rules that are load-bearing — each exists because violating it
produced a wrong answer:

1. **Two conditions, always.** "Nothing intersects" is *also* satisfied
   by parts too far apart to touch. Engagement needs no-interference
   **and** sustained contact. Checking only the first is a silent false
   pass.
2. **Classify pairs by intent** (`True` must-clear / `False` slip-fit /
   `"mesh"` designed-to-touch), and for mesh pairs **test shape, not
   magnitude**: real tooth tessellation is a thin sliver (~1.5mm) across
   the full face width; a buried part is chunky (~3.4mm). A blanket
   exemption on a pair also covers everything rigidly attached to it —
   that's how a 392mm³ knob-through-plate collision shipped.
3. **Never restate a dimension in Python.** Use
   `scad_value(expr, includes=["pcb_carrier.scad"])` to read it out of
   the CAD. *Both* false failures in this project's history came from
   duplicated geometry drifting out of sync with the design.
4. **On a FAIL, check the checker before touching the CAD.** A
   verification tool built alongside the design inherits the same drift.
   Diagnostic: overlap peaking mid-tooth and vanishing at symmetric poses
   is a *direction/sign* error; a real center-distance error clashes at
   *every* pose.

It proves nothing about as-printed dimensions, behaviour under load, or
parts attached to nothing — min-distance is sampled, so it's an upper
bound, a clearance check and not metrology.

### The bug class no checker catches

The pinion was once translated along with the carrier it was meant to
drive. Every part well-formed, nothing interfering, every clearance
passing — and the mechanism a no-op, because the wrong body was held
fixed. That's a *kinematic* error, invisible to every geometric test.
**Name the grounded body explicitly**, and derive dependent motion rather
than posing it (`assembly.scad` computes the pinion angle *from* carrier
travel, so they can't desynchronise).

### Rendering visuals — genuinely useful, do this

Per-part `color()` plus preview mode. **Orthographic, down the axis of
interest** — one such view exposed three gear defects at once that every
perspective isometric had hidden. Perspective hides axial offsets and
makes tangency ambiguous.

```bash
# canonical still (rot: top 0,0,0 · front 90,0,0 · right 90,0,270 · iso 55,0,25)
openscad -o view.png --imgsize=900,900 --projection=ortho \
  --autocenter --viewall --camera=0,0,0,90,0,0,140 optics/assembly.scad

# contact sheet of several views (montage's font lookup can fail; +append works)
magick a.png b.png c.png -background white +append sheet.png

# animation: --animate is the ONLY way to drive $t; camera must be FIXED
openscad --animate 300 --imgsize=900,1160 --projection=perspective \
  --camera=0,0,28,68,0,0,540 -o /tmp/frames/f.png optics/animate.scad
ffmpeg -framerate 30 -i /tmp/frames/f%05d.png -c:v libx264 -pix_fmt yuv420p out.mp4
```

`optics/animate.scad` owns only choreography (turntable + explode +
focus sweep); geometry and kinematics come from the part files unchanged,
so a rendered animation shows the *real* mechanism rather than a posed
one. `optics/assembly.scad` exposes `focus_t` / `explode` /
`animate_focus` as Customizer sliders for interactive use.

Use `#` to highlight a suspect part and `%` to ghost its neighbours —
the highest-leverage trick for "is this actually attached". Render for
orientation and topology; **measure for numbers**. A view reliably
settles orientation and contact-vs-no-contact, and does not reliably
settle "these are off by 2mm".

## Per-device firmware

Mirrors `host/cmd/`: each `firmware/cmd/<name>/main.go` is a complete,
standalone firmware image for the *whole chip* — these are never combined
into one binary, only one runs on the Uno at a time. `cmd/probe` is the
general-purpose serial GPIO probe everything else here is built around;
other entries (`cmd/light-breathe`) are one-off, hardwired firmwares for a
specific attached peripheral that don't need or use the serial protocol
at all — flash them and they just run, no host required. Each gets its
own `packages.firmware-<name>` output in `flake.nix` via the shared
`mkFirmware` helper.

## Verifying you haven't broken anything

```
nix flake check                    # evaluates everything, cheap
nix build .#probe && result/bin/probe /dev/ttyACM0 ping   # needs real hardware
nix build .#firmware-probe                                  # then flash + ping to confirm
nix build .#firmware-light-breathe                          # then flash + watch it breathe
nix build .#optics-calibration     # real OpenSCAD render, ~1 min
nix develop --command python optics/check.py   # geometry: interference + gear mesh
nix develop -c bash -c 'cd firmware && GOROOT=$(pwd)/.gopls-goroot GOFLAGS=-tags=avr,baremetal,linux,arm,atmega328p,atmega,avr5,arduino_uno,tinygo,purego,osusergo,math_big_pure_go,gc.conservative,scheduler.none,serial.uart,tinygo.unicore gopls check ./cmd/probe/main.go ./cmd/light-breathe/main.go'
```

All of these have been run for real at some point in this repo's history
— none of it is aspirational.
