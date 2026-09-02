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
// spec; 4 threads over 4.9mm ~ 1.225 pitch vs 1.27 spec).
//
// Most of this block is now MEASURED off the real scope (eva, 2026-09-02):
// bracket_gap, bracket_t, bracket_clear_d and the axle height. What is
// still ASSUMED here is bracket_w and bracket_free_r -- the bracket's
// face width and how much room the rotor hub has before it fouls tube
// structure -- plus everything about the tube itself.
//
// THE MEASUREMENTS BROKE AN ASSUMPTION. bracket_clear_d came back at 6.25,
// which is UNDER a 1/4-20's 6.35 major diameter, so a 1/4-20 shank does
// not pass through the plain hole. Both the current design and the
// integral-axle proposal route the fastener that way. Asserted below.

alt_thread_size    = "1/4-20";  // MEASURED -- EVA-319, confirmed UNC
alt_bolt_major     = 6.35;      // STANDARD -- 1/4" major dia, mm
alt_bore_c_to_bottom = 10.25;   // MEASURED (eva, 2026-09-02) -- axle
                                // centreline above the mount's base plate.
                                // Supersedes EVA-319's 9.25; re-measured
                                // directly off the scope.

bracket_gap        = 16.5;  // MEASURED (eva, 2026-09-02) -- clear span
                            // between the brackets' facing surfaces.
                            // Much narrower than the 26 assumed, so the
                            // tine gets correspondingly thinner.
bracket_t          = 4.9;   // MEASURED (eva, 2026-09-02) -- one bracket
bracket_w          = 20.0;  // ASSUMED -- bracket width across its flat
                            // face, i.e. how much material the rotor's
                            // lip has to hook onto. MEASURE.
bracket_free_r     = 18.0;  // ASSUMED -- radius, about the alt axis, that
                            // is clear of telescope structure on the near
                            // bracket's OUTER face. The rotor hub must fit
                            // inside this or it fouls the tube. MEASURE.
bracket_clear_d    = 6.25;  // MEASURED (eva, 2026-09-02) -- the plain
                            // hole. NOTE this is SMALLER than a 1/4-20's
                            // 6.35mm major diameter, which is a physical
                            // conflict, not a rounding detail: a 1/4-20
                            // shank does not pass through a 6.25 hole.
                            // Asserted on below rather than absorbed
                            // silently -- it decides whether either the
                            // current design OR the integral-axle idea can
                            // be assembled at all.

// Tube geometry behind the pivot -- decides whether the eyepiece end
// collides with the yoke or the base at high altitude angles.
tube_od            = 60.0;  // ASSUMED -- OD of the 50mm-objective tube.
                            // MEASURE.

// How far the tube's nearest SURFACE stands off the pivot axis. Split out
// from alt_bore_c_to_bottom deliberately: that one is measured against the
// mount lug's bottom face, and the brackets hang below the tube, so the
// two are not the same number. Bundling them assumes the tube is flush
// with the bracket bottom, which is the worst case, not the likely one.
//
// This is the tightest budget in the whole design. The tube swings around
// the pivot, so its surface sweeps a cylinder of exactly this radius about
// the altitude axis -- and EVERY piece of the yoke inside the tube's width
// has to fit within it, at every altitude angle. It sets the pivot boss
// diameter and caps how tall the motor arm may be.
tube_bottom_above_pivot = 10.25; // ASSUMED (worst case), tracking the
                                 // re-measured alt_bore_c_to_bottom. Still
                                 // a different quantity from that one --
                                 // this is the TUBE's surface standoff,
                                 // that one is the axle above the base
                                 // plate, and they coincide only if the
                                 // tube sits flush with the bracket
                                 // bottom. MEASURE.
