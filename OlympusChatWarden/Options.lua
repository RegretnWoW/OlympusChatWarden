local _, ns = ...
local T = ns.Theme
local category, feedback, controls, packControls, sensitivity, sensitivityText, categoryWindow, integrationText
local labels = {aggressive = "Strict", balanced = "Balanced", strict = "Mild"}
local descriptions = {aggressive = "Stronger actions within the same covered subjects and concepts.",
    balanced = "Mild viewing preferences warn; promotion redacts. Protection packs grade attacks separately.",
    strict = "Warns on strong eligible expressions. Explicit threats hide."}
local function PackHelp(pack)
    return pack == "labels"
        and "Body Type 1/2 replacements are built in. The Barber & body-type wording option controls them and this pack's extra replacement variants. This category controls its other phrases."
        or "Default follows the main action preset. Balanced warns on mild unwanted support or criticism and redacts stronger promotion or attacks. Context handling keeps neutral references visible. Gommage is the separate meme mask option. Off disables this category."
end
local summaries = {}
local workspacePackControls = {}
local categoryLabels = {}
local function PackChoice(pack)
    return ns.DB.disabledPacks[pack] and "off" or ns.DB.packPresets[pack] or "default"
end
local function Sync()
    for key, control in pairs(controls or {}) do control:SetChecked(ns.DB[key]) end
    for key, control in pairs(ns.TextCoverageControls or {}) do control:SetChecked(ns.DB[key]) end
    local positions = {}; for i, pack in ipairs(ns.PackNames) do positions[pack] = i end
    for pack, control in pairs(packControls or {}) do
        local index = positions[pack]
        control:SetShown(index ~= nil); categoryLabels[pack]:SetShown(index ~= nil)
        if index then
            control:ClearAllPoints(); control:SetPoint("TOPLEFT", 382, -141 - (index - 1) * 40)
            categoryLabels[pack]:ClearAllPoints(); categoryLabels[pack]:SetPoint("TOPLEFT", 26, -146 - (index - 1) * 40)
            categoryLabels[pack]:SetText(ns.RulePacks.Title(pack)); control:Refresh()
            T.Tooltip(control,ns.RulePacks.Title(pack),PackHelp(pack))
        end
    end
    for pack, text in pairs(summaries) do
        local choice = PackChoice(pack)
        text:SetShown(not ns.Workspace and positions[pack] ~= nil)
        if positions[pack] then
            text:ClearAllPoints(); text:SetPoint("TOPLEFT", 12, -72 - (positions[pack] - 1) * 18)
            text:SetText(ns.RulePacks.Title(pack) .. ": " .. (labels[choice] or (choice == "off" and "Off" or "Default")))
        end
    end
    for pack,control in pairs(workspacePackControls) do
        control:Refresh();T.Tooltip(control,ns.RulePacks.Title(pack),'Default follows the main sensitivity. Other choices stay fixed; Off disables this category.')
    end
    if sensitivity then
        sensitivity:Refresh()
        sensitivityText:SetText(descriptions[ns.DB.preset] or descriptions.balanced)
    end
    if categoryWindow then categoryWindow.DefaultText:SetText("Default follows the main preset: " .. labels[ns.DB.preset] .. ". Other choices stay fixed.") end
    if integrationText and ns.OlympusIntegration then integrationText:SetText(ns.OlympusIntegration.Status()) end
    if ns.CoverageRecoveryStatus and ns.NameplateRecovery then ns.CoverageRecoveryStatus:SetText(ns.NameplateRecovery.Status()) end
    if ns.CoverageNameStatus and ns.NameDisplays then
        ns.ScanExtraText(); ns.CoverageNameStatus:SetText(ns.NameDisplays.Status())
    end
    if ns.RefreshShieldOptions then ns.RefreshShieldOptions() end
    if ns.RefreshLanguageOptions then ns.RefreshLanguageOptions() end
    if ns.RefreshNotificationsOptions then ns.RefreshNotificationsOptions() end
    if feedback then feedback:SetText(not ns.Membership.Allowed() and ns.Membership.Status() or ns.DB.enabled
        and (ns.Membership.method == "local-guild-name" and "Filter active - local Olympus guild-name check. Official affiliation is not verified."
            or "Filter active - choose where it runs and which categories it uses.")
        or "Filter paused - enable it above to filter new messages.") end
    if ns.Workspace and ns.Workspace.mounted==ns.OptionsPanel then ns.Workspace.LayoutMounted() end
