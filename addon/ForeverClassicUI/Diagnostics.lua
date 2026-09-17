-- SPDX-License-Identifier: MIT
local _, Addon = ...
local Diagnostics = Addon:RegisterModule("Diagnostics", {})

Diagnostics.frameNames = {
    "PlayerFrame", "TargetFrame", "PetFrame", "PartyFrame", "PartyMemberFrame1",
    "MainMenuBar", "MainMenuBarArtFrame", "ActionButton1", "MicroMenu",
    "Minimap", "MinimapCluster", "QuestFrame", "QuestLogFrame", "CharacterFrame",
    "SpellBookFrame", "TalentFrame", "PlayerTalentFrame", "WorldMapFrame",
    "ContainerFrame1", "BankFrame", "EditModeManagerFrame",
    -- The beta uses a combined spells/talents window and a map quest panel.
    -- Keep legacy probes for comparison; their absence is not an error.
    "PlayerSpellsFrame", "QuestMapFrame", "SettingsPanel", "FocusFrame",
}

local function inspectFrame(name)
    local frame = _G[name]
    local report = { present = frame ~= nil }
    if not report.present then return report end
    -- Inspect only UI capabilities. Never access unit data, text, attributes,
    -- children, aura values, or any other combat/character information.
    if type(frame) ~= "table" and type(frame) ~= "userdata" then
        report.kind = type(frame)
        return report
    end
    if type(frame.IsForbidden) == "function" then
        local ok, forbidden = pcall(frame.IsForbidden, frame)
        if not ok then report.inspection = "unavailable"; return report end
        report.forbidden = forbidden and true or false
        if forbidden then return report end
    end
    if type(frame.IsProtected) == "function" then
        local ok, protected = pcall(frame.IsProtected, frame)
        if ok then report.protected = protected and true or false
        else report.inspection = "unavailable" end
    end
    return report
end

function Diagnostics:Collect()
    local version, build, buildDate, interfaceVersion = GetBuildInfo()
    local settings = type(Settings) == "table" and Settings or {}
    local report = {
        schemaVersion = 1,
        addonVersion = Addon.version,
        scope = "ui-capabilities-only",
        foreverCompatibility = "unvalidated",
        client = {
            version = version,
            build = build,
            buildDate = buildDate,
            interfaceVersion = interfaceVersion,
            projectID = WOW_PROJECT_ID,
            locale = GetLocale(),
        },
        api = {
            issecretvalue = type(issecretvalue) == "function",
            C_Secrets = type(C_Secrets) == "table",
            InCombatLockdown = type(InCombatLockdown) == "function",
            Settings_RegisterCanvasLayoutCategory = type(settings.RegisterCanvasLayoutCategory) == "function",
            Settings_RegisterAddOnCategory = type(settings.RegisterAddOnCategory) == "function",
            Settings_OpenToCategory = type(settings.OpenToCategory) == "function",
        },
        frames = {},
        mediaSource = Addon:GetModule("Media").source,
    }
    for _, name in ipairs(self.frameNames) do report.frames[name] = inspectFrame(name) end
    local restoration = Addon:GetModule("Restoration")
    if restoration then
        report.restoration = { enabled = restoration:IsEnabled(), modules = {} }
        for _, option in ipairs(restoration:GetOptions()) do
            local state, reason = restoration:GetStatus(option.id)
            report.restoration.modules[option.id] = {
                selected = restoration:GetSelection(option.id), state = state, reason = reason,
            }
        end
    end
    return report
end

function Diagnostics:Run(verbose)
    local report = self:Collect()
    Addon.db.lastReport = report
    local client = report.client
    Addon:Print(string.format("Client %s, build %s, TOC %s, project %s, locale %s.",
        tostring(client.version), tostring(client.build), tostring(client.interfaceVersion),
        tostring(client.projectID), tostring(client.locale)))
    local present, protected = 0, 0
    for _, name in ipairs(self.frameNames) do
        local frame = report.frames[name]
        if frame.present then present = present + 1 end
        if frame.protected then protected = protected + 1 end
        if verbose then
            local status = "not loaded/absent"
            if frame.present then
                status = frame.forbidden and "inspection forbidden"
                    or frame.protected and "present, protected"
                    or frame.protected == false and "present, unprotected"
                    or "present, protection unknown"
            end
            Addon:Print(name .. ": " .. status)
        end
    end
    Addon:Print(string.format("UI sample: %d/%d frames present, %d protected. issecretvalue=%s; C_Secrets=%s.",
        present, #self.frameNames, protected,
        tostring(report.api.issecretvalue), tostring(report.api.C_Secrets)))
    Addon:Print(string.format("Settings API: canvas=%s; addon category=%s; open=%s.",
        tostring(report.api.Settings_RegisterCanvasLayoutCategory),
        tostring(report.api.Settings_RegisterAddOnCategory),
        tostring(report.api.Settings_OpenToCategory)))
    if report.restoration then
        Addon:Print("Classic styling: " .. (report.restoration.enabled and "enabled" or "disabled")
            .. ". Open /foreverui settings to choose window borders.")
        if verbose then
            for _, option in ipairs(Addon:GetModule("Restoration"):GetOptions()) do
                local module = report.restoration.modules[option.id]
                Addon:Print(option.label .. ": " .. module.state)
            end
        end
    end
    Addon:Print("Report held in memory. Use /reload or log out to save it in ForeverClassicUIDB.")
    Addon:Print("An absent frame may load on demand. Forever compatibility is unverified.")
    return report
end
