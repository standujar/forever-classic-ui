# Classic UI - Forever Reframed — Development workshop

Version **0.3.0-dev** adds grouped Edit Mode controls and sixteen experimental
Classic side-and-bottom window skins. The goal is the full Classic-style
in-game interface, except nameplates. Complete window layouts, unit frames and
HUD restoration remain in development.

The source TOC targets **Classic Era 1.15.9 / Interface 11509** for diagnostics
and texture previews. The separate Forever package targets **1.60.1, builds
69893 and 69913 / Interface 16001**. The user's build 69913 logs confirm that
Interface number. The new grouped controls and skins still need in-game testing.

## Edit Mode options

Outside combat, choose **Escape → Edit Mode**, `/foreverui` or `/foreverui edit`.
The Classic UI section follows the native Edit Mode window. `/foreverui settings`
is a compatibility alias; there is no separate Settings category.

**Classic everywhere** selects all groups and clears individual exceptions.
**Restore Forever** disables restoration and clears selections. Four group rows
organize the options: **Unit frames**, **Windows**, **Maps**, and **Action bars &
HUD**. The two groups without implemented modules show **Coming soon**. Expand
**Customize** within Windows or Maps to make exceptions; a dash indicates mixed
selections. Talents and spellbook share one option, as do character and skills,
because each pair shares its native window border.

Fresh settings start disabled. Existing `ForeverReframedDB` choices are preserved.
A group default applies to future modules unless an individual choice overrides
it. Selecting Classic everywhere also opts into future unit-frame and HUD
modules. Choices persist immediately across all layouts; native **Save** and
**Revert** do not undo them. The game writes SavedVariables to disk on reload or
logout.

## Partial window skins

| Module ID | Native window | Group |
| --- | --- | --- |
| `quest_window` | `QuestFrame` | Windows |
| `player_spells_window` | `PlayerSpellsFrame`: talents and spellbook | Windows |
| `character_window` | `CharacterFrame`: character and skills | Windows |
| `professions_window` | `ProfessionsFrame` | Windows |
| `inspect_recipe_window` | `InspectRecipeFrame` | Windows |
| `merchant_window` | `MerchantFrame` | Windows |
| `mail_window` | `MailFrame` | Windows |
| `open_mail_window` | `OpenMailFrame` | Windows |
| `social_window` | `FriendsFrame` | Windows |
| `gossip_window` | `GossipFrame` | Windows |
| `trade_window` | `TradeFrame` | Windows |
| `auction_house_window` | `AuctionHouseFrame` | Windows |
| `bank_window` | `BankFrame` | Windows |
| `trainer_window` | `ClassTrainerFrame` | Windows |
| `item_text_window` | `ItemTextFrame` | Windows |
| `world_map_window` | `WorldMapFrame.BorderFrame` | Maps |

These replace only side and bottom border artwork. The native top decoration,
portrait, title, buttons, dimensions, content layout and gameplay remain intact.
Bags and loot require separate treatment for their dynamic borders and have no
skin yet. The local BlizzMove movement patches are separate from this addon.

Skins require a supported version/build/Interface and the expected frame shape.
Protected or forbidden frames are rejected. Applying and reverting wait until
combat ends. Disabling restores the captured native border alphas. The engine
handles windows that load or reopen later; those paths still require actual
client validation.

## Installation and first test

From the repository root:

```sh
python3 tools/package_addon.py --target forever-beta
```

Close the beta and extract the archive's `ForeverReframed` folder into its
`Interface/AddOns` directory. On macOS this is normally
`/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/`.
The archive includes the required border texture; copying only Lua files is
incomplete. `--with-preview-media` adds eight optional reference samples.

After enabling the addon, open Edit Mode and check the default-off state on a
fresh installation or preserved selections after an upgrade. Select **Windows**,
open the relevant windows, and use **Customize** for an exception. Verify native
buttons and contents, then use **Restore Forever** to confirm the native borders
return. Check reopen, reload, layout switching, UI scale and combat behavior.
Native Save/Revert must not alter the addon choices.

