-- DEV presentation only. Providers read authorized projections; nothing is saved.
local _,ns=...
local J={VERSION=1,MAX_ACTIVITIES=48,MAX_FACTS=256,MAX_SCAN=20000};ns.AthenaJournal=J
local function Copy(v) if type(v)~='table' then return v end;local o={};for k,x in pairs(v) do o[k]=Copy(x) end;return o end
J.Copy=Copy
local function Text(v,fallback) return type(v)=='string' and v:gsub('|',''):sub(1,144) or fallback end
local function Unique(out,seen,ref) if ref and not seen[ref] then seen[ref]=true;out[#out+1]=ref end end
local function Guid(v) return type(v)=='string' and v:match('^Player%-.+') and v end
local function Count(n) return ({'one','two','three','four','five','six','seven','eight','nine','ten','eleven','twelve'})[n] or tostring(n) end
function J.Live()
    local p={demo=false,name='Live history'}
    function p:Allowed() return ns.Athena.Enabled('chronicle') and ns.Membership.LocalHistoryAllowed() end
    function p:Activities(owner,cursor) return ns.Athena.GetHistoryActivities('chronicle',owner,cursor,{limit=12,direction='newest'}) end
    function p:Evidence(owner,ref,cursor) return ns.Athena.GetActivityEvidence('chronicle',owner,ref,cursor,{limit=20}) end
    function p:Resolve(ref) return ns.Athena.ResolveEvidence('chronicle',ref) end
    return p
end
local meaningful={instance_enter=true,instance_exit=true,encounter_started=true,encounter_ended=true,boss_kill_event=true,
    group_roster=true,item_received=true,quest_item_received=true,encounter_loot_delivery=true,collection_gap=true,
    location=true,recording_stop=true,session_start=true,own_spell_success_count=true}
local candidate={RAID_RUN=true,INSTANCE_VISIT=true,ZONE_VISIT=true}
local waiting={INDEXING=true,LOAD_WAIT=true,LINK_PENDING=true,loading=true,pending=true,building=true}
local function Read(job,fn,...)
    while true do
        if not job.provider:Allowed() then error('DENIED') end
        local rows,state=fn(job.provider,...);job.calls=job.calls+1
        if rows then coroutine.yield();return rows,state end
        if waiting[state] then job.status=state;coroutine.yield()
        else error(state or 'UNAVAILABLE') end
    end
end
local function Claim(story,kind,value,refs,qualified)
    local claim={claimId=story.storyId..'/claim/'..(#story.factualClaims+1),claimType=kind,value=value,
        confidence=qualified and 'QUALIFIED' or 'DIRECT',evidenceRefs=Copy(refs),knownCoverage=Copy(story.timeCoverage),disclaimers={}}
    if qualified then claim.disclaimers[1]=qualified;story.supportState='QUALIFIED' end
    story.factualClaims[#story.factualClaims+1]=claim;return claim
end
local function Prose(story,text,claims)
    local block={text=text,claimIds={},evidenceRefs={}};local seen={}
    for _,claim in ipairs(claims) do block.claimIds[#block.claimIds+1]=claim.claimId;for _,ref in ipairs(claim.evidenceRefs) do Unique(block.evidenceRefs,seen,ref) end end
    story.proseBlocks[#story.proseBlocks+1]=block
end
local function Assemble(job,node,facts,partial)
    local owner=job.owner;local place=node.place or {};local name=Text(place.instanceName or place.zone,'an unnamed place')
    local s={storyId='storybook/1/'..owner..'/'..node.activityRef,observerOwner=owner,title=name,
        storyKind=node.type=='RAID_RUN' and 'RAID' or node.type=='ZONE_VISIT' and 'ZONE_RETURN' or 'DUNGEON',
        firstObservedAt=node.firstObservedAt,lastObservedAt=node.lastObservedAt,sourceActivityRefs={node.activityRef},
        sourceEvidenceRefs={},factualClaims={},proseBlocks={},supportState='SUPPORTED',significanceReasons={},storyStatus='UNKNOWN',
        timeCoverage={unknownStart=node.unknownStart,unknownEnd=node.unknownEnd,partial=partial or node.status=='INCOMPLETE',gaps=false},
        narrativeVersion=1,demo=job.provider.demo==true,privacyScope='LOCAL_HISTORY',participants={},encounters={},featured=false,node=Copy(node)}
    local refs={};for _,e in ipairs(facts) do Unique(s.sourceEvidenceRefs,refs,e.evidenceRef) end
    -- Even the place/date statement needs an authorized, resolved original anchor.
    if not refs[node.sourceRef] then s.supportState='INSUFFICIENT';return s end
    local arrival=Claim(s,'observed_place',name,{node.sourceRef},node.unknownStart and 'Arrival was not observed' or nil)
    Prose(s,(node.unknownStart and 'The surviving record finds our journey in ' or 'Our recorded journey led into ')..name..'.',{arrival})
    local active,attempts,byRef,receipts={}, {}, {}, {};local own=node.observerGUID or owner:match('/(Player%-.+)$')
    local rosterSeen,rosterPartial=false,false
    for _,e in ipairs(facts) do
        local d=e.details or {};local r=e.family
        if r=='collection_gap' or r=='recording_stop' then s.timeCoverage.gaps=true end
        if r=='group_roster' then
            if d.rosterComplete==false then rosterPartial=true
            elseif not rosterSeen and type(d.members)=='table' and #d.members>0 then
                rosterSeen=true
                local c=Claim(s,'roster_point_count',#d.members,{e.evidenceRef},'One dated roster point; not continuous attendance')
                Prose(s,'At one recorded muster, the company numbered '..Count(#d.members)..'.',{c})
            end
            for _,v in ipairs(d.members or {}) do local guid=Guid(type(v)=='table' and (v.guid or v.GUID) or v)
                if guid and guid~=own then s.participants[guid]=s.participants[guid] or {guid=guid,ref=e.evidenceRef,at=e.observedAt} end
            end
        elseif r=='encounter_started' and d.encounterID then
            local a={boss=d.encounterID,name=Text(d.name,'Encounter '..d.encounterID),start=e.evidenceRef,at=e.observedAt,refs={e.evidenceRef},outcome='UNKNOWN'}
            attempts[#attempts+1]=a;active[d.encounterID]=a;byRef[e.sourceRecordRef]=a
        elseif r=='encounter_ended' and d.encounterID then
            local link=d.encounterRef or e.sourceContext and e.sourceContext.encounterRef
            local a=link and byRef[link] or not link and active[d.encounterID]
            if not a or a.boss~=d.encounterID then a={boss=d.encounterID,name=Text(d.name,'Encounter '..d.encounterID),at=e.observedAt,refs={},outcome='UNKNOWN'};attempts[#attempts+1]=a end
            local outcome=d.success==1 and 'SUCCESS' or d.success==0 and 'FAILURE' or 'UNKNOWN'
            if a.outcome=='CONFLICTING' or a.result and a.result~=outcome then a.outcome='CONFLICTING' else a.outcome=outcome end
            a.result=outcome;a.refs[#a.refs+1]=e.evidenceRef
            -- A linked late/conflicting result reuses its attempt; separate start anchors stay distinct.
            if link then byRef[link]=a end
        elseif r=='boss_kill_event' and d.encounterID then
            local a=active[d.encounterID]
            -- A duplicate BOSS_KILL after ENCOUNTER_END is corroboration, not
            -- another attempt. A standalone delivered kill remains useful.
            if not a then a={boss=d.encounterID,name=Text(d.name,'Encounter '..d.encounterID),at=e.observedAt,refs={},outcome='UNKNOWN'};attempts[#attempts+1]=a;active[d.encounterID]=a end
            if a.outcome=='FAILURE' or a.outcome=='CONFLICTING' then a.outcome='CONFLICTING' else a.outcome='SUCCESS' end
            a.refs[#a.refs+1]=e.evidenceRef
        elseif r=='item_received' or r=='quest_item_received' or r=='encounter_loot_delivery' then
            local recipient=d.recipientGUID or d.playerGUID or e.subjectGUID
            local selfReceipt=recipient==own or r=='quest_item_received' and e.source=='QUEST_LOOT_RECEIVED'
            if selfReceipt and d.itemID then
                local item=Text(d.itemName,'item '..d.itemID)
                local c=Claim(s,'owner_item_receipt',{itemID=d.itemID,name=item},{e.evidenceRef},'Observed during this activity; boss-drop origin is not established')
                receipts[#receipts+1]={item=item,claim=c}
            end
        elseif r=='own_spell_success_count' and e.subjectGUID==own and type(d.count)=='number' and d.count>0 and d.spellID then
            -- Aggregate bins do not establish spell order, damage or a rotation.
            s.spells=s.spells or {};local v=s.spells[d.spellID] or {count=0,refs={}};s.spells[d.spellID]=v;v.count=v.count+d.count;v.refs[#v.refs+1]=e.evidenceRef
        end
    end
    local bosses={};for _,a in ipairs(attempts) do local b=bosses[a.boss] or {id=a.boss,name=a.name,attempts={},refs={},failures=0,successes=0,unknown=0};bosses[a.boss]=b
        b.attempts[#b.attempts+1]=a;for _,ref in ipairs(a.refs) do b.refs[#b.refs+1]=ref end
        if a.outcome=='FAILURE' then b.failures=b.failures+1 elseif a.outcome=='SUCCESS' then b.successes=b.successes+1 else b.unknown=b.unknown+1 end
    end
    local ids={};for id in pairs(bosses) do ids[#ids+1]=id end;table.sort(ids)
    local wins,losses,unknown=0,0,0
    for _,id in ipairs(ids) do local b=bosses[id];s.encounters[id]=b;wins=wins+b.successes;losses=losses+b.failures;unknown=unknown+b.unknown
        if b.failures>0 then local c=Claim(s,'confirmed_failed_attempts',{boss=id,count=b.failures},b.refs)
            Prose(s,'Against '..b.name..', '..Count(b.failures)..(b.failures==1 and ' recorded attempt ended' or ' recorded attempts ended')..' in defeat.',{c}) end
        if b.successes>0 then local c=Claim(s,'confirmed_success',{boss=id,count=b.successes},b.refs)
            local ordinal=not partial and b.unknown==0 and b.successes==1 and b.attempts[#b.attempts].outcome=='SUCCESS' and #b.attempts or nil
            local position=({[1]='first',[2]='second',[3]='third'})[ordinal]
            Prose(s,ordinal and (position and 'On our '..position..' recorded attempt, ' or 'On recorded attempt '..ordinal..', ')..b.name..' fell.' or ('A victory over '..b.name..' stands in the record.'),{c}) end
        if b.unknown>0 then local c=Claim(s,'uncertain_outcome',{boss=id,count=b.unknown},b.refs,'Missing or conflicting native outcomes')
            Prose(s,'Other recorded attempts have missing or conflicting conclusions.',{c}) end
    end
    for _,receipt in ipairs(receipts) do Prose(s,'During the expedition, '..receipt.item..' came into my possession. Its origin is not established here.',{receipt.claim}) end
    if rosterPartial then local rs={};for _,e in ipairs(facts) do if e.family=='group_roster' and e.details.rosterComplete==false then rs[#rs+1]=e.evidenceRef end end
        local c=Claim(s,'partial_roster',true,rs,'Unreadable membership is not a disband')
        Prose(s,'Part of the company roster could not be read; those passages cannot establish who remained.',{c}) end
    if wins>0 then s.storyStatus=unknown>0 and 'INCOMPLETE' or 'SUCCESS';s.featured=true;s.significanceReasons[1]='Verified encounter victory'
    elseif losses>0 then s.storyStatus=unknown>0 and 'INCOMPLETE' or 'FAILURE';s.featured=s.storyKind=='RAID';s.significanceReasons[1]=s.featured and 'Recorded raid progression' or 'History only: dungeon without recorded victory'
    else s.storyStatus=s.storyKind=='ZONE_RETURN' and 'UNKNOWN' or 'INCOMPLETE' end
    if s.timeCoverage.partial or node.unknownStart or node.unknownEnd then s.storyStatus='INCOMPLETE' end
    if wins==0 and s.storyKind=='RAID' then local c=Claim(s,'no_recorded_victory',true,s.sourceEvidenceRefs,'Only the permitted reviewed source window is known')
        Prose(s,'No victory was recorded in the reviewed passages of this expedition.',{c}) end
    local spellID,spell
    for id,v in pairs(s.spells or {}) do if not spell or v.count>spell.count or v.count==spell.count and id<spellID then spellID,spell=id,v end end
    if spell then local c=Claim(s,'own_spell_frequency',{spellID=spellID,count=spell.count},spell.refs,'Observed successful-cast samples; not damage or rotation order')
        Prose(s,'Among the retained spell samples, spell '..spellID..' was recorded succeeding '..spell.count..' times. The order of those casts is not reconstructed.',{c}) end
    if s.timeCoverage.partial or s.timeCoverage.gaps or node.unknownStart or node.unknownEnd then s.supportState='QUALIFIED' end
    if s.timeCoverage.gaps then local c=Claim(s,'coverage_gaps',true,s.sourceEvidenceRefs,'Continuous play is not established')
        local hours=(tonumber(s.lastObservedAt) or 0)-(tonumber(s.firstObservedAt) or 0)
        Prose(s,(hours>=3600 and string.format('These observations span %.1f hours, with gaps in the record.',hours/3600) or 'There are gaps in the record.')..' They do not establish uninterrupted play.',{c}) end
    for _,c in ipairs(s.factualClaims) do c.knownCoverage=Copy(s.timeCoverage) end
    return s
end
local function Callbacks(job)
    local bosses,companions,zones={},{},{}
    -- Oldest first: callbacks never turn separate source activities into one run.
    table.sort(job.stories,function(a,b) return a.firstObservedAt<b.firstObservedAt or a.firstObservedAt==b.firstObservedAt and a.storyId<b.storyId end)
    for _,s in ipairs(job.stories) do
        for id,b in pairs(s.encounters) do local prior=bosses[id]
            if prior and prior.failures>0 and b.successes>0 then
                local rr={};for _,v in ipairs(prior.refs) do rr[#rr+1]=v end;for _,v in ipairs(b.refs) do rr[#rr+1]=v end
                local c=Claim(s,'later_victory',{boss=id,priorStory=prior.story},rr,'Separate expeditions; same company is not established')
                Prose(s,'An earlier expedition recorded defeats against this foe. A later chapter now records victory, with no claim that the same company returned.',{c})
            end
            if b.failures>0 then bosses[id]={failures=b.failures,refs=b.refs,story=s.storyId} end
        end
        local guids={};for guid in pairs(s.participants) do guids[#guids+1]=guid end;table.sort(guids)
        for _,guid in ipairs(guids) do local p=s.participants[guid];local old=companions[guid]
            if old and old.story~=s.storyId then local c=Claim(s,'recurring_companion',{guid=guid,priorStory=old.story},{old.ref,p.ref},'Dated roster associations, not continuous attendance or friendship')
                Prose(s,'A familiar companion appears again in a dated company roster.',{c});break end
        end
        for guid,p in pairs(s.participants) do companions[guid]={story=s.storyId,ref=p.ref} end
        if s.storyKind=='ZONE_RETURN' then local key=s.node.zoneKey;local old=key and zones[key]
            if old and old.story~=s.storyId then local c=Claim(s,'zone_return',{zone=key,priorStory=old.story},{old.ref,s.node.sourceRef},'Distinct recorded visits; routes and unseen intervals are not reconstructed')
                Prose(s,'The road brought the record back to '..Text(s.node.place and s.node.place.zone,'these shores')..', a place seen in an earlier chapter.',{c})
                s.featured=true;s.significanceReasons[1]='Return to a recorded place'
            end
            if key then zones[key]={story=s.storyId,ref=s.node.sourceRef} end
        end
        for _,claim in ipairs(s.factualClaims) do for _,ref in ipairs(claim.evidenceRefs) do local present=false;for _,r in ipairs(s.sourceEvidenceRefs) do if r==ref then present=true;break end end;if not present then s.sourceEvidenceRefs[#s.sourceEvidenceRefs+1]=ref end end end
        coroutine.yield()
    end
    table.sort(job.stories,function(a,b) return a.firstObservedAt>b.firstObservedAt or a.firstObservedAt==b.firstObservedAt and a.storyId<b.storyId end)
end
function J.New(provider,owner,cursor)
    local job={provider=provider,owner=owner,cursor=cursor,status='INDEXING',stories={},calls=0,resolved=0,restarts=0}
    local function Work()
        local nodes,seen={},{};local nextCursor=job.cursor
        repeat
            local rows,nextPage=Read(job,provider.Activities,owner,nextCursor);nextCursor=nextPage
            for _,n in ipairs(rows) do
                if n.observer==owner and candidate[n.type] and n.accessScope~='PRIVATE_INCIDENT' and not seen[n.activityRef] then nodes[#nodes+1]=n;seen[n.activityRef]=true end
            end
            job.activitiesRead=(job.activitiesRead or 0)+#rows
        until not nextCursor or job.activitiesRead>=J.MAX_ACTIVITIES
        job.nextCursor=nextCursor
        for _,n in ipairs(nodes) do
            local facts,used={},{};local cursor,scanned=nil,0;local partial=false
            repeat
                local rows,nextPage=Read(job,provider.Evidence,owner,n.activityRef,cursor);cursor=nextPage;scanned=scanned+512
                for _,row in ipairs(rows) do
                    if meaningful[row.family] and not used[row.evidenceRef] and #facts<J.MAX_FACTS then
                        local e,state=Read(job,provider.Resolve,row.evidenceRef)
                        if e.observer==owner and e.evidenceRef==row.evidenceRef and not (e.sourceContext and e.sourceContext.accessScope=='PRIVATE_INCIDENT') and e.accessScope~='PRIVATE_INCIDENT' then
                            used[row.evidenceRef]=true;e.family=row.family;facts[#facts+1]=e;job.resolved=job.resolved+1
                        end
                    elseif #facts>=J.MAX_FACTS then partial=true end
                end
            until not cursor or scanned>=J.MAX_SCAN
            partial=partial or cursor~=nil
            table.sort(facts,function(a,b) return a.observedAt<b.observedAt or a.observedAt==b.observedAt and a.evidenceRef<b.evidenceRef end)
            job.stories[#job.stories+1]=Assemble(job,n,facts,partial);coroutine.yield()
        end
        Callbacks(job);job.done=true;job.status='READY'
    end
    job.work=Work;job.thread=coroutine.create(Work);return job
end
function J.Pump(job)
    if not job.provider:Allowed() then job.stories={};job.done=true;job.status='DENIED';return job.status end
    if job.done then return job.status end
    if InCombatLockdown and InCombatLockdown() then job.status='COMBAT_WAIT';return job.status end
    local ok,why=coroutine.resume(job.thread)
    if not ok then
        job.error=tostring(why)
        local state=tostring(why):match('([A-Z_]+)$') or 'UNAVAILABLE'
        if state=='CURSOR_STALE' and job.restarts<3 then
            job.restarts=job.restarts+1;job.stories={};job.activitiesRead=0;job.cursor=nil;job.thread=coroutine.create(job.work);job.status='INDEXING'
        else job.stories={};job.done=true;job.status=state end
    end
    return job.status
end
function J.Featured(job) local out={};for _,s in ipairs(job.stories) do if s.featured then out[#out+1]=s end end;return out end
