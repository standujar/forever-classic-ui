-- SPDX-License-Identifier: MIT
local _, Addon = ...
local SettingsPanel = Addon:RegisterModule("Settings", {})

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

local function managerAvailable(manager)
    if not manager then return false end
    local ok, available = pcall(function()
        -- Check forbidden access before inspecting the rest of the manager.
        if type(manager.IsForbidden) ~= "function" or manager:IsForbidden() then return false end
        if type(manager.IsProtected) ~= "function" or manager:IsProtected() then return false end
        for _, method in ipairs({ "HookScript", "IsShown", "IsEditModeActive", "CanEnterEditMode", "GetWidth" }) do
            if type(manager[method]) ~= "function" then return false end
        end
        return true
    end)
    return ok and available == true
end

function SettingsPanel:Initialize()
    self:EnsureRegistered()
end

function SettingsPanel:IsEditModeVisible()
    if not self.manager then return false end
    local ok, visible = pcall(function()
        return self.manager:IsShown() and self.manager:IsEditModeActive() == true
    end)
    return ok and visible == true
end

function SettingsPanel:CanChange()
    return self.registered and not Addon:IsInCombat() and self:IsEditModeVisible()
        and self.layoutFits ~= false and self.panel and self.panel:IsShown()
end

function SettingsPanel:EnsureRegistered()
    if self.registered then return true end
    if self.panelCreationFailed then return false end
    if Addon:IsInCombat() or not Addon:GetModule("Restoration") then return false end
    local manager = EditModeManagerFrame
    if not managerAvailable(manager) then return false end
    local ok, failure = pcall(function()
        self.manager = manager
        self:CreatePanel(manager)
        -- Hooks preserve the native scripts. OnHide is also needed when Blizzard
        -- temporarily hides Edit Mode to open Settings without exiting Edit Mode.
        manager:HookScript("OnShow", function() self:Refresh() end)
        manager:HookScript("OnHide", function()
            if self.panel then self.panel:Hide() end
            self.spaceWarningShown = nil
        end)
        manager:HookScript("OnSizeChanged", function()
            if not Addon:IsInCombat() then self:Refresh() end
        end)
        manager:HookScript("OnDragStop", function()
            if not Addon:IsInCombat() then self:Refresh() end
        end)
        self.registered = true
        self:Refresh()
    end)
    if not ok then
        self.lastError = tostring(failure)
        self.registered = false
        -- Partially constructed frames/hooks cannot be unregistered safely.
        -- Leave them inert and require a reload instead of duplicating them.
        self.panelCreationFailed = true
        if self.panel then pcall(self.panel.Hide, self.panel) end
        if self.scroll then pcall(self.scroll.SetScript, self.scroll, "OnSizeChanged", nil) end
        self.panel, self.frame, self.scroll, self.content = nil, nil, nil, nil
        return false
    end
    self.lastError = nil
    return true
end

function SettingsPanel:Open()
    if Addon:IsInCombat() then
        Addon:Print("Open Edit Mode outside combat. Use /foreverui status to inspect the current state.")
        return false
    end
    if not EditModeManagerFrame and type(C_AddOns) == "table" and type(C_AddOns.LoadAddOn) == "function" then
        -- Only the explicit command loads Edit Mode. ADDON_LOADED can otherwise
        -- attach the section later without forcing an optional Blizzard addon.
        pcall(C_AddOns.LoadAddOn, "Blizzard_EditMode")
    end
    if not self:EnsureRegistered() then
        if self.panelCreationFailed then
            Addon:Print("Could not initialize the Classic UI controls. Use /reload, then Escape > Edit Mode.")
        else
            Addon:Print("Edit Mode is unavailable on this client or is not ready. Try Escape > Edit Mode after entering the world.")
        end
        return false
    end
    local ok, opened = pcall(function()
        if not self:IsEditModeVisible() then
            if self.manager:CanEnterEditMode() ~= true or type(ShowUIPanel) ~= "function" then return false end
            -- Use the same entry point as the native game menu. Never invoke
            -- EnterEditMode directly or change Blizzard's layout data.
            ShowUIPanel(self.manager)
        end
        self:Refresh()
        return self:IsEditModeVisible()
    end)
    if not ok then self.lastError = tostring(opened) end
    if not ok or not opened then
        Addon:Print("Edit Mode cannot be opened right now. Close other windows and try Escape > Edit Mode.")
        return false
    end
    self.lastError = nil
    return self.layoutFits ~= false
