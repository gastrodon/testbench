// AZ COLUMN -- the azimuth-rotating tower. Gear, table, column, mortise.
//
// Kinematic role (rule 6): rotates about +Z relative to the pedestal, and
// carries the yoke -- and therefore the tilt axis -- with it.
//
// It used to carry the yoke as integral geometry. eva split the yoke off,
// and the cut left this part with almost nothing in it: a gear, a plate,
// a tube, and a slot. That is the point. Everything with a tolerance on
// it now lives in yoke.scad, and this is a tower.
//
// FRAME: local == assembly at azimuth 0. Print orientation is table-down,
// column up, which is also this orientation -- so print and assembly
// transforms are the same here and there is nothing to keep in step
// (rule 5). The gear teeth print with layers stacked across the tooth
// face rather than along it.

include <params.scad>

module az_column() {
    assert(is_num(az_gear_cd), "az_column: params.scad not included");
    assert(column_top_z < tilt_axis_z - tilt_ear_sweep_r,
           "az_column: the column top is inside the tilt sweep");

    difference() {
        union() {
            // Azimuth gear, sunk into the pedestal's pocket.
            translate([0, 0, (az_gear_z0 + az_gear_z1) / 2])
                spur_gear(mod = az_gear_mod, teeth = az_gear_teeth,
                          thickness = az_gear_face, shaft_diam = 0,
                          pressure_angle = gear_pa, backlash = gear_backlash,
                          anchor = CENTER);
            // Table. Rides the pedestal's thrust ring -- DESIGNED-TO-TOUCH.
            translate([0, 0, az_table_z])
                cylinder(h = az_table_t, r = az_table_r);
            // Column. Stops at column_top_z, NOT at the tilt axis: the
            // platter is centred on that axis and its rim swings 34mm
            // below it.
            translate([0, 0, az_table_top_z])
                cylinder(h = column_top_z - az_table_top_z, r = column_r);
        }

        // --- azimuth journal, over the pedestal's post ---
        // Blind at the top: the post ends at az_post_top_z and the column
        // carries on solid above it.
        translate([0, 0, az_gear_z0 - 1])
            cylinder(h = az_post_top_z - az_gear_z0 + 2,
                     d = az_post_d + 2 * az_journal_fit);

        // --- grub screws into the post's collar groove ---
        for (i = [0 : az_grub_n - 1])
            rotate([0, 0, 90 + i * 90])
                translate([0, 0, az_groove_z])
                    rotate([0, 90, 0])
                        cylinder(h = column_r + 1, d = az_grub_d);

        // --- screws that retain the yoke ---
        // Through the wall beside the slit, bearing on the blade's flank.
        // Above the collar grubs, which do a different job on a different
        // part; params asserts the two never meet.
        for (i = [0 : yoke_screw_n - 1])
            rotate([0, 0, i * 180])
                translate([0, 0, yoke_screw_z])
                    rotate([0, 90, 0])
                        cylinder(h = column_r + 1, d = yoke_screw_d);

        // --- the yoke's mortise ---
        // Cut with the SAME module the yoke builds its tenon from, grown
        // by the fit. Two hand-written copies of one profile drift exactly
        // the way two hand-written copies of one dimension do.
        tenon_solid(saddle_fit);
    }
}

az_column();
