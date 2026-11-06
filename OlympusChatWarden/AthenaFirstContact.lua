-- Direct observed contact is not friendship or a new all-player inspect grant.
local _,ns=...
local C,S,X=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture
local F={LIMIT=64,diagnostics={contacts=0,queued=0,attempted=0,denied=0}};ns.AthenaFirstContact=F
local contacts,order,issued,activeOwner,seenBasis,basisOrder={}, {},{},nil,{},{}
local partyMembers={}
function F.Selected() return ns.DB and ns.DB.firstContactInspectConsent==1 end
local function ResetOwner()
    local owner=C.Owner();if owner~=activeOwner then contacts={};order={};issued={};seenBasis={};basisOrder={};partyMembers={};activeOwner=owner end
    return owner
end
local function Reason(code) F.lastReason=code;F.diagnostics.denied=F.diagnostics.denied+1 end
function F.SetEnabled(value)
    if type(value)~='boolean' or not ns.DB or value and not ns.Membership.Allowed() then return false end
    ns.DB.firstContactInspectConsent=value and 1 or nil
    if not value and ns.ChronicleEncounters.CancelContactWork then ns.ChronicleEncounters.CancelContactWork() end
    return true
end
local function EligibleUnit(guid,kind)
    local unit=ns.AthenaEnrichment.Resolve(guid)
    if not unit or S.GUID(X.Call('UnitGUID',unit))~=guid then return end
    if kind=='SMALL_PARTY' then
        local total=S.Integer(X.Call('GetNumGroupMembers'),0,40)
        if not total or total<2 or total>5 or X.Bool(X.Call('IsInRaid'))==true or X.Bool(X.Call('UnitInParty',unit))~=true then return end
    end
    return unit
end
function F.Permitted(guid,basis)
    ResetOwner();local row=contacts[guid]
    return F.Selected() and C.Active() and C.IntelEnabled() and not S.loading and not S.blocked
        and row and row.owner==C.Owner() and (issued[guid]==basis or row.canonicalRef==basis and (C.Tick() or 0)-row.tick<=30)
end
function F.BeginAttempt(guid,unit,basis)
    if not F.Permitted(guid,basis) or issued[guid] or S.GUID(X.Call('UnitGUID',unit))~=guid then return false end
    local row=contacts[guid]
    local e=X.Record('native_event','control',{recordType='contact_inspection_attempt',basisRef=basis,triggerAt=row.at,
        scope='one initial native inspect request attempt; acceptance and unreadable fields unknown'},guid,false)
    if not e then Reason('WRITE_REJECTED');return false end
    issued[guid]=basis;F.diagnostics.attempted=F.diagnostics.attempted+1;return true
end
local function Queue(row)
    if not F.Selected() or not C.IntelEnabled() or issued[row.guid] then return end
    if row.queued then return end;row.queued=true;F.diagnostics.queued=F.diagnostics.queued+1
    X.Queue('first-contact:'..row.guid,function()
        local journal=ns.ChronicleStartupJournal
        while S.loading or journal and (journal.Busy() or journal.Count()>0) do
            if C.Owner()~=row.owner or not F.Selected() or not C.Active() or (C.Tick() or 0)-row.tick>30 then row.queued=nil;Reason('HISTORY_UNRESOLVED');return end
            X.Yield()
        end
        if contacts[row.guid]~=row then return end
        local c=S.Character(row.owner,false);if not c or C.Owner()~=row.owner then row.queued=nil;Reason('HISTORY_UNRESOLVED');return end
        local contact
        for n=#c.events,1,-1 do
            local e=c.events[n]
            if e.subject==row.guid then
                if e.details.recordType=='contact_inspection_attempt' then row.queued=nil;issued[row.guid]=e.details.basisRef;Reason('ALREADY_ATTEMPTED');return end
                if not contact and e.details.recordType=='contact_observed' then contact=e end
            end
            if n%128==0 then X.Yield();if not F.Selected() or C.Owner()~=row.owner or contacts[row.guid]~=row then row.queued=nil;return end end
        end
        row.queued=nil
        if not contact then Reason('SOURCE_UNAVAILABLE');return end
        row.canonicalRef=contact.id
        if not F.Permitted(row.guid,row.canonicalRef) then Reason('CONSENT_OR_OPPORTUNITY_ENDED');return end
        local unit=EligibleUnit(row.guid,row.kind);if not unit then Reason('NO_CURRENT_DIRECT_UNIT');return end
        if ns.AthenaEnrichment.Priority(row.guid) then ns.AthenaEnrichment.Opportunity(unit,'control');Reason('EXISTING_PRIORITY_REUSED');return end
        local state=ns.ChronicleEncounters.RequestInspection(row.guid,unit,'first contact snapshot',false,false,row.canonicalRef)
        F.lastReason=state
    end,true)
