"""Multi-part assembly analysis: several STLs in one CalculiX solve, joined
by bonded (*TIE) or frictional contact (*CONTACT PAIR) interfaces.

Extends fealib.py's single-part pipeline; read that module and fea/README.md
first. Same unit system (mm/N/MPa, tonne mass), same declared-intent rule:
an assembly's parts, joints, supports and loads are data in an
`assemblies.py` next to the .scad sources, never invented by the analyst.

Doctrine (fea/README.md has the long version):
  * Tie-vs-contact is intent. A joint the model declares rigid gets Tie;
    a joint that bears, slides, or can lift gets Contact.
  * Hybrid models are the default: Tie every joint except the one under
    investigation. Full-contact assemblies are slow, fragile, and answer
    no question better.
  * Every part must be grounded — through `fixed`, a Tie chain to a
    grounded part, or `stabilize=True` (weak springs, for parts held only
    by contact). This is validated BEFORE the solver runs, because ccx's
    response to a floating part is a diverging solve with cryptic output.

  nix develop --command python fea/assembly.py <assemblies.py> <case> [mesh_size]
"""

import importlib.util
import subprocess
import sys
import tempfile
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

import numpy as np
from scipy.spatial import cKDTree

import meshio

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fealib import (GRAVITY, MATERIALS, LoadCase, nodal_loads, parse_frd,
                    tet_mesh, von_mises)


# ---------------------------------------------------------------- declarations

@dataclass(frozen=True)
class Part:
    stl: str                 # path, relative to the assemblies.py that names it
    material: str = "PLA"
    stabilize: bool = False  # weak grounding springs for contact-only parts


@dataclass(frozen=True)
class Tie:
    """Bonded joint — for interfaces the design itself declares rigid."""
    a: str                   # part names; a's faces become the slave side
    b: str
    near: Callable | None = None   # optional centroid predicate narrowing the interface
    tol: float = 1.0         # mm; must cover the printed fit gap


@dataclass(frozen=True)
class Contact:
    """Unilateral frictional joint — parts may bear, slide, and separate."""
    a: str                   # slave side: put the finer-meshed part here
    b: str
    mu: float = 0.35         # dry PLA-on-PLA ballpark; declare, don't inherit
    near: Callable | None = None
    tol: float = 2.0         # mm; interface faces auto-detected within this


@dataclass(frozen=True)
class AssemblyCase:
    name: str
    rationale: str
    parts: dict              # name -> Part
    interfaces: list         # Tie / Contact
    fixed: list              # (part_name, pts-predicate)
    loads: list              # (part_name, pts-predicate, force spec per LoadCase)
    gravity: bool = False


# ---------------------------------------------------------------- results

@dataclass
class PartResult:
    name: str
    material: str
    points: np.ndarray       # (N,3) this part's node coords
    node_ids: np.ndarray     # global ccx ids for the arrays below
    S: np.ndarray
    vm: np.ndarray
    free_mask: np.ndarray
    disp: np.ndarray

    @property
    def vm_free(self):
        return np.where(self.free_mask, self.vm, 0.0)

    @property
    def peak(self) -> float:
        return float(self.vm_free.max())

    @property
    def max_disp(self) -> float:
        return float(np.linalg.norm(self.disp, axis=1).max())


@dataclass
class InterfaceResult:
    kind: str                # "tie" | "contact"
    a: str
    b: str
    n_slave_faces: int
    n_master_faces: int
    # contact only (None for ties): from *CONTACT FILE output on slave nodes
    n_slave_nodes: int | None = None
    declared_area: float | None = None   # mm^2, the whole declared interface
    bearing_area: float | None = None    # mm^2 actually carrying pressure
    force_normal: float | None = None    # N transferred across the interface
    pressure_peak: float | None = None   # MPa, from -n.sigma.n
    pressure_mean: float | None = None   # MPa = force_normal / bearing_area
    pressure_peak_ccx: float | None = None  # MPa, ccx CPRESS — diagnostic only
    n_engaged: int | None = None         # slave FACES carrying pressure
    open_max: float | None = None        # mm — see the COPEN caveat below
    slip_max: float | None = None        # mm

    @property
    def bearing_fraction(self) -> float | None:
        """Share of the declared interface AREA actually bearing. Well under
        1.0 means part of the joint has separated — this, not open_max, is
        the separation signal ccx gives honestly. Area-based rather than
        node-based on purpose: corner nodes of quadratic faces carry no
        pressure even in full contact, so node counts read ~70% engaged for
        a perfectly seated joint."""
        if self.bearing_area is None or not self.declared_area:
            return None
        return self.bearing_area / self.declared_area


