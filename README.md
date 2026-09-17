# Forever Classic UI

An open-source addon project to bring **the entire Classic Era in-game interface,
except nameplates, to World of Warcraft: Forever**: unit frames, action bars,
minimap, talents, quests, world and flight maps, character panels, spellbooks,
bags, banks, professions, mail, auctions, social panels and other windows and
controls. Nameplates remain as provided by the Forever client.

**Early development:** the current prototype provides client diagnostics and a
texture preview. It does not yet replace native frames, and Forever compatibility
has not been validated. The development TOC targets **Classic Era 1.15.9**.

![Classic Era texture reference sheet](docs/images/classic-era-contact-sheet.png)

*Extracted texture samples, including talents and quest panels. This is a
reference sheet, not a screenshot of a completed in-game interface.*

## What's included

- An original modular Lua addon with `/fcui status`, `/fcui inspect`,
  `/fcui preview` and `/fcui hide`.
- **8,827 unchanged BLP textures (162.2 MiB)** in
  [assets/classic-era](assets/classic-era), with provenance and SHA-256 hashes.
- Local, read-only CASC extraction tools for obtaining interface resources from
  an installed client.
- Seven behavioral tests running under Lua 5.1 through Lupa.
- A [Classic Frames compatibility audit](docs/classicframes-audit.md).
- An [in-game restoration checklist](docs/ui-coverage.md), distinguishing
  extracted artwork, diagnostic coverage and functional replacement work.

The original code is **MIT licensed**. Blizzard artwork is separately attributed
and is not relicensed under MIT. See [NOTICE.md](NOTICE.md).

## Try the development addon

1. Close Classic Era.
2. Copy `addon/ForeverClassicUI` into that client's `Interface/AddOns` directory.
3. Start the game and enable **Forever Classic UI** in the addon list.
4. Run `/fcui status`, then `/fcui preview` while out of combat.

On macOS, the usual destination is
`/Applications/World of Warcraft/_classic_era_/Interface/AddOns/ForeverClassicUI`.

| Command | Behavior |
| --- | --- |
| `/fcui status` | Reports client build and UI capabilities |
| `/fcui inspect` | Includes named-frame availability and protection information |
| `/fcui preview` | Toggles texture samples for unit frames, buttons, quests and talents |
| `/fcui hide` | Closes the preview; Escape also works |

The preview closes when combat starts and cannot be opened during combat. It
does not modify native frames or display a functional talent tree. The diagnostic
report is stored in `ForeverClassicUIDB.lastReport`; the game saves it on reload
or logout. It contains no character, account or combat data. Load-on-demand
windows may appear absent until opened.

The 21 named-frame probes are only a diagnostic sample. A result such as 19/21
does not measure how many Classic frames exist or how much of the UI is restored.

The [first in-game smoke test](docs/validation-era.md) confirmed that the addon
loads, its native texture samples render and the diagnostic report persists on
Era 1.15.9. Combat behavior, broader compatibility and functional replacements
still require client testing. The automated tests use a simulated WoW environment.

## Development

Python 3.11 or newer:

```sh
python3 -m venv tools/python-env
tools/python-env/bin/python -m pip install -r tools/requirements.txt
tools/python-env/bin/python tests/run.py
python3 tools/package_addon.py
```

The archive is written to `dist/`. Add `--with-preview-media` to include the
eight texture samples from the checked-in art pack or your local extraction.
The preview uses native textures by default; the media module also supports
explicit local paths for future client ports.

To generate a quick reference sheet:

```sh
tools/python-env/bin/python tools/preview_assets.py --source assets/classic-era
```

Use `--verify-all` for a full decode check, which can take several minutes.
Some modern BLP encodings are unsupported by Pillow; a decode limitation does
not by itself indicate a damaged original file.

## Interface resources

The initial local extraction from **Classic Era 1.15.9.69722** recovered
34,108 files: 31,142 BLP textures, 1,899 Lua files, 775 XML files and 292 TOC files
(approximately 1.8 GB). This includes 200 talent textures and the native talent
window source. The repository includes a selected frame-art pack, rather than
the full extraction, zone-map tile collection, shop assets or game UI source.
The reference pack and diagnostic probes are research resources; their inclusion
does not establish restoration progress or override the scope checklist.

The extraction explicitly selects the `wow_classic_era` product from the shared
CASC installation. See [the extraction guide](tools/casc/README.md). Full exports,
local installation reports, tool downloads and generated archives are ignored
by Git. Original BLP files are preserved; PNGs are only previews.

Classic clients contain some shared resources from other versions. Presence in
an Era archive does not prove that a texture is used by its Vanilla UI. For talent
layout research, follow `Blizzard_TalentUI_Vanilla.toc` and its `classic` sources.

## Relationship to Classic Frames

[Classic Frames](https://github.com/Daenarys/ClassicFrames) is a separate addon
and a useful compatibility reference. The audited version is **3.82 for Retail
12.1**, commit `55b66cc4b45e0a581b1a8d388980620f59f4f491`. Its project page lists
All Rights Reserved; this repository does not include its implementation.

Our addon is standalone at this stage. An optional dependency allows future
coexistence with a compatible Classic Frames release, but does not make the
Retail version compatible with Era or Forever. Changing a TOC number alone is
not a port.

## Roadmap

- Track all in-game UI families except nameplates in the
  [restoration checklist](docs/ui-coverage.md).
- Inspect the actual Forever client, build and UI APIs before final adaptation.
- Add a setup panel in the game's native options with a checkbox for each
  restoration module. Unchecked modules retain Forever's appearance; nameplates
  always remain native and have no restoration option. This panel is planned,
  not yet implemented.
- Restore window artwork and layout in isolated, reversible modules.
- Cover talents, quests, character panels, spellbooks, bags, bank, world map and
  flight map windows.
- Cover mail, trade, professions, auctions, social, pet, PvP and settings windows,
  including their buttons, tabs and other controls.
- Restore Classic unit frames, action bars, minimap and the remaining HUD while
  preserving secure gameplay.
- Validate each module in combat, at different UI scales and with other addons.

Talent trees and maps must retain the target client's data and mechanics.
The goal is a Classic-style in-game interface built on the supported client APIs,
with Forever's native nameplates retained. See [CONTRIBUTING.md](CONTRIBUTING.md)
to help.