end
ns.SyncOptions = Sync
function ns.OpenTextCoverage()
    if not ns.DB then return end
    ns.BuildOptions()
    Sync()
    if category and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
        if ns.CoverageScroll then ns.CoverageScroll:SetVerticalScroll(140) end
    else ns.Print("Coverage settings unavailable in this client. Use /ocw status.") end
end
function ns.OpenCategories()
    if not ns.DB then return end
    if not categoryWindow then
        categoryWindow = T.Window("OlympusChatWardenCategories", UIParent, 650, 620)
        ns.CategoryWindow = categoryWindow; T.Title(categoryWindow, ns.NAME); T.Crest(categoryWindow)
        local function Text(x, y, width, value)
            local text = categoryWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("TOPLEFT", x, y); text:SetWidth(width); text:SetJustifyH("LEFT"); text:SetText(value or ""); T.Light(text); return text
        end
        T.Gold(Text(78, -32, 550, "Category sensitivity"))
        categoryWindow.DefaultText = T.Muted(Text(20, -70, 610))
        T.Muted(Text(20, -100, 610, "Choose a preset for each category, or Off. Personal phrase rules and exceptions still apply."))
        packControls = {}; ns.CategoryDropdowns = packControls
        local choices = {{"default", "Default (main preset)"}, {"off", "Off"}, {"strict", "Mild"},
            {"balanced", "Balanced"}, {"aggressive", "Strict"}}
        for i, name in ipairs(ns.RulePacks.Order) do
            local pack = name
            local y = -141 - (i - 1) * 40
            categoryLabels[pack] = Text(26, y - 5, 346, ns.RulePacks.Title(pack))
            packControls[pack] = T.Dropdown(categoryWindow, 382, y, 240, choices,
                function() return PackChoice(pack) end,
                function(value) ns.SetPackPreset(pack, value); Sync() end)
            T.Tooltip(packControls[pack], ns.RulePacks.Title(pack),PackHelp(pack))
        end
        T.Muted(Text(20, -550, 610, "Only installed packs appear here. Import optional categories with Rule packs."))
        local manage = CreateFrame("Button", nil, categoryWindow, "UIPanelButtonTemplate")
        manage:SetSize(200, 26); manage:SetPoint("BOTTOMLEFT", 18, 16); manage:SetText("Manage / import packs")
        manage:SetScript("OnClick", function() ns.OpenPacks() end); T.ActionHelp(manage,"Rule packs")
        local close = CreateFrame("Button", nil, categoryWindow, "UIPanelButtonTemplate")
        close:SetSize(120, 26); close:SetPoint("BOTTOMRIGHT", -18, 16); close:SetText("Close")
        close:SetScript("OnClick", function() categoryWindow:Hide() end)
        categoryWindow:HookScript("OnShow", Sync)
    end
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    categoryWindow:SetScale(math.min(1, math.max(0.5, (width - 30) / 650), math.max(0.5, (height - 30) / 620)))
    Sync(); T.ShowWindow(categoryWindow)
