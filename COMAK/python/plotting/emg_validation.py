"""Simulated activation vs EMG linear-envelope comparison figures.

Replaces
--------
  plot_activation_vs_emg.m               → :func:`plot_trial_emg_validation`
  plot_all_patients_activation_vs_emg.m  → :func:`plot_group_emg_validation`

Layout: one 2 × 2 figure, one subplot per EMG-instrumented muscle
(tibant_r, vaslat_r, gaslat_r, bflh_r).

Each subplot uses twin y-axes:
  Left  (blue) — simulated activation, fixed [0, 1]
  Right (red)  — EMG linear envelope (mV), scaled so its peak aligns
                 visually with the activation peak

Cross-correlation metrics are annotated on each subplot.

MATLAB bugs fixed
-----------------
* ``emt_time`` was built from ``Frame`` numbers on line 71, then immediately
  overwritten with ``linspace(0,100,N)`` on line 102.  Python avoids the
  redundant computation: ``emg_norm`` is already on the 100-point grid.
* Exact-float time lookup ``find(emt_data.Time == time_start)`` replaced by
  nearest-sample ``numpy.searchsorted`` in :func:`analysis.emg.extract_emg_cycle`.
* Group CI denominator uses ``n_subjects``, not 100.
"""

from __future__ import annotations

import logging

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.figure

from COMAK.python.config import (
    EMG_CHANNELS,
    EMG_DISPLAY_NAMES,
    GAIT_CYCLE_POINTS,
    GRAPHICS_VALIDATION,
)
from COMAK.python.aggregation.group_results import GroupResults
from COMAK.python.analysis.metrics import cross_correlation, group_ci
from COMAK.python.models.trial_data import TrialData
from COMAK.python.plotting.shaded_ci import shaded_mean_ci
from COMAK.python.plotting.style import (
    COLORS,
    FIG_ACTIVATION,
    FONT_LABEL,
    FONT_LEGEND,
    FONT_TITLE,
    LINE_WIDTH,
    LINE_WIDTH_THIN,
    set_gait_cycle_xaxis,
)

log = logging.getLogger(__name__)

# Muscles with available EMG — order determines 2×2 subplot positions
_EMG_MUSCLES: tuple[str, ...] = ("tibant_r", "vaslat_r", "gaslat_r", "bflh_r")


# ── Dual-axis helper ──────────────────────────────────────────────────────────

def _setup_twin_axes(
    ax: plt.Axes,
) -> tuple[plt.Axes, plt.Axes]:
    """Return (left_ax, right_ax) from an existing Axes, styled for dual-axis."""
    ax_r = ax.twinx()

    # Left axis: blue activation
    ax.set_ylabel("Muscle Activation", fontsize=FONT_LABEL, color=COLORS["simulation"])
    ax.tick_params(axis="y", colors=COLORS["simulation"])
    ax.set_ylim(0, 1)
    ax.yaxis.label.set_color(COLORS["simulation"])

    # Right axis: red EMG
    ax_r.set_ylabel("EMG Signal (mV)", fontsize=FONT_LABEL, color=COLORS["emg"])
    ax_r.tick_params(axis="y", colors=COLORS["emg"])
    ax_r.yaxis.label.set_color(COLORS["emg"])

    return ax, ax_r


def _scale_emg_axis(
    ax_r: plt.Axes,
    act_signal: np.ndarray,
    emg_signal: np.ndarray,
) -> float:
    """Set right y-axis upper limit so EMG peak aligns with activation peak.

    Replicates MATLAB:
        max_emg_axis = (1 / max(act)) * max(emg)
        ylim([0, max_emg_axis])

    This makes the two traces visually comparable — a fully-active muscle
    (activation = 1) and a maximal EMG burst reach the same chart height.
    """
    max_act = float(np.max(act_signal))
    max_emg = float(np.max(emg_signal))
    scale = max_emg / max(max_act, 1e-9)
    ax_r.set_ylim(0, scale)
    return scale


def _annotate_xcorr(
    ax: plt.Axes,
    act: np.ndarray,
    emg: np.ndarray,
    y_scale: float,
) -> None:
    """Compute normalised cross-correlation and annotate the axes."""
    cc = cross_correlation(act, emg)
    # Place annotations at 10 % gait cycle, descending from 80 % of emg scale
    for frac, text in [
        (0.80, f"Max Corr Lag: {cc.lag_at_max:+d} %"),
        (0.70, f"Max Corr: {cc.max_corr:.2f}"),
        (0.60, f"Corr @ Lag 0: {cc.zero_lag_corr:.2f}"),
    ]:
        ax.text(
            0.10, frac, text,
            transform=ax.transAxes,
            fontsize=FONT_LEGEND,
            color="black",
            verticalalignment="top",
        )


# ── Per-trial ─────────────────────────────────────────────────────────────────

