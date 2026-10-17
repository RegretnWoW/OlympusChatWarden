-- Typed, content-addressed native snapshots. Objects live in the event ledger,
-- so the original provenance and ordinary backup/clear paths remain authoritative.
local _,ns=...
local C,S,B,P=ns.Chronicle,ns.ChronicleStore,ns.ChronicleBackup,ns.PackCrypto
local X={registered={},events={},status={},diagnostics={saved=0,rejected=0,errors=0},refs={}};ns.ChronicleCapture=X
local frame=CreateFrame('Frame');local owner,index,jobs,queue=nil,{},{},{}
local indices=setmetatable({},{__mode='k'})
local schemas={
    gear='guid slots itemGUIDs',traits='guid configID treeID nodes committed exportString',
    appearance='guid raceID classID sex nativeDisplayID displayID customizations modelID exact',
    meter='runID sessionID meterType meterEpoch totalAmount durationSeconds sourceIndex sources spells sourceGUID sourceCreatureID',
    scoreboard='runID matchSequence rowIndex name guid killingBlows honorableKills deaths honorGained faction raceName gender classToken damageDone healingDone honorLevel',
    recap='runID guid recapID healthMax rows',barber='guid raceID sex customizations modelID exact',
    equipment_set='guid setID name items ignored isEquipped',stats='guid strength agility stamina intellect spirit armor healthMax powerMax powerType crit haste',
    rank='factionID renownLevel renownReputationEarned renownLevelThreshold maxLevel previousWeekProgressiveMaxLevel currentWeekProgressiveMaxLevel weekNumber seasonID',
    gear_condition='guid slots',
    currency='currencyID name quantity maxQuantity maxWeeklyQuantity quantityEarnedThisWeek totalEarned isAccountWide catalogView',
    collection='collectionType collectionID battlePetGUID name spellID displayID speciesID creatureID petType petLevel scope collected catalogView',
    lockout='name instanceID instanceIDMostSig difficultyID difficultyName locked extended isRaid maxPlayers resetAt resetSeconds worldBoss',
    lockout_list='rows complete instanceCount worldBossCount',
}
local allowed={};for family,words in pairs(schemas) do allowed[family]={};for key in words:gmatch('%S+') do allowed[family][key]=true end end
local activity={collector_session=true,native_kill_credit=true,pvp_counter_snapshot=true,combat_started=true,combat_ended=true,
    own_spell_success_count=true,encounter_started=true,encounter_ended=true,boss_kill_event=true,pvp_match_complete=true,pvp_score_row=true,
    native_meter_reset=true,damage_meter_source=true,damage_meter_spell=true,damage_meter_session=true,duel_requested=true,duel_finished=true,
    duel_inbounds=true,duel_outofbounds=true,trait_tree_nodes=true,barber_choices_applied=true,stats_observed=true,gear_condition_observed=true,
    equipment_set_observed=true,forever_rank_observed=true,native_death_recap=true,reputation_standing_changed=true,recipe_learned=true,native_craft_result=true,
    currency_observed=true,currency_changed=true,collection_observed=true,collection_added=true,lockout_observed=true,lockout_list_observed=true}
