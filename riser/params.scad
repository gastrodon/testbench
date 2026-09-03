// Shared parameters for the MANUAL two-axis tripod riser (the "riser").
//
// What this is: an adapter that goes between an ordinary upward-facing
// 1/4"-20 tripod stud and the motorized mount in ../mount. It raises the
// mount, and it adds a second, coarse, HAND-DRIVEN gimbal underneath it:
// two axes, each turned by a knob through a 1:1 spur pair.
//
// Why gears at all if the ratio is 1:1: a 1:1 pair buys no mechanical
// advantage, it RELOCATES THE CONTROL POINT. The azimuth axis is the
// central column -- there is physically nowhere to put a knob on it. The
// tilt axis is a loaded trunnion buried between yoke arms. Both gear
// pairs exist to move the grip somewhere fingers can reach without
// putting a hand in the load path. Saying so here because "1:1 gearing"
// otherwise reads like a mistake.
//
// Scope: this file and this directory own the ADAPTER only. ../mount is
// the payload. Nothing here modifies it, and nothing in ../optics or
// ../tele is touched.
//
// ---------------------------------------------------------------------
// PROVENANCE TAGS -- every constant below carries one:
//   MEASURED  someone put a caliper on the real object; source cited
//   ASSUMED   nobody has measured it yet. MUST be checked before print.
//   STANDARD  a published spec for a standard part (1/4-20, M3/M5/M6)
//   CHOSEN    a free design decision made here
//   DERIVED   computed from the above; never type one of these by hand
// ---------------------------------------------------------------------
//
// On restating STANDARD values that ../mount/params.scad also states:
// cad-design rule 3 is about a project's own measured and derived
// numbers drifting apart. A published thread spec is not that. This
// directory is deliberately self-contained the same way nema17.scad is,
// so it can be copied under any 1/4-20 payload. The two numbers that are
// genuinely SHARED with ../mount -- the payload's footprint and the
// depth its captured nut sits at -- are NOT restated: check.py reads
// them out of ../mount at runtime and fails if this file drifts.

include <lib/BOSL2/std.scad>
include <lib/BOSL2/gears.scad>
include <lib/BOSL2/threading.scad>
include <knob.scad>


// =====================================================================
// 1. THE TWO TRIPOD INTERFACES
// =====================================================================
// Bottom: a female socket that swallows the tripod's own male stud.
// Top:    a male stud that presents, upward, exactly what a tripod head
//         presents -- so ../mount/base.scad bolts on unmodified.
tripod_thread    = "1/4-20";  // STANDARD, both ends
tripod_major     = 6.35;      // STANDARD -- 1/4" major dia, mm
tripod_nut_af    = 11.2;      // STANDARD -- 1/4-20 hex nut across flats
tripod_nut_t     = 5.6;       // STANDARD -- 1/4-20 hex nut thickness

// The upward stud is a STEEL 1/4-20 bolt captured head-down in the
// platter, not a printed thread. A printed male thread is the one part
// of this assembly that would carry the entire payload in tension across
// layer lines, and ../mount/README.md already lists "a coupon for the
// 1/4-20 male thread" as an unproven item. Do not print the thread.
stud_head_af     = 11.2;   // STANDARD -- 1/4-20 hex head across flats
stud_head_t      = 4.4;    // STANDARD -- 1/4-20 hex head height
stud_protrude    = 6.0;    // CHOSEN -- how far the shank stands proud of
                           // the platter's top face. Must reach into the
                           // payload's captured nut; check.py verifies
                           // this against ../mount's real nut depth
                           // rather than against the copy above.


// =====================================================================
// 2. THE PAYLOAD -- the binding constraint on everything above the tilt
// =====================================================================
// What sits on top is ../mount/base.scad, a disc with an arm out to the
// azimuth stepper. Its UNDERSIDE is the only part of the whole motorized
// mount that can ever reach down far enough to hit this riser -- the
// table, yoke and telescope are all above it and sweep away from us. So
// the payload proxy for interference is mount/base itself, and check.py
// renders that real part rather than modelling a stand-in disc.
//
// payload_r is the number this file DESIGNS to. It is not a restatement
// of mount's base_plate_r: check.py measures the actual rendered
// footprint of ../mount/base.scad and fails if it exceeds this.
//
// MEASURED, and it changed the design. The first pass here assumed the
// payload was a 124mm disc and drew a yoke that straddled it. Rendering
// ../mount/base.scad and measuring it says otherwise: the disc is r=62,
// but the arm out to the azimuth stepper reaches 129.7mm from the axis.
// A yoke straddling THAT is a 266mm-wide part. The straddle was dropped
// for a single tine -- which is what ../mount/yoke.scad does, one level
// up, for the same reason.
payload_r        = 62.0;   // ASSUMED-from-mount -- the disc. check.py
                           // measures the real mesh and fails on drift.
payload_arm_r    = 130.0;  // ASSUMED-from-mount -- the motor arm's reach.
                           // Same verification. NOTE this rests on
                           // ../mount's belt_loop_len, which is itself
                           // ASSUMED and unmeasured, so it will move.
//
// ORIENTATION IS AN ASSEMBLY CONSTRAINT, not a geometric one. The payload
// joins by a single 1/4-20 screw, so it can be installed at any azimuth,
// and the arm clears the tines in only some of them.
//
// With tines at BOTH +Y and -Y the arm has to lie along X, and the choice
// between +X and -X is not free: +X is the side that swings DOWN as the
// tilt goes up, so an arm there sweeps toward the column. -X rises into
// open air. So: INSTALL THE MOUNT WITH ITS MOTOR ARM POINTING -X.
//
// check.py verifies the two halves of that claim separately, because only
// one of them survives someone turning the mount a quarter turn on its
// single screw: the r=62 disc against everything, which is true at EVERY
// orientation, and the real arm at the specified one.
payload_arm_dir  = 180;    // CHOSEN, degrees about Z -- the orientation
                           // this directory designs to and check.py poses
payload_mass     = 1.6;    // ASSUMED, kg -- printed mount + the Power
                           // Seeker 50AZ tube. NOBODY HAS WEIGHED THIS.
                           // It sets the holding torque in section 7,
                           // which is the least comfortable number in
                           // this design. WEIGH IT BEFORE PRINTING.
payload_cg_h     = 130.0;  // ASSUMED, mm above the tilt axis. Same
                           // caveat. Sensitivity is linear in both.


