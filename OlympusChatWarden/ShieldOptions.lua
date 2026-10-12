local _,ns=...
local T,S=ns.Theme,ns.Shield
local category,status
local controls={}
local function Text(parent,x,y,width,value)
    local t=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
    t:SetPoint('TOPLEFT',x,y);t:SetWidth(width);t:SetJustifyH('LEFT');t:SetText(value or '');T.Light(t);return t
end
function ns.RefreshShieldOptions()
    if not status or not ns.DB or not ns.DB.shield then return end
    local db=ns.DB.shield;local p=S.Profiles[db.profile]
    status:SetText('Protection: '..(S.Active() and 'ACTIVE' or 'OFF'))
    for key,c in pairs(controls) do
        c:SetChecked(db[key])
        if p[key] then
            local r=p[key]
            local window=r[2]%60==0 and (r[2]/60)..' minutes' or r[2]..' seconds'
            local noun=key=='whispers' and ' strong matches' or key=='repeatedWhispers' and ' similar whispers' or ' requests'
            c.detail:SetText(r[1]..noun..' in '..window
                ..'; shield for '..math.floor(r[3]/60)..' minutes.'..(S.capabilities[key]==false and ' Not supported by this client.' or ''))
        end
    end
end
function ns.BuildShieldOptions(parentCategory)
    if category or not Settings.RegisterCanvasLayoutSubcategory then return end
    local f=CreateFrame('Frame',nil,nil,'BackdropTemplate');f:SetSize(640,620);T.SkinWindow(f)
    T.Crest(f,16,-8,56);T.Gold(Text(f,84,-16,500,'ChatWarden Shield'))
    T.Muted(Text(f,84,-44,510,'Local contact protection. Manage players in Review > Shield.'))
    status=T.Muted(Text(f,20,-78,600))
    local function Check(key,label,y,help)
        local c=CreateFrame('CheckButton',nil,f,'UICheckButtonTemplate')
        c:SetSize(26,26);c:SetPoint('TOPLEFT',14,y);Text(c,30,-6,275,label)
        c:SetScript('OnClick',function(self) S.SetOption(key,ns.Checked(self:GetChecked())) end)
        T.Tooltip(c,label,help);controls[key]=c;return c
    end
    Check('enabled','Enable ChatWarden Shield',-105,'Enables contact protection. Requires the main ChatWarden switch. Disabling preserves saved players; existing timers continue.')
    local options={
        {'whispers','Strong-wording whispers','Counts accepted wording matches scoring 80+. Replacements and display masks are excluded.'},
        {'repeatedWhispers','Repeated whispers','Detects identical or slightly changed incoming whispers without a word match. Replying resets that player\'s counter. Independent of chat capture.'},
        {'trades','Trade requests','Declines repeated trade requests after the threshold. Accepted trades reset the counter where supported.'},
        {'duels','Duel requests','Declines repeated duel requests after the threshold. Accepted duels reset the counter.'},
        {'invites','Group invites','Declines repeated group invites after the threshold. Accepted invites reset the counter.'},
        {'visibleChat','Shielded player chat','Hides player chat from shielded senders. Originals remain in Messages.'},
        {'bubbles','Shielded chat bubbles','Hides accessible bubbles only when the speaker can be identified reliably.'},
    }
    for i,item in ipairs(options) do
        local c=Check(item[1],item[2],-155-(i-1)*44,item[3])
        c.detail=T.Muted(Text(f,46,-181-(i-1)*44,570,item[3]))
    end
    local notices=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');notices:SetSize(286,24);notices:SetPoint('TOPLEFT',20,-483)
    notices:SetText('Notifications');notices:SetScript('OnClick',ns.OpenNotificationOptions)
    T.Tooltip(notices,'Notifications','Set contact, spam and ad alerts in one place. Categories control both unread badges and chat notices.')
    T.Muted(Text(f,20,-521,600,'Allowed players bypass Shield; ordinary word filters still apply. Battle.net whispers are excluded.'))
    for i,item in ipairs({{'Open Review > Shield',ns.OpenShield},{'Spam protection',ns.OpenSpamOptions}}) do
        local b=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');b:SetSize(286,26);b:SetPoint('TOPLEFT',20+(i-1)*300,-568)
        b:SetText(item[1]);b:SetScript('OnClick',item[2])
        T.Tooltip(b,item[1],i==1 and 'See contact alerts and manage shielded or allowed players.' or 'Choose ad, repeated-message and rapid-chat checks, channels and timeout duration. Message limits are fixed.')
    end
    f:SetScript('OnShow',ns.RefreshShieldOptions);T.BindSettings(f)
    ns.ShieldOptionControls=controls
    category=Settings.RegisterCanvasLayoutSubcategory(parentCategory,f,'Shield');ns.ShieldOptionsPanel=f;ns.RefreshShieldOptions()
    if ns.BuildSpamOptions then ns.BuildSpamOptions(category) end
end
function ns.OpenShieldOptions()
    ns.BuildOptions()
    if category and Settings.OpenToCategory then Settings.OpenToCategory(category:GetID())
    else ns.Print('Shield settings are unavailable in this client.') end
end
