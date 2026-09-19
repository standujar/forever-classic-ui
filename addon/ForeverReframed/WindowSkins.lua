-- SPDX-License-Identifier: MIT
local _, Addon = ...
local Skins = Addon:RegisterModule("WindowSkins", {})

-- Observed in the extracted Forever 1.60.1 UI: the allowlisted ordinary
-- windows inherit portrait/ButtonFrame NineSlice chrome; WorldMapFrame uses
-- BorderFrame.NineSlice. Do not extend this to every frame with a NineSlice:
-- bags and loot, for example, crop their corners dynamically during layout.
-- Keep their entire top decoration, portrait, title, controls and content.
-- The five custom regions are outside the native frame's content rectangle.
local pieces = { "LeftEdge", "RightEdge", "BottomEdge", "BottomLeftCorner", "BottomRightCorner" }
local borderFile = "Interface\\AddOns\\" .. Addon.name .. "\\Media\\interface\\dialogframe\\ui-dialogbox-border.blp"
local edgeSize = 16
local supportedBuilds = { ["69893"] = true, ["69913"] = true }

local function supportedBuild()
    if type(GetBuildInfo) ~= "function" or type(CreateFrame) ~= "function" then
        return false, "Required frame APIs are unavailable."
    end
    local version, build, _, interface = GetBuildInfo()
    if version ~= "1.60.1" or not supportedBuilds[tostring(build)] or interface ~= 16001 then
        return false, "Window borders require Forever 1.60.1 build 69893 or 69913 (TOC 16001)."
    end
    return true
end

local function safeFrame(frame)
    if not frame then return false end
    -- Keep all inspection and boolean conversion within pcall, including any
    -- failure caused by inaccessible values on a future client.
    local ok, safe = pcall(function()
        return type(frame.IsForbidden) == "function" and not frame:IsForbidden()
            and type(frame.IsProtected) == "function" and not frame:IsProtected()
    end)
    return ok and safe == true
end

local function textureAlpha(texture)
    local ok, alpha = pcall(function()
        if not texture or type(texture.GetObjectType) ~= "function"
            or texture:GetObjectType() ~= "Texture"
            or type(texture.GetAlpha) ~= "function" or type(texture.SetAlpha) ~= "function" then return nil end
        if type(texture.IsForbidden) == "function" and texture:IsForbidden() then return nil end
        if type(texture.IsProtected) == "function" and texture:IsProtected() then return nil end
        local value = texture:GetAlpha()
        if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
        if type(value) ~= "number" or value < 0 or value > 1 then return nil end
        return value
    end)
    if ok then return alpha end
end

