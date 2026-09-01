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

obj_bore_depth = obj_thread_engage + 2; // + lead-in beyond the measured engagement
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
rack_slot_half = gear_thickness / 2 + 1.5;   // 1.5mm clearance per side
arm_t = 3;
arm_x = rack_slot_half + arm_t / 2;          // arm centreline
bearing_d = shaft_d_frame + 0.35;            // running clearance on the shaft
bearing_boss_d = 11;
arm_root_z = 26;           // centre of the arm's root pad on the sleeve
arm_root_h = 44;           // tall root: shallow, obtuse meeting with the base
root_y_out = rack_y - 3;   // outboard edge of the root pad
root_y_in = -7.0;          // inboard edge: clear of the bore at x=arm_x
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

// --- Technic pin breakout ---------------------------------------------
// Sized to the real pin, not guessed: a Technic pin_half(length=1) is
// 7.8mm of body plus a 0.7mm collar, so the MOUNT only has to add a few
// mm of padding behind it. The old version stood the plate 10.4mm off
// the tube before the pin even started — nearly three times the pin's
// own reach, cantilevered for no reason.
//
// Each pin gets its own conical flare rather than sharing one slab.
// The flare spreads load into the pad gradually and prints without
// support, since a cone's own slope is self-supporting all the way
// round.
pad_t = 3.4;                     // pad thickness over the sleeve wall
pad_h = technic_pin_spacing + 12;
pad_w = technic_pin_spacing + 11;
flare_len = 2.2;                 // cone length, plate face -> pin root
flare_root_d = 11;               // wide end, on the pad
flare_tip_d = 6.2;               // narrow end, just over the pin collar

module technic_breakout_solid() {
    pad_x = sleeve_od / 2 - 1.2;          // real overlap into the wall
    // Pad: a saddle sharing the sleeve's curvature so it blends in
    // rather than butting onto a round wall.
    intersection() {
        difference() {
            cylinder(d = sleeve_od + 2 * pad_t, h = pad_h, center = true);
            translate([0, 0, -pad_h])
                cylinder(d = sleeve_id, h = pad_h * 3, center = true);
        }
        translate([(sleeve_od / 2 + pad_t) / 2, 0, 0])
            cube([sleeve_od / 2 + pad_t, pad_w, pad_h], center = true);
    }

    for (y = [-technic_pin_spacing / 2, technic_pin_spacing / 2]) {
        // conical flare, then the pin on its tip
        translate([pad_x, y, 0])
            rotate([0, 90, 0])
                cylinder(d1 = flare_root_d, d2 = flare_tip_d,
                         h = flare_len + 1.2);
        translate([pad_x + flare_len + 1.2, y, 0])
            rotate([0, 90, 0])
                translate([0, 0, -0.6])
                    technic_pin_half(length = 1, friction = true);
    }
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
                // The pad must overlap the sleeve WALL without reaching
                // into the bore. At x=+/-arm_x the bore surface is only
                // y=-6.1, so a pad running to y=+1 (as an earlier version
                // did) sits squarely in the carrier tube's path — a
                // 3.1mm^3 collision the interference check caught.
                translate([0, (root_y_out + root_y_in) / 2, arm_root_z])
                    cuboid([arm_t, root_y_in - root_y_out, arm_root_h],
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
    }
}

// One printed part, upright: floor on the bed, bore opening up.
base_mount();
