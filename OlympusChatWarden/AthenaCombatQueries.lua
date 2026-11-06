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
    options=options or {};local scope=options.scope or {};local refs
    if scope.from~=nil and not S.Number(scope.from,1) or scope.to~=nil and not S.Number(scope.to,1) or scope.from and scope.to and scope.from>scope.to then return nil,'INVALID_SCOPE' end
    if scope.activity then
        local st=ns.ChronicleActivities.Peek(owner);local activity=st and ns.ChronicleActivities.View(st,scope.activity)
        if not activity then ns.ChronicleActivities.Request(owner);return nil,'INDEXING' end;refs=activity.evidenceSet
    end
    local key=consumer..'/'..guid..'/'..tostring(scope.from)..'/'..tostring(scope.to)..'/'..tostring(scope.session)..'/'..tostring(scope.activity);local extent,offset=#c.events,0
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
        if scope.from and e.at<scope.from or scope.to and e.at>scope.to or scope.session and e.session~=scope.session or refs and not refs[e.id] then include=false end
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
local function New(c,owner,guid,scope,consumer)
    return {character=c,owner=owner,guid=guid,scope=scope,consumer=consumer,offset=0,highwater=nil,seen={},casts={},individual={},result={castSpells={},effects={},
        castCount=0,castRecords=0,effectRecords=0,combatStarts=0,pairedWindows=0,partialEnds=0,measuredSeconds=0,
        deaths=0,meterSessions={},latestMeters={},meterSourceRecords=0,coverage='Recorded samples only; no inferred lifetime totals or aura uptime'},
        meterObjects={},types={},uniqueSpells=0,uniqueEffects=0}
end
local function Metric(rows,key,e,amount)
    local v=rows[key]
    if not v then v={spellID=key,count=0,firstAt=e.at,lastAt=e.at,sourceIDs={}};rows[key]=v end
    v.count=v.count+amount;v.firstAt=math.min(v.firstAt,e.details.firstAt or e.at);v.lastAt=math.max(v.lastAt,e.details.lastAt or e.at)
    if #v.sourceIDs<512 then v.sourceIDs[#v.sourceIDs+1]=e.id else v.moreSources=true end
