-- tests/wow_mock.lua
-- A minimal stand-in for the parts of the WoW API that SpecSage touches.
--
-- This is not an emulator. It exists so the addon can be loaded and driven
-- outside the game, which catches load-order mistakes, nil API calls and bad
-- combat-log parsing without a 30GB client.

local mock = {}

--------------------------------------------------------------------------------
-- Clock
--------------------------------------------------------------------------------

mock.now = 1000

function GetTime()
    return mock.now
end

function mock.Advance(seconds)
    mock.now = mock.now + seconds
end

--------------------------------------------------------------------------------
-- Lua globals WoW provides
--------------------------------------------------------------------------------

-- WoW runs Lua 5.1 where unpack is a global; on 5.2+ it lives in table.
unpack = unpack or table.unpack

format = string.format
strjoin = function(sep, ...) return table.concat({ ... }, sep) end
tinsert = table.insert
tremove = table.remove

function tostringall(...)
    local out, count = {}, select("#", ...)
    for i = 1, count do
        out[i] = tostring((select(i, ...)))
    end
    return unpack(out, 1, count)
end

-- Lua 5.1 has no bit library; the addon only needs band over small flags.
bit = {
    band = function(a, b)
        local result, bitValue = 0, 1
        while a > 0 and b > 0 do
            if a % 2 == 1 and b % 2 == 1 then
                result = result + bitValue
            end
            a, b, bitValue = math.floor(a / 2), math.floor(b / 2), bitValue * 2
        end
        return result
    end,
}

-- Real CreateColor returns a ColorMixin object; SpecSage only ever hands the
-- result straight to Texture:SetGradient (see NewTexture below), so a plain
-- table carrying the four components is all this mock needs.
function CreateColor(r, g, b, a)
    return { r = r, g = g, b = b, a = a or 1 }
end

-- Reusable Font objects (UI/Codex.lua's "Blizzard Modern" pass builds a
-- handful once at load, via SetFontObject rather than a fresh CreateFont per
-- row/button).
mock.fonts = {}
function CreateFont(name)
    local font = { name = name }
    function font:SetFont(path, size, flags) self.font, self.fontSize, self.flags = path, size, flags end
    function font:GetFont() return self.font, self.fontSize, self.flags end
    function font:SetTextColor(r, g, b) self.color = { r, g, b } end
    mock.fonts[name] = font
    return font
end

--------------------------------------------------------------------------------
-- Widgets
--------------------------------------------------------------------------------

local function NewRegion(kind)
    local region = { kind = kind, shown = true, points = {} }

    function region:SetPoint(...) table.insert(self.points, { ... }) end
    function region:ClearAllPoints() self.points = {} end
    -- Anchors all four corners to `relativeTo`; recorded as a point so
    -- ClearAllPoints still clears it, matching the real API.
    function region:SetAllPoints(relativeTo)
        table.insert(self.points, { "ALL", relativeTo })
    end
    function region:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
    function region:SetSize(w, h) self.width, self.height = w, h end
    function region:SetWidth(w) self.width = w end
    function region:SetHeight(h) self.height = h end
    function region:GetWidth() return self.width or 0 end
    function region:GetHeight() return self.height or 0 end
    function region:SetAlpha(a) self.alpha = a end
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false end
    function region:IsShown() return self.shown end
    function region:SetShown(value) self.shown = value and true or false end
    -- Real IsObjectType also matches ancestor widget types (a Button
    -- IsObjectType("Frame") is true); this mock only ever needs an exact
    -- kind match (SkinButton in UI/Codex.lua asks "is this a Texture"), so
    -- that's all it implements.
    function region:IsObjectType(kind) return type(kind) == "string" and kind:lower() == self.kind end

    return region
end

local function NewFontString()
    local fs = NewRegion("fontstring")
    function fs:SetText(text) self.text = text end
    function fs:GetText() return self.text end
    function fs:SetJustifyH() end
    function fs:SetFont(path, size) self.font, self.fontSize = path, size end
    function fs:GetFont() return self.font or "Fonts\\FRIZQT__.TTF", self.fontSize or 12, "" end
    function fs:SetTextColor(r, g, b) self.color = { r, g, b } end
    function fs:SetFontObject(obj) self.fontObject = obj end
    return fs
end

local function NewTexture()
    local texture = NewRegion("texture")
    function texture:SetTexture(value) self.texture = value end
    function texture:SetTexCoord() end
    function texture:SetDesaturated(value) self.desaturated = value end
    function texture:SetColorTexture(r, g, b, a) self.colorTexture = { r, g, b, a } end
    function texture:SetGradient(orientation, colorA, colorB) self.gradient = { orientation, colorA, colorB } end
    function texture:SetBlendMode(mode) self.blendMode = mode end
    return texture
end

-- Real WoW's EditBox:SetFocus() is a documented no-op when the frame (or any
-- ancestor) is not shown. Walks the parent chain the way the client's own
-- effective-visibility check would, so a widget hidden only because its
-- parent dialog is hidden is still caught.
local function IsEffectivelyShown(frame)
    local current = frame
    while current do
        if current.shown == false then return false end
        current = current.parent
    end
    return true
end