// =====================================================================
// 3. GEAR TRAIN -- 1:1 on both axes, but NOT the same gear
// =====================================================================
// Both pairs are 1:1 as asked. They are sized differently on purpose,
// because the two axes carry completely different loads:
//
//   AZIMUTH  gravity is PARALLEL to this axis, so an off-centre payload
//            makes no torque about it at all. The az pair only ever
//            fights bearing drag. It can be small, and small is what
//            keeps the base plate from growing -- the knob's axis sits
//            one full pitch diameter out from the column, so the az
//            centre distance IS the base plate's radius, near enough.
//
//   TILT     gravity acts at right angles to this axis and the payload
//            sits ABOVE it, so this pair carries the full overturning
//            torque of section 7. It is bigger, and it costs nothing to
//            make it bigger because it lives up top where the payload's
//            own 124mm width already sets the envelope.
gear_pa          = 20;     // STANDARD -- pressure angle
gear_backlash    = 0.15;   // CHOSEN -- circumferential backlash, mm. Hand
                           // pointing wants free rotation over precision;
                           // a bound printed gear pair is worse than a
                           // loose one.

az_gear_mod      = 2.0;    // CHOSEN
az_gear_teeth    = 20;     // CHOSEN -- above the 17-tooth undercut limit
                           // at 20 deg PA, so no profile shift is needed.
az_gear_face     = 10.0;   // CHOSEN

tilt_gear_mod    = 2.5;    // CHOSEN -- bigger tooth, see section 7
tilt_gear_face   = 12.0;   // CHOSEN

// The tilt pair is split into a WHEEL (on the trunnion) and a PINION (on
// the knob) rather than written as one tooth count, even though both are
// 20 and the ratio is the 1:1 that was asked for. The reason is section 7:
// the holding torque this axis carries is close to the edge of what a hand
// knob can deliver, and the cleanest remedy is a reduction. Constraining
// the two counts to a fixed SUM keeps the centre distance invariant, so a
// different ratio is a swap of two printed parts and nothing else -- no
// yoke change, no knob-post move, no re-check of the layout.
tilt_teeth_sum   = 40;     // CHOSEN -- fixes tilt_gear_cd. Do not change.
tilt_wheel_teeth = 20;     // CHOSEN -- 1:1 as specified
tilt_pinion_teeth = tilt_teeth_sum - tilt_wheel_teeth;   // DERIVED
tilt_ratio       = tilt_wheel_teeth / tilt_pinion_teeth; // DERIVED

// DERIVED. gear_dist(), never pitch_radius() -- using the pitch radius as
// a centre distance is the exact defect optics/model-analysis.md records
// as surviving a rendered review.
az_gear_pd        = az_gear_mod * az_gear_teeth;
tilt_wheel_pd     = tilt_gear_mod * tilt_wheel_teeth;
tilt_pinion_pd    = tilt_gear_mod * tilt_pinion_teeth;
az_gear_cd        = gear_dist(mod = az_gear_mod, teeth1 = az_gear_teeth,
                              teeth2 = az_gear_teeth, pressure_angle = gear_pa);
tilt_gear_cd      = gear_dist(mod = tilt_gear_mod, teeth1 = tilt_wheel_teeth,
                              teeth2 = tilt_pinion_teeth,
                              pressure_angle = gear_pa);
az_gear_tip_r     = outer_radius(mod = az_gear_mod, teeth = az_gear_teeth,
                                 pressure_angle = gear_pa);
tilt_wheel_tip_r  = outer_radius(mod = tilt_gear_mod, teeth = tilt_wheel_teeth,
                                 pressure_angle = gear_pa);
tilt_pinion_tip_r = outer_radius(mod = tilt_gear_mod, teeth = tilt_pinion_teeth,
                                 pressure_angle = gear_pa);

// Centre distance must not depend on how the sum was split, or the "swap
// two printed parts" escape hatch above is a lie. Asserted, not assumed.
assert(abs(tilt_gear_cd - tilt_gear_mod * tilt_teeth_sum / 2) < 1e-6,
       str("tilt centre distance moved with the ratio: ", tilt_gear_cd,
           " vs ", tilt_gear_mod * tilt_teeth_sum / 2,
           ". The drop-in swap in section 3 no longer holds."));

// MESH PHASE. Two gears at the right centre distance still interfere if
// their teeth are drawn in the same phase -- tooth lands on tooth instead
// of in the gap. It is invisible in a render at any angle and it showed
// up here only as an interference volume: 296 mm3 on the tilt pair, from
// a mesh that looked perfect. Half a tooth pitch on the driven member is
// the whole fix.
az_mesh_phase    = 180 / az_gear_teeth;      // DERIVED -- half a pitch
tilt_mesh_phase  = 180 / tilt_pinion_teeth;  // DERIVED

assert(az_gear_teeth      >= 17, "az gear undercuts at 20 deg PA");
assert(tilt_wheel_teeth   >= 17, "tilt wheel undercuts at 20 deg PA");
assert(tilt_pinion_teeth  >= 14,
       str("tilt pinion at ", tilt_pinion_teeth, " teeth undercuts badly ",
           "at 20 deg PA. Below 14 it needs a profile shift, which this ",
           "file does not apply."));


// =====================================================================
// 4. AZIMUTH STAGE -- lowest, as asked
// =====================================================================
az_post_d        = 20.0;   // CHOSEN -- journal post. Wider than mount's
                           // 16 because this riser stands taller and the
                           // payload's overturning moment lands here.
az_post_h        = 40.0;   // CHOSEN -- journal engagement above the deck.
                           // L/D = 2.0. mount/params.scad records why an
                           // L/D under 1 is not enough on a tipping load;
                           // a taller stalk needs more, not less.
az_journal_fit   = 0.35;   // CHOSEN -- radial running clearance per side,
                           // the proven slip-fit allowance in this repo
az_thrust_r      = 28.0;   // CHOSEN -- flat annular thrust face radius.
                           // The sunk gear pocket eats the middle of it,
                           // so the LIVE ring is pocket-radius..this, and
                           // that ring is what carries the payload's
                           // weight. 26 left it under 3mm wide.
az_thrust_h      = 1.0;    // CHOSEN -- how far it stands proud of the plate
// Axial retention is a COLLAR GROOVE, not a screw up the post's centre.
// A centre screw has no access route: the column closes over the post's
// top for its whole length, so the screw head ends up sealed inside a
// 100mm blind bore. Two radial grub screws into a turned groove retain
// from outside, where a hand can reach them.
az_groove_w      = 3.0;    // CHOSEN -- groove width
az_groove_depth  = 1.5;    // CHOSEN -- groove depth, radial
az_grub_d        = 3.0;    // STANDARD -- M3 grub screws, two at 90 deg
az_grub_n        = 2;      // CHOSEN
az_table_t       = 6.0;    // CHOSEN -- rotating table plate thickness

base_plate_t     = 15.0;   // CHOSEN -- thick enough to sink the azimuth
                           // gear pair into pockets in its top face
az_gear_pocket_c = 5.0;    // CHOSEN -- pocket floor above the plate's
                           // underside; also the plate's floor thickness
az_knob_pin_d    = 8.0;    // CHOSEN -- the FIXED pin standing up out of
                           // the pedestal. The knob is a sleeve over it,
                           // so the journal sits at the gear, where the
                           // load is, rather than at the far end of a
                           // cantilever.
