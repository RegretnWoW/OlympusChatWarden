-- Optional duel evidence. One ledger, bounded runtime, no raw combat log.
local _,ns=...
local C,S,X,L,I=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture,ns.ChronicleLoadout,ns.ChronicleEncounters
local D={};ns.ChronicleDuels=D
local active,finished,hooked=nil,nil,{}
local function Own() return S.GUID(X.Call('UnitGUID','player')) end
local function Units()
    local t={'target','focus','mouseover'}
    for _,spec in ipairs({{'party',4},{'raid',40},{'arena',5}}) do for n=1,spec[2] do t[#t+1]=spec[1]..n end end
    return t
end
local function Identity(unit)
    local guid=S.GUID(X.Call('UnitGUID',unit));if not guid or X.Bool(X.Call('UnitIsPlayer',unit))~=true then return end
    local name,realm=X.Call('UnitFullName',unit)
    name=S.Text(name,144);realm=S.Text(realm,144)
    if not name then name,realm=X.Call('UnitName',unit);name=S.Text(name,144);realm=S.Text(realm,144) end
    realm=realm or S.Text(X.Call('GetRealmName'),144)
    if name and S.GUID(X.Call('UnitGUID',unit))==guid then return {guid=guid,name=name,realm=realm,unit=unit} end
end
local function Match(text,p)
    if not S.Text(text,256) or not p then return false end
    local name,realm=text:match('^(.-)%-(.+)$')
    if name then return name==p.name and p.realm~=nil and realm:gsub('%s','')==p.realm:gsub('%s','') end
    return text==p.name -- Full character name, never just the first name.
end
function D.Resolve(name)
    local found
    for _,unit in ipairs(Units()) do
        local p=Identity(unit)
        if p and p.guid~=Own() and Match(name,p) then
            if found and found.guid~=p.guid then return end
            found=p
        end
    end
    return found
end
function D.Enabled() return S.db and S.db.duels==true and S.db.duelConsent==1 and X.Ready() end
local function Emit(s,record,source,data,guid)
    if not s or not D.Enabled() then return end
    data=data or {};data.recordType=record;data.duelID=s.id;data.opponentGUID=s.opponent and s.opponent.guid
    return X.Record('native_event',source or 'control',data,guid or s.opponent and s.opponent.guid,false)
end
local function Phase(s)
    if s.ended then return 'after' end
    if s.combat then return 'during' end
    return 'before'
end
local function Valid(s,phase)
    return D.Enabled() and (active==s or finished==s) and s.accepted and Phase(s)==phase
        and C.Tick()-(s.endedTick or s.acceptedTick or s.tick)<=15
end
local function Snapshot(s,guid,phase,source,gear,trait,appearance,reason)
    if not D.Enabled() then return end
    if not gear and not trait and not appearance then
        Emit(s,'duel_capture_missed',source,{targetGUID=guid,requestedPhase=phase,reason=reason or 'no readable configuration'},guid);return
    end
    local at=C.Stamp()
    local unit=guid==s.own.guid and 'player' or nil
    if not unit then for _,candidate in ipairs(Units()) do if S.GUID(X.Call('UnitGUID',candidate))==guid then unit=candidate;break end end end
    local identity={}
    if unit then
        local name,realm=X.Call('UnitFullName',unit);local _,class,classID=X.Call('UnitClass',unit);local _,race,raceID=X.Call('UnitRace',unit)
        identity={name=S.Text(name,144),realm=S.Text(realm,128),class=S.Text(class,64),classID=S.Integer(classID,1,1000),race=S.Text(race,64),raceID=S.Integer(raceID,1,1000),
            level=S.Integer(X.Call('UnitLevel',unit),1,1000),sex=S.Integer(X.Call('UnitSex',unit),1,3),guild=S.Text(X.Call('GetGuildInfo',unit),128)}
        if S.GUID(X.Call('UnitGUID',unit))~=guid then identity={} end
    end
    local data={targetGUID=guid,phase=Phase(s),requestedPhase=phase,observedAt=at,
        gearRef=gear,gearObservedAt=gear and at,traitRef=trait,traitObservedAt=trait and at,
        appearanceRef=appearance,appearanceObservedAt=appearance and at,partial=true}
    for key,value in pairs(identity) do data[key]=value end
    Emit(s,'duel_capture',source,data,guid)
end
function D.OwnTraits(guid)
    local config=S.Integer(X.Call('C_ClassTalents.GetActiveConfigID'),1)
    if not config then return end
    local function owned() return D.Enabled() and not X.Busy() and Own()==guid
        and S.Integer(X.Call('C_ClassTalents.GetActiveConfigID'),1)==config and X.Bool(X.Call('C_Traits.ConfigHasStagedChanges',config))==false end
    if not owned() then return end
    local choices,complete,read,total=I.TalentChoices(owned,config)
    local export=S.Text(X.Call('C_Traits.GenerateImportString',config),5000)
    local specIndex=S.Integer(X.Call('C_SpecializationInfo.GetSpecialization',false,false),1,100)
    local spec=specIndex and S.Integer(X.Call('C_SpecializationInfo.GetSpecializationInfo',specIndex,false,false),1,1000000)
    if not owned() or not (choices or export or spec) then return end
    local values={guid=guid,configID=config,committed=true,choices=choices,choicesComplete=complete,nodesRead=read,nodesTotal=total,exportString=export,specializationID=spec}
    while choices and not X.Validate({format=1,family='traits',values=values}) and #choices>0 do table.remove(choices);values.choicesComplete=false end
    if not X.Validate({format=1,family='traits',values=values}) then values={guid=guid,configID=config,committed=true,exportString=export,specializationID=spec} end
    if owned() then return X.Store('traits',values,'control') end
end
local function Capture(s,phase)
    if not s.accepted then return end
    local own=s.own.guid
    -- Actual execution date/phase wins. Never relabel delayed work as pre-fight.
    local function localCapture()
        if not Valid(s,phase) or X.Busy() then
            Snapshot(s,own,phase,'control',nil,nil,nil,'capture phase ended or combat prevented read');return
        end
        local gear=L.Gear('player',own,'control');local traits=D.OwnTraits(own);local appearance=L.Appearance('player',own,'control')
        Snapshot(s,own,phase,'control',gear,traits,appearance)
        L.Stats('control',own)
    end
    if not X.Busy() then localCapture() else X.Queue('duel-own:'..s.id..':'..phase,localCapture) end
    local p=s.opponent
    if not p then return end
    local token=s.id..':'..phase
    s.captures=s.captures or {}
    local function callback(gear,traits,appearance,reason)
        if s.captures[token] then return end
        s.captures[token]=true;Snapshot(s,p.guid,phase,'INSPECT_READY',gear,traits,appearance,reason)
    end
    if not I.Priority(p.guid,token,function() return not s.captures[token] and Valid(s,phase) end,callback) then
        callback(nil,nil,nil,'no current eligible capture opportunity')
    end
end
function D.ManualCapture(guid,gear,traits,appearance)
    local s=active or finished
    if not s or not s.opponent or guid~=s.opponent.guid then return end
    local phase=Phase(s);local token=s.id..':'..phase
    if phase=='during' or not Valid(s,phase) or s.captures and s.captures[token] then return end
    s.captures=s.captures or {};s.captures[token]=true
    Snapshot(s,guid,phase,'INSPECT_READY',gear,traits,appearance)
end
local function Flush(s)
    if not s or s.flushed then return end;s.flushed=true
    for guid,row in pairs(s.combatRows or {}) do
        for action,data in pairs(row) do
            Emit(s,'duel_combat_summary',action=='cast' and 'UNIT_SPELLCAST_SUCCEEDED' or 'UNIT_COMBAT',{
                targetGUID=guid,scope=action=='cast' and 'observed successful casts' or action=='WOUND' and 'damage received; attacker unknown' or 'healing received; caster unknown',
                amount=data.amount or 0,count=data.count,spellID=data.spellID,firstAt=data.firstAt,lastAt=data.lastAt,
                windowSeconds=s.acceptedTick and math.max(0,(s.endedTick or C.Tick())-s.acceptedTick),coverage='accepted duel window; not complete combat attribution'},guid)
        end
    end
    for guid,spells in pairs(s.spells or {}) do for id,data in pairs(spells) do
        Emit(s,'duel_combat_summary','UNIT_SPELLCAST_SUCCEEDED',{targetGUID=guid,scope='observed successful casts',amount=0,count=data.count,spellID=id,firstAt=data.firstAt,lastAt=data.lastAt},guid)
    end end
    if s.dropped and s.dropped>0 then Emit(s,'duel_combat_summary','UNIT_SPELLCAST_SUCCEEDED',{targetGUID=s.own.guid,scope='spell detail budget exceeded',amount=0,count=s.dropped,droppedSpells=s.dropped},s.own.guid) end
end
local function End(s,source,reason)
    if not s or s.ended then return end
    s.ended=true;s.endedTick=C.Tick();Emit(s,'duel_session_end',source,{accepted=s.accepted==true,reason=reason,resultKnown=false})
    Flush(s);active=nil;finished=s
    if s.accepted then Capture(s,'after') end
end
function D.Interrupt(reason)
    if active then End(active,'control',reason or 'recording interrupted') end
    active=nil;finished=nil
end
function D.Request(direction,opponent,name)
    if not D.Enabled() then return end
    local now=C.Tick();if not now then return end
    if active and active.direction==direction and now-active.tick<2 and (opponent and active.opponent and opponent.guid==active.opponent.guid or name and name==active.name) then return end
    D.Interrupt('another challenge or recording boundary')
    local own=Identity('player');local c=S.Character(C.Owner(),false);if not own or not c then return end
    local s={id=C.Owner()..'/duel/'..(c.sequence+1),own=own,opponent=opponent,name=name,direction=direction,tick=now,combatRows={},spells={}}
    local e=Emit(s,'duel_session_request',direction=='incoming' and 'DUEL_REQUESTED' or 'control',{direction=direction,name=name or opponent and opponent.name,accepted=false})
    if e then s.anchor=e.id;active=s end
end
-- Native localized format strings, including positional substitutions. No
-- English fallback and no first-name-only outcome matching.
local function Pattern(format)
    if not ns.CanRead(format) or #format>1024 then return end
    local out,order={},{};local n=1;local implicit=0
    while n<=#format do
        local rest=format:sub(n);local token,index=rest:match('^(%%(%d+)%$s)')
        if not token and rest:sub(1,2)=='%s' then token='%s';implicit=implicit+1;index=implicit end
        if token then
            index=tonumber(index);if index~=1 and index~=2 then return end
            out[#out+1]='(.+)';order[#order+1]=index;n=n+#token
        else
            local ch=format:sub(n,n);if ch=='%' then return end
            out[#out+1]=ch:gsub('([%^%$%(%)%.%[%]%*%+%-%?])','%%%1');n=n+1
        end
    end
    if #order~=2 or order[1]==order[2] then return end
    return '^'..table.concat(out)..'$',order
end
function D.Parse(message)
    if not S.Text(message,512) then return end
    local result
    for _,method in ipairs({'KNOCKOUT','RETREAT'}) do
        local pattern,order=Pattern(_G['DUEL_WINNER_'..method])
        local a,b;if pattern then a,b=message:match(pattern) end
        if a and b then
            if result then return end
            local names={};names[order[1]]=a;names[order[2]]=b;result={winner=names[1],loser=names[2],method=method:lower()}
        end
    end
    return result
end
local function Outcome(message)
    local s=active or finished;local r=D.Parse(message)
    if not s or not s.accepted or not s.opponent or not r or s.endedTick and C.Tick()-s.endedTick>8 then return end
    local win=Match(r.winner,s.own) and Match(r.loser,s.opponent)
    local loss=Match(r.winner,s.opponent) and Match(r.loser,s.own)
    if win==loss then return end
    if s.result then return end
    s.result=win and 'win' or 'loss'
    Emit(s,'duel_session_result','CHAT_MSG_SYSTEM',{result=s.result,resultMethod=r.method,resultKnown=true,accepted=true})
    if not s.ended then End(s,'CHAT_MSG_SYSTEM','participant-bound native result') end
end
function D.Pending() return active~=nil or finished~=nil end
function D.Pump()
    if not D.Enabled() then return end
    local now=C.Tick();if not now then return end
    if active and now-active.tick>(active.accepted and 1800 or 60) then End(active,'control','duel window expired; result unknown') end
    if finished and now-(finished.endedTick or now)>16 then finished=nil end
end
function D.Handle(event,a,b,c,d)
    if not D.Enabled() then return end
    if event=='DUEL_REQUESTED' then local name=S.Text(a,144);if name then D.Request('incoming',D.Resolve(name),name) end
    elseif event=='DUEL_COUNTDOWN' then
        local s=active;if not s or s.accepted then return end
        s.opponent=s.opponent or D.Resolve(s.name);s.accepted=true;s.acceptedTick=C.Tick()
        Emit(s,'duel_session_start',event,{accepted=true,reason='native countdown observed; exact fight start unavailable'})
        if s.opponent then
            I.RememberDuel(s.opponent.guid,s.opponent.unit)
            if S.GUID(X.Call('UnitGUID',s.opponent.unit))==s.opponent.guid then C.ObserveUnit(s.opponent.unit,event,X.Bool(X.Call('UnitIsVisible',s.opponent.unit))==true) end
            -- Derived policy uses the verified start. Enrichment uses the shared scheduler.
            X.Record('important_player',event,{relationship='verified duel opponent',name=s.opponent.name,inspection='duel capture scheduled'},s.opponent.guid,false)
        end
        Capture(s,'before')
    elseif event=='DUEL_FINISHED' then if active then End(active,event,active.accepted and 'native finish; result unknown until matched' or 'challenge ended; acceptance unobserved') end
    elseif event=='DUEL_INBOUNDS' or event=='DUEL_OUTOFBOUNDS' then if active then Emit(active,event:lower(),event,{resultKnown=false}) end
    elseif event=='CHAT_MSG_SYSTEM' then Outcome(a)
    elseif event=='PLAYER_REGEN_DISABLED' then if active and active.accepted then active.combat=true end
    elseif event=='UNIT_COMBAT' or event=='UNIT_SPELLCAST_SUCCEEDED' then
        local s=active;if not s or not s.accepted or not s.opponent or not ns.CanRead(a) then return end
        local guid=S.GUID(X.Call('UnitGUID',a));if guid~=s.own.guid and guid~=s.opponent.guid then return end
        local at=C.Stamp()
        if event=='UNIT_COMBAT' and ns.CanRead(b) and (b=='WOUND' or b=='HEAL') then
            local amount=S.Number(d,0,1000000000);if not amount then return end
            local row=s.combatRows[guid] or {};s.combatRows[guid]=row
            local data=row[b] or {amount=0,count=0,firstAt=at};row[b]=data
            data.amount=data.amount+amount;data.count=data.count+1;data.lastAt=at
        elseif event=='UNIT_SPELLCAST_SUCCEEDED' then
            local id=S.Integer(c,1,10000000);if not id then return end
            local row=s.spells[guid] or {};s.spells[guid]=row;local data=row[id]
            if not data then
                local count=0;for _ in pairs(row) do count=count+1 end
                if count>=32 then s.dropped=(s.dropped or 0)+1;return end
                data={count=0,firstAt=at};row[id]=data
            end
            data.count=data.count+1;data.lastAt=at
        end
    elseif event=='ZONE_CHANGED_NEW_AREA' or event=='PLAYER_LEAVING_WORLD' then D.Interrupt('world or zone boundary') end
end
function D.Start()
    active=nil;finished=nil
    if type(hooksecurefunc)~='function' then return end
    for _,name in ipairs({'StartDuel','CancelDuel'}) do
        if not hooked[name] and X.API(name) then
            if name=='StartDuel' then hooksecurefunc(name,function(unit)
                if D.Enabled() and ns.CanRead(unit) then local p=Identity(unit);if p and p.guid~=Own() then D.Request('outgoing',p,p.name) end end
            end)
            else hooksecurefunc(name,function() if D.Enabled() and active then End(active,'control',active.accepted and 'native cancel/forfeit intent; result unknown' or 'native challenge canceled/declined') end end) end
            hooked[name]=true
        end
    end
    X.Mark('Duels',D.Enabled() and 'Optional duel capture enabled; native delivery needs live validation' or 'Off: enable optional duel recording in Chronicle settings')
end
function D.Stop() active=nil;finished=nil end
function D.SetEnabled(value)
    if not S.db or S.blocked then return false end
    if value~=true then D.Interrupt('duel recording disabled') end
    S.db.duels=value==true or nil;S.db.duelConsent=value==true and 1 or nil;D.Start();return true
end
local function EmptyHistory() return {wins=0,losses=0,unknown=0,total=0,challenges=0,rows={}} end
function D.UpdateHistory(st,a)
    local guid=a.opponentGUID;if not S.GUID(guid) then return end
    local h=st.duelPlayers[guid];if not h then h=EmptyHistory();st.duelPlayers[guid]=h end
    local d=a.duel;local key=d.accepted and (d.result=='win' and 'wins' or d.result=='loss' and 'losses' or 'unknown') or 'challenges'
    if d.tally==key then return end
    if d.tally then h[d.tally]=h[d.tally]-1 end
    h[key]=h[key]+1;d.tally=key
    if d.accepted and not d.counted then
        d.counted=true;h.total=h.total+1;h.firstAt=math.min(h.firstAt or a.startAt,a.startAt);h.lastAt=math.max(h.lastAt or a.startAt,a.startAt)
        local n=#h.rows+1
        while n>1 and (h.rows[n-1].startAt<a.startAt or h.rows[n-1].startAt==a.startAt and h.rows[n-1].id<a.id) do h.rows[n]=h.rows[n-1];n=n-1 end
        h.rows[n]=a;if #h.rows>50 then h.rows[#h.rows]=nil end
    end
    h.rate=h.wins+h.losses>0 and h.wins/(h.wins+h.losses) or nil
end
function D.History(st,guid)
    return st and st.duelPlayers and st.duelPlayers[guid] or EmptyHistory()
end
function D.Observation(a,guid,phase)
    local found
    for _,e in ipairs(a and a.duel.captures[guid] or {}) do
        if e.details.phase==phase and e.details.requestedPhase==phase then found=e end
    end
    return found
end
function D.Compare(before,after,family,owner,objects)
    if not before or not after then return 'One observation is missing',{} end
    local key=family=='gear' and 'gearRef' or 'traitRef'
    local function find(hash) if objects then return objects[hash] end;return X.Find(owner,hash) end
    local b=before.details[key] and find(before.details[key]);local a=after.details[key] and find(after.details[key])
    if not b or not a or b.capture.values.guid~=a.capture.values.guid then return 'Comparable content unavailable',{} end
    local changed={};local partial=false
    if family=='gear' then
        for slot=1,19 do
            local x,y=b.capture.values.slots[slot],a.capture.values.slots[slot]
            local oldItem=b.capture.values.itemGUIDs and b.capture.values.itemGUIDs[slot]
            local newItem=a.capture.values.itemGUIDs and a.capture.values.itemGUIDs[slot]
            local full=function(v) return v[2]=='empty' or v[2]=='present' and v[4]~=false end
            if not full(x) or not full(y) then partial=true
            elseif ns.ChronicleBackup.Encode(x)~=ns.ChronicleBackup.Encode(y) or type(oldItem)=='string' and type(newItem)=='string' and oldItem~=newItem then changed[#changed+1]=slot end
            if type(oldItem)=='string' and type(newItem)~='string' or type(newItem)=='string' and type(oldItem)~='string' then partial=true end
        end
    else
        local x,y=b.capture.values,a.capture.values
        partial=x.choicesComplete~=true or y.choicesComplete~=true
        if ns.ChronicleBackup.Encode(x)~=ns.ChronicleBackup.Encode(y) then changed[1]='talents' end
    end
    if #changed>0 then return partial and 'Observed differences • incomplete snapshot' or 'Different configurations observed',changed end
    return partial and 'Comparable fields match • incomplete snapshot' or 'Matching configurations at both observations',changed
end
X.Register(D,{'DUEL_COUNTDOWN','CHAT_MSG_SYSTEM','UNIT_COMBAT','UNIT_SPELLCAST_SUCCEEDED','PLAYER_REGEN_DISABLED','ZONE_CHANGED_NEW_AREA','PLAYER_LEAVING_WORLD'})
