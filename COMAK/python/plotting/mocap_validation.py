"""Simulation-vs-MoCap validation figures.

Replaces
--------
  plot_primary_coordinates_vs_mocap.m          → :func:`plot_trial_mocap_validation`
  plot_primary_coordinates_vs_mocap_save_data.m → merged (broken in MATLAB anyway)
  plot_all_patients_primary_coordinates_vs_mocap.m → :func:`plot_group_mocap_validation`

Produces three output files per trial:

  primary_tibiofemoral_kinematics_with_mocap_1.png
      Two subplots: (1) time-series overlay of simulation vs MoCap knee
      flexion with IK error annotation; (2) scatter plot with identity
      line, linear regression, and R² annotation.

  primary_tibiofemoral_kinematics_with_mocap_2.png
      Bland-Altman limits-of-agreement plot.

And one group-level file:

  mean_results/validation/primary_tibiofemoral_kinematics_with_mocap.png
      Group mean ± 95 % CI band for both simulation and MoCap.

MATLAB differences fixed
------------------------
* ``plot_primary_coordinates_vs_mocap_save_data.m`` was stored wrapped in a
  Markdown code-fence and would not run.  The Python
  port merges both variants into a single function.
* Simulation was resampled to 101 points (``0:100``) while MoCap also has 101
  samples; both are now standardised to ``GAIT_CYCLE_POINTS = 100`` via
  :func:`analysis.normalization.normalize_to_gait_cycle`.
* IK error stats use the t-distribution CI (correct) rather than z = 1.96
  (which is only appropriate asymptotically); see :func:`analysis.metrics.ik_error_stats`.
"""

from __future__ import annotations

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.figure

from COMAK.python.config import (
    GAIT_CYCLE_POINTS,
    GRAPHICS_VALIDATION,
    MOCAP_KNEE_FLEXION_COL,
    MOCAP_SAMPLE_COL,
)
from COMAK.python.aggregation.group_results import GroupResults
from COMAK.python.analysis.metrics import (
    bland_altman,
    linear_regression,
    mae,
    max_error,
    r_squared,
)
from COMAK.python.analysis.normalization import normalize_to_gait_cycle
from COMAK.python.models.trial_data import TrialData
from COMAK.python.plotting.shaded_ci import shaded_mean_ci
from COMAK.python.plotting.style import (
    COLORS,
    FIG_BLAND_ALTMAN,
    FIG_VALIDATION,
    FONT_AXES,
    FONT_LABEL,
    FONT_LEGEND,
    FONT_TITLE,
    LINE_WIDTH,
    LINE_WIDTH_THICK,
    LINE_WIDTH_THIN,
    set_gait_cycle_xaxis,
)


# ── Internal: align MoCap to the standard gait-cycle grid ────────────────────

def _resample_mocap(angle_cycles_df) -> np.ndarray:
    """Interpolate MoCap knee-flexion onto the 100-point gait-cycle grid.

    The BTS 1D_Angle_Cycles file stores gait-cycle-normalised angles.  Each
    row is one uniform sample across the gait cycle (0 – 100 %).  We treat
    row position as the gait-cycle axis and interpolate onto the standard
    linspace(0, 100, 100) grid — bypassing the ``Sample`` column entirely
    to avoid column-alignment issues with the BTS tab-separated format.
    """
    flex = angle_cycles_df[MOCAP_KNEE_FLEXION_COL].to_numpy(dtype=float)
    n = len(flex)
    src_pct = np.linspace(0.0, 100.0, n)
    dst_pct = np.linspace(0.0, 100.0, GAIT_CYCLE_POINTS)
    return np.interp(dst_pct, src_pct, flex)


# ── Figure 1: time series + scatter ──────────────────────────────────────────

