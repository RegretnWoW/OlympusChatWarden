-- Owner-only, seven-place display. Original cover designs/history stay intact.
local _,ns=...;local S={VERSION=2,SLOTS=7,LEAN=10,BADGE_SIZE=.48,DROP=.06};ns.WardenShelfShowcase=S
local B,M,N,C=ns.WardenComposition,ns.WardenMementos,ns.WardenNativeScene,ns.WardenSceneObjectControls
-- File242995 ledges measured in the installed Forever mesh. Badges rest on
-- these boards instead of evenly dividing the model's decorative arch bounds.
S.slots={{.5,2.52},{.25,1.86},{.75,1.86},{.25,1.18},{.75,1.18},{.25,.44},{.75,.44}}
local function plain(v)return type(v)=='table'and not getmetatable(v)end
function S.Validate(v)
 if not plain(v)or v.version~=1 or not plain(v.slots)then return nil,'Invalid showcase'end
 for k in pairs(v)do if k~='version'and k~='slots'then return nil,'Unknown showcase field'end end
 local out={version=1,slots={}};local seen={}
 for k,id in pairs(v.slots)do
  if type(k)~='number'or k%1~=0 or k<1 or k>S.SLOTS or type(id)~='string'or not B.catalog[id]or not B.catalog[id].activity or seen[id]then return nil,'Use seven distinct activity badges'end
  seen[id]=true;out.slots[k]=id
 end;return out
end
local function key()return ns.ClientCompat.IsRetailTest()and'retailShelfShowcase'or'shelfShowcase'end
function S.Read(owner)
 if owner~=ns.Chronicle.Owner()then return nil,'OWNER_REQUIRED'end
 local state=M.OwnerState(owner,false);local stored=state and state[key()]
 if stored then return S.Validate(stored)end
 return{version=1,slots={}}
end
function S.Inventory(owner)local out={};for _,item in ipairs(M.Inventory(owner))do if B.catalog[item.art]and B.catalog[item.art].activity then out[item.art]=item end end;return out end
function S.Save(owner,v)
 if owner~=ns.Chronicle.Owner()or not ns.Permissions.Decide('UIAccess')then return false,'OWNER_REQUIRED'end
 local clean,why=S.Validate(v);if not clean then return false,why end
 local old,err=S.Read(owner);if not old then return false,err..'; original saved showcase retained'end
 local inventory=S.Inventory(owner)
 for slot,id in pairs(clean.slots)do if not inventory[id]and old.slots[slot]~=id then return false,'EARNED_ART_REQUIRED'end end
 local state=M.OwnerState(owner,true);if not state then return false,'Saved history needs recovery; original data retained'end
 state[key()]=clean;state.revision=state.revision+1;return true
end
function S.Swap(work,a,b)
 if not S.Validate(work)or type(a)~='number'or type(b)~='number'or a%1~=0 or b%1~=0 or a<1 or b<1 or a>7 or b>7 then return false end
 work.slots[a],work.slots[b]=work.slots[b],work.slots[a];return true
end
function S.Actor(v)local s=v.studyScene;local a=s and s.native.actors['shelf-right'];return a,s end
function S.ResetCamera(v)
 if v.nativeShelfScene then N.ViewCamera(v.nativeShelfScene.native,nil);v.nativeShelfScene=nil;v.nativeShelfCameraKey=nil end
end
S.defaults={version=1,distance=1.6,height=0,pitch=2.57,yaw=0,x=0,y=-.1}
S.limits={distance={.5,4},height={-3,4},pitch={-15,65},yaw={-180,180},x={-4,4},y={-4,4}}
function S.ValidateCamera(value)
 if not plain(value)or value.version~=1 then return nil,'Invalid showcase camera settings'end
 for key in pairs(value)do if key~='version'and not S.limits[key]then return nil,'Unknown showcase camera control'end end
 local out={version=1}
 for key,range in pairs(S.limits)do local n=value[key];if type(n)~='number'or n~=n or n<range[1]or n>range[2]then return nil,'Out of range: '..key end;out[key]=n end
 return out
end
function S.Settings(scene)
 local clean=scene and S.ValidateCamera(scene.shelfCameraTuning);if clean then return clean end
 local out={};for k,v in pairs(S.defaults)do out[k]=v end;return out
