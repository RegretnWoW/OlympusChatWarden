-- Optional witnessed open-world evidence. Native callbacks only; no unit sweep,
-- hidden-value extraction, raw combat log, aura census or dossier transmission.
local _,ns=...
local C,S,X,P=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture,ns.IntelPolicy
local W={LIMIT=600,PLATES=256,diagnostics={sightings=0,coalesced=0,unreadable=0,states=0,deaths=0,abilities=0,evictions=0,plateLimit=0}};ns.IntelWitness=W
local cache,count,plates,plateCount,owner,generation,started,units={},0,{},0,nil,0,false,{}
local identityKeys={'name','realm','class','race','level','guild','faction'}
-- Spell IDs, never localized spell-name matching. Successful casts prove only a cast.
W.spells={
    [642]='defensive',[1020]='defensive',[498]='defensive',[5573]='defensive',
    [45438]='defensive',[11958]='cooldown',[871]='defensive',[12975]='defensive',
    [5277]='defensive',[26669]='defensive',[1856]='defensive',[1857]='defensive',
    [19263]='defensive',[23989]='cooldown',[16190]='support',[29166]='support',
    [118]='control',[853]='control',[408]='control',[2094]='control',[8122]='control',[6789]='control',[19503]='control',
    [15487]='control',[2139]='control',[6552]='control',[1766]='control',[12042]='offensive',[1719]='offensive',[13750]='offensive',[19574]='offensive',
    [20484]='resurrection',[20739]='resurrection',[20742]='resurrection',[20747]='resurrection',[20748]='resurrection',
    [2006]='resurrection',[2010]='resurrection',[10880]='resurrection',[10881]='resurrection',[20770]='resurrection',
    [7328]='resurrection',[10322]='resurrection',[10324]='resurrection',[20772]='resurrection',[20773]='resurrection',
    [2008]='resurrection',[20609]='resurrection',[20610]='resurrection',[20776]='resurrection',[20777]='resurrection',
}
function W.Selected() return ns.DB and ns.DB.intelWitnessConsent==1 end
function W.Enabled() return started and W.Selected() and C.IntelEnabled() and C.InWorld() and owner==C.Owner() end
function W.SetEnabled(value)
    if type(value)~='boolean' or not ns.DB or not ns.Membership.Allowed() then return false end
    if ns.AthenaCastCounts then ns.AthenaCastCounts.Flush(nil,true) end
    if ns.AthenaCombatEvidence then ns.AthenaCombatEvidence.WitnessBoundary() end
    if ns.AthenaObservations then ns.AthenaObservations.Stop();ns.AthenaObservations.Start() end
    ns.DB.intelWitnessConsent=value and 1 or nil
    W.Stop();if value and C.IntelEnabled() and C.InWorld() then W.Start() end
    return true
end
local function Entry(guid)
    local v=cache[guid];if v then return v end
    if count>=W.LIMIT then
        local oldest,at;for id,row in pairs(cache) do if not at or row.checked<at then oldest,at=id,row.checked end end
        cache[oldest]=nil;count=count-1;W.diagnostics.evictions=W.diagnostics.evictions+1
    end
    v={checked=C.Tick() or 0};cache[guid]=v;count=count+1;return v
end
local function Read(unit,expected)
    if not S.Text(unit,32) or X.Bool(X.Call('UnitIsPlayer',unit))~=true then return end
    local guid=S.GUID(X.Call('UnitGUID',unit));if not guid or guid==select(2,C.Owner()) or expected and guid~=expected then return end
    local name,realm=X.Call('UnitFullName',unit);name=S.Text(name,144)
    local _,class=X.Call('UnitClass',unit);local _,race=X.Call('UnitRace',unit)
    local data={name=name,realm=S.Text(realm,128),class=S.Text(class,64),race=S.Text(race,64),
        level=S.Integer(X.Call('UnitLevel',unit),1,1000),guild=S.Text(X.Call('GetGuildInfo',unit),128),
        faction=S.Text(X.Call('UnitFactionGroup',unit),64),via=unit,localSighting=X.Bool(X.Call('UnitIsVisible',unit))==true,encounter=false}
    local dead=X.Bool(X.Call('UnitIsDeadOrGhost',unit));local ghost=X.Bool(X.Call('UnitIsGhost',unit))
    if dead==nil then
        local corpse=X.Bool(X.Call('UnitIsDead',unit))
        if corpse==true or ghost==true then dead=true elseif corpse==false and ghost==false then dead=false end
    end -- A corpse release must never look like a dead-to-alive recovery.
    local state={dead=dead,ghost=ghost,pvp=X.Bool(X.Call('UnitIsPVP',unit)),
        hostile=X.Bool(X.Call('UnitIsEnemy','player',unit)),inCombat=X.Bool(X.Call('UnitAffectingCombat',unit))}
    if S.GUID(X.Call('UnitGUID',unit))~=guid then return end
    return guid,data,state
