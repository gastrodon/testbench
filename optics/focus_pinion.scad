// Focus pinion + knob — drives pcb_carrier.scad's integrated rack.
// https://linear.app/gastrodon/document/microscope-camera-design-doc-15a95f836b98
//
// mod/teeth/pressure_angle must match focus_rack() in pcb_carrier.scad
// exactly (all pulled from params.scad) or they won't mesh.
//
// IMPORTANT — mesh distance: the frame must hold this shaft at
// gear_dist(), NOT pitch_radius(), from the rack's pitch line. Below the
// ~17-tooth undercut threshold BOSL2 auto-applies a profile shift, which
// pushes the operating center distance out past the naive pitch radius.
// Using the naive value buries the teeth too deep and the pair binds.
//
// ONE PRINTED PART: knob, cove, shaft, gear and far stub, all rigid.
// There is no axle and no set screw — the shaft is printed integral, so
// nothing can slip on it.
//
// It reads as two features because it is: the gear must sit beside the
// rack, but a knob big enough to turn finely has a radius far larger than
// the gap between the pinion axis and the carrier. A COAXIAL knob sweeps
// straight through the carrier at every position along the shaft
// (measured: 392 mm^3 of interference) — that was never fixable by moving
// it. The knob therefore lives OUTBOARD, past the carrier's edge, on a
// shaft long enough to clear it, which is how real microscope focus
// blocks are built and what decouples knob diameter from any clearance
// constraint. Knob size stays a free choice for tactile fineness.
//
// This header used to describe two separately printed pieces joined by a
// length of 4mm rod. That has not been true since the shaft became
// integral, and params.scad and check.py both already said so — the file
// doing the printing was the one carrying the wrong description.

include <params.scad>
include <lib/BOSL2/std.scad>
include <lib/BOSL2/gears.scad>

knob_h = 10;                // knob_d comes from params.scad
flute_n = 16;

// Distance from the gear's midplane out to the knob's inner face. It
// only has to clear the CARRIER FACE, which is now a 34mm bar rather
// than the old 63mm full-width plate — so the knob comes in from 37.5mm
// to 22mm and the axle shortens with it. A shorter axle is a stiffer
// axle: overhang beyond the outer bearing is a cantilever, and halving
// it cuts the deflection at the knob by roughly eight.
knob_standoff = carrier_face_w / 2 + 5;

shaft_d = shaft_d_frame;
arm_reach = 6;                        // shaft past the gear, through the far bearing

// TIP RADIUS FROM THE GENERATOR, not from mod and teeth.
//
// The old flare was built to 2*(pitch_radius + mod) = 10.5mm. The gear's
// real tip circle is 10.947 — a 12-tooth gear is below the undercut
// threshold, BOSL2 auto-shifts the profile, and a shifted tooth is taller
// than the textbook formula says. So the flare stopped 0.22mm short of
// the tips all the way round and left the exact overhanging ledge it
// existed to remove. Asking the library for the number it actually used
// is the only way this cannot drift.
pinion_profile_shift = auto_profile_shift(teeth = pinion_teeth,
                                          pressure_angle = gear_pressure_angle);
pinion_tip_r = outer_radius(mod = gear_mod, teeth = pinion_teeth,
                            profile_shift = pinion_profile_shift);

taper_rise = pinion_tip_r - shaft_d / 2;
taper_h = taper_rise * tan(pinion_tip_slope);

shaft_to_knob = knob_standoff - pinion_full_w / 2;

// The gear station has to live between the yoke arms, whose inner faces
// sit at +/-rack_slot_half. With the taper mirrored the station is
// symmetric about the rack midplane, so one check covers both ends.
yoke_slot_half = rack_slot_half;   // from params.scad, shared with the mount
gear_station_bottom = pinion_full_w / 2 + taper_h;   // same both ends now
assert(gear_station_bottom <= yoke_slot_half - clearance,
       str("pinion taper fouls the yoke arm: needs ", gear_station_bottom,
           "mm below the rack midplane, only ", yoke_slot_half - clearance,
           " available. Raise pinion_tip_slope or cut pinion_full_w."));

echo(str("pinion tip radius ", pinion_tip_r, " (profile shift ",
         pinion_profile_shift, ")"));
echo(str("tooth taper: ", pinion_tip_slope, " deg from bed, ", taper_h,
         "mm tall at EACH end; station ", pinion_full_w + 2 * taper_h,
         "mm in a ", 2 * yoke_slot_half, "mm slot"));

pinion_mesh_dist = gear_dist(mod = gear_mod, teeth1 = pinion_teeth, teeth2 = 0,
                             pressure_angle = gear_pressure_angle);
echo(str("pinion mesh distance (frame offset from rack pitch line): ",
    pinion_mesh_dist, " mm  [naive pitch_radius would be ",
    pitch_radius(mod = gear_mod, teeth = pinion_teeth), "]"));
echo(str("carrier travel per pinion revolution: ",
    PI * gear_mod * pinion_teeth, " mm"));
