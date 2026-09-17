# Forever Classic UI — Era workshop

An original prototype targeting the locally installed **Classic Era 1.15.9 /
TOC 11509** client. The code and tests are ready; execution and rendering in the
game still need validation. Forever compatibility is unverified.

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

The tests use Lua 5.1 through Lupa with minimal substitutes for the game's APIs.
They verify report collection, SavedVariables preservation during simulated
reload, combat restrictions and absence of personal or combat data reads.
Rendering, taint and actual SavedVariables disk writes require in-game testing.

The original addon code is MIT-licensed; see the repository's root `LICENSE`.
This license does not cover Blizzard artwork or third-party addon code.
