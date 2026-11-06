-- WardenDB static knowledge is separate from canonical living history.
local _,ns=...
local D=ns.WorldCodexInput;ns.WorldCodexInput=nil
ns.AthenaQuestChains.SetSource(D)
local K={VERSION=8,CACHE_LIMIT=96};ns.Athena.Knowledge=K
ns.WardenDB=ns.WardenDB or {};ns.WardenDB.Knowledge=K
local contexts,indices=setmetatable({},{__mode='k'}),setmetatable({},{__mode='k'})
local cache,order={},{};local consumers={command=true,chronicle=true,intel=true,chat=true,shield=true,alerts=true,relay=true}
local purposes={LORE_VISIBLE_TO_OWNER=true,PUBLIC_TERMS_ONLY=true,DIAGNOSTICS=true}
local function Copy(v) return ns.AthenaJournal and ns.AthenaJournal.Copy(v) or ns.Athena.Copy(v) end
local function Numbers(s) local out={};for n in tostring(s or ''):gmatch('%d+') do out[#out+1]=tonumber(n) end;return out end
local function Env(provider) return provider and provider.WorldEnvironment and provider:WorldEnvironment() or ns.AthenaWorldKnowledge.Environment() end
local function Permit(consumer) return consumers[consumer] and ns.Athena.Enabled(consumer) and ns.DB and (not ns.Membership or ns.Membership.Allowed()) end
local function Signature() return ns.AthenaStoryContributions.PermissionSignature() end
local function NativeMask(id)
    return type(id)=='number' and id>=1 and id<=32 and id%1==0 and 2^(id-1) or nil
end
local function RaceOK(mask,race,raceID)
    if not mask then return true end
    local value=({Human=1,Orc=2,Dwarf=4,NightElf=8,Undead=16,Scourge=16,Tauren=32,Gnome=64,Troll=128})[race] or NativeMask(raceID)
    if not value then return false end
    return math.floor(mask/value)%2==1
end
local function Valid(ctx)
    local state=contexts[ctx]
    if not state or not Permit(state.consumer) or state.permission~=Signature() then return nil,'DENIED' end
    local c=setmetatable({index=state.weak.index,provider=state.weak.provider},{__index=state,__newindex=state})
    if c.hadIndex and not c.index then return nil,'STALE_PROGRESS' end
    if c.provider and not c.provider:Allowed() then c.index=nil;c.provider=nil;return nil,'DENIED' end
    if c.index and (not indices[c.index] or c.index.owner~=c.owner or c.index.status~='READY') then return nil,'STALE_PROGRESS' end
    if c.index and c.provider.Identity and not ns.AthenaJournal.SameHistory(c.index.identity,c.provider:Identity(c.owner)) then return nil,'STALE_PROGRESS' end
    local env=Env(c.provider)
    if env.interface~=c.env.interface or env.build~=c.env.build or env.locale~=c.env.locale then return nil,'BUILD_CHANGED' end
    -- The temporary strong fields are not retained between calls. Readers own
    -- the index/provider; a weak-key context must not root their story cycle.
    return c
end
-- Called once by the actual cooperative source index, never by a new collector.
function K.BindIndex(index)
    if not index.provider:Allowed() then return end
    local p={quests={},questTitles={},maps={},instances={},instanceNames={},placeNames={},npcs={},npcNames={},questRefs={},identity=Copy(index.ownerIdentity or {})};local own=index.owner:match('/(Player%-.+)$')
    for i,f in ipairs(index.facts) do
        if not f.storyPrivateProjection and (not f.subjectGUID or f.subjectGUID==own) then
            local place=f.location or {}
            if place.inInstance==true and (place.instanceType=='party' or place.instanceType=='raid') then
                local name=place.instanceName or place.zone
                if name then p.instanceNames[name]=f.evidenceRef end
            elseif place.inInstance==false and place.zone then p.placeNames[place.zone]=f.evidenceRef end
            local id=f.details.questID;local stage=({quest_accepted=2,quest_objective=3,quest_turnin=4})[f.family]
            local title=f.details.title or f.details.name
            -- Objective snapshots use title/name for objective wording too.
            -- Only the typed quest-header observation identifies the quest.
            if id and f.family=='quest_observed' and ns.CanRead(title) and title~='' then p.questTitles[id]=title end
            if id and stage then p.quests[id]=math.max(p.quests[id] or 0,stage);p.questRefs[id]=p.questRefs[id] or {};if #p.questRefs[id]<8 then p.questRefs[id][#p.questRefs[id]+1]=f.evidenceRef end end
            if f.mapID and (f.family=='location' or f.family=='instance_enter' or f.family=='player_position') then p.maps[f.mapID]=f.evidenceRef end
        end
        if i%128==0 then coroutine.yield() end
    end
    for i,n in ipairs(index.nodes) do
        if not n.private and index.byRef[n.sourceRef] then
            local map=n.mapID or n.zoneKey and tonumber(n.zoneKey:match('^ui%-map:(%d+)$'))
            if map then p.maps[map]=n.sourceRef end
            if n.place and n.place.instanceID then p.instances[n.place.instanceID]=n.sourceRef end
        end
        if i%128==0 then coroutine.yield() end
    end
    indices[index]=p
end
function K.Context(consumer,owner,options)
    if not Permit(consumer) or type(owner)~='string' or not owner:match('/Player%-.+') then return nil,'DENIED' end
    options=options or {};if not purposes[options.purpose or 'LORE_VISIBLE_TO_OWNER'] then return nil,'PURPOSE_REQUIRED' end
    local index=options.index;local progress=index and indices[index]
    if index and (not progress or index.owner~=owner or not index.provider:Allowed()) then return nil,'PROGRESS_NOT_VERIFIED' end
    local provider=index and index.provider;local ctx={};contexts[ctx]={owner=owner,consumer=consumer,purpose=options.purpose or 'LORE_VISIBLE_TO_OWNER',
        progress=progress or {quests={},questTitles={},maps={},instances={},instanceNames={},placeNames={},npcs={},npcNames={},questRefs={},identity={}},weak=setmetatable({index=index,provider=provider},{__mode='v'}),hadIndex=index~=nil,env=Env(provider),permission=Signature(),version=D.version}
    return ctx
end
function K.Version() return {version=D.version,sourceHash=D.sourceHash,sourceURL=D.sourceURL,knownSourceIDs=D.knownIDs,branch='FOREVER',build=69913,locale='enUS',allGameQuestsKnown=false} end
-- Public static header only. No story atoms, endings, future quest names or
-- character progress escape GetQuest's unchanged eligibility/hash/stage gates.
function K.QuestReferenceFields(id)
    local row=D.questMeta[id];if not row then return end
    local f={};for v in (row..'\031'):gmatch('(.-)\031') do f[#f+1]=v;if #f>=9 then break end end
    local ref=ns.AthenaQuestData.referenceMetadata and ns.AthenaQuestData.referenceMetadata[id]
    return {questID=id,requiredLevel=tonumber(f[2]),level=tonumber(f[3]),racesMask=tonumber(f[4]),classesMask=tonumber(f[5]),
        sourceHash=f[9],sourceURL=ref and ref.sourceURL or D.sourceURL,sourceVersion=ref and ref.sourceVersion or D.version}
end
function K.EachQuestAreaReference(emit)
    -- Read the existing packed location tuples, preserving typed area IDs and
    -- minimum stages. No name matching or new geographic observation.
    for id,row in pairs(D.storyRows) do
        local at=1;local locations
        for value in (row..'\031'):gmatch('(.-)\031') do if at==7 then locations=value;break end;at=at+1 end
        local seen={};for tag in (locations or ''):gmatch('[^\030]+') do
            local stage,area,map,atom,name=tag:match('^(%d+),(%d+),(%d+),(%d+),(.*)$');area=tonumber(area)
            local token=tostring(area)..'/'..tostring(name)
            if stage and not seen[token] and (area and area>0 or name and name~='') then seen[token]=true;emit(id,area,tonumber(stage),name) end
        end
    end
end
-- Read-only labels for the existing Wiki index. Episode prose remains gated by
-- GetArc/GetLore; this does not create another chain database.
function K.EachAuthoredArc(emit)
    for id,arc in pairs(D.arcs) do if arc.authored then emit(id,arc.title,Copy(arc.quests)) end end
end
function K.ContextAllowed(ctx) return Valid(ctx)~=nil end
function K.NoteLoreSubject(ctx,id,questID,claims)
    local c=Valid(ctx);local e=ns.AthenaLoreCodex and ns.AthenaLoreCodex.byID[id];if not c or not e or not e.requiredMentions then return false end
    local q=K.ReferenceForStory({knowledgeContext=ctx,factualClaims=claims},questID);if not q then return false end
    for _,atom in ipairs(q.narrative and q.narrative.atoms or {}) do for _,alias in ipairs(e.requiredMentions) do
        if atom.text:lower():find(alias:lower(),1,true) then c.progress.loreMentions=c.progress.loreMentions or {};c.progress.loreMentions[id]=questID;return true end
    end end
    return false
end
local function Raw(id,env)
    local key=D.version..'/'..tostring(id);local value=cache[key]
    if value then return value end
    local q,why=ns.AthenaWorldKnowledge.GetQuest(id,env);if not q then return nil,why end
    local m=D.questMeta[id];if not m then return nil,'UNKNOWN' end
    local f={};for s in (m..'\031'):gmatch('(.-)\031') do f[#f+1]=s end
    q.intent=f[1];q.requiredLevel=tonumber(f[2]);q.level=tonumber(f[3]);q.racesMask=tonumber(f[4]);q.classesMask=tonumber(f[5]);q.mapID=tonumber(f[6]);q.availability=f[7];q.exclusiveQuestIDs=Numbers(f[8]);q.sourceHash=f[9]
    q.characters={};for pair in (f[10] or ''):gmatch('[^,]+') do local npc,role=pair:match('^(%d+):(.+)$');if npc then local c=ns.AthenaWorldKnowledge.Get('NPC',tonumber(npc),env);q.characters[#q.characters+1]={npcID=tonumber(npc),role=role,name=c and c.name,personallyEncountered=false,sourceField='upstream structure'} end end
    q.sourceProfile=ns.AthenaQuestProfiles.Decode(id,D.storyRows[id],q.sourceHash)
    if not q.sourceProfile then return nil,'PROFILE_INVALID' end
    q.repeatable='UNKNOWN';q.storyTone='UNKNOWN'
    local reference=ns.AthenaQuestData.referenceMetadata and ns.AthenaQuestData.referenceMetadata[id]
    q.sourceVersion=reference and reference.sourceVersion or D.version
    q.worldRef='world:'..q.sourceVersion..'/quest/'..id
    local o=D.overrides[id];if o then q.setup=o.setup;q.conclusion=o.conclusion;q.overrideRevision=o.revision end
    q.reviewStatus=o and 'SOURCE_EXTRACTION + BUILDER_CORRECTION / INDEPENDENT_REVIEW_PENDING' or 'SOURCE_EXTRACTION / INDEPENDENT_REVIEW_PENDING';q.observedByPlayer=false
    if #order>=K.CACHE_LIMIT then cache[table.remove(order,1)]=nil end;order[#order+1]=key;cache[key]=q
    return q
end
local function Revealed(c,id)
    if c.provider and c.provider.demo then return c.reveals and (c.reveals[id] or c.reveals.ALL) end
    local p=ns.DB.journalSpoilerReveals;return p and p[c.owner] and p[c.owner].version==D.version and (p[c.owner].entries[id] or p[c.owner].entries.ALL)
end
local function EligibleQuest(c,id)
    local q,why=Raw(id,c.env);if not q then return nil,why end
    local title=c.progress.questTitles and c.progress.questTitles[id]
    if title and title~=q.title then return nil,'TITLE_CONFLICT' end
    -- Gate the individual reference, never the whole client. Unknown or
    -- unreadable native identity cannot bind an old quest ID to this life.
    -- Deliberate reference-only spoiler browsing still makes no player claim.
    if not title and not Revealed(c,'quest:'..id) and not Revealed(c,'ALL') then return nil,'QUEST_IDENTITY_UNCONFIRMED' end
    if q.racesMask and not RaceOK(q.racesMask,c.progress.identity.race,c.progress.identity.raceID) then return nil,'BRANCH_MISMATCH' end
    if q.classesMask then local class=({WARRIOR=1,PALADIN=2,HUNTER=4,ROGUE=8,PRIEST=16,SHAMAN=64,MAGE=128,WARLOCK=256,DRUID=1024})[c.progress.identity.class] or NativeMask(c.progress.identity.classID)
        if not class or math.floor(q.classesMask/class)%2~=1 then return nil,'BRANCH_MISMATCH' end
    end
    return q
end
function K.GetQuest(id,ctx)
    local c,why=Valid(ctx);if not c then return nil,why end
    local q,status=EligibleQuest(c,id);if not q then return nil,status end
    local stage=c.progress.quests[id] or 0;local reveal=Revealed(c,'quest:'..id)
    if stage<2 and not reveal then return nil,'LOCKED' end
    local out=Copy(q);out.observedStage=stage;out.revealedManually=reveal==true;out.personalSourceRefs=Copy(c.progress.questRefs[id] or {})
    out.clientBuild=c.env.build
    out.referenceCompatibility=ns.AthenaQuestData.referenceMetadata and ns.AthenaQuestData.referenceMetadata[id]
        and 'QUALIFIED_COMMUNITY_BETA_ACCOUNT' or ns.AthenaWorldKnowledge.ReferenceCompatibility(c.env)
    out.narrative=ns.AthenaQuestProfiles.ForStage(out.sourceProfile,reveal and 4 or stage);out.sourceProfile=nil
    if out.premiseMinimumStage and stage<out.premiseMinimumStage and not reveal then out.premise=nil end
    local P=ns.AthenaQuestProfiles
    out.setup=out.setup or P.Scene(out.narrative,'premise',out.giverName)
    out.conclusion=out.conclusion or P.Scene(out.narrative,'ending',out.giverName)
    for _,key in ipairs({'motivations','conflict','stakes','consequences','loreConnections','objectives'}) do out[key]=out.narrative.fields[key] or 'UNKNOWN' end
    for _,person in ipairs(out.narrative.characters) do out.characters[#out.characters+1]=Copy(person) end
    out.locations=Copy(out.narrative.locations)
    if stage<4 and not reveal then out.conclusion=nil end
    if c.purpose=='PUBLIC_TERMS_ONLY' then return {questID=id,title=out.title,characters=out.characters,worldRef=out.worldRef} end
    -- Future quest IDs are not navigation hints until their own premise is known.
    out.previousIDs=ns.AthenaQuestChains.Previous(id);out.nextIDs=ns.AthenaQuestChains.Following(id)
    for _,key in ipairs({'previousIDs','nextIDs','exclusiveQuestIDs'}) do local visible={};for _,other in ipairs(out[key] or {}) do if (c.progress.quests[other] or 0)>=2 then visible[#visible+1]=other end end;out[key]=visible end
    local edges={};for _,e in ipairs(out.narrative.relationships) do if (c.progress.quests[e.questID] or 0)>=2 then edges[#edges+1]=e end end;out.narrative.relationships=edges
    out.storyContext=ns.AthenaQuestContext.Build(out)
    out.summary=ns.AthenaQuestContext.Summary(out)
    return out
end
function K.GetNPC(id,ctx)
    local c,why=Valid(ctx);if not c then return nil,why end
    local roles={};local name
    for _,qid in ipairs(Numbers(D.npcQuests[id])) do
        local q=K.GetQuest(qid,ctx)
        if q then for _,person in ipairs(q.characters) do if person.npcID==id then name=person.name;roles[#roles+1]={questID=qid,role=person.role,questTitle=q.title} end end end
        if #roles>=16 then break end
    end
    local lore=ns.AthenaLoreCodex;local key=lore and lore.byNPC and lore.byNPC[id]
    local entry=key and K.GetLore('lore:'..key,ctx)
    -- Source object3972 and creature3972 are separate addresses. An older
    -- untyped quest relation cannot rename the creature to the wanted notice.
    if entry and entry.catalogReferenceMetadata and entry.catalogReferenceMetadata.separateObjectNamespaceCollision then name=nil;roles={} end
    -- A named vendor or trainer need not give a quest. Resolve the same
    -- canonical lore subject without inventing a quest role or meeting.
    name=name or entry and entry.title
    if not name then return nil,'LOCKED' end
    return {npcID=id,name=name,roles=roles,biography=entry and entry.body or 'UNKNOWN',
        loreID=entry and entry.id,worldRef='world:'..D.version..'/npc/'..id,
        personallyEncountered=false,sourceURL=entry and entry.sourceURL or D.sourceURL,
        referenceStatus=entry and entry.referenceStatus,observedIdentity=entry and Copy(entry.observedIdentity),
        unresolvedBiographyFields=entry and Copy(entry.unresolvedBiographyFields)}
end
function K.GetArc(id,ctx)
    local c,why=Valid(ctx);if not c then return nil,why end
    local arc=D.arcs[id]
    local questID=not arc and type(id)=='string' and tonumber(id:match('^quest%-(%d+)$'))
    if questID then
        local members=ns.AthenaQuestChains.Members(questID);local visible={};local incomplete=false
        for _,qid in ipairs(members) do local q=K.GetQuest(qid,ctx)
            if q then visible[#visible+1]={questID=qid,title=q.title,stage=q.observedStage,summary=q.summary,previousIDs=q.previousIDs,nextIDs=q.nextIDs};if q.observedStage<4 then incomplete=true end end
        end
        if #visible==0 then return nil,'LOCKED' end
        return {id=id,title='Connected quest account',quests=visible,completed=not incomplete and #visible==#members,
            chainStatus='TYPED_REFERENCE_OUTLINE',grouping='Prerequisite / next links; branches retained',worldRef='world:'..D.version..'/arc/'..id,
            sourceURL=D.sourceURL,impliesUnseenCompletion=false,commonCauseVerified=false}
    end
    if not arc then return nil,'UNKNOWN' end
    if arc.raceMask and not RaceOK(arc.raceMask,c.progress.identity.race,c.progress.identity.raceID) then return nil,'BRANCH_MISMATCH' end
    if arc.authored then
        local visible,complete,refs={},true,{}
        for _,qid in ipairs(arc.quests) do
            local q=K.GetQuest(qid,ctx)
            if q then visible[#visible+1]={questID=qid,title=q.title,stage=q.observedStage};refs[qid]=q end
            if not q or q.observedStage<4 then complete=false end
        end
        if #visible==0 then return nil,'LOCKED' end
        local function Reference(qid)
            if refs[qid]==nil then refs[qid]=K.GetQuest(qid,ctx) or false end
            return refs[qid]
        end
        -- Reviewed alternatives replace the old all-members completion rule.
        -- Checking receipt quests outside the authored selection never adds
        -- an unseen quest to the returned account.
        if arc.completionRequirements then
            local function Completed(node,depth)
                if type(node)~='table' or depth>12 then return false end
                if node.questID then
                    local q=Reference(node.questID)
                    return q and node.minimumStage==4 and q.observedStage>=4 and q.sourceHash==node.sourceHash or false
                end
                local children=node.allOf or node.anyOf
                if type(children)~='table' or #children==0 then return false end
                if node.allOf then
                    for _,child in ipairs(children) do if not Completed(child,depth+1) then return false end end
                    return true
                end
                for _,child in ipairs(children) do if Completed(child,depth+1) then return true end end
                return false
            end
            complete=Completed(arc.completionRequirements.expression,0)
        end
        local episodes={}
        for _,episode in ipairs(arc.episodes) do
            local allowed=true
            for _,need in ipairs(episode.requiresAll) do
                local q=Reference(need.questID)
                if not q or q.observedStage<need.minimumStage then allowed=false;break end
            end
            if allowed then for _,proof in ipairs(episode.sourceProofs) do
                local q=Reference(proof.questID);local seen={}
                if not q or q.sourceHash~=proof.sourceHash then allowed=false;break end
                for _,atom in ipairs(q.narrative.atoms) do seen[atom.id]=true end
                for _,id in ipairs(proof.atomIDs) do if not seen[id] then allowed=false;break end end
                if not allowed then break end
            end end
            if allowed then episodes[#episodes+1]=Copy(episode) end
        end
        return {id=id,title=arc.title,quests=visible,episodes=episodes,completed=complete and not arc.sourceConflict,
            authored=true,chainStatus='AUTHORED_SOURCE_BOUND_EPISODES',grouping=arc.grouping,
            worldRef='world:'..D.version..'/arc/'..id,sourceURL=D.sourceURL,
            impliesUnseenCompletion=false,branchHandling=Copy(arc.branchHandling)}
    end
    local visible,complete={},true
    for _,qid in ipairs(arc.quests) do local q=K.GetQuest(qid,ctx);if q then visible[#visible+1]={questID=qid,title=q.title,stage=q.observedStage} end;if (c.progress.quests[qid] or 0)<4 then complete=false end end
    if #visible==0 then return nil,'LOCKED' end
    return {id=id,title=arc.title,quests=visible,completed=complete and not arc.sourceConflict,sourceConflict=arc.sourceConflict==true,
        chainStatus=arc.sourceConflict and 'UNKNOWN_SOURCE_BRANCH_CONFLICT' or 'SOURCE_GROUP',grouping=arc.grouping,worldRef='world:'..D.version..'/arc/'..id,sourceURL=D.sourceURL}
end
local places={
    [57]={title='Teldrassil',body='Darnassus stands among the boughs of Teldrassil, a refuge shaped by night-elven reverence for the living world.',source='https://us.media.blizzard.com/manuals/wow/wow-classic-manual-enUS.pdf'},
    [62]={title='Darkshore',body='Auberdine links the coast of Darkshore to the wider routes of the Alliance. Beyond its harbor, older ruins preserve other chapters of this land.',source='https://worldofwarcraft.blizzard.com/en-gb/news/23156366/wow-classic-getting-around-azeroth'},
    [80]={title='Moonglade',body='The Shrine of Remulos and the wardens of Moonglade belong to the Cenarion Circle’s work of preserving nature and balance.',source=D.sourceURL,quest=28},
    [52]={title='Westfall',body='The militia’s investigation follows the Defias through a countryside whose inhabitants have been driven from their land.',source=D.sourceURL,quest=65},
}
function K.GetZone(id,ctx)
    local c,why=Valid(ctx);if not c then return nil,why end
    local p=places[id];if not p then return nil,'UNKNOWN' end
    if not c.progress.maps[id] or p.quest and (c.progress.quests[p.quest] or 0)<2 and not (p.quest==28 and (c.progress.quests[29] or 0)>=2) then return nil,'LOCKED' end
    return {mapID=id,title=p.title,body=p.body,sourceURL=p.source,worldRef='world:'..D.version..'/zone/'..id,era='FOREVER_START',kind='WORLD_HISTORY',personalSourceRefs={c.progress.maps[id]}}
end
local function WorldEntry(id,c)
    local kind,name=id:match('^world(%a+):(.+)$');if not kind then return end
    local ref,place
    if kind=='place' then ref=c.progress.placeNames and c.progress.placeNames[name];place={inInstance=false,zone=name}
    elseif kind=='instance' then ref=c.progress.instanceNames and c.progress.instanceNames[name];place={inInstance=true,instanceType='party',instanceName=name} end
    if not ref then return nil,'LOCKED' end
    local card=ns.AthenaWorldScenes.Setting(place,c.owner..'/encyclopedia/'..id)
    if not card then return nil,'UNKNOWN' end
    card.id=id;card.section='places';card.personalSourceRefs={ref};return card
end
function K.LoreVisible(id,ctx)
    local c=Valid(ctx);if not c or type(id)~='string' then return false end
    c.allowLoreSpoilers=Revealed(c,'ALL')
    return ns.AthenaLoreCodex.Visible(id,c,ctx)
end
function K.GetLore(id,ctx)
    local c,why=Valid(ctx);if not c then return nil,why end
    if type(id)~='string' then return nil,'UNKNOWN' end
    if id:match('^lore:') and ns.AthenaLoreCodex then c.allowLoreSpoilers=Revealed(c,'ALL');return ns.AthenaLoreCodex.Entry(id,c,ctx) end
    if id:match('^world%a+:') then return WorldEntry(id,c) end
    local era=id:match('^era:(%d+)$');if era then
        if ns.DB.journalPrologueHidden then return nil,'HIDDEN_PROLOGUE' end
        local cards=ns.AthenaWorldKnowledge.Prologue(c.progress.identity);local card=cards[tonumber(era)];if not card then return nil,'UNKNOWN' end
        return {id=id,title=card.title,body=card.text,worldRef=card.worldRef,sourceURL=card.sourceURL,kind='WORLD_HISTORY',era='BEFORE_MY_STORY',section=tonumber(era)==#cards and 'peoples' or 'ages'}
    end
    local qid,part=id:match('^quest:(%d+):(%a+)$')
    if qid then
        qid=tonumber(qid);local q,status=K.GetQuest(qid,ctx);if not q then return nil,status end
        if part~='premise' and part~='ending' then return nil,'UNKNOWN' end
        local editorial=q.storyContext and q.storyContext.editorial
        local text
        if editorial then
            if part=='premise' then text=editorial.opening
            elseif q.observedStage>=4 or q.revealedManually then
                text=ns.AthenaQuestContext.Aftermath(q)
                if not text and editorial.result then
                    -- This is a reference account of the fulfilled objective,
                    -- never a claim that a manually revealed deed was done.
                    text='At fulfillment, '..editorial.result:gsub('{actor}','the assigned adventurer')
                end
            end
        end
        text=text or ns.AthenaQuestProfiles.LoreText(q.narrative,part) or (part=='ending' and q.conclusion or q.setup or q.premise)
        if part=='ending' and not q.conclusion and not q.narrative.fields.conclusion then return nil,q.observedStage<4 and not q.revealedManually and 'LOCKED' or 'UNKNOWN' end
        if not text then return nil,'UNKNOWN' end
        return {id=id,title=q.title..(part=='ending' and ' — Conclusion' or ''),body=text,worldRef=q.worldRef..'/'..part,sourceURL=q.sourceURL,kind='WORLD_HISTORY',era='FOREVER_START',section=part=='ending' and 'legends' or 'questlines',revealedManually=q.revealedManually,personalSourceRefs=q.personalSourceRefs}
    end
    local zid=id:match('^zone:(%d+)$');if zid then local z,reason=K.GetZone(tonumber(zid),ctx);if z then z.section='places' end;return z,reason end
    local npc=id:match('^npc:(%d+)$');if npc then
        local n,reason=K.GetNPC(tonumber(npc),ctx);if not n then return nil,reason end
        if n.loreID and n.biography~='UNKNOWN' then
            local card=K.GetLore(n.loreID,ctx)
            if card then card.relatedWorldRef=n.worldRef;return card end
        end
        local bio=ns.AthenaWorldScenes.NamedFigure(n.name)
        if bio then
            local card=ns.AthenaWorldScenes.Variant(bio,c.owner..'/encyclopedia/'..id)
            card.id=id;card.section='figures';card.personalSourceRefs=n.personalSourceRefs
            card.relatedWorldRef=n.worldRef;card.relatedSourceURL=n.sourceURL;return card
        end
        local roles={};for _,role in ipairs(n.roles) do roles[#roles+1]=role.role:lower()..' for “'..role.questTitle..'”' end
        return {id=id,title=n.name,body=n.name..' is associated with these known assignments: '..table.concat(roles,'; ')..'. A quest association is not proof of a personal meeting.',section='figures',worldRef=n.worldRef,sourceURL=n.sourceURL,kind='WORLD_HISTORY',era='FOREVER_START'}
    end
    local aid=id:match('^arc:(.+)$');if aid then
        local a,status=K.GetArc(aid,ctx);if not a then return nil,status end
        if a.authored then
            local lines={};for _,episode in ipairs(a.episodes) do lines[#lines+1]=episode.text end
            if #lines==0 then return nil,'LOCKED' end
            return {id=id,title=a.title,body=table.concat(lines,'\n\n'),worldRef=a.worldRef,sourceURL=a.sourceURL,
                kind='WORLD_HISTORY',era='FOREVER_START',section='questlines',completed=a.completed,
                personalExperienceProven=false,chainStatus=a.chainStatus}
        end
        if not a.completed and not aid:match('^quest%-') and not Revealed(c,id) then return nil,'LOCKED' end
        if aid:match('^quest%-') then
            local paragraphs={}
            for _,q in ipairs(a.quests) do local summary=q.summary
                local parts={};if summary and summary.problem then parts[#parts+1]=summary.problem end
                if summary and summary.purpose then parts[#parts+1]='The charge concerned '..summary.purpose..'.'
                elseif summary and summary.objectiveAccount then parts[#parts+1]=summary.objectiveAccount end
                if q.stage>=4 and summary and summary.aftermath then parts[#parts+1]=summary.aftermath end
                if #parts>0 then paragraphs[#paragraphs+1]=table.concat(parts,' ') end
            end
            return {id=id,title='Connected account',body=table.concat(paragraphs,'\n\n'),worldRef=a.worldRef,sourceURL=a.sourceURL,kind='WORLD_HISTORY',era='FOREVER_START',section='questlines',completed=a.completed}
        end
        local titles={};for _,q in ipairs(a.quests) do titles[#titles+1]=q.title end
        return {id=id,title=a.title,body='These connected assignments form one arc: '..table.concat(titles,'; ')..'. Each personal milestone has its own source; the arc adds no unseen deeds.',worldRef=a.worldRef,sourceURL=a.sourceURL,kind='WORLD_HISTORY',era='FOREVER_START',section='legends'}
    end
    if id=='instance:409' and c.progress.instances[409] then
        return {id=id,title='Molten Core',body='Deep within Blackrock Mountain, the legacy of a dwarven civil war leads to Ragnaros. Thaurissan’s summoning bound the mountain’s history to the Firelord and his elemental servants.',kind='WORLD_HISTORY',era='FOREVER_START',section='places',worldRef='world:'..D.version..'/instance/409',sourceURL='https://news.blizzard.com/en-gb/article/24165121/20th-anniversary-realms-molten-core-and-onyxia-s-lair-now-live',personalSourceRefs={c.progress.instances[409]}}
    end
    return nil,'UNKNOWN'
end
function K.RequestReveal(ctx,id)
    local c,why=Valid(ctx);if not c then return nil,why end
    local qid=id and id:match('^quest:(%d+)');if qid then local q,status=EligibleQuest(c,tonumber(qid));if not q then return nil,status end
    elseif id~='ALL' then
        local arc=id and id:match('^arc:') and D.arcs[id:sub(5)];if not arc then return nil,'UNKNOWN' end
        if arc.raceMask and not RaceOK(arc.raceMask,c.progress.identity.race,c.progress.identity.raceID) then return nil,'BRANCH_MISMATCH' end
    end
    local ticket={};c.ticket={handle=ticket,id=id};return ticket,'This reveals spoilers for an eligible reference. It does not mark an adventure complete.'
end
function K.ConfirmReveal(ctx,ticket)
    local c,why=Valid(ctx);if not c then return false,why end
    if not c.ticket or c.ticket.handle~=ticket then return false,'CONFIRMATION_REQUIRED' end
    local id=c.ticket.id;c.ticket=nil;local qid=id:match('^quest:(%d+)');local target=qid and ('quest:'..qid) or id
    if c.provider and c.provider.demo then c.reveals=c.reveals or {};c.reveals[target]=true;return true end
    ns.DB.journalSpoilerReveals=ns.DB.journalSpoilerReveals or {};local all=ns.DB.journalSpoilerReveals
    local row=all[c.owner];if not row or row.version~=D.version then row={version=D.version,entries={},order={}};all[c.owner]=row end
    if not row.entries[target] then if #row.order>=32 then row.entries[table.remove(row.order,1)]=nil end;row.order[#row.order+1]=target;row.entries[target]=true end
    return true
end
function K.CancelReveal(ctx) local c=contexts[ctx];if c then c.ticket=nil end end
function K.ResetReveals(ctx) local c=Valid(ctx);if not c then return false end;if c.provider and c.provider.demo then c.reveals={} elseif ns.DB.journalSpoilerReveals then ns.DB.journalSpoilerReveals[c.owner]=nil end;return true end
local function Catalogue(c)
    local signature=tostring(Revealed(c,'ALL'))
    if c.catalog and c.catalogSignature==signature then return c.catalog end
    local out={};for i in ipairs(ns.AthenaWorldKnowledge.Prologue(c.progress.identity)) do out[#out+1]='era:'..i end
    if ns.AthenaLoreCodex then for _,id in ipairs(ns.AthenaLoreCodex.IDs()) do out[#out+1]=id end end
    local maps={};for map in pairs(places) do maps[#maps+1]=map end;table.sort(maps);for _,map in ipairs(maps) do out[#out+1]='zone:'..map end
    local quests={};for qid in pairs(Revealed(c,'ALL') and D.questMeta or c.progress.quests) do quests[#quests+1]=qid end;table.sort(quests)
    local people={}
    for _,qid in ipairs(quests) do out[#out+1]='quest:'..qid..':premise';out[#out+1]='quest:'..qid..':ending'
        if (c.progress.quests[qid] or 0)>=2 or Revealed(c,'quest:'..qid) then
            local pairs=D.questMeta[qid] and D.questMeta[qid]:match('\031([^\031]*)$') or ''
            for id in pairs:gmatch('(%d+):') do people[tonumber(id)]=true end
        end
    end
    for id in pairs(ns.AthenaLoreCodex.byNPC or {}) do people[id]=true end
    local npcids={};for id in pairs(people) do npcids[#npcids+1]=id end;table.sort(npcids);for _,id in ipairs(npcids) do out[#out+1]='npc:'..id end
    local namedArcs={};for id in pairs(D.arcs) do namedArcs[#namedArcs+1]=id end;table.sort(namedArcs)
    for _,id in ipairs(namedArcs) do out[#out+1]='arc:'..id end
    local arcSeen={}
    for _,qid in ipairs(quests) do local key=ns.AthenaQuestArcFor[qid]
        if key and not arcSeen[key] then arcSeen[key]=true;out[#out+1]='arc:quest-'..qid end
    end
    local worldIDs={}
    for name in pairs(c.progress.placeNames or {}) do worldIDs[#worldIDs+1]='worldplace:'..name end
    for name in pairs(c.progress.instanceNames or {}) do worldIDs[#worldIDs+1]='worldinstance:'..name end
    table.sort(worldIDs);for _,id in ipairs(worldIDs) do out[#out+1]=id end
    out[#out+1]='instance:409';c.catalog=out;c.catalogSignature=signature;return out
end
function K.Search(kind,query,ctx,cursor,limit)
    local c,why=Valid(ctx);if not c then return nil,why end
    if kind~='LORE' and kind~='QUEST' and kind~='NPC' then return nil,'UNSUPPORTED' end
    local section=type(query)=='table' and query.section;query=type(query)=='table' and query.text or query
    query=type(query)=='string' and query:lower() or '';local offset=type(cursor)=='number' and math.max(0,math.floor(cursor)) or 0;limit=math.max(1,math.min(25,limit or 20))
    local rows={};local catalog=Catalogue(c)
    -- A typed static shelf must not page through unrelated quests and people
    -- before showing its known subjects. Keep the bounded, gated search over
    -- the canonical registry, with no second database or hidden-item count.
    if kind=='LORE' and section=='creatures' then
        c.creatureShelf=c.creatureShelf or {}
        local signature=tostring(Revealed(c,'ALL'))..'/'..ns.AthenaLoreCodex.VERSION
        if c.creatureShelf.signature~=signature then
            c.allowLoreSpoilers=Revealed(c,'ALL')
            c.creatureShelf={signature=signature,ids=ns.AthenaLoreCodex.VisibleIDs('creature',c,ctx)}
        end
        catalog=c.creatureShelf.ids
    elseif kind=='NPC' then
        -- NPC search matches names only. Restrict the static candidate list
        -- before bounded permission checks instead of scanning every lore and
        -- quest address ahead of the first numeric NPC address.
        catalog={}
        for id,key in pairs(ns.AthenaLoreCodex.byNPC or {}) do
            local e=ns.AthenaLoreCodex.byID[key]
            local match=query=='' or e.title:lower():find(query,1,true)
            if not match then for _,alias in ipairs(e.aliases or {}) do if alias:lower():find(query,1,true) then match=true;break end end end
            if match then catalog[#catalog+1]='npc:'..id end
        end
        table.sort(catalog)
    end
    local pos=offset
    while pos<#catalog and pos<offset+128 do pos=pos+1
        local entry
        local qid=catalog[pos]:match('^quest:(%d+):premise$')
        local npcID=catalog[pos]:match('^npc:(%d+)$')
        if kind=='LORE' then
            -- A canonical figure already has its lore entry in this catalog.
            -- Keep the numeric NPC address for NPC search, not a second card.
            if not (npcID and ns.AthenaLoreCodex.byNPC[tonumber(npcID)]) then entry=K.GetLore(catalog[pos],ctx) end
        elseif kind=='QUEST' and qid then local q=K.GetQuest(tonumber(qid),ctx);if q then entry={questID=q.questID,title=q.title,body=q.setup or q.premise or '',worldRef=q.worldRef} end
        elseif kind=='NPC' and npcID then local n=K.GetNPC(tonumber(npcID),ctx);if n then rows[#rows+1]=n end end
        if entry and (not section or section=='all' or section=='before' and (entry.era=='BEFORE_MY_STORY' or entry.gate=='HISTORICAL') or entry.section==section or entry.category==section or entry.region==section or entry.period==section or section=='zones' and entry.zoneCatalog) and (query=='' or (entry.title..' '..entry.body):lower():find(query,1,true)) then rows[#rows+1]=entry end
        if #rows>=limit then break end
    end
    return rows,pos<#catalog and pos or nil
end
function K.Coverage(kind,ctx)
    local c,why=Valid(ctx);if not c then return nil,why end
    if c.purpose=='DIAGNOSTICS' then return {knownSourceIDs=D.knownIDs,tiers=Copy(D.counts),version=D.version,allInGameQuestsKnown=false,decodedCache=#order,cacheLimit=K.CACHE_LIMIT} end
    return {version=D.version,scope='Story-Safe for this character',allInGameQuestsKnown=false}
end
function K.ResolveEvidenceLink(ref,ctx)
    local c,why=Valid(ctx);if not c or not c.provider then return nil,why or 'DENIED' end
    local e,status=c.provider:Resolve(ref);if e and e.observer==c.owner and not e.storyPrivateProjection and e.accessScope~='PRIVATE_INCIDENT' and not (e.sourceContext and e.sourceContext.accessScope=='PRIVATE_INCIDENT') then return Copy(e) end
    return nil,status or 'DENIED'
end
function K.GateAtom(atom,ctx)
    local c,why=Valid(ctx);if not c then return nil,why end
    if type(atom)~='table' or atom.branch~='FOREVER' and atom.branch~='SHARED' then return nil,'BRANCH_MISMATCH' end
    if type(atom.eraMinimum)~='number' or atom.eraMinimum>1 then return nil,'FUTURE_ERA' end
    if atom.owner and atom.owner~=c.owner then return nil,'OTHER_CHARACTER' end
    if atom.race and atom.race~=c.progress.identity.race then return nil,'BRANCH_MISMATCH' end
    if atom.mapID and not c.progress.maps[atom.mapID] then return nil,'LOCKED' end
    if atom.questID and (c.progress.quests[atom.questID] or 0)<(atom.stage or 999) and not Revealed(c,'quest:'..atom.questID) then return nil,'LOCKED' end
    if atom.requiredQuests then for _,id in ipairs(atom.requiredQuests) do if (c.progress.quests[id] or 0)<4 then return nil,'LOCKED' end end end
    return Copy(atom)
end
function K.ReferenceForStory(story,questID)
    local ctx=story and contexts[story.knowledgeContext] and story.knowledgeContext
    if not ctx then return nil,'NO_PROGRESS_CONTEXT' end
    local q,why=K.GetQuest(questID,ctx);if not q then return nil,why end
    for _,claim in ipairs(story.factualClaims or {}) do if type(claim.value)=='table' and claim.value.questID==questID and claim.value.name and claim.value.name~=q.title then return nil,'TITLE_CONFLICT' end end
    local stage=0
    for _,claim in ipairs(story.factualClaims or {}) do if type(claim.value)=='table' and claim.value.questID==questID then
        local level=({owner_quest_accepted=2,owner_quest_objective=3,owner_quest_turnin=4,quest_expedition_context=2})[claim.claimType] or 0
        stage=math.max(stage,level)
    end end
    if stage<2 then return nil,'NO_OBSERVED_STAGE' end
    stage=math.min(stage,q.observedStage or 0)
    q.narrative=ns.AthenaQuestProfiles.ForStage(q.narrative,stage)
    if not q.overrideRevision then q.setup=ns.AthenaQuestProfiles.Scene(q.narrative,'premise',q.giverName) end
    if stage<4 then q.conclusion=nil end
    for _,key in ipairs({'motivations','conflict','stakes','consequences','loreConnections','objectives'}) do q[key]=q.narrative.fields[key] or 'UNKNOWN' end
    local people={};for _,c in ipairs(q.characters) do if (c.minimumStage or 2)<=stage then people[#people+1]=c end end;q.characters=people
    q.locations=Copy(q.narrative.locations)
    q.subject=ns.AthenaQuestSubjects.Build(q)
    q.storyContext=ns.AthenaQuestContext.Build(q)
      q.summary=ns.AthenaQuestContext.Summary(q)
    return q
end
