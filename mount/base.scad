// BASE -- the grounded body. Everything else moves relative to this.
//
// Kinematic role (rule 6): THIS IS GROUND. Naming it explicitly is the
// point -- a mechanism whose parts are each posed independently, with no
// declared ground, can translate as one rigid lump and still pass every
// interference and contact check ever written. assembly.scad derives all
// motion from this body and never poses anything on its own.
//
// Carries:
//   - the tripod interface (1/4"-20, MEASURED on the scope's own lug)
//   - the azimuth post the table journals on, plus its thrust face
//   - the azimuth stepper on a radially slotted mount for belt tension
//
// FRAME: local, azimuth axis along +Z, plate underside at Z=0. Also its
// print orientation -- flat on the bed, post pointing up. The captured
// tripod nut pocket therefore prints as a bridged void and needs a pause,
// which is print-job's problem, not this file's.

include <params.scad>

az_motor_plate_t = 5.0;
motor_plate_z    = base_plate_t;   // motor sits on top of the plate

module base() {
    assert(is_num(az_post_d), "base: params.scad not included");
    assert(base_plate_r > az_thrust_r,
           "base: plate is smaller than the thrust face it has to support");
    assert(is_num(axis_centre_dist),
           "base: belt centre distance is undef -- belt_loop_len is shorter \
than the minimum wrap for this pulley pair. Measure the real loop.");
    // The az motor sits at the belt centre distance, radially out. If the
    // plate does not reach it, the motor mounts to nothing -- and a
    // floating motor plate is a watertight, valid, useless solid.
    // Coplanarity, enforced rather than hoped for.
    assert(az_motor_face_z >= 0,
           "base: the azimuth motor's pulley stands taller than the belt \
plane, so no counterbore can bring it into line. Either motor_pulley_z is \
wrong (it is ASSUMED) or the table has to be raised.");
    assert(az_motor_face_z <= base_plate_t,
           "base: the azimuth motor seat would sit above the base plate.");
    assert(az_motor_pocket >= 0.4,
           "base: the azimuth motor pocket is too shallow to locate the \
motor; either the belt plane and the pulley standoff already agree (in \
which case drop the pocket) or motor_pulley_z is wrong.");
    assert(base_plate_r + nema_side >= az_motor_r,
           "base: az motor at the belt centre distance is off the plate. \
Either the belt loop is longer than this base can span, or the plate must \
grow an arm. Measure belt_loop_len first.");

    difference() {
        union() {
            cylinder(h = base_plate_t, r = base_plate_r);
            // Thrust face: a raised annulus the table rides on, so contact
            // is a defined narrow ring rather than an ill-defined
            // whole-plate rub. This is a DESIGNED-TO-TOUCH pair -- check.py
            // tests it for sustained distributed contact, not just for
            // absence of overlap.
            cylinder(h = az_deck_z, r = az_thrust_r);
            // Azimuth post.
            cylinder(h = az_deck_z + az_post_h, d = az_post_d);
            // Arm out to the azimuth motor.
            hull() {
                cylinder(h = base_plate_t, r = az_thrust_r * 0.5);
                translate([az_motor_r, 0, 0])
                    cylinder(h = base_plate_t, d = nema_side * 1.4);
            }
        }
        // Retaining screw, up the post's centre. Holds the table captive
        // against the thrust face without clamping it -- same shoulder
        // principle as alt_sleeve, one axis down.
        translate([0, 0, base_plate_t * 0.4])
            cylinder(h = az_post_h + 20, d = az_retain_d);
        // Tripod socket: captured 1/4"-20 hex nut, pocket opening
        // downward, plus the through-bore for the tripod screw.
        translate([0, 0, -1])
            cylinder(h = base_plate_t + 2, d = alt_bolt_major + 2 * clearance);
        translate([0, 0, -0.01])
            cylinder(h = tripod_nut_t, d = tripod_nut_af / cos(30), $fn = 6);
        // Motor seat: a shallow pocket in the plate's TOP face, dropping
        // the faceplate to az_motor_face_z so the pulley lands in the belt
        // plane. Sitting flush on the plate top would be az_motor_pocket
        // too high, and a belt cannot run at an angle.
        //
        // The motor stands body-UP in this pocket. Body-down would hang a
        // 40mm NEMA 17 below the plate and force the whole base up onto
        // 40mm legs to clear the tripod head. Body-up is clear of the
        // rotating table because the motor sits out at the belt centre
        // distance, well outside the table's rim.
        translate([az_motor_r, 0, az_motor_face_z])
            cylinder(h = az_motor_pocket + 1,
                     d = nema_side * sqrt(2) + 2 * clearance);
        // NEMA 17 for azimuth: pilot bore + four M3 slotted RADIALLY so
        // the belt tensions by sliding the motor outward.
        translate([az_motor_r, 0, -1]) {
            hull() for (t = [0, tension_travel])
                translate([t, 0, 0])
                    cylinder(h = base_plate_t + 2,
                             d = nema_pilot_d + 2 * clearance);
            for (sx = [-1, 1], sy = [-1, 1])
                hull() for (t = [0, tension_travel])
                    translate([sx * nema_bolt_pitch / 2 + t,
                               sy * nema_bolt_pitch / 2, 0])
                        cylinder(h = base_plate_t + 2, d = nema_screw_d);
        }
        // Lighten the plate.
        for (i = [0 : 7])
            rotate([0, 0, 22.5 + i * 45])
                translate([(az_thrust_r + base_plate_r) / 2, 0, -1])
                    cylinder(h = base_plate_t + 2, d = 10);
    }
}

base();
