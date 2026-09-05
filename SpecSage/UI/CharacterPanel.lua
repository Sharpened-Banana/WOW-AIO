-- UI/CharacterPanel.lua
-- The gearing panel docked to Blizzard's character sheet.
--
-- The Codex already holds all of this, but it is a separate window you have
-- to go and open. The one screen where stat priority and BiS actually get
-- used is the character sheet, while you are looking at the piece you just
-- picked up - so this puts the same data there, anchored to CharacterFrame's
-- right edge and following it open and closed.
--
-- It shows everything the Codex window does, one section at a time down a
-- single column. The sections are picked from a column of icon tabs hanging
-- off the panel's right edge, the way Blizzard's own character sheet hangs
-- its titles and equipment-set tabs off its side: the Codex's horizontal
-- strip needs roughly twice this panel's width, but ten 32px icons stacked
-- down the side fit comfortably inside the sheet's height and cost the
-- content no room at all.
--
-- Sections are the Codex's own tabs plus one of this panel's own:
--   * Gear  - the spec's stat priority with the player's live rating beside
--     each stat, Wowhead's per-hero-tree orders, and the guide's item(s) for
--     whichever paper doll slot the mouse last touched. The one view that
--     only makes sense here, because only here is there a paper doll to
--     hover. Rendered by this file.
--   * Overview / Stats / Rotation / Cooldowns / Consumables / BiS /
--     Loadouts / Notes / Options - rendered by UI/Codex.lua's own methods,
--     not copies of them. Codex:NewSurface hands back a table carrying the
--     per-window frames, row pools and view state those methods reach
--     through `self`, with `__index` pointing at the Codex, so the same code
--     draws into this panel's scroll area. Duplicating nine render paths so
--     two windows could show the same guide was never going to stay correct.

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
-- Space between the sheet's right edge and the panel's left. It used to
-- overlap the sheet by 2px to read as one window; the owner wanted it set
-- off to the right instead, clear of the sheet's own side tabs.
local DOCK_GAP = 16
-- The grip in the panel's top-left corner. Dragging it moves the panel
-- right or down from its docked spot (never left or up, so it cannot cover
-- the sheet or its side tabs); the offset is saved and the panel keeps
-- following the sheet from there. Right-click puts it back.
local GRIP_SIZE = 16
-- Drawn as a 2x3 dot grid from plain colour textures rather than a client
-- texture file: the first cut pointed at a cursor texture that this client
-- build does not ship, and the grip came out invisible.
local GRIP_DOT = 3
local GRIP_COLOR = { 0.541, 0.478, 0.369, 0.9 }
-- The panel follows the sheet's size until the bottom-right grip has been
-- dragged; from then on it keeps its own. Right-click on that grip goes
-- back to following. The floor keeps the side tabs on the panel and a row
-- readable.
local MIN_WIDTH = 260
local MIN_HEIGHT = 30 + 10 * 36 + 8
local SCROLLBAR_INSET = 26
local PADDING = 10
local TITLE_HEIGHT = 20
local FOOTER_HEIGHT = 24

-- The side tabs: icon buttons hung off the panel's right edge, the size of
-- Blizzard's own character-sheet side tabs. Ten of them at this stride run
-- 360px, well inside the sheet's height.
local TAB_SIZE = 32
local TAB_STRIDE = 36
local TAB_TOP_OFFSET = 30
local TAB_ICON_INSET = 3

-- How long a burst of redraw requests is held before one redraw happens.
-- Opening the sheet asks the client for every item the section shows, and
-- each answer arrives as its own GET_ITEM_INFO_RECEIVED; drawing on every
-- one turned a list of forty items into forty full redraws inside a second,
-- which is a visible freeze. One redraw per interval covers a burst.
local RENDER_THROTTLE = 0.25

-- The Codex's own tabs, plus this panel's Gear section in front of them.
-- Gear is first because it is the reason to have the panel docked at all:
-- it is the only view that reacts to the paper doll next to it.
local GEAR_SECTION = "Gear"
local SECTIONS = {
    GEAR_SECTION, "Overview", "Stats", "Rotation", "Cooldowns",
    "Consumables", "BiS", "Loadouts", "Notes", "Options",
}