def _plot_timeseries_panel(
    ax: plt.Axes,
    gait_axis: np.ndarray,
    sim: np.ndarray,
    mocap: np.ndarray,
    ik_stats,
    mae_val: float,
    max_err_val: float,
) -> None:
    """Subplot 1: overlay MoCap and simulation time-series with metric text."""
    ax.plot(
        gait_axis, mocap,
        color=COLORS["mocap"],
        linewidth=LINE_WIDTH_THIN,
        label="Motion Capture",
    )
    ax.plot(
        gait_axis, sim,
        color=COLORS["simulation"],
        linewidth=LINE_WIDTH_THICK,
        label="Simulation",
    )

    # Metric annotations — top-left, matching MATLAB text() calls
    txt_x, txt_y_start, dy = 0.02, 0.95, 0.10
    texts = [
        f"MAE: {mae_val:.2f} °",
        f"Max Error: {max_err_val:.2f} °",
        "IK marker errors:",
        f"  RMS: {ik_stats.mean_rms*100:.2f} ± {ik_stats.ci_rms*100:.2f} cm",
        f"  Max: {ik_stats.mean_max*100:.2f} ± {ik_stats.ci_max*100:.2f} cm",
    ]
    for i, txt in enumerate(texts):
        ax.text(
            txt_x, txt_y_start - i * dy, txt,
            transform=ax.transAxes,
            fontsize=FONT_LEGEND,
            verticalalignment="top",
        )

    set_gait_cycle_xaxis(ax)
    ax.set_ylabel("Angle [deg]", fontsize=FONT_LABEL)
    ax.set_title(
        "Comparison of Knee Flexion-Extension Angles",
        fontsize=FONT_TITLE,
    )
    ax.legend(fontsize=FONT_LEGEND, loc="upper right")


def _plot_scatter_panel(
    ax: plt.Axes,
    sim: np.ndarray,
    mocap: np.ndarray,
    r2: float,
) -> None:
    """Subplot 2: scatter + identity line + regression line + R² annotation."""
    ax.scatter(mocap, sim, color=COLORS["simulation"], alpha=0.6, s=20)

    x_range = np.array([mocap.min(), mocap.max()])

    # Identity (perfect agreement) line
    ax.plot(
        x_range, x_range,
        color=COLORS["reference"],
        linestyle="--",
        linewidth=LINE_WIDTH_THIN,
        label="Perfect Agreement",
    )

    # Linear regression (skipped when input is degenerate)
    slope, intercept = linear_regression(mocap, sim)
    if np.isfinite(slope):
        ax.plot(
            x_range, slope * x_range + intercept,
            color=COLORS["regression"],
            linewidth=LINE_WIDTH_THICK,
            label="Linear Fit",
        )

    ax.text(
        0.05, 0.92, f"R² = {r2:.2f}",
        transform=ax.transAxes,
        fontsize=FONT_LEGEND,
        verticalalignment="top",
    )

    ax.set_xlabel("Motion Capture Angles [deg]", fontsize=FONT_LABEL)
    ax.set_ylabel("Simulation Angles [deg]", fontsize=FONT_LABEL)
    ax.set_title(
        "Correlation of Motion Capture vs Simulation Angles",
        fontsize=FONT_TITLE,
    )
    ax.legend(fontsize=FONT_LEGEND, loc="best")


def _make_timeseries_scatter_figure(
    gait_axis: np.ndarray,
    sim: np.ndarray,
    mocap: np.ndarray,
    ik_stats,
) -> matplotlib.figure.Figure:
    mae_val = mae(mocap, sim)
    max_err_val = max_error(mocap, sim)
    r2 = r_squared(mocap, sim)

    fig, (ax_ts, ax_sc) = plt.subplots(2, 1, figsize=FIG_VALIDATION)

    _plot_timeseries_panel(ax_ts, gait_axis, sim, mocap, ik_stats, mae_val, max_err_val)
    _plot_scatter_panel(ax_sc, sim, mocap, r2)

    fig.tight_layout()
    return fig


# ── Figure 2: Bland-Altman ────────────────────────────────────────────────────

def _make_bland_altman_figure(
    sim: np.ndarray,
    mocap: np.ndarray,
) -> matplotlib.figure.Figure:
    ba = bland_altman(sim, mocap)

    fig, ax = plt.subplots(figsize=FIG_BLAND_ALTMAN)

    ax.scatter(ba.averages, ba.differences, color=COLORS["bland_altman"], alpha=0.6, s=20)

    x_min, x_max = ba.averages.min(), ba.averages.max()
    x_pad = 0.02 * (x_max - x_min)

    # Mean difference (bias) line
    ax.axhline(ba.mean_diff, color="red", linewidth=LINE_WIDTH_THICK, label=f"Mean diff: {ba.mean_diff:.2f}°")

    # Limits of agreement
    for loa, label in [
        (ba.loa_upper, f"LoA upper: {ba.loa_upper:.2f}°"),
        (ba.loa_lower, f"LoA lower: {ba.loa_lower:.2f}°"),
    ]:
        ax.axhline(loa, color=COLORS["loa"], linestyle="--", linewidth=LINE_WIDTH_THIN, label=label)

    ax.axhline(0, color="#bbbbbb", linewidth=0.8, linestyle=":")

    ax.set_xlabel("Mean of MoCap and Simulation Angles [deg]", fontsize=FONT_LABEL)
    ax.set_ylabel("Difference (Simulation − MoCap) [deg]", fontsize=FONT_LABEL)
    ax.set_title("Bland-Altman Plot of Agreement Between Methods", fontsize=FONT_TITLE)
    ax.legend(fontsize=FONT_LEGEND, loc="best")

    fig.tight_layout()
    return fig