end
function S.Set(scene,value)
 if not scene or not scene.definition.reader then return false,'Enter your home before adjusting the showcase'end
 local clean,why=S.ValidateCamera(value);if not clean then return false,why end;scene.shelfCameraTuning=clean;return true
end
function S.ApplyCamera(v,aspect)
 if not v.shelfFocus then return false end
 local a,s=S.Actor(v);if not a or not a.ready or not a.bounds or not a.position or not s.native.frame then return false end
 local authored=s.shot;local base=s.worldCalibration and s.worldCalibration.camera or authored;local height=(a.bounds[6]-a.bounds[3])*(a.scale or 1)
 local tuning=S.Settings(s);local face=a.worldYaw or 0
 local tx,ty,tz=N.World(authored,a.position[1],a.position[2],a.position[3]+height*.48);tx,ty,tz=ns.WardenWorldScale.PresentWorld(s.native,a,tx,ty,tz)
 tx,ty,tz=tx-math.sin(face)*tuning.x,ty+math.cos(face)*tuning.x,tz+tuning.y
 local distance=math.max(1,height)/(2*math.tan((base.fov or .75)/2)*.78)*tuning.distance
 local yaw=face+math.rad(tuning.yaw);local target={position={tx+math.cos(yaw)*distance,ty+math.sin(yaw)*distance,tz+distance*math.tan(math.rad(tuning.pitch))+tuning.height},target={tx,ty,tz},fov=base.fov}
 local q=v.shelfFocus.mix or 0;local from=v.world3DWideShot or base;local shot={position={},target={},fov=base.fov}
 for i=1,3 do shot.position[i]=from.position[i]+(target.position[i]-from.position[i])*q;shot.target[i]=from.target[i]+(target.target[i]-from.target[i])*q end
 local key=table.concat(shot.position,':')..':'..table.concat(shot.target,':')
 if v.nativeShelfCameraKey~=key then
  if not N.ViewCamera(s.native,shot)then v.shelfCameraStatus='Native shelf camera unavailable; wide scene retained';return false end
  v.nativeShelfCameraKey=key
 end
 v.nativeShelfScene=s;v.shelfCameraStatus='Native shelf camera; fixed viewport';v.shelfCameraTarget={position=target.position,target=target.target,tuning=tuning,shelfPosition={unpack(a.position)}};return true
