-- Regression at public editor/native API boundaries; never executes private code.
local ns={UI2={menuHidden=true},Fireside3D={PRIMARY='square',bounds={-32,-24,32,34}},WardenWorldScenes={}}
local function load(p)return assert(loadfile('OlympusChatWarden/'..p))('test',ns)end
local methods={};local mt={__index=methods}
local function frame(parent)return setmetatable({parent=parent,scripts={},shown=true,w=1600,h=900,level=100,strata='FULLSCREEN_DIALOG'},mt)end
function methods:SetScript(k,v)self.scripts[k]=v end;function methods:GetScript(k)return self.scripts[k]end
function methods:HookScript(k,v)local previous=self.scripts[k];self.scripts[k]=function(...)if previous then previous(...)end;v(...)end end
function methods:Show()self.shown=true end
function methods:Hide()local before=self.shown;self.shown=false;if before and self.scripts.OnHide then self.scripts.OnHide(self)end end
function methods:SetShown(v)if v then self:Show()else self:Hide()end end
function methods:IsShown()return self.shown end;function methods:IsVisible()return self.shown and(not self.parent or self.parent:IsVisible())end
function methods:IsMouseOver()return self.hover==true end
function methods:GetWidth()return self.w end;function methods:GetHeight()return self.h end;function methods:GetLeft()return 0 end;function methods:GetTop()return self.h end
function methods:GetEffectiveScale()return 1 end
function methods:SetSize(w,h)self.w=w;self.h=h end;function methods:SetWidth(w)self.w=w end
function methods:GetFrameLevel()return self.level end;function methods:SetFrameLevel(v)self.level=v end
function methods:GetFrameStrata()return self.strata end;function methods:SetFrameStrata(v)self.strata=v end
function methods:CreateTexture()return frame(self)end;function methods:CreateFontString()return frame(self)end;function methods:CreateLine()return frame(self)end
function methods:SetText(v)self.text=v end
function methods:EnableKeyboard(v)self.keyboard=v end;function methods:SetPropagateKeyboardInput(v)self.propagate=v end
for _,key in ipairs({'SetPoint','SetAllPoints','ClearAllPoints','SetColorTexture','EnableMouse','SetJustifyH','RegisterForClicks','RegisterForDrag','SetStartPoint','SetEndPoint','SetThickness'})do methods[key]=function()end end
CreateFrame=function(_,_,parent)return frame(parent)end
local cursor={0,0};local left,escape,combat,focus=false,false,false,false
GetCursorPosition=function()return cursor[1],cursor[2]end
IsMouseButtonDown=function(button)return button=='LeftButton'and left end
IsKeyDown=function(key)return key=='ESCAPE'and escape end
GetCurrentKeyBoardFocus=function()return focus end;InCombatLockdown=function()return combat end
load('WardenSceneObjectControls.lua');load('WardenNativeScene.lua');load('World3D/Coordinates.lua');load('World3D/Scene.lua');load('World3D/Hitboxes.lua');load('World3D/HitboxEditor.lua');load('World3D/EditorCamera.lua')
local F,N,C=ns.Fireside3D,ns.WardenNativeScene,ns.WardenSceneObjectControls;local H,T=F.Hitboxes,F.HitboxEditor
F.IsScene=function(s)return s and s.definition.world3D end
local shot={position={0,-12,10},target={0,10,1},fov=.85};local engine=F.Coordinates.Bind({frame=frame(),shot=shot,metrics={moves=0},order={},actors={}})
engine.frame.firesideViewShot=shot
N.ProjectNative=function(f,s,x,y,z)return N.Project(f.firesideViewShot or s,x,y,z,f:GetWidth()/f:GetHeight())end
ns.WardenWorldScale={ProjectPoint=function(e,a,x,y,z)return N.ProjectNative(e.frame,e.shot,x,y,z)end}
local a={id='player-home',ready=true,bounds={-3,-3,0,3,3,4},position={0,10,0},scale=1,editorBaseScale=1,spec={id='player-home',fileID=202016,label='Tent',collision=false},engine=engine,worldYaw=0}
local person={id='attendant',ready=true,position={0,5,0},scale=1,spec={controlled=true,navigationRadius=.3},engine=engine}
engine.actors={[a.id]=a,attendant=person};engine.order={a,person}
local scene={key='square',native=engine,shot=shot,frame=engine.frame,definition={world3D=true,props={a.spec}},drawWidth=1600,drawHeight=900,shadows={}}
ns.WardenWorldScenes.Props=function(s)return s.definition.props end
local v={frame=frame()};function v:ActiveRoom()return scene end
local base={x=0,y=10,z=0,yaw=0,scale=1,hidden=false};local work,undo,redo,saved={},{},{},nil
-- A deliberately strict stand-in: the extension must preserve the existing
-- validation/storage/history contract rather than secretly saving elsewhere.
local e={active=true,scene='square',selected='native/player-home',panel={frame=frame()},handle=frame(),Realm=function()return v end,Scene=function()return scene end}
function e.Find(key,id)if key=='square'and id=='native/player-home'then return{kind='native',id=a.id,engine=engine}end end
function e.Value(key,id)local row=e.Find(key,id);if not row then return nil,'missing'end;return H.Copy(work[id]or base),row end
function e.CheckRecord(key,id,r)
 if not e.Find(key,id)or type(r)~='table'or getmetatable(r)then return nil,'bad placement'end
 local out=H.Copy(r)
 for _,kind in ipairs({'collider','hitbox'})do if r[kind]then local valid,why=C.Validate(kind,r[kind]);if not valid then return nil,why end;out[kind]=valid end end
 return out
