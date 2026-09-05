-- Core/Init.lua
-- Addon bootstrap: namespace, module registry, event bus, printing helpers.

local ADDON, ns = ...

local GetAddOnMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata

ns.name = ADDON
ns.version = GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version") or "1.0.0"

local PREFIX = "|cff33ff99SpecSage|r: "

function ns.Print(...)
    print(PREFIX .. strjoin(" ", tostringall(...)))
end

--------------------------------------------------------------------------------
-- Module registry
--
-- Modules are plain tables created at file-load time. Core calls OnInit after
-- saved variables exist, and OnEnable once the player is in the world.
--------------------------------------------------------------------------------

local modules, moduleOrder = {}, {}

function ns:NewModule(name)
    local module = { name = name }
    modules[name] = module
    moduleOrder[#moduleOrder + 1] = module
    return module
end

function ns:GetModule(name)
    return modules[name]
end

--------------------------------------------------------------------------------
-- Event bus
--
-- One frame fans events out to any number of handlers so modules do not each
-- need their own frame.
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local handlers = {}

function ns:RegisterEvent(event, callback)
    local list = handlers[event]
    if not list then
        -- Events come and go between game versions, and registering an unknown
        -- one throws. Skip it rather than taking the whole addon down.
        if not pcall(eventFrame.RegisterEvent, eventFrame, event) then
            return false
        end
        list = {}
        handlers[event] = list
    end
    list[#list + 1] = callback
    return true
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        list[i](event, ...)
    end
end)

--------------------------------------------------------------------------------
-- Secret-value helpers
--
-- Midnight's secret values error on comparison, arithmetic and string
-- formatting rather than returning something useless, so any expression that
-- touches unit/aura/combat data has to be able to fail without taking its
-- caller down. ns.SafeCall runs one such expression and reports "could not
-- read that" as nil.
--------------------------------------------------------------------------------

function ns.SafeCall(fn)
    local ok, result = pcall(fn)
    if ok then return result end
    return nil
end

-- True only when value is known to be past threshold in the given
-- direction (wantGreater true for >, false for <). A secret value cannot be
-- compared at all, so this reports false rather than letting the comparison
-- throw: an optional line quietly not appearing is fine, the whole tooltip
-- or row disappearing is not.
function ns.KnownPast(value, threshold, wantGreater)
    return ns.SafeCall(function()
        local number = value or 0
        if wantGreater then return number > threshold end
        return number < threshold
    end) == true
end

--------------------------------------------------------------------------------
-- Aura availability
--
-- In Midnight's restricted content the aura APIs do not merely return secret
-- values, they refuse addon access outright: AuraUtil.ForEachAura throws
-- "Auras cannot be accessed when secret while tainted by 'SpecSage'" from
-- inside GetAuraSlots, before our callback ever runs, and
-- C_UnitAuras.GetPlayerAuraBySpellID throws the same way. Guarding the
-- values a callback receives is therefore not enough - the call itself has
-- to be wrapped.
--
-- It also has to stop being retried. Procs updates on a 0.1s ticker and on
-- every UNIT_AURA, so a call that is guaranteed to fail for the duration of
-- an encounter fails thousands of times (25k+ in one session before this
-- guard existed). Once a refusal is seen, aura reads are parked for a few
-- seconds before being tried again - long enough to cost nothing, short
-- enough that leaving restricted content restores tracking promptly.
--
-- Shared across every module that reads auras (Modules/Procs.lua,
-- Modules/Buffs.lua) so one refusal backs all of them off together rather
-- than each discovering, and re-announcing, the same restriction on its own.
-- A module still wraps its own call in pcall and calls ns.NoteAurasBlocked
-- on failure; this just holds the shared cooldown and the one-time notice.
--------------------------------------------------------------------------------

local AURA_RETRY_INTERVAL = 5
local auraBlockedUntil = 0
local auraNoticeShown = false

function ns.AurasReadable()
    return GetTime() >= auraBlockedUntil
end

function ns.NoteAurasBlocked()
    auraBlockedUntil = GetTime() + AURA_RETRY_INTERVAL

    -- Said once per session, not once per refusal: the player should know
    -- why the Procs and Buffs sections emptied out, but this is a game
    -- restriction, not an addon fault, and it must never become its own spam.
    if not auraNoticeShown then
        auraNoticeShown = true
        ns.Print("this content hides aura information from addons, so proc and buff tracking is paused here.")
    end
end

-- True when aura access is currently being refused. Lets callers (the slash
-- commands) explain an empty result rather than implying there are no buffs.
function ns.AurasBlocked()
    return not ns.AurasReadable()
end

--------------------------------------------------------------------------------
-- Number / text helpers
--
-- Midnight's secret values (see UI/Overlay.lua's SafeEqual) reach these
-- helpers through stat readers and the damage meter: format() propagates a
-- secret into a displayable secret string, but comparing or doing arithmetic
-- on one errors. Each helper therefore tries its full pretty-print first and
-- falls back to a comparison-free format of the raw value, so a secret
-- renders as its plain number instead of erroring (or silently losing the
-- row when the caller pcall-wraps its reader).
--------------------------------------------------------------------------------