# ── Public: per-trial ─────────────────────────────────────────────────────────

def plot_trial_mocap_validation(
    trial: TrialData,
    save: bool = True,
) -> dict[str, matplotlib.figure.Figure]:
    """Generate simulation-vs-MoCap validation figures for one subject.

    Produces two PNG files:
    * ``primary_tibiofemoral_kinematics_with_mocap_1.png`` — time-series
      overlay + scatter with IK error annotation.
    * ``primary_tibiofemoral_kinematics_with_mocap_2.png`` — Bland-Altman.

    Args:
        trial: :class:`~models.trial_data.TrialData` for the subject.
        save:  Write PNGs to ``trial.graphics_dir(GRAPHICS_VALIDATION)``.

    Returns:
        ``{"timeseries_scatter": fig1, "bland_altman": fig2}``
    """
    gait_axis = np.linspace(0.0, 100.0, GAIT_CYCLE_POINTS)

    sim = trial.kinematics_norm["knee_flex_r"].to_numpy(dtype=float)
    mocap = _resample_mocap(trial.angle_cycles)

    fig1 = _make_timeseries_scatter_figure(gait_axis, sim, mocap, trial.ik_stats)
    fig2 = _make_bland_altman_figure(sim, mocap)

    if save:
        out = trial.graphics_dir(GRAPHICS_VALIDATION)
        fig1.savefig(out / "primary_tibiofemoral_kinematics_with_mocap_1.png")
        fig2.savefig(out / "primary_tibiofemoral_kinematics_with_mocap_2.png")

    return {"timeseries_scatter": fig1, "bland_altman": fig2}


# ── Public: group ─────────────────────────────────────────────────────────────

def plot_group_mocap_validation(
    group: GroupResults,
    save: bool = True,
) -> matplotlib.figure.Figure:
    """Group mean ± 95 % CI overlay of simulation and MoCap knee flexion.

    Both curves are shown on the same axes with different colours so the
    systematic offset (bias) between methods is immediately visible.

    Args:
        group: :class:`~aggregation.group_results.GroupResults`.
        save:  Write PNG to ``group.output_dir("validation")``.

    Returns:
        The single :class:`~matplotlib.figure.Figure`.
    """
    from COMAK.python.analysis.metrics import group_ci
    from COMAK.python.analysis.normalization import normalize_to_gait_cycle

    gait_axis = np.linspace(0.0, 100.0, GAIT_CYCLE_POINTS)

    # ── Simulation ────────────────────────────────────────────────────────────
    sim_stats = group.kinematics_stats.get("knee_flex_r")

    # ── MoCap — resample each subject's BTS data then stack ──────────────────
    mocap_rows: list[np.ndarray] = []
    for trial in group.trials:
        try:
            mocap_rows.append(_resample_mocap(trial.angle_cycles))
        except Exception:  # noqa: BLE001
            pass

    fig, ax = plt.subplots(figsize=(10, 5))

    if mocap_rows:
        import numpy as _np
        mocap_stack = _np.vstack(mocap_rows)
        mocap_stats = group_ci(mocap_stack)
        shaded_mean_ci(
            ax, gait_axis, mocap_stats.mean, mocap_stats.ci_half,
            line_color=COLORS["mocap"],
            label=f"MoCap (n={mocap_stats.n_subjects})",
        )

    if sim_stats is not None:
        shaded_mean_ci(
            ax, gait_axis, sim_stats.mean, sim_stats.ci_half,
            line_color=COLORS["simulation"],
            label=f"Simulation (n={sim_stats.n_subjects})",
        )

    set_gait_cycle_xaxis(ax)
    ax.set_ylabel("Knee Flexion Angle [deg]", fontsize=FONT_LABEL)
    ax.set_title(
        "Group Knee Flexion: Simulation vs Motion Capture  (mean ± 95 % CI)",
        fontsize=FONT_TITLE,
    )
    ax.legend(fontsize=FONT_LEGEND)
    fig.tight_layout()

    if save:
        out = group.output_dir("validation")
        fig.savefig(out / "primary_tibiofemoral_kinematics_with_mocap.png")

    return fig
