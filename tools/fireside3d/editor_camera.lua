-- Actual public input/camera adapters at recorded native boundaries. No private addon or network.
local ns={UI2={menuHidden=true},Fireside3D={PRIMARY='square',preferredBuilding={fileID=202016,label='Furbolg forest tent',renderEvidence='USER_REPORT'}},WardenRoomCatalogue={HasRoom=function(k)return k=='hall'or k=='study'or k=='square'end}}
local function load(p)return assert(loadfile('OlympusChatWarden/'..p))('test',ns)end
local methods={};local mt={__index=methods}
local function frame(parent)return setmetatable({parent=parent,scripts={},visible=true,hover=true},mt)end
function methods:SetScript(k,v)self.scripts[k]=v end
function methods:GetScript(k)return self.scripts[k]end
function methods:HookScript(k,v)local old=self.scripts[k];self.scripts[k]=function(...)if old then old(...)end;return v(...)end end
function methods:IsVisible()return self.visible and(not self.parent or self.parent:IsVisible())end
function methods:IsShown()return self.visible end
function methods:Show()self.visible=true end
function methods:Hide()local was=self.visible;self.visible=false;if was and self.scripts.OnHide then self.scripts.OnHide(self)end end
function methods:SetShown(v)if v then self:Show()else self:Hide()end end
function methods:IsMouseOver()return self.hover end
function methods:CreateTexture()return frame(self)end
function methods:CreateFontString()return frame(self)end
function methods:GetFrameLevel()return self.level or 10 end
function methods:SetFrameLevel(v)self.level=v end
function methods:GetFrameStrata()return self.strata or'DIALOG'end
function methods:SetFrameStrata(v)self.strata=v end
function methods:GetChildren()return unpack(self.children or{})end
function methods:SetParent(v)self.parent=v end
function methods:GetWidth()return self.width or 1600 end
function methods:GetHeight()return self.height or 900 end
function methods:GetEffectiveScale()return 1 end
function methods:SetSize(w,h)self.width=w;self.height=h end
function methods:RegisterForClicks(...)self.clicks={};for _,b in ipairs({...})do self.clicks[b]=true end end
function methods:RegisterForDrag(...)self.dragButtons={};for _,b in ipairs({...})do self.dragButtons[b]=true end end
function methods:SetPropagateMouseClicks(v)self.propagateClicks=v end
function methods:SetPropagateMouseMotion(v)self.propagateMotion=v end
function methods:SetPropagateKeyboardInput(v)self.propagate=v end
function methods:EnableMouse(v)self.mouse=v end
function methods:EnableMouseWheel(v)self.wheel=v end
function methods:EnableKeyboard(v)self.keyboard=v end
function methods:SetCameraPosition(x,y,z)self.eye={x,y,z};self.cameraCalls=(self.cameraCalls or 0)+1 end
function methods:SetCameraOrientationByYawPitchRoll(y,p,r)self.angles={y,p,r}end
for _,k in ipairs({'SetPoint','ClearAllPoints','SetAllPoints','SetColorTexture','SetText','SetCameraFieldOfView','SetCameraNearClip','SetCameraFarClip'})do methods[k]=function()end end
CreateFrame=function(_,_,parent)return frame(parent)end
local focus,combat,shift,right=false,false,false,false;local x,y=0,0
GetCurrentKeyBoardFocus=function()return focus end;InCombatLockdown=function()return combat end
IsShiftKeyDown=function()return shift end;IsMouseButtonDown=function()return right end
GetCursorPosition=function()return x,y end
load('WardenSceneObjectControls.lua');load('WardenNativeScene.lua');load('World3D/Scene.lua');load('World3D/Hitboxes.lua');load('World3D/HitboxEditor.lua');load('World3D/EditorCamera.lua')
local F,EC=ns.Fireside3D,ns.Fireside3D.EditorCamera
F.IsScene=function(s)return s.definition.world3D==true end
local player={ready=true,position={0,-4,0},scale=1.85}
local engine={actors={attendant=player},frame=frame(),shot={position={0,-18,8},target={0,0,1},fov=.85}}
engine.Place=function()error('camera cannot move the player')end
local scene={definition={world3D=true},frame=frame(),native=engine,groundClick=frame(),active=true};scene.shot=engine.shot
local v={frame=frame(),forest=scene,cameraMix=0};function v:ActiveRoom()return scene end
local U=ns.UI2;U.window=frame();U.stage=frame();U.canvas=frame();U.canvas:SetFrameLevel(80)
F.BindInput(v,U)
local floor=scene.groundClick
assert(floor.clicks.RightButtonDown and floor.dragButtons.RightButton)
local higher=frame();higher:SetFrameLevel(70);scene.frame.children={higher,floor}
v:RefreshFieldInput();assert(floor:GetFrameLevel()==71);v:RefreshFieldInput();assert(floor:GetFrameLevel()==71)
-- Wheel dispatch must reach the menu, not the high-level scenic floor.
local menuScroll=0;U.canvas:EnableMouseWheel(true);U.canvas:SetScript('OnMouseWheel',function(_,delta)menuScroll=menuScroll-delta*58 end)
U.menuHidden=false;v:RefreshFieldInput();assert(not floor.wheel and not floor.mouse and not floor:IsShown())
local distance=v.world3DInput.distance
local function wheel(top,bottom,delta)if top:IsVisible()and top.wheel then top.scripts.OnMouseWheel(top,delta)else bottom.scripts.OnMouseWheel(bottom,delta)end end
wheel(floor,U.canvas,-1);assert(menuScroll==58 and v.world3DInput.distance==distance,'menu wheel must not be swallowed by disabled scene input')
U.menuHidden=true;v:RefreshFieldInput();assert(floor.wheel and floor.mouse and floor:IsShown())
local editor={active=false,panel={frame=frame()},Realm=function()return v end};editor.panel.frame.level=160;editor.panel.frame.hover=false;editor.panel.frame.strata='FULLSCREEN_DIALOG'
local fail=false
editor.Open=function(key)
 if fail then return false,'existing guard'end
 editor.closing=true;editor.scene=key;editor.active=true;v:RefreshFieldInput();editor.closing=nil;return true
