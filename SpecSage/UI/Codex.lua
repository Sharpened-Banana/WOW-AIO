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

-- The BiS tab asks the client for every item it shows; each answer arrives
-- as GET_ITEM_INFO_RECEIVED, and the row that was showing an "Item 12345"
-- placeholder redraws with the real name and quality colour.
function Codex:OnEnable()
    ns:RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, itemID)
        self:OnBiSItemInfoReceived(itemID)
    end)
    -- Swapping hero tree (or spec) changes which stat order is the
    -- player's; an open Stats tab redraws to match.
    local function OnTalentsChanged()
        if self.frame and self.frame:IsShown() and self.activeTab == "Stats" then
            self:RenderActiveTab()
        end
    end
    ns:RegisterEvent("TRAIT_CONFIG_UPDATED", OnTalentsChanged)
    ns:RegisterEvent("PLAYER_TALENT_UPDATE", OnTalentsChanged)
    ns:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", OnTalentsChanged)
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
-- Widened again (984 -> 1070) for the 9th tab, Options. The tab strip's own
-- geometry is what forces this: it spans from the spec rail's right edge
-- (x=282) to 8px inside the frame's right edge, i.e. FRAME_WIDTH - 290, and
-- 9 tabs at the existing 84/86 need 8*86 + 84 = 772px. 1070 leaves 780px, a
-- small margin over that, with tab width/stride untouched so "Consumables"
-- still fits its button. CONTENT_WIDTH grows by the same 86 to keep its own
-- invariant (frame width minus 310px of chrome).
local FRAME_WIDTH, FRAME_HEIGHT = 1070, 600
local CLASS_RAIL_WIDTH = 120
local SPEC_RAIL_WIDTH = 150
local TITLE_HEIGHT = 26
local TAB_HEIGHT = 28
local TAB_BUTTON_WIDTH = 84
local TAB_BUTTON_STRIDE = 86
local CONTENT_WIDTH = 760
local PADDING = 12
local LINE_GAP = 5
local PARAGRAPH_GAP = 10
local GROUP_GAP = 16

-- Interactive list rows (BiS lists, trinket tier list, loadouts): the
-- row frame's height and the y-cursor step between rows. Raised from 18/20
-- in the 2026-09-02 readability pass, together with the font sizes below;
-- the two must move together or text clips against the next row.
local ROW_HEIGHT = 22
local ROW_STEP = 26
local STAT_ROW_HEIGHT = 20
local STAT_ROW_STEP = 24

-- Options is last, and is the one tab whose content ignores the class/spec
-- rails entirely: settings are global (or per-character), not per-spec.
local TABS = { "Overview", "Stats", "Rotation", "Cooldowns", "Consumables", "BiS", "Loadouts", "Notes", "Options" }

-- Options tab row metrics.
local OPTION_ROW_HEIGHT = 26
local OPTION_CHECK_SIZE = 20
local OPTION_STEP_BUTTON_WIDTH = 24
local OPTION_VALUE_WIDTH = 58

local CLASS_ICON_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local DEFAULT_CLASS_COLOR = { r = 0.8, g = 0.8, b = 0.8 }

-- Per Data/API.lua's schema comment, missing/empty guide sections render this
-- single italic-styled (see the colour-only note below) line rather than
-- nothing at all. WoW's SetFont has no italic flag, only OUTLINE/MONOCHROME/
-- THICKOUTLINE, so "italic" here is approximated with a muted colour. Names
-- the real place to add data (a Lua data file) rather than the options
-- panel, which has no Codex section (see Core/Options.lua).
local NO_DATA_TEXT = "no guide data yet - see SpecSage/Data/Guides_<Class>.lua to add some"
-- "Blizzard Modern" palette: soft dark blue-gray panels with a faked vertical
-- gradient (real frames stay flat-color BackdropTemplate; the gradient comes
-- from a separate overlay texture via Texture:SetGradient, see
-- ApplyPanelChrome below) and a warm bronze accent, successor to the old flat
-- near-black/pure-blue palette this file used before the 2026-09-01 UI pass.
local MUTED_COLOR = { 0.392, 0.455, 0.541 } -- was { 0.55, 0.55, 0.55 }
local HEADER_COLOR = { 0.388, 0.737, 0.902 } -- was { 0.4, 0.8, 1.0 }; #63BCE6
-- A rotation/cooldown step's optional `condition` (DESIGN.md's v1.3
-- section): a distinct blue-grey so it reads as "detail on the line above"
-- rather than MUTED_COLOR's "there is no data here" or HEADER_COLOR's
-- "this starts a new section".
local CONDITION_COLOR = { 0.55, 0.75, 0.95 }
local CONDITION_INDENT = 20

local PANEL_BG_TOP = { 0.125, 0.164, 0.207 }    -- #202A35
local PANEL_BG_BOTTOM = { 0.071, 0.094, 0.125 } -- #121820
local PANEL_BACKDROP_COLOR = { 0.10, 0.13, 0.16, 0.97 }
local PANEL_BORDER_COLOR = { 0.15, 0.18, 0.22, 1 }
local CARD_BG_TOP = { 0.149, 0.192, 0.239 }    -- #26313D
local CARD_BG_BOTTOM = { 0.102, 0.133, 0.169 } -- #1A222B
local CARD_BACKDROP_COLOR = { 0.149, 0.192, 0.239, 0.92 }
local BORDER_COLOR = { 0.216, 0.259, 0.310, 1 }        -- #37424F
local BORDER_HIGHLIGHT_COLOR = { 0.357, 0.439, 0.525 } -- #5B7086, top-seam highlight
local ACCENT_COLOR = { 0.776, 0.608, 0.427 }        -- #C69B6D
local ACCENT_COLOR_BRIGHT = { 0.886, 0.741, 0.569 } -- #E2BD91
local ACCENT_GLOW_COLOR = { 0.776, 0.608, 0.427, 0.38 }
local TEXT_PRIMARY_COLOR = { 0.906, 0.929, 0.953 }   -- #E7EDF3
local TEXT_SECONDARY_COLOR = { 0.651, 0.706, 0.761 } -- #A6B4C2

-- Body text uses the game's own standard font (Friz Quadrata via
-- STANDARD_TEXT_FONT, the face every default tooltip and panel uses) at 13pt
-- for rows and 14pt for paragraphs. The 2026-09-01 pass bundled PT Sans at
-- 11/12pt for a "modern" look; the owner found it harder to read than the
-- game's own face and too small, so this is the 2026-09-02 readability pass:
-- Blizzard's font, two sizes up, and the row metrics above opened to match.
-- Friz has no bold cut in the client, so headers use the same face and rely
-- on their colour and divider rule to stand out. Built once at load and
-- reused via SetFontObject rather than a fresh CreateFont per row.
local BODY_FONT_PATH = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local SpecSageBodyFont = CreateFont("SpecSageBodyFont")
SpecSageBodyFont:SetFont(BODY_FONT_PATH, 14, "")
SpecSageBodyFont:SetTextColor(unpack(TEXT_PRIMARY_COLOR))
local SpecSageBodyFontSmall = CreateFont("SpecSageBodyFontSmall")
SpecSageBodyFontSmall:SetFont(BODY_FONT_PATH, 13, "")
SpecSageBodyFontSmall:SetTextColor(unpack(TEXT_PRIMARY_COLOR))
local SpecSageBoldFontSmall = CreateFont("SpecSageBoldFontSmall")
SpecSageBoldFontSmall:SetFont(BODY_FONT_PATH, 13, "")
SpecSageBoldFontSmall:SetTextColor(unpack(TEXT_PRIMARY_COLOR))

-- BiS tab: the default
-- item colour-- item colour for an entry whose quality is not known yet (a plain-name
-- entry, or an itemID GetItemInfo has not resolved yet).
local DEFAULT_ITEM_COLOR = { 0.8, 0.8, 0.8 }

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

-- Clickable item links (DESIGN.md's "BiS / Gear" v1.5 addendum). Every
-- concrete item the BiS tab shows - a linked BiS row, a trinket tier-list
-- row - behaves like an item
-- link in chat: hover for the item tooltip, click for the standard clickable
-- ItemRefTooltip, shift-click to insert into chat, ctrl-click to dress up.
local GetItemInfoAPI = (C_Item and C_Item.GetItemInfo) or GetItemInfo

-- Shared with UI/CharacterPanel.lua, which shows the same BiS rows docked to
-- the character sheet: see Core/Init.lua for why a bare item ID is not enough.
local ItemString = ns.ItemString

-- The item's real link once the client has it cached (quality colour, full
-- bonus data), else the item string itself, which the link-click path still
-- resolves. `item` is whatever ItemString returned - an ID or a full string.
local function ItemLink(item)
    if GetItemInfoAPI then
        local ok, _, link = pcall(GetItemInfoAPI, item)
        if ok and type(link) == "string" and link ~= "" then return link end
    end
    if type(item) == "string" then return item end
    return "item:" .. tostring(item)
end

-- HandleModifiedItemClick covers the shift/ctrl modifiers (chat insert,
-- dressing room) and returns true when it consumed the click; SetItemRef is
-- what a plain click on a chat link runs, opening ItemRefTooltip. Both are
-- pcall-wrapped since either has moved between client versions.
local function ClickItemLink(item, button)
    if type(item) ~= "number" and type(item) ~= "string" then return false end
    local link = ItemLink(item)
    local ok = pcall(function()
        if HandleModifiedItemClick and HandleModifiedItemClick(link) then return end
        if SetItemRef then
            local linkString = link:match("|H(.-)|h") or link
            SetItemRef(linkString, link, button or "LeftButton")
        end
    end)
    return ok
end

