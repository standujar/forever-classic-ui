-- SPDX-License-Identifier: MIT
local addonName, Addon = ...

Addon.name = addonName
Addon.version = "0.1.0-dev"
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
end

function Addon:HandleCommand(input)
    if not self.initialized then self:Initialize() end
    local command = string.lower(string.match(input or "", "^%s*(%S*)") or "")
    if command == "status" or command == "inspect" then
        self:GetModule("Diagnostics"):Run(command == "inspect")
    elseif command == "preview" then
        self:GetModule("Preview"):Toggle()
    elseif command == "hide" then
        self:GetModule("Preview"):Hide()
    else
        self:Print("/fcui status: report; /fcui inspect: details; /fcui preview: references; /fcui hide: close.")
        self:Print("Classic Era 1.15.9 workshop. Forever compatibility is unverified.")
    end
end

SLASH_FOREVERCLASSICUI1 = "/fcui"
SlashCmdList.FOREVERCLASSICUI = function(input) Addon:HandleCommand(input) end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == addonName then
        Addon:Initialize()
        events:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_REGEN_DISABLED" then
        local preview = Addon:GetModule("Preview")
        if preview then preview:Hide() end
    end
end)