az_knob_h        = 14.0;   // CHOSEN -- grip height
az_hex_af        = 14.0;   // CHOSEN -- the azimuth handle's hex. Smaller
                           // than the tilt one because it wraps a smaller
                           // pin; the azimuth pinion is therefore a
                           // different part from the tilt gear, not the
                           // same one. Making them identical would mean
                           // running the azimuth pair at module 2.5 too,
                           // which moves its centre distance to 50 and
                           // grows the base plate by 31mm across. Part
                           // count did not beat footprint here; on the
                           // tilt side, where the envelope was already set
                           // by the payload, it did.
                           // (az_knob_shaft_d is DERIVED, in section 9 --
                           // it needs `wall`, which is declared below.
                           // OpenSCAD resolves file-scope assignments in
                           // order and does NOT hoist them, so a forward
                           // reference here silently evaluates to undef
                           // and propagates. Exactly the rule-2 failure
                           // mode: it warns, it does not stop.)


// =====================================================================
// 5. COLUMN -- "a little tall"
// =====================================================================
// The rise is a free choice and it is a real trade: every millimetre of
// column is another millimetre of lever arm on the azimuth journal, and
// it raises the payload's CG above the tilt axis, which section 7 shows
// is what sets the holding torque. 130 is a riser, not a mast.
riser_rise       = 130.0;  // CHOSEN -- tripod face to payload mounting face
column_r         = 15.0;   // CHOSEN -- and this is a CLEARANCE-driven
                           // number, not a strength-driven one. The
                           // azimuth knob's disc overhangs inward to
                           // (az_gear_cd - knob_d/2); the column has to
                           // pass through that gap. Bending stress in a
                           // 30mm column here is under 0.5 MPa, so
                           // clearance is free to win.


// =====================================================================
// 6. TILT STAGE
// =====================================================================
// The tilt axis lies along Y. Tilt 0 = payload face level. Positive tilt
// leans the payload's +X edge DOWN, which is what "look up" means once
// the telescope on top is pointing +X.
tilt_max_deg     = 40;     // CHOSEN -- eva: "not too worried about the
                           // vertical range as long as it can look up".
                           // 40 is what the payload sweep supports; the
                           // real achieved figure is measured by check.py,
                           // not asserted from here.
tilt_platter_t   = 10.0;   // CHOSEN
tilt_platter_r   = 34.0;   // CHOSEN -- a tripod-plate-sized disc. The
                           // payload overhangs it freely; it does not
                           // need to be as wide as the payload.

// TWO TINES, and they are not the same tine twice.
//
// The DRIVE tine, at -Y, carries everything: a closed bore, the flange
// journal, the clamp, and both gears. The SADDLE tine, at +Y, is an open
// half-circle the second stub simply drops into. eva's design, and the
// open half is the load-bearing idea in it rather than a simplification:
// two closed bores on one axis cannot be assembled at all -- neither stub
// can enter its bore without the other leaving one. An open saddle can be
// dropped in from above, and it still takes load, because the load on
// this axis is the payload's weight pressing straight down into the seat.
// Nothing has to hold it up.
//
// The first design here had only the drive tine, which put the payload's
// whole roll moment through one single-shear joint. Two seats on one axis
// carry it as a couple instead, across a 130mm span.
//
// The straddle is affordable ONLY because both tines sit outboard of
// payload_r: rotation about Y moves nothing in Y, so a tine outboard of
// the payload disc can never be struck by it at any tilt angle. What it
// does cost is the ORIENTATION rule -- see section 2. With one tine the
// motor arm had a whole half-plane to live in; with two it has to lie
// along X, and -X specifically, because +X is the side that swings down.
//
// The drive trunnion is still a WIDE SHALLOW FLANGE JOURNAL rather than a
// narrow deep pin. Its annular face IS the friction surface that holds
// the tilt, and friction torque goes as the cube of that radius -- the
// wide journal is what makes section 7's clamp force reachable by a wing
// nut instead of a wrench.
tilt_arm_gap     = 3.0;    // CHOSEN -- clearance past the payload rim
tilt_arm_t       = 14.0;   // CHOSEN -- tine thickness, in Y
tilt_arm_y       = -(payload_r + tilt_arm_gap);     // DERIVED -- the DRIVE
                   // tine's INNER face. Negative: that tine is at -Y.
tilt_arm_y_out   = tilt_arm_y - tilt_arm_t;         // DERIVED -- outer face
tilt_arm2_y      =  (payload_r + tilt_arm_gap);     // DERIVED -- the SADDLE
                   // tine's inner face, mirrored to +Y
tilt_arm2_y_out  = tilt_arm2_y + tilt_arm_t;        // DERIVED
tilt_arm_x       = 22.0;   // CHOSEN -- tine half-extent in X at the axis

tilt_journal_d   = 44.0;   // CHOSEN -- flange journal diameter
tilt_journal_h   = 5.0;    // CHOSEN -- how deep the flange sits into the
                           // tine's counterbore
tilt_stub_d      = 14.0;   // CHOSEN -- the stub that carries on through
                           // the tine, keying the gear outboard
tilt_hex_af      = 20.0;   // CHOSEN -- the across-flats every tilt-side
                           // hex uses. ONE size, because it is what makes
                           // the gear on the trunnion and the gear on the
                           // knob the SAME PRINTED PART: same module, same
                           // tooth count, same bore. eva's call. It is
                           // sized by the knob side, which has to get a
                           // 2.4mm wall around a 14mm pin -- the trunnion
                           // stub could have been smaller and is grown to
                           // match, because one part beats two.
tilt_stub_hex_af = tilt_hex_af;   // DERIVED -- across-flats of the hex
                           // stub end that keys the tilt wheel. A hex,
                           // not a round with a grub screw: a grub
                           // bearing on a round printed boss slips, which
                           // is the failure ../mount/alt_rotor.scad was
                           // redesigned to avoid one axis over.
tilt_clamp_d     = 6.0;    // STANDARD -- M6 up the stub's axis, wing nut
                           // outboard. Its preload is the tilt friction.
tilt_ear_x       = 24.0;   // CHOSEN -- thickness in X of the platter's
                           // ears, the arms that reach out to the tines
tilt_saddle_d    = 16.0;   // CHOSEN -- the +Y stub, running in the open
                           // saddle. Larger than the drive stub because it
                           // has no flange beside it to share the roll
tilt_gear_standoff = 1.2;  // CHOSEN -- how far BOTH tilt gears stand off
                           // the tine's outer face. Not cosmetic: with the
                           // gears flush the wing nut squeezes them
                           // against the tine and clamps the drive to
                           // ground. A joint that seizes interferes with
                           // nothing and passes every geometric check ever
                           // written, so it gets a measured gap rather
                           // than an intention.
tilt_fit         = 0.35;   // CHOSEN -- running clearance on the trunnion,
                           // per side. Same proven allowance as the
                           // azimuth journal.

                           // moment; the seat is all there is.
