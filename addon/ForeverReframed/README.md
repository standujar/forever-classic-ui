# Classic UI - Forever Reframed — Development workshop

**Project goal: restore the entire Classic Era in-game interface in Forever,
except nameplates.** This includes unit frames, action bars, minimap, talents,
quests, world and flight maps, character panels, bags, banks, professions, mail,
auctions, social panels and shared controls. Each area is intended to have its
own choice in native Settings. Nameplates retain Forever's appearance and behavior.

An original prototype, version **0.2.2-dev**. The source TOC targets
**Classic Era 1.15.9 / Interface 11509**. A separate package targets the inspected
**Forever beta 1.60.1.69893** with candidate Interface **16001**, inferred from the
client version and pending confirmation by in-game `GetBuildInfo()`.

Earlier Era tests confirmed addon loading, sample rendering and report
persistence. The new settings panel and window-border modules have only been
prepared and tested offline. Forever runtime behavior remains unvalidated while
beta access is unavailable.

The implemented styling currently covers only the three partial window borders
listed below. Full Classic windows, unit frames and the remaining HUD are still
planned work. Version `0.2.2-dev` uses **`/foreverui`** as its only addon command.
It introduces the distinct `ForeverReframed` folder and namespace, with fresh
`ForeverReframedDB` settings. Older development settings and reports are left
untouched and are not imported. Disable this project's previous development copy
before enabling the renamed addon.

## Settings and experimental borders

Open `/foreverui` or `/foreverui settings` outside combat to access the addon panel in the
game's native Settings. The master switch and all module checkboxes default to
off. The panel includes module status messages, **Reset to defaults** and
**Texture preview**. Selections persist in `ForeverReframedDB.settings`.

| Module ID | Native window |
| --- | --- |
| `quest_window` | `QuestFrame`: quest interaction window |
| `player_spells_window` | `PlayerSpellsFrame`: combined talents and spellbook |
| `world_map_window` | `WorldMapFrame.BorderFrame`: world map |

These modules replace only the side and bottom border artwork with a bundled
Classic texture. They preserve the native top decoration, portrait, title,
buttons, dimensions, content layout and gameplay. They do not restore complete
Classic windows or talent trees. Unit-frame and HUD restoration is not implemented;
nameplates are excluded from restoration and have no checkbox.

The modules require exact version `1.60.1`, build `69893`, candidate Interface
`16001` and the expected frame structure. Protected or forbidden windows are
rejected. Applying or reverting changes waits until combat ends. Disabling a
module restores captured native border alphas, and windows that load or reopen
later are handled by the restoration engine. These behaviors still need actual
beta testing.

## Beta installation and first test

From the repository root, run `python3 tools/package_addon.py --target forever-beta`.
With the beta closed, extract the resulting archive's `ForeverReframed` folder
into `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/`, then
start the beta and enable the addon once beta access is available.

Open `/foreverui` and confirm the default-off state. Open a quest interaction, talents,
the spellbook and the map before running `/foreverui inspect`. Enable the master switch
and test one window checkbox at a time, including turning it off again. Then use
**Reset to defaults** and, while out of combat, run `/foreverui preview`, `/foreverui hide`,
`/foreverui inspect` and `/reload`. The reload writes settings and the report locally;
keep raw SavedVariables out of public reports. The repository's
`docs/validation-forever.md` tracks the outstanding checks.

The default package target is `era`. Both packages include the one BLP listed in
`RequiredMedia.txt` for window borders; install the archive rather than copying
the source directory alone. `--with-preview-media` adds eight reference samples,
for nine BLPs total. The preview uses native textures by default, while window
borders use the required local texture.

## Commands

- `/foreverui` or `/foreverui settings`: open the native Settings addon panel outside combat.
- `/foreverui status`: summarize client and UI capabilities; hold the report in memory.
- `/foreverui inspect`: include frame presence/protection and restoration states.
- `/foreverui preview`: toggle native portrait, action button, quest log and talent
  texture samples. These samples are not functional unit frames or talent trees.
- `/foreverui hide`: close the preview.
- `/reload`: use the game's command to write SavedVariables to disk.

Drag the preview to move it; press Escape to close it. It closes when combat
starts and does not reopen automatically. It cannot be opened during combat.
The preview itself does not modify native game interface elements. Window
styling is controlled separately through the settings panel and starts disabled.

`ForeverReframedDB.lastReport` contains only the client version, build number,
build date, interface number, project, locale, presence of selected APIs and
protection status of named UI frames, plus settings/restoration status. It
collects no character names, realms, account identifiers or combat data. Frames
that load on demand may appear absent until their window has been opened.

This version probes 25 named frames, including `PlayerSpellsFrame`,
`QuestMapFrame`, `SettingsPanel` and `FocusFrame`, and reports native Settings
registration API presence and restoration states. The earlier Era result of
19/21 belongs to version `0.1.0-dev`; probe counts are not restoration progress.

## Extension points

Lua files receive `local addonName, Addon = ...`. Register a new module with
`Addon:RegisterModule(name, module)` and retrieve it with
`Addon:GetModule(name)`. An optional `Initialize()` method runs after
SavedVariables load. Add new Lua files to the TOC before using them.

For selectable styling, call `Addon:GetModule("Restoration"):Register(descriptor)`
after the restoration engine is available. A descriptor has a unique `id`,
`label`, `description`, `group`, and methods `IsSupported`, `Apply`, `Revert`.
Methods receive the descriptor as `self` and return `true` on success or
`false, reason` on failure. `Apply` may return `false, "waiting"` when a target
window has not loaded. `Revert` must restore the captured native state and support
retries after partial failures. The engine attempts cleanup after failed apply
calls and retains ownership until a revert succeeds.

Use `SetEnabled(boolean)`, `SetSelection(id, boolean)` and `Reset()` on the
restoration engine to change persisted choices and reconcile the presentation.
Modules start off; `Reset()` clears selections and disables the master switch.
Nameplate restoration descriptors are not accepted. Register required local BLP
paths in `RequiredMedia.txt` so packaging includes their artwork.

`Media:Resolve(key)` returns a native texture by default. After packaging local
exports under `Media/interface/...`, call `Media:SetSource("local")` before
the preview is created to select those copies. Resolving a path does not
guarantee texture availability or rendering: verify the result in game.

`OptionalDeps: ClassicFrames` allows the two addons to load together. This
prototype does not call ClassicFrames functions or include its code. Integration
or porting remains separate work subject to that addon's license.

## Verification

From the project root:

```sh
tools/python-env/bin/python tests/run.py
```

The 27 tests use Lua 5.1 through Lupa with substitutes for the game's APIs. They
exercise diagnostics, saved choices, module application/reversion, settings
registration and deferred changes. Earlier Era rendering and report disk writes
were confirmed separately. The new settings panel, border rendering, reload
persistence, interactions, taint and combat behavior still require beta testing;
passing mock tests does not validate those behaviors in the game.

The original addon code is MIT-licensed; see the repository's root `LICENSE`.
This license does not cover Blizzard artwork or third-party addon code.
