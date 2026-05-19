"""Readers for BTS ASCII format (.emt) files produced by the BTS Bioengineering
motion-capture system.

Four subtypes appear in this pipeline:

  Masses          one body-mass value in kg                  (Masses_*.emt)
  EMG Tracks      raw multi-channel EMG time series          (EMG_Tracks_*.emt)
  Angle Cycles    gait-cycle-normalised joint angles         (1D_Angle_Cycles_*.emt)
  Event Sequences gait-event timestamps in seconds           (Event_Sequences_*.emt)

All subtypes share the same 'BTS ASCII format' marker and a key: value metadata
section.  The column-label row immediately precedes the numeric data and is always
separated from the metadata by at least one blank line.

MATLAB equivalents replaced by this module
------------------------------------------
  extract_bodyweight_from_emt.m  → read_body_weight()
  EMG loading in plot_activation_vs_emg.m (readtable, HeaderLines 10) → read_emg()
  Angle loading in plot_primary_coordinates_vs_mocap.m (HeaderLines 7) → read_angle_cycles()
  Event loading in plot_all_patients_activation_vs_emg.m (HeaderLines 7) → read_event_sequences()
"""

from __future__ import annotations

import re
from pathlib import Path

import pandas as pd


# ── Internal helpers ──────────────────────────────────────────────────────────

# Matches any BTS metadata line of the form "Key:   value", e.g.:
#   "Type:         \tEmg tracks"
#   "Measure unit: \tmV"
#   "Start time:   \t0.000"
# Does NOT match column-label rows ("Frame", "Sample", "mTB", etc.).
_METADATA_RE = re.compile(r"^[A-Za-z][\w ]*\s*:")


def _find_header_row(lines: list[str]) -> int:
    """Return the 0-based index of the column-label row.

    Scans forward, skipping:
      - blank lines
      - the 'BTS ASCII format' identifier line
      - key: value metadata lines

    The first line that matches none of the above is the label row.
    """
    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("BTS"):
            continue
        if _METADATA_RE.match(stripped):
            continue
        return i
    raise ValueError("No column-label row found in BTS ASCII file")


def _read_bts(path: Path) -> tuple[pd.DataFrame, dict[str, str]]:
    """Core BTS reader used by all public functions.

    Returns (data_df, metadata_dict).  The metadata dict maps lowercase
    underscore-normalised keys to their string values (e.g. 'measure_unit': 'mV').
    """
    with path.open("r", encoding="utf-8", errors="replace") as fh:
        raw_lines = fh.readlines()

    header_row = _find_header_row(raw_lines)

    # Collect metadata key → value from all lines before the label row.
    meta: dict[str, str] = {}
    for line in raw_lines[:header_row]:
        stripped = line.strip()
        if ":" in stripped and not stripped.startswith("BTS"):
            key, _, val = stripped.partition(":")
            meta[key.strip().lower().replace(" ", "_")] = val.strip()

    # Tab-split the label row so that column names containing spaces are kept
    # intact (e.g. "Right Tibialis anterior" stays as one token).
    column_names = [c.strip() for c in raw_lines[header_row].split("\t") if c.strip()]
    if not column_names:
        raise ValueError(f"Empty column-label row in {path}")

    # Skip all lines before the header row and let pandas parse header + data
    # together so that the number of column names always matches the number of
    # data columns.  Using skiprows+header=None+names was fragile: when the
    # data has one more column than the header (e.g. BTS angle-cycle files
    # where row 0 is the integer frame index), pandas silently promoted the
    # first data column to the DataFrame index and shifted all column names
    # right by one — making "acmRKFE.M" read the SD column (all zeros).
    df = pd.read_csv(
        path,
        sep="\t",
        skiprows=list(range(header_row)),   # skip everything before header
        header=0,                            # first remaining row is the header
        engine="python",
        skipinitialspace=True,
        index_col=False,                     # never auto-promote first col to index
    )
    # Strip whitespace BTS pads around column names
    df.columns = [c.strip() for c in df.columns]
    # Drop fully-NaN columns that arise from trailing tabs in the header line
    df = df.dropna(axis=1, how="all")

    return df, meta