tube_len_behind    = 320.0; // ASSUMED -- how far the tube extends from the
                            // alt axis toward the eyepiece.
                            //
                            // Order of magnitude confirmed by eye against
                            // the real scope (eva, 2026-09-02). That is
                            // NOT a measurement and this stays ASSUMED --
                            // but it does mean the ~52 deg altitude
                            // ceiling this drives is a REAL limit rather
                            // than an artefact of a bad guess, which is
                            // the question the confirmation settles.
                            // Still worth a caliper before the ceiling is
                            // engineered around.
                            //
                            // Checked as a swept-clearance case, not a
                            // static one -- see check.py.


// The plain hole must actually pass the fastener that goes through it.
// This is a hard physical conflict, not a tolerance to absorb: 6.25 < 6.35
// means the bolt does not fit, full stop. Fails the build loudly rather
// than producing STLs for a mechanism that cannot be assembled.
// =====================================================================
// 3b. INTEGRAL STEPPED AXLE  (eva's design, 2026-09-02)
// =====================================================================
// The wheel and its shaft are ONE part, inserted from the THREADED side,
// and the diameter only ever decreases from the wheel toward the tip.
// That monotonic taper is what makes it assemblable: every section
// inboard of the thread has to pass through the brass insert's bore
// before the thread engages.
//
//   [160T wheel]==[1/4-20 thread]==[journal]==[M4 tip]-> lock nut
//                       |              |          |
//              threaded bracket   yoke tine   plain 6.25 hole
//
// Why this beats the separate-bolt version it replaces:
//   - torque goes through a THREAD, not through bolt-clamp friction plus
//     printed jaws hooking a bracket edge. That was the sketchiest load
//     path in the build and it is now gone, jaws and all.
//   - the shoulder between journal and tip does alt_sleeve's job, so that
//     part disappears entirely.
//   - it sidesteps the 6.25mm blocker: nothing 6.35mm wide ever has to
//     pass through the plain hole. Only the 4mm tip goes there.
//
// Torque never reaches the thin sections: the thread sits immediately
// inboard of the wheel, so drive torque transfers to the telescope right
// there. Journal and tip carry bending only, and very little of it.

insert_id       = 5.2;   // MEASURED -- EVA-319, the brass insert's
                         // threaded-side ID. THE binding constraint: every
                         // section inboard of the thread must clear this.
axle_journal_d  = insert_id - 0.4;                      // DERIVED -- 4.8
axle_tip_thread = 4.0;   // CHOSEN -- M4. Comfortably under the journal so
                         // the taper stays monotonic, and small enough to
                         // pass the insert with room to spare.

// Journal length is the bracket gap exactly. The step down to the tip
// bears on the far bracket's inner face, so the clamp path runs
// thread -> axle -> step -> far bracket and NEVER through the tine. Same
// shoulder trick alt_sleeve used, now integral: without it, tightening
// the lock nut squeezes the tine and the altitude axis seizes -- a
// mechanism that moves as one rigid lump and passes every geometric test.
axle_journal_len = bracket_gap;                          // DERIVED
axle_thread_len  = bracket_t + 1.5;                      // DERIVED
axle_tip_len     = bracket_t + 4.0;   // through the far bracket, with
                                      // enough protruding for the nut

// The lock nut is not decoration. Drive torque reacts across the 1/4-20
// thread and the altitude axis reverses constantly, so half the reversals
// tend to unscrew it and it walks loose over time. eva's "overshoot the
// far hole" is what makes the fix possible -- the tip protrudes and gets
// captured.
axle_lock_nut   = true;  // CHOSEN

