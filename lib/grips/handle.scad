// HANDLE -- the hand grip for either axis, as a reusable component.
//
// eva: "let's make the handle a separate piece that keys into that same
// shape." So the handle is no longer a knob with a gear moulded onto it.
// It is a shaft with a MALE hex on it, and the gear -- an ordinary
// hex_gear -- slides on.
//
// That split is worth more than tidiness. The gear and the grip used to be
// one printed body, which made the ratio and the grip diameter the same
// object: changing either reprinted both. Now the gear is a stock part and
// the grip is a stock part, so the tooth split params section 7 may force
// costs one small gear instead of a whole knob.
//
// Structure, from the bearing outward:
//     [ collar ] [ male hex ] [ shaft ] [ lobed grip ]
// The bore runs up the middle over a fixed pin; the gear sits on the hex,
// trapped between the fixed part and the grip; the grip is what a hand
// touches. The collar is what sets the gear's standoff from the face
// behind it. Built along +Z from Z=0 at the collar's base.

include <knob.scad>

module handle_body(collar_d, collar_l, hex_af, hex_l, shaft_d, shaft_l,
                   grip_d, grip_h, bore_d, bore_l, lobes = 3,
                   chamfer = 1.0) {
    assert(hex_af / 2 - bore_d / 2 >= 2.0,
           str("handle: only ", hex_af / 2 - bore_d / 2, "mm of wall between ",
               "a ", bore_d, "mm bore and a ", hex_af, "mm hex. The hex is ",
               "what carries the torque; it cannot be a shell."));
    assert(bore_l > collar_l + hex_l,
           str("handle: the bore stops inside the hex, so the pin has ",
               "nowhere to go. A shaft bottomed in a blind hole binds ",
               "while looking like a perfect fit in every render."));

    grip_z = collar_l + hex_l + shaft_l;
    lap    = 1.5;   // the grip starts INSIDE the shaft. Butted exactly on
                    // a face, the two share a plane and no volume, and
                    // OpenSCAD hands back a handle in two pieces --
                    // watertight, valid, rendering identically, and in two
                    // pieces. This directory has now hit that three times.

    difference() {
        union() {
            cylinder(h = collar_l, d = collar_d);
            translate([0, 0, collar_l])
                cylinder(h = hex_l, d = hex_af / cos(30), $fn = 6);
            if (shaft_l > 0)
                translate([0, 0, collar_l + hex_l])
                    cylinder(h = shaft_l, d = shaft_d);
            translate([0, 0, grip_z - lap])
                knob(d = grip_d, h = grip_h + lap, lobes = lobes,
                     chamfer = chamfer);
        }
        translate([0, 0, -1]) cylinder(h = bore_l + 1, d = bore_d);
    }
}
