"""Column-name resolver for OpenSim JointMechanicsTool ForceReporter output.

MATLAB's plot_joint_mechanics_extended.m accessed force data with hardcoded
1-based column indices (e.g. ``forces_data(:, 588+i)``).  Those indices are
fragile: they break whenever the model's contact-element list changes or the
ForceReporter is configured differently.

This module replaces that approach with substring pattern matching: each logical
quantity (``"force_total_x"``, ``"cop_medial_z"``, etc.) maps to a short string
that uniquely identifies its column header in the real file.  The mapping lives
in ``config.FORCE_COLUMN_PATTERNS`` so it can be updated without touching any
plotting code.

Typical workflow
----------------
1. Run one simulation to obtain a ``*_ForceReporter_forces.sto`` file.
2. Run ``tools/discover_force_columns.py`` against that file; it prints every
   column name grouped by keyword.
3. Paste the patterns into ``config.FORCE_COLUMN_PATTERNS`` (replace ``None``).
4. Call ``resolve_force_columns(df)`` once per trial; pass the returned dict to
   all plotting functions.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    import pandas as pd

from COMAK.python.config import FORCE_COLUMN_PATTERNS


def resolve_force_columns(df: "pd.DataFrame") -> dict[str, str]:
    """Map logical force-quantity names to actual column names in *df*.

    For each key in ``config.FORCE_COLUMN_PATTERNS``, searches ``df.columns``
    for a column whose name contains the corresponding pattern as a
    case-insensitive substring.  Raises ``ValueError`` if any pattern is
    ``None`` (not yet configured) or matches zero or multiple columns.

    Args:
        df: DataFrame returned by ``io.sto_reader.read_sto()`` for a
            ``*_ForceReporter_forces.sto`` file.

    Returns:
        Dict mapping each logical name (``"force_total_x"``, etc.) to the
        exact matching column name in *df*.

    Raises:
        ValueError: If any patterns are ``None``, or if a pattern matches
            no columns, or if a pattern matches more than one column.

    Example::

        df = read_sto("walking_001_ForceReporter_forces.sto")
        col = resolve_force_columns(df)
        total_force_y = df[col["force_total_y"]]
    """
    columns: list[str] = list(df.columns)
    resolved: dict[str, str] = {}
    errors: list[str] = []

    unset = [k for k, v in FORCE_COLUMN_PATTERNS.items() if v is None]
    if unset:
        errors.append(
            f"Patterns not yet configured in config.FORCE_COLUMN_PATTERNS "
            f"({len(unset)} keys):\n  " + "\n  ".join(unset)
        )

    for key, pattern in FORCE_COLUMN_PATTERNS.items():
        if pattern is None:
            continue
        matches = [c for c in columns if pattern.lower() in c.lower()]
        if len(matches) == 0:
            errors.append(
                f"  '{key}': pattern '{pattern}' matched no column.\n"
                f"    Available columns (first 10): {columns[:10]}"
            )
        elif len(matches) > 1:
            errors.append(
                f"  '{key}': pattern '{pattern}' is ambiguous — "
                f"matched {len(matches)} columns: {matches}"
            )
        else:
            resolved[key] = matches[0]

    if errors:
        raise ValueError(
            "resolve_force_columns() failed.\n\n"
            "Run tools/discover_force_columns.py against a ForceReporter "
            ".sto file to find the correct patterns, then update "
            "config.FORCE_COLUMN_PATTERNS.\n\n"
            + "\n".join(errors)
        )

    return resolved
