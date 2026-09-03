// POSE -- emit exactly ONE body, at its assembly pose. For check.py.
//
// It exists so the checker never restates a transform. check.py asks for
// "yoke at az=30" and gets back the same geometry the assembly would
// draw, from the same code. A checker that posed parts itself would be a
// second, drifting copy of assembly.scad -- and cad-design rule 4 says the
// checker is the thing to suspect first.

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

part = "pedestal";
az   = 0;
tilt = 0;

module at_tilt2(t) {
    translate([0, 0, tilt_axis_z])
        rotate([0, t, 0])
            translate([0, 0, -tilt_axis_z]) children();
}
module at_knob2(a) {
    translate([0, 0, tilt_knob_z])
        rotate([0, a, 0])
            translate([0, 0, -tilt_knob_z]) children();
}
module tilt_gear_at(y, z) {
    translate([0, y, z]) rotate([-90, 0, 0]) tilt_gear();
}
gear_y = tilt_arm_y_out - tilt_gear_standoff - tilt_gear_face;

if      (part == "pedestal")     pedestal();
else if (part == "tripod_nut")   translate([0, 0, nut_seat_z]) tripod_nut();
else if (part == "az_column")    rotate([0, 0, az]) az_column();
else if (part == "yoke")         rotate([0, 0, az]) yoke();
else if (part == "az_handle")    translate([az_gear_cd, 0, 0])
                                     rotate([0, 0, -az + az_mesh_phase])
                                         az_handle();
else if (part == "az_pinion")    translate([az_gear_cd, 0, 0])
                                     rotate([0, 0, -az + az_mesh_phase])
                                         az_pinion();
else if (part == "tilt_platter") rotate([0, 0, az]) at_tilt2(tilt)
                                     tilt_platter();
else if (part == "tilt_wheel")   rotate([0, 0, az]) at_tilt2(tilt)
                                     tilt_gear_at(gear_y, tilt_axis_z);
else if (part == "tilt_handle")  rotate([0, 0, az])
                                     at_knob2(-tilt * tilt_ratio
                                              + tilt_mesh_phase)
                                         tilt_handle();
else if (part == "tilt_pinion")  rotate([0, 0, az])
                                     at_knob2(-tilt * tilt_ratio
                                              + tilt_mesh_phase)
                                         tilt_gear_at(gear_y, tilt_knob_z);
else if (part == "payload")      rotate([0, 0, az]) at_tilt2(tilt)
                                     translate([0, 0, payload_face_z])
                                         rotate([0, 0, payload_arm_dir])
                                             import("../mount/build/base.stl");
else if (part == "payload_disc")
    // The orientation-INDEPENDENT part of the payload: a disc of
    // payload_r, true at every azimuth the mount could be screwed down
    // at. Checked separately from the real mesh above, because only one
    // of the two claims survives the user turning the mount a quarter
    // turn on its single screw.
    rotate([0, 0, az]) at_tilt2(tilt)
        translate([0, 0, payload_face_z])
            cylinder(h = 6, r = payload_r);
else assert(false, str("pose: unknown part '", part, "'"));