end
local function Feed(st,e)
    local out,d=st.result,e.details;local r=d.recordType;local own=st.guid
    if e.kind=='native_snapshot' and e.capture.family=='meter' then
        -- Keep a reference to the source object, not a second copied payload.
        local v=e.capture.values;local row=v.sources and v.sources[1]
        if v.sourceGUID==own or row and row[1]==own then st.meterObjects[d.contentID]=e end
        return
    end
    local personal=own==st.owner:match('/(Player%-.+)$')
    local meter=r=='damage_meter_source' or r=='damage_meter_spell'
    if not (Q.Includes(e,own,personal) or meter and e.subject==own) then return end
    local scope=st.scope
    if scope.from and e.at<scope.from or scope.to and e.at>scope.to or scope.session and e.session~=scope.session or scope.refs and not scope.refs[e.id] then return end
    if st.seen[e.id] then return end;st.seen[e.id]=true
    out.firstAt=math.min(out.firstAt or e.at,e.at);out.lastAt=math.max(out.lastAt or e.at,e.at)
    if r=='own_spell_success_count' or r=='cast_observation_count' and d.phase=='success notification' then
        if r~='own_spell_success_count' then st.alternativeCasts=true end
        st.casts[#st.casts+1]=e
    elseif r=='cast_observation' and d.phase=='success notification' or r=='witness_ability' and d.method=='successful cast' then
        st.individual[#st.individual+1]=e
    elseif r=='aura_effect' then
        out.effectRecords=out.effectRecords+1
        -- Removals and stack changes are not additional applications/casts.
        if d.effectTransition=='applied' then Metric(out.effects,d.spellID,e,1)
        elseif d.effectTransition=='baseline' then out.baselineEffects=(out.baselineEffects or 0)+1 end
    elseif r=='combat_started' then out.combatStarts=out.combatStarts+1;st.started=e
    elseif r=='combat_ended' then
        local start=st.started;st.started=nil
        if start and start.session==e.session and e.elapsed>=start.elapsed and S.Number(d.combatSeconds,0)
            and math.abs(e.elapsed-start.elapsed-d.combatSeconds)<.01 then
            out.pairedWindows=out.pairedWindows+1;out.measuredSeconds=out.measuredSeconds+d.combatSeconds
        else out.partialEnds=out.partialEnds+1 end
    elseif r=='duel_combat_summary' and d.targetGUID==own and S.Number(d.amount,0) then
        -- These are amounts received by the observed unit, not damage/healing
        -- dealt by its opponent. Keep them separate from cumulative meters.
        local metric=d.scope=='damage received; attacker unknown' and 'duelDamageReceived' or d.scope=='healing received; caster unknown' and 'duelHealingReceived'
        if metric then out[metric]=(out[metric] or 0)+d.amount;out[metric..'Refs']=out[metric..'Refs'] or {};out[metric..'Refs'][#out[metric..'Refs']+1]=e.id end
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
            if current.at and current.at>e.at then return end
            current.amount=row[5];current.duration=v.durationSeconds;current.sourceID=e.id
            current.objectID=object.id;current.at=e.at;out.meterSourceRecords=out.meterSourceRecords+1
            if not out.latestMeters[v.meterType] or (out.latestMeters[v.meterType].at or 0)<=e.at then out.latestMeters[v.meterType]=current end
        elseif v.spells then
            local spell=v.spells[1];current.spells[spell[1]]={amount=spell[2],sourceID=e.id,objectID=object.id,at=e.at}
        end
    end
end
local function FinalizeWork(st)
    local work=0
    local function step() work=work+1;if work>=256 then work=0;coroutine.yield() end end
    local function sortRanges(list)
        -- Cooperative stable merge sort. A single very long history of one
        -- spell must not block a UI frame in table.sort's C implementation.
        local width=1;local buffer={}
        while width<#list do
            for first=1,#list,width*2 do
                local a,b,last=first,math.min(#list+1,first+width),math.min(#list,first+2*width-1)
                local endA=b-1;local endB=last
                for target=first,last do
                    if a<=endA and (b>endB or list[a].first<=list[b].first) then buffer[target]=list[a];a=a+1 else buffer[target]=list[b];b=b+1 end
                    step()
                end
            end
            for i=1,#list do list[i]=buffer[i];step() end
            width=width*2
        end
    end
    local out=st.result;out.castCount=0;out.castRecords=0;out.castSpells={};local windows,castGUIDs={},{}
    if not st.alternativeCasts and #st.individual==0 then
        -- The normal own-cast path has one canonical aggregate producer. It
        -- needs no interval sort or overlap index when no second cast form
        -- exists in the selected history.
        for _,e in ipairs(st.casts)do local d=e.details;Metric(out.castSpells,d.spellID,e,d.count);out.castCount=out.castCount+d.count;out.castRecords=out.castRecords+1;step()end
        out.distinctSpells=0;for _ in pairs(out.castSpells)do out.distinctSpells=out.distinctSpells+1 end
        out.scope=st.scope.label or 'All recorded history';out.owner=st.owner;out.subject=st.guid;return
    end
    local ownRanges={}
    local function window(map,e)
        local d=e.details;local k=e.session..'/'..d.spellID;local list=map[k] or {};map[k]=list
        list[#list+1]={first=d.firstElapsed or d.firstAt or e.at,last=d.lastElapsed or d.lastAt or e.at,elapsed=d.firstElapsed~=nil}
    end
    local function prepare(map)
        for _,list in pairs(map) do
            sortRanges(list)
            local last=-math.huge;for _,w in ipairs(list) do last=math.max(last,w.last);w.maximum=last;step() end
        end
    end
    local function covered(map,e,individual)
        local d=e.details;local list=map[e.session..'/'..d.spellID];if not list then return false end
        local f=individual and e.elapsed or d.firstElapsed;local l=individual and e.elapsed or d.lastElapsed
        if not f or not l then return false end -- no guessed timestamp equivalence
        local low,high=1,#list;local found=0
        while low<=high do local mid=math.floor((low+high)/2);if list[mid].first<=f then found=mid;low=mid+1 else high=mid-1 end end
        return found>0 and list[found].elapsed and list[found].maximum>=l
    end
    for _,e in ipairs(st.casts) do if e.details.recordType=='own_spell_success_count' then window(ownRanges,e) end;step() end
    prepare(ownRanges)
    for _,e in ipairs(st.casts) do local d=e.details
        if d.recordType=='own_spell_success_count' or not covered(ownRanges,e,false) then
            window(windows,e);Metric(out.castSpells,d.spellID,e,d.count);out.castCount=out.castCount+d.count;out.castRecords=out.castRecords+1
        end;step()
    end
    prepare(windows)
    for _,e in ipairs(st.individual) do local d=e.details;local key=d.castGUID and e.session..'/'..d.castGUID
        if not covered(windows,e,true) and (not key or not castGUIDs[key]) then
            Metric(out.castSpells,d.spellID,e,1);out.castCount=out.castCount+1;out.castRecords=out.castRecords+1;if key then castGUIDs[key]=true end
        end;step()
    end
    out.distinctSpells=0;for _ in pairs(out.castSpells) do out.distinctSpells=out.distinctSpells+1 end
    out.scope=st.scope.label or 'All recorded history';out.owner=st.owner;out.subject=st.guid
end
local function Finalize(st)
    if st.finalized==st.offset then return true end
    if not st.finisher then st.finisher=coroutine.create(function()FinalizeWork(st)end) end
    local ok,why=coroutine.resume(st.finisher)
    if not ok then st.failure=tostring(why);st.finisher=nil;return nil end
    if coroutine.status(st.finisher)=='dead' then st.finisher=nil;st.finalized=st.offset;return true end
    return false
end
function Q.GetSummary(consumer,owner,guid,scope)
    if not ((consumer=='chronicle' or consumer=='intel') and A.Enabled(consumer)) then return nil,'DENIED' end
    owner=owner or C.Owner();if not S.Text(owner,256) then return nil,'INVALID_OWNER' end
    guid=guid or owner:match('/(Player%-.+)$');if not S.GUID(guid) then return nil,'INVALID_SUBJECT' end
    scope=scope or {}
    if scope.from~=nil and not S.Number(scope.from,1) or scope.to~=nil and not S.Number(scope.to,1) or scope.from and scope.to and scope.from>scope.to then return nil,'INVALID_SCOPE' end
    local c,status=S.Character(owner,false);if not c then S.RequestCharacter(owner);return nil,status end
    local refs
    if scope.activity then
        local activity=ns.ChronicleActivities.Peek(owner);activity=activity and ns.ChronicleActivities.View(activity,scope.activity)
        if not activity then ns.ChronicleActivities.Request(owner);return nil,'INDEXING' end
        refs=activity.evidenceSet
    end
    local key=owner..'/'..guid..'/'..tostring(scope.activity)..'/'..tostring(scope.session)..'/'..tostring(scope.from)..'/'..tostring(scope.to)
    local st=caches[key]
    if st and (st.character~=c or st.offset>#c.events or st.offset>0 and c.events[st.offset].id~=st.highwater or st.scope.refs~=refs) then st=nil end
    if not st then
        local n,oldest,at=0,nil,nil;for k,v in pairs(caches) do n=n+1;if not at or v.used<at then oldest,at=k,v.used end end
        if n>=4 then caches[oldest]=nil end
        local selected={from=scope.from,to=scope.to,session=scope.session,activity=scope.activity,refs=refs,label=scope.label}
        st=New(c,owner,guid,selected,consumer);caches[key]=st
    end
    clock=clock+1;st.used=clock
    if not st.finisher then for n=st.offset+1,math.min(#c.events,st.offset+256) do Feed(st,c.events[n]);st.offset=n;st.highwater=c.events[n].id end end
    st.result.scanned=st.offset;st.result.total=#c.events;st.result.complete=st.offset==#c.events
    st.result.openWindow=st.started and st.started.id or nil
    if st.result.complete then st.result.complete=Finalize(st)==true end
    if st.failure then return nil,'FAILED' end
    if not st.result.complete then summaryFrame:SetScript('OnUpdate',PumpSummaries) end
    return st.result,st.result.complete and 'READY' or 'INDEXING'
end
function A.GetMyCombat(consumer,owner,scope) return Q.GetSummary(consumer,owner,nil,scope) end
PumpSummaries=function()
    local function cpu()if type(debugprofilestop)=='function'then local ok,v=pcall(debugprofilestop);if ok then return S.Number(v,0)end end end
    local began=cpu();local pending=false
    for _=1,began and 64 or 8 do
        pending=false;local requests={}
        for _,st in pairs(caches) do if not st.result.complete then requests[#requests+1]=st end end
        for _,st in ipairs(requests) do
            if A.Enabled(st.consumer) then local _,status=Q.GetSummary(st.consumer,st.owner,st.guid,st.scope);if status=='INDEXING' then pending=true end end
        end
        local now=cpu();if not pending or began and now and now-began>=2 then break end
    end
    if not pending then summaryFrame:SetScript('OnUpdate',nil) end
end
function Q.Clear() caches={};summaryFrame:SetScript('OnUpdate',nil) end
function Q.Release(owner) for key,st in pairs(caches) do if st.owner==owner then caches[key]=nil end end;if not next(caches) then summaryFrame:SetScript('OnUpdate',nil) end end
function Q.Spells(out,sort)
    local rows={};for _,v in pairs(out.castSpells) do rows[#rows+1]=v end
    table.sort(rows,function(a,b)
        if sort=='name' then return Q.SpellName(a.spellID)<Q.SpellName(b.spellID) end
        if sort=='latest' and a.lastAt~=b.lastAt then return a.lastAt>b.lastAt end
        return a.count>b.count or a.count==b.count and a.spellID<b.spellID
    end)
    return rows
end
function Q.Meters(out)
    local totals={};local types=ns.ChronicleCapture.Table(Enum);types=types and ns.ChronicleCapture.Table(types.DamageMeterType)
    for _,r in pairs(out.latestMeters) do
        local name;for k,id in pairs(types or {}) do if id==r.meterType then name=k;break end end
        if name and S.Number(r.amount,0) then
            local v=totals[name] or {amount=0,seconds=0,measured=true,sources={}};totals[name]=v;v.amount=v.amount+r.amount;v.sources[#v.sources+1]=r.sourceID
            if S.Number(r.duration,0.001) then v.seconds=v.seconds+r.duration else v.measured=false end
        end
    end
    return totals
end
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
