-- Evidence collectors shared by Warden Chronicle and Player Intelligence.
-- Disabled until the player explicitly opts in. No chat parsing or network sends.
local _,ns=...
local S=ns.ChronicleStore
local C={diagnostics={events={},errors=0,dropped=0,duplicates=0,gaps=0},ENCOUNTER_GAP=120}
ns.Chronicle=C
local frame=CreateFrame('Frame');local r={};local wantedSubscribed=false;local worldReady=false
local function Call(name,...)
    local fn=_G[name];if type(fn)~='function' then return end
    local ok,a,b,c,d,e,f,g,h=pcall(fn,...);if ok then return a,b,c,d,e,f,g,h end
end
local function Tick() return S.Number(Call('GetTime'),0) end
local function AFK()
    local value=Call('UnitIsAFK','player')
    if not ns.Readable(value) then return end
    if type(value)=='boolean' then return value elseif value==1 then return true elseif value==0 then return false end
end
local function Stamp()
    local at=S.Integer(Call('GetServerTime'),1);local source='server'
    if not at then at=S.Integer(Call('time'),1);source='local-clock' end
    return at,source
end
local function Identity()
    local guid=S.GUID(Call('UnitGUID','player'));local realm=S.Text(Call('GetRealmName'),128)
    if guid and realm then return realm..'/'..guid,guid end
end
local function Allowed()
    return not S.blocked and S.db and S.db.enabled and S.db.consentVersion==S.CONSENT
        and ns.DB and ns.DB.enabled and ns.Membership and ns.Membership.Allowed()
end
function C.Active() return Allowed() and r.running==true end
function C.InWorld() return C.Active() and r.inWorld==true end
local function Place()
    local loc={zone=S.Text(Call('GetRealZoneText'),128),subzone=S.Text(Call('GetSubZoneText'),128)}
    local inside,kind=Call('IsInInstance')
    if ns.Readable(inside) and (type(inside)=='boolean' or inside==1) then
        loc.inInstance=ns.Checked(inside);loc.instanceType=S.Text(kind,128)
        if loc.inInstance then
            local name,typ,_,_,_,_,_,id=Call('GetInstanceInfo')
            if typ==kind then loc.instanceName=S.Text(name,128);loc.instanceID=S.Integer(id,1,10000000) end
        end
    end
    return loc
end
local function SamePlace(a,b)
    return a and b and a.zone==b.zone and a.subzone==b.subzone and a.inInstance==b.inInstance
        and a.instanceID==b.instanceID and a.instanceName==b.instanceName and a.instanceType==b.instanceType
end
local function Emit(kind,source,data,subject,evidence,location,route,snapshot,capture,encounterPosition)
    if not C.Active() or not r.session then return end
    local at,timeSource=Stamp();local tick=Tick();local c=S.Character(r.owner,false)
    if not at or not tick or c and c.updated and at<c.updated then C.diagnostics.dropped=C.diagnostics.dropped+1;return end
    return S.Append(r.owner,{kind=kind,source=source,details=data or {},subject=subject,
        evidence=evidence or 'observed',at=at,timeSource=timeSource,elapsed=tick,
        location=location or r.place or {},session=r.session,route=route,snapshot=snapshot,capture=capture,encounterPosition=encounterPosition})
end
C.Record=Emit;C.Place=Place;C.Stamp=Stamp;C.Tick=Tick
local function FlushTime()
    local p=r.timePending;if not p then return end;r.timePending=nil
    S.Append(r.owner,{schema=S.VERSION,kind='time_span',source='checkpoint',session=r.session,at=p.lastAt,elapsed=p.lastElapsed,
        timeSource=p.timeSource,evidence='observed',location=p.location,
        details={seconds=p.seconds,afk=p.afk,samples=p.samples,firstAt=p.firstAt,lastAt=p.lastAt,firstElapsed=p.firstElapsed,lastElapsed=p.lastElapsed}})
