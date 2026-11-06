-- Bounded own-character encounter summaries. Health samples never enter the ledger.
local _,ns=...
local C,S,X=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture
local V={VERSION=1};ns.AthenaAdventureEvidence=V
local current,recovery,sequence=nil,nil,0
local function Allowed() return C.PersonalEnabled() and X.Ready() end
local function Own() return select(2,C.Owner()) end
local function Coverage(reason)
    if ns.ChronicleCoverage then ns.ChronicleCoverage.Note('Adventure summaries','partial',reason) end
end
function V.Valid(d)
    if d.summaryVersion~=1 or not S.Text(d.windowRef,256) or not S.Integer(d.revision,1)
        or not S.Integer(d.firstAt,1) or not S.Integer(d.lastAt,d.firstAt)
        or type(d.startObserved)~='boolean' or type(d.closed)~='boolean'
        or not ({ongoing=true,combat_ended=true,interrupted=true,death=true})[d.phase]
        or not ({readable=true,partial=true,unavailable=true})[d.healthReadability]
        or not S.Integer(d.deaths,0) or not S.Integer(d.selfCredits,0) or not S.Integer(d.petCredits,0)
        or type(d.creditLowerBound)~='boolean' or type(d.recoveryObserved)~='boolean' or type(d.lowHealthObserved)~='boolean' then return false end
    if d.minHealthPercent~=nil and not S.Integer(d.minHealthPercent,0,100) then return false end
    if d.healthReadability=='unavailable' and d.minHealthPercent~=nil then return false end
    if d.healthReadability~='unavailable' and d.minHealthPercent==nil then return false end
    if d.lowHealthObserved and (not d.minHealthPercent or d.minHealthPercent>20) then return false end
    if d.closed~=(d.phase=='combat_ended' or d.phase=='interrupted') then return false end
    if d.endAlive~=nil and type(d.endAlive)~='boolean' then return false end
    if d.recoveryObserved and (not d.minHealthPercent or d.minHealthPercent>20) then return false end
    if d.combatSeconds~=nil and not S.Number(d.combatSeconds,0) then return false end
    return true
end
function V.ValidRecord(e,owner)
    return e.source=='checkpoint' and e.subject==owner:match('/(Player%-.+)$') and V.Valid(e.details)
end
local function Alive()
    local dead=X.Bool(X.Call('UnitIsDead','player'));local ghost=X.Bool(X.Call('UnitIsGhost','player'))
    if dead==false and ghost==false then return true end
    if dead==true or ghost==true then return false end
end
local function Commit(w)
    if not w or not w.dirty or not Allowed() or w.owner~=C.Owner() then return not w or not w.dirty end
    local d={recordType='adventure_combat_summary',summaryVersion=1,windowRef=w.id,revision=w.revision+1,
        firstAt=w.firstAt,lastAt=w.lastAt or w.firstAt,startObserved=w.startObserved,
        closed=w.closed,phase=w.phase,healthReadability=w.readability,minHealthPercent=w.minimum,
        deaths=w.deaths,selfCredits=w.selfCredits,petCredits=w.petCredits,creditLowerBound=w.lowerBound,
        recoveryObserved=w.recovered,lowHealthObserved=w.critical==true,endAlive=w.endAlive,combatWindowID=w.combatWindowID,
        combatSeconds=w.seconds}
    local e=X.Record('native_event','checkpoint',d,w.guid,false,w.place)
    if not e then Coverage('A compact encounter summary awaits a successful history write');return false end
    w.revision=d.revision;w.dirty=false;w.checkpoint=C.Tick()
    X.Mark('Adventure summaries','Own combat summaries retained; health ticks are not stored. Native delivery needs client verification.')
    return true
end
local function Begin(startObserved,combatWindowID)
    if not Allowed() then return end
    if current then return current.owner==C.Owner() and not current.closed and current or nil end
    if recovery and recovery.dirty and not Commit(recovery) then return end
    local at=C.Stamp();if not at or not X.runID then return end
    sequence=sequence+1;recovery=nil
    current={id=X.runID..'/adventure/'..sequence,owner=C.Owner(),guid=Own(),place=C.Place(),firstAt=at,lastAt=at,tick=C.Tick(),
        startObserved=startObserved==true,combatWindowID=combatWindowID,revision=0,closed=false,phase='ongoing',
        readability='unavailable',deaths=0,selfCredits=0,petCredits=0,lowerBound=false,recovered=false,
        seen={},seenCount=0,dirty=true}
    return current
end
function V.Sample()
    local w=current or recovery;if not w or not Allowed() or w.owner~=C.Owner() then return end
    if w.disabledRecovery then return end
    if w==current and w.closed then return end
    local health=S.Number(X.Call('UnitHealth','player'),0);local maximum=S.Number(X.Call('UnitHealthMax','player'),1)
    if not health or not maximum or health>maximum then
        if not w.closed then
            if w.readability=='readable' then w.readability='partial';w.dirty=true end
            w.missed=true
        end
        return
    end
    local percent=math.floor(100*health/maximum);local alive=Alive();w.lastAt=math.max(w.firstAt,C.Stamp() or w.lastAt)
    if not w.closed and (not w.minimum or percent<w.minimum) then w.minimum=percent;w.dirty=true end
    if not w.closed and w.readability=='unavailable' then w.readability=w.missed and 'partial' or 'readable';w.dirty=true end
    if w.critical and alive==true and percent>=50 and not w.recovered then w.recovered=true;w.dirty=true;Commit(w) end
    -- Only a readable, living, low-health observation supports a close call.
    if not w.closed and percent>0 and percent<=20 and alive==true and not w.critical then
        w.critical=true;w.dirty=true;Commit(w)
    end
