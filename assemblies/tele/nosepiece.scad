// 0.965" prime-focus nosepiece — the entire telescope-side build per
// EVA-319. Slides into the Power Seeker 50AZ's focuser in place of an
// eyepiece; the NexiGo N60's own female M12x0.5 lens holder threads onto
// the boss at the far end. No rack/pinion: the scope's own drawtube does
// focus (EVA-319 plan step 2 — depth of focus at f/12 is ~+/-0.15mm,
// comfortably inside drawtube resolution).
//
// EVA-319's plan text has an internal contradiction: step 1 says a
// "female bore for the camera holder", step 5 says "reuse the ... M12x0.5
// lens-thread SCAD module ... on a body that mounts into the focuser".
// The microscope build's own coupon (../optics/params.scad) proved the
// camera's holder is FEMALE M12x0.5, so a thread that mates with it must
// be MALE — step 5's module, not step 1's bore. Following step 5.
//
// Bottom to top (matches both the design coordinates below AND the print
// orientation — see the bottom of this file):
//   nose (0.965" male, into the focuser)
//   -> hilt (rounded ridge, bigger than the focuser bore — stops it
//      sliding in and vanishing; see nose_and_hilt() for the profile)
//   -> cone (steep, down to the M12 thread OD)
//   -> boss (male M12x0.5, screws into the camera's own holder,
//      lengthened to reclaim whatever height the steep cone freed up)
// One light bore runs the full length.

include <params.scad>
include <lib/BOSL2/std.scad>
include <lib/BOSL2/threading.scad>

// --- geometry, all derived so nothing here restates params.scad --------

// Both cones are computed at full size FIRST (as if the ridge stayed a
// sharp point), then chamfered back afterward. Doing it in this order —
// rather than designing the chamfer's endpoints directly — means the
// chamfer is always cutting into the SAME two surfaces this file already
// reasoned about (45 deg nose side, boss_taper_angle boss side), so the
// two chamfer cuts naturally land at different angles without having to
// separately state what those angles are.
hilt_dr        = (flange_od - nose_od_male) / 2;
hilt_h_full    = hilt_dr * tan(45);
taper_dr       = (flange_od - lens_thread_d) / 2;
taper_h_full   = taper_dr * tan(boss_taper_angle);

nose_z0     = 0;
hilt_z0     = nose_z0 + nose_len + hilt_h_full;   // theoretical sharp ridge, pre-chamfer
boss_z0     = hilt_z0 + taper_h_full;             // where the thread begins — fixed regardless
                                                    // of how the ridge gets chamfered

// The body-length invariant: steepening the boss-side cone frees up
// axial space, and that space goes entirely into the thread rather than
// shortening the part. Pinned against 45 deg specifically because that
// is what every prior print of this part was measured against — a
// reference point, not an arbitrary one.
taper_h_ref      = taper_dr * tan(45);
boss_thread_len_ = boss_thread_len + (taper_h_ref - taper_h_full);
total_h          = boss_z0 + boss_thread_len_;

// Ridge chamfer: cut the sharp point back into a flat-ish land, split
// evenly around the theoretical apex height. z_a/r_a is where the cut
// meets the nose-side cone; z_b/r_b is where it meets the boss-side
// cone — each found by walking that cone's OWN (already-computed) slope
// back from the apex, not by picking a diameter independently, so the
// land's endpoints are always exactly on the two real cone surfaces.
// The land connecting them is a straight line at whatever angle results
// — a third angle, different from either cone, which is the "trapezoid
// with different angles" this was asked for.
ridge_chamfer_h = 2.0;
z_a = hilt_z0 - ridge_chamfer_h / 2;
z_b = hilt_z0 + ridge_chamfer_h / 2;
r_a = nose_od_male / 2 + hilt_dr  * (z_a - nose_z0 - nose_len) / hilt_h_full;
r_b = flange_od / 2   - taper_dr * (z_b - hilt_z0) / taper_h_full;

