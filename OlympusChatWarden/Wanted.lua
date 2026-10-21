-- Personal alerts from Olympus's consented list. The board remains owned by Olympus.
local _,ns=...
local function OwnedFrame(...) return ns.Modules and ns.Modules.Frame('alerts',...) or CreateFrame(...) end
local C,A=ns.OlympusConnection,ns.Activity
local W={MAX_TARGETS=200,MAX_MARKERS=500,byGUID={},aliases={},last={},sequence=0,state='waiting'};ns.Wanted=W
local defaults={enabled=true,encounters=true,chatIndicators=true,badges=true,sound=false,toast=false,cooldown=300}
local nextRead,reading,lastSound=0,false,-math.huge
local markerPrefix='addon:OlympusChatWardenWanted:'..tostring(math.random(10000,99999))..':'..tostring(math.floor(ns.SessionTime()*1000))..':'
local markers,markerKeys,markerOrder,markerID,markerCursor={},{},{},0,1
local hoverFrames=setmetatable({},{__mode='k'})
local function ClearMarkers()
    markers={};markerKeys={};markerOrder={};markerCursor=1
    if W.hoverLink and GameTooltip then GameTooltip:Hide() end;W.hoverLink=nil
end
local function Number(value,minimum)
    return ns.SafeNumber(value) and value>=minimum and value<=1000000000 and value%1==0 and value or nil
end
local function GUID(value)
    return ns.CanRead(value) and #value<=64 and value:match('^Player%-%w[%w%-]*$') and value or nil
end
local function Name(value)
    return ns.CanRead(value) and #value<=144 and not value:find('[|%c]') and C.Plain(value,144) or nil
end
function W.ValidRecord(t)
    return type(t)=='table' and (t.kind=='encounter' or t.kind=='mention') and GUID(t.guid) and Name(t.name)
        and Number(t.bounty,0) and Number(t.kills,0) and Number(t.cycle,1)
        and (t.zone==nil or Name(t.zone)) and (t.speaker==nil or Name(t.speaker))
        and (t.via=='target' or t.via=='mouseover' or t.via=='chat')
        and (t.kind=='mention')==(t.via=='chat')
end
local function Base()
    return W.db and W.db.enabled and ns.DB and (not ns.Modules or ns.Modules.Enabled('alerts')) and ns.DB.alertsEnabled~=false and ns.Membership.Allowed()
        and C.modern and C.state=='connected' and C.permission=='granted' and C.Profile()~=nil
end
function W.Active() return Base() and W.state=='ready' end
local function Clear(state)
    W.byGUID={};W.aliases={};W.count=0;W.state=state or 'waiting'
    ClearMarkers()
    if ns.HideWantedToast then ns.HideWantedToast() end
end
function W.Initialize()
    local db=type(ns.DB.wanted)=='table' and ns.DB.wanted or {};ns.DB.wanted=db;W.db=db
    if type(db.chatIndicators)~='boolean' and type(db.mentions)=='boolean' then db.chatIndicators=db.mentions end
    db.mentions=nil -- preview-only chat notification preference
    for key,value in pairs(defaults) do if type(db[key])~=type(value) then db[key]=value end end
    db.cooldown=math.max(30,math.min(1800,ns.SafeNumber(db.cooldown) or 300))
    W.last={};W.sequence=0;nextRead=0;lastSound=-math.huge;Clear()
end
local function Alias(index,text,target)
    local key=ns.Engine.Lower(text)
    if index[key] and index[key]~=target then index[key]=false
    elseif index[key]==nil then index[key]=target end
