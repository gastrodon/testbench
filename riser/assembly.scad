// ASSEMBLY -- the posed mechanism. The ONLY file that knows how anything
// moves.
//
// Rule 6, stated rather than assumed: GROUND IS pedestal.scad. Every
// other body's pose is derived from it here, and no part file poses
// itself. A mechanism whose parts are each posed independently can
// translate as one rigid lump and interfere with nothing while doing
// nothing at all -- and no interference or contact check ever written can
// see that.
//
// The two joint angles are PARAMETERS, not globals, because `use <>`
// imports modules but not the variables around them.
//
// Derived motion, in full, so it can be read and argued with:
//
//   pedestal      ground
//   tripod_nut    ground once tight -- it clamps the tripod's own plate
//   az_column     Rz(az)
//   yoke          RIGID with az_column: keyed into its mortise
//   az_handle     spins on its FIXED pin by -az. It does not orbit: the
//                 pin belongs to the pedestal. A 1:1 external mesh turns
//                 the opposite way, hence the sign, and getting that sign
//                 wrong is invisible in every still render.
//   az_pinion     keyed to az_handle's hex -- identical pose
//   tilt_platter  Rz(az), then tilt about the Y axis at tilt_axis_z
//   tilt_wheel    keyed to the platter's stub -- identical pose
//   tilt_handle   carried by the yoke, so Rz(az), then spins on its own
//                 pin by -tilt * tilt_ratio
//   tilt_pinion   keyed to tilt_handle's hex -- identical pose
//   payload       carried by the platter
//
// MESH PHASE is applied HERE, as part of the pose, and not inside any
// part. It is an assembly fact: the handles turn freely, so which tooth
// lands in which gap is decided when the thing is put together. Baked
// into a part it would also stop working the moment two members became
// the same printed part, which is what tilt_gear.scad now is.

include <params.scad>
use <pedestal.scad>
use <az_column.scad>
use <yoke.scad>
use <az_pinion.scad>
use <az_handle.scad>
use <tilt_platter.scad>
use <tilt_gear.scad>
use <tilt_handle.scad>
use <tripod_nut.scad>

// Rotate about the tilt axis: the Y line through X=0 at tilt_axis_z.
module at_tilt(tilt) {
    translate([0, 0, tilt_axis_z])
        rotate([0, tilt, 0])
            translate([0, 0, -tilt_axis_z])
                children();
}

// Spin about the tilt knob's own axis: the Y line at tilt_knob_z.
module at_tilt_knob(a) {
    translate([0, 0, tilt_knob_z])
        rotate([0, a, 0])
            translate([0, 0, -tilt_knob_z])
                children();
}

module assembly(az = 0, tilt = 0, show_payload = true) {
    color("dimgray")    translate([0, 0, nut_seat_z]) tripod_nut();
    color("gainsboro")  pedestal();
    color("steelblue")  rotate([0, 0, az]) az_column();
    color("cadetblue")  rotate([0, 0, az]) yoke();
    color("orange")     translate([az_gear_cd, 0, 0])
                            rotate([0, 0, -az + az_mesh_phase]) az_handle();
    color("darkorange") translate([az_gear_cd, 0, 0])
                            rotate([0, 0, -az + az_mesh_phase]) az_pinion();
    color("indianred")  rotate([0, 0, az]) at_tilt(tilt) tilt_platter();
    color("firebrick")  rotate([0, 0, az]) at_tilt(tilt) tilt_wheel_posed();
    color("goldenrod")  rotate([0, 0, az])
                            at_tilt_knob(-tilt * tilt_ratio + tilt_mesh_phase)
                                tilt_handle();
    color("darkgoldenrod") rotate([0, 0, az])
                            at_tilt_knob(-tilt * tilt_ratio + tilt_mesh_phase)
                                tilt_pinion_posed();

    // The payload, as its REAL part rather than a stand-in disc, at the
    // orientation params section 2 records as an assembly constraint.
    if (show_payload)
        color("darkseagreen", 0.45)
            rotate([0, 0, az]) at_tilt(tilt)
                translate([0, 0, payload_face_z])
                    rotate([0, 0, payload_arm_dir])
                        import("../mount/build/base.stl");
}

// The two instances of tilt_gear, each at its own station. Same part,
// twice -- so these are placements, not geometry.
module tilt_wheel_posed() {
    translate([0, tilt_arm_y_out - tilt_gear_standoff - tilt_gear_face,
               tilt_axis_z])
        rotate([-90, 0, 0]) tilt_gear();
}

module tilt_pinion_posed() {
    translate([tilt_knob_x,
               tilt_arm_y_out - tilt_gear_standoff - tilt_gear_face,
               tilt_knob_z])
        rotate([-90, 0, 0]) tilt_gear();
}

assembly(az = $t * 360, tilt = 20 + 20 * sin($t * 720));
