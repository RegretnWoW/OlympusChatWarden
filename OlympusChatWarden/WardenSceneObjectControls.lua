-- Bounded owner-authored geometry. Offsets follow the object's local X/Y axes;
-- collision and picking remain independent. No imported executable content.
local _,ns=...
local C={VERSION=1};ns.WardenSceneObjectControls=C
local function num(v,lo,hi)return type(v)=='number'and v==v and v>=lo and v<=hi end
function C.Validate(kind,r)
 if type(r)~='table'or getmetatable(r)then return nil,'Use a plain '..kind..' record'end
 local rules=kind=='art-shadow'and{enabled='bool',width={.01,4},depth={.005,2},x={-2,3},y={-2,3},opacity={0,1}}
  or kind=='shadow'and{enabled='bool',width={.05,20},depth={.05,20},x={-10,10},y={-10,10},opacity={0,1}}
  or kind=='hitbox'and{enabled='bool',width={.05,20},depth={.05,20},height={.05,15},x={-10,10},y={-10,10},z={-5,10}}
  or kind=='collider'and{enabled='bool',width={.05,20},depth={.05,20},x={-10,10},y={-10,10}}
 if not rules then return nil,'Unknown geometry control'end
 local out={};for k,v in pairs(r)do local limit=rules[k]
  if not limit or limit=='bool'and type(v)~='boolean'or type(limit)=='table'and not num(v,limit[1],limit[2])then return nil,'Invalid '..kind..' '..tostring(k)end;out[k]=v
 end;return out
