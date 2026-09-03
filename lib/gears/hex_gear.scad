// HEX GEAR -- a spur gear with a hex bore, as a reusable component.
//
// eva: "I like the gear that has the hex key in it. let's reuse that for
// the gear attached to the handle." This file is that reuse. Three of the
// four gears in the mechanism are instances of it, and on the tilt axis
// the two instances are the SAME PRINTED PART -- same module, same tooth
// count, same bore -- so one STL gets printed twice.
//
// A HEX, not a round bore with a grub screw. A grub bearing on a round
// printed boss holds by friction and eventually slips; that is the
// failure ../mount/alt_rotor.scad was redesigned to get rid of, one
// project over. A hex cannot slip, only shear, and it shears at a load
// that is nowhere near what a hand delivers.
//
// Deliberately self-contained apart from the gear library, so it can be
// copied into the next mechanism that needs one.

include <../BOSL2/std.scad>
include <../BOSL2/gears.scad>

module hex_gear(mod, teeth, face, hex_af, fit = 0.35, pa = 20,
                backlash = 0.15, spin = 0) {
    hex_corner_r = hex_af / cos(30) / 2;
    root_r = mod * teeth / 2 - 1.25 * mod;
    // A gear whose bore eats its own tooth roots is not a gear, it is a
    // crack waiting to happen. Asserted rather than eyeballed, because
    // this module is meant to be called with numbers nobody checked.
    assert(root_r - hex_corner_r > 4.0,
           str("hex_gear: only ", root_r - hex_corner_r, "mm of web between ",
               "a ", hex_af, "mm hex and the roots of a ", teeth,
               "-tooth module-", mod, " gear."));

    difference() {
        spur_gear(mod = mod, teeth = teeth, thickness = face,
                  shaft_diam = 0, pressure_angle = pa, backlash = backlash,
                  anchor = BOTTOM, spin = spin);
        translate([0, 0, -1])
            cylinder(h = face + 2, d = (hex_af + 2 * fit) / cos(30), $fn = 6);
    }
}
