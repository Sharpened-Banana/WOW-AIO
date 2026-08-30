-- UI/Codex.lua
-- The Codex: a browsable class/spec guide window with a talent-loadout vault
-- and personal notes. Built lazily (BuildFrame runs on the first Toggle or
-- Open, not at load) so an addon load never pays for a frame nobody opens.
--
-- Layout: a fixed ~900x520 frame (wide enough for a class-coloured name next
-- to each class icon, and for "Consumables" to fit its tab button without
-- clipping) with a class-icon rail on the left, that class's spec buttons
-- next to it, a tab strip (Overview/Stats/Rotation/Cooldowns/Consumables/
-- Loadouts/Notes) and a scrollable content area below the tabs. Content rows
-- are pooled per tab (one pool per simple text tab,
-- plus dedicated widgets for Loadouts/Notes) and reused across renders, the
-- same "keep old frames, hide the leftover ones" approach UI/Overlay.lua
-- uses for its rows.

local ADDON, ns = ...

local Codex = ns:NewModule("Codex")
ns.Codex = Codex

-- Without this, the first /sage of a session runs RenderActiveTab with
-- activeTab == nil: none of its "if tab == ..." branches match, so the Codex
-- opens completely blank until the player happens to click a tab. See
-- RenderActiveTab's own defensive fallback below for the second half of this
-- fix.
function Codex:OnInit()
    self.activeTab = self.activeTab or "Overview"
end

-- Modules/BiS.lua queues a C_Item.RequestLoadItemDataByID call whenever a
-- checklist entry's item is still uncached; this is the other half of that
-- fix. Without it, a freshly-added entry whose item was not yet cached would
-- sit at its "Item 12345" placeholder (no quality colour, no live status)
-- until the player happened to switch tab or spec again - the async fetch
-- was queued, but nothing ever acted on it resolving.
function Codex:OnEnable()
    ns:RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, itemID)
        self:OnBiSItemInfoReceived(itemID)
    end)
end

-- Retail has been moving specialization lookups into C_SpecializationInfo;
-- prefer the namespaced version when present, same pattern as
-- Modules/Stats.lua and Modules/Loadouts.lua.
local GetSpecializationInfoByID = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoByID)
    or GetSpecializationInfoByID

--------------------------------------------------------------------------------
-- Layout constants
--------------------------------------------------------------------------------

