-- Optional history context is additive. Originals never depend on a graph.
local _,ns=...
local S,X=ns.ChronicleStore,ns.ChronicleCapture
local V={};ns.AthenaHistorySchema=V
-- Compare only explicit, safely readable location facts. Missing fields do not
-- establish a departure, and a contradictory observation is not an exit time.
function V.InstanceContradiction(before,after)
    if not ns.Readable(before) or type(before)~='table' or not ns.Readable(after) or type(after)~='table' then return false end
    if not ns.Readable(before.inInstance) or before.inInstance~=true or not ns.Readable(after.inInstance) then return false end
    if after.inInstance==false then return true end
    if after.inInstance~=true then return false end
    for _,key in ipairs({'instanceType','instanceName','instanceID'}) do
        local a,b=before[key],after[key]
        if ns.Readable(a) and ns.Readable(b) and a~=nil and b~=nil and a~=b then return true end
    end
    return false
end
local refKeys={rosterRef=true,instanceRef=true,encounterRef=true,matchRef=true}
function V.Context(t,owner)
    if not ns.Readable(t) or type(t)~='table' or getmetatable(t) or t.version~=1 then return end
    local allowed={version=true,sourceModule=true,accessScope=true,linkStatus=true,mapID=true,difficultyID=true,
        rosterRef=true,rosterObservedAt=true,rosterVerifiedAt=true,instanceRef=true,encounterRef=true,matchRef=true}
    local out={}
    for key,value in pairs(t) do
        if not ns.Readable(key) or not allowed[key] or not ns.Readable(value) then return end
        if refKeys[key] then
            value=S.Text(value,256)
            if not value or value:sub(1,#owner+1)~=owner..':' or not value:sub(#owner+2):match('^%d+$') then return end
        elseif key=='version' then value=S.Integer(value,1,1)
        elseif key=='mapID' then value=S.Integer(value,1,10000000)
        elseif key=='difficultyID' then value=S.Integer(value,0,100000)
        elseif key=='rosterObservedAt' or key=='rosterVerifiedAt' then value=S.Number(value,1)
        elseif key=='sourceModule' then value=({chronicle=true,intel=true,combat=true,guild=true,shield=true,chat=true,alerts=true,command=true})[value] and value
        elseif key=='accessScope' then value=({LOCAL_HISTORY=true,LOCAL_INTEL=true,PRIVATE_INCIDENT=true})[value] and value
        elseif key=='linkStatus' then value=({SOURCE_CONTEXT=true,LINK_PENDING=true})[value] and value end
        if value==nil then return end;out[key]=value
    end
    if not out.sourceModule or not out.accessScope or not out.linkStatus then return end
    return out
end
V.types={contact_observed=true,contact_inspection_attempt=true,historical_incident=true,incident_correction=true,match_observed=true,aura_partial=true}
local common='recordType evidenceClass outcome outcomeScope scope'
local words={
    contact_observed='basisRef triggerAt contactKind',contact_inspection_attempt='basisRef triggerAt',
    historical_incident='sourceActionID cause1 cause2 cause3 count method firstAt lastAt ownerModule',incident_correction='incidentRef correctedSourceID method',
    match_observed='phase matchSequence runID',
    aura_partial='auraInstanceID auraEpoch effectTransition transitionKey runID subjectScope helpful harmful bossAura applications duration expirationTime sourceGUID fieldReadability'}
local allowed={}
for family,fields in pairs(words) do allowed[family]={};for key in (common..' '..fields):gmatch('%S+') do allowed[family][key]=true end end
local function Ref(value) return S.Text(value,256)~=nil end
function V.Valid(d)
    local family=d.recordType;if not allowed[family] or not S.Text(d.scope,256) then return false end
    for key in pairs(d) do if not allowed[family][key] then return false end end
    if family=='contact_observed' then return Ref(d.basisRef) and S.Number(d.triggerAt,1)~=nil and ({SMALL_PARTY=true,DIRECT_DUEL=true})[d.contactKind]==true
    elseif family=='contact_inspection_attempt' then return Ref(d.basisRef) and S.Number(d.triggerAt,1)~=nil
    elseif family=='historical_incident' then
        if not ns.Athena.OperationalSource(d.sourceActionID) or not S.Integer(d.count,1,3) or not S.Number(d.firstAt,1) or not S.Number(d.lastAt,d.firstAt)
            or not ({chat=true,shield=true})[d.ownerModule] or not ({['own protection action']=true,['three local filter decisions']=true})[d.method] then return false end
        for _,key in ipairs({'cause1','cause2','cause3'}) do if d[key]~=nil and not ns.Athena.OperationalSource(d[key]) then return false end end
        return true
    elseif family=='incident_correction' then return (d.incidentRef==nil or Ref(d.incidentRef)) and ns.Athena.OperationalSource(d.correctedSourceID)~=nil and d.method=='source decision marked false positive'
    elseif family=='match_observed' then return d.phase=='native match active' and S.Integer(d.matchSequence,1)~=nil and Ref(d.runID)
    elseif family=='aura_partial' then
        if not S.Integer(d.auraInstanceID,1,1000000000) or not S.Integer(d.auraEpoch,1) or not Ref(d.runID) or not Ref(d.transitionKey)
            or not ({self=true,['eligible-other']=true})[d.subjectScope] or not ({baseline=true,applied=true,changed=true,removed=true})[d.effectTransition]
            or not S.Text(d.fieldReadability,256) then return false end
        for _,key in ipairs({'helpful','harmful','bossAura'}) do if d[key]~=nil and type(d[key])~='boolean' then return false end end
        if d.applications~=nil and not S.Integer(d.applications,0,1000000) or d.duration~=nil and not S.Number(d.duration,0)
            or d.expirationTime~=nil and not S.Number(d.expirationTime,0) or d.sourceGUID~=nil and not X.Entity(d.sourceGUID) then return false end
        return true
    end
end
function V.Record(t,owner)
    local d=t.details;local own=owner:match('/(Player%-.+)$')
    if d.recordType=='contact_observed' then
        return S.GUID(t.subject)~=nil and t.subject~=own and ({GROUP_ROSTER_UPDATE=true,PARTY_MEMBERS_CHANGED=true,DUEL_COUNTDOWN=true,control=true})[t.source]==true
    elseif d.recordType=='contact_inspection_attempt' then return S.GUID(t.subject)~=nil and t.subject~=own and t.source=='control'
    elseif d.recordType=='historical_incident' or d.recordType=='incident_correction' then
        return t.subject==nil and t.source=='control' and t.sourceContext and t.sourceContext.accessScope=='PRIVATE_INCIDENT'
    elseif d.recordType=='match_observed' then return t.source=='PVP_MATCH_ACTIVE' and t.subject==nil
    elseif d.recordType=='aura_partial' then
        return S.GUID(t.subject)~=nil and (t.subject==own)==(d.subjectScope=='self') and
            (t.source=='UNIT_AURA' or ({control=true,PLAYER_TARGET_CHANGED=true,PLAYER_FOCUS_CHANGED=true,UPDATE_MOUSEOVER_UNIT=true,
                NAME_PLATE_UNIT_ADDED=true,GROUP_ROSTER_UPDATE=true,UNIT_TARGET=true})[t.source] and d.effectTransition~='applied' and d.effectTransition~='removed')
    end
    return false
end
function V.Title(e)
    local d=e.details
    if d.recordType=='contact_observed' then return 'Recorded direct contact • '..(d.contactKind=='SMALL_PARTY' and 'small party' or 'own duel') end
    if d.recordType=='contact_inspection_attempt' then return 'First-contact inspection requested' end
    if d.recordType=='historical_incident' then return 'Private local protection context • source-qualified' end
    if d.recordType=='incident_correction' then return 'Private incident source corrected' end
    if d.recordType=='match_observed' then return 'Native battleground match active' end
    if d.recordType=='aura_partial' then return 'Provisional effect '..d.effectTransition..' • spell unknown' end
end
