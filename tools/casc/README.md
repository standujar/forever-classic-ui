# Local Classic Era extraction

This tool reads the installed client's CASC archives and explicitly selects the
`wow_classic_era` product. It does not scan installed addons, launch the game, or
modify its installation. Storage is opened offline, with CASC downloads disabled.

The local extraction performed on September 17, 2026 used Era **1.15.9.69722**,
build `3645f0fe9dc5215ea90eaf7cdb7379ce`, and produced **34,108 files totaling
1,817,050,905 bytes**. The generated local manifest at
`manifests/era-assets.json` records SHA-256 hashes, FileDataIDs, CKeys, EKeys,
sizes, provenance, and category totals. Extracted images retain their original
BLP format; this copy has not been converted.

- 31,142 BLP textures, including 200 `talentframe`, 61 `questframe`, 15,955
  `worldmap`, and 6,364 icon textures.
- 1,899 native Lua files, 775 XML files, and 292 TOC files. Relevant Era modules
  include `interface/addons/blizzard_talentui/classic/`,
  `blizzard_uipanels_game/vanilla/`, and `blizzard_characterframe/vanilla/`.
- Login and character creation artwork (`interface/glues/`) is excluded because
  it falls outside the scope of an in-game addon.
- Two encrypted shop illustrations could not be extracted. No encryption
  bypass is used. Their names are recorded in the generated manifest.
- The 124,467 unavailable candidates come from a list shared across game
  versions; they do not represent 124,467 missing Era assets. Coverage is limited
  to files **named in the list and available locally**. Files without a known
  listfile entry may remain undiscovered.

These counts describe one local installation and may differ with another build.
Game assets are generated locally and are not required to build the extractor.

## Reproduce the extraction

Requirements: macOS, Clang/C++, CMake, Python 3, Git, curl, and zlib.

Run from the project root:

```sh
sh tools/casc/build.sh
curl -L --fail \
  https://github.com/wowdev/wow-listfile/releases/download/202609171121/community-listfile.csv \
  -o .tools/community-listfile.csv
curl -L --fail \
  https://api.github.com/repos/wowdev/wow-listfile/releases/tags/202609171121 \
  -o .tools/wow-listfile-release.json
python3 tools/casc/prepare_candidates.py \
  .tools/community-listfile.csv .tools/era-ui-candidates.csv
.tools/casc-extract '/Applications/World of Warcraft' wow_classic_era \
  .tools/era-ui-candidates.csv assets/era \
  manifests/era-extraction-log.jsonl 2147483648
python3 tools/casc/make_manifest.py
```

The build script creates `.tools/`. The extractor creates its output directory
and the parent directory of the extraction log, including `manifests/` on a
fresh checkout. Output paths must be outside the WoW installation. Use a fresh
output directory when changing the scope or game build: the manifest generator
rejects extra or missing files. The extraction limit is 2 GiB, with a maximum of
32 MiB per file. Adjust the installation path if necessary and pass the same
path to the manifest generator with `--storage '/path/to/World of Warcraft'`.

## Sources and local library patch

- Upstream library:
  <https://github.com/ladislav-zezula/CascLib>, pinned to commit
  `2a280f5a231966dc5d1b534978dd9f9f04a374cd`.
- File names: <https://github.com/wowdev/wow-listfile>, community-maintained
  release dated September 17, 2026. This is not an official Blizzard inventory.
- Two CascLib existence checks unnecessarily request write access. `build.sh`
  changes those calls to use `STREAM_FLAG_READ_ONLY` in the local library copy
  under `.tools/`. This allows extraction within a sandbox that grants only read
  access to the game installation.

Game assets remain Blizzard's intellectual property. Local extraction does not
grant permission to redistribute those files or place them under this project's
open-source license.
