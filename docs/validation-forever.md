# Forever beta validation status

Date: September 17, 2026. Current development addon: `0.2.1-dev`.

The user cannot enter the beta yet. Source inspection and offline tests are
available; no in-game beta rendering or behavior is confirmed.

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
  the prepared integrated setup panel; runtime availability is still to be tested.

The original native sources and detailed extraction manifest stay in ignored
local directories. They are not included in the addon package.

## Packaging and historical diagnostic install

`python3 tools/package_addon.py --target forever-beta` creates a separate beta
archive without rewriting the Era source TOC. It uses **candidate Interface
16001**, derived from application version `1.60.1`. The native TOCs inspected
mostly omit this field; they do not independently confirm that number.
The runtime value printed by `GetBuildInfo()` remains authoritative.

The earlier `0.1.1-dev` diagnostic package was installed into the local
`_classic_beta_/Interface/AddOns` directory. All eight installed files matched
that archive byte for byte. Its eight Lua 5.1 tests included a simulated beta
session for runtime version reporting, modern-window detection and read-only
Settings capability detection. Those results apply to that diagnostic version;
they are not beta runtime validation or a test count for the new version.

The current package is `ForeverClassicUI-0.2.1-dev-forever-beta.zip`. It includes
the one local dialog-border BLP listed in `RequiredMedia.txt`.
`--with-preview-media` adds eight reference samples, for nine BLPs total. Preview
lookup remains native by default; experimental window borders use the required
local texture. Availability and rendering must be checked in the beta.

The `0.2.0-dev` beta package has also been installed locally. All 13 installed
files match the archive byte for byte, including the required border BLP. The
previous addon directory was backed up outside the game's AddOns directory.
Both Era and beta packages were checked with and without optional preview media
(one or nine BLPs), and packaging left the source TOC unchanged. These are
installation checks, not in-game results.

The subsequent `0.2.1-dev` package is now installed in the same beta directory,
with all 13 files verified against its ZIP and the previous version backed up.
All four Era/beta packaging variants were rebuilt and checked for the new version
and `/foreverui` command. No old command alias is registered in this version.

## Implemented offline in 0.2.0-dev; command updated in 0.2.1-dev

- Native Settings canvas registration, opened with `/foreverui` or
  `/foreverui settings` from version `0.2.1-dev`. The previous command has been
  removed; settings and saved reports are preserved.
- A master switch, per-module checkboxes, status messages, reset and texture
  preview. `ForeverClassicUIDB.settings` persists choices; all start disabled.
- Three experimental modules: `quest_window`, `player_spells_window` and
  `world_map_window`. Talents and spellbook share a single checkbox.
- Classic side and bottom border artwork only. The native top decoration,
  portrait, title, buttons, dimensions, content layout and gameplay are preserved.
- Exact version/build checks for `1.60.1 / 69893 / 16001`, expected-shape checks,
  and rejection of protected or forbidden frames. The TOC value remains a
  candidate until observed in game; a mismatch leaves modules unsupported.
- Deferred combat changes, late-load/reopen handling and restoration of captured
  border alphas when modules are disabled.
- Diagnostics retaining 25 frame probes and adding settings/restoration states.

These are code capabilities prepared for testing, not a complete Classic window
restoration or a claim of in-game safety. Unit-frame and HUD restoration is not
implemented. Nameplates remain outside restoration and have no setting.

All 27 Lua 5.1 behavioral tests pass: the eight existing diagnostic tests and
19 additional tests for the settings/restoration implementation. They simulate
the relevant APIs; no beta runtime result follows from those passes.

## First in-game check when beta access opens

1. Start the beta and enable **Forever Classic UI - Beta Workshop** in AddOns.
   Restart the client if it was already running when the addon was installed.
2. Outside combat, open `/foreverui`. Confirm the native Settings category, the
   default-off master switch and three unchecked window modules.
3. Open a quest interaction, talents, the spellbook and the world map using the
   game's normal controls. Talents may require an eligible character. Run
   `/foreverui inspect` and check the actual build, Interface, frame probes and states.
4. Enable the master switch and one window module at a time. Verify the side and
   bottom border, intact top decoration, working buttons and unchanged content.
   Test both talents and spellbook under their shared checkbox, then close and
   reopen the window. Uncheck the module and confirm the original border returns.
5. Select one module and run `/reload`. Verify the choice persists and handles a
   window that has not loaded yet. Check changes deferred during combat and their
   application afterward; record any taint or blocked-action errors.
6. Run `/foreverui preview` and check the texture samples, then `/foreverui hide`. Use
   **Reset to defaults** and confirm the native presentation returns. Run
   `/foreverui inspect` and `/reload` to save the final report and reset choices.

If the addon cannot load due to an interface-version mismatch, run
`/dump select(4, GetBuildInfo())` in the beta so the package metadata can be
corrected. Report any Lua error together with the action that triggered it.

Record the module, toggle state, triggering action and actual client build for
each result. Keep raw SavedVariables local and publish only the relevant summary.
Settings layout, border rendering, saved choices across real reloads, native
interactions, combat/taint behavior and other-addon compatibility remain untested
in the beta. Offline tests do not replace these checks.
