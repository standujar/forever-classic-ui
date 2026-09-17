# Blizzard artwork notice

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
