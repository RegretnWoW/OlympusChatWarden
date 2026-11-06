-- Olympus 1.2.4's own profile is authoritative and requires the player's consent.
-- Guild-name hints never establish verified membership.
local _, ns = ...
local M = {allowed = false, method = "pending", reason = "Waiting for current-character guild information."}
ns.Membership = M
function M.Allowed() return M.allowed == true end
-- Network eligibility is independent of the application gate. This grants no
-- UI access, enrollment, signing authority or permission to publish.
function M.AetherAllowed() return ns.DB~=nil end
function M.RecordingAllowed() return ns.Permissions.HistoryConsent() end
function M.BackgroundAllowed(module) return ns.Permissions.Background(module) end
function M.LocalHistoryAllowed()
    -- Recording consent belongs to Warden, independent of optional Olympus UI
    -- readiness. This does not grant access to any Olympus profile or API.
    return M.Allowed() or M.RecordingAllowed()
end
function M.Status() return M.reason end
local guardsInstalled, panels = false, {}
-- Guard public feature entry points after every module has loaded. Initialization
-- may normalize data; passive collectors retain their existing opt-in gates.
function M.InstallAccessGuards()
    if guardsInstalled then return end
    guardsInstalled = true
    local function Guard(owner, key, announce, passive)
        local original = owner and owner[key]
        if type(original) ~= 'function' then return end
        owner[key] = function(...)
            if not M.Allowed() and not ns.Initializing then
                if passive and M.BackgroundAllowed(passive) then return original(...) end
                -- Local privacy controls remain reachable after membership or consent is lost.
                if owner==SlashCmdList and key=='OLYMPUSCHATWARDEN' then
                    local message=(...)
                    if type(message)=='string' then
                        local command=message:lower():gsub('^%s+',''):gsub('%s+$',''):gsub('%s+',' ')
                        if command=='privacy stop' then return ns.Privacy.Stop() end
                        if command=='privacy withdraw' then return ns.Privacy.Withdraw() end
                        if command=='privacy' or command=='recording privacy' then return ns.UI2.ShowPrivacy() end
                        if (command=='diagnostics' or command=='aether diagnostics') and ns.AetherLive and ns.AetherLive.CopyDiagnostics then return ns.AetherLive.CopyDiagnostics() end
                        if command=='chronicle off' then return ns.Privacy.Stop() end
                        if command=='chronicle clear' or command=='chronicle clear confirm' then return ns.UI2.ShowPrivacy() end
                        -- Private testing commands never bypass the public verification lock.
                    end
                end
                if announce and ns.UI2 then ns.UI2.ShowVerification() end
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
    local passive={ChatCapture={Record='chat'},ChatReports={Capture='chat',RecordOutcome='chat',OnEvent='chat'},
        Spam={Observe='chat'},Shield={Alert='shield',Prune='shield'},Review={Add='chat'}}
    for name, keys in pairs(actions) do for _, key in ipairs(keys) do Guard(ns[name],key,false,passive[name] and passive[name][key]) end end
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
        lock.text:SetText('Fireside — Verification Required\n\n'..M.Status()..'\n\nPreviously authorized background recording and Aether participation can continue independently. Use /warden privacy to stop recording or withdraw participation.')
        lock:SetShown(not M.Allowed())
    end
end
local function LocalGuild()
    if type(IsInGuild) == "function" then
        local ok, member = pcall(IsInGuild)
        if not ok or not ns.Readable(member) then return false, "Guild check unavailable; ChatWarden is disabled." end
        if not ns.Checked(member) then return false, "Join a guild with Olympus as a separate word in its name; ChatWarden is disabled.", true end
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
    return false, "Guild name must contain Olympus as a separate word; ChatWarden is disabled.", true
end
function M.Refresh()
    local allowed, reason, method, denied
    local connection=ns.OlympusConnection
    if connection then connection.Refresh() end
    local bridge = OlympusBridge
    if ns.ClientCompat and ns.ClientCompat.IsRetailTest() then
        -- Local test access only: leave identity, consent, membership claims,
        -- signing and every Aether transport check to their existing owners.
        allowed=true;denied=false;method='retail-local-test'
        reason='Retail test access. Olympus affiliation is not verified.'
    elseif connection and connection.modern then
        method='olympus-api'
        local profile=connection.Profile()
        allowed=connection.state=='connected' and profile~=nil and profile.member==true
        reason=connection.Reason()
        denied=connection.state=='not-member'
    elseif ns.Readable(bridge) and type(bridge) == "table" and ns.Readable(bridge.IsMember) and type(bridge.IsMember) == "function" then
        method = "olympus"
        local ok, member = pcall(bridge.IsMember)
        allowed = ok and ns.Readable(member) and member == true
        denied = ok and ns.Readable(member) and member == false
        reason = allowed and "Olympus membership verified."
            or not ok and "Olympus membership check failed; the Fireside interface is locked."
            or "Olympus has not verified this character as a member; the Fireside interface is locked."
    else
        method = "local-guild-name"
        local candidate;candidate, reason = LocalGuild()
        allowed=false;denied=false
        reason=candidate and 'Olympus guild-name hint found. Membership verification is unavailable.' or 'Olympus membership verification is pending or unavailable.'
    end
    denied=denied==true
    local changed = M.allowed ~= allowed or M.reason ~= reason or M.method ~= method or M.denied~=denied
    M.allowed, M.reason, M.method, M.denied = allowed, reason, method, denied
    if changed and ns.DB and not ns.Initializing then
        local wasOpen=ns.UI2 and ns.UI2.window and ns.UI2.window:IsShown()
        if not allowed and ns.Theme and ns.Theme.HideAll then ns.Theme.HideAll() end
        if ns.Modules then ns.Modules.Reconcile() end
        if ns.PacksSuspended and (not ns.Modules or ns.Modules.Enabled('chat')) and M.BackgroundAllowed('chat') then
            ns.PacksSuspended = nil
            if ns.RulePacks and ns.RulePacks.Restore then ns.RulePacks.Restore() end
        end
        ns.PolicyChanged()
        M.UpdateSettingsLocks()
        if ns.SyncOptions then ns.SyncOptions() end
        if ns.UI2 and ns.UI2.VerificationChanged then
            if wasOpen and not allowed then ns.UI2.ShowVerification() else ns.UI2.VerificationChanged() end
        end
    end
    return allowed
end
