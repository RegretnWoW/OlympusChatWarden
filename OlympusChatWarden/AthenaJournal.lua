-- DEV presentation only. Providers read authorized projections; nothing is saved.
local _,ns=...
local J={VERSION=11,MAX_ACTIVITIES=48,MAX_FACTS=256,MAX_CACHED_STORIES=96,MAX_SCAN=20000};ns.AthenaJournal=J
local function Copy(v) if type(v)~='table' then return v end;local o={};for k,x in pairs(v) do o[k]=Copy(x) end;return o end
J.Copy=Copy
-- Both directions must be weak on Lua 5.1: a simulation provider points back
-- to its run/stories. A strong value would keep that cycle alive after Reset.
local worldProviders=setmetatable({},{__mode="kv"})
function J.WorldLookup(story) local p=worldProviders[story];if p and p.WorldQuest then return function(id,env) return p:WorldQuest(id,env) end end end
local function Text(v,fallback) return ns.AthenaStoryPlanner.Text(v,fallback) end
local function Unique(out,seen,ref) if ref and not seen[ref] then seen[ref]=true;out[#out+1]=ref end end
local function Guid(v) return type(v)=='string' and v:match('^Player%-.+') and v end
function J.Live()
    local p={demo=false,name='Live history'}
    function p:Allowed() return ns.Athena.Enabled('chronicle') and ns.Membership.LocalHistoryAllowed() end
    function p:Activities(owner,cursor,frontier) return ns.Athena.GetJournalActivities('chronicle',owner,cursor,frontier) end
    function p:Evidence(owner,ref,cursor) return ns.Athena.GetActivityEvidence('chronicle',owner,ref,cursor,{limit=20}) end
    function p:WorldEnvironment() return ns.AthenaWorldKnowledge.Environment() end
    function p:StoryContent(kind) return ns.AthenaStoryContributions.Enabled(kind) end
    function p:ConversationsForStory(story,node)
        local ctx=ns.AthenaConversations.Context('chronicle',story.observerOwner)
        return ctx and ns.AthenaConversations.ForStory(story,ctx,{evidenceRefs=node and node.factSet}) or {}
    end
    function p:Resolve(ref)
        if self.privateSources and self.privateSources[ref] then
            local e=self.privateSources[ref];local c=ns.ChronicleStore.Character(e.observer,false)
            if not self:Allowed() or not self:StoryContent('protections') or not c or c.revision~=self.privateRevision then return nil,'DENIED' end
            return Copy(e)
        end
        if type(ref)=='string' and ref:match('^conversation%-moment/1/') then
            local ctx=ns.AthenaConversations.Context('chronicle',ns.Chronicle.Owner())
            return ctx and ns.AthenaConversations.ResolveMoment(ref,ctx) or nil,'PRIVATE_MEMORY; REVEAL_SEPARATELY'
        end
        return ns.Athena.ResolveEvidence('chronicle',ref)
    end
    function p:ClearPrivateSources() self.privateSources=nil;self.privateRevision=nil end
    function p:PrivateFacts(owner,cursor)
        if not self:StoryContent('protections') then self.privateSources=nil;return {} end
        local rows,nextPage=ns.Athena.GetHistoricalIncidents('command',owner,cursor,{limit=20})
        if not rows then return nil,nextPage end
        if not cursor then self.privateSources={};local c=ns.ChronicleStore.Character(owner,false);self.privateRevision=c and c.revision end
        local out={};for _,row in ipairs(rows) do local e=ns.AthenaStoryContributions.PrivateRow(row,owner)
            if e then self.privateSources[e.evidenceRef]=e;out[#out+1]=Copy(e) end
        end
        return out,nextPage
    end
    function p:Facts(owner,cursor,frontier) return ns.Athena.GetJournalSources('chronicle',owner,cursor,frontier) end
    function p:Identity(owner)
        local c=ns.ChronicleStore.Character(owner,false)
        if not c or c.storageFormat then return end
        return {character=c,events=c.events,count=#c.events,last=c.events[#c.events],generation=ns.ChronicleActivities.generation,revision=c.revision,storyScope=ns.AthenaStoryContributions.PermissionSignature()}
    end
    return p
end
function J.SameHistory(a,b)
    return a and b and a.character==b.character and a.events==b.events and a.generation==b.generation and a.storyScope==b.storyScope
        and b.count>=a.count and (a.count==0 or b.events[a.count]==a.last)
end
function J.Library() return {version=J.VERSION,stories={},byID={}} end
function J.ValidLibrary(library)
    return type(library)=='table' and library.version==J.VERSION and type(library.stories)=='table' and type(library.byID)=='table'
end
local meaningful={instance_enter=true,instance_exit=true,encounter_started=true,encounter_ended=true,boss_kill_event=true,
    group_roster=true,item_received=true,quest_item_received=true,encounter_loot_delivery=true,collection_gap=true,
    location=true,recording_stop=true,session_start=true,own_spell_success_count=true,level_change=true,quest_turnin=true,achievement_earned=true}
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
local function Assemble(job,node,facts,partial)
    local owner=job.owner;local place=node.place or {};local name=Text(place.instanceName or place.zone,'an unnamed place')
    local s={storyId='storybook/1/'..owner..'/'..node.activityRef,observerOwner=owner,title=name,
        storyKind=({RAID_RUN='RAID',ZONE_VISIT='ZONE_RETURN',WARDEN_MOMENT='WARDEN_MOMENT',FIELD_ACTIVITY='FIELD_ACTIVITY',QUESTING='QUESTING',PROGRESSION='PROGRESSION',DUEL='DUEL',WORLD_PVP='WORLD_PVP',SAGA='SAGA',BATTLEGROUND_VISIT='BATTLEGROUND',BATTLEGROUND_MATCH='BATTLEGROUND'})[node.type] or 'DUNGEON',
        firstObservedAt=node.firstObservedAt,lastObservedAt=node.lastObservedAt,sourceActivityRefs={node.activityRef},
        sourceEvidenceRefs={},factualClaims={},proseBlocks={},supportState='SUPPORTED',significanceReasons={},storyStatus='UNKNOWN',
        timeCoverage={unknownStart=node.unknownStart,unknownEnd=node.unknownEnd,partial=partial==true,gaps=false},
        narrativeVersion=3,demo=job.provider.demo==true,privacyScope='LOCAL_HISTORY',participants={},encounters={},featured=false,
        node={type=node.type,activityRef=node.activityRef,place=Copy(node.place),zoneKey=node.zoneKey,sourceRef=node.sourceRef,sourceID=node.sourceID}}
    local refs={};for _,e in ipairs(facts) do Unique(s.sourceEvidenceRefs,refs,e.evidenceRef) end
    -- Even the place/date statement needs an authorized, resolved original anchor.
    if not refs[node.sourceRef] then s.supportState='INSUFFICIENT';return s end
    local arrival=Claim(s,'observed_place',name,{node.sourceRef},node.unknownStart and 'Arrival was not observed' or nil)
    
    local active,attempts,byRef={}, {}, {};local own=node.observerGUID or owner:match('/(Player%-.+)$')
    local rosterSeen,rosterPartial=false,false;local summaries,kills,killRefs={},{},{};local deathRefs={};local petCredits=0
    for _,e in ipairs(facts) do
        local d=e.details or {};local r=e.family
        if not e.journalContextOnly and (r=='collection_gap' or r=='recording_stop') then s.timeCoverage.gaps=true end
        if e.journalContextOnly then -- Exact dated title context, not another event in this episode.
        elseif r=='adventure_combat_summary' and e.subjectGUID==own and ns.AthenaAdventureEvidence.Valid(d) then
            local old=summaries[d.windowRef]
            if not old or d.revision>old.details.revision then summaries[d.windowRef]=e end
        elseif r=='player_death' and (not e.subjectGUID or e.subjectGUID==own) then deathRefs[#deathRefs+1]=e.evidenceRef
        elseif r=='native_kill_credit' and ns.AthenaWorldScenes.OwnerKill(e,owner) and not kills[d.targetGUID] then
            kills[d.targetGUID]=true;killRefs[#killRefs+1]=e.evidenceRef
            if d.credit=='current pet native credit' then petCredits=petCredits+1 end
        elseif r=='group_roster' then
            if d.rosterComplete==false then rosterPartial=true
            elseif not rosterSeen and type(d.members)=='table' and #d.members>0 then
                rosterSeen=true
                local c=Claim(s,'roster_point_count',#d.members,{e.evidenceRef},'One dated roster point; not continuous attendance')
                
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
                local item=Text(d.itemName,'an item')
                Claim(s,'owner_item_receipt',{itemID=d.itemID,name=item},{e.evidenceRef},'Observed during this activity; boss-drop origin is not established')
            end
        elseif (not e.subjectGUID or e.subjectGUID==own) and r=='level_change' and type(d.before)=='number' and type(d.after)=='number' then
            Claim(s,'owner_level_change',{before=d.before,after=d.after},{e.evidenceRef})
        elseif (not e.subjectGUID or e.subjectGUID==own) and r:match('^quest_') and d.questID and r~='quest_item_received' then
            local title,titleRef,titleAt,conflict
            for _,v in ipairs(facts) do if v.family=='quest_observed' and v.details.questID==d.questID and v.observedAt<=e.observedAt and v.details.title then
                local label=Text(v.details.title)
                if titleAt==v.observedAt and label~=title then conflict=true
                elseif not titleAt or v.observedAt>titleAt then title=label;titleRef=v.evidenceRef;titleAt=v.observedAt;conflict=false end
            end end
            if conflict then title=nil;titleRef=nil end
            local rr={e.evidenceRef};if titleRef and titleRef~=e.evidenceRef then rr[#rr+1]=titleRef end
            local kind=({quest_turnin='owner_quest_turnin',quest_accepted='owner_quest_accepted',quest_observed='owner_quest_observed',quest_objective='owner_quest_objective',quest_removed='owner_quest_removed'})[r]
            if kind then Claim(s,kind,{questID=d.questID,name=title,objective=d.objective,fulfilled=d.fulfilled,required=d.required,finished=d.finished},rr) end
        elseif (not e.subjectGUID or e.subjectGUID==own) and r=='achievement_earned' and d.achievementID and d.alreadyEarned~=true then
            Claim(s,'owner_achievement',{achievementID=d.achievementID,name=Text(d.name)},{e.evidenceRef})
        elseif (not e.subjectGUID or e.subjectGUID==own) and r=='xp_change' and d.delta and d.delta>0 then
            Claim(s,'owner_xp_gain',{count=d.delta},{e.evidenceRef},'Observed XP change; no particular quest reward is inferred')
        elseif (not e.subjectGUID or e.subjectGUID==own) and r=='equipment_change' then
            Claim(s,'owner_equipment_change',{slot=d.slot,itemID=d.itemID,hasCurrent=d.hasCurrent},{e.evidenceRef},'Change observed; improvement is not inferred')
        elseif (not e.subjectGUID or e.subjectGUID==own) and r=='spell_learned' and d.spellID then
            Claim(s,'owner_spell_learned',{spellID=d.spellID},{e.evidenceRef})
        elseif (not e.subjectGUID or e.subjectGUID==own) and r=='skill_change' then
            Claim(s,'owner_skill_change',{name=Text(d.skill),before=d.before,after=d.after},{e.evidenceRef})
        elseif r=='duel_session_start' and d.accepted==true then
            Claim(s,'owner_duel_accepted',true,{e.evidenceRef})
        elseif r=='duel_session_result' and d.accepted==true and d.resultKnown==true and (d.result=='win' or d.result=='loss') then
            Claim(s,'owner_duel_result',{result=d.result},{e.evidenceRef},'Participant-bound native result; no exact combat sequence inferred')
        elseif node.type=='WORLD_PVP' and r=='player_combat' and d.hostile==true and e.subjectGUID and e.subjectGUID~=own and e.location and e.location.inInstance==false then
            Claim(s,'owner_world_pvp',{guid=e.subjectGUID},{e.evidenceRef},'Dated hostile combat interaction; no kill, rivalry or result inferred')
        elseif r=='match_observed' or r=='pvp_match_complete' then
            Claim(s,r=='match_observed' and 'match_observed' or 'match_ended',{outcome='UNKNOWN'},{e.evidenceRef},'Native winner values have no assumed owner/faction mapping')
        elseif r=='own_spell_success_count' and e.subjectGUID==own and type(d.count)=='number' and d.count>0 and d.spellID then
            -- Aggregate bins do not establish spell order, damage or a rotation.
            s.spells=s.spells or {};local v=s.spells[d.spellID] or {count=0,refs={}};s.spells[d.spellID]=v;v.count=v.count+d.count;v.refs[#v.refs+1]=e.evidenceRef
        end
    end
    local windows={};for key in pairs(summaries) do windows[#windows+1]=key end;table.sort(windows)
    local summarizedDeath=false
    for _,key in ipairs(windows) do local e=summaries[key];local d=Copy(e.details)
        d.observedAt=e.observedAt;summarizedDeath=summarizedDeath or d.deaths>0
        Claim(s,'owner_combat_experience',d,{e.evidenceRef},'Minimum readable health only; survival, kill credit and encounter victory are separate observations')
    end
    if #deathRefs>0 and not summarizedDeath then Claim(s,'owner_recorded_death',{count=#deathRefs},deathRefs) end
    if #killRefs>=10 then Claim(s,'owner_creature_credits',{count=#killRefs,petCount=petCredits,lowerBound=true},killRefs,'Distinct source-reported self or current-pet creature credits; native credit semantics need live verification; not necessarily solo kills') end
    local bosses={};for _,a in ipairs(attempts) do local b=bosses[a.boss] or {id=a.boss,name=a.name,attempts={},refs={},failures=0,successes=0,unknown=0};bosses[a.boss]=b
        b.attempts[#b.attempts+1]=a;for _,ref in ipairs(a.refs) do b.refs[#b.refs+1]=ref end
        if a.outcome=='FAILURE' then b.failures=b.failures+1 elseif a.outcome=='SUCCESS' then b.successes=b.successes+1 else b.unknown=b.unknown+1 end
    end
    local ids={};for id in pairs(bosses) do ids[#ids+1]=id end;table.sort(ids)
    local wins,losses,unknown=0,0,0
    for _,id in ipairs(ids) do local b=bosses[id];s.encounters[id]=b;wins=wins+b.successes;losses=losses+b.failures;unknown=unknown+b.unknown
        for _,a in ipairs(b.attempts) do Claim(s,'encounter_attempt',{boss=id,name=b.name,outcome=a.outcome,at=a.at},a.refs,(a.outcome=='UNKNOWN' or a.outcome=='CONFLICTING') and 'Native outcome missing or conflicting' or nil) end
        if b.failures>0 then Claim(s,'confirmed_failed_attempts',{boss=id,count=b.failures},b.refs) end
        if b.successes>0 then Claim(s,'confirmed_success',{boss=id,count=b.successes},b.refs) end
        if b.unknown>0 then Claim(s,'uncertain_outcome',{boss=id,count=b.unknown},b.refs,'Missing or conflicting native outcomes') end
    end
    if rosterPartial then local rs={};for _,e in ipairs(facts) do if e.family=='group_roster' and e.details.rosterComplete==false then rs[#rs+1]=e.evidenceRef end end
        Claim(s,'partial_roster',true,rs,'Unreadable membership is not a disband') end
    if wins>0 then s.storyStatus=unknown>0 and 'INCOMPLETE' or 'SUCCESS';s.featured=true;s.significanceReasons[1]='Verified encounter victory'
    elseif losses>0 then s.storyStatus=unknown>0 and 'INCOMPLETE' or 'FAILURE';s.featured=s.storyKind=='RAID';s.significanceReasons[1]=s.featured and 'Recorded raid progression' or 'History only: dungeon without recorded victory'
    else s.storyStatus=s.storyKind=='ZONE_RETURN' and 'UNKNOWN' or 'INCOMPLETE' end
    if s.timeCoverage.partial or node.unknownStart or node.unknownEnd then s.storyStatus='INCOMPLETE' end
    if wins==0 and s.storyKind=='RAID' then Claim(s,'no_recorded_victory',true,s.sourceEvidenceRefs,'Only the permitted reviewed source window is known') end
    local spellID,spell
    for id,v in pairs(s.spells or {}) do if not spell or v.count>spell.count or v.count==spell.count and id<spellID then spellID,spell=id,v end end
    if spell then Claim(s,'own_spell_frequency',{spellID=spellID,count=spell.count},spell.refs,'Observed successful-cast samples; not damage or rotation order') end
    if s.timeCoverage.partial or s.timeCoverage.gaps or node.unknownStart or node.unknownEnd then s.supportState='QUALIFIED' end
    if s.timeCoverage.gaps then Claim(s,'coverage_gaps',true,s.sourceEvidenceRefs,'Continuous play is not established') end
    for _,c in ipairs(s.factualClaims) do c.knownCoverage=Copy(s.timeCoverage) end
    if ns.AthenaStoryContributions then ns.AthenaStoryContributions.Claims(s,facts,Claim,job.provider) end
    s.baseClaims=#s.factualClaims;s.baseProse=#s.proseBlocks;s.baseSources=#s.sourceEvidenceRefs
    return s
end
local core={encounter_ended=true,boss_kill_event=true,duel_session_result=true,pvp_match_complete=true,quest_turnin=true,level_change=true,achievement_earned=true}
local function Title(index,f)
    local rows=index.questTitles[f.details.questID] or {};local lo,hi,best=1,#rows,nil
    while lo<=hi do local mid=math.floor((lo+hi)/2);if rows[mid].at<=f.observedAt then best=rows[mid];lo=mid+1 else hi=mid-1 end end
    return best and f.observedAt-best.at<=86400 and best or nil
end
local function Alias(index,guid,at)
    local best;for _,row in ipairs(index.aliases[guid] or {}) do if row.at<=at then best=row else break end end;return best
end
function J.New(provider,owner,cursor,library)
    local job={provider=provider,owner=owner,cursor=cursor,status='INDEXING',stories={},calls=0,resolved=0,restarts=0,library=library}
    local function Work()
        local X=ns.AthenaStoryIndex;local index=library and library.index
        local token=provider.Identity and provider:Identity(owner)
        local reuse=X.Valid(index) and index.done and index.status=='READY' and index.provider==provider and index.owner==owner
            and ((token and J.SameHistory(index.identity,token) and index.identity.revision==token.revision) or not provider.Identity and cursor~=nil)
        if not reuse then
            index=X.New(provider,owner,index);index.serial=((library and library.index and library.index.serial) or 0)+1
            job.index=index
            while not index.done do job.status=X.Pump(index);coroutine.yield() end
            if index.status~='READY' then error(index.status) end
            if library then library.index=index end
        end
        job.index=index
        local nodes,nextCursor
        if type(job.cursor)=='table' and job.cursor.threadId then nodes,nextCursor,job.storyThread,job.volume=ns.AthenaStoryThreads.Window(index,job.cursor)
        else nodes,nextCursor=X.Page(index,job.cursor) end
        if not nodes then error(nextCursor) end
        job.chapterStories={}
        job.nextCursor=nextCursor;job.activitiesRead=#nodes
        local knowledgeContext=ns.Athena.Knowledge and ns.Athena.Knowledge.Context('chronicle',owner,{index=index})
        for _,node in ipairs(nodes) do
            local refs,used={},{};local count=0
            local function Add(ref) if ref and index.byRef[ref] and not used[ref] and #refs<J.MAX_FACTS then used[ref]=true;refs[#refs+1]=ref;return true end end
            Add(node.sourceRef)
            for _,ref in ipairs(ns.Metis.Preferred(index,node)) do Add(ref) end
            for _,link in ipairs(node.links) do
                for _,ref in ipairs(link.refs) do Add(ref) end
                if link.guid then local alias=Alias(index,link.guid,node.lastObservedAt);if alias then Add(alias.ref) end end
            end
            -- Preserve important outcomes in every reading length; resolve a
            -- bounded evidence window and keep any omitted scope explicit.
            for pass=1,2 do for i=#node.factRefs,1,-1 do
                local ref=node.factRefs[i];local f=index.byRef[ref]
                if (pass==1)==(core[f.family]==true) and #refs<J.MAX_FACTS-32 then Add(ref) end
                count=count+1;if count%128==0 then coroutine.yield() end
            end end
            local initial=#refs
            for i=1,initial do local f=index.byRef[refs[i]];if f.details.questID then local title=Title(index,f);if title then Add(title.ref) end end end
            local chainLinks={};local knownQuests={};local env=provider.WorldEnvironment and provider:WorldEnvironment() or ns.AthenaWorldKnowledge.Environment()
            local bounded=#refs
            for at=1,bounded do local f=index.byRef[refs[at]];local id=f.details.questID
                if id and not knownQuests[id] and (f.family=='quest_accepted' or f.family=='quest_turnin' or f.family=='quest_objective') then
                    knownQuests[id]=true;local card=knowledgeContext and ns.Athena.Knowledge.GetQuest(id,knowledgeContext)
                    for i,priorID in ipairs(card and card.previousIDs or {}) do if i>8 or #chainLinks>=32 then break end
                        local priorCard=ns.Athena.Knowledge.GetQuest(priorID,knowledgeContext)
                        local link=priorCard and ns.AthenaWorldKnowledge.ChainLink(priorID,id,env);local prior
                        local rows=index.questTurnins and index.questTurnins[priorID] or {};local lo,hi=1,#rows
                        while lo<=hi do local mid=math.floor((lo+hi)/2);if rows[mid].observedAt<f.observedAt then prior=rows[mid];lo=mid+1 else hi=mid-1 end end
                        if link and prior and (used[prior.evidenceRef] or Add(prior.evidenceRef)) then chainLinks[#chainLinks+1]={current=f.evidenceRef,previous=prior.evidenceRef,link=link} end
                    end
                end
                if at%32==0 then coroutine.yield() end
            end
            local expeditionLinks={}
            if knowledgeContext and node.place and (node.place.instanceType=='party' or node.place.instanceType=='raid') then
                local candidates={}
                for _,occurrence in pairs(index.narrative and index.narrative.occurrences or {}) do
                    local accepted=occurrence.accepted and index.byRef[occurrence.accepted]
                    local ending=(occurrence.turnedIn or occurrence.removed) and index.byRef[occurrence.turnedIn or occurrence.removed]
                    if accepted and accepted.observedAt<node.firstObservedAt and (not ending or ending.observedAt>=node.firstObservedAt) then
                        candidates[#candidates+1]={accepted=accepted,questID=occurrence.questID}
                    end
                end
                table.sort(candidates,function(a,b) return a.accepted.observedAt>b.accepted.observedAt or a.accepted.observedAt==b.accepted.observedAt and a.questID<b.questID end)
                for i,candidate in ipairs(candidates) do
                    local card=ns.Athena.Knowledge.GetQuest(candidate.questID,knowledgeContext)
                    local target=ns.AthenaQuestContext.ExpeditionTarget(card,node.place)
                    if target and (used[candidate.accepted.evidenceRef] or Add(candidate.accepted.evidenceRef)) then
                        expeditionLinks[#expeditionLinks+1]={accepted=candidate.accepted.evidenceRef,questID=candidate.questID,target=target}
                        if #expeditionLinks>=4 then break end
                    end
                    if i%16==0 then coroutine.yield() end
                end
            end
            local originalRefs=#refs;local captureCount=0
            for i=1,originalRefs do local source=refs[i]
                if node.factSet[source]or node.sourceRef==source then
                    for _,ref in ipairs(index.momentsBySource and index.momentsBySource[source]or{})do
                        if captureCount<24 and Add(ref)then captureCount=captureCount+1 end
                    end
                end
            end
            local facts,episodeFacts={},{};for _,ref in ipairs(refs) do
                local e=Read(job,provider.Resolve,ref);local f=index.byRef[ref]
                if e.observer==owner and e.evidenceRef==ref and (not e.storyPrivateProjection or ns.AthenaStoryContributions.Visible(e.family,provider)) and e.accessScope~='PRIVATE_INCIDENT' and not (e.sourceContext and e.sourceContext.accessScope=='PRIVATE_INCIDENT') then
                    e.family=f.family;facts[#facts+1]=e;job.resolved=job.resolved+1
                    if node.factSet[ref]or f.family=='moment_capture'and(node.factSet[f.details.sourceRef]or node.sourceRef==f.details.sourceRef)then episodeFacts[#episodeFacts+1]=e
                    elseif f.family=='quest_observed' then e.journalContextOnly=true;episodeFacts[#episodeFacts+1]=e
                    elseif e.storyPrivateProjection then
                        for _,privateRef in ipairs(index.narrative.contextByStory[node.storyId] or {}) do if privateRef==ref then episodeFacts[#episodeFacts+1]=e end end
                    end
                end
            end
            table.sort(episodeFacts,function(a,b) return a.observedAt<b.observedAt or a.observedAt==b.observedAt and a.evidenceRef<b.evidenceRef end)
            local covered=0;for _,ref in ipairs(node.factRefs) do if used[ref] then covered=covered+1 end end
            local story=Assemble(job,node,episodeFacts,covered<#node.factRefs);story.indexSerial=index.serial
            story.momentCaptures={};local captures={}
            for _,fact in ipairs(episodeFacts)do if fact.family=='moment_capture'then local d=fact.details;captures[d.requestRef]={momentRef=d.momentRef,requestRef=d.requestRef,sourceRef=d.sourceRef,status=d.captureStatus,at=fact.observedAt,filename=nil,imageAvailable=false}end end
            for _,capture in pairs(captures)do story.momentCaptures[#story.momentCaptures+1]=capture end
            table.sort(story.momentCaptures,function(a,b)return a.requestRef<b.requestRef end)
            story.knowledgeContext=knowledgeContext
            if provider.ConversationsForStory then
                story.conversationMoments=provider:ConversationsForStory(story,node) or {}
                for _,moment in ipairs(story.conversationMoments) do
                    Claim(story,'private_conversation_observed',{momentRef=moment.momentRef,channelKind=moment.channelKind,relationStrength=moment.relationStrength,observedFrom=moment.observedFrom},
                        {moment.momentRef},'Only an eligible private exchange was observed; its words do not prove accomplishments, relationships or other assertions')
                end
            end
            story.narrativeIndex=index
            story.lifeOrdinal=node.lifeOrdinal
            story.characterName=index.ownerIdentity and index.ownerIdentity.name
            story.worldEnvironment=provider.WorldEnvironment and provider:WorldEnvironment() or nil
            worldProviders[story]=provider
            story.worldSignature=ns.AthenaWorldKnowledge and ns.AthenaWorldKnowledge.Signature()
            story.privacyScope=node.private and 'LOCAL_PRIVATE' or story.privacyScope
            local resolved={};for _,e in ipairs(facts) do resolved[e.evidenceRef]=e end
            for _,link in ipairs(node.links) do
                local rr={};local complete=true;for _,ref in ipairs(link.refs) do if resolved[ref] then rr[#rr+1]=ref else complete=false end end
                if complete then
                    local value={priorStory=link.prior,guid=link.guid,boss=link.boss,zone=link.zone,at=link.at,questID=link.questID}
                    if link.guid then local alias=Alias(index,link.guid,node.lastObservedAt);local e=alias and resolved[alias.ref]
                        if e and e.subjectGUID==link.guid then value.name=Text(e.details.name);rr[#rr+1]=alias.ref end
                    end
                    Claim(story,link.kind,value,rr,'Distinct dated observations; no continuous attendance, friendship or intervening activity is established')
                end
            end
            for _,connection in ipairs(chainLinks) do
                if resolved[connection.current] and resolved[connection.previous] then
                    local c=Claim(story,'quest_reference_connection',{previousID=connection.link.before.id,questID=connection.link.after.id},
                        {connection.previous,connection.current},'Static reference link and separately observed stages; no completion of an unobserved intermediate quest')
                    c.worldRefs=connection.link.worldRefs;c.worldFacts={connection.link.before,connection.link.after}
                end
            end
            for _,connection in ipairs(expeditionLinks) do
                if resolved[connection.accepted] and resolved[node.sourceRef] then
                    Claim(story,'quest_expedition_context',{questID=connection.questID,target=connection.target},
                        {connection.accepted,node.sourceRef},'An earlier still-open assignment names this native encounter; presence does not prove its completion or the player’s reason for entering')
                end
            end
            if node.episodes then
                story.episodes={};for _,id in ipairs(node.episodes) do local n=index.byStory[id]
                    story.episodes[#story.episodes+1]={storyId=id,title=Text(n.place.instanceName or n.place.zone,'An expedition'),at=n.firstObservedAt,sourceRef=n.sourceRef}
                end
            end
            ns.Metis.Memory.Claims(story,node,resolved,index,Claim)
            local seen={};for _,ref in ipairs(story.sourceEvidenceRefs) do seen[ref]=true end
            for _,c in ipairs(story.factualClaims) do for _,ref in ipairs(c.evidenceRefs) do Unique(story.sourceEvidenceRefs,seen,ref) end end
            -- Only this story's resolved, permitted claims enter its context;
            -- a later encounter elsewhere in a run cannot leak into this scene.
            story.adventureSummary=ns.AthenaAdventureSummary.FromClaims(story)
            ns.Metis.Process(story);job.stories[#job.stories+1]=story;job.chapterStories[#job.chapterStories+1]=story;coroutine.yield()
        end
        if library then
            local map={};for _,s in ipairs(library.stories) do map[s.storyId]=s end
            for _,s in ipairs(job.stories) do map[s.storyId]=s end
            job.stories={};for _,s in pairs(map) do job.stories[#job.stories+1]=s end
            table.sort(job.stories,function(a,b) return a.firstObservedAt>b.firstObservedAt or a.firstObservedAt==b.firstObservedAt and a.storyId<b.storyId end)
            library.readSequence=(library.readSequence or 0)+1
            local keep={};for _,s in ipairs(job.chapterStories) do keep[s.storyId]=true;s.lastRead=library.readSequence end
            if #job.stories>J.MAX_CACHED_STORIES then
                local ranked={};for _,s in ipairs(job.stories) do ranked[#ranked+1]=s end
                table.sort(ranked,function(a,b) if keep[a.storyId]~=keep[b.storyId] then return keep[a.storyId]==true end;if (a.lastRead or 0)~=(b.lastRead or 0) then return (a.lastRead or 0)>(b.lastRead or 0) end;return a.storyId<b.storyId end)
                local ids={};for i=1,J.MAX_CACHED_STORIES do ids[ranked[i].storyId]=true end
                local retained={};for _,s in ipairs(job.stories) do if ids[s.storyId] then retained[#retained+1]=s else map[s.storyId]=nil end end;job.stories=retained
            end
            library.stories=job.stories;library.byID=map
            if not (type(job.cursor)=='table' and (job.cursor.storyId or job.cursor.threadId)) then library.nextCursor=job.nextCursor end
        end
        job.done=true;job.status='READY'
    end
    job.work=Work;job.thread=coroutine.create(Work);return job
end
function J.Pump(job)
    if not job.provider:Allowed() then
        job.stories={};job.done=true;job.status='DENIED';job.thread=nil;job.index=nil
        if job.library then job.library.stories={};job.library.byID={};job.library.index=nil end
        return job.status
    end
    if job.done then return job.status end
    if InCombatLockdown and InCombatLockdown() then job.status='COMBAT_WAIT';return job.status end
    if job.status=='COMBAT_WAIT' then job.status='INDEXING' end
    local ok,why=coroutine.resume(job.thread)
    if not ok then
        job.error=tostring(why)
        local state=tostring(why):match('([A-Z_]+)$') or 'UNAVAILABLE'
        if state=='CURSOR_STALE' and not job.library and job.restarts<3 then
            job.restarts=job.restarts+1;job.stories={};job.activitiesRead=0;job.cursor=nil;job.thread=coroutine.create(job.work);job.status='INDEXING'
        else job.stories={};job.done=true;job.status=state end
    end
    return job.status
end
function J.Featured(job) local out={};for _,s in ipairs(job.stories) do if s.featured then out[#out+1]=s end end;return out end