end
local function Timeslice(source)
    local now=Tick();if not r.running or not now then return end
    if r.since and r.inWorld then
        local delta=now-r.since
        if delta>0 and delta<=60 then
            local at,timeSource=Stamp();local c=S.Character(r.owner,false)
            if at and (not c or not c.updated or at>=c.updated) then
                local p=r.timePending
                if p and (p.afk~=r.afk or not SamePlace(p.location,r.place)) then FlushTime();p=nil end
                p=p or {firstAt=r.sliceWall or at,firstElapsed=r.since,seconds=0,samples=0,afk=r.afk,location=r.place,timeSource=timeSource}
                p.seconds=p.seconds+delta;p.samples=p.samples+1;p.lastAt=at;p.lastElapsed=now;r.timePending=p
                if p.seconds>=300 then FlushTime() end
            else C.diagnostics.dropped=C.diagnostics.dropped+1 end
        elseif delta<0 or delta>60 then FlushTime();C.diagnostics.gaps=C.diagnostics.gaps+1 end
    end
    if source~='checkpoint' then FlushTime() end
    r.since=now
    r.sliceWall=Stamp();r.afk=AFK()
end
local function Reset()
    if ns.ChronicleCapture then ns.ChronicleCapture.Flush() end
    FlushTime()
    if ns.ChronicleRoute then ns.ChronicleRoute.Stop() end
    if ns.ChronicleEvidence then ns.ChronicleEvidence.Stop() end
    if ns.ChronicleOlympus then ns.ChronicleOlympus.Stop() end
    if ns.ChronicleCapture then ns.ChronicleCapture.Stop() end
    r={};frame:SetScript('OnUpdate',nil)
end
function C.Flush()
    if not C.InWorld() then return end
    Timeslice('checkpoint');FlushTime()
    if ns.ChronicleCapture then ns.ChronicleCapture.Flush() end
    if ns.ChronicleRoute then ns.ChronicleRoute.Flush() end
end
local function Baseline()
    r.place=Place();r.since=Tick();r.sliceWall=Stamp();r.afk=AFK()
    r.level=S.Integer(Call('UnitLevel','player'),1,1000)
    r.xp=S.Integer(Call('UnitXP','player'),0);r.xpMax=S.Integer(Call('UnitXPMax','player'),1)
    r.money=S.Integer(Call('GetMoney'),0);r.skills=nil;r.roster=nil;r.death=false
end
local function Wanted(rows)
    if not C.Active() then return end
    local at=Stamp();local map={}
    if type(rows)~='table' or getmetatable(rows) or #rows>200 or not at then r.wanted=nil;return end
    for _,row in ipairs(rows) do
        if type(row)~='table' or not S.GUID(row.guid) or not S.Integer(row.bounty,0,1000000000)
            or not S.Integer(row.kills,0,1000000000) or not S.Integer(row.cycle,1,1000000000) or map[row.guid] then r.wanted=nil;return end
        map[row.guid]={wantedListed=true,wantedBounty=row.bounty,wantedKills=row.kills,wantedCycle=row.cycle,wantedCheckedAt=at}
    end
    r.wanted=map;r.wantedAt=at;r.wantedTick=Tick()
end
local function RefreshWanted()
    local connection=ns.OlympusConnection
    if not C.Active() or not connection or connection.permission~='granted' or connection.state~='connected'
        or not connection.Has('wanted') then r.wanted=nil;return end
    if not wantedSubscribed then
        local ok,subscribed=connection.Call('On','WANTED_CHANGED',function(_,rows) Wanted(rows) end)
        wantedSubscribed=ok and subscribed==true
    end
    local now=Tick()
    if now and (not r.wantedRead or now-r.wantedRead>=60) then
        r.wantedRead=now;local ok,rows=connection.Call('GetWanted');if ok then Wanted(rows) else r.wanted=nil end
    end