end
function W.Receive(rows)
    if not Base() then Clear('inactive');return false end
    if not ns.Readable(rows) or type(rows)~='table' or #rows>W.MAX_TARGETS then Clear('unavailable');return false end
    local byGUID,aliases={},{};local count=0
    for _,row in ipairs(rows) do
        if not ns.Readable(row) or type(row)~='table' then Clear('unavailable');return false end
        local guid,name=GUID(row.guid),Name(row.name)
        local bounty,kills,cycle=Number(row.bounty,0),Number(row.kills,0),Number(row.cycle,1)
        if not guid or not name or not bounty or not kills or not cycle or byGUID[guid] then Clear('unavailable');return false end
        local key=ns.Shield.Key(name)
        if not key then Clear('unavailable');return false end
        local target={guid=guid,name=name,bounty=bounty,kills=kills,cycle=cycle}
        byGUID[guid]=target;count=count+1
        local base,realm=key:match('^([^%-]+)%-(.+)$')
        Alias(aliases,ns.Shield.NormalName(name),target)
        local own=ns.Shield.Key(ns.Shield.UnitName('player') or '')
        local ownRealm=own and own:match('%-(.+)$')
        if realm==ownRealm then Alias(aliases,base,target) end
    end
    W.byGUID,W.aliases,W.count,W.state=byGUID,aliases,count,'ready';nextRead=ns.SessionTime()+60
    if W.hoverLink then
        local id=tonumber(W.hoverLink:match('^'..markerPrefix..'(%d+)$'));local cell=id and markers[id]
        if not cell or not byGUID[cell.guid] then if GameTooltip then GameTooltip:Hide() end;W.hoverLink=nil end
    end
    for key in pairs(W.last) do if not byGUID[key:match('^(.-):')] then W.last[key]=nil end end
    W.ObserveUnit('target');W.ObserveUnit('mouseover')
    if ns.Workspace then ns.Workspace.Queue() end
    return true
end
function W.Refresh(force)
    if not W.db then return end
    if not Base() then Clear(W.db.enabled and 'waiting' or 'off');return end
    if not C.Has('wanted') then Clear('unsupported');return end
    local now=ns.SessionTime();if reading or not force and now<nextRead then return end
    reading=true;nextRead=now+5
    local ok,rows=C.Call('GetWanted');reading=false
    if not ok or rows==nil or not W.Receive(rows) then Clear('unavailable') end
end
function W.Status()
    if not W.db or not W.db.enabled then return 'Wanted alerts are off.' end
    if ns.Modules and not ns.Modules.Enabled('alerts') then return 'SignalWarden alerts are disabled. Enable them in CommandWarden > Modules.' end
    if ns.DB and ns.DB.alertsEnabled==false then return 'Alerts are paused. Enable Alerts to resume Wanted notifications.' end
    if not C.modern then return 'Wanted alerts require Olympus 1.2.4 or later.' end
    if not Base() then return 'Wanted alerts are paused. '..C.Reason() end
    if W.state=='ready' then return 'Connected to Olympus. '..tostring(W.count or 0)..' listed players.' end
    return 'Olympus Wanted data is unavailable. Alerts will retry shortly.'
end
function W.Set(key,value)
    if not ns.Membership.Allowed() or not W.db then return false end
    if key=='cooldown' then
        if not ns.SafeNumber(value) or value<30 or value>1800 then return false end
    elseif type(defaults[key])~='boolean' or type(value)~='boolean' then return false end
    W.db[key]=value
    if key=='chatIndicators' and not value then ClearMarkers() end
    if key=='enabled' then nextRead=0;W.Refresh() end
    if key=='encounters' and value then W.ObserveUnit('target');W.ObserveUnit('mouseover') end
    for _,item in ipairs(A.entries) do if item.categories.wanted then item.quiet.wanted=not W.db.badges end end
    A.Changed();return true
end
local function Emit(target,via)
    if not W.Active() then return end
    local now=ns.SessionTime();local key=target.guid..':encounter'
    if W.last[key] and now-W.last[key]<W.db.cooldown then return end
    W.last[key]=now;W.sequence=W.sequence+1
    local record={kind='encounter',guid=target.guid,name=target.name,bounty=target.bounty,kills=target.kills,cycle=target.cycle,
        via=via,zone=C.Plain(ns.SafeCall(GetRealZoneText),128)}
    local preview='Encountered through '..via..'.'
    local item=A.Add('wanted:'..tostring(ns.DB.historySequence or 0)..':'..W.sequence,'wanted',{
        sender=target.name,event='WANTED_ENCOUNTER',channel='Encounter',wanted=record,
        preview=preview..' Olympus-listed bounty: '..target.bounty..' points.',
        timestamp=ns.SafeCall(time) or ns.SafeCall(GetServerTime)},not W.db.badges)
    if item then
        if W.db.sound and now-lastSound>=5 and type(PlaySound)=='function' then
            lastSound=now;pcall(PlaySound,SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959,'Master')
        end
        if W.db.toast and ns.ShowWantedToast then ns.ShowWantedToast(item) end
    end
    return item
