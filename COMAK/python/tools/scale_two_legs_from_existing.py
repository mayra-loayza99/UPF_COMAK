"""Scale model_two_legs_fixed.osim for a subject using their existing
scaled single-leg model as the source of scale factors.

The existing scaled model (e.g. model_HOLOA_040.osim) was already created
by the OpenSim Scale Tool from the same lenhart2015 generic base.  This
script transplants the scaled body parameters (mass, mass_center, inertia)
and joint frame offsets from that model into model_two_legs_fixed.osim,
producing a subject-specific bilateral model without re-running the Scale Tool.

Usage
-----
    python COMAK/python/tools/scale_two_legs_from_existing.py \\
        --subject HOLOA_040 \\
        --processed_dir "D:/mayra/Descargas/UPF_COMAK-master/UPF_COMAK-master/COMAK/processed_data"

    # Or run all subjects at once (omit --subject):
    python COMAK/python/tools/scale_two_legs_from_existing.py \\
        --processed_dir "D:/mayra/Descargas/UPF_COMAK-master/UPF_COMAK-master/COMAK/processed_data"
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR     = Path(__file__).parent
TWO_LEGS_MODEL = SCRIPT_DIR.parent / "model_two_legs_fixed.osim"


# ── Regex helpers ─────────────────────────────────────────────────────────────

def _body_block(text: str, name: str) -> str | None:
    """Return the full <Body name="name">...</Body> block, or None."""
    pattern = rf'<Body name="{re.escape(name)}">(.*?)</Body>'
    m = re.search(pattern, text, re.DOTALL)
    return m.group(0) if m else None


def _get_tag(block: str, tag: str) -> str | None:
    """Return the first <tag>value</tag> value inside block, or None."""
    m = re.search(rf'<{tag}>(.*?)</{tag}>', block, re.DOTALL)
    return m.group(1).strip() if m else None


def _set_tag(block: str, tag: str, new_val: str) -> str:
    """Replace the first <tag>…</tag> in block with new_val."""
    return re.sub(
        rf'(<{tag}>)([^<]*)(</{tag}>)',
        lambda m: f"{m.group(1)}{new_val}{m.group(3)}",
        block, count=1,
    )


def _replace_body_block(text: str, name: str, new_block: str) -> str:
    """Replace the Body block for *name* in *text* with *new_block*."""
    pattern = rf'<Body name="{re.escape(name)}">.*?</Body>'
    return re.sub(pattern, new_block, text, count=1, flags=re.DOTALL)


# ── PhysicalOffsetFrame helpers ───────────────────────────────────────────────

def _offset_frame_blocks(text: str) -> list[tuple[str, str]]:
    """Return [(name, full_block), ...] for every PhysicalOffsetFrame in text."""
    pattern = r'<PhysicalOffsetFrame name="([^"]+)">(.*?)</PhysicalOffsetFrame>'
    return [(m.group(1), m.group(0))
            for m in re.finditer(pattern, text, re.DOTALL)]


def _replace_offset_frame(text: str, name: str, new_block: str) -> str:
    pattern = rf'<PhysicalOffsetFrame name="{re.escape(name)}">.*?</PhysicalOffsetFrame>'
    return re.sub(pattern, new_block, text, count=1, flags=re.DOTALL)


# ── Muscle helpers ────────────────────────────────────────────────────────────

_MUSCLE_TAGS = ("optimal_fiber_length", "tendon_slack_length",
                "pennation_angle_at_optimal", "max_isometric_force")

def _muscle_blocks(text: str) -> dict[str, str]:
    """Return {muscle_name: full_block} for every muscle-type actuator."""
    pattern = (r'<(?:Millard2012EquilibriumMuscle|Thelen2003Muscle|'
               r'RigidTendonMuscle) name="([^"]+)">(.*?)'
               r'</(?:Millard2012EquilibriumMuscle|Thelen2003Muscle|RigidTendonMuscle)>')
    out = {}
    for m in re.finditer(pattern, text, re.DOTALL):
        out[m.group(1)] = m.group(0)
    return out


def _replace_muscle_block(text: str, name: str, new_block: str) -> str:
    pattern = (rf'<(?:Millard2012EquilibriumMuscle|Thelen2003Muscle|RigidTendonMuscle)'
               rf' name="{re.escape(name)}">.*?'
               rf'</(?:Millard2012EquilibriumMuscle|Thelen2003Muscle|RigidTendonMuscle)>')
    return re.sub(pattern, new_block, text, count=1, flags=re.DOTALL)


# ── Core transfer ─────────────────────────────────────────────────────────────

def transfer_body_params(src_text: str, dst_text: str) -> tuple[str, list[str]]:
    """Copy mass/mass_center/inertia for every body that appears in both models."""
    changes: list[str] = []

    src_bodies = re.findall(r'<Body name="([^"]+)">', src_text)

    for name in src_bodies:
        src_block = _body_block(src_text, name)
        dst_block = _body_block(dst_text, name)
        if src_block is None or dst_block is None:
            continue

        updated = dst_block
        for tag in ("mass", "mass_center", "inertia"):
            src_val = _get_tag(src_block, tag)
            dst_val = _get_tag(dst_block, tag)
            if src_val is None or src_val == dst_val:
                continue
            updated = _set_tag(updated, tag, src_val)
            changes.append(f"  {name}.{tag}")

        if updated != dst_block:
            dst_text = _replace_body_block(dst_text, name, updated)

    return dst_text, changes


def transfer_offset_frames(src_text: str, dst_text: str) -> tuple[str, list[str]]:
    """Copy translation/orientation for PhysicalOffsetFrames present in both models."""
    changes: list[str] = []
    src_frames = dict(_offset_frame_blocks(src_text))

    for name, dst_block in _offset_frame_blocks(dst_text):
        src_block = src_frames.get(name)
        if src_block is None:
            continue

        updated = dst_block
        for tag in ("translation", "orientation"):
            src_val = _get_tag(src_block, tag)
            dst_val = _get_tag(dst_block, tag)
            if src_val is None or src_val == dst_val:
                continue
            updated = _set_tag(updated, tag, src_val)
            changes.append(f"  frame:{name}.{tag}")

        if updated != dst_block:
            dst_text = _replace_offset_frame(dst_text, name, updated)

    return dst_text, changes


def transfer_muscle_params(src_text: str, dst_text: str) -> tuple[str, list[str]]:
    """Copy muscle parameters for muscles present in both models."""
    changes: list[str] = []
    src_muscles = _muscle_blocks(src_text)

    for name, dst_block in _muscle_blocks(dst_text).items():
        src_block = src_muscles.get(name)
        if src_block is None:
            continue

        updated = dst_block
        for tag in _MUSCLE_TAGS:
            src_val = _get_tag(src_block, tag)
            dst_val = _get_tag(dst_block, tag)
            if src_val is None or src_val == dst_val:
                continue
            updated = re.sub(
                rf'(<{tag}>)([^<]*)(</{tag}>)',
                lambda m, v=src_val: f"{m.group(1)}{v}{m.group(3)}",
                updated, count=1,
            )
            changes.append(f"  muscle:{name}.{tag}")

        if updated != dst_block:
            dst_text = _replace_muscle_block(dst_text, name, updated)

    return dst_text, changes


# ── Per-subject entry point ───────────────────────────────────────────────────

def scale_subject(subject_dir: Path, two_legs_text: str) -> None:
    name = subject_dir.name          # e.g. HOLOA_040
    model_dir = subject_dir / "model"

    # Find the existing scaled single-leg .osim
    osim_files = [f for f in model_dir.glob("*.osim")
                  if "two_legs" not in f.name.lower()]
    if not osim_files:
        print(f"  [{name}] No single-leg .osim found — skipping.")
        return

    src_path = osim_files[0]
    src_text = src_path.read_text(encoding="utf-8", errors="replace")

    out_path = model_dir / f"model_two_legs_{name}.osim"
    if out_path.exists():
        print(f"  [{name}] Already exists: {out_path.name} — skipping.")
        return

    print(f"  [{name}] Scaling from: {src_path.name}")

    dst = two_legs_text
    all_changes: list[str] = []

    dst, c = transfer_body_params(src_text, dst)
    all_changes += c

    dst, c = transfer_offset_frames(src_text, dst)
    all_changes += c

    dst, c = transfer_muscle_params(src_text, dst)
    all_changes += c

    out_path.write_text(dst, encoding="utf-8")
    print(f"    {len(all_changes)} parameters transferred -> {out_path.name}")


# ── CLI ───────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--processed_dir", required=True,
                        help="Path to the processed_data directory")
    parser.add_argument("--subject", default=None,
                        help="Single subject folder name (e.g. HOLOA_040). "
                             "Omit to process all subjects.")
    args = parser.parse_args()

    processed_dir = Path(args.processed_dir)
    if not processed_dir.exists():
        sys.exit(f"ERROR: processed_dir not found: {processed_dir}")

    if not TWO_LEGS_MODEL.exists():
        sys.exit(f"ERROR: two-legs model not found: {TWO_LEGS_MODEL}")

    two_legs_text = TWO_LEGS_MODEL.read_text(encoding="utf-8", errors="replace")
    print(f"Two-legs generic model: {TWO_LEGS_MODEL.name}")
    print(f"Processed dir         : {processed_dir}\n")

    if args.subject:
        subject_dirs = [processed_dir / args.subject]
    else:
        subject_dirs = sorted(
            d for d in processed_dir.iterdir()
            if d.is_dir() and (d.name.startswith("HOLOA") or d.name.startswith("STRATO"))
        )

    for subject_dir in subject_dirs:
        scale_subject(subject_dir, two_legs_text)

    print("\nDone.")


if __name__ == "__main__":
    main()