local function FormatNumberRaw(value)
    if value >= 1e9 then
        return format("%.2fB", value / 1e9)
    elseif value >= 1e6 then
        return format("%.2fM", value / 1e6)
    elseif value >= 1e4 then
        return format("%.1fK", value / 1e3)
    end
    return format("%d", value)
end

function ns.FormatNumber(value)
    value = value or 0
    local ok, result = pcall(FormatNumberRaw, value)
    if ok then return result end

    ok, result = pcall(format, "%d", value)
    if ok then return result end
    return "-"
end

-- An item string the client resolves to the item the guide actually meant.
--
-- A bare itemID resolves to the item's *base* form, and on current-season
-- gear that is not the item on the page: Icy Veins' Protection Paladin neck
-- is "Strand of Warding Fangs" at item level 334, while item ID 273781 on
-- its own is a level-48 rare with +8 Stamina. What separates them is the
-- item's bonus-ID list, which puts it on its upgrade track, and which the
-- generated data now carries (Data/BiS.lua's `bonus`). The full form is
-- item:<id>:<enchant>:<4 gems>:<suffix>:<unique>:<linkLevel>:<specID>:
-- <modifiersMask>:<itemContext>:<numBonusIDs>:<bonus...>, so the eleven
-- fields between the ID and the bonus count are zeroed out.
--
-- Rows whose source publishes no bonus list (Wowhead's markup has none of
-- its own; see Data/BiS.lua's header) pass the plain numeric ID through
-- unchanged, which is what every API here took before.
function ns.ItemString(itemID, bonus)
    if type(itemID) ~= "number" then return nil end
    if type(bonus) ~= "string" or bonus == "" then return itemID end

    local count, ids = 0, {}
    for id in bonus:gmatch("%d+") do
        count = count + 1
        ids[count] = id
    end
    if count == 0 then return itemID end
    return string.format("item:%d:0:0:0:0:0:0:0:0:0:0:0:%d:%s", itemID, count, table.concat(ids, ":"))
end

function ns.FormatPercent(value)
    local ok, result = pcall(function() return format("%.2f%%", value or 0) end)
    if ok then return result end

    -- Even the `or 0` can trip on some secret shapes; formatting the raw
    -- value alone is the plainest rendering that can still succeed.
    local plainOk, plain = pcall(format, "%.2f%%", value)
    if plainOk then return plain end
    return "-"
end

local function FormatTimeRaw(seconds)
    if seconds >= 60 then
        return format("%d:%02d", seconds / 60, seconds % 60)
    end
    return format("%.1fs", seconds)
end

function ns.FormatTime(seconds)
    seconds = seconds or 0
    local ok, result = pcall(FormatTimeRaw, seconds)
    if ok then return result end

    -- The >= 60 comparison couldn't run; formatting alone still can, so a
    -- secret remaining time shows as its plain seconds rather than a dash
    -- (the same second attempt ns.FormatNumber makes).
    ok, result = pcall(format, "%.1fs", seconds)
    if ok then return result end
    return "-"
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

local function CallModules(method)
    for i = 1, #moduleOrder do
        local module = moduleOrder[i]
        if module[method] then
            local ok, err = pcall(module[method], module)
            if not ok then
                ns.Print(format("|cffff4444error in %s:%s()|r %s", module.name, method, tostring(err)))
            end
        end
    end
end

-- Pushes config changes out to every module that cares.
function ns.RefreshAll()
    CallModules("OnConfigChanged")
end

ns:RegisterEvent("ADDON_LOADED", function(_, loadedAddon)
    if loadedAddon ~= ADDON then return end
    ns.InitConfig()
    CallModules("OnInit")
end)

ns:RegisterEvent("PLAYER_LOGIN", function()
    ns.playerGUID = UnitGUID("player")
    CallModules("OnEnable")
    ns.RefreshAll()
end)
