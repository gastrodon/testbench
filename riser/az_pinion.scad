// AZ PINION -- the hex-bored gear on the azimuth handle.
//
// Same component as tilt_gear.scad, different numbers: module 2 rather
// than 2.5, and a smaller hex, because it wraps a smaller pin. It is NOT
// the same printed part, and params section 4 records why -- making it
// identical would mean running the azimuth pair at module 2.5 as well,
// which moves its centre distance to 50 and grows the base plate by 31mm
// across. On the tilt side the envelope was already set by the payload,
// so unifying cost nothing there and does cost something here.

include <params.scad>
include <hex_gear.scad>

// Wrapped in a module, and that is not style. `use <>` imports
// MODULES and nothing else, so a part file whose geometry sits at
// the top level imports as an empty file -- assembly.scad and
// pose.scad then render perfectly with the part simply absent.
// cad-design rule 2, and it cost four missing parts here.
// At the origin and at its own working height, so the pose only has to
// carry it out to the centre distance and spin it.
module az_pinion() {
    translate([0, 0, az_gear_z0])
    hex_gear(mod = az_gear_mod, teeth = az_gear_teeth, face = az_gear_face,
             hex_af = az_hex_af, fit = az_journal_fit, pa = gear_pa,
             backlash = gear_backlash);
    
    // The mesh phase is NOT baked in here. It belongs to the assembly, not to
    // the part: the handle turns freely, so which tooth lands in which gap is
    // decided when you put it together, not when you print it. Baking it into
    // one member also stops working the moment two members become the same
    // printed part, which is exactly what happened on the tilt axis.;
}

az_pinion();
