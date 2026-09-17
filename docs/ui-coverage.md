# Complete in-game Classic UI scope

The goal is to restore the Classic presentation of the entire in-game interface,
not only the frames listed by `/fcui inspect`. This scope was clarified on
September 17, 2026. The reference installation is Classic Era `1.15.9.69722`.

## What we currently have

- The local extraction contains 31,142 textures, 1,899 Lua files, 775 XML files
  and 292 TOC files available through the known file-name list.
- The repository's expanded reference pack contains 8,827 unchanged textures
  (170,042,504 bytes). It adds 938 textures for previously omitted UI families.
- The installed prototype samples 21 named globals and previews eight textures.
  Its latest saved report detects 19 globals. This is a diagnostic sample, not a
  count of all Classic frames or a completion percentage.
- No functional replacement module has been completed. Talent-window detection,
  sample rendering and report persistence have been tested on Era; see
  [the validation log](validation-era.md).

A frame is a runtime UI object with layout, children and behavior. Texture files,
XML definitions, Lua-created frames and runtime instances have different counts.
Pooled or anonymous frames and windows loaded on demand make a fixed list of
global names insufficient for an exhaustive inventory.

## Restoration checklist

All items below are in scope; unchecked means functional restoration is pending.

- [ ] Player, target, target-of-target, pet, party and raid frames.
- [ ] Health and resource bars, cast bars, combo points, buffs and debuffs.
- [ ] Nameplates and associated indicators.
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

## Native source evidence

The extracted `Blizzard_UIPanels_Game_Classic.toc` loads the mail, trade, petition,
tabard, pet stable and battleground sources, subject to its game-type conditions.
`Blizzard_CharacterFrame.toc` includes Vanilla pet paperdoll and Classic dressing
room sources. Vanilla crafting and profession sources are present in
`Blizzard_CraftUI` and `Blizzard_TradeSkillUI`. `Blizzard_FrameXML_Vanilla.toc`
loads the Vanilla world-state UI. The unit-frame and action-bar manifests cover
the Classic party, pet, combo and stance families. These are examples of real
native subsystems beyond the prototype's 21 probes.

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
Forever behavior remains unvalidated until its actual client can be inspected
and tested. No completion percentage for the full restoration is claimed.
