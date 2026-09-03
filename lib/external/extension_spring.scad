// EXTENSION SPRING -- close-wound coil with a machine hook at each end.
//
// EXTERNAL PART: bought, not printed. See README.md in this directory.
//
// SOURCE: engineering-drawings field sheet "Extension Spring — Field
// Sheet" (spring-field-sheet.html, PRESET, marked "recorded"). THE SHEET
// IS IN INCHES and is converted here rather than by hand, for the same
// reason as ../external/threaded_tube.scad -- a hand-converted number
// cannot be diffed against the sheet it came from.
function spring_in(x) = x * 25.4;

// ---------------------------------------------------------------------
// MEASURED (eva, field sheet, inches)
// ---------------------------------------------------------------------
spring_hook_top_len = spring_in(3.100);  // A  top hook, axial
spring_wire_d       = spring_in(0.165);  // B  wire diameter
spring_od           = spring_in(1.137);  // C  outer diameter over the coil
spring_body_len     = spring_in(3.576);  // D  coil body only, hook to hook
spring_hook_bot_len = spring_in(3.850);  // E  bottom hook, axial
spring_hook_open    = spring_in(0.640);  // F  hook inside opening

// ---------------------------------------------------------------------
// DERIVED -- the sheet computes the first two live and they are repeated
// here as formulas, never as numbers, so the two cannot disagree.
// ---------------------------------------------------------------------
spring_free_len = spring_body_len + spring_hook_top_len + spring_hook_bot_len;
spring_mean_d   = spring_od - spring_wire_d;
spring_index    = spring_mean_d / spring_wire_d;   // 5.9 -- a normal spring

// COIL COUNT IS DERIVED, NOT COUNTED. Nobody counted the coils; the sheet
// has no letter for them. An extension spring is wound CLOSED -- adjacent
// coils touch at free length, that is what makes it an extension spring
// and not a compression one -- so at free length the pitch IS the wire
// diameter and the count falls out of the body length:
spring_coils = spring_body_len / spring_wire_d;     // ~21.7
//
// That is a strong inference rather than a guess (it is forced by the
// spring being close-wound at all), but it is still an inference. If it
// is ever load-bearing, count the coils.

// Hook centreline radius, and how far the loop reaches past its own
// centre. A hook's INSIDE opening is what a caliper can reach, so the
// centreline is derived from it rather than the other way round.
spring_hook_r    = (spring_hook_open + spring_wire_d) / 2;
spring_hook_span = spring_hook_r + spring_wire_d / 2;

assert(spring_hook_top_len > 2 * spring_hook_r + spring_wire_d / 2,
       "extension_spring: the top hook is shorter than its own loop.");
assert(spring_hook_bot_len > 2 * spring_hook_r + spring_wire_d / 2,
       "extension_spring: the bottom hook is shorter than its own loop.");
assert(spring_index > 3,
       "extension_spring: a spring index below 3 is not windable -- check B and C.");

// Rendering detail. The coil is ~22 turns of swept wire and every segment
// is a hull(), so this is the file's whole cost: segments-per-turn drives
// it linearly. 16 is legible in a render; drop it for a fast preview.
spring_seg = 16;   // segments per turn
spring_fn  = 12;   // facets on the swept sphere
//
// Both undersize the model slightly, in the way any faceted sweep does:
// a 12-facet sphere is inscribed in the wire it stands for, so an
// exported mesh measures ~0.15mm under both the OD and the free length.
// That is a rendering artefact, not a disagreement with the sheet -- use
// extension_spring_envelope() for anything that needs the real numbers
// exactly, since it is built from them directly.

// How far round the hook loop closes. COSMETIC and unmeasured: the sheet
// draws an open loop with the gap facing the coil, so that is what this
// draws, but nothing recorded how big the gap is. It affects nothing that
// mates with the spring -- the inside opening F does that -- so it is a
// constant here rather than a letter that was missed.
spring_hook_sweep = 330;

// ---------------------------------------------------------------------
// WHAT IS NOT HERE
//
//   * material and therefore rate. See spring_rate() at the bottom -- it
//     takes the modulus as an argument precisely because nobody has
//     established what this wire is.
//   * initial tension. A close-wound extension spring does not begin to
//     extend until the preload is overcome, and the preload was not
//     measured (it needs a scale, not calipers). Any force computed from
//     geometry alone is therefore an UNDERESTIMATE of what it takes to
//     pull this spring to a given length.
//   * hook orientation relative to each other. Drawn coplanar because the
//     sheet's side view draws them coplanar; a real pair is often 90
//     degrees apart, and nothing recorded which this one is.
// ---------------------------------------------------------------------