end

function SettingsPanel:CreatePanel(manager)
    if self.panel then return self.panel end
    local panel = CreateFrame("Frame", "ForeverReframedEditModeControls", manager, "BackdropTemplate")
    -- The native parent is a ResizeLayoutFrame. Our section must never
    -- participate in its child bounds, or it would grow the parent repeatedly.
    panel.ignoreInLayout = true
    self.panel, self.frame = panel, panel
    panel:Hide()
    panel:EnableMouse(true)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    self.rows = {}

    -- Everything scrolls together, including the heading and footer. A small
    -- viewport can therefore fit beside an expanded native manager without
    -- covering its Save/Revert buttons or imposing a tall fixed header.
    local scroll = CreateFrame("ScrollFrame", nil, panel, "ScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(450, 1)
    scroll:SetScrollChild(content)
    self.scroll, self.content = scroll, content
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -34, 10)
    scroll:SetScript("OnSizeChanged", function()
        if not Addon:IsInCombat() then self:Layout() end
    end)

    self.title = font(content, "Classic UI - Forever Reframed", "GameFontNormal")
    self.title:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -6)
    self.resetButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    self.resetButton:SetSize(128, 24)
    self.resetButton:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
    self.resetButton:SetText("Reset to defaults")
    self.resetButton:SetScript("OnClick", function()
        if self:CanChange() then Addon:GetModule("Restoration"):Reset() end
        self:Refresh()
    end)

    self.masterCheckbox = checkbox(content, "Enable Classic styling")
    self.masterCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", -2, -30)
    self.masterCheckbox:SetScript("OnClick", function(button)
        if self:CanChange() then
            Addon:GetModule("Restoration"):SetEnabled(button:GetChecked() and true or false)
        end
        self:Refresh()
    end)
    self.status = font(content, "Preview build: window borders only. In-game validation pending.")
    self.status:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -64)
    self.summary = self.status
    self.note = font(content, "Saved immediately for all layouts. Edit Mode Save/Revert does not change these choices. Nameplates stay native.")
    return panel
end

function SettingsPanel:CreateRow(descriptor)
    local row = CreateFrame("Frame", nil, self.content)
    row.checkbox = checkbox(row, descriptor.label)
    row.checkbox:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.status = font(row)
    row.descriptor = descriptor
    row.checkbox:SetScript("OnClick", function(button)
        local engine = Addon:GetModule("Restoration")
        if self:CanChange() and engine:IsEnabled() and engine:IsSupported(row.descriptor.id) then
            engine:SetSelection(row.descriptor.id, button:GetChecked() and true or false)
        end
        self:Refresh()
    end)
    self.rows[descriptor.id] = row
    return row
end

