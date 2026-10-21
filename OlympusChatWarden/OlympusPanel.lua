-- A fixed header and controls leave the stock Olympus height to a virtualized alert list.
local _,ns=...
local V,C,A=ns.Art,ns.OlympusConnection,ns.Activity
local P={pages={},queued=false};ns.OlympusPanel=P
local bronze={.91,.77,.58};local muted={.70,.73,.76}
local specs={{'filtering','Chat','ChatWarden','messages'}, {'shield','Shield','ShieldWarden','shield'},
    {'mentions','Signals','SignalWarden','mentions'}, {'chronicle','Record','ChronicleWarden','chronicle'}, {'intel','Intel','IntelWarden','intel'}}
local filters={{'all','All','overview'},{'chat','Chat','messages'},{'signals','Signals','mentions'},{'shield','Shield','shield'},{'intel','Intel','intel'},{'chronicle','Chronicle','chronicle'}}
local function Owner(key) return key=='filtering' and 'chat' or key=='mentions' and 'alerts' or key end
local function WantsHistory(filter)
    return filter=='all' and ns.Modules.Enabled('history') or filter=='intel' and ns.Modules.Enabled('intel') or filter=='chronicle' and ns.Modules.Enabled('chronicle')
end
local function NeedsHistory(filter)
    return WantsHistory(filter)
        and ns.Membership.Allowed() and not ns.ChronicleStore.loading and not ns.ChronicleStore.blocked
end
local function Busy() return InCombatLockdown and InCombatLockdown() end
local function Open(id,item)
    if Busy() then ns.Print('Open Warden after combat.');return end
    if not ns.Membership.Allowed() then ns.Print(ns.Membership.Status());return end
    if not ns.Workspace.Open(id) then return end
    if item then local page=ns.Workspace.pages[id];if page then
        if id=='mentions' then page.mode='all';page:Activate() end
        page.selected=item;A.Mark(item.id);page:Refresh()
    end end
end
local function Text(parent,text,size,color)
    local t=V.Text(parent,text,0,0,10,size or 12,color or muted);t:ClearAllPoints()
    if size and size<12 then t.ChatWardenFontSize=size;local path=t:GetFont();if not ns.Theme.DocumentFont(t,size) then t:SetFont(path,size,'') end end
    return t
end
local function Place(frame,x,y,w,h)
    frame:ClearAllPoints();frame:SetPoint('TOPLEFT',x,-y);frame:SetSize(w,h)
end
local function Label(t,x,y,w,h,wrap)
    Place(t,x,y,w,h);t:SetWordWrap(wrap==true);t:SetJustifyV('TOP')
    if t.SetMaxLines then t:SetMaxLines(wrap and math.max(1,math.floor(h/((t.ChatWardenFontSize or 12)+3))) or 1) end
end
local function FeatureOn(key)
    if key=='filtering' then return ns.Modules.Enabled('chat') and ns.DB.enabled==true end
    if key=='shield' then return ns.Modules.Enabled('shield') and ns.DB.shield and ns.DB.shield.enabled==true end
    if key=='mentions' then return ns.Modules.Enabled('alerts') and ns.DB.alertsEnabled~=false and ((ns.Mentions.db and ns.Mentions.db.enabled) or (ns.Wanted.db and ns.Wanted.db.enabled)) end
    if key=='intel' then return ns.Modules.Enabled('intel') end
    return ns.Modules.Enabled('chronicle') and ns.Chronicle.Active()
end
local function Module(item)
    if item.wardenModule then return item.wardenModule end
    local c=item.categories or {}
    if c.wanted or c.mentions or c.olympusmute then return 'signals','SignalWarden','mentions' end
    if c.shield then return 'shield','ShieldWarden','shield' end
    return 'chat','ChatWarden','messages'
