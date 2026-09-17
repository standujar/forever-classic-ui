-- SPDX-License-Identifier: MIT
local _, Addon = ...
local SettingsPanel = Addon:RegisterModule("Settings", {})

local groupOrder = { "Unit Frames", "Windows", "HUD" }
local statusLabels = {
    native = "Native appearance",
    active = "Classic styling active",
    pending = "Pending",
    waiting = "Waiting for the window to load",
    unsupported = "Not supported on this client",
    error = "Could not apply styling",
}

local function font(parent, text, template)
    local region = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    region:SetJustifyH("LEFT")
    region:SetText(text or "")
    return region
end

local function textHeight(region)
    return math.max(14, region:GetStringHeight())
end

local function checkbox(parent, text)
    local button = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    button:SetSize(28, 28)
    button.Text:SetFontObject("GameFontNormal")
    button.Text:SetText(text)
    button.Text:SetJustifyH("LEFT")
    return button
end

function SettingsPanel:Initialize()
    self:EnsureRegistered()
end

function SettingsPanel:EnsureRegistered()
    if self.registered then return true end
    if self.panelCreationFailed then return false end
    if Addon:IsInCombat() or not Addon:GetModule("Restoration") then return false end
    if type(Settings) ~= "table"
        or type(Settings.RegisterCanvasLayoutCategory) ~= "function"
        or type(Settings.RegisterAddOnCategory) ~= "function"
        or type(Settings.OpenToCategory) ~= "function" then
        return false
    end
    local stage = "panel"
    local ok, failure = pcall(function()
        local panel = self:CreatePanel()
        stage = "category"
        if not self.category then
            local category = Settings.RegisterCanvasLayoutCategory(panel, "Forever Classic UI")
            assert(category and type(category.GetID) == "function", "Settings category unavailable")
            self.category = category
        end
        stage = "registration"
        Settings.RegisterAddOnCategory(self.category)
    end)
    if not ok then
        self.lastError = tostring(failure)
        if stage == "panel" then
            -- Frame construction may have left partially initialized children.
            -- Keep them hidden and require a reload rather than reusing them or
            -- retrying construction on every subsequent ADDON_LOADED event.
            self.panelCreationFailed = true
            if self.panel then pcall(self.panel.Hide, self.panel) end
            if self.scroll then pcall(self.scroll.SetScript, self.scroll, "OnSizeChanged", nil) end
            self.panel, self.frame = nil, nil
        end
        return false
    end
    self.lastError = nil
    self.registered = true
    self:Refresh()
    return true
end

function SettingsPanel:Open()
    if Addon:IsInCombat() then
        Addon:Print("Open settings outside combat. Use /foreverui status to inspect the current state.")
        return false
    end
    if not self:EnsureRegistered() then
        if self.lastError then
            Addon:Print("Could not initialize Blizzard Settings. Use /reload and try /foreverui settings again.")
        else
            Addon:Print("Blizzard Settings is not available yet. Try /foreverui settings after entering the world; /foreverui status shows diagnostics.")
        end
        return false
    end
    local ok, failure = pcall(function()
        self:Refresh()
        Settings.OpenToCategory(self.category:GetID())
    end)
    if not ok then
        self.lastError = tostring(failure)
        Addon:Print("Could not open Blizzard Settings. Use /reload and try /foreverui settings again.")
        return false
    end
    self.lastError = nil
    return true
end

function SettingsPanel:CreatePanel()
    if self.panel then return self.panel end
    local panel = CreateFrame("Frame", "ForeverClassicUISettingsPanel", UIParent)
    panel:Hide()
    panel:SetSize(680, 560)
    self.panel, self.frame = panel, panel
    self.rows, self.headers = {}, {}

    local title = font(panel, "Forever Classic UI", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -16)
    local note = font(panel, "Preview build: window borders only. In-game validation pending.")
    note:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -48)
    note:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -48)

    self.masterCheckbox = checkbox(panel, "Enable Classic styling")
    self.masterCheckbox:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -76)
    self.masterCheckbox:SetScript("OnClick", function(button)
        Addon:GetModule("Restoration"):SetEnabled(button:GetChecked() and true or false)
        self:Refresh()
    end)
    self.summary = font(panel)
    self.summary:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -112)
    self.summary:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -112)

    -- ScrollFrameTemplate supplies the client's native scrollbar and wheel
    -- handling; all settings content remains inside this scroll child.
    local scroll = CreateFrame("ScrollFrame", nil, panel, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -148)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -36, 62)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(620, 1)
    scroll:SetScrollChild(content)
    self.scroll, self.content = scroll, content
    self.futureNote = font(content)
    scroll:SetScript("OnSizeChanged", function() self:Layout() end)

    self.resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    self.resetButton:SetSize(164, 24)
    self.resetButton:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 18)
    self.resetButton:SetText("Reset to defaults")
    self.resetButton:SetScript("OnClick", function()
        Addon:GetModule("Restoration"):Reset()
        self:Refresh()
    end)
    self.previewButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    self.previewButton:SetSize(164, 24)
    self.previewButton:SetPoint("LEFT", self.resetButton, "RIGHT", 12, 0)
    self.previewButton:SetText("Texture preview")
    self.previewButton:SetScript("OnClick", function()
        local preview = Addon:GetModule("Preview")
        if preview then preview:Toggle() end
    end)

    panel.OnRefresh = function() self:Refresh() end
    panel.OnDefault = function()
        Addon:GetModule("Restoration"):Reset()
        self:Refresh()
    end
    panel:SetScript("OnShow", function() self:Refresh() end)
    return panel
