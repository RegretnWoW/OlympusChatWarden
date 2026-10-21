-- Explicitly opted-in minimal history, separate from bounded operational detail.
-- No message bodies, quotes, names, allegations or automatic protective actions.
local _,ns=...
local A,C,S,X=ns.Athena,ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture
local I={LIMIT=256,diagnostics={saved=0,coalesced=0,denied=0,corrected=0}};ns.AthenaIncidents=I
local buckets,order,corrections,correctionOrder,owner={}, {},{}, {},nil
local projections,projectionOrder={},{}
function I.ClearQueries() projections={};projectionOrder={} end
function I.ResetRuntime() I.ClearQueries();buckets={};order={};corrections={};correctionOrder={};owner=nil end
function I.Selected() return ns.DB and ns.DB.historicalIncidentConsent==1 end
function I.SetEnabled(value)
    if type(value)~='boolean' or not ns.DB or value and not ns.Membership.Allowed() then return false end
    ns.DB.historicalIncidentConsent=value and 1 or nil
    buckets={};order={};return true
end
local function AllowedCapture()
    return I.Selected() and ns.DB.history~=false and ns.DB.persistHistory~=false and C.Active() and C.PersonalEnabled()
end
local function ResetOwner()
    if owner~=C.Owner() then owner=C.Owner();buckets={};order={};corrections={};correctionOrder={} end
