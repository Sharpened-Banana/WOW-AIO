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
    "Modules\\BiS.lua",
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
        DRUID = 4, DEMONHUNTER = 2, EVOKER = 3,
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
    check(totalShipped == 39, "exactly 39 shipped specs are registered across all classes", totalShipped)
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
-- 4-entry gear array; opening the Codex there exercises the shipped gear
-- guidance half of the BiS tab against real data.
Codex:Open("MAGE", 9005)
Codex:SelectTab("BiS")
check(Codex.activeTab == "BiS", "SelectTab switches to the BiS tab")
check(CountShownRows(Codex.pools.bis) == 5,
    "the BiS tab renders one row per shipped gear entry plus the checklist header",
    CountShownRows(Codex.pools.bis))

-- MAGE spec 9004 (also registered above) has no gear key at all: the
-- guidance half falls back to the shared NO_DATA line, same as every other
-- tab.
Codex:Open("MAGE", 9004)
Codex:SelectTab("BiS")
check(Codex.pools.bis[1]:IsShown() and Codex.pools.bis[1].text:GetText():find("no guide data", 1, true) ~= nil,
    "a spec with no gear data renders the NO_DATA line", Codex.pools.bis[1].text:GetText())

-- The Add row: cycling the slot button, typing into the editbox, and
-- clicking Add stores a new personal checklist entry for the viewed spec.
local beforeBiSCount = #BiSCodexModule:GetForSpec(9004)
Codex:CycleBiSSlot()
local cycledSlot = Codex.bisSlot
check(Codex.bisButtons.slotButton:GetText() == cycledSlot, "cycling the slot button updates its label", cycledSlot)

Codex.bisItemBox:SetText("A Test BiS Item")
Codex:OnBiSAddClicked()

