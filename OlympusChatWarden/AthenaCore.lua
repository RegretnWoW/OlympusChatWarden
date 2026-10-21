-- Headless, local-only service. Legacy ledgers remain authoritative WardenDB
-- storage; this namespace contains only compact operational references.
local _,ns=...
local A={VERSION=1,POLICY=2,revision=0,errors=0,MAX_DECISIONS=1024,MAX_ACTIONS=256};ns.Athena=A
local scopes={chat={protection=true},shield={protection=true},intel={protection=true,history=true},
    chronicle={history=true},alerts={protection=true,history=true},command={health=true},relay={health=true}}
local runtime,root,index={},nil,{}
local checked=setmetatable({},{__mode='k'})
local function Enabled(module)
    return scopes[module] and (module=='command' or module=='relay' or not ns.Modules or ns.Modules.Enabled(module))
end
local function Allowed(module) return Enabled(module) and ns.DB and (not ns.Membership or ns.Membership.Allowed()) end
local function Text(v,n) return ns.CanRead(v) and #v<=(n or 256) and v or nil end
local function GUID(v) return Text(v,128) and v:match('^Player%-%w[%w%-]*$') and v end
local function Now() return ns.SafeNumber(ns.SafeCall(GetServerTime)) or ns.SafeNumber(ns.SafeCall(time)) or 0 end
local function Copy(v,depth)
    if not ns.Readable(v) then return nil end
    if type(v)~='table' then return v end
    if (depth or 0)>8 or getmetatable(v) then return nil end
    local out={};for k,x in pairs(v) do if ns.Readable(k) and (type(k)=='string' or type(k)=='number') then out[k]=Copy(x,(depth or 0)+1) end end;return out
end
A.Copy=Copy;A.GUID=GUID;A.Enabled=Enabled
function A.Try(fn,...)
    local ok,a,b=pcall(fn,...)
    if not ok then A.errors=A.errors+1;return nil,'SERVICE_ERROR' end
    return a,b
end
local function Empty() return {version=1,sequence=0,decisions={},actions={},corrections={},expired=0} end
local function MemoryRoot(create)
    if not ns.DB then return end
    if ns.DB.athena==nil and create then ns.DB.athena={version=1,operational=Empty()} end
    if type(ns.DB.athena)~='table' or ns.DB.athena.version~=1 then return nil,'unsupported Athena data retained' end
    return ns.DB.athena
end
local function ValidStore(s)
    if checked[s] then return true end
    if not ns.Readable(s) or type(s)~='table' or s.version~=1 or getmetatable(s)
        or type(s.decisions)~='table' or #s.decisions>A.MAX_DECISIONS
        or type(s.actions)~='table' or #s.actions>A.MAX_ACTIONS or type(s.corrections)~='table'
        or not ns.SafeNumber(s.sequence) or s.sequence<0 then return false end
    for _,r in ipairs(s.decisions) do
        if type(r)~='table' or not Text(r.id,240) or not Text(r.sourceID,240) or not GUID(r.subject)
            or not ns.SafeNumber(r.at) or not Text(r.session,240) or r.originKind~='source' then return false end
    end
    for _,r in ipairs(s.actions) do if type(r)~='table' or not Text(r.id,240) or not ns.SafeNumber(r.at)
        or r.originKind~='action' or not Text(r.action,64) then return false end end
    checked[s]=true;return true
end
local function Store()
    if not ns.DB then return end
    -- A separate privacy choice, shared with the existing operational history.
    if ns.DB.history==false or ns.DB.persistHistory==false then
        runtime.operational=runtime.operational or Empty();return runtime.operational
    end
    root=MemoryRoot(true);if not root then return nil,'unsupported Athena data retained' end
    if not ValidStore(root.operational) then return nil,'unsupported operational data retained' end
    return root.operational
end
local function Identity()
    local guid=GUID(ns.SafeCall(UnitGUID,'player'));local realm=Text(ns.SafeCall(GetRealmName),128)
    return guid and realm and realm..'/'..guid,guid
end
local function Sequence(s,module)
    if not s.origin then
        local seed=(Identity and Identity() or GUID(ns.SafeCall(UnitGUID,'player')) or '')..':'..Now()..':'..tostring(ns.SafeCall(GetTime))..':'..math.random(1,2147483000)..':'..tostring({})
        s.origin=ns.PackCrypto.Hex(ns.PackCrypto.SHA256(seed)):sub(1,24)
    end
    s.sequence=(ns.SafeNumber(s.sequence) or 0)+1
    -- Older builds used raw digest bytes in the origin. Keep every old ID and
    -- saved origin intact; only newly issued IDs use a printable representation.
    local origin=s.origin
    if origin:find('[^a-f0-9]') then origin=ns.PackCrypto.Hex(origin) end
    return 'athena:'..origin..':'..module..':'..s.sequence
