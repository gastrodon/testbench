// PELA-blocks print calibration beam, for the shop Ender 3.
//
// Prints a strip of Technic-compatible beams at slightly different
// tolerances so you can pick the one that actually fits your printer +
// filament, rather than guessing. Print it once, measure which segment's
// pin holes/knobs fit best, and note that offset — every future PELA
// part in this project uses it via top_tweak/bottom_tweak/axle_hole_tweak.
//
// Defaults in PELA-calibration.scad assume large_nozzle=true (>=0.5mm);
// the Ender 3's stock nozzle is 0.4mm. IMPORTANT: OpenSCAD's `include`
// resets any variable you assign *before* the include line back to the
// included file's own default — silently, with only a console warning
// (verified: assigning _large_nozzle here does nothing on its own). The
// only override that actually sticks is a `-D` flag on the command line:
//
//   openscad -o calibration.stl -D '_large_nozzle=false' calibration.scad
//
// (needs lib/ present — run ./fetch-libs.sh first)

include <lib/PELA-blocks/PELA-calibration.scad>
