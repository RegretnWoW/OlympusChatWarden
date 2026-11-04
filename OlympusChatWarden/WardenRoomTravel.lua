-- Walking portals are local scene presentation, never movement of the actual
-- WoW unit. One finite route/transition; no command queue or saved history.
local _,ns=...
local T={VERSION=2,LOAD_TIMEOUT=15};ns.WardenRoomTravel=T
local N,C=ns.WardenNativeScene,ns.WardenRoomCatalogue
local function inside(u,v,b)return u and v and u>=b[1]and u<=b[3]and v>=b[2]and v<=b[4]end
local function ease(q)q=math.max(0,math.min(1,q));return q*q*(3-2*q)end
function T.Navigate(v,route)
 if not v or not v.roomTravel or not ns.Membership.Allowed()or ns.Checked(ns.SafeCall(InCombatLockdown))then return false end
 if v.campfireWelcome and route.page=='journey'then return true,false,'Finish or skip the campfire welcome before hearthing'end
 local t=v.roomTravel;local from=v:ActiveRoom().key;local to=route.page=='journey'and'study'or'hall'
 if route.page~='journey'then if t.state and t.state.navigation then t:Cancel('Another tab was selected')end;return false end
 if t.state then t:Cancel('Another tab was selected')end
 if from==to then return false end
 local seconds,source=ns.WardenHearth.CastTime();if not seconds then return true,false,source end
 local link;for _,candidate in ipairs(C.Connections(from))do if candidate.to==to and candidate.portal then link=candidate;break end end
 if not link then return false end
 link.label=C.Room(to).label
 t.state={navigation=true,route=C.Copy(route),link=link,scene=v:ActiveRoom(),page=ns.UI2.route.page,elapsed=0}
 t.arrivalGuard=nil;t:Hearth(t.state,seconds,source);return true,true,'Hearthing to '..link.label
