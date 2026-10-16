-- Release notes for installed updates; no network request or version polling.
local _,ns=...
local T=ns.Theme
local window,queued,loginReady
local release=ns.VERSION
ns.InstalledUpdate={version=release,cards={
    {'ChatWarden inside Olympus','Use the compact panel for quick controls and recent activity. Right-click its tab to open the full UI.','overview'},
    {'Olympus membership and profile','Olympus 1.2.4 confirms membership after /oly privacy approval. Guild rank and connection status appear in the full UI.','olympus'},
    {'Mentions is now Alerts','Personal mentions and Wanted encounters share one page, with separate views, settings and unread counts.','mentions'},
    {'Wanted encounter alerts','Listed enemy targets and mouseovers can create alerts. Choose optional sound, popups and a per-player cooldown.','reports'},
    {'Quiet Wanted icons in chat','Full listed names get an icon with bounty details on hover. Chat icons never trigger Wanted alerts.','reports'},
    {'Activity and update history','Click recent entries to mark them read. Zeus matches the trim, and Previous/Next opens older update notes.','updates'},
}}
-- Keep published notes here when adding a new release. Older cards retain the
-- wording shipped in those versions; browsing them does not change settings.
ns.UpdateHistory={ns.InstalledUpdate,
    {version='1.0.1',subtitle='Archived release notes',cards={
        {'Smarter filtering','Better context handling means fewer false matches in questions, criticism and ordinary discussion.','messages'},
        {'First-name Mentions','Your first name or full name can trigger Mentions. No @ needed, and Capture can stay off.','mentions'},
        {'Clearer pack names','Optional packs have clearer names. Import updated packs separately to see the new names.','packs'},
        {'WoW-friendly spelling','More game terms and Olympus names are recognized. Ambiguous corrections stay suggestions.','settings'},
        {'Your settings stay yours','Existing choices and saved activity are kept. The launch tour now has its own tab.','reports'},
    }},
    {version='1.0.0',subtitle='Archived release notes',cards={
        {'Incoming spelling and evasion matching','On by default in Balanced matching mode. Close misspellings can match enabled rules and use their normal actions, including Hide. Originals stay intact.','settings'},
        {'Compare the results','Settings > Spelling has Aggressive incoming typo filtering. Turn it off to compare normal matching. Your own messages and name labels are excluded.','settings'},
        {'Reports and sharing in one window','Read reports and Share preview now share one window. Choose entries and privacy before copying. Language-only notifications start off.','reports'},
        {'Spelling assistance','Optional English spelling highlights, right-click suggestions and automatic correction. Enable the options you want in Settings > Spelling.','settings'},
        {'Windows and settings','Keep Review, Rules, Reports and help open together. Window layers move together. The Language guide button now fits inside Settings.','overview'},
    }},
}
local function Label(parent,text,x,y,width,font)
    local label=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall')
    label:SetPoint('TOPLEFT',x,y);label:SetWidth(width);label:SetJustifyH('LEFT');label:SetWordWrap(true);label:SetText(text)
    return label
end
local function Button(text,x,width,fn)
    local button=CreateFrame('Button',nil,window,'UIPanelButtonTemplate')
    button:SetPoint('TOPLEFT',x,-622);button:SetSize(width,26);button:SetText(text);button:SetScript('OnClick',fn)
    T.ActionHelp(button,text);return button
end
function ns.OpenUpdates()
    if not ns.DB then return end
    if InCombatLockdown and InCombatLockdown() then ns.Print('Open update notes after combat with /ocw updates.');return end
    if not window then
        window=T.Window('OlympusChatWardenUpdates',UIParent,680,716);ns.UpdateWindow=window
        T.Title(window,ns.NAME);T.Crest(window)
        T.Gold(Label(window,"What's new",78,-30,570,'GameFontNormalLarge'))
        T.Muted(Label(window,'Update '..release..'  |  Your existing settings and saved data are kept.',78,-52,570))
        local cards=ns.InstalledUpdate.cards
        for i,card in ipairs(cards) do
            local panel=T.Panel(window,18,-84-(i-1)*78,644,70,true)
            T.Heading(T.Body(Label(panel,card[1],14,-10,616,'GameFontNormal')))
            T.Ink(T.Body(Label(panel,card[2],14,-30,616)))
        end
        local show=CreateFrame('CheckButton',nil,window,'UICheckButtonTemplate');show:SetPoint('TOPLEFT',14,-568);show:SetSize(26,26)
        Label(show,'Show this screen after future updates',30,-6,580)
        show:SetScript('OnClick',function(self) ns.DB.showUpdates=ns.Checked(self:GetChecked()) end)
        T.Tooltip(show,'Update notes','Show notes once after an installed release changes. Reopen them anytime with /ocw updates. No online update check is performed.')
        window.ShowUpdates=show
        Button('Get packs link',18,195,function() ns.OpenPacks('download') end)
        Button('Rule packs',225,195,function() ns.OpenPacks('installed') end)
        Button('Close',542,120,function() window:Hide() end)
        T.Muted(Label(window,'Reopen these notes with /ocw updates or Updates in the sidebar.',20,-684,640))
    end
    window.ShowUpdates:SetChecked(ns.DB.showUpdates~=false)
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    window:SetScale(math.min(1,(w-30)/680,(h-30)/716))
    T.ShowWindow(window)
    if window:IsShown() then ns.DB.updateSeen=release end
end
function ns.CheckUpdateScreen(event)
    if event=='PLAYER_LOGIN' then loginReady=true end
    if not loginReady and IsLoggedIn then loginReady=IsLoggedIn()==true end
    if loginReady and ns.DB and ns.Active() and ns.DB.welcomeSeen~=1 then
        ns.DB.updateSeen=release;return -- the introduction covers this release for new users
    end
    if queued or not loginReady or not ns.DB or not ns.Active() or ns.DB.welcomeSeen~=1
        or ns.DB.showUpdates==false or ns.DB.updateSeen==release or not UIParent:IsVisible()
        or InCombatLockdown and InCombatLockdown() then return end
    queued=true
    local function Show()
        queued=false
        if ns.DB and ns.Active() and ns.DB.welcomeSeen==1 and ns.DB.showUpdates~=false
            and ns.DB.updateSeen~=release and UIParent:IsVisible()
            and not (InCombatLockdown and InCombatLockdown()) then ns.OpenUpdates() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0,Show)
    else
        local frame=CreateFrame('Frame');frame:SetScript('OnUpdate',function(self) self:SetScript('OnUpdate',nil);Show() end)
    end
end
