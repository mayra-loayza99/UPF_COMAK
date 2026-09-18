"""
create_subject_table.py
Generate an Excel table of all subjects with included=1 from the HOLOASTRATO CSV,
annotating OA side, motion data availability, and COMAK simulation status.

Usage:
    python tools/create_subject_table.py
"""

import os
import re
import pandas as pd
from pathlib import Path

# ── Paths ──────────────────────────────────────────────────────────────────────
SCRIPT_DIR        = Path(__file__).resolve().parent
CSV_PATH          = SCRIPT_DIR.parent / "HOLOASTRATO-OASide_DATA_2026-05-21_2059.csv"
RESULTS_FINAL_DIR = Path(r"D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\results_final")
INPUTS_DIR        = Path(r"D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\inputs")
PROCESSED_DIR     = Path(r"D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\processed_data")
OUTPUT_PATH       = SCRIPT_DIR.parent / "subject_comak_status.xlsx"


def id_to_folder(patient_id: int) -> str:
    pid = str(patient_id)
    if pid.startswith("1"):
        return f"HOLOA_{pid[1:].zfill(3)}"
    if pid.startswith("2"):
        return f"STRATO_{pid[1:].zfill(3)}"
    return f"UNKNOWN_{pid}"


def get_oa_side(ext1) -> str:
    if pd.isna(ext1):
        return "Unknown"
    return "R" if int(ext1) == 1 else ("L" if int(ext1) == 2 else "Unknown")


def has_motion_data(folder: str) -> bool:
    walking = PROCESSED_DIR / folder / "walking"
    return walking.exists() and any(walking.iterdir())


def has_comak_results(folder: str) -> bool:
    comak_dir = RESULTS_FINAL_DIR / folder / "comak"
    if not comak_dir.exists():
        return False
    return any(f.name.endswith("_activation.sto") for f in comak_dir.iterdir())


def get_simulated_side(folder: str) -> str:
    """Read comak_settings.xml and extract the primary knee side."""
    settings = INPUTS_DIR / folder / "comak_settings.xml"
    if not settings.exists():
        return ""
    text = settings.read_text(encoding="utf-8", errors="ignore")
    m = re.search(r"<primary_coordinates>(.*?)</primary_coordinates>", text, re.DOTALL)
    if not m:
        return ""
    primary = m.group(1)
    if "knee_flex_r" in primary:
        return "R"
    if "knee_flex_l" in primary:
        return "L"
    return ""


def main():
    df = pd.read_csv(CSV_PATH, sep=";", dtype=str)

    # HOLOA (1XXX): keep only included=1
    # STRATO (2XXX): keep all inicio_arm_1 rows (different inclusion scheme)
    is_baseline  = df["redcap_event_name"] == "inicio_arm_1"
    is_holoa     = df["id_paciente"].str.startswith("1")
    is_strato    = df["id_paciente"].str.startswith("2")
    holoa_mask   = is_baseline & is_holoa & (df["included"].str.strip() == "1")
    strato_mask  = is_baseline & is_strato & df["extremidad1"].str.strip().isin(["1", "2"])
    df_inc = pd.concat([df[holoa_mask], df[strato_mask]]).reset_index(drop=True)
    print(f"HOLOA included=1: {holoa_mask.sum()}  |  STRATO baseline: {strato_mask.sum()}  |  Total: {len(df_inc)}")

    rows = []
    for _, row in df_inc.iterrows():
        pid      = int(row["id_paciente"])
        folder   = id_to_folder(pid)
        project  = "HOLOA" if str(pid).startswith("1") else "STRATO"
        oa_side  = get_oa_side(row["extremidad1"])
        motion   = "Yes" if has_motion_data(folder) else "No"
        comak_ok = has_comak_results(folder)
        sim_side = get_simulated_side(folder) if comak_ok else ""

        def clean(val):
            return str(val).strip() if not pd.isna(val) and str(val).strip() not in ("", "nan") else ""

        rows.append({
            "ID":                     pid,
            "Folder":                 folder,
            "Project":                project,
            "Sex (1=M, 2=F)":         clean(row["sexo"]),
            "Group":                  clean(row["grupo"]),
            "OA Side":                oa_side,
            "Motion Data Available":  motion,
            "COMAK Completed":        "Yes" if comak_ok else "No",
            "Simulated Side":         sim_side,
        })

    result = pd.DataFrame(rows)

    # ── Export to Excel with basic formatting ─────────────────────────────────
    with pd.ExcelWriter(OUTPUT_PATH, engine="openpyxl") as writer:
        result.to_excel(writer, index=False, sheet_name="Subject Status")
        ws = writer.sheets["Subject Status"]

        from openpyxl.styles import Font, PatternFill, Alignment, Border, Side

        header_fill = PatternFill("solid", fgColor="1F4E79")
        header_font = Font(bold=True, color="FFFFFF")
        yes_fill    = PatternFill("solid", fgColor="C6EFCE")   # green
        no_fill     = PatternFill("solid", fgColor="FFE0E0")   # red
        thin        = Side(style="thin", color="CCCCCC")
        border      = Border(left=thin, right=thin, top=thin, bottom=thin)

        # Header row
        for cell in ws[1]:
            cell.fill   = header_fill
            cell.font   = header_font
            cell.alignment = Alignment(horizontal="center", vertical="center")

        # Data rows
        col_idx = {cell.value: cell.column for cell in ws[1]}
        for row_cells in ws.iter_rows(min_row=2):
            for cell in row_cells:
                cell.border    = border
                cell.alignment = Alignment(horizontal="center")
            # Colour-code COMAK column
            comak_cell = row_cells[col_idx["COMAK Completed"] - 1]
            if comak_cell.value == "Yes":
                comak_cell.fill = yes_fill
            elif comak_cell.value == "No":
                comak_cell.fill = no_fill
            # Colour-code Motion Data column
            motion_cell = row_cells[col_idx["Motion Data Available"] - 1]
            if motion_cell.value == "Yes":
                motion_cell.fill = yes_fill
            elif motion_cell.value == "No":
                motion_cell.fill = no_fill

        # Auto-width
        for col in ws.columns:
            max_len = max(len(str(cell.value or "")) for cell in col)
            ws.column_dimensions[col[0].column_letter].width = max(max_len + 3, 12)

        ws.freeze_panes = "A2"

    print(f"\nExcel saved to: {OUTPUT_PATH}")
    print(f"\nSummary:")
    print(result.groupby(["Project", "OA Side", "COMAK Completed"]).size().to_string())


if __name__ == "__main__":
    main()
