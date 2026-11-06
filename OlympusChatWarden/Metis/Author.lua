-- Paragraph author over semantic scene plans. No event-to-sentence dispatch.
local _,ns=...
local A={VERSION='metis-calliope-1.2.0'};ns.AthenaLiteraryAuthor=A
local C=ns.Metis.Calliope
local function Text(v,fallback,n) return ns.AthenaStoryPlanner.Text(v,fallback,n or 600) end
local function Number(v) return ({'one','two','three','four','five','six','seven','eight','nine','ten','eleven','twelve'})[v] or tostring(v) end
local function Claims(scene,kind) local o={};for _,c in ipairs(scene.claims) do if c.claimType==kind then o[#o+1]=c end end;return o end
local function First(scene,kind) return Claims(scene,kind)[1] end
local function Lore() return not ns.DB or ns.DB.journalLore~=false end
local function Actor(s) return Text(s.characterName,'The adventurer') end
local function Form(scene,choices)
    return C.Choose(scene,choices,'author')
end
local function Sentence(text,claims,world)
    return {text=text,claims=claims or {},world=world,assertionStrength=world and 'CONTEXTUAL' or 'DIRECT'}
end
local function Block(scene,clauses,role)
    if scene.metisRecall and (role=='scene' or role=='arrival' or role=='interlude') then
        local c=scene.metisRecall
        table.insert(clauses,1,Sentence(Form(scene,{
            'This was the country where an earlier fight had brought '..Actor(scene.story)..' close to death.',
            'Long before this return, '..Actor(scene.story)..' had come close to death in the fighting here.'}),{c}))
    end
    if scene.transition and (role=='scene' or role=='arrival' or role=='interlude') then table.insert(clauses,1,scene.transition) end
    if scene.returnVisit and (role=='scene' or role=='arrival') then
        table.insert(clauses,1,Sentence('The journey brought '..Actor(scene.story)..' back to '..Text((scene.place or scene.story.node.place).zone,'this place')..'.',{scene.returnVisit}))
    end
    local b={blockId=scene.sceneId..'/'..role,sceneId=scene.sceneId,chapterId=scene.chapterId,storyId=scene.story.storyId,
        at=scene.at,title=scene.title,chapterAt=scene.chapterAt,kind='body',recipeId=A.VERSION..'/'..scene.focus..'/'..role,
        claimIds={},evidenceRefs={},worldRefs={},worldFacts={},clauses={},episodeIds={},developmentIds=scene.primaryDevelopmentIds,storycraftVersion=C.VERSION}
    local texts,claims,refs,worlds={},{},{},{}
    for _,s in ipairs(scene.stories) do b.episodeIds[#b.episodeIds+1]=s.storyId end
    for _,c in ipairs(clauses) do if c.text and c.text~='' then
        texts[#texts+1]=c.text;local row={text=c.text,claimIds={},sourceRefs={},worldRefs={},assertionStrength=c.assertionStrength,recipeId=c.recipeId}
        for _,claim in ipairs(c.claims) do
            if claim.claimType=='private_protection' or claim.claimType=='private_correction' then b.privacy='OWNER_PRIVATE';b.ownerPrivate=true;row.ownerPrivate=true end
            row.claimIds[#row.claimIds+1]=claim.claimId
            if not claims[claim.claimId] then claims[claim.claimId]=true;b.claimIds[#b.claimIds+1]=claim.claimId end
            for _,ref in ipairs(claim.evidenceRefs) do row.sourceRefs[#row.sourceRefs+1]=ref;if not refs[ref] then refs[ref]=true;b.evidenceRefs[#b.evidenceRefs+1]=ref end end
            for _,ref in ipairs(claim.worldRefs or {}) do row.worldRefs[#row.worldRefs+1]=ref;if not worlds[ref] then worlds[ref]=true;b.worldRefs[#b.worldRefs+1]=ref end end
            for _,fact in ipairs(claim.worldFacts or {}) do b.worldFacts[#b.worldFacts+1]=fact end
        end
        local identity=scene.story.narrativeIndex and scene.story.narrativeIndex.ownerIdentity
        if identity and identity.evidenceRef then
            row.sourceRefs[#row.sourceRefs+1]=identity.evidenceRef
            if not refs[identity.evidenceRef] then refs[identity.evidenceRef]=true;b.evidenceRefs[#b.evidenceRefs+1]=identity.evidenceRef end
        end
        if c.world then
            row.worldRefs[#row.worldRefs+1]=c.world.worldRef
            if c.world.questWorldRef then row.worldRefs[#row.worldRefs+1]=c.world.questWorldRef;if not worlds[c.world.questWorldRef] then worlds[c.world.questWorldRef]=true;b.worldRefs[#b.worldRefs+1]=c.world.questWorldRef end end
            if not worlds[c.world.worldRef] then worlds[c.world.worldRef]=true;b.worldRefs[#b.worldRefs+1]=c.world.worldRef;b.worldFacts[#b.worldFacts+1]=c.world end
        end
        b.clauses[#b.clauses+1]=row
    end end
    b.text=table.concat(texts,' ');return b
end
local function Goal(ref)
    local p=ref and Text(ref.premise,nil,700);if not p then return end
    p=p:match('^(.-[%.!?])%s') or p;p=p:gsub('[%.%s]+$','')
    local verbs={Bring='bringing',Collect='collecting',Gather='gathering',Recover='recovering',Retrieve='retrieving',Obtain='obtaining',Find='finding',
        Speak='speaking',Talk='talking',Report='reporting',Return='returning',Travel='traveling',Kill='defeating',Slay='defeating',Defeat='defeating',
        Deliver='delivering',Investigate='investigating',Search='searching',Escort='escorting',Take='taking',Use='using',Meet='meeting',Destroy='destroying'}
    local verb=p:match('^(%a+)');if verbs[verb] then
        p=verbs[verb]..p:sub(#verb+1)
        for original,gerund in pairs(verbs) do local lower=original:lower()
            p=p:gsub('then '..lower..'%f[%A]','then '..gerund):gsub('and '..lower..'%f[%A]','and '..gerund)
        end
        p=p:gsub('%f[%d](%d+)%f[%D]',function(v) local n=tonumber(v);return n and n<=12 and Number(n) or v end)
        local giver=ref and Text(ref.giverName)
        if giver then
            local escaped=giver:gsub('(%W)','%%%1')
            p=p:gsub(',? then returning to '..escaped..'.*$',''):gsub(',? then reporting back to '..escaped..'.*$','')
            p=p:gsub(' for '..escaped..'$','')
        end
        return p
    end
end
local function Request(ref,actor,done,scene)
    local p=ref and Text(ref.premise,nil,700);local giver=ref and Text(ref.giverName)
    if not p or not giver then return end
    p=p:match('^(.-[%.!?])%s') or p
    local wanted,forWhom=p:gsub('[%.%s]+$',''):match('^[Rr]etrieve (.-) for (.+)$')
    if wanted and forWhom==giver then
        return done and (actor..' fulfilled '..giver..'’s request to recover '..wanted..'.') or (giver..' sought '..wanted..', and '..actor..' took up the search.')
    end
    local object,recipient=p:gsub('[%.%s]+$',''):match('^[Bb]ring (.-) to (.+)$')
    if object and recipient:sub(1,#giver)==giver then
        object=object:gsub('^(%d+)',function(n) return Number(tonumber(n)) end)
        local need=object..recipient:sub(#giver+1)
        if done then return Form(scene,{actor..' fulfilled '..giver..'’s request for '..need..'.',
            'The request for '..need..' was fulfilled; '..actor..' had seen '..giver..'’s work through.'}) end
        return Form(scene,{giver..' needed '..need..', and '..actor..' took up the errand.',
            giver..'’s need for '..need..' became part of '..actor..'’s work'..(done and ', and the request was fulfilled.' or '.'),
            'For '..giver..', the matter was '..need..'. '..actor..(done and ' carried that errand through.' or ' took up the work.')})
    end
end
local function Backdrop(ref,scene)
    return ns.AthenaQuestContext.Opening(ref)
end
local function Motive(ref)
    if not ref or not ref.giverName or not ref.narrative then return end
    local wanted,opposed
    for _,a in ipairs(ref.narrative.atoms or {}) do if a.minimumStage<=2 and a.speakerNPCID==ref.giverIDs[1] then
        opposed=opposed or a.text:match('^I hate (.-)[!%.]')
        wanted=wanted or a.text:match('^But I sure like (.-)%.')
    end end
    if opposed and wanted then return ref.giverName..' hated '..opposed..', but liked '..wanted..'.' end
end
local function Reference(scene,id)
    local s=scene.story;local candidate={knowledgeContext=s.knowledgeContext,factualClaims=scene.claims}
    local ref,why=ns.Athena.Knowledge.ReferenceForStory(candidate,id)
    if ref then return ref end
    -- Preserve the private Lab's explicitly labelled mock knowledge adapter.
    -- Live readers never gain an external lore provider through this path.
    local lookup=s.demo and ns.AthenaJournal.WorldLookup(s)
    if lookup and why~='TITLE_CONFLICT' and why~='BUILD_CHANGED' and why~='REFERENCE_UNAVAILABLE' then
        local c=First(scene,'owner_quest_turnin') or First(scene,'owner_quest_accepted') or First(scene,'owner_quest_objective')
        local meaning=c and ns.AthenaWorldKnowledge.QuestMeaning(c,s.worldEnvironment,lookup)
        if meaning then ref=meaning.reference;ref.giverIDs=ref.giverIDs or {};return ref end
    end
end
local function Experience(scene,clauses)
    local actor=Actor(scene.story);local experience=ns.AthenaAdventureSummary.ChooseExperience(Claims(scene,'owner_combat_experience'))
    local chosen=experience and {claim=experience}
    local death=First(scene,'owner_recorded_death')
    if chosen then local c=chosen.claim;local d=c.value;local text
        if d.deaths>0 then
            text=actor..' fell during the fighting.'
            if d.endAlive==true then text=text..' Later, '..actor..' stood among the living again.' end
        else
            local crafted=C.Render('close_call',scene,{c})
            text=crafted and crafted.text or 'The fighting brought '..actor..' close to death.'
            if d.recoveryObserved then
                local recovery=C.Render('recovery',scene,{c})
                text=text..' '..(recovery and recovery.text or 'Strength returned before that passage was over.')
            elseif d.closed and d.phase=='combat_ended' and d.endAlive==true then text=text..' '..actor..' came through that bout alive.' end
        end
        clauses[#clauses+1]=Sentence(text,{c})
    elseif death then clauses[#clauses+1]=Sentence(actor..' fell during this stretch of the journey.',{death}) end
    local credits=First(scene,'owner_creature_credits')
    if credits then
        clauses[#clauses+1]=Sentence('The road brought its own battles. At least '..Number(credits.value.count)..' creatures fell in the fighting around '..actor..((credits.value.petCount or 0)>0 and ' and a pet companion.' or '.'),{credits})
    end
    local skills,names,proof={},{},{}
    for _,c in ipairs(scene.skillGrowth or {}) do local d=c.value;local name=Text(d.name)
        if name and type(d.before)=='number' and type(d.after)=='number' then
            local key=tostring(d.skillID or name:lower());local row=skills[key]
            if not row then row={name=name,before=d.before,after=d.after,claims={}};skills[key]=row end
            row.before=math.min(row.before,d.before);row.after=math.max(row.after,d.after);row.claims[#row.claims+1]=c
        end
    end
    for _,row in pairs(skills) do if row.after-row.before>=5 or row.after>row.before and row.after%25==0 then
        names[#names+1]=row.name;for _,c in ipairs(row.claims) do proof[#proof+1]=c end
    end end
    table.sort(names)
    if #names>0 and scene.includeRoutineGrowth then
        local list=#names==1 and names[1] or table.concat(names,', ',1,#names-1)..' and '..names[#names]
        clauses[#clauses+1]=Sentence('Practice also sharpened '..actor..'’s command of '..list..'.',proof)
    end
end
local function Interlude(scene,length)
    local clauses={};scene.title='Along the way'
    if scene.setting and length~='Short' then clauses[#clauses+1]=Sentence(scene.setting.body,{},scene.setting) end
    Experience(scene,clauses)
    if #clauses==0 then return {} end
    local b=Block(scene,clauses,'interlude');b.interlude=true;b.suppressHeading=true;return {b}
end
local function Completion(scene,ref,purpose,actor)
    if not ref then return end
    local p=Text(ref.premise,nil,700);if not p then return end
    p=(p:match('^(.-[%.!?])%s') or p):gsub('[%.%s]+$','')
    local object,recipient=p:match('^[Bb]ring (.-) to (.+)$')
    if not object then object,recipient=p:match('^[Dd]eliver (.-) to (.+)$') end
    if not object then object,recipient=p:match('^[Tt]ake (.-) to (.+)$') end
    if object and recipient and not recipient:find('[<>]') then
        object=object:gsub('^(%d+)',function(n) return Number(tonumber(n)) end)
        -- This is the completed quest's explicit delivery objective. It says
        -- nothing about the route, how items were acquired or a spoken exchange.
        return Form(scene,{actor..' delivered '..object..' to '..recipient..'.',
            'The delivery of '..object..' to '..recipient..' brought '..actor..'’s task to its end.'})
    end
    local destination=p:match('^[Ss]peak with (.+)$') or p:match('^[Ss]peak to (.+)$') or p:match('^[Tt]alk to (.+)$')
    if destination then
        return actor..' had spoken with '..destination..'.'
    end
    local target=p:match('^[Kk]ill (.+)$') or p:match('^[Ss]lay (.+)$') or p:match('^[Dd]efeat (.+)$')
    if target then
        target=(target:match('^(.-),?%s+then%s+') or target):gsub('[,%s]+$','')
        -- Quest fulfillment does not identify the killing blow. Do not convert
        -- objective credit into a fabricated count of the owner's combat kills.
        if not target:find(' and ',1,true) then
            target=target:gsub('^(%d+)',function(n) return Number(tonumber(n)) end)
            local npc=Text(ref.giverName)
            return npc and (npc..'’s call to confront '..target..' had been answered.') or ('The request to confront '..target..' had been fulfilled.')
        end
    end
end
local function SubjectText(scene,ref,done)
    local edited=ns.AthenaQuestContext.Action(ref,done,Actor(scene.story));if edited then return edited end
    local q=ref and (ref.subject or ns.AthenaQuestSubjects.Build(ref));if not q then return end
    local actor=Actor(scene.story);local npc=q.giver
    local subject=q.subject:gsub('^(%d+)',function(n) return Number(tonumber(n)) end)
    if q.kind=='DELIVERY' then
        if done then return Form(scene,{actor..' brought '..subject..' to '..q.recipient..'.',
            actor..' delivered '..subject..' to '..q.recipient..'.'}) end
        local recipient=q.recipient
        -- The giver of a delivery is not automatically its recipient. Wiley
        -- hands over a note for Stoutmantle; he does not ask to receive it.
        return actor..' was to carry '..subject..' to '..recipient..'.'
    elseif q.kind=='RECOVERY' then
        local recipient=q.recipient~='UNKNOWN' and q.recipient or npc
        if done then
            local origin=q.origin and ' from '..q.origin or '';local destination=recipient and ' for '..recipient or ''
            return Form(scene,{actor..' recovered '..subject..origin..destination..'.',
                subject:gsub('^%l',string.upper)..' had been recovered'..origin..destination..'.'})
        end
        return npc and (npc..' sought '..subject..(q.origin and ' from '..q.origin or '')..'.')
            or (recipient and ('For '..recipient..', '..subject..' had to be recovered'..(q.origin and ' from '..q.origin or '')..'.'))
            or ('The search centered on '..subject..(q.origin and ' from '..q.origin or '')..'.')
    elseif q.kind=='CONFLICT' then
        if done then return (npc and npc..'’s charge against ' or 'The charge against ')..subject..' had been carried out.' end
        return npc and (npc..' wanted '..subject..' defeated.') or ('The danger to be confronted was '..subject..'.')
    elseif q.kind=='CONTACT' then
        return done and (actor..' had spoken with '..q.recipient..'.') or ('The next person '..actor..' needed to speak with was '..q.recipient..'.')
    elseif q.kind=='COMPOUND' and q.delivery and q.destination then
        -- Fulfillment supports the explicit delivery, not who struck the
        -- killing blow or the route by which the trophy was obtained.
        return done and (actor..' brought '..q.delivery..' to '..q.destination..'.')
            or ((npc or q.destination)..' called for '..q.delivery..'.')
    end
end
local function QuestCore(scene,length)
    local begin=First(scene,'owner_quest_accepted');local done=First(scene,'owner_quest_turnin')
    local progress=Claims(scene,'owner_quest_objective');local removed=First(scene,'owner_quest_removed')
    local sample=begin or done or progress[1] or removed;if not sample then return {} end
    local ref=Lore() and Reference(scene,sample.value.questID)
    local actor=Actor(scene.story);local purpose=Goal(ref);local clauses={}
    if begin and done then
        local ix=scene.story.narrativeIndex;local proof=ix and ix.byRef[done.evidenceRefs[1]]
        for _,c in ipairs(Claims(scene,'owner_combat_experience')) do
            if proof and c.value.lastAt<=proof.observedAt and (c.value.lowHealthObserved or c.value.deaths>0) then
                scene.deferredTurnin=done;done=nil;break
            end
        end
    end
    scene.title=Text((scene.place or scene.story.node.place or {}).subzone) or Text((scene.place or scene.story.node.place or {}).zone,'Along the way')
    scene.narrativePlan={centralSubject=scene.occurrenceId,premise=ref and ref.worldRef,
        movement=done and 'RESOLUTION' or begin and 'INTRODUCTION' or 'DEVELOPMENT',landing=done and 'FULFILLED' or 'OPEN',asOf=scene.lastAt}
    if not begin and not done then return clauses end
    if scene.setting and length~='Short' then clauses[#clauses+1]=Sentence(scene.setting.body,{},scene.setting) end
    local edited=ref and ref.storyContext and ref.storyContext.editorial
    local setup=(begin or done and not scene.prior) and length~='Short' and (edited and edited.opening or ref and ref.overrideRevision and ref.setup or Motive(ref) or Backdrop(ref,scene))
    -- The quest cast entry and editorial scene can describe the same source
    -- circumstances. Use the fuller scene once; a second local biography is
    -- not new context. Independently sourced historical lore stays eligible.
    if scene.figure and length~='Short' and not (setup and scene.figure.questSourceContext) then clauses[#clauses+1]=Sentence(scene.figure.body,{},scene.figure) end
    local seen=scene.contextSeen
    local setupWritten=false
    local connection=First(scene,'quest_reference_connection')
    local bridge,replacesSetup=ns.AthenaQuestContext.Bridge(ref,connection)
    if bridge and replacesSetup then setup=bridge end
    if setup and (not seen or not seen[setup]) then
        if bridge and not replacesSetup then clauses[#clauses+1]=Sentence(bridge,{connection},ref) end
        local claims=begin and {begin} or {};if replacesSetup and connection then claims[#claims+1]=connection end
        clauses[#clauses+1]=Sentence(setup,claims,ref);if seen then seen[setup]=true end;setupWritten=true
    end
    local text=SubjectText(scene,ref,done)
    local subject=ref and (ref.subject or ns.AthenaQuestSubjects.Build(ref))
    local taskExplained=setupWritten and not done and subject and subject.subject~='UNKNOWN' and setup:lower():find(subject.subject:lower(),1,true)
    if taskExplained then text=nil;purpose=nil end
    if not text then text=done and Completion(scene,ref,purpose,actor) end
    if not text and not taskExplained then text=ns.AthenaQuestContext.Mandate(ref,done,actor) end
    if not text and purpose then
        -- Keep an unparsed, source-backed compound objective intact. No quest
        -- title or speculative narrative supplies the missing subject.
        text=done and ('The work of '..purpose..' was finished.') or ((ref and ref.giverName or actor)..'’s concern was '..purpose..'.')
    end
    if text then clauses[#clauses+1]=Sentence(text,begin and done and {begin,done} or {done or begin},ref) end
    if done and length~='Short' and ref then
        local aftermath=ref.summary and ref.summary.aftermath or ns.AthenaQuestContext.Aftermath(ref)
        if aftermath and aftermath~=setup and (not seen or not seen[aftermath]) then
            clauses[#clauses+1]=Sentence(aftermath,{done},ref);if seen then seen[aftermath]=true end
        end
    end
    if done and ref and ref.overrideRevision and ref.conclusion and length=='Epic' then clauses[#clauses+1]=Sentence(ref.conclusion,{},ref) end
    return clauses
end
local function Growth(scene,clauses)
    local level
    for _,c in ipairs(scene.growth or {}) do
        if c.claimType=='owner_level_change' and (not level or c.value.after>level.value.after) then level=c
        elseif c.claimType=='owner_achievement' then clauses[#clauses+1]=Sentence('The achievement “'..Text(c.value.name,'an unnamed milestone')..'” marked this part of the journey.',{c}) end
    end
    if level and scene.includeRoutineGrowth then clauses[#clauses+1]=Sentence(Actor(scene.story)..' reached level '..level.value.after..' along the way.',{level}) end
end
local function Quest(scene,length)
    local clauses=QuestCore(scene,length);Experience(scene,clauses);Growth(scene,clauses)
    if scene.deferredTurnin then
        local c=scene.deferredTurnin;local ref=Lore() and Reference(scene,c.value.questID)
        clauses[#clauses+1]=Sentence(Actor(scene.story)..' went on to fulfill '..(ref and ref.giverName and Text(ref.giverName)..'’s request.' or 'the request.'),{c})
    end
    if scene.ownProtection and length~='Short' then clauses[#clauses+1]=Sentence('During that passage, '..Actor(scene.story)..'’s Warden applied a protection.',{scene.ownProtection}) end
    if #clauses==0 then return {} end
    return {Block(scene,clauses,'scene')}
end
local function QuestPair(first,second,length)
    if first.focus~='QUEST' or second.focus~='QUEST' or first.chapterId~=second.chapterId or first.prior or second.prior or not Lore() or First(first,'owner_combat_experience') or First(second,'owner_combat_experience') or First(first,'owner_creature_credits') or First(second,'owner_creature_credits') or First(first,'owner_recorded_death') or First(second,'owner_recorded_death') or first.figure or second.figure then return end
    local a,b=First(first,'owner_quest_accepted'),First(second,'owner_quest_accepted')
    local da,db=First(first,'owner_quest_turnin'),First(second,'owner_quest_turnin')
    if not a or not b or not da or not db then return end
    local ra,rb=Reference(first,a.value.questID),Reference(second,b.value.questID)
    if not ra or not rb or not ra.giverIDs[1] or ra.giverIDs[1]~=rb.giverIDs[1] or not ra.giverName then return end
    local ga,gb=Goal(ra),Goal(rb);if not ga or not gb or ga==gb then return end
    local combined={};for k,v in pairs(first) do combined[k]=v end
    combined.sceneId=first.sceneId;combined.title=first.chapter.title or ra.giverName..'’s requests'
    combined.stories={};combined.primaryDevelopmentIds={};combined.sceneIds={first.sceneId,second.sceneId}
    for _,s in ipairs(first.stories) do combined.stories[#combined.stories+1]=s end
    for _,s in ipairs(second.stories) do combined.stories[#combined.stories+1]=s end
    for _,s in ipairs({first,second}) do for _,id in ipairs(s.primaryDevelopmentIds) do combined.primaryDevelopmentIds[#combined.primaryDevelopmentIds+1]=id end end
    local clauses={}
    if first.setting and length~='Short' then clauses[#clauses+1]=Sentence(first.setting.body,{},first.setting) end
    local backdrop=length~='Short' and Backdrop(ra);if backdrop then clauses[#clauses+1]=Sentence(backdrop,{},ra) end
    ga=(ga:match('^(.-),?%s+then%s+') or ga):gsub('[,%s]+$','')
    gb=(gb:match('^(.-),?%s+then%s+') or gb):gsub('[,%s]+$','')
    if ga:match('^speaking with ') and gb:match('^speaking with ') then
        clauses[#clauses+1]=Sentence(ra.giverName..'’s requests pointed '..Actor(first.story)..' first toward '..ga:gsub('^speaking with ',''),{a},ra)
        clauses[#clauses+1]=Sentence('and then toward '..gb:gsub('^speaking with ','')..'.',{b},rb)
    else
        clauses[#clauses+1]=Sentence(ra.giverName..'’s requests for '..Actor(first.story)..' ran from '..ga,{a},ra)
        clauses[#clauses+1]=Sentence('to '..gb..'.',{b},rb)
    end
    clauses[#clauses+1]=Sentence('Both assignments were carried through.',{da,db})
    local protection=first.ownProtection or second.ownProtection
    if protection and length~='Short' then clauses[#clauses+1]=Sentence('During that passage, '..Actor(first.story)..'’s Warden applied a protection.',{protection}) end
    for _,s in ipairs({first,second}) do for _,c in ipairs(s.growth or {}) do if c.claimType=='owner_level_change' and first.includeRoutineGrowth then
        clauses[#clauses+1]=Sentence('Amid these undertakings, '..Actor(s.story)..' reached level '..c.value.after..'.',{c})
    end end end
    local block=Block(combined,clauses,'scene');block.sceneIds=combined.sceneIds;block.title=combined.title
    return block
end
local function SparsePair(first,second)
    if first.focus~='QUEST' or second.focus~='QUEST' or first.chapterId~=second.chapterId or first.prior or second.prior or First(first,'owner_combat_experience') or First(second,'owner_combat_experience') or First(first,'owner_creature_credits') or First(second,'owner_creature_credits') or First(first,'owner_recorded_death') or First(second,'owner_recorded_death') then return end
    local a,b=First(first,'owner_quest_turnin'),First(second,'owner_quest_turnin')
    if not a or not b or a.value.name or b.value.name or a.value.questID==b.value.questID or Reference(first,a.value.questID) or Reference(second,b.value.questID) then return end
    local scene={};for k,v in pairs(first) do scene[k]=v end;scene.stories={first.story,second.story};scene.primaryDevelopmentIds={}
    for _,s in ipairs({first,second}) do for _,id in ipairs(s.primaryDevelopmentIds) do scene.primaryDevelopmentIds[#scene.primaryDevelopmentIds+1]=id end end
    scene.title=first.chapter.title or 'Errands along the way'
    local clauses={Sentence(Actor(first.story)..' brought two errands to a close.',{a,b})}
    local block=Block(scene,clauses,'scene');block.sceneIds={first.sceneId,second.sceneId};return block
end
local Memory
local function QuestWeave(scenes,at,length)
    local first=scenes[at];local scene={};for k,v in pairs(first) do scene[k]=v end
    scene.stories={};scene.claims={};scene.primaryDevelopmentIds={};scene.sceneIds={};scene.skillGrowth={};scene.growth={}
    local clauses,parts,npcSeen={}, {},{};local contributed=0;local resolved={};local deferred={};local paired={}
    -- The chapter plan selects related source subjects. Each paragraph has
    -- concrete work or a consequence; generic progress recaps are not written.
    for i=at,math.min(#scenes,at+31) do local s=scenes[i]
        if s.focus~='QUEST' or s.chapterId~=first.chapterId or s.beat~=first.beat then break end
        parts[#parts+1]=s;scene.sceneIds[#scene.sceneIds+1]=s.sceneId
        for _,story in ipairs(s.stories) do scene.stories[#scene.stories+1]=story end
        for _,id in ipairs(s.primaryDevelopmentIds) do scene.primaryDevelopmentIds[#scene.primaryDevelopmentIds+1]=id end
        for _,c in ipairs(s.claims) do scene.claims[#scene.claims+1]=c end
        for _,c in ipairs(s.skillGrowth or {}) do scene.skillGrowth[#scene.skillGrowth+1]=c end
        for _,c in ipairs(s.growth or {}) do scene.growth[#scene.growth+1]=c end
        local q={};for k,v in pairs(s) do q[k]=v end
        if i~=at then q.setting=nil end
        local sample=First(s,'owner_quest_accepted') or First(s,'owner_quest_turnin');local ref=sample and Reference(s,sample.value.questID)
        local giver=ref and ref.giverIDs and ref.giverIDs[1]
        if giver and npcSeen[giver] then q.figure=nil else if giver then npcSeen[giver]=true end end
        -- Foreground three new subjects. A distinct source-backed circumstance
        -- or an actual resolution can earn space beyond that opening budget;
        -- the missing novice must not vanish behind three delivery objectives.
        -- No objective ticks or repeated acceptance reminders fill the page.
        local rows={}
        local accepted=First(s,'owner_quest_accepted');local finished=First(s,'owner_quest_turnin')
        local purpose=Goal(ref);local shortReferral=purpose and (purpose:match('^speaking ') or purpose:match('^reporting ')) and #scenes>3
        local circumstance=accepted and not q.prior and Backdrop(ref,q)
        if not paired[i] and (contributed<3 or finished or circumstance) and (accepted or finished) then
            rows=QuestCore(q,length)
            local next=scenes[i+1];local nextSample=next and (First(next,'owner_quest_accepted') or First(next,'owner_quest_turnin'))
            local nextRef=nextSample and Reference(next,nextSample.value.questID)
            local function Target(r)
                local p=r and Text(r.premise);if not p then return end
                local v=p:match('^[Kk]ill (.+)') or p:match('^[Ss]lay (.+)') or p:match('^[Dd]efeat (.+)')
                if not v then return end;v=(v:match('^(.-),?%s+then%s+') or v):gsub('[%.%s]+$','')
                if v:find(' and ',1,true) then return end
                return v:gsub('^(%d+)',function(number) return Number(tonumber(number)) end)
            end
            local a,b=Target(ref),Target(nextRef)
            local nd=next and First(next,'owner_quest_turnin');local na=next and First(next,'owner_quest_accepted')
            -- Preserve a distinct reason for the next request, even when its
            -- giver and verb match the current one.
            if a and b and Backdrop(nextRef,next) then a=nil end
            if a and b and length~='Epic' and #rows>0 and next and next.focus=='QUEST' and next.beat==first.beat and next.chapterId==first.chapterId
                and ref.giverName and ref.giverName==nextRef.giverName and ref.giverIDs[1] and ref.giverIDs[1]==nextRef.giverIDs[1]
                and (finished and nd or not finished and not nd and accepted and na)
                and not First(s,'owner_combat_experience') and not First(next,'owner_combat_experience') and not q.deferredTurnin then
                -- Two related concerns from one giver form one thought, with
                -- both independent quest references and both outcomes retained.
                table.remove(rows)
                rows[#rows+1]=Sentence(ref.giverName..'’s concern lay with '..a,{finished or accepted},ref)
                rows[#rows+1]=Sentence('and '..b..'. '..(finished and 'The charge against them had been carried out.' or Actor(scene.story)..' was charged with confronting them.'),{nd or na,finished or accepted},nextRef)
                paired[i+1]=true
            end
        end
        if #rows>0 then
            for _,c in ipairs(rows) do clauses[#clauses+1]=c end;contributed=contributed+1
            if q.deferredTurnin then deferred[#deferred+1]=q.deferredTurnin end
        elseif finished and not paired[i] then resolved[#resolved+1]=finished
        end
        scene.lastAt=math.max(scene.lastAt,s.lastAt)
    end
    if #parts<2 then return end
    Experience(scene,clauses);Growth(scene,clauses)
    for _,s in ipairs(parts) do if s.ownProtection and length~='Short' then
        clauses[#clauses+1]=Sentence('During this passage, '..Actor(scene.story)..'’s Warden applied a protection.',{s.ownProtection});break
    end end
    for _,c in ipairs(deferred) do resolved[#resolved+1]=c end
    -- Off-page minor closures remain in the source archive. Only a deferred
    -- ending after a significant close call needs a further landing here.
    for _,c in ipairs(deferred) do
        local ref=Reference(scene,c.value.questID);local text=SubjectText(scene,ref,true) or Completion(scene,ref,Goal(ref),Actor(scene.story))
        if text then clauses[#clauses+1]=Sentence(text,{c},ref) end
    end
    if #clauses==0 then return nil,parts end
    local b=Block(scene,clauses,'scene');b.sceneIds=scene.sceneIds;b.recipeId=A.VERSION..'/woven-quests';b.suppressHeading=true
    return b,parts
end
local function Activity(scene,length)
    local s=scene.story;local actor=Actor(s);local place=scene.placeClaim or First(scene,'observed_place');if not place then return {} end
    local where=Text(place.value,'an unnamed place');local genre=s.storyKind;local clauses={};local attempt=Claims(scene,'encounter_attempt')
    local company=First(scene,'guild_company');local roster=First(scene,'roster_point_count');local recurring=First(scene,'recurring_companion')
    local lore=Lore() and length~='Short' and not scene.followup and s.knowledgeContext and s.node.place and s.node.place.instanceID and ns.Athena.Knowledge.GetLore('instance:'..s.node.place.instanceID,s.knowledgeContext)
    if scene.setting and length~='Short' then clauses[#clauses+1]=Sentence(scene.setting.body,{},scene.setting) end
    if lore and not scene.setting then clauses[#clauses+1]=Sentence(lore.body,{},lore) end
    if scene.figure and length~='Short' then clauses[#clauses+1]=Sentence(scene.figure.body,{},scene.figure) end
    if not scene.followup then for _,c in ipairs(Claims(scene,'quest_expedition_context')) do
        local ref=Reference(scene,c.value.questID)
        if ref then
            local npc=ref.giverName
            clauses[#clauses+1]=Sentence((npc and npc..'’s charge against ' or 'There was still the charge against ')..Text(c.value.target)..' remained unfinished.',{c},ref)
        end
    end end
    scene.title=(genre=='BATTLEGROUND' and 'The contest at ' or genre=='DUEL' and 'A duel in ' or genre=='WORLD_PVP' and 'Conflict in ' or 'Into ')..where
    if genre=='BATTLEGROUND' then
        local c=First(scene,'match_observed') or First(scene,'match_ended') or place
        clauses[#clauses+1]=Sentence(scene.followup and ('Another contest brought '..actor..' to '..where..'.') or (actor..' took part in a contest at '..where..'.'),{place,c})
    elseif genre=='DUEL' then
        local result=First(scene,'owner_duel_result')
        clauses[#clauses+1]=Sentence(actor..' faced a duel in '..where..(result and (result.value.result=='win' and ', and won the contest.' or ', and lost the contest.') or '.'),result and {place,result} or {place})
    elseif genre=='WORLD_PVP' then
        clauses[#clauses+1]=Sentence('In '..where..', '..actor..' crossed paths with another player in combat.',{place,First(scene,'owner_world_pvp') or place})
    else
        local line=scene.followup and ('A later expedition found '..actor..' in '..where..' again') or actor..(s.timeCoverage.unknownStart and ' was amid an expedition in ' or ' entered ')..where
        if company then line=line..', with '..C.Count(company.value.count,'member')..' of '..Text(company.value.name,'the guild')..' present at one gathering'
        elseif roster then line=line..'; one gathering there numbered '..C.Count(roster.value,'participant') end
        local cc={place};if company or roster then cc[#cc+1]=company or roster end
        clauses[#clauses+1]=Sentence(line..'.',cc)
    end
    local openingCount=#clauses
    table.sort(attempt,function(a,b) return a.value.at<b.value.at or a.value.at==b.value.at and a.claimId<b.claimId end)
    local foes,order={},{}
    for _,c in ipairs(attempt) do local id=c.value.boss;local v=foes[id]
        if not v then v={name=Text(c.value.name,'an unnamed foe'),claims={},fail=0,win=0,unknown=0};foes[id]=v;order[#order+1]=id end
        v.claims[#v.claims+1]=c;v[c.value.outcome=='SUCCESS' and 'win' or c.value.outcome=='FAILURE' and 'fail' or 'unknown']=v[c.value.outcome=='SUCCESS' and 'win' or c.value.outcome=='FAILURE' and 'fail' or 'unknown']+1
    end
    for _,id in ipairs(order) do local v=foes[id];local last=v.claims[#v.claims];local text
        if v.fail>0 and v.win==1 and v.unknown==0 and last.value.outcome=='SUCCESS' then
            text=v.name..' withstood '..Number(v.fail)..' attempt'..(v.fail==1 and '' or 's')..' before falling in a later encounter.'
        elseif v.fail>0 and v.win==0 then text=Number(v.fail):gsub('^%l',string.upper)..' attempt'..(v.fail==1 and '' or 's')..' against '..v.name..' ended in defeat.'
        elseif v.win>0 and v.fail==0 then text=v.name..(v.win==1 and ' fell during the expedition.' or ' was defeated in '..Number(v.win)..' separate encounters.')
        elseif v.win>0 then text='The encounters with '..v.name..' brought '..Number(v.win)..' victor'..(v.win==1 and 'y' or 'ies')..' and '..Number(v.fail)..' defeat'..(v.fail==1 and '.' or 's.')
        else text='The expedition confronted '..v.name..'.' end
        clauses[#clauses+1]=Sentence(text,v.claims)
    end
    Experience(scene,clauses)
    local returnVictory=First(scene,'later_victory')
    if returnVictory and length~='Short' then clauses[#clauses+1]=Sentence('An earlier expedition had ended in defeat against that same foe; this return gave the struggle a different ending.',{returnVictory}) end
    if recurring and length~='Short' then local crafted=C.Render('recurring',scene,{recurring});if crafted then clauses[#clauses+1]=crafted end end
    for _,c in ipairs(scene.growth or {}) do
        if c.claimType=='owner_achievement' then clauses[#clauses+1]=Sentence('The expedition also marked the achievement “'..Text(c.value.name,'an unnamed milestone')..'”.',{c})
        elseif c.claimType=='owner_level_change' and scene.includeRoutineGrowth then clauses[#clauses+1]=Sentence('During that part of the journey, '..actor..' reached level '..c.value.after..'.',{c}) end
    end
    local loot=First(scene,'owner_item_receipt');if loot and length~='Short' then clauses[#clauses+1]=Sentence('During this part of the expedition, '..Text(loot.value.name,'an item')..' came into '..actor..'’s possession.',{loot}) end
    if scene.ownProtection and length~='Short' then clauses[#clauses+1]=Sentence('During that passage, '..actor..'’s Warden applied a protection.',{scene.ownProtection}) end
    scene.narrativePlan={centralSubject=s.node.activityRef,movement=#attempt>0 and 'ENCOUNTER_SEQUENCE' or 'ARRIVAL',asOf=scene.lastAt}
    if scene.preEncounterMemories then
        local opening,events={},{};for i,c in ipairs(clauses) do local list=i<=openingCount and opening or events;list[#list+1]=c end
        local out={Block(scene,opening,'arrival')}
        for _,m in ipairs(scene.preEncounterMemories) do m.chapter=scene.chapter;for _,b in ipairs(Memory(m)) do out[#out+1]=b end end
        if #events>0 then local b=Block(scene,events,'encounters');b.recipeId=A.VERSION..'/battle-encounters';out[#out+1]=b end
        return out
    end
    local b=Block(scene,clauses,'scene');b.recipeId=A.VERSION..'/battle-scene';return {b}
end
local function Milestone(scene,length)
    local actor=Actor(scene.story);local clauses={};local levels=Claims(scene,'owner_level_change');local achievements=Claims(scene,'owner_achievement')
    if scene.setting and length~='Short' then clauses[#clauses+1]=Sentence(scene.setting.body,{},scene.setting) end
    if #levels>0 and scene.includeRoutineGrowth then local last=levels[#levels];scene.title='A new measure of experience';clauses[#clauses+1]=Sentence(scene.returnVisit and (actor..' reached level '..last.value.after..' along the way.') or Form(scene,{
        actor..' reached level '..last.value.after..', another milestone in a life still taking shape.',
        'With level '..last.value.after..', another milestone entered '..actor..'’s tale.',
        'The journey had brought '..actor..' to level '..last.value.after..', a new mark of experience along the way.'}),levels) end
    for _,c in ipairs(achievements) do scene.title=Text(c.value.name,'A milestone');clauses[#clauses+1]=Sentence('The achievement “'..Text(c.value.name,'an unnamed milestone')..'” became part of '..actor..'’s journey.',{c}) end
    return #clauses>0 and {Block(scene,clauses,'scene')} or {}
end
local function Campaign(scenes,at,length)
    if length=='Short' then return end
    local first=scenes[at]
    if first.focus~='ACTIVITY' or first.preEncounterMemories or first.ownProtection then return end
    local kind=first.story.storyKind;local place=first.story.node.place or {}
    if kind~='RAID' and kind~='DUNGEON' or not place.instanceID then return end
    local parts,boss={},nil
    for i=at,math.min(#scenes,at+5) do local s=scenes[i];local p=s.story.node.place or {}
        if s.focus~='ACTIVITY' or s.chapterId~=first.chapterId or s.story.storyKind~=kind or s.preEncounterMemories or s.ownProtection
            or p.instanceID~=place.instanceID or p.difficultyID~=place.difficultyID or First(s,'owner_combat_experience') or First(s,'owner_recorded_death') or First(s,'owner_creature_credits') then break end
        local attempts=Claims(s,'encounter_attempt');local valid=#attempts>0
        for _,c in ipairs(attempts) do if not boss then boss=c.value.boss elseif boss~=c.value.boss then valid=false end end
        if not valid then break end
        table.sort(attempts,function(a,b) return a.value.at<b.value.at or a.value.at==b.value.at and a.claimId<b.claimId end)
        parts[#parts+1]={scene=s,attempts=attempts}
    end
    if #parts<2 then return end
    local combined={};for k,v in pairs(first) do combined[k]=v end
    combined.stories={};combined.primaryDevelopmentIds={};combined.sceneIds={}
    for _,part in ipairs(parts) do local s=part.scene
        combined.sceneIds[#combined.sceneIds+1]=s.sceneId
        for _,story in ipairs(s.stories) do combined.stories[#combined.stories+1]=story end
        for _,id in ipairs(s.primaryDevelopmentIds) do combined.primaryDevelopmentIds[#combined.primaryDevelopmentIds+1]=id end
    end
    local clauses={};local actor=Actor(first.story);local where=Text(place.instanceName or place.zone,'the expedition')
    if first.setting then clauses[#clauses+1]=Sentence(first.setting.body,{},first.setting) end
    local lore=Lore() and not first.followup and first.story.knowledgeContext and ns.Athena.Knowledge.GetLore('instance:'..place.instanceID,first.story.knowledgeContext)
    if lore and not first.setting then clauses[#clauses+1]=Sentence(lore.body,{},lore) end
    if first.figure then clauses[#clauses+1]=Sentence(first.figure.body,{},first.figure) end
    local recurringUsed,companySeen=false,{}
    for i,part in ipairs(parts) do local s=part.scene;local entry=First(s,'observed_place');local failures,wins,unknown=0,0,0
        for _,c in ipairs(part.attempts) do if c.value.outcome=='SUCCESS' then wins=wins+1 elseif c.value.outcome=='FAILURE' then failures=failures+1 else unknown=unknown+1 end end
        local foe=Text(part.attempts[1].value.name,'an unnamed foe');local last=part.attempts[#part.attempts]
        -- A reading window is not a lifetime ordinal. Its first visible outing
        -- must not silently become the character's first-ever expedition.
        local lead=i==1 and (actor..'’s expedition in '..where) or 'A later expedition there'
        local text
        if failures>0 and wins==0 and unknown==0 then
            text=failures==1 and (lead..' met defeat in a confrontation with '..foe..'.')
                or (lead..' brought '..Number(failures)..' attempts against '..foe..', and each ended in defeat.')
        elseif failures>0 and wins==1 and unknown==0 and last.value.outcome=='SUCCESS' then
            text=lead..' met '..Number(failures)..' defeat'..(failures==1 and '' or 's')..' against '..foe..' before the foe finally fell.'
        elseif failures==0 and wins==1 and unknown==0 then
            text=i>1 and (First(s,'later_victory') and ('After the earlier defeats, a later expedition ended with '..foe..'’s fall.') or ('In a later expedition, '..foe..' fell.')) or (lead..' ended with '..foe..'’s defeat.')
        else return end -- The regular scene writer retains mixed/uncertain sequences.
        local proof={};if entry then proof[#proof+1]=entry end;for _,c in ipairs(part.attempts) do proof[#proof+1]=c end
        local resolution=First(s,'later_victory');if resolution then proof[#proof+1]=resolution end
        clauses[#clauses+1]=Sentence(text,proof)
        local company=First(s,'guild_company');local roster=First(s,'roster_point_count')
        local key=company and (tostring(company.value.name)..'/'..tostring(company.value.count)) or roster and ('roster/'..tostring(roster.value))
        if key and not companySeen[key] then
            local line=company and ('At one gathering during that expedition, '..C.Count(company.value.count,'member')..' of '..Text(company.value.name,'the guild')..(company.value.count==1 and ' was present.' or ' were present.'))
                or ('One gathering during that expedition numbered '..C.Count(roster.value,'participant')..'.')
            clauses[#clauses+1]=Sentence(line,{company or roster});companySeen[key]=true
        end
        local recurring=First(s,'recurring_companion')
        if recurring and not recurringUsed then local crafted=C.Render('recurring',s,{recurring});if crafted then clauses[#clauses+1]=crafted;recurringUsed=true end end
        for _,c in ipairs(s.growth or {}) do
            if c.claimType=='owner_level_change' and first.includeRoutineGrowth then clauses[#clauses+1]=Sentence('During that expedition, '..actor..' reached level '..c.value.after..'.',{c})
            elseif c.claimType=='owner_achievement' then clauses[#clauses+1]=Sentence('The achievement “'..Text(c.value.name,'an unnamed milestone')..'” marked that expedition.',{c}) end
        end
        local loot=First(s,'owner_item_receipt');if loot then clauses[#clauses+1]=Sentence('During that expedition, '..Text(loot.value.name,'an item')..' came into '..actor..'’s possession.',{loot}) end
    end
    local b=Block(combined,clauses,'scene');b.sceneIds=combined.sceneIds;b.recipeId=A.VERSION..'/battle-campaign'
    return b,parts
end
local function Affiliation(scene)
    local c=scene.claims[1];if not c then return {} end;local actor=Actor(scene.story);local text
    if c.claimType=='own_guild_affiliation' then scene.title='A change of allegiance'
        if c.value.baseline then if not c.value.after then return {} end;text='At this point, '..actor..' belonged to '..Text(c.value.name,'the guild')..'.'
        else text=actor..(c.value.after and ' joined ' or ' left ')..Text(c.value.name,'the guild')..'.' end
    else scene.title='A connection made';local name=Text(c.value.name,'A fellow adventurer')
        text=c.value.after and (name..(c.value.baseline and ' was among ' or ' now stood among ')..actor..'’s friends.') or (name..' no longer appeared among '..actor..'’s friends.')
    end
    return {Block(scene,{Sentence(text,{c})},'scene')}
end
Memory=function(scene)
    local c=scene.claims[1];if not c then return {} end
    scene.title='Words kept along the way';local out={};local s=scene.story
    local b=Block(scene,{Sentence('A conversation from this part of the journey was kept among '..Actor(s)..'’s private memories.',{c})},'memory')
    b.privateMemory=true;b.memoryRefs={c.value.momentRef};out[1]=b
    for _,moment in ipairs(s.conversationMoments or {}) do if moment.momentRef==c.value.momentRef then for i,e in ipairs(moment.inlineTexts or {}) do
        local q=Block(scene,{Sentence((e.speaker.name or 'Unknown speaker')..': “'..e.text..'”'..(e.textState=='TRUNCATED' and ' [Excerpt shortened]' or ''),{c})},'quotation/'..i)
        q.literal=true;q.privateMemory=true;q.memoryRefs={c.value.momentRef};out[#out+1]=q
    end end end
    return out
end
local function Connect(scene)
    local intent=scene.transitionIntent;scene.transition=nil
    -- Let a concrete setting or activity opening carry the transition. A second
    -- generic "the tale moved" sentence adds no development to that paragraph.
    if not intent or intent.kind~='PLACE' or scene.setting or scene.focus=='ACTIVITY' or scene.returnVisit then return end
    if intent.from and intent.to then
        local destination=Text(intent.to.value,'another place')
        scene.transition=Sentence('Later, '..Actor(scene.story)..' was in '..destination..'.',{intent.from,intent.to})
    end
end
function A.Render(plan,length)
    assert(plan.metisPrepared and plan.metisUnits,'METIS_PLAN_REQUIRED')
    local out,ledger={}, {version=A.VERSION,owner=plan.owner,primary={},callbacks={},clauses={},voice='Natural Fantasy',director=ns.Metis.VERSION}
    local author={INTERLUDE=Interlude,QUEST=Quest,ACTIVITY=Activity,MILESTONE=Milestone,AFFILIATION=Affiliation,MEMORY=Memory}
    local contextSeen={}
    for _,unit in ipairs(plan.metisUnits) do
        for _,s in ipairs(unit.scenes) do s.contextSeen=contextSeen end
        local scene=unit.scene;Connect(scene);local block,blocks
        if unit.recipe=='QUEST_WEAVE' then block=QuestWeave(unit.scenes,1,length)
        elseif unit.recipe=='BATTLE_CAMPAIGN' then block=Campaign(unit.scenes,1,length)
        elseif unit.recipe=='QUEST_PAIR' then block=QuestPair(unit.scenes[1],unit.scenes[2],length)
        elseif unit.recipe=='SPARSE_PAIR' then block=SparsePair(unit.scenes[1],unit.scenes[2]) end
        if block then blocks={block} else
            blocks={};for _,s in ipairs(unit.scenes) do Connect(s);for _,b in ipairs(author[s.focus] and author[s.focus](s,length) or {}) do blocks[#blocks+1]=b end end
        end
        for _,b in ipairs(blocks) do
            b.title=scene.chapter.title or scene.title;if not scene.chapter.title then scene.chapter.title=scene.title end
            out[#out+1]=b;for _,c in ipairs(b.clauses) do ledger.clauses[#ledger.clauses+1]=c end
        end
        if #blocks>0 then for _,s in ipairs(unit.scenes) do
            for _,id in ipairs(s.primaryDevelopmentIds) do ledger.primary[id]=s.sceneId end
            if s.prior then ledger.callbacks[#ledger.callbacks+1]={kind='PREVIOUSLY_INTRODUCED',sourceRef=s.prior.ref,sceneId=s.sceneId} end
        end end
    end
    plan.narratedDevelopmentLedger=ledger;return out
end

ns.Metis.Register('Author',A)