end
local function Record(kind,source,data,guid)
    return X.Record('native_event',source,data,guid,false,C.Place())
end
local function State(unit,guid,state,v,source,context)
    local previous=v.state;local now=C.Stamp()
    local mode=ns.AthenaCollectionPolicy.Decide(18,guid,{witness=true,unit=unit})
    local detailed=mode=='Deep';local meaningful=detailed or mode=='Light'
    if meaningful and previous and previous.dead~=nil and state.dead~=nil and previous.dead~=state.dead then
        local death=state.dead==true
        local e=Record(death and 'death' or 'recovery',source,{recordType=death and 'witness_death' or 'witness_recovery',
            method='state transition',before=previous.dead,after=state.dead,classification='unknown',via=unit},guid)
        if e then
            v.death=death and e.id or nil;v.nativeLinked=nil
            if death then W.diagnostics.deaths=W.diagnostics.deaths+1 end
        end
    end
    local known=v.baselineContext==context and v.knownState or {}
    local changed={recordType='witness_state',baseline=false,via=unit};local any=false
    for key,value in pairs(state) do
        local first=not known[key]
        if detailed and (first or previous and previous[key]~=nil and previous[key]~=value) then
            changed[key]=value;any=true;if first then changed.baseline=true end
        end
    end
    if any and Record('state',source,changed,guid) then
        for key in pairs(state) do known[key]=true end
        W.diagnostics.states=W.diagnostics.states+1;v.baselineContext=context;v.knownState=known
    end
    -- Latest runtime state is valid only for this accessible identity/lifetime.
    v.state=state;v.checked=C.Tick() or v.checked;v.stateAt=now;v.unit=unit
end
function W.Observe(unit,source)
    if not W.Enabled() then return end
    local guid,data,state=Read(unit)
    local old=units[unit]
    if old and old~=guid then local prior=cache[old];if prior and prior.unit==unit then prior.state=nil;prior.death=nil;prior.nativeLinked=nil end end
    units[unit]=guid
    if not guid then W.diagnostics.unreadable=W.diagnostics.unreadable+1;return end
    local v=Entry(guid);local place=data.localSighting and C.Place() or {}
    local context=ns.ChronicleBackup.Encode({zone=place.zone,instanceID=place.instanceID,instanceType=place.instanceType})
    local changed=false
    for _,key in ipairs(identityKeys) do if data[key]~=nil and (not v.identity or v.identity[key]~=data[key]) then changed=true;break end end
    local character=S.WriterCharacter(owner,false);local session=character and character.currentSession
    if data.name and (changed or v.context~=context or v.session~=session) then
        data.encounter=v.context~=context or v.session~=session
        local e=C.Record('player_observed',source,data,guid,'observed',place)
        if e then
            S.Observe(owner,guid,data,e.at,source,data.localSighting and place or nil)
            v.identity=v.identity or {};for _,key in ipairs(identityKeys) do if data[key]~=nil then v.identity[key]=data[key] end end
            v.context=context;v.session=session;W.diagnostics.sightings=W.diagnostics.sightings+1
        end
    else W.diagnostics.coalesced=W.diagnostics.coalesced+1 end
    State(unit,guid,state,v,source,context)
    if ns.AthenaEnrichment then ns.AthenaEnrichment.Opportunity(unit,source,guid) end
    return guid
end
function W.Added(unit,source)
    if not W.Enabled() or not S.Text(unit,32) or not unit:match('^nameplate%d+$') then return end
    if not plates[unit] and plateCount>=W.PLATES then W.diagnostics.plateLimit=W.diagnostics.plateLimit+1;return end
    if plates[unit] then W.Removed(unit) end
    generation=generation+1
    if not plates[unit] then plateCount=plateCount+1 end
    plates[unit]={generation=generation}
    local guid=W.Observe(unit,source or 'NAME_PLATE_UNIT_ADDED');if guid then plates[unit].guid=guid end
end
function W.Removed(unit)
    if not S.Text(unit,32) then return end
    local plate=plates[unit];if not plate then return end
    local v=plate.guid and cache[plate.guid]
    if v then v.state=nil;v.death=nil;v.nativeLinked=nil end
    units[unit]=nil;plates[unit]=nil;plateCount=plateCount-1
