# Forever Classic UI — Diagnostic workshop

An original diagnostic prototype, version **0.1.1-dev**. The source TOC targets
**Classic Era 1.15.9 / Interface 11509**. A separate package targets the inspected
**Forever beta 1.60.1.69893** with candidate Interface **16001**, inferred from the
client version and pending confirmation by in-game `GetBuildInfo()`.

Era addon loading, texture rendering and SavedVariables persistence have been
confirmed in game. Forever runtime behavior remains unvalidated. The addon
does not yet restore native frames or include the planned module setup panel.

## Beta installation and first test

From the repository root, run `python3 tools/package_addon.py --target forever-beta`.
With the beta closed, extract the resulting archive's `ForeverClassicUI` folder
into `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/`, then
start the beta and enable the addon.

Open talents, the spellbook and the map before running `/fcui inspect`. Then,
while out of combat, run `/fcui preview`, `/fcui hide` and `/reload` in that order.
The reload writes the report locally; keep raw SavedVariables out of public
reports. The repository's `docs/validation-forever.md` tracks this beta test.

The default package target is `era`. Both packages use native textures by
default; `--with-preview-media` optionally bundles the eight reference samples.

## Commands

- `/fcui status`: summarize client and UI capabilities; hold the report in memory.
- `/fcui inspect`: collect the same report and list frame presence/protection.
- `/fcui preview`: toggle native portrait, action button, quest log and talent
  texture samples. These samples are not functional unit frames or talent trees.
- `/fcui hide`: close the preview.
- `/reload`: use the game's command to write SavedVariables to disk.

Drag the preview to move it; press Escape to close it. It closes when combat
starts and does not reopen automatically. It cannot be opened during combat.
The addon does not hide, move or modify any native game interface elements.

`ForeverClassicUIDB.lastReport` contains only the client version, build number,
build date, interface number, project, locale, presence of selected APIs and
protection status of named UI frames. It collects no character names, realms,
account identifiers or combat data. Frames that load on demand may appear
absent until their window has been opened.

This version probes 25 named frames, including `PlayerSpellsFrame`,
`QuestMapFrame`, `SettingsPanel` and `FocusFrame`, and reports native Settings
registration API presence. The earlier Era result of 19/21 belongs to version
`0.1.0-dev`; probe counts are not restoration progress.

## Extension points

Lua files receive `local addonName, Addon = ...`. Register a new module with
`Addon:RegisterModule(name, module)` and retrieve it with
`Addon:GetModule(name)`. An optional `Initialize()` method runs after
SavedVariables load. Add new Lua files to the TOC before using them.

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

The eight tests use Lua 5.1 through Lupa with minimal substitutes for the game's APIs.
They verify report collection, SavedVariables preservation during simulated
reload, combat restrictions and absence of personal or combat data reads.
Era rendering and actual SavedVariables disk writes are confirmed separately.
Taint, combat behavior and all Forever runtime behavior still require in-game
testing; passing mock tests does not validate those behaviors.

The original addon code is MIT-licensed; see the repository's root `LICENSE`.
This license does not cover Blizzard artwork or third-party addon code.
