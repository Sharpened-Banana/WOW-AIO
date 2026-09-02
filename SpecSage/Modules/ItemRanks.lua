-- Modules/ItemRanks.lua
-- Stat ranks on item tooltips: every item tooltip in the game gets a line
-- ranking the item's secondary stats (#1, #2, ...) against the player's
-- current spec's Codex stat priority, so "is Haste/Versatility good for me?"
-- is answered on the item itself rather than by alt-tabbing to the Codex.
-- See DESIGN.md's "Item stat ranks (v1.5)" section.
--
-- Frame-free (Core/Init.lua's module conventions): the only thing this
-- module touches at runtime is the tooltip it is handed.

local ADDON, ns = ...

local ItemRanks = ns:NewModule("ItemRanks")

-- Item stat keys (as returned by C_Item.GetItemStats / GetItemStats) -> the
-- Data/API.lua statPriority vocabulary. Only stats a guide can rank appear
-- here; primary stat, stamina and armor are on every piece for its slot and
-- rank nothing against anything. ITEM_MOD_VERSATILITY has no _SHORT suffix
-- in the client's own key naming; both spellings are listed to be safe.
ItemRanks.STAT_KEYS = {
    ITEM_MOD_CRIT_RATING_SHORT = "crit",
    ITEM_MOD_HASTE_RATING_SHORT = "haste",
    ITEM_MOD_MASTERY_RATING_SHORT = "mastery",
    ITEM_MOD_VERSATILITY = "versatility",
    ITEM_MOD_VERSATILITY_SHORT = "versatility",
    ITEM_MOD_CR_LIFESTEAL_SHORT = "leech",
    ITEM_MOD_CR_AVOIDANCE_SHORT = "avoidance",
    ITEM_MOD_CR_SPEED_SHORT = "speed",
}

-- Which statPriority entries count towards a rank: the same set as
-- STAT_KEYS' values. A guide that lists primary first (most do) still ranks
-- Haste as "#1 of 4" rather than "#2 of 5".
local RANKABLE = {
    crit = true, haste = true, mastery = true, versatility = true,
    leech = true, avoidance = true, speed = true,
}

local STAT_LABELS = {
    crit = "Crit", haste = "Haste", mastery = "Mastery", versatility = "Versatility",
    leech = "Leech", avoidance = "Avoidance", speed = "Speed",
}

-- Rank colours, #1 (best) downwards. Anything past the table's end reuses
-- the last entry.
local RANK_COLORS = {
    { 0.20, 0.90, 0.20 },
    { 0.70, 0.90, 0.20 },
    { 0.95, 0.85, 0.20 },
    { 0.95, 0.55, 0.20 },
}

local GetItemStatsAPI = (C_Item and C_Item.GetItemStats) or GetItemStats

--------------------------------------------------------------------------------
-- Pure logic (testable without a tooltip)
--------------------------------------------------------------------------------

-- The rank of each rankable stat for a spec, from its guide's statPriority:
-- { haste = 1, crit = 2, ... } plus the total count, or nil when the spec has
-- no guide or its priority names no rankable stat at all.
function ItemRanks:GetRankTable(specID)
    local guide = specID and ns.GuideStore and ns.GuideStore:GetGuide(specID)
    local priority = guide and guide.statPriority
    if type(priority) ~= "table" then return nil end

    local ranks, count = {}, 0
    for _, entry in ipairs(priority) do
        local stat = type(entry) == "table" and entry.stat
        if stat and RANKABLE[stat] and not ranks[stat] then
            count = count + 1
            ranks[stat] = count
        end
    end
    if count == 0 then return nil end
    return ranks, count
end

-- Reads an item's rankable secondary stats off its link: { haste = 512,
-- versatility = 380 }, or nil when the client cannot read stats for it (an
-- uncached item, no API, or a link that is not an item).
function ItemRanks:GetItemSecondaries(link)
    if not GetItemStatsAPI or type(link) ~= "string" then return nil end
    local ok, stats = pcall(GetItemStatsAPI, link)
    if not ok or type(stats) ~= "table" then return nil end

    local found, any = {}, false
    for key, value in pairs(stats) do
        local stat = self.STAT_KEYS[key]
        if stat and type(value) == "number" and value > 0 then
            found[stat] = value
            any = true
        end
    end
    if not any then return nil end
    return found
end

