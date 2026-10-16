-- A fixed header and controls leave the stock Olympus height to a virtualized alert list.
local _,ns=...
local V,C,A=ns.Art,ns.OlympusConnection,ns.Activity
local P={pages={},queued=false};ns.OlympusPanel=P
local bronze={.91,.77,.58};local muted={.70,.73,.76}
local specs={{'filtering','Filtering','enabled','messages'}, {'shield','Shield','shieldActive','shield'},
    {'mentions','Alerts','mentions','alerts'}, {'capture','Capture','capture','capture'}}
local off={filtering='enabledOff',shield='shieldOff',mentions='mentionsOff',capture='captureOff'}
local function Busy() return InCombatLockdown and InCombatLockdown() end
local function Open(id,item)
    if Busy() then ns.Print('Open ChatWarden after combat.');return end
    if not ns.Membership.Allowed() then ns.Print(ns.Membership.Status());return end
    ns.Workspace.Open(id)
    if item then local page=ns.Workspace.pages[id];if page then
        if id=='mentions' then page.mode='all';page:Activate() end
        page.selected=item;A.Mark(item.id);page:Refresh()
    end end
end
local function Text(parent,text,size,color)
    local t=V.Text(parent,text,0,0,10,size or 12,color or muted);t:ClearAllPoints();return t
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
    return ns.ChatCapture.db and ns.ChatCapture.db.enabled==true
end
function P.Layout(page)
    local width,height=ns.SafeNumber(page:GetWidth()) or 0,ns.SafeNumber(page:GetHeight()) or 0
    if width<160 or height<180 then return end
    local v=page.warden;local cw=width-20
    Place(v.content,10,6,cw,height-12)
    Place(v.hero,0,0,cw,58)
    Place(v.logo,cw-50,13,32,32)
    Label(v.heading,22,20,cw-80,20)
    local y=60
    v.notice:SetShown(not ns.Membership.Allowed())
    if not ns.Membership.Allowed() then Label(v.notice,18,y,cw-36,64,true);y=y+72 end
    for i,card in ipairs(v.features) do
        Place(card,(i-1)*cw/4,y,cw/4,30)
        Place(card.toggle,(cw/4-30)/2,0,30,30);card.toggle.Icon:SetSize(30,30)
    end
    y=y+32
    local activityH=math.max(70,height-y-52)
    Place(v.activity,0,y,cw,activityH);Label(v.activityHeading,18,12,cw-36,20)
    Label(v.empty,18,45,cw-52,math.max(20,activityH-58),true)
    v.listView:Resize(cw-44,math.max(20,activityH-46))
    v.open.Caption:SetWidth(width-44)
end
local function BindRow(page,row,item)
    local width=row:GetWidth()
    if row.id~=item.id then row.revealed=false;row:Select(false) end
    row.id,row.item=item.id,item
    row.category=(item.categories.wanted or item.categories.mentions) and 'mentions' or item.categories.messages and 'messages' or 'shield'
    -- V.SetIcon refits from this box; changing texture points alone would restore
    -- the full workspace row's larger icon and lower position on every refresh.
    row.icon.ChatWardenIconBox={size=24,x=12,y=-(row:GetHeight()-24)/2}
    Label(row.title,44,10,width-78,16);Label(row.preview,44,28,width-58,14);row.meta:Hide()
    row.summary=A.EventLabel(item) or 'Recent Activity'
    row.preview:SetText(row.summary:gsub('Shield Alert','Shield'):gsub('Language Filter','Language'):gsub('Hidden Message','Hidden'):gsub('Redacted Message','Redacted'))
    local text,covered=ns.Workspace.NameText(item,row.title,row.revealed);row.title:SetText(text);row.covered=covered
    row.meta:SetText(ns.Workspace.ActivityChannel(item)..'  |  '..(item.timestamp and ns.SafeCall(date,'%H:%M',item.timestamp) or 'This session'))
    V.SetIcon(row.icon,ns.Workspace.ActivityIcon(item));row.unread:SetShown(A.EntryUnread(item))
    row:SetEnabled(ns.Membership.Allowed())