-- One icon per section, from the client's own icon set. The section name is
-- in the tab's tooltip and in the panel's header, so the icon only has to be
-- recognisable, not self-explanatory.
local SECTION_ICONS = {
    Gear        = "Interface\\Icons\\INV_Chest_Plate16",
    Overview    = "Interface\\Icons\\INV_Misc_Book_09",
    Stats       = "Interface\\Icons\\Spell_Nature_EnchantArmor",
    Rotation    = "Interface\\Icons\\Ability_Rogue_SliceDice",
    Cooldowns   = "Interface\\Icons\\Spell_Holy_BorrowedTime",
    Consumables = "Interface\\Icons\\INV_Potion_51",
    BiS         = "Interface\\Icons\\INV_Misc_Bag_10_Blue",
    Loadouts    = "Interface\\Icons\\Ability_Marksmanship",
    Notes       = "Interface\\Icons\\INV_Misc_Note_01",
    Options     = "Interface\\Icons\\Trade_Engineering",
}
local ROW_HEIGHT = 16
local ROW_STEP = 18
local SECTION_GAP = 10

-- The Tome skin (2026-09-05), matching UI/Codex.lua: a single chart page
-- in a leather edge, ink text, wax red for emphasis. Side tabs are leather
-- with the open one sealed in wax.
local TEXTURE_PATH = "Interface\\AddOns\\SpecSage\\Textures\\"
local LEATHER_COLOR = { 0.231, 0.165, 0.110, 1 }       -- #3B2A1C
local PANEL_BORDER_COLOR = { 0.102, 0.071, 0.043, 1 }  -- #1A120B
local TAB_BACKDROP_COLOR = LEATHER_COLOR
local TAB_ACTIVE_COLOR = { 0.478, 0.184, 0.122, 1 }    -- wax red
local RULE_COLOR = { 0.431, 0.353, 0.227 }             -- #6E5A3A
local GOLD_COLOR = { 0.851, 0.706, 0.416 }             -- #D9B46A
local HEADER_COLOR = { 0.169, 0.122, 0.078 }           -- ink
local MUTED_COLOR = { 0.541, 0.478, 0.369 }            -- #8A7A5E
local CONDITION_COLOR = { 0.478, 0.184, 0.122 }        -- wax red
local TEXT_PRIMARY_COLOR = { 0.169, 0.122, 0.078 }
local TEXT_SECONDARY_COLOR = { 0.353, 0.275, 0.188 }
local DEFAULT_ITEM_COLOR = { 0.35, 0.35, 0.35 }

