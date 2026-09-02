// YOKE -- the single tine that carries the telescope's altitude axis.
//
// Kinematic role (rule 6): rigidly bolted to az_table, so it rotates with
// the AZIMUTH axis and is stationary in ALTITUDE. It is the journal the
// telescope pivots against, and it carries the altitude stepper.
//
// Shape: one blade, not a fork. The telescope's own brackets are the fork
// -- our tine slides BETWEEN them and is pierced by the pivot bolt (via
// alt_sleeve). That is what "the screw goes sideways" means here: we are
// the meat in the telescope's sandwich, not the other way round.
//
// The tine is tall because the ratio demands it. A 160T altitude wheel is
// ~102mm across and hangs ~51mm below the altitude axis, so the axis has
// to sit high enough for the wheel to clear the az table. alt_axis_z is
// DERIVED from exactly that in params.scad -- it is a consequence of the
// 8:1 ratio, not a styling choice.
//
// FRAME: local, tine root at Z=0 in the XY plane of the az table, altitude
// axis parallel to Y at height (alt_axis_z - yoke_base_z). Assembly places
// it; this file does not know the azimuth angle.

include <params.scad>
// NEMA 17 geometry is four M3 on a 31mm square plus a 22mm pilot -- three
// numbers, all in params.scad. BOSL2's nema_steppers.scad is not pulled in
// for that; a dependency that saves no numbers is not worth the import.

// yoke_blade_w / yoke_foot_r / yoke_foot_bolt_* live in params.scad --
// az_table.scad drills the matching holes and must read the same numbers.
// yoke_boss_d, yoke_arm_d, yoke_knee_x and yoke_clear_z also live in
// params.scad: all four are derived from the tube's swept clearance rather
// than chosen here.

// alt_motor_plate_t lives in params.scad -- alt_motor_face_y is derived
// through it, so the plate thickness is part of the belt datum chain and
// cannot be a local number here (rule 3).

module yoke_blade() {
    // Blade: a tapered slab from a wide foot up to the pivot boss.
    hull() {
        translate([0, 0, 1]) cube([yoke_blade_w * 1.3, yoke_tine_t, 2],
                                  center = true);
        translate([0, 0, yoke_local_axis_z])
            rotate([90, 0, 0])
                cylinder(h = yoke_tine_t, d = yoke_boss_d, center = true);
    }
}

module yoke() {
    assert(is_num(yoke_tine_t) && yoke_tine_t > 0,
           "yoke: params.scad not included, or bracket_gap is nonsense");
    // Rule 2: if this ever went negative or undef the blade would still
    // render (as nothing, or inside-out) and pass every mesh check.
    assert(yoke_local_axis_z > gt2_env_r_axis(),
           "yoke: altitude axis is too low -- the 160T wheel would collide \
with the az table. Raise alt_axis_clear or reduce the ratio.");
    assert(is_num(axis_centre_dist),
           "yoke: belt centre distance is undef -- belt_loop_len is shorter \
than the minimum wrap for this pulley pair. Measure the real loop.");
    // The motor plate must sit outboard of the tine, or its body lands on
    // top of the telescope's own bracket.
    assert(yoke_knee_x > gt2_env_r_axis() + yoke_arm_d / 2,
           "yoke: the arm's knee is inside the altitude wheel's envelope -- \
the arm would cross the wheel's plane where the wheel is");
    assert(yoke_boss_d > sleeve_od + 2 * az_journal_fit + 2.0,
           "yoke: the pivot boss is too small to leave wall around the \
sleeve bore. tube_bottom_above_pivot is the binding constraint here -- \
measure it rather than shaving the wall.");
    assert(alt_motor_face_y > yoke_tine_t / 2,
           "yoke: altitude motor plate is inboard of the tine face -- the \
motor body would occupy the telescope's bracket gap");

