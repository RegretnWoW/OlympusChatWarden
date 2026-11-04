-- V4 camera/actor registration inside the existing Hall and Journal.
-- Temporary registration surfaces are deliberate: finished art follows native staging.
local _,ns=...
local N,S,G,R,A,W=ns.WardenNativeScene,ns.WardenWorldScenes,ns.WardenSceneGraph,ns.WardenRealm,ns.WardenSceneAssets,ns.WardenWorldArt
local layerIndex={};for i,key in ipairs(S.layers)do layerIndex[key]=i end
local function available(id)return not id or not ns.WardenSanctuary or ns.WardenSanctuary.Available(id)end
local function moving()return not(ns.WardenSceneEditor and ns.WardenSceneEditor.active)and not(ns.DB and ns.DB.journalReducedMotion)and not ns.Checked(ns.SafeCall(InCombatLockdown))and(not ns.DB or ns.DB.livingRealmAmbience~=false)end
local function lab()return ns.WardenSimLab and ns.WardenSimLab.Enabled()end
local function clone(t)return ns.WardenRoomCatalogue.Copy(t)end
local function family(name)
 local s=name:lower()
 for _,row in ipairs({{'owl',{'owl','owlet'}},{'rabbit',{'rabbit','bunny','hare'}},{'bird',{'raven','hawk','falcon','eagle','crow','parrot','macaw','gull','sparrow','robin'}},{'fox',{'fox','vulpine'}},{'moth',{'moth','butterfly'}}})do
  for _,word in ipairs(row[2])do if s:find('%f[%a]'..word..'%f[%A]')then return row[1]end end
 end
end
local function species(index)
 local p=C_PetJournal;if not p then return end;local row
 if type(p.GetPetInfoTableBySpeciesID)=='function'then local ok,t=pcall(p.GetPetInfoTableBySpeciesID,index);if ok and type(t)=='table'and ns.Readable(t)then row={name=t.name or t.speciesName,displayID=t.displayID or t.creatureDisplayID}end end
 if not row and type(p.GetPetInfoBySpeciesID)=='function'then local ok,name,_,_,_,_,_,_,_,_,_,_,display=pcall(p.GetPetInfoBySpeciesID,index);if ok and type(name)=='string'then row={name=name,displayID=display}end end
 if not row or type(row.name)~='string'then return end
 if type(row.displayID)~='number'and type(p.GetDisplayIDByIndex)=='function'then local ok,d=pcall(p.GetDisplayIDByIndex,index,1);if ok then row.displayID=d end end
 if type(row.displayID)=='number'and row.displayID>0 then row.family=family(row.name);row.speciesID=index;return row end
