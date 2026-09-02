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
//   -> flange (bigger than the focuser bore, stops it sliding in and vanishing)
//   -> cone (down to the M12 thread OD)
//   -> boss (male M12x0.5, screws into the camera's own holder)
// One light bore runs the full length.

include <params.scad>
include <lib/BOSL2/std.scad>
include <lib/BOSL2/threading.scad>

// --- geometry, all derived so nothing here restates params.scad --------

// Cone from the flange down to the thread. flange_od, not nose_od_male,
// because the flange is the wider of the two — using the wrong one here
// would either overshoot the boss or undersize the flange step, silently.
taper_dr = (flange_od - lens_thread_d) / 2;
taper_h  = taper_dr * tan(taper_angle);

nose_z0    = 0;
flange_z0  = nose_z0 + nose_len;
taper_z0   = flange_z0 + flange_t;
boss_z0    = taper_z0 + taper_h;
total_h    = boss_z0 + boss_thread_len;

// Entry chamfer on the nose's FREE end (z=0) — the edge that actually
// leads into the focuser every time this goes in or out. An earlier
// version of this file chamfered the wrong edge (nose-top, where it
// meets the flange, which never enters anything) — caught only by
// tracing which edge is physically the leading one, not by any render.
nose_chamfer = 1.0;

// Shaft-to-shoulder fillet blending the nose's outer wall into the
// flange's underside, replacing what was a bare 90 deg step. Two
// independent reasons this earned a radius rather than staying sharp:
// a cold-read of the first print's renders flagged the step as a stress
// riser / delamination point with nothing wrong about the observation,
// and a hard step prints less cleanly than a curve regardless of which
// side of it ends up an overhang in a given orientation. Radius is set
// to flange_t (the flange's own depth, the "non-45deg" section as
// opposed to the taper above it) rather than an arbitrary value, so it
// scales with the part instead of needing its own tuning.
nose_flange_fillet_r = flange_t;

module nose_and_flange() {
    // Radial gap the fillet has to cross.
    fillet_gap = flange_od / 2 - nose_od_male / 2;
    assert(nose_flange_fillet_r <= fillet_gap,
           "nose_flange_fillet_r is wider than the nose-to-flange step it fills");

    module nose_flange_fillet() {
        // Quarter circle, tangent to the nose's vertical wall at the
        // bottom and tangent to the flange's horizontal underside at the
        // top — the standard blend, not a semicircle: two tangent points
        // 90 degrees apart on the same circle are always a quarter turn
        // apart, whatever the radius. Built as rotate_extrude() of a
        // polygon (arc + two straight closing edges) rather than a cyl()
        // rounding parameter, because BOSL2's cyl() rounding blends a
        // cylinder's own edge into its own cap — it has no way to blend
        // between two DIFFERENT diameters the way this joint needs.
        n = 16;
        nose_r = nose_od_male / 2;
        r = nose_flange_fillet_r;
        cz = nose_len - r;      // arc center, height
        cr = nose_r + r;        // arc center, radius
        arc_pts = [for (i = [0 : n])
            let (a = 180 - i * (90 / n))
            [cr + r * cos(a), cz + r * sin(a)]
        ];
        // arc_pts runs from (nose_r, cz) [tangent to the nose wall] to
        // (nose_r + r, nose_len) [tangent to the flange underside];
        // closing back through (nose_r, nose_len) — the corner point
        // itself — traces the small wedge the fillet actually fills.
        // polygon() closes the loop back to the first point on its own.
        rotate_extrude($fn = $fn)
            polygon(concat(arc_pts, [[nose_r, nose_len]]));
    }

    union() {
        // Nose: plain cylinder. The step up to the flange (24.15 -> 30.65
        // dia) needs no PRINT relief in the boss-down orientation this
        // part currently prints in (see the orientation note further
        // down) — printed that way, this transition shrinks going up,
        // which never overhangs. The fillet above exists for stress
        // concentration and general print cleanliness, not because this
        // specific orientation would sag without it.
        cyl(d = nose_od_male, h = nose_len, anchor = BOTTOM,
            chamfer1 = nose_chamfer);
        nose_flange_fillet();
        // Flange: sits directly on top of the nose.
        translate([0, 0, flange_z0])
            cyl(d = flange_od, h = flange_t, anchor = BOTTOM);
    }
}

module boss_and_taper() {
    // Same construction as the microscope carrier's mounting_boss():
    // thread generated ON the cone (union), then the light bore cut out
    // LAST, because cutting the bore before threading would refill it —
    // exactly the failure ../optics/pcb_carrier.scad documents finding.
    //
    // The cone runs flange_od -> lens_thread_d, i.e. it tops out at
    // EXACTLY the flange's own diameter — no separate step between cone
    // and flange for either printing or load path.
    union() {
        translate([0, 0, taper_z0])
            cylinder(d1 = flange_od, d2 = lens_thread_d, h = taper_h);
        // Sunk 0.6mm into the cone rather than butted at 0.01mm, per the
        // same lesson: tangent contact renders watertight but as two
        // separate bodies.
        translate([0, 0, boss_z0 - 0.6])
            threaded_rod(d = lens_thread_d, l = boss_thread_len + 0.6,
                         pitch = lens_thread_pitch, internal = false,
                         bevel2 = true, blunt_start1 = false,
                         anchor = BOTTOM);
    }
}

module nosepiece() {
    difference() {
        union() {
            nose_and_flange();
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

// Print orientation: BOSS DOWN, flipped from how it is modelled above.
// The alternative (nose-down, i.e. as-modelled with no flip) puts the
// nose/flange step's underside — a ~3.25mm-wide flat annulus, and the
// exact face that seats against the focuser's drawtube end — hanging in
// the air as an unsupported 90 deg overhang; sag there is sensor tilt at
// the seating datum, not just cosmetic. Boss-down instead makes the taper
// cone the self-supporting widening surface (identical situation to the
// microscope carrier's own boss-down print, same taper_angle floor), and
// costs nothing in back-focus since it is a rotation, not new material.
//
// RE-EXAMINE THIS at the current nose_len (32mm, up from the 8mm this
// call was originally made against). Boss-down now spends most of the
// part's height as a slender nose_len-tall column standing ON TOP of a
// comparatively short, narrow base (boss+cone, ~16mm) instead of resting
// on the bed — the opposite of a stable print, and worse the longer
// nose_len gets. Nose-down would put that same 32mm down as a wide,
// direct-to-bed cylinder instead, trading a small (~3.25mm radial, 2mm
// tall) overhang for a much shorter, wider, more stable base. Whichever
// orientation actually gets used, verify it against nose_len at print
// time rather than trusting this comment's math — it was written for a
// specific length that has already changed once.
module nosepiece_printable() {
    translate([0, 0, total_h])
        rotate([180, 0, 0])
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
// under the flange — flange_od is deliberately larger and would pass this
// check even if nose_od_male were wrong.
assert(nose_od_male < focuser_bore,
       "nose_od_male does not clear the focuser bore");

// Rendered as-modelled by default; nosepiece_printable() is what the
// flake's tele-stl build target actually slices.
nosepiece();
