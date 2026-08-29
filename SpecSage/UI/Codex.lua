-- UI/Codex.lua
-- The Codex: a browsable class/spec guide window with a talent-loadout vault
-- and personal notes. Built lazily (BuildFrame runs on the first Toggle or
-- Open, not at load) so an addon load never pays for a frame nobody opens.
--
-- Layout: a fixed ~740x520 frame with a class-icon rail on the left, that
-- class's spec buttons next to it, a tab strip (Overview/Stats/Rotation/
-- Cooldowns/Consumables/Loadouts/Notes) and a scrollable content area below
-- the tabs. Content rows are pooled per tab (one pool per simple text tab,
-- plus dedicated widgets for Loadouts/Notes) and reused across renders, the
-- same "keep old frames, hide the leftover ones" approach UI/Overlay.lua
-- uses for its rows.

local ADDON, ns = ...

local Codex = ns:NewModule("Codex")
ns.Codex = Codex

-- Retail has been moving specialization lookups into C_SpecializationInfo;
-- prefer the namespaced version when present, same pattern as
-- Modules/Stats.lua and Modules/Loadouts.lua.
local GetSpecializationInfoByID = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoByID)
    or GetSpecializationInfoByID

--------------------------------------------------------------------------------
-- Layout constants
--------------------------------------------------------------------------------

local FRAME_WIDTH, FRAME_HEIGHT = 740, 520
local CLASS_RAIL_WIDTH = 40
local SPEC_RAIL_WIDTH = 150
local TITLE_HEIGHT = 26
local TAB_HEIGHT = 24
local CONTENT_WIDTH = 480
local PADDING = 10
local LINE_GAP = 3
local PARAGRAPH_GAP = 6
local GROUP_GAP = 10

local TABS = { "Overview", "Stats", "Rotation", "Cooldowns", "Consumables", "Loadouts", "Notes" }

local CLASS_ICON_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local DEFAULT_CLASS_COLOR = { r = 0.8, g = 0.8, b = 0.8 }

-- Per Data/API.lua's schema comment, missing/empty guide sections render this
-- single italic-styled (see the colour-only note below) line rather than
-- nothing at all. WoW's SetFont has no italic flag, only OUTLINE/MONOCHROME/
-- THICKOUTLINE, so "italic" here is approximated with a muted colour.
local NO_DATA_TEXT = "no guide data yet - /sage config explains how to contribute"
local MUTED_COLOR = { 0.55, 0.55, 0.55 }
local HEADER_COLOR = { 0.4, 0.8, 1.0 }

-- Data/API.lua's statPriority vocabulary, in the Codex's own display words.
local STAT_LABELS = {
    primary = "Primary Stat", crit = "Crit", haste = "Haste", mastery = "Mastery",
    versatility = "Versatility", leech = "Leech", avoidance = "Avoidance",
    speed = "Speed", armor = "Armor", stamina = "Stamina",
}

--------------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------------

local function PlayerClassToken()
    if not UnitClass then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    if ok then return token end
    return nil
end

-- Whether `specID` is the spec the player is currently playing, i.e. whether
-- the Codex should show live stat values / offer "Save current" for it.
local function IsPlayersSpec(specID)
    if specID == nil then return false end
    local Loadouts = ns:GetModule("Loadouts")
    return Loadouts ~= nil and Loadouts:GetCurrentSpecID() == specID
end

local function ClassColor(token)
    return (RAID_CLASS_COLORS and token and RAID_CLASS_COLORS[token]) or DEFAULT_CLASS_COLOR
end

-- GetSpecializationInfoByID only knows the handful of specs the test mock
-- defines; every other spec (i.e. most of them, in and out of the client
-- when the API shape changes) falls back to the guide's own specName, per
-- DESIGN.md. Only id(1)/name(2)/icon(4) are read — other positions in this
-- call's return list have differed across API revisions and are not needed.
local function SpecDisplayName(specID, guide)
    if GetSpecializationInfoByID then
        local ok, _, name = pcall(GetSpecializationInfoByID, specID)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end
    if guide and guide.specName then return guide.specName end
    return "Spec " .. tostring(specID)
end

local function SpecIcon(specID)
    if not GetSpecializationInfoByID then return nil end
    local ok, _, _, _, icon = pcall(GetSpecializationInfoByID, specID)
    if ok and icon then return icon end
    return nil
end

