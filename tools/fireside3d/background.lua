-- Regression for cold native projection/texture readiness without a WoW renderer.
local ns={Fireside3D={},WardenNativeScene={}}
local function load(p)return assert(loadfile('OlympusChatWarden/'..p))('test',ns)end
local ready=false;local methods={};local mt={__index=methods}
local function frame()return setmetatable({visible=true,w=1600,h=900,uvChanges=0},mt)end
function methods:GetWidth()return self.w end;function methods:GetHeight()return self.h end;function methods:GetEffectiveScale()return 1 end
function methods:SetSize(w,h)self.w=w;self.h=h end;function methods:SetHeight(h)self.h=h end
function methods:CreateTexture()return frame()end
function methods:SetTexture(path)self.path=path end
function methods:SetColorTexture(r,g,b)self.color={r,g,b}end
function methods:SetPoint()end;function methods:SetAllPoints()end;function methods:ClearAllPoints()end;function methods:SetClipsChildren()end;function methods:SetVertexColor()end
function methods:SetTexCoord(...)self.uvChanges=self.uvChanges+1;self.uv={...};for _,n in ipairs(self.uv)do assert(n==n and math.abs(n)<10000)end end
function methods:Show()self.visible=true end;function methods:Hide()self.visible=false end;function methods:SetShown(v)self.visible=v end
function methods:IsObjectLoaded()return ready end
local native=frame();local viewport=frame();local shot={position={0,-18,8},target={0,0,1},fov=.85}
ns.WardenNativeScene.ProjectNative=function(f,_,x,y)if f.unready then return end;return .5+x*.05+(f.jitter or 0),.8-y*.02 end
load('World3D/Coordinates.lua');load('World3D/Background.lua')
local bg=ns.Fireside3D.Background.New(viewport)
native.unready=true;bg:Update(native,shot);assert(not bg.rows[100].texture.visible)
native.unready=false;bg:Update(native,shot);assert(not bg.warm and not bg.rows[100].texture.visible)
bg:Update(native,shot);assert(bg.warm and bg.rows[100].under.visible and not bg.rows[100].texture.visible,'cold texture keeps a green ground backing')
assert(bg.rows[100].under.color[2]>.25)
ready=true;bg:Update(native,shot);assert(bg.rows[100].texture.visible)
local updates=bg.rows[100].texture.uvChanges;for i=1,30 do bg:Update(native,shot)end
assert(bg.rows[100].texture.uvChanges==updates,'idle grass cannot rebuild UVs/rectangles every frame')
native.unready=true;bg:Update(native,shot);assert(bg.rows[100].texture.visible and bg.rows[100].texture.uvChanges==updates,'temporary native cache loss must retain the last valid grass')
native.unready=false;native.jitter=.01;bg:Update(native,shot);assert(bg.rows[100].texture.uvChanges==updates+1,'real native projection changes update grass')
viewport.w=1200;native.unready=true;bg:Update(native,shot);assert(not bg.rows[100].texture.visible and not bg.warm,'resize cannot reuse stale geometry')
native.unready=false;bg:Update(native,shot);bg:Update(native,shot);assert(bg.warm and bg.rows[100].texture.visible)
local file=assert(io.open('OlympusChatWarden/World3D/Scene.lua'));local source=file:read('*a');file:close();assert(not source:find('Wood.tga',1,true),'no wooden path overlay remains')
print('PASS: native grass warmup, async texture backing, retained valid projection, idle UV caching, resize recovery and no wood path overlay')
