#!/usr/bin/env python3
"""Build a hash-checked manifest from an extraction log and local game metadata."""
import argparse
import collections
import datetime
import hashlib
import json
from pathlib import Path
import subprocess

p = argparse.ArgumentParser()
p.add_argument("--storage", type=Path, default=Path("/Applications/World of Warcraft"))
p.add_argument("--product", default="wow_classic_era")
a = p.parse_args()
root = Path(__file__).resolve().parents[2]
def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

build_info = a.storage / ".build.info"
build_lines = build_info.read_text().splitlines()
keys = [part.partition("!")[0] for part in build_lines[0].split("|")]
build = next(dict(zip(keys, line.split("|"))) for line in build_lines[1:]
             if dict(zip(keys, line.split("|"))).get("Product") == a.product)
log = root / "manifests/era-extraction-log.jsonl"
files, failures = [], []
status_counts = collections.Counter()
unavailable_errors = collections.Counter()
categories = collections.defaultdict(lambda: {"files": 0, "bytes": 0})
extensions = collections.defaultdict(lambda: {"files": 0, "bytes": 0})
expected_paths = set()
for line in log.open():
    record = json.loads(line)
    status_counts[record["status"]] += 1
    if record["status"] == "unavailable":
        unavailable_errors[str(record["error"])] += 1
        continue
    if record["status"] != "extracted":
        if record.get("error") == 1005:
            record["errorMeaning"] = "ERROR_FILE_ENCRYPTED: no matching key available; not bypassed"
        failures.append(record)
        continue
    relative = record["path"]
    path = root / "assets/era" / relative
    if path.stat().st_size != record["size"]:
        raise RuntimeError(f"Size mismatch: {relative}")
    record["sha256"] = digest(path)
    expected_paths.add(relative)
    files.append(record)
    for counter, key in ((categories, relative.split("/")[1]), (extensions, path.suffix)):
        counter[key]["files"] += 1
        counter[key]["bytes"] += record["size"]
actual_paths = {str(path.relative_to(root / "assets/era"))
                for path in (root / "assets/era").rglob("*") if path.is_file()}
if actual_paths != expected_paths:
    raise RuntimeError(f"Output differs from manifest: extra={len(actual_paths - expected_paths)}, missing={len(expected_paths - actual_paths)}")
release = json.loads((root / ".tools/wow-listfile-release.json").read_text())
manifest = {
    "schemaVersion": 1,
    "generatedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "source": {
        "type": "local Blizzard CASC installation", "storagePath": str(a.storage),
        "product": a.product, "version": build["Version"], "buildKey": build["Build Key"],
        "locale": "enUS", "buildInfoSha256": digest(build_info),
        "readOnly": True, "onlineStorage": False, "allowDownload": False,
        "note": "Every FileDataID was opened through this product's ROOT; installed addon directories were not scanned."
    },
    "extractor": {
        "library": "CascLib", "repository": "https://github.com/ladislav-zezula/CascLib",
        "commit": subprocess.check_output(["git", "-C", str(root / ".tools/CascLib"), "rev-parse", "HEAD"], text=True).strip(),
        "localPatch": "Two existence-check calls in CascFiles.cpp use STREAM_FLAG_READ_ONLY instead of 0.",
        "strictDataCheck": True, "maxBytes": 2147483648,
        "sourceSha256": digest(root / "tools/casc/extract.cpp"),
    },
    "nameMapping": {
        "provider": "wowdev community listfile (community-maintained, not an official Blizzard list)",
        "release": release["tag_name"],
        "url": next(asset["browser_download_url"] for asset in release["assets"] if asset["name"] == "community-listfile.csv"),
        "sha256": digest(root / ".tools/community-listfile.csv"),
        "candidatesSha256": digest(root / ".tools/era-ui-candidates.csv"),
        "pathCase": "lowercase",
    },
    "scope": {
        "prefix": "interface/", "extensions": [".blp", ".tga", ".lua", ".xml", ".toc", ".ttf", ".otf", ".fnt"],
        "excluded": ["interface/glues/ (login and character creation UI outside in-game addon scope)"],
        "completeness": "All mapped candidates in this scope were attempted. This is not a claim that every unnamed or unlisted asset has been recovered.",
        "copyright": "Blizzard game assets remain Blizzard's intellectual property; local extraction is not a redistribution license.",
    },
    "summary": {
        "files": len(files), "bytes": sum(record["size"] for record in files),
        "statusCounts": dict(status_counts), "unavailableErrorCounts": dict(unavailable_errors),
        "categories": dict(sorted(categories.items())), "extensions": dict(sorted(extensions.items())),
    },
    "failures": failures,
    "extractionLog": {"path": "manifests/era-extraction-log.jsonl", "sha256": digest(log)},
    "files": files,
}
destination = root / "manifests/era-assets.json"
destination.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
print(json.dumps({"manifest": str(destination), "files": len(files), "bytes": manifest["summary"]["bytes"],
                  "extensions": manifest["summary"]["extensions"], "failures": failures}, indent=2))
