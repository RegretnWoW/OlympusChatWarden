-- Narrow capture-first evidence. Only allowed primitive fields enter the
-- existing canonical writer. Provisional is a claim limit, never a secret bypass.
local _,ns=...
local C,S,X=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture
local O={VERSION=1,LIMIT=128,diagnostics={seen=0,accepted=0,provisional=0,coalesced=0,unresolved=0,revoked=0,evicted=0}};ns.AthenaObservations=O
local rows,bindings,owner,epoch,count={},{},nil,0,0
local phases={UNIT_SPELLCAST_START='start',UNIT_SPELLCAST_STOP='stop',UNIT_SPELLCAST_SUCCEEDED='success notification',
    UNIT_SPELLCAST_INTERRUPTED='interrupted',UNIT_SPELLCAST_CHANNEL_START='channel start',UNIT_SPELLCAST_CHANNEL_STOP='channel stop'}
local sources={pet_link={UNIT_PET=true,control=true,PLAYER_TARGET_CHANGED=true,UPDATE_MOUSEOVER_UNIT=true,PLAYER_FOCUS_CHANGED=true,NAME_PLATE_UNIT_ADDED=true,GROUP_ROSTER_UPDATE=true},
    group_assignment={control=true,GROUP_ROSTER_UPDATE=true,PARTY_LEADER_CHANGED=true,PLAYER_ROLES_ASSIGNED=true,GROUP_JOINED=true},
    target_episode={UNIT_TARGET=true,PLAYER_TARGET_CHANGED=true},cast_observation={},visible_use={control=true,PLAYER_MOUNT_DISPLAY_CHANGED=true,UNIT_FLAGS=true,PLAYER_TARGET_CHANGED=true,UPDATE_MOUSEOVER_UNIT=true,NAME_PLATE_UNIT_ADDED=true,PLAYER_FOCUS_CHANGED=true},
    group_transition={GROUP_JOINED=true,GROUP_LEFT=true}}
for event in pairs(phases) do sources.cast_observation[event]=true end
sources.cast_observation_count=sources.cast_observation
O.sources=sources
function O.Phase(source) return phases[source] end
function O.Token(unit)
    unit=S.Text(unit,32)
    return unit and (unit=='player' or unit=='target' or unit=='focus' or unit=='mouseover' or unit:match('^party%d+$')
        or unit:match('^raid%d+$') or unit:match('^nameplate%d+$') or unit:match('^%a+target$')) and unit or nil
end
function O.Eligibility(guid)
    if not X.Ready() or owner~=C.Owner() or not S.GUID(guid) then return end
    if guid==select(2,C.Owner()) then return C.PersonalEnabled() and 'SELF' or nil end
    if not ns.AthenaCollectionPolicy.Deep(16,guid,{witness=true,priorityOnly=true}) then return end
    if ns.AthenaEnrichment.Watched(guid) then return 'MANUAL_WATCH' end
    if ns.AthenaSocial.Friend(guid) then return 'VERIFIED_FRIEND' end
    return 'EARNED_IMPORTANT'
end
local function Entry(unit)
    unit=O.Token(unit);if not unit then return end
    local guid=S.GUID(X.Call('UnitGUID',unit));local old=bindings[unit]
    if old and old~=guid then O.Revoke(old);bindings[unit]=nil end
    local eligibility=guid and O.Eligibility(guid)
    if not eligibility or X.Bool(X.Call('UnitIsPlayer',unit))~=true then O.diagnostics.unresolved=O.diagnostics.unresolved+1;return end
    local row=rows[guid]
    if not row then
        if count>=O.LIMIT then
            local oldest,at;for id,v in pairs(rows) do if not at or v.checked<at then oldest,at=id,v.checked end end
            rows[oldest]=nil;count=count-1;O.diagnostics.evicted=O.diagnostics.evicted+1
            X.Mark('Capture-first intelligence','Live cache evicted; future state is a new baseline; history retained')
        end
        epoch=epoch+1;row={guid=guid,epoch=epoch,sequence=0,checked=C.Tick() or 0};rows[guid]=row;count=count+1
    end
    local n=0;for _ in pairs(bindings) do n=n+1 end;if n>=256 then bindings={} end
    bindings[unit]=guid;row.checked=C.Tick() or row.checked;return row,eligibility
