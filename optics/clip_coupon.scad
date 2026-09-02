// Snap-clip coupon — the top of the base, just the bearing region.
// https://linear.app/gastrodon/document/microscope-camera-design-doc-15a95f836b98
//
// Tests the one thing in this build that cannot be settled by geometry:
// whether a 6mm shaft actually snaps into a 5.7mm throat in this
// filament, and holds. That is a materials-and-layer-adhesion question
// — the arms have to flex 0.3mm and spring back, and whether they do
// depends on wall thickness, layer bonding and how the part is oriented,
// none of which check.py can predict.
//
// Cutting the top off base_mount rather than remodelling it means the
// coupon has the REAL geometry — same arm thickness, same throat, same
// boss — so a pass here transfers directly to the printed part. A
// simplified stand-in would only test the stand-in.
//
// The bridge under the gear sits at pinion_z - bridge_drop, inside the
// slice, so both arms stay joined and the coupon is one piece.

include <params.scad>
include <lib/BOSL2/std.scad>
include <lib/BOSL2/gears.scad>
include <lib/BOSL2/threading.scad>
use <objective_focus_mount.scad>
$slop = 0.1;

// Keep everything from just below the tie bridge up to the ceiling.
slice_bottom = 68;
slice_top = carrier_z_home;      // yoke_ceiling sits just under this

// A foot so the coupon stands up on the bed instead of balancing on two
// thin arm cross-sections. Printed at the bottom of the slice, it also
// stiffens the arms less than the real part's long root does — which
// makes this a slightly PESSIMISTIC test of the snap, not an optimistic
// one. Better that way round.
foot_t = 2.4;
foot_pad = 3;

module clip_coupon() {
    difference() {
        union() {
            intersection() {
                base_mount();
                translate([-60, -60, slice_bottom])
                    cube([120, 120, slice_top - slice_bottom]);
            }
            // foot plate under the sliced arms
            translate([0, (rack_y - 12) / 2, slice_bottom])
                cuboid([2 * (arm_x_pub + arm_t_pub) + 2 * foot_pad,
                        abs(rack_y - 12) + 2 * foot_pad, foot_t],
                       rounding = 2, edges = "Z", anchor = BOTTOM + CENTER);
        }
        // keep the rack slot open through the foot so the coupon still
        // shows the real clearance the rack travels in
        translate([-rack_slot_half_pub, rack_y - 4, slice_bottom - 1])
            cube([2 * rack_slot_half_pub, 8, foot_t + 2]);
    }
}

// objective_focus_mount.scad's internals are not exported by use<>, so
// these are re-derived here — but every one of them now comes from
// params.scad rather than being retyped. A bare literal here is the
// rack_slot_half bug waiting to happen again.
arm_t_pub = arm_t;   // from params.scad, shared with the mount
rack_slot_half_pub = rack_slot_half;   // from params.scad
arm_x_pub = rack_slot_half_pub + arm_t_pub / 2;
snap_throat_pub = shaft_d_frame - 0.3;

// Where this part's footprint actually sits in Y. The foot reaches a long
// way back toward the rack, so the geometry is NOT centred on the origin —
// a plate that assumes it is will place a neighbouring label inside the
// foot, where it merges into the union and disappears without a trace.
// Exported so the plate can offset by the same number this file uses.
function clip_y_centre() = (rack_y - 12) / 2;

// Print orientation: the sliced-off bottom of the region sits on the bed.
module clip_coupon_printable() {
    translate([0, 0, -slice_bottom])
        clip_coupon();
}

clip_coupon_printable();

echo(str("clip coupon: slice z ", slice_bottom, "..", slice_top,
         "  throat ", shaft_d_frame - 0.3, " on a ", shaft_d_frame, "mm shaft"));
