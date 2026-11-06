-- Live is a presentation mode of the existing realm, never a second ledger.
local _,ns=...
local L,G,N,S=ns.AetherLive,ns.AetherLiveGameplay,ns.WardenNativeScene,ns.WardenWorldScenes
local W={VERSION=2,active=false,phase='private',slots={},metrics={created=0,retired=0,movements=0,rejected=0,npcPlans=0}};L.World=W
local function copy(t)return ns.WardenRoomCatalogue.Copy(t)end
local function now()return ns.SafeNumber(ns.SafeCall(GetTime))or 0 end
local function stamp()return ns.SafeNumber(ns.SafeCall(GetServerTime))or 0 end
local animations={0,4,5,52,54,96,97,98,102,103,104}
local allowedAnimation={[0]=true,[4]=true,[5]=true,[52]=true,[54]=true,[96]=true,[97]=true,[98]=true,[102]=true,[103]=true,[104]=true}
-- Official authored characters, not Athena captures. Templates and schedules
-- belong to this world revision. No NPC state is sent over the network.
W.NPCs={
 {id='bram-caskwell',name='Bram Caskwell',raceID=1,sex=2,scene='square',offset=0,points={{.68,.64},{.62,.69},{.54,.71}},wait=9},
 {id='laen-stalewind',name='Laen Stalewind',raceID=4,sex=3,scene='square',offset=19,points={{.29,.68},{.34,.72},{.47,.75}},wait=12},
 {id='jerrik-canthrel',name='Jerrik Canthrel',raceID=1,sex=2,scene='hall',offset=37,points={{.40,.76},{.55,.73},{.65,.70}},wait=11},
}
local function public(key)return G.Scenes[key]~=nil end
function W.IsPrivateActor(a)
 local s=a and a.spec
 return s and not(s.liveRemote or s.canonicalNPC)and(s.socialVisitor or s.rememberedGUID or s.entityKind=='remembered-character'or a.visit~=nil)and true or false
end
local function actorSnapshot(a)
 return{spec=copy(a.spec),ready=a.ready==true,position=a.position and copy(a.position),yaw=a.yaw,scale=a.scale,top=a.top,editorHidden=a.editorHidden,
  collider=copy(a.collider),hitbox=copy(a.hitbox),shadow=copy(a.shadow),shadowLayer=a.shadowLayer,renderLayer=a.renderLayer,retired=a.retired,
  seating=copy(a.seating),route=a.route,pendingInteraction=copy(a.pendingInteraction),worldYaw=a.worldYaw}
end
local function retire(scene,a)
 if not a or a.retired then return end;(a.engine or scene.native):Retire(a);if scene.shadows[a.id]then scene.shadows[a.id]:Hide()end
 if a.liveLabel then a.liveLabel:Hide()end;W.metrics.retired=W.metrics.retired+1
 if a.liveNameplate then a.liveNameplate:Hide()end
end
function W.Capture(v)
 local out={room=v.currentRoomKey,player=copy(v.playerState),roomOverride=v.roomOverride,rooms={},reservations=v.rememberedVisitors and copy(v.rememberedVisitors.reservations)}
 for _,s in ipairs(v:Scenes())do
  local pending=s.pendingWorldCalibration
  local calibration=s.worldCalibration;if pending then calibration=pending.record end
  local r={calibration=copy(calibration),groundOffset=s.groundOffset,actors={},art={},flags={},walkSpeed=s.native.walkSpeed};out.rooms[s.key]=r
  for _,a in ipairs(s.native.order)do if not a.spec.liveRemote and not a.spec.canonicalNPC then r.actors[a.id]=actorSnapshot(a)end end
  for id,o in pairs(s.objects)do r.art[id]={box=copy(o.baseBox),layer=o.layer,shadow=copy(o.shadow),shadowLayer=o.shadowLayer,hidden=o.editorHidden}end
  for _,f in ipairs(v.flags)do if f.scene==s then r.flags[f.id]={box=copy(f.baseBox),scale=f.flagScale,layer=f.layer,hidden=f.editorHidden}end end
 end
 return out
