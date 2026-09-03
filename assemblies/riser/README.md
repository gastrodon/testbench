# `riser/` — a manual two-axis tripod riser

An adapter that goes between an ordinary tripod head and the motorised
mount in `../mount`. It raises the mount, and it adds a second, coarse,
**hand-driven** gimbal underneath it: two axes, each turned by a knob
through a 1:1 spur pair.

It does not touch the optical train. `../optics`, `../tele` and the camera
are out of scope here by instruction, and so is `../mount` — that
directory is the **payload**, and nothing here modifies it.

## Why gears at all, if the ratio is 1:1

A 1:1 pair buys no mechanical advantage. It **relocates the control
point**. The azimuth axis is the central column: there is physically
nowhere to put a knob on it. The tilt axis is a loaded trunnion buried
between the yoke's tines. Both pairs exist to move the grip somewhere
fingers can reach without putting a hand in the load path.

Recorded because "1:1 gearing" otherwise reads like a mistake.

## Parts

| file | what it is | moves with |
| -- | -- | -- |
| `pedestal.scad` | **ground.** Tripod interface, azimuth post and thrust ring, both fixed knob pins | — |
| `az_column.scad` | gear, table, column, and the through-slit its yoke drops into | azimuth |
| `yoke.scad` | both tines, both gussets, the trunnion and the gear pin — one part | azimuth |
| `tilt_platter.scad` | the tilting body. The payload bolts to this | tilt |
| `tilt_gear.scad` | the hex-bored gear, **printed twice** — trunnion and knob | see below |
| `az_pinion.scad` | the same component at module 2, for the azimuth | its own pin |
| `az_handle.scad` / `tilt_handle.scad` | the two hand grips | their own pins |
| `tripod_nut.scad` | the hand nut that clamps the tripod's own plate | — |
| `../../lib/gears/hex_gear.scad` | the gear-with-a-hex-bore, as a copy-anywhere component | — |
| `../../lib/grips/handle.scad` | bore + collar + male hex + shaft + grip, likewise | — |
| `../../lib/grips/knob.scad` | the lobed grip on its own, likewise | — |
| `params.scad` | **every dimension.** No number is restated anywhere else | — |
| `assembly.scad` | the posed mechanism; the only file that knows how things move | — |
| `pose.scad` | emits one body at its assembly pose, for the checker | — |
| `print.scad` | emits one body in its PRINT orientation. A different transform | — |
| `check.py` | measured verification | — |
| `drop_to_bed.py` | lands the print-oriented STLs on Z=0, measured off the mesh | — |

## Gears and handles are components, not one-offs

The gear with the hex bore is `../../lib/gears/hex_gear.scad`, and three of the four gears
in the mechanism are instances of it. On the tilt axis the two instances
are **the same printed part** — same module, same 20 teeth, same 20 mm
hex — so one STL gets printed twice. That is only true because the ratio
is the 1:1 asked for, and because the trunnion's hex was grown to match
the handle's rather than the other way round.

A hex, not a round bore with a grub screw: a grub bearing on a round
printed boss holds by friction and eventually slips, which is the failure
`../mount/alt_rotor.scad` was redesigned to get rid of one project over.

The handles are separate parts that key into those same gears. That split
is worth more than tidiness — the gear and the grip used to be one printed
body, so the ratio and the grip diameter were the same object and changing
either reprinted both. Now the tooth split the holding warning may force
costs one small gear.

The azimuth pinion is the same *component* at module 2, not the same STL.
Making it identical would mean running the azimuth pair at module 2.5 too,
moving its centre distance to 50 and growing the base plate by 31 mm
across. Part count did not beat footprint there; on the tilt side, where
the payload already set the envelope, it did.

## How it mounts to the tripod

The tripod has **no mount piece on its head at all**. What it has,
measured and then confirmed against a backlit photo, is a single disc with
four holes: one 12 mm centre bore and three 4 mm holes at 120°, in a plate
~4 mm thick that stands 2–3 mm proud of its casting.

The bolt circle is **derived, not measured**: a bolt circle is awkward to
get a caliper onto, but the *web* between a small hole's edge and the
centre bore's edge is easy, and 1.7 mm of web forces the circle to
**19.4 mm**. Everything else follows from it.

```
  pedestal underside  ────────────────────  flat, seats on the proud plate
       │ │ │                    │
       3 posts              M10×2 stud
   into the 4mm holes    through the 12mm bore
       │ │ │                    │
  ═════╧═╧═╧════════════════════╪═══════════  the tripod's plate
                                │
                          [ hand nut ]  ← annular relief clears the posts
```

Three posts take **all** the torque; the stud only clamps. A tripod joint
held by friction under one screw is a joint that slowly rotates.

The nut's relief is the part of it that matters. Without an annular recess
in its top face, the nut lands on three post ends instead of on the plate,
and the whole mount is then held together by three point contacts on a
19.4 mm circle.

## The yoke is one part, dropped in

Everything the tilt stage and the gears touch is one printed part; the
column below it is a plain tower with a slot in the top. Three reasons,
only the first of which was asked for:

- **Printing.** Integral to the column, the yoke is a 160 mm crossbar
  growing sideways off a 125 mm tower — all overhang. Alone it lies flat.
