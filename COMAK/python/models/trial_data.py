"""Per-subject trial container with lazy-loaded data and derived quantities.

``TrialData`` is the central object that all plotting functions receive.  It
knows where every file lives, reads them on first access, and caches the result
so repeated accesses do not re-read from disk.

Directory layout assumed (rooted at *comak_root*, the ``COMAK/`` folder):

    data/{project_id}_{subject_id}/
        Masses_*.emt
        walking/
            1D_Angle_Cycles_*.emt
            EMG_Tracks_*.emt
            Event_Sequences_*.emt

    results/{project_id}_{subject_id}/
        comak/
            walking_{subject_id}_values.sto
            walking_{subject_id}_activation.sto
        comak_inverse_kinematics/
            walking_{subject_id}_ik_marker_errors.sto
        joint_mechanics/
            walking_{subject_id}_ForceReporter_forces.sto
        graphics/
            kinematics/
            validation/
            muscle_activations/
            reserve_actuators/
            extended_joint_mechanics/
            paraview/

All path constants come from ``config`` so nothing is hardcoded here.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from functools import cached_property
from pathlib import Path

import pandas as pd

from COMAK.python.config import (
    DATA_SUBDIR,
    SUBDIR_COMAK,
    SUBDIR_GRAPHICS,
    SUBDIR_IK,
    SUBDIR_JOINT_MECH,
    STO_ACTIVATION,
    STO_COMAK_VALUES,
    STO_FORCE_REPORTER,
    STO_IK_ERRORS,
)
from COMAK.python.analysis.emg import extract_emg_cycle
from COMAK.python.analysis.metrics import IKErrorStats, ik_error_stats
from COMAK.python.analysis.normalization import normalize_dataframe
from COMAK.python.io.emt_reader import (
    read_angle_cycles,
    read_body_weight,
    read_emg,
    read_event_sequences,
)
from COMAK.python.io.force_columns import resolve_force_columns
from COMAK.python.io.sto_reader import read_sto


@dataclass
class TrialData:
    """All data for one subject's walking trial.

    Attributes:
        subject_id:        Three-digit identifier string, e.g. ``"001"``.
        project_id:        Study identifier, e.g. ``"STRATO"``.
        comak_root:        Absolute path to the ``COMAK/`` directory.
        emg_sampling_freq: EMG acquisition rate in Hz.  BTS systems typically
                           record surface EMG at 1000 Hz; check the acquisition
                           protocol if this value is different.
    """

    subject_id: str
    project_id: str
    comak_root: Path
    emg_sampling_freq: float = 1000.0

    def __post_init__(self) -> None:
        self.comak_root = Path(self.comak_root)

    def __repr__(self) -> str:
        return (
            f"TrialData(subject={self.subject_id!r}, "
            f"project={self.project_id!r}, "
            f"root={str(self.comak_root)!r})"
        )

    # ── Directory helpers ─────────────────────────────────────────────────────

    @property
    def _subject_tag(self) -> str:
        """``"{project_id}_{subject_id}"``, e.g. ``"STRATO_001"``."""
        return f"{self.project_id}_{self.subject_id}"

    @property
    def _data_dir(self) -> Path:
        return self.comak_root / DATA_SUBDIR / self._subject_tag

    @property
    def _walking_dir(self) -> Path:
        return self._data_dir / "walking"

    @property
    def _result_dir(self) -> Path:
        return self.comak_root / "results" / self._subject_tag

    @property
    def _comak_dir(self) -> Path:
        return self._result_dir / SUBDIR_COMAK

    @property
    def _ik_dir(self) -> Path:
        return self._result_dir / SUBDIR_IK

    @property
    def _joint_mech_dir(self) -> Path:
        return self._result_dir / SUBDIR_JOINT_MECH

    @property
    def _graphics_root(self) -> Path:
        return self._result_dir / SUBDIR_GRAPHICS

    def graphics_dir(self, subdir: str = "") -> Path:
        """Return (and create) a graphics output subdirectory.

        Args:
            subdir: One of the ``config.GRAPHICS_*`` constants, e.g.
                    ``config.GRAPHICS_KINEMATICS``.  Pass ``""`` for the
                    top-level graphics folder.

        Returns:
            Resolved :class:`Path` that is guaranteed to exist.
        """
        p = self._graphics_root / subdir if subdir else self._graphics_root
        p.mkdir(parents=True, exist_ok=True)
        return p

    # ── Raw data — lazy, cached ───────────────────────────────────────────────

    @cached_property
    def body_weight_kg(self) -> float:
        """Body mass in kg, from ``Masses_*.emt``."""
        return read_body_weight(self._data_dir)

    @cached_property
    def body_weight_n(self) -> float:
        """Body weight in Newtons (kg × 9.81), used to normalise contact forces."""
        return self.body_weight_kg * 9.81

    @cached_property
    def comak_values(self) -> pd.DataFrame:
        """COMAK joint coordinate output (``*_values.sto``).

        Columns: ``time`` + all joint DOFs (radians / metres in raw OpenSim
        units).  Apply ``config.CoordSpec.scale`` when converting to display
        units (degrees are already in degrees; translations need ×1000 m→mm).
        """
        fname = STO_COMAK_VALUES.format(subject_id=self.subject_id)
        return read_sto(self._comak_dir / fname)

    @cached_property
    def activation(self) -> pd.DataFrame:
        """Muscle and reserve-actuator activations (``*_activation.sto``).

        Columns: ``time`` + one column per element in ``config.MUSCLES`` and
        ``config.RESERVE_ACTUATORS``.  Values are dimensionless in [0, 1].
        """
        fname = STO_ACTIVATION.format(subject_id=self.subject_id)
        return read_sto(self._comak_dir / fname)

    @cached_property
    def ik_errors(self) -> pd.DataFrame:
        """IK marker tracking errors (``*_ik_marker_errors.sto``).

        Column layout (0-based): time, ?, RMS error (m), max error (m).
        Used by :attr:`ik_stats` and ``plotting.mocap_validation``.
        """
        fname = STO_IK_ERRORS.format(subject_id=self.subject_id)
        return read_sto(self._ik_dir / fname)

    @cached_property
    def force_reporter(self) -> pd.DataFrame:
        """JointMechanicsTool ForceReporter output (``*_ForceReporter_forces.sto``).

        Column names are model-specific.  Use :attr:`force_columns` to map
        logical quantities to actual column names rather than accessing columns
        by index.

        This file only exists after at least one simulation run.  The file has
        700+ columns; loading it is the most expensive I/O operation in the
        pipeline.
        """
        fname = STO_FORCE_REPORTER.format(subject_id=self.subject_id)
        return read_sto(self._joint_mech_dir / fname)

    @cached_property
    def angle_cycles(self) -> pd.DataFrame:
        """BTS MoCap gait-cycle-normalised knee angles (``1D_Angle_Cycles_*.emt``).

        Columns: ``Sample`` (0-based integer, 0–100 or 0–101) + angle channels.
        ``config.MOCAP_KNEE_FLEXION_COL`` (``"acmRKFE.M"``) is the right knee
        flexion mean used for simulation validation.
        """
        matches = sorted(self._walking_dir.glob("*Angle*"))
        if not matches:
            raise FileNotFoundError(
                f"No Angle Cycles .emt found in {self._walking_dir}"
            )
        return read_angle_cycles(matches[0])

    @cached_property
    def event_sequences(self) -> pd.DataFrame:
        """BTS gait-event timestamps (``Event_Sequences_*.emt``).

        Columns: Item, eRHS, eRTO, eLHS, eLTO (seconds).  Missing events are
        NaN.  The right heel-strike pair defines the gait cycle window:
            ``gait_start = event_sequences["eRHS"].iloc[0]``
            ``gait_stop  = event_sequences["eRHS"].iloc[1]``
        """
        matches = sorted(self._walking_dir.glob("*Event*"))
        if not matches:
            raise FileNotFoundError(
                f"No Event Sequences .emt found in {self._walking_dir}"
            )
        return read_event_sequences(matches[0])

    @cached_property
    def emg_raw(self) -> pd.DataFrame:
        """Raw multi-channel EMG recording (``EMG_Tracks_*.emt``).

        Columns: ``Frame``, ``Time`` (seconds), then one column per electrode
        site using the original BTS names (e.g. ``"Right Tibialis anterior"``).
        ``config.EMG_CHANNELS`` maps OpenSim muscle names to these column headers.
        """
        matches = sorted(self._walking_dir.glob("*EMG*"))
        if not matches:
            raise FileNotFoundError(
                f"No EMG Tracks .emt found in {self._walking_dir}"
            )
        return read_emg(matches[0])

    # ── Gait-cycle window ─────────────────────────────────────────────────────

    @cached_property
    def gait_start(self) -> float:
        """First right heel-strike time (seconds) — gait-cycle start."""
        return float(self.event_sequences["eRHS"].iloc[0])

    @cached_property
    def gait_stop(self) -> float:
        """Second right heel-strike time (seconds) — gait-cycle end."""
        return float(self.event_sequences["eRHS"].iloc[1])

    # ── Normalised signals — lazy, cached ─────────────────────────────────────

    @cached_property
    def kinematics_norm(self) -> pd.DataFrame:
        """COMAK joint coordinates resampled to the 100-point gait-cycle grid.

        Normalises over the **full trial time** (first to last simulation
        frame), matching ``plot_kinematics.m``.  Values remain in raw OpenSim
        units (radians/metres); apply ``config.CoordSpec.scale`` when plotting.

        Columns: ``gait_cycle_pct`` + all DOF columns from :attr:`comak_values`.
        """
        return normalize_dataframe(self.comak_values, time_col="time")

    @cached_property
    def kinematics_norm_smooth(self) -> pd.DataFrame:
        """Savitzky-Golay smoothed version of :attr:`kinematics_norm`.

        Intended for group statistics / SPM inputs, matching the
        ``plot_kinematics_save_data.m`` behaviour (``sgolayfilt(data, 3, 11)``).
        Not used for per-patient diagnostic plots.
        """
        return normalize_dataframe(
            self.comak_values, time_col="time", smooth=True
        )

    @cached_property
    def activation_norm(self) -> pd.DataFrame:
        """Muscle activations resampled to the 100-point gait-cycle grid.

        Normalises over the full trial time, matching ``plot_activations.m``.
        Values are dimensionless in [0, 1].

        Columns: ``gait_cycle_pct`` + all activation columns.
        """
        return normalize_dataframe(self.activation, time_col="time")

    @cached_property
    def emg_cycle(self) -> pd.DataFrame:
        """Preprocessed EMG channels for the gait-cycle window.

        Calls :func:`analysis.emg.extract_emg_cycle` with the heel-strike
        window ``[gait_start, gait_stop]``.  Returns a DataFrame with:
            ``Time`` — wall-clock seconds (use with ``normalize_dataframe``)
            one column per muscle in ``config.EMG_CHANNELS`` (named by OpenSim
            muscle identifier, e.g. ``"tibant_r"``)
        """
        return extract_emg_cycle(
            self.emg_raw,
            self.gait_start,
            self.gait_stop,
            self.emg_sampling_freq,
        )

    @cached_property
    def emg_norm(self) -> pd.DataFrame:
        """EMG linear envelope resampled to the 100-point gait-cycle grid.

        Normalises :attr:`emg_cycle` over the heel-strike window so that 0 %
        aligns with the first right heel-strike and 100 % with the second.

        Columns: ``gait_cycle_pct`` + muscle columns from :attr:`emg_cycle`.
        """
        return normalize_dataframe(self.emg_cycle, time_col="Time")

    @cached_property
    def force_columns(self) -> dict[str, str]:
        """Resolved mapping of logical force names to actual column names.

        Calls :func:`io.force_columns.resolve_force_columns` on
        :attr:`force_reporter`.  Raises ``ValueError`` if
        ``config.FORCE_COLUMN_PATTERNS`` has not been populated yet (all
        ``None`` until the first simulation is run and
        ``tools/discover_force_columns.py`` is used).
        """
        return resolve_force_columns(self.force_reporter)

    @cached_property
    def ik_stats(self) -> IKErrorStats:
        """IK marker-error summary statistics for this trial.

        See :func:`analysis.metrics.ik_error_stats` for field definitions.
        Values are in metres; multiply by 100 to convert to centimetres for
        display (matching the MATLAB ``*100`` in the annotation strings).
        """
        return ik_error_stats(self.ik_errors)