-- Every template string this addon actually passes to CreateFrame. An
-- unlisted (typo'd, or newly introduced without checking what it provides in
-- the real client) template fails the run immediately rather than silently
-- granting whatever widget surface happens to be convenient.
local KNOWN_TEMPLATES = {
    BackdropTemplate = true,
    UIPanelScrollFrameTemplate = true,
    UIPanelCloseButton = true,
    UIPanelButtonTemplate = true,
    InputBoxTemplate = true,
    GameTooltipTemplate = true,
}

-- Button templates that wire up a label FontString, the same way the real
-- UIPanelButtonTemplate does. A bare CreateFrame("Button", ...) - or a
-- template not in this set - has no such FontString, so Button:SetText below
-- has nothing to write into: exactly the bug this table exists to catch.
local BUTTON_TEXT_TEMPLATES = {
    UIPanelButtonTemplate = true,
}

-- Iterates the (possibly comma-separated) parts of a `template` argument.
local function EachTemplate(template)
    local index = 0
    local parts = {}
    if template then
        for part in template:gmatch("[^,]+") do
            parts[#parts + 1] = part:match("^%s*(.-)%s*$")
        end
    end
    return function()
        index = index + 1
        return parts[index]
    end
end

mock.frames = {}

function CreateFrame(frameType, name, parent, template)
    if template then
        for part in EachTemplate(template) do
            assert(KNOWN_TEMPLATES[part],
                "CreateFrame: unregistered template '" .. tostring(part) .. "' - add it to "
                .. "tests/wow_mock.lua's KNOWN_TEMPLATES once you've checked what widget "
                .. "surface it actually provides in the real client")
        end
    end

    local frame = NewRegion("frame")
    frame.frameType, frame.name, frame.parent, frame.template = frameType, name, parent, template
    frame.scripts = {}
    frame.events = {}
    frame.children = {}

    function frame:SetScript(event, handler) self.scripts[event] = handler end
    function frame:GetScript(event) return self.scripts[event] end
    function frame:HookScript(event, handler) self.scripts[event] = handler end
    function frame:RegisterEvent(event)
        assert(type(event) == "string" and event ~= "", "bad event name")
        assert(mock.KNOWN_EVENTS[event], "unknown event: " .. event)
        self.events[event] = true
    end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:RegisterForDrag() end
    function frame:SetMovable() end
    function frame:SetClampedToScreen() end
    function frame:SetResizable() end
    function frame:EnableMouse(value) self.mouseEnabled = value end
    function frame:SetPropagateMouseClicks(value) self.propagateClicks = value end
    function frame:SetPropagateMouseMotion(value) self.propagateMotion = value end
    function frame:StartMoving() end
    function frame:StopMovingOrSizing() end
    function frame:SetScale(value) self.scale = value end
    function frame:GetScale() return self.scale or 1 end
    function frame:SetBackdrop(value) self.backdrop = value end
    function frame:SetBackdropColor(r, g, b, a) self.backdropColor = { r, g, b, a } end
    function frame:SetBackdropBorderColor() end
    function frame:SetFrameStrata() end
    function frame:SetFrameLevel() end

    -- Tooltip surface, for frames created with frameType "GameTooltip".
    frame.lines = {}
    function frame:SetOwner(owner, anchor)
        self.owner, self.anchor = owner, anchor
        self.lines = {}
        self.spellID = nil
    end
    function frame:ClearLines() self.lines = {}; self.spellID = nil end
    function frame:AddLine(text) table.insert(self.lines, { left = text }) end
    function frame:AddDoubleLine(left, right) table.insert(self.lines, { left = left, right = right }) end
    function frame:SetSpellByID(spellID)
        self.spellID = spellID
        local spell = mock.spells[spellID]
        table.insert(self.lines, { left = spell and spell.name or ("Spell " .. spellID) })
    end
    function frame:NumLines() return #self.lines end
    function frame:Dump()
        local out = {}
        for _, line in ipairs(self.lines) do
            out[#out + 1] = tostring(line.left) .. (line.right and ("=" .. tostring(line.right)) or "")
        end
        return out
    end

    function frame:CreateFontString()
        local fs = NewFontString()
        table.insert(self.children, fs)
        return fs
    end

    function frame:CreateTexture()
        local texture = NewTexture()
        table.insert(self.children, texture)
        return texture
    end

    -- Real GetRegions returns every Texture/FontString/Line region owned
    -- directly by this frame (not child frames, which GetChildren covers
    -- instead) - exactly what .children already tracks above.
    function frame:GetRegions() return unpack(self.children) end

    -- From here on the widget surface is keyed off frameType (and, for
    -- Button's label, template): a bare "Frame" gets none of this, matching
    -- the real client where these methods simply do not exist on the wrong
    -- widget subclass. An earlier version of this mock granted the full
    -- EditBox/ScrollFrame/Button surface to every frame regardless of type or
    -- template, which is exactly what let an untemplated, unfonted Codex
    -- button or editbox pass the test suite while rendering nothing in game.
    if frameType == "EditBox" then
        -- InputBoxTemplate is the only template here that provides a font by
        -- itself; anything else (including no template at all) needs an
        -- explicit SetFontObject call before it can render text, the same as
        -- the real client.
        local hasFont = false
        for part in EachTemplate(template) do
            if part == "InputBoxTemplate" then hasFont = true end
        end

        function frame:SetMultiLine(value) self.multiLine = value end
        function frame:SetAutoFocus(value) self.autoFocus = value end
        function frame:SetFontObject(obj)
            self.fontObject = obj
            if obj then hasFont = true end
        end
        function frame:SetFocus()
            assert(IsEffectivelyShown(self),
                "EditBox:SetFocus called while hidden (directly, or via a hidden "
                .. "ancestor) - SetFocus is a no-op on a hidden widget in the real "
                .. "client, so this box would never actually receive focus; show "
                .. "the frame first")
            self.focused = true
        end
        function frame:ClearFocus() self.focused = false end
        function frame:SetText(text)
            assert(hasFont,
                "EditBox:SetText called with no font set - call SetFontObject or use "
                .. "a font-providing template (e.g. InputBoxTemplate) first, or this "
                .. "cannot render text in the real client")
            self.text = text
        end
        function frame:GetText() return self.text or "" end
        -- Highlighting only actually selects anything once the box is
        -- focused; an unfocused HighlightText() call leaves nothing selected.
        function frame:HighlightText() self.highlighted = self.focused or false end
        function frame:SetMaxLetters(n) self.maxLetters = n end
        function frame:SetTextInsets() end
        function frame:SetCursorPosition() end
    elseif frameType == "ScrollFrame" then
        function frame:SetScrollChild(child) self.scrollChild = child end
        function frame:GetScrollChild() return self.scrollChild end
        function frame:SetVerticalScroll(value) self.vScroll = value end
        function frame:GetVerticalScroll() return self.vScroll or 0 end
        function frame:GetVerticalScrollRange() return self.vScrollRange or 0 end
        function frame:UpdateScrollChildRect() end
    elseif frameType == "Button" then
        function frame:RegisterForClicks() end
        function frame:SetNormalTexture() end
        function frame:SetHighlightTexture() end
        function frame:SetPushedTexture() end
        function frame:SetDisabledTexture() end
        function frame:SetHitRectInsets() end
        function frame:Enable() self.enabled = true end
        function frame:Disable() self.enabled = false end
        function frame:SetEnabled(value) self.enabled = value and true or false end
        function frame:IsEnabled() return self.enabled ~= false end

        -- A label FontString exists only when a text-capable template
        -- created one (real UIPanelButtonTemplate behaviour) or the caller
        -- wires one up explicitly via SetFontString (the real Button API) -
        -- never just because something is a Button.
        local label
        for part in EachTemplate(template) do
            if BUTTON_TEXT_TEMPLATES[part] then
                label = frame:CreateFontString()
            end
        end
        function frame:SetFontString(fs) label = fs end
        function frame:GetFontString() return label end
        function frame:SetText(text)
            assert(label,
                "Button:SetText called with no label FontString - use a text-capable "
                .. "template (e.g. UIPanelButtonTemplate) or call SetFontString first; "
                .. "a bare CreateFrame(\"Button\", ...) has no font string and renders "
                .. "no label at all in the real client")
            label:SetText(text)
        end
        -- Real Button:SetNormalFontObject/SetHighlightFontObject/
        -- SetDisabledFontObject each set the font used for one interaction
        -- state on the button's single label FontString; no-op without a
        -- label, same as the real client (nothing to apply a font to).
        function frame:SetNormalFontObject(obj) if label then label:SetFontObject(obj) end end
        function frame:SetHighlightFontObject(obj) if label then label:SetFontObject(obj) end end
        function frame:SetDisabledFontObject(obj) if label then label:SetFontObject(obj) end end
        function frame:GetText() return label and label:GetText() or nil end
    end

    if name then _G[name] = frame end
    table.insert(mock.frames, frame)
    return frame
end

UIParent = CreateFrame("Frame", "UIParent")

-- ESC closes any frame named here; the Codex registers itself into this so
-- ESC works without the addon needing its own keybind for it.
UISpecialFrames = {}

GameFontNormal = NewFontString()
GameFontNormalSmall = NewFontString()
GameFontHighlightSmall = NewFontString()
ChatFontNormal = NewFontString()

--------------------------------------------------------------------------------
-- Events
--
-- The addon guards RegisterEvent with pcall, so an unknown event would be
-- silently skipped in game. The mock asserts instead, turning a typo in an
-- event name into a loud test failure.
--------------------------------------------------------------------------------

mock.KNOWN_EVENTS = {}
for _, event in ipairs({
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "COMBAT_LOG_EVENT_UNFILTERED",
    "UNIT_STATS", "UNIT_AURA", "UNIT_MAXHEALTH", "UNIT_ATTACK_POWER",
    "COMBAT_RATING_UPDATE", "MASTERY_UPDATE", "SPEED_UPDATE",
    "LIFESTEAL_UPDATE", "AVOIDANCE_UPDATE",
    "PLAYER_EQUIPMENT_CHANGED", "PLAYER_AVG_ITEM_LEVEL_UPDATE",
    "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TALENT_UPDATE",
    -- Reserved for the Codex/Loadouts work: talent config changes.
    "TRAIT_CONFIG_UPDATED", "TRAIT_CONFIG_LIST_UPDATED",
    -- Modules/BiS.lua: fires once C_Item.RequestLoadItemDataByID's async
    -- fetch resolves, so Codex:OnBiSItemInfoReceived can re-render a
    -- checklist row that was still showing "Item 12345" when it was added.
    "GET_ITEM_INFO_RECEIVED",
}) do
    mock.KNOWN_EVENTS[event] = true
end

function mock.Fire(event, ...)
    for _, frame in ipairs(mock.frames) do
        if frame.events[event] and frame.scripts.OnEvent then
            frame.scripts.OnEvent(frame, event, ...)
        end
    end
end

-- Runs every frame's OnUpdate once, the way the client would.
function mock.Tick(elapsed)
    mock.Advance(elapsed or 0)
    for _, frame in ipairs(mock.frames) do
        if frame.shown and frame.scripts.OnUpdate then
            frame.scripts.OnUpdate(frame, elapsed or 0)
        end
    end
end

--------------------------------------------------------------------------------
-- Timers
--------------------------------------------------------------------------------

mock.tickers = {}

C_Timer = {
    NewTicker = function(interval, callback)
        local ticker = { interval = interval, callback = callback }
        function ticker:Cancel() self.cancelled = true end
        table.insert(mock.tickers, ticker)
        return ticker
    end,
    After = function(delay, callback)
        table.insert(mock.pending, { delay = delay, callback = callback })
    end,
}

mock.pending = {}

-- Runs every callback queued with C_Timer.After.
function mock.RunAfter()
    local queued = mock.pending
    mock.pending = {}
    for _, entry in ipairs(queued) do
        entry.callback()
    end
end

function mock.RunTickers()
    for _, ticker in ipairs(mock.tickers) do
        if not ticker.cancelled then ticker.callback() end
    end
end

--------------------------------------------------------------------------------
-- Combat log constants and flags
--------------------------------------------------------------------------------

COMBATLOG_OBJECT_AFFILIATION_MINE = 0x00000001
COMBATLOG_OBJECT_TYPE_PET = 0x00001000
COMBATLOG_OBJECT_TYPE_GUARDIAN = 0x00002000

CR_VERSATILITY_DAMAGE_DONE = 29
CR_VERSATILITY_DAMAGE_TAKEN = 31
CR_LIFESTEAL = 17
CR_AVOIDANCE = 21
CR_SPEED = 14
CR_CRIT_MELEE = 9
CR_CRIT_SPELL = 11
CR_HASTE_MELEE = 18
CR_HASTE_SPELL = 20
CR_MASTERY = 26

mock.combatLogPayload = {}

function CombatLogGetCurrentEventInfo()
    return unpack(mock.combatLogPayload, 1, mock.combatLogPayload.n or #mock.combatLogPayload)
end

-- Fires one combat log event with the given payload.
function mock.FireCombatLog(...)
    mock.combatLogPayload = { n = select("#", ...), ... }
    mock.Fire("COMBAT_LOG_EVENT_UNFILTERED")
end

--------------------------------------------------------------------------------
-- Character state
--------------------------------------------------------------------------------

mock.inCombat = false
mock.stats = { [1] = 1000, [2] = 8500, [3] = 12000, [4] = 900 }
mock.auras = {}

function InCombatLockdown() return mock.inCombat end
function UnitGUID(unit) return unit == "player" and "Player-1234-ABCDEF" or "Pet-0-1234" end
function UnitStat(_, index) return mock.stats[index] - 200, mock.stats[index], 200, 0 end
function UnitHealthMax() return 4250000 end
function UnitHealth() return 3100000 end
mock.armor = { base = 3000, effective = 4500, posBuff = 0 }
function UnitArmor()
    return mock.armor.base, mock.armor.effective, mock.armor.effective, mock.armor.posBuff, 0
end
function UnitLevel() return 80 end
function UnitEffectiveLevel() return 80 end

-- Main-hand / off-hand swing times, as the character sheet's Attack Speed.
mock.attackSpeed = { main = 1.99, off = 2.60 }
function UnitAttackSpeed() return mock.attackSpeed.main, mock.attackSpeed.off end

mock.attackPower = { base = 3000, posBuff = 819, negBuff = 0 }
function UnitAttackPower()
    return mock.attackPower.base, mock.attackPower.posBuff, mock.attackPower.negBuff
end
function GetSpellBonusDamage(school) return 3700 + school * 10 end

function GetDodgeChance() return 3.00 end
function GetParryChance() return 24.88 end
function GetBlockChance() return 33.66 end

-- Returns an effectiveness RATIO (0-1), the way the live API does; the
-- character sheet multiplies it by 100 for display. Deliberately not the old
-- armor/((85*level)+400) curve, which no longer matches the client.
C_PaperDollInfo = {
    GetArmorEffectiveness = function(armor, attackerLevel)
        assert(type(attackerLevel) == "number", "GetArmorEffectiveness needs an attacker level")
        local value = (armor or 0) / ((armor or 0) + 5000)
        return value
    end,
}

function GetAverageItemLevel() return 639.5, 636.2, 0 end
function GetCritChance() return 21.34 end
function GetSpellCritChance(school) return 18 + school end
function GetRangedCritChance() return 21.34 end
function GetHaste() return 14.77 end
function GetMasteryEffect() return 31.02 end
-- Real WoW returns a different bonus per rating index; ignoring the index
-- entirely (as an earlier version of this mock did) hid whether
-- Modules/Stats.lua's melee-vs-spell crit/haste rating selection
-- (Stats.lua:261-268) was actually picking the right index. Every index used
-- by the addon still resolves to a bonus; only crit-spell and haste-spell
-- differ from the rest, which is enough to tell them apart from their melee
-- counterparts in a test.
local RATING_BONUS_BY_INDEX = {
    [CR_CRIT_SPELL] = 6.25,
    [CR_HASTE_SPELL] = 8.10,
}
function GetCombatRatingBonus(index) return RATING_BONUS_BY_INDEX[index] or 4.5 end
function GetCombatRating(index) return 1000 + index end
function GetVersatilityBonus() return 3.1 end
function GetMastery() return 24.5 end
function GetLifesteal() return 2.4 end
function GetAvoidance() return 1.8 end
function GetSpeed() return 0.9 end
function GetSpecialization() return 2 end
-- Mutable rather than a hardcoded 2 (Agility): Modules/Stats.lua captures
-- this function's *value* once at load time (the "local X = ... or X"
-- pattern used throughout the addon), so a test that wants to exercise a
-- different primaryStat cannot swap out the global function afterwards - it
-- has to flip mock.playerPrimaryStat, which this same already-captured
-- closure reads fresh on every call.
mock.playerPrimaryStat = 2
function GetSpecializationInfo() return 252, "Frost", "desc", 135773, "DAMAGER", mock.playerPrimaryStat end

--------------------------------------------------------------------------------
-- Classes and specializations
--
-- Used by the Codex's class rail and by guide-data validation tooling, not by
-- the overlay itself. classID order matches Blizzard's (Warrior=1 ...
-- Evoker=13).
--------------------------------------------------------------------------------

mock.classes = {
    { name = "Warrior",     token = "WARRIOR",     id = 1 },
    { name = "Paladin",     token = "PALADIN",     id = 2 },
    { name = "Hunter",      token = "HUNTER",      id = 3 },
    { name = "Rogue",       token = "ROGUE",       id = 4 },
    { name = "Priest",      token = "PRIEST",      id = 5 },
    { name = "Death Knight", token = "DEATHKNIGHT", id = 6 },
    { name = "Shaman",      token = "SHAMAN",      id = 7 },
    { name = "Mage",        token = "MAGE",        id = 8 },
    { name = "Warlock",     token = "WARLOCK",     id = 9 },
    { name = "Monk",        token = "MONK",        id = 10 },
    { name = "Druid",       token = "DRUID",       id = 11 },
    { name = "Demon Hunter", token = "DEMONHUNTER", id = 12 },
    { name = "Evoker",      token = "EVOKER",      id = 13 },
}

function GetNumClasses() return #mock.classes end

function GetClassInfo(classID)
    local entry = mock.classes[classID]
    if not entry then return nil end
    return entry.name, entry.token, entry.id
end

-- The Codex defaults to the player's own class/spec on first open. Kept in
-- sync with mock.specializations[252] below (Death Knight) so that default
-- lands on a spec the mock actually knows about.
function UnitClass(unit)
    if unit ~= "player" then return nil end
    return "Death Knight", "DEATHKNIGHT", 6
end

-- Real client globals the Codex's class rail reads directly (not wrapped in
-- a namespace, so they must exist as plain globals here too). Colours are
-- close to Blizzard's but not pixel-exact — nothing in the addon depends on
-- the exact channel values, only on every class token resolving to *a* colour.
RAID_CLASS_COLORS = {
    WARRIOR     = { r = 0.78, g = 0.61, b = 0.43 },
    PALADIN     = { r = 0.96, g = 0.55, b = 0.73 },
    HUNTER      = { r = 0.67, g = 0.83, b = 0.45 },
    ROGUE       = { r = 1.00, g = 0.96, b = 0.41 },
    PRIEST      = { r = 1.00, g = 1.00, b = 1.00 },
    DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 },
    SHAMAN      = { r = 0.00, g = 0.44, b = 0.87 },
    MAGE        = { r = 0.41, g = 0.80, b = 0.94 },
    WARLOCK     = { r = 0.58, g = 0.51, b = 0.79 },
    MONK        = { r = 0.00, g = 1.00, b = 0.59 },
    DRUID       = { r = 1.00, g = 0.49, b = 0.04 },
    DEMONHUNTER = { r = 0.64, g = 0.19, b = 0.79 },
    EVOKER      = { r = 0.20, g = 0.58, b = 0.50 },
}