end
function R.Attach(U,host)
 if U.realm then return U.realm end
 local v={VERSION=16,currentRoomKey='hall',scenes={},sceneOrder={},age=0,cameraMix=0,metrics={events=0,updates=0},flags={},visitors={},plants={},clock={},resolved={},nextSpecies=1};U.realm=v
 local root=G.Frame(host,0);v.frame=root;root:SetClipsChildren(true)
 local quiet=root:CreateTexture(nil,'BACKGROUND');quiet:SetAllPoints();quiet:SetTexture(ns.WardenArt.Path('TempleBackdrop'));quiet:SetVertexColor(.6,.65,.72,1)
 local plane=G.Frame(root,0);v.readingPlane=plane
 local function set(key)
  local definition=assert(S.Room(key),'Unknown room ID')
  local f=G.Frame(root,0);f:SetClipsChildren(true)
  local s={frame=f,width=1600,height=900,layers={},objects={},key=key,definition=definition,shot=definition.shot,active=false}
  for i,name in ipairs(S.layers)do local l=G.Frame(f,i*3);l:SetAllPoints();s.layers[name]=l end
  for _,spec in ipairs(definition.plates)do
   local asset=W.assets[spec[2]..'@day']or W.assets[spec[2]];assert(asset,'Missing new scenic asset '..spec[2])
   local box=clone(spec[4]);local o={id=spec[1],asset=spec[2],layer=spec[3],defaultLayer=spec[3],host=s.layers[spec[3]],box=box,baseBox=box,regions={}}
   for _,tile in ipairs(asset.tiles or{asset})do local t=o.host:CreateTexture(nil,'ARTWORK');if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false);t:SetTexelSnappingBias(0)end;o.regions[#o.regions+1]={texture=t,box=asset.tiles and{tile.x/asset.width,tile.y/asset.height,tile.w/asset.width,tile.h/asset.height}or{0,0,1,1}}end
   if o.asset:find('a2-cloud-',1,true)==1 then o.box[4]=o.box[3]*S.aspect/(asset.width/asset.height)end
   s.objects[o.id]=o
  end
  s.shadows={};s.native=N.Create(s.layers.native,s.shot);s.pending={};s.requested={};s.routeAt={}
  s.nativeAir=N.Create(s.layers['outside-native'],s.shot)
  s.native.lightOverride=clone(definition.lighting);s.nativeAir.lightOverride=clone(definition.lighting)
  s.native.layers=s.layers;s.native.baseLayer='native';s.nativeAir.layers=s.layers;s.nativeAir.baseLayer='outside-native'
  if s.native.frame then s.native.frame:SetFrameLevel(s.layers.native:GetFrameLevel());s.native.onReady=function(a)v:ActorReady(s,a)end;s.native.onRouteEnd=function(a)v:RouteEnded(s,a)end;s.native.onRouteBlocked=function(a)if a.spec.wildlife then return ns.WardenWildlife.Blocked(v,s,a)end;if a.visit then a.visit.next=(v.rememberedVisitors.clock or 0)+4 end end end
  if s.nativeAir.frame then s.nativeAir.frame:SetFrameLevel(s.layers['outside-native']:GetFrameLevel());s.nativeAir.onReady=s.native.onReady;s.nativeAir.onRouteEnd=s.native.onRouteEnd end
  if s.native.unsupported then local overlay=G.Frame(root,#S.layers*3+15);overlay:SetAllPoints();local note=overlay:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');note:SetPoint('BOTTOMRIGHT',-16,14);note:SetSize(430,36);note:SetJustifyH('RIGHT');note:SetText(N.IsSimulator()and'Simulator: native WoW actors require a real client.'or'Native scene models are unavailable on this client.');s.nativeNotice=overlay;overlay:Hide()end
  function s:LayoutArt(o)
   local b=o.box;for _,r in ipairs(o.regions)do local q=r.box;G.Place(r.texture,o.host,(b[1]+q[1]*b[3])*self.drawWidth,(b[2]+q[2]*b[4])*self.drawHeight,q[3]*b[3]*self.drawWidth,q[4]*b[4]*self.drawHeight)end
  end
  function s:Layout(w,h)self.drawWidth,self.drawHeight=w,h;self.frame:SetSize(w,h);for _,o in pairs(self.objects)do self:LayoutArt(o)end end
  function s:Mount(state)
   if not self.active then return end;self.artFallbacks={}
   for _,o in pairs(self.objects)do
    local a=W.assets[o.asset..'@'..state]or W.assets[o.asset]or W.assets[o.asset..'@day']
    if not W.assets[o.asset..'@'..state]and not W.assets[o.asset]then self.artFallbacks[#self.artFallbacks+1]=o.asset..'@'..state end
    for i,r in ipairs(o.regions)do local tile=(a.tiles or{a})[i];r.texture:SetTexture(tile.path,'CLAMP','CLAMP','LINEAR');r.texture:SetTexCoord(unpack(tile.uv or{0,1,0,1}))end
   end
   self.mountedState=state
  end
  function s:Deactivate()
   self.active=false;for _,o in pairs(self.objects)do for _,r in ipairs(o.regions)do r.texture:SetTexture(nil)end end;self.mountedState=nil
  end
  function s:SetLighting(state)self.lighting=state;self:Mount(state);for _,native in ipairs({self.native,self.nativeAir})do if native.frame then native:Lighting(state,definition.interior==true)end end end
  v.scenes[key]=s;v.sceneOrder[#v.sceneOrder+1]=s;return s
 end
 function v:Scenes()return self.sceneOrder end
 function v:ActiveRoom()return self.reading and self.studyScene or self.forest end
 v.forest=set('hall');v.studyScene=set('study');v.outdoor=v.forest.frame;v.study=v.studyScene.frame;v.room=v.study;v.homeScene=v.studyScene;v.study:Hide()
 -- Cat removed from the Study at the owner's request. Reference assets remain unused.
 v.candle={IsVisible=function()
  local a=v.studyScene.native.actors.candle
  return v.reading and v.studyScene.frame:IsVisible()and a and a.ready and not a.awaitSupport and(not ns.DB or ns.DB.journalCandle~=false)or false
 end}
 local function flag(s,kind,box,layer,stableID)
  layer=layer or'flags';local f=G.Frame(s.layers[layer],0);local art=A.assets[kind=='guild'and'guild-rendered34'or'alliance-rendered34']
  local c={id=stableID or #v.flags+1,frame=f,kind=kind,box=box,scene=s,layer=layer,defaultLayer=layer,reward=kind=='alliance'and'alliance'or nil,cloth=G.RenderedSurface(f,art,#v.flags*.83)};v.flags[#v.flags+1]=c;return c
 end
 function v:AddRoomFlags(scene)
  for _,spec in ipairs(scene.definition.flags or{})do local b=clone(spec.box);local art=A.assets[spec.kind=='guild'and'guild-rendered34'or'alliance-rendered34'];b[4]=b[4]or b[3]*S.aspect/art.aspect
   local c=flag(scene,spec.kind,b,spec.layer or'flags',spec.id);c.pole=spec.pole or'flagpole';c.defaultScale=spec.scale or 1;c.flagScale=c.defaultScale
   if scene.key=='hall'then self.guildFlag=c elseif scene.key=='study'then self.studyFlag=c end
  end
 end
 for _,scene in ipairs(v:Scenes())do v:AddRoomFlags(scene)end
 function v:BookState()
  local p=self.reader;if not p or not p.book:IsVisible()then return'hidden'end
  if p.coverMotion then return p.coverMotion.opening and'opening'or'closing'end
  return p.turnState and'turning'or p.closedBookSide and'closed'or'open'
 end
 function v:StudyCamera()return self.cameraMix>=.999999 and'desk'or self.cameraMix<=.000001 and'wide'or'transition'end
 function v:SetCameraMix(m)self.cameraMix=self.studyScene.definition.reader and math.max(0,math.min(1,m))or 0;self:Layout()end
 function v:BindReader(p)
  if not p or self.reader==p then return end;self.reader=p;p.studyCamera=self;self.cameraMix=p.closedBookSide and 0 or 1
  p.book:SetFrameLevel(math.max(p.book:GetFrameLevel(),p:GetFrameLevel()+3));self.bookDefaultLevel=p.book:GetFrameLevel()
  self:SetBookLayer(self.bookLayer or'book')
  ns.WardenRoomBook.Bind(self,p,U);self:Layout()

 end
 function v:BookAnchor()
  if not self.studyScene.definition.reader then return .5,.68,0 end
  local roomBook=self.studyScene.native.actors['room-book']
  if roomBook and roomBook.ready and not roomBook.awaitSupport and roomBook.position then local p=roomBook.position;local x,y,z=N.World(self.studyScene.shot,p[1],p[2],p[3]);local u,v,mode=N.ProjectInScene(self.studyScene.native,self.studyScene.shot,x,y,z,S.aspect);if u then self.bookProjection=mode;return u,v,p[3]end end
  local deskSpec;for _,spec in ipairs(S.Props(self.studyScene))do if spec.id=='desk'then deskSpec=spec;break end end
  local desk=self.studyScene.native.actors.desk;local z=desk and desk.position and desk.top and desk.position[3]+desk.top or deskSpec.height*(deskSpec.sizeMultiplier or 1)
  local at=desk and desk.position or deskSpec.at;local offset=self.bookOffset or(self.studyScene.definition.book or S.book).offset
  local x,y,worldZ=N.World(self.studyScene.shot,at[1]+offset[1],at[2]+offset[2],z+(offset[3]or 0));local px,py,mode=N.ProjectInScene(self.studyScene.native,self.studyScene.shot,x,y,worldZ,S.aspect)
  self.bookProjection=mode
  return px or .5,py or .68,z
 end
 function v:SyncCloseupVisibility()
  local mode=not self.campfireWelcome and(self.shelfFocus and'shelf'or self.reading and(self.journalReading or self.roomBookMotion or self.cameraMix>.001)and'journal')or nil
  self.closeupMode=mode
  for _,scene in ipairs(self:Scenes())do for _,engine in ipairs({scene.native,scene.nativeAir})do for _,a in ipairs(engine.order)do
   local was=a.closeupHidden;a.closeupHidden=N.CloseupHidden(mode,a.id,scene==self.studyScene)
   if a.closeupHidden then
    N.Call(a.actor,'Hide');if a.hit then a.hit:Hide()end;if scene.shadows[a.id]then scene.shadows[a.id]:Hide()end
   elseif was and scene.active and a.ready and not(a.retired or a.failed or a.editorHidden or a.sceneHidden or a.awaitSupport or a.awaitRegistration or a.awaitSpawn)and(not a.spec.visitor or a.route or a.wildlifeRecover)and available(a.spec.reward)then
    N.Call(a.actor,'SetAlpha',1);N.Call(a.actor,'Show')
   end
  end end end
 end
 local function layout(self)
  self:SyncCloseupVisibility()
  local w,h=root:GetWidth(),root:GetHeight();if w<1 or h<1 then return end
  local baseW=math.max(w,h*S.aspect);local baseH=baseW/S.aspect
  if not self.shelfFocus and ns.WardenShelfShowcase then ns.WardenShelfShowcase.ResetCamera(self)end
  local nativeReading=ns.WardenReadingCamera and ns.WardenReadingCamera.Apply(self,baseW,baseH,self.cameraMix)
  local nativeShelf=ns.WardenShelfShowcase and ns.WardenShelfShowcase.ApplyCamera(self,baseW/baseH)
  local nativeView=nativeReading or nativeShelf
  local bx,by,bz=self:BookAnchor();local mix=self.cameraMix;local zoom=1+2.5*mix
  local wideX,wideY=(w-baseW)/2,(h-baseH)/2
  -- One composite transform: plates, native viewport, flags and book move together.
  local x=wideX*(1-mix)+(w*.5-bx*baseW*zoom)*mix
  local y=wideY*(1-mix)+(h*.51-by*baseH*zoom)*mix
  if self.ShelfFraming and self.shelfFocus then x,y,zoom=self:ShelfFraming(baseW,baseH,w,h,wideX,wideY)end
  for _,scene in ipairs(self:Scenes())do if scene~=self.studyScene then G.Place(scene.frame,root,wideX,wideY,baseW,baseH);scene:Layout(baseW,baseH)end end
  if nativeView then G.Place(self.studyScene.frame,root,wideX,wideY,baseW,baseH);self.studyScene:Layout(baseW,baseH)
  else G.Place(self.studyScene.frame,root,x,y,baseW*zoom,baseH*zoom);self.studyScene:Layout(baseW*zoom,baseH*zoom)end
  local wideScale=(self.studyScene.definition.book or S.book).wideScale
  local pw=baseW*.23*zoom*(self.bookSize or 1)*(wideScale+(1-wideScale)*mix);local ph=pw/1.5
  -- Closed covers occupy half the open-spread frame. Center that visible half
  -- on the desk; let the physical cover/camera controller settle to a full spread.
  local side=self.reader and(self.reader.closedBookSide or self.reader.coverMotion and self.reader.coverMotion.side)
  local coverShift=side and(side=='back'and-1 or 1)*pw*.61*.25*(1-mix)or 0
  local bookCenterY=.5359375
  local px,py=nativeReading and wideX+bx*baseW or x+bx*baseW*zoom,nativeReading and wideY+by*baseH or y+by*baseH*zoom
  -- The native shot follows the real book; paper settles at the viewport centre.
  -- Keep this independent of late native projection and of menu chrome.
  px,py=px*(1-mix)+w*.5*mix,py*(1-mix)+h*.5*mix
  G.Place(plane,root,px-pw/2-coverShift,py-ph*bookCenterY,pw,ph);self.bookTargetWidth=baseW*.23*3.5*.61
  self.cameraTransform={wideWidth=baseW,zoom=zoom,x=x,y=y,book={bx,by,bz},nativeReading=nativeReading==true,nativeShelf=nativeShelf==true}
  for _,c in ipairs(self.flags)do
   local s,b=c.scene,c.box
   b=self:MountFlag(c)or b
   G.Place(c.frame,s.layers[c.mountedLayer or c.layer],b[1]*s.drawWidth,b[2]*s.drawHeight,b[3]*s.drawWidth,b[4]*s.drawHeight)
  end
  -- Preserve the reader's accepted camera contract: transform the complete book
  -- with its desk plane while keeping its logical typesetting width fixed.
  if self.reading and self.reader then ns.AthenaBookScene.PlaceBook(self.reader,self.reader:GetWidth(),self.reader:GetHeight())end
  if self.LayoutRoomBookHit then self:LayoutRoomBookHit()end
  self:Pose(moving())
 end
 function v:Layout()
  if self.layingOut then return end;self.layingOut=true
  -- Native projection/layout callbacks can fail while viewports settle. Always
  -- release the re-entry lock, including on error, so one failure cannot disable
  -- both close-up cameras for the rest of the session. Keep the error visible.
  local ok,why=pcall(layout,self);self.layingOut=nil
  if not ok then
   self.layoutErrors=(self.layoutErrors or 0)+1;self.lastLayoutError=tostring(why)
   error(why,0)
  end
 end
 function v:MountFlag(c)
  c=c or self.guildFlag;local s=c.scene;local pole=s.native.actors[c.pole or'flagpole']
  if pole and pole.editorHidden then c.mountReady=false;c.frame:Hide();return end
  -- Guild cloth is behind the walking-character viewport in both rooms.
  -- The native pole may cover its attachment; never lift the whole cloth in
  -- front of the player just because the pole uses a higher model pass.
  local layer=c.kind=='guild'and'flags'or c.layer
  if c.mountedLayer~=layer or c.frame:GetParent()~=s.layers[layer]then
   c.mountedLayer=layer;c.frame:SetParent(s.layers[layer]);c.frame:SetFrameLevel(s.layers[layer]:GetFrameLevel()+1);c.mountSignature=nil
  end
  local p=pole and pole.position;local key=p and table.concat({p[1],p[2],p[3],pole.scale or 1,pole.top or 0,pole.worldYaw or 0,c.flagScale or 1,pole.renderLayer or'native',s.native.viewRevision or 0,s.drawWidth,s.drawHeight},':')
  local box,proof=N.FlagSocket(s.native,pole,S.aspect,c.flagScale)
  if box then c.lastNativeBox=box;c.lastNativeProof=proof;c.lastNativeKey=key
  elseif key and key==c.lastNativeKey and pole.ready and not pole.awaitRegistration and c.lastNativeBox then box=c.lastNativeBox;proof=c.lastNativeProof end
  c.mountReady=box~=nil or N.IsSimulator();c.registration=proof
  if box then c.box=box;local px={box[1]*s.drawWidth,box[2]*s.drawHeight,box[3]*s.drawWidth,box[4]*s.drawHeight};local signature=table.concat({math.floor(px[1]*4+.5),math.floor(px[2]*4+.5),math.floor(px[3]*4+.5),math.floor(px[4]*4+.5)},':')
   if c.mountSignature~=signature then c.mountSignature=signature;c.frame:ClearAllPoints();c.frame:SetPoint('TOPLEFT',s.layers[layer],'TOPLEFT',box[1]*s.drawWidth,-box[2]*s.drawHeight);c.frame:SetSize(box[3]*s.drawWidth,box[4]*s.drawHeight)end
  end
  return box
 end
 function v:Prepare(s)
  if not s.native.frame then return end
  local player=s.native.actors.attendant;if s.pendingArrival and player and player.ready then self:ActorReady(s,player)end
  for _,spec in ipairs(S.Props(s))do if not s.requested[spec.id]then s.requested[spec.id]=true;s.native:Add(clone(spec))end end
  for _,group in ipairs({{S.residents[s.key],s.native,'local/'},{S.outside[s.key],s.nativeAir,'outside/'}})do for _,spec in ipairs(group[1])do
   local request=group[3]..spec.id
   if available(spec.reward)and(not spec.optionalProof or self.nativeCatDemo)and not s.requested[request]then
    local data=clone(spec);local rule=S.Route(s.key,spec.id);data.visitor=rule and not rule.persistent or false;local row=spec.family and self.resolved[spec.family]
    if not spec.family or row then
     if row then data.displayID=row.displayID;data.sourceSpeciesID=row.speciesID end
     s.requested[request]=true;if group[2].frame then local existing=group[2].actors[data.id];if data.controlled and existing and existing.retired then group[2]:RefreshPlayer(existing)else group[2]:Add(data)end end
    else s.pending[spec.family]=true end
   end
  end end
  if s.characterDirty then local a=s.native.actors.attendant;if a and a.spec.unit=='player'then s.native:RefreshPlayer(a);s.characterDirty=nil end end
 end
 function v:Resolve(s,dt)
  if not next(s.pending)or self.nextSpecies>4096 then return end
  self.lookupAt=(self.lookupAt or 0)+dt;if self.lookupAt<.10 then return end;self.lookupAt=0
  if not C_PetJournal then self.nextSpecies=4097;return end
  for _=1,32 do local row=species(self.nextSpecies);self.nextSpecies=self.nextSpecies+1;if row and row.family and not self.resolved[row.family]then self.resolved[row.family]=row end;if self.nextSpecies>4096 then break end end
  for key in pairs(s.pending)do if self.resolved[key]then s.pending[key]=nil end end;self:Prepare(s)
 end
 function v:ActorReady(s,a)
  if a.spec.showcaseSupport and a.engine.SetLayer then
   a.engine:SetLayer(a,a.renderLayer or'native');if not a.ready then return end
  end
  if a.spec.controlled and s.pendingArrival then a.spec.at=clone(s.pendingArrival);a.spec.floorUV=nil;a.spawnChecked=nil;s.pendingArrival=nil end
  a.groundOffset=not a.spec.fileID and not a.spec.flying and(s.groundOffset or S.navigation[s.key].contactOffset or 0)or 0
  local p=a.spec.at or{0,0,0}
  if a.spec.floorUV and not a.floorAnchorHeld then
   local target=a.spec.floorUV;local x,y=N.FloorPoint(a.engine.frame,s.shot,target[1],target[2],p[3])
   if not x then
    a.registrationAttempts=(a.registrationAttempts or 0)+1;a.registrationRetry=self.age+.25;a.awaitRegistration=true
    -- A screen anchor is an initial placement aid, not model-load evidence.
    -- After a bounded failure, retain a loaded static prop at its actual world
    -- anchor and collide with those real bounds. Never strand the whole floor.
    if a.registrationAttempts>=8 and a.spec.fileID and not a.spec.support and not a.spec.flying and a.position then
     a.awaitRegistration=nil;a.floorAnchorHeld=true;a.floorAnchorStatus='Authored world placement; screen anchor unavailable';p=a.position
    else
     a.motionStatus='Waiting for native floor registration';N.Call(a.actor,'Hide');return
    end
   else
    a.awaitRegistration=nil;a.floorAnchorStatus='Native screen anchor registered';a.spec.at={x,y,p[3]};p=a.spec.at
   end
  end
  if a.spec.support then
   local support=s.native.actors[a.spec.support]
   if not support or not support.ready or support.awaitRegistration then a.awaitSupport=true;N.Call(a.actor,'Hide');return end
   local offset=a.spec.supportOffset
   if offset then p={support.position[1]+offset[1],support.position[2]+offset[2],support.position[3]+support.top+(offset[3]or 0)}
   else p={p[1],p[2],support.spec.at[3]+support.top}end
  end
  if a.spec.supportYaw then local support=s.native.actors[a.spec.support];if support then a.spec.worldYaw=support.worldYaw end end
  a.engine:Place(a,p[1],p[2],p[3],a.spec.yaw or 0)
  if a.seating and a.seating.phase=='hold'then a.engine:Animate(a,a.seating.animation,1)end
  if a.spec.controlled and not a.spawnChecked then self:EnsurePlayerSpawn(s,a)end
  for _,other in ipairs(s.native.order)do if other.awaitSupport and other.spec.support==a.id then other.awaitSupport=nil;self:ActorReady(s,other)end end
  if a.spec.socialVisitor and self.rememberedVisitors then self.rememberedVisitors:Ready(a)end
  if a.id=='room-book'then a.engine:Animate(a,147,1)end
  if a.id=='desk'or a.id=='room-book'or a.id=='chair'or a.id=='flagpole'then self:Layout()end
  local rule=S.Route(s.key,a.id)
  if rule and not a.spec.controlled then s.routeAt[a.id]=self.age+(rule.firstDelay or(a.id=='cat'and 5 or a.id=='owl'and 16 or .2))end
 end
 function v:RouteEnded(s,a)
  if a.spec.wildlife then return ns.WardenWildlife.Ended(self,s,a)end
  if a.spec.socialVisitor and self.rememberedVisitors then self.rememberedVisitors:Ended(a);return end
  if a.spec.controlled then
   s.routeAt[a.id]=nil
   if a.pendingInteraction then self:SeatPlayer(s,a,a.pendingInteraction);a.pendingInteraction=nil else a.motionStatus='At selected spot'end
   return
  end
  local rule=S.Route(s.key,a.id)
  if rule and rule.fire and not a.returning then
   a.restStarted=self.age;a.restElapsed=0;a.restDuration=.65;a.restStage='facing';s.routeAt[a.id]=nil
   local fire=s.native.actors.firepit
   if fire and fire.position then local p=a.position;local target=math.atan2(fire.position[2]-p[2],fire.position[1]-p[1]);a.faceFrom=a.yaw or target;a.faceDelta=(target-a.faceFrom+math.pi)%(2*math.pi)-math.pi end
   a.engine:Animate(a,0,1,0);a.motionStatus='At firepit; turning toward the fire'
   return
  end
  s.routeAt[a.id]=self.age+(rule and rule.wait or 65)
  if rule and rule.backtrack then a.returning=not a.returning end
 end
 function v:RestAtFire(s,a,dt)
  if not a.restStage or not moving()then return end
  local stage=a.restStage;a.restElapsed=(a.restElapsed or 0)+(dt or 0);local elapsed=a.restElapsed
  if stage=='facing'and a.faceFrom then local q=math.min(1,elapsed/.65);q=q*q*(3-2*q);local p=a.position;a.engine:Place(a,p[1],p[2],p[3],a.faceFrom+a.faceDelta*q)end
  if stage=='down'and a.capabilities[96]then a.engine:Animate(a,96,1,math.min(.85,elapsed))end
  if stage=='up'and a.capabilities[98]then a.engine:Animate(a,98,1,math.min(.85,elapsed))end
  if elapsed<(a.restDuration or 0)then return end
  a.restElapsed=0
  if stage=='facing'then
   if a.capabilities[97]then a.restStage='down';a.restStarted=self.age;a.restDuration=1;a.engine:Animate(a,a.capabilities[96]and 96 or 97,1,0);a.motionStatus='At firepit; native sit sequence'
   else a.restStage='unsupported';a.restDuration=S.Route(s.key,a.id).wait or 18;a.motionStatus='At firepit; native sitting unavailable, standing rest'end
  elseif stage=='down'then a.restStage='sitting';a.restStarted=self.age;a.restDuration=S.Route(s.key,a.id).wait or 18;a.engine:Animate(a,97,1,0)
  elseif stage=='sitting'then a.restStage='up';a.restStarted=self.age;a.restDuration=1;a.engine:Animate(a,a.capabilities[98]and 98 or 0,1,0)
  else a.restStage=nil;a.returning=true;s.routeAt[a.id]=self.age+.3;a.engine:Animate(a,0,1,0)end
 end
 -- One continuous soft footprint per object, dark at its center. Native
 -- projection keeps the contact on the same floor as the model and colliders.
 function v:Shadow(s,a)
  if a.closeupHidden or a.sceneHidden then if s.shadows[a.id]then s.shadows[a.id]:Hide()end;return end
  local r=a.shadow
  if a.editorHidden or r and r.enabled==false or a.spec.effect or a.spec.flying or a.spec.support or not a.ready or a.awaitRegistration or not a.position then if s.shadows[a.id]then s.shadows[a.id]:Hide()end;return end
  local host=s.layers[a.shadowLayer or'contact-shadows']or s.layers['contact-shadows'];local root=s.shadows[a.id]
  if not root then
   root=G.Frame(host,1);root:SetAllPoints();root.broad=G.Texture(root,W.assets['contact-shadow42'].tiles[1]);s.shadows[a.id]=root
  end
  if root:GetParent()~=host then root:SetParent(host);root:SetAllPoints(host);root:SetFrameLevel(host:GetFrameLevel()+1);root.lastQuad=nil end
  local p,b=a.position,a.bounds;local yaw=a.worldYaw or 0;local offset=a.groundOffset or 0
  local movie=self.campfireWelcome;local frozen=movie and movie.phase=='read'and movie.scene==s
  local worldKey=table.concat({p[1],p[2],p[3],a.scale,yaw,offset,r and r.x or 0,r and r.y or 0,r and r.width or 0,r and r.depth or 0,r and r.opacity or .92,a.nativeOrigin and a.nativeOrigin[1]or 0,a.nativeOrigin and a.nativeOrigin[2]or 0},':')
  -- The movie pans/scales the complete scene without changing its 3D camera.
  -- Native projection pixels can lag a resized viewport by one render. Keep
  -- stationary ground quads in scene UVs throughout that one camera move.
  if frozen and root.movie==movie and root.worldKey==worldKey and root.movieUV then
   local quad={};for i,n in ipairs(root.movieUV)do quad[i]=n*(i%2==1 and s.drawWidth or s.drawHeight)end
   ns.WardenComposition.Quad(root.broad,host,quad);root.broad:SetAlpha(r and r.opacity or .92);root.broad:Show();root:Show();return
  end
  if not frozen then root.movie=nil;root.movieUV=nil end
  local signature=table.concat({p[1],p[2],p[3],a.scale,yaw,offset,s.drawWidth,s.drawHeight,a.spec.fileID or 0,a.seating and 1 or 0,a.nativeOrigin and a.nativeOrigin[1]or 0,a.nativeOrigin and a.nativeOrigin[2]or 0,a.engine.viewRevision or 0},':')
  if root.signature==signature and root.lastQuad then root:Show();return end
  local x,y=N.World(s.shot,p[1],p[2],0);local z=.004+offset;local c,sn=math.cos(yaw),math.sin(yaw)
  local hx,hy=(b[4]-b[1])*a.scale*.5,(b[5]-b[2])*a.scale*.5
  if N.IsPerson(a)and a.nativeOrigin then x,y=a.nativeOrigin[1],a.nativeOrigin[2];hx,hy=.40,.276 end
  local function quad(dx,dy,rx,ry)
   local out={};for _,q in ipairs({{-rx,-ry},{rx,-ry},{-rx,ry},{rx,ry}})do
    local lx,ly=dx+q[1],dy+q[2];local u,v=N.ProjectNative(a.engine.frame,s.shot,x+c*lx-sn*ly,y+sn*lx+c*ly,z)
    if not u then return end;out[#out+1]=u*s.drawWidth;out[#out+1]=v*s.drawHeight
   end;return out
  end
  local ratio=a.scale/(a.editorBaseScale or a.authoredBaseScale or a.scale)
  local broad=quad((r and r.x or 0)*ratio,(r and r.y or 0)*ratio,r and r.width and r.width*ratio*.5 or math.max(.15,hx*1.03),r and r.depth and r.depth*ratio*.5 or math.max(.12,hy*.8));if not broad then return end
  ns.WardenComposition.Quad(root.broad,host,broad);root.broad:SetAlpha(r and r.opacity or .92);root.broad:Show()
  root.lastQuad=broad;root.signature=signature;root:SetAlpha(1);root:Show()
  if frozen then local uv={};for i,n in ipairs(broad)do uv[i]=n/(i%2==1 and s.drawWidth or s.drawHeight)end;root.movie=movie;root.worldKey=worldKey;root.movieUV=uv end
 end
 function v:VisibleActor(s,a)
  if a.closeupHidden then return false end
  if not a.ready or a.awaitSupport or a.awaitRegistration or not s.active or not a.position then return false end
  local p=a.position;local x,y,z=N.World(s.shot,p[1],p[2],p[3]+a.top*.5);local u,v=N.ProjectInScene(a.engine,s.shot,x,y,z,S.aspect)
  if not u or u<0 or u>1 or v<0 or v>1 then return false end
  local function covered(id)
   local o=s.objects[id];if not o then return false end;local box=o.box
   local px,py=(u-box[1])/box[3],(v-box[2])/box[4];if px<0 or px>=1 or py<0 or py>=1 then return false end
   local mask=W.masks[o.asset..'@'..(s.mountedState or'day')]or W.masks[o.asset..'@day'];if not mask then return false end
   local row=mask.data[math.floor(py*mask.rows)+1];return row and row:sub(math.floor(px*mask.columns)+1,math.floor(px*mask.columns)+1)=='1'
  end
  if covered('tree')then return false end
  if a.engine==s.nativeAir then for _,id in ipairs(S.airOccluders[s.key])do if covered(id)then return false end end end
  local left,top=s.frame:GetLeft(),s.frame:GetTop();if not left or not top then return false end
  x,y=left+u*s.drawWidth,top-v*s.drawHeight
  return x>root:GetLeft()and x<root:GetRight()and y>root:GetBottom()and y<root:GetTop()
 end
 function v:ReactPet(name,reason)
  local s=self.studyScene;local a=s.native.actors[name]
  if not self.reading or self.cameraMix>.05 or not a or not a.ready or not moving()or self.age<(a.nextReactionAt or 0)then return false end
  local choices=name=='cat'and{130,61,97,0}or{130,61,0};local supported={}
  for _,id in ipairs(choices)do if a.capabilities[id]then supported[#supported+1]=id end end
  if #supported==0 then return false end
  a.reactionIndex=(a.reactionIndex or 0)%#supported+1;a.route=nil;a.manualUntil=self.age+4;a.nextReactionAt=self.age+6;s.routeAt[a.id]=self.age+18
  return a.engine:Animate(a,supported[a.reactionIndex],1,0)
 end
 function v:PetHit(s,a)
  if a.id~='cat'and not(s.key=='study'and a.id=='owl')then return end
  if not a.hit then
   a.hit=CreateFrame('Button',nil,root);a.hit:SetFrameLevel(U.stage:GetFrameLevel()+15);a.hit:RegisterForClicks('LeftButtonUp')
   a.hit:SetScript('OnClick',function()self:ReactPet(a.id,'click')end)
   ns.Theme.Tooltip(a.hit,a.id=='cat'and"Athena's cat"or"Athena's owl",'A native study resident. Click for a supported reaction.')
  end
  if not self:VisibleActor(s,a)or self.cameraMix>.05 or not self.reading then a.hit:Hide();return end
  local p=a.position;local wx,wy,wz=N.World(s.shot,p[1],p[2],p[3]);local u,v=N.ProjectInScene(a.engine,s.shot,wx,wy,wz+a.top*.5,S.aspect)
  local half=math.max(.25,a.top*.65);local l,t=N.ProjectInScene(a.engine,s.shot,wx-half,wy,wz+a.top,S.aspect);local r,b=N.ProjectInScene(a.engine,s.shot,wx+half,wy,wz,S.aspect)
  if not l or not r then a.hit:Hide();return end
  local width=math.max(24,math.abs(r-l)*s.drawWidth);local height=math.max(20,math.abs(b-t)*s.drawHeight)
  local x=s.frame:GetLeft()-root:GetLeft()+u*s.drawWidth-width/2;local y=root:GetTop()-s.frame:GetTop()+v*s.drawHeight-height/2
  G.Place(a.hit,root,x,y,width,height);a.hit:Show()
 end
 -- Fire destinations come from the loaded fire footprint plus the actor's
 -- clearance, rather than a screen point that may lie inside the fire bounds.
 function v:FirePath(s,a,nav)
  if a.returning and a.fireVisit then
   local rows={};for i=#a.fireVisit.samples,1,-1 do local p=a.fireVisit.samples[i];rows[#rows+1]={x=p.x,y=p.y,z=p.z,distance=a.fireVisit.length-p.distance}end
   return{samples=rows,length=a.fireVisit.length}
  end
  local fire=s.native.actors.firepit;local box=fire and N.Footprint(s.shot,fire)
  if not box then return nil,'Waiting for native firepit bounds'end
  local home=a.position;local side=home[1]<fire.position[1]and-1 or 1
  local x=side<0 and box.left-nav.radius-.32 or box.right+nav.radius+.32
  for _,targetX in ipairs({x,side<0 and box.right+nav.radius+.32 or box.left-nav.radius-.32})do for _,delta in ipairs({0,-1.2,1.2})do
   local y=fire.position[2]+delta
   local path,why=N.WalkPath(home,targetX,y,nav)
   if path then local clear,reason=N.CheckPath(path,nav);if clear then a.fireVisit=path;return path end;why=reason end
   a.motionStatus=why
  end end
  return nil,a.motionStatus or'No clear approach to firepit'
 end
 function v:GroundNavigation(s,a)
  local floor=S.navigation[s.key];local width=math.max(a.bounds[4]-a.bounds[1],a.bounds[5]-a.bounds[2])*a.scale
  local nav={floor=floor.floor,ground=true,continuous=true,radius=((a.spec.controlled or a.spec.socialVisitor)and(a.spec.navigationRadius or .4)or math.max(a.spec.navigationRadius or .34,math.min(.9,width*.5)))+.12,obstacles={}}
  nav.polygon=N.FloorFence(a.engine.frame,s.shot,floor.floorUV)
  if not nav.polygon then return nil,'Native floor boundary unavailable'end
  for _,spec in ipairs(S.Props(s))do if not spec.support and spec.collision~=false then local prop=s.native.actors[spec.id]
   if not spec.custom and(not prop or not prop.ready or prop.awaitRegistration)then return nil,'Waiting for furniture bounds: '..spec.id end
   if prop and prop.ready and not prop.editorHidden and not prop.retired then local box=N.Footprint(s.shot,prop);if box then nav.obstacles[#nav.obstacles+1]=box end end
  end end
  return N.PeopleNavigation(nav,s.native,a)
 end
 function v:EnsurePlayerSpawn(s,a)
  local nav,why=self:GroundNavigation(s,a);if not nav then a.awaitSpawn=true;a.motionStatus=why;return false end
  local p=a.position;local function clear(x,y)return N.CheckPath({samples={{x=x,y=y,z=0,distance=0}},length=0},nav)end
  if clear(p[1],p[2])then a.spawnChecked=true;a.awaitSpawn=nil;return true end
  -- Furniture defaults can change underneath an old spawn anchor. Find a
  -- nearby clear start BEFORE first visibility, not a teleport during walking.
  for radius=1,4 do for i=0,7 do local angle=i*math.pi*.25;local x,y=p[1]+math.cos(angle)*radius*.6,p[2]+math.sin(angle)*radius*.6
   if clear(x,y)then a.engine:Place(a,x,y,0,a.yaw);a.spawnChecked=true;a.awaitSpawn=nil;return true end
  end end
  a.awaitSpawn=true;a.motionStatus='No clear initial character position';return false
 end
 function v:SetGroundOffset(s,height)
  s.groundOffset=height
  for _,engine in ipairs({s.native,s.nativeAir})do for _,a in ipairs(engine.order)do
   if not a.spec.fileID and not a.spec.flying then a.groundOffset=height;if a.ready and a.position then engine:Place(a,unpack(a.position));if s.shadows[a.id]then s.shadows[a.id].lastQuad=nil end;self:Shadow(s,a)end end
  end end
 end
 function v:SetBookLayer(layer)
  self.bookLayer=layer
  if not self.reader then return end
  local target=layer and layer~='book'and self.studyScene.layers[layer]
  self.reader.book:SetFrameLevel(target and target:GetFrameLevel()+1 or self.bookDefaultLevel)
 end
 function v:SeatPlayer(s,a,intent)
  local prop=s.native.actors[intent.id];if not prop or not prop.ready or prop.editorHidden then a.motionStatus='Seat unavailable';return false end
  local p={unpack(a.position)};local target={unpack(p)};local yaw=a.yaw or 0
  if intent.kind=='chair'then
   target={prop.position[1],prop.position[2],prop.position[3]+prop.top*(prop.spec.seatFraction or .29)-a.top*.32+(prop.seatHeightOffset or 0)}
   yaw=(prop.worldYaw or 0)-(math.atan2(s.shot.target[2]-s.shot.position[2],s.shot.target[1]-s.shot.position[1])-math.pi*.5)
  else target[3]=target[3]+(prop.seatHeightOffset or 0);yaw=math.atan2(prop.position[2]-p[2],prop.position[1]-p[1])end
  a.seating={kind=intent.kind,id=intent.id,phase='settle',elapsed=0,duration=intent.kind=='chair'and 1.1 or 1,approach=p,from=p,to=target,fromYaw=a.yaw or yaw,delta=(yaw-(a.yaw or yaw)+math.pi)%(2*math.pi)-math.pi,animation=intent.animation}
  a.spec.worldYaw=nil;a.engine:Animate(a,intent.kind=='chair'and 4 or a.capabilities[96]and 96 or intent.animation,1)
  a.motionStatus='Taking a seat';return true
 end
 function v:UpdatePlayerSeat(s,a,dt)
  local state=a.seating;if not state or state.phase=='hold'or not moving()then return end
  state.elapsed=math.min(state.duration,state.elapsed+dt);local q=state.elapsed/state.duration;q=q*q*(3-2*q)
  local p,t=state.from,state.to
  local target={p[1]+(t[1]-p[1])*q,p[2]+(t[2]-p[2])*q,p[3]+(t[3]-p[3])*q}
  if not N.CanStep(a.engine,a,a.position,target)then state.elapsed=math.max(0,state.elapsed-dt);a.motionStatus='Waiting for chair clearance';return end
  a.engine:Place(a,target[1],target[2],target[3],state.fromYaw+state.delta*q)
  if state.elapsed<state.duration then return end
  if state.phase=='leaving'then
   a.seating=nil;a.engine:Animate(a,0,1);if a.spec.socialVisitor then if a.visit then a.visit.next=(self.rememberedVisitors.clock or 0)+1 end;return end;local after=state.after;if after then self:ClickScene(s,after[1],after[2])end
  else state.phase='hold';a.engine:Animate(a,state.animation,1);a.motionStatus=state.kind=='chair'and'Sitting on chair'or'Sitting at fire'end
 end
 function v:LeavePlayerSeat(s,a,u,y)
  local state=a.seating;if not state then return false end
  state.phase='leaving';state.elapsed=0;state.duration=.85;state.from={unpack(a.position)};state.to={unpack(state.approach)};state.fromYaw=a.yaw or 0;state.delta=0;state.after=u and{u,y}or nil
  a.engine:Animate(a,state.kind=='fire'and a.capabilities[98]and 98 or 4,1);a.motionStatus='Standing up';return true
 end
 function v:InteractPlayer(s,id)
  local a=s.native.actors.attendant;local prop=s.native.actors[id]
  if not a or not a.ready or not prop or not prop.ready or prop.editorHidden then return false,'Character or seat is not ready'end
  if not moving()or ns.WardenSceneEditor and ns.WardenSceneEditor.active or self.reading and self.cameraMix>.001 then return false,'Scene interaction is paused'end
  local kind=prop.spec.interaction or(id=='chair'and'chair'or id=='firepit'and'fire');if not kind then return false,'Not a seat'end
  if a.seating and a.seating.id==id and a.seating.phase~='leaving'then return true end
  local animation=kind=='fire'and a.capabilities[97]and 97 or nil
  if kind=='chair'then for _,id in ipairs({102,103,104})do if a.capabilities[id]then animation=id;break end end end
  if not animation or not a.capabilities[4]then return false,'Required sitting or walking animation unavailable'end
  local nav,why=self:GroundNavigation(s,a);if not nav then return false,why end
  local box=N.Footprint(s.shot,prop);local p=prop.position;local margin=nav.radius+.15
  local candidates={{box.left-margin,p[2],0},{box.right+margin,p[2],0},{p[1],box.near-margin,0},{p[1],box.far+margin,0}}
  local best;for _,point in ipairs(candidates)do local path=N.WalkPath(a.position,point[1],point[2],nav);if path and(not best or path.length<best.length)then best=path end end
  if not best then return false,'No clear approach to seat'end
  a.seating=nil;a.restStage=nil;a.spec.worldYaw=nil;a.pendingInteraction={kind=kind,id=id,animation=animation};s.routeAt[a.id]=nil
  local yes;yes,why=a.engine:Route(a,best,math.max(2,best.length/N.WALK_SPEED+.65),4,nav)
  if not yes then a.pendingInteraction=nil;return false,why end
  self:RefreshEffects();return true
 end
 function v:PickSceneObject(s,u,y)
  for _,spec in ipairs(S.Props(s))do if spec.interaction then local id=spec.id;local a=s.native.actors[id]
  if a and a.ready and not a.editorHidden then
  local C=ns.WardenSceneObjectControls
  if C.ContainsPick(C.ProjectPick(s.native,s.shot,a),u,y)then return id end
  end end end
 end
 function v:ClickScene(s,u,y)
  if not s or not s.active or not root:IsVisible()or not moving()or self.reading and self.cameraMix>.001 then return false,'Scene interaction is paused'end
  local a=s.native.actors.attendant
  if a and a.seating then
   local id=self:PickSceneObject(s,u,y);if id==a.seating.id and a.seating.phase~='leaving'then return true end
   return self:LeavePlayerSeat(s,a,u,y)
  end
  local id=self:PickSceneObject(s,u,y);if id then return self:InteractPlayer(s,id)end
  return self:MovePlayer(s,u,y)
 end
 function v:MovePlayer(s,u,positionY)
  if not s or not s.active or not root:IsVisible()or(ns.WardenSceneEditor and ns.WardenSceneEditor.active)or self.reading and self.cameraMix>.001 then return false,'Ground movement is available in the wide scene'end
  if not moving()then return false,'Scene motion is paused'end
  local a=s.native.actors.attendant
  if not a or not a.spec.controlled or not a.ready or a.failed or a.editorHidden or a.awaitRegistration then return false,'Current character model is not ready'end
  if not a.capabilities[4]then return false,'Walking is unavailable for this model'end
  local x,y=N.FloorPoint(s.native.frame,s.shot,u,positionY,0);if not x then return false,'Native ground projection unavailable'end
  local nav,why=self:GroundNavigation(s,a);if not nav then return false,why end
  local path;path,why=N.WalkPath(a.position,x,y,nav);if not path then return false,why end
  -- Replacing a click replaces one finite scene route, never adds a command queue.
  local yes;yes,why=a.engine:Route(a,path,math.max(2,path.length/N.WALK_SPEED+.65),4,nav)
  if yes then a.spec.worldYaw=nil;a.pendingInteraction=nil;a.restStage=nil;a.returning=nil;s.routeAt[a.id]=nil;a.motionStatus='Walking to selected spot';self:RefreshEffects()end
  return yes,why
 end
 local function groundInput(s)
  local b=CreateFrame('Button',nil,s.layers.native);s.groundClick=b;b:SetAllPoints();b:SetFrameLevel(s.layers.native:GetFrameLevel()+1);b:RegisterForClicks('LeftButtonUp')
  b:SetScript('OnClick',function()
   local scale=s.frame:GetEffectiveScale();local x,y=GetCursorPosition();local left,top=s.frame:GetLeft(),s.frame:GetTop()
   if left and top and scale>0 then local ok,why=v:ClickScene(s,(x/scale-left)/s.drawWidth,(top-y/scale)/s.drawHeight);v.lastWalkStatus=ok and'Character interaction'or why;v.sceneClickCount=(v.sceneClickCount or 0)+1;s.clickCount=(s.clickCount or 0)+1;v.lastSceneClick={scene=s.key,u=(x/scale-left)/s.drawWidth,v=(top-y/scale)/s.drawHeight,accepted=ok==true,reason=why} end
  end)
 end
 for _,scene in ipairs(v:Scenes())do groundInput(scene)end
 function v:EnsureRoom(key)
  if self.scenes[key]then return self.scenes[key]end
  if not ns.WardenRoomCatalogue.HasRoom(key)then return nil,'Unknown room'end
  local scene=set(key);groundInput(scene);self:AddRoomFlags(scene);scene:SetLighting(self.timeOfDay or'day');scene.frame:Hide();return scene
 end
 function v:OpenRoom(key,arrival)
  if ns.WardenSceneEditor and ns.WardenSceneEditor.active then return false,'Close the scene editor before travelling'end
  if self.roomBookMotion or self.reader and self.reader.turnState or self.reading and self.cameraMix>.001 or ns.Checked(ns.SafeCall(InCombatLockdown))then return false,'Finish the current interaction before travelling'end
  if arrival then if type(arrival)~='table'or #arrival~=3 then return false,'Invalid arrival'end;for i=1,3 do local n=arrival[i];if type(n)~='number'or n~=n or math.abs(n)>(i==3 and 8 or 80)then return false,'Invalid arrival'end end end
  local scene,why=self:EnsureRoom(key);if not scene then return false,why end
  local previous=self.roomOverride;scene.pendingArrival=arrival and clone(arrival)or nil;self.roomOverride=key~='hall'and key or nil;self.pendingRoomKey=key
  local route=clone(U.route or{page='overview'});route.sceneRoom=key
  local ok,why=U.Open(route);self.pendingRoomKey=nil
  if not ok or self:ActiveRoom()~=scene then self.roomOverride=previous;scene.pendingArrival=nil;return false,why or'Room navigation was refused'end
  self.roomBookMotion=nil
  if self.reader then
   -- Destination preparation may start the legacy reader's cover controller.
   -- A room visit enters its settled wide endpoint, not a queued book motion.
   self.reader:CancelPageTurn()
   if scene.definition.reader then local reduced=ns.DB.journalReducedMotion;ns.DB.journalReducedMotion=true;self.reader:CloseBook('front');ns.DB.journalReducedMotion=reduced
   else self.cameraMix=0;self.reader:Hide();if self.roomBookHit then self.roomBookHit:Hide()end end
  end
  return true
 end
 function v:StartActor(s,a)
  if a.spec.wildlife then return ns.WardenWildlife.Start(self,s,a)end
  if a.spec.socialVisitor then s.routeAt[a.id]=nil;return false,'Remembered visits are managed privately'end
  if a.spec.controlled then s.routeAt[a.id]=nil;return false,'Click clear ground to move your character'end
  local rule=S.Route(s.key,a.id);if not rule or not a.ready or a.failed or a.awaitSupport or a.awaitRegistration then return false end
  if a.route then return true end
  local animation=rule.animation
  if rule.animations then for _,candidate in ipairs(rule.animations)do if a.capabilities[candidate]then animation=candidate;break end end end
  if not animation or not a.capabilities[animation]then a.motionStatus='Required native animation unavailable';s.routeAt[a.id]=nil;return false end
  local nav
  if rule.ground then
   local floor=S.navigation[s.key];local width=math.max(a.bounds[4]-a.bounds[1],a.bounds[5]-a.bounds[2])*a.scale
   nav={boundary=floor.boundary,floor=floor.floor,ground=true,continuous=true,radius=math.max(a.spec.navigationRadius or .34,math.min(.9,width*.5))+.12,obstacles={}}
   if floor.floorUV then nav.polygon=N.FloorFence(a.engine.frame,s.shot,floor.floorUV)
    if not nav.polygon then a.motionStatus='Native floor boundary unavailable';s.routeAt[a.id]=nil;return false end
   end
   for _,spec in ipairs(S.Props(s))do
    if not spec.support then local prop=s.native.actors[spec.id]
     if not prop or not prop.ready or prop.awaitRegistration then
      a.motionStatus='Waiting for furniture bounds: '..spec.id
      if prop and prop.failed then s.routeAt[a.id]=nil else s.routeAt[a.id]=self.age+1 end;return false
     end
     local box=N.Footprint(s.shot,prop);if box then nav.obstacles[#nav.obstacles+1]=box end
    end
   end
  end
  local path,why
  if rule.fire then path,why=self:FirePath(s,a,nav)
  else
   local curves={};local z=0
   if rule.support then local support=s.native.actors[rule.support];if not support or not support.ready then return false end;z=support.position[3]+support.top end
   for i=1,#rule.curves do
    local p=rule.curves[a.returning and #rule.curves-i+1 or i];curves[i]={}
    for j=1,4 do local source=p[a.returning and 5-j or j];local x,y,height=source[1],source[2],source[3]
     if rule.viewDepth then x,y,height=N.ViewPointAtDepth(a.engine.frame,s.shot,x,y,rule.viewDepth)
      if not x then a.motionStatus='Native flight-plane projection unavailable';s.routeAt[a.id]=nil;return false end
     elseif rule.floorUV or rule.screen then x,y=N.FloorPoint(a.engine.frame,s.shot,x,y,source[3])
      if not x then a.motionStatus='Native projection unavailable';s.routeAt[a.id]=nil;return false end
     elseif rule.relativeSupport then local support=s.native.actors[rule.support];x,y=x+support.position[1],y+support.position[2]end
     curves[i][j]={x,y,height+z}
    end
   end
   path,why=N.Path(curves)
  end
  if not path then a.motionStatus=why;s.routeAt[a.id]=nil;return false end
  if not rule.persistent then
   -- Use the very same native camera as the visible models. A mathematical
   -- preview previously accepted endpoints that were still visible natively.
   for _,point in ipairs({path.samples[1],path.samples[#path.samples]})do
    local x,y,z=N.World(s.shot,point.x,point.y,point.z);local u,v=N.ProjectNative(a.engine.frame,s.shot,x,y,z)
    if not u or(u>-.10 and u<1.10 and v>-.10 and v<1.10)then a.motionStatus='Visitor must enter/leave offscreen';s.routeAt[a.id]=nil;return false end
   end
  end
  local duration=rule.speed and math.max(3,path.length/rule.speed+.65)or rule.duration
  local yes,reason=a.engine:Route(a,path,duration,animation,nav);a.motionStatus=yes and'checked scene route; real floor and prop clearance'or reason
  s.routeAt[a.id]=nil
  if yes then self.metrics.events=self.metrics.events+1 end;return yes
 end
 function v:Pose(animated)
  for _,s in ipairs(self:Scenes())do if s.active and s.drawWidth then
   for _,entry in ipairs({{'cloud-far-a',0,1.15,.00065},{'cloud-far-b',1,1.15,.00065},{'cloud-near-a',0,1.45,.00105},{'cloud-near-b',1,1.45,.00105}})do
    local o=s.objects[entry[1]];if o then local base=o.baseBox;local x=base[1]
    if o.asset:find('a2-cloud-',1,true)==1 then
     -- Distinct clouds wrap only after leaving the viewport completely.
     if animated then local margin=.025;local span=1+base[3]+2*margin;local speed=entry[4]*.6;x=(base[1]+base[3]+margin-self.age*speed)%span-base[3]-margin end
     local tint=s.lighting=='night'and{.24,.31,.48,1}or s.lighting=='dusk'and{.92,.66,.52,1}or s.lighting=='dawn'and{1,.87,.79,1}or{1,1,1,1}
     for _,r in ipairs(o.regions)do r.texture:SetVertexColor(unpack(tint))end
    else local drift=animated and(self.age*entry[4])%1 or 0;x=base[1]-drift*base[3]end
    o.box={x,base[2],base[3],base[4]};s:LayoutArt(o)
   end end
  end end
  for i,c in ipairs(self.flags)do c.frame:SetShown(not self.closeupMode and not c.editorHidden and available(c.reward)and c.mountReady~=false);if c.scene.frame:IsVisible()and c.frame:IsShown()then c.cloth:Draw(c.frame:GetWidth(),c.frame:GetHeight(),animated and self.age or 0,1,animated);if animated and ns.WardenAudio then ns.WardenAudio.Actor('scene-cloth-'..i,c.kind,c.frame,'gust',self.age+i*.81,12,c.frame:IsVisible())end end end
  if self.headerFlame and U.header:IsVisible()then local b=ns.WardenArt.headerFlame;self.headerFlame:Draw(b.width,b.height,self.age,1,animated)end
 end
 function v:Advance(dt)
  if not root:IsVisible()then return end;dt=math.max(0,math.min(.25,dt));self.age=self.age+dt;self.metrics.updates=self.metrics.updates+1
  self:SyncCloseupVisibility()
  if self.rememberedVisitors then self.rememberedVisitors:CheckPrivacy()end
  -- Book transitions use one visible-only driver, independent of ambient motion.
  local registering=false;local s=self.reading and self.studyScene or self.forest;if s.active then self:Resolve(s,dt)
  if s.native.frame and not s.projectionReady and self.age>=(s.projectionAt or 0)then
   s.projectionAt=self.age+.2;s.projectionAttempts=(s.projectionAttempts or 0)+1
   local u=N.ProjectNative(s.native.frame,s.shot,unpack(s.shot.target))
   if u then s.projectionReady=true;self:Layout()elseif s.projectionAttempts>=8 then s.projectionReady='unavailable'end
  end
  for _,native in ipairs({s.native,s.nativeAir})do if native.frame then
   native:Tick(dt,moving())
   for _,a in ipairs(native.order)do
    if a.spec.controlled and a.ready and not a.spawnChecked then self:EnsurePlayerSpawn(s,a)end
    if a.awaitRegistration and(a.registrationAttempts or 0)<8 then
     if self.age>=(a.registrationRetry or 0)then self:ActorReady(s,a)end
     if a.awaitRegistration and(a.registrationAttempts or 0)<8 then registering=true end
    end
    if a.closeupHidden then N.Call(a.actor,'Hide');if s.shadows[a.id]then s.shadows[a.id]:Hide()end;if a.hit then a.hit:Hide()end
    elseif a.retired or a.sceneHidden or a.editorHidden or a.failed or a.spec.visitor and not a.route and not a.wildlifeRecover and not(ns.WardenSceneEditor and ns.WardenSceneEditor.active)or not available(a.spec.reward)or a.spec.optionalProof and not self.nativeCatDemo or a.id=='candle'and ns.DB and ns.DB.journalCandle==false then N.Call(a.actor,'Hide');a.route=nil;if a.spec.visitor and not a.editorHidden and not a.failed and available(a.spec.reward)and moving()and s.routeAt[a.id]and self.age>=s.routeAt[a.id]then self:StartActor(s,a)end;if s.shadows[a.id]then s.shadows[a.id]:Hide()end;if a.hit then a.hit:Hide()end
    elseif a.ready and not a.awaitSupport and not a.awaitRegistration and not a.awaitSpawn then
     N.Call(a.actor,'SetAlpha',1);N.Call(a.actor,'Show')
     if a.spec.controlled or a.spec.socialVisitor then self:UpdatePlayerSeat(s,a,dt)end
     self:RestAtFire(s,a,dt)
     if self.age>=(a.nextShadowAt or 0)then a.nextShadowAt=self.age+.08;self:Shadow(s,a)end
     if a.manualUntil and self.age>=a.manualUntil then a.manualUntil=nil;native:Animate(a,0,1,0)end
     if moving()and not a.manualUntil and not a.restStage and s.routeAt[a.id]and self.age>=s.routeAt[a.id]then self:StartActor(s,a)end
     if self.age>=(a.nextHitUpdate or 0)then a.nextHitUpdate=self.age+.10;self:PetHit(s,a)end
     if ns.WardenAudio and({cat=true,owl=true,bird=true,rabbit=true,fox=true,stag=true,moth=true,wizard=true})[a.id]then ns.WardenAudio.Actor('native-'..s.key..'-'..a.id,a.id,native.frame,a.route and(a.spec.flying and'flight'or'traverse')or a.manualUntil and'react'or a.id=='owl'and'perch'or'rest',a.route and a.route.elapsed or self.age,8,moving()and self:VisibleActor(s,a))end
    end
   end
  end end end
  if self.rememberedVisitors and s==self.forest and s.active and moving()then self.rememberedVisitors:Advance(dt)end
  if self.age>=(self.nextFlagMount or 0)then self.nextFlagMount=self.age+.10;for _,c in ipairs(self.flags)do if c.scene.active then self:MountFlag(c)end end end
  self:Pose(moving())
  if not moving()and not(registering or s.native.loading or s.nativeAir.loading or next(s.pending)and self.nextSpecies<=4096)then root:SetScript('OnUpdate',nil)end
 end
 function v:StopActors()for _,s in ipairs(self:Scenes())do for _,native in ipairs({s.native,s.nativeAir})do for _,a in ipairs(native.order)do a.route=nil;a.restStage=nil;if native.frame then native:Animate(a,0,1,0)end end end;s.routeAt={}end end
 function v:Stop()
  root:SetScript('OnUpdate',nil);for _,s in ipairs(self:Scenes())do for _,native in ipairs({s.native,s.nativeAir})do if native.frame then native:Pause(true)end;for _,a in ipairs(native.order)do if a.hit then a.hit:Hide()end end end end
  if ns.WardenAudio then ns.WardenAudio.Scene(nil,nil)end
 end
 function v:RefreshEffects()
  if not root:IsVisible()then self:Stop();return end
  local s=self.reading and self.studyScene or self.forest
  local scenic=true -- Shared Hall environment behind every non-Hearth destination.
  for _,other in ipairs(self:Scenes())do
   other.active=scenic and other==s;other.frame:SetShown(other.active);if other.nativeNotice then other.nativeNotice:SetShown(other.active)end
   other.groundClick:EnableMouse(other.active and other.native.frame~=nil and moving()and not self.shelfFocus and not(self.reading and(self.cameraMix>.001 or self.roomBookMotion~=nil)))
   if not other.active then for _,native in ipairs({other.native,other.nativeAir})do for _,a in ipairs(native.order)do if a.hit then a.hit:Hide()end end end end
   if other.active then if other.mountedState~=other.lighting then other:Mount(other.lighting or'day')end;self:Prepare(other)else other:Deactivate()end
   for _,native in ipairs({other.native,other.nativeAir})do if native.frame then native:Show(other.active);native:Pause(not other.active or not moving())end end
  end
  local q=ns.WardenSanctuary;local preview=q and(q.preview or q.ActiveBypass())
  if not self.rewardStatus then local overlay=G.Frame(root,#S.layers*3+20);overlay:SetAllPoints();self.rewardStatus=overlay:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');self.rewardStatus:SetPoint('BOTTOMLEFT',14,14);self.rewardStatus:SetText('Preview — Rewards Not Yet Earned');self.rewardStatus:SetTextColor(1,.83,.48)end
  self.rewardStatus:SetShown(preview==true)
  if self.SyncRoomBook then self.SyncRoomBook()end
  if self.StackStudyInput then self:StackStudyInput()end
  if self.RefreshFieldInput then self:RefreshFieldInput()end
  self:Pose(moving());root:SetScript('OnUpdate',function(_,dt)
   local ok,why=pcall(self.Advance,self,dt);if not ok then self:Stop();self.lastError=tostring(why)end
  end)
  if ns.WardenAudio then ns.WardenAudio.Scene(self,s.definition.interior and'study'or'forest');ns.WardenAudio.PreferencesChanged()end
 end
 function v:ApplyLighting(state)self.timeOfDay=state;for _,scene in ipairs(self:Scenes())do scene:SetLighting(state)end;for _,c in ipairs(self.flags)do c.cloth.tint={ns.WardenSceneLighting.ActorTint(state,c.scene.definition.interior==true)}end end
 function v:Select(route,reading,immersive)
  local q=ns.WardenSanctuary;if q and q.preview and not q.previewSwitch and q.previewRoute and q.previewRoute~=route then q.ExitPreview()end
  if self.previewRoute and self.previewRoute~=route then self.previewRoute=nil end
  local key=self.pendingRoomKey or(q and q.previewSwitch and route.sceneRoom)or self.currentRoomKey or'hall';self.currentRoomKey=key
  local home=key~='hall';local changed=self.reading~=home;if changed then self:Stop()end;self.reading=home;self.immersive=immersive==true;self.destination=route.page
  -- Every scene may retain a reusable viewport slot, but inactive local-player
  -- models are cleared. Only this room owns the canonical player presentation.
  for _,other in ipairs(self:Scenes())do if other.key~=key then local a=other.native.actors.attendant
   if a and a.actor and a.spec.controlled and not a.retired and other.native.Retire then other.native:Retire(a);a.position=nil;other.requested['local/attendant']=nil end
  end end
  if self.reading then local selected=self:EnsureRoom(key);if selected~=self.studyScene then self:Stop();self.studyScene=selected;self.study=selected.frame;self.room=self.study;self.cameraMix=0;self.bookOffset=selected.bookOffset;self.bookSize=selected.bookSize end end
  local session=key
  -- Menu chrome overlays one stable world viewport. Toggling it must never
  -- resize the ModelScenes, shift floor registration or move the camera.
  root:ClearAllPoints();root:SetPoint('TOPLEFT',0,0);root:SetPoint('BOTTOMRIGHT',0,30)
  self.forest.frame:SetShown(not self.reading);self.studyScene.frame:SetShown(self.reading)
  if session and self.sceneSession~=session then self:ApplyLighting(ns.WardenSceneLighting.Open())end;self.sceneSession=session
  if self.reading and not U.journalHost and U.CreateJournalHost then U.CreateJournalHost()end
  if self.reading and U.journalHost then
   if changed then U.journalHost.reader.closedBookSide='front';self.cameraMix=0 end
   self:BindReader(U.journalHost.reader)
  end
  if changed and not self.reading and self.roomBookMotion then local m=self.roomBookMotion;self.roomBookMotion=nil;self.reader.closedBookSide=m.opening and nil or m.side;self.cameraMix=m.opening and 1 or 0 end
  if not self.reading and(self.previewRoute==route or route.page=='journey')then U.canvas:Hide()end
  self:Layout();self:RefreshEffects()
 end
 function v:Preview()if not lab()then return false end;self.previewRoute=U.route;self:RefreshEffects();if not self.reading then U.canvas:Hide()end;return true end
 function v:Start(id)
  if not lab()then return false end;local s=self.reading and self.studyScene or self.forest
  if id=='cat'then return false,'Cat removed from Study'end
  local a=s.native.actors[id]or s.nativeAir.actors[id];return a and self:StartActor(s,a)or false
 end
 function v:Demonstrate(id)
  if id=='cat-stretch'or id=='cat-groom'then return false,'No verified native stretch/groom mapping for this installed model.'end
  if id=='cat'then return self:Start('cat')end
  if id=='owl-perch'then return self:ReactPet('owl','preview')end
  return self:Start(id=='owl-flight'and'owl'or id)
 end
 function v:BeginShowcase()self:Prepare(self.reading and self.studyScene or self.forest);for _,s in ipairs(self:Scenes())do for _,native in ipairs({s.native,s.nativeAir})do for _,a in ipairs(native.order)do s.routeAt[a.id]=self.age+.1 end end end;self:RefreshEffects()end
 function v:EndShowcase()self:StopActors()end
 function v:Report()
  local function info(s)local flag;for _,c in ipairs(self.flags)do if c.scene==s then flag=c;break end end;return{localActors=s.native.frame and s.native:Report()or s.native.status,outsideActors=s.nativeAir.frame and s.nativeAir:Report()or s.nativeAir.status,lighting=s.lighting,artFallbacks=s.artFallbacks,layerOrder=S.layers,legacy2DActors=false,contactShadows=true,clicks=s.clickCount or 0,flagSocket=flag and flag.registration,flagLayer=flag and flag.mountedLayer}end
  local rooms={};for _,s in ipairs(self:Scenes())do rooms[s.key]=info(s)end
  return{version=self.VERSION,stage='integrated hybrid scene',activeRoom=self:ActiveRoom().key,registeredRooms=ns.WardenRoomCatalogue.Rooms(),rooms=rooms,artStatus=S.artStatus,baseline='e19a4c63a86e607a83c1b9627dcc997de6d058a2',hall=rooms.hall,study=rooms.study,bookProjection=self.bookProjection,lastError=self.lastError,ownerCat='Removed from Study at owner request',rememberedVisitors=self.rememberedVisitors and self.rememberedVisitors:Report(),wildlife=ns.WardenWildlife.Report(self),roomBook=self.lastRoomBookTransition,sceneInput={clicks=self.sceneClickCount or 0,last=self.lastSceneClick,status=self.lastWalkStatus,studyEnabled=self.studyScene.groundClick:IsMouseEnabled(),motionAllowed=moving(),editorActive=ns.WardenSceneEditor and ns.WardenSceneEditor.active==true,cameraMix=self.cameraMix,roomBookAnimating=self.roomBookMotion~=nil,studyLevel=self.studyScene.groundClick:GetFrameLevel()}}
 end
 root:HookScript('OnHide',function()v:Stop()end);root:HookScript('OnShow',function()v:ApplyLighting(ns.WardenSceneLighting.Open());v:RefreshEffects()end);root:HookScript('OnSizeChanged',function()v:Layout()end)
 local events=CreateFrame('Frame',nil,root);events:RegisterEvent('PLAYER_REGEN_DISABLED');events:RegisterEvent('PLAYER_REGEN_ENABLED');events:RegisterEvent('PLAYER_EQUIPMENT_CHANGED');events:RegisterEvent('UNIT_MODEL_CHANGED')
 events:SetScript('OnEvent',function(_,event,unit)
  if event=='PLAYER_EQUIPMENT_CHANGED'or event=='UNIT_MODEL_CHANGED'and unit=='player'then
   for _,scene in ipairs(v:Scenes())do scene.characterDirty=true end
   -- Prepare once when next shown; never keep a hidden model-refresh ticker.
   if root:IsVisible()then v:Prepare(v.reading and v.studyScene or v.forest)end
  else v:RefreshEffects()end
 end)
 for _,name in ipairs({'header','navigationFrame','contextFrame','stage'})do if U[name]then U[name]:SetFrameLevel(host:GetFrameLevel()+(name=='stage'and 64 or 90))end end
 if U.torchLogo then local f=G.Frame(U.header,2);f:SetPoint('TOPLEFT',U.torchLogo,'TOPLEFT');f:SetSize(300,75);if f.SetClipsChildren then f:SetClipsChildren(false)end;v.headerFlameHost=f;v.headerFlame=ns.WardenFlame.Surface(f,'brand',0);if v.headerFlame.frame.SetClipsChildren then v.headerFlame.frame:SetClipsChildren(false)end;local b=ns.WardenArt.headerFlame;G.Place(v.headerFlame.frame,f,b.x,b.y,b.width,b.height)end
 v.rememberedVisitors=ns.WardenSceneVisitors.Create(v,v.forest)
 v:ApplyLighting(ns.WardenSceneLighting.Open());v:Layout();ns.WardenScenicInput.Attach(v,U)
 return v
end
