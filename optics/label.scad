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

LABEL_FONT = "DejaVu Sans:style=Bold";

// One layer, and the layer is the whole part. Height must match the
// profile's FIRST layer height (0.2mm here) — a label taller than that
// becomes a two-layer wall with an unsupported second course, and one
// thinner may miss the slice plane entirely and vanish.
LABEL_LAYER_H = 0.2;

// Bold, and big enough that every stroke is several extrusions wide.
// These are read off the bed rather than in the hand, so they can afford
// to be larger than something engraved on a part.
module flat_label(txt, size = 6, h = LABEL_LAYER_H) {
    linear_extrude(height = h)
        text(txt, size = size, font = LABEL_FONT,
             halign = "center", valign = "center");
}

// Width a label will occupy, so a plate layout can keep it clear of the
// brim around its neighbour rather than discovering the overlap in the
// slicer.
function label_width(txt, size = 6) = len(txt) * size * 0.72;
