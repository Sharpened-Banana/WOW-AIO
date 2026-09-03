-- UI/CharacterPanel.lua
-- The gearing panel docked to Blizzard's character sheet.
--
-- The Codex already holds all of this, but it is a separate window you have
-- to go and open. The one screen where stat priority and BiS actually get
-- used is the character sheet, while you are looking at the piece you just
-- picked up - so this puts the same data there, anchored to CharacterFrame's
-- right edge and following it open and closed.
--
-- Two halves, both about the slot in front of you:
--   * Stat Priority - the spec's order with the player's live rating beside
--     each stat, then Wowhead's per-hero-tree orders under it.
--   * BiS: <Slot>   - the guide's item(s) for whichever paper doll slot the
--     mouse last touched, with an equipped/owned/missing tag.
--
-- Data comes from the same GuideStore this addon's Codex reads; nothing here
-- owns guide content. Rendering deliberately mirrors UI/Codex.lua's row
-- pooling rather than sharing it: the Codex's pools live on its own frame
-- and are sized to its layout, and threading a second parent through every
-- one of its Render* paths would couple two windows that only happen to draw
-- similar rows today.

local ADDON, ns = ...

local CharacterPanel = ns:NewModule("CharacterPanel")

--------------------------------------------------------------------------------
-- Layout and palette, matching UI/Codex.lua's "Blizzard Modern" pass
--------------------------------------------------------------------------------

-- The panel matches the character sheet's own dimensions rather than sizing
-- itself to its content: it is a docked second page of that window, and a
-- panel whose top and bottom edges did not line up with the sheet's read as
-- something floating next to it. Both are taken from CharacterFrame at draw
-- time - height through anchors on both corners, width through GetWidth -
-- so it keeps matching when Blizzard resizes the sheet (its side tabs for
-- titles and equipment sets do exactly that). The constants below are only
-- the fallback for a client that reports no size at all.
local FALLBACK_WIDTH = 338
local SCROLLBAR_INSET = 26
local PADDING = 10
local ROW_HEIGHT = 16
local ROW_STEP = 18
local SECTION_GAP = 10

local PANEL_BACKDROP_COLOR = { 0.10, 0.13, 0.16, 0.97 }
local PANEL_BORDER_COLOR = { 0.15, 0.18, 0.22, 1 }
local HEADER_COLOR = { 0.388, 0.737, 0.902 }
local MUTED_COLOR = { 0.392, 0.455, 0.541 }
local CONDITION_COLOR = { 0.55, 0.75, 0.95 }
local TEXT_PRIMARY_COLOR = { 0.906, 0.929, 0.953 }
local TEXT_SECONDARY_COLOR = { 0.651, 0.706, 0.761 }
local DEFAULT_ITEM_COLOR = { 0.62, 0.62, 0.62 }

-- Matches the Codex's BiS tab tags so the two surfaces read the same.
local STATUS_COLORS = {
    equipped = { 0.20, 0.80, 0.20 },
    owned    = { 0.95, 0.85, 0.20 },
    missing  = { 0.55, 0.55, 0.55 },
}

local STAT_LABELS = {
    primary = "Primary", crit = "Crit", haste = "Haste", mastery = "Mastery",
    versatility = "Vers", leech = "Leech", avoidance = "Avoid",
    speed = "Speed", armor = "Armor", stamina = "Stamina",
}

-- Blizzard's paper doll slot button names -> Data/API.lua's 14-slot
-- vocabulary. Both ring and both trinket buttons collapse onto the single
-- "Ring"/"Trinket" the guides use, which is why a slot can yield two rows.
local SLOT_BY_BUTTON = {
    CharacterHeadSlot = "Head",
    CharacterNeckSlot = "Neck",
    CharacterShoulderSlot = "Shoulder",
    CharacterBackSlot = "Back",
    CharacterChestSlot = "Chest",
    CharacterWristSlot = "Wrist",
    CharacterHandsSlot = "Hands",
    CharacterWaistSlot = "Waist",
    CharacterLegsSlot = "Legs",
    CharacterFeetSlot = "Feet",
    CharacterFinger0Slot = "Ring",
    CharacterFinger1Slot = "Ring",
    CharacterTrinket0Slot = "Trinket",
    CharacterTrinket1Slot = "Trinket",
    CharacterMainHandSlot = "Weapon",
    CharacterSecondaryHandSlot = "Off-hand",
}

