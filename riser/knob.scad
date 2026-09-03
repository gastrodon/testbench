// KNOB -- a hand grip, as a standalone copy-anywhere component.
//
// Deliberately self-contained: no include of params.scad, nothing about
// tripods or telescopes in it. Same reasoning as ../mount/nema17.scad --
// a knob is not a feature of this riser, it is a thing this shop keeps
// making, and the next mechanism that needs one should be able to copy
// one file.
//
// The geometry is generalized from optics/focus_pinion.scad, where the
// three-lobe "fidget spinner" silhouette was arrived at by measurement
// rather than by eye. The reasoning is worth carrying over verbatim
// because it is not obvious:
//
//   A polar cosine, r = R - d + d*cos(N*theta), can only make a SCALLOPED
//   polygon: broad lobes, shallow valleys. A grip wants the opposite --
//   nearly-full circular bulbs joined through a genuinely thin waist,
//   because the waist is what a finger and thumb pinch and the bulb
//   beyond it is the mechanical stop that keeps them from sliding under
//   torque. A shallow scallop only offers friction.
//
//   The valley is an explicit arc TANGENT to both neighbouring bulbs,
//   solved for, not a morphological closing. A closing of radius f fills
//   any concavity narrower than 2f, and the gap between adjacent bulbs is
//   only a few millimetres -- so a closing large enough to look like a
//   valley bridged the gap outright and erased the neck it was supposed
//   to shape.
//
// Everything below is parameterized. Nothing in it is measured; it is all
// CHOSEN geometry, so there is no provenance table to keep.

// Solve the valley arc's centre distance from the axis.
//
// The arc sits on the bisector between two bulbs and must be exactly
// (valley_r + lobe_r) from each bulb centre -- that IS the tangency
// condition. Law of cosines on the triangle (origin, bulb centre, arc
// centre), with half the lobe pitch as the included angle:
//
//     (valley_r + lobe_r)^2 = rp^2 + arm_r^2 - 2*rp*arm_r*cos(half)
//
// solved for rp. For lobes = 3 this reduces to the closed form the optics
// knob used; the general form is here so a 4- or 6-lobe knob is one
// argument away rather than a new derivation.
function knob_valley_rp(arm_r, lobe_r, valley_r, lobes) =
    let (half = 180 / lobes,
         b    = arm_r * cos(half),
         disc = b * b - arm_r * arm_r + pow(valley_r + lobe_r, 2))
    assert(disc >= 0,
           str("knob: no tangent valley arc exists for arm_r ", arm_r,
               ", lobe_r ", lobe_r, ", valley_r ", valley_r, ", lobes ",
               lobes, ". The bulbs are too far apart for an arc of that ",
               "radius to touch both."))
    b + sqrt(disc);

module knob_profile(d, lobes = 3, lobe_r = undef, valley_r = undef) {
    lr    = is_undef(lobe_r) ? d * 0.20 : lobe_r;
    vr    = is_undef(valley_r) ? lr : valley_r;
    arm_r = d / 2 - lr;
    rp    = knob_valley_rp(arm_r, lr, vr, lobes);

    assert(arm_r > 0, "knob: lobe_r is larger than the knob's own radius");

    difference() {
        union() {
            // The web is sized to arm_r, NOT to the finished waist. Sized
            // to the waist, its own rim pokes past the valley arc wherever
            // the arc does not reach and leaves a visible notch at every
            // valley. At arm_r a bulb covers the rim at every angle the
            // valleys do not cut, so the web never becomes the outer
            // boundary anywhere.
            circle(r = arm_r, $fn = KNOB_PROFILE_FN);
            for (i = [0 : lobes - 1])
                rotate([0, 0, i * 360 / lobes])
                    translate([arm_r, 0]) circle(r = lr, $fn = KNOB_PROFILE_FN);
        }
        // The bulbs do not touch each other, so without the web above
        // these arcs would float clear of all material and cut nothing --
        // which is exactly what the first attempt did, leaving the waist
        // unchanged and the defect invisible in every render.
        for (i = [0 : lobes - 1])
            rotate([0, 0, 180 / lobes + i * 360 / lobes])
                translate([rp, 0]) circle(r = vr, $fn = KNOB_PROFILE_FN);
    }
}

// Chamfer by STACKED OFFSETS, not by linear_extrude(scale=) and not by
// hull(). scale= sweeps a ruled surface toward a point, and on a CONCAVE
// outline -- which the waists very much are -- that surface
// self-intersects and hands back a non-manifold solid that still renders
// and still measures correctly. hull() is worse: the hull of a lobed
// profile is convex, so it fills every waist and gives back a plain disc.
// Intersecting with a chamfered cylinder cuts at a single radius, so it
// bites the bulb tips and leaves the waists square.
//
// A short stack of plain prisms, each offset a little further out, is
// manifold by construction.
KNOB_PROFILE_FN = 64;      // segments per bulb/valley arc. See the note
                           // on $fa in params.scad: this number is paid
                           // for once per chamfer step, so it is the most
                           // expensive constant in the whole directory.
KNOB_CHAMFER_STEPS = 8;   // set by how it LOOKS in a render, not by how
                           // it prints -- at 12 steps over a 1mm chamfer
                           // each riser is 0.083mm, well under a layer, so
                           // 6 would print identically but reads as
                           // visible banding on screen.

module knob_bevel(d, h, o_start, o_end, lobes, lobe_r, valley_r) {
    for (i = [0 : KNOB_CHAMFER_STEPS - 1])
        translate([0, 0, h * i / KNOB_CHAMFER_STEPS])
            linear_extrude(height = h / KNOB_CHAMFER_STEPS + 0.01)
                offset(r = o_start + (o_end - o_start) * i / KNOB_CHAMFER_STEPS)
                    knob_profile(d, lobes, lobe_r, valley_r);
}

// The grip itself, sitting on Z=0 and growing +Z.
module knob(d, h, lobes = 3, lobe_r = undef, valley_r = undef,
            chamfer = 1.0) {
    c   = chamfer;
    eps = 0.01;
    assert(h > 2 * c, "knob: height does not leave room for both chamfers");
    // Bottom chamfer also gives the first layer a smaller footprint that
    // grows outward, the usual dodge for elephant foot on a wide disc.
    knob_bevel(d, c, -c, 0, lobes, lobe_r, valley_r);
    translate([0, 0, c - eps])
        linear_extrude(height = h - 2 * c + 2 * eps)
            knob_profile(d, lobes, lobe_r, valley_r);
    translate([0, 0, h - c])
        knob_bevel(d, c, 0, -c, lobes, lobe_r, valley_r);
}