end
function C.LocalBox(shot,a,r)
 if not a.position or not a.bounds then return end
 local basis=a.editorBaseScale or a.authoredBaseScale or a.scale;local scale=a.scale/basis
 -- Implicit dimensions start from the same intrinsic basis as explicit editor
 -- dimensions. A cold actor has no editorBaseScale: using its final scale here
 -- would apply sizeMultiplier twice and give other clients a larger collider.
 local hx=(r.width or(a.bounds[4]-a.bounds[1])*basis)*.5*scale
 local hy=(r.depth or(a.bounds[5]-a.bounds[2])*basis)*.5*scale
 local yaw=(a.worldYaw or 0)-math.atan2(shot.target[2]-shot.position[2],shot.target[1]-shot.position[1])+math.pi*.5
 local c,s=math.cos(yaw),math.sin(yaw);local dx,dy=(r.x or 0)*scale,(r.y or 0)*scale
 local x,y=a.position[1]+c*dx-s*dy,a.position[2]+s*dx+c*dy
 local rx,ry=math.abs(c)*hx+math.abs(s)*hy,math.abs(s)*hx+math.abs(c)*hy
 local corners={};for _,q in ipairs({{-hx,-hy},{hx,-hy},{hx,hy},{-hx,hy}})do corners[#corners+1]={x+c*q[1]-s*q[2],y+s*q[1]+c*q[2]}end
 -- Keep conservative extents for the existing path planner, plus the exact
 -- oriented corners for click volumes and editor outlines.
 return{id=a.id,left=x-rx,right=x+rx,near=y-ry,far=y+ry,corners=corners,centerX=x,centerY=y,halfX=hx,halfY=hy,cos=c,sin=s}
end
function C.PickBox(shot,a)
 local r=a.hitbox
 if r and r.enabled==false then return end
 local box=C.LocalBox(shot,a,r or{});if not box then return end
 local ratio=a.scale/(a.editorBaseScale or a.authoredBaseScale or a.scale)
 box.bottom=a.position[3]+(a.groundOffset or 0)+(r and r.z or 0)*ratio
 -- A just-loaded/re-layered actor can expose bounds before cached height.
 -- Derive the same scaled extent directly rather than aborting world layout.
 box.top=box.bottom+(r and r.height and r.height*ratio or a.top or(a.bounds[6]-a.bounds[3])*a.scale)
 return box
end
function C.ProjectPick(engine,shot,a)
 if not a or not a.ready then return end
 local box=C.PickBox(shot,a);if not box then return end
 local points={};local N=ns.WardenNativeScene
 for _,p in ipairs(box.corners)do for _,z in ipairs({box.bottom,box.top})do
  local u,v=ns.WardenWorldScale.ProjectPoint(engine,a,p[1],p[2],z,shot)
  if not u or not v then return end;points[#points+1]={u,v}
 end end
 table.sort(points,function(a,b)return a[1]==b[1]and a[2]<b[2]or a[1]<b[1]end)
 local function cross(a,b,c)return(b[1]-a[1])*(c[2]-a[2])-(b[2]-a[2])*(c[1]-a[1])end
 local hull={};for _,p in ipairs(points)do while #hull>1 and cross(hull[#hull-1],hull[#hull],p)<=0 do table.remove(hull)end;hull[#hull+1]=p end
 local lower=#hull
 for i=#points-1,1,-1 do local p=points[i];while #hull>lower and cross(hull[#hull-1],hull[#hull],p)<=0 do table.remove(hull)end;hull[#hull+1]=p end
 table.remove(hull);if #hull<3 then return end
 local out={hull=hull,left=2,right=-1,top=2,bottom=-1}
 for _,p in ipairs(hull)do out.left=math.min(out.left,p[1]);out.right=math.max(out.right,p[1]);out.top=math.min(out.top,p[2]);out.bottom=math.max(out.bottom,p[2])end
 return out
end
-- Exactly the footprint consumed by N.CheckPath, projected for inspection.
-- Radius-based obstacles retain their actual square planner bounds here;
-- oriented footprints retain their local axes. No independent UI dimensions.
function C.ColliderShape(shot,a)
 local N=ns.WardenNativeScene
 if N.GroundWalker(a)and a.ready and a.position then
  local radius=N.PersonRadius(a);local corners={}
  for i=0,23 do local t=i*math.pi/12;corners[#corners+1]={a.position[1]+math.cos(t)*radius,a.position[2]+math.sin(t)*radius}end
  return{circle=true,radius=radius,x=a.position[1],y=a.position[2],corners=corners}
 end;return N.Footprint(shot,a)
end
function C.ProjectCollider(engine,shot,a)
 local b=C.ColliderShape(shot,a);if not b then return end
 local corners=b.corners or{{b.left,b.near},{b.right,b.near},{b.right,b.far},{b.left,b.far}}
 local points={};for _,p in ipairs(corners)do
  local u,v=ns.WardenWorldScale.ProjectWorldPoint(engine,p[1],p[2],a.spec.groundHeight or a.position[3])
  if not u then return end;points[#points+1]={u,v}
 end;return points,b
end
function C.ContainsPick(volume,u,v)
 if not volume or not num(u,-100,100)or not num(v,-100,100)then return false end
 if u<volume.left or u>volume.right or v<volume.top or v>volume.bottom then return false end
 for i,a in ipairs(volume.hull)do local b=volume.hull[i%#volume.hull+1]
  if(b[1]-a[1])*(v-a[2])-(b[2]-a[2])*(u-a[1])<-.0000001 then return false end
 end;return true
end
function C.Light(r)
 if type(r)~='table'or getmetatable(r)then return nil,'Invalid scene light'end
 local rules={ambient={0,1},diffuse={0,1},red={0,1},green={0,1},blue={0,1},x={-40,40},y={-40,40},z={-40,40}}
 local out={};for k,v in pairs(r)do
  if k=='mode'then if v~='directional'and v~='point'then return nil,'Unknown light mode'end
  elseif not rules[k]or not num(v,rules[k][1],rules[k][2])then return nil,'Invalid scene light '..tostring(k)end;out[k]=v
 end
 for k in pairs(rules)do if out[k]==nil then return nil,'Missing light '..k end end
 if not out.mode or out.mode=='directional'and out.x*out.x+out.y*out.y+out.z*out.z<.0001 then return nil,'A light direction is required'end
 return out
end