-- Fallback chain for a rotation/cooldown step's spell icon, fully pcall
-- wrapped: a bad or removed spellID from a third-party guide pack must never
-- take the Codex down.
local function SpellIcon(spellID)
    if not spellID then return nil end
    local ok, icon = pcall(function()
        if C_Spell and C_Spell.GetSpellTexture then
            return C_Spell.GetSpellTexture(spellID)
        end
        if GetSpellTexture then
            return GetSpellTexture(spellID)
        end
        if C_Spell and C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(spellID)
            return info and info.iconID
        end
        if GetSpellInfo then
            local _, _, texture = GetSpellInfo(spellID)
            return texture
        end
        return nil
    end)
    if ok then return icon end
    return nil
end

--------------------------------------------------------------------------------
-- Content row pooling
--
-- One pool per simple text-only tab (Overview/Stats/Rotation/Cooldowns/
-- Consumables); Loadouts and Notes manage their own widgets since they are
-- interactive rather than read-only text. Every pool holds Frame rows so a
-- uniform :Hide() call retires the leftovers from a shorter render, the same
-- trick UI/Overlay.lua's row pooling uses.
--------------------------------------------------------------------------------

local function HidePoolFrom(pool, fromIndex)
    for i = fromIndex, #pool do
        pool[i]:Hide()
    end
end

-- A single line of text, optionally with a spell icon on its left edge that
-- shows the real spell tooltip on hover.
local function AcquireLineRow(pool, index, parent)
    local row = pool[index]
    if not row then
        row = CreateFrame("Frame", nil, parent)

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.icon:Hide()

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetJustifyH("LEFT")
        -- Both guarded: not every FontString method exists in every game
        -- version (or in the test mock), and wrapping is cheap here.
        pcall(row.text.SetJustifyV, row.text, "TOP")
        pcall(row.text.SetWordWrap, row.text, true)

        row:SetScript("OnEnter", function(self)
            if not self.spellID then return end
            pcall(function()
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(self.spellID)
                GameTooltip:Show()
            end)
        end)
        row:SetScript("OnLeave", function()
            pcall(function() GameTooltip:Hide() end)
        end)

        pool[index] = row
    end
    return row
end

