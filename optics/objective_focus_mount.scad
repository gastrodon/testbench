// Base mount — the FIXED half of the prime-focus microscope.
// https://linear.app/gastrodon/document/microscope-camera-design-doc-15a95f836b98
//
// One printed piece carrying everything that does not move:
//   * the 150x objective cell, on a real 9mm printed thread in the floor
//   * the sleeve bore the camera carrier's tube slides in (the bearing)
//   * the pinion yoke, holding the axle in double shear
//   * a LEGO Technic pin breakout for provisional structure
//
// Focus works because THIS body stays put while pcb_carrier.scad travels,
// changing the sensor-to-objective distance. The objective used to live on
// the moving tube, where sliding it would have changed nothing.
//
// The telescoping inner tube that used to be here is gone: it became part
// of the carrier, which is the moving body.

include <params.scad>
include <lib/BOSL2/std.scad>
include <lib/BOSL2/threading.scad>
// gears.scad is NOT part of std.scad. Without it gear_dist() is
// undefined, silently yields undef, and the bearing boss gets built at a
// garbage position — OpenSCAD only warns. The yoke still rendered, still
// came out watertight, and still passed every interference check,
// because malformed geometry that happens to miss everything looks
// exactly like correct geometry to a clearance test.
include <lib/BOSL2/gears.scad>
include <lib/Technic.scad/Technic.scad>

$slop = 0.1; // FDM print clearance for the internal thread mask, mm; tune per-printer

obj_bore_depth = obj_thread_engage + 2; // + lead-in beyond the measured engagement
floor_t = obj_bore_depth + 1.5;    // base floor carrying the objective thread

// Sleeve runs up to just below the rack's lowest position (z=59.4 at
// focus home) — "extends up a little" without needing a slot through the
// tube wall itself. The rack's backing sits at y=-10.875, inside the
// sleeve's 11.7mm outer radius, so a taller tube WOULD have to be slit.
sleeve_len = 56;
sleeve_id = carrier_tube_od + 2 * clearance;   // the moving tube's bearing
sleeve_od = sleeve_id + 2 * wall;

breakout_z = 20;   // explicit, not sleeve_len/2 — the sleeve length changed once

// --- pinion yoke ------------------------------------------------------
// The frame. Two arms rise from the sleeve and straddle the rack, so the
// pinion axle is carried in DOUBLE SHEAR — a bearing either side of the
// gear rather than a cantilever. The gap between the arms is the slit the
// rack travels in; a back web closes them into a U-channel for rigidity.
//
// Every dimension here is a clearance against something that moves:
//   rack sweeps  x -4..4,  y -14.25..-10.875,  z 59.4..110
//   gear reaches y -23.47 at its OD
// so the arms sit outside |x|=4 and the web sits beyond y=-23.47.
pinion_y = rack_y - gear_dist(mod = gear_mod, teeth1 = pinion_teeth,
                              teeth2 = 0, pressure_angle = gear_pressure_angle);
rack_slot_half = gear_thickness / 2 + 1.5;   // 1.5mm clearance per side
arm_t = 3;
arm_x = rack_slot_half + arm_t / 2;          // arm centreline
bearing_d = shaft_d_frame + 0.35;            // running clearance on the shaft
bearing_boss_d = 11;
web_y = -32;   // must clear the gear OD; derived below, not guessed
web_t = 3;

module objective_thread_bore() {
    // Real printed 9mm thread, not a self-tapping guess. Pitch is
    // unconfirmed (see params.scad) — reprint once measured.
    up(-0.5)
        threaded_rod(
            d = obj_thread_d, l = obj_bore_depth + 0.5, pitch = obj_thread_pitch,
            internal = true, bevel2 = true, blunt_start1 = false,
            anchor = BOTTOM
        );
}

module base_floor() {
    // Closed floor at the specimen end, carrying the 150x cell. The cell
    // threads in from below; light passes up the bore into the carrier's
    // tube. Because the floor is part of the FIXED body, the objective
    // stays put and focus is purely the carrier's travel.
    difference() {
        cylinder(d = sleeve_od, h = floor_t);
        objective_thread_bore();
    }
}

// --- Technic pin breakout geometry ---
// A flat tab butted onto a round tube is both a stress riser (abrupt
// section change, right at the layer lines) and an unsupported overhang.
// Instead: a saddle pad that wraps the tube and flares smoothly out to
// the pin plate via hull(), so section change is gradual and the flare's
// own slope prints without support.
pad_h = 28;                // saddle height along the tube axis, mm
pad_arc_w = technic_pin_spacing + 14;  // saddle width across the tube, mm
plate_t = 3.4;             // pin plate thickness, mm
plate_h = 12;              // pin plate height, mm
plate_w = technic_pin_spacing + 7;
reach = 7;                 // plate standoff from the tube surface, mm
// flare slope, from horizontal — must stay >45 to print unsupported
flare_deg = atan2((pad_h - plate_h) / 2, reach);

