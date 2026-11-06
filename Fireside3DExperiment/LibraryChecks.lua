local ns={}
for _,file in ipairs({'Vendor/WardenSceneObjectControls.lua','Vendor/WardenNativeScene.lua','WorldSpace.lua','Vendor/WardenComposition.lua','Vendor/AthenaBookMotion.lua','Vendor/AthenaBookObject.lua','SampleCatalogue.lua','ShelfState.lua','Library.lua'})do assert(loadfile('Fireside3DExperiment/'..file))('test',ns)end
-- Call-recording UI boundary for lifecycle errors only. No rendering or in-game success claim.
local mt={};local methods={}
function methods:GetWidth()return rawget(self,"width") or 1000 end
function methods:GetHeight()return rawget(self,"height") or 700 end
function methods:GetFrameLevel()return rawget(self,"level") or 1 end
function methods:SetFrameLevel(n)self.level=n end
function methods:SetSize(w,h)self.width=w;self.height=h end
function methods:SetWidth(w)self.width=w end
function methods:SetHeight(h)self.height=h end
function methods:SetScript(k,f)self.scripts[k]=f end
function methods:HookScript(k,f)local old=self.scripts[k];self.scripts[k]=function(...)if old then old(...)end;f(...)end end
function methods:Show()self.visible=true end
function methods:Hide()local was=self.visible;self.visible=false;if was and self.scripts.OnHide then self.scripts.OnHide(self)end end
function methods:IsShown()return self.visible end
function methods:SetShown(v)if v then self:Show()else self:Hide()end end
function methods:GetEffectiveScale()return 1 end
function methods:GetLeft()return 0 end
function methods:GetTop()return 700 end
function methods:SetText(s)self.text=s end
local function record()return setmetatable({scripts={},visible=true},mt)end
function methods:CreateTexture()return record()end
function methods:CreateFontString()return record()end
for _,key in ipairs({'SetPoint','ClearAllPoints','SetAllPoints','SetColorTexture','SetTexture','SetTexCoord','SetVertexColor','SetJustifyH','SetJustifyV','SetTextColor','EnableMouse','ClearFocus','SetDesaturated','SetParent','SetDrawLayer','SetAlpha','RegisterEvent','SetWordWrap','SetFrameStrata','SetAutoFocus'})do methods[key]=function()end end
mt.__index=methods
CreateFrame=function()return record()end
local now=0;GetTimePreciseSec=function()return now end;GetTime=GetTimePreciseSec
local native={actors={['room-book']={ready=true,capabilities={[146]=true,[147]=true,[148]=true,[149]=true}},['shelf-right']={ready=true}}}
function native:Animate(a,id)self.lastAnimation=id;return a and a.capabilities and a.capabilities[id]==true end
local opens=0
local l=ns.ExperimentLibrary.New(record(),native,{},function()opens=opens+1 end)
assert(l:Open('shelf-right'));assert(l.showcase:IsShown());assert(#l.work.slots==7)
l.work.slots[1]=nil;l:Close(true)
assert(l:Open('shelf-right'));assert(l.work.slots[1],'discarded work must not mutate saved session state')
l:Close(true);assert(l:Open('room-book'));assert(l:IsModal())
for i=1,30 do l:Tick(.1)end
assert(l.reader:IsShown());assert(l.reader.coverMotion,'existing cover transition should start')
l:Close();assert(l.bookTransition and not l.bookTransition.opening)
for i=1,30 do l:Tick(.1)end
assert(not l:IsModal() and native.lastAnimation==147)
assert(opens==3)
print('PASS: journal/showcase build and open/close lifecycle, cancel isolation, native book sequence requests (call-recording boundaries only)')
