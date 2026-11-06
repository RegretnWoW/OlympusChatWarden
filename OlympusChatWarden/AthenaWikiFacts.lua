-- Read-only projection of retained Codex fields. No imported catalog, collector,
-- SavedVariables, network data type, or second subject database.
local _,ns=...
local W,K,L=ns.AthenaLivingWiki,ns.Athena.Knowledge,ns.AthenaLoreCodex
local areaPlaces,areaQuests,unitLoot,itemRefs,instanceQuests={},{},{},{},{}
local function value(v)
 if type(v)=='number' then return v==v and tostring(v) or nil end
 if type(v)~='string' or v=='' or v=='UNKNOWN' or v=='unknown' or v:find('[%z\001-\008\011-\031]') then return end
 return v
end
local function add(out,label,v,source,qualification,key)
 v=value(v);if not v then return end
 out.quickFacts=out.quickFacts or {};out.quickFacts[#out.quickFacts+1]={label=label,value=v,sourceURL=source,qualification=qualification,key=key}
end
local function related(out,key,role)
 if W.ValidKey(key) then out.related=out.related or {};out.related[#out.related+1]={key=key,role=role} end
end
local function loreKey(e)
 local kind=e.zoneCatalog and 'ZONE' or e.category=='battlegrounds' and 'BATTLEGROUND' or ({place='PLACE',instance='INSTANCE',figure='NPC',creature='CREATURE',artifact='ITEM',faction='FACTION',event='EVENT'})[e.kind] or 'LORE'
 if (kind=='NPC' or kind=='CREATURE') and e.npcIDs and e.npcIDs[1] then return W.Canonical(W.Key('NPC',e.npcIDs[1])) end
 return W.Canonical(W.Key(kind,e.id))
end
local function safeEntry(e,ctx)
 if e.canonicalSubjectID then e=L.byID[e.canonicalSubjectID] end
 if e.questSourceProofs or e.gate=='QUEST_MENTION' then return ctx and K.GetLore('lore:'..e.id,ctx) end
 return e
end
local function mask(v,names)
 if not v or v<=0 then return end
 local out,known={},0
 for _,p in ipairs(names) do if math.floor(v/p[1])%2==1 then out[#out+1]=p[2];known=known+p[1] end end
 if known~=v then out[#out+1]='Other source-defined eligibility ('..tostring(v-known)..')' end
 return #out>0 and table.concat(out,', ') or nil
end
local races={{1,'Human'},{2,'Orc'},{4,'Dwarf'},{8,'Night Elf'},{16,'Forsaken'},{32,'Tauren'},{64,'Gnome'},{128,'Troll'}}
local classes={{1,'Warrior'},{2,'Paladin'},{4,'Hunter'},{8,'Rogue'},{16,'Priest'},{64,'Shaman'},{128,'Mage'},{256,'Warlock'},{1024,'Druid'}}
local questSource=W.sources['10-quests'];local oldQuest=questSource.Resolve
questSource.Resolve=function(id,ctx)
 local out=oldQuest(id,ctx);local f=K.QuestReferenceFields(id)
 if f then
  local qualification='Bundled source reference · '..f.sourceVersion
  add(out,'Quest level',f.level and f.level>0 and f.level or nil,f.sourceURL,qualification)
  add(out,'Minimum level',f.requiredLevel and f.requiredLevel>0 and f.requiredLevel or nil,f.sourceURL,qualification)
  add(out,'Race eligibility',mask(f.racesMask,races),f.sourceURL,qualification)
  add(out,'Class eligibility',mask(f.classesMask,classes),f.sourceURL,qualification)
 end
 local q=ctx and K.GetQuest(id,ctx);if not q then return out end
 local url=q.sourceURL;out.questNavigation={}
 local seen={}
 for _,pair in ipairs({{'giverIDs','Given by'},{'finisherIDs','Turn in to'}}) do
  for _,npc in ipairs(q[pair[1]] or {}) do local name=ns.AthenaQuestData.npcs[npc]
   if name then add(out,pair[2],name,url,'Quest-source identity',W.Key('NPC',npc));seen[npc]=true end
  end
 end
 if #(q.giverIDs or {})==0 then add(out,'Given by',q.giverName,url,'Reported by the eligible quest source') end
 if #(q.finisherIDs or {})==0 then add(out,'Turn in to',q.finisherName,url,'Reported by the eligible quest source') end
 for _,loc in ipairs(q.locations or {}) do
  local key=loc.areaID and areaPlaces[loc.areaID]
  add(out,'Location',loc.name,url,loc.certainty=='EXPLICIT_SOURCE_ID' and 'Typed source location' or 'Quest-source location reference',key)
 end
 for _,item in ipairs(q.narrative and q.narrative.objectiveEntities or {}) do
  local key=item.kind=='NPC' and W.Key('NPC',item.id) or item.kind=='ITEM' and W.Key('ITEM',item.id)
  if key then related(out,key,item.role and item.role:lower():gsub('_',' ') or 'Objective reference') end
 end
 for _,p in ipairs({{'previousIDs','Previous quest / branch'},{'nextIDs','Next quest / branch'}}) do
  for _,other in ipairs(q[p[1]] or {}) do
   local visible=K.GetQuest(other,ctx)
   if visible then out.questNavigation[#out.questNavigation+1]={key=W.Key('QUEST',other),label=visible.title,role=p[2]} end
  end
 end
 -- No reward catalogue is inferred from objective items or instance loot.
 -- If a retained source supplies a distinct reward field, its original stage
 -- projection owns visibility; no new rewards or outcomes are synthesized.
 for _,p in ipairs({{'guaranteedRewards','Guaranteed reward'},{'choiceRewards','Choice reward'}}) do
  for _,reward in ipairs(q[p[1]] or {}) do if reward.itemID and reward.name then add(out,p[2],reward.name,url,'Eligible retained quest reward',W.Key('ITEM',reward.itemID)) end end
 end
 return out
end
local oldLore=W.sources['30-lore'];local oldEnumerate,oldResolve=oldLore.Enumerate,oldLore.Resolve
oldLore.Enumerate=function(emit)
 areaPlaces,areaQuests,instanceQuests={},{},{};oldEnumerate(emit)
 for _,id in ipairs(L.order) do local e=L.byID[id]
  for _,candidate in ipairs(e.catalogReferenceMetadata and e.catalogReferenceMetadata.sourceLocationCandidates or {}) do
   local area=tonumber(tostring(candidate.id):match('^area%-(%d+)$'))
   if area and (not areaPlaces[area] or e.kind=='instance') then areaPlaces[area]=loreKey(e) end
  end
 end
 K.EachQuestAreaReference(function(id,area,stage,name)
  if areaPlaces[area] then local rows=areaQuests[area] or {};areaQuests[area]=rows;rows[#rows+1]={id=id,stage=stage} end
  -- This is the same exact retained location-name relation the original
  -- quest adapter uses. It is a source mention, never a native map binding.
  local lid=name and L.byTitle[name];local e=lid and L.byID[lid]
  if e and e.kind=='instance' then local key=loreKey(e);local rows=instanceQuests[key] or {};instanceQuests[key]=rows;rows[#rows+1]={id=id,name=name,stage=stage} end
 end)
end
oldLore.Resolve=function(id,ctx)
 local out=oldResolve(id,ctx);local e=safeEntry(L.byID[id],ctx);if not e then return out end
 local m=e.catalogReferenceMetadata or {};local w=m.worldLayerReference or {};local observed=e.observedIdentity or m.observedIdentity or {}
 local source=w.sourceURL or e.sourceURL
 local qualification=w.evidence and 'World-layer reference · current Forever placement unverified' or e.referenceQualification and 'Qualified retained source reference' or 'Bundled source reference'
 add(out,'Level',w.levelRange or observed.reportedLevel,source,qualification)
 add(out,'Classification',w.rank,source,qualification)
 add(out,'Reaction',w.reaction,source,qualification)
 add(out,'Creature type',observed.creatureType,e.sourceURL,'Publisher-reported reference')
 add(out,'Role',observed.role,e.sourceURL,'Publisher-reported reference')
 add(out,'Zone',observed.zone or w.zone,e.sourceURL,qualification)
 add(out,'Subzone',observed.subarea,e.sourceURL,'Publisher-reported reference')
 add(out,'Known location',observed.location,e.sourceURL,'Publisher-reported reference')
 add(out,'Region',e.region,e.sourceURL,'Retained location reference')
 for _,candidate in ipairs(m.sourceLocationCandidates or {}) do
  add(out,'Map',candidate.mapName,e.sourceURL,'Retained map reference · not an exact position')
 end
 local original=e.referenceSource and e.referenceSource.sourceFields
 if original then
  add(out,'Profession / role',original.title,e.referenceSource.sourceURL,'Retained source description')
  add(out,'Creature type',original.type,e.referenceSource.sourceURL,'Retained source description')
  add(out,'Zone',original.zone,e.referenceSource.sourceURL,'Retained source description')
  add(out,'Subzone',original.sub,e.referenceSource.sourceURL,'Retained source description')
 end
 local rules=e.foreverReferenceRules
 if rules then
  local range=rules.levelRange;range=type(range)=='table' and range[1] and (range[1]..'–'..tostring(range[2] or range[1])) or range
  local qual='Published Forever reference · current access unverified'
  add(out,'Recommended levels',range,rules.sourceURL,qual);add(out,'Minimum entry level',rules.requiredLevel,rules.sourceURL,qual)
  add(out,'Group size',rules.groupSize,rules.sourceURL,qual);add(out,'Entrance / region',rules.publishedLocation,rules.sourceURL,qual)
  add(out,'Entry item',rules.attunementItem,rules.sourceURL,qual)
 end
 if e.parentName then add(out,'Parent location',e.parentName,e.sourceURL,'Retained place reference') end
 out.dungeonQuests={}
 if e.kind=='instance' then
  local seen={}
  for _,link in ipairs(instanceQuests[loreKey(e)] or {}) do if not seen[link.id] then
   local q=ctx and K.GetQuest(link.id,ctx)
   if q then for _,loc in ipairs(q.locations or {}) do if loc.name==link.name then
    out.dungeonQuests[#out.dungeonQuests+1]={key=W.Key('QUEST',link.id),label=q.title,role='Quest source names this instance'};seen[link.id]=true;break
   end end end
  end end
  for _,candidate in ipairs(m.sourceLocationCandidates or {}) do
   local area=tonumber(tostring(candidate.id):match('^area%-(%d+)$'))
   for _,link in ipairs(area and areaQuests[area] or {}) do
    if not seen[link.id] then local q=ctx and K.GetQuest(link.id,ctx)
     if q then
      for _,loc in ipairs(q.locations or {}) do if loc.areaID==area then
       out.dungeonQuests[#out.dungeonQuests+1]={key=W.Key('QUEST',link.id),label=q.title,role='Dungeon quest'};seen[link.id]=true;break
      end end
     end
    end
   end
  end
  for _,ref in ipairs(e.referenceLoot or {}) do related(out,W.Key('ITEM',ref.publishedItemID),'Retained loot reference') end
 end
 for _,native in ipairs(e.npcIDs or {}) do
  for _,ref in ipairs(unitLoot[native] or {}) do related(out,W.Key('ITEM',ref.id),'Retained source item') end
 end
 return out
end
-- These item references already live inside retained instance records. Index
-- their existing labels, resolving back to the original record on demand.
W.RegisterSource('55-retained-instance-items',{
 Enumerate=function(emit)
  unitLoot,itemRefs={},{}
  for _,id in ipairs(L.order) do local e=L.byID[id]
   for at,item in ipairs(e.referenceLoot or {}) do
    if type(item.publishedItemID)=='number' and value(item.name) then
     local refs=itemRefs[item.publishedItemID] or {};itemRefs[item.publishedItemID]=refs;refs[#refs+1]={id=id,at=at}
     for _,npc in ipairs(item.reportedSourceNPCIDs or {}) do local rows=unitLoot[npc] or {};unitLoot[npc]=rows;rows[#rows+1]={id=item.publishedItemID} end
    end
   end
  end
  for item,refs in pairs(itemRefs) do local first=refs[1];local r=L.byID[first.id].referenceLoot[first.at];emit(item,{key=W.Key('ITEM',item),kind='ITEM',nativeID=item,title=r.name}) end
 end,
 Resolve=function(id,ctx)
  local out={priority=5,fields={itemID=id},quickFacts={},related={},sources={}}
  out.summary='An item reference already retained with this instance. The cited source does not establish current obtainability or that your character received it.'
  for _,ref in ipairs(itemRefs[id] or {}) do local e=L.byID[ref.id];if safeEntry(e,ctx) then local item=e.referenceLoot[ref.at]
   out.sources[#out.sources+1]=item.sourceURL
   add(out,'Source instance',e.title,item.sourceURL,'Retained loot reference · current drop unverified',loreKey(e))
   for _,npc in ipairs(item.reportedSourceNPCIDs or {}) do
    local name=ns.AthenaQuestData.npcs[npc];local lid=L.byNPC[npc];name=name or lid and L.byID[lid].title
    if name then add(out,'Reported source',name,item.sourceURL,'Retained source reference',W.Key('NPC',npc)) end
   end
  end end
  return out
 end,
})