local format = string.format
local GetItemInfoAPI = (C_Item and C_Item.GetItemInfo) or GetItemInfo

--------------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------------

local function ItemQualityColor(quality)
    local entry = ITEM_QUALITY_COLORS and quality and ITEM_QUALITY_COLORS[quality]
    if entry then return entry.r, entry.g, entry.b end
    return DEFAULT_ITEM_COLOR[1], DEFAULT_ITEM_COLOR[2], DEFAULT_ITEM_COLOR[3]
end

local function ColorCode(rgb)
    return format("|cff%02x%02x%02x", math.floor(rgb[1] * 255 + 0.5),
        math.floor(rgb[2] * 255 + 0.5), math.floor(rgb[3] * 255 + 0.5))
end

-- The spec the player is actually on. The panel is always about the player's
-- own character - unlike the Codex, there is nothing here to browse - so a
-- failed lookup means "draw nothing" rather than falling back to a default.
local function PlayerSpecID()
    local getSpec = GetSpecialization
    local getInfo = GetSpecializationInfo
    if not (getSpec and getInfo) then return nil end
    local ok, index = pcall(getSpec)
    if not ok or not index then return nil end
    local ok2, specID = pcall(getInfo, index)
    if not ok2 then return nil end
    return specID
end

local function Settings()
    return (ns.db and ns.db.characterPanel) or {}
end

--------------------------------------------------------------------------------
-- Frame construction
--------------------------------------------------------------------------------

local function AcquireRow(pool, index, parent)
    local row = pool[index]
    if row then return row end

    row = CreateFrame("Frame", nil, parent)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetJustifyH("LEFT")
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    pcall(row.text.SetWordWrap, row.text, true)

    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.value:SetJustifyH("RIGHT")
    row.value:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)

    -- Item rows behave like the Codex's: hover for the tooltip, click for the
    -- clickable ItemRefTooltip, shift-click to link into chat.
    row:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        pcall(function()
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local item = self.itemLink or self.itemID
            if type(item) == "string" then
                GameTooltip:SetHyperlink(item)
            else
                GameTooltip:SetItemByID(item)
            end
            GameTooltip:Show()
        end)
    end)
    row:SetScript("OnLeave", function() pcall(function() GameTooltip:Hide() end) end)
    row:SetScript("OnMouseUp", function(self, button)
        if not self.itemID then return end
        local item = self.itemLink or self.itemID
        local link = item
        if GetItemInfoAPI then
            local ok, _, realLink = pcall(GetItemInfoAPI, item)
            if ok and type(realLink) == "string" and realLink ~= "" then link = realLink end
        end
        if type(link) ~= "string" then link = "item:" .. tostring(link) end
        pcall(function()
            if HandleModifiedItemClick and HandleModifiedItemClick(link) then return end
            if SetItemRef then
                SetItemRef(link:match("|H(.-)|h") or link, link, button or "LeftButton")
            end
        end)
    end)

    pool[index] = row
    return row
end

local function HidePoolFrom(pool, fromIndex)
    for i = fromIndex, #pool do
        pool[i]:Hide()
    end
end

-- The width available to a row: the panel minus its padding and the room the
-- scrollbar needs on the right.
function CharacterPanel:ContentWidth()
    local width = self.frame and self.frame:GetWidth() or 0
    if not width or width <= 0 then width = FALLBACK_WIDTH end
    return width - PADDING * 2 - SCROLLBAR_INSET
end

