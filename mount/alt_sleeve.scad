// ALT SLEEVE -- the shoulder bushing that keeps the altitude axis free.
//
// This tiny part is the reason the mechanism moves at all. The telescope's
// pivot bolt threads into the far bracket's brass insert, so tightening it
// pulls both brackets together and clamps everything between them. If the
// yoke tine were in that clamp path, the altitude axis would be locked
// solid -- and a locked axis is geometrically indistinguishable from a
// working one in any interference or contact check (cad-design rule 6).
//
// The sleeve takes the clamp load instead: it is fractionally LONGER than
// the tine is thick, so the bolt squeezes bracket -> sleeve -> bracket and
// the tine spins free on the sleeve's OD.
//
// Kinematic role: clamped to the TELESCOPE (turns with it). The tine is
// the journal, the sleeve is the shaft.
//
// FRAME: local, axis along +Z, seated at Z=0. This is also its print
// orientation -- upright, so the journal OD comes out round rather than
// elephant-footed on one side.

include <params.scad>

// sleeve_len / _id / _od live in params.scad, NOT here: yoke.scad's journal
// bore is a running fit on sleeve_od, so the number is shared by two parts
// and belongs to neither (rule 3). sleeve_shoulder_gap is what makes the
// sleeve stand proud of the tine -- less and print tolerance eats it, more
// and the telescope rattles on its own pivot.

module alt_sleeve() {
    assert_fastener_fits();
    assert(is_num(yoke_tine_t) && yoke_tine_t > 0,
           "alt_sleeve: params.scad not included, or bracket_gap is bad");
    assert(sleeve_od < bracket_clear_d + 6,
           "alt_sleeve: OD is large relative to the bracket hole -- check that \
the sleeve's ends actually land on bracket material, not on air");

    difference() {
        cylinder(h = sleeve_len, d = sleeve_od);
        translate([0, 0, -1]) cylinder(h = sleeve_len + 2, d = sleeve_id);
    }
}

alt_sleeve();
