-- Local evidence for Chronicle and Player Intelligence. No automatic expiry.
local _,ns=...
local S={VERSION=6,CONSENT=5,revision=0}
ns.ChronicleStore=S
local statsCache=setmetatable({},{__mode='k'})
local kinds={recording_start=true,recording_stop=true,session_start=true,time_slice=true,location=true,
    level_change=true,xp_change=true,quest_turnin=true,skill_change=true,money_change=true,
    instance_enter=true,instance_exit=true,group_roster=true,player_observed=true,player_combat=true,
    player_kill_credit=true,player_death=true,character_snapshot=true,skill_observed=true,time_span=true,
    route_segment=true,player_route=true,player_route_gap=true,collection_gap=true,player_state=true,character_detail=true,equipment_observed=true,equipment_change=true,
    quest_accepted=true,quest_removed=true,quest_observed=true,quest_objective=true,loot_offered=true,spell_learned=true,reputation_observed=true,bind_observed=true,olympus_snapshot=true,
    inventory_observed=true,spell_observed=true,achievement_earned=true,native_snapshot=true,native_event=true,loadout_observed=true,important_player=true}
local sources={CHAT_MSG_LOOT=true,control=true,PLAYER_ENTERING_WORLD=true,PLAYER_LOGIN=true,PLAYER_LOGOUT=true,
    CHAT_MSG_ACHIEVEMENT=true,CHAT_MSG_GUILD_ACHIEVEMENT=true,UNIT_TARGET=true,NAME_PLATE_UNIT_ADDED=true,UNIT_DIED=true,UNIT_FLAGS=true,UNIT_FACTION=true,UNIT_LEVEL=true,
    PLAYER_LEAVING_WORLD=true,ZONE_CHANGED=true,ZONE_CHANGED_INDOORS=true,ZONE_CHANGED_NEW_AREA=true,
    PLAYER_LEVEL_UP=true,PLAYER_XP_UPDATE=true,QUEST_TURNED_IN=true,SKILL_LINES_CHANGED=true,
    PLAYER_MONEY=true,GROUP_ROSTER_UPDATE=true,PARTY_MEMBERS_CHANGED=true,
    PLAYER_TARGET_CHANGED=true,UPDATE_MOUSEOVER_UNIT=true,PLAYER_FOCUS_CHANGED=true,
    COMBAT_LOG_EVENT_UNFILTERED=true,PLAYER_DEAD=true,PLAYER_FLAGS_CHANGED=true,checkpoint=true,
    PLAYER_EQUIPMENT_CHANGED=true,UNIT_INVENTORY_CHANGED=true,QUEST_ACCEPTED=true,QUEST_REMOVED=true,QUEST_LOG_UPDATE=true,
    LOOT_OPENED=true,LEARNED_SPELL_IN_TAB=true,UPDATE_FACTION=true,HEARTHSTONE_BOUND=true,PLAYER_ALIVE=true,
    PLAYER_UNGHOST=true,PLAYER_MOUNT_DISPLAY_CHANGED=true,PLAYER_REGEN_ENABLED=true,PLAYER_REGEN_DISABLED=true,
    PLAYER_CONTROL_GAINED=true,PLAYER_CONTROL_LOST=true,UNIT_ENTERED_VEHICLE=true,UNIT_EXITED_VEHICLE=true,
    WANTED_CHANGED=true,RANKINGS_CHANGED=true,PROFILE_CHANGED=true,BAG_UPDATE_DELAYED=true,SPELLS_CHANGED=true,
    LEARNED_SPELL_IN_SKILL_LINE=true,ACHIEVEMENT_EARNED=true,UPDATE_EXHAUSTION=true,HONOR_XP_UPDATE=true,PARTY_KILL=true,PLAYER_PVP_KILLS_CHANGED=true,ENCOUNTER_START=true,ENCOUNTER_END=true,BOSS_KILL=true,
    PVP_MATCH_COMPLETE=true,PVP_MATCH_ACTIVE=true,UPDATE_BATTLEFIELD_SCORE=true,UNIT_SPELLCAST_SUCCEEDED=true,DUEL_REQUESTED=true,DUEL_FINISHED=true,
    DUEL_INBOUNDS=true,DUEL_OUTOFBOUNDS=true,DUEL_COUNTDOWN=true,CHAT_MSG_SYSTEM=true,UNIT_COMBAT=true,CRITERIA_UPDATE=true,FACTION_STANDING_CHANGED=true,NEW_RECIPE_LEARNED=true,TRADE_SKILL_ITEM_CRAFTED_RESULT=true,
    INSPECT_READY=true,UNIT_NAME_UPDATE=true,FRIENDLIST_UPDATE=true,DAMAGE_METER_COMBAT_SESSION_UPDATED=true,DAMAGE_METER_CURRENT_SESSION_UPDATED=true,
    DAMAGE_METER_RESET=true,TRAIT_CONFIG_UPDATED=true,TRAIT_CONFIG_LIST_UPDATED=true,ACTIVE_COMBAT_CONFIG_CHANGED=true,EQUIPMENT_SETS_CHANGED=true,
    ITEM_DATA_LOAD_RESULT=true,BARBER_SHOP_APPEARANCE_APPLIED=true,BARBER_SHOP_RESULT=true,PLAYER_DIFFICULTY_CHANGED=true,UPDATE_INVENTORY_DURABILITY=true,UNIT_STATS=true,CURRENCY_DISPLAY_UPDATE=true,UPDATE_INSTANCE_INFO=true,NEW_MOUNT_ADDED=true,NEW_PET_ADDED=true,NEW_TOY_ADDED=true,TOYS_UPDATED=true,PET_JOURNAL_LIST_UPDATE=true,
    QUEST_LOOT_RECEIVED=true,QUEST_CURRENCY_LOOT_RECEIVED=true,ENCOUNTER_LOOT_RECEIVED=true,GUILD_ROSTER_UPDATE=true,PLAYER_GUILD_UPDATE=true}
local fields={guildBefore=true,guildBeforeRealm=true,guildBeforeRank=true,guildAssociated=true,guildMajority=true,guildGroupSize=true,guildContextMembers=true,guildContextGuildMembers=true,guildContextKnown=true,guildContextSame=true,guildContextUnknown=true,guildName=true,guildRealm=true,guildRank=true,guildMembers=true,orgAffiliation=true,groupEpoch=true,lineID=true,remainingHealthPercent=true,encounterRef=true,bossStatusTotal=true,bossStatusReadCount=true,bossStatusComplete=true,triggerGUID=true,triggerElapsed=true,observedElapsed=true,statisticID=true,categoryID=true,displayValue=true,numericValue=true,nativeScope=true,accountFlag=true,achievementFlags=true,valueDecreased=true,scoreReportID=true,attempts=true,readableRows=true,creatureID=true,creatureName=true,classification=true,duelID=true,opponentGUID=true,phase=true,requestedPhase=true,result=true,resultMethod=true,accepted=true,damageReceived=true,healingReceived=true,windowSeconds=true,coverage=true,droppedSpells=true,loginConfirmed=true,seconds=true,afk=true,before=true,after=true,delta=true,
    beforeLevel=true,afterLevel=true,beforeMax=true,afterMax=true,questID=true,rewardXP=true,rewardCopper=true,
    skill=true,maximum=true,name=true,realm=true,class=true,race=true,faction=true,level=true,guild=true,
    via=true,localSighting=true,encounter=true,subevent=true,direction=true,hostile=true,spellID=true,
    wantedListed=true,wantedBounty=true,wantedKills=true,wantedCycle=true,wantedCheckedAt=true,
    reason=true,members=true,knownMembers=true,sameGuildMembers=true,instanceName=true,xp=true,xpMax=true,copper=true,
    firstAt=true,lastAt=true,firstElapsed=true,lastElapsed=true,samples=true,segment=true,continued=true,pointCount=true,interval=true,
    gapBefore=true,mapID=true,worldMapID=true,method=true,afk=true,dead=true,ghost=true,mounted=true,swimming=true,
    flying=true,onTaxi=true,inCombat=true,inVehicle=true,resting=true,pvp=true,locale=true,clientVersion=true,
    build=true,interface=true,classID=true,raceID=true,sex=true,restedXP=true,honor=true,honorMax=true,honorLevel=true,
    health=true,healthMax=true,power=true,powerMax=true,powerType=true,slot=true,itemID=true,hasCurrent=true,
    previousItemID=true,title=true,objective=true,fulfilled=true,required=true,finished=true,objectiveType=true,
    quantity=true,factionID=true,reaction=true,standing=true,boundAt=true,snapshotID=true,snapshotKind=true,
    board=true,part=true,parts=true,rowCount=true,removedCount=true,apiVersion=true,snapshotMode=true,itemString=true,
    bagID=true,bound=true,rank=true,passive=true,actionID=true,skillLine=true,achievementID=true,frequency=true,suggestedGroup=true,buildDate=true,
    alreadyEarned=true,guildPerk=true,wasReplayQuest=true,skillID=true,contentID=true,family=true,gearRef=true,gearObservedAt=true,
    traitRef=true,traitObservedAt=true,appearanceRef=true,appearanceObservedAt=true,triggerAt=true,observedAt=true,recordType=true,
    attackerGUID=true,targetGUID=true,credit=true,entityKind=true,encounterID=true,difficultyID=true,groupSize=true,success=true,
    winner=true,duration=true,beforeStanding=true,afterStanding=true,recipeID=true,castGUID=true,resultKnown=true,
    sessionID=true,meterType=true,meterEpoch=true,amount=true,count=true,relationship=true,unitVisible=true,inspection=true,partial=true,
    lifetimeHK=true,lifetimeMaxRank=true,sessionHK=true,sessionDK=true,yesterdayHK=true,yesterdayDK=true,combatSeconds=true,evidenceClass=true,outcome=true,outcomeScope=true,currencyID=true,quantityChange=true,quantityGainSource=true,destroyReason=true,collectionType=true,collectionID=true,battlePetGUID=true,baseline=true,scope=true,resetAt=true,resetSeconds=true}