// The seat wraps PAST 180 degrees so it captures the stub sideways rather
// than merely holding it up. The wrap is DERIVED from how much undersize
// the mouth should have, not chosen in degrees -- because degrees are the
// wrong unit to think in here and choosing them directly got it wrong:
// 205 degrees sounds generously past half, and it produced a mouth
// 16.30mm across a 16mm stub. No capture at all, and saddle_arm.scad's
// own assert is what caught it. The snap is what matters; the angle is
// what follows.
tilt_saddle_snap = 0.5;    // CHOSEN, mm the mouth is narrower than the
                           // stub. A printed seat opens a few tenths
                           // elastically -- this is a snap fit, not an
                           // interference fit, and a millimetre would
                           // split it rather than flex it.
function saddle_seat_r() = tilt_saddle_d / 2 + tilt_fit;

tilt_saddle_wrap = 360 - 2 * asin((tilt_saddle_d - tilt_saddle_snap)
                                  / (2 * saddle_seat_r()));  // DERIVED

// How far the saddle's HORNS reach above the axis. The seat only needs
// material up to where its wrap ends -- past that point it is not holding
// anything, and the earlier version carried the drive tine's full arch
// over the top and then cut a channel straight through it. That looked
// like a slot sawn through solid material rather than a seat, which is
// exactly what it was.
//
// Derived from the wrap, so the horns follow the snap rather than being
// a number somebody picked: the mouth's edges sit at
// seat_r * cos((360 - wrap)/2) above the axis, plus a little crown.
saddle_horn_h    = saddle_seat_r() * cos((360 - tilt_saddle_wrap) / 2)
                   + 2.5;   // DERIVED
tilt_knob_pin_d  = 14.0;   // CHOSEN -- the fixed pin on the tine's OUTER
                           // face that the tilt knob turns on. Sized by
                           // bending, not by fit: the whole point of
                           // section 7 is that a hand pushes hard on this
                           // knob, and that force lands here as a
                           // cantilever. At 10mm it runs to 22 MPa.
tilt_knob_pin_h  = 16.0;   // CHOSEN -- long enough that the handle's
                           // bore can run past its tip and still leave
                           // grip behind it. Shortened from 20 when the
                           // handle became a separate part: the bore now
                           // has to clear the pin AND stay inside the
                           // grip, and 20 put the pin's tip in the middle
                           // of the grip's own body.
tilt_knob_h      = 16.0;   // CHOSEN -- grip height
yoke_web_t       = 12.0;   // CHOSEN -- thickness in X of the gusset that
                           // reaches from the column out to the tine.
                           // Thin in X on purpose: the payload's
                           // descending edge sweeps through +X at large
                           // tilt, and a web that stayed thick there
                           // would be the first thing it hit.

// Friction the trunnion can actually generate, per newton of clamp.
// Annular contact, mean-radius form:
//     T = mu * F * (2/3) * (r2^3 - r1^3) / (r2^2 - r1^2)
tilt_mu          = 0.35;   // ASSUMED -- PLA on PLA, dry. Not measured.
tilt_fric_r2     = tilt_journal_d / 2;
tilt_fric_r1     = tilt_stub_d / 2;
tilt_fric_per_N  = tilt_mu * (2 / 3)
                   * (pow(tilt_fric_r2, 3) - pow(tilt_fric_r1, 3))
                   / (pow(tilt_fric_r2, 2) - pow(tilt_fric_r1, 2));
                   // DERIVED, N*mm of holding torque per N of clamp


// =====================================================================
// 7. HOLDING -- the part of this design that is not comfortable
// =====================================================================
// A 1:1 gear pair is not self-locking and cannot hold anything. Let go of
// the knob and the payload back-drives it. So "rough pointing" needs a
// friction term, and the two axes need completely different amounts of it:
//
//   AZIMUTH  gravity is parallel to the axis. An off-centre payload
//            exerts ZERO torque about it. Azimuth needs a light drag so
//            it does not wander, not a lock. That drag is the M5
//            retaining screw's preload against the thrust annulus -- no
//            separate part.
//
//   TILT     the payload sits ABOVE the tilt axis, so this is an inverted
//            pendulum: the overturning torque GROWS with tilt angle
//            instead of shrinking. It has to be held by friction at the
//            trunnion, preloaded by the M6 wing nuts.
//
// Constant drag, not a point-then-lock clamp: a clamp tightened after
// aiming shifts the aim as it takes up. Drag that is always present does
// not.
grav             = 9.81;   // STANDARD
tilt_torque_max  = payload_mass * grav * (payload_cg_h / 1000)
                   * sin(tilt_max_deg);            // DERIVED, N*m
// Friction must exceed gravity or it does not hold at all. Margin over
// 1.0 is what stops it creeping between adjustments.
hold_margin      = 1.5;    // CHOSEN
tilt_friction_t  = tilt_torque_max * hold_margin;  // DERIVED, N*m
// Worst case at the knob: beat gravity and the drag at the same time,
// divided by whatever reduction the gear pair gives (1.0 as specified).
knob_torque_req  = (tilt_torque_max + tilt_friction_t) / tilt_ratio;  // N*m
tilt_knob_d      = 60.0;   // CHOSEN -- grip diameter. Big for a knob,
                           // because rim force is the binding constraint
                           // below and diameter is the only lever this
                           // file has that costs nothing structural.
// Two fingers on the rim of a knob that size. THIS is the number that
// decides whether the mechanism as specified is actually usable by hand.
knob_force_req   = knob_torque_req / (tilt_knob_d / 2000);  // DERIVED, N
knob_force_limit = 60.0;   // CHOSEN -- roughly a comfortable sustained
                           // two-finger pinch, ~6 kgf

// Deliberately an ECHO and not an assert. It is a claim about a human
// hand resting on two ASSUMED payload numbers, not a claim about
// geometry, and a geometric checker has no business failing a build over
// it. check.py reports it as a warning and says so.
//
// The remedy, if it bites, is the fixed-sum split in section 3 and
// nothing else: raise tilt_wheel_teeth, lower tilt_pinion_teeth by the
// same amount, reprint two parts.
// Ratio that would bring the rim force inside the comfort limit, at the
// same fixed tooth sum and therefore the same centre distance. Solved,
// not guessed: with w + p fixed and ratio = w/p, p = sum / (1 + ratio).
// floor() on the pinion, so rounding always lands on MORE reduction
// rather than less.
tilt_ratio_needed = tilt_ratio * knob_force_req / knob_force_limit;  // DERIVED
tilt_pinion_needed = knob_force_req <= knob_force_limit
    ? tilt_pinion_teeth
    : floor(tilt_teeth_sum / (1 + tilt_ratio_needed));               // DERIVED
tilt_wheel_needed  = tilt_teeth_sum - tilt_pinion_needed;            // DERIVED
echo(str("HOLDING: tilt gravity torque at ", tilt_max_deg, " deg = ",
         tilt_torque_max, " Nm, plus drag at margin ", hold_margin,
         " -> knob must deliver ", knob_torque_req, " Nm = ",
         knob_force_req, " N at a ", tilt_knob_d, " mm rim (comfort ",
         knob_force_limit, " N). Ratio is ", tilt_ratio, ":1."));
