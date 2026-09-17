# Classic Frames audit

Verified on September 17, 2026. Static review of the public repository and the author's listing; no WoW runtime tests were performed for this audit.

## Pinned reference

- Repository: <https://github.com/Daenarys/ClassicFrames>.
- Local reference: `references/ClassicFrames`; an unchanged nested Git checkout, not installed in WoW and excluded from the public repository and release packages.
- Branch: `main`.
- Commit: `55b66cc4b45e0a581b1a8d388980620f59f4f491` — `bump version`, September 8, 2026 at 09:22:54 +0200.
- [Exact TOC](https://github.com/Daenarys/ClassicFrames/blob/55b66cc4b45e0a581b1a8d388980620f59f4f491/ClassicFrames/ClassicFrames.toc): version `3.82`, Interface `120100`, author `luckfore`.
- The [CurseForge listing](https://www.curseforge.com/wow/addons/classic-frames) confirms a Retail 12.1.0 release on September 8, 2026. It separately lists MoP Classic version 1.21, dated December 9, 2025. That is not the cloned version.

This snapshot targets Retail. Compatibility with Classic Era or the Forever client has not been established. Changing the TOC Interface number alone does not port the addon.

## License and reference use

The CurseForge listing states **All Rights Reserved**. The cloned commit contains no LICENSE or README granting permission to reuse the main code. Public source availability does not grant permission to redistribute an adaptation.

**This project's MIT license covers its original code only. It does not apply to Classic Frames, its assets, or Blizzard artwork.** Keep Classic Frames as a local reference with its provenance intact. Write our code in a separate addon and exclude `references/ClassicFrames` from the public repository and distributed packages. Embedded libraries have their own provenance and do not determine the license of Classic Frames itself. Blizzard textures also require provenance separate from the addon code.

Any experimental local patch should remain separate from the original snapshot. Private use should not be described as permission from the author. Before distributing reused code, obtain authorization or choose a suitably licensed base.

## Structure and coverage

The repository contains 109 Lua files, including 105 under `skins`, 11 XML files, and 2 BLP files. All 106 TOC entries resolve to existing files.

Loading proceeds through libraries in `embeds.xml`, global styling functions in `skins/ApplySkin.lua`, window modules, then unit frames and class resources. This snapshot has no central module loader, compatibility manifest by client, or documented extension contract.

Functions such as `ApplyCloseButton`, `ApplyTitleBg`, `ApplyNineSlicePortrait`, `ApplyScrollBarHybrid`, and `ApplyBottomTab` are globals rather than a versioned API. A companion can detect their presence, but relying on them couples it to Classic Frames internals.

| Area | Representative files | Behavior |
| --- | --- | --- |
| Windows and controls | `ApplySkin.lua`, `Character.lua`, `Bags.lua`, `Bank.lua`, `Merchant.lua`, `Mail.lua` | Changes textures, borders, portraits, buttons, tabs, sizes, and positions of existing frames |
| Quests and maps | `Quests.lua`, `QuestLog.lua`, `WorldMap.lua`, `ZoneMap.lua` | Skins and rearranges the Retail UI; does not automatically restore the Vanilla quest log structure |
| Talents and spellbook | `Talents.lua`, `ProfessionsBook.lua` | Skins existing Retail systems; `Talents.lua` expects `Blizzard_PlayerSpells`, not the Vanilla talent tree |
| Unit frames | `unitframes/PlayerFrame.lua` and XML, `TargetFrame.lua` and XML, `PartyFrame.lua`, `PetFrame.lua`, `BossFrame.lua` | Modifies native frames and creates auxiliary bars and regions |
| Other HUD elements | `Minimap.lua`, `MirrorTimers.lua`, `ObjectiveTracker.lua`, `Buffs.lua`, `CastBar.lua` | Minimap, quest tracker, timers, buffs, and cast bar |
| Expansion systems | `Delves.lua`, `Catalyst.lua`, `WorkOrders.lua`, `classbars/*` | Numerous Retail-specific integrations to exclude from a focused Era adaptation |

The TOC contains no dedicated main action bar module. Classic Frames alone therefore does not fully restore the Vanilla bottom bar with action buttons, micro-menu, and bags.

## Dependencies and assets

- The only declared optional dependency is `SexyMap`. The minimap module exits when that addon is loaded.
- Embedded libraries: `LibStub`, `CallbackHandler-1.0`, `LibDataBroker-1.1`, and `LibDBIcon-1.0`.
- The TOC declares no required dependencies or `SavedVariables`.
- Bundled textures: `icons/MiniMap-TrackingBorder.blp` and `icons/UIFrameDiamondMetalHeader.blp`.
- Most artwork uses client `Interface\\...` paths or atlases. Reuse resources already present in the target client first, then identify specific missing assets.

## Checks required before a port

1. **Frame hierarchy.** [PlayerFrame.lua, line 100](https://github.com/Daenarys/ClassicFrames/blob/55b66cc4b45e0a581b1a8d388980620f59f4f491/ClassicFrames/skins/unitframes/PlayerFrame.lua#L100) directly accesses `PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer`. A different hierarchy will cause a loading error.
2. **Partial guards.** [Quests.lua, line 33](https://github.com/Daenarys/ClassicFrames/blob/55b66cc4b45e0a581b1a8d388980620f59f4f491/ClassicFrames/skins/Quests.lua#L33) directly uses `QuestScrollFrame.ScrollBar`, although earlier sections guard the presence of other frames.
3. **Deferred loading.** Some modules listen for `ADDON_LOADED`; others run immediately. Our loader must handle both already loaded and demand-loaded components, applying each module once.
4. **Minimap.** [Minimap.lua, line 11](https://github.com/Daenarys/ClassicFrames/blob/55b66cc4b45e0a581b1a8d388980620f59f4f491/ClassicFrames/skins/Minimap.lua#L11) assumes `MinimapCluster.BorderTop` exists. The rest of the module depends on many Retail child frames.
5. **Talents.** [Talents.lua, line 4](https://github.com/Daenarys/ClassicFrames/blob/55b66cc4b45e0a581b1a8d388980620f59f4f491/ClassicFrames/skins/Talents.lua#L4) waits for `Blizzard_PlayerSpells`. Vanilla data and layout must be studied in the target client's code; replacing borders does not recreate their behavior.
6. **Combat and interaction.** Test all anchor, parent, and visibility changes on protected frames. Our structural changes must be deferred until outside combat. A post-hook does not remove the need to check the modified frame's restrictions.

## Recommended approach: independent companion addon

Build `ForeverClassicUI` with its own namespace, build identification, and capability registry. Use diagnostic mode on unknown builds, enabling each module only after checking its required frames and methods.

An optional adapter can supplement an already loaded, compatible Classic Frames version. Declaring `OptionalDeps: ClassicFrames` requests the loading order, but **does not protect the client from errors inside Classic Frames itself**. Do not automatically bundle or enable the Retail version in Era.

The least coupled integration point is the visual result on Blizzard frames: apply our settings after `PLAYER_LOGIN` or the relevant Blizzard component loads, then use targeted hooks only where the client resets their appearance. Avoid replacing Classic Frames' global `Apply*` functions. A first standalone module needs no access to these internals.

Start with texture and frame diagnostics, inspect the actual Forever client before final adaptation, then build a minimal skin for an unprotected window. Add Classic player/target frames and action bars afterward, with combat testing. The restoration scope includes windows, world and flight maps, minimap and the remaining HUD; nameplates alone stay as provided by the Forever client. This produces a testable local companion without first porting all 105 skin files.

Patching Classic Frames would become preferable only if the target client actually shares its frame hierarchies and an authorized fork is the intended maintenance model. That would require replacing the monolithic TOC with module profiles, isolating styling functions, and handling deferred loading. It is more than a version-number change.

## Verification performed

- Cloned the public repository and recorded its commit and TOC.
- Confirmed the reference checkout has no local modifications.
- Verified that all TOC entries exist.
- Read dependencies and shared, quest, talent, minimap, Edit Mode, and unit frame modules.
- Checked the author's published license on September 17, 2026.
- No game launch, installation, publication, or in-game test was performed for this audit.
