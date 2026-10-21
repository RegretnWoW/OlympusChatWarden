-- Rebuildable projections of existing evidence. No collectors or saved database.
local _,ns=...
local S=ns.ChronicleStore
local I={VERSION=3,BUDGET=128,RECENT_LIMIT=120};ns.ChronicleIntelligence=I
local EPS=.001
local personalOnly={time_span=true,time_slice=true,route_segment=true,xp_change=true,money_change=true,quest_turnin=true,quest_accepted=true,
    quest_removed=true,quest_objective=true,quest_log=true,skill_change=true,spell_learned=true,achievement_earned=true,bag_item=true}
local function Own(owner) return owner:match('/(Player%-.+)$') end
local function Add(list,set,id) if not set[id] then set[id]=true;list[#list+1]=id end end
local function Metric() return {seconds=0,afk=0,nonAfk=0,afkUnknown=0,combatSeconds=0,groupContextSeconds=0,categories={},zones={}} end
local function Totals() return {time=Metric(),periods={day={},week={},month={}},calendarUnknown={day=0,week=0,month=0},overlapSeconds=0} end
local function Category(p)
    if p.inInstance==false then return 'open world' end
    if p.inInstance~=true then return 'unknown' end
    return ({party='dungeon',raid='raid',pvp='battleground',arena='arena'})[p.instanceType] or 'other instance'
end
local function PlaceKey(p)
    if not p.inInstance then return 'unknown' end
    return (p.instanceType or '?')..':'..tostring(p.instanceID or '?')..':'..(p.instanceName or p.zone or '?')
end
local function Period(at,kind)
    if kind=='day' then return tostring(math.floor(at/86400)) end
    if kind=='week' then return tostring(math.floor((math.floor(at/86400)+3)/7)) end
    local ok,v=pcall(date or os.date,'!%Y-%m',at);return ok and v or 'unknown'
end
local function Before(a,b) return a.domain<b.domain or a.domain==b.domain and (a.t<b.t or a.t==b.t and a.order<b.order) end
local function Push(i,node)
    i.order=i.order+1;node.order=i.order
    local h=i.heap;local n=#h+1
    while n>1 do local parent=math.floor(n/2);if not Before(node,h[parent]) then break end;h[n]=h[parent];n=parent end
    h[n]=node
end
local function Pop(i)
    local h=i.heap;local first=h[1];local last=table.remove(h)
    if #h>0 then
        local n=1
        while n*2<=#h do
            local child=n*2;if h[child+1] and Before(h[child+1],h[child]) then child=child+1 end
            if not Before(h[child],last) then break end;h[n]=h[child];n=child
        end
        h[n]=last
    end
    return first
end
local function Range(i,scope,lo,hi,kind,data)
    if not scope or not lo or not hi or hi<=lo then return end
    local span={scope=scope.id,kind=kind,data=data}
    local range={domain=scope.domain,lo=lo,hi=hi,span=span};i.ranges[#i.ranges+1]=range
    local domain=i.rangeDomains[scope.domain] or {};i.rangeDomains[scope.domain]=domain;domain[#domain+1]=range
    if i.active and (scope.domain<i.active.domain or scope.domain==i.active.domain and lo<i.active.at) then
        i.needsRebuild=math.min(i.needsRebuild or scope.domain,scope.domain)
    end
    if not i.rebuild then
        Push(i,{domain=scope.domain,t=lo,delta=1,span=span});Push(i,{domain=scope.domain,t=hi,delta=-1,span=span})
    end
end
local function Player(i,guid)
    if ns.Modules and not ns.Modules.Enabled('intel') then return end
    if not S.GUID(guid) or guid==Own(i.owner) then return end
    local p=i.players[guid]
    if not p then
        p={guid=guid,evidence={},evidenceSet={},encounters={},zones={},facts={},credits={own=0,pet=0,group=0,unattributed=0,incoming=0},scoreboards={},scoreGroups={},scoreOrder={},reasons={},publicReports={}}
        i.players[guid]=p
    end
    return p
end
local function Reference(i,e,guid)
    i.events[e.id]=e;Add(i.references,i.referenceSet,e.id)
    local p=Player(i,guid);if p then
        Add(p.evidence,p.evidenceSet,e.id);p.lastEvidenceAt=math.max(p.lastEvidenceAt or e.at,e.at)
        p.enrichment=p.enrichment or {};p.enrichment.context={at=e.at,source=e.source}
        local d=e.details or {};local kind=d.recordType or ''
        local family=e.kind=='group_roster' and 'group' or e.capture and e.capture.family=='scoreboard' and 'pvp'
            or kind=='public_achievement' and 'public' or kind=='aura_effect' and 'combat' or kind:match('^witness_') and 'state'
            or (kind:match('^duel_') or kind=='native_kill_credit' or e.kind=='player_combat') and 'combat'
        if family then p.enrichment[family]={at=e.at,source=e.source} end
        if e.kind=='important_player' and (d.guildName or d.guildRank) then p.enrichment.social={at=e.at,source=e.source} end
    end
    return p
end
local tierReasons=ns.IntelPolicy.labels
local function Reason(p,tier,key,e)
    if not p or not tierReasons[key] then return end
    p.relationship=ns.IntelPolicy.Accumulate(p.relationship,e,p.guid)
    p.tier=p.relationship.tier
    p.reasons[key]={label=tierReasons[key],tier=tier,eventID=e.id,at=e.at}
end
local function Recent(i,kind,e,guid)
    local list=i.recent[kind];local row={event=e,guid=guid,at=e.at,id=e.id}
    -- Only bounded references, rebuilt alongside the existing index. Routine
    -- observations cannot displace milestones, even in very large raw ledgers.
    for n=#list,1,-1 do if list[n].id==row.id then return end end
    local n=#list+1
    while n>1 and (list[n-1].at>row.at or list[n-1].at==row.at and list[n-1].id>row.id) do list[n]=list[n-1];n=n-1 end
    list[n]=row;if #list>I.RECENT_LIMIT then table.remove(list,1) end
end
local function EventReason(p,e)
    if not p then return end
    local tier,key=ns.IntelPolicy.Classify(e,p.guid);Reason(p,tier,key,e)
end
local function Score(st,e,object)
    local i=st.intelligence;local v=object.capture.values;local p=Reference(i,e,v.guid);if not p then return end
    Reason(p,2,'scoreboard',e)
    p.firstScoreAt=math.min(p.firstScoreAt or e.at,e.at);p.lastScoreAt=math.max(p.lastScoreAt or e.at,e.at)
    local key=v.runID and v.matchSequence and (v.runID..'/'..v.matchSequence) or object.id
    local group=p.scoreGroups[key]
    if not group then group={key=key,firstAt=e.at,lastAt=e.at,event=e,object=object};p.scoreGroups[key]=group;p.scoreOrder[#p.scoreOrder+1]=group end
    group.firstAt=math.min(group.firstAt,e.at)
    if e.at>=group.lastAt then group.lastAt=e.at;group.event=e;group.object=object end
    -- These are cache/report groups, never unique matches. No cross-report sum.
    if not p.scoreIdentity or e.at>=p.scoreIdentity.at then p.scoreIdentity={at=e.at,name=v.name,class=v.classToken,race=v.raceName,event=e} end
end
local function Boundary(i,e,reason)
    local scope=i.scope
    if scope then
        scope.endReason=reason;scope.endAt=e.at;scope.closed=true
        if i.group then Range(i,scope,i.group.low,math.min(e.elapsed,i.lastElapsed or e.elapsed),'group');i.group=nil end
    end
    i.combat=nil;i.scope=nil
end
local function NewScope(i,e,hard)
    local scope={id=e.id,session=e.session,domain=i.domain,firstAt=e.at,firstElapsed=e.elapsed,hardStart=hard,
        partialStart=not hard,time=Metric(),pieces={},places={},evidence={}}
    i.scopes[#i.scopes+1]=scope;i.byScope[scope.id]=scope;i.scope=scope;return scope
end
function I.New(owner)
    return {owner=owner,players={},events={},references={},referenceSet={},scopeByEvent={},scopes={},byScope={},domain=0,heap={},ranges={},rangeDomains={},domainTotals={},order=0,time=Metric(),
        periods={day={},week={},month={}},periodEvidence={day={},week={},month={}},calendarUnknown={day=0,week=0,month=0},lastLocal={},
        excludedReportedSeconds=0,overlapSeconds=0,zeroTimeRecords=0,timeEvidence={},
        progression={levels={},xp={},quests={},skills={},equipment={},collections={},achievements={},receipts={},xpObserved=0,rateXP=0,rateSeconds=0},
        cases={},dirtyCase=1,deaths={},deathZones={},visits={},zoneOrder={},scoreboards={},scoreHashes={},
        matchReports={},scoreObjects={},recent={intel={},chronicle={}},duplicateCredits=0,creditKeys={},unknownCombatEnds=0,ready=false}
end
function I.IncludeProfile(st,guid)
    if not ns.Modules.Enabled('intel') then return end
    local i=st.intelligence
    if not i then i=I.New(st.owner);i.events=st.events;st.intelligence=i end
    -- Saved identity/personal information is not historical encounter evidence.
    return Player(i,guid)
end
local function DirtyCases(i,e,lo)
    local left,right=1,#i.cases+1
    while left<right do
        local mid=math.floor((left+right)/2);local c=i.cases[mid]
        if c and (c.domain<i.domain or c.domain==i.domain and c.event.elapsed<lo) then left=mid+1 else right=mid end
    end
    i.dirtyCase=math.min(i.dirtyCase or (#i.cases+1),left)
end
local function TimeRecord(i,e)
    local d=e.details;local lo,hi,first,last
    i.timeEvidence[#i.timeEvidence+1]=e.id;Reference(i,e)
    i.scope.evidence[#i.scope.evidence+1]=e.id
    if e.kind=='time_span' then lo,hi,first,last=d.firstElapsed,d.lastElapsed,d.firstAt,d.lastAt
    else lo,hi=e.elapsed-d.seconds,e.elapsed;first,last=e.at-d.seconds,e.at end
    if d.seconds==0 then i.zeroTimeRecords=i.zeroTimeRecords+1;return end
    local scope=i.scope
    -- Compacted totals with holes do not establish where their measured seconds
    -- lie. Keep them as unallocated evidence, never prorate or fill their holes.
    if lo<0 or math.abs((hi-lo)-d.seconds)>EPS or math.abs(e.elapsed-hi)>EPS
        or scope.hardStart and lo<scope.firstElapsed-EPS
        or i.domainWallFloor and first<i.domainWallFloor then
        i.excludedReportedSeconds=i.excludedReportedSeconds+d.seconds;return
    end
    i.maxWall=math.max(i.maxWall or last,last)
    local data={category=Category(e.location),place=PlaceKey(e.location),zone=e.location.zone or 'unknown',afk=d.afk==true and 'yes' or d.afk==false and 'no' or 'unknown',eventID=e.id}
    for _,kind in ipairs({'day','week','month'}) do
        local a,b=Period(first,kind),Period(last>first and last-EPS or last,kind)
        data[kind]=math.abs(last-first-d.seconds)<=1.001 and a==b and a or 'unknown'
        if data[kind]~='unknown' then
            local refs=i.periodEvidence[kind][data[kind]] or {};i.periodEvidence[kind][data[kind]]=refs;refs[#refs+1]=e.id
        end
    end
    Range(i,scope,lo,hi,'time',data);DirtyCases(i,e,lo)
end
local function Credit(i,e)
    local d=e.details;local own=Own(i.owner)
    if e.source~='PARTY_KILL' or not ns.Chronicle.IntelEnabled() then return end
    local actor,target=S.GUID(d.attackerGUID),S.GUID(d.targetGUID)
    if (not actor or actor==own) and (not target or target==own) then return end
    -- Exact duplicates can share only this scope and native clock position.
    -- Earlier positions cannot recur without Feed opening another clock scope.
    -- Keep one bucket, rather than a string key for every historical creature.
    local window=table.concat({i.scope.id,tostring(e.at),tostring(e.elapsed)},'/')
    if i.creditWindow~=window then i.creditWindow=window;i.creditKeys={} end
    local key=table.concat({d.attackerGUID,d.targetGUID,d.credit},'/')
    if i.creditKeys[key] then i.duplicateCredits=i.duplicateCredits+1;return end;i.creditKeys[key]=e.id
    local attacker=Reference(i,e,d.attackerGUID)
    if attacker then
        attacker.combat=attacker.combat or {}
        local key=d.entityKind=='Player' and 'playerCredits' or (d.entityKind=='Creature' or d.entityKind=='Vehicle') and 'creatureCredits'
        if key then attacker.combat[key]=(attacker.combat[key] or 0)+1 end
        EventReason(attacker,e);Recent(i,'intel',e,attacker.guid)
    end
    if d.entityKind=='Player' and d.targetGUID~=own then
        local p=Reference(i,e,d.targetGUID);if not p then return end
        local kind=d.credit=='self native credit' and d.attackerGUID==own and 'own'
            or d.credit=='current pet native credit' and d.attackerGUID:match('^Pet%-') and 'pet'
            or d.credit=='group native credit' and d.attackerGUID~=own and 'group' or 'unattributed'
        p.credits[kind]=p.credits[kind]+1;p.creditFirst=p.creditFirst or e.at;p.creditLast=e.at
        p.combat=p.combat or {}
        local key=S.GUID(d.attackerGUID) and 'victimCredits' or 'otherVictimCredits'
        p.combat[key]=(p.combat[key] or 0)+1
        EventReason(p,e);Recent(i,'intel',e,p.guid)
    elseif S.GUID(d.attackerGUID) and d.attackerGUID~=own then
        if d.targetGUID==own then local p=attacker;p.credits.incoming=p.credits.incoming+1;p.creditFirst=p.creditFirst or e.at;p.creditLast=e.at end
    end
end
function I.Feed(st,e)
    if ns.Modules and not ns.Modules.Enabled('chronicle') and personalOnly[e.kind] then return end
    local i=st.intelligence;if not i then i=I.New(st.owner);i.events=st.events;st.intelligence=i end
    i.ready=false;i.aggregate=nil;local d=e.details
    -- Tiny source-backed freshness references in the existing projection. This
    -- is not another history scan, player database, or saved status ledger.
    local cap=e.capture
    if cap and (cap.family=='gear' or cap.family=='traits' or cap.family=='appearance') then
        local p=Player(i,cap.values.guid)
        if p then p.enrichment=p.enrichment or {};p.enrichment[cap.family=='traits' and 'talents' or cap.family]={object=e,at=e.at,source=e.source} end
    elseif e.kind=='important_player' or d.recordType=='duel_capture' then
        local p=Player(i,e.subject)
        if p then
            p.enrichment=p.enrichment or {}
            for key,family in pairs({gear='gear',trait='talents',appearance='appearance'}) do
                local object=d[key..'Ref'] and ns.ChronicleCapture.Find(st.owner,d[key..'Ref'])
                if object and object.capture.values.guid==e.subject then
                    p.enrichment[family]={object=object,at=d[key..'ObservedAt'] or e.at,source=e.source}
                end
            end
        end
    end
    local newClock=i.session~=e.session or i.lastElapsed and e.elapsed<i.lastElapsed or i.timeSource~=e.timeSource
    if newClock then
        Boundary(i,e,'recording clock boundary');i.domain=i.domain+1;i.domainWallFloor=i.maxWall
        i.session=e.session;i.timeSource=e.timeSource
    end
    if e.kind=='recording_start' or e.kind=='collection_gap' then Boundary(i,e,e.kind) end
    if not i.scope then NewScope(i,e,e.kind=='recording_start' or e.kind=='collection_gap') end
    local scope=i.scope
    if e.kind=='instance_enter' or e.kind=='location' or e.kind=='group_roster' or e.kind=='native_event' then i.scopeByEvent[e.id]=scope.id end
    if e.kind=='time_span' or e.kind=='time_slice' then TimeRecord(i,e) end
    if e.kind=='player_observed' and e.subject then
        local p=Reference(i,e,e.subject)
        if p then
            p.facts[#p.facts+1]=e
            local localSource=ns.IntelPolicy.localSources[e.source]
            if d.localSighting==true and localSource then
                EventReason(p,e)
                local previous=i.lastLocal[e.subject]
                local separated=not previous or previous.domain==i.domain and e.elapsed-previous.elapsed>=ns.Chronicle.ENCOUNTER_GAP
                    or previous and previous.domain~=i.domain and previous.timeSource=='server' and e.timeSource=='server' and e.at-previous.at>=ns.Chronicle.ENCOUNTER_GAP
                if d.encounter==true and separated then
                    p.encounters[#p.encounters+1]=e.id;p.firstEncounter=p.firstEncounter or e.at;p.lastEncounter=e.at
                    local zone=e.location.zone or 'unknown';p.zones[zone]=(p.zones[zone] or 0)+1
                    if p.tier==1 or d.wantedListed==true then Recent(i,'intel',e,p.guid) end
                end
                i.lastLocal[e.subject]={domain=i.domain,elapsed=e.elapsed,at=e.at,timeSource=e.timeSource}
                p.lastLocalAt=e.at
            end
        end
    elseif e.kind=='native_event' and (d.recordType=='friend_status' or d.recordType=='guild_member_observed') then
        local p=Reference(i,e,e.subject)
        if p then
            if d.recordType=='friend_status' then p.friendObservation={active=d.after,at=e.at,sourceID=e.id}
            else p.guildObservation={guildName=d.guildName,guildRealm=d.guildRealm,rank=d.guildRank,at=e.at,sourceID=e.id} end
            p.enrichment.social={at=e.at,source=e.source}
        end
    elseif e.kind=='important_player' then
        local p=Reference(i,e,e.subject)
        if p and e.source=='INSPECT_READY' and d.relationship=='manual inspection' then p.lastInspection=e.at end
        if p and ns.IntelPolicy.important[d.relationship]
            and (d.relationship~='manual inspection' or e.source=='INSPECT_READY') then
            Reason(p,1,d.relationship,e)
            if e.source=='INSPECT_READY' or d.unitVisible==true then Recent(i,'intel',e,p.guid) end
        end
    elseif e.kind=='player_combat' or e.kind=='player_kill_credit' then
        local p=Reference(i,e,e.subject);if p then p.legacyRecords=(p.legacyRecords or 0)+1 end
    elseif e.kind=='group_roster' then
        for _,guid in ipairs(d.members) do local p=Reference(i,e,guid);if p then p.rosterFirst=p.rosterFirst or e.at;p.rosterLast=e.at;Reason(p,2,'roster',e) end end
        if #d.members>0 and not i.group then i.group={low=e.elapsed}
        elseif #d.members==0 and i.group then Range(i,scope,i.group.low,e.elapsed,'group');i.group=nil end
    elseif e.kind=='native_snapshot' and e.capture.family=='scoreboard' then
        local v=e.capture.values;local p=Reference(i,e,v.guid)
        i.scoreObjects[d.contentID]=e;Score(st,e,e)
        if not i.scoreHashes[d.contentID] then
            i.scoreHashes[d.contentID]=e.id;i.scoreboards[#i.scoreboards+1]=e.id;if p then p.scoreboards[#p.scoreboards+1]=e.id end
        end
    elseif e.kind=='olympus_snapshot' then
        for _,row in ipairs(e.snapshot.rows) do
            local guid=row.values and row.values.guid;local p=Reference(i,e,guid)
            if p then p.publicReports[#p.publicReports+1]={eventID=e.id,row=row,kind=e.snapshot.kind,mode=e.snapshot.mode} end
        end
    end
    if e.kind=='native_event' then
        Reference(i,e)
        if d.recordType=='pvp_score_row' and i.scoreObjects[d.contentID] then Score(st,e,i.scoreObjects[d.contentID]) end
        if d.recordType=='public_achievement' then
            -- The collector already verified the GUID and native announcement
            -- scope. Retaining it globally is insufficient: attach the original
            -- reference to this dossier without claiming a local encounter.
            local p=Reference(i,e,e.subject)
            if p then Recent(i,'intel',e,p.guid) end
        elseif d.recordType=='duel_session_start' and e.source=='DUEL_COUNTDOWN' and d.accepted==true and S.GUID(d.opponentGUID) then
            local p=Reference(i,e,d.opponentGUID);if p then Reason(p,2,'verified duel opponent',e);Recent(i,'intel',e,p.guid);Recent(i,'chronicle',e,p.guid) end
        elseif d.recordType=='duel_session_end' and d.accepted==true then Reference(i,e,d.opponentGUID);Recent(i,'chronicle',e,d.opponentGUID)
        elseif d.recordType=='duel_session_result' or d.recordType=='duel_combat_summary' then Reference(i,e,d.opponentGUID)
        elseif d.recordType=='native_kill_credit' then Credit(i,e)
        elseif ns.AthenaObservationSchema and ns.AthenaObservationSchema.types[d.recordType] then
            Reference(i,e,e.subject) -- Provisional observations never earn priority.
        elseif d.recordType=='aura_effect' or d.recordType=='aura_partial' or d.recordType=='contact_observed' or d.recordType=='contact_inspection_attempt' then
            -- Reuse the original source reference; observing an effect cannot
            -- earn relationship priority or count as a spell cast.
            Reference(i,e,e.subject)
        elseif d.recordType:find('witness_',1,true)==1 then
            local p=Reference(i,e,e.subject)
            if p then
                p.combat=p.combat or {};local combat=p.combat
                if d.recordType=='witness_death' then
                    if d.method=='native death' then combat.nativeDeaths=(combat.nativeDeaths or 0)+1
                    else combat.deadTransitions=(combat.deadTransitions or 0)+1 end
                    Reason(p,2,'death',e);Recent(i,'intel',e,p.guid)
                elseif d.recordType=='witness_recovery' then combat.recoveries=(combat.recoveries or 0)+1
                elseif d.recordType=='witness_ability' then combat.abilities=(combat.abilities or 0)+1
                elseif d.recordType=='witness_state' then combat.stateObservations=(combat.stateObservations or 0)+1 end
                combat.lastAt=e.at
            end
        elseif d.recordType=='combat_started' and e.source=='PLAYER_REGEN_DISABLED' then
            if not i.combat or i.combat.low~=e.elapsed then i.combat={low=e.elapsed,scope=scope.id} end
        elseif d.recordType=='combat_ended' and e.source=='PLAYER_REGEN_ENABLED' then
            if i.combat and i.combat.scope==scope.id and d.combatSeconds and math.abs(e.elapsed-i.combat.low-d.combatSeconds)<=EPS then
                Range(i,scope,i.combat.low,e.elapsed,'combat')
            else i.unknownCombatEnds=i.unknownCombatEnds+1 end;i.combat=nil
        elseif d.recordType=='pvp_match_complete' and e.source=='PVP_MATCH_COMPLETE' then Reference(i,e);i.matchReports[#i.matchReports+1]=e.id end
    end
    if e.kind=='player_death' then
        Reference(i,e);i.deaths[#i.deaths+1]=e.id;local zone=e.location.zone or 'unknown';i.deathZones[zone]=(i.deathZones[zone] or 0)+1
    end
    if e.kind=='location' then
        local zone=e.location.zone
        if zone then
            local v=i.visits[zone]
            if not v then v={zone=zone,firstAt=e.at,evidence={}};i.visits[zone]=v;i.zoneOrder[#i.zoneOrder+1]=zone end
            if i.previousZone~=zone then v.evidence[#v.evidence+1]=e.id;v.lastAt=e.at end;i.previousZone=zone;Reference(i,e)
        end
    end
    local collection=d.recordType=='collection_added';local category=({level_change='levels',xp_change='xp',quest_turnin='quests',
        skill_change='skills',equipment_change='equipment',achievement_earned='achievements'})[e.kind] or collection and 'collections'
        or e.kind=='native_event' and d.recordType=='quest_item_received' and 'receipts'
    if category then
        Reference(i,e);i.progression[category][#i.progression[category]+1]=e.id
        if category=='xp' or category=='levels' then
            local case={event=e,scope=scope.id,domain=i.domain,previous=scope[category],
                knownLevel=scope.levels and scope.levels.event.details.after}
            scope[category]=case;i.cases[#i.cases+1]=case;i.dirtyCase=math.min(i.dirtyCase or #i.cases,#i.cases)
            if category=='xp' then i.progression.xpObserved=i.progression.xpObserved+d.delta end
        end
    end
    if ({level_change=true,quest_turnin=true,skill_change=true,achievement_earned=true,equipment_change=true,player_death=true,spell_learned=true})[e.kind]
        or e.kind=='native_event' and ({encounter_ended=true,boss_kill_event=true,pvp_match_complete=true,collection_added=true})[d.recordType] then
        Reference(i,e);Recent(i,'chronicle',e)
    end
    if e.kind=='recording_stop' then Boundary(i,e,'recording stopped') end
    i.lastElapsed=e.elapsed;i.lastAt=e.at;i.revision=st.revision
end
local function Adjust(map,key,delta) map[key]=(map[key] or 0)+delta;if map[key]==0 then map[key]=nil end end
local function Single(map,total)
    local key,count=next(map);if key and count==total and next(map,key)==nil then return key end
    return 'unknown'
end
local function Accumulate(m,n,v)
    m.seconds=m.seconds+n
    if v.afk=='yes' then m.afk=m.afk+n elseif v.afk=='no' then m.nonAfk=m.nonAfk+n else m.afkUnknown=m.afkUnknown+n end
    m.categories[v.category]=(m.categories[v.category] or 0)+n;m.zones[v.zone]=(m.zones[v.zone] or 0)+n
    if v.combat then m.combatSeconds=m.combatSeconds+n end
    if v.group then m.groupContextSeconds=m.groupContextSeconds+n end
end
local function Commit(i,active,lo,hi)
    local n=hi-lo;if n<=0 or active.time==0 then return end
    local v={};for _,dim in ipairs({'category','place','zone','afk','scope','day','week','month'}) do v[dim]=Single(active[dim],active.time) end
    v.combat=(active.combat[v.scope] or 0)>0;v.group=(active.group[v.scope] or 0)>0
    -- Keep a small total per recording clock. A late combat/group interval can
    -- then replay its affected clocks without replaying every previous session.
    local totals=i.domainTotals[active.domain]
    if not totals then totals=Totals();i.domainTotals[active.domain]=totals end
    Accumulate(totals.time,n,v);if active.time>1 then totals.overlapSeconds=totals.overlapSeconds+n end
    i.totalsDirty=true
    local scope=i.byScope[v.scope]
    if scope then
        Accumulate(scope.time,n,v);local pieces=scope.pieces;local prev=pieces[#pieces]
        pieces[#pieces+1]={lo=lo,hi=hi,total=(prev and prev.total or 0)+n}
        local places=scope.places[v.place] or {};scope.places[v.place]=places;local last=places[#places]
        places[#places+1]={lo=lo,hi=hi,total=(last and last.total or 0)+n}
    end
    for _,kind in ipairs({'day','week','month'}) do
        local key=v[kind]
        if key~='unknown' then local m=totals.periods[kind][key];if not m then m=Metric();totals.periods[kind][key]=m end;Accumulate(m,n,v)
        else totals.calendarUnknown[kind]=totals.calendarUnknown[kind]+n end
    end
end
local function Prefix(pieces,t)
    local low,high=1,#pieces+1
    while low<high do local mid=math.floor((low+high)/2);if pieces[mid] and pieces[mid].hi<=t then low=mid+1 else high=mid end end
    local prior=pieces[low-1];local value=prior and prior.total or 0;local p=pieces[low]
    if p and p.lo<t then value=value+math.min(t,p.hi)-p.lo end
    return value
end
function I.Measure(st,scopeID,lo,hi,place)
    local scope=st.intelligence and st.intelligence.byScope[scopeID]
    if not scope or not lo or not hi or hi<lo then return end
    local pieces=place and scope.places[place] or scope.pieces
    if not pieces then return 0 end
    return math.max(0,Prefix(pieces,hi)-Prefix(pieces,lo))
end
function I.ActivityTime(st,a)
    local i=st.intelligence;local scopeID=i and i.scopeByEvent[a.anchor]
    return I.Measure(st,scopeID,a.firstElapsed,a.endElapsed or a.lastElapsed,a.instanceKey)
end
local function ProjectCase(st,c)
    local i=st.intelligence;local prev=c.previous
    if c.rateSeconds then i.progression.rateSeconds=i.progression.rateSeconds-c.rateSeconds;i.progression.rateXP=i.progression.rateXP-c.event.details.delta end
    c.rateSeconds=nil;c.xpPerHour=nil;c.measuredBetween=nil;c.completeCoverage=nil
    if not prev or prev.scope~=c.scope or c.event.elapsed<=prev.event.elapsed then return end
    local seconds=I.Measure(st,c.scope,prev.event.elapsed,c.event.elapsed);c.measuredBetween=seconds
    c.completeCoverage=math.abs(seconds-(c.event.elapsed-prev.event.elapsed))<=EPS
    local d,p=c.event.details,prev.event.details
    if c.event.kind=='xp_change' and c.completeCoverage and seconds>0 and d.before==p.after and d.beforeLevel==p.afterLevel
        and (not c.knownLevel or d.afterLevel>=c.knownLevel) then
        c.xpPerHour=d.delta*3600/seconds;c.rateSeconds=seconds
        i.progression.rateSeconds=i.progression.rateSeconds+seconds;i.progression.rateXP=i.progression.rateXP+d.delta
    end
end
-- Endpoint heap/sweep unions overlapping intervals and reconciles contradictory
-- dimensions as unknown. No full-history sort or unbounded finalization step.
function I.Finish(st,budget,deadline)
    local i=st.intelligence;if not i then return true end
    local P=ns.WardenPerformance;deadline=deadline or P.Begin()
    if i.needsRebuild and not i.rebuild then
        local first=i.needsRebuild
        i.rebuild=coroutine.create(function()
            -- Scopes and ranges share their original references. No history is
            -- discarded, re-encoded or duplicated by this disposable index.
            for _,scope in ipairs(i.scopes) do
                if scope.domain>=first then scope.time=Metric();scope.pieces={};scope.places={} end
                coroutine.yield()
            end
            for domain=first,i.domain do
                i.domainTotals[domain]=nil;coroutine.yield()
                for _,v in ipairs(i.rangeDomains[domain] or {}) do
                    Push(i,{domain=v.domain,t=v.lo,delta=1,span=v.span});Push(i,{domain=v.domain,t=v.hi,delta=-1,span=v.span})
                    coroutine.yield()
                end
            end
        end)
        i.heap={};i.active=nil;i.aggregate=nil;i.totalsDirty=true
        local left,right=1,#i.cases+1
        while left<right do local mid=math.floor((left+right)/2);if i.cases[mid] and i.cases[mid].domain<first then left=mid+1 else right=mid end end
        i.dirtyCase=math.min(i.dirtyCase or left,left);i.swept=nil;i.needsRebuild=nil
    end
    if i.rebuild then
        for _=1,(budget or I.BUDGET) do
            if P.Expired(deadline) then return false end
            local ok,why=coroutine.resume(i.rebuild);if not ok then error(why) end
            if coroutine.status(i.rebuild)=='dead' then i.rebuild=nil;break end
        end
        if i.rebuild then return false end
    end
    local used=0
    while #i.heap>0 and used<(budget or I.BUDGET) do
        if P.Expired(deadline) then return false end
        local node=Pop(i);local a=i.active
        if not a or a.domain~=node.domain then
            a={domain=node.domain,at=node.t,time=0,category={},place={},zone={},afk={},scope={},day={},week={},month={},combat={},group={}};i.active=a
        end
        Commit(i,a,a.at,node.t);a.at=node.t
        local span,delta=node.span,node.delta
        if span.kind=='time' then
            a.time=a.time+delta
            for _,dim in ipairs({'category','place','zone','afk','day','week','month'}) do Adjust(a[dim],span.data[dim],delta) end
            Adjust(a.scope,span.scope,delta)
        else Adjust(a[span.kind],span.scope,delta) end
        used=used+1
    end
    if #i.heap>0 then return false end
    if i.totalsDirty then
        i.aggregate=i.aggregate or coroutine.create(function()
            i.time=Metric();i.periods={day={},week={},month={}};i.calendarUnknown={day=0,week=0,month=0};i.overlapSeconds=0
            local function Merge(to,from)
                for _,key in ipairs({'seconds','afk','nonAfk','afkUnknown','combatSeconds','groupContextSeconds'}) do to[key]=to[key]+from[key] end
                for _,map in ipairs({'categories','zones'}) do for key,value in pairs(from[map]) do to[map][key]=(to[map][key] or 0)+value;coroutine.yield() end end
            end
            for domain=1,i.domain do local totals=i.domainTotals[domain]
                if totals then
                    Merge(i.time,totals.time);i.overlapSeconds=i.overlapSeconds+totals.overlapSeconds
                    for _,kind in ipairs({'day','week','month'}) do
                        i.calendarUnknown[kind]=i.calendarUnknown[kind]+totals.calendarUnknown[kind]
                        for key,value in pairs(totals.periods[kind]) do
                            local m=i.periods[kind][key] or Metric();i.periods[kind][key]=m;Merge(m,value);coroutine.yield()
                        end
                    end
                end
                coroutine.yield()
            end
        end)
        while used<(budget or I.BUDGET) and not P.Expired(deadline) do
            local ok,why=coroutine.resume(i.aggregate);if not ok then error(why) end;used=used+1
            if coroutine.status(i.aggregate)=='dead' then i.aggregate=nil;i.totalsDirty=nil;break end
        end
        if i.totalsDirty then return false end
    end
    i.swept=true
    local index=i.dirtyCase or #i.cases+1
    while index<=#i.cases and used<(budget or I.BUDGET) and not P.Expired(deadline) do ProjectCase(st,i.cases[index]);index=index+1;used=used+1 end
    i.dirtyCase=index;if index<=#i.cases then return false end
    i.ready=true;return true
end
function I.Player(st,guid)
    local i=st and st.intelligence;local p=i and i.players[guid]
    local c=st and S.Character(st.owner,false);local revision=c and c.revision
    if p and p.summary and p.summaryRevision==i.revision and p.profileRevision==revision then return p.summary end
    local out={guid=guid,recordedEncounters=0,credits={own=0,pet=0,group=0,unattributed=0,incoming=0},zones={},evidence={},scoreboards={},publicReports={},
        confirmedKillingBlows=nil,confirmedDeathsByPlayer=nil,headToHeadRatio=nil,exactGroupedSeconds=nil,performance=nil}
    if p then
        out.recordedEncounters=#p.encounters;out.firstEncounter=p.firstEncounter;out.lastEncounter=p.lastEncounter;out.lastLocalAt=p.lastLocalAt
        out.firstRoster=p.rosterFirst;out.lastRoster=p.rosterLast;out.lastInspection=p.lastInspection;out.credits=p.credits;out.zones=p.zones
        out.evidence=p.evidence;out.scoreboards=p.scoreboards;out.publicReports=p.publicReports;out.facts=p.facts;out.legacyRecords=p.legacyRecords
        out.lastEvidenceAt=p.lastEvidenceAt;out.scoreIdentity=p.scoreIdentity;out.scoreReports=p.scoreOrder
        out.combat=p.combat
        out.firstScoreAt=p.firstScoreAt;out.lastScoreAt=p.lastScoreAt
    end
    local personal=c and c.profiles[guid] and c.profiles[guid].personal
    out.note=personal and personal.note;out.watch=personal and personal.watch==true or false
    out.tier=out.watch and 1 or p and (p.tier or #p.evidence>0 and 3)
    out.earnedTier=p and p.relationship and p.relationship.earnedTier or 3
    out.effectiveCaptureTier=out.tier
    out.tierLabel=({[1]='Important player',[2]='Activity participant',[3]='Casual encounter'})[out.tier] or (#out.publicReports>0 and 'Olympus source only' or out.note and #out.evidence==0 and 'Personal note only' or 'Unclassified evidence')
    out.tierReasons={}
    if out.earnedTier==1 then out.tierReasons[#out.tierReasons+1]={label='Recurring shared activity',tier=1,eventID=p.relationship.promotionID,at=p.relationship.promotionAt} end
    if out.watch then out.tierReasons[#out.tierReasons+1]={label='On your current watchlist',tier=1} end
    if p then for _,r in pairs(p.reasons or {}) do if r.tier==out.tier then out.tierReasons[#out.tierReasons+1]=r end end end
    table.sort(out.tierReasons,function(a,b) return a.label<b.label end)
    local direct=out.credits.own+out.credits.pet+out.credits.incoming
    out.description=out.watch and 'Personal watchlist' or direct>0 and 'Recorded native PvP credit history'
        or out.recordedEncounters>1 and 'Repeated local encounters' or out.recordedEncounters==1 and 'Previously encountered'
        or out.lastInspection and 'Manually inspected' or out.firstRoster and 'Recorded roster history' or #out.publicReports>0 and 'Public Olympus records'
        or out.note and #out.evidence==0 and 'Saved personal note' or 'Recorded source observations'
    if p then p.summary=out;p.summaryRevision=i.revision;p.profileRevision=revision end
    return out
end
function I.Query(st,filter)
    filter=filter or {};local i=st and st.intelligence;local out={};if not i then return out end
    local p=filter.guid and i.players[filter.guid];if filter.guid and not p then return out end
    local refs=p and p.evidence or filter.refs or i.references;local first=filter.offset or 0;local matched=0
    for index=#refs,1,-1 do
        local e=i.events[refs[index]] or st.events[refs[index]]
        if e and (not filter.kind or e.kind==filter.kind) and (not filter.source or e.source==filter.source)
            and (not filter.certainty or e.evidence==filter.certainty) and (not filter.since or e.at>=filter.since)
            and (not filter.untilAt or e.at<=filter.untilAt) and (not filter.zone or e.location.zone==filter.zone)
            and (not filter.activityID or st.links[e.id] and st.links[e.id][filter.activityID])
            and (not filter.encounterID or e.details.encounterID==filter.encounterID)
            and (not filter.instanceID or e.location.instanceID==filter.instanceID) then
            matched=matched+1;if matched>first then out[#out+1]=e;if #out>=(filter.limit or 50) then break end end
        end
    end
    return out
end
function I.ResolveName(st,name,at)
    local result={};if type(name)~='string' then return result end
    name=name:lower()
    for guid in pairs(st.identities) do
        local known=ns.ChronicleActivities.Name(st,guid,at)
        if known:lower()==name then result[#result+1]=guid end
    end
    table.sort(result);return result -- Ambiguous names return every known GUID.
end