-- Positions a line row at `y`, wraps its text to `width` (minus an icon
-- inset when opts.spellID is set) and returns the new y cursor. Height comes
-- from GetStringHeight when the client provides it (the real, wrapped pixel
-- height); the test mock does not, so a character-count estimate stands in
-- for it there.
local function PlaceLine(pool, index, parent, y, width, text, opts)
    opts = opts or {}
    local row = AcquireLineRow(pool, index, parent)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)

    local textInset = 0
    if opts.spellID then
        local icon = SpellIcon(opts.spellID)
        row.icon:SetTexture(icon)
        row.icon:Show()
        row.spellID = opts.spellID
        row:EnableMouse(true)
        textInset = 20
    else
        row.icon:Hide()
        row.spellID = nil
        row:EnableMouse(false)
    end

    row.text:ClearAllPoints()
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", textInset, 0)

    local color = opts.color or { 0.85, 0.85, 0.85 }
    row.text:SetTextColor(color[1], color[2], color[3])

    local textWidth = width - textInset
    row.text:SetWidth(textWidth)
    row.text:SetText(text or "")

    local ok, height = pcall(row.text.GetStringHeight, row.text)
    if not ok or not height or height <= 0 then
        local charsPerLine = math.max(20, math.floor(textWidth / 6))
        local lineCount = math.max(1, math.ceil((#(text or "")) / charsPerLine))
        height = lineCount * 14
    end

    local rowHeight = math.max(height, opts.spellID and 16 or 0)
    row:SetSize(width, rowHeight)
    row:Show()

    return y - rowHeight - LINE_GAP
end

-- A two-column "label ... value" row, used for the Stats tab (label = the
-- priority entry, value = the player's live reading when viewing their own
-- spec).
local function AcquireStatRow(pool, index, parent)
    local row = pool[index]
    if not row then
        row = CreateFrame("Frame", nil, parent)

        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.label:SetJustifyH("LEFT")
        row.label:SetPoint("LEFT", row, "LEFT", 0, 0)

        row.value = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.value:SetJustifyH("RIGHT")
        row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)

        pool[index] = row
    end
    return row
end

local function PlaceStatRow(pool, index, parent, y, width, label, value, muted)
    local row = AcquireStatRow(pool, index, parent)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    row:SetSize(width, 16)

    row.label:SetText(label or "")
    if muted then
        row.label:SetTextColor(MUTED_COLOR[1], MUTED_COLOR[2], MUTED_COLOR[3])
    else
        row.label:SetTextColor(0.85, 0.85, 0.85)
    end

    row.value:SetText(value or "")
    row.value:SetTextColor(1, 1, 1)

    row:Show()
    return y - 18
end

-- Hides the unused tail of a pool and sizes the scroll child to fit what was
-- actually drawn. `y` is the cursor value after the last row was placed.
function Codex:FinishPool(pool, usedCount, y)
    HidePoolFrom(pool, usedCount + 1)
    self.scrollChild:SetHeight(math.max(-y, 10))
    pcall(self.scrollFrame.UpdateScrollChildRect, self.scrollFrame)
end

--------------------------------------------------------------------------------
-- Section renderers
--
-- Each takes the guide table (or nil, for a spec with nothing registered)
-- and draws into its own pool. All five read-only tabs share the same
-- "guide missing/empty -> NO_DATA_TEXT" fallback DESIGN.md specifies.
--------------------------------------------------------------------------------

function Codex:RenderOverview(guide)
    local parent, width = self.scrollChild, CONTENT_WIDTH
    local pool = self.pools.overview
    local y, index = -PADDING, 0

    local paragraphs = guide and guide.overview
    if not paragraphs or #paragraphs == 0 then
        index = index + 1
        y = PlaceLine(pool, index, parent, y, width, NO_DATA_TEXT, { color = MUTED_COLOR })
    else
        for _, paragraph in ipairs(paragraphs) do
            index = index + 1
            y = PlaceLine(pool, index, parent, y, width, paragraph)
            y = y - PARAGRAPH_GAP
        end
    end

    if guide and guide.tips and #guide.tips > 0 then
        index = index + 1
        y = PlaceLine(pool, index, parent, y, width, "Tips", { color = HEADER_COLOR })
        for _, tip in ipairs(guide.tips) do
            index = index + 1
            y = PlaceLine(pool, index, parent, y, width, "\226\128\162 " .. tip)
        end
    end

    self:FinishPool(pool, index, y)
end

function Codex:RenderStats(guide, specID)
    local parent, width = self.scrollChild, CONTENT_WIDTH
    local pool = self.pools.stats
    local y, index = -PADDING, 0

    local priorities = guide and guide.statPriority
    if not priorities or #priorities == 0 then
        index = index + 1
        y = PlaceStatRow(pool, index, parent, y, width, NO_DATA_TEXT, nil, true)
    else
        -- Live values only make sense next to the spec the player is
        -- actually playing; a guide someone else's alt would use just shows
        -- the priority order.
        local StatsModule = IsPlayersSpec(specID) and ns:GetModule("Stats") or nil
        for order, entry in ipairs(priorities) do
            local label = format("%d. %s", order, STAT_LABELS[entry.stat] or entry.stat)
            if entry.note then label = label .. " (" .. entry.note .. ")" end
            local value = StatsModule and StatsModule:GetStatValue(entry.stat) or nil
            index = index + 1
            y = PlaceStatRow(pool, index, parent, y, width, label, value)
        end
    end

    self:FinishPool(pool, index, y)
end

function Codex:RenderRotation(guide)
    local parent, width = self.scrollChild, CONTENT_WIDTH
    local pool = self.pools.rotation
    local y, index = -PADDING, 0

    local groups = guide and guide.rotation
    if not groups or #groups == 0 then
        index = index + 1
        y = PlaceLine(pool, index, parent, y, width, NO_DATA_TEXT, { color = MUTED_COLOR })
    else
        for _, group in ipairs(groups) do
            index = index + 1
            y = PlaceLine(pool, index, parent, y, width, group.title or "", { color = HEADER_COLOR })
            for _, step in ipairs(group.steps or {}) do
                index = index + 1
                y = PlaceLine(pool, index, parent, y, width, step.text or "", { spellID = step.spellID })
            end
            y = y - GROUP_GAP
        end
    end

    self:FinishPool(pool, index, y)
end

function Codex:RenderCooldowns(guide)
    local parent, width = self.scrollChild, CONTENT_WIDTH
    local pool = self.pools.cooldowns
    local y, index = -PADDING, 0

    local cooldowns = guide and guide.cooldowns
    if not cooldowns or #cooldowns == 0 then
        index = index + 1
        y = PlaceLine(pool, index, parent, y, width, NO_DATA_TEXT, { color = MUTED_COLOR })
    else
        for _, entry in ipairs(cooldowns) do
            index = index + 1
            y = PlaceLine(pool, index, parent, y, width, entry.text or "", { spellID = entry.spellID })
        end
    end

    self:FinishPool(pool, index, y)
end

function Codex:RenderConsumables(guide)
    local parent, width = self.scrollChild, CONTENT_WIDTH
    local pool = self.pools.consumables
    local y, index = -PADDING, 0

    local consumables = guide and guide.consumables
    if not consumables or #consumables == 0 then
        index = index + 1
        y = PlaceLine(pool, index, parent, y, width, NO_DATA_TEXT, { color = MUTED_COLOR })
    else
        for _, entry in ipairs(consumables) do
            index = index + 1
            y = PlaceLine(pool, index, parent, y, width, format("%s: %s", entry.slot or "?", entry.text or ""))
        end
    end

    self:FinishPool(pool, index, y)
end

--------------------------------------------------------------------------------
-- Loadouts tab
--------------------------------------------------------------------------------

local function AcquireLoadoutRow(pool, index, parent)
    local row = pool[index]
    if not row then
        row = CreateFrame("Frame", nil, parent)

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.name:SetJustifyH("LEFT")
        row.name:SetPoint("LEFT", row, "LEFT", 0, 0)

        row.copyButton = CreateFrame("Button", nil, row)
        row.copyButton:SetSize(50, 18)
        row.copyButton:SetText("Copy")
        row.copyButton:SetPoint("RIGHT", row, "RIGHT", -58, 0)

        row.deleteButton = CreateFrame("Button", nil, row)
        row.deleteButton:SetSize(50, 18)
        row.deleteButton:SetText("Delete")
        row.deleteButton:SetPoint("RIGHT", row, "RIGHT", 0, 0)

        pool[index] = row
    end
    return row
end

function Codex:EnsureLoadoutWidgets()
    if self.loadoutButtons then return end

    local parent = self.scrollChild

    local save = CreateFrame("Button", nil, parent)
    save:SetSize(110, 20)
    save:SetText("Save current")
    save:SetScript("OnClick", function() self:OnSaveCurrentClicked() end)

    local add = CreateFrame("Button", nil, parent)
    add:SetSize(120, 20)
    add:SetText("Add from string")
    add:SetScript("OnClick", function() self:ShowAddDialog() end)

    self.loadoutButtons = { save = save, add = add }
    self.loadoutRowPool = {}
end

-- Deleting is a two-click confirm rather than a StaticPopup (DESIGN.md offers
-- either): first click arms the button and relabels it; a second click
-- within the window actually deletes. The timer callback resets whichever
-- loadout now occupies this pooled row back to its idle label, which is
-- always the correct state for it to be in, so a row recycled mid-countdown
-- is not left showing a stale "Confirm?".
function Codex:OnDeleteLoadoutClicked(button, specID, index)
    if button.armed then
        local Loadouts = ns:GetModule("Loadouts")
        Loadouts:Delete(specID, index)
        button.armed = false
        if self.activeTab == "Loadouts" then self:RenderActiveTab() end
        return
    end

    button.armed = true
    button:SetText("Confirm?")
    C_Timer.After(4, function()
        button.armed = false
        pcall(button.SetText, button, "Delete")
    end)
end

function Codex:RenderLoadouts(specID)
    self:EnsureLoadoutWidgets()
    local parent, width = self.scrollChild, CONTENT_WIDTH
    local y = -PADDING

    local buttons = self.loadoutButtons
    buttons.save:ClearAllPoints()
    buttons.save:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    buttons.save:SetShown(IsPlayersSpec(specID))

    buttons.add:ClearAllPoints()
    buttons.add:SetPoint("TOPLEFT", parent, "TOPLEFT", 120, y)
    buttons.add:Show()

    y = y - 26

    local Loadouts = ns:GetModule("Loadouts")
    local list = (Loadouts and specID) and Loadouts:GetForSpec(specID) or {}
    local pool = self.loadoutRowPool

    if #list == 0 then
        local empty = AcquireLoadoutRow(pool, 1, parent)
        empty:ClearAllPoints()
        empty:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        empty:SetSize(width, 18)
        empty.name:SetText("no loadouts saved for this spec yet")
        empty.name:SetTextColor(MUTED_COLOR[1], MUTED_COLOR[2], MUTED_COLOR[3])
        empty.copyButton:Hide()
        empty.deleteButton:Hide()
        empty:Show()
        y = y - 20
        HidePoolFrom(pool, 2)
    else
        for i, loadout in ipairs(list) do
            local row = AcquireLoadoutRow(pool, i, parent)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
            row:SetSize(width, 18)

            row.name:SetText(format("%s  |cff888888[%s]|r", loadout.name, loadout.category))
            row.name:SetTextColor(0.9, 0.9, 0.9)
            row.copyButton:Show()
            row.copyButton:SetScript("OnClick", function() self:ShowCopyDialog(loadout.export) end)

            row.deleteButton.armed = false
            row.deleteButton:SetText("Delete")
            row.deleteButton:Show()
            row.deleteButton:SetScript("OnClick", function(btn)
                self:OnDeleteLoadoutClicked(btn, specID, i)
            end)

            row:Show()
            y = y - 20
        end
        HidePoolFrom(pool, #list + 1)
    end

    self.scrollChild:SetHeight(math.max(-y, 10))
    pcall(self.scrollFrame.UpdateScrollChildRect, self.scrollFrame)
end

function Codex:OnSaveCurrentClicked()
    local specID = self.selectedSpecID
    if not IsPlayersSpec(specID) then return end

    local Loadouts = ns:GetModule("Loadouts")
    local exportString = Loadouts and Loadouts:ExportCurrent()
    if not exportString then
        ns.Print("could not read your current loadout - open the talent UI once and try again.")
        return
    end

    self:ShowAddDialog(exportString)
end

function Codex:CycleAddCategory()
    local Loadouts = ns:GetModule("Loadouts")
    local order = (Loadouts and Loadouts.CATEGORY_ORDER) or { "Other" }

    local currentIndex = 1
    for i, category in ipairs(order) do
        if category == self.addCategory then
            currentIndex = i
            break
        end
    end

    self.addCategory = order[(currentIndex % #order) + 1]
    self.addCategoryButton:SetText(self.addCategory)
end

function Codex:EnsureAddDialog()
    if self.addDialog then return end

    local dialog = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    dialog:SetSize(360, 210)
    dialog:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    dialog:SetBackdropColor(0.05, 0.05, 0.07, 0.98)
    dialog:Hide()

    local nameLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", 12, -12)
    nameLabel:SetText("Name")

    local nameBox = CreateFrame("EditBox", nil, dialog)
    nameBox:SetSize(336, 20)
    nameBox:SetAutoFocus(false)
    nameBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -4)

    local categoryButton = CreateFrame("Button", nil, dialog)
    categoryButton:SetSize(120, 20)
    categoryButton:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -10)
    categoryButton:SetScript("OnClick", function() self:CycleAddCategory() end)

    local importLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    importLabel:SetPoint("TOPLEFT", categoryButton, "BOTTOMLEFT", 0, -10)
    importLabel:SetText("Import string")

    local importBox = CreateFrame("EditBox", nil, dialog)
    importBox:SetMultiLine(true)
    importBox:SetSize(336, 70)
    importBox:SetAutoFocus(false)
    importBox:SetPoint("TOPLEFT", importLabel, "BOTTOMLEFT", 0, -4)

    local saveButton = CreateFrame("Button", nil, dialog)
    saveButton:SetSize(80, 22)
    saveButton:SetText("Save")
    saveButton:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 12, 12)
    saveButton:SetScript("OnClick", function() self:OnAddDialogSave() end)

    local cancelButton = CreateFrame("Button", nil, dialog)
    cancelButton:SetSize(80, 22)
    cancelButton:SetText("Cancel")
    cancelButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -12, 12)
    cancelButton:SetScript("OnClick", function() self:HideAddDialog() end)

    self.addDialog = dialog
    self.addNameBox = nameBox
    self.addImportBox = importBox
    self.addCategoryButton = categoryButton
end

function Codex:ShowAddDialog(prefillImport)
    self:EnsureAddDialog()
    self.addNameBox:SetText("")
    self.addImportBox:SetText(prefillImport or "")
    self.addCategory = "Other"
    self.addCategoryButton:SetText(self.addCategory)
    self.addDialog:Show()
end

function Codex:HideAddDialog()
    if self.addDialog then self.addDialog:Hide() end
end

function Codex:OnAddDialogSave()
    local Loadouts = ns:GetModule("Loadouts")
    local name = self.addNameBox:GetText()
    local importString = self.addImportBox:GetText()

    local ok, err = Loadouts:Add(self.selectedSpecID, name, self.addCategory, importString)
    if ok then
        self:HideAddDialog()
        if self.activeTab == "Loadouts" then self:RenderActiveTab() end
    else
        ns.Print("could not save loadout: " .. tostring(err))
    end
end

function Codex:EnsureCopyDialog()
    if self.copyDialog then return end

    local dialog = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    dialog:SetSize(360, 130)
    dialog:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    dialog:SetBackdropColor(0.05, 0.05, 0.07, 0.98)
    dialog:Hide()

    local label = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOP", dialog, "TOP", 0, -12)
    label:SetText("Ctrl+C to copy")

    -- Read-only in spirit (nothing writes it back anywhere): the box exists
    -- purely so the string is selected and focused for the player to copy.
    local box = CreateFrame("EditBox", nil, dialog)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetSize(336, 60)
    box:SetPoint("TOP", label, "BOTTOM", 0, -8)

    local closeButton = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    closeButton:SetSize(24, 24)
    closeButton:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -2, -2)
    closeButton:SetScript("OnClick", function() dialog:Hide() end)

    self.copyDialog = dialog
    self.copyBox = box