end
function T.Bind(v,U)
 if v.roomTravel then return v.roomTravel end
 local t={realm=v,ui=U,armed={},metrics={started=0,completed=0,cancelled=0,failed=0}};v.roomTravel=t
 local f=CreateFrame('Frame',nil,U.window);t.frame=f;f:SetAllPoints(v.frame);f:EnableMouse(true);f:Hide()
 local black=f:CreateTexture(nil,'OVERLAY');black:SetAllPoints();black:SetColorTexture(.006,.012,.025,1)
 local caption=f:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');caption:SetPoint('CENTER');caption:SetSize(500,60);caption:SetTextColor(.93,.77,.47);t.caption=caption
 local retry=CreateFrame('Frame',nil,U.window);retry:SetAllPoints(v.frame);retry:EnableMouse(false);retry:Hide();t.retryFrame=retry
 retry:SetScript('OnUpdate',function(_,dt)if t.pendingTabArrival and not t.state then t:Observe(dt,true)elseif not t.pendingTabArrival then retry:Hide()end end)
 function t:LayoutMask()
  f:ClearAllPoints()
  if U.navigationFrame and U.navigationFrame:IsVisible()then
   f:SetPoint('TOPLEFT',U.navigationFrame,'BOTTOMLEFT',-14,0)
   f:SetPoint('BOTTOMRIGHT',v.frame,'BOTTOMRIGHT')
  else f:SetAllPoints(v.frame)end
 end
 function t:Eligible(scene)
  if not scene or not scene.active or v:ActiveRoom()~=scene or not U.window:IsVisible()or not v.frame:IsVisible()then return false,'Scene is hidden'end
  if ns.WardenSceneEditor and ns.WardenSceneEditor.active then return false,'Close the scene editor before travelling'end
  if ns.Checked(ns.SafeCall(InCombatLockdown))then return false,'Scene travel is unavailable during combat'end
  if v.roomBookMotion or v.reader and v.reader.turnState or v.reading and v.cameraMix>.001 then return false,'Close the book before travelling'end
  if not scene.groundClick or not scene.groundClick:IsShown()then return false,'Open the scene to walk through its exit'end
  return true
 end
 function t:Point(scene,uv,a,nav)
  local x,y=N.FloorPoint(scene.native.frame,scene.shot,uv[1],uv[2],0)
  if not x or math.abs(x)>70 or math.abs(y)>70 then return nil,'Native exit ground projection is unavailable'end
  local function clear(px,py)return N.CheckPath({samples={{x=px,y=py,z=0,distance=0}},length=0},nav)end
  if clear(x,y)then return{x,y,0}end
  -- Bounded clearance for owner-moved furniture and other scene characters.
  for ring=1,3 do for i=0,7 do local angle=i*math.pi*.25;local px,py=x+math.cos(angle)*ring*.45,y+math.sin(angle)*ring*.45
   if clear(px,py)then return{px,py,0}end
  end end
  return nil,'The scene entrance is blocked'
 end
 function t:Walk(scene,a,point,nav)
  local dx,dy=a.position[1]-point[1],a.position[2]-point[2]
  if dx*dx+dy*dy<.025 then return true,'Already at the entrance'end
  local path,why=N.WalkPath(a.position,point[1],point[2],nav);if not path then return false,why end
  local ok;ok,why=a.engine:Route(a,path,math.max(2,path.length/N.WALK_SPEED+.65),4,nav)
  if ok then a.spec.worldYaw=nil;a.pendingInteraction=nil;a.restStage=nil;a.returning=nil;scene.routeAt[a.id]=nil;v:RefreshEffects()end
  return ok,why
 end
 function t:Cancel(why,failed)
  self.pendingTabArrival=nil
  retry:Hide()
  local state=self.state
  if not state then
   local guard=self.arrivalGuard;self.arrivalGuard=nil
   if guard and guard.actor.route==guard.route then guard.actor.route=nil;guard.actor.engine:Animate(guard.actor,0,1)end
   return
  end
  self.state=nil;self.last={from=state.link.from,to=state.link.to,status=why or'Cancelled',completed=false}
  self.metrics[failed and'failed'or'cancelled']=self.metrics[failed and'failed'or'cancelled']+1
  local a=state.committed and state.arrivalActor or state.actor
  if a and a.ready then a.route=nil;a.engine:Animate(a,0,1)end
  if a then a.manualUntil=nil end;ns.WardenHearth.Cleanup(state)
  f:SetScript('OnUpdate',nil);f:Hide();f:SetAlpha(0)
 end
 function t:Fade(state)
  state.phase='out';state.elapsed=0;self.metrics.started=self.metrics.started+1
  local level=math.max(U.window:GetFrameLevel()+150,v.frame:GetFrameLevel()+100)
  for _,room in ipairs(v:Scenes())do if room.groundClick then level=math.max(level,room.groundClick:GetFrameLevel()+5)end end
  self:LayoutMask();f:SetFrameStrata(U.window:GetFrameStrata());f:SetFrameLevel(level);f:SetAlpha(0);caption:SetText(state.link.label);caption:SetAlpha(0);f:Show()
  f:SetScript('OnUpdate',function(_,dt)self:Tick(dt)end)
 end
 function t:Request(key)
  if self.state then return false,'A scene journey is already in progress'end
  local scene=v:ActiveRoom();local ok,why=self:Eligible(scene);if not ok then return false,why end
  local link;link,why=C.Connection(key,scene.key);if not link or not link.portal then return false,why or'This connection has no walking entrance'end
  local a=scene.native.actors.attendant
  if not a or not a.spec.controlled or not a.ready or a.failed or a.awaitSpawn or a.awaitRegistration or a.editorHidden or not a.position then return false,'Wait for your scene character to load'end
  if not a.capabilities[4]then return false,'This model does not support walking'end
  if ns.DB.journalReducedMotion or ns.DB.livingRealmAmbience==false then return false,'Scene movement is disabled in your motion preferences'end
  local nav;nav,why=v:GroundNavigation(scene,a);if not nav then return false,why end
  local point;point,why=self:Point(scene,link.portal.approachUV,a,nav);if not point then return false,why end
  local state={link=link,actor=a,scene=scene,phase='approach',elapsed=0,point=point,page=U.route.page,sourcePosition={unpack(a.position)}}
  local yes;yes,why=self:Walk(scene,a,point,nav);if not yes then return false,why end
  self.state=state;self.arrivalGuard=nil;self.lastError=nil;a.motionStatus=link.label
  if not a.route then self:Fade(state)end
  return true,'Walking to '..link.label
 end
 function t:Hearth(state,seconds,source)
  ns.WardenHearth.Begin(state,v,seconds,source)
  state.phase='hearth';state.elapsed=0;self:LayoutMask();f:SetAlpha(0);caption:SetText('');f:Show();f:SetScript('OnUpdate',function(_,dt)self:Tick(dt)end)
 end
 function t:Arrive(state)
  local scene=v:ActiveRoom();local a=scene.native.actors.attendant
  if not a or not a.ready or a.failed or a.awaitRegistration then return false,'Waiting for the destination character'end
  local nav,why=v:GroundNavigation(scene,a);if not nav then return false,why end
  local point;point,why=self:Point(scene,state.link.portal.arrivalUV,a,nav);if not point then return nil,why end
  state.arrivalActor=a;a.route=nil;a.seating=nil;a.pendingInteraction=nil;a.restStage=nil;a.spec.worldYaw=nil
  a.engine:Place(a,point[1],point[2],0,0);a.spawnChecked=true;a.awaitSpawn=nil;state.arrival=point
  if state.navigation and(ns.DB.journalReducedMotion or ns.DB.livingRealmAmbience==false)then a.engine:Animate(a,0,1);return true end
  local walk;walk,why=self:Point(scene,state.link.portal.arrivalWalkUV,a,nav)
  if not walk then return nil,why end
  local ok;ok,why=self:Walk(scene,a,walk,nav);if not ok then return nil,why end
  self.arrivalGuard={scene=scene,actor=a,route=a.route,page=U.route.page}
  for _,link in ipairs(C.Connections(scene.key))do self.armed[link.id]=false end
  return true
 end
 function t:Recover(state,why)
  if state.navigation then
   self.lastError=why;self.pendingTabArrival={state=state,remaining=30,poll=0};retry:Show();state.phase='in';state.elapsed=0;return
  end
  self.committing=true;local ok=v:OpenRoom(state.link.from);self.committing=nil
  if ok and state.actor.ready then state.actor.route=nil;state.actor.engine:Place(state.actor,unpack(state.sourcePosition))end
  state.failed=why;state.phase='in';state.elapsed=0;caption:SetText('Journey interrupted');self.lastError=why
 end
 function t:Tick(dt)
  local state=self.state;if not state or state.phase=='approach'then return end
  if not U.window:IsVisible()or not v.frame:IsVisible()then self:Cancel('Window closed');return end
  if ns.WardenSceneEditor and ns.WardenSceneEditor.active then self:Cancel('Scene editor opened');return end
  if ns.Checked(ns.SafeCall(InCombatLockdown))then self:Cancel('Combat interrupted scene travel');return end
  self:LayoutMask()
  local realDT=dt;dt=math.max(0,math.min(1,dt));state.elapsed=state.elapsed+dt
  local reduced=ns.DB.journalReducedMotion==true
  if state.phase=='hearth'then
   if ns.WardenHearth.Tick(state,realDT)then self:Fade(state)end
  elseif state.phase=='out'then
   local q=state.elapsed/(reduced and .12 or .38);f:SetAlpha(ease(q));caption:SetAlpha(ease((q-.35)/.65))
   if q>=1 then
    f:SetAlpha(1);caption:SetAlpha(1);self.committing=true
    local ok,why;if state.navigation then v.pendingRoomKey=state.link.to;ok,why=U.Open(state.route);v.pendingRoomKey=nil else ok,why=v:OpenRoom(state.link.to)end;self.committing=nil
    if not ok then self:Recover(state,why);return end
    if state.closeMenuOnArrival then U.CloseMenu()end
    state.committed=true;state.page=U.route.page;state.phase='load';state.elapsed=0;state.poll=0;v:RefreshEffects()
   end
  elseif state.phase=='load'then
   f:SetAlpha(1);state.poll=state.poll+dt
   if state.elapsed>=.15 and state.poll>=.15 then
    state.poll=0;local ok,why=self:Arrive(state)
    if ok then state.phase='in';state.elapsed=0
    elseif state.navigation and state.elapsed>=T.LOAD_TIMEOUT then
     -- Tabs must remain usable even if the installed character cannot load.
     -- Retain one bounded arrival retry for the visible destination instead
     -- of silently treating a failed placement as successful travel.
     self.pendingTabArrival={state=state,remaining=30};retry:Show();self.lastError=why or'Destination character arrival pending';state.phase='in';state.elapsed=0
    elseif ok==nil or state.elapsed>=T.LOAD_TIMEOUT then self:Recover(state,why or'Destination loading timed out')end
   end
  elseif state.phase=='in'then
   local q=state.elapsed/(reduced and .12 or .42);f:SetAlpha(1-ease(q));caption:SetAlpha(1-ease(q))
   if q>=1 then
    local pending=self.pendingTabArrival and self.pendingTabArrival.state==state
    self.last={from=state.link.from,to=state.link.to,status=state.failed or pending and'Character arrival pending'or'Arrived',completed=not state.failed and not pending,arrival=state.arrival,arrivalPending=pending==true,hearth=state.hearth}
    self.metrics[state.failed and'failed'or'completed']=self.metrics[state.failed and'failed'or'completed']+1
    self.state=nil;f:SetScript('OnUpdate',nil);f:Hide();f:SetAlpha(0)
   end
  end
 end
 function t:Observe(dt,pendingDriver)
  local scene=v:ActiveRoom();local state=self.state
  local pending=self.pendingTabArrival
  if pending and not state then
   if not pendingDriver then return end
   pending.remaining=pending.remaining-dt
   if scene.key~=pending.state.link.to or pending.remaining<=0 then self.pendingTabArrival=nil;retry:Hide()
   else pending.poll=(pending.poll or 0)+dt;if pending.poll>=.5 then pending.poll=0;local ok=self:Arrive(pending.state);if ok then self.pendingTabArrival=nil;self.lastError=nil;if self.last then self.last.completed=true;self.last.arrivalPending=false;self.last.arrival=pending.state.arrival;self.last.status='Arrived'end end end end
  end
  if state then
   if state.phase~='approach'then return end
   local ok,why=self:Eligible(scene)
   if not ok or scene~=state.scene or U.route.page~=state.page then self:Cancel(why or'Navigation changed');return end
   if ns.DB.journalReducedMotion or ns.DB.livingRealmAmbience==false then self:Cancel('Scene movement disabled');return end
   state.elapsed=state.elapsed+dt
   local a=state.actor
   if not a.route then
    local p=a.position;local dx,dy=p[1]-state.point[1],p[2]-state.point[2]
    if dx*dx+dy*dy<.16 and not a.failed then self:Fade(state)else self:Cancel(a.motionStatus or'Entrance path interrupted',true)end
   elseif state.elapsed>120 then self:Cancel('Entrance path timed out',true)end
   return
  end
  if not self:Eligible(scene)then return end
  local a=scene.native.actors.attendant
  if not a or not a.ready or not a.position or a.seating or a.pendingInteraction or a.restStage then return end
  local guard=self.arrivalGuard
  if guard then
   if guard.scene==scene and guard.actor==a and a.route and a.route==guard.route then return end
   self.arrivalGuard=nil
  end
  local x,y,z=N.World(scene.shot,unpack(a.position));local u,w=N.ProjectNative(scene.native.frame,scene.shot,x,y,z)
  if not u then return end
  for _,link in ipairs(C.Connections(scene.key))do if link.portal then
   local near=inside(u,w,link.portal.triggerUV)
   if not near then self.armed[link.id]=true
   elseif self.armed[link.id]and a.route then self:Request(link.id);return end
  end end
 end
 local click,advance,select,open,report=v.ClickScene,v.Advance,v.Select,v.OpenRoom,v.Report
 v.ClickScene=function(self,scene,u,y)
  if t.state and t.state.phase~='approach'then return false,'Scene transition in progress'end
  if t.state then t:Cancel('A new destination was selected')end
  local a=scene and scene.native.actors.attendant
  if scene and not(a and a.seating)and not self:PickSceneObject(scene,u,y)then
   for _,link in ipairs(C.Connections(scene.key))do if link.portal and inside(u,y,link.portal.clickUV)then return t:Request(link.id)end end
  end
  return click(self,scene,u,y)
 end
 v.Advance=function(self,dt)local out=advance(self,dt);t:Observe(math.max(0,math.min(.25,dt)));return out end
 v.Select=function(self,route,...)
  if t.state and not t.committing then
   local room=self.pendingRoomKey or self.currentRoomKey or'hall'
   local expected=t.state.committed and t.state.link.to or t.state.link.from
   if route.page~=t.state.page or room~=expected then t:Cancel('Navigation changed')end
  end
  local guard=t.arrivalGuard
  if guard and not t.committing then
   local room=self.pendingRoomKey or self.currentRoomKey or'hall'
   if route.page~=guard.page or room~=guard.scene.key then t:Cancel('Navigation changed')end
  end
  return select(self,route,...)
 end
 v.OpenRoom=function(self,...)
  if t.state and not t.committing then t:Cancel('Another room was selected')end
  return open(self,...)
 end
 v.Report=function(self)
  local out=report(self);local h=t.state and t.state.hearth
  out.roomTravel={version=T.VERSION,phase=t.state and t.state.phase or'idle',connection=t.state and t.state.link.id,last=t.last,lastError=t.lastError,metrics=C.Copy(t.metrics),
   hearth=h and{spellID=h.spellID,seconds=h.seconds,castTimeSource=h.castTimeSource,elapsed=h.elapsed,completed=h.completed,animationSupported=h.animationSupported,soundRequested=h.soundRequested,completionSoundRequested=h.completionSoundRequested,effectRequested=h.effectRequested,effectStatus=h.effectStatus},
   nativeVerification='Native walking, placement and fade-over-models require client inspection'};return out
 end
 -- The shell's final OnHide handler cancels real closes after its existing
 -- hidden-menu reveal branch. Attach runs before that handler is installed.
 -- Reuse the existing scene update. The separate fade clock runs only while
 -- covered/loading/revealing, including when native motion is suspended.
 return t
end
local attach=ns.WardenRealm.Attach
ns.WardenRealm.Attach=function(...)local v=attach(...);T.Bind(v,ns.UI2);return v end
