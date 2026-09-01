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

// Nominal, and 0.2 under for print bulge. The label is written out rather
// than derived with str(d): OpenSCAD prints 11.88-0.2 as 11.680000000000001,
// and a label is worthless if it is not the number you would look for.
test_bosses = [[lens_thread_d,       "11.88"],
               [lens_thread_d - 0.2, "11.68"]];

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
}

// Centred on the origin so a plate can place the pair without knowing
// how many bosses there are or how far apart they sit.
module m12_coupon_pair() {
    for (i = [0 : len(test_bosses) - 1])
        translate([i * gap - gap * (len(test_bosses) - 1) / 2, 0, 0])
            m12_boss(test_bosses[i][0]);
}

// The label strings live here, next to the diameters they describe, so a
// plate cannot label a boss with the wrong number.
function m12_label(i) = test_bosses[i][1];
function m12_label_x(i) = i * gap - gap * (len(test_bosses) - 1) / 2;
function m12_n() = len(test_bosses);

m12_coupon_pair();

echo(str("M12 coupon: nominal ", lens_thread_d, " and ",
         lens_thread_d - 0.2, " mm, pitch ", lens_thread_pitch));
echo("diameters are printed on the sheet beside each boss");
