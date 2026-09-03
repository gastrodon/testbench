// TILT HANDLE -- the tilt hand grip.
//
// Kinematic role: turns on the fixed pin on the yoke's drive tine.
// tilt_gear keys onto its hex and drives the identical gear on the
// trunnion.
//
// This is the part a hand pushes hardest on -- params section 7 works out
// how hard, and at the assumed payload the answer is harder than is
// comfortable. Unlike the azimuth handle this one is horizontal, so it
// does need a retaining screw: gravity will not hold a sideways sleeve on.
//
// FRAME: local == assembly, built along -Y from the tine's outer face.
// Print orientation is grip-down, hex up -- not this orientation.

include <params.scad>
include <handle.scad>

// Wrapped in a module, and that is not style. `use <>` imports
// MODULES and nothing else, so a part file whose geometry sits at
// the top level imports as an empty file -- assembly.scad and
// pose.scad then render perfectly with the part simply absent.
// cad-design rule 2, and it cost four missing parts here.
module tilt_handle() {
    difference() {
        translate([tilt_knob_x, tilt_arm_y_out, tilt_knob_z])
            rotate([90, 0, 0])
                handle_body(collar_d = tilt_collar_d, collar_l = tilt_collar_l,
                            hex_af = tilt_hex_af, hex_l = tilt_handle_hex_l,
                            shaft_d = tilt_hex_af, shaft_l = tilt_handle_shaft_l,
                            grip_d = tilt_knob_d, grip_h = tilt_knob_h,
                            bore_d = tilt_knob_pin_d + 2 * tilt_fit,
                            bore_l = tilt_handle_bore_l);
        // Retaining screw, in through the grip's back to the pin's pilot.
        translate([tilt_knob_x, tilt_grip_end_y - 1, tilt_knob_z])
            rotate([-90, 0, 0])
                cylinder(h = tilt_knob_h + 4, d = 3.4);
        translate([tilt_knob_x, tilt_grip_end_y - 0.01, tilt_knob_z])
            rotate([-90, 0, 0])
                cylinder(h = 4.0, d = 6.5);
    };
}

tilt_handle();
