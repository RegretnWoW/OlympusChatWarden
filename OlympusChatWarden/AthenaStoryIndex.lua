-- Ephemeral, permission-scoped reference index. No SavedVariables or collectors.
local _,ns=...
local X={VERSION=8};ns.AthenaStoryIndex=X
X.families={moment_capture=true,exploration_discovery=true,character_snapshot=true,character_detail=true,friend_status=true,guild_affiliation=true,guild_member_observed=true,signal_sighting=true,historical_incident=true,incident_correction=true,instance_enter=true,instance_exit=true,location=true,session_start=true,recording_start=true,recording_stop=true,collection_gap=true,
    encounter_started=true,encounter_ended=true,boss_kill_event=true,group_roster=true,player_observed=true,
    quest_accepted=true,quest_observed=true,quest_objective=true,quest_removed=true,quest_turnin=true,xp_change=true,level_change=true,
    achievement_earned=true,equipment_change=true,spell_learned=true,skill_change=true,item_received=true,quest_item_received=true,
    encounter_loot_delivery=true,duel_session_start=true,duel_session_end=true,duel_session_result=true,match_observed=true,pvp_match_complete=true,player_combat=true,native_kill_credit=true,own_spell_success_count=true,adventure_combat_summary=true,player_death=true}
local candidate={RAID_RUN=true,INSTANCE_VISIT=true,ZONE_VISIT=true,BATTLEGROUND_VISIT=true,BATTLEGROUND_MATCH=true,DUEL=true}
local priority={DUEL=6,BATTLEGROUND_MATCH=5,BATTLEGROUND_VISIT=4,RAID_RUN=3,INSTANCE_VISIT=3,ZONE_VISIT=1}
local personal={quest_accepted=true,quest_observed=true,quest_objective=true,quest_removed=true,quest_turnin=true,xp_change=true,
    level_change=true,achievement_earned=true,equipment_change=true,spell_learned=true,skill_change=true}
local fields={'momentRef','requestRef','sourceRef','activityRef','sessionRef','category','burstIndex','burstCount','intendedUI','actualUI','captureStatus','class','race','guild','encounterID','name','title','questID','objective','fulfilled','required','finished','success','result','resultKnown','accepted',
    'objectiveID','objectiveState','questOccurrenceRef','resultMethod','encounterRef','rosterComplete','before','after','delta','beforeLevel','afterLevel','achievementID','alreadyEarned',
    'spellID','slot','itemID','itemName','recipientGUID','playerGUID','hasCurrent','skill','rank','count','level','realm','duelID','opponentGUID','hostile','direction',
    'attackerGUID','targetGUID','entityKind','credit','creatureID','creatureName','classification','firstAt','lastAt','summaryVersion','windowRef','revision','startObserved','closed','phase','healthReadability','minHealthPercent','deaths','selfCredits','petCredits','creditLowerBound','recoveryObserved','lowHealthObserved','endAlive','combatSeconds'}
local function Read(index,fn,...)
    while true do
        if not index.provider:Allowed() then error('DENIED') end
        local rows,nextPage,checkpoint=fn(index.provider,...);index.calls=index.calls+1
        if rows then index.status='INDEXING';coroutine.yield();return rows,nextPage,checkpoint end
        if ({INDEXING=true,LOAD_WAIT=true,LINK_PENDING=true,building=true,loading=true,pending=true})[nextPage] then index.status=nextPage;coroutine.yield() else error(nextPage or 'UNAVAILABLE') end
    end
