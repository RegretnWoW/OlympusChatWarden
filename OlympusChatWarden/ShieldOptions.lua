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
    local db=ns.DB.shield
    status:SetText('Protection: '..(S.Active() and 'ACTIVE' or 'OFF'))
    for key,c in pairs(controls) do
        c:SetChecked(db[key])
        if S.GetRule(key) then
            local r=S.GetRule(key)
            local window=r[2]%60==0 and (r[2]/60)..' minutes' or r[2]..' seconds'
            local noun=key=='whispers' and ' strong matches' or key=='repeatedWhispers' and ' similar whispers' or ' requests'
            c.detail:SetText(r[1]..noun..' in '..window
                ..'; shield for '..math.floor(r[3]/60)..' minutes.'..(S.capabilities[key]==false and ' Not supported by this client.' or ''))
        end
    end
    if ns.ShieldOptionsPanel and ns.ShieldOptionsPanel.RefreshTuning then ns.ShieldOptionsPanel:RefreshTuning(false) end
end
function ns.BuildShieldOptions(parentCategory)
    if category or (not ns.Workspace and not Settings.RegisterCanvasLayoutSubcategory) then return end
    local f=CreateFrame('Frame',nil,nil,'BackdropTemplate');f:SetSize(640,620);T.SkinWindow(f)
    T.Crest(f,16,-8,56);T.Gold(Text(f,84,-16,500,'ChatWarden Shield'))
    T.Muted(Text(f,84,-44,510,'Local contact protection. Manage players in Review > Shield.'))
    status=T.Muted(Text(f,20,-78,600))
    local function Check(key,label,y,help)
        local c=CreateFrame('CheckButton',nil,f,'UICheckButtonTemplate')
        c:SetSize(26,26);c:SetPoint('TOPLEFT',14,y);c.caption=Text(c,30,-6,275,label)
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
    if not ns.Workspace then
    local notices=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');notices:SetSize(286,24);notices:SetPoint('TOPLEFT',20,-483)
    notices:SetText('Notifications');notices:SetScript('OnClick',ns.OpenNotificationOptions)
    T.Tooltip(notices,'Notifications','Set contact, spam and ad alerts in one place. Categories control both unread badges and chat notices.')
    end
    local note=T.Muted(Text(f,20,-521,600,'Allowed players bypass Shield; ordinary word filters still apply. Battle.net whispers are excluded.'))
    if ns.Workspace then
        local W,V=ns.Workspace,ns.Art
        local contact=V.Panel(f,18,-98,544,454,'dark');V.Text(contact,'Contact requests',18,-18,480,18,V.gold)
        local chat=V.Panel(f,578,-98,544,454,'dark');V.Text(chat,'Whispers & chat',18,-18,480,18,V.gold)
        local message=V.Text(f,'',24,-594,1080,13,V.muted)
        local profile=ns.DB.shield.profile
        local fields={};f.TuningFields=fields
        local preset=T.Dropdown(f,818,-18,300,{{'balanced','Balanced protection'},{'custom','Custom limits'},{'normal','Previous defaults'}},function() return profile end,function(v) profile=v;f:RefreshTuning(true) end)
        f.TuningPreset=preset
        for _,kind in ipairs(S.RuleKinds) do
            local parent=(kind=='trades' or kind=='duels' or kind=='invites') and contact or chat
            fields[kind]={}
            local default=S.Profiles.balanced[kind]
            fields[kind].default=V.Text(parent,'Balanced default: '..default[1]..' / '..default[2]..' sec / '..(default[3]/60)..' min shield',22,-160,480,11,V.muted)
            for i,label in ipairs({'Count','Within (seconds)','Shield (minutes)'}) do
                local text=V.Text(parent,label,22+(i-1)*166,-106,154,11,V.muted)
                local input,box=V.Edit(parent,22+(i-1)*166,-124,154,34,'')
                input:SetNumeric(true);input:SetMaxLetters(i==2 and 3 or 2);input.ChatWardenNoSpelling=true
                T.Tooltip(input,S.RuleTitles[kind]..' / '..label,'Choose Custom limits to edit. Count: 2–20. Window: 10–600 seconds. Shield: 1–60 minutes. Existing shield timers keep their expiry.')
                fields[kind][i]={input=input,box=box,label=text}
            end
        end
        function f:RefreshTuning(reset)
            for _,kind in ipairs(S.RuleKinds) do
                local r=profile=='custom' and ns.DB.shield.custom[kind] or (S.Profiles[profile] or S.Profiles.balanced)[kind]
                for i,field in ipairs(fields[kind]) do
                    if reset then field.input:SetText(tostring(i==3 and r[i]/60 or r[i])) end
                    local editable=profile=='custom' and ns.Membership.Allowed()
                    field.input:SetEnabled(editable);field.box:SetAlpha(editable and 1 or .55)
                end
                controls[kind].detail:SetText(kind=='whispers' and 'Eligible strong abuse evidence. Display action is separate; masks and replacements excluded.'
                    or kind=='repeatedWhispers' and 'Similar whispers; your reply resets the counter.'
                    or 'Accepted requests reset this player’s counter.')
            end
            preset:Refresh()
        end
        local apply=V.Button(f,'Apply protection settings',24,-628,290,34,function()
            local rules={}
            for _,kind in ipairs(S.RuleKinds) do
                rules[kind]={}
                for i,field in ipairs(fields[kind]) do local n=tonumber(field.input:GetText());rules[kind][i]=n and (i==3 and n*60 or n) end
            end
            local ok,why=S.SetTuning(profile,rules);message:SetText(why or '')
            if ok then ns.RefreshShieldOptions();f:RefreshTuning(true) end
        end)
        local reset=V.Button(f,'Reset defaults',826,-628,290,34,function()
            profile='balanced';S.SetTuning(profile);f:RefreshTuning(true);ns.RefreshShieldOptions();message:SetText('Balanced defaults restored. Existing shield timers are unchanged.')
        end,'neutral')
        function f:ChatWardenLayout(w,h)
            local half=(w-52)/2;local fieldWidth=(half-76)/3
            W.Place(controls.enabled,18,-16,26,26);controls.enabled.caption:SetWidth(w-420)
            W.Place(preset,w-338,-18,314,34);W.Place(status,24,-58,w-48)
            W.Place(contact,18,-98,half,h-222);W.Place(chat,34+half,-98,half,h-222)
            for group,kinds in ipairs({{'trades','duels','invites'},{'whispers','repeatedWhispers'}}) do
                local parent=group==1 and contact or chat
                for n,kind in ipairs(kinds) do
                    local offset=(n-1)*128;local c=controls[kind]
                    W.Place(c,16,-52-offset,26,26,parent);c.caption:SetWidth(half-70)
                    W.Place(c.detail,22,-82-offset,half-44,24,parent)
                    for i,field in ipairs(fields[kind]) do
                        local x=22+(i-1)*(fieldWidth+16)
                        W.Place(field.label,x,-106-offset,fieldWidth,14)
                        W.Place(field.box,x,-124-offset,fieldWidth,34)
                    end
                    W.Place(fields[kind].default,22,-160-offset,half-44,16)
                end
            end
            for n,kind in ipairs({'visibleChat','bubbles'}) do
                local c=controls[kind];W.Place(c,16,-322-(n-1)*62,26,26,chat);c.caption:SetWidth(half-70)
                W.Place(c.detail,22,-350-(n-1)*62,half-44,38,chat)
            end
            W.Place(message,24,-(h-108),w-48,28)
            W.Place(apply,24,-(h-66),290,34);W.Place(reset,w-314,-(h-66),290,34)
            W.Place(note,24,-(h-24),w-48)
        end
        f:HookScript('OnShow',function() profile=ns.DB.shield.profile;f:RefreshTuning(true);message:SetText('Choose Custom limits to edit counts and timers. Applying settings resets detection counters, not active shields.') end)
        f:RefreshTuning(true)
        f.TuningMessage=message
    end
    if not ns.Workspace then
    for i,item in ipairs({{'Open Review > Shield',ns.OpenShield},{'Spam protection',ns.OpenSpamOptions}}) do
        local b=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');b:SetSize(286,26);b:SetPoint('TOPLEFT',20+(i-1)*300,-568)
        b:SetText(item[1]);b:SetScript('OnClick',item[2])
        T.Tooltip(b,item[1],i==1 and 'See contact alerts and manage shielded or allowed players.' or 'Choose ad, repeated-message and rapid-chat checks, channels and timeout duration. Message limits are fixed.')
    end
    end
    f:HookScript('OnShow',ns.RefreshShieldOptions);T.BindSettings(f)
    ns.ShieldOptionControls=controls
    category=ns.Workspace and parentCategory or Settings.RegisterCanvasLayoutSubcategory(parentCategory,f,'Shield');ns.ShieldOptionsPanel=f;ns.RefreshShieldOptions()
    if ns.BuildSpamOptions then ns.BuildSpamOptions(category) end
end
function ns.OpenShieldOptions()
    ns.BuildOptions()
    if category and Settings.OpenToCategory then Settings.OpenToCategory(category:GetID())
    else ns.Print('Shield settings are unavailable in this client.') end
end