// Sweep a circular wire along a polyline, one hull() per segment.
module spring_wire_path(pts, d = spring_wire_d, fn = spring_fn) {
    for (i = [0 : len(pts) - 2])
        hull() {
            translate(pts[i])     sphere(d = d, $fn = fn);
            translate(pts[i + 1]) sphere(d = d, $fn = fn);
        }
}

// Coil centreline, from z0 upward, as a point list.
function spring_coil_pts(z0, coil_len, turns = spring_coils,
                         seg = spring_seg) =
    let (n = max(2, round(turns * seg)))
    [for (i = [0 : n])
        let (t = i / n)
        [spring_mean_d / 2 * cos(360 * turns * t),
         spring_mean_d / 2 * sin(360 * turns * t),
         z0 + coil_len * t]];

// One hook, growing +Z from z0: a short blend off the coil's radius onto
// the axis, a straight shank, then a loop.
//
// The blend is why this is not just a line and a circle. The coil ends
// out at the mean radius and the loop is centred on the axis, so the wire
// has to cross ~12mm of radius somewhere; drawn as a straight jump it
// leaves a visible kink and, worse, a wire that is momentarily horizontal
// where the real one never is.
function spring_hook_pts(z0, hook_len, phase = 0, blend_steps = 8) =
    let (blend_rise = spring_wire_d * 2,
         loop_cz    = z0 + hook_len - spring_hook_span,
         shank_top  = loop_cz - spring_hook_r,
         blend = [for (i = [0 : blend_steps])
                     let (t = i / blend_steps)
                     [spring_mean_d / 2 * (1 - t) * cos(phase + 90 * t),
                      spring_mean_d / 2 * (1 - t) * sin(phase + 90 * t),
                      z0 + blend_rise * t]],
         // The loop stops short of closing, and the gap faces the coil
         // -- which is where the sheet's drawing puts it, and where a
         // real hook's free end sits.
         loop = [for (a = [0 : 10 : spring_hook_sweep])
                    [spring_hook_r * sin(a), 0, loop_cz - spring_hook_r * cos(a)]])
    assert(shank_top > z0 + blend_rise,
           "extension_spring: hook is too short for its own blend and loop.")
    concat(blend, [[0, 0, shank_top]], loop);

// The spring, axis on Z, origin at the BOTTOM of the bottom hook, so a
// spring is positioned by the thing it hangs from.
//
// `length` is the installed, stretched length -- the useful parameter for
// a real assembly, since a spring in a mechanism is essentially never at
// free length. Extension is taken up entirely in the coil pitch, which is
// where it physically goes: the hooks do not stretch.
module extension_spring(length = spring_free_len) {
    assert(length >= spring_free_len,
           str("extension_spring: ", length, "mm is shorter than the ",
               spring_free_len, "mm free length -- an extension spring ",
               "cannot be compressed below close-wound."));
    coil_len = length - spring_hook_top_len - spring_hook_bot_len;
    coil_z0  = spring_hook_bot_len;

    // Bottom hook: the same hook, mirrored, so there is one hook geometry
    // in this file and not two that can drift.
    translate([0, 0, coil_z0]) mirror([0, 0, 1])
        spring_wire_path(spring_hook_pts(0, spring_hook_bot_len));

    spring_wire_path(spring_coil_pts(coil_z0, coil_len));

    // Top hook, phased to start where the coil actually ended -- the coil
    // count is not a whole number, so its far end is at an arbitrary
    // angle and a hook drawn at a fixed one floats off the wire.
    translate([0, 0, coil_z0 + coil_len])
        spring_wire_path(spring_hook_pts(0, spring_hook_top_len,
                                         phase = 360 * spring_coils));
}

// Swept envelope at a given installed length -- a cylinder at OD, plus the
// hooks' reach. Cheap: use this for clearance instead of the ~350 hulls
// the real coil costs.
module extension_spring_envelope(length = spring_free_len, clearance = 0) {
    cylinder(h = length + 2 * clearance, d = spring_od + 2 * clearance,
             center = false, $fn = 48);
}

// Rate, in N/mm, from the standard torsion-of-the-wire formula.
//
// The modulus is an ARGUMENT WITH NO DEFAULT on purpose. Nothing recorded
// what this wire is, and the difference between music wire (~79.3 GPa)
// and 302 stainless (~69 GPa) is 13% of the answer -- which is small
// enough to be invisible in a plausible-looking number and large enough
// to matter. Making it a required argument means the assumption is
// written down at the call site every time.
//
// Ignores initial tension entirely (see above), so this is the SLOPE of
// the force-extension line, not the force at a given extension.
function spring_rate(G_mpa) =
    G_mpa * pow(spring_wire_d, 4)
        / (8 * pow(spring_mean_d, 3) * spring_coils);
