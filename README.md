# Classic UI - Forever Reframed

**Bringing the Classic look to Forever.** An open-source addon working toward
Classic Era unit frames, windows, maps and HUD, with simple choices in the game's
Edit Mode. Nameplates always keep Forever's native appearance and behavior.

[CurseForge](https://www.curseforge.com/wow/addons/classic-ui-forever-reframed/preview)
· [Report an issue](https://github.com/standujar/forever-classic-ui/issues)
· [Contribute](CONTRIBUTING.md)

## Available in development

**Version 0.3.0-dev** adds grouped controls and expands the experimental Classic
side and bottom borders from three windows to sixteen:

- **Character and skills**, **talents and spellbook**, **professions** and **recipe inspection**.
- **Quests**, **NPC conversations**, **merchants**, **trainers**, **books and letters**.
- **Mailbox**, **opened mail**, **trade**, **auction house**, **bank**, **friends and social**.
- **World map**.

These are partial skins. Titles, portraits, buttons, contents, sizes and layouts
remain native. Complete Classic windows, unit frames and HUD styling are still
in development; bags and loot windows do not yet have skins. The separate local
BlizzMove fixes enable movement and are not part of this addon.

The package targets **Forever beta 1.60.1, builds 69893 and 69913**. Interface
**16001** is confirmed by the user's build 69913 logs. The new grouped controls
and expanded skins still need in-game visual, interaction and combat validation.
See the [current validation record](docs/validation-forever-69913.md).

The last recorded CurseForge upload is **0.2.3-dev**, submitted as a **Release**
on September 17, 2026. Its observed status was Processing; that dated observation
is not a current approval check. See the [submission record](docs/validation-forever.md#curseforge-submission).

![Classic Era artwork reference — restoration targets](docs/images/classic-era-contact-sheet.png)

*Classic Era texture references, not a completed Forever interface. Artwork
© Blizzard Entertainment. The gallery's [earlier Era preview](docs/images/classic-era-ingame-prototype.png)
also predates the current modules.*

## Choose your Classic UI

Open **Escape → Edit Mode** or type **`/foreverui`**, outside combat. The Classic UI
section follows the native Edit Mode window; there is no separate Settings page.

- **Classic everywhere** selects all restoration groups and clears individual exceptions.
- **Restore Forever** disables restoration and clears group choices and exceptions.
- Choose **Windows** or **Maps** to style a group without checking every window.
- Expand **Customize** only when you want an exception, such as Classic windows
  with a native spellbook. A dash marks a group with mixed selections.
- **Unit frames** and **Action bars & HUD** show **Coming soon** and cannot be
  selected individually until their modules exist.

Fresh installations start off. Existing `ForeverReframedDB` selections survive
upgrades. Once selected, a group's default also applies to future modules in
that group; individual exceptions take precedence. **Classic everywhere** also
opts into future unit-frame and HUD modules as they become available.

Choices save immediately and apply across all Edit Mode layouts. Native **Save**
and **Revert** do not change addon choices. Turning a skin off restores its
captured native border. Unsupported or protected windows retain their native
appearance, and changes wait until combat ends. Nameplates have no restoration
option.

## Install the development build

For Forever beta, run this from the repository root:

```sh
python3 tools/package_addon.py --target forever-beta
```

1. Close the beta client.
2. Extract `ForeverReframed` from `dist/ForeverReframed-0.3.0-dev-forever-beta.zip`
   into the beta client's `Interface/AddOns` folder. On macOS this is usually
   `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/`.
3. Enable **Classic UI - Forever Reframed** in the addon list and enter the game.
4. Open Edit Mode, select **Windows**, then open the windows you want to test.
   Use **Customize** for exceptions and **Restore Forever** to check that the
   original borders return.
5. Run `/foreverui inspect`, then `/reload` to save the diagnostic report locally.

Install the archive, including its required border texture. Copying only the Lua
source directory is incomplete. If updating from a version before `0.2.2-dev`,
disable the old development addon copy; its older namespace is not imported.

### Commands

| Command | Behavior |
| --- | --- |
| `/foreverui` or `/foreverui edit` | Opens native Edit Mode with Classic UI options outside combat |
| `/foreverui settings` | Compatibility alias for the same Edit Mode options |
| `/foreverui status` | Reports client build and UI capabilities |
| `/foreverui inspect` | Reports frame availability/protection and restoration states |
| `/foreverui preview` | Toggles reference textures; does not restore the interface |
| `/foreverui hide` | Closes the texture preview; Escape also works |

The preview closes in combat. Diagnostic reports are held in
`ForeverReframedDB.lastReport` and written to disk on reload or logout. They
contain no character, account or combat data. Load-on-demand windows may appear
absent until opened. Diagnostic frame counts do not measure restoration coverage.

The source TOC remains **Classic Era 1.15.9 / Interface 11509**. Use
`python3 tools/package_addon.py --target era` for Era diagnostics and texture
previews; the experimental window skins require one of the supported Forever
builds. The [historical Era test](docs/validation-era.md) confirms loading,
reference texture rendering and report persistence for that earlier prototype.

## What comes next

The goal remains the entire Classic-style **in-game** interface except nameplates:

- Complete window artwork and layouts, including bags, loot, quests and professions.
- Player, target, pet, party and raid frames with their related indicators.
- World and flight maps, minimap, action bars and the remaining HUD.
- Shared controls, tooltips, chat, menus and dialogs.

The [restoration checklist](docs/ui-coverage.md) separates implemented partial
skins from complete restoration. Each module needs target-client testing of
rendering, native interactions, combat, scaling and compatibility. Talent trees,
maps and other windows must keep Forever's data and gameplay.

## Development

Python 3.11 or newer:

```sh
python3 -m venv tools/python-env
tools/python-env/bin/python -m pip install -r tools/requirements.txt
tools/python-env/bin/python tests/run.py
tools/python-env/bin/python -m unittest discover -s tests -p 'test_*.py'
python3 tools/package_addon.py --target forever-beta
```

Every PR runs checks and produces downloadable ZIPs. A version change merged
into `main` uploads a **Release** to CurseForge after checks pass. Documentation
or same-version updates do not publish. See the [release guide](docs/releasing.md).
Automated tests simulate the WoW APIs; passing them does not establish in-game
compatibility.

Packages include the required dialog-border BLP. Add `--with-preview-media` to
bundle eight reference samples too. The default packaging target is `era`;
archives are written to `dist/`. See the [addon extension points](addon/ForeverReframed/README.md#extension-points)
for adding modules and preserving group choices.

## Artwork and references

The repository includes **8,827 unchanged BLP textures (162.2 MiB)** with provenance
and SHA-256 hashes in [assets/classic-era](assets/classic-era). The initial local
Classic Era `1.15.9.69722` extraction recovered 34,108 files, including 31,142
textures and the native Lua/XML sources. Only the selected art pack is tracked;
full client exports, account settings and generated archives remain local.

Use the [read-only extraction tools](tools/casc/README.md) for installed-client
research. Create reference previews with:

```sh
tools/python-env/bin/python tools/preview_assets.py --source assets/classic-era
```

Presence in a shared archive does not prove that an asset belongs to the Vanilla
UI. Module research follows the active client manifests and frame definitions.

[Classic Frames](https://github.com/Daenarys/ClassicFrames) is a separate addon
used as a compatibility reference. The [audit](docs/classicframes-audit.md)
covers Retail version 3.82; its implementation is not included here. An optional
dependency does not make that Retail addon compatible with Forever.

Original addon code is **MIT-licensed**. Blizzard artwork is separately
attributed and is not relicensed under MIT. See [NOTICE.md](NOTICE.md).
