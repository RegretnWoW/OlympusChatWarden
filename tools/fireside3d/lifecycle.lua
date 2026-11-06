-- Call-recording realm boundary: validates construction/lifecycle, not native rendering.
local ns={WardenWorldScenes={layers={'contact-shadows','native','outside-native','book','shelf-badges'},props={},residents={},outside={},navigation={},shots={},lighting={},clouds={}},DB={livingRealmAmbience=true},UI2={}}
local function load(p)return assert(loadfile('OlympusChatWarden/'..p))('test',ns)end
local methods={};local mt={__index=methods}
local function frame(parent)return setmetatable({parent=parent,scripts={},visible=true},mt)end
function methods:GetWidth()return rawget(self,'width')or 1600 end
function methods:GetHeight()return rawget(self,'height')or 900 end
function methods:GetFrameLevel()return rawget(self,'level')or 1 end
function methods:GetEffectiveScale()return 1 end
function methods:GetLeft()return 0 end
function methods:GetTop()return 900 end
function methods:SetSize(w,h)self.width=w;self.height=h end
function methods:SetHeight(h)self.height=h end
function methods:SetWidth(w)self.width=w end
function methods:SetFrameLevel(n)self.level=n end
function methods:SetParent(p)self.parent=p end
function methods:RegisterForDrag(...)self.dragButtons={...}end
function methods:CreateTexture()return frame(self)end
function methods:CreateFontString()return frame(self)end
function methods:SetScript(k,v)self.scripts[k]=v end
function methods:GetScript(k)return self.scripts[k]end
function methods:HookScript(k,v)local before=self.scripts[k];self.scripts[k]=function(...)if before then before(...)end;return v(...)end end
function methods:Show()self.visible=true end
function methods:Hide()self.visible=false end
function methods:IsVisible()return self.visible and(not self.parent or self.parent:IsVisible())end
function methods:IsShown()return self.visible end
function methods:SetShown(v)self.visible=v end
function methods:IsMouseOver()return false end
function methods:IsMouseEnabled()return true end
for _,k in ipairs({'SetAlpha','SetJustifyV','SetAllPoints','SetPoint','ClearAllPoints','SetTexture','SetColorTexture','SetTexCoord','SetVertexColor','SetText','SetTextColor','SetJustifyH','SetFrameStrata','EnableMouse','EnableKeyboard','EnableMouseWheel','SetPropagateKeyboardInput','SetClipsChildren','RegisterForClicks','RegisterEvent','SetCameraPosition','SetCameraOrientationByYawPitchRoll','SetCameraFieldOfView','SetCameraNearClip','SetCameraFarClip'})do methods[k]=function()end end
CreateFrame=function(_,_,parent)return frame(parent)end
InCombatLockdown=function()return false end
load('WardenRoomCatalogue.lua');local C=ns.WardenRoomCatalogue
for _,key in ipairs({'hall','study','square'})do assert(C.RegisterRoom(key,{label=key,layoutSlot=key,shot={position={0,-18,8},target={0,0,1},fov=.85},navigation={floor=0,floorUV={0,0,1,1}},plates={},props={},residents={}}))end
C.onRegister=function(key,d)local S=ns.WardenWorldScenes;S.props[key]=d.props;S.residents[key]=d.residents;S.outside[key]=d.outside;S.navigation[key]=d.navigation end
ns.WardenWorldScenes.Room=C.Room
ns.WardenWorldScenes.Props=function(s)return s.definition.props end
ns.WardenWorldScenes.Route=function()return nil end
ns.WardenRealm={};ns.WardenSceneGraph={Frame=function(parent)return frame(parent)end}
ns.WardenSceneAssets={};ns.WardenWorldArt={assets={}}
ns.WardenArt={Path=function()return'test-texture'end}
ns.WardenSceneLighting={Open=function()return'day'end}
ns.WardenSanctuary={ActiveBypass=function()return false end}
ns.SafeCall=function(fn,...)if fn then return fn(...)end end
ns.SafeNumber=function(n)return type(n)=='number'and n or nil end
ns.Checked=function(v)return v==true end
ns.WardenWorldScale={Request=function()return true end}
ns.AetherLive={World={active=false,NPCs={},NPC=function()end}}
ns.WardenShelfShowcase={Render=function()end,ResetCamera=function()end}
load('WardenSceneObjectControls.lua');load('WardenNativeScene.lua');load('World3D/Definitions.lua');load('World3D/Coordinates.lua');load('World3D/Background.lua');load('World3D/Scene.lua');load('World3D/Hitboxes.lua');load('World3D/HitboxEditor.lua');load('World3D/EditorCamera.lua');load('World3D/Catalog.lua')
local count=0
ns.WardenNativeScene.Create=function(parent,shot)
 count=count+1
 local engine={frame=frame(parent),actors={},order={},views={},shot=shot,metrics={moves=0},status='call-recording',clock=0}
 function engine:Add(spec)if self.actors[spec.id]then return self.actors[spec.id]end;local a={id=spec.id,spec=spec,ready=false};self.actors[spec.id]=a;self.order[#self.order+1]=a;return a end
 function engine:Reuse(spec)return self:Add(spec)end
 function engine:Lighting()end;function engine:Pause()end;function engine:Show()end;function engine:Tick()end
 function engine:RenderFrames()return{self.frame}end
 return engine
end
load('WardenWorldRealm.lua')
-- Exercise retained canonical and Live wrapper construction without credentials or transport.
ns.Chronicle={Owner=function()return 'demo-owner' end}
ns.WardenRoomBook={Bind=function()end}
ns.AetherLiveGameplay={Scenes={square='a',hall='f'}}
ns.Art={Text=function(parent)return frame(parent)end,Button=function(parent)return frame(parent)end}
ns.Theme={RegisterModal=function()end}
ns.UI2Forms={}
load('WardenRoomTravel.lua')
load('WardenShelfShowcase.lua')
load('WardenCanonicalPlayer.lua')
load('AetherLiveWorld92.lua')
load('World3D/Integration.lua')
local U=ns.UI2;U.window=frame();U.header=frame(U.window);U.stage=frame(U.window);U.canvas=frame(U.stage);U.route={page='overview'};U.menuHidden=true
U.CreateJournalHost=function()error('Journal must remain lazy until interaction')end
local v=ns.WardenRealm.Attach(U,U.window)
assert(count==1 and #v:Scenes()==1,'only one native viewport and one actual room may initialize')
assert(v.studyScene==v.forest and v:EnsureRoom('study')==v.forest and v:EnsureRoom('hall')==v.forest)
assert(v.forest.key=='square'and v.forest.nativeAir.frame==nil and v.forest.native.world3D)
v:Select({page='overview'},false,true)
assert(count==1 and not U.journalHost,'landing should not construct old scenes or the real reader')
assert(#v.forest.native.order==#ns.Fireside3D.props+1,'only neighborhood props and one controlled player requested')
local tents=0;for _,a in ipairs(v.forest.native.order)do if ns.Fireside3D.BuildingCandidate(a.spec.fileID)then assert(a.id=='player-home'and a.spec.fileID==202016,'only the user-confirmed tent can start automatically');tents=tents+1 end end
assert(tents==1,'exactly one camp shelter')
assert(#C.Rooms()==1 and #C.Connections('square')==0)
v:Advance(.016)
print('PASS: real realm constructor/selection/update at recorded API boundaries; one native viewport, no Fields/Home/Town instance or travel links, lazy real Journal')
local npcTicks=0;local W=ns.AetherLive.World
W.NPC=function()npcTicks=npcTicks+1 end
ns.WardenSceneEditor={active=true,scene='square'}
v:Advance(.016);assert(npcTicks==0,'free-camera editing must retain the existing editor NPC pause')
assert(not v:ClickScene(v.forest,.5,.5),'editor camera input must not issue a player interaction')
ns.WardenSceneEditor.active=false;v:Advance(.016);assert(npcTicks>0,'normal NPC updates resume after editing')
print('PASS: editor input isolation and retained NPC pause/resume')