end

function Codex:ShowCopyDialog(exportString)
    self:EnsureCopyDialog()
    self.copyBox:SetText(exportString or "")
    self.copyBox:SetFocus()
    self.copyBox:HighlightText()
    self.copyDialog:Show()
end

--------------------------------------------------------------------------------
-- Notes tab
--------------------------------------------------------------------------------

function Codex:SaveNotes(box)
    box = box or self.notesBox
    if not box or not box.specID then return end
    local Notes = ns:GetModule("Notes")
    if Notes then Notes:Set(box.specID, box:GetText()) end
end

function Codex:EnsureNotesBox()
    if self.notesBox then return end

    local box = CreateFrame("EditBox", nil, self.scrollChild)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    pcall(box.SetJustifyH, box, "LEFT")
    box:SetScript("OnEditFocusLost", function(self2) self:SaveNotes(self2) end)

    self.notesBox = box
end

function Codex:RenderNotes(specID)
    self:EnsureNotesBox()
    local box = self.notesBox

    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, -PADDING)
    box:SetSize(CONTENT_WIDTH, 400)
    box.specID = specID

    local Notes = ns:GetModule("Notes")
    box:SetText((Notes and specID) and Notes:Get(specID) or "")
    box:Show()

    self.scrollChild:SetHeight(420)
