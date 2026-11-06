-- Unified scene adapter. Loading, animation, routes, real Journal/showcase and Live remain owned by existing systems.
local _,ns=...
local F,N=ns.Fireside3D,ns.WardenNativeScene
local pi,sin,cos=math.pi,math.sin,math.cos
local function clamp(n,a,b)return math.max(a,math.min(b,n))end
function F.PlayCameraAllowed(v)
 local U=ns.UI2
 return v.frame:IsVisible()and not U.locked and not ns.MainStorageBlocked and U.menuHidden
  and not(v.shelfFocus or v.journalReading or v.roomBookMotion)
  and not(ns.WardenSceneEditor and ns.WardenSceneEditor.active)and not InCombatLockdown()
  and not(GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())
end
function F.Look(state,low,high)
 if not state.dragging then return end
 if not IsMouseButtonDown('RightButton')then state.dragging=false;return end
 local x,y=GetCursorPosition();local dx,dy=x-state.x,y-state.y
 if dx==0 and dy==0 and type(GetMouseDelta)=='function'then local mx,my=GetMouseDelta();if type(mx)=='number'and type(my)=='number'then dx,dy=mx,my end end
 state.yaw=(state.yaw-dx*.006)%(2*pi);state.pitch=clamp(state.pitch+dy*.006,low,high)
 state.x,state.y=x,y;state.lastLookDelta={dx,dy}
end
function F.InertEngine(real)
 return {actors={},order={},views={},shot=real.shot,metrics={},clock=0,status='One shared 3D viewport; no outside pass',
 Show=function()end,Pause=function()end,Tick=function()end,Lighting=function()end,RenderFrames=function()return{}end,Report=function()return{status='No second viewport'}end}
end
function F.ActorReady(v,s,a)
 if a.spec.house3D then
  local ok,loaded=N.Call(a.actor,'GetModelFileID')
  if N.BundledPlaceholder(a.bounds)or ok and type(loaded)=='number'and loaded>0 and loaded~=a.spec.fileID then
   s.native:Error(a,'Building was replaced by a missing/other model; inspect its native asset reference');return
  end
 end
 if a.spec.homeInterior and not F.HomeReady(s)then a.awaitHome=true;N.Call(a.actor,'Hide');return end
 a.awaitHome=nil
 local p=a.spec.at or{0,0,0}
 if a.spec.controlled and s.pendingArrival then p=s.pendingArrival;s.pendingArrival=nil;a.spawnChecked=nil end
 if a.spec.support then
  local support=s.native.actors[a.spec.support]
  if not support or not support.ready then a.awaitSupport=true;N.Call(a.actor,'Hide');return end
  local o=a.spec.supportOffset or{0,0,0};p={support.position[1]+o[1],support.position[2]+o[2],support.position[3]+support.top+(o[3]or 0)}
 end
 a.awaitSupport=nil;a.awaitRegistration=nil;a.groundOffset=0
 a.engine:Place(a,p[1],p[2],p[3],a.spec.worldYaw or a.spec.yaw or 0)
 if a.buildingAttempt then
  a.buildingAttempt.phase='native bounds ready; inspect rendering in client'
  if ns.Print then ns.Print('Model test #'..a.buildingAttempt.sequence..': '..a.buildingAttempt.label..' ['..a.spec.fileID..'] has native bounds; rendering is not yet verified.')end
 end
 if a.spec.controlled then v:EnsurePlayerSpawn(s,a)end
 if a.id=='room-book'then a.engine:Animate(a,147,1)end
 for _,other in ipairs(s.native.order)do if other.awaitSupport and other.spec.support==a.id then v:ActorReady(s,other)end end
 if a.id=='player-home'then for _,other in ipairs(s.native.order)do if other.awaitHome then v:ActorReady(s,other)end end end
end
function F.BeginBuildingTest(spec)
 local candidate=spec and F.BuildingCandidate(spec.fileID);if not candidate then return end
 F.buildingTestSequence=(F.buildingTestSequence or 0)+1
 local trace={sequence=F.buildingTestSequence,fileID=spec.fileID,label=candidate.label,slot=spec.id,phase='entering existing native prop loader'}
 F.lastBuildingAttempt=trace
 if ns.Print then ns.Print('Model test #'..trace.sequence..': requesting '..trace.label..' ['..trace.fileID..'] in '..tostring(trace.slot)..'.')end
 return trace
