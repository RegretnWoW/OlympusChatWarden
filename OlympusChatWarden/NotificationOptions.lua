local _,ns=...
local T,N=ns.Theme,ns.Notifications
local category,checks=nil,{}
local function Text(parent,x,y,width,value)
    local text=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
    text:SetPoint('TOPLEFT',x,y);text:SetWidth(width);text:SetJustifyH('LEFT');text:SetWordWrap(true)
    text:SetText(value or '');T.Light(text);return text
end
function ns.RefreshNotificationsOptions()
    if not ns.DB then return end
    for key,control in pairs(checks) do control:SetChecked(N.Get(key)) end
end
function ns.BuildNotificationsOptions(parent)
    if category or (not ns.Workspace and not Settings.RegisterCanvasLayoutSubcategory) then return end
    local f=CreateFrame('Frame',nil,nil,'BackdropTemplate');f:SetSize(640,748);T.SkinWindow(f)
    T.Crest(f,16,-8,56);T.Gold(Text(f,84,-16,510,'Notifications'))
    T.Muted(Text(f,84,-44,510,'Choose which redactions, hidden messages and Shield incidents notify you.'))
    local function Check(key,label,y,description,help)
        local c=CreateFrame('CheckButton',nil,f,'UICheckButtonTemplate')
        c:SetSize(26,26);c:SetPoint('TOPLEFT',14,y);c.caption=Text(c,30,-6,570,label)
        c:SetScript('OnClick',function(self) N.Set(key,ns.Checked(self:GetChecked())) end)
        c.detail=T.Muted(Text(f,44,y-29,570,description));T.Tooltip(c,label,help);checks[key]=c
    end
    Check('badges','Show unread badges',-92,'Controls message rows, the unread count and Olympus indicators.',
        'Master switch for visual unread notifications. It does not stop filtering, recording or Shield chat notices. Messages stay available; opening a message clears its unread state everywhere.')
    Check('chat','Show notices in chat',-150,'One short notice when an automatic pause or timeout starts.',
        'Only enabled categories below can create chat notices. Turning this off keeps unread badges and all review originals.')
    local heading=T.Gold(Text(f,20,-217,600,'Notify for'))
    Check('hidden','Hidden messages',-240,'On by default. Alert when filtering hides a message.',
        'Allow unread badges for hidden wording or language messages in enabled categories. Redactions have a separate switch. This never changes what is filtered or saved.')
    Check('redacted','Redacted text and names',-294,'Off by default. Covered originals remain in Messages.',
        'Allow unread badges for covered wording and names in enabled categories. Warnings and replacements stay quiet in the Messages feed. Hidden-message alerts are independent.')
    Check('filtered','Word filtering',-348,'On by default. Uses the Hidden and Redacted switches above.',
        'Word and personal-rule filtering can notify for the actions enabled above. Originals, warnings and replacements remain in Messages even when alerts are off.')
    Check('language','Language filtering',-402,'Off by default. Uses the Hidden and Redacted switches above.',
        'Allow notifications for language-only filtering, using the actions enabled above. An independent wording redaction or hide follows Word filtering.')
    Check('shield','Contact protection',-456,'Unwanted contact and manually shielded players. On by default.',
        'Allows unread badges and chat notices for contact protection. Repeated chat, repeated whispers and rapid-message bursts use the separate Spam category.')
    Check('spam','Repeated messages and rapid chat',-510,'Off by default. Includes brief pauses and spam timeouts.',
        'Controls both unread badges for messages hidden by spam protection and its chat notices. Also covers repeated-whisper timeouts. Off means quiet hiding; Messages and Shield retain originals and incident details.')
    Check('advertising','Gold and paid-service ads',-564,'Off by default. Ads and timed shields remain available for review.',
        'Allows unread badges for hidden gold/service ads and chat notices for their automatic timeouts. Turning this off keeps ad filtering, Shield protection and the original messages.')
    Check('recruitment','Guild recruitment ads',-618,'Off by default. Hidden ads remain in Messages.',
        'Allows unread notifications for guild recruitment ads. Turning this off hides them quietly. Olympus guild-name exceptions are controlled by the recruitment filter.')
    local note=T.Muted(Text(f,20,-700,600,'Quiet filtering stays in Messages; contact incidents stay in Shield. These switches only change alerts.'))
    if ns.Workspace then
        local W,V=ns.Workspace,ns.Art;heading:Hide()
        local delivery=V.Panel(f,18,-18,1104,158,'dark');V.Text(delivery,'How you receive alerts',18,-18,1050,18,V.gold)
        local matches=V.Panel(f,18,-192,544,430,'dark');V.Text(matches,'Filtered messages',18,-18,490,18,V.gold)
        local spam=V.Panel(f,578,-192,544,430,'dark');V.Text(spam,'Contact, spam & advertising',18,-18,490,18,V.gold)
        function f:ChatWardenLayout(w,h)
            local half=(w-52)/2
            W.Place(delivery,18,-18,w-36,158);W.Place(matches,18,-192,half,h-250);W.Place(spam,34+half,-192,half,h-250)
            for i,key in ipairs({'badges','chat'}) do
                local c=checks[key];W.Place(c,16+(i-1)*(half+16),-52,nil,nil,delivery);c.caption:SetWidth(half-70)
                W.Place(c.detail,22+(i-1)*(half+16),-88,half-48,52,delivery)
            end
            for group,keys in ipairs({{'hidden','redacted','filtered','language'},{'shield','spam','advertising','recruitment'}}) do
                for i,key in ipairs(keys) do
                    local c=checks[key];local parent=group==1 and matches or spam
                    local step=math.min(92,(h-318)/4)
                    W.Place(c,16,-58-(i-1)*step,nil,nil,parent);c.caption:SetWidth(half-70)
                    W.Place(c.detail,22,-88-(i-1)*step,half-44,math.max(26,step-32),parent)
                end
            end
            W.Place(note,24,-(h-32),w-48)
        end
    end
    f:SetScript('OnShow',ns.RefreshNotificationsOptions);T.BindSettings(f)
    category=ns.Workspace and parent or Settings.RegisterCanvasLayoutSubcategory(parent,f,'Notifications')
    ns.NotificationOptionsPanel=f;ns.NotificationOptionControls=checks;ns.RefreshNotificationsOptions()
end
function ns.OpenNotificationOptions()
    ns.BuildOptions()
    if category and Settings.OpenToCategory then Settings.OpenToCategory(category:GetID())
    else ns.Print('Notification settings are unavailable in this client.') end
end
