-- Personal history backups are data, never executable Lua or signed rule packs.
local _,ns=...
local S,P=ns.ChronicleStore,ns.PackCrypto
local B={LIMIT=24000,TEXT_LIMIT=33000};ns.ChronicleBackup=B
local function Encode(v,depth)
    depth=depth or 0;assert(depth<12,'Backup nesting limit.')
    local t=type(v)
    if t=='string' then return 's'..#v..':'..v
    elseif t=='number' then assert(S.Number(v));local n=string.format('%.17g',v);return 'n'..#n..':'..n
    elseif t=='boolean' then return v and 'b1' or 'b0' end
    assert(t=='table' and not getmetatable(v),'Unsupported backup value.')
    local keys={};for k in pairs(v) do assert(type(k)=='string' or type(k)=='number');keys[#keys+1]=k end
    table.sort(keys,function(a,b) if type(a)~=type(b) then return type(a)<type(b) end;return a<b end)
    local out={'t'..#keys..':'}
    for _,k in ipairs(keys) do out[#out+1]=Encode(k,depth+1);out[#out+1]=Encode(v[k],depth+1) end
    return table.concat(out)
end
B.Encode=Encode
local function Decode(text,saved)
    local pos,nodes=1,0
    local function length()
        local n,last=text:match('^(%d+):()',pos);assert(n and #n<7,'Invalid backup length.')
        pos=last;return tonumber(n)
    end
    local function value(depth)
        nodes=nodes+1;assert(depth<12 and nodes<=(saved and 50000 or 6000),'Backup nesting or item limit.')
        local t=text:sub(pos,pos);pos=pos+1
        if t=='b' then local c=text:sub(pos,pos);pos=pos+1;assert(c=='0' or c=='1');return c=='1' end
        local n=length()
        if t=='s' or t=='n' then
            assert(n<=(saved and 196608 or B.LIMIT) and pos+n-1<=#text);local v=text:sub(pos,pos+n-1);pos=pos+n
            if t=='s' then return v end
            assert(v:match('^[%d%.eE%+%-]+$'));v=tonumber(v);assert(S.Number(v));return v
        end
        assert(t=='t' and n<=1500);local out={}
        for _=1,n do
            local k=value(depth+1);assert(type(k)=='string' or S.Integer(k,1,1500));assert(out[k]==nil,'Duplicate backup key.')
            out[k]=value(depth+1)
        end
        return out
    end
    local result=value(0);assert(pos==#text+1,'Trailing backup data.');return result
end
function B.DecodeChunk(text)
    if type(text)~='string' or #text>196608 then return end
    local ok,value=pcall(Decode,text,true);if ok and S.Array(value,1000) then return value end
end
function B.PackSaved(db)
    if S.blocked or not db then return end
    local packed={};for key,value in pairs(db) do if key~='characters' then packed[key]=value end end
    packed.characters={}
    local function chunks(records,map)
        local out,rows,size={}, {},0
        local function flush()
            local encoded={'t'..#rows..':'}
            for n,value in ipairs(rows) do encoded[#encoded+1]=Encode(n);encoded[#encoded+1]=value end
            out[#out+1]=table.concat(encoded);rows={};size=0
        end
        for _,v in (map and pairs or ipairs)(records) do
            local encoded=Encode(v);local n=#encoded
            if n>196580 then return end
            if #rows>0 and size+n>20000 then flush() end
            rows[#rows+1]=encoded;size=size+n
            if size>20000 then flush() end
        end
        if #rows>0 then flush() end
        return out
    end
    for owner,c in pairs(db.characters) do
        if c.storageFormat==1 then
            -- Unopened/partially loading archives are opaque and never empty.
            packed.characters[owner]=c
        else
        if c.storageFormat~=nil or not S.Array(c.events,1000000000) or type(c.profiles)~='table' or getmetatable(c.profiles) then return end
        local copy={};for key,value in pairs(c) do if key~='events' and key~='profiles' then copy[key]=value end end
        copy.eventChunks=chunks(c.events);copy.profileChunks=chunks(c.profiles,true);copy.storageFormat=1
        if not copy.eventChunks or not copy.profileChunks then return end
        packed.characters[owner]=copy
        end
    end
    return packed
end
local function Busy() return InCombatLockdown and InCombatLockdown() end
local function Exact(t,keys)
    if type(t)~='table' or getmetatable(t) then return false end
    for k in pairs(t) do if not keys[k] then return false end end
    for k in pairs(keys) do if t[k]==nil then return false end end
    return true
end
local function Envelope(raw,checkpoint)
    return 'OCW-HISTORY-1:'..P.Hex(P.SHA256(raw,checkpoint))..'\n'..P.Base64Encode(raw)
end
-- Snapshot the export once. Advancing parts never picks up newer live events.
function B.Create(checkpoint)
    if Busy() then return nil,'Create a backup after combat.' end
    if S.blocked or not S.db then return nil,'Saved history format is unavailable. Use the SavedVariables file backup.' end
    if S.db.enabled then return nil,'Pause recording before creating a text backup. Resume it after copying your snapshot.' end
    if ns.ChronicleStartupJournal and (ns.ChronicleStartupJournal.Count()>0 or ns.ChronicleStartupJournal.error) then return nil,'Startup observations await recovery. The complete SavedVariables file backup includes them; text export must wait.' end
    if ns.AthenaCastCounts and not ns.AthenaCastCounts.BackupReady() then return nil,'Cast observations await commit. Keep the complete SavedVariables file backup; text export must wait.' end
    local ready,reason=S.RequireCharacters()
    while not ready and checkpoint and reason and reason:find('Loading requested',1,true) do
        checkpoint('materializing');ready,reason=S.RequireCharacters()
    end
    if not ready then return nil,reason end
    if checkpoint then checkpoint('materializing') end
    local blocks=0
    local hashCheckpoint=checkpoint and function() blocks=blocks+1;if blocks%16==0 then checkpoint() end end or nil
    local parts={};local owners={};for owner in pairs(S.db.characters) do owners[#owners+1]=owner end;table.sort(owners)
    for _,owner in ipairs(owners) do
        local c=S.db.characters[owner];local records={};local included={}
        local objects=ns.ChronicleCapture and ns.ChronicleCapture.ObjectIndex(c.events) or {}
        local function flush()
            if #records>0 then parts[#parts+1]={owner=owner,sequence=c.sequence,sessionSequence=c.sessionSequence,records=records} end
            records={};included={}
        end
        local function add(record)
            if checkpoint then checkpoint() end
            local dependencies={}
            if record.event and ns.ChronicleCapture then
                local err;dependencies,err=ns.ChronicleCapture.Dependencies(record.event,objects)
                if not dependencies then error(err,0) end
            end
            local function bundle()
                local out={}
                for _,e in ipairs(dependencies) do if not included[e.id] then out[#out+1]={event=e} end end
                if not record.event or not included[record.event.id] then out[#out+1]=record end
                return out
            end
            local group=bundle();local probe={};for _,r in ipairs(records) do probe[#probe+1]=r end
            for _,r in ipairs(group) do probe[#probe+1]=r end
            if #records>0 and #Encode({owner=owner,records=probe})>18000 then flush();group=bundle() end
            for _,r in ipairs(group) do records[#records+1]=r;if r.event then included[r.event.id]=true end end
            if #Encode({owner=owner,records=records})>22000 then error('A linked snapshot exceeds the text-backup part limit. Use the complete SavedVariables file backup.',0) end
        end
        for _,e in ipairs(c.events) do add({event=e}) end
        local guids={};for guid in pairs(c.profiles) do guids[#guids+1]=guid end;table.sort(guids)
        for _,guid in ipairs(guids) do add({profile=c.profiles[guid]}) end
        flush()
    end
    if #parts==0 then return nil,'No recorded history to export yet.' end
    local text,hashes={},{}
    for i,p in ipairs(parts) do p.index=i;p.total=#parts;p.format=1;text[i]=Encode(p);hashes[i]=P.Hex(P.SHA256(text[i],hashCheckpoint)) end
    local batch=P.Hex(P.SHA256(table.concat(hashes),hashCheckpoint))
    for i,raw in ipairs(text) do
        local data=parts[i];data.batch=batch;raw=Encode(data)
        if #raw>B.LIMIT then return nil,'A history record is too large for text export. Use the complete SavedVariables file backup.' end
        text[i]=Envelope(raw,hashCheckpoint)
    end
    return {parts=text,batch=batch,total=#text}
end
-- Export cooperatively; no long synchronous loop on the game UI thread.
function B.Begin(done)
    if B.job then return false,'A text backup is already being created.' end
    if Busy() or S.db and S.db.enabled then return false,'Pause recording and create the text backup out of combat.' end
    local revision=S.revision;local materialized=S.materializationRevision or 0;local job={};B.job=job
    local function checkpoint(phase)
        local delta=(S.materializationRevision or 0)-materialized
        if phase=='materializing' and S.revision==revision+delta then revision=S.revision;materialized=S.materializationRevision or 0 end
        if S.revision~=revision or S.blocked or not S.db or S.db.enabled or Busy() then error('History changed or combat began. Pause recording and create a new snapshot.',0) end
        coroutine.yield()
    end
    job.thread=coroutine.create(function() return B.Create(checkpoint) end)
    local pump
    pump=function()
        if B.job~=job then return end
        for _=1,4 do
            local ok,value,err=coroutine.resume(job.thread)
            if not ok or coroutine.status(job.thread)=='dead' then
                B.job=nil;if ok then done(value,err) else done(nil,tostring(value)) end;return
            end
        end
        if C_Timer and C_Timer.After then C_Timer.After(.01,pump)
        else
            B.worker=B.worker or CreateFrame('Frame');B.worker:SetScript('OnUpdate',function(self) self:SetScript('OnUpdate',nil);pump() end)
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0,pump) else pump() end
    return true
end
function B.Cancel() B.job=nil;if B.worker then B.worker:SetScript('OnUpdate',nil) end end
function B.Validate(text)
    if type(text)~='string' or #text>B.TEXT_LIMIT then return nil,'Paste one complete backup part (up to 33,000 bytes).' end
    local hash,encoded=text:match('^%s*OCW%-HISTORY%-1:([a-f0-9]+)%s+([A-Za-z0-9+/=%s]+)%s*$')
    if not hash or #hash~=64 then return nil,'This is not a ChatWarden history backup part.' end
    encoded=encoded:gsub('%s','');local raw=P.Base64Decode(encoded,B.LIMIT)
    if not raw or #raw>B.LIMIT or P.Hex(P.SHA256(raw))~=hash then return nil,'Backup checksum failed. Copy the complete part again.' end
    local ok,p=pcall(Decode,raw)
    if not ok or not Exact(p,{owner=true,sequence=true,sessionSequence=true,records=true,index=true,total=true,format=true,batch=true})
        or p.format~=1 or not S.Text(p.owner,240) or not S.Integer(p.sequence,0,1000000000)
        or not S.Integer(p.sessionSequence,0,1000000000) or not S.Integer(p.total,1,1000000000)
        or not S.Integer(p.index,1,p.total) or type(p.batch)~='string' or #p.batch~=64 or p.batch:find('[^a-f0-9]')
        or type(p.records)~='table' then return nil,'Invalid or unsupported backup data.' end
    local clean={events={},profiles={},sequence=p.sequence,sessionSequence=p.sessionSequence}
    local count=0;for k in pairs(p.records) do count=count+1;if not S.Integer(k,1,#p.records) then return nil,'Invalid record array.' end end
    if count~=#p.records then return nil,'Invalid record array.' end
    local seen={}
    for _,item in ipairs(p.records) do
        if Exact(item,{event=true}) then
            local e=S.Event(item.event,p.owner)
            if not e or Encode(e)~=Encode(item.event) or seen[e.id] then return nil,'Invalid or duplicate history event.' end
            if e.route and not ns.ChronicleCodec.Decode(e.route) then return nil,'Invalid packed route data.' end
            seen[e.id]=true;e.restored=true;clean.events[#clean.events+1]=e
        elseif Exact(item,{profile=true}) then
            local v=item.profile
            if type(v)~='table' or not S.GUID(v.guid) or clean.profiles[v.guid] then return nil,'Invalid player profile.' end
            local temp={schema=1,characters={[p.owner]={profiles={[v.guid]=v}}}}
            local n=S.Normalize(temp);local profile=n and n.characters[p.owner].profiles[v.guid]
            if not profile or Encode(profile)~=Encode(v) then return nil,'Invalid player profile facts.' end
            profile.restored=true;clean.profiles[v.guid]=profile
        else return nil,'Unknown backup record.' end
    end
    if ns.ChronicleCapture then
        local objects=ns.ChronicleCapture.ObjectIndex(clean.events)
        for _,e in ipairs(clean.events) do
            local deps,err=ns.ChronicleCapture.Dependencies(e,objects)
            if not deps then return nil,err end
        end
    end
    p.clean=clean;p.partHash=hash;return p
end
function B.Restore(text)
    if Busy() then return false,'Restore history after combat.' end
    if S.blocked or not S.db then return false,'Saved history format is unavailable.' end
    if S.db.enabled then return false,'Pause recording before restoring a backup.' end
    if ns.ChronicleStartupJournal and (ns.ChronicleStartupJournal.Count()>0 or ns.ChronicleStartupJournal.error) then return false,'Wait for recording recovery before restoring text history. The complete SavedVariables file backup includes pending observations.' end
    if ns.AthenaCastCounts and not ns.AthenaCastCounts.BackupReady() then return false,'Wait for pending cast recovery before restoring text history. Keep the complete SavedVariables file backup.' end
    local p,err=B.Validate(text);if not p then return false,err end
    local prior=S.db.lastRestore
    if prior and prior.batch==p.batch and (prior.total~=p.total or prior.parts[p.index] and prior.parts[p.index]~=p.partHash) then
        return false,'This part conflicts with the same numbered part of this backup. Existing history was kept.'
    end
    local ready,loading=S.RequireCharacters(p.owner)
    if not ready then return false,loading end
    local old=S.Character(p.owner,false)
    local candidate={events={},profiles={},sequence=p.sequence,sessionSequence=p.sessionSequence,bytes=0,pruned=old and old.pruned or 0,dropped=old and old.dropped or 0,updated=0}
    local byID={}
    if old then
        candidate.sequence=math.max(candidate.sequence,old.sequence);candidate.sessionSequence=math.max(candidate.sessionSequence,old.sessionSequence)
        candidate.currentSession=old.currentSession;candidate.updated=old.updated or 0
        for _,e in ipairs(old.events) do candidate.events[#candidate.events+1]=e;byID[e.id]=e end
        for guid,v in pairs(old.profiles) do candidate.profiles[guid]=v end
    end
    local added=0
    for _,e in ipairs(p.clean.events) do
        local existing=byID[e.id]
        if existing then
            local a,b={},{};for k,v in pairs(existing) do if k~='restored' then a[k]=v end end
            for k,v in pairs(e) do if k~='restored' then b[k]=v end end
            if Encode(a)~=Encode(b) then return false,'Conflicting event ID. Existing history was kept; this part was not restored.' end
        else candidate.events[#candidate.events+1]=e;byID[e.id]=e;added=added+1 end
        candidate.sequence=math.max(candidate.sequence,tonumber(e.id:match(':(%d+)$')) or 0)
        candidate.sessionSequence=math.max(candidate.sessionSequence,tonumber(e.session:match('/s(%d+)$')) or 0)
        candidate.updated=math.max(candidate.updated,e.at)
    end
    for guid,incoming in pairs(p.clean.profiles) do
        candidate.updated=math.max(candidate.updated,incoming.lastObserved)
        local existing=candidate.profiles[guid]
        if not existing then candidate.profiles[guid]=incoming
        else
            local merged={guid=guid,firstObserved=math.min(existing.firstObserved,incoming.firstObserved),
                lastObserved=math.max(existing.lastObserved,incoming.lastObserved),lastSource=existing.lastSource,
                restored=existing.restored or incoming.restored,facts={},personal=existing.personal or incoming.personal,
                lastSighting=existing.lastSighting,lastEncounter=existing.lastEncounter}
            if incoming.lastObserved>existing.lastObserved then merged.lastSource=incoming.lastSource end
            for k,v in pairs(existing.facts) do merged.facts[k]=v end
            for k,v in pairs(incoming.facts) do if not merged.facts[k] or v.at>merged.facts[k].at then merged.facts[k]=v end end
            if incoming.lastSighting and (not merged.lastSighting or incoming.lastSighting.at>merged.lastSighting.at) then merged.lastSighting=incoming.lastSighting end
            if incoming.lastEncounter and (not merged.lastEncounter or incoming.lastEncounter.at>merged.lastEncounter.at) then merged.lastEncounter=incoming.lastEncounter end
            candidate.profiles[guid]=merged
        end
    end
    table.sort(candidate.events,function(a,b) if a.at==b.at then return tonumber(a.id:match(':(%d+)$'))<tonumber(b.id:match(':(%d+)$')) end;return a.at<b.at end)
    for _,e in ipairs(candidate.events) do candidate.bytes=candidate.bytes+S.Size(e) end
    for _,v in pairs(candidate.profiles) do candidate.bytes=candidate.bytes+S.Size(v) end
    -- Commit only after every event, fact and conflict in this part was checked.
    S.db.characters[p.owner]=candidate;S.Prune(candidate)
    if not prior or prior.batch~=p.batch then prior={batch=p.batch,total=p.total,parts={}} end
    prior.parts[p.index]=p.partHash;S.db.lastRestore=prior
    local count=0;for _ in pairs(prior.parts) do count=count+1 end
    return true,'Part '..p.index..' restored ('..added..' new events). '..count..' of '..p.total..' parts from this backup restored. Recording stays off.',p
end
