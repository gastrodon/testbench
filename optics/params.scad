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
// SETTLED BY PRINT. A coupon carrying both 11.88 and 11.68 went into the
// camera's own holder: 11.88 threads in perfectly, 11.68 is loose enough
// to slip. So print this thread at NOMINAL — no undersize compensation.
//
// That is worth knowing beyond this part. The received wisdom is that an
// external printed thread comes out oversize by roughly an extrusion
// width and needs shaving; on this printer, at this pitch, it does not.
// Do not pre-shrink the next printed male thread by default.
//
// Caveat carried from the coupon's orientation: it printed flange-down
// with the thread growing up into free air, so its lead-in was clean. The
// carrier's boss will print tip-first ON the bed (see pcb_carrier.scad),
// where the entering threads are the ones carrying elephant foot. The
// DIAMETER answer transfers; the lead-in still needs relieving.
lens_thread_d = 11.88;             // M12 S-mount holder OD, mm — confirmed
lens_thread_pitch = 0.5;
ring_light_r_max = 12;             // hard clearance cap near the objective base, mm

// measured — microscope (B24014N, 150x cell)
obj_thread_d = 9;                  // objective cell thread OD, mm
obj_thread_engage = 3.25;          // thread engagement depth, mm
obj_aperture = 3.4;                // front aperture, mm

// MEASURED BY TEST PRINT, which overruled a caliper reading.
//
// Calipers on the valley diameter said 0.75. A coupon printing 0.5 /
// 0.75 / 1.0 side by side settled it: the cell threads cleanly into the
// 0.5 block and not the 0.75 one. The caliper method was off by exactly
// one standard size — at this scale, reading a thread's root diameter by
// hand is not accurate enough to pick between adjacent standards.
//
// The same trap appeared on the camera's own M12 mount: measuring a
// single crest suggested 0.25mm, while counting 18 crests over 9mm gives
// 0.5 — and 0.5 is what it actually is. COUNT OVER A LENGTH; never
// measure one peak.
//
// Keeping the 0.5 and 1.0 blocks as controls is what made this
// recoverable. Printing only the "measured" value would have produced a
// 7.5-hour, 21g base_mount that the objective simply would not enter,
// and the failure would not have surfaced until final assembly.
obj_thread_pitch = 0.5;

// Depth of the threaded section: measured engagement plus lead-in. Lives
// here rather than in the base part so any coupon testing this thread
// gets the identical value — a coupon at a different depth tests nothing.
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

// --- pinion tooth taper ------------------------------------------------
//
// The gear used to be a square-edged extrusion sitting on a separate 45
// deg cone. Printed knob-down that cone was the only thing holding up a
// 2.5mm radial ledge, and it was a distinct feature bolted under the
// teeth rather than part of them.
//
// Instead each tooth TIP now slopes down to meet the shaft, so the
// support is the tooth. pinion_tip_slope is measured FROM THE BED: the
// cone widens as it rises, so its underside is the overhang, and
//
//     taper height = (tip radius - shaft radius) * tan(slope)
//
// A LARGER angle is a taller, steeper-walled taper and an easier print;
// 45 deg is the usual self-support limit and is the floor here, not the
// target. Taller also costs axial room, which is the trade: the whole
// gear station has to live between the yoke arms.
//
// pinion_full_w is the full-depth band that actually drives the rack. It
// is deliberately NOT gear_thickness — that value sets the rack, the yoke
// slot and the clip coupon, and shrinking it there would silently resize
// three other parts. Trimmed to 7 so the taper fits with margin.
pinion_full_w = 7.0;
pinion_tip_slope = 50;

// --- knob blending -----------------------------------------------------
//
// Where the shaft meets the knob face, a cove rather than a square step.
// The profile is a power curve, not a radius: height above the knob face
// goes as ((knob_r - r)/(knob_r - shaft_r))^knob_cove_pow, so it hugs the
// face across most of the knob and sweeps up only close to the axis —
// the curvature is concentrated at the centre. Raise the power to pull it
// tighter in, lower it toward 1 for a plain cone.
//
// Height is bounded by the carrier: the knob face already sits only 5mm
// clear of the carrier's 34mm-wide bar, and the cove grows back toward it.
// check.py's pinion-vs-carrier pair is what actually holds this honest.
knob_cove_h = 4.0;
knob_cove_pow = 2.2;

// Break the knob's outer edges. Bottom chamfer also gives the first layer
// a smaller footprint that grows, which is the usual dodge for elephant
// foot on a wide disc.
knob_chamfer = 1.0;

// Half-width of the slot between the yoke arms — the axial room the whole
// gear station has to live in.
//
// LIVES HERE BECAUSE THREE FILES NEED IT. It was written out longhand in
// objective_focus_mount.scad (as rack_slot_half), focus_pinion.scad (as
// yoke_slot_half, where it backs the assert that the tooth taper clears
// the arm) and clip_coupon.scad (as rack_slot_half_pub). Three copies of
// one formula under three names: change the mount and the pinion's assert
// would go on checking a number nothing used, which is the exact drift
// this project has already been bitten by twice.
//
// The +3 is no longer what the old comment claimed. It used to be room
// for a separate 45-degree cone under the gear, sized (10.5-6)/2 = 2.25.
// That cone is gone; the teeth taper into the shaft themselves, and the
// station now needs pinion_full_w/2 + taper_h = 6.448mm each side against
// the 6.7mm this allows. focus_pinion.scad asserts that, so the margin is
// checked rather than remembered.
rack_slot_half = gear_thickness / 2 + 3;
guide_rod_d = 4;           // smooth guide rod diameter the PCB carrier rides on, mm
// The pinion shaft is PRINTED as part of the pinion, not stock rod. It
// was 4mm only because that is a stock size; nothing requires it now, so
// it is 6mm — torsional section goes as d^3, making a printed shaft 3.4x
// stronger for free. That matters because printed axis-vertical, torque
// is carried by layer adhesion, which is the weak direction.
shaft_d_frame = 6;

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

// No axle_len: the shaft is integral to the pinion now. Gear, shaft and
// knob all rotate together, so they were always one rigid body — the
// separate rod only existed because closed bearing bores could not be
// threaded past a 10.5mm gear. The snap-fit bearings open upward, so the
// whole assembly drops in from above and the rod is unnecessary.

// print fit
wall = 2.4;                        // generic wall thickness, mm
clearance = 0.3;                   // generic slip-fit clearance, mm per side
$fn = 64;
