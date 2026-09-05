-- Core/Theme.lua
-- Shared status-colour palette and overlay-chrome theme presets.
--
-- Brought across from the Upkeep addon (the same author's later fork of the
-- overlay), which had kept refining this half while SpecSage grew the Codex.
-- Centralising colours here means a palette fix applies everywhere at once
-- instead of being repeated (and drifting) across every module, and a new
-- theme is one table added to THEMES rather than a change scattered across
-- UI/Overlay.lua, Core/Options.lua and UI/Codex.lua.
--
-- Load order: this file sits right after Core/Config.lua in the TOC, and
-- Modules/Combat.lua and Modules/Procs.lua read ns.Colors at file load, so
-- it must stay ahead of them. Core/Config.lua, which loads BEFORE this file,
-- therefore never reads ns.THEMES at load time: its Theme option resolves
-- its choices lazily (see ns.OptionChoices there).

local ADDON, ns = ...

--------------------------------------------------------------------------------
-- Status colours
--
-- Blue-green/orange rather than green/red: under deuteranopia and
-- protanopia, the two most common forms of colour blindness, red and green
-- collapse toward the same hue at similar brightness. Blue-green and orange
-- stay distinguishable, so "good" and "bad" states read correctly either way.
--------------------------------------------------------------------------------

ns.Colors = {
    good    = { 0.13, 0.71, 0.55 }, -- HPS, active procs, buffs present
    bad     = { 0.89, 0.59, 0.04 }, -- damage taken, missing buffs
    warn    = { 0.84, 0.45, 0.04 }, -- on cooldown
    gold    = { 1, 0.82, 0 },       -- DPS, headline numbers
    neutral = { 0.6, 0.6, 0.6 },    -- ready / inactive / dim
}

--------------------------------------------------------------------------------
-- Overlay chrome presets
--
-- Each theme describes how the overlay's backdrop is built: a texture pair
-- SetBackdrop can use directly, plus a border colour. GetEdgeColor is a
-- function rather than a fixed table so a theme can compute its colour at
-- apply time - class-coloured reads the player's actual class each time
-- rather than baking in whichever class built the addon.
--------------------------------------------------------------------------------

local function ClassAccent()
    -- Both reads are guarded: UnitClass("player") can be called before the
    -- player exists on a very early load, and C_ClassColor is a namespace
    -- that has moved before. The fallback is the overlay's old header blue.
    local ok, _, classFilename = pcall(UnitClass, "player")
    local color
    if ok and classFilename and C_ClassColor and C_ClassColor.GetClassColor then
        local colorOk, result = pcall(C_ClassColor.GetClassColor, classFilename)
        if colorOk then color = result end
    end
    if not color and ok and classFilename and RAID_CLASS_COLORS then
        color = RAID_CLASS_COLORS[classFilename]
    end
    if color then return color.r, color.g, color.b end
    return 0.4, 0.8, 1.0
end

ns.THEMES = {
    minimal = {
        label = "Minimal",
        bgTexture = "Interface\\Buttons\\WHITE8X8",
        bgColor = { 0, 0, 0 },
        edgeTexture = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        GetEdgeColor = function() return 1, 1, 1, 0.12 end,
    },
    bordered = {
        label = "Bordered",
        bgTexture = "Interface\\Tooltips\\UI-Tooltip-Background",
        bgColor = { 0.05, 0.04, 0.03 },
        edgeTexture = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        GetEdgeColor = function() return 0.79, 0.63, 0.36, 1 end,
    },
    classcolor = {
        label = "Class-coloured",
        bgTexture = "Interface\\Buttons\\WHITE8X8",
        bgColor = { 0, 0, 0 },
        edgeTexture = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        GetEdgeColor = function()
            local r, g, b = ClassAccent()
            return r, g, b, 0.9
        end,
    },
}

-- Display order for the Theme option on both surfaces; add a new theme here
-- (and above) and nothing else needs to change to offer it.
ns.THEME_ORDER = { "minimal", "bordered", "classcolor" }

-- An unknown key (a theme renamed or removed between versions, or a saved
-- variable hand-edited) falls back to minimal rather than erroring inside
-- SetBackdrop.
function ns.GetTheme(key)
    return ns.THEMES[key] or ns.THEMES.minimal
end
