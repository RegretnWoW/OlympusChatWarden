-- One rebuildable lifecycle over retained observations. No new source archive.
local _,ns=...
local R={VERSION=1,RETURN_SECONDS=1800,RELOAD_SECONDS=300};ns.ChronicleRuns=R
local instanceKinds={party='dungeon',raid='raid',pvp='battleground',arena='arena'}
-- These explicit aggregate diagnostics report missing optional fields, not
-- absence of the recorder or a departure from the instance. Preserve the
-- warning as evidence without discarding the observed run/return anchor.
local optionalFamilies={['Adventure summaries']=true,['Combat effects']=true,['Cast counts']=true,
 ['Battleground scores']=true,['Own spell counts']=true,['Boss status']=true,
 ['Native reader']=true,['Own-character detail']=true}
function R.OptionalCoverageGap(e)
 local d=e and e.details
 if not e or e.kind~='collection_gap' or not d then return false end
 if e.source=='control' and optionalFamilies[d.family]==true and type(d.coverage)=='string' then return true end
 -- A missing coordinate sample does not erase native entry, roster or boss
 -- signals. Its unmeasured time stays unknown in the separate time index.
 return e.source=='checkpoint' and ({['coordinates-unavailable']=true,
  ['map-or-instance-transition']=true,['unmeasured-sampling-gap']=true,
  ['context-changed-during-read']=true})[d.reason]==true
end
local function Key(e)
 local p=e.location or {};local kind=p.inInstance and instanceKinds[p.instanceType]
 if kind then return p.instanceType..':'..tostring(p.instanceID or '?')..':'..tostring(p.instanceName or p.zone or '?'),kind end
end
local function Root(st) st.runs=st.runs or {byID={},byAnchor={},bySegment={},list={},groupGeneration=0,index=0,lockouts={},savedInstances={},lockoutObjects={}};return st.runs end
local function Mark(s,r,e,state,reason)
 r.state=state;r.reason=reason;r.lastAt=e.at
 if state=='COMPLETED' or state=='PARTIAL' or state=='INTERRUPTED' then r.endedAt=e.at;r.endElapsed=e.elapsed;r.endRef=e.id end
 r.transitions[#r.transitions+1]={source=e.id,index=s.index,at=e.at,elapsed=e.elapsed,state=state,reason=reason,
  lastBoss=r.lastBoss,lastBossID=r.lastBossID,lastBossOutcome=r.lastBossOutcome,completionRef=r.completionRef}
end
local function Closed(r) return r and (r.state=='COMPLETED' or r.state=='PARTIAL') end
local function Separate(st,anchor)
 local prefs=ns.DB and ns.DB.activityRunSeparations
 return prefs and prefs[st.owner] and prefs[st.owner][anchor]
end
local function Attach(s,r,e)
 s.byAnchor[e.id]=r.id;r.lastAt=math.max(r.lastAt,e.at);r.lastElapsed=e.elapsed
end
local function Canonical(s,r,allowed)
 while r and r.resumeOf and (not allowed or allowed(r.resumeProof)) do r=s.byID[r.resumeOf] end
 return r
end
local function LockoutKey(name,kind,difficulty)
 return table.concat({tostring(name),tostring(kind),tostring(difficulty)},'/')
