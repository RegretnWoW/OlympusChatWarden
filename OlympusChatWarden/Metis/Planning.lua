-- Pure deterministic scenes and paragraph composition over supported claims.
local _,ns=...
local P={VERSION=4};ns.AthenaStoryPlanner=P
function P.Text(value,fallback,limit)
    if type(value)~='string' or not ns.CanRead(value) then return fallback end
    value=value:gsub('|H.-|h(.-)|h','%1'):gsub('|T.-|t',''):gsub('|A.-|a',''):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('|H.*$',''):gsub('|',''):gsub('[%c]',' '):gsub('%s+',' '):match('^%s*(.-)%s*$')
    local out={};local count=0
    for ch in value:gmatch('[%z\1-\127\194-\244][\128-\191]*') do if count+#ch>(limit or 160) then break end;out[#out+1]=ch;count=count+#ch end
    local text=table.concat(out);return text~='' and text or fallback
end
local function Count(n,cap)
    local s=({'one','two','three','four','five','six','seven','eight','nine','ten','eleven','twelve'})[n] or tostring(n)
    return cap and s:gsub('^%l',string.upper) or s
end
local function Seed(id) local h=P.VERSION;for i=1,#id do h=(h*33+id:byte(i))%2147483647 end;return h end
local function Choose(s,values,salt) return values[(s.plan.seed+(salt or 0))%#values+1] end
local function Group(s,kind) return s.plan.claims[kind] or {} end
local function All(s,kinds) local out={};for _,k in ipairs(kinds) do for _,c in ipairs(Group(s,k)) do out[#out+1]=c end end;return out end
local function Paragraph(text,claims,role)
    local p={text=text,claimIds={},evidenceRefs={},kind=role or 'body'};local ci,ri={},{}
    for _,c in ipairs(claims) do
        if not ci[c.claimId] then ci[c.claimId]=true;p.claimIds[#p.claimIds+1]=c.claimId end
        for _,ref in ipairs(c.evidenceRefs) do if not ri[ref] then ri[ref]=true;p.evidenceRefs[#p.evidenceRefs+1]=ref end end
    end
    return p
end
local function Scene(s,kind,role,claims,relevance)
    if #claims==0 then return end
    local para=Paragraph('',claims);local scene={type=kind,narrativeRole=role,startAt=not s.timeCoverage.unknownStart and s.firstObservedAt or nil,endAt=not s.timeCoverage.unknownEnd and s.lastObservedAt or nil,
        firstObservedAt=s.firstObservedAt,lastObservedAt=s.lastObservedAt,orderBasis='observed chronology; not inferred causality',
        subject=s.observerOwner,subjectGUID=s.observerOwner:match('/(Player%-.+)$'),place=s.node.place,placeRefs={s.node.sourceRef},supportedClaimIds=para.claimIds,evidenceRefs=para.evidenceRefs,
        certainty=s.supportState,relevance=relevance or 1,relatedStories={}}
    if kind=='connections' then for _,link in ipairs(s.plan.links) do scene.relatedStories[#scene.relatedStories+1]=link.storyId end end
    s.plan.scenes[#s.plan.scenes+1]=scene
end
local function QuestCounts(s,kind)
    local claims=Group(s,kind);local seen,n={},0
    for _,c in ipairs(claims) do if not seen[c.value.questID] then seen[c.value.questID]=true;n=n+1 end end
    return n,claims
end
local function Outcome(s,detail)
    local clauses,refs={},{};local wins,losses=0,0
    local keys={};for id in pairs(s.encounters) do keys[#keys+1]=id end;table.sort(keys)
    for _,id in ipairs(keys) do local b=s.encounters[id];wins=wins+b.successes;losses=losses+b.failures
        local cc={};for _,kind in ipairs({'confirmed_failed_attempts','confirmed_success','uncertain_outcome'}) do for _,c in ipairs(Group(s,kind)) do if c.value.boss==id then cc[#cc+1]=c;refs[#refs+1]=c end end end
        if detail then
            local name=P.Text(b.name,'the foe')
            if b.failures>0 and b.successes==1 and b.unknown==0 and b.attempts[#b.attempts].outcome=='SUCCESS' then
                clauses[#clauses+1]=Count(b.failures,true)..(b.failures==1 and ' attempt against ' or ' attempts against ')..name..' ended in defeat before a later attempt brought victory.'
            else
                if b.failures>0 then clauses[#clauses+1]=Count(b.failures,true)..(b.failures==1 and ' attempt against ' or ' attempts against ')..name..' ended in defeat.' end
                if b.successes>0 then clauses[#clauses+1]=name..(b.successes==1 and ' was defeated.' or ' was defeated in '..Count(b.successes)..' attempts.') end
            end
            if b.unknown>0 then clauses[#clauses+1]='The conclusion of '..(b.unknown==1 and 'another attempt' or 'other attempts')..' against '..name..' remains uncertain.' end
        end
    end
    if not detail and #keys>0 then
        if wins>0 then clauses[#clauses+1]='Victory came in '..Count(wins)..(wins==1 and ' encounter' or ' encounters')..(losses>0 and ', alongside '..Count(losses)..(losses==1 and ' failed attempt.' or ' failed attempts.') or '.')
        elseif losses>0 then clauses[#clauses+1]=Count(losses,true)..(losses==1 and ' attempt ended' or ' attempts ended')..' in defeat.' end
        if #Group(s,'uncertain_outcome')>0 then clauses[#clauses+1]='Other conclusions remain uncertain.' end
    end
    if wins==0 and #Group(s,'no_recorded_victory')>0 then
        clauses[#clauses+1]=(s.timeCoverage.partial or s.timeCoverage.unknownEnd or s.timeCoverage.gaps) and 'The surviving account offers no certain victory.' or 'This expedition ends without a known victory.'
        for _,c in ipairs(Group(s,'no_recorded_victory')) do refs[#refs+1]=c end
    end
    for _,c in ipairs(Group(s,'owner_duel_result')) do clauses[#clauses+1]=c.value.result=='win' and 'I won the duel.' or 'I lost the duel.';refs[#refs+1]=c end
    if s.storyKind=='DUEL' and #Group(s,'owner_duel_result')==0 then clauses[#clauses+1]='How the duel ended remains unknown.';for _,c in ipairs(All(s,{'observed_place','owner_duel_accepted'})) do refs[#refs+1]=c end end
    if s.storyKind=='BATTLEGROUND' then
        clauses[#clauses+1]=#Group(s,'match_ended')>0 and 'The match reached its end, but its result for me remains uncertain.' or 'My time here holds no certain match result.'
        for _,c in ipairs(All(s,{'observed_place','match_observed','match_ended'})) do refs[#refs+1]=c end
    end
    if s.storyKind=='WORLD_PVP' then clauses[#clauses+1]='I crossed paths with another player in combat. The outcome remains untold.';for _,c in ipairs(Group(s,'owner_world_pvp')) do refs[#refs+1]=c end end
    return table.concat(clauses,' '),refs
end
local function Opening(s)
    local c=Group(s,'observed_place')[1];if not c then return '',{} end
    local place=P.Text(c.value,'an unnamed place');local genre=s.storyKind
    if genre=='SAGA' then return 'My story in '..place..' stretches across '..Count(#(s.episodes or {}))..' distinct expedition chapters.',All(s,{'observed_place','saga_episode'}) end
    if genre=='QUESTING' then return Choose(s,{'My journey through '..place..' gathered a new chapter of quests.','In '..place..', the work of my journey took shape.','Quests marked this stretch of my time in '..place..'.','My tale in '..place..' turns to the tasks along the way.'}),{c} end
    if genre=='RAID' or genre=='DUNGEON' then
        if s.timeCoverage.unknownStart then return 'My account in '..place..' begins with the expedition already under way.',{c} end
        return Choose(s,{'My path led into '..place..'.','I entered '..place..' for another expedition.','The journey took me into '..place..'.','An expedition in '..place..' became part of my tale.'}),{c}
    end
    if genre=='DUEL' then return 'A duel became part of my story in '..place..'.',{c} end
    if genre=='WORLD_PVP' then return 'An encounter in '..place..' belongs to this part of my tale.',{c} end
    if genre=='BATTLEGROUND' then return 'My journey reached '..place..', a battleground in this part of my tale.',{c} end
    if genre=='PROGRESSION' then return 'In '..place..', another milestone marked my journey.',{c} end
    return Choose(s,{'My tale pauses briefly in '..place..'.',place..' holds a quiet moment in my chronicle.','A moment in '..place..' belongs to this part of my journey.','I spent a moment of this tale in '..place..'.'}),{c}
end
local function Questing(s,detail)
    local parts,refs={},{}
    local function Add(text,claims) if #claims>0 then parts[#parts+1]=text;for _,c in ipairs(claims) do refs[#refs+1]=c end end end
    local turnins=QuestCounts(s,'owner_quest_turnin')
    local n,cc=QuestCounts(s,'owner_quest_accepted');if n>0 and (detail or turnins==0) then Add(n==1 and 'I took on a task.' or ('I took on '..Count(n)..' tasks.'),cc) end
    cc=Group(s,'owner_quest_objective');if #cc>0 and (detail or #parts==0 and turnins==0) then
        local finished,progress=false,false;for _,c in ipairs(cc) do if c.value.finished==true then finished=true end;if type(c.value.fulfilled)=='number' and c.value.fulfilled>0 then progress=true end end
        Add(finished and 'A quest objective was marked finished.' or progress and 'I made progress toward a quest objective.' or 'A quest objective remained in my log without established progress.',cc)
    end
    n,cc=QuestCounts(s,'owner_quest_turnin')
    if n>0 then
        local text=n==1 and 'I completed a task.' or ('I completed '..Count(n)..' tasks.')
        Add(text,cc)
    end
    cc=Group(s,'owner_quest_observed');if #parts==0 and #cc>0 then Add('A quest was present in my log; its completion is not established here.',cc) end
    cc=Group(s,'owner_quest_removed');local removed={};local completed={};for _,c in ipairs(Group(s,'owner_quest_turnin')) do completed[c.value.questID]=true end;for _,c in ipairs(cc) do if not completed[c.value.questID] then removed[#removed+1]=c end end;cc=removed;if #cc>0 and (detail or #parts==0) then Add('A quest left my log. What led to its removal is unknown.',cc) end
    return table.concat(parts,' '),refs
end
local function Milestones(s,detail)
    local parts,refs={},{}
    local function Add(text,c) parts[#parts+1]=text;refs[#refs+1]=c end
    local levels=Group(s,'owner_level_change')
    if #levels>0 then
        local last=levels[#levels];local before,after=last.value.before,last.value.after
        Add(after>before and ('I advanced to level '..after..'.') or ('My level changed from '..before..' to '..after..'.'),last)
    end
    local achievements=Group(s,'owner_achievement')
    if #achievements==1 then Add('I earned '..(P.Text(achievements[1].value.name) or 'an achievement')..'.',achievements[1])
    elseif #achievements>1 then for _,c in ipairs(achievements) do refs[#refs+1]=c end;parts[#parts+1]='I earned '..Count(#achievements)..' achievements.' end
    local loot=Group(s,'owner_item_receipt')
    if #loot>0 then
        if detail then for _,c in ipairs(loot) do Add('I received '..P.Text(c.value.name,'an item')..' during this part of the journey.',c) end
        else for _,c in ipairs(loot) do refs[#refs+1]=c end;parts[#parts+1]=#loot==1 and ('I received '..P.Text(loot[1].value.name,'an item')..'.') or 'Items came into my possession along the way.' end
    end
    if detail or #parts==0 then
        local equipment=Group(s,'owner_equipment_change');if #equipment>0 then parts[#parts+1]='My equipment changed.';for _,c in ipairs(equipment) do refs[#refs+1]=c end end
        local spells=Group(s,'owner_spell_learned');if #spells>0 then parts[#parts+1]='I learned '..(#spells==1 and 'an ability.' or 'new abilities.');for _,c in ipairs(spells) do refs[#refs+1]=c end end
        for _,c in ipairs(Group(s,'owner_skill_change')) do Add('My '..P.Text(c.value.name,'profession')..' skill stood at '..tostring(c.value.after)..'.',c) end
        local xp=Group(s,'owner_xp_gain');if #xp>0 and #levels==0 then parts[#parts+1]='I gained experience along the way.';for _,c in ipairs(xp) do refs[#refs+1]=c end end
    end
    return table.concat(parts,' '),refs
end
local function Connections(s)
    local text,refs={},{}
    for _,c in ipairs(Group(s,'later_victory')) do text[#text+1]='I had faced defeat against this foe in an earlier expedition; a later chapter now holds a victory.';refs[#refs+1]=c end
    local companion=Group(s,'recurring_companion')[1]
    if companion then text[#text+1]=(P.Text(companion.value.name) or 'A familiar party member')..' appears on another dated company roll.';refs[#refs+1]=companion end
    local player=Group(s,'recurring_player')[1];if player then text[#text+1]=(P.Text(player.value.name) or 'The same player')..' appeared in another chapter of my travels.';refs[#refs+1]=player end
    local visit=Group(s,'zone_return')[1];if visit then text[#text+1]='I had visited this place in an earlier part of my journey.';refs[#refs+1]=visit end
    for _,kind in ipairs({'quest_continued','quest_resolved','quest_unresolved'}) do
        local c=Group(s,kind)[1]
        if c then text[#text+1]=kind=='quest_resolved' and 'Work begun in an earlier chapter reached a recorded turn-in here.' or kind=='quest_continued' and 'An unfinished task from an earlier chapter returned to this part of my journey.' or 'A task from an earlier chapter left my log without a confirmed conclusion.';refs[#refs+1]=c end
    end
    return table.concat(text,' '),refs
end
function P.Process(s)
    local plan={version=P.VERSION,seed=Seed(s.storyId),claims={},scenes={},links={}};s.plan=plan
    for _,c in ipairs(s.factualClaims) do local group=plan.claims[c.claimType] or {};plan.claims[c.claimType]=group;group[#group+1]=c
        if type(c.value)=='table' and c.value.priorStory then plan.links[#plan.links+1]={storyId=c.value.priorStory,claimIds={c.claimId},evidenceRefs=c.evidenceRefs,at=c.value.at} end
    end
    local turnins=QuestCounts(s,'owner_quest_turnin');local accepts=QuestCounts(s,'owner_quest_accepted');local attempts,wins,losses=0,0,0;local boss
    for _,b in pairs(s.encounters) do attempts=attempts+#b.attempts;wins=wins+b.successes;losses=losses+b.failures;if not boss or b.id<boss.id then boss=b end end
    local milestones=#Group(s,'owner_level_change')+#Group(s,'owner_achievement')+#Group(s,'owner_spell_learned')+#Group(s,'owner_equipment_change')
    local objectiveProgress=false;for _,c in ipairs(Group(s,'owner_quest_objective')) do if c.value.finished==true or type(c.value.fulfilled)=='number' and c.value.fulfilled>0 then objectiveProgress=true end end
    local richQuest=s.storyKind=='QUESTING' and (turnins>=3 or turnins>=1 and milestones>0 or accepts>=2 and objectiveProgress)
    s.form=s.storyKind=='SAGA' and #(s.episodes or {})>=2 and 'SAGA' or (attempts>0 or richQuest or milestones>=2) and 'CHAPTER' or 'MOMENT'
    local place=Group(s,'observed_place')[1];local name=place and P.Text(place.value,'The journey') or 'The journey';local levels=Group(s,'owner_level_change')
    if s.form=='SAGA' then s.title=name..' — The '..(boss and P.Text(boss.name,'raid') or 'raid')..' expeditions'
    elseif s.storyKind=='QUESTING' then s.title=name..(#levels>0 and (' — Level '..levels[#levels].value.after) or ' — Quests along the way')
    elseif attempts>0 then s.title=name..(wins>0 and ' — A victory' or losses>=2 and (' — '..Count(losses,true)..' defeats') or ' — An unfinished challenge')
    elseif #levels>0 then s.title=name..' — Level '..levels[#levels].value.after
    elseif s.storyKind=='DUEL' then local r=Group(s,'owner_duel_result')[1];s.title=name..(r and (r.value.result=='win' and ' — A duel won' or ' — A duel lost') or ' — An uncertain duel')
    elseif s.storyKind=='BATTLEGROUND' then s.title=name..' — A battleground account'
    elseif s.storyKind=='WORLD_PVP' then s.title=name..' — A world encounter'
    else s.title='A moment in '..name end
    s.featured=s.featured or s.form=='SAGA' or richQuest or #levels>0 or #Group(s,'owner_achievement')>0
    Scene(s,'place','opening',Group(s,'observed_place'))
    Scene(s,'company','context',Group(s,'roster_point_count'))
    Scene(s,'questing','progress',All(s,{'owner_quest_accepted','owner_quest_observed','owner_quest_objective','owner_quest_turnin','owner_quest_removed'}),3)
    Scene(s,'encounters','resolution',All(s,{'confirmed_failed_attempts','confirmed_success','uncertain_outcome','no_recorded_victory','owner_duel_result','match_ended'}),5)
    Scene(s,'milestones','turning_point',All(s,{'owner_level_change','owner_achievement','owner_item_receipt','owner_spell_learned','owner_equipment_change','owner_skill_change','owner_xp_gain'}),4)
    Scene(s,'connections','reflection',All(s,{'later_victory','recurring_companion','recurring_player','zone_return','saga_episode'}),2)
    s.summary=Opening(s);s.proseBlocks=nil;plan.beats={};return plan
end
-- A volume is a reading window, not another event. Only hydrated episode
-- claims enter its prose; all memberships still point at the original story.
function P.PlanThread(thread,volume,library)
    local plan={version=P.VERSION,threadId=thread.id,lifeStoryId=library.index and library.index.threads.lifeId,volumeId=volume and volume.id,owner=thread.owner,scenes={},episodes={},links={}}
    local ix=library.index;plan.worldSignature=ns.AthenaWorldKnowledge and ns.AthenaWorldKnowledge.Signature()
    if thread.type=='LIFE' and (not volume or volume.ordinal==1) and ns.AthenaWorldKnowledge then plan.prologue=ns.AthenaWorldKnowledge.Prologue(ix and ix.ownerIdentity) end
    for _,id in ipairs(volume and volume.episodeIds or {}) do local s=library.byID[id]
        if s and s.supportState~='INSUFFICIENT' and s.observerOwner==thread.owner then
            plan.episodes[#plan.episodes+1]=s
            local role=s.storyStatus=='SUCCESS' and 'resolution' or #Group(s,'confirmed_failed_attempts')>0 and 'setback' or #Group(s,'owner_level_change')>0 and 'milestone' or 'development'
            plan.scenes[#plan.scenes+1]={storyId=id,role=role,at=s.firstObservedAt,claims=s.factualClaims,evidenceRefs=s.sourceEvidenceRefs,coverage=s.timeCoverage}
        end
    end
    ns.AthenaNarrativeScenes.Plan(plan,ix)
    return plan
end
function P.WorldPassages(s,length)
    local W=ns.AthenaWorldKnowledge;if not W then return {} end
    local out,seen={},{};local limit=length=='Short' and 1 or length=='Epic' and 6 or 3
    for _,kind in ipairs({'owner_quest_turnin','owner_quest_accepted','owner_quest_objective','owner_quest_observed','owner_quest_removed'}) do
        for _,c in ipairs(Group(s,kind)) do if not seen[c.value.questID] and #out<limit then
            local m=W.QuestMeaning(c,s.worldEnvironment,ns.AthenaJournal.WorldLookup(s));seen[c.value.questID]=true
            if m and m.reference.premise and m.stage~='UNRESOLVED' then
                local card=m.reference
                local intro=({BEGAN='A new task became part of this chapter.',CONTINUED='An unfinished task continued here.',OBSERVED='A task remained unfinished.',COMPLETED='A task reached its conclusion here.'})[m.stage]
                local paragraph=Paragraph(intro..' Its reference brief describes the work: “'..P.Text(card.premise,'',900)..'”',{c},'quest_context')
                paragraph.worldRefs=m.worldRefs;paragraph.worldFacts={card};paragraph.questID=m.questID;paragraph.stage=m.stage
                paragraph.qualification=m.qualification;out[#out+1]=paragraph
            end
        end end
    end
    return out
end
function P.RenderThread(plan,length)
    if ns.AthenaChronicler and ns.AthenaChronicler.Voice()=='Natural Fantasy' then return ns.AthenaChronicler.RenderThread(plan,length) end
    local out={};local stories=plan.episodes
    if #stories==0 then return out end
    local selected=stories
    if length=='Short' and #stories>2 then
        local best=stories[1];local score=-1
        for _,s in ipairs(stories) do local value=(#Group(s,'confirmed_success')>0 and 10 or 0)+(#Group(s,'owner_level_change')>0 and 5 or 0)+(#Group(s,'confirmed_failed_attempts')>0 and 4 or 0)+(#Group(s,'owner_quest_turnin')>0 and 3 or 0)
            if value>=score then best=s;score=value end
        end
        selected={stories[1]};if best~=stories[1] then selected[#selected+1]=best elseif stories[#stories]~=best then selected[#selected+1]=stories[#stories] end
    end
    if plan.bridge then out[#out+1]={text=plan.bridge.text,kind='editorial_bridge',storyId=plan.bridge.storyId,evidenceRefs=plan.bridge.evidenceRefs,claimIds={},worldRefs={},at=plan.bridge.at,title='The preceding chapter',coverage={gaps=true},derivation='Prior dated anchor only; no invented intervening activity'} end
    for ordinal,s in ipairs(selected) do
        local text,claims={},{}
        local function Add(value,cc) if value~='' and #cc>0 then text[#text+1]=value;for _,c in ipairs(cc) do claims[#claims+1]=c end end end
        local place=Group(s,'observed_place');local name=place[1] and P.Text(place[1].value,'an unnamed place') or 'an unnamed place'
        local intro
        if plan.threadId:find('/ZONE/',1,true) then intro=ordinal==1 and ('This part of my tale unfolds in '..name..'.') or ('Another dated chapter belongs to my time in '..name..'.')
        else
            local openings={'One chapter of my journey unfolds in '..name..'.','My tale turns to '..name..'.','In '..name..', another part of my journey takes shape.','This chapter belongs to my time in '..name..'.'}
            intro=openings[(Seed(plan.threadId)+ordinal-1)%#openings+1]
        end
        Add(intro,place)
        local quests,qc=Questing(s,length=='Epic');local turninCount=QuestCounts(s,'owner_quest_turnin');if turninCount>1 then
            quests=quests:gsub('I turned in '..Count(turninCount)..' quests%.',Count(turninCount,true)..' quests reached their conclusion here.')
        elseif #Group(s,'owner_quest_turnin')==1 and length~='Epic' then
            quests='A task reached its conclusion here.'
        end
        Add(quests,qc)
        local outcome,oc=Outcome(s,true);Add(outcome,oc)
        local growth,gc=Milestones(s,length=='Epic');Add(growth,gc)
        if length~='Short' then local bridge,bc=Connections(s);Add(bridge,bc) end
        if length=='Epic' and s.form~='MOMENT' then
            local company=Group(s,'roster_point_count')[1]
            if company then Add('The company numbered '..Count(company.value)..' at one gathering.',{company}) end
            local attempts=Group(s,'encounter_attempt');local unknown={}
            for _,c in ipairs(attempts) do if c.value.outcome=='UNKNOWN' or c.value.outcome=='CONFLICTING' then unknown[#unknown+1]=c end end
            if #unknown>0 then Add('Some encounters remain without a certain ending.',unknown) end
        end
        local para=Paragraph(table.concat(text,' '),claims,'chapter');para.storyId=s.storyId;para.episodeIds={s.storyId};para.at=s.firstObservedAt;para.title=s.title
        para.coverage=s.timeCoverage;para.derivation='Selected episode claims; chronology is reading order, not proof of continuous activity or causality'
        if #claims>0 then out[#out+1]=para end
        for _,b in ipairs(P.WorldPassages(s,length)) do b.storyId=s.storyId;b.episodeIds={s.storyId};b.at=s.firstObservedAt;b.title='The work behind this chapter';out[#out+1]=b end
        for _,b in ipairs(ns.AthenaStoryContributions and ns.AthenaStoryContributions.Render(s) or {}) do
            local p=Paragraph(b.text,{b.claim},'module_context');p.storyId=s.storyId;p.episodeIds={s.storyId};p.at=s.firstObservedAt;p.title='People and moments along the way';out[#out+1]=p
        end
    end
    return out
end
function P.Render(s,length)
    if not s.plan then return {} end
    local output={}
    local function Put(parts)
        local text,claims={},{};for _,part in ipairs(parts) do if part[1]~='' and #part[2]>0 then text[#text+1]=part[1];for _,c in ipairs(part[2]) do claims[#claims+1]=c end end end
        if #text>0 then output[#output+1]=Paragraph(table.concat(text,' '),claims) end
    end
    local opening,oc=Opening(s);local result,rc=Outcome(s,length~='Short');local quests,qc=Questing(s,length~='Short');local progress,pc=Milestones(s,length=='Epic');local connections,cc=Connections(s)
    if s.form=='MOMENT' then Put({{opening,oc},{quests,qc},{result,rc},{progress,pc}});if connections~='' then Put({{connections,cc}}) end;return output end
    if length=='Short' then Put({{opening,oc},{quests,qc},{result,rc},{progress,pc}});return output end
    local company=Group(s,'roster_point_count')[1];local companyText=company and ('A dated company roll listed '..Count(company.value)..' people during the expedition.') or ''
    Put({{opening,oc},{companyText,company and {company} or {}}})
    if length=='Epic' and (#s.plan.scenes>=3 or s.form=='SAGA') then
        if s.form=='SAGA' then
            for _,c in ipairs(Group(s,'saga_episode')) do local date=ns.SafeCall(_G.date,'%Y-%m-%d',c.value.at) or 'A dated expedition';Put({{date..' marks a distinct chapter in these expeditions.',{c}}}) end
        end
        Put({{quests,qc}})
        local attempts=Group(s,'encounter_attempt')
        if #attempts>=2 and #attempts<=6 and s.form~='SAGA' then
            for _,c in ipairs(attempts) do
                local when=ns.SafeCall(_G.date,'%H:%M',c.value.at) or 'One moment'
                local outcome=({SUCCESS='victory',FAILURE='defeat'})[c.value.outcome]
                Put({{when..' marks an attempt against '..P.Text(c.value.name,'the foe')..(outcome and (' that ended in '..outcome..'.') or ' whose ending remains uncertain.'),{c}}})
            end
        end
        Put({{result,rc}});Put({{progress,pc}});Put({{connections,cc}})
    else Put({{quests,qc},{result,rc}});Put({{progress,pc}});Put({{connections,cc}}) end
    return output
end

ns.Metis.Register('Planning',P)
