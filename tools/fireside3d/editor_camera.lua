-- Exercise the actual scene input adapter and native camera calls at recorded
-- API boundaries. No private addon, network or saved state is executed.
local ns={UI2={menuHidden=true},Fireside3D={PRIMARY='square',preferredBuilding={fileID=328178,label='Night Elf tent',buttonLabel='Add tent test'}},WardenRoomCatalogue={HasRoom=function(k)return k=='hall'or k=='study'or k=='square'end}}
local function load(p)return assert(loadfile('OlympusChatWarden/'..p))('test',ns)end
local methods={};local mt={__index=methods}
local function frame()return setmetatable({scripts={},visible=true,hover=true},mt)end
function methods:SetScript(k,v)self.scripts[k]=v end
function methods:HookScript(k,v)local before=self.scripts[k];self.scripts[k]=function(...)if before then before(...)end;return v(...)end end
function methods:IsVisible()return self.visible end
function methods:IsShown()return self.visible end
function methods:Show()self.visible=true end
function methods:Hide()self.visible=false end
function methods:IsMouseOver()return self.hover end
function methods:CreateTexture()return frame()end
function methods:CreateFontString()return frame()end
function methods:GetFrameLevel()return self.level or 10 end
function methods:SetFrameLevel(value)self.level=value end
function methods:GetChildren()return unpack(self.children or{})end
function methods:SetParent(value)self.parent=value end
function methods:RegisterForClicks(...)self.clicks={};for _,button in ipairs({...})do self.clicks[button]=true end end
function methods:RegisterForDrag(...)self.dragButtons={};for _,button in ipairs({...})do self.dragButtons[button]=true end end
function methods:SetPropagateMouseClicks(value)self.propagateClicks=value end
function methods:SetPropagateMouseMotion(value)self.propagateMotion=value end
function methods:SetPropagateKeyboardInput(value)self.propagate=value end
function methods:EnableMouse(value)self.mouse=value end
function methods:SetCameraPosition(x,y,z)self.eye={x,y,z}end
function methods:SetCameraOrientationByYawPitchRoll(yaw,pitch,roll)self.angles={yaw,pitch,roll}end
for _,k in ipairs({'SetPoint','ClearAllPoints','SetSize','SetAllPoints','SetColorTexture','SetText','SetShown','EnableKeyboard','EnableMouseWheel','SetCameraFieldOfView','SetCameraNearClip','SetCameraFarClip'})do methods[k]=function()end end
CreateFrame=function()return frame()end
local focus,combat,shift,mouse=false,false,false,false
local cursorX,cursorY=0,0
GetCurrentKeyBoardFocus=function()return focus end
InCombatLockdown=function()return combat end
IsShiftKeyDown=function()return shift end
IsMouseButtonDown=function()return mouse end
GetCursorPosition=function()return cursorX,cursorY end
load('WardenNativeScene.lua');load('World3D/Scene.lua');load('World3D/EditorCamera.lua')
local F,N=ns.Fireside3D,ns.WardenNativeScene;local EC=F.EditorCamera
local tentClicks=0;F.Catalog={SpawnPreferred=function()tentClicks=tentClicks+1;return true end}
F.IsScene=function(s)return s.definition.world3D==true end
local player={ready=true,position={0,-7,0},scale=1.85}
local engine={actors={attendant=player},frame=frame(),shot={position={0,-18,8},target={0,0,1},fov=.85}}
engine.Place=function()error('camera controls cannot move an actor')end
local s={definition={world3D=true},native=engine,groundClick=frame(),active=true};s.shot=engine.shot
local v={frame=frame(),forest=s,cameraMix=0};function v:ActiveRoom()return s end
F.BindInput(v,ns.UI2)
local initial=EC.FollowView(v);assert(initial.target[2]>initial.position[2],'initial view faces north toward the Elwynn home')
local floor=s.groundClick
assert(floor.clicks.RightButtonDown and floor.clicks.RightButtonUp and floor.dragButtons.RightButton,'the actual floor must register the right-button gesture')
assert(floor.propagateClicks==false and floor.propagateMotion==false,'the addon camera gesture must not leak into the game world camera')
local clicks=0;v.CursorSceneClick=function()clicks=clicks+1 end
floor.scripts.OnClick(floor,'RightButton',false);floor.scripts.OnClick(floor,'RightButton',true);assert(clicks==0)
floor.scripts.OnClick(floor,'LeftButton',false);assert(clicks==1,'left-click interaction stays separate from right drag')
local higher=frame();higher:SetFrameLevel(70);s.frame=frame();s.frame.children={higher,floor}
v:RefreshFieldInput();assert(floor:GetFrameLevel()==71,'the scenic input must cover higher stale scene frames')
v:RefreshFieldInput();assert(floor:GetFrameLevel()==71,'restacking must not continually raise frame levels')
local opened,failOpen
local editor={active=false,Realm=function()return v end,Open=function(key)opened=key;return not failOpen,'existing result'end}
ns.WardenSceneEditor=editor
assert(EC.BindExistingEditor());assert(not EC.BindExistingEditor(),'adapter binds only once')
assert(editor.Open('study')and opened=='square','legacy launch buttons must open the actual 3D world')
editor.Open('unknown');assert(opened=='unknown','unknown keys retain the existing editor validation')
ns.UI2.menuHidden=false;failOpen=true;local ok,why=editor.Open('square');assert(not ok and why=='existing result'and ns.UI2.menuHidden==false,'failed editor authorization must retain menu state')
failOpen=false;editor.Open('square');assert(ns.UI2.menuHidden,'editor launched from a menu must reveal the wide world')
editor.active=true;editor.scene='square';assert(EC.Active(v))
local function key(name,down)v.frame.scripts[down and'OnKeyDown'or'OnKeyUp'](v.frame,name)end
local function distance(a,b)return math.sqrt((a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2)end
local function copy(p)return{p[1],p[2],p[3]}end
local c=EC.State(v);local start=copy(c.position)
key('W',true);assert(v.frame.propagate==false);EC.Tick(v,.05);assert(math.abs(distance(start,c.position)-.4)<1e-8)
assert(v.world3DCameraBar.addModelTest and tentClicks==0,'opening/moving the editor cannot automatically spawn the preferred building')
v.world3DCameraBar.addModelTest.scripts.OnClick();assert(tentClicks==1,'only the explicit tent button invokes the preferred existing-editor action')
key('W',false);assert(not v.frame.propagate and not c.keys.W,'release the held camera key without forwarding its key-up to WoW')
shift=true;start=copy(c.position);key('D',true);EC.Tick(v,.05);key('D',false)
assert(math.abs(distance(start,c.position)-1.2)<1e-8,'Shift camera movement is three times normal speed');shift=false
start=copy(c.position);key('E',true);EC.Tick(v,.05);key('E',false)
assert(c.position[1]==start[1]and c.position[2]==start[2]and c.position[3]>start[3],'E changes camera height only')
key('Q',true);EC.Tick(v,.05);key('Q',false);assert(distance(start,c.position)<1e-8)
-- Look through 360 degrees using the real native camera API wrapper.
for turn=0,359 do c.yaw=turn*math.pi/180;F.Camera(v);assert(distance(engine.frame.eye,c.position)<1e-8)end
local yaw=c.yaw;mouse=true
-- Dispatch a drag only after native-style registration, rather than testing
-- an isolated OnMouseDown callback that WoW might never deliver to this floor.
assert(floor.dragButtons.RightButton);floor.scripts.OnDragStart(floor,'RightButton')
cursorX,cursorY=80,30;EC.Tick(v,0);assert(c.yaw~=yaw and c.pitch>-.35)
floor.scripts.OnMouseUp(floor,'LeftButton');assert(c.dragging,'left button-up cannot cancel a captured right drag')
floor.hover=false;floor.scripts.OnLeave();yaw=c.yaw;cursorX=100;EC.Tick(v,0)
assert(c.dragging and c.yaw~=yaw,'captured right drag continues after leaving the floor rectangle')
mouse=false;EC.Tick(v,0);assert(not c.dragging,'physical release ends look even when OnMouseUp is missed');floor.hover=true
mouse=true;floor.scripts.OnMouseDown(floor,'RightButton');assert(c.dragging)
floor.scripts.OnDragStop(floor);assert(not c.dragging);mouse=false
local followDistance=v.world3DInput.distance;start=copy(c.position)
s.groundClick.scripts.OnMouseWheel(s.groundClick,1);assert(math.abs(distance(start,c.position)-2)<1e-8)
assert(v.world3DInput.distance==followDistance,'editor dolly cannot change the player follow camera')
-- Editing forms, object dragging, combat and leaving the viewport release keys.
for _,block in ipairs({'focus','popup','drag','combat','lock','storage','hover'})do
 key('W',true);start=copy(c.position)
 if block=='focus'then focus=true elseif block=='popup'then editor.popup=frame()elseif block=='drag'then editor.dragging=true
 elseif block=='combat'then combat=true elseif block=='lock'then ns.UI2.locked=true elseif block=='storage'then ns.MainStorageBlocked=true else s.groundClick.hover=false end
 EC.Tick(v,.05);assert(distance(start,c.position)==0 and not next(c.keys),'camera input guard: '..block)
 key('W',true);assert(v.frame.propagate,'blocked keys must propagate to the focused UI')
 focus=false;editor.popup=nil;editor.dragging=false;combat=false;ns.UI2.locked=false;ns.MainStorageBlocked=false;s.groundClick.hover=true
end
key('W',true);s.groundClick.scripts.OnLeave();assert(not next(c.keys)and v.frame.propagate)
key('D',true);v.frame.scripts.OnHide();assert(not next(c.keys)and v.frame.propagate)
EC.Reset(v);c=EC.State(v);local follow=EC.FollowView(v);assert(distance(c.position,follow.position)==0)
assert(player.position[1]==0 and player.position[2]==-7 and player.position[3]==0 and player.scale==1.85,'free camera must not move or resize the Live player')
assert(not next(v.world3DInput.keys),'fly keys must never enter player movement')
editor.active=false;EC.Tick(v,.05);assert(not v.world3DEditCamera and not v.world3DCameraBar:IsShown())
F.Camera(v);assert(distance(engine.frame.eye,follow.position)==0,'closing editor restores the character follow camera')
local input=v.world3DInput;local playYaw=input.yaw;mouse=true
floor.scripts.OnDragStart(floor,'RightButton');cursorX=160;F.Look(input,-.3,1.2);assert(input.yaw~=playYaw,'the same registered right drag also controls play-camera orbit')
floor.scripts.OnMouseUp(floor,'RightButton');assert(not input.dragging);mouse=false
key('W',true);assert(v.world3DInput.keys.W,'normal player input resumes');key('W',false)
s.definition.world3D=false;editor.active=true;assert(not EC.Active(v),'legacy scenes never use the fly-camera adapter')
print('PASS: registered right-button drag in editor/play, mouse propagation and stale-frame stacking, capture/release outside floor, separate left clicks, fly/strafe/height/look/dolly, 360 camera calls, reset/follow, actor/Live isolation and focus/form/combat guards')