-- Matches the Codex's BiS tab tags so the two surfaces read the same.
local STATUS_COLORS = {
    equipped = { 0.25, 0.42, 0.23 },   -- ink green, readable on paper
    owned    = { 0.478, 0.184, 0.122 }, -- wax red
    missing  = { 0.541, 0.478, 0.369 }, -- faded
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

-- The class token the player is on. The Codex's renderers colour their
-- active-tab underline from it, and the panel's active side tab borrows the
-- same colour; it is also what makes a surface self-contained rather than
-- reading the Codex's selection.
local function PlayerClassToken()
    if not UnitClass then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    if ok then return token end
    return nil
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
    if SpecSageBodyFontSmall then row.text:SetFontObject(SpecSageBodyFontSmall) end
    row.text:SetJustifyH("LEFT")
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    pcall(row.text.SetWordWrap, row.text, true)

    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if SpecSageBoldFontSmall then row.value:SetFontObject(SpecSageBoldFontSmall) end
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
    frame:SetWidth(FALLBACK_WIDTH)
    self.frame = frame
    self:ApplyDockOffset()
    -- Parchment page, 4px leather edge, a hairline rule inside it.
    pcall(frame.SetBackdrop, frame, {
        bgFile = TEXTURE_PATH .. "parchment.png",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 4,
    })
    pcall(frame.SetBackdropColor, frame, 1, 1, 1, 1)
    pcall(frame.SetBackdropBorderColor, frame, unpack(LEATHER_COLOR))
    local rule = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    rule:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    rule:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
    pcall(rule.SetBackdrop, rule, { edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    pcall(rule.SetBackdropBorderColor, rule, RULE_COLOR[1], RULE_COLOR[2], RULE_COLOR[3], 0.6)
    frame:Hide()

    self:BuildGrip(frame)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if SpecSageHeadingFont then title:SetFontObject(SpecSageHeadingFont) end
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING + GRIP_SIZE + 4, -PADDING)
    title:SetTextColor(unpack(HEADER_COLOR))
    frame.title = title

    local headRule = frame:CreateTexture(nil, "ARTWORK")
    headRule:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -(PADDING + TITLE_HEIGHT + 1))
    headRule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, -(PADDING + TITLE_HEIGHT + 1))
    headRule:SetHeight(1)
    headRule:SetColorTexture(unpack(RULE_COLOR))

    -- Names the active section beside the spec name, since the side tabs
    -- are icons.
    local sectionLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if SpecSageItalicFont then sectionLabel:SetFontObject(SpecSageItalicFont) end
    sectionLabel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, -(PADDING + 4))
    sectionLabel:SetJustifyH("RIGHT")
    sectionLabel:SetTextColor(unpack(CONDITION_COLOR))
    frame.sectionLabel = sectionLabel

    self:BuildSideTabs(frame)

    -- Fixed height means the content can outrun the panel on almost any
    -- section, so it scrolls rather than being cut off. Named for the same
    -- reason the Codex's is (see UI/Codex.lua).
    local scrollFrame = CreateFrame("ScrollFrame", "SpecSageCharacterPanelScroll", frame,
        "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -(PADDING + TITLE_HEIGHT + 8))
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -SCROLLBAR_INSET, FOOTER_HEIGHT)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(self:ContentWidth())
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    frame.scrollFrame = scrollFrame
    frame.scrollChild = scrollChild

    -- Cycles which BiS context the Gear section's item rows come from
    -- (Overall / Mythic+ / Raid / Wowhead). Its own setting rather than the
    -- Codex's, so opening the character sheet never quietly changes what the
    -- Codex is showing.
    local listToggle = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    listToggle:SetSize(110, 18)
    listToggle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(PADDING + GRIP_SIZE), PADDING - 2)
    listToggle:SetScript("OnClick", function() self:CycleList() end)
    frame.listToggle = listToggle

    local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if SpecSageItalicFont then footer:SetFontObject(SpecSageItalicFont) end
    footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PADDING, PADDING)
    footer:SetTextColor(unpack(MUTED_COLOR))
    frame.footer = footer

    self:BuildResizeGrip(frame)

    self.rows = {}

    -- The Codex's own render methods, pointed at this panel's scroll area.
    -- Built here rather than lazily so nothing can render before it exists.
    local Codex = ns:GetModule("Codex")
    self.surface = Codex and Codex:NewSurface(frame, scrollFrame, scrollChild, self:ContentWidth())

    return frame
end

-- Where the panel sits relative to the sheet: DOCK_GAP to the right of its
-- right edge, plus whatever the grip has been dragged. Both left corners
-- are anchored so the height keeps tracking the sheet's.
function CharacterPanel:DockOffset()
    local settings = Settings()
    local x = tonumber(settings.offsetX) or 0
    local y = tonumber(settings.offsetY) or 0
    if x < 0 then x = 0 end
    if y > 0 then y = 0 end
    return x, y
end

-- Explicit size, or nil for "follow the sheet".
function CharacterPanel:SizeOverride()
    local settings = Settings()
    local w = tonumber(settings.width)
    local h = tonumber(settings.height)
    if w and w < MIN_WIDTH then w = MIN_WIDTH end
    if h and h < MIN_HEIGHT then h = MIN_HEIGHT end
    return w, h
end

function CharacterPanel:ApplyDockOffset()
    local frame = self.frame
    if not (frame and CharacterFrame) then return end
    local x, y = self:DockOffset()
    local _, height = self:SizeOverride()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", DOCK_GAP + x, y)
    if height then
        -- A resized panel owns its height; only the top corner follows.
        frame:SetHeight(height)
    else
        frame:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMRIGHT", DOCK_GAP + x, y)
    end