-- Texture coordinates into Interface\GLUES\CHARACTERCREATE\UI-CHARACTERCREATE-CLASSES,
-- the same class-icon atlas real WoW exposes this global for.
CLASS_ICON_TCOORDS = {
    WARRIOR     = { 0, 0.25, 0, 0.25 },
    MAGE        = { 0.25, 0.49609375, 0, 0.25 },
    ROGUE       = { 0.49609375, 0.7421875, 0, 0.25 },
    DRUID       = { 0.7421875, 0.98828125, 0, 0.25 },
    HUNTER      = { 0, 0.25, 0.25, 0.5 },
    SHAMAN      = { 0.25, 0.49609375, 0.25, 0.5 },
    PRIEST      = { 0.49609375, 0.7421875, 0.25, 0.5 },
    WARLOCK     = { 0.7421875, 0.98828125, 0.25, 0.5 },
    PALADIN     = { 0, 0.25, 0.5, 0.75 },
    DEATHKNIGHT = { 0.25, 0.49609375, 0.5, 0.75 },
    MONK        = { 0.49609375, 0.7421875, 0.5, 0.75 },
    DEMONHUNTER = { 0.7421875, 0.98828125, 0.5, 0.75 },
    EVOKER      = { 0, 0.25, 0.75, 1.0 },
}

