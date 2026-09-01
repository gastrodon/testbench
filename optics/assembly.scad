// Illustrative assembly of the modeled parts — NOT a fabrication file.
// Positions are derived from params.scad plus each part's own known
// geometry, not re-measured from the .scad files, so treat this as "how
// the pieces relate", not as ground truth for a further part. The frame
// that holds the guide rods + pinion shaft does not exist yet, so the
// pinion is shown floating at its correct meshing position.
//
// Two parameters drive every view, both settable with -D:
//
//   focus_t   0..1  position along the focus travel. Rotates the pinion
//                   and slides the carrier together by the rolling
//                   relationship, so the animation cannot drift out of
//                   sync with the real kinematics.
//   explode   0..1  0 = assembled, 1 = fully exploded along assembly axes
//
//   openscad -o f.png -D 'focus_t=0.5' -D 'explode=0' assembly.scad
//
// Render these in PREVIEW mode (no --render): CGAL discards color(), so
// a full render comes out monochrome and unreadable. Manifoldness is
// verified separately by check.py, which is where that check belongs.

include <params.scad>
include <lib/BOSL2/std.scad>
include <lib/BOSL2/gears.scad>
use <pcb_carrier.scad>
use <objective_focus_mount.scad>
use <focus_pinion.scad>

/* [Focus] */
// position along focus travel (0 = home, 1 = full 20mm)
focus_t = 0;      // [0:0.01:1]
// drive focus from the Animate panel's $t instead of the slider
animate_focus = false;

/* [View] */
// 0 = assembled, 1 = fully exploded
explode = 0;      // [0:0.01:1]

/* [Hidden] */
ft = animate_focus ? $t : focus_t;

// --- geometry duplicated from each part file, for positioning only ---
inner_len = tube_len_nominal;          // objective_focus_mount.scad
sleeve_len = 40;
margin = 4;                            // pcb_carrier.scad
plate_w = pcb[1] + 2 * margin;
plate_d = pcb[0] + 2 * margin;
rack_y = -(plate_d / 2 - margin / 2);   // rack on the SHORT edge
rod_x = plate_w / 2 - margin / 2;
rod_bushing_len = 14;
rack_engage_margin = 5;                 // matches pcb_carrier.scad

// gear_dist(), not pitch_radius() — see focus_pinion.scad
pinion_dist = gear_dist(mod = gear_mod, teeth1 = pinion_teeth, teeth2 = 0,
                        pressure_angle = gear_pressure_angle);

// Stack along Z, specimen end (objective) at the bottom, camera end
// (PCB) at the top — matches the design doc's ASCII diagram.
carrier_z_home = inner_len + holder_h;

// --- focus kinematics -------------------------------------------------
// Rolling without slipping. The contact point sits at +Y from the pinion
// center; rotating +phi about +X maps it to (0, r*cos, r*sin), i.e.
// toward +Z. So the carrier rises as the pinion turns +phi. Deriving the
// carrier position FROM the pinion angle (rather than setting both by
// hand) is what keeps the two in step at every frame.
//
// The PINION IS GROUNDED — it belongs to the frame, which is bolted to
// the tube, and it only spins. The carrier is what translates. Moving
// the pinion along with the carrier (as this file did at first) makes
// the whole mechanism a no-op: nothing ever gets further from anything.
travel_per_rev = PI * gear_mod * pinion_teeth;
travel = focus_travel * ft;                       // mm
pinion_phi = 360 * travel / travel_per_rev;       // deg
carrier_z = carrier_z_home + travel;

// Fixed in world Z, engaging the rack near its top when focus is at
// home. As the carrier climbs, the engagement point walks down the rack.
pinion_z = carrier_z_home - rack_engage_margin;

// $slop is dynamically scoped: objective_focus_mount.scad's own
// $slop=0.1 applies only when IT is the running file, not when its
// modules are called from here via use<>.
$slop = 0.1;

// --- explode offsets --------------------------------------------------
// Each part moves along the axis it is actually assembled along, so the
// exploded view reads as an assembly instruction rather than a scatter.
ex_inner   = explode * 55;    // inner tube lifts out of the sleeve, +Z
ex_carrier = explode * 55;    // carrier lifts off the tube, +Z
ex_pinion  = explode * 38;    // pinion withdraws along its own axis, -X

color("SteelBlue")
    outer_sleeve();

color("SkyBlue")
    translate([0, 0, ex_inner])
        inner_tube();

color("Goldenrod")
    translate([0, 0, carrier_z + ex_carrier])
        pcb_carrier();

// Grounded: fixed z, unaffected by carrier travel or the carrier's
// explode offset. Only its rotation changes with focus_t.
color("FireBrick")
    translate([-ex_pinion, rack_y - pinion_dist, pinion_z])
        rotate([0, 90, 0])
            rotate([0, 0, pinion_phi])   // about the pinion's own axis
                focus_pinion();

// Ghost the guide rods so the carrier's travel axis is visible. They are
// stock 4mm rod, not a printed part, hence the % (transparent, excluded
// from geometry).
%for (x = [-rod_x, rod_x])
    translate([x, 0, carrier_z_home - rod_bushing_len - 4])
        cylinder(d = guide_rod_d, h = focus_travel + rod_bushing_len + 14);