end

function CharacterPanel:SetSize(width, height)
    local settings = Settings()
    settings.width = width and math.max(MIN_WIDTH, math.floor(width + 0.5)) or nil
    settings.height = height and math.max(MIN_HEIGHT, math.floor(height + 0.5)) or nil
    self:ApplyDockOffset()
    self:SyncSize()
end

function CharacterPanel:SetDockOffset(x, y)
    local settings = Settings()
    settings.offsetX = math.max(0, math.floor((tonumber(x) or 0) + 0.5))
    settings.offsetY = math.min(0, math.floor((tonumber(y) or 0) + 0.5))
    self:ApplyDockOffset()
end

-- Cursor position in the sheet's coordinate space, so a drag delta can be
-- added straight onto the anchor offset.
local function CursorPosition()
    if not GetCursorPosition then return nil end
    local ok, cx, cy = pcall(GetCursorPosition)
    if not ok or type(cx) ~= "number" then return nil end
    local scale = 1
    if UIParent and UIParent.GetEffectiveScale then
        local ok2, s = pcall(UIParent.GetEffectiveScale, UIParent)
        if ok2 and type(s) == "number" and s > 0 then scale = s end
    end
    return cx / scale, cy / scale
end

function CharacterPanel:BuildGrip(frame)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(GRIP_SIZE, GRIP_SIZE)
    grip:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING - 2, -(PADDING - 2))
    pcall(grip.RegisterForClicks, grip, "LeftButtonUp", "RightButtonUp")

    grip.dots = {}
    local gridW = GRIP_DOT * 2 + 2
    local gridH = GRIP_DOT * 3 + 4
    local x0 = math.floor((GRIP_SIZE - gridW) / 2)
    local y0 = math.floor((GRIP_SIZE - gridH) / 2)
    for col = 0, 1 do
        for rowIndex = 0, 2 do
            local dot = grip:CreateTexture(nil, "ARTWORK")
            dot:SetSize(GRIP_DOT, GRIP_DOT)
            dot:SetPoint("TOPLEFT", grip, "TOPLEFT",
                x0 + col * (GRIP_DOT + 2), -(y0 + rowIndex * (GRIP_DOT + 2)))
            dot:SetColorTexture(unpack(GRIP_COLOR))
            grip.dots[#grip.dots + 1] = dot
        end
    end
    pcall(grip.SetHighlightTexture, grip, "Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    -- The panel is anchored to the sheet, so it cannot use StartMoving;
    -- the grip tracks the cursor itself and feeds the delta into the
    -- anchor offset while the button is held.
    grip:SetScript("OnMouseDown", function(button, mouseButton)
        if mouseButton ~= "LeftButton" then return end
        local cx, cy = CursorPosition()
        if not cx then return end
        local ox, oy = self:DockOffset()
        button.drag = { cx = cx, cy = cy, ox = ox, oy = oy }
        button:SetScript("OnUpdate", function(b)
            local d = b.drag
            local nx, ny = CursorPosition()
            if not (d and nx) then return end
            self:SetDockOffset(d.ox + (nx - d.cx), d.oy + (ny - d.cy))
        end)
    end)
    grip:SetScript("OnMouseUp", function(button, mouseButton)
        button:SetScript("OnUpdate", nil)
        button.drag = nil
        if mouseButton == "RightButton" then self:SetDockOffset(0, 0) end
    end)
    grip:SetScript("OnEnter", function(button)
        pcall(function()
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText("Move panel")
            GameTooltip:AddLine("Drag to move it right or down. Right-click to put it back.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
    end)
    grip:SetScript("OnLeave", function() pcall(function() GameTooltip:Hide() end) end)

    frame.grip = grip
end

-- The resize grip in the bottom-right corner: three dots on the diagonal.
-- Drag to size the panel; right-click to go back to following the sheet.
function CharacterPanel:BuildResizeGrip(frame)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(GRIP_SIZE, GRIP_SIZE)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    pcall(grip.RegisterForClicks, grip, "LeftButtonUp", "RightButtonUp")
    pcall(grip.SetHighlightTexture, grip, "Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    grip.dots = {}
    for i = 0, 2 do
        local dot = grip:CreateTexture(nil, "ARTWORK")
        dot:SetSize(GRIP_DOT, GRIP_DOT)
        dot:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", -(1 + i * (GRIP_DOT + 1)), 1 + i * (GRIP_DOT + 1))
        dot:SetColorTexture(unpack(GRIP_COLOR))
        grip.dots[#grip.dots + 1] = dot
        -- Fill the lower-right triangle: one extra dot beside each of the
        -- inner diagonal dots.
        if i < 2 then
            local side = grip:CreateTexture(nil, "ARTWORK")
            side:SetSize(GRIP_DOT, GRIP_DOT)
            side:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", -(1 + (i + 1) * (GRIP_DOT + 1)), 1 + i * (GRIP_DOT + 1))
            side:SetColorTexture(unpack(GRIP_COLOR))
            grip.dots[#grip.dots + 1] = side
        end
    end

    grip:SetScript("OnMouseDown", function(button, mouseButton)
        if mouseButton ~= "LeftButton" then return end
        local cx, cy = CursorPosition()
        if not cx then return end
        button.drag = { cx = cx, cy = cy, w = frame:GetWidth() or FALLBACK_WIDTH, h = frame:GetHeight() or MIN_HEIGHT }
        button:SetScript("OnUpdate", function(b)
            local d = b.drag
            local nx, ny = CursorPosition()
            if not (d and nx) then return end
            self:SetSize(d.w + (nx - d.cx), d.h - (ny - d.cy))
            self:QueueRender()
        end)
    end)
    grip:SetScript("OnMouseUp", function(button, mouseButton)
        button:SetScript("OnUpdate", nil)
        button.drag = nil
        if mouseButton == "RightButton" then self:SetSize(nil, nil) end
        if self.frame and self.frame:IsShown() then self:Render() end
    end)
    grip:SetScript("OnEnter", function(button)
        pcall(function()
            GameTooltip:SetOwner(button, "ANCHOR_LEFT")
            GameTooltip:SetText("Resize panel")
            GameTooltip:AddLine("Drag to resize. Right-click to match the character sheet again.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
    end)
    grip:SetScript("OnLeave", function() pcall(function() GameTooltip:Hide() end) end)

    frame.resizeGrip = grip
end

-- The column of icon tabs down the panel's right edge, one per section,
-- hung outside the panel's border the way the character sheet's own side
-- tabs are. Each is a small backdrop button with the section's icon; the
-- name is in its tooltip and in the panel header. frame.sectionTabs is the
-- ordered list, frame.sectionTabByName the lookup UpdateTabHighlight uses.
function CharacterPanel:BuildSideTabs(frame)
    frame.sectionTabs = {}
    frame.sectionTabByName = {}
    for i, section in ipairs(SECTIONS) do
        local tab = CreateFrame("Button", nil, frame, "BackdropTemplate")
        tab:SetSize(TAB_SIZE, TAB_SIZE)
        tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", -1, -(TAB_TOP_OFFSET + (i - 1) * TAB_STRIDE))
        pcall(tab.SetBackdrop, tab, {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        pcall(tab.SetBackdropColor, tab, unpack(TAB_BACKDROP_COLOR))
        pcall(tab.SetBackdropBorderColor, tab, unpack(PANEL_BORDER_COLOR))

        local icon = tab:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", tab, "TOPLEFT", TAB_ICON_INSET, -TAB_ICON_INSET)
        icon:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -TAB_ICON_INSET, TAB_ICON_INSET)
        icon:SetTexture(SECTION_ICONS[section])
        -- Trim the icon's baked-in border so it sits flush in the tab.
        pcall(icon.SetTexCoord, icon, 0.08, 0.92, 0.08, 0.92)
        tab.icon = icon

        -- Active marker: a 2px bar down the tab's outer edge, coloured like
        -- the Codex's active-tab underline.
        local marker = tab:CreateTexture(nil, "OVERLAY")
        marker:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -1, -1)
        marker:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -1, 1)
        marker:SetWidth(2)
        marker:Hide()
        tab.marker = marker

        pcall(tab.SetHighlightTexture, tab, "Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

        tab.section = section
        tab:SetScript("OnClick", function() self:SelectSection(section) end)
        tab:SetScript("OnEnter", function(button)
            pcall(function()
                GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                GameTooltip:SetText(section)
                GameTooltip:Show()
            end)
        end)
        tab:SetScript("OnLeave", function() pcall(function() GameTooltip:Hide() end) end)

        frame.sectionTabs[i] = tab
        frame.sectionTabByName[section] = tab
    end
end

-- The open tab is sealed in wax red with its icon at full colour; the rest
-- are leather with the icon faded. (The Blizzard Modern pass used the
-- class colour for the marker; the Tome keeps class colour off the page.)
function CharacterPanel:UpdateTabHighlight(active)
    local frame = self.frame
    if not (frame and frame.sectionTabs) then return end

    for _, tab in ipairs(frame.sectionTabs) do
        local isActive = tab.section == active
        tab.active = isActive
        tab.marker:SetShown(isActive)
        if isActive then tab.marker:SetColorTexture(GOLD_COLOR[1], GOLD_COLOR[2], GOLD_COLOR[3]) end
        pcall(tab.icon.SetDesaturated, tab.icon, not isActive)
        pcall(tab.icon.SetAlpha, tab.icon, isActive and 1 or 0.5)
        pcall(tab.SetBackdropColor, tab, unpack(isActive and TAB_ACTIVE_COLOR or TAB_BACKDROP_COLOR))
        pcall(tab.SetBackdropBorderColor, tab, unpack(PANEL_BORDER_COLOR))
    end
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
    -- Section headers in the heading face; everything else in the body.
    if opts.color == HEADER_COLOR and SpecSageHeadingFont then
        row.text:SetFontObject(SpecSageHeadingFont)
    elseif SpecSageBodyFontSmall then
        row.text:SetFontObject(SpecSageBodyFontSmall)
    end

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

-- The Gear section: this panel's own view, and the only one the Codex has
-- no equivalent of, because only here is there a paper doll to hover.
function CharacterPanel:RenderGear()
    local frame = self.frame
    if not frame then return end

    local pool = self.rows
    local child = frame.scrollChild
    local width = self:ContentWidth()
    child:SetWidth(width)
    local specID = PlayerSpecID()
    local guide = specID and ns.GuideStore and ns.GuideStore:GetGuide(specID)
    local y, index = 0, 0

    -- Stat priority, with the player's live rating beside each stat.
    -- Wowhead's order for the hero tree the player is in, when the client
    -- can say which; else the guide's flat order (GuideStore).
    local StatsModule = ns:GetModule("Stats")
    local priorities, activeTitle
    if ns.GuideStore then priorities, activeTitle = ns.GuideStore:GetActiveStatPriority(specID) end
    index = index + 1
    y = PlaceRow(pool, index, child, width, y,
        activeTitle and format("Stat Priority \194\183 %s", activeTitle) or "Stat Priority",
        { color = HEADER_COLOR })
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
            local isCurrent = activeTitle ~= nil and listEntry.title == activeTitle
            index = index + 1
            y = PlaceRow(pool, index, child, width, y, listEntry.title .. (isCurrent and "  (you)" or ""),
                { color = isCurrent and HEADER_COLOR or CONDITION_COLOR })
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
-- Sections
--------------------------------------------------------------------------------

function CharacterPanel:ActiveSection()
    local wanted = Settings().section
    for _, section in ipairs(SECTIONS) do
        if section == wanted then return section end
    end
    return GEAR_SECTION
end

function CharacterPanel:SelectSection(section)
    Settings().section = section
    self:Update()
end

-- Draws the active section. Gear is this file's own; everything else is the
-- Codex's own render method running against this panel's surface.
--
-- Whichever half draws, the other's rows have to go: the two share one
-- scroll child, so leftovers from the last section would sit under the new
-- one. HideOtherTabWidgets("Gear") does that for the Codex side - "Gear" is
-- not one of its tabs, so every pool and every tab-owned widget it knows
-- about is hidden.
function CharacterPanel:Render()
    local frame = self.frame
    if not frame then return end

    local section = self:ActiveSection()
    frame.sectionLabel:SetText(section)
    self:UpdateTabHighlight(section)

    -- The title names the spec on every section, not just Gear: the panel
    -- is always about the player's own character, and saying which spec the
    -- guidance is for matters most on the sections that never mention it.
    local specID = PlayerSpecID()
    local guide = specID and ns.GuideStore and ns.GuideStore:GetGuide(specID)
    frame.title:SetText((guide and guide.specName) or "SpecSage")

    local surface = self.surface
    if section == GEAR_SECTION then
        if surface then surface:HideOtherTabWidgets(GEAR_SECTION) end
        self:RenderGear()
    else
        HidePoolFrom(self.rows, 1)
        frame.listToggle:Hide()
        if surface then
            surface.selectedSpecID = PlayerSpecID()
            surface.selectedClass = PlayerClassToken()
            surface.activeTab = section
            surface:RenderActiveTab()
        end
    end
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

-- Pushes the character sheet's width across, unless the resize grip has
-- given the panel a width of its own. Height needs nothing here: until
-- resized the panel is anchored to both of the sheet's right-hand corners,
-- and once resized ApplyDockOffset sets it. A sheet that reports no width yet (built but
-- not laid out) leaves the fallback in place rather than collapsing to zero.
function CharacterPanel:SyncSize()
    if not (self.frame and CharacterFrame) then return end
    local width = self:SizeOverride()
    if not width then
        local ok, sheetWidth = pcall(CharacterFrame.GetWidth, CharacterFrame)
        if ok and type(sheetWidth) == "number" and sheetWidth > 0 then width = sheetWidth end
    end
    if width then self.frame:SetWidth(width) end
    -- The Codex's renderers lay rows out against self.contentWidth, so the
    -- surface has to be told too or a resized panel would keep drawing at
    -- the old width.
    local contentWidth = self:ContentWidth()
    self.frame.scrollChild:SetWidth(contentWidth)
    if self.surface then self.surface.contentWidth = contentWidth end
end

-- Version and patch, the way the reference panel carries its own. Says which
-- build is talking and which patch the shipped guide data was written for,
-- so a panel left over from a past season is visibly that.
function CharacterPanel:FooterText()
    local version = "?"
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local ok, value = pcall(C_AddOns.GetAddOnMetadata, ADDON, "Version")
        if ok and type(value) == "string" and value ~= "" then version = value end
    end
    local specID = PlayerSpecID()
    local bis = specID and ns.GuideStore and ns.GuideStore:GetBiS(specID)
    local patch = bis and bis.patch
    return patch and format("v%s  \194\183  patch %s", version, patch) or ("v" .. version)
end

-- The single place visibility is decided: the panel is shown when the
-- character sheet is open and the setting is on, and drawn only when shown.
function CharacterPanel:Update()
    local frame = self:BuildFrame()
    if not frame then return end
    if self.toggle then self.toggle:SetChecked(self:IsEnabled()) end
    self:SyncSize()
    frame.footer:SetText(self:FooterText())

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
    self:QueueRender()
end

-- Redraws once, RENDER_THROTTLE from now, however many times it is asked
-- in between. Everything event-driven goes through here; only opening the
-- sheet and clicking a tab draw synchronously, because there the player is
-- waiting to see the result.
function CharacterPanel:QueueRender()
    if not (self.frame and self.frame:IsShown()) then return end
    if self.renderQueued then return end
    self.renderQueued = true
    C_Timer.After(RENDER_THROTTLE, function()
        self.renderQueued = nil
        if self.frame and self.frame:IsShown() then self:Render() end
    end)
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
    ns:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function() self:QueueRender() end)
    ns:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function() self:QueueRender() end)
    -- A hero tree swap changes which stat order is the player's.
    ns:RegisterEvent("TRAIT_CONFIG_UPDATED", function() self:QueueRender() end)
    ns:RegisterEvent("PLAYER_TALENT_UPDATE", function() self:QueueRender() end)
    ns:RegisterEvent("GET_ITEM_INFO_RECEIVED", function() self:QueueRender() end)
end
