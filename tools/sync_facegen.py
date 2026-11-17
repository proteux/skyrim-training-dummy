#!/usr/bin/env python3
"""Sync RaceMenu CharGen exports into FaceGen paths for PTX_TrainingDummy.

Female only: Female_Dummy is copied to every female slot FormID
(00000802 / 0000080D / 0000080E). Male uses the EncBandit default head (no
FaceGen override), so Male_Dummy CharGen exports are ignored and leftover male
FaceGen files are removed from repo Data.

Also writes CharGen/<Name>.nif.dds — RaceMenu embeds that tint path inside the .nif,
so FaceGen heads stay colored without NifSkope path rewriting.
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

ESP = "PTX_TrainingDummy.esp"
FEMALE_STEM = "Female_Dummy"
# Slot 0 / 1 / 2 — same CharGen export until distinct heads exist.
FEMALE_FORM_IDS = ("00000802", "0000080D", "0000080E")
MALE_FORM_IDS = ("00000801", "00000805", "00000806")


def sync(data: Path, repo_data: Path) -> int:
    chargen = data / "SKSE" / "Plugins" / "CharGen"
    if not chargen.is_dir():
        print(f"CharGen folder missing: {chargen}", file=sys.stderr)
        return 1

    geom_repo = repo_data / "meshes" / "actors" / "character" / "FaceGenData" / "FaceGeom" / ESP
    tint_repo = repo_data / "textures" / "actors" / "character" / "FaceGenData" / "FaceTint" / ESP
    geom_repo.mkdir(parents=True, exist_ok=True)
    tint_repo.mkdir(parents=True, exist_ok=True)

    for form_id in MALE_FORM_IDS:
        for path in (geom_repo / f"{form_id}.nif", tint_repo / f"{form_id}.dds"):
            if path.is_file():
                path.unlink()
                print(f"Removed male FaceGen override {path.name}")

    nif = chargen / f"{FEMALE_STEM}.nif"
    dds = chargen / f"{FEMALE_STEM}.dds"
    if not nif.is_file() or not dds.is_file():
        print(f"Missing {nif.name} and/or {dds.name} in CharGen", file=sys.stderr)
        return 1

    # RaceMenu nif references CharGen\<stem>.nif.dds for the tintmask.
    nif_dds = chargen / f"{FEMALE_STEM}.nif.dds"
    shutil.copy2(dds, nif_dds)

    for form_id in FEMALE_FORM_IDS:
        shutil.copy2(nif, geom_repo / f"{form_id}.nif")
        shutil.copy2(dds, tint_repo / f"{form_id}.dds")
        print(f"Synced {FEMALE_STEM} -> {form_id} (+ {nif_dds.name})")

    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "--skyrim-data",
        type=Path,
        default=Path(r"C:\Program Files (x86)\Steam\steamapps\common\Skyrim Special Edition\Data"),
    )
    p.add_argument(
        "--repo-data",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "Data",
    )
    args = p.parse_args()
    return sync(args.skyrim_data.resolve(), args.repo_data.resolve())


if __name__ == "__main__":
    raise SystemExit(main())