// Scoped to the parts that actually route the fastener, NOT file scope --
// a file-scope assert also killed gt2_coupon, which has no opinion about
// brackets and is the very thing we want printed early. An assert that
// blocks unrelated work gets commented out, and then it protects nothing.
// The stepped axle RESOLVED the 6.25 conflict rather than working around
// it: entering from the threaded side means only the M4 tip visits the
// plain hole. So the old "does a 1/4-20 fit through 6.25" assert is gone,
// replaced by the checks that now actually bind.
module assert_fastener_fits() {
    assert(axle_journal_d < insert_id,
           str("axle journal ", axle_journal_d, "mm will not pass through ",
               "the insert's ", insert_id, "mm bore during assembly -- the ",
               "axle cannot be inserted at all"));
    assert(axle_tip_thread < axle_journal_d,
           "axle taper is not monotonic: the tip is fatter than the \
journal, so it cannot pass the insert ahead of it");
    assert(axle_tip_thread < bracket_clear_d,
           str("the M4 tip does not fit the plain hole (", bracket_clear_d,
               "mm)"));
    assert(axle_journal_len > yoke_tine_t,
           "axle journal is shorter than the tine is thick -- the lock nut \
would clamp the tine and seize the altitude axis");
}

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
// The post runs up THROUGH the table and on into the yoke's foot, so it
// journals both. The yoke is bolted to the table and turns with it, so
// they share one long bearing rather than the table having a short one and
// the yoke none. Engagement is post_h rather than just the table's own
// thickness -- a 16mm post journalled over only 14mm is an L/D under 1,
// which on a telescope-on-a-stalk tipping load is not enough.
az_post_h       = 28.0;  // CHOSEN -- journal length above the thrust deck
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
// Where the alt rotor's WHEEL CENTRE sits along the altitude axis.
//
// Walk the stack outward from the tine's mid-plane rather than guessing:
//   bracket_gap/2   to the near bracket's inner face
//   + bracket_t     through the bracket to its OUTER face -- where the
//                   rotor hub clamps
//   + rotor_hub_h   through the hub
//   + env_h/2       to the middle of the wheel itself
//
// A first version used just (bracket_gap + 2*bracket_t)/2 = 16, which puts
// the wheel where the BRACKET is: measured overlap 13,936 mm3 against the
// yoke, and the hub buried inside the tine boss. Every part still rendered
// perfectly on its own.
// Hub LENGTH is derived, not chosen. The wheel is 103mm across on a pivot
// that sits only 9.25mm below the tube's bottom, so a wheel anywhere
// inboard of the tube's own radius cuts straight through the telescope --
// measured at 11,061 mm3 of interpenetration with a 6mm hub. The hub has
// to stand the wheel off past the tube surface.
//
// Consequence worth stating rather than hiding: this is a long cantilever
// carrying a big wheel, and it is the least rigid thing in the assembly.
// It gets shorter if bracket_gap measures wider than assumed.
rotor_tube_margin  = 3.0;   // CHOSEN -- air between wheel face and tube

// The hub is subject to the SAME swept-clearance budget as the yoke's
// pivot boss, just measured further out along the axis. At a distance y
// from the tube's mid-plane the tube's underside sits
//     (tube_bottom_above_pivot + R) - sqrt(R^2 - y^2)
// above the pivot axis, and the hub is a cylinder about that axis, so it
// may be no fatter than that. The binding y is the bracket's outer face,
// where the hub starts -- it gets more room further out, but a straight
// hub only gets one diameter.
//
// A chosen 34mm hub put 74.5 mm3 of itself inside the tube. The measured
// overlap sat exactly between this radius and 17, which is how the
// formula below got confirmed rather than just asserted.
rotor_hub_y0       = bracket_gap / 2 + bracket_t;             // DERIVED
rotor_hub_clear_r  = tube_bottom_above_pivot + tube_od / 2
                     - sqrt(max(0, pow(tube_od / 2, 2)
                                   - pow(rotor_hub_y0, 2)));  // DERIVED
rotor_hub_d        = 2 * (min(bracket_free_r, rotor_hub_clear_r) - 1);
// Note there is NO env_h/2 term here. The hub has to stand the wheel's
// INBOARD FACE clear of the tube, not its centre plane; subtracting half
// the wheel's own width put the face 1.7mm back inside the tube while the
// formula's comment claimed otherwise.
rotor_hub_h        = max(6.0,
                         tube_od / 2 + rotor_tube_margin
                         - bracket_gap / 2 - bracket_t);   // DERIVED
