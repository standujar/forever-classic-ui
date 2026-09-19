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
    self.rows, self.groupRows, self.expandedGroups = {}, {}, {}

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
    self.classicButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    self.classicButton:SetSize(154, 24)
    self.classicButton:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -30)
    self.classicButton:SetText("Classic everywhere")
    self.classicButton:SetScript("OnClick", function()
        if self:CanChange() and self.hasSupportedOptions then
            Addon:GetModule("Restoration"):SetAll(true)
        end
        self:Refresh()
    end)
    self.restoreButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    self.restoreButton:SetSize(142, 24)
    self.restoreButton:SetPoint("LEFT", self.classicButton, "RIGHT", 8, 0)
    self.restoreButton:SetText("Restore Forever")
    self.restoreButton:SetScript("OnClick", function()
        if self:CanChange() then Addon:GetModule("Restoration"):SetAll(false) end
        self:Refresh()
    end)
    self.resetButton = self.restoreButton

    self.status = font(content)
    self.status:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -64)
    self.summary = self.status
    self.note = font(content, "Group choices also apply to future modules. Customize to keep individual elements native. Saved immediately for all layouts; Edit Mode Save/Revert does not change these choices. Nameplates stay native.")
    return panel
end

function SettingsPanel:CreateGroupRow(descriptor)
    local row = CreateFrame("Frame", nil, self.content)
    row.descriptor = descriptor
    row.checkbox = checkbox(row, descriptor.label)
    row.checkbox:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    -- A dash gives the native two-state template an explicit mixed state.
    -- Leave the underlying checkbox unchecked so a click selects the group.
    row.mixedMark = font(row.checkbox, "-", "GameFontNormalLarge")
    row.mixedMark:SetPoint("CENTER", row.checkbox, "CENTER", 0, 1)
    row.mixedMark:SetJustifyH("CENTER")
    row.mixedMark:Hide()
    row.status = font(row)
    row.customizeButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.customizeButton:SetSize(108, 24)
    row.customizeButton:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -2)
    row.customizeButton:SetScript("OnClick", function()
        if self:CanChange() and #row.options > 0 then
            local id = row.descriptor.id
            self.expandedGroups[id] = not self.expandedGroups[id]
        end
        self:Refresh()
    end)
    row.checkbox:SetScript("OnClick", function(button)
        if self:CanChange() and row.available then
            Addon:GetModule("Restoration"):SetGroupSelection(row.descriptor.id, button:GetChecked() and true or false)
        end
        self:Refresh()
    end)
    self.groupRows[descriptor.id] = row
    return row
end

function SettingsPanel:CreateRow(descriptor)
    local row = CreateFrame("Frame", nil, self.content)
    row.checkbox = checkbox(row, descriptor.label)
    row.checkbox:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.status = font(row)
    row.descriptor = descriptor
    row.checkbox:SetScript("OnClick", function(button)
        local engine = Addon:GetModule("Restoration")
        if self:CanChange() and row:IsShown() and engine:IsSupported(row.descriptor.id) then
            local selected = button:GetChecked() and true or false
            engine:SetSelection(row.descriptor.id, selected)
            if selected and not engine:IsEnabled() then engine:SetEnabled(true) end
        end
        self:Refresh()
    end)
    self.rows[descriptor.id] = row
    return row
end

function SettingsPanel:DisableControls()
    self.classicButton:SetEnabled(false)
    self.restoreButton:SetEnabled(false)
    for _, row in pairs(self.rows) do row.checkbox:SetEnabled(false) end
    for _, row in pairs(self.groupRows) do
        row.checkbox:SetEnabled(false)
        row.customizeButton:SetEnabled(false)
    end
end