end
function W.Canonical(v,s)
 if not public(s.key)then return end
 local r=W.private and W.private.rooms[s.key]
 if not r then
  local save=W.Capture(v);W.private.rooms[s.key]=save.rooms[s.key]
 end
 ns.WardenWorldScale.Request(s,s.definition.worldCalibration);s.native.walkSpeed=s.definition.walkSpeed;s.nativeAir.walkSpeed=s.definition.walkSpeed
 s.groundOffset=s.definition.navigation.contactOffset
 local defaults={};for _,spec in ipairs(S.Props(s))do defaults[spec.id]=spec end
 for _,a in ipairs(s.native.order)do
  if W.IsPrivateActor(a)then
   if a.visit and a.position then a.visit.pose=copy(a.seating and a.seating.approach or a.position);a.visit.yaw=a.yaw end
   a.layerRestore=nil;retire(s,a)
  elseif not a.spec.liveRemote and not a.spec.canonicalNPC then
   local base=defaults[a.id]
   if base then
    a.spec=copy(base);a.shadow=copy(base.shadow);a.shadowLayer=base.shadowLayer;a.collider=nil;a.hitbox=nil;a.seatHeightOffset=base.seatHeightOffset
    a.editorHidden=base.defaultHidden;a.awaitRegistration=nil;a.floorAnchorHeld=nil;a.registrationAttempts=nil
    if a.ready then a.scale=(a.authoredBaseScale or a.scale)*(base.sizeMultiplier or 1);a.top=(a.bounds[6]-a.bounds[3])*a.scale;a.renderScale=nil
     s.native:SetLayer(a,base.nativePass or'native');v:ActorReady(s,a)
    end
   elseif a.spec.custom then retire(s,a)
   end
  end
 end
 for _,plate in ipairs(s.definition.plates)do local o=s.objects[plate[1]];if o then
  o.layer=plate[3];o.baseBox=copy(plate[4]);o.box=o.baseBox;o.shadow=copy(plate[5]);o.shadowLayer=nil;o.editorHidden=nil;o.host=s.layers[o.layer]
  for _,r in ipairs(o.regions)do r.texture:SetParent(o.host);r.texture:Show()end;s:LayoutArt(o)
 end end
 for _,spec in ipairs(s.definition.flags or{})do for _,f in ipairs(v.flags)do if f.scene==s and f.id==spec.id then
  f.baseBox=copy(spec.box);f.flagScale=spec.scale or 1;f.layer=spec.layer or'flags';f.editorHidden=spec.defaultHidden;f.mountSignature=nil;v:MountFlag(f)
 end end end
 s.liveCanonical=true
end
function W.Restore(v,snapshot)
 local saved=snapshot or W.private
 W.active=false;v.liveMode=nil
 for _,s in ipairs(v:Scenes())do
  for _,a in ipairs(s.native.order)do if a.spec.liveRemote or a.spec.canonicalNPC then retire(s,a)end end
  local r=saved and saved.rooms[s.key]
  if r then
   ns.WardenWorldScale.Request(s,r.calibration);s.native.walkSpeed=r.walkSpeed;s.nativeAir.walkSpeed=r.walkSpeed;s.groundOffset=r.groundOffset
   for id,old in pairs(r.actors)do local a=s.native.actors[id]
    if a and not W.IsPrivateActor(a)then
     if a.retired and not old.retired and old.spec.custom then a=s.native:LoadProp(copy(old.spec))end
     a.spec=copy(old.spec)
     -- A cold snapshot has scale=1 but no measured dimensions. Keep the
     -- subsequently measured intrinsic basis instead of restoring that sentinel.
     if old.ready then a.scale=old.scale
     elseif a.authoredBaseScale then a.scale=a.authoredBaseScale*(a.spec.sizeMultiplier or 1)end
     if a.bounds then a.top=(a.bounds[6]-a.bounds[3])*a.scale else a.top=old.top end
     a.editorHidden=old.editorHidden;if a.editorHidden==nil then a.editorHidden=a.spec.defaultHidden end
     a.collider=copy(old.collider);a.hitbox=copy(old.hitbox)
     a.shadow=copy(old.shadow);a.shadowLayer=old.shadowLayer;a.seatHeightOffset=old.spec.seatHeightOffset;a.renderScale=nil;a.spec.worldYaw=old.spec.worldYaw
     a.route=nil;a.seating=copy(old.seating);a.pendingInteraction=nil
     if a.ready then
      s.native:SetLayer(a,old.renderLayer or'native')
      if old.position then s.native:Place(a,old.position[1],old.position[2],old.position[3],old.yaw)
      elseif a.ready then v:ActorReady(s,a)end
     end
    end
   end
   for id,old in pairs(r.art)do local o=s.objects[id];if o then
    o.baseBox=copy(old.box);o.box=o.baseBox;o.layer=old.layer;o.host=s.layers[o.layer];o.shadow=copy(old.shadow);o.shadowLayer=old.shadowLayer;o.editorHidden=old.hidden
    for _,r in ipairs(o.regions)do r.texture:SetParent(o.host);r.texture:SetShown(not old.hidden)end;s:LayoutArt(o)
   end end
   for _,f in ipairs(v.flags)do local old=r.flags[f.id];if f.scene==s and old then f.baseBox=copy(old.box);f.flagScale=old.scale;f.layer=old.layer;f.editorHidden=old.hidden;f.mountSignature=nil end end
  end
  s.liveCanonical=nil
 end
 W.active=false;v.liveMode=nil;W.slots={};W.npcState={};W.lastRoute=nil;W.lastScene=nil;W.nextCorrection=nil
 if saved then v.playerState=copy(saved.player);v.roomOverride=saved.roomOverride end
 local m=v.rememberedVisitors
 if m then
  m.reservations=saved and copy(saved.reservations)or{}
  -- Retain identities, schedules and remembered poses. Only native slots were
  -- retired; resuming materializes those same entities from existing data.
  for _,state in pairs(m.entities or{})do if state.actor and state.actor.retired then state.actor=nil end end
  m.scene=nil;m.slots={};m:SceneChanged(v:ActiveRoom())
 end
