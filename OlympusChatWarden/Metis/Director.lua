-- The sole narrative entry point. Capabilities below it cannot publish a book.
local _,ns=...
local M=ns.Metis;local C=M.capabilities
local P,D,T,A=C.Planning,C.Scenes,C.Books,C.Author
local raw={process=P.Process,plan=P.PlanThread,record=P.RenderThread,recordStory=P.Render,author=A.Render}
local function First(s,kind) for _,c in ipairs(s.claims or {}) do if c.claimType==kind then return c end end end
local function Copy(row) local out={};for k,v in pairs(row) do out[k]=v end;return out end
local function Union(out,rows,key)
    local seen={};for _,v in ipairs(out) do seen[key and v[key] or v]=true end
    for _,v in ipairs(rows or {}) do local id=key and v[key] or v;if not seen[id] then seen[id]=true;out[#out+1]=v end end
end
local function Reference(s)
    local c=First(s,'owner_quest_accepted') or First(s,'owner_quest_turnin') or First(s,'owner_quest_objective')
    return c and ns.Athena.Knowledge.ReferenceForStory({knowledgeContext=s.story.knowledgeContext,factualClaims=s.claims},c.value.questID)
end
function M.Project(index)
    M.Check(index);index.phase='Metis: significance and scenes';D.Build(index)
    index.phase='Metis: books';index.threads=T.Build(index)
    index.phase='Metis: manuscript memory';index.metisMemory=M.Memory.Build(index)
end
function M.Preferred(index,node)
    local rows=D.Preferred(index,node);Union(rows,M.Memory.Preferred(index,node));return rows
end
function M.Process(story) return raw.process(story) end
local function Consolidate(plan)
    -- Retrospective editing is confined to one uninterrupted visit/quest run.
    -- An expedition, private memory, session, gap or place change is a barrier.
    -- Alternating A/B/A objectives are revisions of A, not three introductions.
    local out,run,runKey={}, {},nil;local chapter
    for _,scene in ipairs(plan.novelScenes or {}) do
        local p=scene.place or scene.story.node.place or {}
        local key=scene.focus=='QUEST' and scene.beat and table.concat({tostring(scene.beat),tostring(p.zone),tostring(p.instanceID)},'/')
        if not key or key~=runKey then run={};chapter=scene.chapterId;runKey=key end
        local last=key and run[scene.occurrenceId]
        if last then
            Union(last.claims,scene.claims,'claimId');Union(last.stories,scene.stories,'storyId')
            Union(last.primaryDevelopmentIds,scene.primaryDevelopmentIds);Union(last.sourceEvidenceRefs,scene.sourceEvidenceRefs)
            Union(last.skillGrowth,scene.skillGrowth,'claimId');Union(last.growth,scene.growth,'claimId')
            last.lastAt=math.max(last.lastAt,scene.lastAt);last.metisRevisions=(last.metisRevisions or 0)+1
        else
            last=Copy(scene)
            for _,field in ipairs({'claims','stories','primaryDevelopmentIds','sourceEvidenceRefs','skillGrowth','growth'}) do last[field]={};for _,v in ipairs(scene[field] or {}) do last[field][#last[field]+1]=v end end
            if key then last.chapterId=chapter;run[scene.occurrenceId]=last end
            out[#out+1]=last
        end
    end
    plan.novelScenes=out
    local chapters,byID={},{}
    for _,scene in ipairs(out) do local c=byID[scene.chapterId]
        if not c then c={id=scene.chapterId,at=scene.chapterAt,title=scene.chapter and scene.chapter.title,scenes={}};byID[scene.chapterId]=c;chapters[#chapters+1]=c end
        c.scenes[#c.scenes+1]=scene;scene.chapter=c
    end
    for _,c in ipairs(chapters) do
        local subjects={};local count=0;local place
        for _,s in ipairs(c.scenes) do if s.focus=='QUEST' and not subjects[s.occurrenceId] then
            subjects[s.occurrenceId]=true;count=count+1;place=s.place or s.story.node.place
        end end
        if count>0 and place and place.zone then c.title=place.subzone or place.zone end
    end
    plan.manuscriptChapters=chapters
end
local function Context(plan)
    local activities,returns,settings,npcs,variants,figures,loreUsed={},{},{},{},{},{},{}
    local speciesChapters={}
    for zone in pairs(plan.manuscriptMemory.priorSettings or {}) do settings[zone]=true;local id=ns.AthenaLoreCodex.byTitle[zone];if id then loreUsed[id]=true end end
    local previous,previousScene;local recallUsed={};local edition=ns.DB.journalEditions and ns.DB.journalEditions[plan.owner] or 0
    for _,s in ipairs(plan.novelScenes) do
        local place=s.place or s.story.node.place or {};local here=s.placeClaim or First({claims=s.story.factualClaims},'observed_place')
        s.transition=nil;s.transitionIntent=nil;s.setting=nil;s.figure=nil;s.returnVisit=nil;s.metisRecall=nil
        local speciesChapter=s.chapterId or place.zone or s.sceneId
        s.creatureLoreAllowed=not speciesChapters[speciesChapter]
        s.includeRoutineGrowth=plan.threadType=='PROGRESSION'
        s.narrativeQuiet=s.focus=='QUEST' and not First(s,'owner_quest_accepted') and not First(s,'owner_quest_turnin') and not First(s,'owner_combat_experience') and not First(s,'owner_creature_credits') and not First(s,'owner_recorded_death') and #(s.growth or {})==0
        if not s.narrativeQuiet then
        if s.focus=='ACTIVITY' then s.followup=activities[s.chapterId];activities[s.chapterId]=true end
        if previous and here and here.value~=previous.claim.value then
            local ix=s.story.narrativeIndex;local now=ix and ix.byRef[here.evidenceRefs[1]];local before=ix and ix.byRef[previous.claim.evidenceRefs[1]]
            if now and before and now.observedAt>before.observedAt then
                s.transitionIntent={kind='PLACE',from=previous.claim,to=here,unknown=now.session~=before.session or now.clock~=before.clock or s.story.timeCoverage.gaps or previous.gaps}
            end
        elseif previousScene and (s.focus=='ACTIVITY' or previousScene.focus=='ACTIVITY') and s.focus~=previousScene.focus then
            s.transitionIntent={kind='ACTIVITY',from=previousScene.claims[1],to=s.claims[1],later=s.at>previousScene.lastAt}
        end
        -- A chapter/episode boundary is not a departure. Require the source's
        -- return proof AND an independently observed intervening other place.
        local visit=First({claims=s.story.factualClaims},'zone_return')
        local returnKey=visit and visit.evidenceRefs and visit.evidenceRefs[1]
        if visit and returnKey and not returns[returnKey] and s.transitionIntent and s.transitionIntent.kind=='PLACE'
            and here and previous and here.value~=previous.claim.value and place.zone==s.story.node.place.zone then
            s.returnVisit=visit;returns[returnKey]=true;s.transitionIntent=nil
        end
        if not settings[place.zone or false] and M.Lore() then
            local landmark=place.subzone and ns.AthenaLoreCodex.byTitle[place.subzone]
            s.setting=landmark and ns.AthenaLoreCodex.Setting(place,s.sceneId..'/'..edition,s.story.knowledgeContext)
                or ns.AthenaWorldScenes.Setting(place,s.sceneId..'/'..edition,variants)
                or ns.AthenaLoreCodex.Setting(place,s.sceneId..'/'..edition,s.story.knowledgeContext)
                or ns.AthenaWorldSettings.Get(place.zone,s.story.worldEnvironment)
            if s.setting then settings[place.zone]=true end
        end
        ns.AthenaLoreCodex.Mark(s.setting,loreUsed)
        if s.focus=='QUEST' then local ref=Reference(s)
            if M.Lore() then s.figure=ns.AthenaLoreCodex.Pick(s,ref,loreUsed,s.sceneId..'/'..edition) or ns.AthenaWorldScenes.Figure(ref,s.sceneId..'/'..edition,figures) end
            local figure=s.figure and ns.AthenaWorldScenes.NamedFigure(s.figure.title);if figure then figures[figure.key]=true end
            s.sameNPC=ref and ref.giverIDs[1] and npcs[ref.giverIDs[1]]
            if ref and ref.giverIDs[1] then npcs[ref.giverIDs[1]]=true end
        elseif s.focus=='ACTIVITY' and M.Lore() then s.figure=ns.AthenaLoreCodex.Pick(s,nil,loreUsed,s.sceneId..'/'..edition) end
        if s.figure and s.figure.subjectKind=='creature' then speciesChapters[speciesChapter]=true end
        if not recallUsed[s.story.storyId] and (s.focus=='QUEST' or s.focus=='ACTIVITY' or s.focus=='INTERLUDE') then
            local recall=First({claims=s.story.factualClaims},'metis_close_call_callback')
            if recall then s.metisRecall=recall;recallUsed[s.story.storyId]=true end
        end
        if here and s.focus~='MEMORY' then previous={claim=here,gaps=s.story.timeCoverage.gaps} end
        previousScene=s
        end
    end
end
local function HasExperience(s) return First(s,'owner_combat_experience') or First(s,'owner_creature_credits') or First(s,'owner_recorded_death') end
local function Units(plan,length)
    local units={};local scenes=plan.novelScenes;local at=1
    while at<=#scenes do
        local first=scenes[at];local parts={first};local recipe='SCENE'
        if first.focus=='QUEST' then
            local ids={};local c=First(first,'owner_quest_accepted') or First(first,'owner_quest_turnin') or First(first,'owner_quest_objective') or First(first,'owner_quest_removed')
            if c then ids[c.value.questID]=true end
            for i=at+1,math.min(#scenes,at+2) do local s=scenes[i]
                local q=First(s,'owner_quest_accepted') or First(s,'owner_quest_turnin') or First(s,'owner_quest_objective') or First(s,'owner_quest_removed')
                if s.focus~='QUEST' or s.chapterId~=first.chapterId or s.beat~=first.beat or not q or ids[q.value.questID] then break end
                ids[q.value.questID]=true;parts[#parts+1]=s
            end
            if #parts>=2 then recipe='QUEST_WEAVE'
            else parts={first};local next=scenes[at+1]
                if next and next.focus=='QUEST' and next.chapterId==first.chapterId and not first.prior and not next.prior and not HasExperience(first) and not HasExperience(next) and not first.figure and not next.figure then
                    local a,b=Reference(first),Reference(next)
                    if M.Lore() and a and b and a.giverIDs[1] and a.giverIDs[1]==b.giverIDs[1] and First(first,'owner_quest_accepted') and First(next,'owner_quest_accepted') and First(first,'owner_quest_turnin') and First(next,'owner_quest_turnin') then recipe='QUEST_PAIR';parts[2]=next
                    elseif not a and not b and First(first,'owner_quest_turnin') and First(next,'owner_quest_turnin') then recipe='SPARSE_PAIR';parts[2]=next end
                end
            end
        elseif first.focus=='ACTIVITY' and length~='Short' and not first.preEncounterMemories and not first.ownProtection then
            local place=first.story.node.place or {};local boss
            if (first.story.storyKind=='RAID' or first.story.storyKind=='DUNGEON') and place.instanceID then
                parts={}
                for i=at,math.min(#scenes,at+5) do local s=scenes[i];local p=s.story.node.place or {};local attempts={}
                    if s.focus~='ACTIVITY' or s.chapterId~=first.chapterId or s.story.storyKind~=first.story.storyKind or p.instanceID~=place.instanceID or p.difficultyID~=place.difficultyID or s.preEncounterMemories or s.ownProtection or HasExperience(s) then break end
                    local valid=true;for _,c in ipairs(s.claims) do if c.claimType=='encounter_attempt' then attempts[#attempts+1]=c;if not boss then boss=c.value.boss end;if c.value.boss~=boss or c.value.outcome~='SUCCESS' and c.value.outcome~='FAILURE' then valid=false end end end
                    if #attempts==0 or not valid then break end;parts[#parts+1]=s
                end
                if #parts>=2 then recipe='BATTLE_CAMPAIGN' else parts={first} end
            end
        end
        local unit={scene=first,scenes=parts,recipe=recipe,at=first.at,scope='Chronological permitted developments; no invented common cause',pacing=#parts>1 and 'COMPOSED_SCENE' or first.focus=='INTERLUDE' and 'INTERLUDE' or 'SCENE'}
        for _,s in ipairs(parts) do if s.metisRecall and not first.metisRecall then first.metisRecall=s.metisRecall end end
        units[#units+1]=unit;at=at+#parts
    end
    plan.metisUnits=units;plan.metisLength=length
end
function M.Prepare(plan,length)
    M.Check(plan.index)
    if plan.metisPrepared and plan.metisLength==length then return plan end
    if not plan.metisPrepared then
        if plan.threadType~='PROGRESSION' then
            local retained={};plan.quietGrowth={}
            for _,s in ipairs(plan.novelScenes) do
                if s.focus=='MILESTONE' and First(s,'owner_level_change') and not First(s,'owner_achievement') then
                    plan.quietGrowth[#plan.quietGrowth+1]=s
                else retained[#retained+1]=s end
            end
            plan.novelScenes=retained
        end
        Consolidate(plan);plan.manuscriptMemory=M.Memory.ForPlan(plan,plan.index)
    end
    Context(plan);ns.Metis.Calliope.Prepare(plan);Units(plan,length);plan.metisPrepared=true;plan.director=M.VERSION
    return plan
end
function M.PlanThread(thread,volume,library)
    local plan=raw.plan(thread,volume,library);plan.index=library.index;plan.threadType=thread.type;plan.firstAt=volume and volume.firstAt;plan.director=M.VERSION;return plan
end
function M.Render(plan,length)
    length=length or 'Chapter';M.Prepare(plan,length)
    local blocks=M.Voice()=='Natural Fantasy' and raw.author(plan,length) or raw.record(plan,length)
    blocks=M.Editor.Review(plan,blocks);blocks=ns.AthenaRecollections.Apply(plan,blocks);M.Memory.Commit(plan,blocks);return ns.AthenaBookIllustrations.Decorate(plan,blocks)
end
function M.TryRender(plan,length)
    local ok,blocks=pcall(M.Render,plan,length)
    if not ok then return nil,tostring(blocks) end
    return blocks
end
function M.Compose(story,length)
    local plan={owner=story.observerOwner,episodes={story},index=story.narrativeIndex}
    D.Plan(plan,plan.index);local blocks=M.Render(plan,length)
    story.narrativeLedger=plan.narratedDevelopmentLedger;story.metisEditorial=plan.metisEditorial
    local text={};for _,b in ipairs(blocks) do if not b.privateMemory and not b.recollection then text[#text+1]=b.text end end;story.narrativeSearch=table.concat(text,' ')
    return blocks
end
function M.RenderStory(story,length)
    if M.Voice()=='Natural Fantasy' then return M.Compose(story,length) end
    local plan={owner=story.observerOwner,episodes={story},index=story.narrativeIndex}
    M.Check(plan.index);return ns.AthenaRecollections.Apply(plan,M.Editor.Review(plan,raw.recordStory(story,length)))
end
function M.TryStory(story,length)
    local ok,blocks=pcall(M.RenderStory,story,length)
    if not ok then return nil,tostring(blocks) end
    return blocks
end
function M.FrontMatter(plan,thread,volume,index,demo)
    M.Check(index)
    local blocks={{kind='title',text=thread.type=='LIFE' and 'The Chronicles of '..P.Text(index.ownerIdentity and index.ownerIdentity.name,'an adventurer') or thread.title}}
    if volume then blocks[#blocks+1]={kind='meta',text=(demo and 'SYNTHETIC • ' or '')..'Volume '..volume.ordinal..' • '..thread.title} end
    if #plan.episodes>0 and plan.prologue and M.Lore() and not ns.DB.journalPrologueHidden then
        blocks[#blocks+1]={id='prologue',kind='heading',text='Prologue — The World Before'}
        for _,card in ipairs(plan.prologue) do blocks[#blocks+1]={id='prologue/'..card.worldRef,text=card.text} end
        local first=plan.episodes[1];local bridge=ns.AthenaWorldSettings.Bridge(index.ownerIdentity,first and first.node.place and first.node.place.zone)
        if bridge then blocks[#blocks+1]={text=bridge} end
    end
    return blocks
end
-- Compatibility entry points delegate to one director; they hold no second
-- narrator or competing manuscript state. Reader and collectors stay separate.
P.Process=M.Process;P.PlanThread=M.PlanThread;P.RenderThread=M.Render;P.Render=M.RenderStory
C.Voice.Compose=M.Compose;C.Voice.RenderThread=M.Render;A.Render=M.Render
