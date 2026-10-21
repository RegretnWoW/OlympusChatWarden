-- Prospective, bounded intake aggregates. Accepted historical rows are immutable.
-- The existing main SavedVariables retains only uncommitted qualified batches.
local _,ns=...
local C,S,X=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture
local G={VERSION=1,LIMIT=256,WINDOW=15,diagnostics={buffered=0,committed=0,failed=0,reused=0,degraded=0}};ns.AthenaCastCounts=G
local owner,epoch,contextSerial,contextKind,encounterID,combat,match=nil,nil,0,'unknown',nil,false,false
local ready,recoveryQueued,busy,recoveryConflict=false,false,false,false
local retry=setmetatable({},{__mode='k'})
local function Note(why)
    if G.lastReason==why then return end
    G.lastReason=why;G.diagnostics.failed=G.diagnostics.failed+1
    X.Mark('Cast counts',why)
    if ns.ChronicleCoverage then ns.ChronicleCoverage.Note('Cast counts','partial',why) end
end
local function Root(create)
    local db=ns.DB;if not db then return end
    local r=db.castPending
    if r==nil and create then r={version=1,nextEpoch=0,nextID=0,rows={}};db.castPending=r end
    if not ns.Readable(r) or type(r)~='table' or getmetatable(r) or r.version~=1
        or not S.Integer(r.nextEpoch,0,999999999) or not S.Integer(r.nextID,0,999999999)
        or not S.Array(r.rows,G.LIMIT) then if r~=nil then Note('Unsupported pending cast archive kept; batching unavailable') end;return end
    for key in pairs(r) do if not ({version=true,nextEpoch=true,nextID=true,rows=true})[key] then Note('Unknown pending cast metadata kept');return end end
    return r
end
local function ValidRow(row)
    return ns.Readable(row) and type(row)=='table' and not getmetatable(row) and S.Text(row.owner,240)
        and S.GUID(row.subject) and S.Text(row.key,1024) and S.Text(row.epoch,256) and type(row.details)=='table'
        and ((ns.AthenaObservationSchema.Valid(row.details) and row.details.recordType=='cast_observation_count'
        and ns.AthenaObservationSchema.Record({source=row.source,subject=row.subject,details=row.details},row.owner))
        or (row.details.recordType=='own_spell_success_count' and row.subject==row.owner:match('/(Player%-.+)$')
        and S.Text(row.details.sourceOccurrenceKey,256) and S.Number(row.details.firstElapsed,0)
        and X.ValidActivity(row.details)))
        and type(row.location)=='table'
