-- Standalone native evidence only. No raw combat-log registration/getter path.
local _,ns=...
local C,S,X=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture
local M={};ns.ChronicleCombat=M
local combatStart,counters,meterEpoch,matchSequence,meterSeen,scoreSeen,casts,lastRank=nil,nil,0,0,{},{},{},nil
local function Event(source,data,subject) return X.Record('native_event',source,data,subject) end
local function Units()
    local out={'player','pet'}
    for i=1,4 do out[#out+1]='party'..i;out[#out+1]='partypet'..i end
    for i=1,40 do out[#out+1]='raid'..i;out[#out+1]='raidpet'..i end
    return out
end
function M.Counters(source)
    if not X.Ready() then return end
    local hk,rank=X.Call('GetPVPLifetimeStats');local sh,sd=X.Call('GetPVPSessionStats');local yh,yd=X.Call('GetPVPYesterdayStats')
    local data={recordType='pvp_counter_snapshot',lifetimeHK=S.Integer(hk,0),lifetimeMaxRank=S.Integer(rank,0),
        sessionHK=S.Integer(sh,0),sessionDK=S.Integer(sd,0),yesterdayHK=S.Integer(yh,0),yesterdayDK=S.Integer(yd,0)}
    if not (data.lifetimeHK or data.sessionHK or data.yesterdayHK) then X.Mark('PvP counters','Unavailable')
    else
        local encoded=ns.ChronicleBackup.Encode(data)
        if encoded~=counters then Event(source,data);counters=encoded;X.Mark('PvP counters','Readable native totals observed; no victim attribution') end
    end
    M.Rank(source)
end
function M.Rank(source)
    if X.Busy() then return end
    local _,build=X.Call('GetBuildInfo');build=S.Text(build,32)
    -- This mapping is verified in these two pinned Camelot UI revisions only.
    if build~='70425' and build~='70450' then X.Mark('Forever rank','Build mapping unverified; no guessed rank faction');return end
    local row=X.Table(X.Call('C_MajorFactions.GetMajorFactionProgressionInfo',2800));if not row then return end
    local data={factionID=2800,seasonID=S.Integer(X.Call('C_SeasonInfo.GetCurrentDisplaySeasonID'),0)}
    for _,key in ipairs({'renownLevel','renownReputationEarned','renownLevelThreshold','maxLevel','previousWeekProgressiveMaxLevel','currentWeekProgressiveMaxLevel','weekNumber'}) do data[key]=S.Integer(row[key],0) end
    if data.renownLevel then
        local hash=X.Store('rank',data,source)
        if hash and hash~=lastRank then Event(source,{recordType='forever_rank_observed',contentID=hash,family='rank'});lastRank=hash end
    end
end
function M.Kill(source,actor,target)
    actor=X.Entity(actor);local victim,kind=X.Entity(target)
    if not actor or not victim then X.Mark('Native kill credit','Unreadable or unsupported actor/target identity');return end
    local credit='unattributed'
    local self=X.Entity(X.Call('UnitGUID','player'));local pet=X.Entity(X.Call('UnitGUID','pet'))
    if actor==self then credit='self native credit' elseif pet and actor==pet then credit='current pet native credit'
    else for _,unit in ipairs(Units()) do if X.Entity(X.Call('UnitGUID',unit))==actor then credit='group native credit';break end end end
    Event(source,{recordType='native_kill_credit',attackerGUID=actor,targetGUID=victim,entityKind=kind,credit=credit},S.GUID(victim))
    X.Mark('Native kill credit','Readable PARTY_KILL payload saved; live credit semantics unverified')
    if S.GUID(victim) and ns.ChronicleEncounters then
        ns.ChronicleEncounters.ImportantGUID(victim,source,'native kill credit')
    end
end
local function MeterTypes()
    local enum=X.Table(Enum);local values=enum and X.Table(enum.DamageMeterType);local out,seen={},{}
    if values then for _,v in pairs(values) do local id=S.Integer(v,0,100);if id and not seen[id] then seen[id]=true;out[#out+1]=id end end end
    table.sort(out);return out
end
function M.Recap(source,id,guid)
    if X.Busy() or not X.runID or not S.GUID(guid) or not S.Integer(id,1) then return end
    if guid~=S.GUID(X.Call('UnitGUID','player')) and not (ns.ChronicleEncounters and ns.ChronicleEncounters.IsImportant(guid)) then return end
    if X.Bool(X.Call('C_DeathRecap.HasRecapEvents',id))~=true then return end
    local entries=X.Table(X.Call('C_DeathRecap.GetRecapEvents',id));if not entries or not S.Array(entries,40) then return end
    local rows={}
    for _,v in ipairs(entries) do
        v=X.Table(v)
        if v then
            local amount=S.Number(v.amount,0);local timestamp=S.Number(v.timestamp,0)
            if amount and timestamp then rows[#rows+1]={S.Text(v.event,64) or false,S.Integer(v.spellId,0) or false,
                S.Text(v.spellName,144) or false,S.Text(v.caster,144) or false,amount,timestamp} end
        end
    end
    if #rows>0 then
        local hash=X.Store('recap',{runID=X.runID,guid=guid,recapID=id,healthMax=S.Number(X.Call('C_DeathRecap.GetRecapMaxHealth',id),0),rows=rows},source)
        if hash and not meterSeen['recap:'..hash] then
            Event(source,{recordType='native_death_recap',contentID=hash,family='recap'},guid);meterSeen['recap:'..hash]=true
        end
    end
end
function M.Meter(source)
    if not X.Ready() or X.Busy() or not X.runID then return end
    if X.Bool(X.Call('C_DamageMeter.IsDamageMeterAvailable'))~=true then X.Mark('Damage meter','Unavailable');return end
    local sessions=X.Table(X.Call('C_DamageMeter.GetAvailableCombatSessions'))
    if not sessions or not S.Array(sessions,200) then X.Mark('Damage meter','Unavailable session list');return end
    for _,session in ipairs(sessions) do
        session=X.Table(session);local id=session and S.Integer(session.sessionID,0)
        if id then for _,kind in ipairs(MeterTypes()) do
            if X.Busy() then return end
            local row=X.Table(X.Call('C_DamageMeter.GetCombatSessionFromID',id,kind))
            local sources=row and X.Table(row.combatSources)
            if row and sources and S.Array(sources,160) then
                local total=S.Number(row.totalAmount,0);local duration=S.Number(row.durationSeconds,0)
                -- One source per object keeps text backups independently bounded.
                for i,v in ipairs(sources) do
                    v=X.Table(v)
                    if v then
                        local guid=X.Entity(v.sourceGUID);local creature=S.Integer(v.sourceCreatureID,0)
                        local amount=S.Number(v.totalAmount,0)
                        if amount then
                            local data={runID=X.runID,sessionID=id,meterType=kind,meterEpoch=meterEpoch,totalAmount=total,durationSeconds=duration,
                                sourceIndex=i,sources={{guid or false,creature or false,S.Text(v.name,144) or false,S.Text(v.classFilename,64) or false,
                                    amount,S.Number(v.amountPerSecond,0) or false,X.Flag(v.isLocalPlayer),
                                    S.Integer(v.deathRecapID,0) or false,S.Number(v.deathTimeSeconds,0) or false}}}
                            local hash=X.Store('meter',data,source);local key=meterEpoch..':'..id..':'..kind..':'..i
                            if hash and meterSeen[key]~=hash then
                                Event(source,{recordType='damage_meter_source',contentID=hash,family='meter',sessionID=id,meterType=kind,meterEpoch=meterEpoch})
                                meterSeen[key]=hash
                            end
                            local recap=S.Integer(v.deathRecapID,1)
                            if recap and S.GUID(guid) then M.Recap(source,recap,guid) end
                            -- Read source spell aggregates only when native identity
                            -- allows an unambiguous getter, never by display name.
                            if guid or creature then
                                local detail=X.Table(X.Call('C_DamageMeter.GetCombatSessionSourceFromID',id,kind,guid,creature))
                                local spells=detail and X.Table(detail.combatSpells)
                                if spells and S.Array(spells,1500) then for j,spell in ipairs(spells) do
                                    spell=X.Table(spell);local spellID=spell and S.Integer(spell.spellID,1)
                                    if spellID then
                                        local value={runID=X.runID,sessionID=id,meterType=kind,meterEpoch=meterEpoch,sourceGUID=guid,sourceCreatureID=creature,
                                            sourceIndex=i,spells={{spellID,S.Number(spell.totalAmount,0) or false,S.Number(spell.amountPerSecond,0) or false,
                                                S.Number(spell.overkillAmount,0) or false,X.Flag(spell.isAvoidable),X.Flag(spell.isDeadly)}}}
                                        local h=X.Store('meter',value,source);local sk=key..':spell:'..spellID..':'..j
                                        if h and meterSeen[sk]~=h then Event(source,{recordType='damage_meter_spell',contentID=h,family='meter',sessionID=id,meterType=kind,meterEpoch=meterEpoch});meterSeen[sk]=h end
                                    end
                                    X.Yield()
                                end end
                            end
                        end
                    end
                    X.Yield()
                end
                if #sources==0 and total then
                    local hash=X.Store('meter',{runID=X.runID,sessionID=id,meterType=kind,meterEpoch=meterEpoch,totalAmount=total,durationSeconds=duration,sources={}},source)
                    if hash and meterSeen[hash]~=true then Event(source,{recordType='damage_meter_session',contentID=hash,family='meter'});meterSeen[hash]=true end
                end
            end
            X.Yield()
        end end
    end
end
function M.Score(source)
    if X.Busy() or not X.runID or matchSequence==0 then return end
    local count=S.Integer(X.Call('GetNumBattlefieldScores'),0,160) or 160
    if not X.API('C_PvP.GetScoreInfo') then X.Mark('PvP scores','Native score reader unavailable');return end
    for i=1,count do
        local value=X.Call('C_PvP.GetScoreInfo',i);local row=X.Table(value)
        if ns.Readable(value) and value==nil then break end
        if row then
            local data={runID=X.runID,matchSequence=matchSequence,rowIndex=i,name=S.Text(row.name,144),guid=S.GUID(row.guid)}
            for _,key in ipairs({'killingBlows','honorableKills','deaths','honorGained','faction','gender','damageDone','healingDone','honorLevel'}) do data[key]=S.Integer(row[key],0) end
            data.raceName=S.Text(row.raceName,64);data.classToken=S.Text(row.classToken,64)
            if data.killingBlows or data.deaths then
                local hash=X.Store('scoreboard',data,source)
                if hash and scoreSeen[i]~=hash then Event(source,{recordType='pvp_score_row',contentID=hash,family='scoreboard',part=i,parts=count});scoreSeen[i]=hash end
            end
        end
        X.Yield()
    end
end
local function FlushCasts(source)
    for id,v in pairs(casts) do Event(source,{recordType='own_spell_success_count',spellID=id,count=v.count,
        firstAt=v.firstAt,lastAt=v.lastAt,method='UNIT_SPELLCAST_SUCCEEDED'}) end
    casts={}
end
function M.Flush() FlushCasts('checkpoint') end
function M.Start()
    combatStart=nil;counters=nil;meterEpoch=0;matchSequence=0;meterSeen={};scoreSeen={};casts={};lastRank=nil
    M.Counters('control');X.Queue('meter',function() M.Meter('control') end)
    X.Mark('Native kill credit','Event registered; waiting for readable delivery')
end
function M.Stop() combatStart=nil;counters=nil;meterSeen={};scoreSeen={};casts={};lastRank=nil end
function M.Handle(event,a,b,c,d,e)
    if event=='PARTY_KILL' then M.Kill(event,a,b)
    elseif event=='PLAYER_PVP_KILLS_CHANGED' then M.Counters(event)
    elseif event=='PLAYER_REGEN_DISABLED' then combatStart=C.Tick();Event(event,{recordType='combat_started'})
    elseif event=='PLAYER_REGEN_ENABLED' then
        local now=C.Tick();Event(event,{recordType='combat_ended',combatSeconds=now and combatStart and S.Number(now-combatStart,0)})
        combatStart=nil;FlushCasts(event);M.Counters(event);X.Queue('meter',function() M.Meter(event) end)
    elseif event=='UNIT_SPELLCAST_SUCCEEDED' then
        if ns.CanRead(a) and a=='player' then local id=S.Integer(c,1,10000000);if id then
            local at=C.Stamp();local v=casts[id] or {count=0,firstAt=at};v.count=v.count+1;v.lastAt=at;casts[id]=v
            if not X.Busy() then FlushCasts(event) end
        end end
    elseif event=='ENCOUNTER_START' or event=='ENCOUNTER_END' then
        local id=S.Integer(a,1,10000000);if id then Event(event,{recordType=event=='ENCOUNTER_START' and 'encounter_started' or 'encounter_ended',
            encounterID=id,name=S.Text(b,144),difficultyID=S.Integer(c,0),groupSize=S.Integer(d,0,100),success=S.Integer(e,0,1)}) end
    elseif event=='BOSS_KILL' then local id=S.Integer(a,1,10000000);if id then Event(event,{recordType='boss_kill_event',encounterID=id,name=S.Text(b,144)}) end
    elseif event=='PVP_MATCH_ACTIVE' then matchSequence=0;scoreSeen={}
    elseif event=='PVP_MATCH_COMPLETE' then
        matchSequence=matchSequence+1;scoreSeen={}
        Event(event,{recordType='pvp_match_complete',winner=S.Integer(a,0,100),duration=S.Number(b,0)})
        X.Queue('scores',function() M.Score(event) end);M.Counters(event)
    elseif event=='UPDATE_BATTLEFIELD_SCORE' then X.Queue('scores',function() M.Score(event) end)
    elseif event=='UPDATE_FACTION' then M.Rank(event)
    elseif event=='DAMAGE_METER_RESET' then meterEpoch=meterEpoch+1;meterSeen={};Event(event,{recordType='native_meter_reset',meterEpoch=meterEpoch})
    elseif event=='DAMAGE_METER_COMBAT_SESSION_UPDATED' or event=='DAMAGE_METER_CURRENT_SESSION_UPDATED' then X.Queue('meter',function() M.Meter(event) end)
    elseif event=='DUEL_REQUESTED' then Event(event,{recordType='duel_requested',name=S.Text(a,144)})
    elseif event=='DUEL_FINISHED' or event=='DUEL_INBOUNDS' or event=='DUEL_OUTOFBOUNDS' then Event(event,{recordType=event:lower(),resultKnown=false}) end
end
X.Register(M,{'PARTY_KILL','PLAYER_PVP_KILLS_CHANGED','PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED','UNIT_SPELLCAST_SUCCEEDED',
    'ENCOUNTER_START','ENCOUNTER_END','BOSS_KILL','PVP_MATCH_ACTIVE','PVP_MATCH_COMPLETE','UPDATE_BATTLEFIELD_SCORE','DUEL_REQUESTED','DUEL_FINISHED',
    'DUEL_INBOUNDS','DUEL_OUTOFBOUNDS','DAMAGE_METER_RESET','DAMAGE_METER_COMBAT_SESSION_UPDATED','DAMAGE_METER_CURRENT_SESSION_UPDATED','UPDATE_FACTION'})
