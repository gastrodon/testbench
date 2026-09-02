// POSE -- emit ONE body, posed exactly where assembly.scad puts it.
//
// This exists so check.py can measure pairs. OpenSCAD cannot be asked
// whether two bodies touch, so the query layer has to get them as separate
// meshes in a COMMON frame -- and the poses must come from the same code
// that draws the assembly, or the checker is measuring a different
// mechanism than the one being built (cad-design rule 4: suspect the
// checker before the design).
//
// assembly.scad's chain is reproduced here by CALLING it with everything
// but one body switched off, rather than by re-writing the transforms.
// Re-writing them is how a checker drifts.
//
//   openscad -D 'part="alt_rotor"' -D 'alt_angle=60' -o out.stl pose.scad

include <params.scad>
use <gt2.scad>
use <alt_rotor.scad>
use <yoke.scad>
use <az_table.scad>
use <base.scad>

part      = "base";
az_angle  = 0;
alt_angle = 0;

module telescope_proxy() {
    translate([-tube_len_behind, 0, tube_bottom_above_pivot + tube_od / 2])
        rotate([0, 90, 0])
            cylinder(h = tube_len_behind + 120, d = tube_od);
    // The brackets are PIERCED -- solid cubes made the axle passing
    // through them read as interference. A proxy defect, not a design one.
    for (s = [-1, 1])
        difference() {
            translate([0, s * (bracket_gap + bracket_t) / 2, 0])
                cube([bracket_w, bracket_t, alt_bore_c_to_bottom * 2],
                     center = true);
            rotate([90, 0, 0])
                cylinder(h = 200, center = true,
                         d = s > 0 ? insert_id + 0.2 : bracket_clear_d);
        }
}

module nema17_proxy() {
    // Centred on the SHAFT axis, which is where the pulley is. Drawing it
    // from a corner instead puts the whole 42mm body 21mm off in two
    // directions, and every clearance measured against it is then wrong.
    // Delegates to nema17.scad rather than redrawing a box. The motor is
    // a shared component now, and its pulley is a SEPARATE call because
    // that is how it is physically attached -- clamped to the shaft, not
    // part of the casting.
    nema17();
    nema17_pulley_envelope();
}

// Same chain as assembly.scad, with ground named and every pose derived
// from it. `part` selects which single body survives.
module posed() {
    if (part == "base") base();
    if (part == "az_motor")
        translate([az_motor_r, 0, az_motor_face_z])
            rotate([180, 0, 0]) nema17_proxy();

    // Table sits on the base's thrust deck -- same datum as assembly.scad,
    // read from the same param, never retyped.
    translate([0, 0, az_deck_z]) rotate([0, 0, az_angle]) {
        if (part == "az_table") az_table();

        translate([0, 0, gt2_env_h_axis() + az_table_t]) {
            if (part == "yoke") yoke();

            translate([0, 0, yoke_local_axis_z]) {
                if (part == "alt_motor")
                    // Faceplate bolts to the plate's OUTBOARD surface,
                    // not to its inboard one -- placing it at face_y put
                    // 6,361 mm3 of motor body inside its own mount.
                    translate([axis_centre_dist, alt_motor_seat_y, 0])
                        rotate([90, 0, 0]) nema17_proxy();

                rotate([0, -alt_angle, 0]) {
                    if (part == "alt_rotor")
                        rotate([-90, 0, 0])
                            translate([0, 0, alt_rotor_offset_y])
                                alt_rotor();
                    if (part == "telescope") telescope_proxy();
                }
            }
        }
    }
}

// Rule 2, enforced: a typo'd part name would emit an empty STL, which is
// watertight, valid, and would sail through every downstream check as
// "no interference". Fail loudly instead.
assert(search([part], [["base", "az_motor", "az_table", "yoke", "alt_motor",
                        "alt_rotor", "telescope"]][0]) != [[]],
       str("pose.scad: unknown part '", part, "'"));

posed();
