-- SPDX-License-Identifier: MIT
local _, Addon = ...
local Restoration = Addon:RegisterModule("Restoration", {})

Restoration.options = {}
Restoration.byID = {}
Restoration.applied = {}
Restoration.status = {}

function Restoration:Initialize()
    if type(Addon.db.settings) ~= "table" then Addon.db.settings = {} end
    self.config = Addon.db.settings
    if type(self.config.enabled) ~= "boolean" then self.config.enabled = false end
    if type(self.config.modules) ~= "table" then self.config.modules = {} end
    for id, selected in pairs(self.config.modules) do
        if type(selected) ~= "boolean" then self.config.modules[id] = false end
    end
end

function Restoration:Register(option)
    assert(type(option) == "table" and type(option.id) == "string", "Invalid restoration option")
    assert(option.id:match("^[a-z][a-z0-9_]*$"), "Invalid restoration ID")
    assert(not option.id:find("nameplate"), "Native nameplates are outside restoration scope")
    assert(not self.byID[option.id], "Duplicate restoration option: " .. option.id)
    assert(type(option.Apply) == "function" and type(option.Revert) == "function"
        and type(option.IsSupported) == "function", "Missing restoration methods")
    self.byID[option.id] = option
    self.options[#self.options + 1] = option
    self.status[option.id] = { state = "native" }
end

function Restoration:GetOptions() return self.options end
function Restoration:IsEnabled() return self.config and self.config.enabled == true end
function Restoration:GetSelection(id) return self.config and self.config.modules[id] == true end
function Restoration:IsSelected(id) return self:IsEnabled() and self:GetSelection(id) end

function Restoration:SetEnabled(value)
    self.config.enabled = value == true
    self:Reconcile()
end

function Restoration:SetSelection(id, value)
    assert(self.byID[id], "Unknown restoration option: " .. tostring(id))
    self.config.modules[id] = value == true
    self:Reconcile()
end

function Restoration:Reset()
    self.config.enabled = false
    self.config.modules = {}
    self:Reconcile()
end

function Restoration:IsSupported(id)
    local option = self.byID[id]
    if not option then return false, "Module is unavailable." end
    local ok, supported, reason = pcall(option.IsSupported, option)
    if not ok then return false, "Unable to check this module on the current client." end
    return supported == true, reason
end

function Restoration:GetStatus(id)
    local status = self.status[id]
    if not status then return "unsupported", "Module is unavailable." end
    return status.state, status.reason
end

local function invoke(option, method)
    local ok, result, reason = pcall(option[method], option)
    if not ok then return false, tostring(result) end
    return result == true, reason
end

function Restoration:RestoreNative(option)
    if not self.applied[option.id] then return true end
    local restored, reason = invoke(option, "Revert")
    if restored then
        self.applied[option.id] = nil
        return true
    end
    -- Retain ownership until a later successful restore. Never report native
    -- appearance while a partial restoration may still be present.
    return false, reason or "Native appearance could not be restored."
end

function Restoration:ReconcileOption(option)
    local id = option.id
    local selected = self:IsSelected(id)
    if Addon:IsInCombat() then
        if selected ~= (self.applied[id] == true) then
            self.status[id] = { state = "pending", reason = "Changes will apply after combat." }
        elseif not selected then
            self.status[id] = { state = "native" }
        end
        return
    end

    if not selected then
        local restored, reason = self:RestoreNative(option)
        self.status[id] = { state = restored and "native" or "error", reason = reason }
        return
    end

    local supported, reason = self:IsSupported(id)
    if not supported then
        local restored, restoreReason = self:RestoreNative(option)
        self.status[id] = {
            state = restored and "unsupported" or "error",
            reason = restoreReason or reason or "This client is not supported by the module.",
        }
        return
    end

    -- Apply may partially succeed before an API call fails. Mark it for cleanup
    -- first, and attempt rollback for both reported failures and Lua errors.
    self.applied[id] = true
    local applied, applyReason = invoke(option, "Apply")
    if applied then
        self.status[id] = { state = "active" }
    else
        local restored, restoreReason = self:RestoreNative(option)
        self.status[id] = {
            state = restored and applyReason == "waiting" and "waiting" or "error",
            reason = restoreReason or (applyReason == "waiting" and "Open the window to apply its border.")
                or applyReason or "The module could not be applied.",
        }
    end
end

function Restoration:Reconcile()
    if not self.config or self.reconciling then return end
    self.reconciling = true
    for _, option in ipairs(self.options) do self:ReconcileOption(option) end
    self.reconciling = false
    local settings = Addon:GetModule("Settings")
    if settings and settings.Refresh then settings:Refresh() end
end
