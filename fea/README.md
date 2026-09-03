# `fea/` — stress analysis for printed parts

Answers three questions the geometric checkers can't: where does a part
concentrate stress under its intended load, roughly how much load can it
carry, and which regions are structurally idle (safe to lighten). It does
**not** replace `check.py`-style geometric verification — a part can carry
its load perfectly and still not mesh with its gear.

Pipeline: **gmsh (Python API) → CalculiX `ccx` → numpy**, everything from
nixpkgs, everything headless, boundary conditions as coordinate predicates
over the node array — the same idiom as the geometric checkers. Selected
2026-09-03 after a tooling investigation and an end-to-end prototype run
against this repo's meshes; alternatives considered (sfepy, scikit-fem,
pygccx, fTetWild, FEniCSx, FreeCAD-headless) and why they lost are in the
investigation report (Linear/artifact trail), the short version being:
these three are all in nixpkgs, and the prototype validated to 0.4% of an
analytic cantilever on day one.

```
nix develop --command python fea/check.py                 # single-part self-test
nix develop --command python fea/check_assembly.py        # assembly/contact self-test
nix develop --command python fea/fealib.py \
    <part.stl> <loadcases.py> <case-name>                 # one part, one load case
nix develop --command python fea/assembly.py \
    <assemblies.py> <case-name> [mesh-size]               # multi-part assembly
```

Two levels, and they are not interchangeable:

| | `fealib.py` | `assembly.py` |
| -- | -- | -- |
| scope | one part | several parts joined |
| joints | none (the part's supports are idealized) | `Tie` (bonded) and `Contact` (bearing, sliding, separating) |
| answers | weak spots, capacity, lightweighting | all of that, plus how load crosses a joint: bearing area, contact pressure, separation, slip |
| cost | seconds | minutes; contact is nonlinear |

## Load intent is declared data, not something the analyst invents

An FEA result is only as meaningful as its boundary conditions, and the
BCs encode *design intent* — where the part is held, where load enters,
how much. That knowledge belongs to the part's author, so it lives in a
`loadcases.py` next to the part's `.scad` source, not in anyone's head:

```python
# <project>/loadcases.py
import numpy as np
from fealib import LoadCase   # run with fea/ on sys.path

LOADCASES = {
    "yoke-payload": LoadCase(
        name="yoke-payload",
        rationale="carries the motorised mount: payload weight enters at "
                  "the trunnion seats, exits through the keyed mortise "
                  "into the az column",
        fixed=lambda p: p[:, 2] < p[:, 2].min() + 1.0,
        loaded=lambda p: p[:, 2] > p[:, 2].max() - 3.0,
        force=(0.0, 0.0, -50.0),      # ~5 kg payload
        material="PLA",
    ),
}
```

Predicates should derive from the mesh (`p[:,2].min()`) or from the
project's params — never restate a dimension by value (cad-design rule 3
applies to load cases too). The `rationale` string is load-bearing: the
design-verify workflow surfaces it verbatim as the statement of intent the
numbers are conditional on.

**A load-bearing part with no declared load case is unverified, and that
is itself a finding** — the analyst inventing plausible BCs on the spot
produces a number that looks measured but isn't anchored to intent.

## Assemblies: joints are declared intent too

An assembly case names its parts, its joints, its supports and its loads in
an `assemblies.py` beside the `.scad` sources — same rule as load cases, and
for the same reason:

```python
ASSEMBLIES = {
    "riser-under-payload": AssemblyCase(
        name="riser-under-payload",
        rationale="payload weight enters at the trunnion seats, crosses the "
                  "yoke/column mortise, and exits through the thrust ring",
        parts={"pedestal":  Part("build/pedestal.stl"),
               "az_column": Part("build/az_column.stl"),
               "yoke":      Part("build/yoke.stl")},
        interfaces=[
            Tie("yoke", "az_column"),               # yoke.scad declares this rigid
            Contact("az_column", "pedestal", mu=0.3),  # thrust ring: bears and turns
        ],
        fixed=[("pedestal", lambda p: p[:, 2] < p[:, 2].min() + 1.0)],
        loads=[("yoke", trunnion_seats, (0.0, 0.0, -50.0))],
        gravity=True,
    ),
}
```

