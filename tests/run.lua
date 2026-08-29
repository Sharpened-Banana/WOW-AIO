-- tests/run.lua
-- Loads SpecSage against the mock API and drives it through a session.
--
-- Run with:  lua5.1 tests/run.lua

package.path = "tests/?.lua;" .. package.path

local mock = require("wow_mock")

--------------------------------------------------------------------------------
-- Tiny test harness
--------------------------------------------------------------------------------

local passed, failed = 0, 0

local function check(condition, description, detail)
    if condition then
        passed = passed + 1
        print("  ok   " .. description)
    else
        failed = failed + 1
        print("  FAIL " .. description .. (detail and ("  -> " .. tostring(detail)) or ""))
    end
end

local function section(title)
    print("\n" .. title)
end

--------------------------------------------------------------------------------
-- Load the addon exactly as the TOC lists it
--------------------------------------------------------------------------------

local FILES = {
    "Core\\Init.lua",
    "Core\\Config.lua",
    "Data\\API.lua",
    "Data\\Guides_Warrior.lua",
    "Data\\Guides_Paladin.lua",
    "Data\\Guides_Hunter.lua",
    "Data\\Guides_Rogue.lua",
    "Data\\Guides_Priest.lua",
    "Data\\Guides_DeathKnight.lua",
    "Data\\Guides_Shaman.lua",
    "Data\\Guides_Mage.lua",
    "Data\\Guides_Warlock.lua",
    "Data\\Guides_Monk.lua",
    "Data\\Guides_Druid.lua",
    "Data\\Guides_DemonHunter.lua",
    "Data\\Guides_Evoker.lua",
    "UI\\Overlay.lua",
    "UI\\Tooltips.lua",
    "UI\\Codex.lua",
    "Modules\\Stats.lua",
    "Modules\\Combat.lua",
    "Modules\\Procs.lua",
    "Modules\\Loadouts.lua",
    "Modules\\Notes.lua",
    "Core\\Options.lua",
    "Core\\Commands.lua",
}