@dataclass
class AssemblyResult:
    parts: dict              # name -> PartResult
    interfaces: list         # InterfaceResult, same order as declared
    workdir: Path

    @property
    def peak(self) -> float:
        return max(p.peak for p in self.parts.values())


# ---------------------------------------------------------------- meshing

# Abaqus C3D10 faces, 0-based local indices: F1=1-2-3, F2=1-4-2, F3=2-4-3,
# F4=3-4-1 in the manual's 1-based numbering, each with its three midside
# nodes. meshio's tetra10 ordering (corners, then mid01, mid12, mid20,
# mid03, mid13, mid23) is identical to Abaqus C3D10's, so connectivity is
# written straight through — the tied-beam gate in check_assembly.py would
# fail loudly if that ever stopped being true.
_FACES = [(0, 1, 2), (0, 3, 1), (1, 3, 2), (2, 3, 0)]
_FACE_MIDS = [(4, 5, 6), (7, 8, 4), (8, 9, 5), (9, 7, 6)]


def _mesh_part(stl: Path, size: float, workdir: Path, name: str):
    """Mesh one STL to (points, tet10 connectivity). meshio's gmsh reader
    permutes tetra10 midside nodes into meshio order, which matches Abaqus
    C3D10 — the same path fealib's validated single-part pipeline rides."""
    msh = workdir / f"{name}.msh"
    tet_mesh(stl, msh, size_max=size)
    m = meshio.read(msh)
    tets = np.vstack([c.data for c in m.cells if c.type == "tetra10"])
    return m.points, tets


def _boundary_faces(tets: np.ndarray, points: np.ndarray):
    """(elem_idx, face_num 1..4, corner triple, midside triple) for every
    exterior face. Midsides are carried because contact pressure lives on
    them: for a quadratic face under uniform pressure the consistent nodal
    loads are zero at the corners and p*A/3 at each midside, so corner
    CPRESS is ~0 even in full contact."""
    count = Counter()
    for f in _FACES:
        for tri in tets[:, f]:
            count[frozenset(tri)] += 1
    out = []
    for ei, tet in enumerate(tets):
        for fi, (f, mids) in enumerate(zip(_FACES, _FACE_MIDS)):
            tri = tet[list(f)]
            if count[frozenset(tri)] != 1:
                continue
            a, b, c = points[tri]
            n = np.cross(b - a, c - a)
            ctr = (a + b + c) / 3.0
            # Orient OUTWARD: away from the tet's fourth corner. This is what
            # makes "do these two surfaces face each other" answerable, which
            # is how a real contact patch is told apart from the side walls
            # that merely pass close to it.
            opp = points[tet[[i for i in range(4) if i not in f][0]]]
            if np.dot(n, ctr - opp) < 0:
                n = -n
            out.append((ei, fi + 1, tri, tet[list(mids)], ctr,
                        n / max(np.linalg.norm(n), 1e-12)))
    return out


# ---------------------------------------------------------------- deck pieces

def _grounding_check(case: AssemblyCase):
    """Union-find over Tie edges from fixed parts; contact does not ground."""
    grounded = {p for p, _ in case.fixed}
    edges = [(i.a, i.b) for i in case.interfaces if isinstance(i, Tie)]
    changed = True
    while changed:
        changed = False
        for a, b in edges:
            if (a in grounded) != (b in grounded):
                grounded |= {a, b}
                changed = True
    floating = [n for n, p in case.parts.items()
                if n not in grounded and not p.stabilize]
    assert not floating, (
        f"assembly '{case.name}': part(s) {floating} are held only by contact "
        f"— ground them via `fixed`, a Tie chain, or Part(stabilize=True). "
        f"ccx's response to a floating part is a diverging solve with output "
        f"that names none of this.")


