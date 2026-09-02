// Base mount — the FIXED half of the prime-focus microscope.
// https://linear.app/gastrodon/document/microscope-camera-design-doc-15a95f836b98
//
// One printed piece carrying everything that does not move:
//   * the 150x objective cell, on a real 9mm printed thread in the floor
//   * the sleeve bore the camera carrier's tube slides in (the bearing)
//   * the pinion yoke, holding the axle in double shear
//   * a LEGO Technic pin breakout for provisional structure
//
// Focus works because THIS body stays put while pcb_carrier.scad travels,
// changing the sensor-to-objective distance. The objective used to live on
// the moving tube, where sliding it would have changed nothing.
//
// The telescoping inner tube that used to be here is gone: it became part
// of the carrier, which is the moving body.

include <params.scad>
include <lib/BOSL2/std.scad>
include <lib/BOSL2/threading.scad>
// gears.scad is NOT part of std.scad. Without it gear_dist() is
// undefined, silently yields undef, and the bearing boss gets built at a
// garbage position — OpenSCAD only warns. The yoke still rendered, still
// came out watertight, and still passed every interference check,
// because malformed geometry that happens to miss everything looks
// exactly like correct geometry to a clearance test.
include <lib/BOSL2/gears.scad>
include <lib/Technic.scad/Technic.scad>

$slop = 0.1; // FDM print clearance for the internal thread mask, mm; tune per-printer

// obj_bore_depth comes from params.scad, shared with the thread coupons
floor_t = obj_bore_depth + 1.5;    // base floor carrying the objective thread

// Sleeve runs up to just below the rack's lowest position (z=59.4 at
// focus home) — "extends up a little" without needing a slot through the
// tube wall itself. The rack's backing sits at y=-10.875, inside the
// sleeve's 11.7mm outer radius, so a taller tube WOULD have to be slit.
sleeve_len = 56;
sleeve_id = carrier_tube_od + 2 * clearance;   // the moving tube's bearing
sleeve_od = sleeve_id + 2 * wall;

breakout_z = 20;   // explicit, not sleeve_len/2 — the sleeve length changed once

// --- pinion yoke ------------------------------------------------------
// The frame. Two arms rise from the sleeve and straddle the rack, so the
// pinion axle is carried in DOUBLE SHEAR — a bearing either side of the
// gear rather than a cantilever. The gap between the arms is the slit the
// rack travels in; a back web closes them into a U-channel for rigidity.
//
// Every dimension here is a clearance against something that moves:
//   rack sweeps  x -4..4,  y -14.25..-10.875,  z 59.4..110
//   gear reaches y -23.47 at its OD
// so the arms sit outside |x|=4 and the web sits beyond y=-23.47.
pinion_y = rack_y - gear_dist(mod = gear_mod, teeth1 = pinion_teeth,
                              teeth2 = 0, pressure_angle = gear_pressure_angle);
// rack_slot_half comes from params.scad — the pinion's taper clearance
// assert depends on the same number, so it cannot live here.
// arm_t comes from params.scad — clip_coupon.scad sizes against it too
arm_x = rack_slot_half + arm_t / 2;          // arm centreline
bearing_d = shaft_d_frame + 0.35;            // running clearance on the shaft
bearing_boss_d = shaft_d_frame + 7;   // follows the shaft, not a fixed 11
// The strut is ONE straight member. It leaves the bearing boss and runs
// down at a slight lean to land on the sleeve at foot_z — a little above
// where the base ends, not at its corner. That gives a single obtuse
// junction (~172 deg to the sleeve wall) instead of the old shape, which
// ran parallel to the sleeve for 44mm and then turned, leaving a corner
// plus a radial blend where it met the base.
foot_z = 12;               // where the strut lands, just above the base end
foot_h = 11;               // footprint along the tube axis
foot_y_out = -13.5;        // outboard edge of the foot
// Moving the arms outboard puts the foot on a thinner part of the round
// wall: at x=8.5 the wall spans y=-8.04..-3.77, so a foot stopping at
// -7.5 would catch only 0.54mm of it. -5.5 keeps 2.5mm of real overlap
// and still clears the bore by 1.7mm.
foot_y_in = -5.5;
bridge_drop = 11;          // bridge sits below the gear, back stays open
bridge_d = 9;
// Snap-fit bearing: the bore opens upward through a throat slightly
// narrower than the axle, so the gear+axle drops in from above and
// clicks home instead of needing to be threaded through two closed
// bores with the gear balanced between them.
snap_throat = shaft_d_frame - 0.3;

