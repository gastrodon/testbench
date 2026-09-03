#!/usr/bin/env python3
"""Self-test for the fea/ pipeline against an analytic answer.

A cantilever beam (100 x 10 x 10 mm, tip-loaded) has a closed-form
Euler-Bernoulli solution; if the whole chain — STL in, gmsh surface
reclassify, tet-10 volume mesh, ccx solve, .frd parse — is healthy, the
computed tip deflection lands within a few percent of it. This is the
pipeline's regression test, in the spirit of optics/check.py: every
assertion here failed for real at least once while the pipeline was built
(wrong element label, truncated node fields, inverted tets — fea/README.md).

The beam goes through the same STL entry point real parts use (a trimesh
box export), not a gmsh-native primitive, so the STL-specific stages are
exercised too.

  nix develop --command python fea/check.py
"""

import sys
import tempfile
from pathlib import Path

import numpy as np
import trimesh

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fealib import (LoadCase, MATERIALS, capacity_scale, converged_peak,
                    couple_about, solve_case, superpose)

L, B, H = 100.0, 10.0, 10.0
F = 10.0  # N, tip load in -z
MAT = MATERIALS["PLA"]

# Euler-Bernoulli: sigma = 6FL/(b h^2), delta = FL^3/(3EI)
I = B * H ** 3 / 12
SIGMA_ROOT = 6 * F * L / (B * H ** 2)          # 6.0 MPa
DELTA_TIP = F * L ** 3 / (3 * MAT.E * I)       # 1.143 mm


def main() -> int:
    work = Path(tempfile.mkdtemp(prefix="fea-check-"))
    stl = work / "beam.stl"
    box = trimesh.creation.box(extents=(L, B, H))
    box.apply_translation((L / 2, B / 2, H / 2))  # corner at origin
    box.export(stl)

    case = LoadCase(
        name="tip-load",
        rationale="analytic validation: clamp x=0 face, 10 N down on the tip face",
        fixed=lambda p: p[:, 0] < 1e-6,
        loaded=lambda p: p[:, 0] > L - 1e-6,
        force=(0.0, 0.0, -F),
        material="PLA",
    )

    res = solve_case(stl, case, mesh_size=3.0, workdir=work)
    tip = res.points[res.node_ids - 1][:, 0] > L - 1e-6
    tip_defl = float(res.disp[tip, 2].mean())

    print(f"tip deflection : {tip_defl:+.4f} mm  (analytic {-DELTA_TIP:+.4f})")
    err = abs(tip_defl + DELTA_TIP) / DELTA_TIP
    # 3D elasticity adds shear deflection and clamp Poisson restraint that
    # beam theory ignores (~1%); beyond 3% something in the chain is broken.
    assert err < 0.03, f"tip deflection {err:.1%} off analytic — pipeline broken"

    # Peak vM away from the clamp underestimates the root fiber stress
    # (the true max is inside the excluded clamp band); it must still be
    # the same order and below the raw clamp-edge concentration.
    print(f"peak vM (free) : {res.peak:.2f} MPa  (root fiber analytic {SIGMA_ROOT:.2f})")
    assert 0.5 * SIGMA_ROOT < res.peak < 2.0 * SIGMA_ROOT, res.peak

    peak, converged, results = converged_peak(stl, case, sizes=(4.0, 3.0), workdir=work)
    print(f"convergence    : {[f'{r.peak:.2f}' for r in results]} MPa -> "
          f"{'converged' if converged else 'NOT converged'}")
    assert converged, "beam peak did not converge — meshing regressed"

    cap = capacity_scale(peak, "PLA")
    print(f"capacity       : {cap:.2f}x the case at {MAT.allowable:.0f} MPa allowable")
    assert cap > 0

    # --- pure bending via a couple: sigma = M c / I, uniform along the span.
    # Exercises the per-node force-field path (couple_about) end to end.
    M = 1000.0  # N*mm -> sigma = 1000 * 5 / 833.3 = 6.0 MPa
    tip_face = lambda p: p[:, 0] > L - 1e-6
    couple = LoadCase(
        name="tip-couple",
        rationale="analytic validation: pure couple about y at the tip face",
        fixed=lambda p: p[:, 0] < 1e-6,
        loaded=tip_face,
        force=couple_about((L, B / 2, H / 2), (0, 1, 0), M),
        material="PLA",
    )
    res_c = solve_case(stl, couple, mesh_size=3.0, workdir=work / "couple")
    sigma = M * (H / 2) / I
    delta_m = M * L ** 2 / (2 * MAT.E * I)  # tip deflection under an end moment
    # Assert on the MID-SPAN stress: pure bending is uniform there, while
    # the load-application field's Saint-Venant tail (~one section depth)
    # outlives the 3mm artifact mask and pollutes the global peak.
    x = res_c.points[res_c.node_ids - 1][:, 0]
    mid = res_c.vm[(x > 0.4 * L) & (x < 0.6 * L)].max()
    print(f"couple mid vM  : {mid:.2f} MPa (pure-bending analytic {sigma:.2f}); "
          f"peak {res_c.peak:.2f}; tip disp {res_c.max_disp:.3f} mm (analytic {delta_m:.3f})")
    assert abs(res_c.max_disp - delta_m) / delta_m < 0.03, \
        "couple magnitude wrong — couple_about scaling broken"
    assert abs(mid - sigma) / sigma < 0.08, mid
    assert res_c.peak < 1.5 * sigma, res_c.peak

    # --- superposition: sum of two solves == one solve of both loads.
    # Tensors add and von Mises is recomputed; this asserts the identity holds.
    both = LoadCase(
        name="tip-both", rationale="force + couple in one case",
        fixed=lambda p: p[:, 0] < 1e-6, loaded=None,
        force=[(tip_face, (0.0, 0.0, -F)),
               (tip_face, couple_about((L, B / 2, H / 2), (0, 1, 0), M))],
        material="PLA",
    )
    res_f = solve_case(stl, case, mesh_size=3.0, workdir=work / "force")
    res_b = solve_case(stl, both, mesh_size=3.0, workdir=work / "both")
    res_s = superpose(res_f, res_c)
    dpk = abs(res_s.peak - res_b.peak) / res_b.peak
    print(f"superposition  : summed peak {res_s.peak:.3f} vs combined-solve "
          f"{res_b.peak:.3f} MPa ({dpk:.1%} apart)")
    assert dpk < 0.02, "superposition identity broken — tensors not adding correctly"

    print("fea/check.py: all assertions passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
