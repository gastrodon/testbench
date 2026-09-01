// Slide-fit coupon — the tube-in-sleeve bearing.
//
// This was fit_coupon.scad, which tested three tolerances at once. Two of
// them are now settled by print and their blocks are gone:
//
//   thread pitch — the three-block coupon answered it. M9x0.5, not the
//   0.75 the calipers read. params.scad carries the finding.
//
//   snap throat  — superseded by clip_coupon.scad, which slices the real
//   base_mount instead of standing in for it. A coupon built from the
//   actual part cannot drift away from the part; this one had already
//   drifted, still describing a 4mm axle after the shaft went to 6mm.
//
// What is left is the only untested tolerance in the build: clearance
// between the carrier tube and the sleeve it rides in. It is the
// mechanism's one bearing, it wants to be free but not sloppy, and no
// amount of geometry checking can tell you which 0.3mm feels like.
//
// Print flat, no support, same filament and profile as the real parts. A
// coupon printed differently proves nothing.

include <params.scad>
include <lib/BOSL2/std.scad>
use <label.scad>

$slop = 0.1;

// Prints alongside the mechanical-fit parts at 0.15mm.
label_h = 0.15;

// Short sections of each, so you can feel the fit without printing 80mm
// of tube.
hh = 14;

module slide_coupon() {
    // sleeve
    difference() {
        cylinder(d = carrier_tube_od + 2 * clearance + 2 * wall, h = hh);
        translate([0, 0, -1])
            cylinder(d = carrier_tube_od + 2 * clearance, h = hh + 2);
    }
    // tube stub
    translate([carrier_tube_od + 12, 0, 0])
        difference() {
            cyl(d = carrier_tube_od, h = hh, anchor = BOTTOM, chamfer1 = 1);
            translate([0, 0, -1])
                cylinder(d = carrier_tube_od - 2 * wall, h = hh + 2);
        }
}

// Which half is which, and at what clearance. The sleeve and the tube
// stub are both plain rings and are genuinely hard to tell apart by eye
// once the pair is off the bed.
label_plate_t = 1.2;
translate([0, -(carrier_tube_od / 2 + clearance + wall), 0])
    label_tab("SLEEVE", label_h, label_plate_t, size = 3.5, dir = -1);
translate([carrier_tube_od + 12, -carrier_tube_od / 2, 0])
    label_tab(str("TUBE ", clearance), label_h, label_plate_t, size = 3.5, dir = -1);

slide_coupon();

echo(str("slide fit: ", clearance, " mm per side on a ",
         carrier_tube_od, " mm tube"));
