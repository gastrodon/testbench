// TRIPOD NUT -- the hand nut that pulls the tripod's plate up against the
// riser. eva's design.
//
// Kinematic role: none. It is a fastener, and once it is tight it is part
// of ground. It is modelled anyway because it is a PRINTED fastener with
// a feature that has to be got right -- the relief -- and an unmodelled
// printed fastener is one nobody checks.
//
// THE RELIEF is the whole point of the part. The three posts pass through
// the tripod's plate and stand post_proud below it. Without an annular
// recess in this nut's top face, the nut lands on three post ends instead
// of on the plate, and the entire mount is then held together by three
// point contacts on a 19.4mm circle. The recess is cut where the posts
// are, sized from the same measured bolt circle they are.
//
// FRAME: local == assembly, threaded bore up the Z axis, relief facing
// +Z toward the plate. Print orientation is FLIPPED -- relief down on the
// bed -- so the thread prints as a vertical spiral and the relief needs
// no bridging. print.scad owns that flip.

include <params.scad>

module tripod_nut() {
    assert(is_num(nut_relief_r0), "tripod_nut: params.scad not included");
    // If the relief is not deeper than the posts stand proud, it is
    // decoration and the nut still lands on them.
    assert(nut_relief_h > post_proud,
           str("tripod_nut: relief is ", nut_relief_h, " deep but the ",
               "posts stand ", post_proud, " proud -- the nut will bear ",
               "on the posts, not on the plate."));

    difference() {
        // Solid cylinder with the same lobed grip the knobs use, so the
        // whole riser has one vocabulary for "turn this by hand".
        knob(d = nut_d, h = nut_h, lobes = 3, chamfer = 1.0);
        // Internal thread. $slop is what makes a printed thread a fit
        // rather than an interference.
        translate([0, 0, -1])
            threaded_rod(d = stud_thread_d, pitch = stud_pitch,
                         l = nut_h + 2, internal = true, bevel = true,
                         blunt_start = true, anchor = BOTTOM, $slop = 0.2);
        // The relief, an annular groove in the top face.
        translate([0, 0, nut_h - nut_relief_h])
            difference() {
                cylinder(h = nut_relief_h + 1, r = nut_relief_r1);
                translate([0, 0, -1])
                    cylinder(h = nut_relief_h + 3, r = nut_relief_r0);
            }
    }
}

tripod_nut();
