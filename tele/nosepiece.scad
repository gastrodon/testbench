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

// A small chamfer between nose and flange rather than a bare step: the
// flange is ~3mm wider in radius than the nose, and an unrelieved 90 deg
// step is the same "square lip catches the lead-in" problem the
// microscope's carrier tube chamfer exists to avoid, just going the other
// direction (this is the LEADING end into the focuser, so a snag here is
// felt every time the nosepiece goes in or out).
nose_chamfer = 1.0;

module nose_and_flange() {
    union() {
        // Nose: plain cylinder, chamfered top edge where it steps up to
        // the flange.
        cyl(d = nose_od_male, h = nose_len, anchor = BOTTOM,
            chamfer2 = nose_chamfer);
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
        // Light path, taken last for the same reason as the boss thread
        // above — never cut before what surrounds it exists.
        translate([0, 0, -1])
            cylinder(d = boss_bore_d, h = total_h + 2);
    }
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

// Print orientation: EXACTLY as modelled, nose down. Unlike the
// microscope carrier (which prints boss-down and needs a sacrificial
// lead-in cone on the thread tip), this part's widest feature is the
// flange, one step up from the bed, and the boss sits at the very top,
// threads growing into free air — the same situation the microscope's
// own diameter-calibration coupon printed in, which is why that thread
// came out clean with no lead-in relief. No flip, no lead-in needed.
nosepiece();
