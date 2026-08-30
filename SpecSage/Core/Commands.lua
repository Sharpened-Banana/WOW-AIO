-- Core/Commands.lua
-- Slash command interface: /sage and /specsage.
--
-- The bare command toggles the Codex (the class/spec guide window) rather
-- than the overlay, since the Codex is the addon's primary surface; the
-- overlay moved to its own "overlay" subcommand. Every Codex-facing handler
-- here still checks for ns.Codex rather than assuming it exists, so a build
-- of the addon with the Codex stripped out (a guide pack installed without
-- it) degrades to a "Codex not loaded" print instead of erroring.

local ADDON, ns = ...

local Commands = ns:NewModule("Commands")

local HELP = {
    "|cff33ff99SpecSage|r commands:",
    "  |cffffff00/sage|r - toggle the Codex window",
    "  |cffffff00/sage overlay|r - toggle the stat overlay",
    "  |cffffff00/sage guide <class> [spec]|r - open the Codex at a class/spec (fuzzy match)",
    "  |cffffff00/sage lock|r / |cffffff00unlock|r - lock or unlock overlay dragging",
    "  |cffffff00/sage config|r - open the Options tab (add |cffffff00blizzard|r for the Settings panel)",
    "  |cffffff00/sage scale <0.5-2>|r - set overlay scale",
    "  |cffffff00/sage width <120-320>|r - set overlay width",
    "  |cffffff00/sage font <8-20>|r - set font size",
    "  |cffffff00/sage stat <name>|r - toggle a stat row for this character",
    "  |cffffff00/sage tooltips|r - toggle hover tooltips",
    "  |cffffff00/sage pin [stat]|r - keep a tooltip on screen (hovered one if no stat given)",
    "  |cffffff00/sage unpin [stat or all]|r - close pinned tooltips",
    "  |cffffff00/sage pins|r - list what is pinned",
    "  |cffffff00/sage dps|r - report the last fight",
    "  |cffffff00/sage reset dps|r - clear combat totals",
    "  |cffffff00/sage reset pos|r - move the overlay back to centre",
    "  |cffffff00/sage reset all|r - restore every setting to default",
    "  |cffffff00/sage watch <spellID>|r - track a spell's proc and cooldown",
    "  |cffffff00/sage unwatch <spellID>|r - stop tracking a spell",
    "  |cffffff00/sage watch list|r - show tracked spells",
    "  |cffffff00/sage scan|r - list your current buffs with their spell IDs",
}

local function PrintLines(lines, emptyMessage)
    if #lines == 0 then
        if emptyMessage then ns.Print(emptyMessage) end
        return
    end
    for _, line in ipairs(lines) do
        ns.Print(line)
    end
end

--------------------------------------------------------------------------------
-- Codex hand-off
--
-- Every path that would open or drive the Codex checks for it here instead
-- of assuming it exists, so /sage stays usable even without UI/Codex.lua
-- loaded.
--------------------------------------------------------------------------------

local function ToggleCodex()
    if ns.Codex and ns.Codex.Toggle then
        ns.Codex:Toggle()
    else
        ns.Print("Codex not loaded.")
    end
end

local function OpenCodex(classToken, specID)
    if ns.Codex and ns.Codex.Open then
        ns.Codex:Open(classToken, specID)
    else
        ns.Print("Codex not loaded.")
    end
end

--------------------------------------------------------------------------------
-- Fuzzy class/spec matching for "/sage guide <class> [spec]"
--------------------------------------------------------------------------------