function SettingsPanel:Layout()
    if not self.panel or not self.content or self.layingOut then return end
    self.layingOut = true
    local width = self.manager:GetWidth()
    if width <= 0 then width = 510 end
    local contentWidth = math.max(1, width - 48)
    self.content:SetWidth(contentWidth)
    self.title:SetWidth(math.max(1, contentWidth - 8))
    self.status:SetWidth(math.max(1, contentWidth - 8))
    self.note:SetWidth(math.max(1, contentWidth - 8))
    local y = 64 + textHeight(self.status) + 10
    for _, descriptor in ipairs(self.groups or {}) do
        local group = self.groupRows[descriptor.id]
        group:ClearAllPoints()
        group:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
        group:SetWidth(contentWidth)
        group.checkbox.Text:SetWidth(math.max(1, contentWidth - 148))
        local labelHeight = math.max(28, textHeight(group.checkbox.Text))
        group.status:ClearAllPoints()
        group.status:SetPoint("TOPLEFT", group, "TOPLEFT", 30, -labelHeight)
        group.status:SetWidth(math.max(1, contentWidth - 34))
        local groupHeight = labelHeight + textHeight(group.status) + 8
        group:SetHeight(groupHeight)
        y = y + groupHeight
        if self.expandedGroups[descriptor.id] then
            for _, option in ipairs(group.options) do
                local row = self.rows[option.id]
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 20, -y)
                row:SetWidth(math.max(1, contentWidth - 20))
                row.checkbox.Text:SetWidth(math.max(1, contentWidth - 54))
                local rowLabelHeight = math.max(28, textHeight(row.checkbox.Text))
                row.status:ClearAllPoints()
                row.status:SetPoint("TOPLEFT", row, "TOPLEFT", 30, -rowLabelHeight)
                row.status:SetWidth(math.max(1, contentWidth - 54))
                local height = rowLabelHeight + textHeight(row.status) + 8
                row:SetHeight(height)
                y = y + height
            end
            y = y + 4
        end
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

