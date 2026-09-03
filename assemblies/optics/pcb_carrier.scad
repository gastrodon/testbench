// Camera carrier — the MOVING half of the prime-focus microscope.
// https://linear.app/gastrodon/document/microscope-camera-design-doc-15a95f836b98
//
// One printed piece combining what used to be two: the PCB mounting face
// and the optical tube. The tube slides in the base's sleeve bore, so the
// tube-in-sleeve fit IS the linear bearing — there are no guide rods and
// no bushings (an 18mm tube in an 18.6mm bore over 56mm of engagement
// constrains far more than two 4mm rods, and the earlier bushings drove
// straight through the tube anyway).
//
// This whole body travels relative to the base. Since the base holds the
// 150x objective, moving it changes the sensor-to-objective distance —
// which is the focus.
//
// The camera mounts by its OWN M12 lens thread, not by the two PCB
// screws. The webcam's lens holder is already a female M12x0.5 concentric
// with the sensor, so screwing into it references the carrier to the
// optical axis directly. The two clearance holes it replaces were the
// only features doing that job before, and they did it loosely — two
// holes locate a part in translation but leave it free to rotate and
// carry any error in their own spacing straight into sensor tilt.
//
// The 19x55 board is still cantilevered off the holder exactly as it is
// in the webcam; nothing carries the board itself.

include <params.scad>
include <lib/BOSL2/std.scad>
include <lib/BOSL2/gears.scad>
include <lib/BOSL2/threading.scad>   // threaded_rod() for the M12 boss


// --- M12 boss ----------------------------------------------------------
//
// Diameter is NOMINAL, settled by print: a coupon carrying 11.88 and
// 11.68 went into the real holder and 11.88 threads perfectly while 11.68
// slips. See params.scad — do not pre-shrink this.
//
// Length: holder_h is the holder's full 10mm depth, but the boss does not
// need all of it and a shorter thread is a shorter tip-down print. 7mm is
// 14 turns at 0.5 pitch, far more than enough to seat.
// boss_thread_len comes from params.scad — it trades directly against
// tube_len_nominal to hold the focus range fixed, so the two cannot live
// in different files.

// LEAD-IN RELIEF. This thread prints TIP-FIRST on the bed — the part goes
// face-down so the boss's free end is the first layer — which means the
// threads that must start the screw are exactly the ones carrying
// elephant foot. The coupon that validated the diameter printed the other
// way up, tip in free air, so it says nothing about this end.
//
// So the first turn is deliberately cut back to a plain cone. It is
// sacrificial: it centres the boss in the holder and gives the real
// threads a clean start, and any first-layer squish lands on a feature
// that was never going to carry thread anyway.
//
// Flipping the part instead is worse, not better: mouth-down puts the
// squish on the tube's 0.3mm/side bearing fit — the one dimension with a
// hard budget and the one whose failure hides until final assembly — and
// drops the rack into the top half of an 85mm print.
boss_lead_len = 1.0;
boss_lead_taper = 1.2;    // radial cut-back at the very tip

// The cone that carries the tube up into the thread. Radius has to fall
// from the tube's 9mm to the thread's 5.94mm, so:
// carrier_tube_od from params, NOT the local tube_od alias — that is
// assigned further down this file, and OpenSCAD evaluates in order, so
// using it here yields undef. It did: taper_h went undef, the cone
// vanished, and the part still rendered watertight at the wrong height
// with the radius stepping straight from tube to thread. Read from the
// source of truth and the ordering cannot bite.
taper_dr = (carrier_tube_od - lens_thread_d) / 2;
taper_h  = taper_dr * tan(carrier_taper_angle);

// Everything above the tube's top, which is z=0. FILE SCOPE because
// pcb_carrier_printable() needs it too — it once said face_t + boss_h,
// and when boss_h was deleted with the screw bosses that became undef,
// the translate silently did nothing, and the part rendered upside down
// with most of it below the bed. No error.
boss_total = taper_h + boss_thread_len;

// The old two-screw bosses are gone with the holes. Worth recording why
// beyond "the thread is better": printed face-down they made the first
// 2.2mm of this part TWO DISCONNECTED ISLANDS, 5.4mm across, 14.6mm
// apart, each anchored by ~23mm2 of bed contact and not tied together
// until the face plate bridged them ~15 layers up — with an 85mm, 12.5cm3
// tower to come. A single central boss is one island and a far better
// footprint.