// Two corners are left after the main chamfer (nose-cone meets the land,
// land meets the boss-cone) — softened the same way the land itself was
// made: cut back a small distance along each of the two real surfaces
// meeting at that corner, connect the cut points with a straight line.
// Same technique applied twice at a smaller scale, not a new one.
// Working in [r, z] points/vectors (not diameters) makes the cutback
// math (norm(), vector subtraction) read directly instead of needing
// factors of 2 threaded through every line.
corner_chamfer = 0.6;

P0 = [nose_od_male / 2, nose_z0 + nose_len];   // nose top, before the chamfer touches anything
Pa = [r_a, z_a];                               // nose-cone / land corner (uncut)
Pb = [r_b, z_b];                               // land / boss-cone corner (uncut)
P1 = [lens_thread_d / 2, boss_z0];             // where the boss thread begins

dir_nose = Pa - P0;
dir_land = Pb - Pa;
dir_boss = P1 - Pb;

// If corner_chamfer ever grew larger than one of these segments, the two
// cuts on that segment would cross rather than leave a land between
// them — assert rather than let it silently fold the geometry over on
// itself.
assert(corner_chamfer < norm(dir_nose) && corner_chamfer < norm(dir_land)
       && corner_chamfer < norm(dir_boss),
       "corner_chamfer is larger than one of the segments it cuts into");

A_lo = Pa - corner_chamfer * dir_nose / norm(dir_nose);
A_hi = Pa + corner_chamfer * dir_land / norm(dir_land);
B_lo = Pb - corner_chamfer * dir_land / norm(dir_land);
B_hi = Pb + corner_chamfer * dir_boss / norm(dir_boss);

// Entry chamfer on the nose's FREE end (z=0) — the edge that actually
// leads into the focuser every time this goes in or out. An earlier
// version of this file chamfered the wrong edge (nose-top, where it
// meets the hilt, which never enters anything) — caught only by tracing
// which edge is physically the leading one, not by any render.
nose_chamfer = 1.0;

// The hilt only ever needed to present SOME diameter bigger than
// focuser_bore to do its retaining job — nothing about that job requires
// a flat wall, a curve, or a sharp point specifically. STRIPPED BACK
// to a plain two-cone ridge first (a fillet here read as a thin, hollow
// cove against the steep boss-side cone, and a genuinely convex portion
// turned out to be geometrically impossible while staying tangent to
// both the nose and the ridge — verified, not assumed), then given a
// flat chamfer instead of a curve: cheaper to reason about, and it
// doesn't have the fillet's "wrong radius reaches the wrong wall" failure
// mode, since a straight cut has nothing to solve for.
module nose_and_hilt() {
    union() {
        cyl(d = nose_od_male, h = nose_len, anchor = BOTTOM,
            chamfer1 = nose_chamfer);
        // Nose-side cone, now stopping at A_lo (short of the old corner)
        // rather than at Pa directly.
        translate([0, 0, P0.y])
            cylinder(d1 = 2 * P0.x, d2 = 2 * A_lo.x, h = A_lo.y - P0.y);
        // Corner chamfer softening the nose-cone/land junction.
        translate([0, 0, A_lo.y])
            cylinder(d1 = 2 * A_lo.x, d2 = 2 * A_hi.x, h = A_hi.y - A_lo.y);
        // The land itself, now spanning A_hi -> B_lo instead of the
        // uncut corners Pa -> Pb.
        translate([0, 0, A_hi.y])
            cylinder(d1 = 2 * A_hi.x, d2 = 2 * B_lo.x, h = B_lo.y - A_hi.y);
        // Corner chamfer softening the land/boss-cone junction.
        translate([0, 0, B_lo.y])
            cylinder(d1 = 2 * B_lo.x, d2 = 2 * B_hi.x, h = B_hi.y - B_lo.y);
    }
}

