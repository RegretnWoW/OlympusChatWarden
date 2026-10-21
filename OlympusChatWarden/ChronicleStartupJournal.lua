-- Full normal-collector evidence, independent of unvalidated history.
-- Chunk sizes bound decoding work; they never limit total retained observations.
local _,ns=...
local S,C=ns.ChronicleStore,ns.Chronicle
local J={VERSION=2,diagnostics={accepted=0,committed=0,merged=0,reused=0,rejected=0}};ns.ChronicleStartupJournal=J
local frame=CreateFrame('Frame');local writer,job
if frame.SetOnUpdateMode and Enum and Enum.OnUpdateMode and Enum.OnUpdateMode.RunAlways then
    pcall(frame.SetOnUpdateMode,frame,Enum.OnUpdateMode.RunAlways)
end
local function Table(t) return type(t)=='table' and not getmetatable(t) end
local function Encode(t) return ns.ChronicleBackup.Encode(t) end
local function Copy(t)
    if type(t)~='table' then return t end
    local out={};for k,v in pairs(t) do out[k]=Copy(v) end;return out
end
local function Fail(reason)
    if J.error~=reason then ns.Print(reason) end
    J.error=reason;job=nil;frame:SetScript('OnUpdate',nil)
end
local function Root()
    local db=OlympusWardenStartupDB
    if db==nil then db={version=2,characters={}};OlympusWardenStartupDB=db end
    if Table(db) and db.version==1 then
        -- Preserve the complete v1 root for its original reader, including IDs.
        db={version=2,characters={},legacy=db};OlympusWardenStartupDB=db
    end
    if not Table(db) or db.version~=2 or not Table(db.characters) then return end
    for k in pairs(db) do if k~='version' and k~='characters' and k~='legacy' then return end end
    return db
end
local function Wake() frame:Show();frame:SetScript('OnUpdate',function() J.Pump() end) end
local function SequenceBase(g,n)
    return g.collisionPivot and n>=g.collisionPivot and g.collisionBase or g.baseSequence
end
local function Reserve(c,g)
    if not c or not g.baseSequence then return true end
    local sequence=math.max(c.sequence,g.baseSequence+g.sequence,(g.collisionBase or g.baseSequence)+g.sequence)
    local session=math.max(c.sessionSequence,g.baseSession+g.sessionSequence-(g.resolvedSession and 1 or 0))
    if not S.Integer(sequence,0,1000000000) or not S.Integer(session,0,1000000000) then return false end
    c.sequence=sequence;c.sessionSequence=session;return true
end
function J.Cancel() job=nil;frame:SetScript('OnUpdate',nil);ns.ChronicleStartupLegacy.Cancel() end
function J.Reset() J.Cancel();writer=nil;J.quitting=nil end
function J.Freeze() J.quitting=true;J.Cancel() end
function J.Clear() J.Reset();OlympusWardenStartupDB={version=2,characters={}};J.error=nil end
function J.Character(owner) return writer and writer.owner==owner and not J.error and writer.character end
function J.WriteRoot() return writer and not J.error and writer.db end
function J.Writing() return writer~=nil end
function J.WriterGeneration() return writer and writer.g.id end
function J.Boundary()
    -- Runtime collectors can still hold provisional IDs until they all stop.
    if writer and writer.streaming and writer.g.committed==writer.g.total then
        if not Reserve(S.Character(writer.owner,false),writer.g) then Fail('Recovery identity reservation needs attention; original evidence is kept.');return end
        if #writer.entry.generations==0 then writer.root.characters[writer.owner]=nil end
        writer=nil
    end
end
function J.Resume(reload)
    if writer and reload and writer.character.currentSession==nil then
        writer.g.resume=true;writer.character.currentSession=writer.owner..'/s1';writer.character.sessionSequence=1
    end