function CharacterPanel:BuildFrame()
    if self.frame then return self.frame end
    if not CharacterFrame then return nil end

    local frame = CreateFrame("Frame", "SpecSageCharacterPanel", CharacterFrame, "BackdropTemplate")
    -- Anchoring both left corners to the sheet's right corners is what makes
    -- the height match exactly and keep matching; only the width has to be
    -- pushed across by hand (SyncSize, called on every Update).
    frame:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", -2, 0)
    frame:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMRIGHT", -2, 0)
    frame:SetWidth(FALLBACK_WIDTH)
    pcall(frame.SetBackdrop, frame, {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    pcall(frame.SetBackdropColor, frame, unpack(PANEL_BACKDROP_COLOR))
    pcall(frame.SetBackdropBorderColor, frame, unpack(PANEL_BORDER_COLOR))
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -PADDING)
    title:SetTextColor(unpack(HEADER_COLOR))
    frame.title = title

    -- Fixed height means the content can outrun the panel on a spec with a
    -- long priority and two BiS rows, so it scrolls rather than being cut
    -- off. Named for the same reason the Codex's is (see UI/Codex.lua).
    local scrollFrame = CreateFrame("ScrollFrame", "SpecSageCharacterPanelScroll", frame,
        "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(PADDING + 22))
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -SCROLLBAR_INSET, PADDING)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(self:ContentWidth())
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    frame.scrollFrame = scrollFrame
    frame.scrollChild = scrollChild

    -- Cycles which BiS context the item rows come from (Overall / Mythic+ /
    -- Raid / Wowhead). Its own setting rather than the Codex's, so opening
    -- the character sheet never quietly changes what the Codex is showing.
    local listToggle = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    listToggle:SetSize(110, 18)
    listToggle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, -PADDING + 2)
    listToggle:SetScript("OnClick", function() self:CycleList() end)
    frame.listToggle = listToggle

    self.frame = frame
    self.rows = {}
    return frame
end

