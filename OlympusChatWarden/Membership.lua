-- Olympus 1.2.4's own profile is authoritative and requires the player's consent.
-- Older Olympus versions retain the clearly labelled local guild-name gate.
local _, ns = ...
local M = {allowed = false, method = "pending", reason = "Waiting for current-character guild information."}
ns.Membership = M
function M.Allowed() return M.allowed == true end
function M.LocalHistoryAllowed()
    -- Recording consent belongs to Warden, independent of optional Olympus UI
    -- readiness. This does not grant access to any Olympus profile or API.
    local root=ns.DB and ns.DB.chronicle
    local connection=ns.OlympusConnection
    if not M.Allowed() and connection and (connection.state=='connected' or connection.state=='not-member') then return false end
    return M.Allowed() or type(root)=='table' and root.enabled==true and root.consentVersion==5
end
function M.Status() return M.reason end
local guardsInstalled, panels = false, {}
-- Guard public feature entry points after every module has loaded. Initialization
-- may normalize saved data, but nonmembers cannot record, export or change it.
function M.InstallAccessGuards()
    if guardsInstalled then return end
    guardsInstalled = true
    local function Guard(owner, key, announce)
        local original = owner and owner[key]
        if type(original) ~= 'function' then return end
        owner[key] = function(...)
            if not M.Allowed() and not ns.Initializing then
                -- Local privacy controls remain reachable after membership or consent is lost.
                if owner==SlashCmdList and key=='OLYMPUSCHATWARDEN' then
                    local message=(...)
                    if type(message)=='string' then
                        local command=message:lower():gsub('^%s+',''):gsub('%s+$',''):gsub('%s+',' ')
                        if command=='chronicle off' or command=='chronicle clear' or command=='chronicle clear confirm'
                            or command=='chronicle status' then return original(message) end
                        if ns.WardenSimLab and (command=='hephaestus' or command=='simlab') then return original(message) end
                    end
                end
                if announce then ns.Print(M.Status()) end
                return nil, M.Status()
            end
            return original(...)
        end
    end
    local open = {}
    for key, value in pairs(ns) do
        if type(key)=='string' and type(value)=='function' and key:match('^Open') then open[#open+1]=key end
    end
    for _, key in ipairs(open) do Guard(ns,key,true) end
    for _, key in ipairs({'MakeDemo','SetPreset','SetPackPreset','SetExceptions','SetRules','SetLauncher',
        'OnLink','CheckWelcome','SetReviewTab','RefreshReview','RefreshCapture','RefreshPersonal','RefreshReportExport','SyncPacks'}) do Guard(ns,key) end
    local actions = {
        ChatCapture={'SetOption','Record','Bookmark','UpdateBookmark','RemoveBookmark','RemoveRecords','Clear'},
        ChatReports={'Capture','RecordOutcome','OnClick','BuildMenu','OnEvent','Open'}, Notifications={'Set'},
        PlayerMenus={'Add'}, Personal={'SaveRule','ChangeRule','SaveReport','RemoveReport'},
        Spam={'Set','Observe'}, Shield={'Add','Remove','Allow','Unallow','SetProfile','SetTuning','SetOption','Alert','Prune'},
        Spelling={'SetEnabled','SetOption','AddWord','RemoveWord','Ignore','Correct','OpenSuggestions'}, TypoFilter={'Set','SetMode'},
        Mentions={'Set','SetChannel','Save','Change'},
        Wanted={'Set'},
        Workspace={'Open','Copy','RuleEditor','ExceptionEditor','ShieldEditor','PackSensitivity','CaptureSettings','MentionSettings','WantedSettings','WatchPhrases','BookmarkEditor','SettingsSub'},
        RulePacks={'BeginImport','Commit','Remove','Export','Restore'}, PackUpdates={'Check'},
        Export={'Batch','Build','TextPreview'}, Reports={'Export'}, Review={'Add'}, Language={'Set','Allow'}, LanguageDisplay={'Toggle'},
    }
    for name, keys in pairs(actions) do for _, key in ipairs(keys) do Guard(ns[name],key) end end
    Guard(ns.Theme,'ShowWindow',true)
    Guard(SlashCmdList,'OLYMPUSCHATWARDEN',true)
end
function M.RegisterSettings(panel)
    panels[panel] = true
    panel:HookScript('OnShow',function() M.UpdateSettingsLocks() end)
    M.UpdateSettingsLocks()
end
function M.UpdateSettingsLocks()
    for panel in pairs(panels) do
        local lock = panel.ChatWardenGuildLock
        if not lock then
            lock = CreateFrame('Frame',nil,panel)
            lock:SetAllPoints(panel);lock:SetFrameLevel(panel:GetFrameLevel()+100)
            lock:EnableMouse(true);lock:EnableMouseWheel(true)
            local background=lock:CreateTexture(nil,'BACKGROUND');background:SetAllPoints(lock)
            background:SetColorTexture(0.04,0.04,0.04,1)
            local text=lock:CreateFontString(nil,'OVERLAY','GameFontHighlight')
            text:SetPoint('TOPLEFT',22,-24);text:SetPoint('TOPRIGHT',-22,-24)
            text:SetJustifyH('LEFT');text:SetWordWrap(true);lock.text=text
            panel.ChatWardenGuildLock=lock
        end
        lock.text:SetText('Olympus ChatWarden is unavailable.\n\n'..M.Status()..'\n\nAll features are disabled until this character qualifies. Saved data is kept.')
        lock:SetShown(not M.Allowed())
    end
end
local function LocalGuild()
    if type(IsInGuild) == "function" then
        local ok, member = pcall(IsInGuild)
        if not ok or not ns.Readable(member) then return false, "Guild check unavailable; ChatWarden is disabled." end
        if not ns.Checked(member) then return false, "Join a guild with Olympus as a separate word in its name; ChatWarden is disabled." end
    end
    local ok, guild = pcall(function()
        if type(GetGuildInfo) == "function" then return GetGuildInfo("player") end
    end)
    if not ok or not ns.CanRead(guild) or guild == "" then
        return false, "Waiting for current-character guild information; ChatWarden is disabled."
    end
    if #guild > 128 or guild:find('[%z\1-\31\127|]') then
        return false, "Guild check unavailable; ChatWarden is disabled."
    end
    if guild:lower():find('%f[%w]olympus%f[%W]') then
        return true, "Local Olympus guild-name check passed. Official affiliation is not verified."
    end
    return false, "Guild name must contain Olympus as a separate word; ChatWarden is disabled."
end
function M.Refresh()
    local allowed, reason, method
    local connection=ns.OlympusConnection
    if connection then connection.Refresh() end
    local bridge = OlympusBridge
    if connection and connection.modern then
        method='olympus-api'
        local profile=connection.Profile()
        allowed=connection.state=='connected' and profile~=nil and profile.member==true
        reason=connection.Reason()
    elseif ns.Readable(bridge) and type(bridge) == "table" and ns.Readable(bridge.IsMember) and type(bridge.IsMember) == "function" then
        method = "olympus"
        local ok, member = pcall(bridge.IsMember)
        allowed = ok and ns.Readable(member) and member == true
        reason = allowed and "Olympus membership verified."
            or not ok and "Olympus membership check failed; ChatWarden is disabled."
            or "Olympus has not verified this character as a member; ChatWarden is disabled."
    else
        method = "local-guild-name"
        allowed, reason = LocalGuild()
    end
    local changed = M.allowed ~= allowed or M.reason ~= reason or M.method ~= method
    M.allowed, M.reason, M.method = allowed, reason, method
    if changed and ns.DB and not ns.Initializing then
        if ns.Modules then ns.Modules.Reconcile() end
        if not allowed then
            ns.PacksSuspended = true
            if ns.RulePacks and ns.RulePacks.Suspend then ns.RulePacks.Suspend() end
            if ns.Theme and ns.Theme.HideAll then ns.Theme.HideAll() end
        elseif ns.PacksSuspended and (not ns.Modules or ns.Modules.Enabled('chat')) then
            ns.PacksSuspended = nil
            if ns.RulePacks and ns.RulePacks.Restore then ns.RulePacks.Restore() end
        end
        ns.PolicyChanged()
        M.UpdateSettingsLocks()
        if ns.SyncOptions then ns.SyncOptions() end
    end
    return allowed
end