if (knob_force_req > knob_force_limit)
    echo(str("HOLDING WARNING: the 1:1 pair as specified needs ",
             knob_force_req / knob_force_limit,
             "x a comfortable hand. Same centre distance, same everything ",
             "else: tilt_wheel_teeth ", tilt_wheel_needed,
             " / tilt_pinion_teeth ", tilt_pinion_needed, " (ratio ",
             tilt_wheel_needed / tilt_pinion_needed, ":1, rim force ",
             knob_force_req * tilt_ratio / (tilt_wheel_needed
                                            / tilt_pinion_needed),
             " N) would bring it in. Two printed parts, nothing else ",
             "moves."));

// What the wing nut actually has to deliver. This is the number that
// decides whether the trunnion holds by hand-tightening or needs a tool.
tilt_clamp_force = tilt_friction_t * 1000 / tilt_fric_per_N;   // DERIVED, N
clamp_hand_limit = 800.0;  // ASSUMED -- what a firm hand on an M6 wing nut
                           // reaches. Not measured; wing nuts vary wildly.
echo(str("CLAMP: trunnion needs ", tilt_clamp_force,
         " N of preload for ", tilt_friction_t, " Nm of drag (hand limit ~",
         clamp_hand_limit, " N)"));

// Tooth bending, the other consequence of that torque. The tangential
// force is common to both members; the PINION is the weaker one because
// it has fewer teeth, so it is the one checked.
lewis_y          = 0.30;   // STANDARD-ish -- Lewis form factor, small
                           // spur tooth at 20 deg PA. Conservative.
tilt_tooth_f     = (tilt_torque_max + tilt_friction_t)
                   / (tilt_wheel_pd / 2000);                    // DERIVED, N
tilt_tooth_sigma = tilt_tooth_f / (tilt_gear_face * tilt_gear_mod * lewis_y);
pla_sigma_allow  = 20.0;   // CHOSEN, MPa -- a deliberately conservative
                           // working stress for a printed tooth loaded
                           // across layer lines, well under bulk PLA yield
assert(tilt_tooth_sigma <= pla_sigma_allow,
       str("tilt gear teeth overstressed: ", tilt_tooth_sigma,
           " MPa vs allowable ", pla_sigma_allow,
           ". Raise tilt_gear_mod or tilt_gear_face, or cut the payload."));

az_knob_d        = 40.0;   // CHOSEN -- see column_r; this and the column
                           // fight for the same gap


// =====================================================================
// 8. PRINT / FIT
// =====================================================================
wall             = 2.4;    // CHOSEN -- proven wall in this repo's prints
clearance        = 0.25;   // CHOSEN -- general slip fit
layer_h          = 0.2;

// Tessellation. MEASURED cost, not a guess: at $fa=2/$fs=0.4 a single
// posed tilt_knob took 105 seconds and came out 110k triangles, which
// makes both check.py's sweep and the web viewer impractical. The knob's
// chamfer is the reason -- it is twelve stacked offset() operations on a
// lobed profile, so every extra segment in that profile is paid for
// twelve times over. At 4/0.8 the same part is a few seconds and a
// tenth the size, and the largest chord error on a 60mm knob is under
// 0.02mm, well inside the 0.35mm fits this design turns on.
$fa = 4;
$fs = 0.8;


// =====================================================================
// 9. LAYOUT -- all DERIVED. Do not hand-type a number in this section.
// =====================================================================
// Frame, shared by every part and by check.py:
//   +Z up. The azimuth axis is Z through the origin. The tilt axis is
//   horizontal, along Y, through X=0 at height tilt_axis_z. Z=0 is the
//   TRIPOD MOUNTING FACE -- the underside of the base plate, where the
//   tripod head's own top face bears. It is not "the ground": below it is
//   a tripod, and ../mount/check.py learned that lesson by reporting a
//   false altitude ceiling against exactly this plane.

az_deck_z        = base_plate_t + az_thrust_h;   // top of the thrust face
az_table_z       = az_deck_z;                    // table underside
az_table_top_z   = az_table_z + az_table_t;

// The azimuth gear hangs BELOW the table into a pocket in the base plate,
// not above it. Above the table is where the column has to be, and a gear
// concentric with the column would put the knob gear's tooth tips through
// the column's wall. Sinking the pair keeps the whole top of the table
// free.
az_gear_z0       = az_table_z - az_gear_face;    // gear bottom
az_gear_z1       = az_table_z;                   // gear top, at the table
az_pocket_floor  = az_gear_pocket_c;             // pocket floor in the plate
assert(az_gear_z0 > az_pocket_floor,
       str("azimuth gear would be buried in the base plate floor: gear ",
           "bottom ", az_gear_z0, " vs pocket floor ", az_pocket_floor));

az_post_top_z    = az_deck_z + az_post_h;
az_knob_bore_d   = az_knob_pin_d + 2 * az_journal_fit;  // DERIVED
az_knob_shaft_d  = az_knob_bore_d + 2 * wall;  // DERIVED -- the handle's
                   // own sleeve OD. Grown from the BORE, not from the pin:
                   // built off the pin it came out a running clearance
                   // short of a full wall, and the part's own assert
                   // caught it. The clearance is not free material.

// The widest thing on the azimuth handle. NOT the shaft: the hex is wider
// across its corners than the shaft is across its diameter, and deriving
// the table's radius from the shaft put the table 0.56mm from the hex's
// top corner. Both numbers were right; the wrong one was chosen. Taking
// the max means adding another section to the handle cannot quietly
// invalidate the clearance below.
az_handle_max_r  = max(az_knob_shaft_d, az_hex_af / cos(30)) / 2;
az_table_r       = az_gear_cd - az_handle_max_r - 2.5;  // DERIVED --
                   // the table has to slip past the knob's post, so the
                   // knob post is what sets the table's radius, not the
                   // gear under it. Chaining it the other way round is
                   // how a table ends up the same size as the post it
                   // must clear.
assert(az_table_r > az_thrust_r,
       "azimuth table is narrower than the thrust face it rides on");
assert(az_table_r > az_gear_tip_r,
       "azimuth table does not cover its own gear");

// The sunk gear pocket, owned here because BOTH pedestal.scad (which cuts
// it) and the thrust ring (which has to stay outside it) depend on it.
az_pocket_r      = az_gear_tip_r + clearance + 1;   // DERIVED
assert(az_thrust_r > az_pocket_r + 3.0,
       str("the live thrust ring is only ", az_thrust_r - az_pocket_r,
           "mm wide -- the gear pocket has eaten it."));
assert(az_thrust_r < az_table_r - 1.0,
       str("the thrust ring at r=", az_thrust_r, " runs out past the ",
           "table at r=", az_table_r, " that rides on it."));