local function resolveTarget(descriptor)
    local root = _G[descriptor.frameName]
    if not root then return nil, "waiting" end
    if not safeFrame(root) then return nil, "The native window is protected or cannot be inspected." end
    local chrome = root
    if descriptor.borderChild then chrome = root[descriptor.borderChild] end
    if not safeFrame(chrome) then return nil, "The window border is protected or unavailable." end
    local slice = chrome.NineSlice
    if not safeFrame(slice) or type(slice.GetFrameLevel) ~= "function"
        or type(chrome.HookScript) ~= "function" then
        return nil, "The observed NineSlice window structure is unavailable."
    end
    local decorations = {}
    for _, name in ipairs(pieces) do
        local texture = slice[name]
        local alpha = textureAlpha(texture)
        if alpha == nil then return nil, "Unsupported window decoration: " .. name end
        decorations[#decorations + 1] = { texture = texture, alpha = alpha }
    end
    return { root = root, chrome = chrome, slice = slice, decorations = decorations }
end

local function makeOverlay(target)
    local overlay = CreateFrame("Frame", nil, target.slice)
    overlay:Hide()
    overlay:EnableMouse(false)
    overlay:SetAllPoints(target.chrome)
    -- Under the preserved native top decoration, and with no interactive area.
    overlay:SetFrameLevel(math.max(0, target.slice:GetFrameLevel() - 1))
    local function region()
        local texture = overlay:CreateTexture(nil, "BORDER")
        texture:SetTexture(borderFile)
        return texture
    end
    -- UV rectangles are the five segments of the original 256 x 32 Classic
    -- dialog border artwork, with a two-pixel sampling inset. No top is drawn.
    local left = region()
    left:SetWidth(edgeSize)
    left:SetPoint("TOPRIGHT", target.chrome, "TOPLEFT", 0, -64)
    left:SetPoint("BOTTOMRIGHT", target.chrome, "BOTTOMLEFT", 0, 0)
    left:SetTexCoord(2 / 256, 30 / 256, 2 / 32, 30 / 32)
    local right = region()
    right:SetWidth(edgeSize)
    right:SetPoint("TOPLEFT", target.chrome, "TOPRIGHT", 0, -32)
    right:SetPoint("BOTTOMLEFT", target.chrome, "BOTTOMRIGHT", 0, 0)
    right:SetTexCoord(34 / 256, 62 / 256, 2 / 32, 30 / 32)
    local bottom = region()
    bottom:SetHeight(edgeSize)
    bottom:SetPoint("TOPLEFT", target.chrome, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("TOPRIGHT", target.chrome, "BOTTOMRIGHT", 0, 0)
    bottom:SetTexCoord(98 / 256, 30 / 32, 126 / 256, 30 / 32,
        98 / 256, 2 / 32, 126 / 256, 2 / 32)
    local bottomLeft = region()
    bottomLeft:SetSize(edgeSize, edgeSize)
    bottomLeft:SetPoint("TOPRIGHT", target.chrome, "BOTTOMLEFT", 0, 0)
    bottomLeft:SetTexCoord(194 / 256, 222 / 256, 2 / 32, 30 / 32)
    local bottomRight = region()
    bottomRight:SetSize(edgeSize, edgeSize)
    bottomRight:SetPoint("TOPLEFT", target.chrome, "BOTTOMRIGHT", 0, 0)
    bottomRight:SetTexCoord(226 / 256, 254 / 256, 2 / 32, 30 / 32)
    return overlay
end

local function restore(descriptor)
    local state = descriptor.state
    if not state or not state.applied then return true end
    if Addon:IsInCombat() then return false, "combat" end
    if not safeFrame(state.root) or not safeFrame(state.chrome) or not safeFrame(state.slice) then
        return false, "The window cannot be safely restored yet."
    end
    -- Validate all destinations before changing any native decoration.
    for _, saved in ipairs(state.decorations) do
        if textureAlpha(saved.texture) == nil then return false, "A decoration cannot be safely restored yet." end
    end
    local ok = pcall(function()
        state.overlay:Hide()
        for _, saved in ipairs(state.decorations) do saved.texture:SetAlpha(saved.alpha) end
    end)
    if not ok then return false, "The window border could not be fully restored." end
    state.applied = false
    return true
end

local function apply(descriptor)
    local supported, reason = supportedBuild()
    if not supported then return false, reason end
    if Addon:IsInCombat() then return false, "combat" end
    local target
    target, reason = resolveTarget(descriptor)
    if not target then return false, reason end
    local state = descriptor.state
    if state and (state.chrome ~= target.chrome or state.slice ~= target.slice) then
        local restored
        restored, reason = restore(descriptor)
        if not restored then return false, reason end
        descriptor.state = nil
        state = nil
    end
    if not state then
        local ok, overlay = pcall(makeOverlay, target)
        if not ok then return false, "Could not create the Classic window border." end
        state = target
        state.overlay = overlay
        state.applied = false
        descriptor.state = state
    end
    if not state.applied then
        -- Take a fresh baseline on each enable, never overwrite it while active.
        state.decorations = target.decorations
    end
    if not descriptor.hooked then descriptor.hooked = {} end
    if not descriptor.hooked[state.chrome] then
        state.chrome:HookScript("OnShow", function()
            local engine = Addon:GetModule("Restoration")
            if engine and engine:IsSelected(descriptor.id) then engine:Reconcile() end
        end)
        descriptor.hooked[state.chrome] = true
    end
    state.applied = true
    local ok = pcall(function()
        for _, saved in ipairs(state.decorations) do saved.texture:SetAlpha(0) end
        state.overlay:Show()
    end)
    if not ok then
        restore(descriptor)
        return false, "Could not apply the Classic window border."
    end
    return true
end

function Skins:Initialize()
    local engine = Addon:GetModule("Restoration")
    assert(engine and type(engine.Register) == "function", "Restoration must be loaded before WindowSkins")
    local windows = {
        { id = "quest_window", label = "Quest window border", frameName = "QuestFrame" },
        { id = "player_spells_window", label = "Talents and spellbook window border", frameName = "PlayerSpellsFrame" },
        { id = "world_map_window", label = "World map window border", frameName = "WorldMapFrame", borderChild = "BorderFrame", group = "maps" },
        -- Camelot CharacterFrame inherits PortraitFrameBaseTemplate. SkillsFrame
        -- is its content tab, so keep a single choice for the shared border.
        { id = "character_window", label = "Character and skills window border", frameName = "CharacterFrame" },
        -- ProfessionsFrameBase and InspectRecipeFrame inherit portrait chrome;
        -- recipe buttons, crafting operations and their content stay native.
        { id = "professions_window", label = "Professions window border", frameName = "ProfessionsFrame" },
        { id = "inspect_recipe_window", label = "Recipe inspection window border", frameName = "InspectRecipeFrame" },
        { id = "merchant_window", label = "Merchant window border", frameName = "MerchantFrame" },
        { id = "mail_window", label = "Mailbox window border", frameName = "MailFrame" },
        { id = "open_mail_window", label = "Open mail window border", frameName = "OpenMailFrame" },
        { id = "social_window", label = "Friends and social window border", frameName = "FriendsFrame" },
        { id = "gossip_window", label = "NPC conversation window border", frameName = "GossipFrame" },
        { id = "trade_window", label = "Trade window border", frameName = "TradeFrame" },
        { id = "auction_house_window", label = "Auction house window border", frameName = "AuctionHouseFrame" },
        { id = "bank_window", label = "Bank window border", frameName = "BankFrame" },
        { id = "trainer_window", label = "Trainer window border", frameName = "ClassTrainerFrame" },
        { id = "item_text_window", label = "Books and letters window border", frameName = "ItemTextFrame" },
    }
    for _, descriptor in ipairs(windows) do
        descriptor.group = descriptor.group or "windows"
        descriptor.description = "Classic side and bottom borders. Keeps the native top, portrait, buttons, size and content layout."
        descriptor.IsSupported = supportedBuild
        descriptor.Apply = apply
        descriptor.Revert = restore
        engine:Register(descriptor)
    end
end