end
function W.ObserveUnit(unit)
    if not W.Active() or not W.db.encounters or (unit~='target' and unit~='mouseover') then return end
    if not ns.Checked(ns.SafeCall(UnitIsPlayer,unit)) or not ns.Checked(ns.SafeCall(UnitCanAttack,'player',unit)) then return end
    local target=W.byGUID[GUID(ns.SafeCall(UnitGUID,unit)) or ''];if not target then return end
    return Emit(target,unit)
end
local function Letter(byte)
    return byte and (byte>=128 or byte>=48 and byte<=57 or byte>=65 and byte<=90 or byte>=97 and byte<=122 or byte==95 or byte==45)
end
local function Visible(text)
    local parts,ends={},{};local size=0
    local function Add(value,at,constant)
        local offset=0
        for char in value:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
            offset=offset+#char;local lower=ns.Engine.Lower(char);parts[#parts+1]=lower
            for i=1,#lower do size=size+1;ends[size]=constant and at or at+offset-1 end
        end
    end
    local at=1
    while at<=#text do
        local code=text:sub(at,at+1)
        if code=='|H' then
            local first,last,payload,label=text:find('|H([^|]+)|h(.-)|h',at)
            if first~=at then Add('\1',at,true);at=at+2
            else
                -- Append outside a player link; never nest our hyperlink in its label.
                label=label:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')
                if payload:match('^player:') and not label:find('|',1,true) then Add(label,last,true)
                else Add('\1',last,true) end
                at=last+1
            end
        elseif code=='|T' or code=='|A' then
            local close=code=='|T' and '|t' or '|a';local last=text:find(close,at+2,true)
            Add('\1',at,true);at=last and last+2 or #text+1
        elseif code=='|c' and text:sub(at+2,at+9):match('^%x%x%x%x%x%x%x%x$') then at=at+10
        elseif code=='|r' then at=at+2
        elseif code:sub(1,1)=='|' then Add('\1',at,true);at=at+2
        else
            local last=text:find('|',at,true);last=last and last-1 or #text
            Add(text:sub(at,last),at,false);at=last+1
        end
    end
    return table.concat(parts),ends
