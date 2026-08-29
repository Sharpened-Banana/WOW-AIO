-- Modules/Notes.lua
-- Free-text personal notes, saved per spec. Deliberately tiny and frame-free
-- (see Core/Init.lua's module conventions) — the Codex's Notes tab is the
-- only caller.

local ADDON, ns = ...

local Notes = ns:NewModule("Notes")
ns.Notes = Notes

-- Returns the saved note text for a spec, or "" if none is saved (never nil,
-- so callers can hand this straight to an EditBox:SetText without a guard).
function Notes:Get(specID)
    if type(specID) ~= "number" then return "" end
    return ns.db.notes[specID] or ""
end

-- Saves note text for a spec. A note that is empty or only whitespace is
-- stored as nil rather than an empty string, so closing the Codex without
-- typing anything does not leave a stray key behind in the saved variables.
function Notes:Set(specID, text)
    if type(specID) ~= "number" then return false end

    if type(text) ~= "string" or text:match("^%s*$") then
        ns.db.notes[specID] = nil
    else
        ns.db.notes[specID] = text
    end
    return true
end