end
local originalSave=ns.WardenCanonicalPlayer.Save
ns.WardenCanonicalPlayer.Save=function(v)
 if v.liveMode then return true,'Private scenic position retained while Live is active'end
 return originalSave(v)
end
local unitTokens={'target','mouseover','focus','party1','party2','party3','party4'}
for i=1,40 do unitTokens[#unitTokens+1]='raid'..i end
local function availableUnit(guid)
 if not guid then return end
 for _,token in ipairs(unitTokens)do if ns.SafeCall(UnitGUID,token)==guid then return token end end
end
function W.AppearanceReport(p,a,reason)
 local native=a and a.spec.liveUnit~=nil
 local mode=reason or(not a and'APPEARANCE_UNAVAILABLE'or a.failed and'LOAD_FAILED'or not a.ready and'LOADING'or native and'NATIVE_UNIT'or'GENERIC_BODY')
 if p.renderReport and p.renderActor==a and p.renderReport.mode==mode and p.renderItems==(a and a.dressedItems)and p.renderReport.form==(p.liveForm or 0)then return p.renderReport end
 p.renderActor=a;p.renderItems=a and a.dressedItems
 local r={mode=mode,
  nativeUnitUsed=native or false,genericBody=a~=nil and not native,visualVerification='UNVERIFIED',gearSlotsAccepted={},gearSlotsRendered='UNVERIFIED',
  form=p.liveForm or 0,formApplied=(p.liveForm or 0)==0 and'NOT_REQUESTED'or native and'UNVERIFIED_NATIVE_UNIT'or'UNSUPPORTED_FALLBACK',
  face=native and'UNVERIFIED_NATIVE_UNIT'or'APPROXIMATE',hair=native and'UNVERIFIED_NATIVE_UNIT'or'APPROXIMATE',bodyClothing=native and'UNVERIFIED_NATIVE_UNIT'or'APPROXIMATE'}
 for slot in pairs(a and a.gearAppliedSlots or{})do r.gearSlotsAccepted[#r.gearSlotsAccepted+1]=slot end;table.sort(r.gearSlotsAccepted)
 r.reason=a and(a.failed and a.status or not native and'NO_READABLE_MATCHING_UNIT'or nil)or reason
 p.renderReport=r;return r
end
local function label(s,a,p)
 if now()<(a.liveLabelAt or 0)then return end;a.liveLabelAt=now()+.12
 if a.liveLabel then a.liveLabel:Hide()end
 if not a.liveNameplate then
  local b=CreateFrame('Button',nil,s.frame);b:SetSize(240,27);b:EnableMouse(true)
  b.label=ns.UI2Components.Text(b,'',13,ns.UI2Components.colors.gold);b.label:SetAllPoints();b.label:SetJustifyH('CENTER')
  b:SetScript('OnClick',function(self)L.OpenPlayer(self.livePeer)end);a.liveNameplate=b
 end
 local b=a.liveNameplate;local point=a.position;local u,y=ns.WardenWorldScale.ProjectPoint(s.native,a,point[1],point[2],point[3]+a.top)
 if u and y then
  b.livePeer=p.id;b:SetFrameLevel((s.layers['desk-props-front']or s.frame):GetFrameLevel()+5)
  b:ClearAllPoints();b:SetPoint('BOTTOM',s.frame,'TOPLEFT',u*s.drawWidth,-y*s.drawHeight-3)
  local name=L.PlayerName(p);if b.name~=name then b.name=name;b.label:SetText(name);ns.Theme.Tooltip(b,name,'Click to open their Aether profile.')end
  b:Show()
 else b:Hide()end
end
function W.Remote(v,s,p,slot)
 local state=p.liveState
 if not state or not p.liveAppearance or p.status~='CONNECTED'or state.scene~=s.key or not G.Compatible(state.revision)or now()-state.received>35 then
  W.AppearanceReport(p,nil,not p.liveAppearance and'APPEARANCE_UNAVAILABLE'or'AWAITING_SHARED_SCENE')
  retire(s,s.native.actors['live-player-'..slot]);return
 end
 local id='live-player-'..slot;local a=s.native.actors[id]
 -- A rejected packet must not start another asynchronous native load every
 -- pump. Recheck the geometry first using the retained measured actor bounds.
 -- New positions are checked immediately; an unchanged position retries once
 -- per second so furniture finishing its first load can still recover.
 if a and a.retired and a.bounds then
  if p.geometryRejectedSeq==state.seq and now()<(p.geometryRetryAt or 0)then return end
  local nav,why=v:GroundNavigation(s,a)
  if nav then
   local base=nav.base or nav
   local ok;ok,why=N.CheckPath({samples={{x=state.position[1],y=state.position[2],z=state.position[3]}},length=0},base)
   if ok then p.geometryRejectedSeq=nil;p.gameErrorDetail=nil
   else p.gameError='POSITION_OUTSIDE_SHARED_GEOMETRY';p.gameErrorDetail=why;p.geometryRejectedSeq=state.seq;p.geometryRetryAt=now()+1;return end
  else p.gameErrorDetail=why;return end
 end
 local unitLost=a and a.spec.liveUnit and ns.SafeCall(UnitGUID,a.spec.liveUnit)~=(p.cert and p.cert.guid)
 if not p.nextUnitCheck or now()>=p.nextUnitCheck or unitLost then
  p.nextUnitCheck=now()+2;p.readableUnit=availableUnit(p.cert and p.cert.guid)
 end
 local unit=p.readableUnit
 if unit and ns.SafeCall(UnitGUID,unit)~=(p.cert and p.cert.guid)then unit=nil;p.readableUnit=nil end
 if a and a.failed and a.spec.liveUnit then p.failedUnitUntil=now()+15;unit=nil end
 if now()<(p.failedUnitUntil or 0)then unit=nil end
 local changedUnit=a and a.spec.liveUnit~=unit
 if not a or a.retired or unitLost or changedUnit or a.liveIdentity~=p.id or a.liveAppearanceVersion~=p.appearanceVersion or a.failed and now()>=(p.renderRetry or 0)then
  p.renderRetry=now()+15
  -- Copy only on reconstruction, not on each movement/presence update.
  -- A signed identity does not make arbitrary peer model IDs safe assets.
  local recipe=copy(p.liveAppearance);if not N.LiveDisplayAllowed(recipe)then recipe.nativeDisplayID=nil end
  local spec={id=id,liveRemote=true,liveUnit=unit,appearance=copy(recipe),appearanceV2=copy(p.liveAppearanceV2),gear=copy(recipe.slots),appearanceSource='Consenting Live owner; no Athena lookup',
   height=1.85,navigationRadius=.4,at=copy(state.position),yaw=state.yaw,animations=animations}
  if a and not a.retired and not changedUnit and not unitLost and a.liveIdentity==p.id and a.liveAppearanceVersion~=p.appearanceVersion and s.native.RefreshAppearance and s.native:RefreshAppearance(a,spec)then
   a.liveAppearanceVersion=p.appearanceVersion
  else
  local oldLabel=a and a.liveLabel
  local oldNameplate=a and a.liveNameplate;if oldNameplate then oldNameplate:Hide()end
  a=s.native:Reuse(spec)
  if not a then W.AppearanceReport(p,nil,'APPEARANCE_UNAVAILABLE');return end
  a.liveLabel=oldLabel;a.liveNameplate=oldNameplate;a.liveIdentity=p.id;a.liveAppearanceVersion=p.appearanceVersion;a.liveApplied=nil;W.metrics.created=W.metrics.created+1
  end
 end
 a.liveLastSeen=now()
 W.AppearanceReport(p,a)
 if not a.ready or a.failed then return a end
 label(s,a,p)
 if a.liveApplied==state.seq then return a end
 if not allowedAnimation[state.animation]then p.gameError='UNSUPPORTED_ANIMATION';W.metrics.rejected=W.metrics.rejected+1;return a end
 local nav,why=v:GroundNavigation(s,a);if not nav then p.gameError=why;return a end
 local base=nav.base or nav
 if math.abs(state.position[3]-(base.floor or 0))>.2 then p.gameError='INVALID_GROUND_HEIGHT';retire(s,a);return end
 local point={samples={{x=state.position[1],y=state.position[2],z=state.position[3],distance=0}},length=0}
 local valid,blocked=N.CheckPath(point,base)
 if not valid then p.gameError='POSITION_OUTSIDE_SHARED_GEOMETRY';p.gameErrorDetail=blocked;p.geometryRejectedSeq=state.seq;p.geometryRetryAt=now()+1;retire(s,a);return end
 local goal=state.destination
 local path
 if state.duration>0 then
  path,why=N.WalkPath(state.position,goal[1],goal[2],base)
  if not path or math.abs(goal[3]-(base.floor or 0))>.2 then p.gameError=why or'INVALID_GROUND_HEIGHT';return a end
 end
 local age=math.max(0,math.min(30,stamp()-state.at));local x,y,z=unpack(state.position)
 if path then x,y,z=N.Sample(path,math.min(1,age/math.max(.01,state.duration)))end
 local distance=math.sqrt((x-a.position[1])^2+(y-a.position[2])^2)
 if not a.livePlaced then s.native:Place(a,x,y,z,state.yaw);a.livePlaced=true
 elseif distance>7 then p.gameError='POSITION_DESYNCHRONIZED';retire(s,a);return end
 a.liveApplied=state.seq;W.metrics.movements=W.metrics.movements+1;p.gameError=nil;p.gameErrorDetail=nil;p.geometryRejectedSeq=nil
 if state.seat then
  local prop=s.native.actors[state.seat];local kind=prop and(prop.spec.interaction or(prop.id=='chair'and'chair'or prop.id=='firepit'and'fire'))
 if not prop or not prop.ready or prop.editorHidden or not kind or(prop.position[1]-x)^2+(prop.position[2]-y)^2>16 then p.gameError='INVALID_PUBLIC_INTERACTION';return a end
  local animation=kind=='fire'and 97 or 102
  if a.capabilities[animation]and(not a.seating or a.seating.id~=state.seat)then a.route=nil;v:SeatPlayer(s,a,{id=state.seat,kind=kind,animation=animation})end
  return a
 elseif a.seating then v:LeavePlayerSeat(s,a);return a end
 local target=path and goal or{x,y,z}
 local correction=N.WalkPath(a.position,target[1],target[2],nav)
 if correction and correction.length>.05 then
  local duration=path and math.max(.65,state.duration-age)or math.max(.35,math.min(2,correction.length/1.65))
  s.native:Route(a,correction,duration,state.animation==5 and a.capabilities[5]and 5 or 4,nav)
 else a.route=nil;s.native:Place(a,a.position[1],a.position[2],a.position[3],state.yaw);s.native:Animate(a,a.capabilities[state.animation]and state.animation or 0,1)end
 return a
end
local function staticNav(v,s,a)local nav=v:GroundNavigation(s,a);return nav and(nav.base or nav)end
function W.NPC(v,s,def,dt)
 W.npcState=W.npcState or{};local r=W.npcState[def.id]
 if not r then r={};W.npcState[def.id]=r end
 local id='canonical-'..def.id;local a=s.native.actors[id]
 if not a or a.retired then
  local x,y;if def.worldPoints then x,y=unpack(def.worldPoints[1])else x,y=N.AuthoredFloorPoint(s.native.frame,s.shot,def.points[1][1],def.points[1][2],0)end;if not x then return end
  local oldLabel=a and a.liveLabel
  a=s.native:Reuse({id=id,canonicalNPC=true,label=def.name,appearance={raceID=def.raceID,sex=def.sex},height=1.85,navigationRadius=.4,at={x,y,0},animations=animations})
  if not a then return end;a.liveLabel=oldLabel;r.actor=a;r.paths=nil;W.metrics.created=W.metrics.created+1
 end
 if not a.ready or a.failed then return end
 if not r.paths then
  if now()<(r.nextPlan or 0)then return end;r.nextPlan=now()+3
  local nav=staticNav(v,s,a);if not nav then return end
  local points={};for _,uv in ipairs(def.points)do local x,y;if def.worldPoints then x,y=unpack(def.worldPoints[#points+1])else x,y=N.AuthoredFloorPoint(s.native.frame,s.shot,uv[1],uv[2],0)end;if not x then return end;points[#points+1]={x,y,0}end
  local paths,cycle={},0
  for i,p in ipairs(points)do local q=points[i%#points+1];local path=N.WalkPath(p,q[1],q[2],nav);if not path then return end
   local duration=math.max(1,path.length/ns.WardenWorldScale.WALK_SPEED);paths[#paths+1]={path=path,duration=duration,begin=cycle};cycle=cycle+duration+def.wait
  end
  r.paths,r.cycle=paths,cycle;W.metrics.npcPlans=W.metrics.npcPlans+1
 end
 W.clockOffset=W.clockOffset or stamp()-now()
 local phase=(now()+W.clockOffset+def.offset)%r.cycle
 for _,leg in ipairs(r.paths)do if phase>=leg.begin and phase<leg.begin+leg.duration+def.wait then
  local q=math.min(1,(phase-leg.begin)/leg.duration);local x,y,z,dx,dy=N.Sample(leg.path,q)
  -- The routine has a deterministic clock and static path. Local body
  -- clearance may briefly pause presentation; contested actions need future
  -- authority and are deliberately not claimed as synchronized here.
  if N.CanStep(s.native,a,a.position,{x,y,z})then s.native:Place(a,x,y,z,math.atan2(dy,dx))end
  a.route=nil;s.native:Animate(a,q<1 and 4 or 0,1);break
 end end
 if a.liveLabel then a.liveLabel:Hide()end -- Citizens use the shared name-only hover tooltip.
end
function W.Bind(v)
 if v.liveBound92 then return end;v.liveBound92=true
 local m=v.rememberedVisitors
 if m then
  local advance,changed=m.Advance,m.SceneChanged
  m.Advance=function(self,...)if W.active then return end;return advance(self,...)end
  m.SceneChanged=function(self,...)if W.active then return end;return changed(self,...)end
  local materialize,ready=m.Materialize,m.Ready
  m.Materialize=function(self,...)if W.active then return false end;return materialize(self,...)end
  m.Ready=function(self,a,...)if W.active then a.layerRestore=nil;retire({native=a.engine,shadows={}},a);return end;return ready(self,a,...)end
 end
 local E=ns.WardenSceneEditor
 if not W.propsGuard then
  W.propsGuard=true;local props=S.Props
  S.Props=function(scene)
   local definition=type(scene)=='table'and scene.definition or S.Room(scene)
   if W.active and definition then return definition.props end
   return props(scene)
  end
 end
 if E and not E.liveGuard92 then
  E.liveGuard92=true
  local apply,open=E.ApplyAll,E.Open
  E.ApplyAll=function(...)if W.active then return end;return apply(...)end
  if open then E.Open=function(...)if W.active then return false,'Leave Aether Live before editing your private scene'end;return open(...)end end
 end
 local open,ready,ended,advance,report=v.OpenRoom,v.ActorReady,v.RouteEnded,v.Advance,v.Report
 v.OpenRoom=function(self,key,...)
  if W.active and not public(key)then
   L.Runtime():Leave('Entering private Home');W.Restore(self);W.private=nil;W.phase='private'
  end
  local ok,why=open(self,key,...)
  if ok and W.active then W.Canonical(self,self:ActiveRoom())end
  return ok,why
 end
 v.ActorReady=function(self,s,a,...)
  if W.active and W.IsPrivateActor(a)then a.layerRestore=nil;retire(s,a);return end
  return ready(self,s,a,...)
 end
 v.Report=function(self,...)
  local out=report(self,...);local hidden,visible=0,0
  for _,s in ipairs(self:Scenes())do for _,a in ipairs(s.native.order)do if W.IsPrivateActor(a)then if a.retired then hidden=hidden+1 elseif a.ready then visible=visible+1 end end end end
  out.aetherLiveWorld={active=W.active,phase=W.phase,privateSnapshot=W.private~=nil,transportEnabled=L.Active(),privateActorsHidden=hidden,privateActorsReady=visible,lastError=L.lastError}
  return out
 end
 v.RouteEnded=function(self,s,a,...)
  if a.spec.liveRemote or a.spec.canonicalNPC then s.routeAt[a.id]=nil;return end
  return ended(self,s,a,...)
 end
 v.Advance=function(self,dt)
  local result=advance(self,dt)
  if W.active and self.frame:IsVisible()then for _,def in ipairs(W.NPCs)do if def.scene==self.currentRoomKey then W.NPC(self,self:ActiveRoom(),def,dt)end end end
  return result
 end
end
function W.Enter()
 if not L.Active()then return false,'Explicit, verified Live participation is required'end
 local U=ns.UI2;U.Ensure();local v=U.realm
 if not v or not v.roomTravel then return false,'The Fireside world is still loading'end
 W.Bind(v)
 if W.active then return true end
 if W.phase~='private'then return false,'A scene transition is in progress'end
 if not v.frame:IsVisible()then U.Open({page='overview',sceneRoom=v.currentRoomKey})end
 local s=v:ActiveRoom();local ok,why=v.roomTravel:Eligible(s);if not ok then return false,why end
 -- Finish any previous presentation before taking ownership of a new snapshot.
 if v.roomTravel.state and v.roomTravel.state.presentation then v.roomTravel:Cancel('Live entry requested')end
 ns.WardenCanonicalPlayer.Save(v)
 local captured,snapshot=pcall(W.Capture,v);if not captured then return false,'Live entry could not preserve the private scene: '..tostring(snapshot)end
 W.private=snapshot;W.phase='entering';W.transition=(W.transition or 0)+1;local token=W.transition
 local target=snapshot.room=='square'and snapshot.player and snapshot.player.position or nil
 local function abort(reason)
  if W.transition~=token then return end
  L.lastError=reason or'Live entry interrupted';W.Leave(L.lastError,true)
 end
 return v.roomTravel:Presentation('square',function()
  if W.transition~=token or W.private~=snapshot then return false,'Live entry was cancelled'end
  local success,result,reason=pcall(function()
   W.active=true;v.liveMode=true
   if v.rememberedVisitors then v.rememberedVisitors.reservations={}end
   for _,room in ipairs(v:Scenes())do W.Canonical(v,room)end
   local entered,why=v:OpenRoom('square',target);if not entered then return false,why end
   W.lastRoute=nil;W.nextAppearance=0;W.nextCorrection=0
   return true
  end)
  if not success then return false,'Live scene preparation failed: '..tostring(result)end
  return result,reason
 end,function()
  local a=v:ActiveRoom().native.actors.attendant
  return a and a.ready and not(a.awaitSpawn or a.awaitRegistration)
 end,abort,function(success)
  if W.transition==token and success and W.active then W.phase='live';if L.RefreshStatus then L.RefreshStatus()end end
 end)
end
function W.Leave(reason,immediate,keepConnection)
 keepConnection=keepConnection or W.backgroundClosing
 local U=ns.UI2;local v=U.realm
 if not keepConnection then L.Runtime():Leave(reason or'Left Aether Live')else
  local s=L.Runtime();s.localGame={};s.localVersions={};s.localAt={};s.gameQueue={};s.gameOrder={}
 end
 if W.restoring then return true end
 if W.phase=='leaving'and not immediate then return true,'Live exit already in progress'end
 -- Cancelling invokes the old presentation's abort. Its restoration must
 -- finish before another presentation captures or overwrites W.private.
 if v and v.roomTravel and v.roomTravel.state and v.roomTravel.state.presentation then v.roomTravel:Cancel(reason or'Live exit')end
 if not v or not W.private then W.active=false;W.phase='private';if v then v.liveMode=nil end;return true end
 local saved=W.private;W.phase='leaving';W.transition=(W.transition or 0)+1;local token=W.transition;local restored=false
 for _,s in ipairs(v:Scenes())do for _,a in ipairs(s.native.order)do if a.spec.liveRemote or a.spec.canonicalNPC then retire(s,a)end end end
 local function restore()
  if restored then return true end;restored=true;W.restoring=true
  W.Restore(v,saved);local position=saved.player and saved.player.position
  local committing=v.roomTravel.committing;v.roomTravel.committing=true
  local ok,why
  if U.window:IsVisible()then ok,why=v:OpenRoom(saved.room,position)
  else
   v.currentRoomKey=saved.room;local room=v:EnsureRoom(saved.room);room.pendingArrival=copy(position)
   for _,other in ipairs(v:Scenes())do if other.key~=saved.room then local a=other.native.actors.attendant;if a and not a.retired then other.native:Retire(a);a.position=nil;other.requested['local/attendant']=nil end end end
   ok=true
  end
  v.roomTravel.committing=committing
  v.playerState=copy(saved.player);v.roomOverride=saved.roomOverride
  if W.private==saved then W.private=nil end
  if W.transition==token then W.phase='private'end
  W.restoring=nil
  if ok and ns.WardenSceneEditor then ns.WardenSceneEditor.ApplyAll(saved.room)end
  if not ok then L.lastError=why end
  if L.RefreshStatus then L.RefreshStatus()end
  return ok,why
 end
 if immediate or not U.window:IsVisible()then return restore()end
 return v.roomTravel:Presentation(saved.room,restore,function()return true end,function()restore()end)
end
function W.Publish(v,s,client)
 local a=s.native.actors.attendant
 if not public(s.key)then return end
 local form=ns.SafeNumber(ns.SafeCall(GetShapeshiftFormID))or 0
 if form~=W.lastObservedForm then W.lastObservedForm=form;W.nextAppearance=math.min(W.nextAppearance or 0,now()+.5)end
 if now()>=(W.nextAppearance or 0)then
  W.nextAppearance=now()+30
  local appearance,why=ns.WardenAppearance.Capture(ns.SafeCall(UnitGUID,'player'))
  local minimal=not appearance and ns.WardenAppearance.Minimal(ns.SafeCall(UnitGUID,'player'));appearance=appearance or minimal
  L.lastAppearanceError=not appearance and(why or'Appearance is unavailable on this client')or nil
  L.localAppearanceStatus=not appearance and'APPEARANCE_UNAVAILABLE'or minimal and'MINIMAL_RACE_SEX'or'OWNER_RECIPE'
  if appearance then
   local recipe=G.PUBLIC_APPEARANCE_V2 and ns.WardenAppearance.CaptureLive(a and a.actor)
   local payload=recipe and G.AppearanceEncodeV2(recipe)or G.AppearanceEncode(appearance,form)
   if payload then client:Publish('A',payload);W.lastPublishedForm=form end
  end
  if minimal or not appearance or not a or not a.ready then W.nextAppearance=now()+2 end
 end
 if not a or not a.ready or not a.position or a.awaitRegistration or a.awaitSpawn then return end
 local route=a.route;local seat=a.seating
 local signature=(route and tostring(route)or'idle')..'/'..s.key..'/'..(seat and seat.phase..seat.id or'')..'/'..(a.animation or 0)
 if s.definition.world3D and a.manualMovement then signature=signature..'/wasd/'..math.floor(now()*6)end
 if signature==W.lastRoute and now()<(W.nextCorrection or 0)then return end
 W.lastRoute=signature;W.nextCorrection=now()+8
 local p=seat and seat.approach or a.position;local goal=route and route.path.samples[#route.path.samples]
 local state={scene=s.key,revision=G.SCENE_REVISION,position=copy(p),destination=goal and{goal.x,goal.y,goal.z}or copy(p),
  yaw=a.yaw or 0,duration=route and math.max(0,route.duration-route.elapsed)or 0,animation=route and route.animation or(a.manualMovement and 4 or 0),seat=seat and seat.phase=='hold'and seat.id or nil}
 -- Periodic idle state must also remain fresh. Retain the observation time
 -- through the send queue, so a delayed destination can be caught up locally.
 client.localScene=s.key;client:Publish('M',G.StateEncode(state),true)
end
function L.WorldPump()
 local client=L.runtime;local U=ns.UI2;local v=U.realm
 if W.active and not(client and client.enabled)and W.phase~='leaving'then L.lastLost=true;L.lastError='Live participation ended because identity, enrollment or permission changed. Your private scene is restored.';W.Leave('Live connection permission changed');return end
 if not W.active or not client or not v then return end
 if not U.window:IsVisible()then W.Leave('Fireside closed',true,ns.AetherUnified and ns.AetherUnified.Available());return end
 W.Bind(v);local scene=v:ActiveRoom();if not public(scene.key)then W.Leave('Private destination');return end
 W.Publish(v,scene,client)
 local peers={};for _,p in pairs(client.peers)do if p.status=='CONNECTED'and p.liveState and p.liveState.scene==scene.key and p.liveAppearance then peers[#peers+1]=p
 elseif p.status=='CONNECTED'then W.AppearanceReport(p,nil,not p.liveAppearance and'APPEARANCE_UNAVAILABLE'or'AWAITING_SHARED_SCENE')end end
 table.sort(peers,function(a,b)return a.id<b.id end)
 local used={}
 -- Stable slots survive another peer joining/leaving. Never bind actor-slot
 -- identity to an Athena GUID or accidentally reuse a remembered character.
 for slot,id in pairs(W.slots)do for _,p in ipairs(peers)do if id==p.id then used[slot]=p end end;if not used[slot]then W.slots[slot]=nil end end
 for _,p in ipairs(peers)do local found=false;for _,q in pairs(used)do if p==q then found=true end end
  if not found then for i=1,8 do if not used[i]then W.slots[i]=p.id;used[i]=p;break end end end
 end
 for _,s in ipairs(v:Scenes())do for i=1,8 do local a=s.native.actors['live-player-'..i]
  if s~=scene or not used[i]then retire(s,a)
  elseif used[i]then W.Remote(v,s,used[i],i)end
 end end
 if L.RefreshStatus then L.RefreshStatus()end
end
local attach=ns.WardenRealm.Attach
ns.WardenRealm.Attach=function(...)local v=attach(...);W.Bind(v);return v end
