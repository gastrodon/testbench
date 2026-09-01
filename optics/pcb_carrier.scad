// PCB carrier plate — part 1 of the prime-focus microscope camera build.
// https://linear.app/gastrodon/document/microscope-camera-design-doc-15a95f836b98
//
// The N60's PCB seats on this plate, self-tapping screws through the same
// 2 holes the M12 holder already uses, so holder + PCB + carrier all pin to
// one axis. Those 2 screws are the only feature on the whole build
// referenced to the optical axis, so this plate's screw-hole positions ARE
// the axis for everything downstream.
//
// The board is USB-fed at one end (55mm long, screws only 20mm apart, so
// ~17.5mm of unsupported overhang past the screws either way) — a tugged
// cable would otherwise torque the mount straight through the PCB. The
// strain-relief post anchors the cable to the plate instead.
//
// This is the moving half of the focus mechanism (image-side focus, per
// the design doc — M^2 easier than moving the objective end): the plate
// rides 2 fixed guide rods along Z (the optical axis) and carries an
// integrated rack that a frame-mounted pinion (focus_pinion.scad) drives.
// The frame itself — which holds the rods and the pinion shaft — isn't
// designed yet; this part only needs to be internally consistent with it.

include <params.scad>
include <lib/BOSL2/std.scad>
include <lib/BOSL2/gears.scad>

margin = 4;               // plate overhang past the board footprint, mm
boss_d = holder_screw_d + 3;  // printed boss OD around each screw hole, mm
screw_hole_d = holder_screw_d - 0.3; // slightly undersized so a self-tapping screw bites
plate_t = wall;

cable_end = 1;            // +1 or -1: which end of the board the USB cable exits.
                           // Confirm against the physical board before printing.

plate_w = pcb[1] + 2 * margin; // long axis (board length), X
plate_d = pcb[0] + 2 * margin; // short axis (board width), Y

// Guide rods flank the board along X (the long axis), symmetric about
// the optical axis so the carriage cannot rotate as it travels.
//
// They were on the Y axis at +/-11.5mm, where the bushings (4.4mm boss
// radius, hanging 14mm below the plate) reached to 7.1mm from the axis
// and drove straight through the 9mm-radius optical tube — a 65mm^3
// collision that no render showed, because the tube hides behind the
// plate from every viewing angle. Found by check.py, not by looking.
// On the X axis at +/-29.5mm the bushings clear the tube by a wide
// margin, and the wider span resists carriage twist better besides.
rod_boss_od = guide_rod_d + 2 * wall;
rod_bushing_len = 14;      // below the plate, mm — plate itself is too thin (wall) to bear alone
rod_x = plate_w / 2 - margin / 2;

// Rack sits on the SHORT (Y) edge: that puts the pinion 17.8mm off the
// optical axis instead of 35.8mm on the long edge, halving the frame's
// reach and the cantilever it has to hold rigid.
//
// It hangs DOWNWARD from the plate, along the travel axis. The pinion is
// fixed to the frame and the carrier climbs past it, so relative to the
// carrier the engagement point travels from the rack's top (focus at
// home) to its bottom (focus at full travel) — the rack therefore has to
// be at least focus_travel long, plus engagement margin at both ends.
rack_circ_pitch = PI * gear_mod;
rack_engage_margin = 5;                 // mm of rack beyond each travel end
rack_len_min = focus_travel + 2 * rack_engage_margin;
rack_teeth = ceil(rack_len_min / rack_circ_pitch);
rack_len = rack_teeth * rack_circ_pitch;
rack_z_center = -rack_len / 2;          // top of rack flush with plate underside

// Rack pitch line sits FLUSH with the plate edge, not inset. BOSL2's
// rack backing extends 2*dedendum+addendum behind the pitch line, and
// since the rack hangs down alongside the optical tube, that backing is
// what has to clear the tube's 9mm outer radius. Inset by margin/2 the
// backing reached y=-8.875 and fouled the tube by 0.125mm — a real
// collision, small enough to look like rounding error but not.
// Flush with the edge it reaches -10.875, clearing by 1.875mm.
rack_y = -plate_d / 2;

module screw_bosses() {
    for (x = [-holder_screw_span / 2, holder_screw_span / 2])
        translate([x, 0, 0])
            cylinder(d = boss_d, h = plate_t + 1.5, center = false);
}

module screw_holes() {
    for (x = [-holder_screw_span / 2, holder_screw_span / 2])
        translate([x, 0, -0.5])
            cylinder(d = screw_hole_d, h = plate_t + 3, center = false);
}

module guide_rod_bosses() {
    for (x = [-rod_x, rod_x])
        translate([x, 0, -rod_bushing_len])
            cylinder(d = rod_boss_od, h = rod_bushing_len + plate_t, center = false);
}

module guide_rod_holes() {
    for (x = [-rod_x, rod_x])
        translate([x, 0, -rod_bushing_len - 1])
            cylinder(d = guide_rod_d, h = rod_bushing_len + plate_t + 2, center = false);
}

module strain_relief() {
    // A post + crossbar past the board's overhanging end, with a gap
    // underneath to loop a zip-tie around the cable and cinch it to the
    // plate instead of the PCB.
    post_x = cable_end * (plate_w / 2 - margin / 2);
    post_h = 9;
    post_w = 6;
    bar_t = 2.4;

    translate([post_x, 0, 0]) {
        cube([post_w, pcb[0] * 0.6, post_h], center = true);
        translate([0, 0, post_h / 2 - bar_t / 2])
            cube([post_w + 6, pcb[0] * 0.6, bar_t], center = true);
    }
}

module focus_rack() {
    // BOSL2's rack() lies length-along-X, teeth-pointing-+Z, thickness
    // along Y. Three axes have to land correctly, and getting any one
    // wrong still renders as a plausible-looking toothed strip:
    //
    //   length +X -> +Z   the travel axis
    //   teeth  +Z -> -Y   outward from the -Y edge, toward the pinion
    //   thick  +Y -> -X   across the plate edge
    //
    // rotate([0,-90,90]) is the composition that does this. An earlier
    // rotate([90,0,90]) put the LENGTH along Y — the rack lay across the
    // plate instead of along the travel, and overhung both edges (it
    // showed up as a 39mm Y bounding box on a 27mm plate).
    translate([0, rack_y, rack_z_center])
        rotate([0, -90, 90])
            rack(
                mod = gear_mod, teeth = rack_teeth, thickness = gear_thickness,
                pressure_angle = gear_pressure_angle,
                anchor = CENTER
            );
}

module pcb_carrier() {
    difference() {
        union() {
            linear_extrude(height = plate_t)
                square([plate_w, plate_d], center = true);
            screw_bosses();
            guide_rod_bosses();
        }
        screw_holes();
        guide_rod_holes();
    }
    strain_relief();
    focus_rack();
}

pcb_carrier();
