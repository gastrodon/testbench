// ALT ROTOR -- the 160T altitude wheel that clamps to the telescope.
//
// Kinematic role (cad-design rule 6): this body is rigidly attached to the
// TELESCOPE and rotates with it about the altitude axis. It is NOT
// grounded. The grounded body in this mechanism is base.scad's plate.
//
// Fastener stack along the altitude axis, outboard -> inboard:
//
//   [1/4-20 bolt head]
//     -> alt_rotor hub          (this part, clamped hard, turns with scope)
//     -> telescope NEAR bracket (plain clearance hole)
//     -> alt_sleeve             (shoulder bushing, clamped hard)
//        ... yoke tine rides FREE on the sleeve's OD ...
//     -> telescope FAR bracket  (1/4-20 brass insert, bolt threads in here)
//
// The sleeve is what makes this work: it is fractionally longer than the
// tine is thick, so clamp load passes bracket->sleeve->bracket and never
// pinches the tine. Without it, tightening the pivot bolt locks the
// altitude axis solid -- a mechanism that moves as one rigid lump, which
// is exactly the kinematic error rule 6 says no geometric check can see.
//
// Anti-rotation: bolt friction alone would eventually slip and lose
// position (steps lost silently, no error raised anywhere). So the hub
// carries a LIP that hooks over the near bracket's outer edge, keying the
// rotor to the bracket positively. Lip geometry depends on bracket_t and
// bracket_w, both ASSUMED -- if the real bracket is a different shape,
// the lip is the first thing to redraw.
//
// FRAME (rule 5 -- print orientation is not assembly orientation):
// modelled in its own LOCAL frame with the wheel axis along +Z and the
// wheel centred on Z=0. The hub and lip grow toward -Z, which is the
// inboard/telescope side. assembly.scad does all posing; nothing in this
// file knows where the telescope is.

include <params.scad>
use <gt2.scad>

// rotor_hub_h lives in params.scad: alt_rotor_offset_y is derived from it,
// so it is shared by this file, yoke.scad and assembly.scad (rule 3).
rotor_hub_d     = min(bracket_free_r * 2, 34);  // must not foul the tube

// How far the anti-rotation jaws reach back over the bracket's edge.
// Bounded ABOVE, not below: the jaws sweep an annulus as the scope tilts,
// so their tips must stop short of the tine's face or they grind it on
// every altitude move. The gap from the bracket's outer face to the tine
// face is bracket_t + (bracket_gap - yoke_tine_t)/2.
//
// The first version asserted the opposite (lip_depth > bracket_t) on the
// theory that the lip had to reach past the bracket to key anything. It
// does not -- partial engagement on the bracket edge keys it fine, and
// reaching past guarantees a collision.
rotor_lip_max   = bracket_t + (bracket_gap - yoke_tine_t) / 2;
rotor_lip_depth = 2.5;
rotor_face_z    = -gt2_envelope_h() / 2;  // inboard face of the wheel, local Z

module alt_rotor() {
    assert(is_num(axis_teeth), "alt_rotor: params.scad not included");
    assert(rotor_lip_depth > 0.8,
           "alt_rotor: lip too shallow to key anything against the bracket");
    assert(rotor_lip_depth < rotor_lip_max,
           str("alt_rotor: lip_depth ", rotor_lip_depth, " reaches past the ",
               "bracket into the yoke tine's swept path (max ",
               rotor_lip_max, ")"));
    assert(rotor_hub_d <= bracket_free_r * 2,
           "alt_rotor: hub fouls the telescope tube");

    difference() {
        union() {
            gt2_pulley(axis_teeth);                     // wheel, centred Z=0
            translate([0, 0, rotor_face_z - rotor_hub_h])
                cylinder(h = rotor_hub_h + 1, d = rotor_hub_d);  // hub, -Z
            // Anti-rotation jaws straddling the bracket's outer edge.
            //
            // Offset by `clearance` so the jaws' inner faces sit just
            // outside the bracket rather than exactly ON it. Flush was the
            // first version: the two faces were mathematically coincident,
            // which measured as 75 mm3 of interpenetration and would have
            // been a jaw that cannot be pushed over the bracket at all.
            // The 0.25mm of slop is also the keying backlash -- small
            // against 0.225 deg per full step.
            for (s = [-1, 1])
                translate([s * (bracket_w / 2 + clearance + wall / 2),
                           0,
                           rotor_face_z - rotor_hub_h - rotor_lip_depth / 2])
                    cube([wall, rotor_hub_d * 0.7, rotor_lip_depth],
                         center = true);
        }
        // Pivot bore -- CLEARANCE, because the bolt threads into the far
        // bracket, not into this part.
        translate([0, 0, rotor_face_z - rotor_hub_h - rotor_lip_depth - 2])
            cylinder(h = 60, d = alt_bolt_major + 2 * clearance);
        // Bolt-head counterbore on the outboard (+Z) face.
        translate([0, 0, gt2_envelope_h() / 2 - 3])
            cylinder(h = 10, d = alt_bolt_major * 1.9);
        // Lightening holes. A solid 102mm disc is a lot of filament for a
        // part carrying very little load -- 8:1 off a NEMA 17 is enormous
        // torque margin against a 50mm toy refractor.
        for (i = [0 : 4])
            rotate([0, 0, i * 72])
                translate([axis_od / 4 + 4, 0, 0])
                    cylinder(h = 60, d = 16, center = true);
    }
}

alt_rotor();