end
function P.Refresh(page)
    local v=page.warden;if not v or not ns.DB then return end
    P.Layout(page)
    local allowed=ns.Membership.Allowed();local profile=C.Profile();local own=profile and profile.member and profile
    local name=own and own.name or ns.Mentions.Character() or 'Your character';name=name:match('^(.-)%-') or name
    v.identity=name;v.notice:SetText(C.Reason())
    for i,card in ipairs(v.features) do
        local spec=specs[i];local key=spec[1];local on=FeatureOn(key)
        local standby=on and not ns.DB.enabled and (key=='shield' or key=='mentions')
        card.state=not allowed and 'Locked' or standby and 'Standby' or key=='capture' and (on and 'Recording' or 'Paused') or on and 'On' or 'Paused'
        V.SetIcon(card.toggle.Icon,on and spec[3] or off[key]);card.toggle:SetEnabled(allowed);card.toggle.Icon:SetAlpha(standby and .5 or 1)
        card.Badge:SetCount(allowed and A.Unread(spec[4]) or 0)
    end
    local entries={}
    if allowed then for _,item in ipairs(A.List()) do
        local c=item.categories
        if c and (c.messages or c.mentions or c.shield or c.wanted) then entries[#entries+1]=item end
    end end
    v.listView:SetItems(entries,true)
    v.empty:SetShown(#entries==0)
    v.empty:SetText(allowed and 'New filtering, personal alerts and Shield activity appear here.' or 'Your activity stays saved. Grant Olympus access to resume protection.')
    v.open:SetEnabled(allowed)
    if ns.OlympusIntegration then ns.OlympusIntegration.HookNativeTabRoot(page:GetParent()) end
end
function P.Build(page)
    if page.warden then return end
    local v={};page.warden=v;P.pages[#P.pages+1]=page
    v.back=page:CreateTexture(nil,'BACKGROUND');v.back:SetAllPoints();v.back:SetColorTexture(.055,.075,.10,1)
    v.content=CreateFrame('Frame',nil,page);v.content:SetSize(280,360)
    v.hero=V.Panel(v.content,0,0,280,68,'header');v.logo=V.Texture(v.hero,'Logo',{0,0,512,512},'ARTWORK')
    v.heading=Text(v.hero,'ChatWarden',18,bronze);v.notice=Text(v.content,'',12,bronze)
    v.features={}
    for i,spec in ipairs(specs) do
        local key=spec[1];local card=CreateFrame('Frame',nil,v.content);v.features[i]=card;card.feature=key
        card.toggle=V.IconButton(card,spec[3],30,0,0,function()
            if not Busy() and ns.Membership.Allowed() then ns.Workspace.ToggleFeature(key);P.Queue() end
        end,spec[2],'Click to enable or pause '..spec[2]..'.')
        card.toggle:HookScript('OnEnter',function()
            if GameTooltip then GameTooltip:AddLine(card.state or '',.9,.9,.85,true);GameTooltip:Show() end
        end)
        card.Badge=V.Badge(card.toggle,4,4);card.Badge:SetScale(.55);card.Badge:EnableMouse(false)
    end
    v.activity=V.Panel(v.content,0,0,280,180,'dark');v.activityHeading=Text(v.activity,'Recent Activity',15,bronze);v.empty=Text(v.activity,'',12,muted)
    v.listView=V.ScrollingList(v.activity,12,-34,236,134,54,function(parent)
        local row=V.Row(parent,0,function() end);row:SetHeight(50)
        for _,spec in ipairs({{row.title,13},{row.preview,11}}) do
            spec[1].ChatWardenFontSize=spec[2];local path=spec[1]:GetFont()
            if not ns.Theme.DocumentFont(spec[1],spec[2]) then spec[1]:SetFont(path,spec[2],'') end
        end
        row:SetScript('OnClick',function(self,button)
            if not self.item then return end
            if (button==nil or button=='LeftButton') and ns.Checked(ns.SafeCall(IsControlKeyDown)) and (self.covered or self.revealed) then
                self.revealed=not self.revealed;BindRow(page,self,self.item)
            else Open(self.category,self.item) end
        end)
        ns.Theme.Tooltip(row,'Recent Activity','Open this entry in ChatWarden. Ctrl + left-click reveals a covered player name.')
        row:HookScript('OnEnter',function(self)
            self:Select(true)
            if GameTooltip and self.item then GameTooltip:AddLine(self.summary or '',.91,.77,.58,true);GameTooltip:AddLine(self.meta:GetText() or '',.7,.73,.76,true);GameTooltip:Show() end
        end)
        row:HookScript('OnLeave',function(self) self:Select(false) end)
        return row
    end,function(row,item) BindRow(page,row,item) end)
    v.rows=v.listView.rows
    v.open=V.Button(page,'Open ChatWarden',10,0,280,32,function() Open('overview') end,'button')
    v.open:ClearAllPoints();v.open:SetPoint('BOTTOMLEFT',10,7);v.open:SetPoint('BOTTOMRIGHT',-10,7)
    page:HookScript('OnSizeChanged',function() P.Refresh(page) end);page:HookScript('OnShow',function() P.Refresh(page) end)
    P.Refresh(page)
end
function P.Queue()
    if P.queued then return end;P.queued=true
    local function Run() P.queued=false;for _,page in ipairs(P.pages) do if page:IsShown() then P.Refresh(page) end end end
    if C_Timer and C_Timer.After then C_Timer.After(0,Run) else Run() end
end
function P.Ensure()
    if P.attempted or Busy() or not ns.DB or not C.Ensure() or not C.HasSurface() then return end
    P.attempted=true
    local ok,why=C.RegisterSurface({label='ChatWarden',icon=ns.Theme.Icon,
        portrait='Interface\\AddOns\\OlympusChatWarden\\Media\\V5\\Logo.tga',
        availableWhenLocked=true,visible=function() return ns.DB~=nil end,build=P.Build,refresh=P.Refresh,
        help=function() ns.Print(C.Reason());if ns.Membership.Allowed() then ns.Workspace.Guide('basics') end end})
    if not ok and why=='unavailable' then P.attempted=nil end
end
C.Subscribe(function()
    if ns.OlympusIntegration then ns.OlympusIntegration.Refresh() end
    C.RefreshSurface();P.Queue()
    if ns.Workspace and ns.Workspace.window then ns.Workspace.Queue() end
end)
