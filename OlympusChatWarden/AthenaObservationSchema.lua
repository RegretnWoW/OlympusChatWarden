-- Additive typed observation validation; old records require no new fields.
local _,ns=...
local S,X=ns.ChronicleStore,ns.ChronicleCapture
local V={};ns.AthenaObservationSchema=V
local keys={cast_observation_count='spellID phase count firstAt lastAt firstElapsed lastElapsed aggregationVersion contextRef contextKind windowRef unknownCount sourceEvidenceSummary observerSession encounterID',pet_link='petGUID entityKind baseline',group_assignment='assignedRole groupLeader groupAssistant baseline',
    target_episode='relatedGUID inCombat',cast_observation='spellID castGUID phase',visible_use='mounted baseline',
    group_transition='phase',personal_source='phase auctionID playerAccepted targetAccepted'}
V.types=keys
local allowed={}
local common='recordType evidenceState interpretationVersion sourceVersion subjectEligibility fieldReadability interpretationStatus runID sourceOccurrenceKey scope attribution coverage evidenceClass outcome outcomeScope'
local guild='guildName guildRealm guildRank guildAssociated guildContextMembers guildContextGuildMembers guildContextKnown guildContextSame guildGroupSize guildContextUnknown guildMajority orgAffiliation'
for family,fields in pairs(keys) do
    allowed[family]={};for key in (common..' '..fields..((family=='group_assignment' or family=='group_transition') and ' '..guild or '')):gmatch('%S+') do allowed[family][key]=true end
end
local attribution={cast_observation_count='STATE_ON_SUBJECT',pet_link='STATE_ON_SUBJECT',group_assignment='GROUP_CONTEXT',target_episode='STATE_ON_SUBJECT',cast_observation='STATE_ON_SUBJECT',visible_use='STATE_ON_SUBJECT',group_transition='SELF_ACTION',personal_source='SELF_ACTION'}
function V.Metadata(d)
    if not ({VERIFIED_FACT=true,PROVISIONAL_OBSERVATION=true})[d.evidenceState] or d.interpretationVersion~=1 or d.sourceVersion~=1
        or not ({SELF=true,MANUAL_WATCH=true,EARNED_IMPORTANT=true,VERIFIED_FRIEND=true})[d.subjectEligibility]
        or not S.Text(d.fieldReadability,256) then return false end
    return d.interpretationStatus==(d.evidenceState=='VERIFIED_FACT' and 'RAW_OBSERVED' or 'UNRESOLVED_INTERPRETATION')
end
function V.Valid(d)
    local r=d.recordType;if not keys[r] or not V.Metadata(d) or not S.Text(d.runID,256)
        or not S.Text(d.sourceOccurrenceKey,256) or not S.Text(d.scope,256) or d.attribution~=attribution[r]
        or d.coverage~='Dated observed source; unobserved intervals unknown' then return false end
    for key in pairs(d) do if not allowed[r][key] then return false end end
    if r=='cast_observation_count' then
        return S.Integer(d.spellID,1,1000000000) and S.Integer(d.count,1,128) and S.Integer(d.unknownCount,0,d.count)
            and d.aggregationVersion==1 and S.Number(d.firstAt,1) and S.Number(d.lastAt,d.firstAt)
            and S.Number(d.firstElapsed,0) and S.Number(d.lastElapsed,d.firstElapsed)
            and S.Text(d.contextRef,256) and S.Text(d.windowRef,256) and S.Text(d.observerSession,256)
            and S.Text(d.sourceEvidenceSummary,256) and ({unknown=true,['native encounter interval']=true,['observed combat window']=true,['observed match interval']=true})[d.contextKind]
            and (d.encounterID==nil or S.Integer(d.encounterID,1,10000000))
            and ({start=true,stop=true,['success notification']=true})[d.phase]
            and d.evidenceState==(d.unknownCount>0 and 'PROVISIONAL_OBSERVATION' or 'VERIFIED_FACT')
    elseif r=='pet_link' then local _,kind=X.Entity(d.petGUID);return kind~=nil and kind~='Player' and kind==d.entityKind and type(d.baseline)=='boolean' and d.evidenceState=='VERIFIED_FACT'
    elseif r=='group_assignment' then
        if d.assignedRole~=nil and not ({TANK=true,HEALER=true,DAMAGER=true,NONE=true})[d.assignedRole] then return false end
        for _,key in ipairs({'groupLeader','groupAssistant'}) do if d[key]~=nil and type(d[key])~='boolean' then return false end end
        return type(d.baseline)=='boolean' and (d.assignedRole~=nil or d.groupLeader~=nil or d.groupAssistant~=nil) and d.evidenceState=='VERIFIED_FACT'
    elseif r=='target_episode' then return S.GUID(d.relatedGUID)~=nil and type(d.inCombat)=='boolean' and d.evidenceState=='VERIFIED_FACT'
    elseif r=='visible_use' then return type(d.mounted)=='boolean' and type(d.baseline)=='boolean' and d.evidenceState=='VERIFIED_FACT'
    elseif r=='group_transition' then return ({['native group joined']=true,['native group left']=true})[d.phase]==true
    elseif r=='cast_observation' then
        if d.spellID~=nil and not S.Integer(d.spellID,1,1000000000) or d.castGUID~=nil and not S.Text(d.castGUID,128) then return false end
        return ({start=true,stop=true,interrupted=true,['success notification']=true,['channel start']=true,['channel stop']=true})[d.phase]==true
            and d.evidenceState==((d.spellID and d.castGUID) and 'VERIFIED_FACT' or 'PROVISIONAL_OBSERVATION')
    elseif r=='personal_source' then
        for _,key in ipairs({'playerAccepted','targetAccepted'}) do if d[key]~=nil and type(d[key])~='boolean' then return false end end
        return S.Text(d.phase,64)~=nil and (d.auctionID==nil or S.Integer(d.auctionID,1)~=nil)
    end
    return false
