-- Lazy, reference-only views over existing canonical histories. No eager alt
-- materialization and no private Chat/Shield/Relay bytes in general queries.
local _,ns=...
local A,S,C=ns.Athena,ns.ChronicleStore,ns.Chronicle
local consumers={intel=true,chronicle=true,alerts=true}
local function Permit(who) return consumers[who] and A.Enabled(who) end
local function State(owner,request)
    local c,status=S.Character(owner,false)
    if not c and request then S.RequestCharacter(owner) end
    if not c then return nil,status end
    return ns.ChronicleActivities.Request(owner)
end
local function Envelope(e)
    return {id=e.id,observationID=A.ObservationID(e),activityID=e.details and (e.details.runID or e.details.duelID),observer=e.character,
        subject=e.subject,occurredAt=e.at,receivedAt=e.at,source=e.source,kind=e.kind,
        recordType=e.details and e.details.recordType,originKind='source',scope=e.details and e.details.scope,
        localSighting=e.details and e.details.localSighting==true,retentionClass=ns.AthenaRetention.Classify(e).class,share='local-only',schema=1}
end
function A.QueryEvidence(consumer,filters,cursor)
    if not Permit(consumer) or type(filters)~='table' then return nil,'DENIED' end
    local owner=filters.owner or C.Owner();local st,status=State(owner,filters.requestArchive)
    if not st then return nil,status end
    local i=st.intelligence;local player=filters.guid and i.players[filters.guid]
    local refs=filters.guid and (player and player.evidence or {}) or i.references
    local offset=math.min(#refs,math.max(0,tonumber(cursor) or 0));local rows={};local scanned=0
    for n=#refs-offset,1,-1 do
        scanned=scanned+1;offset=offset+1
        local e=i.events[refs[n]] or st.events[refs[n]]
        if e and (not ns.AthenaHistoryGraph or ns.AthenaHistoryGraph.CanRead(consumer,e)) then rows[#rows+1]=Envelope(e) end
        if #rows>=math.min(filters.limit or 25,50) or scanned>=256 then break end
    end
    return rows,offset<#refs and offset or nil
end
function A.GetEvidence(consumer,id,owner)
    if not Permit(consumer) or not ns.SafeString(id,512) then return nil,'DENIED' end
    local st,status=State(owner or C.Owner());if not st then return nil,status end
    local e=st.events[id] or st.intelligence.events[id];if not e then return nil,'NOT_FOUND' end
    if ns.AthenaHistoryGraph and not ns.AthenaHistoryGraph.CanRead(consumer,e) then return nil,'DENIED' end
    local out=Envelope(e);out.details=A.Copy(e.details);out.location=A.Copy(e.location)
    if e.capture then out.capture=A.Copy(e.capture) end
    return out
end
local function Fresh(out,e)
    local d=e.details or {};local f=out.freshness
    f.player=math.max(f.player or 0,e.at)
    if d.localSighting then f.localEncounter=math.max(f.localEncounter or 0,e.at) end
    if d.gearObservedAt then f.gear=math.max(f.gear or 0,d.gearObservedAt) end
    if d.traitObservedAt then f.talents=math.max(f.talents or 0,d.traitObservedAt) end
end
local function BuildDossier(consumer,guid,options)
    if not Permit(consumer) or not A.GUID(guid) then return nil,'DENIED' end
    options=options or {};local out={id=guid,subject=guid,observers={},evidence={},chapters={},freshness={},gaps={},earnedTier=3,effectiveCaptureTier=3,
        coverage='Loaded validated observer archives; older archives remain available on request'}
    local seen,chapterIDs={},{};local relationship
    local chapterPage=math.max(0,math.floor(tonumber(options.chapterPage) or 0))
    local chapterSize=20;local localPrevious
    local events,streams={},{}
    local steps=0
    local function Yield() steps=steps+1;if steps%128==0 then coroutine.yield() end end
    for owner,c in pairs(S.db and S.db.characters or {}) do
        if c.storageFormat==nil and (not options.owner or owner==options.owner) then
            local st,status=State(owner)
            while not st and S.Character(owner,false)==c and Permit(consumer) do coroutine.yield();st,status=State(owner) end
            local p=st and st.intelligence.players[guid]
            if p then
                out.observers[#out.observers+1]=owner
                streams[#streams+1]={st=st,refs=p.evidence,at=1}
                local profile=c.profiles[guid]
                if owner==C.Owner() and profile and profile.personal and profile.personal.watch then out.watch=true end
                local links=st.players[guid]
                local activities=links and links.activities or {}
                for n=#activities,1,-1 do local activityID=activities[n];local a=st.byID[activityID]
                    local key=owner..'/'..activityID
                    if a and not chapterIDs[key] then
                        local chapter={id=a.id,kind=a.kind,at=a.startAt,status=a.status,observer=owner,evidence={a.evidence[1]},evidenceCount=#a.evidence,activityID=a.id}
                        chapterIDs[key]=chapter;out.chapters[#out.chapters+1]=chapter
                    end
                    Yield()
                end
            end
        end
    end
    -- Merge already-ordered source indices; a large dossier never sorts the
    -- whole account history in one frame or copies payloads into another DB.
    while true do
        local chosen,earliest
        for _,stream in ipairs(streams) do
            local id=stream.refs[stream.at];local e=id and (stream.st.events[id] or stream.st.intelligence.events[id])
            if id and not e then stream.at=stream.at+1 end
            if e and (not earliest or e.at<earliest.at or e.at==earliest.at and e.id<earliest.id) then chosen=stream;earliest=e end
        end
        if not chosen then break end
        chosen.at=chosen.at+1
        if not seen[earliest.id] then
            seen[earliest.id]=true;relationship=ns.IntelPolicy.Accumulate(relationship,earliest,guid);Fresh(out,earliest)
            local d=earliest.details or {}
            local category=ns.AthenaObservedHistory and ns.AthenaObservedHistory.Category(earliest)
            if category then
                out.observedCategories=out.observedCategories or {}
                local v=out.observedCategories[category] or {count=0,provisional=0,firstAt=earliest.at,lastAt=earliest.at,sourceID=earliest.id}
                v.count=v.count+1;v.lastAt=earliest.at;v.sourceID=earliest.id
                if d.evidenceState=='PROVISIONAL_OBSERVATION' then v.provisional=v.provisional+1 end
                out.observedCategories[category]=v
            end
            if d.localSighting then
                if localPrevious and earliest.at-localPrevious.at>=43200 then
                    out.localGaps=out.localGaps or {}
                    out.localGaps[#out.localGaps+1]={afterID=localPrevious.id,beforeID=earliest.id,afterObserver=localPrevious.character,beforeObserver=earliest.character,
                        seconds=earliest.at-localPrevious.at,label='Local observation gap',explanation='No local encounter evidence between these observations; public notices do not establish local presence'}
                    if #out.localGaps>20 then table.remove(out.localGaps,1) end
                end
                localPrevious=earliest
            end
            local family=d.recordType=='public_achievement' and 'Public notices' or d.localSighting and 'Local encounters'
            if family then
                local id=family..'/'..earliest.character..'/'..earliest.session..'/'..(family=='Public notices' and math.floor(earliest.at/86400) or earliest.location.zone or 'unknown')
                if not chapterIDs[id] then
                    local chapter={id=id,kind=family,at=earliest.at,lastAt=earliest.at,observer=earliest.character,evidence={earliest.id},evidenceCount=0}
                    chapterIDs[id]=chapter;out.chapters[#out.chapters+1]=chapter
                end
                local chapter=chapterIDs[id];if type(chapter)=='table' then chapter.lastAt=earliest.at;chapter.evidenceCount=chapter.evidenceCount+1 end
            end
            events[#events+1]=earliest;if #events>math.min(options.limit or 50,200)+1 then table.remove(events,1) end
        end
        Yield()
    end
    -- Gap rows are presentation only. Category dates are never refreshed by
    -- unrelated messages, public notices, recovery time or UI open time.
    local previous
    local first=math.max(1,#events-math.min(options.limit or 50,200)+1)
    for n=first,#events do local e=events[n]
        if previous and e.at-previous.at>=43200 then out.gaps[#out.gaps+1]={afterID=previous.id,beforeID=e.id,seconds=e.at-previous.at,
            label='Observation gap',explanation='No additional observations recorded by your installation'} end
        out.evidence[#out.evidence+1]=Envelope(e);previous=e
    end
    if relationship then
        out.earnedTier=relationship.earnedTier;out.effectiveCaptureTier=relationship.tier;out.reason=relationship.reason
        if out.earnedTier==1 then
            relationship.shared=#out.observers>1
            ns.IntelPolicy.AcceptShared(guid,relationship)
            A.RememberRelationship(relationship.promotionOwner or events[#events] and events[#events].character,guid,relationship)
        end
    end
    if A.EarnedTier(guid)==1 and out.earnedTier~=1 then out.earnedTier=1;out.relationshipFromIndex=true;out.reason='Previously verified relationship index; older evidence remains available on request' end
    if A.CachedCaptureTier(guid)==1 then out.effectiveCaptureTier=1 end
    if out.watch then out.effectiveCaptureTier=1 end
    if ns.AthenaEnrichment then out.priorityOrigins=ns.AthenaEnrichment.Origins(guid);if out.priorityOrigins.verifiedFriend then out.effectiveCaptureTier=1 end end
    -- Merge every loaded observer before applying a page limit. These are
    -- disposable references/counts, never copies of historical payloads.
    local function Before(a,b) return a.at>b.at or a.at==b.at and (a.observer..'/'..a.id)<(b.observer..'/'..b.id) end
    -- Cooperative merge sort: multi-year histories must not introduce a single
    -- unbounded native table.sort into the query frame.
    local ordered=out.chapters;local width=1
    while width<#ordered do
        local merged={}
        for lo=1,#ordered,2*width do
            local left,right=lo,lo+width;local leftEnd=math.min(lo+width-1,#ordered);local rightEnd=math.min(lo+2*width-1,#ordered)
            while left<=leftEnd or right<=rightEnd do
                if left<=leftEnd and (right>rightEnd or Before(ordered[left],ordered[right])) then merged[#merged+1]=ordered[left];left=left+1
                else merged[#merged+1]=ordered[right];right=right+1 end
                Yield()
            end
        end
        ordered=merged;width=width*2
    end
    out.chapters=ordered
    out.chapterCount=#out.chapters;out.chapterPage=chapterPage
    out.hasNewerChapters=chapterPage>0;out.hasOlderChapters=(chapterPage+1)*chapterSize<out.chapterCount
    local page={};for n=chapterPage*chapterSize+1,math.min((chapterPage+1)*chapterSize,#out.chapters) do page[#page+1]=out.chapters[n] end
    out.chapters=page
    out.promotion=relationship and relationship.promotionID and {id=relationship.promotionID,observer=relationship.promotionOwner,at=relationship.promotionAt,reason=relationship.reason}
    local context=A.GetPlayerContext('intel',guid,'protection')
    if context then out.protection=context;out.freshness.chat=context.lastFilteredAt;out.freshness.shield=context.lastProtectionAt end
    return out
end
local dossierCache,dossierJobs={},{}
local dossierFrame
function A.ReleaseDossiers()
    dossierJobs={};dossierCache={};A.queryVersions={}
    if dossierFrame then dossierFrame:SetScript('OnUpdate',nil) end
end
function A.PumpQueries()
    local job=dossierJobs[1];if not job then if dossierFrame then dossierFrame:SetScript('OnUpdate',nil) end;return end
    if not A.Enabled('intel') then A.ReleaseDossiers();return end
    local start=ns.WardenPerformance.Now()
    for _=1,16 do
        local ok,result=coroutine.resume(job.thread)
        if not ok or coroutine.status(job.thread)=='dead' then
            if ok and result then dossierCache[job.key]={value=result,revision=job.revision};A.queryRevision=(A.queryRevision or 0)+1;else A.errors=A.errors+1 end
            table.remove(dossierJobs,1);return
        end
        if start and (ns.WardenPerformance.Now() or start)-start>=2 then break end
    end
end
function A.GetDossier(consumer,guid,options)
    if not Permit(consumer) or not A.GUID(guid) then return nil,'DENIED' end
    A.queryVersions=A.queryVersions or {}
    if not A.queryVersions[guid] then
        local n=0;for _ in pairs(A.queryVersions) do n=n+1 end
        if n>=2 then A.ReleaseDossiers() end
        A.queryVersions[guid]=0
    end
    local profile=C.Profile(guid)
    options=options or {};local revision=tostring(A.queryVersions[guid])..':'..tostring(S.materializationRevision or 0)..':'..tostring(profile and profile.personal and profile.personal.watch or false)
    local key=guid..'/'..(options.owner or '*')..'/'..tostring(options.limit or 50)..'/'..tostring(options.chapterPage or 0)
    local cached=dossierCache[key]
    if cached and cached.revision==revision then return A.Copy(cached.value) end
    for _,job in ipairs(dossierJobs) do if job.key==key then return cached and A.Copy(cached.value) or nil,'INDEXING' end end
    if #dossierJobs>=2 then return nil,'BUSY' end
    local n=0;for _ in pairs(dossierCache) do n=n+1 end;if n>=2 then dossierCache={} end
    dossierJobs[#dossierJobs+1]={key=key,revision=revision,thread=coroutine.create(function() return BuildDossier(consumer,guid,options) end)}
    dossierFrame=dossierFrame or CreateFrame('Frame');dossierFrame:SetScript('OnUpdate',A.PumpQueries)
    return cached and A.Copy(cached.value) or nil,'INDEXING'
end
-- Timeline is the character's chronology, not a technical snapshot browser or
-- the curated Highlights page. Real changes/receipts remain here even when
-- they are too ordinary for Highlights. This selection never changes storage.
local timelineTitles={quest_turnin='Quest completed',quest_accepted='Quest accepted',quest_removed='Quest removed from log',level_change='Level gained',skill_change='Skill progress',achievement_earned='Achievement earned',spell_learned='Ability learned',location='Journey continued',instance_enter='Instance entered',instance_exit='Instance left',player_death='Character death',group_roster='Group changed',equipment_change='Equipment changed'}
local milestones={quest_turnin=true,quest_accepted=true,quest_removed=true,level_change=true,skill_change=true,achievement_earned=true,spell_learned=true,location=true,instance_enter=true,instance_exit=true,
    player_death=true,group_roster=true,gear_change=true,equipment_change=true}
local nativeMilestones={item_received=true,quest_accepted=true,quest_removed=true,quest_item_received=true,quest_currency_received=true,
    recipe_learned=true,native_craft_result=true,reputation_standing_changed=true,barber_choices_applied=true,
    collection_added=true,encounter_started=true,encounter_ended=true,boss_kill_event=true,duel_session_start=true,duel_session_result=true,pvp_match_complete=true}
function A.GetCharacterTimeline(consumer,owner,cursor,limit)
    if consumer~='chronicle' or not Permit(consumer) then return nil,'DENIED' end
    owner=owner or C.Owner();local c,status=S.Character(owner,false)
    if not c then S.RequestCharacter(owner);return nil,status end
    local offset=math.min(#c.events,math.max(0,tonumber(cursor) or 0));local rows={};local scanned=0
    while offset<#c.events and #rows<math.min(limit or 12,50) and scanned<512 do
        local e=c.events[#c.events-offset];offset=offset+1;scanned=scanned+1
        local d=e.details or {};local include=milestones[e.kind] or e.kind=='native_event' and nativeMilestones[d.recordType]
        if e.subject and e.subject~=owner:match('/(Player%-.+)$') then include=false end
        if e.kind=='group_roster' and #(d.members or {})==0 then include=false end
        if include then
            local row=Envelope(e);row.title=timelineTitles[e.kind] or timelineTitles[d.recordType] or ns.RecordingUI.Title(e) or 'Recorded character event'
            if e.kind=='level_change' then row.title='Reached level '..tostring(d.after)
            elseif e.kind=='skill_change' then row.title=(d.skill or 'Skill')..' • '..tostring(d.after)
            elseif e.kind=='native_event' and d.recordType=='duel_session_result' then
                row.title=({win='Duel won',loss='Duel lost'})[d.result] or 'Duel result recorded • outcome unknown'
            end
            if d.name then row.title=row.title..' • '..d.name end
            if d.questID then row.title=row.title..' • Quest '..d.questID elseif d.achievementID then row.title=row.title..' #'..d.achievementID end
            row.zone=e.location and e.location.zone;row.event=e -- page-scoped original reference, never saved
            rows[#rows+1]=row
        end
    end
    return rows,offset<#c.events and offset or nil
end
-- Guild context is a projection of one original source, never attendance proof.
function A.GetGuildContext(consumer,id,owner)
    local e,why=A.GetEvidence(consumer,id,owner);if not e then return nil,why end
    local d=e.details or {};if e.kind~='group_roster' or not d.guildName or not d.guildRealm then return nil,'NO_VERIFIED_AFFILIATION' end
    return {version=1,guildId=d.guildRealm..'/'..d.guildName,guildEventId='guild-context:'..e.id,contextId=e.activityID or e.id,
        status='guild-associated candidate',sourceID=e.id,at=e.occurredAt,guildName=d.guildName,guildRank=d.guildRank,
        orgAffiliation=d.orgAffiliation,participants=A.Copy(d.guildMembers or {}),role='group-member',official=false}
end
ns.WardenDB.QueryEvidence=A.QueryEvidence;ns.WardenDB.GetEvidence=A.GetEvidence;ns.WardenDB.GetDossier=A.GetDossier
ns.WardenDB.GetCharacterTimeline=A.GetCharacterTimeline
-- Complete typed retrieval, independent of Timeline/Highlights selection. A
-- page pins the append-only extent so new arrivals cannot repeat/skip old rows.
local function HistoryPage(consumer,owner,cursor,options,guild)
    if consumer~='chronicle' or not Permit(consumer) then return nil,'DENIED' end
    owner=owner or C.Owner();options=options or {}
    local c,status=S.Character(owner,false);if not c then S.RequestCharacter(owner);return nil,status end
    local direction=options.direction=='oldest' and 'oldest' or 'newest'
    local family=S.Text(options.family,128);local search=S.Text(options.search,128)
    local key=(guild and 'guild' or 'personal')..'/'..direction..'/'..(family or '')..'/'..(search or '')
    local extent,offset=#c.events,0
    if cursor~=nil then
        if type(cursor)~='table' or cursor.owner~=owner or cursor.key~=key or not S.Integer(cursor.extent,0,#c.events)
            or not S.Integer(cursor.offset,0,cursor.extent) then return nil,'INVALID_CURSOR' end
        if cursor.extent>0 and c.events[cursor.extent].id~=cursor.highwater then return nil,'CURSOR_STALE' end
        extent=cursor.extent;offset=cursor.offset
    end
    local rows={};local scanned=0;local own=owner:match('/(Player%-.+)$')
    while offset<extent and #rows<math.min(S.Integer(options.limit,1,50) or 20,50) and scanned<512 do
        local n=direction=='oldest' and offset+1 or extent-offset
        local e=c.events[n];offset=offset+1;scanned=scanned+1
        local d=e.details or {};local kind=d.recordType or e.capture and e.capture.family or e.kind
        local include=guild and (d.guildAssociated==true or kind=='guild_affiliation' or kind=='guild_member_observed'
            or e.kind=='group_roster' and d.guildName and d.guildRealm)
            or not guild and (not e.subject or e.subject==own)
        if include and (not ns.AthenaHistoryGraph or ns.AthenaHistoryGraph.CanRead(consumer,e)) and (not family or kind==family or e.kind==family) then
            local title=ns.RecordingUI.Title(e) or kind
            local hay=title..' '..kind..' '..e.source..' '..(d.guildName or '')..' '..(d.guildRank or '')..' '..(d.name or '')..' '..tostring(d.itemID or d.questID or '')
            if not search or hay:lower():find(search:lower(),1,true) then
                local row=Envelope(e);row.title=title;row.family=kind;row.zone=e.location.zone;row.event=e
                if kind=='item_received' then row.title='Item received • '..d.itemID..' × '..d.quantity
                elseif kind=='guild_affiliation' then row.title=(d.baseline and 'Guild affiliation recorded' or not d.after and 'Guild affiliation ended' or 'Guild affiliation changed')..' • '..(d.guildName or d.guildBefore or 'No guild')..(d.guildRank and ' • '..d.guildRank or '')
                elseif kind=='guild_member_observed' then row.title='Guild member observed • '..(d.guildName or '') end
                if guild then
                    row.guildName=d.guildName or d.guildBefore;row.guildRealm=d.guildRealm or d.guildBeforeRealm
                    row.guildRank=d.guildRank;row.baseline=d.baseline;row.official=false
                    row.association=d.guildMajority==true and 'measured guild majority' or d.guildAssociated and 'guild associated'
                        or kind=='guild_affiliation' and (d.baseline and 'affiliation baseline; join date unknown' or 'observed affiliation change')
                        or kind=='guild_member_observed' and 'GUID roster affiliation; join date unknown' or 'historical guild roster context'
                    row.groupSize=d.guildGroupSize;row.unknownMembers=d.guildContextUnknown
                    row.role='observed group context; no inferred attendance, kill or official event'
                end
                rows[#rows+1]=row
            end
        end
    end
    return rows,offset<extent and {owner=owner,key=key,extent=extent,offset=offset,highwater=c.events[extent].id} or nil,
        {extent=extent,scanned=scanned,firstRecordedAt=c.events[1] and c.events[1].at,coverage='First authorized observation onward; unknown prior life is not reconstructed'}
end
function A.GetCharacterHistory(consumer,owner,cursor,options) return HistoryPage(consumer,owner,cursor,options,false) end
function A.GetGuildHistory(consumer,owner,cursor,options) return HistoryPage(consumer,owner,cursor,options,true) end
ns.WardenDB.GetCharacterHistory=A.GetCharacterHistory;ns.WardenDB.GetGuildHistory=A.GetGuildHistory
