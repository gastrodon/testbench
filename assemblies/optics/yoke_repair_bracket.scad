// Repair bracket for a base_mount() print physically disturbed mid-job.
//
// The physical part reached Z=72.82mm of a 74.5mm total print (measured
// off the real part) before a bed disturbance. Everything above 72.82mm
// turned out NOT to be one connected body: it's the very top of the
// pinion's bearing boss (bearing_boss_d=13, centered at pinion_z), split
// into 4 separate islands by the snap_throat slot that lets the shaft
// click in from above. Confirmed by intersecting the real base_mount.stl
// with a z>=72.82 half-space (--render=true, CGAL) and with a thin
// single-layer slice exactly at z=72.82: both show 4 disconnected
// islands, not 2 -- and the throat's own cutting geometry runs from
// pinion_z past the yoke_ceiling trim, so there is no height at which
// the two sides of it reconnect into a "C" on their own.
//
// v1 of this bracket swept a hull from a pad against the SLEEVE up to a
// closed bore at the original bearing position -- verified (trimesh
// boolean intersection against the real base_mount.stl) to occupy
// almost the same 3D space as the existing arm blade and bearing boss,
// i.e. it couldn't physically be installed, the real plastic is already
// there. Also wrong per the user: mount to the ARM (the "fin" -- the
// blade is flat and fin-like, hence the name) directly below the break,
// not the sleeve; and keep the throat OPEN so the axle still snaps in,
// don't seal it into a closed bore.
//
// v2 (this file): a thin plate OUTBOARD of each arm's outer face
// (x = s*10, from base_mount's own arm_x + arm_t/2), offset 1mm clear
// so there's no overlap with real material, screwed radially into the
// arm blade itself. At the top, an open-throat boss reproducing the
// ORIGINAL snap-throat geometry (same bearing_boss_d, same snap_throat
// width) so the M6 axle still clicks in from above -- this bracket
// REPLACES the missing top of the boss, it doesn't seal it shut. The
// two plates join into one printed part via a low, outboard-rear
// connecting bar clear of the gear disc, the rack's sweep, and the
// original bridge_y/bridge_drop feature.
//
// Consequence worth flagging: because the new bosses sit outboard of
// the arm (x=s*~13.5) rather than at the original x=s*8.5, the M6 axle
// now spans further between its two bearing points than the original
// design did (~23mm -> ~32mm). Check the axle stock is long enough
// before cutting it.
//
// Print orientation: "print flat per side" (said before "join as one
// part") and "join as one part" pull in different directions once
// they're a single U-shaped piece -- a joined bracket prints bar-down,
// with both plates standing as vertical walls either side. That's
// still support-free (the walls are vertical, the throat opens
// upward, same self-supporting logic the original boss used) and is
// what yoke_repair_bracket_printable() below does; it is not literally
// "flat."
//
// ON SOURCING GEOMETRY FROM objective_focus_mount.scad: that file
// cannot be safely `include`d (its last line is a bare base_mount()
// call, which would union the entire original part into this output)
// nor does `use` give access to its internal derived variables. The
// derived numbers below are RECOMPUTED here from the same
// params.scad/gears.scad inputs and the same formulas
// objective_focus_mount.scad itself uses (each cited by name), not
// retyped constants.
include <params.scad>
include <lib/BOSL2/std.scad>
include <lib/BOSL2/gears.scad>
use <objective_focus_mount.scad>   // base_mount() -- reference only, for
                                    // the verification render; never
                                    // unioned into the bracket itself.