end
local function Stable(unit,row)
    return rows[row.guid]==row and S.GUID(X.Call('UnitGUID',unit))==row.guid and O.Eligibility(row.guid)~=nil
end
function O.Save(unit,row,source,data,provisional,reason)
    if not Stable(unit,row) then O.diagnostics.unresolved=O.diagnostics.unresolved+1;return end
    if not sources[data.recordType] or not sources[data.recordType][source] then return end
    row.sequence=row.sequence+1
    data.evidenceState=provisional and 'PROVISIONAL_OBSERVATION' or 'VERIFIED_FACT'
    data.interpretationVersion=1;data.sourceVersion=1;data.subjectEligibility=O.Eligibility(row.guid)
    data.fieldReadability=reason or 'Only safely readable native fields retained'
    data.interpretationStatus=provisional and 'UNRESOLVED_INTERPRETATION' or 'RAW_OBSERVED'
    data.runID=X.runID;data.sourceOccurrenceKey='observation/'..row.epoch..'/'..row.sequence
    data.coverage='Dated observed source; unobserved intervals unknown'
    local e=X.Record('native_event',source,data,row.guid,false,C.Place())
    if e then O.diagnostics.accepted=O.diagnostics.accepted+1;if provisional then O.diagnostics.provisional=O.diagnostics.provisional+1 end end
    return e
end
local function PetToken(unit)
    if unit=='player' then return 'pet' end
    local n=unit:match('^party(%d+)$');if n then return 'partypet'..n end
    n=unit:match('^raid(%d+)$');if n then return 'raidpet'..n end
    if unit=='target' or unit=='focus' or unit=='mouseover' then return unit..'pet' end
end
function O.Pet(unit,source)
    local row=Entry(unit);local pet=unit and PetToken(unit);if not row or not pet then return end
    local guid,kind=X.Entity(X.Call('UnitGUID',pet))
    if not guid or kind=='Player' then return end
    if not Stable(unit,row) or X.Entity(X.Call('UnitGUID',pet))~=guid then O.diagnostics.unresolved=O.diagnostics.unresolved+1;return end
    if row.pet==guid then O.diagnostics.coalesced=O.diagnostics.coalesced+1;return end
    if O.Save(unit,row,source,{recordType='pet_link',petGUID=guid,entityKind=kind,baseline=row.pet==nil,
        attribution='STATE_ON_SUBJECT',scope='native owner-pet unit link; not permanent ownership'},false) then row.pet=guid end
end
function O.Role(unit,source)
    local row=Entry(unit);if not row then return end
    local grouped=X.Bool(X.Call('UnitInParty',unit))==true or S.Integer(X.Call('UnitInRaid',unit),1,40)~=nil
    if not grouped and unit=='player' then grouped=(S.Integer(X.Call('GetNumGroupMembers'),0,40) or 0)>1 end
    if not grouped then return end
    local role=S.Text(X.Call('UnitGroupRolesAssigned',unit),32)
    if not ({TANK=true,HEALER=true,DAMAGER=true,NONE=true})[role or ''] then role=nil end
    local leader=X.Bool(X.Call('UnitIsGroupLeader',unit));local assistant=X.Bool(X.Call('UnitIsGroupAssistant',unit))
    if not role and leader==nil and assistant==nil then return end
    if not Stable(unit,row) then return end
    -- A restricted getter is not a change to the last readable state.
    local known=row.roleFields or {};local merged={}
    merged.assignedRole=role or known.assignedRole
    merged.groupLeader=leader;if leader==nil then merged.groupLeader=known.groupLeader end
    merged.groupAssistant=assistant;if assistant==nil then merged.groupAssistant=known.groupAssistant end
    local signature=(merged.assignedRole or '?')..'/'..tostring(merged.groupLeader)..'/'..tostring(merged.groupAssistant)
    if row.role==signature then O.diagnostics.coalesced=O.diagnostics.coalesced+1;return end
    if O.Save(unit,row,source,{recordType='group_assignment',assignedRole=role,groupLeader=leader,groupAssistant=assistant,
        baseline=row.role==nil,attribution='GROUP_CONTEXT',scope='native roster assignment; not actual combat role or boss attendance'},false) then row.role=signature;row.roleFields=merged end
