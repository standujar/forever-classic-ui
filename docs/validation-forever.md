# Forever beta validation status

Date: September 17, 2026. Current development addon: `0.2.3-dev`.

Version `0.2.3-dev` moves Classic UI options directly into native Edit Mode.
Its Release package was uploaded automatically after CI passed. CurseForge
reported **Processing** when checked on September 17, 2026; public approval is
not confirmed.

The `ForeverReframed` 0.2.3-dev beta package is installed locally, with all 13
files checked against its archive. The previous addon copy was backed up outside
AddOns before replacement; SavedVariables were untouched. Earlier releases also
verified packaging for both client targets with optional preview artwork.

The user cannot enter the beta yet. Source inspection and offline tests are
available; no in-game beta rendering or behavior is confirmed.

## CurseForge submission

The current Release was uploaded on September 17, 2026 at 20:17 Europe/Paris:

- Project: **Classic UI - Forever Reframed**, ID `1699904`, under author `k4rno`.
- Slug: `classic-ui-forever-reframed`.
- [Project preview](https://www.curseforge.com/wow/addons/classic-ui-forever-reframed/preview).
- Linked source: [standujar/forever-classic-ui](https://github.com/standujar/forever-classic-ui).
- Uploaded archive: `ForeverReframed-0.2.3-dev-forever-beta.zip`, file ID `8905648`.
- Display name: **Classic UI - Forever Reframed 0.2.3-dev**.
- Game version: `1.60.1`; distribution channel: **Release**.
- Observed file status: **Processing**. Public approval is not confirmed.

Source revision `f3e733a` passed both checks and the automatic Publish Release job
in [GitHub Actions run 35257915758](https://github.com/standujar/forever-classic-ui/actions/runs/35257915758).
All 37 Lua 5.1 behavioral tests and 21 Python release-tool tests passed. The run's
`curseforge-upload.json` receipt records project `1699904`, file `8905648`,
version `0.2.3-dev` and the matching archive. Its SHA-256 is
`5dcee63033480063e8216f2ec7c73918010dccf9c771b0d67926d1dff91b806d`.

The [author file dashboard](https://authors.curseforge.com/#/projects/1699904/files)
requires the project's author account. The Release channel does not change the
experimental feature scope or establish beta runtime compatibility.

### Initial 0.2.2-dev submission

The initial `ForeverReframed-0.2.2-dev-forever-beta.zip` was submitted manually on
September 17, 2026 as file `8904620`, with display name **Classic UI - Forever
Reframed 0.2.2-dev**, game version `1.60.1` and channel **Release**. It remained
**Under Review** when the newer file was checked. The initial project status was
**New**, pending moderator validation.

That submission's source revision is `e8e5817`.
[GitHub Actions run 35242087809](https://github.com/standujar/forever-classic-ui/actions/runs/35242087809)
passed, including all 28 Lua 5.1 behavioral tests. These are offline checks;
the beta runtime validation below remains outstanding.

### Gallery references

Both gallery images were uploaded and saved on September 17, 2026. **Classic Era
artwork reference — restoration targets** is the first image and the selected
feature media. This primary repository visual shows original texture samples
for unit frames, quests, talents, bars, minimap and windows. The
[reference sheet](images/classic-era-contact-sheet.png) is a collection of
artwork, not an in-game screenshot or completed restoration. Its caption credits
Blizzard Entertainment.

The second gallery image, **In-game texture preview — Classic Era prototype**,
is an unmodified user screenshot from the `0.1` prototype on Classic
Era `1.15.9`, before the addon was renamed. The preview displays artwork samples
and leaves the native interface unchanged. The image is also available in
[the repository](images/classic-era-ingame-prototype.png).

Neither image demonstrates the current beta border modules or a completed
interface restoration.

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
  `RegisterAddOnCategory` and `OpenToCategory`. These supported the previous
  `0.2.2-dev` integration and remain diagnostic API probes; `0.2.3-dev` no longer
  registers an addon Settings category.
- The current options section is a direct child of `EditModeManagerFrame` and
  opens through the native Edit Mode path. Its live behavior is still unvalidated.

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

The current package is `ForeverReframed-0.2.3-dev-forever-beta.zip`. It includes
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

The subsequent `0.2.1-dev` package was installed in the same beta directory,
with all 13 files verified against its ZIP and the previous version backed up.
All four Era/beta packaging variants were rebuilt and checked for the new version
and `/foreverui` command. No old command alias is registered in this version.

Those historical packages used the `ForeverClassicUI` addon directory and
`ForeverClassicUIDB` settings. Version `0.2.2-dev` adopts the public name
**Classic UI - Forever Reframed**, the `ForeverReframed` directory and the distinct
`ForeverReframedDB` namespace. It does not read or modify the old database. The
`/foreverui` command is unchanged; the renamed addon starts with default-off
settings. The earlier installation checks describe the earlier package names.

## Current implementation and development history

- Version `0.2.3-dev` replaces the separate Settings category with a compact
  **Classic UI** section attached directly to `EditModeManagerFrame`. It follows
  the manager's visibility and movement.
- **Escape → Edit Mode**, `/foreverui` and `/foreverui edit` reach the same native
  surface. `/foreverui settings` remains a compatibility alias. Opening requires
  an available native manager and an allowed state outside combat.
- A master switch, per-module checkboxes, status messages and reset.
  `ForeverReframedDB.settings` choices update immediately and apply across all
  layouts. Native Edit Mode **Save** and **Revert** do not undo these choices.
  Fresh installations start disabled; existing `ForeverReframedDB` choices are
  retained. Texture samples remain available through `/foreverui preview`.
- Three experimental modules: `quest_window`, `player_spells_window` and
  `world_map_window`. Talents and spellbook share a single checkbox.
- Classic side and bottom border artwork only. The native top decoration,
  portrait, title, buttons, dimensions, content layout and gameplay are preserved.
- Exact version/build checks for `1.60.1 / 69893 / 16001`, expected-shape checks,
  and rejection of protected or forbidden frames. The TOC value remains a
  candidate until observed in game; a mismatch leaves modules unsupported.
- Deferred combat changes, late-load/reopen handling and restoration of captured
  border alphas when modules are disabled.
- Diagnostics retaining 25 frame probes and Settings API presence flags, plus
  Edit Mode control registration and restoration states.

These are code capabilities prepared for testing, not a complete Classic window
restoration or a claim of in-game safety. Unit-frame and HUD restoration is not
implemented. Nameplates remain outside restoration and have no setting.

For `0.2.3-dev`, all 37 Lua 5.1 behavioral tests and 21 Python release-tool tests
pass locally and in the CI run linked above. The addon tests simulate the relevant APIs, including Edit Mode
integration, persistence, restoration and deferred changes. Their results do
not establish beta runtime compatibility. The successful upload is separately
recorded by the receipt and author dashboard.
The historical `0.2.2-dev` CI result above applies to that version.

## Edit Mode validation for 0.2.3-dev

1. Start the beta and enable **Classic UI - Forever Reframed - Beta Workshop** in AddOns.
   Restart the client if it was already running when the addon was installed.
2. Outside combat, choose **Escape → Edit Mode**. Confirm the attached Classic UI
   section, master switch and three window modules. Fresh settings should be off;
   an upgrade from `0.2.2-dev` should retain the player's selections. Confirm that
   `/foreverui`, `/foreverui edit` and `/foreverui settings` open this same surface.
3. Move and close/reopen the native Edit Mode window. Verify the Classic UI
   section follows it, disappears when it closes, and is not duplicated.
4. Close Edit Mode. Open a quest interaction, talents, the spellbook and the world
   map using the game's normal controls. Talents may require an eligible character. Run
   `/foreverui inspect` and check the actual build, Interface, frame probes and states.
5. In Edit Mode, enable the master switch and one window module at a time. Close
   Edit Mode and verify the side and bottom border, intact top decoration,
   working buttons and unchanged content.
   Test both talents and spellbook under their shared checkbox, then close and
   reopen the window. Return to Edit Mode, uncheck the module and confirm the
   original border returns. Turning the master switch off should disable all styling.
6. Select a module, switch native Edit Mode layouts, and use native **Save** and
   **Revert**. Confirm the addon selection stays the same and its explanatory
   note remains visible. The addon choices are shared across layouts and do not
   participate in native layout save/revert.
7. Run `/reload` with a module selected. Verify its selection persists and handles
   a window that has not loaded yet. Confirm commands cannot open Edit Mode in
   combat, queued restoration changes apply after combat, and returning to an
   allowed state restores usable controls. Record taint or blocked-action errors.
8. At small screen sizes and different UI scales, check every checkbox, label,
   status and reset action remains readable and clickable. Move the native
   manager near screen edges and check that the attached section stays usable.
9. Run `/foreverui preview` and check the texture samples, then `/foreverui hide`.
   Use the Classic UI reset action and confirm the native presentation returns. Run
   `/foreverui inspect` and `/reload` to save the final report and reset choices.

If the addon cannot load due to an interface-version mismatch, run
`/dump select(4, GetBuildInfo())` in the beta so the package metadata can be
corrected. Report any Lua error together with the action that triggered it.

Record the module, toggle state, triggering action and actual client build for
each result. Keep raw SavedVariables local and publish only the relevant summary.
Edit Mode layout and lifecycle, border rendering, saved choices across real
reloads, native interactions, combat/taint behavior and other-addon compatibility remain untested
in the beta. Offline tests do not replace these checks.
