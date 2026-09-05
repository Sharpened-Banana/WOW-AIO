-- Modules/TalentButton.lua
-- A "SpecSage" button in Blizzard's talent window. Click it for a list of
-- every build SpecSage knows for the spec you are on - the SimC-suggested
-- Mythic+ and Raid builds, the live top-players' build, the guide sites'
-- builds, and your own saved loadouts - and pick one to lay it onto the
-- tree, using the same view-a-loadout path the Codex's View buttons use
-- (Loadouts:OpenInTalentUI: nothing is applied or saved until you choose
-- to). Added at the owner's request on 2026-09-05: the Codex is where you
-- read about a build, the talent window is where you try it, and having to
-- walk between the two to do so was the friction.
--
-- The button lives on the Talents tab of the PlayerSpells window (or the
-- older ClassTalent window), which is load-on-demand; the module attaches
-- when Blizzard_PlayerSpells loads, or straight away if it already has.

local ADDON, ns = ...

local TalentButton = ns:NewModule("TalentButton")

local MENU_WIDTH = 300
local ROW_HEIGHT = 22
local MENU_PADDING = 10
local HEADER_HEIGHT = 20

-- The talent tab frame under whichever name this client uses.
local function TalentsFrame()
    if PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame then return PlayerSpellsFrame.TalentsFrame end
    if ClassTalentFrame and ClassTalentFrame.TalentsTab then return ClassTalentFrame.TalentsTab end
    return nil
end

-- Only a real frame can parent our button; the test mock's stand-in table
-- for the View path is not one.
local function IsFrame(candidate)
    return type(candidate) == "table" and type(candidate.CreateFontString) == "function"
end

--------------------------------------------------------------------------------
-- What to list
--------------------------------------------------------------------------------

-- The builds for `specID`, in the order the menu shows them:
-- { { name, detail, string, source }, ... }. `detail` is the second line
-- (where the build came from); `source` groups rows under a header.
function TalentButton:BuildsFor(specID)
    local builds = {}
    if type(specID) ~= "number" then return builds end

    local guide = ns.GuideStore and ns.GuideStore:GetGuide(specID)
    if guide then
        local suggested = {
            { field = "mplusLoadout", name = "Suggested Mythic+", detail = "SimulationCraft" },
            { field = "raidLoadout", name = "Suggested Raid", detail = "SimulationCraft" },
            { field = "mplusMetaLoadout", name = "Top Players' Mythic+ Build", detail = "Blizzard's API" },
        }
        for _, kind in ipairs(suggested) do
            local loadout = guide[kind.field]
            if type(loadout) == "table" and type(loadout.string) == "string" and loadout.string ~= "" then
                local detail = kind.detail
                if loadout.patch then detail = detail .. ", patch " .. tostring(loadout.patch) end
                builds[#builds + 1] = { name = kind.name, detail = detail, string = loadout.string, source = "SpecSage" }
            end
        end
    end

    local site = ns.GuideStore and ns.GuideStore:GetSiteLoadouts(specID)
    if site and type(site.builds) == "table" then
        for _, build in ipairs(site.builds) do
            if type(build.string) == "string" and build.string ~= "" then
                builds[#builds + 1] = { name = build.label or "Build", detail = build.site or site.source or "guide site",
                                        string = build.string, source = "Guide sites" }
            end
        end
    end

    local Loadouts = ns:GetModule("Loadouts")
    if Loadouts then
        for _, entry in ipairs(Loadouts:GetForSpec(specID) or {}) do
            if type(entry.export) == "string" and entry.export ~= "" then
                builds[#builds + 1] = { name = entry.name or "Saved build", detail = entry.category or "Saved",
                                        string = entry.export, source = "My vault" }
            end
        end
    end

    return builds
end

--------------------------------------------------------------------------------
-- The menu
--------------------------------------------------------------------------------

function TalentButton:EnsureMenu()
    if self.menu then return self.menu end
    local button = self.button
    if not button then return nil end

    local menu = CreateFrame("Frame", "SpecSageTalentMenu", button, "BackdropTemplate")
    menu:SetWidth(MENU_WIDTH)
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -4)
    menu:SetFrameStrata("DIALOG")
    pcall(menu.SetClampedToScreen, menu, true)
    if ns.SetParchmentBackdrop then ns.SetParchmentBackdrop(menu) end
    menu:EnableMouse(true)
    menu:Hide()

    menu.title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if SpecSageHeadingFont then menu.title:SetFontObject(SpecSageHeadingFont) end
    menu.title:SetPoint("TOPLEFT", menu, "TOPLEFT", MENU_PADDING, -MENU_PADDING)
    menu.title:SetJustifyH("LEFT")

    menu.rows = {}
    menu.headers = {}
    self.menu = menu

    -- Clicking anywhere else closes it (checked on the next frame so the
    -- click that opened it does not also close it).
    menu:SetScript("OnUpdate", function(frame)
        if not frame:IsShown() then return end
        if IsMouseButtonDown and IsMouseButtonDown("LeftButton") and not (frame.IsMouseOver and frame:IsMouseOver())
            and not (button.IsMouseOver and button:IsMouseOver()) then
            frame:Hide()
        end
    end)
    return menu
end

local function AcquireHeader(menu, index)
    local header = menu.headers[index]
    if not header then
        header = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        if SpecSageBoldFontSmall then header:SetFontObject(SpecSageBoldFontSmall) end
        header:SetJustifyH("LEFT")
        menu.headers[index] = header
    end
    return header
