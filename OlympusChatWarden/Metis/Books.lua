-- Reading paths over one permitted source index. Nothing is saved or collected.
local _,ns=...
local T={VERSION=13,MAX_EPISODES=24,HARD_EPISODES=48,PERIOD=14*86400};ns.AthenaStoryThreads=T
local function ID(owner,kind,key) return 'thread/1/'..#owner..':'..owner..'/'..kind..'/'..#key..':'..key end
T.ID=ID
local function StableZone(key) return type(key)=='string' and (key:match('^ui%-map:%d+$') or key:match('^native%-world:%d+$')) and key or nil end
local function Context(n)
    local p=n.place or {};if not p.instanceID then return end
    return tostring(p.instanceType or n.type)..'/id:'..p.instanceID..'/difficulty:'..tostring(p.difficultyID or 'unknown')
end
local function Tick(index) if not index.provider:Allowed() then error('DENIED') end;coroutine.yield() end
function T.Valid(t,index) return type(t)=='table' and t.version==T.VERSION and t.owner==index.owner and t.serial==index.serial and t.index==index end
function T.Build(index)
    local result={version=T.VERSION,owner=index.owner,serial=index.serial,index=index,threads={},byID={},episodes={},volumes={},chronology={},status='INDEXING'}
    local function Thread(kind,key,title,collection)
        local id=ID(index.owner,kind,key);local t=result.byID[id]
        if not t then t={id=id,owner=index.owner,type=kind,contextKey=key,title=title,collection=collection,episodeIds={},volumeIds={},relatedThreadIds={},status='ONGOING',indexVersion=T.VERSION};result.byID[id]=t;result.threads[#result.threads+1]=t end
        return t
    end
    local life=Thread('LIFE','life','Complete Chronicle','archive');result.lifeId=life.id
    local journey=Thread('LIFE','journey','The Journey — Leveling & Zone Stories','life');result.journeyId=journey.id
    local battles=Thread('PVP','pvp','Battlegrounds & PvP','pvp');result.battlesId=battles.id
    local expeditions=Thread('EXPEDITIONS','expeditions','Dungeons & Raids','expeditions');result.expeditionsId=expeditions.id
    local function Join(t,n,role)
        local e=result.episodes[n.storyId];if e.membershipSet[t.id] then return end
        e.membershipSet[t.id]=true;e.memberships[#e.memberships+1]=t.id;t.episodeIds[#t.episodeIds+1]=n.storyId
        t.firstObservedAt=t.firstObservedAt or n.firstObservedAt;t.lastObservedAt=math.max(t.lastObservedAt or 0,n.lastObservedAt)
        if role=='primary' then e.primaryThreadId=t.id end
    end
    -- A BG visit encloses matches, rather than creating an extra match itself.
    local matched={}
    for i,n in ipairs(index.nodes) do if n.type=='BATTLEGROUND_MATCH' then
        for j,ref in ipairs(n.factRefs) do local f=index.byRef[ref];for _,context in ipairs(f and f.contexts or {}) do
            local parent=index.byActivity[context];if parent and parent.type=='BATTLEGROUND_VISIT' then matched[parent.storyId]=true end
        end;if j%64==0 then Tick(index) end end
    end;if i%64==0 then Tick(index) end end
    local levelCursor,level=1,nil;local firstExperiences={};local wonBosses={}
    for i=#index.nodes,1,-1 do local n=index.nodes[i];local anchor=index.byRef[n.sourceRef]
        while (index.facts or {})[levelCursor] and index.facts[levelCursor].observedAt<=n.firstObservedAt do
            local f=index.facts[levelCursor]
            if f.family=='character_snapshot' or f.family=='character_detail' then level=f.details.level or level
            elseif f.family=='level_change' then level=f.details.after or level end
            levelCursor=levelCursor+1
        end
        if n.type~='SAGA' and not n.suppressed and not matched[n.storyId] and anchor then
            local e={storyId=n.storyId,node=n,role='moment',memberships={},membershipSet={},anchorRefs={n.sourceRef},owner=index.owner,coverage='Dated chapters; intervening activity is unknown'}
            result.episodes[n.storyId]=e;result.chronology[#result.chronology+1]=n.storyId;n.lifeOrdinal=#result.chronology;if ns.AthenaNarrativeScenes.Admit(index,n) then Join(life,n) end
            local zone=StableZone(n.zoneKey) or n.mapID and 'ui-map:'..n.mapID
            -- Never infer a world zone around an instance from its name.
            if zone and n.type~='BATTLEGROUND_MATCH' and n.type~='BATTLEGROUND_VISIT' then
                Join(Thread('ZONE',zone,ns.AthenaStoryPlanner.Text(n.place and n.place.zone,'An unnamed place')..' — A Chronicle','places'),n)
            end
            if not n.private then
                local guids,set={},{};for guid in pairs(n.participants or {}) do set[guid]=true end;for guid in pairs(n.connections or {}) do set[guid]=true end;for guid in pairs(set) do guids[#guids+1]=guid end;table.sort(guids)
                for _,guid in ipairs(guids) do
                    local label='A recorded companion';local aliases=index.aliases[guid] or {}
                    for _,a in ipairs(aliases) do if a.at<=n.lastObservedAt then label=ns.AthenaStoryPlanner.Text(a.name,label) end end
                    Join(Thread('PERSON',guid,label..' — Recorded Connections','people'),n)
                end
            end
            for _,ref in ipairs(n.factRefs) do local f=index.byRef[ref];local d=f and f.details or {}
                if d.guildName and (f.family=='guild_affiliation' or f.family=='guild_member_observed' or d.guildAssociated==true) and ns.AthenaStoryContributions.Visible('guild_affiliation',index.provider) then
                    local key=d.guildName..'/'..tostring(d.guildRealm or '')
                    Join(Thread('GUILD',key,ns.AthenaStoryPlanner.Text(d.guildName,'Guild')..' — Chapters','guild'),n)
                end
                if f and (f.family=='historical_incident' or f.family=='incident_correction') then Join(Thread('WATCH','watch','The Watch','watch'),n);Join(Thread('PROTECTION','private','Private Protections','protections'),n,'primary') end
                if f and f.family=='signal_sighting' then Join(Thread('WATCH','watch','The Watch','watch'),n);Join(Thread('SIGHTING','sightings','Historical Sightings','sightings'),n,'primary') end
            end
            local completeCategory=({RAID_RUN='raids',INSTANCE_VISIT='dungeons',BATTLEGROUND_MATCH='battlegrounds',BATTLEGROUND_VISIT='battlegrounds',DUEL='duels',WORLD_PVP='world'})[n.type]
            if completeCategory then Join(Thread('CHAPTERS',completeCategory,({raids='All Raid Chapters',dungeons='All Dungeon Chapters',battlegrounds='All Battleground Chapters',duels='Duels & PvP',world='World Events'})[completeCategory],completeCategory),n) end
            local family={};for j,ref in ipairs(n.factRefs) do local f=index.byRef[ref];if f then family[f.family]=true end;if j%128==0 then Tick(index) end end
            if n.type=='DUEL' or n.type=='BATTLEGROUND_MATCH' or n.type=='BATTLEGROUND_VISIT' or n.type=='WORLD_PVP' then
                Join(Thread('PVP','pvp','My PvP Chronicle','pvp'),n,'primary')
                if n.type=='DUEL' then Join(Thread('DUEL','duels','Duels','pvp'),n)
                elseif n.type=='WORLD_PVP' then Join(Thread('WORLD_PVP','world','World Encounters','pvp'),n)
                else local key=Context(n);if key then Join(Thread('BATTLEGROUND',key,ns.AthenaStoryPlanner.Text(n.place.instanceName or n.place.zone,'Battleground')..' — Battles','pvp'),n) end end
            elseif n.type=='RAID_RUN' or n.type=='INSTANCE_VISIT' then
                Join(expeditions,n)
                local kind=n.type=='RAID_RUN' and 'RAID' or 'DUNGEON';local key=Context(n)
                Join(Thread(kind,kind=='RAID' and 'all-raids' or 'all-dungeons',kind=='RAID' and 'Raids & Campaigns' or 'Dungeon Expeditions','adventures'),n)
                if key then Join(Thread(kind,key,ns.AthenaStoryPlanner.Text(n.place.instanceName,'An expedition')..' — Expeditions','adventures'),n,'primary') end
            end
            -- The primary Journey follows outdoor growth and zone/quest plots.
            -- Quest work continues after 60; entering an instance does not
            -- erase that plot. Standalone match/run records have their own book.
            local isQuest=family.quest_accepted or family.quest_turnin or family.quest_objective or family.quest_removed
            local special=n.type=='RAID_RUN' or n.type=='INSTANCE_VISIT' or n.type=='DUEL' or n.type=='BATTLEGROUND_MATCH' or n.type=='BATTLEGROUND_VISIT' or n.type=='WORLD_PVP'
            if special then
                local key=Context(n) or n.type;local first=not firstExperiences[key];firstExperiences[key]=true
                local significant=false
                for _,ref in ipairs(n.factRefs) do local f=index.byRef[ref];local d=f and f.details or {}
                    if d.success==1 and d.encounterID and not wonBosses[d.encounterID] then wonBosses[d.encounterID]=true;significant=true end
                    if d.lowHealthObserved and type(d.minHealthPercent)=='number' and d.minHealthPercent<=20 or (d.deaths or 0)>0 then significant=true end
                end
                if first or significant then Join(journey,n) end
            end
            if ns.AthenaNarrativeScenes.Admit(index,n) and (not special or isQuest) and (not level or level<60 or isQuest) then Join(journey,n) end
            if family.quest_accepted or family.quest_observed or family.quest_turnin or family.quest_objective or family.quest_removed then
                Join(Thread('QUESTING','quests','Questing Journey','adventures'),n,n.type=='QUESTING' and 'primary' or nil);Join(Thread('CHAPTERS','questing','Questing Chapters','questing'),n)
            end
            if family.level_change or family.achievement_earned or family.equipment_change or family.spell_learned or family.skill_change then
                Join(Thread('PROGRESSION','growth','Milestones & Growth','adventures'),n,n.type=='PROGRESSION' and 'primary' or nil)
            end
            if n.type=='FIELD_ACTIVITY' and ns.AthenaNarrativeScenes.Admit(index,n) then
                Join(Thread('FIELD_ACTIVITY','field','Adventures Along the Way','adventures'),n,'primary')
            end
            e.primaryThreadId=e.primaryThreadId or life.id
        end
        if i%32==0 then Tick(index) end
    end
    -- Related quest steps appear in expedition books too, without moving or
    -- duplicating their evidence. Only explicit endpoint objectives or records
    -- already attached to a run qualify; geographical proximity is insufficient.
    local questThreads={};local questIDs={};local questNodes,questTitles={},{}
    for _,f in ipairs(index.facts or {}) do if f.family=='quest_observed' and f.details.title then questTitles[f.details.questID]=f.details.title end end
    for i,sid in ipairs(result.chronology) do local n=result.episodes[sid].node;local seen={}
        for _,ref in ipairs(n.factRefs) do local f=index.byRef[ref];local id=f and f.details.questID
            if id and not seen[id] then seen[id]=true;questNodes[id]=questNodes[id] or {};questNodes[id][#questNodes[id]+1]=n end
        end
        if i%64==0 then Tick(index) end
    end
    for _,t in ipairs(result.threads) do if t.collection=='adventures' and (t.type=='DUNGEON' or t.type=='RAID') or t==expeditions then
        questThreads[#questThreads+1]=t
        local places={};for _,sid in ipairs(t.episodeIds) do local p=result.episodes[sid].node.place;if p and p.instanceID then places[p.instanceID]=p end end
        local wanted={}
        local scanned=0
        for id in pairs(questNodes) do
            local q=ns.AthenaWorldKnowledge.GetQuest(id)
            if q and questTitles[id]==q.title then for _,place in pairs(places) do if ns.AthenaQuestContext.ExpeditionTarget(q,place) then wanted[id]=true end end end
            scanned=scanned+1;if scanned%32==0 then Tick(index) end
        end
        -- Expand the verified predecessors of a directly associated objective.
        -- These links identify a reading path, never an unobserved completion.
        local todo={};for id in pairs(wanted) do todo[#todo+1]=id end;local pos=1
        while pos<=#todo and pos<=512 do local id=todo[pos];pos=pos+1
            for _,prior in ipairs(ns.AthenaQuestChains.Previous(id)) do if not wanted[prior] then wanted[prior]=true;todo[#todo+1]=prior end end
        end
        questIDs[t.id]=wanted
    end end
    for _,t in ipairs(questThreads) do
        for id in pairs(questIDs[t.id]) do for _,n in ipairs(questNodes[id] or {}) do Join(t,n) end end
        table.sort(t.episodeIds,function(a,b) local x,y=result.episodes[a].node,result.episodes[b].node;return x.firstObservedAt<y.firstObservedAt or x.firstObservedAt==y.firstObservedAt and a<b end)
        Tick(index)
    end
    -- Stable volume IDs derive from the first episode, never mutable offsets.
    for _,t in ipairs(result.threads) do
        local v
        for i,id in ipairs(t.episodeIds) do local e=result.episodes[id];local n=e.node
            local chapter=index.narrative.chapterKeys[id]
            -- Prefer a real chapter turn once the reading window is full.
            -- A hard presentation cap bounds hydration without splitting the
            -- accepted history or claiming an invented literary turning point.
            if not v or #v.episodeIds>=T.HARD_EPISODES or #v.episodeIds>=T.MAX_EPISODES and (not chapter or chapter.id~=v.lastChapter) then
                local vid=t.id..'/volume/'..#id..':'..id
                v={id=vid,threadId=t.id,ordinal=#t.volumeIds+1,firstAt=n.firstObservedAt,lastAt=n.lastObservedAt,episodeIds={},sourceRefs={},partialCoverage=true,role='development'}
                t.volumeIds[#t.volumeIds+1]=vid;result.volumes[vid]=v
            end
            if t.type=='LIFE' and chapter and (t==journey or not chapter.volumeId) then chapter.volumeId=v.id end
            v.lastChapter=chapter and chapter.id
            v.episodeIds[#v.episodeIds+1]=id;v.sourceRefs[#v.sourceRefs+1]=n.sourceRef;v.lastAt=math.max(v.lastAt,n.lastObservedAt)
            if i%64==0 then Tick(index) end
        end
        t.episodeCount=#t.episodeIds;Tick(index)
    end
    -- Related links are resolved for the selected chapter, avoiding a quadratic
    -- global thread-to-thread adjacency graph for a ten-year archive.
    result.status='READY';return result
end
-- Resolve old DEV7 reading windows to the nearest retained narrative anchor.
-- This is view compatibility only; saved bookmarks and source IDs are untouched.
function T.ResolveVolume(index,thread,id)
    local ts=index.threads
    if id and ts.volumes[id] and ts.volumes[id].threadId==thread.id then return ts.volumes[id] end
    local old=id and id:match('/volume/%d+:(.+)$');local node=old and index.byStory[old]
    if node then
        for _,vid in ipairs(thread.volumeIds) do local v=ts.volumes[vid];if v.lastAt>=node.firstObservedAt then return v end end
    end
    return ts.volumes[thread.volumeIds[#thread.volumeIds]]
end
function T.Window(index,cursor)
    local t=index.threads
    if not index.provider:Allowed() then return nil,'DENIED' end
    if not T.Valid(t,index) then return nil,'UNAVAILABLE' end
    local thread=t.byID[cursor.threadId];if not thread then return nil,'UNAVAILABLE' end
    local volume=cursor.fromBeginning and t.volumes[thread.volumeIds[1]] or T.ResolveVolume(index,thread,cursor.volumeId)
    if not volume or volume.threadId~=thread.id then return {},nil,thread,nil end
    local rows={};for _,id in ipairs(volume.episodeIds) do rows[#rows+1]=t.episodes[id].node end
    return rows,nil,thread,volume
end
function T.Related(index,storyId)
    local t=index and index.threads;return index and index.provider:Allowed() and T.Valid(t,index) and t.episodes[storyId] and t.episodes[storyId].memberships or {}
end

ns.Metis.Register('Books',T)
