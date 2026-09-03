// Shared measured/assumed/chosen parameters for the prime-focus telescope
// camera build. Every .scad part in this directory includes this file
// instead of restating numbers.
// https://linear.app/gastrodon/issue/EVA-319/prime-focus-telescope-camera-build
//
// Sibling of EVA-316 (prime-focus microscope, ../optics/). Same NexiGo N60
// bare-sensor principle, same M12x0.5 holder thread — but EVA-316's own
// params.scad/pcb_carrier.scad exist only as UNCOMMITTED staged changes on
// a different branch (eva/eva-316-...), not on any commit this worktree
// (branched from origin/main) can include or build against. So the camera
// constants below are copied, not shared, across the two builds — that is
// acceptable duplication of a measured physical fact about common
// hardware, not the drifting-derivation kind rule 3 warns about. When
// eva-316 lands, factoring both builds' camera constants into one shared
// file is a reasonable follow-up; not done here.

// measured — camera (NexiGo N60), copied from the microscope design doc
// https://linear.app/gastrodon/document/microscope-camera-design-doc-15a95f836b98
holder_h = 10;                     // M12 holder tube height, mm
// SETTLED BY PRINT on the microscope build: a coupon carrying both 11.88
// and 11.68 went into the camera's own holder — 11.88 threads in
// perfectly, 11.68 is loose enough to slip. Print at NOMINAL, no
// undersize compensation. Caveat: that coupon printed flange-down with
// the thread growing into free air, so its lead-in was clean; whichever
// end of THIS part's boss lands on the bed still needs its own lead-in
// relief (see nosepiece.scad).
lens_thread_d = 11.88;             // M12 S-mount holder OD, mm — confirmed
lens_thread_pitch = 0.5;
sensor_w = [5.37, 3.02];           // 1/2.7" sensor active area, mm

// measured — telescope (Power Seeker 50AZ), from EVA-319
scope_d = 50;                      // objective diameter, mm
scope_f = 600;                     // focal length, mm (f/12, printed on tube)
nose_od_male = 24.15;              // 0.965" eyepiece nose OD — what slides into the focuser
focuser_bore = 24.65;              // focuser's own bore — 0.5mm clearance over nose_od_male
drawtube_travel = 90;              // mm, approximate

// chosen — nosepiece geometry
// Same boss as the microscope carrier: male M12x0.5, generated ON a cone
// rather than cut into it (threaded_rod() internal=false, unioned in
// before the through-bore is cut — cutting first and threading second
// would refill the bore the way base_mount's objective bore once did).
// 7mm is 14 turns at 0.5 pitch, proven on the microscope build to seat the
// camera's holder with margin to spare. This is a BASE length now, not
// the final one — nosepiece.scad extends it by whatever height the
// boss-side cone's steeper angle frees up, so the overall body length
// stays put regardless of that angle.
boss_thread_len = 7;
boss_lead_len = 1.0;               // sacrificial cone at the boss tip, IF the boss prints bed-side
boss_lead_taper = 1.2;             // radial cut-back at that tip
boss_bore_d = 9;                   // light path through the boss — proven wall at this thread

// Angle of the cone from the hilt ridge down to the M12 thread, measured
// FROM THE BED (0 = flat/horizontal, 90 = vertical), same convention the
// microscope build's carrier_taper_angle uses. This cone NARROWS going
// up in the current nose-down print orientation, so it never overhangs
// regardless of angle (a shrinking-upward transition is self-supporting
// at any angle — the 45 deg self-support floor that constrains the
// OTHER, widening cone at the hilt simply does not apply here).
// Steepening this one just trades cone height for thread length, 1:1
// (see nosepiece.scad's boss_thread_len_), with no print-quality cost.
// Much steeper than that 45 deg floor: tan(15) is a quarter of tan(45),
// so this cone claims a quarter of the axial space it used to for the
// same diameter change.
boss_taper_angle = 15;

// Retaining diameter (the "hilt ridge" in nosepiece.scad): bigger than
// the focuser bore so the nosepiece cannot slide all the way in and
// vanish down the drawtube. No separate thickness parameter any more —
// the ridge is where two cones meet, chamfered, not a flat-walled
// flange with its own height.
flange_od = focuser_bore + 6;

// Nose length. FOUND SHORT ON THE FIRST PRINT: 8mm left too little of the
// nose past the focuser's set-screw holes for them to actually bite —
// workable by hand on this print (screws still grip, just barely) but not
// something to repeat on purpose. Went to 32mm as a first generous
// correction, then settled to 20mm — still comfortable set-screw
// engagement, without the extra length that made the boss-down v2 print
// top-heavy enough to detach from the bed (see nosepiece.scad's print-
// orientation notes). drawtube_travel is ~90mm, so 20mm still leaves
// plenty of focus range. Original reasoning (screws only need to grip,
// not carry load — the flange stops axial travel) still holds.
nose_len = 20;

wall = 2.4;                        // generic wall thickness, mm
$fn = 64;