// Nothing in the frame may reach the carrier's underside, which sits at
// carrier_z_home and travels UP from there — so the home position is the
// worst case, not the extended one.
yoke_ceiling = carrier_z_home - 1.5;

module objective_thread_bore() {
    // Real printed 9mm thread, not a self-tapping guess. Pitch is
    // unconfirmed (see params.scad) — reprint once measured.
    //
    // The thread alone does NOT open the floor: it stops at
    // obj_bore_depth, leaving solid plastic above it and no light path.
    // A clear bore carries on through, slightly narrower than the thread
    // so the cell bottoms against a positive shoulder instead of being
    // screwed in to an arbitrary depth.
    up(-0.5)
        threaded_rod(
            d = obj_thread_d, l = obj_bore_depth + 0.5, pitch = obj_thread_pitch,
            internal = true, bevel2 = true, blunt_start1 = false,
            anchor = BOTTOM
        );
    translate([0, 0, obj_bore_depth - 0.01])
        cylinder(d = obj_thread_d - 1.2, h = floor_t - obj_bore_depth + 1.02);
}

module base_floor_solid() {
    // Just the solid disc. Its bore is subtracted at the TOP level, not
    // here: base_mount() unions this with a solid sleeve cylinder that
    // spans z=0 upward, which would refill any hole cut inside this
    // module. Subtracting locally and then unioning something solid over
    // it left the floor completely closed — no light path at all, and
    // nothing flagged it because a blocked bore interferes with nothing.
    cyl(d = sleeve_od, h = floor_t, anchor = BOTTOM, chamfer1 = 0.8);
}

// --- Technic adapter mounting pad -------------------------------------
// The pins themselves now live on technic_adapter.scad, which bolts on
// here. All this part provides is a flat, square pad with a pilot hole —
// so the adapter's flat face has something true to sit against instead
// of a round tube.
pad_t = 4.0;                     // pad stands off the sleeve wall
pad_face_w = technic_pin_spacing + 14;
pad_face_h = 15;
m3_pilot = 2.6;                  // self-tapping M3 bites into this
m3_pilot_depth = 8;

module technic_breakout_solid() {
    // Flat pad, blended into the round wall with a hull so there is no
    // abrupt section change at the joint.
    pad_x = sleeve_od / 2 + pad_t;
    hull() {
        // saddle footprint on the sleeve
        intersection() {
            difference() {
                cylinder(d = sleeve_od + 1.0, h = pad_face_h + 8,
                         center = true);
                translate([0, 0, -pad_face_h])
                    cylinder(d = sleeve_id, h = pad_face_h * 4, center = true);
            }
            translate([sleeve_od / 4, 0, 0])
                cube([sleeve_od / 2, pad_face_w, pad_face_h + 8],
                     center = true);
        }
        // the flat face itself
        translate([pad_x - 1.2, 0, 0])
            cuboid([2.4, pad_face_w, pad_face_h], rounding = 2.5,
                   edges = "X");
    }
}

module technic_pad_cuts() {
    // Pilot for the adapter's M3, drilled into the flat face
    translate([sleeve_od / 2 + pad_t + 1, 0, 0])
        rotate([0, 90, 0])
            translate([0, 0, -m3_pilot_depth - 1])
                cylinder(d = m3_pilot, h = m3_pilot_depth + 1.2);
}

module pinion_yoke_solid() {
    // OPEN BACK. The arms root into the sleeve and rise to the bearings
    // with nothing behind the gear — you can get a finger and a hex key
    // in there, and the gear is visible while setting it. The closed web
    // that used to span the back added stiffness but walled the
    // mechanism in; a low bridge UNDER the gear ties the arms instead,
    // which resists splay without blocking access.
    for (s = [-1, 1]) {
        translate([s * arm_x, 0, 0]) {
            hull() {
                // Long root, low on the sleeve. Extending the strut down
                // like this lets it meet the base at a shallow, obtuse
                // angle instead of standing off it in two right-angle
                // steps — smoother load path and no overhang to bridge.
                // Foot. It must overlap the sleeve WALL without reaching
                // into the bore: at x=+/-arm_x the bore surface is only
                // y=-6.1, so a pad running further in sits squarely in
                // the carrier tube's path — a 3.1mm^3 collision the
                // interference check caught once already.
                translate([0, (foot_y_out + foot_y_in) / 2, foot_z])
                    cuboid([arm_t, foot_y_in - foot_y_out, foot_h],
                           rounding = 2.5, edges = "X");
                translate([-arm_t / 2, pinion_y, pinion_z])
                    rotate([0, 90, 0])
                        cylinder(d = bearing_boss_d, h = arm_t);
            }
        }
    }
    // Bridge under the gear: ties the two arms without closing the back.
    hull() {
        for (s = [-1, 1])
            translate([s * arm_x, pinion_y, pinion_z - bridge_drop])
                rotate([0, 90, 0])
                    cylinder(d = bridge_d, h = arm_t, center = true);
    }
}

