-- Torch first-pass presentation resources. No state, permissions or collectors.
local _,ns=...
local A={VERSION=1,base='Interface\\AddOns\\OlympusChatWarden\\Media\\Torch\\'};ns.WardenArt=A
-- One new material family; historical/badge art uses its own untouched registry.
A.worldBase='Interface\\AddOns\\OlympusChatWarden\\Media\\WorldUI38\\'
A.world={ButtonNormal=true,ButtonHover=true,ButtonSelected=true,ButtonPressed=true,ButtonDisabled=true,SectionHeader=true,PanelFrame=true,Parchment=true,TempleBackdrop=true,HeaderBackdrop=true,BrandHeader=true,TorchEmblem=true,Wood=true}
for _,name in ipairs({'Hall','Aether','Athenaeum','Journal','Chronicle','Chat','Shield','Signal','Settings','Dossiers','Relay'})do A.world['Icon'..name]=true end
A.icons={overview='Hall',intel='Aether',wiki='Athenaeum',journey='Oasis',chronicle='Chronicle',messages='Chat',shield='Shield',mentions='Vigil',notifications='Signal',relay='Relay',settings='Settings',dossiers='Dossiers'}
A.legacy={Warden='TorchEmblem',CommandWarden='IconHall',ChronicleWarden='IconJournal',IntelWarden='IconDossiers',ChatWarden='IconChat',ShieldWarden='IconShield',SignalWarden='IconSignal',RelayWarden='IconRelay'}
local iconBounds={Hall={6,22,123,128},Aether={5,15,124,128},Athenaeum={4,25,124,128},Journal={4,24,125,128},Chronicle={6,0,124,128},Dossiers={5,0,123,117},Chat={5,0,124,128},Shield={4,11,124,116},Signal={6,0,123,104},Relay={4,0,123,103},Settings={4,0,124,103}}
A.header52={path='Interface\\AddOns\\OlympusChatWarden\\Media\\WorldUI52\\SectionHeader.tga',uv={.001953125,.994140625,.0078125,.720703125},cap=.18}
A.headerFlame={x=57.3,y=-11,width=36,height=40}
function A.Path(key)if key=='BrandHeader'then return 'Interface\\AddOns\\OlympusChatWarden\\Media\\Fireside61\\BrandHeader.tga'end;if key=='TorchEmblem'then return 'Interface\\AddOns\\OlympusChatWarden\\Media\\Warden\\FiresideTorch65.tga'end;if key=='IconOasis'or key=='IconVigil'then return 'Interface\\AddOns\\OlympusChatWarden\\Media\\WorldUI54\\'..key..'.tga'end;if key=='SectionHeader'then return A.header52.path end;return(A.world[key]and A.worldBase or A.base)..key..'.tga'end
local worldIconBounds={Hall={0.03125,0.0,0.96875,1.0},Aether={0.015625,0.0,0.9765625,1.0},Athenaeum={0.0,0.0078125,1.0,0.9921875},Journal={0.0,0.0,1.0,1.0},Chronicle={0.0,0.0078125,1.0,0.984375},Chat={0.0,0.0,1.0,1.0},Shield={0.03125,0.0,0.96875,1.0},Signal={0.0546875,0.0,0.9375,1.0},Settings={0.0,0.0625,1.0,0.9296875},Dossiers={0.015625,0.0,0.9765625,1.0},Relay={0.015625,0.0,0.9765625,1.0},Oasis={0.0078125,0.0078125,1.0,0.984375},Vigil={0.015625,0.0,0.984375,0.984375}}
function A.Icon(texture,key)
 local name=A.icons[key]or key;texture:SetTexture(A.Path('Icon'..name));local uv=worldIconBounds[name];if uv then texture:SetTexCoord(uv[1],uv[3],uv[2],uv[4]);texture.WardenArtAspect=(uv[3]-uv[1])/(uv[4]-uv[2]);return end;local b=iconBounds[name]
 if b then texture:SetTexCoord(b[1]/128,b[3]/128,b[2]/128,b[4]/128);texture.WardenArtAspect=(b[3]-b[1])/(b[4]-b[2])else texture:SetTexCoord(0,1,0,1);texture.WardenArtAspect=1 end
end
function A.Texture(parent,key,layer,sub)
 local t=parent:CreateTexture(nil,layer or 'BACKGROUND',nil,sub or 1);t:SetTexture(A.Path(key));if key=='SectionHeader'then t:SetTexCoord(unpack(A.header52.uv))end;return t
