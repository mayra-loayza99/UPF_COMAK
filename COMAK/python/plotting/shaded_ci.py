"""Shaded mean ± CI band primitive for gait-cycle plots.

Replaces MATLAB's ``shadedErrorBar.m``, which used:
    fill([x; flipud(x)], [y+err; flipud(y-err)], color,
         'FaceAlpha', transparent, 'EdgeColor', 'none')

The matplotlib equivalent is ``Axes.fill_between``, which is more readable
and integrates cleanly with the legend system.

All group-level plotting functions (kinematics, activations, joint mechanics)
call :func:`shaded_mean_ci` rather than reimplementing the fill pattern.
"""

from __future__ import annotations

from typing import Any

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.collections import PolyCollection

from COMAK.python.plotting.style import (
    CI_FILL_ALPHA,
    COLORS,
    FONT_LABEL,
    LINE_WIDTH,
)


def shaded_mean_ci(
    ax: plt.Axes,
    x: np.ndarray,
    mean: np.ndarray,
    ci_half: np.ndarray,
    *,
    line_color: str = COLORS["group_mean"],
    fill_color: str | None = None,
    line_width: float = LINE_WIDTH,
    alpha: float = CI_FILL_ALPHA,
    label: str = "",
    line_style: str = "-",
    **line_kwargs: Any,
) -> tuple[Line2D, PolyCollection]:
    """Plot a mean line with a symmetric shaded confidence band.

    Equivalent to MATLAB's ``shadedErrorBar(x, y, errBar, lineProps, color,
    transparent)``.

    Args:
        ax:          Target :class:`matplotlib.axes.Axes`.
        x:           Gait-cycle percentage axis, typically
                     ``numpy.linspace(0, 100, 100)``.
        mean:        Mean signal values, shape ``(n_points,)``.
        ci_half:     Half-width of the confidence interval (±), same shape.
                     Pass ``GroupStats.ci_half`` from
                     :func:`analysis.metrics.group_ci`.
        line_color:  Hex or named colour for the mean line.  Defaults to
                     ``style.COLORS["group_mean"]`` (blue).
        fill_color:  Colour of the shaded band.  Defaults to *line_color*.
        line_width:  Mean-line width (default ``style.LINE_WIDTH``).
        alpha:       Opacity of the shaded band (default ``style.CI_FILL_ALPHA``
                     = 0.2, matching MATLAB's default transparent=0.2).
        label:       Legend label attached to the mean line.
        line_style:  Matplotlib line style string (default ``"-"``).
        **line_kwargs: Extra keyword arguments forwarded to ``ax.plot``.

    Returns:
        ``(line, poly)`` — the :class:`~matplotlib.lines.Line2D` for the mean
        and the :class:`~matplotlib.collections.PolyCollection` for the band.
        Both are returned so callers can build custom legend entries if needed.

    Example::

        gait_axis = np.linspace(0, 100, 100)
        stats = group_ci(stacked_knee_flex)
        line, band = shaded_mean_ci(
            ax, gait_axis, stats.mean, stats.ci_half,
            label="Knee Flexion (mean ± 95 % CI)",
        )
        ax.legend(handles=[line])
    """
    fc = fill_color if fill_color is not None else line_color

    # Shaded band — drawn first so the mean line renders on top
    poly = ax.fill_between(
        x,
        mean - ci_half,
        mean + ci_half,
        color=fc,
        alpha=alpha,
        linewidth=0,
    )

    # Mean line
    (line,) = ax.plot(
        x,
        mean,
        color=line_color,
        linewidth=line_width,
        linestyle=line_style,
        label=label,
        **line_kwargs,
    )

    return line, poly


def shaded_std(
    ax: plt.Axes,
    x: np.ndarray,
    mean: np.ndarray,
    std: np.ndarray,
    **kwargs: Any,
) -> tuple[Line2D, PolyCollection]:
    """Convenience wrapper: plot mean ± 1 std instead of ± CI.

    Identical signature to :func:`shaded_mean_ci`; use when you want to show
    variability rather than uncertainty of the mean.
    """
    return shaded_mean_ci(ax, x, mean, std, **kwargs)