-- Keep addon chat output from drowning the test log.
local realPrint = print
local addonOutput = {}
_G.print = function(...)
    addonOutput[#addonOutput + 1] = table.concat({ mock and "" or "" }, "") .. tostring((select(1, ...)))
end

local ns = mock.LoadAddon("SpecSage", FILES, "SpecSage")

_G.print = realPrint

-- The slash-command tests further down replace ns.Codex with bare stand-in
-- tables (and finally nil) to exercise Commands.lua's "Codex not loaded"
-- fallback. Keep a handle on the real UI/Codex.lua module here so the Codex
-- section near the end of this file can restore it.
local RealCodex = ns.Codex

-- Record every section the modules render, without touching production code.
local rendered = {}
local realSetSection = ns.UI.SetSection
ns.UI.SetSection = function(self, id, rows, tooltipProvider)
    rendered[id] = rows or {}
    return realSetSection(self, id, rows, tooltipProvider)
end

local function findRow(sectionID, labelPattern)
    for _, row in ipairs(rendered[sectionID] or {}) do
        if row.label and row.label:find(labelPattern, 1, true) then
            return row
        end
    end
    return nil
end

--------------------------------------------------------------------------------
section("Load and initialisation")
--------------------------------------------------------------------------------

check(ns.name == "SpecSage", "namespace carries the addon name")
check(ns.UI ~= nil, "UI module registered at load time")
check(ns.GuideStore ~= nil, "GuideStore registered at load time")

mock.Fire("ADDON_LOADED", "SomeOtherAddon")
check(ns.db == nil, "ignores ADDON_LOADED for other addons")

mock.Fire("ADDON_LOADED", "SpecSage")
check(ns.db ~= nil, "saved variables initialised")
check(ns.db.scale == 1.0, "defaults applied", ns.db and ns.db.scale)
check(ns.chardb ~= nil and type(ns.chardb.watch) == "table", "per-character watch list created")
check(ns.UI.frame ~= nil, "overlay frame built")
check(SlashCmdList.SPECSAGE ~= nil, "slash command registered")

-- Defaults must not be shared by reference, or one character's settings would
-- leak into another's.
ns.chardb.statsShow.crit = false
check(ns.DEFAULTS.stats.enabled == true, "defaults are deep-copied, not referenced")
ns.chardb.statsShow.crit = true

mock.Fire("PLAYER_LOGIN")
check(ns.playerGUID == "Player-1234-ABCDEF", "player GUID cached on login")

--------------------------------------------------------------------------------
section("Stats module")
--------------------------------------------------------------------------------

check(#(rendered.stats or {}) > 0, "stats section renders rows")
check(findRow("stats", "Item Level") ~= nil, "item level row present")

local primaryRow = findRow("stats", "Agility")
check(primaryRow ~= nil, "primary stat resolved from spec (Agility for spec primaryStat=2)")
-- Values below 10,000 stay exact; only larger numbers get abbreviated.
check(primaryRow and primaryRow.value == "8500", "primary stat shown exactly below the abbreviation threshold",
    primaryRow and primaryRow.value)

local healthRowBefore = findRow("stats", "Health")
check(healthRowBefore == nil, "health row off by default")
ns.chardb.statsShow.health = true
ns.RefreshAll()
local healthRow = findRow("stats", "Health")
check(healthRow and healthRow.value == "4.25M", "large numbers abbreviated", healthRow and healthRow.value)
ns.chardb.statsShow.health = false
ns.RefreshAll()

local critRow = findRow("stats", "Crit")
check(critRow ~= nil and critRow.value == "21.34%", "melee crit used for a non-Intellect spec", critRow and critRow.value)

local versRow = findRow("stats", "Versatility")
check(versRow ~= nil and versRow.value == "7.60%", "versatility sums rating bonus and versatility bonus", versRow and versRow.value)

check(findRow("stats", "Stamina") == nil, "stats disabled by default are not drawn")

ns.chardb.statsShow.stamina = true
ns.RefreshAll()
check(findRow("stats", "Stamina") ~= nil, "enabling a stat adds its row")
ns.chardb.statsShow.stamina = false
ns.RefreshAll()

--------------------------------------------------------------------------------
section("Stats:GetStatValue (public accessor for the Codex)")
--------------------------------------------------------------------------------

local StatsModule = ns:GetModule("Stats")

check(StatsModule.GetStatValue ~= nil, "Stats module exposes GetStatValue")
check(StatsModule:GetStatValue("crit") == "21.34%", "GetStatValue matches the overlay row's own value for crit",
    StatsModule:GetStatValue("crit"))
check(StatsModule:GetStatValue("haste") == "14.77%", "GetStatValue works for a stat currently shown on the overlay",
    StatsModule:GetStatValue("haste"))

-- statPriority entries speak the guide vocabulary ("versatility",
-- "avoidance"); GetStatValue must accept that even though the overlay's own
-- internal row keys are the shorter "vers"/"avoid".
check(StatsModule:GetStatValue("versatility") == "7.60%", "GetStatValue accepts the GuideStore's 'versatility' key",
    StatsModule:GetStatValue("versatility"))
check(StatsModule:GetStatValue("avoidance") == "1.80%", "GetStatValue accepts the GuideStore's 'avoidance' key",
    StatsModule:GetStatValue("avoidance"))

-- A stat that is hidden on the overlay right now must still resolve: the
-- accessor computes on demand rather than reading only the last rendered row.
check(findRow("stats", "Stamina") == nil, "stamina row is not currently shown")
check(StatsModule:GetStatValue("stamina") ~= nil, "GetStatValue resolves a stat even when its row is hidden",
    StatsModule:GetStatValue("stamina"))

check(StatsModule:GetStatValue("bogus") == nil, "GetStatValue returns nil for an unknown key")
check(StatsModule:GetStatValue(nil) == nil, "GetStatValue returns nil rather than erroring on nil")
check(StatsModule:GetStatValue(42) == nil, "GetStatValue returns nil rather than erroring on a non-string key")

--------------------------------------------------------------------------------
section("GuideStore (Data/API.lua)")
--------------------------------------------------------------------------------

local GuideStore = ns.GuideStore

do
    local classes = GuideStore:GetClasses()
    check(#classes == 13, "GetClasses lists all 13 retail classes", #classes)
    check(classes[1].token == "WARRIOR" and classes[1].classID == 1, "classes are ordered by classID (Warrior first)")
    check(classes[13].token == "EVOKER" and classes[13].classID == 13, "classes are ordered by classID (Evoker last)")

    local seen = {}
    for _, entry in ipairs(classes) do
        check(not seen[entry.token], "class token appears once: " .. tostring(entry.token))
        seen[entry.token] = true
        check(type(entry.name) == "string" and entry.name ~= "", "class has a display name: " .. tostring(entry.token))
    end
end

-- A class nobody has registered a guide for is still listed.
check(#GuideStore:GetClassSpecs("MONK") >= 0, "GetClassSpecs never errors for a class with no guides",
    #GuideStore:GetClassSpecs("MONK"))

local silencedOutput
local function silently(fn)
    local before = _G.print
    _G.print = function() end
    local ok, a, b = pcall(fn)
    _G.print = before
    return ok, a, b
end

-- Rejects a non-table guide. Uses a specID well outside any real
-- specialization's range (they all fall under 2000) so this cannot collide
-- with a shipped class guide file.
do
    local ok, result = silently(function() return GuideStore:RegisterSpec("WARRIOR", 9051, "not a table") end)
    check(ok, "RegisterSpec with a non-table guide does not error", result)
    check(result == false, "RegisterSpec with a non-table guide is rejected")
    check(GuideStore:GetGuide(9051) == nil, "rejected guide is not stored")
end

-- Rejects a bad stat key inside statPriority.
do
    local badGuide = {
        specName = "Test Spec",
        role = "DAMAGER",
        statPriority = {
            { stat = "haste" },
            { stat = "not_a_real_stat" },
        },
    }
    local ok, result = silently(function() return GuideStore:RegisterSpec("MAGE", 9001, badGuide) end)
    check(ok, "RegisterSpec with a bad stat key does not error", result)
    check(result == false, "guide with an invalid statPriority stat key is rejected")
    check(GuideStore:GetGuide(9001) == nil, "guide with a bad stat key is not stored")
end

-- Rejects a guide missing specName.
do
    local badGuide = { role = "DAMAGER" }
    local ok, result = silently(function() return GuideStore:RegisterSpec("MAGE", 9002, badGuide) end)
    check(ok, "RegisterSpec with a missing specName does not error", result)
    check(result == false, "guide missing specName is rejected")
    check(GuideStore:GetGuide(9002) == nil, "guide missing specName is not stored")
end

-- Rejects an unknown class token.
do
    local ok, result = silently(function()
        return GuideStore:RegisterSpec("NOTACLASS", 9003, { specName = "Whatever" })
    end)
    check(ok, "RegisterSpec with an unknown class token does not error", result)
    check(result == false, "unknown class token is rejected")
end

-- Accepts a valid guide and round-trips it through GetGuide.
do
    local goodGuide = {
        specName = "Frostfire",
        role = "DAMAGER",
        overview = { "A test spec for the suite." },
        statPriority = {
            { stat = "haste", note = "to ~20%" },
            { stat = "mastery" },
            { stat = "crit" },
            { stat = "versatility" },
        },
        rotation = {
            { title = "Single Target", steps = {
                { spellID = 133, text = "Fireball on cooldown" },
                { text = "Free-text step without a spell icon" },
            }},
        },
        cooldowns = { { spellID = 12043, text = "Presence of Mind" } },
        consumables = { { slot = "Flask", text = "Flask of Alchemical Chaos" } },
        tips = { "Keep moving between casts." },
    }

    local ok = GuideStore:RegisterSpec("MAGE", 9010, goodGuide)
    check(ok == true, "RegisterSpec accepts a valid guide")

    local roundTripped = GuideStore:GetGuide(9010)
    check(roundTripped == goodGuide, "GetGuide returns the exact guide table that was registered")
    check(roundTripped.specName == "Frostfire", "round-tripped guide keeps its specName")
    check(#roundTripped.statPriority == 4, "round-tripped guide keeps its full statPriority")
end

-- Registration order is preserved per class. Compared relative to whatever
-- was already registered for PALADIN by the shipped guide data file (which
-- may or may not have run yet), rather than assuming an exact count, since
-- these tests exercise the same store the real Data\Guides_*.lua files feed.
do
    local baseCount = #GuideStore:GetClassSpecs("PALADIN")

    GuideStore:RegisterSpec("PALADIN", 9101, { specName = "Order Spec A", role = "TANK" })
    GuideStore:RegisterSpec("PALADIN", 9102, { specName = "Order Spec B", role = "HEALER" })
    GuideStore:RegisterSpec("PALADIN", 9103, { specName = "Order Spec C", role = "DAMAGER" })

    local specs = GuideStore:GetClassSpecs("PALADIN")
    check(#specs == baseCount + 3, "GetClassSpecs grows by exactly the number of newly registered specs", #specs)

    local indexOf = {}
    for index, specID in ipairs(specs) do
        if specID == 9101 or specID == 9102 or specID == 9103 then
            indexOf[specID] = index
        end
    end
    check(indexOf[9101] and indexOf[9102] and indexOf[9103]
        and indexOf[9101] < indexOf[9102] and indexOf[9102] < indexOf[9103],
        "GetClassSpecs preserves registration order among newly registered specs", table.concat(specs, ","))

    -- Registering the same specID again must not duplicate it in the order.
    GuideStore:RegisterSpec("PALADIN", 9102, { specName = "Order Spec B Updated", role = "HEALER" })
    specs = GuideStore:GetClassSpecs("PALADIN")
    check(#specs == baseCount + 3, "re-registering an existing specID does not duplicate its slot in the order", #specs)
    check(GuideStore:GetGuide(9102).specName == "Order Spec B Updated",
        "re-registering an existing specID updates its guide")
end

-- Every shipped data file (populated by work package C) registers guides
-- with valid stat keys and non-empty rotations.
do
    local anyShipped = false
    for _, classEntry in ipairs(GuideStore:GetClasses()) do
        for _, specID in ipairs(GuideStore:GetClassSpecs(classEntry.token)) do
            -- Skip the synthetic test specIDs registered above (9000+).
            if specID < 9000 then
                anyShipped = true
                local guide = GuideStore:GetGuide(specID)
                check(guide ~= nil, format("shipped guide exists for %s spec %d", classEntry.token, specID))
                if guide then
                    check(type(guide.specName) == "string" and guide.specName ~= "",
                        format("shipped guide for %s spec %d has a specName", classEntry.token, specID))
                    if guide.rotation ~= nil then
                        check(type(guide.rotation) == "table" and #guide.rotation > 0,
                            format("shipped guide for %s spec %d has a non-empty rotation", classEntry.token, specID))
                    end
                end
            end
        end
    end
    check(anyShipped == true, "at least one shipped class guide is registered (Shaman)", anyShipped)
end

--------------------------------------------------------------------------------
section("Combat module")
--------------------------------------------------------------------------------

local PLAYER = "Player-1234-ABCDEF"
local PET = "Pet-0-1234"
local ENEMY = "Creature-0-9999"
local MINE_PET_FLAGS = 0x00000001 + 0x00001000

mock.inCombat = true
mock.Fire("PLAYER_REGEN_DISABLED")

-- SPELL_DAMAGE: amount sits at index 15.
mock.FireCombatLog(mock.now, "SPELL_DAMAGE", false, PLAYER, "Player", 0, 0, ENEMY, "Target", 0, 0,
    12345, "Frostbolt", 16, 60000, 0, 16, 0, 0, 0, false)

-- SWING_DAMAGE: amount sits at index 12.
mock.FireCombatLog(mock.now, "SWING_DAMAGE", false, PLAYER, "Player", 0, 0, ENEMY, "Target", 0, 0,
    40000, 0, 1, 0, 0, 0, false)

mock.Advance(10)
mock.RunTickers()

local dpsRow = findRow("combat", "DPS")
check(dpsRow ~= nil, "DPS row rendered")
check(dpsRow and dpsRow.value == "10.0K", "damage from both payload layouts counted (100k over 10s)", dpsRow and dpsRow.value)

-- Healing must exclude overhealing.
mock.FireCombatLog(mock.now, "SPELL_HEAL", false, PLAYER, "Player", 0, 0, PLAYER, "Player", 0, 0,
    2061, "Heal", 2, 50000, 30000, 0, false)
mock.RunTickers()

local hpsRow = findRow("combat", "HPS")
check(hpsRow and hpsRow.value == "2000", "overhealing excluded from HPS (20k effective over 10s)", hpsRow and hpsRow.value)

-- Damage taken is tracked separately from damage done.
ns.db.combat.showDamageTaken = true
mock.FireCombatLog(mock.now, "SPELL_DAMAGE", false, ENEMY, "Target", 0, 0, PLAYER, "Player", 0, 0,
    999, "Smash", 1, 30000, 0, 1, 0, 0, 0, false)
mock.RunTickers()

local dtpsRow = findRow("combat", "DTPS")
check(dtpsRow and dtpsRow.value == "3000", "incoming damage tracked as DTPS", dtpsRow and dtpsRow.value)

-- Enemy damage must not inflate the player's own DPS.
dpsRow = findRow("combat", "DPS")
check(dpsRow and dpsRow.value == "10.0K", "enemy damage did not count towards player DPS", dpsRow and dpsRow.value)

-- Pet damage respects the includePets setting.
mock.FireCombatLog(mock.now, "SPELL_DAMAGE", false, PET, "Pet", MINE_PET_FLAGS, 0, ENEMY, "Target", 0, 0,
    111, "Claw", 1, 20000, 0, 1, 0, 0, 0, false)
mock.RunTickers()
dpsRow = findRow("combat", "DPS")
check(dpsRow and dpsRow.value == "12.0K", "pet damage counted when includePets is on", dpsRow and dpsRow.value)

ns.db.combat.includePets = false
mock.FireCombatLog(mock.now, "SPELL_DAMAGE", false, PET, "Pet", MINE_PET_FLAGS, 0, ENEMY, "Target", 0, 0,
    111, "Claw", 1, 20000, 0, 1, 0, 0, 0, false)
mock.RunTickers()
dpsRow = findRow("combat", "DPS")
check(dpsRow and dpsRow.value == "12.0K", "pet damage ignored when includePets is off", dpsRow and dpsRow.value)

-- Leaving combat freezes the fight clock.
mock.inCombat = false
mock.Fire("PLAYER_REGEN_ENABLED")
local frozen = findRow("combat", "Last Fight")
check(frozen ~= nil, "fight duration label switches out of combat")
mock.Advance(30)
mock.RunTickers()
local stillFrozen = findRow("combat", "Last Fight")
check(stillFrozen and stillFrozen.value == frozen.value, "fight clock does not advance out of combat",
    stillFrozen and stillFrozen.value)

-- A new pull starts a fresh segment.
mock.inCombat = true
mock.Fire("PLAYER_REGEN_DISABLED")
mock.Advance(5)
mock.RunTickers()
dpsRow = findRow("combat", "DPS")
check(dpsRow and dpsRow.value == "0", "new pull resets fight damage", dpsRow and dpsRow.value)
mock.inCombat = false
mock.Fire("PLAYER_REGEN_ENABLED")

--------------------------------------------------------------------------------
section("Procs module")
--------------------------------------------------------------------------------

mock.ClearAuras()
mock.AddAura(377097, 12)
mock.Fire("UNIT_AURA", "player")

local procRow = findRow("procs", "Trinket Proc")
check(procRow ~= nil, "auto-detected proc rendered")
check(procRow and procRow.icon == 136116, "proc row carries the spell icon", procRow and procRow.icon)

-- Long buffs (flasks, food) must not be treated as procs.
mock.AddAura(12472, 3600)
mock.Fire("UNIT_AURA", "player")
check(findRow("procs", "Icy Veins") == nil, "buffs longer than maxDuration are ignored")

mock.ClearAuras()
mock.Fire("UNIT_AURA", "player")

-- Watched spells show their state even with no aura up.
local ok, result = ns:GetModule("Procs"):Watch(190319)
check(ok, "watching a valid spell succeeds", result)
check(findRow("procs", "Combustion") ~= nil, "watched spell shows while ready")

local readyRow = findRow("procs", "Combustion")
check(readyRow and readyRow.value == "ready", "ready watched spell labelled", readyRow and readyRow.value)

mock.cooldowns[190319] = { start = mock.now, duration = 120 }
ns:GetModule("Procs"):Update()
local cdRow = findRow("procs", "Combustion")
check(cdRow and cdRow.value == "2:00", "watched spell shows cooldown remaining", cdRow and cdRow.value)
check(cdRow and cdRow.desaturate == true, "cooldown row is desaturated")

-- The global cooldown should never read as "on cooldown".
mock.cooldowns[190319] = { start = mock.now, duration = 1.5 }
ns:GetModule("Procs"):Update()
local gcdRow = findRow("procs", "Combustion")
check(gcdRow and gcdRow.value == "ready", "global cooldown is not reported as a cooldown", gcdRow and gcdRow.value)

-- An active aura takes priority over cooldown display.
mock.cooldowns[190319] = { start = mock.now, duration = 120 }
mock.AddAura(190319, 10, 3)
ns:GetModule("Procs"):Update()
local activeRow = findRow("procs", "Combustion")
check(activeRow and activeRow.value == "10.0s", "active aura shows remaining duration", activeRow and activeRow.value)
check(activeRow and activeRow.label == "Combustion (3)", "stack count shown", activeRow and activeRow.label)

local unwatched = ns:GetModule("Procs"):Unwatch(190319)
check(unwatched, "unwatching removes the spell")
check(#ns.chardb.watch == 0, "watch list empty after unwatch")

local badWatch, reason = ns:GetModule("Procs"):Watch(999999)
check(not badWatch, "watching an unknown spell ID is rejected", reason)

--------------------------------------------------------------------------------
section("Per-character stat visibility")
--------------------------------------------------------------------------------

check(ns.StatsShown() == ns.chardb.statsShow, "stat visibility reads from the character DB")
check(ns.db.stats.show == nil, "stat visibility no longer lives in the shared DB")

-- Toggling on this character must not touch the account-wide table.
ns.StatsShown().armor = true
ns.RefreshAll()
check(findRow("stats", "Armor") ~= nil, "enabling armor on this character shows it")
check(ns.db.stats.show == nil, "toggling did not write back to the shared DB")
ns.StatsShown().armor = false
ns.RefreshAll()

-- A second character starts from its own defaults, not the first one's choices.
local firstCharacter = SpecSageCharDB
ns.StatsShown().speed = true
SpecSageCharDB = nil
ns.InitConfig()
check(ns.chardb ~= firstCharacter, "a new character gets a fresh character DB")
check(ns.chardb.statsShow.speed == false, "second character does not inherit the first character's choices",
    ns.chardb.statsShow.speed)
check(firstCharacter.statsShow.speed == true, "first character keeps its own choice")

-- An upgrade from the account-wide layout carries the old choice across once.
SpecSageDB.stats.show = { crit = false, armor = true, haste = false }
SpecSageCharDB = nil
ns.InitConfig()
check(ns.chardb.statsShow.crit == false, "legacy account-wide choice migrated (crit off)", ns.chardb.statsShow.crit)
check(ns.chardb.statsShow.armor == true, "legacy account-wide choice migrated (armor on)", ns.chardb.statsShow.armor)
check(ns.chardb.migratedStatVisibility == true, "migration is marked done")

-- Migration must not run twice and undo later changes.
ns.chardb.statsShow.crit = true
ns.InitConfig()
check(ns.chardb.statsShow.crit == true, "migration does not re-run over later changes")

SpecSageDB.stats.show = nil
SpecSageCharDB = firstCharacter
ns.InitConfig()
ns.RefreshAll()

--------------------------------------------------------------------------------
section("Tooltips")
--------------------------------------------------------------------------------

-- Find the live row frames so hover can be simulated the way the client does.
local function rowFrameFor(key)
    for _, frame in ipairs(mock.frames) do
        if frame.tooltipKey == key then return frame end
    end
    return nil
end

ns.db.tooltips = true
ns.RefreshAll()
ns.UI:Relayout()

local hoverTip = SpecSageHoverTooltip
check(hoverTip ~= nil, "addon owns a hover tooltip frame rather than reusing GameTooltip")

local function dumpOf(frame)
    return table.concat(frame:Dump(), " | ")
end

local critFrame = rowFrameFor("crit")
check(critFrame ~= nil, "stat rows carry a tooltip key")
check(critFrame and critFrame.mouseEnabled == true, "tooltip rows accept mouse input")
check(critFrame and critFrame.propagateClicks == true, "clicks still pass through for click-through locking")

critFrame.scripts.OnEnter(critFrame)
local dump = dumpOf(hoverTip)
check(hoverTip.shown, "hovering a stat shows a tooltip")
check(dump:find("Crit=21.34%%") ~= nil, "tooltip headline shows the stat and its value", dump)
check(dump:find("Rating=1009") ~= nil, "tooltip shows the underlying combat rating", dump)
check(dump:find("From rating=4.50%%") ~= nil, "tooltip shows what the rating converts to", dump)
check(dump:find("critically strike") ~= nil, "tooltip explains what the stat does", dump)
check(dump:find("Click to keep this on screen") ~= nil, "hover tooltip explains how to pin it", dump)

-- Leaving the row must not hide instantly, or the mouse could never reach the
-- tooltip to click it.
critFrame.scripts.OnLeave(critFrame)
check(hoverTip.shown, "tooltip survives leaving the row long enough to be reached")
mock.RunAfter()
check(not hoverTip.shown, "tooltip hides once the grace period expires")

-- Moving into the tooltip cancels the pending hide.
critFrame.scripts.OnEnter(critFrame)
critFrame.scripts.OnLeave(critFrame)
hoverTip.scripts.OnEnter(hoverTip)
mock.RunAfter()
check(hoverTip.shown, "entering the tooltip cancels the scheduled hide")

-- Versatility reports both halves of what it does.
local versFrame = rowFrameFor("vers")
versFrame.scripts.OnEnter(versFrame)
dump = dumpOf(hoverTip)
check(dump:find("Damage and healing done") ~= nil, "versatility tooltip covers damage done", dump)
check(dump:find("Damage taken reduced by") ~= nil, "versatility tooltip covers damage reduction", dump)

-- Primary stat breaks down base versus buffs.
local primaryFrame = rowFrameFor("primary")
primaryFrame.scripts.OnEnter(primaryFrame)
dump = dumpOf(hoverTip)
check(dump:find("Base=8300") ~= nil, "primary tooltip shows base value", dump)
check(dump:find("From gear and buffs=%+200") ~= nil, "primary tooltip shows the buffed portion", dump)

-- Item level distinguishes equipped from overall.
local ilvlFrame = rowFrameFor("ilvl")
ilvlFrame.scripts.OnEnter(ilvlFrame)
dump = dumpOf(hoverTip)
check(dump:find("Equipped=636.2") ~= nil, "item level tooltip shows equipped", dump)
check(dump:find("Overall=639.5") ~= nil, "item level tooltip shows overall", dump)

-- Proc rows defer to the game's own spell tooltip.
ns:GetModule("Procs"):Watch(190319)
ns.RefreshAll()
ns.UI:Relayout()
local procFrame = rowFrameFor(190319)
check(procFrame ~= nil, "proc rows carry the spell ID as their tooltip key")
procFrame.scripts.OnEnter(procFrame)
check(hoverTip.spellID == 190319, "proc tooltip uses the real spell tooltip", hoverTip.spellID)
ns:GetModule("Procs"):Unwatch(190319)

--------------------------------------------------------------------------------
section("Pinned tooltips")
--------------------------------------------------------------------------------

local Tooltips = ns.Tooltips
Tooltips:UnpinAll()

-- Clicking the hover tooltip pins whatever is under the cursor.
local armorFrame = rowFrameFor("armor")
check(armorFrame == nil, "armor row hidden by default")
ns.StatsShown().armor = true
ns.RefreshAll()
ns.UI:Relayout()
armorFrame = rowFrameFor("armor")
check(armorFrame ~= nil, "armor row present once enabled")

armorFrame.scripts.OnEnter(armorFrame)
hoverTip.scripts.OnMouseDown(hoverTip)
check(Tooltips:IsPinned("stats", "armor"), "clicking the hover tooltip pins it")
check(not hoverTip.shown, "hover tooltip closes once pinned")

local pinned = _G.SpecSagePinnedTooltip1
check(pinned ~= nil and pinned.shown, "a pinned tooltip frame is shown")
dump = dumpOf(pinned)
check(dump:find("Armor=") ~= nil, "pinned tooltip shows the stat", dump)
check(dump:find("physical damage") ~= nil, "pinned tooltip keeps the explanation", dump)
check(dump:find("Click to keep this on screen") == nil, "pinned tooltip drops the pin hint", dump)

-- Pinned content refreshes on its own so the numbers stay live. Change the
-- underlying value and the pin must pick it up without being re-opened.
check(dumpOf(pinned):find("Effective=4500") ~= nil, "pinned tooltip starts with the current armor")
mock.armor.effective = 7777
mock.RunTickers()
check(dumpOf(pinned):find("Effective=7777") ~= nil, "pinned tooltip refreshes from its provider",
    dumpOf(pinned))
mock.armor.effective = 4500

-- Hovering an already-pinned row should not double up.
armorFrame.scripts.OnEnter(armorFrame)
check(not hoverTip.shown, "hovering an already-pinned row does not reopen the hover tooltip")

-- Pinning the same thing twice is rejected.
local okDup, reasonDup = Tooltips:Pin("stats", "armor")
check(not okDup, "pinning the same row twice is rejected", reasonDup)

-- A second pin stacks below the first rather than covering it.
local okSecond = Tooltips:Pin("stats", "crit")
check(okSecond, "a second row can be pinned")
check(#Tooltips:ListPinned() == 2, "two pins tracked", #Tooltips:ListPinned())

-- Pins survive a reload: they are saved and restored by key.
check(ns.db.pinnedTooltips["stats:armor"] ~= nil, "pin saved to the database")
local savedPins = ns.db.pinnedTooltips
Tooltips:UnpinAll()
check(#Tooltips:ListPinned() == 0, "unpin all clears every pin")
check(next(savedPins) == nil, "unpinning clears the saved entries too")

ns.db.pinnedTooltips["stats:crit"] = { section = "stats", key = "crit" }
Tooltips:RestoreSaved()
check(Tooltips:IsPinned("stats", "crit"), "saved pins are restored")

-- Closing via the frame's own close button works.
local critPin
for _, frame in ipairs(mock.frames) do
    if frame.pinID == "stats:crit" then critPin = frame end
end
check(critPin ~= nil, "pinned frame carries its id")
critPin.closeButton.scripts.OnClick()
check(not Tooltips:IsPinned("stats", "crit"), "close button unpins")

-- Right-clicking a pin closes it; left-clicking does not.
Tooltips:Pin("stats", "crit")
critPin = nil
for _, frame in ipairs(mock.frames) do
    if frame.pinID == "stats:crit" then critPin = frame end
end
critPin.scripts.OnMouseUp(critPin, "LeftButton")
check(Tooltips:IsPinned("stats", "crit"), "left-clicking a pin does not close it")
critPin.scripts.OnMouseUp(critPin, "RightButton")
check(not Tooltips:IsPinned("stats", "crit"), "right-clicking a pin closes it")

-- Pinning with nothing hovered reports why rather than erroring.
Tooltips:HideHover()
local okNone, reasonNone = Tooltips:PinHovered()
check(not okNone, "pinning with nothing hovered is rejected", reasonNone)

-- The key binding entry point is defined and safe to call.
check(type(SpecSage_PinHoveredTooltip) == "function", "binding handler is a global function")
check(pcall(SpecSage_PinHoveredTooltip), "binding handler runs without a hovered row")
check(BINDING_NAME_SPECSAGE_PIN_TOOLTIP ~= nil, "binding has a display name")

-- Resetting config must not leave orphaned pins on screen.
Tooltips:Pin("stats", "armor")
ns.ResetConfig()
check(#Tooltips:ListPinned() == 0, "reset all closes pinned tooltips")

ns.StatsShown().armor = false
ns.db.tooltips = true
ns.RefreshAll()
ns.UI:Relayout()

-- Disabling tooltips releases the mouse entirely.
ns.db.tooltips = false
ns.RefreshAll()
ns.UI:Relayout()
critFrame = rowFrameFor("crit")
check(critFrame == nil, "disabling tooltips clears tooltip keys from rows")

ns.db.tooltips = true
ns.RefreshAll()
ns.UI:Relayout()

--------------------------------------------------------------------------------
section("Layout")
--------------------------------------------------------------------------------

ns.UI:Relayout()
local frame = ns.UI.frame
check(frame:GetHeight() > 20, "frame height grows to fit its rows", frame:GetHeight())
check(frame:GetWidth() == ns.db.width, "frame width follows config", frame:GetWidth())

-- Shrinking the content must hide the leftover rows rather than leave stale text.
local before = frame:GetHeight()
ns.db.stats.enabled = false
ns.db.combat.enabled = false
ns.db.procs.enabled = false
ns.RefreshAll()
ns.UI:Relayout()
check(frame:GetHeight() < before, "frame shrinks when sections are disabled", frame:GetHeight())

ns.db.stats.enabled = true
ns.db.combat.enabled = true
ns.db.procs.enabled = true
ns.RefreshAll()

--------------------------------------------------------------------------------
section("Visibility")
--------------------------------------------------------------------------------

ns.db.hidden = false
ns.db.hideOutOfCombat = false
ns.UI:UpdateVisibility()
check(frame:IsShown(), "overlay visible by default")

local nowVisible = ns.UI:Toggle()
check(not nowVisible and not frame:IsShown(), "toggle hides the overlay")

-- A manual hide must survive combat, which is what a naive implementation
-- would clobber.
mock.inCombat = true
mock.Fire("PLAYER_REGEN_DISABLED")
check(not frame:IsShown(), "entering combat does not un-hide a manually hidden overlay")
mock.inCombat = false
mock.Fire("PLAYER_REGEN_ENABLED")

ns.UI:Toggle()
check(frame:IsShown(), "toggle shows it again")

ns.db.hideOutOfCombat = true
ns.UI:UpdateVisibility()
check(not frame:IsShown(), "hide-out-of-combat hides while resting")
mock.inCombat = true
ns.UI:UpdateVisibility()
check(frame:IsShown(), "hide-out-of-combat shows in combat")
mock.inCombat = false
ns.db.hideOutOfCombat = false
ns.UI:UpdateVisibility()

--------------------------------------------------------------------------------
section("Slash commands")
--------------------------------------------------------------------------------

local handler = SlashCmdList.SPECSAGE

local function run(input)
    local silenced = _G.print
    _G.print = function() end
    local success, err = pcall(handler, input)
    _G.print = silenced
    return success, err
end

-- The bare command now toggles the Codex, not the overlay; the overlay moved
-- to its own "overlay" subcommand.
local codexToggled = 0
ns.Codex = {
    Toggle = function() codexToggled = codexToggled + 1 end,
}

do
    local success, err = run("")
    check(success, "/sage (bare) does not error", err)
    check(codexToggled == 1, "/sage (bare) toggles the Codex when it is loaded")
end

ns.Codex = nil
do
    local success, err = run("")
    check(success, "/sage (bare) with no Codex loaded does not error", err)
end

do
    local overlayShown = ns.UI:Toggle() -- restore known state
    if not overlayShown then ns.UI:Toggle() end
end

do
    local wasHidden = ns.db.hidden
    local success, err = run("overlay")
    check(success, "/sage overlay does not error", err)
    check(ns.db.hidden ~= wasHidden, "/sage overlay toggles the overlay's hidden state")
    run("overlay") -- put it back
end

-- /sage guide <class> [spec] fuzzy-matches and hands off to the Codex.
do
    local opened = {}
    ns.Codex = {
        Toggle = function() codexToggled = codexToggled + 1 end,
        Open = function(_, classToken, specID) opened[#opened + 1] = { classToken, specID } end,
    }

    local success, err = run("guide warrior")
    check(success, "/sage guide warrior does not error", err)
    check(#opened == 1 and opened[1][1] == "WARRIOR", "/sage guide warrior resolves the WARRIOR token",
        opened[1] and opened[1][1])
    check(opened[1][2] == nil, "/sage guide warrior with no spec passes a nil specID")

    -- "war" alone is ambiguous (Warrior/Warlock both start with it); "warr"
    -- narrows to Warrior only.
    success, err = run("guide warr")
    check(success, "/sage guide warr (prefix match) does not error", err)
    check(#opened == 2 and opened[2][1] == "WARRIOR", "/sage guide warr fuzzy-matches to WARRIOR by prefix")

    success, err = run("guide shaman elemental")
    check(success, "/sage guide shaman elemental does not error", err)
    check(#opened == 3 and opened[3][1] == "SHAMAN" and opened[3][2] == 262,
        "/sage guide shaman elemental resolves both class and spec",
        opened[3] and (opened[3][1] .. ":" .. tostring(opened[3][2])))

    -- An ambiguous prefix (matches both Warrior and Warlock) is reported
    -- rather than guessing.
    success, err = run("guide war")
    check(success, "/sage guide war (ambiguous prefix) does not error", err)
    check(#opened == 3, "/sage guide war does not call Codex:Open when the class is ambiguous")

    success, err = run("guide nosuchclass")
    check(success, "/sage guide <unknown class> does not error", err)
    check(#opened == 3, "/sage guide <unknown class> does not call Codex:Open")

    success, err = run("guide")
    check(success, "/sage guide with no argument does not error", err)
    check(#opened == 3, "/sage guide with no argument does not call Codex:Open")

    ns.Codex = nil
    success, err = run("guide warrior")
    check(success, "/sage guide warrior with no Codex loaded does not error", err)
end

local commands = {
    "", "", "help", "lock", "unlock", "config", "scan", "dps",
    "scale 1.5", "width 240", "font 14", "stat", "stat crit",
    "watch", "watch 190319", "watch list", "unwatch 190319", "tooltips", "tooltips",
    "pin", "pin crit", "pin crit", "pins", "unpin crit", "unpin all", "pin bogus",
    "reset dps", "reset pos", "nonsense", "scale bogus", "watch bogus",
    "overlay", "overlay", "guide", "guide bogus", "guide warrior bogus",
}

for _, command in ipairs(commands) do
    local success, err = run(command)
    check(success, "/sage " .. (command == "" and "(toggle)" or command), err)
end

check(ns.db.scale == 1.5, "scale command applied", ns.db.scale)
check(ns.db.width == 240, "width command applied", ns.db.width)
check(ns.db.fontSize == 14, "font command applied", ns.db.fontSize)
check(ns.db.locked == false, "lock then unlock leaves it unlocked")

-- Out-of-range values must be rejected rather than applied.
run("scale 99")
check(ns.db.scale == 1.5, "out-of-range scale rejected", ns.db.scale)

run("reset all")
check(ns.db.scale == 1.0, "reset all restores defaults", ns.db.scale)

-- /specsage is registered as an alias of /sage.
check(SLASH_SPECSAGE1 == "/sage", "SLASH_SPECSAGE1 is /sage")
check(SLASH_SPECSAGE2 == "/specsage", "SLASH_SPECSAGE2 is /specsage")

--------------------------------------------------------------------------------
section("Options panel")
--------------------------------------------------------------------------------

local options = ns:GetModule("Options")
check(options.category ~= nil, "settings category registered")
check(pcall(ns.OpenOptions), "opening options does not error")

--------------------------------------------------------------------------------
section("Ticker safety")
--------------------------------------------------------------------------------

-- Everything should keep running for a while without throwing.
local survived = pcall(function()
    for _ = 1, 50 do
        mock.Advance(0.1)
        mock.RunTickers()
        mock.Tick(0.1)
    end
end)
check(survived, "50 ticker cycles run without error")

--------------------------------------------------------------------------------
section("Loadouts module (Modules/Loadouts.lua)")
--------------------------------------------------------------------------------

local LoadoutsModule = ns:GetModule("Loadouts")
check(LoadoutsModule ~= nil, "Loadouts module registered at load time")

-- Uses a synthetic specID (9401), the same >=9000 convention the GuideStore
-- tests above use, so this cannot collide with a shipped class guide's spec.
check(#LoadoutsModule:GetForSpec(9401) == 0, "GetForSpec returns an empty list for a spec with nothing saved")
check(ns.db.loadouts[9401] == nil, "reading an empty spec does not create clutter in the saved variables")

do
    local ok, err = LoadoutsModule:Add(9401, "", "Raid", "SomeExportString")
    check(ok == false, "Add rejects an empty name", err)
end

do
    local ok, err = LoadoutsModule:Add(9401, "   ", "Raid", "SomeExportString")
    check(ok == false, "Add rejects a whitespace-only name", err)
end

do
    local ok, err = LoadoutsModule:Add(9401, "My Build", "Raid", "")
    check(ok == false, "Add rejects an empty export string", err)
end

do
    local ok, err = LoadoutsModule:Add("not-a-number", "My Build", "Raid", "ExportABC")
    check(ok == false, "Add rejects a non-number specID", err)
end

do
    local ok, entry = LoadoutsModule:Add(9401, "  Raid Build  ", "Raid", "ExportABC")
    check(ok == true, "Add accepts a valid loadout")
    check(entry.name == "Raid Build", "Add trims surrounding whitespace from the name", entry.name)
    check(entry.category == "Raid", "Add keeps a valid category", entry.category)
end

do
    local ok, entry = LoadoutsModule:Add(9401, "Mythic+ Build", "NotARealCategory", "ExportDEF")
    check(ok == true, "Add accepts an invalid category rather than rejecting the whole entry")
    check(entry.category == "Other", "an invalid category falls back to Other", entry.category)
end

local savedList = LoadoutsModule:GetForSpec(9401)
check(#savedList == 2, "both loadouts round-trip through GetForSpec", #savedList)
check(savedList[1].name == "Raid Build" and savedList[2].name == "Mythic+ Build",
    "loadouts keep registration order")
check(ns.db.loadouts[9401] == savedList, "GetForSpec returns the live saved-variable table once one exists")

check(LoadoutsModule:Delete(9401, 5) == false, "Delete rejects an out-of-range index")
check(LoadoutsModule:Delete(9999, 1) == false, "Delete on a spec with nothing saved returns false rather than erroring")

do
    local ok = LoadoutsModule:Delete(9401, 1)
    check(ok == true, "Delete removes the loadout at the given index")
    local remaining = LoadoutsModule:GetForSpec(9401)
    check(#remaining == 1 and remaining[1].name == "Mythic+ Build",
        "the remaining loadout shifts into place", remaining[1] and remaining[1].name)
end

-- GetSpecialization()=2 -> GetSpecializationInfo(2) returns specID 252 in
-- the mock (see wow_mock.lua); this is the same value Stats.lua's own
-- primary-stat lookup already depends on.
check(LoadoutsModule:GetCurrentSpecID() == 252, "GetCurrentSpecID reads the player's current spec from the mock",
    LoadoutsModule:GetCurrentSpecID())

check(LoadoutsModule:ExportCurrent() == "SpecSage-mock-export-string",
    "ExportCurrent reads the mock's export string via the C_Traits fallback chain", LoadoutsModule:ExportCurrent())

do
    -- No active talent config: the fallback chain must degrade to nil
    -- rather than erroring.
    local realGetActiveConfigID = C_ClassTalents.GetActiveConfigID
    C_ClassTalents.GetActiveConfigID = function() return nil end
    check(LoadoutsModule:ExportCurrent() == nil, "ExportCurrent returns nil with no active talent config")
    C_ClassTalents.GetActiveConfigID = realGetActiveConfigID
end

do
    -- A client with no talent-loadout API at all (e.g. Classic) must not
    -- error either.
    local realC_ClassTalents = C_ClassTalents
    C_ClassTalents = nil
    check(LoadoutsModule:ExportCurrent() == nil, "ExportCurrent returns nil without C_ClassTalents at all")
    C_ClassTalents = realC_ClassTalents
end

--------------------------------------------------------------------------------
section("Notes module (Modules/Notes.lua)")
--------------------------------------------------------------------------------

local NotesModule = ns:GetModule("Notes")
check(NotesModule ~= nil, "Notes module registered at load time")

check(NotesModule:Get(9402) == "", "Get returns an empty string for a spec with no saved note")
check(ns.db.notes[9402] == nil, "reading an unset note does not create a saved-variable entry")

check(NotesModule:Set(9402, "Remember trinket swap at 30% add health.") == true, "Set accepts a real note")
check(NotesModule:Get(9402) == "Remember trinket swap at 30% add health.", "Get round-trips the saved note")

check(NotesModule:Set(9402, "   ") == true, "Set accepts whitespace-only text")
check(NotesModule:Get(9402) == "", "whitespace-only text reads back as empty", NotesModule:Get(9402))
check(ns.db.notes[9402] == nil, "whitespace-only text is stored as nil, not an empty string")

NotesModule:Set(9402, "Second note.")
NotesModule:Set(9402, "")
check(ns.db.notes[9402] == nil, "an empty string also clears the saved note")

check(NotesModule:Set("not-a-number", "text") == false, "Set rejects a non-number specID")
check(NotesModule:Get("not-a-number") == "", "Get returns empty for a non-number specID rather than erroring")

--------------------------------------------------------------------------------
section("Codex (UI/Codex.lua)")
--------------------------------------------------------------------------------

-- Restore the real module the slash-command tests replaced with stand-ins.
ns.Codex = RealCodex
local Codex = ns.Codex

check(Codex ~= nil, "Codex module registered at load time")
check(type(Codex.Toggle) == "function" and type(Codex.Open) == "function" and type(Codex.IsShown) == "function",
    "Codex exposes Toggle/Open/IsShown")
check(Codex:IsShown() == false, "Codex starts hidden with no frame built yet")

Codex:Toggle()
check(Codex.frame ~= nil, "Toggle builds the frame lazily on first use, not at load")
check(Codex:IsShown() == true, "Toggle shows the frame")
check(Codex.selectedClass ~= nil, "first-ever open defaults to a class", Codex.selectedClass)
check(Codex.selectedClass == "DEATHKNIGHT", "first-ever open defaults to the player's own class (per UnitClass in the mock)",
    Codex.selectedClass)
check(Codex.selectedSpecID == 252, "first-ever open defaults to the player's own current spec", Codex.selectedSpecID)

Codex:Toggle()
check(Codex:IsShown() == false, "a second Toggle hides the frame")
Codex:Toggle()
check(Codex:IsShown() == true, "a third Toggle shows it again, keeping the prior selection")

-- Open() selects an explicit class/spec regardless of what was open before.
Codex:Open("WARRIOR", 72)
check(Codex.selectedClass == "WARRIOR", "Open selects the requested class")
check(Codex.selectedSpecID == 72, "Open selects the requested spec")
check(Codex:IsShown() == true, "Open leaves the frame shown")

local TAB_NAMES = { "Overview", "Stats", "Rotation", "Cooldowns", "Consumables", "Loadouts", "Notes" }

-- Tab switching must render every tab without error for a spec with real
-- guide data (Warrior Fury, spec 72 - see Data/Guides_Warrior.lua).
for _, tabName in ipairs(TAB_NAMES) do
    local ok, err = pcall(function() Codex:SelectTab(tabName) end)
    check(ok, "tab " .. tabName .. " renders without error for a spec WITH guide data (Warrior/72)", err)
end
check(Codex.activeTab == "Notes", "SelectTab updates the active tab", Codex.activeTab)

-- ...and for a spec with no guide registered at all.
check(ns.GuideStore:GetGuide(424242) == nil, "sanity check: specID 424242 has no guide registered")
Codex:Open("WARRIOR", 424242)
for _, tabName in ipairs(TAB_NAMES) do
    local ok, err = pcall(function() Codex:SelectTab(tabName) end)
    check(ok, "tab " .. tabName .. " renders without error for a spec WITHOUT guide data", err)
end

-- Stats tab must not error whether or not the viewed spec is the player's
-- own (252); the live-value lookup only applies to the player's own spec.
Codex:Open("DEATHKNIGHT", 252)
check(pcall(function() Codex:SelectTab("Stats") end), "Stats tab renders for the player's own spec")
Codex:Open("WARRIOR", 71) -- Arms: a real, different spec
check(pcall(function() Codex:SelectTab("Stats") end), "Stats tab renders for a spec that is not the player's own")

-- The class rail lists all 13 classes, matching GuideStore:GetClasses().
for _, entry in ipairs(ns.GuideStore:GetClasses()) do
    check(Codex.classButtons[entry.token] ~= nil, "class rail has a button for " .. entry.token)
end

--------------------------------------------------------------------------------
section("Codex: Loadouts tab")
--------------------------------------------------------------------------------

Codex:Open("WARRIOR", 72)
Codex:SelectTab("Loadouts")

local beforeCount = #LoadoutsModule:GetForSpec(72)

Codex:ShowAddDialog("TestImportString123")
check(Codex.addDialog:IsShown(), "Save/Add opens the Add-from-string dialog")
check(Codex.addImportBox:GetText() == "TestImportString123",
    "the dialog prefills the import string when one is given (as Save current would)")

Codex.addNameBox:SetText("My Mythic+ Build")
Codex.addCategoryButton:GetScript("OnClick")() -- cycle the category away from its "Other" default
Codex:OnAddDialogSave()

check(not Codex.addDialog:IsShown(), "saving closes the Add dialog")
local afterAdd = LoadoutsModule:GetForSpec(72)
check(#afterAdd == beforeCount + 1, "saving from the Add dialog stores exactly one new loadout", #afterAdd)
check(afterAdd[#afterAdd].name == "My Mythic+ Build", "the saved loadout keeps the entered name")
check(afterAdd[#afterAdd].export == "TestImportString123", "the saved loadout keeps the entered import string")
check(afterAdd[#afterAdd].category ~= "Other", "cycling the category button changed it away from the default",
    afterAdd[#afterAdd].category)

local savedRow = Codex.loadoutRowPool[#afterAdd]
check(savedRow ~= nil, "the newly saved loadout has a row in the Loadouts tab")

savedRow.copyButton:GetScript("OnClick")()
check(Codex.copyDialog:IsShown(), "Copy opens a dialog")
check(Codex.copyBox:GetText() == "TestImportString123", "the Copy dialog is populated with the loadout's export string")

-- Delete is a two-click confirm: the first click arms it, the second removes it.
local deleteButton = savedRow.deleteButton
local countBeforeDelete = #LoadoutsModule:GetForSpec(72)

deleteButton:GetScript("OnClick")(deleteButton)
check(deleteButton.armed == true, "the first Delete click arms the confirm")
check(#LoadoutsModule:GetForSpec(72) == countBeforeDelete, "the first Delete click does not remove anything yet")

deleteButton:GetScript("OnClick")(deleteButton)
check(#LoadoutsModule:GetForSpec(72) == countBeforeDelete - 1, "the second Delete click removes the loadout")

-- "Save current" is only offered for the player's own spec.
Codex:Open("DEATHKNIGHT", 252) -- the player's own spec, per the mock
Codex:SelectTab("Loadouts")
check(Codex.loadoutButtons.save:IsShown(), "Save current is shown while viewing the player's own spec")

Codex:Open("WARRIOR", 71) -- not the player's own spec
Codex:SelectTab("Loadouts")
check(not Codex.loadoutButtons.save:IsShown(), "Save current is hidden while viewing another spec")

--------------------------------------------------------------------------------
section("Codex: Notes tab")
--------------------------------------------------------------------------------

Codex:Open("WARRIOR", 72)
Codex:SelectTab("Notes")
check(Codex.notesBox ~= nil, "the Notes tab builds an editbox")
check(Codex.notesBox:GetText() == NotesModule:Get(72), "the Notes tab loads the spec's saved note")

Codex.notesBox:SetText("Watch for the add-phase trinket swap.")
Codex.notesBox:GetScript("OnEditFocusLost")(Codex.notesBox)
check(NotesModule:Get(72) == "Watch for the add-phase trinket swap.", "losing focus saves the note")

Codex.notesBox:SetText("Saved on window close.")
Codex.frame:GetScript("OnHide")(Codex.frame)
check(NotesModule:Get(72) == "Saved on window close.", "the Codex frame's OnHide also saves the open note")

--------------------------------------------------------------------------------
section("Codex: close")
--------------------------------------------------------------------------------

if not Codex:IsShown() then Codex:Toggle() end
check(Codex:IsShown() == true, "Codex is shown before the final close check")
Codex:Toggle()
check(Codex:IsShown() == false, "Toggle closes the Codex")

--------------------------------------------------------------------------------

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
