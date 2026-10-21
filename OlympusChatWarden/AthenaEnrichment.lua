-- Watch priority is an acquisition intent, never evidence. Runtime only; native
-- observations still enter the existing ledger, journal and immutable snapshots.
local _,ns=...
local C,S,X=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture
local E={LIMIT=128,revision=0,diagnostics={opportunities=0,assessments=0,capacity=0,errors=0}};ns.AthenaEnrichment=E
local rows,order,jobs,queued,bindings,owner,seed,earlySeed={}, {},{}, {},{},nil,true,true
-- Freshness is a request hint, not expiration. Passive histories have no
-- "complete" state: a watch cannot fetch an event that was never delivered.
E.categories={
    {id='identity',label='Identity',owner='Chronicle',source='GUID-verified unit',mode='read',freshness=300,retry='unit opportunity'},
    {id='social',label='Guild & relationships',owner='ChronicleEncounters',source='unit guild / native roster / GUID friend',mode='read',freshness=300,retry='unit or roster change'},
    {id='appearance',label='Appearance',owner='ChronicleLoadout',source='unit race, class and sex',mode='read',freshness=3600,retry='unit opportunity; exact remote model unavailable'},
    {id='gear',label='Gear',owner='ChronicleEncounters',source='owned INSPECT_READY',mode='inspect',freshness=300,retry='verified inspectable opportunity; 300-second backoff'},
    {id='talents',label='Talents',owner='ChronicleEncounters',source='owned native inspect trait cache',mode='inspect',freshness=300,retry='shared inspect queue; no local-player substitute'},
    {id='state',label='Visible state & abilities',owner='IntelWitness',source='native unit flags / delivered successful casts',mode='witness',retry='native event; separate witness opt-in'},
    {id='group',label='Group & dungeon history',owner='Chronicle / ChronicleActivities',source='native rosters / local instance and boss events',mode='passive',retry='delivered attributable event; roster is not boss participation'},
    {id='combat',label='Combat & duels',owner='ChronicleCombat / ChronicleDuels',source='native credit / combat / duel evidence',mode='passive',retry='delivered attributable event; duel consent remains separate'},
    {id='pvp',label='PvP history',owner='ChronicleCombat',source='GUID-bearing native scoreboards / objectives',mode='passive',retry='delivered scoreboard; no remote honor-cache attribution'},
    {id='public',label='Public & guild events',owner='AthenaCollectors / ChronicleOlympus',source='delivered GUID-bearing announcements / read-only public records',mode='passive',retry='delivered event; no remote activity request'},
    {id='context',label='Shared Warden context',owner='Athena',source='existing validated Chronicle / Intel references and authorized outcomes',mode='derived',retry='existing source changes; no raw private module data'},
    {id='remote',label='Hidden or offline activity',owner='none',source='no supported ordinary client source',mode='unobservable',retry='never; no remote quests, bank, reputation or complete history'},
}
local capabilities={identity='readable UnitGUID / UnitIsPlayer / UnitFullName / UnitClass / UnitRace / UnitLevel',
    social='readable GetGuildInfo; GUID-bearing friend results and delivered rosters',appearance='readable UnitRace / UnitClass / UnitSex; exact offline reconstruction unsupported',
    gear='CanInspect / NotifyInspect / stable owned INSPECT_READY and inventory getters',talents='owned inspect specialization / valid C_Traits inspect cache',
    state='IntelWitness consent and readable delivered unit events',group='legitimate native group and local instance callbacks',
    combat='native credit / duel callbacks and separately consented duel recording',pvp='native GUID-bearing scoreboard rows',
    public='delivered GUID-bearing public announcements / read-only Olympus records',context='loaded validated internal evidence references',remote='unsupported'}
for _,spec in ipairs(E.categories) do spec.capability=capabilities[spec.id] end
local function Profile(guid)
    local c=S.Character(C.Owner(),false)
    return c and c.profiles[guid],c
end
function E.Watched(guid)
    if not S.GUID(guid) or guid==select(2,C.Owner()) then return false end
    local p=Profile(guid);return p and p.personal and p.personal.watch==true or false
