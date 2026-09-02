// Shared measured/assumed/chosen parameters for the motorized telescope
// pan/tilt mount (EVA-296), built around the Power Seeker 50AZ's own
// alt-az bracket pair and the Afinia-salvage NEMA 17 steppers.
//
//   EVA-296  the work            https://linear.app/gastrodon/issue/EVA-296
//   EVA-319  telescope measurements  https://linear.app/gastrodon/issue/EVA-319
//   EVA-297  stepper/pulley salvage  https://linear.app/gastrodon/issue/EVA-297
//
// Every .scad part in this directory includes this file instead of
// restating numbers (cad-design rule 3). Nothing here is duplicated into
// check.py either — check.py reads the values back out of OpenSCAD.
//
// Scope boundary: this mechanism carries the telescope. It does NOT touch
// the camera, the nosepiece, or anything in ../optics or the eva-319
// tele/ worktree. The optical train is somebody else's file.
//
// ---------------------------------------------------------------------
// PROVENANCE TAGS -- every constant below carries one:
//   MEASURED  someone put a caliper on the real object; source cited
//   ASSUMED   nobody has measured it yet. MUST be measured before print.
//   STANDARD  a published spec for a standard part (NEMA 17, GT2, 1/4-20)
//   CHOSEN    a free design decision made here
//   DERIVED   computed from the above; never type one of these by hand
// ---------------------------------------------------------------------


// =====================================================================
// 1. DRIVETRAIN -- GT2 belt, not gears
// =====================================================================
// The salvaged steppers already carry 20-tooth GT2 TIMING-BELT PULLEYS,
// not spur gears (EVA-297: confirmed by direct tooth count AND by a
// controlled inked-tooth roll, two independent methods agreeing). A GT2
// pulley cannot mesh with a spur gear, so the 8:1 reduction is realized
// as a belt drive: existing 20T motor pulley -> printed N-tooth pulley.
// Decision made with eva at the keyboard, 2026-09-02.

belt_pitch      = 2.0;    // STANDARD -- GT2 / 2GT, 2mm pitch
belt_pld        = 0.254;  // STANDARD -- pitch line differential.
                          // Cross-check: EVA-297 measured the real 20T at
                          // pitch dia 12.73 and OD ~12.22. (12.73-12.22)/2
                          // = 0.255. The measured part confirms the spec.
belt_width      = 6.0;    // ASSUMED -- printer X/Y belts are 6mm GT2, but
                          // the salvaged loop's width is UNRECORDED.
                          // MEASURE BEFORE PRINT.
belt_loop_len   = 400.0;  // ASSUMED -- eva has only the one CLOSED loop off
                          // the intact Afinia axis; its length was never
                          // recorded (EVA-297 lists the rail+belt as
                          // harvested, no dimension). MEASURE BEFORE PRINT.
                          // Drives axis_centre_dist below, so this is the
                          // single most load-bearing unmeasured number here.

motor_teeth     = 20;     // MEASURED -- EVA-297, direct tooth count
reduction       = 8;      // CHOSEN -- the ratio eva asked for
axis_teeth      = motor_teeth * reduction;   // DERIVED -- this is "N" = 160

// Pitch diameters. Belt engages at the PITCH line, never the outer
// surface -- EVA-297 records a 5% steps/mm error from confusing the two.
function pulley_pd(teeth) = teeth * belt_pitch / PI;   // DERIVED
function pulley_od(teeth) = pulley_pd(teeth) - 2 * belt_pld;  // DERIVED

motor_pd = pulley_pd(motor_teeth);   // DERIVED ~ 12.732 (matches measured)
axis_pd  = pulley_pd(axis_teeth);    // DERIVED ~ 101.859
motor_od = pulley_od(motor_teeth);   // DERIVED ~ 12.224 (matches measured)
axis_od  = pulley_od(axis_teeth);    // DERIVED ~ 101.351

// Centre distance forced by a CLOSED belt loop of length L over two
// pulleys of pitch dia d, D. Standard two-pulley belt-length formula
//     L = 2C + pi*(D+d)/2 + (D-d)^2/(4C)
// solved for C:
//     C = [A + sqrt(A^2 - 2*(D-d)^2)] / 4,   A = L - pi*(D+d)/2
// Real (non-imaginary) only when A >= sqrt(2)*(D-d), i.e. L >= ~306mm for
// this 20T/160T pair. Asserted in belt.scad -- an undef centre distance
// would otherwise propagate silently, exactly the failure mode rule 2
// warns about.
function belt_centre_dist(L, d, D) =
    let (A = L - PI * (D + d) / 2)
    (A * A - 2 * pow(D - d, 2) < 0) ? undef
                                    : (A + sqrt(A * A - 2 * pow(D - d, 2))) / 4;

