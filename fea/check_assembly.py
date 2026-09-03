#!/usr/bin/env python3
"""Self-tests for the assembly pipeline (fea/assembly.py) against analytic
and equivalence answers, in the spirit of fea/check.py:

  1. TIE      two half-beams bonded end-to-end deflect like one beam —
              validates the deck emitter, global numbering, C3D10 face
              tables, and *TIE itself in one shot.
  2. GRAVITY  a column under self-weight carries sigma = rho*g*h.
  3. CONTACT  a block pressed onto a slab: mean interface pressure = F/A
              (set by equilibrium, insensitive to the overclosure slope).
  4. FRICTION a sheared block below the friction limit sticks.
  5. PEEL     an edge-loaded block tips: part of the interface opens while
              the rest bears — separation must be visible in the results.

  nix develop --command python fea/check_assembly.py
"""

import sys
import tempfile
from pathlib import Path

import numpy as np
import trimesh

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fealib import LoadCase, MATERIALS, solve_case
from assembly import AssemblyCase, Contact, Part, Tie, solve_assembly

MAT = MATERIALS["PLA"]


def box_stl(path, extents, origin):
    b = trimesh.creation.box(extents=extents)
    b.apply_translation(np.asarray(extents) / 2 + np.asarray(origin))
    b.export(path)