-- The lines to append for `link` on `specID`: an ordered array of
-- { stat, label, rank, count, r, g, b }, best rank first, or nil when there
-- is nothing to say (no guide, or the item carries no ranked stat).
function ItemRanks:Describe(link, specID)
    local ranks, count = self:GetRankTable(specID)
    if not ranks then return nil end

    local secondaries = self:GetItemSecondaries(link)
    if not secondaries then return nil end

    local lines = {}
    for stat in pairs(secondaries) do
        local rank = ranks[stat]
        if rank then
            local color = RANK_COLORS[math.min(rank, #RANK_COLORS)]
            lines[#lines + 1] = {
                stat = stat, label = STAT_LABELS[stat] or stat,
                rank = rank, count = count,
                r = color[1], g = color[2], b = color[3],
            }
        else
            -- On the item but absent from the guide's priority: still worth
            -- saying so, ranked last so the reader knows it was considered.
            lines[#lines + 1] = {
                stat = stat, label = STAT_LABELS[stat] or stat,
                rank = nil, count = count, r = 0.6, g = 0.6, b = 0.6,
            }
        end
    end
    if #lines == 0 then return nil end

    table.sort(lines, function(a, b)
        if a.rank and b.rank then return a.rank < b.rank end
        if a.rank then return true end
        if b.rank then return false end
        return a.label < b.label
    end)
    return lines
end

--------------------------------------------------------------------------------
-- Tooltip hook
--------------------------------------------------------------------------------

local function PlayerSpecID()
    local Loadouts = ns:GetModule("Loadouts")
    return Loadouts and Loadouts:GetCurrentSpecID() or nil
end

local function SpecName(specID)
    local guide = ns.GuideStore and ns.GuideStore:GetGuide(specID)
    return (guide and guide.specName) or ("spec " .. tostring(specID))
end

-- Appends the rank lines to `tooltip` for the item link `link`. Public so a
-- test can drive it directly; every real-client call inside is pcall-wrapped
-- so a tooltip that lacks some method cannot error out of the game's own
-- tooltip pipeline (which would break every item tooltip, not just ours).
function ItemRanks:Annotate(tooltip, link)
    if not ns.db or not ns.db.itemStatRanks then return false end
    if not tooltip or type(link) ~= "string" then return false end

    local specID = PlayerSpecID()
    local lines = self:Describe(link, specID)
    if not lines then return false end

    local header = format("SpecSage stat ranks (%s):", SpecName(specID))
    local parts = {}
    for _, line in ipairs(lines) do
        local rankText = line.rank and format("#%d of %d", line.rank, line.count) or "unranked"
        parts[#parts + 1] = format("|cff%02x%02x%02x%s %s|r",
            math.floor(line.r * 255 + 0.5), math.floor(line.g * 255 + 0.5), math.floor(line.b * 255 + 0.5),
            line.label, rankText)
    end

    local ok = pcall(function()
        tooltip:AddLine(" ")
        tooltip:AddLine(header, 0.776, 0.608, 0.427)
        tooltip:AddLine(table.concat(parts, "  "), 1, 1, 1)
        if tooltip.Show then tooltip:Show() end
    end)
    return ok
end

-- Resolves the item link a tooltip is currently showing. GetItem returns
-- name, link on every tooltip that has an item set; the TooltipDataProcessor
-- `data` argument (modern clients) carries a hyperlink too, checked first
-- since GetItem has been unreliable inside post-calls on some builds.
local function LinkFromTooltip(tooltip, data)
    if type(data) == "table" and type(data.hyperlink) == "string" then
        return data.hyperlink
    end
    if tooltip and tooltip.GetItem then
        local ok, _, link = pcall(tooltip.GetItem, tooltip)
        if ok and type(link) == "string" then return link end
    end
    return nil
end

local function OnTooltipItem(tooltip, data)
    local link = LinkFromTooltip(tooltip, data)
    if not link then return end
    ItemRanks:Annotate(tooltip, link)
end

function ItemRanks:OnEnable()
    if self.hooked then return end

    -- Modern clients (10.0.2+): one post-call covers GameTooltip, the
    -- ItemRefTooltip that opens on a clicked link, and the shopping/compare
    -- tooltips alike. Older clients: hook the two tooltips that matter.
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        local ok = pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, OnTooltipItem)
        if ok then
            self.hooked = "TooltipDataProcessor"
            return
        end
    end

    for _, name in ipairs({ "GameTooltip", "ItemRefTooltip" }) do
        local tooltip = _G[name]
        if tooltip and tooltip.HookScript then
            pcall(tooltip.HookScript, tooltip, "OnTooltipSetItem", function(self2)
                OnTooltipItem(self2, nil)
            end)
            self.hooked = "OnTooltipSetItem"
        end
    end
end