- **The interface stops straddling the joint.** With both seats on one
  part, the span between them is a *printed* dimension rather than an
  *assembly* dimension.
- The column ends up with nothing left in it to get wrong.

The two tines are deliberately different. The −Y **drive** tine has a
closed bore, the flange journal, the clamp and both gears. The +Y
**saddle** tine is an open cradle. Open because **two closed bores on one
axis cannot be assembled at all** — neither stub can enter its bore
without the other leaving one. The seat wraps past 180° so it captures the
stub sideways instead of merely holding it up; the wrap is derived from a
0.5 mm snap, because choosing the angle directly got it wrong (205° gave a
mouth 16.30 mm across a 16 mm stub — no capture whatsoever, caught by the
part's own assert).

The cradle is **capped just above where the wrap ends**, leaving two
horns. Carrying the drive tine's full arch over the seat and then cutting
the mouth through it read as a slot sawn through solid material, because
that is what it was — and the arch carried nothing, since the payload
presses *down* into the seat.

The yoke's underside is **flat end to end**: there is no tongue, and the
stretch of blade that happens to lie inside the column *is* the tenon. The
slit's depth follows from that rather than being chosen. An earlier
version stepped the blade up over the column and left a 2 mm notch either
side of a protruding tongue — clean on every measurement in `check.py`,
and obvious in the first orthographic view anyone rendered.

Two M3 screws through the column's wall bear on the blade's flanks, above
the collar grubs that retain the column on its post. `params.scad` asserts
the two sets can never meet.

## The payload is the binding constraint

`../mount/base.scad` is not a 124 mm disc. Rendered and measured, it
reaches **129.7 mm** for the stepper arm. A yoke straddling *that* is a
266 mm part.

Both tines therefore sit outboard of the payload's 62 mm rim, which works
because rotation about Y moves nothing in Y — a tine outboard of the disc
can never be struck by it at any tilt angle. The cost is one assembly rule:

> **Install the mount with its motor arm pointing −X**, the side that
> rises, not the side that swings down.

`check.py` verifies the two halves of that separately, because only one of
them survives someone turning the mount a quarter turn on its single
screw: the r=62 disc against everything, and the real arm at the specified
orientation.

## The number that is not comfortable

The payload sits **above** the tilt axis, so tilt is an inverted pendulum:
the overturning torque *grows* with angle instead of shrinking. At the
assumed payload the tilt knob needs about **109 N at the rim against a
~60 N comfortable pinch** — 1.8×.

That is **reasoned from two numbers nobody has weighed**, so `check.py`
reports it as a warning and says so, rather than failing a build over a
claim about a human hand.

The remedy is one line. The tilt pair's tooth **sum** is fixed, so the
centre distance cannot move with the ratio:

```
tilt_wheel_teeth  20 → 26
tilt_pinion_teeth 20 → 14      ratio 1.86:1, rim force 59 N
```

Two reprinted parts. Nothing else moves — asserted, not assumed.

## Before printing

1. **Weigh the mount, and find its CG height.** `payload_mass` and
   `payload_cg_h` are guesses, and they set the paragraph above.
2. **Confirm the plate is ~4 mm and stands proud.** Both are eva's, both
   are recent, and the photo already contradicted an earlier reading.
3. **Print the M10×2 stud and the hand nut first**, as a pair. A printed
   thread is the one feature here with no precedent in this repo.
4. **`tripod_nut`'s insert dimensions are ASSUMED** — heat-set inserts
   vary by supplier and clearance here is load-bearing.

## Print orientation is not assembly orientation

`print.scad` states the **rotations**, one per part, each with a reason.
It does not state landing heights: OpenSCAD cannot ask a solid for its own
bounding box, so every height would be a number restating geometry the
part already owns. `drop_to_bed.py` measures the drop off the rendered
mesh afterwards and asserts the result. The first version hand-wrote those
heights and got five of nine wrong, one by 32 mm, and every one of them
still rendered.

Two parts need a reasonably large bed:

| part | bed footprint |
| -- | -- |
| `yoke` | 89 × 174 mm |
| `tilt_platter` | 68 × 171 mm |
| `pedestal` | 136 × 136 mm |
| everything else | ≤ 62 × 61 mm |

Both large ones are consequences of the payload being 124 mm across: the
tines have to straddle it.

## Running the checks

```sh
./build.sh          # every part, plus print-oriented copies
python3 check.py    # measured verification
```

`check.py` reads every dimension back out of OpenSCAD at runtime; there is
not one geometric constant typed into it. What *is* typed in is intent —
which pairs must clear, which must touch — because that is the one thing
the CAD cannot state for itself.

It poses parts numerically for speed, and then **renders a sample of those
poses through `pose.scad` and requires the two to agree**. Two independent
walks that must land in the same place, because a checker built alongside
the thing it checks inherits the same drift.

**And it is not enough on its own.** Measuring and looking catch
non-overlapping classes of defect. Two real faults in this directory —
a notch beside the yoke's tenon, and a channel cut through the saddle's
arch — passed every pair check and were obvious in the first orthographic
render. Render the part and look at it:

```sh
openscad -o /tmp/v.png --projection=ortho --camera=0,0,100,90,0,90,340 yoke.scad
```