end
local function WantedDetails(guid,data)
    local now=Tick()
    if r.wanted and now and r.wantedTick and now-r.wantedTick<=90 then
        local listing=r.wanted[guid]
        if listing then for k,v in pairs(listing) do data[k]=v end
        else data.wantedListed=false;data.wantedCheckedAt=r.wantedAt end
    end
end
local function CoordinateRead(unit)
    local api=ns.Readable(C_Map) and type(C_Map)=='table' and C_Map or nil
    local function Safe(fn,...)
        if not ns.Readable(fn) or type(fn)~='function' then return end
        local ok,a,b=pcall(fn,...);if ok then return a,b end
    end
    local map=S.Integer(api and Safe(api.GetBestMapForUnit,unit),1,10000000)
    local x,y
    -- The documented UI-map getter supports player/party. Other units may only
    -- supply ordinary UnitPosition values; no fallback reconstructs hidden data.
    if map and (unit=='player' or unit:match('^party%d+$')) then
        local p=Safe(api.GetPlayerMapPosition,map,unit)
        if ns.Readable(p) and (type(p)=='table' or type(p)=='userdata') then x,y=Safe(p.GetXY,p) end
        x,y=S.Number(x,0,1),S.Number(y,0,1);if not x or not y then x,y=nil,nil end
    end
    local a,b,z,world=Call('UnitPosition',unit)
    a,b,z,world=S.Number(a,-1000000000,1000000000),S.Number(b,-1000000000,1000000000),
        S.Number(z,-1000000000,1000000000),S.Integer(world,0,10000000)
    if not a or not b or not world then a,b,z,world=nil,nil,nil,nil end
    local after=S.Integer(api and Safe(api.GetBestMapForUnit,unit),1,10000000)
    if map~=after then return nil,false end
    if not x and not a then return nil,true end
    return {mapID=x and map or nil,uiX=x,uiY=y,worldMapID=world,native1=a,native2=b,native3=z},true
end
local function EncounterPosition(unit,guid,place)
    local owner=C.Owner();local at,timeSource=Stamp();local elapsed=Tick()
    if not at or not elapsed then return nil,false end
    local observer,observerStable=CoordinateRead('player')
    local subject,subjectStable=CoordinateRead(unit)
    if not C.InWorld() or C.Owner()~=owner or owner~=r.owner or not observerStable or not subjectStable
        or S.GUID(Call('UnitGUID',unit))~=guid or not ns.Checked(Call('UnitIsVisible',unit))
        or not SamePlace(place,Place()) then return nil,false end
    if not observer and not subject then return nil,true end
    return {format=1,subjectGUID=guid,at=at,elapsed=elapsed,timeSource=timeSource,observer=observer,subject=subject},true
end
local function Player(guid,data,source,localSighting,unit)
    if not C.Active() or guid==r.guid or not S.GUID(guid) or not S.Text(data.name) then return end
    local now,at=Tick(),Stamp();local c=S.Character(r.owner,false)
    if not now or not at or c and c.updated and at<c.updated then C.diagnostics.dropped=C.diagnostics.dropped+1;return end
    r.seen=r.seen or {};local previous=r.seen[guid]
    local encounter=localSighting and (not previous or not previous.localAt or now-previous.localAt>=C.ENCOUNTER_GAP) or false
    data.localSighting=localSighting==true;data.encounter=encounter;WantedDetails(guid,data)
    local signature=table.concat({data.name,data.realm or '',data.class or '',data.race or '',data.faction or '',tostring(data.level or ''),data.guild or ''},'\1')
    local changed=not previous or previous.signature~=signature
    local place=Place();local position
    if encounter then
        local stable;position,stable=EncounterPosition(unit,guid,place)
        if not stable then C.diagnostics.dropped=C.diagnostics.dropped+1;return end
    end
    local saved
    if encounter or changed or not previous or now-previous.recorded>=30 then
        saved=Emit('player_observed',source,data,guid,nil,place,nil,nil,nil,position)
    else C.diagnostics.duplicates=C.diagnostics.duplicates+1 end
    if saved or previous then
        -- A failed append must not turn an unsaved event into a profile encounter.
        if not saved then data.encounter=false end
        S.Observe(r.owner,guid,data,saved and saved.at or at,source,place,position)
        r.seen[guid]={signature=signature,recorded=saved and now or previous.recorded,
            localAt=localSighting and now or previous and previous.localAt}
    end
    -- Runtime deduplication is bounded independently of SavedVariables.
    local count=0;for _ in pairs(r.seen) do count=count+1 end
    if count>600 then local old,stamp;for id,v in pairs(r.seen) do if not stamp or v.recorded<stamp then old,stamp=id,v.recorded end end;r.seen[old]=nil end
