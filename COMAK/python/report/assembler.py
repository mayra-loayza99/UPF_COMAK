"""HTML report assembly using Jinja2 templates.

Replaces
--------
  create_report.m          → :func:`assemble_reports`
  generatePatientReport.m  → :func:`build_patient_report`
  generateMeanReport.m     → :func:`build_mean_report`

Three output files are written to ``comak_root/reports/``:

  COMAK_Simulation_Results.html  — main COMAK explanation page
  {patient_id}_results.html      — one per subject (kinematics, validation,
                                   activations, EMG, joint mechanics)
  mean_results.html              — group-level results

MATLAB bug fixed
----------------
``create_report.m`` called ``generatePatientReport`` twice per patient:
once inside a loop that was still building ``patientLinks``, and once in a
second loop after all links were ready.  This caused each report to be
written twice and the first write to have an incomplete navigation dropdown.
Python builds the full links list first, then generates all reports exactly
once each.

Template design
---------------
Jinja2 ``{% extends %}`` / ``{% block %}`` inheritance keeps the shared CSS,
JavaScript, and navigation bar in ``base.html.j2`` so changes propagate to
all three report types automatically.  Image ``src`` attributes use relative
paths so the ``reports/`` folder can be moved without editing the HTML.
"""

from __future__ import annotations

from datetime import datetime
from pathlib import Path

from jinja2 import Environment, FileSystemLoader, select_autoescape

from COMAK.python.config import (
    EXCLUDED_RESULT_DIRS,
    MEAN_RESULTS_DIR,
    MUSCLE_DISPLAY_NAMES,
    MUSCLES,
    RESERVE_ACTUATORS,
)


# ── Jinja2 environment ────────────────────────────────────────────────────────

def _make_env() -> Environment:
    templates_dir = Path(__file__).parent / "templates"
    return Environment(
        loader=FileSystemLoader(str(templates_dir)),
        autoescape=select_autoescape(["html", "j2"]),
    )


# ── Shared context helpers ────────────────────────────────────────────────────

_DIRECTIONS = ("Anterior-Posterior", "Superior-Inferior", "Medial-Lateral")

def _muscle_list() -> list[dict]:
    return [
        {"id": m, "display_name": MUSCLE_DISPLAY_NAMES.get(m, m)}
        for m in MUSCLES
    ]

def _reserve_list() -> list[dict]:
    return [
        {"id": r, "display_name": MUSCLE_DISPLAY_NAMES.get(r, r)}
        for r in RESERVE_ACTUATORS
    ]

def _now_str() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def _patient_links(patient_ids: list[str]) -> list[dict]:
    """Build navigation dropdown entries for all subjects."""
    return [
        {"href": f"{pid}_results.html", "label": pid}
        for pid in patient_ids
    ]


def _discover_patient_ids(comak_root: Path) -> list[str]:
    """List subject directory names from results/, sorted."""
    results_dir = comak_root / "results"
    if not results_dir.exists():
        return []
    return sorted(
        d.name for d in results_dir.iterdir()
        if d.is_dir() and d.name not in EXCLUDED_RESULT_DIRS and not d.name.startswith(".")
    )


# ── Individual patient report ─────────────────────────────────────────────────

def build_patient_report(
    patient_id: str,
    comak_root: Path,
    reports_dir: Path,
    patient_links: list[dict],
    env: Environment | None = None,
) -> Path:
    """Render and write one patient HTML report.

    Image paths are relative to ``reports/``, pointing into
    ``../results/{patient_id}/graphics/``.

    Args:
        patient_id:    Directory name, e.g. ``"STRATO_001"``.
        comak_root:    ``COMAK/`` root directory.
        reports_dir:   Output directory (``comak_root/reports/``).
        patient_links: Full navigation dropdown list (all patients).
        env:           Optional pre-built Jinja2 environment.

    Returns:
        Path to the written HTML file.
    """
    if env is None:
        env = _make_env()

    tmpl = env.get_template("patient_report.html.j2")

    # Relative image prefix from reports/ to this patient's graphics/
    results_prefix = f"../results/{patient_id}/graphics/"

    context = {
        "patient_id":    patient_id,
        "generated_at":  _now_str(),
        "patient_links": patient_links,
        "results_prefix": results_prefix,
        "muscles":       _muscle_list(),
        "reserves":      _reserve_list(),
        "directions":    _DIRECTIONS,
    }

    out_path = reports_dir / f"{patient_id}_results.html"
    out_path.write_text(tmpl.render(**context), encoding="utf-8")
    return out_path


# ── Group / mean report ───────────────────────────────────────────────────────

