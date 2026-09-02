// Part labelling — one layer of filament written straight onto the bed.
//
// Written after the thread coupons came off the bed indistinguishable and
// had to be identified by "the one further from the centre", reconstructed
// from the layout script. That worked once. It is not a method.
//
// NOT ON THE PART. The first version raised the text on a tab attached to
// each coupon, which reads perfectly in a render and not at all in the
// hand: one filament colour means a letter standing 0.2mm proud of a
// surface the same colour is just a texture. Contrast is what makes text
// legible, and the only contrast available here is filament against the
// bare sheet.
//
// So the labels are separate islands printed flat on the sheet next to
// the part they name, like writing on the paper. They come away with the
// print, they cost one layer, and they touch no functional surface — no
// seating face to foul, no load path to interrupt, and nothing to sand
// off afterwards.
//
// Proximity is the association: a label sits beside its part and is read
// off the sheet before anything is lifted.
//
// SLICE LABELS DIFFERENTLY FROM PARTS. Found on the first plate that
// printed these: brim_width applies per OBJECT, and every glyph is its
// own object, so a 3mm brim grows around each character, fills the
// counters of 8, 6 and P, and bridges the gaps between letters. Measured
// in that gcode's first layer, the label band held 683 points of
// skirt/brim against 260 points of actual glyph outline — nearly three
// times more packaging than letter.
//
// A label therefore needs brim_width = 0 and the skirt kept well away.
// PrusaSlicer's CLI has no per-object settings (that needs a 3MF project
// with per-object config), so the practical options are:
//
//   * slice the whole coupon plate with --brim-width 0, relying on the
//     sheet for adhesion — fine for parts with broad flat footprints
//     like these, and what to try first;
//   * or run the labels as their own short job before the parts.
//
// Do NOT solve it by making the text bigger. Brim surrounds each glyph
// at a fixed width regardless of size, so the counters still fill.
//
// FONTS: text() silently renders NOTHING when fontconfig finds no font,
// with only a warning on stderr. The nix build sandbox has no fonts, so
// flake.nix hands the derivation a fontconfig file. If a label ever comes
// out blank, that is the first place to look — the STL will still be
// watertight and will still pass every geometry check.

// ONE EXTRUSION PASS PER STROKE. Not bold, and not merely "small" —
// stroke width is what matters, and it is set by the font's weight times
// its size, so those two are not independent choices.
//
// Measured stem widths (the plain vertical bar of "I"), against a 0.42mm
// extrusion at a 0.4mm nozzle:
//
//   Bold        size 5     1.305mm   ~3 passes   <- what printed illegibly
//   Book        size 5     0.685mm   1.6 passes  <- worst case: one bead
//                                                   plus ragged gap-fill
//   Book        size 3.1   0.425mm   1.0 pass    <- right stroke, tiny text
//   ExtraLight  size 6     0.423mm   1.0 pass    <- right stroke, readable
//
// SETTLED BY PRINT, and it overturned the prediction. A strip carrying
// all six candidates went down at z_offset 0.05, bed 40, 4mm/s. The two
// that read best were the SMALL ones — ExtraLight at 5 and Book at 3.1 —
// not ExtraLight at 6, which the stem arithmetic had picked as the
// obvious winner.
//
// The instructive part: ExtraLight 5 is 0.8 extrusion passes, thinner
// than a single bead, and it was expected to drop strokes. It did not.
// Sub-one-bead text prints legibly on this machine, so "at least one
// full pass" is not the constraint it was assumed to be. Restraint in
// SIZE turned out to matter more than hitting a whole number of passes —
// bigger text at the same weight just gets heavier strokes, and heavier
// strokes are what closes the counters of 8, 6 and 0.
//
// 1.6 passes remains the worst place to land: the slicer lays one
// perimeter and then gap-fills the remainder, which blobs. Avoid it in
// either direction.
//
// One glyph was lost on that print. Cause unknown — it may be the
// sub-bead width, or a momentary flow dropout. Worth watching whether it
// recurs before treating it as a property of the size.
LABEL_FONT = "DejaVu Sans Light:style=ExtraLight";

// One layer, and the layer is the whole part. Height must match the
// profile's FIRST layer height (0.2mm here) — a label taller than that
// becomes a two-layer wall with an unsupported second course, and one
// thinner may miss the slice plane entirely and vanish.
LABEL_LAYER_H = 0.2;

// Size and font weight are coupled through stroke width — see LABEL_FONT.
// 5 is what actually printed best; going larger makes strokes heavier,
// not clearer.
module flat_label(txt, size = 5, h = LABEL_LAYER_H) {   // 5 => 0.35mm stroke
    linear_extrude(height = h)
        text(txt, size = size, font = LABEL_FONT,
             halign = "center", valign = "center");
}

// Width a label will occupy, so a plate layout can keep it clear of the
// brim around its neighbour rather than discovering the overlap in the
// slicer.
function label_width(txt, size = 5) = len(txt) * size * 0.62;   // ExtraLight is narrower than Bold