// Recomputed, not retyped -- see header note.
sleeve_id       = carrier_tube_od + 2 * clearance;              // objective_focus_mount.scad
sleeve_od       = sleeve_id + 2 * wall;                          // objective_focus_mount.scad
rack_slot_half  = gear_thickness / 2 + 3;                        // params.scad
arm_x           = rack_slot_half + arm_t / 2;                    // objective_focus_mount.scad
arm_outer_x     = arm_x + arm_t / 2;                              // arm blade's own outer face
// The plate's outboard offset has to clear the ROUND SLEEVE too, not
// just the arm blade -- the sleeve's OD (11.7 radius) actually pokes
// PAST the arm's outer face (10) near y=0 for z<~66, which a first
// draft of this offset missed: measured 552mm^3 of real overlap with
// base_mount.stl, bbox showing exactly that x in [-11.7,11.7] sliver.
mount_clear_x   = max(arm_outer_x, sleeve_od/2);
bearing_d       = shaft_d_frame + 0.35;                           // objective_focus_mount.scad
pinion_y        = rack_y - gear_dist(mod = gear_mod, teeth1 = pinion_teeth,
                                      teeth2 = 0,
                                      pressure_angle = gear_pressure_angle); // objective_focus_mount.scad
pinion_od_r     = gear_mod * (pinion_teeth + 2) / 2;              // addendum OD radius, for keep-out
// pinion_z comes straight from params.scad -- no recompute needed.

// ---------------------------------------------------------------------
// New geometry this repair introduces.
// ---------------------------------------------------------------------
screw_clear_d   = 3.4;    // M3 clearance THROUGH THE BRACKET -- the pilot
                           // lives in the real arm, not here.
screw_pilot_d   = 2.5;    // M3 self-tapping pilot, drilled into the arm.
plate_gap       = 0;      // flush: the plate's inner face sits AT the
                           // real surface (mount_clear_x), not offset
                           // off it -- was 1mm of standoff clearance,
                           // changed to flush contact per instruction.
plate_t         = 4;      // plate thickness, mm

// Screw mount heights and Y-targets -- NOT y=0. Measured directly off
// base_mount.stl by ray-casting from y=-40 toward +y at x=8.5 (the arm
// centreline) at each candidate z: the arm blade leans hard toward
// negative Y as it rises (it only sits near y=0 right at its root, well
// below arm_z_top) and is fused with the sleeve's own back wall through
// this whole range, so a screw aimed at y=0 here misses the arm and
// mostly lands on the sleeve's FRONT wall instead -- which is exactly
// the "screws into the cylindrical area" problem flagged on the last
// draft. At z=32 the real material spans y=[-16.16,-3.75]; at z=42,
// y=[-18.97,-3.75] -- both fused arm+sleeve, solid and thick (>12mm),
// genuinely better screw purchase than the thin blade higher up.
// Targets below sit mid-material at each height, not at either surface.
mount_z_lo      = 32;
mount_y_lo      = -10;
mount_z_hi      = 42;
mount_y_hi      = -11.5;

// Connecting bar: NOT over the top. That was tried and the user caught
// what the interference checks in this file missed -- the bar's own
// keep-out tests (base_mount, rack sweep box, gear disc) all measured
// clean, but none of them modelled the CARRIER TUBE's own insertion
// path (it slides down into the sleeve bore from directly above,
// travelling through x=0, y=[-9.3,9.3] -- the bore radius -- at any Z
// above the sleeve). A bar arced over the top at (pinion_y+9, 85) sat
// directly in that path even though every keep-out I'd actually
// measured came back zero. Also not through the low/mid region either
// (tried and measured 434mm^3 of real overlap there, see git history)
// -- that band is crowded with the sleeve, the leaning arm, the rack
// sweep, the gear disc and the original bridge all at once.
//
// So: BEHIND -- outboard in Y, past the arm's own back-most reach,
// where nothing else (fixed or moving) ever goes. At z=50 the arm's
// real back surface (measured, x=8.5 ray cast) sits at y=-21.2; y=-27
// clears it by 5.8mm. Below rack_z_min (45.37) would also have worked,
// but z=50 lines up with mount_z_hi's neighbourhood so the fin's own
// hull doesn't need a big separate detour to reach it -- still checked
// against the real mesh below, not assumed safe because it's outboard.
bar_y           = -27;
bar_z           = 50;
bar_section     = 8;

