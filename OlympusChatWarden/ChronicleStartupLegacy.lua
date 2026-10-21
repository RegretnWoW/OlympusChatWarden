-- Local recovery for already-consented startup observations. This separate
-- SavedVariable never modifies an unvalidated Chronicle archive or transmits data.
local _,ns=...
local J={VERSION=1,LIMIT=1024,BYTES=524288};ns.ChronicleStartupLegacy=J
local S,C=ns.ChronicleStore,ns.Chronicle
local frame=CreateFrame('Frame');local job
local function Saved() return type(OlympusWardenStartupDB)=='table' and OlympusWardenStartupDB.legacy end
local entryKeys={rows=true,run=true,bytes=true,overflow=true,firstAt=true,sessions=true,started=true,gap=true}
local function Root()
    local db=Saved()
    if db==nil then return end
    if type(db)~='table' or getmetatable(db) or db.version~=1 or type(db.characters)~='table' or getmetatable(db.characters) then return nil end
    for k in pairs(db) do if k~='version' and k~='characters' then return nil end end
    return db
end
local function Fail(reason)
    if J.error~=reason then ns.Print(reason) end
    J.error=reason;job=nil;frame:SetScript('OnUpdate',nil)
end
function J.Cancel() job=nil;frame:SetScript('OnUpdate',nil) end
function J.Clear() J.Cancel();OlympusWardenStartupDB.legacy=nil;J.error=nil end
local function ValidEntry(owner,e)
    if type(e)~='table' or getmetatable(e) or not S.Array(e.rows,J.LIMIT) or not S.Integer(e.run,0,1000000000)
        or type(e.sessions)~='table' or getmetatable(e.sessions) or not S.Integer(e.overflow,0,1000000000)
        or not S.Integer(e.firstAt,1) or not S.Number(e.bytes,0) or e.started~=nil and type(e.started)~='boolean' then return end
    for k in pairs(e) do if not entryKeys[k] then return end end
    for run,session in pairs(e.sessions) do
        if not S.Integer(run,1,e.run) or not S.Text(session,256) or session:sub(1,#owner+2)~=owner..'/s'
            or not S.Integer(tonumber(session:sub(#owner+3)),1,1000000000) then return end
    end
    local bytes=0;for _,row in ipairs(e.rows) do bytes=bytes+S.Size(row) end
    -- Assigned recovery identifiers add bounded metadata after capture.
    if bytes>J.BYTES+J.LIMIT*1024 then return end
    return bytes
end
function J.Prepare(owner,at)
    local db=Root();if not db or not S.Text(owner,240) then Fail('Startup recovery needs attention; its original saved data is kept.');return end
    local e=db.characters[owner]
    if not e then e={rows={},run=0,bytes=0,overflow=0,firstAt=at,sessions={}};db.characters[owner]=e end
    local bytes=ValidEntry(owner,e)
    if not bytes or e.run>=1000000000 then Fail('Startup recovery record is unsupported; its original data is kept.');return end
    e.bytes=bytes;e.run=e.run+1;J.error=nil
    return e,e.run
end
local rowKeys={kind=true,source=true,details=true,evidence=true,at=true,elapsed=true,timeSource=true,location=true,startupParent=true,run=true,targetID=true,targetSession=true}
local function Event(owner,e,row,index)
    if type(row)~='table' or getmetatable(row) or not S.Integer(row.run,1,e.run) then return nil end
    for k in pairs(row) do if not rowKeys[k] then return nil end end
    local details={};if type(row.details)~='table' then return nil end;for k,v in pairs(row.details) do details[k]=v end
    if row.startupParent then
        local parent=S.Integer(row.startupParent,1,(index or 1)-1) and e.rows[row.startupParent]
        if not parent or parent.run~=row.run then return nil end
        details.encounterRef=parent.targetID or owner..':1'
    end
    local raw={schema=S.VERSION,character=owner,id=row.targetID or owner..':1',session=row.targetSession or owner..'/s1',
        kind=row.kind,source=row.source,details=details,evidence=row.evidence,at=row.at,elapsed=row.elapsed,timeSource=row.timeSource,location=row.location}
    local clean=S.Event(raw,owner)
    if clean and S.Preserved(raw,clean) then return clean end
end
local function Same(a,b)
    if not a or not b then return false end
    local x,y={},{};for k,v in pairs(a) do if k~='restored' then x[k]=v end end;for k,v in pairs(b) do if k~='restored' then y[k]=v end end
    return ns.ChronicleBackup.Encode(x)==ns.ChronicleBackup.Encode(y)
end
function J.Busy() return job~=nil end
function J.Has(owner)
    local db=Saved()
    return owner and type(db)=='table' and type(db.characters)=='table' and db.characters[owner]~=nil or false
end
function J.Count()
    local db=Saved();local n=0
    for _,e in pairs(type(db)=='table' and type(db.characters)=='table' and db.characters or {}) do if type(e)=='table' and type(e.rows)=='table' then n=n+#e.rows end end
    return n
end
function J.Merge()
    if job or S.loading or S.blocked or not S.db or S.db.consentVersion~=S.CONSENT
        or not ns.Modules.Enabled('history') or not ns.Membership.Allowed() then return end
    local db=Saved();if db==nil then return end
    if not Root() then Fail('Startup recovery root is unsupported; its original data is kept.');return end
    local owner=C.Owner();local e=owner and db.characters[owner];if not e then return end
    local c=S.Character(owner,true);if not c then return end
    if not Root() or not ValidEntry(owner,e) then Fail('Startup recovery could not be validated; its original data is kept.');return end
    if #e.rows==0 and not e.started then db.characters[owner]=nil;return end
    local targets={};local hasTargets=false
    local function reserve(row,index)
        if not Event(owner,e,row,index) then return false end
        if row.targetID then
            if targets[row.targetID] then return false end
            targets[row.targetID]=true;hasTargets=true
            c.sequence=math.max(c.sequence,tonumber(row.targetID:match(':(%d+)$')) or 0)
        end
        if row.targetSession then c.sessionSequence=math.max(c.sessionSequence,tonumber(row.targetSession:match('/s(%d+)$')) or 0) end
        return true
    end
    for n,row in ipairs(e.rows) do if not reserve(row,n) then Fail('A startup observation needs recovery; original staged data is kept.');return end end
    if e.gap and not reserve(e.gap) then Fail('Startup coverage marker needs recovery; original staged data is kept.');return end
    for _,session in pairs(e.sessions) do c.sessionSequence=math.max(c.sessionSequence,tonumber(session:match('/s(%d+)$'))) end
    local readyAt=C.Stamp()
    J.error=nil
    job={owner=owner,entry=e,root=db,db=S.db,character=c,events=c.events,targets=targets,found={},scan=hasTargets and 1 or #c.events+1,
        count=#c.events,tail=c.events[#c.events],index=1,readyAt=readyAt,merged=0}
    frame:SetScript('OnUpdate',function() J.Pump() end);frame:Show();J.Pump()
end
local function Pump()
    local j=job;if not j then return end
    if Saved()~=j.root or j.root.characters[j.owner]~=j.entry
        or S.db~=j.db or S.Character(j.owner,false)~=j.character or j.character.events~=j.events
        or C.Owner()~=j.owner or not ns.Modules.Enabled('history') or not ns.Membership.Allowed() then J.Cancel();return end
    local c,e=j.character,j.entry;local deadline=ns.WardenPerformance.Begin();local used=0
    if j.scan<=j.count and c.events[j.count]~=j.tail then
        j.count=#c.events;j.tail=c.events[j.count];j.scan=1;j.found={}
    end
    while j.scan<=j.count and used<128 do
        if ns.WardenPerformance.Expired(deadline) then return end
        local event=j.events[j.scan];if j.targets[event.id] then j.found[event.id]=event end
        j.scan=j.scan+1;used=used+1
    end
    if j.scan<=j.count then return end
    local Boot=ns.ChronicleStartup
    while j.index<=#e.rows and used<128 do
        if ns.WardenPerformance.Expired(deadline) then return end
        local row=e.rows[j.index];local existing=row.targetID and j.found[row.targetID]
        if existing then
            if not Same(existing,Event(j.owner,e,row,j.index)) then Fail('Startup recovery conflicts with a saved event; both originals are kept.');return end
        else
            local session=e.sessions[row.run]
            if not session then c.sessionSequence=c.sessionSequence+1;session=j.owner..'/s'..c.sessionSequence;e.sessions[row.run]=session end
            row.targetSession=session;row.targetID=j.owner..':'..(c.sequence+1)
            local event=Event(j.owner,e,row,j.index)
            if not event then Fail('Startup observation validation failed; original staged data is kept.');return end
            local saved=S.Commit(j.owner,event)
            if not saved then Fail('Startup observation could not be committed; original staged data is kept.');return end
            row.targetID=saved.id;j.merged=j.merged+1
            if Boot then Boot.diagnostics.merged=(Boot.diagnostics.merged or 0)+1 end
        end
        j.index=j.index+1;used=used+1
    end
    if j.index<=#e.rows then return end
    local at,clock=C.Stamp();local tick=C.Tick();local session=c.currentSession or e.sessions[e.run]
    if not session then c.sessionSequence=c.sessionSequence+1;session=j.owner..'/s'..c.sessionSequence;c.currentSession=session end
    if not e.gap and at and tick then
        e.gap={kind='collection_gap',source='control',run=e.run,targetSession=session,at=at,elapsed=tick,timeSource=clock,evidence='observed',location={},
            details={reason='Startup coverage is partial: no routes, inspections, scoreboard snapshots or full duel sessions during archive validation',
                firstAt=e.firstAt,lastAt=j.readyAt or at,count=#e.rows,samples=e.overflow or 0}}
    end
    if not e.gap then Fail('Startup recovery is waiting for a reliable clock; its data is kept.');return end
    local existing=e.gap.targetID and j.found[e.gap.targetID]
    if existing then
        if not Same(existing,Event(j.owner,e,e.gap)) then Fail('Startup coverage marker conflicts with saved evidence; both originals are kept.');return end
    else
        e.gap.targetID=j.owner..':'..(c.sequence+1)
        local saved=S.Commit(j.owner,Event(j.owner,e,e.gap))
        if not saved then Fail('Startup coverage marker could not be saved; recovery journal is kept.');return end
        C.diagnostics.gaps=C.diagnostics.gaps+1
    end
    if j.root.characters[j.owner]==e then j.root.characters[j.owner]=nil end
    job=nil;J.error=nil;frame:SetScript('OnUpdate',nil)
end
function J.Pump()
    local ok=pcall(Pump)
    if not ok then Fail('Startup recovery was interrupted; its original observations are kept for retry.') end
end
