# Complete in-game Classic UI scope

The goal is to restore the Classic presentation of the in-game interface,
including unit frames, windows, maps and HUD controls. Nameplates are the explicit
exception: keep the target client's native nameplates and their behavior.
This scope was clarified on September 17, 2026. The reference installation is
Classic Era `1.15.9.69722`. The installed Forever beta `1.60.1.69893` has now been
inspected at source level; its in-game behavior still needs validation before
final adaptations are chosen.

## What we currently have

- The local extraction contains 31,142 textures, 1,899 Lua files, 775 XML files
  and 292 TOC files available through the known file-name list.
- The repository's expanded reference pack contains 8,827 unchanged textures
  (170,042,504 bytes). It adds 938 textures for previously omitted UI families.
- Prototype `0.1.1-dev` samples 25 named globals and previews eight textures.
  Diagnostics include new probes for `PlayerSpellsFrame`, `QuestMapFrame`, `SettingsPanel`
  and `FocusFrame`, plus native Settings API presence flags.
- The saved Era report from version `0.1.0-dev` detects 19 of its 21 probed globals.
  These are diagnostic samples, not a count of all Classic frames or a completion
  percentage.
- No functional replacement module has been completed. Talent-window detection,
  sample rendering and report persistence have been tested on Era; see
  [the validation log](validation-era.md).
- The first Forever beta diagnostic package is prepared for the local
  `_classic_beta_` client. Camelot sources identify `PlayerSpellsFrame` for talents
  and spellbook, `QuestMapFrame`/`WorldMapFrame` for maps and native Settings
  registration functions. [Beta runtime validation](validation-forever.md) is
  still pending.
- The integrated setup panel described below is planned and is not included in
  the current prototype.

A frame is a runtime UI object with layout, children and behavior. Texture files,
XML definitions, Lua-created frames and runtime instances have different counts.
Pooled or anonymous frames and windows loaded on demand make a fixed list of
global names insufficient for an exhaustive inventory.

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

## Integrated setup panel

Provide a settings panel integrated into the target client's native game options,
using the same panel styling and controls. Verify the integration points on the
actual Forever client before implementation. All labels and help text are English.

- Let players choose Classic styling independently for each implemented module.
  Checked modules use Classic styling; unchecked modules retain native Forever
  styling and behavior.
- Group checkboxes into **Unit Frames**, **Windows** and **HUD**. Unit-frame
  choices include player, target, pet, party and raid. Window choices include
  talents, quests, character, spellbook, maps, bags, bank, mail and professions,
  with further choices following the restoration checklist. HUD choices cover
  the other in-scope elements such as action bars and the minimap.
- Keep nameplates native, with no nameplate-restoration checkbox. Explain that
  boundary once in the panel rather than presenting it as a missing feature.
- Include an overall enable switch, save the player's selections across reloads
  and sessions, and provide a reset-to-defaults action. New modules start disabled
  until the player chooses to enable them.
- Offer working choices only for implemented, supported modules. The panel must
  not imply that an unchecked roadmap item already has a functional skin.
- Turning a module off restores its native presentation. Apply supported changes
  without a reload where possible; clearly indicate any required reload. Defer
  changes to protected frames while the player is in combat.

Build this panel as part of the first functional restoration milestone so that
each subsequent unit-frame, window or HUD module is individually configurable.

## Native source evidence

The extracted `Blizzard_UIPanels_Game_Classic.toc` loads the mail, trade, petition,
tabard, pet stable and battleground sources, subject to its game-type conditions.
`Blizzard_CharacterFrame.toc` includes Vanilla pet paperdoll and Classic dressing
room sources. Vanilla crafting and profession sources are present in
`Blizzard_CraftUI` and `Blizzard_TradeSkillUI`. `Blizzard_FrameXML_Vanilla.toc`
loads the Vanilla world-state UI. The unit-frame and action-bar manifests cover
the Classic party, pet, combo and stance families. These are examples of real
native subsystems beyond the original prototype's 21 probes.

## Completion criteria and limits

Each module needs verified artwork and layout, working native interactions,
load-on-demand handling, combat checks where applicable, scaling checks and a
recorded target-client build. Texture inclusion alone completes none of these.
Keep the target client's actual talent, map and gameplay data when restoring
Classic presentation.

The local extraction is limited to known file names and locally available data;
it is not a certified complete archive. Shared folders contain artwork from other
expansions, so each module must identify the textures its Classic sources use.
Zone-map tiles remain in the local export; the repository currently includes only
the top-level map artwork. Other omitted dependencies can be added when identified.

Login and character-selection screens are outside this in-game addon scope.
Forever runtime behavior remains unvalidated despite source inspection of the
installed beta client. No completion percentage for the full restoration is claimed.
