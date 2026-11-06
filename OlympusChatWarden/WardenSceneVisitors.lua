-- Private scenic recollections of captured people. No writes to evidence,
-- friends, profiles, publications or SavedVariables; presence here proves nothing.
local _,ns=...
local V={MAX_CANDIDATES=256,MAX_VISITORS=2,SCAN_SLICE=64};ns.WardenSceneVisitors=V
local N=ns.WardenNativeScene
local function integer(v,lo,hi)return type(v)=='number'and v==math.floor(v)and v>=lo and v<=hi end
local function eligible()
 return ns.Permissions and ns.Permissions.Decide('UIAccess')and ns.Chronicle and ns.Chronicle.IntelEnabled()
end
local function priority(guid)
 return ns.AthenaEnrichment and ns.AthenaEnrichment.Watched(guid)
  or ns.AthenaSocial and ns.AthenaSocial.Friend(guid)
  or ns.IntelPolicy and ns.IntelPolicy.EarnedTier(guid)==1
end
function V.Body(values)
 if type(values)~='table'or not ns.ChronicleStore.GUID(values.guid)then return end
 local display=values.nativeDisplayID -- transient transforms are not a person's base body
 if not integer(display,1,1000000000)then display=nil end
 local race=integer(values.raceID,1,1000)and values.raceID or nil
 local sex=(values.sex==2 or values.sex==3)and values.sex or nil
 if not display and not(race and sex)then return end
 return{guid=values.guid,raceID=race,sex=sex,nativeDisplayID=display}