end
local function Lockout(st,s,r,entry,e)
 if not r or r.separated or not entry or r.kind~=entry.kind or entry.session~=e.session or entry.at<r.openedAt
  or entry.untilAt<=e.at or not r.difficulty or r.difficulty~=entry.difficulty then return end
 local old=s.savedInstances[entry.token];old=old and Canonical(s,s.byID[old])
 if old and old~=Canonical(s,r) and old.lockoutUntil and old.lockoutUntil>e.at
  and math.abs(old.lockoutUntil-entry.untilAt)<300 and not old.reset then
  local completed=R.AsOf(old,nil,s).state=='COMPLETED'
  r.resumeOf=old.id;r.resumeProof=entry.source;old.children=old.children or {};old.children[#old.children+1]=r.id
  if completed then r.completedSaveReturn=true end
 end
 r.lockoutEvidence=r.lockoutEvidence or {};r.lockoutEvidence[entry.source]=true
 if entry.objectSource then r.lockoutEvidence[entry.objectSource]=true end
 local root=Canonical(s,r);root.lockoutUntil=entry.untilAt;root.lockoutToken=entry.token;s.savedInstances[entry.token]=root.id
end
local function ObserveLockouts(st,s,r,rows,e,receipts)
 local candidates={}
 for i,row in ipairs(rows) do
  -- Saved IDs are distinct from map IDs. Do not guess between two saves for
  -- the same named instance, type and difficulty in one native observation.
  if type(row[1])=='string' and type(row[4])=='number'
   and (row[5]=='true' or row[5]==true) and (row[7]=='true' or row[7]==true or row[7]=='false' or row[7]==false)
   and row[11]~=true and row[11]~='true' and type(row[2])=='number' and row[2]>0 and type(row[10])=='number' and row[10]>e.at then
   local kind=(row[7]=='true' or row[7]==true) and 'raid' or 'dungeon'
   local key=LockoutKey(row[1],kind,row[4])
   local entry={token=table.concat({row[1],row[2],tostring(row[3]),tostring(row[4]),tostring(row[7])},'/'),untilAt=row[10],session=e.session,source=e.id,
    objectSource=receipts and receipts[i],kind=kind,difficulty=row[4],at=e.at}
   local old=candidates[key]
   if old==false or old and old.token~=entry.token then candidates[key]=false else candidates[key]=entry end
  end
 end
 for key,entry in pairs(candidates) do
  s.lockouts[key]=entry
  if entry and r and key==LockoutKey(r.name,r.kind,r.difficulty) then Lockout(st,s,r,entry,e) end
 end
end
local function Start(st,s,e,previous,reason)
 local key,kind=Key(e);if not key then return end
 local r=previous
 if not r then
  r={id=e.id,kind=kind,key=key,owner=st.owner,openedAt=e.at,lastAt=e.at,segments={},segmentSet={},transitions={},bosses={},deaths=0,
   group=s.groupGeneration,session=e.session,difficulty=e.sourceContext and e.sourceContext.difficultyID,
   name=(e.location or {}).instanceName or (e.location or {}).zone,separated=Separate(st,e.id) or nil,
   startObserved=e.kind=='instance_enter' and not e.details.reason}
  s.byID[r.id]=r;s.list[#s.list+1]=r
 end
 if r.state~='COMPLETED' then r.endedAt=nil;r.endElapsed=nil;r.endRef=nil end
 s.active=r;s.pending=nil;s.reload=nil;Attach(s,r,e)
 if r.state~='COMPLETED' then Mark(s,r,e,'ACTIVE',reason or 'observed entry') end
 Lockout(st,s,r,s.lockouts[LockoutKey(r.name,r.kind,r.difficulty)],e)
 return r
end
local function Endpoint(e)
 local p=e.location or {};local d=e.details
 for _,row in ipairs(ns.ChronicleRunEndpoints or {}) do if p.instanceID==row.mapID then
  local name=ns.CanRead(d.name) and d.name:gsub('’',"'"):lower()
  local expected=row.name:gsub('’',"'"):lower()
  -- IDs vary between client branches. Require the readable native identity;
  -- missing or conflicting text keeps an unsupported finishing result unknown.
  if name==expected then return row end
 end end
end
function R.Feed(st,e)
 local s=Root(st);s.index=s.index+1;local d=e.details or {};local key,kind=Key(e);local r=s.active
 if s.session and (e.session~=s.session or e.at<(s.at or 0) or e.elapsed<(s.elapsed or 0)) then
  local old=r or s.pending and s.pending.run
  if old and not Closed(old) then Mark(s,old,e,'INTERRUPTED','recording or clock boundary') end
  s.active=nil;s.pending=nil;s.reload=nil;r=nil;s.groupGeneration=s.groupGeneration+1
 end
 s.session=e.session;s.at=e.at;s.elapsed=e.elapsed
 if s.reload and e.kind~='recording_start' then s.reload=nil end
 if s.resume and not ((e.kind=='character_snapshot' or e.kind=='location' or e.kind=='instance_enter')
  and key==s.resume.key and e.source=='PLAYER_ENTERING_WORLD') then s.resume=nil end
 local window=s.pending and s.pending.run.groupSeen and s.groupPresent and 6*3600 or R.RETURN_SECONDS
 if s.pending and e.at-s.pending.at>window then
  if not Closed(s.pending.run) then Mark(s,s.pending.run,e,'PARTIAL','return window elapsed') end;s.pending=nil
 end
 if e.kind=='collection_gap' and not R.OptionalCoverageGap(e) then
  local old=r or s.pending and s.pending.run
  if old and not Closed(old) then Mark(s,old,e,'INTERRUPTED','recorded observation gap') end
  s.active=nil;s.pending=nil;s.reload=nil
 elseif e.kind=='native_event' and d.recordType=='instance_reset' then
  local old=r or s.pending and s.pending.run
  if old then
   local segment=st.byID[old.segments[#old.segments]];local p=segment and segment.context or {}
   if not d.name or d.name==p.instanceName or d.name==p.zone then
    if not Closed(old) then Mark(s,old,e,'PARTIAL','native instance reset') end;Canonical(s,old).reset=true
    s.active=nil;s.pending=nil;s.reload=nil
   end
  end
 elseif e.kind=='recording_stop' then
  local paused=s.pending and s.pending.run
  if paused and not Closed(paused) then Mark(s,paused,e,'INTERRUPTED','recording stopped while outside') end
  if r then
   if not Closed(r) then Mark(s,r,e,'INTERRUPTED','recording stopped') end
   s.reload={run=r,at=e.at,session=e.session,source=e.source,key=key}
  end
  s.active=nil;s.pending=nil
 elseif e.kind=='recording_start' then
  local reload=s.reload
  if d.reason=='ui-reload' and reload and reload.source=='PLAYER_LOGOUT' and e.source=='PLAYER_ENTERING_WORLD'
   and reload.session==e.session and e.at>=reload.at and e.at-reload.at<=R.RELOAD_SECONDS and key==reload.key then
   s.resume=reload.run
  else s.resume=nil;s.reload=nil end
 elseif e.kind=='instance_enter' or e.kind=='location' and key and not r then
  if key then
   local startup=r and key==r.key and (d.reason=='recording-started-inside' or e.at==r.lastAt and e.elapsed==r.lastElapsed)
   if startup then Attach(s,r,e)
   elseif not r or key~=r.key or e.kind=='instance_enter' then
    local previous=s.resume;s.resume=nil
    local pending=s.pending
    if not previous and pending and (kind=='dungeon' or kind=='raid') and pending.run.key==key
     and pending.run.session==e.session and pending.run.group==s.groupGeneration and not Closed(pending.run)
     and (not pending.run.difficulty or not (e.sourceContext and e.sourceContext.difficultyID) or pending.run.difficulty==e.sourceContext.difficultyID)
     and e.at>=pending.at and e.at-pending.at<=window then previous=pending.run end
    if previous and previous.lockoutToken then previous=nil end -- Wait for a fresh saved-instance receipt.
    if Separate(st,e.id) then previous=nil end
    local old=r or pending and pending.run
    if old and old~=previous and not Closed(old) then Mark(s,old,e,'PARTIAL','another activity or new run') end
    Start(st,s,e,previous,previous and 'continued after return or reload' or 'observed entry')
   end
  end
 elseif e.kind=='instance_exit' or e.kind=='location' and r and key~=r.key then
  if r and (key==r.key or e.kind=='location') then
   Attach(s,r,e)
   if not Closed(r) then
    if r.kind=='dungeon' or r.kind=='raid' then
     Mark(s,r,e,'PAUSED','left instance; return possible');s.pending={run=r,at=e.at}
    else Mark(s,r,e,'PARTIAL','left without native completion') end
   end
   s.active=nil
  end
 end
 r=s.active
 local lockoutRows,lockoutReceipts
 if e.kind=='native_snapshot' and e.capture and e.capture.family=='lockout_list' then
  local values=e.capture.values
  if d.contentID then s.lockoutObjects[d.contentID]=values end
  local count=values.instanceCount and values.worldBossCount and values.instanceCount+values.worldBossCount
  if not d.contentID or count and count<=#values.rows then lockoutRows=values.rows end
 elseif e.kind=='native_event' and d.recordType=='lockout_list_observed' then
  local values=s.lockoutObjects[d.contentID];local part,parts=d.part or 1,d.parts or 1
  if part==1 then s.lockoutBatch={session=e.session,source=e.source,parts=parts,next=1,rows={},receipts={}} end
  local batch=s.lockoutBatch
  if batch and values and batch.session==e.session and batch.source==e.source and batch.parts==parts and batch.next==part then
   for _,row in ipairs(values.rows) do batch.rows[#batch.rows+1]=row;batch.receipts[#batch.receipts+1]=e.id end
   batch.next=part+1
   if part==parts then lockoutRows=batch.rows;lockoutReceipts=batch.receipts;s.lockoutBatch=nil end
  else s.lockoutBatch=nil end
  end
 if lockoutRows then ObserveLockouts(st,s,r,lockoutRows,e,lockoutReceipts) end
 if e.kind=='group_roster' and d.rosterComplete~=false and #(d.members or {})==0 then
  if s.groupPresent then
   s.groupGeneration=s.groupGeneration+1
   local old=r or s.pending and s.pending.run
   if old and not Closed(old) then Mark(s,old,e,'PARTIAL','group disbanded') end
   s.pending=nil
  end
  s.groupPresent=false
 elseif e.kind=='group_roster' and #(d.members or {})>0 then
  s.groupPresent=true;if r and not r.groupSeen then r.group=s.groupGeneration;r.groupSeen=true end
 end
 if r and key==r.key then
  if e.kind=='player_death' then r.deaths=r.deaths+1 end
  if e.kind=='native_event' then
   if d.recordType=='match_observed' and (r.kind=='battleground' or r.kind=='arena') then
    -- Another native active notification after a completed match is a new
    -- match even when the map and current visit have not changed.
    if Closed(r) then r=Start(st,s,e,nil,'new native match') end
    Attach(s,r,e);r.matchRef=e.id
   elseif d.recordType=='pvp_match_complete' and e.source=='PVP_MATCH_COMPLETE' then
    Attach(s,r,e);r.completionRef=e.id;Mark(s,r,e,'COMPLETED','native match completion')
   elseif d.recordType=='instance_completed' and e.source=='LFG_COMPLETION_REWARD' and (r.kind=='dungeon' or r.kind=='raid') then
    Attach(s,r,e);r.completionRef=e.id;Mark(s,r,e,'COMPLETED','native instance completion')
   elseif d.recordType=='encounter_started' or d.recordType=='encounter_ended' or d.recordType=='boss_kill_event' then
    Attach(s,r,e);r.lastBoss=d.name;r.lastBossID=d.encounterID
    local won=d.recordType=='boss_kill_event' or d.recordType=='encounter_ended' and d.success==1
    r.lastBossOutcome=won and 'SUCCESS' or d.recordType=='encounter_ended' and d.success==0 and 'FAILURE' or 'OPEN'
    if won and Endpoint(e) then
     r.completionRef=e.id;Mark(s,r,e,'COMPLETED','finishing encounter defeated')
    elseif not Closed(r) then Mark(s,r,e,'ACTIVE','boss progress') end
   end
  end
 end
 -- A late PvP result requires its exact saved active-match anchor.
 if not r and e.kind=='native_event' and d.recordType=='pvp_match_complete' and e.source=='PVP_MATCH_COMPLETE' and d.matchRef then
  local id=s.byAnchor[d.matchRef];local old=id and s.byID[id]
  if old and old.session==e.session then Attach(s,old,e);old.completionRef=e.id;Mark(s,old,e,'COMPLETED','native match completion') end
 end
 return s
end
function R.Bind(st,a)
 local s=Root(st);local id=s.byAnchor[a.anchor];local r=id and s.byID[id]
 if r and ({dungeon=true,raid=true,battleground=true,arena=true})[a.kind] then
  s.bySegment[a.id]=id
  if not r.segmentSet[a.id] then r.segmentSet[a.id]=true;r.segments[#r.segments+1]=a.id end
 end
end
function R.ForSegment(st,id,allowed) local s=st and st.runs;return s and Canonical(s,s.byID[s.bySegment[id]],allowed) end
local function Related(s,run,allowed,out)
 out=out or {};out[#out+1]=run
 for _,id in ipairs(run.children or {}) do local child=s.byID[id]
  if child and (not allowed or allowed(child.resumeProof)) then Related(s,child,allowed,out) end
 end
 return out
end
function R.Segments(st,run)
 local ids={};for _,r in ipairs(Related(st.runs,run)) do for _,id in ipairs(r.segments) do ids[#ids+1]=id end end
 table.sort(ids,function(a,b) local x,y=st.byID[a],st.byID[b];return x.startAt==y.startAt and a<b or x.startAt<y.startAt end)
 return ids
end
function R.SourceRefs(st,run)
 local refs={}
 for _,r in ipairs(Related(st.runs,run)) do
  if r.resumeProof then refs[#refs+1]=r.resumeProof end
  for ref in pairs(r.lockoutEvidence or {}) do refs[#refs+1]=ref end
  for _,t in ipairs(r.transitions) do refs[#refs+1]=t.source end
 end
 return refs
end
function R.AsOf(run,allowed,store)
 local out={id=run.id,kind=run.kind,state='UNKNOWN',startObserved=run.startObserved}
 local latest=-1
 for _,r in ipairs(store and Related(store,run,allowed) or {run}) do
  local completedReturn=r.completedSaveReturn and (not allowed or allowed(r.resumeProof))
  for _,t in ipairs(not completedReturn and r.transitions or {}) do if (not allowed or allowed(t.source)) and t.index>latest then
   latest=t.index;for k,v in pairs(t) do out[k]=v end
  end end
 end
 if out.state=='COMPLETED' or out.state=='PARTIAL' or out.state=='INTERRUPTED' then out.endedAt=out.at;out.endElapsed=out.elapsed end
 -- Operational completion closes the expedition. It does not certify that
 -- every boss was defeated or that an individual earned a whole-instance clear.
 out.completionBasis=({['finishing encounter defeated']='finishing_encounter',['native instance completion']='native_completion_report',['native match completion']='match_completion'})[out.reason] or 'unknown'
 out.fullClearVerified=false
 return out
end
function R.SeparateVisits(st,a)
 if not st or not a then return end
 ns.DB.activityRunSeparations=ns.DB.activityRunSeparations or {};local all=ns.DB.activityRunSeparations
 all[st.owner]=all[st.owner] or {};local rows=a.segmentIDs or {a.id}
 if #rows==1 then all[st.owner][a.anchor]=nil
 else for i=2,#rows do local p=st.byID[rows[i]];if p then all[st.owner][p.anchor]=true end end end
end
local graphKinds={RAID_RUN=true,INSTANCE_VISIT=true,BATTLEGROUND_VISIT=true,BATTLEGROUND_MATCH=true}
function R.MapGraph(g)
 g.runNodes=g.runNodes or {};g.runForNode=g.runForNode or {}
 g.runNodeCache={}
 local s=g.activityState and g.activityState.runs
 for i=(g.runMapped or 0)+1,#g.activities do
  local n=g.activities[i];local id=s and graphKinds[n.type] and s.byAnchor[n.sourceID]
  if id then
   g.runForNode[n.activityRef]=id;local rows=g.runNodes[id] or {};g.runNodes[id]=rows;rows[#rows+1]=n.activityRef
  end
  if i%128==0 then coroutine.yield() end
 end
 g.runMapped=#g.activities
end
function R.JournalNode(g,node,extent)
 local id=g.runForNode and g.runForNode[node.activityRef]
 local store=g.activityState and g.activityState.runs
 local allowed=function(ref) return (g.positions[ref] or math.huge)<=extent end
 local run=id and Canonical(store,store.byID[id],allowed)
 if not run then return ns.Athena.Copy(node) end
 local cacheKey=run.id..'/'..extent;local cached=g.runNodeCache[cacheKey]
 if cached then return cached.last==node.activityRef and ns.Athena.Copy(cached.node) or nil end
 local first,last,aliases,count,bgMatch=nil,nil,{},0,false
 local members={}
 for _,r in ipairs(Related(store,run,allowed)) do for _,ref in ipairs(g.runNodes[r.id] or {}) do members[#members+1]=ref end end
 table.sort(members,function(a,b) return g.positions[g.byRef[a].sourceID]<g.positions[g.byRef[b].sourceID] end)
 for _,ref in ipairs(members) do local n=g.byRef[ref]
  if (g.positions[n.sourceID] or math.huge)<=extent then
   first=first or n;last=n;aliases[#aliases+1]=ref;count=count+n.sourceCount
   if n.type=='BATTLEGROUND_MATCH' then bgMatch=true end
  end
 end
 if not last then return end
 local copy=ns.Athena.Copy(first);copy.activityAliases=aliases;copy.sourceCount=count
 local cap=extent>0 and g.character.events[extent].at or copy.firstObservedAt
 copy.lastObservedAt=math.min(last.lastObservedAt,cap)
 copy.run=R.AsOf(run,allowed,store)
 copy.unknownEnd=copy.run.state~='COMPLETED' and copy.run.state~='PARTIAL'
 copy.observedEndAt=not copy.unknownEnd and copy.run.endedAt or nil
 copy.endSourceRef=not copy.unknownEnd and ns.Athena.EvidenceRef(copy.run.source) or nil
 copy.status=copy.unknownEnd and 'INCOMPLETE' or 'CLOSED'
 if bgMatch then copy.type='BATTLEGROUND_MATCH';copy.ownerResult='UNKNOWN' end
 g.runNodeCache[cacheKey]={last=last.activityRef,node=copy}
 return last.activityRef==node.activityRef and ns.Athena.Copy(copy) or nil
end