-- A handful of specializations, enough to exercise the Codex/GuideStore
-- integration without hand-typing all 39 retail specs into the mock.
mock.specializations = {
    [71] = { id = 71, name = "Arms",       icon = 132355, role = "DAMAGER", classID = 1, primaryStat = 1 },
    [72] = { id = 72, name = "Fury",       icon = 132347, role = "DAMAGER", classID = 1, primaryStat = 1 },
    [73] = { id = 73, name = "Protection", icon = 134951, role = "TANK",    classID = 1, primaryStat = 1 },
    [250] = { id = 250, name = "Blood",     icon = 135771, role = "TANK",    classID = 6, primaryStat = 3 },
    [251] = { id = 251, name = "Frost",     icon = 135773, role = "DAMAGER", classID = 6, primaryStat = 3 },
    [252] = { id = 252, name = "Unholy",    icon = 135775, role = "DAMAGER", classID = 6, primaryStat = 3 },
}

function GetSpecializationInfoByID(specID)
    local spec = mock.specializations[specID]
    if not spec then return nil end
    -- Real signature: id, name, description, icon, role, primaryStat (6
    -- values). An earlier version of this mock returned 7, with classID
    -- inserted before primaryStat - nothing here reads position 6 today, but
    -- it would have silently misaligned any future caller that does.
    return spec.id, spec.name, spec.name, spec.icon, spec.role, spec.primaryStat
