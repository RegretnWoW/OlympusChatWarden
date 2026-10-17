-- A fixed header and controls leave the stock Olympus height to a virtualized alert list.
local _,ns=...
local V,C,A=ns.Art,ns.OlympusConnection,ns.Activity
local P={pages={},queued=false};ns.OlympusPanel=P
local bronze={.91,.77,.58};local muted={.70,.73,.76}
local specs={{'filtering','Chat','ChatWarden','messages'}, {'shield','Shield','ShieldWarden','shield'},
    {'mentions','Signals','SignalWarden','mentions'}, {'chronicle','Record','ChronicleWarden','chronicle'}}
local filters={{'all','All','overview'},{'signals','Signals','mentions'},{'shield','Shield','shield'},{'intel','Intel','intel'},{'chronicle','Chronicle','chronicle'}}
local function Busy() return InCombatLockdown and InCombatLockdown() end
local function Open(id,item)
    if Busy() then ns.Print('Open Warden after combat.');return end
    if not ns.Membership.Allowed() then ns.Print(ns.Membership.Status());return end
    ns.Workspace.Open(id)
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
    if key=='filtering' then return ns.DB.enabled==true end
    if key=='shield' then return ns.DB.shield and ns.DB.shield.enabled==true end
    if key=='mentions' then return ns.DB.alertsEnabled~=false and (ns.Mentions.db.enabled or ns.Wanted.db.enabled) end
    return ns.Chronicle.Active()
end
local function Module(item)
    if item.wardenModule then return item.wardenModule end
    local c=item.categories or {}
    if c.wanted or c.mentions or c.olympusmute then return 'signals','SignalWarden','mentions' end
    if c.shield then return 'shield','ShieldWarden','shield' end
    return 'chat','ChatWarden','messages'