end

--------------------------------------------------------------------------------
-- Tab dispatch
--------------------------------------------------------------------------------

-- Every simple-text pool, plus the Loadouts row pool and the Notes box, are
-- hidden before rendering the newly active tab; only one tab's widgets are
-- ever visible at a time, all sharing the same scroll child.
local POOL_BY_TAB = { Overview = "overview", Stats = "stats", Rotation = "rotation", Cooldowns = "cooldowns", Consumables = "consumables" }

function Codex:HideOtherTabWidgets(activeTab)
    for tabName, poolName in pairs(POOL_BY_TAB) do
        if tabName ~= activeTab then
            HidePoolFrom(self.pools[poolName], 1)
        end
    end

    if activeTab ~= "Loadouts" then
        if self.loadoutButtons then
            self.loadoutButtons.save:Hide()
            self.loadoutButtons.add:Hide()
        end
        if self.loadoutRowPool then HidePoolFrom(self.loadoutRowPool, 1) end
    end

    if activeTab ~= "Notes" and self.notesBox then
        self.notesBox:Hide()
    end
end

function Codex:RenderActiveTab()
    if not self.frame then return end

    local specID = self.selectedSpecID
    local guide = specID and ns.GuideStore:GetGuide(specID) or nil
    local tab = self.activeTab

    self:HideOtherTabWidgets(tab)

    if tab == "Overview" then
        self:RenderOverview(guide)
    elseif tab == "Stats" then
        self:RenderStats(guide, specID)
    elseif tab == "Rotation" then
        self:RenderRotation(guide)
    elseif tab == "Cooldowns" then
        self:RenderCooldowns(guide)
    elseif tab == "Consumables" then
        self:RenderConsumables(guide)
    elseif tab == "Loadouts" then
        self:RenderLoadouts(specID)
    elseif tab == "Notes" then
        self:RenderNotes(specID)
    end

    self:UpdateTabHighlight()
