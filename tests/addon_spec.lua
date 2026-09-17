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
    equal(state.env.ForeverClassicUIDB.lastReport.api.issecretvalue, false)
    equal(state.env.ForeverClassicUIDB.lastReport.api.C_Secrets, false)
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
    local report = state.env.ForeverClassicUIDB.lastReport
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

local function withSettings(env, state)
    state.settingsCalls = { canvas = 0, category = 0, open = 0 }
    env.Settings = {
        RegisterCanvasLayoutCategory = function(panel, label)
            state.settingsCalls.canvas = state.settingsCalls.canvas + 1
            equal(label, "Forever Classic UI")
            state.settingsPanel = panel
            return { GetID = function() return 17 end }
        end,
        RegisterAddOnCategory = function(category)
            state.settingsCalls.category = state.settingsCalls.category + 1
            equal(category:GetID(), 17)
        end,
        OpenToCategory = function(id)
            equal(id, 17)
            state.settingsCalls.open = state.settingsCalls.open + 1
        end,
    }
end

test("Settings registers once and both slash commands open its native category", function()
    local state = harness(nil, withSettings)
    local settings = state.addon:GetModule("Settings")
    equal(state.settingsCalls.canvas, 1)
    equal(state.settingsCalls.category, 1)
    equal(state.settingsCalls.open, 0)
    equal(settings.panel:IsShown(), false)
    state:emit("PLAYER_LOGIN")
    state:emit("ADDON_LOADED", "Blizzard_PlayerSpells")
    state:command("")
    state:command(" settings ")
    equal(state.settingsCalls.open, 2)
    equal(state.settingsCalls.canvas, 1)
    equal(state.settingsCalls.category, 1)
    equal(state.nativeMutations, 0)
end)

test("Settings appears after its API arrives and handles unavailable APIs gracefully", function()
    local state = harness()
    local settings = state.addon:GetModule("Settings")
    equal(settings.panel, nil)
    state:command("")
    equal(settings.panel, nil)
    assert(state.messages[#state.messages]:find("not available", 1, true))
    withSettings(state.env, state)
    state.combat = true
    state:command("settings")
    state:emit("ADDON_LOADED", "Blizzard_Settings")
    equal(state.settingsCalls.canvas, 0)
    state.combat = false
    state:emit("PLAYER_REGEN_ENABLED")
    equal(state.settingsCalls.canvas, 1)
    equal(state.settingsCalls.category, 1)
    state:command("settings")
    equal(state.settingsCalls.open, 1)
end)

test("Settings registration failure retries without duplicating the native category", function()
    local attempts = 0
    local state = harness(nil, function(env, current)
        withSettings(env, current)
        local register = env.Settings.RegisterAddOnCategory
        env.Settings.RegisterAddOnCategory = function(category)
            attempts = attempts + 1
            if attempts == 1 then error("Settings registration temporarily unavailable") end
            register(category)
        end
    end)
    local settings = state.addon:GetModule("Settings")
    equal(settings.registered, nil)
    equal(state.settingsCalls.canvas, 1)
    state:emit("PLAYER_LOGIN")
    equal(settings.registered, true)
    equal(state.settingsCalls.canvas, 1)
    equal(state.settingsCalls.category, 1)
    equal(attempts, 2)
    state:command("settings")
    equal(attempts, 2)
    equal(state.settingsCalls.open, 1)
end)

test("a failed settings panel stays hidden and is not repeatedly reconstructed", function()
    local attempts = 0
    local state = harness(nil, function(env, current)
        withSettings(env, current)
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
    equal(state.env.ForeverClassicUISettingsPanel:IsShown(), false)
    equal(attempts, 1)
    state:emit("PLAYER_LOGIN")
    state:emit("ADDON_LOADED", "AnotherBlizzardAddon")
    state:command("settings")
    equal(attempts, 1)
    equal(state.settingsCalls.canvas, 0)
    assert(state.messages[#state.messages]:find("Could not initialize", 1, true))
    state:command("status")
    equal(state.addon.db.lastReport.client.interfaceVersion, 11509)
end)

test("opening Settings handles a native API failure while diagnostics remain available", function()
    local state = harness(nil, withSettings)
    state.env.Settings.OpenToCategory = function() error("Settings cannot open yet") end
    equal(state.addon:GetModule("Settings"):Open(), false)
    assert(state.messages[#state.messages]:find("Could not open", 1, true))
    state:command("inspect")
    equal(state.addon.db.lastReport.client.interfaceVersion, 11509)
    equal(state.nativeMutations, 0)
end)

test("Settings checkbox callbacks save selections and reset restores native appearance", function()
    local state = harness(nil, withSettings)
    local engine = restoration(state)
    local settings = state.addon:GetModule("Settings")
    local calls = registerFixture(state)
    engine:Reconcile()
    local row = settings.rows.test_window
    equal(row.checkbox:IsEnabled(), false)
    settings.masterCheckbox:SetChecked(true)
    settings.masterCheckbox:Click()
    equal(engine:IsEnabled(), true)
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

local nativePieces = { "LeftEdge", "RightEdge", "BottomEdge", "BottomLeftCorner", "BottomRightCorner" }

local function withNativeWindows(env, state, region)
    env.GetBuildInfo = function() return "1.60.1", "69893", "Sep 17 2026", 16001 end
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
    for _, name in ipairs({ "QuestFrame", "PlayerSpellsFrame", "WorldMapFrame" }) do
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

test("all three window skins preserve exact alpha baselines through reapply and disable", function()
    local state = harness(nil, withNativeWindows)
    local engine = restoration(state)
    equal(state.nativeMutations, 0)
    engine:SetEnabled(true)
    local cases = {
        { "quest_window", "QuestFrame" },
        { "player_spells_window", "PlayerSpellsFrame" },
        { "world_map_window", "WorldMapFrame" },
    }
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

test("settings changes during combat defer every native window mutation", function()
    local state = harness(nil, function(env, current, region)
        withNativeWindows(env, current, region)
        withSettings(env, current)
    end)
    local engine = restoration(state)
    local settings = state.addon:GetModule("Settings")
    settings.masterCheckbox:SetChecked(true)
    settings.masterCheckbox:Click()
    local row = settings.rows.quest_window
    row.checkbox:SetChecked(true)
    row.checkbox:Click()
    equal(engine:GetStatus("quest_window"), "active")
    state.combat = true
    local before = state.nativeMutations
    row.checkbox:SetChecked(false)
    row.checkbox:Click()
    equal(engine:GetStatus("quest_window"), "pending")
    assert(row.status.text:find("Pending", 1, true))
    state.windows.QuestFrame.chrome.scripts.OnShow()
    settings.resetButton:Click()
    equal(state.nativeMutations, before)
    state.combat = false
    state:emit("PLAYER_REGEN_ENABLED")
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

print(string.format("%d behavioral tests passed under %s", testCount, _VERSION))