-- Matches `query` against a list of { key, name } candidates: exact token or
-- name match wins outright; otherwise any candidate whose name or token
-- starts with the query is a match. Returns the single match, or nil plus an
-- explanatory error when there is none or more than one.
local function FuzzyMatch(query, candidates, noun)
    query = query:lower()

    for _, candidate in ipairs(candidates) do
        if candidate.token and candidate.token:lower() == query then
            return candidate
        end
        if candidate.name:lower() == query then
            return candidate
        end
    end

    local matches = {}
    for _, candidate in ipairs(candidates) do
        local nameStarts = candidate.name:lower():find(query, 1, true) == 1
        local tokenStarts = candidate.token and candidate.token:lower():find(query, 1, true) == 1
        if nameStarts or tokenStarts then
            matches[#matches + 1] = candidate
        end
    end

    if #matches == 1 then
        return matches[1]
    elseif #matches > 1 then
        local names = {}
        for _, candidate in ipairs(matches) do
            names[#names + 1] = candidate.name
        end
        return nil, format("'%s' matches more than one %s: %s.", query, noun, table.concat(names, ", "))
    end

    return nil, format("no %s matches '%s'.", noun, query)
end

local function MatchClass(query)
    local classes = ns.GuideStore and ns.GuideStore:GetClasses() or {}
    local match, err = FuzzyMatch(query, classes, "class")
    if not match then return nil, nil, err end
    return match.token, match.name
end

local function MatchSpec(classToken, query)
    if not ns.GuideStore then return nil, nil, "guide data not loaded." end

    local specIDs = ns.GuideStore:GetClassSpecs(classToken)
    local candidates = {}
    for _, specID in ipairs(specIDs) do
        local guide = ns.GuideStore:GetGuide(specID)
        if guide and guide.specName then
            candidates[#candidates + 1] = { key = specID, name = guide.specName }
        end
    end

    local match, err = FuzzyMatch(query, candidates, "spec")
    if not match then return nil, nil, err end
    return match.key, match.name
end

--------------------------------------------------------------------------------
-- Handlers
--------------------------------------------------------------------------------

local handlers = {}

handlers.help = function()
    for _, line in ipairs(HELP) do
        print(line)
    end
end

handlers.overlay = function()
    if not ns.UI:Toggle() then
        ns.Print("overlay hidden. |cffffff00/sage overlay|r to show it again.")
    end
end

handlers.guide = function(argument)
    argument = argument or ""
    local classArg, specArg = argument:match("^(%S+)%s*(.-)$")

    if not classArg or classArg == "" then
        ns.Print("usage: /sage guide <class> [spec]")
        return
    end

    local classToken, className, classErr = MatchClass(classArg)
    if not classToken then
        ns.Print(classErr)
        return
    end

    local specID
    if specArg and specArg ~= "" then
        local matchedSpecID, _, specErr = MatchSpec(classToken, specArg)
        if not matchedSpecID then
            ns.Print(format("%s (class: %s)", specErr, className))
            return
        end
        specID = matchedSpecID
    end

    OpenCodex(classToken, specID)
end

handlers.lock = function()
    ns.db.locked = true
    ns.RefreshAll()
    ns.Print("overlay locked.")
end

handlers.unlock = function()
    ns.db.locked = false
    ns.RefreshAll()
    ns.Print("overlay unlocked - drag it to move.")
end

-- Opens the Codex's own Options tab rather than Blizzard's Settings panel.
-- The in-addon tab is the more dependable of the two surfaces (it is built
-- from primitives this addon controls, not from Settings widget templates
-- that move between game versions), and both render the same
-- ns.OPTION_GROUPS schema, so nothing is lost by preferring it. The Settings
-- panel is still registered and reachable from the game's own options list,
-- and "/sage config blizzard" still opens it directly.
handlers.config = function(argument)
    argument = (argument or ""):lower()

    if argument == "blizzard" or argument == "settings" then
        ns.OpenOptions()
        return
    end

    if ns.Codex and ns.Codex.Open then
        ns.Codex:Open()
        ns.Codex:SelectTab("Options")
    else
        ns.OpenOptions()
    end
end

handlers.scale = function(argument)
    local value = tonumber(argument)
    if not value or value < 0.5 or value > 2 then
        ns.Print("usage: /sage scale <0.5-2>")
        return
    end
    ns.db.scale = value
    ns.RefreshAll()
    ns.Print(format("scale set to %.2f.", value))
end

handlers.width = function(argument)
    local value = tonumber(argument)
    if not value or value < 120 or value > 320 then
        ns.Print("usage: /sage width <120-320>")
        return
    end
    ns.db.width = value
    ns.RefreshAll()
    ns.Print(format("width set to %d.", value))
end

handlers.font = function(argument)
    local value = tonumber(argument)
    if not value or value < 8 or value > 20 then
        ns.Print("usage: /sage font <8-20>")
        return
    end
    ns.db.fontSize = value
    ns.RefreshAll()
    ns.Print(format("font size set to %d.", value))
end

handlers.stat = function(argument)
    local shown = ns.StatsShown()

    if not argument or argument == "" then
        local names = {}
        for _, entry in ipairs(ns.STAT_LIST) do
            local state = shown[entry.key] and "|cff44ff44on|r" or "|cff888888off|r"
            names[#names + 1] = format("%s (%s)", entry.key, state)
        end
        ns.Print("stats for this character: " .. table.concat(names, ", "))
        return
    end

    local key = argument:lower()
    if shown[key] == nil then
        ns.Print(format("unknown stat '%s'. Use /sage stat to list them.", key))
        return
    end

    shown[key] = not shown[key]
    ns.RefreshAll()
    ns.Print(format("%s %s on this character.", key, shown[key] and "shown" or "hidden"))
end

handlers.pin = function(argument)
    if not argument or argument == "" then
        local ok, result = ns.Tooltips:PinHovered()
        ns.Print(ok and format("pinned %s.", result) or format("could not pin: %s.", result))
        return
    end

    -- Pin by name so a stat can be pinned without hovering it.
    local key = argument:lower()
    if ns.StatsShown()[key] ~= nil then
        local ok, result = ns.Tooltips:Pin("stats", key)
        ns.Print(ok and format("pinned %s.", key) or format("could not pin %s: %s.", key, result))
        return
    end

    local spellID = tonumber(argument)
    if spellID then
        local ok, result = ns.Tooltips:Pin("procs", spellID)
        ns.Print(ok and format("pinned spell %d.", spellID) or format("could not pin: %s.", result))
        return
    end

    ns.Print(format("unknown stat '%s'. Use /sage stat to list them.", key))
end

handlers.unpin = function(argument)
    argument = (argument or ""):lower()

    if argument == "" or argument == "all" then
        local removed = ns.Tooltips:UnpinAll()
        ns.Print(format("closed %d pinned tooltip%s.", removed, removed == 1 and "" or "s"))
        return
    end

    if ns.Tooltips:Unpin("stats:" .. argument) or ns.Tooltips:Unpin("procs:" .. argument) then
        ns.Print(format("unpinned %s.", argument))
    else
        ns.Print(format("%s is not pinned.", argument))
    end
end

handlers.pins = function()
    PrintLines(ns.Tooltips:ListPinned(), "nothing pinned.")
end

handlers.tooltips = function()
    ns.db.tooltips = not ns.db.tooltips
    ns.RefreshAll()
    ns.Print(format("tooltips %s.", ns.db.tooltips and "enabled" or "disabled"))
end

handlers.dps = function()
    ns.Print(ns:GetModule("Combat"):GetReport())
end

handlers.reset = function(argument)
    argument = (argument or ""):lower()

    if argument == "dps" or argument == "meter" then
        ns:GetModule("Combat"):ResetSession()
        ns.Print("combat totals cleared.")
    elseif argument == "pos" or argument == "position" then
        ns.UI:ResetPosition()
        ns.Print("position reset.")
    elseif argument == "all" then
        ns.ResetConfig()
        ns.Print("all settings restored to defaults.")
    else
        ns.Print("usage: /sage reset <dps|pos|all>")
    end
end

handlers.watch = function(argument)
    local procs = ns:GetModule("Procs")

    if not argument or argument == "" or argument:lower() == "list" then
        PrintLines(procs:ListWatched(), "no spells watched. Use /sage watch <spellID>.")
        return
    end

    local spellID = tonumber(argument)
    if not spellID then
        ns.Print("usage: /sage watch <spellID> - find IDs with /sage scan")
        return
    end

    local ok, result = procs:Watch(spellID)
    if ok then
        ns.Print(format("now watching %s (%d).", result, spellID))
    else
        ns.Print(format("could not watch %d: %s.", spellID, result))
    end
end

handlers.unwatch = function(argument)
    local spellID = tonumber(argument)
    if not spellID then
        ns.Print("usage: /sage unwatch <spellID>")
        return
    end

    local ok, result = ns:GetModule("Procs"):Unwatch(spellID)
    if ok then
        ns.Print(format("stopped watching %s.", result))
    else
        ns.Print(format("could not unwatch %d: %s.", spellID, result))
    end
end

handlers.scan = function()
    local lines, blocked = ns:GetModule("Procs"):ScanAuras()
    if blocked then
        ns.Print("this content hides aura information from addons, so buffs cannot be listed here.")
        return
    end
    PrintLines(lines, "no buffs on you right now.")
end

--------------------------------------------------------------------------------
-- Dispatch
--------------------------------------------------------------------------------

local function HandleCommand(input)
    input = (input or ""):match("^%s*(.-)%s*$")

    if input == "" then
        ToggleCodex()
        return
    end

    local command, argument = input:match("^(%S+)%s*(.*)$")
    local handler = handlers[command:lower()]

    if handler then
        handler(argument)
    else
        handlers.help()
    end
end

function Commands:OnInit()
    SLASH_SPECSAGE1 = "/sage"
    SLASH_SPECSAGE2 = "/specsage"
    SlashCmdList.SPECSAGE = HandleCommand
end