local afterBiS = BiSCodexModule:GetForSpec(9004)
check(#afterBiS == beforeBiSCount + 1, "the Add row's Add button stores exactly one new entry", #afterBiS)
check(afterBiS[#afterBiS].name == "A Test BiS Item", "the new entry keeps the typed text as its name",
    afterBiS[#afterBiS].name)
check(afterBiS[#afterBiS].slot == cycledSlot, "the new entry uses the cycled slot", afterBiS[#afterBiS].slot)
check(Codex.bisItemBox:GetText() == "", "the editbox clears itself after a successful add")

-- Pressing Enter in the item editbox also adds an entry, not just the Add
-- button.
local beforeEnterCount = #BiSCodexModule:GetForSpec(9004)
Codex.bisItemBox:SetText("Added Via Enter")
Codex.bisItemBox:GetScript("OnEnterPressed")()
check(#BiSCodexModule:GetForSpec(9004) == beforeEnterCount + 1,
    "pressing Enter in the item editbox also adds an entry")

-- Status tags: shown only for the player's own viewed spec (252, per the
-- mock) with a resolvable itemID.
mock.equipped = {}
mock.bags = {}
BiSCodexModule:Add(252, "Head", "55010")
mock.equipped[INVSLOT_HEAD] = 55010

Codex:Open("DEATHKNIGHT", 252)
Codex:SelectTab("BiS")

local ownList = BiSCodexModule:GetForSpec(252)
local ownRow = Codex.bisRowPool[#ownList]
check(ownRow ~= nil, "the checklist row for the player's own spec exists")
check(ownRow.status:GetText() == "equipped", "an equipped item on the player's own spec shows the equipped status tag",
    ownRow.status:GetText())

-- Not the player's own spec: no status tag at all, even with a resolvable
-- itemID.
BiSCodexModule:Add(71, "Head", "55010")
Codex:Open("WARRIOR", 71)
Codex:SelectTab("BiS")
local otherList = BiSCodexModule:GetForSpec(71)
local otherRow = Codex.bisRowPool[#otherList]
check(otherRow ~= nil, "the checklist row for a non-own spec exists")
check(otherRow.status:GetText() == "", "a non-own spec's entry shows no status tag even with an itemID",
    otherRow.status:GetText())

mock.equipped = {}
mock.bags = {}

-- "owned" status also flows through the render-time bag cache (Medium #6:
-- Codex:RenderBiS now builds one BiS:ScanBags() bagSet per render and hands
-- it into GetStatus instead of GetStatus rescanning bags itself per row).
BiSCodexModule:Add(252, "Trinket", "55011")
mock.bags[0] = { [1] = 55011 }
Codex:Open("DEATHKNIGHT", 252)
Codex:SelectTab("BiS")
local ownedList = BiSCodexModule:GetForSpec(252)
local ownedRow = Codex.bisRowPool[#ownedList]
check(ownedRow ~= nil, "the checklist row for the owned-but-not-equipped entry exists")
check(ownedRow.status:GetText() == "in bags",
    "an owned-but-not-equipped item on the player's own spec shows the 'in bags' status tag via the render-time bag cache",
    ownedRow.status:GetText())

mock.equipped = {}
mock.bags = {}

--------------------------------------------------------------------------------
section("Codex: BiS row text width is bounded (Medium #4)")
--------------------------------------------------------------------------------

-- Real item names are short enough to be safe, but a plain-name entry is
-- arbitrary user text with no length limit of its own - without a width
-- bound, a long name draws straight through row.status and
-- row.deleteButton instead of stopping short of them.
check(Codex.bisItemBox.maxLetters == 255,
    "the BiS Add editbox caps input length so a pasted/typed entry cannot be unbounded",
    Codex.bisItemBox.maxLetters)

Codex:Open("MAGE", 9005)
Codex:SelectTab("BiS")
BiSCodexModule:Add(9005, "Trinket", string.rep("Extremely Long Hand-Typed Item Name ", 10))
Codex:SelectTab("BiS") -- re-render so the new row exists in the pool
local longNameList = BiSCodexModule:GetForSpec(9005)
local longNameRow = Codex.bisRowPool[#longNameList]
check(longNameRow ~= nil, "a row exists for the overlong plain-name entry")
check(longNameRow.text:GetWidth() == Codex.scrollChild:GetWidth() - 120,
    "the row's text FontString has a fixed width leaving room for the status tag and Delete button",
    longNameRow.text:GetWidth())

-- Delete is a two-click confirm, same as Loadouts.
Codex:Open("MAGE", 9004)
Codex:SelectTab("BiS")
local deleteCountBefore = #BiSCodexModule:GetForSpec(9004)
local firstRow = Codex.bisRowPool[1]
firstRow.deleteButton:GetScript("OnClick")(firstRow.deleteButton)
check(firstRow.deleteButton.armed == true, "the first Delete click arms the confirm")
check(#BiSCodexModule:GetForSpec(9004) == deleteCountBefore, "the first Delete click does not remove anything yet")
firstRow.deleteButton:GetScript("OnClick")(firstRow.deleteButton)
check(#BiSCodexModule:GetForSpec(9004) == deleteCountBefore - 1, "the second Delete click removes the entry")

-- Hover shows the real item tooltip via GameTooltip:SetItemByID (pcall
-- wrapped), the same shared-tooltip approach rotation/cooldown spell icons
-- use.
Codex:Open("MAGE", 9005)
Codex:SelectTab("BiS")
BiSCodexModule:Add(9005, "Neck", "42")
Codex:SelectTab("BiS") -- re-render to build a row for the entry just added
local hoverRow = Codex.bisRowPool[#BiSCodexModule:GetForSpec(9005)]
check(hoverRow ~= nil, "a row exists for the item-linked entry to hover")
check(pcall(function() hoverRow:GetScript("OnEnter")(hoverRow) end), "hovering a BiS row does not error")
check(GameTooltip.itemID == 42, "hovering a BiS row shows the real item tooltip via SetItemByID", GameTooltip.itemID)
hoverRow:GetScript("OnLeave")(hoverRow)

--------------------------------------------------------------------------------
section("Codex: BiS row updates on GET_ITEM_INFO_RECEIVED (Medium #2)")
--------------------------------------------------------------------------------

-- An itemID the item cache does not know about yet: Add stores the "Item
-- <id>" placeholder (Modules/BiS.lua's ParseItemText), and Modules/BiS.lua's
-- ResolveItemInfo queues a C_Item.RequestLoadItemDataByID call for it.
mock.items[888888] = nil
mock.itemLoadRequests = {}
BiSCodexModule:Add(9005, "Wrist", "888888")
Codex:Open("MAGE", 9005)
Codex:SelectTab("BiS")

local asyncList = BiSCodexModule:GetForSpec(9005)
local asyncRow = Codex.bisRowPool[#asyncList]
check(asyncRow ~= nil, "a row exists for the not-yet-cached entry")
check(asyncRow.text:GetText():find("Item 888888", 1, true) ~= nil,
    "the row shows the placeholder name before the item is cached", asyncRow.text:GetText())

local requestedLoad = false
for _, itemID in ipairs(mock.itemLoadRequests) do
    if itemID == 888888 then requestedLoad = true end
end
check(requestedLoad, "an unresolved entry queues a C_Item.RequestLoadItemDataByID request", mock.itemLoadRequests)

-- The item becomes cached (a test fixture appears, same as the real client
-- caching it server-side) and the client fires GET_ITEM_INFO_RECEIVED for
-- it. The row must update on its own - no explicit re-render, tab switch,
-- or spec switch needed - which is the bug this finding is about: nothing
-- previously listened for this event at all.
mock.items[888888] = { name = "Freshly Cached Wristguard", quality = 3 }
mock.Fire("GET_ITEM_INFO_RECEIVED", 888888)

local updatedRow = Codex.bisRowPool[#asyncList]
check(updatedRow.text:GetText():find("Freshly Cached Wristguard", 1, true) ~= nil,
    "the row's text updates to the real name once GET_ITEM_INFO_RECEIVED fires, with no explicit re-render",
    updatedRow.text:GetText())

-- An item-info event for an itemID that is not on the currently viewed
-- spec's checklist at all must not error and must not touch anything.
check(pcall(function() mock.Fire("GET_ITEM_INFO_RECEIVED", 55) end),
    "GET_ITEM_INFO_RECEIVED for an unrelated itemID does not error")

mock.items[888888] = nil

--------------------------------------------------------------------------------
section("Codex: the BiS Add box does not survive a spec or tab switch (Medium #5)")
--------------------------------------------------------------------------------

-- Mirrors "Codex: notes survive a spec switch" above: clicking a spec-rail
-- button does not clear an EditBox's focus in WoW, so SelectSpec must flush
-- (here: clear, since there is nothing to save) the BiS Add box itself
-- before a later Add can land against the wrong spec.
Codex:Open("WARRIOR", 72)
Codex:SelectTab("BiS")
Codex.bisItemBox:SetText("Half-typed entry meant for Fury (72)")
Codex.bisItemBox:SetFocus()
check(Codex.bisItemBox.focused == true, "sanity: the BiS Add box can be focused while its tab is active")

local specSwitchAddCountBefore = #BiSCodexModule:GetForSpec(71)
Codex:SelectSpec(71) -- Arms: a different spec, same class, BiS tab stays open
check(Codex.bisItemBox:GetText() == "", "switching spec clears the half-typed BiS Add box")
check(Codex.bisItemBox.focused == false, "switching spec also clears the BiS Add box's focus")

Codex:OnBiSAddClicked() -- the box is now empty; must be a silent no-op (Low #11)
check(#BiSCodexModule:GetForSpec(71) == specSwitchAddCountBefore,
    "the emptied box after a spec switch adds nothing to the newly selected spec")

-- Same guarantee for a tab switch away from BiS (not just a spec switch).
Codex:Open("WARRIOR", 72)
Codex:SelectTab("BiS")
Codex.bisItemBox:SetText("Half-typed entry, tab switch this time")
Codex:SelectTab("Notes")
check(Codex.bisItemBox:GetText() == "", "switching tab away from BiS clears the half-typed Add box")

-- The one-line notesBox fix from the same finding: HideOtherTabWidgets now
-- clears focus before hiding self.notesBox too, not just self.bisItemBox.
Codex:SelectTab("Notes")
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
section("Codex: Suggested Mythic+ loadout row (v1.2)")
--------------------------------------------------------------------------------

-- Inline fixture guides on scratch specIDs (the >=9000 convention used
-- throughout this suite), registered here rather than relying on any real
-- shipped Guides_*.lua content - two other agents are concurrently adding
-- mplusLoadout data to those files, so this section must not race with them.
GuideStore:RegisterSpec("WARRIOR", 9201, {
    specName = "Loadout Warrior",
    role = "DAMAGER",
    mplusLoadout = {
        string = "C0EAy0kSampleExportStringFromSimC",
        source = "SimulationCraft default profile (credit, not endorsement of 'best')",
        patch = "12.1",
    },
})
GuideStore:RegisterSpec("WARRIOR", 9202, { specName = "No Loadout Warrior", role = "DAMAGER" })

-- Present: the extra row renders above the saved-loadout list, labeled per
-- DESIGN.md, with both buttons shown.
Codex:Open("WARRIOR", 9201)
Codex:SelectTab("Loadouts")
check(Codex.suggestedLoadoutRow:IsShown(), "the suggested row is shown for a spec whose guide ships mplusLoadout")
check(Codex.suggestedLoadoutRow.name:GetText() == "Suggested Mythic+ (via SimulationCraft, patch 12.1)",
    "the suggested row is labeled per DESIGN.md, including the guide's patch",
    Codex.suggestedLoadoutRow.name:GetText())
check(Codex.suggestedLoadoutRow.copyButton:IsShown(), "the suggested row's Copy button is shown")
check(Codex.suggestedLoadoutRow.addButton:IsShown(), "the suggested row's Add to my vault button is shown")
check(Codex.suggestedLoadoutRow.addButton:GetText() == "Add to my vault",
    "the suggested row's Add button is labeled 'Add to my vault'", Codex.suggestedLoadoutRow.addButton:GetText())

-- Absent: no placeholder text, the row simply doesn't render (per DESIGN.md).
Codex:Open("WARRIOR", 9202)
Codex:SelectTab("Loadouts")
check(not Codex.suggestedLoadoutRow:IsShown(),
    "the suggested row is hidden entirely for a spec whose guide has no mplusLoadout")

-- Copy: same read-only highlighted-editbox pattern as a saved loadout's
-- Copy, and the same Show-before-focus ordering the mock enforces via
-- IsEffectivelyShown (see the saved-loadout Copy test above) - a reordering
-- mistake here would error under the mock instead of silently copying
-- nothing.
Codex:Open("WARRIOR", 9201)
Codex:SelectTab("Loadouts")
local suggestedCopyOk = pcall(function() Codex.suggestedLoadoutRow.copyButton:GetScript("OnClick")() end)
check(suggestedCopyOk, "Copy on the suggested row does not error under the mock's visibility-checked SetFocus")
check(Codex.copyDialog:IsShown(), "Copy on the suggested row opens the copy dialog")
check(Codex.copyBox:GetText() == "C0EAy0kSampleExportStringFromSimC",
    "the copy dialog is populated with the suggested loadout's export string, not a saved loadout's",
    Codex.copyBox:GetText())
check(Codex.copyBox.focused == true, "the copy box is focused for the suggested row's string")
check(Codex.copyBox.highlighted == true, "the copy box's text is highlighted for the suggested row's string")

-- Add to my vault: calls Loadouts:Add with the exact arguments DESIGN.md
-- specifies, never touching SpecSageDB before the click, and gives a brief
-- confirmation via a temporary label change that reverts on its own.
local vaultCountBefore = #LoadoutsModule:GetForSpec(9201)
Codex.suggestedLoadoutRow.addButton:GetScript("OnClick")(Codex.suggestedLoadoutRow.addButton)

local vaultAfter = LoadoutsModule:GetForSpec(9201)
check(#vaultAfter == vaultCountBefore + 1, "Add to my vault stores exactly one new loadout", #vaultAfter)
check(vaultAfter[#vaultAfter].name == "Suggested M+ (SimC)",
    "the added loadout uses the exact name DESIGN.md specifies", vaultAfter[#vaultAfter].name)
check(vaultAfter[#vaultAfter].category == "Mythic+",
    "the added loadout uses the exact category DESIGN.md specifies", vaultAfter[#vaultAfter].category)
check(vaultAfter[#vaultAfter].export == "C0EAy0kSampleExportStringFromSimC",
    "the added loadout keeps the guide's mplusLoadout.string as its export", vaultAfter[#vaultAfter].export)
check(Codex.suggestedLoadoutRow.addButton:GetText() == "Added!",
    "clicking Add to my vault gives a brief confirmation via a temporary label change",
    Codex.suggestedLoadoutRow.addButton:GetText())

mock.RunAfter()
check(Codex.suggestedLoadoutRow.addButton:GetText() == "Add to my vault",
    "the confirmation label reverts to 'Add to my vault' after the timer",
    Codex.suggestedLoadoutRow.addButton:GetText())

-- Clicking Add to my vault a second time adds a second entry rather than
-- silently no-oping - it is a plain Loadouts:Add call, not a toggle.
Codex.suggestedLoadoutRow.addButton:GetScript("OnClick")(Codex.suggestedLoadoutRow.addButton)
check(#LoadoutsModule:GetForSpec(9201) == vaultCountBefore + 2,
    "clicking Add to my vault again stores a second loadout")
mock.RunAfter()

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
section("Codex: close")
--------------------------------------------------------------------------------

if not Codex:IsShown() then Codex:Toggle() end
check(Codex:IsShown() == true, "Codex is shown before the final close check")
Codex:Toggle()
check(Codex:IsShown() == false, "Toggle closes the Codex")

--------------------------------------------------------------------------------

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