module pinion_yoke_cuts() {
    // Rack travel slot: the swept volume of the rack across the whole
    // focus range, plus clearance. Cutting the SWEPT volume rather than
    // the rack's home position is the point — the rack moves 20mm.
    translate([-rack_slot_half, rack_y - 3, sleeve_len - 4])
        cube([2 * rack_slot_half, rack_backing + 5, 70]);

    // Gear pocket, so the pinion can spin without touching the web
    translate([-rack_slot_half, pinion_y, pinion_z])
        rotate([0, 90, 0])
            cylinder(d = 14, h = 2 * rack_slot_half);

    // Bearing bores, both arms, one continuous axis
    translate([-(arm_x + arm_t), pinion_y, pinion_z])
        rotate([0, 90, 0])
            cylinder(d = bearing_d, h = 2 * (arm_x + arm_t));

    // Snap throat: a slot from each bore straight up through the boss,
    // narrower than the axle so it holds once seated. Chamfered at the
    // mouth so the rod has something to wedge against on the way in
    // rather than a square lip to catch on.
    for (sgn = [-1, 1])
        translate([sgn * arm_x, pinion_y, pinion_z]) {
            translate([-arm_t / 2 - 0.1, -snap_throat / 2, 0])
                cube([arm_t + 0.2, snap_throat, bearing_boss_d]);
            translate([-arm_t / 2 - 0.1, 0, bearing_boss_d / 2 - 0.6])
                rotate([0, 90, 0])
                    cylinder(d1 = snap_throat, d2 = snap_throat + 2.6,
                             h = arm_t + 0.2);
        }

    // Trim everything above the carrier's underside, then break the
    // resulting sharp top edge. A guillotine cut leaves a knife edge
    // that prints badly and is unpleasant to handle.
    translate([-60, -60, yoke_ceiling])
        cube([120, 120, 60]);
    // NOTE: an edge-breaking cone was tried here and removed. Centred on
    // the boss at the ceiling it reached +/-6.35mm in Y at the bore's own
    // height — wider than the 5.5mm boss — and silently deleted the
    // entire bearing. The ceiling leaves a flat horizontal face, which
    // prints fine and needs no chamfer; the features that actually
    // wanted softening are the rims and the bore lead-in, done above.
}

module base_mount() {
    // Bore and cutouts are subtracted LAST, after the breakout is
    // unioned on — hull() fills its own concavity, so subtracting the
    // bore first would let the flare bridge across the light path.
    difference() {
        union() {
            // Chamfered rims top and bottom. A square bottom edge is
            // where elephant foot shows worst; a square top rim is what
            // the carrier tube has to be guided past on assembly.
            cyl(d = sleeve_od, h = sleeve_len, anchor = BOTTOM,
                chamfer1 = 0.8, chamfer2 = 1.2);
            base_floor_solid();
            translate([0, 0, breakout_z])
                technic_breakout_solid();
            pinion_yoke_solid();
        }

        // Bore starts above the floor; the floor keeps its own smaller
        // threaded opening. No clamp slot or clamp screw any more: the
        // carrier is positioned by the rack and pinion, not pinched.
        translate([0, 0, floor_t])
            cylinder(d = sleeve_id, h = sleeve_len);
        // lead-in so the carrier tube self-centres instead of catching
        translate([0, 0, sleeve_len - 1.6])
            cylinder(d1 = sleeve_id, d2 = sleeve_id + 3.2, h = 1.7);

        // Objective thread + its clear optical path, subtracted LAST so
        // nothing unioned above can fill it back in.
        objective_thread_bore();

        pinion_yoke_cuts();

        translate([0, 0, breakout_z])
            technic_pad_cuts();
    }
}

// One printed part, upright: floor on the bed, bore opening up.
base_mount();