end
local function ValidGeneration(g,owner)
    if not Table(g) or not S.Integer(g.id,1,1000000000) or not S.Integer(g.firstAt,1)
        or not S.Array(g.chunks,1000000000) or not S.Array(g.tail,32)
        or not S.Integer(g.total,0,1000000000) or not S.Integer(g.committed,0,g.total)
        or not S.Integer(g.sequence,0,1000000000) or not S.Integer(g.sessionSequence,0,1000000000)
        or not S.Number(g.bytes,0) then return false end
    local keys={id=true,firstAt=true,chunks=true,tail=true,total=true,committed=true,sequence=true,sessionSequence=true,
        currentSession=true,bytes=true,baseSequence=true,baseSession=true,hashes=true,resume=true,resolvedSession=true,collisionPivot=true,collisionBase=true}
    for k in pairs(g) do if not keys[k] then return false end end
    if (g.baseSequence==nil)~=(g.baseSession==nil) then return false end
    if g.committed>0 and g.baseSequence==nil then return false end
    if g.baseSequence and (not S.Integer(g.baseSequence,0,1000000000) or not S.Integer(g.baseSession,0,1000000000)) then return false end
    if (g.collisionPivot==nil)~=(g.collisionBase==nil) then return false end
    if g.collisionPivot and (not g.baseSequence or not S.Integer(g.collisionPivot,1,g.sequence)
        or not S.Integer(g.collisionBase,g.baseSequence+1,1000000000-g.sequence)) then return false end
    if g.hashes~=nil and not Table(g.hashes) then return false end
    if g.resume~=nil and type(g.resume)~='boolean' then return false end
    for _,key in ipairs({'currentSession','resolvedSession'}) do
        local value=g[key]
        if value~=nil and (not S.Text(value,256) or value:sub(1,#owner+2)~=owner..'/s'
            or not S.Integer(tonumber(value:sub(#owner+3)),1,1000000000)) then return false end
    end
    for old,new in pairs(g.hashes or {}) do
        if type(old)~='string' or type(new)~='string' or #old~=64 or #new~=64 or old:find('[^a-f0-9]') or new:find('[^a-f0-9]') then return false end
    end
    return true
end
local function Entry(db,owner)
    local e=db.characters[owner]
    if not e then e={nextGeneration=0,generations={}};db.characters[owner]=e end
    if not Table(e) or not S.Integer(e.nextGeneration,0,999999999) or not S.Array(e.generations,1000000000) then return end
    for k in pairs(e) do if k~='nextGeneration' and k~='generations' then return end end
    -- Inspect only the next boundary, never scan all generations on an event.
    -- Duplicate/reversed IDs must not acquire a second final offset and replay.
    local first,nextGeneration,last=e.generations[1],e.generations[2],e.generations[#e.generations]
    for _,g in pairs({first=first,last=last}) do
        if not Table(g) or not S.Integer(g.id,1,e.nextGeneration) then return end
    end
    if nextGeneration and (not Table(nextGeneration) or not S.Integer(nextGeneration.id,1,e.nextGeneration)
        or nextGeneration.id<=first.id) then return end
    return e
end
function J.Open(owner,source,at)
    if writer then return writer.owner==owner and not J.error end
    local db=Root();local e=db and Entry(db,owner)
    if not e or not at then Fail('Recording recovery is unsupported. Original history and journal are kept; new capture is blocked.');return false end
    -- Never decode older generations before enabling current event-time reads.
    e.nextGeneration=e.nextGeneration+1
    local g={id=e.nextGeneration,firstAt=at,chunks={},tail={},total=0,committed=0,sequence=0,sessionSequence=0,bytes=0}
    e.generations[#e.generations+1]=g
    local c={events={},profiles={},sequence=0,sessionSequence=0,bytes=0,pruned=0,dropped=0}
    writer={owner=owner,root=db,entry=e,g=g,character=c,db={schema=S.VERSION,enabled=source.enabled,
        consentVersion=source.consentVersion,duels=source.duels,duelConsent=source.duelConsent,characters={[owner]=c},olympusState={}}}
    J.error=nil;Wake();return true
end
local function Stage(op)
    if not writer or J.error then return false end
    local w,g=writer,writer.g
    if OlympusWardenStartupDB~=w.root or w.root.characters[w.owner]~=w.entry then Fail('Recording recovery changed unexpectedly; both histories are kept.');return false end
    if w.entry.generations[#w.entry.generations]~=g then w.entry.generations[#w.entry.generations+1]=g end
    -- Copy on acceptance: later mutations cannot change earlier evidence.
    op=Copy(op);g.tail[#g.tail+1]=op;g.total=g.total+1;g.bytes=g.bytes+S.Size(op)
    g.sequence=w.character.sequence;g.sessionSequence=w.character.sessionSequence;g.currentSession=w.character.currentSession
    -- Reserve accepted provisional identities BEFORE a pause/reload can switch
    -- back to direct writes. Coroutine completion can occur a frame later.
    if not S.loading and not S.blocked and not Reserve(S.Character(w.owner,false),g) then Fail('Recovery identity reservation needs attention; original evidence is kept.');return false end
    -- The structured original is retained even when sealing fails.
    J.diagnostics.accepted=J.diagnostics.accepted+1
    if #g.tail>=32 or S.Size(g.tail)>=24000 then
        local ok,text=pcall(Encode,g.tail)
        if not ok or type(text)~='string' or #text>196608 then
            Fail('Recording journal encoding needs attention. Original observations remain in its structured tail.');return false
        end
        g.chunks[#g.chunks+1]={first=g.total-#g.tail+1,last=g.total,text=text};g.tail={}
    end
    Wake();return true
end
function J.RecordEvent(event)
    if not writer then return true end
    return Stage({kind='event',value=event}),writer.streaming==true
end
function J.RecordProfile(owner,p) if writer and writer.owner==owner then return Stage({kind='profile',value=p}) end end
function J.RecordState(key) if writer then return Stage({kind='state',key=key,value=writer.db.olympusState[key]}) end end
function J.Reject(reason)
    J.diagnostics.rejected=J.diagnostics.rejected+1;J.lastRejected=reason
end
function J.Count()
    local db=OlympusWardenStartupDB;local n=0
    for _,e in pairs(Table(db) and Table(db.characters) and db.characters or {}) do
        for _,g in ipairs(Table(e) and Table(e.generations) and e.generations or {}) do
            if Table(g) and type(g.total)=='number' and type(g.committed)=='number' then n=n+math.max(0,g.total-g.committed) end
        end
    end
    return n+ns.ChronicleStartupLegacy.Count()
end
function J.Has(owner)
    local db=OlympusWardenStartupDB
    local e=Table(db) and Table(db.characters) and db.characters[owner]
    return Table(e) and Table(e.generations) and #e.generations>0 or ns.ChronicleStartupLegacy.Has(owner)
end
function J.Busy() return job~=nil or ns.ChronicleStartupLegacy.Busy() end
local refKeys={id=true,session=true,runID=true,encounterRef=true,scoreReportID=true,duelID=true,snapshotID=true,segmentID=true,segment=true}
local hashKeys={gearRef=true,traitRef=true,appearanceRef=true,contentID=true}
refKeys.combatWindowID=true
for _,key in ipairs({'rosterRef','instanceRef','matchRef','basisRef','incidentRef'}) do refKeys[key]=true end
local function VerifiedHash(j,old,mapped)
    if old==mapped then return mapped end
    if j.hashProof and j.hashProof[old]==mapped then return mapped end
    local object=j.objects[mapped];local capture=object and object.capture
    -- Of the supported snapshot fields, only runID changes a content hash
    -- during ID rebasing. Prove the old fingerprint from the validated object;
    -- a well-shaped hash mapping alone cannot establish the association.
    local run=capture and capture.values.runID;local prefix=j.owner..':'
    local sequence=type(run)=='string' and run:sub(1,#prefix)==prefix and tonumber(run:sub(#prefix+1))
    if not S.Integer(sequence,1,1000000000) or sequence<=j.g.baseSequence then error('Recovery snapshot mapping has no valid original run') end
    local g=j.g;local originalSequence=sequence-g.baseSequence
    if g.collisionPivot and sequence>=g.collisionPivot+g.collisionBase and sequence<=g.sequence+g.collisionBase then originalSequence=sequence-g.collisionBase end
    local original=Copy(capture);original.values.runID=prefix..originalSequence
    if not ns.ChronicleCapture.MatchesHash(original,old,j.checkpoint) then error('Recovery snapshot mapping conflicts with its original fingerprint') end
    if not j.hashProof or j.hashProofCount>=128 then j.hashProof={};j.hashProofCount=0 end
    j.hashProof[old]=mapped;j.hashProofCount=j.hashProofCount+1
    return mapped
end
local function Rewrite(j,value,key)
    if type(value)=='table' then local out={};for k,v in pairs(value) do out[k]=Rewrite(j,v,k) end;return out end
    if type(value)~='string' then return value end
    if hashKeys[key] then local mapped=j.hashes[value];return mapped and VerifiedHash(j,value,mapped) or value end
    if not refKeys[key] then return value end
    local owner,g=j.owner,j.g
    for _,prefix in ipairs({owner..':',owner..'/s',owner..'/duel/'}) do
        if value:sub(1,#prefix)==prefix then
            local n,rest=value:sub(#prefix+1):match('^(%d+)(.*)$')
            if n and (rest=='' or rest:sub(1,1)=='/') then
                local base=prefix==owner..'/s' and g.baseSession or SequenceBase(g,tonumber(n))
                if prefix==owner..'/s' then
                    local kind,sequence=rest:match('^/(olympus)(%d+)$')
                    if not kind then kind,sequence=rest:match('^/(route)(%d+)$') end
                    if kind then rest='/'..kind..(tonumber(sequence)+g.baseSequence) end
                    if g.resolvedSession then
                        if tonumber(n)==1 then return g.resolvedSession..rest end
                        base=base-1
                    end
                end
                return prefix..(tonumber(n)+base)..rest
            end
        end
    end
    return value
end
local function MergeProfile(c,p)
    local old=c.profiles[p.guid];local before=old and S.Size(old) or 0
    if not old then old=Copy(p);c.profiles[p.guid]=old else
        old.firstObserved=math.min(old.firstObserved,p.firstObserved)
        if p.lastObserved>=old.lastObserved then old.lastObserved=p.lastObserved;old.lastSource=p.lastSource end
        for k,f in pairs(p.facts) do if not old.facts[k] or f.at>=old.facts[k].at then old.facts[k]=Copy(f) end end
        for _,k in ipairs({'lastSighting','lastEncounter'}) do if p[k] and (not old[k] or p[k].at>=old[k].at) then old[k]=Copy(p[k]) end end
        -- Private notes/watch settings are never replaced by a capture baseline.
    end
    c.bytes=c.bytes+S.Size(old)-before;c.updated=math.max(c.updated or 0,p.lastObserved);S.Prune(c,p.lastObserved)
end
local function Apply(j,op)
    if not Table(op) or not Table(op.value) then error('Invalid recovery operation') end
    for k in pairs(op) do if k~='kind' and k~='value' and k~='key' then error('Unsupported recovery field') end end
    if op.kind=='event' then
        local raw=op.value;local validated=S.Event(raw,j.owner,j.checkpoint)
        if not validated or not S.Preserved(raw,validated) then error('Recovery event did not validate') end
        if raw.route and raw.route.format==2 and not ns.ChronicleCodec.Decode(raw.route,j.checkpoint) then error('Recovery route checksum failed') end
        local input=raw
        if raw.capture then
            -- A previous save may contain the computed mapping before the
            -- object append finished. Its pending payload proves its own hash.
            input={};for k,v in pairs(raw) do input[k]=v end
            input.details=Copy(raw.details);input.details.contentID=nil
        end
        local event=Rewrite(j,input)
        if event.capture then
            local hash=ns.ChronicleCapture.Hash(event.capture,j.checkpoint)
            local previous=j.hashes[raw.details.contentID]
            if previous and previous~=hash then error('Pending snapshot conflicts with its recovery fingerprint mapping') end
            j.hashes[raw.details.contentID]=hash;event.details.contentID=hash
            local old=j.objects[hash]
            if old then
                if not ns.ChronicleCapture.SameSnapshot(old.capture,event.capture,hash,j.checkpoint) then error('Snapshot fingerprint conflict') end
                J.diagnostics.reused=J.diagnostics.reused+1;return
            end
        end
        local deps,why=ns.ChronicleCapture.Dependencies(event,j.objects);if not deps then error(why) end
        local existing=j.ids[event.id]
        if existing then
            local a,b=Copy(existing),Copy(event);a.restored=nil;b.restored=nil
            if Encode(a)~=Encode(b) then
                -- Older builds could release the provisional writer before its
                -- final sequence reservation, then reuse a pending ID. Preserve
                -- BOTH distinct observations. Allocate the remaining provisional
                -- range above all retained/reserved IDs, persist its mapping,
                -- and apply it to every supported dependent reference.
                local n=tonumber(raw.id:match(':(%d+)$'))
                if j.g.collisionPivot or not S.Integer(n,1,j.g.sequence) then error('Saved event conflicts with recovery evidence') end
                local base=math.max(j.c.sequence,j.g.baseSequence+j.g.sequence)+1-n
                if not S.Integer(base,j.g.baseSequence+1,1000000000-j.g.sequence) then error('Recovery collision identity space exhausted') end
                if event.capture then error('Recovery object identity conflict requires source recovery; originals kept') end
                j.g.collisionPivot=n;j.g.collisionBase=base;Reserve(j.c,j.g)
                event=Rewrite(j,input);existing=j.ids[event.id]
                if existing then error('Recovery collision reservation is not unique') end
                J.diagnostics.collisions=(J.diagnostics.collisions or 0)+1
            end
        end
        if not existing then
            local saved=S.Commit(j.owner,event,j.checkpoint);if not saved or Encode(saved)~=Encode(event) then error('Recovery commit did not preserve complete evidence') end
            if ns.AthenaLab and ns.AthenaLab.Current() then pcall(ns.AthenaLab.CanonicalMapping,input.id,saved.id,saved.subject) end
            if ns.Athena and ns.Athena.CommitLiveNotice then ns.Athena.Try(ns.Athena.CommitLiveNotice,input.id,saved,j.g.id) end
            j.ids[saved.id]=saved;if saved.capture then j.objects[saved.details.contentID]=saved end
            J.diagnostics.merged=J.diagnostics.merged+1
        end
    elseif op.kind=='profile' then
        local p=op.value
        local check=S.Normalize({schema=S.VERSION,characters={[j.owner]={events={},profiles={[p.guid or '']=p}}}})
        if not check or not S.Preserved(p,check.characters[j.owner].profiles[p.guid]) then error('Recovery profile did not validate') end
        MergeProfile(j.c,p)
    elseif op.kind=='state' then
        if type(op.key)~='string' or op.key:sub(1,#j.owner+1)~=j.owner..'/' then error('Recovery state owner mismatch') end
        local state=Rewrite(j,op.value)
        local check=S.Normalize({schema=S.VERSION,olympusState={[op.key]=state}})
        if not check or not S.Preserved(state,check.olympusState[op.key]) then error('Recovery source state did not validate') end
        j.db.olympusState[op.key]=state
    else error('Unknown recovery operation') end
end
local function Run(j)
    local g=j.g;j.checkpoint=function() coroutine.yield() end
    g.baseSequence=g.baseSequence or j.c.sequence;g.baseSession=g.baseSession or j.c.sessionSequence
    if g.resume and not g.resolvedSession and g.committed==0 then g.resolvedSession=j.c.currentSession end
    if not Reserve(j.c,g) then error('Recovery identity space exhausted') end
    if not j.indexed then
        for n,event in ipairs(j.c.events) do
            local seq=tonumber(event.id:match(':(%d+)$'))
            if seq and seq>g.baseSequence then j.ids[event.id]=event end
            if event.capture then j.objects[event.details.contentID]=event end
            if n%128==0 then coroutine.yield() end
        end
        j.indexed=true
    end
    if g.sequence+g.baseSequence>1000000000 or g.sessionSequence+g.baseSession>1000000000 then error('Recovery identity space exhausted') end
    local expected=g.committed+1;local ci=1
    while expected<=g.total do
        local ops,first,last,chunk
        while ci<=#g.chunks and g.chunks[ci]==false do ci=ci+1 end
        chunk=g.chunks[ci]
        while Table(chunk) and type(chunk.last)=='number' and chunk.last<expected do
            g.chunks[ci]=false;ci=ci+1;chunk=g.chunks[ci]
        end
        if chunk then
            if not Table(chunk) or not S.Integer(chunk.first,1,g.total) or not S.Integer(chunk.last,chunk.first,g.total)
                or type(chunk.text)~='string' then error('Invalid recovery chunk') end
            for k in pairs(chunk) do if k~='first' and k~='last' and k~='text' then error('Unsupported recovery chunk field') end end
            first,last=chunk.first,chunk.last;ops=ns.ChronicleBackup.DecodeChunk(chunk.text)
            if not ops or #ops~=last-first+1 then error('Recovery chunk failed to decode') end
        else ops=g.tail;first=g.total-#ops+1;last=g.total end
        if expected<first or expected>last+1 then error('Recovery operations are not contiguous') end
        while expected<=last do
            -- A tail may be sealed while checksums yield; ordinals remain stable.
            local op=ops[expected-first+1]
            Apply(j,op);g.bytes=math.max(0,g.bytes-S.Size(op));g.committed=expected;expected=expected+1
            J.diagnostics.committed=J.diagnostics.committed+1;coroutine.yield()
        end
        if chunk then g.chunks[ci]=false;ci=ci+1 else
            local remaining={};local tailFirst=g.total-#g.tail+1
            for n,op in ipairs(g.tail) do if tailFirst+n-1>g.committed then remaining[#remaining+1]=op end end
            g.tail=remaining
        end
    end
    Reserve(j.c,g)
    if g.currentSession then j.c.currentSession=Rewrite(j,g.currentSession,'session') end
    if writer and writer.g==g then
        writer.streaming=true;writer.character.events={}
        for guid,p in pairs(writer.character.profiles) do
            local saved=j.c.profiles[guid];if saved and saved.personal then p.personal=Copy(saved.personal) end
        end
    end
end
function J.Merge() if not J.error and not J.quitting then Wake() end end
function J.Pump()
    if J.quitting or J.error or S.loading or S.blocked or not S.db or not ns.DB or not ns.Modules.Enabled('history') or not ns.Membership.Allowed() then return end
    local root=Root();if not root then Fail('Unsupported recovery root; original evidence is retained.');return end
    local owner=C.Owner();if not owner then return end
    if ns.ChronicleStartupLegacy.error then Fail(ns.ChronicleStartupLegacy.error);return end
    if root.legacy~=nil then
        -- Validate an existing legacy root even when Has cannot enumerate it.
        ns.ChronicleStartupLegacy.Merge()
        if ns.ChronicleStartupLegacy.error then Fail(ns.ChronicleStartupLegacy.error);return end
        if ns.ChronicleStartupLegacy.Has(owner) or ns.ChronicleStartupLegacy.Busy() then return end
    end
    if not job then
        local e=root.characters[owner];if not e then frame:SetScript('OnUpdate',nil);return end
        if not Entry(root,owner) then Fail('Invalid recovery character; original evidence is retained.');return end
        local g=e.generations[1];if not g then frame:SetScript('OnUpdate',nil);return end
        if not ValidGeneration(g,owner) then Fail('Unsupported recovery generation; original evidence is retained.');return end
        local c=S.Character(owner,true);if not c then return end
        g.hashes=g.hashes or {}
        job=writer and writer.g==g and writer.mergeCache or nil
        job=job or {root=root,entry=e,g=g,owner=owner,db=S.db,c=c,ids={},objects={},hashes=g.hashes}
        local current=job;job.thread=coroutine.create(function() Run(current) end)
    end
    local j=job
    if root~=j.root or S.db~=j.db or S.Character(owner,false)~=j.c or j.entry.generations[1]~=j.g then J.Cancel();return end
    local start=ns.WardenPerformance.Begin()
    for _=1,64 do
        local ok,why=coroutine.resume(j.thread)
        if not ok then J.lastFailure=tostring(why);Fail('Recording recovery stopped after a validation/commit error. Original pending evidence is kept. /warden chronicle diagnostics shows the reason.');return end
        if coroutine.status(j.thread)=='dead' then
            if j.g.committed==j.g.total then
                j.g.chunks={};j.g.tail={};j.g.bytes=0;table.remove(j.entry.generations,1)
                if #j.entry.generations==0 then
                    J.lastHandoffAt=C.Stamp();J.lastHandoffOwner=owner
                    if not writer or writer.entry~=j.entry then root.characters[owner]=nil end
                end
            end
            if writer and writer.g==j.g then writer.mergeCache=j end
            job=nil;return
        end
        if ns.WardenPerformance.Expired(start) then break end
    end
end
function J.Status()
    local bytes=0;local db=OlympusWardenStartupDB
    for _,e in pairs(Table(db) and Table(db.characters) and db.characters or {}) do
        for _,g in ipairs(Table(e) and Table(e.generations) and e.generations or {}) do if Table(g) then bytes=bytes+(S.Number(g.bytes,0) or 0) end end
    end
    return {version=J.VERSION,writing=writer~=nil,recording=writer~=nil and C.InWorld()==true,pending=J.Count(),bytes=bytes,merging=J.Busy(),error=J.error,reason=J.lastFailure,lastRejected=J.lastRejected,
        accepted=J.diagnostics.accepted,committed=J.diagnostics.committed,lastHandoff=J.lastHandoffOwner==C.Owner() and J.lastHandoffAt or nil,merged=J.diagnostics.merged,reused=J.diagnostics.reused,rejected=J.diagnostics.rejected}
end

-- Aggregate only, computed on request; absence of a detected gap is not proof
-- that the native client supplied every possible observation.
function J.Health()
    local h=J.Status();local r=C.RuntimeStatus()
    h.capture=r.captureReady and (h.writing and 'Active; local staging' or 'Active; history') or 'Inactive'
    h.archive=S.loading and 'Validating' or S.blocked and 'Needs recovery' or r.queryReady and 'Ready' or 'Unavailable'
    h.integrity=h.error and 'Needs attention; pending originals kept' or h.pending>0 and 'Pending verification' or 'No detected recovery error'
    h.collectorErrors=C.diagnostics.errors;h.dropped=C.diagnostics.dropped;h.gaps=C.diagnostics.gaps
    return h
end
