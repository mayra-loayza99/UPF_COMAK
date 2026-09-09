"""Extract the left-leg side from model_two_legs_fixed.osim.

Produces lenhart2015_left.osim by removing every right-side component
(bodies, joints, forces, contact geometry, markers) via the OpenSim
Python API.  Also applies two bug-fixes to left-side contact geometry
mesh references before saving.

Usage
-----
    python COMAK/python/tools/extract_left_model.py

Reads:  COMAK/python/model_two_legs_fixed.osim
Writes: COMAK/models/lenhart2015_generic/lenhart2015_left.osim
"""

from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

# ── OpenSim SDK ───────────────────────────────────────────────────────────────

_ROOT    = Path(__file__).parent.parent.parent.parent  # UPF_COMAK/
_SDK_DIR = _ROOT / "sdk" / "Python"
_BIN_DIR = _ROOT / "bin"

if str(_SDK_DIR) not in sys.path:
    sys.path.insert(0, str(_SDK_DIR))

# Windows requires explicit DLL directory registration (Python 3.8+)
_DLL_DIRS = [_BIN_DIR, _ROOT / "sdk" / "Simbody" / "bin"]
if hasattr(os, "add_dll_directory"):
    for _d in _DLL_DIRS:
        if _d.exists():
            os.add_dll_directory(str(_d))

import opensim as osim  # noqa: E402

# ── Paths ─────────────────────────────────────────────────────────────────────

ROOT       = Path(__file__).parent.parent          # COMAK/python/
INPUT_PATH = ROOT / "model_two_legs_fixed.osim"
OUT_PATH   = (
    ROOT.parent
    / "models"
    / "lenhart2015_generic"
    / "lenhart2015_left.osim"
)

# ── Component lists ───────────────────────────────────────────────────────────

MUSCLES_R = [
    "addbrev_r", "addlong_r", "addmagProx_r", "addmagMid_r", "addmagDist_r",
    "addmagIsch_r", "bflh_r", "bfsh_r", "edl_r", "ehl_r", "fdl_r", "fhl_r",
    "gaslat_r", "gasmed_r", "gem_r", "glmax1_r", "glmax2_r", "glmax3_r",
    "glmed1_r", "glmed2_r", "glmed3_r", "glmin1_r", "glmin2_r", "glmin3_r",
    "grac_r", "iliacus_r", "pect_r", "perbrev_r", "perlong_r", "pertert_r",
    "piri_r", "psoas_r", "quadfem_r", "recfem_r", "sart_r", "semimem_r",
    "semiten_r", "soleus_r", "tfl_r", "tibant_r", "tibpost_r", "vasint_r",
    "vaslat_r", "vasmed_r",
]

LIGAMENTS_R = [
    "MCLd1", "MCLd2", "MCLd3", "MCLd4", "MCLd5",
    "MCLs1", "MCLs2", "MCLs3", "MCLs4", "MCLs5", "MCLs6",
    "ACLpl1", "ACLpl2", "ACLpl3", "ACLpl4", "ACLpl5", "ACLpl6",
    "ACLam1", "ACLam2", "ACLam3", "ACLam4", "ACLam5", "ACLam6",
    "PCLal1", "PCLal2", "PCLal3", "PCLal4", "PCLal5",
    "PCLpm1", "PCLpm2", "PCLpm3", "PCLpm4", "PCLpm5",
    "LCL1", "LCL2", "LCL3", "LCL4",
    "PT1", "PT2", "PT3", "PT4", "PT5", "PT6",
    "lPFL1", "lPFL2", "lPFL3", "lPFL4", "lPFL5", "lPFL6", "lPFL7", "lPFL8",
    "mPFL1", "mPFL2", "mPFL3", "mPFL4", "mPFL5", "mPFL6",
    "MCLp1", "MCLp2", "MCLp3", "MCLp4", "MCLp5",
    "PFL1", "PFL2", "PFL3", "PFL4", "PFL5",
    "pCAP1", "pCAP2", "pCAP3", "pCAP4", "pCAP5", "pCAP6", "pCAP7", "pCAP8",
    "ITB1",
]

# Contacts may be named without _r suffix in the bilateral model.
# We remove them dynamically in PASO 1 by type, not by name.
CONTACTS_R = ["tf_contact_r", "pf_contact_r", "tf_contact", "pf_contact"]

SPRINGS_R = [
    "knee_flex_r", "knee_add_r", "knee_rot_r",
    "knee_tx_r", "knee_ty_r", "knee_tz_r",
    "pf_flex_r", "pf_rot_r", "pf_tilt_r",
    "pf_tx_r", "pf_ty_r", "pf_tz_r",
]

CONTACT_GEOM_R = ["femur_cartilage", "tibia_cartilage", "patella_cartilage"]

