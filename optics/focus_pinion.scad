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
// No set screws. Both parts are a press fit on the axle, so the only
// screw holes left in the whole build are the two that hold the PCB.
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

// (historical) PRESS FIT note, kept because it explains the bore sizes
// that used to be here: With the set screws removed, an
// interference fit is the only thing left transmitting torque from the
// knob through the axle to the gear — at the old 4.2mm slip bore both
// parts would simply spin on the rod and the focus would do nothing.
// 0.1mm under nominal is the usual press for a printed part on a metal
// shaft: enough to grip, little enough to push on without splitting.
//
// If it ends up too loose, drop shaft_d further before reaching for glue
// (0.15 under is still pressable); if it will not go on, warm the part.
// Note the bore must never be EXACTLY 4.0 — coincident surfaces with the
// axle left detached CGAL slivers and the part reported 3 bodies.
shaft_d = shaft_d_frame - 0.1;   // press fit on the 4mm axle
knob_h = 10;                // knob_d comes from params.scad
flute_n = 16;

// Distance from the gear's midplane out to the knob's inner face. It
// only has to clear the CARRIER FACE, which is now a 34mm bar rather
// than the old 63mm full-width plate — so the knob comes in from 37.5mm
// to 22mm and the axle shortens with it. A shorter axle is a stiffer
// axle: overhang beyond the outer bearing is a cantilever, and halving
// it cuts the deflection at the knob by roughly eight.
knob_standoff = carrier_face_w / 2 + 5;

shaft_d = shaft_d_frame;
gear_od = 2 * (pitch_radius(mod = gear_mod, teeth = pinion_teeth) + gear_mod);
flare_h = (gear_od - shaft_d) / 2;   // 45 deg: self-supporting
shaft_to_knob = knob_standoff - gear_thickness / 2;
arm_reach = 6;                        // shaft past the gear, through the far bearing

pinion_mesh_dist = gear_dist(mod = gear_mod, teeth1 = pinion_teeth, teeth2 = 0,
                             pressure_angle = gear_pressure_angle);
echo(str("pinion mesh distance (frame offset from rack pitch line): ",
    pinion_mesh_dist, " mm  [naive pitch_radius would be ",
    pitch_radius(mod = gear_mod, teeth = pinion_teeth), "]"));
echo(str("carrier travel per pinion revolution: ",
    PI * gear_mod * pinion_teeth, " mm"));
echo(str("knob standoff from gear midplane: ", knob_standoff, " mm"));

module focus_gear() {
    // No bore: the gear IS the shaft at this station. A 6mm bore through
    // a 12-tooth mod-0.75 gear would leave 0.56mm of wall at the tooth
    // roots, which is not a gear, it is a crack waiting to happen.
    spur_gear(mod = gear_mod, teeth = pinion_teeth,
              thickness = gear_thickness,
              pressure_angle = gear_pressure_angle, shaft_diam = 0,
              anchor = CENTER);
}

module focus_knob() {
    union() {
        cylinder(d = knob_d, h = knob_h);
        for (a = [0 : 360 / flute_n : 359])
            rotate([0, 0, a])
                translate([knob_d / 2 - 0.6, 0, knob_h / 2])
                    cube([1.6, 1.6, knob_h], center = true);
    }
}

// ONE PRINTED PART: knob, shaft, gear and the far stub, all rigid.
// Printed knob-DOWN so the 28mm disc is the bed adhesion surface and the
// gear ends up on top; the cone under the gear keeps that transition
// self-supporting instead of a 2.25mm radial ledge hanging in mid air.
module focus_pinion() {
    stub_len = arm_reach + 2;
    translate([0, 0, -(knob_h + shaft_to_knob)]) {
        focus_knob();
        // shaft from the knob up to the gear
        translate([0, 0, knob_h])
            cylinder(d = shaft_d, h = shaft_to_knob + gear_thickness / 2);
    }
    // self-supporting flare into the gear
    translate([0, 0, -gear_thickness / 2 - flare_h])
        cylinder(d1 = shaft_d, d2 = gear_od, h = flare_h + 0.01);
    focus_gear();
    // far stub, through the opposite bearing
    translate([0, 0, gear_thickness / 2 - 0.01])
        cylinder(d = shaft_d, h = stub_len);
}

// Print orientation: knob DOWN on the bed, gear UP. The offset lives
// here so it is derived from this file's own dimensions rather than
// recomputed in the build — the same mistake, made once already, put the
// part 28mm below the bed.
module focus_pinion_printable() {
    translate([0, 0, knob_h + shaft_to_knob])
        focus_pinion();
}

focus_pinion();
