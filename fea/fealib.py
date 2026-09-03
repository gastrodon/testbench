"""Stress analysis for this repo's printed parts: STL -> tet mesh -> linear
static solve -> von Mises field, as a library of scripted, assertable steps.

Pipeline: gmsh (Python API, surface reclassify + 2nd-order tets) -> CalculiX
ccx (from the devshell) -> numpy postprocess. Chosen and validated 2026-09-03
against an analytic cantilever (0.4% on tip deflection) — see fea/README.md
for the selection rationale, the material table's provenance, and the ccx
input-format traps this file works around.

Unit system: mm / N / MPa, consistent throughout (OpenSCAD exports mm).

The two functions that carry the doctrine:

  converged_peak()  Peak von Mises is only meaningful if it stabilizes under
                    mesh refinement — a peak still climbing at the finest mesh
                    is a sharp-corner singularity, and the honest answer is
                    "fillet it or accept local yielding", not a bigger number.
                    Field percentiles are never a capacity metric: they dilute
                    as the mesh refines while the true peak converges.

  capacity()        Load capacity = applied load x allowable / converged peak,
                    where allowable = printed yield x layer-adhesion knockdown.
                    Order-of-magnitude + relative-comparison grade, not a
                    rating: absolute FEA yield prediction for FDM parts needs
                    per-setup coupon calibration (fea/README.md).

Boundary conditions are coordinate predicates over the node array (the
check.py idiom — no GUI face picking). Parts declare load intent in a
loadcases.py next to their .scad source; run one case from the CLI:

  nix develop --command python fea/fealib.py <part.stl> <loadcases.py> <case>
"""

import importlib.util
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

import numpy as np
from scipy.spatial import cKDTree

import gmsh
import meshio


# Nominal datasheet-grade values for FDM prints, flat/on-axis loading.
# E varies only ~10% with raster orientation; STRENGTH is the anisotropic
# axis (~30% loss across raster at 100% infill, worse layer-normal), which
# is what the knockdown derates. Sources and caveats: fea/README.md.
@dataclass(frozen=True)
class Material:
    E: float           # MPa
    nu: float
    yield_flat: float  # MPa, printed-flat tensile yield
    knockdown: float   # layer-adhesion derating applied to yield_flat
    # tonne/mm^3 — the mass unit consistent with mm/N/MPa (1 N = 1 t*mm/s^2),
    # so gravity is 9810 mm/s^2 and rho*V*g comes out in N.
    density: float

    @property
    def allowable(self) -> float:
        return self.yield_flat * self.knockdown


MATERIALS = {
    "PLA": Material(E=3500.0, nu=0.36, yield_flat=50.0, knockdown=0.5,
                    density=1.24e-9),
    "PETG": Material(E=2100.0, nu=0.40, yield_flat=47.0, knockdown=0.6,
                     density=1.27e-9),
}

GRAVITY = 9810.0  # mm/s^2


@dataclass(frozen=True)
class LoadCase:
    """Declared load intent for one part. The rationale is load-bearing
    documentation: design-verify surfaces it verbatim, so it should say in
    words where the load comes from and where it exits the part.

    `force` takes three forms:
      * (fx, fy, fz)            total N, split evenly over `loaded` nodes
      * callable sel_pts->(n,3) per-node forces in N over the `loaded`
                                nodes (see couple_about() for torques)
      * [(pred, spec), ...]     independent patches, each a predicate over
                                all points paired with either form above;
                                `loaded` may then be None
    """
    name: str
    rationale: str
    fixed: Callable[[np.ndarray], np.ndarray]          # pts (N,3) -> bool mask
    loaded: Callable[[np.ndarray], np.ndarray] | None
    force: object
    material: str = "PLA"


def couple_about(point, axis, torque) -> Callable[[np.ndarray], np.ndarray]:
    """Per-node force field applying a pure couple: `torque` (N*mm) about
    the axis through `point` along `axis`, zero net force. Use as a
    LoadCase force callable over the nodes the torque enters through."""
    point = np.asarray(point, float)
    axis = np.asarray(axis, float)
    axis = axis / np.linalg.norm(axis)

    def field(pts: np.ndarray) -> np.ndarray:
        r = pts - point
        r_perp = r - np.outer(r @ axis, axis)
        f = np.cross(axis, r_perp)              # tangential, ~ |r_perp|
        f -= f.mean(axis=0)                     # zero the net force...
        t = float(np.einsum("ij,ij->", np.cross(r, f),
                            np.broadcast_to(axis, f.shape)))
        assert abs(t) > 1e-12, "couple_about: nodes are collinear with the axis"
        return f * (torque / t)                 # ...then rescale to the torque
    return field