end
function C.ObserveUnit(unit,source,localSighting)
    if not C.InWorld() or not ns.Checked(Call('UnitIsPlayer',unit)) then return end
    local guid=S.GUID(Call('UnitGUID',unit));if not guid or guid==r.guid then return end
    local name,realm=Call(type(UnitFullName)=='function' and 'UnitFullName' or 'UnitName',unit)
    name=S.Text(name);if not name then return end
    local _,class=Call('UnitClass',unit);local _,race=Call('UnitRace',unit)
    local data={name=name,realm=S.Text(realm,128),class=S.Text(class,64),race=S.Text(race,64),
        faction=S.Text(Call('UnitFactionGroup',unit),64),level=S.Integer(Call('UnitLevel',unit),1,1000),
        guild=S.Text(Call('GetGuildInfo',unit),128),via=unit}
    -- A unit token can be recycled while its fields are being read.
    if S.GUID(Call('UnitGUID',unit))~=guid then C.diagnostics.dropped=C.diagnostics.dropped+1;return end
    -- A remote target/focus token or roster entry is not a personal sighting.
    localSighting=localSighting==true and ns.Checked(Call('UnitIsVisible',unit))
    Player(guid,data,source,localSighting,unit)
    return guid,data
end
local function Location(source)
    local nextPlace=Place()
    if not SamePlace(nextPlace,r.place) then
        Timeslice(source)
        if r.place and r.place.inInstance and (not nextPlace.inInstance or r.place.instanceID~=nextPlace.instanceID
            or r.place.instanceName~=nextPlace.instanceName) then Emit('instance_exit',source,{},nil,'observed',r.place) end
        if nextPlace.inInstance and (not r.place or not r.place.inInstance or r.place.instanceID~=nextPlace.instanceID
            or r.place.instanceName~=nextPlace.instanceName) then Emit('instance_enter',source,{},nil,'observed',nextPlace) end
        r.place=nextPlace;Emit('location',source,{})
    end
end
local function Progress(source)
    local level=S.Integer(Call('UnitLevel','player'),1,1000)
    local xp,max=S.Integer(Call('UnitXP','player'),0),S.Integer(Call('UnitXPMax','player'),1)
    if level and r.level and level~=r.level then Emit('level_change',source,{before=r.level,after=level},nil,'confirmed') end
    if xp and max and xp<max and level and r.level and r.xp and r.xpMax and r.xp<r.xpMax then
        local delta
        if level==r.level and max==r.xpMax and xp>r.xp then delta=xp-r.xp
        elseif level==r.level+1 then delta=r.xpMax-r.xp+xp end
        if delta and delta>0 then Emit('xp_change',source,{before=r.xp,after=xp,delta=delta,
            beforeLevel=r.level,afterLevel=level,beforeMax=r.xpMax,afterMax=max},nil,'observed') end
    end
    r.level,r.xp,r.xpMax=level,xp,max
