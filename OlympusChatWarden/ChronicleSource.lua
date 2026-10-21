-- Pure native source normalization. Inputs are already acquired at event time;
-- no globals, frames, stores, permissions, transport or protected actions here.
-- Both ordinary collectors and Hephaestus call these same small reducers.
local _,ns=...;local S=ns.ChronicleStore
local R={VERSION=1};ns.ChronicleSource=R
function R.Quest(event,a,b,c)
    local id=S.Integer(event=='QUEST_ACCEPTED' and (b~=nil and b or a) or a,1,10000000)
    if not id then return nil,'Unreadable quest identity' end
    if event=='QUEST_TURNED_IN' then return {questID=id,rewardXP=S.Integer(b,0),rewardCopper=S.Integer(c,0)}
    elseif event=='QUEST_ACCEPTED' then return {questID=id}
    elseif event=='QUEST_REMOVED' then local value;if ns.Readable(b) and type(b)=='boolean' then value=b end;return {questID=id,wasReplayQuest=value} end
end
function R.Progress(previous,level,xp,maximum)
    level=S.Integer(level,1,1000);xp=S.Integer(xp,0);maximum=S.Integer(maximum,1)
    local out={}
    if level and previous.level and level~=previous.level then out[#out+1]={kind='level_change',details={before=previous.level,after=level},evidence='confirmed'} end
    if xp and maximum and xp<maximum and level and previous.level and previous.xp and previous.xpMax and previous.xp<previous.xpMax then
        local delta
        if level==previous.level and maximum==previous.xpMax and xp>previous.xp then delta=xp-previous.xp
        elseif level==previous.level+1 then delta=previous.xpMax-previous.xp+xp end
        if delta and delta>0 then out[#out+1]={kind='xp_change',details={before=previous.xp,after=xp,delta=delta,beforeLevel=previous.level,afterLevel=level,beforeMax=previous.xpMax,afterMax=maximum},evidence='observed'} end
    end
    return out,{level=level,xp=xp,xpMax=maximum}
end
function R.Roster(members,sameGuild,count,inRaid,at,state,complete)
    if not S.Array(members,40) or not S.Integer(count,0,40) or not S.Integer(sameGuild,0,#members) then return nil,'Unreadable roster/count' end
    local copy,seen={},{};for _,guid in ipairs(members) do if not S.GUID(guid) or seen[guid] then return nil,'Unreadable or duplicate roster identity' end;copy[#copy+1]=guid;seen[guid]=true end
    table.sort(copy);inRaid=inRaid==true
    if complete==nil then complete=#copy==(inRaid and count or math.max(0,count-1)) end
    if type(complete)~='boolean' then return nil,'Unknown roster completeness' end
    local active=#copy>0 or count>(inRaid and 0 or 1)
    local epoch=(state.groupEpoch or 0)+(active and not state.groupActive and 1 or 0)
    return {members=copy,knownMembers=#copy,sameGuildMembers=sameGuild,groupEpoch=active and epoch or nil,
        rosterComplete=complete,rosterSize=count,rosterRaid=inRaid,rosterObservedAt=at},
        {signature=table.concat(copy,',')..':'..sameGuild..':'..count..':'..tostring(complete),groupActive=active,groupEpoch=epoch}
end
function R.Encounter(event,id,name,difficulty,size,success)
    id=S.Integer(id,1,10000000);if not id then return nil,'Unreadable encounter identity' end
    return {recordType=event=='ENCOUNTER_START' and 'encounter_started' or event=='BOSS_KILL' and 'boss_kill_event' or 'encounter_ended',
        encounterID=id,name=S.Text(name,144),difficultyID=event~='BOSS_KILL' and S.Integer(difficulty,0) or nil,
        groupSize=event~='BOSS_KILL' and S.Integer(size,0,100) or nil,success=event~='BOSS_KILL' and S.Integer(success,0,1) or nil}
end
function R.ItemIdentity(id,link)
    id=S.Integer(id,1,1000000000)
    if not id and ns.CanRead(link) then local item=link:match('|H(item:[^|]+)|h') or link:match('^(item:[%d:%-]+)$');id=item and S.Integer(tonumber(item:match('^item:(%d+)')),1,1000000000) end
    return id,id and ns.ChronicleEvidence.ItemString(link,id)
end
function R.Aura(value)
    if not ns.Readable(value) or type(value)~='table' then return nil,'Aura table unavailable or inaccessible' end
    local id=S.Integer(value.auraInstanceID,1,1000000000);if not id then return nil,'Aura instance identity unavailable' end
    local function Bool(v) if ns.Readable(v) and type(v)=='boolean' then return v end end
    return {auraInstanceID=id,spellID=S.Integer(value.spellId,1,1000000000),applications=S.Integer(value.applications,0,1000000),
        duration=S.Number(value.duration,0),expirationTime=S.Number(value.expirationTime,0),helpful=Bool(value.isHelpful),harmful=Bool(value.isHarmful),bossAura=Bool(value.isBossAura)}
end
function R.Cast(phase,cast,spell)
    if not phase then return nil,'Unsupported cast phase' end
    local id=S.Integer(spell,1,1000000000);local key=S.Text(cast,128)
    local idReason=not ns.Readable(spell) and 'SECRET_OR_RESTRICTED' or id and 'READABLE' or 'UNAVAILABLE'
    local castReason=not ns.Readable(cast) and 'SECRET_OR_RESTRICTED' or key and 'READABLE' or 'UNAVAILABLE'
    return {recordType='cast_observation',spellID=id,castGUID=key,phase=phase,attribution='STATE_ON_SUBJECT',
        scope='native cast phase on subject; no target, effect, learned spell or interrupter inferred'},
        not id or not key,'spellID='..idReason..'; castGUID='..castReason..'; interrupter=UNKNOWN'
end