def solve_assembly(case: AssemblyCase, mesh_size: float = 3.0,
                   workdir: Path | None = None, base_dir: Path | None = None,
                   clamp_exclude: float = 3.0) -> AssemblyResult:
    _grounding_check(case)
    if workdir is None:
        workdir = Path(tempfile.mkdtemp(prefix="fea-asm-"))
    workdir.mkdir(parents=True, exist_ok=True)
    base_dir = Path(base_dir) if base_dir else Path.cwd()

    # --- mesh every part, assign global id ranges ---
    meshes = {}   # name -> dict(points, tets, node_off, elem_off, faces)
    node_off = elem_off = 0
    for name, part in case.parts.items():
        pts, tets = _mesh_part((base_dir / part.stl).resolve(), mesh_size,
                               workdir, name)
        meshes[name] = dict(points=pts, tets=tets, node_off=node_off,
                            elem_off=elem_off,
                            faces=_boundary_faces(tets, pts))
        node_off += len(pts)
        elem_off += len(tets)

    deck = ["*HEADING", f"assembly {case.name}"]

    # --- nodes + elements, globally numbered ---
    for name, m in meshes.items():
        deck.append("*NODE")
        for i, p in enumerate(m["points"]):
            deck.append(f"{m['node_off'] + i + 1}, "
                        f"{p[0]:.10g}, {p[1]:.10g}, {p[2]:.10g}")
        deck.append(f"*ELEMENT, TYPE=C3D10, ELSET=E_{name}")
        for i, tet in enumerate(m["tets"]):
            deck.append(f"{m['elem_off'] + i + 1}, "
                        + ", ".join(str(m["node_off"] + n + 1) for n in tet))

    # --- materials + sections (one section per part, materials shared) ---
    for mat_name in sorted({p.material for p in case.parts.values()}):
        mat = MATERIALS[mat_name]
        deck += [f"*MATERIAL, NAME={mat_name}", "*ELASTIC", f"{mat.E}, {mat.nu}",
                 "*DENSITY", f"{mat.density}"]
    for name, part in case.parts.items():
        deck.append(f"*SOLID SECTION, ELSET=E_{name}, MATERIAL={part.material}")

    # --- interface surfaces, auto-detected by face-centroid proximity ---
    def face_geom(m):
        return (np.array([f[4] for f in m["faces"]]),
                np.array([f[5] for f in m["faces"]]))

    def surface(idx, side, m, sel):
        """Emit a *SURFACE and return (name, per-face geometry). The face
        list carries each face's area and its global midside node ids —
        the pair that turns nodal CPRESS into a bearing area and a
        transferred force."""
        sname = f"IF{idx}_{side}"
        deck.append(f"*SURFACE, NAME={sname}, TYPE=ELEMENT")
        faces = []
        for k in sel:
            ei, fi, tri, mids, ctr, nrm = m["faces"][k]
            deck.append(f"{m['elem_off'] + ei + 1}, S{fi}")
            a, b, c = m["points"][tri]
            area = 0.5 * float(np.linalg.norm(np.cross(b - a, c - a)))
            faces.append((area, [int(n) + m["node_off"] + 1 for n in mids],
                          nrm))
        return sname, faces

    iface_meta = []
    contact_present = False
    for idx, itf in enumerate(case.interfaces):
        ma, mb = meshes[itf.a], meshes[itf.b]
        ca, na = face_geom(ma)
        cb, nb = face_geom(mb)
        find_tol = max(itf.tol, 2.0)

        def facing(c_self, n_self, c_other, n_other):
            """Close to the other surface AND facing it. Proximity alone
            also catches the side walls that merely run past the joint —
            they then dilute the bearing area and add phantom transferred
            force, because they share edge nodes with the real patch."""
            d, j = cKDTree(c_other).query(c_self)
            opposed = np.einsum("ij,ij->i", n_self, n_other[j]) < -0.5
            return np.flatnonzero((d < find_tol) & opposed)

        sel_a = facing(ca, na, cb, nb)
        sel_b = facing(cb, nb, ca, na)
        if itf.near is not None:
            sel_a = sel_a[itf.near(ca[sel_a])]
            sel_b = sel_b[itf.near(cb[sel_b])]
        assert len(sel_a) and len(sel_b), (
            f"assembly '{case.name}': interface {itf.a}<->{itf.b} matched "
            f"{len(sel_a)}/{len(sel_b)} faces — parts further apart than "
            f"tol={find_tol}mm, not facing each other, or the `near` "
            f"predicate excludes everything")
        s_a, slave_faces = surface(idx, "A", ma, sel_a)   # slave
        s_b, _ = surface(idx, "B", mb, sel_b)             # master
        if isinstance(itf, Tie):
            deck += [f"*TIE, NAME=T{idx}, POSITION TOLERANCE={itf.tol}",
                     f"{s_a}, {s_b}"]
        else:
            contact_present = True
            # Pressure-overclosure slope: interface pressure is set by
            # equilibrium, so results are insensitive to K within reason —
            # it only trades penetration depth against conditioning.
            K = 10.0 * min(MATERIALS[case.parts[itf.a].material].E,
                           MATERIALS[case.parts[itf.b].material].E) / mesh_size
            deck += [f"*SURFACE INTERACTION, NAME=I{idx}",
                     "*SURFACE BEHAVIOR, PRESSURE-OVERCLOSURE=LINEAR",
                     f"{K:.6g}",
                     "*FRICTION",
                     f"{itf.mu}, {K / 10:.6g}",
                     f"*CONTACT PAIR, INTERACTION=I{idx}, TYPE=SURFACE TO SURFACE",
                     f"{s_a}, {s_b}"]
        iface_meta.append((itf, len(sel_a), len(sel_b), slave_faces))

    # --- weak grounding springs for stabilize parts ---
    spring_eid = elem_off
    for name, part in case.parts.items():
        if not part.stabilize:
            continue
        m = meshes[name]
        # a spread of anchor nodes: extreme node along each axis direction
        anchors = sorted({int(np.argmin(m["points"][:, ax])) for ax in range(3)}
                         | {int(np.argmax(m["points"][:, ax])) for ax in range(3)})
        for dof in (1, 2, 3):
            elset = f"STAB_{name}_{dof}"
            deck.append(f"*ELEMENT, TYPE=SPRING1, ELSET={elset}")
            for n in anchors:
                spring_eid += 1
                deck.append(f"{spring_eid}, {m['node_off'] + n + 1}")
            # 1 N/mm: orders below structural stiffness, enough to pin
            # rigid-body modes while contact seats
            deck += [f"*SPRING, ELSET={elset}", f"{dof}", "1.0"]

    # --- fixtures ---
    fixed_global = []
    for pname, pred in case.fixed:
        m = meshes[pname]
        ids = np.flatnonzero(pred(m["points"])) + m["node_off"] + 1
        assert len(ids) > 3, f"fixed predicate on {pname} matched {len(ids)} nodes"
        fixed_global.append(ids)
    fixed_global = np.concatenate(fixed_global) if fixed_global else np.array([], int)
    deck.append("*NSET, NSET=FIXED")
    for i in range(0, len(fixed_global), 8):
        deck.append(", ".join(str(v) for v in fixed_global[i:i + 8]))

    # --- loads, via fealib's declaration forms ---
    load_lines, load_ids_global = [], []
    for pname, pred, spec in case.loads:
        m = meshes[pname]
        lc = LoadCase(name=case.name, rationale="", fixed=lambda p: p[:, 0] < np.inf,
                      loaded=pred, force=spec)
        ids, forces = nodal_loads(m["points"], lc)
        ids = ids + m["node_off"]
        load_ids_global.append(ids)
        for nid, f in zip(ids, forces):
            for dof, comp in ((1, f[0]), (2, f[1]), (3, f[2])):
                if comp != 0.0:
                    load_lines.append(f"{nid}, {dof}, {comp:.9g}")
    load_ids_global = np.concatenate(load_ids_global) if load_ids_global \
        else np.array([], int)

    # --- step ---
    deck.append("*STEP")
    if contact_present:
        # contact is unilateral -> iterative; ramp the load in increments
        deck += ["*STATIC", "0.1, 1.0, 1e-5, 0.25"]
    else:
        deck.append("*STATIC")
    deck += ["*BOUNDARY", "FIXED, 1, 3"]
    if load_lines:
        deck.append("*CLOAD")
        deck += load_lines
    if case.gravity:
        deck.append("*DLOAD")
        for name in case.parts:
            deck.append(f"E_{name}, GRAV, {GRAVITY}, 0., 0., -1.")
    deck += ["*NODE FILE", "U", "*EL FILE", "S"]
    if contact_present:
        deck += ["*CONTACT FILE", "CDIS, CSTR"]
    deck.append("*END STEP")

    (workdir / "asm.inp").write_text("\n".join(deck) + "\n")
    r = subprocess.run(["ccx", "-i", "asm"], cwd=workdir,
                       capture_output=True, text=True)
    if "Job finished" not in r.stdout:
        raise RuntimeError(f"ccx failed in {workdir}:\n{r.stdout[-2500:]}\n"
                           f"{r.stderr[-500:]}")

    return _postprocess(case, meshes, iface_meta, fixed_global,
                        load_ids_global, workdir, clamp_exclude)


