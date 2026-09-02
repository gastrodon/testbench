// The coupon build plate: three test parts, each named on the sheet.
//
// This exists so the layout is a committed artifact rather than a python
// script in /tmp. Every previous plate was assembled by loading STLs and
// translating them outside the model, which meant the arrangement — what
// sits where, and which label belongs to which part — was not reviewable,
// not reproducible, and not something check.py or a render could see.
//
// LABELS ARE NOT ON THE PARTS. They are separate one-layer islands
// printed flat on the sheet beside what they name. A raised label on a
// part is invisible in a single filament colour; filament on bare sheet
// is the only contrast available. See label.scad.
//
// The association is proximity, so the only thing this file must get
// right is that each label sits nearer its own part than any other, and
// clear of every brim. label_gap below is that margin.

include <params.scad>
include <lib/BOSL2/std.scad>
include <lib/BOSL2/gears.scad>
include <lib/BOSL2/threading.scad>

use <clip_coupon.scad>
use <focus_pinion.scad>
use <label.scad>

$slop = 0.1;

// Clearance from a part's footprint to its label. The profile puts a 3mm
// brim around each part, so anything under ~5 welds the label to the brim
// and it stops being separable.
label_gap = 7;

// The M12 pair is GONE from this plate: settled by print, 11.88 threads
// into the camera holder and 11.68 slips (see params.scad). Reprinting it
// would answer a question that is closed. m12_coupon.scad stays on disk in
// case the redesigned boss ever needs re-testing at a new orientation.
//
// Part positions.
clip_at  = [-18, 0];
pinion_at = [18, 0];

module coupon_plate() {
    // --- snap-clip coupon ---------------------------------------------
    // shifted by its own Y centre so clip_at means the same thing here as
    // it does for the other two: the middle of the part's footprint
    translate([clip_at[0], clip_at[1] - clip_y_centre(), 0])
        clip_coupon_printable();
    translate([clip_at[0], clip_at[1] - 17 - label_gap, 0])
        flat_label("CLIP");

    // --- pinion + knob ------------------------------------------------
    translate(pinion_at) focus_pinion_printable();
    translate([pinion_at[0], pinion_at[1] - 14.2 - label_gap, 0])
        flat_label("PINION");
}

coupon_plate();

echo("plate labels: CLIP / PINION — flat on the sheet, one layer, single-pass strokes");
