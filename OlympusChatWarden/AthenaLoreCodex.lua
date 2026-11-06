-- Shared structured lore for the encyclopedia and scene author. No collectors.
local _,ns=...
local D=ns.AthenaLoreCodexInput;ns.AthenaLoreCodexInput=nil
local L={VERSION=D.version,byID={},byTitle={},byNPC={},order={},fields={'role','appearance','location','history','motivation','conflict','stakes','outcome','relationships','context'}}
ns.AthenaLoreCodex=L;ns.WardenDB.Lore=L
local function Copy(v) return ns.Athena.Copy(v) end
-- Entries have a derived-field metatable; the shared copier intentionally
-- refuses those. Copy canonical own fields through a plain table instead.
local function PlainEntry(e)
    local raw={};for key,value in pairs(e) do raw[key]=value end
    return Copy(raw)
end
local function Slug(v) return v:lower():gsub('[^%w%s%-]',''):gsub('%s+','-') end
-- Raw fields/provenance remain canonical and resident. Per-field narrative
-- objects are a bounded, rebuildable projection, not a second full codex.
local derived,derivedOrder={},{}
function L.ReleaseDerived() derived={};derivedOrder={} end
local function Derived(e)
    local value=derived[e.id];if value then return value end
    value={facts={},missing={}}
    for _,field in ipairs(L.fields) do
        local text=e.fields[field]
        if type(text)=='string' and text~='UNKNOWN' and #text>0 then
            value.facts[#value.facts+1]={field=field,text=text,worldRef=e.worldRef..'/'..field,sourceURL=e.fieldSources and e.fieldSources[field] or e.sourceURL,era=e.era,
                sourceVersion=e.fieldVersions and e.fieldVersions[field] or e.sourceVersion or L.VERSION,sourceEvidence=Copy(e.fieldEvidence and e.fieldEvidence[field])}
        else value.missing[#value.missing+1]=field end
    end
    if #derivedOrder>=96 then derived[table.remove(derivedOrder,1)]=nil end
    derivedOrder[#derivedOrder+1]=e.id;derived[e.id]=value;return value
end
local entryMeta={__index=function(e,key) if key=='facts' or key=='missing' then return Derived(e)[key] end end}
local function Register(e)
    assert(type(e.id)=='string' and not L.byID[e.id] and type(e.title)=='string' and type(e.fields)=='table','Invalid lore subject')
    e.sourceURL=e.sourceURL or assert(D.sources[e.source],'Missing lore source')
    e.era=D.era;e.worldRef='lore:'..L.VERSION..'/'..e.id
    e.aliases=e.aliases or {e.title};e.category=e.category or (e.kind=='figure' and 'figures' or e.kind=='creature' and 'creatures' or e.kind=='event' and 'wars' or e.kind=='instance' and 'dungeons' or 'places')
    for _,field in ipairs(L.fields) do
        local text=e.fields[field]
        if type(text)~='string' or text=='UNKNOWN' or #text==0 then e.fields[field]='UNKNOWN' end
    end
    e.facts=nil;e.missing=nil;setmetatable(e,entryMeta)
    L.byID[e.id]=e
    -- Source-addressed units and places may share a displayed name. Keep the
    -- earlier curated subject for name-only context; exact IDs stay distinct.
    if not e.catalogReferenceOnly or not L.byTitle[e.title] then L.byTitle[e.title]=e.id end
    L.order[#L.order+1]=e.id
    for _,id in ipairs(e.npcIDs or {}) do
        assert(not L.byNPC[id] or L.byNPC[id]==e.id,'Conflicting canonical NPC subject')
        L.byNPC[id]=e.id
    end
    for _,alias in ipairs(e.aliases) do
        if not L.byTitle[alias] then L.byTitle[alias]=e.id end
        local native=alias:gsub('’',"'");if not L.byTitle[native] then L.byTitle[native]=e.id end
    end
end
local basicReferences={}
for _,e in ipairs(D.entries) do
    if e.catalogReferenceOnly then basicReferences[#basicReferences+1]=e else Register(e) end
end
for kind,rows in pairs({place=ns.AthenaWorldScenes.places,instance=ns.AthenaWorldScenes.instances,figure=ns.AthenaWorldScenes.figures}) do
    for _,c in pairs(rows) do local id=c.key or Slug(c.title)
        if not L.byID[id] and not L.byTitle[c.title] then Register({id=id,title=c.title,kind=kind,category=({thrall='horde',jaina='alliance',sylvanas='horde',tyrande='nightelves',arthas='fallenpowers',vancleef='fallenpowers'})[id],sourceURL=c.sourceURL,fields={context=c.body},aliases=c.aliases or {c.title},
            gate=c.requiredQuestMention and 'QUEST_MENTION' or (kind=='instance' or id=='vancleef') and 'DISCOVERY' or 'HISTORICAL',variants=c.variants,
            requiredMentions=c.requiredQuestMention and (c.title=='Wailing Caverns' and {'Naralex'} or {'Arugal','worgen'}) or nil}) end
    end
end
for _,name in ipairs({'Ashenvale','Elwynn Forest','Durotar'}) do local c=ns.AthenaWorldSettings.Get(name)
    if c and not L.byID[Slug(name)] and not L.byTitle[name] then Register({id=Slug(name),title=name,kind='place',sourceURL=c.sourceURL,fields={context=c.body},gate='HISTORICAL'}) end
end
for _,race in ipairs({{'Human','Alliance','Humans'},{'Dwarf','Alliance','Dwarves'},{'Gnome','Alliance','Gnomes'},
    {'NightElf','Alliance','Night Elves'},{'Orc','Horde','Orcs'},{'Troll','Horde','Darkspear Trolls'},{'Undead','Horde','The Forsaken'}}) do
    local id=Slug(race[3]);if not L.byID[id] and not (id=='the-forsaken') then
        local cards=ns.AthenaWorldKnowledge.Prologue({race=race[1],faction=race[2]});local c=cards[#cards]
        if c then Register({id=id,title=race[3],kind='faction',category='peoples',sourceURL=c.sourceURL,fields={history=c.text},gate='HISTORICAL'}) end
    end
end
-- Legacy scene knowledge gets first choice of its existing canonical name.
-- Bulk identity references cannot suppress its richer figure/place context.
for _,e in ipairs(basicReferences) do Register(e) end
table.sort(L.order,function(a,b) local x,y=L.byID[a],L.byID[b];return x.title==y.title and a<b or x.title<y.title end)
if ns.AthenaLoreBuildIndex then ns.AthenaLoreBuildIndex.Release()end
local function Mention(text,alias,person)
    if type(text)~='string' then return false end
    text=text:lower():gsub('’',"'");alias=alias:lower():gsub('’',"'");local at=1
    while true do local a,b=text:find(alias,at,true);if not a then return false end
        local suffix=text:sub(b+1):match('^%s+(%a+)')
        local placeSuffix=person and ({village=true,city=true,keep=true,hold=true,tower=true,camp=true,hall=true,inn=true})[suffix]
        if not placeSuffix and not text:sub(a-1,a-1):match('%a') and not text:sub(b+1,b+1):match('%a') then return true end;at=b+1
    end
end
local function Known(e,c)
    if type(c)~='table' or type(c.progress)~='table' then return false end
    if e.gate=='HISTORICAL' or c.allowLoreSpoilers then return true end
    if e.gate=='QUEST_MENTION' then return c.progress.loreMentions and c.progress.loreMentions[e.id] end
    for _,alias in ipairs(e.aliases) do
        if c.progress.placeNames and c.progress.placeNames[alias] or c.progress.instanceNames and c.progress.instanceNames[alias]
            or c.progress.npcNames and c.progress.npcNames[alias] then return true end
    end
    for _,id in ipairs(e.related or {}) do local other=not (e.relatedEvidence and e.relatedEvidence[id]) and L.byID[id]
        if other and other.kind=='instance' then for _,alias in ipairs(other.aliases) do if c.progress.instanceNames and c.progress.instanceNames[alias] then return true end end end
    end
end
-- Reviewed quest circumstances remain bound to their exact eligible source.
-- Spoiler preferences cannot override race/class, hash or observed-stage proof.
function L.SourceAllowed(e,c)
    if not e.questSourceProofs then return true end
    if not c or not ns.Athena.Knowledge.ContextAllowed(c) then return false end
    local all=e.questSourceProofsMode=='ALL';local proved=0
    for _,proof in ipairs(e.questSourceProofs) do
        local q=ns.Athena.Knowledge.GetQuest(proof.questID,c)
        if q and q.sourceHash==proof.sourceHash and (q.observedStage or 0)>=(proof.minimumStage or 2) then
            local seen={};for _,a in ipairs(q.narrative and q.narrative.atoms or {}) do seen[a.id]=true end
            local complete=true;for _,id in ipairs(proof.atomIDs) do if not seen[id] then complete=false;break end end
            if complete then
                if not all then return true end
                proved=proved+1
            end
        end
    end
    return all and #e.questSourceProofs>0 and proved==#e.questSourceProofs or false
end
function L.Visible(id,c,ctx)
    local e=L.byID[(id or ''):gsub('^lore:','')]
    return e~=nil and Known(e,c) and L.SourceAllowed(e,ctx) or false
end
function L.RelationAllowed(e,id,ctx,c)
    local proof=e.relatedEvidence and e.relatedEvidence[id]
    if not proof then return true end
    if not L.SourceAllowed(proof,ctx) then return false end
    -- A new edge never discovers either endpoint or silently follows an
    -- identity alias past a stricter original subject gate.
    local function visible(key)
        return c and L.Visible(key,c,ctx) or not c and ns.Athena.Knowledge.LoreVisible(key,ctx)
    end
    return visible((e.id or ''):gsub('^lore:','')) and visible(id)
        and visible(proof.subjectLoreID) and visible(proof.objectLoreID) or false
end
function L.Entry(id,c,ctx)
    id=id:gsub('^lore:','');local e=L.byID[id]
    if not e then return nil,'UNKNOWN' end
    -- c is the internal, validated view used for discovery; ctx is the opaque
    -- permission handle accepted by Knowledge. They are deliberately distinct.
    if not Known(e,c) or not L.SourceAllowed(e,ctx) then return nil,'LOCKED' end
    -- Copy only canonical own fields into a plain projection. Athena's general
    -- copier deliberately refuses metatables; that boundary stays unchanged.
    local out=PlainEntry(e);out.id='lore:'..e.id;out.section=e.kind=='figure' and 'figures' or e.kind=='creature' and 'creatures' or e.kind=='event' and 'ages' or e.kind=='faction' and 'peoples' or e.kind=='artifact' and 'artifacts' or e.kind=='instance' and 'dungeons' or 'places'
    out.kind='WORLD_HISTORY';out.subjectKind=e.kind;out.body='';local text={};out.facts={};out.missing=Copy(e.missing);out.lockedFields={}
    for _,f in ipairs(e.facts) do
        if L.SourceAllowed(f.sourceEvidence or {},ctx) then out.facts[#out.facts+1]=Copy(f);text[#text+1]=f.text
        else
            -- Keep basic identity readable while a quest-derived description
            -- waits for its own existing hash/stage/branch proof.
            out.fields[f.field]='UNKNOWN';out.lockedFields[f.field]=true
            if out.fieldEvidence then out.fieldEvidence[f.field]=nil end
            if out.fieldSources then out.fieldSources[f.field]=nil end
            if out.fieldVersions then out.fieldVersions[f.field]=nil end
        end
    end;out.body=table.concat(text,' ')
    out.relatedIDs={};out.related={};out.relatedEvidence=nil
    for _,other in ipairs(e.related or {}) do local row=L.byID[other]
        if row and Known(row,c) and L.SourceAllowed(row,ctx) and L.RelationAllowed(e,other,ctx,c) then
            out.relatedIDs[#out.relatedIDs+1]='lore:'..other;out.related[#out.related+1]=other
        end
    end
    out.personalExperienceProven=false;out.observedWeather=false;out.revealedManually=c.allowLoreSpoilers==true;return out
end
function L.VisibleIDs(kind,c,ctx)
    if not ns.Athena.Knowledge.ContextAllowed(ctx) then return {} end
    local out={}
    for _,id in ipairs(L.order) do local e=L.byID[id]
        if e.kind==kind and Known(e,c) and L.SourceAllowed(e,ctx) then out[#out+1]='lore:'..id end
    end
    return out
end
function L.IDs() local out={};for _,id in ipairs(L.order) do out[#out+1]='lore:'..id end;return out end
function L.Mark(card,used) local id=card and L.byTitle[card.title];if id then used[id]=true end end
function L.Coverage()
    local counts,missing={},{};local facts=0
    for _,id in ipairs(L.order) do local e=L.byID[id];counts[e.kind]=(counts[e.kind] or 0)+1;facts=facts+#e.facts;missing[id]=Copy(e.missing) end
    local zones={expected=D.zoneManifest and #D.zoneManifest.titles or 0,covered=0,missing={},sourceURL=D.zoneManifest and D.zoneManifest.sourceURL,version=D.zoneManifest and D.zoneManifest.version}
    for _,title in ipairs(D.zoneManifest and D.zoneManifest.titles or {}) do
        local id=L.byTitle[title];local e=id and L.byID[id]
        if e and e.kind=='place' and e.zoneCatalog then zones.covered=zones.covered+1 else zones.missing[#zones.missing+1]=title end
    end
    return {version=L.VERSION,era=D.era,subjects=#L.order,facts=facts,byKind=counts,missing=missing,zones=zones,exhaustive=false}
end
function L.Setting(place,seed,ctx)
    local title=place and (place.inInstance and place.instanceName or place.subzone and L.byTitle[place.subzone] and place.subzone or place.zone)
    local id=title and L.byTitle[title];local e=id and L.byID[id]
    if not e or e.catalogReferenceOnly or e.kind~='place' and e.kind~='instance' or not L.SourceAllowed(e,ctx) then return end
    -- World geography and historical atmosphere never become observed weather,
    -- an asserted route through a subzone, or a personal encounter outcome.
    local journalFields;if e.journalFields then journalFields={};for _,field in ipairs(e.journalFields) do journalFields[field]=true end end
    for _,field in ipairs({'appearance','history','location','context'}) do
        for _,f in ipairs(e.facts) do if f.field==field and (not journalFields or journalFields[field]) and not (f.sourceEvidence and f.sourceEvidence.narrativeUse=='REFERENCE_ONLY') and L.SourceAllowed(f.sourceEvidence or {},ctx) then
            return {title=e.title,body=f.text,worldRef=f.worldRef,sourceURL=f.sourceURL,sourceVersion=f.sourceVersion or L.VERSION,sourceEvidence=Copy(f.sourceEvidence),
                kind='WORLD_HISTORY',era=e.era,personalExperienceProven=false,observedWeather=false,field=field}
        end end
    end
end
function L.Pick(scene,ref,used,seed)
    local ctx=scene.story.knowledgeContext
    if not ctx or not ns.Athena.Knowledge.ContextAllowed(ctx) then return end
    local text,primaryPeople={},{};local qid=ref and (ref.questID or ref.id)
    -- Re-obtain the stage-gated source rather than trusting a label or player name.
    local q=qid and ns.Athena.Knowledge.ReferenceForStory({knowledgeContext=ctx,factualClaims=scene.claims},qid)
    if q then
        text[#text+1]=q.giverName or '';text[#text+1]=q.premise or ''
        primaryPeople[#primaryPeople+1]=q.giverName or '';primaryPeople[#primaryPeople+1]=q.finisherName or ''
        for _,atom in ipairs(q.narrative and q.narrative.atoms or {}) do
            text[#text+1]=atom.text
            if atom.field=='objective' then primaryPeople[#primaryPeople+1]=atom.text end
        end
    end
    local place=scene.place or scene.story.node.place or {}
    -- A setting may mention a city or a historical figure; that is not a
    -- reason to append their biography to every unrelated local errand.
    -- Quest figures come from this quest's eligible source, not another card.
    if not q then
        text[#text+1]=place.instanceName or place.zone or ''
        -- Only a typed, permitted encounter claim supplies a boss subject.
        -- Roster names, place text and an instance visit cannot substitute.
        if scene.focus=='ACTIVITY' then for _,claim in ipairs(scene.claims or {}) do
            if claim.claimType=='encounter_attempt' and type(claim.value)=='table' and type(claim.value.name)=='string' then
                text[#text+1]=claim.value.name;primaryPeople[#primaryPeople+1]=claim.value.name
            end
        end end
    end
    local corpus=table.concat(text,' ');local peopleCorpus=table.concat(primaryPeople,' ');local candidates={}
    for _,id in ipairs(L.order) do local e=L.byID[id]
        local localPlace=(e.kind~='place' and e.kind~='instance') or e.title==place.zone or e.title==place.instanceName
        local creatureAllowed=e.kind~='creature' or scene.creatureLoreAllowed~=false
        if not e.catalogReferenceOnly and localPlace and creatureAllowed and not used[id] and (not q or e.kind=='figure' or e.kind=='creature' or e.kind=='place' or e.kind=='instance' or e.kind=='artifact') then for _,alias in ipairs(e.aliases) do
          local primaryPerson=e.kind=='figure' and Mention(peopleCorpus,alias,true)
          local relevant=not q or e.kind~='figure' or primaryPerson or e.requiredMentions or e.journalMentionRelevant
          if relevant and Mention(corpus,alias,e.kind=='figure') then
            local entry=ns.Athena.Knowledge.GetLore('lore:'..id,ctx)
            -- An eligible quest mentioning a subject unlocks a contextual atom;
            -- it still does not prove a personal meeting or an encounter outcome.
            if not entry and q and L.SourceAllowed(e,ctx) and (e.gate~='QUEST_MENTION' or ns.Athena.Knowledge.NoteLoreSubject(ctx,e.id,qid,scene.claims)) then
                entry=PlainEntry(e);entry.facts=Copy(e.facts);entry.missing=Copy(e.missing)
                -- This is a contextual prose fallback, never a relation index.
                entry.related=nil;entry.relatedEvidence=nil
            end
            if entry then
                entry.questRoleRelevance=q and primaryPerson or false
                entry.observedEncounterRelevance=not q and primaryPerson or false
                candidates[#candidates+1]=entry
            end;break
        end end end
    end
    if #candidates==0 then return end
    table.sort(candidates,function(a,b)
        local function Rank(e)
            if e.questRoleRelevance or e.observedEncounterRelevance then return 3 end
            if e.subjectKind=='creature' or e.kind=='creature' then return 2 end
            if e.subjectKind=='figure' or e.kind=='figure' then return 1 end
            return 0
        end
        local ar,br=Rank(a),Rank(b);if ar~=br then return ar>br end;return a.title<b.title
    end)
    local hash=0;for i=1,#seed do hash=(hash*33+seed:byte(i))%2147483647 end
    for _,e in ipairs(candidates) do
        local journalFields
        if e.journalFields then journalFields={};for _,field in ipairs(e.journalFields) do journalFields[field]=true end end
        local facts={};for _,f in ipairs(e.facts) do
            local repeatedSource=false
            local contextualSource=true
            local fieldProofs=f.sourceEvidence and f.sourceEvidence.questSourceProofs
            if fieldProofs then
                -- A later quest known elsewhere in the book must not explain
                -- an earlier scene. Reuse these new source facts only in their
                -- own account or a verified immediate successor.
                contextualSource=q~=nil
                for _,proof in ipairs(fieldProofs) do
                    local linked=proof.questID==qid
                    for _,previous in ipairs(q and q.previousIDs or {}) do if proof.questID==previous then linked=true;break end end
                    if not linked then contextualSource=false;break end
                end
            end
            if q and (q.setup or q.storyContext and q.storyContext.editorial) then
                for _,proof in ipairs(f.sourceEvidence and f.sourceEvidence.questSourceProofs or {}) do
                    if proof.questID==qid then repeatedSource=true;break end
                end
            end
            local namedSubject=e.kind=='figure' or e.subjectKind=='figure' or e.kind=='creature' or e.subjectKind=='creature'
            local named=not namedSubject
            if namedSubject then for _,alias in ipairs(e.aliases) do if Mention(f.text,alias) then named=true;break end end end
            -- A field is readable inside its encyclopedia entry but may have
            -- no antecedent in a novel ("His blessing...", "enslaved her").
            -- Automatic insertion requires the figure to be named explicitly.
            if named and contextualSource and not repeatedSource and (not journalFields or journalFields[f.field]) and not (f.sourceEvidence and f.sourceEvidence.narrativeUse=='REFERENCE_ONLY') and L.SourceAllowed(f.sourceEvidence or {},ctx) and not (scene.setting and scene.setting.body==f.text) then facts[#facts+1]=f end
        end
        if #facts>0 then
            used[e.id:gsub('^lore:','')]=true;local f=facts[hash%#facts+1]
            return {title=e.title,body=f.text,worldRef=f.worldRef,sourceURL=f.sourceURL,sourceVersion=f.sourceVersion or L.VERSION,sourceEvidence=Copy(f.sourceEvidence),kind='WORLD_HISTORY',era=e.era,
                questID=qid,questWorldRef=q and q.worldRef,questSourceContext=e.questSourceProofs~=nil or f.sourceEvidence and f.sourceEvidence.questSourceProofs~=nil or false,subjectKind=e.subjectKind or e.kind,
                personalExperienceProven=false,observedWeather=false,field=f.field}
        end
    end
end
