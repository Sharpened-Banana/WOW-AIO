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
    "Data\\Trinkets.lua",
    "Data\\BiS.lua",
    "Data\\SiteLoadouts.lua",
    "Data\\StatPriority.lua",
    "UI\\Overlay.lua",
    "UI\\Tooltips.lua",
    "UI\\Codex.lua",
    "UI\\CharacterPanel.lua",
    "Modules\\Stats.lua",
    "Modules\\Combat.lua",
    "Modules\\Procs.lua",
    "Modules\\Loadouts.lua",
    "Modules\\BiS.lua",
    "Modules\\ItemRanks.lua",
    "Modules\\Notes.lua",
    "Core\\Options.lua",
    "Core\\Commands.lua",
}

-- Keep addon chat output from drowning the test log.
local realPrint = print
local addonOutput = {}
_G.print = function(...)
    addonOutput[#addonOutput + 1] = tostring((select(1, ...)))
end

local ns = mock.LoadAddon("SpecSage", FILES, "SpecSage")

_G.print = realPrint

-- A guide file whose top-level RegisterSpec call gets rejected would print a
-- warning and otherwise load silently; nothing before this asserted that
-- addonOutput (captured above) was actually empty, so that failure mode
-- could pass the whole suite unnoticed.
check(#addonOutput == 0, "no addon warnings printed while loading", addonOutput[1])

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

-- A class nobody has registered a guide for returns an empty list, not an
-- error. "#t >= 0" is always true regardless of what GetClassSpecs actually
-- returns (and Monk has three shipped guides anyway, so it was never testing
-- the "nobody registered" case its own comment claimed); NOTACLASS is not a
-- real class token, so it is guaranteed to have nothing registered.
check(#GuideStore:GetClassSpecs("NOTACLASS") == 0, "GetClassSpecs returns an empty table for a class with no guides",
    #GuideStore:GetClassSpecs("NOTACLASS"))

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

-- gear is optional (DESIGN.md's "BiS / Gear" section) — a guide with no gear
-- key at all must still be accepted, the same as every guide before v1.1.
do
    local guide = { specName = "No Gear Spec", role = "DAMAGER" }
    local ok = GuideStore:RegisterSpec("MAGE", 9004, guide)
    check(ok == true, "RegisterSpec accepts a guide with no gear key at all")
    check(GuideStore:GetGuide(9004).gear == nil, "a guide with no gear key round-trips with gear still nil")
end

-- A valid gear array is accepted and round-trips, including a repeated slot
-- (DESIGN.md explicitly allows "two Trinket lines").
do
    local guide = {
        specName = "Gear Spec",
        role = "DAMAGER",
        gear = {
            { slot = "Head", text = "Tier set piece" },
            { slot = "Trinket", text = "On-use burst trinket" },
            { slot = "Trinket", text = "Passive stat stick" },
            { slot = "Weapon", text = "Highest item level" },
        },
    }
    local ok = GuideStore:RegisterSpec("MAGE", 9005, guide)
    check(ok == true, "RegisterSpec accepts a valid gear array")
    local roundTripped = GuideStore:GetGuide(9005)
    check(roundTripped ~= nil and #roundTripped.gear == 4, "round-tripped guide keeps its full gear array",
        roundTripped and roundTripped.gear and #roundTripped.gear)
end

-- An invalid slot value is rejected (guide skipped entirely), the same
-- validate-and-skip contract as a bad statPriority stat key.
do
    local badGuide = {
        specName = "Bad Gear Spec",
        role = "DAMAGER",
        gear = {
            { slot = "Head", text = "Fine" },
            { slot = "Cape", text = "Not a real slot name" },
        },
    }
    local ok, result = silently(function() return GuideStore:RegisterSpec("MAGE", 9006, badGuide) end)
    check(ok, "RegisterSpec with a bad gear slot does not error", result)
    check(result == false, "guide with an invalid gear slot is rejected")
    check(GuideStore:GetGuide(9006) == nil, "guide with a bad gear slot is not stored")
end

-- Empty gear text is rejected too.
do
    local badGuide = {
        specName = "Bad Gear Text Spec",
        role = "DAMAGER",
        gear = { { slot = "Head", text = "" } },
    }
    local ok, result = silently(function() return GuideStore:RegisterSpec("MAGE", 9007, badGuide) end)
    check(ok, "RegisterSpec with empty gear text does not error", result)
    check(result == false, "guide with empty gear text is rejected")
    check(GuideStore:GetGuide(9007) == nil, "guide with empty gear text is not stored")
end

-- mplusLoadout is optional (DESIGN.md's "Shipped Mythic+ talent loadout
-- (v1.2)" section) - a guide with no mplusLoadout key at all must still be
-- accepted, the same as every guide before v1.2.
do
    local guide = { specName = "No Loadout Spec", role = "DAMAGER" }
    local ok = GuideStore:RegisterSpec("MAGE", 9008, guide)
    check(ok == true, "RegisterSpec accepts a guide with no mplusLoadout key at all")
    check(GuideStore:GetGuide(9008).mplusLoadout == nil,
        "a guide with no mplusLoadout key round-trips with mplusLoadout still nil")
end

-- A valid mplusLoadout is accepted and round-trips.
do
    local guide = {
        specName = "Loadout Spec",
        role = "DAMAGER",
        mplusLoadout = {
            string = "C0EAy0kSampleExportStringFromSimC",
            source = "SimulationCraft default profile (credit, not endorsement of 'best')",
            patch = "12.1",
        },
    }
    local ok = GuideStore:RegisterSpec("MAGE", 9009, guide)
    check(ok == true, "RegisterSpec accepts a valid mplusLoadout")
    local roundTripped = GuideStore:GetGuide(9009)
    check(roundTripped ~= nil and roundTripped.mplusLoadout.string == "C0EAy0kSampleExportStringFromSimC",
        "round-tripped guide keeps its mplusLoadout.string",
        roundTripped and roundTripped.mplusLoadout and roundTripped.mplusLoadout.string)
    check(roundTripped.mplusLoadout.patch == "12.1", "round-tripped guide keeps its mplusLoadout.patch",
        roundTripped.mplusLoadout.patch)
end

-- A non-table mplusLoadout is rejected (guide skipped entirely), the same
-- validate-and-skip contract as a bad gear entry.
do
    local badGuide = { specName = "Bad Loadout Spec A", role = "DAMAGER", mplusLoadout = "not a table" }
    local ok, result = silently(function() return GuideStore:RegisterSpec("MAGE", 9011, badGuide) end)
    check(ok, "RegisterSpec with a non-table mplusLoadout does not error", result)
    check(result == false, "guide with a non-table mplusLoadout is rejected")
    check(GuideStore:GetGuide(9011) == nil, "guide with a non-table mplusLoadout is not stored")
end

-- A missing/empty `string` field is rejected.
do
    local badGuide = {
        specName = "Bad Loadout Spec B",
        role = "DAMAGER",
        mplusLoadout = { string = "", patch = "12.1" },
    }
    local ok, result = silently(function() return GuideStore:RegisterSpec("MAGE", 9012, badGuide) end)
    check(ok, "RegisterSpec with an empty mplusLoadout.string does not error", result)
    check(result == false, "guide with an empty mplusLoadout.string is rejected")
    check(GuideStore:GetGuide(9012) == nil, "guide with an empty mplusLoadout.string is not stored")
end

-- A missing/empty `patch` field is rejected.
do
    local badGuide = {
        specName = "Bad Loadout Spec C",
        role = "DAMAGER",
        mplusLoadout = { string = "C0EAy0k", patch = "" },
    }
    local ok, result = silently(function() return GuideStore:RegisterSpec("MAGE", 9013, badGuide) end)
    check(ok, "RegisterSpec with an empty mplusLoadout.patch does not error", result)
    check(result == false, "guide with an empty mplusLoadout.patch is rejected")
    check(GuideStore:GetGuide(9013) == nil, "guide with an empty mplusLoadout.patch is not stored")
end

-- raidLoadout (DESIGN.md's v1.3 section) is validated identically to
-- mplusLoadout - same shared validator, so these mirror the mplusLoadout
-- cases above rather than re-deriving the rules.
do
    local guide = { specName = "No Raid Loadout Spec", role = "DAMAGER" }
    local ok = GuideStore:RegisterSpec("MAGE", 9014, guide)
    check(ok == true, "RegisterSpec accepts a guide with no raidLoadout key at all")
    check(GuideStore:GetGuide(9014).raidLoadout == nil,
        "a guide with no raidLoadout key round-trips with raidLoadout still nil")
end

do
    local guide = {
        specName = "Raid Loadout Spec",
        role = "DAMAGER",
        mplusLoadout = { string = "MplusStringSideBySide", patch = "12.1" },
        raidLoadout = {
            string = "C0EAy0kSampleRaidExportStringFromSimC",
            source = "SimulationCraft default profile (credit, not endorsement of 'best')",
            patch = "12.1",
        },
    }
    local ok = GuideStore:RegisterSpec("MAGE", 9015, guide)
    check(ok == true, "RegisterSpec accepts a valid raidLoadout")
    local roundTripped = GuideStore:GetGuide(9015)
    check(roundTripped ~= nil and roundTripped.raidLoadout.string == "C0EAy0kSampleRaidExportStringFromSimC",
        "round-tripped guide keeps its raidLoadout.string",
        roundTripped and roundTripped.raidLoadout and roundTripped.raidLoadout.string)
    check(roundTripped.mplusLoadout.string == "MplusStringSideBySide",
        "a guide can carry both mplusLoadout and raidLoadout without either overwriting the other",
        roundTripped.mplusLoadout.string)
end

do
    local badGuide = { specName = "Bad Raid Loadout Spec A", role = "DAMAGER", raidLoadout = "not a table" }
    local ok, result = silently(function() return GuideStore:RegisterSpec("MAGE", 9016, badGuide) end)
    check(ok, "RegisterSpec with a non-table raidLoadout does not error", result)
    check(result == false, "guide with a non-table raidLoadout is rejected")
    check(GuideStore:GetGuide(9016) == nil, "guide with a non-table raidLoadout is not stored")
end

do
    local badGuide = {
        specName = "Bad Raid Loadout Spec B",
        role = "DAMAGER",
        raidLoadout = { string = "", patch = "12.1" },
    }
    local ok, result = silently(function() return GuideStore:RegisterSpec("MAGE", 9017, badGuide) end)
    check(ok, "RegisterSpec with an empty raidLoadout.string does not error", result)
    check(result == false, "guide with an empty raidLoadout.string is rejected")
    check(GuideStore:GetGuide(9017) == nil, "guide with an empty raidLoadout.string is not stored")
end

do
    local badGuide = {
        specName = "Bad Raid Loadout Spec C",
        role = "DAMAGER",
        raidLoadout = { string = "C0EAy0k", patch = "" },
    }
    local ok, result = silently(function() return GuideStore:RegisterSpec("MAGE", 9018, badGuide) end)
    check(ok, "RegisterSpec with an empty raidLoadout.patch does not error", result)
    check(result == false, "guide with an empty raidLoadout.patch is rejected")
    check(GuideStore:GetGuide(9018) == nil, "guide with an empty raidLoadout.patch is not stored")
end

-- mplusMetaLoadout (DESIGN.md's v1.4 section) shares the same validated
-- shape, plus an optional numeric `sampleSize` no other loadout kind
-- carries - an empirical top-players aggregate has a sample size, a single
-- curated SimC profile does not.
do
    local guide = { specName = "No Meta Loadout Spec", role = "DAMAGER" }
    local ok = GuideStore:RegisterSpec("MAGE", 9019, guide)
    check(ok == true, "RegisterSpec accepts a guide with no mplusMetaLoadout key at all")
    check(GuideStore:GetGuide(9019).mplusMetaLoadout == nil,
        "a guide with no mplusMetaLoadout key round-trips with mplusMetaLoadout still nil")
end

do
    local guide = {
        specName = "Meta Loadout Spec",
        role = "DAMAGER",
        mplusMetaLoadout = {
            string = "C0EAy0kSampleLiveMetaExportString",
            source = "Blizzard Battle.net API, aggregated from top current-season Mythic+ players",
            patch = "12.1",
            sampleSize = 50,
        },
    }
    local ok = GuideStore:RegisterSpec("MAGE", 9020, guide)
    check(ok == true, "RegisterSpec accepts a valid mplusMetaLoadout with a sampleSize")
    local roundTripped = GuideStore:GetGuide(9020)
    check(roundTripped.mplusMetaLoadout.string == "C0EAy0kSampleLiveMetaExportString",
        "round-tripped guide keeps its mplusMetaLoadout.string")
    check(roundTripped.mplusMetaLoadout.sampleSize == 50,
        "round-tripped guide keeps its mplusMetaLoadout.sampleSize", roundTripped.mplusMetaLoadout.sampleSize)
end

do
    -- sampleSize is optional - a guide can omit it and still validate, the
    -- same as mplusLoadout/raidLoadout never having had the field at all.
    local guide = {
        specName = "Meta Loadout No Sample Spec",
        role = "DAMAGER",
        mplusMetaLoadout = { string = "C0EAy0kNoSampleSize", patch = "12.1" },
    }
    local ok = GuideStore:RegisterSpec("MAGE", 9021, guide)
    check(ok == true, "RegisterSpec accepts a valid mplusMetaLoadout with no sampleSize")
    check(GuideStore:GetGuide(9021).mplusMetaLoadout.sampleSize == nil,
        "sampleSize stays nil when the guide never set one")
end

do
    local badGuide = {
        specName = "Bad Meta Loadout Spec A",
        role = "DAMAGER",
        mplusMetaLoadout = { string = "C0EAy0k", patch = "12.1", sampleSize = 0 },
    }
    local ok, result = silently(function() return GuideStore:RegisterSpec("MAGE", 9022, badGuide) end)
    check(ok, "RegisterSpec with sampleSize = 0 does not error", result)
    check(result == false, "a zero sampleSize is rejected")
    check(GuideStore:GetGuide(9022) == nil, "guide with a zero sampleSize is not stored")
end

do
    local badGuide = {
        specName = "Bad Meta Loadout Spec B",
        role = "DAMAGER",
        mplusMetaLoadout = { string = "C0EAy0k", patch = "12.1", sampleSize = "fifty" },
    }
    local ok, result = silently(function() return GuideStore:RegisterSpec("MAGE", 9023, badGuide) end)
    check(ok, "RegisterSpec with a non-number sampleSize does not error", result)
    check(result == false, "a string sampleSize is rejected")
    check(GuideStore:GetGuide(9023) == nil, "guide with a non-number sampleSize is not stored")
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
-- with valid stat keys and non-empty rotations. Also assert the exact
-- shipped spec count per class (a class silently missing a spec, or a guide
-- file that fails to load, used to slip through unnoticed since the old loop
-- only ever walked specs that *are* registered) and that every statPriority
-- entry actually resolves through Stats:GetStatValue.
do
    local EXPECTED_SPEC_COUNT = {
        WARRIOR = 3, PALADIN = 3, HUNTER = 3, ROGUE = 3, PRIEST = 3,
        DEATHKNIGHT = 3, SHAMAN = 3, MAGE = 3, WARLOCK = 3, MONK = 3,
        DRUID = 4, DEMONHUNTER = 3, EVOKER = 3,
    }

    local anyShipped = false
    local totalShipped = 0

    for _, classEntry in ipairs(GuideStore:GetClasses()) do
        local shippedForClass = 0

        for _, specID in ipairs(GuideStore:GetClassSpecs(classEntry.token)) do
            -- Skip the synthetic test specIDs registered above (9000+).
            if specID < 9000 then
                anyShipped = true
                shippedForClass = shippedForClass + 1
                totalShipped = totalShipped + 1

                local guide = GuideStore:GetGuide(specID)
                check(guide ~= nil, format("shipped guide exists for %s spec %d", classEntry.token, specID))
                if guide then
                    check(type(guide.specName) == "string" and guide.specName ~= "",
                        format("shipped guide for %s spec %d has a specName", classEntry.token, specID))
                    if guide.rotation ~= nil then
                        check(type(guide.rotation) == "table" and #guide.rotation > 0,
                            format("shipped guide for %s spec %d has a non-empty rotation", classEntry.token, specID))
                    end
                    if guide.statPriority then
                        for _, entry in ipairs(guide.statPriority) do
                            check(StatsModule:GetStatValue(entry.stat) ~= nil,
                                format("statPriority stat '%s' for %s spec %d resolves through Stats:GetStatValue",
                                    tostring(entry.stat), classEntry.token, specID))
                        end
                    end
                end
            end
        end

        check(shippedForClass == EXPECTED_SPEC_COUNT[classEntry.token],
            format("%s has exactly %d shipped spec(s)", classEntry.token, EXPECTED_SPEC_COUNT[classEntry.token]),
            shippedForClass)
    end

    check(anyShipped == true, "at least one shipped class guide is registered (Shaman)", anyShipped)
    check(totalShipped == 40, "exactly 40 shipped specs are registered across all classes", totalShipped)
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

-- Procs.lua asks AuraUtil.ForEachAura for "HELPFUL" only; a debuff on the
-- player must never show up as a proc. Previously unverifiable because the
-- mock's ForEachAura ignored the filter argument entirely.
mock.AddAura(999001, 10, 1, false)
mock.Fire("UNIT_AURA", "player")
check(findRow("procs", "Spell 999001") == nil, "a HARMFUL aura (debuff) is not shown by the HELPFUL-filtered proc list")

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
section("Procs: auras refused by the client")
--------------------------------------------------------------------------------

-- In Midnight's restricted content the aura APIs refuse addon access
-- outright rather than returning secrets: AuraUtil.ForEachAura throws from
-- inside GetAuraSlots, before our callback runs. On a 0.1s ticker that
-- produced 25k+ errors in a single session.
do
    local ProcsModule = ns:GetModule("Procs")
    local savedForEach = AuraUtil.ForEachAura
    local savedByID = C_UnitAuras.GetPlayerAuraBySpellID
    local savedWatch = ns.chardb.watch

    local attempts, blocking = 0, true
    AuraUtil.ForEachAura = function(unit, filter, _, callback)
        attempts = attempts + 1
        if blocking then
            error("GetAuraSlots(): Auras cannot be accessed when secret while tainted by 'SpecSage'")
        end
        callback({ spellId = 4321, name = "Recovered Proc", icon = 1, duration = 10,
            expirationTime = GetTime() + 5, applications = 1 })
    end
    C_UnitAuras.GetPlayerAuraBySpellID = function()
        error("Auras cannot be accessed when secret while tainted by 'SpecSage'")
    end

    ns.chardb.watch = {}
    ns.db.procs.enabled, ns.db.procs.autoDetect = true, true

    local escaped = 0
    for _ = 1, 200 do
        if not pcall(function() ProcsModule:Update() end) then escaped = escaped + 1 end
        mock.Advance(0.1)
    end

    check(escaped == 0, "a refusing aura API never lets an error escape Update", escaped)
    check(attempts < 20, "refusals back off instead of retrying every tick",
        format("%d attempts across 200 ticks", attempts))
    check(ProcsModule:AurasBlocked(), "the module reports auras as blocked")

    -- /sage scan must say why it is empty rather than claim there are no buffs.
    local scanned, blocked = ProcsModule:ScanAuras()
    check(#scanned == 0 and blocked, "ScanAuras reports the refusal instead of an empty buff list")

    -- A fully secret UNIT_AURA payload: even comparing the unit token errors.
    local secretUnit = setmetatable({}, {
        __eq = function() error("secret value") end,
        __index = function() error("secret value") end,
    })
    check(pcall(function() mock.Fire("UNIT_AURA", secretUnit) end),
        "a secret UNIT_AURA payload does not take the handler down")

    -- Leaving restricted content restores proc tracking on its own.
    blocking = false
    mock.Advance(10)
    ProcsModule:Update()
    check(not ProcsModule:AurasBlocked(), "proc tracking recovers once auras are readable again")
    check(findRow("procs", "Recovered Proc") ~= nil, "auto-detected procs come back after recovery")

    AuraUtil.ForEachAura = savedForEach
    C_UnitAuras.GetPlayerAuraBySpellID = savedByID
    ns.chardb.watch = savedWatch
    ProcsModule:Update()
end

--------------------------------------------------------------------------------
section("Stat tooltips: derived values")
--------------------------------------------------------------------------------

-- Blizzard's own character sheet explains what a stat is worth, not just its
-- rating ("Physical damage reduction: 56.62%"). These assert SpecSage's
-- tooltips carry the same derived numbers.
do
    local provider = ns.UI:GetSectionProvider("stats")
    check(provider ~= nil, "the stats section publishes a tooltip provider")

    local function lineValue(data, leftPattern)
        for _, line in ipairs((data and data.lines) or {}) do
            if line.left and line.left:find(leftPattern, 1, true) then return line.right end
        end
        return nil
    end

    local armor = provider("armor")
    check(armor ~= nil, "the armor tooltip resolves")
    -- The mock's effectiveness curve: 4500 / (4500 + 5000) = 0.47368...
    local reduction = lineValue(armor, "Physical damage reduction")
    check(reduction == "47.37%", "armor tooltip shows physical damage reduction", tostring(reduction))
    check(lineValue(armor, "evenly matched") ~= nil,
        "armor tooltip notes the reduction is against an evenly matched enemy")
    check(lineValue(armor, "Effective") ~= nil, "armor tooltip still shows effective armor")

    -- A client without the API must omit the line rather than guess with the
    -- obsolete formula.
    local savedPaperDoll = C_PaperDollInfo
    C_PaperDollInfo = nil
    local armorNoAPI = provider("armor")
    check(lineValue(armorNoAPI, "Physical damage reduction") == nil,
        "without GetArmorEffectiveness the reduction line is omitted, not guessed")
    check(lineValue(armorNoAPI, "Effective") ~= nil, "the rest of the armor tooltip survives")
    C_PaperDollInfo = savedPaperDoll

    -- Attack Speed, the other derived stat from the character sheet.
    ns.StatsShown().attackspeed = true
    ns.RefreshAll()
    local speedRow = findRow("stats", "Attack Speed")
    check(speedRow ~= nil, "Attack Speed renders a stat row")
    check(speedRow and speedRow.value == "1.99", "Attack Speed shows the main-hand swing time",
        speedRow and speedRow.value)

    local speedTip = provider("attackspeed")
    check(lineValue(speedTip, "Main hand") == "1.99 sec", "attack speed tooltip shows the main hand",
        tostring(lineValue(speedTip, "Main hand")))
    check(lineValue(speedTip, "Off hand") == "2.60 sec", "attack speed tooltip shows the off hand",
        tostring(lineValue(speedTip, "Off hand")))
    check(lineValue(speedTip, "Haste") ~= nil, "attack speed tooltip names haste as the driver")
    ns.StatsShown().attackspeed = false
    ns.RefreshAll()
end

--------------------------------------------------------------------------------
section("Stat tooltips: secret values")
--------------------------------------------------------------------------------

-- Reported bug: the physical damage reduction line vanished the moment a
-- buff changed the player's armor. Cause: armor becomes a secret value, and
-- the code compared the resulting effectiveness to decide whether the API
-- returns a ratio or a percentage. Comparing a secret errors, so the guard
-- returned nil and the line disappeared.
--
-- Midnight's rules, which this models: arithmetic and formatting propagate a
-- secret, comparing one errors.
local function SecretNumber(value)
    local secret
    secret = setmetatable({}, {
        __lt = function() error("attempt to compare a secret value") end,
        __le = function() error("attempt to compare a secret value") end,
        __eq = function() error("attempt to compare a secret value") end,
        __add = function(a, b) return SecretNumber(value + (type(a) == "number" and a or b)) end,
        -- Arithmetic yields another secret; the test resolves it to the real
        -- product so the formatted output can be asserted.
        __mul = function(a, b) return value * (type(a) == "number" and a or b) end,
    })
    return secret
end

do
    local provider = ns.UI:GetSectionProvider("stats")
    local savedArmor = UnitArmor
    local savedEffectiveness = C_PaperDollInfo.GetArmorEffectiveness

    -- Secretness flows from the input: the probe's literal 1000/80 stay
    -- plain, a real (buffed) armor value comes back secret.
    C_PaperDollInfo.GetArmorEffectiveness = function(armor, attackerLevel)
        assert(type(attackerLevel) == "number", "attacker level must stay readable")
        if armor == 1000 then return 0.1666 end
        return SecretNumber(0.5662)
    end
    UnitArmor = function()
        local secretArmor = SecretNumber(6620)
        return 3000, secretArmor, secretArmor, SecretNumber(1200), 0
    end

    local ok, data = pcall(provider, "armor")
    check(ok, "a secret armor value does not break the tooltip", not ok and tostring(data) or "")

    local reduction
    for _, line in ipairs((data and data.lines) or {}) do
        if line.left and line.left:find("Physical damage reduction", 1, true) then
            reduction = line.right
        end
    end
    check(reduction == "56.62%",
        "the reduction line survives a secret armor value (the reported bug)",
        tostring(reduction))

    UnitArmor = savedArmor
    C_PaperDollInfo.GetArmorEffectiveness = savedEffectiveness
end

do
    -- The same class of bug in the stat breakdowns: a secret buff amount
    -- must cost at most its own optional line, never the whole tooltip.
    local provider = ns.UI:GetSectionProvider("stats")
    local savedUnitStat = UnitStat
    UnitStat = function(_, index)
        return 1000, 1200, SecretNumber(200), SecretNumber(0)
    end

    local ok, data = pcall(provider, "primary")
    check(ok, "a secret buff amount does not break the primary tooltip")
    local hasBase = false
    for _, line in ipairs((data and data.lines) or {}) do
        if line.left == "Base" then hasBase = true end
    end
    check(hasBase, "the base line survives a secret buff amount")

    UnitStat = savedUnitStat
end

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

-- Core/Config.lua used to have a MigrateStatVisibility function that read
-- SpecSageDB.stats.show onto the character DB, but DEFAULTS.stats never
-- creates that key and this addon never writes it either (SpecSageDB is a
-- brand-new saved variable, not the predecessor addon's StatOverlayDB) - the
-- only thing that ever exercised the branch was this test writing to it by
-- hand. It was dead code (see REVIEW.md #13) and has been removed; confirm a
-- stray legacy-shaped key like this is simply left alone, not read into a
-- player's real per-character choices.
SpecSageDB.stats.show = { crit = false, armor = true, haste = false }
SpecSageCharDB = nil
ns.InitConfig()
check(ns.chardb.statsShow.crit == true, "a stray SpecSageDB.stats.show is not read into the character DB",
    ns.chardb.statsShow.crit)
check(ns.chardb.migratedStatVisibility == nil, "there is no migration flag - the migration path was removed")

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

-- Melee vs. spell crit rating selection (Stats.lua:261-268) actually picks a
-- different combat-rating index depending on primaryStat - previously
-- unverifiable because the mock's GetCombatRatingBonus ignored its index
-- argument and always returned the same number regardless of which rating
-- was asked for.
do
    local realPrimaryStat = mock.playerPrimaryStat
    mock.playerPrimaryStat = 4 -- Intellect
    critFrame.scripts.OnEnter(critFrame)
    local spellDump = dumpOf(hoverTip)
    mock.playerPrimaryStat = realPrimaryStat
    check(spellDump:find("From rating=6.25%%") ~= nil,
        "an Intellect-primary spec's crit tooltip uses the spell rating index, not melee", spellDump)
end
critFrame.scripts.OnEnter(critFrame) -- back to the mock's real (non-Intellect) primary stat

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

-- Curated data (loadouts, notes, bis) must all survive a full reset — the
-- same guarantee Core/Config.lua's ResetConfig already gives loadouts and
-- notes (DESIGN.md: "/sage reset all leaves SpecSageDB.bis alone").
ns.db.bis[9601] = { { slot = "Head", itemID = 123, name = "Reset Test Item" } }

run("reset all")
check(ns.db.scale == 1.0, "reset all restores defaults", ns.db.scale)
check(ns.db.bis[9601] ~= nil and ns.db.bis[9601][1].name == "Reset Test Item",
    "reset all leaves SpecSageDB.bis alone, like loadouts and notes")

-- /specsage is registered as an alias of /sage.
check(SLASH_SPECSAGE1 == "/sage", "SLASH_SPECSAGE1 is /sage")
check(SLASH_SPECSAGE2 == "/specsage", "SLASH_SPECSAGE2 is /specsage")

--------------------------------------------------------------------------------
section("Options panel")
--------------------------------------------------------------------------------

local options = ns:GetModule("Options")
check(options.category ~= nil, "settings category registered")
check(pcall(ns.OpenOptions), "opening options does not error")

-- Every stat in STAT_LIST must be reachable from the panel, or a stat can
-- only ever be toggled through /sage stat.
do
    local registeredVars = {}
    for _, variable in ipairs(mock.settingsRegistered or {}) do
        registeredVars[variable] = true
    end
    local missing = {}
    for _, entry in ipairs(ns.STAT_LIST) do
        if not registeredVars["SpecSage_stat_" .. entry.key] then
            missing[#missing + 1] = entry.key
        end
    end
    check(#missing == 0, "every STAT_LIST entry has an options checkbox"
        .. (#missing > 0 and (" (missing: " .. table.concat(missing, ", ") .. ")") or ""))
end

-- The panel used to be built by code that indexed
-- MinimalSliderWithSteppersMixin.Label.Right outside the pcall meant to
-- protect it, so a client without that global lost the entire panel (and
-- /sage config reported "options panel unavailable") after only the handful
-- of checkboxes that precede the first slider. Rebuilding without the global
-- must still produce a full panel.
do
    local savedMixin = MinimalSliderWithSteppersMixin
    MinimalSliderWithSteppersMixin = nil

    local before = #(mock.settingsRegistered or {})
    local ok = pcall(function() options:OnEnable() end)
    local after = #(mock.settingsRegistered or {})

    MinimalSliderWithSteppersMixin = savedMixin

    check(ok, "rebuilding the panel without MinimalSliderWithSteppersMixin does not error")
    check(options.category ~= nil, "the category survives a missing slider mixin")
    check(after - before >= #ns.STAT_LIST, "sliders do not abort the panel when the mixin is missing")
end

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
section("BiS module (Modules/BiS.lua)")
--------------------------------------------------------------------------------

local BiSModule = ns:GetModule("BiS")
check(BiSModule ~= nil, "BiS module registered at load time")

-- Uses a synthetic specID (9501), the same >=9000 convention the GuideStore/
-- Loadouts tests above use, so this cannot collide with a shipped spec.
check(#BiSModule:GetForSpec(9501) == 0, "GetForSpec returns an empty list for a spec with nothing saved")
check(ns.db.bis[9501] == nil, "reading an empty spec does not create clutter in the saved variables")

do
    local ok, err = BiSModule:Add(9501, "NotASlot", "12345")
    check(ok == false, "Add rejects an invalid slot", err)
end

do
    local ok, err = BiSModule:Add(9501, "Head", "")
    check(ok == false, "Add rejects an empty itemText", err)
end

do
    local ok, err = BiSModule:Add("not-a-number", "Head", "12345")
    check(ok == false, "Add rejects a non-number specID", err)
end

-- Form 1: a pasted item link — itemID and name both come straight out of
-- the link text, no GetItemInfo lookup needed.
do
    local link = "|cffa335ee|Hitem:19019:0:0:0:0:0:0:0:0:0|h[Thunderfury, Blessed Blade of the Windseeker]|h|r"
    local ok, entry = BiSModule:Add(9501, "Weapon", link)
    check(ok == true, "Add accepts a pasted item link", entry)
    check(entry.itemID == 19019, "item link parsing extracts the itemID", entry.itemID)
    check(entry.name == "Thunderfury, Blessed Blade of the Windseeker",
        "item link parsing extracts the display name", entry.name)
    check(entry.slot == "Weapon", "the entry keeps the slot it was added under", entry.slot)
end

-- Form 2: a bare numeric itemID — name resolved via the GetItemInfo fallback
-- chain (mock.items[42] is fixtured in tests/wow_mock.lua).
do
    local ok, entry = BiSModule:Add(9501, "Neck", "42")
    check(ok == true, "Add accepts a bare numeric itemID", entry)
    check(entry.itemID == 42, "numeric itemID is stored as a number", entry.itemID)
    check(entry.name == "Champion's Dreadful Gladiator's Pendant of Alacrity",
        "a cached itemID resolves its name immediately via GetItemInfo", entry.name)
end

-- A numeric itemID the item cache does not know about yet (async — the
-- server has not handed back a name) still gets listed, per DESIGN.md, with
-- a placeholder name rather than being rejected.
do
    local ok, entry = BiSModule:Add(9501, "Feet", "999999")
    check(ok == true, "Add accepts an itemID GetItemInfo cannot resolve yet", entry)
    check(entry.itemID == 999999, "the unresolved itemID is still stored", entry.itemID)
    check(type(entry.name) == "string" and entry.name ~= "", "an unresolved itemID still gets a placeholder name",
        entry.name)

    -- Once the item becomes "cached" (a test fixture appears), ResolveDisplay
    -- picks up the real name lazily, on render, per DESIGN.md.
    mock.items[999999] = { name = "Freshly Cached Trinket", quality = 4 }
    local resolvedName, quality = BiSModule:ResolveDisplay(entry)
    check(resolvedName == "Freshly Cached Trinket", "ResolveDisplay re-resolves a name that became available later",
        resolvedName)
    check(quality == 4, "ResolveDisplay also returns the item's quality", quality)
    check(entry.name == "Freshly Cached Trinket", "the resolved name is written back onto the entry", entry.name)
    mock.items[999999] = nil
end

-- Form 3: a plain name — no itemID at all, still listed.
do
    local ok, entry = BiSModule:Add(9501, "Trinket", "Some Trinket I Read About")
    check(ok == true, "Add accepts a plain name with no itemID", entry)
    check(entry.itemID == nil, "a plain-name entry has no itemID", entry.itemID)
    check(entry.name == "Some Trinket I Read About", "a plain-name entry keeps the typed name", entry.name)
end

local bisList = BiSModule:GetForSpec(9501)
check(#bisList == 4, "all four added entries round-trip through GetForSpec", #bisList)
check(ns.db.bis[9501] == bisList, "GetForSpec returns the live saved-variable table once one exists")

-- Per-spec isolation: a second spec's list is independent.
do
    local ok = BiSModule:Add(9502, "Head", "Different Spec's Item")
    check(ok == true, "Add works for a second, unrelated spec")
    check(#BiSModule:GetForSpec(9502) == 1, "the second spec has exactly its own entry")
    check(#BiSModule:GetForSpec(9501) == 4, "the first spec's list is untouched by the second spec's Add")
end

check(BiSModule:Delete(9501, 99) == false, "Delete rejects an out-of-range index")
check(BiSModule:Delete(9999, 1) == false, "Delete on a spec with nothing saved returns false rather than erroring")

do
    local ok = BiSModule:Delete(9501, 1)
    check(ok == true, "Delete removes the entry at the given index")
    local remaining = BiSModule:GetForSpec(9501)
    check(#remaining == 3, "the remaining entries shift into place", #remaining)
end

--------------------------------------------------------------------------------
section("BiS module: GetStatus")
--------------------------------------------------------------------------------

-- No itemID at all: GetStatus has nothing to check against, so it reports
-- neither equipped, owned, nor missing — just nil.
check(BiSModule:GetStatus({ slot = "Trinket", name = "No ID" }) == nil,
    "GetStatus returns nil for an entry with no itemID")
check(BiSModule:GetStatus("not a table") == nil, "GetStatus returns nil rather than erroring on a non-table")

mock.equipped = {}
mock.bags = {}

-- Equipped: a single-slot gear type (Head -> INVSLOT_HEAD).
do
    mock.equipped[INVSLOT_HEAD] = 55001
    local status = BiSModule:GetStatus({ slot = "Head", itemID = 55001 })
    check(status == "equipped", "a Head item in INVSLOT_HEAD reports equipped", status)
    mock.equipped[INVSLOT_HEAD] = nil
end

-- Equipped: Ring maps to two inventory slots (INVSLOT_FINGER1/2) — the item
-- sitting in the *second* ring slot must still be found.
do
    mock.equipped[INVSLOT_FINGER2] = 55002
    local status = BiSModule:GetStatus({ slot = "Ring", itemID = 55002 })
    check(status == "equipped", "a Ring item equipped in INVSLOT_FINGER2 still reports equipped", status)
    mock.equipped[INVSLOT_FINGER2] = nil
end

-- Owned: the item is in a bag, not equipped anywhere.
do
    mock.bags[0] = { [3] = 55003 }
    local status = BiSModule:GetStatus({ slot = "Trinket", itemID = 55003 })
    check(status == "owned", "an item sitting in a bag reports owned", status)
    mock.bags[0] = nil
end

-- Missing: neither equipped nor in any bag.
do
    local status = BiSModule:GetStatus({ slot = "Legs", itemID = 55004 })
    check(status == "missing", "an item that is neither equipped nor in bags reports missing", status)
end

-- Weapon fans out to BOTH the main-hand and off-hand inventory slots (High
-- finding #1: it used to check INVSLOT_MAINHAND only, so a dual-wield
-- entry's second weapon permanently reported "missing" while visibly
-- equipped). Off-hand still maps to INVSLOT_OFFHAND alone.
do
    mock.equipped[INVSLOT_MAINHAND] = 55005
    local status = BiSModule:GetStatus({ slot = "Weapon", itemID = 55005 })
    check(status == "equipped", "a Weapon item equipped in INVSLOT_MAINHAND reports equipped", status)
    mock.equipped[INVSLOT_MAINHAND] = nil
end

do
    mock.equipped[INVSLOT_OFFHAND] = 55006
    local status = BiSModule:GetStatus({ slot = "Weapon", itemID = 55006 })
    check(status == "equipped",
        "a Weapon item equipped in INVSLOT_OFFHAND (the second of two dual-wield weapons) reports equipped", status)
    mock.equipped[INVSLOT_OFFHAND] = nil
end

do
    mock.equipped[INVSLOT_OFFHAND] = 55007
    local status = BiSModule:GetStatus({ slot = "Off-hand", itemID = 55007 })
    check(status == "equipped", "an Off-hand item in INVSLOT_OFFHAND reports equipped", status)
    mock.equipped[INVSLOT_OFFHAND] = nil
end

mock.equipped = {}
mock.bags = {}

--------------------------------------------------------------------------------
section("BiS module: GetStatus covers every slot's real inventory ID (Medium #1/#3)")
--------------------------------------------------------------------------------

-- Every BiS.SLOT_ORDER slot, checked against Blizzard's real INVSLOT_*
-- constants (defined independently in tests/wow_mock.lua, not copied from
-- Modules/BiS.lua). Multi-slot gear types list every inventory slot that
-- should satisfy them. This is the comprehensive version of the three-entry
-- coverage the round-2 review flagged (Head/Ring/Off-hand only): a wrong
-- numeric literal or a wrong INVSLOT_* name anywhere in
-- Modules/BiS.lua's SLOT_INVENTORY_IDS fails one of these checks instead of
-- silently agreeing with a test that used the same wrong literal.
local SLOT_INVSLOT_EXPECTATIONS = {
    { slot = "Head", invSlots = { INVSLOT_HEAD } },
    { slot = "Neck", invSlots = { INVSLOT_NECK } },
    { slot = "Shoulder", invSlots = { INVSLOT_SHOULDER } },
    { slot = "Back", invSlots = { INVSLOT_BACK } },
    { slot = "Chest", invSlots = { INVSLOT_CHEST } },
    { slot = "Wrist", invSlots = { INVSLOT_WRIST } },
    { slot = "Hands", invSlots = { INVSLOT_HAND } },
    { slot = "Waist", invSlots = { INVSLOT_WAIST } },
    { slot = "Legs", invSlots = { INVSLOT_LEGS } },
    { slot = "Feet", invSlots = { INVSLOT_FEET } },
    { slot = "Ring", invSlots = { INVSLOT_FINGER1, INVSLOT_FINGER2 } },
    { slot = "Trinket", invSlots = { INVSLOT_TRINKET1, INVSLOT_TRINKET2 } },
    { slot = "Weapon", invSlots = { INVSLOT_MAINHAND, INVSLOT_OFFHAND } },
    { slot = "Off-hand", invSlots = { INVSLOT_OFFHAND } },
}

check(#SLOT_INVSLOT_EXPECTATIONS == #BiSModule.SLOT_ORDER,
    "the coverage table above lists every slot in BiS.SLOT_ORDER, not a subset",
    #SLOT_INVSLOT_EXPECTATIONS .. " vs " .. #BiSModule.SLOT_ORDER)

for _, expectation in ipairs(SLOT_INVSLOT_EXPECTATIONS) do
    for _, invSlot in ipairs(expectation.invSlots) do
        mock.equipped = {}
        local itemID = 60000 + invSlot
        mock.equipped[invSlot] = itemID
        local status = BiSModule:GetStatus({ slot = expectation.slot, itemID = itemID })
        check(status == "equipped",
            format("%s reports equipped when its item sits in inventory slot %d", expectation.slot, invSlot),
            status)
    end
end

mock.equipped = {}
mock.bags = {}

--------------------------------------------------------------------------------
section("BiS module: GetStatus with a precomputed bag set (Medium #6, perf cache)")
--------------------------------------------------------------------------------

-- Codex:RenderBiS now builds one bagSet per render (BiS:ScanBags()) and
-- passes it into GetStatus instead of letting GetStatus rescan bags itself
-- on every row. GetStatus's own contract when a bagSet is supplied:
do
    local bagSet = { [77001] = true }
    local status = BiSModule:GetStatus({ slot = "Trinket", itemID = 77001 }, bagSet)
    check(status == "owned", "GetStatus reports owned from a precomputed bag set", status)
end

do
    local bagSet = {}
    local status = BiSModule:GetStatus({ slot = "Trinket", itemID = 77002 }, bagSet)
    check(status == "missing", "GetStatus reports missing when the item is absent from a precomputed bag set",
        status)
end

do
    -- Equipped still wins even when a bagSet is supplied.
    mock.equipped[INVSLOT_HEAD] = 77003
    local bagSet = {}
    local status = BiSModule:GetStatus({ slot = "Head", itemID = 77003 }, bagSet)
    check(status == "equipped", "equipped still takes priority over a precomputed bag set", status)
    mock.equipped[INVSLOT_HEAD] = nil
end

do
    mock.bags[0] = { [1] = 77004 }
    local bagSet = BiSModule:ScanBags()
    check(bagSet[77004] == true, "ScanBags finds an item sitting in bag 0", bagSet[77004])
    mock.bags[0] = nil
end

do
    -- No bagSet at all: GetStatus falls back to scanning bags itself, same
    -- as before this fix - callers that do not build a bagSet still work.
    mock.bags[1] = { [2] = 77005 }
    local status = BiSModule:GetStatus({ slot = "Neck", itemID = 77005 })
    check(status == "owned", "GetStatus without a bagSet argument still falls back to scanning bags itself", status)
    mock.bags[1] = nil
end

mock.equipped = {}
mock.bags = {}

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

-- The very first Toggle() must render visible content with no explicit
-- SelectTab call: Codex.activeTab used to start out nil (only ever set
-- inside SelectTab), so RenderActiveTab's "if tab == ..." chain matched
-- nothing and the Codex opened completely blank until the player happened
-- to click a tab.
do
    local function CountShown(pool)
        local n = 0
        for _, row in ipairs(pool) do
            if row:IsShown() then n = n + 1 end
        end
        return n
    end
    check(Codex.activeTab == "Overview", "the Codex defaults to the Overview tab", Codex.activeTab)
    check(CountShown(Codex.pools.overview) > 0,
        "the first Toggle() renders visible Overview content rows without an explicit SelectTab")
end

Codex:Toggle()
check(Codex:IsShown() == false, "a second Toggle hides the frame")
Codex:Toggle()
check(Codex:IsShown() == true, "a third Toggle shows it again, keeping the prior selection")

-- Open() selects an explicit class/spec regardless of what was open before.
Codex:Open("WARRIOR", 72)
check(Codex.selectedClass == "WARRIOR", "Open selects the requested class")
check(Codex.selectedSpecID == 72, "Open selects the requested spec")
check(Codex:IsShown() == true, "Open leaves the frame shown")

local TAB_NAMES = { "Overview", "Stats", "Rotation", "Cooldowns", "Consumables", "BiS", "Loadouts", "Notes" }

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

-- Under the stricter mock, Button:SetText only works when the button was
-- created with a text-capable template (see tests/wow_mock.lua); a bare
-- CreateFrame("Button", ...) - the pre-fix state of every button below -
-- would raise an assertion the moment it tried to set its label, failing
-- this run outright rather than passing while rendering nothing in game.
for _, tabName in ipairs(TAB_NAMES) do
    check(Codex.tabButtons[tabName]:GetText() == tabName,
        "tab strip button '" .. tabName .. "' has a text-capable template and shows its label")
end

--------------------------------------------------------------------------------
section("BiS item bonus IDs (v1.6)")
--------------------------------------------------------------------------------

-- A bare itemID resolves to the item's *base* form. On current-season gear
-- that is a different item from the one the guide means - the reported case
-- was Protection Paladin's Mythic+ neck, item 273781, which the BiS tab
-- showed as a level-48 rare with +8 Stamina rather than the item level 334
-- epic on Icy Veins' page. The bonus-ID list is what separates them, so it
-- ships alongside the item ID and the Codex builds a full item string.
do
    local rows, withBonus, badBonus = 0, 0, {}
    for _, classEntry in ipairs(ns.GuideStore:GetClasses()) do
        for _, specID in ipairs(ns.GuideStore:GetClassSpecs(classEntry.token)) do
            if specID < 9000 then
                for _, listEntry in ipairs(ns.GuideStore:GetBiS(specID).lists) do
                    for _, row in ipairs(listEntry.list) do
                        rows = rows + 1
                        if row.bonus then
                            withBonus = withBonus + 1
                            if not row.bonus:match("^%d+[%d:]*$") then
                                badBonus[#badBonus + 1] = tostring(row.itemID)
                            end
                        end
                    end
                end
            end
        end
    end
    check(#badBonus == 0, "every bonus list is colon-separated numbers only", table.concat(badBonus, ","))
    check(withBonus > rows * 0.95, "nearly every BiS row carries its bonus list",
        format("%d of %d", withBonus, rows))

    -- The exact row from the bug report.
    local neck
    for _, listEntry in ipairs(ns.GuideStore:GetBiS(66).lists) do
        if listEntry.title == "Icy Veins Mythic+" then
            for _, row in ipairs(listEntry.list) do
                if row.slot == "Neck" then neck = row end
            end
        end
    end
    check(neck ~= nil and neck.itemID == 273781, "Protection Paladin's Mythic+ neck is item 273781",
        neck and neck.itemID)
    check(neck ~= nil and neck.bonus ~= nil and neck.bonus ~= "",
        "and it now carries the bonus list Icy Veins links it with", neck and neck.bonus)

    -- A malformed bonus list is rejected rather than reaching the client.
    local base = { lists = { { title = "T", list = {
        { slot = "Neck", itemID = 1, name = "N", bonus = "4786:12854" } } } } }
    check(ns.GuideStore:RegisterBiS(999902, base) == true, "a well-formed bonus list registers")
    base.lists[1].list[1].bonus = ":12854"
    check(ns.GuideStore:RegisterBiS(999903, base) == false, "a bonus list with an empty element is rejected")
    base.lists[1].list[1].bonus = 4786
    check(ns.GuideStore:RegisterBiS(999903, base) == false, "a non-string bonus list is rejected")
    base.lists[1].list[1].bonus = nil
    check(ns.GuideStore:RegisterBiS(999903, base) == true, "a row with no bonus list still registers")
end

--------------------------------------------------------------------------------
section("Codex: BiS rows resolve the upgraded item, not its base form (v1.6)")
--------------------------------------------------------------------------------

do
    -- The fixture models the real difference: item 880101 on its own is a
    -- low-level rare, and only the bonus list gives the epic the guide meant.
    mock.items[880101] = {
        name = "Base Form Neck", quality = 3, level = 48,
        bonus = { ["4786:12854"] = { name = "Upgraded Neck", quality = 4, level = 334 } },
    }
    ns.GuideStore:RegisterBiS(9604, { source = "test source", patch = "12.1", lists = { {
        title = "Test", list = {
            { slot = "Neck", itemID = 880101, name = "Shipped Name", from = "Somewhere",
              bonus = "4786:12854" },
            { slot = "Ring", itemID = 880101, name = "Shipped Name", from = "Somewhere" },
        },
    } } })
    Codex.bisListIndex = 1
    Codex:Open("MAGE", 9604)
    Codex:SelectTab("BiS")

    local linked = Codex.bisLinkRowPool[1]
    check(linked ~= nil and linked.text:GetText():find("Upgraded Neck", 1, true) ~= nil,
        "a row with a bonus list shows the upgraded item's name", linked and linked.text:GetText())
    check(linked ~= nil and linked.itemLink == "item:880101:0:0:0:0:0:0:0:0:0:0:0:2:4786:12854",
        "the row carries the full item string, bonus count and all", linked and linked.itemLink)

    local bare = Codex.bisLinkRowPool[2]
    check(bare ~= nil and bare.text:GetText():find("Base Form Neck", 1, true) ~= nil,
        "a row with no bonus list still resolves the bare item", bare and bare.text:GetText())
    check(bare ~= nil and bare.itemLink == nil, "and carries no item string of its own", bare and bare.itemLink)

    -- Hovering must go through SetHyperlink for the bonus row: SetItemByID
    -- takes a numeric ID and would show the base item instead.
    linked:GetScript("OnEnter")(linked)
    check(GameTooltip.itemID == "item:880101:0:0:0:0:0:0:0:0:0:0:0:2:4786:12854",
        "hovering a bonus row opens the tooltip on the full item string", GameTooltip.itemID)
    check(table.concat(GameTooltip:Dump(), "\n"):find("Upgraded Neck", 1, true) ~= nil,
        "so the hover tooltip shows the upgraded item")
    linked:GetScript("OnLeave")(linked)

    GameTooltip:SetOwner(nil, "ANCHOR_NONE")
    bare:GetScript("OnEnter")(bare)
    check(GameTooltip.itemID == 880101, "hovering a bare row still uses the numeric itemID", GameTooltip.itemID)
    bare:GetScript("OnLeave")(bare)

    -- Clicking inserts the bonus-carrying link, so a shift-click into chat
    -- links the item the guide meant.
    mock.itemRefClicks = {}
    linked:GetScript("OnMouseUp")(linked, "LeftButton")
    check(#mock.itemRefClicks == 1 and mock.itemRefClicks[1].link:find("4786:12854", 1, true) ~= nil,
        "clicking a bonus row opens the upgraded item's link",
        mock.itemRefClicks[1] and mock.itemRefClicks[1].link)

    mock.items[880101] = nil
end

--------------------------------------------------------------------------------
section("Stat priority: Wowhead per-hero-tree lists (v1.6)")
--------------------------------------------------------------------------------

-- Data/StatPriority.lua registers one table per spec, one list per hero
-- talent tree (or, where Wowhead splits on something else, one per split
-- with both hero trees named in the title). Every spec the guide files
-- register must have one, and every list must use the same statPriority
-- vocabulary Data/API.lua validates the guides' own flat list against.
do
    local VALID = {
        primary = true, crit = true, haste = true, mastery = true, versatility = true,
        leech = true, avoidance = true, speed = true, armor = true, stamina = true,
    }
    -- Earlier sections register throwaway specs of their own (9xxx); only
    -- the 40 real ones ship stat data.
    local function IsShippedSpec(specID) return specID < 9000 end
    local specCount, missing, badStat, tooFewLists = 0, {}, {}, {}
    for _, classEntry in ipairs(ns.GuideStore:GetClasses()) do
        for _, specID in ipairs(ns.GuideStore:GetClassSpecs(classEntry.token) or {}) do
          if IsShippedSpec(specID) then
            specCount = specCount + 1
            local data = ns.GuideStore:GetStatPriority(specID)
            if not data then
                missing[#missing + 1] = specID
            else
                if #data.lists < 2 then tooFewLists[#tooFewLists + 1] = specID end
                for _, listEntry in ipairs(data.lists) do
                    for _, entry in ipairs(listEntry.list) do
                        if not VALID[entry.stat] then
                            badStat[#badStat + 1] = specID .. ":" .. tostring(entry.stat)
                        end
                    end
                end
            end
          end
        end
    end
    check(specCount == 40, "all 40 specs are registered", specCount)
    check(#missing == 0, "every spec has a Wowhead stat priority registered", table.concat(missing, ","))
    check(#tooFewLists == 0, "every spec carries a list per hero talent tree, not just one",
        table.concat(tooFewLists, ","))
    check(#badStat == 0, "every stat key is in the Data/API.lua vocabulary", table.concat(badStat, ","))

    -- Arcane (62) is the worked example in DESIGN.md: Wowhead's two hero
    -- trees genuinely disagree below Haste, so the two lists must differ.
    local arcane = ns.GuideStore:GetStatPriority(62)
    check(arcane and arcane.lists[1].title == "Spellslinger" and arcane.lists[2].title == "Sunfury",
        "Arcane's lists are titled after its two hero talent trees")
    check(arcane and arcane.lists[1].list[3].stat == "mastery" and arcane.lists[2].list[3].stat == "versatility",
        "Spellslinger and Sunfury diverge below Haste, as Wowhead has them")
    check(arcane and arcane.source and arcane.source:find("Wowhead", 1, true) ~= nil,
        "the table carries a Wowhead attribution line the Codex can show", arcane and arcane.source)
    check(arcane and arcane.url and arcane.url:find("wowhead.com", 1, true) ~= nil,
        "the table records the page it was read from", arcane and arcane.url)

    -- The guide's own flat statPriority - the one Modules/ItemRanks.lua
    -- ranks items against - must agree with the first Wowhead list rather
    -- than drifting away from it.
    local mismatched = {}
    for _, classEntry in ipairs(ns.GuideStore:GetClasses()) do
        for _, specID in ipairs(ns.GuideStore:GetClassSpecs(classEntry.token) or {}) do
            local guide = IsShippedSpec(specID) and ns.GuideStore:GetGuide(specID) or nil
            local data = ns.GuideStore:GetStatPriority(specID)
            local flat, first = guide and guide.statPriority, data and data.lists[1].list
            if flat and first then
                if #flat ~= #first then
                    mismatched[#mismatched + 1] = tostring(specID)
                else
                    for i = 1, #flat do
                        if flat[i].stat ~= first[i].stat then
                            mismatched[#mismatched + 1] = tostring(specID)
                            break
                        end
                    end
                end
            end
        end
    end
    check(#mismatched == 0, "each guide's flat statPriority matches its first Wowhead list",
        table.concat(mismatched, ","))

    -- A bad registration is rejected with a printed reason, not stored.
    check(ns.GuideStore:RegisterStatPriority(999901, { lists = {} }) == false,
        "an empty lists array is rejected")
    check(ns.GuideStore:RegisterStatPriority(999901,
        { lists = { { title = "X", list = { { stat = "nonsense" } } } } }) == false,
        "an invalid stat key is rejected")
    check(ns.GuideStore:RegisterStatPriority(999901,
        { lists = { { list = { { stat = "haste" } } } } }) == false, "a list with no title is rejected")
    check(ns.GuideStore:GetStatPriority(999901) == nil, "nothing rejected is left registered")
    check(ns.GuideStore:RegisterStatPriority(999901,
        { source = "test", lists = { { title = "X", note = "n", list = { { stat = "haste" } } } } }) == true,
        "a well-formed table registers")
    check(ns.GuideStore:GetStatPriority(999901) ~= nil, "and can be read back")
end

--------------------------------------------------------------------------------
section("Codex: Stats tab renders the per-hero-tree lists (v1.6)")
--------------------------------------------------------------------------------

do
    local function ShownText(pool)
        local out = {}
        for _, row in ipairs(pool) do
            if row:IsShown() and row.text then out[#out + 1] = row.text:GetText() or "" end
        end
        return table.concat(out, "\n")
    end

    Codex:Open("MAGE", 62)
    Codex:SelectTab("Stats")
    local dump = ShownText(Codex.statLinePool)
    check(dump:find("By Hero Talent Tree", 1, true) ~= nil, "the Stats tab has a hero-tree section", dump)
    check(dump:find("Spellslinger: Primary Stat > Haste > Mastery > Crit > Versatility", 1, true) ~= nil,
        "Spellslinger's order is spelled out in the Codex's own stat words", dump)
    check(dump:find("Sunfury: Primary Stat > Haste > Versatility > Crit > Mastery", 1, true) ~= nil,
        "Sunfury's order is listed separately", dump)
    check(dump:find("Wowhead Arcane Mage stat priority guide", 1, true) ~= nil,
        "the section is attributed to the Wowhead page it came from", dump)

    -- A list's note (Wowhead's own caveat - a haste cap, a tie between two
    -- stats) renders under it rather than being dropped.
    Codex:Open("DEMONHUNTER", 1480)
    Codex:SelectTab("Stats")
    dump = ShownText(Codex.statLinePool)
    check(dump:find("Void-Scarred:", 1, true) ~= nil, "Devourer lists its Void-Scarred order", dump)
    check(dump:find("800 rating", 1, true) ~= nil, "Wowhead's haste-cap caveat rides along as a note", dump)

    -- Leaving the tab hides the rows, the same contract every other tab's
    -- own row pool has (HideOtherTabWidgets).
    Codex:SelectTab("Rotation")
    local shown = 0
    for _, row in ipairs(Codex.statLinePool) do
        if row:IsShown() then shown = shown + 1 end
    end
    check(shown == 0, "leaving the Stats tab hides the hero-tree rows", shown)

    -- A spec with no stat priority registered still renders the tab.
    Codex:Open("WARRIOR", 424242)
    check(pcall(function() Codex:SelectTab("Stats") end), "the Stats tab renders for a spec with no stat data")
end

--------------------------------------------------------------------------------
section("Codex: BiS tab")
--------------------------------------------------------------------------------

-- CONTENT_WIDTH's documented invariant: the scroll area is the frame minus
-- 310px of chrome (both rails, their gaps, and the scrollbar). Asserted as a
-- relationship rather than a second magic number, so widening the frame for
-- another tab cannot leave the content area behind.
check(Codex.scrollChild:GetWidth() == Codex.frame:GetWidth() - 310,
    "CONTENT_WIDTH stays FRAME_WIDTH minus 310px of chrome",
    format("frame=%d content=%d", Codex.frame:GetWidth(), Codex.scrollChild:GetWidth()))

do
    -- The bug this guards: DESIGN.md's original +60 sizing left the tab
    -- strip narrower than the tabs at the existing 84/86 width/stride
    -- actually need, so the last tab rendered past the frame's own right
    -- edge. Derived from the live tab count rather than a hardcoded 8, so
    -- adding a tab without widening the frame fails here instead of
    -- silently clipping in the client.
    local tabCount = 0
    for _ in pairs(Codex.tabButtons) do tabCount = tabCount + 1 end

    local needed = (tabCount - 1) * 86 + 84
    local specRailRight = 120 + 4 + 150
    local stripLeft = specRailRight + 8
    local stripRight = Codex.frame:GetWidth() - 8
    local available = stripRight - stripLeft
    check(available >= needed,
        format("tab strip has enough width for all %d tabs without clipping", tabCount),
        format("available=%d needed=%d", available, needed))
end

local BiSCodexModule = ns:GetModule("BiS")

local function CountShownRows(pool)
    local n = 0
    for _, row in ipairs(pool) do
        if row:IsShown() then n = n + 1 end
    end
    return n
end

-- MAGE spec 9005 was registered in the GuideStore section above with a
-- 4-entry gear array. That prose is no longer drawn on the BiS tab - it ran
-- to a screenful before the first item - so the tab opens straight on the
-- linked lists: the Trinket Tier List header + its "no data" reason line
-- (9005 registers no trinkets). The personal checklist that used to follow
-- was pulled on 2026-09-03 at the owner's request.
Codex:Open("MAGE", 9005)
Codex:SelectTab("BiS")
check(Codex.activeTab == "BiS", "SelectTab switches to the BiS tab")
check(CountShownRows(Codex.pools.bis) == 2,
    "the BiS tab draws no gear prose and no checklist, only the trinket header and its reason",
    CountShownRows(Codex.pools.bis))
check(Codex.bisRowPool == nil and Codex.bisItemBox == nil and Codex.bisButtons == nil,
    "no checklist rows, Add box or Add row are built")
for _, row in ipairs(Codex.pools.bis) do
    check(not (row:IsShown() and (row.text:GetText() or ""):find("^Head:")),
        "no per-slot prose row is drawn", row.text:GetText())
end

Codex:Open("MAGE", 9004)
Codex:SelectTab("BiS")

--------------------------------------------------------------------------------
section("Codex: leaving a tab clears its edit box focus")
--------------------------------------------------------------------------------

-- HideOtherTabWidgets clears focus before hiding self.notesBox: a focused
-- EditBox hidden without releasing keyboard focus is the classic "my
-- keybinds stopped working" report.
Codex:Open("WARRIOR", 72)
Codex:SelectTab("Notes")Codex:SelectTab("Notes")
Codex.notesBox:SetFocus()
check(Codex.notesBox.focused == true, "sanity: the notes box can be focused while its tab is active")
Codex:SelectTab("BiS")
check(Codex.notesBox.focused == false, "switching away from Notes clears its focus too")

-- All 8 tabs (BiS included) still render for both a spec with data and a
-- spec without, and the widened tab strip still builds without error.
Codex:Open("WARRIOR", 424242)
for _, tabName in ipairs(TAB_NAMES) do
    local ok, err = pcall(function() Codex:SelectTab(tabName) end)
    check(ok, "tab " .. tabName .. " still renders without error now that BiS has been added", err)
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

check(Codex.loadoutButtons.save:GetText() == "Save current", "the Save current button has a text-capable template")
check(Codex.loadoutButtons.add:GetText() == "Add from string", "the Add from string button has a text-capable template")
check(savedRow.copyButton:GetText() == "Copy", "the loadout row's Copy button has a text-capable template")
check(savedRow.deleteButton:GetText() == "Delete", "the loadout row's Delete button has a text-capable template")

-- The Copy dialog must be shown before its EditBox is focused/highlighted:
-- EditBox:SetFocus() is a no-op on a hidden widget in the real client (the
-- stricter mock now enforces this - see tests/wow_mock.lua's
-- IsEffectivelyShown - so getting the order wrong here would error instead
-- of silently copying nothing).
local copyOk = pcall(function() savedRow.copyButton:GetScript("OnClick")() end)
check(copyOk, "Copy does not error under the mock's visibility-checked SetFocus (dialog is shown before focusing)")
check(Codex.copyDialog:IsShown(), "Copy opens a dialog")
check(Codex.copyBox:GetText() == "TestImportString123", "the Copy dialog is populated with the loadout's export string")
check(Codex.copyBox.focused == true, "the copy box is focused once the dialog is shown")
check(Codex.copyBox.highlighted == true, "the copy box's text is highlighted (selected) once focused, ready for Ctrl+C")

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
section("Codex: Suggested Mythic+, Raid, and live-meta loadout rows (v1.2 / v1.3 / v1.4)")
--------------------------------------------------------------------------------

-- Inline fixture guides on scratch specIDs (the >=9000 convention used
-- throughout this suite), registered here rather than relying on any real
-- shipped Guides_*.lua content - two other agents are concurrently adding
-- mplusLoadout/raidLoadout/mplusMetaLoadout data to those files, so this
-- section must not race with them.
GuideStore:RegisterSpec("WARRIOR", 9201, {
    specName = "Loadout Warrior",
    role = "DAMAGER",
    mplusLoadout = {
        string = "C0EAy0kSampleExportStringFromSimC",
        source = "SimulationCraft default profile (credit, not endorsement of 'best')",
        patch = "12.1",
    },
    raidLoadout = {
        string = "C0EAy0kSampleRaidExportStringFromSimC",
        source = "SimulationCraft default profile (credit, not endorsement of 'best')",
        patch = "12.1",
    },
    mplusMetaLoadout = {
        string = "C0EAy0kSampleLiveMetaExportString",
        source = "Blizzard Battle.net API, aggregated from top current-season Mythic+ players",
        patch = "12.1",
        sampleSize = 50,
    },
})
GuideStore:RegisterSpec("WARRIOR", 9203, {
    specName = "Mplus Only Warrior",
    role = "DAMAGER",
    mplusLoadout = {
        string = "C0EAy0kMplusOnlyString",
        source = "SimulationCraft default profile (credit, not endorsement of 'best')",
        patch = "12.1",
    },
})
GuideStore:RegisterSpec("WARRIOR", 9202, { specName = "No Loadout Warrior", role = "DAMAGER" })

-- All three present: three rows render above the saved-loadout list, in
-- SUGGESTED_LOADOUT_KINDS order (Mythic+, then Raid, then the live-meta
-- one), each independently labeled with its own real source - not one
-- hardcoded "via SimulationCraft" phrase across all three, which is exactly
-- what an earlier version of this rendering did (it would have mislabeled
-- the Blizzard-API-sourced row as SimC's) - and none of the three rows'
-- content bleeds into another's.
Codex:Open("WARRIOR", 9201)
Codex:SelectTab("Loadouts")
local mplusRow = Codex.suggestedLoadoutRows.mplus
local raidRow = Codex.suggestedLoadoutRows.raid
local metaRow = Codex.suggestedLoadoutRows.mplusMeta

check(mplusRow:IsShown(), "the Mythic+ row is shown for a spec whose guide ships mplusLoadout")
check(mplusRow.name:GetText() == "Suggested Mythic+ (via SimulationCraft, patch 12.1)",
    "the Mythic+ row is labeled per DESIGN.md, including the guide's patch", mplusRow.name:GetText())
check(mplusRow.copyButton:IsShown(), "the Mythic+ row's Copy button is shown")
check(mplusRow.addButton:IsShown(), "the Mythic+ row's Add to my vault button is shown")
check(mplusRow.addButton:GetText() == "Add to my vault",
    "the Mythic+ row's Add button is labeled 'Add to my vault'", mplusRow.addButton:GetText())

check(raidRow:IsShown(), "the Raid row is shown for a spec whose guide ships raidLoadout")
check(raidRow.name:GetText() == "Suggested Raid (via SimulationCraft, patch 12.1)",
    "the Raid row is labeled per DESIGN.md, including the guide's patch", raidRow.name:GetText())
check(raidRow.copyButton:IsShown(), "the Raid row's Copy button is shown")
check(raidRow.addButton:IsShown(), "the Raid row's Add to my vault button is shown")

check(metaRow:IsShown(), "the live-meta row is shown for a spec whose guide ships mplusMetaLoadout")
check(metaRow.name:GetText() == "Top Players' Mythic+ Build (via Blizzard's API, top 50, patch 12.1)",
    "the live-meta row is attributed to Blizzard's API (not SimC) and shows its sample size",
    metaRow.name:GetText())
check(metaRow.copyButton:IsShown(), "the live-meta row's Copy button is shown")
check(metaRow.addButton:IsShown(), "the live-meta row's Add to my vault button is shown")

-- The mock's GetPoint() is a fixed stub (it does not track real SetPoint
-- calls), so ordering is checked against the recorded .points table instead
-- - row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y) after a ClearAllPoints
-- leaves exactly one recorded point, whose 5th element is the y offset.
-- Higher on screen means a less negative y (SetPoint uses UIParent's
-- bottom-up coordinate space).
local mplusTop = mplusRow.points[#mplusRow.points][5]
local raidTop = raidRow.points[#raidRow.points][5]
local metaTop = metaRow.points[#metaRow.points][5]
check(type(mplusTop) == "number" and type(raidTop) == "number" and mplusTop > raidTop,
    "the Mythic+ row sits above the Raid row", format("mplus y=%s raid y=%s", tostring(mplusTop), tostring(raidTop)))
check(type(metaTop) == "number" and raidTop > metaTop,
    "the Raid row sits above the live-meta row", format("raid y=%s meta y=%s", tostring(raidTop), tostring(metaTop)))

-- Only one kind present: that row shows, the others stay hidden, and no gap
-- is left where a missing one would have gone.
Codex:Open("WARRIOR", 9203)
Codex:SelectTab("Loadouts")
check(Codex.suggestedLoadoutRows.mplus:IsShown(), "the Mythic+ row shows on a spec with only mplusLoadout")
check(not Codex.suggestedLoadoutRows.raid:IsShown(), "the Raid row stays hidden on a spec with no raidLoadout")
check(not Codex.suggestedLoadoutRows.mplusMeta:IsShown(),
    "the live-meta row stays hidden on a spec with no mplusMetaLoadout")

-- None present: no placeholder text, all three rows simply don't render
-- (per DESIGN.md).
Codex:Open("WARRIOR", 9202)
Codex:SelectTab("Loadouts")
check(not Codex.suggestedLoadoutRows.mplus:IsShown(),
    "the Mythic+ row is hidden entirely for a spec whose guide has no mplusLoadout")
check(not Codex.suggestedLoadoutRows.raid:IsShown(),
    "the Raid row is hidden entirely for a spec whose guide has no raidLoadout")
check(not Codex.suggestedLoadoutRows.mplusMeta:IsShown(),
    "the live-meta row is hidden entirely for a spec whose guide has no mplusMetaLoadout")

-- Copy: same read-only highlighted-editbox pattern as a saved loadout's
-- Copy, and the same Show-before-focus ordering the mock enforces via
-- IsEffectivelyShown (see the saved-loadout Copy test above) - a reordering
-- mistake here would error under the mock instead of silently copying
-- nothing. Checked for all three kinds, so a shared-helper bug that only
-- shows up on the second or third row built is not masked by testing just
-- the first.
Codex:Open("WARRIOR", 9201)
Codex:SelectTab("Loadouts")

local mplusCopyOk = pcall(function() mplusRow.copyButton:GetScript("OnClick")() end)
check(mplusCopyOk, "Copy on the Mythic+ row does not error under the mock's visibility-checked SetFocus")
check(Codex.copyDialog:IsShown(), "Copy on the Mythic+ row opens the copy dialog")
check(Codex.copyBox:GetText() == "C0EAy0kSampleExportStringFromSimC",
    "the copy dialog is populated with the Mythic+ loadout's export string", Codex.copyBox:GetText())

local raidCopyOk = pcall(function() raidRow.copyButton:GetScript("OnClick")() end)
check(raidCopyOk, "Copy on the Raid row does not error under the mock's visibility-checked SetFocus")
check(Codex.copyBox:GetText() == "C0EAy0kSampleRaidExportStringFromSimC",
    "the copy dialog is populated with the Raid loadout's export string, not the Mythic+ one",
    Codex.copyBox:GetText())

local metaCopyOk = pcall(function() metaRow.copyButton:GetScript("OnClick")() end)
check(metaCopyOk, "Copy on the live-meta row does not error under the mock's visibility-checked SetFocus")
check(Codex.copyBox:GetText() == "C0EAy0kSampleLiveMetaExportString",
    "the copy dialog is populated with the live-meta loadout's export string, not either SimC one",
    Codex.copyBox:GetText())

-- Add to my vault: calls Loadouts:Add with the exact arguments DESIGN.md
-- specifies for each kind, never touching SpecSageDB before the click, and
-- gives a brief confirmation via a temporary label change that reverts on
-- its own.
local vaultCountBefore = #LoadoutsModule:GetForSpec(9201)
mplusRow.addButton:GetScript("OnClick")(mplusRow.addButton)

local vaultAfter = LoadoutsModule:GetForSpec(9201)
check(#vaultAfter == vaultCountBefore + 1, "Add to my vault stores exactly one new loadout", #vaultAfter)
check(vaultAfter[#vaultAfter].name == "Suggested M+ (SimC)",
    "the added Mythic+ loadout uses the exact name DESIGN.md specifies", vaultAfter[#vaultAfter].name)
check(vaultAfter[#vaultAfter].category == "Mythic+",
    "the added Mythic+ loadout uses the exact category DESIGN.md specifies", vaultAfter[#vaultAfter].category)
check(vaultAfter[#vaultAfter].export == "C0EAy0kSampleExportStringFromSimC",
    "the added loadout keeps the guide's mplusLoadout.string as its export", vaultAfter[#vaultAfter].export)
check(mplusRow.addButton:GetText() == "Added!",
    "clicking Add to my vault gives a brief confirmation via a temporary label change",
    mplusRow.addButton:GetText())

mock.RunAfter()
check(mplusRow.addButton:GetText() == "Add to my vault",
    "the confirmation label reverts to 'Add to my vault' after the timer", mplusRow.addButton:GetText())

-- The Raid row's Add is independent: its own name/category, and it does not
-- disturb the Mythic+ entry already in the vault.
raidRow.addButton:GetScript("OnClick")(raidRow.addButton)
local vaultAfterRaid = LoadoutsModule:GetForSpec(9201)
check(#vaultAfterRaid == vaultCountBefore + 2, "Add to my vault on the Raid row stores a second loadout")
check(vaultAfterRaid[#vaultAfterRaid].name == "Suggested Raid (SimC)",
    "the added Raid loadout uses its own name, not the Mythic+ one", vaultAfterRaid[#vaultAfterRaid].name)
check(vaultAfterRaid[#vaultAfterRaid].category == "Raid",
    "the added Raid loadout uses the Raid category", vaultAfterRaid[#vaultAfterRaid].category)
check(vaultAfterRaid[#vaultAfterRaid].export == "C0EAy0kSampleRaidExportStringFromSimC",
    "the added Raid loadout keeps the guide's raidLoadout.string as its export",
    vaultAfterRaid[#vaultAfterRaid].export)
check(vaultAfterRaid[1].name == "Suggested M+ (SimC)",
    "the earlier Mythic+ entry is untouched by adding the Raid one")
mock.RunAfter()

-- The live-meta row's Add is likewise independent, and its category is
-- "Mythic+" (same category as the SimC mplus row, since it is also a
-- Mythic+ build - only the source and name differ) rather than a category
-- of its own.
metaRow.addButton:GetScript("OnClick")(metaRow.addButton)
local vaultAfterMeta = LoadoutsModule:GetForSpec(9201)
check(#vaultAfterMeta == vaultCountBefore + 3, "Add to my vault on the live-meta row stores a third loadout")
check(vaultAfterMeta[#vaultAfterMeta].name == "Top M+ Build (Live)",
    "the added live-meta loadout uses its own name", vaultAfterMeta[#vaultAfterMeta].name)
check(vaultAfterMeta[#vaultAfterMeta].category == "Mythic+",
    "the added live-meta loadout uses the Mythic+ category", vaultAfterMeta[#vaultAfterMeta].category)
check(vaultAfterMeta[#vaultAfterMeta].export == "C0EAy0kSampleLiveMetaExportString",
    "the added live-meta loadout keeps the guide's mplusMetaLoadout.string as its export",
    vaultAfterMeta[#vaultAfterMeta].export)
mock.RunAfter()

-- Clicking Add to my vault a second time adds a fourth entry rather than
-- silently no-oping - it is a plain Loadouts:Add call, not a toggle.
mplusRow.addButton:GetScript("OnClick")(mplusRow.addButton)
check(#LoadoutsModule:GetForSpec(9201) == vaultCountBefore + 4,
    "clicking Add to my vault again stores another loadout")
mock.RunAfter()

--------------------------------------------------------------------------------
section("Codex: rotation/cooldown conditions (v1.3)")
--------------------------------------------------------------------------------

-- A step's optional `condition` (the APL if= logic behind it, translated to
-- plain English) renders as its own sub-line, distinct in colour from the
-- step's own text and from a section header, and only when present - a step
-- with no condition costs no extra row.
GuideStore:RegisterSpec("WARRIOR", 9301, {
    specName = "Condition Warrior",
    role = "DAMAGER",
    rotation = {
        { title = "Single Target", steps = {
            { spellID = 163201, text = "Execute", condition = "with Rage above 40, or on a Sudden Death proc" },
            { spellID = 12294, text = "Mortal Strike on cooldown" },
        }},
    },
    cooldowns = {
        { spellID = 227847, text = "Bladestorm", condition = "while your Colossus Smash debuff is active" },
        { spellID = 107574, text = "Avatar" },
    },
})

Codex:Open("WARRIOR", 9301)
Codex:SelectTab("Rotation")

local rotationPool = Codex.pools.rotation
check(rotationPool[1].text:GetText() == "Single Target", "the rotation group title renders first",
    rotationPool[1].text:GetText())
check(rotationPool[2].text:GetText() == "Execute", "a step with a condition still renders its own line first",
    rotationPool[2].text:GetText())
check(rotationPool[2].icon:IsShown(), "the step's own line keeps its spell icon")
check(rotationPool[3].text:GetText() == "with Rage above 40, or on a Sudden Death proc",
    "the step's condition renders as a separate line right after it", rotationPool[3].text:GetText())
check(not rotationPool[3].icon:IsShown(), "the condition line has no spell icon of its own")
check(rotationPool[3].text.color[1] == 0.55 and rotationPool[3].text.color[2] == 0.75
    and rotationPool[3].text.color[3] == 0.95,
    "the condition line uses its own colour, distinct from step text and from a section header",
    table.concat(rotationPool[3].text.color or {}, ","))
check(rotationPool[4].text:GetText() == "Mortal Strike on cooldown",
    "a step with no condition is followed directly by the next step, with no blank line between",
    rotationPool[4].text:GetText())
check(rotationPool[5] == nil or not rotationPool[5]:IsShown(),
    "a step with no condition costs no extra row")

Codex:SelectTab("Cooldowns")
local cooldownsPool = Codex.pools.cooldowns
check(cooldownsPool[1].text:GetText() == "Bladestorm", "a cooldown entry's own line renders first",
    cooldownsPool[1].text:GetText())
check(cooldownsPool[2].text:GetText() == "while your Colossus Smash debuff is active",
    "the cooldown entry's condition renders as a separate line right after it", cooldownsPool[2].text:GetText())
check(cooldownsPool[3].text:GetText() == "Avatar",
    "a cooldown entry with no condition is followed directly by the next entry",
    cooldownsPool[3].text:GetText())

--------------------------------------------------------------------------------
section("Codex: Options tab")
--------------------------------------------------------------------------------

Codex:SelectTab("Options")
check(Codex.activeTab == "Options", "the Options tab can be selected")

local function CountShownOptionRows(pool)
    local shown = 0
    for _, row in ipairs(pool or {}) do
        if row:IsShown() then shown = shown + 1 end
    end
    return shown
end

do
    -- Every schema entry must reach a widget; a group silently skipped
    -- would leave settings reachable only through the Blizzard panel that
    -- this tab exists to back up.
    local expected = { check = 0, range = 0, action = 0 }
    for _, group in ipairs(ns.OPTION_GROUPS) do
        for _, entry in ipairs(group.options) do
            expected[entry.kind] = (expected[entry.kind] or 0) + 1
        end
    end

    check(CountShownOptionRows(Codex.optionPools.check) == expected.check,
        "every check option renders a row",
        format("shown=%d expected=%d", CountShownOptionRows(Codex.optionPools.check), expected.check))
    check(CountShownOptionRows(Codex.optionPools.range) == expected.range,
        "every range option renders a row",
        format("shown=%d expected=%d", CountShownOptionRows(Codex.optionPools.range), expected.range))
    check(CountShownOptionRows(Codex.optionPools.action) == expected.action,
        "every action option renders a row",
        format("shown=%d expected=%d", CountShownOptionRows(Codex.optionPools.action), expected.action))
end

do
    -- Clicking a checkbox must write through to the same saved variable the
    -- Settings panel writes, not to a copy.
    local entry
    for _, group in ipairs(ns.OPTION_GROUPS) do
        for _, candidate in ipairs(group.options) do
            if candidate.kind == "check" and candidate.scope == "db" and candidate.key == "locked" then
                entry = candidate
            end
        end
    end
    check(entry ~= nil, "the Lock overlay checkbox is in the schema")

    local before = ns.db.locked
    Codex:ToggleOption(entry)
    check(ns.db.locked ~= before, "toggling a check option flips the stored value")
    Codex:ToggleOption(entry)
    check(ns.db.locked == before, "toggling it back restores the original value")
end

do
    -- Steppers move by exactly one step and refuse to leave the range.
    local entry
    for _, group in ipairs(ns.OPTION_GROUPS) do
        for _, candidate in ipairs(group.options) do
            if candidate.kind == "range" and candidate.key == "fontSize" then entry = candidate end
        end
    end
    check(entry ~= nil, "the Font size range option is in the schema")

    ns.db.fontSize = 12
    Codex:StepOption(entry, 1)
    check(ns.db.fontSize == 13, "stepping up moves one step", ns.db.fontSize)
    Codex:StepOption(entry, -1)
    check(ns.db.fontSize == 12, "stepping down moves one step back", ns.db.fontSize)

    ns.db.fontSize = entry.max
    Codex:StepOption(entry, 1)
    check(ns.db.fontSize == entry.max, "stepping past the maximum clamps", ns.db.fontSize)

    ns.db.fontSize = entry.min
    Codex:StepOption(entry, -1)
    check(ns.db.fontSize == entry.min, "stepping below the minimum clamps", ns.db.fontSize)
    ns.db.fontSize = 12
end

do
    -- A fractional step accumulates float error if the value is repeatedly
    -- added to; ClampOptionValue rebuilds it from a whole number of steps.
    local entry
    for _, group in ipairs(ns.OPTION_GROUPS) do
        for _, candidate in ipairs(group.options) do
            if candidate.kind == "range" and candidate.key == "opacity" then entry = candidate end
        end
    end

    ns.db.opacity = 0
    for _ = 1, 10 do Codex:StepOption(entry, 1) end
    check(math.abs(ns.db.opacity - 0.5) < 1e-9,
        "ten 0.05 steps land exactly on 0.5 with no float drift", ns.db.opacity)
    ns.db.opacity = 0.75
end

do
    -- /sage config must land on the Options tab: that is the surface this
    -- feature exists to provide, and it works even when Blizzard's Settings
    -- panel refuses to build.
    Codex:SelectTab("Overview")
    Codex.frame:Hide()
    SlashCmdList.SPECSAGE("config")
    check(Codex.activeTab == "Options", "/sage config opens the Options tab", tostring(Codex.activeTab))
    check(Codex.frame:IsShown(), "/sage config shows the Codex")
end

do
    -- Leaving the tab hides its widgets, the same contract every other tab
    -- honours; a stale checkbox drawn over the Rotation tab would be a
    -- visible bug.
    Codex:SelectTab("Rotation")
    check(CountShownOptionRows(Codex.optionPools.check) == 0,
        "leaving Options hides its check rows")
    check(CountShownOptionRows(Codex.optionPools.range) == 0,
        "leaving Options hides its range rows")
    check(CountShownOptionRows(Codex.optionPools.action) == 0,
        "leaving Options hides its action rows")
    Codex:SelectTab("Options")
end

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
section("Codex: notes survive a spec switch")
--------------------------------------------------------------------------------

-- Clicking a spec-rail button does not clear an EditBox's focus in WoW, so
-- SelectSpec must flush the still-open note itself before RenderNotes
-- overwrites the buffer with the newly selected spec's saved text.
Codex:Open("WARRIOR", 72)
Codex:SelectTab("Notes")
Codex.notesBox:SetText("Typed but not yet saved for 72.")
Codex:SelectSpec(71) -- Arms: a different real spec, same class, Notes tab stays open
check(NotesModule:Get(72) == "Typed but not yet saved for 72.",
    "switching spec flushes the previously open note for its own spec")
check(Codex.notesBox:GetText() == NotesModule:Get(71),
    "the newly selected spec's own note is shown, not the old spec's buffer")

--------------------------------------------------------------------------------
section("Trinket tier lists: registration (Data/API.lua v1.5)")
--------------------------------------------------------------------------------

do
    local GuideStore = ns.GuideStore
    check(GuideStore:GetTrinkets(9601) == nil, "GetTrinkets returns nil for a spec with nothing registered")

    local ok = GuideStore:RegisterTrinkets(9601, { unavailable = "no sims for this spec" })
    check(ok == true, "RegisterTrinkets accepts the unavailable shape")
    check(GuideStore:GetTrinkets(9601).unavailable == "no sims for this spec", "the unavailable reason round-trips")

    ok = GuideStore:RegisterTrinkets(9602, {
        source = "test fixture", patch = "12.1",
        lists = {
            { title = "Single Target", fightStyle = "castingpatchwerk", list = {
                { itemID = 19019, name = "Thunderfury, Blessed Blade of the Windseeker", ilvl = 344, gain = 10.5, tier = "S", source = "Raid", onUse = false },
                { itemID = 777001, name = "Uncached Test Trinket", ilvl = 334, gain = 8.1, tier = "A", source = "Dungeon", onUse = true },
            }},
            { title = "5 Targets", fightStyle = "castingpatchwerk5", list = {
                { itemID = 777001, name = "Uncached Test Trinket", ilvl = 334, gain = 12.0, tier = "S", source = "Dungeon", onUse = true },
            }},
        },
    })
    check(ok == true, "RegisterTrinkets accepts a valid two-list registration")
    check(#GuideStore:GetTrinkets(9602).lists == 2, "both fight-style lists round-trip")

    local _, bad = silently(function() return GuideStore:RegisterTrinkets(9603, { lists = {} }) end)
    check(bad == false, "RegisterTrinkets rejects an empty lists array")
    _, bad = silently(function()
        return GuideStore:RegisterTrinkets(9603, { lists = { { title = "ST", list = { { itemID = "nope", name = "x", tier = "S", gain = 1 } } } } })
    end)
    check(bad == false, "RegisterTrinkets rejects a non-numeric itemID")
    _, bad = silently(function()
        return GuideStore:RegisterTrinkets(9603, { lists = { { title = "ST", list = { { itemID = 1, name = "x", tier = "Z", gain = 1 } } } } })
    end)
    check(bad == false, "RegisterTrinkets rejects an unknown tier letter")
    _, bad = silently(function() return GuideStore:RegisterTrinkets("spec", { unavailable = "x" }) end)
    check(bad == false, "RegisterTrinkets rejects a non-number specID")
    check(GuideStore:GetTrinkets(9603) == nil, "a rejected registration stores nothing")

    -- Optional gear[].itemID (v1.5): a number is accepted, anything else is not.
    ok = GuideStore:RegisterSpec("MAGE", 9604, {
        specName = "Linked Gear", role = "DAMAGER",
        gear = { { slot = "Trinket", text = "The classic pick", itemID = 19019 } },
    })
    check(ok == true, "RegisterSpec accepts a numeric gear[].itemID")
    _, bad = silently(function()
        return GuideStore:RegisterSpec("MAGE", 9605, {
            specName = "Bad Linked Gear", role = "DAMAGER",
            gear = { { slot = "Trinket", text = "x", itemID = "19019" } },
        })
    end)
    check(bad == false, "RegisterSpec rejects a non-numeric gear[].itemID")
end

--------------------------------------------------------------------------------
section("Trinket tier lists: shipped data (Data/Trinkets.lua)")
--------------------------------------------------------------------------------

do
    local GuideStore = ns.GuideStore
    local withLists, withSim, withIcyVeins, withNote, unavailable, total = 0, 0, 0, 0, 0, 0
    for _, classEntry in ipairs(GuideStore:GetClasses()) do
        for _, specID in ipairs(GuideStore:GetClassSpecs(classEntry.token)) do
            if specID < 9000 then
                total = total + 1
                local data = GuideStore:GetTrinkets(specID)
                check(data ~= nil, format("shipped spec %d has a trinket registration", specID))
                if data and data.unavailable then
                    unavailable = unavailable + 1
                elseif data then
                    withLists = withLists + 1
                    if data.note then withNote = withNote + 1 end
                    local sawSim, sawIcyVeins, sorted, simRowsCarrySiteTier = false, false, true, true
                    for _, listEntry in ipairs(data.lists) do
                        local isSim = listEntry.list[1] and listEntry.list[1].gain ~= nil
                        if isSim then sawSim = true end
                        if listEntry.title == "Icy Veins" then sawIcyVeins = true end
                        for i, row in ipairs(listEntry.list) do
                            if isSim and i > 1 and row.gain > listEntry.list[i - 1].gain then sorted = false end
                            -- A sim row either names Icy Veins' tier for the item or
                            -- carries none (the site does not list it); never junk.
                            if row.siteTier ~= nil and not ({ S = 1, A = 1, B = 1, C = 1, D = 1 })[row.siteTier] then
                                simRowsCarrySiteTier = false
                            end
                        end
                        check(#listEntry.list > 0 and (not isSim or #listEntry.list <= 15),
                            format("spec %d '%s' list has rows (sim lists at most 15)", specID, listEntry.title), #listEntry.list)
                        -- A sim list always opens with the best trinket (S by
                        -- construction); an editorial list may leave its S row
                        -- empty (Wowhead does for a couple of specs), so it
                        -- only has to open at S or A.
                        local top = listEntry.list[1] and listEntry.list[1].tier
                        check(top == "S" or (not isSim and top == "A"),
                            format("spec %d '%s' top trinket is tier S (or A for an editorial list)", specID, listEntry.title), top)
                    end
                    check(sorted, format("spec %d sim lists are sorted by gain, best first", specID))
                    check(simRowsCarrySiteTier, format("spec %d siteTier values are valid tiers", specID))
                    check(sawIcyVeins, format("spec %d carries an Icy Veins list", specID))
                    if sawSim then withSim = withSim + 1 end
                    if sawIcyVeins then withIcyVeins = withIcyVeins + 1 end
                    -- A spec with no sim list explains why.
                    check(sawSim or (data.note and data.note:find("No sim list", 1, true) ~= nil),
                        format("spec %d without a sim list carries a note saying why", specID))
                end
            end
        end
    end
    check(total == 40, "all 40 shipped specs were checked", total)
    check(withLists == 40 and unavailable == 0, "every shipped spec has at least one trinket list", withLists)
    check(withSim == 27, "27 specs ship a bloodmallet-derived sim list", withSim)
    check(withIcyVeins == 40, "all 40 specs ship an Icy Veins list", withIcyVeins)
    check(withNote == 13, "the 13 specs without sims (6 healers + 7 without a current SimC profile) carry a note", withNote)
end

--------------------------------------------------------------------------------
section("Codex: BiS tab trinket tier list and clickable item links (v1.5)")
--------------------------------------------------------------------------------

do
    -- MAGE 9604 (registered above) has one gear entry with an itemID and no
    -- trinket registration of its own; give it the 9602 fixture's lists.
    ns.GuideStore:RegisterTrinkets(9604, ns.GuideStore:GetTrinkets(9602))
    Codex.trinketListIndex = 1
    Codex:Open("MAGE", 9604)
    Codex:SelectTab("BiS")

    local function shownTrinketRows()
        local n = 0
        for _, row in ipairs(Codex.trinketRowPool) do
            if row:IsShown() then n = n + 1 end
        end
        return n
    end

    check(shownTrinketRows() == 2, "the Single Target list renders one row per trinket", shownTrinketRows())
    local first = Codex.trinketRowPool[1]
    check(first.tag:GetText() == "S", "the top trinket row carries its S tier tag", first.tag:GetText())
    check(first.itemID == 19019, "the trinket row knows its itemID", first.itemID)
    check(first.text:GetText():find("Thunderfury", 1, true) ~= nil,
        "a cached trinket shows the client's item name", first.text:GetText())
    check(first.text:GetText():find("ilvl 344", 1, true) ~= nil, "the row shows the simmed item level")
    check(first.gain:GetText() == "+10.5%", "the row shows the sim gain", first.gain:GetText())
    local second = Codex.trinketRowPool[2]
    check(second.text:GetText():find("Uncached Test Trinket", 1, true) ~= nil,
        "an uncached trinket falls back to the sim's own name", second.text:GetText())
    check(second.text:GetText():find("on%-use") ~= nil, "an on-use trinket is tagged as such")
    local requested = false
    for _, id in ipairs(mock.itemLoadRequests) do if id == 777001 then requested = true end end
    check(requested, "an uncached trinket queues a RequestLoadItemDataByID call")
    check(Codex.trinketToggle:IsShown() and Codex.trinketToggle:GetText() == "Single Target",
        "the fight-style toggle shows the active list's title", Codex.trinketToggle:GetText())

    -- Hover and click behave like an item link.
    first:GetScript("OnEnter")(first)
    check(GameTooltip.itemID == 19019, "hovering a trinket row shows its item tooltip", GameTooltip.itemID)
    first:GetScript("OnLeave")(first)
    mock.itemRefClicks = {}
    first:GetScript("OnMouseUp")(first, "LeftButton")
    check(#mock.itemRefClicks == 1 and mock.itemRefClicks[1].link:find("item:19019", 1, true) ~= nil,
        "clicking a trinket row opens it as an item link via SetItemRef",
        mock.itemRefClicks[1] and mock.itemRefClicks[1].link)

    -- Toggling cycles to the next list and wraps.
    Codex:CycleTrinketList()
    check(Codex.trinketToggle:GetText() == "5 Targets", "the toggle cycles to the next fight style", Codex.trinketToggle:GetText())
    check(shownTrinketRows() == 1, "the 5 Targets list renders its own row count", shownTrinketRows())
    Codex:CycleTrinketList()
    check(Codex.trinketToggle:GetText() == "Single Target", "the toggle wraps back to the first list")

    -- Once the uncached trinket resolves, GET_ITEM_INFO_RECEIVED re-renders it.
    mock.items[777001] = { name = "Now Cached Trinket", quality = 4 }
    mock.Fire("GET_ITEM_INFO_RECEIVED", 777001)
    check(Codex.trinketRowPool[2].text:GetText():find("Now Cached Trinket", 1, true) ~= nil,
        "a trinket row re-renders with the real name once the item loads", Codex.trinketRowPool[2].text:GetText())
    mock.items[777001] = nil

    -- A spec with an unavailable reason shows it and no rows or toggle.
    Codex:Open("MAGE", 9005)
    ns.GuideStore:RegisterTrinkets(9005, { unavailable = "no sims for this spec" })
    Codex:SelectTab("BiS")
    check(shownTrinketRows() == 0, "an unavailable spec renders no trinket rows")
    check(not Codex.trinketToggle:IsShown(), "an unavailable spec hides the fight-style toggle")
    local found = false
    for _, row in ipairs(Codex.pools.bis) do
        if row:IsShown() and row.text:GetText() == "no sims for this spec" then found = true end
    end
    check(found, "the unavailable reason is rendered as a line")

    -- Leaving the tab hides the trinket widgets.
    Codex:SelectTab("Overview")
    check(shownTrinketRows() == 0 and not Codex.trinketToggle:IsShown(), "leaving the BiS tab hides the trinket rows and toggle")

end

--------------------------------------------------------------------------------
section("Item stat ranks on tooltips (Modules/ItemRanks.lua)")
--------------------------------------------------------------------------------

do
    local ItemRanks = ns:GetModule("ItemRanks")
    check(ItemRanks ~= nil, "ItemRanks module registered at load time")
    check(ItemRanks.hooked == "TooltipDataProcessor", "ItemRanks hooks through TooltipDataProcessor when it exists", ItemRanks.hooked)
    check(ns.db.itemStatRanks == true, "stat ranks default to on")

    -- The player is Unholy (252). Its statPriority follows Wowhead's order
    -- for the spec (Data/StatPriority.lua's source line): crit, mastery,
    -- haste, versatility once the primary stat is dropped.
    local ranks, count = ItemRanks:GetRankTable(252)
    check(ranks and ranks.crit == 1 and ranks.haste == 3 and ranks.versatility == 4 and count == 4,
        "GetRankTable ranks only the secondary stats, primary excluded", ranks and ranks.haste)
    check(ItemRanks:GetRankTable(9999) == nil, "GetRankTable returns nil for a spec with no guide")

    mock.items[880001] = { name = "Haste/Vers Test Bracers", quality = 3,
        stats = { ITEM_MOD_HASTE_RATING_SHORT = 512, ITEM_MOD_VERSATILITY = 380, ITEM_MOD_STAMINA_SHORT = 900 } }
    mock.items[880002] = { name = "Statless Test Trinket", quality = 3, stats = { ITEM_MOD_STAMINA_SHORT = 900 } }

    local lines = ItemRanks:Describe("item:880001", 252)
    check(lines and #lines == 2, "Describe returns one line per ranked stat on the item", lines and #lines)
    check(lines and lines[1].stat == "haste" and lines[1].rank == 3, "the best-ranked stat on the item comes first")
    check(lines and lines[2].stat == "versatility" and lines[2].rank == 4, "versatility ranks #4 for Unholy")
    check(ItemRanks:Describe("item:880002", 252) == nil, "an item with no secondary stats yields nothing")

    -- Fire the tooltip pipeline the way the client does.
    GameTooltip:SetOwner(nil, "ANCHOR_NONE")
    mock.FireTooltipItem(GameTooltip, 880001)
    local dump = table.concat(GameTooltip:Dump(), "\n")
    -- Ranks land on the stat's own line, in its right-aligned column (the
    -- mock's Dump renders a line as "left=right"), not in a summary
    -- underneath, and not appended to the left text where they would sit at
    -- a different offset on every line.
    check(dump:match("%+512 Haste=|cff%x+#3|r") ~= nil, "the Haste line's right column gains its #3 rank", dump)
    check(dump:match("%+380 Versatility=|cff%x+#4|r") ~= nil, "the Versatility line's right column gains its #4 rank", dump)
    check(dump:find("+512 Haste  ", 1, true) == nil, "the left text is not appended to when the right column is free", dump)
    check(GameTooltip.lines[2].rightShown or GameTooltip.lines[3].rightShown, "the right column FontString is shown")
    check(dump:find("+900 Stamina=", 1, true) == nil, "the Stamina line is left alone", dump)

    -- When the right column is already in use, the rank falls back to the
    -- left text so it is never dropped or overwritten.
    GameTooltip:SetOwner(nil, "ANCHOR_NONE")
    GameTooltip:SetItemByID(880001)
    for _, line in ipairs(GameTooltip.lines) do line.right = "taken" end
    ItemRanks:Annotate(GameTooltip, "item:880001")
    local busy = table.concat(GameTooltip:Dump(), "\n")
    check(busy:match("%+512 Haste  |cff%x+#3|r=taken") ~= nil,
        "a line whose right column is occupied gets the rank appended to its left text instead", busy)
    GameTooltip:SetOwner(nil, "ANCHOR_NONE")
    mock.FireTooltipItem(GameTooltip, 880001)
    dump = table.concat(GameTooltip:Dump(), "\n")
    check(dump:find("SpecSage stat ranks", 1, true) == nil,
        "no summary line is added when every rank was placed inline", dump)

    -- A second pass over the same tooltip (the client can fire the post-call
    -- more than once) does not double-annotate a line.
    ItemRanks:Annotate(GameTooltip, "item:880001")
    dump = table.concat(GameTooltip:Dump(), "\n")
    check(select(2, dump:gsub("#3|r", "")) == 1, "re-annotating does not stack a second rank onto the line", dump)

    -- A tooltip whose lines cannot be reached (no name) falls back to the
    -- summary line.
    local anon = setmetatable({ lines = {}, shown = false, hooks = {} }, { __index = GameTooltip })
    anon.GetName = function() return nil end
    anon:SetOwner(nil, "ANCHOR_NONE")
    anon:SetItemByID(880001)
    ItemRanks:Annotate(anon, "item:880001")
    dump = table.concat(anon:Dump(), "\n")
    check(dump:find("SpecSage stat ranks (Unholy):", 1, true) ~= nil, "an unnamed tooltip gets the summary header instead", dump)
    check(dump:find("Haste #3 of 4", 1, true) ~= nil and dump:find("Versatility #4 of 4", 1, true) ~= nil,
        "the summary lists Haste #3 of 4 and Versatility #4 of 4", dump)

    GameTooltip:SetOwner(nil, "ANCHOR_NONE")
    mock.FireTooltipItem(GameTooltip, 880002)
    check(table.concat(GameTooltip:Dump(), "\n"):find("SpecSage", 1, true) == nil,
        "an item with no secondaries adds no rank lines")

    ns.db.itemStatRanks = false
    GameTooltip:SetOwner(nil, "ANCHOR_NONE")
    mock.FireTooltipItem(GameTooltip, 880001)
    check(table.concat(GameTooltip:Dump(), "\n"):find("SpecSage", 1, true) == nil,
        "turning the option off suppresses the rank lines")
    ns.db.itemStatRanks = true

    -- Trinket tier on the tooltip: the player's spec (Unholy, 252) ships
    -- real lists; pick its Single Target #1 and check every list that ranks
    -- it is named, with its tier letter.
    local unholy = ns.GuideStore:GetTrinkets(252)
    local topRow = unholy.lists[1].list[1]
    local tiers = ItemRanks:DescribeTrinket(topRow.itemID, 252)
    check(tiers and #tiers >= 2 and tiers[1].title == "Single Target" and tiers[1].tier == "S",
        "DescribeTrinket finds the spec's top single-target trinket as S in the Single Target list", tiers and #tiers)
    local sawIcyVeins = false
    for _, entry in ipairs(tiers or {}) do
        if entry.title == "Icy Veins" then sawIcyVeins = true end
    end
    check(sawIcyVeins, "DescribeTrinket also reports the Icy Veins list's tier for the same trinket")
    check(ItemRanks:DescribeTrinket(19019, 252) == nil, "DescribeTrinket returns nil for an item no list ranks")

    mock.items[topRow.itemID] = { name = topRow.name, quality = 4, equipLoc = "INVTYPE_TRINKET" }
    GameTooltip:SetOwner(nil, "ANCHOR_NONE")
    mock.FireTooltipItem(GameTooltip, topRow.itemID)
    dump = table.concat(GameTooltip:Dump(), "\n")
    check(dump:find("SpecSage trinket tier (Unholy):", 1, true) ~= nil, "a ranked trinket's tooltip gains a trinket tier header", dump)
    check(dump:find("Single Target |cff", 1, true) ~= nil and dump:find("S|r (+", 1, true) ~= nil,
        "the trinket tier line names the list, the tier and the sim gain", dump)
    check(dump:find("Icy Veins |cff", 1, true) ~= nil, "the trinket tier line includes Icy Veins' tier", dump)
    check(dump:find("stat ranks", 1, true) == nil, "a trinket with no secondary stats adds no stat-rank lines")
    mock.items[topRow.itemID] = nil

    -- A trinket no list ranks says so; a non-trinket no list ranks says nothing.
    mock.items[880003] = { name = "Obscure Trinket", quality = 2, equipLoc = "INVTYPE_TRINKET" }
    GameTooltip:SetOwner(nil, "ANCHOR_NONE")
    mock.FireTooltipItem(GameTooltip, 880003)
    check(table.concat(GameTooltip:Dump(), "\n"):find("not in this spec's trinket lists", 1, true) ~= nil,
        "an unranked trinket's tooltip says it is not in the spec's lists")
    mock.items[880003] = nil
    GameTooltip:SetOwner(nil, "ANCHOR_NONE")
    mock.FireTooltipItem(GameTooltip, 880002)
    check(table.concat(GameTooltip:Dump(), "\n"):find("trinket", 1, true) == nil,
        "a non-trinket with nothing to rank gets no trinket line")

    -- The option is exposed through the shared schema (Codex Options tab and
    -- the Settings panel both read ns.OPTION_GROUPS).
    local exposed = false
    for _, group in ipairs(ns.OPTION_GROUPS) do
        for _, entry in ipairs(group.options) do
            if entry.key == "itemStatRanks" and entry.scope == "db" then exposed = true end
        end
    end
    check(exposed, "the stat-ranks option is in ns.OPTION_GROUPS")

    mock.items[880001], mock.items[880002] = nil, nil
end

--------------------------------------------------------------------------------
section("Linked BiS lists and guide-site builds (Data/BiS.lua, Data/SiteLoadouts.lua)")
--------------------------------------------------------------------------------

do
    local GuideStore = ns.GuideStore
    -- Shipped data: every spec has a BiS list with all 14-slot rows valid,
    -- and a set of site builds whose strings look like export strings.
    local bisSpecs, buildSpecs, builds = 0, 0, 0
    local VALID_SLOT = {}
    for _, slot in ipairs(ns:GetModule("BiS").SLOT_ORDER) do VALID_SLOT[slot] = true end
    for _, classEntry in ipairs(GuideStore:GetClasses()) do
        for _, specID in ipairs(GuideStore:GetClassSpecs(classEntry.token)) do
            if specID < 9000 then
                local bis = GuideStore:GetBiS(specID)
                check(bis ~= nil and #bis.lists >= 1, format("spec %d ships a linked BiS list", specID))
                if bis then
                    bisSpecs = bisSpecs + 1
                    local titles = {}
                    for _, listEntry in ipairs(bis.lists) do
                        check(not titles[listEntry.title], format("spec %d BiS list titles are unique", specID), listEntry.title)
                        titles[listEntry.title] = true
                        check(#listEntry.list >= 12, format("spec %d '%s' BiS list covers most slots", specID, listEntry.title), #listEntry.list)
                        for _, row in ipairs(listEntry.list) do
                            if not VALID_SLOT[row.slot] then check(false, format("spec %d BiS row has a valid slot", specID), row.slot) end
                        end
                    end
                end
                local site = GuideStore:GetSiteLoadouts(specID)
                check(site ~= nil and #site.builds >= 1, format("spec %d ships at least one Icy Veins build", specID))
                if site then
                    buildSpecs = buildSpecs + 1
                    for _, build in ipairs(site.builds) do
                        builds = builds + 1
                        check(build.string:match("^[A-Za-z0-9+/]+$") ~= nil and #build.string >= 60,
                            format("spec %d build '%s' string looks like a talent export string", specID, build.label))
                        check(build.label:find("\n", 1, true) == nil and build.label:match("[-–]%s*$") == nil,
                            format("spec %d build label is clean", specID), build.label)
                    end
                end
            end
        end
    end
    check(bisSpecs == 40, "all 40 specs have a linked BiS list", bisSpecs)
    check(buildSpecs == 40, "all 40 specs have site builds", buildSpecs)
    check(builds >= 100, "over 100 site builds ship in total", builds)

    -- Wowhead sits beside Icy Veins on every spec: a Wowhead BiS list, a
    -- Wowhead trinket list, Wowhead builds, and whTier on sim trinket rows.
    local whBis, whTrinkets, whBuilds, ivBuilds, whTierRows = 0, 0, 0, 0, 0
    for _, classEntry in ipairs(GuideStore:GetClasses()) do
        for _, specID in ipairs(GuideStore:GetClassSpecs(classEntry.token)) do
            if specID < 9000 then
                local bis = GuideStore:GetBiS(specID)
                local sawWH, sawIV = false, false
                for _, listEntry in ipairs(bis.lists) do
                    if listEntry.title:find("^Wowhead") then sawWH = true end
                    if listEntry.title:find("^Icy Veins") then sawIV = true end
                end
                check(sawWH and sawIV, format("spec %d has both an Icy Veins and a Wowhead BiS list", specID))
                if sawWH then whBis = whBis + 1 end
                local trinkets = GuideStore:GetTrinkets(specID)
                for _, listEntry in ipairs(trinkets.lists) do
                    if listEntry.title == "Wowhead" then whTrinkets = whTrinkets + 1 end
                    for _, row in ipairs(listEntry.list) do
                        if row.whTier then whTierRows = whTierRows + 1 end
                    end
                end
                local site = GuideStore:GetSiteLoadouts(specID)
                local specWH, specIV = 0, 0
                for _, build in ipairs(site.builds) do
                    if build.site == "Wowhead" then specWH = specWH + 1 elseif build.site == "Icy Veins" then specIV = specIV + 1 end
                    check(build.site == "Wowhead" or build.site == "Icy Veins", format("spec %d build names its site", specID), build.site)
                end
                check(specWH > 0 and specIV > 0, format("spec %d has builds from both sites", specID), specWH .. "/" .. specIV)
                whBuilds, ivBuilds = whBuilds + specWH, ivBuilds + specIV
            end
        end
    end
    check(whBis == 40, "all 40 specs have a Wowhead BiS list", whBis)
    check(whTrinkets == 40, "all 40 specs have a Wowhead trinket list", whTrinkets)
    check(whBuilds >= 150 and ivBuilds >= 100, "both sites contribute builds in bulk", whBuilds .. "/" .. ivBuilds)
    check(whTierRows >= 200, "most sim trinket rows carry a Wowhead tier", whTierRows)
    local _, badTier = silently(function()
        return GuideStore:RegisterTrinkets(9702, { lists = { { title = "x", list = { { itemID = 1, name = "n", tier = "S", whTier = "Z" } } } } })
    end)
    check(badTier == false, "RegisterTrinkets rejects an invalid whTier")
    check(GuideStore:RegisterTrinkets(9702, { lists = { { title = "x", list = { { itemID = 1, name = "n", tier = "F" } } } } }) == true,
        "RegisterTrinkets accepts tier F (Wowhead uses it)")

    -- Validation.
    local _, bad = silently(function() return GuideStore:RegisterBiS(9701, { lists = { { title = "x", list = { { slot = "Cape", itemID = 1, name = "n" } } } } }) end)
    check(bad == false, "RegisterBiS rejects an invalid slot")
    _, bad = silently(function() return GuideStore:RegisterSiteLoadouts(9701, { patch = "12.1", builds = { { label = "x", string = "" } } }) end)
    check(bad == false, "RegisterSiteLoadouts rejects an empty string")

    -- BiS tab: rows, toggle, link click.
    GuideStore:RegisterBiS(9604, {
        source = "test", patch = "12.1",
        lists = {
            { title = "Overall", list = {
                { slot = "Weapon", itemID = 19019, name = "Thunderfury, Blessed Blade of the Windseeker", from = "Molten Core" },
                { slot = "Neck", itemID = 42, name = "Champion's Dreadful Gladiator's Pendant of Alacrity", from = "PvP" },
            }},
            { title = "Raid", list = { { slot = "Neck", itemID = 42, name = "Champion's Dreadful Gladiator's Pendant of Alacrity", from = "PvP" } } },
        },
    })
    Codex.bisListIndex = 1
    Codex:Open("MAGE", 9604)
    Codex:SelectTab("BiS")
    local function shownLinkRows()
        local n = 0
        for _, row in ipairs(Codex.bisLinkRowPool) do if row:IsShown() then n = n + 1 end end
        return n
    end
    check(shownLinkRows() == 2, "the Overall BiS list renders one row per slot", shownLinkRows())
    local linkRow = Codex.bisLinkRowPool[1]
    check(linkRow.slot:GetText() == "Weapon" and linkRow.itemID == 19019, "a BiS row shows its slot and knows its item")
    check(linkRow.text:GetText():find("Thunderfury", 1, true) ~= nil and linkRow.text:GetText():find("Molten Core", 1, true) ~= nil,
        "a BiS row shows the item name and drop source", linkRow.text:GetText())
    check(Codex.bisListToggle:IsShown() and Codex.bisListToggle:GetText() == "Overall", "the BiS context toggle shows the active list")
    mock.itemRefClicks = {}
    linkRow:GetScript("OnMouseUp")(linkRow, "LeftButton")
    check(#mock.itemRefClicks == 1, "clicking a BiS row opens its item link")

    check(linkRow.addButton == nil, "a BiS row has no Add button (the checklist was pulled)")

    Codex:CycleBiSList()
    check(Codex.bisListToggle:GetText() == "Raid" and shownLinkRows() == 1, "the toggle cycles to the Raid list", shownLinkRows())
    Codex:SelectTab("Overview")
    check(shownLinkRows() == 0 and not Codex.bisListToggle:IsShown(), "leaving the tab hides the linked BiS rows")

    -- Loadouts tab: Icy Veins build rows with Copy and Add to my vault.
    GuideStore:RegisterSiteLoadouts(9604, {
        source = "test", patch = "12.1",
        builds = {
            { label = "Raid / Cleave - Sunfury", string = "C4DAAAAAAAAAAAAAAAAAAAAAAYGGLzMzswMDamZGAAAGAwMz0sssMDAgNAAAzMDbWmxMLzYMzMzMsxMmZmBAYAAAGgZGwMAYYmZA" },
            { label = "High Mythic+ Keys - Spellslinger", string = "C4DAAAAAAAAAAAAAAAAAAAAAAYGGLzMzswMDamZGAAAGAwMz0sssMDAgNAAAzMDbWmxMLzYMzMzMsxMmZmBAYAAAGgZGwMAYYmZB" },
        },
    })
    Codex:SelectTab("Loadouts")
    local shownSite = 0
    for _, row in ipairs(Codex.siteLoadoutRowPool) do if row:IsShown() then shownSite = shownSite + 1 end end
    check(shownSite == 2, "the Loadouts tab renders one row per Icy Veins build", shownSite)
    local siteRow = Codex.siteLoadoutRowPool[1]
    check(siteRow.name:GetText():find("Icy Veins: Raid / Cleave - Sunfury", 1, true) ~= nil, "a site build row is labelled with its source and title", siteRow.name:GetText())
    siteRow.copyButton:GetScript("OnClick")()
    check(Codex.copyBox:GetText():find("^C4DAAAA") ~= nil, "Copy on a site build row opens the copy dialog with its string")
    Codex.copyDialog:Hide()
    local LoadoutsMod = ns:GetModule("Loadouts")
    local vaultBefore = #LoadoutsMod:GetForSpec(9604)
    Codex.siteLoadoutRowPool[2].addButton:GetScript("OnClick")(Codex.siteLoadoutRowPool[2].addButton)
    local vault = LoadoutsMod:GetForSpec(9604)
    check(#vault == vaultBefore + 1 and vault[#vault].category == "Mythic+",
        "Add to my vault on a Mythic+ site build files it under Mythic+", vault[#vault] and vault[#vault].category)
    check(vault[#vault].name == "Icy Veins: High Mythic+ Keys - Spellslinger", "the vault entry is named after the site build", vault[#vault].name)
    Codex:SelectTab("Overview")
    shownSite = 0
    for _, row in ipairs(Codex.siteLoadoutRowPool) do if row:IsShown() then shownSite = shownSite + 1 end end
    check(shownSite == 0, "leaving the Loadouts tab hides the site build rows")
end

--------------------------------------------------------------------------------
section("Character sheet panel (v1.6, UI/CharacterPanel.lua)")
--------------------------------------------------------------------------------

do
    local Panel = ns:GetModule("CharacterPanel")
    check(Panel ~= nil, "CharacterPanel module registered at load time")

    local function ShownText()
        local out = {}
        for _, row in ipairs(Panel.rows or {}) do
            if row:IsShown() then out[#out + 1] = row.text:GetText() or "" end
        end
        return table.concat(out, "\n")
    end
    local function ShownRow(needle)
        for _, row in ipairs(Panel.rows or {}) do
            if row:IsShown() and (row.text:GetText() or ""):find(needle, 1, true) then return row end
        end
        return nil
    end

    -- The panel exists but stays hidden until the character sheet opens.
    check(Panel.frame ~= nil, "the panel frame is built at enable time")
    check(Panel.frame:IsShown() == false, "the panel is hidden while the character sheet is closed")
    check(Panel.toggle ~= nil, "a show/hide checkbox is added to the character sheet")

    -- Dimensions come from the character sheet, not from the content: the
    -- panel is a docked second page of that window, so its top and bottom
    -- edges have to line up with the sheet's.
    do
        local byPoint = {}
        for _, point in ipairs(Panel.frame.points) do byPoint[point[1]] = point end
        check(byPoint.TOPLEFT ~= nil and byPoint.TOPLEFT[2] == CharacterFrame
                and byPoint.TOPLEFT[3] == "TOPRIGHT",
            "the panel's top-left is anchored to the character sheet's top-right")
        check(byPoint.BOTTOMLEFT ~= nil and byPoint.BOTTOMLEFT[2] == CharacterFrame
                and byPoint.BOTTOMLEFT[3] == "BOTTOMRIGHT",
            "and its bottom-left to the sheet's bottom-right, so the height matches exactly")
        check(Panel.frame.scrollFrame ~= nil,
            "a fixed height means the content scrolls rather than being cut off")
    end

    -- Opening the character sheet shows and renders it. The mock's player is
    -- Unholy (252), whose statPriority follows Wowhead's order.
    mock.ShowCharacterFrame(true)
    check(Panel.frame:IsShown() == true, "opening the character sheet shows the panel")
    check(Panel.frame.title:GetText() == "Unholy", "the panel is titled with the player's own spec",
        Panel.frame.title:GetText())
    local dump = ShownText()
    check(dump:find("Stat Priority", 1, true) ~= nil, "the panel has a stat priority section", dump)
    check(dump:find("1. Primary", 1, true) ~= nil, "the priority is numbered in the spec's own order", dump)
    check(dump:find("2. Crit", 1, true) ~= nil, "and follows Wowhead's order for the spec", dump)
    local critRow = ShownRow("2. Crit")
    check(critRow ~= nil and critRow.value:GetText() ~= "",
        "each stat row carries the player's live rating", critRow and critRow.value:GetText())
    check(dump:find("By Hero Talent Tree", 1, true) ~= nil, "the hero-tree orders are shown too", dump)
    check(dump:find("San'layn", 1, true) ~= nil, "one row per hero tree", dump)

    check(Panel.frame:GetWidth() == CharacterFrame:GetWidth(),
        "the panel is exactly as wide as the character sheet",
        Panel.frame:GetWidth() .. " vs " .. CharacterFrame:GetWidth())
    check(Panel:ContentWidth() < Panel.frame:GetWidth(),
        "with the row width inset for padding and the scrollbar", Panel:ContentWidth())

    -- Blizzard resizes the sheet when its side tabs open, so the width has to
    -- be re-read rather than captured once at build time.
    CharacterFrame:SetSize(500, 600)
    Panel:Update()
    check(Panel.frame:GetWidth() == 500, "the panel follows the sheet when it is resized",
        Panel.frame:GetWidth())
    CharacterFrame:SetSize(338, 424)
    Panel:Update()
    check(Panel.frame:GetWidth() == 338, "and follows it back", Panel.frame:GetWidth())

    -- The content lives in the scroll child, which is what grows; the panel
    -- itself must never be resized to fit its rows.
    check(Panel.frame.scrollChild:GetHeight() > 0, "the scroll child grows with the rendered rows",
        Panel.frame.scrollChild:GetHeight())
    check(Panel.frame.scrollChild:GetWidth() == Panel:ContentWidth(),
        "and is as wide as a row", Panel.frame.scrollChild:GetWidth())

    -- No slot hovered yet, so the BiS half asks for one.
    check(dump:find("hover a gear slot", 1, true) ~= nil, "the BiS half prompts for a slot first", dump)

    -- Hovering a paper doll slot fills the BiS half with that slot. The
    -- redraw is throttled (see the sections block below), so it lands on
    -- the next timer tick rather than inside the hover itself.
    mock.HoverPaperDollSlot("CharacterNeckSlot")
    mock.RunAfter()
    dump = ShownText()
    check(Panel.hoveredSlot == "Neck", "hovering the neck slot selects it", Panel.hoveredSlot)
    check(dump:find("BiS: Neck", 1, true) ~= nil, "the BiS half names the hovered slot", dump)

    -- The item shown is the one the spec's active BiS list has for that slot,
    -- and it carries the bonus-carrying item string (v1.6) so hovering it
    -- shows the upgraded item rather than the base one.
    local bis = ns.GuideStore:GetBiS(252)
    local wantNeck
    for _, row in ipairs(bis.lists[ns.db.characterPanel.listIndex].list) do
        if row.slot == "Neck" then wantNeck = row end
    end
    check(wantNeck ~= nil, "the spec's active BiS list has a neck")
    local neckRow
    for _, row in ipairs(Panel.rows) do
        if row:IsShown() and row.itemID == wantNeck.itemID then neckRow = row end
    end
    check(neckRow ~= nil, "the panel shows a row for that item", wantNeck and wantNeck.itemID)
    check(neckRow ~= nil and neckRow.itemLink == ns.ItemString(wantNeck.itemID, wantNeck.bonus),
        "the row carries the bonus-carrying item string", neckRow and neckRow.itemLink)

    -- A slot the guides list twice (Ring, Trinket) shows both rows, and both
    -- ring buttons select the same "Ring" slot.
    mock.HoverPaperDollSlot("CharacterFinger1Slot")
    mock.RunAfter()
    check(Panel.hoveredSlot == "Ring", "the second ring button selects the Ring slot too", Panel.hoveredSlot)
    local ringRows = 0
    for _, row in ipairs(Panel.rows) do
        if row:IsShown() and row.itemID then ringRows = ringRows + 1 end
    end
    check(ringRows == 2, "both of the list's rings are shown", ringRows)

    -- Clicking a row opens the item link, the same contract the Codex's rows have.
    mock.HoverPaperDollSlot("CharacterNeckSlot")
    mock.RunAfter()
    local clickable
    for _, row in ipairs(Panel.rows) do
        if row:IsShown() and row.itemID then clickable = row end
    end
    mock.itemRefClicks = {}
    clickable:GetScript("OnMouseUp")(clickable, "LeftButton")
    check(#mock.itemRefClicks == 1, "clicking an item row opens its link")

    -- The context toggle cycles the BiS list the rows come from, and does so
    -- without touching the Codex's own list index.
    local codexIndex = Codex.bisListIndex
    local firstTitle = Panel.frame.listToggle:GetText()
    Panel:CycleList()
    check(Panel.frame.listToggle:GetText() ~= firstTitle, "the context toggle cycles to the next BiS list",
        Panel.frame.listToggle:GetText())
    check(Codex.bisListIndex == codexIndex, "and leaves the Codex's own list alone")
    ns.db.characterPanel.listIndex = 1
    Panel:Update()

    -- The checkbox turns it off, and the choice is remembered.
    Panel.toggle:SetChecked(false)
    Panel.toggle:GetScript("OnClick")(Panel.toggle)
    check(ns.db.characterPanel.enabled == false, "unchecking the box saves the setting off")
    check(Panel.frame:IsShown() == false, "and hides the panel straight away")
    mock.ShowCharacterFrame(false)
    mock.ShowCharacterFrame(true)
    check(Panel.frame:IsShown() == false, "reopening the character sheet keeps it off")

    Panel.toggle:SetChecked(true)
    Panel.toggle:GetScript("OnClick")(Panel.toggle)
    check(ns.db.characterPanel.enabled == true, "checking it again saves the setting on")
    check(Panel.frame:IsShown() == true, "and shows the panel again")

    -- Closing the character sheet takes the panel with it.
    mock.ShowCharacterFrame(false)
    check(Panel.frame:IsShown() == false, "closing the character sheet hides the panel")

    -- Equipping something while the sheet is open redraws; while closed it
    -- must not (the panel is not even up to draw into).
    mock.Fire("PLAYER_EQUIPMENT_CHANGED", 2)
    check(Panel.frame:IsShown() == false, "an equipment change with the sheet closed shows nothing")
    mock.ShowCharacterFrame(true)
    check(pcall(function() mock.Fire("PLAYER_EQUIPMENT_CHANGED", 2) end),
        "an equipment change with the sheet open redraws without error")

    -- The setting is reachable from the options schema too, not only the box.
    local found
    for _, group in ipairs(ns.OPTION_GROUPS) do
        for _, entry in ipairs(group.options) do
            if entry.scope == "characterPanel" and entry.key == "enabled" then found = entry end
        end
    end
    check(found ~= nil, "the panel has an entry in ns.OPTION_GROUPS")
    check(found ~= nil and ns.GetOptionValue(found) == true, "which reads the same saved value")

    mock.ShowCharacterFrame(false)
end

--------------------------------------------------------------------------------
section("Character sheet panel: sections (v1.6)")
--------------------------------------------------------------------------------

-- The panel shows everything the Codex window does, picked from icon tabs
-- down its right edge (the Codex's strip needs about twice the panel's
-- width). The Codex's own
-- render methods draw it, running against a surface from Codex:NewSurface -
-- so these check both that every section renders and that the two windows
-- keep their frames, pools, widgets and view state apart.
do
    local Panel = ns:GetModule("CharacterPanel")
    mock.ShowCharacterFrame(true)

    local SECTIONS = { "Gear", "Overview", "Stats", "Rotation", "Cooldowns",
                       "Consumables", "BiS", "Loadouts", "Notes", "Options" }

    check(Panel.surface ~= nil, "the panel owns a Codex rendering surface")
    check(#Panel.frame.sectionTabs == #SECTIONS,
        "there is a side tab for every section", #Panel.frame.sectionTabs)
    for i, sectionName in ipairs(SECTIONS) do
        local tab = Panel.frame.sectionTabs[i]
        check(tab.section == sectionName and Panel.frame.sectionTabByName[sectionName] == tab,
            "tab " .. i .. " is " .. sectionName, tab.section)
        check(tab.icon.texture ~= nil, "and carries an icon", tab.icon.texture)
    end

    -- Nothing may be shared by reference with the Codex's own surface: a
    -- shared pool would have the two windows fighting over the same rows,
    -- and a shared widget would put the panel's Notes text in the Codex's
    -- edit box. This is the __index fallthrough Codex:NewSurface guards
    -- against by listing every field explicitly.
    local function CountShown()
        local n = 0
        for _, pool in pairs({ Panel.rows, Panel.surface.pools.overview, Panel.surface.pools.stats,
                Panel.surface.pools.rotation, Panel.surface.pools.cooldowns,
                Panel.surface.pools.consumables, Panel.surface.pools.bis,
                Panel.surface.pools.options, Panel.surface.statLinePool,
                Panel.surface.bisLinkRowPool, Panel.surface.trinketRowPool,
                Panel.surface.loadoutRowPool, Panel.surface.siteLoadoutRowPool }) do
            for _, row in ipairs(pool) do
                if row:IsShown() then n = n + 1 end
            end
        end
        return n
    end

    -- Every section renders without error, and actually draws something.
    -- Notes is the one exception: it is an edit box, not rows.
    for _, sectionName in ipairs(SECTIONS) do
        local ok, err = pcall(function() Panel:SelectSection(sectionName) end)
        check(ok, "section " .. sectionName .. " renders in the panel without error", err)
        if ok and sectionName ~= "Notes" then
            check(CountShown() > 0, "section " .. sectionName .. " draws rows", CountShown())
        end
    end

    -- Having visited every section, the lazily-built widgets all exist, so
    -- this is the point at which sharing would show up.
    check(Panel.surface.pools ~= Codex.pools, "the panel's row pools are its own")
    check(Panel.surface.scrollChild ~= Codex.scrollChild, "as is its scroll child")
    check(Panel.surface.frame == Panel.frame and Panel.surface.frame ~= Codex.frame,
        "the surface hosts widgets in the panel, not the Codex window")
    check(Panel.surface.notesBox ~= Codex.notesBox, "the Notes box is the panel's own, not the Codex's")
    check(Panel.surface.optionPools ~= Codex.optionPools, "as are the Options widgets")
    check(Panel.surface.bisListToggle ~= Codex.bisListToggle, "and the BiS list toggle")
    check(Panel.surface.suggestedLoadoutRows ~= Codex.suggestedLoadoutRows,
        "and the suggested loadout rows")
    check(Panel.surface.contentWidth == Panel:ContentWidth(),
        "the surface lays rows out at the panel's width, not the Codex's",
        Panel.surface.contentWidth)

    -- Switching sections must clear the previous one: both halves draw into
    -- one scroll child, so leftovers would stack under the new section.
    Panel:SelectSection("Rotation")
    local rotationRows = CountShown()
    Panel:SelectSection("Gear")
    local gearRows = 0
    for _, row in ipairs(Panel.rows) do
        if row:IsShown() then gearRows = gearRows + 1 end
    end
    check(rotationRows > 0 and gearRows > 0, "both sections draw rows of their own")
    check(CountShown() == gearRows, "switching to Gear leaves only the Gear rows shown",
        CountShown() .. " vs " .. gearRows)
    Panel:SelectSection("Overview")
    local shownGear = 0
    for _, row in ipairs(Panel.rows) do
        if row:IsShown() then shownGear = shownGear + 1 end
    end
    check(shownGear == 0, "and switching away from Gear hides its rows", shownGear)

    -- The chosen section is remembered.
    check(ns.db.characterPanel.section == "Overview", "the chosen section is saved",
        ns.db.characterPanel.section)
    mock.ShowCharacterFrame(false)
    mock.ShowCharacterFrame(true)
    check(Panel.frame.sectionLabel:GetText() == "Overview",
        "and restored when the character sheet is reopened", Panel.frame.sectionLabel:GetText())

    -- Clicking a side tab switches section, and only that tab lights up.
    local function ActiveTabs()
        local names = {}
        for _, tab in ipairs(Panel.frame.sectionTabs) do
            if tab.active then names[#names + 1] = tab.section end
        end
        return table.concat(names, ",")
    end
    check(ActiveTabs() == "Overview", "only the active section's tab is lit", ActiveTabs())
    local bisTab = Panel.frame.sectionTabByName.BiS
    bisTab:GetScript("OnClick")(bisTab)
    check(Panel.frame.sectionLabel:GetText() == "BiS", "clicking a side tab switches section",
        Panel.frame.sectionLabel:GetText())
    check(ActiveTabs() == "BiS", "and moves the highlight with it", ActiveTabs())
    check(bisTab.marker:IsShown() and not Panel.frame.sectionTabByName.Overview.marker:IsShown(),
        "the active marker follows the selection")

    -- View state stays per-window: cycling the panel's BiS context must not
    -- move the Codex's, and vice versa.
    local codexBefore = Codex.bisListIndex
    Panel.surface.bisListIndex = 1
    Panel.surface:CycleBiSList()
    check(Panel.surface.bisListIndex ~= 1, "the panel's BiS context cycles",
        Panel.surface.bisListIndex)
    check(Codex.bisListIndex == codexBefore, "without moving the Codex window's")

    -- The footer names the build and the patch the data was written for.
    check((Panel.frame.footer:GetText() or ""):find("patch", 1, true) ~= nil,
        "the footer names the patch the shipped data targets", Panel.frame.footer:GetText())

    -- Event-driven redraws are throttled. Opening the sheet asks for every
    -- item on the section and each answer is its own GET_ITEM_INFO_RECEIVED;
    -- one redraw per event was a forty-redraw freeze on a forty-item list.
    Panel:SelectSection("BiS")
    mock.RunAfter()
    local renders = 0
    local realRender = Panel.Render
    Panel.Render = function(...) renders = renders + 1; return realRender(...) end
    for i = 1, 40 do mock.Fire("GET_ITEM_INFO_RECEIVED", 700000 + i) end
    mock.Fire("PLAYER_EQUIPMENT_CHANGED", 1)
    check(renders == 0, "a burst of item-info events draws nothing synchronously", renders)
    mock.RunAfter()
    check(renders == 1, "and exactly one redraw once the throttle elapses", renders)
    mock.RunAfter()
    check(renders == 1, "with nothing left queued after it", renders)
    -- Hovering a paper doll slot goes through the same throttle.
    Panel:SetHoveredSlot("Head")
    Panel:SetHoveredSlot("Neck")
    check(renders == 1, "hovering slots queues rather than draws", renders)
    mock.RunAfter()
    check(renders == 2 and Panel.hoveredSlot == "Neck", "and draws once for the last hovered slot", renders)
    -- With the sheet closed nothing is queued at all.
    mock.ShowCharacterFrame(false)
    mock.Fire("GET_ITEM_INFO_RECEIVED", 700001)
    mock.RunAfter()
    check(renders == 2, "a closed sheet queues no redraw", renders)
    Panel.Render = realRender

    mock.ShowCharacterFrame(true)
    Panel:SelectSection("Gear")
    mock.ShowCharacterFrame(false)
end

--------------------------------------------------------------------------------
section("Codex: Feedback button")
--------------------------------------------------------------------------------

do
    check(ns.FeedbackURL() == "https://github.com/Sharpened-Banana/WOW-AIO/issues",
        "the feedback URL comes from the TOC's X-Website field", ns.FeedbackURL())
    check(Codex.frame.feedbackButton ~= nil and Codex.frame.feedbackButton:GetText() == "Feedback",
        "the Codex title bar has a Feedback button")

    if Codex:IsShown() then Codex:Toggle() end
    Codex.frame.feedbackButton:GetScript("OnClick")()
    check(Codex:IsShown(), "the Feedback button opens the Codex if it was closed")
    check(Codex.copyDialog:IsShown(), "the Feedback button opens the copy dialog")
    check(Codex.copyBox:GetText() == ns.FeedbackURL(), "the copy dialog holds the feedback URL", Codex.copyBox:GetText())
    check(Codex.copyBox.focused and Codex.copyBox.highlighted, "the URL is focused and selected, ready for Ctrl+C")
    check(Codex.copyLabel:GetText():find("bug reports", 1, true) ~= nil, "the dialog caption says what the link is for",
        Codex.copyLabel:GetText())

    -- The same dialog reverts to its default caption for a loadout copy.
    Codex:ShowCopyDialog("SomeExportString")
    check(Codex.copyLabel:GetText() == "Ctrl+C to copy", "a loadout copy restores the default caption", Codex.copyLabel:GetText())
    Codex.copyDialog:Hide()

    -- Reachable from the Options schema and the slash command too.
    local exposed = false
    for _, group in ipairs(ns.OPTION_GROUPS) do
        for _, entry in ipairs(group.options) do
            if entry.kind == "action" and entry.action == "feedback" then exposed = true end
        end
    end
    check(exposed and ns.OPTION_ACTIONS.feedback ~= nil, "a Feedback action is in ns.OPTION_GROUPS")
    Codex.copyBox:SetText("")
    run("feedback")
    check(Codex.copyBox:GetText() == ns.FeedbackURL(), "/sage feedback shows the same dialog")
    Codex.copyDialog:Hide()
end

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