end
-- Three-piece bands preserve the ornament size while their quiet middle grows.
function A.Band(parent,key,layer)
 local g={}
 for n=1,3 do g[n]=A.Texture(parent,key,layer or 'BACKGROUND',1)end
 local function coordinates(value)
  local info=value=='SectionHeader'and A.header52;local u0,u1,v0,v1=0,1,0,1
  if info then u0,u1,v0,v1=unpack(info.uv)end
  local uv=info and info.cap or A.world[value]and .22 or .14;local span=u1-u0
  g[1]:SetTexCoord(u0,u0+span*uv,v0,v1);g[2]:SetTexCoord(u0+span*uv,u1-span*uv,v0,v1);g[3]:SetTexCoord(u1-span*uv,u1,v0,v1)
  if info then for _,t in ipairs(g)do if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false);t:SetTexelSnappingBias(0)end end end
 end
 coordinates(key)
 local function layout()
  local cap=math.min(parent:GetWidth()*.23,math.max(5,parent:GetHeight()*(key=='SectionHeader'and .95 or .65)))
  g[1]:ClearAllPoints();g[1]:SetPoint('TOPLEFT');g[1]:SetPoint('BOTTOMLEFT');g[1]:SetWidth(cap)
  g[3]:ClearAllPoints();g[3]:SetPoint('TOPRIGHT');g[3]:SetPoint('BOTTOMRIGHT');g[3]:SetWidth(cap)
  g[2]:ClearAllPoints();g[2]:SetPoint('TOPLEFT',cap,0);g[2]:SetPoint('BOTTOMRIGHT',-cap,0)
 end
 function g:SetArt(value)if self.key==value then return end;self.key=value;for _,t in ipairs(self)do t:SetTexture(A.Path(value))end;coordinates(value)end
 function g:SetShown(value)for _,t in ipairs(self)do t:SetShown(value)end end
 g.key=key;parent:HookScript('OnSizeChanged',layout);layout();return g
end
-- Complete re-render of the original material without ornamental side pieces.
-- All of the new artwork, including finished end rails, is displayed. Three
-- pieces preserve its corner proportions as the button changes width.
-- Original search/text artwork remains in Band above.
function A.ButtonBand(parent,key,layer)
 local g={rerendered=true,key=key};local path='Interface\\AddOns\\OlympusChatWarden\\Media\\Buttons65\\Button.tga'
 for i,uv in ipairs({{0,.1},{.1,.9},{.9,1}})do
  local t=parent:CreateTexture(nil,layer or'BACKGROUND',nil,1);t:SetTexture(path);t:SetTexCoord(uv[1],uv[2],0,1);g[i]=t
 end
 local function layout()
  local cap=math.min(parent:GetWidth()*.25,parent:GetHeight()*.4)
  g[1]:ClearAllPoints();g[1]:SetPoint('TOPLEFT');g[1]:SetPoint('BOTTOMLEFT');g[1]:SetWidth(cap)
  g[3]:ClearAllPoints();g[3]:SetPoint('TOPRIGHT');g[3]:SetPoint('BOTTOMRIGHT');g[3]:SetWidth(cap)
  g[2]:ClearAllPoints();g[2]:SetPoint('TOPLEFT',cap,0);g[2]:SetPoint('BOTTOMRIGHT',-cap,0)
 end
 function g:SetArt(value)
  self.key=value;local gain=value=='ButtonDisabled'and .45 or value=='ButtonPressed'and .8 or 1
  for _,t in ipairs(self)do t:SetVertexColor(gain,gain,gain,1)end
 end
 function g:SetShown(value)for _,t in ipairs(self)do t:SetShown(value)end end
 parent:HookScript('OnSizeChanged',layout);layout();g:SetArt(key);return g
end
-- Reusable frame edges with fixed-size corners; text surfaces remain quiet.
function A.Frame(parent,paper,fill)
 local g={};local edge=14
 local positions={{'TOPLEFT',0,.21,0,.21},{'TOPRIGHT',.79,1,0,.21},{'BOTTOMLEFT',0,.21,.79,1},{'BOTTOMRIGHT',.79,1,.79,1}}
 for _,p in ipairs(positions)do local t=A.Texture(parent,'PanelFrame','BORDER',1);t:SetTexCoord(p[2],p[3],p[4],p[5]);t:SetSize(edge,edge);t:SetPoint(p[1]);g[#g+1]=t end
 for _,p in ipairs({{'TOP',.21,.79,0,.055},{'BOTTOM',.21,.79,.945,1},{'LEFT',0,.055,.21,.79},{'RIGHT',.945,1,.21,.79}})do
  local t=A.Texture(parent,'PanelFrame','BORDER',1);t:SetTexCoord(p[2],p[3],p[4],p[5])
  if p[1]=='TOP'or p[1]=='BOTTOM'then t:SetPoint(p[1]..'LEFT',edge,0);t:SetPoint(p[1]..'RIGHT',-edge,0);t:SetHeight(2)
  else t:SetPoint('TOP'..p[1],0,-edge);t:SetPoint('BOTTOM'..p[1],0,edge);t:SetWidth(2)end;g[#g+1]=t
 end
 if fill then local t=A.Texture(parent,paper and 'Parchment'or 'TempleBackdrop');t:SetPoint('TOPLEFT',3,-3);t:SetPoint('BOTTOMRIGHT',-3,3);if not paper then t:SetTexCoord(.30,.70,.20,.80)end;g[#g+1]=t end
 function g:SetShown(value)for _,t in ipairs(self)do t:SetShown(value)end end
 return g
end
A.controls={button='ButtonNormal',neutral='ButtonNormal',danger='ButtonNormal',hover='ButtonHover',neutralHover='ButtonHover',dangerHover='ButtonHover',pressed='ButtonPressed',neutralPressed='ButtonPressed',dangerPressed='ButtonPressed',disabled='ButtonDisabled',tab='ButtonSelected',tabOff='ButtonNormal',tabHover='ButtonHover',tabPressed='ButtonPressed',tabDisabled='ButtonDisabled',selected='ButtonSelected',header='SectionHeader',search='ButtonNormal',searchFocus='ButtonHover'}
