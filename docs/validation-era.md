# In-game smoke tests

Date: September 17, 2026. Addon: `0.1.0-dev`.

The commands below describe the historical test. Current versions use
`/foreverui`; the earlier command was removed in `0.2.1-dev`.

Client: Classic Era `1.15.9`, build `69722`, Interface `11509`, project ID `2`,
locale `enUS`. Evidence consists of user-provided in-game screenshots and the
addon's subsequently saved `ForeverClassicUIDB.lastReport`.

## Confirmed

- The addon loads and `/fcui inspect` prints a client/frame report.
- `/fcui preview` displays the native target-frame border, action slots, four
  quest-log fragments, a talent-window border and the Arms background sample.
- The report persists to the addon's SavedVariables file. Its content was read
  back from disk after the test.
- The first saved report contains 18 of the 21 probed frame globals and identifies
  eight as protected. After opening talents, a follow-up screenshot and saved
  report show 19 of 21 globals present, with eight still protected. These describe
  those snapshots, not every possible UI state.
- Both `issecretvalue` and `C_Secrets` are present in this Era client. Their
  presence alone does not establish which combat restrictions apply.

The quest-log pieces are deliberately separated in this diagnostic preview.
This verifies individual texture rendering, not a restored functional window.

## Follow-up: talent window

`TalentFrame` and `PlayerTalentFrame` were absent in the first report.
The extracted `Blizzard_TalentUI_Vanilla.toc` declares `LoadOnDemand: 1` and
loads the Classic talent UI sources. Their XML creates `PlayerTalentFrame`;
no global `TalentFrame` is expected from that module. An absent frame before
that module loads does not establish an incompatibility.

`PartyMemberFrame1` is also a legacy global probe. The current party UI creates
pooled member frames under `PartyFrame.MemberFrame1` and subsequent parent keys.
The missing legacy global is therefore expected for this client.

The follow-up screenshot at 14:51:25 confirms that `PlayerTalentFrame` is present
and unprotected after opening talents and running `/fcui inspect`. The two legacy
global probes, `TalentFrame` and `PartyMemberFrame1`, remain absent as expected.
This verifies detection after the talent module loads; it does not validate
restyling the window or replacing talent interactions.

After the user reloaded, the SavedVariables file was updated at 14:53:27 local
time. Reading it back confirms 19 globals present and eight protected, with
`PlayerTalentFrame` present, unprotected and not forbidden. The two legacy globals
remain absent. The follow-up result is now confirmed on disk as well as in the
screenshot.

## Not yet validated

- Behavior of the preview at combat entry, Escape handling and dragging in game.
- Other UI scales or resolutions, or interaction with additional UI addons.
- Any replacement of native gameplay frames or a functional talent-tree module.
- Any behavior on the Forever client.

The seven Lua 5.1 mock tests cover separate automated behavior; they are not
substitutes for the outstanding in-game checks. Raw SavedVariables and user
screenshots remain local and are not included in this report.
