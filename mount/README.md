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
| `alt_sleeve.scad` | shoulder bushing on the altitude axis | telescope |
| `alt_rotor.scad` | 160T altitude wheel + hub that clamps to the near bracket | telescope |
| `gt2.scad` | pulley generator | — |
| `gt2_coupon.scad` | tooth-profile test coupon, print this first | — |
| `params.scad` | **every dimension.** No number is restated anywhere else | — |
| `assembly.scad` | the posed mechanism; the only file that knows how things move | — |
| `pose.scad` | emits one body at its assembly pose, for the checker | — |
| `check.py` | measured verification | — |

## How the telescope actually attaches

The brief's description — "the screw goes sideways" — is the alt-az pivot.
Two brackets face each other under the tube: one plain hole, one brass
**1/4"-20** insert (measured, EVA-319), bore centreline 9.25 mm above the
tube's bottom surface. **That screw axis is the altitude axis.**

Our tine is the meat in the telescope's sandwich, not the reverse:

```
[1/4-20 bolt head]
  -> alt_rotor hub          clamped, turns with the scope
  -> telescope NEAR bracket plain clearance hole
  -> alt_sleeve             clamped, turns with the scope
     ... yoke tine rides FREE on the sleeve OD ...
  -> telescope FAR bracket  1/4-20 brass insert, bolt threads in here
```

`alt_sleeve` is the part that makes this a mechanism instead of a statue.
Tightening the pivot bolt pulls the brackets together and clamps whatever
is between them — if the tine were in that clamp path the altitude axis
would be locked solid. The sleeve is 0.3 mm longer than the tine is thick,
so the clamp load goes bracket → sleeve → bracket and the tine spins free.

A locked axis is geometrically indistinguishable from a working one: it
interferes with nothing and renders beautifully. Hence `assembly.scad`
names `base` as ground and derives every other pose from it, and `check.py`
sweeps altitude rather than checking one pose.

Anti-rotation: bolt friction alone would slip and lose steps silently, so
the rotor hub has a **lip** that hooks over the near bracket's outer edge.
Its shape depends on two unmeasured bracket dimensions — see below.

## The tightest budget in the design: 9.25 mm around the pivot

The tube's underside sweeps a cylinder about the altitude axis, and with
`tube_bottom_above_pivot` at the assumed 9.25 mm that cylinder is *tiny*.
**Everything the yoke puts inside the tube's width has to fit under it, at
every altitude angle** — not just at 0° and 90°. That single constraint
sets the pivot boss diameter (16.5 mm, leaving only a 2.5 mm wall over the
sleeve bore) and forces the motor arm's inboard beam to duck under a trim
plane. Two separate features violated it independently before it was
written down once.

It also drives the altitude wheel outboard. A 103 mm wheel on a pivot that
close to the tube cuts straight through the telescope, so `rotor_hub_h` is
**derived** — it stands the wheel's inboard face 3 mm clear of the tube
surface, which needs a 17 mm hub. That is a long cantilever carrying a big
wheel and is the least rigid thing in the assembly.

`tube_bottom_above_pivot` is ASSUMED at the worst case and is deliberately
*not* the same number as the measured `alt_bore_c_to_bottom` — that one is
measured against the mount lug's bottom face, and the brackets hang below
the tube. Measuring it is likely to relax all of the above at once.

## Why the yoke is tall

Not styling. A 160T wheel is ~102 mm across and hangs ~51 mm below the
altitude axis, so the axis must sit high enough for the wheel to clear the
deck. `alt_axis_z` is derived from exactly that. **The height is a
consequence of the 8:1 ratio.** A smaller ratio would give a shorter, more
rigid mount; that tradeoff is real and is eva's call, not a defect.

## Measure these before printing anything large

`params.scad` tags every constant `MEASURED` / `ASSUMED` / `STANDARD` /
`CHOSEN` / `DERIVED`. The `ASSUMED` ones are guesses. In rough order of how
much damage a wrong guess does:

