-- Rebuildable literary projection. Never writes to canonical history or consent.
local _,ns=...
local D={VERSION=14};ns.AthenaNarrativeScenes=D
local primary={quest_accepted=true,quest_turnin=true,encounter_started=true,encounter_ended=true,boss_kill_event=true,
    level_change=true,achievement_earned=true,duel_session_start=true,duel_session_result=true,match_observed=true,pvp_match_complete=true,player_combat=true}
local context={guild_member_observed=true,group_roster=true,friend_status=true,guild_affiliation=true,signal_sighting=true,
    quest_observed=true,quest_removed=true,quest_objective=true,location=true,instance_enter=true,instance_exit=true,
    skill_change=true,equipment_change=true,spell_learned=true,item_received=true,quest_item_received=true,encounter_loot_delivery=true}
local function Key(...) local o={};for i=1,select('#',...) do local v=tostring(select(i,...));o[#o+1]=#v..':'..v end;return table.concat(o,'/') end
D.Key=Key
local function Tick(index,i) if i%64==0 then if not index.provider:Allowed() then error('DENIED') end;coroutine.yield() end end
function D.Classify(f,owner)
    local k,d=f.family,f.details or {};local own=owner:match('/(Player%-.+)$')
    if f.storyPrivateProjection or k=='historical_incident' or k=='incident_correction' then return 'EVIDENCE_ONLY','Private operational evidence' end
    if k:match('^quest_') or k=='level_change' or k=='achievement_earned' then
        if f.subjectGUID and f.subjectGUID~=own then return 'EVIDENCE_ONLY','Not the owner’s development' end
    end
    if k=='adventure_combat_summary' then
        if f.subjectGUID==own and ns.AthenaAdventureEvidence.Valid(d) and (d.lowHealthObserved or d.deaths>0) then return 'PRIMARY_SCENE','Source-backed own close call or death' end
        return 'SUPPORTING_CONTEXT','Routine compact combat window'
    end
    if k=='player_death' and (not f.subjectGUID or f.subjectGUID==own) then return 'PRIMARY_SCENE','Own native death' end
    if k=='quest_objective' then return 'SUPPORTING_CONTEXT','Objective state requires occurrence/change comparison' end
    if k=='instance_enter' and f.location and f.location.inInstance==true then return 'PRIMARY_SCENE','Verified entry into an activity' end
    if k=='guild_affiliation' and (not f.subjectGUID or f.subjectGUID==own) and d.baseline~=true and type(d.after)=='boolean' then
        return 'PRIMARY_SCENE','Verified owner affiliation transition'
    end
    if k=='friend_status' and d.baseline~=true and type(d.after)=='boolean' and d.before~=d.after then return 'PRIMARY_SCENE','Verified friend-list transition; not an emotional relationship' end
    if primary[k] then
        if k=='level_change' and (type(d.before)~='number' or type(d.after)~='number' or d.after<=d.before) then return 'SUPPORTING_CONTEXT','No advancement' end
        if k=='achievement_earned' and d.alreadyEarned then return 'SUPPORTING_CONTEXT','Already known achievement' end
        if k=='player_combat' and (d.hostile~=true or f.location.inInstance~=false) then return 'EVIDENCE_ONLY','Not a verified outdoor hostile encounter' end
        return 'PRIMARY_SCENE','Substantive observed development'
    end
    return context[k] and 'SUPPORTING_CONTEXT' or 'EVIDENCE_ONLY','Not an independent literary scene'
end
function D.Build(index)
    local o={version=D.VERSION,owner=index.owner,byRef={},occurrences={},developments={},primaryNodes={},chapterKeys={},chapters={},chapterOrder={},
        stats={PRIMARY_SCENE=0,SUPPORTING_CONTEXT=0,EVIDENCE_ONLY=0,originals=#index.facts}}
    local active,guildState={},nil;local combatLatest={};local credits={};local creditRefs={};local creditSeen={}
    for i,f in ipairs(index.facts) do local d=f.details or {};if f.family=='adventure_combat_summary' and f.subjectGUID==index.owner:match('/(Player%-.+)$') and ns.AthenaAdventureEvidence.Valid(d) then local old=combatLatest[d.windowRef];if not old or d.revision>old.details.revision then combatLatest[d.windowRef]=f end end;Tick(index,i) end
    for i,f in ipairs(index.facts) do
        local k,d=f.family,f.details or {};local class,reason=D.Classify(f,index.owner);local occurrence
        if k=='adventure_combat_summary' and combatLatest[d.windowRef]~=f then class='SUPPORTING_CONTEXT';reason='Earlier checkpoint of the same combat window' end
        if f.primary and ns.AthenaWorldScenes.OwnerKill(f,index.owner) then
            local key=f.primary..'/'..d.targetGUID
            if not creditSeen[key] then creditSeen[key]=true;credits[f.primary]=(credits[f.primary] or 0)+1;creditRefs[f.primary]=f end
        end
        if k:match('^quest_') and k~='quest_item_received' and d.questID and (not f.subjectGUID or f.subjectGUID==index.owner:match('/(Player%-.+)$')) then
            local q=active[d.questID]
            if not q or q.closed and (k=='quest_accepted' or k=='quest_turnin') then
                local id=Key(index.owner,'quest',d.questID,f.evidenceRef)
                q={id=id,questID=d.questID,anchor=f.evidenceRef,firstAt=f.observedAt,states={},values={},developments={},unknownStart=k~='quest_accepted'}
                active[d.questID]=q;o.occurrences[id]=q
            end
            occurrence=q.id
            if k=='quest_accepted' then
                if q.accepted then class='SUPPORTING_CONTEXT';reason='Repeated acceptance in an unbroken occurrence' else q.accepted=f.evidenceRef;q.unknownStart=false end
            elseif k=='quest_objective' then
                local slot=Key(d.objective or d.objectiveID or 'unknown')
                local state=Key(d.fulfilled,d.required,d.finished,d.objectiveState)
                local previous=q.values[slot]
                if not q.closed and q.states[slot]~=state and (d.finished==true or type(d.fulfilled)=='number' and d.fulfilled>0)
                    and (not previous or not d.fulfilled or d.fulfilled>=previous) then class='PRIMARY_SCENE';reason='Changed objective state; not a turn-in' end
                q.states[slot]=state;q.values[slot]=d.fulfilled
            elseif k=='quest_turnin' then q.closed=true;q.turnedIn=f.evidenceRef
            elseif k=='quest_removed' then q.closed=true;q.removed=f.evidenceRef end
            -- All repeated observations retain their original refs in the source index.
            if class=='PRIMARY_SCENE' or k=='quest_removed' then
                o.byRef[f.evidenceRef]={occurrenceId=occurrence,eligibility=class,reason=reason}
            end
        end
        if k=='guild_affiliation' then
            local state=Key(d.after,d.guildName,d.guildRealm)
            if guildState==state then class='SUPPORTING_CONTEXT';reason='Unchanged affiliation' end
            guildState=state
        end
        if class=='PRIMARY_SCENE' then
            local id=Key(index.owner,occurrence or f.primary or f.evidenceRef,k, f.evidenceRef)
            local dev={id=id,occurrenceId=occurrence,kind=k,at=f.observedAt,sourceRef=f.evidenceRef,primaryStory=f.primary and ns.AthenaStoryIndex.StoryID(index.owner,f.primary)}
            o.developments[#o.developments+1]=dev
            local row=o.byRef[f.evidenceRef] or {};o.byRef[f.evidenceRef]=row;row.development=dev;row.eligibility=class;row.reason=reason
            if occurrence then local q=o.occurrences[occurrence];q.developments[#q.developments+1]=dev;q.lastAt=f.observedAt end
            if dev.primaryStory then o.primaryNodes[dev.primaryStory]=true end
        end
        o.stats[class]=o.stats[class]+1;Tick(index,i)
    end
    -- A substantial stretch of creature credits is one optional interlude, never
    -- one paragraph per kill. Five trivial credits cannot create a chapter.
    for activity,count in pairs(credits) do if count>=10 then local f=creditRefs[activity];local node=index.byActivity[activity]
        if node then
            local dev={id=Key(index.owner,'field-credits',activity),kind='native_credit_stretch',at=f.observedAt,sourceRef=f.evidenceRef,primaryStory=node.storyId}
            o.developments[#o.developments+1]=dev;o.primaryNodes[node.storyId]=true
            o.byRef[f.evidenceRef]={development=dev,eligibility='PRIMARY_SCENE',reason='One grouped stretch of distinct source credit'}
        end
    end end
    -- Temporal visits are independent of quest identity. Taking up an errand,
    -- entering a dungeon and returning to finish it are three reading beats;
    -- the later turn-in must not be pulled ahead of the intervening adventure.
    local beat,lastContext,lastSession,lastClock,lastAt=0,nil,nil,nil,nil
    local barriers={session_start=true,session_end=true,collection_gap=true,recording_started=true,recording_stopped=true,instance_enter=true,instance_exit=true}
    local majorTypes={RAID_RUN=true,INSTANCE_VISIT=true,BATTLEGROUND_MATCH=true,BATTLEGROUND_VISIT=true,DUEL=true,WORLD_PVP=true}
    o.beats={}
    for i,f in ipairs(index.facts) do
        local n=f.primary and index.byActivity[f.primary];local place=f.location or {}
        -- A bare outside/inside flag is not a new place. Incidental records
        -- may omit the zone; that absence must not invent a departure/return.
        local ctx=n and majorTypes[n.type] and Key(n.type,n.activityRef or f.primary) or (place.zone or place.instanceID) and Key(place.inInstance==true,place.instanceID,place.zone) or lastContext
        if beat==0 or ctx~=lastContext or f.session and lastSession and f.session~=lastSession or f.clock and lastClock and f.clock~=lastClock or barriers[f.family]
            or lastAt and f.observedAt-lastAt>1800 then beat=beat+1;o.beats[beat]={at=f.observedAt,sourceRef=f.evidenceRef} end
        local row=o.byRef[f.evidenceRef]
        if row then row.beat=beat end
        lastContext,lastSession,lastClock,lastAt=ctx,f.session or lastSession,f.clock or lastClock,f.observedAt
        Tick(index,i)
    end
    -- Chapter breaks describe substantial activity/region/session changes, not
    -- six callbacks. A display window can continue an existing chapter.
    local chapter,priorGroup
    local ordered={};for i=#index.nodes,1,-1 do ordered[#ordered+1]=index.nodes[i] end
    for i,n in ipairs(ordered) do if o.primaryNodes[n.storyId] and n.type~='SAGA' and not n.suppressed then
        local place=n.place or {}
        local anchor=index.byRef[n.sourceRef];local major=({RAID_RUN=true,INSTANCE_VISIT=true,BATTLEGROUND_MATCH=true,BATTLEGROUND_VISIT=true,DUEL=true,WORLD_PVP=true})[n.type]
        local group=major and Key(n.type,place.instanceID or n.zoneKey or place.zone,place.difficultyID) or Key(n.zoneKey or n.mapID or place.zone,anchor and anchor.session or 'undated')
        if group~=priorGroup then
            local title=place.instanceName or place.subzone or place.zone or 'An unfolding life'
            -- In-world contents use the observed setting, never a quest's UI
            -- label. The exact label remains available through Sources.
            for _,ref in ipairs(not major and n.factRefs or {}) do local f=index.byRef[ref];local d=f and f.details or {}
                if f and f.family=='guild_affiliation' then title='A change of allegiance' end
            end
            chapter={id=Key(index.owner,'chapter',n.sourceRef),firstStory=n.storyId,at=n.firstObservedAt,title=ns.AthenaStoryPlanner.Text(title,'An unfolding life')}
            o.chapters[chapter.id]=chapter;o.chapterOrder[#o.chapterOrder+1]=chapter.id;priorGroup=group
        end
        o.chapterKeys[n.storyId]=chapter
    end;Tick(index,i) end
    -- One eligible own protection action can color an already substantive
    -- passage. Its time establishes coexistence, never motive or an offender.
    o.contextByStory={};local activeNode,atNode,usedChapter=nil,1,{}
    for i,f in ipairs(index.facts) do
        while ordered[atNode] and ordered[atNode].firstObservedAt<=f.observedAt do
            local n=ordered[atNode];if o.primaryNodes[n.storyId] and not n.suppressed and n.type~='SAGA' then activeNode=n end;atNode=atNode+1
        end
        local d=f.details or {};local chapter=activeNode and o.chapterKeys[activeNode.storyId]
        if f.storyPrivateProjection and f.family=='historical_incident' and d.ownerModule=='shield' and d.method=='own protection action'
            and (d.activeSourceCount or 0)>0 and (d.correctedDependencyCount or 0)==0 and activeNode and chapter
            and not usedChapter[chapter.id] and f.observedAt<=activeNode.lastObservedAt then
            o.contextByStory[activeNode.storyId]={f.evidenceRef};usedChapter[chapter.id]=true
        end
        Tick(index,i)
    end
    index.narrative=o;return o
end
function D.Admit(index,node)
    local o=index.narrative;return o and o.primaryNodes[node.storyId]==true
end
function D.Preferred(index,node)
    local out,seen={},{};local function Add(ref) if ref and not seen[ref] then seen[ref]=true;out[#out+1]=ref end end
    for _,ref in ipairs(index.narrative.contextByStory[node.storyId] or {}) do Add(ref) end
    -- Preserve latest summary/credit proofs ahead of incidental bounded context.
    local windows={};local kills={}
    for _,ref in ipairs(node.factRefs) do local f=index.byRef[ref];local d=f.details or {}
        if f.family=='adventure_combat_summary' then local old=windows[d.windowRef];if not old or d.revision>old.details.revision then windows[d.windowRef]=f end
        elseif ns.AthenaWorldScenes.OwnerKill(f,index.owner) and not kills[d.targetGUID] then kills[d.targetGUID]=f end
    end
    local combatRefs={};for _,f in pairs(windows) do combatRefs[#combatRefs+1]=f.evidenceRef end;for _,f in pairs(kills) do combatRefs[#combatRefs+1]=f.evidenceRef end
    table.sort(combatRefs);for i,ref in ipairs(combatRefs) do if i<=32 then Add(ref) end end
    -- Two ends plus a representative actual change survive a noisy bounded read.
    for _,ref in ipairs(node.factRefs) do local r=index.narrative and index.narrative.byRef[ref];if r and r.development then
        local k=r.development.kind;if k~='quest_objective' then Add(ref) end
    end end
    local last={};for _,ref in ipairs(node.factRefs) do local r=index.narrative and index.narrative.byRef[ref];if r and r.development and r.development.kind=='quest_objective' then last[r.occurrenceId]=ref end end
    local ordered={};for _,ref in pairs(last) do ordered[#ordered+1]=ref end;table.sort(ordered);for _,ref in ipairs(ordered) do Add(ref) end
    return out
end
local questKinds={owner_quest_accepted=true,owner_quest_turnin=true,owner_quest_objective=true,owner_quest_observed=true,owner_quest_removed=true}
local activityKinds={DUNGEON=true,RAID=true,DUEL=true,WORLD_PVP=true,BATTLEGROUND=true,SAGA=true}
function D.Plan(plan,index)
    local scenes,byKey,seen={}, {},{};local projection=index and index.narrative
    local function Add(s,kind,key,c,at,occurrence)
        local chapter=projection and projection.chapterKeys[s.storyId]
        local ck=chapter and chapter.id or s.storyId
        key=Key(ck,kind,key)
        local v=byKey[key]
        if not v then v={sceneId=Key(plan.owner or s.observerOwner,'scene',key),chapterId=ck,chapterAt=chapter and chapter.at or s.firstObservedAt,
            focus=kind,story=s,stories={},storySet={},claims={},claimSet={},at=at or s.firstObservedAt,lastAt=at or s.lastObservedAt,
            sourceEvidenceRefs={},sourceSet={},occurrenceId=occurrence,primaryDevelopmentIds={}};byKey[key]=v;scenes[#scenes+1]=v end
        if not v.storySet[s.storyId] then v.storySet[s.storyId]=true;v.stories[#v.stories+1]=s end
        if c and not v.claimSet[c.claimId] then
            v.claimSet[c.claimId]=true;v.claims[#v.claims+1]=c
            for _,ref in ipairs(c.evidenceRefs or {}) do if not v.sourceSet[ref] then v.sourceSet[ref]=true;v.sourceEvidenceRefs[#v.sourceEvidenceRefs+1]=ref end end
            v.lastAt=math.max(v.lastAt,at or s.lastObservedAt)
        end
        return v
    end
    for _,s in ipairs(plan.episodes or {}) do
        local activity=activityKinds[s.storyKind];local av
        if activity then av=Add(s,'ACTIVITY',s.node.activityRef,nil,s.firstObservedAt) end
        for _,c in ipairs(s.factualClaims) do
            local ref=c.evidenceRefs and c.evidenceRefs[1];local f=index and index.byRef[ref];local row=projection and projection.byRef[ref]
            -- An earlier quest acceptance supports context at this arrival;
            -- it must not become another primary acceptance development.
            if c.claimType=='quest_expedition_context' then f=nil;row=nil end
            if c.claimType=='owner_creature_credits' and projection then for _,r in ipairs(c.evidenceRefs) do local candidate=projection.byRef[r];if candidate and candidate.development then row=candidate;break end end end
            local at=f and f.observedAt or c.claimType=='private_conversation_observed' and c.value.observedFrom or s.firstObservedAt;local dev=row and row.development
            local id=c.claimType=='private_conversation_observed' and ('memory/'..c.value.momentRef) or dev and dev.id or c.claimId
            if not seen[id] then
                local v
                if questKinds[c.claimType] then
                    local occurrence=row and row.occurrenceId or Key(s.storyId,c.value.questID)
                    if not projection or row and (row.eligibility=='PRIMARY_SCENE' or c.claimType=='owner_quest_removed') then
                        -- A quest may occur within an expedition, but remains a
                        -- subject of its own, never a source of invented boss facts.
                        v=Add(s,'QUEST',Key(occurrence,row and row.beat or 'undated'),c,at,occurrence)
                        v.beat=row and row.beat
                    end
                elseif activity and (c.claimType=='observed_place' or c.claimType=='encounter_attempt' or c.claimType=='owner_duel_result'
                    or c.claimType=='match_observed' or c.claimType=='match_ended' or c.claimType=='owner_world_pvp' or c.claimType=='roster_point_count'
                    or c.claimType=='guild_company' or c.claimType=='recurring_companion' or c.claimType=='later_victory' or c.claimType=='owner_item_receipt' or c.claimType=='quest_expedition_context') then
                    v=Add(s,'ACTIVITY',s.node.activityRef,c,at)
                elseif c.claimType=='owner_combat_experience' or c.claimType=='owner_recorded_death' or c.claimType=='owner_creature_credits' then
                    v=Add(s,activity and 'ACTIVITY' or 'INTERLUDE',activity and s.node.activityRef or s.storyId,c,at)
                elseif c.claimType=='owner_level_change' or c.claimType=='owner_achievement' then
                    v=Add(s,'MILESTONE',s.node.activityRef,c,at)
                elseif (c.claimType=='own_guild_affiliation' or c.claimType=='verified_friend_status') and c.value.baseline~=true and (not projection or dev) then
                    v=Add(s,'AFFILIATION',id,c,at)
                elseif c.claimType=='private_conversation_observed' then
                    v=Add(s,'MEMORY',c.value.momentRef,c,at)
                end
                if v then seen[id]=true;if dev then v.primaryDevelopmentIds[#v.primaryDevelopmentIds+1]=id end end
            end
        end
    end
    table.sort(scenes,function(a,b) return a.at<b.at or a.at==b.at and a.sceneId<b.sceneId end)
    local beforeEncounter={}
    for _,v in ipairs(scenes) do if v.focus=='MEMORY' then
        for _,a in ipairs(scenes) do if a.focus=='ACTIVITY' and a.storySet[v.story.storyId] then
            local first
            for _,c in ipairs(a.claims) do if c.claimType=='encounter_attempt' and (not first or c.value.at<first) then first=c.value.at end end
            if first and v.at<first then
                a.preEncounterMemories=a.preEncounterMemories or {};a.preEncounterMemories[#a.preEncounterMemories+1]=v;beforeEncounter[v]=true;break
            end
        end end
    end end
    -- Growth can enrich a substantive scene from the same observed segment;
    -- proximity alone never joins unrelated activities or claims causation.
    local edited={};local recent
    for _,v in ipairs(scenes) do
        if beforeEncounter[v] then -- Authored between the arrival and encounter beats.
        elseif v.focus=='MILESTONE' and recent and recent.chapterId==v.chapterId and recent.storySet[v.story.storyId] then
            for _,c in ipairs(v.claims) do recent.claims[#recent.claims+1]=c end
            for _,id in ipairs(v.primaryDevelopmentIds) do recent.primaryDevelopmentIds[#recent.primaryDevelopmentIds+1]=id end
            recent.growth=v.claims
        else edited[#edited+1]=v;if v.focus=='QUEST' or v.focus=='ACTIVITY' then recent=v end end
    end
    scenes=edited
    for _,v in ipairs(scenes) do if v.focus=='QUEST' then
        local id=v.claims[1] and v.claims[1].value.questID
        for _,s in ipairs(v.stories) do for _,c in ipairs(s.factualClaims) do if c.claimType=='quest_reference_connection' and c.value.questID==id and not v.claimSet[c.claimId] then
            v.claimSet[c.claimId]=true;v.claims[#v.claims+1]=c
        end end end
    end end
    local protectionUsed={}
    for _,v in ipairs(scenes) do if v.focus=='QUEST' or v.focus=='ACTIVITY' then
        for _,s in ipairs(v.stories) do for _,c in ipairs(s.factualClaims) do if c.claimType=='private_protection' and c.value.module=='shield' and not c.value.corrected and not protectionUsed[c.claimId] then
            v.ownProtection=c;protectionUsed[c.claimId]=true
        end end end
    end end
    -- Experiences enrich the existing quest scene from their shared source
    -- segment. Temporal co-presence is never claimed to prove quest causation.
    local retained={}
    for _,v in ipairs(scenes) do
        local target
        if v.focus=='INTERLUDE' then
            for _,q in ipairs(scenes) do if q.focus=='QUEST' and q.chapterId==v.chapterId and q.storySet[v.story.storyId]
                and q.at<=v.lastAt and (not target or q.at>target.at) then target=q end end
        end
        if target then
            for _,c in ipairs(v.claims) do if not target.claimSet[c.claimId] then target.claimSet[c.claimId]=true;target.claims[#target.claims+1]=c end end
            for _,id in ipairs(v.primaryDevelopmentIds) do target.primaryDevelopmentIds[#target.primaryDevelopmentIds+1]=id end
        else retained[#retained+1]=v end
    end
    scenes=retained
    -- The first place of a long source episode is not the place of every later
    -- quest beat. Use that beat's own recorded location, even if a reused map ID
    -- left several zones in the same source episode.
    for _,v in ipairs(scenes) do
        for _,c in ipairs(v.claims) do local f=index and c.evidenceRefs and index.byRef[c.evidenceRefs[1]];local place=f and f.location
            if place and (ns.CanRead(place.zone) or ns.CanRead(place.instanceName)) then
                v.place=ns.Athena.Copy(place)
                v.placeClaim={claimId='scene-place/'..v.sceneId,claimType='observed_place',value=place.instanceName or place.zone,evidenceRefs={f.evidenceRef},worldRefs={}}
                break
            end
        end
    end
    local skillsUsed={}
    for _,v in ipairs(scenes) do if v.focus=='QUEST' or v.focus=='ACTIVITY' or v.focus=='INTERLUDE' then
        local skills={}
        for _,s in ipairs(v.stories) do for _,c in ipairs(s.factualClaims) do local d=c.value
            local f=index and index.byRef[c.evidenceRefs[1]];local at=f and f.observedAt
            if c.claimType=='owner_skill_change' and not skillsUsed[c.claimId] and at and at>=v.at and at<=v.lastAt and d.name and type(d.before)=='number' and type(d.after)=='number' and d.after>d.before then
                local old=skills[d.name];if not old or d.after>old.value.after then skills[d.name]=c end
            end
        end end
        local names={};for name in pairs(skills) do names[#names+1]=name end;table.sort(names)
        v.skillGrowth={};for i=1,math.min(2,#names) do local c=skills[names[i]];v.skillGrowth[#v.skillGrowth+1]=c;skillsUsed[c.claimId]=true end
    end end
    local chapters={};local current
    for _,s in ipairs(scenes) do
        -- A chapter's scope is fixed by the projection, independent of font or width.
        if not current or current.id~=s.chapterId then
            local meta=projection and projection.chapters[s.chapterId]
            current={id=s.chapterId,at=s.chapterAt,title=meta and meta.title,scenes={}};chapters[#chapters+1]=current
        end
        current.scenes[#current.scenes+1]=s;s.chapter=current
        if s.focus=='QUEST' and projection then
            local q=projection.occurrences[s.occurrenceId];local first=q and q.developments[1];local began=false
            for _,c in ipairs(s.claims) do if c.claimType=='owner_quest_accepted' then began=true end end
            s.prior=not began and first and first.at<s.at and {ref=first.sourceRef,at=first.at} or nil
        end
    end
    plan.novelScenes=scenes;plan.manuscriptChapters=chapters;plan.narrationRevision=D.VERSION;return scenes
end

ns.Metis.Register('Scenes',D)
