// LEGO Technic adapter — bolts to the side of the base.
// https://linear.app/gastrodon/document/microscope-camera-design-doc-15a95f836b98
//
// Split out of base_mount so the two print in their own best
// orientation: this one pins-UP with its baseplate flat on the bed, the
// base upright. As one piece the pins had to grow sideways off a round
// tube, which is the worst case for both support and layer adhesion —
// the load on a Technic pin is a lever, and it was landing straight on
// the layer lines.
//
// Flat mating face, one M3 through the middle into the base's pad.
//
// ONE screw means the adapter can in principle rotate about it. For a
// provisional mount that is fine — the screw pulls two flat faces
// together and friction holds. If it ever creeps, the fix is a second
// M3 rather than a tighter one.

include <params.scad>
include <lib/BOSL2/std.scad>
include <lib/Technic.scad/Technic.scad>

plate_w = technic_pin_spacing + 14;   // across the pins
plate_d = 15;                          // along the base's axis
plate_t = 4.0;                         // baseplate thickness

m3_free = 3.3;                         // clearance, screw passes through
m3_head = 6.2;                         // socket-head counterbore
m3_head_h = 3.2;

flare_len = 2.2;
flare_root_d = 11;
flare_tip_d = 6.2;

module technic_adapter() {
    difference() {
        union() {
            // Baseplate. Flat on the bed, flat against the base's pad —
            // both mating faces are printed flat, which is the only way
            // this joint sits true without machining.
            translate([0, 0, plate_t / 2])
                cuboid([plate_w, plate_d, plate_t],
                       rounding = 2.5, edges = "Z");
            // Conical flares, self-supporting all the way round
            for (y = [-technic_pin_spacing / 2, technic_pin_spacing / 2])
                translate([0, y, plate_t - 0.01])
                    cylinder(d1 = flare_root_d, d2 = flare_tip_d,
                             h = flare_len);
        }
        // M3 through, counterbored so the head sits below the pins and
        // cannot foul a beam pushed onto them
        translate([0, 0, -1])
            cylinder(d = m3_free, h = plate_t + flare_len + 2);
        translate([0, 0, -0.01])
            cylinder(d = m3_head, h = m3_head_h);
    }

    // Pins last, on top of the flares
    for (y = [-technic_pin_spacing / 2, technic_pin_spacing / 2])
        translate([0, y, plate_t + flare_len - 0.6])
            technic_pin_half(length = 1, friction = true);
}

// Print orientation: pins UP, baseplate DOWN on the bed.
technic_adapter();
