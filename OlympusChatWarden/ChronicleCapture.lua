-- Typed, content-addressed native snapshots. Objects live in the event ledger,
-- so the original provenance and ordinary backup/clear paths remain authoritative.
local _,ns=...
local function OwnedFrame(...) return ns.Modules and ns.Modules.Frame('history',...) or CreateFrame(...) end
local C,S,B,P=ns.Chronicle,ns.ChronicleStore,ns.ChronicleBackup,ns.PackCrypto
local X={registered={},events={},status={},diagnostics={saved=0,reused=0,collisions=0,rejected=0,errors=0},refs={}};ns.ChronicleCapture=X
local frame=OwnedFrame('Frame');local owner,index,jobs,queue=nil,{},{},{}
local indices=setmetatable({},{__mode='k'})
local schemas={
    gear='guid slots itemGUIDs',traits='guid configID treeID nodes committed exportString specializationID choices choicesComplete nodesRead nodesTotal layoutRefs layoutTree layoutPart layoutParts layoutNodes layoutGroups layoutComplete',
    appearance='guid raceID classID sex nativeDisplayID displayID customizations modelID exact',
    meter='runID sessionID meterType meterEpoch totalAmount durationSeconds sourceIndex sources spells sourceGUID sourceCreatureID',
    scoreboard='runID matchSequence rowIndex name guid killingBlows honorableKills deaths honorGained faction raceName gender classToken damageDone healingDone honorLevel objectives objectiveReadCount objectiveTotal objectivesComplete phase instanceID instanceName instanceType',
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
local activity={item_received=true,guild_affiliation=true,guild_member_observed=true,friend_status=true,public_achievement=true,witness_state=true,witness_death=true,witness_recovery=true,witness_ability=true,collector_session=true,native_kill_credit=true,pvp_counter_snapshot=true,combat_started=true,combat_ended=true,
    own_spell_success_count=true,encounter_started=true,encounter_ended=true,boss_kill_event=true,pvp_match_complete=true,pvp_score_row=true,
    native_meter_reset=true,damage_meter_source=true,damage_meter_spell=true,damage_meter_session=true,duel_requested=true,duel_finished=true,
    duel_inbounds=true,duel_outofbounds=true,trait_tree_nodes=true,barber_choices_applied=true,stats_observed=true,gear_condition_observed=true,
    equipment_set_observed=true,forever_rank_observed=true,native_death_recap=true,reputation_standing_changed=true,recipe_learned=true,native_craft_result=true,
    currency_observed=true,currency_changed=true,collection_observed=true,collection_added=true,lockout_observed=true,lockout_list_observed=true,duel_session_request=true,duel_session_start=true,duel_session_end=true,duel_session_result=true,duel_capture=true,duel_capture_missed=true,duel_combat_summary=true,statistic_observed=true,score_capture_status=true,
    boss_status_observed=true,quest_item_received=true,quest_currency_received=true,encounter_loot_delivery=true}
function X.ValidActivity(d)
    if ns.AthenaHistorySchema and ns.AthenaHistorySchema.types[d.recordType] then return ns.AthenaHistorySchema.Valid(d) end
    if ns.AthenaObservationSchema and ns.AthenaObservationSchema.types[d.recordType] then return ns.AthenaObservationSchema.Valid(d) end
    if d.recordType=='aura_effect' then return ns.AthenaCombatEvidence and ns.AthenaCombatEvidence.Valid(d) or false end
    if not activity[d.recordType] then return false end
    if d.recordType=='guild_affiliation' then
        if type(d.after)~='boolean' or type(d.baseline)~='boolean' or d.baseline~=(d.before==nil) or d.before~=nil and type(d.before)~='boolean' or d.scope~='own native guild affiliation' or d.after and (not S.Text(d.guildName,128) or not S.Text(d.guildRealm,128)) then return false end
    elseif d.recordType=='guild_member_observed' then
        if not S.Text(d.guildName,128) or not S.Text(d.guildRealm,128) or type(d.baseline)~='boolean' or d.scope~='GUID-bearing native guild roster' then return false end
    elseif d.recordType=='friend_status' then
        if type(d.after)~='boolean' or type(d.baseline)~='boolean' or d.before~=nil and type(d.before)~='boolean' or d.scope~='GUID-verified character friend' then return false end
    elseif d.recordType=='public_achievement' then
        if not S.Integer(d.achievementID,1,10000000) or not ({['delivered guild-member announcement']=true,['delivered vicinity announcement']=true})[d.scope] then return false end
    elseif d.recordType=='witness_state' then
        local any=false
        if type(d.baseline)~='boolean' or not S.Text(d.via,32) then return false end
        for _,key in ipairs({'dead','ghost','pvp','hostile','inCombat'}) do if d[key]~=nil then if type(d[key])~='boolean' then return false end;any=true end end
        if not any then return false end
    elseif d.recordType=='witness_death' or d.recordType=='witness_recovery' then
        if d.classification~='unknown' then return false end
        if d.method=='state transition' then
            if type(d.before)~='boolean' or type(d.after)~='boolean' or d.before==d.after
                or d.after~=(d.recordType=='witness_death') or not S.Text(d.via,32) then return false end
        elseif d.method~='native death' or d.recordType~='witness_death' then return false end
        if d.encounterRef~=nil and not S.Text(d.encounterRef,256) then return false end
    elseif d.recordType=='witness_ability' then
        if not S.Integer(d.spellID,1,1000000000) or not S.Text(d.castGUID,128) or not S.Text(d.via,32)
            or d.method~='successful cast' or not ({defensive=true,cooldown=true,support=true,resurrection=true,control=true,offensive=true})[d.classification] then return false end
    end
    if d.recordType=='statistic_observed' and (not S.Integer(d.statisticID,1,10000000) or not S.Integer(d.categoryID,1,10000000) or not S.Text(d.displayValue,256) or d.nativeScope~='unknown' or d.numericValue~=nil and not S.Integer(d.numericValue,0,1000000000000)) then return false end
    if d.recordType and d.recordType:find('duel_',1,true)==1 and d.duelID then
        if not S.Text(d.duelID,256) or d.opponentGUID~=nil and not S.GUID(d.opponentGUID) then return false end
        if d.recordType=='duel_session_result' and (not S.GUID(d.opponentGUID) or not ({win=true,loss=true})[d.result] or d.resultKnown~=true) then return false end
        if d.recordType=='duel_capture' and (not ({before=true,after=true,during=true})[d.phase] or not S.GUID(d.targetGUID) or not S.Integer(d.observedAt,1)) then return false end
        if d.recordType=='duel_combat_summary' and (not S.GUID(d.targetGUID) or not S.Number(d.amount,0) or not S.Integer(d.count,1)) then return false end
    elseif d.recordType=='duel_session_request' or d.recordType=='duel_session_start' or d.recordType=='duel_session_end' or d.recordType=='duel_session_result' or d.recordType=='duel_capture' or d.recordType=='duel_capture_missed' or d.recordType=='duel_combat_summary' then return false end
    if d.recordType=='native_kill_credit' then
        local actor=X.Entity(d.attackerGUID);local target,kind=X.Entity(d.targetGUID)
        if not actor or not target or kind~=d.entityKind or not ({['self native credit']=true,['current pet native credit']=true,
            ['group native credit']=true,unattributed=true})[d.credit] then return false end
    elseif d.recordType=='own_spell_success_count' then
        if not S.Integer(d.spellID,1,10000000) or not S.Integer(d.count,1) or not S.Integer(d.firstAt,1) or not S.Integer(d.lastAt,d.firstAt) then return false end
        if d.aggregateVersion~=nil and (d.aggregateVersion~=2 or d.method~='UNIT_SPELLCAST_SUCCEEDED'
            or not S.Text(d.combatContext,64) or not S.Text(d.runID,256)
            or d.combatWindowID~=nil and not S.Text(d.combatWindowID,256)) then return false end
    elseif d.recordType=='encounter_started' or d.recordType=='encounter_ended' or d.recordType=='boss_kill_event' then
        if not S.Integer(d.encounterID,1,10000000) then return false end
        if d.bossStatusReadCount~=nil and (not S.Integer(d.bossStatusReadCount,0,40) or type(d.bossStatusComplete)~='boolean'
            or d.bossStatusTotal~=nil and not S.Integer(d.bossStatusTotal,d.bossStatusReadCount,1000000)
            or d.bossStatusComplete and d.bossStatusTotal~=d.bossStatusReadCount) then return false end
    elseif d.recordType=='boss_status_observed' then
        if not S.Integer(d.encounterID,1,10000000) or not S.Integer(d.part,1,40) or type(d.partial)~='boolean'
            or d.remainingHealthPercent~=nil and not S.Number(d.remainingHealthPercent,0,100)
            or d.creatureID~=nil and not S.Integer(d.creatureID,1,1000000000)
            or not (d.creatureID or S.Text(d.creatureName,144) or d.remainingHealthPercent) then return false end
    elseif d.recordType=='quest_item_received' or d.recordType=='encounter_loot_delivery' or d.recordType=='item_received' then
        if not S.Integer(d.itemID,1,1000000000) or not S.Integer(d.quantity,1,1000000)
            or d.itemString~=nil and (not S.Text(d.itemString,512) or not d.itemString:match('^item:[%d:%-]+$') or tonumber(d.itemString:match('^item:(%d+)'))~=d.itemID) then return false end
        if d.recordType=='item_received' and (not d.itemString or d.scope~='native self loot message' or not ({LOOT_ITEM_SELF=true,LOOT_ITEM_SELF_MULTIPLE=true,LOOT_ITEM_PUSHED_SELF=true,LOOT_ITEM_PUSHED_SELF_MULTIPLE=true,LOOT_ITEM_CREATED_SELF=true,LOOT_ITEM_CREATED_SELF_MULTIPLE=true})[d.method]) then return false end
        if d.recordType=='quest_item_received' and (not S.Integer(d.questID,1,10000000) or not d.itemString or d.scope~='native quest reward delivery') then return false end
        if d.recordType=='encounter_loot_delivery' and (not S.Integer(d.encounterID,1,10000000) or d.scope~='recipient unknown') then return false end
    elseif d.recordType=='quest_currency_received' then
        if not S.Integer(d.questID,1,10000000) or not S.Integer(d.currencyID,1,10000000) or not S.Integer(d.quantity,1,1000000000) or d.scope~='native quest reward delivery' then return false end
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
    if ns.AthenaHistorySchema and ns.AthenaHistorySchema.types[r] then
        return r=='aura_partial' and 'value-snapshot' or 'native-event','source-observed',r=='aura_partial' and 'provisional-source' or 'source-qualified'
    end
    if ns.AthenaObservationSchema and ns.AthenaObservationSchema.types[r] then
        return (r=='cast_observation' or r=='cast_observation_count' or r=='personal_source' or r=='group_transition') and 'native-event' or 'value-snapshot',
            'source-observed',data.evidenceState=='PROVISIONAL_OBSERVATION' and 'provisional-source' or 'qualified-source'
    end
    if r=='aura_effect' then
        local native=source=='UNIT_AURA' and (data.effectTransition=='applied' or data.effectTransition=='removed')
        return native and 'native-event' or 'value-snapshot',data.effectTransition,'effect-on-subject'
    end
    if r=='public_achievement' and (source=='CHAT_MSG_ACHIEVEMENT' or source=='CHAT_MSG_GUILD_ACHIEVEMENT') then
        return 'native-event','announcement-received',source=='CHAT_MSG_GUILD_ACHIEVEMENT' and 'guild-delivered' or 'vicinity-delivered'
    end
    if r=='witness_death' and source=='UNIT_DIED' and data.method=='native death' then return 'native-event','death-notice','cause-unknown' end
    if (r=='witness_death' or r=='witness_recovery') and data.method=='state transition' then return 'value-snapshot',r=='witness_death' and 'observed-dead' or 'observed-alive','unit-state' end
    if r=='witness_state' then return 'value-snapshot','observed-state','unit-state' end
    if r=='witness_ability' and source=='UNIT_SPELLCAST_SUCCEEDED' then return 'native-event','cast-succeeded','actor-only' end
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
    if r=='item_received' and source=='CHAT_MSG_LOOT' then return 'native-event','receipt-observed','own-native-loot-message' end
    if r=='quest_item_received' and source=='QUEST_LOOT_RECEIVED' or r=='quest_currency_received' and source=='QUEST_CURRENCY_LOOT_RECEIVED' then return 'native-event','reward-delivery','quest' end
    if r=='encounter_loot_delivery' and source=='ENCOUNTER_LOOT_RECEIVED' then return 'native-event','loot-delivery','recipient-unknown' end
    if r=='boss_status_observed' and source=='ENCOUNTER_END' then return 'native-event','boss-status','encounter' end
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
    if ns.ChronicleCoverage then ns.ChronicleCoverage.Note('Native reader','failed','A supported native read failed; no inferred replacement') end
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
    elseif t.family=='traits' then
        if ns.WardenTalents and not ns.WardenTalents.Validate(values) then return end
        if values.specializationID~=nil and not S.Integer(values.specializationID,1,1000000) then return end
        if values.exportString~=nil and not S.Text(values.exportString,5000) then return end
        if values.choices~=nil then
            if not S.GUID(values.guid) or not S.Array(values.choices,80) or type(values.choicesComplete)~='boolean'
                or not S.Integer(values.nodesRead,0,256) or not S.Integer(values.nodesTotal,values.nodesRead,100000)
                or #values.choices>values.nodesRead or values.choicesComplete and values.nodesRead~=values.nodesTotal then return end
            local seenNodes={}
            for _,row in ipairs(values.choices) do
                if not S.Array(row,6) or #row~=6 then return end
                for n=1,4 do if not S.Integer(row[n],1,1000000000) then return end end
                if not S.Integer(row[4],1,1000) then return end
                for n=5,6 do if row[n]~=false and not S.Integer(row[n],1,1000000000) then return end end
                if row[6]~=false and row[5]==false or seenNodes[row[2]] then return end
                seenNodes[row[2]]=true
            end
        elseif values.choicesComplete~=nil or values.nodesRead~=nil or values.nodesTotal~=nil then return end
    elseif t.family=='scoreboard' then
        if values.phase~=nil and not ({['in-progress']=true,['in-progress; start unobserved']=true,['completion observation']=true})[values.phase]
            or values.instanceID~=nil and not S.Integer(values.instanceID,0)
            or values.instanceName~=nil and not S.Text(values.instanceName,144)
            or values.instanceType~=nil and not S.Text(values.instanceType,32) then return end
        if values.objectives~=nil then
        if not S.Array(values.objectives,12) or not S.Integer(values.objectiveReadCount,0,12) or values.objectiveReadCount~=#values.objectives
            or not S.Integer(values.objectiveTotal,values.objectiveReadCount,10000) or type(values.objectivesComplete)~='boolean'
            or values.objectivesComplete and values.objectiveReadCount~=values.objectiveTotal then return end
        local seen={}
        for _,row in ipairs(values.objectives) do
            if not S.Array(row,10) or #row~=10 or not S.Integer(row[1],1,10000000) or seen[row[1]] then return end
            seen[row[1]]=true
            if row[2]~=false and not S.Number(row[2]) or row[3]~=false and not S.Integer(row[3],0,10000) or row[5]~=false and not S.Integer(row[5],0,10000000) then return end
            for _,key in ipairs({4,6,7,8,9,10}) do if row[key]~=false and not S.Text(row[key],key==7 and 256 or 144) then return end end
            if values.objectivesComplete and row[2]==false then return end
        end
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
function X.Hash(t,checkpoint) return P.Hex(P.SHA256(B.Encode(t),checkpoint)) end
function X.MatchesHash(t,expected,checkpoint)
    if not S.Text(expected,64) or #expected~=64 or expected:find('[^a-f0-9]') then return false end
    if X.Hash(t,checkpoint)==expected then return true end
    -- Expanded legacy SavedVariables can parse a native float32 one double ULP
    -- away from its original value. Try that one bounded representation, then
    -- require the ORIGINAL SHA-256 exactly. Neither input nor fingerprint is
    -- rewritten, and unrelated/tampered payloads still fail validation.
    local changed=false
    local function copy(v)
        if type(v)=='number' and v~=0 then
            local magnitude=math.abs(v);local _,exponent=math.frexp(magnitude)
            if exponent>=-148 and exponent<=128 then
                local step=math.ldexp(1,math.max(-149,exponent-24))
                local rounded=math.floor(magnitude/step+.5)*step
                if v<0 then rounded=-rounded end
                if rounded~=v and math.abs(rounded-v)<=4*2.220446049250313e-16*magnitude then changed=true;return rounded end
            end
        elseif type(v)=='table' then
            local out={};for k,value in pairs(v) do out[k]=copy(value) end;return out
        end
        return v
    end
    local candidate=copy(t)
    if changed and X.Hash(candidate,checkpoint)==expected then
        X.diagnostics.numericRoundtrips=(X.diagnostics.numericRoundtrips or 0)+1
        return true,'native float roundtrip'
    end
    -- WoW also serializes expanded double-valued rates with 16 significant
    -- decimal digits. That text can reload a few double ULPs from the hashed
    -- value (e.g. 3/13). Search only its four neighboring double ULPs, with an
    -- absolute work bound. Acceptance STILL requires the original full SHA;
    -- no payload, fingerprint or historical field is changed or skipped.
    local fields={};local bounded=ns.Athena and ns.Athena.Copy(t) or copy(t)
    local function fieldsIn(v)
        local keys={};for k in pairs(v) do keys[#keys+1]=k end
        table.sort(keys,function(a,b) if type(a)==type(b) then return a<b end;return type(a)<type(b) end)
        for _,k in ipairs(keys) do local n=v[k]
            if type(n)=='table' then fieldsIn(n)
            elseif type(n)=='number' and n~=0 and n%1~=0 and #fields<32 then
                local _,exponent=math.frexp(math.abs(n));local delta=math.ldexp(1,exponent-53)
                local options={n};local seen={[string.format('%.17g',n)]=true}
                for distance=1,4 do for _,sign in ipairs({-1,1}) do
                    local v2=n+sign*distance*delta;local key=string.format('%.17g',v2)
                    if not seen[key] then options[#options+1]=v2;seen[key]=true end
                end end
                if #options>1 then fields[#fields+1]={row=v,key=k,options=options} end
            end
        end
    end
    fieldsIn(bounded)
    local attempts=0
    local function match()
        if attempts>=1024 then return false end
        attempts=attempts+1;return X.Hash(bounded,checkpoint)==expected
    end
    -- Single-field changes first: do not make ordinary small legacy repairs
    -- wait behind a combinatorial search over unchanged measurements.
    for _,f in ipairs(fields) do
        for i=2,#f.options do f.row[f.key]=f.options[i];if match() then
            X.diagnostics.numericRoundtrips=(X.diagnostics.numericRoundtrips or 0)+1;return true,'decimal double roundtrip'
        end end;f.row[f.key]=f.options[1]
    end
    -- Multi-field recovery is bounded and cooperative through SHA checkpoints.
    -- If the exact original cannot be established, retain and reject it.
    local function combinations(i)
        if attempts>=1024 then return false end
        if i>#fields then return match() end
        local f=fields[i]
        for _,n in ipairs(f.options) do f.row[f.key]=n;if combinations(i+1) then return true end end
        f.row[f.key]=f.options[1];return false
    end
    if #fields>1 and combinations(1) then
        X.diagnostics.numericRoundtrips=(X.diagnostics.numericRoundtrips or 0)+1;return true,'decimal doubles roundtrip'
    end
    return false
end
function X.SameSnapshot(a,b,hash,checkpoint)
    if not a or not b then return false end
    if B.Encode(a)==B.Encode(b) then return true end
    return X.MatchesHash(a,hash,checkpoint) and X.MatchesHash(b,hash,checkpoint)
end
function X.Find(character,hash)
    -- Historical UI consumers use validated objects; event-time collectors can
    -- additionally resolve newly staged objects before query readiness.
    local c=S.Character(character,false);local found=c and X.Index(c)[hash]
    if found then return found end
    local writing=S.WriterCharacter(character,false)
    return writing and X.Index(writing)[hash]
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
    if not payload then
        if ns.AthenaLab and ns.AthenaLab.Report then ns.AthenaLab.Report(source or 'control',X.Table(values) and S.GUID(values.guid),'VALIDATION_REJECTED',family,'snapshot validation') end
        X.diagnostics.rejected=X.diagnostics.rejected+1;X.Mark(family,'Rejected malformed, unreadable or oversized snapshot');if ns.ChronicleCoverage then ns.ChronicleCoverage.Note('Snapshot','partial','Malformed, unreadable or oversized detail was rejected') end;return
    end
    -- Canonicalize newly captured unordered selections only. Old decoded content
    -- and its original hashes stay byte-for-byte valid.
    if payload.family=='traits' then
        for _,key in ipairs({'choices','nodes'}) do
            local rows=payload.values[key]
            if rows then table.sort(rows,function(a,b) return B.Encode(a)<B.Encode(b) end) end
        end
    end
    local hash=X.Hash(payload)
    if index[hash] then
        if not X.SameSnapshot(index[hash].capture,payload,hash) then
            X.diagnostics.collisions=X.diagnostics.collisions+1;X.diagnostics.rejected=X.diagnostics.rejected+1
            X.Mark(family,'Fingerprint conflict: content not reused; observation details unavailable');return
        end
        X.diagnostics.reused=X.diagnostics.reused+1
    else
        local e=C.Record('native_snapshot',source or 'checkpoint',{contentID=hash,family=family},nil,'observed',nil,nil,nil,payload)
        if not e then
            if ns.AthenaLab and ns.AthenaLab.Report then ns.AthenaLab.Report(source or 'control',values.guid,'WRITE_REJECTED',family,'snapshot writer') end
            X.diagnostics.rejected=X.diagnostics.rejected+1;return
        end
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
function X.Record(kind,source,data,subject,ownRefs,location)
    if not X.Ready() then return end
    data.evidenceClass,data.outcome,data.outcomeScope=X.Classify(kind,source,data)
    -- Own-character configurations must not appear to be another player's gear.
    if ownRefs~=false and (not subject or subject==select(2,C.Owner())) then data=X.References(data) end
    local e=C.Record(kind,source,data,subject,'observed',location)
    if not e and ns.AthenaLab and ns.AthenaLab.Report then ns.AthenaLab.Report(source,subject,'WRITE_REJECTED',kind,'record writer') end
    return e
end
function X.Queue(key,fn,background)
    if not X.Ready() then return end
    if jobs[key] then jobs[key].again=fn;return end
    if #queue>=200 then X.Mark('Enrichment queue','Detail work budget reached; native events retained without guessed details');if ns.ChronicleCoverage then ns.ChronicleCoverage.Note('Enrichment','saturated','Detail queue full; base native events remain separate evidence') end;return end
    jobs[key]={thread=coroutine.create(fn),background=background==true};queue[#queue+1]=key
end
function X.Yield() coroutine.yield() end
function X.Pending() return #queue end
function X.Pump()
    if not X.Ready() then return end
    if ns.AthenaCastCounts then ns.AthenaCastCounts.Pump() end
    if ns.AthenaCombatEvidence then ns.AthenaCombatEvidence.Pump() end
    if ns.ChronicleCombat then ns.ChronicleCombat.Pump() end
    if X.Busy() then return end
    if ns.ChronicleCoverage then ns.ChronicleCoverage.Flush(false) end
    if ns.ChronicleDuels then ns.ChronicleDuels.Pump() end
    if ns.ChronicleStatistics then ns.ChronicleStatistics.Pump() end
    if ns.ChronicleEncounters then ns.ChronicleEncounters.InspectPump() end
    if ns.AthenaEnrichment then ns.AthenaEnrichment.Pump() end
    if ns.IntelPolicy then ns.IntelPolicy.Pump() end
    if ns.IntelWitness then ns.IntelWitness.Pump() end
    for _=1,2 do
        local key=queue[1];if not key then break end
        local job=jobs[key];local ok=coroutine.resume(job.thread)
        if not ok then X.diagnostics.errors=X.diagnostics.errors+1;X.Mark(key,'Collector error; no inferred replacement');if ns.ChronicleCoverage then ns.ChronicleCoverage.Note('Enrichment','failed','A detail task failed; no inferred replacement') end end
        if not ok or coroutine.status(job.thread)=='dead' then
            table.remove(queue,1);jobs[key]=nil;if job.again then X.Queue(key,job.again,job.background) end
        elseif job.background and #queue>1 then
            -- Large optional catalog work yields behind normal enrichment.
            table.remove(queue,1);queue[#queue+1]=key
        end
    end
end
function X.Stop()
    if X.Ready() and ns.ChronicleCombat then ns.ChronicleCombat.Flush() end
    if ns.AthenaCastCounts then ns.AthenaCastCounts.Stop() end
    if ns.AthenaEnrichment then ns.AthenaEnrichment.Stop() end
    if ns.IntelPolicy then ns.IntelPolicy.CancelSeed() end
    if ns.ChronicleCoverage then ns.ChronicleCoverage.Flush(true);ns.ChronicleCoverage.Clear() end
    owner=nil;index={};jobs={};queue={};X.refs={};X.runID=nil;frame:SetScript('OnUpdate',nil)
    for _,module in ipairs({'ChronicleLoadout','ChronicleCombat','ChronicleEncounters','ChronicleProgress','ChronicleDuels','ChronicleStatistics','IntelWitness','AthenaSocial','AthenaGuild','AthenaPersonal','AthenaCombatEvidence','AthenaObservations','AthenaPersonalSources','AthenaFirstContact'}) do if ns[module] then ns[module].Stop() end end
end
function X.Flush()
    if X.Ready() then
        if ns.AthenaCastCounts then ns.AthenaCastCounts.Flush(nil,true) end
        if ns.ChronicleDuels then ns.ChronicleDuels.Interrupt('recording boundary') end
        if ns.ChronicleCombat then ns.ChronicleCombat.Flush() end
        if ns.ChronicleCoverage then ns.ChronicleCoverage.Flush(true) end
    end
end
function X.Suspend() X.Stop() end
function X.Start()
    if not C.InWorld() then return end
    X.Stop();owner=C.Owner();local c=S.WriterCharacter(owner,false)
    index=c and X.Index(c) or {}
    local run=X.Record('native_event','control',{recordType='collector_session'},nil,false)
    X.runID=run and run.id
    if ns.AthenaCastCounts then ns.AthenaCastCounts.Start() end
    for _,module in ipairs({'ChronicleLoadout','ChronicleCombat','ChronicleEncounters','ChronicleProgress','ChronicleDuels','ChronicleStatistics','IntelWitness','AthenaSocial','AthenaGuild','AthenaPersonal','AthenaCombatEvidence','AthenaObservations','AthenaPersonalSources','AthenaFirstContact'}) do
        local scope=(module=='ChronicleEncounters' or module=='IntelWitness' or module=='AthenaSocial' or module=='AthenaFirstContact') and 'intel' or (module=='ChronicleProgress' or module=='ChronicleStatistics' or module=='ChronicleLoadout' or module=='AthenaGuild' or module=='AthenaPersonal' or module=='AthenaPersonalSources') and 'chronicle' or 'history'
        if ns[module] and (not ns.Modules or ns.Modules.Enabled(scope)) then ns[module].Start() end
    end
    if ns.AthenaEnrichment and C.IntelEnabled() then ns.AthenaEnrichment.Start() end
    local idle=0
    frame:SetScript('OnUpdate',function(_,delta)
        -- Queued work still drains every frame. Idle schedulers need only a
        -- tenth-second tick; native callbacks/manual inspection stay immediate.
        local critical=ns.ChronicleEncounters and ns.ChronicleEncounters.Pending() or ns.ChronicleDuels and ns.ChronicleDuels.Pending()
        critical=critical or ns.AthenaCombatEvidence and ns.AthenaCombatEvidence.Pending()>0
        if #queue==0 and not critical then idle=idle+(S.Number(delta,0) or 0);if idle<.1 then return end end
        idle=0;local ok=pcall(X.Pump);if not ok then X.diagnostics.errors=X.diagnostics.errors+1 end
    end)
end
function X.Register(module,events,scope)
    scope=scope or (module==ns.ChronicleEncounters and 'intel' or (module==ns.ChronicleProgress or module==ns.ChronicleStatistics or module==ns.ChronicleLoadout) and 'chronicle' or 'history')
    local f=ns.Modules and ns.Modules.Frame(scope,'Frame') or CreateFrame('Frame')
    for _,event in ipairs(events) do X.registered[event]=pcall(f.RegisterEvent,f,event) end
    f:SetScript('OnEvent',function(_,event,...)
        if not X.Ready() then return end
        X.events[event]=(X.events[event] or 0)+1
        local ok=pcall(module.Handle,event,...)
        if not ok then X.diagnostics.errors=X.diagnostics.errors+1;X.Mark(event,'Read failed; no inferred value saved');if ns.ChronicleCoverage then ns.ChronicleCoverage.Note('Native event','failed','A native event handler failed; no inferred replacement') end end
    end)
end