local function attentionSummary(errors, restoreErrors, pending)
    if errors == 0 and pending == 0 then return nil end
    local details = {}
    if restoreErrors > 0 then
        details[#details + 1] = restoreErrors .. (restoreErrors == 1 and " module" or " modules") .. " could not be restored"
    end
    local applyErrors = errors - restoreErrors
    if applyErrors > 0 then
        details[#details + 1] = applyErrors .. (applyErrors == 1 and " module" or " modules") .. " could not be styled"
    end
    if pending > 0 then
        details[#details + 1] = pending .. (pending == 1 and " change pending" or " changes pending")
    end
    return (errors > 0 and "Needs attention: " or "Pending: ") .. table.concat(details, "; ") .. "."
end

function SettingsPanel:RefreshRow(row, descriptor, visible, engine)
    row.descriptor = descriptor
    row.checkbox.Text:SetText(descriptor.label)
    row.checkbox:SetChecked(engine:GetSelection(descriptor.id))
    local supported, unsupportedReason = engine:IsSupported(descriptor.id)
    row.checkbox:SetEnabled(visible and supported)
    local state, reason = engine:GetStatus(descriptor.id)
    if not supported and (state == "native" or state == "unsupported") then
        state, reason = "unsupported", unsupportedReason or reason
    end
    local status = statusLabels[state] or "Status unavailable"
    if state == "error" and not engine:IsSelected(descriptor.id) then
        status = "Could not restore native appearance"
    end
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
    return supported, state
end

function SettingsPanel:Refresh()
    if not self.panel or self.refreshing then return end
    local engine = Addon:GetModule("Restoration")
    if not engine then return end
    if Addon:IsInCombat() then
        self:DisableControls()
        self.panel:Hide()
        return
    end
    self.refreshing = true
    local visible, enabled = self:IsEditModeVisible(), engine:IsEnabled()
    if enabled then
        self.status:SetText("Choose whole groups, then customize exceptions. Available modules provide partial Classic styling.")
    else
        self.status:SetText("Classic styling is off. Choose a group or use Classic everywhere to get started.")
    end
    self.restoreButton:SetEnabled(visible)
    for _, row in pairs(self.rows) do
        row:Hide()
        row.checkbox:SetEnabled(false)
    end
    for _, group in pairs(self.groupRows) do group:Hide() end
    self.options, self.groups = engine:GetOptions() or {}, engine:GetGroups() or {}
    self.hasSupportedOptions = false
    local totalErrors, totalRestoreErrors, totalPending = 0, 0, 0
    for _, descriptor in ipairs(self.groups) do
        local group = self.groupRows[descriptor.id] or self:CreateGroupRow(descriptor)
        group.descriptor = descriptor
        group.options = engine:GetGroupOptions(descriptor.id) or {}
        group.checkbox.Text:SetText(descriptor.label)
        local expanded = self.expandedGroups[descriptor.id] == true
        group.customizeButton:SetText(expanded and "Customize -" or "Customize +")
        local available, errors, restoreErrors, pending = 0, 0, 0, 0
        for _, option in ipairs(group.options) do
            local row = self.rows[option.id] or self:CreateRow(option)
            local supported, state = self:RefreshRow(row, option, visible and expanded, engine)
            if supported then available = available + 1 end
            if state == "error" then
                errors = errors + 1
                if not engine:IsSelected(option.id) then restoreErrors = restoreErrors + 1 end
            elseif state == "pending" then
                pending = pending + 1
            end
            if expanded then row:Show() end
        end
        totalErrors, totalRestoreErrors, totalPending = totalErrors + errors, totalRestoreErrors + restoreErrors, totalPending + pending
        local attention = attentionSummary(errors, restoreErrors, pending)
        group.available = available > 0
        self.hasSupportedOptions = self.hasSupportedOptions or group.available
        local selection = engine:GetGroupSelection(descriptor.id)
        group.selection = selection
        group.checkbox:SetChecked(selection == "all")
        if selection == "mixed" then group.mixedMark:Show() else group.mixedMark:Hide() end
        group.checkbox:SetEnabled(visible and group.available)
        group.customizeButton:SetEnabled(visible and #group.options > 0)
        if #group.options == 0 then
            group.status:SetText("Coming soon")
            group.customizeButton:Hide()
        else
            local label = selection == "all" and "Classic selected" or selection == "mixed" and "Custom selection" or "Native appearance"
            if not enabled and selection ~= "none" then label = label .. " (styling is off)" end
            if available == 0 then
                label = label .. " - unavailable on this client"
            else
                label = label .. " - " .. available .. " available"
            end
            -- Desired selection is not proof that a failed rollback restored
            -- the native textures. Surface failures even while collapsed.
            group.status:SetText(attention or label)
            group.customizeButton:Show()
        end
        if errors > 0 then
            group.status:SetTextColor(1, 0.55, 0.4)
        elseif pending > 0 then
            group.status:SetTextColor(1, 0.82, 0)
        else
            group.status:SetTextColor(group.available and 0.85 or 0.6, group.available and 0.85 or 0.6, group.available and 0.85 or 0.6)
        end
        group:Show()
    end
    local attention = attentionSummary(totalErrors, totalRestoreErrors, totalPending)
    if attention then
        self.status:SetText(attention .. " Expand Customize for details.")
        if totalErrors > 0 then self.status:SetTextColor(1, 0.55, 0.4) else self.status:SetTextColor(1, 0.82, 0) end
    else
        self.status:SetTextColor(1, 1, 1)
    end
    self.classicButton:SetEnabled(visible and self.hasSupportedOptions)
    self:Layout()
    if visible and self.layoutFits then
        self.spaceWarningShown = nil
        self.panel:Show()
    else
        self.panel:Hide()
        self:DisableControls()
        if visible and not self.spaceWarningShown then
            self.spaceWarningShown = true
            Addon:Print("Classic UI controls need more screen space. Move or collapse the Edit Mode window to show them.")
        end
    end
    self.refreshing = false
end
