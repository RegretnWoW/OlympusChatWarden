-- One contained scenic welcome. No gameplay evidence, Journal mutation or audio clock.
-- Installed models are references only; native visual acceptance remains required.
local _,ns=...
local C={VERSION=4,MAX_OWNERS=16,PAN_SECONDS=4.5,ZOOM=1.65};ns.WardenCampfireWelcome=C
C.lines={'Thank you for helping bring Fireside to life.','Our vision is a living world where every adventure becomes a story, and every story has a place to call home.'}
local N,G=ns.WardenNativeScene,ns.WardenSceneGraph
local function copy(v)return ns.WardenRoomCatalogue.Copy(v)end
local function ease(q)return G.Ease(q)end
function C.Failure(why)
 if ns.UI2Forms.Form then return ns.UI2Forms.Form({title='Campfire welcome could not start',help=tostring(why or'Native scene is not ready')..'\n\nReturn to Olympus Fields and wait for your character and firepit to finish loading. Close any editor or interaction, then try Replay again.',fields={},cancelLabel='Close'})end
end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
-- The editor's live actor is the anchor. No original screen/world coordinates
-- are used by the welcome; projection follows the actual placed book.
function C.Anchor(scene)
 local fire=scene and scene.native.actors.firepit
 if not fire or not fire.ready or fire.retired or fire.editorHidden or not fire.position then return nil,'Campfire unavailable'end
 local p=fire.position;for i=1,3 do if not finite(p[i])then return nil,'Invalid campfire placement'end end
 return{actor=fire,x=p[1],y=p[2],z=p[3],yaw=fire.yaw or 0,scale=fire.scale or 1}
end
local function sameAnchor(a,b)
 return a and b and a.actor==b.actor and math.abs(a.x-b.x)<.0001 and math.abs(a.y-b.y)<.0001 and math.abs(a.z-b.z)<.0001 and math.abs(a.yaw-b.yaw)<.0001 and math.abs(a.scale-b.scale)<.0001
end
function C.Seen(owner,write)
 -- Chronicle owns history by realm/GUID; a raw GUID remains valid for old keys.
 local S=ns.ChronicleStore
 if not S.Text(owner,193)or not S.GUID(owner:match('/(Player%-.+)$')or owner)then return nil,'Character identity unavailable'end
 local root=ns.DB and ns.DB.wardenCampfireWelcome
 if root==nil and write then root={version=1,owners={}};ns.DB.wardenCampfireWelcome=root end
 if root==nil then return false end
 if type(root)~='table'or getmetatable(root)or root.version~=1 or type(root.owners)~='table'or getmetatable(root.owners)then return nil,'Welcome state is incompatible; original retained'end
 local n=0;for k,v in pairs(root.owners)do n=n+1;if n>C.MAX_OWNERS or type(k)~='string'or #k>193 or type(v)~='boolean'then return nil,'Welcome state needs recovery; original retained'end end
 if write then if root.owners[owner]==nil and n>=C.MAX_OWNERS then return nil,'Welcome character limit'end;root.owners[owner]=true end
 return root.owners[owner]==true
end
function C.Stop(v,reason,seen)
 local m=v and v.campfireWelcome;if not m then return false end
 -- Keep the canonical save frozen until the original runtime pose is restored.
 if m.actor and m.actor.ready and m.position then
  m.actor.route=nil;m.actor.seating=nil;m.actor.pendingInteraction=nil;m.actor.manualUntil=m.manualUntil;m.actor.spec.worldYaw=m.worldYaw
  m.actor.engine:Place(m.actor,m.position[1],m.position[2],m.position[3],m.yaw)
  m.actor.route=m.route;m.actor.seating=m.seating;m.actor.pendingInteraction=m.pendingInteraction
  m.actor.engine:Animate(m.actor,m.animation or 0,m.animationRate or 1,m.animationClock or 0)
 end
 for _,a in ipairs({m.book or false,m.table or false})do if a then a.sceneHidden=true;a.engine:Retire(a)end end
 for _,saved in ipairs(m.others or{})do local a=saved.actor;if a.ready and not a.retired then a.route=saved.route;a.manualUntil=saved.manualUntil;a.engine:Animate(a,saved.animation or 0,saved.rate or 1,saved.clock or 0)end end
 v.playerState=m.playerState;v.cameraMix=m.cameraMix or 0;v.campfireWelcome=nil
 if seen then C.Seen(m.owner,true)end
 v.welcomeDriver:Hide();v.welcomeSkip:Hide();v.welcomeInk:Hide();v:Layout()
 if ns.UI2.menuHidden~=m.menuHidden and ns.UI2.window:IsVisible()then ns.UI2.SetMenuHidden(m.menuHidden)end
 if ns.WardenAudio and ns.WardenAudio.PreferencesChanged then ns.WardenAudio.PreferencesChanged()end
 v.lastCampfireWelcome={reason=reason or'Finished',completed=reason=='Finished',skipped=reason=='Skipped',ownerStateRestored=true,nativeVerification='UNVERIFIED',seconds=m.age,actualPlayer=m.actor and m.actor.spec.unit=='player' or false,anchor=m.anchor and{x=m.anchor.x,y=m.anchor.y,z=m.anchor.z,yaw=m.anchor.yaw,scale=m.anchor.scale},staging='Live firepit; collision-checked approach and book placement; projected camera target'}
 if m.replay and reason~='Finished'and reason~='Skipped'and reason~='Window closed'and reason~='Scene hidden'and reason~='Logout'and reason~='Navigation changed'then C.Failure(reason)end
 return true
