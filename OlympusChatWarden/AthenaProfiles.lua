-- Compatibility lens over the existing Chronicle activity index; no copied ledger.
local _,ns=...
local R,A,S=ns.Athena2,ns.ChronicleActivities,ns.ChronicleStore
local I={VERSION=1,cache=R.Cache(64),queries=0,wholeHistoryScans=0};ns.AthenaActivityIndex=I;ns.AthenaProfiles=I
local function Own(owner) return owner and owner:match('/(Player%-.+)$') end
-- Primary adventures are distinct from supporting party-roster contexts.
-- Consumers use this shared semantic rule rather than counting every segment.
function I.IsAdventure(a) return a and ({dungeon=true,raid=true,battleground=true,arena=true,duel=true,boss=true})[a.kind]==true end
function I.Request(owner) if not R.Permit('intel') and not R.Permit('chronicle') then return nil,'DENIED' end;return A.Request(owner or R.Owner()) end
local function meta(st) if not st.athena2 then st.athena2={people={},sourceCount=0} end;return st.athena2 end
function I.Feed(st,e)
 if e.details and e.details.origin=='synthetic' then st.syntheticEvidence=true end
 local m=meta(st);m.sourceCount=m.sourceCount+1
 local touched={};local function touch(guid)
  if not R.GUID(guid) or touched[guid] then return end;touched[guid]=true
  local p=m.people[guid];if not p then p={revision=0,identity={},freshness={}};m.people[guid]=p end
  p.revision=p.revision+1
  if e.kind=='player_observed' and e.subject==guid or e.kind=='character_snapshot' and Own(st.owner)==guid then
   for _,k in ipairs({'name','realm','class','race','faction','guild','level'}) do local v=e.details[k]
    if (k=='level' and R.Number(v,1,1000) or k~='level' and R.Text(v)) and e.at>=(p.freshness[k] or 0) then p.identity[k]=v;p.freshness[k]=e.at end
   end
  end
 end
 touch(e.subject);touch(Own(st.owner))
 -- Small read index for the observer's own progression. Other people's quest
 -- progress is never attributed from a shared roster or nearby observation.
 local own=Own(st.owner);local me=m.people[own];local d=e.details or {}
 if me and (not e.subject or e.subject==own) and (e.kind=='quest_turnin' or e.kind=='level_change' or e.kind=='achievement_earned' and d.alreadyEarned~=true) then
  me.progression=me.progression or {turnins=0,levels=0,achievements=0,recent={}}
  local q=me.progression;local key=({quest_turnin='turnins',level_change='levels',achievement_earned='achievements'})[e.kind]
  q[key]=q[key]+1
  q.recent[#q.recent+1]={kind=e.kind,at=e.at,questID=d.questID,title=d.title,level=d.after or d.afterLevel,achievementID=d.achievementID,sourceID=e.id}
  if #q.recent>20 then table.remove(q.recent,1) end
 end
 local v=e.capture and e.capture.values;if v then touch(v.guid) end
 if d.recordType=='friend_status' and m.people[e.subject] and type(d.after)=='boolean' then m.people[e.subject].friend={active=d.after,at=e.at} end
 if e.kind=='group_roster' then for _,g in ipairs(e.details.members or {}) do touch(g) end end
 -- A supporting party context can accompany an entire instance expedition.
 -- Track its relationship here, so Chronicle/Intel consumers need not count
 -- the party ledger as another adventure or hide duplicate UI rows ad hoc.
 local parties={};local major=false
 for id in pairs(st.links[e.id] or {}) do local activity=st.byID[id]
  if I.IsAdventure(activity) then
   major=true;m.adventureDetails=m.adventureDetails or {};local summary=m.adventureDetails[id] or {quests={},loot=0,rewards={}};m.adventureDetails[id]=summary
   if e.kind=='quest_accepted' or e.kind=='quest_objective' or e.kind=='quest_turnin' then summary.quests[d.questOccurrenceRef or d.questID or e.id]=true end
   if d.recordType=='item_received' or d.recordType=='quest_item_received' or d.recordType=='encounter_loot_delivery' then summary.loot=summary.loot+1;if #summary.rewards<3 then summary.rewards[#summary.rewards+1]=e.id end end
  elseif activity and activity.kind=='group' then parties[#parties+1]=activity.id end
 end
 m.partyContexts=m.partyContexts or {}
 for _,id in ipairs(parties) do local context=m.partyContexts[id] or {};m.partyContexts[id]=context
  if major then context.supportsAdventure=true
  elseif ({quest_accepted=true,quest_objective=true,quest_turnin=true,player_combat=true,player_kill_credit=true})[e.kind] or d.recordType=='native_kill_credit' then context.outsideAdventure=true end
 end
 if ns.AthenaStats then ns.AthenaStats.Feed(st,e) end
end
function I.AdventureDetails(st,a)
 local quests,loot,rewards={},0,{}
 for _,id in ipairs(a.segmentIDs or {a.id}) do local row=st.athena2 and st.athena2.adventureDetails and st.athena2.adventureDetails[id]
  if row then for key in pairs(row.quests) do quests[key]=true end;loot=loot+row.loot;for _,ref in ipairs(row.rewards) do if #rewards<3 then rewards[#rewards+1]=ref end end end
 end
 return {quests=R.Count(quests),loot=loot,rewards=rewards}
end
function I.Experiences(st,filter)
 local ready,state=I.Ensure(st,st.owner);if not ready then return nil,state end
 local options={};for key,value in pairs(filter or {}) do options[key]=value end
 local limit=math.min(options.limit or 120,120);options.limit=240;options.groupReloads=true
 local rows={}
 for _,a in ipairs(A.Query(st,options)) do local context=st.athena2.partyContexts and st.athena2.partyContexts[a.id]
  if not (a.kind=='group' and context and context.supportsAdventure and not context.outsideAdventure) then rows[#rows+1]=a;if #rows>=limit then break end end
 end
 return rows
end
local observing=false
local function ObserveUpdates()
 if observing then return end;observing=true
 local original=A.Feed
 A.Feed=function(st,e)
  original(st,e)
  if st.athena2 and st.athena2.ready then I.Feed(st,e);st.athena2.cursor=st.athena2.cursor+1 end
 end
end
function I.Ensure(st,owner)
 ObserveUpdates()
 local m=meta(st);local c=S.Character(owner or st.owner,false)
 if not c then return nil,'HISTORY_UNAVAILABLE' end
 local count=st.processed or #c.events
 if m.ready and m.cursor==count then return m end
 if m.pending then return nil,'DERIVED_INDEX_PENDING' end
 local raw=c.events;local tail=raw[count];m.cursor=m.cursor or 0;m.ready=false;m.pending=true
 if m.cursor==0 and count>0 then I.wholeHistoryScans=I.wholeHistoryScans+1 end
 local submitted=ns.WardenScheduler.Submit('athena profiles/'..st.owner,'interactive',function(deadline)
  if S.Character(st.owner,false)~=c or c.events~=raw or raw[count]~=tail then m.pending=nil;st.athena2=nil;return true end
  local stop=math.min(count,m.cursor+128)
  while m.cursor<stop do
   if ns.WardenPerformance.Expired(deadline) then return false end
   m.cursor=m.cursor+1;I.Feed(st,raw[m.cursor])
  end
  if m.cursor>=count then m.pending=nil;m.ready=true;return true end
 end,{module='history',onCancel=function() m.pending=nil end})
 if not submitted then m.pending=nil;return nil,'BUSY' end
 return nil,'DERIVED_INDEX_PENDING'
end
function I.GetPlayer(guid,owner,consumer)
 if not R.Permit(consumer or 'intel') or not R.GUID(guid) then return nil,'DENIED' end
 owner=owner or R.Owner();local st,state=I.Request(owner);if not st then return nil,state end;I.queries=I.queries+1
 local ready,pending=I.Ensure(st,owner);local m=st.athena2;local p=ready and m.people[guid];local c=S.Character(owner,false);local source=c and c.profiles[guid]
 if not p and not source then return nil,pending or 'UNKNOWN' end
 local origin=R.Origin(st)
 if not ready and origin~='synthetic' then origin='unverified_archive' end
 local rev={origin,p and p.revision or 0}
 for _,field in ipairs({'name','realm','class','race','faction','guild','level'}) do local f=source and source.facts and source.facts[field];rev[#rev+1]=f and f.at or 0 end
 local revision=table.concat(rev,'/')
 local key=owner..'/'..guid;local cached=I.cache:Get(key,revision)
 if cached then return R.Copy(cached) end
 local identity,freshness={},{}
 for _,k in ipairs({'name','realm','class','race','faction','guild','level'}) do
  local f=source and source.facts and source.facts[k]
  if f then identity[k]=f.value;freshness[k]=f.at end
  if p and p.identity[k]~=nil and (p.freshness[k] or 0)>=(freshness[k] or 0) then identity[k]=p.identity[k];freshness[k]=p.freshness[k] end
 end
 local links=st.players[guid];local out={schema=1,kind='player',personKey=guid,ownerKey=owner,self=guid==Own(owner),identity=identity,freshness=freshness,revision=revision,sourceOrigin=origin,coverage='Loaded observer archive; unknown fields stay unknown',activityCount=links and #links.activities or 0,evidenceCount=links and #links.evidence or 0}
 I.cache:Put(key,revision,out);return R.Copy(out)
end
function I.GetMyProfile(consumer) return I.GetPlayer(Own(R.Owner()),R.Owner(),consumer) end
function I.GetEvent(id,owner,consumer)
 if not R.Permit(consumer or 'chronicle') or not R.Text(id,512) then return nil,'DENIED' end
 local st,state=I.Request(owner);if not st then return nil,state end
 local ready=I.Ensure(st,owner);local origin=R.Origin(st);if not ready and origin~='synthetic' then origin='unverified_archive' end
 local a=A.View(st,id);if not a then return nil,'UNKNOWN' end
 return {schema=1,kind='event',eventKey=a.id,ownerKey=st.owner,activityType=a.kind,firstAt=a.startAt,lastAt=a.lastAt,status=a.status,completion=a.completion or 'unknown',mapID=a.context and a.context.instanceID,mapName=a.context and a.context.instanceName,evidenceCount=#a.evidence,sourceOrigin=origin,revision=st.revision,coverage='Observed segments; completion is not a full clear guarantee'}
end
function I.Sources(kind,key,owner,cursor,consumer)
 if not R.Permit(consumer or 'intel') then return nil,'DENIED' end
 local st,state=I.Request(owner);if not st then return nil,state end
 local p=kind=='event' and A.View(st,key) or st.players[key];local refs=p and p.evidence or {};local offset=R.Number(cursor,0,#refs) or 0;local out={}
 for n=offset+1,math.min(#refs,offset+50) do local e=st.events[refs[n]] or st.intelligence and st.intelligence.events[refs[n]]
  if e and ns.AthenaHistoryGraph.CanRead(consumer or 'intel',e) then out[#out+1]='history:'..e.id end
 end
 return out,offset+50<#refs and offset+50 or nil
end
function I.Clear() I.cache:Clear() end
