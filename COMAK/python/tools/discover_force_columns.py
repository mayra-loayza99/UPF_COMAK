"""CLI: print all column names in a ForceReporter .sto file, grouped by keyword.

Usage
-----
    python tools/discover_force_columns.py path/to/walking_NNN_ForceReporter_forces.sto

The tool prints every column name together with its 0-based index so you can
identify the short substrings to paste into config.FORCE_COLUMN_PATTERNS.

Output is grouped by the keywords used in FORCE_COLUMN_PATTERNS to make it
easier to locate the right column in large files (these files often have 700+
columns).

After running this tool, open config.py and replace the None values with the
shortest substring that uniquely identifies each column.  Then confirm that
io.force_columns.resolve_force_columns() resolves cleanly by running:

    python tools/discover_force_columns.py --verify path/to/...sto
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Allow running from repo root without installing the package.
sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from COMAK.python.io.sto_reader import read_sto


_INTEREST_KEYWORDS = [
    "cop", "force", "moment", "pressure", "area",
    "medial", "lateral", "contact",
]


def _group_columns(columns: list[str]) -> dict[str, list[tuple[int, str]]]:
    """Return columns grouped by whichever interest keyword they contain."""
    groups: dict[str, list[tuple[int, str]]] = {}
    ungrouped: list[tuple[int, str]] = []
    for i, col in enumerate(columns):
        cl = col.lower()
        matched = False
        for kw in _INTEREST_KEYWORDS:
            if kw in cl:
                groups.setdefault(kw, []).append((i, col))
                matched = True
                break
        if not matched:
            ungrouped.append((i, col))
    if ungrouped:
        groups["(other)"] = ungrouped
    return groups


def _print_discovery(path: Path) -> None:
    df = read_sto(path)
    columns = list(df.columns)
    print(f"\n{path.name}  —  {len(columns)} columns total\n")
    groups = _group_columns(columns)
    for keyword, entries in groups.items():
        print(f"── {keyword} ({len(entries)} columns) ──")
        for idx, name in entries:
            print(f"  [{idx:4d}]  {name}")
        print()


def _verify(path: Path) -> None:
    """Check that resolve_force_columns() succeeds on *path*."""
    from COMAK.python.io.force_columns import resolve_force_columns
    df = read_sto(path)
    try:
        mapping = resolve_force_columns(df)
        print(f"OK — all {len(mapping)} patterns resolved:")
        for logical, actual in sorted(mapping.items()):
            print(f"  {logical:<30s}  →  {actual}")
    except ValueError as exc:
        print(f"FAILED:\n{exc}", file=sys.stderr)
        sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Discover column names in a ForceReporter .sto file."
    )
    parser.add_argument(
        "path",
        type=Path,
        help="Path to *_ForceReporter_forces.sto",
    )
    parser.add_argument(
        "--verify",
        action="store_true",
        help="Instead of listing columns, verify config.FORCE_COLUMN_PATTERNS resolves cleanly.",
    )
    args = parser.parse_args()

    if not args.path.exists():
        print(f"File not found: {args.path}", file=sys.stderr)
        sys.exit(1)

    if args.verify:
        _verify(args.path)
    else:
        _print_discovery(args.path)


if __name__ == "__main__":
    main()
