-- Compound geometry for the experimental world only. Existing native shapes,
-- path validation and projection remain the authority; boxes never merge for walking.
local _,ns=...
local F,N,C=ns.Fireside3D,ns.WardenNativeScene,ns.WardenSceneObjectControls
local H={MAX_BOXES=8};F.Hitboxes=H
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
H.Copy=copy
function H.World(a)return a and a.engine and a.engine.world3D end
function H.Compound(r)return type(r)=='table'and r.boxes~=nil end
function H.Validate(kind,r)
 if kind~='collider'and kind~='hitbox'then return nil,'Unknown box control'end
 if not H.Compound(r)then return C.Validate(kind,r)end
 if getmetatable(r)or type(r.boxes)~='table'or getmetatable(r.boxes)then return nil,'Use a plain box list'end
 for k in pairs(r)do if k~='enabled'and k~='boxes'then return nil,'Unknown box-list field'end end
 if r.enabled~=nil and type(r.enabled)~='boolean'then return nil,'Invalid box-list enabled flag'end
 local n=0;for k in pairs(r.boxes)do if type(k)~='number'or k%1~=0 or k<1 or k>H.MAX_BOXES then return nil,'Limit: eight boxes per object and control'end;n=n+1 end
 local out={enabled=r.enabled~=false,boxes={}}
 for i=1,n do
  local b=r.boxes[i];if type(b)~='table'or H.Compound(b)then return nil,'Use a dense list of simple boxes'end
  local v,why=C.Validate(kind,b);if not v then return nil,why end;out.boxes[i]=v
 end
 return out
end
function H.Ratio(a)return a.scale/(a.editorBaseScale or a.authoredBaseScale or a.scale)end
function H.Default(a,kind)
 local basis=a.editorBaseScale or a.authoredBaseScale or a.scale;local b=a.bounds
 local r={enabled=kind~='collider'or a.spec.collision~=false,width=math.max(.05,math.min(20,(b[4]-b[1])*basis)),depth=math.max(.05,math.min(20,(b[5]-b[2])*basis)),x=0,y=0}
 if kind=='collider'and(a.spec.collisionRadius or 0)>0 then r.width=math.min(20,a.spec.collisionRadius*2);r.depth=r.width end
 if kind=='hitbox'then r.z=0;r.height=math.max(.05,math.min(15,(b[6]-b[3])*basis))end
 return r
end
function H.Boxes(a,kind,record)
 local r=record or a[kind]
 if H.Compound(r)then
  local boxes={};for i,part in ipairs(r.boxes)do local b=H.Default(a,kind);b.enabled=true;for k,v in pairs(part)do b[k]=v end;if r.enabled==false then b.enabled=false end;boxes[i]=b end
  return boxes,r.enabled~=false
 end
 local b=H.Default(a,kind);for k,v in pairs(r or{})do b[k]=v end
 return{b},true
end
function H.Shape(shot,a,r)
 local box=C.LocalBox(shot,a,r);if not box then return end
 local ratio=H.Ratio(a);box.bottom=a.position[3]+(r.z or 0)*ratio
 box.top=box.bottom+(r.height or H.Default(a,'hitbox').height)*ratio
 return box
