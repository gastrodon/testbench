// RANGE-OF-MOTION animation.
//
// Drives assembly() through both joints so the mechanism can be watched
// rather than inferred. This is the one check that a still render cannot
// do at all: a mechanism that moves as one rigid lump, or one whose
// "moving" joint is actually clamped solid, looks perfect in every static
// view and interferes with nothing (cad-design rule 6).
//
// $t CANNOT be set with -D -- OpenSCAD silently ignores -D on $-prefixed
// variables, and every frame comes out byte-identical. The only way to
// drive it is --animate N. (AGENTS.md; cost someone a confusing round of
// "why do all four spot-check frames look the same".)
//
//   ./animate.sh
//
// Schedule, so a viewer knows what they are looking at:
//   t 0.00 - 0.45   ALTITUDE sweeps 0 -> 90 -> 0, azimuth held
//   t 0.45 - 1.00   AZIMUTH sweeps a full 360, altitude held at 40
//
// The altitude half deliberately runs the FULL designed range, including
// the part where the tube's tail swings below the base. That collision is
// real at the assumed tube_len_behind and showing it is the point -- an
// animation that quietly stopped at the last angle that looked tidy would
// be hiding the one open question in the design.

include <params.scad>
use <assembly.scad>

phase_split = 0.45;

// Triangle wave 0 -> 1 -> 0 over the first phase.
function alt_of_t(t) =
    let (u = t / phase_split)
    alt_min_deg + (alt_max_deg - alt_min_deg) * (u < 0.5 ? 2 * u : 2 - 2 * u);

function az_of_t(t) =
    t < phase_split ? 0 : 360 * (t - phase_split) / (1 - phase_split);

alt_now = $t < phase_split ? alt_of_t($t) : 40;
az_now  = az_of_t($t);

assembly(az = az_now, alt = alt_now);
