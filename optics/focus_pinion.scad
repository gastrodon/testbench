// Focus pinion + knob — drives pcb_carrier.scad's integrated rack.
// https://linear.app/gastrodon/document/microscope-camera-design-doc-15a95f836b98
//
// mod/teeth/pressure_angle must match focus_rack() in pcb_carrier.scad
// exactly (all pulled from params.scad) or they won't mesh.
//
// IMPORTANT — mesh distance: the frame must hold this shaft at
// gear_dist(), NOT pitch_radius(), from the rack's pitch line. Below the
// ~17-tooth undercut threshold BOSL2 auto-applies a profile shift, which
// pushes the operating center distance out past the naive pitch radius.
// Using the naive value buries the teeth too deep and the pair binds.
//
// TWO SEPARATE PRINTED PARTS, joined by a length of 4mm rod:
//
//   focus_gear()  small, lives at the plate edge where the rack is
//   focus_knob()  large, lives OUTBOARD past the plate's X edge
//
// They cannot be one piece. The gear must sit beside the rack, but a
// knob big enough to turn finely has a radius far larger than the gap
// between the pinion axis and the carrier plate — a coaxial knob sweeps
// straight through the plate no matter how the pinion is positioned in
// Z (measured: 392 mm^3 of interference). Putting the knob on a shaft
// outboard of the plate is how real microscope focus blocks do it, and
// it decouples knob diameter from any clearance constraint — so knob
// size stays a free choice for tactile fineness.

include <params.scad>
include <lib/BOSL2/std.scad>
include <lib/BOSL2/gears.scad>

shaft_d = 4;                // through-bore for a metal shaft, mm
set_screw_d = 2.6;          // self-tapping M3 pilot, radial, locks part to shaft
knob_h = 10;                // knob_d comes from params.scad
flute_n = 16;

// Distance from the gear's midplane out to the knob's inner face, along
// the shaft. Must clear the carrier plate's X half-width plus margin.
plate_half_x = (pcb[1] + 8) / 2;
knob_standoff = plate_half_x + 6;

pinion_mesh_dist = gear_dist(mod = gear_mod, teeth1 = pinion_teeth, teeth2 = 0,
                             pressure_angle = gear_pressure_angle);
echo(str("pinion mesh distance (frame offset from rack pitch line): ",
    pinion_mesh_dist, " mm  [naive pitch_radius would be ",
    pitch_radius(mod = gear_mod, teeth = pinion_teeth), "]"));
echo(str("carrier travel per pinion revolution: ",
    PI * gear_mod * pinion_teeth, " mm"));
echo(str("knob standoff from gear midplane: ", knob_standoff, " mm"));

module focus_gear() {
    // straddles z=0, so placing this part puts the GEAR where you asked
    difference() {
        spur_gear(
            mod = gear_mod, teeth = pinion_teeth, thickness = gear_thickness,
            pressure_angle = gear_pressure_angle, shaft_diam = 0,
            anchor = CENTER
        );
        cylinder(d = shaft_d, h = gear_thickness + 2, center = true);
        translate([0, pitch_radius(mod = gear_mod, teeth = pinion_teeth) - 1.5, 0])
            rotate([90, 0, 0])
                cylinder(d = set_screw_d, h = gear_thickness);
    }
}

module focus_knob() {
    difference() {
        union() {
            cylinder(d = knob_d, h = knob_h);
            for (a = [0 : 360 / flute_n : 359])
                rotate([0, 0, a])
                    translate([knob_d / 2 - 0.6, 0, knob_h / 2])
                        cube([1.6, 1.6, knob_h], center = true);
        }
        translate([0, 0, -1])
            cylinder(d = shaft_d, h = knob_h + 2);
        translate([0, knob_d / 2 - 3, knob_h / 2])
            rotate([90, 0, 0])
                cylinder(d = set_screw_d, h = knob_d);
    }
}

// The axle: stock 4mm rod, NOT printed. Modelled as real geometry (not a
// % ghost) so interference checks actually see it — a ghost is excluded
// from geometry, so nothing would have caught the axle fouling something.
// It must span both yoke bearings and reach the knob:
//   -9  through the -X bearing
//    0  the gear
//  +8.5 through the +X bearing
// +47.5 the far face of the knob
// axle_len in params.scad is cut from stock to suit.
module focus_axle() {
    translate([0, 0, -(axle_len - (knob_standoff + knob_h))])
        cylinder(d = shaft_d_frame, h = axle_len);
}

// Both printed parts on their common axle, for assembly views.
module focus_pinion() {
    focus_gear();
    translate([0, 0, knob_standoff])
        focus_knob();
    focus_axle();
}

// Print layout: the two parts side by side, both flat on the bed.
// (use<> imports only modules, so assembly.scad never sees this.)
focus_gear();
translate([knob_d + 6, 0, -knob_h / 2])
    focus_knob();