base_plate_r     = az_gear_cd + az_gear_tip_r + 6;   // DERIVED -- reach
                   // the knob gear's pocket, plus a rim
assert(base_plate_r > az_thrust_r, "base plate smaller than its thrust face");

// The tripod screw comes up the centre and stops inside the plate. There
// used to be an assert here that it never met the azimuth retaining
// screw coming down; the collar groove replaced that screw, so the
// assert is gone rather than left standing over a hazard that no longer
// exists. An assert that cannot fail is worse than no assert -- it reads
// as coverage.
tripod_bore_top  = base_plate_t * 0.66;             // DERIVED
az_groove_z      = az_post_top_z - 8;               // DERIVED -- groove
                   // centre, near the post's top so the collar's grip is
                   // at the far end of the journal

// Azimuth knob: its gear shares the sunk pocket with the table's gear, so
// the two are coplanar by construction rather than by coincidence. The
// grip rises clear of the table on a shaft.
az_knob_gear_z0  = az_gear_z0;
az_knob_gear_z1  = az_gear_z1;
az_knob_pin_top  = az_gear_z1 + 8;                  // DERIVED -- the pin
                   // stands proud of the gear, so the sleeve is journalled
                   // over more than just the gear's own face
az_knob_grip_z   = az_table_top_z + 30;             // DERIVED -- grip
                   // underside, a hand's width above the table
az_knob_top_z    = az_knob_grip_z + az_knob_h;      // DERIVED
assert(az_gear_cd - az_knob_d / 2 > column_r + 3.0,
       str("the azimuth knob's grip fouls the column: knob reaches in to ",
           az_gear_cd - az_knob_d / 2, ", column is ", column_r,
           ". Shrink az_knob_d, shrink column_r, or spread az_gear_cd."));

// Tilt.
tilt_axis_z      = riser_rise - tilt_platter_t / 2;   // DERIVED -- the
                   // axis sits at the platter's mid-plane, which puts the
                   // payload's mounting face only half a platter above
                   // it. Every millimetre the axis drops below the payload
                   // is another millimetre of CG height in section 7.
payload_face_z   = riser_rise;                        // DERIVED
assert(tilt_axis_z > az_table_top_z + column_r,
       "the tilt axis is not clear of the azimuth table");

// The tilt knob hangs below the axis on the outboard face of the -Y arm.
// Below rather than beside, so it adds nothing to the X footprint, and
// outboard of an arm that is already outboard of the payload, so it can
// never be reached by the payload at any tilt angle.
tilt_knob_gear_y = tilt_arm_y_out;                   // DERIVED -- the
                   // wheel's inner face lies on the tine's outer face
tilt_knob_x      = 0;                                // DERIVED
tilt_knob_z      = tilt_axis_z - tilt_gear_cd;       // DERIVED -- straight
                   // down one centre distance
assert(tilt_knob_z - tilt_pinion_tip_r > az_table_top_z,
       str("the tilt knob's gear swings into the azimuth table: gear ",
           "reaches down to ", tilt_knob_z - tilt_pinion_tip_r,
           ", table top is ", az_table_top_z, ". Raise riser_rise."));

// Sanity on the whole stack: the column has to actually span the gap.
// THE YOKE CEILING. The gusset runs under the tilting parts, so it needs
// a roof, and the roof is not a constant -- it is a function of Y, which
// is what the first attempt here got wrong. Every tilting part is centred
// ON the tilt axis, so each sweeps a cylinder about it: a point stays at
// its own radius and only changes angle. Two different parts set that
// radius over two different spans of Y:
//
//   |y| <= tilt_platter_r   the PLATTER, radius sqrt(r^2 - y^2 + (t/2)^2).
//                           At y=0 that is 34.4mm, not the 11mm a
//                           thickness-only reading gives -- the platter's
//                           own radius swings down through the yoke.
//   |y| up to the tine      the EAR, a constant 16.3mm.
//
// Taking the smaller of the two, as the first version did, ran the column
// straight up to the tilt axis and put 5,473 mm3 of it inside the platter.
// Watertight, valid, and the two parts occupying the same space.
tilt_ear_h       = 22.0;   // CHOSEN -- ear depth in Z, centred on the axis
tilt_ear_sweep_r = sqrt(pow(tilt_ear_x / 2, 2) + pow(tilt_ear_h / 2, 2));
yoke_gap         = 3.0;    // CHOSEN -- clearance under the sweep
//   |y| >  tilt_platter_r   whatever the widest thing turning out there
//                            is, which is the FLANGE JOURNAL at 22mm.
//
// That last case is the one the first two versions of this function got
// wrong, and it cost 601 mm3 of the yoke's blade standing inside the
// platter's saddle stub. Both earlier versions reasoned about the parts
// they could see from the tilt axis -- the platter, then the ear -- and
// both forgot that the STUBS reach 14mm further out in Y than the tines'
// inner faces do. Outboard of the platter this now returns the largest
// radius anything rotating has, full stop, rather than a list of cases
// somebody has to remember to extend every time a feature is added.
function yoke_sweep_r(y) =
    abs(y) <= tilt_platter_r
        ? max(sqrt(pow(tilt_platter_r, 2) - y * y
                   + pow(tilt_platter_t / 2, 2)),
              tilt_ear_sweep_r)
        : tilt_journal_d / 2;
function yoke_ceiling(y) = tilt_axis_z - yoke_sweep_r(y) - yoke_gap;

// And a FLOOR, for a reason that has nothing to do with the tilt axis:
// everything on this column sweeps a full circle in azimuth, so anything
// between the knob's inner and outer reach has to pass over the azimuth
// knob. The first version raked the gusset down to the table and put
// 6,986 mm3 of it through the knob at 90 degrees of azimuth -- a clash
// that does not exist at az=0 and so is invisible in the obvious render.
yoke_bottom_z    = az_knob_top_z + 3;               // DERIVED
column_top_z     = yoke_ceiling(0);                 // DERIVED -- the column
                   // stops under the platter's swing, not at the axis
assert(column_top_z > yoke_bottom_z + 5,
       str("no room for a yoke: ceiling ", column_top_z, " vs floor ",
           yoke_bottom_z, ". Raise riser_rise."));
assert(yoke_ceiling(tilt_arm_y) > yoke_bottom_z,
       "the gusset has no height where it meets the drive tine");
assert(yoke_ceiling(tilt_arm2_y) > yoke_bottom_z,
       "the gusset has no height where it meets the saddle tine");
assert(tilt_arm2_y > payload_r,
       "the saddle tine is inboard of the payload disc and will be hit");
YOKE_SAMPLES     = 14;     // CHOSEN -- points along the ceiling curve

column_h         = tilt_axis_z - az_table_top_z;     // DERIVED
assert(column_h > 0, "riser_rise is shorter than its own azimuth stage");
echo(str("LAYOUT: base r ", base_plate_r, ", table r ", az_table_r,
         ", column h ", column_h, ", tilt axis z ", tilt_axis_z,
         ", payload face z ", payload_face_z));


