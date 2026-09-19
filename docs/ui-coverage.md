# Complete in-game Classic UI scope

The goal is to restore Classic presentation throughout the in-game interface:
unit frames, windows, maps and HUD controls. **Nameplates remain native.** Login
and character-selection screens are outside an in-game addon's scope.

The artwork reference client is Classic Era `1.15.9.69722`. The current beta
package supports Forever `1.60.1` builds `69893` and `69913`, with Interface
`16001` confirmed in the user's build 69913 logs. See the [69913 validation
record](validation-forever-69913.md) for current source evidence and runtime
checks, and the [earlier record](validation-forever.md) for dated observations.

## Current implementation

Development version **0.3.0-dev** has grouped controls in native Edit Mode and
**sixteen partial side-and-bottom border skins**. No complete Classic window,
unit frame or HUD replacement has been completed.

| Group | Implemented partial skins |
| --- | --- |
| Windows | Quest interactions; talents/spellbook; character/skills; professions; recipe inspection; merchant; mailbox; open mail; friends/social; NPC conversations; trade; auction house; bank; trainer; books/letters |
| Maps | World map |
| Unit frames | No implemented modules; Coming soon |
| Action bars & HUD | No implemented modules; Coming soon |

The skins preserve native top decoration, portraits, titles, buttons, dimensions,
content layout and gameplay. Bags and loot windows need separate treatment for
their dynamic borders; they have no skin yet. Local BlizzMove fixes for moving
windows belong to that separate addon and do not count as Classic restoration.

Skins require a supported build and the inspected frame shape. Protected or
forbidden frames are rejected; changes wait until combat ends. Switching a skin
off restores its captured native border alphas. Late-loaded and reopened windows
are handled by the engine. The required dialog-border BLP is included in every
package. Actual rendering, interactions and combat behavior for this version
still need client validation.

This partial artwork change leaves every full restoration item below unchecked.

## Restoration checklist

All items below are in scope; unchecked means functional restoration is pending.

- [ ] Player, target, target-of-target, pet, party and raid frames.
- [ ] Health and resource bars, cast bars, combo points, buffs and debuffs.
- [ ] Action bars, pet actions, stances, paging, XP and reputation bars.
- [ ] Micro menu, bag buttons and other HUD controls.
- [ ] Minimap, tracking, clock, world map and flight map.
- [ ] Character equipment, statistics, skills and reputation panels.
- [ ] Other-player inspection and item dressing-room previews.
- [ ] Talents and spellbooks, including pet-related panels where applicable.
- [ ] Quest log, quest conversations, gossip and readable books or letters.
- [ ] Bags, bank, item tooltips and comparison tooltips.
- [ ] Loot windows, group rolls and loot history.
- [ ] Merchants, repairs and class or profession trainers.
- [ ] Professions, crafting, recipes and enchantment interfaces.
- [ ] Player trade and auction house.
- [ ] Inbox, opened mail, attachments and composing mail.
- [ ] Friends, ignore list, who list, guild and raid management.
- [ ] Guild creation, petitions and tabard design.
- [ ] Pet character panel, stable and pet management.
- [ ] Honor, battleground queues, scoreboards and world-state displays.
- [ ] Chat, chat tabs, menus, notifications and text entry.
- [ ] Game menu, settings, keybindings, macros and addon settings surfaces.
- [ ] Confirmation dialogs, shared buttons, scrollbars, tabs and borders.
- [ ] Tutorials, help, durability warnings and remaining in-game utility windows.

This checklist organizes the work; it is not a claim that every individual frame
or asset has already been identified. Split each family into concrete modules as
its native source and behavior are inspected. Additional Classic windows found
during that process belong in scope.

## Native Forever nameplates

Nameplates are the indicators above characters in the game world. Preserve their
native Forever appearance, layout and behavior, including their attached
indicators. They are excluded from restoration. Player, target, pet, party and
raid unit frames remain in scope; they are distinct from nameplates.

Reference textures and diagnostic coverage do not expand this boundary. Review
the actual Forever client before selecting hooks or modifying shared templates,
so changes to unit frames and windows do not inadvertently restyle nameplates.

## Grouped Edit Mode choices

Open **Escape → Edit Mode**, `/foreverui` or `/foreverui edit` outside combat.
The attached Classic UI section follows the manager's visibility and movement.
`/foreverui settings` remains an alias; there is no separate Settings category.

- **Classic everywhere** selects every group and clears module exceptions. Only
  implemented, supported modules apply; group defaults also select future modules.
- **Restore Forever** disables restoration and clears group choices and exceptions.
- Group checkboxes allow Windows or Maps to be selected in one action. Groups
  without modules show Coming soon and are disabled.
- **Customize** expands a group's individual options. A dash marks mixed choices.
  Talents and spellbook share one option; character and skills share another.
- Fresh settings start off. Upgrades preserve existing module selections. Once
  chosen, a group default is inherited by future modules unless an explicit
  module choice overrides it. This also applies to future unit-frame and HUD
  modules after Classic everywhere is selected.
- Choices save immediately in `ForeverReframedDB.settings` and apply across all
  Edit Mode layouts. Native Save/Revert does not change addon settings.

Keep the difference between available partial skins and future restoration
visible. No nameplate toggle is offered. Validate group selection, exceptions,
reloads, layout switching, native Save/Revert and combat behavior in the client.

## Reference resources and evidence

The local Era extraction contains 31,142 textures, 1,899 Lua files, 775 XML files
and 292 TOC files available through the known file-name list. The repository's
reference pack includes 8,827 unchanged textures (170,042,504 bytes), with
provenance and hashes. Texture inclusion is research material, not a functional
restoration result.

The historical Era report from `0.1.0-dev` detected 19 of 21 probed globals.
That version's texture preview and report persistence were tested on Era; see
[the Era validation log](validation-era.md). Later diagnostics add selected
window and API probes, but no probe count represents every Classic frame.

Fresh extraction of the installed Forever build 69913 recovered 4,393 UI source
files; their contents match the build 69893 extraction. The active Camelot
manifests and inherited shared definitions identify the native windows used by
the expanded skins. Source equality does not establish equal runtime behavior.

A frame is a runtime object with children, layout and behavior. Texture files,
XML definitions, Lua-created frames and runtime instances have different counts.
Pooled or anonymous frames and windows loaded on demand make a fixed global-name
list insufficient for an exhaustive inventory.

## Completion criteria

Each module needs verified artwork and layout, working native interactions,
load-on-demand handling, combat checks where applicable, scaling checks and a
recorded target-client build. Preserve Forever's talent, map and gameplay data.
Mock tests do not establish in-game behavior or compatibility with other addons.

Extraction is limited to known names and locally available data, not a certified
complete archive. Shared folders include artwork from other expansions; identify
which textures the Classic sources actually use. Full exports and zone-map tiles
remain local. Missing dependencies can be added when their use is established.

No completion percentage for the full restoration is claimed.
