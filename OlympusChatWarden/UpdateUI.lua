-- Release notes for installed updates; no network request or version polling.
local _,ns=...
local T=ns.Theme
local window,queued,loginReady
local release=ns.VERSION
local function Label(parent,text,x,y,width,font)
    local label=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall')
    label:SetPoint('TOPLEFT',x,y);label:SetWidth(width);label:SetJustifyH('LEFT');label:SetWordWrap(true);label:SetText(text)
    return label
end
local function Button(text,x,width,fn)
    local button=CreateFrame('Button',nil,window,'UIPanelButtonTemplate')
    button:SetPoint('TOPLEFT',x,-572);button:SetSize(width,26);button:SetText(text);button:SetScript('OnClick',fn)
    T.ActionHelp(button,text);return button
end
function ns.OpenUpdates()
    if not ns.DB then return end
    if InCombatLockdown and InCombatLockdown() then ns.Print('Open update notes after combat with /ocw updates.');return end
    if not window then
        window=T.Window('OlympusChatWardenUpdates',UIParent,680,632);ns.UpdateWindow=window
        T.Title(window,ns.NAME);T.Crest(window)
        T.Gold(Label(window,"What's new",78,-30,570,'GameFontNormalLarge'))
        T.Muted(Label(window,'Update '..release..'  |  Your existing settings and saved data are kept.',78,-52,570))
        local cards={
            {'Incoming spelling and evasion matching','On by default in Balanced matching mode. Close misspellings can match enabled rules and use their normal actions, including Hide. Originals stay intact.'},
            {'Compare the results','Settings > Spelling has Aggressive incoming typo filtering. Turn it off to compare normal matching. Your own messages and name labels are excluded.'},
            {'Reports and sharing in one window','Read reports and Share preview now share one window. Choose entries and privacy before copying. Language-only notifications start off.'},
            {'Spelling assistance','Optional English spelling highlights, right-click suggestions and automatic correction. Enable the options you want in Settings > Spelling.'},
            {'Windows and settings','Keep Review, Rules, Reports and help open together. Window layers move together. The Language guide button now fits inside Settings.'},
        }
        for i,card in ipairs(cards) do
            local panel=T.Panel(window,18,-84-(i-1)*84,644,76,true)
            T.Heading(T.Body(Label(panel,card[1],14,-10,616,'GameFontNormal')))
            T.Ink(T.Body(Label(panel,card[2],14,-30,616)))
        end
        local show=CreateFrame('CheckButton',nil,window,'UICheckButtonTemplate');show:SetPoint('TOPLEFT',14,-514);show:SetSize(26,26)
        Label(show,'Show this screen after future updates',30,-6,580)
        show:SetScript('OnClick',function(self) ns.DB.showUpdates=ns.Checked(self:GetChecked()) end)
        T.Tooltip(show,'Update notes','Show notes once after an installed release changes. Reopen them anytime with /ocw updates. No online update check is performed.')
        window.ShowUpdates=show
        Button('Get packs link',18,195,function() ns.OpenPacks('download') end)
        Button('Rule packs',225,195,function() ns.OpenPacks('installed') end)
        Button('Close',542,120,function() window:Hide() end)
        T.Muted(Label(window,'Reopen these notes with /ocw updates or the Updates button in Review.',20,-608,640))
    end
    window.ShowUpdates:SetChecked(ns.DB.showUpdates~=false)
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    window:SetScale(math.min(1,(w-30)/680,(h-30)/632))
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