// =====================================================================
// 10. THE TRIPOD INTERFACE -- pegs, a big thread, and a hand nut
// =====================================================================
// The tripod has no mount piece on its head at all. What it has, MEASURED
// by eva 2026-09-03 and confirmed against a backlit top-down photo, is a
// single disc with FOUR holes: one central bore and three small ones at
// 120 degrees around it.
//
//   38mm disc, 12mm centre bore, three 4mm holes at 120 degrees, and
//   1.7mm of web at the narrowest point between a small hole's edge and
//   the centre bore's edge.
//
// The web is what pins the bolt circle, and it is the only practical way
// to get it: a bolt circle is awkward to caliper, a web between two edges
// is easy. centre-to-centre = 12/2 + 1.7 + 4/2, so the circle is 19.4mm
// across. DERIVED from the measurement, never typed in. The photo agrees
// qualitatively -- the small holes read as roughly a third the centre
// bore's diameter and sit about half a small-hole width off its edge --
// but that is a LOOK, not a measurement, and it is recorded as such.
//
// HOW IT ATTACHES (eva's design, and it is better than the shoe this
// replaces). Three POSTS on the riser's own underside drop into the three
// small holes and take all the torque. A single big THREAD passes down
// through the centre bore. A hand NUT threads up onto it from below and
// pulls the plate against the riser. No separate shoe, no captured
// fasteners, and the anti-rotation is three posts on a 19.4mm circle
// instead of friction under one screw.
tripod_plate_d   = 38.0;   // MEASURED (eva, 2026-09-03)
tripod_bore_d    = 12.0;   // MEASURED -- the centre bore
tripod_hole_d    = 4.0;    // MEASURED -- the three small holes
tripod_web       = 1.7;    // MEASURED -- narrowest web, small-hole edge
                           // to centre-bore edge
tripod_hole_n    = 3;      // MEASURED -- at 120 degrees
tripod_bolt_r    = tripod_bore_d / 2 + tripod_web + tripod_hole_d / 2;
                           // DERIVED -- 9.7mm, a 19.4mm circle
assert(tripod_bolt_r + tripod_hole_d / 2 < tripod_plate_d / 2,
       str("the derived bolt circle runs off the edge of the plate. ",
           "One of the four measurements it comes from is wrong."));

// THE PLATE STANDS PROUD, by 2-3mm (eva, 2026-09-03). The backlit photo
// read the other way -- it looked like a disc at the bottom of a well in
// the casting -- and an earlier version of this file grew a locating
// spigot to reach down into that well. There is no well. A photograph is
// not a caliper, and this is the second thing in this directory that a
// picture got backwards.
//
// Proud is the easy case and it needs no feature at all: the riser's
// underside is FLAT and bears on the plate, and its 136mm rim floats 2-3mm
// clear of the casting around it. One bearing face, statically
// determinate. A part that tried to touch both the plate and the casting
// would rock on whichever came out proud.
tripod_plate_proud = 2.0;  // MEASURED-ish (eva: "2 or 3 mm") -- NOT used
                           // as a dimension anywhere, because nothing has
                           // to reach it. Recorded so the next person does
                           // not reinvent the spigot: this is the number
                           // that says they should not.

// The posts. They locate and they carry torque; they do NOT clamp.
post_d           = tripod_hole_d - 2 * clearance;    // DERIVED -- 3.5
post_proud       = 1.0;    // CHOSEN -- how far a post stands below the
                           // plate once seated. Deliberately positive and
                           // small: a post that stops SHORT of the plate's
                           // underside only half-engages, and half a peg
                           // is where the torque this joint exists to take
                           // would start working it loose. Overshooting
                           // costs nothing, because the nut is relieved.
tripod_plate_t   = 4.0;    // MEASURED (eva, 2026-09-03) -- "the disk ...
                           // should be ~4mm thick". This is what sets peg
                           // engagement: the pegs are sized TO the plate,
                           // about 4mm of engagement, rather than to a
                           // round number.
post_len         = tripod_plate_t + post_proud;   // DERIVED

// The thread. Big, coarse and printed: coarse because a fine printed
// thread is a row of unsupported ridges, and big because it has to be
// worth gripping by hand. It must pass THROUGH the 12mm centre bore, so
// its major diameter is capped by that and not by preference.
stud_thread_d    = 10.0;   // CHOSEN -- major dia, under tripod_bore_d
stud_pitch       = 2.0;    // CHOSEN -- coarse, for printability
assert(stud_thread_d + 1.0 <= tripod_bore_d,
       "the stud thread will not pass through the tripod's centre bore");
stud_len         = tripod_plate_t + 12.0;   // DERIVED -- reach
                   // through the plate plus real engagement below it

// The hand nut. A cylinder with the same lobed grip the knobs use, an
// internal thread, and an annular relief in its TOP face so the three
// posts -- which stand post_proud below the plate -- never touch it.
// Without that relief the nut bears on three post ends instead of on the
// plate, which is a tripod mount held together by three point contacts.
nut_d            = 34.0;   // CHOSEN -- grip diameter
nut_h            = 14.0;   // CHOSEN
nut_relief_r0    = tripod_bolt_r - tripod_hole_d / 2 - 1.0;  // DERIVED
nut_relief_r1    = tripod_bolt_r + tripod_hole_d / 2 + 1.0;  // DERIVED
nut_relief_h     = post_proud + 1.5;                         // DERIVED --
                   // margin over the nominal protrusion, because the
                   // plate thickness it derives from is a "~4mm" and the
                   // relief is the cheapest place to absorb that. If the
                   // plate is really 3mm the pegs stand 2mm proud and
                   // this still clears them.
assert(nut_relief_r0 > stud_thread_d / 2 + 1.2,
       "the hand nut's post relief breaks into its own thread");
assert(nut_relief_r1 < nut_d / 2 - 3.0,
       "the hand nut's post relief runs out through its own rim");
// Where the nut actually SITS: threaded up until its top face bears on
// the plate's underside. Not at the stud's far end, which is where an
// earlier version of assembly.scad drew it -- and drawing it there put
// the three posts 0.5mm into the relief's floor, which the checker
// reported as 14 mm3 of interference. It was rationalised, wrongly, as
// thread flanks grazing at an arbitrary phase; measuring the overlap's
// bounding box put it at three lumps of 4.65 mm3 each, at r=9.7, which is
// the post circle exactly. Posed geometry is geometry, and a pose that is
// merely plausible is a pose that measures nothing.
nut_seat_z       = -(nut_h + tripod_plate_t);   // DERIVED
nut_engagement   = stud_len - tripod_plate_t;   // DERIVED
assert(nut_engagement > 8.0,
       str("the hand nut only engages ", nut_engagement, "mm of stud"));
assert(nut_engagement < nut_h,
       "the stud bottoms out in the hand nut before the nut reaches the plate");

