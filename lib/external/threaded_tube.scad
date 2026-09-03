// THREADED TUBE -- a male-stud/female-socket tube section, as measured.
//
// EXTERNAL PART: bought, not printed. See README.md in this directory for
// what that means for how the numbers are allowed to be wrong.
//
// SOURCE: engineering-drawings field sheet "Threaded Tube — Field Sheet"
// (tube-field-sheet.html, PRESET, marked "recorded"). THE SHEET IS IN
// INCHES; every measurement below is written in the units it was taken in
// and converted here, rather than converted by hand into the source. A
// hand-converted number cannot be checked against the sheet without
// redoing the arithmetic, and this repo has a rule about restating
// dimensions for exactly that reason.
function tube_in(x) = x * 25.4;

// ---------------------------------------------------------------------
// MEASURED (eva, field sheet, inches)
// ---------------------------------------------------------------------
tube_len          = tube_in(14.35);  // A  overall length, socket tip to stud tip
tube_od           = tube_in(1.17);   // B  outer diameter, main body
tube_bore_d       = tube_in(0.615);  // C  through bore
tube_stud_d       = tube_in(0.71);   // G  male stud MAJOR diameter
tube_stud_len     = tube_in(0.71);   // H  male stud length
tube_neck_od      = tube_in(0.88);   // K  female neck OD (the ring seat)
tube_neck_len     = tube_in(0.15);   // L  female neck length
tube_socket_depth = tube_in(0.5);    // J  female thread depth (engagement)
tube_stud_threads = 6.5;             // M  thread count over H (a count, not a length)

// DERIVED, not measured -- pitch from a thread count over a known length.
// 6.5 threads counted by eye over 18mm is worth about half a thread of
// resolution, so this is good to roughly +/-8%: enough to say "coarse",
// not enough to cut a mating thread from.
tube_stud_pitch = tube_stud_len / tube_stud_threads;
tube_stud_tpi   = tube_stud_threads / 0.71;
tube_wall       = (tube_od - tube_bore_d) / 2;

// ---------------------------------------------------------------------
// N -- the female thread count -- WAS NEVER RECORDED. The sheet has a
// letter for it and the letter came back empty, so the female pitch below
// is an ASSUMPTION, not a reading:
// ---------------------------------------------------------------------
tube_socket_pitch = tube_stud_pitch;   // ASSUMED equal to the male pitch

// ---------------------------------------------------------------------
// The one place this file departs from the field sheet, and why.
//
// The sheet's live-derived readout prints "female major (bore) dia = C",
// i.e. it takes the female thread's major diameter to be the same 0.615"
// as the through bore. That CANNOT be right, and it is worth writing out
// rather than quietly fixing:
//
//   male stud major   G = 0.710"
//   through bore      C = 0.615"
//
// A 0.710" stud does not enter a 0.615" hole. Since this part has a male
// stud on one end and a female socket on the other -- the whole point of
// which is that sections chain -- either the two ends do not mate (and
// the part is not what it plainly is), or the socket is bored WIDER than
// the through bore over its engagement depth. The second reading also
// makes the numbers agree with themselves:
//
//   a thread of pitch ~0.109" has ~0.067" of depth per flank
//   minor 0.615" + 2 * 0.067" = 0.749" major, against a 0.710" stud
//
// which is the right side of the stud with a normal amount of clearance,
// where "female major = C" is on the wrong side of it by 0.095".
//
// So: modelled as a counterbore at the STUD's major diameter over depth J.
// This is REASONED, not measured -- it is one caliper reading down the
// socket away from being settled, and that reading has not been taken.
tube_socket_major_d = tube_stud_d;     // REASONED, see above

assert(tube_socket_major_d >= tube_stud_d,
       "threaded_tube: socket is narrower than the stud -- sections cannot chain.");
assert(tube_neck_od > tube_socket_major_d,
       "threaded_tube: the female neck has no wall left around its own thread.");
assert(tube_socket_depth > tube_neck_len,
       "threaded_tube: socket engagement is shallower than the neck.");