# ── Public API ────────────────────────────────────────────────────────────────

def read_body_weight(subject_dir: Path | str) -> float:
    """Return body mass (kg) from the Masses_*.emt file in *subject_dir*.

    The BTS Masses file has a single data column named 'mTB' and exactly one
    data row.  Force normalisation throughout the pipeline uses:
        body_weight_N = body_weight_kg * 9.81

    Args:
        subject_dir: Directory containing the subject's Masses_*.emt file,
                     e.g. COMAK/data/STRATO_001/.

    Raises:
        FileNotFoundError: If no Masses_*.emt is found in *subject_dir*.
        ValueError: If multiple Masses_*.emt files are found.
    """
    subject_dir = Path(subject_dir)
    matches = sorted(subject_dir.glob("Masses_*.emt"))
    if not matches:
        raise FileNotFoundError(f"No Masses_*.emt found in {subject_dir}")
    if len(matches) > 1:
        raise ValueError(
            f"Multiple Masses_*.emt files in {subject_dir}: "
            f"{[m.name for m in matches]}"
        )
    df, _ = _read_bts(matches[0])
    return float(df.iloc[0, 0])


def read_emg(path: Path | str) -> pd.DataFrame:
    """Parse a BTS EMG Tracks .emt file into a DataFrame.

    Columns: Frame (int), Time (float, seconds), one column per EMG channel.

    Channel names preserve the original BTS casing and spacing, e.g.:
        'Right Tibialis anterior'
        'Right Vastus lateralis'
        'Right Gastrocnemius lateralis'
        'Right Biceps femoris caput longus'

    These are the keys in config.EMG_CHANNELS.

    MATLAB difference
    -----------------
    MATLAB's readtable() silently strips spaces and capitalises words, so
    'Right Tibialis anterior' became emt_data.RightTibialisAnterior.  The
    MATLAB plot scripts then accessed columns as struct fields.  In Python,
    use df['Right Tibialis anterior'] or, more robustly, use the mapping in
    config.EMG_CHANNELS[muscle_name] as the key.

    Args:
        path: Path to the EMG Tracks .emt file.
    """
    return _read_bts(Path(path))[0]


def read_angle_cycles(path: Path | str) -> pd.DataFrame:
    """Parse a BTS 1D Angle Cycles .emt file into a DataFrame.

    Columns: Sample (0-based integer index over the gait cycle), then one column
    per angle channel.  BTS column naming convention:
        acmRKFE.M  right knee flexion-extension, cycle mean  (degrees)
        acmRKFE.S  right knee flexion-extension, cycle std
    config.MOCAP_KNEE_FLEXION_COL = 'acmRKFE.M' identifies the column used for
    the simulation-vs-MoCap comparison.

    The 'Sample' index runs from 0 to N-1 where N equals the number of points
    per normalised gait cycle stored in the BTS file (typically 100 or 101).

    Args:
        path: Path to the 1D Angle Cycles .emt file.
    """
    return _read_bts(Path(path))[0]


def read_event_sequences(path: Path | str) -> pd.DataFrame:
    """Parse a BTS Event Sequences .emt file into a DataFrame.

    Columns: Item, eRHS, eRTO, eLHS, eLTO (all times in seconds).
    Missing events are NaN (the original BTS file stores them as whitespace-only
    cells between tabs).

    The gait window that aligns the EMG recording to one complete stride is:
        time_start = df['eRHS'].iloc[0]   # first  right heel-strike
        time_stop  = df['eRHS'].iloc[1]   # second right heel-strike

    MATLAB difference: MATLAB used 1-based indexing (event_data.eRHS(1) and
    event_data.eRHS(2)); Python uses .iloc[0] and .iloc[1].

    Args:
        path: Path to the Event Sequences .emt file.
    """
    return _read_bts(Path(path))[0]