def nodal_loads(pts: np.ndarray, case: LoadCase) -> tuple[np.ndarray, np.ndarray]:
    """Resolve a LoadCase's force declaration to (node_ids, forces (n,3))."""
    patches = case.force if isinstance(case.force, list) \
        else [(case.loaded, case.force)]
    ids, forces = [], []
    for pred, spec in patches:
        sel = np.flatnonzero(pred(pts))
        assert len(sel) > 0, f"load predicate matched no nodes ({case.name})"
        if callable(spec):
            f = np.asarray(spec(pts[sel]), float)
            assert f.shape == (len(sel), 3), f.shape
        else:
            f = np.tile(np.asarray(spec, float) / len(sel), (len(sel), 1))
        ids.append(sel + 1)
        forces.append(f)
    return np.concatenate(ids), np.vstack(forces)


@dataclass
class SolveResult:
    mesh_size: float
    points: np.ndarray      # (N,3) node coords, 0-indexed
    node_ids: np.ndarray    # ccx node ids for the result arrays below
    S: np.ndarray           # (n,6) nodal stress sxx,syy,szz,sxy,syz,szx, MPa
    vm: np.ndarray          # nodal von Mises, MPa
    free_mask: np.ndarray   # False within clamp_exclude of a fixed node
    disp: np.ndarray        # (n,3) nodal displacement, mm
    n_fixed: int
    n_loaded: int

    @property
    def vm_free(self) -> np.ndarray:
        return np.where(self.free_mask, self.vm, 0.0)

    @property
    def peak(self) -> float:
        """Peak von Mises away from the artificial clamp edge."""
        return float(self.vm_free.max())

    @property
    def max_disp(self) -> float:
        return float(np.linalg.norm(self.disp, axis=1).max())


def von_mises(S: np.ndarray) -> np.ndarray:
    sxx, syy, szz, sxy, syz, szx = S.T
    return np.sqrt(0.5 * ((sxx - syy) ** 2 + (syy - szz) ** 2 + (szz - sxx) ** 2)
                   + 3 * (sxy ** 2 + syz ** 2 + szx ** 2))


def superpose(*results: SolveResult) -> SolveResult:
    """Sum linear solves of the SAME mesh (same part, same mesh size,
    different load cases). Stress TENSORS add; von Mises does not — it is
    recomputed from the summed tensor. The free mask intersects, so a node
    near any case's clamp stays excluded."""
    a = results[0]
    for b in results[1:]:
        assert b.mesh_size == a.mesh_size and np.array_equal(b.node_ids, a.node_ids), \
            "superpose: results are not from identical meshes"
    S = sum(r.S for r in results)
    mask = np.logical_and.reduce([r.free_mask for r in results])
    return SolveResult(mesh_size=a.mesh_size, points=a.points, node_ids=a.node_ids,
                       S=S, vm=von_mises(S), free_mask=mask,
                       disp=sum(r.disp for r in results),
                       n_fixed=a.n_fixed, n_loaded=sum(r.n_loaded for r in results))


def tet_mesh(stl_path: Path, msh_path: Path, size_max: float, size_min: float = 1.0):
    """STL -> 2nd-order tet mesh. Reclassifies the faceted surface rather than
    inheriting OpenSCAD's skinny triangles as element faces."""
    gmsh.initialize()
    try:
        gmsh.option.setNumber("General.Terminal", 0)
        gmsh.merge(str(stl_path))
        gmsh.model.mesh.classifySurfaces(40 * np.pi / 180, True, True, np.pi)
        gmsh.model.mesh.createGeometry()
        surfs = [s[1] for s in gmsh.model.getEntities(2)]
        loop = gmsh.model.geo.addSurfaceLoop(surfs)
        gmsh.model.geo.addVolume([loop])
        gmsh.model.geo.synchronize()
        gmsh.option.setNumber("Mesh.MeshSizeMax", size_max)
        gmsh.option.setNumber("Mesh.MeshSizeMin", size_min)
        gmsh.option.setNumber("Mesh.ElementOrder", 2)
        # Curved midside nodes invert coarse tets (ccx: "nonpositive
        # jacobian"). Level 1 untangles them; level 2 hangs for 10+ minutes
        # on ~10k-tet parts — do not raise this.
        gmsh.option.setNumber("Mesh.HighOrderOptimize", 1)
        gmsh.model.mesh.generate(3)
        gmsh.write(str(msh_path))
    finally:
        gmsh.finalize()