sources.UNIT_AURA=true;sources.NAME_PLATE_UNIT_REMOVED=true
for _,source in ipairs({'UNIT_PET','PARTY_LEADER_CHANGED','PLAYER_ROLES_ASSIGNED','GROUP_JOINED','GROUP_LEFT',
    'UNIT_SPELLCAST_START','UNIT_SPELLCAST_STOP','UNIT_SPELLCAST_INTERRUPTED','UNIT_SPELLCAST_CHANNEL_START','UNIT_SPELLCAST_CHANNEL_STOP',
    'MAIL_SEND_SUCCESS','MAIL_SUCCESS','AUCTION_HOUSE_AUCTION_CREATED','TRADE_SHOW','TRADE_ACCEPT_UPDATE','TRADE_CLOSED',
    'TRADE_REQUEST_CANCEL','PARTY_INVITE_REQUEST','PARTY_INVITE_CANCEL','TAXIMAP_OPENED','TAXIMAP_CLOSED'}) do sources[source]=true end
for _,key in ipairs({'evidenceState','interpretationVersion','sourceVersion','subjectEligibility','fieldReadability','interpretationStatus',
    'sourceOccurrenceKey','attribution','petGUID','assignedRole','groupLeader','groupAssistant','relatedGUID','auctionID','playerAccepted','targetAccepted'}) do fields[key]=true end
for _,key in ipairs({'basisRef','contactKind','sourceActionID','cause1','cause2','cause3','incidentRef','correctedSourceID','matchRef','matchSequence',
    'rosterComplete','rosterSize','rosterRaid','rosterObservedAt','ownerModule'}) do fields[key]=true end
for _,key in ipairs({'runID','auraInstanceID','effectTransition','auraEpoch','transitionKey','subjectScope','evidenceStrength',
    'actorCoverage','applications','expirationTime','helpful','harmful','bossAura','sourceGUID','aggregateVersion','combatContext','combatWindowID'}) do fields[key]=true end
function S.Number(v,min,max)
    return ns.Readable(v) and type(v)=='number' and v==v and v~=math.huge and v~=-math.huge
        and v>=(min or -1000000000000) and v<=(max or 1000000000000) and v or nil
end
function S.Text(v,max)
    -- %c follows the host locale: some clients classify UTF-8 continuation
    -- bytes (for example 0x90) as controls. Only actual ASCII controls and WoW
    -- markup delimiters are forbidden; historical Unicode names stay intact.
    return ns.CanRead(v) and #v>0 and #v<=(max or 144) and not v:find('[|%z\001-\031\127]') and v or nil
