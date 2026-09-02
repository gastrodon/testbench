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
yoke_boss_d       = 24;    // CHOSEN -- journal boss around the pivot

// Altitude motor plate. Sits out at the belt-forced centre distance, with
// its face in the same plane as the altitude wheel so the belt is not
// asked to run at an angle -- a belt drive requires coplanar pulleys
// absolutely, and this is where that gets enforced.
alt_motor_plate_t = 5.0;

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
    assert(alt_motor_face_y > yoke_tine_t / 2,
           "yoke: altitude motor plate is inboard of the tine face -- the \
motor body would occupy the telescope's bracket gap");

    difference() {
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
            // Arm tying the motor plate back to the blade. Sweeps in Y as
            // well as X, because the plate is no longer in the tine plane.
            hull() {
                translate([axis_centre_dist, alt_motor_face_y, yoke_local_axis_z])
                    rotate([-90, 0, 0])
                        cylinder(h = alt_motor_plate_t, d = 26);
                translate([0, -yoke_tine_t / 2, yoke_local_axis_z])
                    rotate([-90, 0, 0])
                        cylinder(h = yoke_tine_t, d = yoke_boss_d);
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
            for (sx = [-1, 1], sy = [-1, 1])
                hull() for (t = [0, -tension_travel])
                    translate([sx * nema_bolt_pitch / 2 + t,
                               sy * nema_bolt_pitch / 2, 0])
                        cylinder(h = 40, d = nema_screw_d, center = true);
        }
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
