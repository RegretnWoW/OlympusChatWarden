-- UI2 subject selectors. Ephemeral projections over existing accepted indices.
-- No saved ledger, producer, network request or presentation builder belongs here.
local _,ns=...
local M={VERSION=1,cache={},order={},pending={},errors={},jobs={},jobSerial=0,builds=0,hits=0,maxCache=24};ns.UI2Models=M
local A,S=ns.ChronicleActivities,ns.ChronicleStore
local labels={dungeon='Dungeon',raid='Raid',battleground='Battleground',arena='Arena',group='Party',guild='Guild gathering',duel='Duel',boss='World encounter'}
local moments={instance_enter='Entered the instance',instance_exit='Left the instance',group_roster='Group composition recorded',encounter_started='Encounter began',encounter_ended='Encounter ended',player_death='Death recorded',quest_accepted='Assignment accepted',quest_objective='Objective advanced',quest_turnin='Assignment completed',item_received='Item received',quest_item_received='Quest reward received',encounter_loot_delivery='Encounter loot reported',adventure_combat_summary='Combat summary recorded',guild_affiliation='Guild affiliation changed',pvp_match_complete='Match completed',recording_start='Observation resumed',recording_stop='Observation paused'}
local function count(t) local n=0;for _ in pairs(t or {}) do n=n+1 end;return n end
local function origin(e) return e and e.details and e.details.origin=='synthetic' and 'synthetic' or e and e.source=='SYNTHETIC' and 'synthetic' or 'recorded' end
local function clean(v) return type(v)=='string' and ns.SafeString(v,512) or nil end
local function field(v,state,at) return {value=v,state=v~=nil and state or 'unknown',at=at} end
local function Name(st,guid,at)
 local n=A.Name(st,guid,at);return n~=guid and n or 'Unidentified player'
end
local function Identity(st,guid,at)
 local c=not st.asOf and S.Character(st.owner,false);local p=c and c.profiles[guid];local out={}
 if st.asOf then local person=st.athena2 and st.athena2.people[guid];for k,v in pairs(person and person.identity or {}) do out[k]=v end end
 for _,k in ipairs({'name','realm','class','race','guild','level','faction'}) do local f=p and p.facts and p.facts[k];if f then out[k]=f.value end end
 local card=ns.WardenCharacterCards.FromState(st,guid,at or st.asOf)
 if card then for _,k in ipairs({'name','realm','class','race','guild','level','faction'}) do if card.values[k]~=nil then out[k]=card.values[k] end end end
 if not st.asOf and guid==st.owner:match('/(Player%-.+)$') then
  local me=ns.AthenaProfiles.GetPlayer(guid,st.owner,'chronicle')
  if me then for k,v in pairs(me.identity or {}) do if out[k]==nil then out[k]=v end end end
  out.name=out.name or 'You · observing character'
 end
 out.name=out.name or Name(st,guid,at)
 return out,card
end
function M.Title(a,st,subject)
 if a.kind=='duel' then local own=st and st.owner:match('/(Player%-.+)$');local opponent=subject==a.opponentGUID and own or a.opponentGUID
  local name=st and opponent and Name(st,opponent,a.lastAt)
  if st and opponent==own then local profile=ns.AthenaProfiles.GetPlayer(own,st.owner,'intel');name=profile and profile.identity.name or 'the observing character' end
  return 'Duel with '..(name or 'unidentified opponent')
 end
 return (a.context.instanceName or a.context.zone or labels[a.kind] or 'Adventure')..' · '..(labels[a.kind] or 'Activity')
end
function M.Status(a,st,subject)
 if a.kind=='duel' and a.duel then
  if not a.duel.accepted then return a.endAt and 'Challenge ended · not started' or 'Challenge pending' end
  local result=a.duel.result;if st and subject==a.opponentGUID then result=result=='win' and 'loss' or result=='loss' and 'win' or result end
  return ({win='Victory',loss='Defeat',conflicting='Conflicting result observations'})[result] or 'Outcome not established'
 end
 local state=a.run and a.run.state
 if state=='COMPLETED' and (a.kind=='dungeon' or a.kind=='raid') then return a.run.completionBasis=='finishing_encounter' and 'Final encounter won' or a.run.completionBasis=='native_completion_report' and 'Instance completion reported' or 'Expedition concluded' end
 return ({COMPLETED='Completed',PARTIAL='Partial expedition',INTERRUPTED='Observation interrupted',SUSPENDED='Away from the instance',ACTIVE='In progress',UNKNOWN='Outcome not recorded'})[state] or (a.status=='open' and 'In progress' or a.completion=='success' and 'Encounter concluded' or 'Observation ended')
end
function M.Moment(e)
 local d=e.details or {};local k=d.recordType or e.kind
 if e.capture and e.capture.family=='scoreboard_page' then return 'Scoreboard captured' end
 if e.capture and e.capture.family=='scoreboard' then return nil end
 if e.kind=='player_observed' or e.kind=='native_snapshot' then return nil end
 return moments[k] or moments[e.kind]