module boss_and_taper() {
    // Same construction as the microscope carrier's mounting_boss():
    // thread generated ON the cone (union), then the light bore cut out
    // LAST, because cutting the bore before threading would refill it —
    // exactly the failure ../optics/pcb_carrier.scad documents finding.
    //
    // This cone is the boss-side REMAINDER after both the main ridge
    // chamfer and the small corner chamfer at B — starts at B_hi, not at
    // the ridge's full theoretical diameter — but ends at the same
    // lens_thread_d and boss_z0 either way, since chamfering only ever
    // carves into the two cones, never moves where the thread begins.
    union() {
        translate([0, 0, B_hi.y])
            cylinder(d1 = 2 * B_hi.x, d2 = lens_thread_d, h = boss_z0 - B_hi.y);
        // Sunk 0.6mm into the cone rather than butted at 0.01mm, per the
        // same lesson: tangent contact renders watertight but as two
        // separate bodies.
        translate([0, 0, boss_z0 - 0.6])
            threaded_rod(d = lens_thread_d, l = boss_thread_len_ + 0.6,
                         pitch = lens_thread_pitch, internal = false,
                         bevel2 = true, blunt_start1 = false,
                         anchor = BOTTOM);
    }
}

module nosepiece() {
    difference() {
        union() {
            nose_and_hilt();
            boss_and_taper();
        }
        // Sacrificial lead-in relief at the boss's free tip (z = total_h):
        // this part prints BOSS-DOWN (see the bottom of this file), so
        // the boss tip is the first layer on the bed, and it is exactly
        // the threads that must start the camera's holder cleanly. Same
        // cut as ../optics/pcb_carrier.scad's mounting_boss() — an
        // oversize cylinder minus a cone, so only material OUTSIDE the
        // cone is removed rather than lopping the whole tip off.
        translate([0, 0, total_h - boss_lead_len - 0.01])
            difference() {
                cylinder(d = lens_thread_d + 4, h = boss_lead_len + 0.02);
                cylinder(d1 = lens_thread_d + 0.02,
                         d2 = lens_thread_d - 2 * boss_lead_taper,
                         h = boss_lead_len + 0.02);
            }
        // Light path, taken last for the same reason as the boss thread
        // above — never cut before what surrounds it exists.
        translate([0, 0, -1])
            cylinder(d = boss_bore_d, h = total_h + 2);
    }
}

// Print orientation: NOSE DOWN (as-modelled, no flip) — reversed from an
// earlier boss-down choice, after the boss-down print of this same
// nose_len=32 actually detached from the bed mid-print (boss-down put a
// 32mm-tall column on an 11.88mm boss footprint — a real adhesion/tip-
// over failure, not a theoretical one). Nose-down instead puts the nose
// flat on the bed — 24.15mm diameter, more than double the boss's
// footprint, and the tall section sits low rather than perched on top.
//
// The nose-to-hilt fillet (above) faces upward-and-outward in this
// orientation — a genuine overhang, which is exactly why it kept its
// own gentler curve (tangent-vertical at the nose, widening steadily to
// the ridge) rather than adopting the boss-side cone's steep angle. The
// boss-side cone narrows going up instead, so it never overhangs and
// was free to go steep — the two sides of this ridge answer to different
// print constraints now, not the same one.
//
// This is now based on one success (v1, boss-down, nose_len=8) and one
// failure (v2, boss-down, nose_len=32) — re-examine again if nose_len
// changes further, rather than assuming nose-down is unconditionally
// right either.
module nosepiece_printable() {
    nosepiece();
}

// boss_bore_d has to actually fit inside the thread root, or the boss is
// a thread wrapped around nothing (the microscope build's own
// boss_bore_d note: 9mm through an 11.88mm thread leaves ~0.9mm of wall,
// proven printable — this reuses the same two numbers, so the margin
// carries over unchanged).
assert(boss_bore_d < lens_thread_d - 1,
       "boss_bore_d leaves no wall at the thread root");
// The nose has to be a genuine slip fit UNDER the focuser bore, not just
// under the hilt — flange_od is deliberately larger and would pass this
// check even if nose_od_male were wrong.
assert(nose_od_male < focuser_bore,
       "nose_od_male does not clear the focuser bore");

// Rendered as-modelled by default; nosepiece_printable() is what the
// flake's tele-stl build target actually slices.
nosepiece();