assert(tube_len > tube_stud_len + tube_socket_depth,
       "threaded_tube: the stud and socket overlap -- there is no tube between them.");

tube_fn = 64;

// ---------------------------------------------------------------------
// THREADS ARE DRAWN AS PLAIN CYLINDERS AT MAJOR DIAMETER, on purpose --
// the same call ../motors/nema17.scad makes for the pulley it does not
// make. The questions this file answers are envelope and engagement
// depth, and a helical form answers neither any better while costing a
// BOSL2 dependency and a slow render. `tube_stud_pitch` is exported for
// anyone who does need to cut a mating form; note its error bar above
// before using it for that.
//
// ORIENTATION: axis on Z, FEMALE SOCKET AT Z=0, male stud at +Z. That
// makes chaining a plain `translate([0, 0, tube_len])` with no sign to
// get backwards -- see threaded_tube_chain().
// ---------------------------------------------------------------------
module threaded_tube() {
    difference() {
        union() {
            // Neck first (the reduced-OD ring seat), then the body, then
            // the stud. Each is a full-length-from-zero cylinder trimmed
            // by the next, so every joint is a volumetric overlap rather
            // than two faces meeting at a plane.
            cylinder(h = tube_neck_len, d = tube_neck_od, $fn = tube_fn);
            translate([0, 0, tube_neck_len])
                cylinder(h = tube_len - tube_neck_len - tube_stud_len,
                         d = tube_od, $fn = tube_fn);
            translate([0, 0, tube_len - tube_stud_len])
                cylinder(h = tube_stud_len, d = tube_stud_d, $fn = tube_fn);
        }
        // Through bore -- runs from the socket end up to the stud
        // shoulder and stops. The stud is SOLID on the real part (the
        // sheet's section view is explicit about this), so a bore run all
        // the way through would hollow out the one feature that carries
        // the load.
        translate([0, 0, -1])
            cylinder(h = tube_len - tube_stud_len + 1, d = tube_bore_d,
                     $fn = tube_fn);
        // Socket counterbore over the engagement depth.
        translate([0, 0, -1])
            cylinder(h = tube_socket_depth + 1, d = tube_socket_major_d,
                     $fn = tube_fn);
    }
}

// The stud as a NEGATIVE -- the hole a part of ours needs if it is going
// to accept one of these. Kept in this file, beside the stud it mates
// with, so the two cannot drift apart.
module threaded_tube_socket_cut(depth = tube_socket_depth, clearance = 0.25) {
    cylinder(h = depth, d = tube_stud_d + 2 * clearance, $fn = tube_fn);
}

// ...and the stud as a POSITIVE, for a part of ours that screws INTO the
// tube's socket. Drawn at major diameter minus clearance: a printed stud
// at exactly major diameter does not start.
module threaded_tube_stud(len = tube_socket_depth, clearance = 0.25) {
    assert(len <= tube_socket_depth,
           str("threaded_tube_stud: ", len, "mm is longer than the ",
               tube_socket_depth, "mm the socket actually accepts."));
    cylinder(h = len, d = tube_socket_major_d - 2 * clearance, $fn = tube_fn);
}

// Envelope of a run of n chained sections, for reach and clearance.
//
// Renders as n SEPARATE closed bodies, which is correct -- these are n
// separate bought parts meeting across their thread flanks, not one
// solid. Do not union the result into something printed; it is for reach
// and clearance.
//
// The stud disappears into the next section's socket, so n sections do
// NOT reach n * A: each joint swallows the engagement depth. Modelled by
// actually stacking them rather than by a length formula, so the
// shortening is a consequence of the geometry instead of arithmetic
// somebody has to keep true.
module threaded_tube_chain(n = 2) {
    for (i = [0 : n - 1])
        translate([0, 0, i * (tube_len - tube_socket_depth)])
            threaded_tube();
}

function threaded_tube_chain_len(n) =
    n * tube_len - (n - 1) * tube_socket_depth;