end
-- Shelf front is local +X; its width lies along model Y. Registration uses
-- the same centered bounds, yaw, scale and projection as native furniture.
function S.Quad(v,index,surface)
 local a,s=S.Actor(v);if not a or not a.ready or a.editorHidden or not a.position or not a.bounds then return end
 local b=a.bounds;local box=C.LocalBox(s.shot,a,{});if not box then return end
 local fit=(b[6]-b[3])/3.6077550258
 local slot=S.slots[index];if not slot then return end
 local size=S.BADGE_SIZE*a.scale*fit;local across=(slot[1]-.5)*1.50*a.scale*fit
 local bottom=(slot[2]-.0201365147-S.DROP)*a.scale*fit+.008*a.scale
 local lean=S.LEAN*math.pi/180
 -- The top rests against the recessed back; the foot stands forward by the
 -- ten-degree rake. Do not leave a tilted badge floating at the shelf lip.
 local depth=-(b[4]-b[1])*a.scale*.5+.045*a.scale+size*math.sin(lean)
 local function point(y,z)
  local height=z-bottom;local x=depth-height*math.sin(lean);z=bottom+height*math.cos(lean)
  if surface=='wall'then x=-(b[4]-b[1])*a.scale*.5+.028*a.scale;z=z+.012*a.scale
  elseif surface=='contact'then x=depth+(height/size-.5)*size*.30;z=bottom+.002*a.scale end
  local r=a.position[1]+box.cos*x-box.sin*y;local d=a.position[2]+box.sin*x+box.cos*y
  return ns.WardenWorldScale.ProjectPoint(s.native,a,r,d,a.position[3]+(a.groundOffset or 0)+z)
 end
 local points={};for _,p in ipairs({{across-size/2,bottom+size},{across+size/2,bottom+size},{across-size/2,bottom},{across+size/2,bottom}})do
  local u,y=point(p[1],p[2]);if not u then return end;points[#points+1]=u;points[#points+1]=y
 end
 if points[3]<points[1]then points={points[3],points[4],points[1],points[2],points[7],points[8],points[5],points[6]}end
 return points
end
-- Shelf-only presentation: a projected wall silhouette and one soft ledge
-- contact. Both are pooled below the artwork and never enter saved recipes.
function S.Shadow(tile,item,projectWall,projectContact)
 tile.badgeShadows=tile.badgeShadows or{}
 for _,t in ipairs(tile.badgeShadows)do t:Hide()end
 if not item then return end
 local pieces=B.Pieces({art=item.art,stage=item.stage,charms=item.charms},3);local used=0
 local function texture()
  used=used+1;local t=tile.badgeShadows[used]
  if not t then t=tile:CreateTexture(nil,'BACKGROUND');tile.badgeShadows[used]=t end;return t
 end
 for _,piece in ipairs(pieces)do
  if piece.role=='metal'or piece.role=='metal-back'or piece.role=='paper'then
   local t=texture();t:SetTexture(piece.art.path);t:SetTexCoord(unpack(piece.art.uv));t:SetVertexColor(0,0,0,.28)
   local x,y,w,h=piece.x,piece.y,piece.w,piece.h;local x1,y1=projectWall(x,y);local x2,y2=projectWall(x+w,y);local x3,y3=projectWall(x,y+h);local x4,y4=projectWall(x+w,y+h)
   B.Quad(t,tile,{x1,y1,x2,y2,x3,y3,x4,y4});t:Show()
  end
 end
 local t=texture();local asset=ns.WardenWorldArt.assets['contact-shadow42'].tiles[1]
 t:SetTexture(asset.path);t:SetTexCoord(unpack(asset.uv or{0,1,0,1}));t:SetVertexColor(1,1,1,.78)
 local x1,y1=projectContact(.04,0);local x2,y2=projectContact(.96,0);local x3,y3=projectContact(.04,1);local x4,y4=projectContact(.96,1)
 B.Quad(t,tile,{x1,y1,x2,y2,x3,y3,x4,y4});t:Show()
end
function S.Pick(v,u,y)
 local a,s=S.Actor(v);if not s or not s.active or v.cameraMix>.001 or a and a.editorHidden then return end
 local bounds=C.ProjectPick(s.native,s.shot,a);return C.ContainsPick(bounds,u,y)and bounds or nil
end
function S.Render(v)
 local a,s=S.Actor(v);local h=v.shelfDisplay;if not h or not s then return end
 local active=s.active and v.reading and v.cameraMix<.001 and not v.roomBookMotion and a and a.ready and not a.editorHidden
 if not active then if h:IsShown()then h:Hide()end;return end
 local host=s.layers['shelf-badges']
 if h:GetParent()~=host then h:SetParent(host);h.mounted=nil end
 if not h.mounted then h:SetAllPoints();h.mounted=true end
 ns.WardenSceneGraph.StackTree(h,host:GetFrameLevel());if not h:IsShown()then h:Show()end
 local state=v.shelfFocus;local owner=ns.Chronicle.Owner();local saved=M.OwnerState(owner,false);local revision=saved and saved.revision or-1
 if not state and(v.shelfOwner~=owner or v.shelfRevision~=revision)then v.shelfOwner=owner;v.shelfRevision=revision;v.shelfSaved=S.Read(owner);v.shelfInventory=S.Inventory(owner)end
 local design=state and state.work or v.shelfSaved;local inventory=state and state.inventory or v.shelfInventory or{}
 if not design then return end
 for i,tile in ipairs(h.tiles)do
  local q=S.Quad(v,i)
  if q then
   -- Subpixel projection noise is not a new layout. Keep idle materials and
   -- native viewport composition stable instead of hide/show each poll.
   for j=1,8 do local extent=j%2==1 and s.drawWidth or s.drawHeight;q[j]=math.floor(q[j]*extent*8+.5)/(extent*8)end
   local loX,hiX=math.min(q[1],q[3],q[5],q[7]),math.max(q[1],q[3],q[5],q[7]);local loY,hiY=math.min(q[2],q[4],q[6],q[8]),math.max(q[2],q[4],q[6],q[8])
   tile:EnableMouse(state and state.editing==true and not state.transition or false)
   local id=design.slots[i];local item=id and inventory[id];local stamp=id and item and(id..':'..item.stage..':'..table.concat(item.charms or{},','))or'empty'
   local signature=stamp..':'..s.drawWidth..':'..s.drawHeight..':'..table.concat(q,':')
   if tile.signature~=signature then
    tile:ClearAllPoints();tile:SetPoint('TOPLEFT',h,'TOPLEFT',loX*s.drawWidth,-loY*s.drawHeight);tile:SetSize(math.max(1,(hiX-loX)*s.drawWidth),math.max(1,(hiY-loY)*s.drawHeight))
    local recipe={version=1,catalog=3,layers={}};if item then recipe.layers[1]={art=id,stage=item.stage,charms=item.charms,x=0,y=0,w=1000,h=1000}end
    local function projection(points)return function(u,y)
     local topX=points[1]+(points[3]-points[1])*u;local topY=points[2]+(points[4]-points[2])*u;local bottomX=points[5]+(points[7]-points[5])*u;local bottomY=points[6]+(points[8]-points[6])*u
     return(topX+(bottomX-topX)*y-loX)*s.drawWidth,(topY+(bottomY-topY)*y-loY)*s.drawHeight
    end end
    local wall,contact=S.Quad(v,i,'wall'),S.Quad(v,i,'contact')
    if wall and contact then S.Shadow(tile,item,projection(wall),projection(contact))end
    B.Render(tile,recipe,projection(q));tile.signature=signature
   end
   tile.item=item;tile.label:SetText(state and state.editing and(state.selected==i and('Selected · '..i)or not id and'+ Add badge'or tostring(i))or'');if not tile:IsShown()then tile:Show()end
  elseif tile:IsShown()then tile:Hide()end
 end
end
function S.Bind(v,U)
 if v.shelfDisplay then return end
 local h=CreateFrame('Frame',nil,v.studyScene.layers['shelf-badges']);h:EnableMouse(false);h.tiles={};v.shelfDisplay=h
 local function message(text)if v.shelfBar then v.shelfBar.status:SetText(text or'')end end
 local function picker(slot)
  local state=v.shelfFocus;if not state or not state.editing then return end
  local choices={};for id,item in pairs(state.inventory)do choices[#choices+1]={id,item.title}end;table.sort(choices,function(a,b)return a[2]<b[2]end)
  if #choices==0 then message('Your recorded adventures will supply earned badges.');return end
  local form=ns.UI2Forms.Form({title='Choose an earned badge',help='Choose a badge for shelf position '..slot..'. Its stage and mementos follow your accepted history.',fields={{key='badge',label='Earned badge',value=choices[1][1],choices=choices}},submitLabel='Place badge',submit=function(values)
   if v.shelfFocus~=state or state.owner~=ns.Chronicle.Owner()or not state.inventory[values.badge]then return false,'Owner or inventory changed'end
   for i,id in pairs(state.work.slots)do if id==values.badge then state.work.slots[i]=nil end end;state.work.slots[slot]=values.badge;state.selected=nil;state.dirty=true;S.Render(v);return true
  end});state.picker=form
 end
 for i=1,7 do local slot=i;local tile=CreateFrame('Button',nil,h);h.tiles[i]=tile;tile:EnableMouse(false);tile:RegisterForClicks('LeftButtonUp')
  tile.label=tile:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');tile.label:SetPoint('TOP',tile,'BOTTOM',0,-1)
  tile:SetScript('OnClick',function()
   local state=v.shelfFocus;if not state or not state.editing then return end
   if state.selected then S.Swap(state.work,state.selected,slot);state.selected=nil;state.dirty=true;message('Moved. Save to keep this arrangement.')
   elseif state.work.slots[slot]then state.selected=slot;message('Choose another position to move or swap, or use Change / Remove.')else picker(slot)end;S.Render(v)
  end)
  tile:SetScript('OnEnter',function()if tile.item and GameTooltip then GameTooltip:SetOwner(tile,'ANCHOR_RIGHT');GameTooltip:SetText(tile.item.title);GameTooltip:Show()end end);tile:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide()end end)
 end
 local bar=CreateFrame('Frame','OlympusWardenShelfShowcase',U.window);bar:SetSize(730,91);bar:SetPoint('BOTTOM',U.window,'BOTTOM',0,40);bar:SetFrameStrata('DIALOG');bar:EnableMouse(true);bar:Hide();v.shelfBar=bar
 ns.Theme.RegisterModal(bar,U.window)
 bar:ClearAllPoints();bar:SetPoint('BOTTOM',U.window,'BOTTOM',0,40)
 if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]='OlympusWardenShelfShowcase'end
 local bg=bar:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();bg:SetTexture(ns.WardenArt.Path('Panel'));bar.background=bg
 local V=ns.Art;bar.status=V.Text(bar,'',12,-8,705,13,V.gold);bar.status:SetHeight(25)
 local buttons={};bar.buttons=buttons
 local function button(name,label,x,w,fn)buttons[name]=V.Button(bar,label,x,-42,w,30,fn,'neutral')end
 button('edit','Edit showcase',12,150,function()local state=v.shelfFocus;state.editing=true;state.inventory=S.Inventory(state.owner);message('Select a badge, then a destination to move it. Empty positions add a badge.');S.RefreshBar(v);S.Render(v)end)
 button('change','Change',12,100,function()local state=v.shelfFocus;picker(state.selected or 1)end)
 button('remove','Remove',120,100,function()local state=v.shelfFocus;if state.selected then state.work.slots[state.selected]=nil;state.selected=nil;state.dirty=true;S.Render(v)end end)
 button('save','Save',230,100,function()local state=v.shelfFocus;local ok,why=S.Save(state.owner,state.work);if ok then state.editing=false;state.dirty=nil;state.selected=nil;S.RefreshBar(v);S.Render(v);message('Showcase saved.')else message(why)end end)
 button('cancel','Cancel',340,100,function()local state=v.shelfFocus;state.work=S.Read(state.owner)or{version=1,slots={}};state.editing=false;state.selected=nil;state.dirty=nil;S.RefreshBar(v);S.Render(v);message('Unsaved edits discarded.')end)
 button('back','Back to home',550,164,function()S.Close(v)end)
 function v:ShelfFraming(baseW,baseH,w,height,wideX,wideY)
  local state=self.shelfFocus;if not state then return end
  -- Native viewports larger than the physical screen can be rejected by the
  -- client compositor. Zoom the shared camera, never resize a 3D render target.
  return wideX,wideY,1
 end
 local click,pick,interact,layout,select,stop,ready=v.ClickScene,v.PickSceneObject,v.InteractPlayer,v.Layout,v.Select,v.Stop,v.ActorReady
 v.PickSceneObject=function(self,s,u,y)if s==self.studyScene and S.Pick(self,u,y)then return'shelf-right'end;return pick(self,s,u,y)end
 v.InteractPlayer=function(self,s,id)if s==self.studyScene and id=='shelf-right'then return S.Open(self)end;return interact(self,s,id)end
 v.ClickScene=function(self,s,u,y)
  if self.shelfFocus then return false,'Close the showcase to walk'end
  -- Reading a display is not walking: a seated character or paused ambient
  -- motion must not consume the click as a stand-up / movement instruction.
  if s==self.studyScene and S.Pick(self,u,y)then return S.Open(self)end
  return click(self,s,u,y)
 end
 v.Layout=function(self,...)local result=layout(self,...);S.Render(self);return result end
 v.Select=function(self,route,reading,immersive)
  -- UI reader visibility is false with the main menu closed. It does not mean
  -- the canonical character left home; badge-picker feedback refreshes that UI.
  local room=self.pendingRoomKey or self.currentRoomKey or'hall'
  if self.shelfFocus and(room~=self.studyScene.key or not U.menuHidden and not reading or route.sceneRoom and route.sceneRoom~=self.studyScene.key)then S.Close(self,true)end
  return select(self,route,reading,immersive)
 end
 v.Stop=function(self,...)if self.shelfFocus then S.Close(self,true)end;return stop(self,...)end
 v.ActorReady=function(self,s,a,...)local result=ready(self,s,a,...);if a.id=='shelf-right'then S.Render(self)end;return result end
 local driver=CreateFrame('Frame',nil,U.window);driver:SetAllPoints(v.frame);driver:EnableMouse(false);v.shelfDriver=driver
 driver:SetScript('OnUpdate',function(_,dt)
  if not v.frame:IsVisible()then return end
  local state=v.shelfFocus
  if v.shelfQueued then if not v.roomBookMotion and v.cameraMix<.001 then v.shelfQueued=nil;S.Open(v)end;return end
  if not state then driver.age=(driver.age or 0)+dt;if driver.age>=.4 then driver.age=0;S.Render(v)end;return end
  if state.owner~=ns.Chronicle.Owner()or not v.reading or not v.frame:IsVisible()then S.Close(v,true);return end
  if state.transition then local t=state.transition;t.elapsed=math.min(.9,t.elapsed+dt);local q=t.elapsed/.9;q=q*q*(3-2*q);state.mix=t.from+(t.to-t.from)*q
   v:Layout();if t.elapsed>=.9 then state.transition=nil;if t.to==0 then S.Close(v,true);return end end
  else state.age=(state.age or 0)+dt;if state.age>=.15 then state.age=0;S.Render(v)end end
 end)
 bar:SetScript('OnHide',function()if v.shelfFocus and not v.shelfClosing then S.Close(v,true)end end)
 U.window:HookScript('OnHide',function()S.Close(v,true);v.shelfQueued=nil end)
 local report=v.Report
 v.Report=function(self,...)
  local out=report(self,...);local a=S.Actor(self);local state=self.shelfFocus;local visible=0
  for _,tile in ipairs(self.shelfDisplay.tiles)do if tile:IsVisible()and tile.item then visible=visible+1 end end
  out.shelfShowcase={version=S.VERSION,leanDegrees=S.LEAN,shadows='projected shelf wall and ledge contact',loaded=a and a.ready==true or false,removed=a and a.editorHidden==true or false,open=state~=nil,zoom=state and state.zoom,mix=state and state.mix,editing=state and state.editing==true or false,visibleBadges=visible,last=self.lastShelfAction,driverVisible=driver:IsVisible(),clock='stable window driver'};return out
 end
