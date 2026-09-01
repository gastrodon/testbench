// M12x0.5 male thread coupon — for the camera-holder mount.
// https://linear.app/gastrodon/document/microscope-camera-design-doc-15a95f836b98
//
// The carrier is being redesigned to screw into the NexiGo's existing
// M12 S-mount lens holder instead of bolting through two screw holes.
// That thread self-centres on the optical axis, which two clearance
// holes never could — the holes were the only feature referencing the
// sensor to the axis, and they referenced it loosely.
//
// Confirmed M12 x 0.5: 11.86mm OD measured, and 18 crests counted over
// 9mm of thread. Note the crest COUNT is what settled it — reading a
// single crest with calipers suggested 0.25 and would have been wrong by
// 2x, the same trap that put the objective thread at 0.75 when it is
// really 0.5.
//
// PRINTS TWO DIAMETERS. An external printed thread comes out oversize by
// roughly the extrusion width's worth of bulge, so nominal often will
// not enter. Nominal and undersized are printed side by side; use
// whichever threads in without forcing.

include <params.scad>
include <lib/BOSL2/std.scad>
include <lib/BOSL2/threading.scad>

$slop = 0.1;

thread_len = 9;             // full engagement depth of the holder
light_bore = 9;             // clear aperture through the boss
flange_d = 22;              // something to grip while turning it in
flange_t = 3;
gap = 30;

// nominal, and 0.2 under for print bulge
test_diameters = [lens_thread_d, lens_thread_d - 0.2];

module m12_boss(d) {
    difference() {
        union() {
            cylinder(d = flange_d, h = flange_t);
            translate([0, 0, flange_t - 0.01])
                threaded_rod(d = d, l = thread_len, pitch = lens_thread_pitch,
                             internal = false, bevel2 = true,
                             blunt_start1 = false, anchor = BOTTOM);
        }
        // light path straight through
        translate([0, 0, -1])
            cylinder(d = light_bore, h = flange_t + thread_len + 2);
    }
    // a flat on the flange so you can tell the two apart by feel, and
    // so the undersized one is identifiable after they are both off the
    // bed and look identical
    if (d < lens_thread_d)
        translate([flange_d / 2 - 2, -5, 0])
            cube([3, 10, flange_t]);
}

for (i = [0 : len(test_diameters) - 1])
    translate([i * gap, 0, 0])
        m12_boss(test_diameters[i]);

echo(str("M12 coupon: nominal ", lens_thread_d, " and ",
         lens_thread_d - 0.2, " mm, pitch ", lens_thread_pitch));
echo("the one WITH the flat tab on its flange is the undersized one");
