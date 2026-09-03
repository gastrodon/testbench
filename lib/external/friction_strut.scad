// FRICTION STRUT -- plastic housing + steel rod, a sliding lid-stay pair.
//
// EXTERNAL PART: bought, not printed. See README.md in this directory.
//
// ---------------------------------------------------------------------
// THIS ONE IS NOT MEASURED. THE FIELD SHEET CAME BACK EMPTY.
//
// The other three sheets in the batch say "recorded" in their subtitle
// and carry a PRESET of caliper readings. This one
// (friction-strut-field-sheet.html) does not: it has all twelve letters
// laid out with leader lines and not one value behind them. So there is
// nothing here to hard-code, and this file does not pretend otherwise --
// it models the SHAPE, which the drawing does establish, and takes every
// dimension as a required argument.
//
// The consequence, stated plainly so nobody has to discover it: you
// cannot build a clearance around this strut yet. Any assembly that needs
// to will have to go through the sheet with calipers first. Twelve
// numbers, listed below by letter.
//
// The rule this file follows for what it will and will not invent:
//
//   * anything the sheet gave a LETTER is a required argument. Passing
//     none asserts, naming the letter and what it measures. A default
//     would be a fabricated measurement wearing a real one's clothes.
//   * anything the sheet never lettered -- eye thickness, slot width,
//     grip length, slot count -- gets a default derived from the letters,
//     marked DRAWN. Those are shape, not measurement: they change how the
//     render looks and not what fits.
// ---------------------------------------------------------------------
//
// LETTERS, from the sheet, housing (plastic) on the left of the drawing:
//
//   A  overall length, top of eye to tip
//   B  eye outer diameter
//   C  eye bore diameter
//   D  eye length: top of eye to body start
//   E  body outer diameter
//   F  slot (window) length
//   G  grip-end outer diameter
//
// ...and the rod (steel) on the right:
//
//   H  overall length, top of eye to tip
//   I  eye outer diameter
//   J  eye bore diameter
//   K  eye-to-shaft length, the neck
//   L  rod shaft outer diameter
//
// The sheet cross-checks B against I and C against J live, because both
// ends pin to the same kind of thing and should match. friction_strut()
// asserts the same pair rather than leaving it to a reader.

strut_fn = 48;

// The eye, shared by both parts so there is one eye geometry in this file
// and not two that drift. Pin axis on X, so the strut swings in the YZ
// plane; the eye's own axis is the pivot and sits at the ORIGIN.
module strut_eye(od, bore, t) {
    rotate([0, 90, 0]) difference() {
        cylinder(h = t, d = od, center = true, $fn = strut_fn);
        cylinder(h = t + 2, d = bore, center = true, $fn = strut_fn);
    }
}

// A through window with rounded ends, `len` along the strut axis.
module strut_slot(len, w, depth) {
    assert(len >= w, "friction_strut: slot is shorter than it is wide.");
    rotate([90, 0, 0]) hull() for (s = [-1, 1])
        translate([0, s * (len - w) / 2, -depth / 2])
            cylinder(h = depth, d = w, $fn = strut_fn);
}

// THE HOUSING. Origin at the EYE BORE CENTRE -- the pivot, which is what
// a strut is actually located by in an assembly, and the only point on it
// whose position a design cares about. The body runs +Z from there, so
// the eye's top face lands at z = -B/2 and the tip at z = A - B/2. The
// sheet's own datum (top of the eye) is therefore reproduced rather than
// restated.
module friction_strut_housing(A, B, C, D, E, F, G,
                              slots = 2, slot_w = undef,
                              grip_len = undef, eye_t = undef) {
    assert(!is_undef(A), "friction_strut_housing: A (overall length) unmeasured.");
    assert(!is_undef(B), "friction_strut_housing: B (eye OD) unmeasured.");
    assert(!is_undef(C), "friction_strut_housing: C (eye bore) unmeasured.");
    assert(!is_undef(D), "friction_strut_housing: D (eye to body start) unmeasured.");
    assert(!is_undef(E), "friction_strut_housing: E (body OD) unmeasured.");
    assert(!is_undef(F), "friction_strut_housing: F (slot length) unmeasured.");
    assert(!is_undef(G), "friction_strut_housing: G (grip-end OD) unmeasured.");

    et = is_undef(eye_t)    ? E       : eye_t;    // DRAWN, not measured
    gl = is_undef(grip_len) ? G * 1.5 : grip_len; // DRAWN, not measured
    sw = is_undef(slot_w)   ? E / 2   : slot_w;   // DRAWN, not measured

    body_z0  = D - B / 2;        // where the body starts, per the sheet's D
    tip_z    = A - B / 2;
    body_len = tip_z - gl - body_z0;

    assert(C < B, "friction_strut_housing: eye bore C is larger than eye OD B.");
    assert(D > B, str("friction_strut_housing: D (", D, ") is not longer than ",
                      "the eye's own diameter B (", B, ") -- D runs from the ",
                      "TOP of the eye, so it cannot be shorter."));
    assert(body_len > 0,
           "friction_strut_housing: no body left between the eye and the grip.");
    assert(body_len > slots * F,
           str("friction_strut_housing: ", slots, " slots of ", F,
               "mm do not fit in ", body_len, "mm of body."));

    difference() {
        union() {
            strut_eye(B, C, et);
            // Body from the eye's CENTRE, not from its edge -- it buries
            // itself in the eye and overlaps volumetrically instead of
            // meeting it across a tangent surface (AGENTS.md: union needs
            // overlap, not contact).
            //
            // The sheet's drawing shows a slight collar tapering out of
            // the eye into the body. Nothing lettered it, so it is not
            // drawn: a straight body is the shape we can defend.
            cylinder(h = body_z0 + body_len, d = E, $fn = strut_fn);
            translate([0, 0, tip_z - gl])
                cylinder(h = gl, d = G, $fn = strut_fn);
        }
        // Windows, spaced evenly down the body.
        for (i = [1 : slots])
            translate([0, 0, body_z0 + body_len * i / (slots + 1)])
                strut_slot(F, sw, E + 2);
    }
}