-- Class rail wide enough for icon + class-coloured name (DESIGN.md), tab
-- strip buttons wide enough for "Consumables" under UIPanelButtonTemplate,
-- and CONTENT_WIDTH set to the scroll area's real geometry (frame width minus
-- both rails, their gaps, and the scrollbar) rather than an independent guess
-- that used to leave ~30px of dead space on the right of every content tab.
-- FRAME_WIDTH widened to fit the BiS tab (DESIGN.md's "BiS / Gear" section)
-- with tab button width/stride left as they are per that section. DESIGN.md
-- specified +60 (900->960), but that only accounted for CONTENT_WIDTH's
-- geometry chain; the tab strip is a separate chain (frame width minus both
-- rails, their gaps, and its own 8px side margins) and 8 tabs at the
-- existing 84/86 need 686px, which +60 alone left 16px short, clipping the
-- last tab past the frame's right edge. +84 (900->984) covers the tab
-- strip's real requirement with a small margin; CONTENT_WIDTH grows by the
-- same 84px to keep its own invariant (frame width minus 310px of chrome).
local FRAME_WIDTH, FRAME_HEIGHT = 984, 520
local CLASS_RAIL_WIDTH = 120
local SPEC_RAIL_WIDTH = 150
local TITLE_HEIGHT = 26
local TAB_HEIGHT = 24
local TAB_BUTTON_WIDTH = 84
local TAB_BUTTON_STRIDE = 86
local CONTENT_WIDTH = 674
local PADDING = 10
local LINE_GAP = 3
local PARAGRAPH_GAP = 6
local GROUP_GAP = 10

local TABS = { "Overview", "Stats", "Rotation", "Cooldowns", "Consumables", "BiS", "Loadouts", "Notes" }

local CLASS_ICON_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local DEFAULT_CLASS_COLOR = { r = 0.8, g = 0.8, b = 0.8 }

-- Per Data/API.lua's schema comment, missing/empty guide sections render this
-- single italic-styled (see the colour-only note below) line rather than
-- nothing at all. WoW's SetFont has no italic flag, only OUTLINE/MONOCHROME/
-- THICKOUTLINE, so "italic" here is approximated with a muted colour. Names
-- the real place to add data (a Lua data file) rather than the options
-- panel, which has no Codex section (see Core/Options.lua).
local NO_DATA_TEXT = "no guide data yet - see SpecSage/Data/Guides_<Class>.lua to add some"
local MUTED_COLOR = { 0.55, 0.55, 0.55 }
local HEADER_COLOR = { 0.4, 0.8, 1.0 }

-- BiS tab: status-tag colours (DESIGN.md: green/yellow/grey) and the default
-- item colour for an entry whose quality is not known yet (a plain-name
-- entry, or an itemID GetItemInfo has not resolved yet).
local BIS_STATUS_COLOR = {
    equipped = { 0.2, 0.9, 0.2 },
    owned = { 0.95, 0.85, 0.2 },
    missing = { 0.6, 0.6, 0.6 },
}
local BIS_STATUS_LABEL = {
    equipped = "equipped",
    owned = "in bags",
    missing = "missing",
}
local DEFAULT_ITEM_COLOR = { 0.8, 0.8, 0.8 }

-- How much of a BiS row's width row.text is allowed to use: the remaining
-- 120px covers row.status (anchored at RIGHT -58, room for the widest
-- status label plus its own margin) and the 50px Delete button (anchored at
-- RIGHT 0) that sit to its right on the same row.
local BIS_ROW_TEXT_WIDTH_INSET = 120

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

-- Maps an item quality (0=Poor..5=Legendary) to its r,g,b colour, the same
-- ITEM_QUALITY_COLORS global fallback pattern Codex.lua already uses for
-- RAID_CLASS_COLORS. A nil quality (item link/plain-name entry, or an
-- itemID GetItemInfo has not resolved yet) falls back to a neutral grey.
local function ItemQualityColor(quality)
    local entry = ITEM_QUALITY_COLORS and quality and ITEM_QUALITY_COLORS[quality]
    if entry then return entry.r, entry.g, entry.b end
    return DEFAULT_ITEM_COLOR[1], DEFAULT_ITEM_COLOR[2], DEFAULT_ITEM_COLOR[3]
end

-- Creates a multi-line EditBox backed by a bordered BackdropTemplate frame.
-- A bare EditBox has no font set and no backdrop/inset of its own: in the
-- real client that means invisible text (or a "font not set" error on
-- SetText) and no visual hint of where to click or type. Returns the
-- backdrop (position/size this) and the EditBox itself (read/write text on
-- this).
local function NewBackdropEditBox(parent, width, height)
    local backdrop = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    backdrop:SetSize(width, height)
    backdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    backdrop:SetBackdropColor(0, 0, 0, 0.6)
    backdrop:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)

    local box = CreateFrame("EditBox", nil, backdrop)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetTextInsets(4, 4, 2, 2)
    box:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 4, -4)
    box:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -4, 4)
    -- The Codex is in UISpecialFrames, so an unhandled ESC inside a focused
    -- EditBox would otherwise close the whole window out from under whatever
    -- was being typed.
    box:SetScript("OnEscapePressed", function(self2) self2:ClearFocus() end)

    return backdrop, box
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
-- BiS tab
--
-- Two halves sharing one scroll child: shipped gear guidance (read-only text
-- rows, drawn into self.pools.bis the same way Consumables draws into
-- self.pools.consumables) on top, then a divider, then the player's own
-- interactive checklist (its own row pool, like Loadouts' loadoutRowPool)
-- and an Add row below it. Positions continue down the same `y` cursor
-- across both halves so nothing overlaps.
--------------------------------------------------------------------------------

local function AcquireBiSRow(pool, index, parent)
    local row = pool[index]
    if not row then
        row = CreateFrame("Frame", nil, parent)
        row:EnableMouse(true)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetJustifyH("LEFT")
        row.text:SetPoint("LEFT", row, "LEFT", 0, 0)
        -- Bounded and non-wrapping: row.text is arbitrary user text (a
        -- plain-name entry has no length limit of its own), and a
        -- FontString does not clip to its parent frame - without a width
        -- and SetWordWrap(false), a long name draws straight through
        -- row.status and row.deleteButton instead of eliding. Guarded since
        -- SetWordWrap is not on every FontString method surface (including
        -- the test mock's).
        pcall(row.text.SetWordWrap, row.text, false)

        row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.status:SetJustifyH("RIGHT")
        row.status:SetPoint("RIGHT", row, "RIGHT", -58, 0)

        row.deleteButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.deleteButton:SetSize(50, 18)
        row.deleteButton:SetText("Delete")
        row.deleteButton:SetPoint("RIGHT", row, "RIGHT", 0, 0)

        -- Real spell tooltip on hover, the same shared-GameTooltip approach
        -- AcquireLineRow uses for rotation/cooldown spell icons ("the Codex
        -- has no pinning" per DESIGN.md).
        row:SetScript("OnEnter", function(self2)
            if not self2.itemID then return end
            pcall(function()
                GameTooltip:SetOwner(self2, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(self2.itemID)
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

function Codex:EnsureBiSWidgets()
    if self.bisButtons then return end

    local parent = self.scrollChild

    local slotButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    slotButton:SetSize(90, 20)
    slotButton:SetScript("OnClick", function() self:CycleBiSSlot() end)

    local itemBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    itemBox:SetSize(300, 20)
    itemBox:SetAutoFocus(false)
    -- A plain-name entry has no other length limit (see row.text's own
    -- width bound above), so an unbounded box lets a player type something
    -- that would overflow the checklist row it renders into.
    itemBox:SetMaxLetters(255)
    itemBox:SetScript("OnEscapePressed", function(self2) self2:ClearFocus() end)
    itemBox:SetScript("OnEnterPressed", function() self:OnBiSAddClicked() end)

    local addButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    addButton:SetSize(60, 20)
    addButton:SetText("Add")
    addButton:SetScript("OnClick", function() self:OnBiSAddClicked() end)

    self.bisButtons = { slotButton = slotButton, addButton = addButton }
    self.bisItemBox = itemBox
    self.bisRowPool = {}

    local BiSModule = ns:GetModule("BiS")
    self.bisSlot = (BiSModule and BiSModule.SLOT_ORDER and BiSModule.SLOT_ORDER[1]) or "Head"
    slotButton:SetText(self.bisSlot)
end

function Codex:CycleBiSSlot()
    local BiSModule = ns:GetModule("BiS")
    local order = (BiSModule and BiSModule.SLOT_ORDER) or { "Head" }

    local currentIndex = 1
    for i, slot in ipairs(order) do
        if slot == self.bisSlot then
            currentIndex = i
            break
        end
    end

    self.bisSlot = order[(currentIndex % #order) + 1]
    self.bisButtons.slotButton:SetText(self.bisSlot)
end

function Codex:OnBiSAddClicked()
    local BiSModule = ns:GetModule("BiS")
    local specID = self.selectedSpecID
    if not BiSModule or not specID then return end

    local itemText = self.bisItemBox:GetText()
    if not itemText or itemText:match("^%s*$") then
        -- An empty/whitespace box (a stray click, or Enter on an untouched
        -- box) is a silent no-op, not a "could not add BiS entry" chat
        -- message - BiS:Add's rejection is only interesting when the player
        -- actually typed something.
        return
    end

    local ok, err = BiSModule:Add(specID, self.bisSlot, itemText)
    if ok then
        self.bisItemBox:SetText("")
        if self.activeTab == "BiS" then self:RenderActiveTab() end
    else
        ns.Print("could not add BiS entry: " .. tostring(err))
    end
end

-- Fired (via Codex:OnEnable) on GET_ITEM_INFO_RECEIVED. Re-renders only the
-- BiS tab's own pool/rows (RenderBiS), not the whole Codex, and only when
-- the resolved itemID actually belongs to an entry on the spec currently
-- being viewed - an item info event for some unrelated addon's lookup, or
-- for a spec the player is not looking at right now, is a no-op.
function Codex:OnBiSItemInfoReceived(itemID)
    if type(itemID) ~= "number" then return end
    if not self.frame or self.activeTab ~= "BiS" then return end

    local specID = self.selectedSpecID
    local BiSModule = ns:GetModule("BiS")
    if not BiSModule or not specID then return end

    for _, entry in ipairs(BiSModule:GetForSpec(specID)) do
        if entry.itemID == itemID then
            self:RenderBiS(ns.GuideStore:GetGuide(specID), specID)
            return
        end
    end
end

-- Same two-click confirm as Codex:OnDeleteLoadoutClicked (see its comment for
-- why the timer callback resets to the idle label unconditionally).
function Codex:OnDeleteBiSClicked(button, specID, index)
    if button.armed then
        local BiSModule = ns:GetModule("BiS")
        BiSModule:Delete(specID, index)
        button.armed = false
        if self.activeTab == "BiS" then self:RenderActiveTab() end
        return
    end

    button.armed = true
    button:SetText("Confirm?")
    C_Timer.After(4, function()
        button.armed = false
        pcall(button.SetText, button, "Delete")
    end)
end

function Codex:RenderBiS(guide, specID)
    self:EnsureBiSWidgets()
    local parent, width = self.scrollChild, CONTENT_WIDTH
    local pool = self.pools.bis
    local y, index = -PADDING, 0

    -- Shipped gear guidance (read-only, per DESIGN.md: "never a scraped item
    -- list" — slot + our own words on what to look for).
    local gear = guide and guide.gear
    if not gear or #gear == 0 then
        index = index + 1
        y = PlaceLine(pool, index, parent, y, width, NO_DATA_TEXT, { color = MUTED_COLOR })
    else
        for _, entry in ipairs(gear) do
            index = index + 1
            y = PlaceLine(pool, index, parent, y, width, format("%s: %s", entry.slot or "?", entry.text or ""))
        end
    end

    y = y - GROUP_GAP
    index = index + 1
    y = PlaceLine(pool, index, parent, y, width, "Personal Checklist", { color = HEADER_COLOR })
    self:FinishPool(pool, index, y)

    y = y - LINE_GAP

    -- Personal checklist. Status tags only make sense for the player's own
    -- viewed spec with a resolvable itemID (DESIGN.md).
    local BiSModule = ns:GetModule("BiS")
    local list = (BiSModule and specID) and BiSModule:GetForSpec(specID) or {}
    local rowPool = self.bisRowPool
    local isOwnSpec = IsPlayersSpec(specID)

    -- Bag contents are scanned once per render, here, rather than once per
    -- row inside BiS:GetStatus - a full checklist used to mean N x 5 bags x
    -- ~36 slots of C_Container reads on every render. Status tags (and so
    -- this scan) only ever matter for the player's own viewed spec.
    local bagSet = (isOwnSpec and BiSModule) and BiSModule:ScanBags() or nil

    if #list == 0 then
        local empty = AcquireBiSRow(rowPool, 1, parent)
        empty:ClearAllPoints()
        empty:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        empty:SetSize(width, 18)
        empty.text:SetWidth(width - BIS_ROW_TEXT_WIDTH_INSET)
        empty.text:SetText("no BiS entries yet - add one below")
        empty.text:SetTextColor(MUTED_COLOR[1], MUTED_COLOR[2], MUTED_COLOR[3])
        empty.status:SetText("")
        empty.itemID = nil
        empty.deleteButton:Hide()
        empty:Show()
        y = y - 20
        HidePoolFrom(rowPool, 2)
    else
        for i, entry in ipairs(list) do
            local row = AcquireBiSRow(rowPool, i, parent)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
            row:SetSize(width, 18)
            row.text:SetWidth(width - BIS_ROW_TEXT_WIDTH_INSET)

            local displayName, quality = BiSModule:ResolveDisplay(entry)
            local r, g, b = ItemQualityColor(quality)
            row.text:SetText(format("[%s] %s", entry.slot or "?", displayName or entry.name or "?"))
            row.text:SetTextColor(r, g, b)
            row.itemID = entry.itemID

            if isOwnSpec and entry.itemID then
                local status = BiSModule:GetStatus(entry, bagSet) or "missing"
                local color = BIS_STATUS_COLOR[status] or BIS_STATUS_COLOR.missing
                row.status:SetText(BIS_STATUS_LABEL[status] or status)
                row.status:SetTextColor(color[1], color[2], color[3])
            else
                row.status:SetText("")
            end

            row.deleteButton.armed = false
            row.deleteButton:SetText("Delete")
            row.deleteButton:Show()
            row.deleteButton:SetScript("OnClick", function(btn)
                self:OnDeleteBiSClicked(btn, specID, i)
            end)

            row:Show()
            y = y - 20
        end
        HidePoolFrom(rowPool, #list + 1)
    end

    y = y - GROUP_GAP

    -- Add row: slot cycler + editbox + Add button, own spec or any viewed
    -- spec (the checklist is per viewed specID, per DESIGN.md).
    local buttons = self.bisButtons
    buttons.slotButton:ClearAllPoints()
    buttons.slotButton:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    buttons.slotButton:Show()

    self.bisItemBox:ClearAllPoints()
    self.bisItemBox:SetPoint("LEFT", buttons.slotButton, "RIGHT", 8, 0)
    self.bisItemBox:Show()

    buttons.addButton:ClearAllPoints()
    buttons.addButton:SetPoint("LEFT", self.bisItemBox, "RIGHT", 8, 0)
    buttons.addButton:Show()

    y = y - 24

    self.scrollChild:SetHeight(math.max(-y, 10))
    pcall(self.scrollFrame.UpdateScrollChildRect, self.scrollFrame)
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

        row.copyButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.copyButton:SetSize(50, 18)
        row.copyButton:SetText("Copy")
        row.copyButton:SetPoint("RIGHT", row, "RIGHT", -58, 0)

        row.deleteButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
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

    local save = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    save:SetSize(110, 20)
    save:SetText("Save current")
    save:SetScript("OnClick", function() self:OnSaveCurrentClicked() end)

    local add = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    add:SetSize(120, 20)
    add:SetText("Add from string")
    add:SetScript("OnClick", function() self:ShowAddDialog() end)

    self.loadoutButtons = { save = save, add = add }
    self.loadoutRowPool = {}
    self:EnsureSuggestedLoadoutRow()
end

-- The one shipped-guide "Suggested Mythic+" row (DESIGN.md's v1.2 section):
-- a single frame, not pooled, since a spec has at most one mplusLoadout.
-- Built alongside the saved-loadout row pool but kept separate from it, since
-- its buttons (Copy / Add to my vault) differ from a saved row's (Copy /
-- Delete) and it never participates in the delete-by-index list.
function Codex:EnsureSuggestedLoadoutRow()
    if self.suggestedLoadoutRow then return end

    local parent = self.scrollChild
    local row = CreateFrame("Frame", nil, parent)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetJustifyH("LEFT")
    row.name:SetPoint("LEFT", row, "LEFT", 0, 0)

    row.addButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.addButton:SetSize(110, 18)
    row.addButton:SetText("Add to my vault")
    row.addButton:SetPoint("RIGHT", row, "RIGHT", -58, 0)

    row.copyButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.copyButton:SetSize(50, 18)
    row.copyButton:SetText("Copy")
    row.copyButton:SetPoint("RIGHT", row.addButton, "LEFT", -8, 0)

    row:Hide()
    self.suggestedLoadoutRow = row
end

-- Adding the shipped suggestion never writes anywhere until this click - the
-- guide's mplusLoadout stays read-only reference data (like every other
-- shipped guide field) until the player opts in, matching the existing
-- "shipped data is read-only, SpecSageDB is the user's own roster" split.
-- Confirmation is a temporary label change on the button itself (mirrors the
-- Delete row's arm/revert timer above); the newly saved loadout shows up in
-- the list below on the next render (a tab/spec switch, or the revert below)
-- rather than forcing an immediate re-render here, which would otherwise
-- stomp the "Added!" label back to its default before the player ever sees
-- it (RenderLoadouts resets this button's text every render, the same as
-- a saved row's Delete button).
function Codex:OnAddSuggestedLoadoutClicked(button, specID, exportString)
    local Loadouts = ns:GetModule("Loadouts")
    local ok, err = Loadouts:Add(specID, "Suggested M+ (SimC)", "Mythic+", exportString)
    if ok then
        button:SetText("Added!")
        C_Timer.After(2, function()
            pcall(button.SetText, button, "Add to my vault")
            if self.activeTab == "Loadouts" then self:RenderActiveTab() end
        end)
    else
        ns.Print("could not add suggested loadout: " .. tostring(err))
    end
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

function Codex:RenderLoadouts(specID, guide)
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

    -- The shipped "Suggested Mythic+" row (DESIGN.md's v1.2 section): shown
    -- above the player's own saved loadouts only when this spec's guide
    -- ships one, with no placeholder when it does not - the row simply
    -- doesn't exist rather than rendering empty.
    local suggested = self.suggestedLoadoutRow
    local mplusLoadout = guide and guide.mplusLoadout
    if mplusLoadout then
        suggested:ClearAllPoints()
        suggested:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        suggested:SetSize(width, 18)
        suggested.name:SetText(format("Suggested Mythic+ (via SimulationCraft, patch %s)", mplusLoadout.patch))
        suggested.name:SetTextColor(0.9, 0.9, 0.9)

        suggested.copyButton:Show()
        suggested.copyButton:SetScript("OnClick", function() self:ShowCopyDialog(mplusLoadout.string) end)

        suggested.addButton:SetText("Add to my vault")
        suggested.addButton:Show()
        suggested.addButton:SetScript("OnClick", function(btn)
            self:OnAddSuggestedLoadoutClicked(btn, specID, mplusLoadout.string)
        end)

        suggested:Show()
        y = y - 20
    else
        suggested:Hide()
    end

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

    local nameBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    nameBox:SetSize(336, 20)
    nameBox:SetAutoFocus(false)
    nameBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -4)
    nameBox:SetScript("OnEscapePressed", function(self2) self2:ClearFocus() end)
    nameBox:SetScript("OnEnterPressed", function() self:OnAddDialogSave() end)

    local categoryButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    categoryButton:SetSize(120, 20)
    categoryButton:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -10)
    categoryButton:SetScript("OnClick", function() self:CycleAddCategory() end)

    local importLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    importLabel:SetPoint("TOPLEFT", categoryButton, "BOTTOMLEFT", 0, -10)
    importLabel:SetText("Import string")

    local importBoxBackdrop, importBox = NewBackdropEditBox(dialog, 336, 70)
    importBoxBackdrop:SetPoint("TOPLEFT", importLabel, "BOTTOMLEFT", 0, -4)

    local saveButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    saveButton:SetSize(80, 22)
    saveButton:SetText("Save")
    saveButton:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 12, 12)
    saveButton:SetScript("OnClick", function() self:OnAddDialogSave() end)

    local cancelButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
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
    local boxBackdrop, box = NewBackdropEditBox(dialog, 336, 60)
    boxBackdrop:SetPoint("TOP", label, "BOTTOM", 0, -8)

    local closeButton = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    closeButton:SetSize(24, 24)
    closeButton:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -2, -2)
    closeButton:SetScript("OnClick", function() dialog:Hide() end)

    self.copyDialog = dialog
    self.copyBox = box
end

function Codex:ShowCopyDialog(exportString)
    self:EnsureCopyDialog()
    -- Show first: EditBox:SetFocus() is a no-op on a hidden widget in the
    -- real client, so focusing/highlighting before Show() leaves nothing
    -- selected for Ctrl+C despite the dialog's own "Ctrl+C to copy" label.
    self.copyDialog:Show()
    self.copyBox:SetText(exportString or "")
    self.copyBox:SetFocus()
    self.copyBox:HighlightText()
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

    local backdrop, box = NewBackdropEditBox(self.scrollChild, CONTENT_WIDTH, 400)
    pcall(box.SetJustifyH, box, "LEFT")
    box:SetScript("OnEditFocusLost", function(self2) self:SaveNotes(self2) end)

    self.notesBoxFrame = backdrop
    self.notesBox = box
end

function Codex:RenderNotes(specID)
    self:EnsureNotesBox()
    local backdrop, box = self.notesBoxFrame, self.notesBox

    backdrop:ClearAllPoints()
    backdrop:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, -PADDING)
    backdrop:SetSize(CONTENT_WIDTH, 400)
    box.specID = specID

    local Notes = ns:GetModule("Notes")
    box:SetText((Notes and specID) and Notes:Get(specID) or "")
    backdrop:Show()
    box:Show()

    self.scrollChild:SetHeight(420)
end

--------------------------------------------------------------------------------
-- Tab dispatch
--------------------------------------------------------------------------------

-- Every simple-text pool, plus the Loadouts row pool and the Notes box, are
-- hidden before rendering the newly active tab; only one tab's widgets are
-- ever visible at a time, all sharing the same scroll child.
local POOL_BY_TAB = { Overview = "overview", Stats = "stats", Rotation = "rotation", Cooldowns = "cooldowns", Consumables = "consumables", BiS = "bis" }

function Codex:HideOtherTabWidgets(activeTab)
    for tabName, poolName in pairs(POOL_BY_TAB) do
        if tabName ~= activeTab then
            HidePoolFrom(self.pools[poolName], 1)
        end
    end

    if activeTab ~= "BiS" then
        if self.bisButtons then
            self.bisButtons.slotButton:Hide()
            self.bisButtons.addButton:Hide()
        end
        -- ClearFocus before Hide: a focused EditBox that is hidden without
        -- releasing keyboard focus is a long-standing source of "my
        -- keybinds stopped working" reports (same fix as self.notesBox
        -- below).
        if self.bisItemBox then
            self.bisItemBox:ClearFocus()
            self.bisItemBox:Hide()
        end
        if self.bisRowPool then HidePoolFrom(self.bisRowPool, 1) end
    end

    if activeTab ~= "Loadouts" then
        if self.loadoutButtons then
            self.loadoutButtons.save:Hide()
            self.loadoutButtons.add:Hide()
        end
        if self.loadoutRowPool then HidePoolFrom(self.loadoutRowPool, 1) end
        if self.suggestedLoadoutRow then self.suggestedLoadoutRow:Hide() end
    end

    if activeTab ~= "Notes" then
        if self.notesBoxFrame then self.notesBoxFrame:Hide() end
        if self.notesBox then
            self.notesBox:ClearFocus()
            self.notesBox:Hide()
        end
    end
end

function Codex:RenderActiveTab()
    if not self.frame then return end

    local specID = self.selectedSpecID
    local guide = specID and ns.GuideStore:GetGuide(specID) or nil
    -- Defensive fallback alongside OnInit: activeTab should already be set by
    -- the time anything renders, but never draw nothing just because it
    -- somehow was not.
    local tab = self.activeTab or "Overview"
    self.activeTab = tab

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
    elseif tab == "BiS" then
        self:RenderBiS(guide, specID)
    elseif tab == "Loadouts" then
        self:RenderLoadouts(specID, guide)
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
    -- Flush whatever note is open against the spec it belongs to before
    -- swapping in a different spec: clicking a spec-rail button does not
    -- clear an EditBox's focus in WoW, so RenderNotes below would otherwise
    -- silently overwrite the still-open buffer with the new spec's saved
    -- note. Also close the Add/Copy dialogs, which otherwise stay open
    -- across the switch and would write (or show) against whatever spec is
    -- now selected instead of the one the player was looking at.
    self:SaveNotes()
    self:HideAddDialog()
    if self.copyDialog then self.copyDialog:Hide() end
    -- The BiS Add row gets the same treatment as Notes/the Add dialog:
    -- clicking a spec-rail button does not clear an EditBox's focus in WoW,
    -- so a half-typed item would otherwise silently land against whichever
    -- spec is selected when Add is next clicked, not the one it was typed
    -- while viewing.
    if self.bisItemBox then
        self.bisItemBox:ClearFocus()
        self.bisItemBox:SetText("")
    end

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

    self:SaveNotes()
    self:HideAddDialog()
    if self.copyDialog then self.copyDialog:Hide() end
    if self.bisItemBox then
        self.bisItemBox:ClearFocus()
        self.bisItemBox:SetText("")
    end

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
        btn:SetSize(CLASS_RAIL_WIDTH - 8, 26)
        btn:SetPoint("TOPLEFT", rail, "TOPLEFT", 4, y)

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("LEFT", btn, "LEFT", 0, 0)
        icon:SetTexture(CLASS_ICON_TEXTURE)
        local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[entry.token]
        if coords then icon:SetTexCoord(unpack(coords)) end
        btn.icon = icon

        -- DESIGN.md: "class icon + class-coloured name" - the name's colour
        -- is permanent (it is what makes the rail class-coloured at all);
        -- UpdateClassHighlight dims the whole button via alpha for
        -- whichever class is not currently selected.
        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetJustifyH("LEFT")
        label:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        label:SetText(entry.name)
        local color = ClassColor(entry.token)
        label:SetTextColor(color.r, color.g, color.b)
        btn.label = label

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
        y = y - 28
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
        local btn = CreateFrame("Button", nil, strip, "UIPanelButtonTemplate")
        btn:SetSize(TAB_BUTTON_WIDTH, TAB_HEIGHT)
        btn:SetPoint("TOPLEFT", strip, "TOPLEFT", x, 0)
        btn:SetText(tabName)
        btn:SetScript("OnClick", function() self:SelectTab(tabName) end)
        self.tabButtons[tabName] = btn
        x = x + TAB_BUTTON_STRIDE
    end
end

function Codex:BuildContentArea()
    -- Named (rather than anonymous): UIPanelScrollFrameTemplate has, in past
    -- client revisions, resolved its scrollbar via the frame's own global
    -- name when self.ScrollBar is not set by a parentKey; an anonymous frame
    -- makes that a concat-on-nil risk for no benefit.
    local scrollFrame = CreateFrame("ScrollFrame", "SpecSageCodexScrollFrame", self.frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", self.tabStrip, "BOTTOMLEFT", 0, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -28, 8)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(CONTENT_WIDTH)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    self.scrollFrame = scrollFrame
    self.scrollChild = scrollChild
    self.pools = { overview = {}, stats = {}, rotation = {}, cooldowns = {}, consumables = {}, bis = {} }
end

function Codex:BuildFrame()
    local frame = CreateFrame("Frame", "SpecSageCodexFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)

    local pos = (ns.db and ns.db.codexPosition) or ns.DEFAULTS.codexPosition
    frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)

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
    frame:SetScript("OnDragStop", function(self2)
        self2:StopMovingOrSizing()
        local point, _, relPoint, x, y = self2:GetPoint()
        local saved = ns.db and ns.db.codexPosition
        if saved then
            saved.point, saved.relPoint, saved.x, saved.y = point, relPoint, x, y
        end
    end)
    -- Notes save on window close as well as on focus-lost, so a note typed
    -- and then closed without tabbing away is never lost.
    frame:SetScript("OnHide", function() self:SaveNotes() end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -8)
    title:SetText(ns.version and ("SpecSage Codex " .. ns.version) or "SpecSage Codex")
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
