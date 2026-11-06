-- Typed, permission-scoped adapters. Operational alerts/chat/Relay are not sources.
local _,ns=...
local R={VERSION=1};ns.AthenaStoryContributions=R
R.policy={
    friend_status={life=true,linkedBook='PEOPLE',scope='LOCAL_HISTORY',requires='dated GUID friend transition',correction='invalidate source'},
    guild_affiliation={life=true,linkedBook='GUILD',scope='LOCAL_HISTORY',requires='own dated affiliation',correction='invalidate source'},
    guild_company={life=true,linkedBook='GUILD',scope='LOCAL_HISTORY',requires='at-event participant GUIDs',correction='invalidate source'},
    historical_incident={life=true,linkedBook='PROTECTION',scope='LOCAL_PRIVATE',requires='historical consent + reader opt-in + source module',correction='withdraw dependent assessment',placement='brief own-action context'},
    signal_sighting={life=true,linkedBook='SIGHTING',scope='LOCAL_HISTORY',requires='prospective consent + GUID + native target/mouseover + contemporaneous list match',correction='retain dated neutral fact only'},
    raw_chat={life=false},private_note={life=false},relay_report={life=false},operational_alert={life=false}
}
R.fields={'baseline','race','faction','class','raceID','classID','guildName','guildRealm','guildBefore','guildBeforeRealm','ownerModule','method','scope','sourceActionID',
    'cause1','cause2','cause3','correctedSourceID','firstAt','lastAt','activeSourceCount','correctedDependencyCount','origin','via',
    'guildAssociated','guildContextGuildMembers','guildContextMembers','guildContextKnown','guildContextSame','guildContextUnknown'}
function R.Enabled(kind)
    local d=ns.DB or {};local modules=ns.Modules
    if kind=='social' then return d.journalSocial~=false and (not modules or modules.Enabled('intel')) end
    if kind=='protections' then return d.journalProtections==true and d.historicalIncidentConsent==1 and (not modules or modules.Enabled('shield') or modules.Enabled('chat')) end
    if kind=='sightings' then return d.journalSightings==true and d.journalCaptureSightings==true and (not modules or modules.Enabled('alerts')) end
    return false
end
function R.PermissionSignature() return tostring(R.Enabled('social'))..'/'..tostring(R.Enabled('protections'))..'/'..tostring(R.Enabled('sightings'))..'/'..tostring(not ns.Modules or ns.Modules.Enabled('chat'))..'/'..tostring(not ns.Modules or ns.Modules.Enabled('shield'))..'/'..tostring(ns.AthenaIncidents and ns.AthenaIncidents.diagnostics.corrected or 0) end
function R.Signature()
    return R.PermissionSignature()..'/'..tostring(ns.AthenaWorldKnowledge and ns.AthenaWorldKnowledge.Signature())..'/'..tostring(ns.DB and ns.DB.journalNarration or 'Natural Fantasy')..'/'..tostring(not ns.DB or ns.DB.journalLore~=false)..'/'..tostring(ns.DB and ns.DB.journalEditionRevision or 0)
end
function R.Visible(family,provider)
    local enabled=provider and provider.StoryContent and function(k) return provider:StoryContent(k) end or R.Enabled
    if family=='friend_status' or family=='guild_affiliation' or family=='guild_member_observed' then return enabled('social') end
    if family=='historical_incident' or family=='incident_correction' then return enabled('protections') end
    if family=='signal_sighting' then return enabled('sightings') end
    return true
end
function R.PrivateRow(row,owner)
    if row.observer~=owner or row.share~='PRIVATE_LOCAL_ONLY' then return end
    local d=row.details or {};if d.recordType~='historical_incident' and d.recordType~='incident_correction' then return end
    if d.recordType=='historical_incident' and (d.ownerModule~='shield' and d.ownerModule~='chat' or ns.Modules and not ns.Modules.Enabled(d.ownerModule)) then return end
    local details={recordType=d.recordType,ownerModule=d.ownerModule,method=d.method,count=d.count,
        activeSourceCount=row.activeSourceCount,correctedDependencyCount=row.correctedDependencyCount or 0}
    return {evidenceRef=row.ref,sourceRecordRef=row.id,observer=owner,observedAt=row.at,family=d.recordType,source='control',
        details=details,location={},storyPrivateProjection=true,privacy='LOCAL_PRIVATE'}
