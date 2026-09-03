// PRINT -- emit one part in its PRINT orientation.
//
// This file exists because five part headers used to claim "build.sh owns
// that flip" and build.sh did no such thing. That is cad-design rule 5
// documented in the wrong direction, which is worse than not documenting
// it: a reader who trusts the comment ships a pedestal whose entire
// tripod interface is unsupported air under the first layer.
//
// Print orientation and assembly orientation are two different transforms
// on the same object, and conflating them is easy because both are "just
// a rotation". Every part's assembly frame lives in its own file; every
// part's PRINT frame lives here, once, with a reason beside it.
//
//   openscad -o out.stl -D 'part="yoke"' print.scad
//
// What this file does NOT decide is supports, adhesion or sequence. That
// is print-job's job, and duplicating it here would drift.

include <params.scad>
use <pedestal.scad>
use <az_column.scad>
use <yoke.scad>
use <az_pinion.scad>
use <az_handle.scad>
use <tilt_platter.scad>
use <tilt_gear.scad>
use <tilt_handle.scad>
use <tripod_nut.scad>

part = "pedestal";

// This file states ROTATIONS only. It does NOT try to drop parts onto the
// bed, because OpenSCAD cannot ask a solid for its own bounding box, so
// every landing height would be a hand-computed number restating geometry
// the part already owns -- rule 3, in the one file that exists to warn
// about rule 5. The first version did exactly that and got five of nine
// wrong, by as much as 32mm.
//
// drop_to_bed.py does it afterwards, from the rendered mesh's real
// bounds. Measured, not restated.

if (part == "pedestal")
    // NO orientation is free here: the azimuth post stands 40mm up and the
    // tripod posts and stud hang 16mm down, so one of them is always in
    // the air. Printed as modelled, dropped onto the bed, which puts the
    // small tripod-side features on the bed and the big post upward. The
    // plate's underside is then a bridge over three posts and needs
    // support -- print-job's call, flagged here.
    pedestal();
else if (part == "az_column")
    // Already right: table down, column up, gear teeth stacked across
    // the face rather than along it.
    az_column();
else if (part == "yoke")
    // Laid flat: the blade is a plate thin in X, so rotating it onto its
    // face puts the whole part within about 44mm of the bed instead of
    // standing 78mm tall on a 12mm footprint.
    rotate([0, 90, 0]) yoke();
else if (part == "az_pinion")
    az_pinion();
else if (part == "az_handle")
    // Grip DOWN. The lobed profile is the widest thing on the part and
    // its bottom chamfer was drawn to be a first layer; printed hex-down
    // the grip is a 40mm overhang.
    rotate([180, 0, 0]) az_handle();
else if (part == "tilt_platter")
    // Payload face DOWN: it is the one large flat surface on the part,
    // and it puts the trunnion stub horizontal rather than cantilevered.
    rotate([180, 0, 0]) tilt_platter();
else if (part == "tilt_gear")
    // Bore vertical, like any gear.
    tilt_gear();
else if (part == "tilt_handle")
    // Same reasoning as az_handle: grip down.
    rotate([-90, 0, 0]) tilt_handle();
else if (part == "tripod_nut")
    // Relief DOWN, so the annular recess is the first layers rather than
    // a bridge, and the internal thread climbs as a vertical spiral.
    rotate([180, 0, 0]) tripod_nut();
else
    assert(false, str("print: unknown part '", part, "'"));
