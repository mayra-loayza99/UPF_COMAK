"""EMG preprocessing pipeline.

Standard pre-processing chain for surface EMG recorded during gait:

1. **Offset removal** — subtract the mean of the first *offset_duration* seconds
   to remove electrode DC offset and amplifier drift.
2. **Zero-phase Butterworth high-pass filter** — removes low-frequency movement
   artefacts (human joint kinematics produce energy below ~6 Hz; the standard
   cutoff used here is 20 Hz).  Zero-phase is critical: using a causal filter
   would introduce a time delay that corrupts the timing comparison with the
   simulation activation.
3. **Full-wave rectification** — ``abs()`` converts biphasic raw EMG into a
   signal proportional to muscle fibre recruitment.
4. **Moving-average smoothing** — low-pass linear envelope (default 50 ms
   window) produces the *linear envelope* that visually resembles the
   muscle-activation output from OpenSim COMAK.

MATLAB equivalents replaced
---------------------------
``preprocess_emg.m``                    → :func:`preprocess_emg`
EMG windowing in ``plot_activation_vs_emg.m`` (lines 64-72)
                                        → :func:`extract_emg_cycle`

Bugs fixed
----------
``plot_activation_vs_emg.m`` line 71–72 builds ``emt_time`` from frame numbers
then overwrites it with ``linspace(0,100,N)`` on line 102 inside the loop.
The overwrite is numerically benign (same uniform spacing) but wastes the
frame-based mapping.  More importantly, the ``find(emt_data.Time == time_start)``
exact-float search on lines 64-65 can silently return empty if the event
timestamp does not land on a recorded sample exactly.  Python uses nearest-sample
lookup via ``numpy.searchsorted`` instead.
"""

from __future__ import annotations

import numpy as np
import pandas as pd
from scipy.ndimage import uniform_filter1d
from scipy.signal import butter, filtfilt

from COMAK.python.config import EMG_CHANNELS


def preprocess_emg(
    signal: np.ndarray,
    sampling_freq: float,
    offset_duration: float = 0.1,
    filter_order: int = 3,
    filter_cutoff: float = 20.0,
    filter_type: str = "high",
    smoothing_duration: float = 0.05,
) -> np.ndarray:
    """Apply the standard 4-step EMG preprocessing chain.

    Args:
        signal:            1-D raw EMG array (mV).
        sampling_freq:     Sampling frequency in Hz (e.g. 1000.0).
        offset_duration:   Seconds of recording used to estimate DC offset
                           (default 0.1 s, matching MATLAB default).
        filter_order:      Butterworth filter order (default 3).
        filter_cutoff:     Filter cut-off frequency in Hz (default 20 Hz).
        filter_type:       ``"high"`` or ``"low"`` (default ``"high"``).
        smoothing_duration: Moving-average window in seconds (default 0.05 s
                            = 50 ms, matching MATLAB default).

    Returns:
        Preprocessed linear-envelope signal, same length as *signal*.

    Notes:
        ``scipy.signal.filtfilt`` is the Python equivalent of MATLAB's
        ``filtfilt``: it applies the filter forward and backward to achieve
        zero-phase distortion.

        ``scipy.signal.uniform_filter1d`` replicates MATLAB's
        ``smooth(x, N, 'moving')`` centered moving average.  Edge samples use
        the nearest valid sample (``mode='nearest'``), which matches MATLAB's
        shrink-to-fit edge behaviour closely enough for EMG work.
    """
    sig = np.asarray(signal, dtype=float).ravel()

    # 1. Offset removal
    n_offset = max(1, round(offset_duration * sampling_freq))
    sig = sig - sig[:n_offset].mean()

    # 2. Zero-phase Butterworth filter
    # Nyquist-normalised cutoff: Wn = cutoff / (0.5 * fs)
    wn = filter_cutoff / (0.5 * sampling_freq)
    b, a = butter(filter_order, wn, btype=filter_type)
    sig = filtfilt(b, a, sig)

    # 3. Full-wave rectification
    sig = np.abs(sig)

    # 4. Moving-average linear envelope
    n_smooth = max(1, round(smoothing_duration * sampling_freq))
    sig = uniform_filter1d(sig, size=n_smooth, mode="nearest")

    return sig


