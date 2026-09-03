# `mount/` — motorized alt-az pan/tilt for the Power Seeker 50AZ

Two driven axes carrying the toy refractor: unlimited azimuth, 0–90°
altitude, giving hemispherical pointing. Tracked as
[EVA-296](https://linear.app/gastrodon/issue/EVA-296).

This directory does **not** touch the optical train. The camera, the
nosepiece and everything in `../optics` and the eva-319 `tele/` worktree
are out of scope here by instruction.

## The headline finding: they are pulleys, not gears

The brief asked for gears driving each axis at ratio `N`, with the
stepper's existing gear at `N/8`. The salvaged steppers **do not have
gears on them.** They carry **20-tooth GT2 timing-belt pulleys** —
[EVA-297](https://linear.app/gastrodon/issue/EVA-297) confirms this two
independent ways (a direct tooth count, and a controlled inked-tooth roll
that agreed to 0.6%). A GT2 pulley cannot mesh with a spur gear.

So the 8:1 reduction is a **belt drive**, decided with eva at the
keyboard: the existing 20T pulley drives a printed **160T** GT2 pulley on
each axis. `N = 160`, the motor pulley is `N/8 = 20`, and because both are
integer tooth counts the ratio is *exactly* 8:1 rather than approximately.

Per full step of a 1.8° stepper, each axis moves `360/(200·8)` = **0.225°**;
at 1/16 microstepping, 0.0141°. Pointing resolution will not be the
limiting factor — backlash and mount rigidity will be.

## Parts

| file | what it is | moves with |
| -- | -- | -- |
| `base.scad` | **ground.** Tripod plate (captured 1/4"-20 nut), azimuth post + thrust face, azimuth stepper on radial tension slots | — |
| `az_table.scad` | rotating deck with the 160T azimuth wheel integral to it | azimuth |
| `yoke.scad` | the single tine that goes between the telescope's brackets; carries the altitude stepper | azimuth |
| `alt_rotor.scad` | 160T altitude wheel **and its integral stepped axle** | telescope |
| `nema17.scad` | the stepper, as a standalone copy-anywhere component | — |
| `gt2.scad` | pulley generator, plus a printable pulley for a D-shaft | — |
| `gt2_coupon.scad` | tooth-profile test coupon, print this first | — |
| `params.scad` | **every dimension.** No number is restated anywhere else | — |
| `assembly.scad` | the posed mechanism; the only file that knows how things move | — |
| `pose.scad` | emits one body at its assembly pose, for the checker | — |
| `check.py` | measured verification | — |
| `animate.scad` / `animate.sh` | range-of-motion animation | — |
| `views.sh` | orthographic review renders | — |
| `build.sh` | render every part, `--hardwarnings` | — |

## How the telescope actually attaches

The brief's "the screw goes sideways" is the alt-az pivot. Two brackets
face each other under the tube: one plain hole, one brass **1/4"-20**
insert. **That screw axis is the altitude axis.** Our tine is the meat in
the telescope's sandwich, not the other way round.

The wheel and its shaft are **one part**, inserted from the **threaded**
side, diameter decreasing monotonically from wheel to tip:

```
[160T wheel]==[1/4-20 thread]==[journal 4.8]==[M4 tip]--> lock nut
                     |               |            |
            threaded bracket     yoke tine    plain 6.25 hole
```

The monotonic taper is what makes it assemblable: everything inboard of
the thread has to pass through the insert's **5.2 mm** bore on the way in.
That one number caps the journal.

Three things this buys over a separate bolt:

1. **Torque goes through a thread**, not through bolt-clamp friction plus
   a printed hook catching a bracket edge.
2. **The shoulder is integral.** The journal/tip step bears on the far
   bracket's inner face, so clamp load runs thread → axle → step → far
   bracket and never touches the tine. Without it the lock nut squeezes
   the tine and the axis seizes — and a seized axis interferes with
   nothing and passes every geometric check ever written.
3. **It resolved the 6.25 mm blocker.** A 1/4-20 shank does not fit the
   measured plain hole. Entering from the threaded side means only the
   4 mm tip ever goes there.

The thin sections carry no drive torque — the thread sits immediately
inboard of the wheel, so torque transfers to the telescope right there.
The tip is domed so it can find three coaxial holes blind.

The lock nut is load-bearing, not tidy: drive torque reacts across the
1/4-20 and the altitude axis reverses constantly, so half the reversals
tend to unscrew it.

## The tightest budget in the design: 10.25 mm around the pivot

The tube's underside sweeps a cylinder about the altitude axis, and with
`tube_bottom_above_pivot` at the assumed 10.25 mm that cylinder is *tiny*.
**Everything the yoke puts inside the tube's width has to fit under it, at
every altitude angle** — not just at 0° and 90°. That single constraint
sets the pivot boss diameter and forces the motor arm's inboard beam to
duck under a trim plane. Two separate features violated it independently before it was
written down once.

It also drives the altitude wheel outboard. A 103 mm wheel on a pivot that
close to the tube cuts straight through the telescope, so `rotor_hub_h` is
**derived** — it stands the wheel's inboard face 3 mm clear of the tube
surface, which needs a 17 mm hub. That is a long cantilever carrying a big
wheel and is the least rigid thing in the assembly.

`tube_bottom_above_pivot` is ASSUMED at the worst case and is deliberately
*not* the same number as the measured `alt_bore_c_to_bottom` (10.25) —
that one is the axle above the mount's base plate, and the brackets hang
below the tube. Measuring it is likely to relax all of the above at once.

## Why the yoke is tall

Not styling. A 160T wheel is ~102 mm across and hangs ~51 mm below the
altitude axis, so the axis must sit high enough for the wheel to clear the
deck. `alt_axis_z` is derived from exactly that. **The height is a
consequence of the 8:1 ratio.** A smaller ratio would give a shorter, more
rigid mount; that tradeoff is real and is eva's call, not a defect.

## Measure these before printing anything large

`params.scad` tags every constant `MEASURED` / `ASSUMED` / `STANDARD` /
`CHOSEN` / `DERIVED`. Most of the interface is now measured. What is left,
in order of how much damage a wrong guess does:

1. **`belt_loop_len` (400 mm assumed).** Still the single biggest unknown.
   Only one *closed* GT2 loop is on hand and its length was never
   recorded. A closed loop fixes the centre distance **absolutely** — at
   400 mm it comes out **100.1 mm**, which is why both motors sit so far
   out. A 320 mm loop would put them at ~60 mm and make the whole rig
   dramatically more compact. Loops under ~306 mm cannot wrap this pulley
   pair at all; `belt_centre_dist()` returns `undef` and it is asserted
   on, not silently propagated.
   The tension slots are a **trim, not a range** — ±1 tooth of
   measurement error plus print shrink. If the real loop is far off,
   change the parameter; do not stretch the slot to cover it.
2. **`tube_len_behind` (320 mm assumed)** — decides the altitude ceiling
   outright. Order of magnitude confirmed by eye, so the ~52° ceiling is
   a real limit rather than an artefact, but the exact number is not.
3. **`tube_bottom_above_pivot` (10.25 mm assumed, worst case)** — the
   binding constraint on the yoke's whole upper half. Measuring it likely
   *relaxes* three things at once.
4. **`bracket_w`, `bracket_free_r`** — the last two bracket unknowns.
5. **`belt_width`**, **`tube_od`**.

**Already measured off the real hardware** (eva, 2026-09-02) — these were
on this list and have come off it:

| | |
| -- | -- |
| bracket gap / thickness / plain hole | 16.5 / 4.9 / 6.25 |
| axle centreline above the base plate | 10.25 |
| stepper body | 42.3 frame, **33** deep |
| shaft | **5.0 × 12**, flat chord 3.5 → across-flat 4.285 |
| pulley | 8 mm tall, belt-face centre **8 mm** off the faceplate |

The stepper lives in `nema17.scad` as a standalone, copy-anywhere
component — the same four salvaged motors are headed for the camera dome,
the laser gimbal and the microscope rebuild. Its **flat length** is
*deferred, not pending*: nothing here reads it, and it matters the day
`gt2_pulley_on_shaft()` is used for real.

## Altitude reach: ~52 degrees, measured

| altitude | result |
| -- | -- |
| 30–50° | clear |
| 55° | first graze — 3.8 mm³ against the base plate |
| 60° | hard collision — 246 mm³ into the deck, 1189 mm³ into the base |

**The ceiling is ~52°, not 90°.** The tube's tail swings down as it tilts
and strikes the base plate and the rotating deck.

A word on how this was nearly mis-reported. `check.py` originally measured
the tail against the plane `z = 0` and called it "ground", which put the
ceiling at **~14°**. The arithmetic was right and the claim was wrong:
`z = 0` is the tripod *mounting face*, and on a real tripod that is free
air — the tail may swing below it freely. A checker can measure the wrong
thing perfectly accurately. The number that binds comes from the swept
must-clear pairs, because those are collisions with hardware that exists.

`tube_len_behind` is ASSUMED at 320 mm and drives all of it — it depends
on where along the tube the bracket pair sits, which nobody has measured.
Three ways to raise the ceiling, and which is right depends on that:

- **measure it first** — a shorter tail behind the pivot buys altitude
  directly;
- **a taller yoke or a riser**, which costs rigidity on a tipping load;
- **a narrower base** — the tail currently strikes a 62 mm-radius plate
  and a 51.7 mm-radius deck, and both are wider than they strictly need
  to be.

Not patched by nudging a number until the check went green.

## Verification

```
./build.sh                       # render every part, --hardwarnings
nix develop -c python3 check.py  # measured geometric verification
```

```
./animate.sh          # range-of-motion animation (mp4 + gif)
```

The animation is the one check a still render cannot do at all: a
mechanism whose "moving" joint is actually clamped solid looks perfect in
every static view and interferes with nothing. It runs the full designed
altitude range on purpose, including the part where the tube's tail
swings through the base — stopping at the last angle that looked tidy
would hide the design's one open question.

`check.py` checks **two conditions, not one**: no interference *and*
sustained contact. "Nothing overlaps" is satisfied by two parts a metre
apart, so designed-to-touch pairs (the thrust face, the altitude journal,
the rotor-to-bracket clamp) are tested for a distributed contact patch,
and must-clear pairs are swept across the whole altitude range rather than
checked at one pose. Unclassified pairs are reported as **unchecked**, not
as passing.

Every number `check.py` uses is read back out of OpenSCAD at runtime. It
restates nothing.

## Current verdict

`check.py`, last run: **17 pairs classified, 0 unchecked, 3 failures** —
and all three are one issue. Everything mechanical passes, measured:

| | |
| -- | -- |
| reduction | **exactly 8:1** — integer tooth counts |
| wheel | **160 grooves**, counted off the mesh |
| altitude bearing | runs at **0.250 mm** across the whole sweep |
| rotor → telescope | clamped; the 42.9 mm³ "overlap" **is** the thread engagement (analytic annulus 42.7) |
| thrust face | seated, 17.9% contact patch |
| belt solve | round-trips to 0.001 mm |

The three failures are the **altitude reach** group — `telescope` against
`yoke` / `az_table` / `base` at 60° and beyond. One issue, one cause
(`tube_len_behind`), left failing on purpose. Measured ceiling: **~52°**.

## Open items, not silently designed around

- **Unlimited azimuth means the altitude motor's cable has to go
  somewhere.** Either a slip ring or an unwind-between-sessions habit.
  Not solved here.
- **The GT2 tooth flank is an approximation**, though the pitch geometry
  is exact and confirmed against the real measured pulley. Print
  `gt2_coupon.scad` and roll the real belt on it before committing hours
  of filament to a 160T wheel — the same settle-it-by-print method the
  microscope build used on its M12 thread.
- **The 1/4-20 male thread is unproven.** It is now the only
  load-bearing thread in the mechanism, and it is modelled as a plain
  cylinder at major diameter rather than a cut thread form — deliberately,
  because a modelled thread would look authoritative and prove nothing.
  It needs its own coupon before the real wheel is printed.
- **`nema17_flat_len` is deferred, not pending.** Nothing in this build
  reads it; it matters the day `gt2_pulley_on_shaft()` is used for real.
- **No altitude limit switch or homing datum.** Steppers are open-loop;
  something has to define where 0° is.
