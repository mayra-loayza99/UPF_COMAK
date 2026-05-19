"""Parser for OpenSim .sto and .mot storage files.

The OpenSim storage format is a plain-text file with:
  1. A free-form title line.
  2. A key=value header block terminated by the literal line 'endheader'.
  3. A single whitespace-delimited row of column names.
  4. Whitespace-delimited floating-point data rows.

No OpenSim Python API is needed to read these files.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd


def read_sto(path: Path | str) -> pd.DataFrame:
    """Parse an OpenSim .sto or .mot file into a DataFrame.

    Column names are taken verbatim from the label row that immediately follows
    'endheader'.  The 'time' column is always present and first.  Header metadata
    (version, nrows, ncols, indegrees) is stored in ``df.attrs`` for optional
    downstream validation; no callers in the original pipeline used it.

    Args:
        path: Path to the .sto or .mot file.

    Returns:
        DataFrame whose columns match the OpenSim storage label row.

    Raises:
        FileNotFoundError: If *path* does not exist.
        ValueError: If 'endheader' is not found, or the label row is empty.

    Notes:
        MATLAB equivalent: read_opensim_mot.m (Colin Smith / Aurel Berger).
        The original used the deprecated ``findstr`` function and a manual
        character scan to parse column labels; this version uses str.split().
        The MATLAB function had a dual-return API (1 output → struct, 2+ outputs
        → matrix + labels); Python returns a single DataFrame that subsumes both.
    """
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"OpenSim storage file not found: {path}")

    with path.open("r", encoding="utf-8", errors="replace") as fh:
        raw_lines = fh.readlines()

    attrs: dict[str, object] = {}
    endheader_idx: int = -1

    # First line is the file title (free-form string, not a key=value pair).
    if raw_lines:
        attrs["title"] = raw_lines[0].strip()

    # Scan header lines for key=value metadata until 'endheader'.
    for idx, line in enumerate(raw_lines[1:], start=1):
        stripped = line.strip()
        if stripped.lower() == "endheader":
            endheader_idx = idx
            break
        if "=" in stripped:
            key, _, val = stripped.partition("=")
            key = key.strip().lower()
            val = val.strip()
            if key in ("nrows", "datarows"):
                attrs["nrows"] = int(val)
            elif key in ("ncolumns", "datacolumns"):
                attrs["ncols"] = int(val)
            elif key == "version":
                attrs["version"] = int(val)
            elif key == "indegrees":
                # True means angle columns are in degrees (the usual case for kinematics).
                attrs["indegrees"] = val.lower() == "yes"

    if endheader_idx < 0:
        raise ValueError(f"'endheader' marker not found in {path}")

    label_idx = endheader_idx + 1
    if label_idx >= len(raw_lines):
        raise ValueError(f"No column-label row after 'endheader' in {path}")

    column_names = raw_lines[label_idx].split()
    if not column_names:
        raise ValueError(f"Empty column-label row in {path}")

    data_start = label_idx + 1  # index of first numeric data line

    df = pd.read_csv(
        path,
        sep=r"\s+",
        skiprows=data_start,
        header=None,
        names=column_names,
        engine="python",
        dtype=float,
    )

    df.attrs.update(attrs)
    return df
