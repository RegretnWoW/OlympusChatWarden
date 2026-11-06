-- Only the scene integration changes. Existing Journal, badge ownership, Live trust,
-- protocol, reconnection and session limits remain authoritative.
local _,ns=...
local F,N,C,U=ns.Fireside3D,ns.WardenNativeScene,ns.WardenRoomCatalogue,ns.UI2
local worldScale=ns.WardenWorldScale
local request=worldScale.Request
worldScale.Request=function(s,record,...)
 if F.IsScene(s)then
  if record then return false,'3D world uses native perspective; painted-depth calibration is unavailable'end
  s.worldCalibration=nil;s.pendingWorldCalibration=nil;s.native.worldCalibration=nil;return true
 end
 return request(s,record,...)
end
local rooms=C.Rooms
C.Rooms=function()return{{id=F.PRIMARY,label='Fireside Neighborhood',interior=false}}end
local connections=C.Connections
C.Connections=function(from)if from==F.PRIMARY then return{}end;return connections(from)end
local W=ns.AetherLive.World
for i,def in ipairs(W.NPCs)do def.scene=F.PRIMARY;def.worldPoints=F.npcPaths[i]end
local remote=W.Remote
W.Remote=function(v,s,p,...)
 local a=remote(v,s,p,...);local state=p.liveState
 if a and F.IsScene(s)then
  if state and a.liveApplied==state.seq and not p.gameError and state.duration==0 and not state.seat and not a.seating then
   a.route=nil;a.world3DTarget={position={unpack(state.position)},yaw=state.yaw,animation=state.animation}
  else a.world3DTarget=nil end
 end
 return a
end
local shelf=ns.WardenShelfShowcase
local render=shelf.Render
shelf.Render=function(v,...)
 if v and F.IsScene(v:ActiveRoom())and not v.shelfFocus then if v.shelfDisplay then v.shelfDisplay:Hide()end;return end
 return render(v,...)