end
function V.Health(unit)
    if not current and not recovery then return end
    if not ns.Readable(unit) or unit~='player' or not Allowed() or S.GUID(X.Call('UnitGUID','player'))~=Own() then return end
    -- Native own-unit notifications only; no polling and no foreign health reads.
    V.Sample()
end
function V.Close(reason)
    local w=current;if not w then return end
    if w.owner~=C.Owner() then return end
    V.Sample();w.closed=true;w.phase=reason or 'interrupted';w.dirty=true
    w.lastAt=math.max(w.firstAt,C.Stamp() or w.lastAt)
    local now=C.Tick();w.seconds=now and w.tick and S.Number(now-w.tick,0)
    if reason=='combat_ended' then w.endAlive=Alive() end
    if Commit(w) then
        current=nil
        if w.critical and not w.recovered or w.deaths>0 and w.endAlive~=true then w.recoveryUntil=(now or 0)+300;recovery=w end
    end
end
function V.Kill(d)
    if not Allowed() then return end
    local pet=X.Entity(X.Call('UnitGUID','pet'))
    local own=d.credit=='self native credit' and d.attackerGUID==Own()
    local petCredit=d.credit=='current pet native credit' and pet and d.attackerGUID==pet
    if not (own or petCredit) or d.entityKind~='Creature' then return end
    local w=current or X.Bool(X.Call('UnitAffectingCombat','player'))==true and Begin(false)
    if not w or w.closed or w.owner~=C.Owner() then return end
    if w.seen[d.targetGUID] then return end
    if w.seenCount>=128 then w.lowerBound=true;w.dirty=true;return end
    w.seen[d.targetGUID]=true;w.seenCount=w.seenCount+1;w.lastAt=math.max(w.firstAt,C.Stamp() or w.lastAt)
    local k=own and 'selfCredits' or 'petCredits';w[k]=w[k]+1;w.dirty=true
end
function V.Handle(event)
    if not Allowed() then return end
    if current and current.owner~=C.Owner() then return end
    if event=='PLAYER_REGEN_DISABLED' then
        if current then V.Close('interrupted') end
        local w=Begin(true);if w and not w.closed then V.Sample() end
    elseif event=='PLAYER_REGEN_ENABLED' then V.Close('combat_ended')
    elseif event=='PLAYER_DEAD' then
        -- A death after a closed fight may be unrelated (fall, drowning, etc.).
        -- The ordinary player_death source remains; do not invent combat cause.
        local w=current or X.Bool(X.Call('UnitAffectingCombat','player'))==true and Begin(false)
        if not w and recovery then recovery.disabledRecovery=true;if Commit(recovery) then recovery=nil else recovery.recoveryUntil=0 end end
        if w and w.closed then return end
        if w and not w.dead then w.dead=true;w.deaths=w.deaths+1;w.lastAt=math.max(w.firstAt,C.Stamp() or w.lastAt);w.dirty=true;w.phase=w.closed and w.phase or 'death';Commit(w) end
    elseif event=='PLAYER_ALIVE' or event=='PLAYER_UNGHOST' then
        local w=current or recovery
        if w and not w.disabledRecovery and w.owner==C.Owner() and Alive()==true then
            if w.dead or w.endAlive~=true then
                w.dead=false;w.endAlive=true;w.lastAt=math.max(w.firstAt,C.Stamp() or w.lastAt);w.dirty=true
            end
            -- Resurrection/recovery is observed; its cause and healer are unknown.
            V.Sample();Commit(w)
        end
    elseif event=='PLAYER_LEAVING_WORLD' then V.Boundary()
    elseif event:find('ZONE_CHANGED',1,true)==1 then
        V.Boundary();if X.Bool(X.Call('UnitAffectingCombat','player'))==true then Begin(false);V.Sample() end
    end
end
function V.Start()
    if current and current.owner~=C.Owner() or recovery and recovery.dirty and recovery.owner~=C.Owner() then Coverage('Uncommitted summary belongs to a different observer; it was not reassigned');return end
    if current and current.closed then if Commit(current) then current=nil else return end end
    if X.Bool(X.Call('UnitAffectingCombat','player'))==true then Begin(false);V.Sample() end
end
function V.Flush() Commit(current);Commit(recovery) end
function V.Boundary()
    V.Close('interrupted')
    if recovery then recovery.disabledRecovery=true;if Commit(recovery) then recovery=nil else recovery.recoveryUntil=0 end end
end
function V.Stop() V.Boundary() end
function V.Clear() current=nil;recovery=nil end
function V.Pump()
    if not Allowed() then return end
    local now=C.Tick();if not now then return end
    if recovery and recovery.recoveryUntil and now>recovery.recoveryUntil then if Commit(recovery) then recovery=nil end end
    if current and current.closed then if Commit(current) then current=nil end
    elseif current and current.dirty and now-(current.checkpoint or current.tick or now)>=60 then Commit(current) end
end
-- RegisterUnitEvent avoids dispatching a crowded zone's health traffic to Warden.
local frame=ns.Modules and ns.Modules.Frame('chronicle','Frame') or CreateFrame('Frame')
for _,event in ipairs({'UNIT_HEALTH','UNIT_MAXHEALTH'}) do
    if frame.RegisterUnitEvent then pcall(frame.RegisterUnitEvent,frame,event,'player')
    else pcall(frame.RegisterEvent,frame,event) end
end
frame:SetScript('OnEvent',function(_,_,unit) local ok=pcall(V.Health,unit);if not ok then Coverage('Own health observation was unreadable; no replacement was inferred') end end)
