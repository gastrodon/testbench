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
// The face is deliberately NOT a full rectangle. It only has to reach the
// two M12-holder screws (the only features referenced to the optical
// axis) and carry the tube; the 19x55 board itself is cantilevered off
// those two screws exactly as it is in the webcam.

include <params.scad>
include <lib/BOSL2/std.scad>
include <lib/BOSL2/gears.scad>

face_t = carrier_face_t;
boss_d = holder_screw_d + 3.4;
screw_hole_d = holder_screw_d - 0.3;   // undersized: self-tapping screw bites
boss_h = 2.2;

tube_od = carrier_tube_od;
tube_id = tube_od - 2 * wall;
tube_len = carrier_tube_len;

aperture_d = tube_id;                  // clear path from sensor into the tube

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
    // A bar spanning the two holder screws, with a central aperture the
    // sensor looks through. Rounded so there is no corner to catch.
    difference() {
        union() {
            translate([0, 0, face_t / 2])
                cuboid([carrier_face_w, carrier_face_d, face_t],
                       rounding = 4, edges = "Z");
            for (x = [-holder_screw_span / 2, holder_screw_span / 2])
                translate([x, 0, 0])
                    cylinder(d = boss_d, h = face_t + boss_h);
        }
        translate([0, 0, -1])
            cylinder(d = aperture_d, h = face_t + boss_h + 2);
        for (x = [-holder_screw_span / 2, holder_screw_span / 2])
            translate([x, 0, -1])
                cylinder(d = screw_hole_d, h = face_t + boss_h + 2);
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
        translate([0, 0, -tube_len - 1])
            cylinder(d = tube_id, h = tube_len + 2);
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

pcb_carrier();
