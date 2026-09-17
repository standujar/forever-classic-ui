# Content and licenses

The MIT license in `LICENSE` applies to original Classic UI - Forever Reframed code,
tests, extraction tools and project documentation.

## Blizzard interface artwork

The `.blp` files under `assets/classic-era/interface/`, and copies in generated
addon `Media` directories, are World of Warcraft
interface resources extracted from a local Classic Era client. They remain
copyright Blizzard Entertainment and are **not covered by this project's MIT
license**. Their paths, FileDataIDs, source build and hashes are recorded in
`assets/classic-era/manifest.json`. The project's license does not grant rights
to Blizzard material.

Generated preview images derived from this artwork have the same attribution.
World of Warcraft and Blizzard Entertainment are trademarks of Blizzard
Entertainment. This is an independent community project, not an official or
endorsed Blizzard product.

## Classic Frames reference

[Classic Frames](https://github.com/Daenarys/ClassicFrames) by luckfore is a
separate addon. Its public project page lists All Rights Reserved. No Classic
Frames implementation or bundled library code is included in this repository.
The compatibility audit links to the author's source for reference.

## Build-time dependencies

CascLib and the wowdev community listfile are downloaded separately by the
documented local extraction workflow. They are not vendored here and retain
their respective notices and licenses. Python test and image dependencies are
listed in `tools/requirements.txt`.
