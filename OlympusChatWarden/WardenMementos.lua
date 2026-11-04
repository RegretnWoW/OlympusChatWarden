-- Owner-private derived presentation. Accepted history remains authoritative.
-- No new collector, public achievement claim, or copies of canonical events.
local _,ns=...
local M={VERSION=2,MAX_BADGES=512,MAX_REFS=512};ns.WardenMementos=M
local function plain(v)return type(v)=='table'and getmetatable(v)==nil end
local function size(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
local function id(v)return type(v)=='number'and v>0 and v<100000000 and v%1==0 end
local function ownerState(owner,create)
 if not ns.DB or not owner or owner~=ns.Chronicle.Owner()then return end
 local root=ns.DB.journalArtifacts
 if not root and create then root={version=1,owners={}};ns.DB.journalArtifacts=root end
 if not plain(root)or root.version~=1 or not plain(root.owners)then return end
 local s=root.owners[owner];if not s and create then s={badges={},design={version=1,layers={}},revision=0};root.owners[owner]=s end
 if not plain(s)or not plain(s.badges)or not ns.WardenComposition.Validate(s.design)or type(s.revision)~='number'then return end
 return s
end
-- Sanctuary cosmetics extend this same private owner record, never a second
-- collection ledger or a public accomplishment source.
M.OwnerState=ownerState
local entryKinds={session_start=true,location=true,world_entry=true,zone_change=true,location_change=true,instance_entered=true,instance_enter=true,instance_visit=true,instance_entry=true}
local sources={encounter_started='ENCOUNTER_START',encounter_ended='ENCOUNTER_END',boss_kill_event='BOSS_KILL',pvp_match_complete='PVP_MATCH_COMPLETE',instance_completed='LFG_COMPLETION_REWARD'}
local function put(t,key,limit)
 if not key or t[key]or size(t)>=limit then return false end;t[key]=true;return true
end
-- Participation embellishes an artifact; it never certifies a whole-instance
-- clear. Forty distinct regional quests or thirty separately observed calendar
-- days permit a long-term commemoration mount, never a zone-completion claim.
function M.KeepsakeCriterion(b,variant)
 local days=plain(b.observedDays)and size(b.observedDays)or 0
 local q,v,e,n,r=b.questsCount or 0,b.victories or 0,b.encounterCount or 0,b.matchCount or 0,math.max(b.completionCount or 0,b.finishingCount or 0)
 if b.family=='zone'then
  if variant==1 then return q>=3 or days>=5,'3 distinct regional quest turn-ins or 5 observed UTC days' end
  return q>=10 or days>=15,'10 distinct regional quest turn-ins or 15 observed UTC days'
 elseif b.family=='battleground'then return n>=(variant==1 and 1 or 10),variant==1 and'1 scoped battleground result'or'10 distinct scoped battleground results'
 elseif variant==1 then return e>=2 or v>=1 or days>=5,'2 distinct encounter IDs, 1 boss victory, or 5 observed UTC days'
 else return r>=1 or v>=3 or days>=15,'1 supported finishing result, 3 distinct boss victories, or 15 observed UTC days; not a full clear' end
end
function M.Memories(b)
 local out={};local B=ns.WardenComposition
 for _,m in ipairs(B.memories or{})do
  local ref,source,criterion
  if m.questStory then
  local p=plain(b.questStoryProof)and b.questStoryProof
  if p and m.activity==b.art then for _,q in ipairs(m.quests)do if q==p.questID then ref='quest:'..q;source=m.source end end end
 elseif m.activity and m.activity==b.art then local unlocked,why=M.KeepsakeCriterion(b,m.criterion);if unlocked then ref='activity:'..b.art..'/'..m.criterion;source=m.source;criterion=why end
  elseif m.quest and plain(b.quests)and b.quests[m.quest]and(m.quest~=166 or not b.art or b.art=='activity-the-deadmines'or plain(b.memoryProofs)and b.memoryProofs[m.key])then ref='quest:'..m.quest;source=ns.AthenaQuestData and ns.AthenaQuestData.sourceURL
  elseif m.map==b.identity and plain(b.bosses)then
   for _,endpoint in ipairs(ns.ChronicleRunEndpoints or{})do if endpoint.mapID==m.map and endpoint.name==m.boss then
    for _,encounter in ipairs(endpoint.encounterIDs)do if b.bosses[encounter]then ref='encounter:'..encounter;source=endpoint.sourceURL end end
   end end
  end
  local definition=m.questStory and b.questStoryProof and ns.WardenComposition.memoryByKey[b.questStoryProof.key]or m
  local memoryKey=definition and definition.key or m.key
  local proof=m.questStory and b.questStoryProof or plain(b.memoryProofs)and b.memoryProofs[m.key];if not plain(proof)then proof=nil end
  if ref then out[#out+1]={key=memoryKey,title=definition and definition.title or m.title,ref=ref,source=source,criterion=criterion,firstObserved=proof and proof.at or nil,eventRef=proof and proof.eventRef or nil,precision=proof and proof.precision or nil,scope=m.claim or'Commemorative symbol; not ownership of a depicted item'}end
 end
 return out
end
function M.Progress(b)
 if b.observedDays~=nil and not plain(b.observedDays)then return end
 local q,v,e,n,r,f=b.questsCount or 0,b.victories or 0,b.encounterCount or 0,b.matchCount or 0,b.completionCount or 0,b.finishingCount or 0
 for _,value in ipairs({q,v,e,n,r,f,b.capstoneCount or 0})do if type(value)~='number'or value~=value or value<0 or value>4096 or value%1~=0 then return end end
 r=math.max(r,f)
 local stage=1
 if b.family=='zone'then stage=(q>=40 or size(b.observedDays)>=30)and 6 or q>=20 and 5 or q>=8 and 4 or q>=3 and 3 or q>=1 and 2 or 1
 elseif b.family=='battleground'then stage=n>=50 and 6 or n>=25 and 5 or n>=10 and 4 or n>=3 and 3 or n>=1 and 2 or 1
 else stage=r>=3 and 6 or r>=2 and 5 or r>=1 and 4 or v>=5 and 5 or v>=3 and 4 or e>=2 and 3 or e>=1 and 2 or 1 end
 local charms={};local named=M.Memories(b)
 -- Keep each badge's two personal regional artifacts visible before generic
 -- participation symbols. All earned alternatives remain valid in saved art.
 for _,m in ipairs(named)do local definition=ns.WardenComposition.memoryByKey[m.key];if definition and definition.activity==b.art and #charms<4 then charms[#charms+1]=m.key end end
 for _,m in ipairs(named)do local definition=ns.WardenComposition.memoryByKey[m.key];if definition and not definition.activity and #charms<4 then charms[#charms+1]=m.key end end
 for _,pair in ipairs({{'seal',(b.capstoneCount or 0)>0},{'fang',v>=2},{'ribbon',r>=1},{'banner',n>=10}})do if pair[2]and #charms<4 then charms[#charms+1]=pair[1]end end
 return stage,charms
end
function M.RefreshBadge(owner,s,b,e,changed)
 if not changed then return end
 local d=e.details or{};local key=b.key
 b.questsCount=size(b.quests);b.victories=size(b.bosses);b.encounterCount=size(b.encounters);b.matchCount=size(b.matches);b.completionCount=size(b.completions);b.finishingCount=size(b.finishes);b.capstoneCount=size(b.capstones)
 local previous=b.stage;local previousCharms={};for _,name in ipairs(b.charms or{})do previousCharms[name]=true end;b.stage,b.charms=M.Progress(b)
 if not b.memoryProofs then b.memoryProofs={}end
 if plain(b.memoryProofs)then for _,memory in ipairs(M.Memories(b))do
  local exact=memory.ref=='quest:'..tostring(d.questID)or memory.ref=='encounter:'..tostring(d.encounterID)or memory.criterion and not M.replaying
  if exact and not b.memoryProofs[memory.key]then
   local at=e.at;if memory.precision=='unknown original completion date'then at=nil end
   b.memoryProofs[memory.key]={eventRef=e.id,at=at,precision=memory.precision}
  end
 end end
 local newMemento=false;for _,name in ipairs(b.charms or{})do if not previousCharms[name]then newMemento=true end end
 if previous and(b.stage>previous or newMemento)and not M.replaying then
  if M.changedOwner~=owner then M.changedOwner=owner;M.changes={}end
  M.changes=M.changes or{};M.changes[key]={from=previous,to=b.stage>previous and b.stage or'memento'}
 end
 s.revision=s.revision+1
 if ns.WardenSanctuary then ns.WardenSanctuary.BadgeChanged(owner,s,b,e,previous,previousCharms,M.replaying)end
end
function M.Observe(e,status)
 if status~='COMMITTED'or not plain(e)or e.character~=ns.Chronicle.Owner()or type(e.id)~='string'then return end
 if ns.WardenSanctuary then ns.WardenSanctuary.Observe(e,M.replaying)end
 local owner=e.character;local d=e.details or{};local loc=e.location or{};local ctx=e.sourceContext or{}
 if not plain(d)or not plain(loc)or not plain(ctx)then return end
 local kind=d.recordType or e.kind;local entry=entryKinds[e.kind]
 if not entry and e.kind~='quest_turnin'and not sources[kind]then return end
 if sources[kind]and e.source~=sources[kind]then return end
 local _,own=ns.Chronicle.Owner();if e.subject and e.subject~=own then return end
 local pending=ownerState(owner,true);if pending and ns.WardenQuestMementos then ns.WardenQuestMementos.Record(e,pending)end
 local family=({party='dungeon',raid='raid',pvp='battleground'})[loc.instanceType or ctx.instanceType]or'zone'
 local identity=family=='zone'and(ctx.mapID or loc.uiMapID)or(loc.instanceID or ctx.instanceID)
 local title=family=='zone'and loc.zone or loc.instanceName or loc.zone
 local art=ns.WardenActivityArt.Lookup(family,id(identity)and identity or nil,title)
 if not art then return end
 local s=ownerState(owner,true);if not s then return end
 local key=art.id;local b=s.badges[key];local changed=false
 if not b then
  if not entry or size(s.badges)>=M.MAX_BADGES then return end
  b={key=key,family=family,identity=identity,title=art.title,firstObserved=e.at,precision=e.temporal and e.temporal.occurrencePrecision or'observed',quests={},bosses={},encounters={},matches={},completions={},finishes={},capstones={},art=key}
  s.badges[key]=b;if ns.WardenQuestMementos then ns.WardenQuestMementos.Attach(s,b)end;changed=true
 end
 for _,field in ipairs({'quests','bosses','encounters','matches','completions','capstones'})do if not plain(b[field])then return end end
 if b.finishes==nil then b.finishes={}end;if not plain(b.finishes)then return end
 if b.observedDays==nil then b.observedDays={}end;if not plain(b.observedDays)then return end
 if entry and type(e.at)=='number'and e.at>0 and e.at<100000000000 then changed=put(b.observedDays,math.floor(e.at/86400),366)or changed end
 if e.kind=='quest_turnin'and id(d.questID)then
  changed=put(b.quests,d.questID,4096)or changed
  local chains=ns.AthenaQuestChains
  if chains and #chains.Previous(d.questID)>0 and #chains.Following(d.questID)==0 then changed=put(b.capstones,d.questID,128)or changed end
 elseif (kind=='encounter_started'or kind=='encounter_ended'or kind=='boss_kill_event')and id(d.encounterID)then
  changed=put(b.encounters,d.encounterID,M.MAX_REFS)or changed
  if kind=='boss_kill_event'or kind=='encounter_ended'and d.success==1 then
   changed=put(b.bosses,d.encounterID,M.MAX_REFS)or changed
   for _,endpoint in ipairs(ns.ChronicleRunEndpoints or{})do if endpoint.mapID==identity then
    for _,encounter in ipairs(endpoint.encounterIDs)do if encounter==d.encounterID then
     -- A supported finishing encounter/wing result is a strong story moment,
     -- never proof that all bosses or optional encounters were completed.
     changed=put(b.finishes,tostring(e.session)..'/'..tostring(ctx.instanceRef or'one-unscoped-visit')..'/'..encounter,M.MAX_REFS)or changed
    end end
   end end
  end
 elseif kind=='pvp_match_complete'and family=='battleground'then
  -- Native completion is a result, not proof the owner won. No guessed faction.
  local match=ctx.matchRef or d.matchRef
  if type(match)=='string'then changed=put(b.matches,tostring(e.session)..'/'..match,M.MAX_REFS)or changed end
 elseif kind=='instance_completed'and family=='dungeon'then
  -- Native completion reward closes a run; it does not prove all bosses died.
  local ref=ctx.instanceRef or'one-unscoped-completion'
  changed=put(b.completions,tostring(e.session)..'/'..ref,M.MAX_REFS)or changed
 end
 if not changed then return end
 M.RefreshBadge(owner,s,b,e,changed)
end

local scanning
function M.Request(owner)
 if owner~=ns.Chronicle.Owner()or scanning or not ns.WardenScheduler or not ns.Permissions.Decide('UIAccess')then return end
 local store=ns.ChronicleStore;if not store or store.loading or store.blocked then return end
 local c=store.Character(owner,false);if not c or not plain(c.events)then return end
 local saved=ownerState(owner,false);local index=saved and saved.presentationVersion==4 and saved.scanIndex or 0
 if ns.WardenSanctuary then ns.WardenSanctuary.Reconcile(owner)end
 if type(index)~='number'or index%1~=0 or index<0 or index>#c.events or index>0 and c.events[index].id~=saved.scanRef then index=0 end
 if index==#c.events then return end
 scanning=owner
 local accepted=ns.WardenScheduler.Submit('journal3-mementos','low',function(deadline)
  if owner~=ns.Chronicle.Owner()or not ns.Permissions.Decide('UIAccess')or store.Character(owner,false)~=c then scanning=nil;return true end
  local stop=math.min(#c.events,index+64)
  while index<stop do
   index=index+1;M.replaying=true;M.Observe(c.events[index],'COMMITTED');M.replaying=nil
   if ns.WardenPerformance.Expired(deadline)then break end
  end
  local s=ownerState(owner,false);if s then s.presentationVersion=4;s.scanIndex=index;s.scanRef=c.events[index]and c.events[index].id end
  if index>=#c.events then scanning=nil;M.revision=(M.revision or 0)+1;return true end
 end,{module='chronicle',onCancel=function()scanning=nil end})
 if not accepted then scanning=nil end
end
function M.TakeEvolution(owner,key)if owner~=M.changedOwner then return end;local value=M.changes and M.changes[key];if value then M.changes[key]=nil;return value end end
function M.ResetRuntime()M.changes=nil;M.changedOwner=nil;M.replaying=nil;if ns.WardenScheduler then ns.WardenScheduler.Cancel('journal3-mementos')end;scanning=nil;if ns.WardenSanctuary then ns.WardenSanctuary.ResetRuntime()end end
function M.Inventory(owner)
 if owner==ns.Chronicle.Owner()and ns.ClientCompat and ns.ClientCompat.IsRetailTest()then
  local out={};local B=ns.WardenComposition;local charms={};for key in pairs(B.charms)do charms[#charms+1]=key end;table.sort(charms)
  for key,art in pairs(B.catalog)do
   local shown={};for _,m in ipairs(B.memories)do if m.activity==key and #shown<4 then shown[#shown+1]=m.key end end
   for _,name in ipairs({'seal','book','laurel','ribbon'})do if #shown<4 then shown[#shown+1]=name end end
   out[#out+1]={key='retail-preview:'..key,art=key,title=art.title or key,family=art.family,stage=#B.stages,charms=shown,unlockedCharms=charms,memories={},testOnly=true,observedDays=0}
  end
  table.sort(out,function(a,b)return a.art<b.art end);return out
 end
 M.Request(owner)
 local s=ownerState(owner,false);local out={};if not s then return out end
 for _,b in pairs(s.badges)do
  if plain(b)and ns.WardenComposition.catalog[b.art]then
   local stage,charms=M.Progress(b)
   if stage then local copy={stage=stage,charms=charms,memories=M.Memories(b),commemoration=b.family=='zone'and stage==6 and'Long-term regional commemoration · not a full-zone clear'or nil,observedDays=size(b.observedDays)};for _,field in ipairs({'key','family','identity','title','firstObserved','precision','art','questsCount','victories','encounterCount','matchCount','completionCount','finishingCount','capstoneCount'})do copy[field]=b[field]end;out[#out+1]=copy end
  end
 end
 table.sort(out,function(a,b)return a.key<b.key end);return out
end
function M.Design(owner)
 local s=ownerState(owner,false);local testing=ns.ClientCompat and ns.ClientCompat.IsRetailTest()
 local design=s and ns.WardenComposition.Copy(testing and s.retailTestDesign or s.design)or{version=1,catalog=3,layers={}};design=design or{version=1,catalog=3,layers={}};design.catalog=3
 M.Request(owner)
 for _,l in ipairs(design.layers)do local b=not testing and s and s.badges[l.art];if plain(b)then local stage,charms=M.Progress(b);if stage then l.stage=stage;l.charms=charms end end end
 return design
end
function M.SaveDesign(owner,design)
 if not ns.Permissions.Decide('UIAccess')or owner~=ns.Chronicle.Owner()then return false,'OWNER_REQUIRED'end
 local value=ns.WardenComposition.Copy(design);if not value then return false,'INVALID_OR_OVER_BUDGET_DESIGN'end
 local inventory={};for _,b in ipairs(M.Inventory(owner))do inventory[b.art]=b end
 for _,l in ipairs(value.layers)do
  local earned=inventory[l.art];if not earned then return false,'EARNED_ART_REQUIRED'end
  if(l.stage or(l.growth and l.growth+1)or 1)>earned.stage then return false,'EARNED_STAGE_REQUIRED'end
  local charms={};for _,name in ipairs(earned.unlockedCharms or earned.charms)do charms[name]=true end
  for _,memory in ipairs(earned.memories or{})do charms[memory.key]=true end
  if(earned.capstoneCount or 0)>0 then charms.seal=true end
  if(earned.victories or 0)>=2 then charms.fang=true end
  if math.max(earned.completionCount or 0,earned.finishingCount or 0)>=1 then charms.ribbon=true end
  if(earned.matchCount or 0)>=10 then charms.banner=true end
  for _,name in ipairs(l.charms or{})do if not charms[name]then return false,'EARNED_MEMENTO_REQUIRED'end end
 end
 local s=ownerState(owner,true);if not s then return false,'ORIGINAL_DESIGN_PRESERVED_NEEDS_RECOVERY'end
 if ns.ClientCompat and ns.ClientCompat.IsRetailTest()then s.retailTestDesign=value else s.design=value end
 s.revision=s.revision+1;return true
end
function M.Snapshot(owner)
 if owner~=ns.Chronicle.Owner()or not ns.Permissions.Decide('UIAccess')then return end
 return {version=1,catalog=3,base='cover',layers=M.Design(owner).layers}
end
