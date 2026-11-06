-- Real public window manager + hitbox tool, with native fixed-level behavior.
-- Tests the full button tree after deferred focus changes, not just callbacks.
local ns={UI2={menuHidden=true},Fireside3D={PRIMARY='square'},WardenWorldScenes={}}
local function load(p)return assert(loadfile('OlympusChatWarden/'..p))('test',ns)end
local M={};local mt={__index=M}
local function frame(parent,region)
 local f=setmetatable({parent=parent,children={},scripts={},shown=true,w=1600,h=900,level=parent and parent:GetFrameLevel()+1 or 1},mt)
 if parent and not region then parent.children[#parent.children+1]=f end;return f
end
function M:GetChildren()return unpack(self.children)end;function M:GetParent()return self.parent end
function M:SetParent(p)if self.parent then for i,v in ipairs(self.parent.children)do if v==self then table.remove(self.parent.children,i);break end end end;self.parent=p;if p then p.children[#p.children+1]=self end end
function M:SetScript(k,v)self.scripts[k]=v end;function M:GetScript(k)return self.scripts[k]end
function M:HookScript(k,v)local old=self.scripts[k];self.scripts[k]=function(...)if old then old(...)end;v(...)end end
function M:IsShown()return self.shown end;function M:IsVisible()return self.shown and(not self.parent or self.parent:IsVisible())end
function M:Show()self.shown=true end
function M:Hide()local old=self.shown;self.shown=false;if old and self.scripts.OnHide then self.scripts.OnHide(self)end end
function M:SetShown(v)if v then self:Show()else self:Hide()end end
function M:GetFrameLevel()return self.level end
function M:SetFrameLevel(n)if self.fixedLevel then return end;local delta=n-self.level;self.level=n;for _,c in ipairs(self.children)do c:SetFrameLevel(c:GetFrameLevel()+delta)end end
function M:SetFixedFrameLevel(v)self.fixedLevel=v end;function M:SetFixedFrameStrata(v)self.fixedStrata=v end
function M:GetFrameStrata()return self.strata or(self.parent and self.parent:GetFrameStrata())or'MEDIUM'end
function M:SetFrameStrata(v)if not self.fixedStrata then self.strata=v end end
function M:GetScale()return self.scale or 1 end;function M:SetScale(v)self.scale=v end
function M:GetEffectiveScale()return self:GetScale()*(self.parent and self.parent:GetEffectiveScale()or 1)end
function M:GetWidth()return self.anchor and self.anchor:GetWidth()*self.anchor:GetEffectiveScale()/self:GetEffectiveScale()or self.w end
function M:GetHeight()return self.anchor and self.anchor:GetHeight()*self.anchor:GetEffectiveScale()/self:GetEffectiveScale()or self.h end
function M:SetAllPoints(r)self.anchor=r or self.parent end
function M:SetPoint(...)self.point={...}end;function M:SetSize(w,h)self.w=w;self.h=h end;function M:SetWidth(w)self.w=w end
function M:CreateTexture()return frame(self,true)end;function M:CreateFontString()return frame(self,true)end;function M:CreateLine()return frame(self,true)end
function M:SetText(v)self.text=v end;function M:EnableMouse(v)self.mouse=v end;function M:IsMouseEnabled()return self.mouse==true end
function M:IsMouseOver()return false end;function M:EnableMouseWheel(v)self.wheel=v end;function M:EnableKeyboard(v)self.keyboard=v end
for _,key in ipairs({'ClearAllPoints','SetColorTexture','SetJustifyH','RegisterForClicks','RegisterForDrag','SetStartPoint','SetEndPoint','SetThickness','SetToplevel','RegisterEvent','SetPropagateKeyboardInput'})do M[key]=function()end end
UIParent=frame()
CreateFrame=function(kind,_,p)local f=frame(p);f.mouse=kind=='Button';return f end
hooksecurefunc=function(f,key,hook)local old=f[key];f[key]=function(self,...)local r=old(self,...);hook(self,...);return r end end
local queue={};C_Timer={After=function(_,fn)queue[#queue+1]=fn end}
local function flush()while #queue>0 do local batch=queue;queue={};for _,fn in ipairs(batch)do fn()end end end
local focus;GetCurrentKeyBoardFocus=function()return focus end;InCombatLockdown=function()return false end
load('Theme.lua');load('WardenSceneObjectControls.lua');load('WardenNativeScene.lua');load('World3D/Coordinates.lua');load('World3D/Scene.lua');load('World3D/Hitboxes.lua');load('World3D/HitboxEditor.lua');load('World3D/EditorCamera.lua')
local F,N,H,T=ns.Fireside3D,ns.WardenNativeScene,ns.Fireside3D.Hitboxes,ns.Fireside3D.HitboxEditor
F.IsScene=function(s)return s.definition.world3D end
local v={frame=frame(UIParent)};ns.Theme.RegisterWindow(v.frame);v.frame:Show()
local engine={world3D=true,frame=frame(v.frame),shot={position={0,-12,10},target={0,10,1},fov=.85},actors={}}
engine.frame:SetAllPoints(v.frame)
N.ProjectNative=function(f,s,x,y,z)return N.Project(s,x,y,z,f:GetWidth()/f:GetHeight())end
local a={id='tent',engine=engine,ready=true,scale=1,bounds={-3,-3,0,3,3,4},position={0,10,0},spec={fileID=202016,label='Tent',collision=false}}
engine.actors.tent=a
local scene={native=engine,definition={world3D=true},groundClick=frame(v.frame)};function v:ActiveRoom()return scene end
local e={active=true,scene='square',selected='native/tent',panel={frame=frame(UIParent)},Realm=function()return v end}
local current={x=0,y=10,z=0,yaw=0,scale=1};local calls=0
function e.Value()return H.Copy(current),{kind='native',engine=engine,id='tent'}end
function e.Set(_,r)current=H.Copy(r);a.collider=H.Copy(r.collider);a.hitbox=H.Copy(r.hitbox);calls=calls+1;return true end
function e.Message(s)e.lastMessage=s end
function e.ShowForm(spec)e.form=spec;e.popup=frame(UIParent);ns.Theme.RegisterModal(e.popup,e.panel.frame);e.popup:Show()end
ns.WardenSceneEditor=e
ns.Theme.RegisterModal(e.panel.frame,v.frame);e.panel.frame:Show()
v.world3DEditSurface=CreateFrame('Button',nil,v.frame);F.EditorCamera.SyncInput(v)
assert(T.Open(v,'collider'));local tool=v.world3DHitboxTool
assert(tool.panel:GetParent()==e.panel.frame and tool.overlay:GetParent()==e.panel.frame,'whole tool must belong to the registered editor window')
local ranks={HIGH=1,DIALOG=2,FULLSCREEN_DIALOG=3}
local function above(a,b)return ranks[a:GetFrameStrata()]>ranks[b:GetFrameStrata()]or a:GetFrameStrata()==b:GetFrameStrata()and a:GetFrameLevel()>b:GetFrameLevel()end
local function action(label)
 for _,b in ipairs(tool.panel.children)do if b.text==label then return b end end;error('missing button '..label)
end
local function checkTree()
 F.EditorCamera.SyncInput(v)
 for _,b in ipairs(tool.panel.children)do if b.scripts.OnClick then
  assert(b:GetFrameStrata()==tool.panel:GetFrameStrata()and above(b,v.world3DEditSurface),'button below camera after focus: '..b.text)
 end end
 for _,h in ipairs(tool.handles)do assert(above(action('Exact values'),h),'handles must not cover panel buttons')end
end
local function click(label)
 local b=action(label);ns.Theme.FocusWindow(v.frame);flush();T.Draw(v);checkTree()
 focus={ClearFocus=function()focus=nil end};assert(not T.Allowed(v),'typing stays guarded until an explicit tool action')
 if b.scripts.OnMouseDown then b.scripts.OnMouseDown(b,'LeftButton')end
 if b.scripts.OnMouseUp then b.scripts.OnMouseUp(b,'LeftButton')end
 b.scripts.OnClick(b,'LeftButton');flush();assert(focus==nil,'tool action must release stale text focus')
end
local viewRect={GetLeft=function()return 0 end,GetTop=function()return 900 end,GetWidth=function()return 1600 end,GetHeight=function()return 900 end,GetEffectiveScale=function()return 1 end}
local coverScale=1
local panelRect={IsVisible=function()return true end,GetLeft=function()return 10 end,GetRight=function()return 370 end,GetTop=function()return 800 end,GetBottom=function()return 596 end,GetEffectiveScale=function()return coverScale end}
assert(T.Covered(viewRect,.1,.2,{panelRect})and not T.Covered(viewRect,.6,.6,{panelRect}),'world handles cannot cover editor controls')
coverScale=.5;assert(T.Covered(viewRect,.1,.6,{panelRect}),'panel exclusion must account for independent UI scale')
checkTree();click('Add box');assert(calls==1 and #a.collider.boxes==1)
click('Duplicate');assert(#a.collider.boxes==2)
click('On / Off');assert(a.collider.boxes[2].enabled==false)
click('Auto-fit box');assert(a.collider.boxes[2].enabled and a.collider.boxes[2].width==6)
click('Exact values');assert(e.form and e.popup:IsShown());T.Draw(v);assert(not tool.overlay:IsShown())
e.popup:Hide();e.popup=nil;flush();T.Draw(v);checkTree()
click('Use automatic');assert(a.collider==nil)
click('Add box');click('Remove');assert(#a.collider.boxes==0)
click('Click area');assert(tool.kind=='hitbox');click('Walking');assert(tool.kind=='collider')
for i=1,10 do ns.Theme.FocusWindow(v.frame);ns.Theme.FocusWindow(e.panel.frame);flush();T.Draw(v);checkTree()end
v.frame:Hide();assert(not tool.panel:IsShown()and not tool.overlay:IsShown())
print('PASS: real Theme window restacking with fixed native levels, entire hitbox button tree above camera/handles, explicit text-focus release, all lower-row actions, popup return and owner hide')
