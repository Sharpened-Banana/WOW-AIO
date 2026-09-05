local _, ns = ...

-- Item IDs for every consumable the shipped guides name in their
-- `consumables` prose (Data/Guides_*.lua). The guide text stays prose - it
-- explains *why* one flask over another - and the Codex's Consumables tab
-- scans each line for these names and lays hoverable, clickable item chips
-- under it, so the reader can see the real tooltip instead of taking the
-- guide's word for it. A name not in this table simply gets no chip.
--
-- Rank-3 crafted item where a recipe has quality ranks (the tooltip shows
-- the rank stars). IDs looked up on Wowhead 2026-09-05; the names are
-- matched case-sensitively and whole, longest first, so "Flask of Tempered
-- Swiftness" never claims a shorter name's chip.
ns.ConsumableItems = {
    ["Flask of Tempered Swiftness"] = 212274,
    ["Flask of Tempered Aggression"] = 212271,
    ["Flask of Tempered Mastery"] = 212280,
    ["Flask of Tempered Versatility"] = 212277,
    ["Flask of Alchemical Chaos"] = 212283,
    ["Flask of Saving Graces"] = 212301,
    ["Loa's Gathering"] = 275265,
    ["Feast of Knowledge"] = 275266,
    ["Hearty Venom-Spiced Cutlets"] = 275259,
    ["Puffer Plate"] = 275260,
    ["Liquid Luster"] = 271887,
    ["Potion of Unwavering Focus"] = 212259,
    ["Tempered Potion"] = 212265,
    ["Concentrated Silvermoon Health Potion"] = 271884,
    ["Ironclaw Whetstone"] = 222504,
    ["Shadowcore Oil"] = 171285,
    ["Crystallized Augment Rune"] = 224572,
    ["Ethereal Augment Rune"] = 243191,
}

-- Names sorted longest first, built once.
local ordered
local function OrderedNames()
    if ordered then return ordered end
    ordered = {}
    for name in pairs(ns.ConsumableItems) do ordered[#ordered + 1] = name end
    table.sort(ordered, function(a, b)
        if #a ~= #b then return #a > #b end
        return a < b
    end)
    return ordered
end

-- The consumables a line of guide prose names, in the order they appear,
-- each once: { { name = ..., itemID = ... }, ... }. Plain (non-pattern)
-- find, so apostrophes and hyphens in names are safe.
function ns.FindConsumableItems(text)
    local found = {}
    if type(text) ~= "string" or text == "" then return found end
    local claimed = {}
    for _, name in ipairs(OrderedNames()) do
        local start = text:find(name, 1, true)
        while start do
            local finish = start + #name - 1
            local overlaps = false
            for _, span in ipairs(claimed) do
                if start <= span[2] and finish >= span[1] then overlaps = true break end
            end
            if not overlaps then
                claimed[#claimed + 1] = { start, finish, name }
            end
            start = text:find(name, finish + 1, true)
        end
    end
    table.sort(claimed, function(a, b) return a[1] < b[1] end)
    local seen = {}
    for _, span in ipairs(claimed) do
        local name = span[3]
        if not seen[name] then
            seen[name] = true
            found[#found + 1] = { name = name, itemID = ns.ConsumableItems[name] }
        end
    end
    return found
end