1. **`belt_loop_len` (400 mm assumed).** Only one *closed* GT2 loop is on
   hand and its length was never recorded. A closed loop fixes the centre
   distance absolutely — at 400 mm it comes out **100.1 mm**, which is why
   both motors sit so far out. A 320 mm loop would put them at ~60 mm and
   make the whole rig dramatically more compact. **Measure this first; it
   changes the layout more than anything else here.** Loops shorter than
   ~306 mm cannot wrap this pulley pair at all, and `belt_centre_dist()`
   returns `undef` — asserted on, not silently propagated.
2. **The five bracket dimensions** — `bracket_gap`, `bracket_t`,
   `bracket_w`, `bracket_free_r`, `bracket_clear_d`. These set the tine
   thickness, the sleeve length, and whether the anti-rotation lip grips
   anything at all.
3. **`tube_bottom_above_pivot`** — see the section above; it is the
   binding constraint on the yoke's whole upper half.
4. **`motor_pulley_z`** — how high the 20T pulley's belt face sits above
   the motor faceplate. A belt drive absolutely requires coplanar pulleys.
5. **`tube_len_behind`** — decides the altitude ceiling outright.
6. **`belt_width`**, **`nema_shaft_d`**, **`nema_body_len`**, **`tube_od`**.

EVA-297 already lists the shaft diameter and stepper spec labels as
open TODOs — this build needs them.

## Altitude reach is set by where the pivot sits along the tube

The pivot sits 77.1 mm above the tripod face. The tube's rear end swings
`tube_len_behind × sin(altitude)` below the pivot, so with the assumed
320 mm the rig clears the ground only up to **~14°** of altitude — nowhere
near the hemisphere. `check.py` prints the ceiling and flags it.

Reaching a given altitude needs the tube to extend no more than
`77.1 / sin(altitude)` mm behind the pivot: ~77 mm for zenith, ~89 mm for
60°, ~154 mm for 30°.

**This is a parameter question, not a modelling defect.** `tube_len_behind`
is ASSUMED and unmeasured; it depends on where along the tube the bracket
pair actually sits, which nobody has checked. Three honest options, and
which one is right depends on that measurement:

- measure it first — if the brackets are near the tube's balance point the
  problem mostly evaporates;
- accept a lower altitude ceiling (`alt_max_deg`) — hemispherical coverage
  degrades to a cone, which may be fine;
- add a riser under the base, which costs rigidity on a tipping load.

Not silently patched by nudging a number until the check went green.

## Verification

```
./build.sh                       # render every part, --hardwarnings
nix develop -c python3 check.py  # measured geometric verification
```

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

`check.py`, last run: **22 part pairs classified, 0 unchecked.** All
geometry passes — the 8:1 ratio is exact, the wheel carries its 160
grooves (counted off the mesh, not assumed), the belt solve round-trips
to 0.001 mm, the thrust face and the altitude journal both show real
distributed contact.

The only remaining failures are the **altitude reach** group —
`telescope` against `yoke` / `az_table` / `base` at 60–75°, plus the
computed ceiling. They are one issue with one cause, `tube_len_behind`,
and they are left failing on purpose. See the section above.

## Open items, not silently designed around

- **Unlimited azimuth means the altitude motor's cable has to go
  somewhere.** Either a slip ring or an unwind-between-sessions habit.
  Not solved here.
- **The GT2 tooth flank is an approximation**, though the pitch geometry
  is exact and confirmed against the real measured pulley. Print
  `gt2_coupon.scad` and roll the real belt on it before committing hours
  of filament to a 160T wheel — the same settle-it-by-print method the
  microscope build used on its M12 thread.
- **The anti-rotation lip is unvalidated** against a bracket nobody has
  measured. Its depth is bounded ABOVE, not below: the jaws sweep an
  annulus as the scope tilts, so reaching too far past the bracket makes
  them grind the tine on every altitude move.
- **No altitude limit switch or homing datum.** Steppers are open-loop;
  something has to define where 0° is.
