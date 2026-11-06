-- Read-only, rebuildable activity lens. No copied source archive or saved edges.
local _,ns=...
local A,C,S=ns.Athena,ns.Chronicle,ns.ChronicleStore
local G={VERSION=2};ns.AthenaHistoryGraph=G
local caches,order={},{}
local readers,readerOrder={},{}
local function Permit(consumer)
    return ({chronicle=true,intel=true,chat=true,shield=true,alerts=true,command=true})[consumer] and A.Enabled(consumer)
        and ns.Membership.LocalHistoryAllowed()
end
function G.Private(e) return e.sourceContext and (e.sourceContext.accessScope=='PRIVATE_INCIDENT' or e.sourceContext.accessScope=='OWNER_PRIVATE') end
function G.CanRead(consumer,e)
    if not Permit(consumer) then return false end
    if e.sourceContext and e.sourceContext.accessScope=='OWNER_PRIVATE' then return e.character==C.Owner() and consumer=='chronicle' end
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
    ns.ChronicleRuns.MapGraph(g);g.done=true
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
    g.activityState=st
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
    return {evidenceRef=ref,sourceRecordRef=e.id,family=e.details.recordType or e.kind,source=e.source,sourceModule=e.sourceContext and e.sourceContext.sourceModule,
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
    local node=g.byRef[ref];if not node then return nil,'UNAVAILABLE' end
    -- Activity membership cannot precede its original anchor or follow its
    -- observed close. Keep absolute cursors, but avoid rescanning other runs.
    local offset=math.max(0,(g.positions[node.sourceID] or 1)-1);options=options or {}
    local extent=node.endSourceRef and g.positions[Original(node.endSourceRef)] or node.contradictionIndex and node.contradictionIndex-1 or g.extent
    if cursor then if cursor.owner~=g.owner or cursor.key~=ref or cursor.revision~=g.revision then return nil,'CURSOR_STALE' end;offset=S.Integer(cursor.offset,0,g.extent);if not offset then return nil,'INVALID_CURSOR' end end
    local out,scanned={},0;local limit=S.Integer(options.limit,1,50) or 20
    while offset<extent and #out<limit and scanned<512 do
        offset=offset+1;scanned=scanned+1;local e=g.character.events[offset]
        if G.CanRead(consumer,e) then
            local refs=Contexts(g,offset,e)
            for _,v in ipairs(refs) do if v==ref then out[#out+1]={evidenceRef=A.EvidenceRef(e.id),id=e.id,at=e.at,
                source=e.source,family=e.details.recordType or e.kind,support='CONTEXTUAL',noCausation=true};break end end
        end
    end
    return out,offset<extent and {owner=g.owner,key=ref,revision=g.revision,offset=offset} or nil
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
-- Journal-only authorized reference stream. It exposes selected structured
-- fields, never raw chat/incident text or a second copy of the source ledger.
-- Absolute cursors can extend an unchanged prefix when new events append.
function A.GetJournalActivities(consumer,owner,cursor,frontier)
    if consumer~='chronicle' or not Permit(consumer) then return nil,'DENIED' end
    local g,status=Request(owner or C.Owner());if not g then return nil,status end
    frontier=frontier or cursor and cursor.frontier or {count=g.extent,lastID=g.character.events[g.extent] and g.character.events[g.extent].id}
    local extent=S.Integer(frontier.count,0,g.extent)
    if not extent or extent>0 and g.character.events[extent].id~=frontier.lastID then return nil,'CURSOR_STALE' end
    local offset=cursor and S.Integer(cursor.offset,0,#g.activities) or 0
    local total=cursor and S.Integer(cursor.total,0,#g.activities) or #g.activities
    if not offset or not total or cursor and (cursor.owner~=g.owner or total>0 and g.activities[total].activityRef~=cursor.boundRef) then return nil,'CURSOR_STALE' end
    local rows={};local scanned=0
    while offset<total and #rows<12 and scanned<128 do
        offset=offset+1;scanned=scanned+1;local n=g.activities[total-offset+1]
        if (g.positions[n.sourceID] or math.huge)<=extent then
            local copy=ns.ChronicleRuns.JournalNode(g,n,extent)
            if copy then
                local last=copy.endSourceRef and Original(copy.endSourceRef)
                if last and (g.positions[last] or math.huge)>extent then copy.unknownEnd=true;copy.observedEndAt=nil;copy.endSourceRef=nil;copy.status='INCOMPLETE' end
                if copy.unknownEnd and extent>0 then copy.lastObservedAt=math.min(copy.lastObservedAt,g.character.events[extent].at) end
                rows[#rows+1]=copy
            end
        end
    end
    return rows,offset<total and {owner=g.owner,offset=offset,total=total,boundRef=total>0 and g.activities[total].activityRef,frontier=frontier} or nil,frontier
end
function A.GetJournalSources(consumer,owner,cursor,frontier)
    if consumer~='chronicle' or not Permit(consumer) then return nil,'DENIED' end
    local g,status=Request(owner or C.Owner());if not g then return nil,status end
    frontier=frontier or {count=g.extent,lastID=g.character.events[g.extent] and g.character.events[g.extent].id}
    local extent=S.Integer(frontier.count,0,g.extent)
    if not extent or extent>0 and g.character.events[extent].id~=frontier.lastID then return nil,'CURSOR_STALE' end
    local offset=cursor and S.Integer(cursor.offset,0,g.extent) or 0
    if not offset or cursor and (cursor.owner~=g.owner or offset>0 and g.character.events[offset].id~=cursor.anchor) then return nil,'CURSOR_STALE' end
    local out,scanned={},0;local families=ns.AthenaStoryIndex and ns.AthenaStoryIndex.families or {}
    while offset<extent and #out<40 and scanned<128 do
        offset=offset+1;scanned=scanned+1;local e=g.character.events[offset];local family=e.details.recordType or e.kind
        if families[family] and G.CanRead(consumer,e) then
            local details={}
            for _,key in ipairs({'momentRef','requestRef','sourceRef','activityRef','sessionRef','category','burstIndex','burstCount','intendedUI','actualUI','captureStatus','encounterID','name','title','questID','objective','fulfilled','required','finished','success','result','resultKnown','accepted',
                'resultMethod','encounterRef','rosterComplete','before','after','delta','beforeLevel','afterLevel','achievementID','alreadyEarned',
                'spellID','slot','itemID','itemName','recipientGUID','playerGUID','hasCurrent','skill','rank','count','level','realm','duelID','opponentGUID','hostile','direction',
                'attackerGUID','targetGUID','entityKind','credit','creatureID','creatureName','classification','firstAt','lastAt','summaryVersion','windowRef','revision','startObserved','closed','phase','healthReadability','minHealthPercent','deaths','selfCredits','petCredits','creditLowerBound','recoveryObserved','lowHealthObserved','endAlive','combatSeconds'}) do
                details[key]=e.details[key]
            end
            for _,key in ipairs(ns.AthenaStoryContributions and ns.AthenaStoryContributions.fields or {}) do details[key]=Copy(e.details[key]) end
            if e.details.members then details.members=Copy(e.details.members) end
            local refs=Contexts(g,offset,e)
            out[#out+1]={evidenceRef=A.EvidenceRef(e.id),sourceRecordRef=e.id,observer=e.character,subjectGUID=e.subject,
                observedAt=e.at,elapsed=e.elapsed,clock=e.timeSource,session=e.session,family=family,source=e.source,details=details,location=Copy(e.location),
                mapID=e.sourceContext and e.sourceContext.mapID,difficultyID=e.sourceContext and e.sourceContext.difficultyID,contexts=refs}
        end
    end
    local checkpoint={owner=g.owner,offset=offset,anchor=offset>0 and g.character.events[offset].id or nil}
    return out,offset<extent and checkpoint or nil,checkpoint
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
for _,key in ipairs({'EvidenceRef','ResolveEvidence','GetHistoryActivities','GetJournalActivities','GetJournalSources','GetHistoryActivity','GetActivityEvidence','GetEvidenceRelationships','GetFirstObservations','GetObservedParticipants','GetObservedSnapshots','GetPersonalRoute','ClearHistoryContext','PumpHistoryContext'}) do ns.WardenDB[key]=A[key] end
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

-- Canonical typed relations are disposable projections of the existing source
-- ledger. Local IDs never become public identity merely through correlation.
local subjects,subjectOrder={},{}
local function SubjectHash(value) return ns.PackCrypto.Hex(ns.PackCrypto.SHA256(value)) end
function G.Subject(kind,key,owner)
 if kind=='CHARACTER' then kind='PLAYER' end
 if kind=='PLAYER' and S.GUID(key) then return {type=kind,key=key,owner=owner,ref='PLAYER/'..key} end
 if kind=='GUILD' and type(key)=='string' and #key<=128 and key:match('^Guild%-[%w%-]+$') then return {type=kind,key=key,owner=owner,ref='GUILD/'..key} end
 if kind=='EVENT' and type(key)=='string' and #key<=128 and key:match('^Event%-[%w%-]+$') then return {type=kind,key=key,owner=owner,ref='EVENT/'..key} end
end
function G.GuildKey(owner,name,realm,source)
 name=S.Text(name,128);realm=S.Text(realm,128)
 if not S.Text(owner,192) or not name or not realm and not S.Text(source,256) then return end
 if not realm then return 'Guild-Candidate-'..SubjectHash(owner..'/'..name..'/'..source):sub(1,40) end
 return 'Guild-Local-'..SubjectHash(owner..'/'..realm..'/'..name):sub(1,40)
end
function G.LocalEvent(st,a)
 if not st or not a or not a.id then return end
 return {type='EVENT',key='Event-Local-'..SubjectHash(st.owner..'/'..a.id):sub(1,40),owner=st.owner,activityID=a.id,
  correlation='LOCAL_ONLY',verified=false,sourceRef=a.anchor,kind=a.kind,startAt=a.startAt,endAt=a.endAt or a.lastAt,
  scope='Local observation; public event not verified'}
end
function G.Registry(owner)
 if not Permit('intel') and not Permit('chronicle') then return nil,'Access unavailable' end
 local c,status=S.Character(owner,false);if not c then S.RequestCharacter(owner);return nil,status end
 local j=subjects[owner]
 if not j or j.character~=c or j.raw~=c.events or j.cursor>#c.events or j.cursor>0 and c.events[j.cursor].id~=j.tail then
  j={owner=owner,character=c,raw=c.events,cursor=0,guilds={},dates={},facts={},objects={},latestRoster=nil,revision=c.revision}
  subjects[owner]=j;subjectOrder[#subjectOrder+1]=owner
  while #subjectOrder>2 do local old=table.remove(subjectOrder,1);if old~=owner then subjects[old]=nil end end
 end
 for n=j.cursor+1,math.min(#c.events,j.cursor+128) do
  local e=c.events[n];local d=e.details or {};local v=e.capture and e.capture.values
  if G.CanRead('intel',e) then
   local guid=e.subject or v and v.guid or owner:match('/(Player%-.+)$')
   if S.GUID(guid) then
    local times=j.dates[guid] or {};j.dates[guid]=times
    local day=math.floor(e.at/86400);times[day]=math.max(times[day] or 0,e.at)
    local facts=j.facts[guid] or {};j.facts[guid]=facts
    if e.kind=='player_observed' or e.kind=='character_snapshot' then
     for _,key in ipairs({'name','realm','race','class','faction','level','guild'}) do
      if d[key]~=nil and (not facts[key] or e.at>=facts[key].at) then facts[key]={value=d[key],at=e.at,source=e.id} end
     end
    end
   end
   local name,realm=d.guildName or d.guild,d.guildRealm or d.realm
   local key=G.GuildKey(owner,name,realm,e.id)
   if key then
    local g=j.guilds[key] or {kind='guild',key=key,owner=owner,identity={name=name,realm=realm},realmUnknown=realm==nil,title=name,provisional=true,
     members={},memberSet={},events={},sources={},rating={count=0,maximum=10},claimed=false,scope='Observed affiliation; provisional local identity',firstAt=e.at,lastAt=e.at}
    j.guilds[key]=g;g.lastAt=math.max(g.lastAt,e.at)
    if #g.sources<128 then g.sources[#g.sources+1]={id=e.id,at=e.at,source=e.source} end
    if S.GUID(guid) then
     local member=g.memberSet[guid]
     if not member then member={key=guid,asOf=e.at,scope='Observed guild association'};g.memberSet[guid]=member;g.members[#g.members+1]=member end
     if e.at>=member.asOf then
      member.asOf=e.at;member.identity=member.identity or {}
      for _,field in ipairs({'name','realm','class','race','level'}) do if d[field]~=nil then member.identity[field]=d[field] end end
     end
    end
   end
   if e.kind=='group_roster' and (not j.latestRoster or e.at>=j.latestRoster.at) then j.latestRoster=e end
   if e.kind=='instance_exit' or e.kind=='recording_stop' or e.kind=='session_end' then j.lastBoundary=math.max(j.lastBoundary or 0,e.at) end
  end
  j.cursor=n;j.tail=e.id
 end
 j.revision=c.revision
 if j.cursor<#c.events then return nil,'INDEXING' end
 return j
end
function G.ResolveGuild(key,owner)
 local j,why=G.Registry(owner);if not j then return nil,why end
 return j.guilds[key],j.guilds[key] and nil or 'Guild source unavailable'
end
function G.PlayerDates(guid,owner)
 local j,why=G.Registry(owner);if not j then return nil,why end
 local rows={};for _,at in pairs(j.dates[guid] or {}) do rows[#rows+1]=at end
 table.sort(rows,function(a,b) return a>b end);return rows
end
function G.Presence(guid,owner,asOf)
 local result={label=asOf and 'Historical view; live activity not projected' or 'Activity unknown',group={},scope='Current group unknown',online='UNKNOWN'}
 if asOf or owner~=C.Owner() then return result end
 local j,why=G.Registry(owner);if not j then result.scope=why or result.scope;return result end
 local now=ns.SafeNumber(ns.SafeCall(GetServerTime)) or 0;local e=j.latestRoster
 if not e or e.at>now+5 or now-e.at>90 or (j.lastBoundary or 0)>=e.at then return result end
 local own=owner:match('/(Player%-.+)$');local known={};for _,id in ipairs(e.details.members or {}) do known[id]=true end
 if not known[guid] or not known[own] then return result end
 -- A recent historical roster alone is insufficient. Recheck this observer's
 -- readable current group membership; no request, inspection or transmission.
 if ns.Checked(ns.SafeCall(IsInGroup))~=true and ns.Checked(ns.SafeCall(IsInRaid))~=true then return result end
 local units={'player'};for n=1,40 do units[#units+1]='raid'..n;if n<=4 then units[#units+1]='party'..n end end
 local visible={};for _,unit in ipairs(units) do local id=S.GUID(ns.SafeCall(UnitGUID,unit));if id then visible[id]=true end end
 if not visible[guid] or not visible[own] then return result end
 for id in pairs(known) do if visible[id] then result.group[#result.group+1]={key=id,owner=owner,title=ns.ChronicleActivities.Name(ns.ChronicleActivities.Peek(owner) or {identities={}},id,e.at)} end end
 table.sort(result.group,function(a,b) return a.key<b.key end)
 result.label=e.location and e.location.inInstance and 'Observed together in '..(e.location.instanceName or e.location.zone or 'an instance') or 'Observed in your current group'
 result.scope='Fresh local roster · partial readable members';result.at=e.at;result.expiresAt=e.at+90;result.source=e.id
 return result
end
-- Date replay reuses the original activity reducers, never the saved latest
-- profiles. It is one bounded, lazy temporal projection, not another archive.
function G.AsOf(owner,at)
 if not Permit('intel') or not S.Integer(at,1,9999999999) then return nil,'Invalid historical date' end
 local c,status=S.Character(owner,false);if not c then return nil,status end
 G.temporal=G.temporal or {};local id=owner..'/'..at;local j=G.temporal[id]
 if not j or j.character~=c or j.revision~=c.revision then
  G.temporal={};j={character=c,revision=c.revision,cursor=0,state=ns.ChronicleActivities.New(owner),at=at};G.temporal[id]=j
  j.state.asOf=at;j.state.athena2={people={},sourceCount=0};j.state.temporalEvents={}
 end
 if j.done then return j.state end
 for n=j.cursor+1,math.min(#c.events,j.cursor+128) do
  local e=c.events[n]
  if e.at<=at and G.CanRead('intel',e) then
   ns.ChronicleActivities.Feed(j.state,e);ns.AthenaProfiles.Feed(j.state,e);j.state.temporalEvents[#j.state.temporalEvents+1]=e
  end
  j.cursor=n
 end
 if j.cursor<#c.events then return nil,'INDEXING' end
 if ns.ChronicleIntelligence and not ns.ChronicleIntelligence.Finish(j.state,128) then return nil,'INDEXING' end
 j.state.athena2.ready=true;j.state.athena2.cursor=#j.state.temporalEvents;j.state.processed=#j.state.temporalEvents;j.done=true
 return j.state
end

function G.EventFor(st,a)
 local localRef=G.LocalEvent(st,a);if not localRef then return end
 local c=ns.AetherNet.Cached();if not c then return localRef end
 local matched
 for _,row in pairs(c.records) do local r=row.record
  if r.kind=='EVENT_FACT' and r.data.sourceRef==localRef.key and not r.removed and not row.conflict
   and c.options.owns(r.origin,'CHARACTER',st.owner:match('/(Player%-.+)$')) then
   local view=c:View('EVENT',r.subjectKey);local event=view and view.event
   if event and event.verified and event.activityType==a.kind and event.startAt<=a.lastAt and (event.endAt or a.lastAt)>=a.startAt then
    if matched and matched.key~=event.key then localRef.correlation='AMBIGUOUS';return localRef end
    matched={type='EVENT',key=event.key,owner=st.owner,activityID=a.id,verified=true,correlation='ATTESTED_SHARED_ID',scope=event.scope}
   end
  end
 end
 return matched or localRef
end
function G.Destination(ref)
 if type(ref)~='table' then return end
 local resolved=G.Subject(ref.type,ref.key,ref.owner);if not resolved then return end
 if resolved.type=='PLAYER' then return {page='intel',kind='player',key=ref.key,owner=ref.owner,asOf=ref.asOf}
 elseif resolved.type=='GUILD' then return {page='intel',kind='guild',key=ref.key,owner=ref.owner}
 elseif resolved.type=='EVENT' then return {page='chronicle',kind='activity',key=ref.activityID or ref.key,owner=ref.owner,eventKey=not ref.activityID and ref.key or nil} end
end
local clearSubjectContext=A.ClearHistoryContext
function A.ClearHistoryContext(...) subjects={};subjectOrder={};G.temporal={};return clearSubjectContext(...) end
