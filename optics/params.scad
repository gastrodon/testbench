// Shared measured/assumed/chosen parameters for the prime-focus microscope
// build. See the design doc for the full derivation:
// https://linear.app/gastrodon/document/microscope-camera-design-doc-15a95f836b98
// Every .scad part in this directory includes this file instead of
// restating numbers.

// measured — camera (NexiGo N60)
pcb = [19, 55, 1.6];               // board footprint, mm
holder_h = 10;                     // M12 holder tube height, mm
holder_screw_d = 2;                // holder-to-PCB screw diameter, mm
holder_screw_span = 20;            // spacing between the 2 screws, mm, straddling board center
lens_thread_d = 11.88;             // M12 S-mount holder OD, mm
lens_thread_pitch = 0.5;
ring_light_r_max = 12;             // hard clearance cap near the objective base, mm

// measured — microscope (B24014N, 150x cell)
obj_thread_d = 9;                  // objective cell thread OD, mm
obj_thread_engage = 3.25;          // thread engagement depth, mm
obj_aperture = 3.4;                // front aperture, mm

// assumed — objective thread pitch is an open question in the design doc
// (crest-count-over-3.25mm still needs doing). 0.75mm is a plausible
// small-plastic-thread guess, NOT a measurement. Confirm by test fit
// before trusting this for anything but a first print.
obj_thread_pitch = 0.75;

// Depth of the threaded section: measured engagement plus lead-in. Lives
// here rather than in the base part because fit_coupon.scad needs the
// identical value — a coupon that tests a different depth tests nothing.
obj_bore_depth = obj_thread_engage + 2;

// chosen — rack-and-pinion focus mechanism (BOSL2 gears.scad)
// pressure_angle must match between rack() and spur_gear() or they won't mesh.
//
// Finer focus control = less carrier travel per knob revolution
// (travel/rev = PI * mod * teeth), so a SMALLER pinion is finer. mod 0.75
// x 12T gives 28.3mm/rev vs mod 1's 37.7 — about 33% finer — while
// keeping ~1.7mm teeth, comfortably printable on a 0.4mm nozzle. mod 0.5
// would be finer still but its ~1.1mm teeth are only 2-3 extrusion widths
// per flank, where print quality and backlash get unpredictable.
//
// If this still isn't fine enough by hand, the next moves in order of
// cost are: a bigger knob (below), then a reduction gear stage, then a
// stepper. Do NOT chase it by shrinking the module further.
gear_mod = 0.75;
gear_pressure_angle = 20;
gear_thickness = 8;        // rack/pinion face width, mm
pinion_teeth = 12;
guide_rod_d = 4;           // smooth guide rod diameter the PCB carrier rides on, mm
shaft_d_frame = 4;         // pinion axle: stock 4mm rod, carried in double shear

// Knob diameter multiplies tactile fineness for free: the same angular
// resolution at your fingertip covers proportionally less rotation on a
// bigger knob. Cheapest available precision — no gearing change.
knob_d = 28;

// LEGO Technic interface (cfinke/Technic.scad) — provisional frame
// attachment at the objective end, per Technic.scad's own constants
technic_pin_spacing = 8;   // = technic_beam_hole_spacing in Technic.scad

// assumed — resolve empirically (see design doc "next steps")
obj_f = 9;                         // focal length, mm; plausible range 8-14

// chosen
tube_len_nominal = 80;             // mm, starting point pending empirical focus test
focus_travel = 20;                 // mm of adjustment range to build in

// --- shared interface dimensions --------------------------------------
// The carrier owns the rack and the frame owns the pinion bearings, so
// these live here rather than in either part. Duplicating them into both
// files is exactly how the checker drifted out of sync with the CAD once
// already. Anything both a moving part and its frame must agree on
// belongs in this block.
// ARCHITECTURE: two bodies.
//   BASE   fixed. sleeve + 150x objective cell in its floor + pinion yoke.
//   MOVING PCB face + the tube that slides in the sleeve bore + the rack.
// The tube-in-sleeve fit IS the linear bearing — an 18mm tube in an
// 18.6mm bore over 56mm of engagement constrains far more than two 4mm
// rods did, so there are no guide rods and no bushings. Focus changes the
// sensor-to-objective distance because the sensor end moves and the
// objective does not.
carrier_tube_od = 18;              // = base sleeve bore mate
carrier_tube_len = 80;
carrier_face_w = 34;               // PCB mounting bar, X (spans the screws)
carrier_face_d = 21;               // Y — wide enough to carry the tube
carrier_face_t = 2.6;

// Rack must clear the BASE SLEEVE's outside, since it rides alongside it.
// Sleeve OD is 23.4 (r=11.7) and BOSL2's rack backing sits
// 2*dedendum+addendum behind the pitch line, so the pitch line has to be
// pushed out past -(11.7 + backing + clearance).
rack_backing = 2 * 1.25 * gear_mod + gear_mod;
rack_y = -(carrier_tube_od / 2 + 2.4 + rack_backing + 1.6);
rack_engage_margin = 5;            // rack beyond each end of travel, mm
carrier_z_home = tube_len_nominal + holder_h;
pinion_z = carrier_z_home - rack_engage_margin;  // grounded; never travels
// pinion_y = rack_y - gear_dist(...) — computed where BOSL2 is available,
// since params.scad is included before the library.

// The pinion axle is stock 4mm rod, not a printed part. It must reach
// through both yoke bearings and out past the knob:
//   -10  clear of the -X bearing
//     0  the gear
//  +8.5  through the +X bearing
//   +32  far face of the knob (22 standoff + 10 knob)
axle_len = 44;

// print fit
wall = 2.4;                        // generic wall thickness, mm
clearance = 0.3;                   // generic slip-fit clearance, mm per side
$fn = 64;