end
local function Revision(st,key)
 local c=S.Character(st.owner,false)
 local draft=key and ns.PlayerCard.Local(key)
 local outreach=ns.RelayOutreach.Current.session
 local reader=ns.AthenaJournalWindow.window and ns.AthenaJournalWindow.window.reader
 local chapters=reader and reader.job and reader.job.done and reader.library and #reader.library.stories or 0
 local net=ns.AetherNet and ns.AetherNet.Cached and ns.AetherNet.Cached()
 local netRevision=(net and net:CacheToken() or 'OFF')..'/'..tostring(ns.RelayStore.revision or 0)
 return table.concat({st.generation or A.generation or 0,st.revision or 0,st.processed or 0,c and c.revision or 0,ns.Fellowship.revision,outreach and outreach.state or 'none',chapters,reader and tostring(reader.library) or '-',reader and reader.job and reader.job.status or '-',draft and draft.revision or 0,netRevision,math.floor((ns.SafeCall(GetServerTime) or 0)/30)},':')
end
local function PartySize(st,a)
 local members={};for guid in pairs(a.members or {}) do members[guid]=true end
 local own=st.owner:match('/(Player%-.+)$')
 for _,ref in ipairs(a.rosters or {}) do local e=st.events[ref];local d=e and e.details or {}
  if d.rosterComplete==true and not d.rosterRaid and d.rosterSize and d.rosterSize>1 and #(d.members or {})==d.rosterSize-1 or e and e.source=='GROUP_ROSTER_UPDATE' and d.rosterRaid==true and d.rosterSize and d.rosterSize>0 then members[own]=true end
 end
 if a.kind=='duel' and a.duel and a.duel.accepted then members[own]=true end
 return count(members)
end
M.EncounterGroups=ns.AthenaAdventureSummary.Encounters
local function Loot(st,e)
 local d=e.details or {};local k=d.recordType or e.kind
 local name,link,quality,_,_,_,_,_,_,icon=ns.WardenBrand.Values(GetItemInfo or C_Item and C_Item.GetItemInfo,d.itemString or d.itemID)
 local own=st.owner:match('/(Player%-.+)$');local recipient='Recipient not recorded'
 if (k=='item_received' or k=='quest_item_received') and e.subject==own then recipient=Identity(st,own,e.at).name end
 if not name or name=='Unknown' or name=='' then name='Item not identified' end
 return {title=name,link=d.itemString or link,itemID=d.itemID,icon=icon,quality=quality,quantity=field(d.quantity,origin(e),e.at),recipient=recipient,scope=k=='encounter_loot_delivery' and 'Reward observed' or 'Item received',at=e.at,state=origin(e),_ref=e.id}