# ---------------------------------------------------------------- postprocess

def _parse_frd_labeled(path: Path):
    """Like fealib.parse_frd, but keeps EVERY block with its -5 component
    labels. An incremented (contact) step writes one set of blocks per
    increment, so the caller must take the LAST — the first is the initial
    fraction of the ramped load and looks like a converged answer at a
    tenth the magnitude."""
    blocks, lines, i = [], path.read_text().splitlines(), 0
    while i < len(lines):
        l = lines[i]
        if l.startswith(" -4"):
            name, ncomp = l.split()[1], int(l.split()[2])
            labels, i = [], i + 1
            while lines[i].startswith(" -5"):
                labels.append(lines[i].split()[1])
                i += 1
            rows = {}
            while i < len(lines) and lines[i].startswith(" -1"):
                ln = lines[i]
                nf = (len(ln) - 13) // 12
                rows[int(ln[3:13])] = [float(ln[13 + 12 * k:25 + 12 * k])
                                       for k in range(min(ncomp, nf))]
                i += 1
            blocks.append((name, labels, rows))
        else:
            i += 1
    return blocks


def _postprocess(case, meshes, iface_meta, fixed_global, load_ids_global,
                 workdir, clamp_exclude) -> AssemblyResult:
    blocks = _parse_frd_labeled(workdir / "asm.frd")

    def last(pred):
        """Final increment of the matching block — see _parse_frd_labeled."""
        hits = [(lab, rows) for name, lab, rows in blocks if pred(name, lab)]
        return hits[-1] if hits else (None, None)

    _, stress = last(lambda n, lab: n == "STRESS")
    _, disp = last(lambda n, lab: n == "DISP" and lab[0].startswith("D"))
    con_labels, con_rows = last(
        lambda n, lab: any(x.startswith("CPRESS") for x in lab))

    all_pts = np.vstack([m["points"] for m in meshes.values()])
    artifacts = np.concatenate([fixed_global, load_ids_global])
    art_tree = cKDTree(all_pts[artifacts - 1]) if len(artifacts) else None

    parts = {}
    for name, m in meshes.items():
        lo, hi = m["node_off"] + 1, m["node_off"] + len(m["points"])
        nid = np.array([n for n in sorted(stress) if lo <= n <= hi])
        S = np.array([stress[n] for n in nid])
        d = np.array([disp[n] for n in nid])
        xyz = all_pts[nid - 1]
        mask = np.ones(len(nid), bool)
        if art_tree is not None:
            dist, _ = art_tree.query(xyz)
            mask = dist >= clamp_exclude
        parts[name] = PartResult(name=name, material=case.parts[name].material,
                                 points=m["points"], node_ids=nid, S=S,
                                 vm=von_mises(S), free_mask=mask, disp=d)

    # ccx writes all six contact components in ONE block (COPEN, CSLIP1/2,
    # CPRESS, CSHEAR1/2), on every node in the model — zero off the contact
    # surfaces. Separation is read from CPRESS going to zero on slave nodes,
    # NOT from COPEN: ccx drops a separated node from its active set and
    # reports COPEN 0 for it, so COPEN never goes positive even when the
    # displacements plainly show a face lifting (verified on a tipping
    # block, fea/README.md).
    ci = {}
    if con_rows:
        ci = {lab: i for i, lab in enumerate(con_labels)}

    ifaces = []
    for itf, nsa, nsb, slave_faces in iface_meta:
        if isinstance(itf, Tie):
            ifaces.append(InterfaceResult("tie", itf.a, itf.b, nsa, nsb))
            continue
        areas = np.array([a for a, _, _ in slave_faces])
        res = InterfaceResult("contact", itf.a, itf.b, nsa, nsb,
                              declared_area=float(areas.sum()))
        res.n_slave_nodes = len({n for _, mids, _ in slave_faces for n in mids})

        # Interface pressure from the STRESS field, not from ccx's CPRESS.
        # p = -n.sigma.n on the interface face: it comes out of the same
        # validated stress output the rest of this pipeline reports, and it
        # satisfies equilibrium. CPRESS is ccx's own contact bookkeeping,
        # divided by nodal tributary areas whose convention is not
        # documented — measured 23-33% high on a block whose transferred
        # force is known exactly, and the error moved with the geometry of
        # the OTHER body, so it is not a constant to divide out.
        # Midside nodes: for a quadratic triangle the 3-midpoint rule is
        # exact for a quadratic field, so area * mean(midside p) is an
        # exact face integral.
        pmid = np.empty((len(slave_faces), 3))
        for k, (_, mids, nrm) in enumerate(slave_faces):
            for j, n in enumerate(mids):
                s = stress.get(n)
                if s is None:
                    pmid[k, j] = 0.0
                    continue
                sxx, syy, szz, sxy, syz, szx = s
                sig = np.array([[sxx, sxy, szx], [sxy, syy, syz],
                                [szx, syz, szz]])
                pmid[k, j] = -float(nrm @ sig @ nrm)   # compression positive
        face_p = pmid.mean(axis=1)
        peak = float(pmid.max()) if pmid.size else 0.0
        # A face bears if it is in compression; tension across a contact
        # interface is not physical, it is a face that has let go.
        bearing = face_p > 0.01 * max(peak, 1e-12)
        res.pressure_peak = peak
        res.force_normal = float((areas[bearing] * face_p[bearing]).sum())
        res.bearing_area = float(areas[bearing].sum())
        res.pressure_mean = (res.force_normal / res.bearing_area
                             if res.bearing_area > 0 else 0.0)
        res.n_engaged = int(bearing.sum())

        if con_rows:
            allv = np.array([con_rows[n] for _, mids, _ in slave_faces
                             for n in mids if n in con_rows])
            if len(allv):
                res.pressure_peak_ccx = float(allv[:, ci["CPRESS"]].max())
                if "COPEN" in ci:
                    res.open_max = float(allv[:, ci["COPEN"]].max())
                slip_k = [ci[k] for k in ("CSLIP1", "CSLIP2") if k in ci]
                if slip_k:
                    res.slip_max = float(np.abs(allv[:, slip_k]).max())
        ifaces.append(res)

    return AssemblyResult(parts=parts, interfaces=ifaces, workdir=workdir)