echo(str("TRIPOD: bolt circle ", 2 * tripod_bolt_r, " mm (derived from a ",
         tripod_web, " mm web), posts ", post_len, " mm, stud M",
         stud_thread_d, "x", stud_pitch, " ", stud_len, " mm"));


// =====================================================================
// 11. THE YOKE -- one separate part, keyed into the column
// =====================================================================
// eva's split, and the second version of it. The first attempt broke off
// only the +Y saddle; the right cut is the WHOLE yoke -- both tines, both
// gussets, the trunnion, the gear pin. Everything the tilt stage and the
// gears touch is then one part, and the column below it is a plain tower
// with a slot in the top.
//
// It is a better cut for three separate reasons:
//   - printing. As part of the column the yoke is a 160mm-wide crossbar
//     growing sideways off a 125mm tower, which is all overhang. Alone it
//     lies flat.
//   - the interface stops straddling the joint. With only the saddle
//     split off, the tilt axis ran across a printed seam: one seat on the
//     column, one on a bolted-on arm, and any error in that joint went
//     straight into axis alignment. Both seats on ONE part means the span
//     between them is a printed dimension, not an assembly dimension.
//   - the column becomes something with no features to get wrong.
//
// The joint is a plain rectangular blade dropping into a plain
// rectangular slit cut clean through the column. No keying feature: eva's
// call, and it is the right one for a part that is hand-affixed anyway.
// An earlier version chamfered one bottom corner as a key, which bought a
// theoretical protection against installing backwards -- a yoke with
// gears on one side and an open saddle on the other is not a part anyone
// fits backwards twice -- at the cost of a feature in the one joint that
// wants to be simple.
//
// The blade fills the slit end to end, so it reads as centred by eye.
// What that does NOT give it is a positive stop in Y: the slit is open at
// both ends, so nothing but the axle and the hand-affixing locates the
// yoke along its own axis. Recorded rather than quietly accepted, because
// it is the one degree of freedom this joint does not constrain.
//
// The male tenon and the female mortise come from ONE module,
// tenon_solid(), with the fit as its argument. That is cad-design rule 3
// applied to a SHAPE rather than to a number: two hand-written copies of
// the same profile is the same duplication defect as two hand-written
// copies of the same dimension, and drifts the same way.
//
// NO FASTENER, per eva: hand-affixed for this run. The tenon is captured
// in X and Y by the mortise walls and in Z by its floor; the one free
// direction is straight up, and the payload's weight is what presses it
// down.
// NO TONGUE. eva, looking at a render: the yoke should not hang a tongue
// below its own base, and the column's inset should come UP to match.
// Both of those -- plus a defect the same render showed -- fall out of
// one change: a FLAT underside.
//
// The gap: the blade used to step up to column_top_z between |y|=15 and
// |y|=17 to clear a column of radius 15, which left a 2mm wide, 18.6mm
// tall notch either side of the tongue. It measured clean on every pair
// in check.py and was obvious the moment anyone looked at an orthographic
// view. Measuring and looking catch different classes of defect, and this
// directory had done a great deal of the former and none of the latter.
//
// Flat-bottomed, there is no tongue and no notch: the part of the blade
// that happens to lie inside the column IS the tenon, and the slit is cut
// to receive it. The depth follows rather than being chosen.
yoke_tenon_h     = column_top_z - yoke_bottom_z;   // DERIVED -- the slit
                   // reaches from the column's top down to the yoke's own
                   // flat underside, and no further
yoke_tenon_up    = 2.0;    // CHOSEN -- how far the cut carries above the
                           // column's top face, so it opens through it
                           // rather than ending exactly on it
saddle_fit       = 0.25;   // CHOSEN -- slip fit on the slit, per side

// Screws through the column's wall into the yoke's flank. eva asked for
// these above the collar grubs. Same pattern as those: the thread is in
// the printed wall and the screw bears on the part it retains.
yoke_screw_d     = 2.5;    // CHOSEN -- M3 self-tapping pilot in PLA
yoke_screw_n     = 2;      // CHOSEN -- one each side, so they pinch the
                           // blade rather than push it off its seat
yoke_screw_z     = (yoke_bottom_z + column_top_z) / 2;   // DERIVED
assert(yoke_screw_z > az_groove_z + 6,
       "the yoke screws would run into the collar groove's grub screws");
assert(column_r - yoke_web_t / 2 - saddle_fit > 4.0,
       str("only ", column_r - yoke_web_t / 2 - saddle_fit, "mm of column ",
           "wall beside the slit to put a thread in."));

// The slit the column loses. A plain box, cut clean through in Y and a
// little past the top face in Z. There is no matching male part to keep
// it in step with any more -- the yoke's flat blade simply passes through
// it -- so this is the only place the joint's shape is stated.
module tenon_solid(fit = 0) {
    w  = yoke_web_t / 2 + fit;
    z0 = yoke_bottom_z - fit;
    z1 = column_top_z + yoke_tenon_up;
    translate([-w, -(column_r + 2), z0])
        cube([2 * w, 2 * (column_r + 2), z1 - z0]);
}


// =====================================================================
// 12. HANDLE STATIONS -- all DERIVED
// =====================================================================
// The two handles are the same component with different numbers. Each is
// a bore over a fixed pin, a collar that sets the gear's standoff, a male
// hex the gear keys onto, a shaft, and a grip.

// --- azimuth: pin runs UP from the pedestal's pocket floor ---
az_handle_z0     = az_pocket_floor;                    // DERIVED -- base
az_collar_l      = az_gear_z0 - az_pocket_floor;       // DERIVED -- 1mm,
                   // and it is the gear's clearance over the pocket floor
az_handle_hex_l  = az_gear_face;                       // DERIVED
az_handle_shaft_l = az_knob_grip_z - az_gear_z1;       // DERIVED
az_handle_bore_l = az_knob_pin_top - az_pocket_floor + 2;   // DERIVED --
                   // past the pin's tip, not to it
az_collar_d      = az_knob_bore_d + 2 * wall;          // DERIVED
assert(az_collar_l > 0.5, "the azimuth gear sits on the pocket floor");

// --- tilt: pin runs OUT from the yoke's drive tine ---
tilt_collar_l    = tilt_gear_standoff;                 // DERIVED -- the
                   // collar IS the standoff that keeps the gear off the
                   // tine's face
tilt_handle_hex_l = tilt_gear_face;                    // DERIVED
tilt_handle_shaft_l = 3.0;                             // CHOSEN
tilt_handle_bore_l = tilt_knob_pin_h + 2;              // DERIVED
tilt_collar_d    = tilt_knob_pin_d + 2 * wall;         // DERIVED
tilt_grip_y      = tilt_arm_y_out
                   - (tilt_collar_l + tilt_handle_hex_l
                      + tilt_handle_shaft_l);          // DERIVED
tilt_grip_end_y  = tilt_grip_y - tilt_knob_h;          // DERIVED
assert(tilt_grip_end_y < tilt_arm_y_out - tilt_knob_pin_h,
       "the tilt grip ends before the pin it sits on does");
