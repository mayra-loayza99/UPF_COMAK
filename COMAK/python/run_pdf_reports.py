"""Generate per-subject figures as individual PDF files in Frontiers journal style.

Usage
-----
Run from the repository root::

    python COMAK/python/run_pdf_reports.py <comak_root> [--subject HOLOA_040]

Each figure is saved as a PDF alongside the existing PNGs, inside the subject's
existing ``graphics/`` subdirectories::

    results/<SUBJECT>/graphics/
      kinematics/
        tibiofemoral_rotations.pdf
        tibiofemoral_translations.pdf
        patellofemoral_rotations.pdf
        patellofemoral_translations.pdf
      validation/
        primary_tibiofemoral_kinematics_with_mocap_1.pdf
        primary_tibiofemoral_kinematics_with_mocap_2.pdf
      muscle_activations/
        muscle_activations.pdf
        reserve_actuators.pdf
      extended_joint_mechanics/
        joint_mechanics_force.pdf
        joint_mechanics_moment.pdf
        joint_mechanics_pressure.pdf
        joint_mechanics_area.pdf

Frontiers formatting
--------------------
  Figure width   : 180 mm (full-text-width, double-column layout)
  Font family    : Arial (falls back to DejaVu Sans if not installed)
  Font sizes     : title 10 pt, axis labels 9 pt, ticks 8 pt, legend 8 pt
  Line widths    : 1.5 pt data lines, 0.8 pt axes
  DPI            : 300 (also sets the vector PDF rasterization resolution)
  Background     : white, no top/right spines
"""

from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from COMAK.python.aggregation.group_results import discover_trials
from COMAK.python.models.trial_data import TrialData
from COMAK.python.config import (
    GAIT_CYCLE_POINTS,
    GRAPHICS_KINEMATICS,
    GRAPHICS_VALIDATION,
    GRAPHICS_ACTIVATIONS,
    GRAPHICS_RESERVES,
    GRAPHICS_JOINT_MECH,
)
from COMAK.python.plotting.style import COLORS

log = logging.getLogger(__name__)

# ── Frontiers rcParams ────────────────────────────────────────────────────────

FIG_W = 7.0866   # 180 mm — Frontiers full-text-width

FRONTIERS_RC: dict = {
    "font.family":           "sans-serif",
    "font.sans-serif":       ["Arial", "Helvetica", "DejaVu Sans"],
    "font.size":             8,
    "axes.labelsize":        9,
    "axes.titlesize":        10,
    "axes.linewidth":        0.8,
    "axes.spines.top":       False,
    "axes.spines.right":     False,
    "axes.facecolor":        "white",
    "axes.grid":             True,
    "axes.grid.which":       "major",
    "grid.alpha":            0.25,
    "grid.color":            "#cccccc",
    "grid.linewidth":        0.5,
    "xtick.labelsize":       8,
    "ytick.labelsize":       8,
    "xtick.major.width":     0.6,
    "ytick.major.width":     0.6,
    "xtick.major.size":      3,
    "ytick.major.size":      3,
    "lines.linewidth":       1.5,
    "legend.fontsize":       8,
    "legend.framealpha":     0.85,
    "legend.edgecolor":      "none",
    "figure.facecolor":      "white",
    "savefig.dpi":           300,
    "savefig.bbox":          "tight",
    "savefig.facecolor":     "white",
}


def _apply_frontiers() -> None:
    matplotlib.rcParams.update(FRONTIERS_RC)


def _set_gait_xaxis(ax: plt.Axes) -> None:
    ax.set_xlabel("Gait Cycle [%]")
    ax.set_xticks(range(0, 101, 10))
    ax.set_xlim(0, 100)