end
local function Bucket(key)
    local b=buckets[key];if b then return b end
    if #order>=I.LIMIT then buckets[table.remove(order,1)]=nil end
    b={causes={}};buckets[key]=b;order[#order+1]=key;return b
end
local function Correction(sourceID,actionID)
    if not I.Selected() or not ns.Modules.Enabled('chat') or not ns.Membership.LocalHistoryAllowed() then return nil,'DENIED' end
    sourceID=A.OperationalSource(sourceID) or sourceID
    if not ns.CanRead(sourceID) or not sourceID:match('^athena:.+:chat:%d+$') then return nil,'INVALID_SOURCE_REF' end
    sourceID=A.OperationalRef(sourceID);if not sourceID then return nil,'INVALID_SOURCE_REF' end
    ResetOwner();if corrections[sourceID] then return corrections[sourceID],'DUPLICATE' end
    local c=S.WriterCharacter(C.Owner(),false);if not c or not c.currentSession then return nil,'HISTORY_UNAVAILABLE' end
    local at,clock=C.Stamp();local elapsed=C.Tick();if not at or not elapsed then return nil,'CLOCK_UNAVAILABLE' end
    local e=S.Append(C.Owner(),{kind='native_event',source='control',session=c.currentSession,at=at,elapsed=elapsed,
        timeSource=clock,evidence='observed',location={},sourceContext={version=1,sourceModule='chat',accessScope='PRIVATE_INCIDENT',linkStatus='LINK_PENDING'},
        details={recordType='incident_correction',correctedSourceID=sourceID,method='source decision marked false positive',
            scope='explicit user correction; applies only to matching retained private source dependency',
            evidenceClass='native-event',outcome='source-observed',outcomeScope='source-qualified'}})
    if not e then I.diagnostics.denied=I.diagnostics.denied+1;return nil,'WRITE_REJECTED' end
    if #correctionOrder>=1024 then corrections[table.remove(correctionOrder,1)]=nil end
    correctionOrder[#correctionOrder+1]=sourceID;corrections[sourceID]=e.id
    I.diagnostics.corrected=I.diagnostics.corrected+1;return e.id,'COMMITTED_OR_STAGED'
end
I.CorrectHistorical=Correction
function I.Notify(kind,row)
    if kind=='correction' then Correction(row.targetID,row.id);return end
    if not AllowedCapture() or kind~='decision' and kind~='action' then return end
    if kind=='decision' and (not row.spam or row.observer~=select(2,C.Owner())) then return end
    if kind=='action' and row.owner~='shield' then return end
    ResetOwner();local c=S.WriterCharacter(owner,false);if not c then return end
    local context=ns.AthenaIntakeContext.State(owner,c.currentSession)
    local anchor=context.matchRef or context.instanceRef or c.currentSession
    local key=anchor..'/'..kind..'/'..(S.GUID(row.subject) or 'unresolved')
    local b=Bucket(key)
    if b.saved then I.diagnostics.coalesced=I.diagnostics.coalesced+1;return end
    b.firstAt=b.firstAt or row.at;b.lastAt=row.at
    if kind=='decision' then
        for _,id in ipairs(b.causes) do if id==row.id then return end end
        if #b.causes<3 then b.causes[#b.causes+1]=row.id end
        if #b.causes<3 then return end
    else
        for n=1,math.min(3,#(row.causeIDs or {})) do b.causes[n]=row.causeIDs[n] end
    end
    local e=X.Record('native_event','control',{recordType='historical_incident',sourceActionID=A.OperationalRef(row.id),
        ownerModule=kind=='decision' and 'chat' or 'shield',cause1=A.OperationalRef(b.causes[1]),cause2=A.OperationalRef(b.causes[2]),cause3=A.OperationalRef(b.causes[3]),
        firstAt=b.firstAt,lastAt=b.lastAt,count=kind=='decision' and 3 or 1,
        method=kind=='decision' and 'three local filter decisions' or 'own protection action',
        scope='private local source/action metadata; no message text, intent, guilt or causation inferred'},nil,false)
    if e then b.saved=e.id;I.diagnostics.saved=I.diagnostics.saved+1 else I.diagnostics.denied=I.diagnostics.denied+1 end
end
local function Projection(observer,c)
    local p=projections[observer]
    if not p or p.character~=c or p.revision~=c.revision then
        if not p then projectionOrder[#projectionOrder+1]=observer;if #projectionOrder>2 then projections[table.remove(projectionOrder,1)]=nil end end
        p={character=c,revision=c.revision,corrected={}};projections[observer]=p
        p.job=coroutine.create(function()
            for n,e in ipairs(c.events) do
                if e.details.recordType=='incident_correction' then
                    local id=e.details.correctedSourceID
                    p.corrected[id]=p.corrected[id] or {ref=ns.Athena.EvidenceRef(e.id),at=e.at}
                end
                if n%128==0 then coroutine.yield() end
            end
            p.done=true
        end)
    end
    if not p.done then local ok=coroutine.resume(p.job);if not ok then projections[observer]=nil;return end end
    return p.done and p or nil
end
function I.ResolveOperational(consumer,ref)
    if not ({chat=true,shield=true,alerts=true,command=true})[consumer] or not A.Enabled(consumer) or not ns.Membership.LocalHistoryAllowed() then return nil,'DENIED' end
    local id=A.OperationalSource(ref);if not id then return nil,'INVALID_REF' end
    local root=ns.DB and ns.DB.athena;local store=type(root)=='table' and root.version==1 and root.operational
    if type(store)~='table' then return nil,'UNAVAILABLE' end
    local found
    for _,row in ipairs(store.decisions or {}) do if row.id==id then found=row;break end end
    if not found then for _,row in ipairs(store.actions or {}) do if row.id==id then found=row;break end end end
    if not found then for _,row in pairs(store.corrections or {}) do if row.id==id then found=row;break end end end
    if not found then return nil,'OUTSIDE_RETAINED_OPERATIONAL_WINDOW' end
    local out={evidenceRef=ref,horizon='Bounded operational detail; not lifetime canonical history',accessScope='PRIVATE_OPERATIONAL'}
    for _,key in ipairs({'id','originKind','subject','observer','at','source','action','owner','causeIDs','targetID','kind','policyVersion'}) do out[key]=A.Copy(found[key]) end
    return out
end
function A.GetHistoricalIncidents(consumer,observer,cursor,options)
    if not ({chat=true,shield=true,command=true})[consumer] or not A.Enabled(consumer) or not I.Selected() or not ns.Membership.LocalHistoryAllowed() then return nil,'DENIED' end
    observer=observer or C.Owner();local c,status=S.Character(observer,false);if not c then S.RequestCharacter(observer);return nil,status end
    local projection=Projection(observer,c);if not projection then return nil,'INDEXING' end
    options=options or {};local offset=cursor and S.Integer(cursor.offset,0,#c.events) or 0
    if not offset or cursor and (cursor.owner~=observer or not S.Integer(cursor.extent,1,#c.events) or offset>cursor.extent
        or cursor.highwater~=c.events[cursor.extent].id) then return nil,'CURSOR_STALE' end
    local extent=cursor and cursor.extent or #c.events;local out,scanned={},0
    while offset<extent and #out<(S.Integer(options.limit,1,50) or 20) and scanned<512 do
        offset=offset+1;scanned=scanned+1;local e=c.events[extent-offset+1]
        if e.details.recordType=='historical_incident' or e.details.recordType=='incident_correction' then
            local d=e.details;local corrected,dependencies=0,{}
            for _,key in ipairs({'cause1','cause2','cause3'}) do local id=d[key];local fix=id and projection.corrected[id]
                if fix then corrected=corrected+1;dependencies[#dependencies+1]={sourceID=id,correctionRef=fix.ref,correctedAt=fix.at} end
            end
            out[#out+1]={ref=A.EvidenceRef(e.id),id=e.id,at=e.at,observer=observer,details=A.Copy(e.details),sourceContext=A.Copy(e.sourceContext),
                correctedDependencyCount=corrected,correctionDependencies=dependencies,
                activeSourceCount=d.recordType=='historical_incident' and math.max(0,d.count-corrected) or nil,
                interpretation=corrected>0 and 'SOURCE_CORRECTED; original action retained, repeated-source assessment withdrawn' or 'SOURCE_QUALIFIED; no misconduct conclusion',
                share='PRIVATE_LOCAL_ONLY',qualification='Source decision/action; no player-misconduct conclusion'}
        end
    end
    return out,offset<extent and {owner=observer,offset=offset,extent=extent,highwater=c.events[extent].id} or nil
end
ns.WardenDB.GetHistoricalIncidents=A.GetHistoricalIncidents
