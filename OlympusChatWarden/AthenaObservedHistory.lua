-- Rebuildable dossier sections, stable references, and qualified interpretations.
local _,ns=...
local H={};ns.AthenaObservedHistory=H
local A,S,C=ns.Athena,ns.ChronicleStore,ns.Chronicle
local categories={cast_observation_count='casts',pet_link='pets',group_assignment='groups',group_transition='groups',target_episode='targeting',
    cast_observation='casts',visible_use='identity',personal_source='interactions',aura_effect='effects',aura_partial='effects',
    contact_observed='interactions',contact_inspection_attempt='interactions',
    public_achievement='public',guild_member_observed='guild',friend_status='social'}
function H.Category(e)
    return categories[e.details.recordType] or (e.kind=='important_player' and 'gear')
        or (e.kind=='player_observed' and 'identity')
end
function H.Title(e)
    return ns.AthenaHistorySchema.Title(e) or ns.AthenaObservationSchema.Title(e) or ns.AthenaCombatQueries.Title(e)
end
function H.Interpret(e,version)
    -- Future interpretation is a derived result, never a mutation of the source.
    return {sourceID=e.id,observer=e.character,at=e.at,version=version or 1,title=H.Title(e),
        evidenceState=e.details.evidenceState or (e.details.recordType=='aura_partial' and 'PROVISIONAL_OBSERVATION' or 'SOURCE_QUALIFIED_LEGACY'),
        claim=e.details.scope or e.details.outcomeScope or 'Original source semantics',
        firstAt=e.details.firstAt,lastAt=e.details.lastAt,recordedAt=e.at,
        learnedSpell=false,moderation=false}
end
-- Primary phase counts only. Exceptional ability evidence and general duel
-- summaries are not added again as routine casts. Unknown notifications stay
-- separate; no rotation/completeness or inferred success claim is produced.
function H.CastCounts(events,guid)
    local out={phases={},unknown=0,sourceIDs={},coverage='Observed primary phase notifications only; not all casts or an exact rotation'}
    for _,e in ipairs(events) do local d=e.details
        if e.subject==guid and (d.recordType=='cast_observation_count' or d.recordType=='cast_observation') then
            if d.spellID then
                local phase=out.phases[d.phase] or {};out.phases[d.phase]=phase
                phase[d.spellID]=(phase[d.spellID] or 0)+(d.count or 1)
            else out.unknown=out.unknown+(d.count or 1) end
            out.sourceIDs[#out.sourceIDs+1]=e.id
        end
    end
    return out
end
function A.GetObservedHistory(consumer,guid,owner,cursor,options)
    if consumer~='intel' or not A.Enabled(consumer) or not S.GUID(guid) then return nil,'DENIED' end
    owner=owner or C.Owner();options=options or {};local c,status=S.Character(owner,false)
    if not c then S.RequestCharacter(owner);return nil,status end
    local category=S.Text(options.category,32);local key=guid..'/'..(category or 'all');local extent,offset=#c.events,0
    if cursor then
        if type(cursor)~='table' or cursor.owner~=owner or cursor.key~=key or not S.Integer(cursor.extent,0,#c.events)
            or not S.Integer(cursor.offset,0,cursor.extent) then return nil,'INVALID_CURSOR' end
        if cursor.extent>0 and c.events[cursor.extent].id~=cursor.highwater then return nil,'CURSOR_STALE' end
        extent=cursor.extent;offset=cursor.offset
    end
    local out,scanned={},0
    while offset<extent and #out<(S.Integer(options.limit,1,50) or 20) and scanned<512 do
        local e=c.events[extent-offset];offset=offset+1;scanned=scanned+1
        local kind=H.Category(e)
        if e.subject==guid and kind and (not category or kind==category) then
            out[#out+1]={id=e.id,event=e,title=H.Title(e),category=kind,at=e.at,interpretation=H.Interpret(e)}
        end
    end
    return out,offset<extent and {owner=owner,key=key,extent=extent,offset=offset,highwater=c.events[extent].id} or nil,
        {coverage='Retained observations only; no complete remote history',scanned=scanned}
end
ns.WardenDB.GetObservedHistory=A.GetObservedHistory