end

--------------------------------------------------------------------------------
-- Talent loadouts (C_ClassTalents / C_Traits)
--
-- Minimal stand-ins for the export/import surface Modules/Loadouts.lua will
-- need. Not a real talent-tree simulation: just enough to hand back an
-- opaque "current config" and echo an import string back out.
--------------------------------------------------------------------------------

mock.activeConfigID = 1

C_ClassTalents = {
    GetActiveConfigID = function() return mock.activeConfigID end,
    GetLastSelectedSavedConfigID = function() return mock.activeConfigID end,
}

mock.exportString = "SpecSage-mock-export-string"

C_Traits = {
    GetConfigInfo = function(configID)
        if configID ~= mock.activeConfigID then return nil end
        return { id = configID, name = "Active" }
    end,
    GenerateInspectImportString = function() return mock.exportString end,
    -- The current retail export API; Modules/Loadouts.lua tries this before
    -- falling back to GenerateInspectImportString, so both are defined here.
    GenerateImportString = function() return mock.exportString end,
}

--------------------------------------------------------------------------------
-- Spells and auras
--------------------------------------------------------------------------------

mock.spells = {
    [190319] = { name = "Combustion", icon = 135824 },
    [12472]  = { name = "Icy Veins", icon = 135838 },
    [377097] = { name = "Trinket Proc", icon = 136116 },
}

