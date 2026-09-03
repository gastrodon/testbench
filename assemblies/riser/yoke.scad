// YOKE -- both tines, both gussets, the trunnion and the gear pin, as ONE
// separate printed part that keys into the column's top.
//
// eva's split. Everything the tilt stage and the gears interface with is
// here; the column below is a plain tower.
//
// Kinematic role (rule 6): RIGID with az_column. It turns in azimuth with
// the column and does not move relative to it at all -- the joint exists
// for printing and assembly, not for motion. Worth stating, because a
// part meant not to move is exactly the kind a checker will happily
// report as "no interference" while it quietly falls out.
//
// TWO DIFFERENT TINES, on purpose:
//   -Y  the DRIVE tine. Closed bore, counterbore for the platter's flange
//       journal, the clamp, and the pin both gears run on.
//   +Y  the SADDLE tine. An open seat the platter's second stub drops
//       into. Open because two closed bores on one axis cannot be
//       assembled at all: neither stub can enter its bore without the
//       other leaving one.
//
// Having BOTH seats on this one part is what makes the span between them
// a printed dimension rather than an assembly dimension. Split across two
// parts, any error in the joint went straight into axis alignment.
//
// FRAME: local == assembly at azimuth 0. Print orientation is flat -- the
// blade on the bed, tenon in the plane of the bed -- which is NOT this
// orientation (rule 5). print.scad owns that transform.

include <params.scad>

// The blade: one plate spanning both tines, thin in X. Its roof follows
// yoke_ceiling(y) rather than sitting at a constant height, because the
// thing it has to duck under -- the platter's own radius swinging about
// the tilt axis -- is not a constant either. Its floor sits above the
// azimuth knob, because everything here sweeps a full circle in azimuth
// and the knob does not move.
module yoke_blade() {
    ys = [for (i = [0 : 2 * YOKE_SAMPLES])
              tilt_arm_y_out
              + (tilt_arm2_y_out - tilt_arm_y_out) * i / (2 * YOKE_SAMPLES)];
    // FLAT underside, end to end. No tongue below it and no step up over
    // the column: the stretch of blade that lands inside the column is
    // the tenon, and the column's slit is cut to take it. The step this
    // replaces left a 2mm notch either side of the tongue -- clean on
    // every measurement and plainly wrong in an orthographic view.
    rotate([0, -90, 0])
        linear_extrude(height = yoke_web_t, center = true)
            polygon(concat(
                [for (y = ys) [yoke_ceiling(y), y]],
                [[yoke_bottom_z, tilt_arm2_y_out],
                 [yoke_bottom_z, tilt_arm_y_out]]));
}

// The DRIVE tine's outline, in XZ.
module tine_profile() {
    hull() {
        translate([0, tilt_axis_z]) circle(r = tilt_arm_x);
        translate([-tilt_arm_x, yoke_bottom_z])
            square([2 * tilt_arm_x, 10]);
    }
}

module yoke() {
    assert(is_num(yoke_tenon_h), "yoke: params.scad not included");

    seat_r = saddle_seat_r();
    // Mouth width: the chord across the opening. The seat wraps past 180
    // degrees, so this is NARROWER than the stub and the stub snaps
    // through it. Under 180 the seat is a shelf a knock can lift it off.
    mouth  = 2 * seat_r * sin((360 - tilt_saddle_wrap) / 2);
    assert(mouth < tilt_saddle_d,
           str("yoke: the mouth is ", mouth, "mm across a ", tilt_saddle_d,
               "mm stub -- it captures nothing."));
    assert(tilt_saddle_d - mouth < 1.2,
           str("yoke: the mouth is ", tilt_saddle_d - mouth, "mm undersize. ",
               "A printed seat opens a few tenths, not millimetres."));

    difference() {
        union() {
            yoke_blade();

            // Drive tine, -Y. Built in XZ and swung into a Y-normal slab.
            // rotate([-90,0,0]) is the transform that reads correctly here
            // and it flips Z, dropping the whole tine below the base plate
            // -- watertight, valid, and nowhere near the axis it holds.
            translate([0, tilt_arm_y, 0])
                rotate([90, 0, 0])
                    linear_extrude(height = tilt_arm_t) tine_profile();

            // Saddle tine, +Y. A CRADLE, not the drive tine's arch with a
            // channel cut through it: the profile is capped just above
            // where the seat's wrap ends, so what is left either side of
            // the mouth is two horns that do the capturing. The arch this
            // replaces carried no load -- the payload presses DOWN into
            // the seat -- and reading it as a slot through solid material
            // was the correct reading, because that is what it was.
            translate([0, tilt_arm2_y_out, 0])
                rotate([90, 0, 0])
                    linear_extrude(height = tilt_arm_t)
                        difference() {
                            intersection() {
                                tine_profile();
                                translate([-tilt_arm_x - 1, yoke_bottom_z])
                                    square([2 * tilt_arm_x + 2,
                                            tilt_axis_z + saddle_horn_h
                                            - yoke_bottom_z]);
                            }
                            translate([0, tilt_axis_z]) circle(r = seat_r);
                            translate([-mouth / 2, tilt_axis_z])
                                square([mouth, saddle_horn_h + 2]);
                        }

            // The tilt knob's fixed pin, on the drive tine's OUTER face.
            translate([tilt_knob_x, tilt_arm_y_out, tilt_knob_z])
                rotate([90, 0, 0])
                    cylinder(h = tilt_knob_pin_h, d = tilt_knob_pin_d);
        }

        // --- trunnion: counterbore for the platter's flange journal,
        //     then the stub bore straight on through the drive tine ---
        translate([0, tilt_arm_y - tilt_journal_h, tilt_axis_z])
            rotate([-90, 0, 0])
                cylinder(h = tilt_journal_h + 1,
                         d = tilt_journal_d + 2 * tilt_fit);
        translate([0, tilt_arm_y_out - 1, tilt_axis_z])
            rotate([-90, 0, 0])
                cylinder(h = tilt_arm_t + 2, d = tilt_stub_d + 2 * tilt_fit);

        // --- pilot for the tilt knob's retaining screw ---
        translate([tilt_knob_x, tilt_arm_y_out - tilt_knob_pin_h,
                   tilt_knob_z])
            rotate([-90, 0, 0])
                cylinder(h = 14, d = 2.5);   // +Y, INTO the pin
    }
}

yoke();
