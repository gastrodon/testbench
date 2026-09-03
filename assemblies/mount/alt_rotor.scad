// ALT ROTOR -- the 160T altitude wheel and its integral stepped axle.
//
// Kinematic role (cad-design rule 6): rigidly attached to the TELESCOPE
// and rotates with it about the altitude axis. NOT grounded. Ground is
// base.scad's plate.
//
// eva's design, 2026-09-02. Inserted from the THREADED side, diameter
// decreasing monotonically from wheel to tip:
//
//   [160T wheel]==[1/4-20 thread]==[journal]==[M4 tip]--> lock nut
//                        |              |          |
//               threaded bracket    yoke tine   plain 6.25 hole
//
// It replaces a separate bolt + separate shoulder bushing + printed jaws
// hooking the bracket edge for anti-rotation. Three things improved at
// once:
//
//   1. TORQUE GOES THROUGH A THREAD. The old version relied on bolt-clamp
//      friction plus a printed hook, which was the weakest load path in
//      the build. The jaws are gone entirely.
//   2. THE SHOULDER IS INTEGRAL. The step from journal to tip bears on
//      the far bracket's inner face, so clamp load runs
//      thread -> axle -> step -> far bracket and never touches the tine.
//      alt_sleeve.scad is deleted; this is its job now. Without that step
//      the lock nut squeezes the tine and the altitude axis seizes -- and
//      a seized axis interferes with nothing and passes every geometric
//      check ever written.
//   3. IT RESOLVED THE 6.25mm BLOCKER. A 1/4-20 shank does not fit the
//      measured plain hole. Entering from the threaded side means only
//      the 4mm tip ever visits that hole.
//
// The thin sections carry no drive torque: the thread sits immediately
// inboard of the wheel, so torque transfers to the telescope right there.
// Journal and tip see bending only, over a 16.5mm span, from a scope of
// order 1-2kg -- roughly 11 MPa against PLA's ~50, so ~4x margin.
//
// FRAME (rule 5): local, wheel axis along +Z, wheel centred on Z=0. Axle
// grows toward -Z, which is inboard. assembly.scad does all posing.

include <params.scad>
use <gt2.scad>

rotor_face_z = -gt2_envelope_h() / 2;   // inboard face of the wheel

// Axle stations, measured from the TINE'S CENTRE PLANE outward -- not
// chained off the hub by running subtraction.
//
// Chaining was wrong and the checker caught it: an extra 1.5mm of thread
// run-out pushed the 6.35mm thread 1.5mm into the bracket gap, where the
// tine's 5.5mm bore is. 9.9 mm3 of thread inside the bearing bore, and
// the tine would not have gone on. Anchoring each station to the real
// feature it mates with makes that unrepresentable: the journal IS the
// gap, the thread IS the bracket.
z_tine_c        = -alt_rotor_offset_y;                  // tine centre plane
z_journal_out   = z_tine_c + bracket_gap / 2;           // near bracket face
z_journal_in    = z_tine_c - bracket_gap / 2;           // far bracket face
z_thread_out    = z_journal_out + bracket_t;            // bracket outer face
z_tip_end       = z_journal_in - axle_tip_len;

module alt_rotor() {
    assert_fastener_fits();
    assert(is_num(axis_teeth), "alt_rotor: params.scad not included");
    assert(rotor_hub_d > alt_bolt_major + 2 * wall,
           "alt_rotor: the tube's swept clearance has squeezed the hub down \
past the thread it has to carry. tube_bottom_above_pivot is the binding \
constraint -- measure it.");
    assert(rotor_hub_d <= bracket_free_r * 2,
           "alt_rotor: hub fouls telescope structure on the bracket face");

    union() {
        difference() {
            union() {
                gt2_pulley(axis_teeth);              // wheel, centred Z=0
                // Hub: stands the wheel off clear of the tube.
                translate([0, 0, z_thread_out])
                    cylinder(h = rotor_hub_h + 1, d = rotor_hub_d);
            }
            // Lighten the wheel. A solid 102mm disc is a lot of filament
            // for a part carrying very little load -- 8:1 off a NEMA 17 is
            // enormous torque margin against a 50mm toy refractor.
            for (i = [0 : 4])
                rotate([0, 0, i * 72])
                    translate([axis_od / 4 + 4, 0, 0])
                        cylinder(h = 60, d = 16, center = true);
        }

        // Consistency check: walking out from the tine must land exactly
        // where the hub ends. If these ever disagree, one of the two walks
        // has drifted from the other (rule 3).
        assert(abs(z_thread_out - (rotor_face_z - rotor_hub_h)) < 1e-6,
               "alt_rotor: axle stations and alt_rotor_offset_y disagree");

        // 1/4-20 male thread into the brass insert. Modelled as a plain
        // cylinder at MAJOR diameter, not as cut threads: this is the one
        // load-bearing thread in the mechanism and it gets settled by
        // print on axle_coupon.scad, the same way the microscope build
        // settled its M12 and the way the GT2 flank is being settled.
        // Modelling a thread form here would look authoritative and prove
        // nothing.
        translate([0, 0, z_journal_out])
            cylinder(h = bracket_t, d = alt_bolt_major);

        // Journal: what the yoke tine actually rides on. Capped by the
        // insert's bore, because it has to pass through it on the way in.
        translate([0, 0, z_journal_in])
            cylinder(h = bracket_gap, d = axle_journal_d);

        // M4 tip through the plain hole, protruding for the lock nut. The
        // step up to the journal is the shoulder that keeps the tine free.
        //
        // Hemispherical nose (eva): this axle has to feel its way blind
        // through the insert, then the tine bore, then the far bracket --
        // three coaxial holes with the telescope in the way of seeing any
        // of them. A domed tip self-centres on each lip instead of
        // catching on it. Costs nothing and it is the difference between
        // assembly being fiddly and being obvious.
        translate([0, 0, z_tip_end])
            cylinder(h = axle_tip_len, d = axle_tip_thread);
        translate([0, 0, z_tip_end]) sphere(d = axle_tip_thread);
    }
}

alt_rotor();
