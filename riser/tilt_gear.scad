// TILT GEAR -- printed TWICE, and it is the same part both times.
//
// One instance keys onto the platter's trunnion stub and turns with the
// payload; the other keys onto the tilt handle's hex and drives it. Same
// module, same tooth count, same hex, so one STL covers both -- which is
// only true because the ratio is the 1:1 that was asked for and because
// the trunnion's hex was grown to match the handle's rather than the
// other way round.
//
// If params section 7's holding warning bites and the ratio has to change,
// these stop being one part and become two: a 26-tooth wheel and a
// 14-tooth pinion, at the same centre distance. That is the moment this
// file splits, and nothing else does.

include <params.scad>
include <hex_gear.scad>

// Wrapped in a module, and that is not style. `use <>` imports
// MODULES and nothing else, so a part file whose geometry sits at
// the top level imports as an empty file -- assembly.scad and
// pose.scad then render perfectly with the part simply absent.
// cad-design rule 2, and it cost four missing parts here.
module tilt_gear() {
    hex_gear(mod = tilt_gear_mod, teeth = tilt_wheel_teeth,
             face = tilt_gear_face, hex_af = tilt_hex_af, fit = tilt_fit,
             pa = gear_pa, backlash = gear_backlash);
}

tilt_gear();