// The mount pads and bar sit OUTBOARD (clear of the sleeve and arm, see
// mount_clear_x above); the boss/throat sits back INBOARD, at the same
// X the original clamps occupied (arm_x), so the axle ends up exactly
// where it was rather than ~4mm further out. The two X's are different,
// so the fin can't be a single flat plate any more -- it needs a
// genuine offset between the mount region and the boss region.
//
// A JOGGLE, properly: two parallel flanges (one at each X) connected by
// a short PERPENDICULAR step, not a smooth diagonal taper. A first
// draft hulled all four stations together in one hull() -- convex hull
// of points at two different X's is a cone/wedge between them, which
// reads as a single slanted cut, not a step. Built here instead as
// THREE separate pieces, each hulling only its own adjacent pair, so X
// and Z each change in their own dedicated segment rather than
// blending together:
//   1. outboard rise  -- x constant at x_outboard, z rises from
//      mount_z_lo through the bar up to jog_z
//   2. the jog itself -- z AND y constant at jog_z/jog_y, x steps from
//      x_outboard to x_inboard (the "move perpendicularly" part)
//   3. inboard rise    -- x constant at x_inboard, y constant at
//      pinion_y (jog_y = pinion_y, so this leg is a pure vertical rise
//      with no further lean), z rises from jog_z to the boss
// jog_z sits just above the disturbance height (72.82) -- entirely in
// the missing region, so the jog step itself never has to cross real
// printed material.
x_inboard = arm_x;   // original clamp X -- see header note on this change
jog_z     = 73.5;
jog_y     = pinion_y;

module station(x, y, z, d) {
    translate([x, y, z])
        rotate([0, 90, 0])
            cylinder(d = d, h = plate_t, center = true);
}

module fin_solid(s) {
    xo = s * (mount_clear_x + plate_gap + plate_t/2);   // outboard X
    xi = s * x_inboard;                                  // inboard X
    union() {
        // 1. outboard rise (x = xo throughout)
        hull() {
            station(xo, mount_y_lo, mount_z_lo, 9);
            station(xo, mount_y_hi, mount_z_hi, 9);
        }
        hull() {
            station(xo, mount_y_hi, mount_z_hi, 9);
            station(xo, bar_y, bar_z, bar_section + 2);
        }
        hull() {
            station(xo, bar_y, bar_z, bar_section + 2);
            station(xo, jog_y, jog_z, 9);
        }
        // 2. the jog (z = jog_z, y = jog_y throughout; only x moves)
        hull() {
            station(xo, jog_y, jog_z, 9);
            station(xi, jog_y, jog_z, 9);
        }
        // 3. inboard rise -- NOT a simple circle station any more. A
        // thin (plate_t=4mm) extruded circle read as a hollow ring in
        // the sliced preview rather than a solid clamp, and re-deriving
        // the throat/bore cuts by hand risked getting them subtly wrong
        // a second time. The real clamp geometry already exists and is
        // known-good -- arm_blade(s) IS the original arm, boss included
        // -- so reuse it directly.
        //
        // NOT via hull() with arm_blade(s) itself, though -- tried
        // twice: hulling the full blade produced a non-manifold result
        // outright (CGAL "Simple: no"); hulling a z>=64-cropped copy of
        // it was manifold but fragmented into 5+ disconnected slivers
        // right at the crop boundary, where the blade's own tail-curve
        // cross-section is complex enough that a flat intersection cut
        // doesn't leave a single clean face for hull() to grip. CGAL's
        // hull is reliable against simple primitives, not against an
        // arbitrary complex mesh.
        //
        // So: hull() ONLY between two simple stations (bridging from the
        // jog down to a point verified (ray-cast against the real mesh)
        // to sit INSIDE the real arm's solid at z=66), then plain
        // union() with the untouched, full arm_blade(s) -- union doesn't
        // need convexity, only real volumetric overlap, which the
        // bridging station's placement guarantees directly rather than
        // hoping a hull wraps a complex shape cleanly.
        union() {
            hull() {
                station(xi, jog_y, jog_z, 9);
                station(xi, jog_y, 66, 9);
            }
            arm_blade(s);
        }
    }
}