    difference() {
        intersection() {
        union() {
            yoke_blade();
            // Foot: the pad that bolts down to az_table.
            translate([0, 0, 2])
                cube([yoke_blade_w * 1.3, yoke_foot_r * 1.2, 4], center = true);
            // Altitude motor plate. Out along +X at the belt-forced
            // centre distance, and out along +Y to alt_motor_face_y --
            // the motor's pulley has to land in the ROTOR's plane, and
            // the rotor is clamped outboard of the near bracket, not in
            // the tine's plane. Putting this plate at Y=0 is a belt that
            // runs at an angle, which is not a thing a belt does.
            translate([axis_centre_dist, alt_motor_face_y, yoke_local_axis_z])
                rotate([-90, 0, 0])
                    cylinder(h = alt_motor_plate_t, d = nema_side * 1.5);
            // Arm from the motor plate back to the blade, DOG-LEGGED.
            //
            // A straight hull from the plate to the tine boss looks
            // obviously right and is wrong: it crosses the wheel's plane
            // somewhere inside the wheel's radius and runs clean through
            // the 160T disc. Measured at 1,294 mm3, and invisible in every
            // view except straight down the altitude axis.
            //
            // So: run outboard at the motor's own Y as far as the knee,
            // which sits clear of the wheel's envelope, and only there
            // turn inboard to the tine.
            //   1. beam out to the knee, at the motor's Y
            hull() {
                translate([axis_centre_dist, alt_motor_face_y, yoke_local_axis_z])
                    rotate([-90, 0, 0])
                        cylinder(h = alt_motor_plate_t, d = yoke_arm_d);
                translate([yoke_knee_x, alt_motor_face_y, yoke_local_axis_z])
                    rotate([-90, 0, 0])
                        cylinder(h = alt_motor_plate_t, d = yoke_arm_d);
            }
            //   2. the crossing itself, entirely outboard of the wheel
            translate([yoke_knee_x, -yoke_tine_t / 2, yoke_local_axis_z])
                rotate([-90, 0, 0])
                    cylinder(h = alt_motor_face_y + alt_motor_plate_t
                                 + yoke_tine_t / 2, d = yoke_arm_d);
            //   3. back in to the blade, in the tine's own plane, which is
            //      nowhere near the wheel in Y
            hull() {
                translate([yoke_knee_x, -yoke_tine_t / 2, yoke_local_axis_z])
                    rotate([-90, 0, 0])
                        cylinder(h = yoke_tine_t, d = yoke_arm_d);
                translate([0, -yoke_tine_t / 2, yoke_local_axis_z])
                    rotate([-90, 0, 0])
                        cylinder(h = yoke_tine_t, d = yoke_boss_d);
            }
        }
        // DUCK UNDER THE TUBE.
        //
        // The telescope's underside sweeps a cylinder of radius
        // tube_bottom_above_pivot about the altitude axis -- at EVERY
        // altitude angle, not just the extremes. Everything the yoke puts
        // inside the tube's width therefore has to stay below that line.
        // Stating it once as a trim plane beats making every feature
        // remember it: the pivot boss and the arm's inboard beam both
        // failed that independently. Outside the tube's width -- the motor
        // plate and its outboard beam -- nothing is cut.
        union() {
            translate([-400, -tube_od / 2 - 1, -400])
                cube([800, tube_od + 2,
                      400 + yoke_local_axis_z + yoke_clear_z]);
            translate([-400, -401 - tube_od / 2, -400]) cube([800, 400, 800]);
            translate([-400, tube_od / 2 + 1, -400]) cube([800, 400, 800]);
        }
        }
        // Journal bore: the tine rides on alt_sleeve's OD, so this is a
        // RUNNING fit on the sleeve, not on the bolt.
        translate([0, 0, yoke_local_axis_z])
            rotate([90, 0, 0])
                cylinder(h = yoke_tine_t + 20, d = sleeve_od + 2 * az_journal_fit,
                         center = true);
        // NEMA 17 mounting: pilot bore + four M3, SLOTTED along X so the
        // belt can be tensioned. Slots run toward the wheel, i.e. -X,
        // because tension is taken by pulling the motor AWAY from it.
        translate([axis_centre_dist, alt_motor_face_y, yoke_local_axis_z])
        rotate([-90, 0, 0]) {
            cylinder(h = 40, d = nema_pilot_d + 2 * clearance, center = true);
            // Relief for the pulley already on the motor's shaft. It
            // reaches motor_pulley_reach back from the faceplate; if the
            // plate is thicker than that, the pulley's inner flange lands
            // on the plate and the motor never seats. Counterbored rather
            // than solved by thinning the plate, so the plate stays stiff.
            if (alt_motor_plate_t > motor_pulley_reach)
                translate([0, 0, -1])
                    cylinder(h = alt_motor_plate_t - motor_pulley_reach + 1,
                             d = gt2_env_d_motor() + 2 * clearance);
            for (sx = [-1, 1], sy = [-1, 1])
                hull() for (t = [0, -tension_travel])
                    translate([sx * nema_bolt_pitch / 2 + t,
                               sy * nema_bolt_pitch / 2, 0])
                        cylinder(h = 40, d = nema_screw_d, center = true);
        }
        // Clearance for the azimuth post, which runs up through the table
        // and on into this foot so that the two share one long journal.
        // Without this bore the post lands inside the blade root: 1,348 mm3
        // of solid-through-solid, and every part still renders.
        translate([0, 0, -1])
            cylinder(h = az_deck_z + az_post_h - yoke_base_z + 1,
                     d = az_post_d + 2 * az_journal_fit);
        // Foot bolt pattern into az_table -- four M3 on a square.
        for (sx = [-1, 1], sy = [-1, 1])
            translate([sx * yoke_foot_bolt_x, sy * yoke_foot_bolt_y, -1])
                cylinder(h = 12, d = nema_screw_d);
        // Lighten the blade.
        translate([0, 0, yoke_local_axis_z * 0.45])
            rotate([90, 0, 0])
                cylinder(h = yoke_tine_t + 20, d = yoke_local_axis_z * 0.4,
                         center = true);
    }
}
yoke();