end
local function buildActivity(st,a)
 local model={eventRef=ns.AthenaHistoryGraph.EventFor(st,a),kind='activity',key=a.id,owner=st.owner,title=M.Title(a,st,st.owner:match('/(Player%-.+)$')),category=a.kind,status=M.Status(a,st,st.owner:match('/(Player%-.+)$')),sections={},participants={},encounters={},quests={},loot={},timeline={},boards={},combat={},related={},sourceState='recorded',firstAt=a.startAt,lastAt=a.lastAt,endAt=a.run and a.run.endedAt or a.endAt,visits=a.recordingSegments or 1,coverage={}}
 model.momentCaptures={}
 local deaths,sourceCount=0,0;local combatWindows,questGroups={},{}
 for index,ref in ipairs(a.evidence or {}) do
  local e=st.events[ref]
  if e then
   sourceCount=sourceCount+1;local d=e.details or {};local k=d.recordType or e.kind;local state=origin(e)
   if state=='synthetic' then model.sourceState='synthetic' end
   -- Ordinary return trips and intermediate counter checkpoints are already
   -- represented by the run, roster and final combat windows on this page.
   -- Routine collector administration stays in the original evidence. The
   -- player timeline is composed below from meaningful, consolidated subjects.
   if k=='player_death' then model.timeline[#model.timeline+1]={title='Death recorded',at=e.at,state=state,_ref=e.id,priority=70,section='combat'} end
   if e.kind=='player_death' then deaths=deaths+1 end
   if k=='moment_capture'then model.momentCaptures[d.requestRef]={title=d.category,status=d.captureStatus,at=e.at,sourceRef=d.sourceRef}end
   if e.kind=='quest_accepted' or e.kind=='quest_turnin' or e.kind=='quest_objective' then
    local q=d.questID and ns.AthenaWorldKnowledge.GetQuest(d.questID)
    local key=d.questOccurrenceRef or d.questID or e.id;local row=questGroups[key]
    if not row or e.kind=='quest_accepted' and row.status=='Completed' then
     row={title=clean(d.title) or q and q.title or 'Recorded assignment',questID=d.questID,firstAt=e.at,state=state,_ref=e.id,changes=0};questGroups[key]=row;model.quests[#model.quests+1]=row
    end
    row.status=e.kind=='quest_turnin' and 'Completed' or e.kind=='quest_accepted' and 'Accepted' or 'Progress';row.at=e.at;row.changes=row.changes+1
   end
   if k=='item_received' or k=='quest_item_received' or k=='encounter_loot_delivery' then
    model.loot[#model.loot+1]=Loot(st,e)
   end
   if k=='adventure_combat_summary' and ns.AthenaAdventureEvidence.ValidRecord(e,st.owner) then
    -- Retain only actual explicitly attributed counters, never nearby meter totals.
    local row={title='Your recorded combat',at=e.at,state=state,_ref=e.id,values={}}
    for _,key in ipairs({'deaths','selfCredits','petCredits','minHealthPercent','combatSeconds'}) do if type(d[key])=='number' then row.values[key]=d[key] end end
    row.window=d.windowRef;row.revision=d.revision;row.firstAt=d.firstAt;row.lowHealthObserved=d.lowHealthObserved;row.recoveryObserved=d.recoveryObserved
    if not combatWindows[d.windowRef] or d.revision>combatWindows[d.windowRef].revision then combatWindows[d.windowRef]=row end
   end
  end
  if index%64==0 then coroutine.yield() end
 end
 for _,row in pairs(combatWindows) do model.combat[#model.combat+1]=row end
 table.sort(model.combat,function(x,y) return x.firstAt<y.firstAt end)
 model.encounters=M.EncounterGroups(a,model.sourceState);model.attemptCount=#(a.attempts or {})
 for _,boss in ipairs(model.encounters) do
  local result=boss.lastOutcome=='success' or boss.lastOutcome=='native boss kill'
  model.timeline[#model.timeline+1]={title=boss.title..(result and ' · victory' or boss.defeats>0 and ' · attempt ended without victory' or ' · outcome unresolved'),at=boss.lastAt,state=model.sourceState,priority=100,section='encounters'}
 end
 for _,quest in ipairs(model.quests) do model.timeline[#model.timeline+1]={title=quest.title..' · '..quest.status:lower(),at=quest.at,state=quest.state,_ref=quest._ref,priority=quest.status=='Completed' and 90 or 80,section='quests'} end
 for _,reward in ipairs(model.loot) do model.timeline[#model.timeline+1]={title='Reward observed · '..reward.title,at=reward.at,state=reward.state,_ref=reward._ref,priority=85,section='loot'} end
 model.adventureSummary=ns.AthenaAdventureSummary.Get(st,a);model.combatSummary=model.adventureSummary.combat
 local close=model.combatSummary.closeCall
 if close then model.timeline[#model.timeline+1]={title='Health reached '..close.value.minHealthPercent..'%'..(model.combatSummary.recoveryObserved and ' · recovery observed' or ''),at=close.value.firstAt,state=model.sourceState,priority=75,section='combat'} end
 local roles={};local members={};for guid in pairs(a.members or {}) do members[guid]=true end
 local own=st.owner:match('/(Player%-.+)$')
 for _,ref in ipairs(a.rosters or {}) do local e=st.events[ref];local d=e and e.details or {};for _,p in ipairs(d.roster or d.players or {}) do if type(p)=='table' and p.guid then roles[p.guid]=p.role end end
  -- Chronicle's relationship index deliberately excludes self. A party roster's
  -- documented count includes its observer; raid rosters explicitly list self.
  if d.rosterComplete==true and not d.rosterRaid and d.rosterSize and d.rosterSize>1 and #(d.members or {})==d.rosterSize-1 then members[own]=true end
  -- The native collector only sets rosterRaid after IsInRaid; its ordinary
  -- observation helper excludes self, so even a partial raid roster may omit
  -- the verified observing character without making that character unknown.
  if e.source=='GROUP_ROSTER_UPDATE' and d.rosterRaid==true and d.rosterSize and d.rosterSize>0 then members[own]=true end
  for _,guid in ipairs(d.members or {}) do if guid==own then members[own]=true end end
 end
 for guid in pairs(members) do local v,card=Identity(st,guid,a.lastAt)
  model.participants[#model.participants+1]={key=guid,owner=st.owner,title=v.name,identity=v,card=card,role=roles[guid],state=model.sourceState}
  if #model.participants%16==0 then coroutine.yield() end
 end
 table.sort(model.participants,function(x,y) return x.title<y.title or x.title==y.title and x.key<y.key end)
 if a.kind=='duel' and a.duel then
  local G,D=ns.WardenDossier,ns.ChronicleDuels;local index=G.Request(st.owner)
  while index and not index.done do G.Pump(index,128);coroutine.yield() end
  local objects=index and not index.stale and index.objects or {};model.duelSnapshots={}
  for _,guid in ipairs({own,a.opponentGUID or false}) do
   local side={key=guid or nil,title=guid==own and 'Your recorded loadout' or guid and Name(st,guid,a.lastAt) or 'Opponent identity unavailable',identity=guid and Identity(st,guid,a.lastAt) or {},phases={}}
   local before=guid and D.Observation(a,guid,'before');local after=guid and D.Observation(a,guid,'after')
   for phase,event in pairs({before=before,after=after}) do
    local d=event.details;local gear=d.gearRef and objects[d.gearRef];local traits=d.traitRef and objects[d.traitRef]
    if gear and (gear.capture.family~='gear' or gear.capture.values.guid~=guid) then gear=nil end
    if traits and (traits.capture.family~='traits' or traits.capture.values.guid~=guid) then traits=nil end
    side.phases[phase]={at=d.observedAt or event.at,gear=gear and {object=gear,at=event.at},traits=traits,ref=event.id}
   end
   side.gearComparison=D.Compare(before,after,'gear',st.owner,objects);side.traitComparison=D.Compare(before,after,'traits',st.owner,objects)
   for _,event in ipairs(guid and a.duel.combat[guid] or {}) do local d=event.details
    if d.scope=='damage received; attacker unknown' then side.damage=(side.damage or 0)+d.amount
    elseif d.scope=='healing received; caster unknown' then side.healing=(side.healing or 0)+d.amount
    elseif d.scope=='observed successful casts' then side.casts=(side.casts or 0)+d.count end
   end
   model.duelSnapshots[#model.duelSnapshots+1]=side
  end
 end
 local reports=ns.ChronicleScoreboards.List(st,a)
 -- One latest exact-match observation, with completeness stated; no row summation.
 for reportIndex,report in ipairs(reports) do local board={id=report.id,phase=report.phase,complete=ns.ChronicleScoreboards.Complete(report),firstAt=report.firstAt,lastAt=report.lastAt,rows={},state=model.sourceState}
  for _,r in ipairs(ns.ChronicleScoreboards.Rows(report)) do local v=r.values;local row={title=clean(v.name) or 'Unidentified participant',key=v.guid,values={},state=origin(r.source)}
   for _,k in ipairs({'killingBlows','honorableKills','deaths','damageDone','healingDone','honorGained','class','faction','race','level','objectives'}) do row.values[k]=v[k] end
   board.rows[#board.rows+1]=row
  end;model.boards[reportIndex]=board;if reportIndex%8==0 then coroutine.yield() end
 end
 -- Significance selects the readable overview; chronology orders its moments.
 -- Every encounter, reward and quest remains in its complete section above.
 table.sort(model.timeline,function(x,y) return x.priority>y.priority or x.priority==y.priority and x.at<y.at end)
 model.timelineOmitted=math.max(0,#model.timeline-20)
 while #model.timeline>20 do table.remove(model.timeline) end
 table.sort(model.timeline,function(x,y) return x.at<y.at or x.at==y.at and x.priority>y.priority end)
 local timing=ns.ChronicleIntelligence.ActivityTime(st,a)
 model.measuredSeconds=field(type(timing)=='number' and timing>0 and timing or nil,'derived')
 model.metrics={{label='Encounter attempts',value=model.attemptCount>0 and model.attemptCount or nil},{label='Known participants',value=#model.participants>0 and #model.participants or nil},{label='Quest changes',value=#model.quests>0 and #model.quests or nil},{label='Loot observations',value=#model.loot>0 and #model.loot or nil}}
 if deaths>0 then model.metrics[#model.metrics+1]={label='Deaths recorded',value=deaths} end
 model.coverage={'Observed visits are grouped into this run. Leaving or reloading does not by itself prove completion.','Roster inclusion establishes a shared group, not attendance at every encounter.','Loot observations may overlap, so Fireside does not add them into a complete loot total.'}
 if #model.encounters==0 then model.coverage[#model.coverage+1]='No encounter outcomes were linked to this activity.' end
 model.sourceCount=sourceCount;model._activity=a
 model.summary=model.adventureSummary.text
 return model
end
function M.ReadyChapters(owner)
 local refs={};local reader=ns.AthenaJournalWindow.window and ns.AthenaJournalWindow.window.reader
 if reader and reader.owner==owner and reader.job and reader.job.done and reader.job.status=='READY' and reader.library then
  for _,story in ipairs(reader.library.stories or {}) do
   for _,ref in ipairs(story.sourceActivityRefs or {}) do refs[ref]=story.storyId end
  end
 end
 return refs
end
function M.ActivityChapter(st,a,refs)
 if not st or not a then return end;refs=refs or M.ReadyChapters(st.owner)
 for _,id in ipairs(a.segmentIDs or {a.id}) do
  local segment=st.byID[id];local ref=segment and ns.Athena.EvidenceRef(segment.anchor)
  if ref and refs[ref] then return refs[ref] end
 end
end
local function buildPlayer(st,guid)
 -- Wait for the existing cooperative identity/progression lens. Publishing a
 -- cached 'unknown self' while this lens is pending leaves a stale empty card.
 while not st.asOf do local ready,state=ns.AthenaProfiles.Ensure(st,st.owner);if ready or state~='DERIVED_INDEX_PENDING' and state~='BUSY' then break end;coroutine.yield() end
 local identity,card=Identity(st,guid)
 local intel=ns.ChronicleIntelligence.Player(st,guid)
 local c=not st.asOf and S.Character(st.owner,false);local stored=c and c.profiles[guid];local p=st.players[guid]
 local profile=not st.asOf and ns.AthenaProfiles.GetPlayer(guid,st.owner,'intel')
 local model={kind='player',key=guid,owner=st.owner,title=identity.name,identity=identity,card=card,sourceState=st.syntheticEvidence and 'synthetic' or 'recorded',activities={},interactions={},equipment={},metrics={},note=intel.note,watch=intel.watch,relationship=intel.description,lastAt=intel.lastEvidenceAt or intel.lastEncounter,coverage={'This dossier describes this observer’s retained history, not lifetime statistics.'},known=p~=nil or stored~=nil or profile~=nil}
 model._sourceState=st;model.asOf=st.asOf;model.presence=ns.AthenaHistoryGraph.Presence(guid,st.owner,st.asOf)
 if not st.asOf then
  local net=ns.AetherNet.Presence(guid)
  if net and net.activityKnown and #model.presence.group==0 then model.presence=net
  elseif net then model.presence.wardenStatus=net.wardenStatus;model.presence.online=net.online;model.presence.lastSeen=net.lastSeen;model.presence.expiresAt=net.expiresAt or model.presence.expiresAt end
 end
 local dates;while not dates do local why;dates,why=ns.AthenaHistoryGraph.PlayerDates(guid,st.owner);if why~='INDEXING' then break end;coroutine.yield() end;model.observedDates=dates or {}
 if identity.guild then local key=ns.AthenaHistoryGraph.GuildKey(st.owner,identity.guild,identity.realm);if key and ns.AthenaHistoryGraph.ResolveGuild(key,st.owner) then model.guildRef=key end end
 model.self=guid==ns.PlayerCard.Own();model.observer=guid==st.owner:match('/(Player%-.+)$');model.adventures={};model.companions={};model.storyLinks={};model.bosses={}
 local seen,companions={},{};local ids=model.observer and st.activities or p and p.activities or {}
 local chapterRefs=M.ReadyChapters(st.owner)
 for n=#ids,1,-1 do local a=A.View(st,type(ids[n])=='table' and ids[n].id or ids[n]);if a and not seen[a.id] then
  seen[a.id]=true
  if ns.AthenaProfiles.IsAdventure(a) then
  local chapterId=M.ActivityChapter(st,a,chapterRefs)
  local detail=ns.AthenaProfiles.AdventureDetails(st,a);local known=PartySize(st,a);local context={}
  if #a.attempts>0 then context[#context+1]=#a.attempts..' encounter attempts' end
  if known>0 then context[#context+1]=known..' known participants' end
  if detail.quests>0 then context[#context+1]='Quest progress' end
  if detail.loot>0 then context[#context+1]=detail.loot..' reward observations' end
  local place=a.kind=='duel' and M.Title(a,st,guid) or a.context.instanceName or a.context.zone or labels[a.kind]
  local people={};for member in pairs(a.members or {}) do people[#people+1]={key=member,owner=st.owner,title=Name(st,member,a.lastAt),identity=Identity(st,member,a.lastAt),state=model.sourceState} end
  table.sort(people,function(x,y) return x.title<y.title end)
  local rewards={};for _,ref in ipairs(detail.rewards) do if st.events[ref] then rewards[#rewards+1]=Loot(st,st.events[ref]) end end
  local sharedSummary=ns.AthenaAdventureSummary.Get(st,a);local summary=sharedSummary.text
  model.activities[#model.activities+1]={key=a.id,owner=st.owner,title=M.Title(a,st,guid),place=place,location=a.context.zone,status=M.Status(a,st,guid),concluded=a.run and a.run.state=='COMPLETED' or a.kind=='duel' and a.duel and a.duel.result~='unknown',category=a.kind,at=a.startAt,chapterId=chapterId,context=table.concat(context,' · '),summary=summary,state=model.sourceState,details=detail,knownParticipants=known,attempts=#a.attempts,people=people,rewards=rewards,fullClearVerified=a.run and a.run.fullClearVerified or false}
  model.activities[#model.activities].adventureSummary=sharedSummary
  local group=model.adventures[a.kind] or {count=0,concluded=0,partial=0,victories=0};model.adventures[a.kind]=group;group.count=group.count+1
  local state=a.run and a.run.state
  if state=='COMPLETED' then group.concluded=group.concluded+1 elseif state=='PARTIAL' or state=='INTERRUPTED' then group.partial=group.partial+1 end
  for _,attempt in ipairs(a.attempts or {}) do if attempt.outcome=='success' or attempt.outcome=='native boss kill' then group.victories=group.victories+1
   if #model.bosses<12 then model.bosses[#model.bosses+1]={title=attempt.name or 'Observed encounter',at=attempt.endAt,key=a.id,owner=st.owner} end
  end end
  for other in pairs(a.members or {}) do if other~=guid and other~=st.owner:match('/(Player%-.+)$') then
   local co=companions[other] or {key=other,owner=st.owner,title=Name(st,other,a.lastAt),identity=Identity(st,other,a.lastAt),state=model.sourceState,count=0,kinds={}};companions[other]=co;co.count=co.count+1;co.kinds[a.kind]=(co.kinds[a.kind] or 0)+1;co.latest=co.latest or a.context.instanceName or a.context.zone
  end end
  if a.anchor and #model.storyLinks<8 then model.storyLinks[#model.storyLinks+1]={title=a.context.instanceName or a.context.zone or labels[a.kind] or 'Shared adventure',activityRef=ns.Athena.EvidenceRef(a.anchor),owner=st.owner,at=a.startAt} end
  end
 end;if n%32==0 then coroutine.yield() end end
 for _,co in pairs(companions) do local person=st.athena2 and st.athena2.people[co.key];co.friend=person and person.friend and person.friend.active==true;model.companions[#model.companions+1]=co end
 table.sort(model.companions,function(x,y) return x.count>y.count or x.count==y.count and x.key<y.key end)
 if model.observer then local indexed=st.athena2 and st.athena2.people[guid];model.progression=indexed and indexed.progression end
 if #model.activities>0 then model.metrics[#model.metrics+1]={label='Shared activities observed',value=#model.activities} end
 if intel.recordedEncounters and intel.recordedEncounters>0 then model.metrics[#model.metrics+1]={label='Local encounters',value=intel.recordedEncounters} end
 if intel.lastInspection then model.interactions[#model.interactions+1]={title='Manually inspected',at=intel.lastInspection} end
 for _,r in ipairs(intel.tierReasons or {}) do model.interactions[#model.interactions+1]={title=r.label,at=r.at} end
 local stats=not st.asOf and ns.AthenaStats.Get(guid,st.owner,'intel')
 if stats and stats.matchCount>0 then model.pvp=stats end
 local listing=not st.asOf and ns.AthenaNativeLFGAdapter.Current:LeaderListing(guid)
 if listing then model.listing={key=listing.key,generation=listing.generation,resultID=listing.resultID,title=listing.title,source=listing.source} end
 local j=model.known and ns.WardenDossier.Request(st.owner)
 if j and not j.done then while not j.done do ns.WardenDossier.Pump(j,128);coroutine.yield() end end
 if j and j.done then
  model.gearSets=ns.WardenDossier.Configurations(j,guid,'gear');model.talentSets=ns.WardenDossier.Configurations(j,guid,'traits');model.loadoutIndex=j
  for _,row in ipairs(ns.WardenDossier.Rows(j,guid,'gear') or {}) do model.equipment[#model.equipment+1]=row;if #model.equipment>=1 then break end end
 end
 if st.asOf and j then
  local function dated(sets)
   local result={};for _,set in ipairs(sets or {}) do local copy={};for k,v in pairs(set) do copy[k]=v end;copy.observations={}
    for _,o in ipairs(set.observations or {}) do if o.at<=st.asOf and (not o.event or o.event.at<=st.asOf) and (not o.object or o.object.at<=st.asOf) then copy.observations[#copy.observations+1]=o end end
    if #copy.observations==0 and set.object and set.object.at<=st.asOf then copy.observations[1]={object=set.object,event=set.object,at=set.object.at,hash=set.hash,standalone=true} end
    if #copy.observations>0 then local last=copy.observations[#copy.observations];copy.at=last.at;copy.event=last.event;result[#result+1]=copy end
   end;return result
  end
  model.gearSets=dated(model.gearSets);model.talentSets=dated(model.talentSets);model.equipment={}
  local bounded={};for k,v in pairs(j) do bounded[k]=v end;bounded.objects={};local count=0;for hash,object in pairs(j.objects) do if object.at<=st.asOf then bounded.objects[hash]=object end;count=count+1;if count%128==0 then coroutine.yield() end end;model.loadoutIndex=bounded
  if model.gearSets[1] then model.equipment[1]=model.gearSets[1] end
 end
 if not model.known then model.sourceState='unknown';model.coverage[#model.coverage+1]='No retained observations identify this person. Nothing has been requested from another player.' end
 model.match=ns.Fellowship.GetPlayerMatch(guid)
 model.requests={};for _,request in pairs(ns.Fellowship.requests) do if request.guid==guid then model.requests[#model.requests+1]=request end end
 local outreach=ns.RelayOutreach.Current.session;model.outreach=outreach and outreach.target.guid==guid and outreach.state or 'No outreach started'
 -- Public/social fields have one authority. Old Exchange/local drafts never
 -- become published declarations, opinions or remote character observations.
 model.profileDraft=ns.PlayerCard.Local(guid)
 if st.owner==ns.Chronicle.Owner() then model.receivedCaptures=ns.RelayStore.ReceivedFor(ns.PlayerCard.Own(),guid) or {} end
   model.publicUnavailable='No public profile information is available for this subject. Private notes and unpublished drafts are not part of the public profile.'
 local net=ns.AetherNet.Cached()
 do
  model.aetherNet=ns.AetherNet.ReadSubject('CHARACTER',guid)
  model.remote={claims={},rating=model.aetherNet.rating}
  if not st.asOf and not model.known and model.aetherNet.identity.name and model.aetherNet.identity.realm then
   model.identity=model.aetherNet.identity;model.title=model.identity.name;model.sourceState='shared'
   model.coverage={'Shared through Aether; this is not a record of meeting the player yourself.'}
  end
  local owner=model.aetherNet.owner
  if owner then model.declaration={gamerzone=owner.gamerzone and owner.gamerzone:lower(),revision=owner.revision} end
 end
 return model
end
local function get(kind,key,owner,asOf)
 M.lastError=nil
 owner=owner or ns.Chronicle.Owner();local consumer=kind=='player' and 'intel' or 'chronicle'
 if not ns.Athena2.Permit(consumer) then return nil,'Access or module unavailable' end
 local st,state;if asOf then st,state=ns.AthenaHistoryGraph.AsOf(owner,asOf) else st,state=A.Request(owner) end;if not st then return nil,state or 'Preparing history' end
 local a=kind=='activity' and A.View(st,key)
 if kind=='activity' then if not a then return nil,'Activity unavailable' end;key=a.id end
 if kind=='player' and not S.GUID(key) then return nil,'Player identity unavailable' end
 local id=owner..'/'..kind..'/'..key..'/'..tostring(asOf or 'latest');local rev=Revision(st,key);local entry=M.cache[id]
 local failure=M.errors[id];if failure and failure.revision==rev then M.lastError=failure.message;return nil,'Dossier preparation failed' end
 if entry and entry.revision==rev then M.hits=M.hits+1;return entry.model end
 if M.pending[id] then return entry and entry.model,entry and 'refreshing' or 'Preparing dossier' end
 local character=S.Character(owner,false);local events=character and character.events
 local co=coroutine.create(function() return kind=='activity' and buildActivity(st,a) or buildPlayer(st,key) end)
 local token={};M.pending[id]=token
 M.jobSerial=M.jobSerial+1;local jobKey='ui2 subject/'..M.jobSerial;M.jobs[jobKey]=true
 local function finished() M.jobs[jobKey]=nil;if M.pending[id]==token then M.pending[id]=nil end end
 local ok=ns.WardenScheduler.Submit(jobKey,'interactive',function(deadline)
  if M.pending[id]~=token or S.Character(owner,false)~=character or character and character.events~=events or Revision(st,key)~=rev then finished();return true end
  local resumed,result=coroutine.resume(co)
  if not resumed then finished();M.errors[id]={revision=rev,message=tostring(result)};return true end
  if coroutine.status(co)~='dead' then return false end
  finished();M.builds=M.builds+1
  if not M.cache[id] then M.order[#M.order+1]=id end
  M.cache[id]={revision=rev,model=result}
  while #M.order>M.maxCache do M.cache[table.remove(M.order,1)]=nil end
  return true
 end,{module=consumer,onCancel=finished})
 if not ok then finished();return nil,'Dossier queue busy' end
 return entry and entry.model,entry and 'refreshing' or 'Preparing dossier'
end
function M.GetActivityPage(key,owner)
 if ns.AetherNet.Subject('EVENT',key) then
  if not ns.Membership.Allowed() then return nil,'Access or module unavailable' end
  local v=ns.AetherNet.ReadSubject('EVENT',key);local e=v.event
  if not e then return nil,'Shared event unavailable' end
  local people={};for _,guid in ipairs(e.participants) do local identity=ns.AetherNet.ReadSubject('CHARACTER',guid).identity;people[#people+1]={key=guid,title=identity.name or 'Resolved participant',identity=identity,state='shared'} end
  local outcome=({final_encounter_won='Final encounter reported won',full_clear='Attested complete event',partial='Partial event',unknown='Outcome unknown'})[e.outcome] or 'Conflicting outcome'
  return {kind='activity',key=key,owner=owner or ns.Chronicle.Owner(),category=e.activityType,title=e.name or 'Shared event',status=outcome,firstAt=e.startAt,lastAt=e.endAt,endAt=e.endAt,sourceState='shared',eventRef={key=key,type='EVENT',verified=e.verified,scope=e.scope},attemptCount=0,participants=people,encounters={},quests={},loot={},timeline={},boards={},combat={},combatSummary={},related={},sections={},metrics={},measuredSeconds={},adventureSummary=ns.AthenaAdventureSummary.Shared(e),summary=ns.AthenaAdventureSummary.Shared(e).text,coverage={'Shared with permission · separate from your own adventure history','Participant identifiers were separately authorized; attendance at each boss remains unknown.'}}
 end
 return get('activity',key,owner)
end
function M.GetPlayerPage(key,owner,asOf)
 if not ns.Membership.Allowed() then return nil,'Access or module unavailable' end
 return get('player',key,owner,asOf)
end
function M.GetGroupPage(generation,resultID,adapter,viewer)
 M.lastError=nil;adapter=adapter or ns.AthenaNativeLFGAdapter.Current
 if not ns.Athena2.Permit('intel') then return nil,'Access or module unavailable' end
 local listing=adapter:Get(tostring(generation)..':'..tostring(resultID))
 if not listing then return nil,'Listing expired or unavailable' end
 return {kind='group',key=listing.key,title=listing.title or listing.activityName,listing=listing,match=ns.AthenaGroupMatch.Score(viewer or ns.Fellowship.Context(),listing),sourceState=listing.source:find('SYNTHETIC',1,true) and 'synthetic' or 'recorded',members=listing.members,native='NATIVE-PENDING'}
end
function M.Browse(kind,owner,query)
 local consumer=kind=='player' and 'intel' or 'chronicle'
 if not ns.Athena2.Permit(consumer) then return nil,'Access or module unavailable' end
 local st,state=A.Request(owner or ns.Chronicle.Owner());if not st then return nil,state end
 if kind~='player' then local rows,pending=ns.AthenaProfiles.Experiences(st,{search=query,limit=120});return rows,rows and st or pending end
 local out={};query=(query or ''):lower()
 for guid,p in pairs(st.players) do local name=Name(st,guid);if query=='' or name:lower():find(query,1,true) then out[#out+1]={key=guid,title=name,owner=st.owner};if #out>=120 then break end end end
 table.sort(out,function(x,y) return x.title<y.title end);return out,st
end
function M.Clear()
 local jobs=M.jobs;M.jobs={};M.pending={}
 for key in pairs(jobs) do ns.WardenScheduler.Cancel(key) end
 M.cache={};M.order={};M.errors={};M.lastError=nil
 M.combatCache={};M.combatPending={}
end
function M.CombatEvidence(model,filter,page)
 if not ns.Athena2.Permit('intel') then return nil,'Combat evidence access unavailable.' end
 local st=model._sourceState;if not st or st.owner~=model.owner then return {rows={},more=false},'No retained source index.' end
 page=math.max(0,math.min(10000,math.floor(tonumber(page) or 0)));filter=filter or 'all'
 local key=model.owner..'/'..model.key..'/'..filter..'/'..page..'/'..tostring(st.revision)
 M.combatCache=M.combatCache or {};M.combatPending=M.combatPending or {}
 if M.combatCache[key] then return M.combatCache[key] end
 if M.combatPending[key] then return nil,'Preparing player-scoped evidence…' end
 if count(M.combatCache)>=24 then M.combatCache={} end
 local data=st.intelligence;local p=data and data.players[model.key];local refs=p and p.evidence or {}
 local revision=st.revision;local result={rows={},more=false,filter=filter,page=page,owner=model.owner,guid=model.key};local scanned,matched=0,0
 local co=coroutine.create(function()
  for i=#refs,1,-1 do local e=data.events[refs[i]] or st.events[refs[i]];local category=e and ns.IntelCombatUI.Category(e)
   if category and (not ns.AthenaHistoryGraph or ns.AthenaHistoryGraph.CanRead('intel',e)) and (filter=='all' or filter==category) then matched=matched+1;if matched>page*50 then result.rows[#result.rows+1]=e;if #result.rows==51 then result.rows[51]=nil;result.more=true;break end end end
   scanned=scanned+1;if scanned%128==0 then coroutine.yield() end
  end
 end)
 M.jobSerial=M.jobSerial+1;local job='ui2 combat/'..M.jobSerial;M.jobs[job]=true;M.combatPending[key]=true
 local function finish() M.jobs[job]=nil;M.combatPending[key]=nil end
 local ok=ns.WardenScheduler.Submit(job,'interactive',function()
  if st.revision~=revision or not st.asOf and ns.ChronicleActivities.Peek(model.owner)~=st then finish();return true end
  local resumed,why=coroutine.resume(co)
  if not resumed then result.error=tostring(why);finish();M.combatCache[key]=result;return true end
  if coroutine.status(co)~='dead' then return false end
  finish();M.combatCache[key]=result
  if ns.UI2.route and ns.UI2.route.key==model.key and ns.UI2.route.owner==model.owner then ns.UI2.Refresh(true) end
  return true
 end,{module='intel',onCancel=finish})
 if not ok then finish();return nil,'Evidence queue busy; retry.' end
 return nil,'Preparing player-scoped evidence…'
end

function M.GetGuildPage(key,owner)
 owner=owner or ns.Chronicle.Owner();if not ns.Membership.Allowed() or not ns.Athena2.Permit('intel') then return nil,'Access or module unavailable' end
 local c=ns.AetherNet.Cached()
 local public=c and c.options.identity('GUILD',key) and ns.AetherNet.ReadSubject('GUILD',key)
 local v,why
 if ns.Membership.LocalHistoryAllowed() then v,why=ns.AthenaHistoryGraph.ResolveGuild(key,owner) end
 if v then
  local st,status=A.Request(owner)
  local result=ns.Athena.Copy(v);result.events={};local seen={};result.aetherNet=public;result.publicSubjectType='GUILD'
  -- An empty community projection must not replace recorded guild identity,
  -- members and adventures. The same profile composes both existing sources.
  if public then result.rating=public.rating;result.guildzone=public.guildzone or result.guildzone end
  if st then for _,source in ipairs(v.sources) do for id in pairs(st.links[source.id] or {}) do local a=A.View(st,id);if a and not seen[a.id] and ns.AthenaProfiles.IsAdventure(a) then seen[a.id]=true;result.events[#result.events+1]={key=a.id,name=M.Title(a),scope='Observed guild activity',owner=owner,localActivity=true} end end end end
  local members={};for _,member in ipairs(result.members) do members[member.key]=true end
  for _,member in ipairs(public and public.members or {}) do if not members[member.key] then members[member.key]=true;result.members[#result.members+1]=ns.Athena.Copy(member) end end
  for _,event in ipairs(public and public.events or {}) do if not seen[event.key] then seen[event.key]=true;result.events[#result.events+1]=ns.Athena.Copy(event) end end
  return result,not st and 'refreshing' or nil
 end
 if public then public.kind='guild';public.owner=owner;public.title=public.identity.name or 'Guild Profile';public.aetherNet=ns.AetherNet.ReadSubject('GUILD',key);public.publicSubjectType='GUILD';return public,why=='INDEXING'and 'refreshing'or nil end
 return nil,why or 'Guild source unavailable'
end
