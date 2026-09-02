// Label legibility test strip — one layer, a few minutes on the bed.
//
// The first plate to carry on-sheet labels came out only half readable:
// "all I can tell is one number ends in .88 and one ends in .68". Two
// causes, both now understood, neither yet proven fixed:
//
//   the font was BOLD, so every stroke was ~1.3mm — about three extrusion
//   passes — and the counters of 8 and 6 filled in;
//
//   brim_width applies per OBJECT and every glyph is an object, so a 3mm
//   brim grew around each character and bridged the gaps.
//
// This prints the candidates side by side so one short job settles which
// combination actually reads, instead of discovering it three hours into
// a real plate again.
//
// SLICE IT WITH:
//   --brim-width 0        (else the brim closes the counters again)
//   --skirts 0            (a skirt loop beside the text crowds it)
//   --layer-height 0.2    (one layer, matching LABEL_LAYER_H)
//
// Measured stems against a 0.42mm extrusion — see label.scad for the
// table. The prediction under test: ExtraLight at 6 is the only row that
// is both one clean pass AND readable at a glance.

include <params.scad>
// INCLUDE, not use. use<> imports modules and functions but NOT variables,
// so LABEL_LAYER_H came through as undef and linear_extrude built a 100mm
// tall block of text instead of a 0.2mm one — silently, with valid
// geometry and no warning. Third time this file family has been bitten by
// what use<> does not carry.
include <label.scad>

// Each row: font, size, and what it should demonstrate.
rows = [
    ["DejaVu Sans Light:style=ExtraLight", 6,   "11.88  0.42mm  1.0x"],
    ["DejaVu Sans Light:style=ExtraLight", 7,   "11.88  0.49mm  1.2x"],
    ["DejaVu Sans Light:style=ExtraLight", 5,   "11.88  0.35mm  0.8x"],
    ["DejaVu Sans:style=Book",             3.1, "11.88  0.43mm  1.0x"],
    ["DejaVu Sans:style=Book",             5,   "11.88  0.69mm  1.6x"],
    ["DejaVu Sans:style=Bold",             5,   "11.88  1.31mm  3.1x"],
];

row_pitch = 11;

// The digits that actually failed last time: 8 and 6 have counters that
// fill, and the decimal point is the smallest feature on the plate.
sample = "11.88 11.68";

module test_row(font, size, i) {
    translate([0, -i * row_pitch, 0])
        linear_extrude(height = LABEL_LAYER_H)
            text(sample, size = size, font = font,
                 halign = "center", valign = "center");
}

for (i = [0 : len(rows) - 1])
    test_row(rows[i][0], rows[i][1], i);

echo("label test strip — rows top to bottom:");
for (i = [0 : len(rows) - 1])
    echo(str("  ", i + 1, ": ", rows[i][2], "  ", rows[i][0]));
echo(str("one layer at ", LABEL_LAYER_H, "mm; slice with brim 0 and skirts 0"));
