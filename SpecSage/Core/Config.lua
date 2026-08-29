-- Core/Config.lua
-- Saved-variable defaults and initialisation.

local ADDON, ns = ...

-- Stats the overlay knows how to display, in the order they are drawn.
ns.STAT_LIST = {
    { key = "ilvl",    label = "Item Level" },
    { key = "primary", label = "Primary" },
    { key = "stamina", label = "Stamina" },
    { key = "health",  label = "Health" },
    { key = "crit",    label = "Crit" },
    { key = "haste",   label = "Haste" },
    { key = "mastery", label = "Mastery" },
    { key = "vers",    label = "Versatility" },
    { key = "leech",   label = "Leech" },
    { key = "avoid",   label = "Avoidance" },
    { key = "speed",   label = "Speed" },
    { key = "armor",   label = "Armor" },
}

local DEFAULTS = {
    hidden = false,
    locked = false,
    scale = 1.0,
    opacity = 0.75,
    width = 190,
    fontSize = 12,
    showHeaders = true,
    hideOutOfCombat = false,
    tooltips = true,

    -- Pinned tooltips, keyed by "section:key", each { section, key, custom,
    -- point, relPoint, x, y }. Only dragged pins carry a position; the rest
    -- stack down the side of the overlay.
    pinnedTooltips = {},

    position = { point = "CENTER", relPoint = "CENTER", x = 300, y = 0 },

    -- The Codex window's own remembered position, independent of the
    -- overlay's. Centred by default; updated on drag (see UI/Codex.lua's
    -- OnDragStop).
    codexPosition = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 },

    -- Which stats are shown lives per character, in SpecSageCharDB.
    stats = {
        enabled = true,
    },

    combat = {
        enabled = true,
        includePets = true,
        showDPS = true,
        showHPS = true,
        showDamageTaken = false,
        showCombatTime = true,
        showSessionTotals = false,
    },

    procs = {
        enabled = true,
        autoDetect = true,
        maxAuto = 5,
        maxDuration = 60,
        showInactiveWatched = true,
    },

    -- Saved talent loadouts, keyed by specID: { {name=, category=, export=}, ... }.
    loadouts = {},

    -- Free-text notes, keyed by specID.
    notes = {},

    -- Personal BiS checklist entries, keyed by specID: { {slot=, itemID=,
    -- name=, note=}, ... }. Curated data like loadouts and notes.
    bis = {},
}

-- Anything class- or spec-specific belongs here rather than in the shared DB:
-- a tank and a healer want different rows on screen.
local CHAR_DEFAULTS = {
    -- Spell IDs the player explicitly asked to track, in display order.
    watch = {},

    -- Which stat rows this character shows. Defaults suit a damage dealer;
    -- tanks will want armor and avoidance on.
    statsShow = {
        ilvl = true,
        primary = true,
        stamina = false,
        health = false,
        crit = true,
        haste = true,
        mastery = true,
        vers = true,
        leech = false,
        avoid = false,
        speed = false,
        armor = false,
    },
}

-- Recursively fills missing keys from a defaults table without clobbering
-- values the player has already set.
local function CopyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

ns.CopyDefaults = CopyDefaults
ns.DEFAULTS = DEFAULTS

function ns.InitConfig()
    SpecSageDB = CopyDefaults(SpecSageDB or {}, DEFAULTS)
    SpecSageCharDB = CopyDefaults(SpecSageCharDB or {}, CHAR_DEFAULTS)
    ns.db = SpecSageDB
    ns.chardb = SpecSageCharDB
end

-- Single point of truth for which stats this character shows.
function ns.StatsShown()
    return ns.chardb.statsShow
end

-- Restores display settings and this character's stat rows. The watch list,
-- loadouts, notes and BiS checklist are deliberately kept: they are curated
-- data, not a setting.
function ns.ResetConfig()
    -- Close pins against the old table before it is replaced, or their frames
    -- would linger on screen with nothing backing them.
    if ns.Tooltips then
        ns.Tooltips:UnpinAll()
    end

    local loadouts, notes, bis = SpecSageDB.loadouts, SpecSageDB.notes, SpecSageDB.bis

    SpecSageDB = CopyDefaults({}, DEFAULTS)
    SpecSageDB.loadouts = loadouts
    SpecSageDB.notes = notes
    SpecSageDB.bis = bis
    ns.db = SpecSageDB

    ns.chardb.statsShow = CopyDefaults({}, CHAR_DEFAULTS.statsShow)

    ns.RefreshAll()
end