-- SetItemByID only takes a numeric ID, so a bonus-carrying item string has to
-- go through SetHyperlink instead - otherwise the hover tooltip would show
-- the base item while the row's text described the upgraded one.
local function ShowItemTooltip(owner, item)
    pcall(function()
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        if type(item) == "string" then
            GameTooltip:SetHyperlink(item)
        else
            GameTooltip:SetItemByID(item)
        end
        GameTooltip:Show()
    end)
end

-- Trinket tier-list tag colours (S/A/B/C), and the muted tag for the gain
-- column / source text.
local TIER_COLORS = {
    S = { 1.00, 0.55, 0.10 },
    A = { 0.64, 0.21, 0.93 },
    B = { 0.00, 0.60, 1.00 },
    C = { 0.20, 0.80, 0.20 },
    D = { 0.60, 0.60, 0.60 },
    F = { 0.55, 0.35, 0.35 },
}

-- Layers a soft top-to-bottom gradient and a 1px top-edge highlight seam over
-- a flat BackdropTemplate panel - the two tricks that make a plain solid-color
-- backdrop read as a lit "Blizzard Modern" panel instead of a flat rectangle,
-- using only WoW's own Texture:SetGradient API (no bundled art needed).
local function ApplyPanelChrome(frame, topColor, bottomColor)
    if frame.specSageChromeApplied then return end
    frame.specSageChromeApplied = true

    local gradient = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    gradient:SetAllPoints(frame)
    gradient:SetGradient("VERTICAL",
        CreateColor(topColor[1], topColor[2], topColor[3], 0.55),
        CreateColor(bottomColor[1], bottomColor[2], bottomColor[3], 0))

    local seam = frame:CreateTexture(nil, "BORDER")
    seam:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    seam:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    seam:SetHeight(1)
    seam:SetColorTexture(unpack(BORDER_HIGHLIGHT_COLOR))
    seam:SetAlpha(0.6)
end

local CORNER_RADIUS = 10
local CORNER_BORDER_WIDTH = 2
local TEXTURE_PATH = "Interface\\AddOns\\SpecSage\\Textures\\"

-- Genuinely rounds a panel's corners - unlike ApplyPanelChrome's gradient/
-- seam trick above, a naive corner-mask overlay does NOT work here: a
-- BackdropTemplate's own bg/border fill paints the FULL rectangle including
-- the corners, so anything drawn on top of it with transparent "cut" pixels
-- just reveals that same opaque fill sitting underneath, not the real
-- background behind the frame - rounding requires nothing else to paint
-- those corner pixels in the first place.
-- This replaces the backdrop's fill entirely with a manually-built "cross"
-- (3 border-colored rects + 3 fill-colored rects, each shaped to avoid the
-- 4 corner squares) plus 4 pre-baked corner tiles
-- (SpecSage/Textures/panel_corner_*.png - fill+border baked in, transparent
-- outside the rounded arc) dropped into exactly those 4 unpainted corner
-- squares. Since nothing else paints there, the tiles' transparent zone
-- correctly reveals whatever's really behind the frame.
-- Caller must also set the frame's own SetBackdropColor/BorderColor alpha
-- to 0 so the old flat square fill doesn't paint underneath and defeat this.
-- Only applied to the main Codex frame - dialogs/the notes editbox keep
-- ApplyPanelChrome's simpler flat treatment, since this is a bigger change
-- per frame and the main panel is the highest-value target.
local function ApplyRoundedCorners(frame, bgColor, borderColor)
    local r, bw = CORNER_RADIUS, CORNER_BORDER_WIDTH

    -- Builds the 3-piece "frame rect minus 4 corner squares" cross shape
    -- (a full-height center band + two side strips that stop short of the
    -- top/bottom corners) at the given inset from the frame's true edges.
    local function crossPieces(color, inset, sublevel)
        local vert = frame:CreateTexture(nil, "BACKGROUND", nil, sublevel)
        vert:SetColorTexture(unpack(color))
        vert:SetPoint("TOPLEFT", frame, "TOPLEFT", r, -inset)
        vert:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -r, inset)

        local left = frame:CreateTexture(nil, "BACKGROUND", nil, sublevel)
        left:SetColorTexture(unpack(color))
        left:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -r)
        left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", r, r)

        local right = frame:CreateTexture(nil, "BACKGROUND", nil, sublevel)
        right:SetColorTexture(unpack(color))
        right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -r)
        right:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -r, r)

        return { vert, left, right }
    end

    -- Border layer sits at the true edges (inset 0); the fill layer sits
    -- inset by the border width so a `bw`-thick border ring shows on the
    -- straight edges. Stored on the frame so UpdateClassHighlight can
    -- recolor the (only) tintable part of this per selected class - the
    -- 4 small corner tiles stay a fixed neutral color rather than also
    -- being made tintable, a deliberate, low-risk scope cut.
    frame.roundedBorderPieces = crossPieces(borderColor, 0, 0)
    crossPieces(bgColor, bw, 1)

    for _, spec in ipairs({
        { point = "TOPLEFT", suffix = "TL" },
        { point = "TOPRIGHT", suffix = "TR" },
        { point = "BOTTOMLEFT", suffix = "BL" },
        { point = "BOTTOMRIGHT", suffix = "BR" },
    }) do
        local tex = frame:CreateTexture(nil, "BORDER")
        tex:SetSize(r, r)
        tex:SetPoint(spec.point, frame, spec.point, 0, 0)
        tex:SetTexture(TEXTURE_PATH .. "panel_corner_" .. spec.suffix .. ".png")
    end
end

local DANGER_BORDER_COLOR = { 0.700, 0.298, 0.263 }

