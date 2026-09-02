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
3. **`motor_pulley_z`** — how high the 20T pulley's belt face sits above
   the motor faceplate. A belt drive absolutely requires coplanar pulleys.
4. **`belt_width`**, **`nema_shaft_d`**, **`nema_body_len`**,
   **`tube_od`**, **`tube_len_behind`**.

EVA-297 already lists the shaft diameter and stepper spec labels as
open TODOs — this build needs them.

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
  measured.
- **No altitude limit switch or homing datum.** Steppers are open-loop;
  something has to define where 0° is.