end
function F.BuildingReport(s)
 local out={zone=F.campLayout and'Forest camp'or'Manual scene assets',automaticBuildings=not F.manualBuildingTests,visualVerified=false,preferredTest=F.preferredBuilding,lastAttempt=F.lastBuildingAttempt,buildings={}}
 for _,h in ipairs(F.buildingCandidates)do
  local instances={}
  for _,a in ipairs(s.native.order)do if a.spec.fileID==h.fileID and not a.retired then
   instances[#instances+1]={slot=a.id,status=a.failed and a.status or a.ready and'bounds ready; inspect visible model'or'loading'}
  end end
  out.buildings[#out.buildings+1]={fileID=h.fileID,label=h.label,format=(h.fileID==328178 or h.fileID==202016)and'M2'or'WMO',instances=instances,status=#instances==0 and'not spawned'or'manually placed'}
 end
 return out
end
function F.BuildingNotice(v,s)
 local home=s.native.actors['player-home']
 if F.campLayout and not F.lastBuildingAttempt and not(home and home.failed)then if v.buildingNotice then v.buildingNotice:Hide()end;return end
 if not v.buildingNotice then
  local f=CreateFrame('Frame',nil,v.frame);f:SetPoint('BOTTOMLEFT',12,32);f:SetSize(640,44);f:SetFrameLevel(s.groundClick:GetFrameLevel()+3)
  local bg=f:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();bg:SetColorTexture(.035,.025,.015,.88)
  f.text=f:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');f.text:SetPoint('TOPLEFT',8,-7);f.text:SetPoint('BOTTOMRIGHT',-8,7);f.text:SetJustifyH('LEFT');v.buildingNotice=f
 end
 local attempt=F.lastBuildingAttempt
 local text=attempt and('Model test #'..attempt.sequence..': '..attempt.label..' ['..attempt.fileID..'] — '..attempt.phase)
  or(home and home.failed and('Camp shelter [202016]: '..tostring(home.status)))
  or'Use Add forest tent in the editor for another Furbolg forest tent [202016].'
 if v.buildingNotice.lastText~=text then v.buildingNotice.text:SetText(text);v.buildingNotice.lastText=text end
 v.buildingNotice:SetFrameLevel(s.groundClick:GetFrameLevel()+3);v.buildingNotice:Show()
end
function F.CameraKey(s,view)
 local p,t=view.position,view.target;local frame=s.native.frame
 return table.concat({p[1],p[2],p[3],t[1],t[2],t[3],view.fov or .85,frame:GetWidth(),frame:GetHeight(),frame:GetEffectiveScale()},':')
end
function F.ApplyCamera(s,view)
 local key=F.CameraKey(s,view);local engine=s.native
 if engine.world3DViewKey==key and engine.viewShot==engine.world3DLastView then return true end
 local ok=N.ViewCamera(engine,view)
 if ok then engine.world3DViewKey=key;engine.world3DLastView=engine.viewShot end
 return ok
end
local function homeWalls(box)
 local out={};local t=F.homeDoor.wallThickness;local hx,hy=box.halfX,box.halfY;local door=math.min(F.homeDoor.width/2,hx*.65)
 local function wall(id,x,y,w,d)
  out[#out+1]={id='home/'..id,centerX=box.centerX+box.cos*x-box.sin*y,centerY=box.centerY+box.sin*x+box.cos*y,halfX=w,halfY=d,cos=box.cos,sin=box.sin}
 end
 wall('west',-hx+t*.5,0,t*.5,hy);wall('east',hx-t*.5,0,t*.5,hy);wall('back',0,hy-t*.5,hx,t*.5)
 local span=(hx-door)*.5;wall('front-left',-door-span,-hy+t*.5,span,t*.5);wall('front-right',door+span,-hy+t*.5,span,t*.5)
 return out
end
F.HomeWalls=homeWalls
function F.Navigation(v,s,a)
 local nav={ground=true,continuous=true,floor=0,radius=a.spec.navigationRadius or .3,boundary=F.bounds,obstacles={}}
 for _,spec in ipairs(ns.WardenWorldScenes.Props(s))do
  local actor=s.native.actors[spec.id]
  if not spec.support and spec.collision~=false or actor and actor.collider then
  -- Wait for pending bounds, but let an explicitly failed/hidden model keep
  -- its native error report without freezing movement across the whole demo.
  local omitted=actor and(actor.failed or actor.retired or actor.editorHidden)
  if spec.house3D and not omitted and(not actor or not actor.ready)then return nil,'Waiting for neighborhood house bounds: '..spec.id end
  if actor and actor.ready and not(actor.failed or actor.retired or actor.editorHidden or actor.awaitHome)then
   local boxes=F.Hitboxes and F.Hitboxes.Footprints(s.shot,actor)or{N.Footprint(s.shot,actor)}
   for _,box in ipairs(boxes)do
    if actor.id=='player-home'and not actor.collider and box.halfX then for _,b in ipairs(homeWalls(box))do nav.obstacles[#nav.obstacles+1]=b end
    else nav.obstacles[#nav.obstacles+1]=box end
   end
  end
 end end
 return N.PeopleNavigation(nav,s.native,a)
end
function F.Camera(v)
 local s=v:ActiveRoom();local input=v.world3DInput;if not input or not s.native.frame then return end
 if F.EditorCamera.Active(v)then
  v.nativeReadingScene=nil;v.readingCameraKey=nil
  F.ApplyCamera(s,F.EditorCamera.View(v))
 elseif v.shelfFocus then ns.WardenShelfShowcase.ApplyCamera(v,s.drawWidth/s.drawHeight)
 elseif v.journalReading or v.roomBookMotion or v.cameraMix>.001 then
  if ns.WardenReadingCamera then ns.WardenReadingCamera.Apply(v,s.drawWidth,s.drawHeight,v.cameraMix)end
 else
  v.nativeReadingScene=nil;v.readingCameraKey=nil
  local view=F.EditorCamera.FollowView(v)
  F.ApplyCamera(s,view);v.world3DWideShot=view
 end
 if s.background3D then s.background3D:SetLighting(v.timeOfDay or'day');s.background3D:Update(s.native.frame,s.shot)end
end
function F.Layout(v)
 local w,h=v.frame:GetWidth(),v.frame:GetHeight();if w<1 or h<1 then return end
 local s=v:ActiveRoom();s.frame:ClearAllPoints();s.frame:SetAllPoints(v.frame);s:Layout(w,h)
 local pw=math.min(w*.88,h*1.2);v.readingPlane:ClearAllPoints();v.readingPlane:SetPoint('CENTER');v.readingPlane:SetSize(pw,pw/1.5);v.bookTargetWidth=pw
 F.Camera(v)
end
local function quad(s,points)
 local result={}
 for _,p in ipairs(points)do
  local u,v=N.ProjectNative(s.native.frame,s.shot,p[1],p[2],p[3]);if not u then return end
  local _,_,depth=N.Project(s.native.viewShot or s.shot,p[1],p[2],p[3],s.drawWidth/s.drawHeight);if not depth or depth<=.01 then return end
  result[#result+1]=u*s.drawWidth;result[#result+1]=v*s.drawHeight
 end
 return result
end
function F.Shadow(v,s,a)
 if a.awaitHome then if s.shadows[a.id]then s.shadows[a.id]:Hide()end;return end
 if not a.ready or not a.position or a.failed or a.retired or a.editorHidden or a.spec.support or a.awaitHome then return end
 local old=s.shadows[a.id]
 if not old then old=CreateFrame('Frame',nil,s.layers['contact-shadows']);old:SetAllPoints();old.texture=old:CreateTexture(nil,'ARTWORK');old.texture:SetTexture(ns.WardenWorldArt.assets['contact-shadow42'].tiles[1].path);s.shadows[a.id]=old end
 local x,y=a.position[1],a.position[2];local hx,hy
 if N.IsPerson(a)then hx,hy=.4,.28 else hx,hy=(a.bounds[4]-a.bounds[1])*a.scale*.45,(a.bounds[5]-a.bounds[2])*a.scale*.45 end
 local yaw=a.worldYaw or 0;local points={}
 for _,p in ipairs({{-hx,-hy},{hx,-hy},{-hx,hy},{hx,hy}})do points[#points+1]={x+cos(yaw)*p[1]-sin(yaw)*p[2],y+sin(yaw)*p[1]+cos(yaw)*p[2],.004}end
 local q=quad(s,points);if q then ns.WardenComposition.Quad(old.texture,old,q);old.texture:SetAlpha(.55);old:Show()else old:Hide()end
end
local function clipPolygon(points,value,inside)
 local out={};local previous=points[#points];local before=value(previous)
 for _,point in ipairs(points)do local after=value(point)
  if inside(before)~=inside(after)then
   local q=before/(before-after);local p={}
   for i=1,#point do p[i]=previous[i]+(point[i]-previous[i])*q end;out[#out+1]=p
  end
  if inside(after)then out[#out+1]=point end
  previous,before=point,after
 end
 return out
end
F.ClipPolygon=clipPolygon
-- Render interpolation for already-validated, zero-duration Live movement states.
-- Uses the existing collision/path helpers; this is not a transport or authority path.
function F.StepRemote(v,s,a,dt)
 local t=a.world3DTarget;if not t or a.seating then return end
 local p=a.position;local goal=t.position;local dx,dy=goal[1]-p[1],goal[2]-p[2]
 local distance=math.sqrt(dx*dx+dy*dy);local q=math.min(1,dt*12)
 local x,y=p[1]+dx*q,p[2]+dy*q
 local nav=F.Navigation(v,s,a);if not nav then return end
 local path={samples={{x=p[1],y=p[2],z=0},{x=x,y=y,z=0}}}
 if not N.CheckPath(path,nav)then
  local around=N.WalkPath(p,goal[1],goal[2],nav);if not around then return end
  x,y=N.Sample(around,math.min(1,distance*q/math.max(.001,around.length)))
 end
 if N.CanStep(s.native,a,p,{x,y,0})then s.native:Place(a,x,y,0,t.yaw)end
 s.native:Animate(a,distance>.03 and 4 or t.animation,1)
end
function F.Pose(v,animated)
 local U=ns.UI2
 if v.headerFlame and U.header and U.header:IsVisible()then local b=ns.WardenArt.headerFlame;v.headerFlame:Draw(b.width,b.height,v.age,1,animated)end
end
function F.Advance(v,elapsed)
 if not v.frame:IsVisible()then return end
 local dt=clamp(elapsed,0,.05);v.age=v.age+dt;v.metrics.updates=v.metrics.updates+1
 local s=v:ActiveRoom();s.native:Tick(dt,ns.DB.livingRealmAmbience~=false)
 for _,a in ipairs(s.native.order)do
  if a.buildingAttempt then
   if a.failed then a.buildingAttempt.phase='failed: '..tostring(a.status)
   elseif a.retired then a.buildingAttempt.phase='removed in editor'end
  end
  if a.ready and not(a.failed or a.retired or a.editorHidden or a.sceneHidden)then
   if a.awaitSupport then F.ActorReady(v,s,a)end
   if a.spec.homeInterior then
    if not F.HomeReady(s)then a.awaitHome=true;N.Call(a.actor,'Hide')
    elseif a.awaitHome then F.ActorReady(v,s,a)end
   end
   if a.spec.controlled and not a.spawnChecked then v:EnsurePlayerSpawn(s,a)end
   if not(a.awaitSpawn or a.awaitSupport or a.awaitHome)then N.Call(a.actor,'SetAlpha',1);N.Call(a.actor,'Show')end
   if a.spec.liveRemote and a.world3DTarget then F.StepRemote(v,s,a,dt)end
   if a.seating then v:UpdatePlayerSeat(s,a,dt)end
  elseif a.actor and(a.retired or a.editorHidden or a.sceneHidden)then N.Call(a.actor,'Hide');if s.shadows[a.id]then s.shadows[a.id]:Hide()end end
 end
 local input=v.world3DInput;local U=ns.UI2;local editor=ns.WardenSceneEditor
 local allowed=input and not U.locked and not ns.MainStorageBlocked and U.menuHidden and not(v.shelfFocus or v.journalReading or v.roomBookMotion)and not(editor and editor.active)and not InCombatLockdown()and ns.DB.livingRealmAmbience~=false
 local a=s.native.actors.attendant
 if input and F.PlayCameraAllowed(v)then F.Look(input,-.3,1.2)end
 if allowed and a and a.ready and not a.awaitSpawn then
  if not s.groundClick:IsMouseOver()or(GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())then input.keys={}end
  local forward=(input.keys.W and 1 or 0)-(input.keys.S and 1 or 0);local right=(input.keys.D and 1 or 0)-(input.keys.A and 1 or 0)
  local length=math.sqrt(forward*forward+right*right);local moved=false
  if length>0 and a.seating then if a.seating.phase~='leaving'then v:LeavePlayerSeat(s,a)end
  elseif length>0 then
   a.route=nil;a.pendingInteraction=nil
   local dx=(cos(input.yaw)*forward+sin(input.yaw)*right)/length*4*dt;local dy=(sin(input.yaw)*forward-cos(input.yaw)*right)/length*4*dt
   local p=a.position;local nav=F.Navigation(v,s,a)
   local path={samples={{x=p[1],y=p[2],z=0},{x=p[1]+dx,y=p[2]+dy,z=0}}}
   if nav and N.CheckPath(path,nav)and N.CanStep(s.native,a,p,{p[1]+dx,p[2]+dy,0})then s.native:Place(a,p[1]+dx,p[2]+dy,0,math.atan2(dy,dx));moved=true end
  end
  a.manualMovement=moved
  if not a.route and not a.seating then s.native:Animate(a,moved and 4 or 0,1)end
 else if input then input.keys={};if not F.PlayCameraAllowed(v)then input.dragging=false end end;if a then a.manualMovement=false end end
 if not F.EditorCamera.DriverActive(v)then F.EditorCamera.Tick(v,dt)end
 local W=ns.AetherLive and ns.AetherLive.World
 if W and not W.active and not(editor and editor.active)then for _,def in ipairs(W.NPCs)do if def.scene==s.key then W.NPC(v,s,def,dt)end end end
 if not F.EditorCamera.DriverActive(v)then F.Camera(v)end;F.Pose(v,ns.DB.journalReducedMotion~=true)
 F.BuildingNotice(v,s)
 for _,actor in ipairs(s.native.order)do if actor.ready and not(actor.retired or actor.editorHidden or actor.sceneHidden)then F.Shadow(v,s,actor)end end
end
function F.BindInput(v,U)
 local s=v.forest;local input={keys={},yaw=pi/2,pitch=.35,distance=14,surfaceBaseLevel=v.forest.groundClick:GetFrameLevel()};v.world3DInput=input
 local EC=F.EditorCamera
 local function clear()input.keys={};input.dragging=false;EC.Clear(v);v.frame:SetPropagateKeyboardInput(true)end
 function v:StackFieldInput()
  local floor=s.groundClick;local highest=s.layers and s.layers.native:GetFrameLevel()or input.surfaceBaseLevel
  local count=0
  local function visit(frame)
   if not frame or frame==floor or frame==v.world3DCameraBar or frame.ChatWardenModal then return end
   count=count+1;if count>2048 then return end
   highest=math.max(highest,frame:GetFrameLevel())
   if frame.GetChildren then for _,child in ipairs({frame:GetChildren()})do visit(child)end end
  end
  visit(U.stage);visit(s.frame)
  if U.window and U.stage then
   floor:SetParent(U.window);floor:ClearAllPoints();floor:SetPoint('TOPLEFT',U.stage,'TOPLEFT',0,-35);floor:SetPoint('BOTTOMRIGHT',U.stage,'BOTTOMRIGHT')
  end
  if floor.SetFixedFrameLevel then floor:SetFixedFrameLevel(false)end
  floor:SetFrameLevel(highest+1)
  if floor.SetFixedFrameLevel then floor:SetFixedFrameLevel(true)end
 end
 function v:RefreshFieldInput()
  local enabled=s.active and U.menuHidden and not EC.Active(self)and not self.shelfFocus and not self.journalReading and not self.roomBookMotion
  s.groundClick:SetShown(enabled==true);s.groundClick:EnableMouse(enabled==true);s.groundClick:EnableMouseWheel(enabled==true)
  if enabled then self:StackFieldInput()else clear()end
  if self.world3DEditSurface then EC.SyncInput(self)end
 end
 v.frame:EnableKeyboard(true);v.frame:SetPropagateKeyboardInput(true)
 v.frame:SetScript('OnKeyDown',function(receiver,key)
  if EC.Active(v)then
   local capture=EC.Allowed(v)and(key=='W'or key=='A'or key=='S'or key=='D'or key=='Q'or key=='E')
   receiver:SetPropagateKeyboardInput(not capture)
   if capture then EC.State(v).keys[key]=true end
   return
  end
  local capture=not U.locked and not ns.MainStorageBlocked and U.menuHidden and s.groundClick:IsMouseOver()and not(v.shelfFocus or v.journalReading or v.roomBookMotion)and not(ns.WardenSceneEditor and ns.WardenSceneEditor.active)and not InCombatLockdown()and not(GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())and(key=='W'or key=='A'or key=='S'or key=='D')
  receiver:SetPropagateKeyboardInput(not capture);if capture then input.keys[key]=true end
 end)
 v.frame:SetScript('OnKeyUp',function(receiver,key)
  local c=v.world3DEditCamera;local held=input.keys[key]or c and c.keys[key];input.keys[key]=nil;if c then c.keys[key]=nil end
  receiver:SetPropagateKeyboardInput(not held)
 end)
 local function begin(source)
  local state
  if EC.Active(v)then if EC.Allowed(v)then state=EC.State(v)end
  elseif F.PlayCameraAllowed(v)and s.groundClick:IsMouseOver()then state=input end
  if state then state.dragging=true;state.x,state.y=GetCursorPosition();input.rightDragStarts=(input.rightDragStarts or 0)+1;input.lastDragSource=source end
 end
 local function finish()input.dragging=false;local c=v.world3DEditCamera;if c then c.dragging=false end end
 -- Register the actual right-button gesture. The old floor only registered
 -- LeftButtonUp; directly calling its callbacks in tests missed this boundary.
 s.groundClick:RegisterForClicks('LeftButtonUp','RightButtonDown','RightButtonUp')
 s.groundClick:RegisterForDrag('RightButton')
 if s.groundClick.SetPropagateMouseClicks then s.groundClick:SetPropagateMouseClicks(false)end
 if s.groundClick.SetPropagateMouseMotion then s.groundClick:SetPropagateMouseMotion(false)end
 s.groundClick:SetScript('OnClick',function(_,button,down)if button=='LeftButton'and not down then return v:CursorSceneClick(s,'3D floor')end end)
 s.groundClick:SetScript('OnMouseDown',function(_,button)if button=='RightButton'then begin('mouse down')end end)
 s.groundClick:SetScript('OnMouseUp',function(_,button)if button=='RightButton'then finish()end end)
 s.groundClick:SetScript('OnDragStart',function()begin('registered right drag')end)
 s.groundClick:SetScript('OnDragStop',finish)
 s.groundClick:EnableMouseWheel(true);s.groundClick:SetScript('OnMouseWheel',function(_,delta)
  if EC.Active(v)then EC.Scroll(v,delta)
  elseif U.menuHidden and not U.locked and not ns.MainStorageBlocked and not InCombatLockdown()then input.distance=clamp(input.distance-delta,2,55)end
 end)
 s.groundClick:SetScript('OnLeave',function(receiver)
  -- A captured right drag may leave the floor rectangle. Release keys there;
  -- release look on button-up, hide, combat or a blocking editor form.
  input.keys={};local c=v.world3DEditCamera;if c then c.keys={}end
  if not IsMouseButtonDown('RightButton')then finish()end;(receiver or v.frame):SetPropagateKeyboardInput(true)
 end)
 v.frame:HookScript('OnHide',clear)
 v.world3DHandlers={OnKeyDown=v.frame:GetScript('OnKeyDown'),OnKeyUp=v.frame:GetScript('OnKeyUp')}
 for _,name in ipairs({'OnMouseDown','OnMouseUp','OnDragStart','OnDragStop','OnMouseWheel','OnLeave'})do v.world3DHandlers[name]=s.groundClick:GetScript(name)end
 function v:CursorSceneClick(scene,source)
  local scale=scene.frame:GetEffectiveScale();local x,y=GetCursorPosition();local left,top=scene.frame:GetLeft(),scene.frame:GetTop()
  if not left or not top or scale<=0 then return false,'Scene viewport unavailable'end
  local u,q=(x/scale-left)/scene.drawWidth,(top-y/scale)/scene.drawHeight
  local ok,why=self:ClickScene(scene,u,q);self.lastWalkStatus=ok and'Character interaction'or why
  self.lastSceneClick={scene=scene.key,u=u,v=q,accepted=ok==true,reason=why,source=source};return ok,why
 end
 v:RefreshFieldInput()
end
