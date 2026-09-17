-- SPDX-License-Identifier: MIT
local addonName, Addon = ...

Addon.name = addonName
Addon.version = "0.2.0-dev"
Addon.modules = {}
Addon.moduleOrder = {}

function Addon:RegisterModule(name, module)
    assert(type(name) == "string" and type(module) == "table", "Invalid module")
    assert(not self.modules[name], "Duplicate module: " .. name)
    self.modules[name] = module
    self.moduleOrder[#self.moduleOrder + 1] = name
    module.addon = self
    return module
end

function Addon:GetModule(name)
    return self.modules[name]
end

function Addon:IsInCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

function Addon:Print(message)
    local line = "|cffd4b16aForever Classic UI|r: " .. message
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(line)
    else
        print(line)
    end
end

function Addon:Initialize()
    if self.initialized then return end
    if type(ForeverClassicUIDB) ~= "table" or ForeverClassicUIDB.schemaVersion ~= 1 then
        ForeverClassicUIDB = { schemaVersion = 1 }
    end
    self.db = ForeverClassicUIDB
    self.initialized = true
    for _, name in ipairs(self.moduleOrder) do
        local module = self.modules[name]
        if module.Initialize then module:Initialize() end
    end
    local restoration = self:GetModule("Restoration")
    if restoration then restoration:Reconcile() end
end

function Addon:HandleCommand(input)
    if not self.initialized then self:Initialize() end
    local command = string.lower(string.match(input or "", "^%s*(%S*)") or "")
    if command == "" or command == "settings" then
        local settings = self:GetModule("Settings")
        if settings then settings:Open() end
    elseif command == "status" or command == "inspect" then
        self:GetModule("Diagnostics"):Run(command == "inspect")
    elseif command == "preview" then
        self:GetModule("Preview"):Toggle()
    elseif command == "hide" then
        self:GetModule("Preview"):Hide()
    else
        self:Print("/fcui settings: options; /fcui status: report; /fcui inspect: details; /fcui preview: references; /fcui hide: close.")
        self:Print("Preview build. Native Forever nameplates are preserved. In-game validation pending.")
    end
end

SLASH_FOREVERCLASSICUI1 = "/fcui"
SlashCmdList.FOREVERCLASSICUI = function(input) Addon:HandleCommand(input) end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == addonName then
        Addon:Initialize()
        return
    elseif event == "PLAYER_REGEN_DISABLED" then
        local preview = Addon:GetModule("Preview")
        if preview then preview:Hide() end
        local settings = Addon:GetModule("Settings")
        if settings and settings.Refresh then settings:Refresh() end
    end
    if Addon.initialized and (event == "ADDON_LOADED" or event == "PLAYER_LOGIN"
        or event == "PLAYER_REGEN_ENABLED") then
        local settings = Addon:GetModule("Settings")
        if settings and settings.EnsureRegistered then settings:EnsureRegistered() end
        local restoration = Addon:GetModule("Restoration")
        if restoration then restoration:Reconcile() end
    end
end)
