-- Local presentation only. Fixed source canvases, explicit occlusion layers,
-- and articulated parts; no evidence, networking, rewards or persisted state.
local _,ns=...
local G={VERSION=1,MAX_ACTORS=8};ns.WardenSceneGraph=G
-- One material, shared vertices, reference-calibrated skeletal weights. Adjacent
-- regions cannot expose rectangular seams or leave a fixed ear underneath.
function G.SkinRig(parent,spec,assets)
 local skin=spec.skin;local f=CreateFrame('Frame',nil,parent);f:SetFrameLevel(parent:GetFrameLevel()+1);f:EnableMouse(false)
 local r={frame=f,spec=spec,parts={},state='rest',stateAt=0,cells={},skin=skin,nodes={}}
 local base,eyes=assets[skin.asset],assets[skin.eyes];local eyeCells={};for _,id in ipairs(skin.eyeCells)do eyeCells[id]=true end
 local cols,rows=skin.columns,skin.rows
 local function texture(a,x,y,layer)
  local t=G.Texture(f,a,'ARTWORK',layer);local uv=a.uv;t:SetTexCoord(uv[1]+(uv[2]-uv[1])*x/cols,uv[1]+(uv[2]-uv[1])*(x+1)/cols,uv[3]+(uv[4]-uv[3])*y/rows,uv[3]+(uv[4]-uv[3])*(y+1)/rows);return t
 end
 for y=0,rows-1 do for x=0,cols-1 do local id=y*cols+x+1;r.cells[id]={texture=texture(base,x,y,-1),eyes=eyeCells[id]and texture(eyes,x,y,0),x=x,y=y,quad={}}end end
 for _,id in ipairs({'body','head','ear','earFar','paw','pawFar','tail','lids'})do r.parts[id]={source=base,texture=r.cells[1].texture}end
 function r:SetState(state,at)if self.state==state then return false end;self.previous=self.state;self.state=state;self.stateAt=at;return true end
 function r:Place(host,x,y,w,h)
  if self.frame:GetParent()~=host then self.frame:SetParent(host)end;self.frame:SetFrameLevel(host:GetFrameLevel())
  local target=w/spec.aspect;y=y+(h-target)/2;G.Place(f,host,x,y,w,target);self.width,self.height=w,target
 end
 function r:Draw(pose)
  if not self.cells[1].texture.SetVertexOffset then pose={lids=pose.lids};self.unsupportedSkinning=true end
  local w,h=f:GetWidth(),f:GetHeight();local output=self.nodes
  local function bone(x,y,id,weight,gain)
   local joint=pose[id];if not joint or weight<=0 then return x,y end
   local pivot=skin.pivots[id];local px,py=pivot[1]*w,pivot[2]*h
   local angle=(joint.angle or 0)*(gain or 1);local c,s=math.cos(angle),math.sin(angle);local dx,dy=x-px,y-py
   local nx=px+dx*c-dy*s+(joint.x or 0)*w*(gain or 1);local ny=py+dx*s+dy*c+(joint.y or 0)*h*(gain or 1)
   return x+(nx-x)*weight,y+(ny-y)*weight
  end
  for i,node in ipairs(skin.nodes)do local x,y=node[1]*w,node[2]*h;local weights=node[3]
   x,y=bone(x,y,'ear',weights.ear,1);x,y=bone(x,y,'earFar',weights.earFar,1)
   x,y=bone(x,y,'paw',weights.paw,.12);x,y=bone(x,y,'tail',weights.tail,.8)
   x,y=bone(x,y,'head',weights.head,.65);x,y=bone(x,y,'body',weights.body,1)
   if self.heading==-1 then x=w-x end;local n=output[i]or{};output[i]=n;n[1],n[2]=x,y
  end
  local lids=pose.lids or{};local openness=1-(lids.hidden and 0 or lids.alpha or 0)
  for _,cell in ipairs(self.cells)do local i=cell.y*(cols+1)+cell.x+1;local a,b,c,d=output[i],output[i+1],output[i+cols+1],output[i+cols+2];local quad=cell.quad
   quad[1],quad[2],quad[3],quad[4],quad[5],quad[6],quad[7],quad[8]=a[1],a[2],b[1],b[2],c[1],c[2],d[1],d[2]
   ns.WardenComposition.Quad(cell.texture,f,quad);cell.texture:Show()
   if cell.eyes then ns.WardenComposition.Quad(cell.eyes,f,quad);cell.eyes:SetAlpha(openness);cell.eyes:SetShown(openness>0)end
  end
  self.nodes=output;self.pose=pose
 end
 function r:Show(value)f:SetShown(value)end
 function r:SetLighting(state,interior)
  local red,green,blue=ns.WardenSceneLighting.ActorTint(state,interior)
  for _,cell in ipairs(self.cells)do cell.texture:SetVertexColor(red,green,blue);if cell.eyes then cell.eyes:SetVertexColor(red,green,blue)end end
 end
 return r
