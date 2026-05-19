"""Central configuration for the COMAK post-processing pipeline.

All joint coordinate names, muscle identifiers, EMG channel mappings, file-naming
conventions, and numerical constants live here.  Plotting functions and I/O helpers
import from this module — nothing is hardcoded inside individual functions.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Final


# ── Gait-cycle normalisation ──────────────────────────────────────────────────

GAIT_CYCLE_POINTS: Final[int] = 100
"""Number of uniformly-spaced samples on the 0–100 % gait-cycle grid.

The original MATLAB scripts are inconsistent: plot_primary_coordinates_vs_mocap.m
uses 0:100 (101 points) while all other scripts use linspace(0,100,100) (100 points).
This constant standardises the pipeline on 100 points everywhere.
"""


# ── Confidence-interval parameters ───────────────────────────────────────────

CI_Z_SCORE: Final[float] = 1.96
"""
Multiplier for the large-sample 95 % CI: half_width = CI_Z_SCORE × std / √n.
Matches the original MATLAB code.  Pass use_t_dist=True to analysis.metrics.ci_95()
to switch to the t-distribution CI (recommended for n < 30).
"""


# ── Joint coordinate definitions ─────────────────────────────────────────────

@dataclass(frozen=True)
class CoordSpec:
    """One degree of freedom: its column name, human label, axis unit, and unit scale."""
    name: str           # column name in *_values.sto
    label: str          # subplot title, e.g. "Flexion"
    unit: str           # y-axis label, e.g. "Angle [deg]"
    scale: float = 1.0  # multiply raw value before plotting (1000.0 converts m → mm)


# Tibiofemoral joint — 3 rotations, 3 translations
TF_ROTATIONS: Final[tuple[CoordSpec, ...]] = (
    CoordSpec("knee_flex_r",  "Flexion",           "Angle [deg]"),
    CoordSpec("knee_add_r",   "Adduction",          "Angle [deg]"),
    CoordSpec("knee_rot_r",   "Internal Rotation",  "Angle [deg]"),
)
TF_TRANSLATIONS: Final[tuple[CoordSpec, ...]] = (
    CoordSpec("knee_tx_r", "Anterior Translation", "Translation [mm]", scale=1000.0),
    CoordSpec("knee_ty_r", "Superior Translation", "Translation [mm]", scale=1000.0),
    CoordSpec("knee_tz_r", "Lateral Translation",  "Translation [mm]", scale=1000.0),
)

# Patellofemoral joint — 3 rotations, 3 translations
PF_ROTATIONS: Final[tuple[CoordSpec, ...]] = (
    CoordSpec("pf_flex_r",  "Flexion",  "Angle [deg]"),
    CoordSpec("pf_rot_r",   "Rotation", "Angle [deg]"),
    CoordSpec("pf_tilt_r",  "Tilt",     "Angle [deg]"),
)
PF_TRANSLATIONS: Final[tuple[CoordSpec, ...]] = (
    CoordSpec("pf_tx_r", "Anterior Translation", "Translation [mm]", scale=1000.0),
    CoordSpec("pf_ty_r", "Superior Translation", "Translation [mm]", scale=1000.0),
    CoordSpec("pf_tz_r", "Lateral Translation",  "Translation [mm]", scale=1000.0),
)

# MoCap column names in 1D_Angle_Cycles_*.emt (BTS format; ".M" suffix = cycle mean)
MOCAP_KNEE_FLEXION_COL: Final[str] = "acmRKFE.M"
MOCAP_SAMPLE_COL: Final[str] = "Sample"


# ── Muscle and reserve-actuator identifiers ───────────────────────────────────

MUSCLES: Final[tuple[str, ...]] = (
    "addbrev_r", "addlong_r", "addmagProx_r", "addmagMid_r", "addmagDist_r",
    "addmagIsch_r", "bflh_r", "bfsh_r", "edl_r", "ehl_r", "fdl_r", "fhl_r",
    "gaslat_r", "gasmed_r", "gem_r", "glmax1_r", "glmax2_r", "glmax3_r",
    "glmed1_r", "glmed2_r", "glmed3_r", "glmin1_r", "glmin2_r", "glmin3_r",
    "grac_r", "iliacus_r", "pect_r", "perbrev_r", "perlong_r", "pertert_r",
    "piri_r", "psoas_r", "quadfem_r", "recfem_r", "sart_r", "semimem_r",
    "semiten_r", "soleus_r", "tfl_r", "tibant_r", "tibpost_r", "vasint_r",
    "vaslat_r", "vasmed_r",
)

RESERVE_ACTUATORS: Final[tuple[str, ...]] = (
    "hip_flex_r_reserve", "hip_add_r_reserve", "hip_rot_r_reserve",
    "pf_flex_r_reserve",  "pf_rot_r_reserve",  "pf_tilt_r_reserve",
    "pf_tx_r_reserve",    "pf_ty_r_reserve",   "pf_tz_r_reserve",
    "knee_flex_r_reserve","knee_add_r_reserve", "knee_rot_r_reserve",
    "knee_tx_r_reserve",  "knee_ty_r_reserve",  "knee_tz_r_reserve",
    "ankle_flex_r_reserve",
)

# Reserve actuators whose output is a force (translational DOF) vs torque (rotational)
RESERVE_FORCE_ACTUATORS: Final[frozenset[str]] = frozenset(
    a for a in RESERVE_ACTUATORS if any(s in a for s in ("_tx_", "_ty_", "_tz_"))
)

MUSCLE_DISPLAY_NAMES: Final[dict[str, str]] = {
    "addbrev_r":      "Adductor Brevis",
    "addlong_r":      "Adductor Longus",
    "addmagProx_r":   "Adductor Magnus Proximal",
    "addmagMid_r":    "Adductor Magnus Middle",
    "addmagDist_r":   "Adductor Magnus Distal",
    "addmagIsch_r":   "Adductor Magnus Ischial",
    "bflh_r":         "Biceps Femoris Long Head",
    "bfsh_r":         "Biceps Femoris Short Head",
    "edl_r":          "Extensor Digitorum Longus",
    "ehl_r":          "Extensor Hallucis Longus",
    "fdl_r":          "Flexor Digitorum Longus",
    "fhl_r":          "Flexor Hallucis Longus",
    "gaslat_r":       "Gastrocnemius Lateral",
    "gasmed_r":       "Gastrocnemius Medial",
    "gem_r":          "Gemellus",
    "glmax1_r":       "Gluteus Maximus 1",
    "glmax2_r":       "Gluteus Maximus 2",
    "glmax3_r":       "Gluteus Maximus 3",
    "glmed1_r":       "Gluteus Medius 1",
    "glmed2_r":       "Gluteus Medius 2",
    "glmed3_r":       "Gluteus Medius 3",
    "glmin1_r":       "Gluteus Minimus 1",
    "glmin2_r":       "Gluteus Minimus 2",
    "glmin3_r":       "Gluteus Minimus 3",
    "grac_r":         "Gracilis",
    "iliacus_r":      "Iliacus",
    "pect_r":         "Pectineus",
    "perbrev_r":      "Peroneus Brevis",
    "perlong_r":      "Peroneus Longus",
    "pertert_r":      "Peroneus Tertius",
    "piri_r":         "Piriformis",
    "psoas_r":        "Psoas",
    "quadfem_r":      "Quadratus Femoris",
    "recfem_r":       "Rectus Femoris",
    "sart_r":         "Sartorius",
    "semimem_r":      "Semimembranosus",
    "semiten_r":      "Semitendinosus",
    "soleus_r":       "Soleus",
    "tfl_r":          "Tensor Fasciae Latae",
    "tibant_r":       "Tibialis Anterior",
    "tibpost_r":      "Tibialis Posterior",
    "vasint_r":       "Vastus Intermedius",
    "vaslat_r":       "Vastus Lateralis",
    "vasmed_r":       "Vastus Medialis",
    "hip_flex_r_reserve":  "Hip Flexor Reserve Actuator",
    "hip_add_r_reserve":   "Hip Adductor Reserve Actuator",
    "hip_rot_r_reserve":   "Hip Rotator Reserve Actuator",
    "pf_flex_r_reserve":   "Patellofemoral Flexor Reserve Actuator",
    "pf_rot_r_reserve":    "Patellofemoral Rotator Reserve Actuator",
    "pf_tilt_r_reserve":   "Patellofemoral Tilt Reserve Actuator",
    "pf_tx_r_reserve":     "Patellofemoral Translation X Reserve Actuator",
    "pf_ty_r_reserve":     "Patellofemoral Translation Y Reserve Actuator",
    "pf_tz_r_reserve":     "Patellofemoral Translation Z Reserve Actuator",
    "knee_flex_r_reserve": "Knee Flexor Reserve Actuator",
    "knee_add_r_reserve":  "Knee Adductor Reserve Actuator",
    "knee_rot_r_reserve":  "Knee Rotator Reserve Actuator",
    "knee_tx_r_reserve":   "Knee Translation X Reserve Actuator",
    "knee_ty_r_reserve":   "Knee Translation Y Reserve Actuator",
    "knee_tz_r_reserve":   "Knee Translation Z Reserve Actuator",
    "ankle_flex_r_reserve":"Ankle Flexor Reserve Actuator",
}

# Muscle groups used to compute quad:hamstring co-activation ratio
QUADRICEPS: Final[tuple[str, ...]] = ("vaslat_r", "vasmed_r", "vasint_r", "recfem_r")
HAMSTRINGS: Final[tuple[str, ...]] = ("bflh_r", "bfsh_r", "semiten_r", "semimem_r")


# ── EMG channel mapping ───────────────────────────────────────────────────────

# Maps OpenSim muscle name → raw column header in the BTS EMG Tracks .emt file.
#
# MATLAB readtable silently converts column names: spaces are stripped and words
# capitalised ("Right Tibialis anterior" → RightTibialisAnterior).
# pandas.read_csv preserves the original spacing and casing, so the keys here
# match what pandas actually returns from the file.
EMG_CHANNELS: Final[dict[str, str]] = {
    "tibant_r": "Right Tibialis anterior",
    "vaslat_r": "Right Vastus lateralis",
    "gaslat_r": "Right Gastrocnemius lateralis",
    "bflh_r":   "Right Biceps femoris caput longus",
}
EMG_DISPLAY_NAMES: Final[dict[str, str]] = {
    "tibant_r": "Tibialis Anterior",
    "vaslat_r": "Vastus Lateralis",
    "gaslat_r": "Gastrocnemius Lateralis",
    "bflh_r":   "Biceps Femoris (long head)",
}


# ── ForceReporter column patterns ─────────────────────────────────────────────
#
# The JointMechanicsTool ForceReporter writes a *_ForceReporter_forces.sto whose
# exact column names depend on the model's contact-element names.  No sample file
# is available in this repository.
#
# After your first simulation run, run:
#   python tools/discover_force_columns.py path/to/walking_NNN_ForceReporter_forces.sto
# and paste the printed mapping here.  Each value should be a substring that
# uniquely identifies its column among the label row.  None = not yet mapped;
# io.force_columns.resolve_force_columns() will raise a clear ValueError listing
# every unresolved key.

FORCE_COLUMN_PATTERNS: Final[dict[str, str | None]] = {
    # Center of pressure [m → mm] — total, medial (region 4), lateral (region 5)
    # Regions 4 and 5 correspond to the medial and lateral tibial compartments
    # respectively, confirmed from MATLAB script column indices (654+i and 657+i).
    "cop_total_x":   "tibia_cartilage.total.center_of_pressure_x",
    "cop_total_y":   "tibia_cartilage.total.center_of_pressure_y",
    "cop_total_z":   "tibia_cartilage.total.center_of_pressure_z",
    "cop_medial_x":  "tibia_cartilage.regional.center_of_pressure_4_x",
    "cop_medial_y":  "tibia_cartilage.regional.center_of_pressure_4_y",
    "cop_medial_z":  "tibia_cartilage.regional.center_of_pressure_4_z",
    "cop_lateral_x": "tibia_cartilage.regional.center_of_pressure_5_x",
    "cop_lateral_y": "tibia_cartilage.regional.center_of_pressure_5_y",
    "cop_lateral_z": "tibia_cartilage.regional.center_of_pressure_5_z",
    # Contact forces [N, normalised to BW in plots]
    "force_total_x":   "tibia_cartilage.total.contact_force_x",
    "force_total_y":   "tibia_cartilage.total.contact_force_y",
    "force_total_z":   "tibia_cartilage.total.contact_force_z",
    "force_medial_x":  "tibia_cartilage.regional.contact_force_4_x",
    "force_medial_y":  "tibia_cartilage.regional.contact_force_4_y",
    "force_medial_z":  "tibia_cartilage.regional.contact_force_4_z",
    "force_lateral_x": "tibia_cartilage.regional.contact_force_5_x",
    "force_lateral_y": "tibia_cartilage.regional.contact_force_5_y",
    "force_lateral_z": "tibia_cartilage.regional.contact_force_5_z",
    # Joint reaction moments [Nm]
    "moment_total_x":   "tibia_cartilage.total.contact_moment_x",
    "moment_total_y":   "tibia_cartilage.total.contact_moment_y",
    "moment_total_z":   "tibia_cartilage.total.contact_moment_z",
    "moment_medial_x":  "tibia_cartilage.regional.contact_moment_4_x",
    "moment_medial_y":  "tibia_cartilage.regional.contact_moment_4_y",
    "moment_medial_z":  "tibia_cartilage.regional.contact_moment_4_z",
    "moment_lateral_x": "tibia_cartilage.regional.contact_moment_5_x",
    "moment_lateral_y": "tibia_cartilage.regional.contact_moment_5_y",
    "moment_lateral_z": "tibia_cartilage.regional.contact_moment_5_z",
    # Contact pressure [MPa]
    "mean_pressure_total":   "tibia_cartilage.total.mean_pressure",
    "max_pressure_total":    "tibia_cartilage.total.max_pressure",
    "mean_pressure_medial":  "tibia_cartilage.regional.mean_pressure_4",
    "mean_pressure_lateral": "tibia_cartilage.regional.mean_pressure_5",
    "max_pressure_medial":   "tibia_cartilage.regional.max_pressure_4",
    "max_pressure_lateral":  "tibia_cartilage.regional.max_pressure_5",
    # Contact area [m² → mm² with ×1e6]
    "area_total":   "tibia_cartilage.total.contact_area",
    "area_medial":  "tibia_cartilage.regional.contact_area_4",
    "area_lateral": "tibia_cartilage.regional.contact_area_5",
}


# ── File-naming conventions ───────────────────────────────────────────────────

# Format strings — resolve with .format(subject_id=...)
STO_COMAK_VALUES:   Final[str] = "walking_{subject_id}_values.sto"
STO_ACTIVATION:     Final[str] = "walking_{subject_id}_activation.sto"
STO_FORCE_REPORTER: Final[str] = "walking_{subject_id}_ForceReporter_forces.sto"
STO_IK_ERRORS:      Final[str] = "walking_{subject_id}_ik_marker_errors.sto"

# Top-level data directory (relative to COMAK/) — contains {project_id}_{subject_id}/ folders
DATA_SUBDIR: Final[str] = "processed_data"

# Subdirectory layout under results/<project_id>_<subject_id>/
SUBDIR_COMAK:      Final[str] = "comak"
SUBDIR_IK:         Final[str] = "comak_inverse_kinematics"
SUBDIR_JOINT_MECH: Final[str] = "joint_mechanics"
SUBDIR_GRAPHICS:   Final[str] = "graphics"

# Output graphic subdirectories (under SUBDIR_GRAPHICS)
GRAPHICS_KINEMATICS: Final[str] = "kinematics"
GRAPHICS_VALIDATION: Final[str] = "validation"
GRAPHICS_ACTIVATIONS: Final[str] = "muscle_activations"
GRAPHICS_RESERVES:   Final[str] = "reserve_actuators"
GRAPHICS_JOINT_MECH: Final[str] = "extended_joint_mechanics"
GRAPHICS_PARAVIEW:   Final[str] = "paraview"

# Mean/group results output root (relative to COMAK/)
MEAN_RESULTS_DIR: Final[str] = "mean_results"

# Directory names to skip when scanning results/ for patient subdirectories
EXCLUDED_RESULT_DIRS: Final[frozenset[str]] = frozenset({
    "images_for_visualizations",
    "paraview_template_files",
    "reports",
})