end
local footprint=N.Footprint
function H.Footprints(shot,a)
 local r=a.collider
 if not H.World(a)or not H.Compound(r)then local b=footprint(shot,a);return b and{b}or{}end
 local out={};if not a.ready or not a.position or not a.bounds or r.enabled==false then return out end
 for i,v in ipairs(r.boxes)do if v.enabled~=false then local b=C.LocalBox(shot,a,v);b.id=a.id..'/box-'..i;out[#out+1]=b end end
 return out
end
-- Envelope is for approach/presentation callers only. Navigation consumes each
-- part above, so the gaps between tent walls stay open.
N.Footprint=function(shot,a)
 if not H.World(a)or not H.Compound(a.collider)then return footprint(shot,a)end
 local out
 for _,b in ipairs(H.Footprints(shot,a))do
  if not out then out={id=a.id,left=b.left,right=b.right,near=b.near,far=b.far}
  else out.left=math.min(out.left,b.left);out.right=math.max(out.right,b.right);out.near=math.min(out.near,b.near);out.far=math.max(out.far,b.far)end
 end;return out
end
local pick,contains,pickBox,projectCollider=C.ProjectPick,C.ContainsPick,C.PickBox,C.ProjectCollider
C.PickBox=function(shot,a)if H.World(a)and H.Compound(a.hitbox)then return end;return pickBox(shot,a)end
C.ProjectCollider=function(engine,shot,a)if H.World(a)and H.Compound(a.collider)then return end;return projectCollider(engine,shot,a)end
C.ProjectPick=function(engine,shot,a)
 if not H.World(a)or not H.Compound(a.hitbox)then return pick(engine,shot,a)end
 if a.hitbox.enabled==false then return end
 local out={parts={},left=math.huge,right=-math.huge,top=math.huge,bottom=-math.huge}
 for _,r in ipairs(a.hitbox.boxes)do if r.enabled~=false then
  local proxy=setmetatable({hitbox=r},{__index=a});local b=pick(engine,shot,proxy)
  if b then out.parts[#out.parts+1]=b;out.left=math.min(out.left,b.left);out.right=math.max(out.right,b.right);out.top=math.min(out.top,b.top);out.bottom=math.max(out.bottom,b.bottom)end
 end end
 if #out.parts>0 then return out end
end
C.ContainsPick=function(volume,u,v)
 if volume and volume.parts then for _,part in ipairs(volume.parts)do if contains(part,u,v)then return true end end;return false end
 return contains(volume,u,v)
end
-- Move a single face while holding its opposite face fixed. Values are in
-- intrinsic editor units, so rotation and scaling never change the saved box.
function H.Resize(r,face,delta)
 local out=copy(r);local axis=face:sub(1,1);local sign=face:sub(2)=='+'and 1 or-1
 local dim=axis=='x'and'width'or axis=='y'and'depth'or'height';local center=axis=='z'and'z'or axis
 local size=r[dim];local change=math.max(.05-size,math.min((axis=='z'and 15 or 20)-size,sign*delta))
 local shift=sign*change*(axis=='z'and(sign<0 and 1 or 0)or .5)
 local low,high=axis=='z'and-5 or-10,10
 if shift~=0 then
  local target=math.max(low,math.min(high,(r[center]or 0)+shift))
  if target~=(r[center]or 0)+shift then shift=target-(r[center]or 0);change=shift/(sign*(axis=='z'and 1 or .5))end
 end
 out[dim]=math.max(.05,math.min(axis=='z'and 15 or 20,size+change));out[center]=(r[center]or 0)+shift;return out
end
-- Invert the native projection along a frozen world axis. Three samples capture
-- perspective (a linear pixel/world ratio would slide the opposite face).
function H.AxisMap(frame,shot,origin,axis)
 local points={};local w,h=frame:GetWidth(),frame:GetHeight()
 for i=0,2 do local u,v=N.ProjectNative(frame,shot,origin[1]+axis[1]*i,origin[2]+axis[2]*i,origin[3]+axis[3]*i);if not u then return end;points[i+1]={u*w,v*h}end
 local dx,dy=points[2][1]-points[1][1],points[2][2]-points[1][2];local length=dx*dx+dy*dy
 if length<.25 then return end
 local k2=((points[3][1]-points[1][1])*dx+(points[3][2]-points[1][2])*dy)/length
 if math.abs(k2-1)<1e-7 then return end
 local c=(2-k2)/(2*(k2-1));local a=1+c
 return function(x,y)
  local k=(x*dx+y*dy)/length;local den=a-c*k;if math.abs(den)<1e-7 then return end
  local t=k/den;if t~=t or math.abs(t)>80 then return end;return t
 end
end
