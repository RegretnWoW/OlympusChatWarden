-- Small runtime context. Canonical facts are accepted before optional work.
local _,ns=...
local C,S,X=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture
local H={revision=0,diagnostics={contextErrors=0,linkErrors=0,accepted=0,staged=0,committed=0,denied=0}};ns.AthenaIntakeContext=H
local state={}
function H.Reset() state={} end
function H.State(owner,session)
    if state.owner~=owner or state.session~=session then state={owner=owner,session=session} end
    return state
end
function H.Module(e)
    local d=e.details or {};local r=d.recordType or ''
    if r=='historical_incident' or r=='incident_correction' then return d.ownerModule=='shield' and 'shield' or 'chat','PRIVATE_INCIDENT' end
    if r:find('guild_',1,true)==1 then return 'guild','LOCAL_HISTORY' end
    if e.kind=='player_observed' or e.kind=='important_player' or r=='contact_observed' or r=='contact_inspection_attempt'
        or ns.AthenaObservationSchema.types[r] and e.subject and e.subject~=select(2,C.Owner()) then return 'intel','LOCAL_INTEL' end
    if r=='aura_effect' or r=='aura_partial' or r:find('combat_',1,true)==1 or r:find('encounter_',1,true)==1
        or r:find('pvp_',1,true)==1 or r:find('damage_meter_',1,true)==1 or r=='own_spell_success_count' or r=='match_observed' then return 'combat','LOCAL_HISTORY' end
    return 'chronicle','LOCAL_HISTORY'
end
function H.Prepare(e,owner)
    if e.sourceContext~=nil or not C.Active() or C.Owner()~=owner then return end
    local st=H.State(owner,e.session);local module,scope=H.Module(e)
    local v={version=1,sourceModule=module,accessScope=scope,linkStatus='SOURCE_CONTEXT'}
    local map=S.Integer(X.Call('C_Map.GetBestMapForUnit','player'),1,10000000)
    if map then v.mapID=map end
    local _,_,difficulty=X.Call('GetInstanceInfo');v.difficultyID=S.Integer(difficulty,0,100000)
    for _,key in ipairs({'rosterRef','rosterObservedAt','rosterVerifiedAt','instanceRef','encounterRef','matchRef'}) do v[key]=st[key] end
    if ns.AthenaHistorySchema.InstanceContradiction(st.instanceLocation,e.location) then
        v.instanceRef=nil;v.encounterRef=nil;v.matchRef=nil
    end
    local d=e.details or {};if S.Text(d.matchRef,256) then v.matchRef=d.matchRef end
    return ns.AthenaHistorySchema.Context(v,owner)
end
function H.Attach(e,owner)
    local raw=e.sourceContext
    if not ns.Readable(raw) or raw~=nil then
        local clean=ns.AthenaHistorySchema.Context(raw,owner)
        if clean then e.sourceContext=clean;return end
        e.sourceContext=nil;H.diagnostics.contextErrors=H.diagnostics.contextErrors+1
    end
    local ok,v=pcall(H.Prepare,e,owner)
    if ok then e.sourceContext=v else H.diagnostics.contextErrors=H.diagnostics.contextErrors+1 end
end
function H.Accepted(e,status,live)
    H.revision=H.revision+1
    if status=='COMMITTED' then H.diagnostics.committed=H.diagnostics.committed+1;H.lastCommittedAt=e.at end
    if not live then return end
    H.diagnostics.accepted=H.diagnostics.accepted+1;H.lastAcceptedAt=e.at
    if status=='STAGED' then H.diagnostics.staged=H.diagnostics.staged+1 end
    local st=H.State(e.character,e.session);local d=e.details
    if e.kind=='group_roster' then st.rosterRef=e.id;st.rosterEvidence=e;st.rosterObservedAt=e.at;st.rosterVerifiedAt=nil
    elseif e.kind=='instance_enter' then st.instanceRef=e.id;st.instanceLocation=e.location;st.encounterRef=nil;st.encounterID=nil;st.matchRef=nil
    elseif e.kind=='instance_exit' then st.instanceRef=nil;st.instanceLocation=nil;st.encounterRef=nil;st.encounterID=nil;st.matchRef=nil
    elseif d.recordType=='encounter_started' then st.encounterRef=e.id;st.encounterID=d.encounterID
    elseif d.recordType=='encounter_ended' and st.encounterID==d.encounterID then st.encounterRef=nil;st.encounterID=nil
    elseif d.recordType=='match_observed' then st.matchRef=e.id
    elseif d.recordType=='pvp_match_complete' then st.matchRef=nil end
    if ns.AthenaHistorySchema.InstanceContradiction(st.instanceLocation,e.location) then
        st.instanceRef=nil;st.instanceLocation=nil;st.encounterRef=nil;st.encounterID=nil;st.matchRef=nil
    end
    if ns.AthenaFirstContact then
        local ok=pcall(ns.AthenaFirstContact.Accepted,e)
        if not ok then H.diagnostics.linkErrors=H.diagnostics.linkErrors+1 end
    end
end
function H.Deny(source,family,reason)
    H.diagnostics.denied=H.diagnostics.denied+1
    H.lastDenied={source=S.Text(source,96),family=S.Text(family,96),reason=reason,at=C.Stamp()}
    if reason=='CAPACITY_DEGRADED' and not H.capacityWarned then
        H.capacityWarned=true;ns.Print('New history could not be saved because the admission limit was reached. Existing history is kept. /warden chronicle diagnostics shows the current limit state.')
    end
    H.revision=H.revision+1
end
function H.Health()
    return {revision=H.revision,accepted=H.diagnostics.accepted,staged=H.diagnostics.staged,committed=H.diagnostics.committed,
        denied=H.diagnostics.denied,lastAcceptedAt=H.lastAcceptedAt,lastCommittedAt=H.lastCommittedAt,lastDenied=H.lastDenied,
        optionalContextErrors=H.diagnostics.contextErrors,optionalLinkErrors=H.diagnostics.linkErrors,
        admission=(S.admissionBlocked or S.admissionLimitBytes and H.lastDenied and H.lastDenied.reason=='CAPACITY_DEGRADED') and 'CAPACITY_BLOCKED' or 'NORMAL',diskSave='NOT_VERIFIED_BY_RUNNING_ADDON',
        retention='No automatic canonical expiry; explicit player deletion only'}
end