end
local function Matches(text)
    if not W.Active() or not ns.CanRead(text) or #text>8192 then return {} end
    local visible,ends=Visible(text);local candidates={}
    for alias,target in pairs(W.aliases) do if target then
        local at=1
        while at<=#visible do
            local first,last=visible:find(alias,at,true);if not first then break end
            if not Letter(visible:byte(first-1)) and not Letter(visible:byte(last+1)) then
                candidates[#candidates+1]={target=target,first=first,last=last,after=ends[last]};break
            end
            at=last+1
        end
    end end
    table.sort(candidates,function(a,b) return a.first<b.first or a.first==b.first and (a.last>b.last or a.last==b.last and a.target.guid<b.target.guid) end)
    local found,seen,last={}, {},0
    for _,hit in ipairs(candidates) do if hit.first>last and not seen[hit.target.guid] then
        found[#found+1]=hit;seen[hit.target.guid]=true;last=hit.last;if #found>=5 then break end
    end end
    return found
end
function W.Find(text)
    local found={};for _,hit in ipairs(Matches(text)) do found[#found+1]=hit.target end
    table.sort(found,function(a,b) return a.guid<b.guid end);return found
end
local function Cell(link)
    if not W.Active() or not W.db.chatIndicators or not ns.CanRead(link) then return end
    local id=tonumber(link:match('^'..markerPrefix..'(%d+)$'));local cell=id and markers[id]
    if cell and W.byGUID[cell.guid] then return cell end
end
function W.Hover(frame,link)
    local cell=Cell(link);if not cell or not GameTooltip then return end
    local target=W.byGUID[cell.guid]
    GameTooltip:SetOwner(frame,'ANCHOR_CURSOR');GameTooltip:SetText('Olympus Wanted')
    GameTooltip:AddLine(target.name,.91,.77,.58,true)
    GameTooltip:AddLine('Listed bounty: '..target.bounty..' points',.9,.9,.85,true)
    GameTooltip:AddLine('Listed kills: '..target.kills..'  |  Cycle: '..target.cycle,.7,.73,.76,true)
    GameTooltip:AddLine('Listed by Olympus. A chat mention does not establish location.',.7,.73,.76,true)
    GameTooltip:Show();W.hoverLink=link
end
local function HookHover(frame)
    if not ns.Readable(frame) or not frame or not frame.HookScript
        or frame.IsForbidden and frame:IsForbidden() or frame.IsProtected and frame:IsProtected() then return false end
    if hoverFrames[frame] then return true end
    hoverFrames[frame]=true
    frame:HookScript('OnHyperlinkEnter',function(self,link) W.Hover(self,link) end)
    frame:HookScript('OnHyperlinkLeave',function(_,link)
        if W.hoverLink==link then if GameTooltip then GameTooltip:Hide() end;W.hoverLink=nil end
    end)
    return true
end
local function Marker(target,entry)
    local delivery=entry.deliveryKey or entry.captureID
    if not ns.CanRead(delivery) then return '' end
    local key=delivery..':'..target.guid
    local id=markerKeys[key]
    if not id or not markers[id] then
        local old=markerOrder[markerCursor]
        if old and markers[old] then markerKeys[markers[old].key]=nil;markers[old]=nil end
        markerID=markerID+1;id=markerID;markers[id]={key=key,guid=target.guid}
        markerKeys[key]=id;markerOrder[markerCursor]=id;markerCursor=markerCursor%W.MAX_MARKERS+1
    end
    return ' |H'..markerPrefix..id..'|h|TInterface\\AddOns\\OlympusChatWarden\\Media\\V5\\Status.tga:16:16:0:0:1254:1254:25:296:799:1081|t|h'
end
function W.Decorate(frame,text,entry,source)
    if not W.Active() or not W.db.chatIndicators or not entry or not source or source.kind~='player' or source.shield or source.spam
        or not entry.captureSnapshot.actionRecorded or entry.captureSnapshot.actualAction=='Hidden'
        or not ns.CanRead(text) or #text>8192 or text:find('|H'..markerPrefix,1,true) then return text end
    local hits=Matches(text);if #hits==0 then return text end
    if not HookHover(frame) then return text end
    -- Insert from the right, retaining all native text and link payloads verbatim.
    table.sort(hits,function(a,b) return a.after>b.after end)
    for _,hit in ipairs(hits) do
        local mark=Marker(hit.target,entry)
        text=text:sub(1,hit.after)..mark..text:sub(hit.after+1)
    end
    return text
end
function W.OnLink(link)
    -- Informational marker only: clicking it never creates an alert or opens a UI.
    return ns.CanRead(link) and link:find(markerPrefix,1,true)==1 or false
end
C.Subscribe(function() W.Refresh() end)
function W.Stop() Clear('disabled');W.last={} end
local events=OwnedFrame('Frame');events:RegisterEvent('PLAYER_TARGET_CHANGED');events:RegisterEvent('UPDATE_MOUSEOVER_UNIT')
events:SetScript('OnEvent',function(_,event) W.ObserveUnit(event=='PLAYER_TARGET_CHANGED' and 'target' or 'mouseover') end)
local elapsed=0
events:SetScript('OnUpdate',function(_,delta)
    elapsed=elapsed+delta;if elapsed<1 then return end;elapsed=0;W.Refresh()
end)