Run `/foreverui inspect` and `/reload` to save a local diagnostic report. Keep
personal SavedVariables out of public reports. The repository's
`docs/validation-forever-69913.md` records the current source evidence and
outstanding runtime checks.

Versions before `0.2.2-dev` used a different development namespace. Disable that
old addon copy before enabling `ForeverReframed`; its settings are not imported.

## Commands and reports

| Command | Behavior |
| --- | --- |
| `/foreverui` or `/foreverui edit` | Opens native Edit Mode outside combat |
| `/foreverui settings` | Alias for the same controls |
| `/foreverui status` | Summarizes client and UI capabilities |
| `/foreverui inspect` | Includes frame protection and restoration states |
| `/foreverui preview` | Toggles reference textures, not functional windows |
| `/foreverui hide` | Closes the preview |

The preview can be dragged and closed with Escape. It closes when combat starts
and cannot be opened during combat. It leaves native game frames unchanged.

`ForeverReframedDB.lastReport` contains client/build/Interface, selected API and
frame capabilities, and restoration settings/status. It contains no character
names, realms, account identifiers or combat data. Load-on-demand windows may
appear absent until opened. Probe counts are diagnostic samples, not restoration
coverage.

## Extension points

Lua files receive `local addonName, Addon = ...`. Register a module with
`Addon:RegisterModule(name, module)` and retrieve it with `Addon:GetModule(name)`.
Optional `Initialize()` methods run after SavedVariables load. Add new Lua files
to the TOC before using them.

Register selectable styling through `Addon:GetModule("Restoration"):Register(descriptor)`.
Each descriptor has a unique `id`, a `label`, `description`, `group`, and
`IsSupported`, `Apply`, `Revert` methods. Valid group IDs are `unit_frames`,
`windows`, `maps` and `hud`. Methods receive the descriptor as `self` and return
`true`, or `false, reason`. `Apply` may return `false, "waiting"` for a window
that has not loaded. `Revert` must restore captured state and allow retries
following partial failures. The engine attempts rollback after a failed apply
and retains ownership until revert succeeds.

Group defaults and explicit module choices are stored separately. An explicit
boolean in `settings.modules[id]` overrides `settings.groups[group]`; otherwise
the module inherits its group. The master `settings.enabled` gate controls
whether selected modules apply. This preserves existing per-module choices
without enabling newly added modules unless their group was selected.

| Restoration method | Effect |
| --- | --- |
| `SetAll(true)` | Enables restoration, selects all group defaults, clears exceptions |
| `SetAll(false)` or `Reset()` | Disables restoration and clears group choices and exceptions |
| `SetGroupSelection(group, boolean)` | Changes a group default and clears its registered module exceptions; selecting enables restoration |
| `SetSelection(id, boolean)` | Sets an explicit module exception |
| `SetEnabled(boolean)` | Changes the master gate while retaining choices |
| `GetSelection(id)` | Resolves the module choice without the master gate |
| `IsSelected(id)` | Resolves the choice including the master gate |
| `GetGroupSelection(group)` | Returns `none`, `all` or `mixed` for registered modules |

Register no nameplate restoration descriptors. Add required BLP paths to
`RequiredMedia.txt` so packaging includes their artwork. Modules must stay
reversible and must not bypass frame protection or combat restrictions.

`Media:Resolve(key)` returns a native texture by default. For a packaged local
preview, call `Media:SetSource("local")` before creating it. A resolved path does
not establish availability or correct rendering; verify in game.

`OptionalDeps: ClassicFrames` permits coexistence but does not port that addon
or include its code. Third-party integration remains subject to its license.

## Verification

From the repository root:

```sh
tools/python-env/bin/python tests/run.py
tools/python-env/bin/python -m unittest discover -s tests -p 'test_*.py'
```

The 47 Lua addon tests and 21 Python release-tool tests pass. The Lua tests use
simulated WoW APIs through Lupa. They cover saved choices,
group inheritance and exceptions, apply/revert, Edit Mode integration and
combat deferral. Passing them does not confirm actual beta rendering, secure
interactions, taint behavior or compatibility with other addons.

Original code is MIT-licensed. That license does not cover Blizzard artwork
or third-party addon code; see the repository's `LICENSE` and `NOTICE.md`.
