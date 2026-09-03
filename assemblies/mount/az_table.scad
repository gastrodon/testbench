// AZ TABLE -- the 160T azimuth wheel and the platform the yoke bolts to.
//
// Kinematic role (rule 6): rotates about the vertical azimuth axis
// relative to base.scad, which is the GROUNDED body. Everything above it
// -- yoke, alt rotor, telescope -- rides on this one part, so its journal
// fit and thrust face are what decide whether the whole rig is rigid or
// wobbly.
//
// 360 deg unlimited: nothing here mechanically stops rotation. The real
// limit is the altitude motor's cable, which has to either slip-ring or be
// unwound between sessions. That is recorded as an open item in README.md,
// not silently designed around.
//
// FRAME: local, azimuth axis along +Z, table underside at Z=0. Same as its
// assembly orientation, and also its print orientation (wheel flat on the
// bed, teeth vertical) -- the three coincide here, which is convenient and
// is stated rather than assumed (rule 5).

include <params.scad>
use <gt2.scad>

module az_table() {
    assert(is_num(axis_teeth), "az_table: params.scad not included");
    assert(az_table_r > gt2_env_r_axis() * 0.5,
           "az_table: plate is smaller than its own belt wheel");

    difference() {
        union() {
            // The 160T wheel sits at the BOTTOM, right above the base's
            // thrust face, and the deck plate rides on top of it. Integral
            // with the table rather than a bolted-on pulley: one part, no
            // phase error between wheel and platform, nothing to loosen.
            //
            // Deck-on-bottom (the first attempt) put the yoke's foot in
            // the same volume as the wheel and its belt. Both parts still
            // rendered perfectly; only an orthographic assembly view
            // showed it.
            translate([0, 0, gt2_envelope_h() / 2]) gt2_pulley(axis_teeth);
            // Deck plate.
            translate([0, 0, gt2_envelope_h()])
                cylinder(h = az_table_t, r = az_table_r);
            // No boss hangs BELOW the deck. A downward boss has nowhere to
            // go: the base's plate and post already occupy that space, and
            // the first version drove 845 mm3 of table straight into the
            // base. The post comes UP through this table instead -- and on
            // into the yoke's foot, so table and yoke share one journal.
        }
        // Journal bore -- running fit on base's post.
        translate([0, 0, -az_post_h - 1])
            cylinder(h = az_post_h + az_table_t + gt2_envelope_h() + 4,
                     d = az_post_d + 2 * az_journal_fit);
        // Deck datum used by every hole below.
        // Retaining screw counterbore, from the top, so a washer + M5 can
        // hold the table down onto its thrust face without clamping it.
        translate([0, 0, gt2_envelope_h() + az_table_t - 2.5])
            cylinder(h = 20, d = az_retain_d * 2.4);
        // Yoke foot bolt pattern -- must match yoke.scad's foot holes.
        // Both read yoke_blade_w / yoke_foot_r from the same source.
        for (sx = [-1, 1], sy = [-1, 1])
            translate([sx * yoke_foot_bolt_x, sy * yoke_foot_bolt_y,
                       gt2_envelope_h() - 1])
                cylinder(h = az_table_t + 2, d = nema_screw_d);
        // Lighten the plate between wheel and journal.
        for (i = [0 : 5])
            rotate([0, 0, i * 60])
                translate([az_table_r * 0.62, 0, gt2_envelope_h() - 1])
                    cylinder(h = az_table_t + 2, d = 12);
    }
}

az_table();
