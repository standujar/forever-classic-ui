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

local function harness(saved, configure)
    local state = { combat = false, frames = {}, messages = {}, sensitiveCalls = 0, nativeMutations = 0 }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.ForeverReframedDB = saved
    env.SlashCmdList = {}
    env.UISpecialFrames = {}
    env.UIParent = { GetHeight = function() return 1080 end, GetEffectiveScale = function() return 1 end }
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
        local item = { shown = true, alpha = 1, texCoord = { 0, 1, 0, 1 } }
        for _, method in ipairs({ "SetPoint", "ClearAllPoints", "SetSize", "SetWidth", "SetHeight", "SetJustifyH", "SetJustifyV", "SetAllPoints", "SetColorTexture", "SetTextColor", "SetWordWrap", "SetFontObject" }) do
            item[method] = function() end
        end
        item.SetText = function(self, text) self.text = text end
        item.SetTexture = function(self, texture) self.texture = texture end
        item.GetTexture = function(self) return self.texture end
        item.SetTexCoord = function(self, ...) self.texCoord = { ... } end
        item.GetTexCoord = function(self) return unpack(self.texCoord) end
        item.Show = function(self) self.shown = true end
        item.Hide = function(self) self.shown = false end
        item.IsShown = function(self) return self.shown end
        item.GetObjectType = function() return "Texture" end
        item.SetAlpha = function(self, alpha) self.alpha = alpha end
        item.GetAlpha = function(self) return self.alpha end
        item.GetStringHeight = function() return 18 end
        return item
    end

    env.CreateFrame = function(kind, name, parent, template)
        local frame = { kind = kind, name = name, parent = parent, template = template, shown = true, scripts = {}, events = {}, regions = {} }
        for _, method in ipairs({ "SetSize", "SetPoint", "SetAllPoints", "SetWidth", "SetHeight", "SetFrameStrata", "SetClampedToScreen", "SetMovable", "EnableMouse", "RegisterForDrag", "SetScrollChild", "SetNormalFontObject", "SetHighlightFontObject" }) do
            frame[method] = function() end
        end
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:UnregisterEvent(event) self.events[event] = nil end
        function frame:SetScript(event, callback) self.scripts[event] = callback end
        function frame:HookScript(event, callback)
            local original = self.scripts[event]
            self.scripts[event] = function(...)
                if original then original(...) end
                callback(...)
            end
        end
        function frame:Hide()
            local wasShown = self.shown
            self.shown = false
            if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
        end
        function frame:Show()
            local wasShown = self.shown
            self.shown = true
            if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
        end
        function frame:IsShown() return self.shown end
        function frame:IsVisible()
            if not self.shown then return false end
            if self.parent and self.parent.IsVisible then return self.parent:IsVisible() end
            return not self.parent or self.parent.shown ~= false
        end
        function frame:IsForbidden() return self.forbidden == true end
        function frame:IsProtected() return self.protected == true end
        function frame:GetEffectiveScale() return 1 end
        function frame:GetBottom() return self.bottom end
        function frame:GetTop() return self.top end
        function frame:SetChecked(value) self.checked = value and true or false end
        function frame:GetChecked() return self.checked end
        function frame:SetEnabled(value) self.enabled = value end
        function frame:IsEnabled() return self.enabled ~= false end
        function frame:Enable() self.enabled = true end
        function frame:Disable() self.enabled = false end
        function frame:SetText(text) self.text = text end
        function frame:GetName() return self.name end
        function frame:SetAlpha(alpha) self.alpha = alpha end
        function frame:SetSize(width, height) self.width, self.height = width, height end
        function frame:SetWidth(width) self.width = width end
        function frame:SetHeight(height) self.height = height end
        function frame:GetWidth() return self.width or 800 end
        function frame:GetHeight() return self.height or 600 end
        function frame:GetFrameLevel() return self.level or 1 end
        function frame:SetFrameLevel(level) self.level = level end
        function frame:ClearAllPoints() self.points = {} end
        function frame:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = { ... } end
        function frame:SetBackdrop(backdrop) self.backdrop = backdrop end
        function frame:Click()
            if self:IsEnabled() and self.scripts.OnClick then self.scripts.OnClick(self) end
        end
        function frame:StartMoving() self.moving = true end
        function frame:StopMovingOrSizing() self.moving = false end
        function frame:CreateTexture()
            local item = region(); self.regions[#self.regions + 1] = item; return item
        end
        frame.CreateFontString = frame.CreateTexture
        if kind == "CheckButton" then frame.Text = region() end
        state.frames[#state.frames + 1] = frame
        if name then env[name] = frame end
        return frame
    end

    if configure then configure(env, state, region) end
    local addon = {}
    for line in io.lines(root .. "/ForeverReframed.toc") do
        if line:match("%.lua$") then
            local chunk = assert(loadfile(root .. "/" .. line))
            setfenv(chunk, env)
            chunk("ForeverReframed", addon)
        end
    end
    state.env, state.addon = env, addon
    function state:emit(event, ...)
        for _, frame in ipairs(self.frames) do
            if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
        end
    end
    function state:command(input) self.env.SlashCmdList.FOREVERREFRAMED(input) end
    state:emit("ADDON_LOADED", "ForeverReframed")
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
    equal(state.env.ForeverReframedDB.lastReport, nil)
    equal(state.env.ForeverReframedPreview, nil)
end)

test("renamed addon leaves the legacy database frames and command namespace untouched", function()
    local previous = { schemaVersion = 1, settings = { enabled = true, modules = { quest_window = true } }, lastReport = { historical = true } }
    local previousPreview = {}
    local previousHandler = function() error("Unrelated legacy command invoked") end
    local state = harness(nil, function(env)
        env.ForeverClassicUIDB = previous
        env.ForeverClassicUIPreview = previousPreview
        env.SLASH_FOREVERCLASSICUI1 = "/legacy-other-addon"
        env.SlashCmdList.FOREVERCLASSICUI = previousHandler
    end)
    equal(state.addon.name, "ForeverReframed")
    equal(state.addon.db, state.env.ForeverReframedDB)
    assert(state.addon.db ~= previous)
    equal(state.addon.db.settings.enabled, false)
    equal(state.addon.db.settings.modules.quest_window, nil)
    equal(state.addon.db.lastReport, nil)
    state:command("status")
    state:command("preview")
    equal(state.env.ForeverClassicUIDB, previous)
    equal(previous.settings.enabled, true)
    equal(previous.settings.modules.quest_window, true)
    equal(previous.lastReport.historical, true)
    equal(state.env.ForeverClassicUIPreview, previousPreview)
    assert(state.env.ForeverReframedPreview ~= previousPreview)
    equal(state.env.SLASH_FOREVERCLASSICUI1, "/legacy-other-addon")
    equal(state.env.SlashCmdList.FOREVERCLASSICUI, previousHandler)
    equal(state.env.SLASH_FOREVERREFRAMED1, "/foreverui")
end)

test("status stores only build and UI capability report", function()
    local state = harness()
    state:command("  STATUS ")
    local report = state.env.ForeverReframedDB.lastReport
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
    equal(report.api.Settings_RegisterCanvasLayoutCategory, false)
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
    equal(state.env.ForeverReframedDB.lastReport.api.issecretvalue, false)
    equal(state.env.ForeverReframedDB.lastReport.api.C_Secrets, false)
    equal(state.sensitiveCalls, 0)
    equal(state.nativeMutations, 0)
    assert(#state.messages >= #state.addon:GetModule("Diagnostics").frameNames)
end)

test("beta report detects modern windows and Settings without invoking gameplay APIs", function()
    local state = harness()
    state.env.GetBuildInfo = function() return "1.60.1", "69893", "Sep 17 2026", 16001 end
    local function mustNotCall() error("Capability detection invoked an API") end
    state.env.Settings = {
        RegisterCanvasLayoutCategory = mustNotCall,
        RegisterAddOnCategory = mustNotCall,
        OpenToCategory = mustNotCall,
    }
    state.env.C_Traits = setmetatable({}, { __index = mustNotCall })
    state.env.C_NamePlate = setmetatable({}, { __index = mustNotCall })
    state.env.NamePlate1 = { IsForbidden = mustNotCall, IsProtected = mustNotCall }
    state.env.PlayerSpellsFrame = { IsProtected = function() return false end }
    state.env.QuestMapFrame = { IsProtected = function() return false end }
    state.env.FocusFrame = { IsProtected = function() return true end }
    state:command("inspect")
    local report = state.env.ForeverReframedDB.lastReport
    equal(report.client.interfaceVersion, 16001)
    equal(report.client.build, "69893")
    equal(report.frames.PlayerSpellsFrame.present, true)
    equal(report.frames.PlayerSpellsFrame.protected, false)
    equal(report.frames.QuestMapFrame.present, true)
    equal(report.frames.FocusFrame.protected, true)
    equal(report.frames.PlayerTalentFrame.present, false)
    equal(report.frames.NamePlate1, nil)
    equal(report.api.Settings_RegisterCanvasLayoutCategory, true)
    equal(report.api.Settings_RegisterAddOnCategory, true)
    equal(report.api.Settings_OpenToCategory, true)
    equal(report.foreverCompatibility, "unvalidated")
    equal(state.nativeMutations, 0)
    equal(state.sensitiveCalls, 0)
end)

test("report survives simulated SavedVariables reload without new scan", function()
    local first = harness()
    first:command("status")
    local persisted = clone(first.env.ForeverReframedDB)
    local reloaded = harness(persisted)
    equal(reloaded.env.ForeverReframedDB, persisted)
    equal(reloaded.env.ForeverReframedDB.lastReport.client.build, "69722")
    equal(#reloaded.messages, 0)
end)

test("preview cannot be created or opened in combat", function()
    local state = harness()
    state.combat = true
    state:command("preview")
    equal(state.env.ForeverReframedPreview, nil)
    equal(#state.frames, 1)
    equal(#state.env.UISpecialFrames, 0)
end)

test("preview closes on combat and can later reopen only on request", function()
    local state = harness()
    state:command("preview")
    local panel = state.env.ForeverReframedPreview
    equal(panel:IsShown(), true)
    equal(state.env.UISpecialFrames[1], "ForeverReframedPreview")
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
    equal(media:Resolve("talentBorder"), "Interface\\AddOns\\ForeverReframed\\Media\\interface\\talentframe\\ui-talentframe-botleft.blp")
    assert(not pcall(function() media:SetSource("unknown") end))
end)

local function restoration(state)
    return assert(state.addon:GetModule("Restoration"), "Restoration module was not loaded")
end

local function registerFixture(state, id, callbacks)
    local calls = { apply = 0, revert = 0, support = 0, visual = "native" }
    callbacks = callbacks or {}
    local descriptor = {
        id = id or "test_window", label = "Test window", group = "Windows",
        description = "Fixture with a reversible visual change",
        IsSupported = function(self)
            calls.support = calls.support + 1
            if callbacks.support then return callbacks.support(self, calls) end
            return true
        end,
        Apply = function(self)
            calls.apply = calls.apply + 1
            if callbacks.apply then return callbacks.apply(self, calls) end
            calls.visual = "classic"
            return true
        end,
        Revert = function(self)
            calls.revert = calls.revert + 1
            if callbacks.revert then return callbacks.revert(self, calls) end
            calls.visual = "native"
            return true
        end,
    }
    restoration(state):Register(descriptor)
    return calls, descriptor
end

test("setup migrates an existing report without enabling visual changes", function()
    local report = { client = { build = "previous" }, retained = true }
    local saved = { schemaVersion = 1, lastReport = report }
    local state = harness(saved)
    local engine = restoration(state)
    equal(state.addon.db, saved)
    equal(saved.lastReport, report)
    equal(engine:IsEnabled(), false)
    equal(type(saved.settings.modules), "table")
    local calls = registerFixture(state)
    engine:Reconcile()
    equal(calls.apply, 0)
    equal(calls.revert, 0)
    equal(engine:GetStatus("test_window"), "native")
    equal(state.nativeMutations, 0)
end)

test("master and individual selection both control restoration", function()
    local state = harness()
    local engine = restoration(state)
    local first = registerFixture(state, "first_window")
    local second = registerFixture(state, "second_window")
    engine:SetSelection("first_window", true)
    equal(engine:GetSelection("first_window"), true)
    equal(engine:IsSelected("first_window"), false)
    equal(first.apply, 0)
    engine:SetEnabled(true)
    equal(first.visual, "classic")
    equal(engine:IsSelected("first_window"), true)
    equal(engine:GetStatus("first_window"), "active")
    equal(second.apply, 0)
    engine:SetEnabled(false)
    equal(first.visual, "native")
    equal(engine:GetStatus("first_window"), "native")
    equal(engine:GetSelection("first_window"), true)
    engine:SetEnabled(true)
    equal(first.visual, "classic")
    engine:SetSelection("first_window", false)
    equal(first.visual, "native")
    equal(second.apply, 0)
end)

test("selections survive reload and reset preserves the diagnostic report", function()
    local report = { client = { build = "test" } }
    local state = harness({ schemaVersion = 1, lastReport = report })
    local engine = restoration(state)
    registerFixture(state)
    engine:SetSelection("test_window", true)
    engine:SetEnabled(true)
    local persisted = clone(state.addon.db)
    local reloaded = harness(persisted)
    local newEngine = restoration(reloaded)
    local calls = registerFixture(reloaded)
    newEngine:Reconcile()
    equal(newEngine:IsEnabled(), true)
    equal(newEngine:GetSelection("test_window"), true)
    equal(calls.visual, "classic")
    newEngine:Reset()
    equal(newEngine:IsEnabled(), false)
    equal(newEngine:GetSelection("test_window"), false)
    equal(calls.visual, "native")
    equal(persisted.lastReport.client.build, "test")
    equal(persisted.schemaVersion, 1)
end)

test("combat queues desired settings and applies only the latest choice", function()
    local state = harness()
    local engine = restoration(state)
    local calls = registerFixture(state)
    state.combat = true
    local supportBefore = calls.support
    engine:SetEnabled(true)
    engine:SetSelection("test_window", true)
    equal(engine:GetStatus("test_window"), "pending")
    engine:SetSelection("test_window", false)
    state:emit("ADDON_LOADED", "SomeDelayedBlizzardModule")
    state:emit("PLAYER_LOGIN")
    equal(calls.support, supportBefore)
    equal(calls.apply, 0)
    equal(calls.revert, 0)
    equal(state.addon.db.settings.enabled, true)
    equal(state.addon.db.settings.modules.test_window, false)
    state.combat = false
    state:emit("PLAYER_REGEN_ENABLED")
    equal(calls.visual, "native")
    equal(calls.apply, 0)
    engine:SetSelection("test_window", true)
    equal(calls.visual, "classic")
    state.combat = true
    local applyBefore, revertBefore = calls.apply, calls.revert
    engine:SetEnabled(false)
    engine:Reset()
    equal(engine:GetStatus("test_window"), "pending")
    equal(calls.visual, "classic")
    equal(calls.apply, applyBefore)
    equal(calls.revert, revertBefore)
    state.combat = false
    state:emit("PLAYER_REGEN_ENABLED")
    equal(calls.visual, "native")
    equal(calls.revert, revertBefore + 1)
end)

test("a selected window activates when its Blizzard module arrives", function()
    local state = harness()
    local engine = restoration(state)
    local loaded = false
    local calls = registerFixture(state, "delayed_window", {
        apply = function(_, counters)
            if not loaded then return false, "waiting" end
            counters.visual = "classic"
            return true
        end,
    })
    engine:SetSelection("delayed_window", true)
    engine:SetEnabled(true)
    equal(engine:GetStatus("delayed_window"), "waiting")
    equal(calls.visual, "native")
    loaded = true
    state:emit("ADDON_LOADED", "Blizzard_DelayedWindow")
    equal(engine:GetStatus("delayed_window"), "active")
    equal(calls.visual, "classic")
    calls.visual = "native" -- Blizzard rebuilt its decoration after opening.
    engine:Reconcile()
    equal(calls.visual, "classic")
end)

test("unsupported options cannot apply and support errors fail closed", function()
    local state = harness()
    local engine = restoration(state)
    local unsupported = registerFixture(state, "unsupported_window", {
        support = function() return false, "Unsupported client build" end,
    })
    local failed = registerFixture(state, "invalid_window", {
        support = function() error("Broken support probe") end,
    })
    engine:SetSelection("unsupported_window", true)
    engine:SetSelection("invalid_window", true)
    engine:SetEnabled(true)
    equal(engine:IsSupported("unsupported_window"), false)
    equal(engine:GetStatus("unsupported_window"), "unsupported")
    equal(unsupported.apply, 0)
    equal(failed.apply, 0)
    assert(engine:GetStatus("invalid_window") ~= "active")
end)

test("partial apply failures roll back before reporting an error", function()
    local state = harness()
    local engine = restoration(state)
    local calls = registerFixture(state, "broken_window", {
        apply = function(_, counters)
            counters.visual = "partially modified"
            error("Texture mutation failed")
        end,
    })
    engine:SetSelection("broken_window", true)
    engine:SetEnabled(true)
    equal(calls.revert, 1)
    equal(calls.visual, "native")
    equal(engine:GetStatus("broken_window"), "error")
end)

test("failed rollback remains tracked until disable can restore the window", function()
    local state = harness()
    local engine = restoration(state)
    local canRevert = false
    local calls = registerFixture(state, "stuck_window", {
        apply = function(_, counters)
            counters.visual = "partially modified"
            return false, "Failed during mutation"
        end,
        revert = function(_, counters)
            if not canRevert then return false, "Temporarily unavailable" end
            counters.visual = "native"
            return true
        end,
    })
    engine:SetSelection("stuck_window", true)
    engine:SetEnabled(true)
    equal(engine:GetStatus("stuck_window"), "error")
    engine:SetEnabled(false)
    equal(engine:GetStatus("stuck_window"), "error")
    equal(calls.visual, "partially modified")
    canRevert = true
    engine:Reconcile()
    equal(calls.visual, "native")
    equal(engine:GetStatus("stuck_window"), "native")
end)

local function withEditMode(env, state)
    state.editModeCalls = { open = 0, hooks = 0, settings = 0 }
    local manager = env.CreateFrame("Frame", "EditModeManagerFrame", env.UIParent)
    manager.width, manager.height = 510, 280
    manager.bottom, manager.top = 420, 700
    manager.shown, manager.active = false, false
    function manager:CanEnterEditMode() return state.canEnter ~= false end
    function manager:IsEditModeActive() return self.active end
    local hook = manager.HookScript
    function manager:HookScript(event, callback)
        state.editModeCalls.hooks = state.editModeCalls.hooks + 1
        hook(self, event, callback)
    end
    function manager:SetSize() error("Must not resize the native manager") end
    function manager:SetHeight() error("Must not resize the native manager") end
    env.ShowUIPanel = function(frame)
        equal(frame, manager)
        equal(state.combat, false)
        state.editModeCalls.open = state.editModeCalls.open + 1
        manager.active = true
        manager:Show()
    end
    env.Settings = {
        RegisterCanvasLayoutCategory = function()
            state.editModeCalls.settings = state.editModeCalls.settings + 1
            error("A separate settings category must not be created")
        end,
    }
    return manager
end

test("Classic controls belong to native Edit Mode with no separate Settings category", function()
    local state = harness(nil, withEditMode)
    local settings = state.addon:GetModule("Settings")
    local manager = state.env.EditModeManagerFrame
    equal(settings.registered, true)
    equal(settings.panel.parent, manager)
    equal(settings.panel.ignoreInLayout, true)
    equal(settings.panel:IsVisible(), false)
    equal(state.editModeCalls.settings, 0)
    equal(state.env.ForeverReframedSettingsPanel, nil)
    equal(state.env.SLASH_FOREVERREFRAMED1, "/foreverui")
    equal(state.env.SLASH_FOREVERREFRAMED2, nil)
    local hooks = state.editModeCalls.hooks
    state:emit("PLAYER_LOGIN")
    state:emit("ADDON_LOADED", "Blizzard_PlayerSpells")
    equal(state.editModeCalls.hooks, hooks)
    state:command("")
    state:command(" edit ")
    state:command("settings")
    equal(state.editModeCalls.open, 1)
    equal(settings.panel:IsVisible(), true)
    equal(state.nativeMutations, 0)
end)

test("late Edit Mode initialization waits until combat ends", function()
    local state = harness()
    local settings = state.addon:GetModule("Settings")
    state:command("")
    equal(settings.panel, nil)
    assert(#state.messages > 0)
    withEditMode(state.env, state)
    state.combat = true
    state:command("edit")
    state:emit("ADDON_LOADED", "Blizzard_EditMode")
    equal(settings.panel, nil)
    equal(state.editModeCalls.hooks, 0)
    state.combat = false
    state:emit("PLAYER_REGEN_ENABLED")
    equal(settings.registered, true)
    state:command("edit")
    equal(state.editModeCalls.open, 1)
end)

test("opening Edit Mode may load the missing Blizzard module outside combat", function()
    local loads = 0
    local state = harness(nil, function(env, current)
        env.C_AddOns = { LoadAddOn = function(name)
            equal(name, "Blizzard_EditMode")
            loads = loads + 1
            withEditMode(env, current)
            return true
        end }
    end)
    state.combat = true
    state:command("")
    equal(loads, 0)
    state.combat = false
    state:command("")
    equal(loads, 1)
    equal(state.editModeCalls.open, 1)
end)

test("native Edit Mode entry restrictions and UI errors leave diagnostics available", function()
    local state = harness(nil, withEditMode)
    local settings = state.addon:GetModule("Settings")
    state.canEnter = false
    equal(settings:Open(), false)
    equal(state.editModeCalls.open, 0)
    state.canEnter = true
    state.env.ShowUIPanel = function() error("UI unavailable") end
    equal(settings:Open(), false)
    equal(settings.panel:IsVisible(), false)
    state:command("inspect")
    equal(state.addon.db.lastReport.client.interfaceVersion, 11509)
end)

test("protected or forbidden Edit Mode managers are not modified", function()
    for _, key in ipairs({ "protected", "forbidden" }) do
        local state = harness(nil, function(env, current)
            withEditMode(env, current)[key] = true
        end)
        local settings = state.addon:GetModule("Settings")
        equal(settings.panel, nil)
        equal(state.editModeCalls.hooks, 0)
        equal(settings:Open(), false)
        equal(state.editModeCalls.open, 0)
    end
end)

test("failed Edit Mode control construction stays hidden without repeated attempts", function()
    local attempts = 0
    local state = harness(nil, function(env, current)
        withEditMode(env, current)
        local create = env.CreateFrame
        env.CreateFrame = function(kind, ...)
            if kind == "CheckButton" then
                attempts = attempts + 1
                error("Native checkbox template unavailable")
            end
            return create(kind, ...)
        end
    end)
    local settings = state.addon:GetModule("Settings")
    equal(settings.panel, nil)
    equal(attempts, 1)
    state:emit("PLAYER_LOGIN")
    state:emit("ADDON_LOADED", "AnotherBlizzardAddon")
    equal(settings:Open(), false)
    equal(attempts, 1)
    for _, frame in ipairs(state.frames) do
        if frame.parent == state.env.EditModeManagerFrame then equal(frame:IsVisible(), false) end
    end
    state:command("status")
    equal(state.addon.db.lastReport.client.interfaceVersion, 11509)
end)

test("controls follow a temporary native hide and reopen without a new Edit Mode entry", function()
    local state = harness(nil, withEditMode)
    local manager = state.env.EditModeManagerFrame
    local settings = state.addon:GetModule("Settings")
    state:command("")
    equal(settings.panel:IsVisible(), true)
    manager:Hide()
    equal(manager.active, true)
    equal(settings.panel:IsVisible(), false)
    manager:Show()
    equal(settings.panel:IsVisible(), true)
    manager.active = false
    manager:Hide()
    equal(settings.panel:IsVisible(), false)
end)

test("opening Edit Mode from the game menu shows the controls without a slash command", function()
    local state = harness(nil, withEditMode)
    local manager = state.env.EditModeManagerFrame
    state.env.ShowUIPanel(manager)
    local settings = state.addon:GetModule("Settings")
    equal(settings.panel:IsVisible(), true)
    assert(settings.note.text:find("Save/Revert", 1, true))
    state:command("inspect")
    equal(state.addon.db.lastReport.api.EditMode_controls_registered, true)
end)

test("attached controls move above a low native manager and leave its dimensions intact", function()
    local state = harness(nil, withEditMode)
    state:command("")
    local manager = state.env.EditModeManagerFrame
    local settings = state.addon:GetModule("Settings")
    equal(settings.panel.points[1][1], "TOPLEFT")
    manager.bottom, manager.top = 20, 300
    manager.scripts.OnDragStop(manager)
    equal(settings.panel.points[1][1], "BOTTOMLEFT")
    equal(settings.panel.points[1][2], manager)
    equal(settings.panel.points[1][3], "TOPLEFT")
    equal(manager:GetHeight(), 280)
    equal(manager:GetWidth(), 510)
    equal(settings.panel.ignoreInLayout, true)
    assert(settings.panel:GetHeight() <= 1080 - manager.top)
end)

test("hidden Edit Mode controls reject stale clicks", function()
    local state = harness(nil, withEditMode)
    local engine = restoration(state)
    registerFixture(state)
    state:command("")
    engine:SetEnabled(true)
    local settings = state.addon:GetModule("Settings")
    local row = settings.rows.test_window
    state.env.EditModeManagerFrame:Hide()
    row.checkbox:SetChecked(true)
    row.checkbox.scripts.OnClick(row.checkbox)
    settings.resetButton.scripts.OnClick(settings.resetButton)
    equal(engine:GetSelection("test_window"), false)
    equal(engine:IsEnabled(), true)
end)

test("expanded Edit Mode on a short display does not lose its native bottom controls", function()
    local state = harness(nil, withEditMode)
    state:command("")
    local manager = state.env.EditModeManagerFrame
    local settings = state.addon:GetModule("Settings")
    state.env.UIParent.GetHeight = function() return 768 end
    manager.bottom, manager.top = 118, 668
    state:emit("DISPLAY_SIZE_CHANGED")
    equal(settings.panel.points[1][1], "TOPLEFT")
    assert(settings.panel:GetHeight() <= 102, "The section must fit below the native buttons")
    equal(settings.panel:IsVisible(), true)
    assert(settings.content:GetHeight() > settings.panel:GetHeight(), "All controls remain accessible by scrolling")
    manager.bottom, manager.top = 20, 300
    state:emit("UI_SCALE_CHANGED")
    equal(settings.panel.points[1][1], "BOTTOMLEFT")
    state.combat = true
    state:emit("UI_SCALE_CHANGED")
    equal(settings.panel:IsVisible(), false)
end)

test("insufficient screen space hides addon controls and moving Edit Mode restores them", function()
    local state = harness(nil, withEditMode)
    local manager = state.env.EditModeManagerFrame
    local settings = state.addon:GetModule("Settings")
    state.env.UIParent.GetHeight = function() return 768 end
    manager.bottom, manager.top = 20, 750
    state:command("")
    equal(settings.panel:IsVisible(), false)
    settings.classicButton.scripts.OnClick(settings.classicButton)
    equal(restoration(state):IsEnabled(), false)
    manager.top = 300
    manager.scripts.OnDragStop(manager)
    equal(settings.panel:IsVisible(), true)
end)

test("Edit Mode checkbox choices apply immediately and reset restores native appearance", function()
    local state = harness(nil, withEditMode)
    local engine = restoration(state)
    local settings = state.addon:GetModule("Settings")
    local calls = registerFixture(state)
    engine:Reconcile()
    state:command("")
    local row = settings.rows.test_window
    equal(row.checkbox:IsEnabled(), false)
    settings.groupRows.windows.customizeButton:Click()
    equal(engine:IsEnabled(), false)
    equal(row.checkbox:IsEnabled(), true)
    row.checkbox:SetChecked(true)
    row.checkbox:Click()
    equal(engine:GetSelection("test_window"), true)
    equal(calls.visual, "classic")
    assert(row.status.text:find("active", 1, true))
    settings.resetButton:Click()
    equal(engine:IsEnabled(), false)
    equal(engine:GetSelection("test_window"), false)
    equal(calls.visual, "native")
    for _, descriptor in ipairs(engine:GetOptions()) do
        assert(not descriptor.id:find("nameplate", 1, true))
    end
end)

test("collapsed groups expose failed native restoration until recovery succeeds", function()
    local state = harness(nil, withEditMode)
    local engine = restoration(state)
    local settings = state.addon:GetModule("Settings")
    local canRestore = false
    local calls = registerFixture(state, "stuck_window", {
        revert = function(_, current)
            if not canRestore then return false, "Native border is temporarily unavailable." end
            current.visual = "native"
            return true
        end,
    })
    state:command("")
    engine:SetSelection("stuck_window", true)
    engine:SetEnabled(true)
    equal(calls.visual, "classic")
    equal(settings.rows.stuck_window:IsShown(), false)
    settings.restoreButton:Click()
    equal(engine:IsEnabled(), false)
    equal(engine:GetGroupSelection("windows"), "none")
    equal(engine:GetStatus("stuck_window"), "error")
    equal(calls.visual, "classic")
    equal(settings.rows.stuck_window:IsShown(), false)
    assert(settings.status.text:find("Needs attention", 1, true))
    assert(settings.groupRows.windows.status.text:find("Needs attention", 1, true))
    assert(not settings.groupRows.windows.status.text:find("Native appearance", 1, true))
    canRestore = true
    state:emit("ADDON_LOADED", "AnotherBlizzardAddon")
    equal(engine:GetStatus("stuck_window"), "native")
    equal(calls.visual, "native")
    assert(not settings.status.text:find("Needs attention", 1, true))
    assert(settings.groupRows.windows.status.text:find("Native appearance", 1, true))
end)

test("Edit Mode choices survive closing reopening and SavedVariables reload", function()
    local state = harness(nil, withEditMode)
    local engine = restoration(state)
    registerFixture(state)
    state:command("")
    engine:SetEnabled(true)
    engine:SetSelection("test_window", true)
    local manager = state.env.EditModeManagerFrame
    manager.active = false
    manager:Hide()
    equal(engine:GetSelection("test_window"), true)
    state:command("")
    equal(state.addon:GetModule("Settings").rows.test_window.checkbox:GetChecked(), true)
    local nextState = harness(clone(state.env.ForeverReframedDB), withEditMode)
    registerFixture(nextState)
    restoration(nextState):Reconcile()
    nextState:command("")
    local settings = nextState.addon:GetModule("Settings")
    equal(restoration(nextState):IsEnabled(), true)
    equal(settings.rows.test_window.checkbox:GetChecked(), true)
end)

test("unsupported Edit Mode checkboxes cannot enable a restoration module", function()
    local state = harness(nil, withEditMode)
    local engine = restoration(state)
    local calls = registerFixture(state, "unsupported_window", {
        support = function() return false, "Unsupported client" end,
    })
    state:command("")
    engine:SetEnabled(true)
    local row = state.addon:GetModule("Settings").rows.unsupported_window
    equal(row.checkbox:IsEnabled(), false)
    row.checkbox:SetChecked(true)
    row.checkbox:Click()
    equal(engine:GetSelection("unsupported_window"), false)
    equal(calls.apply, 0)
end)

local nativePieces = { "LeftEdge", "RightEdge", "BottomEdge", "BottomLeftCorner", "BottomRightCorner" }

local function withNativeWindows(env, state, region)
    env.GetBuildInfo = function() return "1.60.1", "69913", "Sep 18 2026", 16001 end
    env.issecretvalue = function(value)
        assert(type(value) == "number", "Only cosmetic alpha values should be inspected")
        return false
    end
    state.windows = {}
    local function nativeFrame()
        local frame = { scripts = {} }
        function frame:IsForbidden() return self.forbidden == true end
        function frame:IsProtected() return self.protected == true end
        function frame:GetFrameLevel() return 12 end
        function frame:HookScript(event, callback)
            local before = self.scripts[event]
            self.scripts[event] = function(...)
                if before then before(...) end
                callback(...)
            end
        end
        return frame
    end
    for _, name in ipairs({ "QuestFrame", "PlayerSpellsFrame", "WorldMapFrame", "CharacterFrame", "ProfessionsFrame", "InspectRecipeFrame", "MerchantFrame", "MailFrame", "OpenMailFrame", "FriendsFrame", "GossipFrame", "TradeFrame", "AuctionHouseFrame", "BankFrame", "ClassTrainerFrame", "ItemTextFrame" }) do
        local frame = nativeFrame()
        local chrome = frame
        if name == "WorldMapFrame" then
            chrome = nativeFrame()
            frame.BorderFrame = chrome
        end
        local slice = nativeFrame()
        chrome.NineSlice = slice
        local originals = {}
        for index, piece in ipairs(nativePieces) do
            local texture = region()
            texture.alpha = index / 6
            originals[piece] = texture.alpha
            function texture:SetAlpha(alpha)
                state.nativeMutations = state.nativeMutations + 1
                self.alpha = alpha
            end
            slice[piece] = texture
        end
        slice.TopEdge = { SetAlpha = function() error("Top decoration must stay native") end }
        state.windows[name] = { root = frame, chrome = chrome, slice = slice, originals = originals }
        env[name] = frame
    end
end

test("all sixteen window skins preserve exact alpha baselines through reapply and disable", function()
    local state = harness(nil, withNativeWindows)
    local engine = restoration(state)
    equal(state.nativeMutations, 0)
    engine:SetEnabled(true)
    local cases = {
        { "quest_window", "QuestFrame" },
        { "player_spells_window", "PlayerSpellsFrame" },
        { "world_map_window", "WorldMapFrame" },
        { "character_window", "CharacterFrame" },
        { "professions_window", "ProfessionsFrame" },
        { "inspect_recipe_window", "InspectRecipeFrame" },
        { "merchant_window", "MerchantFrame" },
        { "mail_window", "MailFrame" },
        { "open_mail_window", "OpenMailFrame" },
        { "social_window", "FriendsFrame" },
        { "gossip_window", "GossipFrame" },
        { "trade_window", "TradeFrame" },
        { "auction_house_window", "AuctionHouseFrame" },
        { "bank_window", "BankFrame" },
        { "trainer_window", "ClassTrainerFrame" },
        { "item_text_window", "ItemTextFrame" },
    }
    equal(#engine:GetOptions(), #cases)
    for _, case in ipairs(cases) do
        engine:SetSelection(case[1], true)
        equal(engine:GetStatus(case[1]), "active")
        local native = state.windows[case[2]]
        for _, piece in ipairs(nativePieces) do equal(native.slice[piece].alpha, 0) end
        native.slice.LeftEdge.alpha = 0.75 -- Simulate native decoration being refreshed.
        native.chrome.scripts.OnShow()
        equal(native.slice.LeftEdge.alpha, 0)
    end
    engine:SetEnabled(false)
    for _, case in ipairs(cases) do
        local native = state.windows[case[2]]
        for _, piece in ipairs(nativePieces) do equal(native.slice[piece].alpha, native.originals[piece]) end
        local before = state.nativeMutations
        native.chrome.scripts.OnShow()
        equal(state.nativeMutations, before, "Disabled hooks must be inert")
        equal(engine:GetStatus(case[1]), "native")
    end
    -- Capture a fresh baseline after the user disables and later re-enables.
    local quest = state.windows.QuestFrame
    quest.slice.LeftEdge.alpha = 0.9
    engine:SetEnabled(true)
    engine:SetEnabled(false)
    equal(quest.slice.LeftEdge.alpha, 0.9)
    equal(state.sensitiveCalls, 0)
end)

test("window skins wait for load-on-demand windows and reject protected or unknown builds", function()
    local state = harness(nil, withNativeWindows)
    local engine = restoration(state)
    local spells = state.env.PlayerSpellsFrame
    state.env.PlayerSpellsFrame = nil
    engine:SetSelection("player_spells_window", true)
    engine:SetEnabled(true)
    equal(engine:GetStatus("player_spells_window"), "waiting")
    equal(state.nativeMutations, 0)
    state.env.PlayerSpellsFrame = spells
    state:emit("ADDON_LOADED", "Blizzard_PlayerSpells")
    equal(engine:GetStatus("player_spells_window"), "active")
    engine:SetEnabled(false)
    spells.protected = true
    local before = state.nativeMutations
    engine:SetEnabled(true)
    equal(engine:GetStatus("player_spells_window"), "error")
    equal(state.nativeMutations, before)
    state.env.GetBuildInfo = function() return "1.60.2", "70000", "future", 16002 end
    engine:Reconcile()
    equal(engine:GetStatus("player_spells_window"), "unsupported")
    equal(state.nativeMutations, before)
end)

test("window skins roll back a partial native texture mutation", function()
    local state = harness(nil, withNativeWindows)
    local engine = restoration(state)
    local native = state.windows.QuestFrame
    local texture = native.slice.RightEdge
    local originalSetAlpha = texture.SetAlpha
    function texture:SetAlpha(alpha)
        if alpha == 0 then error("Simulated native texture failure") end
        originalSetAlpha(self, alpha)
    end
    engine:SetSelection("quest_window", true)
    engine:SetEnabled(true)
    equal(engine:GetStatus("quest_window"), "error")
    for _, piece in ipairs(nativePieces) do equal(native.slice[piece].alpha, native.originals[piece]) end
end)

test("Edit Mode controls hide in combat and stale clicks cannot change saved selections", function()
    local state = harness(nil, function(env, current, region)
        withNativeWindows(env, current, region)
        withEditMode(env, current)
    end)
    local engine = restoration(state)
    local settings = state.addon:GetModule("Settings")
    state:command("")
    settings.groupRows.windows.customizeButton:Click()
    local row = settings.rows.quest_window
    row.checkbox:SetChecked(true)
    row.checkbox:Click()
    equal(engine:GetStatus("quest_window"), "active")
    state.combat = true
    state:emit("PLAYER_REGEN_DISABLED")
    equal(settings.panel:IsVisible(), false)
    local before = state.nativeMutations
    row.checkbox:SetChecked(false)
    row.checkbox.scripts.OnClick(row.checkbox)
    settings.resetButton.scripts.OnClick(settings.resetButton)
    equal(engine:GetSelection("quest_window"), true)
    equal(engine:IsEnabled(), true)
    equal(state.nativeMutations, before)
    state.combat = false
    state:emit("PLAYER_REGEN_ENABLED")
    equal(settings.panel:IsVisible(), true)
    equal(row.checkbox:GetChecked(), true)
    settings.resetButton:Click()
    local native = state.windows.QuestFrame
    for _, piece in ipairs(nativePieces) do equal(native.slice[piece].alpha, native.originals[piece]) end
    equal(engine:GetStatus("quest_window"), "native")
end)

test("an active window returns to native if its client support is lost", function()
    local state = harness(nil, withNativeWindows)
    local engine = restoration(state)
    engine:SetSelection("world_map_window", true)
    engine:SetEnabled(true)
    equal(engine:GetStatus("world_map_window"), "active")
    state.env.GetBuildInfo = function() return "1.60.2", "70000", "future", 16002 end
    engine:Reconcile()
    equal(engine:GetStatus("world_map_window"), "unsupported")
    local native = state.windows.WorldMapFrame
    for _, piece in ipairs(nativePieces) do equal(native.slice[piece].alpha, native.originals[piece]) end
end)

test("group defaults inherit new modules and individual exceptions survive reload", function()
    local state = harness(nil, withNativeWindows)
    local engine = restoration(state)
    engine:SetGroupSelection("windows", true)
    equal(engine:IsEnabled(), true)
    equal(engine:GetGroupSelection("windows"), "all")
    equal(engine:GetSelection("world_map_window"), false)
    engine:SetSelection("quest_window", false)
    equal(engine:GetGroupSelection("windows"), "mixed")
    local calls = registerFixture(state, "future_window")
    engine:Reconcile()
    equal(calls.visual, "classic")
    local reloaded = harness(clone(state.addon.db), withNativeWindows)
    local fresh = restoration(reloaded)
    registerFixture(reloaded, "future_window")
    equal(fresh:GetSelection("quest_window"), false)
    equal(fresh:GetSelection("future_window"), true)
    fresh:SetGroupSelection("windows", false)
    equal(fresh:GetGroupSelection("windows"), "none")
    fresh:SetGroupSelection("windows", true)
    equal(fresh:GetSelection("quest_window"), true, "Choosing a whole group clears its old exceptions")
end)

test("global presets select every group and restore clears inherited and explicit choices", function()
    local state = harness(nil, withNativeWindows)
    local engine = restoration(state)
    engine:SetAll(true)
    equal(engine:GetGroupSelection("windows"), "all")
    equal(engine:GetGroupSelection("maps"), "all")
    local _, future = registerFixture(state, "future_unit")
    future.group = "unit_frames"
    equal(engine:GetSelection("future_unit"), true)
    engine:SetSelection("quest_window", false)
    engine:SetAll(false)
    equal(engine:IsEnabled(), false)
    equal(next(engine.config.modules), nil)
    equal(next(engine.config.groups), nil)
    equal(engine:GetSelection("future_unit"), false)
    for _, option in ipairs(engine:GetOptions()) do equal(engine:GetStatus(option.id), "native") end
end)

test("legacy module choices migrate without enabling new windows or losing reports", function()
    local state = harness({ schemaVersion = 1, lastReport = { retained = true }, settings = {
        enabled = true, modules = { quest_window = true, world_map_window = false },
    } }, withNativeWindows)
    local engine = restoration(state)
    equal(engine:GetStatus("quest_window"), "active")
    equal(engine:GetSelection("character_window"), false)
    equal(engine:GetSelection("world_map_window"), false)
    equal(next(engine.config.groups), nil)
    equal(state.addon.db.lastReport.retained, true)
end)

test("group selection during combat defers changes and respects final exceptions", function()
    local state = harness(nil, withNativeWindows)
    local engine = restoration(state)
    state.combat = true
    engine:SetAll(true)
    engine:SetSelection("quest_window", false)
    equal(state.nativeMutations, 0)
    equal(engine:GetStatus("character_window"), "pending")
    state.combat = false
    state:emit("PLAYER_REGEN_ENABLED")
    equal(engine:GetStatus("character_window"), "active")
    equal(engine:GetStatus("quest_window"), "native")
end)

test("grouped Edit Mode starts collapsed and Customize does not enable restoration", function()
    local state = harness(nil, function(env, current, region)
        withNativeWindows(env, current, region); withEditMode(env, current)
    end)
    local settings, engine = state.addon:GetModule("Settings"), restoration(state)
    state:command("")
    equal(#engine:GetGroups(), 4)
    equal(settings.rows.quest_window:IsShown(), false)
    equal(settings.groupRows.unit_frames.checkbox:IsEnabled(), false)
    equal(settings.groupRows.hud.customizeButton:IsEnabled(), false)
    settings.groupRows.windows.customizeButton:Click()
    equal(settings.rows.quest_window:IsShown(), true)
    equal(engine:IsEnabled(), false)
    settings.groupRows.windows.checkbox:SetChecked(true)
    settings.groupRows.windows.checkbox:Click()
    equal(engine:IsEnabled(), true)
    equal(engine:GetGroupSelection("windows"), "all")
    local checkbox = settings.rows.quest_window.checkbox
    checkbox:SetChecked(false); checkbox:Click()
    equal(settings.groupRows.windows.mixedMark:IsShown(), true)
    equal(settings.groupRows.windows.checkbox:GetChecked(), false)
    settings.groupRows.windows.customizeButton:Click()
    checkbox:SetChecked(true); checkbox.scripts.OnClick(checkbox)
    equal(engine:GetSelection("quest_window"), false, "Collapsed stale clicks must be inert")
    settings.classicButton:Click()
    equal(engine:GetSelection("world_map_window"), true)
    equal(engine:GetSelection("quest_window"), true)
    settings.restoreButton:Click()
    equal(engine:IsEnabled(), false)
end)

test("hidden and combat group controls reject stale preset and group clicks", function()
    local state = harness(nil, function(env, current, region)
        withNativeWindows(env, current, region); withEditMode(env, current)
    end)
    local settings, engine = state.addon:GetModule("Settings"), restoration(state)
    state:command("")
    for _, inCombat in ipairs({ false, true }) do
        state.combat = inCombat
        if inCombat then state:emit("PLAYER_REGEN_DISABLED") else state.env.EditModeManagerFrame:Hide() end
        local group = settings.groupRows.windows
        settings.classicButton.scripts.OnClick(settings.classicButton)
        group.checkbox:SetChecked(true); group.checkbox.scripts.OnClick(group.checkbox)
        group.customizeButton.scripts.OnClick(group.customizeButton)
        equal(engine:IsEnabled(), false)
        equal(engine:GetGroupSelection("windows"), "none")
        equal(settings.expandedGroups.windows, nil)
    end
end)

test("both observed builds are accepted and an unknown build stays unavailable", function()
    local state = harness(nil, withNativeWindows)
    local engine = restoration(state)
    for _, build in ipairs({ "69893", "69913" }) do
        state.env.GetBuildInfo = function() return "1.60.1", build, "observed", 16001 end
        equal(engine:IsSupported("character_window"), true)
    end
    state.env.GetBuildInfo = function() return "1.60.1", "69999", "unknown", 16001 end
    equal(engine:IsSupported("character_window"), false)
end)

test("additional window skins reject incomplete protected and secret decorations before mutation", function()
    local cases = {
        function(env) env.ProfessionsFrame.NineSlice = nil end,
        function(env) env.ProfessionsFrame.NineSlice.LeftEdge = nil end,
        function(env) env.ProfessionsFrame.protected = true end,
        function(env) env.ProfessionsFrame.NineSlice.forbidden = true end,
        function(env) env.issecretvalue = function() return true end end,
    }
    for _, change in ipairs(cases) do
        local state = harness(nil, withNativeWindows)
        change(state.env)
        local engine = restoration(state)
        engine:SetSelection("professions_window", true)
        engine:SetEnabled(true)
        equal(engine:GetStatus("professions_window"), "error")
        equal(state.nativeMutations, 0)
    end
end)

test("missing map border never falls back to a different root decoration", function()
    local state = harness(nil, withNativeWindows)
    local frame = state.env.WorldMapFrame
    frame.NineSlice = frame.BorderFrame.NineSlice
    frame.BorderFrame = nil
    local engine = restoration(state)
    engine:SetSelection("world_map_window", true)
    engine:SetEnabled(true)
    equal(engine:GetStatus("world_map_window"), "error")
    equal(state.nativeMutations, 0)
end)

print(string.format("%d behavioral tests passed under %s", testCount, _VERSION))