end
local function frame(parent,level)
 local f=CreateFrame('Frame',nil,parent);f:SetFrameLevel(parent:GetFrameLevel()+(level or 1));f:EnableMouse(false);return f
end
G.Frame=frame
-- Native focus locks descendants independently. Move a complete visual tree
-- together so its paper/ink or flame cannot remain below another viewport.
function G.StackTree(root,level)
 if not root or root:GetFrameLevel()==level then return end
 local delta=level-root:GetFrameLevel();local rows={}
 local function collect(f)rows[#rows+1]={f,f:GetFrameLevel()+delta};for _,child in ipairs({f:GetChildren()})do collect(child)end end
 collect(root)
 for _,row in ipairs(rows)do if row[1].SetFixedFrameLevel then row[1]:SetFixedFrameLevel(false)end end
 for _,row in ipairs(rows)do row[1]:SetFrameLevel(row[2])end
 for _,row in ipairs(rows)do if row[1].SetFixedFrameLevel then row[1]:SetFixedFrameLevel(true)end end
end
function G.Place(object,parent,x,y,w,h)
 object:ClearAllPoints();object:SetPoint('TOPLEFT',parent,'TOPLEFT',x,-y);object:SetSize(math.max(.01,w),math.max(.01,h))
end
function G.Ease(t)t=math.max(0,math.min(1,t));return t*t*(3-2*t)end
function G.Lerp(a,b,t)return a+(b-a)*t end
function G.Texture(parent,asset,layer,sub)
 local t=parent:CreateTexture(nil,layer or'ARTWORK',nil,sub or 0)
 t:SetTexture(asset.path,'CLAMP','CLAMP','LINEAR');t:SetTexCoord(unpack(asset.uv or{0,1,0,1}))
 if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false);t:SetTexelSnappingBias(0)end
 return t