**`Tie` vs `Contact` is a statement about the design, not a solver setting.**
A joint the model itself calls rigid gets `Tie` (the yoke's tenon: "RIGID
with az_column… the joint exists for printing and assembly, not for
motion"). A joint that bears, slides, or can lift gets `Contact`.

**Tie everything except the joint under investigation.** A full-contact
assembly is slower, more fragile, and answers no question better than a
hybrid one. Promote one interface to `Contact` when you want *that* joint's
pressure distribution, separation, or slip; leave the rest bonded.

**Every part must be grounded** — by `fixed`, by a `Tie` chain reaching a
fixed part, or by `Part(stabilize=True)` (weak springs, for a part held only
by contact). This is checked *before* ccx runs, because a floating part
otherwise produces a diverging solve whose output names nothing useful.

Interfaces are found automatically: faces that are both within `tol` of the
other part **and facing it** (outward normals opposed). The facing test is
not optional — proximity alone also catches the side walls running past a
joint, and since those share edge nodes with the real patch they inflate
both bearing area and transferred force.

What contact reporting gives you per interface: **bearing area vs declared
area** (the separation signal), **peak and mean contact pressure**,
**transferred normal force**, and **max slip**.

## Reading the numbers honestly

* **Capacity uses the converged peak, never a percentile.** Field
  percentiles dilute as the mesh refines (a p98-based capacity drifted
  10 kg → 16 kg across refinements during prototyping while the true peak
  converged). `converged_peak()` solves at two mesh sizes and tells you
  whether the peak stabilized; a peak still climbing means a sharp-corner
  singularity — the honest responses are "fillet it in the model" or
  "accept that the corner yields locally first", not a bigger mesh.
* **Absolute capacity is order-of-magnitude; relative comparisons are the
  reliable product.** Literature on FDM PLA needed per-print-setup coupon
  calibration to get absolute yield predictions under 6% error. "Holds
  ~1.6 kg" means "don't hang 5 kg on it", not "1.7 kg snaps it".
* **Strength, not stiffness, is where printing hurts.** Modulus varies
  ~10% with raster orientation; tensile strength drops ~30% (≈53 → 37 MPa
  at 100% infill) from 0° to 90° raster, worse layer-normal. The material
  table derates yield by a knockdown (PLA 0.5, PETG 0.6) as a blunt
  conservative stand-in. Print orientation relative to the peak tensile
  direction at the hotspot matters more than any material swap.
* **Swapping material does not move the weak spots.** Single-material
  linear elasticity: the stress field is (essentially) independent of
  stiffness — a PETG part stresses the same corners at the same MPa as
  PLA. What changes is the allowable and the deflection. One solve per
  geometry answers the material question for all of them.
* **The clamp edge is an artifact.** A rigid full clamp concentrates
  stress at its own boundary; `solve_case` zeroes the field within 3 mm
  of fixed nodes for peak-finding. Stress *at* a support needs a modelled
  support, not a `*BOUNDARY` card.

Worked example (prototype run, 2026-09-03, `riser/build/yoke.stl`): under
50 N pushed down on the tine tops with the mortise base fixed, the weak
spot was **not** the slender tines but the sharp top corners of the
central mortise slots (y ≈ ±15.5, z ≈ 88) — peak ~80 MPa, stable across
three mesh refinements, well past PLA yield. Two fillets fix it; a
thicker part wouldn't. (Demonstration-grade BCs: real load enters at the
trunnion bores. Declare the real case in `riser/loadcases.py` before
quoting yoke numbers.)

## ccx/meshio traps this pipeline works around (do not rediscover)

Each of these cost a debugging round; all are patched in `fealib.py`:

