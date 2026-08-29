-- Modules/Loadouts.lua
-- The talent loadout vault: save, label, import and export talent strings
-- per spec. This module is a plain data API deliberately kept frame-free
-- (see Core/Init.lua's module conventions) so it is fully testable without
-- the Codex UI, which is the only thing that calls it.

local ADDON, ns = ...

local Loadouts = ns:NewModule("Loadouts")
ns.Loadouts = Loadouts

-- These moved into C_SpecializationInfo in modern retail but the globals are
-- still around; prefer the namespaced versions when present (same pattern as
-- Modules/Stats.lua's GetPrimaryStatIndex).
local GetSpecialization = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
local GetSpecializationInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo

local VALID_CATEGORIES = {
    Raid = true, ["Mythic+"] = true, Delves = true, PvP = true, Other = true,
}
Loadouts.VALID_CATEGORIES = VALID_CATEGORIES

-- Ordered for UI cycling (e.g. a category-picker button in the Codex).
Loadouts.CATEGORY_ORDER = { "Raid", "Mythic+", "Delves", "PvP", "Other" }

local function Trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

--------------------------------------------------------------------------------
-- Storage: SpecSageDB.loadouts[specID] = { {name=, category=, export=}, ... }
--------------------------------------------------------------------------------

-- Returns the saved loadouts for a spec, oldest first. The array returned is
-- the live saved-variable table when one exists (so index-based Delete stays
-- in sync with what was just listed) or a fresh empty table when it does not
-- — reading a spec with nothing saved must never create clutter in the DB.
function Loadouts:GetForSpec(specID)
    if type(specID) ~= "number" then return {} end
    return ns.db.loadouts[specID] or {}
end

-- Adds a loadout, validating input the way Data/API.lua validates guide data:
-- return false plus a reason on bad input, never error, so a bad dialog entry
-- cannot take the addon down. `category` falls back to "Other" rather than
-- being rejected, since it is a convenience field, not one worth blocking on.
function Loadouts:Add(specID, name, category, exportString)
    if type(specID) ~= "number" then
        return false, "specID must be a number"
    end

    if type(name) ~= "string" or Trim(name) == "" then
        return false, "name must be a non-empty string"
    end

    if type(exportString) ~= "string" or Trim(exportString) == "" then
        return false, "exportString must be a non-empty string"
    end

    if type(category) ~= "string" or not VALID_CATEGORIES[category] then
        category = "Other"
    end

    local list = ns.db.loadouts[specID]
    if not list then
        list = {}
        ns.db.loadouts[specID] = list
    end

    local entry = { name = Trim(name), category = category, export = exportString }
    list[#list + 1] = entry
    return true, entry
end

-- Deletes the loadout at `index` (1-based, in the order GetForSpec returns)
-- for `specID`. Returns false rather than erroring for an out-of-range index
-- or a spec with nothing saved, so a stale UI reference cannot throw.
function Loadouts:Delete(specID, index)
    local list = ns.db.loadouts[specID]
    if type(list) ~= "table" or type(index) ~= "number" then
        return false
    end
    if not list[index] then
        return false
    end
    table.remove(list, index)
    return true
end

--------------------------------------------------------------------------------
-- Current character / talents
--------------------------------------------------------------------------------

-- The specialization ID the player is currently playing, or nil if unknown
-- (e.g. no spec chosen yet, very low level). Shared by the Codex to decide
-- whether "Save current" / live stat values apply to the spec being viewed.
function Loadouts:GetCurrentSpecID()
    local spec = GetSpecialization and GetSpecialization()
    if not spec then return nil end

    local ok, specID = pcall(GetSpecializationInfo, spec)
    if not ok then return nil end
    return specID
end

-- Reads an export string for the player's active talent loadout. Retail's
-- talent export surface has moved between API names across patches, so this
-- tries each in turn and is fully pcall-wrapped: a client without any of
-- these (or a temporary API hiccup) must return nil, not error.
function Loadouts:ExportCurrent()
    if not C_ClassTalents or not C_ClassTalents.GetActiveConfigID then
        return nil
    end

    local ok, configID = pcall(C_ClassTalents.GetActiveConfigID)
    if not ok or not configID then return nil end

    if not C_Traits then return nil end

    for _, fnName in ipairs({ "GenerateImportString", "GenerateInspectImportString" }) do
        local fn = C_Traits[fnName]
        if fn then
            local callOk, result = pcall(fn, configID)
            if callOk and type(result) == "string" and result ~= "" then
                return result
            end
        end
    end

    return nil
end