end

--------------------------------------------------------------------------------
-- Class rail / spec rail / tab strip
--------------------------------------------------------------------------------

function Codex:UpdateClassHighlight()
    local color = ClassColor(self.selectedClass)

    if self.frame then
        pcall(self.frame.SetBackdropBorderColor, self.frame, color.r, color.g, color.b, 1)
        if self.frame.title then
            self.frame.title:SetTextColor(color.r, color.g, color.b)
        end
    end

    for token, btn in pairs(self.classButtons or {}) do
        pcall(btn.SetAlpha, btn, (token == self.selectedClass) and 1 or 0.55)
    end
end

function Codex:UpdateSpecHighlight()
    local color = ClassColor(self.selectedClass)
    for _, btn in ipairs(self.specButtonPool or {}) do
        if btn.specID then
            if btn.specID == self.selectedSpecID then
                btn.label:SetTextColor(color.r, color.g, color.b)
            else
                btn.label:SetTextColor(0.8, 0.8, 0.8)
            end
        end
    end
end

function Codex:UpdateTabHighlight()
    for tabName, btn in pairs(self.tabButtons or {}) do
        pcall(btn.SetAlpha, btn, (tabName == self.activeTab) and 1 or 0.6)
    end
end

function Codex:RefreshSpecRail(classToken)
    local rail, pool = self.specRail, self.specButtonPool
    local specIDs = ns.GuideStore:GetClassSpecs(classToken)
    local y = -4

    for index, specID in ipairs(specIDs) do
        local btn = pool[index]
        if not btn then
            btn = CreateFrame("Button", nil, rail)
            btn:SetSize(SPEC_RAIL_WIDTH - 8, 28)

            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetSize(24, 24)
            btn.icon:SetPoint("LEFT", btn, "LEFT", 0, 0)

            btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btn.label:SetJustifyH("LEFT")
            btn.label:SetPoint("LEFT", btn.icon, "RIGHT", 4, 0)

            pool[index] = btn
        end

        local guide = ns.GuideStore:GetGuide(specID)
        local icon = SpecIcon(specID)

        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", rail, "TOPLEFT", 4, y)
        btn.label:SetText(SpecDisplayName(specID, guide))
        if icon then
            btn.icon:SetTexture(icon)
            btn.icon:Show()
        else
            btn.icon:Hide()
        end
        btn.specID = specID
        btn:SetScript("OnClick", function() self:SelectSpec(specID) end)
        btn:Show()

        y = y - 30
    end

    HidePoolFrom(pool, #specIDs + 1)
end

function Codex:SelectClass(classToken)
    if not classToken then return end
    self.selectedClass = classToken
    self:RefreshSpecRail(classToken)
    self:UpdateClassHighlight()

    local specIDs = ns.GuideStore:GetClassSpecs(classToken)
    local defaultSpecID = specIDs[1]

    -- Prefer the player's actual current spec when it belongs to this class,
    -- so opening the Codex on your own class lands on your own spec.
    local Loadouts = ns:GetModule("Loadouts")
    local currentSpecID = Loadouts and Loadouts:GetCurrentSpecID()
    if currentSpecID then
        for _, specID in ipairs(specIDs) do
            if specID == currentSpecID then
                defaultSpecID = currentSpecID
                break
            end
        end
    end

    self:SelectSpec(defaultSpecID)
end

function Codex:SelectSpec(specID)
    self.selectedSpecID = specID
    self:UpdateSpecHighlight()
    if self.scrollFrame then self.scrollFrame:SetVerticalScroll(0) end
    self:RenderActiveTab()
end

function Codex:SelectTab(tabName)
    local valid = false
    for _, name in ipairs(TABS) do
        if name == tabName then valid = true break end
    end
    if not valid then return end

    self.activeTab = tabName
    if self.scrollFrame then self.scrollFrame:SetVerticalScroll(0) end
    self:RenderActiveTab()
end

--------------------------------------------------------------------------------
-- Frame construction
--------------------------------------------------------------------------------

function Codex:BuildClassRail()
    local rail = CreateFrame("Frame", nil, self.frame)
    rail:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -TITLE_HEIGHT)
    rail:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 0, 0)
    rail:SetWidth(CLASS_RAIL_WIDTH)
    self.classRail = rail

    self.classButtons = {}
    local y = -4
    for _, entry in ipairs(ns.GuideStore:GetClasses()) do
        local btn = CreateFrame("Button", nil, rail)
        btn:SetSize(32, 32)
        btn:SetPoint("TOPLEFT", rail, "TOPLEFT", 4, y)

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(28, 28)
        icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
        icon:SetTexture(CLASS_ICON_TEXTURE)
        local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[entry.token]
        if coords then icon:SetTexCoord(unpack(coords)) end
        btn.icon = icon

        btn:SetScript("OnClick", function() self:SelectClass(entry.token) end)
        btn:SetScript("OnEnter", function(self2)
            pcall(function()
                GameTooltip:SetOwner(self2, "ANCHOR_RIGHT")
                GameTooltip:AddLine(entry.name)
                GameTooltip:Show()
            end)
        end)
        btn:SetScript("OnLeave", function() pcall(function() GameTooltip:Hide() end) end)

        self.classButtons[entry.token] = btn
        y = y - 34
    end