tube_od = carrier_tube_od;
tube_id = tube_od - 2 * wall;
tube_len = carrier_tube_len;

aperture_d = tube_id;                  // clear path down the tube itself

// The bore THROUGH THE BOSS cannot be the tube's 13.2mm — the M12 thread
// is only 11.88mm across, so boring the tube's aperture straight through
// deletes the boss entirely. (It did: the part rendered 82.6mm tall
// instead of 89.6, watertight and single-bodied, with no error. Only
// checking the height against what it should be caught it.)
//
// 9mm matches the light bore m12_coupon.scad already proved printable at
// this thread, and leaves ~0.9mm of wall at the thread root. It vignettes
// nothing: the objective's own front aperture is 3.4mm.
boss_bore_d = 9;

// Rack runs the travel axis on the -Y side, standing off the tube on a
// fin. rack_y comes from params.scad — the base's pinion bearings must
// agree with it.
// rack_circ_pitch, rack_teeth and rack_len come from params.scad — the
// base mount has to cut a travel slot to exactly this length, so the
// number cannot live in only one of the two files.
rack_z_center = -rack_len / 2;         // hangs down from the face
fin_t = gear_thickness;                // fin is as wide as the rack

module mounting_boss() {
    // The tube runs straight up into the thread through a cone. There is
    // no flat plate: nothing needed one. The board hangs off the camera's
    // own holder exactly as it does in the webcam, so the plate was
    // carrying nothing but itself — and it was a wide flat shelf standing
    // proud of both the tube and the thread, which is mass, an edge to
    // catch, and a large flat overhang on the bed.
    //
    // The thread is generated ON the cone rather than cut into it:
    // threaded_rod() with internal=false is the male form, and it has to
    // be unioned in before the bore is taken out, or the bore would be
    // refilled the same way base_mount's objective bore once was.
    difference() {
        union() {
            // tube -> thread, self-supporting at carrier_taper_angle
            cylinder(d1 = carrier_tube_od, d2 = lens_thread_d, h = taper_h);
            // Sunk 0.6mm INTO the cone, not butted at 0.01mm. A
            // hundredth of a millimetre is tangency, not intersection,
            // and CGAL returns it as a separate body — watertight,
            // correct height, right thread diameter, and in TWO PIECES.
            translate([0, 0, taper_h - 0.6])
                threaded_rod(d = lens_thread_d, l = boss_thread_len + 0.6,
                             pitch = lens_thread_pitch, internal = false,
                             bevel2 = true, blunt_start1 = false,
                             anchor = BOTTOM);
        }
        // Sacrificial lead-in: cone the tip back so the first threads to
        // enter the holder are not the ones the bed squashed. Cut as
        // (oversize cylinder MINUS a cone) so it removes only what lies
        // outside the cone — subtracting a plain cylinder takes the whole
        // tip off, which is what the first attempt did.
        translate([0, 0, boss_total - boss_lead_len - 0.01])
            difference() {
                cylinder(d = lens_thread_d + 4, h = boss_lead_len + 0.02);
                cylinder(d1 = lens_thread_d + 0.02,
                         d2 = lens_thread_d - 2 * boss_lead_taper,
                         h = boss_lead_len + 0.02);
            }
        // Light path, taken LAST so nothing can refill it. The tube's own
        // 13.2mm bore stops at z=0; this carries 9mm the rest of the way,
        // which is all the thread's wall can spare.
        translate([0, 0, -1])
            cylinder(d = boss_bore_d, h = boss_total + 2);
    }
}

module carrier_tube() {
    // Hangs down from the face into the base sleeve.
    difference() {
        // Chamfer the tube's free end: it is the leading edge entering
        // the base bore, and a square lip catches on the lead-in.
        translate([0, 0, -tube_len])
            cyl(d = tube_od, h = tube_len + 0.01, anchor = BOTTOM,
                chamfer1 = 1.0);
        // Stops at z=0, the face's underside. Running it 1mm INTO the
        // face (as it used to) put a 13.2mm hole through a plate that has
        // to carry an 11.88mm boss — the boss then floated over the hole
        // with nothing to bond to, and the part came out watertight, the
        // right height, and in two pieces.
        translate([0, 0, -tube_len - 1])
            cylinder(d = tube_id, h = tube_len + 1);
    }
}