mock.cooldowns = {}

C_Spell = {
    GetSpellInfo = function(spellID)
        local spell = mock.spells[spellID]
        if not spell then return nil end
        return { name = spell.name, iconID = spell.icon, spellID = spellID }
    end,
    GetSpellTexture = function(spellID)
        local spell = mock.spells[spellID]
        return spell and spell.icon
    end,
    GetSpellCooldown = function(spellID)
        local cooldown = mock.cooldowns[spellID]
        if not cooldown then
            return { startTime = 0, duration = 0, isEnabled = true, modRate = 1 }
        end
        return { startTime = cooldown.start, duration = cooldown.duration, isEnabled = true, modRate = 1 }
    end,
}

C_UnitAuras = {
    GetPlayerAuraBySpellID = function(spellID)
        for _, aura in ipairs(mock.auras) do
            if aura.spellId == spellID then return aura end
        end
        return nil
    end,
}

AuraUtil = {
    -- Mirrors the real (unit, filter, maxCount, func, usePackedAura)
    -- signature: filter actually filters HELPFUL vs HARMFUL, maxCount
    -- actually caps how many auras the callback sees, and usePackedAura
    -- actually changes the callback's argument shape - instead of silently
    -- ignoring all three the way an earlier version of this mock did, which
    -- left HELPFUL filtering entirely unverified.
    ForEachAura = function(_, filter, maxCount, callback, usePackedAura)
        assert(filter == "HELPFUL" or filter == "HARMFUL",
            "ForEachAura filter must be HELPFUL or HARMFUL, got " .. tostring(filter))
        local wantHelpful = filter == "HELPFUL"
        local count = 0
        for _, aura in ipairs(mock.auras) do
            if (aura.isHelpful ~= false) == wantHelpful then
                local stop
                if usePackedAura then
                    stop = callback(aura)
                else
                    stop = callback(aura.name, aura.icon, aura.applications, nil,
                        aura.duration, aura.expirationTime, aura.sourceUnit, false, nil, nil, aura.spellId)
                end
                if stop then return end

                count = count + 1
                if maxCount and maxCount > 0 and count >= maxCount then return end
            end
        end
    end,
}

