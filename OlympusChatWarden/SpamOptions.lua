local _,ns=...
local T,P=ns.Theme,ns.Spam
local category,status
local checks,drops={},{}
local function Text(parent,x,y,width,value)
    local t=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
    t:SetPoint('TOPLEFT',x,y);t:SetWidth(width);t:SetJustifyH('LEFT');t:SetText(value or '');T.Light(t);return t
end
function ns.RefreshSpamOptions()
    if not status or not ns.DB or not ns.DB.shield.spam then return end
    local db=ns.DB.shield.spam
    status:SetText((ns.Shield.Active() and db.enabled and 'Spam protection on' or 'Spam protection paused')..'  |  Spam protection')
    for key,c in pairs(checks) do c:SetChecked(db[key]) end
    for _,d in ipairs(drops) do d:Refresh() end
end
function ns.BuildSpamOptions(parent)
    if category or not Settings.RegisterCanvasLayoutSubcategory then return end
    local f=CreateFrame('Frame',nil,nil,'BackdropTemplate');f:SetSize(640,620);T.SkinWindow(f)
    T.Crest(f,16,-8,56);T.Gold(Text(f,84,-16,500,'Shield: Spam protection'))
    T.Muted(Text(f,84,-44,510,'Hide ads. Pause rapid chat before applying a full timeout.'))
    status=T.Muted(Text(f,20,-78,600))
    local function Check(key,label,x,y,help)
        local c=CreateFrame('CheckButton',nil,f,'UICheckButtonTemplate')
        c:SetSize(26,26);c:SetPoint('TOPLEFT',x,y);Text(c,30,-6,270,label)
        c:SetScript('OnClick',function(self) P.Set(key,ns.Checked(self:GetChecked())) end)
        T.Tooltip(c,label,help);checks[key]=c
    end
    Check('enabled','Enable Spam protection',14,-105,'Requires ChatWarden and Shield. Pausing detection preserves existing timed shields. Remove them in Review > Shield.')
    Check('advertising','Gold and paid-service ads',14,-149,'A website plus gold or leveling/boost services and sales or service-offer wording triggers a timeout. Recognizes common lookalike letters. A link alone does not trigger it; game links are excluded. Detection can make mistakes.')
    Check('recruitment','Guild recruitment ads',320,-149,'Hide individual recruitment ads, including <Guild Name> recruiting, raid-team pitches with a reply/sign-up request, and direct guild-invite offers. Olympus guild ads are exempt by guild name; this is not official verification. Guild mentions or Discord links alone do not trigger it. This check does not shield the sender. General flooding and repetition limits still apply. Starts on; uses the selected channels.')
    Check('repetition','Repeated or similar messages',14,-181,'Three similar messages in 30 seconds trigger the automatic timeout. Case, punctuation and small spelling changes are normalized. Counts the same player across selected channels.')
    Check('flooding','Rapid messages (any content)',14,-213,'Five messages in 10 seconds start a 10-second chat pause, without shielding contact requests. A second full burst within 60 seconds applies your automatic timeout. The same delivery counts once across chat windows. Allow player bypasses these checks.')
    local function Drop(key,label,x,y,items,help)
        T.Gold(Text(f,x,y,286,label))
        local d=T.Dropdown(f,x,y-23,286,items,function() return ns.DB.shield.spam[key] end,function(v) P.Set(key,v) end)
        T.Tooltip(d,label,help);drops[#drops+1]=d
    end
    Drop('duration','Automatic timeout',20,-260,{{300,'5 minutes'},{900,'15 minutes (default)'},{1800,'30 minutes'}},'For sales ads, repeated messages and a second rapid-message burst. Further messages do not extend an active timeout. Remove shield or Allow player ends it early.')
    T.Muted(Text(f,326,-270,286,'Rapid chat: 5 messages in 10 seconds.\nRepeated chat: 3 matches in 30 seconds.'))
    T.Gold(Text(f,20,-340,600,'Channels to check'))
    Check('public','Public chat',14,-363,'Trade, General and other channels, Say, Yell and emotes. Starts on.')
    Check('whispers','Whispers',320,-363,'Adds spam checks to whispers. Contact and repeated-whisper protection also work independently. Starts on.')
    Check('group','Party and raid',14,-403,'Includes instance groups and raid warnings. Starts on. Turn off to exclude group coordination.')
    Check('guild','Guild and officer',320,-403,'Starts on. Allowed players bypass all Shield checks.')
    T.Muted(Text(f,20,-450,600,'Spam and ads are quiet by default. Hidden originals stay in Messages; alerts stay in Shield. Change alerts in Notifications.'))
    local b=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');b:SetSize(286,26);b:SetPoint('TOPLEFT',20,-500)
    b:SetText('Review Shield alerts');b:SetScript('OnClick',ns.OpenShield)
    T.Tooltip(b,'Review Shield alerts','Select an alert for its reason and recent messages. No reports are sent automatically.')
    f:SetScript('OnShow',ns.RefreshSpamOptions);T.BindSettings(f)
    category=Settings.RegisterCanvasLayoutSubcategory(parent,f,'Spam protection')
    ns.SpamOptionsPanel=f;ns.SpamOptionControls=checks;ns.RefreshSpamOptions()
end
function ns.OpenSpamOptions()
    ns.BuildOptions()
    if category and Settings.OpenToCategory then Settings.OpenToCategory(category:GetID())
    else ns.Print('Spam settings are unavailable in this client.') end
end