end
local function Skills(source)
    if InCombatLockdown and InCombatLockdown() then r.skillsPending=true;return end
    local modern=ns.Readable(C_SkillInfo) and type(C_SkillInfo)=='table' and type(C_SkillInfo.GetNumSkillLines)=='function'
    local countFn=modern and C_SkillInfo.GetNumSkillLines or _G.GetNumSkillLines
    local infoFn=modern and C_SkillInfo.GetSkillLineInfo or _G.GetSkillLineInfo
    if type(countFn)~='function' or type(infoFn)~='function' then return end
    local ok,value=pcall(countFn);local count=ok and S.Integer(value,0,400);if not count then return end
    local nextSkills={}
    for i=1,count do
        local good,name,header,_,rank,_,_,maximum=pcall(infoFn,i)
        local id
        if modern then
            local row=good and ns.Readable(name) and type(name)=='table' and not getmetatable(name) and name
            if not row then return end
            id=S.Integer(row.skillID,1,10000000);name=S.Text(row.name);header=row.isHeader
            rank=S.Integer(row.rank,0,100000);maximum=S.Integer(row.maxRank,0,100000)
        else name=S.Text(name);rank=S.Integer(rank,0,100000);maximum=S.Integer(maximum,0,100000) end
        if good and name and ns.Readable(header) and not ns.Checked(header) and rank and maximum and rank<=maximum then
            local key=modern and id or name
            if not key or nextSkills[key] then return end
            nextSkills[key]={name=name,id=id,rank=rank,maximum=maximum}
        end
    end
    for key,item in pairs(nextSkills) do
        local old=r.skills and r.skills[key]
        local data={skill=item.name,skillID=item.id,after=item.rank,maximum=item.maximum}
        if old and old.rank~=item.rank then data.before=old.rank;Emit('skill_change',source,data,nil,'observed')
        elseif not old then Emit('skill_observed',source,data,nil,'observed') end
    end
    r.skills=nextSkills;r.skillsPending=nil
