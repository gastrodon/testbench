// PEDESTAL -- the grounded body. Everything else moves relative to this.
//
// Kinematic role (cad-design rule 6): THIS IS GROUND, said out loud. A
// mechanism whose parts are each posed independently, with no declared
// ground, can translate as one rigid lump and still pass every
// interference and contact check ever written. assembly.scad derives all
// motion from this body and never poses anything on its own.
//
// Carries:
//   - the tripod interface: a flat seating face, three anti-rotation
//     posts, and the big printed stud the hand nut pulls up on
//   - the azimuth journal post and its annular thrust face
//   - the fixed pin the azimuth knob turns on
//
// FRAME: local == assembly. Azimuth axis along +Z, plate underside at
// Z=0, which is the TRIPOD MOUNTING FACE. Also its print orientation --
// flat on the bed, pins up. The captured nut pocket therefore prints as a
// bridged void and wants a pause; that is print-job's problem, not this
// file's.

include <params.scad>

module pedestal() {
    assert(is_num(az_post_d), "pedestal: params.scad not included");

    // The azimuth gear pair is SUNK into the plate's top face. Both
    // pockets are cut to the same floor, which is what makes the two
    // gears coplanar by construction rather than by two numbers that
    // happen to agree today.
    // One radius, from params, because the thrust ring's own assert
    // depends on the same number. Written out twice here it was already a
    // duplication defect, whether or not the two copies agreed.
    pocket_r_tbl = az_pocket_r;
    pocket_r_knb = az_pocket_r;

    difference() {
        union() {
            cylinder(h = base_plate_t, r = base_plate_r);
            // Thrust face: a raised annulus the table rides on, so the
            // contact is a defined narrow ring rather than an ill-defined
            // whole-plate rub. DESIGNED-TO-TOUCH -- check.py tests it for
            // sustained distributed contact, not merely for the absence
            // of overlap, because "nothing intersects" is also true of
            // two parts a metre apart.
            cylinder(h = az_deck_z, r = az_thrust_r);
            // Azimuth post. It runs up through the table and on into the
            // column's foot, so one long journal serves both rather than
            // the table having a short one and the column none.
            cylinder(h = az_post_top_z, d = az_post_d);
            // The azimuth knob's fixed pin.
            translate([az_gear_cd, 0, 0])
                cylinder(h = az_knob_pin_top, d = az_knob_pin_d);

            // --- the tripod interface, all below Z=0 ---
            // No spigot and no relief: the tripod's plate stands 2-3mm
            // PROUD of its casting, so this plate's own underside seats
            // straight onto it and the 136mm rim floats clear. See params
            // section 10 -- an earlier version grew a spigot to reach into
            // a well that a photograph invented.
            // Three posts, on the circle derived from the measured web.
            // These take the torque. Nothing else does -- the stud only
            // clamps, and a clamped joint on one axis is a joint that
            // slowly rotates.
            for (i = [0 : tripod_hole_n - 1])
                rotate([0, 0, i * 360 / tripod_hole_n])
                    translate([tripod_bolt_r, 0, -post_len])
                        cylinder(h = post_len, d = post_d);
            // The stud. Printed male thread, coarse on purpose: a fine
            // printed thread is a row of unsupported ridges. It carries
            // clamp load only -- in normal use the riser stands ON the
            // plate in compression and the thread merely stops it lifting.
            translate([0, 0, -stud_len])
                threaded_rod(d = stud_thread_d, pitch = stud_pitch,
                             l = stud_len, bevel1 = true, anchor = BOTTOM,
                             internal = false, blunt_start = true);
        }

        // --- the two sunk gear pockets ---
        // ANNULAR, not plain cylinders. Cut as plain cylinders they are
        // wider than the post and the pin standing in the middle of them,
        // so they slice both off at the ankles: the model stays
        // watertight, renders identically, and comes apart into three
        // floating bodies. Caught by counting bodies; invisible in every
        // render. cad-design rule 2, and the reason check.py asserts a
        // body count for every part rather than trusting that it built.
        pocket_h = az_deck_z - az_pocket_floor + 1;
        translate([0, 0, az_pocket_floor])
            difference() {
                cylinder(h = pocket_h, r = pocket_r_tbl);
                translate([0, 0, -1])
                    cylinder(h = pocket_h + 2, d = az_post_d);
            }
        translate([az_gear_cd, 0, az_pocket_floor])
            difference() {
                cylinder(h = pocket_h, r = pocket_r_knb);
                translate([0, 0, -1])
                    cylinder(h = pocket_h + 2, d = az_knob_pin_d);
            }

        // --- collar groove: axial retention for the column ---
        // The column's grub screws land in here. It stops the assembly
        // lifting off the post; it does NOT preload anything. The azimuth
        // drag comes from the payload's own weight on the thrust ring, so
        // there is no preloaded joint on this axis at all -- see section 7
        // of params.scad for why this axis needs no more than that.
        translate([0, 0, az_groove_z - az_groove_w / 2])
            difference() {
                cylinder(h = az_groove_w, d = az_post_d + 2);
                cylinder(h = az_groove_w, d = az_post_d - 2 * az_groove_depth);
            }

        // --- pilot for the azimuth knob's retaining screw ---
        translate([az_gear_cd, 0, az_knob_pin_top - 12])
            cylinder(h = 13, d = 2.5);   // M3 pilot, cut into the pin

        // --- lighten the rim ---
        for (i = [0 : 7])
            rotate([0, 0, 22.5 + i * 45])
                translate([(az_thrust_r + base_plate_r) / 2 + 4, 0, -1])
                    cylinder(h = base_plate_t + 2, d = 9);
    }
}

pedestal();
