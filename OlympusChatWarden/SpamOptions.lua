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
    status:SetText((ns.Shield.Active() and db.enabled and 'Spam protection on' or 'Spam protection paused')..'  |  Local protection')
    for key,c in pairs(checks) do c:SetChecked(db[key]) end
    for _,d in ipairs(drops) do d:Refresh() end
end
function ns.BuildSpamOptions(parent)
    if category or (not ns.Workspace and not Settings.RegisterCanvasLayoutSubcategory) then return end
    local f=CreateFrame('Frame',nil,nil,'BackdropTemplate');f:SetSize(640,620);T.SkinWindow(f)
    T.Crest(f,16,-8,56);T.Gold(Text(f,84,-16,500,'Shield: Spam protection'))
    T.Muted(Text(f,84,-44,510,'Hide ads. Pause rapid chat before applying a full timeout.'))
    status=T.Muted(Text(f,20,-78,600))
    local function Check(key,label,x,y,help)
        local c=CreateFrame('CheckButton',nil,f,'UICheckButtonTemplate')
        c:SetSize(26,26);c:SetPoint('TOPLEFT',x,y);c.caption=Text(c,30,-6,270,label)
        c:SetScript('OnClick',function(self) P.Set(key,ns.Checked(self:GetChecked())) end)
        T.Tooltip(c,label,help);checks[key]=c
    end
    Check('enabled','Enable Spam protection',14,-105,'Requires ChatWarden and Shield. Pausing detection preserves existing timed shields. Remove them in Review > Shield.')
    Check('advertising','Gold and paid-service ads',14,-149,'A website plus gold or leveling/boost services and sales or service-offer wording triggers a timeout. Recognizes common lookalike letters. A link alone does not trigger it; game links are excluded. Detection can make mistakes.')
    Check('recruitment','Guild recruitment ads',320,-149,'Hide individual recruitment ads, including <Guild Name> recruiting, raid-team pitches with a reply/sign-up request, and direct guild-invite offers. Olympus guild ads are exempt by guild name; this is not official verification. Guild mentions or Discord links alone do not trigger it. This check does not shield the sender. General flooding and repetition limits still apply. Starts on; uses the selected channels.')
    Check('repetition','Repeated or similar messages',14,-181,'Three similar messages in 30 seconds trigger the automatic timeout. Case, punctuation and small spelling changes are normalized. Counts the same player across selected channels.')
    Check('flooding','Rapid messages (any content)',14,-213,'Five messages in 10 seconds start a 10-second chat pause, without shielding contact requests. A second full burst within 60 seconds applies your automatic timeout. The same delivery counts once across chat windows. Allow player bypasses these checks.')
    local function Drop(key,label,x,y,items,help)
        local caption=T.Gold(Text(f,x,y,286,label))
        local d=T.Dropdown(f,x,y-23,286,items,function() return ns.DB.shield.spam[key] end,function(v) P.Set(key,v) end)
        d.caption=caption;T.Tooltip(d,label,help);drops[#drops+1]=d
    end
    Drop('duration','Automatic timeout',20,-260,{{300,'5 minutes'},{900,'15 minutes (default)'},{1800,'30 minutes'}},'For sales ads, repeated messages and a second rapid-message burst. Further messages do not extend an active timeout. Remove shield or Allow player ends it early.')
    local limits=T.Muted(Text(f,326,-270,286,'Rapid chat: 5 messages in 10 seconds.\nRepeated chat: 3 matches in 30 seconds.'))
    local channelsHeading=T.Gold(Text(f,20,-340,600,'Channels to check'))
    Check('public','Public chat',14,-363,'Trade, General and other channels, Say, Yell and emotes. Starts on.')
    Check('whispers','Whispers',320,-363,'Adds spam checks to whispers. Contact and repeated-whisper protection also work independently. Starts on.')
    Check('group','Party and raid',14,-403,'Includes instance groups and raid warnings. Starts on. Turn off to exclude group coordination.')
    Check('guild','Guild and officer',320,-403,'Starts on. Allowed players bypass all Shield checks.')
    local note=T.Muted(Text(f,20,-450,600,'Spam and ads are quiet by default. Hidden originals stay in Messages; alerts stay in Shield. Change alerts in Notifications.'))
    if ns.Workspace then
        local W,V=ns.Workspace,ns.Art;channelsHeading:Hide()
        local detection=V.Panel(f,18,-98,544,520,'dark');V.Text(detection,'What to detect',18,-18,490,18,V.gold)
        local channels=V.Panel(f,578,-98,544,272,'dark');V.Text(channels,'Channels to check',18,-18,490,18,V.gold)
        local timing=V.Panel(f,578,-386,544,232,'dark');V.Text(timing,'Pauses & timeouts',18,-18,490,18,V.gold)
        local summaries={advertising='A sales or service offer with a website can trigger a timeout. A link alone does not.',recruitment='Hides recruitment pitches without shielding the sender. Olympus guild ads are exempt.',repetition='Three similar messages in 30 seconds trigger the selected timeout.',flooding='Five messages in 10 seconds start a brief pause. A second full burst within a minute triggers a timeout.'}
        for key,value in pairs(summaries) do checks[key].detail=V.Text(detection,value,22,-90,490,14,V.muted) end
        function f:ChatWardenLayout(w,h)
            local half=(w-52)/2
            W.Place(checks.enabled,18,-16,w-70);checks.enabled.caption:SetWidth(w-100);W.Place(status,24,-58,w-48)
            W.Place(detection,18,-98,half,h-156);W.Place(channels,34+half,-98,half,272)
            W.Place(timing,34+half,-386,half,h-444)
            for i,key in ipairs({'advertising','recruitment','repetition','flooding'}) do
                local c=checks[key];W.Place(c,16,-58-(i-1)*108,nil,nil,detection);c.caption:SetWidth(half-70)
                W.Place(c.detail,22,-90-(i-1)*108,half-44,68)
            end
            for i,key in ipairs({'public','whispers','group','guild'}) do local c=checks[key];W.Place(c,16,-58-(i-1)*44,nil,nil,channels);c.caption:SetWidth(half-70) end
            local d=drops[1];W.Place(d.caption,22,-58,half-44,nil,timing);W.Place(d,22,-84,half-44,34,timing)
            W.Place(limits,22,-144,half-44,64,timing);W.Place(note,24,-(h-32),w-48)
        end
    end
    if not ns.Workspace then
    local b=CreateFrame('Button',nil,f,'UIPanelButtonTemplate');b:SetSize(286,26);b:SetPoint('TOPLEFT',20,-500)
    b:SetText('Review Shield alerts');b:SetScript('OnClick',ns.OpenShield)
    T.Tooltip(b,'Review Shield alerts','Select an alert for its reason and recent messages. No reports are sent automatically.')
    end
    f:SetScript('OnShow',ns.RefreshSpamOptions);T.BindSettings(f)
    category=ns.Workspace and parent or Settings.RegisterCanvasLayoutSubcategory(parent,f,'Spam protection')
    ns.SpamOptionsPanel=f;ns.SpamOptionControls=checks;ns.RefreshSpamOptions()
end
function ns.OpenSpamOptions()
    ns.BuildOptions('spam')
    if category and Settings.OpenToCategory then Settings.OpenToCategory(category:GetID())
    else ns.Print('Spam settings are unavailable in this client.') end
end
