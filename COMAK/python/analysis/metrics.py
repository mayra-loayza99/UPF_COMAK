"""Validation and group-statistics metrics.

Centralises all numerical summaries that were previously computed inline inside
individual plotting functions across four MATLAB scripts:

  plot_primary_coordinates_vs_mocap.m  → mae(), max_error(), r_squared(),
                                         bland_altman(), ik_error_stats()
  plot_activation_vs_emg.m             → cross_correlation()
  plot_all_patients_*.m                → group_ci()

All public functions accept plain NumPy arrays so they can be called from any
plotting or aggregation context without depending on DataFrame structure.

Bugs fixed
----------
``plot_all_patients_kinematics.m`` line 91 (and the same line in the three
other all-patients scripts):

    ci_kin = structfun(@(x) 1.96*(x/sqrt(size(x,1)))', std_kin, ...)

``structfun`` passes each *field value* — a 100-element std vector — so
``size(x, 1)`` equals 100 (gait-cycle points), not the number of subjects.
The CI half-width is therefore underestimated by a factor of √(n/100).

:func:`group_ci` fixes this by accepting ``n_subjects`` explicitly.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from scipy.signal import correlate, correlation_lags
from scipy.stats import pearsonr, t as t_dist

from COMAK.python.config import CI_Z_SCORE


# ── Return-type dataclasses ───────────────────────────────────────────────────

@dataclass(frozen=True)
class BlandAltmanResult:
    """Outputs of a Bland-Altman agreement analysis."""
    differences: np.ndarray   # method_a − method_b at each sample
    averages: np.ndarray      # (method_a + method_b) / 2 at each sample
    mean_diff: float          # mean of differences (bias)
    std_diff: float           # std  of differences
    loa_upper: float          # mean_diff + 1.96 * std_diff
    loa_lower: float          # mean_diff − 1.96 * std_diff


@dataclass(frozen=True)
class IKErrorStats:
    """Per-subject IK marker-error summary with t-distribution 95 % CI."""
    mean_rms: float           # mean RMS marker error across frames (m)
    std_rms: float
    mean_max: float           # mean maximum marker error across frames (m)
    std_max: float
    ci_rms: float             # 95 % CI half-width for mean_rms
    ci_max: float             # 95 % CI half-width for mean_max
    n_frames: int


@dataclass(frozen=True)
class CrossCorrelationResult:
    """Outputs of a normalised cross-correlation between two signals."""
    coefficients: np.ndarray  # full normalised correlation array (values ∈ [−1, 1])
    lags: np.ndarray          # corresponding integer lag values (samples)
    max_corr: float           # peak correlation value
    lag_at_max: int           # lag (samples) at which correlation is maximum
    zero_lag_corr: float      # correlation at lag = 0


@dataclass(frozen=True)
class GroupStats:
    """Mean ± CI summary for one signal across n_subjects."""
    mean: np.ndarray          # shape (n_points,)
    std: np.ndarray           # shape (n_points,)
    ci_half: np.ndarray       # shape (n_points,) — half-width of 95 % CI
    n_subjects: int


# ── Point-wise validation metrics ────────────────────────────────────────────

def mae(a: np.ndarray, b: np.ndarray) -> float:
    """Mean absolute error between two equal-length signal arrays.

    Args:
        a: Reference signal (e.g. MoCap knee flexion).
        b: Estimated signal (e.g. simulation knee flexion).

    Returns:
        Scalar MAE in whatever units *a* and *b* are expressed.
    """
    return float(np.mean(np.abs(np.asarray(a) - np.asarray(b))))


def max_error(a: np.ndarray, b: np.ndarray) -> float:
    """Peak absolute error between two equal-length signal arrays."""
    return float(np.max(np.abs(np.asarray(a) - np.asarray(b))))


def r_squared(a: np.ndarray, b: np.ndarray) -> float:
    """Pearson R² between two equal-length signal arrays.

    Computes the square of the Pearson product-moment correlation coefficient,
    equivalent to MATLAB's ``corr(a, b)^2``.

    Note: this is *not* the coefficient of determination from a regression
    (which measures variance explained by a fitted model).  It is the
    squared linear correlation, which equals 1 only when the two signals are
    perfectly linearly related.

    Args:
        a: First signal array.
        b: Second signal array.

    Returns:
        R² in [0, 1].
    """
    r, _ = pearsonr(np.asarray(a, dtype=float), np.asarray(b, dtype=float))
    return float(r ** 2)


def linear_regression(
    x: np.ndarray, y: np.ndarray
) -> tuple[float, float]:
    """Fit y = slope*x + intercept via least squares.

    Equivalent to MATLAB's ``p = polyfit(x, y, 1)``.

    Returns:
        ``(slope, intercept)`` as floats.
    """
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)
    if np.ptp(x) == 0 or np.ptp(y) == 0 or not np.isfinite(x).all() or not np.isfinite(y).all():
        return float("nan"), float("nan")
    slope, intercept = np.polyfit(x, y, 1)
    return float(slope), float(intercept)


# ── Bland-Altman agreement ────────────────────────────────────────────────────

def bland_altman(
    method_a: np.ndarray,
    method_b: np.ndarray,
) -> BlandAltmanResult:
    """Compute Bland-Altman limits of agreement.

    Defined as:
        differences = method_a − method_b
        averages    = (method_a + method_b) / 2
        LoA         = mean_diff ± 1.96 × std_diff

    The ±1.96 σ limits contain ~95 % of differences if they are normally
    distributed (Bland & Altman, 1986, Lancet).

    By convention ``method_a`` is the new/simulation method and ``method_b``
    is the reference/MoCap method, so a positive mean_diff means the
    simulation reads higher on average.

    Args:
        method_a: New-method values (e.g. simulation).
        method_b: Reference values (e.g. MoCap).

    Returns:
        :class:`BlandAltmanResult` with all derived quantities.
    """
    a = np.asarray(method_a, dtype=float)
    b = np.asarray(method_b, dtype=float)
    diffs = a - b
    avgs = (a + b) / 2.0
    mean_d = float(np.mean(diffs))
    std_d = float(np.std(diffs, ddof=1))
    return BlandAltmanResult(
        differences=diffs,
        averages=avgs,
        mean_diff=mean_d,
        std_diff=std_d,
        loa_upper=mean_d + 1.96 * std_d,
        loa_lower=mean_d - 1.96 * std_d,
    )


# ── IK marker error stats ─────────────────────────────────────────────────────

def ik_error_stats(error_df) -> IKErrorStats:
    """Summarise IK marker error with t-distribution 95 % CI.

    Reads columns 2 (0-based) and 3 from the IK error DataFrame returned by
    ``io.sto_reader.read_sto()`` for a ``*_ik_marker_errors.sto`` file.
    Column layout from OpenSim:
        0: time
        1: (unused here)
        2: RMS marker error (m)
        3: maximum marker error (m)

    Uses a t-distribution CI (not the z-approximation), matching the MATLAB
    formula ``tinv(0.975, n-1) * std / sqrt(n)``.  This is correct for
    per-frame statistics where n = number of frames.

    Args:
        error_df: DataFrame from ``read_sto()`` for the IK error file.

    Returns:
        :class:`IKErrorStats` with values in metres (unit used by OpenSim).
        Multiply by 100 when displaying in centimetres, as MATLAB does.
    """
    rms_col = error_df.iloc[:, 2].to_numpy(dtype=float)
    max_col = error_df.iloc[:, 3].to_numpy(dtype=float)
    n = len(rms_col)
    df_t = n - 1
    t_val = float(t_dist.ppf(0.975, df=df_t))
    return IKErrorStats(
        mean_rms=float(np.mean(rms_col)),
        std_rms=float(np.std(rms_col, ddof=1)),
        mean_max=float(np.mean(max_col)),
        std_max=float(np.std(max_col, ddof=1)),
        ci_rms=t_val * float(np.std(rms_col, ddof=1)) / np.sqrt(n),
        ci_max=t_val * float(np.std(max_col, ddof=1)) / np.sqrt(n),
        n_frames=n,
    )


# ── Cross-correlation ─────────────────────────────────────────────────────────

def cross_correlation(
    signal_a: np.ndarray,
    signal_b: np.ndarray,
) -> CrossCorrelationResult:
    """Normalised cross-correlation between two equal-length signals.

    Equivalent to MATLAB's ``xcorr(a, b, 'coeff')``, which normalises by
    ``sqrt(sum(a²) * sum(b²))`` so that the result lies in [−1, 1].

    Used to compare simulated muscle activation timing with the EMG linear
    envelope.  The lag at maximum correlation indicates whether the simulation
    leads or lags the measured EMG.

    Args:
        signal_a: First signal (e.g. simulated activation, resampled to 101
                  gait-cycle points as in the original MATLAB script).
        signal_b: Second signal (e.g. preprocessed EMG), same length.

    Returns:
        :class:`CrossCorrelationResult`.
    """
    a = np.asarray(signal_a, dtype=float)
    b = np.asarray(signal_b, dtype=float)

    raw = correlate(a, b, mode="full")
    norm = np.sqrt(np.sum(a ** 2) * np.sum(b ** 2))
    if norm == 0.0:
        coeffs = np.zeros_like(raw)
    else:
        coeffs = raw / norm

    lags = correlation_lags(len(a), len(b), mode="full")
    max_idx = int(np.argmax(coeffs))
    zero_idx = int(np.searchsorted(lags, 0))

    return CrossCorrelationResult(
        coefficients=coeffs,
        lags=lags,
        max_corr=float(coeffs[max_idx]),
        lag_at_max=int(lags[max_idx]),
        zero_lag_corr=float(coeffs[zero_idx]),
    )


# ── Group statistics ──────────────────────────────────────────────────────────

def group_ci(
    stacked: np.ndarray,
    use_t_dist: bool = False,
) -> GroupStats:
    """Compute mean, std, and 95 % CI half-width across subjects.

    ``stacked`` must be shaped ``(n_subjects, n_points)`` — one row per
    subject, one column per gait-cycle point.  This is the layout produced by
    :class:`aggregation.GroupResults`.

    The MATLAB ``*_all_patients_*`` scripts had a critical bug here::

        ci_kin = structfun(@(x) 1.96*(x/sqrt(size(x,1)))', std_kin, ...)

    ``structfun`` passes each field value (a 100-element std vector) as ``x``,
    so ``size(x, 1)`` is 100, not n_subjects.  This underestimates the CI by
    √(n_subjects / 100).  This function uses the actual subject count.

    Args:
        stacked:    2-D array, shape ``(n_subjects, n_points)``.
        use_t_dist: If ``True``, use the t-distribution critical value
                    (recommended for n_subjects < 30).  If ``False`` (default),
                    use ``config.CI_Z_SCORE`` (1.96), matching the original
                    MATLAB intent for large samples.

    Returns:
        :class:`GroupStats` with arrays of shape ``(n_points,)``.
    """
    arr = np.asarray(stacked, dtype=float)
    if arr.ndim != 2:
        raise ValueError(
            f"stacked must be 2-D (n_subjects × n_points); got shape {arr.shape}"
        )
    n = arr.shape[0]
    mean_arr = arr.mean(axis=0)
    std_arr = arr.std(axis=0, ddof=1)

    if use_t_dist:
        z = float(t_dist.ppf(0.975, df=n - 1))
    else:
        z = CI_Z_SCORE

    ci_half = z * std_arr / np.sqrt(n)

    return GroupStats(
        mean=mean_arr,
        std=std_arr,
        ci_half=ci_half,
        n_subjects=n,
    )
