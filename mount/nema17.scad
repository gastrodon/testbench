// NEMA 17 stepper -- reusable component module.
//
// Deliberately SELF-CONTAINED: it does not include params.scad and has no
// opinion about telescopes. Every dimension is a module argument with a
// default, so this file can be copied into another project unchanged.
// That is the whole point of pulling it out -- the same four salvaged
// motors are going into the camera dome, the laser gimbal and the
// microscope rebuild (Lab/testbench.md calls them one shared subsystem).
//
// MEASURED off the real Afinia salvage motor (eva, 2026-09-02) unless
// marked otherwise.
//
// ---------------------------------------------------------------------
// A note on the mounting holes, because the two measurements look like
// they disagree and do not.
//
//   "four M3 on the face, each 4mm from the edge"   -> 42 - 2*4  = 34mm
//   "internal distance between two holes ~28mm"     -> 28 + 3.2  = 31.2mm
//
// Those reconcile if the 4mm was measured to the hole's EDGE rather than
// its centre, which is the natural thing to do with calipers on a hole:
//
//   42 - 2 * (4 + 3.2/2) = 30.8mm
//   28 + 3.2             = 31.2mm
//
// Both land on the NEMA 17 standard 31mm bolt square. So the measurements
// CONFIRM the standard rather than contradicting it, and 31 is used below
// with more confidence than before, not less. Recording the reasoning
// because "eva measured 34 and I used 31" would otherwise look like the
// model quietly overriding the bench.
// ---------------------------------------------------------------------

// Faceplate is 42.0 measured; the NEMA 17 spec is 42.3. Within caliper
// noise on a chamfered casting, and the difference does not matter for
// clearance -- the larger of the two is used so clearances stay honest.
nema17_side       = 42.3;
nema17_body_len   = 33.0;   // MEASURED -- a SHORT NEMA 17. The 40mm that
                            // was assumed would have over-reserved 7mm
                            // behind every faceplate in the design.
nema17_bolt_pitch = 31.0;   // STANDARD, confirmed above
nema17_pilot_d    = 22.0;   // STANDARD raised boss
// WHAT NEMA ACTUALLY STANDARDIZES, since it matters for how much these
// numbers can be trusted:
//
//   STANDARD  the mounting face -- 42.3mm frame, 31mm bolt square, 22mm
//             pilot boss. That is the whole of it.
//   NOT       shaft diameter and the D-cut. NEMA says nothing about
//             either; they are manufacturer options.
//
// 5mm round is near-universal on NEMA 17 in printer and hobby use, and
// the common D-cut convention leaves 4.5mm across the flat. Both are
// CONVENTION, not spec -- which is a weaker claim than the bolt square
// and is tagged accordingly. EVA-297 already lists the shaft diameter as
// explicitly unrecorded.
nema17_shaft_d    = 5.0;    // MEASURED (eva, 2026-09-02) -- and it lands
                            // on the near-universal convention, so the
                            // convention is now confirmed rather than
                            // merely assumed.

// THE FLAT, measured by its visible WIDTH rather than by across-flat.
//
// eva measured "the flat part width, right in the neighbourhood of 3.5mm"
// (2026-09-02). That phrasing has two readings and they differ by 2x, so
// it is worth writing out which one this is and why:
//
//   chord width 3.5     -> flat plane 1.785 off axis -> across-flat 4.285,
//                          i.e. a 0.72mm cut
//   across-flat 3.5     -> a 1.50mm cut, and the visible flat would then
//                          be 4.58mm wide
//
// The first lands right next to the near-universal 4.5mm / 0.5mm-cut
// convention; the second would be an unusually deep cut. So this is read
// as the chord -- the width of the flat face you can see and put calipers
// across -- and the convention corroborates it rather than the other way
// round.
//
// Parameterised by the CHORD because that is the dimension a caliper can
// actually take off a mounted motor. Across-flat is derived from it:
//
//   d = sqrt(r^2 - (w/2)^2)        across_flat = d + r
//
nema17_flat_w     = 3.5;    // MEASURED -- visible width of the flat face
function nema17_flat_across(shaft_d = 5.0, w = 3.5) =
    let (r = shaft_d / 2) sqrt(r * r - (w / 2) * (w / 2)) + r;
nema17_shaft_flat = nema17_flat_across(5.0, nema17_flat_w);   // DERIVED

// Flat LENGTH is still deferred, and deferred is not the same as pending:
// nothing in this build reads it. The salvaged pulleys are existing metal
// parts already pressed on, and nothing we print mates to a D-shaft. It
// matters the day gt2_pulley_on_shaft() gets used for real.
//
// When it does: caliper across the shaft at intervals along its length
// and find where the reading steps from across-flat back up to the full
// 5.0. That station is the end of the flat. Usually impossible with the
// pulley on, since the pulley covers the part you want -- and not worth
// pulling a press fit apart for a number nothing is waiting on.
nema17_flat_len   = 8.0;    // ASSUMED, DEFERRED

nema17_shaft_len  = 12.0;   // MEASURED (eva, 2026-09-02) -- directly, on
                            // the motor in hand. SUPERSEDES EVA-297's
                            // "~15mm", which was an eyeball figure across
                            // all three belt-axis motors. Still nothing
                            // like the extruder motor's ~4mm stub, which
                            // remains not a drop-in for anything.
nema17_screw_d    = 3.4;    // CHOSEN -- M3 clearance
nema17_boss_h     = 2.0;    // STANDARD-ish, raised pilot height

