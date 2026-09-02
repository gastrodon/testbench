// Label legibility test strip — one layer, a few minutes on the bed.
//
// Two columns, testing two different things:
//
//   LEFT   real strings in the CANDIDATE font only (ExtraLight at 6, a
//          measured 0.42mm stem = one extrusion pass). Words rather than
//          digits, because words are what exposes a font: ascenders and
//          descenders, letter pairs that nearly touch, repeated letters
//          that reveal inconsistent spacing, and punctuation, which is
//          the smallest and first thing to drop out.
//
//   RIGHT  0-9 plus a decimal point and an underscore, at every
//          font/size candidate. Digits are what labels actually carry —
//          diameters, pitches, tolerances — and the decimal point is the
//          smallest feature on any plate. An underscore sits on the
//          baseline where the first layer is most likely to lift.
//
// The first attempt at on-sheet labels used Bold at ~3 extrusion passes
// per stroke under a 3mm brim; the counters of 8 and 6 filled in and only
// the distinctive digits stayed readable. The second showed small text
// peeling off the sheet before it could adhere. So this strip is sliced
// with brim 0, z_offset lowered to squash the bead into the sheet, and a
// slower first layer.
//
// SLICE IT WITH:
//   --brim-width 0        (a brim around each glyph closes the counters)
//   --skirts 2 --skirt-distance 8   (warm-up, kept well clear of the text)
//   --layer-height 0.2 --first-layer-height 0.2   (one layer)

include <params.scad>
// INCLUDE, not use. use<> imports modules and functions but NOT variables,
// so LABEL_LAYER_H came through as undef and linear_extrude built a 100mm
// tall block of text instead of a 0.2mm one — silently, with valid
// geometry and no warning.
include <label.scad>

// The candidate: one clean extrusion pass per stroke at a readable size.
NORMAL_FONT = "DejaVu Sans Light:style=ExtraLight";
NORMAL_SIZE = 6;

// Left column — real strings, candidate font only.
phrases = [
    "panty liar man :3c",
    "huge @3",
    "big eeeeed |:3",
    "pick see o:3",
    "malice >:3",
    "penis :3",
];

// Right column — the same digit set at every candidate, so one print
// compares them directly instead of across two sessions.
//   font, size, measured stem, extrusion passes at 0.42mm
digit_rows = [
    [NORMAL_FONT,                6,   "0.42mm  1.0x"],
    [NORMAL_FONT,                7,   "0.49mm  1.2x"],
    [NORMAL_FONT,                5,   "0.35mm  0.8x"],
    ["DejaVu Sans:style=Book",   3.1, "0.43mm  1.0x"],
    ["DejaVu Sans:style=Book",   5,   "0.69mm  1.6x"],
    ["DejaVu Sans:style=Bold",   5,   "1.31mm  3.1x"],
];

digits = "0123456789._";

row_pitch = 11;
column_gap = 8;

// Left-aligned so both columns share a datum and a row's two halves can
// be compared without hunting.
module row_text(txt, font, size) {
    linear_extrude(height = LABEL_LAYER_H)
        text(txt, size = size, font = font,
             halign = "left", valign = "center");
}

// Width the widest left-hand string will occupy, so the right column
// clears it rather than overlapping — computed, not guessed.
left_w = max([ for (s = phrases) label_width(s, NORMAL_SIZE) ]);
right_x = left_w + column_gap;

for (i = [0 : len(phrases) - 1])
    translate([0, -i * row_pitch, 0])
        row_text(phrases[i], NORMAL_FONT, NORMAL_SIZE);

for (i = [0 : len(digit_rows) - 1])
    translate([right_x, -i * row_pitch, 0])
        row_text(digits, digit_rows[i][0], digit_rows[i][1]);

echo(str("left column: ", len(phrases), " phrases in ", NORMAL_FONT,
         " at ", NORMAL_SIZE, " (", left_w, "mm widest)"));
echo(str("right column starts at x=", right_x, "; digit rows top to bottom:"));
for (i = [0 : len(digit_rows) - 1])
    echo(str("  ", i + 1, ": size ", digit_rows[i][1], "  ",
             digit_rows[i][2], "  ", digit_rows[i][0]));