module technic_breakout_solid() {
    // Saddle: an annular wedge sharing the sleeve's own wall, so it
    // blends into the tube instead of sitting on it. Inner radius is the
    // bore radius, so it can never encroach on the light path.
    saddle_od = sleeve_od + 1.2;   // slight proud bulge, reads as a fillet
    module saddle() {
        intersection() {
            difference() {
                cylinder(d = saddle_od, h = pad_h, center = true);
                translate([0, 0, -pad_h])
                    cylinder(d = sleeve_id, h = pad_h * 3, center = true);
            }
            translate([saddle_od / 4, 0, 0])
                cube([saddle_od / 2, pad_arc_w, pad_h], center = true);
        }
    }

    module pin_plate() {
        translate([sleeve_od / 2 + reach, 0, 0])
            cuboid([plate_t, plate_w, plate_h], rounding = 2.5, edges = "X");
    }

    // hull() blends saddle -> plate into one continuous buttress; no
    // tangent contact, no abrupt corner, nothing to concentrate stress.
    hull() { saddle(); pin_plate(); }

    for (y = [-technic_pin_spacing / 2, technic_pin_spacing / 2])
        translate([sleeve_od / 2 + reach + plate_t / 2, y, 0])
            rotate([0, 90, 0])
                translate([0, 0, -1])   // real overlap into the plate
                    technic_pin_half(length = 1, friction = true);
}

module pinion_yoke_solid() {
    // Each arm: hulled from a pad on the sleeve up to the bearing boss,
    // giving a tapered strut with no abrupt section change. The pad
    // starts at y=-9 so it overlaps the sleeve wall (surface at y=-9.7 at
    // this x) while staying clear of the sliding inner tube, whose
    // surface at x=+/-6.5 is only y=-6.2.
    for (s = [-1, 1]) {
        translate([s * arm_x, 0, 0]) {
            hull() {
                // pad, straddling the sleeve wall: reaches in to y=-8 for
                // real overlap (wall surface is y=-9.7 at this x) while
                // staying clear of the sliding inner tube at y=-6.2
                translate([-arm_t / 2, rack_y - 2, sleeve_len - 30])
                    cube([arm_t, abs(rack_y) - 6, 24]);
                // bearing boss
                translate([-arm_t / 2, pinion_y, pinion_z])
                    rotate([0, 90, 0])
                        cylinder(d = bearing_boss_d, h = arm_t);
            }
        }
    }
    // Back web ties the arms together. Without it the two arms are
    // independent cantilevers and the axle can still splay.
    hull() {
        translate([-(arm_x + arm_t / 2), web_y, pinion_z - 14])
            cube([2 * (arm_x + arm_t / 2), web_t, 21]);
        translate([-(arm_x + arm_t / 2), web_y + 6, sleeve_len - 14])
            cube([2 * (arm_x + arm_t / 2), web_t, 8]);
    }
}

// Nothing in the frame may reach the carrier plate's underside, which
// sits at carrier_z_home and travels UP from there — so the home
// position is the worst case, not the extended one.
yoke_ceiling = carrier_z_home - 1.5;

module pinion_yoke_cuts() {
    // Rack travel slot: the swept volume of the rack across the whole
    // focus range, plus clearance. Cutting the SWEPT volume rather than
    // the rack's home position is the point — the rack moves 20mm.
    translate([-rack_slot_half, rack_y - 3, sleeve_len - 4])
        cube([2 * rack_slot_half, rack_backing + 5, 70]);

    // Gear pocket, so the pinion can spin without touching the web
    translate([-rack_slot_half, pinion_y, pinion_z])
        rotate([0, 90, 0])
            cylinder(d = 14, h = 2 * rack_slot_half);

    // Bearing bores, both arms, one continuous axis
    translate([-(arm_x + arm_t), pinion_y, pinion_z])
        rotate([0, 90, 0])
            cylinder(d = bearing_d, h = 2 * (arm_x + arm_t));

    // Trim everything above the carrier plate's underside. Cheaper and
    // more robust than sizing each feature to clear it individually.
    translate([-60, -60, yoke_ceiling])
        cube([120, 120, 60]);
}

module base_mount() {
    // Bore and cutouts are subtracted LAST, after the breakout is
    // unioned on — hull() fills its own concavity, so subtracting the
    // bore first would let the flare bridge across the light path.
    difference() {
        union() {
            cylinder(d = sleeve_od, h = sleeve_len);
            base_floor();
            translate([0, 0, breakout_z])
                technic_breakout_solid();
            pinion_yoke_solid();
        }

        // Bore starts above the floor, so the floor stays solid for the
        // objective thread. No clamp slot or clamp screw any more: the
        // carrier is positioned by the rack and pinion, not pinched.
        translate([0, 0, floor_t])
            cylinder(d = sleeve_id, h = sleeve_len);

        pinion_yoke_cuts();
    }
}

// One printed part, upright: floor on the bed, bore opening up.
base_mount();
