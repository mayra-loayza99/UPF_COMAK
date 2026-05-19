"""Fix model_two_legs.osim coordinate defaults and clamped flags.

The model was saved in a walking-gait pose, so all default_value fields
captured simulation residuals instead of neutral reference values.
The left-leg structural additions (femur_distal_l, tibia_proximal_l,
left ligaments, left contact) are correctly mirrored — only defaults and
clamped flags need resetting.

Usage
-----
    python COMAK/python/tools/fix_two_legs_model.py

Writes:  COMAK/python/model_two_legs_fixed.osim
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# ── Paths ─────────────────────────────────────────────────────────────────────

ROOT = Path(__file__).parent.parent
REF_PATH   = ROOT / "lenhart2015.osim"
INPUT_PATH = ROOT / "model_two_legs.osim"
OUT_PATH   = ROOT / "model_two_legs_fixed.osim"


# ── Parse coordinate settings from a file ────────────────────────────────────

_COORD_BLOCK_RE = re.compile(
    r'<Coordinate name="([^"]+)">(.*?)</Coordinate>',
    re.DOTALL,
)
_TAG_RE = re.compile(r'<(\w+)>(.*?)</\1>', re.DOTALL)


def _parse_coords(text: str) -> dict[str, dict[str, str]]:
    """Return {coord_name: {tag: value}} for every Coordinate in *text*."""
    out: dict[str, dict[str, str]] = {}
    for m in _COORD_BLOCK_RE.finditer(text):
        name = m.group(1)
        body = m.group(2)
        fields: dict[str, str] = {}
        for tm in _TAG_RE.finditer(body):
            fields[tm.group(1)] = tm.group(2).strip()
        out[name] = fields
    return out


# ── Mapping: two-legs coord → reference coord ────────────────────────────────

def _ref_name(coord: str, ref_coords: dict) -> str | None:
    """Find the lenhart2015 coordinate that is the reference for *coord*."""
    if coord in ref_coords:
        return coord
    # Left-side coordinates: try replacing _l suffix with _r
    if coord.endswith("_l"):
        r = coord[:-2] + "_r"
        if r in ref_coords:
            return r
    return None


def _negate_z_for_left(coord: str, tag: str, value: str) -> str:
    """
    For left-side patellofemoral translation coordinates (pf_tz_l) the
    Z-component of the default position must be negated relative to the
    right side to preserve anatomical symmetry.
    """
    if tag == "default_value" and coord in ("pf_tz_l",):
        try:
            return str(-float(value))
        except ValueError:
            pass
    return value


# ── Replace a single tag inside a Coordinate block ───────────────────────────

def _replace_in_block(block: str, tag: str, new_val: str) -> str:
    """Replace <tag>…</tag> inside *block* with *new_val*."""
    return re.sub(
        rf"(<{tag}>)([^<]*)(</{tag}>)",
        lambda m: f"{m.group(1)}{new_val}{m.group(3)}",
        block,
        count=1,
    )


# ── Main fix ──────────────────────────────────────────────────────────────────

def fix_model(ref_text: str, two_text: str) -> tuple[str, list[str]]:
    """Return (fixed_xml, list_of_changes)."""

    ref_coords = _parse_coords(ref_text)
    changes: list[str] = []

    def _fix_coord_block(m: re.Match) -> str:
        name = m.group(1)
        block = m.group(0)

        ref_key = _ref_name(name, ref_coords)
        if ref_key is None:
            return block  # no reference found, leave unchanged

        ref = ref_coords[ref_key]

        for tag in ("default_value", "clamped"):
            if tag not in ref:
                continue
            new_val = _negate_z_for_left(name, tag, ref[tag])

            # Find current value in the block
            cur_m = re.search(rf"<{tag}>([^<]*)</{tag}>", block)
            cur_val = cur_m.group(1).strip() if cur_m else None

            if cur_val != new_val:
                block = _replace_in_block(block, tag, new_val)
                changes.append(
                    f"  {name}.{tag}: {cur_val!r} -> {new_val!r}"
                )

        return block

    fixed = _COORD_BLOCK_RE.sub(_fix_coord_block, two_text)
    return fixed, changes


# ── Entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    print(f"Reference : {REF_PATH}")
    print(f"Input     : {INPUT_PATH}")
    print(f"Output    : {OUT_PATH}")

    ref_text = REF_PATH.read_text(encoding="utf-8", errors="replace")
    two_text = INPUT_PATH.read_text(encoding="utf-8", errors="replace")

    fixed, changes = fix_model(ref_text, two_text)

    if not changes:
        print("\nNo changes needed — model already matches reference.")
        return

    print(f"\n{len(changes)} fields updated:")
    for c in changes:
        print(c)

    OUT_PATH.write_text(fixed, encoding="utf-8")
    print(f"\nFixed model written to: {OUT_PATH}")
    print(
        "\nNext steps:"
        "\n  1. Open model_two_legs_fixed.osim in OpenSim GUI"
        "\n  2. Check that the model loads without errors"
        "\n  3. Verify the neutral pose looks anatomically correct"
        "\n  4. Run a test COMAK simulation on a subject"
    )


if __name__ == "__main__":
    main()