end
-- Manual watches are private observer intent. Earned priority is independently
-- source-backed. Both use one acquisition path; Lab still calls Watched only.
function E.Priority(guid)
    if not S.GUID(guid) or guid==select(2,C.Owner()) then return false end
    if not ns.AthenaCollectionPolicy.Deep(22,guid,{priorityOnly=true}) then return false end
    if E.Watched(guid) then return true,'personal bookmark',true end
    if ns.AthenaSocial and ns.AthenaSocial.Friend(guid) then return true,'encountered friend',false end
    if ns.IntelPolicy.EarnedTier(guid)==1 then return true,'earned relationship',false end
    return false
end
function E.Origins(guid)
    local state=ns.IntelPolicy.Explain(guid)
    return {manualWatch=E.Watched(guid),verifiedFriend=ns.AthenaSocial and ns.AthenaSocial.Friend(guid) or false,
        friendState=ns.AthenaSocial and ns.AthenaSocial.State(guid) or 'source unavailable',
        friendEvidence=ns.AthenaSocial and ns.AthenaSocial.Proof(guid),earned=ns.IntelPolicy.EarnedTier(guid)==1,
        earnedSourceID=state.promotionID,earnedObserver=state.promotionOwner,deliberateCause=state.manualCause,
        deliberateSourceID=state.manualID,meaning='Independent causes; historical records are not current watch/friend authorization'}
end
local function Enabled() return C.IntelEnabled() and X.Ready() and owner==C.Owner() end
local function Trace(source,guid,code,category,stage)
    if ns.AthenaLab and ns.AthenaLab.Report then ns.AthenaLab.Report(source or 'control',guid,code,category or 'watched player',stage or 'enrichment') end