// The 20T GT2 pulley already pressed onto these shafts.
nema17_pulley_h   = 8.0;    // MEASURED -- the pulley's own overall height
nema17_pulley_od  = 12.22;  // MEASURED (EVA-297) -- matches 20T GT2 spec

// WHERE ALONG THE SHAFT the pulley sits. An 8mm pulley on a 12mm shaft
// leaves only 4mm of slack, so this is a choice between two positions
// about 4mm apart -- and 4mm is a LOT, because this number sets the belt
// plane and a belt will not run at an angle.
//
//   pressed to the shaft END      -> belt-face centre 8.0mm off the face
//   seated against the FACEPLATE  -> belt-face centre 4.0mm off the face
//
// Assumed flush to the end. UNVERIFIED, and it is the last thing standing
// between this model and a belt that tracks: worth one look at whether
// there is a visible gap between the pulley's hub and the motor's face.
nema17_pulley_flush_end = true;   // ASSUMED -- CHECK
nema17_pulley_z = nema17_pulley_flush_end
    ? nema17_shaft_len - nema17_pulley_h / 2
    : nema17_pulley_h / 2;        // DERIVED -- belt-face centre standoff

// Solid body proxy, for clearance checking. Faceplate at Z=0, body growing
// toward -Z, centred on the SHAFT AXIS. Drawing it from a corner instead
// puts a 42mm body 21mm off in two directions and every clearance measured
// against it is then wrong -- which happened once here already.
module nema17_body(side = nema17_side, len = nema17_body_len) {
    translate([-side / 2, -side / 2, -len]) cube([side, side, len]);
}

// The D-shaft itself, growing +Z from the faceplate. The flat runs back
// from the shaft's free END, which is where a pulley's grub screw lands.
module nema17_shaft(shaft_d = nema17_shaft_d, shaft_len = nema17_shaft_len,
                    flat = nema17_shaft_flat, flat_len = nema17_flat_len) {
    difference() {
        cylinder(h = shaft_len, d = shaft_d);
        // Cut the flat: everything beyond `flat` measured across the
        // shaft, over the last flat_len of its length.
        translate([flat - shaft_d / 2, -shaft_d, shaft_len - flat_len])
            cube([shaft_d, 2 * shaft_d, flat_len + 1]);
    }
}

// The MATCHING BORE, as a negative. This is the half that a printed
// pulley, coupler or hub needs -- the interface, not the motor. Kept here
// beside the shaft it mates with so the two cannot drift apart (rule 3):
// a bore in one file and a flat in another is a duplication defect the
// moment it is written.
module nema17_shaft_bore(shaft_d = nema17_shaft_d, depth = 20,
                         flat = nema17_shaft_flat, clearance = 0.15) {
    intersection() {
        cylinder(h = depth, d = shaft_d + 2 * clearance);
        translate([-shaft_d, -shaft_d, 0])
            cube([shaft_d + flat + clearance, 2 * shaft_d, depth]);
    }
}

// Radial grub-screw hole for clamping onto that flat.
module nema17_grub_cut(at_z, d = nema17_grub_d, reach = 20) {
    translate([0, 0, at_z]) rotate([0, 90, 0])
        cylinder(h = reach, d = d, center = true);
}

// Motor body + boss + shaft, for clearance checking.
//
// The pulley is NOT part of this. It is a separate component that happens
// to be clamped to the shaft -- which is how it is actually attached, and
// modelling it as part of the motor hides the one interface we might have
// to reproduce (see gt2.scad's gt2_pulley_on_shaft).
module nema17(with_shaft = true) {
    nema17_body();
    cylinder(h = nema17_boss_h, d = nema17_pilot_d);
    if (with_shaft) nema17_shaft();
}

// Envelope of the 20T pulley already pressed on, for CLEARANCE only --
// a plain cylinder at OD, because clearance cares about the envelope and
// not the tooth form. The real part is metal and we are not making it.
module nema17_pulley_envelope(pulley_h = nema17_pulley_h,
                              pulley_od = nema17_pulley_od,
                              pulley_z = nema17_pulley_z) {
    translate([0, 0, pulley_z - pulley_h / 2])
        cylinder(h = pulley_h, d = pulley_od);
}

// The mounting cutout: pilot bore plus four M3, optionally SLOTTED along
// +X by `slot` for belt tensioning. Cut this out of whatever plate the
// motor bolts to; it is the half of the interface that actually matters.
module nema17_mount_cut(depth = 20, slot = 0, clearance = 0.25,
                        pilot_d = nema17_pilot_d,
                        bolt_pitch = nema17_bolt_pitch,
                        screw_d = nema17_screw_d) {
    translate([0, 0, -depth / 2]) {
        hull() for (t = [0, slot])
            translate([t, 0, 0])
                cylinder(h = depth, d = pilot_d + 2 * clearance);
        for (sx = [-1, 1], sy = [-1, 1])
            hull() for (t = [0, slot])
                translate([sx * bolt_pitch / 2 + t, sy * bolt_pitch / 2, 0])
                    cylinder(h = depth, d = screw_d);
    }
}

// Seat pocket: drops the faceplate `depth` into a plate so the pulley
// lands in a belt plane the plate would otherwise sit too high for.
module nema17_seat_cut(depth, side = nema17_side, clearance = 0.25) {
    if (depth > 0)
        translate([0, 0, -0.01])
            cylinder(h = depth + 0.01, d = side * sqrt(2) + 2 * clearance);
}
