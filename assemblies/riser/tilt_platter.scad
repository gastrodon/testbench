// TILT PLATTER -- the tilting body. This is what the payload bolts to.
//
// Kinematic role (rule 6): rotates about the tilt axis (along Y, at
// height tilt_axis_z) relative to az_column, and carries the payload
// rigidly. Nothing else tilts. Naming that here matters, because a
// payload posed independently of this part would translate with it and
// interfere with nothing while doing absolutely nothing.
//
// Three features, one body:
//   - the plate, with the captured 1/4-20 stud that faces UP
//   - the ear, a single arm reaching out to the tine at -Y
//   - the trunnion: a wide flange journal, then a stub through the tine
//
// FRAME: local == assembly at tilt 0. Print orientation is on its ear,
// stub pointing up -- NOT this orientation (rule 5); print.scad owns
// that transform.

include <params.scad>

module tilt_platter() {
    assert(is_num(tilt_journal_d), "tilt_platter: params.scad not included");
    // The stud is a bought steel bolt. If the head pocket is deeper than
    // the plate it opens straight through and captures nothing.
    assert(stud_head_t + 2.0 < tilt_platter_t,
           "tilt_platter: no material left over the captured stud's head");

    ear_end_y = tilt_arm_y + 1.0;    // 1mm short of the tine's inner face:
                                     // the flange's shoulder is meant to
                                     // carry the clamp, not this face
    ear2_end_y = tilt_arm2_y - 1.0;  // and the same on the saddle side

    // TRIMMED at the payload's mounting face. The ear is a 22mm-deep
    // section centred on the tilt axis, which puts its top 6mm ABOVE that
    // face -- so it stood inside the payload, 7,157 mm3 of it, at every
    // tilt angle including zero. Nothing on the tilting body may rise
    // above the face the payload sits on. Same trim ../mount/yoke.scad
    // applies to duck its tine under the telescope tube.
    intersection() {
    // The ceiling applies only where the payload actually is. Applied
    // everywhere it also decapitates the flange journal and the saddle
    // stub, both of which live outboard of the payload's rim -- and a
    // journal with its top sliced off is not a journal, it is a cam.
    union() {
        translate([-400, -400, payload_face_z - 400]) cube([800, 800, 400]);
        translate([-400,  payload_r, -400])           cube([800, 400, 800]);
        translate([-400, -payload_r - 400, -400])     cube([800, 400, 800]);
    }
    difference() {
        union() {
            // Plate.
            translate([0, 0, tilt_axis_z - tilt_platter_t / 2])
                cylinder(h = tilt_platter_t, r = tilt_platter_r);
            // Ears, out to both tines. Symmetric, because the two seats
            // now carry the payload's roll moment as a couple rather than
            // one of them carrying all of it in single shear.
            for (end = [ear_end_y, ear2_end_y])
                hull() {
                    translate([0, 0, tilt_axis_z])
                        rotate([90, 0, 0])
                            cylinder(h = 1, d = tilt_ear_h, center = true);
                    translate([-tilt_ear_x / 2, end,
                               tilt_axis_z - tilt_ear_h / 2])
                        cube([tilt_ear_x, 1, tilt_ear_h]);
                }
            // The +Y stub, which rides in the open saddle. Plain and
            // round: it takes load and locates the axis, and nothing
            // clamps it, so it needs no flange, no hex and no thread.
            translate([0, ear2_end_y, tilt_axis_z])
                rotate([-90, 0, 0])
                    cylinder(h = tilt_arm2_y_out - ear2_end_y,
                             d = tilt_saddle_d);
            // Flange journal: the wide shallow disc that runs in the
            // tine's counterbore. Its annular face is the friction surface
            // that holds the tilt -- friction torque goes as the cube of
            // this radius, which is the whole reason it is 44mm and not a
            // 14mm pin.
            translate([0, ear_end_y - tilt_journal_h - 1, tilt_axis_z])
                rotate([-90, 0, 0])
                    cylinder(h = tilt_journal_h + 1, d = tilt_journal_d);
            // Stub, round through the tine's bore...
            translate([0, tilt_arm_y_out - tilt_gear_standoff, tilt_axis_z])
                rotate([-90, 0, 0])
                    cylinder(h = tilt_arm_t + tilt_journal_h
                                 + tilt_gear_standoff + 1,
                             d = tilt_stub_d);
            // ...then hex, outboard, keying the tilt wheel. A hex and not
            // a round with a grub screw: a grub bearing on a round printed
            // boss slips under sustained torque, which is the failure
            // ../mount/alt_rotor.scad was redesigned to get rid of one
            // axis over.
            // The hex starts one standoff OUTBOARD of the tine, so the
            // round-to-hex step is the shoulder the wheel seats on and
            // the wheel lands clear of the tine rather than against it.
            translate([0, tilt_arm_y_out - tilt_gear_standoff
                          - tilt_gear_face, tilt_axis_z])
                rotate([-90, 0, 0])
                    cylinder(h = tilt_gear_face,
                             d = tilt_stub_hex_af / cos(30), $fn = 6);
        }
        // Captured 1/4-20 stud: hex head pocket opening DOWNWARD, shank
        // bore through the top face. A bought steel bolt, not a printed
        // thread -- see params section 1.
        translate([0, 0, tilt_axis_z - tilt_platter_t / 2 - 0.01])
            cylinder(h = stud_head_t, d = stud_head_af / cos(30), $fn = 6);
        translate([0, 0, tilt_axis_z - tilt_platter_t / 2 - 1])
            cylinder(h = tilt_platter_t + 2,
                     d = tripod_major + 2 * clearance);
        // Clamp bore up the stub's axis, for an M6 heat-set insert. The
        // wing nut's preload is the tilt friction, and params section 7
        // says how much of it is needed.
        translate([0, tilt_arm_y_out - tilt_gear_standoff - tilt_gear_face
                      - 2, tilt_axis_z])
            rotate([-90, 0, 0])
                cylinder(h = tilt_gear_face + tilt_arm_t + 10, d = 8.0);
    }
    }
}

tilt_platter();
