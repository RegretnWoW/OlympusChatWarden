-- Shared scene projection. Logical positions, intrinsic scale and collision
-- stay in world units. Camera fit is preferred; painted-depth correction is
-- one optional scene-wide presentation transform, never a collision resize.
local _,ns=...;local N=ns.WardenNativeScene
local W={VERSION=1,REFERENCE_HEIGHT=1.85,WALK_SPEED=1.65};ns.WardenWorldScale=W
W.MIN_REFERENCE_HEIGHT=.002;W.MAX_REFERENCE_HEIGHT=1.5
-- Reusable world-unit proportions. These are template dimensions, not claims
-- that animation/equipment-inclusive bounding boxes are anatomical height.
-- Explicit authored heights and sizeMultiplier remain artistic exceptions.
W.raceHeights={[1]={1.85,1.75},[2]={2.05,1.90},[3]={1.35,1.28},[4]={2.13,2.03},[5]={1.80,1.70},[6]={2.60,2.45},[7]={1.02,.98},[8]={2.30,2.15},[9]={1.18,1.12},[10]={1.92,1.82},[11]={2.25,2.12},[22]={2.10,1.98},[24]={1.95,1.85},[25]={1.95,1.85},[26]={1.95,1.85}}
function W.IntrinsicHeight(a)
 local s=a.spec;local height=s.height
 if(s.controlled or s.socialVisitor or s.liveRemote or s.canonicalNPC)and not s.preserveHeight then
  local race,sex=s.appearance and s.appearance.raceID,s.appearance and s.appearance.sex
  if s.unit=='player'and type(UnitRace)=='function'then local _,_,id=UnitRace('player');race=id;sex=type(UnitSex)=='function'and UnitSex('player')or sex end
  local row=W.raceHeights[race];if row then height=(height or 1.85)/1.85*row[sex==3 and 2 or 1]end
 end;return height
end
local abs,sqrt,tan=math.abs,math.sqrt,math.tan
local function finite(x)return type(x)=='number'and x==x and abs(x)<math.huge end
local function clamp(x,a,b)return math.max(a,math.min(b,x))end
local function copy(t)return ns.WardenRoomCatalogue.Copy(t)end
local function sequence(v,n)
 if type(v)~='table'or getmetatable(v)or #v~=n then return false end
 local count=0;for k in pairs(v)do if type(k)~='number'or k~=math.floor(k)or k<1 or k>n then return false end;count=count+1 end
 return count==n
end
local function vector(v,n,limit)
 if not sequence(v,n)then return false end
 for i=1,n do if not finite(v[i])or abs(v[i])>(limit or 160)then return false end end;return true
end
-- Authored UV geometry is registered once against the original native lens.
-- Changing the display lens must not change a fence, entrance, spawn or path.
local function groundMap(project)
 local x0,y0=project(0,0);local x1,y1=project(2,0);local x2,y2=project(0,2);local x3,y3=project(2,2)
 if not(x0 and x1 and x2 and x3)then return end
 local ax,bx,cx=x1-x3,x2-x3,x0-x1+x3-x2;local ay,by,cy=y1-y3,y2-y3,y0-y1+y3-y2
 local det=ax*by-bx*ay;if abs(det)<1e-12 then return end
 local g,h=(cx*by-bx*cy)/det,(ax*cy-cx*ay)/det
 return{x1-x0+g*x1,x2-x0+h*x2,x0,y1-y0+g*y1,y2-y0+h*y2,y0,g,h}
end
local function inverseMap(m,u,v)
 local ar,ad,br,bd=m[1]-u*m[7],m[2]-u*m[8],m[4]-v*m[7],m[5]-v*m[8];local det=ar*bd-ad*br
 if abs(det)<1e-12 then return end
 local x,y=2*((u-m[3])*bd-ad*(v-m[6]))/det,2*(ar*(v-m[6])-br*(u-m[3]))/det
 if not finite(x)or not finite(y)or abs(x)>80 or abs(y)>80 then return end;return x,y