-- Adds a buff (or, with isHelpful=false, a debuff) to the player for the
-- duration of the test.
function mock.AddAura(spellID, duration, applications, isHelpful)
    local spell = mock.spells[spellID] or { name = "Spell " .. spellID, icon = 0 }
    table.insert(mock.auras, {
        spellId = spellID,
        name = spell.name,
        icon = spell.icon,
        duration = duration,
        expirationTime = mock.now + duration,
        applications = applications or 1,
        sourceUnit = "player",
        isHelpful = isHelpful ~= false,
    })
end

function mock.ClearAuras()
    mock.auras = {}
end

--------------------------------------------------------------------------------
-- Items (BiS checklist)
--
-- itemID-keyed fixtures a test can populate before exercising Modules/BiS.lua
-- or the Codex's BiS tab. Only the fields those actually read (name, quality)
-- are modelled; the rest of GetItemInfo's real ~11-value return is filled
-- with a placeholder so the shape still matches what the addon unpacks.
--------------------------------------------------------------------------------

mock.items = {
    [19019] = { name = "Thunderfury, Blessed Blade of the Windseeker", quality = 4 },
    [42] = { name = "Champion's Dreadful Gladiator's Pendant of Alacrity", quality = 3 },
}

C_Item = {
    GetItemInfo = function(itemID)
        local item = mock.items[itemID]
        if not item then return nil end
        return item.name, item.link or ("item:" .. itemID), item.quality or 1, item.level or 1,
            item.reqLevel or 1, item.itemType or "Miscellaneous", item.subType or "Junk",
            item.stackCount or 1, item.equipLoc or "", item.texture or 0, item.sellPrice or 0
    end,
    -- Records the request rather than doing anything with it: the real
    -- client's async fetch-then-fire-GET_ITEM_INFO_RECEIVED behaviour is
    -- simulated by a test populating mock.items and firing that event
    -- itself (mock.Fire("GET_ITEM_INFO_RECEIVED", itemID)), same as the
    -- existing item/spell/aura fixtures in this file.
    RequestLoadItemDataByID = function(itemID)
        table.insert(mock.itemLoadRequests, itemID)
    end,
}

mock.itemLoadRequests = {}

-- Approximates Blizzard's real item-quality colours (0=Poor..5=Legendary is
-- all the Codex needs to colour a BiS entry's name by).
ITEM_QUALITY_COLORS = {
    [0] = { r = 0.61, g = 0.61, b = 0.61 },
    [1] = { r = 1.00, g = 1.00, b = 1.00 },
    [2] = { r = 0.12, g = 1.00, b = 0.00 },
    [3] = { r = 0.00, g = 0.44, b = 0.87 },
    [4] = { r = 0.64, g = 0.21, b = 0.93 },
    [5] = { r = 1.00, g = 0.50, b = 0.00 },
}