def mesh_to_inp(msh_path: Path, inp_path: Path) -> np.ndarray:
    """Translate the gmsh mesh to a ccx-readable Abaqus-format mesh include.
    Returns the node coordinate array (ccx node id = row index + 1).

    Two silent ccx traps handled here, both misreported by ccx as bogus
    downstream errors ("node set not defined", "value > nk"):
      * ccx input fields max 20 chars; meshio writes 22-char floats.
      * meshio labels tet10s C3D10MH, which ccx does not know.
    """
    m = meshio.read(msh_path)
    tet_blocks = [c.data for c in m.cells if c.type == "tetra10"]
    assert tet_blocks, f"no tetra10 cells in {msh_path}: {[c.type for c in m.cells]}"
    mesh = meshio.Mesh(points=m.points, cells=[("tetra10", np.vstack(tet_blocks))])
    meshio.write(inp_path, mesh)

    out, in_node = [], False
    for l in inp_path.read_text().splitlines():
        if l.startswith("*"):
            in_node = l.upper().startswith("*NODE")
            l = l.replace("*ELEMENT, TYPE=C3D10MH", "*ELEMENT, TYPE=C3D10, ELSET=EALL")
        elif in_node:
            f = l.split(",")
            l = f[0] + ", " + ", ".join(f"{float(v):.10g}" for v in f[1:])
        out.append(l)
    inp_path.write_text("\n".join(out) + "\n")
    return mesh.points


def _nset(name: str, ids: np.ndarray) -> str:
    lines = [f"*NSET, NSET={name}"]
    for i in range(0, len(ids), 8):
        lines.append(", ".join(str(v) for v in ids[i:i + 8]))
    return "\n".join(lines)


def parse_frd(path: Path) -> dict:
    """Nodal result blocks from a ccx .frd. Block headers advertise more
    components than some blocks store (DISP says 4, writes 3) — parse the
    12-char fields actually present on each line."""
    blocks, lines, i = {}, path.read_text().splitlines(), 0
    while i < len(lines):
        l = lines[i]
        if l.startswith(" -4"):
            name, ncomp = l.split()[1], int(l.split()[2])
            i += 1
            while lines[i].startswith(" -5"):
                i += 1
            rows = {}
            while i < len(lines) and lines[i].startswith(" -1"):
                ln = lines[i]
                nf = (len(ln) - 13) // 12
                rows[int(ln[3:13])] = [float(ln[13 + 12 * k:25 + 12 * k])
                                       for k in range(min(ncomp, nf))]
                i += 1
            blocks[name] = rows
        else:
            i += 1
    return blocks


def solve_case(stl_path: Path, case: LoadCase, mesh_size: float,
               workdir: Path | None = None, clamp_exclude: float = 3.0) -> SolveResult:
    """One linear static solve of `case` on `stl_path` at the given mesh size."""
    assert shutil.which("ccx"), "ccx not on PATH — run inside `nix develop`"
    mat = MATERIALS[case.material]
    stl_path = Path(stl_path).resolve()
    if workdir is None:
        workdir = Path(tempfile.mkdtemp(prefix="fea-"))
    workdir.mkdir(parents=True, exist_ok=True)
    name = stl_path.stem

    tet_mesh(stl_path, workdir / f"{name}.msh", size_max=mesh_size)
    pts = mesh_to_inp(workdir / f"{name}.msh", workdir / f"{name}_mesh.inp")

    node_id = np.arange(1, len(pts) + 1)
    fixed = node_id[case.fixed(pts)]
    assert len(fixed) > 3, f"fixed predicate matched {len(fixed)} nodes"
    load_ids, load_f = nodal_loads(pts, case)

    cloads = "\n".join(
        f"{nid}, {dof}, {comp:.9g}"
        for nid, f in zip(load_ids, load_f)
        for dof, comp in ((1, f[0]), (2, f[1]), (3, f[2])) if comp != 0.0
    )
    deck = f"""*INCLUDE, INPUT={name}_mesh.inp
{_nset("FIXED", fixed)}
*MATERIAL, NAME=MAT
*ELASTIC
{mat.E}, {mat.nu}
*SOLID SECTION, ELSET=EALL, MATERIAL=MAT
*STEP
*STATIC
*BOUNDARY
FIXED, 1, 3
*CLOAD
{cloads}
*NODE FILE
U
*EL FILE
S
*END STEP
"""
    (workdir / f"{name}.inp").write_text(deck)
    r = subprocess.run(["ccx", "-i", name], cwd=workdir, capture_output=True, text=True)
    # ccx prints its pass-1 allocation table in full even when pass 2 aborts;
    # only this banner proves a completed solve.
    if "Job finished" not in r.stdout:
        raise RuntimeError(f"ccx failed in {workdir}:\n{r.stdout[-2000:]}\n{r.stderr[-500:]}")

    frd = parse_frd(workdir / f"{name}.frd")
    nid = np.array(sorted(frd["STRESS"]))
    S = np.array([frd["STRESS"][n] for n in nid])
    disp = np.array([frd["DISP"][n] for n in nid])

    # Both BC idealizations produce artifact stress at their own footprint:
    # a rigid clamp concentrates at its edge, and concentrated nodal loads
    # (equal per node, inconsistent for quadratic elements) spike locally at
    # the application patch. Mask near both for peak-finding — stress AT a
    # bearing surface needs a modelled contact (Tier 3), not a *CLOAD.
    xyz = pts[nid - 1]
    d_fixed, _ = cKDTree(pts[fixed - 1]).query(xyz)
    d_load, _ = cKDTree(pts[np.unique(load_ids) - 1]).query(xyz)
    mask = (d_fixed >= clamp_exclude) & (d_load >= clamp_exclude)

    return SolveResult(mesh_size=mesh_size, points=pts, node_ids=nid,
                       S=S, vm=von_mises(S), free_mask=mask,
                       disp=disp, n_fixed=len(fixed),
                       n_loaded=len(np.unique(load_ids)))


