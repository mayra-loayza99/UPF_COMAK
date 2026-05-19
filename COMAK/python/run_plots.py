"""Generate all per-patient figures for the COMAK post-processing pipeline.

Usage
-----
Run from the repository root (so ``COMAK`` is importable as a package)::

    python COMAK/python/run_plots.py <comak_root> [--subject STRATO_001]

``comak_root`` is the ``COMAK/`` directory that contains ``results/``,
``data/``, etc.  When ``--subject`` is omitted every patient found in
``results/`` is processed.

Exit codes
----------
0  All figures generated successfully.
1  One or more patients failed; errors were logged to stderr.
"""

from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

# Allow running as a plain script: add repo root to sys.path so that
# "COMAK.python.*" imports resolve regardless of working directory.
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

import matplotlib
matplotlib.use("Agg")   # non-interactive backend — no display required, no GUI memory leak
import matplotlib.pyplot as plt

from COMAK.python.aggregation.group_results import discover_trials
from COMAK.python.models.trial_data import TrialData
from COMAK.python.plotting.activations import plot_trial_activations
from COMAK.python.plotting.emg_validation import plot_trial_emg_validation
from COMAK.python.plotting.joint_mechanics import plot_trial_joint_mechanics
from COMAK.python.plotting.kinematics import plot_trial_kinematics
from COMAK.python.plotting.mocap_validation import plot_trial_mocap_validation
from COMAK.python.plotting.style import apply_style

log = logging.getLogger(__name__)


def _run_step(label: str, fn, trial: TrialData) -> bool:
    """Run one plotting step.  Returns False only on an unexpected error."""
    try:
        fn(trial)
        log.info("  [%s] %s done", trial.subject_id, label)
        return True
    except FileNotFoundError as exc:
        log.warning("  [%s] %s skipped — file not found: %s", trial.subject_id, label, exc)
        return True   # missing data is expected for some subjects, not a failure
    except Exception:
        log.exception("  [%s] %s FAILED", trial.subject_id, label)
        return False


def _process_one(trial: TrialData) -> bool:
    """Run all plotting steps for a single trial.  Returns True if all steps succeeded."""
    ok = True
    ok &= _run_step("kinematics",       plot_trial_kinematics,       trial)
    ok &= _run_step("MoCap validation", plot_trial_mocap_validation, trial)
    ok &= _run_step("activations",      plot_trial_activations,      trial)
    ok &= _run_step("EMG validation",   plot_trial_emg_validation,   trial)
    ok &= _run_step("joint mechanics",  plot_trial_joint_mechanics,  trial)
    return ok


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Generate all per-patient COMAK figures.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "comak_root",
        help="Path to the COMAK/ root directory (contains results/, data/, …).",
    )
    parser.add_argument(
        "--subject",
        metavar="SUBJECT_ID",
        default=None,
        help="Process only this subject (directory name under results/).  "
             "Omit to process all subjects.",
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

    trials = discover_trials(root, emg_sampling_freq=args.emg_hz)
    if not trials:
        log.error("No patient directories found under %s/results/", root)
        return 1

    if args.subject:
        trials = [t for t in trials if t.subject_id == args.subject]
        if not trials:
            log.error("Subject '%s' not found in %s/results/", args.subject, root)
            return 1

    n_total  = len(trials)
    n_ok     = 0
    n_failed = 0

    for i, trial in enumerate(trials, 1):
        log.info("Processing %s  (%d / %d)", trial.subject_id, i, n_total)
        if _process_one(trial):
            n_ok += 1
        else:
            n_failed += 1
        plt.close("all")  # free all figures before next patient

    log.info("Done.  %d / %d subjects processed successfully.", n_ok, n_total)

    return 0 if n_failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
