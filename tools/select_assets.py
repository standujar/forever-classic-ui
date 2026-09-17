#!/usr/bin/env python3
"""Select and verify an unchanged Classic Era UI texture pack for this project."""
import argparse
import collections
import hashlib
import json
from pathlib import Path, PurePosixPath

PROJECT_ROOT = Path(__file__).resolve().parents[1]
FOLDERS = frozenset({
    "talentframe", "questframe", "questlogframe", "targetingframe",
    "characterframe", "paperdollinfoframe", "containerframe", "bankframe",
    "spellbook", "mainmenubar", "minimap", "buttons", "dialogframe",
    "tooltips", "castingbar", "moneyframe", "itemtextframe", "gossipframe",
    "lootframe", "merchantframe", "friendsframe", "chatframe", "auctionframe",
    "classtrainerframe", "taxiframe", "icons",
})
MAX_BYTES = 150 * 1024 * 1024
NOTICE = """# Blizzard artwork notice

World of Warcraft interface artwork is copyright Blizzard Entertainment, Inc.
All rights reserved.

This directory contains selected, unchanged BLP textures extracted from a locally
installed World of Warcraft Classic Era client, version **1.15.9.69722**. The
selection supports development of a Classic-style interface addon for World of
Warcraft. It is an interface texture pack, not a copy of the entire game or a
complete inventory of its interface assets.

Blizzard artwork is **not covered by this repository's MIT license**. That
license applies to the project's original code and tooling. Attribution and
inclusion here do not grant permission or additional rights to use or
redistribute Blizzard's artwork. This project does not claim ownership of these
textures and is not affiliated with or endorsed by Blizzard Entertainment.

`manifest.json` records the source product and build, each selected file's
FileDataID, byte size and SHA-256, plus the selection rules and category totals.
The files retain their extracted bytes and BLP format. File names were resolved
using the community-maintained wowdev listfile; it is not an official Blizzard
inventory.

The selection includes frame artwork and icons. Only files directly inside
`interface/worldmap/` are included; zone-map tile directories are excluded.
Login screens, character creation artwork, shop artwork, and unrelated interface
categories are outside this pack's selection.

To reproduce the selection after running the local extraction tools, run
`python3 tools/select_assets.py` from the repository root.
"""


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def selected(path):
    parts = path.parts
    return (
        len(parts) >= 3
        and parts[0] == "interface"
        and path.suffix == ".blp"
        and ".." not in parts
        and (parts[1] in FOLDERS or (parts[1] == "worldmap" and len(parts) == 3))
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-manifest", type=Path,
                        default=PROJECT_ROOT / "manifests/era-assets.json")
    parser.add_argument("--raw-source", type=Path,
                        default=PROJECT_ROOT / "assets/era")
    parser.add_argument("--output", type=Path,
                        default=PROJECT_ROOT / "assets/classic-era")
    args = parser.parse_args()
    source_bytes = args.source_manifest.read_bytes()
    source_manifest = json.loads(source_bytes)
    source = source_manifest["source"]
    if source["product"] != "wow_classic_era":
        raise ValueError("The source manifest must describe wow_classic_era.")
    records = sorted(
        (record for record in source_manifest["files"]
         if selected(PurePosixPath(record["path"]))),
        key=lambda record: record["path"],
    )
    if not records:
        raise ValueError("No matching textures were found in the source manifest.")
    paths = {record["path"] for record in records}
    if len(paths) != len(records):
        raise ValueError("The source manifest contains duplicate selected paths.")
    total_bytes = sum(record["size"] for record in records)
    if total_bytes > MAX_BYTES:
        raise ValueError(f"Selection exceeds the 150 MiB limit: {total_bytes} bytes.")
    raw_root = args.raw_source.resolve(strict=True)
    output_root = args.output.resolve()
    if output_root == raw_root or raw_root in output_root.parents:
        raise ValueError("Keep the selected pack separate from the raw extraction.")
    existing_paths = {path.relative_to(output_root).as_posix()
                      for path in output_root.rglob("*.blp")}
    if existing_paths - paths:
        raise ValueError("Output contains textures outside this selection; use a fresh output directory.")

    files = []
    categories = collections.defaultdict(lambda: {"files": 0, "bytes": 0})
    for record in records:
        relative = record["path"]
        original = (raw_root / relative).resolve(strict=True)
        if raw_root not in original.parents:
            raise ValueError(f"Source path escapes the raw extraction: {relative}")
        data = original.read_bytes()
        if len(data) != record["size"] or sha256(data) != record["sha256"]:
            raise ValueError(f"Source hash or size mismatch: {relative}")
        if data[:4] not in (b"BLP1", b"BLP2"):
            raise ValueError(f"Invalid BLP signature: {relative}")
        destination = output_root / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not destination.exists() or destination.read_bytes() != data:
            destination.write_bytes(data)
        files.append({
            "path": relative,
            "fileDataId": record["fileDataId"],
            "size": record["size"],
            "sha256": record["sha256"],
        })
        category = PurePosixPath(relative).parts[1]
        categories[category]["files"] += 1
        categories[category]["bytes"] += record["size"]

    # Deliberately copy only public build metadata, never local installation paths.
    manifest = {
        "schemaVersion": 1,
        "description": "Selected unchanged Classic Era interface BLP textures",
        "source": {key: source[key] for key in ("product", "version", "buildKey", "locale")},
        "sourceManifestSha256": sha256(source_bytes),
        "nameMapping": {
            key: source_manifest["nameMapping"][key]
            for key in ("provider", "release", "url", "sha256", "pathCase")
        },
        "selection": {
            "includedInterfaceFolders": sorted(FOLDERS),
            "worldmap": "Only immediate .blp files; all subdirectories excluded",
            "extensions": [".blp"],
            "maxBytes": MAX_BYTES,
            "completeGameExtraction": False,
            "unchangedFromSource": True,
        },
        "rights": {
            "owner": "Blizzard Entertainment, Inc.",
            "coveredByProjectMITLicense": False,
            "notice": "NOTICE.md",
        },
        "summary": {
            "files": len(files), "bytes": total_bytes,
            "categories": dict(sorted(categories.items())),
        },
        "files": files,
    }
    (output_root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    notice = NOTICE.replace("1.15.9.69722", source["version"])
    (output_root / "NOTICE.md").write_text(notice)
    print(json.dumps({"files": len(files), "bytes": total_bytes,
                      "mib": round(total_bytes / (1024 * 1024), 2),
                      "categories": manifest["summary"]["categories"]}, indent=2))


if __name__ == "__main__":
    main()
