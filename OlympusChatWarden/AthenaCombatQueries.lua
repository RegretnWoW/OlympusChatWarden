-- Disposable, lazy projections. All rows point to original canonical evidence.
local _,ns=...
local A,S,C=ns.Athena,ns.ChronicleStore,ns.Chronicle
local Q={};ns.AthenaCombatQueries=Q
local summaryFrame=ns.Modules and ns.Modules.Frame('chronicle','Frame') or CreateFrame('Frame')
local PumpSummaries
local selfTypes={cast_observation_count=true,cast_observation=true,aura_effect=true,aura_partial=true,own_spell_success_count=true,combat_started=true,combat_ended=true,
    native_death_recap=true,damage_meter_source=true,damage_meter_spell=true,damage_meter_session=true,native_meter_reset=true,
    native_kill_credit=true,encounter_started=true,encounter_ended=true,boss_kill_event=true,pvp_match_complete=true,
    duel_session_start=true,duel_session_end=true,duel_session_result=true,duel_combat_summary=true,pvp_score_row=true}
function Q.Includes(e,guid,personal)
    if personal then
        return (not e.subject or e.subject==guid) and (e.kind=='player_death' or e.kind=='player_combat'
            or e.kind=='native_event' and selfTypes[e.details.recordType]==true)
    end
    return e.subject==guid and e.kind=='native_event' and (e.details.recordType=='cast_observation_count' or e.details.recordType=='cast_observation' or e.details.recordType=='aura_effect' or e.details.recordType=='aura_partial'
        or e.details.recordType:match('^witness_')~=nil)
end
function Q.SpellName(id)
    local info=ns.ChronicleCapture.Table(ns.ChronicleCapture.Call('C_Spell.GetSpellInfo',id))
    return info and S.Text(info.name,144) or S.Text(ns.ChronicleCapture.Call('GetSpellInfo',id),144) or 'Spell '..tostring(id)
end
function Q.Title(e)
    local d=e.details;local r=d.recordType
    if r=='cast_observation_count' or r=='cast_observation' then return ns.AthenaObservationSchema.Title(e)
    elseif r=='aura_effect' then
        local action=({applied='Effect applied on subject',removed='Observed effect removed',changed='Observed effect changed',baseline='Effect present when observed'})[d.effectTransition]
        return action..' • '..Q.SpellName(d.spellID)
    elseif r=='own_spell_success_count' then return 'Your confirmed successful spells • '..Q.SpellName(d.spellID)..' × '..d.count end
    return ns.RecordingUI.Title(e) or r or e.kind