alt_rotor_offset_y = bracket_gap / 2 + bracket_t + rotor_hub_h
                     + gt2_env_h_axis() / 2;              // DERIVED
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
// The altitude motor bolts to the OUTBOARD face of the yoke's motor plate
// and its pulley reaches back INBOARD through the plate's pilot bore. So
// the plate's inboard face is one plate thickness further in than the
// faceplate:
//     pulley plane = faceplate - motor_pulley_z
//     faceplate    = plate inboard face + plate thickness
alt_motor_plate_t = 5.0;   // CHOSEN -- shared by yoke.scad and the datum
// The motor's faceplate bolts to the plate's OUTBOARD face, so the plate's
// inboard face -- which is where yoke.scad draws it from -- is one plate
// thickness further in.
alt_motor_face_y  = alt_belt_plane_y + motor_pulley_z
                    - alt_motor_plate_t;                  // DERIVED
alt_motor_seat_y  = alt_motor_face_y + alt_motor_plate_t; // DERIVED

// The arm from the tine out to that plate has to cross the wheel's plane.
// Crossing it anywhere inside the wheel's radius runs the arm straight
// through the wheel -- measured at 1,294 mm3. So the arm dog-legs: it runs
// outboard at the motor's Y until it is clear of the wheel, and only then
// turns in toward the tine.
yoke_arm_d        = 26.0;   // CHOSEN -- arm cross-section
yoke_knee_x       = gt2_env_r_axis() + yoke_arm_d / 2 + 3;   // DERIVED

// Ceiling for anything on the yoke that lies within the tube's width. The
// tube's underside sweeps past at tube_bottom_above_pivot; everything the
// yoke puts in that band has to duck under it.
yoke_clear_z      = tube_bottom_above_pivot - 1.25;          // DERIVED
// The pivot boss lives inside that same swept radius, so its diameter is
// derived from it rather than chosen. This leaves a thin wall over the
// sleeve bore -- flagged in README, and it grows the moment
// tube_bottom_above_pivot is actually measured.
yoke_boss_d       = 2 * (tube_bottom_above_pivot - 1);       // DERIVED

// The pulley's own envelope reaches (motor_pulley_z - env_h/2) back from
// the faceplate. If the plate is thicker than that, the pulley's inner
// flange lands on the plate and the motor cannot seat. Relieved with a
// counterbore rather than by thinning the plate.
motor_pulley_reach = motor_pulley_z - gt2_env_h_motor() / 2;   // DERIVED
function gt2_env_h_motor() = pulley_face_w + 2 * pulley_flange_h;
function gt2_env_d_motor() = pulley_od(motor_teeth) + 2 * pulley_flange_t;
// The azimuth motor stands ON TOP of the base plate, body upward, seated
// in a shallow pocket that drops its faceplate to the height which puts
// its pulley in the belt plane. Body-up rather than body-down: hanging a
// 40mm NEMA 17 below the plate would need the whole base standing 40mm off
// the tripod head on legs. It clears the rotating table because it sits
// out at the belt centre distance, far outside the table's rim.
//
// If motor_pulley_z measures out larger than az_belt_plane_z this goes
// negative and base.scad refuses to render -- the correct outcome, not
// something to paper over.
az_motor_face_z  = az_belt_plane_z - motor_pulley_z;    // DERIVED
az_motor_pocket  = base_plate_t - az_motor_face_z;      // DERIVED

// Yoke tine thickness: it runs between the telescope's brackets on the
// shoulder sleeve, so it can be no thicker than the gap minus running
// clearance.
yoke_tine_t = bracket_gap - 2 * clearance;   // DERIVED

// The separate shoulder sleeve is GONE -- alt_rotor's integral axle does
// its job now (see section 3b). What it protected against still applies:
// the journal must be longer than the tine is thick, or the lock nut
// clamps the tine and seizes the axis. That is asserted in
// assert_fastener_fits().

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