end
function N.AuthoredFloorPoint(frame,shot,u,v,height)
 if not frame or not finite(u)or not finite(v)then return end;height=height or 0
 local cache=frame.firesideAuthoredGround
 if not cache or cache.shot~=shot then
  if frame.firesideViewShot then return end
  cache={shot=shot,planes={}};frame.firesideAuthoredGround=cache
 end
 local m=cache.planes[height]
 if not m then
  local corroborated=true;local samples={}
  if not frame.firesideViewShot then
   m=groundMap(function(r,d)
    local x,y,z=N.World(shot,r,d,height);local u,v=N.ProjectNative(frame,shot,x,y,z);local a,b=N.Project(shot,x,y,z,16/9)
    if not u or not a then corroborated=false else samples[#samples+1]={u,v,a,b}end;return u,v
   end)
   if height==0 and m then
    local gx,gy,spanX,spanY=1,1,0,0
    for _,q in ipairs(samples)do
     if abs(q[3]-.5)>spanX then spanX=abs(q[3]-.5);gx=(q[1]-.5)/(q[3]-.5)end
     if abs(q[4]-.5)>spanY then spanY=abs(q[4]-.5);gy=(q[2]-.5)/(q[4]-.5)end
    end
    if spanX<.0001 or spanY<.0001 or gx<.2 or gx>8 or gy<.2 or gy>8 or abs(gx-gy)>.002*gy then corroborated=false end
    for _,q in ipairs(samples)do if abs(q[1]-(.5+(q[3]-.5)*gx))+abs(q[2]-(.5+(q[4]-.5)*gy))>.0002 then corroborated=false end end
    cache.corroborated=corroborated
    if corroborated then cache.lensGain=(gx+gy)*.5;cache.logicalShot={position=shot.position,target=shot.target,fov=2*math.atan(tan(shot.fov*.5)/cache.lensGain)}end
   end
  elseif cache.corroborated then
   m=groundMap(function(r,d)local x,y,z=N.World(shot,r,d,height);return N.Project(cache.logicalShot,x,y,z,16/9)end)
  end
  -- A first-frame viewport can yield a plausible but inconsistent matrix.
  -- Do not freeze that measurement for the remainder of this login.
  if not m or not frame.firesideViewShot and not corroborated then return end
  -- Animated raised contacts can expose many distinct heights. Keep a small
  -- reusable cache, never one permanent matrix per animation-frame height.
  if height==0 or(cache.planeCount or 0)<32 then cache.planes[height]=m;cache.planeCount=(cache.planeCount or 0)+1 end
  cache.lastHeight,cache.lastMap=height,m
 end
 return inverseMap(m,u,v)
end
function W.AuthoredView(engine)
 for i=1,4 do if not engine.projectionSource or engine.projectionSource==engine then break end;engine=engine.projectionSource end
 if not engine.frame then return engine.shot end -- Simulator mathematics only.
 N.AuthoredFloorPoint(engine.frame,engine.shot,.5,.7,0)
 local cache=engine.frame.firesideAuthoredGround
 if not cache or not cache.corroborated then return nil,'Wait for a supported native perspective projection; previous camera retained'end
 return cache.logicalShot
end
function N.AuthoredUV(frame,shot,right,depth,height)
 if not frame then return end
 N.AuthoredFloorPoint(frame,shot,.5,.7,height or 0)
 local cache=frame.firesideAuthoredGround;local m=cache and(cache.planes[height or 0]or cache.lastHeight==(height or 0)and cache.lastMap);if not m then return end
 local r,d=right*.5,depth*.5;local den=1+m[7]*r+m[8]*d;if abs(den)<1e-10 then return end
 return(m[1]*r+m[2]*d+m[3])/den,(m[4]*r+m[5]*d+m[6])/den
end
function W.Inverse(authored,view,u,v,z)
 view=view or authored;z=z or 0
 local p,t=view.position,view.target;local fx,fy,fz=t[1]-p[1],t[2]-p[2],t[3]-p[3]
 local d=sqrt(fx*fx+fy*fy+fz*fz);fx,fy,fz=fx/d,fy/d,fz/d
 local h=sqrt(fx*fx+fy*fy);if h<.0001 then return end
 local rx,ry=fy/h,-fx/h;local ux,uy,uz=-fz*fx/h,-fz*fy/h,h
 local lens=tan(view.fov*.5);local sx,sy=(u*2-1)*lens*16/9,(1-v*2)*lens
 local dx,dy,dz=fx+rx*sx+ux*sy,fy+ry*sx+uy*sy,fz+uz*sy
 if abs(dz)<.00001 then return end;local q=(z-p[3])/dz;if q<=0 then return end
 local x,y=p[1]+dx*q,p[2]+dy*q;local a,b=authored.target[1]-authored.position[1],authored.target[2]-authored.position[2];d=sqrt(a*a+b*b);a,b=a/d,b/d
 x,y=x-authored.target[1],y-authored.target[2]
 local right,depth=x*b-y*a,x*a+y*b;if abs(right)>80 or abs(depth)>80 then return end;return right,depth,z
end
function W.Analyze(scene)
 local shot=scene.shot;local nav=scene.definition.navigation;local b=nav.floorUV;local l,t,r,d
 local view,why=W.AuthoredView(scene.native);if not view then return nil,why end
 if type(b[1])=='table'then l,t,r,d=2,2,-1,-1;for _,p in ipairs(b)do l,t,r,d=math.min(l,p[1]),math.min(t,p[2]),math.max(r,p[1]),math.max(d,p[2])end
 else l,t,r,d=unpack(b)end
 local near,far=math.min(.9,d-.04),math.max(t+.04,.40);if near-far<.12 then near,far=d-.02,t+.02 end
 local out={};for i,v in ipairs({near,far})do
  local x,y,z=W.Inverse(shot,view,(l+r)*.5,v,nav.floor);if not x then return nil,'Walkable floor does not project to a stable reference plane'end
  local wx,wy,wz=N.World(shot,x,y,z);local u,foot=N.Project(view,wx,wy,wz,16/9);local _,head=N.Project(view,wx,wy,wz+W.REFERENCE_HEIGHT,16/9)
  if not head or foot<=head then return nil,'Reference character is outside this camera'end
  out[i]={world={x,y,z},screen={u,foot},height=foot-head}
 end
 return out,{viewport={scene.drawWidth or 1600,scene.drawHeight or 900},floor=nav.floor,source='Existing camera, logical floor and walkable boundaries; no image-only inference'}
end
local function lens(base,p)
 local dx,dy=base.target[1]-base.position[1],base.target[2]-base.position[2];local d=sqrt(dx*dx+dy*dy);dx,dy=dx/d,dy/d
 local x,y=base.target[1]-dx*p[1],base.target[2]-dy*p[1]
 return{position={x,y,p[2]},target={x+dx*20,y+dy*20,p[2]-tan(p[3])*20},fov=p[4]}
end
local function errorFor(base,view,anchors)
 local error,maxError,residuals=0,0,{}
 for _,a in ipairs(anchors)do
  local x,y,z=N.World(base,unpack(a.world));local u,v=N.Project(view,x,y,z,16/9);local _,top=N.Project(view,x,y,z+W.REFERENCE_HEIGHT,16/9)
  if not u or not top or top>=v then return 1000000,1 end
  local e={u-a.screen[1],v-a.screen[2],top-(a.screen[2]-a.height)}
  for _,n in ipairs(e)do error=error+n*n;maxError=math.max(maxError,abs(n));residuals[#residuals+1]=n end
 end;return error,maxError,residuals
end
local function solve4(m,b)
 for col=1,4 do
  local pivot=col;for row=col+1,4 do if abs(m[row][col])>abs(m[pivot][col])then pivot=row end end
  if abs(m[pivot][col])<1e-15 then return end
  m[col],m[pivot],b[col],b[pivot]=m[pivot],m[col],b[pivot],b[col]
  local div=m[col][col];for j=col,4 do m[col][j]=m[col][j]/div end;b[col]=b[col]/div
  for row=1,4 do if row~=col then local factor=m[row][col];for j=col,4 do m[row][j]=m[row][j]-factor*m[col][j]end;b[row]=b[row]-factor*b[col]end end
 end;return b
end
function W.Fit(base,anchors,authoredView)
 local valid,why=W.Validate({version=1,mode='camera',camera={position=base.position,target=base.target,fov=base.fov},anchors=anchors})
 if not valid then return nil,why end
 for _,a in ipairs(anchors)do if not vector(a.world,3,80)or not vector(a.screen,2,1.5)or not finite(a.height)or a.height<W.MIN_REFERENCE_HEIGHT or a.height>W.MAX_REFERENCE_HEIGHT then return nil,'Invalid visual reference'end end
 if abs(anchors[1].world[2]-anchors[2].world[2])<.5 then return nil,'Place the references farther apart on the ground'end
 local dx,dy=base.target[1]-base.position[1],base.target[2]-base.position[2];local distance=sqrt(dx*dx+dy*dy)
 local p={distance,base.position[3],math.atan2(base.position[3]-base.target[3],distance),(authoredView or base).fov}
 local ranges={{1,160},{.35,80},{.025,1.4},{.12,1.8}}
 local best,_,residual=errorFor(base,lens(base,p),anchors);local evaluations,lambda=1,.0001
 -- Bounded damped least squares. Coordinate descent converged too slowly on
 -- correlated distance/FOV references, even for an exactly valid camera.
 for iteration=1,80 do
  if best<1e-16 then break end
  local jac={};for k=1,4 do
   local old=p[k];local step=k<3 and .001 or .00001;p[k]=old+step
   local _,_,r=errorFor(base,lens(base,p),anchors);p[k]=old;evaluations=evaluations+1
   if not r then return nil,'References do not fit a forward-facing camera'end
   jac[k]={};for j=1,#residual do jac[k][j]=(r[j]-residual[j])/step end
  end
  local matrix,rhs={},{}
  for k=1,4 do matrix[k]={};rhs[k]=0
   for j=1,#residual do rhs[k]=rhs[k]-jac[k][j]*residual[j]end
   for l=1,4 do local dot=0;for j=1,#residual do dot=dot+jac[k][j]*jac[l][j]end;matrix[k][l]=dot end
   matrix[k][k]=matrix[k][k]+lambda*math.max(matrix[k][k],1e-8)
  end
  local delta=solve4(matrix,rhs);if not delta then break end
  local trial={};for k=1,4 do trial[k]=clamp(p[k]+delta[k],ranges[k][1],ranges[k][2])end
  local e,_,r=errorFor(base,lens(base,trial),anchors);evaluations=evaluations+1
  if e<best then p,best,residual=trial,e,r;lambda=math.max(1e-9,lambda*.25)else lambda=math.min(1e8,lambda*8)end
 end
 local shot=lens(base,p);local _,maxError=errorFor(base,shot,anchors)
 return{version=1,mode='camera',camera=shot,anchors=copy(anchors)}, {maxError=maxError,pixelsAt900=maxError*900,evaluations=evaluations,approximate=maxError>.006,source='Constrained perspective camera fit; original logical coordinate basis unchanged'}
end
function W.PaintedFit(base,anchors,authoredView)
 local valid,why=W.Validate({version=1,mode='camera',camera={position=base.position,target=base.target,fov=base.fov},anchors=anchors})
 if not valid then return nil,why end
 local knots={}
 local view=authoredView or base
 for _,a in ipairs(anchors)do local x,y,z=N.World(base,unpack(a.world));local _,foot=N.Project(view,x,y,z,16/9);local _,head=N.Project(view,x,y,z+W.REFERENCE_HEIGHT,16/9)
  if not head or foot-head<.001 then return nil,'Reference is outside the camera'end
  local factor=a.height/(foot-head);if factor<.1 or factor>4 then return nil,'Painted reference needs an excessive correction'end
  knots[#knots+1]={depth=a.world[2],factor=factor}
 end
 table.sort(knots,function(a,b)return a.depth<b.depth end)
 for i=2,#knots do if knots[i].depth-knots[i-1].depth<.5 or knots[i].factor>knots[i-1].factor+.00001 then return nil,'These references are inconsistent. Add or reposition the middle reference; far corrections must decrease smoothly.'end end
 return{version=1,mode='painted',camera={position=copy(view.position),target=copy(view.target),fov=view.fov},anchors=copy(anchors),knots=knots}
end
function W.Validate(r)
 if type(r)~='table'or getmetatable(r)or r.version~=1 or(r.mode~='camera'and r.mode~='painted')then return nil,'Unsupported scene calibration'end
 for k in pairs(r)do if not({version=true,mode=true,camera=true,anchors=true,knots=true})[k]then return nil,'Unknown calibration field'end end
 local c=r.camera;if type(c)~='table'or getmetatable(c)or not vector(c.position,3)or not vector(c.target,3)or not finite(c.fov)or c.fov<.12 or c.fov>1.8 then return nil,'Invalid calibrated camera'end
 for k in pairs(c)do if k~='position'and k~='target'and k~='fov'then return nil,'Unknown camera field'end end
 if (c.position[1]-c.target[1])^2+(c.position[2]-c.target[2])^2<.00001 then return nil,'Degenerate calibrated camera'end
 if type(r.anchors)~='table'or #r.anchors<2 or #r.anchors>3 or not sequence(r.anchors,#r.anchors)then return nil,'Invalid calibration references'end
 for _,a in ipairs(r.anchors)do
  if type(a)~='table'or getmetatable(a)or not vector(a.world,3,80)or not vector(a.screen,2,1.5)or not finite(a.height)or a.height<W.MIN_REFERENCE_HEIGHT or a.height>W.MAX_REFERENCE_HEIGHT then return nil,'Invalid reference'end
  for k in pairs(a)do if k~='world'and k~='screen'and k~='height'then return nil,'Unknown reference field'end end
 end
 if r.mode=='painted'then
  if not sequence(r.knots,#r.anchors)then return nil,'Invalid depth curve'end
  for i,k in ipairs(r.knots)do if type(k)~='table'or getmetatable(k)or not finite(k.depth)or abs(k.depth)>80 or not finite(k.factor)or k.factor<.1 or k.factor>4 then return nil,'Invalid depth reference'end
   for name in pairs(k)do if name~='depth'and name~='factor'then return nil,'Unknown depth field'end end
   if i>1 and(k.depth-r.knots[i-1].depth<.5 or k.factor>r.knots[i-1].factor+.00001)then return nil,'Depth curve must be monotonic'end
  end
 elseif r.knots~=nil then return nil,'A camera calibration has no separate scale curve'end
 return copy(r)
end
function W.Curve(record,depth)
 if not record or record.mode~='painted'then return 1 end;local a=record.knots
 if depth<=a[1].depth then return a[1].factor end
 for i=2,#a do if depth<=a[i].depth then local q=(depth-a[i-1].depth)/(a[i].depth-a[i-1].depth);q=q*q*(3-2*q);return a[i-1].factor+(a[i].factor-a[i-1].factor)*q end end
 return a[#a].factor
end
function W.Root(engine,a)
 local root=a
 for i=1,8 do local parent=root.spec and root.spec.support and engine.actors[root.spec.support];if not parent or parent==root or not parent.position then break end;root=parent end
 return root
end
function W.Render(engine,a,right,depth,height)
 local root=W.Root(engine,a);local r,d,h=right,depth,height;if root~=a then r,d,h=unpack(root.position)end
 local factor=W.Curve(engine.worldCalibration,d);local x,y,z=N.World(engine.shot,right,depth,height+(a.groundOffset or 0)-a.bounds[3]*a.scale)
 if factor~=1 then local px,py,pz=N.World(engine.shot,r,d,h);x,y,z=px+(x-px)*factor,py+(y-py)*factor,pz+(z-pz)*factor end
 return x,y,z,a.scale*factor,factor
end
function W.PresentWorld(engine,a,x,y,z)
 local factor=a.presentationFactor or 1;if factor==1 then return x,y,z end
 local root=W.Root(engine,a);local px,py,pz=N.World(engine.shot,unpack(root.position));return px+(x-px)*factor,py+(y-py)*factor,pz+(z-pz)*factor
end
function W.PhysicalWorld(engine,a,x,y,z)
 local factor=a.presentationFactor or 1;if factor==1 then return x,y,z end
 local root=W.Root(engine,a);local px,py,pz=N.World(engine.shot,unpack(root.position));return px+(x-px)/factor,py+(y-py)/factor,pz+(z-pz)/factor
end
function W.InAuthoredUV(scene,u,v,box)
 -- Uncalibrated scenes already use their authored screen registration. Keep
 -- painted travel portals usable while native ground registration is pending
 -- or unavailable; transformed scenes must still invert the calibrated lens.
 if not scene.worldCalibration then return u>=box[1]and u<=box[3]and v>=box[2]and v<=box[4]end
 local x,y=N.FloorPoint(scene.native.frame,scene.shot,u,v,0);if not x then return false end
 local r,d=N.AuthoredUV(scene.native.frame,scene.shot,x,y,0);return r and r>=box[1]and r<=box[3]and d>=box[2]and d<=box[4]or false
end
function W.ScreenToAuthored(scene,u,v)
 if not scene.worldCalibration then return u,v end
 local x,y=N.FloorPoint(scene.native.frame,scene.shot,u,v,0);if not x then return end
 return N.AuthoredUV(scene.native.frame,scene.shot,x,y,0)
end
function W.ProjectAuthoredPolygon(scene,box)
 local points={}
 for _,p in ipairs({{box[1],box[2]},{box[3],box[2]},{box[3],box[4]},{box[1],box[4]}})do
  if not scene.worldCalibration then points[#points+1]={p[1],p[2]}
  else
   local r,d=N.AuthoredFloorPoint(scene.native.frame,scene.shot,p[1],p[2],0);if not r then return end
   local x,y,z=N.World(scene.shot,r,d,0);local u,v=N.ProjectNative(scene.native.frame,scene.shot,x,y,z);if not u then return end
   points[#points+1]={u,v}
  end
 end
 return points
end
function W.ProjectAuthoredBox(scene,box)
 if not scene.worldCalibration then return box end
 local bounds={2,2,-1,-1}
 local points=W.ProjectAuthoredPolygon(scene,box);if not points then return end
 for _,p in ipairs(points)do local u,v=p[1],p[2]
  bounds[1],bounds[2],bounds[3],bounds[4]=math.min(bounds[1],u),math.min(bounds[2],v),math.max(bounds[3],u),math.max(bounds[4],v)
 end;return bounds
end
function W.ProjectWorldPoint(engine,right,depth,height)
 local x,y,z=N.World(engine.shot,right,depth,height)
 -- Physical navigation dimensions already exist in world coordinates.
 -- Applying a second object-size curve here would draw a different collider.
 return N.ProjectNative(engine.frame,engine.shot,x,y,z)
end
-- One projection entry point for model-aligned colliders, click volumes,
-- editor handles and shadows. Neither this function nor the renderer changes
-- logical bounds or navigation radii when depth changes.
function W.ProjectPoint(engine,a,right,depth,height,authored)
 local shot=engine.shot or authored;local x,y,z=N.World(shot,right,depth,height)
 x,y,z=W.PresentWorld(engine,a,x,y,z)
 return N.ProjectNative(a.renderScene or engine.frame,shot,x,y,z)
end
function W.UnprojectPoint(engine,a,u,v,height)
 local root=W.Root(engine,a);local factor=a.presentationFactor or 1
 for i=1,5 do
  local base=root.position[3];local visualHeight=base+(height-base)*factor
  local r,d=N.FloorPoint(a.renderScene or engine.frame,engine.shot,u,v,visualHeight);if not r then return end
  if root~=a then
   local x,y,z=N.World(engine.shot,r,d,visualHeight);x,y,z=W.PhysicalWorld(engine,a,x,y,z)
   local p,t=engine.shot.position,engine.shot.target;local dx,dy=t[1]-p[1],t[2]-p[2];local n=sqrt(dx*dx+dy*dy);dx,dy=dx/n,dy/n
   x,y=x-t[1],y-t[2];return x*dy-y*dx,x*dx+y*dy
  end
  local nextFactor=W.Curve(engine.worldCalibration,d)
  if abs(nextFactor-factor)<.00001 or i==5 then return r,d end;factor=nextFactor
 end
end
function W.Apply(scene,record)
 local valid,why;if record then valid,why=W.Validate(record);if not valid then return false,why end end
 local engines={};for _,engine in pairs({scene.native,scene.nativeAir})do engines[#engines+1]={engine=engine,record=engine.worldCalibration,view=engine.logicalViewShot or engine.viewShot}
  if engine.frame and not engine.viewShot then N.AuthoredFloorPoint(engine.frame,engine.shot,.5,.7,0)end
 end
 for _,entry in ipairs(engines)do local engine=entry.engine;engine.worldCalibration=valid
  if engine.frame and not N.ViewCamera(engine,nil)then
   for _,old in ipairs(engines)do old.engine.worldCalibration=old.record;if old.engine.frame then N.ViewCamera(old.engine,old.view)end end
   return false,'Native camera rejected calibration; previous projection retained'
  end
 end
 for _,entry in ipairs(engines)do local engine=entry.engine;for _,a in ipairs(engine.order)do if a.ready and a.position then engine:Place(a,unpack(a.position))end end end
 scene.worldCalibration=valid;return true
end
-- Keep authored intent while the native viewport warms up. This is volatile:
-- failed camera setup never changes a saved layout or discards its calibration.
function W.Request(scene,record,source)
 local valid,why;if record then valid,why=W.Validate(record);if not valid then return false,why end end
 scene.pendingWorldCalibration={record=valid,source=source,attempts=0,nextTry=0}
 return W.Retry(scene,0)
end
function W.Retry(scene,clock)
 local pending=scene.pendingWorldCalibration;if not pending then return true end
 if clock<(pending.nextTry or 0)then return false,pending.reason end
 pending.nextTry=clock+.5;pending.attempts=pending.attempts+1
 local ok,why=W.Apply(scene,pending.record)
 if not ok then pending.reason=why;return false,why end
 scene.worldCalibrationSource=pending.source;scene.pendingWorldCalibration=nil
 scene.sceneryNavigationKey=nil;scene.sceneryNavigation=nil
 return true
end
local camera=N.ViewCamera
N.ViewCamera=function(engine,view)
 if engine and engine.frame and not engine.viewShot and not engine.projectionSource then N.AuthoredFloorPoint(engine.frame,engine.shot,.5,.7,0)end
 local logical=view or engine.worldCalibration and engine.worldCalibration.camera
 if logical and engine.worldCalibration and engine.frame then
  local base,why=W.AuthoredView(engine);if not base then return false,why end
  local source=engine;for i=1,4 do if not source.projectionSource or source.projectionSource==source then break end;source=source.projectionSource end
  local gain=source.frame.firesideAuthoredGround.lensGain
  local native={position=logical.position,target=logical.target,fov=2*math.atan(tan(logical.fov*.5)*gain)}
  local ok=camera(engine,native);engine.logicalViewShot=ok and logical or nil;return ok
 end
 engine.logicalViewShot=nil;return camera(engine,logical)
end
function N.WalkSpeed(a)return a and a.engine and a.engine.walkSpeed or W.WALK_SPEED end
function N.WalkDuration(a,path)return math.max(.65,path.length/N.WalkSpeed(a)+.30)end
