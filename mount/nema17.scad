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
nema17_shaft_d    = 5.0;    // CONVENTION -- near-universal, not NEMA spec.
                            // MEASURE.
nema17_shaft_flat = 4.5;    // CONVENTION -- across the flat of the D. A
                            // 0.5mm cut on a 5mm shaft. MEASURE: this is
                            // what actually transmits torque to a pulley,
                            // and it is the least standardized dimension
                            // on the whole motor.
nema17_flat_len   = 10.0;   // ASSUMED -- flat length varies freely between
                            // manufacturers. MEASURE.
nema17_grub_d     = 3.0;    // CONVENTION -- M3 set screws, usually two at
                            // 90deg with one bearing on the flat
nema17_shaft_len  = 15.0;   // MEASURED (EVA-297) -- the three belt-axis
                            // motors. NOT the extruder motor, which has a
                            // ~4mm stub and is not a drop-in for anything.
nema17_screw_d    = 3.4;    // CHOSEN -- M3 clearance
nema17_boss_h     = 2.0;    // STANDARD-ish, raised pilot height

// The 20T GT2 pulley already pressed onto these shafts.
nema17_pulley_h   = 8.0;    // MEASURED -- the pulley's own overall height
nema17_pulley_od  = 12.22;  // MEASURED (EVA-297) -- matches 20T GT2 spec

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
                              shaft_len = nema17_shaft_len) {
    translate([0, 0, shaft_len - pulley_h])
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
