-- Only explicit story/source identities become manuscript links. No arbitrary
-- name scan or new article catalogue. The existing Wiki remains the opener.
local _,ns=...
local L={};ns.AthenaJournalLinks=L
local W=ns.AthenaLivingWiki
local destination=ns.AthenaHistoryGraph.Destination
function ns.AthenaHistoryGraph.Destination(ref)
 if type(ref)=='table' and ref.type=='WIKI' and W.ValidKey(ref.key) then return {page='wiki',key=ref.key,owner=ns.Chronicle.Owner(),wikiKind='ALL'} end
 return destination(ref)
end
local kinds={NPC='NPC',CREATURE='CREATURE',QUEST='QUEST',BOSS='BOSS',INSTANCE='INSTANCE',ZONE='ZONE',PLACE='PLACE',FACTION='FACTION',ITEM='ITEM',LORE='LORE',EVENT='EVENT'}
local function add(out,label,key)
 if type(label)=='string' and #label>0 and #label<=256 and W.ValidKey(key) then local canonical=W.Canonical(key);if W.index.status=='READY' and not W.index.byKey[canonical] then return end;out[#out+1]={label=label,key=canonical} end
end
local function reference(out,ref)
 if type(ref)~='table' then return end
 local key=ref.wikiKey or W.ValidKey(ref.key) and ref.key or kinds[ref.type] and W.Key(ref.type,ref.id or ref.key)
 add(out,ref.label or ref.title or ref.name,key)
end
function L.Candidates(reader,source)
 local out={};source=source or {}
 reference(out,source.subjectRef);for _,ref in ipairs(source.subjectRefs or {}) do reference(out,ref) end
 for _,ref in ipairs(source.wikiRefs or {}) do reference(out,ref) end
 local index=reader.library and reader.library.index
 local ctx=reader.LoreContext and reader:LoreContext()
 local function fact(e)
  if not e or e.storyPrivateProjection or e.accessScope=='PRIVATE_INCIDENT' then return end
  local d=e.details or {}
  if d.questID then
   local q=ctx and ns.Athena.Knowledge.GetQuest(d.questID,ctx)
   add(out,d.title or q and q.title,W.Key('QUEST',d.questID))
   for _,npc in ipairs(q and q.characters or {}) do add(out,npc.name,W.Key('NPC',npc.npcID)) end
  end
  if d.npcID then add(out,d.npcName,W.Key('NPC',d.npcID)) end
  if d.creatureID then
   local key=W.Key('NPC',d.creatureID);if not ns.AthenaQuestData.npcs[d.creatureID] then key=W.Key('CREATURE',d.creatureID) end
   add(out,d.creatureName,key)
  end
  if d.itemID then add(out,d.itemName,W.Key('ITEM',d.itemID)) end
  if d.encounterID then add(out,d.name,W.Key('BOSS','encounter-'..d.encounterID)) end
  local loc=e.location or {}
  for _,name in ipairs({loc.instanceName or '',loc.zone or '',loc.subzone or ''}) do
   local id=ns.AthenaLoreCodex.byTitle[name]
   if id then add(out,name,W.Key('LORE',id)) end
  end
  reference(out,d.subjectRef)
 end
 local seen={};for i,ref in ipairs(source.evidenceRefs or source.sourceEvidenceRefs or {}) do
  if i>256 then break end
  if not seen[ref] then seen[ref]=true;local f=index and index.byRef[ref]
   if f then fact(f) elseif reader.provider and reader.provider:Allowed() then local e=reader.provider:Resolve(ref);if e and e.observer==reader.owner then fact(e) end end
  end
 end
 for _,world in ipairs(source.worldFacts or {}) do
  if world.questID or world.id and world.kind=='quest' then add(out,world.title,W.Key('QUEST',world.questID or world.id)) end
  reference(out,world.subjectRef)
 end
 return out
