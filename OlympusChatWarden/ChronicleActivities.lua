-- Rebuildable local views over the preserved ledger. Never a second saved history.
local _,ns=...
local function OwnedFrame(...) return ns.Modules and ns.Modules.Frame('history',...) or CreateFrame(...) end
local S=ns.ChronicleStore
local A={VERSION=5,BUDGET=1024,CACHE_LIMIT=2,generation=0,caches=setmetatable({},{__mode='k'})}
ns.ChronicleActivities=A
local frame=OwnedFrame('Frame');local job
local clock=0
local function Now() return ns.SafeNumber(ns.SafeCall(GetTime)) or 0 end
local function Touch(cache)
    clock=clock+1;cache.used=clock
    local count,oldest,key=0
    for c,row in pairs(A.caches) do
        count=count+1;if row~=cache and (not oldest or (row.used or 0)<oldest) then oldest=row.used or 0;key=c end
    end
    if count>A.CACHE_LIMIT and key then A.caches[key]=nil end
end
local function Add(list,set,id) if not set[id] then set[id]=true;list[#list+1]=id end end
local function Own(owner) return owner:match('/(Player%-.+)$') end
function A.Provenance(e)
    local d=e.details or {};local context,scope='native observation','record'
    local source=e.kind=='olympus_snapshot' and 'Olympus API' or 'WoW API'
    if source=='Olympus API' then context='Olympus report';scope='public source snapshot'
    elseif e.kind=='group_roster' then context='remote-capable group roster';scope='roster observation'
    elseif e.kind=='player_combat' or e.kind=='player_kill_credit' then context='legacy combat observation';scope='original semantics; not promoted to current credit or death attribution'
    elseif e.kind=='player_observed' then context=d.localSighting and 'direct local observation' or 'remote-capable unit identity';scope='dated player observation'
    elseif d.recordType=='pvp_score_row' or e.capture and e.capture.family=='scoreboard' then context='match scoreboard';scope='match-specific'
    elseif d.recordType and d.recordType:find('damage_meter',1,true)==1 or e.capture and e.capture.family=='meter' then context='native meter summary';scope='unmatched native combat session'
    elseif d.recordType=='native_kill_credit' then context='native actor/target credit';scope=d.credit or 'unattributed'
    elseif d.recordType=='encounter_started' or d.recordType=='encounter_ended' or d.recordType=='boss_kill_event' then context='native encounter event';scope='boss result; individual attendance unknown' end
    return {source=source,context=context,scope=scope,certainty=e.evidence,restored=e.restored==true,
        independentVerification=false,eventID=e.id,at=e.at}
end
function A.New(owner)
    return {owner=owner,activities={},byID={},players={},events={},identities={},menuNames={},links={},processed=0,
        duplicateDeliveries=0,unmatchedPerformance=0,revision=0,duels={},duelPlayers={}}
end
local function Player(st,guid)
    if not S.GUID(guid) or guid==Own(st.owner) then return end
    local p=st.players[guid]
    if not p then p={guid=guid,activities={},activitySet={},evidence={},evidenceSet={}};st.players[guid]=p end
    return p
end
local function PlayerEvidence(st,guid,e)
    local p=Player(st,guid);if p then Add(p.evidence,p.evidenceSet,e.id) end
end
local function Link(st,a,e)
    if not a then return end
    Add(a.evidence,a.evidenceSet,e.id);st.links[e.id]=st.links[e.id] or {};st.links[e.id][a.id]=true
    a.lastAt=math.max(a.lastAt,e.at);a.lastElapsed=math.max(a.lastElapsed,e.elapsed)
end
local function Associate(st,a,guid)
    local p=Player(st,guid);if not p or not a then return end
    a.members[guid]=true;Add(p.activities,p.activitySet,a.id)
end
local function Activity(st,kind,e,reason)
    local a={id=e.id..'/activity/'..kind,kind=kind,owner=st.owner,session=e.session,startAt=e.at,
        firstElapsed=e.elapsed,lastAt=e.at,lastElapsed=e.elapsed,anchor=e.id,context=e.location,
        startReason=reason,evidence={},evidenceSet={},rosters={},rosterSet={},members={},attempts={},
        measuredSeconds=0,timeSpanCount=0,completion='unknown',status='open'}
    st.activities[#st.activities+1]=a;st.byID[a.id]=a;Link(st,a,e);return a
end
local function Roster(st,a,e,carried)
    if not a or not e then return end
    Add(a.rosters,a.rosterSet,e.id)
    for _,guid in ipairs(e.details.members or {}) do Associate(st,a,guid) end
    if carried then
        a.carriedRoster=e.id;Add(a.evidence,a.evidenceSet,e.id)
        st.links[e.id]=st.links[e.id] or {};st.links[e.id][a.id]=true
    else Link(st,a,e) end
end
local function EndAttempt(st,reason)
    if st.attempt then st.attempt.status='interrupted';st.attempt.interruption=reason;st.attempt=nil end
end
local function Close(st,e,reason,known)
    EndAttempt(st,reason)
    if st.active then
        local a=st.active;a.status=known and 'ended' or 'interrupted';a.endReason=reason
        if known then a.endAt=e.at;a.endElapsed=e.elapsed;Link(st,a,e) end
        st.active=nil
    end
    st.lastEnded=nil
end
local function Break(st,e,reason)
    Close(st,e,reason,false)
    if st.group then st.group.status='interrupted';st.group.endReason=reason;st.group=nil end
    if st.openDuel then st.openDuel.status='interrupted';st.openDuel.endReason=reason;st.openDuel.closedBoundary=true;st.openDuel=nil end
    st.roster=nil;st.startup=nil
end
local function InstanceKey(e)
    local p=e.location
    if not p.inInstance or not ({party=true,raid=true,pvp=true,arena=true})[p.instanceType] then return end
    -- Instance IDs identify a map, not a unique run. Never use this as a run ID.
    return p.instanceType..':'..tostring(p.instanceID or '?')..':'..(p.instanceName or p.zone or '?')
end
local function BeginInstance(st,e,reason)
    local key=InstanceKey(e);if not key then return end
    local kind=({raid='raid',party='dungeon',pvp='battleground',arena='arena'})[e.location.instanceType]
    local a=Activity(st,kind,e,reason)
    if kind=='battleground' or kind=='arena' then a.partialMatch=true;a.matchOutcome='unknown';a.pvpReports={} end
    a.instanceKey=key;a.partialStart=reason~='entry';st.active=a;Roster(st,a,st.roster,true)
    return a
end
local function Attempt(st,e)
    local d=e.details
    local a=st.active or Activity(st,'boss',e,'instance context unavailable')
    local t={id=e.id..'/attempt',anchor=e.id,activityID=a.id,encounterID=d.encounterID,
        name=d.name,difficultyID=d.difficultyID,startAt=e.at,firstElapsed=e.elapsed,
        session=e.session,evidence={},evidenceSet={},rosters={},rosterSet={},members={},
        status='open',outcome='unknown',participation='unavailable'}
    a.attempts[#a.attempts+1]=t;st.attempt=t
    if st.roster then
        Add(t.rosters,t.rosterSet,st.roster.id)
        for _,guid in ipairs(st.roster.details.members) do t.members[guid]=true;Associate(st,a,guid) end
    end
    Link(st,a,e);Add(t.evidence,t.evidenceSet,e.id)
    return t,a
end
local function SameAttempt(t,e)
    return t and t.session==e.session and t.encounterID==e.details.encounterID
        and (not t.difficultyID or not e.details.difficultyID or t.difficultyID==e.details.difficultyID)
end
local function Encounter(st,e)
    local d=e.details;local r=d.recordType;local t=st.attempt
    if r=='encounter_started' then
        if SameAttempt(t,e) and t.startAt==e.at and t.firstElapsed==e.elapsed then
            st.duplicateDeliveries=st.duplicateDeliveries+1;Add(t.evidence,t.evidenceSet,e.id);Link(st,st.byID[t.activityID],e);return
        end
        EndAttempt(st,'another encounter start');st.lastEnded=nil;Attempt(st,e);return
    end
    if not SameAttempt(t,e) then
        local previous=st.lastEnded
        if SameAttempt(previous,e) and previous.endAt==e.at and previous.endElapsed==e.elapsed then
            t=previous;st.duplicateDeliveries=st.duplicateDeliveries+1
        else
            -- An unmatched result is valuable evidence, but it has no invented start.
            if t then EndAttempt(st,'different encounter result') end
            t=Attempt(st,e);t.startAt=nil;t.firstElapsed=nil;t.missingStart=true
        end
    end
    local a=st.byID[t.activityID];Link(st,a,e);Add(t.evidence,t.evidenceSet,e.id)
    local outcome=r=='boss_kill_event' and 'native boss kill' or d.success==1 and 'success' or d.success==0 and 'failure' or 'unknown'
    if t.outcome~='unknown' and outcome~='unknown' and t.outcome~=outcome
        and not (t.outcome=='success' and outcome=='native boss kill' or t.outcome=='native boss kill' and outcome=='success') then
        t.conflictingResults=true;t.outcome='conflicting'
    elseif not t.conflictingResults and outcome~='unknown' then t.outcome=outcome end
    t.endAt=e.at;t.endElapsed=e.elapsed;t.status='ended';st.lastEnded=t;st.attempt=nil
    if a.kind=='boss' then a.status='ended';a.endAt=e.at end
end
local meaningful={instance_enter=true,instance_exit=true,group_roster=true,player_observed=true,important_player=true,
    level_change=true,quest_turnin=true,achievement_earned=true,equipment_change=true,loot_offered=true,
    loadout_observed=true,collection_gap=true,player_death=true}
local function Alias(st,guid,name,realm,at)
    if not S.GUID(guid) or not S.Text(name,144) then return end
    local aliases=st.identities[guid] or {};st.identities[guid]=aliases
    local last=aliases[#aliases]
    if not last or last.name~=name or last.realm~=realm then aliases[#aliases+1]={name=name,realm=realm,at=at} end
    -- Built alongside the existing cooperative index, never during a menu open.
    -- A name without a known realm is insufficient; a live GUID can still match.
    local full=realm and not name:find('-',1,true) and (name..'-'..realm) or name
    local key=(realm or name:find('-',1,true)) and ns.Shield and ns.Shield.Key(full)
    if key then
        local old=st.menuNames[key]
        st.menuNames[key]=old==nil and guid or old==guid and guid or false
    end
end
function A.Feed(st,e)
    local d=e.details
    if st.session and (st.session~=e.session or e.elapsed<(st.elapsed or 0) or e.at<(st.at or 0)) then Break(st,e,'recording or clock boundary') end
    st.session=e.session;st.elapsed=e.elapsed;st.at=e.at;st.revision=st.revision+1
    if e.kind=='recording_start' then
        Break(st,e,'recording start or reload')
        st.startup={id=e.id,session=e.session,source=e.source,key=InstanceKey(e),stage='location'}
    elseif st.startup then
        local stage=st.startup.stage
        if not (stage=='location' and (e.kind=='character_snapshot' or e.kind=='location')
            or stage=='entry' and e.kind=='instance_enter') then st.startup=nil end
    end
    -- Keep references only. The original event remains the one authoritative record.
    if meaningful[e.kind] or e.kind=='native_event' or e.kind=='olympus_snapshot' or e.kind=='recording_stop' then st.events[e.id]=e end
    if e.subject then PlayerEvidence(st,e.subject,e) end
    for _,key in ipairs({'attackerGUID','targetGUID'}) do if S.GUID(d[key]) then PlayerEvidence(st,d[key],e) end end
    if e.kind=='player_observed' and e.subject then
        Alias(st,e.subject,d.name,d.realm,e.at)
    end
    if e.kind=='olympus_snapshot' then
        for _,row in ipairs(e.snapshot.rows) do local guid=row.values and row.values.guid;if S.GUID(guid) then PlayerEvidence(st,guid,e) end end
    end
    if e.kind=='native_snapshot' and e.capture then
        local v=e.capture.values
        if e.capture.family=='scoreboard' and S.GUID(v.guid) then st.events[e.id]=e;PlayerEvidence(st,v.guid,e);Alias(st,v.guid,v.name,nil,e.at) end
        if e.capture.family=='meter' then
            for _,row in ipairs(v.sources or {}) do if S.GUID(row[1]) then st.events[e.id]=e;PlayerEvidence(st,row[1],e) end end
            if S.GUID(v.sourceGUID) then st.events[e.id]=e;PlayerEvidence(st,v.sourceGUID,e) end
        end
    end
    if e.kind=='instance_enter' then
        local startup=st.startup
        local startupPair=startup and startup.stage=='entry' and startup.activity==st.active
            and startup.session==e.session and startup.source==e.source and startup.key==InstanceKey(e)
            and d.reason=='recording-started-inside'
        if startupPair then
            -- The recorder synchronously emits location then entry on startup.
            -- Their clocks can differ. Match the explicit boundary and sequence,
            -- retaining both records without merging later entries to this map.
            st.active.startupBoundary=startup.id;st.active.startupEntry=e.id
            st.active.startReason='recording started inside';st.active.partialStart=true
            Link(st,st.active,e);st.duplicateDeliveries=st.duplicateDeliveries+1
        elseif st.active and st.active.anchor~=e.id and st.active.startAt==e.at and st.active.firstElapsed==e.elapsed and st.active.instanceKey==InstanceKey(e) then
            Link(st,st.active,e);st.duplicateDeliveries=st.duplicateDeliveries+1
        else Close(st,e,'new instance entry',false);BeginInstance(st,e,d.reason and 'recording started inside' or 'entry') end
        st.startup=nil
    elseif e.kind=='location' then
        if st.active and InstanceKey(e)~=st.active.instanceKey then Close(st,e,'location changed; exit unobserved',false) end
        if not st.active then BeginInstance(st,e,'first observed inside') end
        local startup=st.startup
        if startup and startup.stage=='location' and startup.key and startup.key==InstanceKey(e)
            and startup.session==e.session and startup.source==e.source and st.active and st.active.anchor==e.id then
            startup.activity=st.active;startup.stage='entry'
        else st.startup=nil end
    elseif e.kind=='instance_exit' then
        if st.active and InstanceKey(e)==st.active.instanceKey then Close(st,e,'observed instance exit',true) end
    end
    if e.kind=='group_roster' then
        if #d.members>0 and not st.group then st.group=Activity(st,'group',e,'first nonempty roster') end
        Roster(st,st.group,e);Roster(st,st.active,e)
        if st.group then
            st.group.lastRosterComplete=d.rosterComplete~=false
            if d.rosterComplete==false then st.group.hasPartialRosters=true end
        end
        if st.attempt then
            Add(st.attempt.rosters,st.attempt.rosterSet,e.id)
            for _,guid in ipairs(d.members) do st.attempt.members[guid]=true;Associate(st,st.byID[st.attempt.activityID],guid) end
        end
        for _,guid in ipairs(d.members) do PlayerEvidence(st,guid,e) end
        if #d.members==0 and d.rosterComplete~=false and st.group then
            st.group.status='ended';st.group.endAt=e.at;st.group.endReason='no members reported';st.group=nil
        end
        st.roster=e
    end
    if e.kind=='native_event' then
        if d.duelID then
            local a=st.duels[d.duelID]
            if d.recordType=='duel_session_request' and not a then
                a=Activity(st,'duel',e,'native challenge observation');a.duel={id=d.duelID,result='unknown',accepted=false,captures={},combat={}}
                a.status='requested';a.opponentGUID=d.opponentGUID;st.duels[d.duelID]=a;st.openDuel=a
            end
            -- Cross-session or different-opponent records never silently attach.
            if a and not a.closedBoundary and a.session==e.session and (not a.opponentGUID or not d.opponentGUID or a.opponentGUID==d.opponentGUID) then
                if d.opponentGUID then a.opponentGUID=d.opponentGUID;Associate(st,a,d.opponentGUID) end
                Link(st,a,e)
                local duel=a.duel
                if d.recordType=='duel_session_start' and e.source=='DUEL_COUNTDOWN' and d.accepted==true then
                    duel.accepted=true;duel.acceptedAt=e.at;a.status='accepted';duel.startEvidence=e.id
                elseif d.recordType=='duel_session_result' and e.source=='CHAT_MSG_SYSTEM' and duel.accepted and d.resultKnown==true then
                    if duel.result~='unknown' and duel.result~=d.result then duel.result='conflicting' else duel.result=d.result end
                    duel.resultEvidence=e.id
                elseif d.recordType=='duel_session_end' then
                    a.status=duel.accepted and (e.source=='control' and 'interrupted' or 'ended') or 'challenge ended';a.endAt=e.at;a.endReason=d.reason;if st.openDuel==a then st.openDuel=nil end
                elseif d.recordType=='duel_capture' then
                    local guid=d.targetGUID
                    if guid==Own(st.owner) or guid==a.opponentGUID then
                        local rows=duel.captures[guid] or {};duel.captures[guid]=rows;rows[#rows+1]=e
                    end
                elseif d.recordType=='duel_combat_summary' then
                    local guid=d.targetGUID
                    if guid==Own(st.owner) or guid==a.opponentGUID then
                        local rows=duel.combat[guid] or {};duel.combat[guid]=rows;rows[#rows+1]=e
                    end
                end
                if ns.ChronicleDuels then ns.ChronicleDuels.UpdateHistory(st,a) end
            end
        end
        if d.recordType=='encounter_started'  or d.recordType=='encounter_ended' or d.recordType=='boss_kill_event' then Encounter(st,e)
        elseif d.recordType=='pvp_match_complete' and e.source=='PVP_MATCH_COMPLETE' and st.active
            and st.active.pvpReports and InstanceKey(e)==st.active.instanceKey then
            -- A visit is not a unique match. Keep native completion reports but
            -- never use map/name or a reused score sequence to infer a match ID.
            st.active.pvpReports[#st.active.pvpReports+1]=e.id
        elseif d.recordType and d.recordType:find('damage_meter',1,true)==1 then st.unmatchedPerformance=st.unmatchedPerformance+1 end
    end
    if meaningful[e.kind] or e.kind=='native_event' then Link(st,st.active,e);Link(st,st.group,e) end
    if e.kind=='time_span' then
        -- Count only complete observed intervals within one activity boundary.
        -- Never allocate wall-clock gaps or prorate spans across uncertain boundaries.
        local a=st.active
        if a and d.firstElapsed>=a.firstElapsed and e.session==a.session and InstanceKey(e)==a.instanceKey then
            a.measuredSeconds=a.measuredSeconds+d.seconds;a.timeSpanCount=a.timeSpanCount+1;st.events[e.id]=e;Link(st,a,e)
        end
    end
    if e.kind=='recording_stop' then Break(st,e,'recording stopped or client unloaded') end
    if ns.ChronicleIntelligence then ns.ChronicleIntelligence.Feed(st,e) end
end
function A.Name(st,guid,at)
    local aliases=st.identities[guid] or {};local name=guid
    for _,alias in ipairs(aliases) do if not at or alias.at<=at then name=alias.name..(alias.realm and ' - '..alias.realm or '') else break end end
    return name
end
function A.Player(st,guid)
    local p=st and st.players[guid]
    if p and p.summaryRevision==st.revision then return p.summary end
    local out={guid=guid,listedDungeonSegments=0,listedRaidSegments=0,groupSegments=0,
        bossResultsWhileListed=0,bossAttemptsWhileListed=0,successResultsWhileListed=0,failureResultsWhileListed=0,
        localEncounters=0,selfCredits=0,petCredits=0,groupCredits=0,unattributedCredits=0,
        olympusReports=0,scoreboardRecords=0,meterRecords=0,activities={},
        confirmedBossParticipation=nil,groupedSeconds=nil,performance=nil}
    if not p then return out end
    for _,id in ipairs(p.activities) do
        local a=st.byID[id];out.activities[#out.activities+1]=id
        if a.kind=='dungeon' then out.listedDungeonSegments=out.listedDungeonSegments+1
        elseif a.kind=='raid' then out.listedRaidSegments=out.listedRaidSegments+1
        elseif a.kind=='group' then out.groupSegments=out.groupSegments+1 end
        out.firstAt=math.min(out.firstAt or a.startAt,a.startAt);out.lastAt=math.max(out.lastAt or a.lastAt,a.lastAt)
        for _,t in ipairs(a.attempts) do
            if t.members[guid] then out.bossAttemptsWhileListed=out.bossAttemptsWhileListed+1 end
            if t.members[guid] and t.status=='ended' then
            out.bossResultsWhileListed=out.bossResultsWhileListed+1
            if t.outcome=='success' or t.outcome=='native boss kill' then out.successResultsWhileListed=out.successResultsWhileListed+1
            elseif t.outcome=='failure' then out.failureResultsWhileListed=out.failureResultsWhileListed+1 end
        end end
    end
    for _,id in ipairs(p.evidence) do
        local e=st.events[id];local d=e and e.details
        if e then
            if e.kind=='player_observed' and d.encounter and d.localSighting then out.localEncounters=out.localEncounters+1 end
            if e.kind=='olympus_snapshot' then out.olympusReports=out.olympusReports+1 end
            if e.kind=='native_snapshot' and e.capture.family=='scoreboard' then out.scoreboardRecords=out.scoreboardRecords+1 end
            if e.kind=='native_snapshot' and e.capture.family=='meter' then out.meterRecords=out.meterRecords+1 end
            if d.recordType=='native_kill_credit' then
                local key=({['self native credit']='selfCredits',['current pet native credit']='petCredits',['group native credit']='groupCredits'})[d.credit] or 'unattributedCredits'
                out[key]=out[key]+1
            end
        end
    end
    if ns.ChronicleIntelligence then
        local intel=ns.ChronicleIntelligence.Player(st,guid);local credits=intel.credits
        out.localEncounters=intel.recordedEncounters
        out.selfCredits=credits.own;out.petCredits=credits.pet;out.groupCredits=credits.group;out.unattributedCredits=credits.unattributed
    end
    p.summary=out;p.summaryRevision=st.revision;return out
end
function A.Query(st,filter)
    filter=filter or {};local result={};if not st then return result end
    local p=filter.guid and st.players[filter.guid];local ids=p and p.activitySet
    if filter.guid and not ids then return result end
    for i=#st.activities,1,-1 do
        local a=st.activities[i];local ok=(not filter.kind or filter.kind==a.kind or a.kind=='duel' and a.duel.accepted and filter.kind=='duel_'..a.duel.result) and (not ids or ids[a.id])
        if ok and filter.search and filter.search~='' then
            local text=(a.context.instanceName or a.context.zone or '')..' '..a.kind..' '..a.id
            for guid in pairs(a.members) do text=text..' '..guid..' '..A.Name(st,guid,a.lastAt) end
            for _,t in ipairs(a.attempts) do text=text..' '..(t.name or '') end
            ok=text:lower():find(filter.search:lower(),1,true)~=nil
        end
        if ok then result[#result+1]=a;if #result>=(filter.limit or 50) then break end end
    end
    return result
end
-- Build cooperatively and extend append-only history. Imported/out-of-order or
-- replaced ledgers rebuild from their original evidence, never from old summaries.
function A.Peek(owner)
    if not ns.Modules.Enabled('history') or S.blocked or S.loading then return end
    local c=S.Character(owner,false);local cache=c and A.caches[c]
    if cache and cache.raw==c.events and cache.count==#c.events and cache.tail==c.events[#c.events] then return cache.state end
end
function A.ViewRevision(st)
    local c=st and S.Character(st.owner,false);local cache=c and A.caches[c]
    return cache and cache.state==st and cache.revision or nil
end
function A.Request(owner)
    if ns.Modules and not ns.Modules.Enabled('history') then return nil,'disabled' end
    if S.blocked then return nil,'blocked' end
    local c,status=S.RequestCharacter(owner)
    if status=='loading' or status=='blocked' then return nil,'building' elseif status=='failed' then return nil,'blocked' end
    if not c then return A.New(owner),'empty' end
    local cache=A.caches[c]
    if cache and cache.raw==c.events and cache.count==#c.events and cache.tail==c.events[#c.events] then cache.revision=c.revision;Touch(cache);return cache.state,'ready' end
    if job then return nil,'building' end
    local extend=cache and cache.raw==c.events and cache.count<=#c.events and cache.tail==c.events[cache.count]
    -- Publish each completed, internally consistent view before admitting the
    -- next batch. Continuous recording must not starve every read of results.
    if extend and Now()<(cache.readyUntil or 0) then Touch(cache);return cache.state,'ready' end
    local st=extend and cache.state or A.New(owner)
    job={owner=owner,character=c,raw=c.events,state=st,index=extend and cache.count+1 or 1,
        count=#c.events,tail=c.events[#c.events],revision=c.revision,profiles=c.profiles,profilesRead=0,extending=extend~=nil and extend~=false,profilesDone=not ns.Modules.Enabled('intel')}
    local elapsed=0
    frame:SetScript('OnUpdate',function(_,delta)
        elapsed=elapsed+(delta or 0);if job and job.extending and elapsed<.05 then return end;elapsed=0;A.Pump()
    end)
    return nil,'building'
end
function A.Pump(budget)
    if not job or InCombatLockdown and InCombatLockdown() then return end
    local j=job
    if S.Character(j.owner,false)~=j.character or j.character.events~=j.raw or j.character.events[j.count]~=j.tail or j.character.profiles~=j.profiles then A.caches[j.character]=nil;job=nil;frame:SetScript('OnUpdate',nil);return end
    local P=ns.WardenPerformance;local deadline,start=P.Begin(j.extending and 1 or 2);local first=j.index
    for _=1,math.min(budget or A.BUDGET,A.BUDGET) do
        if P.Expired(deadline) then break end
        local e=j.character.events[j.index]
        if j.index>j.count then break end
        A.Feed(j.state,e);j.state.processed=j.index;j.index=j.index+1
    end
    if j.index>j.count then
        -- Add retained profiles alongside the cooperative index. Menu opening
        -- only reads this ready alias map and the exact GUID's saved profile.
        local used=0
        while not j.profilesDone and used<math.max(0,math.min(budget or A.BUDGET,A.BUDGET)-(j.index-first)) do
            if P.Expired(deadline) then P.End('history index',start,j.index-first+used);return end
            local guid,profile=next(j.profiles,j.profileKey);j.profileKey=guid
            if not guid then j.profilesDone=true;break end
            if ns.Modules.Enabled('intel') then
                local facts=profile.facts or {};local name,realm=facts.name,facts.realm
                if name and not j.state.identities[guid] then
                    Alias(j.state,guid,name.value,realm and realm.value,math.max(name.at,realm and realm.at or name.at))
                end
                ns.ChronicleIntelligence.IncludeProfile(j.state,guid)
            end
            used=used+1;j.profilesRead=j.profilesRead+1
        end
        if not j.profilesDone then P.End('history index',start,j.index-first+used);return end
        if P.Expired(deadline) or ns.ChronicleIntelligence and not ns.ChronicleIntelligence.Finish(j.state,A.BUDGET,deadline) then j.finishing=true;P.End('history index',start,j.index-first);return end
        A.caches[j.character]={state=j.state,raw=j.raw,count=j.count,tail=j.tail,revision=j.revision,readyUntil=Now()+1}
        Touch(A.caches[j.character])
        job=nil;frame:SetScript('OnUpdate',nil)
    end
    P.End('history index',start,j.index-first)
end
function A.Clear() job=nil;A.generation=A.generation+1;A.caches=setmetatable({},{__mode='k'});frame:SetScript('OnUpdate',nil) end
function A.Progress() return job and job.index-1 or 0,job and job.count or 0,job and (job.finishing and 'summaries' or job.index>job.count and 'profiles' or 'records') or 'ready' end
function A.ProgressText()
    if not job then return 'Saved views ready.' end
    local done,total,stage=A.Progress()
    local text=stage=='summaries' and 'Finalizing measured time and history summaries'
        or stage=='profiles' and ('Preparing player summaries: '..job.profilesRead..' profiles checked')
        or ('Preparing saved views: '..done..' / '..total..' records indexed')
    if InCombatLockdown and InCombatLockdown() then text=text..' • view preparation paused during combat' end
    local pending=#job.raw-job.count;if pending>0 then text=text..' • '..pending..' new records queued' end
    return text..'. Saved evidence is kept.'
end