end
function A.OperationalRef(id)
    if not ns.CanRead(id) or #id>240 or id:sub(1,7)~='athena:' or not id:match(':%a+:%d+$') then return end
    return 'operational:hex:'..ns.PackCrypto.Hex(id)
end
function A.OperationalSource(ref)
    ref=ns.ChronicleStore.Text(ref,512);if not ref then return end
    local hex=ref:match('^operational:hex:([a-f0-9]+)$')
    local id=hex and #hex%2==0 and ns.PackCrypto.Unhex(hex) or ref:match('^operational:(athena:.+)$')
    if id and A.OperationalRef(id) then return id end
end
local function Session()
    local owner=Identity();return (owner or 'unresolved')..':'..tostring(ns.DB.historySequence or 0)
end
local function Notify(kind,row,live)
    A.revision=A.revision+1
    if live and ns.AthenaIncidents and (kind=='decision' or kind=='action' or kind=='correction') then
        local ok=pcall(ns.AthenaIncidents.Notify,kind,row)
        if not ok then A.errors=A.errors+1 end
    end
    if A.queryVersions and A.queryVersions[row.subject] then A.queryVersions[row.subject]=A.queryVersions[row.subject]+1 end
    if ns.AthenaLab and ns.AthenaLab.Trace then local ok=pcall(ns.AthenaLab.Trace,kind,row);if not ok then
        A.errors=A.errors+1;pcall(ns.AthenaLab.Stop,'INCOMPLETE_PRODUCTION_TRACE_ERROR')
    end end
    if live and ns.SignalCore then ns.SignalCore.Publish('athena.'..kind,{version=1,id=row.id,subject=row.subject,at=row.at,originKind=row.originKind,live=true}) end
end
function A.ResolvePlayer(query)
    if type(query)=='table' and GUID(query.guid) then return {id=query.guid,certainty='verified-guid'} end
    if GUID(query) then return {id=query,certainty='verified-guid'} end
    return nil,'unresolved identity; names are not GUID proof'
end
function A.Subscribe(consumer,kinds,handler)
    if not scopes[consumer] or type(handler)~='function' or type(kinds)~='table' then return false end
    local owner=consumer=='command' and 'core' or consumer
    for _,kind in ipairs(kinds) do
        if not ({evidence=true,decision=true,correction=true,action=true,assessment=true})[kind] then return false end
        ns.SignalCore.Subscribe('athena.'..kind,owner,'athena:'..consumer,function(v)
            if Enabled(consumer) then handler(Copy(v)) end
        end)
    end
    return true
