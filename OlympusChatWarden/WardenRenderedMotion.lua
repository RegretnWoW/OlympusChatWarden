-- Approved fixed-model renders. One shared scene clock; persistent atlas bindings.
local _,ns=...;local G=ns.WardenSceneGraph
local function finite(v)return type(v)=='number'and v==v and v~=math.huge and v~=-math.huge end
function G.RenderedFrame(asset,time)
 if not finite(time)then time=0 end
 return math.floor((math.max(0,time)%asset.duration)/asset.duration*asset.frames)+1
end
function G.RenderedSurface(parent,asset,phase,shape)
 assert(asset.renderedMotion and asset.frames>0 and asset.duration>0 and #asset.uv==asset.frames and #asset.sheets<=32,'Invalid rendered motion')
 local f=G.Frame(parent,1);f:SetAllPoints();f:EnableMouse(false)
 local r={frame=f,asset=asset,phase=phase or 0,kind='rendered-3d',cells={},sheets={},updates=0,textureBinds=0}
 for i,path in ipairs(asset.sheets)do
  local t=f:CreateTexture(nil,'ARTWORK');t:SetAllPoints();t:SetTexture(path,'CLAMP','CLAMP','LINEAR');t:SetAlpha(0)
  r.sheets[i]=t;r.cells[i]={texture=t};r.textureBinds=r.textureBinds+1
 end
 r.texture=r.sheets[1]
 function r:Draw(width,height,time,depth,animated)
  local active=animated and(not ns.WardenWind or ns.WardenWind.mode~='off')
  local index=G.RenderedFrame(asset,active and(time+self.phase)or 0);local uv=asset.uv[index];local target=self.sheets[uv[1]]
  -- Keep the previous valid pose while a sheet is loading. Bind each sheet once
  -- for the surface lifetime, so cache eviction cannot blank a reused region.
  local ready=not target.IsObjectLoaded or target:IsObjectLoaded()
  if ready and index~=self.index then
   target:SetTexCoord(uv[2],uv[3],uv[4],uv[5])
   if target~=self.texture then self.texture:SetAlpha(0)end
   target:SetAlpha(1);self.texture=target;self.sheet=uv[1];self.index=index;self.updates=self.updates+1
  end
  -- Architectural banners reuse the proven cloth atlas with a taller panel.
  -- The ordinary Fields/Home surface keeps its original proportions.
  local aspect=shape and shape.aspect or asset.aspect
  local w=math.min(math.max(0,width),math.max(0,height)*aspect);local h=w/aspect
  if not self.width or math.abs(w-self.width)>.05 or math.abs(h-self.height)>.05 then
   for _,t in ipairs(self.sheets)do G.Place(t,f,0,0,w,h)end;self.width,self.height=w,h
  end
  if self.tint then for _,t in ipairs(self.sheets)do t:SetVertexColor(unpack(self.tint))end end
 end
 return r
end