end

function Codex:BuildSpecRail()
    local rail = CreateFrame("Frame", nil, self.frame)
    rail:SetPoint("TOPLEFT", self.classRail, "TOPRIGHT", 4, 0)
    rail:SetPoint("BOTTOMLEFT", self.classRail, "BOTTOMRIGHT", 4, 0)
    rail:SetWidth(SPEC_RAIL_WIDTH)
    self.specRail = rail
    self.specButtonPool = {}
end

function Codex:BuildTabStrip()
    local strip = CreateFrame("Frame", nil, self.frame)
    strip:SetPoint("TOPLEFT", self.specRail, "TOPRIGHT", 8, 0)
    strip:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -8, -TITLE_HEIGHT)
    strip:SetHeight(TAB_HEIGHT)
    self.tabStrip = strip

    self.tabButtons = {}
    local x = 0
    for _, tabName in ipairs(TABS) do
        local btn = CreateFrame("Button", nil, strip)
        btn:SetSize(64, TAB_HEIGHT)
        btn:SetPoint("TOPLEFT", strip, "TOPLEFT", x, 0)
        btn:SetText(tabName)
        btn:SetScript("OnClick", function() self:SelectTab(tabName) end)
        self.tabButtons[tabName] = btn
        x = x + 66
    end
end

