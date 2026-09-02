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

module nose_and_flange() {
    union() {
        // Nose: plain cylinder. The step up to the flange (24.15 -> 30.65
        // dia) needs no relief of its own: printed boss-down (see the
        // print-orientation note at the bottom of this file), that step
        // is a downward-shrinking transition in print space, not an
        // overhang, so nothing sags there.
        cyl(d = nose_od_male, h = nose_len, anchor = BOTTOM,
            chamfer1 = nose_chamfer);
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
// nose/flange step's underside — a ~4mm-wide flat annulus, and the exact
// face that seats against the focuser's drawtube end — hanging in the
// air as an unsupported 90 deg overhang; sag there is sensor tilt at the
// seating datum, not just cosmetic. Boss-down instead makes the taper
// cone the self-supporting widening surface (identical situation to the
// microscope carrier's own boss-down print, same taper_angle floor), and
// costs nothing in back-focus since it is a rotation, not new material.
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