end
function S.RefreshBar(v)local b=v.shelfBar;local edit=v.shelfFocus and v.shelfFocus.editing;for _,name in ipairs({'change','remove','save','cancel'})do b.buttons[name]:SetShown(edit==true)end;b.buttons.edit:SetShown(not edit)end
function S.Open(v)
 local function reject(why)v.lastShelfAction={accepted=false,reason=why};return false,why end
 if not ns.Permissions.Decide('UIAccess')or not v.reading or v.cameraMix>.001 or v.roomBookMotion or ns.WardenSceneEditor and ns.WardenSceneEditor.active then return reject('Finish the current scene interaction first')end
 if v.shelfFocus then return true end
 local a,s=S.Actor(v);local bounds=a and C.ProjectPick(s.native,s.shot,a);if not bounds or a.editorHidden then return reject('Display shelf is not loaded or is removed')end
 local owner=ns.Chronicle.Owner();local work,why=S.Read(owner);if not work then return false,why end
 v.shelfFocus={owner=owner,work=work,inventory=S.Inventory(owner),mix=0,u=(bounds.left+bounds.right)/2,v=(bounds.top+bounds.bottom)/2,zoom=math.max(1.15,math.min(4,.72/math.max(.02,bounds.bottom-bounds.top))),transition={from=0,to=1,elapsed=0}}
 if ns.DB.journalReducedMotion then v.shelfFocus.mix=1;v.shelfFocus.transition=nil end
 local person=s.native.actors.attendant;if person then person.route=nil;person.pendingInteraction=nil;if not person.seating then s.native:Animate(person,0,1)end end
 s.groundClick:EnableMouse(false);if v.roomBookHit then v.roomBookHit:Hide();v.roomBookHit:EnableMouse(false)end
 v.lastShelfAction={accepted=true,action='Open display shelf'}
 v.shelfBar:Show();v.shelfBar.status:SetText('Badge showcase · seven positions · 1 / 2 / 2 / 2');S.RefreshBar(v);v.shelfDriver:Show();v:Layout();return true
end
function S.Close(v,immediate)
 local state=v and v.shelfFocus;if not state then return end
 if not immediate and not ns.DB.journalReducedMotion then if state.picker then state.picker:Hide()end;state.editing=false;state.transition={from=state.mix,to=0,elapsed=0};S.RefreshBar(v);return true end
 S.ResetCamera(v);v.shelfClosing=true;if state.picker then state.picker:Hide()end;v.shelfFocus=nil;v.shelfBar:Hide();v.shelfClosing=nil;v:Layout();v:RefreshEffects();return true
end
function S.OpenFromReader(p)
 local v=p.studyCamera;if not v then return false end
 if not p.closedBookSide then p:CloseBook('front')end
 if v.roomBookMotion then v.shelfQueued=true;v.shelfDriver:Show();return true end
 return S.Open(v)
end
local attach=ns.WardenRealm.Attach
ns.WardenRealm.Attach=function(...)local v=attach(...);S.Bind(v,ns.UI2);return v end
