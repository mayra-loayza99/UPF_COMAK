"""Group-level aggregation: stack per-subject signals and compute group statistics.

``GroupResults`` collects a list of :class:`~models.trial_data.TrialData`
objects and provides stacked (n_subjects × n_gait_points) arrays and
:class:`~analysis.metrics.GroupStats` for every signal.

The MATLAB all-patients scripts (``plot_all_patients_*.m``) replicated the
same scan-normalise-stack loop four times with the CI denominator bug in each.
This module performs the stacking once per signal type and delegates CI
computation to :func:`analysis.metrics.group_ci` where the bug is fixed.

Subject discovery
-----------------
:func:`discover_trials` scans ``comak_root/results/`` for subject
sub-directories, inferring ``project_id`` and ``subject_id`` from the
directory name (``{project_id}_{subject_id}`` convention, e.g. ``STRATO_001``).
Subjects whose simulation files are missing are skipped with a warning rather
than raising an exception, matching the MATLAB ``try / catch / continue`` logic.
"""

from __future__ import annotations

import logging
import warnings
from dataclasses import dataclass, field
from functools import cached_property
from pathlib import Path
from typing import Callable

import numpy as np
import pandas as pd

from COMAK.python.config import (
    EXCLUDED_RESULT_DIRS,
    GAIT_CYCLE_POINTS,
    MUSCLES,
    RESERVE_ACTUATORS,
    TF_ROTATIONS,
    TF_TRANSLATIONS,
    PF_ROTATIONS,
    PF_TRANSLATIONS,
    MEAN_RESULTS_DIR,
)
from COMAK.python.analysis.metrics import GroupStats, group_ci
from COMAK.python.models.trial_data import TrialData

log = logging.getLogger(__name__)


# ── Subject discovery ─────────────────────────────────────────────────────────

def discover_trials(
    comak_root: Path | str,
    emg_sampling_freq: float = 1000.0,
) -> list[TrialData]:
    """Scan ``results/`` and return one :class:`TrialData` per valid subject.

    Reads every immediate subdirectory of ``comak_root/results/``, skipping
    names listed in ``config.EXCLUDED_RESULT_DIRS``.  Infers ``project_id``
    and ``subject_id`` by splitting on the final underscore
    (``"STRATO_001"`` → project ``"STRATO"``, subject ``"001"``).

    Args:
        comak_root:        Absolute path to the ``COMAK/`` directory.
        emg_sampling_freq: EMG acquisition rate in Hz, forwarded to every
                           :class:`TrialData` (default 1000 Hz).

    Returns:
        List of :class:`TrialData` objects sorted by ``subject_id``.

    Raises:
        FileNotFoundError: If ``comak_root/results/`` does not exist.
    """
    root = Path(comak_root)
    results_dir = root / "results"
    if not results_dir.exists():
        raise FileNotFoundError(
            f"Results directory not found: {results_dir}\n"
            "Run at least one simulation before calling discover_trials()."
        )

    trials: list[TrialData] = []
    for subdir in sorted(results_dir.iterdir()):
        if not subdir.is_dir():
            continue
        if subdir.name in EXCLUDED_RESULT_DIRS:
            continue
        if subdir.name.startswith("."):
            continue
        # "STRATO_001" → ("STRATO", "001")
        parts = subdir.name.rsplit("_", 1)
        if len(parts) != 2:
            log.warning("Skipping directory with unexpected name format: %s", subdir.name)
            continue
        project_id, subject_id = parts
        trials.append(
            TrialData(
                subject_id=subject_id,
                project_id=project_id,
                comak_root=root,
                emg_sampling_freq=emg_sampling_freq,
            )
        )
    return trials


# ── Internal stacking helper ──────────────────────────────────────────────────

def _stack_signal(
    trials: list[TrialData],
    signal_names: list[str],
    get_df: Callable[[TrialData], pd.DataFrame],
) -> dict[str, np.ndarray]:
    """Build ``{signal_name: (n_subjects, n_points)}`` arrays, skipping failures.

    Args:
        trials:       All trial objects.
        signal_names: Column names to extract from the DataFrame.
        get_df:       Callable that takes a :class:`TrialData` and returns a
                      normalised DataFrame (e.g. ``lambda t: t.kinematics_norm``).

    Returns:
        Dict mapping signal name → 2-D array of shape ``(n_ok, GAIT_CYCLE_POINTS)``
        where ``n_ok`` is the number of subjects whose data loaded without error.
    """
    stacked: dict[str, list[np.ndarray]] = {name: [] for name in signal_names}

    for trial in trials:
        try:
            df = get_df(trial)
        except Exception as exc:  # noqa: BLE001
            log.warning(
                "Skipping %s (%s): %s",
                trial.subject_id, type(exc).__name__, exc,
            )
            continue

        for name in signal_names:
            if name not in df.columns:
                log.warning(
                    "Column '%s' missing for subject %s — skipping signal.",
                    name, trial.subject_id,
                )
                continue
            stacked[name].append(df[name].to_numpy(dtype=float))

    return {
        name: np.vstack(rows) if rows else np.empty((0, GAIT_CYCLE_POINTS))
        for name, rows in stacked.items()
    }


# ── GroupResults ──────────────────────────────────────────────────────────────

