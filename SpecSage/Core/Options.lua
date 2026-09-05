-- Core/Options.lua
-- Interface Options entry built on the retail Settings API.

local ADDON, ns = ...

local Options = ns:NewModule("Options")

--------------------------------------------------------------------------------
-- Settings API helpers
--
-- Every call is guarded: the Settings API has changed signatures across
-- expansions, and a broken options panel should never take the overlay with it.
--------------------------------------------------------------------------------

-- Why every call here is guarded, and why the failures are now *recorded*
-- rather than silently dropped: a settings panel that half-registers is
-- indistinguishable from one that never built, and the previous version
-- swallowed the error text from three separate pcalls, so "/sage config does
-- nothing" carried no way to find out why. Anything that goes wrong lands in
-- this list and is reported once, with the real Lua error.
local failures = {}

local function RecordFailure(what, err)
    failures[#failures + 1] = format("%s: %s", what, tostring(err))
end

-- Settings.VarType is the documented way to declare a setting's type, but it
-- is a table lookup on a global that has moved before; fall back to the
-- plain Lua type names it holds, which is what the API compares against.
local function VarType(name)
    local varType = Settings.VarType and Settings.VarType[name]
    if varType ~= nil then return varType end
    return name:lower()
end

-- RegisterProxySetting has shipped with two argument orders: the current
-- 7-argument one, and an older 8-argument one carrying a `variableTbl` after
-- `variable`. Which one a client wants is decided ONCE, with throwaway probe
-- variable names, and then used for every real setting.
--
-- The previous version instead retried per setting: attempt the 7-arg form,
-- and on failure attempt the 8-arg form under the SAME variable name. On a
-- client wanting the 8-arg form that is a trap - the first attempt can claim
-- the variable name before it fails, so the retry dies on a duplicate
-- registration and *every* setting is lost while the category itself still
-- registers fine. The result is a settings panel that opens completely
-- empty, which is indistinguishable from "/sage config does nothing".
local PROBE_PREFIX = "SpecSage_signature_probe_"
local probeCount = 0
local proxyStyle

local function ProbeStyle(category)
    probeCount = probeCount + 1
    local variable = PROBE_PREFIX .. probeCount
    local get = function() return false end
    local set = function() end

    local ok, setting = pcall(Settings.RegisterProxySetting, category, variable,
        VarType("Boolean"), "probe", false, get, set)
    if ok and setting then return "modern" end
    local modernErr = setting

    probeCount = probeCount + 1
    variable = PROBE_PREFIX .. probeCount
    ok, setting = pcall(Settings.RegisterProxySetting, category, variable,
        nil, VarType("Boolean"), "probe", false, get, set)
    if ok and setting then return "legacy" end

    RecordFailure("signature probe", modernErr)
    return "unsupported"
end

local function RegisterProxy(category, variable, varType, name, default, get, set)
    if not proxyStyle then
        proxyStyle = ProbeStyle(category)
    end
    if proxyStyle == "unsupported" then return nil end

    local ok, setting
    if proxyStyle == "legacy" then
        ok, setting = pcall(Settings.RegisterProxySetting, category, variable, nil, varType, name, default, get, set)
    else
        ok, setting = pcall(Settings.RegisterProxySetting, category, variable, varType, name, default, get, set)
    end
    if ok and setting then return setting end

    RecordFailure(variable, ok and "registered nothing" or setting)
    return nil
end

local function AddCheckbox(category, variable, name, tooltip, get, set)
    -- A checkbox whose current value is not a boolean would be rejected by
    -- the client's own type check with a far less obvious error than this.
    local current = get()
    if type(current) ~= "boolean" then
        current = current and true or false
    end

    local setting = RegisterProxy(category, variable, VarType("Boolean"), name, current, get, function(value)
        set(value)
        ns.RefreshAll()
    end)
    if not setting then return end

    local ok, err = pcall(Settings.CreateCheckbox, category, setting, tooltip)
    if not ok then RecordFailure(variable .. " (checkbox)", err) end
end

local function AddSlider(category, variable, name, tooltip, minValue, maxValue, step, formatter, get, set)
    local current = tonumber(get()) or minValue

    local setting = RegisterProxy(category, variable, VarType("Number"), name, current, get, function(value)
        set(value)
        ns.RefreshAll()
    end)
    if not setting then return end

    local ok, options = pcall(Settings.CreateSliderOptions, minValue, maxValue, step)
    if not ok then
        RecordFailure(variable .. " (slider options)", options)
        options = nil
    end

    -- MinimalSliderWithSteppersMixin.Label.Right was indexed *outside* the
    -- pcall that was meant to protect it, so a client without that global
    -- (or without .Label on it) threw straight out of BuildPanel and killed
    -- the whole panel over one slider's label format.
    if options and options.SetLabelFormatter then
        local labelPosition = MinimalSliderWithSteppersMixin
            and MinimalSliderWithSteppersMixin.Label
            and MinimalSliderWithSteppersMixin.Label.Right
        if labelPosition ~= nil then
            pcall(options.SetLabelFormatter, options, labelPosition, formatter)
        end
    end

    local created, err = pcall(Settings.CreateSlider, category, setting, options, tooltip)
    if not created then RecordFailure(variable .. " (slider)", err) end
end

-- optionsList is an array of { value, label }. Dropdown-backed settings are
-- always NUMERIC (an index into that list), never string. The one
-- confirmed-working example in Blizzard's own settings-menu documentation
-- backs a dropdown with a plain number (RegisterAddOnSetting's default is 1,
-- typed via type(1) == "number"); VarType.String is not something that
-- example - or any other found - actually uses for a dropdown, and
-- mismatched setting metadata is exactly what surfaces later as an
-- assertion failure deep inside Blizzard_SettingControls.lua when the
-- control gets built. get/set here therefore speak in indices; the caller
-- translates to and from its real value.
--
-- The option list is handed over as a generator function rather than a
-- fixed table because that is the real CreateDropdown contract: it calls
-- the function each time the control is built, so a list that changes at
-- runtime is always current.
local function AddDropdown(category, variable, name, tooltip, optionsList, get, set)
    local current = tonumber(get()) or 1

    local setting = RegisterProxy(category, variable, VarType("Number"), name, current, get, function(value)
        set(value)
        ns.RefreshAll()
    end)
    if not setting then return end

    local function GetOptions()
        local ok, container = pcall(Settings.CreateControlTextContainer)
        if not ok or not container then return nil end
        for _, entry in ipairs(optionsList) do
            container:Add(entry.value, entry.label)
        end
        return container:GetData()
    end

    local ok, err = pcall(Settings.CreateDropdown, category, setting, GetOptions, tooltip)
    if not ok then RecordFailure(variable .. " (dropdown)", err) end
end

local function AddHeader(layout, text)
    if not CreateSettingsListSectionHeaderInitializer then return end
    pcall(layout.AddInitializer, layout, CreateSettingsListSectionHeaderInitializer(text))
end

-- CreateSettingsButtonInitializer's 5th argument, addSearchTags, is
-- asserted non-nil by the 12.1 client (Blizzard_SettingControls.lua:915,
-- "assertion failed!"): a 4-argument call takes the whole panel down with
-- it. `true` is what every Blizzard caller that wants the button findable
-- in the settings search passes. The call also sits *inside* the pcall now:
-- it used to be evaluated as an argument to it, so its own error escaped.
local function AddButton(layout, name, buttonText, onClick, tooltip)
    if not CreateSettingsButtonInitializer then return end
    local ok, err = pcall(function()
        local initializer = CreateSettingsButtonInitializer(name, buttonText, onClick, tooltip, true)
        layout:AddInitializer(initializer)
    end)
    if not ok then RecordFailure(name .. " (button)", err) end
end

--------------------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------------------

local function BuildPanel()
    -- Rebuilding starts from a clean slate so a retry cannot report stale
    -- failures from a previous attempt.
    failures = {}
    proxyStyle = nil

    local category, layout = Settings.RegisterVerticalLayoutCategory("SpecSage")
    if not category then return nil end

    -- Driven entirely by ns.OPTION_GROUPS (Core/Config.lua), which the
    -- Codex's own Options tab renders from as well - the two surfaces show
    -- the same settings because they read the same table, not because two
    -- lists were kept in step by hand.
    for _, group in ipairs(ns.OPTION_GROUPS) do
        AddHeader(layout, group.title)

        for _, entry in ipairs(group.options) do
            if entry.kind == "check" then
                AddCheckbox(category, entry.variable, entry.label, entry.tooltip,
                    function() return ns.GetOptionValue(entry) end,
                    function(value) ns.SetOptionValue(entry, value) end)

            elseif entry.kind == "range" then
                AddSlider(category, entry.variable, entry.label, entry.tooltip,
                    entry.min, entry.max, entry.step, entry.formatter,
                    function() return ns.GetOptionValue(entry) end,
                    function(value) ns.SetOptionValue(entry, value) end)

            elseif entry.kind == "select" then
                -- The dropdown speaks in list indices (see AddDropdown);
                -- the schema's choices carry the real stored values, so the
                -- translation happens here, once, for every select.
                local choices = ns.OptionChoices(entry)
                local optionsList = {}
                for index, choice in ipairs(choices) do
                    optionsList[index] = { value = index, label = choice.label }
                end
                AddDropdown(category, entry.variable, entry.label, entry.tooltip, optionsList,
                    function() return ns.OptionChoiceIndex(entry) end,
                    function(index)
                        local choice = choices[index] or choices[1]
                        if choice then ns.SetOptionValue(entry, choice.value) end
                    end)

            elseif entry.kind == "action" then
                local action = ns.OPTION_ACTIONS[entry.action]
                if action then
                    AddButton(layout, entry.label, entry.buttonText, function()
                        pcall(action)
                    end, entry.tooltip)
                end
            end
        end
    end

    Settings.RegisterAddOnCategory(category)
    return category
end

-- What went wrong while the panel was last built, oldest first; empty when
-- every widget registered. Exposed so the test suite (and a curious
-- /dump) can tell a fully built panel from one that half-registered.
function Options:GetFailures()
    return failures
end

function Options:OnEnable()
    if not Settings or not Settings.RegisterVerticalLayoutCategory then
        ns.Print("this game version has no Settings API; use /sage for configuration.")
        return
    end
    if not Settings.RegisterProxySetting then
        ns.Print("this game version has no Settings.RegisterProxySetting; use /sage for configuration.")
        return
    end

    local ok, category = pcall(BuildPanel)
    if ok and category then
        self.category = category
        -- Individually failed widgets no longer pass unnoticed: the panel
        -- opens with whatever registered, and the reason the rest did not is
        -- printed once instead of being lost inside three pcalls.
        if #failures > 0 then
            ns.Print(format("|cffff4444%d option(s) failed to register|r - first: %s", #failures, failures[1]))
        end
    else
        -- pcall's second return is the error; printing it is the whole point.
        ns.Print("|cffff4444could not build the options panel|r: " .. tostring(category))
        ns.Print("use /sage help for the slash-command equivalents.")
    end
end

-- Opens the panel. OpenToCategory takes a category ID (category:GetID()),
-- but GetID has not always existed on the returned category, and passing the
-- category object itself is accepted by some revisions - so try the ID and
-- fall back to the object rather than erroring out of the slash command.
function ns.OpenOptions()
    local category = Options.category
    if not category or not Settings or not Settings.OpenToCategory then
        ns.Print("options panel unavailable; use /sage help for commands.")
        return
    end

    local categoryID
    if type(category.GetID) == "function" then
        local ok, id = pcall(category.GetID, category)
        if ok then categoryID = id end
    end

    if categoryID ~= nil and pcall(Settings.OpenToCategory, categoryID) then return end
    if pcall(Settings.OpenToCategory, category) then return end

    ns.Print("could not open the options panel; use /sage help for commands.")
end
