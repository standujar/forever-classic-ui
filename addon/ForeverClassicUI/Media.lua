-- SPDX-License-Identifier: MIT
local _, Addon = ...
local Media = Addon:RegisterModule("Media", {})

-- Paths and IDs are from the WoW community listfile; the local export manifest
-- records which files were actually extracted from the installed Era build.
-- No artwork is copied from the ClassicFrames addon.
Media.entries = {
    targetFrame = { native = "Interface\\TargetingFrame\\UI-TargetingFrame", fileDataID = 137026 },
    actionSlot = { native = "Interface\\Buttons\\UI-Quickslot2", fileDataID = 130841 },
    questTopLeft = { native = "Interface\\QuestFrame\\UI-QuestLog-TopLeft", fileDataID = 136804 },
    questTopRight = { native = "Interface\\QuestFrame\\UI-QuestLog-TopRight", fileDataID = 136805 },
    questBottomLeft = { native = "Interface\\QuestFrame\\UI-QuestLog-BotLeft", fileDataID = 136798 },
    questBottomRight = { native = "Interface\\QuestFrame\\UI-QuestLog-BotRight", fileDataID = 136799 },
    talentBorder = { native = "Interface\\TalentFrame\\UI-TalentFrame-BotLeft", fileDataID = 136963 },
    talentWarriorArms = { native = "Interface\\TalentFrame\\WarriorArms-TopLeft", fileDataID = 136983 },
}
Media.source = "native"

function Media:GetLocalPath(key)
    local entry = assert(self.entries[key], "Unknown media: " .. tostring(key))
    return "Interface\\AddOns\\" .. Addon.name .. "\\Media\\" .. string.lower(entry.native) .. ".blp"
end

function Media:SetSource(source)
    assert(source == "native" or source == "local", "Expected native or local media source")
    -- Select local before the first preview creation, and only after the
    -- corresponding Media/interface/... files have been packaged. Missing
    -- textures cannot be detected reliably out of game.
    self.source = source
end

function Media:Resolve(key)
    local entry = assert(self.entries[key], "Unknown media: " .. tostring(key))
    if self.source == "local" then return self:GetLocalPath(key) end
    return entry.native
end