JOINTS_R = [
    "hip_r", "femur_femur_distal_r", "pf_r", "knee_r",
    "tibia_tibia_proximal_r", "ankle_r", "subtalar_r", "mtp_r",
]

BODIES_R = [
    "femur_r", "femur_distal_r", "patella_r", "tibia_proximal_r",
    "tibia_r", "talus_r", "calcn_r", "toes_r",
]

# ── Helpers ───────────────────────────────────────────────────────────────────

def _remove_by_name(set_obj, names: list[str], set_label: str) -> None:
    """Remove entries whose name is in *names* from an OpenSim Set."""
    name_set = set(names)
    indices = [
        i
        for i in range(set_obj.getSize())
        if set_obj.get(i).getName() in name_set
    ]
    found = {set_obj.get(i).getName() for i in indices}
    missing = name_set - found
    if missing:
        for m in sorted(missing):
            print(f"  WARNING [{set_label}]: '{m}' not found — skipping")
    for i in reversed(sorted(indices)):
        set_obj.remove(i)
    print(f"  Removed {len(indices)} from {set_label}")


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    print(f"Input : {INPUT_PATH}")
    print(f"Output: {OUT_PATH}")

    if not INPUT_PATH.exists():
        print(f"ERROR: input file not found: {INPUT_PATH}")
        sys.exit(1)

    # Smith2018ContactMesh throws (not warns) when STL files aren't found.
    # It resolves paths relative to the model file's directory.
    # Solution: load from a temp copy placed next to the existing Geometry/ folder.
    _tmp = OUT_PATH.parent / "_tmp_bilateral.osim"
    shutil.copy2(INPUT_PATH, _tmp)
    try:
        model = osim.Model(str(_tmp))
    finally:
        if _tmp.exists():
            _tmp.unlink()
    model.setName("lenhart2015_left")

    # ── PASO 1: Remove R forces ───────────────────────────────────────────────
    print("\n[PASO 1] Removing R forces...")
    force_set = model.updForceSet()
    # Contacts may live in ForceSet or as subcomponents — try ForceSet first,
    # then fall back to a name-based component search.
    to_remove_forces = MUSCLES_R + LIGAMENTS_R + CONTACTS_R + SPRINGS_R
    _remove_by_name(force_set, to_remove_forces, "ForceSet")

    # Safety pass: remove any remaining Smith2018ArticularContactForce that
    # doesn't end in _l (i.e., R-side contacts, regardless of exact name).
    contact_indices = [
        i for i in range(force_set.getSize())
        if osim.Smith2018ArticularContactForce.safeDownCast(force_set.get(i)) is not None
        and not force_set.get(i).getName().endswith("_l")
    ]
    if contact_indices:
        names = [force_set.get(i).getName() for i in contact_indices]
        print(f"  Removing R-side contacts by type: {names}")
        for i in reversed(contact_indices):
            force_set.remove(i)

    # ── PASO 2: Remove R ContactGeometry ─────────────────────────────────────
    print("\n[PASO 2] Removing R ContactGeometry...")
    cg_set = model.updContactGeometrySet()
    _remove_by_name(cg_set, CONTACT_GEOM_R, "ContactGeometrySet")

    # ── PASO 3: Remove R markers (body-aware) ────────────────────────────────
    print("\n[PASO 3] Removing R markers (only those anchored to removed bodies)...")
    marker_set = model.updMarkerSet()
    removed_bodies = set(BODIES_R)
    r_markers_to_remove = []
    r_markers_kept = []
    for i in range(marker_set.getSize()):
        m = marker_set.get(i)
        if not m.getName().startswith("r."):
            continue
        # socket path e.g. "/bodyset/femur_r" — extract the terminal component
        frame_path = m.getSocket("parent_frame").getConnecteePath()
        body_name = frame_path.split("/")[-1]
        if body_name in removed_bodies:
            r_markers_to_remove.append(m.getName())
        else:
            r_markers_kept.append(m.getName())
    _remove_by_name(marker_set, r_markers_to_remove, "MarkerSet")

    # ── PASO 4: Remove R joints ───────────────────────────────────────────────
    print("\n[PASO 4] Removing R joints...")
    joint_set = model.updJointSet()
    _remove_by_name(joint_set, JOINTS_R, "JointSet")

    # ── PASO 5: Remove R bodies ───────────────────────────────────────────────
    print("\n[PASO 5] Removing R bodies...")
    body_set = model.updBodySet()
    _remove_by_name(body_set, BODIES_R, "BodySet")

    # ── BUG FIX 1: Correct mesh_back_file for L ContactGeometry ──────────────
    print("\n[BUG FIX 1] Correcting mesh_back_file for L contact geometry...")
    cg_set = model.updContactGeometrySet()
    fixes_back = {
        "femur_cartilage_l":   "lenhart2015-L-femur-bone.stl",
        "tibia_cartilage_l":   "lenhart2015-L-tibia-bone.stl",
        "patella_cartilage_l": "lenhart2015-L-patella-bone.stl",
    }
    for i in range(cg_set.getSize()):
        cg = cg_set.get(i)
        name = cg.getName()
        if name in fixes_back:
            mesh = osim.Smith2018ContactMesh.safeDownCast(cg)
            if mesh is None:
                print(f"  WARNING: '{name}' expected Smith2018ContactMesh but safeDownCast returned None — aborting")
                sys.exit(1)
            mesh.set_mesh_back_file(fixes_back[name])
            print(f"  {name}: mesh_back_file -> {fixes_back[name]}")

    # ── BUG FIX 2: Correct tibia_proximal_l attached geometry mesh ───────────
    print("\n[BUG FIX 2] Correcting tibia_proximal_l attached geometry...")
    try:
        body = model.updBodySet().get("tibia_proximal_l")
        fixed_geom = False
        # OpenSim 4.3 SWIG bindings use get_attached_geometry(i) / upd_attached_geometry(i)
        n_geoms = body.getProperty_attached_geometry().size()
        for j in range(n_geoms):
            geom = body.upd_attached_geometry(j)
            mesh = osim.Mesh.safeDownCast(geom)
            if mesh and "tibia-cartilage" in mesh.get_mesh_file():
                old_val = mesh.get_mesh_file()
                mesh.set_mesh_file("lenhart2015-L-tibia-cartilage.stl")
                print(f"  tibia_proximal_l geometry[{j}]: '{old_val}' -> 'lenhart2015-L-tibia-cartilage.stl'")
                fixed_geom = True
        if not fixed_geom:
            print("  No 'tibia-cartilage' mesh found in tibia_proximal_l attached geometry — nothing changed")
    except Exception as e:
        print(f"  WARNING BUG FIX 2 skipped (non-critical display fix): {e}")

    # ── Finalize and validate ─────────────────────────────────────────────────
    print("\n[FINALIZE] Calling finalizeConnections()...")
    model.finalizeConnections()

    print("[VALIDATE] Calling initSystem()...")
    try:
        state = model.initSystem()
        print("  initSystem(): OK")
    except Exception as e:
        print(f"  ERROR in initSystem(): {e}")
        print("  Broken references detected after pruning. Aborting — model NOT saved.")
        sys.exit(1)

    # ── Report ────────────────────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("PRE-SAVE REPORT")
    print("=" * 60)

    n_bodies = model.getNumBodies()
    bs = model.getBodySet()
    bodies_l = [bs.get(i).getName() for i in range(bs.getSize())
                if bs.get(i).getName().endswith("_l") or not bs.get(i).getName().endswith("_r")]
    print(f"  Bodies total          : {n_bodies}")
    print(f"  Bodies L (or neutral) : {len(bodies_l)}")

    print(f"  Joints total          : {model.getNumJoints()}")

    fs = model.getForceSet()
    total_forces = fs.getSize()
    muscles_l = sum(
        1 for i in range(fs.getSize()) if fs.get(i).getName().endswith("_l")
    )
    lig_l = sum(
        1 for i in range(fs.getSize())
        if fs.get(i).getName().endswith("_l")
        and osim.Millard2012EquilibriumMuscle.safeDownCast(fs.get(i)) is None
    )
    contacts_l = sum(
        1 for i in range(fs.getSize())
        if osim.Smith2018ArticularContactForce.safeDownCast(fs.get(i)) is not None
    )
    springs_l = sum(
        1 for i in range(fs.getSize())
        if osim.SpringGeneralizedForce.safeDownCast(fs.get(i)) is not None
    )
    print(f"  Forces total          : {total_forces}")
    print(f"  Muscles L (_l suffix) : {muscles_l}")
    print(f"  Smith2018 contacts    : {contacts_l}")
    print(f"  SpringGeneralizedForce: {springs_l}")

    ms = model.getMarkerSet()
    print(f"  Markers               : {ms.getSize()}")
    print(f"  Markers preserved from R side: {len(r_markers_kept)} — {r_markers_kept}")

    print("\n  Coordinates:")
    coord_set = model.getCoordinateSet()
    for i in range(coord_set.getSize()):
        coord = coord_set.get(i)
        print(f"    {coord.getName():<40s} {coord.getMotionType()}")

    print("=" * 60)

    # ── Save ──────────────────────────────────────────────────────────────────
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    model.printToXML(str(OUT_PATH))
    print(f"\nSaved: {OUT_PATH}")


if __name__ == "__main__":
    main()