end
function S.GUID(v) return S.Text(v,64) and v:match('^Player%-%w[%w%-]*$') and v or nil end
function S.Integer(v,min,max) return S.Number(v,min,max) and v%1==0 and v or nil end
function S.Array(t,max)
    if not ns.Readable(t) or type(t)~='table' or getmetatable(t) or #t>max then return false end
    local count=0;for k in pairs(t) do if not S.Integer(k,1,#t) then return false end;count=count+1 end
    return count==#t
end
for _,key in ipairs({'aggregationVersion','contextRef','contextKind','windowRef','unknownCount','sourceEvidenceSummary','observerSession','castCountOwner'}) do fields[key]=true end
local function Plain(v)
    if not ns.Readable(v) then return end
    if type(v)=='boolean' then return v end
    if type(v)=='number' then return S.Number(v) end
    return S.Text(v,256)
end
local function Detail(t)
    if type(t)~='table' or getmetatable(t) then return end
    local out={};local count=0
    for k,v in pairs(t) do
        count=count+1;if count>40 or not fields[k] then return end
        if k=='members' or k=='guildMembers' or k=='guildContextMembers' or k=='guildContextGuildMembers' then
            if type(v)~='table' or getmetatable(v) or #v>40 then return end
            out[k]={};for i,guid in ipairs(v) do if not S.GUID(guid) then return end;out[k][i]=guid end
        else
            local ref=k=='sourceActionID' or k=='cause1' or k=='cause2' or k=='cause3' or k=='correctedSourceID'
            out[k]=(k=='itemString' or ref) and S.Text(v,512) or Plain(v);if out[k]==nil then return end
        end
    end
    return out
end
local function Location(t)
    if type(t)~='table' or getmetatable(t) then return end
    local out={}
    for _,k in ipairs({'zone','subzone','instanceType','instanceName'}) do
        if t[k]~=nil then out[k]=S.Text(t[k],128);if not out[k] then return end end
    end
    if t.instanceID~=nil then out.instanceID=S.Number(t.instanceID,1,10000000);if not out.instanceID then return end end
    if t.inInstance~=nil then if type(t.inInstance)~='boolean' then return end;out.inInstance=t.inInstance end
    return out
end
-- One dated encounter snapshot, never a route or an inferred subject position.
function S.EncounterPosition(t,guid)
    if type(t)~='table' or getmetatable(t) or t.format~=1 or t.subjectGUID~=guid or not S.GUID(guid)
        or not S.Integer(t.at,1) or not S.Number(t.elapsed,0)
        or (t.timeSource~='server' and t.timeSource~='local-clock') then return end
    local allowed={format=true,subjectGUID=true,at=true,elapsed=true,timeSource=true,observer=true,subject=true}
    for k in pairs(t) do if not allowed[k] then return end end
    local out={format=1,subjectGUID=guid,at=t.at,elapsed=t.elapsed,timeSource=t.timeSource}
    for _,role in ipairs({'observer','subject'}) do
        local p=t[role]
        if p~=nil then
            if type(p)~='table' or getmetatable(p) then return end
            local keys={mapID=true,uiX=true,uiY=true,worldMapID=true,native1=true,native2=true,native3=true}
            for k in pairs(p) do if not keys[k] then return end end
            local clean={}
            for k,v in pairs(p) do
                if k=='mapID' then clean[k]=S.Integer(v,1,10000000)
                elseif k=='worldMapID' then clean[k]=S.Integer(v,0,10000000)
                elseif k=='uiX' or k=='uiY' then clean[k]=S.Number(v,0,1)
                else clean[k]=S.Number(v,-1000000000,1000000000) end
                if clean[k]==nil then return end
            end
            if (clean.mapID~=nil or clean.uiX~=nil or clean.uiY~=nil) and not (clean.mapID and clean.uiX and clean.uiY) then return end
            if (clean.worldMapID~=nil or clean.native1~=nil or clean.native2~=nil or clean.native3~=nil)
                and not (clean.worldMapID and clean.native1 and clean.native2) then return end
            if not clean.uiX and not clean.native1 then return end
            out[role]=clean
        end
    end
    if not out.observer and not out.subject then return end
    return out
end
function S.Event(t,owner,checkpoint)
    checkpoint=type(checkpoint)=='function' and checkpoint or nil -- Preserve callers whose final expression returns an extra GUID.
    if type(t)~='table' or getmetatable(t) or not kinds[t.kind] or not sources[t.source]
        or (t.schema~=1 and t.schema~=2 and t.schema~=3 and t.schema~=4 and t.schema~=5 and t.schema~=S.VERSION) or not S.Text(t.id,256) or not S.Text(t.session,256) or t.character~=owner
        or not S.Number(t.at,1) or not S.Number(t.elapsed,0) or (t.timeSource~='server' and t.timeSource~='local-clock')
        or (t.evidence~='observed' and t.evidence~='confirmed') then return end
    if t.subject~=nil and not S.GUID(t.subject) then return end
    if t.id:sub(1,#owner+1)~=owner..':' or not t.id:sub(#owner+2):match('^%d+$')
        or not S.Integer(tonumber(t.id:sub(#owner+2)),1,1000000000) then return end
    if t.session:sub(1,#owner+2)~=owner..'/s' or not t.session:sub(#owner+3):match('^%d+$') then return end
    local details,location=Detail(t.details),Location(t.location)
    if not details or not location then return end
    if t.kind=='time_slice' and (not S.Number(details.seconds,0,60) or details.afk~=nil and type(details.afk)~='boolean') then return end
    if t.kind=='session_start' and type(details.loginConfirmed)~='boolean' then return end
    if t.kind=='quest_turnin' and not S.Integer(details.questID,1,10000000) then return end
    if t.kind=='level_change' and (not S.Integer(details.before,1,1000) or not S.Integer(details.after,1,1000)
        or details.before==details.after) then return end
    if (t.kind=='skill_change' or t.kind=='skill_observed') and (not S.Text(details.skill) or not S.Integer(details.after,0,100000)) then return end
    if t.kind=='money_change' or t.kind=='xp_change' then
        if not S.Integer(details.before,0) or not S.Integer(details.after,0) or not S.Integer(details.delta) then return end
        if t.kind=='money_change' and details.after-details.before~=details.delta then return end
        if t.kind=='xp_change' and (details.delta<=0 or not S.Integer(details.beforeLevel,1,1000)
            or not S.Integer(details.afterLevel,details.beforeLevel,details.beforeLevel+1)
            or not S.Integer(details.beforeMax,1) or not S.Integer(details.afterMax,1)
            or details.before>=details.beforeMax or details.after>=details.afterMax
            or details.delta~=(details.afterLevel==details.beforeLevel and details.after-details.before
                or details.beforeMax-details.before+details.after)) then return end
    end
    if (t.kind=='player_observed' or t.kind=='player_combat' or t.kind=='player_kill_credit') and not S.GUID(t.subject) then return end
    if t.kind=='player_observed' and (not S.Text(details.name) or type(details.encounter)~='boolean'
        or type(details.localSighting)~='boolean') then return end
    if t.kind=='group_roster' and (type(details.members)~='table' or not S.Integer(details.knownMembers,0,40)
        or #details.members~=details.knownMembers or not S.Integer(details.sameGuildMembers,0,details.knownMembers)) then return end
    if t.kind=='group_roster' and details.rosterComplete~=nil and (type(details.rosterComplete)~='boolean' or type(details.rosterRaid)~='boolean'
        or not S.Integer(details.rosterSize,0,40) or not S.Number(details.rosterObservedAt,1)) then return end
    if details.wantedListed~=nil and type(details.wantedListed)~='boolean' then return end
    for _,key in ipairs({'wantedBounty','wantedKills','wantedCycle','wantedCheckedAt','level'}) do
        if details[key]~=nil and not S.Integer(details[key],0) then return end
    end
    if t.kind=='time_span' and (not S.Number(details.seconds,0) or not S.Integer(details.samples,1)
        or not S.Number(details.firstAt,1) or not S.Number(details.lastAt,details.firstAt)
        or not S.Number(details.firstElapsed,0) or not S.Number(details.lastElapsed,details.firstElapsed)
        or details.seconds>details.lastElapsed-details.firstElapsed+.001 or details.afk~=nil and type(details.afk)~='boolean') then return end
    if t.kind=='quest_accepted' or t.kind=='quest_removed' or t.kind=='quest_observed' or t.kind=='quest_objective' then
        if not S.Integer(details.questID,1,10000000) then return end
    end
    if (t.kind=='equipment_observed' or t.kind=='equipment_change') and not S.Integer(details.slot,1,19) then return end
    if t.kind=='equipment_observed' and not S.Integer(details.itemID,1,1000000000) then return end
    if t.kind=='loot_offered' and (not S.Integer(details.itemID,1,1000000000) or not S.Integer(details.quantity,1,1000000)) then return end
    if t.kind=='spell_learned' and not S.Integer(details.spellID,1,10000000) then return end
    if t.kind=='spell_observed' and not S.Integer(details.spellID,1,10000000) then return end
    if t.kind=='achievement_earned' and not S.Integer(details.achievementID,1,10000000) then return end
    if t.kind=='inventory_observed' and (not S.Integer(details.bagID,0,4) or not S.Integer(details.slot,1,200)
        or type(details.hasCurrent)~='boolean' or details.hasCurrent and (not S.Integer(details.itemID,1,1000000000)
        or not S.Integer(details.quantity,1,1000000)) or not details.hasCurrent and (details.itemID~=nil or details.quantity~=nil)) then return end
    if t.kind=='reputation_observed' and not S.Integer(details.factionID,1,10000000) then return end
    local route
    if t.kind=='route_segment' or t.kind=='player_route' then
        route=S.Route(t.route)
        if not route or details.pointCount~=(route.count or #route.points) or not S.Text(details.segment,256) then return end
    elseif t.route~=nil then return end
    if t.kind=='player_route' or t.kind=='player_route_gap' then
        if not S.GUID(t.subject) or t.subject==owner:match('/(Player%-.+)$') or not S.Text(details.relationship,144)
            or (details.interval~=5 and details.interval~=10) then return end
        if t.kind=='player_route_gap' and not S.Text(details.reason,144) then return end
    end
    local snapshot
    if t.kind=='olympus_snapshot' then
        snapshot=S.Snapshot(t.snapshot)
        if not snapshot or details.snapshotID~=snapshot.id or details.part~=snapshot.part or details.parts~=snapshot.parts then return end
    elseif t.snapshot~=nil then return end
    local capture
    if t.kind=='native_snapshot' then
        capture=ns.ChronicleCapture and ns.ChronicleCapture.Validate(t.capture)
        if not capture or details.family~=capture.family or not ns.ChronicleCapture.MatchesHash(capture,details.contentID,checkpoint and function() checkpoint('checksum blocks',1) end) then return end
    elseif t.capture~=nil then return end
    for _,key in ipairs({'gearRef','traitRef','appearanceRef','contentID'}) do
        if details[key]~=nil and (not S.Text(details[key],64) or #details[key]~=64 or details[key]:find('[^a-f0-9]')) then return end
    end
    if t.kind=='native_event' and (not ns.ChronicleCapture or not ns.ChronicleCapture.ValidActivity(details)) then return end
    if details.evidenceState~=nil then
        if not ns.AthenaObservationSchema.Metadata(details) then return end
    end
    if t.kind=='native_event' and ns.AthenaObservationSchema.types[details.recordType]
        and not ns.AthenaObservationSchema.Record(t,owner) then return end
    local sourceContext
    if not ns.Readable(t.sourceContext) then return end
    if t.sourceContext~=nil then
        sourceContext=ns.AthenaHistorySchema and ns.AthenaHistorySchema.Context(t.sourceContext,owner)
        if not sourceContext then return end
    end
    if t.kind=='native_event' and ns.AthenaHistorySchema and ns.AthenaHistorySchema.types[details.recordType]
        and not ns.AthenaHistorySchema.Record({source=t.source,subject=t.subject,sourceContext=sourceContext,details=details},owner) then return end
    if t.kind=='native_event' and details.recordType=='aura_effect' then
        if not ns.AthenaCombatEvidence.ValidRecord(t,owner) then return end
    end
    if t.kind=='native_event' and details.recordType=='own_spell_success_count' and details.aggregateVersion~=nil
        and (t.subject~=owner:match('/(Player%-.+)$') or not ({checkpoint=true,UNIT_SPELLCAST_SUCCEEDED=true,
            PLAYER_REGEN_ENABLED=true,PLAYER_REGEN_DISABLED=true,PLAYER_LOGOUT=true,PLAYER_LEAVING_WORLD=true,control=true})[t.source]) then return end
    if t.kind=='native_event' and (details.recordType=='guild_affiliation' or details.recordType=='guild_member_observed') then
        if not ({control=true,GUILD_ROSTER_UPDATE=true,PLAYER_GUILD_UPDATE=true})[t.source] or not S.GUID(t.subject) then return end
        if details.recordType=='guild_affiliation' and t.subject~=owner:match('/(Player%-.+)$') then return end
    end
    if details.guildAssociated~=nil then
        if details.guildAssociated~=true or not S.Text(details.guildName,128) or not S.Text(details.guildRealm,128) then return end
        if details.guildGroupSize~=nil then
            local total,known,same,unknown=details.guildGroupSize,details.guildContextKnown,details.guildContextSame,details.guildContextUnknown
            if not S.Integer(total,1,40) or not S.Integer(known,1,total) or not S.Integer(same,1,known)
                or not S.Integer(unknown,0,total) or same+unknown>total
                or type(details.guildMajority)~='boolean' or details.guildMajority~=(total>1 and same>total/2)
                or not details.guildContextMembers or #details.guildContextMembers~=known
                or not details.guildContextGuildMembers or #details.guildContextGuildMembers~=same then return end
            local all,matched={},{}
            for _,guid in ipairs(details.guildContextMembers) do if all[guid] then return end;all[guid]=true end
            for _,guid in ipairs(details.guildContextGuildMembers) do if not all[guid] or matched[guid] then return end;matched[guid]=true end
        end
    end
    if t.kind=='native_event' and details.recordType=='item_received' and (t.source~='CHAT_MSG_LOOT' or t.subject~=owner:match('/(Player%-.+)$')) then return end
    if t.kind=='native_event' and details.recordType=='friend_status' then
        if not S.GUID(t.subject) or not ({control=true,FRIENDLIST_UPDATE=true,PLAYER_TARGET_CHANGED=true,
            UPDATE_MOUSEOVER_UNIT=true,PLAYER_FOCUS_CHANGED=true,NAME_PLATE_UNIT_ADDED=true,UNIT_NAME_UPDATE=true,
            UNIT_FLAGS=true,UNIT_FACTION=true,UNIT_LEVEL=true,UNIT_INVENTORY_CHANGED=true})[t.source]
            or details.baseline~=(details.before==nil) or details.before~=nil and details.before==details.after then return end
    end
    if t.kind=='native_event' and details.recordType=='public_achievement' then
        if not S.GUID(t.subject) or not ({CHAT_MSG_ACHIEVEMENT=true,CHAT_MSG_GUILD_ACHIEVEMENT=true})[t.source] then return end
        if details.scope~=(t.source=='CHAT_MSG_GUILD_ACHIEVEMENT' and 'delivered guild-member announcement' or 'delivered vicinity announcement') then return end
    end
    if t.kind=='native_event' and details.recordType:find('witness_',1,true)==1 then
        if not S.GUID(t.subject) or t.subject==owner:match('/(Player%-.+)$') then return end
        local r=details.recordType
        if r=='witness_ability' then if t.source~='UNIT_SPELLCAST_SUCCEEDED' then return end
        elseif details.method=='native death' then if t.source~='UNIT_DIED' then return end
        elseif not ({NAME_PLATE_UNIT_ADDED=true,UNIT_FLAGS=true,UNIT_FACTION=true,UNIT_NAME_UPDATE=true,UNIT_LEVEL=true,
            PLAYER_TARGET_CHANGED=true,PLAYER_FOCUS_CHANGED=true,UPDATE_MOUSEOVER_UNIT=true,UNIT_TARGET=true,GROUP_ROSTER_UPDATE=true})[t.source] then return end
    end
    if details.evidenceClass~=nil then
        if not ({['native-event']=true,['value-snapshot']=true,['source-aggregate']=true})[details.evidenceClass] then return end
        local class,outcome,scope=ns.ChronicleCapture.Classify(t.kind,t.source,details)
        if details.evidenceClass~=class or details.outcome~=outcome or details.outcomeScope~=scope then return end
    elseif details.outcome~=nil or details.outcomeScope~=nil then return end
    if t.kind=='important_player' and (not S.GUID(t.subject) or not S.Text(details.relationship,144)) then return end
    if t.kind=='loadout_observed' and (not S.Text(details.reason,144) or not S.Integer(details.triggerAt,1)
        or not S.Integer(details.observedAt,details.triggerAt) or not details.gearRef and not details.appearanceRef) then return end
    local position
    if t.encounterPosition~=nil then
        position=S.EncounterPosition(t.encounterPosition,t.subject)
        if not position or t.kind~='player_observed' or details.encounter~=true or details.localSighting~=true
            or position.at>t.at or position.elapsed>t.elapsed or position.timeSource~=t.timeSource then return end
    end
    -- The copied allowlist excludes chat text, code, cycles, frames and arbitrary saved fields.
    return {schema=t.schema,id=t.id,kind=t.kind,source=t.source,session=t.session,character=owner,at=t.at,
        elapsed=t.elapsed,timeSource=t.timeSource,evidence=t.evidence,subject=t.subject,details=details,location=location,
        restored=t.restored==true or nil,route=route,snapshot=snapshot,capture=capture,encounterPosition=position,sourceContext=sourceContext}
end
local snapshotKeys={wanted={place='integer',name='text',guid='text',bounty='integer',kills='integer',cycle='integer'},
    profile={member='boolean',name='text',guild='text',rank='text',rankIndex='integer',role='text',frame='text',title='text'},
    ranking={place='integer',name='text',points='integer',claims='integer',rating='number',wins='integer',losses='integer',games='integer',won='integer'}}
function S.PublicRow(kind,t)
    local keys=snapshotKeys[kind]
    if not keys or not ns.Readable(t) or type(t)~='table' or getmetatable(t) then return end
    local out={}
    for k,v in pairs(t) do
        if not ns.Readable(v) then return end
        local rule=keys[k];if not rule then return end
        if rule=='text' then out[k]=S.Text(v,144)
        elseif rule=='integer' then out[k]=S.Integer(v,0)
        elseif rule=='number' then out[k]=S.Number(v)
        elseif rule=='boolean' and type(v)=='boolean' then out[k]=v end
        if out[k]==nil then return end
    end
    return out
end
function S.Snapshot(t)
    if type(t)~='table' or getmetatable(t) or t.format~=1 or not snapshotKeys[t.kind] or not S.Text(t.board,64)
        or not S.Text(t.id,256) or not S.Integer(t.parts,1,1000) or not S.Integer(t.part,1,t.parts)
        or not S.Integer(t.apiVersion,1,1000) or (t.mode~='full' and t.mode~='delta' and t.mode~='unavailable')
        or not S.Array(t.rows,6) or not S.Array(t.removed,6) then return end
    local allowed={format=true,kind=true,board=true,id=true,part=true,parts=true,apiVersion=true,mode=true,rows=true,removed=true}
    for k in pairs(t) do if not allowed[k] then return end end
    local out={format=1,kind=t.kind,board=t.board,id=t.id,part=t.part,parts=t.parts,apiVersion=t.apiVersion,mode=t.mode,rows={},removed={}}
    local seen={}
    for i,row in ipairs(t.rows) do
        if type(row)~='table' or getmetatable(row) or not S.Text(row.key,200) then return end
        for k in pairs(row) do if k~='key' and k~='values' then return end end
        local value=S.PublicRow(t.kind,row.values);if not value or seen[row.key] then return end;seen[row.key]=true
        out.rows[i]={key=row.key,values=value}
    end
    for i,key in ipairs(t.removed) do if not S.Text(key,200) or seen[key] then return end;out.removed[i]=key;seen[key]=true end
    if t.mode=='unavailable' and (#t.rows>0 or #t.removed>0) or t.mode=='full' and #t.removed>0 then return end
    return out
end
-- Fixed columns retain native values without quantization or guessed transforms.
-- at, elapsed, uiX, uiY, native1, native2, native3, facing, speed, lastAt, lastElapsed, observations.
function S.Route(t)
    if type(t)=='table' and not getmetatable(t) and t.format==2 then
        local keys={format=true,mapID=true,worldMapID=true,count=true,data=true,sha256=true,firstAt=true,lastAt=true,firstElapsed=true,lastElapsed=true,observations=true}
        for k in pairs(t) do if not keys[k] then return end end
        if not S.Integer(t.count,1,60) or not S.Text(t.data,11000) or #t.data%4~=0 or t.data:find('[^A-Za-z0-9+/=]')
            or not S.Text(t.sha256,64) or #t.sha256~=64 or t.sha256:find('[^a-f0-9]')
            or not S.Integer(t.firstAt,1) or not S.Integer(t.lastAt,t.firstAt) or not S.Number(t.firstElapsed,0)
            or not S.Number(t.lastElapsed,t.firstElapsed) or not S.Integer(t.observations,t.count,1000000000) then return end
        local map=S.Integer(t.mapID,1,10000000);local world=S.Integer(t.worldMapID,0,10000000)
        if not map and not world or t.mapID~=nil and not map or t.worldMapID~=nil and not world then return end
        local out={};for k,v in pairs(t) do out[k]=v end;return out
    end
    if type(t)~='table' or getmetatable(t) or t.format~=1 or not S.Array(t.points,60) or #t.points<1 then return end
    for k in pairs(t) do if k~='format' and k~='mapID' and k~='worldMapID' and k~='points' then return end end
    local map=S.Integer(t.mapID,1,10000000);local world=S.Integer(t.worldMapID,0,10000000)
    if not map and not world then return end
    if t.mapID~=nil and not map or t.worldMapID~=nil and not world then return end
    local out={format=1,mapID=map,worldMapID=world,points={}};local last,lastWall
    for i,p in ipairs(t.points) do
        if type(p)~='table' or getmetatable(p) or #p~=12 then return end
        for k in pairs(p) do if not S.Integer(k,1,12) then return end end
        local copy={}
        for j=1,12 do
            if j>=3 and j<=9 and p[j]==false then copy[j]=false
            else
                local min=-1000000000;if j==1 or j==10 then min=1 elseif j==2 or j==11 or j==12 then min=0 end
                copy[j]=S.Number(p[j],min,1000000000000);if copy[j]==nil then return end
            end
        end
        if not S.Integer(p[1],1) or not S.Number(p[2],0) or not S.Integer(p[10],p[1]) or not S.Number(p[11],p[2])
            or not S.Integer(p[12],1,1000000000) or last and p[2]<last or lastWall and p[1]<lastWall then return end
        local ui=map and S.Number(p[3],0,1) and S.Number(p[4],0,1)
        local native=world and S.Number(p[5],-1000000000,1000000000) and S.Number(p[6],-1000000000,1000000000)
        if not ui and not native or (p[3]~=false or p[4]~=false) and not ui
            or (p[5]~=false or p[6]~=false or p[7]~=false) and not native then return end
        if p[8]~=false and not S.Number(p[8],0,math.pi*2+.001) or p[9]~=false and not S.Number(p[9],0,100000) then return end
        out.points[i]=copy;last=p[11];lastWall=p[10]
    end
    return out
end
local function Size(v,depth)
    depth=depth or 0;if depth>8 then return 100000 end
    if type(v)=='string' then return #v*2+8 elseif type(v)=='number' then return 32
    elseif type(v)=='boolean' then return 8 elseif type(v)~='table' then return 0 end
    local n=32;for k,item in pairs(v) do n=n+Size(k,depth+1)+Size(item,depth+1) end;return n
end
S.Size=Size
local function Empty()
    return {events={},profiles={},sequence=0,sessionSequence=0,bytes=0,pruned=0,dropped=0,retainedSince=nil}
end
-- Event payloads are immutable evidence. Share identical scalar context/source
-- rows only after validation, never editable profiles or personal annotations.
-- Both dictionaries are bounded and values are weak; they do not own history.
local sharedRows=setmetatable({},{__mode='k'})
local function ShareEvent(c,event)
    local encode=ns.ChronicleBackup and ns.ChronicleBackup.Encode
    if not encode then return end
    local pool=sharedRows[c]
    if not pool then pool={locations=setmetatable({},{__mode='v'}),rows=setmetatable({},{__mode='v'}),locationCount=0,rowCount=0};sharedRows[c]=pool end
    local function Share(value,key,count,limit)
        local signature=encode(value);local old=pool[key][signature]
        if old then return old end
        if pool[count]>=limit then pool[key]=setmetatable({},{__mode='v'});pool[count]=0 end
        pool[key][signature]=value;pool[count]=pool[count]+1;return value
    end
    event.location=Share(event.location,'locations','locationCount',128)
    if event.snapshot then
        for _,row in ipairs(event.snapshot.rows) do row.values=Share(row.values,'rows','rowCount',512) end
    end
end
-- Validation must never turn unsupported saved information into missing history.
local function Preserved(raw,clean,depth)
    if type(raw)~=type(clean) then return false end
    if type(raw)~='table' then return raw==clean end
    if getmetatable(raw) or (depth or 0)>12 then return false end
    for k,v in pairs(raw) do if not Preserved(v,clean[k],(depth or 0)+1) then return false end end
    return true
end
S.Preserved=Preserved
local function Reject(reason) S.validationFailure=reason;return nil end
local rootKeys={schema=true,consentVersion=true,enabled=true,retention=true,promptSeen=true,characters=true,needsConsentUpgrade=true,
    duelConsent=true,duels=true,olympusState=true,lastRestore=true,retentionDays=true}
local characterKeys={events=true,profiles=true,sequence=true,sessionSequence=true,bytes=true,pruned=true,dropped=true,retainedSince=true,
    currentSession=true,updated=true,revision=true,storageFormat=true,eventChunks=true,profileChunks=true}
function S.Normalize(db,checkpoint,onlyOwner)
    S.validationFailure=nil

    checkpoint=type(checkpoint)=='function' and checkpoint or nil
    if db==nil then db={} end
    if type(db)~='table' or getmetatable(db) then return Reject('Invalid saved history root.') end
    for k in pairs(db) do if not rootKeys[k] then return Reject('Unsupported saved history field; original data kept.') end end
    if db.characters~=nil and (type(db.characters)~='table' or getmetatable(db.characters)) then return Reject('Invalid saved character map.') end
    if db.schema~=nil and db.schema~=1 and db.schema~=2 and db.schema~=3 and db.schema~=4 and db.schema~=5 and db.schema~=S.VERSION then
        -- Never downgrade or overwrite an unrecognized schema, including its consent.
        return nil
    end
    local clean={schema=S.VERSION,consentVersion=S.Integer(db.consentVersion,1,S.CONSENT),
        enabled=db.enabled==true and db.consentVersion==S.CONSENT,
        retention='forever',promptSeen=S.Integer(db.promptSeen,1,S.CONSENT),characters={},
        needsConsentUpgrade=(db.enabled==true or db.needsConsentUpgrade==true) and db.consentVersion~=S.CONSENT or nil}
    if db.duelConsent==1 then clean.duelConsent=1;if type(db.duels)=='boolean' then clean.duels=db.duels end end
    clean.olympusState={}
    if type(db.olympusState)=='table' and not getmetatable(db.olympusState) then
        for key,state in pairs(db.olympusState) do
            if S.Text(key,384) and type(state)=='table' and snapshotKeys[state.kind] and type(state.rows)=='table' and not getmetatable(state.rows) then
                local rows={};local valid=true
                local visited=0
                for id,row in pairs(state.rows) do
                    local value=S.PublicRow(state.kind,row)
                    if not S.Text(id,200) or not value then valid=false;break end;rows[id]=value
                    visited=visited+1;if checkpoint and visited%32==0 then checkpoint('source rows',32) end
                end
                if valid then clean.olympusState[key]={kind=state.kind,rows=rows,unavailable=state.unavailable==true,
                    checkedAt=S.Integer(state.checkedAt,1),snapshotID=S.Text(state.snapshotID,256)} end
            end
        end
    end
    local restore=db.lastRestore
    if type(restore)=='table' and S.Text(restore.batch,64) and #restore.batch==64 and not restore.batch:find('[^a-f0-9]')
        and S.Integer(restore.total,1,1000000000) and type(restore.parts)=='table' and not getmetatable(restore.parts) then
        clean.lastRestore={batch=restore.batch,total=restore.total,parts={}}
        for i,hash in pairs(restore.parts) do
            if S.Integer(i,1,restore.total) and S.Text(hash,64) and #hash==64 and not hash:find('[^a-f0-9]') then clean.lastRestore.parts[i]=hash end
        end
    end
    local chars={}
    if type(db.characters)=='table' and not getmetatable(db.characters) then
        for key,c in pairs(db.characters) do
            if S.Text(key,240) and type(c)=='table' and not getmetatable(c) then
                for field in pairs(c) do if not characterKeys[field] then return Reject('Unsupported saved character field; original data kept.') end end
                chars[#chars+1]={key=key,data=c,updated=S.Number(c.updated,0) or 0}
            else return Reject('Invalid saved character identity or archive.') end
        end
    end
    table.sort(chars,function(a,b) return a.updated>b.updated end)
    for i=1,#chars do
        local key,old=chars[i].key,chars[i].data;local c=Empty();c.updated=chars[i].updated
        for _,field in ipairs({'sequence','sessionSequence'}) do if old[field]~=nil and not S.Integer(old[field],0,1000000000) then return Reject('Invalid saved character sequence; original archive kept.') end end
        for _,field in ipairs({'bytes','pruned','dropped','updated','retainedSince','revision'}) do if old[field]~=nil and not S.Number(old[field],0) then return Reject('Invalid saved character metadata; original archive kept.') end end
        if onlyOwner and key~=onlyOwner and old.storageFormat==1 then
            clean.characters[key]=old -- Opaque archive, not an empty loaded character.
        else
        if old.storageFormat~=nil then
            if old.storageFormat~=1 or not ns.ChronicleBackup or not S.Array(old.eventChunks,1000000000)
                or not S.Array(old.profileChunks,1000000000) then return nil end
            if old.events~=nil or old.profiles~=nil then return Reject('Conflicting packed and expanded history; original archive kept.') end
        end
        -- Decode one bounded chunk into the private candidate, then release it.
        -- The original saved representation is untouched until all characters
        -- validate, so a corrupt later chunk still leaves recovery data intact.
        local function chunks(texts,accept)
            for _,text in ipairs(texts) do
                local records=ns.ChronicleBackup.DecodeChunk(text);if not records then return false end
                for _,record in ipairs(records) do if accept(record)==false then return false end end
                if checkpoint then checkpoint('saved chunks',1) end
            end
            return true
        end
        c.sequence=S.Integer(old.sequence,0,1000000000) or 0;c.sessionSequence=S.Integer(old.sessionSequence,0,1000000000) or 0
        c.pruned=S.Number(old.pruned,0,1000000000) or 0;c.dropped=S.Number(old.dropped,0,1000000000) or 0
        c.currentSession=S.Text(old.currentSession,256)
        if old.currentSession~=nil and (not c.currentSession or c.currentSession:sub(1,#key+2)~=key..'/s'
            or not S.Integer(tonumber(c.currentSession:sub(#key+3)),1,1000000000)) then return Reject('Invalid saved session identity; original archive kept.') end
        if c.currentSession then c.sessionSequence=math.max(c.sessionSequence,tonumber(c.currentSession:sub(#key+3))) end
        local seen={};local eventFailure
        local function acceptEvent(raw)
                local event=S.Event(raw,key,checkpoint)
                if not event or seen[event.id] or not Preserved(raw,event) then return false end
                if event.route and event.route.format==2 and (not ns.ChronicleCodec or not ns.ChronicleCodec.Decode(event.route,
                    checkpoint and function() checkpoint('checksum blocks',1) end)) then
                    eventFailure='A saved route failed its checksum or content validation; original archive kept for recovery.';return false
                end
                if old.storageFormat==1 then event=raw end -- Decoder output is private and fully validated; avoid a retained second copy.
                if event and not seen[event.id] then
                    seen[event.id]=true;local bytes=Size(event)
                    if bytes>((event.kind=='route_segment' or event.kind=='player_route' or event.kind=='native_snapshot') and 131072 or 12000) then return false end
                    ShareEvent(c,event);c.events[#c.events+1]=event;c.bytes=c.bytes+bytes
                    local sequence=tonumber(event.id:match(':(%d+)$'));if sequence then c.sequence=math.max(c.sequence,sequence) end
                end
                return true
        end
        if old.storageFormat==1 then
            if not chunks(old.eventChunks,acceptEvent) then return Reject(eventFailure or 'Invalid, oversized or duplicate saved event; original archive kept.') end
        elseif type(old.events)=='table' and not getmetatable(old.events) then
            if not S.Array(old.events,1000000000) then return Reject('Incomplete legacy event array; original archive kept.') end
            for j=1,#old.events do if not acceptEvent(old.events[j]) then return Reject(eventFailure or 'Unsupported legacy event; original archive kept for recovery.') end;if checkpoint and j%32==0 then checkpoint('events',32) end end
        elseif old.events~=nil then return Reject('Invalid legacy events; original archive kept.')
        end
        seen=nil -- Duplicate validation does not need to remain live during profile rebuilding.
        -- Keep every supported profile; reject partial reconstruction rather than silently dropping it.
        local function acceptProfile(guid,p)
                if S.GUID(guid) and type(p)=='table' and not getmetatable(p) and S.Number(p.firstObserved,1)
                    and S.Number(p.lastObserved,p.firstObserved) and type(p.facts)=='table' and not getmetatable(p.facts) then
                    local facts={};for _,k in ipairs({'name','realm','class','race','faction','level','guild'}) do
                        local f=p.facts[k]
                        local value=type(f)=='table' and (k=='level' and S.Integer(f.value,1,1000) or k~='level' and S.Text(f.value,144))
                        if type(f)=='table' and not getmetatable(f) and value and S.Integer(f.at,1) and sources[f.source] then
                            facts[k]={value=Plain(f.value),at=f.at,source=f.source}
                        end
                    end
                    local profile={guid=guid,firstObserved=p.firstObserved,lastObserved=p.lastObserved,facts=facts,
                        lastSource=sources[p.lastSource] and p.lastSource or nil,restored=p.restored==true or nil}
                    if type(p.personal)=='table' and not getmetatable(p.personal) then
                        profile.personal={note=S.Text(p.personal.note,512),watch=p.personal.watch==true}
                    end
                    if type(p.lastSighting)=='table' and S.Number(p.lastSighting.at,1) and sources[p.lastSighting.source] then
                        local loc=Location(p.lastSighting.observerLocation)
                        if loc then profile.lastSighting={at=p.lastSighting.at,source=p.lastSighting.source,observerLocation=loc} end
                    end
                    if type(p.lastEncounter)=='table' and not getmetatable(p.lastEncounter)
                        and S.Number(p.lastEncounter.at,1,p.lastObserved) and sources[p.lastEncounter.source] then
                        local loc=Location(p.lastEncounter.observerLocation)
                        local position=p.lastEncounter.position and S.EncounterPosition(p.lastEncounter.position,guid)
                        if loc and (not p.lastEncounter.position or position and position.at<=p.lastEncounter.at) then
                            profile.lastEncounter={at=p.lastEncounter.at,source=p.lastEncounter.source,observerLocation=loc,position=position}
                        end
                    end
                    if not Preserved(p,profile) then return false end
                    if old.storageFormat==1 then profile=p end
                    c.profiles[guid]=profile;c.bytes=c.bytes+Size(profile);return true
                end
                return false
        end
        if old.storageFormat==1 then
            local profilesSeen={}
            if not chunks(old.profileChunks,function(p)
                if type(p)~='table' or not S.GUID(p.guid) or profilesSeen[p.guid] then return false end
                profilesSeen[p.guid]=true;return acceptProfile(p.guid,p)
            end) then return Reject('Invalid or partially reconstructed saved profile; original archive kept.') end
        elseif type(old.profiles)=='table' and not getmetatable(old.profiles) then
            local visited=0
            for guid,p in pairs(old.profiles) do if not acceptProfile(guid,p) then return Reject('Unsupported legacy profile; original archive kept for recovery.') end;visited=visited+1;if checkpoint and visited%32==0 then checkpoint('profiles',32) end end
        elseif old.profiles~=nil then return Reject('Invalid legacy profiles; original archive kept.')
        end
        clean.characters[key]=c
        end
    end
    for _,c in pairs(clean.characters) do if not c.storageFormat then c.retainedSince=c.events[1] and c.events[1].at or nil end end
    if db.olympusState and not Preserved(db.olympusState,clean.olympusState) then return Reject('Unsupported Olympus source-state data; original archive kept.') end
    if db.lastRestore and not Preserved(db.lastRestore,clean.lastRestore) then return Reject('Unsupported restore metadata; original archive kept.') end
    return clean
end
local loadFrame=CreateFrame('Frame')
-- Deliberately not parented to a Warden window. New clients can also run this
-- nonvisual worker when the UI is hidden; old clients retain the visible-frame
-- fallback. No timers try to catch up work while the client is suspended.
if loadFrame.SetOnUpdateMode and Enum and Enum.OnUpdateMode and Enum.OnUpdateMode.RunAlways then
    pcall(loadFrame.SetOnUpdateMode,loadFrame,Enum.OnUpdateMode.RunAlways)
end
local loadJob,loadSource,loadEpoch=nil,nil,0
-- Settings may change consent while the archive is being validated. This is
-- metadata only: it must never make unvalidated events a recording destination.
function S.PreferenceRoot()
    local writer=ns.ChronicleStartupJournal and ns.ChronicleStartupJournal.WriteRoot()
    if writer then return writer end
    if not S.blocked and S.db then return S.db end
    if S.loading and ns.DB and ns.DB.chronicle==loadSource and type(loadSource)=='table' and not getmetatable(loadSource)
        and (loadSource.schema==nil or S.Integer(loadSource.schema,1,S.VERSION)) and type(loadSource.characters)=='table' then return loadSource end
    -- Known-format archive metadata remains editable when evidence validation
    -- fails. This grants NO write destination for observations and preserves
    -- the complete original archive, including the rejected record.
    local saved=ns.DB and ns.DB.chronicle
    if S.blocked and type(saved)=='table' and not getmetatable(saved)
        and (saved.schema==nil or S.Integer(saved.schema,1,S.VERSION)) and type(saved.characters)=='table' then return saved end
end
local function LoadProgress(finished)
    local p=S.loadProgress;if not p then return end
    local percent=finished and 100 or p.totalChunks>0 and math.min(99,math.floor(p.chunks*100/p.totalChunks)) or nil
    if percent then
        local milestone=finished and 100 or math.floor(percent/25)*25
        while milestone>(p.announced or 0) do
            p.announced=(p.announced or 0)+25
            ns.Print('Saved archive '..p.announced..'% '..(p.announced==100 and 'validated for your current character. Reading views prepare separately; other character archives load when requested.' or 'validated for your current character ('..p.chunks..' / '..p.totalChunks..' chunks).'))
        end
    end
end
local function Complete(clean,reason)
    local preferences=S.preferencesChanged and S.PreferenceRoot()
    loadFrame:SetScript('OnUpdate',nil);loadJob=nil;loadSource=nil;S.loading=false
    S.loadError=reason;S.revision=S.revision+1
    if not clean then S.db=nil;S.blocked=true;if ns.ChronicleStartup then ns.ChronicleStartup.Cancel() end;return false end
    ns.DB.chronicle=clean;S.db=clean;S.blocked=false
    local writer=ns.ChronicleStartupJournal and ns.ChronicleStartupJournal.WriteRoot()
    if writer then
        -- Consent changes made during validation are authoritative over the
        -- candidate metadata copied when validation started.
        clean.enabled=writer.enabled;clean.consentVersion=writer.consentVersion
        clean.promptSeen=writer.promptSeen;clean.needsConsentUpgrade=writer.needsConsentUpgrade
        clean.duels=writer.duels;clean.duelConsent=writer.duelConsent
    elseif preferences then
        clean.enabled=preferences.enabled;clean.consentVersion=preferences.consentVersion
        clean.promptSeen=preferences.promptSeen;clean.needsConsentUpgrade=preferences.needsConsentUpgrade
        clean.duels=preferences.duels;clean.duelConsent=preferences.duelConsent
    end
    if S.loadProgress then S.loadProgress.finished=ns.SafeCall(GetTime) end
    if S.loadProgress and S.loadProgress.pumps>0 then LoadProgress(true) end
    return true
end
function S.Initialize(cooperative)
    if ns.ChronicleStartup then ns.ChronicleStartup.Cancel() end
    loadEpoch=loadEpoch+1;loadFrame:SetScript('OnUpdate',nil);loadJob=nil;loadSource=nil
    S.loading=false;S.loadError=nil;S.preferencesChanged=nil;S.loadProgress={chunks=0,totalChunks=0,records=0,checksumBlocks=0,pumps=0};S.db=nil;S.blocked=true
    local source=ns.DB.chronicle
    if ns.ChronicleStartup then ns.ChronicleStartup.Begin(source) end
    if cooperative and type(source)=='table' and type(source.characters)=='table' and next(source.characters) then
        local initialOwner=ns.Chronicle and ns.Chronicle.Owner()
        for key,character in pairs(source.characters) do if key==initialOwner and type(character)=='table' and character.storageFormat==1 then
            S.loadProgress.totalChunks=S.loadProgress.totalChunks+(type(character.eventChunks)=='table' and #character.eventChunks or 0)+(type(character.profileChunks)=='table' and #character.profileChunks or 0)
        end end
        S.loading=true;loadSource=source;local token=loadEpoch
        S.loadProgress.started=ns.SafeCall(GetTime);S.loadProgress.lastPump=S.loadProgress.started
        ns.Print('Loading your history safely. Warden can stay closed; enabled collectors preserve new observations in the local recovery journal.')
        loadFrame:Show()
        loadJob=coroutine.create(function()
            local checksumSteps=0;local current=ns.Chronicle and ns.Chronicle.Owner()
            while not current do coroutine.yield();current=ns.Chronicle and ns.Chronicle.Owner() end
            S.loadProgress.owner=current;S.loadProgress.totalChunks=0
            local own=source.characters[current]
            if type(own)=='table' and own.storageFormat==1 then S.loadProgress.totalChunks=#(own.eventChunks or {})+#(own.profileChunks or {}) end
            return S.Normalize(source,function(kind,n)
                if token~=loadEpoch then error('History loading was superseded.') end
                if kind=='checksum blocks' then
                    S.loadProgress.checksumBlocks=S.loadProgress.checksumBlocks+n;checksumSteps=checksumSteps+n
                    if checksumSteps<8 then return end
                elseif kind=='saved chunks' then S.loadProgress.chunks=S.loadProgress.chunks+n else S.loadProgress.records=S.loadProgress.records+n end
                checksumSteps=0
                coroutine.yield()
            end,current)
        end)
        loadFrame:SetScript('OnUpdate',function() S.PumpLoad() end)
        return
    end
    local ok,clean=pcall(S.Normalize,source)
    local loaded=Complete(ok and clean or nil,not ok and 'History validation raised an error; original saved data is preserved.' or not clean and (S.validationFailure or 'History validation failed; original saved data is preserved.') or nil)
    if loaded and ns.ChronicleStartup then ns.ChronicleStartup.Merge() end
    return loaded
end
function S.PumpLoad()
    if not loadJob then return end
    if not ns.DB or ns.DB.chronicle~=loadSource then Complete(nil,'Saved history changed during loading; original data was not replaced.');return end
    if ns.ChronicleStartup and ns.Chronicle then ns.ChronicleStartup.Ensure(ns.Chronicle.WorldReady()) end
    local timer=type(debugprofilestop)=='function' and debugprofilestop
    local start=timer and timer()
    S.loadProgress.pumps=S.loadProgress.pumps+1
    if ns.WardenPerformance and ns.WardenPerformance.active then
        local heap=ns.SafeNumber(ns.SafeCall(collectgarbage,'count'))
        if heap then S.loadProgress.sampledPeakKiB=math.max(S.loadProgress.sampledPeakKiB or 0,heap) end
    end
    local p=S.loadProgress;local now=ns.SafeCall(GetTime);local window=ns.Workspace and ns.Workspace.window
    if window and window:IsShown() then p.openPumps=(p.openPumps or 0)+1 else p.closedPumps=(p.closedPumps or 0)+1 end
    if now then p.longestInterval=math.max(p.longestInterval or 0,p.lastPump and now-p.lastPump or 0);p.lastPump=now end
    -- Startup validation gets a small extra budget outside combat. Keep the
    -- tighter budget in combat and a bounded fallback without a native clock.
    local budget=type(InCombatLockdown)=='function' and InCombatLockdown() and 2 or 4
    for _=1,(start and 128 or 8) do
        local ok,clean=coroutine.resume(loadJob)
        if not ok or coroutine.status(loadJob)=='dead' then
            local loaded=Complete(ok and clean or nil,not ok and 'History validation raised an error; original saved data is preserved.' or not clean and (S.validationFailure or 'History validation failed; original saved data is preserved.') or nil)
            if loaded and ns.Chronicle and ns.Chronicle.Loaded then ns.Chronicle.Loaded() end
            local panel=ns.ChronicleOptionsPanel;if panel and panel.Refresh then pcall(panel.Refresh,panel) end
            if ns.Workspace then ns.Workspace.Queue() end
            return
        end
        if start and timer()-start>=budget then break end
    end
    LoadProgress(false)
end
function S.LoadStatus()
    local p=S.loadProgress or {};local now=ns.SafeCall(GetTime)
    return {loading=S.loading==true,chunks=p.chunks or 0,totalChunks=p.totalChunks or 0,pumps=p.pumps or 0,
        openPumps=p.openPumps or 0,closedPumps=p.closedPumps or 0,longestInterval=p.longestInterval or 0,
        elapsed=now and p.started and math.max(0,(S.loading and now or p.finished or p.lastPump or now)-p.started) or nil,
        currentOwner=p.owner,sampledPeakKiB=p.sampledPeakKiB,
        sinceLastPump=S.loading and now and p.lastPump and math.max(0,now-p.lastPump) or nil,
        workerShown=loadFrame:IsShown(),backgroundFPS=ns.SafeCall(C_CVar and C_CVar.GetCVar or GetCVar,'maxFPSBk')}
end
function S.CancelLoad()
    if S.loading then loadEpoch=loadEpoch+1;Complete(nil,'Client exit interrupted history loading; original saved data is preserved.') end
end
function S.PrepareLogout()
    -- A worker must never advance/remove journal evidence after the saved
    -- history representation has been packed for this client exit.
    if ns.IntelPolicy then ns.IntelPolicy.PreparePriorityCache() end
    if ns.ChronicleStartupJournal then ns.ChronicleStartupJournal.Freeze() end
    if S.blocked or not S.db or not ns.ChronicleBackup then return end
    ns.DB.chronicle=S.db -- A failed pack must retain the newest live data.
    local ok,packed=pcall(ns.ChronicleBackup.PackSaved,S.db)
    if ok and packed then ns.DB.chronicle=packed end
    -- S.db keeps the live ledger for remaining logout callbacks. Only the saved
    -- representation changes; the next Initialize validates/expands its chunks.
end
function S.Character(key,create)
    if S.blocked or not S.db or not S.Text(key,240) then return end
    local chars=S.db.characters;local c=chars[key]
    if not c and create then
        c=Empty();chars[key]=c
    end
    return c
end
function S.Prune(c,now)
    -- Kept as a compatibility entry point. Only explicit Clear removes history.
    c.retainedSince=c.events[1] and c.events[1].at or nil
    c.revision=(c.revision or 0)+1;S.revision=S.revision+1
end
local function Accumulate(out,e,sessions,combat)
    local d=e.details;out.events=out.events+1;out.byKind[e.kind]=(out.byKind[e.kind] or 0)+1
    if e.kind=='character_snapshot' and d.name then out.name=d.name end
    if e.kind=='route_segment' or e.kind=='player_route' then
        local prefix=e.kind=='route_segment' and 'ownRoute' or 'playerRoute'
        out[prefix..'Bytes']=out[prefix..'Bytes']+Size(e);out[prefix..'Segments']=out[prefix..'Segments']+1
        local count=e.route.observations or 0;if e.route.format==1 then for _,p in ipairs(e.route.points) do count=count+p[12] end end
        out[prefix..'Samples']=out[prefix..'Samples']+count
    end
    if e.kind=='player_route_gap' then out.playerRouteBytes=out.playerRouteBytes+Size(e) end
    if e.kind=='player_observed' or e.kind=='important_player' or e.kind=='player_combat'
        or e.kind=='player_kill_credit' or e.kind=='group_roster' or e.kind=='native_event' and e.subject then
        out.playerIntelBytes=out.playerIntelBytes+Size(e)
    end
    if not sessions[e.session] then sessions[e.session]=true;out.recordingSessions=out.recordingSessions+1 end
    if e.kind=='time_slice' or e.kind=='time_span' then
        out.seconds=out.seconds+d.seconds;if d.afk then out.afkSeconds=out.afkSeconds+d.seconds end
        if e.location.zone then out.zones[e.location.zone]=(out.zones[e.location.zone] or 0)+d.seconds end
    elseif e.kind=='session_start' and d.loginConfirmed then out.logins=out.logins+1
    elseif e.kind=='quest_turnin' then out.quests=out.quests+1
    elseif e.kind=='xp_change' and d.delta then out.xp=out.xp+d.delta
    elseif e.kind=='money_change' then out.moneyNet=out.moneyNet+d.delta
    elseif e.kind=='native_event' and d.recordType=='native_kill_credit' then
        out.nativeKillCredits=out.nativeKillCredits+1
        if d.credit=='self native credit' then out.selfNativeCredits=out.selfNativeCredits+1
        elseif d.credit=='current pet native credit' then out.petNativeCredits=out.petNativeCredits+1
        elseif d.credit=='group native credit' then out.groupNativeCredits=out.groupNativeCredits+1 end
        if e.subject and (d.credit=='self native credit' or d.credit=='current pet native credit') then
            out.namedPlayerCredits=out.namedPlayerCredits+1
            if not combat[e.subject] then combat[e.subject]=true;out.combatPlayers=out.combatPlayers+1 end
        end
    elseif e.kind=='player_death' then out.deaths=out.deaths+1
    elseif e.kind=='player_kill_credit' then out.killCredits=out.killCredits+1
    elseif e.kind=='player_combat' and not combat[e.subject] then combat[e.subject]=true;out.combatPlayers=out.combatPlayers+1
    elseif e.kind=='player_observed' and d.encounter then
        out.encounters=out.encounters+1;if d.wantedListed then out.wantedEncounters=out.wantedEncounters+1 end
    end
end
function S.WriteRoot()
    local j=ns.ChronicleStartupJournal
    if j and j.Writing() then return j.WriteRoot() end
    return not S.blocked and S.db or nil
end
function S.WriterCharacter(owner,create)
    local j=ns.ChronicleStartupJournal
    if j and j.Writing() then return j.Character(owner) end
    return S.Character(owner,create)
end
function S.Commit(owner,event,checkpoint)
    local c=S.Character(owner,true);if not c then return end
    local clean=S.Event(event,owner,checkpoint)
    if not clean or not S.Preserved(event,clean) then return end
    if Size(clean)>((clean.kind=='route_segment' or clean.kind=='player_route' or clean.kind=='native_snapshot') and 131072 or 12000) then return end
    c.sequence=math.max(c.sequence,tonumber(clean.id:match(':(%d+)$')) or 0)
    c.sessionSequence=math.max(c.sessionSequence,tonumber(clean.session:match('/s(%d+)$')) or 0)
    local inserted=S.Insert(c,clean)
    if inserted and ns.Athena then ns.Athena.Try(ns.Athena.Notice,inserted,'COMMITTED') end
    return inserted
end
function S.Append(owner,t,originalDetails)
    local c=S.WriterCharacter(owner,true);if not c then return end
    if ns.AthenaIntakeContext then
        local ok=pcall(ns.AthenaIntakeContext.Attach,t,owner)
        if not ok then t.sourceContext=nil;ns.AthenaIntakeContext.diagnostics.contextErrors=ns.AthenaIntakeContext.diagnostics.contextErrors+1 end
    end
    c.sequence=c.sequence+1;t.schema=S.VERSION;t.id=owner..':'..c.sequence;t.character=owner
    local event=S.Event(t,owner)
    if not event and originalDetails and originalDetails~=t.details then
        t.details=originalDetails
        if t.sourceContext then t.sourceContext.linkStatus='LINK_PENDING' end
        event=S.Event(t,owner)
        if event and ns.AthenaIntakeContext then ns.AthenaIntakeContext.diagnostics.contextErrors=ns.AthenaIntakeContext.diagnostics.contextErrors+1 end
    end
    local bytes=event and Size(event)
    if not event or bytes>((event.kind=='route_segment' or event.kind=='player_route' or event.kind=='native_snapshot') and 131072 or 12000) then
        if ns.ChronicleStartupJournal and ns.ChronicleStartupJournal.Character(owner)==c then ns.ChronicleStartupJournal.Reject('Unsupported, unreadable or oversized normal event') end
        c.dropped=c.dropped+1;if statsCache[c] then statsCache[c].value.dropped=c.dropped end
        if ns.AthenaIntakeContext then ns.AthenaIntakeContext.Deny(t.source,type(t.details)=='table' and t.details.recordType or t.kind,'UNSAFE_OR_OVERSIZED_SOURCE') end
        return
    end
    -- A capacity guard denies NEW admission. It never evicts accepted facts.
    if S.admissionBlocked or S.admissionLimitBytes and c.bytes+bytes>S.admissionLimitBytes then
        if ns.AthenaIntakeContext then ns.AthenaIntakeContext.Deny(t.source,event.details.recordType or t.kind,'CAPACITY_DEGRADED') end
        return
    end
    local j=ns.ChronicleStartupJournal
    local accepted,live
    if j and j.Character(owner)==c then
        accepted,live=j.RecordEvent(event)
        if not accepted then c.dropped=c.dropped+1;return end
        if live then c.updated=math.max(c.updated or 0,event.at);if ns.IntelPolicy then ns.IntelPolicy.Notice(event) end;if ns.Athena then ns.Athena.Try(ns.Athena.Notice,event,'STAGED',true,j.WriterGeneration()) end;return event end
    end
    local inserted=S.Insert(c,event)
    if inserted and ns.IntelPolicy then ns.IntelPolicy.Notice(inserted) end
    if inserted and ns.Athena then ns.Athena.Try(ns.Athena.Notice,inserted,accepted and 'STAGED' or 'COMMITTED',true,accepted and j.WriterGeneration() or nil) end
    return inserted
end
function S.Insert(c,event)
    local bytes=Size(event)
    local cached=statsCache[c];if cached and cached.revision~=c.revision then cached=nil end
    local index=#c.events+1
    if c.events[index-1] and c.events[index-1].at>event.at then
        local low,high=1,index
        while low<high do local mid=math.floor((low+high)/2);if c.events[mid] and c.events[mid].at<=event.at then low=mid+1 else high=mid end end
        index=low
    end
    ShareEvent(c,event);table.insert(c.events,index,event);c.bytes=c.bytes+bytes;c.updated=math.max(c.updated or 0,event.at)
    S.Prune(c,event.at)
    if cached then
        Accumulate(cached.value,event,cached.sessions,cached.combat);cached.value.bytes=c.bytes;cached.value.since=c.retainedSince
        cached.revision=c.revision
    end
    return event
end
local profileFacts={'name','realm','class','race','faction','level','guild'}
local profileLocation={'zone','subzone','instanceType','instanceName','instanceID','inInstance'}
local function SameProfileLocation(old,now)
    if type(old)~='table' or not ns.Readable(now) or type(now)~='table' or getmetatable(now) then return false end
    for _,key in ipairs(profileLocation) do if not ns.Readable(now[key]) or old[key]~=now[key] then return false end end
    return true
end
function S.Observe(owner,guid,details,at,source,location,position)
    if ns.Modules and not ns.Modules.Enabled('intel') and guid~=owner:match('/(Player%-.+)$') then return end
    local c=S.WriterCharacter(owner,false);if not c or not S.GUID(guid) then return end
    local p=c.profiles[guid];local existed=p~=nil;local cached=statsCache[c]
    if cached and cached.revision~=c.revision then cached=nil end
    -- Updating numeric timestamps does not change Size(). Reuse identical fact
    -- objects, retaining the same latest times and source as the full path.
    local metadataOnly=p and type(p.lastObserved)=='number' and type(at)=='number' and at>=p.lastObserved and type(p.lastSource)=='string'
        and type(source)=='string' and #p.lastSource==#source and not details.encounter
    if metadataOnly and details.localSighting then
        metadataOnly=p.lastSighting and type(p.lastSighting.at)=='number' and type(p.lastSighting.source)=='string' and #p.lastSighting.source==#source
            and SameProfileLocation(p.lastSighting.observerLocation,location)
    end
    if metadataOnly then for _,key in ipairs(profileFacts) do if details[key]~=nil then
        local fact=p.facts[key]
        if not fact or fact.value~=details[key] or type(fact.at)~='number' or type(fact.source)~='string' or #fact.source~=#source then metadataOnly=false;break end
    end end end
    if metadataOnly then
        local changed=p.lastObserved~=at or p.lastSource~=source;p.lastObserved=at;p.lastSource=source
        if details.localSighting then changed=changed or p.lastSighting.at~=at or p.lastSighting.source~=source;p.lastSighting.at=at;p.lastSighting.source=source end
        for _,key in ipairs(profileFacts) do if details[key]~=nil then local fact=p.facts[key];changed=changed or fact.at~=at or fact.source~=source;fact.at=at;fact.source=source end end
        if changed then c.updated=math.max(c.updated or 0,at);S.Prune(c,at);if cached then cached.revision=c.revision end end
        if ns.ChronicleStartupJournal then ns.ChronicleStartupJournal.RecordProfile(owner,p) end
        return
    end
    local before=p and Size(p) or 0
    if p then c.bytes=c.bytes-before else p={guid=guid,firstObserved=at,facts={}};c.profiles[guid]=p end
    p.firstObserved=math.min(p.firstObserved or at,at);p.lastObserved=math.max(p.lastObserved or at,at);p.lastSource=source
    if details.localSighting then p.lastSighting={at=at,source=source,observerLocation=Location(location) or {}} end
    if details.localSighting and details.encounter then
        p.lastEncounter={at=at,source=source,observerLocation=Location(location) or {},position=position and S.EncounterPosition(position,guid)}
    end
    for _,key in ipairs(profileFacts) do
        if details[key]~=nil then p.facts[key]={value=details[key],at=at,source=source} end
    end
    local after=Size(p);c.bytes=c.bytes+after;c.updated=math.max(c.updated or 0,at);S.Prune(c,at)
    if ns.ChronicleStartupJournal then ns.ChronicleStartupJournal.RecordProfile(owner,p) end
    if cached then
        if not existed then cached.value.profiles=cached.value.profiles+1 end
        cached.value.playerIntelBytes=cached.value.playerIntelBytes+after-before
        cached.value.bytes=c.bytes;cached.value.since=c.retainedSince;cached.revision=c.revision
    end
end
function S.Statistics(owner)
    local c,status=S.Character(owner,false)
    if status=='packed' or status=='failed' then return nil,status end
    local out={events=0,profiles=0,seconds=0,afkSeconds=0,logins=0,
        recordingSessions=0,quests=0,xp=0,moneyNet=0,deaths=0,killCredits=0,combatPlayers=0,encounters=0,wantedEncounters=0,
        nativeKillCredits=0,selfNativeCredits=0,petNativeCredits=0,groupNativeCredits=0,namedPlayerCredits=0,
        ownRouteBytes=0,playerRouteBytes=0,playerIntelBytes=0,ownRouteSegments=0,playerRouteSegments=0,ownRouteSamples=0,playerRouteSamples=0,zones={},byKind={}}
    if not c then return out end
    local cached=statsCache[c]
    if cached and cached.revision==c.revision then return cached.value end
    local sessions,combat={},{}
    out.since=c.retainedSince;out.pruned=c.pruned;out.dropped=c.dropped;out.bytes=c.bytes
    for _,p in pairs(c.profiles) do out.profiles=out.profiles+1;out.playerIntelBytes=out.playerIntelBytes+Size(p) end
    for _,e in ipairs(c.events) do Accumulate(out,e,sessions,combat) end
    statsCache[c]={revision=c.revision,value=out,sessions=sessions,combat=combat}
    return out
end
function S.PlayerStatistics(owner,guid)
    local c,status=S.Character(owner,false)
    if status=='packed' or status=='failed' then return nil,status end
    local out={encounters=0,combatEvents=0,killCredits=0,legacyCombatEvents=0,legacyKillCredits=0,nativeCreditEvents=0,
        selfNativeCredits=0,petNativeCredits=0,groupNativeCredits=0,unattributedNativeCredits=0,importantRecords=0,routeSegments=0,routeSamples=0}
    if not c or not S.GUID(guid) then return out end
    out.since=c.retainedSince
    for _,e in ipairs(c.events) do if e.subject==guid then
        local d=e.details
        if e.kind=='player_observed' and d.encounter then out.encounters=out.encounters+1 end
        if e.kind=='important_player' then out.importantRecords=out.importantRecords+1 end
        if e.kind=='player_route' then
            out.routeSegments=out.routeSegments+1;local n=e.route.observations or 0
            if e.route.format==1 then for _,p in ipairs(e.route.points) do n=n+p[12] end end
            out.routeSamples=out.routeSamples+n
        end
        if e.kind=='player_combat' then out.legacyCombatEvents=out.legacyCombatEvents+1;out.combatEvents=out.combatEvents+1 end
        if e.kind=='player_kill_credit' then out.legacyKillCredits=out.legacyKillCredits+1;out.killCredits=out.killCredits+1 end
        if e.kind=='native_event' and d.recordType=='native_kill_credit' then
            out.nativeCreditEvents=out.nativeCreditEvents+1
            if d.credit=='self native credit' then out.selfNativeCredits=out.selfNativeCredits+1;out.combatEvents=out.combatEvents+1
            elseif d.credit=='current pet native credit' then out.petNativeCredits=out.petNativeCredits+1;out.combatEvents=out.combatEvents+1
            elseif d.credit=='group native credit' then out.groupNativeCredits=out.groupNativeCredits+1
            else out.unattributedNativeCredits=out.unattributedNativeCredits+1 end
        end
        if d.wantedListed~=nil then out.wantedListed=d.wantedListed;out.wantedCheckedAt=d.wantedCheckedAt;out.wantedBounty=d.wantedBounty end
    end end
    -- combatEvents is an evidence-record count, not fights/wins. Legacy kill
    -- counts stay separate because their historical semantics are not upgraded.
    return out
end
function S.Storage()
    local out={packedCharacters=0,loadedCharacters=0,partial=false,bytes=0,events=0,characters=0,largestCharacterBytes=0,stage='normal',ownRouteBytes=0,playerRouteBytes=0,playerIntelBytes=0,breakdown={}}
    for owner,c in pairs(S.db and S.db.characters or {}) do
        out.characters=out.characters+1;out.bytes=out.bytes+(c.bytes or 0)
        if c.storageFormat then
            out.packedCharacters=out.packedCharacters+1;out.partial=true
            out.breakdown[#out.breakdown+1]={owner=owner,name=owner,bytes=c.bytes or 0,loaded=false}
        else
        out.loadedCharacters=out.loadedCharacters+1;out.events=out.events+#c.events
        out.largestCharacterBytes=math.max(out.largestCharacterBytes,c.bytes or 0)
        local stats=S.Statistics(owner);out.ownRouteBytes=out.ownRouteBytes+stats.ownRouteBytes;out.playerRouteBytes=out.playerRouteBytes+stats.playerRouteBytes
        out.playerIntelBytes=out.playerIntelBytes+stats.playerIntelBytes
        out.breakdown[#out.breakdown+1]={owner=owner,name=stats.name or owner,bytes=c.bytes or 0,events=#c.events,
            ownRouteBytes=stats.ownRouteBytes,playerRouteBytes=stats.playerRouteBytes,playerIntelBytes=stats.playerIntelBytes,
            otherBytes=(c.bytes or 0)-stats.ownRouteBytes-stats.playerRouteBytes-stats.playerIntelBytes,
            ownRouteSamples=stats.ownRouteSamples,playerRouteSamples=stats.playerRouteSamples}
        end
    end
    table.sort(out.breakdown,function(a,b) return a.owner<b.owner end);out.otherBytes=math.max(0,out.bytes-out.ownRouteBytes-out.playerRouteBytes-out.playerIntelBytes)
    if out.bytes>=256*1048576 then out.stage='large';out.message='Large retained history. Back up the complete SavedVariables file; loading and text backups may take longer.'
    elseif out.bytes>=64*1048576 then out.stage='growing';out.message='History is growing. Keep a complete file backup before changing PCs or addon versions.'
    else out.message='No automatic deletion. The history-size estimate is approximate, not measured disk size or addon memory.' end
    return out
end