echo(str("knob standoff from gear midplane: ", knob_standoff, " mm"));

// SYMMETRIC: the teeth run out into the shaft at BOTH ends.
//
// The lower taper is the one that has to exist — printed knob-down it is
// what holds the teeth up. The upper one is free: a cone that narrows as
// it rises is self-supporting no matter how steep, so mirroring it costs
// nothing in printability and only the axial room to put it in.
module gear_taper_mask() {
    // bottom: shaft opening out to the tip circle
    translate([0, 0, -pinion_full_w / 2 - taper_h])
        cylinder(d1 = shaft_d, d2 = 2 * pinion_tip_r, h = taper_h);
    // middle: full-depth teeth, the band that drives the rack
    translate([0, 0, -pinion_full_w / 2])
        cylinder(d = 2 * pinion_tip_r + 2, h = pinion_full_w);
    // top: closing back down to the shaft
    translate([0, 0, pinion_full_w / 2])
        cylinder(d1 = 2 * pinion_tip_r, d2 = shaft_d, h = taper_h);
}

module focus_gear() {
    // No bore: the gear IS the shaft at this station. A 6mm bore through
    // a 12-tooth mod-0.75 gear would leave 0.56mm of wall at the tooth
    // roots, which is not a gear, it is a crack waiting to happen.
    //
    // Cut a taller blank back to the mask, so the teeth themselves run
    // out into the shaft. Root radius is 3.79 against a 3.0 shaft radius,
    // so the cone leaves the shaft before any tooth material appears and
    // the two stay one continuous solid.
    intersection() {
        spur_gear(mod = gear_mod, teeth = pinion_teeth,
                  thickness = pinion_full_w + 2 * taper_h,
                  pressure_angle = gear_pressure_angle, shaft_diam = 0,
                  anchor = CENTER);
        gear_taper_mask();
    }
}

// The flutes stand slightly proud of knob_d, so the chamfer mask is taken
// at their outer diameter — cutting at knob_d would shave the grip ridges
// off entirely instead of breaking their edges.
knob_od = knob_d + 0.4;

module focus_knob() {
    intersection() {
        union() {
            cylinder(d = knob_d, h = knob_h);
            for (a = [0 : 360 / flute_n : 359])
                rotate([0, 0, a])
                    translate([knob_d / 2 - 0.6, 0, knob_h / 2])
                        cube([1.6, 1.6, knob_h], center = true);
        }
        cyl(d = knob_od, h = knob_h, chamfer = knob_chamfer, anchor = BOTTOM);
    }
}

// Cove blending the shaft into the knob face.
//
// Sampled and revolved, because the profile is a power curve rather than
// an arc and there is no primitive for that. Printed knob-down the surface
// narrows as it rises, so it is self-supporting at any power.
COVE_SEGS = 48;

module knob_cove() {
    kr = knob_d / 2;
    sr = shaft_d / 2;
    // w runs 0 at the knob rim to 1 at the shaft; z rises as w^pow, so the
    // steep part of the sweep lands at the centre
    pts = [ for (i = [0 : COVE_SEGS])
              let (w = i / COVE_SEGS)
              [kr - w * (kr - sr), knob_cove_h * pow(w, knob_cove_pow)] ];
    rotate_extrude()
        polygon(concat([[sr, 0]], pts));
}

// ONE PRINTED PART: knob, shaft, gear and the far stub, all rigid.
// Printed knob-DOWN so the 28mm disc is the bed adhesion surface and the
// gear ends up on top. There is no separate flare any more — the tapered
// tooth tips carry that transition themselves.
//
// z=0 is the RACK MIDPLANE and the full-depth band is centred on it, with
// an equal taper each side, so the geometry the assembly positions from is
// unchanged.
module focus_pinion() {
    stub_len = arm_reach + 2;
    translate([0, 0, -(knob_h + shaft_to_knob)]) {
        focus_knob();
        // cove sitting on the knob face, blending into the shaft
        translate([0, 0, knob_h - 0.01])
            knob_cove();
        // shaft from the knob up through the gear; it runs inside the
        // tooth roots, so gear and shaft union without a seam
        translate([0, 0, knob_h])
            cylinder(d = shaft_d, h = shaft_to_knob + pinion_full_w / 2 + taper_h);
    }
    focus_gear();
    // far stub, through the opposite bearing. It starts above the upper
    // taper now; the taper closes down to exactly shaft_d, so the two meet
    // without a step.
    translate([0, 0, pinion_full_w / 2 + taper_h - 0.01])
        cylinder(d = shaft_d, h = stub_len);
}

// Print orientation: knob DOWN on the bed, gear UP. The offset lives
// here so it is derived from this file's own dimensions rather than
// recomputed in the build — the same mistake, made once already, put the
// part 28mm below the bed.
module focus_pinion_printable() {
    translate([0, 0, knob_h + shaft_to_knob])
        focus_pinion();
}

focus_pinion();