axis_centre_dist = belt_centre_dist(belt_loop_len, motor_pd, axis_pd); // DERIVED

// Tension travel: the motor mount is slotted so the centre distance can be
// trimmed. Sized to swallow a +/-1 tooth error in the belt-length
// measurement (1 tooth = 2mm of loop = ~1mm of centre distance) plus print
// shrink, with margin. If the measured loop turns out far off, change
// belt_loop_len -- do NOT stretch the slot to cover it.
tension_travel  = 8.0;    // CHOSEN, mm of slot travel

// Pulley body
pulley_flange_h = 1.2;    // CHOSEN -- belt-retaining flange height
pulley_flange_t = 1.0;    // CHOSEN -- flange thickness beyond the OD
pulley_face_w   = belt_width + 1.0;  // DERIVED -- belt width + wander room


// =====================================================================
// 2. GT2 TOOTH PROFILE -- approximate flank, exact pitch
// =====================================================================
// HONESTY NOTE (cad-design rule 7): the PITCH geometry above is exact and
// independently confirmed against the real measured pulley. The tooth
// FLANK shape below is an APPROXIMATION of the Gates 2GT curvilinear
// groove -- a circular-arc-bottomed slot at the published depth and width.
// It is not traceable to a Gates drawing. Ratio, centre distance and
// steps/rev do not depend on it; belt seating and backlash do.
//   => Print gt2_coupon.scad and roll the real belt on it BEFORE
//      committing 4 hours of filament to a 160T wheel.
tooth_depth     = 0.764;  // approximation of the 2GT groove depth
tooth_width     = 1.494;  // approximation of the 2GT groove width


// =====================================================================
// 3. TELESCOPE INTERFACE -- the bracket pair on the tube's underside
// =====================================================================
// Two brackets facing each other on the bottom of the tube, pierced by a
// sideways screw: near bracket a plain clearance hole, far bracket a brass
// threaded insert. The screw axis IS the altitude axis.
//
// MEASURED (EVA-319): the insert is 1/4"-20 UNC (bore 6.31 vs 6.35 major
// spec; 4 threads over 4.9mm ~ 1.225 pitch vs 1.27 spec), and its bore
// centreline sits 9.25mm above the telescope's bottom surface.
//
// EVERYTHING ELSE ABOUT THESE BRACKETS IS UNMEASURED. The five ASSUMED
// values below are the blocking measurement list for this whole build --
// they set the yoke's thickness, the sleeve length, and whether the
// anti-rotation lip on the rotor can grip anything at all.

alt_thread_size    = "1/4-20";  // MEASURED -- EVA-319, confirmed UNC
alt_bolt_major     = 6.35;      // STANDARD -- 1/4" major dia, mm
alt_bore_c_to_bottom = 9.25;    // MEASURED -- EVA-319, bore centreline
                                // above the tube's bottom surface

bracket_gap        = 26.0;  // ASSUMED -- clear span between the two
                            // brackets' facing surfaces. Sets yoke tine
                            // thickness and sleeve length. MEASURE.
bracket_t          = 3.0;   // ASSUMED -- sheet/plate thickness of one
                            // bracket. Sets the anti-rotation lip. MEASURE.
bracket_w          = 20.0;  // ASSUMED -- bracket width across its flat
                            // face, i.e. how much material the rotor's
                            // lip has to hook onto. MEASURE.
bracket_free_r     = 18.0;  // ASSUMED -- radius, about the alt axis, that
                            // is clear of telescope structure on the near
                            // bracket's OUTER face. The rotor hub must fit
                            // inside this or it fouls the tube. MEASURE.
bracket_clear_d    = 6.8;   // ASSUMED -- the near bracket's plain hole
                            // diameter (>= alt_bolt_major). MEASURE.

// Tube geometry behind the pivot -- decides whether the eyepiece end
// collides with the yoke or the base at high altitude angles.
tube_od            = 60.0;  // ASSUMED -- OD of the 50mm-objective tube.
                            // MEASURE.
tube_len_behind    = 320.0; // ASSUMED -- how far the tube extends from the
                            // alt axis toward the eyepiece. MEASURE.
                            // Checked as a swept-clearance case, not a
                            // static one -- see check.py.