// THE ROD. Same origin convention: its own pivot at the origin, shaft
// running +Z.
module friction_strut_rod(H, I, J, K, L, eye_t = undef) {
    assert(!is_undef(H), "friction_strut_rod: H (overall length) unmeasured.");
    assert(!is_undef(I), "friction_strut_rod: I (eye OD) unmeasured.");
    assert(!is_undef(J), "friction_strut_rod: J (eye bore) unmeasured.");
    assert(!is_undef(K), "friction_strut_rod: K (eye-to-shaft neck) unmeasured.");
    assert(!is_undef(L), "friction_strut_rod: L (shaft OD) unmeasured.");

    et = is_undef(eye_t) ? L : eye_t;   // DRAWN, not measured -- a rod eye
                                        // is usually a flattened end, so
                                        // it is drawn at the rod's own
                                        // thickness rather than the
                                        // housing's moulded width.
    assert(J < I, "friction_strut_rod: eye bore J is larger than eye OD I.");
    assert(K > I / 2, "friction_strut_rod: the neck K ends inside the eye.");

    strut_eye(I, J, et);
    // The neck is a real taper on this part -- the drawing goes from a
    // 28mm-ish eye down to a thin shaft over a few millimetres, so unlike
    // the housing's collar it cannot be left out. Drawn as a single cone
    // from the eye's centre (buried, hence overlapping) out to the shaft
    // diameter at the shaft's start. That introduces no constant of its
    // own: both ends of the cone are lettered dimensions.
    cylinder(h = K - I / 2, d1 = I, d2 = L, $fn = strut_fn);
    translate([0, 0, K - I / 2])
        cylinder(h = H - I / 2 - (K - I / 2), d = L, $fn = strut_fn);
}

// The pair, posed at a given EYE-TO-EYE length -- which is the dimension
// an assembly actually constrains, and the one that avoids needing a
// figure nobody measured (how deep the rod sits in the housing at a given
// stroke). Housing pivot at the origin, rod pivot at z = eye_to_eye.
module friction_strut(A, B, C, D, E, F, G, H, I, J, K, L, eye_to_eye,
                      slots = 2) {
    assert(!is_undef(eye_to_eye),
           "friction_strut: pose it by naming the eye-to-eye length.");
    // The sheet's own live cross-check, as an assertion. Both ends pin to
    // the same class of fastener; if the two eyes disagree, one of the
    // four readings is wrong and the strut is not what it looks like.
    assert(abs(B - I) < 0.5,
           str("friction_strut: housing eye OD B=", B,
               " and rod eye OD I=", I, " disagree. Re-measure."));
    assert(abs(C - J) < 0.5,
           str("friction_strut: housing eye bore C=", C,
               " and rod eye bore J=", J, " disagree. Re-measure."));
    assert(eye_to_eye < A - B / 2 + H - I / 2,
           "friction_strut: posed longer than the two parts laid end to end.");

    friction_strut_housing(A, B, C, D, E, F, G, slots = slots);
    translate([0, 0, eye_to_eye]) rotate([180, 0, 0])
        friction_strut_rod(H, I, J, K, L);
}
