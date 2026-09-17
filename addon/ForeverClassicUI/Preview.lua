-- SPDX-License-Identifier: MIT
local _, Addon = ...
local Preview = Addon:RegisterModule("Preview", {})

local function label(parent, text, x, y, width, template)
    local region = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    region:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    region:SetWidth(width)
    region:SetJustifyH("LEFT")
    region:SetText(text)
    return region
end

local function artwork(parent, key, x, y, width, height)
    local texture = parent:CreateTexture(nil, "ARTWORK")
    texture:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    texture:SetSize(width, height)
    texture:SetTexture(Addon:GetModule("Media"):Resolve(key))
    return texture
end

function Preview:CreatePanel()
    if self.frame then return self.frame end
    -- This is a static reference board. No protected templates, unit bindings,
    -- native-frame mutations, or hooks into the Blizzard UI.
    local panel = CreateFrame("Frame", "ForeverClassicUIPreview", UIParent)
    panel:Hide()
    panel:SetSize(740, 620)
    panel:SetPoint("CENTER", UIParent, "CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(frame)
        if not Addon:IsInCombat() then frame:StartMoving() end
    end)
    panel:SetScript("OnDragStop", function(frame) frame:StopMovingOrSizing() end)
    panel:SetScript("OnHide", function(frame) frame:StopMovingOrSizing() end)

    local background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(panel)
    background:SetColorTexture(0.045, 0.038, 0.026, 0.98)
    label(panel, "Forever Classic UI — Era references", 24, -24, 660, "GameFontNormalLarge")
    label(panel, "Native texture samples. The game's interface is unchanged.", 24, -52, 675, "GameFontHighlightSmall")
    label(panel, "Drag to move. Press Escape to close. Automatically closes in combat.", 24, -72, 675, "GameFontHighlightSmall")

    label(panel, "Portrait frame", 24, -112, 290)
    artwork(panel, "targetFrame", 24, -136, 256, 128)
    label(panel, "UI-TargetingFrame / 137026", 24, -270, 295, "GameFontHighlightSmall")

    label(panel, "Action slots", 24, -312, 290)
    for index = 0, 3 do artwork(panel, "actionSlot", 24 + index * 68, -338, 64, 64) end
    label(panel, "UI-Quickslot2 / 130841", 24, -410, 295, "GameFontHighlightSmall")

    label(panel, "Quest log — original fragments", 350, -112, 365)
    artwork(panel, "questTopLeft", 350, -138, 160, 160)
    artwork(panel, "questTopRight", 516, -138, 160, 160)
    artwork(panel, "questBottomLeft", 350, -304, 160, 160)
    artwork(panel, "questBottomRight", 516, -304, 160, 160)

    label(panel, "Talents — border and Arms background", 24, -444, 310)
    artwork(panel, "talentBorder", 24, -468, 96, 96)
    artwork(panel, "talentWarriorArms", 126, -468, 96, 96)
    label(panel, "136963 / 136983", 230, -490, 100, "GameFontHighlightSmall")
    label(panel, "Prototype 0.1: rendering needs testing in Classic Era 1.15.9. Forever unverified.", 24, -586, 680, "GameFontHighlightSmall")
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() panel:Hide() end)

    UISpecialFrames[#UISpecialFrames + 1] = "ForeverClassicUIPreview"
    self.frame = panel
    return panel
end

function Preview:Toggle()
    if Addon:IsInCombat() then
        Addon:Print("Open the references outside combat. No changes applied.")
        return false
    end
    local panel = self:CreatePanel()
    if panel:IsShown() then panel:Hide() else panel:Show() end
    return true
end

function Preview:Hide()
    if self.frame then self.frame:Hide() end
end
