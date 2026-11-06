-- A bounded session roster keyed by observed GUID, independent of room/model slots.
-- Remembered projections are not connected visitors or proof of live presence.
local _,ns=...;local V,N,S=ns.WardenSceneVisitors,ns.WardenNativeScene,ns.WardenWorldScenes
V.MAX_VISITORS=10;V.VERSION=81
local create=V.Create
local function important(guid)
 return ns.AthenaEnrichment and ns.AthenaEnrichment.Watched(guid)or ns.AthenaSocial and ns.AthenaSocial.Friend(guid)or ns.IntelPolicy and ns.IntelPolicy.EarnedTier(guid)==1
end
function V.Create(realm,initial)
 local m=create(realm,initial);m.scene=initial;m.entities={};m.entityCount=0;m.rosterSlots={};m.reservations={};m.nextArrival=2
 local function public(key)return S.population and S.population[key]end
 local function actorCopy(a)return a.position and{unpack(a.position)}end
 function m:Release(a)
  local state=a and a.visit
  if state and state.reservation and self.reservations[state.reservation]==state.entityID then self.reservations[state.reservation]=nil;state.reservation=nil end
 end
 function m:Clear()
  local function clear(a,room)
   a.layerRestore=nil;if not a.retired then a.engine:Retire(a)end
   if a.visit or a.spec.rememberedGUID then a.visit=nil;a.spec={id=a.id,socialVisitor=true}end
   if room.shadows[a.id]then room.shadows[a.id]:Hide()end
  end
  for _,a in pairs(self.slots)do clear(a,self.scene)end
  for _,room in ipairs(realm:Scenes())do for _,a in ipairs(room.native.order or{})do if a.spec.socialVisitor then clear(a,room)end end end
  self.slots={};self.entities={};self.rosterSlots={};self.reservations={};self.entityCount=0;self.candidates={};self.count=0;self.recent={};self.character=nil;self.events=nil;self.owner=nil;self.scan=0;self.failures=nil;self.status='Private population cleared'
 end
 function m:Pick()
  local preferred,other={},{}
  for guid,row in pairs(self.candidates)do if row.body and not row.active and self.clock>=(row.retryAt or 0)then local list=important(guid)and preferred or other;list[#list+1]=row end end
  local list=#preferred>0 and preferred or other;if #list==0 then return end
  table.sort(list,function(a,b)return a.guid<b.guid end);return list[math.min(#list,math.floor(self:Random(1,#list+1)))]
 end
 function m:SceneChanged(room)
  if self.scene==room then return end
  for _,a in pairs(self.slots)do local state=a.visit
   if state then
    state.pose=actorCopy(a);state.yaw=a.yaw or 0;state.actor=nil;state.next=math.max(self.clock+2,state.next or 0)
    if a.seating then state.pose={unpack(a.seating.approach)};state.phase='rest' end
    self:Release(a);a.layerRestore=nil;a.engine:Retire(a);if self.scene.shadows[a.id]then self.scene.shadows[a.id]:Hide()end
   end
  end
  self.slots={};self.scene=room
 end
 function m:Portal(state)
  local room=self.scene;local definition=public(room.key);if not definition then return end
  if definition.gates then
   local gate=definition.gates[state.gate or 1];local x,y=N.AuthoredFloorPoint(room.native.frame,room.shot,gate.concealed[1],gate.concealed[2],0);return x,y,gate
  end
  return N.AuthoredFloorPoint(room.native.frame,room.shot,state.side<0 and-.22 or 1.22,.69,0)
 end
 function m:Route(a,x,y,phase,portal,wide)
  local room=self.scene;local state=a.visit;local nav,why
  if portal then local _,_,gate=self:Portal(state)
   nav,why=ns.WardenSceneNavigation81.PortalNavigation(realm,room,a,portal==true and gate and gate.ignore or nil,wide or(room.key=='hall'and{-.5,.55,1.5,.985}or nil))
  else nav,why=realm:GroundNavigation(room,a)end
  if not nav then a.motionStatus=why;return false end
  local path;path,why=N.WalkPath(a.position,x,y,nav);if not path then a.motionStatus=why;return false end
  local ok;ok,why=a.engine:Route(a,path,N.WalkDuration(a,path),4,nav)
  if ok then state.phase=phase;state.goal={x,y,0};state.next=self.clock+3;a.motionStatus='Remembered character · '..phase else a.motionStatus=why end
  return ok,why
 end
 function m:Ready(a)
  if not a.spec.socialVisitor or not a.visit or a.layerRestore then return end
  local state=a.visit
  if not a.capabilities[4]then self.metrics.unsupported=self.metrics.unsupported+1;self:Retire(a,true);return end
  if state.pose then
   a.engine:Place(a,state.pose[1],state.pose[2],state.pose[3],state.yaw or 0);state.pose=nil
   if state.phase=='entering'or state.phase=='leaving'then local goal=state.goal;local definition=public(self.scene.key);local exit=state.phase=='leaving'and definition and definition.exitEndUV
    if goal and self:Route(a,goal[1],goal[2],state.phase,exit and'exit'or true,exit and{.015,.40,.985,1.40}or nil)then return end
   end
   state.phase='rest';state.next=self.clock+self:Random(2,7);return
  end
  local _,_,gate=self:Portal(state)
  if gate and ns.WardenSceneLayers81 and(a.renderLayer or'native')~='portal-native'and not state.emerged then
   if ns.WardenSceneLayers81.Stage(realm,a,'portal-native')then return end
  end
  local u,v=gate and gate.floor[1]or(state.side<0 and .22 or .78),gate and gate.floor[2]or .69
  local x,y=N.AuthoredFloorPoint(self.scene.native.frame,self.scene.shot,u,v,0)
  if not x or not self:Route(a,x,y,'entering',true)then self:Retire(a,true)end
 end
 function m:Materialize(state)
  local room=self.scene;if state.room~=room.key or not public(room.key)or not room.active or not room.native.frame then return false end
  local row=self.candidates[state.guid];if not row or not row.body then return false end
  local x,y;if state.pose then x,y=state.pose[1],state.pose[2]else x,y=self:Portal(state)end
  if not x then return false end
  local shared=ns.WardenAppearance.Shared(row.guid);local body=row.body;local gear=row.gear
  if shared then body={guid=row.guid,raceID=shared.raceID,sex=shared.sex,nativeDisplayID=shared.nativeDisplayID};gear={};for _,item in ipairs(shared.slots)do gear[#gear+1]={item[1],item[2],item[3],false}end end
  local spec={id=state.slot,sceneEntityID=state.entityID,entityKind='remembered-character',socialVisitor=true,rememberedGUID=row.guid,appearance=body,displayID=body.nativeDisplayID,gear=gear,
   appearanceSource=shared and'Authenticated owner-shared appearance'or'Private observation',height=1.85,at={x,y,0},animations={0,4,96,97,98,102,103,104},navigationRadius=.40}
  local a=room.native:Reuse(spec);if not a then return false end
  a.visit=state;state.actor=a;self.slots[a.id]=a;return true
 end
 function m:Retire(a,failed)
  local state=a.visit;local row=self.candidates[a.spec.rememberedGUID];self:Release(a)
  if row then row.active=nil;row.retryAt=self.clock+(failed and 180 or 60);row.unsupported=failed or nil end
  if state then self.entities[state.guid]=nil;self.rosterSlots[state.slot]=nil;self.entityCount=math.max(0,self.entityCount-1);state.actor=nil end
  if failed then self.failures=self.failures or{};self.failures[#self.failures+1]={guid=a.spec.rememberedGUID,reason=a.motionStatus or a.status};if #self.failures>12 then table.remove(self.failures,1)end end
  a.layerRestore=nil;a.engine:Retire(a);self.slots[a.id]=nil;if self.scene.shadows[a.id]then self.scene.shadows[a.id]:Hide()end;self.metrics.departures=self.metrics.departures+1
 end
 function m:Depart(a)
  local definition=public(self.scene.key);local link=definition and ns.WardenRoomCatalogue.Connection(definition.exit,self.scene.key)
  local x,y;local phase='leaving'
  if link and link.portal then local uv=definition.exitEndUV or link.portal.approachUV;x,y=N.AuthoredFloorPoint(self.scene.native.frame,self.scene.shot,uv[1],uv[2],0);a.visit.destination=link.to
  else x,y=self:Portal(a.visit)end
  self:Release(a);return x and self:Route(a,x,y,phase,definition and definition.exitEndUV and'exit'or false,definition and definition.exitEndUV and{.015,.40,.985,1.40}or nil)or false
 end
 function m:Ended(a)
  if not a.spec.socialVisitor or not a.visit then return end;local state=a.visit
  if state.phase=='leaving'then
   self.metrics.roomDepartures=(self.metrics.roomDepartures or 0)+1
   self:Release(a);state.pose=nil;state.goal=nil;state.actor=nil;state.phase='travelling';state.arrivalAt=self.clock+self:Random(12,25)
   a.layerRestore=nil;a.engine:Retire(a);self.slots[a.id]=nil;if self.scene.shadows[a.id]then self.scene.shadows[a.id]:Hide()end;return
  end
  if state.phase=='to-object'and state.intent then
   if realm:SeatPlayer(self.scene,a,state.intent)then state.phase='seated';state.next=self.clock+self:Random(18,48);return end
  end
  if state.phase=='entering'then self.metrics.roomArrivals=(self.metrics.roomArrivals or 0)+1 end
  state.emerged=true;state.phase='rest';state.goal=nil;state.next=self.clock+self:Random(5,15);a.engine:Animate(a,0,1)
 end
 function m:PublicObject(a)
  local room=self.scene;local state=a.visit;local candidates={}
  for _,spec in ipairs(S.Props(room))do local prop=room.native.actors[spec.id]
   if prop and prop.ready and not(prop.editorHidden or prop.retired)and(spec.interaction=='chair'or spec.interaction=='fire')then candidates[#candidates+1]=prop end
  end
  if #candidates==0 then return false end
  local prop=candidates[math.min(#candidates,math.floor(self:Random(1,#candidates+1)))];local kind=prop.spec.interaction
  local reservation=room.key..'/'..prop.id
  if kind=='chair'then
   if self.reservations[reservation]then return false end
   for _,other in ipairs(room.native.order)do if other~=a and other.seating and other.seating.id==prop.id then return false end end
  end
  local animation=kind=='fire'and a.capabilities[97]and 97
  if kind=='chair'then for _,id in ipairs({102,103,104})do if a.capabilities[id]then animation=id;break end end end
  if not animation then return false end
  local nav=realm:GroundNavigation(room,a);if not nav then return false end
  local best
  if kind=='fire'then best=realm:FirePath(room,a,nav)
  else
   local box=N.Footprint(room.shot,prop);if not box then return false end;local p=prop.position;local margin=nav.radius+.20
   for _,point in ipairs({{box.left-margin,p[2]},{box.right+margin,p[2]},{p[1],box.near-margin},{p[1],box.far+margin}})do
    local path=N.WalkPath(a.position,point[1],point[2],nav);if path and(not best or path.length<best.length)then best=path end
   end
  end
  if not best then return false end
  local ok=a.engine:Route(a,best,N.WalkDuration(a,best),4,nav)
  if ok then state.phase='to-object';state.intent={id=prop.id,kind=kind,animation=animation};if kind=='chair'then self.reservations[reservation]=state.entityID;state.reservation=reservation end end
  return ok
 end
 function m:Advance(dt)
  self.clock=self.clock+dt
  if self.clock>=(self.scanAt or 0)then self.scanAt=self.clock+.10;if not self:Scan()then return end end
  local room=realm:ActiveRoom();if self.scene~=room then self:SceneChanged(room)end
  if room.definition and room.definition.nativeObjectsPaused then return end
  if not self.character then return end
  -- One actor decision/route plan per .15 s, rather than ten graph builds/frame.
  if self.clock<(self.planAt or 0)then return end;self.planAt=self.clock+.15
  for _,state in pairs(self.entities)do
   if state.phase=='travelling'and self.clock>=state.arrivalAt then
    state.room=state.destination or'square';state.destination=nil;state.phase='loading';state.emerged=nil;state.pose=nil
    state.gate=math.min(3,math.floor(self:Random(1,4)));state.leaveAt=self.clock+self:Random(150,360)
   elseif state.room~=room.key and state.phase~='travelling'and self.clock>=state.leaveAt then
    local definition=public(state.room);local link=definition and ns.WardenRoomCatalogue.Connection(definition.exit,state.room)
    if link then state.destination=link.to;state.phase='travelling';state.pose=nil;state.arrivalAt=self.clock+self:Random(20,45)end
   end
   if state.room==room.key and not state.actor and state.phase~='travelling'then if self:Materialize(state)then return end end
  end
  self.decision=(self.decision or 0)%V.MAX_VISITORS+1
  local a=self.slots['visitor-'..self.decision]
  if a then
   if a.failed then self.metrics.unsupported=self.metrics.unsupported+1;self:Retire(a,true);return end
   local state=a.visit
   if a.ready and state and not a.route and not a.layerRestore then
    if a.seating then
     if a.seating.phase=='hold'and self.clock>=state.next then realm:LeavePlayerSeat(room,a);self:Release(a);state.phase='standing'end
    elseif self.clock>=(state.next or 0)then
     self:Release(a)
     if self.clock>=state.leaveAt then if not self:Depart(a)then state.next=self.clock+10 end
     elseif self:Random(0,1)<.45 and self:PublicObject(a)then
     else
      local targets=public(room.key)and public(room.key).destinations
      local point=targets and targets[math.min(#targets,math.floor(self:Random(1,#targets+1)))];local x,y
      if point then x,y=N.AuthoredFloorPoint(room.native.frame,room.shot,point[1],point[2],0)end
      if not x or not self:Route(a,x,y,'roaming')then state.next=self.clock+self:Random(4,10)end
     end
    end
   end
  end
  if self.entityCount>=V.MAX_VISITORS or self.clock<self.nextArrival then return end
  self.nextArrival=self.clock+self:Random(8,18);local row=self:Pick()
  if not row then self.status='No additional captured appearances; no duplicate or generic substitutes';return end
  local slot;for i=1,V.MAX_VISITORS do if not self.rosterSlots['visitor-'..i]then slot='visitor-'..i;break end end;if not slot then return end
  local state={entityID='remembered/'..row.guid,guid=row.guid,slot=slot,room=public(room.key)and room.key or'square',side=self:Random(0,1)<.5 and-1 or 1,
   gate=math.min(3,math.floor(self:Random(1,4))),phase='loading',leaveAt=self.clock+self:Random(150,360),next=self.clock+2}
  row.active=true;self.entities[row.guid]=state;self.rosterSlots[slot]=state;self.entityCount=self.entityCount+1;self.metrics.arrivals=self.metrics.arrivals+1
  self:Materialize(state);self.status='Stable remembered characters across public rooms; not live presence'
 end
 function m:Report()
  self:CheckPrivacy();local out={version=81,status=self.status,indexedCandidates=self.count,scanRemaining=self.scan or 0,limit=V.MAX_VISITORS,population=self.entityCount,active={},entities={},metrics=self.metrics,failures=self.failures,
   identity='Namespaced observed GUID; model slots are not identity. Canonical player state is separate.',privacy='Private scenic projections; no presence, publication or new saved history'}
  for _,state in pairs(self.entities)do out.entities[#out.entities+1]={id=state.entityID,guid=state.guid,room=state.room,phase=state.phase,slot=state.slot};if state.actor and state.actor.ready and not state.actor.retired then out.active[#out.active+1]={guid=state.guid,phase=state.phase,status=state.actor.status,entityID=state.entityID}end end
  table.sort(out.entities,function(a,b)return a.id<b.id end);return out
 end
 return m
end
