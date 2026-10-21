-- Read-only, rebuildable activity lens. No copied source archive or saved edges.
local _,ns=...
local A,C,S=ns.Athena,ns.Chronicle,ns.ChronicleStore
local G={VERSION=1};ns.AthenaHistoryGraph=G
local caches,order={},{}
local readers,readerOrder={},{}
local function Permit(consumer)
    return ({chronicle=true,intel=true,chat=true,shield=true,alerts=true,command=true})[consumer] and A.Enabled(consumer)
        and ns.Membership.LocalHistoryAllowed()
end
function G.Private(e) return e.sourceContext and e.sourceContext.accessScope=='PRIVATE_INCIDENT' end
function G.CanRead(consumer,e)
    if not Permit(consumer) then return false end
    return not G.Private(e) or ns.DB.historicalIncidentConsent==1 and ({chat=true,shield=true,command=true})[consumer]==true
end
function A.EvidenceRef(id) return S.Text(id,256) and 'history:'..id or nil end
local function Original(ref)
    ref=S.Text(ref,768);return ref and ref:match('^history:(.+)$')
end
local function Ref(kind,id) return 'activity:'..kind..':'..id end
local function Copy(v) return A.Copy(v) end
local function Own(id) return id and id:match('^(.*):%d+$') end
local function Node(g,kind,e,unknown)
    local ref=Ref(kind,e.id);local n={activityRef=ref,type=kind,observer=e.character,observerGUID=e.character:match('/(Player%-.+)$'),
        firstObservedAt=e.at,lastObservedAt=e.at,observedStartAt=not unknown and e.at or nil,unknownStart=unknown==true,
        unknownEnd=true,status='OPEN',sourceRef=A.EvidenceRef(e.id),sourceID=e.id,source=e.source,place=Copy(e.location),
        parentRef=g.state.play,accessScope='LOCAL_HISTORY',classificationVersion=1,sourceCount=0}
    g.byRef[ref]=n;g.byAnchor[e.id]=ref;g.activities[#g.activities+1]=n;return ref,n
end
local function Close(g,ref,e,known)
    local n=ref and g.byRef[ref];if not n then return end
    if known then n.lastObservedAt=e.at end;n.unknownEnd=not known;n.observedEndAt=known and e.at or nil
    n.endSourceRef=known and A.EvidenceRef(e.id) or nil;n.status=known and 'CLOSED' or 'INCOMPLETE'
end
local function Point(g,index)
    local out={index=index};for key,value in pairs(g.state) do out[key]=value end
    g.points[#g.points+1]=out
end
local function Build(g,start)
    for index=start or 1,g.extent do
        local e=g.character.events[index];local d=e.details;local r=d.recordType;local st=g.state
        g.positions[e.id]=index
        if e.capture then g.objects[d.contentID]=index end
        local changed=false
        if st.nativeSession~=e.session or e.kind=='recording_start' and d.reason=='ui-reload' then
            for _,key in ipairs({'play','instance','encounter','match','group','visit'}) do Close(g,st[key],e,false) end
            g.state={nativeSession=e.session};st=g.state
            st.play=Node(g,'PLAY_SESSION',e,e.kind~='session_start');changed=true
        elseif e.kind=='recording_start' and not st.play then st.play=Node(g,'PLAY_SESSION',e,true);changed=true end
        local instance=st.instance and g.byRef[st.instance]
        if e.kind~='instance_enter' and e.kind~='instance_exit' and instance and ns.AthenaHistorySchema.InstanceContradiction(instance.place,e.location) then
            for _,key in ipairs({'instance','encounter','match'}) do
                local n=st[key] and g.byRef[st[key]]
                if n then
                    Close(g,st[key],e,false);n.contradictionIndex=index
                    n.boundaryReason='Location changed; instance exit unobserved'
                    n.boundaryEvidenceRef=A.EvidenceRef(e.id)
                end
                st[key]=nil
            end
            changed=true
        end
        if e.kind=='instance_enter' then
            Close(g,st.encounter,e,false);Close(g,st.match,e,false)
            Close(g,st.instance,e,false);st.instance=Node(g,(e.location.instanceType=='raid' and 'RAID_RUN' or e.location.instanceType=='pvp' and 'BATTLEGROUND_VISIT' or 'INSTANCE_VISIT'),e,d.reason=='recording-started-inside');st.encounter=nil;st.match=nil;changed=true
        elseif e.kind=='instance_exit' then Close(g,st.encounter,e,false);Close(g,st.match,e,false);Close(g,st.instance,e,true);changed=true
        elseif r=='encounter_started' then
            Close(g,st.encounter,e,false);st.encounter=Node(g,'ENCOUNTER_ATTEMPT',e,false)
            local n=g.byRef[st.encounter];n.encounterID=d.encounterID;n.parentRef=st.instance or st.play;changed=true
        elseif r=='encounter_ended' then
            local ref=e.sourceContext and e.sourceContext.encounterRef;ref=ref and g.byAnchor[ref] or st.encounter
            local n=ref and g.byRef[ref]
            if not n or n.encounterID~=d.encounterID then ref,n=Node(g,'ENCOUNTER_RESULT',e,true);n.encounterID=d.encounterID end
            st.encounter=ref
            n.nativeOutcome=d.success==1 and 'SUCCESS' or d.success==0 and 'FAILURE' or 'UNKNOWN';n.outcomeSourceRef=A.EvidenceRef(e.id);Close(g,ref,e,true);changed=true
        elseif r=='match_observed' then
            Close(g,st.match,e,false);st.match=Node(g,'BATTLEGROUND_MATCH',e,false);changed=true
        elseif r=='pvp_match_complete' then
            local ref=e.sourceContext and e.sourceContext.matchRef;ref=ref and g.byAnchor[ref] or st.match
            local n=ref and g.byRef[ref];if not n then ref,n=Node(g,'BATTLEGROUND_MATCH',e,true) end;st.match=ref
            n.winnerRaw=d.winner;n.ownerResult='UNKNOWN';n.outcomeSourceRef=A.EvidenceRef(e.id);Close(g,ref,e,true);changed=true
        elseif r=='duel_session_start' and d.accepted==true then
            local ref,n=Node(g,'DUEL',e,false);n.duelID=d.duelID;n.opponentGUID=d.opponentGUID
            g.duels[d.duelID]=ref;st.duel=ref;changed=true
        elseif (r=='duel_session_end' or r=='duel_session_result') and d.duelID then
            local ref=g.duels[d.duelID];local n=ref and g.byRef[ref]
            if n then n.nativeOutcome=d.result or 'UNKNOWN';n.outcomeSourceRef=A.EvidenceRef(e.id);Close(g,ref,e,true) end;changed=true
        elseif e.kind=='group_roster' then
            st.roster=e.id
            if #d.members>0 and not st.group then st.group=Node(g,'GROUP_PERIOD',e,true)
            elseif #d.members==0 and d.rosterComplete~=false then Close(g,st.group,e,true) end
            local n=st.group and g.byRef[st.group]
            if n then n.lastRosterComplete=d.rosterComplete~=false;if d.rosterComplete==false then n.hasPartialRosters=true end end
            changed=true
        end
        local map=e.sourceContext and e.sourceContext.mapID or e.route and e.route.mapID
        if (e.kind=='location' or e.kind=='route_segment') and (not st.visit or map and st.mapID~=map or e.location.zone~=st.zone) then
            Close(g,st.visit,e,e.kind=='location');st.visit=Node(g,'ZONE_VISIT',e,e.kind~='location')
            st.mapID=map;st.zone=e.location.zone;local n=g.byRef[st.visit];n.mapID=map;n.worldMapID=e.route and e.route.worldMapID
            n.zoneKey=map and 'ui-map:'..map or n.worldMapID and 'native-world:'..n.worldMapID or nil
            n.chapterStatus='CHAPTER_DERIVATION_PENDING';changed=true
        end
        if changed then Point(g,index) end
        for _,key in ipairs({'play','instance','encounter','match','group','visit','duel'}) do
            local n=st[key] and g.byRef[st[key]]
            if n and n.status=='OPEN' then n.lastObservedAt=e.at;n.sourceCount=n.sourceCount+1 end
        end
        if e.kind=='instance_exit' then st.instance=nil;st.encounter=nil;st.match=nil;Point(g,index+1)
        elseif r=='encounter_ended' then st.encounter=nil;Point(g,index+1)
        elseif r=='pvp_match_complete' then st.match=nil;Point(g,index+1)
        elseif r=='duel_session_end' or r=='duel_session_result' then st.duel=nil;Point(g,index+1)
        elseif e.kind=='group_roster' and #d.members==0 and d.rosterComplete~=false then st.group=nil;Point(g,index+1)
        elseif e.kind=='recording_stop' then for _,key in ipairs({'play','instance','encounter','match','group','visit','duel'}) do Close(g,st[key],e,key=='play');st[key]=nil end;Point(g,index+1) end
        if index%128==0 then coroutine.yield() end
    end
    g.done=true
end
local function Request(owner)
    local c,status=S.Character(owner,false);if not c then S.RequestCharacter(owner);return nil,status end
    local st,state=ns.ChronicleActivities.Request(owner);if not st then ns.ChronicleActivities.Pump();return nil,state or 'INDEXING' end
    local g=caches[owner]
    local stable=g and g.extent<=#c.events and (g.extent==0 or c.events[g.extent].id==g.highwater)
    if g and g.character==c and stable and g.done and g.revision~=c.revision then
        local start=g.extent+1;g.extent=#c.events;g.highwater=c.events[g.extent] and c.events[g.extent].id;g.revision=c.revision;g.firsts={};g.firstOrder={}
        g.done=false;g.job=coroutine.create(function() Build(g,start) end)
    elseif not g or g.character~=c or not stable then
        if not g then order[#order+1]=owner;if #order>2 then caches[table.remove(order,1)]=nil end end
        g={owner=owner,character=c,revision=c.revision,extent=#c.events,activities={},byRef={},byAnchor={},points={},positions={},objects={},duels={},state={},firsts={},firstOrder={}}
        g.highwater=c.events[g.extent] and c.events[g.extent].id
        g.job=coroutine.create(function() Build(g) end);caches[owner]=g
    end
    if not g.done then
        local ok,why=coroutine.resume(g.job)
        if not ok then caches[owner]=nil;return nil,'LINK_PENDING' end
        if not g.done then return nil,'INDEXING' end
    end
    return g
end
local function Source(g,id) local n=g.positions[id];return n and g.character.events[n] end
function A.ClearHistoryContext()
    caches={};order={};readers={};readerOrder={}
    if ns.AthenaIncidents then ns.AthenaIncidents.ClearQueries() end
end
local function FindOriginal(owner,id)
    local c,status=S.Character(owner,false);if not c then S.RequestCharacter(owner);return nil,status end
    local g=caches[owner];local n=g and g.character==c and g.positions[id]
    if n and c.events[n] and c.events[n].id==id then return c.events[n] end
    -- Exact source resolution never depends on the optional activity graph.
    -- A bounded scan is resumable even if the graph/index service is broken.
    local job=readers[id]
    if not job or job.character~=c or job.extent>#c.events or job.extent>0 and c.events[job.extent].id~=job.highwater then
        if not job then
            if #readerOrder>=8 then readers[table.remove(readerOrder,1)]=nil end
            readerOrder[#readerOrder+1]=id
        end
        job={character=c,offset=0,extent=#c.events,highwater=c.events[#c.events] and c.events[#c.events].id};readers[id]=job
    end
    if job.found and c.events[job.found] and c.events[job.found].id==id then return c.events[job.found] end
    if job.offset==job.extent and job.extent<#c.events then job.extent=#c.events;job.highwater=c.events[job.extent].id end
    for index=job.offset+1,math.min(job.extent,job.offset+128) do
        local e=c.events[index];job.offset=index
        if e.id==id then job.found=index;return e end
    end
    return nil,job.offset<job.extent and 'INDEXING' or 'UNAVAILABLE'
end
function A.PumpHistoryContext(owner) return Request(owner or C.Owner()) end
local function ContextAt(g,index,e)
    local low,high,best=1,#g.points,nil
    while low<=high do local mid=math.floor((low+high)/2);local p=g.points[mid]
        if p.index<=index then best=p;low=mid+1 else high=mid-1 end end
    local out={};for key,value in pairs(best or {}) do if key~='index' then out[key]=value end end
    local x=e.sourceContext
    if x then
        for field,key in pairs({instanceRef='instance',encounterRef='encounter',matchRef='match'}) do
            if x[field] then
                local ref=g.byAnchor[x[field]];local n=ref and g.byRef[ref]
                -- Old originals may carry a stale pre-P9 context. Qualify the
                -- read view without rewriting it. Explicit delayed match refs
                -- remain historical match affinity, not current attendance.
                local delayed=key=='match' and e.details.matchRef==x[field]
                local contradicted=n and n.contradictionIndex and index>=n.contradictionIndex
                if key=='instance' and n and ns.AthenaHistorySchema.InstanceContradiction(n.place,e.location) then contradicted=true end
                out[key]=n and (not contradicted or delayed) and ref or nil
            end
        end
        if x.rosterRef then out.roster=x.rosterRef end
    end
    return out
end
local function Contexts(g,index,e)
    local st=ContextAt(g,index,e);local out={}
    for _,key in ipairs({'play','instance','encounter','match','group','visit','duel'}) do if st[key] then out[#out+1]=st[key] end end
    return out,st
end
function A.ResolveEvidence(consumer,ref)
    if not Permit(consumer) then return nil,'DENIED' end
    local id=Original(ref)
    if not id then if ns.AthenaIncidents then return ns.AthenaIncidents.ResolveOperational(consumer,ref) end;return nil,'UNAVAILABLE' end
    local owner=Own(id);if not owner then return nil,'INVALID_REF' end
    local e,status=FindOriginal(owner,id);if not e then return nil,status end
    if not G.CanRead(consumer,e) then return nil,'DENIED' end
    return {evidenceRef=ref,sourceRecordRef=e.id,source=e.source,sourceModule=e.sourceContext and e.sourceContext.sourceModule,
        observer=e.character,observerGUID=e.character:match('/(Player%-.+)$'),subjectGUID=e.subject,
        observedAt=e.at,elapsed=e.elapsed,clock=e.timeSource,sourceContext=Copy(e.sourceContext),details=Copy(e.details),
        location=Copy(e.location),capture=Copy(e.capture),route=Copy(e.route),linkStatus=e.sourceContext and e.sourceContext.linkStatus or 'LEGACY_CONTEXT_QUALIFIED'}
end
local function Page(g,values,cursor,options,key)
    options=options or {};local offset=0
    if cursor then if cursor.owner~=g.owner or cursor.key~=key or cursor.revision~=g.revision then return nil,'CURSOR_STALE' end;offset=S.Integer(cursor.offset,0,#values);if not offset then return nil,'INVALID_CURSOR' end end
    local out={};local limit=S.Integer(options.limit,1,50) or 20
    for n=offset+1,math.min(#values,offset+limit) do out[#out+1]=Copy(values[n]) end
    offset=offset+#out
    return out,offset<#values and {owner=g.owner,key=key,revision=g.revision,offset=offset} or nil
end
function A.GetHistoryActivities(consumer,owner,cursor,options)
    if not Permit(consumer) then return nil,'DENIED' end
    owner=owner or C.Owner();local g,status=Request(owner);if not g then return nil,status end
    options=options or {};local from,to=S.Number(options.from,0),S.Number(options.to,0)
    local kind=S.Text(options.type,64);local direction=S.Text(options.direction,16)
    local key='activities/'..(kind or 'all')..'/'..tostring(from)..'/'..tostring(to)..'/'..tostring(direction)
    local offset=0
    if cursor then if cursor.owner~=g.owner or cursor.key~=key or cursor.revision~=g.revision then return nil,'CURSOR_STALE' end;offset=S.Integer(cursor.offset,0,#g.activities);if not offset then return nil,'INVALID_CURSOR' end end
    local out,scanned={},0;local limit=S.Integer(options.limit,1,50) or 20
    while offset<#g.activities and #out<limit and scanned<512 do
        local n=g.activities[direction=='newest' and #g.activities-offset or offset+1];offset=offset+1;scanned=scanned+1
        if (not kind or n.type==kind) and (not from or n.lastObservedAt>=from) and (not to or n.firstObservedAt<=to) then out[#out+1]=Copy(n) end
    end
    return out,offset<#g.activities and {owner=g.owner,key=key,revision=g.revision,offset=offset} or nil
end
function A.GetHistoryActivity(consumer,owner,ref)
    if not Permit(consumer) then return nil,'DENIED' end
    local g,status=Request(owner or C.Owner());if not g then return nil,status end
    return Copy(g.byRef[ref]),g.byRef[ref] and nil or 'UNAVAILABLE'
end
function A.GetActivityEvidence(consumer,owner,ref,cursor,options)
    if not Permit(consumer) then return nil,'DENIED' end
    local g,status=Request(owner or C.Owner());if not g then return nil,status end
    if not g.byRef[ref] then return nil,'UNAVAILABLE' end
    local offset=0;options=options or {}
    if cursor then if cursor.owner~=g.owner or cursor.key~=ref or cursor.revision~=g.revision then return nil,'CURSOR_STALE' end;offset=S.Integer(cursor.offset,0,g.extent);if not offset then return nil,'INVALID_CURSOR' end end
    local out,scanned={},0;local limit=S.Integer(options.limit,1,50) or 20
    while offset<g.extent and #out<limit and scanned<512 do
        offset=offset+1;scanned=scanned+1;local e=g.character.events[offset]
        if G.CanRead(consumer,e) then
            local refs=Contexts(g,offset,e)
            for _,v in ipairs(refs) do if v==ref then out[#out+1]={evidenceRef=A.EvidenceRef(e.id),id=e.id,at=e.at,
                source=e.source,family=e.details.recordType or e.kind,support='CONTEXTUAL',noCausation=true};break end end
        end
    end
    return out,offset<g.extent and {owner=g.owner,key=ref,revision=g.revision,offset=offset} or nil
end
function A.GetEvidenceRelationships(consumer,ref)
    local id=Original(ref);local owner=id and Own(id);if not owner or not Permit(consumer) then return nil,'DENIED' end
    local g,status=Request(owner);if not g then return nil,status end
    local e=Source(g,id);if not e or not G.CanRead(consumer,e) then return nil,'DENIED' end
    local index=g.positions[e.id]
    if not index then return nil,'UNAVAILABLE' end
    local refs,st=Contexts(g,index,e);local out={}
    for _,v in ipairs(refs) do out[#out+1]={relationRef='relation:'..ref..'->'..v,fromRef=ref,toRef=v,kind='OBSERVED_DURING',
        supportingEvidenceRefs={ref,g.byRef[v].sourceRef},observer=owner,observedAt=e.at,strength='CONTEXTUAL',version=1,
        accessScope=G.Private(e) and 'PRIVATE_INCIDENT' or 'LOCAL_HISTORY',causal=false} end
    if st.roster and Source(g,st.roster) then
        local roster=Source(g,st.roster);out[#out+1]={relationRef='relation:'..ref..'->roster:'..st.roster,
            fromRef=ref,toRef=A.EvidenceRef(st.roster),kind='LAST_OBSERVED_ROSTER',supportingEvidenceRefs={A.EvidenceRef(st.roster)},
            observedAt=roster.at,strength='CONTEXTUAL',continuousAttendance=false,version=1}
    end
    return out
end
local function Firsts(g,guid)
    local out={subjectGUID=guid,observer=g.owner,gearAtFirstMeeting='UNKNOWN',coverage='First retained observation; not first-ever life event'}
    for index=1,g.extent do local e=g.character.events[index];if e.subject==guid then
        local d=e.details
        if not out.firstSeen and e.kind=='player_observed' then out.firstSeen={ref=A.EvidenceRef(e.id),at=e.at} end
        if not out.firstInteraction and d.recordType=='contact_observed' then out.firstInteraction={ref=A.EvidenceRef(e.id),at=d.triggerAt,observedAt=e.at,kind=d.contactKind} end
        for _,kind in ipairs({'gear','trait','appearance'}) do
            local key=kind=='trait' and 'firstTalents' or kind=='gear' and 'firstGear' or 'firstAppearance'
            if d[kind..'Ref'] and not out[key] then
                local objectIndex=g.objects[d[kind..'Ref']];local object=objectIndex and g.character.events[objectIndex]
                local values=object and object.capture.values;local known=kind=='appearance'
                if kind=='gear' then for _,slot in ipairs(values and values.slots or {}) do if slot[2]=='present' and S.Integer(slot[3],1) then known=true;break end end end
                if kind=='trait' then known=values and (S.Text(values.exportString,5000)~=nil or values.choices and #values.choices>0) end
                if values and known then out[key]={ref=A.EvidenceRef(e.id),snapshotRef=d[kind..'Ref'],at=d[kind..'ObservedAt'] or e.at,complete=values.choicesComplete,
                    exact=kind=='appearance' and values.exact==true or nil} end
            end
        end
    end;if index%128==0 then coroutine.yield() end end
    if out.firstGear and out.firstInteraction and out.firstGear.at>=out.firstInteraction.at then out.gearObservationDelay=out.firstGear.at-out.firstInteraction.at end
    return out
end
local function SourcePage(consumer,owner,cursor,options,key,selectRow)
    if not Permit(consumer) then return nil,'DENIED' end
    local g,status=Request(owner or C.Owner());if not g then return nil,status end
    local offset=0;options=options or {}
    if cursor then
        if cursor.owner~=g.owner or cursor.key~=key or cursor.revision~=g.revision then return nil,'CURSOR_STALE' end
        offset=S.Integer(cursor.offset,0,g.extent);if not offset then return nil,'INVALID_CURSOR' end
    end
    local out,scanned={},0;local limit=S.Integer(options.limit,1,50) or 20
    local from,to=S.Number(options.from,0),S.Number(options.to,0)
    while offset<g.extent and #out<limit and scanned<512 do
        offset=offset+1;scanned=scanned+1;local e=g.character.events[offset]
        if G.CanRead(consumer,e) and (not from or e.at>=from) and (not to or e.at<=to) then
            local row=selectRow(g,e);if row then out[#out+1]=row end
        end
    end
    return out,offset<g.extent and {owner=g.owner,key=key,revision=g.revision,offset=offset} or nil
end
function A.GetObservedSnapshots(consumer,guid,owner,cursor,options)
    if consumer~='intel' or not S.GUID(guid) then return nil,'DENIED' end
    return SourcePage(consumer,owner,cursor,options,'snapshots/'..guid,function(g,e)
        if e.subject~=guid then return end
        local out={evidenceRef=A.EvidenceRef(e.id),observer=e.character,subjectGUID=guid,source=e.source,snapshots={}}
        for family,key in pairs({gear='gearRef',traits='traitRef',appearance='appearanceRef'}) do
            local ref=e.details[key];local index=ref and g.objects[ref];local object=index and g.character.events[index]
            if object and object.capture.values.guid==guid then
                local values=object.capture.values;local known,unavailable=0,0
                for _,slot in ipairs(values.slots or {}) do if slot[2]=='present' then known=known+1 elseif slot[2]=='unavailable' then unavailable=unavailable+1 end end
                out.snapshots[#out.snapshots+1]={family=family,snapshotRef=ref,sourceRef=A.EvidenceRef(object.id),
                    observedAt=e.details[(family=='traits' and 'trait' or family)..'ObservedAt'] or e.at,
                    readableSlots=family=='gear' and known or nil,unavailableSlots=family=='gear' and unavailable or nil,
                    choicesComplete=values.choicesComplete,identityOnly=family=='traits' and not values.exportString and not values.choices or nil}
            end
        end
        return #out.snapshots>0 and out or nil
    end)
end
function A.GetPersonalRoute(consumer,owner,cursor,options)
    if consumer~='chronicle' then return nil,'DENIED' end
    return SourcePage(consumer,owner,cursor,options,'personal-route',function(g,e)
        if e.kind~='route_segment' and e.kind~='collection_gap' then return end
        return {evidenceRef=A.EvidenceRef(e.id),observer=e.character,session=e.session,observedAt=e.at,
            source=e.source,details=Copy(e.details),location=Copy(e.location),route=Copy(e.route),
            sourceContext=Copy(e.sourceContext),continuity='Only original segment/gap semantics; never splice across missing maps, sessions or observers'}
    end)
end
function A.GetFirstObservations(consumer,guid,owner)
    if consumer~='intel' or not Permit(consumer) or not S.GUID(guid) then return nil,'DENIED' end
    local g,status=Request(owner or C.Owner());if not g then return nil,status end
    local v=g.firsts[guid]
    if not v then
        if #g.firstOrder>=64 then g.firsts[table.remove(g.firstOrder,1)]=nil end
        g.firstOrder[#g.firstOrder+1]=guid;v={};g.firsts[guid]=v
        v.job=coroutine.create(function() v.result=Firsts(g,guid) end)
    end
    if not v.result then
        local ok=coroutine.resume(v.job);if not ok then g.firsts[guid]=nil;return nil,'LINK_PENDING' end
        if not v.result then return nil,'INDEXING' end
        v.job=nil
    end
    return Copy(v.result)
end
function A.GetObservedParticipants(consumer,owner,activityRef,cursor,options)
    local rows,nextCursor=A.GetActivityEvidence(consumer,owner,activityRef,cursor,options);if not rows then return nil,nextCursor end
    local out={}
    for _,row in ipairs(rows) do if row.family=='group_roster' then
        local e=A.ResolveEvidence(consumer,row.evidenceRef)
        if e then out[#out+1]={sourceRef=row.evidenceRef,observedAt=row.at,members=e.details.members,
            complete=e.details.rosterComplete,scope='observed roster point; not continuous attendance or damage participation'} end
    end end
    return out,nextCursor
end
for _,key in ipairs({'EvidenceRef','ResolveEvidence','GetHistoryActivities','GetHistoryActivity','GetActivityEvidence','GetEvidenceRelationships','GetFirstObservations','GetObservedParticipants','GetObservedSnapshots','GetPersonalRoute','ClearHistoryContext','PumpHistoryContext'}) do ns.WardenDB[key]=A[key] end
-- Pure read projection seam. This never registers the supplied character in
-- canonical stores/caches, and does not grant any production read permission.
function G.NewProjection(character,owner)
    local g={owner=owner,character=character,revision=0,extent=#character.events,activities={},byRef={},byAnchor={},points={},positions={},objects={},duels={},state={},firsts={},firstOrder={}}
    g.job=coroutine.create(function() Build(g) end);return g
end
function G.StepProjection(g)
    if g.done then return true end
    local ok,why=coroutine.resume(g.job);if not ok then return nil,why end
    return g.done==true
end
G.ProjectionContexts=Contexts
