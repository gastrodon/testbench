// Turntable + exploded-view storyboard, for producing a video.
//
//   openscad --animate 240 --imgsize=960,1080 -o /tmp/frames/f.png \
//            optics/animate.scad
//   ffmpeg -framerate 30 -i /tmp/frames/f%05d.png -c:v libx264 \
//          -pix_fmt yuv420p optics-assembly.mp4
//
// Kept separate from assembly.scad so that file stays a clean
// Customizer surface. This one owns only the choreography; all the
// geometry and kinematics come from assembly.scad unchanged.
//
// Render in PREVIEW (no --render). CGAL discards color(), and a
// monochrome exploded view is unreadable.

include <params.scad>
include <lib/BOSL2/std.scad>
include <lib/BOSL2/gears.scad>
use <pcb_carrier.scad>
use <objective_focus_mount.scad>
use <focus_pinion.scad>

$slop = 0.1;

// --- storyboard -------------------------------------------------------
// $t runs 0..1 over the whole clip. Four acts, so each behaviour gets
// shown on its own rather than everything moving at once.
//
//   0.00-0.30  assembled, focus sweeps the full travel and back
//   0.30-0.50  explode apart
//   0.50-0.70  hold exploded
//   0.70-1.00  collapse back together
//
// The turntable spins continuously underneath all four.

// smoothstep, so acts ease in and out instead of starting with a jerk
function ease(x) = let (c = max(0, min(1, x))) c * c * (3 - 2 * c);
// map t from [a,b] onto 0..1
function span(t, a, b) = (t - a) / (b - a);

act_focus   = $t < 0.30;
act_explode = $t >= 0.30 && $t < 0.50;
act_hold    = $t >= 0.50 && $t < 0.70;

// focus: out and back during act 1, parked at home afterwards
focus_t =
    act_focus
        ? (span($t, 0, 0.30) < 0.5
              ? ease(span($t, 0, 0.15))              // 0 -> 1
              : 1 - ease(span($t, 0.15, 0.30)))      // 1 -> 0
        : 0;

explode =
      act_explode ? ease(span($t, 0.30, 0.50))
    : act_hold    ? 1
    : $t >= 0.70  ? 1 - ease(span($t, 0.70, 1.0))
    : 0;

turntable = 360 * $t;

// --- geometry (mirrors assembly.scad) ---------------------------------
// carrier_z_home, pinion_z, rack_y, rack_engage_margin: params.scad owns
// these. Redefining them here resolves to undef and silently breaks the
// positioning — see the note in assembly.scad.
inner_len = tube_len_nominal;

pinion_dist = gear_dist(mod = gear_mod, teeth1 = pinion_teeth, teeth2 = 0,
                        pressure_angle = gear_pressure_angle);

travel_per_rev = PI * gear_mod * pinion_teeth;
travel = focus_travel * focus_t;
pinion_phi = 360 * travel / travel_per_rev;
carrier_z = carrier_z_home + travel;
// pinion_z: params.scad. GROUNDED — must not depend on travel.

ex_carrier = explode * 60;
ex_pinion  = explode * 38;

// Spin about the optical axis, centred on the assembly's mid-height so
// the model does not wander in frame.
rotate([0, 0, turntable])
translate([0, 0, -carrier_z_home / 2])
{
    color("SteelBlue")  base_mount();

    color("Goldenrod")
        translate([0, 0, carrier_z + ex_carrier]) pcb_carrier();

    color("FireBrick")
        translate([-ex_pinion, rack_y - pinion_dist, pinion_z])
            rotate([0, 90, 0])
                rotate([0, 0, pinion_phi])
                    focus_pinion();

    }