function Codex:BuildContentArea()
    local scrollFrame = CreateFrame("ScrollFrame", nil, self.frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", self.tabStrip, "BOTTOMLEFT", 0, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -28, 8)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(CONTENT_WIDTH)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    self.scrollFrame = scrollFrame
    self.scrollChild = scrollChild
    self.pools = { overview = {}, stats = {}, rotation = {}, cooldowns = {}, consumables = {} }
end

function Codex:BuildFrame()
    local frame = CreateFrame("Frame", "SpecSageCodexFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetFrameStrata("HIGH")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
    frame:SetBackdropBorderColor(0, 0, 0, 1)

    frame:SetScript("OnDragStart", function(self2) self2:StartMoving() end)
    frame:SetScript("OnDragStop", function(self2) self2:StopMovingOrSizing() end)
    -- Notes save on window close as well as on focus-lost, so a note typed
    -- and then closed without tabbing away is never lost.
    frame:SetScript("OnHide", function() self:SaveNotes() end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -8)
    title:SetText("SpecSage Codex")
    frame.title = title

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetSize(24, 24)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeButton:SetScript("OnClick", function() self:Toggle() end)

    -- Registers the frame's global name for ESC-to-close; UISpecialFrames is
    -- a plain array of frame names that the client's own ESC handler reads.
    tinsert(UISpecialFrames, "SpecSageCodexFrame")

    self.frame = frame
    self:BuildClassRail()
    self:BuildSpecRail()
    self:BuildTabStrip()
    self:BuildContentArea()

    -- CreateFrame hands back a frame that is already shown (both in the real
    -- client and in the test mock); the Codex should not pop up the instant
    -- it is built, only once Toggle/Open actually decide to show it.
    frame:Hide()
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function Codex:EnsureFrame()
    if not self.frame then
        self:BuildFrame()
    end
end

function Codex:IsShown()
    return self.frame ~= nil and self.frame:IsShown() == true
end

-- Opens the Codex at a class/spec. A nil classToken defaults to whatever is
-- already selected, falling back to the player's own class on a first-ever
-- open; a nil specID lets SelectClass pick the player's current spec (if it
-- belongs to that class) or the class's first registered spec.
function Codex:Open(classToken, specID)
    self:EnsureFrame()

    classToken = classToken or self.selectedClass or PlayerClassToken()
    if not classToken then
        local classes = ns.GuideStore:GetClasses()
        classToken = classes[1] and classes[1].token
    end

    self:SelectClass(classToken)
    if specID then
        self:SelectSpec(specID)
    end

    self.frame:Show()
end

function Codex:Toggle()
    self:EnsureFrame()

    if self.frame:IsShown() then
        self.frame:Hide()
    elseif not self.selectedClass then
        self:Open()
    else
        self.frame:Show()
    end
end
