#!/usr/bin/env python3
"""Sync RaceMenu CharGen exports into FaceGen paths for PTX_TrainingDummy.

Copies Male_Dummy / Female_Dummy from Data/SKSE/Plugins/CharGen into:
  meshes/.../FaceGeom/PTX_TrainingDummy.esp/00000801.nif (male) / 00000802.nif (female)
  textures/.../FaceTint/PTX_TrainingDummy.esp/0000080x.dds

Also writes CharGen/<Name>.nif.dds — RaceMenu embeds that tint path inside the .nif,
so FaceGen heads stay colored without NifSkope path rewriting.
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

ESP = "PTX_TrainingDummy.esp"
PAIRS = (
    ("Male_Dummy", "00000801"),
    ("Female_Dummy", "00000802"),
)


def sync(data: Path, repo_data: Path) -> int:
    chargen = data / "SKSE" / "Plugins" / "CharGen"
    if not chargen.is_dir():
        print(f"CharGen folder missing: {chargen}", file=sys.stderr)
        return 1

    geom_repo = repo_data / "meshes" / "actors" / "character" / "FaceGenData" / "FaceGeom" / ESP
    tint_repo = repo_data / "textures" / "actors" / "character" / "FaceGenData" / "FaceTint" / ESP
    geom_repo.mkdir(parents=True, exist_ok=True)
    tint_repo.mkdir(parents=True, exist_ok=True)

    missing = False
    for stem, form_id in PAIRS:
        nif = chargen / f"{stem}.nif"
        dds = chargen / f"{stem}.dds"
        if not nif.is_file() or not dds.is_file():
            print(f"Missing {nif.name} and/or {dds.name} in CharGen", file=sys.stderr)
            missing = True
            continue

        # RaceMenu nif references CharGen\<stem>.nif.dds for the tintmask.
        nif_dds = chargen / f"{stem}.nif.dds"
        shutil.copy2(dds, nif_dds)

        shutil.copy2(nif, geom_repo / f"{form_id}.nif")
        shutil.copy2(dds, tint_repo / f"{form_id}.dds")
        print(f"Synced {stem} -> {form_id} (+ {nif_dds.name})")

    return 1 if missing else 0


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
