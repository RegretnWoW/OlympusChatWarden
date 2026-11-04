-- One ephemeral wind field shared by cloth and planted foliage; no saved state.
local _,ns=...;local G=ns.WardenSceneGraph
local W={VERSION=1,mode=nil,markers=false};ns.WardenWind=W
function W.Strength(t)
 if W.mode=='off'then return 0 end
 local base=W.mode=='breeze'and .28 or W.mode=='moderate'and .58 or W.mode=='gust'and .85 or .24
 local gust=math.max(0,math.sin(t*.17-.8))^6*.48
 return math.min(1.2,base+gust+.055*math.sin(t*.51))
end
function W.Preview(mode,isolate,markers)
 if not(ns.WardenSimLab and ns.WardenSimLab.Enabled())then return false end
 if mode~=nil and not({off=true,breeze=true,moderate=true,gust=true})[mode]then return false end
 W.mode,W.isolate,W.markers=mode,isolate,markers==true
 local v=ns.UI2 and ns.UI2.realm;if v then v:Pose(v.frame:IsVisible()and ns.DB.journalReducedMotion~=true)end;return true
end
function W.Surface(parent,asset,kind,phase)
 local f=G.Frame(parent,1);f:SetAllPoints();f:EnableMouse(false)
 local s={frame=f,asset=asset,kind=kind,phase=phase or 0,cells={},nodes={},columns=kind=='guild'and 8 or 4,rows=4}
 local uv=asset.uv or{0,1,0,1};local cols,rows=s.columns,s.rows
 for y=0,rows-1 do for x=0,cols-1 do
  local t=G.Texture(f,asset);t:SetTexCoord(uv[1]+(uv[2]-uv[1])*x/cols,uv[1]+(uv[2]-uv[1])*(x+1)/cols,uv[3]+(uv[4]-uv[3])*y/rows,uv[3]+(uv[4]-uv[3])*(y+1)/rows)
  s.cells[#s.cells+1]={texture=t,x=x,y=y}
 end end
 function s:Draw(width,height,t,depth,animated)
  local strength=animated and W.Strength(t)or 0;depth=depth or 1
  self.time=t;self.strength=strength;self.animated=animated==true;local nodes={}
  for y=0,rows do nodes[y]={};for x=0,cols do
   local u,v=x/cols,y/rows;local dx,dy=0,0;local wave=math.sin(t*1.65-u*5.4-v*.8+self.phase)
   if kind=='guild'then
    -- Hoist nodes remain exact. A wave and lag grow towards the free edge.
    dx=-width*.018*strength*u*u*(.5+.5*wave)
    dy=height*strength*u*u*(.065*wave+.025*math.sin(t*.7-u*2+self.phase))
   elseif kind=='flame'then
    local tip=(1-v)^2
    dx=width*tip*(.10*math.sin(t*2.2+v*3+self.phase)+.045*math.sin(t*4.1-v*4))*(animated and 1 or 0)
    dy=height*tip*.018*math.sin(t*3.3+u*4)*(animated and 1 or 0)
   elseif kind=='alliance'then
    dx=width*.055*strength*v*v*wave;dy=height*.009*strength*v*v*math.sin(t*1.2-u*3+self.phase)
   else
    -- Authored foliage weights: the roots, trunks and large lower branches
    -- stay still. Canopy tips or grass blades flex above their support.
    local upper=kind=='tree'and math.max(0,(.59-v)/.59)^2 or(1-v)^2
    dx=width*.018*strength*upper*depth*(.55+.45*wave)
    dy=height*.004*strength*upper*depth*math.sin(t*1.25+u*3+self.phase)
   end
   nodes[y][x]={u*width+dx,v*height+dy}
  end end
  self.nodes=nodes
  for _,c in ipairs(self.cells)do local a,b,c1,d=nodes[c.y][c.x],nodes[c.y][c.x+1],nodes[c.y+1][c.x],nodes[c.y+1][c.x+1];ns.WardenComposition.Quad(c.texture,f,{a[1],a[2],b[1],b[2],c1[1],c1[2],d[1],d[2]})end
  local tint=self.tint or{1,1,1};for _,c in ipairs(self.cells)do c.texture:SetVertexColor(unpack(tint))end
  f:SetShown(not W.isolate or W.isolate=='all'or W.isolate=='flags'and(kind=='guild'or kind=='alliance')or W.isolate=='foliage'and kind~='guild'and kind~='alliance')
  if W.markers then
   if not self.pivot then self.pivot=f:CreateTexture(nil,'OVERLAY');self.pivot:SetColorTexture(1,.2,.05,1);self.pivot:SetSize(5,5)end
   self.pivot:ClearAllPoints();self.pivot:SetPoint(kind=='guild'and'TOPLEFT'or kind=='alliance'and'TOP'or'BOTTOM',f,kind=='guild'and'TOPLEFT'or kind=='alliance'and'TOP'or'BOTTOM');self.pivot:Show()
  elseif self.pivot then self.pivot:Hide()end
 end
 return s
end