-- Blizzard's real INVSLOT_* inventory slot IDs. Defined here independently
-- of Modules/BiS.lua's SLOT_INVENTORY_IDS (which now reads these same
-- globals rather than hardcoding its own numbers) so a wrong slot mapping in
-- the addon shows up as this file's tests indexing mock.equipped by the
-- *correct* named slot and getting no match, instead of both sides agreeing
-- on the same made-up literal by construction (the "permissive mock hides a
-- live bug" pattern from round 1's review).
INVSLOT_HEAD = 1
INVSLOT_NECK = 2
INVSLOT_SHOULDER = 3
INVSLOT_BODY = 4 -- shirt; not a BiS-trackable slot, listed for completeness
INVSLOT_CHEST = 5
INVSLOT_WAIST = 6
INVSLOT_LEGS = 7
INVSLOT_FEET = 8
INVSLOT_WRIST = 9
INVSLOT_HAND = 10
INVSLOT_FINGER1 = 11
INVSLOT_FINGER2 = 12
INVSLOT_TRINKET1 = 13
INVSLOT_TRINKET2 = 14
INVSLOT_BACK = 15
INVSLOT_MAINHAND = 16
INVSLOT_OFFHAND = 17

-- Equipped items, keyed by inventory slot ID (see Modules/BiS.lua's
-- SLOT_INVENTORY_IDS, and the INVSLOT_* constants just above, for which
-- numbers map to which gear slot).
mock.equipped = {}

function GetInventoryItemID(unit, invSlot)
    if unit ~= "player" then return nil end
    return mock.equipped[invSlot]
end

-- Bag contents, keyed by bag index then slot index: mock.bags[0] = { [3] =
-- 12345 } means bag 0 (the backpack) slot 3 holds itemID 12345. numSlots
-- defaults to the highest configured slot index so a test does not have to
-- set it explicitly for a simple one-item bag.
mock.bags = {}

C_Container = {
    GetContainerNumSlots = function(bag)
        local contents = mock.bags[bag]
        if not contents then return 0 end
        if contents.numSlots then return contents.numSlots end
        local highest = 0
        for slotIndex in pairs(contents) do
            if type(slotIndex) == "number" and slotIndex > highest then highest = slotIndex end
        end
        return highest
    end,
    GetContainerItemID = function(bag, slotIndex)
        local contents = mock.bags[bag]
        return contents and contents[slotIndex] or nil
    end,
}

--------------------------------------------------------------------------------
-- Tooltip
--
-- Records what was rendered so tests can assert on tooltip content.
--------------------------------------------------------------------------------

GameTooltip = {
    lines = {},
    shown = false,
}

function GameTooltip:SetOwner(owner, anchor)
    self.owner, self.anchor = owner, anchor
    self.lines = {}
    self.spellID = nil
    self.itemID = nil
end

function GameTooltip:ClearLines() self.lines = {} end

function GameTooltip:AddLine(text)
    table.insert(self.lines, { left = text })
end

function GameTooltip:AddDoubleLine(left, right)
    table.insert(self.lines, { left = left, right = right })
end

function GameTooltip:SetSpellByID(spellID)
    self.spellID = spellID
    local spell = mock.spells[spellID]
    table.insert(self.lines, { left = spell and spell.name or ("Spell " .. spellID) })
end

function GameTooltip:SetItemByID(itemID)
    self.itemID = itemID
    local item = mock.items[itemID]
    table.insert(self.lines, { left = item and item.name or ("Item " .. tostring(itemID)) })
end

function GameTooltip:Show() self.shown = true end
function GameTooltip:Hide() self.shown = false end

-- Returns the rendered tooltip as a flat list of "left=right" strings.
function GameTooltip:Dump()
    local out = {}
    for _, line in ipairs(self.lines) do
        out[#out + 1] = tostring(line.left) .. (line.right and ("=" .. tostring(line.right)) or "")
    end
    return out
end

--------------------------------------------------------------------------------
-- Addon metadata, settings, slash commands
--------------------------------------------------------------------------------

C_AddOns = {
    GetAddOnMetadata = function(_, field)
        if field == "Version" then return "1.0.0" end
        return nil
    end,
}

SlashCmdList = {}

MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }

-- Variable names passed to RegisterProxySetting, in order.
mock.settingsRegistered = {}

local function NewSettingsCategory(name)
    local category = { name = name, id = name }
    function category:GetID() return self.id end
    return category
end

Settings = {
    VarType = { Boolean = "boolean", Number = "number", String = "string" },

    RegisterVerticalLayoutCategory = function(name)
        local layout = { initializers = {} }
        function layout:AddInitializer(initializer)
            table.insert(self.initializers, initializer)
        end
        return NewSettingsCategory(name), layout
    end,

    -- Current signature: (category, variable, variableType, name, default, get, set)
    RegisterProxySetting = function(_, variable, variableType, name, default, get, set)
        assert(type(variableType) == "string",
            "RegisterProxySetting called with the legacy signature for " .. tostring(variable))
        assert(type(get) == "function", "missing getter for " .. tostring(variable))
        assert(type(set) == "function", "missing setter for " .. tostring(variable))
        -- The live client rejects a default whose type disagrees with the
        -- declared variableType; catching that here rather than in the game.
        assert(type(default) == variableType,
            ("default for %s is %s, declared %s"):format(tostring(variable), type(default), variableType))
        -- Recorded so tests can assert the panel actually registered every
        -- widget, not merely that building it did not error.
        mock.settingsRegistered[#mock.settingsRegistered + 1] = variable
        return { variable = variable, name = name, get = get, set = set }
    end,

    CreateCheckbox = function(_, setting) return setting end,
    CreateSlider = function(_, setting) return setting end,
    CreateSliderOptions = function(minValue, maxValue, step)
        local options = { min = minValue, max = maxValue, step = step }
        function options:SetLabelFormatter(_, formatter) self.formatter = formatter end
        return options
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function() end,
}

function CreateSettingsListSectionHeaderInitializer(text)
    return { kind = "header", text = text }
end

function CreateSettingsButtonInitializer(name, buttonText, onClick, tooltip)
    return { kind = "button", name = name, text = buttonText, onClick = onClick, tooltip = tooltip }
end

--------------------------------------------------------------------------------
-- Loader
--------------------------------------------------------------------------------

-- Loads addon files in TOC order, sharing one namespace table the way the
-- client does, and hands the namespace back for inspection.
function mock.LoadAddon(basePath, files, addonName)
    local ns = {}
    for _, file in ipairs(files) do
        local path = basePath .. "/" .. file:gsub("\\", "/")
        local chunk, err = loadfile(path)
        assert(chunk, "failed to load " .. path .. ": " .. tostring(err))
        chunk(addonName, ns)
    end
    return ns
end

return mock