end
function A.Observe(module,observation)
    if not Allowed(module) then return nil,'MODULE_DISABLED' end
    if type(observation)~='table' or not ns.Readable(observation) then return nil,'UNREADABLE' end
    if module~='chat' or observation.kind~='chat_decision' then return nil,'UNSUPPORTED_TYPED_SOURCE' end
    local s,why=Store();if not s then return nil,why end
    local sourceID=Text(observation.sourceID,240);local subject=GUID(observation.subject)
    if not sourceID then return nil,'SOURCE_ID_REQUIRED' end
    -- No guessed name reconciliation and no permanent ambiguous player counts.
    if not subject then runtime.unresolved=(runtime.unresolved or 0)+1;return nil,'UNRESOLVED_IDENTITY' end
    if not ({Hidden=true,Redacted=true,Warning=true,Replaced=true})[observation.action] then return nil,'UNSUPPORTED_ACTION' end
    for _,r in ipairs(s.decisions) do if r.sourceID==sourceID then return r.id,'DUPLICATE' end end
    local id=Sequence(s,module);if not id then return nil,'OBSERVER_UNRESOLVED' end
    local r={id=id,sourceID=sourceID,subject=subject,observer=select(2,Identity()),at=ns.SafeNumber(observation.at) or Now(),
        session=Session(),source=Text(observation.source,64),action=observation.action,spam=observation.spam==true,
        originKind='source',schema=1,share='local-only'}
    if #s.decisions>=A.MAX_DECISIONS then local old=table.remove(s.decisions,1);s.corrections[old.id]=nil;s.expired=(s.expired or 0)+1 end
    s.decisions[#s.decisions+1]=r;Notify('decision',r,true);return id,'COMMITTED'
end
function A.RecordCorrection(module,id,correction)
    if module~='chat' or not Allowed(module) or type(correction)~='table' or correction.kind~='false_positive' then return nil,'DENIED' end
    local s=Store();if not s then return nil,'UNAVAILABLE' end
    for _,r in ipairs(s.decisions) do if r.id==id then
        if s.corrections[id] then return id,'DUPLICATE' end
        local fix={id=Sequence(s,'correction'),targetID=id,subject=r.subject,at=Now(),kind='false_positive',originKind='correction',policyVersion=A.POLICY}
        s.corrections[id]=fix;Notify('correction',fix,true);return fix.id,'COMMITTED'
    end end
    if ns.AthenaIncidents and ns.AthenaIncidents.Selected() then return ns.AthenaIncidents.CorrectHistorical(id) end
    return nil,'Original decision outside retained auditable window'
end
function A.GetPlayerContext(consumer,guid,scope)
    if not Enabled(consumer) or not GUID(guid) or not scopes[consumer][scope or 'protection'] then return nil,'DENIED' end
    local s,why=Store();if not s then return nil,why or 'UNAVAILABLE' end
    local out={subject=guid,filtered=0,eligible=0,spam=0,sessions=0,corrected=0,sourceIDs={},
        horizon='retained operational window (up to 1024 source decisions); not lifetime totals',policyVersion=A.POLICY}
    local sessions={}
    for _,r in ipairs(s and s.decisions or {}) do if r.subject==guid then
        out.filtered=out.filtered+1;out.lastFilteredAt=math.max(out.lastFilteredAt or 0,r.at)
        if s.corrections[r.id] then out.corrected=out.corrected+1 else
            out.eligible=out.eligible+1;if r.spam then out.spam=out.spam+1 end
            out.sourceIDs[#out.sourceIDs+1]=r.id;sessions[r.session]=true
        end
    end end
    for _ in pairs(sessions) do out.sessions=out.sessions+1 end
    out.fingerprint=out.eligible..':'..out.spam..':'..(out.sourceIDs[#out.sourceIDs] or '')
    out.advisory=out.spam>=3 and 'Repeated local spam-filter decisions' or nil
    if s and s.dismissed and s.dismissed[guid]==out.fingerprint then out.advisory=nil;out.dismissed=true end
    out.advisoryExplanation='A local filter decision is not proof of malice. Corrected decisions are excluded.'
    out.actions={};for _,r in ipairs(s and s.actions or {}) do if r.subject==guid then
        out.actions[#out.actions+1]=Copy(r);if r.owner=='shield' then out.lastProtectionAt=math.max(out.lastProtectionAt or 0,r.at) end
    end end
    return out
end
function A.RecordAction(module,action,causeIDs)
    if not Allowed(module) or not ({shield=true,alerts=true,relay=true,command=true})[module] or type(action)~='table' then return nil,'DENIED' end
    local s=Store();if not s then return nil,'UNAVAILABLE' end
    local guid=GUID(action.subject);local key=Text(action.nameKey,180)
    if not guid and not key and module~='relay' and module~='command' then return nil,'UNRESOLVED_IDENTITY' end
    local causes={};if causeIDs then
        if type(causeIDs)~='table' or #causeIDs>64 then return nil,'INVALID_CAUSES' end
        for _,id in ipairs(causeIDs) do
            local found=false;for _,r in ipairs(s.decisions) do if r.id==id and r.subject==guid and not s.corrections[id] then found=true;break end end
            if not found then return nil,'CAUSE_NOT_ELIGIBLE_SOURCE' end;causes[#causes+1]=id
        end
    end
    local row={id=Sequence(s,module),originKind='action',subject=guid,nameKey=not guid and key or nil,
        at=Now(),action=Text(action.kind,64),causeIDs=causes,sourceEvidenceID=Text(action.sourceEvidenceID,512),owner=module,share='local-only'}
    if not row.id or not row.action then return nil,'INVALID_ACTION' end
    if #s.actions>=A.MAX_ACTIONS then table.remove(s.actions,1) end
    s.actions[#s.actions+1]=row;Notify('action',row,true);return row.id,'COMMITTED'
end
function A.RecordAssessment(module,finding,dependencies)
    if module~='intel' or not Allowed(module) or type(finding)~='table' or not GUID(finding.subject) then return nil,'DENIED' end
    -- Derived on demand; no new evidence and no independent Shield trigger.
    local c=A.GetPlayerContext('intel',finding.subject,'protection')
    return c and {subject=finding.subject,label=c.advisory,dependencies=c.sourceIDs,originKind='assessment',policyVersion=A.POLICY,retracted=not c.advisory}
end
function A.ChatDecision(entry)
    if not entry or entry.kind~='player' or entry.displayOnly or entry.shieldReason or entry.confidence=='Contact shield' then return end
    local id=A.Observe('chat',{kind='chat_decision',sourceID=entry.captureID,subject=entry.guid,at=entry.timestamp,source=entry.event,
        action=entry.action,spam=entry.spamReason~=nil})
    if id then entry.athenaDecisionID=id end
    if id and entry.sender then A.BindContact(entry.guid,entry.sender) end
end
function A.CorrectReview(entry,label)
    if entry and entry.athenaDecisionID and label=='False positive' then
        return A.RecordCorrection('chat',entry.athenaDecisionID,{kind='false_positive'})
    end
end
local contactProof={};local contactCount=0
function A.BindContact(guid,name)
    local key=ns.Shield and ns.Shield.Key(name)
    if not GUID(guid) or not key then return end
    if not contactProof[key] and contactCount>=256 then contactProof={};contactCount=0 end
    if not contactProof[key] then contactCount=contactCount+1 end
    contactProof[key]={guid=guid,at=Now()}
end
function A.ResolveContact(name)
    local key=ns.Shield and ns.Shield.Key(name);local proof=key and contactProof[key]
    if proof and Now()>=proof.at and Now()-proof.at<=300 then return proof.guid end
    return nil,'Name-scoped contact; no fresh verified GUID association'
end
function A.DismissAdvisory(consumer,guid)
    if consumer~='intel' or not Allowed(consumer) or not GUID(guid) then return false end
    local context=A.GetPlayerContext('intel',guid,'protection');local s=Store()
    if not s or not context or not context.advisory then return false end
    s.dismissed=s.dismissed or {};s.dismissed[guid]=context.fingerprint
    A.revision=A.revision+1;return true
end
function A.Notice(e,status,live,generation)
    -- Called only after the existing authoritative writer accepts a native event.
    -- Journal recovery does not replay business actions.
    if not e then return end
    if ns.AthenaIntakeContext then
        local ok=pcall(ns.AthenaIntakeContext.Accepted,e,status,live)
        if not ok then ns.AthenaIntakeContext.diagnostics.linkErrors=ns.AthenaIntakeContext.diagnostics.linkErrors+1 end
    end
    if A.queryVersions then
        local d=e.details or {};local values=e.capture and e.capture.values or {}
        for guid in pairs(A.queryVersions) do
            local relevant=e.subject==guid or d.attackerGUID==guid or d.targetGUID==guid or d.opponentGUID==guid or values.guid==guid
            if e.kind=='group_roster' then for _,member in ipairs(d.members) do if member==guid then relevant=true;break end end end
            if relevant then A.queryVersions[guid]=A.queryVersions[guid]+1 end
        end
    end
    local row={id=e.id,subject=e.subject,at=e.at,originKind='source',status=status,source=e.source,owner=e.character}
    Notify('evidence',row,false)
    if live and A.NativeNotice then A.NativeNotice(e,status,generation) end
    if e.kind=='group_roster' and ns.AthenaLab and ns.AthenaLab.Current() then
        for _,guid in ipairs(e.details.members) do row.subject=guid;Notify('evidence',row,false) end
    end
end
function A.ObservationID(e)
    local s=MemoryRoot(true);if not s then return nil,'Origin unavailable' end
    s.sequence=s.sequence or 0
    if not s.origin then Sequence(s,'origin') end
    return 'ow1:'..s.origin..':'..e.id
end
local trustedSources=setmetatable({},{__mode='v'})
function A.RememberRelationship(owner,guid,state,provisional)
    local earned=state.earnedTier==1
    owner=earned and state.promotionOwner or state.manualOwner or owner
    local c=ns.ChronicleStore.Character(owner,false)
    local j=ns.ChronicleStartupJournal
    if not earned and not state.manualPriority and not state.captureHint then return end
    if not provisional and (not c or ns.ChronicleStore.loading or j and (j.Busy() or j.Count()>0)) then return end
    local root=MemoryRoot(true)
    if not root or root.version~=1 then return end
    root.relationships=root.relationships or {}
    root.relationships[guid]={version=1,policy=A.POLICY,earnedTier=state.earnedTier,manualPriority=state.manualPriority==true,manualCause=state.manualCause,owner=owner,
        sourceID=not provisional and (earned and state.promotionID or state.manualID) or nil,
        at=earned and state.promotionAt or state.manualAt,sequence=c and c.sequence,updated=c and c.updated,
        sessionSequence=c and c.sessionSequence,provisional=provisional==true,captureHint=state.captureHint==true,shared=state.shared==true,
        meaning='Capture priority hint only; never source evidence, statistics or a protective action'}
    if not provisional then trustedSources[owner]=c end
end
local function CachedRole(guid)
    local root=ns.DB and ns.DB.athena;local r=type(root)=='table' and root.version==1 and type(root.relationships)=='table' and root.relationships[guid]
    local saved=ns.DB and ns.DB.chronicle
    if ns.ChronicleStore.blocked or type(r)~='table' or r.version~=1 or (r.policy~=A.POLICY and not (r.policy==1 and r.earnedTier==1 and not r.provisional)) or not Text(r.owner,240) then return end
    local c=type(saved)=='table' and type(saved.characters)=='table' and saved.characters[r.owner]
    if type(c)~='table' then return end
    if r.provisional then
        local journal=OlympusWardenStartupDB
        if type(journal)=='table' and journal.version==2 and type(journal.characters)=='table' and journal.characters[r.owner] then return r end
        if c.sequence==r.sequence and c.updated==r.updated and c.sessionSequence==r.sessionSequence then return r end
    elseif Text(r.sourceID,512) and r.sourceID:sub(1,#r.owner+1)==r.owner..':' then
        local sequence=tonumber(r.sourceID:sub(#r.owner+2))
        -- Canonical histories are append-only; text restore rejects conflicting
        -- IDs and merges rather than replaces. Explicit Clear also clears this
        -- derived cache. A lower sequence cannot substantiate the prior index.
        if sequence and ns.SafeNumber(c.sequence) and c.sequence>=sequence then return r end
    end
end
function A.EarnedTier(guid)
    local r=CachedRole(guid);return r and not r.provisional and r.earnedTier==1 and 1 or nil
end
function A.CachedCaptureTier(guid)
    local r=CachedRole(guid);return r and (r.earnedTier==1 or r.manualPriority or r.captureHint) and 1 or nil
end
function A.ReconcilePriorityOwner(owner,states)
    local root=ns.DB and ns.DB.athena
    if type(root)~='table' or root.version~=1 or type(root.relationships)~='table' then return end
    for guid,row in pairs(root.relationships) do
        if row.provisional and row.owner==owner and (not states[guid] or states[guid].tier~=1) then root.relationships[guid]=nil end
    end
end
function A.CheckpointPriorityMetadata()
    local root=ns.DB and ns.DB.athena
    for _,r in pairs(type(root)=='table' and root.version==1 and type(root.relationships)=='table' and root.relationships or {}) do
        local c=ns.ChronicleStore.Character(r.owner,false)
        if not r.provisional and c and trustedSources[r.owner]==c then r.sequence=c.sequence;r.updated=c.updated;r.sessionSequence=c.sessionSequence end
    end
end
function A.GetHealth(consumer)
    if consumer~='command' and consumer~='relay' then return nil,'DENIED' end
    local s,why=Store();return {version=1,revision=A.revision,errors=A.errors,operationalAvailable=s~=nil,operationalError=why,
        operationalDecisions=s and #s.decisions,operationalActions=s and #s.actions,expiredOperationalReferences=s and s.expired,
        unresolvedSessionCount=runtime.unresolved or 0,history='legacy canonical ledger; unified startup journal',network='absent'}
end
function A.ExportEligible(consumer,request)
    -- Explicit future boundary. No source or private record is shareable today.
    if type(request)~='table' or request.version~=1 then return nil,'UNSUPPORTED_SCHEMA' end
    return {version=1,records={},reason='No external intelligence sharing is enabled'}
end
function A.Import() return nil,'SYNC_DISABLED; no peer evidence ingestion is enabled' end
ns.WardenDB={version=1,ResolvePlayer=A.ResolvePlayer,GetHealth=A.GetHealth}