// =====================================================================
// 4. STEPPERS -- NEMA 17, three available with 15mm D-shafts
// =====================================================================
// EVA-297: three "belt-axis" steppers carry the 20T pulleys on ~15mm
// D-shafts. The fourth (extruder) has a ~4mm shaft and is explicitly NOT
// a drop-in -- do not design for it.
nema_side       = 42.3;  // STANDARD -- NEMA 17 faceplate
nema_bolt_pitch = 31.0;  // STANDARD -- M3 square bolt circle
nema_pilot_d    = 22.0;  // STANDARD -- raised pilot boss
nema_body_len   = 40.0;  // ASSUMED -- body length is unrecorded in EVA-297
                         // (34/40/48mm are all common). Only affects
                         // how much room the mount leaves behind the
                         // faceplate. MEASURE.
nema_shaft_d    = 5.0;   // ASSUMED -- EVA-297 flags shaft DIAMETER as
                         // explicitly unrecorded; 5mm is the NEMA 17
                         // standard. MEASURE.
nema_screw_d    = 3.4;   // CHOSEN -- M3 clearance
motor_pulley_z  = 8.0;   // ASSUMED -- height of the 20T pulley's belt face
                         // above the motor faceplate. Sets whether the two
                         // pulleys are COPLANAR, which a belt requires
                         // absolutely. MEASURE.


// =====================================================================
// 5. AZIMUTH AXIS + BASE
// =====================================================================
az_post_d       = 16.0;  // CHOSEN -- printed journal post diameter
az_journal_fit  = 0.35;  // CHOSEN -- radial running clearance, per side.
                         // Proven slip-fit allowance elsewhere in this
                         // repo's prints.
az_post_h       = 22.0;  // CHOSEN -- journal engagement length
az_thrust_r     = 34.0;  // CHOSEN -- radius of the flat annular thrust
                         // face the table rides on. Wide, because a
                         // telescope on a stalk is a tipping load.
az_retain_d     = 5.5;   // CHOSEN -- M5 clearance for the retaining screw
                         // up the post's centre (keeps the table captive)

base_plate_t    = 6.0;   // CHOSEN
base_plate_r    = 62.0;  // DERIVED-ish: must exceed az_thrust_r and cover
                         // the motor footprint; asserted in base.scad
tripod_thread   = "1/4-20";  // MEASURED -- EVA-319 / testbench.md: the
                             // tripod interface is 1/4"-20 UNC
tripod_nut_af   = 11.2;  // STANDARD -- 1/4-20 hex nut across-flats
tripod_nut_t    = 5.6;   // STANDARD -- 1/4-20 hex nut thickness

// =====================================================================
// 6. RANGE OF MOTION
// =====================================================================
// eva's spec: 360 deg azimuth, and altitude from horizon (0) to zenith
// (90). 180 deg of altitude would be nice but is NOT required -- so the
// altitude limit below is a real design constraint to verify, not a
// nice-to-have. Hemispherical coverage needs only 0..90.
alt_min_deg     = 0;     // horizon
alt_max_deg     = 90;    // zenith
az_full_turn    = true;  // CHOSEN -- no hard stop. NOTE: unlimited azimuth
                         // means the motor/limit-switch wiring must either
                         // slip-ring or be unwound. Not solved here;
                         // recorded as an open item, not silently ignored.

// =====================================================================
// 7. PRINT / FIT
// =====================================================================
wall            = 2.4;   // CHOSEN -- proven wall in this repo's prints
clearance       = 0.25;  // CHOSEN -- general slip-fit gap
layer_h         = 0.2;

$fa = 2;
$fs = 0.4;


// =====================================================================
// 8. LAYOUT -- all DERIVED. Do not hand-type any number in this section.
// =====================================================================
// Coordinate convention, shared by every part and by check.py:
//   +Z up. Azimuth axis is Z through the origin. The altitude axis is
//   horizontal, parallel to Y, passing through X=0 at height alt_axis_z.
//   Altitude 0 deg = telescope level (pointing +X); 90 deg = zenith.

az_table_t      = 5.0;   // CHOSEN -- rotating table plate thickness
az_table_r      = az_thrust_r + 6;  // DERIVED
az_thrust_h     = 1.0;   // CHOSEN -- how far the thrust annulus stands
                         // proud of the base plate. Owned here because
                         // base.scad raises it and assembly.scad has to
                         // sit the table ON it -- two files, one number.

// Datum chain, ground upward. Getting this wrong buries one part inside
// another while every individual part still renders perfectly.
az_deck_z       = base_plate_t + az_thrust_h;   // DERIVED -- top of thrust

