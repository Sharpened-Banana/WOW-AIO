-- Modules/BiS.lua
-- The personal "Best in Slot" checklist: player-curated gear entries per
-- spec, tracked live against the player's own equipped gear and bags. This
-- is deliberately separate from a guide's shipped `gear` guidance (validated
-- by Data/API.lua) — the player builds this list themselves from whatever
-- source they trust; see DESIGN.md's "BiS / Gear (v1.1)" section.
--
-- Frame-free (see Core/Init.lua's module conventions), same as
-- Modules/Loadouts.lua and Modules/Notes.lua — the Codex's BiS tab is the
-- only caller.

local ADDON, ns = ...

-- Reached only via ns:GetModule("BiS"); no separate ns.BiS alias, matching
-- Modules/Loadouts.lua's and Modules/Notes.lua's equivalent note.
local BiS = ns:NewModule("BiS")

-- The same 14-slot vocabulary Data/API.lua validates a guide's `gear` array
-- against. Kept as its own copy rather than reaching into ns.GuideStore's
-- internals, the same independence Modules/Loadouts.lua's VALID_CATEGORIES
-- has from the rest of the addon. Ordered for UI cycling (the Codex's Add
-- row slot-cycler button), the same role Loadouts.CATEGORY_ORDER plays.
BiS.SLOT_ORDER = {
    "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist",
    "Legs", "Feet", "Ring", "Trinket", "Weapon", "Off-hand",
}

local VALID_SLOTS = {}
for _, slot in ipairs(BiS.SLOT_ORDER) do
    VALID_SLOTS[slot] = true
end
BiS.VALID_SLOTS = VALID_SLOTS

-- Ring and Trinket each cover two inventory slots; Weapon fans out to both
-- the main-hand and off-hand slots (the shipped gear guidance itself tells
-- dual-wield specs to list two weapons under "Weapon" - see e.g.
-- Guides_Warrior.lua's Fury entry - so checking only INVSLOT_MAINHAND left
-- one of those two always reporting "missing" while visibly equipped).
-- Off-hand stays mapped to INVSLOT_OFFHAND alone: a shield/held-in-off-hand
-- entry filed under "Off-hand" is still correct, and an item sitting in 17
-- legitimately satisfies either "Weapon" or "Off-hand".
--
-- Built from the real INVSLOT_* globals (with a numeric fallback for a
-- client that somehow does not expose them) rather than bare literals, so a
-- wrong number here becomes a naming mismatch against tests/wow_mock.lua's
-- own independently-defined INVSLOT_* constants instead of a
-- self-consistent tautology (see tests/run.lua's "GetStatus covers every
-- inventory slot" section).
local SLOT_INVENTORY_IDS = {
    Head = { INVSLOT_HEAD or 1 },
    Neck = { INVSLOT_NECK or 2 },
    Shoulder = { INVSLOT_SHOULDER or 3 },
    Back = { INVSLOT_BACK or 15 },
    Chest = { INVSLOT_CHEST or 5 },
    Wrist = { INVSLOT_WRIST or 9 },
    Hands = { INVSLOT_HAND or 10 },
    Waist = { INVSLOT_WAIST or 6 },
    Legs = { INVSLOT_LEGS or 7 },
    Feet = { INVSLOT_FEET or 8 },
    Ring = { INVSLOT_FINGER1 or 11, INVSLOT_FINGER2 or 12 },
    Trinket = { INVSLOT_TRINKET1 or 13, INVSLOT_TRINKET2 or 14 },
    Weapon = { INVSLOT_MAINHAND or 16, INVSLOT_OFFHAND or 17 },
    ["Off-hand"] = { INVSLOT_OFFHAND or 17 },
}

-- Retail API fallback chains, captured once at load time (same pattern as
-- Modules/Loadouts.lua's GetSpecialization/GetSpecializationInfo).
local GetItemInfoAPI = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetInventoryItemIDAPI = GetInventoryItemID
local GetContainerNumSlotsAPI = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local GetContainerItemIDAPI = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID
-- No plain-global fallback: RequestLoadItemDataByID only ever existed under
-- C_Item. A client without it (or without C_Item at all) simply gets no
-- proactive load request - GetItemInfo may still resolve on its own once the
-- server hands the data over some other way, and ResolveDisplay keeps
-- re-checking on every render regardless.
local RequestLoadItemDataByIDAPI = C_Item and C_Item.RequestLoadItemDataByID

local function Trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Asks the client to fetch an uncached item's data from the server, pcall
-- wrapped and guarded the same way every other real-client call in this
-- module is: a bad itemID or a missing API must never take the Codex down.
-- Fire-and-forget - Codex:OnBiSItemInfoReceived (UI/Codex.lua) is what
-- actually re-renders once GET_ITEM_INFO_RECEIVED tells us the request
-- resolved.
local function RequestItemLoad(itemID)
    if not RequestLoadItemDataByIDAPI or type(itemID) ~= "number" then return end
    pcall(RequestLoadItemDataByIDAPI, itemID)
end

-- pcall-wrapped: GetItemInfo is genuinely allowed to return nil for an item
-- the client has not cached yet (a fresh itemID lookup can be async), so "no
-- name yet" is a normal outcome here, not an error. When that happens, queue
-- a load request so the async fetch actually gets kicked off rather than the
-- addon merely hoping some other code path already triggered one - see
-- DESIGN.md's "BiS / Gear (v1.1)" note on GetItemInfo being genuinely async.
local function ResolveItemInfo(itemID)
    if not GetItemInfoAPI or type(itemID) ~= "number" then return nil, nil end
    local ok, name, _, quality = pcall(GetItemInfoAPI, itemID)
    if not ok then return nil, nil end
    if type(name) ~= "string" or name == "" then
        RequestItemLoad(itemID)
        return nil, nil
    end
    return name, quality
end

-- Parses whatever the Add editbox was given: a pasted item link, a bare
-- numeric itemID, or a plain name with no ID at all. Returns itemID (number
-- or nil) and the best name available right now.
local function ParseItemText(text)
    -- Item link: |cffxxxxxx|Hitem:12345:...|h[Item Name]|h|r. The colour
    -- prefix and the trailing |h|r are not required to match — only the
    -- itemID and the bracketed display name matter.
    local linkID, linkName = text:match("Hitem:(%d+):.-|h%[(.-)%]")
    if linkID then
        local itemID = tonumber(linkID)
        local name = linkName
        if not name or name == "" then
            name = ResolveItemInfo(itemID)
        end
        return itemID, name
    end

    if text:match("^%d+$") then
        local itemID = tonumber(text)
        local name = ResolveItemInfo(itemID)
        -- A fresh itemID the client has not cached yet resolves to no name
        -- at all; still list it (per DESIGN.md), and BiS:ResolveDisplay
        -- picks up the real name lazily once it becomes available.
        return itemID, name or ("Item " .. itemID)
    end

    -- Plain name: no itemID, so GetStatus can never report more than
    -- "missing" for it, but it is still listed per DESIGN.md.
    return nil, text
end

--------------------------------------------------------------------------------
-- Storage: SpecSageDB.bis[specID] = { {slot=, itemID=, name=, note=}, ... }
--------------------------------------------------------------------------------

-- Returns the saved BiS entries for a spec, oldest first. Same live-table
-- (once one exists) or fresh-empty-table contract as Loadouts:GetForSpec, so
-- reading a spec with nothing saved never creates clutter in the DB.
function BiS:GetForSpec(specID)
    if type(specID) ~= "number" then return {} end
    return ns.db.bis[specID] or {}
end

-- Adds a checklist entry. Returns false plus a reason on bad input rather
-- than erroring, the same validate-and-skip contract Data/API.lua and
-- Modules/Loadouts.lua use, so a bad Add-row entry cannot take the addon
-- down. `itemText` may be a pasted item link, a bare numeric itemID, or a
-- plain name (see ParseItemText above).
function BiS:Add(specID, slot, itemText, note)
    if type(specID) ~= "number" then
        return false, "specID must be a number"
    end
    if type(slot) ~= "string" or not VALID_SLOTS[slot] then
        return false, "slot must be a valid gear slot"
    end
    if type(itemText) ~= "string" or Trim(itemText) == "" then
        return false, "itemText must be a non-empty string"
    end
    if note ~= nil and type(note) ~= "string" then
        return false, "note must be a string"
    end

    local itemID, name = ParseItemText(Trim(itemText))
    if type(name) ~= "string" or Trim(name) == "" then
        return false, "could not determine an item name"
    end

    local list = ns.db.bis[specID]
    if not list then
        list = {}
        ns.db.bis[specID] = list
    end

    local entry = { slot = slot, itemID = itemID, name = Trim(name) }
    if note and Trim(note) ~= "" then
        entry.note = Trim(note)
    end

    list[#list + 1] = entry
    return true, entry
end

-- Deletes the entry at `index` (1-based, in the order GetForSpec returns)
-- for `specID`. Same false-rather-than-error contract as Loadouts:Delete for
-- an out-of-range index or a spec with nothing saved.
function BiS:Delete(specID, index)
    local list = ns.db.bis[specID]
    if type(list) ~= "table" or type(index) ~= "number" then
        return false
    end
    if not list[index] then
        return false
    end
    table.remove(list, index)
    return true
end

-- Re-resolves an entry's display name against the item cache and returns it
-- alongside the item's quality (for the Codex's quality-coloured text).
-- GetItemInfo can be genuinely async — the server hands back nil until the
-- client has cached the item — so this re-resolves on every call rather than
-- once at Add time: an entry added while its item was uncached still picks
-- up the real name and colour once it becomes available, with no user
-- action needed. A plain-name entry (no itemID) has nothing to resolve and
-- is returned as-is.
function BiS:ResolveDisplay(entry)
    if type(entry) ~= "table" then return nil, nil end

    if entry.itemID then
        local name, quality = ResolveItemInfo(entry.itemID)
        if type(name) == "string" and name ~= "" then
            entry.name = name
        end
        return entry.name, quality
    end

    return entry.name, nil
end

-- Builds a { [itemID] = true } set of every item sitting in bags 0-4
-- (backpack plus the four bag slots; bank/reagent bags are out of scope for
-- "do I already own this to go equip it"), in one pass. A checklist render
-- with N rows used to call GetStatus per row, each of which rescanned all
-- five bags itself - up to ~14 x 5 x 36 container reads on a full checklist,
-- every render. Codex:RenderBiS now calls this once per render and passes
-- the result into GetStatus below instead. Pcall-wrapped, same as the scan
-- it replaces: a client without C_Container, or one where a read throws
-- mid-scan, degrades to an empty set (every row falls through to "missing")
-- rather than an error.
function BiS:ScanBags()
    local bagSet = {}
    if not (GetContainerNumSlotsAPI and GetContainerItemIDAPI) then return bagSet end

    pcall(function()
        for bag = 0, 4 do
            local numSlots = GetContainerNumSlotsAPI(bag) or 0
            for slotIndex = 1, numSlots do
                local itemID = GetContainerItemIDAPI(bag, slotIndex)
                if itemID then bagSet[itemID] = true end
            end
        end
    end)

    return bagSet
end

-- Returns "equipped", "owned" (in bags), or "missing" for a checklist entry,
-- or nil when the entry has no itemID to check at all (a plain-name entry
-- can never be more specific than that). Every game-API call is
-- pcall-wrapped: a client without C_Container, or one where a bag/inventory
-- read throws mid-scan, degrades to "missing" rather than taking the Codex
-- down. Equipped is checked before owned, so an item that is both equipped
-- and (for whatever reason) also sitting in a bag still reports as equipped.
--
-- `bagSet`, when given, is a precomputed BiS:ScanBags() result: pass one in
-- when checking many entries in the same render pass (Codex:RenderBiS does)
-- so the bag scan happens once rather than once per row. Omit it (or pass
-- nil) to fall back to scanning bags right here for this one entry - keeps
-- GetStatus independently callable/testable without a caller having to build
-- a bagSet first.
function BiS:GetStatus(entry, bagSet)
    if type(entry) ~= "table" or type(entry.itemID) ~= "number" then
        return nil
    end

    local invSlots = SLOT_INVENTORY_IDS[entry.slot]
    if invSlots and GetInventoryItemIDAPI then
        local ok, equipped = pcall(function()
            for _, invSlot in ipairs(invSlots) do
                if GetInventoryItemIDAPI("player", invSlot) == entry.itemID then
                    return true
                end
            end
            return false
        end)
        if ok and equipped then return "equipped" end
    end

    if type(bagSet) == "table" then
        return bagSet[entry.itemID] and "owned" or "missing"
    end

    if GetContainerNumSlotsAPI and GetContainerItemIDAPI then
        local ok, owned = pcall(function()
            -- Backpack (0) plus the four bag slots (1-4); bank/reagent bags
            -- are out of scope for "do I already own this to go equip it".
            for bag = 0, 4 do
                local numSlots = GetContainerNumSlotsAPI(bag) or 0
                for slotIndex = 1, numSlots do
                    if GetContainerItemIDAPI(bag, slotIndex) == entry.itemID then
                        return true
                    end
                end
            end
            return false
        end)
        if ok and owned then return "owned" end
    end

    return "missing"
end
