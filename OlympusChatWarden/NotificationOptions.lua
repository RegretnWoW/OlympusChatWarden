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
    if category or not Settings.RegisterCanvasLayoutSubcategory then return end
    local f=CreateFrame('Frame',nil,nil,'BackdropTemplate');f:SetSize(640,620);T.SkinWindow(f)
    T.Crest(f,16,-8,56);T.Gold(Text(f,84,-16,510,'Notifications'))
    T.Muted(Text(f,84,-44,510,'Choose which hidden messages and Shield incidents notify you.'))
    local function Check(key,label,y,description,help)
        local c=CreateFrame('CheckButton',nil,f,'UICheckButtonTemplate')
        c:SetSize(26,26);c:SetPoint('TOPLEFT',14,y);Text(c,30,-6,570,label)
        c:SetScript('OnClick',function(self) N.Set(key,ns.Checked(self:GetChecked())) end)
        T.Muted(Text(f,44,y-29,570,description));T.Tooltip(c,label,help);checks[key]=c
    end
    Check('badges','Show unread badges',-100,'Controls message rows, the unread count and Olympus indicators.',
        'Master switch for visual unread notifications. It does not stop filtering, recording or Shield chat notices. Messages stay available; opening a message clears its unread state everywhere.')
    Check('chat','Show notices in chat',-164,'One short notice when an automatic pause or timeout starts.',
        'Only enabled categories below can create chat notices. Turning this off keeps unread badges and all review originals.')
    T.Gold(Text(f,20,-235,600,'Notify for'))
    Check('filtered','Hidden filtered messages',-258,'Word and language filtering. On by default.',
        'Adds unread notifications for fully hidden wording and language matches. Redactions, warnings and covered names do not create hidden-message alerts.')
    Check('shield','Contact protection',-316,'Unwanted contact and manually shielded players. On by default.',
        'Allows unread badges and chat notices for contact protection. Repeated chat, repeated whispers and rapid-message bursts use the separate Spam category.')
    Check('spam','Repeated messages and rapid chat',-374,'Off by default. Includes brief pauses and spam timeouts.',
        'Controls both unread badges for messages hidden by spam protection and its chat notices. Also covers repeated-whisper timeouts. Off means quiet hiding; Messages and Shield retain originals and incident details.')
    Check('advertising','Gold and paid-service ads',-432,'Off by default. Ads and timed shields are still saved for review.',
        'Allows unread badges for hidden gold/service ads and chat notices for their automatic timeouts. Turning this off keeps ad filtering, Shield protection and the original messages.')
    Check('recruitment','Guild recruitment ads',-490,'Off by default. Hidden ads remain in Messages.',
        'Allows unread notifications for guild recruitment ads. Turning this off hides them quietly. Olympus guild-name exceptions are controlled by the recruitment filter.')
    T.Muted(Text(f,20,-566,600,'Category switches apply to badges and chat notices. Quiet messages remain in Review > Messages. Filtering is unchanged.'))
    f:SetScript('OnShow',ns.RefreshNotificationsOptions);T.BindSettings(f)
    category=Settings.RegisterCanvasLayoutSubcategory(parent,f,'Notifications')
    ns.NotificationOptionsPanel=f;ns.NotificationOptionControls=checks;ns.RefreshNotificationsOptions()
end
function ns.OpenNotificationOptions()
    ns.BuildOptions()
    if category and Settings.OpenToCategory then Settings.OpenToCategory(category:GetID())
    else ns.Print('Notification settings are unavailable in this client.') end
end
