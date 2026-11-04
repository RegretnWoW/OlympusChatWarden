-- Rebuildable references and development state, never a second evidence store.
local _,ns=...
local M=ns.Metis;local R={VERSION=1,MAX_BOOKS=32};M.Memory=R
local function Search(rows,at)
    local lo,hi,best=1,#(rows or {}),nil
    while lo<=hi do local mid=math.floor((lo+hi)/2);if rows[mid].at<at then best=rows[mid];lo=mid+1 else hi=mid-1 end end
    return best
end
R.Before=Search
function R.Build(index)
    local memory={version=R.VERSION,owner=index.owner,quests={},introduced={},cast={},places={},settings={},experiences={},callbacks={},books={},clock=0,
        policy='Permitted source anchors and manuscript ledgers; no chat text or inferred relationships'}
    local owner=index.owner:match('/(Player%-.+)$')
    for i,f in ipairs(index.facts) do
        local d=f.details or {};local row=index.narrative.byRef[f.evidenceRef]
        if row and row.development then memory.introduced[row.development.id]={ref=f.evidenceRef,at=f.observedAt} end
        if row and row.occurrenceId and row.development then
            local q=memory.quests[d.questID] or {};memory.quests[d.questID]=q
            q[#q+1]={at=f.observedAt,ref=f.evidenceRef,occurrence=row.occurrenceId,
                state=f.family=='quest_turnin' and 'RESOLVED' or f.family=='quest_removed' and 'UNRESOLVED_REMOVAL' or 'OPEN'}
        end
        if f.family=='adventure_combat_summary' and f.subjectGUID==owner and row and row.eligibility=='PRIMARY_SCENE'
            and ns.AthenaAdventureEvidence.Valid(d) and d.lowHealthObserved and d.deaths==0 and d.closed and d.endAlive
            and f.location and f.location.zone then
            local zone=f.location.zone;local rows=memory.experiences[zone] or {};memory.experiences[zone]=rows
            rows[#rows+1]={at=f.observedAt,ref=f.evidenceRef,zone=zone}
        end
        M.Tick(index,i)
    end
    -- Recall one earlier close call on a separately supported return. Assignment
    -- is chronological and independent of which volume the reader opens first.
    local used,lastRecall={},-math.huge;local ordinal=0
    for i=#index.nodes,1,-1 do local node=index.nodes[i]
        if node.type~='SAGA' then
            for _,link in ipairs(node.links or {}) do
                if link.kind=='recurring_companion' or link.kind=='recurring_player' then
                    local rows=memory.cast[link.guid] or {};memory.cast[link.guid]=rows
                    rows[#rows+1]={at=node.firstObservedAt,refs=link.refs,storyId=node.storyId,kind=link.kind}
                elseif link.kind=='zone_return' then
                    local rows=memory.places[link.zone] or {};memory.places[link.zone]=rows
                    rows[#rows+1]={at=node.firstObservedAt,refs=link.refs,storyId=node.storyId}
                end
            end
        end
        if node.type~='SAGA' and index.narrative.primaryNodes[node.storyId] then
            ordinal=ordinal+1;local zone=node.place and node.place.zone;local returning=false
            if zone and not memory.settings[zone] then memory.settings[zone]=node.firstObservedAt end
            for _,link in ipairs(node.links or {}) do if link.kind=='zone_return' then returning=true end end
            local prior=zone and Search(memory.experiences[zone],node.firstObservedAt-7200)
            if returning and prior and not used[prior.ref] and ordinal-lastRecall>=3 then
                memory.callbacks[node.storyId]=prior;used[prior.ref]=true;lastRecall=ordinal
            end
        end
        M.Tick(index,i)
    end
    return memory
end
function R.Preferred(index,node)
    local memory=index.metisMemory;local prior=memory and memory.callbacks[node.storyId]
    local refs=prior and {prior.ref} or {}
    for _,ref in ipairs(node.factRefs or {}) do local f=index.byRef[ref]
        if f and f.family=='friend_status' and f.subjectGUID then
            local aliases=index.aliases[f.subjectGUID] or {};local alias
            for _,a in ipairs(aliases) do if a.at<=f.observedAt then alias=a else break end end
            if alias then refs[#refs+1]=alias.ref end
        end
    end
    return refs
end
function R.Claims(story,node,resolved,index,claim)
    for _,c in ipairs(story.factualClaims) do if c.claimType=='verified_friend_status' and c.value.guid then
        local observed=index.byRef[c.evidenceRefs[1]];local alias
        for _,a in ipairs(index.aliases[c.value.guid] or {}) do if observed and a.at<=observed.observedAt then alias=a else break end end
        local source=alias and resolved[alias.ref]
        if source and source.subjectGUID==c.value.guid and source.observer==index.owner then
            c.value.name=ns.AthenaStoryPlanner.Text(source.details.name);c.evidenceRefs[#c.evidenceRefs+1]=alias.ref
        end
    end end
    local memory=index.metisMemory;local prior=memory and memory.callbacks[node.storyId]
    local e=prior and resolved[prior.ref];local current=resolved[node.sourceRef]
    local own=index.owner:match('/(Player%-.+)$');local d=e and e.details
    if e and current and e.observer==index.owner and e.subjectGUID==own and ns.AthenaAdventureEvidence.Valid(d)
        and d.lowHealthObserved and d.deaths==0 and d.closed and d.endAlive and e.observedAt<current.observedAt then
        claim(story,'metis_close_call_callback',{zone=prior.zone,priorAt=prior.at,currentAt=current.observedAt},
            {prior.ref,node.sourceRef},'Earlier readable low health and separately observed return; no shared enemy or causal connection is inferred')
    end
end
function R.ForPlan(plan,index)
    local memory=index and index.metisMemory;local out={introduced={},unresolved={},resolved={},priorSettings={}}
    if not memory then return out end
    local first=plan.novelScenes and plan.novelScenes[1];local at=plan.firstAt or first and first.at or math.huge;local seen={}
    if plan.threadType=='LIFE' then for zone,introducedAt in pairs(memory.settings) do if introducedAt<at then out.priorSettings[zone]=true end end end
    for _,s in ipairs(plan.novelScenes or {}) do for _,c in ipairs(s.claims) do local qid=type(c.value)=='table' and c.value.questID
        if qid and not seen[qid] then seen[qid]=true;local prior=Search(memory.quests[qid],at)
            if prior then out.introduced[qid]=prior;if prior.state=='RESOLVED' then out.resolved[qid]=prior else out.unresolved[qid]=prior end end
        end
    end end
    return out
end
function R.Commit(plan,blocks)
    local memory=plan.index and plan.index.metisMemory;if not memory or #plan.episodes==0 then return end
    M.Check(plan.index);local key=(plan.threadId or 'passage')..'/'..(plan.volumeId or plan.episodes[1].storyId)
    local row={developments={},scenes={},lore={},edition=ns.DB.journalEditions and ns.DB.journalEditions[plan.owner] or 0}
    for _,b in ipairs(blocks) do
        for _,id in ipairs(b.developmentIds or {}) do row.developments[id]=true end
        row.scenes[b.sceneId or b.storyId]=true
        for _,id in ipairs(b.worldRefs or {}) do row.lore[id]=true end
    end
    memory.clock=memory.clock+1;row.used=memory.clock;memory.books[key]=row
    local count=0;for _ in pairs(memory.books) do count=count+1 end
    if count>R.MAX_BOOKS then local oldest,age;for k,v in pairs(memory.books) do if not age or v.used<age then oldest=k;age=v.used end end;memory.books[oldest]=nil end
end