end
function O.Target(unit,source)
    local row=Entry(unit);if not row then return end
    local target=unit=='player' and 'target' or unit..'target'
    local guid=S.GUID(X.Call('UnitGUID',target));if not guid or guid==row.guid then return end
    -- Keep contextual episodes, never a full target-click graph.
    local combat=X.Bool(X.Call('UnitAffectingCombat',unit))==true
    local grouped=X.Bool(X.Call('UnitInParty',unit))==true or S.Integer(X.Call('UnitInRaid',unit),1,40)~=nil
    if unit=='player' and not O.Eligibility(guid) then return end
    if not combat and not grouped then return end
    if not Stable(unit,row) or S.GUID(X.Call('UnitGUID',target))~=guid then O.diagnostics.unresolved=O.diagnostics.unresolved+1;return end
    local now=C.Tick() or 0
    row.targets=row.targets or {};row.targetOrder=row.targetOrder or {}
    local key=(X.runID or '')..'/'..guid;local prior=row.targets[key]
    if prior and now-prior<60 then O.diagnostics.coalesced=O.diagnostics.coalesced+1;return end
    if O.Save(unit,row,source,{recordType='target_episode',relatedGUID=guid,attribution='STATE_ON_SUBJECT',
        scope='observed target in native group/combat context; no attack or intent',inCombat=combat},false) then
        row.targets[key]=now;if not prior then row.targetOrder[#row.targetOrder+1]=key end
        if #row.targetOrder>16 then row.targets[table.remove(row.targetOrder,1)]=nil end
    end
end
local function Field(value,validator)
    if not ns.Readable(value) then return nil,'SECRET_OR_RESTRICTED' end
    local clean=validator(value);return clean,clean~=nil and 'READABLE' or 'UNAVAILABLE'
end
function O.Cast(event,unit,cast,spell)
    local row,eligibility=Entry(unit);if not row then return end
    -- Preview 6 owns self successful counts and existing selected other casts.
    if eligibility=='SELF' and event=='UNIT_SPELLCAST_SUCCEEDED' then return end
    local data,provisional,reason=ns.ChronicleSource.Cast(phases[event],cast,spell);if not data then return end
    local id,castID=data.spellID,data.castGUID
    local phase=phases[event];if not phase then return end
    row.casts=row.casts or {};row.castOrder=row.castOrder or {}
    local now=C.Tick() or 0;local key=castID and castID..'/'..phase or 'unknown/'..phase
    local prior=row.casts[key]
    -- Without a readable native cast identity, two notifications cannot be
    -- proved duplicates. Preserve both; never guess equality from timing.
    if prior and castID then O.diagnostics.coalesced=O.diagnostics.coalesced+1;return end
    -- Duel consent owns ordinary-opponent success counts. Deep subjects use
    -- this primary batch path; selected abilities remain separate evidence.
    local e
    if id and (phase=='start' or phase=='stop' or phase=='success notification') and Stable(unit,row) then
        e=ns.AthenaCastCounts.Admit(unit,row.guid,data,eligibility)
    end
    if not e then e=O.Save(unit,row,event,data,provisional,reason) end
    if e then
        row.casts[key]=now;if not prior then row.castOrder[#row.castOrder+1]=key end
        if #row.castOrder>64 then row.casts[table.remove(row.castOrder,1)]=nil end
    end
end
function O.Visible(unit,source)
    local row=Entry(unit);if not row then return end
    local mounted=X.Bool(X.Call('UnitIsMounted',unit))
    if mounted==nil and unit=='player' then mounted=X.Bool(X.Call('IsMounted')) end
    if mounted==nil or not Stable(unit,row) then return end
    if row.mounted==mounted then O.diagnostics.coalesced=O.diagnostics.coalesced+1;return end
    if O.Save(unit,row,source,{recordType='visible_use',mounted=mounted,baseline=row.mounted==nil,attribution='STATE_ON_SUBJECT',
        scope='native mounted state only; mount identity and collection unknown'},false) then row.mounted=mounted end
end
function O.Opportunity(unit,source)
    unit=O.Token(unit);if not unit then return end
    O.Pet(unit,source);O.Visible(unit,source)
end
function O.Start() O.Stop();owner=C.Owner();O.Opportunity('player','control');O.Role('player','control') end
function O.Stop() rows={};bindings={};count=0;owner=nil end
function O.Revoke(guid) ns.AthenaCastCounts.Revoke(guid);if rows[guid] then rows[guid]=nil;count=count-1 end end
function O.Counts() return count end
function O.Handle(event,a,b,c)
    O.diagnostics.seen=O.diagnostics.seen+1
    if phases[event] then O.Cast(event,O.Token(a),b,c)
    elseif event=='UNIT_PET' then O.Pet(O.Token(a),event)
    elseif event=='UNIT_TARGET' then O.Target(O.Token(a),event)
    elseif event=='PLAYER_TARGET_CHANGED' then O.Target('player',event);O.Opportunity('target',event)
    elseif event=='NAME_PLATE_UNIT_REMOVED' then local unit=O.Token(a);local guid=unit and bindings[unit];if guid then O.Revoke(guid);bindings[unit]=nil end
    elseif event=='GROUP_JOINED' or event=='GROUP_LEFT' then
        local row=Entry('player')
        if row then O.Save('player',row,event,{recordType='group_transition',phase=event=='GROUP_JOINED' and 'native group joined' or 'native group left',
            attribution='SELF_ACTION',scope='delivered own group boundary; earlier interval unknown'},false) end
        for _,v in pairs(rows) do v.role=nil;v.roleFields=nil end
    elseif event=='GROUP_ROSTER_UPDATE' or event=='PARTY_LEADER_CHANGED' or event=='PLAYER_ROLES_ASSIGNED' then
        O.Role('player',event)
        local raid=X.Bool(X.Call('IsInRaid'))==true
        for n=1,raid and 40 or 4 do local unit=(raid and 'raid' or 'party')..n;O.Role(unit,event);if event=='GROUP_ROSTER_UPDATE' then O.Pet(unit,event) end end
    elseif event=='PLAYER_MOUNT_DISPLAY_CHANGED' then O.Visible('player',event)
    else O.Opportunity(event=='PLAYER_FOCUS_CHANGED' and 'focus' or event=='UPDATE_MOUSEOVER_UNIT' and 'mouseover' or O.Token(a),event) end
end
local events={'UNIT_PET','GROUP_JOINED','GROUP_LEFT','GROUP_ROSTER_UPDATE','PARTY_LEADER_CHANGED','PLAYER_ROLES_ASSIGNED',
    'UNIT_TARGET','PLAYER_TARGET_CHANGED','PLAYER_FOCUS_CHANGED','UPDATE_MOUSEOVER_UNIT','NAME_PLATE_UNIT_ADDED','NAME_PLATE_UNIT_REMOVED','PLAYER_MOUNT_DISPLAY_CHANGED','UNIT_FLAGS'}
for event in pairs(phases) do events[#events+1]=event end
X.Register(O,events,'history')
