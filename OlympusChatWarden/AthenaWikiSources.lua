-- Read-only adapters. Codex authors retain ownership of facts and source records.
local _,ns=...
local W=ns.AthenaLivingWiki
local npcByName,npcQuests,loreKeys,instanceBosses,unitNames,authoredArcs,authoredForQuest={}, {},{},{},{},{},{}
local function nonempty(v) return type(v)=='string' and v~='' and v~='UNKNOWN' end
local function prose(v)
 return nonempty(v) and not (v:match('^Reference rank:') or v:match('^Reference level:') or v:match('^Reference location:') or v:match('^Location:') or v:match('^Type:'))
end
local function compact(s) return W.NormalizeText(s):gsub('%s','') end
local function plainTitle(row) return row:match('^([^\031]*)') end
local function related(out,key,role,order) out=out.related or out;if W.ValidKey(key) then out[#out+1]={key=key,role=role,order=order} end end
local function text(v)
 if nonempty(v) then return v end
 if type(v)=='table' then local out={};for _,a in ipairs(v) do local t=type(a)=='table' and a.text or a;if nonempty(t) then out[#out+1]=t end end;return #out>0 and table.concat(out,'\n\n') or nil end
end
W.RegisterSource('10-quests',{
 version=function() return ns.AthenaQuestData.version end,
 Enumerate=function(emit)
  npcQuests={}
  for id,row in pairs(ns.AthenaQuestData.quests or {}) do
   emit(id,{key=W.Key('QUEST',id),kind='QUEST',nativeID=id,title=plainTitle(row)})
   -- The compact source stores giver and finisher IDs in fields three/four.
   local fields={};for value in (row..'\031'):gmatch('(.-)\031') do fields[#fields+1]=value;if #fields>=4 then break end end
   for at=3,4 do for n in (fields[at] or ''):gmatch('%d+') do local npc=tonumber(n);npcQuests[npc]=npcQuests[npc] or {};if #npcQuests[npc]<128 then npcQuests[npc][#npcQuests[npc]+1]={id=id,role=at==3 and 'Quest giver' or 'Quest recipient'} end end end
  end
 end,
 Resolve=function(id,ctx)
  local out={sections={},related={},sources={ns.AthenaQuestData.sourceURL},fields={questID=id}}
  local q,why;if ctx then q,why=ns.Athena.Knowledge.GetQuest(id,ctx) end
  if not q then out.locked=true;out.lockReason=why or 'PROGRESS_REQUIRED';out.summary='A quest reference. Its story and objectives follow this character’s accepted/completed stages and Athena spoiler choices.';return out end
  out.summary=text(q.summary) or text(q.setup) or text(q.premise)
  for _,field in ipairs({{'setup','The assignment'},{'objectives','Objectives'},{'motivations','Background'},{'conflict','The conflict'},{'stakes','What is at stake'},{'conclusion','Conclusion'},{'consequences','Aftermath'},{'loreConnections','Lore connections'}}) do
   local value=text(q[field[1]]);if value then out.sections[#out.sections+1]={title=field[2],text=value} end
  end
  out.fields.requiredLevel=q.requiredLevel;out.fields.level=q.level;out.fields.stage=q.observedStage
  for _,person in ipairs(q.characters or {}) do related(out,W.Key('NPC',person.npcID),person.role) end
  for _,other in ipairs(q.previousIDs or {}) do related(out,W.Key('QUEST',other),'Prerequisite') end
  for _,other in ipairs(q.nextIDs or {}) do related(out,W.Key('QUEST',other),'Following quest') end
  for _,place in ipairs(q.locations or {}) do if place.name then local lore=ns.AthenaLoreCodex.byTitle[place.name];if lore then related(out,loreKeys[lore],'Location') end end end
  local arc=ns.AthenaQuestArcFor[id];if arc then related(out,W.Key('CHAIN',arc),'Quest chain') end
  for _,authored in ipairs(authoredForQuest[id] or {}) do related(out,W.Key('CHAIN',authored),'Authored storyline') end
  return out
 end})
W.RegisterSource('20-npcs',{
 Enumerate=function(emit)
  npcByName={};unitNames={}
  for id,name in pairs(ns.AthenaQuestData.npcs or {}) do unitNames[id]=name end
  for id,loreID in pairs(ns.AthenaLoreCodex.byNPC or {}) do
   local e=ns.AthenaLoreCodex.byID[loreID];if e then unitNames[id]=e.title end
  end
  for id,name in pairs(unitNames) do
   local n=W.NormalizeText(name);if npcByName[n]~=nil then npcByName[n]=false else npcByName[n]=id end
   emit(id,{key=W.Key('NPC',id),kind='NPC',nativeID=id,title=name})
  end
 end,
 Resolve=function(id)
  local out={priority=10,sections={},related={},sources={ns.AthenaQuestData.sourceURL},fields={npcID=id}}
  local roles,seen={},{}
  for _,q in ipairs(npcQuests[id] or {}) do if not seen[q.id] then seen[q.id]=true;related(out,W.Key('QUEST',q.id),q.role);roles[q.role]=true end end
  local title=unitNames[id]
  local loreID=ns.AthenaLoreCodex.byNPC and ns.AthenaLoreCodex.byNPC[id]
  local e=loreID and ns.AthenaLoreCodex.byID[loreID]
  if e and e.catalogReferenceMetadata and e.catalogReferenceMetadata.separateObjectNamespaceCollision then return out end
  if next(roles) then out.summary=title..' is a named character associated with quests in the bundled reference.';out.sections[1]={title='Known roles',text=table.concat({roles['Quest giver'] and 'Offers recorded assignments.' or '',roles['Quest recipient'] and 'Receives recorded assignments.' or ''},' ')} end
  return out
 end})
local loreTypes={figure='NPC',creature='CREATURE',place='PLACE',instance='INSTANCE',faction='FACTION',event='EVENT',artifact='ITEM'}
W.RegisterSource('30-lore',{
 version=function() return ns.AthenaLoreCodex.VERSION end,
 Enumerate=function(emit)
  loreKeys={}
  local metas={}
  for _,id in ipairs(ns.AthenaLoreCodex.order) do
   local e=ns.AthenaLoreCodex.byID[id];local kind=loreTypes[e.kind] or 'LORE'
   if e.zoneCatalog or e.category=='zones' then kind='ZONE' elseif e.category=='battlegrounds' then kind='BATTLEGROUND' end
   local actor=kind=='NPC' or kind=='CREATURE'
   local numeric=actor and (e.npcIDs and e.npcIDs[1] or npcByName[W.NormalizeText(e.title)]) or nil
   local key=actor and numeric and W.Key('NPC',numeric) or W.Key(kind,e.id)
   loreKeys[id]=key
   local redirects={W.Key('LORE',id)}
   if actor and numeric then
    for _,nativeID in ipairs(e.npcIDs or {}) do if nativeID~=numeric then redirects[#redirects+1]=W.Key('NPC',nativeID) end end
    if kind=='CREATURE' then redirects[#redirects+1]=W.Key('CREATURE',numeric) end
   end
   metas[id]={key=key,kind=kind,title=e.title,aliases=e.aliases,redirects=redirects,nativeID=numeric,category=e.category}
  end
  for _,id in ipairs(ns.AthenaLoreCodex.order) do
   local e=ns.AthenaLoreCodex.byID[id];local meta=metas[id]
   if e.canonicalSubjectID and metas[e.canonicalSubjectID] then
    local target=metas[e.canonicalSubjectID];meta.key=target.key;meta.kind=target.kind;loreKeys[id]=target.key
   end
   emit(id,meta)
  end
 end,
 Resolve=function(id,ctx)
  local e=ns.AthenaLoreCodex.byID[id];if not e then return end
  -- Redirected reference identities must not contribute a second, metadata-only
  -- biography alongside the same canonical boss or character.
  if e.canonicalSubjectID then id=e.canonicalSubjectID;e=ns.AthenaLoreCodex.byID[id];if not e then return end end
  local out={priority=80,sections={},related={},sources={e.sourceURL},fields={category=e.category,era=e.era}}
  -- Quest-extracted circumstances keep the exact existing hash/stage gates.
  if e.questSourceProofs or e.gate=='QUEST_MENTION' then
   local safe=ctx and ns.Athena.Knowledge.GetLore('lore:'..id,ctx)
   if not safe then out.locked=true;out.lockReason='QUEST_CONTEXT_REQUIRED';return out end
   e=safe
  end
  local headings={role='Overview',appearance='Appearance',location='Location & environment',history='History',motivation='Motivations',conflict='Conflicts',stakes='What is at stake',relationships='Relationships',context='Lore & background',outcome='Outcome'}
  for _,field in ipairs({'role','appearance','location','history','context','motivation','relationships','conflict','stakes','outcome'}) do
   local value=e.fields and e.fields[field]
   local proof=e.fieldEvidence and e.fieldEvidence[field]
   local allowed=not proof or not proof.questSourceProofs or ns.AthenaLoreCodex.SourceAllowed(proof,ctx)
   if allowed and prose(value) then
    out.sections[#out.sections+1]={title=headings[field],text=value}
    if not out.summary and (field=='role' or field=='context' or field=='history') then out.summary=value end
    local source=e.fieldSources and e.fieldSources[field];if source then out.sources[#out.sources+1]=source end
   end
  end
  out.fields.referenceStatus=e.referenceStatus
  if e.catalogReferenceOnly then out.sections[#out.sections+1]={title='Reference coverage',text='An indexed source reference; its current placement and complete biography have not been verified.'} end
  for _,other in ipairs(e.related or {}) do
   if ns.AthenaLoreCodex.RelationAllowed(e,other,ctx) then
    local proof=e.relatedEvidence and e.relatedEvidence[other]
    related(out,loreKeys[other],proof and proof.predicate and proof.predicate:lower():gsub('_',' ') or 'Related subject')
   end
  end
  for _,boss in ipairs((e.kind=='instance' or e.subjectKind=='instance') and e.encounterReferences or {}) do related(out,loreKeys[boss.loreID],'Catalogued encounter') end
  for _,boss in ipairs(instanceBosses[id] or {}) do related(out,boss,'Catalogued encounter') end
  return out
 end})
W.RegisterSource('40-chains',{
 Enumerate=function(emit)
  authoredArcs={};authoredForQuest={}
  if ns.Athena.Knowledge.EachAuthoredArc then ns.Athena.Knowledge.EachAuthoredArc(function(id,title,quests)
   authoredArcs[id]=true;emit(id,{key=W.Key('CHAIN',id),kind='CHAIN',title=title})
   for _,qid in ipairs(quests) do authoredForQuest[qid]=authoredForQuest[qid] or {};authoredForQuest[qid][#authoredForQuest[qid]+1]=id end
  end) end
  for arc,members in pairs(ns.AthenaQuestArcMembers or {}) do
   local first=members[1];local row=first and ns.AthenaQuestData.quests[first]
   if row and #members>1 then emit(arc,{key=W.Key('CHAIN',arc),kind='CHAIN',title=plainTitle(row)..' — quest chain',aliases={plainTitle(row)}}) end
  end
 end,
 Resolve=function(id,ctx)
  local out={summary='A connected quest reference. Branches and prerequisites retain their source order; membership is not proof of completion.',sections={},related={},sources={ns.AthenaQuestData.sourceURL}}
  if authoredArcs[id] then
   local story=ctx and ns.Athena.Knowledge.GetLore('arc:'..id,ctx)
   local arc=ctx and ns.Athena.Knowledge.GetArc(id,ctx)
   if not story then out.locked=true;out.lockReason='PROGRESS_REQUIRED';return out end
   out.summary=story.body;out.fields={completed=arc.completed,authored=true}
   for ordinal,q in ipairs(arc.quests) do related(out,W.Key('QUEST',q.questID),'Known chapter',ordinal) end
   return out
  end
  for ordinal,qid in ipairs(ns.AthenaQuestArcMembers[id] or {}) do local q=ctx and ns.Athena.Knowledge.GetQuest(qid,ctx)
   if q then related(out,W.Key('QUEST',qid),'Known chapter',ordinal) end
  end
  if #out.related==0 then out.locked=true;out.lockReason='PROGRESS_REQUIRED' end;return out
 end})
W.RegisterSource('50-encounter-references',{
 Enumerate=function(emit)
  instanceBosses={}
  for i,e in ipairs(ns.ChronicleRunEndpoints or {}) do
   local id=npcByName[W.NormalizeText(e.name)];local key=id and W.Key('NPC',id) or W.Key('BOSS','endpoint-'..e.mapID..'-'..compact(e.name))
   local folder=e.sourceURL:match('/Classic/([^/]+)/') or e.sourceURL:match('/Shared/([^/]+)/')
   if folder then for _,lid in ipairs(ns.AthenaLoreCodex.order) do local l=ns.AthenaLoreCodex.byID[lid];if l.kind=='instance' then for _,alias in ipairs(l.aliases) do if compact(alias)==compact(folder) then instanceBosses[lid]=instanceBosses[lid] or {};instanceBosses[lid][#instanceBosses[lid]+1]=key end end end end end
   emit(i,{key=key,kind='BOSS',title=e.name,nativeID=id,redirects=e.encounterIDs[1] and {W.Key('BOSS','encounter-'..e.encounterIDs[1])} or {}})
  end
 end,
 Resolve=function(i)
  local e=ns.ChronicleRunEndpoints[i];local out={summary=e.name..' is a catalogued finishing encounter or wing endpoint.',sections={{title='Encounter reference',text=e.scope}},related={},sources={e.sourceURL},fields={instanceID=e.mapID}}
  local folder=e.sourceURL:match('/Classic/([^/]+)/') or e.sourceURL:match('/Shared/([^/]+)/')
  if folder then for _,id in ipairs(ns.AthenaLoreCodex.order) do local l=ns.AthenaLoreCodex.byID[id];if l.kind=='instance' then for _,alias in ipairs(l.aliases) do if compact(alias)==compact(folder) then related(out,loreKeys[id],'Dungeon or raid') end end end end end
  return out
 end})
-- Merge contract for the seven Codex branches. Only references/labels are indexed.
-- Resolve stays on the source adapter so new facts never get copied into a second DB.
function W.RegisterCodex(id,spec)
 assert(type(spec)=='table' and type(spec.records)=='table' and W.types[spec.kind],'Codex requires typed source records')
 W.RegisterSource('codex/'..id,{
  version=spec.version,
  Enumerate=function(emit)
   for id,record in pairs(spec.records) do
    local actorID=(spec.kind=='NPC' or spec.kind=='CREATURE' or spec.kind=='BOSS') and (record.npcID or record.creatureID)
    local key=record.wikiKey or actorID and ns.AthenaQuestData.npcs[actorID] and W.Key('NPC',actorID) or W.Key(spec.kind,id)
    local redirects={};for _,alias in ipairs(record.redirects or {}) do redirects[#redirects+1]=alias end
    if key~=W.Key(spec.kind,id) then redirects[#redirects+1]=W.Key(spec.kind,id) end
    emit(id,{key=key,kind=record.wikiKind or spec.kind,nativeID=record.nativeID or actorID or type(id)=='number' and id,title=record.title or record.name,aliases=record.aliases,redirects=redirects,icon=record.icon})
   end
  end,
  Resolve=function(id,ctx)
   if spec.Resolve then return spec.Resolve(id,ctx) end
   local r=spec.records[id];if not r then return end
   local out={priority=spec.priority or 100,summary=text(r.summary) or text(r.description),expectedBosses=#(r.bosses or {}),fields={},sections={},related={},sources={},rosterComplete=r.rosterComplete==true}
   for _,url in ipairs(r.sources or {}) do out.sources[#out.sources+1]=url end;if r.sourceURL then out.sources[#out.sources+1]=r.sourceURL end
   -- Source-backed article text only. An adapter may apply stricter stage gates.
   if r.verified~=true and #out.sources==0 then out.summary=nil;return out end
   if spec.kind=='QUEST' then
    -- Reuse the existing staged reference projection, never a raw Codex ending.
    return W.sources['10-quests'].Resolve(r.questID or id,ctx)
   elseif r.questID then
    local q=ctx and ns.Athena.Knowledge.GetQuest(r.questID,ctx)
    if not q or (q.observedStage or 0)<(r.minimumStage or 4) or r.sourceHash and r.sourceHash~=q.sourceHash then out.summary=nil;out.locked=true;out.lockReason='PROGRESS_REQUIRED';return out end
   end
   for _,field in ipairs({'description','appearance','environment','history','lore','classification','roles','motivations','relationships','gameplay','objectives','prerequisites'}) do local value=text(r[field]);if value then out.sections[#out.sections+1]={title=field:sub(1,1):upper()..field:sub(2),text=value} end end
   for _,field in ipairs({'level','requiredLevel','npcID','creatureID','displayID','instanceID','itemID','encounterID','faction','quality','slot'}) do out.fields[field]=r[field] end
   for _,other in ipairs(r.related or {}) do out.related[#out.related+1]=other end
   for ordinal,boss in ipairs(r.bosses or {}) do local k=type(boss)=='table' and (boss.key or W.Key('BOSS',boss.id)) or type(boss)=='string' and W.ValidKey(boss) and boss or W.Key('BOSS',boss);related(out,k,'Boss',r.encounterOrderVerified==true and ordinal or nil) end
   for _,item in ipairs(r.loot or {}) do local id=type(item)=='table' and (item.itemID or item.id) or item;related(out,W.Key('ITEM',id),'Referenced loot') end
   if r.obtainable==true and r.availabilitySource then out.sections[#out.sections+1]={title='Availability',text='This source identifies the item as obtainable: '..r.availabilitySource}
   elseif r.loot or spec.kind=='ITEM' then out.sections[#out.sections+1]={title='Availability',text='This is a reference entry. Current obtainability is not established by this source.'} end
   return out
  end})
end
-- A Codex merge may register before or after this module loads.
for id,spec in pairs(ns.WardenDB.WikiSources or {}) do W.RegisterCodex(id,spec) end
