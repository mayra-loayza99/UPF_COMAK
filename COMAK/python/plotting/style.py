"""Matplotlib style constants and global defaults for the COMAK pipeline.

All font sizes, line widths, colors, and figure dimensions used across the
pipeline are defined here.  Importing and calling :func:`apply_style` once at
the top of an entry-point script sets the rcParams globally so every figure
produced in that process shares the same look.

Values are matched to the MATLAB scripts wherever the mapping is direct:
    line_width = 2              → LINE_WIDTH
    thick_line_width = 3        → LINE_WIDTH_THICK
    title_font_size = 18        → FONT_TITLE
    label_font_size = 16        → FONT_LABEL
    axes_font_size = 14         → FONT_AXES
    legend_font_size = 14       → FONT_LEGEND
    GridAlpha = 0.3             → GRID_ALPHA
    'Color', 'w'                → white figure background (matplotlib default)
"""

from __future__ import annotations

import matplotlib as mpl
import matplotlib.pyplot as plt


# ── Numeric constants ─────────────────────────────────────────────────────────

LINE_WIDTH: float = 2.0
LINE_WIDTH_THICK: float = 3.0
LINE_WIDTH_THIN: float = 1.5

FONT_TITLE: int = 18
FONT_LABEL: int = 16
FONT_AXES: int = 14
FONT_LEGEND: int = 14

GRID_ALPHA: float = 0.3

CI_FILL_ALPHA: float = 0.2   # shaded CI band transparency (matches MATLAB default)

# ── Figure dimensions (width × height in inches at 100 DPI) ──────────────────
# MATLAB pixel sizes are converted: [width_px, height_px] / 100

FIG_KINEMATICS: tuple[float, float] = (10.0, 6.0)   # [1000, 600] px
FIG_ACTIVATION: tuple[float, float] = (16.0, 8.0)   # [1600, 800] px
FIG_VALIDATION: tuple[float, float] = (14.0, 10.0)  # fullscreen equivalent
FIG_BLAND_ALTMAN: tuple[float, float] = (14.0, 5.0) # [fullwidth, half-height]
FIG_GROUP: tuple[float, float] = (10.0, 6.0)

# ── Color palette ─────────────────────────────────────────────────────────────

COLORS: dict[str, str] = {
    # Per-patient diagnostic plots
    "simulation":    "#1f77b4",   # blue  — COMAK simulation output
    "mocap":         "#ff7f0e",   # orange — MoCap reference
    "emg":           "#d62728",   # red   — EMG envelope (MATLAB used 'r-')
    "regression":    "#d62728",   # red   — linear regression line
    "reference":     "#2c2c2c",   # near-black — identity/perfect-agreement line
    # Group plots
    "group_mean":    "#1f77b4",   # blue  — group mean line
    "group_fill":    "#1f77b4",   # same — CI band (alpha applied separately)
    # Misc
    "bland_altman":  "#2c2c2c",   # scatter colour for Bland-Altman
    "loa":           "#2c2c2c",   # limits-of-agreement lines
    "grid":          "#cccccc",
}


# ── rcParams setup ────────────────────────────────────────────────────────────

def apply_style() -> None:
    """Apply COMAK pipeline matplotlib defaults globally.

    Call once at the start of each entry-point script (``run_plots.py``,
    ``run_group_plots.py``, ``run_report.py``).  Individual plotting functions
    may override specific parameters per-figure without calling this again.

    Sets:
    - White figure and axes backgrounds
    - Font sizes for titles, labels, tick labels, and legends
    - Default line width
    - Grid style matching MATLAB's GridAlpha=0.3
    - PNG output at 150 DPI (a reasonable balance between file size and quality
      for clinical reports; MATLAB's ``saveas`` uses screen resolution ~72 DPI)
    """
    mpl.rcParams.update({
        # Figure
        "figure.facecolor":         "white",
        "figure.dpi":               100,
        "savefig.dpi":              150,
        "savefig.bbox":             "tight",
        "savefig.facecolor":        "white",
        # Axes
        "axes.facecolor":           "white",
        "axes.grid":                True,
        "axes.grid.which":          "major",
        "grid.alpha":               GRID_ALPHA,
        "grid.color":               COLORS["grid"],
        "axes.spines.top":          False,
        "axes.spines.right":        False,
        "axes.labelsize":           FONT_LABEL,
        "axes.titlesize":           FONT_TITLE,
        "axes.linewidth":           0.8,
        # Ticks
        "xtick.labelsize":          FONT_AXES,
        "ytick.labelsize":          FONT_AXES,
        # Legend
        "legend.fontsize":          FONT_LEGEND,
        "legend.framealpha":        0.8,
        "legend.edgecolor":         "none",
        # Lines
        "lines.linewidth":          LINE_WIDTH,
        # Font
        "font.family":              "sans-serif",
    })


def set_gait_cycle_xaxis(ax: plt.Axes, step: int = 10) -> None:
    """Set x-axis ticks and label for a gait-cycle percentage axis.

    Args:
        ax:   Axes to configure.
        step: Tick interval in percent (default 10, giving 0 10 20 … 100).
    """
    ax.set_xlabel("Gait Cycle [%]", fontsize=FONT_LABEL)
    ax.set_xticks(range(0, 101, step))
    ax.set_xlim(0, 100)