end
local function Roster(source)
    if InCombatLockdown and InCombatLockdown() then r.rosterPending=true;return end
    local raidCount=S.Integer(Call('GetNumRaidMembers'),0,40)
    local inRaid=ns.Checked(Call('IsInRaid')) or raidCount and raidCount>0
    local count=S.Integer(Call('GetNumGroupMembers'),0,40)
    if not count then local party=S.Integer(Call('GetNumPartyMembers'),0,4);count=inRaid and raidCount or party and party+1 end
    if not count then return end
    local members,seen={},{};local sameGuild=0
    local ownGuild=S.Text(Call('GetGuildInfo','player'),128)
    for i=1,(inRaid and count or math.max(0,count-1)) do
        local unit=(inRaid and 'raid' or 'party')..i
        local guid,data=C.ObserveUnit(unit,source,false)
        if guid and not seen[guid] then
            seen[guid]=true;members[#members+1]=guid
            if ownGuild and data.guild==ownGuild then sameGuild=sameGuild+1 end
        end
    end
    table.sort(members);local signature=table.concat(members,',')..':'..sameGuild
    if r.roster~=signature then Emit('group_roster',source,{members=members,knownMembers=#members,sameGuildMembers=sameGuild});r.roster=signature end
    r.rosterPending=nil
end
-- Midnight/Forever restrict raw combat-log access. Do not register or probe it:
-- pcall does not prevent ADDON_ACTION_FORBIDDEN. Older observations stay readable.
C.combatSupport='Disabled: this client restricts addon combat-log access.'
function C.Start(source,reload,login)
    if not Allowed() or r.running then return end
    local owner,guid=Identity();local now=Tick();local at=Stamp()
    if not owner or not now or not at then C.diagnostics.dropped=C.diagnostics.dropped+1;return end
    local c=S.Character(owner,true);if not c then return end
    if not reload or not c.currentSession then
        c.sessionSequence=c.sessionSequence+1;c.currentSession=owner..'/s'..c.sessionSequence
    end
    r={owner=owner,guid=guid,session=c.currentSession,running=true,inWorld=true}
    Baseline()
    if not reload then Emit('session_start',source,{loginConfirmed=login==true},nil,login and 'confirmed' or 'observed') end
    Emit('recording_start',source,{reason=reload and 'ui-reload' or 'recording-enabled'})
    local name,realm=Call(type(UnitFullName)=='function' and 'UnitFullName' or 'UnitName','player')
    Emit('character_snapshot',source,{name=S.Text(name),realm=S.Text(realm),level=r.level,xp=r.xp,xpMax=r.xpMax,copper=r.money})
    Emit('location',source,{})
    if r.place.inInstance then Emit('instance_enter',source,{reason='recording-started-inside'}) end
    Skills('SKILL_LINES_CHANGED');Roster('GROUP_ROSTER_UPDATE');RefreshWanted()
    if ns.ChronicleRoute then ns.ChronicleRoute.Start() end
    if ns.ChronicleEvidence then ns.ChronicleEvidence.Start() end
    if ns.ChronicleOlympus then ns.ChronicleOlympus.Start() end
    if ns.ChronicleCapture then ns.ChronicleCapture.Start() end
    local elapsed=0
    local function Checkpoint(_,delta)
        elapsed=elapsed+(S.Number(delta,0) or 0)
        if elapsed<1 then return end;elapsed=0
        if not Allowed() then Reset();return end
        if Identity()~=r.owner then Reset();return end
        local now=Tick()
        if now and r.since and now-r.since>=30 and r.inWorld then Timeslice('checkpoint');RefreshWanted() end
        if not (InCombatLockdown and InCombatLockdown()) then
            if r.skillsPending then Skills('SKILL_LINES_CHANGED') end
            if r.rosterPending then Roster('GROUP_ROSTER_UPDATE') end
        end
    end
    frame:SetScript('OnUpdate',function(...)
        local ok=pcall(Checkpoint,...);if not ok then C.diagnostics.errors=C.diagnostics.errors+1 end
    end)
end
function C.RefreshGate()
    if ns.Initializing then return end
    if C.MaybePrompt then C.MaybePrompt() end
    if not Allowed() then Reset()
    elseif worldReady and not r.running then C.Start('control',false,false) end
end
function C.SetEnabled(value)
    if type(value)~='boolean' or S.blocked or not S.db then return false end
    if value and not ns.Membership.Allowed() then return false end
    if value and C.Active() then return true end
    if not value and C.Active() then Timeslice('control');Emit('recording_stop','control',{reason='opted-out'}) end
    Reset();S.db.enabled=value;S.db.promptSeen=S.CONSENT;S.db.needsConsentUpgrade=nil;if value then S.db.consentVersion=S.CONSENT end
    if value and ns.Checked(Call('IsLoggedIn')) then C.Start('control',false,false) end
    return true
end
function C.Clear()
    if not S.db or S.blocked then return false end
    -- Clearing always stops recording; it never immediately repopulates history.
    Reset();S.db.enabled=false;S.db.characters={};S.db.olympusState={};S.db.lastRestore=nil;S.db.needsConsentUpgrade=nil;S.revision=S.revision+1
    if ns.ChronicleBackup then ns.ChronicleBackup.Cancel() end
    if ns.ChronicleActivities then ns.ChronicleActivities.Clear() end
    if ns.RecordingUI then ns.RecordingUI.ClearCachedView() end
    return true
end
function C.Owner() return Identity() end
function C.Statistics()
    local saved=S.Statistics(C.Owner());if not r.timePending then return saved end
    local out={};for k,v in pairs(saved) do out[k]=v end
    out.seconds=out.seconds+r.timePending.seconds
    if r.timePending.afk then out.afkSeconds=out.afkSeconds+r.timePending.seconds end
    out.zones={};for k,v in pairs(saved.zones) do out.zones[k]=v end
    local zone=r.timePending.location.zone;if zone then out.zones[zone]=(out.zones[zone] or 0)+r.timePending.seconds end
    return out
end
function C.Profile(guid)
    local c=S.Character(C.Owner(),false);local p=c and c.profiles[S.GUID(guid) or '']
    if not p then return end
    -- Read-only copies for future UI consumers.
    local copy={guid=p.guid,firstObserved=p.firstObserved,lastObserved=p.lastObserved,lastSource=p.lastSource,facts={},restored=p.restored}
    for key,f in pairs(p.facts) do copy.facts[key]={value=f.value,at=f.at,source=f.source} end
    if p.personal then copy.personal={note=p.personal.note,watch=p.personal.watch} end
    if p.lastSighting then
        local loc={};for k,v in pairs(p.lastSighting.observerLocation) do loc[k]=v end
        copy.lastSighting={at=p.lastSighting.at,source=p.lastSighting.source,observerLocation=loc}
    end
    if p.lastEncounter then
        local loc={};for k,v in pairs(p.lastEncounter.observerLocation) do loc[k]=v end
        copy.lastEncounter={at=p.lastEncounter.at,source=p.lastEncounter.source,observerLocation=loc,
            position=p.lastEncounter.position and S.EncounterPosition(p.lastEncounter.position,p.guid)}
    end
    return copy
end
function C.SetPersonal(guid,note,watch)
    local c=S.Character(C.Owner(),false);local p=c and c.profiles[S.GUID(guid) or '']
    if not p or not Allowed() or note~=nil and note~='' and not S.Text(note,512) or watch~=nil and type(watch)~='boolean' then return false end
    c.bytes=c.bytes-S.Size(p);p.personal=p.personal or {}
    if note~=nil then p.personal.note=note~='' and note or nil end
    if watch~=nil then p.personal.watch=watch end
    c.bytes=c.bytes+S.Size(p);S.Prune(c,Stamp());return true
end
function C.PlayerStatistics(guid) return S.PlayerStatistics(C.Owner(),guid) end

function C.Status()
    if S.blocked then return 'Recording unavailable: saved history could not be loaded. Original data is preserved.' end
    if S.db and S.db.needsConsentUpgrade then return 'Recording paused until you review Chronicle and Player Intelligence recording. /ocw chronicle prompt'
    end
    if not S.db or not S.db.enabled then return 'Recording off. No new Chronicle or Player Intelligence history is saved.' end
    if not Allowed() then return 'Recording paused. ChatWarden must be enabled and Olympus membership available.' end
    return C.Active() and 'Recording Chronicle and Player Intelligence on this computer.' or 'Recording enabled; waiting for a supported character identity and world entry.'
end
function C.Initialize()
    Reset();worldReady=false;C.promptReady=false;S.Initialize()
end
function C.Handle(event,...)
    if not S.db then return end
    if event=='PLAYER_ENTERING_WORLD' then worldReady=true;C.promptReady=true;if C.MaybePrompt then C.MaybePrompt() end
    elseif event=='PLAYER_LOGOUT' then worldReady=false end
    if not Allowed() then Reset();if event=='PLAYER_LOGOUT' then S.PrepareLogout() end;return end
    if r.running and Identity()~=r.owner then Reset() end
    C.diagnostics.events[event]=(C.diagnostics.events[event] or 0)+1
    if event=='PLAYER_ENTERING_WORLD' then
        local initial,reload=...
        if not r.running then C.Start(event,reload==true,initial==true)
        else Location(event);r.inWorld=true;Baseline();Skills('SKILL_LINES_CHANGED');Roster('GROUP_ROSTER_UPDATE');RefreshWanted()
            if ns.ChronicleRoute then ns.ChronicleRoute.Resume('world-entry') end
            if ns.ChronicleEvidence then ns.ChronicleEvidence.Start() end
            if ns.ChronicleCapture then ns.ChronicleCapture.Start() end
        end
        return
    elseif not r.running then if event=='PLAYER_LOGOUT' then S.PrepareLogout() end;return end
    if event=='PLAYER_LOGOUT' or event=='PLAYER_LEAVING_WORLD' then
        if ns.ChronicleCapture then ns.ChronicleCapture.Flush() end
        Timeslice(event);r.inWorld=false
        if ns.ChronicleRoute then ns.ChronicleRoute.Suspend('loading-screen') end
        if ns.ChronicleEvidence then ns.ChronicleEvidence.Suspend() end
        if ns.ChronicleCapture then ns.ChronicleCapture.Suspend() end
        if event=='PLAYER_LOGOUT' then Emit('recording_stop',event,{reason='client-unload'});Reset();S.PrepareLogout() end
    elseif not r.inWorld then return
    elseif event:find('ZONE_CHANGED',1,true)==1 then Location(event)
    elseif event=='PLAYER_XP_UPDATE' then local unit=...;if unit=='player' or unit==nil then Progress(event) end
    elseif event=='PLAYER_LEVEL_UP' then Progress(event)
    elseif event=='QUEST_TURNED_IN' then
        local id,xp,money=...;id=S.Integer(id,1,10000000)
        if not id then C.diagnostics.dropped=C.diagnostics.dropped+1;return end
        r.quests=r.quests or {};local now=Tick()
        if now and r.quests[id] and now-r.quests[id]<2 then C.diagnostics.duplicates=C.diagnostics.duplicates+1;return end
        r.quests[id]=now;Emit('quest_turnin',event,{questID=id,rewardXP=S.Integer(xp,0),rewardCopper=S.Integer(money,0)},nil,'confirmed')
        if now then for q,t in pairs(r.quests) do if now-t>=2 then r.quests[q]=nil end end end
    elseif event=='PLAYER_MONEY' then
        local nextMoney=S.Integer(Call('GetMoney'),0)
        if nextMoney and r.money and nextMoney~=r.money then Emit('money_change',event,{before=r.money,after=nextMoney,delta=nextMoney-r.money}) end
        r.money=nextMoney
    elseif event=='SKILL_LINES_CHANGED' then Skills(event)
    elseif event=='GROUP_ROSTER_UPDATE' or event=='PARTY_MEMBERS_CHANGED' then Roster(event)
    elseif event=='PLAYER_TARGET_CHANGED' then C.ObserveUnit('target',event,true)
    elseif event=='UPDATE_MOUSEOVER_UNIT' then C.ObserveUnit('mouseover',event,true)
    elseif event=='PLAYER_FOCUS_CHANGED' then C.ObserveUnit('focus',event,true)
    elseif event=='PLAYER_DEAD' then
        if not r.death then Emit('player_death',event,{},nil,'confirmed');r.death=true end
    elseif event=='PLAYER_ALIVE' or event=='PLAYER_UNGHOST' then r.death=false end
    if event=='PLAYER_FLAGS_CHANGED' then local unit=...;if unit=='player' then Timeslice(event) end end
end
local events={'PLAYER_ENTERING_WORLD','PLAYER_LEAVING_WORLD','PLAYER_LOGOUT','ZONE_CHANGED','ZONE_CHANGED_INDOORS',
    'ZONE_CHANGED_NEW_AREA','PLAYER_LEVEL_UP','PLAYER_XP_UPDATE','QUEST_TURNED_IN','SKILL_LINES_CHANGED',
    'PLAYER_MONEY','GROUP_ROSTER_UPDATE','PARTY_MEMBERS_CHANGED','PLAYER_TARGET_CHANGED','UPDATE_MOUSEOVER_UNIT',
    'PLAYER_FOCUS_CHANGED','PLAYER_DEAD','PLAYER_ALIVE','PLAYER_UNGHOST','PLAYER_FLAGS_CHANGED'}
C.registered={}
for _,event in ipairs(events) do C.registered[event]=pcall(frame.RegisterEvent,frame,event) end
frame:SetScript('OnEvent',function(_,event,...)
    local ok=pcall(C.Handle,event,...);if not ok then C.diagnostics.errors=C.diagnostics.errors+1 end
end)
if ns.OlympusConnection then ns.OlympusConnection.Subscribe(function() C.RefreshGate() end) end
