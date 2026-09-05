-- Modules/MinimapButton.lua
-- A wax seal on the minimap ring. Left-click opens the Codex, right-click
-- toggles the stat overlay, drag it around the ring to move it. Added at the
-- owner's request on 2026-09-05, alongside /sage and the keybind - the
-- one addon entry point a player finds without reading anything.
--
-- No LibDBIcon / LibDataBroker: the addon bundles no libraries, and the
-- whole job is one button and a bit of trigonometry. The seal is the
-- Codex's own hero-seal art (Textures/wax_seal.png) with the addon's book
-- icon rounded off inside it, so the minimap carries the same mark as the
-- book's left page rather than a generic ring button.

local ADDON, ns = ...

local MinimapButton = ns:NewModule("MinimapButton")

local TEXTURE_PATH = "Interface\\AddOns\\SpecSage\\Textures\\"
local BOOK_ICON = "Interface\\Icons\\INV_Misc_Book_11"
local BUTTON_SIZE = 34
local ICON_SIZE = 22
-- How far past the minimap's edge the seal's centre sits.
local RING_INSET = 2

-- Where along the ring, in degrees from 3 o'clock going anticlockwise;
-- 220 is the lower left, out of the way of the clock and the tracking
-- button on the default minimap.
local DEFAULT_ANGLE = 220

-- WoW's Lua has math.atan2; a 5.3+ test interpreter folds it into atan.
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local function Settings()
    return ns.db and ns.db.minimap
end

-- The seal's offset from the minimap centre for an angle, on a round or a
-- square minimap (an addon that squares the minimap advertises it through
-- GetMinimapShape, the convention every minimap-button library follows).
function MinimapButton:OffsetFor(angle)
    local radius = (Minimap and Minimap.GetWidth and Minimap:GetWidth() or 140) / 2 + RING_INSET
    local rad = math.rad(angle)
    local x, y = math.cos(rad), math.sin(rad)
    local shape = (GetMinimapShape and GetMinimapShape()) or "ROUND"
    if shape == "SQUARE" then
        -- Slide along the square's edge rather than the inscribed circle.
        local scale = 1 / math.max(math.abs(x), math.abs(y))
        return x * radius * scale, y * radius * scale
    end
    return x * radius, y * radius
end

function MinimapButton:Reposition()
    local button = self.button
    if not button then return end
    local settings = Settings()
    local angle = (settings and settings.angle) or DEFAULT_ANGLE
    local x, y = self:OffsetFor(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Reads the cursor's angle about the minimap centre and pins the seal
-- there; runs every frame while the button is being dragged.
function MinimapButton:FollowCursor()
    if not Minimap or not Minimap.GetCenter then return end
    local mx, my = Minimap:GetCenter()
    if not mx then return end
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    local angle = math.deg(atan2(cy - my, cx - mx))
    if angle < 0 then angle = angle + 360 end
    local settings = Settings()
    if settings then settings.angle = angle end
    self:Reposition()
end

function MinimapButton:ShowTooltip()
    local button = self.button
    if not button or not GameTooltip then return end
    pcall(function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("SpecSage")
        GameTooltip:AddLine("Left-click: open the Codex", 1, 1, 1)
        GameTooltip:AddLine("Right-click: toggle the stat overlay", 1, 1, 1)
        GameTooltip:AddLine("Drag: move around the minimap", 1, 1, 1)
        GameTooltip:Show()
    end)
end

function MinimapButton:OnClick(mouseButton)
    if mouseButton == "RightButton" then
        if ns.UI and ns.UI.Toggle then ns.UI:Toggle() end
    else
        local Codex = ns:GetModule("Codex")
        if Codex then Codex:Toggle() end
    end
end

function MinimapButton:Create()
    if self.button or not Minimap then return end

    local button = CreateFrame("Button", "SpecSageMinimapButton", Minimap)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    pcall(button.RegisterForClicks, button, "LeftButtonUp", "RightButtonUp")
    pcall(button.RegisterForDrag, button, "LeftButton")
    button:SetMovable(true)
    button:EnableMouse(true)

    local wax = button:CreateTexture(nil, "ARTWORK")
    wax:SetAllPoints(button)
    wax:SetTexture(TEXTURE_PATH .. "wax_seal.png")
    button.wax = wax

    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexture(BOOK_ICON)
    pcall(icon.SetTexCoord, icon, 0.07, 0.93, 0.07, 0.93)
    pcall(function()
        local mask = button:CreateMaskTexture()
        mask:SetTexture(TEXTURE_PATH .. "circle_mask.png")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
    end)
    button.icon = icon

    -- A faint warm glow on hover, clipped to the seal.
    pcall(function()
        button:SetHighlightTexture(TEXTURE_PATH .. "wax_seal.png", "ADD")
        local highlight = button:GetHighlightTexture()
        highlight:SetAllPoints(button)
        highlight:SetVertexColor(1, 0.85, 0.6, 0.35)
    end)

    button:SetScript("OnClick", function(_, mouseButton) self:OnClick(mouseButton) end)
    button:SetScript("OnEnter", function() self:ShowTooltip() end)
    button:SetScript("OnLeave", function() pcall(function() GameTooltip:Hide() end) end)
    button:SetScript("OnDragStart", function()
        self.dragging = true
        pcall(function() GameTooltip:Hide() end)
        button:SetScript("OnUpdate", function() self:FollowCursor() end)
    end)
    button:SetScript("OnDragStop", function()
        self.dragging = false
        button:SetScript("OnUpdate", nil)
        self:Reposition()
    end)

    self.button = button
    self:Reposition()
end

function MinimapButton:Refresh()
    local settings = Settings()
    if not settings then return end
    if settings.shown then
        self:Create()
        if self.button then
            self:Reposition()
            self.button:Show()
        end
    elseif self.button then
        self.button:Hide()
    end
end

function MinimapButton:OnEnable()
    self:Refresh()
end

function MinimapButton:OnConfigChanged()
    self:Refresh()
end