end
local function Observe(guid,basis,kind)
    if not S.GUID(guid) or guid==select(2,C.Owner()) or not C.IntelEnabled() or not C.Active() then return end
    ResetOwner()
    local key=basis.id..'/'..guid;if seenBasis[key] then return true end
    local e=X.Record('native_event','control',{recordType='contact_observed',basisRef=basis.id,triggerAt=basis.at,contactKind=kind,
        scope='source-verified direct interaction; not friendship, outcome or fight-time gear'},guid,false)
    if not e then Reason('WRITE_REJECTED');return end
    if #basisOrder>=128 then seenBasis[table.remove(basisOrder,1)]=nil end;seenBasis[key]=true;basisOrder[#basisOrder+1]=key
    F.diagnostics.contacts=F.diagnostics.contacts+1
    if not contacts[guid] then
        if #order>=F.LIMIT then local old=table.remove(order,1);contacts[old]=nil;issued[old]=nil end
        order[#order+1]=guid
    end
    local row={owner=C.Owner(),guid=guid,at=basis.at,tick=C.Tick() or 0,kind=kind,canonicalRef=e.id};contacts[guid]=row
    Queue(row)
    return true
end
function F.Accepted(e)
    if not C.IntelEnabled() then return end
    ResetOwner()
    local d=e.details
    if e.kind=='group_roster' and d.rosterComplete==true and d.rosterRaid==false and d.rosterSize>=2 and d.rosterSize<=5 then
        local current={}
        for _,guid in ipairs(d.members) do
            -- Only a successfully retained contact can suppress a later retry.
            if partyMembers[guid] or Observe(guid,e,'SMALL_PARTY') then current[guid]=true end
        end
        partyMembers=current
    elseif e.kind=='group_roster' and d.rosterComplete==true then partyMembers={}
    elseif d.recordType=='duel_session_start' and d.accepted==true and S.GUID(d.opponentGUID) then Observe(d.opponentGUID,e,'DIRECT_DUEL') end
end
function F.Opportunity(unit)
    if not F.Selected() then return end;ResetOwner()
    local guid=S.GUID(X.Call('UnitGUID',unit));local row=guid and contacts[guid]
    if not row or issued[guid] then return end
    if row.kind=='SMALL_PARTY' and EligibleUnit(guid,row.kind) then row.tick=C.Tick() or row.tick;Queue(row) end
end
function F.Handle(event,unit)
    if event=='PLAYER_TARGET_CHANGED' then F.Opportunity('target')
    elseif event=='UPDATE_MOUSEOVER_UNIT' then F.Opportunity('mouseover')
    elseif event=='GROUP_ROSTER_UPDATE' then for n=1,4 do F.Opportunity('party'..n) end end
end
function F.Start()
    ResetOwner();local c=S.WriterCharacter(C.Owner(),false)
    local st=c and ns.AthenaIntakeContext.State(C.Owner(),c.currentSession)
    local e=st and st.rosterEvidence
    if e and e.elapsed and C.Tick() and C.Tick()-e.elapsed<=5 then F.Accepted(e) end
end
function F.Stop() contacts={};order={};issued={};seenBasis={};basisOrder={};partyMembers={};activeOwner=nil end
function F.Counts() local n=0;for _ in pairs(issued) do n=n+1 end;return #order,n,#basisOrder end
X.Register(F,{'PLAYER_TARGET_CHANGED','UPDATE_MOUSEOVER_UNIT','GROUP_ROSTER_UPDATE'},'intel')