// The alt pulley is a 160T wheel ~102mm across whose centre is the alt
// axis, so it hangs ~51mm BELOW that axis. The yoke tine must lift the alt
// axis high enough that the wheel clears the az table. This is a
// must-clear pair and the reason the yoke is as tall as it is -- it is a
// consequence of the ratio eva chose, not an arbitrary height.
// The azimuth wheel sits at the BOTTOM of the table and the deck plate on
// top of it, not the other way round. Deck-on-bottom puts the yoke's foot
// in the same volume as the wheel and its belt -- both parts render
// perfectly and the rig cannot be assembled.
yoke_base_z     = az_deck_z + gt2_env_h_axis() + az_table_t;  // DERIVED
alt_wheel_r     = gt2_env_r_axis();                 // DERIVED (see below)
alt_axis_clear  = 4.0;                              // CHOSEN, air gap
alt_axis_z      = yoke_base_z + alt_wheel_r + alt_axis_clear;  // DERIVED

// gt2.scad cannot be included here (it includes this file), so the axis
// pulley's envelope radius is restated as a FUNCTION of the same pitch
// constants rather than as a literal -- same source of truth, no copied
// number.
function gt2_env_r_axis() = (pulley_od(axis_teeth) + 2 * pulley_flange_t) / 2;

// Belt planes. A belt drive absolutely requires the two pulleys to be
// coplanar; motor_pulley_z is ASSUMED, so this is the first thing to
// re-derive once that is measured.
// The alt rotor is clamped OUTBOARD of the near bracket, so its wheel's
// mid-plane is offset from the tine's plane by half the bracket span. The
// altitude motor has to be pushed out to the same Y or the belt runs at an
// angle -- which a belt drive does not forgive. This being 0 (i.e. "the
// belt runs in the tine's plane") was a real error caught by rendering the
// assembly orthographically down the altitude axis.
alt_rotor_offset_y = (bracket_gap + 2 * bracket_t) / 2;   // DERIVED
alt_belt_plane_y   = alt_rotor_offset_y;                  // DERIVED
az_belt_plane_z  = az_deck_z + gt2_env_h_axis() / 2;   // DERIVED

// Restated as a function of the same constants gt2.scad uses, because
// gt2.scad includes THIS file and cannot be included back (rule 3).
function gt2_env_h_axis() = pulley_face_w + 2 * pulley_flange_h;

// Motor positions, both at the belt-forced centre distance.
alt_motor_x = axis_centre_dist;   // DERIVED -- alt motor sits out along +X
az_motor_r  = axis_centre_dist;   // DERIVED -- az motor sits out radially

// Where each motor's FACEPLATE has to land so that its pulley -- which
// stands motor_pulley_z proud of that faceplate -- ends up in the belt
// plane. This is the whole coplanarity constraint, written once.
//
// The altitude motor hangs OUTBOARD (+Y), on the same side as the rotor,
// so its body is clear of the telescope's brackets.
alt_motor_face_y = alt_belt_plane_y + motor_pulley_z;   // DERIVED
// The azimuth motor hangs BELOW the base plate, shaft up. A faceplate flat
// against the plate's top face would put its pulley too high, so the plate
// is counterbored to drop it. If motor_pulley_z measures out larger than
// az_belt_plane_z this goes negative and base.scad refuses to render --
// which is the correct outcome, not something to paper over with a fudge.
az_motor_face_z  = az_belt_plane_z - motor_pulley_z;    // DERIVED

// Yoke tine thickness: it runs between the telescope's brackets on the
// shoulder sleeve, so it can be no thicker than the gap minus running
// clearance.
yoke_tine_t = bracket_gap - 2 * clearance;   // DERIVED

// Shoulder sleeve on the altitude axis. Lives here, not in alt_sleeve.scad,
// because yoke.scad's journal bore is a running fit ON this OD -- two files
// needing the same number means it belongs to neither of them (rule 3).
sleeve_shoulder_gap = 0.3;   // CHOSEN -- sleeve stands proud of the tine
sleeve_wall         = 2.0;   // CHOSEN
sleeve_len = yoke_tine_t + sleeve_shoulder_gap;              // DERIVED
sleeve_id  = alt_bolt_major + 2 * clearance;                 // DERIVED
sleeve_od  = sleeve_id + 2 * sleeve_wall;                    // DERIVED

// Yoke-to-table bolt pattern. Shared by yoke.scad (which drills the foot)
// and az_table.scad (which drills the deck) -- if these two ever drift the
// parts simply will not bolt together, and no render would show it. Rule 3.
yoke_blade_w      = 46.0;   // CHOSEN -- blade width in X
yoke_foot_r       = az_table_r * 0.8;          // DERIVED
yoke_foot_bolt_x  = yoke_blade_w * 0.45;       // DERIVED
yoke_foot_bolt_y  = yoke_foot_r * 0.35;        // DERIVED
yoke_local_axis_z = alt_axis_z - yoke_base_z;  // DERIVED -- pivot height in
                                               // the yoke's own local frame.
                                               // Shared by yoke.scad and
                                               // assembly.scad (rule 3).