def converged_peak(stl_path: Path, case: LoadCase,
                   sizes: tuple[float, ...] = (4.0, 2.5), rtol: float = 0.10,
                   workdir: Path | None = None) -> tuple[float, bool, list[SolveResult]]:
    """Solve at successive refinements; return (finest peak, converged?, results).

    converged=False means the peak moved more than rtol between the last two
    meshes — a sharp corner concentrating without bound. Report it as such;
    do not average it away or quote the coarse number.
    """
    results = [solve_case(stl_path, case, s, workdir=workdir) for s in sizes]
    peaks = [r.peak for r in results]
    converged = len(peaks) > 1 and abs(peaks[-1] - peaks[-2]) <= rtol * peaks[-1]
    return peaks[-1], converged, results


def capacity_scale(peak_vm: float, material: str) -> float:
    """How many times the declared load case the part sustains at the
    material allowable. Dimensionless on purpose: it scales a force case,
    a torque case, or a mixed one identically, because linear elasticity
    scales the whole field together. >1 means margin; <1 means the case
    as declared already exceeds the allowable."""
    return MATERIALS[material].allowable / peak_vm


def hotspots(res: SolveResult, n: int = 5, min_sep: float = 8.0) -> list[tuple[np.ndarray, float]]:
    """Top-n stress locations, greedily separated so one concentration
    doesn't fill every slot with its own neighbors."""
    xyz = res.points[res.node_ids - 1]
    picked: list[tuple[np.ndarray, float]] = []
    for i in np.argsort(-res.vm_free):
        if len(picked) >= n or res.vm_free[i] <= 0:
            break
        if all(np.linalg.norm(xyz[i] - p) > min_sep for p, _ in picked):
            picked.append((xyz[i], float(res.vm_free[i])))
    return picked


def _load_case(loadcases_py: Path, case_name: str) -> LoadCase:
    spec = importlib.util.spec_from_file_location("loadcases", loadcases_py)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.LOADCASES[case_name]


def main(argv: list[str]) -> int:
    if len(argv) != 4:
        print(__doc__)
        return 2
    stl, lc_py, case_name = Path(argv[1]), Path(argv[2]), argv[3]
    case = _load_case(lc_py, case_name)
    mat = MATERIALS[case.material]

    peak, converged, results = converged_peak(stl, case)
    fine = results[-1]
    print(f"{stl.name} / case '{case.name}' ({case.material}): {case.rationale}")
    print(f"load over {fine.n_loaded} nodes, {fine.n_fixed} fixed")
    for r in results:
        print(f"  mesh {r.mesh_size:4.1f} mm: {len(r.points):6d} nodes, "
              f"peak vM {r.peak:7.2f} MPa, max disp {r.max_disp:.3f} mm")
    print(f"peak von Mises  : {peak:.2f} MPa "
          f"({'converged' if converged else 'NOT CONVERGED — sharp corner, fillet or accept local yield'})")
    print(f"allowable       : {mat.allowable:.0f} MPa "
          f"({case.material} yield {mat.yield_flat:.0f} x {mat.knockdown} knockdown)")
    print(f"capacity        : {capacity_scale(peak, case.material):.2f}x the declared "
          f"load case (order-of-magnitude; see fea/README.md)")
    print("hotspots:")
    for p, v in hotspots(fine):
        print(f"  ({p[0]:7.1f},{p[1]:7.1f},{p[2]:7.1f})  vM {v:7.2f} MPa")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