def main() -> int:
    work = Path(tempfile.mkdtemp(prefix="fea-asm-check-"))
    L, B, H = 100.0, 10.0, 10.0
    F = 10.0

    # --- 1. tied split beam == monolithic beam ---
    box_stl(work / "whole.stl", (L, B, H), (0, 0, 0))
    box_stl(work / "half_a.stl", (L / 2, B, H), (0, 0, 0))
    box_stl(work / "half_b.stl", (L / 2, B, H), (L / 2, 0, 0))

    mono = solve_case(work / "whole.stl", LoadCase(
        name="mono", rationale="", material="PLA",
        fixed=lambda p: p[:, 0] < 1e-6,
        loaded=lambda p: p[:, 0] > L - 1e-6, force=(0, 0, -F)),
        mesh_size=3.0, workdir=work / "mono")

    tied = solve_assembly(AssemblyCase(
        name="tied-beam", rationale="two halves bonded end-to-end",
        parts={"a": Part("half_a.stl"), "b": Part("half_b.stl")},
        interfaces=[Tie("a", "b", tol=0.5)],
        fixed=[("a", lambda p: p[:, 0] < 1e-6)],
        loads=[("b", lambda p: p[:, 0] > L - 1e-6, (0.0, 0.0, -F))]),
        mesh_size=3.0, workdir=work / "tied", base_dir=work)

    d_mono, d_tied = mono.max_disp, tied.parts["b"].max_disp
    print(f"1 TIE      tip disp {d_tied:.4f} mm vs monolithic {d_mono:.4f}")
    assert abs(d_tied - d_mono) / d_mono < 0.05, (d_tied, d_mono)

    # --- 2. gravity column: sigma(z) = rho*g*(h - z) ---
    hcol = 100.0
    box_stl(work / "col.stl", (20, 20, hcol), (0, 0, 0))
    grav = solve_assembly(AssemblyCase(
        name="gravity-column", rationale="self-weight only",
        parts={"col": Part("col.stl")}, interfaces=[],
        fixed=[("col", lambda p: p[:, 2] < 1e-6)], loads=[], gravity=True),
        mesh_size=5.0, workdir=work / "grav", base_dir=work)
    sigma_at_mask = MAT.density * 9810.0 * (hcol - 3.0)
    peak = grav.parts["col"].peak
    print(f"2 GRAVITY  peak vM {peak * 1e3:.4f} kPa vs rho*g*(h-3mm) "
          f"{sigma_at_mask * 1e3:.4f} kPa")
    assert abs(peak - sigma_at_mask) / sigma_at_mask < 0.15, peak

    # --- shared geometry for the contact tests ---
    # slab 30x30x10 fixed at its base; block 20x20x10 resting on top of it
    N = 100.0                     # normal force, N
    A = 20.0 * 20.0               # contact patch, mm^2
    box_stl(work / "slab.stl", (30, 30, 10), (-15, -15, -10))
    box_stl(work / "block.stl", (20, 20, 10), (-10, -10, 0))

    def contact_case(name, loads):
        return AssemblyCase(
            name=name, rationale="contact validation",
            parts={"slab": Part("slab.stl"),
                   "block": Part("block.stl", stabilize=True)},
            interfaces=[Contact("block", "slab", mu=0.3, tol=1.0)],
            fixed=[("slab", lambda p: p[:, 2] < -10 + 1e-6)],
            loads=loads)

    # --- 3. pressure = F/A ---
    press = solve_assembly(contact_case("press", [
        ("block", lambda p: p[:, 2] > 10 - 1e-6, (0.0, 0.0, -N))]),
        mesh_size=3.0, workdir=work / "press", base_dir=work)
    c = press.interfaces[0]
    print(f"3 CONTACT  {c.force_normal:.2f} N transferred (applied {N:.0f}), "
          f"mean pressure {c.pressure_mean:.4f} MPa vs F/A {N / A:.4f}, "
          f"bearing {c.bearing_area:.0f}/{c.declared_area:.0f} mm^2 "
          f"= {c.bearing_fraction:.0%} "
          f"[ccx CPRESS peak {c.pressure_peak_ccx:.4f} vs traction peak "
          f"{c.pressure_peak:.4f}]")
    # The load has to arrive on the other side of the interface: equilibrium,
    # not a modelling choice, so this is tight.
    assert abs(c.force_normal - N) / N < 0.05, c.force_normal
    assert abs(c.pressure_mean - N / A) / (N / A) < 0.15, c.pressure_mean
    # a centrally-loaded block bears across essentially its whole footprint
    assert c.bearing_fraction > 0.9, c.bearing_fraction
    press_frac = c.bearing_fraction

    # --- 4. friction stick: shear below mu*N must not slide ---
    stick = solve_assembly(contact_case("stick", [
        ("block", lambda p: p[:, 2] > 10 - 1e-6, (0.0, 0.0, -N)),
        ("block", lambda p: p[:, 2] > 10 - 1e-6, (0.1 * N, 0.0, 0.0))]),
        mesh_size=3.0, workdir=work / "stick", base_dir=work)
    c = stick.interfaces[0]
    lat = float(np.abs(stick.parts["block"].disp[:, 0]).max())
    print(f"4 FRICTION shear at 0.1*N (mu=0.3): slip_max {c.slip_max}, "
          f"block lateral disp {lat:.4f} mm")
    assert lat < 0.05, "block slid under sub-friction shear"

    # --- 5. peel: all the load on one edge tips the block, far edge opens ---
    peel = solve_assembly(contact_case("peel", [
        ("block", lambda p: (p[:, 2] > 10 - 1e-6) & (p[:, 0] < -10 + 2.0),
         (0.0, 0.0, -N))]),
        mesh_size=3.0, workdir=work / "peel", base_dir=work)
    c = peel.interfaces[0]
    lift = float(peel.parts["block"].disp[:, 2].max())
    print(f"5 PEEL     bearing {c.bearing_area:.0f}/{c.declared_area:.0f} mm^2 = "
          f"{c.bearing_fraction:.0%} (vs {press_frac:.0%} pressed flat), "
          f"pressure peak {c.pressure_peak:.4f} vs mean {c.pressure_mean:.4f}, "
          f"max upward disp {lift:.4f} mm")
    # Separation shows up as interface area dropping to zero pressure, NOT as
    # positive COPEN — ccx removes a separated node from its active set and
    # reports COPEN 0 for it (fea/README.md).
    assert c.bearing_fraction < 0.8 * press_frac, \
        "no separation reported on a tipping block"
    assert lift > 1e-3, "far edge should lift off"
    assert c.pressure_peak > 1.5 * c.pressure_mean, \
        "edge loading should concentrate pressure toward the loaded edge"

    print("fea/check_assembly.py: all assertions passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
