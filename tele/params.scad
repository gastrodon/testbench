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
// camera's holder with margin to spare.
boss_thread_len = 7;
boss_lead_len = 1.0;               // sacrificial cone at the boss tip, IF the boss prints bed-side
boss_lead_taper = 1.2;             // radial cut-back at that tip
boss_bore_d = 9;                   // light path through the boss — proven wall at this thread

// Retaining flange: bigger than the focuser bore so the nosepiece cannot
// slide all the way in and vanish down the drawtube. Thin, because
// EVA-319's open question is whether prime focus is reachable at all with
// the diagonal in — every mm of flange is a mm subtracted from the
// drawtube's ~90mm of travel, so this stays as thin as still prints
// cleanly (proven wall thickness elsewhere in this project is >=1.8mm).
flange_od = focuser_bore + 6;
flange_t = 2.0;

// Nose length. FOUND SHORT ON THE FIRST PRINT: 8mm left too little of the
// nose past the focuser's set-screw holes for them to actually bite —
// workable by hand on this print (screws still grip, just barely) but not
// something to repeat on purpose. Bumped generously rather than by a
// small margin: drawtube_travel is ~90mm, so 32mm still leaves plenty of
// focus range, and there was no reason to re-guess a second undersized
// value when the room was available. Still provisional — nobody has
// confirmed the set-screw hole position relative to the focuser opening,
// so this is "clearly enough", not a measured number. Original reasoning
// (screws only need to grip, not carry load — the flange stops axial
// travel) still holds.
nose_len = 32;

// Cone from the nose/flange OD down to the thread OD, same self-support
// angle the microscope build settled on (45 deg is the floor, not the
// target — steeper is a cleaner print when printed thread-up).
taper_angle = 45;

wall = 2.4;                        // generic wall thickness, mm
$fn = 64;