def _save_pdf(fig: matplotlib.figure.Figure, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(str(path), format="pdf", bbox_inches="tight")
    plt.close(fig)


# ── Kinematics ────────────────────────────────────────────────────────────────

def _pdf_kinematics(trial: TrialData) -> None:
    from COMAK.python.config import (
        TF_ROTATIONS, TF_TRANSLATIONS,
        PF_ROTATIONS, PF_TRANSLATIONS,
    )

    groups = [
        ("tibiofemoral_rotations",     "Tibiofemoral Rotations",     TF_ROTATIONS),
        ("tibiofemoral_translations",  "Tibiofemoral Translations",  TF_TRANSLATIONS),
        ("patellofemoral_rotations",   "Patellofemoral Rotations",   PF_ROTATIONS),
        ("patellofemoral_translations","Patellofemoral Translations",PF_TRANSLATIONS),
    ]

    kin = trial.kinematics_norm
    gait_pct = kin["gait_cycle_pct"].to_numpy(dtype=float)
    out = trial.graphics_dir(GRAPHICS_KINEMATICS)

    for stem, title, coords in groups:
        fig, axes = plt.subplots(3, 1, figsize=(FIG_W, 5.91), sharex=True)
        fig.suptitle(title, fontsize=10, fontweight="bold", y=1.01)

        for ax, coord in zip(axes, coords):
            if coord.name not in kin.columns:
                ax.set_visible(False)
                continue
            data = kin[coord.name].to_numpy(dtype=float) * coord.scale
            ax.plot(gait_pct, data, color=COLORS["simulation"], linewidth=1.5)
            ax.set_ylabel(f"{coord.label}\n[{coord.unit}]", fontsize=9)
            ax.set_title(coord.name, fontsize=8, pad=2, color="#555555")

        _set_gait_xaxis(axes[-1])
        fig.tight_layout()
        _save_pdf(fig, out / f"{stem}.pdf")


# ── MoCap validation ──────────────────────────────────────────────────────────

def _pdf_mocap_validation(trial: TrialData) -> None:
    from COMAK.python.analysis.metrics import (
        mae, max_error, r_squared, linear_regression, bland_altman,
    )
    from COMAK.python.plotting.mocap_validation import _resample_mocap

    gait = np.linspace(0.0, 100.0, GAIT_CYCLE_POINTS)
    sim  = trial.kinematics_norm["knee_flex_r"].to_numpy(dtype=float)
    mocap = _resample_mocap(trial.angle_cycles)
    ik    = trial.ik_stats

    mae_v = mae(mocap, sim)
    max_e = max_error(mocap, sim)
    r2    = r_squared(mocap, sim)
    out   = trial.graphics_dir(GRAPHICS_VALIDATION)

    # Figure 1: time-series + scatter
    fig1, (ax_ts, ax_sc) = plt.subplots(2, 1, figsize=(FIG_W, 5.71))
    fig1.suptitle("Simulation vs. Motion-Capture Knee Flexion", fontsize=10, fontweight="bold")

    ax_ts.plot(gait, mocap, color=COLORS["mocap"],      linewidth=1.5, label="Motion Capture")
    ax_ts.plot(gait, sim,   color=COLORS["simulation"], linewidth=1.5, label="Simulation")
    ax_ts.text(0.02, 0.97,
               f"MAE: {mae_v:.2f}°   Max error: {max_e:.2f}°\n"
               f"IK RMS: {ik.mean_rms*100:.2f} ± {ik.ci_rms*100:.2f} cm   "
               f"IK Max: {ik.mean_max*100:.2f} ± {ik.ci_max*100:.2f} cm",
               transform=ax_ts.transAxes, fontsize=7, va="top")
    _set_gait_xaxis(ax_ts)
    ax_ts.set_ylabel("Angle [deg]")
    ax_ts.legend(loc="upper right")

    ax_sc.scatter(mocap, sim, color=COLORS["simulation"], alpha=0.55, s=8)
    x_range = np.array([mocap.min(), mocap.max()])
    ax_sc.plot(x_range, x_range, color=COLORS["reference"], linestyle="--",
               linewidth=1.0, label="Perfect agreement")
    slope, intercept = linear_regression(mocap, sim)
    if np.isfinite(slope):
        ax_sc.plot(x_range, slope * x_range + intercept,
                   color=COLORS["regression"], linewidth=1.5, label="Linear fit")
    ax_sc.text(0.05, 0.92, f"R² = {r2:.3f}", transform=ax_sc.transAxes, fontsize=8, va="top")
    ax_sc.set_xlabel("Motion Capture [deg]")
    ax_sc.set_ylabel("Simulation [deg]")
    ax_sc.legend(loc="upper left")

    fig1.tight_layout()
    _save_pdf(fig1, out / "primary_tibiofemoral_kinematics_with_mocap_1.pdf")

    # Figure 2: Bland-Altman
    ba = bland_altman(sim, mocap)
    fig2, ax_ba = plt.subplots(figsize=(FIG_W, 3.54))
    fig2.suptitle("Bland-Altman: Simulation − Motion Capture", fontsize=10, fontweight="bold")

    ax_ba.scatter(ba.averages, ba.differences, color=COLORS["bland_altman"], alpha=0.55, s=8)
    ax_ba.axhline(ba.mean_diff,  color="red",           linewidth=1.5,
                  label=f"Bias: {ba.mean_diff:.2f}°")
    ax_ba.axhline(ba.loa_upper, color=COLORS["loa"],    linewidth=1.0, linestyle="--",
                  label=f"LoA: [{ba.loa_lower:.2f}, {ba.loa_upper:.2f}]°")
    ax_ba.axhline(ba.loa_lower, color=COLORS["loa"],    linewidth=1.0, linestyle="--")
    ax_ba.axhline(0,            color="#bbbbbb",         linewidth=0.6, linestyle=":")
    ax_ba.set_xlabel("Mean of MoCap and Simulation [deg]")
    ax_ba.set_ylabel("Difference (Sim − MoCap) [deg]")
    ax_ba.legend(loc="best")
    fig2.tight_layout()
    _save_pdf(fig2, out / "primary_tibiofemoral_kinematics_with_mocap_2.pdf")


# ── Muscle activations ────────────────────────────────────────────────────────

def _pdf_activations(trial: TrialData) -> None:
    from COMAK.python.config import MUSCLES, RESERVE_ACTUATORS
    from COMAK.python.config import MUSCLE_DISPLAY_NAMES as _MUSCLE_DISPLAY_NAMES

    act  = trial.activation_norm
    gait = act["gait_cycle_pct"].to_numpy(dtype=float)
    out  = trial.graphics_dir(GRAPHICS_ACTIVATIONS)

    def _make_activation_grid(
        muscle_list: list[str],
        title: str,
        filename: str,
        out_dir: Path,
    ) -> None:
        n = len(muscle_list)
        if n == 0:
            return
        ncols = 3
        nrows = int(np.ceil(n / ncols))
        fig, axes = plt.subplots(
            nrows, ncols,
            figsize=(FIG_W, max(3.94, nrows * 1.6)),
            sharex=True,
        )
        fig.suptitle(title, fontsize=10, fontweight="bold", y=1.01)
        axes_flat = np.array(axes).flatten()

        for i, muscle in enumerate(muscle_list):
            ax = axes_flat[i]
            if muscle in act.columns:
                ax.plot(gait, act[muscle].to_numpy(dtype=float),
                        color=COLORS["simulation"], linewidth=1.5)
            label = _MUSCLE_DISPLAY_NAMES.get(muscle, muscle)
            ax.set_title(label, fontsize=7, pad=2)
            ax.set_ylim(0, 1.05)
            ax.set_ylabel("Activation", fontsize=7)
            if i >= n - ncols:
                _set_gait_xaxis(ax)

        for j in range(i + 1, len(axes_flat)):
            axes_flat[j].set_visible(False)

        fig.tight_layout()
        _save_pdf(fig, out_dir / filename)

    _make_activation_grid(list(MUSCLES), "Predicted Muscle Activations",
                          "muscle_activations.pdf", out)
    _make_activation_grid(
        list(RESERVE_ACTUATORS), "Reserve Actuator Activations",
        "reserve_actuators.pdf", trial.graphics_dir(GRAPHICS_RESERVES),
    )


# ── EMG validation ────────────────────────────────────────────────────────────

def _pdf_emg_validation(trial: TrialData) -> None:
    from COMAK.python.config import EMG_CHANNELS
    from COMAK.python.config import MUSCLE_DISPLAY_NAMES as _MUSCLE_DISPLAY_NAMES

    act  = trial.activation_norm
    emg  = trial.emg_norm
    gait = act["gait_cycle_pct"].to_numpy(dtype=float)
    emg_gait = emg["gait_cycle_pct"].to_numpy(dtype=float)
    out  = trial.graphics_dir(GRAPHICS_VALIDATION)

    pairs = [(m, ch) for m, ch in EMG_CHANNELS.items()
             if m in act.columns and ch in emg.columns]
    if not pairs:
        log.warning("  [%s] EMG validation: no matching channel pairs", trial.subject_id)
        return

    ncols = 2
    nrows = int(np.ceil(len(pairs) / ncols))
    fig, axes = plt.subplots(
        nrows, ncols,
        figsize=(FIG_W, max(3.94, nrows * 1.8)),
        sharex=True,
    )
    fig.suptitle("Predicted Activation vs. Measured EMG", fontsize=10, fontweight="bold", y=1.01)
    axes_flat = np.array(axes).flatten()

    for idx, (muscle, channel) in enumerate(pairs):
        ax = axes_flat[idx]
        emg_vals = emg[channel].to_numpy(dtype=float)
        act_vals = act[muscle].to_numpy(dtype=float)

        emg_max = emg_vals.max()
        if emg_max > 0:
            emg_vals = emg_vals / emg_max

        ax.fill_between(emg_gait, emg_vals, alpha=0.28, color=COLORS["emg"],
                        label="EMG (norm.)")
        ax.plot(emg_gait, emg_vals, color=COLORS["emg"],       linewidth=0.8)
        ax.plot(gait,     act_vals, color=COLORS["simulation"], linewidth=1.5,
                label="Simulation")
        ax.set_title(_MUSCLE_DISPLAY_NAMES.get(muscle, muscle), fontsize=7, pad=2)
        ax.set_ylim(0, 1.15)
        if idx % ncols == 0:
            ax.set_ylabel("Activation / EMG", fontsize=7)
        if idx >= len(pairs) - ncols:
            _set_gait_xaxis(ax)
        if idx == 0:
            ax.legend(fontsize=7, loc="upper right")

    for j in range(idx + 1, len(axes_flat)):
        axes_flat[j].set_visible(False)

    fig.tight_layout()
    _save_pdf(fig, out / "activation_vs_emg.pdf")


# ── Joint mechanics ───────────────────────────────────────────────────────────

def _pdf_joint_mechanics(trial: TrialData) -> None:
    from COMAK.python.analysis.normalization import normalize_dataframe

    fc   = trial.force_columns
    fr   = trial.force_reporter
    fr_norm = normalize_dataframe(fr, time_col="time")
    gait = fr_norm["gait_cycle_pct"].to_numpy(dtype=float)
    bw   = trial.body_weight_n
    out  = trial.graphics_dir(GRAPHICS_JOINT_MECH)

    def _get(key: str) -> np.ndarray | None:
        col = fc.get(key)
        if col and col in fr_norm.columns:
            return fr_norm[col].to_numpy(dtype=float)
        return None

    panels = [
        # (filename, suptitle, [(key, ylabel, color), ...], divisor)
        (
            "joint_mechanics_force.pdf",
            "Tibiofemoral Contact Forces — Y component",
            [
                ("force_total_y",   "Total [× BW]",   COLORS["simulation"]),
                ("force_medial_y",  "Medial [× BW]",  "#2ca02c"),
                ("force_lateral_y", "Lateral [× BW]", "#ff7f0e"),
            ],
            bw,
        ),
        (
            "joint_mechanics_moment.pdf",
            "Tibiofemoral Contact Moments — Y component",
            [
                ("moment_total_y",   "Total [N·m/BW]",   COLORS["simulation"]),
                ("moment_medial_y",  "Medial [N·m/BW]",  "#2ca02c"),
                ("moment_lateral_y", "Lateral [N·m/BW]", "#ff7f0e"),
            ],
            bw,
        ),
        (
            "joint_mechanics_pressure.pdf",
            "Mean Contact Pressure",
            [
                ("mean_pressure_total",   "Total [MPa]",   COLORS["simulation"]),
                ("mean_pressure_medial",  "Medial [MPa]",  "#2ca02c"),
                ("mean_pressure_lateral", "Lateral [MPa]", "#ff7f0e"),
            ],
            1.0,
        ),
        (
            "joint_mechanics_area.pdf",
            "Contact Area",
            [
                ("area_total",   "Total [cm²]",   COLORS["simulation"]),
                ("area_medial",  "Medial [cm²]",  "#2ca02c"),
                ("area_lateral", "Lateral [cm²]", "#ff7f0e"),
            ],
            1e-4,  # m² → cm²  (divide by 1e-4 = multiply by 1e4)
        ),
    ]

    for filename, title, rows, divisor in panels:
        fig, axes = plt.subplots(3, 1, figsize=(FIG_W, 5.91), sharex=True)
        fig.suptitle(title, fontsize=10, fontweight="bold")

        for ax, (key, ylabel, color) in zip(axes, rows):
            data = _get(key)
            if data is not None:
                scaled = data / divisor if divisor != 1e-4 else data * 1e4
                ax.plot(gait, scaled, color=color, linewidth=1.5)
            ax.set_ylabel(ylabel, fontsize=8)

        _set_gait_xaxis(axes[-1])
        fig.tight_layout()
        _save_pdf(fig, out / filename)


# ── Per-trial orchestrator ────────────────────────────────────────────────────

def _run_pdf_step(label: str, fn, trial: TrialData) -> bool:
    try:
        fn(trial)
        log.info("  [%s] %s done", trial.subject_id, label)
        return True
    except FileNotFoundError as exc:
        log.warning("  [%s] %s skipped — file not found: %s", trial.subject_id, label, exc)
        return True
    except Exception:
        log.exception("  [%s] %s FAILED", trial.subject_id, label)
        return False


def process_trial(trial: TrialData) -> bool:
    """Generate all PDF figures for one subject. Returns True if all steps succeeded."""
    ok = True
    ok &= _run_pdf_step("kinematics",       _pdf_kinematics,        trial)
    ok &= _run_pdf_step("MoCap validation", _pdf_mocap_validation,  trial)
    ok &= _run_pdf_step("activations",      _pdf_activations,       trial)
    ok &= _run_pdf_step("EMG validation",   _pdf_emg_validation,    trial)
    ok &= _run_pdf_step("joint mechanics",  _pdf_joint_mechanics,   trial)
    return ok


# ── Entry point ───────────────────────────────────────────────────────────────

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Generate per-subject figures as PDFs in Frontiers journal style.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "comak_root",
        help="Path to the COMAK/ root directory (contains results/, processed_data/, …).",
    )
    parser.add_argument(
        "--subject", metavar="SUBJECT_ID", default=None,
        help="Generate PDFs for this subject only (e.g. HOLOA_040).",
    )
    parser.add_argument(
        "--emg-hz", type=float, default=1000.0, metavar="HZ",
    )
    parser.add_argument("--verbose", "-v", action="store_true")
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s  %(message)s",
    )

    _apply_frontiers()

    root = Path(args.comak_root)
    if not root.is_dir():
        log.error("comak_root does not exist: %s", root)
        return 1

    trials = discover_trials(root, emg_sampling_freq=args.emg_hz)
    if not trials:
        log.error("No subjects found under %s/results/", root)
        return 1

    if args.subject:
        trials = [t for t in trials if f"{t.project_id}_{t.subject_id}" == args.subject]
        if not trials:
            log.error("Subject '%s' not found.", args.subject)
            return 1

    n_ok = n_fail = 0
    for i, trial in enumerate(trials, 1):
        tag = f"{trial.project_id}_{trial.subject_id}"
        log.info("(%d/%d)  %s", i, len(trials), tag)
        if process_trial(trial):
            n_ok += 1
        else:
            n_fail += 1
        plt.close("all")

    log.info("Done.  %d / %d subjects OK.", n_ok, len(trials))
    return 0 if n_fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
