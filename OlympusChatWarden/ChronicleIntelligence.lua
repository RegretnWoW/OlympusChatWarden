-- Rebuildable projections of existing evidence. No collectors or saved database.
local _,ns=...
local S=ns.ChronicleStore
local I={VERSION=2,BUDGET=128,RECENT_LIMIT=120};ns.ChronicleIntelligence=I
local EPS=.001
local function Own(owner) return owner:match('/(Player%-.+)$') end
local function Add(list,set,id) if not set[id] then set[id]=true;list[#list+1]=id end end
local function Metric() return {seconds=0,afk=0,nonAfk=0,afkUnknown=0,combatSeconds=0,groupContextSeconds=0,categories={},zones={}} end
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
    if i.active and (scope.domain<i.active.domain or scope.domain==i.active.domain and lo<i.active.at) then i.needsRebuild=true end
    if not i.rebuild then
        Push(i,{domain=scope.domain,t=lo,delta=1,span=span});Push(i,{domain=scope.domain,t=hi,delta=-1,span=span})
    end
end
local function Player(i,guid)
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
    local p=Player(i,guid);if p then Add(p.evidence,p.evidenceSet,e.id);p.lastEvidenceAt=math.max(p.lastEvidenceAt or e.at,e.at) end
    return p
end
local tierReasons={['party teammate']='Recorded party teammate',['raid teammate']='Recorded raid teammate',
    ['encountered friend']='GUID-matched friend',['personal bookmark']='Personal bookmark',
    ['manual inspection']='Deliberately inspected',['Wanted encounter']='Direct Wanted observation',['verified duel opponent']='Verified duel opponent',
    ['native opponent']='Personal native credit evidence',roster='Recorded group roster',scoreboard='GUID-bearing scoreboard',localUnit='Direct local observation'}
local function Reason(p,tier,key,e)
    if not p or not tierReasons[key] then return end
    p.tier=math.min(p.tier or tier,tier)
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
    return {owner=owner,players={},events={},references={},referenceSet={},scopeByEvent={},scopes={},byScope={},domain=0,heap={},ranges={},order=0,time=Metric(),
        periods={day={},week={},month={}},periodEvidence={day={},week={},month={}},calendarUnknown={day=0,week=0,month=0},lastLocal={},
        excludedReportedSeconds=0,overlapSeconds=0,zeroTimeRecords=0,timeEvidence={},
        progression={levels={},xp={},quests={},skills={},equipment={},collections={},achievements={},xpObserved=0,rateXP=0,rateSeconds=0},
        cases={},dirtyCase=1,deaths={},deathZones={},visits={},zoneOrder={},scoreboards={},scoreHashes={},
        matchReports={},scoreObjects={},recent={intel={},chronicle={}},duplicateCredits=0,creditKeys={},unknownCombatEnds=0,ready=false}
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
    if e.source~='PARTY_KILL' or d.entityKind~='Player' then return end
    local key=table.concat({i.scope.id,tostring(e.at),tostring(e.elapsed),d.attackerGUID,d.targetGUID,d.credit},'/')
    if i.creditKeys[key] then i.duplicateCredits=i.duplicateCredits+1;return end;i.creditKeys[key]=e.id
    if d.targetGUID~=own then
        local p=Reference(i,e,d.targetGUID);if not p then return end
        local kind=d.credit=='self native credit' and d.attackerGUID==own and 'own'
            or d.credit=='current pet native credit' and d.attackerGUID:match('^Pet%-') and 'pet'
            or d.credit=='group native credit' and d.attackerGUID~=own and 'group' or 'unattributed'
        p.credits[kind]=p.credits[kind]+1;p.creditFirst=p.creditFirst or e.at;p.creditLast=e.at
        if kind=='own' or kind=='pet' then Reason(p,1,'native opponent',e);Recent(i,'intel',e,p.guid) end
    elseif S.GUID(d.attackerGUID) and d.attackerGUID~=own then
        local p=Reference(i,e,d.attackerGUID);p.credits.incoming=p.credits.incoming+1;p.creditFirst=p.creditFirst or e.at;p.creditLast=e.at
        Reason(p,1,'native opponent',e);Recent(i,'intel',e,p.guid)
    end
end
function I.Feed(st,e)
    local i=st.intelligence;if not i then i=I.New(st.owner);i.events=st.events;st.intelligence=i end
    i.ready=false;local d=e.details
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
            local localSource=e.source=='PLAYER_TARGET_CHANGED' or e.source=='UPDATE_MOUSEOVER_UNIT' or e.source=='PLAYER_FOCUS_CHANGED'
            if d.localSighting==true and localSource then
                Reason(p,3,'localUnit',e)
                local previous=i.lastLocal[e.subject]
                local separated=not previous or previous.domain==i.domain and e.elapsed-previous.elapsed>=ns.Chronicle.ENCOUNTER_GAP
                    or previous and previous.domain~=i.domain and previous.timeSource=='server' and e.timeSource=='server' and e.at-previous.at>=ns.Chronicle.ENCOUNTER_GAP
                if d.encounter==true and separated then
                    p.encounters[#p.encounters+1]=e.id;p.firstEncounter=p.firstEncounter or e.at;p.lastEncounter=e.at
                    local zone=e.location.zone or 'unknown';p.zones[zone]=(p.zones[zone] or 0)+1
                    if p.tier==1 or d.wantedListed==true then Recent(i,'intel',e,p.guid) end
                end
                if d.wantedListed==true then Reason(p,1,'Wanted encounter',e) end
                i.lastLocal[e.subject]={domain=i.domain,elapsed=e.elapsed,at=e.at,timeSource=e.timeSource}
                p.lastLocalAt=e.at
            end
        end
    elseif e.kind=='important_player' then
        local p=Reference(i,e,e.subject)
        if p and e.source=='INSPECT_READY' and d.relationship=='manual inspection' then p.lastInspection=e.at end
        if p and ({['party teammate']=true,['raid teammate']=true,['encountered friend']=true,['personal bookmark']=true,['manual inspection']=true,['Wanted encounter']=true,['verified duel opponent']=true})[d.relationship]
            and (d.relationship~='manual inspection' or e.source=='INSPECT_READY') then
            Reason(p,1,d.relationship,e)
            if e.source=='INSPECT_READY' or d.unitVisible==true then Recent(i,'intel',e,p.guid) end
        end
    elseif e.kind=='player_combat' or e.kind=='player_kill_credit' then
        local p=Reference(i,e,e.subject);if p then p.legacyRecords=(p.legacyRecords or 0)+1 end
    elseif e.kind=='group_roster' then
        for _,guid in ipairs(d.members) do local p=Reference(i,e,guid);if p then p.rosterFirst=p.rosterFirst or e.at;p.rosterLast=e.at;Reason(p,1,'roster',e) end end
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
        if d.recordType=='duel_session_start' and e.source=='DUEL_COUNTDOWN' and d.accepted==true and S.GUID(d.opponentGUID) then
            local p=Reference(i,e,d.opponentGUID);if p then Reason(p,1,'verified duel opponent',e);Recent(i,'intel',e,p.guid);Recent(i,'chronicle',e,p.guid) end
        elseif d.recordType=='duel_session_end' and d.accepted==true then Recent(i,'chronicle',e,d.opponentGUID)
        elseif d.recordType=='native_kill_credit' then Credit(i,e)
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
    Accumulate(i.time,n,v);if active.time>1 then i.overlapSeconds=i.overlapSeconds+n end
    local scope=i.byScope[v.scope]
    if scope then
        Accumulate(scope.time,n,v);local pieces=scope.pieces;local prev=pieces[#pieces]
        pieces[#pieces+1]={lo=lo,hi=hi,total=(prev and prev.total or 0)+n}
        local places=scope.places[v.place] or {};scope.places[v.place]=places;local last=places[#places]
        places[#places+1]={lo=lo,hi=hi,total=(last and last.total or 0)+n}
    end
    for _,kind in ipairs({'day','week','month'}) do
        local key=v[kind]
        if key~='unknown' then local m=i.periods[kind][key];if not m then m=Metric();i.periods[kind][key]=m end;Accumulate(m,n,v)
        else i.calendarUnknown[kind]=i.calendarUnknown[kind]+n end
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
        i.rebuild={phase='scopes',index=1};i.heap={};i.active=nil;i.time=Metric()
        i.periods={day={},week={},month={}};i.calendarUnknown={day=0,week=0,month=0}
        i.overlapSeconds=0;i.dirtyCase=1;i.swept=nil;i.needsRebuild=nil
    end
    if i.rebuild then
        local r=i.rebuild
        for _=1,(budget or I.BUDGET) do
            if P.Expired(deadline) then return false end
            if r.phase=='scopes' then
                local scope=i.scopes[r.index]
                if scope then scope.time=Metric();scope.pieces={};scope.places={};r.index=r.index+1
                else r.phase='ranges';r.index=1 end
            else
                local v=i.ranges[r.index]
                if v then
                    Push(i,{domain=v.domain,t=v.lo,delta=1,span=v.span});Push(i,{domain=v.domain,t=v.hi,delta=-1,span=v.span});r.index=r.index+1
                else i.rebuild=nil;break end
            end
        end
        return false
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
    i.swept=true
    local index=i.dirtyCase or #i.cases+1
    while index<=#i.cases and used<(budget or I.BUDGET) and not P.Expired(deadline) do ProjectCase(st,i.cases[index]);index=index+1;used=used+1 end
    i.dirtyCase=index;if index<=#i.cases then return false end
    i.ready=true;return true
end
function I.Player(st,guid)
    local i=st and st.intelligence;local p=i and i.players[guid]
    local c=st and S.Character(st.owner,false);local revision=c and c.revision
    if p and p.summaryRevision==i.revision and p.profileRevision==revision then return p.summary end
    local out={guid=guid,recordedEncounters=0,credits={own=0,pet=0,group=0,unattributed=0,incoming=0},zones={},evidence={},scoreboards={},publicReports={},
        confirmedKillingBlows=nil,confirmedDeathsByPlayer=nil,headToHeadRatio=nil,exactGroupedSeconds=nil,performance=nil}
    if p then
        out.recordedEncounters=#p.encounters;out.firstEncounter=p.firstEncounter;out.lastEncounter=p.lastEncounter;out.lastLocalAt=p.lastLocalAt
        out.firstRoster=p.rosterFirst;out.lastRoster=p.rosterLast;out.lastInspection=p.lastInspection;out.credits=p.credits;out.zones=p.zones
        out.evidence=p.evidence;out.scoreboards=p.scoreboards;out.publicReports=p.publicReports;out.facts=p.facts;out.legacyRecords=p.legacyRecords
        out.lastEvidenceAt=p.lastEvidenceAt;out.scoreIdentity=p.scoreIdentity;out.scoreReports=p.scoreOrder
        out.firstScoreAt=p.firstScoreAt;out.lastScoreAt=p.lastScoreAt
    end
    local personal=c and c.profiles[guid] and c.profiles[guid].personal
    out.note=personal and personal.note;out.watch=personal and personal.watch==true or false
    out.tier=out.watch and 1 or p and p.tier
    out.tierLabel=({[1]='Important player',[2]='Activity participant',[3]='Casual encounter'})[out.tier] or (#out.publicReports>0 and 'Olympus source only' or 'Unclassified evidence')
    out.tierReasons={}
    if out.watch then out.tierReasons[#out.tierReasons+1]={label='On your current watchlist',tier=1} end
    if p then for _,r in pairs(p.reasons or {}) do if r.tier==out.tier then out.tierReasons[#out.tierReasons+1]=r end end end
    table.sort(out.tierReasons,function(a,b) return a.label<b.label end)
    local direct=out.credits.own+out.credits.pet+out.credits.incoming
    out.description=out.watch and 'Personal watchlist' or direct>0 and 'Recorded native PvP credit history'
        or out.recordedEncounters>1 and 'Repeated local encounters' or out.recordedEncounters==1 and 'Previously encountered'
        or out.lastInspection and 'Manually inspected' or out.firstRoster and 'Recorded roster history' or #out.publicReports>0 and 'Public Olympus records' or 'Recorded source observations'
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