module fin(s) {
    x0 = s * (mount_clear_x + plate_gap + plate_t/2);   // outboard, mounts/bar
    xi = s * x_inboard;                                  // inboard, boss/throat/bore
    difference() {
        fin_solid(s);

        // Throat + bore: reuse pinion_yoke_cuts() directly rather than
        // re-deriving the throat width/depth and bore position by
        // hand. It cuts the bearing bore, the snap-throat slot (open
        // top to bottom, not capped -- the whole point of "not being
        // capped" is that this is the SAME cut geometry the original
        // design used, not a shorter stand-in that only reaches through
        // this bracket's own thin cross-section), the gear pocket, the
        // rack slot and the yoke_ceiling trim. Everything except the
        // bore/throat lands on empty space here (no material of this
        // bracket's own reaches the rack slot or gear pocket) so it's a
        // no-op there -- reusing the whole module is simpler and safer
        // than trying to extract just the two cuts that matter.
        pinion_yoke_cuts();

        // Screw clearance THROUGH the plate, at each mount point's own
        // real Y target (not a shared y=0) -- pilot holes are cut into
        // the real arm separately, in fin_pilot_cut() below.
        translate([x0 - plate_t, mount_y_lo, mount_z_lo])
            rotate([0, 90, 0])
                cylinder(d = screw_clear_d, h = 2 * plate_t);
        translate([x0 - plate_t, mount_y_hi, mount_z_hi])
            rotate([0, 90, 0])
                cylinder(d = screw_clear_d, h = 2 * plate_t);

        // Cleanup: the arm_blade(s) union above brings in its FULL
        // shape (root to tip) so the boss/throat cuts above have real,
        // known-good geometry to act on -- the top-level base_mount()
        // subtraction in yoke_repair_bracket() is what's meant to strip
        // the redundant, already-printed lower portion back out. In
        // practice that large-scale subtract left small disconnected
        // debris (measured: 5-7 slivers, watertight individually but
        // not connected to the main body, near the arm's root z=6.75-34
        // and near the boss transition z=62-65) rather than cleanly
        // zeroing it out -- a boundary-tolerance artifact of two
        // separately-built shapes that are SUPPOSED to coincide exactly
        // but don't quite, bit for bit. This bracket's own geometry
        // never needs anything from the inboard column below the bridge
        // station at z=66, so just remove that column outright rather
        // than trust the large subtraction to leave nothing behind:
        // narrower than the outboard mount plate (xi+-3 vs the plate's
        // own inner face at ~13.7) so it can't touch legitimate geometry.
        translate([xi - 3, -100, -100])
            cube([6, 200, 100 + 66]);
    }
}

// Pilot holes into the REAL arm -- exported separately so it can be
// subtracted from base_mount.stl (or just drilled by hand at assembly:
// these coordinates are also the drill points). Centred on the GAP
// between the plate's inner face and the arm's real surface, at each
// mount point's own measured Y, so the hole actually spans from the
// plate into solid arm material -- an earlier draft centred this on
// mount_clear_x (the sleeve-clearance offset, ~19.7) while the plate
// itself sat at ~14.7, so the two didn't line up and the "pilot" mostly
// drilled through air.
module fin_pilot_cut(s) {
    x0 = s * (mount_clear_x + plate_gap + plate_t/2);
    translate([x0 - s*plate_t, mount_y_lo, mount_z_lo])
        rotate([0, 90, 0])
            cylinder(d = screw_pilot_d, h = 20, center = true);
    translate([x0 - s*plate_t, mount_y_hi, mount_z_hi])
        rotate([0, 90, 0])
            cylinder(d = screw_pilot_d, h = 20, center = true);
}

