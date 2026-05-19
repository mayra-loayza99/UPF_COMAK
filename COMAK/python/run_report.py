"""Assemble HTML reports for the COMAK post-processing pipeline.

Usage
-----
Run from the repository root (so ``COMAK`` is importable as a package)::

    python COMAK/python/run_report.py <comak_root>

Three HTML files are written to ``<comak_root>/reports/``:

    COMAK_Simulation_Results.html  — static COMAK introduction page
    {patient_id}_results.html      — one per subject
    mean_results.html              — group-level results

The report pages reference images with relative paths, so the ``reports/``
directory can be moved together with ``results/`` and ``mean_results/``
without editing any HTML.

Run this script **after** both ``run_plots.py`` and ``run_group_plots.py``
have finished so that all referenced images exist.

Exit codes
----------
0  All reports written successfully.
1  Fatal error.
"""

from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from COMAK.python.report.assembler import assemble_reports

log = logging.getLogger(__name__)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Assemble COMAK HTML reports.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "comak_root",
        help="Path to the COMAK/ root directory (contains results/, data/, …).",
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

    root = Path(args.comak_root)
    if not root.is_dir():
        log.error("comak_root does not exist: %s", root)
        return 1

    log.info("Assembling reports for %s …", root)
    written = assemble_reports(root)

    log.info("\nReports written:")
    for p in written:
        log.info("  %s", p)

    return 0


if __name__ == "__main__":
    sys.exit(main())