@dataclass
class GroupResults:
    """Aggregated results across all subjects.

    Construct via :meth:`from_results_dir` for automatic subject discovery, or
    pass a hand-picked list of :class:`TrialData` objects directly.

    Attributes:
        trials:    All per-subject data objects.
        comak_root: ``COMAK/`` directory, used to build output paths.
    """

    trials: list[TrialData]
    comak_root: Path

    def __post_init__(self) -> None:
        self.comak_root = Path(self.comak_root)

    # ── Constructor ───────────────────────────────────────────────────────────

    @classmethod
    def from_results_dir(
        cls,
        comak_root: Path | str,
        emg_sampling_freq: float = 1000.0,
    ) -> "GroupResults":
        """Discover all subjects and return a :class:`GroupResults`.

        Args:
            comak_root:        ``COMAK/`` root directory.
            emg_sampling_freq: EMG acquisition rate forwarded to each trial.
        """
        root = Path(comak_root)
        trials = discover_trials(root, emg_sampling_freq)
        return cls(trials=trials, comak_root=root)

    # ── Basic properties ──────────────────────────────────────────────────────

    @property
    def subject_ids(self) -> list[str]:
        return [t.subject_id for t in self.trials]

    @property
    def n_subjects(self) -> int:
        return len(self.trials)

    def output_dir(self, subdir: str = "") -> Path:
        """Return (and create) a group-results output subdirectory.

        Mirrors ``comak_root/mean_results/{subdir}``, matching the MATLAB
        ``'../mean_results/...'`` output convention.

        Args:
            subdir: Subfolder name, e.g. ``"kinematics"`` or ``"validation"``.
        """
        base = self.comak_root / MEAN_RESULTS_DIR
        p = base / subdir if subdir else base
        p.mkdir(parents=True, exist_ok=True)
        return p

    # ── Kinematics ────────────────────────────────────────────────────────────

    @cached_property
    def _all_coord_names(self) -> list[str]:
        return [
            c.name
            for c in TF_ROTATIONS + TF_TRANSLATIONS + PF_ROTATIONS + PF_TRANSLATIONS
        ]

    @cached_property
    def kinematics_stacked(self) -> dict[str, np.ndarray]:
        """``{coord_name: (n_subjects, 100)}`` array of gait-cycle-normalised kinematics.

        Uses :attr:`~models.trial_data.TrialData.kinematics_norm` (linear
        interpolation only, no Savitzky-Golay) matching the standard
        ``plot_all_patients_kinematics.m`` behaviour.  Values are in raw
        OpenSim units; apply ``config.CoordSpec.scale`` when plotting.
        """
        return _stack_signal(
            self.trials,
            self._all_coord_names,
            lambda t: t.kinematics_norm,
        )

    @cached_property
    def kinematics_stats(self) -> dict[str, GroupStats]:
        """Per-DOF :class:`~analysis.metrics.GroupStats` across all subjects."""
        return {
            name: group_ci(arr)
            for name, arr in self.kinematics_stacked.items()
            if arr.shape[0] > 0
        }

    # ── Activations ───────────────────────────────────────────────────────────

    @cached_property
    def _all_activation_names(self) -> list[str]:
        return list(MUSCLES) + list(RESERVE_ACTUATORS)

    @cached_property
    def activation_stacked(self) -> dict[str, np.ndarray]:
        """``{muscle_name: (n_subjects, 100)}`` array of gait-cycle-normalised activations."""
        return _stack_signal(
            self.trials,
            self._all_activation_names,
            lambda t: t.activation_norm,
        )

    @cached_property
    def activation_stats(self) -> dict[str, GroupStats]:
        """Per-muscle :class:`~analysis.metrics.GroupStats` across all subjects."""
        return {
            name: group_ci(arr)
            for name, arr in self.activation_stacked.items()
            if arr.shape[0] > 0
        }

    # ── MoCap knee flexion ────────────────────────────────────────────────────

    @cached_property
    def mocap_knee_flex_stacked(self) -> np.ndarray:
        """``(n_subjects, N)`` array of MoCap knee-flexion angles (degrees).

        Each row is the ``acmRKFE.M`` column from one subject's
        ``1D_Angle_Cycles_*.emt`` file.  The number of columns equals the
        number of samples in the BTS file (typically 101); use
        :func:`analysis.normalization.normalize_to_gait_cycle` if 100-point
        alignment is needed before group statistics.
        """
        rows: list[np.ndarray] = []
        from COMAK.python.config import MOCAP_KNEE_FLEXION_COL
        for trial in self.trials:
            try:
                col = trial.angle_cycles[MOCAP_KNEE_FLEXION_COL].to_numpy(dtype=float)
                rows.append(col)
            except Exception as exc:  # noqa: BLE001
                log.warning(
                    "Skipping MoCap data for %s: %s", trial.subject_id, exc
                )
        return np.vstack(rows) if rows else np.empty((0,))

    @cached_property
    def sim_knee_flex_stacked(self) -> np.ndarray:
        """``(n_subjects, 100)`` array of simulated knee-flexion angles (degrees).

        Extracts ``knee_flex_r`` from each trial's :attr:`kinematics_norm`
        and stacks into a 2-D array for the group MoCap-vs-simulation comparison.
        """
        from COMAK.python.config import MOCAP_KNEE_FLEXION_COL
        arr = self.kinematics_stacked.get("knee_flex_r")
        return arr if arr is not None else np.empty((0, GAIT_CYCLE_POINTS))

    # ── Convenience ───────────────────────────────────────────────────────────

    def __repr__(self) -> str:
        return (
            f"GroupResults(n_subjects={self.n_subjects}, "
            f"subjects={self.subject_ids})"
        )