end
local function apply()local r=work[e.selected]or base;a.collider=H.Copy(r.collider);a.hitbox=H.Copy(r.hitbox)end
function e.Push()undo[#undo+1]=H.Copy(work);redo={}end
function e.Set(id,r,noHistory)local valid,why=e.CheckRecord(e.scene,id,r);if not valid then return false,why end;if not noHistory then e.Push()end;work[id]=valid;apply();return true end
function e.History(back)local source,dest=back and undo or redo,back and redo or undo;local next=table.remove(source);if next then dest[#dest+1]=H.Copy(work);work=next;apply()end end
function e.Export()return{version=5,scene='square',format='WARDEN_SCENE_LAYOUT',objects=H.Copy(work)}end
function e.Validate(r)
 if r.version~=5 or r.format~='WARDEN_SCENE_LAYOUT'then return nil,'unsupported'end
 local out=H.Copy(r);for id,record in pairs(r.objects)do local valid,why=e.CheckRecord(r.scene,id,record);if not valid then return nil,why end;out.objects[id]=valid end;return out
end
function e.UpdateHandle()e.handle:Show()end
function e.GeometryForm()return 'legacy form'end
function e.Message(s)e.lastMessage=s end
function e.ShowForm(form)e.form=form end
ns.WardenSceneEditor=e
assert(T.BindExistingEditor()and not T.BindExistingEditor())
local walls={{width=.3,depth=5,x=-2.5,y=0},{width=.3,depth=5,x=2.5,y=0},{width=5.3,depth=.3,x=0,y=2.5}}
assert(e.Set(e.selected,{x=0,y=10,z=0,yaw=0,scale=1,collider={enabled=true,boxes=walls}}))
local function segment(x,y,tx,ty)return{samples={{x=x,y=y,z=0},{x=tx,y=ty,z=0}}}end
local function world(x,y)local c,s=math.cos(a.worldYaw),math.sin(a.worldYaw);return a.position[1]+a.scale*(c*x-s*y),a.position[2]+a.scale*(s*x+c*y)end
for angle=0,359 do
 a.worldYaw=angle*math.pi/180;a.scale=({.5,1,2})[angle%3+1]
 local nav=assert(F.Navigation(v,scene,person));assert(#nav.obstacles==3,'no extra envelope or generated house walls')
 local x,y=world(0,-4);local xx,yy=world(0,1)
 assert(N.CheckPath(segment(x,y,xx,yy),nav),'open entrance survives rotation and scale')
 x,y=world(-4,0);xx,yy=world(0,0);assert(not N.CheckPath(segment(x,y,xx,yy),nav),'each wall must block the real path validator')
 local envelope=N.Footprint(shot,a);assert(envelope and envelope.left<envelope.right)
end
-- Disabled parts/empty overrides and decoration props use exactly the edited shapes.
a.scale=1;a.worldYaw=0;a.collider.boxes[1].enabled=false;assert(#F.Navigation(v,scene,person).obstacles==2)
a.collider={boxes={}};assert(#F.Navigation(v,scene,person).obstacles==0 and not N.Footprint(shot,a))
a.collider={enabled=false,boxes=walls};assert(#H.Footprints(shot,a)==0)
local inactive,globalEnabled=H.Boxes(a,'collider');assert(not globalEnabled);for _,r in ipairs(inactive)do assert(r.enabled==false,'editing a disabled collection must not enable its other boxes')end
a.collider=nil;assert(#F.Navigation(v,scene,person).obstacles==0,'tent default remains open')
local legacy={ready=true,position={0,0,0},bounds=a.bounds,scale=1,engine={},spec={},collider={width=2,depth=3}}
assert(N.Footprint(shot,legacy).halfX==1,'legacy single-box path remains unchanged')
for _,bad in ipairs({{boxes={[2]={}}},{boxes={{width=0}}},{boxes={{width=0/0}}},{boxes={{boxes={}}}},{boxes=setmetatable({},{})},{enabled=1,boxes={}},{boxes={},width=1}})do assert(not H.Validate('collider',bad),'malformed compound must fail')end
local tooMany={};for i=1,9 do tooMany[i]={}end;assert(not H.Validate('hitbox',{boxes=tooMany}))
assert(not H.Validate('shadow',{boxes={}}))
-- Separate click volumes retain gaps rather than making a convex hull of all boxes.
a.hitbox={boxes={{width=1,depth=1,height=2,x=-2,y=0,z=0},{width=1,depth=1,height=2,x=2,y=0,z=0}}}
local picks=C.ProjectPick(engine,shot,a);assert(picks and #picks.parts==2)
local u,w=N.ProjectNative(engine.frame,shot,-2,10,1);assert(C.ContainsPick(picks,u,w))
u,w=N.ProjectNative(engine.frame,shot,0,10,1);assert(not C.ContainsPick(picks,u,w),'the gap must not become clickable')
a.hitbox.boxes[1].enabled=false;u,w=N.ProjectNative(engine.frame,shot,-2,10,1);assert(not C.ContainsPick(C.ProjectPick(engine,shot,a),u,w))
a.hitbox=nil
-- Every face keeps the opposite face fixed, including top and bottom, under clamping.
for _,face in ipairs({'x-','x+','y-','y+','z-','z+'})do
 for _,delta in ipairs({-50,-.4,.4,50})do
  local r={width=3,depth=4,height=2,x=1,y=-1,z=.5};local out=H.Resize(r,face,delta);assert(C.Validate('hitbox',out))
  local axis=face:sub(1,1);local dim=axis=='x'and'width'or axis=='y'and'depth'or'height';local sign=face:sub(2)=='+'and 1 or-1
  local old=axis=='z'and(r.z+(sign<0 and r.height or 0))or(r[axis]-sign*r[dim]/2)
  local new=axis=='z'and(out.z+(sign<0 and out.height or 0))or(out[axis]-sign*out[dim]/2)
  assert(math.abs(old-new)<1e-8,'opposite face anchored: '..face)
 end
end
-- Native perspective inversion through full camera rotation, with no linear approximation.
for angle=0,359 do
 local rad=angle*math.pi/180;local view={position={20*math.cos(rad),10+20*math.sin(rad),10},target={0,10,1},fov=.85};engine.frame.firesideViewShot=view
 local origin={1,10,1};for _,axis in ipairs({{1,0,0},{0,1,0},{0,0,1}})do
  local map=H.AxisMap(engine.frame,shot,origin,axis)
  if map then for _,amount in ipairs({-1,.3,1.5})do
   local x,y=N.ProjectNative(engine.frame,shot,unpack(origin));local xx,yy=N.ProjectNative(engine.frame,shot,origin[1]+axis[1]*amount,origin[2]+axis[2]*amount,origin[3]+axis[3]*amount)
   assert(math.abs(map((xx-x)*1600,(yy-y)*900)-amount)<1e-6,'native axis inverse')
  end end
 end
end
engine.frame.firesideViewShot=shot
-- Editor UI: old numeric command opens the richer tool and routes all mutations
-- through Set, creating a single undo entry for an arbitrarily long gesture.
work={};apply();assert(e.GeometryForm('collider'));local s=v.world3DHitboxTool;assert(s.panel:IsShown())
T.Command(v,'add');assert(#a.collider.boxes==1,'first explicit box on open tent must not add a giant automatic wall')
T.Command(v,'duplicate');assert(#a.collider.boxes==2);T.Command(v,'remove');assert(#a.collider.boxes==1)
T.Command(v,'enabled');assert(a.collider.boxes[1].enabled==false);T.Command(v,'enabled')
T.Command(v,'fit');assert(a.collider.boxes[1].width==6)
T.Command(v,'automatic');assert(a.collider==nil)
T.Command(v,'add');s.index=1;a.scale=1.8;a.worldYaw=.65;T.Draw(v);assert(#s.lines>=4 and #s.handles>=5,'visible four sides plus center')
e.UpdateHandle();assert(not e.handle:IsShown(),'old move-object handle must not obscure the box tool')
local function mouseAt(point)local x,y=N.ProjectNative(engine.frame,shot,unpack(point));cursor={x*1600,900-y*900}end
local b=H.Shape(shot,a,H.Boxes(a,'collider')[1]);local origin,axis=T.Handle(b,'x+','collider');mouseAt(origin);left=true
local history=#undo;local side
for _,h in ipairs(s.handles)do if h.face=='x+'and h:IsShown()then side=h end end
assert(side);side.scripts.OnMouseDown(side,'LeftButton');assert(e.firesideBoxDragging and not e.dragging)
assert(not F.EditorCamera.Allowed(v),'camera must release while a box face is captured')
local oldX=a.position[1];local oldY=a.position[2]
for i=1,20 do mouseAt({origin[1]+axis[1]*i*.03*a.scale,origin[2]+axis[2]*i*.03*a.scale,origin[3]});T.Drag(v)end
left=false;T.Drag(v);assert(not e.firesideBoxDragging and not s.drag)
assert(#undo==history+1,'one history snapshot per drag')
assert(math.abs(a.collider.boxes[1].width-1.6)<1e-6 and math.abs(a.collider.boxes[1].x-.3)<1e-6)
assert(a.position[1]==oldX and a.position[2]==oldY,'editing a face must never drag the object')
e.History(true);assert(a.collider.boxes[1].width==1);e.History(false);assert(math.abs(a.collider.boxes[1].width-1.6)<1e-6)
-- Center drag and cancellation, with perspective plane inversion at the box height.
a.scale=1;a.worldYaw=0
local r=H.Boxes(a,'collider')[1];b=H.Shape(shot,a,r);origin=T.Handle(b,'move','collider');mouseAt(origin);left=true
T.BeginDrag(v,1,'move');mouseAt({origin[1]+1,origin[2]+.5,origin[3]});T.Drag(v)
assert(math.abs(a.collider.boxes[1].x-r.x-1)<1e-6 and math.abs(a.collider.boxes[1].y-r.y-.5)<1e-6)
s.panel.scripts.OnKeyDown(s.panel,'ESCAPE');left=false;assert(not s.panel.keyboard and s.panel.propagate==false and math.abs(a.collider.boxes[1].x-r.x)<1e-6,'Escape must cancel locally rather than close the editor')
-- Save/export/reload retains compound data; legacy version-5 layouts still validate.
local exported=e.Export();assert(exported.version==6);saved=assert(e.Validate(exported))
work={};apply();local validated=assert(e.Validate(saved));work=H.Copy(validated.objects);apply();assert(#a.collider.boxes==1)
local oldLayout=H.Copy(saved);oldLayout.version=5;oldLayout.objects[e.selected].collider={width=2,depth=3};assert(e.Validate(oldLayout))
s.kind='hitbox';s.index=1;T.Command(v,'add');T.Draw(v);local zHandle=false;for _,h in ipairs(s.handles)do if h:IsShown()and h.face=='z+'then zHandle=true end end;assert(zHandle)
T.Exact(v);assert(e.form and e.form.submit({enabled='yes',width='2',depth='1',height='3',x='0',y='0',z='.2'}));assert(a.hitbox.boxes[s.index].height==3)
for _,guard in ipairs({'combat','focus','popup','storage'})do
 local previous=#undo;if guard=='combat'then combat=true elseif guard=='focus'then focus=true elseif guard=='popup'then e.popup=frame()else ns.MainStorageBlocked=true end
 T.Command(v,'add');assert(#undo==previous and not T.Allowed(v),'guard '..guard)
 combat=false;focus=false;e.popup=nil;ns.MainStorageBlocked=nil
end
e.active=false;s.panel.scripts.OnUpdate(s.panel,.05);assert(not s.panel:IsShown()and not s.overlay:IsShown()and not e.firesideBoxDragging)
print('PASS: compound tent doorway/three independent walls through 360 rotation and scale; disabled/legacy shapes; strict bounded schema; separate clickable volumes; all six anchored faces; native perspective drag inverse')
print('PASS: existing editor adapter/UI handles, add/duplicate/remove/auto/exact controls, face/center dragging and cancel, camera isolation, one-step undo/redo, versioned save/export/reload, legacy layouts and form/combat/focus/storage guards')