def extract_emg_cycle(
    emg_df: pd.DataFrame,
    t_start: float,
    t_stop: float,
    sampling_freq: float,
    channels: dict[str, str] | None = None,
) -> pd.DataFrame:
    """Clip, preprocess, and return EMG channels for one gait cycle.

    Slices the full-trial EMG DataFrame to the gait cycle defined by
    *t_start*…*t_stop* (right heel-strike to right heel-strike), applies
    :func:`preprocess_emg` to every channel, and returns a DataFrame ready
    for plotting and cross-correlation.

    The ``Time`` column is preserved so that downstream code can resample
    onto the gait-cycle grid via :func:`analysis.normalization.normalize_dataframe`.

    Args:
        emg_df:       DataFrame from ``io.emt_reader.read_emg()``.  Must
                      contain a ``Time`` column (seconds) and the raw EMG
                      channel columns.
        t_start:      Gait-cycle start time in seconds (first right
                      heel-strike, ``event_df['eRHS'].iloc[0]``).
        t_stop:       Gait-cycle end time in seconds (second right
                      heel-strike, ``event_df['eRHS'].iloc[1]``).
        sampling_freq: EMG sampling frequency in Hz (read from the BTS
                       header or known from the acquisition setup).
        channels:     Mapping ``{opensim_name: bts_column_header}``.
                      Defaults to ``config.EMG_CHANNELS`` (the 4 muscles with
                      available EMG in this dataset).

    Returns:
        DataFrame with columns ``["Time", <channel_opensim_name>, ...]``.
        ``Time`` is the original wall-clock time for the slice; use
        ``normalization.normalize_dataframe()`` with ``time_col="Time"``
        and ``t_start``/``t_stop`` to map it to 0–100 %.

    Raises:
        KeyError:   If a BTS column from *channels* is missing in *emg_df*.
        ValueError: If *t_start* >= *t_stop* or no samples fall in the window.

    Notes:
        MATLAB used exact-float lookup ``find(emt_data.Time == time_start)``
        which silently fails if the event timestamp does not coincide with a
        recorded sample.  This function uses ``numpy.searchsorted`` (nearest
        sample) to guarantee a non-empty slice.
    """
    if channels is None:
        channels = EMG_CHANNELS

    if not np.isfinite(t_start) or not np.isfinite(t_stop):
        raise FileNotFoundError(
            f"Invalid gait-cycle window: t_start={t_start}, t_stop={t_stop}. "
            "Check that Event_Sequences contains two right heel-strike events."
        )
    if t_start >= t_stop:
        raise ValueError(f"t_start ({t_start}) must be less than t_stop ({t_stop})")

    time_arr = emg_df["Time"].to_numpy(dtype=float)

    # Nearest-sample lookup — robust to floating-point rounding in event times.
    i_start = int(np.searchsorted(time_arr, t_start, side="left"))
    i_stop = int(np.searchsorted(time_arr, t_stop, side="right"))

    if i_start >= i_stop:
        raise ValueError(
            f"No EMG samples found between t_start={t_start} and t_stop={t_stop}. "
            f"EMG time range: [{time_arr[0]:.4f}, {time_arr[-1]:.4f}]"
        )

    sliced = emg_df.iloc[i_start:i_stop].reset_index(drop=True)
    result = pd.DataFrame({"Time": sliced["Time"].to_numpy(dtype=float)})

    for opensim_name, bts_col in channels.items():
        raw = sliced[bts_col].to_numpy(dtype=float)
        result[opensim_name] = preprocess_emg(raw, sampling_freq)

    return result
