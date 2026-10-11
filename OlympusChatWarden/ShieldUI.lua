local _,ns=...
local T,S=ns.Theme,ns.Shield
local panel,rows,listTitle,empty,previous,nextPage,pager,status,details,scroll,heading,nameBox,remove,allow,add,footer
local view,page,query,durationValue='alerts',1,'',900
local selected
local PAGE_SIZE=9
local function Plain(text) return (text or ''):gsub('|','||') end
local function Text(parent,x,y,width,text,font,paper)
    local t=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall')
    t:SetPoint('TOPLEFT',x,y);t:SetWidth(width);t:SetJustifyH('LEFT');t:SetText(text or '')
    if paper then T.Ink(t) else T.Light(t) end;return t
end
local function Button(parent,label,width,x,y,fn,help)
    local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
    b:SetSize(width,24);b:SetPoint('TOPLEFT',x,y);b:SetText(label);b:SetScript('OnClick',fn)
    if help then T.Tooltip(b,label,help) end;return b
end
local function Duration(item)
    if item.session then return 'Until you log out or reload' end
    if item.expires==0 then return 'Until you remove it' end
    local now=ns.SafeNumber(ns.SafeCall(GetServerTime)) or ns.SafeNumber(ns.SafeCall(time)) or item.expires
    return math.max(1,math.ceil((item.expires-now)/60))..' minutes left'
end
local function Contact(name)
    local key=S.Key(name)
    for _,item in ipairs(S.List()) do if item.key==key then return item end end