def build_mean_report(
    comak_root: Path,
    reports_dir: Path,
    patient_links: list[dict],
    n_subjects: int,
    env: Environment | None = None,
) -> Path:
    """Render and write the group-level mean results HTML report.

    Args:
        comak_root:    ``COMAK/`` root directory.
        reports_dir:   Output directory (``comak_root/reports/``).
        patient_links: Full navigation dropdown list.
        n_subjects:    Number of successfully processed subjects.
        env:           Optional pre-built Jinja2 environment.

    Returns:
        Path to the written HTML file.
    """
    if env is None:
        env = _make_env()

    tmpl = env.get_template("mean_report.html.j2")

    mean_prefix = f"../{MEAN_RESULTS_DIR}/"

    context = {
        "generated_at":  _now_str(),
        "patient_links": patient_links,
        "n_subjects":    n_subjects,
        "mean_prefix":   mean_prefix,
        "muscles":       _muscle_list(),
        "reserves":      _reserve_list(),
        "directions":    _DIRECTIONS,
    }

    out_path = reports_dir / "mean_results.html"
    out_path.write_text(tmpl.render(**context), encoding="utf-8")
    return out_path


# ── Main entry point ──────────────────────────────────────────────────────────

def assemble_reports(comak_root: Path | str) -> list[Path]:
    """Build all HTML reports for the COMAK pipeline.

    Discovers patient directories automatically, generates one report per
    patient, one group-level report, and the main COMAK explanation page.
    All reports share a navigation dropdown that lists every patient.

    The complete navigation dropdown is built **before** any report is
    written, fixing the MATLAB double-generation bug where the first loop
    wrote reports with an incomplete dropdown.

    Args:
        comak_root: ``COMAK/`` root directory (absolute or relative).

    Returns:
        List of :class:`~pathlib.Path` objects for all written HTML files.
    """
    root = Path(comak_root)
    reports_dir = root / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)

    env = _make_env()

    # Build full link list once before writing any file
    patient_ids = _discover_patient_ids(root)
    links = _patient_links(patient_ids)

    written: list[Path] = []

    # One report per patient
    for pid in patient_ids:
        path = build_patient_report(pid, root, reports_dir, links, env)
        written.append(path)
        print(f"  Patient report: {path.name}")

    # Group-level report
    mean_path = build_mean_report(root, reports_dir, links, len(patient_ids), env)
    written.append(mean_path)
    print(f"  Mean report:    {mean_path.name}")

    # Main COMAK explanation page (static — no dynamic data needed)
    main_path = _write_main_report(root, reports_dir, links, env)
    written.append(main_path)
    print(f"  Main report:    {main_path.name}")

    return written


# ── Main report (static COMAK explanation) ────────────────────────────────────

_MAIN_REPORT_BODY = """\
<section id="introduction">
<h2>Introduction to COMAK</h2>
<p>Concurrent Optimization of Muscle Activations and Kinematics (COMAK) is a computational
approach in the OpenSim-JAM toolkit that simultaneously optimises muscle activations and
secondary joint kinematics during dynamic movements such as walking.  It is particularly
suited to studying knee osteoarthritis (KOA) mechanics.</p>
<div style="text-align:center;margin-top:16px">
  <img class="img-full" src="../data/images_for_visualizations/COMAK_workflow.png"
       alt="COMAK Workflow" style="max-width:700px">
  <caption>COMAK workflow (adapted from Colin Smith / opensim-jam).</caption>
</div>
</section>

<section id="workflow">
<h2>Simulation Workflow</h2>
<ol>
  <li><b>Subject-specific knee model</b> — constructed from imaging data.</li>
  <li><b>Gait data collection</b> — marker trajectories and ground reaction forces.</li>
  <li><b>COMAKInverseKinematics</b> — computes primary joint angles.</li>
  <li><b>COMAK</b> — concurrently optimises muscle activations and secondary kinematics.</li>
  <li><b>JointMechanicsTool</b> — post-processes contact forces, pressures, and CoP.</li>
  <li><b>Python post-processing</b> — this report.</li>
</ol>
</section>

<section id="validation">
<h2>Validation Strategy</h2>
<ul>
  <li>Kinematics validated against MoCap knee-flexion angles (MAE, R², Bland-Altman).</li>
  <li>Muscle activations validated against surface EMG (cross-correlation).</li>
  <li>IK marker tracking error reported with 95 % CI.</li>
</ul>
</section>
"""


def _write_main_report(
    comak_root: Path,
    reports_dir: Path,
    patient_links: list[dict],
    env: Environment,
) -> Path:
    """Write the static COMAK-explanation main report directly (no separate template)."""
    tmpl_str = """\
{% extends "base.html.j2" %}
{% block title %}What is COMAK?{% endblock %}
{% block nav %}
  <a href="mean_results.html" class="highlight">Group Results</a>
  <a href="#introduction">Introduction</a>
  <a href="#workflow">Workflow</a>
  <a href="#validation">Validation</a>
{% endblock %}
{% block header %}
<div class="page-header">
  <h1>What is COMAK?</h1>
  <p>Concurrent Optimization of Muscle Activations and Kinematics</p>
</div>
{% endblock %}
{% block content %}
""" + _MAIN_REPORT_BODY + "\n{% endblock %}\n"

    tmpl = env.from_string(tmpl_str)
    html = tmpl.render(patient_links=patient_links)
    out_path = reports_dir / "COMAK_Simulation_Results.html"
    out_path.write_text(html, encoding="utf-8")
    return out_path
