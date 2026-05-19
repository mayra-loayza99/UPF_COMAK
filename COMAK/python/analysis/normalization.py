"""Gait-cycle normalization utilities.

The COMAK pipeline needs two distinct operations on every signal before it can
be compared across subjects or joints:

1. **Time-percentage mapping** — convert wall-clock seconds to 0–100 % of
   the gait cycle (the unit used on all x-axes).

2. **Resampling to a fixed grid** — interpolate onto ``config.GAIT_CYCLE_POINTS``
   (100) uniformly-spaced points so signals from different trials (which may
   have different step durations and therefore different sample counts) can be
   stacked into a 2-D array for group statistics.

3. **Optional Savitzky-Golay smoothing** — the ``*_save_data`` MATLAB scripts
   applied ``sgolayfilt(data_norm, 3, 11)`` after resampling.  The smoothing is
   used only for the structured output that feeds SPM / group statistics, not for
   the per-patient diagnostic plots.

MATLAB equivalents replaced
---------------------------
``interp1(Time_normed, data, linspace(0,100,100), 'linear')``
    → :func:`normalize_to_gait_cycle`

``fit(time_norm', data, fittype('linearinterp'))``
    → :func:`normalize_to_gait_cycle`  (identical result, different syntax)

``sgolayfilt(data_norm, 3, 11)``
    → :func:`smooth_savgol`

MATLAB inconsistency fixed
--------------------------
``plot_primary_coordinates_vs_mocap.m`` used ``Time_normed = 0:100`` (101 points)
while all other scripts used ``linspace(0,100,100)`` (100 points).  All Python
functions standardise on ``config.GAIT_CYCLE_POINTS = 100``.
"""

from __future__ import annotations

import numpy as np
import pandas as pd
from scipy.signal import savgol_filter

from COMAK.python.config import GAIT_CYCLE_POINTS


def percent_time(
    time: np.ndarray,
    t_start: float | None = None,
    t_stop: float | None = None,
) -> np.ndarray:
    """Map an absolute time array to 0–100 % of the gait cycle.

    Does **not** resample: the returned array has the same length as *time*.
    Use this when you want to plot the raw-resolution signal on a % axis
    (as in ``plot_kinematics.m``).

    Args:
        time: 1-D array of time values in seconds.
        t_start: Wall-clock time of gait-cycle start (0 %).  Defaults to
            ``time[0]`` when *None*.
        t_stop:  Wall-clock time of gait-cycle end (100 %).  Defaults to
            ``time[-1]`` when *None*.

    Returns:
        1-D float64 array in [0, 100].

    Raises:
        ValueError: If ``t_start >= t_stop``.
    """
    t0 = float(time[0]) if t_start is None else float(t_start)
    t1 = float(time[-1]) if t_stop is None else float(t_stop)
    if t0 >= t1:
        raise ValueError(
            f"t_start ({t0}) must be strictly less than t_stop ({t1})"
        )
    return (np.asarray(time, dtype=float) - t0) / (t1 - t0) * 100.0


def normalize_to_gait_cycle(
    time: np.ndarray,
    signal: np.ndarray,
    t_start: float | None = None,
    t_stop: float | None = None,
    n_points: int = GAIT_CYCLE_POINTS,
) -> tuple[np.ndarray, np.ndarray]:
    """Resample *signal* onto a uniform 0–100 % gait-cycle grid.

    Internally maps *time* to percent via :func:`percent_time`, then uses
    linear interpolation (``numpy.interp``) onto *n_points* uniformly-spaced
    nodes.  This matches MATLAB's ``interp1(..., 'linear')`` and the Curve
    Fitting Toolbox ``fit(..., 'linearinterp')`` — both produce identical
    results for monotonically-increasing time.

    Args:
        time:    1-D array of time values in seconds (must be monotonically
                 increasing).
        signal:  1-D array of signal values, same length as *time*.
        t_start: Gait-cycle start time (seconds).  Defaults to ``time[0]``.
        t_stop:  Gait-cycle end time (seconds).  Defaults to ``time[-1]``.
        n_points: Number of output samples on the 0–100 % grid.  Defaults to
                  ``config.GAIT_CYCLE_POINTS`` (100).

    Returns:
        ``(gait_axis, resampled)`` where *gait_axis* is the uniform grid
        (``numpy.linspace(0, 100, n_points)``) and *resampled* is the
        interpolated signal.
    """
    pct = percent_time(time, t_start, t_stop)
    gait_axis = np.linspace(0.0, 100.0, n_points)
    resampled = np.interp(gait_axis, pct, np.asarray(signal, dtype=float))
    return gait_axis, resampled