end
editor.Close=function()editor.closing=true;editor.active=false;v:RefreshFieldInput();editor.closing=nil end
ns.WardenSceneEditor=editor
local added=0;F.Catalog={SpawnPreferred=function()added=added+1;return true end}
assert(EC.BindExistingEditor());assert(not EC.BindExistingEditor())
fail=true;U.menuHidden=false;assert(not editor.Open('square')and U.menuHidden==false);fail=false
assert(editor.Open('study'));assert(editor.scene=='square')
local surface=v.world3DEditSurface
assert(surface and surface:IsVisible()and surface.keyboard and surface.mouse and surface.wheel)
assert(not floor.wheel and not floor:IsShown()and not v.frame.keyboard,'editor input has its own surface; gameplay floor/keyboard must release')
assert(surface:GetFrameStrata()=='FULLSCREEN_DIALOG'and surface:GetFrameLevel()<editor.panel.frame:GetFrameLevel())
local function step(dt)surface.scripts.OnUpdate(surface,dt or .05)end
local function key(k,down)surface.scripts[down and'OnKeyDown'or'OnKeyUp'](surface,k)end
local function copy(p)return{p[1],p[2],p[3]}end
local function d(a,b)return math.sqrt((a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2)end
step(0);local c=EC.State(v);local start=copy(c.position)
assert(added==0 and v.world3DCameraBar.addModelTest);v.world3DCameraBar.addModelTest.scripts.OnClick();assert(added==1)
key('W',true);assert(surface.propagate==false,'editor camera keys must be consumed by their receiving surface');step();key('W',false);assert(math.abs(d(start,c.position)-.4)<1e-8)
shift=true;start=copy(c.position);key('D',true);step();key('D',false);assert(math.abs(d(start,c.position)-1.2)<1e-8);shift=false
start=copy(c.position);key('E',true);step();key('E',false);assert(c.position[3]>start[3]and c.position[1]==start[1]);key('Q',true);step();key('Q',false);assert(d(start,c.position)<1e-8)
-- Native modal focus can prevent OnKeyDown; guarded physical-key polling still works.
IsKeyDown=function(k)return k=='W'end;start=copy(c.position);step();assert(d(start,c.position)>.39)
IsKeyDown=function()return false end;step(0);IsKeyDown=nil
-- Right look through the dedicated modal-level surface, including native-event loss.
right=true;surface.scripts.OnDragStart(surface,'RightButton');local yaw=c.yaw;x=50;y=20;step(0);assert(c.yaw~=yaw)
surface.scripts.OnMouseUp(surface,'LeftButton');assert(c.dragging)
surface.hover=false;surface.scripts.OnLeave();yaw=c.yaw;x=70;step(0);assert(c.dragging and c.yaw~=yaw)
right=false;step(0);assert(not c.dragging);surface.hover=true
-- Poll press when mouse-down was swallowed by native focus.
right=true;step(0);yaw=c.yaw;x=90;step(0);assert(c.yaw~=yaw)
GetMouseDelta=function()return 4,2 end;yaw=c.yaw;step(0);assert(c.yaw~=yaw,'captured cursor can report relative motion without absolute movement');GetMouseDelta=nil
right=false;step(0)
start=copy(c.position);surface.scripts.OnMouseWheel(surface,1);assert(math.abs(d(start,c.position)-2)<1e-8)
for _,block in ipairs({'focus','popup','objectdrag','boxdrag','combat','panel','storage'})do
 key('W',true);start=copy(c.position)
 if block=='focus'then focus=true elseif block=='popup'then editor.popup=frame()elseif block=='objectdrag'then editor.dragging=true elseif block=='boxdrag'then editor.firesideBoxDragging=true
 elseif block=='combat'then combat=true elseif block=='panel'then editor.panel.frame.hover=true else ns.MainStorageBlocked=true end
 step();assert(d(start,c.position)==0 and not next(c.keys),'guard: '..block)
 if block=='popup'or block=='objectdrag'or block=='boxdrag'or block=='combat'or block=='storage'then assert(not surface.wheel and not surface.keyboard)end
 focus=false;editor.popup=nil;editor.dragging=false;editor.firesideBoxDragging=nil;combat=false;editor.panel.frame.hover=false;ns.MainStorageBlocked=false;step(0)
end
local oldCalls=engine.frame.cameraCalls;for i=1,20 do step(0)end;assert(engine.frame.cameraCalls==oldCalls,'idle editor cannot reset native camera every frame')
for turn=0,359 do c.yaw=turn*math.pi/180;step(0);assert(d(engine.frame.eye,c.position)<1e-8)end
assert(player.position[1]==0 and player.position[2]==-4 and player.position[3]==0 and player.scale==1.85)
editor.Close();assert(not surface:IsShown()and not surface.wheel and not surface.keyboard and v.frame.keyboard)
assert(not v.world3DEditCamera and floor.wheel and floor:IsShown())
local follow=EC.FollowView(v);assert(d(engine.frame.eye,follow.position)<1e-8)
local calls=engine.frame.cameraCalls;F.Camera(v);F.Camera(v);assert(engine.frame.cameraCalls==calls,'idle play view cannot invalidate projection repeatedly')
U.menuHidden=false;v:RefreshFieldInput();wheel(floor,U.canvas,-1);assert(menuScroll==116,'menu scrolling resumes after editor closes')
print('PASS: menu wheel delivery, dedicated modal-level editor surface/driver, keyboard/mouse polling fallback, capture/release, fly/strafe/height/dolly, panel/form/combat guards, 360 camera, idle-camera caching and player-state isolation')
