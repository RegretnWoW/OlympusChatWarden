-- Runtime-only book decoration. No artwork enters saved manuscripts or evidence.
local _,ns=...
local J={VERSION=1};ns.AthenaBookArt=J
local C=ns.WardenArtCatalog
local function fact(reader,source,fn)
 local index=reader.library and reader.library.index
 for i,ref in ipairs(source and (source.evidenceRefs or source.sourceEvidenceRefs)or {})do
  if i>64 then break end
  local e=index and index.owner==reader.owner and index.byRef and index.byRef[ref]
  local fromIndex=e~=nil
  if not e and reader.provider and reader.provider:Allowed()then e=reader.provider:Resolve(ref)end
  if e and (fromIndex or e.observer==reader.owner)and reader.provider and reader.provider:Allowed()and not e.storyPrivateProjection and e.accessScope~='PRIVATE_INCIDENT'then fn(e)end
 end
end
function J.Decorate(reader,block,source)
 block.journalArt=nil
 if type(block.text)~='string'or block.doodle or block.characterCard or block.guildSeal then return end
 local purpose
 if block.kind=='title'then purpose='journal.chapter.banner'
 elseif block.kind=='heading'then purpose='journal.chapter.divider'end
 local icon,map
 -- Semantic claims use source IDs, never a text/name match or reference lore.
 fact(reader,source,function(e)
  local d=e.details or {};local loc=e.location or {}
  if e.family=='quest_accepted'or e.family=='quest_turnin'then purpose='journal.quest.header'end
  if d.itemID and (e.family=='item_received'or e.family=='quest_item_received'or e.family=='encounter_loot_delivery')then icon=C.Dynamic('item',{id=d.itemID,recorded=true})end
  if d.spellID and e.family=='spell_learned'then icon=C.Dynamic('spell',{id=d.spellID,recorded=true})end
  if e.family=='encounter_ended'and(d.success==true or d.success==1)then purpose='journal.dungeon.victory'end
  if e.family=='level_change'then purpose='journal.milestone'end
  if e.family=='pvp_match_complete'or e.family=='duel_session_result'then purpose='journal.pvp'end
  -- AthenaHistoryGraph projects the existing sourceContext.mapID (the UI map
  -- captured by GetBestMapForUnit) onto the fact. Do not use instance map IDs.
  if e.family=='exploration_discovery'and e.mapID then map=C.Map({id=e.mapID,recorded=true})end
 end)
 if (block.id=='prologue'or block.paragraphId=='prologue')and reader.library and reader.library.index then
  local owner=reader.library.index.ownerIdentity
  if type(owner)=='table'then
   if owner.faction=='Alliance'then purpose='journal.prologue.alliance'elseif owner.faction=='Horde'then purpose='journal.prologue.horde'end
   icon=C.Class({id=owner.classID,recorded=true})
  end
 end
 if map then block.journalArt={map=map,height=108,purpose='journal.exploration.map'}
 elseif icon then block.journalArt={art=icon,seal=purpose and C.Select(purpose),height=40,purpose='journal.recorded.icon'}
 elseif purpose then block.journalArt={art=C.Select(purpose),height=purpose=='journal.chapter.banner'and 24 or 14,purpose=purpose}end
end
function J.Height(block)return block.journalArt and block.journalArt.height or 0 end
function J.Key(spec)
 if not spec then return ''end
 local a=spec.art;local m=spec.map
 return tostring(spec.purpose)..'/'..tostring(spec.height)..'/'..tostring(a and a.path)..'/'..tostring(m and m.mapID)..'/'..tostring(a and a.fallback)
end
function J.Emit(surface,face,block,x,y,width)
 local spec=block.journalArt;if not spec then return end
 local h=spec.height
 if spec.map then
  local m=spec.map;local scale=math.min(width/m.width,(h-8)/m.height);local left=x+(width-m.width*scale)*.5
  for _,t in ipairs(m.tiles)do surface:AddArtwork(face,left+t.x*scale,y+t.y*scale,t.width*scale,t.height*scale,t)end
 else
  local a=spec.art;local w=math.min(width*.85,h*(a.width/a.height));local ah=math.min(h,w*a.height/a.width)
  surface:AddArtwork(face,x+(width-w)*.5,y,w,ah,a)
  if spec.seal and not spec.seal.fallback then local seal=spec.seal;surface:AddArtwork(face,x+(width-w)*.5-34,y+4,28,28,seal)end
 end
end
