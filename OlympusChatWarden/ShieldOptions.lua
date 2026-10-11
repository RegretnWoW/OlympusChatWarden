local _,ns=...
local T,S=ns.Theme,ns.Shield
local category,profile,status
local controls={}
local function Text(parent,x,y,width,value)
    local t=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
    t:SetPoint('TOPLEFT',x,y);t:SetWidth(width);t:SetJustifyH('LEFT');t:SetText(value or '');T.Light(t);return t
end
function ns.RefreshShieldOptions()
    if not status or not ns.DB or not ns.DB.shield then return end
    local db=ns.DB.shield;local p=S.Profiles[db.profile]
    status:SetText('Protection: '..(S.Active() and 'ACTIVE' or 'OFF')..'  |  Profile: '..p.title)
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
    if profile.lastValue~=db.profile then profile.lastValue=db.profile;profile:Refresh() end
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
    profile=T.Dropdown(f,348,-107,272,{{'normal','Normal Harassment'},{'streamer','Streamer'}},
        function() return ns.DB.shield.profile end,function(v) S.SetProfile(v) end)
    T.Tooltip(profile,'Protection profile','Normal uses higher thresholds. Streamer uses lower thresholds and quiet notices. Changing profile resets counters and preserves existing shields.')
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
    Check('quiet','Quiet Shield notices',-483,'Suppresses Shield chat notices. Alerts and hidden-message badges remain available. Enabled by default for Streamer.')
    T.Muted(Text(f,20,-521,600,'Allowed players bypass Shield; ordinary word filters still apply. Battle.net whispers are excluded.'))
    for i,item in ipairs({{'Open Review > Shield',ns.OpenShield},{'Shield guide',function() ns.OpenTutorial('shield') end}}) do
        local b=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');b:SetSize(286,26);b:SetPoint('TOPLEFT',20+(i-1)*300,-568)
        b:SetText(item[1]);b:SetScript('OnClick',item[2])
        T.Tooltip(b,item[1],i==1 and 'See contact alerts and manage shielded or allowed players.' or 'Read a short guide to profiles, player controls and signal tooltips.')
    end
    f:SetScript('OnShow',ns.RefreshShieldOptions);T.BindSettings(f)
    ns.ShieldOptionControls=controls
    category=Settings.RegisterCanvasLayoutSubcategory(parentCategory,f,'Shield');ns.ShieldOptionsPanel=f;ns.RefreshShieldOptions()
end
function ns.OpenShieldOptions()
    ns.BuildOptions()
    if category and Settings.OpenToCategory then Settings.OpenToCategory(category:GetID())
    else ns.Print('Shield settings are unavailable in this client.') end
end