end

function SettingsPanel:CreateRow(descriptor)
    local row = CreateFrame("Frame", nil, self.content)
    row.checkbox = checkbox(row, descriptor.label)
    row.checkbox:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.description = font(row, descriptor.description)
    row.status = font(row)
    row.descriptor = descriptor
    row.checkbox:SetScript("OnClick", function(button)
        local engine = Addon:GetModule("Restoration")
        local supported = engine:IsSupported(row.descriptor.id)
        if engine:IsEnabled() and supported then
            engine:SetSelection(row.descriptor.id, button:GetChecked() and true or false)
        end
        self:Refresh()
    end)
    self.rows[descriptor.id] = row
    return row
end

function SettingsPanel:Layout()
    if not self.content or self.layingOut then return end
    self.layingOut = true
    local width = self.scroll:GetWidth()
    if width <= 0 then width = 620 end
    self.content:SetWidth(width)
    local y = 4
    for _, group in ipairs(groupOrder) do
        local header = self.headers[group]
        if header and header.used then
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", self.content, "TOPLEFT", 4, -y)
            header:SetWidth(math.max(1, width - 12))
            y = y + textHeight(header) + 12
            for _, descriptor in ipairs(self.options or {}) do
                if descriptor.group == group then
                    local row = self.rows[descriptor.id]
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
                    row:SetWidth(width)
                    row.checkbox.Text:SetWidth(math.max(1, width - 40))
                    local labelHeight = math.max(28, textHeight(row.checkbox.Text))
                    row.description:ClearAllPoints()
                    row.description:SetPoint("TOPLEFT", row, "TOPLEFT", 30, -(labelHeight + 2))
                    row.description:SetWidth(math.max(1, width - 42))
                    local descriptionHeight = textHeight(row.description)
                    row.status:ClearAllPoints()
                    row.status:SetPoint("TOPLEFT", row, "TOPLEFT", 30, -(labelHeight + descriptionHeight + 8))
                    row.status:SetWidth(math.max(1, width - 42))
                    local height = labelHeight + descriptionHeight + textHeight(row.status) + 22
                    row:SetHeight(height)
                    y = y + height
                end
            end
            y = y + 12
        end
    end
    self.futureNote:ClearAllPoints()
    self.futureNote:SetPoint("TOPLEFT", self.content, "TOPLEFT", 4, -y)
    self.futureNote:SetWidth(math.max(1, width - 16))
    self.content:SetHeight(y + textHeight(self.futureNote) + 20)
    self.layingOut = false
end

function SettingsPanel:Refresh()
    if not self.panel or self.refreshing then return end
    local engine = Addon:GetModule("Restoration")
    if not engine then return end
    self.refreshing = true
    local enabled = engine:IsEnabled()
    self.masterCheckbox:SetChecked(enabled)
    self.masterCheckbox:SetEnabled(true)
    if Addon:IsInCombat() then
        self.summary:SetText("Choices are saved now. Changes to game frames wait until combat ends.")
    elseif enabled then
        self.summary:SetText("Choose the available modules below. Each status reports what is currently applied.")
    else
        self.summary:SetText("Classic styling is disabled by default. Enable it to select available modules.")
    end
    self.previewButton:SetEnabled(not Addon:IsInCombat() and Addon:GetModule("Preview") ~= nil)

    for _, header in pairs(self.headers) do header.used = false; header:Hide() end
    for _, row in pairs(self.rows) do row:Hide() end
    self.options = engine:GetOptions() or {}
    local implementedGroups = {}
    for _, descriptor in ipairs(self.options) do
        implementedGroups[descriptor.group] = true
        local header = self.headers[descriptor.group]
        if not header then
            header = font(self.content, descriptor.group, "GameFontNormal")
            self.headers[descriptor.group] = header
        end
        header.used = true
        header:Show()
        local row = self.rows[descriptor.id] or self:CreateRow(descriptor)
        row.descriptor = descriptor
        row.checkbox.Text:SetText(descriptor.label)
        row.description:SetText(descriptor.description or "")
        row.checkbox:SetChecked(engine:GetSelection(descriptor.id))
        local supported, unsupportedReason = engine:IsSupported(descriptor.id)
        row.checkbox:SetEnabled(enabled and supported)
        local state, reason = engine:GetStatus(descriptor.id)
        if not supported and (state == "native" or state == "unsupported") then
            state, reason = "unsupported", unsupportedReason or reason
        end
        local status = statusLabels[state] or "Status unavailable"
        if reason and reason ~= "" then status = status .. ": " .. reason end
        if not supported and state ~= "unsupported" then
            status = status .. ". " .. (unsupportedReason or "This module is not supported on this client.")
        end
        row.status:SetText(status)
        if state == "unsupported" or state == "error" then
            row.status:SetTextColor(1, 0.55, 0.4)
        elseif state == "active" then
            row.status:SetTextColor(0.5, 1, 0.5)
        else
            row.status:SetTextColor(0.75, 0.75, 0.75)
        end
        row:Show()
    end
    local future = {}
    if not implementedGroups["Unit Frames"] then future[#future + 1] = "Unit frame" end
    if not implementedGroups.HUD then future[#future + 1] = "HUD" end
    local note = "Native nameplates are preserved."
    if #future > 0 then note = note .. " " .. table.concat(future, " and ") .. " modules are not implemented yet." end
    if #self.options == 0 then note = "No styling modules are available in this build. " .. note end
    self.futureNote:SetText(note)
    self:Layout()
    self.refreshing = false
end
