// ASSEMBLY -- the posed mechanism, and the only file that knows how the
// parts move relative to each other.
//
// cad-design rule 6, stated as code rather than as a comment: there is
// exactly ONE grounded body here (base), and every other body's pose is
// derived from it by walking the kinematic chain. No part is posed
// independently. This is the discipline that catches "the whole mechanism
// translated as one rigid lump" -- an error that interferes with nothing,
// renders beautifully, and is a complete no-op.
//
//   base            GROUND
//    +-- az_table    rotate az_angle about +Z
//         +-- yoke        rigid on az_table (bolted)
//              +-- telescope    rotate alt_angle about the altitude axis
//                   +-- alt_rotor   rigid on telescope (clamped)
//                   +-- alt_sleeve  rigid on telescope (clamped)
//
// Note where alt_sleeve sits in that tree: on the TELESCOPE, not on the
// yoke. If it were rigid on the yoke, the altitude axis would be locked
// and the mechanism would be a statue that passes every check.
//
// Drive it with -D on the command line ($-variables cannot be set with -D,
// which is why these are plain names -- see AGENTS.md):
//   openscad -D 'az_angle=45' -D 'alt_angle=60' assembly.scad
// or animate the full sweep with animate.scad.

include <params.scad>
use <gt2.scad>
use <alt_rotor.scad>
use <alt_sleeve.scad>
use <yoke.scad>
use <az_table.scad>
use <base.scad>

az_angle  = 0;   // deg, unlimited
alt_angle = 0;   // deg, alt_min_deg .. alt_max_deg (0 = horizon, 90 = zenith)

show_telescope = true;   // proxy solid, NOT a model of the real scope
show_belts     = true;

// ---- proxies -------------------------------------------------------
// These stand in for things we do not make: the telescope tube and the
// motors. They exist so clearance can be MEASURED against them rather
// than eyeballed. Their dimensions are the ASSUMED ones in params.scad,
// so a proxy clash is only as trustworthy as those measurements.

module telescope_proxy() {
    // Tube, lying along +X at the pivot, with the bracket pair below it.
    color("silver", 0.5) {
        translate([-tube_len_behind, 0, tube_bottom_above_pivot + tube_od / 2])
            rotate([0, 90, 0])
                cylinder(h = tube_len_behind + 120, d = tube_od);
        for (s = [-1, 1])
            translate([0, s * (bracket_gap + bracket_t) / 2, 0])
                cube([bracket_w, bracket_t, alt_bore_c_to_bottom * 2],
                     center = true);
    }
}

module nema17_proxy() {
    color("dimgray", 0.6)
        translate([0, 0, -nema_body_len])
            translate([-nema_side / 2, -nema_side / 2, 0])
            cube([nema_side, nema_side, nema_body_len]);
}

// A belt drawn as its pitch-line loop. Not a printed part -- it is here so
// the belt PLANE is visible and measurable, because coplanarity of the two
// pulleys is the one thing a belt drive cannot forgive.
module belt_proxy(d_small, d_big, c) {
    color("black", 0.55)
        linear_extrude(height = belt_width, center = true)
            difference() {
                hull() { circle(d = d_big); translate([c, 0]) circle(d = d_small); }
                hull() { circle(d = d_big - 1.6);
                         translate([c, 0]) circle(d = d_small - 1.6); }
            }
}

// ---- the chain -----------------------------------------------------

// Takes its two joint angles as PARAMETERS, defaulting to the file-scope
// values so -D still drives it. animate.scad needs to set them per frame,
// and `use <>` imports modules but not the variables around them -- so a
// module reading file-scope angles cannot be animated from outside without
// duplicating the whole chain, which is how a second, drifting copy of the
// kinematics gets born.
module assembly(az = az_angle, alt = alt_angle) {
    assert(alt >= alt_min_deg && alt <= alt_max_deg,
           str("assembly: alt_angle ", alt, " is outside the design range ",
               alt_min_deg, "..", alt_max_deg));

    // GROUND.
    color("steelblue", 0.85) base();
    if (show_telescope)
        translate([az_motor_r, 0, az_motor_face_z])
            rotate([180, 0, 0]) nema17_proxy();
    if (show_belts)
        translate([0, 0, az_belt_plane_z])
            belt_proxy(motor_pd, axis_pd, az_motor_r);

    // AZIMUTH stage. The table sits ON the base's raised thrust annulus,
    // not at Z=0. Placing it at Z=0 buries it inside the base plate --
    // and every part still renders perfectly, which is exactly why this
    // had to be measured rather than looked at.
    translate([0, 0, az_deck_z]) rotate([0, 0, az]) {
        color("darkseagreen", 0.9) az_table();

        // Yoke rides rigidly on the table deck.
        translate([0, 0, gt2_env_h_axis() + az_table_t]) {
            color("goldenrod", 0.9) yoke();

            // ALTITUDE stage. The pivot is at the yoke's local axis
            // height; alt_angle turns the telescope about +Y there.
            translate([0, 0, yoke_local_axis_z]) {
                if (show_belts)
                    translate([0, alt_belt_plane_y, 0]) rotate([-90, 0, 0])
                        belt_proxy(motor_pd, axis_pd, axis_centre_dist);
                    // Faceplate bolts to the plate's OUTBOARD surface,
                    // not to its inboard one -- placing it at face_y put
                    // 6,361 mm3 of motor body inside its own mount.
                    translate([axis_centre_dist, alt_motor_seat_y, 0])
                        rotate([90, 0, 0]) nema17_proxy();

                rotate([0, -alt, 0]) {
                    // alt_rotor is modelled axis-along-Z; the altitude
                    // axis is +Y, so it is laid over here. This is the
                    // assembly transform -- it is NOT the part's print
                    // orientation, which stays flat-on-Z in its own file
                    // (rule 5).
                    color("indianred", 0.9)
                        rotate([-90, 0, 0])
                            translate([0, 0, alt_rotor_offset_y])
                                alt_rotor();
                    color("orange", 0.9)
                        rotate([-90, 0, 0])
                            translate([0, 0, -sleeve_len / 2])
                                alt_sleeve();
                    if (show_telescope) telescope_proxy();
                }
            }
        }
    }
}

assembly();