function X.ValidActivity(d)
    if not activity[d.recordType] then return false end
    if d.recordType=='native_kill_credit' then
        local actor=X.Entity(d.attackerGUID);local target,kind=X.Entity(d.targetGUID)
        if not actor or not target or kind~=d.entityKind or not ({['self native credit']=true,['current pet native credit']=true,
            ['group native credit']=true,unattributed=true})[d.credit] then return false end
    elseif d.recordType=='own_spell_success_count' then
        if not S.Integer(d.spellID,1,10000000) or not S.Integer(d.count,1) or not S.Integer(d.firstAt,1) or not S.Integer(d.lastAt,d.firstAt) then return false end
    elseif d.recordType=='encounter_started' or d.recordType=='encounter_ended' or d.recordType=='boss_kill_event' then
        if not S.Integer(d.encounterID,1,10000000) then return false end
    elseif d.recordType=='recipe_learned' then if not S.Integer(d.recipeID,1,10000000) then return false end
    elseif d.recordType=='native_craft_result' then
        if not S.Integer(d.itemID,1,1000000000) or not S.Integer(d.quantity,1,1000000) then return false end
    elseif d.recordType=='reputation_standing_changed' then
        if not S.Integer(d.factionID,1) or not S.Integer(d.beforeStanding) or not S.Integer(d.afterStanding)
            or d.delta~=nil and d.delta~=d.afterStanding-d.beforeStanding then return false end
    elseif d.recordType=='currency_observed' or d.recordType=='currency_changed' then
        if not S.Integer(d.currencyID,1) or d.before~=nil and not S.Number(d.before,0) or d.after~=nil and not S.Number(d.after,0)
            or d.delta~=nil and (not d.before or not d.after or d.delta~=d.after-d.before) then return false end
    elseif d.recordType=='collection_observed' or d.recordType=='collection_added' then
        if not ({mount=true,pet=true,toy=true})[d.collectionType] or d.collectionType~='pet' and not S.Integer(d.collectionID,1)
            or d.collectionType=='pet' and not S.Text(d.battlePetGUID,128) then return false end
    end
    return true
end
function X.Classify(kind,source,data)
    if kind~='native_event' then return 'value-snapshot' end
    local r=data.recordType
    local outcomes={encounter_started={'started','boss-encounter'},encounter_ended={data.success==1 and 'success' or data.success==0 and 'failure' or 'unknown','boss-encounter'},
        boss_kill_event={'native-kill-event','boss-encounter'},native_kill_credit={'native-credit','actor-target-credit'},
        pvp_match_complete={'ended','match'},duel_finished={'unknown','duel'},recipe_learned={'learned','recipe'},
        native_craft_result={'crafted-result','craft'},collection_added={'native-added-event','collection'}}
    local nativeSources={encounter_started='ENCOUNTER_START',encounter_ended='ENCOUNTER_END',boss_kill_event='BOSS_KILL',
        native_kill_credit='PARTY_KILL',pvp_match_complete='PVP_MATCH_COMPLETE',duel_finished='DUEL_FINISHED',
        recipe_learned='NEW_RECIPE_LEARNED',native_craft_result='TRADE_SKILL_ITEM_CRAFTED_RESULT'}
    local result=outcomes[r]
    if result and (nativeSources[r]==source or r=='collection_added' and
        ((data.collectionType=='mount' and source=='NEW_MOUNT_ADDED') or (data.collectionType=='pet' and source=='NEW_PET_ADDED') or (data.collectionType=='toy' and source=='NEW_TOY_ADDED'))) then
        return 'native-event',result[1],result[2]
    end
    if r and (r:find('damage_meter',1,true)==1 or r=='native_death_recap' or r=='pvp_score_row') then return 'source-aggregate' end
    if r=='own_spell_success_count' then return 'source-aggregate','cast-succeeded','own-spell' end
    if r=='currency_changed' and source=='CURRENCY_DISPLAY_UPDATE' then return 'native-event','balance-update','currency' end
    return 'value-snapshot'
end
function X.API(name)
    local a,b=name:match('^([^.]+)%.(.+)$');local v=a and _G[a] or _G[name]
    if a then v=ns.Readable(v) and type(v)=='table' and v[b] or nil end
    return ns.Readable(v) and type(v)=='function' and v or nil
end
function X.Call(name,...)
    local fn=X.API(name);if not fn then return end
    local ok,a,b,c,d,e,f,g,h,i,j,k,l,m,n=pcall(fn,...)
    if ok then return a,b,c,d,e,f,g,h,i,j,k,l,m,n end
    X.diagnostics.errors=X.diagnostics.errors+1
end
function X.Table(v) return ns.Readable(v) and type(v)=='table' and not getmetatable(v) and v or nil end
function X.Bool(v) if ns.Readable(v) and type(v)=='boolean' then return v end end
function X.Flag(v)
    local b=X.Bool(v);if b==true then return 'true' elseif b==false then return 'false' end
    return 'unavailable'
end
function X.Entity(v)
    local text=S.Text(v,128);if not text then return end
    local kind=text:match('^(%a+)%-[%w%-]+$')
    if kind=='Player' then if S.GUID(text) then return text,kind end
    elseif kind=='Creature' or kind=='Pet' or kind=='Vehicle' then return text,kind end