def smooth_savgol(
    signal: np.ndarray,
    window: int = 11,
    polyorder: int = 3,
) -> np.ndarray:
    """Apply a Savitzky-Golay smoothing filter.

    Equivalent to MATLAB's ``sgolayfilt(signal, polyorder, window)``.

    The default ``window=11, polyorder=3`` matches the ``*_save_data`` MATLAB
    scripts.  The window must be odd and larger than *polyorder*.

    Args:
        signal:    1-D float array (already resampled to the gait-cycle grid).
        window:    Number of points in the filter window (must be odd).
        polyorder: Polynomial order of the filter.

    Returns:
        Smoothed 1-D array, same length as *signal*.
    """
    return savgol_filter(signal, window_length=window, polyorder=polyorder)


def normalize_dataframe(
    df: pd.DataFrame,
    t_start: float | None = None,
    t_stop: float | None = None,
    time_col: str = "time",
    n_points: int = GAIT_CYCLE_POINTS,
    smooth: bool = False,
) -> pd.DataFrame:
    """Resample every non-time column of *df* onto the gait-cycle grid.

    Applies :func:`normalize_to_gait_cycle` to each data column vectorially.
    The returned DataFrame has a ``"gait_cycle_pct"`` column as its index and
    one column per input signal column (all time columns are dropped).

    This is the high-level entry point used by ``TrialData`` when computing
    ``kinematics_norm``, ``activation_norm``, etc.

    Args:
        df:       DataFrame with a continuous time column and signal columns.
        t_start:  Gait-cycle start (seconds).  Defaults to first row of *time_col*.
        t_stop:   Gait-cycle end (seconds).    Defaults to last row of *time_col*.
        time_col: Name of the time column in *df*.  Defaults to ``"time"``.
        n_points: Output grid length.  Defaults to ``GAIT_CYCLE_POINTS``.
        smooth:   If ``True``, apply Savitzky-Golay smoothing after
                  resampling (mirrors the ``*_save_data`` variant behaviour).

    Returns:
        DataFrame indexed by ``"gait_cycle_pct"`` (0–100), one column per
        signal.  ``df.attrs`` is forwarded to the returned DataFrame.

    Raises:
        KeyError: If *time_col* is not in *df*.
    """
    if time_col not in df.columns:
        raise KeyError(f"Time column '{time_col}' not found in DataFrame")

    time = df[time_col].to_numpy(dtype=float)
    gait_axis = np.linspace(0.0, 100.0, n_points)

    pct = percent_time(time, t_start, t_stop)

    signal_cols = [c for c in df.columns if c != time_col]
    data_matrix = df[signal_cols].to_numpy(dtype=float)

    # Vectorised interpolation: each column independently, one np.interp call each.
    # n_points rows × n_cols columns — avoid a Python loop over rows.
    resampled = np.column_stack(
        [np.interp(gait_axis, pct, data_matrix[:, j]) for j in range(data_matrix.shape[1])]
    )

    if smooth:
        resampled = np.column_stack(
            [smooth_savgol(resampled[:, j]) for j in range(resampled.shape[1])]
        )

    result = pd.DataFrame(resampled, columns=signal_cols)
    result.insert(0, "gait_cycle_pct", gait_axis)
    result.attrs.update(df.attrs)
    return result
