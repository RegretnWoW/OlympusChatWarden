-- A small projected flame volume. Fixed materials, continuously changing
-- shared geometry; no flipbook, particle queue, per-flame timer or saved state.
local _,ns=...;local G=ns.WardenSceneGraph
local F={VERSION=1,ROWS=16,ASPECT=.64};ns.WardenFlame=F
local material='Interface\\AddOns\\OlympusChatWarden\\Media\\LivingFlame\\Volume.tga'
local halo='Interface\\AddOns\\OlympusChatWarden\\Media\\LivingFlame\\Halo.tga'
local function finite(n)return type(n)=='number'and n==n and n~=math.huge and n~=-math.huge end
local function hash(n,seed)local x=math.sin(n*127.1+seed*311.7)*43758.5453123;return(x-math.floor(x))*2-1 end
local function noise(t,seed)
 local i=math.floor(t);local q=t-i;q=q*q*q*(q*(q*6-15)+10)
 local a,b=hash(i,seed),hash(i+1,seed);return a+(b-a)*q
end
F.Noise=noise
local lobes={
 {width=.46,height=.98,offset=-.022,seed=3,color={1,.48,.20},alpha=.70},
 {width=.32,height=.87,offset=.018,seed=11,color={1,.91,.65},alpha=.88},
 {width=.15,height=.61,offset=-.012,seed=29,color={1,1,1},alpha=.96}}
function F.Surface(parent,kind,phase)
 local f=G.Frame(parent,1);f:SetAllPoints();f:EnableMouse(false)
 local brand=kind=='brand';local rows=brand and 24 or F.ROWS
 local shapes=brand and{
  {width=.47,height=.86,offset=-.05,seed=3,color={1,.22,.025},alpha=.72},
  {width=.28,height=1.06,offset=-.16,seed=41,color={1,.49,.055},alpha=.83},
  {width=.25,height=.94,offset=.17,seed=67,color={1,.64,.11},alpha=.88},
  {width=.30,height=.91,offset=.015,seed=11,color={1,.86,.35},alpha=.93},
  {width=.13,height=.65,offset=-.01,seed=29,color={1,1,.88},alpha=.98}}or lobes
 local r={frame=f,kind=brand and'brand-fire-volume'or'living-volume',flameKind=kind,phase=phase or 0,cells={},nodes={},rows=rows,material=material,updates=0,textureWrites=0,embers={}}
 local candle=kind=='candle';r.calm=candle and .36 or 1
 local glow=f:CreateTexture(nil,'BACKGROUND');glow:SetTexture(halo,'CLAMP','CLAMP','LINEAR');glow:SetBlendMode('ADD');glow:SetVertexColor(1,.37,.08);r.glow=glow
 for layer,spec in ipairs(shapes)do
  for row=0,rows-1 do
   local t=f:CreateTexture(nil,'ARTWORK',nil,layer-1);t:SetTexture(material,'CLAMP','CLAMP','LINEAR')
   t:SetTexCoord(0,1,1-(row+1)/rows,1-row/rows);t:SetVertexColor(unpack(spec.color));t:SetAlpha(spec.alpha)
   if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false);t:SetTexelSnappingBias(0)end
   r.cells[#r.cells+1]={texture=t,layer=layer,row=row,quad={0,0,0,0,0,0,0,0}}
  end
 end
 if brand then for i=1,8 do local t=f:CreateTexture(nil,'OVERLAY');t:SetTexture(halo,'CLAMP','CLAMP','LINEAR');t:SetBlendMode('ADD');t:SetVertexColor(1,.61,.14);r.embers[i]=t end end
 r.textureWrites=#r.cells+1+#r.embers
 -- A client lacking quad articulation gets a truthful static flame, never a
 -- changing sequence of replacement pictures or unsupported geometry calls.
 if not r.cells[1].texture.SetVertexOffset then
  for _,c in ipairs(r.cells)do c.texture:Hide()end
  r.unsupportedGeometry=true;r.fallback=G.Texture(f,ns.WardenSceneAssets.assets['air-flame2']);r.fallback:SetAllPoints()
 end
 function r:Draw(width,height,time,depth,animated)
  if not finite(width)or not finite(height)or width<=0 or height<=0 then return end
  local active=animated==true and(not ns.WardenWind or ns.WardenWind.mode~='off')
  local t=active and finite(time)and math.max(0,time)or 0
  if self.lastTime==t and self.width==width and self.height==height then return end
  self.lastTime,self.width,self.height=t,width,height;self.updates=self.updates+1
  if self.unsupportedGeometry then G.Place(self.fallback,f,0,0,width,height);return end
  local calm=self.calm;local seed=self.phase*13;local energy=noise(t*.83+seed,7)*.65+noise(t*1.71+seed,19)*.35
  local stretch=1+energy*(brand and .12 or .054)*calm
  local output=self.nodes
  for layer,spec in ipairs(shapes)do
   local nodes=output[layer]or{};output[layer]=nodes
   for row=0,rows do
    local q=row/rows;local rise=q*q
    -- Advected, quintic noise gives continuous position AND velocity through
    -- random control points. The tip lags the root; it does not swing as a card.
    local a=noise(t*1.37-q*.85+seed,spec.seed)
    local b=noise(t*2.43-q*1.2+seed,spec.seed+43)
    local bend=rise*(a*(brand and .12 or .067)+b*.027)*calm+spec.offset*math.sin(q*math.pi)
    local center=width*(.5+bend)
    local profile=.055*(1-q)+math.sin(q*math.pi)^.82*(1-q)^.34
    local breathing=1+rise*.075*calm*noise(t*1.91-q*.58+seed,spec.seed+71)
    local radius=width*spec.width*profile*breathing
    if row==rows then radius=.0001 end
    local y=height*(1-q*spec.height*stretch)
    local n=nodes[row+1]or{};nodes[row+1]=n;n[1],n[2],n[3],n[4]=center-radius,y,center+radius,y
   end
  end
  for _,c in ipairs(self.cells)do
   local a,b=output[c.layer][c.row+1],output[c.layer][c.row+2]
   -- The lower and upper edges are shared, including at the spine of each
   -- luminous lobe. UVs stay constant for the lifetime of the object.
   local q=c.quad;q[1],q[2],q[3],q[4],q[5],q[6],q[7],q[8]=b[1],b[2],b[3],b[4],a[1],a[2],a[3],a[4]
   ns.WardenComposition.Quad(c.texture,f,q)
  end
  G.Place(glow,f,-width*.9,height*.16,width*2.8,height*1.35)
  glow:SetAlpha((brand and .26 or candle and .065 or .10)*(1+energy*.13*calm))
  for i,ember in ipairs(self.embers)do
   if active then
    local duration=1.8+i*.217;local clock=t+self.phase+i*.673;local cycle=math.floor(clock/duration);local q=(clock%duration)/duration
    local spread=hash(cycle,i);local x=width*(.5+spread*(.08+q*.50));local y=height*(.92-q*1.45)
    local size=1.1+(hash(cycle,i+91)+1)*.6;G.Place(ember,f,x-size/2,y-size/2,size,size)
    ember:SetAlpha(math.sin(q*math.pi)^1.4*.75);ember:Show()
   else ember:Hide()end
  end
  self.energy=energy;self.animated=active
 end
 return r
end
