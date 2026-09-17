-- SPDX-License-Identifier: MIT
-- Behavioral checks only. Rendering, secure execution/taint and persistence to
-- the game's filesystem still require a real client session.
local root = assert(ADDON_TEST_ROOT, "Set ADDON_TEST_ROOT before loading this file")
local testCount = 0

local function equal(actual, expected, message)
    assert(actual == expected, (message or "Unexpected value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function clone(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = clone(item) end
    return copy
end

local function harness(saved)
    local state = { combat = false, frames = {}, messages = {}, sensitiveCalls = 0, nativeMutations = 0 }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.ForeverClassicUIDB = saved
    env.SlashCmdList = {}
    env.UISpecialFrames = {}
    env.UIParent = {}
    env.WOW_PROJECT_ID = 2
    env.GetBuildInfo = function() return "1.15.9", "69722", "Sep 9 2026", 11509 end
    env.GetLocale = function() return "frFR" end
    env.InCombatLockdown = function() return state.combat end
    env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) state.messages[#state.messages + 1] = text end }

    local function sensitive()
        state.sensitiveCalls = state.sensitiveCalls + 1
        error("Forbidden combat or identifying data access")
    end
    for _, name in ipairs({ "UnitName", "UnitFullName", "UnitGUID", "UnitHealth", "UnitHealthMax", "UnitPower", "UnitAura", "UnitExists", "GetRealmName", "BNGetInfo", "issecretvalue" }) do
        env[name] = sensitive
    end
    env.C_Secrets = setmetatable({}, { __index = sensitive })

    local function nativeMutation()
        state.nativeMutations = state.nativeMutations + 1
        error("Native UI mutation")
    end
    env.PlayerFrame = {
        IsProtected = function() return true end,
        IsForbidden = function() return false end,
        Hide = nativeMutation, Show = nativeMutation, SetPoint = nativeMutation,
    }
    env.TargetFrame = {
        IsForbidden = function() return true end,
        IsProtected = function() error("Forbidden frame inspected") end,
    }
    env.Minimap = { IsProtected = function() return false end }
    env.QuestFrame = { IsProtected = function() error("UI inspection unavailable") end }

    local function region()
        local item = {}
        for _, method in ipairs({ "SetPoint", "SetSize", "SetWidth", "SetJustifyH", "SetAllPoints", "SetColorTexture" }) do
            item[method] = function() end
        end
        item.SetText = function(self, text) self.text = text end
        item.SetTexture = function(self, texture) self.texture = texture end
        return item
    end

    env.CreateFrame = function(kind, name, parent, template)
        local frame = { kind = kind, name = name, parent = parent, template = template, shown = true, scripts = {}, events = {}, regions = {} }
        for _, method in ipairs({ "SetSize", "SetPoint", "SetFrameStrata", "SetClampedToScreen", "SetMovable", "EnableMouse", "RegisterForDrag" }) do
            frame[method] = function() end
        end
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:UnregisterEvent(event) self.events[event] = nil end
        function frame:SetScript(event, callback) self.scripts[event] = callback end
        function frame:Hide()
            local wasShown = self.shown
            self.shown = false
            if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
        end
        function frame:Show() self.shown = true end
        function frame:IsShown() return self.shown end
        function frame:StartMoving() self.moving = true end
        function frame:StopMovingOrSizing() self.moving = false end
        function frame:CreateTexture()
            local item = region(); self.regions[#self.regions + 1] = item; return item
        end
        frame.CreateFontString = frame.CreateTexture
        state.frames[#state.frames + 1] = frame
        if name then env[name] = frame end
        return frame
    end

    local addon = {}
    for line in io.lines(root .. "/ForeverClassicUI.toc") do
        if line:match("%.lua$") then
            local chunk = assert(loadfile(root .. "/" .. line))
            setfenv(chunk, env)
            chunk("ForeverClassicUI", addon)
        end
    end
    state.env, state.addon = env, addon
    function state:emit(event, ...)
        for _, frame in ipairs(self.frames) do
            if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
        end
    end
    function state:command(input) self.env.SlashCmdList.FOREVERCLASSICUI(input) end
    state:emit("ADDON_LOADED", "ForeverClassicUI")
    return state
end

local function test(name, callback)
    callback()
    testCount = testCount + 1
    print("PASS " .. name)
end

test("no inspection or preview on load", function()
    local state = harness()
    equal(#state.frames, 1)
    equal(state.env.ForeverClassicUIDB.lastReport, nil)
    equal(state.env.ForeverClassicUIPreview, nil)
end)

test("status stores only build and UI capability report", function()
    local state = harness()
    state:command("  STATUS ")
    local report = state.env.ForeverClassicUIDB.lastReport
    equal(report.client.interfaceVersion, 11509)
    equal(report.client.locale, "frFR")
    equal(report.foreverCompatibility, "unvalidated")
    equal(report.frames.PlayerFrame.protected, true)
    equal(report.frames.Minimap.protected, false)
    equal(report.frames.TargetFrame.forbidden, true)
    equal(report.frames.TargetFrame.protected, nil)
    equal(report.frames.QuestFrame.inspection, "unavailable")
    equal(report.frames.WorldMapFrame.present, false)
    equal(report.api.issecretvalue, true)
    equal(report.api.C_Secrets, true)
    equal(state.sensitiveCalls, 0)
    equal(state.nativeMutations, 0)
    assert(#state.messages >= 4)
end)

test("inspect handles optional APIs missing and remains read only in combat", function()
    local state = harness()
    state.env.issecretvalue = nil
    state.env.C_Secrets = nil
    state.combat = true
    state:command("inspect")
    equal(state.env.ForeverClassicUIDB.lastReport.api.issecretvalue, false)
    equal(state.env.ForeverClassicUIDB.lastReport.api.C_Secrets, false)
    equal(state.sensitiveCalls, 0)
    equal(state.nativeMutations, 0)
    assert(#state.messages >= #state.addon:GetModule("Diagnostics").frameNames)
end)

test("report survives simulated SavedVariables reload without new scan", function()
    local first = harness()
    first:command("status")
    local persisted = clone(first.env.ForeverClassicUIDB)
    local reloaded = harness(persisted)
    equal(reloaded.env.ForeverClassicUIDB, persisted)
    equal(reloaded.env.ForeverClassicUIDB.lastReport.client.build, "69722")
    equal(#reloaded.messages, 0)
end)

test("preview cannot be created or opened in combat", function()
    local state = harness()
    state.combat = true
    state:command("preview")
    equal(state.env.ForeverClassicUIPreview, nil)
    equal(#state.frames, 1)
    equal(#state.env.UISpecialFrames, 0)
end)

test("preview closes on combat and can later reopen only on request", function()
    local state = harness()
    state:command("preview")
    local panel = state.env.ForeverClassicUIPreview
    equal(panel:IsShown(), true)
    equal(state.env.UISpecialFrames[1], "ForeverClassicUIPreview")
    panel.scripts.OnDragStart(panel)
    equal(panel.moving, true)
    state.combat = true
    state:emit("PLAYER_REGEN_DISABLED")
    equal(panel:IsShown(), false)
    equal(panel.moving, false)
    state:command("preview")
    equal(panel:IsShown(), false)
    state.combat = false
    state:emit("PLAYER_REGEN_ENABLED")
    equal(panel:IsShown(), false)
    state:command("preview")
    equal(panel:IsShown(), true)
    equal(#state.env.UISpecialFrames, 1)
    state:command("hide")
    equal(panel:IsShown(), false)
    equal(state.nativeMutations, 0)
    equal(state.sensitiveCalls, 0)
end)

test("native and exported media preserve intended paths", function()
    local media = harness().addon:GetModule("Media")
    equal(media:Resolve("targetFrame"), "Interface\\TargetingFrame\\UI-TargetingFrame")
    media:SetSource("local")
    equal(media:Resolve("talentBorder"), "Interface\\AddOns\\ForeverClassicUI\\Media\\interface\\talentframe\\ui-talentframe-botleft.blp")
    assert(not pcall(function() media:SetSource("unknown") end))
end)

print(string.format("%d behavioral tests passed under %s", testCount, _VERSION))
