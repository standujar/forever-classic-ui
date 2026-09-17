# Forever beta preflight

Date: September 17, 2026. Diagnostic addon: `0.1.1-dev`.

## Confirmed from the installed client

- Product: `wow_classic_beta`.
- Application version: `1.60.1`, build `69893`.
- CASC build key: `70dc75547c16ac2a381fde65945a0e85`.
- The read-only source extraction recovered 4,393 Lua, XML and TOC files
  (36,308,296 bytes), without encrypted-file or read failures in this selection.

These are installation and source observations, not results from a running game.
The beta is not the same build as the Era `1.15.9.69722` reference client.

## Native interface structure

The sources contain a Camelot variant with Mainline-family components. Porting
the Era layout requires following the active module's load conditions, not just
finding a familiar file or global in the shared archives.

- `Blizzard_UnitFrame` defines `PlayerFrame`, `TargetFrame` and `FocusFrame` using
  secure templates, with Mainline sources and Camelot overrides.
- The load-on-demand `Blizzard_PlayerSpells` module creates `PlayerSpellsFrame`.
  Its Camelot XML contains `TalentsFrame` and `SpellBookFrame` children. Its talent
  implementation uses `C_Traits`; the Era `PlayerTalentFrame` is not the target.
- The quest interaction window is `QuestFrame`. The quest log is `QuestMapFrame`,
  attached as `WorldMapFrame.QuestLog`.
- The world map is `WorldMapFrame`, with a `BorderFrame` child.
- Native Settings sources define `RegisterCanvasLayoutCategory`,
  `RegisterAddOnCategory` and `OpenToCategory`. Their presence in source supports
  the planned integrated setup panel; runtime availability is still to be tested.

The original native sources and detailed extraction manifest stay in ignored
local directories. They are not included in the addon package.

## Diagnostic package

`python3 tools/package_addon.py --target forever-beta` creates a separate beta
archive without rewriting the Era source TOC. It uses **candidate Interface
16001**, derived from application version `1.60.1`. The native TOCs inspected
mostly omit this field; they do not independently confirm that number.
The runtime value printed by `GetBuildInfo()` remains authoritative.

The addon samples 25 named globals and reports Settings API availability without
calling those APIs. It does not inspect talent or combat data, modify native
frames or touch nameplates. Preview texture lookup remains native by default;
availability and appearance of those samples must be checked in the beta.

The beta package was installed into the local `_classic_beta_/Interface/AddOns`
directory. All eight installed files match the built archive byte for byte.
The client was running during installation and needs a restart to discover the
new addon. Installation verification is separate from runtime validation.

The eight Lua 5.1 behavioral tests include a simulated beta session to check
runtime version reporting, modern-window detection and read-only Settings
capability detection. They do not establish in-game compatibility.

## First in-game check

1. Start the beta and enable **Forever Classic UI - Beta Workshop** in AddOns.
   Restart the client if it was already running when the addon was installed.
2. Open talents, the spellbook and the world map using the game's normal controls.
   Talents may require an eligible character. This allows their modules to load.
3. Run `/fcui inspect`. Check the printed client build, interface number, modern
   frame probes and Settings API capabilities. Legacy names may remain absent.
4. Outside combat, run `/fcui preview` and check the displayed texture samples,
   then close it with `/fcui hide`.
5. Run `/reload` or log out to save `ForeverClassicUIDB.lastReport` to disk.

If the addon cannot load due to an interface-version mismatch, run
`/dump select(4, GetBuildInfo())` in the beta so the package metadata can be
corrected. Report any Lua error together with the action that triggered it.

No beta runtime test, functional restoration, integrated setup panel or combat
safety result is claimed yet. The full restoration scope still excludes native
Forever nameplates; individual supported modules will be selectable in setup.
