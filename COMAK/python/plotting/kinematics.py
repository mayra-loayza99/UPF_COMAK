"""Per-patient and group-level joint-kinematics figures.

Replaces
--------
  plot_kinematics.m                  → :func:`plot_trial_kinematics`
  plot_kinematics_save_data.m        → merged into :func:`plot_trial_kinematics`
  plot_all_patients_kinematics.m     → :func:`plot_group_kinematics`
  plot_all_patients_kinematics_save_data.m  → merged into :func:`plot_group_kinematics`

Each public function produces four figures — one per joint/motion-type
combination (tibiofemoral rotations, tibiofemoral translations, patellofemoral
rotations, patellofemoral translations) — and saves them as PNG files.

MATLAB differences
------------------
* Translation data is converted m → mm via ``CoordSpec.scale``; MATLAB did
  this with an inline ``if contains(…'Translation') … * 1000`` check.
* The ``*_save_data`` variants are merged: the returned dict always contains
  the normalised arrays, so no separate function is needed.
* Group CI uses the correct ``n_subjects`` denominator (MATLAB bug fixed in
  :func:`analysis.metrics.group_ci`).
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.figure

from COMAK.python.config import (
    CoordSpec,
    GAIT_CYCLE_POINTS,
    GRAPHICS_KINEMATICS,
    PF_ROTATIONS,
    PF_TRANSLATIONS,
    TF_ROTATIONS,
    TF_TRANSLATIONS,
)
from COMAK.python.aggregation.group_results import GroupResults
from COMAK.python.models.trial_data import TrialData
from COMAK.python.plotting.shaded_ci import shaded_mean_ci
from COMAK.python.plotting.style import (
    COLORS,
    FONT_LABEL,
    FONT_TITLE,
    FIG_KINEMATICS,
    LINE_WIDTH,
    LINE_WIDTH_THICK,
    set_gait_cycle_xaxis,
)


# ── Figure groups: (output filename stem, title, coord tuple) ─────────────────

_FIGURE_GROUPS: list[tuple[str, str, tuple[CoordSpec, ...]]] = [
    ("tibiofemoral_rotations",    "Tibiofemoral Rotations",    TF_ROTATIONS),
    ("tibiofemoral_translations", "Tibiofemoral Translations", TF_TRANSLATIONS),
    ("patellofemoral_rotations",  "Patellofemoral Rotations",  PF_ROTATIONS),
    ("patellofemoral_translations","Patellofemoral Translations", PF_TRANSLATIONS),
]


# ── Internal helpers ──────────────────────────────────────────────────────────

def _make_coord_figure(
    title: str,
) -> tuple[matplotlib.figure.Figure, list[plt.Axes]]:
    """Create a 3-row figure for one coordinate group."""
    fig, axes = plt.subplots(3, 1, figsize=FIG_KINEMATICS, sharex=True)
    fig.suptitle(title, fontsize=FONT_TITLE, y=1.01)
    return fig, list(axes)


def _apply_subplot_labels(
    ax: plt.Axes,
    coord: CoordSpec,
    is_last: bool,
) -> None:
    ax.set_title(f"{coord.label} ({coord.name})", fontsize=FONT_TITLE - 2)
    ax.set_ylabel(coord.unit, fontsize=FONT_LABEL)
    if is_last:
        set_gait_cycle_xaxis(ax)


# ── Per-patient figure ────────────────────────────────────────────────────────

def _plot_trial_coord_group(
    coords: tuple[CoordSpec, ...],
    gait_pct: np.ndarray,
    kinematics_df,
    title: str,
) -> matplotlib.figure.Figure:
    """One 3-subplot figure for a single trial."""
    fig, axes = _make_coord_figure(title)

    for ax, coord in zip(axes, coords):
        if coord.name not in kinematics_df.columns:
            ax.set_visible(False)
            continue
        data = kinematics_df[coord.name].to_numpy(dtype=float) * coord.scale
        ax.plot(gait_pct, data, color=COLORS["simulation"], linewidth=LINE_WIDTH)
        _apply_subplot_labels(ax, coord, ax is axes[-1])

    fig.tight_layout()
    return fig


def plot_trial_kinematics(
    trial: TrialData,
    save: bool = True,
) -> dict[str, matplotlib.figure.Figure]:
    """Generate per-patient TF and PF kinematics figures.

    Plots each of the 12 joint degrees of freedom (6 tibiofemoral, 6
    patellofemoral) on a 0–100 % gait-cycle x-axis.  Translations are
    converted from metres to millimetres via ``CoordSpec.scale``.

    Args:
        trial: Fully-loaded :class:`~models.trial_data.TrialData`.
        save:  If ``True`` (default), save each figure as a PNG in
               ``trial.graphics_dir(GRAPHICS_KINEMATICS)``.

    Returns:
        Dict mapping filename stem → :class:`~matplotlib.figure.Figure`,
        e.g. ``{"tibiofemoral_rotations": <Figure>}``.
    """
    kin = trial.kinematics_norm
    gait_pct = kin["gait_cycle_pct"].to_numpy(dtype=float)

    figures: dict[str, matplotlib.figure.Figure] = {}
    out_dir = trial.graphics_dir(GRAPHICS_KINEMATICS) if save else None

    for stem, title, coords in _FIGURE_GROUPS:
        fig = _plot_trial_coord_group(coords, gait_pct, kin, title)
        if out_dir is not None:
            fig.savefig(out_dir / f"{stem}.png")
        figures[stem] = fig

    return figures


# ── Group figure ──────────────────────────────────────────────────────────────

def _plot_group_coord_group(
    coords: tuple[CoordSpec, ...],
    gait_axis: np.ndarray,
    kinematics_stats: dict,
    title: str,
) -> matplotlib.figure.Figure:
    """One 3-subplot figure with mean ± CI band across all subjects."""
    fig, axes = _make_coord_figure(title)

    for ax, coord in zip(axes, coords):
        stats = kinematics_stats.get(coord.name)
        if stats is None:
            ax.set_visible(False)
            continue

        mean = stats.mean * coord.scale
        ci = stats.ci_half * coord.scale

        shaded_mean_ci(
            ax, gait_axis, mean, ci,
            label=f"Mean ± 95 % CI  (n={stats.n_subjects})",
        )
        _apply_subplot_labels(ax, coord, ax is axes[-1])
        ax.legend(fontsize=10, loc="upper right")

    fig.tight_layout()
    return fig


def plot_group_kinematics(
    group: GroupResults,
    save: bool = True,
) -> dict[str, matplotlib.figure.Figure]:
    """Generate group-level mean ± 95 % CI kinematics figures.

    One figure per coordinate group (TF rotations, TF translations, PF
    rotations, PF translations), each with 3 subplots.  The CI is computed
    from the correct ``n_subjects`` denominator, fixing the MATLAB bug in
    ``plot_all_patients_kinematics.m`` (which divided by √100 instead of
    √n_subjects).

    Args:
        group: :class:`~aggregation.group_results.GroupResults` with at least
               one successfully loaded trial.
        save:  If ``True`` (default), save each figure in
               ``group.output_dir("kinematics")``.

    Returns:
        Dict mapping filename stem → :class:`~matplotlib.figure.Figure`.
    """
    gait_axis = np.linspace(0.0, 100.0, GAIT_CYCLE_POINTS)
    stats = group.kinematics_stats
    figures: dict[str, matplotlib.figure.Figure] = {}
    out_dir = group.output_dir("kinematics") if save else None

    for stem, title, coords in _FIGURE_GROUPS:
        fig = _plot_group_coord_group(coords, gait_axis, stats, title)
        if out_dir is not None:
            fig.savefig(out_dir / f"{stem}.png")
        figures[stem] = fig

    return figures