end
function C.Start(v,replay)
 if not v or v.campfireWelcome then return false,'A welcome is already active'end
 local U=ns.UI2;local s=v:ActiveRoom();local a=s and s.native.actors.attendant
 if not s or s.key~='hall'then return false,'Walk to Olympus Fields before replaying the campfire welcome'end
 if not U.window:IsVisible()or not v.frame:IsVisible()or ns.Checked(ns.SafeCall(InCombatLockdown))or ns.WardenSceneEditor and ns.WardenSceneEditor.active or ns.UI2Forms.active or v.roomTravel.state or v.roomBookMotion or v.shelfFocus then return false,'Finish the current interaction before the welcome'end
 local anchor,anchorWhy=C.Anchor(s);local fire=anchor and anchor.actor
 if not a or a.spec.unit~='player'or not a.ready or not a.position or a.route or not anchor then return false,anchorWhy or'Wait for your character and campfire to be ready and idle'end
 local owner=ns.Chronicle.Owner();if not owner then return false,'Character identity unavailable'end
 if not replay then local seen,why=C.Seen(owner);if seen==nil or seen then return false,why or'Already seen'end end
 if not a.capabilities[97]or not a.capabilities[4]then return false,'This installed model lacks the required sit/walk animations'end
 if ns.DB.journalReducedMotion then local dx,dy=a.position[1]-fire.position[1],a.position[2]-fire.position[2];if dx*dx+dy*dy>6.25 then return false,'With reduced motion, approach the campfire before replaying the static welcome'end end
 -- Save before hiding UI; unchanged music requests retain their native owner/clock.
 local m={owner=owner,actor=a,scene=s,position={unpack(a.position)},yaw=a.yaw or 0,worldYaw=a.spec.worldYaw,route=a.route,seating=a.seating,pendingInteraction=a.pendingInteraction,
  animation=a.animation,animationRate=a.lastAnimationRate,animationClock=a.animationClock,manualUntil=a.manualUntil,menuHidden=U.menuHidden==true,playerState=copy(v.playerState),cameraMix=v.cameraMix,anchor=anchor,page=U.route and U.route.page,replay=replay==true,phase='prepare',age=0,elapsed=0,mix=0}
 local ok,reason=U.SetMenuHidden(true);if not ok then return false,reason end
 v.campfireWelcome=m;v.cameraMix=0;m.others={};if v.reader then v.reader:Hide()end;if v.roomBookHit then v.roomBookHit:Hide()end
 for _,other in ipairs(s.native.order)do if other~=a and other.ready and not other.spec.fileID then m.others[#m.others+1]={actor=other,route=other.route,manualUntil=other.manualUntil,animation=other.animation,rate=other.lastAnimationRate,clock=other.animationClock};other.route=nil;other.manualUntil=math.huge;other.engine:Animate(other,0,1)end end
 local engine=s.native
 if not engine.LoadProp then C.Stop(v,'Native model API unavailable');return false,'Native model API unavailable'end
 -- One normal-size book on a clear ground patch. No temporary furniture.
 local oldTable=engine.actors['welcome-table'];if oldTable then engine:Retire(oldTable)end
 m.book=engine:LoadProp({id='welcome-book',fileID=200912,custom=true,width=.8,probeObject=true,animations={0,146,147,148,149},collisionRadius=0,at={0,0,0}})
 if m.book then m.book.sceneHidden=true;N.Call(m.book.actor,'Hide')end
 v.welcomeSkip:Show();v.welcomeDriver:Show();return true,'Campfire welcome; Skip is available immediately'
end
local function placeBook(v,m)
 local nav,why=v:GroundNavigation(m.scene,m.actor);if not nav then return false,why end
 local p=m.actor.position;local target
 -- A nearby clear patch beside the seated player, away from fire/people/props.
 local check={};for k,value in pairs(nav)do check[k]=value end;check.radius=math.max(nav.radius or .3,.75)
 local facing=math.atan2(m.anchor.y-p[2],m.anchor.x-p[1])
 for i=0,23 do local angle=facing+math.pi*.5+(i%8)*math.pi*.25;local radius=1.5+math.floor(i/8)*.4;local x,y=p[1]+math.cos(angle)*radius,p[2]+math.sin(angle)*radius
  if N.CheckPath({samples={{x=x,y=y,z=0,distance=0}},length=0},check)then target={x,y,0};break end
 end
 if not target then return false,'No clear grounded place for the welcome book'end
 local book=m.book;local z=(nav.floor or 0)+.012;book.sceneHidden=nil;book.engine:Place(book,target[1],target[2],z,facing)
 book.engine:Animate(book,ns.DB.journalReducedMotion and 149 or 148,1,0);N.Call(book.actor,'Show');m.open=ns.DB.journalReducedMotion==true
 -- Frame the seated owner and actual fire together, rather than zooming into
 -- the book or using any Journal camera/state.
 local wx,wy,wz=N.World(m.scene.shot,(p[1]+m.anchor.x)*.5,(p[2]+m.anchor.y)*.5,.65);local u,q=N.ProjectNative(m.scene.native.frame,m.scene.shot,wx,wy,wz)
 if not u then return false,'Native book projection unavailable'end
 m.u,m.v=u,q;m.zoom=C.ZOOM;m.phase='read';m.elapsed=0
 if ns.WardenAudio and ns.WardenAudio.PreferencesChanged then ns.WardenAudio.PreferencesChanged()end
 return true
end
function C.Tick(v,dt)
 local m=v.campfireWelcome;if not m then return end
 if not ns.UI2.window:IsVisible()or not v.frame:IsVisible()or v:ActiveRoom()~=m.scene or ns.Chronicle.Owner()~=m.owner or ns.Checked(ns.SafeCall(InCombatLockdown))or ns.WardenSceneEditor and ns.WardenSceneEditor.active then C.Stop(v,'Interrupted');return end
 if not sameAnchor(m.anchor,C.Anchor(m.scene))then C.Stop(v,'Campfire placement changed');return end
 if v.roomTravel.state or v.roomBookMotion or v.reading then C.Stop(v,'Conflicting scene transition');return end
 dt=math.max(0,math.min(1,dt));m.age=m.age+dt;m.elapsed=m.elapsed+dt
 if m.age>90 or not m.actor.ready or m.actor.retired then C.Stop(v,'Timed out or character unavailable');return end
 if m.phase=='prepare'then
  if not m.book or m.book.failed then C.Stop(v,'Installed welcome prop unavailable');return end
  if m.book.ready then
   if not m.book.capabilities[148]or not m.book.capabilities[149]then C.Stop(v,'Installed book opening animation unavailable');return end
   local fire=m.anchor;local p=m.actor.position;local box=N.Footprint and N.Footprint(m.scene.shot,fire.actor)
   local radius=box and math.max(box.right-box.left,box.far-box.near)*.5+2 or 2.5
   local nearby=(p[1]-fire.x)^2+(p[2]-fire.y)^2<=radius^2
   if ns.DB.journalReducedMotion or nearby and m.actor.seating and m.actor.seating.id=='firepit'and m.actor.seating.phase=='hold'then
    local ok,why=placeBook(v,m);if not ok then C.Stop(v,why)end
   else m.actor.seating=nil;local ok,why=v:InteractPlayer(m.scene,'firepit');if not ok then C.Stop(v,why);return end;m.phase='approach';m.elapsed=0 end
  elseif m.elapsed>15 then C.Stop(v,'Welcome props did not load');return end
 elseif m.phase=='approach'then
  if m.actor.seating and m.actor.seating.phase=='hold'then local ok,why=placeBook(v,m);if not ok then C.Stop(v,why)end
  elseif m.elapsed>35 or not m.actor.route and not m.actor.seating then C.Stop(v,'Campfire approach interrupted')end
 elseif m.phase=='read'then
  if m.elapsed>=.4 and not m.open then m.open=true;m.book.engine:Animate(m.book,149,1)end
  local reduced=ns.DB.journalReducedMotion==true;m.mix=reduced and 1 or ease(m.elapsed/C.PAN_SECONDS)
  local ending=18;if m.elapsed>ending then m.mix=reduced and 0 or 1-ease((m.elapsed-ending)/C.PAN_SECONDS)end
  v:Layout();v.welcomeInk:SetShown(m.open and m.elapsed>(reduced and 0 or 1)and m.elapsed<ending+1);v.welcomeInk:SetAlpha(reduced and 1 or math.min(1,math.max(0,m.elapsed-1)))
  if m.elapsed>=ending+C.PAN_SECONDS then C.Stop(v,'Finished',true)end
 end
end
function C.Bind(v,U)
 if v.welcomeDriver then return end
 local driver=CreateFrame('Button',nil,U.window);driver:SetAllPoints(v.frame);driver:EnableMouse(true);driver:RegisterForClicks('LeftButtonUp');driver:SetFrameStrata('DIALOG');driver:SetFrameLevel(U.window:GetFrameLevel()+220);driver:Hide();v.welcomeDriver=driver
 local function consumeClick()
  local m=v.campfireWelcome;if not m then return false end
  -- The mouse-up that opens Replay can also reach a newly exposed floor.
  -- Consume it; a later skip must never dispatch the same click to the world.
  if m.age>=.35 then C.Stop(v,'Skipped',true)end
  return true,'Campfire welcome input'
 end
 driver:SetScript('OnClick',consumeClick)
 local ink=CreateFrame('Frame',nil,driver);ink:SetAllPoints(v.frame);ink:SetFrameLevel(driver:GetFrameLevel()+1);ink:EnableMouse(false);ink:Hide();v.welcomeInk=ink;ink.text={}
 local bars={};v.welcomeBars=bars
 for _,edge in ipairs({'TOP','BOTTOM'})do local bar=driver:CreateTexture(nil,'OVERLAY');bar:SetColorTexture(0,0,0,1);bar:SetPoint(edge..'LEFT',driver,edge..'LEFT');bar:SetPoint(edge..'RIGHT',driver,edge..'RIGHT');bars[edge]=bar end
 for i,line in ipairs(C.lines)do local f=ink:CreateFontString(nil,'OVERLAY');f:SetFont('Fonts\\FRIZQT__.TTF',16,'');f:SetTextColor(1,.94,.78,1);f:SetShadowColor(0,0,0,1);f:SetShadowOffset(1,-1);f:SetJustifyH('CENTER');f:SetJustifyV('MIDDLE');f:SetWordWrap(true);f:SetText(line);ink.text[i]=f end
 local skip=ns.UI2Components.Button(U.window,'Skip welcome',function()C.Stop(v,'Skipped',true)end,150);skip:SetPoint('RIGHT',U.restoreMenu,'LEFT',-10,0);skip:SetFrameStrata('DIALOG');skip:SetFrameLevel(U.window:GetFrameLevel()+250);skip:Hide();v.welcomeSkip=skip
 local layout,click,select,stop=v.Layout,v.ClickScene,v.Select,v.Stop
 v.Layout=function(self,...)
  local out=layout(self,...);local m=self.campfireWelcome
  if m then
   local w,h=self.frame:GetWidth(),self.frame:GetHeight();local top=math.max(64,math.min(110,h*.12));local bottom=math.max(96,math.min(138,h*.15))
   bars.TOP:SetHeight(top);bars.BOTTOM:SetHeight(bottom)
   for i,f in ipairs(ink.text)do f:ClearAllPoints();f:SetPoint(i==1 and'TOP'or'BOTTOM',ink,i==1 and'TOP'or'BOTTOM',0,i==1 and-top*.5+23 or bottom*.5-23);f:SetSize(math.max(280,w-360),46)end
  end
  if m and m.phase=='read'and m.u then
   local w,h=self.frame:GetWidth(),self.frame:GetHeight();local bw=math.max(w,h*16/9);local bh=bw*9/16;local z=1+((m.zoom or C.ZOOM)-1)*m.mix
   local wx,wy=(w-bw)/2,(h-bh)/2;local x=wx*(1-m.mix)+(w*.5-m.u*bw*z)*m.mix;local y=wy*(1-m.mix)+(h*.53-m.v*bh*z)*m.mix
   G.Place(m.scene.frame,self.frame,x,y,bw*z,bh*z);m.scene:Layout(bw*z,bh*z)
   -- Re-register cloth AFTER the cinematic's final scene transform. The normal
   -- layout above still used the previous viewport; it is not this frame's hoist.
   for _,flag in ipairs(self.flags or{})do if flag.scene==m.scene then
    local box=self:MountFlag(flag);if box then
     G.Place(flag.frame,m.scene.layers[flag.mountedLayer or flag.layer],box[1]*m.scene.drawWidth,box[2]*m.scene.drawHeight,box[3]*m.scene.drawWidth,box[4]*m.scene.drawHeight)
     -- Cloth vertices are authored in pixels, so its final size needs a draw
     -- as well as a new frame anchor. Keep the existing wind/motion policy.
     flag.cloth:Draw(flag.frame:GetWidth(),flag.frame:GetHeight(),self.age,1,flag.cloth.animated==true)
    end
   end end
   for _,a in ipairs(m.scene.native.order)do if a.ready and not a.retired then self:Shadow(m.scene,a)end end
   -- Captions stay inside the letterbox bars, outside the camera image.
  end;return out
 end
 v.ClickScene=function(self,...)if self.campfireWelcome then return consumeClick()end;return click(self,...)end
 v.Select=function(self,route,...)
  local m=self.campfireWelcome
  if m and((route and route.page)~=m.page or(self.pendingRoomKey or self.currentRoomKey or'hall')~=m.scene.key)then C.Stop(self,'Navigation changed')end
  return select(self,route,...)
 end
 v.Stop=function(self,...)if self.campfireWelcome then C.Stop(self,'Scene hidden')end;return stop(self,...)end
 driver:SetScript('OnUpdate',function(_,dt)local ok,why=pcall(C.Tick,v,dt);if not ok then C.Stop(v,'Controller error');v.lastCampfireWelcomeError=tostring(why):sub(1,180)end end)
 U.window:HookScript('OnHide',function()C.Stop(v,'Window closed')end)
 local logout=CreateFrame('Frame');logout:RegisterEvent('PLAYER_LOGOUT');logout:SetScript('OnEvent',function()C.Stop(v,'Logout')end)
 local advance=v.Advance
 v.Advance=function(self,dt)
  local out=advance(self,dt)
  if not ns.WardenWelcomeGuide and not self.campfireWelcome and not N.IsSimulator()and self.frame:IsVisible()then
   self.welcomePoll=(self.welcomePoll or 0)+dt
   if self.welcomePoll>=1 then self.welcomePoll=0;local owner=ns.Chronicle.Owner()
    self.welcomeAutoAttempted=self.welcomeAutoAttempted or{}
    if owner and not self.welcomeAutoAttempted[owner]and C.Seen(owner)==false and(self.age or 0)>=(self.welcomeRetryAt or 5)then
     self.welcomeRetryAt=(self.age or 0)+60;local ok=C.Start(self,false);if ok then self.welcomeAutoAttempted[owner]=true end
    end
   end
  end;return out
 end
 local visitors=v.rememberedVisitors
 if visitors then local visit=visitors.Advance;visitors.Advance=function(self,dt)if v.campfireWelcome then self:CheckPrivacy();return end;return visit(self,dt)end end
 local report=v.Report
 v.Report=function(self,...)
  local out=report(self,...);local m=self.campfireWelcome
  out.campfireWelcome=m and{version=C.VERSION,phase=m.phase,seconds=m.age,scene=m.scene.key,activeScene=self:ActiveRoom().key,camera='wide character and firepit; grounded book; no temporary table',zoom=m.zoom,panSeconds=C.PAN_SECONDS,homeCameraMix=self.cameraMix,inputShield=driver:IsVisible()}or self.lastCampfireWelcome
  return out
 end
end
local update=ns.WardenCanonicalPlayer.Update
ns.WardenCanonicalPlayer.Update=function(engine,a)local v=ns.UI2.realm;if v and v.campfireWelcome and a==v.campfireWelcome.actor then return end;return update(engine,a)end
local attach=ns.WardenRealm.Attach
ns.WardenRealm.Attach=function(...)local v=attach(...);C.Bind(v,ns.UI2);return v end