end
local function Items()
    local source={}
    if view=='alerts' then source=S.alerts
    else
        source=S.List()
        for key,name in pairs(ns.DB.shield.allowed) do source[#source+1]={key=key,name=name,allowed=true} end
        table.sort(source,function(a,b) return a.key<b.key end)
    end
    local result={}
    for _,item in ipairs(source) do
        local text=(item.name..' '..(item.message or item.reason or '')):lower()
        if query=='' or text:find(query,1,true) then result[#result+1]=item end
    end
    return result
end
local function UpdateDetails()
    local name=nameBox:GetText();local key=S.Key(name);local contact=key and Contact(name)
    local allowed=key and ns.DB.shield.allowed[key]
    local valid=key~=nil and key~=S.Key(S.UnitName('player'))
    remove:SetEnabled(contact~=nil);allow:SetEnabled(valid)
    allow:SetText(allowed and 'Stop allowing' or 'Allow player')
    add:SetEnabled(valid and not allowed)
    heading:SetText(name~='' and Plain(name) or 'Player details')
    local text
    if name=='' then
        text='Pick an alert or player on the left, or enter a name below.\n\nShield gives you a break from repeated unwanted contact. You can add a shield yourself, end one early, or allow someone you know.'
    elseif not valid then text='Enter a player name below. Add -Realm if they play on another realm.'
    else
        text=contact and ('Shielded\n'..Duration(contact)..'\n\n'..(contact.reason or 'You added this shield.'))
            or allowed and 'Allowed\n\nShield will leave this player alone. Your normal word filters still apply.'
            or 'No active shield\n\nYou can shield this player below, or allow them so Shield leaves them alone.'
        if selected and S.Key(selected.name)==key and selected.message then
            text=text..'\n\nLatest selected alert\n'..selected.message..(selected.count>1 and ' ('..selected.count..' times)' or '')
        end
        if not S.Active() then text=text..'\n\nShield is currently paused. Your saved players are still here.' end
    end
    text=Plain(text)
    if details:GetText()~=text then details:SetText(text) end
end
local function Select(item)
    selected=item;nameBox:SetText(item and item.name or '');nameBox:ClearFocus()
    scroll:SetVerticalScroll(0);footer:SetText('Shields and allowed players are saved. Alerts last until you log out or reload.')
    ns.RefreshShield()
end
function ns.RefreshShield()
    if ns.RefreshShieldOptions then ns.RefreshShieldOptions() end
    if not panel or not ns.DB or not ns.DB.shield then return end
    local db=ns.DB.shield
    status:SetText((S.Active() and 'Shield on' or 'Shield paused')..'  |  '..S.Profiles[db.profile].title..'  |  '..#S.List()..' shielded')
    local items=Items();local pages=math.max(1,math.ceil(#items/PAGE_SIZE));page=math.min(page,pages)
    listTitle:SetText((view=='alerts' and 'Recent alerts' or 'Shielded & allowed')..'  |  '..#items..' shown')
    pager:SetText('Page '..page..' / '..pages);previous:SetEnabled(page>1);nextPage:SetEnabled(page<pages)
    empty:SetShown(#items==0)
    empty:SetText(query~='' and 'No matches.\n\nTry another name or clear the search.'
        or view=='alerts' and 'No alerts yet.\n\nWhen Shield steps in, you can see what happened here.'
        or 'No players saved yet.\n\nEnter a name on the right to add a shield or allow someone.')
    for i,row in ipairs(rows) do
        local item=items[(page-1)*PAGE_SIZE+i];row.item=item;row:SetShown(item~=nil)
        if item then
            row.label:SetText(Plain(item.name))
            row.preview:SetText(Plain(view=='alerts' and item.message or item.allowed and 'Allowed player' or Duration(item)))
            T.RowState(row,S.Key(nameBox:GetText())==S.Key(item.name),item.allowed and 'Unchanged' or 'Hidden')
        end
    end
    UpdateDetails()
end
local function Act(kind)
    local name=nameBox:GetText();local ok,err
    if kind=='add' then ok,err=S.Add(name,durationValue)
    elseif kind=='remove' then S.Remove(name);ok=true
    elseif ns.DB.shield.allowed[S.Key(name)] then S.Unallow(name);ok=true
    else ok,err=S.Allow(name) end
    ns.RefreshShield()
    footer:SetText(err or (ok and (kind=='add' and 'Shield added. You can end it early with Remove shield.'
        or kind=='remove' and 'Shield removed. This player can contact you again.'
        or 'Player updated. Your normal word filters still apply.') or 'Enter a player name first.'))
end
function ns.BuildShieldReview(parent)
    if panel then return panel end
    panel=CreateFrame('Frame',nil,parent);panel:SetAllPoints(parent);ns.ShieldWindow=panel
    local toolbar=T.Panel(panel,14,-70,912,44)
    Text(toolbar,10,-15,50,'Show')
    local source=T.Dropdown(toolbar,57,-9,157,{{'alerts','Recent alerts'},{'contacts','Players'}},
        function() return view end,function(v) view=v;page=1;Select(nil) end)
    T.Tooltip(source,'What to show','Recent alerts shows when Shield stepped in. Players shows your saved shields and allowed players.')
    local search=CreateFrame('EditBox',nil,toolbar,'SearchBoxTemplate')
    search:SetSize(225,24);search:SetPoint('TOPLEFT',230,-10);search:SetAutoFocus(false);search:SetMaxLetters(128);T.TextField(search)
    search:SetScript('OnTextChanged',function(self)
        if SearchBoxTemplate_OnTextChanged then SearchBoxTemplate_OnTextChanged(self) end
        query=(self:GetText() or ''):lower();page=1;ns.RefreshShield()
    end)
    search:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
    T.Tooltip(search,'Find a player','Search this list by player name or the reason shown in an alert.')
    status=T.Muted(Text(toolbar,472,-15,276))
    Button(toolbar,'Export shields',146,752,-10,function() ns.OpenShieldExport() end,'Preview your current shielded players, choose entries and privacy options, then copy for your own review or a moderator.')
    local list=T.Panel(panel,14,-122,350,444)
    listTitle=Text(list,12,-12,326);empty=T.Muted(Text(list,18,-68,314));rows={}
    for i=1,PAGE_SIZE do
        local row=CreateFrame('Button',nil,list);rows[i]=row
        row:SetSize(332,42);row:SetPoint('TOPLEFT',9,-34-(i-1)*44)
        row.background=row:CreateTexture(nil,'BACKGROUND');row.background:SetAllPoints()
        row.label=Text(row,12,-6,309);row.label:SetWordWrap(false)
        row.preview=T.Muted(Text(row,12,-23,309));row.preview:SetWordWrap(false);T.SkinRow(row)
        row:SetScript('OnClick',function(self) Select(self.item) end)
        T.Tooltip(row,'Player details','Click to see what happened and manage this player on the right.')
    end
    previous=Button(panel,'Previous',94,14,-577,function() page=math.max(1,page-1);ns.RefreshShield() end)
    nextPage=Button(panel,'Next',94,270,-577,function() page=page+1;ns.RefreshShield() end)
    pager=Text(panel,121,-583,145)
    local header=T.Panel(panel,376,-122,550,34);heading=T.Gold(Text(header,12,-10,526,'Player details','GameFontNormal'));heading:SetWordWrap(false)
    local paper=T.Panel(panel,376,-159,550,407,true)
    scroll=CreateFrame('ScrollFrame',nil,paper,'UIPanelScrollFrameTemplate')
    scroll:SetPoint('TOPLEFT',16,-16);scroll:SetSize(502,186)
    details=CreateFrame('EditBox',nil,scroll);details:SetMultiLine(true);details:SetAutoFocus(false);T.Body(details);T.Ink(details)
    details:SetSize(498,186);scroll:SetScrollChild(details)
    local writing=false
    details:SetScript('OnTextChanged',function(self,user)
        if user and not writing then writing=true;UpdateDetails();writing=false end
    end)
    details:SetScript('OnEscapePressed',function(self) self:ClearFocus() end);T.TextField(details,scroll)
    Text(paper,18,-225,510,'Player name','GameFontNormal',true)
    nameBox=CreateFrame('EditBox',nil,paper,'InputBoxTemplate');nameBox:SetSize(500,26);nameBox:SetPoint('TOPLEFT',24,-249)
    nameBox:SetAutoFocus(false);nameBox:SetMaxLetters(128);T.TextField(nameBox)
    nameBox:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
    nameBox:SetScript('OnTextChanged',function() if add then UpdateDetails() end end)
    T.Tooltip(nameBox,'Player name','Enter Name-Realm for someone on another realm. For your own realm, just their name is enough.')
    Text(paper,18,-281,510,'Use Name-Realm, or just a name for your own realm.',nil,true)
    Text(paper,18,-315,220,'How long?','GameFontNormal',true)
    local duration=T.Dropdown(paper,18,-339,220,{{900,'15 minutes'},{'session','Until logout / reload'},{0,'Until I remove it'}},
        function() return durationValue end,function(v) durationValue=v end)
    T.Tooltip(duration,'Shield duration','15 minutes expires on its own. Until logout / reload lasts this session. Until I remove it stays saved until you end it.')
    add=Button(paper,'Add shield',258,274,-339,function() Act('add') end,'Give this player a timeout across the Shield features you have turned on.')
    remove=Button(panel,'Remove shield',145,376,-577,function() Act('remove') end,'End this shield now. Old messages stay in Messages; future contact is allowed.')
    allow=Button(panel,'Allow player',185,531,-577,function() Act('allow') end,'Allow removes the shield and keeps Shield from blocking this player again. Stop allowing puts them back under normal Shield protection. Word filters still apply.')
    Button(panel,'Help',86,726,-577,function() ns.OpenTutorial('shield') end,'A quick guide to profiles, shields and allowed players.')
    Button(panel,'Settings',100,826,-577,ns.OpenShieldOptions,'Change your Shield profile and choose which kinds of contact to block.')
    footer=T.Muted(Text(panel,18,-615,898,'Shields and allowed players are saved. Alerts last until you log out or reload.'))
    ns.ShieldNameBox,ns.ShieldDetails,ns.ShieldSource,ns.ShieldSearch=nameBox,details,source,search
    ns.ShieldAddButton,ns.ShieldRemoveButton,ns.ShieldAllowButton=add,remove,allow
    panel:SetScript('OnShow',ns.RefreshShield);panel:Hide();return panel
end
function ns.OpenShield() ns.OpenReview('shield') end
function ns.OpenShieldPlayer(name)
    ns.OpenShield();view='contacts';query='';page=1
    if ns.ShieldSearch then ns.ShieldSearch:SetText('') end
    ns.ShieldSource:Refresh();Select(nil);nameBox:SetText(name);nameBox:ClearFocus();ns.RefreshShield()
end