module yoke_repair_bracket() {
    // The joggle's inboard boss (see x_inboard note above) puts new
    // material back at the SAME x=+-arm_x the real arm already
    // occupies below the 72.82 break -- measured 1385mm^3 of genuine
    // overlap with base_mount.stl before this cut existed, bbox
    // z=[43.6,74.5], exactly the transition region as the joggle sweeps
    // inboard. Rather than hand-trim just that region (fragile against
    // any future change to the joggle's own shape), subtract the real
    // part directly: this guarantees zero overlap with whatever
    // already-printed material exists, by construction, everywhere in
    // this file, not just in the one spot that happened to get measured.
    //
    // IMPORTANT: base_mount() is the COMPLETE, undisturbed design --
    // full CAD intent, as if the print had finished. It is NOT the
    // actual physical object, which stops at 72.82. Subtracting the
    // whole thing (first attempt) also erased this bracket's own new
    // material anywhere it occupies space the ORIGINAL design intended
    // but the real part never got to print -- the throat's own
    // clearance ray came back completely empty, because the boss
    // region above 72.82 got treated as "already there" and cut away.
    // Only the truly-printed portion (z<=72.82) should ever be
    // subtracted.
    disturbance_z = 72.82;
    difference() {
        union() {
            for (s = [-1, 1])
                fin(s);
            // Endpoints sunk well inside each fin's own (bar_y,bar_z)
            // waypoint circle (radius bar_section/2+1 there vs the
            // bar's own bar_section/2 -- 1mm of real radial overlap,
            // not a coincident surface).
            hull() {
                translate([-(mount_clear_x + plate_gap + plate_t/2), bar_y, bar_z]) sphere(d = bar_section);
                translate([mount_clear_x + plate_gap + plate_t/2, bar_y, bar_z]) sphere(d = bar_section);
            }
        }
        intersection() {
            base_mount();
            translate([-100, -100, -100])
                cube([200, 200, 100 + disturbance_z]);
        }

        // Bore, extended: pinion_yoke_cuts()'s own bearing bore only
        // spans the ORIGINAL double-arm width (x=-(arm_x+arm_t) to
        // +(arm_x+arm_t), ~23mm) -- it never had reason to reach this
        // bracket's outboard jog/mount structure, which didn't exist in
        // the original design. Left alone, the outboard side of each
        // clamp caps the hole rather than passing all the way through.
        // Extended here to clear the FULL X-span of this bracket (both
        // fins, generous margin) at the same (pinion_y, pinion_z) axis
        // -- same diameter as the real bore, just longer. Print-side
        // consequence acknowledged and accepted (per instruction): this
        // reads as a much bigger unsupported horizontal void once the
        // part is lying on its side for printing, needs real support
        // material through it, and that support gets manually cleared
        // after printing rather than designed away.
        translate([-40, pinion_y, pinion_z])
            rotate([0, 90, 0])
                cylinder(d = bearing_d, h = 80);
    }
}

// Printed bar-down: see the print-orientation note in the file header.
// Lying on its side: the two fins stay side-by-side (X untouched, so
// they print symmetric rather than stacked), the mount-to-boss line
// (originally the tall Z axis, ~50mm, beam and axle-clip both live on
// it) rotates down to run horizontally front-to-back on the bed, and
// the bar-to-boss front/back offset (originally Y, only ~26.5mm)
// becomes the vertical build direction -- a squat ~27mm-tall print
// instead of a ~50mm-tall standing one, with no overhang under the
// clamp (nothing is cantilevered past what's already printed below it
// in this orientation, unlike standing it up on the mount end).
module yoke_repair_bracket_printable() {
    translate([0, 0, 32])   // lift clear of the bed -- see z-shift note below
        rotate([90, 0, 0])
            yoke_repair_bracket();
}

yoke_repair_bracket();