def plot_trial_emg_validation(
    trial: TrialData,
    save: bool = True,
) -> matplotlib.figure.Figure:
    """2 × 2 dual-axis activation-vs-EMG figure for one subject.

    Each subplot overlays:
    * Left axis (blue line): simulated muscle activation [0, 1]
    * Right axis (red line): preprocessed EMG linear envelope (mV),
      y-axis scaled to align peaks visually

    Cross-correlation lag, peak, and zero-lag values are annotated on
    each subplot.

    Args:
        trial: :class:`~models.trial_data.TrialData`.
        save:  Write PNG to ``trial.graphics_dir(GRAPHICS_VALIDATION)``.

    Returns:
        The 2 × 2 :class:`~matplotlib.figure.Figure`.
    """
    gait_axis = np.linspace(0.0, 100.0, GAIT_CYCLE_POINTS)

    act_df = trial.activation_norm
    emg_df = trial.emg_norm

    fig, axes = plt.subplots(2, 2, figsize=FIG_ACTIVATION)
    fig.suptitle("Muscle Activation vs EMG", fontsize=FONT_TITLE)

    for ax, name in zip(axes.flat, _EMG_MUSCLES):
        if name not in act_df.columns or name not in emg_df.columns:
            ax.set_visible(False)
            continue

        act = act_df[name].to_numpy(dtype=float)
        emg = emg_df[name].to_numpy(dtype=float)

        ax_l, ax_r = _setup_twin_axes(ax)

        ax_l.plot(gait_axis, act, color=COLORS["simulation"],
                  linewidth=LINE_WIDTH, label="Simulated Activation")
        ax_r.plot(gait_axis, emg, color=COLORS["emg"],
                  linewidth=LINE_WIDTH_THIN, label="EMG Envelope")

        y_scale = _scale_emg_axis(ax_r, act, emg)
        _annotate_xcorr(ax_r, act, emg, y_scale)

        set_gait_cycle_xaxis(ax_l)
        ax_l.set_title(EMG_DISPLAY_NAMES.get(name, name), fontsize=FONT_TITLE - 4)
        ax_l.grid(True, alpha=0.3)

    fig.tight_layout()

    if save:
        out = trial.graphics_dir(GRAPHICS_VALIDATION)
        fig.savefig(out / "muscle_activations_vs_EMG.png")

    return fig


# ── Group ─────────────────────────────────────────────────────────────────────

def plot_group_emg_validation(
    group: GroupResults,
    save: bool = True,
) -> matplotlib.figure.Figure:
    """2 × 2 dual-axis group mean ± CI activation-vs-EMG figure.

    Stacks per-subject activation and EMG signals, computes group mean ± 95 %
    CI, and plots both as shaded bands on twin axes.

    Cross-correlation is computed on the **group mean** signals (not per-subject
    then averaged), matching the MATLAB implementation.

    Args:
        group: :class:`~aggregation.group_results.GroupResults`.
        save:  Write PNG to ``group.output_dir("validation")``.

    Returns:
        The 2 × 2 :class:`~matplotlib.figure.Figure`.
    """
    gait_axis = np.linspace(0.0, 100.0, GAIT_CYCLE_POINTS)

    # ── Stack EMG across subjects ─────────────────────────────────────────────
    emg_stacked: dict[str, list[np.ndarray]] = {m: [] for m in _EMG_MUSCLES}
    for trial in group.trials:
        try:
            emg_df = trial.emg_norm
            for name in _EMG_MUSCLES:
                if name in emg_df.columns:
                    emg_stacked[name].append(emg_df[name].to_numpy(dtype=float))
        except Exception as exc:  # noqa: BLE001
            log.warning("Skipping EMG for %s: %s", trial.subject_id, exc)

    fig, axes = plt.subplots(2, 2, figsize=FIG_ACTIVATION)
    fig.suptitle(
        "Group Muscle Activation vs EMG  (mean ± 95 % CI)",
        fontsize=FONT_TITLE,
    )

    act_stats_map = group.activation_stats

    for ax, name in zip(axes.flat, _EMG_MUSCLES):
        act_stats = act_stats_map.get(name)
        emg_rows = emg_stacked.get(name, [])

        if act_stats is None or not emg_rows:
            ax.set_visible(False)
            continue

        emg_stack = np.vstack(emg_rows)
        emg_stats = group_ci(emg_stack)

        ax_l, ax_r = _setup_twin_axes(ax)

        # Activation band on left axis
        shaded_mean_ci(
            ax_l, gait_axis, act_stats.mean, act_stats.ci_half,
            line_color=COLORS["simulation"],
            label=f"Activation (n={act_stats.n_subjects})",
        )

        # EMG band on right axis
        shaded_mean_ci(
            ax_r, gait_axis, emg_stats.mean, emg_stats.ci_half,
            line_color=COLORS["emg"],
            label=f"EMG (n={emg_stats.n_subjects})",
        )

        _scale_emg_axis(ax_r, act_stats.mean, emg_stats.mean)
        _annotate_xcorr(ax_r, act_stats.mean, emg_stats.mean, 1.0)

        # Subject count annotation
        ax_l.text(
            0.10, 0.95,
            f"n = {act_stats.n_subjects}",
            transform=ax_l.transAxes,
            fontsize=FONT_LEGEND,
            verticalalignment="top",
        )

        set_gait_cycle_xaxis(ax_l)
        ax_l.set_title(EMG_DISPLAY_NAMES.get(name, name), fontsize=FONT_TITLE - 4)
        ax_l.grid(True, alpha=0.3)

    fig.tight_layout()

    if save:
        out = group.output_dir("validation")
        fig.savefig(out / "Population_Level_Activation_vs_EMG.png")

    return fig