end
local function Less(a,b) return a.observedAt<b.observedAt or a.observedAt==b.observedAt and a.evidenceRef<b.evidenceRef end
local function Sort(rows,less)
    local size,steps=1,0
    while size<#rows do
        local out={}
        for first=1,#rows,2*size do
            local a,b=first,first+size;local ae,be=math.min(first+size-1,#rows),math.min(first+2*size-1,#rows)
            while a<=ae or b<=be do
                if b>be or a<=ae and less(rows[a],rows[b]) then out[#out+1]=rows[a];a=a+1 else out[#out+1]=rows[b];b=b+1 end
                steps=steps+1;if steps%128==0 then coroutine.yield() end
            end
        end
        rows=out;size=size*2
    end
    return rows
end
function X.StoryID(owner,ref) return 'storybook/1/'..owner..'/'..ref end
local function AddRef(node,fact)
    if not node.factSet[fact.evidenceRef] then node.factSet[fact.evidenceRef]=true;node.factRefs[#node.factRefs+1]=fact.evidenceRef end
end
local function BossKey(node,id)
    local p=node.place or {};local context=p.instanceID and p.difficultyID~=nil and ('id:'..p.instanceID)
    if not context or not (p.instanceType=='raid' or p.instanceType=='party' or node.type=='RAID_RUN' or node.type=='INSTANCE_VISIT') then return end
    return tostring(p.instanceType or node.type)..'/'..context..'/'..tostring(p.difficultyID or 'unknown-difficulty')..'/'..id
end
X.BossKey=BossKey
function X.Valid(index)
    return type(index)=='table' and index.version==X.VERSION and type(index.facts)=='table' and type(index.nodes)=='table'
        and type(index.byRef)=='table' and type(index.byStory)=='table' and type(index.byActivity)=='table' and type(index.aliases)=='table'
end
function X.New(provider,owner,previous)
    local token=provider.Identity and provider:Identity(owner)
    local extend=X.Valid(previous) and previous.provider==provider and previous.owner==owner
        and token and ns.AthenaJournal.SameHistory(previous.identity,token)
    local index={version=X.VERSION,provider=provider,owner=owner,status='INDEXING',calls=0,facts={},byRef={},nodes={},byActivity={},byStory={},aliases={},sagas={},identity=token,
        frontier=token and {count=token.count,lastID=token.last and token.last.id}}
    local function Work()
        index.phase='activities'
        local nodes,duels={},{};local cursor
        repeat
            local rows,nextPage,frontier=Read(index,provider.Activities,owner,cursor,index.frontier);cursor=nextPage;index.frontier=index.frontier or frontier
            for _,n in ipairs(rows) do if n.observer==owner and candidate[n.type] and n.accessScope~='PRIVATE_INCIDENT' then
                local node=ns.AthenaJournal.Copy(n);node.factRefs={};node.factSet={};node.links={};node.encounters={};node.participants={}
                node.storyId=X.StoryID(owner,node.activityRef);nodes[#nodes+1]=node;index.byActivity[node.activityRef]=node;index.byStory[node.storyId]=node
                for _,alias in ipairs(node.activityAliases or {}) do index.byActivity[alias]=node end
                if node.type=='DUEL' and node.duelID then duels[node.duelID]=node end
            end end
        until not cursor
        local function Admit(e,context)
            if e.observer~=owner or not ns.AthenaStoryContributions.Visible(e.family,provider) or not X.families[e.family] or e.accessScope=='PRIVATE_INCIDENT' or e.sourceContext and e.sourceContext.accessScope=='PRIVATE_INCIDENT' then return end
            if e.family=='native_kill_credit' and not ns.AthenaWorldScenes.OwnerKill(e,owner) then return end
            if e.family=='adventure_combat_summary' and e.subjectGUID~=owner:match('/(Player%-.+)$') then return end
            local f=index.byRef[e.evidenceRef]
            if not f then
                f={evidenceRef=e.evidenceRef,sourceRecordRef=e.sourceRecordRef,family=e.family,observedAt=e.observedAt,elapsed=e.elapsed,clock=e.clock,
                    session=e.session,subjectGUID=e.subjectGUID,source=e.source,location=ns.AthenaJournal.Copy(e.location or {}),mapID=e.mapID,difficultyID=e.difficultyID or e.sourceContext and e.sourceContext.difficultyID,details={},contexts={},contextSet={}}
                for _,k in ipairs(fields) do f.details[k]=e.details and e.details[k] end
                for _,k in ipairs(ns.AthenaStoryContributions.fields) do f.details[k]=e.details and ns.AthenaJournal.Copy(e.details[k]) end
                f.storyPrivateProjection=e.storyPrivateProjection
                if e.details and e.details.members then f.details.members=ns.AthenaJournal.Copy(e.details.members) end
                index.byRef[f.evidenceRef]=f;index.facts[#index.facts+1]=f
            end
            for _,ref in ipairs(context and {context} or e.contexts or {}) do if not f.contextSet[ref] then f.contextSet[ref]=true;f.contexts[#f.contexts+1]=ref end end
        end
        if provider.PrivateFacts and ns.AthenaStoryContributions.Visible('historical_incident',provider) then
            local privateCursor
            repeat local rows,nextPage=Read(index,provider.PrivateFacts,owner,privateCursor);privateCursor=nextPage
                for _,e in ipairs(rows) do Admit(e) end
            until not privateCursor
        end
        if extend then for i,f in ipairs(previous.facts) do if not f.storyPrivateProjection then index.facts[#index.facts+1]=f;index.byRef[f.evidenceRef]=f end;if i%128==0 then coroutine.yield() end end end
        if provider.Facts then
            index.phase='sources'
            cursor=extend and previous.checkpoint or nil
            repeat
                local rows,nextPage,checkpoint=Read(index,provider.Facts,owner,cursor,index.frontier);cursor=nextPage;index.checkpoint=checkpoint;index.scanned=checkpoint and checkpoint.offset
                for _,e in ipairs(rows) do Admit(e) end
            until not cursor
        else
            -- Source-compatible private/legacy providers. Same processor and
            -- permission checks; production uses the single-pass stream above.
            for _,node in ipairs(nodes) do
                cursor=nil
                repeat
                    local rows,nextPage=Read(index,provider.Evidence,owner,node.activityRef,cursor);cursor=nextPage
                    for _,row in ipairs(rows) do if X.families[row.family] then
                        local f=index.byRef[row.evidenceRef]
                        if f then Admit({observer=owner,family=row.family,evidenceRef=row.evidenceRef},node.activityRef)
                        else local e=Read(index,provider.Resolve,row.evidenceRef);e.family=row.family;Admit(e,node.activityRef) end
                    end end
                until not cursor
            end
        end
        index.phase='planning';index.facts=Sort(index.facts,Less)
        local segment,last,seq=nil,nil,0;local own=owner:match('/(Player%-.+)$');local outdoor;local fighting;local combatNodes={}
        for i,f in ipairs(index.facts) do
            local d=f.details;local primary
            for _,ref in ipairs(f.contexts) do local n=index.byActivity[ref];if n and (not primary or (priority[n.type] or 0)>(priority[primary.type] or 0)) then primary=n end end
            -- Native duel results can arrive after the end boundary cleared
            -- the active context. The exact saved duel ID remains authoritative.
            if f.family:match('^duel_session_') and d.duelID and duels[d.duelID] then primary=duels[d.duelID] end
            f.primary=primary and primary.activityRef
            if f.family=='collection_gap' or f.family=='recording_stop' or f.family=='recording_start' or f.family=='session_start' or f.family=='location' or f.family=='instance_enter' or f.family=='instance_exit' then segment=nil;last=nil;outdoor=nil end
            local zone=f.mapID and 'ui-map:'..f.mapID or primary and primary.zoneKey or f.location.zone
            local session=f.session or primary and (primary.parentRef or primary.activityRef)
            if f.family=='quest_accepted' or f.family=='quest_turnin' or f.family=='quest_removed' or f.family=='collection_gap' or f.family=='recording_stop' or f.family=='recording_start' or f.family=='session_start' or f.family=='location' or f.family=='instance_enter' or f.family=='instance_exit' then fighting=nil end
            if (ns.AthenaWorldScenes.OwnerKill(f,owner) or f.family=='adventure_combat_summary' and f.subjectGUID==own or f.family=='player_death' and (not f.subjectGUID or f.subjectGUID==own)) and (not primary or (priority[primary.type] or 0)<=1) then
                local key=tostring(session)..'/'..tostring(f.clock)..'/'..tostring(zone)
                local known=d.windowRef and combatNodes[d.windowRef]
                if known then fighting=known
                elseif segment and segment.segmentKey==key and f.observedAt-segment.lastObservedAt<=300 and (not d.firstAt or d.firstAt>=segment.firstObservedAt) then fighting=segment
                elseif not fighting or fighting.segmentKey~=key or f.observedAt-fighting.lastObservedAt>300 then
                    local ref='journal:field:'..f.sourceRecordRef
                    fighting={activityRef=ref,storyId=X.StoryID(owner,ref),type='FIELD_ACTIVITY',observer=owner,observerGUID=own,sourceRef=f.evidenceRef,sourceID=f.sourceRecordRef,
                        mapID=f.mapID,place=ns.AthenaJournal.Copy(f.location),zoneKey=zone,firstObservedAt=f.observedAt,lastObservedAt=f.observedAt,
                        unknownStart=true,unknownEnd=true,status='INCOMPLETE',factRefs={},factSet={},links={},encounters={},participants={},segmentKey=key}
                    nodes[#nodes+1]=fighting;index.byActivity[ref]=fighting;index.byStory[fighting.storyId]=fighting
                end
                if d.windowRef then combatNodes[d.windowRef]=fighting end
                AddRef(fighting,f);fighting.lastObservedAt=f.observedAt;f.primary=fighting.activityRef
                if primary then primary.suppressed=true end
            elseif f.family=='own_spell_success_count' and f.subjectGUID==own and fighting and f.observedAt-fighting.lastObservedAt<=300 then
                AddRef(fighting,f);f.primary=fighting.activityRef
            elseif f.family=='player_combat' and d.hostile==true and f.location.inInstance==false and type(f.subjectGUID)=='string' and f.subjectGUID:match('^Player%-') and f.subjectGUID~=own then
                local key=tostring(session)..'/'..tostring(f.clock)..'/'..tostring(zone)
                if not outdoor or outdoor.segmentKey~=key or f.observedAt-outdoor.lastObservedAt>300 then
                    local ref='journal:world-pvp:'..f.sourceRecordRef
                    outdoor={activityRef=ref,storyId=X.StoryID(owner,ref),type='WORLD_PVP',observer=owner,observerGUID=own,sourceRef=f.evidenceRef,sourceID=f.sourceRecordRef,
                        place=ns.AthenaJournal.Copy(f.location),zoneKey=f.mapID and 'ui-map:'..f.mapID or primary and primary.zoneKey,firstObservedAt=f.observedAt,lastObservedAt=f.observedAt,
                        unknownStart=true,unknownEnd=true,status='INCOMPLETE',factRefs={},factSet={},links={},encounters={},participants={},segmentKey=key}
                    nodes[#nodes+1]=outdoor;index.byActivity[ref]=outdoor;index.byStory[outdoor.storyId]=outdoor
                end
                AddRef(outdoor,f);outdoor.lastObservedAt=f.observedAt;f.primary=outdoor.activityRef
                if primary and primary.type=='ZONE_VISIT' then primary.suppressed=true end
            elseif personal[f.family] and (not f.subjectGUID or f.subjectGUID==own) and (not primary or (priority[primary.type] or 0)<=1) then
                local key=tostring(session)..'/'..tostring(f.clock)..'/'..tostring(zone)
                if not segment or segment.segmentKey~=key or last and (f.observedAt-last>1200 or f.observedAt<last) then
                    seq=seq+1;local ref='journal:adventure:'..f.sourceRecordRef
                    segment={activityRef=ref,type='PROGRESSION',observer=owner,observerGUID=own,sourceRef=f.evidenceRef,sourceID=f.sourceRecordRef,mapID=f.mapID,
                        place=ns.AthenaJournal.Copy(f.location),zoneKey=zone,firstObservedAt=f.observedAt,lastObservedAt=f.observedAt,
                        unknownStart=true,unknownEnd=true,status='INCOMPLETE',factRefs={},factSet={},links={},encounters={},participants={},storyId=X.StoryID(owner,ref),segmentKey=key}
                    nodes[#nodes+1]=segment;index.byActivity[ref]=segment;index.byStory[segment.storyId]=segment
                end
                if f.family:match('^quest_') then segment.type='QUESTING' end
                segment.lastObservedAt=f.observedAt;AddRef(segment,f);f.primary=segment.activityRef;last=f.observedAt
                if primary then primary.suppressed=true end
            elseif ({friend_status=true,guild_affiliation=true,guild_member_observed=true,signal_sighting=true,historical_incident=true,incident_correction=true})[f.family] then
                local private=f.family=='historical_incident' or f.family=='incident_correction'
                local ref='journal:contribution:'..f.sourceRecordRef
                local social={activityRef=ref,storyId=X.StoryID(owner,ref),type='WARDEN_MOMENT',observer=owner,observerGUID=own,
                    sourceRef=f.evidenceRef,sourceID=f.sourceRecordRef,place=ns.AthenaJournal.Copy(f.location),mapID=f.mapID,private=private,
                    zoneKey=f.mapID and 'ui-map:'..f.mapID,firstObservedAt=f.observedAt,lastObservedAt=f.observedAt,unknownStart=true,unknownEnd=true,
                    status='INCOMPLETE',factRefs={},factSet={},links={},encounters={},participants={}}
                if f.subjectGUID then social.connections=social.connections or {};social.connections[f.subjectGUID]={guid=f.subjectGUID,ref=f.evidenceRef,at=f.observedAt} end
                AddRef(social,f);nodes[#nodes+1]=social;index.byActivity[ref]=social;index.byStory[social.storyId]=social;f.primary=ref
            elseif primary then AddRef(primary,f) end
            if (f.family=='character_detail' or f.family=='character_snapshot') and (not f.subjectGUID or f.subjectGUID==own) then
                index.ownerIdentity=index.ownerIdentity or {owner=owner,evidenceRef=f.evidenceRef}
                for _,key in ipairs({'name','race','faction','class','raceID','classID'}) do if not index.ownerIdentity[key] and (type(d[key])=='string' or type(d[key])=='number') then index.ownerIdentity[key]=d[key] end end
            end
            if f.family=='player_observed' and f.subjectGUID and d.name then
                local aliases=index.aliases[f.subjectGUID] or {};index.aliases[f.subjectGUID]=aliases
                aliases[#aliases+1]={at=f.observedAt,name=d.name,realm=d.realm,ref=f.evidenceRef}
            end
            if i%64==0 then coroutine.yield() end
        end
        -- Quest title observations may precede the actual turn-in segment. A
        -- dated exact-ID title pointer is retained, never a guessed quest name.
        index.questTitles={};index.questTurnins={}
        for i,f in ipairs(index.facts) do if f.family=='quest_observed' and f.details.questID and f.details.title then
            local list=index.questTitles[f.details.questID] or {};index.questTitles[f.details.questID]=list
            list[#list+1]={at=f.observedAt,ref=f.evidenceRef,title=f.details.title}
        end
            if f.family=='quest_turnin' and f.details.questID and (not f.subjectGUID or f.subjectGUID==own) then local rows=index.questTurnins[f.details.questID] or {};index.questTurnins[f.details.questID]=rows;rows[#rows+1]=f end
            if i%128==0 then coroutine.yield() end
        end
        nodes=Sort(nodes,function(a,b) return a.firstObservedAt<b.firstObservedAt or a.firstObservedAt==b.firstObservedAt and a.activityRef<b.activityRef end)
        local priorQuest={}
        for i,f in ipairs(index.facts) do local d=f.details;local node=f.primary and index.byActivity[f.primary]
            if node and d.questID and f.family:match('^quest_') and f.family~='quest_item_received' then
                local lastQuest=priorQuest[d.questID];local old=lastQuest and (lastQuest.node==node and lastQuest.prior or lastQuest)
                if old and old.node~=node and old.at<f.observedAt and old.family~='quest_turnin' then
                    node.links[#node.links+1]={kind=f.family=='quest_turnin' and 'quest_resolved' or f.family=='quest_removed' and 'quest_unresolved' or 'quest_continued',
                        prior=old.node.storyId,questID=d.questID,refs={old.ref,f.evidenceRef},at=old.at}
                end
                priorQuest[d.questID]={node=node,ref=f.evidenceRef,at=f.observedAt,family=f.family,prior=old}
            end
            if i%128==0 then coroutine.yield() end
        end
        local zones,bosses,companions,groups={},{},{},{}
        for _,node in ipairs(nodes) do
            -- Anchor is always available for a conservative scene/place claim.
            local anchor=index.byRef[node.sourceRef];if anchor then AddRef(node,anchor);if anchor.difficultyID~=nil then node.place.difficultyID=anchor.difficultyID end end
            for i,ref in ipairs(node.factRefs) do
                local f=index.byRef[ref];local d=f.details
                if f.family=='group_roster' then for _,member in ipairs(d.members or {}) do
                    local guid=type(member)=='table' and (member.guid or member.GUID) or member
                    if type(guid)=='string' and guid:match('^Player%-') and guid~=own then node.participants[guid]={guid=guid,ref=ref,at=f.observedAt} end
                end
                elseif node.type=='WORLD_PVP' and f.family=='player_combat' and f.subjectGUID then node.participants[f.subjectGUID]={guid=f.subjectGUID,ref=ref,at=f.observedAt}
                elseif (f.family=='encounter_ended' or f.family=='boss_kill_event') and d.encounterID then
                    local key=BossKey(node,d.encounterID)
                    if key then
                        local b=node.encounters[key] or {id=d.encounterID,key=key,failures={},wins={}};node.encounters[key]=b
                        local bucket=d.success==0 and b.failures or (d.success==1 or f.family=='boss_kill_event') and b.wins
                        if bucket then bucket[#bucket+1]={ref=ref,at=f.observedAt} end
                    end
                end
                if i%128==0 then coroutine.yield() end
            end
            for key,b in pairs(node.encounters) do
                local old=bosses[key]
                if old and #old.failures>0 and #b.wins>0 and old.failures[#old.failures].at<b.wins[1].at then
                    node.links[#node.links+1]={kind='later_victory',prior=old.node.storyId,boss=b.id,refs={old.failures[#old.failures].ref,b.wins[1].ref},at=old.node.firstObservedAt}
                end
                if #b.failures>0 then bosses[key]={node=node,failures=b.failures} end
                if node.type=='RAID_RUN' then local group=groups[key] or {};groups[key]=group;group[#group+1]=node end
            end
            local ids={};for guid in pairs(node.participants) do ids[#ids+1]=guid end;table.sort(ids)
            for _,guid in ipairs(ids) do
                local p=node.participants[guid];local old=companions[guid]
                if old and old.node~=node and old.at<p.at then node.links[#node.links+1]={kind=node.type=='WORLD_PVP' and 'recurring_player' or 'recurring_companion',prior=old.node.storyId,guid=guid,refs={old.ref,p.ref},at=old.at};break end
            end
            for guid,p in pairs(node.participants) do companions[guid]={node=node,ref=p.ref,at=p.at} end
            if node.type=='ZONE_VISIT' and node.zoneKey then
                local old=zones[node.zoneKey]
                if old then node.links[#node.links+1]={kind='zone_return',prior=old.storyId,zone=node.zoneKey,refs={old.sourceRef,node.sourceRef},at=old.firstObservedAt} end
                zones[node.zoneKey]=node
            end
            coroutine.yield()
        end
        -- A verified return can enrich a quest/milestone within that exact
        -- visit without promoting the location observation into a new chapter.
        -- Use accepted at-event context membership, never matching names alone.
        local returned={}
        for i,f in ipairs(index.facts) do
            local node=f.primary and index.byActivity[f.primary]
            if node and node.type~='ZONE_VISIT' and node.zoneKey and not returned[node.storyId] then
                for _,ref in ipairs(f.contexts) do
                    local visit=index.byActivity[ref]
                    if visit and visit.type=='ZONE_VISIT' and visit.zoneKey==node.zoneKey then
                        for _,link in ipairs(visit.links) do if link.kind=='zone_return' then
                            node.links[#node.links+1]=ns.AthenaJournal.Copy(link);returned[node.storyId]=true;break
                        end end
                    end
                    if returned[node.storyId] then break end
                end
            end
            if i%128==0 then coroutine.yield() end
        end
        local sagaKeys={};for key in pairs(groups) do sagaKeys[#sagaKeys+1]=key end;table.sort(sagaKeys)
        for _,key in ipairs(sagaKeys) do local episodes=groups[key]
            if #episodes>=2 then
                local first,last=episodes[1],episodes[#episodes];local ref='journal:saga:'..key..':'..first.sourceID
                local saga={activityRef=ref,storyId=X.StoryID(owner,ref),type='SAGA',observer=owner,observerGUID=own,sourceRef=first.sourceRef,sourceID=first.sourceID,
                    place=ns.AthenaJournal.Copy(first.place),firstObservedAt=first.firstObservedAt,lastObservedAt=last.lastObservedAt,unknownStart=true,unknownEnd=true,status='INCOMPLETE',
                    factRefs={},factSet={},links={},episodes={},encounters={},participants={}}
                for _,episode in ipairs(episodes) do
                    saga.episodes[#saga.episodes+1]=episode.storyId
                    saga.links[#saga.links+1]={kind='saga_episode',prior=episode.storyId,refs={episode.sourceRef},at=episode.firstObservedAt}
                    episode.links[#episode.links+1]={kind='saga_overview',prior=saga.storyId,refs={episode.sourceRef,first.sourceRef},at=first.firstObservedAt}
                    for _,r in ipairs(episode.factRefs) do AddRef(saga,index.byRef[r]) end
                end
                index.sagas[#index.sagas+1]=saga;nodes[#nodes+1]=saga;index.byActivity[ref]=saga;index.byStory[saga.storyId]=saga
            end;coroutine.yield()
        end
        index.nodes=Sort(nodes,function(a,b) return a.firstObservedAt>b.firstObservedAt or a.firstObservedAt==b.firstObservedAt and a.activityRef<b.activityRef end)
        if provider.Identity and not index.identity then
            index.identity=provider:Identity(owner)
            if index.identity and index.frontier then index.identity.count=index.frontier.count;index.identity.last=index.identity.events[index.frontier.count] end
        end
        ns.Metis.Project(index)
        -- Capture results may arrive after a run closes. Relate them by the
        -- exact accepted source, never by proximity or a new narrative event.
        index.momentsBySource={}
        for i,f in ipairs(index.facts)do if f.family=='moment_capture'and index.byRef[f.details.sourceRef]then
            local rows=index.momentsBySource[f.details.sourceRef]or{};index.momentsBySource[f.details.sourceRef]=rows
            if #rows<24 then rows[#rows+1]=f.evidenceRef end
        end;if i%128==0 then coroutine.yield()end end
        if ns.Athena.Knowledge then ns.Athena.Knowledge.BindIndex(index) end
        index.done=true;index.status='READY';index.phase='ready'
    end
    index.thread=coroutine.create(Work);return index
end
function X.Pump(index)
    if not index.provider:Allowed() then index.done=true;index.status='DENIED';index.facts={};index.nodes={};index.byRef={};index.byStory={};index.byActivity={};index.aliases={};index.questTitles={};index.sagas={};index.threads=nil;index.narrative=nil;index.metisMemory=nil;index.thread=nil;return index.status end
    if index.done then return index.status end
    local ok,why=coroutine.resume(index.thread)
    if not ok then index.done=true;index.status=tostring(why):match('([A-Z_]+)$') or 'UNAVAILABLE';index.error=tostring(why) end
    return index.status
end
function X.Page(index,cursor)
    if not index.provider:Allowed() then return nil,'DENIED' end
    if cursor and cursor.storyId then local n=index.byStory[cursor.storyId] or index.byActivity[cursor.storyId];return n and {n} or {},nil end
    local offset=type(cursor)=='table' and cursor.offset or 0
    if cursor and (type(cursor)~='table' or cursor.version~=X.VERSION or cursor.owner~=index.owner or cursor.serial~=index.serial
        or type(offset)~='number' or offset%1~=0 or offset<0 or offset>#index.nodes) then return nil,'CURSOR_STALE' end
    local rows={};local i=offset
    while i<#index.nodes and #rows<ns.AthenaJournal.MAX_ACTIVITIES do i=i+1;if not index.nodes[i].suppressed then rows[#rows+1]=index.nodes[i] end end
    return rows,i<#index.nodes and {offset=i,version=X.VERSION,owner=index.owner,serial=index.serial} or nil
end