end
function X.Busy()
    return ns.Checked(X.Call('InCombatLockdown')) or ns.Checked(X.Call('UnitAffectingCombat','player'))
end
function X.Ready() return C.InWorld() and owner==C.Owner() end
function X.Mark(family,status) X.status[family]=status end
function X.Validate(t)
    if not X.Table(t) or not ns.Readable(t.format) or not ns.CanRead(t.family) or t.format~=1 or not allowed[t.family] or not X.Table(t.values) then return end
    for k in pairs(t) do if k~='format' and k~='family' and k~='values' then return end end
    local count,seen=0,{}
    local function copy(v,depth)
        if not ns.Readable(v) then return nil,false end
        if type(v)=='number' then local n=S.Number(v);return n,n~=nil end
        if type(v)=='boolean' then return v,true end
        if type(v)=='string' then local s=S.Text(v,6000);return s,s~=nil end
        if depth>5 or not X.Table(v) or seen[v] then return nil,false end
        seen[v]=true;local out={};local n=0
        for k,item in pairs(v) do
            count=count+1;n=n+1
            if count>1000 or n>160 or not ns.Readable(k) or not S.Integer(k,1,160) and not (depth==0 and allowed[t.family][k]) then return nil,false end
            local value,ok=copy(item,depth+1);if not ok then return nil,false end;out[k]=value
        end
        seen[v]=nil;return out,true
    end
    local values,ok=copy(t.values,0);if not ok or not next(values) then return end
    if values.guid~=nil and not S.GUID(values.guid) then return end
    if t.family=='gear' then
        if not S.GUID(values.guid) or not S.Array(values.slots,19) or #values.slots~=19 then return end
        for i,row in ipairs(values.slots) do
            if not S.Array(row,4) or #row~=4 or row[1]~=i
                or not ({present=true,empty=true,pending=true,unavailable=true})[row[2]] then return end
            if (row[2]=='present' or row[2]=='pending') and not S.Integer(row[3],1,1000000000)
                or row[2]~='present' and row[2]~='pending' and row[3]~=false then return end
            if row[4]~=false and (not S.Text(row[4],512) or not row[4]:match('^item:[%d:%-]+$') or tonumber(row[4]:match('^item:(%d+)'))~=row[3]) then return end
        end
    elseif t.family=='currency' then
        if not S.Integer(values.currencyID,1) or not S.Number(values.quantity,0) then return end
    elseif t.family=='collection' then
        if not ({mount=true,pet=true,toy=true})[values.collectionType] or values.collected~=true
            or values.collectionType~='pet' and not S.Integer(values.collectionID,1)
            or values.collectionType=='pet' and not S.Text(values.battlePetGUID,128) then return end
    elseif t.family=='lockout_list' then
        if not S.Array(values.rows,12) or type(values.complete)~='boolean' then return end
        for _,row in ipairs(values.rows) do
            if not S.Array(row,11) or #row~=11 or not S.Text(row[1],144) or not S.Integer(row[2],0)
                or not S.Number(row[10],1) or type(row[11])~='boolean' then return end
        end
    end
    local out={format=1,family=t.family,values=values}
    if #B.Encode(out)>6000 then return end
    return out
end
function X.Hash(t) return P.Hex(P.SHA256(B.Encode(t))) end
function X.Find(character,hash)
    local c=S.Character(character,false);if not c then return end
    return X.Index(c)[hash]
end
function X.ObjectIndex(events)
    local out={};for _,e in ipairs(events or {}) do if e.capture then out[e.details.contentID]=e end end;return out
end
function X.Index(c)
    if not indices[c] then indices[c]=X.ObjectIndex(c.events) end
    return indices[c]