end
local attach=ns.WardenRealm.Attach
ns.WardenRealm.Attach=function(...)
 local v=attach(...);v.currentRoomKey=F.PRIMARY
 local s=v.forest
 -- Every actor stays in the one native depth buffer, including editor placements and Live peers.
 s.native.SetLayer=function(_,a,layer)if layer~='native'then return false,'3D world actors use one shared native depth buffer'end;a.renderLayer='native';return true end
 local clicked,interact,ended=v.ClickScene,v.InteractPlayer,v.RouteEnded
 local function finish(id)
  if id=='room-book'then
   if not v.reader then local host=U.CreateJournalHost();host.reader.closedBookSide='front';v:BindReader(host.reader)end
   return v:ClickRoomBook()
  end
  return shelf.Open(v)
 end
 local function approach(id)
  local home=s.native.actors['player-home'];if not home or not home.ready or home.failed then return false,'Goldshire Inn must load before using its interior objects'end
  local a=s.native.actors.attendant;local prop=s.native.actors[id]
  if not a or not a.ready or not prop or not prop.ready then return false,'Wait for the object and your character'end
  if a.seating then return v:LeavePlayerSeat(s,a)end
  if not a.capabilities[4]then return false,'Walking animation unavailable'end
  local support=id=='room-book'and s.native.actors.desk or prop
  local box=N.Footprint(s.shot,support);local nav,why=v:GroundNavigation(s,a)
  if not box or not nav then return false,why or'Support unavailable'end
  local p=support.position;local margin=nav.radius+.2;local best
  for _,q in ipairs({{box.left-margin,p[2]},{box.right+margin,p[2]},{p[1],box.near-margin},{p[1],box.far+margin}})do
   if(a.position[1]-q[1])^2+(a.position[2]-q[2])^2<.05 then return finish(id)end
   local path=N.WalkPath(a.position,q[1],q[2],nav);if path and(not best or path.length<best.length)then best=path end
  end
  if not best then return false,'No clear route to the home object'end
  a.pendingInteraction={kind='home-object-3d',id=id};return s.native:Route(a,best,math.max(2,best.length/4),4,nav)
 end
 local function click3D(self,scene,u,y)
  if ns.WardenSceneEditor and ns.WardenSceneEditor.active then return false,'Scene editor is active'end
  if U.locked or ns.MainStorageBlocked or not U.menuHidden or self.shelfFocus or self.journalReading or self.roomBookMotion then return false,'Finish the current view first'end
  local G=ns.WardenSceneObjectControls
  for _,id in ipairs({'room-book','shelf-right'})do local a=scene.native.actors[id]
   if a and a.ready and G.ContainsPick(G.ProjectPick(scene.native,scene.shot,a),u,y)then return approach(id)end
  end
  return clicked(self,scene,u,y)
 end
 v.ClickScene=click3D
 local bindReader=v.BindReader
 v.BindReader=function(self,...)local result=bindReader(self,...);self.ClickScene=click3D;return result end
 v.InteractPlayer=function(self,scene,id)
  local prop=scene.native.actors[id];local home=scene.native.actors['player-home']
  if prop and prop.spec.homeInterior and(not home or not home.ready or home.failed or prop.awaitHome)then return false,'The Elwynn home is unavailable'end
  if id=='room-book'or id=='shelf-right'then return approach(id)end
  return interact(self,scene,id)
 end
 v.RouteEnded=function(self,scene,a,...)
  local intent=a.pendingInteraction
  if intent and intent.kind=='home-object-3d'then a.pendingInteraction=nil;return finish(intent.id)end
  return ended(self,scene,a,...)
 end
 local report=v.Report
 v.Report=function(self,...)
  local out=report(self,...);out.fireside3D={version=F.VERSION,scene=F.PRIMARY,coordinateSpace='world XYZ',instances=#self:Scenes(),houses=#F.houses,nativeViewportCount=1,legacyTravel=false,base=F.BASE,visualQualification='Elwynn WMO buildings and interior require native render verification',colliderQualification='Bounds-based doorway; align against the actual visible Goldshire Inn',elwynn=F.BuildingReport(self:ActiveRoom()),rightDragStarts=self.world3DInput.rightDragStarts,lastDragSource=self.world3DInput.lastDragSource};return out
 end
 F.Catalog.BindExistingEditor()
 F.EditorCamera.BindExistingEditor()
 return v
end
-- Direct 3D landing; regular feature tabs still open the existing UI over it.
local open=U.Open
U.Open=function(route,...)
 local page=type(route)=='table'and route.page or route
 local landing=(page==nil or page=='overview'or page=='home')and(not U.window or not U.window:IsShown())
 if landing then U.menuHidden=true;U.closingMenu=true end
 local ok,why=open(route,...)
 if landing then U.closingMenu=nil;if ok then U.menuHidden=true;U.ApplyMenuState()end end
 return ok,why
end
local select=U.SelectNavigationTab
U.SelectNavigationTab=function(id,...)
 if id=='journey'then return U.Hearth()end
 return select(id,...)
end
U.Hearth=function()
 if ns.MainStorageBlocked or U.locked or not ns.Membership.Allowed()then return false,'Fireside access is unavailable'end
 if ns.WardenSceneEditor and ns.WardenSceneEditor.active or ns.UI2LayoutEditor and ns.UI2LayoutEditor.tx then return false,'Finish editing before walking home'end
 if InCombatLockdown()then return false,'Walk home after combat'end
 U.Ensure();local v=U.realm;local s=v:ActiveRoom();local a=s.native.actors.attendant;local home=s.native.actors['player-home']
 if not a or not a.ready or not home or not home.ready or home.failed then return false,'Wait for your home and character; check the Elwynn building load status'end
 local box=N.Footprint(s.shot,home);local nav,why=v:GroundNavigation(s,a);if not nav then return false,why end
 local path;path,why=N.WalkPath(a.position,home.position[1],box.near-1,nav);if not path then return false,why end
 a.pendingInteraction=nil;local ok;ok,why=s.native:Route(a,path,math.max(2,path.length/4),4,nav)
 if ok then U.CloseMenu()end;return ok,why
end
-- The old fixed-scene cinematic is not part of the unified world. Consent/setup UI remains unchanged.
if ns.WardenWelcomeGuide then ns.WardenWelcomeGuide.NeedsWelcome=function()return false end end
ns.OpenWelcome=function()ns.Print('Welcome home. Close Menu to explore; WASD moves and right-drag rotates the 3D camera.');return true end
local event=CreateFrame('Frame');event:RegisterEvent('ADDON_LOADED');event:SetScript('OnEvent',function()F.Catalog.BindExistingEditor();F.EditorCamera.BindExistingEditor()end)

for _,entry in ipairs(U.destinations or{})do if entry[1]=='journey'then entry[2]='My Home'end end
local ensure=U.Ensure
U.Ensure=function(...)
 local f=ensure(...)
 if not f.fireside3DChrome then
  f.fireside3DChrome=true
  if U.navigation and U.navigation.journey then ns.Theme.Tooltip(U.navigation.journey,'Walk to My Home','Walk to your entrance in the same neighborhood. Your Journal is on the table inside.')end
 end
 return f
end