function SettingsPanel:Layout()
    if not self.panel or not self.content or self.layingOut then return end
    self.layingOut = true
    local width = self.manager:GetWidth()
    if width <= 0 then width = 510 end
    local contentWidth = math.max(1, width - 48)
    self.content:SetWidth(contentWidth)
    self.title:SetWidth(math.max(1, contentWidth - 140))
    self.status:SetWidth(math.max(1, contentWidth - 8))
    self.note:SetWidth(math.max(1, contentWidth - 8))
    self.masterCheckbox.Text:SetWidth(math.max(1, contentWidth - 34))
    local y = 64 + textHeight(self.status) + 10
    for _, descriptor in ipairs(self.options or {}) do
        local row = self.rows[descriptor.id]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
        row:SetWidth(contentWidth)
        row.checkbox.Text:SetWidth(math.max(1, contentWidth - 34))
        local labelHeight = math.max(28, textHeight(row.checkbox.Text))
        row.status:ClearAllPoints()
        row.status:SetPoint("TOPLEFT", row, "TOPLEFT", 30, -labelHeight)
        row.status:SetWidth(math.max(1, contentWidth - 34))
        local height = labelHeight + textHeight(row.status) + 8
        row:SetHeight(height)
        y = y + height
    end
    self.note:ClearAllPoints()
    self.note:SetPoint("TOPLEFT", self.content, "TOPLEFT", 4, -(y + 8))
    local contentHeight = y + textHeight(self.note) + 16
    self.content:SetHeight(contentHeight)
    local desiredHeight = math.min(360, contentHeight + 20)
    local above, available = false, desiredHeight
    if type(self.manager.GetBottom) == "function" and type(self.manager.GetTop) == "function"
        and UIParent and type(UIParent.GetHeight) == "function" then
        local bottom, top = self.manager:GetBottom(), self.manager:GetTop()
        local screenHeight = UIParent:GetHeight()
        if type(self.manager.GetEffectiveScale) == "function" and type(UIParent.GetEffectiveScale) == "function" then
            local scale = self.manager:GetEffectiveScale()
            if scale > 0 then screenHeight = screenHeight * UIParent:GetEffectiveScale() / scale end
        end
        if bottom and top then
            local belowSpace, aboveSpace = math.max(0, bottom - 16), math.max(0, screenHeight - top - 16)
            above = belowSpace < desiredHeight and aboveSpace > belowSpace
            available = above and aboveSpace or belowSpace
        end
    end
    -- Never clamp this child back over its native parent: its entire viewport
    -- fits in the chosen free area, or stays hidden until space is available.
    local height = math.min(desiredHeight, available)
    self.layoutFits = height >= 64
    if not self.layoutFits then
        self.panel:Hide()
        self.layingOut = false
        return false
    end
    self.panel:ClearAllPoints()
    if above then
        self.panel:SetPoint("BOTTOMLEFT", self.manager, "TOPLEFT", 0, 6)
        self.panel:SetPoint("BOTTOMRIGHT", self.manager, "TOPRIGHT", 0, 6)
    else
        self.panel:SetPoint("TOPLEFT", self.manager, "BOTTOMLEFT", 0, -6)
        self.panel:SetPoint("TOPRIGHT", self.manager, "BOTTOMRIGHT", 0, -6)
    end
    self.panel:SetHeight(height)
    self.layingOut = false
    return true
end

function SettingsPanel:Refresh()
    if not self.panel or self.refreshing then return end
    local engine = Addon:GetModule("Restoration")
    if not engine then return end
    if Addon:IsInCombat() then
        self.masterCheckbox:SetEnabled(false)
        self.resetButton:SetEnabled(false)
        for _, row in pairs(self.rows) do row.checkbox:SetEnabled(false) end
        self.panel:Hide()
        return
    end
    self.refreshing = true
    local visible, enabled = self:IsEditModeVisible(), engine:IsEnabled()
    self.masterCheckbox:SetChecked(enabled)
    self.masterCheckbox:SetEnabled(visible)
    self.resetButton:SetEnabled(visible)
    for _, row in pairs(self.rows) do row:Hide() end
    self.options = engine:GetOptions() or {}
    for _, descriptor in ipairs(self.options) do
        local row = self.rows[descriptor.id] or self:CreateRow(descriptor)
        row.descriptor = descriptor
        row.checkbox.Text:SetText(descriptor.label)
        row.checkbox:SetChecked(engine:GetSelection(descriptor.id))
        local supported, unsupportedReason = engine:IsSupported(descriptor.id)
        row.checkbox:SetEnabled(visible and enabled and supported)
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
    self:Layout()
    if visible and self.layoutFits then
        self.spaceWarningShown = nil
        self.panel:Show()
    else
        self.panel:Hide()
        self.masterCheckbox:SetEnabled(false)
        self.resetButton:SetEnabled(false)
        for _, row in pairs(self.rows) do row.checkbox:SetEnabled(false) end
        if visible and not self.spaceWarningShown then
            self.spaceWarningShown = true
            Addon:Print("Classic UI controls need more screen space. Move or collapse the Edit Mode window to show them.")
        end
    end
    self.refreshing = false
end
