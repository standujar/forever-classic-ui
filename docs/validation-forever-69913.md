# Forever 1.60.1.69913 source inspection

Date: September 19, 2026. This record covers the source audit for the expanded
window-border modules. It does not establish in-game rendering, taint or combat
compatibility.

## Client and source comparison

The installed beta client is `1.60.1.69913`. The user's September 18 in-game
BlizzMove diagnostic also reported build `69913` and Interface `16001`.

The read-only extraction in `references/forever-69913` contains **4,393 files**
and **36,308,296 bytes**. A byte-for-byte comparison against the earlier
`references/forever-client` extraction from build `69893` found **zero added,
removed or changed files**. This comparison covers the extracted Lua, XML and
TOC selection, not the complete game client or its native implementation.

The local source trees and detailed extraction logs remain ignored and are not
distributed. Representative SHA-256 values, identical in both extractions:

| Source under `interface/addons/` | SHA-256 |
|---|---|
| `blizzard_sharedxml/mainline/shareduipaneltemplates.xml` | `5e57136067ecdcfae793e5b99f144ae0ed9ede6f74abae77fa20e897f6188203` |
| `blizzard_uipanels_game/camelot/characterframe.xml` | `92fa79cd4c2c262ef2be9284017d5433f4c8ed99e64202de5f931ec3f0cbca61` |
| `blizzard_professions/camelot/blizzard_professionsframe.xml` | `61119fa4df6dfec7a8ace42b61c4c9cd90b444b6d446a23ffb3f73a2c8c0effe` |
| `blizzard_uipanels_game/mainline/bankframetemplates.xml` | `325398e9a0d9d25538f1cea31a5911a8edb241a264e3e072562e6a99d5d892b8` |

## Expanded window coverage

Sixteen modules use the existing Classic **side and bottom border** treatment.
Their native top decoration, portrait, controls, dimensions and content layout
remain unchanged. This is not a complete Classic layout replacement.

| Module | Native root | Source evidence under `interface/addons/` |
|---|---|---|
| Quest window | `QuestFrame` | `blizzard_uipanels_game/mainline/questframe.xml:42` |
| Talents and spellbook | `PlayerSpellsFrame` | `blizzard_playerspells/camelot/blizzard_playerspellsframe.xml:4` |
| World map | `WorldMapFrame.BorderFrame` | `blizzard_worldmap/blizzard_worldmap.xml:85` |
| Character and skills | `CharacterFrame` | `blizzard_uipanels_game/camelot/characterframe.xml:403` |
| Professions | `ProfessionsFrame` | `blizzard_professions/camelot/blizzard_professionsframe.xml:10` and `blizzard_professionsframebase.xml:5` |
| Recipe inspection | `InspectRecipeFrame` | `blizzard_professions/blizzard_professionsinspectrecipe.xml:5` |
| Merchant | `MerchantFrame` | `blizzard_uipanels_game/mainline/merchantframe.xml:94` |
| Mailbox | `MailFrame` | `blizzard_mailframe/mailframe.xml:277` |
| Open mail | `OpenMailFrame` | `blizzard_mailframe/mailframe.xml:895` |
| Friends and social | `FriendsFrame` | `blizzard_friendsframe/camelot/friendsframe.xml:390` |
| NPC conversation | `GossipFrame` | `blizzard_uipanels_game/mainline/gossipframe.xml:34` |
| Trade | `TradeFrame` | `blizzard_uipanels_game/mainline/tradeframe.xml:179` |
| Auction house | `AuctionHouseFrame` | `blizzard_auctionhouseui/shared/blizzard_auctionhouseframe.xml:4` |
| Bank | `BankFrame` | `blizzard_uipanels_game/camelot/bankframe.xml:59` and `mainline/bankframetemplates.xml:667` |
| Trainer | `ClassTrainerFrame` | `blizzard_trainerui/mainline/blizzard_trainerui.xml:150` |
| Books and letters | `ItemTextFrame` | `blizzard_uipanels_game/mainline/itemtextframe.xml:3` |

The added roots inherit ordinary portrait or ButtonFrame chrome. Their shared
`NineSlice` is declared in
`blizzard_sharedxml/mainline/shareduipaneltemplates.xml:573`; its portrait layout
is in `blizzard_sharedxml/mainline/nineslicelayouts.lua:17`.
`SkillsFrame` is a content tab parented to `CharacterFrame`
(`blizzard_uipanels_game/camelot/skillsframe.xml:121`), so it uses the character
window's border choice rather than another checkbox.

Windows that load on demand are processed after their native addon loads.
Every target still requires a supported build, an inspectable and unprotected
root and border, and all five expected cosmetic textures. A missing named
border child is rejected; it does not fall back to another part of the window.
Unsupported, forbidden or protected structures are left native. Choices are
grouped under **Windows**, except the world map under **Maps**.

## Deliberately deferred targets

Bags and loot use `NineSliceUtil.UpdateCornerCropping` during layout
(`blizzard_uipanels_game/mainline/containerframe.lua:973` and
`mainline/scrollingflatpanel.lua:41`). Their short and dynamically resized
windows need their own geometry handling before reusing this border treatment.
BlizzMove's ability to move those windows does not establish that their Classic
styling is implemented here.

Unit frames and action bars/HUD still need separate restoration work. Nameplates
remain native and have no restoration setting.

## Runtime checks still required

Source compatibility enabled the known-build gate for both `69893` and `69913`.
It does not justify enabling arbitrary later builds. In the current client,
check each available window after loading, switching tabs, reopening and
disabling its styling. Verify original alpha restoration, unchanged controls,
combat deferral, and coexistence with the locally patched BlizzMove. Record
actual screenshots and Lua errors separately from this source inspection.

The `0.3.0-dev` package was installed in the local beta addon folder on September
19. Attempts to reload and inspect it through native UI automation were
interrupted by active user input, so no successful reload or in-game validation
is recorded. The installed build is ready for `/reload`, followed by
`/foreverui` to select Windows or Maps and test the individual windows.
