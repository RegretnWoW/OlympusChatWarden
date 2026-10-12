local ADDON_NAME, ns = ...
ns.NAME, ns.VERSION = "Olympus ChatWarden", "0.9.0-rc49"
ns.TAGLINE = "CHUDS WITHOUT BORDERS"
ns.REPORT_URL = "https://github.com/RegretnWoW/OlympusChatWarden/issues"
ns.PROJECT_URL = "https://github.com/RegretnWoW/OlympusChatWarden"
ns.PolicyRevision, ns.Interaction = 0, 0
local cache, order, cursor, cacheBytes, cacheRecords = {}, {}, 1, 0, 0
ns.Stats = {scans = 0, cacheHits = 0, uiBlocks = 0, chatMatches = 0, skipped = 0}

function ns.CanRead(value)
    if issecretvalue and issecretvalue(value) then return false end
    if canaccessvalue and not canaccessvalue(value) then return false end
    return type(value) == "string"
end

-- Classic clients can return 1/nil instead of true/false from checkboxes.
-- Store a real boolean so the next login does not reset a numeric preference.
function ns.Checked(value)
    if issecretvalue and issecretvalue(value) then return false end
    if canaccessvalue and not canaccessvalue(value) then return false end
    return value == true or value == 1
end

function ns.Print(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffdd3333OCW:|r " .. message) end
end

function ns.Active(scope)
    return ns.DB and ns.DB.enabled and ns.DB[scope] ~= false
        and ns.Membership and ns.Membership.Allowed()
end

function ns.Find(text)
    if not ns.CanRead(text) or #text > ns.Engine.MAX_TEXT then
        ns.Stats.skipped = ns.Stats.skipped + 1
        return {}
    end
    if cache[text] then
        ns.Stats.cacheHits = ns.Stats.cacheHits + 1
        return cache[text]
    end
    ns.Stats.scans = ns.Stats.scans + 1
    local matches, report, err = ns.Confidence.Analyze(ns.Matcher, text, ns.DB, ns.ExceptionMatcher)
    if err then ns.Stats.skipped = ns.Stats.skipped + 1 end
    if cacheBytes + #text > 262144 or cacheRecords + #matches > 8192 then
        cache, order, cursor, cacheBytes, cacheRecords = {}, {}, 1, 0, 0
    end
    local previous = order[cursor]
    if previous then
        cacheBytes = cacheBytes - #previous; cacheRecords = cacheRecords - #cache[previous]; cache[previous] = nil
    end
    order[cursor], cache[text] = text, matches
    cacheBytes = cacheBytes + #text
    cacheRecords = cacheRecords + #matches
    cursor = cursor % 128 + 1
    return matches
end

function ns.PolicyChanged()
    ns.PolicyRevision = ns.PolicyRevision + 1
    cache, order, cursor, cacheBytes, cacheRecords = {}, {}, 1, 0, 0
    if ns.Language then ns.Language.Invalidate() end
    if ns.Spam then ns.Spam.Reset() end
    if ns.ChatFonts then ns.ChatFonts.Refresh() end
    if ns.Initializing then return end
    if ns.Matcher and ns.RefreshUI then ns.RefreshUI(true) end
    if ns.ScanTooltips then ns.ScanTooltips() end
    if ns.RefreshBubbles then ns.RefreshBubbles() end
    if ns.QueueNameScan then ns.QueueNameScan() end
    if ns.LanguageDisplay then ns.LanguageDisplay.Refresh() end
    if ns.NameplateRecovery then ns.NameplateRecovery.Refresh() end
end

function ns.SetPreset(preset)
    preset = ({selective = "strict", broad = "aggressive", all = "maximum", gommage = "maximum", ["all listed terms"] = "maximum"})[preset] or preset
    if not ns.Confidence.Presets[preset] then return false, "Choose selective, balanced, broad, or gommage." end
    ns.DB.preset = preset; ns.PolicyChanged(); return true
end
function ns.SetPackPreset(pack, preset)
    local known
    for _, name in ipairs(ns.PackNames) do if name == pack then known = true end end
    if not known then return false, "Unknown category." end
    preset = ({selective = "strict", broad = "aggressive", all = "maximum", gommage = "maximum"})[preset] or preset
    if preset ~= "default" and preset ~= "off" and not ns.Confidence.Presets[preset] then
        return false, "Choose default, off, selective, balanced, broad, or gommage."
    end
    ns.DB.disabledPacks[pack] = preset == "off"
    ns.DB.packPresets[pack] = ns.Confidence.Presets[preset] and preset or nil
    ns.PolicyChanged(); return true
end

function ns.SetExceptions(rules)
    local matcher, err = ns.Engine.Compile(rules)
    if not matcher then return false, err end
    if #matcher.rules > 256 then return false, "Maximum 256 exception phrases." end
    ns.ExceptionMatcher, ns.DB.exceptions = matcher, matcher.rules
    ns.PolicyChanged(); return true
end

function ns.SetRules(rules)
    local matcher, errorMessage = ns.Engine.Compile(rules)
    if not matcher then return false, errorMessage end
    ns.Matcher = matcher
    ns.DB.rules = nil -- compile from installed, verified packs instead of saved legacy catalogs
    -- Old chat links retain their original matched phrases until normal eviction.
    ns.PolicyChanged()
    return true, #matcher.rules
end

function ns.Status()
    ns.Print(ns.NAME .. " v" .. ns.VERSION .. " - " .. (ns.Active() and "active" or "paused"))
    ns.Print(ns.Membership.Status())
    local label = ({maximum = "Gommage", aggressive = "Broad", balanced = "Balanced", strict = "Selective"})[ns.DB.preset]
    ns.Print("Preset: " .. label .. "; " .. #ns.Personal.rules .. " personal rules; " .. #ns.Personal.reports .. " saved reports.")
    local overrides = 0
    for _, pack in ipairs(ns.PackNames) do if ns.DB.packPresets[pack] then overrides = overrides + 1 end end
    ns.Print(overrides .. " category preset overrides. Configure with /ocw categories.")
    ns.Print(#ns.PackNames .. " installed categories. Manage imports with /ocw packs.")
    if ns.NameDisplays then ns.NameDisplays.Scan() end
    if ns.RevealStatus then ns.Print(ns.RevealStatus()) end
    if ns.NameDisplays then ns.Print(ns.NameDisplays.Status()) end
end

-- Olympus is the normal launcher. Slash commands remain available for setup.
function ns.SetLauncher(mode)
    if mode ~= "olympus" then return false end
    ns.DB.olympusIntegration = true
    ns.DB.minimap = nil
    if ns.OlympusIntegration then ns.OlympusIntegration.Refresh() end
    if ns.BuildMinimap then ns.BuildMinimap() end
    if ns.SyncOptions then ns.SyncOptions() end
    return true
end

function ns.Initialize()
    ns.Initializing = true
    ns.Membership.InstallAccessGuards()
    if type(OlympusChatWardenDB) ~= "table" then OlympusChatWardenDB = {} end
    ns.DB = OlympusChatWardenDB
    local defaults={enabled=true,chat=true,npc=false,barber=true,bubbles=true,captureAlerts=true,olympusMuteSignal=true,languageEnabled=false,
        dialogue=false,vendor=false,nameplates=false,targetNames=false,tooltips=false,
        playerNames=false,npcNames=false,talkingHead=false,history=true,context=true}
    for key,default in pairs(defaults) do
        if ns.DB[key] == 1 or ns.DB[key] == 0 then ns.DB[key] = ns.Checked(ns.DB[key]) end
        if type(ns.DB[key]) ~= "boolean" then ns.DB[key] = default end
    end
    ns.DB.worldNames, ns.DB.olympusText = nil, nil -- retired adapters; reports retain captured policy
    if type(ns.DB.talkingHead) ~= "boolean" then ns.DB.talkingHead = false end
    if type(ns.DB.history) ~= "boolean" then ns.DB.history = true end
    ns.DB.minimap, ns.DB.minimapAngle = nil, nil
    if not ns.Confidence.Presets[ns.DB.preset] then ns.DB.preset = "aggressive" end
    if type(ns.DB.context) ~= "boolean" then ns.DB.context = true end
    if type(ns.DB.disabledPacks) ~= "table" then ns.DB.disabledPacks = {} end
    for _, pack in ipairs(ns.RulePacks.Order) do
        local value = ns.DB.disabledPacks[pack]
        if value == 1 or value == 0 then value = ns.Checked(value) end
        if type(value) ~= "boolean" then value = ns.PackData.Optional[pack] == true end
        ns.DB.disabledPacks[pack] = value
    end
    local saved = type(ns.DB.packPresets) == "table" and ns.DB.packPresets or {}
    ns.DB.packPresets = {}
    for _, pack in ipairs(ns.RulePacks.Order) do
        if ns.Confidence.Presets[saved[pack]] then ns.DB.packPresets[pack] = saved[pack] end
    end
    ns.DB.olympusIntegration = true
    ns.Membership.Refresh()
    if not ns.SetExceptions(type(ns.DB.exceptions) == "table" and ns.DB.exceptions or {}) then ns.SetExceptions({}) end
    ns.RulePacks.Initialize()
    ns.DB.schema = 11
    if ns.OlympusMuteSignal then ns.OlympusMuteSignal.Initialize() end
    if ns.Shield then ns.Shield.Initialize() end
    if ns.Notifications then ns.Notifications.Initialize() end
    if ns.Language then ns.Language.Initialize() end
    if ns.Personal then ns.Personal.Initialize() end
    if ns.ChatCapture then ns.ChatCapture.Initialize() end
    ns.Initializing = false
    if ns.Membership.Allowed() then ns.RulePacks.Restore() else ns.PacksSuspended = true end
end

local events = CreateFrame("Frame")
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "LOADING_SCREEN_DISABLED", "QUEST_DETAIL", "QUEST_PROGRESS",
    "QUEST_COMPLETE", "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_LOG_UPDATE",
    "BARBER_SHOP_OPEN", "TALKINGHEAD_REQUESTED", "PLAYER_REGEN_ENABLED", "PLAYER_GUILD_UPDATE", "GUILD_ROSTER_UPDATE"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, loaded)
    if event == "ADDON_LOADED" and loaded == ADDON_NAME then ns.Initialize() end
    if not ns.DB then return end
    ns.Membership.Refresh()
    if ns.InstallAdapters then ns.InstallAdapters() end
    if ns.ChatReports then ns.ChatReports.Install() end
    if ns.BuildOptions then ns.BuildOptions() end
    if ns.BuildMinimap then ns.BuildMinimap() end
    if ns.OlympusIntegration then ns.OlympusIntegration.Refresh() end
    if ns.CheckWelcome then ns.CheckWelcome(event) end
    if ns.QueueScan then
        local reset = event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE"
            or event == "GOSSIP_SHOW" or event == "QUEST_GREETING" or event == "TALKINGHEAD_REQUESTED"
        if reset or event == "BARBER_SHOP_OPEN" then ns.Interaction = ns.Interaction + 1 end
        ns.QueueScan(reset)
    end
end)