-- The show/hide checkbox that lives on the character sheet itself, so the
-- panel can be turned off from where you see it rather than only from the
-- options panel. Both write the same saved setting.
function CharacterPanel:BuildToggle()
    if self.toggle then return self.toggle end
    if not CharacterFrame then return nil end

    local toggle = CreateFrame("CheckButton", "SpecSageCharacterPanelToggle", CharacterFrame,
        "UICheckButtonTemplate")
    toggle:SetSize(22, 22)
    toggle:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -46, -26)
    toggle:SetScript("OnClick", function(button)
        local checked = button:GetChecked() and true or false
        Settings().enabled = checked
        self:Update()
    end)
    toggle:SetScript("OnEnter", function(button)
        pcall(function()
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText("SpecSage gearing panel")
            GameTooltip:AddLine("Stat priority and the BiS item for the slot you hover.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
    end)
    toggle:SetScript("OnLeave", function() pcall(function() GameTooltip:Hide() end) end)

    self.toggle = toggle
    return toggle
end

--------------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------------

local function PlaceRow(pool, index, parent, width, y, text, opts)
    opts = opts or {}
    local row = AcquireRow(pool, index, parent)
    local indent = opts.indent or 0
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", indent, y)
    row:SetSize(width - indent, ROW_HEIGHT)

    local valueWidth = (opts.value and opts.value ~= "") and 62 or 0
    row.text:SetWidth(width - indent - valueWidth)
    row.text:SetText(text or "")
    local color = opts.color or TEXT_PRIMARY_COLOR
    row.text:SetTextColor(color[1], color[2], color[3])

    row.value:SetText(opts.value or "")
    row.value:SetTextColor(TEXT_SECONDARY_COLOR[1], TEXT_SECONDARY_COLOR[2], TEXT_SECONDARY_COLOR[3])

    row.itemID = opts.itemID
    row.itemLink = opts.itemLink
    row:EnableMouse(opts.itemID ~= nil)
    row:Show()

    -- A wrapped item row can run to two lines; measure rather than assume.
    local height = ROW_HEIGHT
    local ok, measured = pcall(row.text.GetStringHeight, row.text)
    if ok and measured and measured > ROW_HEIGHT then
        height = measured
        row:SetHeight(height)
    end
    return y - (height + (ROW_STEP - ROW_HEIGHT))
end

-- The BiS rows for `slot` out of the spec's active list. Ring and Trinket
-- legitimately return two rows; every other slot returns one, or none when
-- the list has nothing for it (a two-hander spec has no Off-hand row).
function CharacterPanel:RowsForSlot(specID, slot)
    local data = specID and ns.GuideStore and ns.GuideStore:GetBiS(specID)
    if not data or not data.lists or #data.lists == 0 or not slot then return nil, nil end

    local index = Settings().listIndex or 1
    if index > #data.lists or index < 1 then index = 1 end
    local active = data.lists[index]

    local out = {}
    for _, entry in ipairs(active.list) do
        if entry.slot == slot then out[#out + 1] = entry end
    end
    return out, active.title
end

function CharacterPanel:Render()
    local frame = self.frame
    if not frame then return end

    local pool = self.rows
    local child = frame.scrollChild
    local width = self:ContentWidth()
    child:SetWidth(width)
    local specID = PlayerSpecID()
    local guide = specID and ns.GuideStore and ns.GuideStore:GetGuide(specID)
    local y, index = 0, 0

    frame.title:SetText((guide and guide.specName) or "SpecSage")

    -- Stat priority, with the player's live rating beside each stat.
    local StatsModule = ns:GetModule("Stats")
    local priorities = guide and guide.statPriority
    index = index + 1
    y = PlaceRow(pool, index, child, width, y, "Stat Priority", { color = HEADER_COLOR })
    if not priorities or #priorities == 0 then
        index = index + 1
        y = PlaceRow(pool, index, child, width, y, "no stat priority for this spec", { color = MUTED_COLOR })
    else
        for order, entry in ipairs(priorities) do
            local value = StatsModule and StatsModule:GetStatValue(entry.stat) or nil
            index = index + 1
            y = PlaceRow(pool, index, child, width, y,
                format("%d. %s", order, STAT_LABELS[entry.stat] or entry.stat),
                { value = value })
        end
    end

    -- Wowhead's per-hero-tree orders (Data/StatPriority.lua). Names only, no
    -- live values: these are alternatives to the order above, not extra rows
    -- of the player's own stats.
    local statData = specID and ns.GuideStore and ns.GuideStore:GetStatPriority(specID)
    if statData and statData.lists then
        y = y - SECTION_GAP
        index = index + 1
        y = PlaceRow(pool, index, child, width, y, "By Hero Talent Tree", { color = HEADER_COLOR })
        for _, listEntry in ipairs(statData.lists) do
            local names = {}
            for order, entry in ipairs(listEntry.list) do
                names[order] = STAT_LABELS[entry.stat] or entry.stat
            end
            index = index + 1
            y = PlaceRow(pool, index, child, width, y, listEntry.title, { color = CONDITION_COLOR })
            index = index + 1
            y = PlaceRow(pool, index, child, width, y, table.concat(names, " > "),
                { color = TEXT_SECONDARY_COLOR, indent = 10 })
        end
    end

    -- BiS for the slot the mouse last touched on the paper doll.
    y = y - SECTION_GAP
    local slot = self.hoveredSlot
    local entries, listTitle = self:RowsForSlot(specID, slot)
    frame.listToggle:SetText(listTitle or "")
    frame.listToggle:SetShown(listTitle ~= nil)

    index = index + 1
    y = PlaceRow(pool, index, child, width, y, slot and ("BiS: " .. slot) or "Best in Slot",
        { color = HEADER_COLOR })

    if not slot then
        index = index + 1
        y = PlaceRow(pool, index, child, width, y, "hover a gear slot to see its BiS item",
            { color = MUTED_COLOR })
    elseif not entries or #entries == 0 then
        index = index + 1
        y = PlaceRow(pool, index, child, width, y, format("no %s in this list", slot), { color = MUTED_COLOR })
    else
        local BiSModule = ns:GetModule("BiS")
        for _, entry in ipairs(entries) do
            local item = ns.ItemString(entry.itemID, entry.bonus)
            local name, quality = entry.name
            if GetItemInfoAPI then
                local ok, realName, _, realQuality = pcall(GetItemInfoAPI, item)
                if ok and type(realName) == "string" and realName ~= "" then
                    name, quality = realName, realQuality
                elseif C_Item and C_Item.RequestLoadItemDataByID then
                    pcall(C_Item.RequestLoadItemDataByID, entry.itemID)
                end
            end
            local status = BiSModule and BiSModule:GetStatus(entry) or nil
            local statusText = ""
            if status then
                statusText = format("  %s%s|r", ColorCode(STATUS_COLORS[status] or MUTED_COLOR), status)
            end
            local r, g, b = ItemQualityColor(quality)
            index = index + 1
            y = PlaceRow(pool, index, child, width, y,
                format("%s%s|r%s", ColorCode({ r, g, b }), name, statusText),
                { itemID = entry.itemID, itemLink = (item ~= entry.itemID) and item or nil })
            if entry.from and entry.from ~= "" then
                index = index + 1
                y = PlaceRow(pool, index, child, width, y, entry.from,
                    { color = MUTED_COLOR, indent = 10 })
            end
        end
    end

    HidePoolFrom(pool, index + 1)
    -- The panel's own height is fixed to the character sheet's; it is the
    -- scroll child that grows with the content.
    child:SetHeight(math.max(-y, 1))
    pcall(frame.scrollFrame.UpdateScrollChildRect, frame.scrollFrame)
end

--------------------------------------------------------------------------------
-- Visibility and events
--------------------------------------------------------------------------------

function CharacterPanel:CycleList()
    local specID = PlayerSpecID()
    local data = specID and ns.GuideStore and ns.GuideStore:GetBiS(specID)
    local count = (data and data.lists and #data.lists) or 1
    local settings = Settings()
    settings.listIndex = ((settings.listIndex or 1) % count) + 1
    self:Update()
end

function CharacterPanel:IsEnabled()
    return Settings().enabled ~= false
end

-- Pushes the character sheet's width across. Height needs nothing: the panel
-- is anchored to both of the sheet's right-hand corners, so it already tracks
-- any height the sheet takes. A sheet that reports no width yet (built but
-- not laid out) leaves the fallback in place rather than collapsing to zero.
function CharacterPanel:SyncSize()
    if not (self.frame and CharacterFrame) then return end
    local ok, width = pcall(CharacterFrame.GetWidth, CharacterFrame)
    if ok and type(width) == "number" and width > 0 then
        self.frame:SetWidth(width)
    end
end

-- The single place visibility is decided: the panel is shown when the
-- character sheet is open and the setting is on, and drawn only when shown.
function CharacterPanel:Update()
    local frame = self:BuildFrame()
    if not frame then return end
    if self.toggle then self.toggle:SetChecked(self:IsEnabled()) end
    self:SyncSize()

    local open = CharacterFrame and CharacterFrame:IsShown()
    if open and self:IsEnabled() then
        self:Render()
        frame:Show()
    else
        frame:Hide()
    end
end

function CharacterPanel:SetHoveredSlot(slot)
    if self.hoveredSlot == slot then return end
    self.hoveredSlot = slot
    -- Only redraw when the panel is actually up; hovering gear with the
    -- panel off should cost nothing.
    if self.frame and self.frame:IsShown() then self:Render() end
end

-- Hooks Blizzard's frames. Kept separate from OnEnable so it can be retried:
-- the character sheet is base UI in retail, but a client that has not built
-- it yet must not leave the panel permanently dead.
function CharacterPanel:HookBlizzardFrames()
    if self.hooked then return true end
    if not CharacterFrame then return false end

    self:BuildFrame()
    self:BuildToggle()

    CharacterFrame:HookScript("OnShow", function() self:Update() end)
    CharacterFrame:HookScript("OnHide", function()
        if self.frame then self.frame:Hide() end
    end)

    -- The paper doll slot buttons drive which BiS row is shown. HookScript
    -- leaves Blizzard's own handlers (the item tooltip) running.
    for buttonName, slot in pairs(SLOT_BY_BUTTON) do
        local button = _G[buttonName]
        if button and button.HookScript then
            button:HookScript("OnEnter", function() self:SetHoveredSlot(slot) end)
        end
    end

    self.hooked = true
    return true
end

function CharacterPanel:OnEnable()
    if not self:HookBlizzardFrames() then
        -- Retail loads the character sheet with the base UI, so this is a
        -- belt-and-braces retry for a client that somehow has not yet.
        ns:RegisterEvent("PLAYER_ENTERING_WORLD", function() self:HookBlizzardFrames() end)
        return
    end
    self:Update()
end

-- Equipping something changes both the live stat values and the
-- equipped/owned tags, so the panel redraws with the character sheet open.
function CharacterPanel:OnInit()
    ns:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function()
        if self.frame and self.frame:IsShown() then self:Render() end
    end)
    ns:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function()
        if self.frame and self.frame:IsShown() then self:Render() end
    end)
    ns:RegisterEvent("GET_ITEM_INFO_RECEIVED", function()
        if self.frame and self.frame:IsShown() then self:Render() end
    end)
end