end

local function AcquireRow(menu, index, onClick)
    local row = menu.rows[index]
    if not row then
        row = CreateFrame("Button", nil, menu)
        row:SetHeight(ROW_HEIGHT)
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        if SpecSageBodyFontSmall then row.name:SetFontObject(SpecSageBodyFontSmall) end
        row.name:SetJustifyH("LEFT")
        row.name:SetPoint("LEFT", row, "LEFT", 8, 0)
        row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        if SpecSageItalicFont then row.detail:SetFontObject(SpecSageItalicFont) end
        row.detail:SetJustifyH("RIGHT")
        row.detail:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        -- A flat wax-red wash on hover, like the Codex's buttons.
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(row)
        highlight:SetColorTexture(0.478, 0.184, 0.122, 0.16)
        row:SetScript("OnClick", function(self) onClick(self) end)
        menu.rows[index] = row
    end
    return row
end

-- Lays a build onto the tree; reports Loadouts' reason in chat when it
-- cannot (the window is closed, in combat, a build for another spec).
function TalentButton:Pick(build)
    local Loadouts = ns:GetModule("Loadouts")
    if not Loadouts then return end
    local result, reason = Loadouts:OpenInTalentUI(build.string, build.name)
    if not result then
        ns.Print("could not show that build: " .. tostring(reason))
    end
    if self.menu then self.menu:Hide() end
    return result
end

function TalentButton:FillMenu()
    local menu = self:EnsureMenu()
    if not menu then return end
    local Loadouts = ns:GetModule("Loadouts")
    local specID = Loadouts and Loadouts:GetCurrentSpecID()
    local guide = specID and ns.GuideStore and ns.GuideStore:GetGuide(specID)
    menu.title:SetText(guide and guide.specName and ("SpecSage builds - " .. guide.specName) or "SpecSage builds")

    local builds = self:BuildsFor(specID)
    local y = -(MENU_PADDING + HEADER_HEIGHT + 4)
    local rowIndex, headerIndex, lastSource = 0, 0, nil
    for _, build in ipairs(builds) do
        if build.source ~= lastSource then
            headerIndex = headerIndex + 1
            local header = AcquireHeader(menu, headerIndex)
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", menu, "TOPLEFT", MENU_PADDING, y - 4)
            header:SetText(build.source)
            header:Show()
            y = y - HEADER_HEIGHT
            lastSource = build.source
        end
        rowIndex = rowIndex + 1
        local row = AcquireRow(menu, rowIndex, function(self) TalentButton:Pick(self.build) end)
        row.build = build
        row.name:SetText(build.name)
        row.detail:SetText(build.detail or "")
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, y)
        row:SetWidth(MENU_WIDTH - 4)
        row:Show()
        y = y - ROW_HEIGHT
    end
    for i = rowIndex + 1, #menu.rows do menu.rows[i]:Hide() end
    for i = headerIndex + 1, #menu.headers do menu.headers[i]:Hide() end

    if #builds == 0 then
        headerIndex = 1
        local header = AcquireHeader(menu, 1)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", menu, "TOPLEFT", MENU_PADDING, y - 4)
        header:SetText("No builds for this spec yet - save one from the Codex's Loadouts tab.")
        header:Show()
        y = y - HEADER_HEIGHT
    end

    menu:SetHeight(-y + MENU_PADDING)
    menu.buildCount = #builds
end

function TalentButton:ToggleMenu()
    local menu = self:EnsureMenu()
    if not menu then return end
    if menu:IsShown() then
        menu:Hide()
    else
        self:FillMenu()
        menu:Show()
    end
end

--------------------------------------------------------------------------------
-- Attaching to the talent window
--------------------------------------------------------------------------------

function TalentButton:Attach()
    local frame = TalentsFrame()
    if not IsFrame(frame) then return false end
    if self.button and self.attachedTo == frame then return true end

    local button = CreateFrame("Button", "SpecSageTalentButton", frame, "UIPanelButtonTemplate")
    button:SetSize(90, 22)
    button:SetText("SpecSage")
    -- Bottom left of the tab, clear of Blizzard's loadout dropdown (top),
    -- search box (top right) and Apply / Undo (bottom centre).
    button:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 6)
    pcall(button.SetFrameStrata, button, "HIGH")
    if ns.SkinButton then ns.SkinButton(button) end
    button:SetScript("OnClick", function() self:ToggleMenu() end)
    button:SetScript("OnEnter", function()
        pcall(function()
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText("SpecSage")
            GameTooltip:AddLine("Lay one of SpecSage's builds for this spec onto the tree. Nothing is saved or applied until you choose to.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
    end)
    button:SetScript("OnLeave", function() pcall(function() GameTooltip:Hide() end) end)
    button:SetScript("OnHide", function() if self.menu then self.menu:Hide() end end)

    self.button = button
    self.attachedTo = frame
    self.menu = nil
    return true
end

function TalentButton:OnEnable()
    self:Attach()
    -- Blizzard_PlayerSpells is load-on-demand: attach when it arrives.
    ns:RegisterEvent("ADDON_LOADED", function(_, name)
        if name == "Blizzard_PlayerSpells" or name == "Blizzard_ClassTalentUI" then self:Attach() end
    end)
end