end
-- Existing personal success batching keeps its record shape and writer. If
-- that writer is denied, transfer the qualified batch to this durable outbox.
function G.HoldOwn(details,source,location)
    local r=Root(true)
    if not r or not epoch or #r.rows>=G.LIMIT or r.nextID>=999999999 then Note('Own cast pending capacity unavailable; coverage incomplete');return false end
    local d={};for key,value in pairs(details) do d[key]=value end
    d.sourceOccurrenceKey=epoch..'/own/'..(r.nextID+1);d.firstElapsed=C.Tick()
    local row={owner=C.Owner(),subject=select(2,C.Owner()),source=source,key=d.sourceOccurrenceKey,epoch=epoch,location=location or {},details=d}
    if not ValidRow(row) then Note('Own pending batch could not be validated; coverage incomplete');return false end
    r.rows[#r.rows+1]=row;r.nextID=r.nextID+1;return true
end
-- Pure reducer: the Lab supplies its own row array and explicit source context.
-- No native getters, current settings, canonical writer or test authorization.
function G.Reduce(rows,input)
    if not S.Array(rows,G.LIMIT) or type(input)~='table' or not S.Text(input.key,1024)
        or not S.Number(input.at,1) or not S.Number(input.elapsed,0) then return nil,'INVALID_INPUT' end
    local row
    for _,candidate in ipairs(rows) do if not ValidRow(candidate) then return nil,'INVALID_PENDING_ROW' end;if candidate.key==input.key then row=candidate;break end end
    if row then
        if row.owner~=input.owner or row.subject~=input.subject or row.source~=input.source or row.epoch~=input.epoch
            or row.details.spellID~=input.spellID or row.details.phase~=input.phase then return nil,'IDENTITY_MISMATCH' end
        if input.at<row.details.lastAt or input.elapsed<row.details.lastElapsed then return nil,'CLOCK_OR_SCHEMA_BOUNDARY' end
        if row.details.count>=128 then return nil,'WINDOW_FULL' end
        row.details.count=row.details.count+1;row.details.lastAt=input.at;row.details.lastElapsed=input.elapsed
        row.details.unknownCount=row.details.unknownCount+(input.unknown and 1 or 0)
        if row.details.unknownCount>0 then row.details.evidenceState='PROVISIONAL_OBSERVATION';row.details.interpretationStatus='UNRESOLVED_INTERPRETATION' end
    else
        if #rows>=G.LIMIT then return nil,'BUFFER_FULL' end
        row={owner=input.owner,subject=input.subject,source=input.source,key=input.key,epoch=input.epoch,location=input.location or {},details=input.details}
        if not ValidRow(row) then return nil,'INVALID_AGGREGATE' end
        rows[#rows+1]=row
    end
    return row
end
function G.Details(input)
    local partial=input.unknown==true
    return {recordType='cast_observation_count',aggregationVersion=1,count=1,unknownCount=partial and 1 or 0,
        spellID=input.spellID,phase=input.phase,firstAt=input.at,lastAt=input.at,firstElapsed=input.elapsed,lastElapsed=input.elapsed,
        contextRef=input.contextRef,contextKind=input.contextKind or 'unknown',encounterID=input.encounterID,
        windowRef=input.windowRef,observerSession=input.session,runID=input.epoch,sourceOccurrenceKey=input.id,
        evidenceState=partial and 'PROVISIONAL_OBSERVATION' or 'VERIFIED_FACT',interpretationVersion=1,sourceVersion=1,
        subjectEligibility=input.eligibility,fieldReadability='Native notification count; missing cast identities are not deduplicated',
        interpretationStatus=partial and 'UNRESOLVED_INTERPRETATION' or 'RAW_OBSERVED',attribution='STATE_ON_SUBJECT',
        scope='Observed phase notifications in this source window; not a rotation, hit or complete cast census',
        sourceEvidenceSummary='Native phase notifications; selected ability evidence has a separate semantic scope',
        coverage='Dated observed source; unobserved intervals unknown'}
end
local function Write(row)
    if not ValidRow(row) then Note('Invalid pending cast row preserved without replacement');return end
    local d={};for key,value in pairs(row.details) do d[key]=value end
    d.evidenceClass,d.outcome,d.outcomeScope=X.Classify('native_event',row.source,d)
    -- The source epoch/context and original first/last times are immutable.
    -- A later flush must not inherit the current boss/roster as its evidence.
    local context={version=1,sourceModule='intel',accessScope='LOCAL_INTEL',linkStatus='LINK_PENDING'}
    if row.subject==row.owner:match('/(Player%-.+)$') then context.sourceModule='chronicle';context.accessScope='LOCAL_HISTORY' end
    return C.Record('native_event',row.source,d,row.subject,'observed',row.location,nil,nil,nil,nil,context)
end
function G.Flush(guid,all,limit)
    if busy or not X.Ready() then return false end
    local r=Root();if not r then return true end
    busy=true;local used=0;local now=C.Tick() or 0;local ok=true
    for n=#r.rows,1,-1 do local row=r.rows[n]
        if not ValidRow(row) then Note('Invalid pending cast evidence retained');ok=false;break end
        if row.owner==C.Owner() and (row.epoch==epoch or ready) and (not guid or row.subject==guid)
            and (all or not retry[row] or now>=retry[row])
            and (all or row.epoch~=epoch or now-row.details.firstElapsed>=G.WINDOW or row.details.count>=128) then
            if not ValidRow(row) then Note('Invalid pending cast evidence retained');ok=false
            else
                local saved=Write(row)
                if saved then table.remove(r.rows,n);retry[row]=nil;G.diagnostics.committed=G.diagnostics.committed+1
                else retry[row]=now+5;Note('Cast aggregate commit denied; qualified pending counts retained for retry');ok=false end
            end
            used=used+1;if used>=(limit or G.LIMIT) then break end
        end
    end
    busy=false;return ok
end
function G.Admit(unit,guid,data,eligibility)
    if not epoch or owner~=C.Owner() or not data.spellID then return false,'NO_BATCH_CONTEXT' end
    local r=Root(true);if not r then return false,'PENDING_ARCHIVE_UNAVAILABLE' end
    if r.nextID>=999999999 then Note('Cast identifier capacity reached; pending evidence kept');return false,'IDENTIFIER_CAPACITY' end
    local at,elapsed=C.Stamp(),C.Tick();if not at or not elapsed then return false,'CLOCK_UNAVAILABLE' end
    local context=epoch..'/context/'..contextSerial;local window=math.floor(elapsed/G.WINDOW)
    local key=table.concat({epoch,guid,data.spellID,data.phase,context,window},'/')
    G.Flush(nil,false,8)
    local character=S.WriterCharacter(owner,false)
    local input={owner=owner,subject=guid,source=({start='UNIT_SPELLCAST_START',stop='UNIT_SPELLCAST_STOP',
        ['success notification']='UNIT_SPELLCAST_SUCCEEDED'})[data.phase],key=key,epoch=epoch,
        at=at,elapsed=elapsed,spellID=data.spellID,phase=data.phase,unknown=data.castGUID==nil,eligibility=eligibility,
        contextRef=context,contextKind=contextKind,encounterID=encounterID,windowRef=context..'/window/'..window,
        session=character and character.currentSession,location=C.Place(),id=epoch..'/batch/'..(r.nextID+1)}
    input.details=G.Details(input)
    local row,why=G.Reduce(r.rows,input)
    if not row and (why=='BUFFER_FULL' or why=='WINDOW_FULL' or why=='CLOCK_OR_SCHEMA_BOUNDARY') then
        G.Flush(guid,true);row,why=G.Reduce(r.rows,input)
    end
    if not row then G.diagnostics.degraded=G.diagnostics.degraded+1;Note('Cast batching unavailable: '..tostring(why)..'; individual source fallback attempted');return false,why end
    r.nextID=r.nextID+1;G.diagnostics.buffered=G.diagnostics.buffered+1;return true
end
function G.Pump()
    if not owner or owner~=C.Owner() or not X.Ready() then return end
    local r=Root();if not r then return end
    if not ready and not recoveryQueued and not recoveryConflict and not S.loading and not S.blocked then
        local J=ns.ChronicleStartupJournal
        if J and (J.Busy() or J.Count()>0) then return end
        local pending={};for _,row in ipairs(r.rows) do
            if not ValidRow(row) then Note('Unrecognized pending cast row preserved');return end
            if row.owner==owner and row.epoch~=epoch then
            pending[row.details.sourceOccurrenceKey]=row
        end end
        if not next(pending) then ready=true else
            if X.Pending()>=200 then Note('Cast recovery deferred behind full detail queue; pending kept');return end
            recoveryQueued=true;local currentOwner=owner
            X.Queue('cast-count-recovery',function()
                local c=S.Character(currentOwner,false);if not c then recoveryQueued=false;return end
                local found={}
                for n,e in ipairs(c.events) do
                    local row=pending[e.details.sourceOccurrenceKey]
                    if row and (e.details.recordType=='cast_observation_count' or e.details.recordType=='own_spell_success_count') then
                        for key,value in pairs(row.details) do if e.details[key]~=value then Note('Pending cast identity conflicts with accepted evidence; both preserved');recoveryConflict=true;recoveryQueued=false;return end end
                        found[row]=true
                    end
                    if n%128==0 then X.Yield();if owner~=currentOwner or S.Character(currentOwner,false)~=c then recoveryQueued=false;return end end
                end
                for n=#r.rows,1,-1 do if found[r.rows[n]] then table.remove(r.rows,n);G.diagnostics.reused=G.diagnostics.reused+1 end end
                ready=true;recoveryQueued=false
            end,true)
        end
    end
    G.Flush(nil,false,8)
end
function G.Start()
    owner=C.Owner();contextSerial=0;contextKind='unknown';encounterID=nil;combat=false;match=false;ready=false;recoveryQueued=false;recoveryConflict=false
    local r=Root(true);if not r then epoch=nil;return end
    if r.nextEpoch>=999999999 then epoch=nil;Note('Cast source-epoch capacity reached; pending evidence kept');return end
    r.nextEpoch=r.nextEpoch+1;epoch=owner..'/cast-epoch/'..r.nextEpoch
end
function G.Stop() G.Flush(nil,true);owner=nil;epoch=nil;recoveryQueued=false end
function G.Clear() if ns.DB then ns.DB.castPending=nil end;owner=nil;epoch=nil;retry=setmetatable({},{__mode='k'}) end
function G.Revoke(guid) G.Flush(guid,true) end
function G.Count() local r=Root();return r and #r.rows or 0 end
function G.BackupReady()
    local r=Root();return r and #r.rows==0 or ns.DB and ns.DB.castPending==nil
end
function G.Handle(event,a)
    G.Flush(nil,true);contextSerial=contextSerial+1
    if event=='ENCOUNTER_START' then encounterID=S.Integer(a,1,10000000)
    elseif event=='ENCOUNTER_END' then encounterID=nil
    elseif event=='PLAYER_REGEN_DISABLED' then combat=true
    elseif event=='PLAYER_REGEN_ENABLED' then combat=false
    elseif event=='PVP_MATCH_ACTIVE' then match=true
    elseif event=='PVP_MATCH_COMPLETE' or event=='PLAYER_LEAVING_WORLD' then match=false end
    contextKind=encounterID and 'native encounter interval' or combat and 'observed combat window' or match and 'observed match interval' or 'unknown'
end
X.Register(G,{'ENCOUNTER_START','ENCOUNTER_END','PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED','PVP_MATCH_ACTIVE','PVP_MATCH_COMPLETE',
    'DUEL_COUNTDOWN','DUEL_FINISHED','GROUP_LEFT','PLAYER_LEAVING_WORLD','PLAYER_LOGOUT'})