end
function ns.BuildOptions()
    if category or not ns.DB or not Settings or not Settings.RegisterCanvasLayoutCategory
        or not Settings.RegisterAddOnCategory then return end
    local panel = CreateFrame("Frame", nil, nil, "BackdropTemplate")
    panel:SetSize(640, 620); T.SkinWindow(panel)
    local function Text(parent, x, y, width, value, font)
        local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
        text:SetPoint("TOPLEFT", x, y); text:SetWidth(width); text:SetJustifyH("LEFT"); text:SetText(value or "")
        T.Light(text); return text
    end
    T.Crest(panel, 16, -8, 56)
    T.Gold(Text(panel, 84, -16, 530, ns.NAME, "GameFontNormalLarge"))
    T.Muted(Text(panel, 84, -44, 530, ns.TAGLINE .. "  |  v" .. ns.VERSION))
    local help = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    help:SetSize(100, 24); help:SetPoint("TOPRIGHT", -18, -16); help:SetText("Help / guide")
    help:SetScript("OnClick", ns.OpenTutorial)
    T.Tooltip(help, "How ChatWarden works", "Reference for filtering, languages, Shield, chat capture, bookmarks and exports.")
    controls = {}
    local function Check(parent, key, label, x, y, width, callback, help)
        local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        check:SetSize(26,26)
        check:SetPoint("TOPLEFT", x, y); check.Text:SetText(label); check.Text:SetFontObject("GameFontHighlightSmall")
        T.Light(check.Text); check.Text:SetWidth(width); check.Text:SetJustifyH("LEFT"); check.Text:SetWordWrap(false)
        check:SetScript("OnClick", callback)
        if help then T.Tooltip(check, label, help) end
        return check
    end
    controls.enabled = Check(panel, "enabled", "Enable Olympus ChatWarden", 14, -82, 500, function(self)
        ns.DB.enabled = ns.Checked(self:GetChecked()); ns.PolicyChanged(); ns.BuildMinimap(); Sync()
    end, "Turn filtering on or off for new messages and supported game text.")
    feedback = T.Muted(Text(panel, 20, -117, 600))
    local mode = T.Panel(panel, 14, -146, 612, 82)
    T.Gold(Text(mode, 12, -10, 340, "Sensitivity", "GameFontNormal"))
    sensitivityText = T.Muted(Text(mode, 12, -30, 335))
    sensitivity = T.Dropdown(mode, 362, -20, 236, {{"strict", labels.strict}, {"balanced", labels.balanced}, {"aggressive", labels.aggressive}},
        function() return ns.DB.preset end, function(value) ns.SetPreset(value); Sync() end)
    T.Tooltip(sensitivity,"Action preset","Packs use the same covered concepts in every preset. Balanced warns on mild qualified expressions, redacts stronger promotion or attacks and hides severe directed abuse. Strict increases actions within that same scope. Uncertain cases stay visible. Older optional policy packs pause until updated; Labels v7 remains compatible.")
    controls.gommage=Check(mode,'gommage','Gommage: cover curated words',12,-66,500,function(self)
        ns.SetGommage(ns.Checked(self:GetChecked()));Sync()
    end,'The deliberately exaggerated meme option. Separate from practical context filtering: it covers your original curated terms even in questions or criticism, in any preset. Exceptions still apply.')
    local coverage = T.Panel(panel, 14, -239, 298, 264)
    T.Gold(Text(coverage, 12, -12, 274, "Where to filter", "GameFontNormal"))
    local scroll = CreateFrame("ScrollFrame", "OlympusChatWardenCoverageScroll", coverage, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -35); scroll:SetPoint("BOTTOMRIGHT", -30, 12)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(254, 720); scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maximum = math.max(0, content:GetHeight() - self:GetHeight())
        local value = math.max(0, math.min(maximum, (self:GetVerticalScroll() or 0) - delta * 28))
        self:SetVerticalScroll(value)
    end)
    ns.CoverageScroll, ns.TextCoverageControls = scroll, {}
    local specs = {{"chat", "Player chat", "Player messages in supported chat windows."},
        {"npc", "NPC chat", "Monster and NPC speech in the chat window."},
        {"dialogue", "Quests and NPC dialogue", "Supported quest descriptions, titles, objectives, greetings and choices."},
        {"vendor", "Vendor item labels", "Matching words in vendor labels. Buying and item links keep their native identities."},
        {"bubbles", "Overhead chat bubbles", "Accessible speech-bubble text above characters."},
        {"talkingHead", "Talking-head captions", "Experimental support for talking-head captions."},
        {"barber", "Barber & body-type wording", "Built-in Body Type 1 to Male and Body Type 2 to Female, including barber labels and tooltips. No pack required. This single switch also controls imported body-label replacements; enabled chat/text coverage still applies."},
        {"playerNames", "Player names (experimental)", "Guild, friends, ignore/Who lists and accessible player nameplate names. Names start off. Native selection targets stay intact."},
        {"npcNames", "NPC names (experimental)", "NPC headings and public nameplate names. Only matching words are covered; the rest of the name stays visible."},
        {"targetNames", "Unit-frame names", "Filters supported unit name labels when Player names or NPC names is enabled. Ctrl + left-click the covered phrase to reveal. Ordinary clicks retain targeting. Protected combat updates wait until combat ends."},
        {"nameplates", "Nameplates (experimental)", "Filters accessible nameplate labels when Player names or NPC names is enabled. Enable nameplates yourself in WoW; ChatWarden keeps native targeting and health bars. Floating-name Ctrl + left-click is experimental and may be unavailable. Read originals in Messages."},
        {"history", "Keep review history", "Keep warnings and redactions in the session inbox. Hidden originals always enter review."},
        {"olympusMuteSignal", "OlympusMute signal tooltips", "On by default. Adds a tooltip note when compatible OlympusMute sharing was seen from that player. It may miss ordinary addon use. Turning this off hides the note and stops new observations, but keeps saved history."},
        {"tooltips", "Tooltips", "Filters accessible native tooltip text. Hold Ctrl to reveal tooltip wording; release it to re-cover. Item and spell actions keep their native identities."},
        {"languageEnabled", "Language filtering", "Off by default. Confidence always runs with a fixed four-letter minimum. Low defaults to Redact; High defaults to Hide. Mostly non-preferred text also uses High, even when the exact language is uncertain. Filter player names too starts off. One language list and incoming chat switches control coverage. Word rules and Shield remain independent."}}
    for i, spec in ipairs(specs) do
        local key = spec[1]
        controls[key] = Check(content, key, spec[2], 0, -(i - 1) * 28, 220, function(self)
            if not ns.Membership.Allowed() then Sync(); return end
            ns.DB[key] = ns.Checked(self:GetChecked());
            if key == "olympusMuteSignal" then ns.OlympusMuteSignal.SettingsChanged() end
            ns.PolicyChanged(); Sync()
        end, spec[3])
        if key == "vendor" or key == "playerNames" or key == "npcNames" or key == "nameplates" or key == "targetNames" then
            ns.TextCoverageControls[key] = controls[key]
        end
    end
    local languageSettings=CreateFrame('Button',nil,content,'UIPanelButtonTemplate')
    languageSettings:SetSize(230,24);languageSettings:SetPoint('TOPLEFT',6,-423);languageSettings:SetText('Language settings')
    languageSettings:SetScript('OnClick',ns.OpenLanguageOptions);T.Tooltip(languageSettings,'Language settings','One master switch, Low and High actions, optional name filtering, incoming chat switches and the languages you read. Confidence always runs with a fixed four-letter minimum.')
    ns.CoverageNameStatus = T.Muted(Text(content, 6, -460, 236))
    ns.CoverageRecoveryStatus = T.Muted(Text(content, 6, -530, 236))
    local coverageHelp=T.Muted(Text(content, 6, -598, 236, "Player/NPC names start off. Ctrl + left-click reveals supported labels; floating-name clicks are experimental. Enable nameplates in WoW yourself. Originals are in Messages."))
    local packs = T.Panel(panel, 324, -239, 302, 264)
    T.Gold(Text(packs, 12, -12, 278, "Rule packs & sensitivity", "GameFontNormal"))
    local configure = CreateFrame("Button", nil, packs, "UIPanelButtonTemplate")
    configure:SetSize(132, 26); configure:SetPoint("TOPLEFT", 12, -34); configure:SetText("Sensitivity")
    configure:SetScript("OnClick", ns.OpenCategories); T.ActionHelp(configure,"Sensitivity")
    local manage = CreateFrame("Button", nil, packs, "UIPanelButtonTemplate")
    manage:SetSize(132, 26); manage:SetPoint("TOPLEFT", 154, -34); manage:SetText("Rule packs")
    manage:SetScript("OnClick", function() ns.OpenPacks() end); T.ActionHelp(manage,"Rule packs")
    for i, name in ipairs(ns.RulePacks.Order) do
        local pack = name
        summaries[pack] = Text(packs, 12, -72 - (i - 1) * 16, 278)
    end
    local packHelp=T.Muted(Text(packs, 12, -245, 275, "Two stock packs. Import other categories."))
    if ns.Workspace then
        local W,V=ns.Workspace,ns.Art
        configure:Hide();manage:Hide();languageSettings:Hide();help:Hide()
        local packScroll=CreateFrame('ScrollFrame',nil,packs)
        packScroll:SetPoint('TOPLEFT',14,-42);packScroll:SetPoint('BOTTOMRIGHT',-34,82)
        local packContent=CreateFrame('Frame',nil,packScroll);packContent:SetSize(470,440);packScroll:SetScrollChild(packContent);V.SkinScroll(packScroll)
        local names={};local choices={{'default','Default (main preset)'},{'off','Off'},{'strict','Mild'},{'balanced','Balanced'},{'aggressive','Strict'}}
        for _,packName in ipairs(ns.RulePacks.Order) do
            local pack=packName
            names[pack]=Text(packContent,0,0,238,ns.RulePacks.Title(pack))
            workspacePackControls[pack]=T.Dropdown(packContent,254,0,214,choices,function() return PackChoice(pack) end,function(v) ns.SetPackPreset(pack,v);Sync() end)
            T.Tooltip(workspacePackControls[pack],ns.RulePacks.Title(pack),'Default follows the main sensitivity. Other choices stay fixed; Off disables this category.')
        end
        ns.WorkspacePackDropdowns=workspacePackControls
        function panel:ChatWardenLayout(w,h)
            local half=(w-52)/2
            W.Place(controls.enabled,18,-18,w-70);W.Place(feedback,22,-54,w-44)
            W.Place(mode,18,-83,w-36,112);W.Place(sensitivityText,14,-36,w-362,26)
            W.Place(sensitivity,w-336,-34,282,34)
            W.Place(coverage,18,-199,half,h-217);W.Place(packs,34+half,-199,half,h-217)
            content:SetWidth(half-46)
            for _,c in pairs(controls) do if c~=controls.enabled then c.Text:SetWidth(half-84) end end
            W.Place(ns.CoverageNameStatus,6,-468,half-58,64)
            W.Place(ns.CoverageRecoveryStatus,6,-536,half-58,64)
            W.Place(coverageHelp,6,-604,half-58,80);content:SetHeight(700)
            packContent:SetWidth(half-48)
            for _,text in pairs(summaries) do text:Hide() end
            local positions={};for i,pack in ipairs(ns.PackNames) do positions[pack]=i end
            for pack,d in pairs(workspacePackControls) do
                local i=positions[pack];d:SetShown(i~=nil);names[pack]:SetShown(i~=nil)
                if i then
                    names[pack]:SetText(ns.RulePacks.Title(pack))
                    W.Place(names[pack],0,-10-(i-1)*44,half-294)
                    W.Place(d,half-282,-(i-1)*44,230,32)
                end
            end
            packContent:SetHeight(math.max(1,#ns.PackNames*44))
            W.Place(packHelp,14,-(h-281),half-28,48)
            packHelp:SetText('Default follows the main preset. Optional categories are signed imports.')
        end
    end
    if not ns.Workspace then
    local notifications=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate')
    notifications:SetSize(286,24);notifications:SetPoint('TOPLEFT',20,-512);notifications:SetText('Notifications')
    notifications:SetScript('OnClick',ns.OpenNotificationOptions)
    T.Tooltip(notifications,'Notifications','Choose unread badges, chat notices and which categories notify you. Repeated messages, rapid chat and ads start quiet.')
    T.Muted(Text(panel,326,-517,290,'Choose which hidden messages notify you.'))
    integrationText = T.Muted(Text(panel, 20, -542, 600))
    for i, spec in ipairs({{"Preview test", ns.MakeDemo}, {"Review messages", ns.OpenReview},
        {"My rules", ns.OpenRules}, {"My reports", ns.OpenReports}}) do
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(140, 26); button:SetPoint("TOPLEFT", 20 + (i - 1) * 151, -562)
        button:SetText(spec[1]); button:SetScript("OnClick", spec[2]); T.ActionHelp(button,spec[1])
    end
    end
    panel:SetScript("OnShow", Sync)
    T.BindSettings(panel)
    ns.OptionsPanel = panel
    category = Settings.RegisterCanvasLayoutCategory(ns.Workspace and ns.Workspace.SettingsCanvas(panel,'general') or panel, ns.NAME); Settings.RegisterAddOnCategory(category); ns.BuildShieldOptions(category); ns.BuildLanguageOptions(category); ns.BuildNotificationsOptions(category); ns.BuildSpellingOptions(category); ns.BuildChronicleOptions(category); Sync()
end

SLASH_OLYMPUSCHATWARDEN1 = "/chatwarden"
SLASH_OLYMPUSCHATWARDEN2 = "/ocw"
SlashCmdList.OLYMPUSCHATWARDEN = function(message)
    if not ns.DB then return end
    local command, argument = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = (command or ""):lower()
    if command=='chronicle' then ns.Chronicle.Slash(argument)
    elseif command=='intel' then ns.Chronicle.IntelSlash(argument)
    elseif command=='test' then ns.PhraseTester.Run(argument)
    elseif command == "shieldoptions" then ns.OpenShieldOptions()
    elseif command == "inbox" or command == "review" then ns.OpenReview()
    elseif command == "shield" then ns.OpenShield()
    elseif command == "help" or command == "tutorial" then ns.OpenTutorial()
    elseif command == "languages" then ns.OpenLanguageOptions()
    elseif command == "spelling" then ns.OpenSpellingOptions()
    elseif command == "updates" then ns.OpenUpdates()
    elseif command == "welcome" then ns.OpenWelcome()
    elseif command == "personal" or command == "reports" then ns.OpenPersonal("reports")
    elseif command == "rules" then ns.OpenPersonal("rules")
    elseif command == "feedback" then ns.OpenReportLink()
    elseif command == "export" then ns.OpenReportExport(argument == "misses" and "misses" or nil)
    elseif command == "capture" then ns.OpenCapture()
    elseif command == "report" then ns.OpenReport(nil, "Missed match")
    elseif command == "history" then
        if argument == "on" or argument == "off" then
            ns.DB.history = argument == "on"
            ns.Print("Optional warning/redaction history " .. argument .. ". High-confidence items always go to review. Existing entries remain until clear/reload.")
        else ns.Print("History is " .. (ns.DB.history and "on" or "off") .. ": " .. #ns.Review.entries .. " session entries. Use /ocw history on|off.") end
    elseif command == "minimap" then
        ns.Print("Use the Olympus minimap icon and ChatWarden tab. /ocw opens setup directly.")
    elseif command == "on" or command == "off" then
        ns.DB.enabled = command == "on"
        ns.PolicyChanged(); Sync()
        if ns.RefreshBubbles then ns.RefreshBubbles() end
        ns.Print(ns.DB.enabled and (ns.Membership.Allowed() and "Enabled for new chat and supported UI text." or ns.Membership.Status())
            or "Disabled. Existing chat redactions remain clickable; new messages are untouched.")
    elseif command == "bubbles" then
        if argument == "on" or argument == "off" then
            ns.DB.bubbles = argument == "on"; ns.PolicyChanged(); Sync()
        end
        ns.Print(ns.BubbleStatus())
    elseif command == "preset" then
        local ok, err = ns.SetPreset(argument:lower()=='strict' and 'aggressive' or argument:lower())
        if ok then Sync(); ns.Status() else ns.Print(err) end
    elseif command == 'gommage' then
        if argument=='on' or argument=='off' then ns.SetGommage(argument=='on');Sync() end
        ns.Print('Gommage '..(ns.DB.gommage and 'on' or 'off')..'. Use /ocw gommage on|off. The action preset is unchanged.')
    elseif command == "logic" then
        ns.Print("Context handling is always active. Choose Mild, Balanced or Strict to change filtering strength.")
    elseif command == "pack" then
        local pack, setting = argument:lower():match("^(%S+)%s+(%S+)$")
        local known = false
        for _, name in ipairs(ns.PackNames) do if name == pack then known = true end end
        if known and (setting == "on" or setting == "off") then
            ns.DB.disabledPacks[pack] = setting == "off"; ns.PolicyChanged()
            ns.Print(pack .. " pack " .. setting)
            Sync()
        elseif known and setting then
            local ok, err = ns.SetPackPreset(pack, setting); Sync(); ns.Print(ok and (pack .. " sensitivity: " .. setting) or err)
        else
            for _, name in ipairs(ns.PackNames) do ns.Print(name .. ": " .. (ns.DB.disabledPacks[name] and "off" or "on")) end
            ns.Print("Use /ocw pack NAME default|off|mild|balanced|broad, or /ocw categories. Gommage is a separate toggle.")
        end
    elseif command == "allow" or command == "unallow" then
        local rules = {}
        for _, phrase in ipairs(ns.DB.exceptions) do
            if command ~= "unallow" or phrase ~= argument:lower() then rules[#rules + 1] = phrase end
        end
        if command == "allow" then rules[#rules + 1] = argument end
        local ok, err = ns.SetExceptions(rules)
        ns.Print(ok and ("Saved " .. #ns.DB.exceptions .. " exceptions. Exceptions suppress nearby matches in the same bounded sentence window.") or err)
    elseif command == "exceptions" then
        ns.Print(#ns.DB.exceptions == 0 and "No exceptions." or table.concat(ns.DB.exceptions, ", "))
    elseif command == "stock" or command == "add" or command == "remove" then
        ns.Print("Open /ocw rules to add or edit personal phrase rules. Use pack switches and allow/unallow exceptions to adjust built-in categories.")
    elseif command == "categories" then ns.OpenCategories()
    elseif command == "packs" then ns.OpenPacks(argument == "import" and "import" or "installed")
    elseif command == "names" or command == "text" then ns.OpenTextCoverage()
    elseif command == "status" then ns.Status()
    elseif command == "preview" or command == "test" then ns.MakeDemo()
    elseif command == "rescan" then ns.QueueScan(true); ns.RefreshBubbles()
    elseif command == "options" or command == "" then
        if category and Settings.OpenToCategory then Settings.OpenToCategory(category:GetID())
        else ns.Print("Options panel unavailable; use /ocw inbox, pack, allow, on, off, test, or status.") end
    else ns.Print("Commands: test PHRASE | options | inbox | shield | shieldoptions | reports | report | feedback | export [misses] | rules | preview | on/off | status | rescan | preset mild/balanced/strict | gommage on/off | pack NAME on/off | allow/unallow PHRASE | exceptions | history on/off | bubbles on/off") end
end
