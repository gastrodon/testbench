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

face_t = carrier_face_t;

// --- M12 boss ----------------------------------------------------------
//
// Diameter is NOMINAL, settled by print: a coupon carrying 11.88 and
// 11.68 went into the real holder and 11.88 threads perfectly while 11.68
// slips. See params.scad — do not pre-shrink this.
//
// Length: holder_h is the holder's full 10mm depth, but the boss does not
// need all of it and a shorter thread is a shorter tip-down print. 7mm is
// 14 turns at 0.5 pitch, far more than enough to seat.
boss_thread_len = 7;

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

// Overall height of the face+boss stack, above the face's underside.
// FILE SCOPE because pcb_carrier_printable() needs it too — it used to
// say face_t + boss_h, and when boss_h was deleted with the screw bosses
// that became undef, the translate silently did nothing, and the part
// rendered upside down with most of it below the bed. No error.
boss_total = face_t + boss_thread_len;

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
rack_circ_pitch = PI * gear_mod;
rack_len_min = focus_travel + 2 * rack_engage_margin;
rack_teeth = ceil(rack_len_min / rack_circ_pitch);
rack_len = rack_teeth * rack_circ_pitch;
rack_z_center = -rack_len / 2;         // hangs down from the face
fin_t = gear_thickness;                // fin is as wide as the rack

module mounting_face() {
    // A bar carrying one central M12 boss, with the aperture bored
    // straight through it. Rounded so there is no corner to catch.
    //
    // The thread is generated ON the boss rather than cut into a
    // cylinder: threaded_rod() with internal=false is the male form, and
    // it must be unioned into the plate before the aperture is taken out,
    // or the bore would be refilled by the boss the same way base_mount's
    // objective bore once was.
    difference() {
        union() {
            translate([0, 0, face_t / 2])
                cuboid([carrier_face_w, carrier_face_d, face_t],
                       rounding = 4, edges = "Z");
            // Male M12x0.5, rising from the face toward the camera.
            //
            // Sunk 0.6mm INTO the plate, not butted against it at
            // 0.01mm. A hundredth of a millimetre is tangency, not
            // intersection, and CGAL returns it as a separate body — the
            // part rendered watertight, correct height, right thread
            // diameter, and in TWO PIECES. Extend the rod by the same
            // 0.6 so the exposed length is still boss_thread_len.
            translate([0, 0, face_t - 0.6])
                threaded_rod(d = lens_thread_d, l = boss_thread_len + 0.6,
                             pitch = lens_thread_pitch, internal = false,
                             bevel2 = true, blunt_start1 = false,
                             anchor = BOTTOM);
        }
        // Sacrificial lead-in: cone the tip back so the first threads to
        // enter the holder are not the ones the bed squashed. Cut as
        // (oversize cylinder MINUS a cone) so it removes only what lies
        // outside the cone — subtracting a plain cylinder here would take
        // the whole tip off, which is what the first attempt did.
        translate([0, 0, boss_total - boss_lead_len - 0.01])
            difference() {
                cylinder(d = lens_thread_d + 4, h = boss_lead_len + 0.02);
                cylinder(d1 = lens_thread_d + 0.02,
                         d2 = lens_thread_d - 2 * boss_lead_taper,
                         h = boss_lead_len + 0.02);
            }
        // Light path, taken LAST so nothing can refill it. Two diameters:
        // narrow through the boss (all the thread can carry), opening to
        // the tube's full bore once past the face.
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

module cable_relief() {
    // The board is 55mm long on 20mm screw centres, so a tugged USB
    // cable torques the mount through the PCB. A zip-tie slot in the
    // face takes that load instead — compact, unlike the old post.
    for (s = [-1, 1])
        translate([s * (carrier_face_w / 2 - 4), 0, -1])
            cube([2.6, 9, face_t + 2], center = false);
}

module pcb_carrier() {
    difference() {
        union() {
            mounting_face();
            carrier_tube();
            rack_fin();
        }
        cable_relief();
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
    translate([0, 0, boss_total])
        rotate([180, 0, 0])
            pcb_carrier();
}

pcb_carrier();
