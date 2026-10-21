-- One live workspace, backed by the existing filtering and storage modules.
local _,ns=...
local V,T,A=ns.Art,ns.Theme,ns.Activity
local W={pages={},navigation={},legacyFrames={},width=1440,height=900,leftOverhang=5,bottomOverhang=4};ns.Workspace=W
local definitions={
    {'overview','CommandWarden','Your dashboard, modules, performance and shared settings.'},
    {'chronicle','ChronicleWarden','Your own adventures, milestones and recorded time.'},
    {'intel','IntelWarden','Recently met players and profiles from retained evidence.'},
    {'activity','Recent activity','Chat, signals and protection activity.'},
    {'messages','ChatWarden','Messages, Capture, Rules, Packs and Reports.'},
    {'mentions','SignalWarden','Personal mentions, Wanted encounters and observed OlympusMute sharing.'},
    {'shield','ShieldWarden','Manage local shields, allowed players and contact alerts.'},
    {'relay','RelayWarden','Bug reports, diagnostics, data, backups and help.'},
    {'capture','Chat Capture','Search, bookmark and revisit locally recorded conversations.'},
    {'recording','Data & Backups','Inspect recorded events, collection status and backups.'},
    {'rules','My Rules','Your personal phrase actions and exceptions.'},
    {'packs','Rule Packs','Author-signed categories with independent controls.'},
    {'reports','My Reports','Read saved feedback and review exactly what you share.'},
    {'updates','Updates & Help','Release notes, guides and optional pack downloads.'},
    {'settings','CommandWarden','Shared appearance, window size and Warden preferences.'},
    {'modules','Modules & Performance','Choose your Warden features. Disabled modules keep saved data.'},
    {'performance','Performance','Module runtime states and safe diagnostics.'},
}
local labels={};for _,d in ipairs(definitions) do labels[d[1]]=d end
local chatPages={messages=true,capture=true,rules=true,packs=true,reports=true}
local relayPages={relay=true,recording=true,updates=true}
local commandPages={overview=true,activity=true,settings=true,modules=true,performance=true}
local function NavID(id) return ns.WardenBrand.Parent(id) end
local original={};for _,key in ipairs({'OpenReport','OpenReportLink','OpenExport','OpenPacks','OpenTutorial','OpenCategories','OpenPreview'}) do original[key]=ns[key] end
local nativeShow=T.ShowWindow
local function Plain(text) return (text or ''):gsub('|H.-|h(.-)|h','%1'):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('|T.-|t',''):gsub('|A.-|a',''):gsub('|','||') end
function W.NameSource(item)
    local name=item
    if type(item)=='table' then
        local review=item.reviewID and ns.Review.Get(item.reviewID)
        name=ns.Review.NameOriginal(review) or review and review.sender or item.captured and item.captured.sender or item.contact and item.contact.name
            or item.shieldAlert and item.shieldAlert.name or item.sender
    end
    if type(name)~='string' then return 'Unknown Player' end
    if ns.LanguageDisplay.CoveredMarkup(name) and not ns.LanguageDisplay.Identity(name) then return 'Name Unavailable' end
    -- A player's link payload retains the identity even if its visible label
    -- has already been covered by the native chat formatter.
    name=ns.LanguageDisplay.Identity(name)
    if not name then return 'Name Unavailable' end
    name=Plain(name)
    if name:match('^%s*%[%s*%]%s*$') or name=='[redacted]' or name=='' then return 'Name Unavailable' end
    return name
end
local function NameFont(owner,text)
    if not owner or not owner.GetFont then return end
    if not owner.ChatWardenNameFont then owner.ChatWardenNameFont={owner:GetFont()} end
    local font=owner.ChatWardenNameFont
    if T.DocumentFont(owner,owner.ChatWardenFontSize or font[2] or 14) then return end
    local visible=text:gsub('|T.-|t',''):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')
    if visible:find('[\128-\255]') and owner.SetFontObject then
        -- Retain the native font object's multilingual fallback. An explicit
        -- single TTF can render a revealed Chinese/Cyrillic name as boxes.
        owner:SetFontObject((font[2] or 14)>=17 and (GameFontHighlightLarge or 'GameFontHighlightLarge')
            or (GameFontHighlight or 'GameFontHighlight'))
    elseif font[1] and owner.SetFont then owner:SetFont(font[1],font[2],font[3] or '') end
end
local nameMeasure
local function FitName(name,owner)
    local width=owner and owner.GetWidth and ns.SafeNumber(ns.SafeCall(owner.GetWidth,owner))
    if not width or width<=0 or not owner.CanWordWrap or ns.SafeCall(owner.CanWordWrap,owner)~=false then return name,#name end
    if not nameMeasure then nameMeasure=UIParent:CreateFontString(nil,'OVERLAY');nameMeasure:Hide();nameMeasure:SetWordWrap(false) end
    local path,size,flags=owner:GetFont()
    if not T.DocumentFont(nameMeasure,owner.ChatWardenFontSize or size or 14) and path then nameMeasure:SetFont(path,size,flags or '') end
    if nameMeasure.SetTextScale then nameMeasure:SetTextScale(owner.GetTextScale and ns.SafeCall(owner.GetTextScale,owner) or 1) end
    nameMeasure:SetWidth(0);nameMeasure:SetText(name)
    width=math.max(0,width-4)
    if nameMeasure:GetStringWidth()<=width then return name,#name end
    -- Fit original UTF-8 boundaries, never an already rendered |T tag. Native
    -- ellipsis can cut through a second inline texture in narrow name rows.
    local ends={0};local at=0
    for char in name:gmatch('[%z\1-\127\194-\244][\128-\191]*') do at=at+#char;ends[#ends+1]=at end
    local low,high=1,#ends
    while low<high do
        local mid=math.ceil((low+high)/2);nameMeasure:SetText(name:sub(1,ends[mid])..'...')
        if nameMeasure:GetStringWidth()<=width then low=mid else high=mid-1 end
    end
    return name:sub(1,ends[low])..'...',ends[low]
