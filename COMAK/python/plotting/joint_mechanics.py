"""Joint-mechanics figures: contact forces, moments, CoP, pressure, and area.

Replaces
--------
  plot_joint_mechanics_extended.m              → :func:`plot_trial_joint_mechanics`
  plot_all_patients_joint_mechanics.m          → :func:`plot_group_joint_mechanics`
  plot_all_patients_pressure_and_area.m        → :func:`plot_group_pressure_area`

Critical MATLAB bug fixed
--------------------------
All five source scripts used hardcoded 1-based column indices to access the
ForceReporter output, e.g. ``forces_data(:, 588+i)``.  Those indices break
whenever the model or contact-element list changes.  Python uses
:func:`~io.force_columns.resolve_force_columns` to look up column names by
pattern, driven by ``config.FORCE_COLUMN_PATTERNS``.

**Important**: ``config.FORCE_COLUMN_PATTERNS`` must be populated before any
function in this module can run.  Run ``tools/discover_force_columns.py`` against
one ForceReporter ``.sto`` file and fill in the patterns.

Scaling conventions (matching MATLAB)
--------------------------------------
* Contact forces   — divided by body weight in N  → dimensionless [BW]
* Reaction moments — unchanged                    → [Nm]
* Center of pressure — ×1000 (m → mm)            → [mm]
* Contact pressure — unchanged                    → [MPa]
* Contact area     — ×1e6  (m² → mm²)            → [mm²]
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Callable

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.figure

from COMAK.python.config import (
    GAIT_CYCLE_POINTS,
    GRAPHICS_JOINT_MECH,
)
from COMAK.python.aggregation.group_results import GroupResults
from COMAK.python.analysis.metrics import group_ci
from COMAK.python.analysis.normalization import normalize_dataframe
from COMAK.python.models.trial_data import TrialData
from COMAK.python.plotting.shaded_ci import shaded_mean_ci
from COMAK.python.plotting.style import (
    FIG_KINEMATICS,
    FONT_LABEL,
    FONT_LEGEND,
    FONT_TITLE,
    LINE_WIDTH,
    LINE_WIDTH_THICK,
    set_gait_cycle_xaxis,
)

log = logging.getLogger(__name__)

# ── Colour convention: total=black, medial=red, lateral=blue ─────────────────
_C_TOTAL   = "#2c2c2c"
_C_MEDIAL  = "#d62728"
_C_LATERAL = "#1f77b4"

_DIRECTIONS = ("Anterior-Posterior", "Superior-Inferior", "Medial-Lateral")
_AXES       = ("x", "y", "z")


# ── Figure specification dataclass ────────────────────────────────────────────

@dataclass(frozen=True)
class _FigSpec:
    """Definition of one directional (per-axis) joint-mechanics figure."""
    stem: str            # filename stem, e.g. "Contact_Forces_Anterior-Posterior"
    title: str           # e.g. "Contact Forces - Anterior-Posterior (X)"
    key_total: str       # config key, e.g. "force_total_x"
    key_medial: str
    key_lateral: str
    ylabel: str
    scale: float         # multiply raw values by this before plotting


def _build_specs() -> list[_FigSpec]:
    """Generate all 9 per-axis figure specs for forces, moments, and CoP."""
    specs = []
    for direction, ax in zip(_DIRECTIONS, _AXES):
        axis_letter = ax.upper()
        specs.append(_FigSpec(
            stem=f"Contact_Forces_{direction.replace('-', '_')}",
            title=f"Contact Forces - {direction} ({axis_letter})",
            key_total=f"force_total_{ax}",
            key_medial=f"force_medial_{ax}",
            key_lateral=f"force_lateral_{ax}",
            ylabel="Joint Contact Force [BW]",
            scale=1.0,   # BW division applied separately (needs runtime BW value)
        ))
        specs.append(_FigSpec(
            stem=f"Reaction_Moments_{direction.replace('-', '_')}",
            title=f"Reaction Moments - {direction} ({axis_letter})",
            key_total=f"moment_total_{ax}",
            key_medial=f"moment_medial_{ax}",
            key_lateral=f"moment_lateral_{ax}",
            ylabel="Joint Reaction Moment [Nm]",
            scale=1.0,
        ))
        specs.append(_FigSpec(
            stem=f"Center_of_Pressure_{direction.replace('-', '_')}",
            title=f"Center of Pressure - {direction} ({axis_letter})",
            key_total=f"cop_total_{ax}",
            key_medial=f"cop_medial_{ax}",
            key_lateral=f"cop_lateral_{ax}",
            ylabel="CoP [mm]",
            scale=1000.0,   # m → mm
        ))
    return specs


_SPECS: list[_FigSpec] = _build_specs()

# Pressure & area: separate combined-subplot figure
@dataclass(frozen=True)
class _PressureAreaSpec:
    stem: str
    title: str
    key_total: str
    key_medial: str
    key_lateral: str
    ylabel: str
    scale: float

_PRESSURE_AREA_SPECS: list[_PressureAreaSpec] = [
    _PressureAreaSpec("mean_pressure",  "Mean Contact Pressure",
                      "mean_pressure_total", "mean_pressure_medial", "mean_pressure_lateral",
                      "Pressure [MPa]", 1.0),
    _PressureAreaSpec("max_pressure",   "Max Contact Pressure",
                      "max_pressure_total",  "max_pressure_medial",  "max_pressure_lateral",
                      "Pressure [MPa]", 1.0),
    _PressureAreaSpec("contact_area",   "Contact Area",
                      "area_total",          "area_medial",           "area_lateral",
                      "Area [mm²]",   1e6),  # m² → mm²
]


# ── Helpers ───────────────────────────────────────────────────────────────────

def _extract(
    norm_df,
    col_key: str,
    force_cols: dict[str, str],
    scale: float,
    bw_n: float = 1.0,
) -> np.ndarray | None:
    """Return scaled signal for *col_key*, or None if column is unresolved."""
    actual = force_cols.get(col_key)
    if actual is None or actual not in norm_df.columns:
        return None
    return norm_df[actual].to_numpy(dtype=float) * scale / bw_n


def _plot_three_lines(
    ax: plt.Axes,
    gait_axis: np.ndarray,
    total: np.ndarray | None,
    medial: np.ndarray | None,
    lateral: np.ndarray | None,
) -> None:
    if total   is not None: ax.plot(gait_axis, total,   color=_C_TOTAL,   lw=LINE_WIDTH,       label="Total")
    if medial  is not None: ax.plot(gait_axis, medial,  color=_C_MEDIAL,  lw=LINE_WIDTH_THICK, label="Medial")
    if lateral is not None: ax.plot(gait_axis, lateral, color=_C_LATERAL, lw=LINE_WIDTH_THICK, label="Lateral")


def _plot_three_bands(
    ax: plt.Axes,
    gait_axis: np.ndarray,
    stats_total,
    stats_medial,
    stats_lateral,
) -> None:
    if stats_total   is not None:
        shaded_mean_ci(ax, gait_axis, stats_total.mean,   stats_total.ci_half,   line_color=_C_TOTAL,   label="Total")
    if stats_medial  is not None:
        shaded_mean_ci(ax, gait_axis, stats_medial.mean,  stats_medial.ci_half,  line_color=_C_MEDIAL,  label="Medial")
    if stats_lateral is not None:
        shaded_mean_ci(ax, gait_axis, stats_lateral.mean, stats_lateral.ci_half, line_color=_C_LATERAL, label="Lateral")


def _finish_axes(ax: plt.Axes, title: str, ylabel: str) -> None:
    set_gait_cycle_xaxis(ax)
    ax.set_ylabel(ylabel, fontsize=FONT_LABEL)
    ax.set_title(title, fontsize=FONT_TITLE)
    ax.legend(fontsize=FONT_LEGEND)


# ── Per-trial ─────────────────────────────────────────────────────────────────

def plot_trial_joint_mechanics(
    trial: TrialData,
    save: bool = True,
) -> dict[str, matplotlib.figure.Figure]:
    """Generate 9 per-axis joint-mechanics figures + 1 combined pressure/area figure.

    Each of the 9 directional figures (3 forces × 3 directions, 3 moments × 3
    directions, 3 CoP × 3 directions) shows total (black), medial (red), and
    lateral (blue) compartment values over the gait cycle.

    Requires ``config.FORCE_COLUMN_PATTERNS`` to be fully populated.

    Args:
        trial: :class:`~models.trial_data.TrialData`.
        save:  Write PNGs to ``trial.graphics_dir(GRAPHICS_JOINT_MECH)``.

    Returns:
        Dict mapping filename stem → :class:`~matplotlib.figure.Figure`.
    """
    force_cols = trial.force_columns
    bw_n = trial.body_weight_n
    gait_axis = np.linspace(0.0, 100.0, GAIT_CYCLE_POINTS)

    # Normalise only the ~36 relevant columns for speed (not all 700+)
    needed_actual = [
        force_cols[k] for k in force_cols
        if force_cols[k] in trial.force_reporter.columns
    ]
    subset = trial.force_reporter[["time"] + needed_actual]
    norm_df = normalize_dataframe(subset, time_col="time")

    figures: dict[str, matplotlib.figure.Figure] = {}
    out_dir = trial.graphics_dir(GRAPHICS_JOINT_MECH) if save else None

    # ── 9 directional figures ─────────────────────────────────────────────────
    for spec in _SPECS:
        is_force = spec.ylabel.startswith("Joint Contact Force")
        bw_divisor = bw_n if is_force else 1.0

        total   = _extract(norm_df, spec.key_total,   force_cols, spec.scale, bw_divisor)
        medial  = _extract(norm_df, spec.key_medial,  force_cols, spec.scale, bw_divisor)
        lateral = _extract(norm_df, spec.key_lateral, force_cols, spec.scale, bw_divisor)

        fig, ax = plt.subplots(figsize=FIG_KINEMATICS)
        _plot_three_lines(ax, gait_axis, total, medial, lateral)
        _finish_axes(ax, spec.title, spec.ylabel)
        fig.tight_layout()

        if out_dir is not None:
            fig.savefig(out_dir / f"{spec.stem}_plot.png")
        figures[spec.stem] = fig

    # ── Combined pressure/area figure ─────────────────────────────────────────
    fig_pa, axes_pa = plt.subplots(3, 1, figsize=(10, 9), sharex=True)
    fig_pa.suptitle("Contact Pressure and Area", fontsize=FONT_TITLE)

    for ax, paspec in zip(axes_pa, _PRESSURE_AREA_SPECS):
        total   = _extract(norm_df, paspec.key_total,   force_cols, paspec.scale)
        medial  = _extract(norm_df, paspec.key_medial,  force_cols, paspec.scale)
        lateral = _extract(norm_df, paspec.key_lateral, force_cols, paspec.scale)
        _plot_three_lines(ax, gait_axis, total, medial, lateral)
        ax.set_ylabel(paspec.ylabel, fontsize=FONT_LABEL)
        ax.set_title(paspec.title, fontsize=FONT_TITLE - 4)
        ax.legend(fontsize=FONT_LEGEND - 2)

    set_gait_cycle_xaxis(axes_pa[-1])
    fig_pa.tight_layout()

    if out_dir is not None:
        fig_pa.savefig(out_dir / "Pressure_and_Area_plot.png")
    figures["pressure_area"] = fig_pa

    return figures


# ── Group: forces / moments / CoP ─────────────────────────────────────────────

def _stack_force_signal(
    trials: list[TrialData],
    key: str,
    scale: float,
    bw_divisor_fn: Callable[[TrialData], float],
) -> np.ndarray:
    """Stack one resolved force column across all trials → (n_ok, 100) array."""
    rows: list[np.ndarray] = []
    for trial in trials:
        try:
            force_cols = trial.force_columns
            actual = force_cols.get(key)
            if actual is None:
                continue
            subset = trial.force_reporter[["time", actual]]
            norm_df = normalize_dataframe(subset, time_col="time")
            bw_d = bw_divisor_fn(trial)
            rows.append(norm_df[actual].to_numpy(dtype=float) * scale / bw_d)
        except Exception as exc:  # noqa: BLE001
            log.warning("Skipping %s for key '%s': %s", trial.subject_id, key, exc)
    return np.vstack(rows) if rows else np.empty((0, GAIT_CYCLE_POINTS))


def plot_group_joint_mechanics(
    group: GroupResults,
    save: bool = True,
) -> dict[str, matplotlib.figure.Figure]:
    """Generate group mean ± 95 % CI joint-mechanics figures.

    Produces the same 9 directional figures as :func:`plot_trial_joint_mechanics`
    but with three mean ± CI bands (total, medial, lateral) per figure.

    Args:
        group: :class:`~aggregation.group_results.GroupResults`.
        save:  Write PNGs to ``group.output_dir("joint_mechanics")``.

    Returns:
        Dict mapping filename stem → :class:`~matplotlib.figure.Figure`.
    """
    gait_axis = np.linspace(0.0, 100.0, GAIT_CYCLE_POINTS)
    figures: dict[str, matplotlib.figure.Figure] = {}
    out_dir = group.output_dir("joint_mechanics") if save else None

    for spec in _SPECS:
        is_force = spec.ylabel.startswith("Joint Contact Force")
        bw_fn: Callable[[TrialData], float] = (lambda t: t.body_weight_n) if is_force else (lambda t: 1.0)

        def _stats(key: str):
            arr = _stack_force_signal(group.trials, key, spec.scale, bw_fn)
            return group_ci(arr) if arr.shape[0] > 0 else None

        stats_t = _stats(spec.key_total)
        stats_m = _stats(spec.key_medial)
        stats_l = _stats(spec.key_lateral)

        fig, ax = plt.subplots(figsize=FIG_KINEMATICS)
        _plot_three_bands(ax, gait_axis, stats_t, stats_m, stats_l)
        _finish_axes(ax, spec.title, spec.ylabel)
        fig.tight_layout()

        if out_dir is not None:
            fig.savefig(out_dir / f"{spec.stem}_plot.png")
        figures[spec.stem] = fig
        plt.close(fig)

    return figures


def plot_group_pressure_area(
    group: GroupResults,
    save: bool = True,
) -> matplotlib.figure.Figure:
    """Group mean ± CI combined figure for pressure and contact area.

    3 subplots (mean pressure, max pressure, contact area) × 3 bands
    (total, medial, lateral).

    Args:
        group: :class:`~aggregation.group_results.GroupResults`.
        save:  Write PNG to ``group.output_dir("joint_mechanics")``.

    Returns:
        The combined :class:`~matplotlib.figure.Figure`.
    """
    gait_axis = np.linspace(0.0, 100.0, GAIT_CYCLE_POINTS)
    no_bw: Callable[[TrialData], float] = lambda t: 1.0

    fig, axes = plt.subplots(3, 1, figsize=(10, 9), sharex=True)
    fig.suptitle("Group Contact Pressure and Area  (mean ± 95 % CI)", fontsize=FONT_TITLE)

    for ax, paspec in zip(axes, _PRESSURE_AREA_SPECS):
        for key, color in [
            (paspec.key_total,   _C_TOTAL),
            (paspec.key_medial,  _C_MEDIAL),
            (paspec.key_lateral, _C_LATERAL),
        ]:
            arr = _stack_force_signal(group.trials, key, paspec.scale, no_bw)
            if arr.shape[0] > 0:
                stats = group_ci(arr)
                shaded_mean_ci(ax, gait_axis, stats.mean, stats.ci_half,
                               line_color=color,
                               label=key.split("_")[-1].capitalize())

        ax.set_ylabel(paspec.ylabel, fontsize=FONT_LABEL)
        ax.set_title(paspec.title, fontsize=FONT_TITLE - 4)
        ax.legend(fontsize=FONT_LEGEND - 2)

    set_gait_cycle_xaxis(axes[-1])
    fig.tight_layout()

    if save:
        out = group.output_dir("joint_mechanics")
        fig.savefig(out / "combined_joint_mechanics_plot.png")

    return fig