end
function P.Entries(filter)
    local entries={};local unread=0
    for _,item in ipairs(A.List()) do
        local category=Module(item)
        local owner=category=='signals' and 'alerts' or category
        if ns.Modules.Enabled(owner) and (filter=='all' or filter==category) then entries[#entries+1]=item;if A.EntryUnread(item) then unread=unread+1 end end
    end
    local H=ns.ChronicleActivities;local owner,st,status
    if NeedsHistory(filter) then owner=ns.Chronicle.Owner();st,status=H.Request(owner) end
    if st and st.intelligence then
        for _,module in ipairs({'intel','chronicle'}) do if ns.Modules.Enabled(module) and (filter=='all' or filter==module) then
            local list=st.intelligence.recent[module]
            for n=#list,math.max(1,#list-23),-1 do
                local r=list[n];local e=r.event;local title=ns.RecordingUI.Title(e)
                if module=='intel' and e.kind=='player_observed' then title='Important player observed' end
                if module=='intel' and e.details.recordType=='native_kill_credit' then title='Native credit observation' end
                entries[#entries+1]={id='record:'..e.id,wardenModule=module,event=e,guid=r.guid,owner=owner,timestamp=e.at,
                    sender=module=='intel' and H.Name(st,r.guid,e.at) or ns.WardenUI.Highlight(e).title,preview=title,categories={},state=st}
            end
        end end
        if ns.Modules.Enabled('chronicle') and (filter=='all' or filter=='chronicle') then
            for n=#st.activities,math.max(1,#st.activities-23),-1 do
                local a=st.activities[n]
                if a.kind~='group' then
                    local e=st.events[a.anchor] or st.intelligence.events[a.anchor]
                    if e then entries[#entries+1]={id='activity:'..a.id,wardenModule='chronicle',event=e,activity=a,owner=owner,timestamp=a.startAt,
                        sender=ns.ChronicleActivitiesUI.Title(a),preview='Recorded '..a.kind..' segment',categories={},state=st} end
                end
            end
        end
    end
    table.sort(entries,function(a,b) local at,bt=a.timestamp or 0,b.timestamp or 0;return at>bt or at==bt and a.id<b.id end)
    while #entries>100 do table.remove(entries) end
    return entries,status,st,unread
end
function P.OpenRecord(item)
    if not item or not item.event or Busy() or not ns.Membership.Allowed() then return end
    if item.wardenModule=='intel' then return ns.WardenUI.Navigate('player',item.owner,item.guid or item.event.subject,item.event) end
    if item.activity then return ns.WardenUI.Navigate('activity',item.owner,item.activity.id,item.event) end
    return ns.WardenUI.Navigate('highlight',item.owner,item.event.id,item.event)
end
function P.Layout(page)
    local width,height=ns.SafeNumber(page:GetWidth()) or 0,ns.SafeNumber(page:GetHeight()) or 0
    if width<160 or height<180 then return end
    local v=page.warden;local cw=width-20
    Place(v.content,10,6,cw,height-12)
    Place(v.hero,0,0,cw,44)
    Place(v.logo,4,0,44,44)
    Label(v.heading,54,4,cw-184,21);Label(v.connection,54,26,cw-184,13)
    Place(v.target,cw-126,10,116,24);v.target.Caption:SetWidth(100)
    local y=48
    v.notice:SetShown(not ns.Membership.Allowed())
    if not ns.Membership.Allowed() then Label(v.notice,18,y,cw-36,64,true);y=y+72 end
    local visible={};for _,card in ipairs(v.features) do card:SetShown(ns.Modules.Enabled(Owner(card.feature)));if card:IsShown() then visible[#visible+1]=card end end
    local cell=#visible>0 and math.min(200,cw/#visible) or cw
    local stacked=cell<88;local iconSize=cw>=520 and 48 or cw>=350 and 44 or 40
    if stacked then iconSize=40 end
    local featureH=stacked and 60 or iconSize+4
    local start=(cw-#visible*cell)/2
    for i,card in ipairs(visible) do
        local spec=card.spec
        Place(card,start+(i-1)*cell,y,cell,featureH)
        local iconX=stacked and (cell-iconSize)/2 or 2
        Place(card.toggle,iconX,2,iconSize,iconSize)
        card.toggle.Icon.ChatWardenIconBox={size=iconSize,x=0,y=0};V.SetIcon(card.toggle.Icon,spec[4])
        local textX=stacked and 0 or iconSize+4;local textWidth=stacked and cell or cell-textX-2
        Label(card.label,textX,stacked and 46 or 6,textWidth,14);card.label:SetJustifyH(stacked and 'CENTER' or 'LEFT')
        Label(card.caption,textX,22,textWidth,14);card.caption:SetShown(not stacked)
        for _,label in ipairs({card.label,card.caption}) do
            local size=11;local path=label:GetFont()
            if not ns.Theme.DocumentFont(label,size) then label:SetFont(path,size,'') end
        end
    end
    if #visible>0 then y=y+featureH+3 end
    local shown={};local valid=false
    for n,b in ipairs(v.filters) do local spec=filters[n];b:SetShown(spec[1]=='all' or ns.Modules.Enabled(spec[3]));if b:IsShown() then shown[#shown+1]=b;if spec[1]==v.filter then valid=true end end end
    if not valid then v.filter='all';v.listView.offset=0;v.listView.scroll:SetVerticalScroll(0) end
    local filterCell=math.min(128,cw/#shown);start=(cw-#shown*filterCell)/2
    for n,b in ipairs(shown) do Place(b,start+(n-1)*filterCell,y,filterCell-2,24);b.Caption:SetWidth(filterCell-8)
        b:SetText(b.filter=='chronicle' and filterCell<60 and 'Log' or b.label)
    end
    if #shown>1 then y=y+28 else shown[1]:Hide() end
    local activityH=math.max(70,height-y-52)
    Place(v.activity,0,y,cw,activityH);Label(v.activityHeading,12,9,cw-24,16)
    Label(v.empty,14,34,cw-42,math.max(20,activityH-42),true)
    v.listView:Resize(cw-40,math.max(20,activityH-33))
    v.open.Caption:SetWidth(width-44)
end
local function BindRow(page,row,item)
    local width=row:GetWidth()
    if row.id~=item.id then row.revealed=false;row:Select(false) end
    row.id,row.item=item.id,item
    local module,brand,category=Module(item)
    if not brand then brand=module=='intel' and 'IntelWarden' or 'ChronicleWarden';category=module end
    row.category=category
    -- V.SetIcon refits from this box; changing texture points alone would restore
    -- the full workspace row's larger icon and lower position on every refresh.
    row.icon.ChatWardenIconBox={size=42,x=6,y=-(row:GetHeight()-42)/2}
    Label(row.title,54,7,width-121,17);Label(row.preview,54,27,width-60,15)
    Label(row.meta,width-62,8,36,14);row.meta:SetTextColor(.70,.73,.76)
    row.summary=item.event and item.preview or A.EventLabel(item) or 'Recent Activity'
    row.preview:SetText((({ChatWarden='Chat',SignalWarden='Signal',ShieldWarden='Shield',IntelWarden='Intel',ChronicleWarden='Chronicle'})[brand])..' • '..row.summary:gsub('Shield Alert','Shield'):gsub('Language Filter','Language'):gsub('Hidden Message','Hidden'):gsub('Redacted Message','Redacted'))
    local text,covered=ns.Workspace.NameText(item,row.title,row.revealed);row.title:SetText(text);row.covered=covered
    row.meta:SetText(item.timestamp and ns.SafeCall(date,'%H:%M',item.timestamp) or '')
    V.SetIcon(row.icon,item.activity and ns.EventIcons.Activity(item.activity) or item.event and ns.EventIcons.Record(item.event) or ns.EventIcons.Chat(item));row.unread:SetShown(not item.event and A.EntryUnread(item))
    row:SetEnabled(ns.Membership.Allowed())
end
function P.Refresh(page)
    local v=page.warden;if not v or not ns.DB then return end
    P.Layout(page)
    local allowed=ns.Membership.Allowed();local profile=C.Profile();local own=profile and profile.member and profile
    local name=own and own.name or ns.Mentions.Character() or 'Your character';name=name:match('^(.-)%-') or name
    v.identity=name;v.notice:SetText(C.Reason())
    v.connection:SetText(allowed and 'Olympus connected' or 'Access needed');v.connection:SetTextColor(unpack(allowed and V.blue or bronze))
    for i,card in ipairs(v.features) do
        local spec=specs[i];local key=spec[1];local on=FeatureOn(key)
        local module=Owner(key)
        card.on=on
        local historical=key=='intel' or key=='chronicle'
        card.state=not allowed and 'Locked' or not ns.Modules.Enabled(module) and 'Module off' or historical and ns.ChronicleStore.loading and 'Loading' or historical and ns.ChronicleStore.blocked and 'Unavailable' or key=='intel' and 'Ready' or on and 'On' or key=='chronicle' and 'Off' or 'Paused'
        V.SetIcon(card.toggle.Icon,spec[4]);card.toggle:SetEnabled(allowed);card.toggle.Icon:SetAlpha(on and 1 or .4)
        V.FeatureState(card.toggle,allowed and on);card.toggle.StateMark:ClearAllPoints();card.toggle.StateMark:SetPoint('BOTTOMRIGHT',0,0)
        card.label:SetText(spec[2]=='Signals' and 'Signal' or spec[2]);card.caption:SetText(card.state=='Module off' and 'Off' or card.state);card.caption:SetTextColor(unpack(on and V.blue or muted))
        card.unread=allowed and key~='chronicle' and A.Unread(key=='mentions' and 'alerts' or spec[4]) or 0
    end
    for n,b in ipairs(v.filters) do b:SetEnabled(allowed);b.Selected:SetShown(filters[n][1]==v.filter) end
    local entries,status,st,unread
    if allowed then entries,status,st,unread=P.Entries(v.filter) else entries={};unread=0 end
    v.indexStatus=status;v.indexState=st
    v.listView:SetItems(entries,true)
    local heading=({all='All activity',chat='Chat activity',signals='Signals',shield='Shield activity',intel='Intel activity',chronicle='Chronicle highlights'})[v.filter]
    v.activityHeading:SetText(heading..(unread and ' • '..unread..' unread' or ''))
    v.empty:SetShown(#entries==0)
    local enabled=ns.Modules.Enabled('chat') or ns.Modules.Enabled('shield') or ns.Modules.Enabled('alerts') or ns.Modules.Enabled('history')
    local chatOnly=ns.Modules.Enabled('chat') and not ns.Modules.Enabled('shield') and not ns.Modules.Enabled('alerts') and not ns.Modules.Enabled('history')
    v.empty:SetText(not allowed and 'Your activity stays saved. Grant Olympus access to resume protection.' or not enabled and 'No optional activity sources are enabled.\n\nOpen CommandWarden to choose modules. Your saved history is kept.' or (v.filter=='chat' or chatOnly) and 'No recent chat activity.\n\nRight-click the Chat crest to open ChatWarden. Chat Capture is separate and stays off until you choose it.' or 'No recent Warden activity in this view.\n\nClick a module crest or right-click a filter to open its full page. Recording remains your choice in Data & Backups.')
    if allowed and status=='building' then v.empty:SetText(ns.ChronicleActivities.ProgressText()..'\n\nMeaningful events appear when the view is ready.') end
    if allowed and WantsHistory(v.filter) and ns.ChronicleStore.loading then v.empty:SetText('Loading retained history. Progress appears in chat.\n\n'..ns.Chronicle.Status())
    elseif allowed and WantsHistory(v.filter) and ns.ChronicleStore.blocked then v.empty:SetText('Saved history is unavailable to this build. Your original archive is preserved.\n\nOpen Relay Data & Backups for recovery information.') end
    local intel=ns.Modules.Enabled('intel');local target=intel and ns.SafeCall(UnitGUID,'target')
    v.target:SetText(intel and 'Inspect target' or 'Command')
    v.target:SetEnabled(allowed and (not intel or ns.WardenLaunchers.CanInspect('target')))
    v.moduleRevision=ns.Modules.revision
    v.historyLoading=not not ns.ChronicleStore.loading;v.historyBlocked=not not ns.ChronicleStore.blocked
    v.open:SetEnabled(allowed)
    if ns.OlympusIntegration then ns.OlympusIntegration.HookNativeTabRoot(page:GetParent()) end
end
function P.Build(page)
    if page.warden then return end
    local v={filter='all'};page.warden=v;P.pages[#P.pages+1]=page
    v.back=page:CreateTexture(nil,'BACKGROUND');v.back:SetAllPoints();v.back:SetColorTexture(.055,.075,.10,1)
    v.content=CreateFrame('Frame',nil,page);v.content:SetSize(280,360)
    v.hero=V.Panel(v.content,0,0,280,38,'dark');v.logo=V.Texture(v.hero,'Warden',{0,0,512,512},'ARTWORK')
    v.heading=Text(v.hero,'Warden',18,bronze);v.connection=Text(v.hero,'',10,muted);v.notice=Text(v.content,'',12,bronze)
    ns.Theme.Tooltip(v.hero,'Olympus connection','Membership and connection details are available in Warden’s top bar.')
    v.hero:HookScript('OnEnter',function() if GameTooltip then GameTooltip:AddLine(C.Reason(),.7,.73,.76,true);GameTooltip:Show() end end)
    v.target=V.Button(v.hero,'Inspect target',0,0,116,24,function()
        if Busy() or not ns.Membership.Allowed() then return end
        if not ns.Modules.Enabled('intel') then Open('overview');return end
        ns.WardenLaunchers.OpenIntel('target',true)
    end,'neutral')
    if not ns.Theme.DocumentFont(v.target.Caption,12) then local path=v.target.Caption:GetFont();v.target.Caption:SetFont(path,12,'') end
    ns.Theme.Tooltip(v.target,'Inspect target','Open a normal Blizzard inspection of your target, then their exact IntelWarden dossier when recorded data arrives. Adventure recording remains opt-in. Without IntelWarden, open CommandWarden.')
    v.features={}
    for i,spec in ipairs(specs) do
        local key=spec[1];local card=CreateFrame('Frame',nil,v.content);v.features[i]=card;card.feature=key;card.spec=spec
        card.label=Text(card,spec[2],11,bronze);card.caption=Text(card,'',11,muted)
        card.toggle=V.IconButton(card,spec[4],32,0,0,function(_,button)
            if Busy() or not ns.Membership.Allowed() then return end
            if not ns.Modules.Enabled(Owner(key)) then Open('modules');return end
            if button=='RightButton' or key=='chronicle' or key=='intel' then Open(spec[4])
            else ns.Workspace.ToggleFeature(key);P.Queue() end
        end,spec[3],(key=='chronicle' or key=='intel') and 'Open this module. Recording remains your separate choice in Data & Backups.' or 'Click to enable or pause. Right-click to open the full module.')
        card.toggle:RegisterForClicks('LeftButtonUp','RightButtonUp')
        card.toggle:HookScript('OnEnter',function()
            if GameTooltip then GameTooltip:AddLine(card.state or '',.9,.9,.85,true);if card.unread and card.unread>0 then GameTooltip:AddLine(card.unread..' unread activity',.7,.73,.76,true) end;GameTooltip:Show() end
        end)
        card.toggle:HookScript('OnLeave',function() card.toggle.Icon:SetAlpha(card.on and 1 or .4) end)
    end
    v.filters={}
    for n,spec in ipairs(filters) do
        local b=V.Button(v.content,spec[2],0,0,52,24,function(_,button)
            if button=='RightButton' then Open(spec[3]) else v.filter=spec[1];v.listView.offset=0;v.listView.scroll:SetVerticalScroll(0);P.Refresh(page) end
        end,'neutral');b:RegisterForClicks('LeftButtonUp','RightButtonUp');b.Selected=V.Nine(b,'selected');b.filter=spec[1];b.label=spec[2];v.filters[n]=b
        local path=b.Caption:GetFont();if not ns.Theme.DocumentFont(b.Caption,11) then b.Caption:SetFont(path,11,'') end
        ns.Theme.Tooltip(b,spec[2],'Click to filter recent activity. Right-click to open '..spec[3]..'.')
    end
    v.activity=V.Panel(v.content,0,0,280,180,'dark');v.activityHeading=Text(v.activity,'Recent activity',12,bronze);v.empty=Text(v.activity,'',12,muted)
    v.listView=V.ScrollingList(v.activity,10,-27,240,141,50,function(parent)
        local row=V.Row(parent,0,function() end);row:SetHeight(46)
        -- This small sapphire marker is an atlas crop, not the new full crest.
        row.unread.Gem:SetTexture('Interface\\AddOns\\OlympusChatWarden\\Media\\V5\\Logo.tga')
        for _,spec in ipairs({{row.title,13},{row.preview,11}}) do
            spec[1].ChatWardenFontSize=spec[2];local path=spec[1]:GetFont()
            if not ns.Theme.DocumentFont(spec[1],spec[2]) then spec[1]:SetFont(path,spec[2],'') end
        end
        row:SetScript('OnClick',function(self,button)
            if not self.item then return end
            if (button==nil or button=='LeftButton') and ns.Checked(ns.SafeCall(IsControlKeyDown)) and (self.covered or self.revealed) then
                self.revealed=not self.revealed;BindRow(page,self,self.item)
            elseif self.item.event then
                P.OpenRecord(self.item)
            else Open(self.category,self.item) end
        end)
        ns.Theme.Tooltip(row,'Recent Activity','Open this entry in Warden. Ctrl + left-click reveals a covered player name.')
        row:HookScript('OnEnter',function(self)
            self:Select(true)
            if GameTooltip and self.item then GameTooltip:AddLine(self.title:GetText() or '',.91,.77,.58,true);GameTooltip:AddLine(self.summary or '',.91,.77,.58,true);GameTooltip:AddLine(self.meta:GetText() or '',.7,.73,.76,true);GameTooltip:Show() end
        end)
        row:HookScript('OnLeave',function(self) self:Select(false) end)
        return row
    end,function(row,item) BindRow(page,row,item) end)
    v.rows=v.listView.rows
    v.open=V.Button(page,'Open CommandWarden',10,0,280,32,function() Open('overview') end,'button')
    v.open:ClearAllPoints();v.open:SetPoint('BOTTOMLEFT',10,7);v.open:SetPoint('BOTTOMRIGHT',-10,7)
    page:HookScript('OnSizeChanged',function() P.Refresh(page) end);page:HookScript('OnShow',function() P.Refresh(page) end)
    page:HookScript('OnHide',function() v.indexState=nil;v.entries=nil;v.listView:SetItems({}) end)
    P.Refresh(page)
    page:HookScript('OnUpdate',function(_,elapsed)
        if not page:IsVisible() then return end
        v.tick=(v.tick or 0)+elapsed;if v.tick<1 or Busy() then return end;v.tick=0
        local owner=NeedsHistory(v.filter) and ns.Chronicle.Owner();local c=owner and ns.ChronicleStore.Character(owner,false)
        local revision=c and c.revision;local count=c and #c.events or 0
        local target=ns.Modules.Enabled('intel') and ns.SafeCall(UnitGUID,'target');local active=ns.Modules.Enabled('history') and ns.Chronicle.Active()
        local progress=NeedsHistory(v.filter) and ns.ChronicleActivities.Progress()
        if v.count~=count or v.revision~=revision or v.lastTarget~=target or v.recording~=active or v.moduleRevision~=ns.Modules.revision or v.indexStatus=='building' and v.progress~=progress or v.historyLoading~=not not ns.ChronicleStore.loading or v.historyBlocked~=not not ns.ChronicleStore.blocked then
            v.count=count;v.revision=revision;v.lastTarget=target;v.recording=active;v.progress=progress;P.Refresh(page)
        end
    end)
end
function P.Queue()
    if P.queued then return end;P.queued=true
    local function Run() P.queued=false;for _,page in ipairs(P.pages) do if page:IsVisible() then P.Refresh(page) end end end
    if C_Timer and C_Timer.After then C_Timer.After(0,Run) else Run() end
end
function P.Ensure()
    if P.attempted or Busy() or not ns.DB or not C.Ensure() or not C.HasSurface() then return end
    P.attempted=true
    local ok,why=C.RegisterSurface({label='Warden',icon=ns.Theme.Icon,
        portrait=ns.WardenBrand.Path('Warden'),
        availableWhenLocked=true,visible=function() return ns.DB~=nil end,build=P.Build,refresh=P.Refresh,
        help=function() ns.Print(C.Reason());if ns.Membership.Allowed() then ns.Workspace.Guide('basics') end end})
    if not ok and why=='unavailable' then P.attempted=nil end
end
C.Subscribe(function()
    if ns.OlympusIntegration then ns.OlympusIntegration.Refresh() end
    C.RefreshSurface();P.Queue()
    if ns.Workspace and ns.Workspace.window then ns.Workspace.Queue() end
end)