-- Re-skins a UIPanelButtonTemplate button (the gray 3D bevel look) as a flat
-- bordered button: hides every pre-existing texture region rather than
-- assuming a specific template internal (some templates expose a single
-- NormalTexture, others a Left/Middle/Right 3-slice - hiding all of them
-- works either way), then layers two textures of our own directly on the
-- button (BACKGROUND = border color, BORDER layer inset 1px = fill color) so
-- there is no frame-level ordering to get wrong against the button's own
-- text. The button keeps its native click/disable/highlight behavior -
-- only SetHighlightTexture is re-pointed at a plain additive glow.
local function SkinButton(button, opts)
    if not button or button.specSageSkinned then return end
    button.specSageSkinned = true
    opts = opts or {}
    local isDanger = opts.variant == "danger"

    for _, region in ipairs({ button:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("Texture") then
            region:Hide()
        end
    end

    local border = button:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints(button)
    border:SetColorTexture(unpack(BORDER_COLOR))

    local fill = button:CreateTexture(nil, "BORDER")
    fill:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    fill:SetColorTexture(unpack(CARD_BACKDROP_COLOR))

    button.specSageBorder = border

    if button.SetHighlightTexture then
        button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    end

    -- A soft accent-colored glow (SpecSage/Textures/accent_glow.png, a plain
    -- radial gradient with real alpha falloff) behind the button on hover -
    -- ADD blend means it only ever brightens what's underneath, so unlike
    -- the corner tiles above there's no "opaque layer defeats it" problem
    -- to worry about here.
    local glow
    if not isDanger then
        glow = button:CreateTexture(nil, "BACKGROUND")
        glow:SetPoint("TOPLEFT", button, "TOPLEFT", -6, 6)
        glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 6, -6)
        glow:SetTexture(TEXTURE_PATH .. "accent_glow.png")
        glow:SetBlendMode("ADD")
        glow:Hide()
    end

    button:HookScript("OnEnter", function()
        border:SetColorTexture(unpack(isDanger and DANGER_BORDER_COLOR or ACCENT_COLOR))
        if glow then glow:Show() end
    end)
    button:HookScript("OnLeave", function()
        border:SetColorTexture(unpack(BORDER_COLOR))
        if glow then glow:Hide() end
    end)

    if button.SetNormalFontObject then
        button:SetNormalFontObject(SpecSageBodyFontSmall)
        button:SetHighlightFontObject(SpecSageBodyFontSmall)
        button:SetDisabledFontObject(SpecSageBodyFontSmall)
    end
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
    backdrop:SetBackdropColor(unpack(CARD_BACKDROP_COLOR))
    backdrop:SetBackdropBorderColor(unpack(BORDER_COLOR))
    ApplyPanelChrome(backdrop, CARD_BG_TOP, CARD_BG_BOTTOM)

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
        row.text:SetFontObject(SpecSageBodyFontSmall)
        -- Both guarded: not every FontString method exists in every game
        -- version (or in the test mock), and wrapping is cheap here.
        pcall(row.text.SetJustifyV, row.text, "TOP")
        pcall(row.text.SetWordWrap, row.text, true)

        -- Hairline divider shown only under section headers (opts.isHeader
        -- in PlaceLine) - the "Blizzard Modern" pass's stand-in for a real
        -- section rule, since a bare colored line of text was the only
        -- separator before.
        row.divider = row:CreateTexture(nil, "ARTWORK")
        row.divider:SetColorTexture(unpack(BORDER_COLOR))
        row.divider:Hide()

        row:SetScript("OnEnter", function(self)
            if self.itemID then
                ShowItemTooltip(self, self.itemLink or self.itemID)
                return
            end
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
        -- A gear guidance line that names a concrete item (opts.itemID in
        -- PlaceLine) is a clickable item link; spell rows stay hover-only.
        row:SetScript("OnMouseUp", function(self, button)
            if self.itemID then ClickItemLink(self.itemLink or self.itemID, button) end
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
    row.itemID = opts.itemID
    row.itemLink = opts.itemLink
    if opts.itemID then row:EnableMouse(true) end
    -- opts.indent (a step's condition sub-line) stacks with the spellID
    -- inset rather than replacing it, though the two are never combined in
    -- practice today - a condition line carries no icon of its own.
    textInset = textInset + (opts.indent or 0)

    row.text:ClearAllPoints()
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", textInset, 0)
    row.text:SetFontObject(opts.isHeader and SpecSageBoldFontSmall or SpecSageBodyFontSmall)

    local color = opts.color or TEXT_PRIMARY_COLOR
    row.text:SetTextColor(color[1], color[2], color[3])

    local textWidth = width - textInset
    row.text:SetWidth(textWidth)
    row.text:SetText(text or "")

    local ok, height = pcall(row.text.GetStringHeight, row.text)
    if not ok or not height or height <= 0 then
        local charsPerLine = math.max(20, math.floor(textWidth / 6))
        local lineCount = math.max(1, math.ceil((#(text or "")) / charsPerLine))
        height = lineCount * 17
    end

    -- Headers reserve a little extra room below the text for the divider
    -- rule (see AcquireLineRow), so the next line's PlaceLine call never
    -- overlaps it.
    local headerDividerSpace = opts.isHeader and 6 or 0
    local rowHeight = math.max(height, opts.spellID and 16 or 0) + headerDividerSpace
    row:SetSize(width, rowHeight)
    row:Show()

    if opts.isHeader then
        row.divider:ClearAllPoints()
        row.divider:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -3)
        row.divider:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.divider:SetHeight(1)
        row.divider:Show()
    else
        row.divider:Hide()
    end

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
        row.label:SetFontObject(SpecSageBodyFontSmall)

        row.value = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.value:SetJustifyH("RIGHT")
        row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.value:SetFontObject(SpecSageBoldFontSmall)

        pool[index] = row
    end
    return row
end

local function PlaceStatRow(pool, index, parent, y, width, label, value, muted)
    local row = AcquireStatRow(pool, index, parent)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    row:SetSize(width, STAT_ROW_HEIGHT)

    row.label:SetText(label or "")
    if muted then
        row.label:SetTextColor(MUTED_COLOR[1], MUTED_COLOR[2], MUTED_COLOR[3])
    else
        row.label:SetTextColor(TEXT_SECONDARY_COLOR[1], TEXT_SECONDARY_COLOR[2], TEXT_SECONDARY_COLOR[3])
    end

    row.value:SetText(value or "")
    row.value:SetTextColor(TEXT_PRIMARY_COLOR[1], TEXT_PRIMARY_COLOR[2], TEXT_PRIMARY_COLOR[3])

    row:Show()
    return y - STAT_ROW_STEP
end

-- Hides the unused tail of a pool and sizes the scroll child to fit what was
-- actually drawn. `y` is the cursor value after the last row was placed.
-- Builds a second rendering surface: a plain table the Render*/Ensure*
-- methods below can run against, drawing into `host`'s own scroll area
-- instead of the Codex window's.
--
-- `__index = Codex` is what makes those methods reachable, and is also the
-- one hazard: a field the surface forgets to set falls through and reads the
-- Codex's, which would silently share a row pool between two windows. Every
-- per-surface field is therefore listed here explicitly, empty, rather than
-- being created lazily on first use - if a new one is added to the Codex
-- later, this table is the place it has to be repeated.
--
-- `host` is the frame interactive widgets anchor into (the Codex's own is
-- Codex.frame); `scrollFrame`/`scrollChild`/`contentWidth` are the scroll
-- area the rows are laid out in.
function Codex:NewSurface(host, scrollFrame, scrollChild, contentWidth)
    return setmetatable({
        frame = host,
        scrollFrame = scrollFrame,
        scrollChild = scrollChild,
        contentWidth = contentWidth,

        -- One pool per tab that draws plain line rows, plus the extra pools
        -- the richer tabs keep alongside them.
        pools = { overview = {}, stats = {}, rotation = {}, cooldowns = {},
                  consumables = {}, bis = {}, options = {} },
        statLinePool = {},
        bisLinkRowPool = {},
        trinketRowPool = {},
        loadoutRowPool = {},
        siteLoadoutRowPool = {},

        -- Per-surface view state. Scalars, so unlike the pools above these
        -- cannot be shared by reference even in principle: each window
        -- remembers its own BiS context and trinket fight style.
        activeTab = "Overview",
        bisListIndex = 1,
        trinketListIndex = 1,

        -- Lazily-built widgets, and the pools an Ensure*Widgets builds
        -- rather than the surface. `false`, deliberately, on both counts:
        --
        --   * nil would fall through __index to the Codex's own widget, so
        --     the panel's Notes tab would write into the Codex window's edit
        --     box and its Options tab would drive the Codex's checkboxes.
        --   * a ready-made table would satisfy the "if self.X then return"
        --     guard every Ensure*Widgets opens with, so the widgets would
        --     never be built at all and the first render would index nil.
        --
        -- `false` is the only value that is both non-nil (no fallthrough)
        -- and falsy (the guard still builds). Anything added to the Codex
        -- that an Ensure*Widgets creates has to be repeated here the same
        -- way.
        bisListToggle = false,
        trinketToggle = false,
        loadoutButtons = false,
        suggestedLoadoutRows = false,
        notesBox = false,
        notesBoxFrame = false,
        optionPools = false,

        -- UpdateTabHighlight iterates this; a surface with no tab strip of
        -- its own gets an empty table rather than falling through to the
        -- Codex's real buttons and highlighting the wrong window's tab.
        tabButtons = {},
    }, { __index = self })
end

-- Rendering surfaces.
--
-- Every Render*/Ensure* method below reaches its frames, row pools and
-- per-window state through `self` rather than through an upvalue: `self`
-- here is a *surface*, not necessarily the Codex module. The Codex is its
-- own surface (Codex.frame, Codex.pools, Codex.contentWidth, ... all live
-- directly on the module), and UI/CharacterPanel.lua builds a second one -
-- a plain table carrying the same field names, with `__index = Codex` so
-- these same methods run against it. Nothing here may close over the
-- Codex's own frames or pools, or the docked panel would draw into the
-- floating window; `self.contentWidth` rather than the CONTENT_WIDTH
-- upvalue is that rule applied to the one number rendering needs.
--
-- Codex:NewSurface lists exactly what a surface must provide.
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
    local parent, width = self.scrollChild, self.contentWidth
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
        y = PlaceLine(pool, index, parent, y, width, "Tips", { color = HEADER_COLOR, isHeader = true })
        for _, tip in ipairs(guide.tips) do
            index = index + 1
            y = PlaceLine(pool, index, parent, y, width, "\226\128\162 " .. tip)
        end
    end

    self:FinishPool(pool, index, y)
end

function Codex:RenderStats(guide, specID)
    local parent, width = self.scrollChild, self.contentWidth
    local pool = self.pools.stats
    self.statLinePool = self.statLinePool or {}
    local linePool = self.statLinePool
    local y, index = -PADDING, 0

    -- For the player's own spec this is Wowhead's order for the hero tree
    -- they are in (activeTitle names it); for any other spec, or when the
    -- tree cannot be read, the guide's flat order.
    local priorities, activeTitle = ns.GuideStore:GetActiveStatPriority(specID)
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
        if activeTitle then
            index = index + 1
            y = PlaceStatRow(pool, index, parent, y, width,
                format("for your hero tree: %s", activeTitle), nil, true)
        end
    end

    self:FinishPool(pool, index, y)

    -- Wowhead's own per-hero-tree priorities (v1.6, generated
    -- Data/StatPriority.lua). Drawn into a second, wrapping pool below the
    -- rows above: these are ordered text, not live values, and a note like
    -- "Haste only to roughly 800 rating" needs to wrap rather than clip.
    y = y - GROUP_GAP
    local lineIndex = 0
    local data = specID and ns.GuideStore:GetStatPriority(specID)
    if data and data.lists and #data.lists > 0 then
        lineIndex = lineIndex + 1
        y = PlaceLine(linePool, lineIndex, parent, y, width, "By Hero Talent Tree",
            { color = HEADER_COLOR, isHeader = true })
        for _, listEntry in ipairs(data.lists) do
            local names = {}
            for order, entry in ipairs(listEntry.list) do
                names[order] = STAT_LABELS[entry.stat] or entry.stat
            end
            local isCurrent = activeTitle ~= nil and listEntry.title == activeTitle
            lineIndex = lineIndex + 1
            y = PlaceLine(linePool, lineIndex, parent, y, width,
                format("%s%s: %s", listEntry.title, isCurrent and "  (you)" or "", table.concat(names, " > ")),
                isCurrent and { color = HEADER_COLOR } or nil)
            if listEntry.note then
                lineIndex = lineIndex + 1
                y = PlaceLine(linePool, lineIndex, parent, y, width, listEntry.note,
                    { color = CONDITION_COLOR, indent = CONDITION_INDENT })
            end
        end
        -- Same attribution contract the BiS lists carry: whose editorial
        -- order this is, and when it was read, so a stale season is visible
        -- on the tab rather than assumed to be current.
        if data.source then
            y = y - LINE_GAP
            lineIndex = lineIndex + 1
            y = PlaceLine(linePool, lineIndex, parent, y, width, data.source, { color = MUTED_COLOR })
        end
    end

    HidePoolFrom(linePool, lineIndex + 1)
    self.scrollChild:SetHeight(math.max(-y, 10))
    pcall(self.scrollFrame.UpdateScrollChildRect, self.scrollFrame)
end

function Codex:RenderRotation(guide)
    local parent, width = self.scrollChild, self.contentWidth
    local pool = self.pools.rotation
    local y, index = -PADDING, 0

    local groups = guide and guide.rotation
    if not groups or #groups == 0 then
        index = index + 1
        y = PlaceLine(pool, index, parent, y, width, NO_DATA_TEXT, { color = MUTED_COLOR })
    else
        for _, group in ipairs(groups) do
            index = index + 1
            y = PlaceLine(pool, index, parent, y, width, group.title or "", { color = HEADER_COLOR, isHeader = true })
            for _, step in ipairs(group.steps or {}) do
                index = index + 1
                y = PlaceLine(pool, index, parent, y, width, step.text or "", { spellID = step.spellID })
                -- Optional condition (DESIGN.md's v1.3 section): the APL
                -- if= logic a step comes from, translated to plain English
                -- and kept structurally separate from step.text rather than
                -- folded into one sentence, so the two can be told apart at
                -- a glance and a refresh pass can update one without
                -- rewriting hand-authored prose.
                if step.condition and step.condition ~= "" then
                    index = index + 1
                    y = PlaceLine(pool, index, parent, y, width, step.condition,
                        { color = CONDITION_COLOR, indent = CONDITION_INDENT })
                end
            end
            y = y - GROUP_GAP
        end
    end

    self:FinishPool(pool, index, y)
end

function Codex:RenderCooldowns(guide)
    local parent, width = self.scrollChild, self.contentWidth
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
            if entry.condition and entry.condition ~= "" then
                index = index + 1
                y = PlaceLine(pool, index, parent, y, width, entry.condition,
                    { color = CONDITION_COLOR, indent = CONDITION_INDENT })
            end
        end
    end

    self:FinishPool(pool, index, y)
end

function Codex:RenderConsumables(guide)
    local parent, width = self.scrollChild, self.contentWidth
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
-- Read-only: the linked BiS lists and the trinket tier list, drawn into
-- self.pools.bis plus their own row pools. The personal checklist that used
-- to sit under them (its rows, Add row and per-row Add buttons) was pulled
-- on 2026-09-03 at the owner's request; Modules/BiS.lua still holds the
-- saved entries so nothing is lost if it comes back.
--------------------------------------------------------------------------------

-- The item-link hit area of a list row. Hover and click used to be on the
-- whole row, so the tooltip popped up whenever the mouse crossed the list -
-- scrolling through it meant a tooltip on every line. The row is now inert
-- and a child button the width of the item text takes the mouse instead:
-- hover the name for its tooltip, click it for the link, and the rest of
-- the row is just text. SizeItemHit fits the button to the item's name -
-- not the whole string, which carries the drop source or tier detail after
-- the name - by measuring the name on a hidden FontString in the same font
-- (the text's own width bound is the ceiling).
local function AttachItemHit(row)
    local hit = CreateFrame("Button", nil, row)
    hit:SetPoint("TOPLEFT", row.text, "TOPLEFT", 0, 2)
    hit:SetPoint("BOTTOMLEFT", row.text, "BOTTOMLEFT", 0, -2)
    hit:SetWidth(1)

    local measure = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    measure:SetFontObject(SpecSageBodyFontSmall)
    measure:Hide()
    row.measure = measure
    hit:SetScript("OnEnter", function()
        if row.itemID then ShowItemTooltip(row, row.itemLink or row.itemID) end
    end)
    hit:SetScript("OnLeave", function()
        pcall(function() GameTooltip:Hide() end)
    end)
    hit:SetScript("OnMouseUp", function(_, button)
        if row.itemID then ClickItemLink(row.itemLink or row.itemID, button) end
    end)
    row.hit = hit
end

local function SizeItemHit(row, name)
    local bound = row.text:GetWidth() or 0
    row.measure:SetText(name or "")
    local ok, measured = pcall(row.measure.GetStringWidth, row.measure)
    local width = (ok and type(measured) == "number" and measured > 0) and measured or bound
    if bound > 0 and width > bound then width = bound end
    row.hit:SetWidth(math.max(width, 1))
    row.hit:SetShown(row.itemID ~= nil)
end

-- One trinket tier-list row: tier tag | item name (quality-coloured, a
-- clickable item link) with its ilvl/source/on-use detail | sim gain.
local TRINKET_TAG_WIDTH = 22
local TRINKET_GAIN_WIDTH = 70

local function AcquireTrinketRow(pool, index, parent)
    local row = pool[index]
    if not row then
        row = CreateFrame("Frame", nil, parent)

        row.tag = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.tag:SetFontObject(SpecSageBoldFontSmall)
        row.tag:SetJustifyH("LEFT")
        row.tag:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.tag:SetWidth(TRINKET_TAG_WIDTH)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetFontObject(SpecSageBodyFontSmall)
        row.text:SetJustifyH("LEFT")
        row.text:SetPoint("LEFT", row, "LEFT", TRINKET_TAG_WIDTH, 0)
        pcall(row.text.SetWordWrap, row.text, false)

        row.gain = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.gain:SetFontObject(SpecSageBodyFontSmall)
        row.gain:SetJustifyH("RIGHT")
        row.gain:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.gain:SetWidth(TRINKET_GAIN_WIDTH)

        AttachItemHit(row)

        pool[index] = row
    end
    return row
end

-- One linked-BiS row (Data/BiS.lua): slot tag | quality-coloured item name
-- (a clickable item link) with its drop source.
local BIS_LINK_SLOT_WIDTH = 64

local function AcquireBiSLinkRow(pool, index, parent)
    local row = pool[index]
    if not row then
        row = CreateFrame("Frame", nil, parent)

        row.slot = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.slot:SetFontObject(SpecSageBoldFontSmall)
        row.slot:SetJustifyH("LEFT")
        row.slot:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.slot:SetWidth(BIS_LINK_SLOT_WIDTH)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetFontObject(SpecSageBodyFontSmall)
        row.text:SetJustifyH("LEFT")
        row.text:SetPoint("LEFT", row, "LEFT", BIS_LINK_SLOT_WIDTH, 0)
        pcall(row.text.SetWordWrap, row.text, false)

        AttachItemHit(row)

        pool[index] = row
    end
    return row
end

-- Cycles the linked BiS list through the registered contexts (Overall /
-- Mythic+ / Raid).
function Codex:CycleBiSList()
    local data = self.selectedSpecID and ns.GuideStore:GetBiS(self.selectedSpecID)
    local count = (data and data.lists and #data.lists) or 1
    self.bisListIndex = ((self.bisListIndex or 1) % count) + 1
    if self.activeTab == "BiS" then self:RenderActiveTab() end
end

-- The linked Best-in-Slot section of the BiS tab (Data/BiS.lua): header
-- with the context toggle beside it, one row per slot into
-- self.bisLinkRowPool, and an attribution line. Returns the new pool index
-- and y cursor; draws nothing when the spec has no list registered.
function Codex:RenderBiSLinkSection(pool, index, parent, width, y, specID)
    local data = specID and ns.GuideStore:GetBiS(specID)
    local rowPool = self.bisLinkRowPool
    local toggle = self.bisListToggle
    if not data or not data.lists then
        toggle:Hide()
        HidePoolFrom(rowPool, 1)
        return index, y
    end

    index = index + 1
    y = PlaceLine(pool, index, parent, y, width, "Best in Slot (Icy Veins)", { color = HEADER_COLOR, isHeader = true })
    local headerRow = pool[index]

    local count = #data.lists
    if (self.bisListIndex or 1) > count then self.bisListIndex = 1 end
    local active = data.lists[self.bisListIndex or 1]

    toggle:ClearAllPoints()
    toggle:SetPoint("TOPRIGHT", headerRow, "TOPRIGHT", 0, 2)
    toggle:SetText(active.title or "")
    toggle:SetShown(count > 1)

    for i, entry in ipairs(active.list) do
        local row = AcquireBiSLinkRow(rowPool, i, parent)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        row:SetSize(width, ROW_HEIGHT)
        row.text:SetWidth(width - BIS_LINK_SLOT_WIDTH)

        row.slot:SetText(entry.slot or "")
        row.slot:SetTextColor(TEXT_SECONDARY_COLOR[1], TEXT_SECONDARY_COLOR[2], TEXT_SECONDARY_COLOR[3])

        -- Resolve through the bonus-carrying item string, not the bare ID:
        -- the ID alone gives the item's base form (see ItemString).
        local item = ItemString(entry.itemID, entry.bonus)
        local name, quality = entry.name
        if GetItemInfoAPI then
            local ok, realName, _, realQuality = pcall(GetItemInfoAPI, item)
            if ok and type(realName) == "string" and realName ~= "" then
                name, quality = realName, realQuality
            elseif C_Item and C_Item.RequestLoadItemDataByID then
                -- Always the numeric ID: loading the base item is what makes
                -- the bonus-carrying string resolvable on the next pass.
                pcall(C_Item.RequestLoadItemDataByID, entry.itemID)
            end
        end
        local r, g, b = ItemQualityColor(quality)
        local fromText = (entry.from and entry.from ~= "") and ("  |cff8a97a5" .. entry.from .. "|r") or ""
        row.text:SetText(format("|cff%02x%02x%02x%s|r%s",
            math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), name, fromText))
        row.text:SetTextColor(1, 1, 1)
        row.itemID = entry.itemID
        row.itemLink = (item ~= entry.itemID) and item or nil
        SizeItemHit(row, name)

        row:Show()
        y = y - ROW_STEP
    end
    HidePoolFrom(rowPool, #active.list + 1)

    index = index + 1
    y = PlaceLine(pool, index, parent, y, width,
        format("One site's list (%s), and it goes stale every patch: %s. Click an item for its link.",
            active.title or "", data.source or "source unknown"),
        { color = MUTED_COLOR })

    return index, y - GROUP_GAP
end

function Codex:EnsureBiSWidgets()
    if self.bisListToggle then return end

    local parent = self.scrollChild

    local bisListToggle = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    bisListToggle:SetSize(170, 20)
    bisListToggle:SetScript("OnClick", function() self:CycleBiSList() end)
    SkinButton(bisListToggle)
    self.bisListToggle = bisListToggle
    self.bisLinkRowPool = {}
    self.bisListIndex = self.bisListIndex or 1

    -- Trinket tier list: one button cycling through the registered fight
    -- styles (Single Target / 3 Targets / 5 Targets), sitting beside the
    -- section header.
    local trinketToggle = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    trinketToggle:SetSize(130, 20)
    trinketToggle:SetScript("OnClick", function() self:CycleTrinketList() end)
    SkinButton(trinketToggle)
    self.trinketToggle = trinketToggle
    self.trinketRowPool = {}
    self.trinketListIndex = self.trinketListIndex or 1

end

-- Fired (via Codex:OnEnable) on GET_ITEM_INFO_RECEIVED. Re-renders only the
-- BiS tab's own pool/rows (RenderBiS), not the whole Codex, and only when
-- the resolved itemID is on a row the tab is showing - an item info event
-- for some unrelated addon's lookup is a no-op.
function Codex:OnBiSItemInfoReceived(itemID)
    if type(itemID) ~= "number" then return end
    -- A closed Codex left on its BiS tab must not redraw for every item
    -- the docked panel asked about; the next Open redraws anyway.
    if not self.frame or not self.frame:IsShown() or self.activeTab ~= "BiS" then return end

    local specID = self.selectedSpecID
    if not specID then return end

    -- Anything on the tab showing that item re-renders: a linked BiS row or
    -- a trinket tier-list row.
    for _, row in ipairs(self.bisLinkRowPool or {}) do
        if row.itemID == itemID and row:IsShown() then
            self:RenderBiS(ns.GuideStore:GetGuide(specID), specID)
            return
        end
    end
    for _, row in ipairs(self.trinketRowPool or {}) do
        if row.itemID == itemID and row:IsShown() then
            self:RenderBiS(ns.GuideStore:GetGuide(specID), specID)
            return
        end
    end
end

-- Cycles the trinket tier list through the spec's registered fight styles.
function Codex:CycleTrinketList()
    local data = self.selectedSpecID and ns.GuideStore:GetTrinkets(self.selectedSpecID)
    local count = (data and data.lists and #data.lists) or 1
    self.trinketListIndex = ((self.trinketListIndex or 1) % count) + 1
    if self.activeTab == "BiS" then self:RenderActiveTab() end
end

-- The trinket tier-list section of the BiS tab. Draws the header (with the
-- fight-style toggle beside it) into `pool` from `index`, then the rows into
-- self.trinketRowPool, and returns the new pool index and y cursor.
function Codex:RenderTrinketSection(pool, index, parent, width, y, specID)
    local data = specID and ns.GuideStore:GetTrinkets(specID)
    local rowPool = self.trinketRowPool
    local toggle = self.trinketToggle

    index = index + 1
    y = PlaceLine(pool, index, parent, y, width, "Trinket Tier List", { color = HEADER_COLOR, isHeader = true })
    local headerRow = pool[index]

    if not data or not data.lists then
        toggle:Hide()
        HidePoolFrom(rowPool, 1)
        index = index + 1
        local reason = (data and data.unavailable) or "no trinket data registered for this spec"
        y = PlaceLine(pool, index, parent, y, width, reason, { color = MUTED_COLOR })
        return index, y
    end

    local count = #data.lists
    if self.trinketListIndex > count then self.trinketListIndex = 1 end
    local active = data.lists[self.trinketListIndex]

    toggle:ClearAllPoints()
    toggle:SetPoint("TOPRIGHT", headerRow, "TOPRIGHT", 0, 2)
    toggle:SetText(active.title or "")
    toggle:SetShown(count > 1)

    for i, entry in ipairs(active.list) do
        local row = AcquireTrinketRow(rowPool, i, parent)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        row:SetSize(width, ROW_HEIGHT)
        row.text:SetWidth(width - TRINKET_TAG_WIDTH - TRINKET_GAIN_WIDTH - 8)

        local tier = TIER_COLORS[entry.tier] or MUTED_COLOR
        row.tag:SetText(entry.tier or "")
        row.tag:SetTextColor(tier[1], tier[2], tier[3])

        -- Quality colour once the client knows the item; a not-yet-cached
        -- item shows the sim's own name in the default item colour and asks
        -- the client to fetch it (OnBiSItemInfoReceived re-renders).
        local item = ItemString(entry.itemID, entry.bonus)
        local name, quality = entry.name
        if GetItemInfoAPI then
            local ok, realName, _, realQuality = pcall(GetItemInfoAPI, item)
            if ok and type(realName) == "string" and realName ~= "" then
                name, quality = realName, realQuality
            elseif C_Item and C_Item.RequestLoadItemDataByID then
                pcall(C_Item.RequestLoadItemDataByID, entry.itemID)
            end
        end
        local r, g, b = ItemQualityColor(quality)
        local detail = {}
        if entry.ilvl then detail[#detail + 1] = "ilvl " .. tostring(entry.ilvl) end
        if entry.source and entry.source ~= "" then detail[#detail + 1] = entry.source end
        if entry.onUse then detail[#detail + 1] = "on-use" end
        -- A sim row shows the guide site's tier for the same item beside it,
        -- or says the site does not list it, so the two views are compared
        -- on the row rather than by flipping between lists.
        if entry.gain ~= nil then
            for _, site in ipairs({ { "Icy Veins", entry.siteTier }, { "Wowhead", entry.whTier } }) do
                if site[2] then
                    local st = TIER_COLORS[site[2]] or MUTED_COLOR
                    detail[#detail + 1] = format("%s |cff%02x%02x%02x%s|r|cff8a97a5", site[1],
                        math.floor(st[1] * 255 + 0.5), math.floor(st[2] * 255 + 0.5), math.floor(st[3] * 255 + 0.5),
                        site[2])
                else
                    detail[#detail + 1] = format("not on %s' list", site[1])
                end
            end
        end
        local detailText = #detail > 0 and ("  |cff8a97a5" .. table.concat(detail, " · ") .. "|r") or ""
        row.text:SetText(format("|cff%02x%02x%02x%s|r%s",
            math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), name, detailText))
        row.text:SetTextColor(1, 1, 1)
        row.itemID = entry.itemID
        row.itemLink = (item ~= entry.itemID) and item or nil
        SizeItemHit(row, name)

        row.gain:SetText(entry.gain ~= nil and format("+%.1f%%", entry.gain) or "")
        row.gain:SetTextColor(TEXT_SECONDARY_COLOR[1], TEXT_SECONDARY_COLOR[2], TEXT_SECONDARY_COLOR[3])

        row:Show()
        y = y - ROW_STEP
    end
    HidePoolFrom(rowPool, #active.list + 1)

    if data.note then
        index = index + 1
        y = PlaceLine(pool, index, parent, y, width, data.note, { color = TEXT_SECONDARY_COLOR })
    end

    local isSim = active.list[1] and active.list[1].gain ~= nil
    index = index + 1
    y = PlaceLine(pool, index, parent, y, width,
        format("%s (%s), not a verdict for your fight. Sources: %s. Click a trinket for its link.",
            isSim and "Sim ranking" or "Editorial ranking", active.title or "", data.source or "unknown"),
        { color = MUTED_COLOR })

    return index, y
end

function Codex:RenderBiS(guide, specID)
    self:EnsureBiSWidgets()
    local parent, width = self.scrollChild, self.contentWidth
    local pool = self.pools.bis
    local y, index = -PADDING, 0

    -- The shipped per-slot gear prose (guide.gear) is deliberately not drawn
    -- here any more: it ran to a screenful before the first item, and the
    -- linked BiS lists below say the same thing as a row per slot. The data
    -- stays in the guide files (the schema and its round-trip tests still
    -- carry it) but nothing draws it.

    index, y = self:RenderBiSLinkSection(pool, index, parent, width, y, specID)
    index, y = self:RenderTrinketSection(pool, index, parent, width, y, specID)

    self:FinishPool(pool, index, y)

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
        row.name:SetFontObject(SpecSageBodyFontSmall)
        row.name:SetJustifyH("LEFT")
        row.name:SetPoint("LEFT", row, "LEFT", 0, 0)

        row.copyButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.copyButton:SetSize(50, 18)
        row.copyButton:SetText("Copy")
        row.copyButton:SetPoint("RIGHT", row, "RIGHT", -58, 0)
        SkinButton(row.copyButton)

        row.deleteButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.deleteButton:SetSize(50, 18)
        row.deleteButton:SetText("Delete")
        row.deleteButton:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        SkinButton(row.deleteButton, { variant = "danger" })

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
    SkinButton(save)

    local add = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    add:SetSize(120, 20)
    add:SetText("Add from string")
    add:SetScript("OnClick", function() self:ShowAddDialog() end)
    SkinButton(add)

    self.loadoutButtons = { save = save, add = add }
    self.loadoutRowPool = {}
    self:EnsureSuggestedLoadoutRow()
end

-- The shipped-guide suggested-loadout rows (DESIGN.md's v1.2 section, v1.3
-- for the raid one, v1.4 for the live-meta one): one small frame per kind a
-- guide can ship a talent string for. A fixed small list rather than a pool,
-- since a spec has at most one loadout per kind - there is no unbounded list
-- to pool for. Built alongside the saved-loadout row pool but kept separate
-- from it, since these rows' buttons (Copy / Add to my vault) differ from a
-- saved row's (Copy / Delete) and none of them participate in the
-- delete-by-index list.
--
-- guideField is the guide table key the data lives under; addName/category
-- are what Loadouts:Add stores when the player clicks "Add to my vault"
-- (category must be one of Loadouts.VALID_CATEGORIES, so an unrecognised
-- one here would silently fall back to "Other" rather than error).
-- attribution names the source in the row's own label - kinds are NOT all
-- SimC-sourced (mplusMeta is Blizzard's own API), so this must not be
-- hardcoded at render time the way an earlier version of this table did.
local SUGGESTED_LOADOUT_KINDS = {
    { key = "mplus", guideField = "mplusLoadout", label = "Suggested Mythic+",
      addName = "Suggested M+ (SimC)", category = "Mythic+", attribution = "via SimulationCraft" },
    { key = "raid", guideField = "raidLoadout", label = "Suggested Raid",
      addName = "Suggested Raid (SimC)", category = "Raid", attribution = "via SimulationCraft" },
    { key = "mplusMeta", guideField = "mplusMetaLoadout", label = "Top Players' Mythic+ Build",
      addName = "Top M+ Build (Live)", category = "Mythic+", attribution = "via Blizzard's API" },
}

-- Which vault category a guide site's build label belongs to, from the words
-- the sites actually use ("AoE / Mythic+", "High Mythic+ Keys", "Raid /
-- Cleave", "Delves"). Must return one of Loadouts.VALID_CATEGORIES.
local function SiteBuildCategory(label)
    local lower = (label or ""):lower()
    if lower:find("mythic", 1, true) or lower:find("dungeon", 1, true) or lower:find("keys", 1, true)
        or lower:find("m+", 1, true) or lower:find("aoe", 1, true) then
        return "Mythic+"
    end
    if lower:find("delve", 1, true) then return "Delves" end
    if lower:find("pvp", 1, true) then return "PvP" end
    if lower:find("raid", 1, true) or lower:find("single", 1, true) or lower:find("cleave", 1, true) then
        return "Raid"
    end
    return "Other"
end

local function CreateSuggestedLoadoutRow(parent)
    local row = CreateFrame("Frame", nil, parent)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetFontObject(SpecSageBodyFontSmall)
    row.name:SetJustifyH("LEFT")
    row.name:SetPoint("LEFT", row, "LEFT", 0, 0)

    row.addButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.addButton:SetSize(110, 18)
    row.addButton:SetText("Add to my vault")
    row.addButton:SetPoint("RIGHT", row, "RIGHT", -58, 0)
    SkinButton(row.addButton)

    row.copyButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.copyButton:SetSize(50, 18)
    row.copyButton:SetText("Copy")
    row.copyButton:SetPoint("RIGHT", row.addButton, "LEFT", -8, 0)
    SkinButton(row.copyButton)

    row:Hide()
    return row
end

function Codex:EnsureSuggestedLoadoutRow()
    if self.suggestedLoadoutRows then return end

    self.suggestedLoadoutRows = {}
    for _, kind in ipairs(SUGGESTED_LOADOUT_KINDS) do
        self.suggestedLoadoutRows[kind.key] = CreateSuggestedLoadoutRow(self.scrollChild)
    end
end

-- Adding a shipped suggestion never writes anywhere until this click - the
-- guide's mplusLoadout/raidLoadout stays read-only reference data (like
-- every other shipped guide field) until the player opts in, matching the
-- existing "shipped data is read-only, SpecSageDB is the user's own roster"
-- split. Confirmation is a temporary label change on the button itself
-- (mirrors the Delete row's arm/revert timer above); the newly saved
-- loadout shows up in the list below on the next render (a tab/spec switch,
-- or the revert below) rather than forcing an immediate re-render here,
-- which would otherwise stomp the "Added!" label back to its default before
-- the player ever sees it (RenderLoadouts resets this button's text every
-- render, the same as a saved row's Delete button).
function Codex:OnAddSuggestedLoadoutClicked(button, specID, kind, exportString)
    local Loadouts = ns:GetModule("Loadouts")
    local ok, err = Loadouts:Add(specID, kind.addName, kind.category, exportString)
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
    local parent, width = self.scrollChild, self.contentWidth
    local y = -PADDING

    local buttons = self.loadoutButtons
    buttons.save:ClearAllPoints()
    buttons.save:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    buttons.save:SetShown(IsPlayersSpec(specID))

    buttons.add:ClearAllPoints()
    buttons.add:SetPoint("TOPLEFT", parent, "TOPLEFT", 120, y)
    buttons.add:Show()

    y = y - 26

    -- The shipped suggested-loadout rows (DESIGN.md's v1.2/v1.3/v1.4
    -- sections): shown above the player's own saved loadouts only for the
    -- kinds this spec's guide actually ships (mplusLoadout, raidLoadout,
    -- mplusMetaLoadout), with no placeholder for a kind it does not - that
    -- row simply doesn't exist rather than rendering empty. Order follows
    -- SUGGESTED_LOADOUT_KINDS, and only a shown row spends a y-offset, so a
    -- spec shipping fewer than all kinds does not leave a gap where a
    -- missing one would have been.
    for _, kind in ipairs(SUGGESTED_LOADOUT_KINDS) do
        local suggested = self.suggestedLoadoutRows[kind.key]
        local loadout = guide and guide[kind.guideField]

        if loadout then
            suggested:ClearAllPoints()
            suggested:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
            suggested:SetSize(width, ROW_HEIGHT)

            -- kind.attribution names the real source (SimC vs Blizzard's
            -- own API) rather than a hardcoded phrase - see
            -- SUGGESTED_LOADOUT_KINDS's own comment on why. loadout.sampleSize
            -- is optional (only the empirical, API-sourced kind has one) and
            -- is folded in when present, so a live-meta row can say how many
            -- players it was aggregated from without a curated one needing
            -- to carry a meaningless sample size of its own.
            local detail = kind.attribution
            if loadout.sampleSize then
                detail = format("%s, top %d", detail, loadout.sampleSize)
            end
            detail = format("%s, patch %s", detail, loadout.patch)
            suggested.name:SetText(format("%s (%s)", kind.label, detail))
            suggested.name:SetTextColor(TEXT_PRIMARY_COLOR[1], TEXT_PRIMARY_COLOR[2], TEXT_PRIMARY_COLOR[3])

            suggested.copyButton:Show()
            suggested.copyButton:SetScript("OnClick", function() self:ShowCopyDialog(loadout.string) end)

            suggested.addButton:SetText("Add to my vault")
            suggested.addButton:Show()
            suggested.addButton:SetScript("OnClick", function(btn)
                self:OnAddSuggestedLoadoutClicked(btn, specID, kind, loadout.string)
            end)

            suggested:Show()
            y = y - ROW_STEP
        else
            suggested:Hide()
        end
    end

    -- Guide-site builds (Data/SiteLoadouts.lua): a pooled row per build,
    -- same Copy / Add-to-my-vault buttons as the suggested rows above. The
    -- vault category is inferred from the site's own label.
    local site = specID and ns.GuideStore:GetSiteLoadouts(specID)
    self.siteLoadoutRowPool = self.siteLoadoutRowPool or {}
    local siteCount = 0
    if site and site.builds then
        for i, build in ipairs(site.builds) do
            siteCount = i
            local row = self.siteLoadoutRowPool[i]
            if not row then
                row = CreateSuggestedLoadoutRow(parent)
                self.siteLoadoutRowPool[i] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
            row:SetSize(width, ROW_HEIGHT)
            local siteName = build.site or "Icy Veins"
            row.name:SetText(format("%s: %s (patch %s)", siteName, build.label, site.patch or "?"))
            row.name:SetTextColor(TEXT_PRIMARY_COLOR[1], TEXT_PRIMARY_COLOR[2], TEXT_PRIMARY_COLOR[3])
            row.copyButton:Show()
            row.copyButton:SetScript("OnClick", function() self:ShowCopyDialog(build.string) end)
            local kind = {
                addName = siteName .. ": " .. build.label,
                category = SiteBuildCategory(build.label),
            }
            row.addButton:SetText("Add to my vault")
            row.addButton:Show()
            row.addButton:SetScript("OnClick", function(btn)
                self:OnAddSuggestedLoadoutClicked(btn, specID, kind, build.string)
            end)
            row:Show()
            y = y - ROW_STEP
        end
    end
    HidePoolFrom(self.siteLoadoutRowPool, siteCount + 1)

    local Loadouts = ns:GetModule("Loadouts")
    local list = (Loadouts and specID) and Loadouts:GetForSpec(specID) or {}
    local pool = self.loadoutRowPool

    if #list == 0 then
        local empty = AcquireLoadoutRow(pool, 1, parent)
        empty:ClearAllPoints()
        empty:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        empty:SetSize(width, ROW_HEIGHT)
        empty.name:SetText("no loadouts saved for this spec yet")
        empty.name:SetTextColor(MUTED_COLOR[1], MUTED_COLOR[2], MUTED_COLOR[3])
        empty.copyButton:Hide()
        empty.deleteButton:Hide()
        empty:Show()
        y = y - ROW_STEP
        HidePoolFrom(pool, 2)
    else
        for i, loadout in ipairs(list) do
            local row = AcquireLoadoutRow(pool, i, parent)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
            row:SetSize(width, ROW_HEIGHT)

            row.name:SetText(format("%s  |cff888888[%s]|r", loadout.name, loadout.category))
            row.name:SetTextColor(TEXT_PRIMARY_COLOR[1], TEXT_PRIMARY_COLOR[2], TEXT_PRIMARY_COLOR[3])
            row.copyButton:Show()
            row.copyButton:SetScript("OnClick", function() self:ShowCopyDialog(loadout.export) end)

            row.deleteButton.armed = false
            row.deleteButton:SetText("Delete")
            row.deleteButton:Show()
            row.deleteButton:SetScript("OnClick", function(btn)
                self:OnDeleteLoadoutClicked(btn, specID, i)
            end)

            row:Show()
            y = y - ROW_STEP
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
    dialog:SetBackdropColor(unpack(CARD_BACKDROP_COLOR))
    dialog:SetBackdropBorderColor(unpack(BORDER_COLOR))
    ApplyPanelChrome(dialog, CARD_BG_TOP, CARD_BG_BOTTOM)
    dialog:Hide()

    local nameLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetFontObject(SpecSageBodyFontSmall)
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
    SkinButton(categoryButton)

    local importLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    importLabel:SetFontObject(SpecSageBodyFontSmall)
    importLabel:SetPoint("TOPLEFT", categoryButton, "BOTTOMLEFT", 0, -10)
    importLabel:SetText("Import string")

    local importBoxBackdrop, importBox = NewBackdropEditBox(dialog, 336, 70)
    importBoxBackdrop:SetPoint("TOPLEFT", importLabel, "BOTTOMLEFT", 0, -4)

    local saveButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    saveButton:SetSize(80, 22)
    saveButton:SetText("Save")
    saveButton:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 12, 12)
    saveButton:SetScript("OnClick", function() self:OnAddDialogSave() end)
    SkinButton(saveButton)

    local cancelButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    cancelButton:SetSize(80, 22)
    cancelButton:SetText("Cancel")
    cancelButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -12, 12)
    cancelButton:SetScript("OnClick", function() self:HideAddDialog() end)
    SkinButton(cancelButton)

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
    dialog:SetBackdropColor(unpack(CARD_BACKDROP_COLOR))
    dialog:SetBackdropBorderColor(unpack(BORDER_COLOR))
    ApplyPanelChrome(dialog, CARD_BG_TOP, CARD_BG_BOTTOM)
    dialog:Hide()

    local label = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetFontObject(SpecSageBodyFontSmall)
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
    self.copyLabel = label
end

-- `label` (optional) replaces the dialog's default "Ctrl+C to copy" caption
-- for callers that need to say what the string is for (the Feedback link).
function Codex:ShowCopyDialog(exportString, label)
    self:EnsureCopyDialog()
    -- Show first: EditBox:SetFocus() is a no-op on a hidden widget in the
    -- real client, so focusing/highlighting before Show() leaves nothing
    -- selected for Ctrl+C despite the dialog's own "Ctrl+C to copy" label.
    self.copyDialog:Show()
    self.copyLabel:SetText(label or "Ctrl+C to copy")
    self.copyBox:SetText(exportString or "")
    self.copyBox:SetFocus()
    self.copyBox:HighlightText()
end

-- Feedback / feature requests. The game gives an addon no way to open a
-- browser or send anything out, so this is the honest version of a
-- "feedback button": the GitHub Issues link, selected and ready to
-- Ctrl+C. Opens the Codex first so the dialog has a parent to sit on.
function Codex:ShowFeedback()
    if not self.frame or not self:IsShown() then self:Toggle() end
    self:ShowCopyDialog(ns.FeedbackURL(),
        "Ctrl+C this link, paste it in your browser: bug reports and feature requests go there")
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

    local backdrop, box = NewBackdropEditBox(self.scrollChild, self.contentWidth, 400)
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
    backdrop:SetSize(self.contentWidth, 400)
    box.specID = specID

    local Notes = ns:GetModule("Notes")
    box:SetText((Notes and specID) and Notes:Get(specID) or "")
    backdrop:Show()
    box:Show()

    self.scrollChild:SetHeight(420)
end

--------------------------------------------------------------------------------
-- Options tab
--
-- Renders ns.OPTION_GROUPS (Core/Config.lua) - the same schema Core/
-- Options.lua feeds to Blizzard's Settings panel, so the two surfaces cannot
-- show different settings.
--
-- Every widget here is built from primitives this file already relies on
-- (a bare Button plus textures, UIPanelButtonTemplate, FontStrings) rather
-- than from checkbox/slider templates. Blizzard's widget templates move
-- between versions - MinimalSliderWithSteppersMixin going missing is what
-- broke the Settings panel in the first place - and this tab exists partly
-- as the fallback for when that panel will not build, so it must not depend
-- on the same shifting surface. A "range" option is therefore a pair of
-- -/+ steppers rather than a slider, which also lets a player land on an
-- exact value instead of dragging for it.
--------------------------------------------------------------------------------

local CHECK_BACKDROP_TEXTURE = "Interface\\Buttons\\UI-CheckBox-Up"
local CHECK_MARK_TEXTURE = "Interface\\Buttons\\UI-CheckBox-Check"
local CHECK_HIGHLIGHT_TEXTURE = "Interface\\Buttons\\UI-CheckBox-Highlight"

-- Shared hover tooltip for an option row; `entry.tooltip` is the same text
-- the Settings panel shows for that option.
local function SetOptionTooltip(frame, entry)
    frame.optionLabel = entry.label
    frame.optionTooltip = entry.tooltip
end

local function OnOptionRowEnter(self)
    if not self.optionTooltip and not self.optionLabel then return end
    pcall(function()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.optionLabel or "")
        if self.optionTooltip then
            GameTooltip:AddLine(self.optionTooltip, 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
end

local function OnOptionRowLeave()
    pcall(function() GameTooltip:Hide() end)
end

local function AcquireOptionCheckRow(pool, index, parent)
    local row = pool[index]
    if not row then
        row = CreateFrame("Frame", nil, parent)
        row:EnableMouse(true)
        row:SetScript("OnEnter", OnOptionRowEnter)
        row:SetScript("OnLeave", OnOptionRowLeave)

        -- Deliberately untemplated: this button never calls SetText (its
        -- caption is the separate FontString below), so it needs no
        -- text-capable template, and the check itself is drawn with the
        -- long-standing UI-CheckBox textures.
        local box = CreateFrame("Button", nil, row)
        box:SetSize(OPTION_CHECK_SIZE, OPTION_CHECK_SIZE)
        box:SetPoint("LEFT", row, "LEFT", 0, 0)

        local bg = box:CreateTexture(nil, "ARTWORK")
        bg:SetAllPoints(box)
        bg:SetTexture(CHECK_BACKDROP_TEXTURE)

        local mark = box:CreateTexture(nil, "OVERLAY")
        mark:SetAllPoints(box)
        mark:SetTexture(CHECK_MARK_TEXTURE)
        mark:Hide()

        pcall(box.SetHighlightTexture, box, CHECK_HIGHLIGHT_TEXTURE)

        box:SetScript("OnEnter", function() OnOptionRowEnter(row) end)
        box:SetScript("OnLeave", OnOptionRowLeave)

        row.box, row.mark = box, mark

        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.label:SetFontObject(SpecSageBodyFontSmall)
        row.label:SetJustifyH("LEFT")
        row.label:SetPoint("LEFT", box, "RIGHT", 6, 0)

        pool[index] = row
    end
    return row
end

local function AcquireOptionRangeRow(pool, index, parent)
    local row = pool[index]
    if not row then
        row = CreateFrame("Frame", nil, parent)
        row:EnableMouse(true)
        row:SetScript("OnEnter", OnOptionRowEnter)
        row:SetScript("OnLeave", OnOptionRowLeave)

        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.label:SetFontObject(SpecSageBodyFontSmall)
        row.label:SetJustifyH("LEFT")
        row.label:SetPoint("LEFT", row, "LEFT", 0, 0)

        row.minusButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.minusButton:SetSize(OPTION_STEP_BUTTON_WIDTH, 18)
        row.minusButton:SetText("-")
        SkinButton(row.minusButton)

        row.value = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.value:SetFontObject(SpecSageBodyFontSmall)
        row.value:SetJustifyH("CENTER")

        row.plusButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.plusButton:SetSize(OPTION_STEP_BUTTON_WIDTH, 18)
        row.plusButton:SetText("+")
        SkinButton(row.plusButton)

        -- Anchored right-to-left so the trio keeps its shape at any row
        -- width: [+] sits at the right edge, the value left of it, [-] left
        -- of that.
        row.plusButton:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.value:SetPoint("RIGHT", row.plusButton, "LEFT", -4, 0)
        row.value:SetWidth(OPTION_VALUE_WIDTH)
        row.minusButton:SetPoint("RIGHT", row.value, "LEFT", -4, 0)

        pool[index] = row
    end
    return row
end

local function AcquireOptionActionRow(pool, index, parent)
    local row = pool[index]
    if not row then
        row = CreateFrame("Frame", nil, parent)
        row:EnableMouse(true)
        row:SetScript("OnEnter", OnOptionRowEnter)
        row:SetScript("OnLeave", OnOptionRowLeave)

        row.button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.button:SetSize(140, 20)
        row.button:SetPoint("LEFT", row, "LEFT", 0, 0)
        SkinButton(row.button)

        pool[index] = row
    end
    return row
end

function Codex:EnsureOptionWidgets()
    if self.optionPools then return end
    self.optionPools = { check = {}, range = {}, action = {} }
end

-- Applies a changed option and refreshes both the overlay (so the change is
-- visible immediately) and this tab (so the widget reflects the stored
-- value, including a clamp that refused to move).
function Codex:OnOptionChanged()
    ns.RefreshAll()
    if self.activeTab == "Options" then self:RenderActiveTab() end
end

function Codex:ToggleOption(entry)
    ns.SetOptionValue(entry, not ns.GetOptionValue(entry))
    self:OnOptionChanged()
end

function Codex:StepOption(entry, direction)
    local current = tonumber(ns.GetOptionValue(entry)) or entry.min
    ns.SetOptionValue(entry, ns.ClampOptionValue(entry, current + direction * entry.step))
    self:OnOptionChanged()
end

function Codex:RenderOptions()
    self:EnsureOptionWidgets()

    local parent, width = self.scrollChild, self.contentWidth
    local pool = self.pools.options
    local pools = self.optionPools
    local y = -PADDING
    local textIndex = 0
    local used = { check = 0, range = 0, action = 0 }

    for groupIndex, group in ipairs(ns.OPTION_GROUPS) do
        if groupIndex > 1 then y = y - GROUP_GAP end

        textIndex = textIndex + 1
        y = PlaceLine(pool, textIndex, parent, y, width, group.title, { color = HEADER_COLOR, isHeader = true })

        for _, entry in ipairs(group.options) do
            if entry.kind == "check" then
                used.check = used.check + 1
                local row = AcquireOptionCheckRow(pools.check, used.check, parent)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
                row:SetSize(width, OPTION_ROW_HEIGHT)
                row.label:SetText(entry.label or "")
                row.label:SetTextColor(TEXT_SECONDARY_COLOR[1], TEXT_SECONDARY_COLOR[2], TEXT_SECONDARY_COLOR[3])
                row.mark:SetShown(ns.GetOptionValue(entry) and true or false)
                SetOptionTooltip(row, entry)
                row.box:SetScript("OnClick", function() self:ToggleOption(entry) end)
                row:Show()
                y = y - OPTION_ROW_HEIGHT

            elseif entry.kind == "range" then
                used.range = used.range + 1
                local row = AcquireOptionRangeRow(pools.range, used.range, parent)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
                row:SetSize(width, OPTION_ROW_HEIGHT)
                row.label:SetText(entry.label or "")
                row.label:SetTextColor(TEXT_SECONDARY_COLOR[1], TEXT_SECONDARY_COLOR[2], TEXT_SECONDARY_COLOR[3])

                local value = tonumber(ns.GetOptionValue(entry)) or entry.min
                local formatter = entry.formatter
                row.value:SetText(formatter and formatter(value) or tostring(value))
                row.value:SetTextColor(TEXT_PRIMARY_COLOR[1], TEXT_PRIMARY_COLOR[2], TEXT_PRIMARY_COLOR[3])

                -- A stepper at the end of its range is disabled rather than
                -- silently doing nothing when clicked.
                row.minusButton:SetEnabled(value > entry.min)
                row.plusButton:SetEnabled(value < entry.max)
                row.minusButton:SetScript("OnClick", function() self:StepOption(entry, -1) end)
                row.plusButton:SetScript("OnClick", function() self:StepOption(entry, 1) end)

                SetOptionTooltip(row, entry)
                row:Show()
                y = y - OPTION_ROW_HEIGHT

            elseif entry.kind == "action" then
                local action = ns.OPTION_ACTIONS[entry.action]
                if action then
                    used.action = used.action + 1
                    local row = AcquireOptionActionRow(pools.action, used.action, parent)
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
                    row:SetSize(width, OPTION_ROW_HEIGHT)
                    row.button:SetText(entry.buttonText or entry.label or "")
                    row.button:SetScript("OnClick", function()
                        pcall(action)
                        self:OnOptionChanged()
                    end)
                    SetOptionTooltip(row, entry)
                    row:Show()
                    y = y - OPTION_ROW_HEIGHT
                end
            end
        end
    end

    HidePoolFrom(pools.check, used.check + 1)
    HidePoolFrom(pools.range, used.range + 1)
    HidePoolFrom(pools.action, used.action + 1)

    self:FinishPool(pool, textIndex, y)
end

--------------------------------------------------------------------------------
-- Tab dispatch
--------------------------------------------------------------------------------

-- Every simple-text pool, plus the Loadouts row pool and the Notes box, are
-- hidden before rendering the newly active tab; only one tab's widgets are
-- ever visible at a time, all sharing the same scroll child.
local POOL_BY_TAB = { Overview = "overview", Stats = "stats", Rotation = "rotation", Cooldowns = "cooldowns", Consumables = "consumables", BiS = "bis", Options = "options" }

function Codex:HideOtherTabWidgets(activeTab)
    for tabName, poolName in pairs(POOL_BY_TAB) do
        if tabName ~= activeTab then
            HidePoolFrom(self.pools[poolName], 1)
        end
    end

    if activeTab ~= "BiS" then
        if self.trinketRowPool then HidePoolFrom(self.trinketRowPool, 1) end
        if self.trinketToggle then self.trinketToggle:Hide() end
        if self.bisLinkRowPool then HidePoolFrom(self.bisLinkRowPool, 1) end
        if self.bisListToggle then self.bisListToggle:Hide() end
    end

    if activeTab ~= "Stats" and self.statLinePool then
        HidePoolFrom(self.statLinePool, 1)
    end

    if activeTab ~= "Loadouts" then
        if self.loadoutButtons then
            self.loadoutButtons.save:Hide()
            self.loadoutButtons.add:Hide()
        end
        if self.loadoutRowPool then HidePoolFrom(self.loadoutRowPool, 1) end
        if self.suggestedLoadoutRows then
            for _, row in pairs(self.suggestedLoadoutRows) do row:Hide() end
        end
        if self.siteLoadoutRowPool then HidePoolFrom(self.siteLoadoutRowPool, 1) end
    end

    if activeTab ~= "Options" and self.optionPools then
        HidePoolFrom(self.optionPools.check, 1)
        HidePoolFrom(self.optionPools.range, 1)
        HidePoolFrom(self.optionPools.action, 1)
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
    elseif tab == "Options" then
        self:RenderOptions()
    end

    self:UpdateTabHighlight()
end

--------------------------------------------------------------------------------
-- Class rail / spec rail / tab strip
--------------------------------------------------------------------------------

function Codex:UpdateClassHighlight()
    local color = ClassColor(self.selectedClass)

    if self.frame then
        -- The frame's real border is now the 3-piece cross ApplyRoundedCorners
        -- built (SetBackdropBorderColor is a no-op alpha-0 leftover) - the 4
        -- small corner tiles deliberately stay a fixed color rather than also
        -- being tinted per class, see that function's own comment.
        for _, piece in ipairs(self.frame.roundedBorderPieces or {}) do
            pcall(piece.SetColorTexture, piece, color.r, color.g, color.b, 1)
        end
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
                btn.label:SetTextColor(TEXT_SECONDARY_COLOR[1], TEXT_SECONDARY_COLOR[2], TEXT_SECONDARY_COLOR[3])
            end
        end
    end
end

function Codex:UpdateTabHighlight()
    -- Bronze ACCENT_COLOR by default; once a real class is selected (not
    -- DEFAULT_CLASS_COLOR's neutral gray fallback), the active-tab
    -- underline shifts to that class's own color instead.
    local color = self.selectedClass and ClassColor(self.selectedClass)
    local accentR, accentG, accentB = ACCENT_COLOR[1], ACCENT_COLOR[2], ACCENT_COLOR[3]
    if color and color ~= DEFAULT_CLASS_COLOR then
        accentR, accentG, accentB = color.r, color.g, color.b
    end

    for tabName, btn in pairs(self.tabButtons or {}) do
        local isActive = (tabName == self.activeTab)
        local fontString = btn.GetFontString and btn:GetFontString()
        if fontString then
            if isActive then
                fontString:SetTextColor(unpack(TEXT_PRIMARY_COLOR))
            else
                fontString:SetTextColor(unpack(TEXT_SECONDARY_COLOR))
            end
        end
        if btn.tabUnderline then
            btn.tabUnderline:SetShown(isActive)
            if isActive then
                btn.tabUnderline:SetColorTexture(accentR, accentG, accentB)
            end
        end
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
            btn:SetSize(SPEC_RAIL_WIDTH - 8, 32)

            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetSize(24, 24)
            btn.icon:SetPoint("LEFT", btn, "LEFT", 0, 0)

            btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btn.label:SetFontObject(SpecSageBodyFontSmall)
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
        btn:SetSize(CLASS_RAIL_WIDTH - 8, 30)
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
        label:SetFontObject(SpecSageBodyFontSmall)
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
        SkinButton(btn)

        -- Active-tab indicator: a 2px underline in the selected class's
        -- color (falls back to the flat bronze ACCENT_COLOR - see
        -- UpdateTabHighlight) instead of the old plain alpha dim/undim.
        local underline = btn:CreateTexture(nil, "OVERLAY")
        underline:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 0)
        underline:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 0)
        underline:SetHeight(2)
        underline:Hide()
        btn.tabUnderline = underline

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
    self.contentWidth = CONTENT_WIDTH
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    self.scrollFrame = scrollFrame
    self.scrollChild = scrollChild
    self.pools = { overview = {}, stats = {}, rotation = {}, cooldowns = {}, consumables = {}, bis = {}, options = {} }
    -- Stats tab's second, wrapping pool: the per-hero-tree priorities and
    -- their notes, which are text rows rather than label/value stat rows.
    self.statLinePool = {}
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
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    -- Alpha 0: the backdrop's own flat square fill/border is replaced by
    -- ApplyRoundedCorners' manual texture stack below. A visible backdrop
    -- fill here would paint the 4 corner squares too, defeating the
    -- rounding (see that function's own comment for why).
    frame:SetBackdropColor(0, 0, 0, 0)
    frame:SetBackdropBorderColor(0, 0, 0, 0)
    ApplyPanelChrome(frame, PANEL_BG_TOP, PANEL_BG_BOTTOM)
    ApplyRoundedCorners(frame, PANEL_BACKDROP_COLOR, PANEL_BORDER_COLOR)

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

    -- Feedback button in the title bar, left of the close button: shows the
    -- GitHub Issues link ready to copy (see Codex:ShowFeedback).
    local feedbackButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    feedbackButton:SetSize(84, 20)
    feedbackButton:SetPoint("RIGHT", closeButton, "LEFT", -6, 0)
    feedbackButton:SetText("Feedback")
    feedbackButton:SetScript("OnClick", function() self:ShowFeedback() end)
    SkinButton(feedbackButton)
    frame.feedbackButton = feedbackButton

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