end
function V.Gear(values,guid)
 if type(values)~='table'or values.guid~=guid or type(values.slots)~='table'then return end
 local rows={}
 for i=1,19 do local row=values.slots[i]
  if type(row)=='table'and row[1]==i and(row[2]=='present'or row[2]=='pending')and integer(row[3],1,1000000000)then
   local id,link=ns.ChronicleSource.ItemIdentity(row[3],row[4]);if id then rows[#rows+1]={i,row[2],id,link or false}end
  end
 end
 return rows
end
function V.Create(realm,scene)
 local m={clock=0,candidates={},count=0,recent={},slots={},nextArrival=2,metrics={scanned=0,arrivals=0,departures=0,unsupported=0},status='Reading existing private appearance captures'}
 local seed=math.floor((type(GetTime)=='function'and GetTime()or 1)*1000)%2147483646+1
 function m:Random(lo,hi)seed=seed*48271%2147483647;return lo+(hi-lo)*seed/2147483647 end
 function m:Clear()
  for _,a in pairs(self.slots)do scene.native:Retire(a);if scene.shadows[a.id]then scene.shadows[a.id]:Hide()end end
  self.slots={};self.candidates={};self.recent={};self.failures=nil;self.count=0;self.character=nil;self.events=nil;self.owner=nil;self.scan=0;self.status='Private visitor projection cleared'
 end
 function m:CheckPrivacy()
  if self.character and(not eligible()or self.owner~=ns.Chronicle.Owner()or ns.ChronicleStore.Character(self.owner,false)~=self.character or self.character.events~=self.events)then self:Clear();return false end
  return true
 end
 function m:Scan()
  if not eligible()then self:Clear();return false end
  local owner,selfGUID=ns.Chronicle.Owner();local c=ns.ChronicleStore.Character(owner,false)
  if not c or type(c.events)~='table'then self:Clear();return false end
  if self.character~=c or self.events~=c.events or self.owner~=owner or #c.events<(self.eventCount or 0)then
   self:Clear();self.character=c;self.owner=owner;self.selfGUID=selfGUID;self.events=c.events;self.scan=#c.events;self.eventCount=#c.events
  elseif #c.events>self.eventCount then self.scan=#c.events;self.eventCount=#c.events end
  for _=1,V.SCAN_SLICE do
   if self.scan<=0 then break end;local e=c.events[self.scan];self.scan=self.scan-1;self.metrics.scanned=self.metrics.scanned+1
   local cap=type(e)=='table'and e.capture;local values=cap and cap.values;local guid=values and values.guid
   if type(values)=='table'and guid~=self.selfGUID and ns.ChronicleStore.GUID(guid)and(cap.family=='appearance'or cap.family=='gear')then
    local row=self.candidates[guid]
    if not row and self.count>=V.MAX_CANDIDATES and priority(guid)then
     for key,r in pairs(self.candidates)do if not priority(key)and not r.active then self.candidates[key]=nil;self.count=self.count-1;break end end
    end
    if not row and self.count<V.MAX_CANDIDATES then row={guid=guid};self.candidates[guid]=row;self.count=self.count+1 end
    if row then local time=type(e.at)=='number'and e.at or 0
     if cap.family=='appearance'and(not row.appearanceAt or time>row.appearanceAt)then
      local body=V.Body(values);if body then row.body=body;row.appearanceAt=time;row.appearanceRef=e.id end
     elseif cap.family=='gear'and(not row.gearAt or time>row.gearAt)then row.gear=V.Gear(values,guid);row.gearAt=time;row.gearRef=e.id end
    end
   end
  end
  return true
 end
 function m:Pick()
  local preferred,others={},{}
  for guid,row in pairs(self.candidates)do if row.body and not row.active and(self.clock>=(row.retryAt or 0))then
   local list=priority(guid)and preferred or others;list[#list+1]=row
  end end
  -- Existing important/friend captures outrank random remembered people.
  -- A currently active important person still prevents unrelated fallback.
  local hasPreferred=#preferred>0
  if not hasPreferred then for guid,row in pairs(self.candidates)do if row.body and priority(guid)and not row.unsupported then hasPreferred=true;break end end end
  local list=hasPreferred and preferred or others;if #list==0 then return end
  table.sort(list,function(a,b)return a.guid<b.guid end)
  return list[math.min(#list,math.floor(self:Random(1,#list+1)))]
 end
 function m:Portal(side)
  -- The endpoint is genuinely outside the same native viewport, not a fade.
  return N.AuthoredFloorPoint(scene.native.frame,scene.shot,side<0 and-.22 or 1.22,.69,0)
 end
 function m:Route(a,x,y,phase,portal)
  local nav,why=realm:GroundNavigation(scene,a);if not nav then a.motionStatus=why;return false end
  if portal then local base={};for k,v in pairs(nav.base or nav)do base[k]=v end;base.polygon=nil;base.boundary=nil;base.base=nil;nav=N.PeopleNavigation(base,scene.native,a)end -- only entry/exit may leave the visible floor
  local path;path,why=N.WalkPath(a.position,x,y,nav)
  if not path then a.motionStatus=why;return false end
  local ok;ok,why=scene.native:Route(a,path,N.WalkDuration(a,path),4,nav)
  if ok then a.visit.phase=phase;a.motionStatus='Private remembered visitor · '..phase else a.motionStatus=why end
  return ok
 end
 function m:Depart(a)
  local x,y=self:Portal(a.visit.side);if not x then return false end
  return self:Route(a,x,y,'leaving',true)
 end
 function m:Retire(a,failed)
  local row=self.candidates[a.spec.rememberedGUID]
  if row then row.active=nil;row.retryAt=self.clock+(failed and 300 or 90);row.unsupported=failed or nil end
  self.recent[#self.recent+1]=a.spec.rememberedGUID;if #self.recent>16 then table.remove(self.recent,1)end
  if failed then self.failures=self.failures or{};self.failures[#self.failures+1]={guid=a.spec.rememberedGUID,reason=a.motionStatus or a.status};if #self.failures>8 then table.remove(self.failures,1)end end
  scene.native:Retire(a);self.slots[a.id]=nil;if scene.shadows[a.id]then scene.shadows[a.id]:Hide()end
  self.nextArrival=self.clock+self:Random(15,45);self.metrics.departures=self.metrics.departures+1
 end
 function m:Ready(a)
  if not a.spec.socialVisitor then return end
  if not a.capabilities[4]then self.metrics.unsupported=self.metrics.unsupported+1;self:Retire(a,true);return end
  local x,y=N.AuthoredFloorPoint(scene.native.frame,scene.shot,a.visit.side<0 and .22 or .78,.69,0)
  if not x or not self:Route(a,x,y,'entering',true)then self:Retire(a,true)end
 end
 function m:Ended(a)
  if not a.spec.socialVisitor or not a.visit then return end
  local visit=a.visit
  if visit.phase=='leaving'then self:Retire(a);return end
  if visit.phase=='to-fire'then
   realm:SeatPlayer(scene,a,{kind='fire',id='firepit',animation=97});visit.phase='seated';visit.next=self.clock+self:Random(18,36)
  else visit.phase='rest';visit.next=self.clock+self:Random(4,12)end
 end
 function m:Advance(dt)
  if not self:Scan()then return end
  self.clock=self.clock+dt
  for _,a in pairs(self.slots)do
   if a.failed then self.metrics.unsupported=self.metrics.unsupported+1;self:Retire(a,true)
   elseif a.ready and a.visit and not a.route then local visit=a.visit
    if a.seating then
     if a.seating.phase=='hold'and self.clock>=visit.next then realm:LeavePlayerSeat(scene,a);visit.phase='standing'end
    elseif self.clock>=(visit.next or 0)then
     if self.clock>=visit.leaveAt then
      if not self:Depart(a)then visit.next=self.clock+10 end
     else
      local nav=realm:GroundNavigation(scene,a);local path
      if nav and a.capabilities[97]and not visit.sat then path=realm:FirePath(scene,a,nav)end
      if path and scene.native:Route(a,path,N.WalkDuration(a,path),4,nav)then visit.phase='to-fire';visit.sat=true
      else
       local x,y=N.AuthoredFloorPoint(scene.native.frame,scene.shot,self:Random(.28,.73),self:Random(.63,.81),0)
       if not x or not self:Route(a,x,y,'roaming')then visit.next=self.clock+8 end
      end
     end
    end
   end
  end
  if self.clock<self.nextArrival then return end;self.nextArrival=self.clock+self:Random(15,45)
  local slot;for i=1,V.MAX_VISITORS do local id='visitor-'..i;if not self.slots[id]then slot=id;break end end;if not slot then return end
  local row=self:Pick();if not row then self.status='No additional usable captured people; no generic substitutes';return end
  local side=self:Random(0,1)<.5 and-1 or 1;local x,y=self:Portal(side);if not x then self.status='Waiting for native entrance projection';return end
  local shared=ns.WardenAppearance.Shared(row.guid);local body=row.body;local gear=row.gear
  if shared then body={guid=row.guid,raceID=shared.raceID,sex=shared.sex,nativeDisplayID=shared.nativeDisplayID};gear={};for _,item in ipairs(shared.slots)do gear[#gear+1]={item[1],item[2],item[3],false}end end
  local spec={id=slot,socialVisitor=true,rememberedGUID=row.guid,appearance=body,displayID=body.nativeDisplayID,gear=gear,appearanceSource=shared and'Authenticated owner-shared appearance'or'Private observation',
   height=1.85,at={x,y,0},animations={0,4,96,97,98},navigationRadius=.40}
  local a=scene.native:Reuse(spec);if not a then row.retryAt=self.clock+300;return end
  a.visit={phase='loading',side=side,leaveAt=self.clock+self:Random(75,150),next=self.clock+2};row.active=true;self.slots[slot]=a
  self.metrics.arrivals=self.metrics.arrivals+1;self.status='Private captured visitors; not proof of online presence or an actual visit'
 end
 function m:Report()
  self:CheckPrivacy()
  local out={status=self.status,indexedCandidates=self.count,scanRemaining=self.scan or 0,metrics=self.metrics,failures=self.failures,limit=V.MAX_VISITORS,active={},privacy='Private scenic projection only; no evidence or publication',likeness='Captured body/gear; uncaptured face and hair are unknown'}
  for _,a in pairs(self.slots)do out.active[#out.active+1]={guid=a.spec.rememberedGUID,phase=a.visit and a.visit.phase,status=a.status}end
  return out
 end
 return m
end
