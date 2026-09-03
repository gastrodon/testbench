// ROLLER WHEEL -- dryer drum support roller, as measured off the real part.
//
// EXTERNAL PART. Nothing in this directory gets printed: these are bought
// or salvaged objects, modelled so a design can be built AROUND them. The
// job of this file is to be the honest envelope and the honest interface
// of a thing we do not control, not to be a good part -- so "solid where
// the real thing has spokes" is a deliberate, conservative choice, and
// every number below is either a caliper reading or is tagged as not one.
//
// SOURCE: engineering-drawings field sheet "Roller Wheel — Field Sheet"
// (wheel-field-sheet.html, PRESET, mm, marked "recorded"). Letters below
// are that sheet's letters, kept verbatim so a re-measure can be diffed
// against this file letter by letter.
//
// Deliberately self-contained -- no params.scad, no BOSL2, nothing about
// telescopes -- same rule as ../motors/nema17.scad. A dryer roller is not
// a feature of any one assembly here.

// ---------------------------------------------------------------------
// MEASURED (eva, field sheet, mm)
// ---------------------------------------------------------------------
roller_tire_od    = 80.1;   // A  outer diameter of the full wheel
roller_hub_od     = 54.1;   // B  plastic hub face diameter -- tread starts here
roller_bore_d     = 17.8;   // C  ring-bushing bore; the shaft rides in THIS
roller_bushing_od = 20.5;   // D  ring-bushing outer diameter
roller_tread_t    = 13.0;   // E  tread thickness, radial

// F -- overall width, face to face. NOT a caliper reading: the sheet says
// it was inferred from the axle's stopper span, and flags it as "confirm
// with calipers if it matters". It matters for any pocket sized to hold
// this wheel, so treat a design that depends on it as unverified until
// someone puts calipers across the faces.
roller_width      = 32.85;  // F  INFERRED, not measured

// G -- the washer that sits against the wheel on the axle. A SEPARATE
// part, not a feature of the wheel; it is here because the sheet recorded
// it as the cross-check on F and anything reproducing the axle stack
// needs it.
roller_washer_od  = 22.2;   // G  MEASURED

// ---------------------------------------------------------------------
// The one cross-check the sheet's two independent readings allow: tread
// thickness was measured directly (E) AND is implied by the two diameters
// ((A-B)/2). They agree to the digit, so the tire OD, hub OD and tread
// thickness are mutually confirming rather than three separate hopes.
// Asserted rather than remarked on, so a future re-measure that breaks the
// agreement fails loudly instead of leaving a stale comment behind.
// ---------------------------------------------------------------------
assert(abs((roller_tire_od - roller_hub_od) / 2 - roller_tread_t) < 0.05,
       str("roller_wheel: tread thickness E=", roller_tread_t,
           " disagrees with (A-B)/2=", (roller_tire_od - roller_hub_od) / 2,
           ". Two readings that used to agree no longer do -- re-measure ",
           "before trusting either."));

assert(roller_bushing_od < roller_hub_od,
       "roller_wheel: the ring bushing is wider than the hub it sits in.");

roller_fn = 96;

// ---------------------------------------------------------------------
// NOT MEASURED, and therefore NOT MODELLED as anything but solid:
//
//   * the hub web is SPOKED on the real part (eight of them in the sheet's
//     face view). No letter was assigned to a spoke, so there is no width,
//     count or depth to model. Solid is the conservative direction for the
//     only questions this file exists to answer -- clearance and envelope
//     -- and it is wrong in the safe direction for mass.
//   * the sheet's side view hints the tread band may be narrower than the
//     hub. Nothing lettered it either, so `tread_w` defaults to the full
//     width and is left as an argument for whoever measures it.
//   * the bushing's axial length. Assumed full width; if it is a short
//     press-in collar instead, only its own module is wrong, not the bore.
// ---------------------------------------------------------------------

// The wheel, standing on the axle axis: Z is the axle, and the origin is
// the wheel's MID-WIDTH plane, not a face. A roller is symmetric and gets
// positioned by its centreline in every assembly that holds one; anchoring
// it to a face means every caller writes the same +F/2 by hand and one of
// them eventually writes it as -F/2.
module roller_wheel(tread_w = roller_width, with_bushing = true) {
    assert(tread_w <= roller_width,
           "roller_wheel: tread cannot be wider than the wheel.");
    difference() {
        union() {
            // Hub and tread are both drawn as SOLID discs that overlap
            // through the whole hub, rather than as a disc plus a ring
            // tangent to it. A ring whose bore exactly equals the hub OD
            // touches it across a cylinder of zero thickness, which CGAL
            // renders as non-manifold garbage (AGENTS.md: union needs
            // volumetric overlap, not contact). The bore subtracted below
            // is what makes it a wheel.
            cylinder(h = roller_width, d = roller_hub_od,  center = true,
                     $fn = roller_fn);
            cylinder(h = tread_w,      d = roller_tire_od, center = true,
                     $fn = roller_fn);
        }
        // `with_bushing` picks WHICH BORE is exposed -- the bushing's own
        // 17.8 running bore, or the 20.5 seat it presses into if it has
        // been pulled (or is being drawn separately by the caller). The
        // bushing is deliberately NOT unioned in as a second solid: its OD
        // is exactly the seat diameter, so the two would meet across a
        // zero-thickness cylinder, which is the non-manifold trap in
        // AGENTS.md. Same geometry, one body, no coincident faces.
        cylinder(h = roller_width + 2,
                 d = with_bushing ? roller_bore_d : roller_bushing_od,
                 center = true, $fn = roller_fn);
    }
}

// The ring bushing on its own -- a separate component of the real wheel,
// and the one that actually defines the running fit.
module roller_wheel_bushing(len = roller_width) {
    difference() {
        cylinder(h = len, d = roller_bushing_od, center = true,
                 $fn = roller_fn);
        cylinder(h = len + 2, d = roller_bore_d, center = true,
                 $fn = roller_fn);
    }
}

// Swept envelope, for clearance checks that do not care what the wheel is
// made of -- a plain cylinder at tire OD over the full width. Cheaper than
// the real thing and, unlike it, correct even if the spoke web turns out
// to be something other than solid.
module roller_wheel_envelope(clearance = 0) {
    cylinder(h = roller_width + 2 * clearance,
             d = roller_tire_od + 2 * clearance,
             center = true, $fn = roller_fn);
}

// The axle this thing rides on, as a proxy -- drawn at the BUSHING BORE,
// which is the largest shaft that can pass. A real axle is undersized by
// its running clearance; that clearance belongs to whoever specifies the
// axle, not to a file describing the wheel.
module roller_wheel_axle(len = 80) {
    cylinder(h = len, d = roller_bore_d, center = true, $fn = roller_fn);
}

// The washer off the axle stack (G). Thickness was never measured, so it
// is an argument with no default worth defending.
module roller_wheel_washer(t) {
    assert(!is_undef(t),
           str("roller_wheel_washer: washer thickness was never measured ",
               "(the field sheet only recorded its OD, as letter G). ",
               "Pass one."));
    difference() {
        cylinder(h = t, d = roller_washer_od, center = true, $fn = roller_fn);
        cylinder(h = t + 2, d = roller_bore_d, center = true, $fn = roller_fn);
    }
}