end
function X.Dependencies(e,objects)
    local out,seen={},{}
    for key,family in pairs({gearRef='gear',traitRef='traits',appearanceRef='appearance',contentID=e.details.family}) do
        local hash=e.details[key]
        if hash and e.kind~='native_snapshot' then
            local object=objects[hash]
            if not object or not object.capture or object.capture.family~=family then return nil,'Missing or mismatched snapshot reference.' end
            if not seen[object.id] then out[#out+1]=object;seen[object.id]=true end
        end
    end
    return out
end
function X.Store(family,values,source)
    if not X.Ready() then return end
    local payload=X.Validate({format=1,family=family,values=values})
    if not payload then X.diagnostics.rejected=X.diagnostics.rejected+1;X.Mark(family,'Rejected malformed, unreadable or oversized snapshot');return end
    local hash=X.Hash(payload)
    if not index[hash] then
        local e=C.Record('native_snapshot',source or 'checkpoint',{contentID=hash,family=family},nil,'observed',nil,nil,nil,payload)
        if not e then X.diagnostics.rejected=X.diagnostics.rejected+1;return end
        index[hash]=e;X.diagnostics.saved=X.diagnostics.saved+1
    end
    X.Mark(family,'Readable snapshot saved; native delivery still needs live validation')
    return hash
end
function X.References(data)
    data=data or {}
    for _,key in ipairs({'gear','trait','appearance'}) do
        local ref=X.refs[key]
        if ref and not data[key..'Ref'] then data[key..'Ref']=ref.hash;data[key..'ObservedAt']=ref.at end
    end
    return data
end
function X.Record(kind,source,data,subject,ownRefs)
    if not X.Ready() then return end
    data.evidenceClass,data.outcome,data.outcomeScope=X.Classify(kind,source,data)
    if ownRefs~=false then data=X.References(data) end
    return C.Record(kind,source,data,subject,'observed')
end
function X.Queue(key,fn)
    if not X.Ready() then return end
    if jobs[key] then jobs[key].again=fn;return end
    if #queue>=200 then X.Mark('Enrichment queue','Detail work budget reached; native events retained without guessed details');return end
    jobs[key]={thread=coroutine.create(fn)};queue[#queue+1]=key
end
function X.Yield() coroutine.yield() end
function X.Pump()
    if not X.Ready() or X.Busy() then return end
    if ns.ChronicleEncounters then ns.ChronicleEncounters.InspectPump() end
    for _=1,2 do
        local key=queue[1];if not key then break end
        local job=jobs[key];local ok=coroutine.resume(job.thread)
        if not ok then X.diagnostics.errors=X.diagnostics.errors+1;X.Mark(key,'Collector error; no inferred replacement') end
        if not ok or coroutine.status(job.thread)=='dead' then
            table.remove(queue,1);jobs[key]=nil;if job.again then X.Queue(key,job.again) end
        end
    end
end
function X.Stop()
    owner=nil;index={};jobs={};queue={};X.refs={};X.runID=nil;frame:SetScript('OnUpdate',nil)
    for _,module in ipairs({'ChronicleLoadout','ChronicleCombat','ChronicleEncounters','ChronicleProgress'}) do if ns[module] then ns[module].Stop() end end
end
function X.Flush() if X.Ready() and ns.ChronicleCombat then ns.ChronicleCombat.Flush() end end
function X.Suspend() X.Stop() end
function X.Start()
    if not C.InWorld() then return end
    X.Stop();owner=C.Owner();local c=S.Character(owner,false)
    index=c and X.Index(c) or {}
    local run=X.Record('native_event','control',{recordType='collector_session'},nil,false)
    X.runID=run and run.id
    for _,module in ipairs({'ChronicleLoadout','ChronicleCombat','ChronicleEncounters','ChronicleProgress'}) do if ns[module] then ns[module].Start() end end
    frame:SetScript('OnUpdate',function() local ok=pcall(X.Pump);if not ok then X.diagnostics.errors=X.diagnostics.errors+1 end end)
end
function X.Register(module,events)
    local f=CreateFrame('Frame')
    for _,event in ipairs(events) do X.registered[event]=pcall(f.RegisterEvent,f,event) end
    f:SetScript('OnEvent',function(_,event,...)
        if not X.Ready() then return end
        X.events[event]=(X.events[event] or 0)+1
        local ok=pcall(module.Handle,event,...)
        if not ok then X.diagnostics.errors=X.diagnostics.errors+1;X.Mark(event,'Read failed; no inferred value saved') end
    end)
end