end
function W.NameText(name,owner,revealed)
    name=W.NameSource(name)
    NameFont(owner,name)
    local display,kept=FitName(name,owner)
    if revealed then return display,false end
    local matches=ns.Active('chat') and ns.Find(name) or {}
    if ns.Language then matches=ns.Language.NameMatches(name,matches) end
    local clipped={}
    for _,match in ipairs(ns.DisplayMatches(name,matches)) do
        if match.first<=kept then
            local copy={};for key,value in pairs(match) do copy[key]=value end
            copy.last=math.min(copy.last,kept);clipped[#clipped+1]=copy
        end
    end
    local covered=false
    local text=ns.Engine.Render(display,clipped,function(original,match)
        if ns.IsRedacted(match) then covered=true;return ns.BarText(original,owner) end
        return match.replacement and Plain(match.replacement) or original
    end)
    return text,covered
end
local function ControlClick(button)
    return (button==nil or button=='LeftButton') and type(IsControlKeyDown)=='function' and ns.Checked(ns.SafeCall(IsControlKeyDown))
end
local function Stamp(item) return item.timestamp and ns.SafeCall(date,'%H:%M',item.timestamp) or 'This session' end
local function Channel(item)
    return item.channel and item.channel~='' and item.channel or ({CHAT_MSG_WHISPER='Whisper',CHAT_MSG_WHISPER_INFORM='Whisper',CHAT_MSG_GUILD='Guild',CHAT_MSG_OFFICER='Officer',CHAT_MSG_SAY='Say',CHAT_MSG_YELL='Yell'})[item.event] or item.event and item.event:gsub('CHAT_MSG_',''):gsub('_',' ') or 'Activity'
end
local function Icon(item) return ns.EventIcons.Chat(item) end
W.ActivityIcon=Icon
W.ActivityChannel=Channel
local function ShowStatus(text) if W.status then W.status:SetText(text or '') end end
function W.Queue()
    if ns.OlympusPanel then ns.OlympusPanel.Queue() end
    if W.queued then return end;W.queued=true
    local function refresh() W.queued=false;W.Refresh() end
    if C_Timer and C_Timer.After then C_Timer.After(0,refresh) else refresh() end
end
local featureIcons={filtering='messages',shield='shield',capture='capture',mentions='mentions'}
function W.FeatureEnabled(key)
    if key=='filtering' then return ns.Modules.Enabled('chat') and ns.DB.enabled end
    if key=='shield' then return ns.Shield.Active() end
    if key=='capture' then return ns.Modules.Enabled('chat') and ns.ChatCapture.db and ns.ChatCapture.db.enabled end
    return ns.Modules.Enabled('alerts') and ns.DB.alertsEnabled~=false and ((ns.Mentions.db and ns.Mentions.db.enabled) or (ns.Wanted.db and ns.Wanted.db.enabled))
end
function W.ToggleFeature(key)
    if not ns.Membership.Allowed() then return end
    local owner=key=='shield' and 'shield' or key=='mentions' and 'alerts' or 'chat'
    if not ns.Modules.Enabled(owner) then W.Open('modules');return end
    if key=='filtering' then ns.DB.enabled=not ns.DB.enabled;ns.PolicyChanged()
    elseif key=='shield' then ns.Shield.SetOption('enabled',not ns.DB.shield.enabled)
    elseif key=='capture' then ns.ChatCapture.SetOption('enabled',not ns.ChatCapture.db.enabled)
    elseif key=='mentions' then
        ns.DB.alertsEnabled=ns.DB.alertsEnabled==false;ns.Wanted.Refresh(true)
        if not ns.DB.alertsEnabled and ns.HideMentionToast then ns.HideMentionToast() end
    end
    W.Queue()
end
local function FeatureIcon(button,key)
    V.SetIcon(button.Icon,featureIcons[key]);V.FeatureState(button,W.FeatureEnabled(key))
end
function W.LayoutGuardian(hasTitle)
    local width=hasTitle and 150 or 184;local height=width*1269/1240
    W.guardian:SetSize(width,height)
    -- Align the straight gold rails baked into the transparent artwork with
    -- the outer frame. The jewel tips can overlap the corner by a few pixels.
    W.guardian:ClearAllPoints()
    W.guardian:SetPoint('BOTTOMLEFT',W.window,'BOTTOMLEFT',-width*27/1024,-height*21/1024)
end
function W.Refresh()
    if not W.window or not W.window:IsVisible() then return end
    W.filterStatus:SetText(W.FeatureEnabled('filtering') and 'Filtering: ON' or 'Filtering: OFF')
    W.shieldStatus:SetText(ns.Shield.Active() and 'Shield: ON' or 'Shield: OFF')
    W.filterButton:SetShown(ns.Modules.Selected('chat'));W.filterStatus:SetShown(ns.Modules.Selected('chat'))
    W.shieldButton:SetShown(ns.Modules.Selected('shield'));W.shieldStatus:SetShown(ns.Modules.Selected('shield'))
    local connection=ns.OlympusConnection
    W.olympusStatus:SetText(connection.StatusText())
    W.olympusStatus:SetTextColor(unpack(connection.state=='connected' and {.42,.84,.55} or V.gold))
    W.olympusHint:SetText(ns.OlympusIntegration.Available() and 'Open Olympus' or 'Olympus Unavailable')
    local own=connection.Profile();own=own and own.member and own or nil
    W.profileRows[1].value:SetText(own and own.guild or 'Unavailable')
    W.profileRows[2].value:SetText(own and own.rank or 'Unavailable')
    local title=own and own.title
    W.profileRows[3].value:SetText(title or '')
    W.profileRows[3].value:SetShown(title~=nil);W.profileRows[3].label:SetShown(title~=nil)
    W.profile:SetHeight(title and 102 or 68)
    W.LayoutGuardian(title~=nil)
    FeatureIcon(W.filterButton,'filtering');FeatureIcon(W.shieldButton,'shield')
    W.UpdatePageToggle()
    if W.nativeMaster then W.nativeMaster:SetChecked(ns.DB.enabled) end
    for _,id in ipairs({'messages','mentions','shield'}) do W.navigation[id].Badge:SetCount(A.Unread(id=='mentions' and 'alerts' or id)) end
    W.navigation.overview.Badge:SetCount(0)
    W.totalBadge:SetCount(A.Unread())
    local page=W.pages[W.current];if page and page.Refresh and page:IsShown() then page:Refresh() end
    if W.activeSetting and W.current=='settings' and ns.SyncOptions then ns.SyncOptions() end
    -- Update functional views and counts before the decorative launcher icon.
    local olympusIcon=W.olympusButton.Icon
    ns.OlympusIntegration.ApplyIcon(olympusIcon)
    olympusIcon:ClearAllPoints();olympusIcon:SetPoint('CENTER');olympusIcon:SetSize(28,28)
    olympusIcon:SetAlpha(ns.OlympusIntegration.Available() and 1 or .4)
    if olympusIcon.ChatWardenFallback then olympusIcon.ChatWardenFallback:SetAlpha(olympusIcon:GetAlpha()) end
end
function W.Ensure()
    if W.window then return end
    local root=V.Panel(UIParent,0,0,W.width,W.height,'dark');root:ClearAllPoints();root:SetPoint('CENTER')
    root:SetFrameStrata('DIALOG');root:SetClampedToScreen(true);root:SetMovable(true);root:EnableMouse(true)
    if root.SetClampRectInsets then root:SetClampRectInsets(-W.leftOverhang,0,0,-W.bottomOverhang) end
    root.ChatWardenOwned=true;root:SetScript('OnHide',function() V.CloseMenus() end)
    W.window=root;ns.WorkspaceWindow=root
    T.RegisterWindow(root)
    local header=V.Panel(root,12,-12,1416,78,'header')
    header:EnableMouse(true);header:RegisterForDrag('LeftButton');header:SetScript('OnDragStart',function() root:StartMoving() end)
    header:SetScript('OnDragStop',function() root:StopMovingOrSizing() end)
    local logo=V.Texture(header,'Logo',{0,0,512,512},'OVERLAY');logo:SetSize(100,100);logo:SetPoint('TOPLEFT',4,7)
    V.Text(header,'Olympus Warden',115,-25,460,27,V.gold)
    W.filterButton=V.IconButton(header,'messages',44,729,-14,function() W.ToggleFeature('filtering') end,'ChatWarden filtering','Click to enable or pause filtering. The crest stays the same; ON/OFF shows its state.');W.filterStatus=V.Text(header,'',785,-28,135,12);W.filterStatus:SetHeight(24);W.filterStatus:SetJustifyV('MIDDLE')
    W.shieldButton=V.IconButton(header,'shield',44,930,-14,function() W.ToggleFeature('shield') end,'ShieldWarden','Click to enable or pause all Shield protection. The crest stays the same; ON/OFF shows its state.');W.shieldStatus=V.Text(header,'',986,-28,102,12);W.shieldStatus:SetHeight(24);W.shieldStatus:SetJustifyV('MIDDLE')
    W.olympusButton=V.IconButton(header,'olympus',25,1105,-24,function() local _,message=ns.OlympusIntegration.Open();if message then ShowStatus(message) end;W.Queue() end,'Olympus','Open Olympus and bring it to the front.')
    W.olympusStatus=V.Text(header,'',1136,-23,205,12)
    W.olympusHint=V.Text(header,'',1136,-41,205,10,V.muted)
    W.olympusButton:HookScript('OnEnter',function()
        if GameTooltip then GameTooltip:AddLine(ns.OlympusConnection.Reason(),.9,.9,.85,true);GameTooltip:Show() end
    end)
    V.Button(header,'X',1362,-16,38,38,function() root:Hide() end,'danger')
    W.totalBadge=V.Badge(header,-48,-48)
    local sidebar=V.Panel(root,12,-101,236,778,'sidebar')
    local index=0
    for _,d in ipairs(definitions) do if NavID(d[1])==d[1] and d[1]~='modules' then
        index=index+1
        local id=d[1];local label=id=='updates' and 'Updates & Help' or d[2]
        local b=V.Button(sidebar,label,8,-12-(index-1)*64,220,62,function() W.Open(id) end,'row')
        b.WardenClickSound='tab'
        local fontPath=b.Caption:GetFont();if not T.DocumentFont(b.Caption,16) then b.Caption:SetFont(fontPath,16,'') end
        b.Caption:ClearAllPoints();b.Caption:SetPoint('LEFT',72,0);b.Caption:SetWidth(140);b.Caption:SetJustifyH('LEFT')
        b.Icon=V.Icon(b,id,60,6,-1);b.SelectedArt=V.Nine(b,'selected');b.SelectedArt:SetShown(false)
        b.Badge=V.Badge(b,-4,-11);W.navigation[id]=b
        T.Tooltip(b,d[2],d[3])
    end end
    -- Measure the complete labels with the client's actual font. Use one size
    -- for the whole sidebar so CommandWarden fits without shrinking its crest.
    local navMeasure=sidebar:CreateFontString(nil,'OVERLAY');navMeasure:Hide()
    local navSize=16
    while navSize>12 do
        local fits=true
        for _,b in pairs(W.navigation) do
            local path=b.Caption:GetFont()
            if not T.DocumentFont(navMeasure,navSize) then navMeasure:SetFont(path,navSize,'') end
            navMeasure:SetText(b:GetText())
            if (navMeasure:GetStringWidth() or 0)>b.Caption:GetWidth()-4 then fits=false;break end
        end
        if fits then break end;navSize=navSize-1
    end
    for _,b in pairs(W.navigation) do
        local path=b.Caption:GetFont()
        if not T.DocumentFont(b.Caption,navSize) then b.Caption:SetFont(path,navSize,'') end
    end
    W.LayoutNavigation()
    W.profile=CreateFrame('Frame',nil,sidebar);W.profile:SetPoint('TOPLEFT',10,-476);W.profile:SetSize(216,102)
    W.profileRows={}
    for i,label in ipairs({'Guild','Rank','Title'}) do
        local row={label=V.Text(W.profile,label,0,-(i-1)*34,44,10,V.blue),value=V.Text(W.profile,'',50,-(i-1)*34,164,12,V.gold)}
        row.value:SetHeight(32);row.value:SetWordWrap(true);row.value:SetJustifyV('TOP')
        if row.value.SetMaxLines then row.value:SetMaxLines(2) end
        W.profileRows[i]=row
    end
    T.Tooltip(W.profile,'Olympus Profile','Your guild, rank and selected title come from Olympus after you grant access.');W.profile:EnableMouse(true)
    W.LayoutNavigation() -- Also place the profile correctly on a cold minimal start.
    W.guardian=V.Texture(sidebar,'Guardian',{0,0,1024,1024},'ARTWORK');W.LayoutGuardian(false)
    W.pageHeader=V.Panel(root,260,-101,1168,76,'dark')
    W.pageIcon=V.Icon(W.pageHeader,'overview',72,12,-2)
    W.heading=V.Text(W.pageHeader,'',100,-10,810,22,V.gold);W.heading:SetHeight(28);W.heading:SetWordWrap(false)
    W.pageToggle=V.Button(W.pageHeader,'',920,-8,228,32,function() W.ToggleFeature(W.current) end,'button')
    W.pageIconButton=CreateFrame('Button',nil,W.pageHeader);W.pageIconButton:SetPoint('TOPLEFT',12,-2);W.pageIconButton:SetSize(72,72);W.pageIconButton.Icon=W.pageIcon
    W.pageIconButton:SetScript('OnClick',function() W.ToggleFeature(W.current) end)
    T.Tooltip(W.pageIconButton,'Feature Switch','Click to enable or pause this feature. Saved records and settings are kept.')

    W.tabHost=CreateFrame('Frame',nil,W.pageHeader);W.tabHost:SetPoint('TOPLEFT',86,-42);W.tabHost:SetSize(1066,28)
    W.chatTabHost=CreateFrame('Frame',nil,W.pageHeader);W.chatTabHost:SetPoint('TOPLEFT',100,-42);W.chatTabHost:SetSize(1052,28);W.chatTabHost:Hide()
    W.canvas=CreateFrame('Frame',nil,root);W.canvas:SetPoint('TOPLEFT',274,-190);W.canvas:SetSize(1140,676)
    W.legacyHost=CreateFrame('ScrollFrame',nil,W.canvas);W.legacyHost:SetAllPoints();W.legacyHost:Hide()
    W.status=V.Text(root,'History stays local. Report delivery starts only after Submit.',274,-875,1030,11,V.muted)
    V.Text(root,'v'..ns.VERSION,1297,-875,118,11,V.gold)
    root:HookScript('OnShow',W.Refresh)
    local screen=CreateFrame('Frame',nil,root);screen:RegisterEvent('DISPLAY_SIZE_CHANGED');screen:RegisterEvent('UI_SCALE_CHANGED')
    screen:SetScript('OnEvent',function() if W.Fit then W.Fit() end end)
    local esc=CreateFrame('Frame','OlympusChatWardenWorkspaceEscape',root);esc:SetAllPoints();esc:EnableMouse(false);esc:Hide()
    -- Only the workspace belongs to Escape handling; page forms stay inside it.
    if UISpecialFrames then _G.OlympusChatWardenWorkspace=root;UISpecialFrames[#UISpecialFrames+1]='OlympusChatWardenWorkspace' end
    W.LayoutNavigation()
end
function W.Tabs(specs,current)
    local chat=chatPages[W.current]
    local relay=relayPages[W.current]
    W.chatTabHost:SetShown(chat==true or relay==true)
    for _,button in ipairs(W.chatTabs or {}) do button:Hide() end
    for _,button in ipairs(W.relayTabs or {}) do button:Hide() end
    if chat then
        W.chatTabs=W.chatTabs or {}
        for i,s in ipairs({{'messages','Messages'},{'capture','Capture'},{'rules','Rules'},{'packs','Packs'},{'reports','Reports'},{'chat-settings','Settings'}}) do
            local id=s[1];local b=W.chatTabs[i]
            if not b then b=V.Button(W.chatTabHost,s[2],(i-1)*174,0,168,28,function() if id=='chat-settings' then W.SettingsSub('general') else W.Open(id) end end,'tabOff');b.ActiveArt=V.Nine(b,'tab');W.chatTabs[i]=b end
            local selected=W.current==id or id=='chat-settings' and W.mounted~=nil
            b.ActiveArt:SetShown(selected);b.ArtNormal:SetShown(not selected);b:Show()
        end
    end
    if relay then
        local choices={{'relay','Support'},{'recording','Data & Backups'},{'updates','Help & Updates'}}
        local selected=W.current
        W.relayTabs=W.relayTabs or {}
        local width=280
        for i,s in ipairs(choices) do
            local id=s[1];local b=W.relayTabs[i]
            if not b then b=V.Button(W.chatTabHost,'',0,0,width,28,function() end,'tabOff');b.ActiveArt=V.Nine(b,'tab');W.relayTabs[i]=b end
            b:ClearAllPoints();b:SetPoint('TOPLEFT',(i-1)*(width+6),0);b:SetSize(width,28);b.Caption:SetWidth(width-18);b:SetText(s[2]);b:Show()
            b:SetScript('OnClick',function()
                W.Open(id)
            end)
            b.ActiveArt:SetShown(id==selected);b.ArtNormal:SetShown(id~=selected)
        end
    end
    W.tabHost:ClearAllPoints();W.tabHost:SetPoint('TOPLEFT',100,(chat or relay) and -74 or -42)
    W.LayoutHeader(#specs>0)
    W.tabs=W.tabs or {};for _,tab in ipairs(W.tabs) do tab:Hide() end
    local x=0;local maximum=(W.tabHost:GetWidth()-math.max(0,#specs-1)*6)/math.max(1,#specs)
    for i,spec in ipairs(specs) do
        local tab=W.tabs[i]
        if not tab then tab=V.Button(W.tabHost,'',0,0,166,34,function() end,'tabOff');tab.ActiveArt=V.Nine(tab,'tab');W.tabs[i]=tab end
        tab:ClearAllPoints();tab:SetPoint('TOPLEFT',x,0);tab:SetSize(math.min(spec[4] or 166,maximum),28);tab.Caption:SetWidth(math.min(spec[4] or 166,maximum)-18);tab.Caption:SetHeight(18);tab.Caption:SetJustifyV('MIDDLE')
        tab:SetText(spec[2]);tab:SetScript('OnClick',spec[3]);tab.ActiveArt:SetShown(spec[1]==current);tab.ArtNormal:SetShown(spec[1]~=current);tab:Show()
        x=x+math.min(spec[4] or 166,maximum)+6
    end
end
function W.LayoutHeader(hasTabs)
    local height=(chatPages[W.current] or relayPages[W.current]) and (hasTabs and 108 or 76) or 76
    W.pageHeader:SetHeight(height)
    W.canvas:ClearAllPoints();W.canvas:SetPoint('TOPLEFT',274,-114-height)
    W.canvas:SetHeight(752-height)
    W.LayoutMounted()
    W.LayoutRelayLegacy()
end
-- Legacy evidence/help pages retain their controls and internal routes. A small
-- outer viewport accommodates the new primary Relay row without clipping tools.
function W.LayoutRelayLegacy()
    for _,wrap in pairs(W.relayLegacy or {}) do
        if wrap.scroll.ChatWardenUpdateScrollRange then wrap.scroll.ChatWardenUpdateScrollRange(math.max(0,676-W.canvas:GetHeight())) end
    end
end
function W.WrapRelayLegacy(page)
    W.relayLegacy=W.relayLegacy or {}
    local wrap=W.relayLegacy[page]
    if not wrap then
        local scroll=CreateFrame('ScrollFrame',nil,W.canvas);scroll:SetAllPoints();V.SkinScroll(scroll)
        page:SetParent(scroll);page:ClearAllPoints();page:SetPoint('TOPLEFT');page:SetSize(1140,676);scroll:SetScrollChild(page)
        wrap={scroll=scroll};W.relayLegacy[page]=wrap
        page:HookScript('OnHide',function() scroll:Hide() end)
    end
    wrap.scroll:Show();W.LayoutRelayLegacy()
end
-- Embedded tools arrange native controls at the available workspace size.
-- Keep a stable font size rather than magnifying an old, narrow window.
function W.Place(widget,x,y,width,height,parent)
    if parent then widget:SetParent(parent) end
    widget:ClearAllPoints();widget:SetPoint('TOPLEFT',x,y)
    if widget.GetObjectType and widget:GetObjectType()=='CheckButton' and not widget.Caption then
        -- Native checkbox art fills its frame. Only its label may grow wide.
        widget:SetSize(26,26)
        if widget.Text and width then widget.Text:SetWidth(math.max(1,width-34)) end
    elseif width then widget:SetWidth(width) end
    if height then widget:SetHeight(height) end
    if height and widget.GetObjectType and widget:GetObjectType()=='FontString' then widget:SetJustifyV('TOP') end
    return widget
end
function W.LayoutMounted()
    local frame=W.mounted
    if frame and frame.ChatWardenLayout then
        frame:SetScale(1);frame:ClearAllPoints();frame:SetPoint('TOPLEFT',0,0)
        frame:SetSize(W.canvas:GetWidth(),W.canvas:GetHeight())
        frame:ChatWardenLayout(W.canvas:GetWidth(),W.canvas:GetHeight())
    end
end
function W.ToolTitle(frame,title)
    frame.ChatWardenTitle=title
    if W.mounted==frame then W.heading:SetText(title) end
end
function W.Header(id)
    local d=labels[id] or labels.overview
    W.heading:SetText(commandPages[id] and 'CommandWarden' or chatPages[id] and 'ChatWarden' or relayPages[id] and 'RelayWarden' or d[2]);V.SetIcon(W.pageIcon,NavID(id));W.pageIcon:SetAlpha(1)
    if W.pageIcon.SetDesaturated then W.pageIcon:SetDesaturated(false) end
    -- Replace via the shared icon routine so reference rectangles stay in one module.
    for key,button in pairs(W.navigation) do button.SelectedArt:SetShown(key==NavID(id));button.ArtNormal:SetShown(key~=NavID(id)) end
    W.UpdatePageToggle()
end
function W.UpdatePageToggle()
    if not W.pageToggle then return end
    local id=W.current;local feature=id=='capture' or id=='shield' or id=='mentions'
    W.pageToggle:SetShown(feature);W.pageIconButton:SetShown(feature)
    if feature then
        local configured=id=='capture' and ns.ChatCapture.db.enabled or id=='shield' and ns.DB.shield.enabled or id=='mentions' and ns.DB.alertsEnabled~=false
        local name=({capture='Capture',shield='Shield',mentions='Alerts'})[id]
        W.pageToggle:SetText((configured and 'Pause ' or id=='capture' and 'Start ' or 'Enable ')..name)
        V.SetIcon(W.pageIcon,NavID(id));V.FeatureState(W.pageIconButton,W.FeatureEnabled(id))
    end
end
function W.HidePages()
    W.switching=true;V.CloseMenus()
    for _,page in pairs(W.pages) do page.nameRevealed=nil;page.original=false;page:Hide() end
    if W.pageToggle then W.pageToggle:Hide();W.pageIconButton:Hide() end
    if W.mounted then W.mounted:Hide();W.mounted=nil end
    W.legacyHost:Hide();W.switching=false
end
function W.Fit()
    local automatic,screen=T.WindowScale(W.width+2*W.leftOverhang,W.height+2*W.bottomOverhang)
    -- Keep a saved preference when a smaller display temporarily limits it.
    -- A page opening must not first apply automatic scale and then custom scale.
    local requested=ns.DB.workspaceScale
    local scale=requested and math.min(requested,screen) or automatic
    local current=W.window.GetScale and W.window:GetScale() or W.appliedScale
    if not current or math.abs(current-scale)>.0001 then W.window:SetScale(scale) end
    W.appliedScale=scale
    if W.scalePage and W.scalePage:IsShown() and W.scalePage.SyncDisplay then W.scalePage:SyncDisplay() end
    return scale
end
local Fit=W.Fit
function W.SetScale(percent)
    if not ns.Membership.Allowed() then return false end
    if percent~=nil then percent=tonumber(percent);if not percent or percent~=percent or percent<50 or percent>150 then return false,'Enter a percentage from 50 to 150.' end end
    ns.DB.workspaceScale=percent and math.floor(percent+.5)/100 or nil
    W.Ensure();Fit();return true
end
local builders={}
builders.modules=function() return ns.ModuleUI.Build(W.canvas) end
builders.performance=function() return ns.ModuleUI.BuildPerformance(W.canvas) end
builders.relay=function() return ns.RelayUI.Build(W.canvas) end
builders.recording=function() return ns.RecordingUI.Build(W.canvas) end
builders.intel=function() return ns.WardenUI.Build(W.canvas,'intel') end
builders.chronicle=function() return ns.WardenUI.Build(W.canvas,'chronicle') end
local Bookmark
function W.Open(id)
    if not ns.DB or not ns.Membership.Allowed() then ns.Print(ns.Membership.Status());return false end
    if id=='alerts' then id='mentions' end
    id=({warden='overview',commandwarden='overview',chatwarden='messages',signalwarden='mentions',shieldwarden='shield',intelwarden='intel',chroniclewarden='chronicle',relaywarden='relay'})[id] or id
    id=labels[id] and id or 'overview';local requested=id;id=ns.Modules.Route(id)
    if id=='recording' then ns.Modules.LoadHistory() end
    W.Ensure();W.HidePages();W.current=id;W.Header(id);Fit();W.window:Show()
    ShowStatus('History stays local. Report delivery starts only after Submit.')
    if builders[id] then W.pages[id]=W.pages[id] or builders[id]();if id=='recording' or id=='updates' then W.WrapRelayLegacy(W.pages[id]) end;W.pages[id]:Show();if W.pages[id].Activate then W.pages[id]:Activate() end
    elseif id=='reports' then
        W.pending='reports';original.OpenExport('reports',nil,nil,'review');W.pending=nil
    end
    W.Refresh();T.FocusWindow(W.window)
    if id~='updates' and ns.Chronicle then ns.Chronicle.MaybePrompt() end
    if id~=requested then ShowStatus('That module is disabled. Your saved data is kept. Choose it in CommandWarden > Modules to use this destination.');return false end
    return true,W.pages[id]
end
-- Every deep link must use this contract; a redirect is not a constructed page.
function W.Destination(id)
    local opened,page=W.Open(id);if not opened or W.current~=id or not page then return nil end;return page
end
function W.CommandTabs(current)
    local tabs={{'overview','Overview',function() W.Open('overview') end,210},
        {'modules','Modules',function() W.Open('modules') end,210},
        {'performance','Performance',function() W.Open('performance') end,210},
        {'settings','Settings',function() W.Open('settings') end,210}}
    if ns.WardenSimLab then tabs[#tabs+1]={'hephaestus','Hephaestus Lab',function() ns.WardenSimLab.Open() end,210} end
    W.Tabs(tabs,current)
end
function W.LayoutNavigation()
    if not W.navigation then return end
    local n=0
    for _,d in ipairs(definitions) do
        local b=W.navigation[d[1]]
        if b then
            local visible=ns.Modules.Route(d[1])==d[1]
            b:SetShown(visible)
            if visible then n=n+1;b:ClearAllPoints();b:SetPoint('TOPLEFT',8,-12-(n-1)*64) end
        end
    end
    if W.profile then W.profile:ClearAllPoints();W.profile:SetPoint('TOPLEFT',10,-26-n*64) end
end
function W.ModulesChanged()
    if not W.window then return end
    if InCombatLockdown and InCombatLockdown() then W.moduleLayoutPending=true;ShowStatus('Module processing changed. Navigation and display cleanup apply after combat. Saved data is kept.');return end
    W.moduleLayoutPending=nil;W.LayoutNavigation()
    local destination=ns.Modules.Route(W.current or 'overview')
    if destination~=W.current then W.Open(destination) else W.Queue() end
end
local function Page()
    local f=CreateFrame('Frame',nil,W.canvas);f:SetAllPoints();f:Hide();return f
end
function W.UpdateTabs(current)
    W.Tabs({{'notes','Patch Notes',function() ns.OpenUpdates() end},
        {'tour','Launch Tour',function() W.Open('updates');W.pages.updates:SetView('tour') end},
        {'guide','User Guide',function() W.Guide('basics') end}},current)
end
function W.Guide(topic)
    if not ns.DB or not ns.Membership.Allowed() then return end
    W.Ensure();W.HidePages();W.current='updates';W.Header('updates')
    W.heading:SetText('RelayWarden')
    W.UpdateTabs('guide')
    local p=W.pages.guide
    if not p then
        p=Page();W.pages.guide=p
        p.topics=V.Panel(p,0,0,260,676,'dark');V.Text(p.topics,'Topics',18,-20,210,18,V.gold)
        p.reader=V.Panel(p,276,0,864,676,'paper');p.title=V.Text(p.reader,'',24,-20,802,23,{.31,.15,.055})
        p.document,p.scroll=V.Document(p.reader,18,-66,812,590)
        p.topicList=V.ScrollingList(p.topics,14,-60,212,596,52,function(parent)
            local row=V.Button(parent,'',0,0,212,46,function() end,'neutral');row.ActiveArt=V.Nine(row,'selected')
            row:SetScript('OnClick',function(self) W.Guide(self.topic.id) end);return row
        end,function(row,item)
            row.topic=item;row:SetText(item.title);row.Caption:SetWidth(row:GetWidth()-24);row.ActiveArt:SetShown(p.topic==item.id)
        end)
    end
    W.WrapRelayLegacy(p)
    local page=ns.TutorialPage(topic);p.topic=page.id;p.title:SetText(page.title)
    p.document:SetBlocks(T.ParagraphBlocks(page.text),page.text);p.scroll:SetVerticalScroll(0);p.topicList:SetItems(ns.TutorialTopics(),true)
    p:Show();Fit();W.window:Show();T.FocusWindow(W.window)
end
local function ListPage(category,title,items,detail,actions)
    title=title:gsub('(%a)([%w\']*)',function(first,rest) return first:upper()..rest end)
    local p=Page();p.category=category;p.mode='all';p.query='';p.page=1;p.selected=nil;p.channel='all';p.period=0
    p.search=V.Edit(p,0,0,420,36,'Search '..title:lower()..'...',function(text) p.query=ns.Engine.Lower(text);p.page=1;if p.Refresh then p:Refresh() end end)
    local channels={{'all','All channels'},{'whispers','Whispers'},{'guild','Guild / officer'},{'party','Party / instance'},{'raid','Raid'},{'general','General'},{'trade','Trade'},{'lfg','LookingForGroup'},{'say','Say'},{'yell','Yell'},{'other','Other'}}
    p.channelMenu=V.Dropdown(p,436,0,216,channels,function() return p.channel end,function(value) p.channel=value;p.page=1;p:Refresh() end)
    p.timeMenu=V.Dropdown(p,666,0,166,{{0,'All time'},{3600,'Last hour'},{86400,'Today'}},function() return p.period end,function(value) p.period=value;p:Refresh() end)
    p.unreadOnly=V.Check(p,'Unread only',850,4,false,function(v) p.onlyUnread=v;p.page=1;p:Refresh() end,150)
    p.list=V.Panel(p,0,-52,300,576,'dark');p.listTitle=V.Text(p.list,'',14,-12,270,12,V.gold)
    p.empty=V.Text(p.list,'No entries yet.',18,-72,264,13,V.muted)
    p.listView=V.ScrollingList(p.list,8,-37,260,523,76,function(parent) return V.Row(parent,0,function(item)
        p.selected=item;p.original=false;p.reasons=false;p.nameRevealed=nil
        if item and item.activityID then A.Mark(item.activityID,category) elseif item and item.categories then A.Mark(item.id,category) end
        p:Refresh()
    end) end,function(row,item)
        row.entry=item
        row.title:SetWidth(row:GetWidth()-72);row.preview:SetWidth(row:GetWidth()-72);row.meta:SetWidth(row:GetWidth()-72)
        row.title:SetWidth(row:GetWidth()-88)
        row.title:SetText(item.title and Plain(item.title) or W.NameText(item,row.title,p.nameRevealed==item.id))
        if not row.nameButton then
            row.nameButton=CreateFrame('Button',nil,row);row.nameButton:SetPoint('TOPLEFT',56,-8);row.nameButton:SetHeight(22)
            row.nameButton:SetScript('OnClick',function(_,button)
                local current=row.entry;if not current then return end
                local _,hidden=W.NameText(current,row.title,p.nameRevealed==current.id)
                if ControlClick(button) and (hidden or p.nameRevealed==current.id) then
                    p.selected=current;p.original=false;p.nameRevealed=p.nameRevealed~=current.id and current.id or nil
                    if current.categories then A.Mark(current.id,category) end;p:Refresh()
                else row:GetScript('OnClick')(row) end
            end)
            T.Tooltip(row.nameButton,'Player Name','Ctrl + left-click a covered name to reveal it. Repeat to cover it.')
        end
        row.nameButton:SetWidth(row:GetWidth()-88);row.nameButton:SetShown(not item.title)
        row.preview:SetText(Plain(A.EventLabel(item) or (item.preview or item.original or ''):gsub('[\r\n]',' ')))
        row.meta:SetText(Plain(Channel(item)..'  |  '..Stamp(item)))
        V.SetIcon(row.icon,Icon(item))
        row:Select(p.selected and p.selected.id==item.id)
        row.unread:SetShown(A.EntryUnread(item,category) or item.unread==true)
    end)
    p.rows=p.listView.rows
    p.center=V.Panel(p,312,-52,548,576,'dark');p.senderIcon=V.Icon(p.center,'messages',48,18,-17)
    p.sender=V.Text(p.center,'Select an entry',80,-20,448,19,V.gold);p.subtitle=V.Text(p.center,'',80,-49,440,12,V.muted)
    p.sender:SetWordWrap(false)
    p.nameButton=CreateFrame('Button',nil,p.center);p.nameButton:SetPoint('TOPLEFT',80,-17);p.nameButton:SetSize(448,30)
    local function ToggleName(_,button)
        if p.selected and ControlClick(button) then p.nameRevealed=p.nameRevealed~=p.selected.id and p.selected.id or nil;p:Refresh() end
    end
    p.nameButton:SetScript('OnClick',ToggleName)
    T.Tooltip(p.nameButton,'Covered Player Name','Ctrl + left-click to reveal or cover this name. Message originals remain controlled separately.')
    p.documentPanel=V.Panel(p.center,12,-82,524,476,'paper')
    p.documentEmpty=V.Nine(p.documentPanel,'minimal');p.documentEmpty:SetShown(false)
    p.document,p.scroll=V.Document(p.documentPanel,16,-18,478,438)
    p.right=CreateFrame('Frame',nil,p);p.right:SetPoint('TOPLEFT',872,-52);p.right:SetSize(268,576)
    p.detailsBox=V.Panel(p.right,0,0,268,196,'dark');V.Text(p.detailsBox,'Details',18,-18,230,16,V.gold)
    p.info=V.Text(p.detailsBox,'',18,-48,230,12);p.info:SetHeight(130);p.actions={}
    p.detailsNameButton=CreateFrame('Button',nil,p.detailsBox);p.detailsNameButton:SetPoint('TOPLEFT',18,-46);p.detailsNameButton:SetSize(230,26)
    p.detailsNameButton:SetScript('OnClick',ToggleName)
    T.Tooltip(p.detailsNameButton,'Covered Player Name','Ctrl + left-click to reveal or cover this name.')
    p.actionsBox=V.Panel(p.right,0,-212,268,364,'dark');V.Text(p.actionsBox,'Actions',18,-18,230,16,V.gold)
    p.actionsTop=54
    p.pager=V.Text(p,'',12,-650,280,12,V.muted)
    p.listView.Changed=function(first,last,total) p.pager:SetText(total>0 and (first..'-'..last..' of '..total..'  |  Scroll to browse') or 'No entries') end
    if category then p.markAll=V.Button(p,'Mark all read',880,-640,260,31,function() A.MarkCategory(category);p:Refresh() end,'neutral') end
    function p:AddAction(label,fn,kind)
        local b=V.Button(self.actionsBox,label,14,-self.actionsTop-#self.actions*37,240,32,function() fn(self.selected,self) end,kind)
        self.actions[#self.actions+1]=b;return b
    end
    if actions then actions(p) end
    function p:Refresh()
        local top=self.contentTop or 52
        local height=W.canvas:GetHeight()-top-48
        self.list:SetHeight(height);self.center:SetHeight(height);self.right:SetHeight(height);self.actionsBox:SetHeight(height-212)
        self.documentPanel:SetHeight(height-100);self.scroll:SetHeight(height-138)
        self.pager:ClearAllPoints();self.pager:SetPoint('TOPLEFT',12,-W.canvas:GetHeight()+26)
        if self.markAll then self.markAll:ClearAllPoints();self.markAll:SetPoint('TOPLEFT',880,-W.canvas:GetHeight()+36) end
        local entries=items(self);local visible={};local now=ns.SafeCall(time) or 0
        for _,item in ipairs(entries) do
            local scope=ns.Mentions.Channel(item.event or '',item.channel)
            local haystack=ns.Engine.Lower((item.sender or '')..' '..(item.preview or item.original or '')..' '..(item.title or '')..' '..(item.note or ''))
            local unread=A.EntryUnread(item,category) or item.unread==true
            if (self.channel=='all' or scope==self.channel) and (self.query=='' or haystack:find(self.query,1,true))
                and (not self.onlyUnread or unread) and (self.period==0 or item.timestamp and now-item.timestamp<=self.period) then visible[#visible+1]=item end
        end
        self.visible=visible
        self.listTitle:SetText(title..'  |  '..#visible);self.empty:SetShown(#visible==0)
        self.empty:SetText(#entries>0 and 'No matching entries\nChange the search or filters.' or category=='shield' and 'No Shield activity yet\nProtected contact appears here.' or category=='alerts' and 'No alerts yet\nMentions and Wanted encounters appear here.' or 'Nothing to review yet\nRecorded activity will appear here.')
        local present=not self.selected
        for _,item in ipairs(visible) do if self.selected and item.id==self.selected.id then self.selected=item;present=true end end
        if not present then self.selected=nil;self.original=false;self.nameRevealed=nil end
        local filter=self.mode..'\031'..self.query..'\031'..self.channel..'\031'..self.period..tostring(self.onlyUnread)
        self.listView:Resize(self.list:GetWidth()-40,self.list:GetHeight()-53)
        self.listView:SetItems(visible,filter==self.filterKey);self.filterKey=filter
        local item=self.selected
        local hasItem=item~=nil
        if self.paperShown~=hasItem then
            self.paperShown=hasItem;self.documentPanel.ArtFrame:SetShown(hasItem);self.documentPanel.ArtBacking:SetShown(hasItem);self.documentEmpty:SetShown(not hasItem)
            self.document:SetStyle(hasItem and 'paper' or 'dark')
        end
        V.SetIcon(self.senderIcon,item and Icon(item) or category=='alerts' and 'mentions' or category)
        local name,covered=W.NameText(item,self.sender,item and self.nameRevealed==item.id)
        self.sender:SetText(item and (item.title and Plain(item.title) or name) or 'Select an Entry')
        self.nameButton:SetShown(item~=nil and not item.title and (covered or self.nameRevealed==item.id))
        self.detailsNameButton:SetShown(item~=nil and not item.title and (covered or self.nameRevealed==item.id))
        self.subtitle:SetText(item and Plain(Channel(item)..'  |  '..Stamp(item)) or 'Your local records appear here.')
        local sections,info=detail(item,self)
        sections=sections or {'Select an entry on the left.'}
        if type(sections[1])=='table' then self.document:SetBlocks(sections)
        else
            local blocks={}
            for i,text in ipairs(sections) do
                local trimmed=text:match('^%s*(.-)%s*$')
                local kind=text:match('^\n.+\n$') and 'heading' or i==1 and #text<70 and not text:match('^%[') and 'title' or 'body'
                blocks[#blocks+1]={text=kind=='heading' and trimmed or text,kind=kind}
            end
            self.document:SetBlocks(blocks,table.concat(sections,'\n'))
        end
        local infoText=Plain(info or (not item and 'Choose an entry to see its channel, time and Warden action. Originals stay behind deliberate reveal controls.' or ''))
        if item and info and info:match('^Player: ') then
            local stop=info:find('\n',1,true) or #info+1
            infoText='Player: '..W.NameText(item,self.info,self.nameRevealed==item.id)..Plain(info:sub(stop))
        end
        self.info:SetText(infoText)
        for _,b in ipairs(self.actions) do b:SetEnabled(item~=nil) end
        if self.AfterRefresh then self:AfterRefresh() end
        local index=0
        for _,button in ipairs(self.actions) do if button:IsShown() then
            button:ClearAllPoints();button:SetPoint('TOPLEFT',14,-self.actionsTop-index*37);index=index+1
        end end
    end
    return p
end
builders.shield=function()
    local p=ListPage('shield','Shield',function(self)
        if self.mode=='allowed' then local out={};for key,name in pairs(ns.DB.shield.allowed) do out[#out+1]={id=key,sender=name,preview='Allowed player',allowed=true} end;table.sort(out,function(a,b) return a.id<b.id end);return out
        elseif self.mode=='active' then local out={};for _,e in ipairs(ns.Shield.List()) do out[#out+1]={id=e.key,sender=e.name,preview=e.reason or 'Manual shield',contact=e} end;return out end
        return A.List('shield')
    end,function(item)
        if not item then return {'Contact Protection','Select an alert or player. Shields apply only to your client; allowed players bypass Shield.'} end
        local active=ns.Shield.HasShield(item.sender)
        local paused=ns.Spam.PauseRemaining(item.sender)>0
        local key=ns.Shield.Key(item.sender);local allowed=key and ns.DB.shield.allowed[key]~=nil
        local lines={{text=active and 'Player shielded' or allowed and 'Allowed player' or 'Recent contact alert',kind='title',tone=(active or allowed) and 'success' or 'warning'},
            {text=Stamp(item),kind='meta'},{text='Contact record',kind='heading'},{text=item.preview or '',kind='body'}}
        if item.contact then lines[#lines+1]={text=item.contact.session and 'Until logout / reload' or item.contact.expires==0 and 'Until you remove it' or 'Expires: '..(ns.SafeCall(date,'%Y-%m-%d %H:%M',item.contact.expires) or ''),kind='meta'} end
        local entry=item.reviewID and ns.Review.Get(item.reviewID)
        if entry then
            lines[#lines+1]={text=entry.spamReason and 'Spam Message' or 'Shielded Message',kind='heading'}
            lines[#lines+1]={text=ns.Review.DisplayOriginal(entry),kind='quote'}
            lines[#lines+1]={text=entry.spamReason or entry.shieldReason or 'Hidden by contact protection.',kind='meta'}
        end
        return lines,'Player: '..A.DisplayName(item.sender)..'\n\nStatus: '..(active and 'Shielded' or paused and 'Chat paused' or allowed and 'Allowed' or 'Not shielded')
    end,function(page)
        page.allow=page:AddAction('Allow player',function(item) local _,message=ns.Shield.Allow(item.sender);ShowStatus(message or 'Player allowed.');W.Queue() end)
        page.add=page:AddAction('Shield for 15 minutes',function(item) local _,message=ns.Shield.Add(item.sender,900,'Manual shield');ShowStatus(message or 'Shield added.');W.Queue() end)
        page.remove=page:AddAction('Remove shield',function(item,self)
            if not item then return end
            local _,message=ns.Shield.Remove(item.sender)
            if self.mode=='active' then self.selected=nil end
            self:Refresh();ShowStatus(message);W.Queue()
        end,'danger')
        page.unallow=page:AddAction('Stop allowing player',function(item) ns.Shield.Unallow(item.sender);ShowStatus('Player removed from Allowed.');W.Queue() end,'neutral')
        page:AddAction('Copy player details',function(item) W.Copy(A.DisplayName(item.sender)..'\n'..(item.preview or ''),'Copy Shield details') end)
    end)
    p.mode='alerts'
    function p:AfterRefresh()
        local item=self.selected;local name=item and item.sender;local key=name and ns.Shield.Key(name)
        local allowed=key and ns.DB.shield.allowed[key]~=nil
        local shielded=name and ns.Shield.HasShield(name)
        local paused=name and ns.Spam.PauseRemaining(name)>0
        self.allow:SetShown(key~=nil and not allowed)
        self.add:SetShown(key~=nil and not allowed and not shielded)
        self.remove:SetShown(key~=nil and (shielded or paused));self.remove:SetText(paused and not shielded and 'End chat pause' or 'Remove shield')
        self.unallow:SetShown(key~=nil and allowed==true)
    end
    function p:Activate()
        local function View(value) self.mode=value;self.selected=nil;self:Activate();self:Refresh() end
        W.Tabs({{'alerts','Recent alerts',function() View('alerts') end},{'active','Active shields',function() View('active') end},
            {'allowed','Allowed players',function() View('allowed') end},{'add','Add player',function() W.ShieldEditor() end},
            {'export','Export shields',function() ns.OpenShieldExport() end},{'settings','Settings',function() W.SettingsSub('shield') end}},self.mode)
    end
    return p
end
local function WantedDetail(item)
    if not ns.Wanted.ValidRecord(item.wanted) then return {'Wanted alert','This saved alert is unavailable.'} end
            local w=item.wanted
            local blocks={{text=w.kind=='encounter' and 'Wanted Player Encountered' or 'Wanted Player Mentioned',kind='title'},
                {text=Stamp(item)..(w.zone and '  /  Your zone: '..w.zone or ''),kind='meta'},
                {text=w.kind=='encounter' and ('Observed through '..w.via..'.') or ('Mentioned in chat by '..A.DisplayName(w.speaker)..'.'),kind='body'},
                {text='Olympus-listed bounty',kind='heading'},{text=w.bounty..' points',kind='quote'},
                {text='Listed kills: '..w.kills..'  |  Bounty cycle: '..w.cycle,kind='meta'},
                {text='Saved at the time of this alert. Olympus manages the Wanted board and its updates.',kind='body'}}
            if w.kind=='mention' then blocks[#blocks+1]={text='A chat mention does not establish this player\'s location.',kind='body'} end
            return blocks,'Player: '..A.DisplayName(w.name)..'\n\nSource: '..w.via..'\n\n'..Stamp(item)
end
builders.overview=function() return ns.WardenHomeUI.Build(W.canvas) end
builders.activity=function()
    local p=ListPage(nil,'Recent Activity',function() return A.List() end,function(item,page)
        if item and item.wanted then return WantedDetail(item) end
        if not item then return {{text='Your recent activity',kind='title'},
            {text='Choose an entry to review what Warden observed and the action it took. Hidden originals stay behind Show original.',kind='body'},
            {text='Looking for adventures or players?',kind='heading'},{text='Open ChronicleWarden for your recorded history or IntelWarden for player dossiers.',kind='body'}} end
        local categories={};for _,key in ipairs({'messages','mentions','shield','activity'}) do if item.categories[key] then categories[#categories+1]=({messages='Messages',mentions='Alerts',shield='Shield',activity='Activity'})[key] end end
        local entry=item.reviewID and ns.Review.Get(item.reviewID)
        return {{text='Recent Activity',kind='title'},{text=Channel(item)..'  /  '..Stamp(item),kind='meta'},
            {text=A.EventLabel(item) or 'Activity',kind='heading'},
            {text=page.original and entry and (ns.Review.IsNameRecord(entry) and 'Original Name' or 'Original Message') or 'Safe Preview',kind='heading'},
            {text=page.original and entry and ns.Review.DisplayOriginal(entry) or entry and entry.action=='Hidden' and 'Message content is hidden. Choose Show Original to read it.' or entry and A.SafePreview(entry) or item.preview or '',kind='quote'},
            {text='Activity Categories',kind='heading'},{text=table.concat(categories,', '),kind='accent'}},
            'Player: '..A.DisplayName(item.sender)..'\n\nChannel: '..Channel(item)..'\n\n'..Stamp(item)
    end,function(page)
        page.reveal=page:AddAction('Show original',function(_,self) self.original=not self.original;self:Refresh() end)
        page.openActivity=page:AddAction('Open activity',function(item) local target=W.Destination(item.categories.mentions and 'mentions' or item.categories.shield and 'shield' or item.categories.activity and 'activity' or 'messages');if not target then return end;target.selected=item;if item.categories.activity then target.original=true end;A.Mark(item.id,W.current=='activity' and 'activity' or W.current);target:Refresh() end)
        page.copy=page:AddAction('Copy message',function(item) W.Copy(item.preview,'Copy activity') end)
        page.bookmark=page:AddAction('Bookmark message',Bookmark)
        page.addShield=page:AddAction('Add to Shield',function(item) W.ShieldEditor(item.sender) end)
        page.openOlympus=page:AddAction('Open Olympus',function() local _,message=ns.OlympusIntegration.Open();if message then ShowStatus(message) end end,'neutral')
    end)
    p.markAll=V.Button(p,'Mark all read',880,-640,260,31,function() A.MarkCategory('messages');A.MarkCategory('alerts');A.MarkCategory('shield');p:Refresh() end,'neutral')
    p.unreadOnly:Hide();p.pageSize=6;p.contentTop=149
    p.search:GetParent():ClearAllPoints();p.search:GetParent():SetPoint('TOPLEFT',0,-97)
    p.channelMenu:ClearAllPoints();p.channelMenu:SetPoint('TOPLEFT',436,-97)
    p.timeMenu:ClearAllPoints();p.timeMenu:SetPoint('TOPLEFT',666,-97)
    for _,spec in ipairs({{p.list,0},{p.center,312},{p.right,872}}) do spec[1]:ClearAllPoints();spec[1]:SetPoint('TOPLEFT',spec[2],-149);spec[1]:SetHeight(444) end
    p.documentPanel:SetHeight(344);p.scroll:SetHeight(306)
    local specs={{'filtering','ChatWarden'},{'shield','ShieldWarden'},{'capture','Chat Capture'},{'mentions','SignalWarden'}}
    p.cards={}
    for i,spec in ipairs(specs) do
        local key=spec[1];local card=V.Panel(p,(i-1)*288,0,276,82,'dark')
        card.feature=key;card.toggle=V.IconButton(card,featureIcons[key],52,10,-14,function() W.ToggleFeature(key) end,spec[2],'Click this icon to enable or pause '..spec[2]..'.')
        card.title=V.Text(card,spec[2],70,-12,190,17,V.gold);card.title:SetHeight(25);card.title:SetWordWrap(false);card.title:SetJustifyV('MIDDLE')
        card.detail=V.Text(card,'',70,-43,190,11,V.muted);card.detail:SetHeight(24);card.detail:SetWordWrap(false);card.detail:SetJustifyV('MIDDLE')
        p.cards[i]=card
    end
    function p:AfterRefresh()
        for _,card in ipairs(self.cards) do FeatureIcon(card.toggle,card.feature) end
        local entry=self.selected and self.selected.reviewID and ns.Review.Get(self.selected.reviewID)
        self.reveal:SetEnabled(entry~=nil);self.reveal:SetShown(entry~=nil);self.reveal:SetText(self.original and 'Hide original' or 'Show original')
        local wanted=self.selected and self.selected.categories and self.selected.categories.wanted
        self.openOlympus:SetShown(wanted==true);self.bookmark:SetShown(not wanted);self.addShield:SetShown(not wanted)
        self.openActivity:SetShown(not wanted)
        self.copy:SetText(wanted and 'Copy alert' or 'Copy message')
        self.cards[1].detail:SetText(W.FeatureEnabled('filtering') and ('ON • '..T.Label({{'aggressive','Strict'},{'balanced','Balanced'},{'strict','Mild'}},ns.DB.preset)..(ns.DB.gommage and ' + Gommage' or '')) or 'OFF • Paused')
        self.cards[2].detail:SetText((ns.Shield.Active() and 'ON' or 'OFF')..' • '..#ns.Shield.List()..' shielded')
        self.cards[3].detail:SetText((W.FeatureEnabled('capture') and 'ON' or 'OFF')..' • '..#ns.ChatCapture.db.entries..' lines')
        self.cards[4].detail:SetText((W.FeatureEnabled('mentions') and 'ON' or 'OFF')..' • '..A.Unread('alerts')..' unread')
    end
    function p:Activate()
        W.CommandTabs('overview')
    end
    return p
end
builders.packs=function()
    local p=ListPage(nil,'Installed packs',function()
        local out={};for _,pack in ipairs(ns.RulePacks.List()) do out[#out+1]={id=pack.id,title=pack.title,
            preview=pack.updateRequired and ('v'..pack.version..' | Update Required')
                or (pack.error and 'Not loaded' or pack.stock and 'Stock' or 'v'..tostring(pack.version or '?'))..'  |  '..(pack.enabled and 'On' or 'Off'),pack=pack} end;return out
    end,function(item)
        if not item then return {'Rule Packs','Olympus Protection and King Protection are included. Optional categories are verified author-signed imports.','Importing the addon does not automatically update installed packs.'} end
        local p=item.pack
        if p.error then return {p.title,'This saved import could not be verified.',p.error,'Import a valid author-signed copy to restore this category.'},'Status: Not loaded\n\nNo rules from this import are active.' end
        if p.updateRequired then return {p.title,'Update Required — v'..p.version,
            'This pack and its Gommage masks are paused until a compatible signed update is imported.',
            'Your signed import, enabled choice, sensitivity and history are kept. Use Get packs link, then Import signed pack.'},
            'Status: Update Required\n\nSaved choice: '..(p.enabled and 'On' or 'Off')..'\n\nCurrent rules: Inactive\n\nGommage masks: Inactive' end
        return {p.title,'Version '..p.version..'  |  '..(p.stock and 'Included with ChatWarden' or 'Author: '..(p.author or 'Unknown')),
            p.description or '',p.rules..' scored phrases\n'..p.gommage..' Gommage terms\n'..p.replacements..' replacements',
            p.stock and 'Stock reference matches use context. Gommage terms do not add scores.' or 'Verified author key: '..(p.keyID or '')},
            'Status: '..(p.enabled and 'Enabled' or 'Off')..'\n\nScored phrases: '..p.rules..'\n\nGommage: '..p.gommage..'\n\nReplacements: '..p.replacements
    end,function(page)
        page.toggle=page:AddAction('Toggle enabled',function(item) ns.SetPackPreset(item.id,item.pack.enabled and 'off' or 'default');W.Queue() end)
        page.sensitivity=page:AddAction('Change sensitivity',function(item) W.PackSensitivity(item.id) end)
        page.export=page:AddAction('Export signed pack',function(item) local text,err=ns.RulePacks.Export(item.id);if text then W.Copy(text,'Copy signed pack',true) else ShowStatus(err) end end)
        page.remove=page:AddAction('Remove imported pack',function(item,self)
            if self.removeArmed~=item.id then self.removeArmed=item.id;ShowStatus('Click Remove imported pack again to confirm.');return end
            local _,err=ns.RulePacks.Remove(item.id);self.removeArmed=nil;ShowStatus(err or 'Imported pack removed.');self:Refresh()
        end,'danger')
    end)
    p.unreadOnly:Hide();p.channelMenu:Hide();p.timeMenu:Hide()
    function p:Activate() W.Tabs({{'installed','Installed packs',function() end},{'import','Import signed pack',function() W.pending='packs';original.OpenPacks('import');W.pending=nil end},
        {'download','Get packs link',function() W.Copy(ns.PROJECT_URL..'/tree/main/rule-packs','Optional rule packs',true) end}},'installed') end
    function p:AfterRefresh()
        local selected=self.selected and self.selected.pack;local valid=selected and not selected.error
        self.toggle:SetEnabled(valid~=nil and valid~=false);self.sensitivity:SetEnabled(valid~=nil and valid~=false)
        self.export:SetEnabled(valid and not selected.stock or false);self.remove:SetEnabled(valid and not selected.stock or false)
    end
    return p
end
builders.rules=function()
    local p=ListPage(nil,'Personal rules',function(self)
        local out={}
        if self.mode=='exceptions' then for i,text in ipairs(ns.DB.exceptions) do out[#out+1]={id=i,title=text,preview='Keep matching text visible',exception=text} end
        else for _,rule in ipairs(ns.Personal.rules) do if self.mode~='replacements' or rule.action=='Replaced' then out[#out+1]={id=rule.id,title=rule.phrase,preview=rule.action..'  |  '..(rule.enabled and 'On' or 'Off'),rule=rule} end end end
        return out
    end,function(item)
        if not item then return {'My Rules','Personal rules apply to new matching text. Saving a report does not create a rule automatically.','Use exact phrases and choose Keep visible, Warn, Redact, Hide or Replace.'} end
        if item.exception then return {item.exception,'Personal filtering exception'},'Type: Exception\n\nExact phrase: '..item.exception end
        return {item.rule.phrase,'Action: '..item.rule.action,'Status: '..(item.rule.enabled and 'On' or 'Off'),item.rule.replacement or '', 'Applies to new chat and supported text; existing lines are not rewritten.'},'Type: Personal phrase\n\nAction: '..item.rule.action..'\n\nStatus: '..(item.rule.enabled and 'On' or 'Off')
    end,function(page)
        page.edit=page:AddAction('Edit rule',function(item) if item.rule then W.RuleEditor(item.rule) else W.ExceptionEditor(item.exception) end end)
        page.toggle=page:AddAction('Enable / disable',function(item) ns.Personal.ChangeRule(item.rule.id,not item.rule.enabled);page:Refresh() end)
        page:AddAction('Delete entry',function(item,self)
            if self.deleteArmed~=item.id then self.deleteArmed=item.id;ShowStatus('Click Delete entry again to confirm.');return end
            if item.rule then ns.Personal.ChangeRule(item.rule.id,nil,true)
            else local list={};for _,text in ipairs(ns.DB.exceptions) do if text~=item.exception then list[#list+1]=text end end;ns.SetExceptions(list) end
            self.selected=nil;self.deleteArmed=nil;self:Refresh()
        end,'danger')
    end)
    p.mode='rules';p.unreadOnly:Hide();p.channelMenu:Hide();p.timeMenu:Hide()
    function p:Activate()
        local function View(mode) self.mode=mode;self.selected=nil;self:Activate();self:Refresh() end
        W.Tabs({{'rules','My rules',function() View('rules') end},{'exceptions','Exceptions',function() View('exceptions') end},
            {'replacements','Replacements',function() View('replacements') end},{'new','New rule',function() if self.mode=='exceptions' then W.ExceptionEditor() else W.RuleEditor() end end}},self.mode)
    end
    function p:AfterRefresh() self.toggle:SetEnabled(self.selected~=nil and self.selected.rule~=nil) end
    return p
end
local function FormPage(title,description)
    W.Ensure();W.HidePages()
    W.Header(W.current or 'overview')
    local p=Page();W.pages.form=p;p:Show();W.Tabs({{'back','Back',function() W.Open(W.current or 'overview') end}},nil)
    V.Text(p,title,24,-18,1050,23,V.gold);V.Text(p,description,24,-58,1050,13,V.muted)
    p.status=V.Text(p,'',24,-561,1040,13,V.gold);return p
end
function W.WantedSettings()
    if not ns.Membership.Allowed() then return end
    W.current='mentions'
    local p=FormPage('Olympus Wanted alerts','Encounter alerts appear in Alerts and Overview. Chat icons show hover details without sending notifications.')
    local panel=V.Panel(p,18,-96,1104,408,'dark');local wanted=ns.Wanted
    local controls={{'enabled','Enable Wanted alerts',24,24},{'encounters','Target and mouseover encounters',24,82},
        {'chatIndicators','Show Wanted icons in visible chat',24,140},{'badges','Unread badge for Wanted alerts',24,198},
        {'sound','Play a sound',574,24},{'toast','Show a toast notification',574,82}}
    for _,spec in ipairs(controls) do
        local key=spec[1];V.Check(panel,spec[2],spec[3],-spec[4],wanted.db[key],function(value)
            wanted.Set(key,value);p.status:SetText(wanted.Status())
        end,490)
    end
    V.Text(panel,'Per-player cooldown',574,-157,480,14,V.gold)
    V.Dropdown(panel,574,-185,490,{{30,'30 seconds'},{60,'1 minute'},{300,'5 minutes (default)'},{900,'15 minutes'},{1800,'30 minutes'}},
        function() return wanted.db.cooldown end,function(value) wanted.Set('cooldown',value);p.status:SetText(wanted.Status()) end)
    V.Text(panel,'Encounters match an attackable player\'s GUID. Chat icons require the exact full name and do not establish proximity. They never trigger sounds, toasts or feed entries.',24,-276,1034,14,V.muted)
    V.Text(panel,'Sound and toast start off. Bounty details are saved with each alert; open Olympus to review the board.',24,-342,1034,14,V.muted)
    p.status:SetText(wanted.Status())
    W.AlertTabs('wanted-settings')
end
function W.ScaleSettings()
    if not ns.Membership.Allowed() then return end
    W.Open('settings')
    if W.scalePage and W.scalePage.ResetDraft then
        W.HidePages();W.pages.form=W.scalePage;W.scalePage:Show();W.Tabs({{'back','Back',function() W.Open('settings') end}},nil);W.scalePage:ResetDraft();return
    end
    local p=FormPage('Window size','Choose the size that feels comfortable. This setting is saved for this account.')
    local panel=V.Panel(p,18,-101,1104,370,'dark')
    local current=math.floor((ns.DB.workspaceScale or Fit())*100+.5);local syncing=false;local dirty=false
    V.Text(panel,'Window scale',24,-26,800,18,V.gold)
    local valueLabel=V.Text(panel,'',24,-64,1000,14)
    local slider=CreateFrame('Slider',nil,panel);slider:SetPoint('TOPLEFT',30,-126);slider:SetSize(1020,30)
    slider:SetOrientation('HORIZONTAL');slider:SetMinMaxValues(50,150);slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    local track=V.Texture(slider,'Controls',{47,375,268,391},'BACKGROUND')
    track:SetPoint('TOPLEFT',0,-11);track:SetSize(1020,8)
    slider:SetThumbTexture('Interface\\AddOns\\OlympusChatWarden\\Media\\V5\\Controls.tga')
    local thumb=slider:GetThumbTexture();V.Region(thumb,'Controls',{1127,564,1170,742});thumb:SetSize(18,30);thumb:SetDrawLayer('OVERLAY',1)
    V.Text(panel,'50%',24,-168,100,12,V.muted);V.Text(panel,'150%',1006,-168,100,12,V.muted)
    local input=V.Edit(panel,24,-224,180,40,'Percentage');input:SetMaxLetters(3);input:SetNumeric(true);input.ChatWardenNoSpelling=true;T.TextField(input)
    V.Text(panel,'%',215,-236,30,16)
    function p:SyncDisplay()
        local actual=math.floor((W.appliedScale or 1)*100+.5)
        local requested=ns.DB.workspaceScale and math.floor(ns.DB.workspaceScale*100+.5)
        valueLabel:SetText((requested and ('Saved size: '..requested..'%') or 'Automatic screen fit')..' • displayed '..actual..'%'..(dirty and ' • unsaved adjustment' or ''))
    end
    local function Sync()
        syncing=true;current=math.floor((ns.DB.workspaceScale or W.appliedScale or 1)*100+.5);slider:SetValue(math.max(50,math.min(150,current)))
        input:SetText(tostring(current));input:ClearFocus()
        syncing=false;dirty=false;p:SyncDisplay()
    end
    local function Apply()
        local ok,message=W.SetScale(input:GetText())
        if ok then p.status:SetText('Window size saved.');Sync() else p.status:SetText(message or '') end
    end
    slider:SetScript('OnValueChanged',function(_,value,userInput)
        if syncing or userInput==false or not p:IsShown() then return end
        current=math.floor(value+.5);syncing=true;input:SetText(tostring(current));syncing=false;dirty=true;p:SyncDisplay()
    end)
    input:HookScript('OnTextChanged',function(_,user) if user and not syncing then dirty=true;p:SyncDisplay() end end)
    input:SetScript('OnEnterPressed',Apply)
    V.Button(panel,'Apply',266,-224,170,40,Apply)
    V.Button(panel,'Fit to screen',716,-224,346,40,function() W.SetScale(nil);p.status:SetText('Automatic screen fit restored.');Sync() end,'neutral')
    V.Text(panel,'Choose a size, then Apply. The panel stays still while you drag. Screen limits can temporarily reduce a saved size; your preference is kept. Percentages follow WoW UI scale.',24,-303,1040,14,V.muted):SetHeight(60)
    p:SetScript('OnHide',function() input:ClearFocus() end)
    p.input=input;p.slider=slider;p.track=track;p.ResetDraft=Sync;p.ApplyScale=Apply;W.scalePage=p;Sync()
end
function W.RuleEditor(rule,seed)
    if not ns.Membership.Allowed() then return end
    W.current='rules';W.Header('rules');local p=FormPage(rule and 'Edit personal rule' or 'New personal rule','Choose a literal phrase and its action. This changes filtering; saved reports remain separate.')
    local panel=V.Panel(p,14,-92,1112,448,'dark')
    V.Text(panel,'Exact phrase',22,-24,700,15,V.gold);local phrase=V.Edit(panel,22,-54,1064,40,'Phrase to match')
    phrase:SetMaxLetters(120);phrase:SetText(rule and rule.phrase or seed or '')
    V.Text(panel,'Action',22,-120,500,15,V.gold);local action=rule and rule.action or 'Redacted'
    V.Dropdown(panel,22,-150,510,T.RuleActions,function() return action end,function(v) action=v end)
    V.Text(panel,'Replacement text (Replace action only)',22,-213,850,15,V.gold)
    local replacement=V.Edit(panel,22,-244,1064,40,'Replacement text');replacement:SetMaxLetters(120);replacement:SetText(rule and rule.replacement or '')
    local enabled=rule==nil or rule.enabled;V.Check(panel,'Rule enabled',22,-310,enabled,function(v) enabled=v end,300)
    V.Button(panel,'Save personal rule',22,-371,252,39,function()
        local ok,message=ns.Personal.SaveRule(phrase:GetText(),action,rule and rule.id,nil,enabled,replacement:GetText())
        p.status:SetText(message or '');if ok then W.Open('rules');ShowStatus(message) end
    end)
    V.Button(panel,'Cancel',824,-371,262,39,function() W.Open('rules') end,'neutral')
    p.phrase=phrase;p.replacement=replacement;W.ruleEditor=p
end
function W.HistorySettings()
    if not ns.Membership.Allowed() then return end
    W.Open('settings');local p=FormPage('Activity history','Keep review evidence and read states for this character across reloads and logins.')
    local panel=V.Panel(p,18,-98,1104,420,'dark')
    V.Check(panel,'Remember Messages, Alerts and contact activity',24,-26,ns.DB.persistHistory~=false,function(value)
        ns.History.SetEnabled(value);p.status:SetText(value and 'History will be remembered for this character.' or 'Saved history for this character removed. Current entries remain available until reload.')
    end,1000)
    local messages,mentions,alerts=ns.History.Stats()
    V.Text(panel,'Saved activity',24,-92,1000,20,V.gold)
    V.Text(panel,messages..(messages==1 and ' review entry' or ' review entries')..'  /  '..mentions..(mentions==1 and ' mention' or ' mentions')..'  /  '..alerts..(alerts==1 and ' contact alert' or ' contact alerts'),24,-132,1000,15)
    V.Text(panel,'History is separate for each character. Oldest records roll off at the storage limits. Read states return without replaying sounds or popups.',24,-184,1000,14,V.muted):SetHeight(48)
    V.Text(panel,'Limits: 200 review entries, 300 shared activity entries and 200 contact alerts; up to 2 MB per character, 12 characters and 8 MB total. Capture and bookmarks have their own limits.',24,-246,1000,14,V.muted):SetHeight(56)
    local armed=false;local clear
    clear=V.Button(panel,'Clear all history for this character',24,-336,460,38,function()
        if not armed then armed=true;clear:SetText('Confirm clear history');p.status:SetText('Clears Messages, Alerts and contact activity for this character. Capture, bookmarks, reports, rules and protection lists are kept.');return end
        ns.History.Clear();W.HistorySettings();W.pages.form.status:SetText('This character’s activity history was cleared.')
    end,'danger')
end
function W.ExceptionEditor(existing)
    W.current='rules';local p=FormPage('Personal exception','An exact phrase that should remain visible. Other filtering and Shield protections still apply.')
    local phrase=V.Edit(p,24,-123,1050,44,'Exception phrase');phrase:SetText(existing or '')
    V.Button(p,'Save exception',24,-211,260,39,function()
        local list={};for _,text in ipairs(ns.DB.exceptions) do if text~=existing then list[#list+1]=text end end;list[#list+1]=phrase:GetText()
        local ok,err=ns.SetExceptions(list);if ok then W.Open('rules') else p.status:SetText(err or 'Unable to save exception.') end
    end)
end
function W.ShieldEditor(name)
    if not ns.Modules.Enabled('shield') then W.Open('modules');return end
    W.current='shield';W.Header('shield');local p=FormPage('Add local shield','Enter the full player name. Forever first name and surname are supported.')
    local player=V.Edit(p,24,-123,1050,42,'Player name');player:SetText(name or '')
    local duration=900;V.Dropdown(p,24,-191,420,{{900,'15 minutes'},{'session','Until logout / reload'},{0,'Until I remove it'}},function() return duration end,function(v) duration=v end)
    V.Button(p,'Add shield',24,-262,260,39,function()
        local ok,message=ns.Shield.Add(player:GetText(),duration,'Manual shield');p.status:SetText(message or '')
        if ok then
            local page=W.Destination('shield');if not page then return end;page.mode='active';page.selected=nil;page:Activate();page:Refresh()
            local key=ns.Shield.Key(player:GetText());for _,item in ipairs(page.visible) do if item.id==key then page.selected=item;break end end
            page:Refresh();ShowStatus('Shield added.')
        end
    end)
    W.shieldEditor=p;p.player=player
end
function W.PackSensitivity(id)
    W.current='packs';local p=FormPage('Pack sensitivity',ns.RulePacks.Title(id))
    local value=ns.DB.disabledPacks[id] and 'off' or ns.DB.packPresets[id] or 'default'
    V.Dropdown(p,24,-126,600,{{'default','Default (main preset)'},{'off','Off'},{'strict','Mild'},{'balanced','Balanced'},{'aggressive','Strict'}},function() return value end,function(v) value=v end)
    local masks=ns.DB.gommagePacks[id]~=false
    V.Check(p,"Include this pack's curated masks when Gommage is on",24,-187,masks,function(v) masks=v end,1000)
    V.Button(p,'Save preset',24,-254,260,39,function() local ok,err=ns.SetPackPreset(id,value);if ok then ns.DB.gommagePacks[id]=masks;ns.PolicyChanged();W.Open('packs') else p.status:SetText(err) end end)
end
function W.CaptureSettings()
    if not ns.Modules.Enabled('chat') then W.Open('modules');return end
    W.current='capture';local p=FormPage('Capture settings','Recording starts off. Saved capture stays local and persists across reloads until cleared or full.')
    local C=ns.ChatCapture
    V.Check(p,'Record supported player chat',24,-119,C.db.enabled,function(v) C.SetOption('enabled',v);W.Queue() end,600)
    V.Check(p,'Include whispers',24,-169,C.db.whispers,function(v) C.SetOption('whispers',v) end,600)
    V.Check(p,'Include guild / officer chat',24,-219,C.db.guild,function(v) C.SetOption('guild',v) end,600)
    V.Text(p,'Capture: 5,000 lines / 4 MB. Bookmarks: 50 / 1 MB. Oldest captured lines roll off when full. Clearing capture keeps bookmarks.',24,-285,1030,14,V.muted)
    local armed=false;V.Button(p,'Clear rolling capture',24,-369,300,39,function(self) if not armed then armed=true;self:SetText('Click again to clear');return end;C.Clear();p.status:SetText('Capture cleared. Bookmarks kept.');self:SetText('Clear rolling capture');armed=false end,'danger')
end
function W.AlertTabs(current)
    local function View(mode)
        local page=W.Destination('mentions');if not page then return end;page.mode=mode;page.selected=nil;page:Activate();page:Refresh()
    end
    W.Tabs({{'all','All alerts',function() View('all') end},{'mentions','Mentions',function() View('mentions') end},
        {'wanted','Wanted',function() View('wanted') end},{'olympusmute','OlympusMute',function() View('olympusmute') end},{'mention-settings','Mention settings',W.MentionSettings},
        {'wanted-settings','Wanted settings',W.WantedSettings}},current or 'all')
end
function W.MentionSettings()
    W.current='mentions';W.Header('mentions');local p=FormPage('Mention settings','Your first or full name matches without @. Names and nicknames stay exact. Hidden and Shielded messages stay quiet.')
    local M=ns.Mentions;local db=M.db
    V.Check(p,'Enable Mention Alerts',22,-100,db.enabled,function(v) M.Set('enabled',v) end,360)
    V.Check(p,'Detect my first or full character name',22,-140,db.character,function(v) M.Set('character',v) end,470)
    V.Text(p,#M.CharacterNames()>0 and table.concat(M.CharacterNames(),' / ') or 'Name unavailable. Add a manual nickname below.',59,-174,470,12,V.muted)
    V.Check(p,'Enable sound',570,-100,db.sound,function(v) M.Set('sound',v) end,340)
    V.Check(p,'Enable toast notifications',570,-140,db.toast,function(v) M.Set('toast',v) end,420)
    V.Dropdown(p,570,-184,520,{{0,'No sound / toast cooldown'},{5,'5-second alert cooldown'},{10,'10-second alert cooldown'},{30,'30-second alert cooldown'},{60,'60-second alert cooldown'}},function() return db.cooldown end,function(v) M.Set('cooldown',v) end)
    local phraseTypos=V.Check(p,'Match close typos in watch phrases',22,-228,db.typos,function(v) M.Set('typos',v) end,800)
    T.Tooltip(phraseTypos,'Watch phrase typos','Optional. Requires Typo-aware incoming filtering in Settings > Spelling. Uses a unique one-edit match for watch phrases; character names and nicknames stay literal. Hidden and Shielded chat stays quiet.')
    V.Text(p,'Monitored channels',22,-270,1050,16,V.gold)
    local channelNames={{'general','General'},{'trade','Trade'},{'lfg','LookingForGroup'},{'other','Other channels / emotes'},{'say','Say'},{'yell','Yell'},{'guild','Guild / officer'},{'party','Party / instance'},{'raid','Raid'},{'whispers','Whispers'}}
    for i,c in ipairs(channelNames) do local key=c[1];V.Check(p,c[2],22+((i-1)%3)*360,-305-math.floor((i-1)/3)*34,db.channels[key],function(v) M.SetChannel(key,v) end,350) end
    V.Button(p,'Manage nicknames & phrases',22,-472,330,39,function() W.WatchPhrases() end)
    V.Button(p,'Mark all mentions read',376,-472,330,39,function() A.MarkCategory('mentions');p.status:SetText('Mentions marked read.') end,'neutral')
    W.AlertTabs('mention-settings')
end
function W.WatchPhrases(edit)
    W.current='mentions';local p=FormPage('Nicknames & watch phrases','One notification per message, even when several phrases match. Nicknames and phrases are literal and case-insensitive.')
    local text=V.Edit(p,22,-109,700,40,'Nickname or phrase');text:SetText(edit and edit.text or '')
    local kind=edit and edit.kind or 'phrase';local channel=edit and edit.channel or 'all'
    V.Dropdown(p,742,-109,348,{{'phrase','Watch phrase'},{'nickname','Nickname'}},function() return kind end,function(v) kind=v end)
    V.Dropdown(p,22,-168,450,{{'all','All monitored channels'},{'general','General'},{'trade','Trade'},{'lfg','LookingForGroup'},{'whispers','Whispers'},{'guild','Guild / officer'},{'party','Party / instance'},{'raid','Raid'}},function() return channel end,function(v) channel=v end)
    V.Button(p,'Save phrase',490,-168,250,35,function()
        local ok,message=ns.Mentions.Save(text:GetText(),kind,edit and edit.id,channel);if ok then W.WatchPhrases() else p.status:SetText(message) end
    end)
    local list=V.Panel(p,14,-224,1110,305,'dark');local offset=0
    -- This bounded editor uses pages so all 100 phrases remain manageable.
    W.phrasePage=W.phrasePage or 1;local phrases=ns.Mentions.db.phrases;local pages=math.max(1,math.ceil(#phrases/6));W.phrasePage=math.min(W.phrasePage,pages)
    for i=(W.phrasePage-1)*6+1,math.min(#phrases,W.phrasePage*6) do
        local phrase=phrases[i];local y=-15-offset*45;offset=offset+1
        V.Text(list,phrase.text,18,y-8,520,14);V.Text(list,(phrase.enabled and 'On' or 'Off')..' | '..phrase.kind..' | '..phrase.channel,540,y-10,210,11,V.muted)
        V.Button(list,'Edit',760,y,88,32,function() W.WatchPhrases(phrase) end,'neutral')
        V.Button(list,phrase.enabled and 'Mute' or 'Enable',854,y,104,32,function() ns.Mentions.Change(phrase.id,not phrase.enabled);W.WatchPhrases() end,'neutral')
        V.Button(list,'Delete',964,y,122,32,function() ns.Mentions.Change(phrase.id,nil,true);W.WatchPhrases() end,'danger')
    end
    V.Button(p,'Previous',22,-544,150,34,function() W.phrasePage=math.max(1,W.phrasePage-1);W.WatchPhrases() end,'neutral')
    V.Text(p,W.phrasePage..' / '..pages,189,-554,100,12,V.muted)
    V.Button(p,'Next',282,-544,150,34,function() W.phrasePage=math.min(pages,W.phrasePage+1);W.WatchPhrases() end,'neutral')
    V.Button(p,'Mention settings',810,-544,280,34,W.MentionSettings,'neutral')
end
local function Copy(text,label,verbatim)
    local p=Page();V.Text(p,label or 'Copy text',20,-15,1050,20,V.gold)
    V.Text(p,'Select the text and press Ctrl+C. Nothing is sent automatically.',20,-48,1050,13,V.muted)
    local hideNames=true;local extra=''
    local paper=V.Panel(p,12,-146,1116,398,'dark');local scroll=CreateFrame('ScrollFrame',nil,paper,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',18,-18);scroll:SetSize(1068,354)
    local edit=CreateFrame('EditBox',nil,scroll);edit:SetMultiLine(true);edit:SetAutoFocus(false);edit:SetMaxLetters(8388608);edit:SetSize(1068,354);T.Body(edit);edit:SetTextColor(.91,.88,.80,1);edit.ChatWardenNoSpelling=true;scroll:SetScrollChild(edit);T.TextField(edit,scroll);V.SkinScroll(scroll)
    local function Rebuild() edit:SetText(verbatim and (text or '') or ns.Export.TextPreview(text or '',hideNames,extra));edit:SetCursorPosition(0);edit:ClearFocus() end
    if not verbatim then
        V.Check(p,'Hide known player names',20,-91,true,function(value) hideNames=value;Rebuild() end,360)
        local extraBox=V.Edit(p,390,-90,738,36,'Other names to hide, separated by commas',function(value,user) if user then extra=value;Rebuild() end end)
        extraBox.ChatWardenNoSpelling=true
    else V.Text(p,'Copy the complete text. Signed pack contents are preserved.',20,-96,1070,13,V.muted) end
    Rebuild();p.copyText=edit;W.copyPage=p
    V.Button(p,'Select all text',14,-565,220,36,function() edit:SetFocus();edit:HighlightText() end)
    V.Button(p,'Back',914,-565,214,36,function() p:Hide();W.Open(W.copyBack or 'overview') end,'neutral')
    W.HidePages();W.pages.copy=p;W.copyBack=W.current;p:Show();W.Tabs({{'copy','Copy text',function() end}},'copy');W.current='copy'
end
function W.Copy(text,label,verbatim) W.Ensure();Copy(text,label,verbatim) end
Bookmark=function(item)
    if not item then return end
    local entry=ns.ChatCapture.Find(item.sender,item.lineID)
    if not entry then ShowStatus('This message is not in your capture. Start capture for future messages.');return end
    local ok,message=ns.ChatCapture.Bookmark(entry.id,'','');ShowStatus(message);if ok then local page=W.Destination('capture');if page then page.mode='bookmarks';page:Activate();page:Refresh() end end
end
builders.messages=function()
    local p=ListPage('messages','Filtering activity',function() return A.List('messages') end,function(item,page)
        local entry=item and ns.Review.Get(item.reviewID)
        if not entry then return {'Review filtered chat','Select a message to inspect its result. The original text appears here when you select it.'} end
        local parts=ns.Review.ReaderBlocks(entry,page.reasons)
        return parts,'Player: '..A.DisplayName(entry.sender)..'\n\nResult: '..entry.action..'\n\nChannel: '..Channel(entry)..'\n\n'..ns.Review.TimeLabel(entry)
    end,function(page)
        page:AddAction('Why filtered?',function(_,self) self.reasons=not self.reasons;self:Refresh() end)
        page:AddAction('Report filter problem',function(item) ns.OpenReport(ns.Review.Get(item.reviewID),'False positive') end)
        page:AddAction('Report player',function(item) ns.Review.ReportPlayer(ns.Review.Get(item.reviewID)) end)
        page:AddAction('Create personal rule',function(item) W.RuleEditor(nil,ns.Review.Get(item.reviewID).original) end)
        page:AddAction('Dismiss message',function(item) ns.Review.Remove(item.reviewID) end,'danger')
        page:AddAction('Copy message',function(item) W.Copy(ns.Review.Get(item.reviewID).original,'Copy message') end)
    end)
    function p:Activate() W.Tabs({}) end
    return p
end
builders.mentions=function()
    local p=ListPage('alerts','Signals',function(self) return A.List(self.mode=='mentions' and 'mentions' or self.mode=='wanted' and 'wanted' or self.mode=='olympusmute' and 'olympusmute' or 'alerts') end,function(item)
        if item and item.wanted then return WantedDetail(item) end
        if item and item.categories.olympusmute then return {{kind='title',text='OlympusMute sharing observed'},
            {kind='meta',text=Plain(Channel(item)..' / '..Stamp(item))},
            {kind='body',text='A complete compatible sharing message was observed from this player.'},
            {kind='body',text='This does not prove they muted you or anyone else. The shared list is discarded and never imported. Observations can be missed; the sender is not independently verified.'}},
            'Player: '..A.DisplayName(item.sender)..'\n\n'..Stamp(item) end
        if not item then return {'SignalWarden','Personal mentions, Wanted encounters and observed OlympusMute sharing appear here.'} end
        local phrases={};for _,match in ipairs(item.mentionMatches or {}) do phrases[#phrases+1]=match.text end
        return {{text='Mention alert',kind='title'},{text=Channel(item)..'  /  '..Stamp(item),kind='meta'},
            {text=item.text or item.preview,kind='quote'},{text='Matched phrases',kind='heading'},{text=table.concat(phrases,', '),kind='accent'}},
            'Player: '..A.DisplayName(item.sender)..'\n\nChannel: '..Channel(item)..'\n\nMatched: '..table.concat(phrases,', ')
    end,function(page)
        page:AddAction('Mark read',function(item) A.Mark(item.id,'alerts') end)
        page.copy=page:AddAction('Copy message',function(item) W.Copy(item.text or item.preview,'Copy mention') end)
        page.bookmark=page:AddAction('Bookmark message',Bookmark)
        page.mute=page:AddAction('Mute matched phrase',function(item)
            for _,match in ipairs(item.mentionMatches or {}) do if match.id==0 then ns.Mentions.Set('character',false) else ns.Mentions.Change(match.id,false) end end
            ShowStatus('Matched phrases muted for future alerts.')
        end)
        page.watch=page:AddAction('Add watch phrase',function() W.WatchPhrases() end)
        page:AddAction('Delete alert',function(item)
            for _,key in ipairs({'mentions','wanted','olympusmute'}) do item.categories[key]=nil;item.read[key]=nil;item.quiet[key]=nil end
            if not next(item.categories) then A.Remove(item.id) else A.Changed() end
        end,'danger')
        page.openOlympus=page:AddAction('Open Olympus',function() local _,message=ns.OlympusIntegration.Open();if message then ShowStatus(message) end end,'neutral')
    end)
    function p:Activate() W.AlertTabs(self.mode) end
    p.markAll:SetScript('OnClick',function()
        A.MarkCategory(p.mode=='mentions' and 'mentions' or p.mode=='wanted' and 'wanted' or p.mode=='olympusmute' and 'olympusmute' or 'alerts');p:Refresh()
    end)
    function p:AfterRefresh()
        local item=self.selected;local wanted=item and item.wanted~=nil;local signal=item and item.categories.olympusmute
        self.bookmark:SetShown(not wanted and not signal);self.mute:SetShown(not wanted and not signal);self.watch:SetShown(not wanted and not signal)
        self.openOlympus:SetShown(wanted);self.copy:SetText(wanted and 'Copy alert' or 'Copy message')
        if not item or wanted or signal then return end
        local ranges={};for _,hit in ipairs(item.mentionMatches or {}) do ranges[#ranges+1]=hit end
        table.sort(ranges,function(a,b) return a.first<b.first or a.first==b.first and a.last>b.last end)
        local text=item.text or item.preview;local parts,cursor={},1
        for _,hit in ipairs(ranges) do if hit.first>=cursor then
            parts[#parts+1]=Plain(text:sub(cursor,hit.first-1));parts[#parts+1]='|cff1a4a66'..Plain(text:sub(hit.first,hit.last))..'|r';cursor=hit.last+1
        end end
        parts[#parts+1]=Plain(text:sub(cursor));self.document:SetMarkup(3,table.concat(parts))
    end
    return p
end
builders.capture=function()
    local function Line(entry)
        local timestamp=entry.timestamp and ns.SafeCall(date,'%H:%M',entry.timestamp) or '--:--'
        return '['..timestamp..']  ['..(entry.sender or 'Unknown')..']: '..entry.original
    end
    local function Items(p)
        local out={};local C=ns.ChatCapture
        if p.mode=='bookmarks' then
            for i=#C.db.bookmarks,1,-1 do local b=C.db.bookmarks[i];local lines={};for _,e in ipairs(b.records) do lines[#lines+1]=C.Line(e) end
                out[#out+1]={id=b.id,title=b.title,preview=#b.records..' saved messages',text=table.concat(lines,'\n'),note=b.note,timestamp=b.timestamp,bookmark=b}
            end
        elseif p.mode=='conversations' then
            local map={}
            for _,e in ipairs(C.db.entries) do if e.event=='CHAT_MSG_WHISPER' or e.event=='CHAT_MSG_WHISPER_INFORM' then
                local name=e.recipient or e.sender;local key=ns.Shield.Key(name)
                if key then
                    local group=map[key];if not group then group={id=key,sender=name,event='CHAT_MSG_WHISPER',records={},timestamp=e.timestamp};map[key]=group;out[#out+1]=group end
                    group.records[#group.records+1]=e;group.timestamp=e.timestamp;group.preview=e.original
                end
            end end
            table.sort(out,function(a,b) return (a.timestamp or 0)>(b.timestamp or 0) end)
        else
            for i=#C.db.entries,1,-1 do local e=C.db.entries[i];out[#out+1]={id=e.id,sender=e.sender,event=e.event,channel=e.channel,preview=e.original,timestamp=e.timestamp,captured=e} end
        end
        return out
    end
    local p=ListPage(nil,'Captured chat',Items,function(item)
        if not item then return {'Chat Capture','Start capture to save future player chat. Recording is optional and stays local.','Storage: 5,000 lines / 4 MB. Bookmarks: 50 / 1 MB.','Conversations groups whispers that are already in your capture.'} end
        local lines={}
        if item.captured and (item.event=='CHAT_MSG_WHISPER' or item.event=='CHAT_MSG_WHISPER_INFORM') then
            local key=ns.Shield.Key(item.captured.recipient or item.captured.sender);local records={}
            for _,e in ipairs(ns.ChatCapture.db.entries) do if (e.event=='CHAT_MSG_WHISPER' or e.event=='CHAT_MSG_WHISPER_INFORM') and ns.Shield.Key(e.recipient or e.sender)==key then records[#records+1]=e;if #records>50 then table.remove(records,1) end end end
            item.contextRecords=records
        end
        if item.records or item.contextRecords then for _,e in ipairs(item.records or item.contextRecords) do lines[#lines+1]=Line(e) end
        elseif item.bookmark then lines={item.bookmark.note,item.text}
        else lines={Line(item.captured)} end
        local blocks={{text=item.bookmark and 'Saved incident' or (item.records or item.contextRecords) and 'Conversation' or 'Captured message',kind='title'}}
        local records=item.records or item.contextRecords or item.bookmark and item.bookmark.records or {item.captured}
        if item.bookmark and item.bookmark.note and item.bookmark.note~='' then blocks[#blocks+1]={text=item.bookmark.note,kind='body'} end
        for _,e in ipairs(records) do
            blocks[#blocks+1]={text=(e.timestamp and ns.SafeCall(date,'%H:%M',e.timestamp) or '--:--')..'  /  '..(e.sender or 'Unknown player'),kind='accent',gap=5}
            blocks[#blocks+1]={text=e.original or '',kind='quote',gap=18}
        end
        return blocks,'Player: '..(item.sender or 'Saved bookmark')..'\n\nChannel: '..Channel(item)..'\n\nMessages: '..(item.records and #item.records or item.contextRecords and #item.contextRecords or item.bookmark and #item.bookmark.records or 1)
    end,function(page)
        page:AddAction('Add bookmark',function(item)
            local captured=item.captured or item.records and item.records[#item.records]
            if captured then W.BookmarkEditor(captured) else W.BookmarkEditor(nil,item.bookmark) end
        end)
        page:AddAction('Export selection',function(item)
            local records=item.bookmark and {item.bookmark} or item.records or item.contextRecords or {item.captured}
            ns.OpenExport(item.bookmark and 'bookmarks' or 'capture',nil,records)
        end)
        page:AddAction('Copy conversation',function(item) local lines={};for _,e in ipairs(item.records or item.contextRecords or item.bookmark and item.bookmark.records or {item.captured}) do lines[#lines+1]=Line(e) end;W.Copy(table.concat(lines,'\n'),'Copy captured chat') end)
        page:AddAction('Create personal rule',function(item) W.RuleEditor(nil,item.captured and item.captured.original or '') end)
        page.delete=page:AddAction('Delete from capture',function(item,self)
            if self.deleteArmed~=item.id then self.deleteArmed=item.id;self.delete:SetText('Confirm delete');ShowStatus('Click Confirm delete to remove this selection. Other capture and bookmarks are kept.');return end
            if item.bookmark then ns.ChatCapture.RemoveBookmark(item.id)
            else ns.ChatCapture.RemoveRecords(item.records or {item.captured}) end
            self.deleteArmed=nil;self.selected=nil;self:Refresh()
        end,'danger')
        page.editBookmark=page:AddAction('Edit bookmark',function(item) W.BookmarkEditor(nil,item.bookmark) end,'neutral')
    end)
    p.mode='recent';p.unreadOnly:Hide()
    function p:Activate()
        local function View(value) self.mode=value;self.selected=nil;self.page=1;self:Activate();self:Refresh() end
        W.Tabs({{'recent','Recent',function() View('recent') end},{'bookmarks','Bookmarks',function() View('bookmarks') end},
            {'conversations','Conversations',function() View('conversations') end},{'export','Export shown',function()
                local records={};for _,item in ipairs(self.visible or {}) do
                    if item.bookmark then records[#records+1]=item.bookmark
                    elseif item.records then for _,record in ipairs(item.records) do records[#records+1]=record end
                    elseif item.captured then records[#records+1]=item.captured end
                end
                ns.OpenExport(self.mode=='bookmarks' and 'bookmarks' or 'capture',nil,records)
            end},{'settings','Capture settings',W.CaptureSettings}},self.mode)
    end
    function p:AfterRefresh()
        self.delete:SetEnabled(self.selected~=nil)
        self.delete:SetText(self.selected and self.deleteArmed==self.selected.id and 'Confirm delete' or self.mode=='bookmarks' and 'Delete bookmark' or 'Delete from capture')
        self.editBookmark:SetEnabled(self.selected~=nil and self.selected.bookmark~=nil)
        self.editBookmark:SetShown(self.mode=='bookmarks')
        ShowStatus((ns.ChatCapture.db.enabled and 'Recording' or 'Paused')..'  |  '..#ns.ChatCapture.db.entries..' / 5,000 lines  |  '..#ns.ChatCapture.db.bookmarks..' bookmarks')
    end
    return p
end
function W.BookmarkEditor(captured,bookmark)
    if not captured and not bookmark then return end
    W.current='capture';local p=FormPage(bookmark and 'Edit bookmark' or 'Save incident bookmark','Save up to 10 already captured lines on each side. Titles and notes are optional.')
    V.Text(p,'Bookmark title',24,-107,1040,15,V.gold);local title=V.Edit(p,24,-138,1060,42,'Optional title');title:SetMaxLetters(120);title:SetText(bookmark and bookmark.title or '')
    V.Text(p,'Note',24,-207,1040,15,V.gold);local note=V.Edit(p,24,-238,1060,42,'Optional note');note:SetMaxLetters(1000);note:SetText(bookmark and bookmark.note or '')
    V.Button(p,'Save bookmark',24,-322,300,39,function()
        local ok,message
        if bookmark then ok,message=ns.ChatCapture.UpdateBookmark(bookmark.id,title:GetText(),note:GetText()) else ok,message=ns.ChatCapture.Bookmark(captured.id,title:GetText(),note:GetText()) end
        if ok then ns.OpenCaptureBookmark(bookmark and bookmark.id or ns.ChatCapture.nextBookmark);ShowStatus(message) else p.status:SetText(message) end
    end)
end
builders.settings=function()
    local p=Page()
    V.Text(p,'Make Warden comfortable',12,-12,1100,24,V.gold)
    V.Text(p,'Shared preferences live here. Protection and recording settings stay with the feature they control.',12,-55,1100,15,V.muted)
    local specs={{'Window size','Apply a size or fit Warden to your screen. Navigation preserves your choice.',W.ScaleSettings,'settings'},
        {'Recent activity history','Choose how the bounded chat/protection review feed is kept. Chronicle history is separate.',W.HistorySettings,'copy'}}
    for n,s in ipairs(specs) do local card=V.Panel(p,0,-110-(n-1)*154,1140,136,'dark');V.Icon(card,s[4],56,18,-18);V.Text(card,s[1],96,-18,1000,21,V.gold);V.Text(card,s[2],96,-53,1000,15,V.muted);V.Button(card,'Open '..s[1]:lower(),96,-90,420,32,s[3],'neutral') end
    local launch=V.Panel(p,0,-418,1140,218,'dark');V.Icon(launch,'overview',56,18,-18)
    V.Text(launch,'Optional shortcuts',96,-18,1000,21,V.gold)
    p.shopLauncher=V.Check(launch,'Replace the shop micro button with Warden',96,-56,ns.DB.shopLauncher,function(value) ns.WardenLaunchers.Set('shopLauncher',value) end,970)
    p.inspectLauncher=V.Check(launch,'Show an IntelWarden tab beside Blizzard Inspect',96,-94,ns.DB.inspectLauncher,function(value) ns.WardenLaunchers.Set('inspectLauncher',value) end,970)
    p.wardenMinimap=V.Check(launch,'Show a Warden minimap button',96,-132,ns.DB.wardenMinimap,function(value) ns.WardenLaunchers.Set('wardenMinimap',value) end,970)
    V.Text(launch,'All start off. Changes requested in combat apply after combat. Recording and module choices are unchanged.',96,-175,1000,13,V.muted)
    function p:Activate() W.CommandTabs('settings');self.shopLauncher:SetChecked(ns.DB.shopLauncher);self.inspectLauncher:SetChecked(ns.DB.inspectLauncher);self.wardenMinimap:SetChecked(ns.DB.wardenMinimap) end
    return p
end
builders.updates=function()
    local p=Page()
    p.mode='notes';p.notes=CreateFrame('Frame',nil,p);p.notes:SetAllPoints(p)
    p.tour=CreateFrame('Frame',nil,p);p.tour:SetAllPoints(p)
    local updateHero=V.Panel(p.notes,0,0,1140,111,'header')
    V.Icon(updateHero,'updates',76,20,-17)
    p.releaseTitle=V.Text(updateHero,ns.NAME..' '..ns.InstalledUpdate.version,124,-22,986,26,V.gold)
    p.releaseTitle:SetHeight(34);p.releaseTitle:SetJustifyV('TOP')
    p.releaseSubtitle=V.Text(updateHero,'Highlights since 1.0.1',125,-65,978,14)
    p.releaseSubtitle:SetHeight(22);p.releaseSubtitle:SetJustifyV('TOP')
    p.noteCards={}
    local slots=0;for _,release in ipairs(ns.UpdateHistory) do slots=math.max(slots,#release.cards) end
    for i=1,slots do
        local card=V.Panel(p.notes,0,-125-(i-1)*76,1140,66,'dark')
        card.icon=V.Icon(card,'updates',36,18,-15)
        card.title=V.Text(card,'',72,-11,1046,17,V.gold)
        card.description=V.Text(card,'',73,-35,1046,13);card.description:SetHeight(24)
        p.noteCards[i]=card
    end
    p.githubNotes=V.Button(p.notes,'Full notes on GitHub',0,-587,360,38,function()
        local path=p.releaseIndex>1 and '/releases/tag/v'..ns.UpdateHistory[p.releaseIndex].version or '/releases'
        W.Copy(ns.PROJECT_URL..path,'Full patch notes on GitHub',true)
    end)
    p.previousUpdate=V.Button(p.notes,'Previous update',500,-587,204,38,function() p:SetRelease(p.releaseIndex+1) end,'neutral')
    p.nextUpdate=V.Button(p.notes,'Next update',716,-587,204,38,function() p:SetRelease(p.releaseIndex-1) end,'neutral')
    p.releasePosition=V.Text(p.notes,'',944,-599,184,13,V.muted)
    function p:SetRelease(index)
        self.releaseIndex=math.max(1,math.min(#ns.UpdateHistory,index))
        local release=ns.UpdateHistory[self.releaseIndex];local compact=#release.cards>5
        self.releaseTitle:SetText(ns.NAME..' '..release.version)
        self.releaseSubtitle:SetText(release.subtitle or 'Highlights since 1.0.1')
        for i,card in ipairs(self.noteCards) do
            local spec=release.cards[i];card:SetShown(spec~=nil)
            if spec then
                card:ClearAllPoints();card:SetPoint('TOPLEFT',0,-125-(i-1)*(compact and 76 or 86));card:SetHeight(compact and 66 or 76)
                card.icon.ChatWardenIconBox={size=compact and 36 or 42,x=18,y=compact and -15 or -17};V.SetIcon(card.icon,spec[3])
                card.title:SetText(spec[1]);card.description:SetText(spec[2])
                card.description:ClearAllPoints();card.description:SetPoint('TOPLEFT',73,compact and -35 or -34);card.description:SetHeight(compact and 24 or 32)
            end
        end
        self.previousUpdate:SetEnabled(self.releaseIndex<#ns.UpdateHistory);self.nextUpdate:SetEnabled(self.releaseIndex>1)
        self.releasePosition:SetText(self.releaseIndex..' / '..#ns.UpdateHistory)
    end
    p:SetRelease(1)
    local hero=V.Panel(p.tour,0,0,1140,111,'header')
    local crest=V.Texture(hero,'Logo',{0,0,512,512},'ARTWORK');crest:SetSize(92,92);crest:SetPoint('TOPLEFT',16,-9)
    V.Text(hero,'Welcome to Olympus Warden',124,-18,986,28,V.gold)
    V.Text(hero,'Your protection, remembered players and personal Chronicle in one Olympus suite.',125,-57,978,14)
    V.Text(hero,'LAUNCH TOUR  |  Installed version '..ns.VERSION,125,-78,978,11,V.blue)
    local features={
        {'overview','CommandWarden','Your command center: selected features, suite search, shared settings and performance.','Overview • Modules • Performance • Settings','overview'},
        {'messages','ChatWarden','Review filtered messages and manage Capture, Rules, Packs and Reports in one place.','Messages • Capture • Rules • Packs • Reports','messages'},
        {'mentions','SignalWarden','Personal mentions, Wanted encounters and permitted OlympusMute signals, with your alert choices.','Mentions • Wanted • Notification settings','mentions'},
        {'shield','ShieldWarden','Protect unwanted contact and review what happened. Allow trusted players and manage shields.','Contact alerts • Active shields • Allowed players','shield'},
        {'intel','IntelWarden','Explore players you remember, private notes and dated gear and talent observations.','Recent players • Dossiers • Appearance & Gear','intel'},
        {'chronicle','ChronicleWarden','Follow milestones, activities, duels and measured time from your recorded adventure.','Highlights • Activities • Time & averages','chronicle'},
        {'relay','RelayWarden','Write a bug report, preview optional diagnostics and manage data, backups and help.','Reports • Diagnostics • Data & Backups • Help','relay'},
        {'settings','Make Warden comfortable','Choose your window size, protection, languages, notifications and typing assistance.','Settings • Window size • User guide','settings'},
    }
    p.features={}
    for i,spec in ipairs(features) do
        local target=spec[1];local card=V.Panel(p.tour,((i-1)%2)*578,-125-math.floor((i-1)/2)*121,562,111,'dark')
        V.Icon(card,spec[5],42,17,-17)
        V.Text(card,spec[2],74,-16,470,18,V.gold)
        local description=V.Text(card,spec[3],75,-45,465,13);description:SetHeight(35)
        V.Text(card,spec[4],75,-86,465,11,V.blue)
        card:EnableMouse(true);card:SetScript('OnMouseUp',function(_,button) if button=='LeftButton' then W.Open(target) end end)
        card:SetScript('OnEnter',function(self) self:SetAlpha(.85) end);card:SetScript('OnLeave',function(self) self:SetAlpha(1) end)
        T.Tooltip(card,spec[2],'Click to explore '..labels[target][2]..'.');p.features[i]=card
    end
    V.Text(p.tour,'History stays local. Reports require Submit. Click a feature to explore it.',10,-627,810,13,V.muted)
    p.ShowUpdates=V.Check(p,'Show future update notes',850,-622,ns.DB.showUpdates~=false,function(v) ns.DB.showUpdates=v end,286)
    function p:SetView(mode)
        self.mode=mode=='tour' and 'tour' or 'notes'
        self.ShowUpdates:SetChecked(ns.DB.showUpdates~=false)
        self.ShowUpdates:ClearAllPoints();self.ShowUpdates:SetPoint('TOPLEFT',850,self.mode=='notes' and -642 or -622)
        self.notes:SetShown(self.mode=='notes');self.tour:SetShown(self.mode=='tour')
        W.UpdateTabs(self.mode)
    end
    function p:Activate()
        self:SetView(self.mode)
    end
    return p
end
local function Walk(frame,fn)
    fn(frame)
    if frame.GetChildren then for _,child in ipairs({frame:GetChildren()}) do if not child:IsForbidden() and not child:IsProtected() then Walk(child,fn) end end end
end
function W.StyleTree(root)
    Walk(root,function(f)
        if f.GetObjectType and f:GetObjectType()=='Button' and f.GetText and f:GetText() and f:GetText()~='' and f:GetWidth()>45 and not f.ChatWardenArtStyled and not f.Caption then
            f.ChatWardenArtStyled=true
            for _,get in ipairs({'GetNormalTexture','GetPushedTexture','GetHighlightTexture','GetDisabledTexture'}) do if f[get] then local t=f[get](f);if t then t:Hide() end end end
            if f.GetFontString then local t=f:GetFontString();if t then t:Hide() end end
            local value=f:GetText();local role=V.ButtonKind(value);f.ChatWardenRole=role
            f.ArtNormal=V.Nine(f,role);f.Caption=V.Text(f,value,0,0,f:GetWidth()-10,13,V.gold)
            f.Caption:ClearAllPoints();f.Caption:SetPoint('CENTER');f.Caption:SetJustifyH('CENTER');f.Caption:SetWordWrap(false);f.Caption:SetHeight(math.max(14,f:GetHeight()-8))
            hooksecurefunc(f,'SetText',function(self,text) self.Caption:SetText(text or '') end)
            hooksecurefunc(f,'SetEnabled',function(self,enabled) self.Caption:SetAlpha(enabled and 1 or .45) end)
        end
        if f.GetObjectType and f:GetObjectType()=='EditBox' and f:GetHeight()<65 and f:GetWidth()>50 and not f.ChatWardenArtStyled then
            f.ChatWardenArtStyled=true;f.ArtFrame=V.Nine(f,'search')
            for _,name in ipairs({'Left','Right','Middle'}) do if f[name] and f[name].Hide then f[name]:Hide() end end
        end
        if f.GetObjectType and f:GetObjectType()=='ScrollFrame' then V.SkinScroll(f) end
    end)
end
function W.Embed(frame,id,trim)
    if not ns.Membership.Allowed() then return end
    if ns.Modules.Route(id or W.current or 'reports')~=(id or W.current or 'reports') then W.Open('modules');return end
    W.Ensure();id=id or W.current or 'reports';W.HidePages();W.current=id;W.Header(id);W.mounted=frame
    -- Remove only the old window branding, before laying out its actual content.
    if frame.OlympusCrest then frame.OlympusCrest:Hide() end
    if not frame.ChatWardenHeaderHidden and frame.GetRegions and trim~=false then
        for _,region in ipairs({frame:GetRegions()}) do
            if region.GetObjectType and region:GetObjectType()=='FontString' and region.GetPoint then local _,_,_,_,y=region:GetPoint();if y and y>=-65 then region:Hide() end end
        end
        frame.ChatWardenHeaderHidden=true
    end
    W.Tabs({})
    if frame.SetFixedFrameStrata then frame:SetFixedFrameStrata(false);frame:SetFixedFrameLevel(false) end
    frame:SetParent(W.legacyHost);frame:SetFrameStrata('DIALOG');frame:SetFrameLevel(W.legacyHost:GetFrameLevel()+1)
    local top,scale=0,1
    if frame.ChatWardenLayout then W.LayoutMounted()
    else
        local width,height=frame:GetWidth(),frame:GetHeight();top=trim==false and 0 or 64
        scale=math.min(1.15,1136/width,W.canvas:GetHeight()/math.max(1,height-top))
        frame:SetScale(scale);frame:ClearAllPoints();frame:SetPoint('TOPLEFT',(1140/scale-width)/2,0)
    end
    W.legacyHost:SetScrollChild(frame);W.legacyHost:SetVerticalScroll(top*scale);W.legacyHost:Show()
    if frame.ChatWardenTitle then W.heading:SetText(frame.ChatWardenTitle) end
    frame:Show();W.StyleTree(frame);Fit();W.window:Show();T.FocusWindow(W.window)
    if not frame.ChatWardenWorkspaceHide then
        frame.ChatWardenWorkspaceHide=true;frame:HookScript('OnHide',function() if not W.switching and W.mounted==frame and W.window:IsShown() then W.mounted=nil;W.Open(id) end end)
    end
end
function W.SettingsSub(key)
    local owner=(key=='shield' or key=='spam') and 'shield' or key=='notifications' and 'alerts' or key=='chronicle' and 'history' or 'chat'
    if not ns.Modules.Enabled(owner) then W.Open('modules');return end
    ns.BuildOptions(key);local panels={general=ns.OptionsPanel,languages=ns.LanguageOptionsPanel,shield=ns.ShieldOptionsPanel,spam=ns.SpamOptionsPanel,notifications=ns.NotificationOptionsPanel,spelling=ns.SpellingOptionsPanel,chronicle=ns.ChronicleOptionsPanel}
    local panel=panels[key];if not panel then W.Open('settings');ShowStatus('This settings page is unavailable in the current client.');return end
    local destination=owner=='chat' and 'messages' or owner=='shield' and 'shield' or owner=='alerts' and 'mentions' or ns.Modules.Enabled('chronicle') and 'chronicle' or 'intel'
    W.activeSetting=key;W.pending=destination;W.Embed(panel,destination,true);W.pending=nil
    local names={{'general','Filtering'},{'languages','Languages'},{'shield','Shield'},{'spam','Spam'},{'notifications','Notifications'},{'spelling','Spelling'},{'chronicle','Chronicle & Intel'}};local tabs={}
    for _,spec in ipairs(names) do local id=spec[1];local section=(id=='shield' or id=='spam') and 'shield' or id=='notifications' and 'alerts' or id=='chronicle' and 'history' or 'chat';if section==owner then tabs[#tabs+1]={id,spec[2],function() W.SettingsSub(id) end,180} end end
    W.Tabs(tabs,key)
end
-- Secondary editors use the same workspace host, never scattered addon windows.
T.Window=function(name,parent,width,height)
    local f=V.Panel(UIParent,0,0,width,height,'dark');f:ClearAllPoints();f:SetSize(width,height);f:Hide()
    f.ChatWardenOwned=true;f.ChatWardenToolName=name;f.ChatWardenLegacyRoot=true;return f
end
T.ShowWindow=function(frame)
    if frame==W.window then return nativeShow(frame) end
    local name=frame.ChatWardenToolName or ''
    if not frame.ChatWardenTitle and frame.Heading then frame.ChatWardenTitle=frame.Heading:GetText() end
    local page=W.pending or (name:find('Pack',1,true) and 'packs' or name:find('Categor',1,true) and 'settings' or name:find('Tutorial',1,true) and 'updates' or name:find('Preview',1,true) and 'settings' or 'reports')
    W.Embed(frame,page,true)
end
T.Crest=function(frame,x,y,size)
    local t=V.Texture(frame,'Logo',{0,0,512,512},'OVERLAY');t:SetSize(size or 48,size or 48);t:SetPoint('TOPLEFT',x or 18,y or -10);frame.OlympusCrest=t;return t
end
T.Icon=ns.WardenBrand.Path('Warden')
T.Panel=function(parent,x,y,width,height,paper) return V.Panel(parent,x,y,width,height,'dark') end
T.SkinWindow=function(frame) if not frame.ChatWardenArtFrame then frame.ChatWardenArtFrame=V.Nine(frame,'dark') end end
T.Ink=function(text) text:SetTextColor(.91,.88,.80,1);return text end
T.Heading=function(text) text:SetTextColor(unpack(V.gold));return text end
T.Dropdown=V.Dropdown
T.BindSettings=function(panel) ns.Membership.RegisterSettings(panel) end
local oldSkinRow,oldRowState=T.SkinRow,T.RowState
local oldBody=T.Body
T.Body=function(text) oldBody(text);local path=text:GetFont();if not T.DocumentFont(text,16) then text:SetFont(path,16,'') end;return text end
T.SkinRow=function(row)
    oldSkinRow(row);if row.background then row.background:Hide() end;if row.stripe then row.stripe:Hide() end
    row.ArtNormal=V.Nine(row,'row');row.ArtSelected=V.Nine(row,'selected');row.ArtSelected:SetShown(false)
end
T.RowState=function(row,selected,action) oldRowState(row,selected,action);if row.ArtNormal then row.ArtNormal:SetShown(not selected);row.ArtSelected:SetShown(selected) end end
ns.OpenReview=function(tab) W.Open(tab=='shield' and 'shield' or tab=='capture' and 'capture' or 'messages') end
ns.OpenShield=function() W.Open('shield') end
ns.OpenCapture=function() W.Open('capture') end
ns.OpenRules=function() W.Open('rules') end
ns.OpenPersonal=function(mode) W.Open(mode=='rules' and 'rules' or 'reports') end
ns.OpenReports=function() W.Open('reports') end
ns.OpenUpdates=function() ns.DB.updateSeen=ns.VERSION;W.Open('updates');if W.pages.updates then W.pages.updates:SetRelease(1);W.pages.updates:SetView('notes') end end
function W.Welcome()
    if not ns.DB or not ns.Membership.Allowed() then if ns.Membership then ns.Print(ns.Membership.Status()) end;return end
    if InCombatLockdown and InCombatLockdown() then ns.Print('Open the Warden introduction after combat with /warden welcome.');return end
    if ns.WelcomeWindow then ns.WelcomeWindow:Hide() end
    W.Open('updates');if W.pages.updates then W.pages.updates:SetView('tour') end
    ns.DB.welcomeSeen=1;ns.DB.updateSeen=ns.VERSION
end
ns.OpenWelcome=W.Welcome
ns.OpenShieldPlayer=function(name) if W.Destination('shield') then W.ShieldEditor(name) end end
ns.OpenCapturePlayer=function(name) local p=W.Destination('capture');if not p then return end;p.mode='recent';p.search:SetText(name or '');p:Activate();p:Refresh() end
ns.OpenCaptureBookmark=function(id)
    local p=W.Destination('capture');if not p then return end;p.mode='bookmarks';p.selected=nil;p:Activate();p:Refresh()
    for _,item in ipairs(p.visible) do if item.id==id then p.selected=item;break end end;p:Refresh()
end
ns.OpenTextCoverage=function() W.SettingsSub('general');if ns.CoverageScroll then ns.CoverageScroll:SetVerticalScroll(140) end end
ns.OpenShieldOptions=function() W.SettingsSub('shield') end
ns.OpenSpamOptions=function() W.SettingsSub('spam') end
ns.OpenLanguageOptions=function() W.SettingsSub('languages') end
ns.OpenNotificationOptions=function() W.SettingsSub('notifications') end
ns.OpenSpellingOptions=function() W.SettingsSub('spelling') end
ns.OpenReport=function(...) if not ns.Modules.Enabled('chat') then W.Open('modules');return end;W.pending='reports';original.OpenReport(...);W.pending=nil end
ns.OpenReportLink=function(...) if not ns.Modules.Enabled('chat') then W.Open('modules');return end;W.pending='reports';original.OpenReportLink(...);W.pending=nil end
ns.OpenExport=function(...) if not ns.Modules.Enabled('chat') then W.Open('modules');return end;W.pending='reports';original.OpenExport(...);W.pending=nil end
ns.OpenPacks=function(mode) if not ns.Modules.Enabled('chat') then W.Open('modules');return end;if mode=='import' or mode=='download' then W.pending='packs';original.OpenPacks(mode);W.pending=nil else W.Open('packs') end end
ns.OpenTutorial=function(page) W.Guide(type(page)=='string' and page or 'basics') end
local oldSlash=SlashCmdList.OLYMPUSCHATWARDEN
SlashCmdList.OLYMPUSCHATWARDEN=function(message)
    local command=(message or ''):match('^%s*(%S*)'):lower()
    if command=='' then W.Open(ns.Modules.InitialRoute())
    elseif command=='options' or command=='settings' then W.Open('settings')
    elseif command=='mentions' or command=='alerts' then W.Open('mentions')
    elseif command=='overview' then W.Open('overview') else oldSlash(message) end
end
local toast
function ns.HideMentionToast() if toast then toast:Hide() end end
function ns.ShowMentionToast(item)
    if ns.DB.alertsEnabled==false then return end
    if not toast then
        toast=V.Panel(UIParent,0,0,390,94,'dark');toast:ClearAllPoints();toast:SetPoint('TOP',UIParent,'TOP',0,-110);toast:SetFrameStrata('TOOLTIP')
        V.Icon(toast,'event:mentions',46,14,-18);toast.title=V.Text(toast,'',70,-17,300,15,V.gold);toast.preview=V.Text(toast,'',70,-43,300,12)
        toast:EnableMouse(true);toast:SetScript('OnMouseUp',function() toast:Hide();W.Open('mentions') end)
    end
    toast.title:SetText(Plain(A.DisplayName(item.sender)..' mentioned you'));toast.preview:SetText(Plain((item.preview or ''):sub(1,180)))
    toast.generation=(toast.generation or 0)+1;local generation=toast.generation;toast:Show()
    if C_Timer and C_Timer.After then C_Timer.After(5,function() if toast.generation==generation then toast:Hide() end end) end
end
local wantedToast
function ns.HideWantedToast() if wantedToast then wantedToast:Hide() end end
function ns.ShowWantedToast(item)
    if not ns.Wanted.Active() or not item.wanted or not ns.Wanted.ValidRecord(item.wanted) then return end
    if not wantedToast then
        wantedToast=V.Panel(UIParent,0,0,390,94,'dark');wantedToast:ClearAllPoints();wantedToast:SetPoint('TOP',UIParent,'TOP',0,-214);wantedToast:SetFrameStrata('TOOLTIP')
        V.Icon(wantedToast,'event:reports',42,18,-22)
        wantedToast.title=V.Text(wantedToast,'',76,-18,292,15,V.gold);wantedToast.title:SetHeight(20);wantedToast.title:SetWordWrap(false)
        wantedToast.detail=V.Text(wantedToast,'',76,-43,292,12,V.muted);wantedToast.detail:SetHeight(34)
        wantedToast:EnableMouse(true);wantedToast:SetScript('OnMouseUp',function(_,button)
            if button=='RightButton' then wantedToast:Hide();return end
            if InCombatLockdown and InCombatLockdown() then ns.Print('Open this alert in Alerts after combat.');return end
            local selected=wantedToast.item;wantedToast:Hide()
            local page=W.Destination('mentions');if not page then return end;page.mode='all';page.selected=selected;page:Activate();page:Refresh()
        end)
    end
    wantedToast.item=item
    wantedToast.title:SetText(W.NameText(item,wantedToast.title,false))
    wantedToast.detail:SetText((item.wanted.kind=='encounter' and 'Wanted player encountered' or 'Wanted player mentioned')..'\nBounty: '..item.wanted.bounty..' points')
    wantedToast.generation=(wantedToast.generation or 0)+1;local generation=wantedToast.generation;wantedToast:Show()
    if C_Timer and C_Timer.After then C_Timer.After(6,function() if wantedToast.generation==generation then wantedToast:Hide() end end) end
end
A.Subscribe(W.Queue)
local oldCaptureChanged=ns.ChatCapture.Changed
ns.ChatCapture.Changed=function() oldCaptureChanged();W.Queue() end
local oldPersonalRefresh=ns.RefreshPersonal
ns.RefreshPersonal=function() oldPersonalRefresh();W.Queue() end
local oldPolicyChanged=ns.PolicyChanged
ns.PolicyChanged=function(...) oldPolicyChanged(...);W.Queue() end
local oldSyncPacks=ns.SyncPacks
ns.SyncPacks=function(...) oldSyncPacks(...);W.Queue() end
function W.SettingsCanvas(panel,key)
    local canvas=CreateFrame('Frame',nil,nil);canvas:SetSize(640,620)
    local art=V.Panel(canvas,8,-8,624,604,'dark');local logo=V.Texture(art,'Logo',{0,0,512,512},'ARTWORK');logo:SetSize(122,122);logo:SetPoint('TOPLEFT',250,-40)
    V.Text(art,'Olympus Warden',28,-195,570,25,V.gold)
    V.Text(art,'All Warden sections and settings share this workspace.',28,-241,570,15)
    W.nativeMaster=V.Check(art,'Enable ChatWarden',60,-292,ns.DB.enabled,function(value) if ns.Membership.Allowed() then ns.DB.enabled=value;ns.PolicyChanged();W.Queue() end end,504)
    canvas:HookScript('OnShow',function() W.nativeMaster:SetChecked(ns.DB.enabled) end)
    V.Button(art,'Open Warden settings',60,-350,504,44,function()
        if SettingsPanel and not (SettingsPanel.IsProtected and SettingsPanel:IsProtected()) then SettingsPanel:Hide() end
        W.SettingsSub(key or 'general')
    end)
    T.BindSettings(canvas);return canvas
end
local hideAll=T.HideAll
T.HideAll=function() hideAll();if toast then toast:Hide() end;if wantedToast then wantedToast:Hide() end;V.CloseMenus() end