end
function L.Decorate(reader,block,source)
 if type(block.text)~='string' or block.text:find('|',1,true) then return block end
 local choices={};for _,ref in ipairs(L.Candidates(reader,source or block)) do
  if choices[ref.label] and choices[ref.label]~=ref.key then choices[ref.label]=false elseif choices[ref.label]==nil then choices[ref.label]=ref.key end
 end
 local spans={};for _,span in ipairs(block.spans or {}) do spans[#spans+1]=span end
 for label,key in pairs(choices) do if key and #spans<24 then
  local start=1
  while #spans<24 do
   local first,last=block.text:find(label,start,true);if not first then break end
   local before=first>1 and block.text:sub(first-1,first-1) or '';local after=block.text:sub(last+1,last+1)
   if not before:match('%w') and not after:match('%w') then
    local overlaps=false;for _,s in ipairs(spans) do if s.first<=last and s.last>=first then overlaps=true end end
    if not overlaps then spans[#spans+1]={first=first,last=last,ref={type='WIKI',key=key}} end
   end
   start=last+1
  end
 end end
 if #spans>0 then block.spans=spans end
 return block
end
local decorate=ns.AthenaBookIllustrations.ReadingBlocks
function ns.AthenaBookIllustrations.ReadingBlocks(reader,blocks,paragraphs)
 local result=decorate(reader,blocks,paragraphs);local by={}
 for _,p in ipairs(paragraphs or {}) do if p.blockId then by[p.blockId]=p end end
 for _,block in ipairs(blocks) do local source=by[block.paragraphId or block.id];L.Decorate(reader,block,source);ns.AthenaBookArt.Decorate(reader,block,source or block)end
 return result
end
L.Reference=reference
L.Add=add
-- UI summaries use these same typed destinations. Only an exact, unambiguous
-- reference label from a known model may supply a name fallback; never scan
-- chat, owner notes or arbitrary free text for things that resemble names.
local subjects,subjectOrder={},{}
function L.Subject(kind,id,label)
 local typed=id and W.Key(kind,kind=='BOSS' and ('encounter-'..id) or id)
 if typed and W.index and W.index.status=='READY' and W.index.byKey[W.Canonical(typed)] then return W.Canonical(typed) end
 if kind=='QUEST' and id and ns.AthenaQuestData.quests[id] then return W.Key('QUEST',id) end
 if (kind=='NPC' or kind=='CREATURE') and id and (ns.AthenaQuestData.npcs[id] or ns.AthenaLoreCodex.byNPC[id]) then return W.Key('NPC',id) end
 if type(label)~='string' or label=='' or #label>256 then return end
 local key=kind..'/'..label;local cached=subjects[key]
 if cached~=nil then return cached or nil end
 local expected=({BOSS='figure',NPC='figure',CREATURE='creature',INSTANCE='instance',ZONE='place',PLACE='place',FACTION='faction',ITEM='artifact'})[kind]
 local found
 for _,loreID in ipairs(ns.AthenaLoreCodex.order) do
  local entry=ns.AthenaLoreCodex.byID[loreID]
  if entry.kind==expected or kind=='BOSS' and entry.kind=='creature' then
   local matches=entry.title==label
   if not matches then for _,alias in ipairs(entry.aliases or {}) do if alias==label then matches=true;break end end end
   if matches then
    local canonical=entry.canonicalSubjectID and ns.AthenaLoreCodex.byID[entry.canonicalSubjectID] or entry
    local ref=canonical.npcIDs and canonical.npcIDs[1] and W.Key('NPC',canonical.npcIDs[1]) or W.Key('LORE',canonical.id)
    if found and found~=ref then found=false;break end;found=ref
   end
  end
 end
 if #subjectOrder>=128 then subjects[table.remove(subjectOrder,1)]=nil end
 subjectOrder[#subjectOrder+1]=key;subjects[key]=found or false;return found or nil
end
function L.Row(row,key)
 if not row or not W.ValidKey(key) then return row end
 row.wikiKey=key
 if not row.activate then
  row.activate=function() W.Open(key) end;row.wikiPrimary=true
 end
 return row
end
local activity=ns.UI2Layouts.Activity
function ns.UI2Layouts.Activity(model,...)
 local blocks=activity(model,...);local context=model._activity and model._activity.context
 if context then for _,block in ipairs(blocks) do if block.id=='identity' then
  L.Row(block.rows[1],L.Subject(context.instanceName and 'INSTANCE' or 'ZONE',context.instanceID,context.instanceName or context.zone))
 end end end
 return blocks
end