* **ccx input fields max 20 characters.** meshio writes 22-char floats;
  ccx then misparses `*NODE` and reports only downstream nonsense ("node
  set FIXED not defined", "value > nk") — never the cause. Coordinates
  are reformatted to `%.10g`.
* **meshio labels tet-10s `C3D10MH`**, an Abaqus type ccx doesn't know.
  Rewritten to `C3D10`.
* **ccx's output lies by omission on failure.** The pass-1 allocation
  table prints in full even when pass 2 aborts. Only the `Job finished`
  banner proves a solve; grep for it, never for the absence of errors.
* **Coarse 2nd-order meshes on curved surfaces invert elements**
  ("nonpositive jacobian"). `Mesh.HighOrderOptimize = 1` untangles them;
  level 2 hung 10+ minutes on a 13k-tet part — don't raise it.
* **.frd blocks advertise more components than they store** (DISP header
  says 4, lines carry 3). The parser reads the 12-char fields actually
  present.
* **OpenSCAD/manifold STLs are watertight** (all riser parts checked
  clean), so gmsh's `classifySurfaces` remesh suffices — the dirty-STL
  repair tools (fTetWild, tetgen `-d`) haven't been needed. If an STL
  ever fails to volume-mesh, check watertightness with trimesh *first*.

Assembly/contact traps, all found by running the gates in
`check_assembly.py` and all handled in `assembly.py`:

* **A contact step writes one set of result blocks per increment, and the
  first one looks exactly like a converged answer at a tenth the load.**
  Parsing the first block silently reports the first ramp increment.
  Always take the *last* block of each type.
* **`CPRESS` is not a usable pressure — interface pressure comes from the
  stress field.** ccx's `CPRESS` is its own contact bookkeeping, nodal
  contact force over a tributary area whose convention is undocumented.
  Integrated over a patch whose transferred force is known exactly
  (100 N), it gave 1.33x, 1.30x and 1.24x the right answer as the slab
  width, the mesh size and the patch area were varied — not a constant to
  divide out. The pipeline instead reports pressure as the normal
  traction `-n.sigma.n` on the interface faces, from the same validated
  stress output everything else uses; that integrates to 102.8 N against
  100 N applied, i.e. equilibrium holds. `CPRESS` is kept only as
  `pressure_peak_ccx`, a diagnostic (it read 1.46 MPa where the traction
  was 0.49).
* **`COPEN` never goes positive, so it cannot detect separation.** ccx
  drops a separated node from its active set and reports `COPEN` 0 for
  it — verified on a deliberately tipped block whose displacements
  plainly showed the far edge lifting 0.039 mm while `COPEN` maxed at
  exactly 0.0. Separation is read from **bearing area**: the share of the
  declared interface still in compression (14% on that tipped block,
  against 100% for the same block pressed flat).
* **Integrate interface quantities per FACE, at the midside nodes.** For
  a quadratic triangle the 3-midpoint rule is exact for a quadratic
  field, so `area * mean(midside values)` is an exact face integral.
  Node-counting is not a substitute: corner nodes of quadratic faces
  carry no contact load at all (the consistent nodal loads under uniform
  pressure are zero at corners, `p*A/3` at each midside), so "fraction of
  nodes with pressure" reads ~70% for a perfectly seated joint.
* **Proximity alone is the wrong interface test.** Faces must be close
  *and* facing (outward normals opposed). Without the normal test, a
  block's lower side walls join its own footprint — measured on the
  validation block as 569 mm² of "interface" where the true footprint is
  400 mm², with phantom transferred force to match, because the side
  faces share edge nodes with the real patch.
* **meshio's `tetra10` node order matches Abaqus `C3D10`**, so assembly
  connectivity is written straight through without permutation. The
  tied-beam gate (a split beam must deflect like a monolithic one, and
  does — 1.1422 vs 1.1421 mm) is what would catch that changing.

## Material table (`fealib.MATERIALS`)

Nominal datasheet-grade values, mm/N/MPa system:

| material | E (MPa) | ν | yield, printed flat | knockdown | allowable |
| -- | -- | -- | -- | -- | -- |
| PLA | 3500 | 0.36 | 50 | 0.5 | 25 MPa |
| PETG | 2100 | 0.40 | 47 | 0.6 | 28 MPa |

These are for ranking designs and sizing margins, not certifying them.
Anything safety-adjacent gets a printed coupon test in the part's actual
orientation, or a bigger margin.
