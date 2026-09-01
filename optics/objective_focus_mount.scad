// Objective focus mount — part 2 of the prime-focus microscope camera build.
// https://linear.app/gastrodon/document/microscope-camera-design-doc-15a95f836b98
//
// Holds the 150x objective cell (real 9mm printed thread, via BOSL2) at the
// specimen end of a telescoping tube: an inner tube slides inside a fixed
// outer sleeve and locks with a clamp screw. This stands in for the real
// rack-and-pinion focus mechanism (that lives on pcb_carrier.scad instead —
// see the design doc: image-side focus is M^2 easier than moving this end)
// — good enough for the empirical focus test and early bench use, since
// tube_len is not yet known (obj_f is assumed, see params.scad).
//
// The outer sleeve breaks out to 2 LEGO Technic pins so it can plug
// straight into a Technic beam for a provisional frame, ahead of the real
// frame part.

include <params.scad>
include <lib/BOSL2/std.scad>
include <lib/BOSL2/threading.scad>
include <lib/Technic.scad/Technic.scad>

$slop = 0.1; // FDM print clearance for the internal thread mask, mm; tune per-printer

obj_bore_depth = obj_thread_engage + 2; // + lead-in beyond the measured engagement

inner_od = 18;                     // stays well under the r12 (24mm dia) ring-light cap
inner_id = inner_od - 2 * wall;
inner_len = tube_len_nominal;

sleeve_len = 40;                   // fixed portion, mounts to frame (frame TBD)
sleeve_id = inner_od + 2 * clearance;
sleeve_od = sleeve_id + 2 * wall;

slot_w = 2;
clamp_screw_d = 3.2;               // M3 clearance
clamp_nut_flat = 5.6;              // M3 hex nut across-flats + slop
clamp_nut_h = 3;

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

module inner_tube() {
    difference() {
        cylinder(d = inner_od, h = inner_len);
        translate([0, 0, -1])
            cylinder(d = inner_id, h = inner_len + 2);
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

module outer_sleeve() {
    // Bore and cutouts are subtracted LAST, after the breakout is
    // unioned on — hull() fills its own concavity, so subtracting the
    // bore first would let the flare bridge across the light path.
    difference() {
        union() {
            cylinder(d = sleeve_od, h = sleeve_len);
            translate([0, 0, sleeve_len / 2])
                technic_breakout_solid();
        }

        translate([0, 0, -1])
            cylinder(d = sleeve_id, h = sleeve_len + 2);

        // slot the full length so the sleeve can clamp down on the inner tube
        translate([-slot_w / 2, 0, -1])
            cube([slot_w, sleeve_od / 2 + 1, sleeve_len + 2]);

        // clamp screw, radial, near the open (specimen) end
        translate([0, -sleeve_od / 2 - 1, sleeve_len - 8])
            rotate([-90, 0, 0])
                cylinder(d = clamp_screw_d, h = sleeve_od + 2);

        // captured nut trap on the far side
        translate([0, sleeve_od / 2 - clamp_nut_h + 0.4, sleeve_len - 8])
            rotate([90, 0, 90])
                cylinder(d = clamp_nut_flat, h = clamp_nut_h + 0.2, $fn = 6);
    }
}

// Lay out separately so both print without support: inner tube upright
// (bore opening down), sleeve beside it.
translate([-sleeve_od - technic_pin_spacing - 20, 0, 0])
    inner_tube();

outer_sleeve();