end
function G.Scene(parent,spec,assets)
 local f=frame(parent,0);f:SetAllPoints();if f.SetClipsChildren then f:SetClipsChildren(true)end
 local s={frame=f,spec=spec,layers={},objects={},assets=assets,width=spec.width,height=spec.height}
 for i,d in ipairs(spec.layers)do
  local host=frame(f,i);host:SetAllPoints();s.layers[d.id]=host;host.sceneLayerID=d.id;host.logicalDepth=i
 end
 function s:Add(id,assetID,layer,box,kind)
  local a=assert(self.assets[assetID],'Missing scene asset '..assetID);local host=assert(self.layers[layer],layer)
  local object={id=id,assetID=assetID,layer=layer,box=box,kind=kind,host=host,regions={}}
  if a.tiles then
   for _,tile in ipairs(a.tiles)do object.regions[#object.regions+1]={texture=G.Texture(host,tile),box={tile.x/a.width,tile.y/a.height,tile.w/a.width,tile.h/a.height}}end
  else object.regions[1]={texture=G.Texture(host,a),box={0,0,1,1}}end
  self.objects[id]=object;return object
 end
 function s:Layout(width,height)
  self.drawWidth,self.drawHeight=width,height;self.frame:SetSize(width,height)
  for _,o in pairs(self.objects)do local b=o.box
   for _,r in ipairs(o.regions)do local q=r.box;G.Place(r.texture,o.host,(b[1]+q[1]*b[3])*width,(b[2]+q[2]*b[4])*height,q[3]*b[3]*width,q[4]*b[4]*height)end
  end
 end
 function s:Shown(id,value)local o=self.objects[id];if o then for _,r in ipairs(o.regions)do r.texture:SetShown(value)end end end
 function s:SetLighting(state)
  self.lighting=state
  for _,o in pairs(self.objects)do
   local a=self.assets[o.assetID..'@'..state]or self.assets[o.assetID]
   local tiles=a.tiles or{a}
   for i,r in ipairs(o.regions)do local q=tiles[i];if q then r.texture:SetTexture(q.path,'CLAMP','CLAMP','LINEAR');r.texture:SetTexCoord(unpack(q.uv or{0,1,0,1}))end end
  end
 end
 return s
end
local function transform(x,y,px,py,angle)
 local c,s=math.cos(angle),math.sin(angle);local dx,dy=x-px,y-py
 return px+dx*c-dy*s,py+dx*s+dy*c
end
function G.Rig(parent,spec,assets)
 if spec.skin then return G.SkinRig(parent,spec,assets)end
 local f=frame(parent,1);f:ClearAllPoints();local r={frame=f,spec=spec,parts={},joints={},state='rest',stateAt=0,elapsed=0}
 for i,p in ipairs(spec.parts)do
  local a=assert(assets[p.asset],p.asset);local t=G.Texture(f,a,'ARTWORK',math.max(-8,math.min(7,p.depth or i-8)))
  r.parts[p.id]={texture=t,box=p.box,pivot=p.pivot or{.5,.5},parent=p.parent,fold=p.fold,baseAngle=p.angle or 0,source=a}
 end
 function r:SetState(state,at)
  if self.state==state then return false end
  self.previous=self.state;self.state=state;self.stateAt=at;return true
 end
 function r:Place(host,x,y,w,h)
  if self.frame:GetParent()~=host then self.frame:SetParent(host)end;self.frame:SetFrameLevel(host:GetFrameLevel())
  G.Place(self.frame,host,x,y,w,h);self.width,self.height=w,h
 end
 function r:Draw(pose)
  local w,h=self.frame:GetWidth(),self.frame:GetHeight();local body=pose.root or{};local rootAngle=(body.angle or 0)+(self.pitch or 0)
  local function rotate(x,y,px,py,angle)local a,b=transform(x*w,y*h,px*w,py*h,angle);return a/w,b/h end
  local function point(part,u,v,seen)
   local b=part.box;local p=part.pivot;local joint=pose[part.id]or{}
   local x,y=b[1]+u*b[3],b[2]+v*b[4];local px,py=b[1]+p[1]*b[3],b[2]+p[2]*b[4]
   -- A wing/cloth surface hinges in depth without stretching its material.
   -- Only its projection changes; the actor canvas and torso stay invariant.
   if part.fold then
    local fold=joint.fold or 0;local distance=x-px;x=px+distance*math.cos(fold);y=y+distance*math.sin(fold)*.10
   end
   x,y=rotate(x,y,px,py,(part.baseAngle or 0)+(joint.angle or 0));x=x+(joint.x or 0);y=y+(joint.y or 0)
   local ancestor=part.parent;seen=seen or 0
   while ancestor and seen<8 do
    local a=r.parts[ancestor];if not a then break end;local ab,ap=a.box,a.pivot;local j=pose[ancestor]or{}
    x,y=rotate(x,y,ab[1]+ap[1]*ab[3],ab[2]+ap[2]*ab[4],(a.baseAngle or 0)+(j.angle or 0));x=x+(j.x or 0);y=y+(j.y or 0);ancestor=a.parent;seen=seen+1
   end
   x,y=rotate(x,y,.5,.65,rootAngle);if self.heading==-1 then x=1-x end;return(x+(body.x or 0))*w,(y+(body.y or 0))*h
  end
  for id,p in pairs(self.parts)do local j=pose[id]or{};local t=p.texture
   if j.hidden then t:Hide()else
    local x1,y1=point(p,0,0);local x2,y2=point(p,1,0);local x3,y3=point(p,0,1);local x4,y4=point(p,1,1)
    ns.WardenComposition.Quad(t,self.frame,{x1,y1,x2,y2,x3,y3,x4,y4});t:SetAlpha(j.alpha or 1);t:Show()
   end
  end
  self.pose=pose
 end
 function r:Show(value)self.frame:SetShown(value)end
 function r:SetLighting(state,interior)
  local red,green,blue=ns.WardenSceneLighting.ActorTint(state,interior)
  for _,p in pairs(self.parts)do p.texture:SetVertexColor(red,green,blue)end
 end
 return r
end
-- Per-actor state functions produce part transforms, never replace its torso.
function G.Pose(kind,state,elapsed,phase,cycleTime,motionWeight)
 local rad=math.pi/180;local t=math.max(0,elapsed or 0);phase=phase or 0;local p={root={}}
 if kind=='cat'then
  local loop=cycleTime or t;local blink=(loop+phase)%11.7;local closed=state=='sleep'or state=='rest'and blink>10.9 or blink>11.38
  p.eyes={hidden=closed};p.lids={hidden=not closed};p.chest={y=math.sin(loop*1.2)*.002}
  p.ear={angle=state=='alert'and-7*rad*math.sin(math.pi*math.min(1,t/5))or math.max(0,math.sin((loop+phase)*.31))^20*3*rad}
  p.tail={angle=math.sin(loop*.38)*1.3*rad}
  if state=='react'or state=='alert'then local q=math.sin(math.pi*math.min(1,t/5));p.head={angle=-9*rad*q,y=-.008*q}
  elseif state=='stretch'then local q=math.sin(math.pi*math.min(1,t/6))^2;p.head={angle=-12*rad*q,x=.01*q,y=-.015*q};p.paw={x=.055*q,angle=-4*rad*q};p.tail={angle=5*rad*q}
  elseif state=='groom'then local q=math.sin(math.pi*math.min(1,t/7));p.head={angle=(7+math.sin(t*3)*2)*rad*q,y=.008*q};p.paw={y=-.025*q,angle=-12*rad*q}end
 elseif kind=='owl'or kind=='bird'or kind=='moth'then
  local flight=state=='traverse'or state=='flight'or state=='takeoff'or state=='landing'
  local open=flight and 1 or 0
  if state=='takeoff'then open=G.Ease(t/1.2)elseif state=='landing'then open=1-G.Ease(t/1.5)end
  if kind=='owl'then
   local wave=math.sin((cycleTime or t)*1.35*math.pi*2);wave=wave*math.abs(wave)
   p.wingFar={angle=(-22-32*wave)*rad*open,fold=(1-open)*1.36};p.wingNear={angle=(-18-37*wave)*rad*open,fold=(1-open)*1.36}
  elseif kind=='bird'then
   local cycle=(t*2.8)%1;local stroke=cycle<.34 and G.Ease(cycle/.34)or 1-G.Ease((cycle-.34)/.66)
   p.wingFar={angle=(-48+78*stroke)*rad*open,fold=(1-open)*1.36};p.wingNear={angle=(-54+90*stroke)*rad*open,fold=(1-open)*1.36}
  else
   local flutter=.5+.5*math.sin(t*4.1*math.pi*2)
   p.wingFar={angle=math.sin(t*2)*4*rad,fold=flight and .20+flutter*1.12 or 1.36};p.wingNear={angle=math.sin(t*2+.4)*5*rad,fold=flight and .16+flutter*1.10 or 1.36};p.root.y=math.sin(t*3)*.002
  end
  p.root.angle=kind=='owl'and 52*rad*open or math.sin(t*1.3)*rad
  p.feet={y=-.035*open};p.head={angle=kind=='owl'and-52*rad*open or math.sin(t*.23)*2*rad}
  if kind=='owl'and state=='alert'then p.head.angle=math.sin(math.pi*math.min(1,t/4))*10*rad end
  if kind=='owl'and state=='ruffle'then local q=math.sin(math.pi*math.min(1,t/3))^2;p.wingNear.fold=1.36-.12*q;p.wingFar.fold=1.36-.10*q end
  p.eyes={hidden=(t+phase)%13.2>12.9};p.lids={hidden=not p.eyes.hidden}
 else
  local walking=state=='traverse'or state=='move'or state=='takeoff';local frequency=kind=='fox'and 2.6 or kind=='rabbit'and 1.7 or 1.1
  local wave=walking and math.sin(t*math.pi*2*frequency)*(motionWeight or math.min(1,t/.5))or 0;local angle=(kind=='rabbit'and 18 or 12)*rad
  p.legFar={angle=-wave*angle};p.legNear={angle=wave*angle};p.legFar2={angle=wave*angle};p.legNear2={angle=-wave*angle};p.tail={angle=math.sin(t*.7)*2*rad};p.head={angle=walking and 0 or math.sin(t*.29)*1.5*rad}
  if kind=='rabbit'and walking then p.root.y=-math.max(0,wave)^2*.035 end
  if kind=='wizard'then
   local q=state=='cast'and math.sin(math.pi*math.min(1,t/5))^2 or 0;p.arm={angle=35*rad*(1-q)};p.staff={angle=-10*rad*q};p.head={angle=3*rad*q};p.magic={hidden=q<.1,alpha=q*.65}
  end
 end
 return p
end
