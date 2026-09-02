// GT2 TOOTH-PROFILE COUPON -- settle the flank by print, not by argument.
//
// params.scad section 2 is explicit that the tooth FLANK here is an
// approximation of the Gates 2GT groove, while the pitch geometry is exact
// and confirmed against the real salvaged pulley. This coupon is how the
// approximation gets tested before 100+ grams of filament goes into a
// 160T wheel.
//
// Same method the microscope build used to settle its M12 thread: print a
// small coupon carrying several candidate variants, offer them to the real
// mating part, and keep whichever actually engages. Reasoning about tooth
// profiles from a datasheet is exactly the kind of "should have worked"
// this repo's history is a list of.
//
// Usage: print, then roll the real salvaged belt onto each arc. The right
// depth seats with no rock and no rattle.

include <params.scad>
use <gt2.scad>

coupon_teeth = 20;   // same tooth count as the real motor pulley, so the
                     // belt sees the same curvature it will in service
variants     = [0.9, 1.0, 1.1];   // multipliers on tooth_depth
gap          = 6;

module coupon() {
    for (i = [0 : len(variants) - 1]) {
        translate([i * (pulley_od(coupon_teeth) + gap), 0, 0]) {
            // A 120-degree arc of pulley is enough to test seating and
            // costs a fraction of a full wheel.
            intersection() {
                gt2_pulley(coupon_teeth, flange = false,
                           depth_scale = variants[i]);
                translate([0, 0, -20])
                    linear_extrude(40)
                        polygon([[0, 0], [60, -35], [60, 35]]);
            }
            // Backing web so the arc is printable standing up.
            translate([-2, 0, 0])
                cube([4, pulley_od(coupon_teeth), pulley_face_w], center = true);
        }
    }
}

coupon();
