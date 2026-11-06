-- Optional adapter for the existing editor. Camera state is transient and local;
-- no actor transform, layout record, character state or Live packet is changed.
local _,ns=...
local F,N=ns.Fireside3D,ns.WardenNativeScene
local E={};F.EditorCamera=E
local sin,cos,sqrt=math.sin,math.cos,math.sqrt
local function clamp(n,a,b)return math.max(a,math.min(b,n))end
function E.Active(v)
 local editor=ns.WardenSceneEditor
 return editor and editor.active and not editor.closing and F.IsScene(v:ActiveRoom())
  and(editor.scene==F.PRIMARY)and(not editor.Realm or editor.Realm()==v)or false
end
function E.Allowed(v,capturedLook)
 if not E.Active(v)or ns.UI2.locked or ns.MainStorageBlocked or InCombatLockdown()then return false end
 local editor=ns.WardenSceneEditor
 if editor.dragging or editor.popup and editor.popup:IsShown()then return false end
 return v.frame:IsVisible()and(capturedLook or v:ActiveRoom().groundClick:IsMouseOver())
  and not(GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())
end
function E.FollowView(v)
 local input=v.world3DInput;local a=v:ActiveRoom().native.actors.attendant
 local p=a and a.ready and a.position or{0,-7,0};local z=p[3]+1.3
 local h=input.distance*cos(input.pitch)
 return{position={p[1]-h*cos(input.yaw),p[2]-h*sin(input.yaw),math.max(.4,z+input.distance*sin(input.pitch))},target={p[1],p[2],z},fov=.85}
end
local function fromView(view)
 local p,t=view.position,view.target;local x,y,z=t[1]-p[1],t[2]-p[2],t[3]-p[3]
 local length=sqrt(x*x+y*y+z*z)
 return{position={p[1],p[2],p[3]},yaw=math.atan2(y,x),pitch=math.asin(clamp(z/length,-1,1)),keys={}}
end
function E.Reset(v)
 v.world3DEditCamera=fromView(E.FollowView(v));return v.world3DEditCamera
end
function E.State(v)
 return v.world3DEditCamera or E.Reset(v)
end
local function direction(c)return cos(c.pitch)*cos(c.yaw),cos(c.pitch)*sin(c.yaw),sin(c.pitch)end
local function translate(c,x,y,z)
 local p=c.position;p[1]=clamp(p[1]+x,-256,256);p[2]=clamp(p[2]+y,-256,256);p[3]=clamp(p[3]+z,.15,128)
end
function E.View(v)
 local c=E.State(v);local x,y,z=direction(c);local p=c.position
 return{position={p[1],p[2],p[3]},target={p[1]+x,p[2]+y,p[3]+z},fov=.85}
end
function E.Scroll(v,delta)
 if not E.Allowed(v)then return end
 local c=E.State(v);local x,y,z=direction(c);local amount=delta*(IsShiftKeyDown()and 6 or 2)
 translate(c,x*amount,y*amount,z*amount)
end
function E.Toolbar(v)
 if v.world3DCameraBar then return v.world3DCameraBar end
 local s=v:ActiveRoom();local bar=CreateFrame('Frame',nil,v.frame)
 bar:SetPoint('TOPLEFT',12,-12);bar:SetSize(510,58);bar:SetFrameLevel(s.groundClick:GetFrameLevel()+4)
 local bg=bar:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();bg:SetColorTexture(.025,.035,.045,.88)
 local help=bar:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');help:SetPoint('TOPLEFT',8,-7)
 help:SetText('Editor camera: WASD fly | Q/E down/up | Shift faster | Right-drag look | Wheel dolly')
 local reset=CreateFrame('Button',nil,bar,'UIPanelButtonTemplate');reset:SetPoint('TOPLEFT',8,-29);reset:SetSize(112,22);reset:SetText('Reset camera')
 reset:SetScript('OnClick',function()E.Reset(v)end)
 v.world3DCameraBar=bar;return bar
end
function E.Tick(v,dt)
 if not E.Active(v)then
  v.world3DEditCamera=nil
  if v.world3DCameraBar then v.world3DCameraBar:Hide()end
  return
 end
 local c=E.State(v);local bar=E.Toolbar(v)
 bar:SetFrameLevel(v:ActiveRoom().groundClick:GetFrameLevel()+4);bar:Show()
 if not E.Allowed(v,c.dragging)then c.keys={};c.dragging=false;return end
 F.Look(c,-1.50,1.50)
 if not E.Allowed(v)then c.keys={};return end
 local keys=c.keys;local forward=(keys.W and 1 or 0)-(keys.S and 1 or 0)
 local right=(keys.D and 1 or 0)-(keys.A and 1 or 0);local up=(keys.E and 1 or 0)-(keys.Q and 1 or 0)
 local fx,fy,fz=direction(c)
 local x,y,z=fx*forward+sin(c.yaw)*right,fy*forward-cos(c.yaw)*right,fz*forward+up
 local length=sqrt(x*x+y*y+z*z)
 if length>0 then local step=(IsShiftKeyDown()and 24 or 8)*clamp(dt,0,.05)/length;translate(c,x*step,y*step,z*step)end
end
function E.Clear(v)
 local c=v.world3DEditCamera;if c then c.keys={};c.dragging=false end
end
function E.BindExistingEditor()
 local editor=ns.WardenSceneEditor;if not editor or editor.fireside3DCameraBound or not editor.Open then return false end
 editor.fireside3DCameraBound=true
 -- Older launch buttons name the retired rooms. They now edit the single world.
 local open=editor.Open
 editor.Open=function(key,...)
  if key==nil or ns.WardenRoomCatalogue.HasRoom(key)then key=F.PRIMARY end
  -- Enter the editor over the wide world, including when launched from a menu.
  -- Otherwise the old Study preview route can open the real reader over it.
  local U=ns.UI2;local previous=U.menuHidden;U.menuHidden=true
  local ok,why=open(key,...)
  if not ok then U.menuHidden=previous;return ok,why end
  if U.ApplyMenuState then U.ApplyMenuState()end
  local v=editor.Realm and editor.Realm()
  if v and E.Active(v)then E.Reset(v);F.Camera(v)end
  return ok,why
 end
 return true
end
