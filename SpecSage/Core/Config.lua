-- Core/Config.lua
-- Saved-variable defaults and initialisation.

local ADDON, ns = ...

-- Stats the overlay knows how to display, in the order they are drawn.
ns.STAT_LIST = {
    { key = "ilvl",    label = "Item Level" },
    { key = "primary", label = "Primary" },
    { key = "power",   label = "Attack/Spell Power" },
    { key = "attackspeed", label = "Attack Speed" },
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
    { key = "dodge",   label = "Dodge" },
    { key = "parry",   label = "Parry" },
    { key = "block",   label = "Block" },
}

--------------------------------------------------------------------------------
-- Option schema
--
-- One description of every setting, consumed by BOTH surfaces that present
-- them: Core/Options.lua (Blizzard's Settings panel) and UI/Codex.lua's
-- Options tab. It lives here, in the file that already owns DEFAULTS and
-- STAT_LIST, so adding an option is a single edit and the two surfaces
-- cannot drift apart.
--
-- Entry kinds:
--   check  - boolean toggle
--   range  - number with min/max/step (a slider in the Settings panel, -/+
--            steppers in the Codex, which has no slider widget of its own)
--   action - a button that runs a named side effect
--------------------------------------------------------------------------------

-- Where an option's value lives. Resolved at call time, never at load time:
-- ns.db and ns.chardb do not exist until InitConfig has run.
ns.OPTION_SCOPES = {
    db = function() return ns.db end,
    stats = function() return ns.db.stats end,
    combat = function() return ns.db.combat end,
    procs = function() return ns.db.procs end,
    statsShow = function() return ns.StatsShown() end,
    characterPanel = function() return ns.db.characterPanel end,
}

-- Named side effects, kept out of the schema itself so it stays plain data.
ns.OPTION_ACTIONS = {
    resetPosition = function() ns.UI:ResetPosition() end,
    resetSession = function() ns:GetModule("Combat"):ResetSession() end,
    feedback = function()
        local Codex = ns:GetModule("Codex")
        if Codex then Codex:ShowFeedback() end
    end,
}

-- Where the Feedback button sends people. An addon cannot open a browser or
-- send anything out of the game (no network access from Lua), so "feedback"
-- means showing this link ready to Ctrl+C. Read from the TOC's X-Website so
-- the one place to change it is the addon manifest.
local FEEDBACK_URL_FALLBACK = "https://github.com/Sharpened-Banana/WOW-AIO/issues"
function ns.FeedbackURL()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local ok, url = pcall(C_AddOns.GetAddOnMetadata, ADDON, "X-Website")
        if ok and type(url) == "string" and url ~= "" then return url end
    end
    return FEEDBACK_URL_FALLBACK
end

function ns.GetOptionValue(entry)
    local scope = ns.OPTION_SCOPES[entry.scope]
    local target = scope and scope()
    if not target then return nil end
    return target[entry.key]
end

function ns.SetOptionValue(entry, value)
    local scope = ns.OPTION_SCOPES[entry.scope]
    local target = scope and scope()
    if not target then return false end
    target[entry.key] = value
    return true
end

-- Snaps `value` onto the entry's step grid and clamps it to range. Stepping
-- by a fractional step (opacity's 0.05) accumulates float error otherwise,
-- so the value is rebuilt from a whole number of steps above min rather than
-- repeatedly added to.
function ns.ClampOptionValue(entry, value)
    value = tonumber(value) or entry.min
    local steps = math.floor((value - entry.min) / entry.step + 0.5)
    value = entry.min + steps * entry.step
    if value < entry.min then return entry.min end
    if value > entry.max then return entry.max end
    return value
end

-- %d is handed a rounded value rather than a raw float. Scaling a stepped
-- fraction reintroduces float error (0.05 * 100 is 5.000000000000001, and
-- 0.35 * 100 is 34.99999999999999), which %d truncates - so an opacity of
-- 35% would render as "34%". Rounding first also keeps these safe on a Lua
-- 5.3+ interpreter, where %d on a non-integer float is an error rather than
-- a silent truncation.
local function Round(value) return math.floor((value or 0) + 0.5) end

local function Percent(value) return format("%d%%", Round((value or 0) * 100)) end
local function Two(value) return format("%.2f", value or 0) end
local function Whole(value) return format("%d", Round(value)) end
local function Seconds(value) return format("%ds", Round(value)) end

local function BuildOptionGroups()
    local display = {
        { kind = "check", scope = "db", key = "locked",
          variable = "SpecSage_locked", label = "Lock overlay",
          tooltip = "Stops the overlay from being dragged and lets clicks pass through it." },
        { kind = "check", scope = "db", key = "hideOutOfCombat",
          variable = "SpecSage_hideOOC", label = "Hide out of combat",
          tooltip = "Only show the overlay while you are in combat." },
        { kind = "check", scope = "db", key = "showHeaders",
          variable = "SpecSage_headers", label = "Show section headers",
          tooltip = "Show the Stats / Combat / Procs labels." },
        { kind = "check", scope = "db", key = "tooltips",
          variable = "SpecSage_tooltips", label = "Show tooltips on hover",
          tooltip = "Explain each stat and show the rating behind it when you hover a row. "
              .. "Clicks still pass through to whatever is underneath." },
        { kind = "range", scope = "db", key = "scale",
          variable = "SpecSage_scale", label = "Scale", tooltip = "Overall size of the overlay.",
          min = 0.5, max = 2.0, step = 0.05, formatter = Two },
        { kind = "range", scope = "db", key = "opacity",
          variable = "SpecSage_opacity", label = "Background opacity",
          tooltip = "Transparency of the overlay background.",
          min = 0, max = 1, step = 0.05, formatter = Percent },
        { kind = "range", scope = "db", key = "width",
          variable = "SpecSage_width", label = "Width", tooltip = "Overlay width in pixels.",
          min = 120, max = 320, step = 10, formatter = Whole },
        { kind = "range", scope = "db", key = "fontSize",
          variable = "SpecSage_fontSize", label = "Font size", tooltip = "Text size used for rows.",
          min = 8, max = 20, step = 1, formatter = Whole },
        { kind = "action", action = "resetPosition", label = "Position",
          buttonText = "Reset position", tooltip = "Move the overlay back to its default spot." },
    }

    local codex = {
        { kind = "check", scope = "db", key = "itemStatRanks",
          variable = "SpecSage_itemStatRanks", label = "Tier and stat ranks on item tooltips",
          tooltip = "Add lines to every item tooltip: a trinket's tier in your current spec's trinket "
              .. "lists (Single Target S, Icy Veins A, ...) and each secondary stat's rank (#1, #2, ...) "
              .. "against your spec's stat priority from the Codex." },
        { kind = "check", scope = "characterPanel", key = "enabled",
          variable = "SpecSage_characterPanel", label = "Dock gearing panel to the character sheet",
          tooltip = "Show your stat priority, your live rating for each stat, Wowhead's order for "
              .. "each hero talent tree, and the BiS item for whichever gear slot you hover - "
              .. "attached to the character sheet, opening and closing with it." },
        { kind = "action", action = "feedback", label = "Feedback",
          buttonText = "Feedback / requests",
          tooltip = "Shows the link to SpecSage's GitHub Issues page, ready to copy, for bug reports "
              .. "and feature requests. (An addon cannot open your browser itself.)" },
    }

    local stats = {
        { kind = "check", scope = "stats", key = "enabled",
          variable = "SpecSage_stats", label = "Show stats section" },
    }
    -- Generated from STAT_LIST so a stat added there reaches both surfaces
    -- without a second edit.
    for _, entry in ipairs(ns.STAT_LIST) do
        stats[#stats + 1] = {
            kind = "check", scope = "statsShow", key = entry.key,
            variable = "SpecSage_stat_" .. entry.key, label = entry.label,
            tooltip = "Shown on this character only.",
        }
    end

    local combatOptions = {
        { key = "enabled", label = "Show combat section" },
        { key = "showDPS", label = "Damage per second" },
        { key = "showHPS", label = "Healing per second" },
        { key = "showDamageTaken", label = "Damage taken per second" },
        { key = "showCombatTime", label = "Fight duration" },
        { key = "showSessionTotals", label = "Session totals" },
        { key = "includePets", label = "Count pet damage" },
    }
    local combat = {}
    for _, entry in ipairs(combatOptions) do
        combat[#combat + 1] = {
            kind = "check", scope = "combat", key = entry.key,
            variable = "SpecSage_combat_" .. entry.key, label = entry.label,
        }
    end
    combat[#combat + 1] = { kind = "action", action = "resetSession", label = "Meters",
        buttonText = "Reset session", tooltip = "Clear accumulated damage, healing and time." }

    local procs = {
        { kind = "check", scope = "procs", key = "enabled",
          variable = "SpecSage_procs", label = "Show procs section" },
        { kind = "check", scope = "procs", key = "autoDetect",
          variable = "SpecSage_procs_auto", label = "Auto-detect procs",
          tooltip = "Automatically show short buffs on you, such as trinket and talent procs." },
        { kind = "check", scope = "procs", key = "showInactiveWatched",
          variable = "SpecSage_procs_inactive", label = "Show watched spells when ready",
          tooltip = "Keep watched spells on the list even when they are not active." },
        { kind = "range", scope = "procs", key = "maxAuto",
          variable = "SpecSage_procs_maxAuto", label = "Max auto-detected procs",
          tooltip = "How many auto-detected procs to show at once.",
          min = 1, max = 10, step = 1, formatter = Whole },
        { kind = "range", scope = "procs", key = "maxDuration",
          variable = "SpecSage_procs_maxDuration", label = "Max proc duration",
          tooltip = "Ignore buffs longer than this, so flasks and food do not show up.",
          min = 5, max = 120, step = 5, formatter = Seconds },
    }

    return {
        { title = "Display", options = display },
        { title = "Codex", options = codex },
        { title = "Stats (this character)", options = stats },
        { title = "Combat", options = combat },
        { title = "Procs", options = procs },
    }
end

ns.OPTION_GROUPS = BuildOptionGroups()

local DEFAULTS = {
    -- Off by default for a fresh install; /sage overlay or the Options tab
    -- turns it on. Existing users' saved choice is untouched - CopyDefaults
    -- only fills in a key that's still nil, never overwrites one already set.
    hidden = true,
    locked = false,
    scale = 1.0,
    opacity = 0.75,
    width = 190,
    fontSize = 12,
    showHeaders = true,
    hideOutOfCombat = false,
    tooltips = true,

    -- Modules/ItemRanks.lua: rank an item tooltip's secondary stats against
    -- the player's current spec's Codex stat priority.
    itemStatRanks = true,

    -- UI/CharacterPanel.lua: the gearing panel docked to the character
    -- sheet. On by default - it only ever appears while the character sheet
    -- is open, so it costs nothing until you go looking at your gear, and
    -- the checkbox on the sheet itself turns it off in one click.
    -- `listIndex` is which BiS context (Overall / Mythic+ / Raid / Wowhead)
    -- its item rows come from, kept apart from the Codex's own so opening
    -- the character sheet never changes what the Codex is showing.
    characterPanel = {
        enabled = true,
        listIndex = 1,
        -- Which section the dropdown is on. "Gear" is this panel's own view;
        -- every other value is one of the Codex's tabs, rendered by the
        -- Codex's own methods against the panel's surface.
        section = "Gear",
    },

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
        power = false,
        attackspeed = false,
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
        dodge = false,
        parry = false,
        block = false,
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
