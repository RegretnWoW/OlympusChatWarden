-- Local suite search. Bounded work per frame; original evidence stays in its store.
local _,ns=...
local Q={BUDGET=128,LIMIT=30};ns.WardenSearch=Q
local function Text(v) return type(v)=='string' and v or type(v)=='number' and tostring(v) or '' end
local function Match(q,...)
    for n=1,select('#',...) do if Text(select(n,...)):lower():find(q,1,true) then return true end end
    return false
end
local routes={
 {'overview','Warden','Overview home search dashboard'}, {'messages','ChatWarden','Messages filtering chat'},
 {'capture','Capture','Saved chat bookmarks whispers conversations'}, {'rules','Rules','Custom phrases replacements exceptions'},
 {'packs','Packs','Optional signed categories'}, {'reports','Reports','Saved filtering feedback'},
 {'mentions','SignalWarden','Alerts mentions wanted OlympusMute'}, {'shield','ShieldWarden','Contact protection allowed players spam'},
 {'intel','IntelWarden','Players profiles recently met watchlist'}, {'chronicle','ChronicleWarden','Personal milestones adventures stats time'},
 {'recording','Data & Backups','Recorded events collection backup restore export'}, {'updates','Updates & Help','Patch notes history user guide tour'},
 {'settings','Settings','Languages spelling sensitivity notifications window size'},
}
local function Add(job,group,id,title,sub,data)
    job.matches[group]=(job.matches[group] or 0)+1
    if job.matches[group]>Q.LIMIT then return end
    job.results[#job.results+1]={id=group..':'..id,group=group,title=title,sub=sub,data=data}
end
local function Name(c,guid)
    local p=c and c.profiles and c.profiles[guid];local f=p and p.facts
    return f and f.name and f.name.value,f and f.guild and f.guild.value
end
local function When(at) return at and ns.WardenUI.Stamp(at) or '' end
function Q.Begin(text)
    if Q.CancelOpen then Q.CancelOpen() end
    local q=Text(text):lower():match('^%s*(.-)%s*$')
    local j={query=q,results={},matches={},sources={},source=1,processed=0,done=q==''}
    if j.done then return j end
    for _,r in ipairs(routes) do if Match(q,r[2],r[3]) then Add(j,ns.WardenBrand.sections[ns.WardenBrand.Parent(r[1])] and ns.WardenBrand.sections[ns.WardenBrand.Parent(r[1])].name or 'Warden',r[1],r[2],'Open section • '..r[3],{page=r[1]}) end end
    local function Array(kind,array,owner) j.sources[#j.sources+1]={kind=kind,array=array or {},index=#(array or {}),owner=owner} end
    Array('activity',ns.Activity.List());Array('capture',ns.ChatCapture.db.entries)
    Array('bookmarks',ns.ChatCapture.db.bookmarks);Array('rules',ns.Personal.rules);Array('reports',ns.Personal.reports);Array('packs',ns.RulePacks.List())
    for owner,c in pairs(ns.ChronicleStore.db.characters or {}) do
        j.sources[#j.sources+1]={kind='profiles',map=c.profiles,owner=owner,character=c,revision=c.revision}
        Array('events',c.events,owner);local s=j.sources[#j.sources];s.character=c;s.revision=c.revision;s.snapshotLength=#c.events;s.lastID=c.events[#c.events] and c.events[#c.events].id
    end
    return j
end
local function Visit(j,s,e,key)
    local q=j.query;local group,title,sub,data
    if s.kind=='activity' then
        if not Match(q,e.sender,e.preview,ns.Activity.EventLabel(e),e.channel,When(e.timestamp)) then return end
        group=e.categories.shield and 'ShieldWarden' or (e.categories.mentions or e.categories.wanted or e.categories.olympusmute) and 'SignalWarden' or 'ChatWarden'
        title=ns.Activity.DisplayName(e.sender);sub=(ns.Activity.EventLabel(e) or 'Activity')..' • '..When(e.timestamp);data={activity=e,page=group=='ShieldWarden' and 'shield' or group=='SignalWarden' and 'mentions' or 'messages'}
    elseif s.kind=='capture' then
        if not Match(q,e.original,e.sender,e.channel,e.recipient,When(e.timestamp)) then return end
        group='ChatWarden';title=ns.Activity.DisplayName(e.sender);sub='Chat Capture • '..When(e.timestamp)..' • open to read';data={page='capture',capture=e}
    elseif s.kind=='bookmarks' then
        local found=Match(q,e.title,e.note)
        if not found then for _,r in ipairs(e.records or {}) do if Match(q,r.original,r.sender) then found=true;break end end end
        if not found then return end
        group='ChatWarden';title=e.title or 'Bookmark';sub='Saved chat bookmark • '..When(e.timestamp);data={page='capture',bookmark=e}
    elseif s.kind=='rules' or s.kind=='reports' or s.kind=='packs' then
        if not Match(q,e.phrase,e.title,e.description,e.note,e.original,e.expected,e.action) then return end
        group='ChatWarden';title=e.title or e.phrase or 'Saved report';sub=({rules='Personal phrase rule',reports='Saved filtering report',packs='Signed rule pack'})[s.kind];data={page=s.kind,entry=e}
    elseif s.kind=='profiles' then
        local f=e.facts or {};local name=f.name and f.name.value;local guild=f.guild and f.guild.value;local class=f.class and f.class.value
        if not Match(q,key,name,guild,class,e.personal and e.personal.note,When(e.firstObserved),When(e.lastObserved)) then return end
        group='IntelWarden';title=name or 'Name not recorded';sub=(guild or 'Guild not recorded')..' • Saved by '..ns.WardenUI.OwnerName(s.owner);data={page='intel',guid=key,owner=s.owner}
    elseif s.kind=='events' then
        local d=e.details or {};local loc=e.location or {}
        local name,guild=Name(s.character,e.subject or d.guid);local ownerName=ns.WardenUI.OwnerName(s.owner)
        if not Match(q,ns.RecordingUI.Title(e),e.id,e.kind,e.source,e.subject,e.character,ownerName,name,guild,d.name,d.class,d.guild,d.skill,d.questID,d.recordType,d.relationship,loc.zone,loc.subzone,loc.instanceName,When(e.at)) then return end
        group=(e.kind=='player_observed' or e.kind=='important_player' or e.kind=='olympus_snapshot') and 'IntelWarden' or 'ChronicleWarden'
        local description=(e.kind=='player_observed' or e.kind=='important_player') and ns.RecordingUI.Title(e) or d.name or ns.RecordingUI.Title(e)
        title=(name and name..' • ' or '')..description;sub=When(e.at)..' • '..(loc.zone or loc.instanceName or 'Location not recorded')..' • '..ownerName
        -- Retain a position only for the bounded result set, not a second history index.
        data={event=e,owner=s.owner,eventArray=s.array,eventIndex=key}
    end
    if group then data.character=s.character;Add(j,group,tostring(e.id or key or s.index),title,sub,data) end
end
function Q.Pump(j,budget)
    if not j or j.done then return true end
    if InCombatLockdown and InCombatLockdown() then return false end
    local P=ns.WardenPerformance;local deadline,start=P.Begin();local first=j.processed
    for _=1,math.min(budget or Q.BUDGET,Q.BUDGET) do
        if P.Expired(deadline) then break end
        local s=j.sources[j.source]
        if not s then
            j.done=true
            table.sort(j.results,function(a,b) return a.group<b.group or a.group==b.group and a.id<b.id end)
            break
        end
        if s.character and (ns.ChronicleStore.Character(s.owner,false)~=s.character or s.kind=='events' and s.character.events~=s.array or s.kind=='profiles' and s.character.profiles~=s.map) then
            j.stale=true;j.done=true;break -- Retry explicitly against a stable snapshot.
        end
        if s.kind=='events' and (s.array[s.snapshotLength] and s.array[s.snapshotLength].id or nil)~=s.lastID then
            j.stale=true;j.done=true;break -- A late insertion shifted the snapshot boundary.
        end
        local value,key
        if s.map then key,value=next(s.map,s.key);s.key=key else value=s.array[s.index];key=s.index;s.index=s.index-1 end
        if value then Visit(j,s,value,key);j.processed=j.processed+1 else j.source=j.source+1 end
    end
    P.End('suite search',start,j.processed-first);return j.done
end
local sourceWorker=CreateFrame('Frame')
local function SourceStatus(message)
    local W=ns.Workspace;if W and W.status then W.status:SetText(message) end
end
function Q.CancelOpen()
    Q.pendingOpen=nil;sourceWorker:SetScript('OnUpdate',nil)
end
function Q.PumpOpen(budget)
    local j=Q.pendingOpen;if not j then return true end
    local W=ns.Workspace
    if not ns.Membership.Allowed() or W.current~=j.page or j.wasShown and not W.window:IsShown() then Q.CancelOpen();return true end
    local c=ns.ChronicleStore.Character(j.owner,false)
    if ns.ChronicleStore.blocked or c~=j.character or c.events~=j.events or j.events[j.length]~=j.tail then
        Q.CancelOpen();ns.Print('That history changed. Search again to refresh the result.');return true
    end
    if InCombatLockdown and InCombatLockdown() then SourceStatus('Original record lookup paused during combat.');return false end
    if j.position and j.events[j.position]==j.event then Q.CancelOpen();ns.RecordingUI.OpenSource(nil,j.event);return true end
    local P=ns.WardenPerformance;local deadline,start=P.Begin();local first=j.processed
    for _=1,math.min(Q.BUDGET,budget or Q.BUDGET) do
        if P.Expired(deadline) then break end
        local e=j.events[j.cursor];j.processed=j.processed+1
        if not e or j.cursor<1 then
            P.End('source lookup',start,j.processed-first);Q.CancelOpen();ns.Print('This saved record is no longer available. Search again to refresh the results.');return true
        end
        if e==j.event then
            P.End('source lookup',start,j.processed-first);Q.CancelOpen();ns.RecordingUI.OpenSource(nil,e);return true
        end
        j.cursor=j.cursor-1
    end
    P.End('source lookup',start,j.processed-first);SourceStatus('Finding the original record... '..j.processed..' saved entries checked.');return false
end
function Q.Open(row)
    Q.CancelOpen()
    local d=row and row.data;if not d then return end
    if d.character and ns.ChronicleStore.Character(d.owner,false)~=d.character then ns.Print('That history changed. Search again to refresh the result.');return end
    local W=ns.Workspace
    if d.event then
        if not ns.Membership.Allowed() then ns.Print(ns.Membership.Status());return end
        local owner=d.owner or d.event.character;local c=ns.ChronicleStore.Character(owner,false)
        if ns.ChronicleStore.blocked or not c or not c.events then ns.Print('This saved history is no longer available. Search again.');return end
        if d.eventArray and d.eventArray~=c.events then ns.Print('That history changed. Search again to refresh the result.');return end
        if d.eventArray==c.events and d.eventIndex and c.events[d.eventIndex]==d.event
            and not (InCombatLockdown and InCombatLockdown()) then
            ns.RecordingUI.OpenSource(nil,d.event);return
        end
        -- Older results and Home highlights may lack a retained position. Resolve
        -- them cooperatively, with identity/table/tail checks on every update.
        Q.pendingOpen={owner=owner,character=c,events=c.events,length=#c.events,tail=c.events[#c.events],
            event=d.event,position=d.eventArray==c.events and d.eventIndex,cursor=#c.events,processed=0,page=W.current,wasShown=W.window and W.window:IsShown()}
        sourceWorker:SetScript('OnUpdate',function() Q.PumpOpen() end)
        Q.PumpOpen();return
    end
    W.Open(d.page)
    local p=W.pages[W.current];if not p then return end
    if d.guid then p.owner=d.owner;p.mode='all';p.detail='profile';p.query='';p.search:SetText('');p.selected=d.guid;p.state=nil;p:Activate();p:Refresh(true)
    elseif d.highlight then p.owner=d.owner;p.mode='journal';p.selected=d.highlight;p:Activate();p:Refresh(true)
    elseif d.activity then p.selected=d.activity;if d.page=='mentions' then p.mode='all';p:Activate() end;ns.Activity.Mark(d.activity.id);p:Refresh()
    elseif d.capture then p.mode='recent';p.search:SetText(d.capture.sender or '');p.selected={id=d.capture.id,captured=d.capture,sender=d.capture.sender,event=d.capture.event,preview=d.capture.original,timestamp=d.capture.timestamp};p:Activate();p:Refresh()
    elseif d.bookmark then p.mode='bookmarks';p.selected={id=d.bookmark.id,bookmark=d.bookmark,title=d.bookmark.title};p:Activate();p:Refresh()
    elseif d.entry and p.search then p.search:SetText(d.entry.phrase or d.entry.title or '');p:Refresh() end
end