end
local function Touch(guid)
    local r=rows[guid];if r then return r end
    if #order>=E.LIMIT then
        -- Disposable status only. A watch flag and its missing categories remain
        -- reconstructible; never evict an issued inspect or queued evaluation.
        local remove
        for n,id in ipairs(order) do if not queued[id] and not (ns.ChronicleEncounters.InspectionState(id)=='pending') then remove=n;break end end
        if not remove then E.diagnostics.capacity=E.diagnostics.capacity+1;return end
        local id=table.remove(order,remove);local prior=rows[id]
        if prior and prior.unit and bindings[prior.unit]==id then bindings[prior.unit]=nil end
        rows[id]=nil
    end
    r={guid=guid};rows[guid]=r;order[#order+1]=guid;return r
end
local function Schedule(guid)
    if queued[guid] then return end
    if #jobs>=E.LIMIT then E.diagnostics.capacity=E.diagnostics.capacity+1;return end
    queued[guid]=true;jobs[#jobs+1]=guid
end
function E.Resolve(guid)
    local r=rows[guid]
    if r and r.unit and S.GUID(X.Call('UnitGUID',r.unit))==guid then return r.unit end
    for _,unit in ipairs({'target','focus','mouseover'}) do if S.GUID(X.Call('UnitGUID',unit))==guid then return unit end end
    local unit=ns.IntelWitness and ns.IntelWitness.UnitFor(guid);if unit then return unit end
    -- One fixed native roster, only on an explicit watch or queued assessment.
    local raid=X.Bool(X.Call('IsInRaid'))==true
    for n=1,raid and 40 or 4 do local token=(raid and 'raid' or 'party')..n;if S.GUID(X.Call('UnitGUID',token))==guid then return token end end
end
local function Cheap(guid,unit,source,r)
    if S.GUID(X.Call('UnitGUID',unit))~=guid or X.Bool(X.Call('UnitIsPlayer',unit))~=true then return end
    local duplicates=C.diagnostics.duplicates
    local actual,data=C.ObserveUnit(unit,source,X.Bool(X.Call('UnitIsVisible',unit))==true)
    if actual~=guid then Trace(source,guid,'READ_UNAVAILABLE','identity');return end
    if S.GUID(X.Call('UnitGUID',unit))~=guid then Trace(source,guid,'GUID_MISMATCH','identity');return end
    if C.diagnostics.duplicates>duplicates then Trace(source,guid,'UNCHANGED_COALESCED','identity','coalescing') end
    local at=C.Stamp();r.identityAt=at;r.identitySource=source
    if X.Busy() then Trace(source,guid,'COMBAT_DEFERRED');return end -- retain cheap identity now; defer detail work
    local appearanceSignature=table.concat({data.race or '?',tostring(data.raceID or '?'),data.class or '?',tostring(data.sex or '?')},'/')
    local hash=r.appearanceHash
    if appearanceSignature~=r.appearanceSignature or not r.appearanceAt or at-r.appearanceAt>=3600 then
        hash=ns.ChronicleLoadout.Appearance(unit,guid,source)
        if hash then r.appearanceSignature=appearanceSignature;r.appearanceAt=at end
    end
    local guild,rank=X.Call('GetGuildInfo',unit);guild=S.Text(guild,128);rank=S.Text(rank,128)
    local friend=data.name and X.Table(X.Call('C_FriendList.GetFriendInfo',data.name))
    local verifiedFriend=friend and S.GUID(friend.guid)==guid
    local eligible,reason=E.Priority(guid)
    if not Enabled() or not eligible or S.GUID(X.Call('UnitGUID',unit))~=guid then return end
    local signature=(guild or '?')..'/'..(rank or '?')
    if (hash and hash~=r.appearanceHash) or (guild and signature~=r.socialSignature) or verifiedFriend and not r.friend then
        local e=X.Record('important_player',source,{relationship=verifiedFriend and 'encountered friend' or reason,guildName=guild,guildRank=rank,
            appearanceRef=hash,appearanceObservedAt=hash and at,unitVisible=X.Bool(X.Call('UnitIsVisible',unit))},guid,false)
        if e then r.appearanceHash=hash or r.appearanceHash;r.socialSignature=signature;r.socialAt=(guild or verifiedFriend) and at or r.socialAt;r.socialSource=(guild or verifiedFriend) and source or r.socialSource;r.friend=verifiedFriend or r.friend end
    end
    return true
end
function E.Opportunity(unit,source,verifiedGUID)
    if not Enabled() then Trace(source,nil,'PERMISSION_OFF');return end
    if not S.Text(unit,32) then Trace(source,nil,'NO_UNIT');return end
    local guid=verifiedGUID or S.GUID(X.Call('UnitGUID',unit))
    if not guid then Trace(source,nil,'GUID_UNREADABLE');return end
    local prior=bindings[unit];if prior and prior~=guid then E.Removed(unit) end
    if not E.Priority(guid) then local _,c=Profile(guid);Trace(source,guid,c and 'NOT_WATCHED' or 'HISTORY_UNRESOLVED');return end
    if ns.AthenaCombatEvidence then ns.AthenaCombatEvidence.Schedule(unit,'control') end
    if ns.AthenaObservations then ns.AthenaObservations.Opportunity(unit,'control') end
    local r=Touch(guid);if not r then Trace(source,guid,'QUEUE_CAPACITY');return end
    if r.unit and bindings[r.unit]==guid then bindings[r.unit]=nil end
    E.diagnostics.opportunities=E.diagnostics.opportunities+1;r.unit=unit;bindings[unit]=guid;r.source=source or 'control'
    -- UNIT_FLAGS is a state notification, not an identity/guild update. Witness
    -- owns those state transitions. Reusing an unchanged binding avoids a second
    -- identity/appearance read on every flag notification without sampling facts.
    local flags=source=='UNIT_FLAGS' and prior==guid and r.identityAt and not r.cheapPending
    if not flags then r.cheapPending=not Cheap(guid,unit,r.source,r) end
    if source=='UNIT_INVENTORY_CHANGED' then r.partialUntil=nil;r.partialRepeats=0 end
    local tick=C.Tick()
    if not flags or not r.assessedTick or not tick or tick-r.assessedTick>=1 then Schedule(guid) end
    return guid
end
function E.Removed(unit)
    if not S.Text(unit,32) then return end
    local id=bindings[unit];local r=id and rows[id]
    if r and r.unit==unit then r.unit=nil end
    bindings[unit]=nil
end
function E.WatchChanged(guid,watch)
    if not watch then
        ns.ChronicleEncounters.CancelWatch(guid)
        if E.Priority(guid) then E.PriorityChanged(guid);return end
        if ns.AthenaCombatEvidence then ns.AthenaCombatEvidence.Revoke(guid) end
        if ns.AthenaObservations then ns.AthenaObservations.Revoke(guid) end
        local r=rows[guid];if r and r.unit and bindings[r.unit]==guid then bindings[r.unit]=nil end
        rows[guid]=nil;queued[guid]=nil
        for n=#order,1,-1 do if order[n]==guid then table.remove(order,n) end end
        for n=#jobs,1,-1 do if jobs[n]==guid then table.remove(jobs,n) end end
        E.revision=E.revision+1;return
    end
    if not Enabled() then return end
    local r=Touch(guid);if not r then return end
    local unit=E.Resolve(guid)
    if unit then
        if ns.IntelWitness and ns.IntelWitness.Enabled() then ns.IntelWitness.Observe(unit,'control')
        else E.Opportunity(unit,'control') end
    else r.reason='Waiting for a GUID-matching player unit';Schedule(guid) end
    E.revision=E.revision+1
end
-- Promotion may run inside the accepted writer callback. Defer reads/writes to
-- the normal pump, so promotion cannot re-enter the writer or backdate a fact.
function E.PriorityChanged(guid)
    if not Enabled() or not E.Priority(guid) then return end
    local r=Touch(guid);if not r then return end
    r.cheapPending=true;r.source='control';Schedule(guid);E.revision=E.revision+1
end
local BuildCoverage
function E.Inspection(guid,state,reason,gear,traits)
    if not E.Priority(guid) then return end
    local r=Touch(guid);if not r then return end
    r.inspectState=state;r.failure=reason;r.gear=gear or r.gear;r.traits=traits or r.traits
    if gear or traits then r.inspectedAt=C.Stamp() end
    if state=='saved' or state=='partial' then
        local signature=(gear or '?')..'/'..(traits or '?')
        local complete=gear and BuildCoverage(X.Find(C.Owner(),gear)) and traits and BuildCoverage(X.Find(C.Owner(),traits))
        if not complete then
            r.partialRepeats=signature==r.partialSignature and (r.partialRepeats or 0)+1 or 1
            r.partialSignature=signature
            -- A low-level player's unreadable optional slots may remain unknown
            -- indefinitely. Three identical partial responses exhaust this burst;
            -- wait an hour or a real inventory change, never invent empty slots.
            if r.partialRepeats>=3 then r.partialUntil=C.Stamp()+3600 end
        else r.partialRepeats=0;r.partialUntil=nil;r.partialSignature=nil end
    end
    if gear then Trace('INSPECT_READY',guid,BuildCoverage(X.Find(C.Owner(),gear)) and 'SNAPSHOT_SAVED' or 'PARTIAL','gear','inspection result') end
    if traits then Trace('INSPECT_READY',guid,BuildCoverage(X.Find(C.Owner(),traits)) and 'SNAPSHOT_SAVED' or 'PARTIAL','talents','inspection result') end
    if state=='saved' or state=='partial' then
        if not gear then Trace('INSPECT_READY',guid,'READ_UNAVAILABLE','gear','inspection result') end
        if not traits then Trace('INSPECT_READY',guid,'READ_UNAVAILABLE','talents','inspection result') end
    end
    E.revision=E.revision+1
end
BuildCoverage=function(object)
    if not object or not object.capture then return false,0,0 end
    local v=object.capture.values
    if object.capture.family=='gear' then
        local known=0;for _,slot in ipairs(v.slots or {}) do if slot[2]=='present' or slot[2]=='empty' then known=known+1 end end
        return known==19,known,19
    end
    return v.choicesComplete==true and v.choices~=nil,v.nodesRead,v.nodesTotal
end
local function Fresh(f,horizon)
    local now=C.Stamp();return f and now and now>=f.at and now-f.at<horizon
end
local function Indexed(guid)
    local st,status=ns.ChronicleActivities.Request(C.Owner())
    return st and st.intelligence and st.intelligence.players[guid],st~=nil,status
end
function E.Reconcile(unit,source)
    local guid=S.GUID(X.Call('UnitGUID',unit));local r=guid and rows[guid]
    -- History readiness is not itself a new native player occurrence.
    if r and r.identityAt then Schedule(guid) else E.Opportunity(unit,source) end
end
function E.Pump()
    if not Enabled() or X.Busy() then return end
    if earlySeed or seed and S.Character(C.Owner(),false) then
        earlySeed=nil
        if S.Character(C.Owner(),false) then seed=nil end
        for _,unit in ipairs({'target','focus','mouseover'}) do E.Reconcile(unit,'control') end
        local raid=X.Bool(X.Call('IsInRaid'))==true
        for n=1,raid and 40 or 4 do E.Reconcile((raid and 'raid' or 'party')..n,'GROUP_ROSTER_UPDATE') end
    end
    local guid=table.remove(jobs,1);if not guid then return end;queued[guid]=nil
    local r=rows[guid];local eligible,reason,watchOnly=E.Priority(guid);if not r or not eligible then return end
    local unit=E.Resolve(guid);r.unit=unit
    if not unit then r.reason='Waiting for a GUID-matching player unit';Trace(r.source,guid,'NO_UNIT');return end
    if r.cheapPending then r.cheapPending=not Cheap(guid,unit,r.source or 'control',r) end
    local p,ready=Indexed(guid)
    if not ready then r.reason='Checking retained history';if not r.historyTraced then Trace(r.source,guid,'HISTORY_UNRESOLVED');r.historyTraced=true end;Schedule(guid);return end
    E.diagnostics.assessments=E.diagnostics.assessments+1
    r.assessedTick=C.Tick()
    local f=p and p.enrichment or {}
    if Fresh(f.gear,300) and BuildCoverage(f.gear.object) and Fresh(f.talents,300) and BuildCoverage(f.talents.object) then
        r.reason='Recent gear and talents already retained';Trace(r.source,guid,'ALREADY_CURRENT','gear and talents');return
    end
    if r.partialUntil and C.Stamp()<r.partialUntil then
        Trace(r.source,guid,'PARTIAL_RETRY_WAIT','gear and talents','scheduler')
        r.inspectState='partial_wait';r.reason='Repeated partial inspection; waiting for an inventory change or a later opportunity';E.revision=E.revision+1;return
    end
    if r.partialUntil then r.partialUntil=nil;r.partialRepeats=0 end
    local state,why=ns.ChronicleEncounters.RequestInspection(guid,unit,reason,watchOnly,true)
    local codes={queued='INSPECT_QUEUED',pending='INSPECT_QUEUED',cooldown='PLAYER_COOLDOWN',API_unavailable='API_UNAVAILABLE',not_inspectable='NOT_INSPECTABLE',capacity='QUEUE_CAPACITY',waiting_for_unit='NO_UNIT',permission_off='PERMISSION_OFF'}
    Trace(r.source,guid,codes[state] or 'NOT_TRACED','gear and talents','scheduler')
    r.inspectState=state;r.reason=why;E.revision=E.revision+1
end
function E.Start() E.Stop();owner=C.Owner();seed=true;earlySeed=true end
function E.RefreshVisible() seed=true end
function E.Stop() rows={};order={};jobs={};queued={};bindings={};owner=nil;seed=true;earlySeed=true;E.revision=E.revision+1 end
function E.Counts() return #order,#jobs,E.LIMIT end
function E.Status(guid)
    if not S.GUID(guid) then return end
    local p,c=Profile(guid);local r=owner==C.Owner() and rows[guid] or {}
    r=r or {};local watched=p and p.personal and p.personal.watch==true
    local eligible,priority=E.Priority(guid)
    local active=Enabled();local unit=active and eligible and E.Resolve(guid)
    local st=ns.ChronicleActivities.Peek(C.Owner());local indexed=st and st.intelligence and st.intelligence.players[guid]
    local f=indexed and indexed.enrichment or {};local result={guid=guid,watch=watched,priority=eligible,priorityReason=priority,origins=E.Origins(guid),categories={},failure=r.failure,
        identityCertainty=p and p.facts and p.facts.name and 'verified GUID observation' or 'GUID only; identity fields not yet observed'}
    for _,spec in ipairs(E.categories) do
        local v={id=spec.id,label=spec.label,owner=spec.owner,source=spec.source,mode=spec.mode,freshness=spec.freshness,retry=spec.retry,capability=spec.capability}
        local fact=f[spec.id]
        if spec.id=='identity' then local name=p and p.facts.name;fact=name and {at=name.at,source=name.source} end
        if spec.id=='social' and r.socialAt then fact={at=r.socialAt,source=r.socialSource} end
        v.lastVerifiedAt=fact and fact.at;v.source=fact and fact.source or v.source
        v.freshnessState=not fact and 'never_observed' or spec.freshness and (Fresh(fact,spec.freshness) and 'recent' or 'stale') or 'dated_observation'
        if spec.mode=='inspect' then
            local complete,known,total=BuildCoverage(fact and fact.object)
            v.completeness=not fact and 'missing' or complete and 'complete' or 'partial';v.knownFields=known;v.totalFields=total
        else v.completeness=(spec.mode=='passive' or spec.mode=='witness' or spec.mode=='unobservable' or spec.mode=='derived') and 'not_claimed' or fact and 'observed' or 'missing' end
        if spec.mode=='unobservable' then v.status='not_observable';v.reason='No supported remote source'
        elseif not C.IntelEnabled() or not C.Active() then v.status='permission_off';v.reason='Player recording is off; retained evidence remains'
        elseif spec.mode=='witness' then v.status=ns.IntelWitness.Selected() and 'event_driven' or 'permission_off';v.reason='Separate open-world witness permission; native events only'
        elseif spec.mode=='passive' or spec.mode=='derived' then v.status='event_driven';v.reason='Existing source evidence only; never a complete remote history'
        elseif not c then v.status='waiting_for_history';v.reason='Watch state is unknown until this character validates'
        elseif not eligible then v.status='not_watched';v.reason=ns.AthenaSocial and ns.AthenaSocial.State(guid)=='unresolved roster'
            and 'No independent acquisition priority; native friend roster is not ready' or 'No current watch, verified friend or independently earned acquisition priority'
        elseif fact and Fresh(fact,spec.freshness) and (spec.mode~='inspect' or BuildCoverage(fact.object)) then v.status='up_to_date';v.reason='Recent source evidence retained'
        elseif spec.mode=='inspect' and ns.ChronicleEncounters.InspectionState(guid)=='pending' then v.status='pending';v.reason='Waiting for the matching native inspect response'
        elseif not unit then v.status='waiting_for_unit';v.reason='Player has no currently accessible GUID-matching unit'
        elseif spec.mode=='inspect' and r.partialUntil and C.Stamp()<r.partialUntil then v.status='partial_wait';v.reason='Repeated partial inspection; waiting for an inventory change or a later opportunity';v.retryAfter=r.partialUntil
        elseif spec.mode=='inspect' then
            local state,why=ns.ChronicleEncounters.InspectionState(guid)
            if not X.API('NotifyInspect') or not X.API('CanInspect') then state='API_unavailable';why='Native inspection API unavailable'
            elseif X.Bool(X.Call('UnitIsEnemy','player',unit))==true or X.Bool(X.Call('CanInspect',unit,true))~=true then state='not_inspectable';why='Player cannot currently be inspected'
            elseif state~='cooldown' and state~='queued' then state=fact and not BuildCoverage(fact.object) and 'partial' or fact and 'stale' or r.inspectState=='error' and 'error' or 'missing';why=r.failure or 'Waiting for a safe inspection opportunity' end
            v.status=state;v.reason=why
        else v.status=fact and 'stale' or 'missing';v.reason='Readable values will be captured at the next unit opportunity' end
        v.retryEligible=active and eligible and unit~=nil and spec.mode~='passive' and spec.mode~='derived' and spec.mode~='unobservable' and v.status~='up_to_date' and v.status~='pending' and v.status~='queued' and v.status~='cooldown' and v.status~='partial_wait' and v.status~='not_inspectable' and v.status~='API_unavailable'
        if spec.mode=='inspect' then v.lastFailure=r.failure end
        result.categories[#result.categories+1]=v
    end
    return result
end
function E.Blocks(guid,details)
    local s=E.Status(guid);if not s or not s.priority then return {} end
    local out={{kind='heading',text=s.watch and 'Watchlist enrichment' or 'Important player enrichment'}}
    for _,v in ipairs(s.categories) do
        if details or v.id=='gear' or v.id=='talents' then
            out[#out+1]={kind='body',text=v.label..': '..v.reason..(details and ('\nCoverage: '..tostring(v.completeness)..' • Age: '..v.freshnessState..'\nStatus: '..v.status..' • Last verified: '..(v.lastVerifiedAt and tostring(v.lastVerifiedAt) or 'Never observed')..'\nSource: '..v.source..' • Retry: '..v.retry..(v.lastFailure and '\nLast failure: '..v.lastFailure or '')) or '')}
        end
    end
    return out
end