end
function V.Record(t,owner)
    local d=t.details;if not S.GUID(t.subject) then return false end
    if (t.subject==owner:match('/(Player%-.+)$'))~=(d.subjectEligibility=='SELF') then return false end
    local sources=ns.AthenaObservations and ns.AthenaObservations.sources[d.recordType]
    if d.recordType=='personal_source' then sources=ns.AthenaPersonalSources and ns.AthenaPersonalSources.sources end
    if not sources or not sources[t.source] then return false end
    if (d.recordType=='group_transition' or d.recordType=='personal_source') and d.subjectEligibility~='SELF' then return false end
    if d.recordType=='cast_observation' or d.recordType=='cast_observation_count' then return ns.AthenaObservations.Phase(t.source)==d.phase end
    if d.recordType=='personal_source' then
        local names={MAIL_SEND_SUCCESS='Own mail send success notice',MAIL_SUCCESS='Own mail action success notice',AUCTION_HOUSE_AUCTION_CREATED='Own auction listing created notice',
            TRADE_SHOW='Trade window observed',TRADE_ACCEPT_UPDATE='Trade acceptance state observed',TRADE_CLOSED='Trade window closed',TRADE_REQUEST_CANCEL='Trade request cancelled',
            PARTY_INVITE_REQUEST='Group invitation received',PARTY_INVITE_CANCEL='Group invitation cancelled',TAXIMAP_OPENED='Taxi map opened',TAXIMAP_CLOSED='Taxi map closed'}
        if names[t.source]~=d.phase or d.auctionID~=nil and t.source~='AUCTION_HOUSE_AUCTION_CREATED' then return false end
        if (d.playerAccepted~=nil or d.targetAccepted~=nil) and t.source~='TRADE_ACCEPT_UPDATE' then return false end
        local provisional=t.source=='TRADE_ACCEPT_UPDATE' or t.source=='PARTY_INVITE_REQUEST' or t.source=='PARTY_INVITE_CANCEL' or t.source=='AUCTION_HOUSE_AUCTION_CREATED' and not d.auctionID
        return d.evidenceState==(provisional and 'PROVISIONAL_OBSERVATION' or 'VERIFIED_FACT')
    end
    return true
end
function V.Inspection(d,guid)
    d.evidenceState='PROVISIONAL_OBSERVATION';d.interpretationVersion=1;d.sourceVersion=1
    d.subjectEligibility=ns.AthenaEnrichment.Watched(guid) and 'MANUAL_WATCH'
        or ns.AthenaSocial.Friend(guid) and 'VERIFIED_FRIEND' or 'EARNED_IMPORTANT'
    d.interpretationStatus='UNRESOLVED_INTERPRETATION'
    d.fieldReadability='Owned native inspect; known snapshot fields retained; unreadable slots/talents unknown'
    return d
end
function V.Title(e)
    local d=e.details;local r=d.recordType;local title
    if r=='pet_link' then title='Observed owner-linked pet • '..d.petGUID
    elseif r=='group_assignment' then title='Roster assignment • '..(d.assignedRole or 'role unknown')..(d.groupLeader==true and ' • group leader' or '')
    elseif r=='target_episode' then title='Observed target • '..d.relatedGUID
    elseif r=='cast_observation_count' then title='Observed '..d.phase..' notifications • Spell '..d.spellID..' × '..d.count
    elseif r=='cast_observation' then title='Cast notification • '..d.phase..(d.spellID and ' • Spell '..d.spellID or ' • spell unknown')
    elseif r=='visible_use' then title=d.mounted and 'Mounted state observed' or 'Unmounted state observed'
    elseif r=='group_transition' or r=='personal_source' then title=d.phase end
    return title and ((d.evidenceState=='PROVISIONAL_OBSERVATION' and 'Provisional • ' or '')..title) or nil
end