end
function W.Death(guid)
    if not W.Enabled() then return end
    guid=S.GUID(guid);if not guid or guid==select(2,C.Owner()) then return end
    local known=cache[guid]
    if not known or not ns.AthenaCollectionPolicy.Light(18,guid,{witness=true,unit=known.unit}) then return end
    -- UNIT_DIED itself supplies a GUID, even with no name/unit available.
    local v=cache[guid];local ref
    if v and v.state and v.state.dead==true and v.death and not v.nativeLinked
        and S.GUID(X.Call('UnitGUID',v.unit))==guid and X.Bool(X.Call('UnitIsVisible',v.unit))==true
        and X.Bool(X.Call('UnitIsDead',v.unit))==true and S.GUID(X.Call('UnitGUID',v.unit))==guid then ref=v.death end
    local e=Record('death','UNIT_DIED',{recordType='witness_death',method='native death',classification='unknown',encounterRef=ref},guid)
    if e then
        if ref then v.nativeLinked=true end
        W.diagnostics.deaths=W.diagnostics.deaths+1
    end
end
function W.Cast(unit,cast,spell)
    if not W.Enabled() or not S.Text(unit,32) then return end
    local guid=S.GUID(X.Call('UnitGUID',unit));if not guid then return end
    if not ns.AthenaCollectionPolicy.Deep(16,guid,{witness=true,priorityOnly=true}) then return end
    spell=S.Integer(spell,1,1000000000);local category=spell and W.spells[spell]
    cast=S.Text(cast,128);if not category or not cast then return end
    local actual=Read(unit,guid);if actual~=guid then return end
    local v=Entry(guid);v.casts=v.casts or {};v.castOrder=v.castOrder or {}
    if v.casts[cast] then return end
    if Record('ability','UNIT_SPELLCAST_SUCCEEDED',{recordType='witness_ability',castGUID=cast,spellID=spell,
        classification=category,method='successful cast',via=unit},guid) then
        v.casts[cast]=true;v.castOrder[#v.castOrder+1]=cast
        if #v.castOrder>32 then v.casts[table.remove(v.castOrder,1)]=nil end
        W.diagnostics.abilities=W.diagnostics.abilities+1
    end
end
function W.Start()
    W.Stop()
    if W.Selected() and C.IntelEnabled() and C.InWorld() then
        owner=C.Owner();started=true
        -- C.Start emits its first roster before capture workers start. Reuse a
        -- small accepted tail immediately; full validated context seeds cooperatively.
        local c=S.WriterCharacter(owner,false);local events=c and c.events or {}
        for n=#events,math.max(1,#events-63),-1 do P.Notice(events[n],true) end
    end
end
function W.Stop() cache={};count=0;plates={};plateCount=0;units={};owner=nil;started=false end
function W.Pump() if W.Enabled() then P.Pump() end end
function W.Counts() return count,plateCount end
function W.UnitFor(guid)
    local v=W.Enabled() and cache[guid]
    local unit=v and v.unit
    if unit and units[unit]==guid and (not unit:match('^nameplate') or plates[unit]) and S.GUID(X.Call('UnitGUID',unit))==guid then return unit end
end
function W.Handle(event,a,b,c)
    if not W.Enabled() then return end
    if event=='GROUP_ROSTER_UPDATE' then
        for n=1,40 do local unit=(ns.Checked(X.Call('IsInRaid')) and 'raid' or 'party')..n
            if n<=4 or unit:match('^raid') then W.Observe(unit,'GROUP_ROSTER_UPDATE') end
        end
    elseif event=='UNIT_TARGET' then
        local token=S.Text(a,32);if token then W.Observe(token..'target',event) end
    elseif event=='NAME_PLATE_UNIT_ADDED' then W.Added(a)
    elseif event=='NAME_PLATE_UNIT_REMOVED' then W.Removed(a)
    elseif event=='UNIT_DIED' then W.Death(a)
    elseif event=='UNIT_SPELLCAST_SUCCEEDED' then W.Cast(a,b,c)
    else
        local unit=event=='PLAYER_TARGET_CHANGED' and 'target' or event=='UPDATE_MOUSEOVER_UNIT' and 'mouseover' or event=='PLAYER_FOCUS_CHANGED' and 'focus' or S.Text(a,32)
        if unit then
            local plate=plates[unit]
            if unit:match('^nameplate%d+$') and not plate then
                -- After an opt-in/resume, a currently accessible native unit
                -- update can introduce the token without a synthetic Added event.
                W.Added(unit,event)
            elseif not unit:match('^nameplate') or plate then
                local guid=W.Observe(unit,event)
                if plate and guid then plate.guid=guid end
            end
        end
    end
end
X.Register(W,{'NAME_PLATE_UNIT_ADDED','NAME_PLATE_UNIT_REMOVED','UNIT_DIED','UNIT_FLAGS','UNIT_FACTION','UNIT_NAME_UPDATE','UNIT_LEVEL',
    'PLAYER_TARGET_CHANGED','UPDATE_MOUSEOVER_UNIT','PLAYER_FOCUS_CHANGED','UNIT_SPELLCAST_SUCCEEDED','UNIT_TARGET','GROUP_ROSTER_UPDATE'},'intel')
