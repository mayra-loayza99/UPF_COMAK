"""Generate group-level (mean ± 95 % CI) figures for the COMAK pipeline.

Usage
-----
Run from the repository root (so ``COMAK`` is importable as a package)::

    python COMAK/python/run_group_plots.py <comak_root>

All output PNGs are written to ``<comak_root>/mean_results/`` with the same
subdirectory structure that ``mean_report.html.j2`` expects:

    mean_results/
      kinematics/
      validation/
      muscle_activations/
      reserve_actuators/
      joint_mechanics/

Exit codes
----------
0  All group figures generated successfully.
1  Fatal error (e.g. no patients found).
"""

from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: F401 (imported so Agg is active before plotting imports)

from COMAK.python.aggregation.group_results import GroupResults
from COMAK.python.plotting.activations import plot_group_activations
from COMAK.python.plotting.emg_validation import plot_group_emg_validation
from COMAK.python.plotting.joint_mechanics import (
    plot_group_joint_mechanics,
    plot_group_pressure_area,
)
from COMAK.python.plotting.kinematics import plot_group_kinematics
from COMAK.python.plotting.mocap_validation import plot_group_mocap_validation
from COMAK.python.plotting.style import apply_style

log = logging.getLogger(__name__)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Generate group mean ± CI COMAK figures.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "comak_root",
        help="Path to the COMAK/ root directory (contains results/, data/, …).",
    )
    parser.add_argument(
        "--emg-hz",
        type=float,
        default=1000.0,
        metavar="HZ",
        help="EMG sampling frequency in Hz.",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Print DEBUG-level messages.",
    )
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s  %(message)s",
    )

    apply_style()

    root = Path(args.comak_root)
    if not root.is_dir():
        log.error("comak_root does not exist: %s", root)
        return 1

    log.info("Loading all trials from %s/results/ …", root)
    group = GroupResults.from_results_dir(root, emg_sampling_freq=args.emg_hz)

    n = len(group.trials)
    if n == 0:
        log.error("No patient directories found under %s/results/", root)
        return 1

    log.info("  %d subjects loaded.", n)

    log.info("Kinematics …")
    plot_group_kinematics(group)

    log.info("MoCap validation …")
    plot_group_mocap_validation(group)

    log.info("Muscle activations …")
    plot_group_activations(group)

    log.info("EMG validation …")
    plot_group_emg_validation(group)

    log.info("Joint mechanics (forces / moments / CoP) …")
    plot_group_joint_mechanics(group)

    log.info("Contact pressure and area …")
    plot_group_pressure_area(group)

    log.info("Done.  Figures written to %s/mean_results/", root)
    return 0


if __name__ == "__main__":
    sys.exit(main())
