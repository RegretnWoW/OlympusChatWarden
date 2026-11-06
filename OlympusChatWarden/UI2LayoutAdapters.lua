-- Specialized book/foreign-host boundaries. No foreign Blizzard/Olympus frames move.
local _,ns=...
local E,U=ns.UI2LayoutEngine,ns.UI2
local function values(name) local t={};for _,c in ipairs(E.Get(name).cards) do t[c.id]=c end;return t end
local journal=U.LayoutJournal
function U.LayoutJournal()
 journal();local host=U.journalHost;if not host or U.immersive then return end
 local v=values('journey.chrome');local w=host:GetWidth();local owner=v.owner;local width=math.min(250,math.max(150,w*owner.span/12-12))
 host.ownerMenu:ClearAllPoints();host.ownerMenu:SetPoint('TOPLEFT',owner.region=='right' and w-width or owner.region=='center' and (w-width)/2 or 0,-1);host.ownerMenu:SetWidth(width)
 host.syntheticLabel:ClearAllPoints();local source=v.source;local x=source.region=='left' and 0 or source.region=='center' and w*.36 or w*.62
 -- Two essential labels sharing a requested lane stack safely in this chrome row.
 if source.region==owner.region then x=math.min(w-240,(owner.region=='right' and w-width or owner.region=='center' and (w-width)/2 or 0)+width+8) end
 host.syntheticLabel:SetPoint('TOPLEFT',x,-9);host.syntheticLabel:SetWidth(math.max(160,math.min(w-x-6,w*source.span/12-12)))
end
local build=ns.AthenaJournalUI.Build
function ns.AthenaJournalUI.Build(parent,host)
 local reader=build(parent,host);local layout=reader.Layout
 function reader:Layout(w,h)
  local v=values('journey.chrome');self.ui2Chrome=v.library;layout(self,w,h)
 end
 return reader
end
local panel=ns.OlympusPanel;local layout=panel.Layout
function panel.Layout(page)
 layout(page);if not page.warden or not ns.Membership.Allowed() then return end
 local v=page.warden;local pref=values('olympus.panel');local features=pref.features;local activity=pref.activity
 local top=48;local maxBottom=top;for _,f in ipairs(v.features) do if f:IsShown() then maxBottom=math.max(maxBottom,(v.content:GetTop()-f:GetTop())+f:GetHeight()+3) end end
 if features.hidden then for _,f in ipairs(v.features) do f:Hide() end end
 if activity.order<features.order or features.hidden then
  local cw=v.content:GetWidth();local height=math.max(70,page:GetHeight()-150-(features.hidden and 0 or maxBottom-top))
  for _,filter in ipairs(v.filters) do if filter:IsShown() then local _,_,_,x=filter:GetPoint();filter:ClearAllPoints();filter:SetPoint('TOPLEFT',x,-48) end end
  v.activity:ClearAllPoints();v.activity:SetPoint('TOPLEFT',0,-82);v.activity:SetSize(cw,height);v.listView:Resize(cw-40,math.max(20,height-33))
  if not features.hidden then for _,f in ipairs(v.features) do if f:IsShown() then local _,_,_,x,y=f:GetPoint();f:ClearAllPoints();f:SetPoint('TOPLEFT',x,-(86+height)) end end end
 end
end