# ---------------------------------------------------------------- CLI

def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    asm_py, case_name = Path(argv[1]).resolve(), argv[2]
    mesh_size = float(argv[3]) if len(argv) > 3 else 3.0
    spec = importlib.util.spec_from_file_location("assemblies", asm_py)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    case = mod.ASSEMBLIES[case_name]

    res = solve_assembly(case, mesh_size=mesh_size, base_dir=asm_py.parent)
    print(f"assembly '{case.name}' ({len(case.parts)} parts, mesh {mesh_size}mm): "
          f"{case.rationale}")
    for name, p in res.parts.items():
        mat = MATERIALS[p.material]
        print(f"  {name:16s} peak vM {p.peak:7.2f} MPa "
              f"(allowable {mat.allowable:.0f}, {p.material}), "
              f"max disp {p.max_disp:.3f} mm")
    for r in res.interfaces:
        if r.kind == "tie":
            print(f"  tie     {r.a}<->{r.b}: {r.n_slave_faces}/{r.n_master_faces} faces")
        else:
            frac = r.bearing_fraction
            print(f"  contact {r.a}<->{r.b}: {r.force_normal:.2f} N transferred, "
                  f"pressure peak {r.pressure_peak:.3f} MPa / mean "
                  f"{r.pressure_mean:.3f}, bearing {r.bearing_area:.1f} of "
                  f"{r.declared_area:.1f} mm^2"
                  f"{'' if frac is None else f' ({frac:.0%})'}"
                  f"{'' if frac is None or frac > 0.9 else ' — PART OF THIS JOINT HAS SEPARATED'}"
                  f", slip_max {r.slip_max}")
    print(f"workdir: {res.workdir}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
