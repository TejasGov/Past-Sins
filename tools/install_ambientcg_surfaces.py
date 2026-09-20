#!/usr/bin/env python3
"""Install only the selected 1K maps from previously downloaded ambientCG ZIPs.

Downloads stay outside res://. Example (repeat for IDs in SETS below):
  curl -fLsS 'https://ambientcg.com/get?file=Tiles133A_1K-JPG.zip' \
    -o /tmp/blacksite-Tiles133A_1K-JPG.zip
  python3 tools/install_ambientcg_surfaces.py --archive-dir /tmp

No resizing/recompression, DirectX normals, displacement, or duplicate preview
files are installed. Safe to rerun: existing identical maps are left untouched;
different files are rejected, never silently overwritten.
"""

import argparse
import hashlib
from pathlib import Path
from zipfile import ZipFile

SETS = {
    "tile_shower": "Tiles133A",
    "gym_rubber": "Rubber004",
    "court_concrete": "Concrete048",
    "gunmetal": "Metal032",
    "wood_furniture": "Wood059",
    "wood_ak_furniture": "Wood030",
}
MAPS = {"Color": "albedo", "NormalGL": "normal", "Roughness": "roughness"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive-dir", type=Path, required=True)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    for material, asset_id in SETS.items():
        archive = args.archive_dir / f"blacksite-{asset_id}_1K-JPG.zip"
        selected_maps = dict(MAPS)
        if material == "gunmetal":
            selected_maps["Metalness"] = "metalness"
        with ZipFile(archive) as source:
            for source_map, role in selected_maps.items():
                filename = f"{asset_id}_1K-JPG_{source_map}.jpg"
                # Read an exact known member, never extract arbitrary ZIP paths.
                data = source.read(filename)
                destination = project / "textures" / material / f"{material}_{role}.jpg"
                if destination.exists() and destination.read_bytes() != data:
                    raise RuntimeError(f"Refusing to overwrite changed texture: {destination}")
                if not destination.exists():
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    destination.write_bytes(data)
                print(f"{destination.relative_to(project)} {len(data)} bytes sha256={hashlib.sha256(data).hexdigest()}")


if __name__ == "__main__":
    main()
