"""Per-patient and group-level muscle-activation figures.

Replaces
--------
  plot_activations.m               → :func:`plot_trial_activations`
  plot_all_patients_activations.m  → :func:`plot_group_activations`

One PNG is produced per muscle (44) and per reserve actuator (16) = 60 files
per function call.  Figures are created, saved, and closed in a tight loop to
keep memory usage constant regardless of how many subjects are processed.

Per-trial style (matching ``plot_activations.m``)
-------------------------------------------------
* Filled area chart (black, 50 % alpha) — MATLAB ``area(..., 'FaceColor',
  [0 0 0], 'FaceAlpha', 0.5)`` → ``ax.fill_between`` with ``alpha=0.5``.
* Muscle y-axis fixed [0, 1].
* Reserve y-axis auto; label "Force (N)" for translational DOFs (tx/ty/tz),
  "Torque (Nm)" for rotational.
* Slightly smaller fonts than kinematics: title 12, labels 10.

Group style (matching ``plot_all_patients_activations.m``)
----------------------------------------------------------
* Blue mean ± CI band via :func:`~plotting.shaded_ci.shaded_mean_ci`.
* CI denominator fixed: ``n_subjects``, not 100.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.figure

from COMAK.python.config import (
    GAIT_CYCLE_POINTS,
    GRAPHICS_ACTIVATIONS,
    GRAPHICS_RESERVES,
    MUSCLE_DISPLAY_NAMES,
    MUSCLES,
    RESERVE_ACTUATORS,
    RESERVE_FORCE_ACTUATORS,
)
from COMAK.python.aggregation.group_results import GroupResults
from COMAK.python.models.trial_data import TrialData
from COMAK.python.plotting.shaded_ci import shaded_mean_ci
from COMAK.python.plotting.style import (
    COLORS,
    LINE_WIDTH,
    set_gait_cycle_xaxis,
)

# Font sizes for activation plots — MATLAB used smaller sizes here than for
# kinematics (title=12, labels=10) so we respect that distinction.
_TITLE_FS: int = 12
_LABEL_FS: int = 10
_AXES_FS:  int = 10

_MUSCLES_SET: frozenset[str] = frozenset(MUSCLES)
_RESERVES_SET: frozenset[str] = frozenset(RESERVE_ACTUATORS)


# ── Helpers ───────────────────────────────────────────────────────────────────

def _ylabel_for(name: str) -> str:
    """Return the appropriate y-axis label for a muscle or reserve actuator."""
    if name in _MUSCLES_SET:
        return "Activation"
    if name in RESERVE_FORCE_ACTUATORS:
        return "Force (N)"
    return "Torque (Nm)"


def _ylim_for(name: str) -> tuple[float, float] | None:
    """Return fixed y-limits for muscles; None (auto) for reserve actuators."""
    return (0.0, 1.0) if name in _MUSCLES_SET else None


def _out_subdir(name: str) -> str:
    """Return the config graphics subdirectory constant for this element."""
    return GRAPHICS_ACTIVATIONS if name in _MUSCLES_SET else GRAPHICS_RESERVES


def _display(name: str) -> str:
    return MUSCLE_DISPLAY_NAMES.get(name, name)


# ── Per-trial ─────────────────────────────────────────────────────────────────

def _plot_trial_one(
    name: str,
    gait_pct: np.ndarray,
    signal: np.ndarray,
) -> matplotlib.figure.Figure:
    """Filled area chart for one muscle/reserve in one trial."""
    fig, ax = plt.subplots(figsize=(6, 3))

    ax.fill_between(
        gait_pct, 0, signal,
        color="black",
        alpha=0.5,
        linewidth=0,
    )
    ax.plot(gait_pct, signal, color="black", linewidth=0.8)

    set_gait_cycle_xaxis(ax)
    ax.set_ylabel(_ylabel_for(name), fontsize=_LABEL_FS)
    ax.set_title(_display(name), fontsize=_TITLE_FS)

    ylim = _ylim_for(name)
    if ylim is not None:
        ax.set_ylim(ylim)

    ax.tick_params(labelsize=_AXES_FS)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    fig.tight_layout()
    return fig


def plot_trial_activations(
    trial: TrialData,
    save: bool = True,
) -> None:
    """Generate one area-chart PNG per muscle and reserve actuator.

    Produces 44 muscle PNGs in ``graphics/muscle_activations/`` and 16 reserve
    PNGs in ``graphics/reserve_actuators/``.

    Figures are created, saved, and immediately closed to avoid accumulating
    60 open figure objects in memory.

    Args:
        trial: :class:`~models.trial_data.TrialData` for the subject.
        save:  Write PNGs to the subject's graphics directory.  Set to
               ``False`` to skip disk writes (useful for testing).
    """
    act = trial.activation_norm
    gait_pct = act["gait_cycle_pct"].to_numpy(dtype=float)

    muscle_dir = trial.graphics_dir(GRAPHICS_ACTIVATIONS) if save else None
    reserve_dir = trial.graphics_dir(GRAPHICS_RESERVES) if save else None

    for name in list(MUSCLES) + list(RESERVE_ACTUATORS):
        if name not in act.columns:
            continue

        signal = act[name].to_numpy(dtype=float)
        fig = _plot_trial_one(name, gait_pct, signal)

        if save:
            out_dir = muscle_dir if name in _MUSCLES_SET else reserve_dir
            fig.savefig(out_dir / f"{name}.png")

        plt.close(fig)


# ── Group ─────────────────────────────────────────────────────────────────────

def _plot_group_one(
    name: str,
    gait_axis: np.ndarray,
    stats,
) -> matplotlib.figure.Figure:
    """Mean ± CI area band for one muscle/reserve across all subjects."""
    fig, ax = plt.subplots(figsize=(6, 3))

    shaded_mean_ci(
        ax, gait_axis, stats.mean, stats.ci_half,
        label=f"Mean ± 95 % CI  (n={stats.n_subjects})",
    )

    set_gait_cycle_xaxis(ax)
    ax.set_ylabel(_ylabel_for(name), fontsize=_LABEL_FS)
    ax.set_title(_display(name), fontsize=_TITLE_FS)

    ylim = _ylim_for(name)
    if ylim is not None:
        ax.set_ylim(ylim)

    ax.legend(fontsize=_LABEL_FS - 1, loc="upper right")
    ax.tick_params(labelsize=_AXES_FS)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    fig.tight_layout()
    return fig


def plot_group_activations(
    group: GroupResults,
    save: bool = True,
) -> None:
    """Generate group mean ± 95 % CI activation PNG for every muscle and reserve.

    Produces 44 + 16 = 60 PNGs in ``mean_results/muscle_activations/`` and
    ``mean_results/reserve_actuators/``.

    CI computed with the correct ``n_subjects`` denominator (MATLAB bug fixed).

    Args:
        group: :class:`~aggregation.group_results.GroupResults`.
        save:  Write PNGs to ``group.output_dir(...)``.
    """
    gait_axis = np.linspace(0.0, 100.0, GAIT_CYCLE_POINTS)
    stats_map = group.activation_stats

    muscle_dir = group.output_dir("muscle_activations") if save else None
    reserve_dir = group.output_dir("reserve_actuators") if save else None

    for name in list(MUSCLES) + list(RESERVE_ACTUATORS):
        stats = stats_map.get(name)
        if stats is None or stats.n_subjects == 0:
            continue

        fig = _plot_group_one(name, gait_axis, stats)

        if save:
            out_dir = muscle_dir if name in _MUSCLES_SET else reserve_dir
            fig.savefig(out_dir / f"{name}.png")

        plt.close(fig)
