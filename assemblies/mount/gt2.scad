// GT2 (2GT) timing pulley generator.
//
// Pitch geometry here is exact and cross-confirmed against the real
// salvaged 20T pulley (EVA-297: pitch dia 12.73, OD 12.22 -> PLD 0.254).
// The tooth FLANK is an approximation of the Gates curvilinear groove --
// see the honesty note in params.scad section 2. gt2_coupon.scad exists
// to settle the flank by print, the same way the microscope build settled
// its M12 thread by print rather than by argument.
//
// use<> imports modules but NOT the includes around them (AGENTS.md /
// cad-design rule 2), so every consumer of this file must include
// params.scad itself. gt2_pulley() asserts on the constants it needs so a
// missing include fails loudly instead of rendering an undef-sized blob.

include <params.scad>

// One groove, as a 2D cross-section in the pulley's OWN XY plane, placed
// so its mouth is at the pulley OD and its floor sits tooth_depth below.
// Round-bottomed slot: a circle at the floor plus a throat out past the OD.
//
// The profile is referenced to the OD, not to the pitch circle, because
// that is how groove depth is specified. The two differ by the 0.254mm
// pitch line differential -- a third of the groove depth, not a rounding
// error.
// `over` is how far the throat runs past the OD. It must clear the FLANGE
// too, not just the rim: a throat ending exactly on the flange's outer
// surface makes the two coincident, and CGAL emits zero-volume degenerate
// facets there. That showed up as the wheel reporting 41 bodies -- one
// real solid plus 40 slivers of exactly zero volume. Harmless to the
// geometry, but real debris in the STL, and it masks a genuine
// fragmentation if one ever appears.
module gt2_groove_2d(od, depth_scale = 1.0, over = 2.0) {
    d     = tooth_depth * depth_scale;
    floor = od / 2 - d + tooth_width / 2;   // centre of the floor arc
    union() {
        translate([floor, 0]) circle(r = tooth_width / 2);
        translate([floor, -tooth_width / 2])
            square([od / 2 - floor + over, tooth_width]);
    }
}

// A GT2 pulley blank + grooves.
//   teeth  tooth count
//   face   axial width of the belt-bearing face
//   flange true to add belt-retaining flanges on both ends
//   depth_scale multiplier on the (approximate) groove depth -- the knob
//          gt2_coupon.scad sweeps to settle the flank by print
module gt2_pulley(teeth, face = undef, flange = true, depth_scale = 1.0) {
    assert(is_num(belt_pitch) && is_num(belt_pld),
           "gt2.scad: params.scad was not included -- pitch constants are undef");
    assert(is_num(teeth) && teeth >= 10, "gt2_pulley: teeth must be >= 10");

    f  = is_undef(face) ? pulley_face_w : face;
    pd = pulley_pd(teeth);
    od = pulley_od(teeth);

    difference() {
        union() {
            cylinder(h = f, d = od, center = true);
            if (flange)
                for (z = [-1, 1])
                    translate([0, 0, z * (f / 2 + pulley_flange_h / 2)])
                        cylinder(h = pulley_flange_h,
                                 d = od + 2 * pulley_flange_t, center = true);
        }
        // Grooves run PARALLEL TO THE AXIS, the full width of the face.
        //
        // The first attempt rotated the profile 90 degrees and extruded it
        // ACROSS the face instead, which cut slots through the rim rather
        // than teeth around it. The result was watertight, valid, and
        // printable -- and a perfectly smooth wheel that cannot drive a
        // belt. It was invisible on the assembly render at this scale and
        // only showed up on an orthographic view of the coupon. Rule 2:
        // assert on a measurable consequence, which is why check.py counts
        // the teeth rather than trusting that they rendered.
        for (i = [0 : teeth - 1])
            rotate([0, 0, i * 360 / teeth])
                linear_extrude(height = f + 2 * pulley_flange_h + 2,
                               center = true)
                    gt2_groove_2d(od, depth_scale,
                                  over = pulley_flange_t + 1);
    }
}

// Total outside envelope of a pulley including its flanges -- the number
// any clearance check should ask for, rather than re-deriving it.
function gt2_envelope_d(teeth, flange = true) =
    pulley_od(teeth) + (flange ? 2 * pulley_flange_t : 0);
function gt2_envelope_h(face = undef, flange = true) =
    (is_undef(face) ? pulley_face_w : face) + (flange ? 2 * pulley_flange_h : 0);

// A PRINTABLE pulley bored to fit a NEMA 17 D-shaft, with grub screws.
//
// Not needed for this build -- the 20T pulleys on the salvaged motors are
// existing metal parts and stay put. It exists because eva's point is
// right: the pulley is a SEPARATE COMPONENT clamped to the shaft, not
// part of the motor, and that interface is the one thing we would have to
// reproduce to make our own. Modelling the pulley as part of the motor
// hides the only interface that matters.
//
// The bore and flat come from ../../lib/motors/nema17.scad, beside the shaft they mate
// with, so the two cannot drift (rule 3). Nothing about the D is
// restated here.
//
// The grub screw bears on the FLAT, not on the round. A screw tightened
// against a round shaft holds by friction and eventually slips -- the
// same mistake the rotor's original anti-rotation jaws made, one axis
// over, and the reason that design was replaced.
module gt2_pulley_on_shaft(teeth, face = undef, flange = true,
                           hub_h = 6, hub_d = undef,
                           grubs = 2, depth_scale = 1.0) {
    f  = is_undef(face) ? pulley_face_w : face;
    hd = is_undef(hub_d) ? pulley_od(teeth) * 0.75 : hub_d;
    envelope_h = gt2_envelope_h(f, flange);

    assert(hd > nema17_shaft_d + 2 * 2.0,
           "gt2_pulley_on_shaft: under 2mm of wall around the shaft bore");

    difference() {
        union() {
            gt2_pulley(teeth, face = f, flange = flange,
                       depth_scale = depth_scale);
            translate([0, 0, -envelope_h / 2 - hub_h])
                cylinder(h = hub_h, d = hd);
        }
        translate([0, 0, -envelope_h / 2 - hub_h - 1])
            nema17_shaft_bore(depth = envelope_h + hub_h + 2);
        for (i = [0 : grubs - 1])
            rotate([0, 0, i * 90])
                nema17_grub_cut(-envelope_h / 2 - hub_h / 2);
    }
}