end
function P.Entries(filter)
    local entries={}
    for _,item in ipairs(A.List()) do
        local category=Module(item)
        if filter=='all' or filter==category then entries[#entries+1]=item end
    end
    local H=ns.ChronicleActivities;local owner=ns.Chronicle.Owner();local st,status
    if filter=='all' or filter=='intel' or filter=='chronicle' then st,status=H.Request(owner) end
    if st and st.intelligence then
        for _,module in ipairs({'intel','chronicle'}) do if filter=='all' or filter==module then
            local list=st.intelligence.recent[module]
            for n=#list,math.max(1,#list-23),-1 do
                local r=list[n];local e=r.event;local title=ns.RecordingUI.Title(e)
                if module=='intel' and e.kind=='player_observed' then title='Important player observed' end
                if module=='intel' and e.details.recordType=='native_kill_credit' then title='Native credit observation' end
                entries[#entries+1]={id='record:'..e.id,wardenModule=module,event=e,guid=r.guid,owner=owner,timestamp=e.at,
                    sender=module=='intel' and H.Name(st,r.guid,e.at) or ns.WardenUI.Highlight(e).title,preview=title,categories={},state=st}
            end
        end end
        if filter=='all' or filter=='chronicle' then
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
    return entries,status,st
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
    Place(v.hero,0,0,cw,38)
    Place(v.logo,10,5,28,28)
    Label(v.heading,46,3,cw-144,21);Label(v.connection,46,24,cw-144,13)
    Place(v.target,cw-92,7,80,24)
    local y=42
    v.notice:SetShown(not ns.Membership.Allowed())
    if not ns.Membership.Allowed() then Label(v.notice,18,y,cw-36,64,true);y=y+72 end
    for i,card in ipairs(v.features) do
        Place(card,(i-1)*cw/4,y,cw/4,36)
        Place(card.toggle,7,3,24,24);card.toggle.Icon:SetSize(24,24)
        Label(card.label,35,2,cw/4-37,14);Label(card.caption,35,18,cw/4-37,13)
    end
    y=y+39
    for n,b in ipairs(v.filters) do Place(b,(n-1)*cw/5,y,cw/5-2,24);b.Caption:SetWidth(cw/5-8) end
    y=y+28
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
    row.icon.ChatWardenIconBox={size=24,x=12,y=-(row:GetHeight()-24)/2}
    Label(row.title,44,7,width-111,17);Label(row.preview,44,27,width-50,15)
    Label(row.meta,width-62,8,36,14);row.meta:SetTextColor(.70,.73,.76)
    row.summary=item.event and item.preview or A.EventLabel(item) or 'Recent Activity'
    row.preview:SetText((({ChatWarden='Chat',SignalWarden='Signal',ShieldWarden='Shield',IntelWarden='Intel',ChronicleWarden='Chronicle'})[brand])..' • '..row.summary:gsub('Shield Alert','Shield'):gsub('Language Filter','Language'):gsub('Hidden Message','Hidden'):gsub('Redacted Message','Redacted'))
    local text,covered=ns.Workspace.NameText(item,row.title,row.revealed);row.title:SetText(text);row.covered=covered
    row.meta:SetText(item.timestamp and ns.SafeCall(date,'%H:%M',item.timestamp) or '')
    V.SetIcon(row.icon,category);row.unread:SetShown(not item.event and A.EntryUnread(item))
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
        local standby=on and not ns.DB.enabled and (key=='shield' or key=='mentions')
        card.on=on and not standby
        card.state=not allowed and 'Locked' or standby and 'Standby' or on and 'On' or 'Paused'
        V.SetIcon(card.toggle.Icon,spec[4]);card.toggle:SetEnabled(allowed);card.toggle.Icon:SetAlpha(on and not standby and 1 or .4)
        card.label:SetText(spec[2]);card.caption:SetText(card.state);card.caption:SetTextColor(unpack(on and not standby and V.blue or muted))
        card.unread=allowed and key~='chronicle' and A.Unread(key=='mentions' and 'alerts' or spec[4]) or 0
    end
    for n,b in ipairs(v.filters) do b:SetEnabled(allowed);b.Selected:SetShown(filters[n][1]==v.filter) end
    local entries,status,st
    if allowed then entries,status,st=P.Entries(v.filter) else entries={} end
    v.indexStatus=status;v.indexState=st
    v.listView:SetItems(entries,true)
    local heading=({all='All activity',signals='Signals',shield='Shield activity',intel='Intel activity',chronicle='Chronicle highlights'})[v.filter]
    local unread=allowed and (v.filter=='all' and A.Unread() or v.filter=='signals' and A.Unread('alerts') or v.filter=='shield' and A.Unread('shield'))
    v.activityHeading:SetText(heading..(unread and ' • '..unread..' unread' or ''))
    v.empty:SetShown(#entries==0)
    v.empty:SetText(allowed and 'No recent Warden activity in this view.\n\nProtection and recording status appear above. Right-click a filter to open its full module.' or 'Your activity stays saved. Grant Olympus access to resume protection.')
    if allowed and status=='building' then local done,total=ns.ChronicleActivities.Progress();v.empty:SetText('Reading saved history…\n'..done..' of '..total..' records indexed.\n\nMeaningful events appear when the index is ready.') end
    local target=ns.SafeCall(UnitGUID,'target');v.target:SetEnabled(allowed and ns.ChronicleStore.GUID(target)~=nil and target~=ns.SafeCall(UnitGUID,'player') and ns.Chronicle.Profile(target)~=nil)
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
    v.target=V.Button(v.hero,'My target',0,0,80,24,function()
        if Busy() or not ns.Membership.Allowed() then return end
        local guid=ns.SafeCall(UnitGUID,'target');if guid==ns.SafeCall(UnitGUID,'player') or not ns.Chronicle.Profile(guid) then return end
        ns.WardenUI.Navigate('player',ns.Chronicle.Owner(),guid)
    end,'neutral')
    ns.Theme.Tooltip(v.target,'My target','Open this exact player’s retained dossier. Disabled when there is no recorded player profile. This shortcut never records or inspects anyone.')
    v.features={}
    for i,spec in ipairs(specs) do
        local key=spec[1];local card=CreateFrame('Frame',nil,v.content);v.features[i]=card;card.feature=key
        card.label=Text(card,spec[2],11,bronze);card.caption=Text(card,'',11,muted)
        card.toggle=V.IconButton(card,spec[4],24,0,0,function(_,button)
            if Busy() or not ns.Membership.Allowed() then return end
            if button=='RightButton' or key=='chronicle' then Open(spec[4])
            else ns.Workspace.ToggleFeature(key);P.Queue() end
        end,spec[3],key=='chronicle' and 'Open ChronicleWarden. Recording remains your choice in Data & Backups.' or 'Click to enable or pause. Right-click to open the full module.')
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
        end,'neutral');b:RegisterForClicks('LeftButtonUp','RightButtonUp');b.Selected=V.Nine(b,'selected');v.filters[n]=b
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
    v.open=V.Button(page,'Open Warden',10,0,280,32,function() Open('overview') end,'button')
    v.open:ClearAllPoints();v.open:SetPoint('BOTTOMLEFT',10,7);v.open:SetPoint('BOTTOMRIGHT',-10,7)
    page:HookScript('OnSizeChanged',function() P.Refresh(page) end);page:HookScript('OnShow',function() P.Refresh(page) end)
    page:HookScript('OnHide',function() v.indexState=nil;v.entries=nil;v.listView:SetItems({}) end)
    P.Refresh(page)
    page:HookScript('OnUpdate',function(_,elapsed)
        v.tick=(v.tick or 0)+elapsed;if v.tick<1 or Busy() then return end;v.tick=0
        local owner=ns.Chronicle.Owner();local c=owner and ns.ChronicleStore.Character(owner,false)
        local revision=c and c.revision;local count=c and #c.events or 0
        local target=ns.SafeCall(UnitGUID,'target');local active=ns.Chronicle.Active()
        local st,status
        if v.filter=='all' or v.filter=='intel' or v.filter=='chronicle' then st,status=ns.ChronicleActivities.Request(owner) end
        if v.count~=count or v.revision~=revision or v.lastTarget~=target or v.recording~=active or v.indexState~=st or v.indexStatus~=status then
            v.count=count;v.revision=revision;v.lastTarget=target;v.recording=active;P.Refresh(page)
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