end
function R.Claims(story,facts,claim,provider)
    for _,e in ipairs(facts) do local d=e.details or {};local family=e.family
        if family=='friend_status' and e.subjectGUID and type(d.after)=='boolean' then
            claim(story,'verified_friend_status',{guid=e.subjectGUID,after=d.after,baseline=d.baseline==true},{e.evidenceRef},'Dated native character-friend status; no emotional relationship inferred')
        elseif family=='guild_affiliation' and type(d.after)=='boolean' then
            claim(story,'own_guild_affiliation',{after=d.after,baseline=d.baseline==true,name=d.guildName or d.guildBefore},{e.evidenceRef},'Own affiliation observed at this date; no group participation implied')
        elseif family=='guild_member_observed' and e.subjectGUID and d.guildName then
            claim(story,'observed_guild_member',{guid=e.subjectGUID,name=d.guildName},{e.evidenceRef},'Guild roster observation; not raid attendance')
        elseif R.Visible('guild_affiliation',provider) and d.guildAssociated==true and type(d.guildContextGuildMembers)=='table' and #d.guildContextGuildMembers>0 and (family=='group_roster' or family=='encounter_started' or family=='encounter_ended') then
            claim(story,'guild_company',{name=d.guildName,count=#d.guildContextGuildMembers},{e.evidenceRef},'Same-guild GUIDs verified in this event context; not the whole guild')
        elseif family=='historical_incident' and e.storyPrivateProjection and (d.ownerModule=='shield' or d.ownerModule=='chat') then
            claim(story,'private_protection',{module=d.ownerModule,corrected=(d.correctedDependencyCount or 0)>0},{e.evidenceRef},'Own local protection/filter action only; no text, identity or misconduct conclusion')
        elseif family=='incident_correction' and e.storyPrivateProjection then
            claim(story,'private_correction',true,{e.evidenceRef},'Source decision corrected; original retained')
        elseif family=='signal_sighting' and e.subjectGUID and d.origin=='OLYMPUS_BOARD_MATCH_AT_OBSERVATION' and (d.via=='target' or d.via=='mouseover') then
            claim(story,'verified_signal_sighting',{guid=e.subjectGUID,via=d.via},{e.evidenceRef},'Historical native sighting and contemporaneous list match; not current list status or an accusation')
        end
    end
end
function R.Render(s)
    local out={};local text=ns.AthenaStoryPlanner.Text
    for _,c in ipairs(s.factualClaims) do local v=c.value;local line
        if c.claimType=='verified_friend_status' then line=v.after and (v.baseline and 'A player was present on my verified friend roster at this point in my journey.' or 'A player joined my verified friend roster in this chapter.') or 'A player was no longer on my verified friend roster; the reason is untold.'
        elseif c.claimType=='own_guild_affiliation' then line=v.after and ((v.baseline and 'At this point, I belonged to ' or 'My guild affiliation changed to ')..text(v.name,'a guild')..'.') or ('My affiliation with '..text(v.name,'the guild')..' ended. The record does not tell why.')
        elseif c.claimType=='guild_company' then line='This part of the adventure included '..v.count..' verified member'..(v.count==1 and '' or 's')..' of '..text(v.name,'my guild')..' in the recorded company.'
        elseif c.claimType=='observed_guild_member' then line='A dated guild roster places a player in '..text(v.name,'the guild')..'; it does not place them in my expedition.'
        elseif c.claimType=='private_protection' then line=v.corrected and 'My Fireside retained a local protection action whose source was subsequently corrected. Its earlier assessment is withdrawn.' or v.module=='chat' and 'My Fireside applied local message filtering. These pages retain only that action, without the messages or a judgment about their senders.' or 'My Fireside applied a local protection action. The record describes that action and makes no judgment about another player.'
        elseif c.claimType=='private_correction' then line='A source decision was corrected. The earlier original remains preserved, without carrying its withdrawn interpretation forward.'
        elseif c.claimType=='verified_signal_sighting' then line='A dated player sighting through '..v.via..' matched a profile on Olympus’s list at that moment. The sighting establishes neither misconduct nor a present listing.'
        elseif c.claimType=='private_conversation_observed' then line='An eligible private conversation was preserved during this passage. Its words remain in Conversations & Memories and do not establish any asserted accomplishment.' end
        if line then out[#out+1]={text=line,claim=c} end
    end
    return out
end
