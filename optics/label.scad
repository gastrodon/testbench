// Part labelling — one layer of raised text.
//
// Written after the thread coupons came off the bed indistinguishable and
// had to be identified by "the one further from the centre", reconstructed
// from the layout script. That worked once. It is not a method.
//
// RAISED, not engraved. A one-layer recess reads as a faint scuff on a
// top surface; a one-layer boss catches the light and the fingernail.
// The cost is that raised text must never sit on a face that mates with
// something — hence the label TAB below, which is deliberately out of
// every load and seating path.
//
// h should be at least the COARSEST layer height the part might print at,
// not the one it happens to be sliced at today. The slicer takes each
// layer's cross-section at its midpoint (print_z - height/2), so a slab
// thinner than a layer survives only if that plane happens to fall inside
// it. A 0.10mm label did survive a 0.15mm slice here, but only because
// the tab's 3.0mm top put the plane at 3.075 — move the tab thickness a
// fraction and the same label vanishes with no warning.
//
// 0.2 straddles a slice plane at every height these parts would use, so
// the label stops depending on where the planes happen to land.
//
// FONTS: text() silently renders NOTHING when fontconfig finds no font,
// with only a warning on stderr. The nix build sandbox has no fonts by
// default, so flake.nix hands the derivation a fontconfig file. If a
// label ever comes out blank, that is the first place to look — the STL
// will still be watertight and will still pass every geometry check.

// NO LIBRARY DEPENDENCY, deliberately. This file is pulled in with
// use<>, and use<> imports module definitions WITHOUT the caller's
// includes — so a BOSL2 call in here resolves against label.scad's own
// (empty) scope, not the caller's. The first version used cuboid() and
// every single tab silently vanished: undefined module, a warning on
// stderr, exit 0, and three watertight STLs whose labels were loose
// letters floating a hundredth of a millimetre above the part.
//
// Rounded corners via hull() of four cylinders instead. Plain OpenSCAD,
// nothing to resolve, nothing to forget to include.
LABEL_FONT = "DejaVu Sans:style=Bold";

// How far the glyphs are sunk into the plate they sit on. The raised
// height above the surface is still exactly h; this is extra material
// BELOW the surface so the union is volumetric. 0.01mm of overlap is
// tangency, not intersection, and tangency is what produces the
// disconnected bodies this build keeps rediscovering.
LABEL_SINK = 0.4;

module rounded_plate(w, d, thick, r = 1.5) {
    hull()
        for (sx = [-1, 1], sy = [-1, 1])
            translate([sx * (w / 2 - r), sy * (d / 2 - r), 0])
                cylinder(r = r, h = thick, $fn = 24);
}

// Bold and >=3.5mm so every stroke is at least one 0.4mm extrusion wide.
// PrusaSlicer drops features thinner than the extrusion width without
// complaining, which on a label means losing the thin strokes of digits
// and turning 8 into something ambiguous.
module part_label(txt, h, size = 4) {
    linear_extrude(height = h)
        text(txt, size = size, font = LABEL_FONT,
             halign = "center", valign = "center");
}

// A flat plate to carry a label, sized to the text so it cannot overrun.
// Sits proud of the part it names by `stick` so it merges solidly rather
// than touching tangentially — tangent contact is how this build has
// produced non-manifold STLs before.
// Place the origin ON the edge of the part being labelled. The tab grows
// AWAY from it along `dir` (+1 or -1 in Y) and reaches `stick` back the
// other way, burying itself in the parent.
//
// dir exists so a tab on a part's -Y edge still points outward without
// rotating the whole tab 180, which would leave the text upside down.
// The glyphs stay upright either way.
module label_tab(txt, h, thick, size = 4, pad = 2.5, stick = 2, dir = 1) {
    w = len(txt) * size * 0.72 + 2 * pad;
    d = size + 2 * pad;
    union() {
        translate([0, dir * (d - stick) / 2, 0])
            rounded_plate(w, d + stick, thick);
        translate([0, dir * d / 2, thick - LABEL_SINK])
            part_label(txt, h + LABEL_SINK, size);
    }
}