module rack_fin() {
    // Ties the rack to the tube. Spans from inside the tube wall out to
    // the rack's backing so there is real volumetric overlap at both
    // ends rather than tangent contact.
    // Both ends run in -Y, so the outer edge is the LOWER y. Ordering
    // these the other way round yields a negative cube extent, which
    // OpenSCAD rejects outright rather than silently mis-drawing.
    fin_inner = -(tube_od / 2 - 1);          // inside the tube wall
    fin_outer = rack_y + rack_backing;       // into the rack's backing
    translate([-fin_t / 2, fin_outer, rack_z_center - rack_len / 2])
        cube([fin_t, fin_inner - fin_outer, rack_len]);
}

// PRINT-ONLY, sacrificial. As modelled, the fin (and the rack riding on
// it) appears off the round tube at full depth in one step -- a flat
// shelf with nothing under it, printed_len_z (Z) mapping to the rack's
// travel axis and the whole fin cross-section arriving at once. That's a
// 90-degree overhang from the tube surface, not a taper.
//
// This hulls the fin's own bottom cross-section up against a sliver
// pinned at fin_inner (the tube wall) one fin-depth below it, so the
// added wedge's outer face runs at 45 degrees -- self-supporting -- from
// the tube surface up to the real fin footprint. It is oversized on
// purpose: it bulges past the tube's true OD over that stretch, which is
// exactly the region the base's sleeve bore expects a plain cylinder, so
// this needs to be pared back by hand to true OD before the carrier goes
// in the sleeve. The true tooth profile (pressure angle) is untouched --
// this only fills air that was empty before, it doesn't reshape a tooth.
module rack_fin_lead_in() {
    fin_inner = -(tube_od / 2 - 1);
    fin_outer = rack_y + rack_backing;
    fin_depth = fin_inner - fin_outer;       // same reach as rack_fin()
    z_top = rack_z_center - rack_len / 2;    // rack_fin()'s own bottom
    z_bot = z_top - fin_depth;               // 45 deg: ramp run == reach
    hull() {
        translate([-fin_t / 2, fin_inner - 0.01, z_bot])
            cube([fin_t, 0.01, 0.01]);
        translate([-fin_t / 2, fin_outer, z_top - 0.01])
            cube([fin_t, fin_inner - fin_outer, 0.01]);
    }
}

module focus_rack() {
    // length +X -> +Z (travel), teeth +Z -> -Y (outward, toward the
    // pinion), thickness +Y -> -X. See the note in git history: an
    // earlier rotate([90,0,90]) put the LENGTH along Y instead.
    translate([0, rack_y, rack_z_center])
        rotate([0, -90, 90])
            rack(mod = gear_mod, teeth = rack_teeth,
                 thickness = gear_thickness,
                 pressure_angle = gear_pressure_angle, anchor = CENTER);
}

module pcb_carrier() {
    // cable_relief() is gone with the plate it was cut into — it was a
    // zip-tie slot so a tugged USB cable torqued the mount rather than
    // the board. That strain path is now unhandled; if it matters, the
    // slot wants to come back in the tube wall, not on a new plate.
    union() {
        mounting_boss();
        carrier_tube();
        rack_fin();
        rack_fin_lead_in();
    }
    focus_rack();
}
// Print orientation: PCB face DOWN on the bed, telescope tube UP — the
// tube then prints as a plain vertical cylinder with no overhang, and
// the face's flat side (which the board bolts to) is the bed-side
// surface, which is the flattest one a printer makes.
//
// The flip lives here rather than in the build so the offset uses this
// file's own boss height instead of a magic number copied elsewhere.
module pcb_carrier_printable() {
    // AS MODELLED — thread UP, tube mouth on the bed. No flip.
    //
    // This is the opposite of how it printed before, and it trades one
    // risk for another deliberately. Thread-up means the M12 threads,
    // including the lead-in that has to start the screw, print in free
    // air with no elephant foot — which matters more now the thread is
    // 21mm and its whole job is reaching into a recessed hole. The cost
    // is that the tube's open mouth becomes the first layer: an 18/13.2
    // annulus, about 118mm^2, carrying a 90mm tower. That wants a brim,
    // and it puts first-layer squish on the 0.3mm/side bearing surface.
    translate([0, 0, tube_len])
        pcb_carrier();
}

pcb_carrier();
