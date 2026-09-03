// AZ HANDLE -- the azimuth hand grip.
//
// Kinematic role: turns on the pedestal's fixed pin at [az_gear_cd, 0].
// az_pinion keys onto its hex and meshes with the gear under the column.
//
// No axial retention, deliberately. The pin is vertical and this is a
// sleeve over it, so gravity holds it down and lifting is how you take it
// off. A screw here would resist a load that does not exist.
//
// FRAME: local == assembly. Print orientation is grip-DOWN, hex up, which
// is NOT this orientation (rule 5) -- printed as modelled, the whole hex
// and collar hang unsupported under the grip.

include <params.scad>
include <handle.scad>

// Wrapped in a module, and that is not style. `use <>` imports
// MODULES and nothing else, so a part file whose geometry sits at
// the top level imports as an empty file -- assembly.scad and
// pose.scad then render perfectly with the part simply absent.
// cad-design rule 2, and it cost four missing parts here.
// Modelled at the ORIGIN, not out at the centre distance. The pose puts
// it there. Built at az_gear_cd AND posed there as well -- which is what
// the first version of this file did -- it lands at twice the centre
// distance, half off the base plate, meshing with nothing. 1,471 mm3 of
// it inside the pedestal, and a gear pair 40mm apart that still renders
// as a mechanism from any angle that does not show both at once.
module az_handle() {
    translate([0, 0, az_handle_z0])
        handle_body(collar_d = az_collar_d, collar_l = az_collar_l,
                    hex_af = az_hex_af, hex_l = az_handle_hex_l,
                    shaft_d = az_knob_shaft_d, shaft_l = az_handle_shaft_l,
                    grip_d = az_knob_d, grip_h = az_knob_h,
                    bore_d = az_knob_bore_d, bore_l = az_handle_bore_l);
}

az_handle();
