// Fit test coupon — PRINT THIS FIRST.
//
// Three tolerances in this build are unverified guesses, and all three
// are cheap to test and expensive to get wrong. A full base_mount is a
// multi-hour print with ~22cm^3 of plastic; this coupon is minutes, and
// settles every one of them:
//
//   1. OBJECTIVE THREAD PITCH — now MEASURED as M9x0.75, so this is no
//      longer a coin-flip. The three blocks remain useful as a fit test:
//      a printed thread carries its own tolerance on top of a correct
//      pitch, and screwing the real cell into the 0.75 block confirms
//      the print rather than the number. The 0.5 and 1.0 blocks are kept
//      as controls — if the cell somehow threads into one of those
//      instead, the measurement was wrong.
//
//   2. SNAP-FIT THROAT. 0.3mm of interference on a 4mm axle. Whether
//      that clicks home, refuses to seat, or splits the arm depends
//      entirely on filament and layer adhesion.
//
//   3. TUBE-IN-SLEEVE SLIDING FIT. clearance = 0.3mm/side. Wants to be
//      free but not sloppy — this is the mechanism's only bearing.
//
// Print flat on the bed, no support, same filament and profile you will
// use for the real parts. A coupon printed differently proves nothing.

include <params.scad>
include <lib/BOSL2/std.scad>
include <lib/BOSL2/threading.scad>

$slop = 0.1;

// Test the STANDARD pitches, not arbitrary increments around a guess.
// Threads come off a die in standard sizes; 0.6 and 0.9 are not ones
// anybody cuts, so an earlier [0.6, 0.75, 0.9] set could easily have had
// no correct answer in it at all. For a 9mm optics thread the real
// candidates are M9x0.5 (a known small-lens pitch — the same camera's
// M12 mount is x0.5), x0.75, and x1.0.
//
// Mark which is which with a pen as they come off the bed — they are not
// distinguishable by eye afterwards.
test_pitches = [0.5, 0.75, 1.0];

// NB: avoid generic names like `pad`/`gap` at top level here — BOSL2
// defines plenty of its own and a silent collision surfaces as an
// assertion deep inside the library, nowhere near the real cause.
blk_h = obj_thread_engage + 3;
blk_w = 14;
blk_gap = 4;

module thread_test(pitch) {
    difference() {
        cuboid([blk_w, blk_w, blk_h], rounding = 1.5, edges = "Z",
               anchor = BOTTOM);
        // same construction as the real base: thread, then a clear
        // shoulder bore through
        up(-0.5)
            threaded_rod(d = obj_thread_d, l = obj_bore_depth + 0.5,
                         pitch = pitch, internal = true, bevel2 = true,
                         blunt_start1 = false, anchor = BOTTOM);
        translate([0, 0, obj_bore_depth - 0.01])
            cylinder(d = obj_thread_d - 1.2, h = blk_h);
    }
}

module snap_test() {
    // One arm section at full thickness, with the real bore and throat.
    w = 16;
    h = 18;
    difference() {
        cuboid([arm_t_test, w, h], rounding = 2, edges = "X",
               anchor = BOTTOM);
        translate([-arm_t_test, 0, h - 6])
            rotate([0, 90, 0])
                cylinder(d = shaft_d_frame + 0.35, h = arm_t_test * 3);
        // throat, opening upward
        translate([-arm_t_test, -(shaft_d_frame - 0.3) / 2, h - 6])
            cube([arm_t_test * 3, shaft_d_frame - 0.3, 8]);
    }
}
arm_t_test = 3;

module slide_test() {
    // A short section of the sleeve bore and a matching tube stub, so
    // you can feel the fit without printing 80mm of tube.
    hh = 14;
    difference() {
        cylinder(d = carrier_tube_od + 2 * clearance + 2 * wall, h = hh);
        translate([0, 0, -1])
            cylinder(d = carrier_tube_od + 2 * clearance, h = hh + 2);
    }
    translate([carrier_tube_od + 12, 0, 0])
        difference() {
            cyl(d = carrier_tube_od, h = hh, anchor = BOTTOM, chamfer1 = 1);
            translate([0, 0, -1])
                cylinder(d = carrier_tube_od - 2 * wall, h = hh + 2);
        }
}

// layout, left to right
for (i = [0 : len(test_pitches) - 1])
    translate([i * (blk_w + blk_gap), 0, 0])
        thread_test(test_pitches[i]);

translate([len(test_pitches) * (blk_w + blk_gap) + 6, 0, 0])
    snap_test();

translate([len(test_pitches) * (blk_w + blk_gap) + 34, 0, 0])
    slide_test();

echo(str("thread pitches printed, left to right: ", test_pitches));
echo(str("snap throat: ", shaft_d_frame - 0.3, " mm on a ",
         shaft_d_frame, " mm axle"));
echo(str("slide fit: ", clearance, " mm per side"));
