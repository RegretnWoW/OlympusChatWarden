-- Book ornaments are presentation. They never add narrative claims or acquire
-- appearance data. Only an already important, GUID-bound person earns a card.
local _,ns=...
local I={};ns.AthenaBookIllustrations=I
function I.Card(index,guid,at)
 if not index or not guid then return end
 if not index.provider.demo then
  local st=ns.ChronicleActivities.Peek(index.owner)
  local card=ns.WardenCharacterCards.FromState(st,guid,at);if card then return card end
 end
 local best
 for _,f in ipairs(index.facts or {}) do
  if f.subjectGUID==guid and f.family=='player_observed' and f.observedAt<=at and f.details.name
   and (not best or f.observedAt>best.at) then
   best={owner=index.owner,guid=guid,at=f.observedAt,sourceRef=f.evidenceRef,values={name=f.details.name,
    class=f.details.class,race=f.details.race,level=f.details.level,guild=f.details.guild,exact=false,portraitKind='class-emblem'}}
  end
 end
 return best
end
function I.Decorate(plan,blocks)
 local claims={};for _,s in ipairs(plan and plan.episodes or {}) do for _,c in ipairs(s.factualClaims) do claims[c.claimId]=c end end
 local seen={};for _,b in ipairs(blocks) do
  for _,id in ipairs(b.claimIds or {}) do local c=claims[id]
   local guid=c and (c.claimType=='verified_friend_status' and c.value.after or c.claimType=='recurring_companion') and c.value.guid
   if guid and not seen[guid] then
    local card=I.Card(plan.index,guid,b.at or plan.firstAt or 0)
    if card then b.characterCard=card;seen[guid]=true;break end
   elseif c and c.claimType=='own_guild_affiliation' and c.value.after and not seen['guild:'..tostring(c.value.name)] then
    b.guildSeal=c.value.name;b.guildOwner=plan.owner or plan.index and plan.index.owner
    local key=ns.AthenaHistoryGraph.GuildKey(b.guildOwner,c.value.name,c.value.realm)
    if key and ns.AthenaHistoryGraph.ResolveGuild(key,b.guildOwner) then b.guildRef=key end
    seen['guild:'..tostring(c.value.name)]=true
   end
  end
 end
 for _,b in ipairs(blocks) do
  b.spans=b.spans or {}
  local function span(label,ref,source)
   if type(label)~='string' or not ref or not ns.AthenaHistoryGraph.Destination(ref) then return end
   local first,last=(b.text or ''):find(label,1,true);if first then b.spans[#b.spans+1]={first=first,last=last,ref=ref,source=source} end
  end
  if b.characterCard then local card=b.characterCard;span(card.values.name,{type='PLAYER',key=card.guid,owner=plan.owner or plan.index.owner},card.sourceRef) end
  if b.guildRef then span(b.guildSeal,{type='GUILD',key=b.guildRef,owner=plan.owner or plan.index.owner},(b.evidenceRefs or {})[1]) end
 end
 return blocks
end
function I.ReadingBlocks(reader,blocks,paragraphs)
 -- The Observed Record renderer also emits plain paragraphs without a stable
 -- literary block ID. They remain readable, but cannot carry an illustration
 -- or evidence-click target matched by that absent identifier.
 local by={};for _,b in ipairs(paragraphs or {}) do if b.blockId~=nil then by[b.blockId]=b end end
 for _,b in ipairs(blocks) do local source=by[b.paragraphId or b.id]
  if source then
   b.characterCard=source.characterCard;b.guildSeal=source.guildSeal;b.guildRef=source.guildRef;b.guildOwner=source.guildOwner;b.spans=source.spans
   if source.recollectionText then b.margin={text=source.recollectionText,at=source.at,ownerPrivate=true,source=(source.evidenceRefs or {})[1]};b.tone='meta' end
   if not b.activate and source.evidenceRefs and #source.evidenceRefs>0 then
    b.revealAllowed=true
    b.activate=function()
     if not reader:OpenRecollections(false) then return end
     for _,ref in ipairs(source.evidenceRefs) do if reader.recollectionTargets[ref] then reader:SelectRecollection(ref);reader.recollectionEditor.select:Refresh();break end end
    end
    b.tooltipTitle='A passage in your story';b.tooltip='Click to add your recollection of this passage.'
   end
  end
 end
 local compact={}
 for _,block in ipairs(blocks) do
  if block.margin and block.recollection and #compact>0 then compact[#compact].margin=block.margin
  else compact[#compact+1]=block end
 end
 for i=#blocks,1,-1 do blocks[i]=nil end;for i,b in ipairs(compact) do blocks[i]=b end
 return blocks
end