end
function A.GetCombatHistory(consumer,owner,guid,cursor,options)
    if not ((consumer=='chronicle' or consumer=='intel') and A.Enabled(consumer)) then return nil,'DENIED' end
    owner=owner or C.Owner();local personal=consumer=='chronicle';local own=owner:match('/(Player%-.+)$')
    guid=personal and own or S.GUID(guid);if not guid then return nil,'INVALID_SUBJECT' end
    local c,status=S.Character(owner,false);if not c then S.RequestCharacter(owner);return nil,status end
    options=options or {};local key=consumer..'/'..guid;local extent,offset=#c.events,0
    if cursor then
        if type(cursor)~='table' or cursor.owner~=owner or cursor.key~=key or not S.Integer(cursor.extent,0,#c.events)
            or not S.Integer(cursor.offset,0,cursor.extent) then return nil,'INVALID_CURSOR' end
        if cursor.extent>0 and c.events[cursor.extent].id~=cursor.highwater then return nil,'CURSOR_STALE' end
        extent=cursor.extent;offset=cursor.offset
    end
    local rows,scanned={},0;local search=S.Text(options.search,128)
    while offset<extent and #rows<(S.Integer(options.limit,1,50) or 20) and scanned<512 do
        local e=c.events[extent-offset];offset=offset+1;scanned=scanned+1
        local include=Q.Includes(e,guid,personal)
        if include and personal and (e.details.recordType=='damage_meter_source' or e.details.recordType=='damage_meter_spell' or e.details.recordType=='damage_meter_session') then
            local object=ns.ChronicleCapture.Find(owner,e.details.contentID);local v=object and object.capture.values
            local row=v and v.sources and v.sources[1]
            include=v and (v.sourceGUID==guid or row and row[1]==guid) -- legacy subject-less meter rows need native ownership.
        end
        if include then
            local title=Q.Title(e)
            if not search or title:lower():find(search:lower(),1,true) then rows[#rows+1]={id=e.id,event=e,title=title,
                occurredAt=e.at,source=e.source,subject=e.subject,observer=e.character,zone=e.location.zone,
                association=e.details.recordType=='aura_effect' and 'effect on recipient; casting not established' or 'source-qualified combat evidence'} end
        end
    end
    return rows,offset<extent and {owner=owner,key=key,extent=extent,offset=offset,highwater=c.events[extent].id} or nil,
        {coverage='Recorded observations only; unavailable intervals and actual uptime unknown',scanned=scanned}
end
local caches={};local clock=0
local function New(c,owner)
    return {character=c,owner=owner,offset=0,highwater=nil,result={castSpells={},effects={},
        castCount=0,castRecords=0,effectRecords=0,combatStarts=0,pairedWindows=0,partialEnds=0,measuredSeconds=0,
        deaths=0,meterSessions={},latestMeters={},meterSourceRecords=0,coverage='Recorded samples only; no inferred lifetime totals or aura uptime'},
        meterObjects={},types={},uniqueSpells=0,uniqueEffects=0}
end
local function Metric(rows,key,e,amount)
    local v=rows[key]
    if not v then v={spellID=key,count=0,firstAt=e.at,lastAt=e.at,sourceIDs={}};rows[key]=v end
    v.count=v.count+amount;v.firstAt=math.min(v.firstAt,e.details.firstAt or e.at);v.lastAt=math.max(v.lastAt,e.details.lastAt or e.at)
    if #v.sourceIDs==3 then table.remove(v.sourceIDs,1) end;v.sourceIDs[#v.sourceIDs+1]=e.id
end
local function Feed(st,e)
    local out,d=st.result,e.details;local r=d.recordType;local own=st.owner:match('/(Player%-.+)$')
    if e.kind=='native_snapshot' and e.capture.family=='meter' then
        -- Keep a reference to the source object, not a second copied payload.
        local v=e.capture.values;local row=v.sources and v.sources[1]
        if v.sourceGUID==own or row and row[1]==own then st.meterObjects[d.contentID]=e end
        return
    end
    if not Q.Includes(e,own,true) then return end
    out.firstAt=math.min(out.firstAt or e.at,e.at);out.lastAt=math.max(out.lastAt or e.at,e.at)
    if r=='own_spell_success_count' then
        out.castCount=out.castCount+d.count;out.castRecords=out.castRecords+1
        Metric(out.castSpells,d.spellID,e,d.count)
    elseif r=='aura_effect' then
        out.effectRecords=out.effectRecords+1
        -- Removals and stack changes are not additional applications/casts.
        if d.effectTransition=='applied' or d.effectTransition=='baseline' then Metric(out.effects,d.spellID,e,1) end
    elseif r=='combat_started' then out.combatStarts=out.combatStarts+1;st.started=e
    elseif r=='combat_ended' then
        local start=st.started;st.started=nil
        if start and start.session==e.session and e.elapsed>=start.elapsed and S.Number(d.combatSeconds,0)
            and math.abs(e.elapsed-start.elapsed-d.combatSeconds)<.01 then
            out.pairedWindows=out.pairedWindows+1;out.measuredSeconds=out.measuredSeconds+d.combatSeconds
        else out.partialEnds=out.partialEnds+1 end
    elseif e.kind=='player_death' then out.deaths=out.deaths+1
    elseif r=='damage_meter_source' or r=='damage_meter_spell' then
        local object=st.meterObjects[d.contentID];local v=object and object.capture.values
        if not v then return end
        local row=v.sources and v.sources[1];local guid=v.sourceGUID or row and row[1]
        if guid~=own then return end
        if not S.Integer(v.sessionID,0) or not S.Integer(v.meterType,0) then return end
        local session=st.owner..'/'..(S.Text(v.runID,256) or e.session)..'/'..(v.meterEpoch or 0)..'/'..v.sessionID..'/'..v.meterType
        local current=out.meterSessions[session] or {sessionID=v.sessionID,meterType=v.meterType,spells={}}
        out.meterSessions[session]=current
        if row then
            -- Latest cumulative source observation per native session and type.
            -- Never add refresh values, different types, runs or spell rows.
            current.amount=row[5];current.duration=v.durationSeconds;current.sourceID=e.id
            current.objectID=object.id;current.at=e.at;out.meterSourceRecords=out.meterSourceRecords+1
            out.latestMeters[v.meterType]=current
        elseif v.spells then
            local spell=v.spells[1];current.spells[spell[1]]={amount=spell[2],sourceID=e.id,objectID=object.id,at=e.at}
        end
    end
end
function A.GetMyCombat(consumer,owner)
    if consumer~='chronicle' or not A.Enabled(consumer) then return nil,'DENIED' end
    owner=owner or C.Owner();local c,status=S.Character(owner,false);if not c then S.RequestCharacter(owner);return nil,status end
    local st=caches[owner]
    if st and (st.character~=c or st.offset>#c.events or st.offset>0 and c.events[st.offset].id~=st.highwater) then st=nil end
    if not st then
        local n,oldest,at=0,nil,nil
        for key,v in pairs(caches) do n=n+1;if not at or v.used<at then oldest,at=key,v.used end end
        if n>=2 then caches[oldest]=nil end
        st=New(c,owner);caches[owner]=st
    end
    clock=clock+1;st.used=clock
    -- At most 128 rows per request. UI refresh or a caller's continuation pumps
    -- incrementally; opening another alt never eagerly decodes other archives.
    local limit=math.min(#c.events,st.offset+128)
    for n=st.offset+1,limit do Feed(st,c.events[n]);st.offset=n;st.highwater=c.events[n].id end
    st.result.scanned=st.offset;st.result.total=#c.events;st.result.complete=st.offset==#c.events
    st.result.openWindow=st.started and st.started.id or nil
    if not st.result.complete then summaryFrame:SetScript('OnUpdate',PumpSummaries) end
    return st.result,st.result.complete and 'READY' or 'INDEXING'
end
PumpSummaries=function()
    if not A.Enabled('chronicle') then Q.Clear();return end
    local pending=false
    for owner,st in pairs(caches) do if not st.result.complete then
        local value,status=A.GetMyCombat('chronicle',owner);if value and status=='INDEXING' then pending=true end
    end end
    if not pending then summaryFrame:SetScript('OnUpdate',nil) end
end
function Q.Clear() caches={};summaryFrame:SetScript('OnUpdate',nil) end
function Q.Release(owner) if owner then caches[owner]=nil end;if not next(caches) then summaryFrame:SetScript('OnUpdate',nil) end end
function Q.Top(rows,limit)
    local result={};for _,v in pairs(rows) do result[#result+1]=v end
    table.sort(result,function(a,b) return a.count>b.count or a.count==b.count and a.spellID<b.spellID end)
    local out={};for n=1,math.min(#result,limit or 3) do out[n]=Q.SpellName(result[n].spellID)..' × '..result[n].count end
    return #out>0 and table.concat(out,', ') or 'Not recorded / unknown'
end
function Q.MeterLine(out)
    local text={};local types=ns.ChronicleCapture.Table(Enum) and ns.ChronicleCapture.Table(Enum.DamageMeterType)
    for kind,row in pairs(out.latestMeters) do
        local label='type '..kind
        for name,id in pairs(types or {}) do if S.Integer(id,0)==kind and S.Text(name,64) then label=name;break end end
        text[#text+1]=label..' '..tostring(row.amount)..' (native session '..row.sessionID..')'
        if #text==3 then break end
    end
    return #text>0 and table.concat(text,'; ') or 'Native meter: not recorded / unknown'
end
ns.WardenDB.GetCombatHistory=A.GetCombatHistory;ns.WardenDB.GetMyCombat=A.GetMyCombat
