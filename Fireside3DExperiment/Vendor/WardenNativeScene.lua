-- Native actors and interacting props share ONE perspective/depth buffer.
-- Scene-only presentation: no collectors, identity, rewards or saved history.
local _,ns=...
local N={VERSION=10,MAX_ACTORS=40,MAX_PATH_SAMPLES=129};ns.WardenNativeScene=N
local pi,sqrt,sin,cos=math.pi,math.sqrt,math.sin,math.cos
local function finite(v)return type(v)=='number'and v==v and v~=math.huge and v~=-math.huge end
local function id(v)return finite(v)and v>0 and v<=1000000000 and v==math.floor(v)end
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
function N.Call(o,key,...)
 if not o or type(o[key])~='function'then return false,'Unavailable '..key end
 return pcall(o[key],o,...)
end
N.closeupActors={journal={desk=true,candle=true,['room-book']=true},shelf={['shelf-right']=true}}
function N.CloseupHidden(mode,id,focusRoom)
 return mode~=nil and(not focusRoom or not(N.closeupActors[mode]and N.closeupActors[mode][id]))
end
-- Textured generic bodies: CreatureDisplayInfo + Extra, matched to the
-- ChrRaces/ChrModel skeleton and race/sex. Bare player displays have no baked
-- material and render white on an offline creature-backed actor. Metadata: wago.tools.
-- These are generic bodies, never evidence of an uncaptured face or hairstyle.
local classicBodies={[1]={1276,176},[2]={1139,1312},[3]={115,1286},[4]={1285,1543},[5]={1027,1029},[6]={1624,1322},[7]={1832,1890},[8]={1976,1882},[9]={6882,7175},[10]={10375,11657},[11]={16199,16200}}
local retailBodies={[1]={1276,176},[2]={1139,1312},[3]={115,1286},[4]={1285,1543},[5]={1027,1029},[6]={1624,1322},[7]={1832,1890},[8]={1976,1882},[9]={6882,7175},[10]={10375,15505},[11]={16199,16200},[22]={30164,31689},[24]={39489,39487},[25]={56219,87613},[26]={86949,86917},[27]={81832,81847},[28]={80981,81849},[29]={80975,80977},[30]={76240,76338},[31]={15003,14996},[32]={76907,77936},[34]={8803,69941},[35]={78401,79314},[36]={86324,85555},[37]={90771,90797},[52]={102032,102033},[70]={104821,105451},[84]={114403,114678},[85]={114855,116294}}
local bareBodies={[49]=true,[50]=true,[51]=true,[52]=true,[53]=true,[54]=true,[55]=true,[56]=true,[57]=true,[58]=true,[59]=true,[60]=true,[1478]=true,[1479]=true,[1563]=true,[1564]=true,[6894]=true,[6895]=true,[15475]=true,[15476]=true,[16125]=true,[16126]=true,[29422]=true,[29423]=true,[38551]=true,[38552]=true,[49242]=true,[51877]=true,[51894]=true,[53291]=true,[53762]=true,[53768]=true,[54041]=true,[54439]=true,[54918]=true,[55077]=true,[56316]=true,[56327]=true,[56658]=true,[57027]=true,[57899]=true,[58232]=true,[59071]=true,[59223]=true,[62127]=true,[62128]=true,[75078]=true,[75079]=true,[75080]=true,[75081]=true,[75082]=true,[75083]=true,[75084]=true,[75085]=true,[79100]=true,[79101]=true,[80387]=true,[80388]=true,[83910]=true,[83911]=true,[83913]=true,[83914]=true,[84558]=true,[84560]=true,[90786]=true,[90787]=true,[104597]=true,[115279]=true,[115281]=true}
function N.BodyDisplay(appearance)
 if type(appearance)~='table'then return end
 if id(appearance.nativeDisplayID)and not bareBodies[appearance.nativeDisplayID]then return appearance.nativeDisplayID end
 if appearance.sex~=2 and appearance.sex~=3 then return end
 local rows=ns.ClientCompat and ns.ClientCompat.client=='retail'and retailBodies or classicBodies
 local pair=rows[appearance.raceID];return pair and pair[appearance.sex-1]
end
function N.IsSimulator()
 return rawget(_G,'WARDEN_SIMULATOR_ISOLATED')==true or type(rawget(_G,'WardenSimulator'))=='table'and WardenSimulator.Host~=nil
end
function N.Bounds(actor)
 local ok,a,b,c,d,e,f=N.Call(actor,'GetActiveBoundingBox');if not ok then return end
 if finite(a)and finite(b)and finite(c)and finite(d)and finite(e)and finite(f)then return a,b,c,d,e,f end
 local function xyz(v)
  if type(v)~='table'and type(v)~='userdata'then return end
  local good,x,y,z=pcall(function()if type(v.GetXYZ)=='function'then return v:GetXYZ()end;return v.x,v.y,v.z end)
  if good and finite(x)and finite(y)and finite(z)then return x,y,z end
 end
 local ax,ay,az=xyz(a);local bx,by,bz=xyz(b);if ax and bx then return ax,ay,az,bx,by,bz end
end
function N.StandingPlayerBounds(a,b)
 if a.spec.unit~='player'then return b end
 local file=a.probeModelFileID;local ok,native=N.Call(a.actor,'GetModelFileID');if ok and id(native)then file=native end
 if not id(file)then return b end
 local saved=a.standingGeometry
 if saved and saved.fileID==file then return saved.bounds end
 local bounds={unpack(b)};a.standingGeometry={fileID=file,bounds=bounds};return bounds
end
function N.PropRenderLayer(engine,a,requested)
 if requested~=engine.baseLayer or not a.spec.fileID or a.spec.showcaseSupport or a.spec.support or a.spec.effect or a.id=='flagpole'then return requested end
 local pole=engine.actors.flagpole
 if engine.layers and engine.layers['native-rear']and pole and pole.ready and not pole.editorHidden and pole.position and a.position and a.position[2]>pole.position[2]+.05 then return'native-rear'end
 return requested
end
function N.Camera(scene,x,y,z,tx,ty,tz,fov)
 for _,v in ipairs({x,y,z,tx,ty,tz,fov or .75})do if not finite(v)then return false,'Invalid camera'end end
 local dx,dy,dz=tx-x,ty-y,tz-z;local length=sqrt(dx*dx+dy*dy+dz*dz)
 if length<.0001 or sqrt(dx*dx+dy*dy)<.0001 then return false,'Degenerate camera'end
 -- Blizzard's pitch convention: forward.z = sin(-pitch). Do not reflect axes.
 local yaw,pitch=math.atan2(dy,dx),math.asin(-dz/length)
 local pos=N.Call(scene,'SetCameraPosition',x,y,z)
 local orient=N.Call(scene,'SetCameraOrientationByYawPitchRoll',yaw,pitch,0)
 local field=N.Call(scene,'SetCameraFieldOfView',fov or .75)
 N.Call(scene,'SetCameraNearClip',math.max(.001,length*.01));N.Call(scene,'SetCameraFarClip',math.max(100,length*12))
 return pos and orient and field,{position={x,y,z},target={tx,ty,tz},fov=fov or .75,yaw=yaw,pitch=pitch}
end
-- A presentation camera never changes the authored coordinate basis or actors.
function N.ViewCamera(engine,view)
 if not engine or not engine.frame then return false end
 local shot=view or engine.shot;local frames=engine.RenderFrames and engine:RenderFrames()or{engine.frame};local accepted=true
 for _,frame in ipairs(frames)do local ok=N.Camera(frame,shot.position[1],shot.position[2],shot.position[3],shot.target[1],shot.target[2],shot.target[3],shot.fov)
  if ok then frame.firesideViewShot=view else accepted=false end
 end
 if accepted then engine.viewShot=view;engine.viewRevision=(engine.viewRevision or 0)+1
 else for _,frame in ipairs(frames)do local base=engine.shot;N.Camera(frame,base.position[1],base.position[2],base.position[3],base.target[1],base.target[2],base.target[3],base.fov);frame.firesideViewShot=nil end;engine.viewShot=nil end
 return accepted
end
-- Coordinates in an authored set: horizontal/right, depth/away, elevation.
-- These become real world X/Y/Z. Apparent size is perspective, NEVER per-tick scale.
function N.World(shot,right,depth,height)
 local p,t=shot.position,shot.target;local x,y=t[1]-p[1],t[2]-p[2];local d=sqrt(x*x+y*y)
 if d<.0001 then return end;x,y=x/d,y/d
 return t[1]+y*right+x*depth,t[2]-x*right+y*depth,height
end
function N.Project(shot,x,y,z,aspect)
 local p,t=shot.position,shot.target;local fx,fy,fz=t[1]-p[1],t[2]-p[2],t[3]-p[3];local d=sqrt(fx*fx+fy*fy+fz*fz)
 if d<.0001 then return end;fx,fy,fz=fx/d,fy/d,fz/d
 local h=sqrt(fx*fx+fy*fy);if h<.0001 then return end
 local rx,ry=fy/h,-fx/h;local ux,uy,uz=-fz*fx/h,-fz*fy/h,h
 local dx,dy,dz=x-p[1],y-p[2],z-p[3];local depth=dx*fx+dy*fy+dz*fz
 if depth<=.0001 then return end
 local lens=math.tan(shot.fov*.5);local horizontal=(dx*rx+dy*ry)/(depth*lens*(aspect or 16/9))
 local vertical=(dx*ux+dy*uy+dz*uz)/(depth*lens)
 return .5+.5*horizontal,.5-.5*vertical,depth
end
-- Prefer the client's own projection for book/prop registration. Detect its
-- coordinate convention at the known camera target; do not assume pixel units.
function N.ProjectNative(scene,shot,x,y,z)
 shot=scene and scene.firesideViewShot or shot
 local good,cx,cy,centerDepth=N.Call(scene,'Project3DPointTo2D',unpack(shot.target));if not good or not finite(cx)or not finite(cy)or not finite(centerDepth)or centerDepth<=0 then return end
 local ok,u,v,depth=N.Call(scene,'Project3DPointTo2D',x,y,z);if not ok or not finite(u)or not finite(v)or not finite(depth)then return end
 local w,h,scale=scene:GetWidth(),scene:GetHeight(),scene:GetEffectiveScale();if w<2 or h<2 then return end
 local function near(a,b)return math.abs(a-b)<math.max(.002,math.abs(b)*.002)end
 -- Native projection is cached by the renderer. During a viewport resize its
 -- pixel extent may still be the previous frame's extent. The fixed camera's
 -- target gives that extent directly, avoiding UI-scale and one-frame drift.
 if cx>1 and cy>1 and near(cx/cy,w/h)then return u/(2*cx),1-v/(2*cy),'native target-relative pixels'end
 if near(cx,w*scale*.5)and near(cy,h*scale*.5)then return u/(w*scale),1-v/(h*scale),'native pixels'end
 if near(cx,w*.5)and near(cy,h*.5)then return u/w,1-v/h,'native UI units'end
 if near(cx,.5)and near(cy,.5)then return u,1-v,'native normalized'end
 if near(cx,0)and near(cy,0)then return .5+u*.5,.5-v*.5,'native clip coordinates'end
end
function N.ProjectInScene(engine,shot,x,y,z,aspect)
 if engine and engine.frame then local u,v,mode=N.ProjectNative(engine.frame,shot,x,y,z);if u then return u,v,mode end end
 local u,v=N.Project(engine and engine.viewShot or shot,x,y,z,aspect);return u,v,'mathematical fallback; native registration unverified'
end
-- Register an authored floor contact against the client's actual projection.
-- A bounded inverse solve avoids guessing field-of-view or pixel conventions.
-- Never substitute the mathematical preview when native registration fails.
function N.FloorPoint(scene,shot,u,v,height)
 if not finite(u)or not finite(v)then return nil end
 -- Fit a projective ground plane to four ACTUAL native projections. The
 -- old ten-step finite-difference solve failed at valid Study floor corners,
 -- disabling the entire navigation fence. No preview-camera fallback is used.
 local function project(r,d)local x,y,z=N.World(shot,r,d,height or 0);return N.ProjectNative(scene,shot,x,y,z)end
 local x0,y0=project(0,0);local x1,y1=project(2,0);local x2,y2=project(0,2);local x3,y3=project(2,2)
 if not(x0 and x1 and x2 and x3)then return nil end
 local ax,bx,cx=x1-x3,x2-x3,x0-x1+x3-x2
 local ay,by,cy=y1-y3,y2-y3,y0-y1+y3-y2
 local det=ax*by-bx*ay;if math.abs(det)<1e-12 then return nil end
 local g,h=(cx*by-bx*cy)/det,(ax*cy-cx*ay)/det
 local a,b,c=x1-x0+g*x1,x2-x0+h*x2,x0
 local d,e,f=y1-y0+g*y1,y2-y0+h*y2,y0
 local ar,ad,br,bd=a-u*g,b-u*h,d-v*g,e-v*h
 det=ar*bd-ad*br;if math.abs(det)<1e-12 then return nil end
 local right,depth=2*((u-c)*bd-ad*(v-f))/det,2*(ar*(v-f)-br*(u-c))/det
 if not finite(right)or not finite(depth)or math.abs(right)>80 or math.abs(depth)>80 then return nil end
 local px,py=project(right,depth)
 if not px or math.abs(px-u)+math.abs(py-v)>.0002 then return nil end
 return right,depth
end
-- Flying screen routes use an actual native depth plane. This avoids assuming
-- that a fixed flight height remains on the same side of a changed eye level.
function N.ViewPointAtDepth(scene,shot,u,v,depth)
 if not finite(u)or not finite(v)or not finite(depth)or depth<0 or depth>80 then return end
 local function project(r,h)local x,y,z=N.World(shot,r,depth,h);return N.ProjectNative(scene,shot,x,y,z)end
 local x0,y0=project(0,0);local x1,y1=project(2,0);local x2,y2=project(0,2);local x3,y3=project(2,2)
 if not(x0 and x1 and x2 and x3)then return end
 local ax,bx,cx=x1-x3,x2-x3,x0-x1+x3-x2;local ay,by,cy=y1-y3,y2-y3,y0-y1+y3-y2
 local det=ax*by-bx*ay;if math.abs(det)<1e-12 then return end
 local g,h=(cx*by-bx*cy)/det,(ax*cy-cx*ay)/det
 local a,b,c=x1-x0+g*x1,x2-x0+h*x2,x0;local d,e,f=y1-y0+g*y1,y2-y0+h*y2,y0
 local ar,ad,br,bd=a-u*g,b-u*h,d-v*g,e-v*h;det=ar*bd-ad*br;if math.abs(det)<1e-12 then return end
 local right,height=2*((u-c)*bd-ad*(v-f))/det,2*(ar*(v-f)-br*(u-c))/det
 if not finite(right)or not finite(height)or math.abs(right)>80 or math.abs(height)>80 then return end
 local x,y=project(right,height);if not x or math.abs(x-u)+math.abs(y-v)>.0002 then return end
 return right,depth,height
end
function N.FloorFence(scene,shot,box)
 local outline=type(box[1])=='table'and box or{{box[1],box[2]},{box[3],box[2]},{box[3],box[4]},{box[1],box[4]}}
 local points={};for _,p in ipairs(outline)do
  local x,y=N.FloorPoint(scene,shot,p[1],p[2],0);if not x then return nil end;points[#points+1]={x,y}
 end;return points
end
-- Hoist registration uses a relative native projection around the same floor
-- socket as the pole. Re-evaluate after rendering/resize, not just model load.
function N.FlagSocket(engine,a,aspect,flagScale)
 if not a or not a.ready or a.awaitRegistration or not a.position then return end
 local p=a.position;local function project(r,d,h)local x,y,z=N.World(engine.shot,r,d,h);return N.ProjectNative(a.renderScene or engine.frame,engine.shot,x,y,z)end
 local fu,fv=project(p[1],p[2],p[3]);local tu,tv,mode=project(p[1],p[2],p[3]+a.top*.98)
 local eu=project(p[1]+1.55,p[2],p[3]+a.top*.98)
 if not fu or not tu or not eu then return end
 local width=math.abs(eu-tu);if width<.005 or width>.4 then return end
 width=width*clamp(finite(flagScale)and flagScale or 1,.05,5)
 local height=width*(aspect or 16/9)/(256/163)
 local u,v=tu,tv
 return{u-width*.015,v-height*.035,width,height},{hoist={u,v},foot={fu,fv},mode=mode}
end
local function cubic(p,q)
 local a,b=1-q,q;local w={a*a*a,3*a*a*b,3*a*b*b,b*b*b};local x,y,z=0,0,0
 for i=1,4 do x=x+p[i][1]*w[i];y=y+p[i][2]*w[i];z=z+p[i][3]*w[i]end
 return x,y,z
end
function N.Path(segments)
 if type(segments)~='table'or #segments<1 or #segments>4 then return nil,'Path must have 1-4 authored curves'end
 local path={samples={},length=0};local previous
 for index,p in ipairs(segments)do
  if type(p)~='table'or #p~=4 then return nil,'Four control points required'end
  for _,v in ipairs(p)do if type(v)~='table'or not finite(v[1])or not finite(v[2])or not finite(v[3])then return nil,'Invalid point'end end
  if previous then local gap=sqrt((p[1][1]-previous.x)^2+(p[1][2]-previous.y)^2+(p[1][3]-previous.z)^2);if gap>.001 then return nil,'Disconnected path'end end
  for i=index==1 and 0 or 1,32 do
   local x,y,z=cubic(p,i/32)
   if previous then path.length=path.length+sqrt((x-previous.x)^2+(y-previous.y)^2+(z-previous.z)^2)end
   local row={x=x,y=y,z=z,distance=path.length};path.samples[#path.samples+1]=row;previous=row
  end
 end
 if path.length<.001 then return nil,'Stationary path'end
 return path
end
function N.Sample(path,q)
 local target=clamp(q,0,1)*path.length;local rows=path.samples;local lo,hi=1,#rows
 while lo<hi do local m=math.floor((lo+hi)/2);if rows[m].distance<target then lo=m+1 else hi=m end end
 local i=math.max(2,lo);local a,b=rows[i-1],rows[i];local span=b.distance-a.distance;local t=span>.000001 and(target-a.distance)/span or 0
 return a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t,a.z+(b.z-a.z)*t,b.x-a.x,b.y-a.y,b.z-a.z
end
function N.Pace(t,duration)
 -- Integrate a short speed ramp. Frame cadence cannot change travel duration.
 duration=math.max(2,duration);t=clamp(t,0,duration);local a=math.min(.65,duration*.15);local distance,speed
 local function integral(q)return q^3-.5*q^4 end
 local function ease(q)return q*q*(3-2*q)end
 if t<a then local q=t/a;distance=a*integral(q);speed=ease(q)
 elseif t<=duration-a then distance=t-a*.5;speed=1
 else local q=(duration-t)/a;distance=duration-a-a*integral(q);speed=ease(q)end
 return distance/(duration-a),speed/(duration-a)
end
-- These extents use the same explicit center/rotation as Place. No implicit
-- animation-dependent center is allowed to move the model away from this box.
function N.Footprint(shot,a)
 if not a.ready or not a.bounds or not a.position then return end
 if a.collider then if a.collider.enabled==false then return end;return ns.WardenSceneObjectControls.LocalBox(shot,a,a.collider)end
 if a.spec.collision==false then return end
 if a.spec.collisionRadius and a.spec.collisionRadius>0 then
  local radius=a.spec.collisionRadius*(a.scale/(a.editorBaseScale or a.scale));local p=a.position
  return{id=a.id,left=p[1]-radius,right=p[1]+radius,near=p[2]-radius,far=p[2]+radius}
 end
 return ns.WardenSceneObjectControls.LocalBox(shot,a,{})
end
function N.CheckPath(path,nav)
 if not nav then return true end
 local radius=nav.radius or .3;local boundary=nav.boundary;local checks=0;local polygon=nav.polygon;local orientation=1
 if polygon then local area=0;for i,a in ipairs(polygon)do local b=polygon[i%#polygon+1];area=area+a[1]*b[2]-a[2]*b[1]end;orientation=area<0 and-1 or 1 end
 local function point(x,y,z)
  checks=checks+1;if checks>4096 then return false,'Route validation budget exceeded'end
  if nav.ground and math.abs(z-(nav.floor or 0))>.015 then return false,'Ground route leaves its floor'end
  if boundary and(x-radius<boundary[1]or y-radius<boundary[2]or x+radius>boundary[3]or y+radius>boundary[4])then return false,'Route leaves authored floor'end
  if polygon then for i,a in ipairs(polygon)do local b=polygon[i%#polygon+1];local dx,dy=b[1]-a[1],b[2]-a[2]
   if(dx*(y-a[2])-dy*(x-a[1]))*orientation<radius*sqrt(dx*dx+dy*dy)then return false,'Route leaves registered floor'end
  end end
  for _,b in ipairs(nav.obstacles or{})do
   if b.circle then
    if(x-b.x)^2+(y-b.y)^2<(b.radius+radius)^2-1e-8 then return false,'Route blocked by '..b.id end
   elseif b.centerX then
    local dx,dy=x-b.centerX,y-b.centerY;local lx,ly=dx*b.cos+dy*b.sin,-dx*b.sin+dy*b.cos
    if math.abs(lx)<b.halfX+radius and math.abs(ly)<b.halfY+radius then return false,'Route blocked by '..b.id end
   elseif x>b.left-radius and x<b.right+radius and y>b.near-radius and y<b.far+radius then return false,'Route blocked by '..b.id end
  end
  return true
 end
 for i,p in ipairs(path.samples)do
  local a=path.samples[math.max(1,i-1)];local span=sqrt((p.x-a.x)^2+(p.y-a.y)^2+(p.z-a.z)^2)
  local count=math.max(1,math.ceil(span/.05));if checks+count>4096 then return false,'Route validation budget exceeded'end
  for step=1,count do local q=step/count;local ok,why=point(a.x+(p.x-a.x)*q,a.y+(p.y-a.y)*q,a.z+(p.z-a.z)*q);if not ok then return false,why end end
 end
 return true
end
local function usableBounds(actor)
 local a,b,c,d,e,f=N.Bounds(actor)
 if a and d>a and e>b and f>c then return{a,b,c,d,e,f}end
end
-- Small visibility graph over the existing floor/prop bounds. Temporary click
-- planning only: at most 146 nodes, no retry queue, and no gameplay movement API.
function N.WalkPath(from,x,y,nav)
 if not from or not finite(x)or not finite(y)then return nil,'Invalid ground point'end
 local function line(a,b)
  return N.Path({{{a[1],a[2],0},{a[1]+(b[1]-a[1])/3,a[2]+(b[2]-a[2])/3,0},{a[1]+2*(b[1]-a[1])/3,a[2]+2*(b[2]-a[2])/3,0},{b[1],b[2],0}}})
 end
 local start,goal={from[1],from[2]},{x,y};local direct=line(start,goal)
 if not direct then return nil,'Already at that spot'end
 local goalOK,goalWhy=N.CheckPath({samples={{x=x,y=y,z=0}},length=0},nav);if not goalOK then return nil,goalWhy end
 if N.CheckPath(direct,nav)then return direct end
 local nodes={start,goal};local margin=(nav.radius or .3)+.025
 for _,b in ipairs(nav.obstacles or{})do
  if #nodes+4>146 then return nil,'Scene navigation budget'end
  if b.centerX then for _,p in ipairs({{-1,-1},{1,-1},{-1,1},{1,1}})do local x,y=p[1]*(b.halfX+margin),p[2]*(b.halfY+margin);nodes[#nodes+1]={b.centerX+x*b.cos-y*b.sin,b.centerY+x*b.sin+y*b.cos}end
  else for _,p in ipairs({{b.left-margin,b.near-margin},{b.right+margin,b.near-margin},{b.left-margin,b.far+margin},{b.right+margin,b.far+margin}})do nodes[#nodes+1]=p end end
 end
 -- Straight visibility edges use analytic segment clearance. Building and
 -- sampling a 129-point spline for every graph edge caused needless allocation
 -- when the owner populated the room with many native objects.
 local allowed={}
 for i,p in ipairs(nodes)do allowed[i]=N.CheckPath({samples={{x=p[1],y=p[2],z=0}},length=0},nav)end
 local function edge(i,j)
  if not allowed[i]or not allowed[j]then return false end
  local a,b=nodes[i],nodes[j];local dx,dy=b[1]-a[1],b[2]-a[2];local len=dx*dx+dy*dy;local radius=nav.radius or .3
  for _,box in ipairs(nav.obstacles or{})do
   if box.circle then
    local q=len>0 and clamp(((box.x-a[1])*dx+(box.y-a[2])*dy)/len,0,1)or 0
    if(a[1]+dx*q-box.x)^2+(a[2]+dy*q-box.y)^2<(box.radius+radius)^2-1e-8 then return false end
   else
    local low,high=0,1;local intersects=true
    local ax,ay,ex,ey=a[1],a[2],b[1],b[2]
    if box.centerX then local x,y=ax-box.centerX,ay-box.centerY;ax,ay=x*box.cos+y*box.sin,-x*box.sin+y*box.cos;x,y=ex-box.centerX,ey-box.centerY;ex,ey=x*box.cos+y*box.sin,-x*box.sin+y*box.cos end
    for axis=1,2 do local origin=axis==1 and ax or ay;local delta=axis==1 and ex-ax or ey-ay
     local left=box.centerX and(axis==1 and-box.halfX-radius or-box.halfY-radius)or(axis==1 and box.left-radius or box.near-radius)
     local right=box.centerX and(axis==1 and box.halfX+radius or box.halfY+radius)or(axis==1 and box.right+radius or box.far+radius)
     if math.abs(delta)<1e-10 then if origin<=left or origin>=right then intersects=false;break end
     else local one,two=(left-origin)/delta,(right-origin)/delta;if one>two then one,two=two,one end;low=math.max(low,one);high=math.min(high,two);if low>=high then intersects=false;break end end
    end
    if intersects then return false end
   end
  end
  return sqrt(len)
 end
 local distances,previous,done={[1]=0},{},{};local cache={};local reached
 for _=1,#nodes do
  local at;for i=1,#nodes do if not done[i]and distances[i]and(not at or distances[i]<distances[at])then at=i end end
  if not at then break end;if at==2 then reached=true;break end;done[at]=true
  for i=2,#nodes do if i~=at and not done[i]then
   local key=math.min(i,at)*256+math.max(i,at);local length=cache[key]
   if length==nil then length=edge(at,i);cache[key]=length end
   if length and(not distances[i]or distances[at]+length<distances[i])then distances[i]=distances[at]+length;previous[i]=at end
  end end
 end
 if not reached then return nil,'No clear walk to that spot'end
 local points={};local at=2;while at do table.insert(points,1,nodes[at]);at=previous[at]end
 local out={samples={},length=0};for i,p in ipairs(points)do
  if i>1 then local a=points[i-1];out.length=out.length+sqrt((p[1]-a[1])^2+(p[2]-a[2])^2)end
  out.samples[i]={x=p[1],y=p[2],z=0,distance=out.length}
 end
 if not N.CheckPath(out,nav)then return nil,'No clear walk to that spot'end
 return out
end
-- Scene-only body clearance; no game-unit movement, evidence or saved state.
function N.IsPerson(a)
 local s=a and a.spec
 return s and not s.fileID and not s.flying and(s.controlled or s.socialVisitor or s.unit or s.appearance or s.npcID and not s.reward)and true or false
end
function N.PersonRadius(a)
 return clamp((a.spec.navigationRadius or(a.spec.wildlife and .18 or .4))*(a.scale and a.authoredBaseScale and a.scale/a.authoredBaseScale or 1),a.spec.wildlife and .12 or .2,1.2)
end
N.WALK_SPEED=1.3
function N.GroundWalker(a)return N.IsPerson(a)or a and a.spec and a.spec.wildlife and not a.spec.flying end
local function personPresent(a)
 return N.IsPerson(a)and a.ready and a.position and not(a.retired or a.failed or a.editorHidden or a.sceneHidden or a.awaitRegistration or a.awaitSpawn)
end
function N.PeopleNavigation(nav,engine,a)
 local base=nav.base or nav;local out={};for k,v in pairs(base)do out[k]=v end
 out.base=base;out.obstacles={};for _,b in ipairs(base.obstacles or{})do out.obstacles[#out.obstacles+1]=b end
 if not N.GroundWalker(a)then return out end
 for _,other in ipairs(engine.order)do if other~=a and personPresent(other)then
  -- Use the same circular clearance as the swept movement test. Inflated
  -- squares stranded actors outside actual body contact at their corners.
  local radius=math.max(.01,N.PersonRadius(other)+N.PersonRadius(a)+.06-(out.radius or .3))
  local function box(x,y,suffix)out.obstacles[#out.obstacles+1]={id='character/'..other.id..suffix,left=x-radius,right=x+radius,near=y-radius,far=y+radius,circle=true,x=x,y=y,radius=radius}end
  box(other.position[1],other.position[2],'')
  local path=other.route and other.route.path;local goal=path and path.samples[#path.samples]
  if goal and(goal.x-other.position[1])^2+(goal.y-other.position[2])^2>.25 then box(goal.x,goal.y,'/destination')end
 end end
 return out
end
function N.CanStep(engine,a,from,to)
 if not N.GroundWalker(a)or not from then return true end
 local dx,dy=to[1]-from[1],to[2]-from[2];local length=dx*dx+dy*dy
 for _,other in ipairs(engine.order)do if other~=a and personPresent(other)then
  local p=other.position
  if math.min(from[3],to[3])<p[3]+(other.top or 1.85)and math.max(from[3],to[3])+(a.top or 1.85)>p[3]then
   local radius=N.PersonRadius(a)+N.PersonRadius(other)+.06
   local before=(from[1]-p[1])^2+(from[2]-p[2])^2;local after=(to[1]-p[1])^2+(to[2]-p[2])^2
   local q=length>1e-12 and clamp(((p[1]-from[1])*dx+(p[2]-from[2])*dy)/length,0,1)or 0
   local closest=(from[1]+dx*q-p[1])^2+(from[2]+dy*q-p[2])^2
   if closest<radius*radius-1e-8 and not(before<radius*radius and after>before+1e-8 and q<=1e-5)then return false,other end
  end
 end end
 return true
end

function N.Create(parent,shot)
 local s={shot=shot,actors={},order={},errors={},clock=0,loading=false,baseLayer='native',views={},metrics={updates=0,loads=0,moves=0,animationChanges=0},status='not opened'}
 if N.IsSimulator()then s.status='SIMULATOR: native 3D unavailable';s.unsupported='simulator';return s end
 local ok,scene=pcall(CreateFrame,'ModelScene',nil,parent)
 if not ok or not scene or type(scene.CreateActor)~='function'then s.unsupported='ModelScene unavailable';s.status=s.unsupported;return s end
 s.frame=scene;scene:SetAllPoints(parent);scene:EnableMouse(false);N.Call(scene,'SetDrawLayer','ARTWORK');N.Call(scene,'SetAllowOverlappedModels',true)
 local accepted,camera=N.Camera(scene,shot.position[1],shot.position[2],shot.position[3],shot.target[1],shot.target[2],shot.target[3],shot.fov)
 s.camera=camera;if not accepted then scene:Hide();s.frame=nil;s.unsupported='Native camera unavailable';s.status=s.unsupported;return s end
 function s:Error(slot,reason)
  slot.status=reason;slot.failed=true;slot.route=nil;N.Call(slot.actor,'Hide');if slot.probe then slot.probe:Hide()end
  self.errors[#self.errors+1]={id=slot.id,reason=tostring(reason)};if #self.errors>12 then table.remove(self.errors,1)end
 end
 function s:RenderFrames()
  local out={scene};for _,view in pairs(self.views)do out[#out+1]=view end;return out
 end
 -- Keep interacting furniture/residents together by default. An explicit
 -- editor pass change uses a camera-matched viewport, not fake actor z-order.
 function s:SetLayer(a,layer)
  if not a then return false,'Missing actor'end
  a.requestedRenderLayer=layer
  -- The wall display needs its mesh below the flat badge artwork, with the
  -- walking character/other props above both. Retained "native" shelf layouts
  -- resolve to this pass without rewriting the owner's saved placement.
  if a.spec.showcaseSupport and layer==self.baseLayer and self.layers and self.layers['shelf-props']then layer='shelf-props'end
  layer=N.PropRenderLayer(self,a,layer)
  if layer==(a.renderLayer or self.baseLayer)then return true end
  if not self.layers or not self.layers[layer]then return false,'Unknown scene layer'end
  local view=layer==self.baseLayer and scene or self.views[layer]
  if not view then
   local good;good,view=pcall(CreateFrame,'ModelScene',nil,self.layers[layer]);if not good or not view then return false,'Native layer viewport unavailable'end
   view:SetAllPoints();view:EnableMouse(false);view:SetFrameLevel(self.layers[layer]:GetFrameLevel());N.Call(view,'SetDrawLayer','ARTWORK');N.Call(view,'SetAllowOverlappedModels',true)
   local lens=self.viewShot or shot;local ok=N.Camera(view,lens.position[1],lens.position[2],lens.position[3],lens.target[1],lens.target[2],lens.target[3],lens.fov);view.firesideViewShot=self.viewShot
   if not ok then view:Hide();return false,'Layer camera unavailable'end
   self.views[layer]=view
  end
  a.variants=a.variants or{};a.variants[a.renderLayer or self.baseLayer]=a.actor
  local actor=a.variants[layer]
  if not actor then N.serial=(N.serial or 0)+1;local ok;ok,actor=N.Call(view,'CreateActor','WardenWorldActor'..N.serial,'ModelSceneActorTemplate');if not ok or not actor then return false,'Native layer actor unavailable'end;a.variants[layer]=actor end
  N.Call(a.actor,'Hide');N.Call(a.actor,'ClearModel');a.actor=actor;a.renderLayer=layer;a.renderScene=view
  N.Call(actor,'SetUseCenterForOrigin',false,false,false);N.Call(actor,'SetNormalizedScaleAggressiveness',0);N.Call(actor,'SetRequestedScale',1);N.Call(actor,'SetScale',1);N.Call(actor,'SetAlpha',0);N.Call(actor,'Show')
  local ok,result
  if a.spec.unit=='player'then ok,result=N.Call(actor,'SetModelByUnit','player',true,true)
  elseif a.spec.fileID then ok,result=N.Call(actor,'SetModelByFileID',a.spec.fileID)
  elseif a.displayID then ok,result=N.Call(actor,'SetModelByCreatureDisplayID',a.displayID)
  else ok=true;a.requested=false end
  if not ok or result==false then self:Error(a,'Model unavailable in selected layer');return false,a.status end
  a.ready=false;a.failed=nil;a.wait=0;a.animation=nil;a.lastAnimationRate=nil;a.route=nil;a.status='loading selected layer';self.loading=true
  if a.probe then a.probe:Show()end
  local paused=self.paused;self:Lighting(self.lightState or'day',self.interior);self:Show(not self.hidden);self:Pause(paused);return true
 end
 function s:Add(spec)
  if type(spec)~='table'or type(spec.id)~='string'or spec.id==''then return nil,'An authored actor ID is required'end
  if self.actors[spec.id]then return self.actors[spec.id]end
  if #self.order>=N.MAX_ACTORS then return nil,'Scene actor budget'end
  if not(spec.unit=='player'or id(spec.fileID)or id(spec.displayID)or id(spec.npcID)or spec.appearance and id(spec.appearance.raceID)and(spec.appearance.sex==2 or spec.appearance.sex==3))then return nil,'A real installed model reference is required'end
  N.serial=(N.serial or 0)+1;local yes,actor=N.Call(scene,'CreateActor','WardenWorldActor'..N.serial,'ModelSceneActorTemplate')
  if not yes or not actor then yes,actor=N.Call(scene,'CreateActor','WardenWorldActor'..N.serial,'')end
  if not yes or not actor then return nil,'Native actor creation failed'end
  local a={id=spec.id,actor=actor,spec=spec,engine=self,status='loading',wait=0,capabilities={},scale=spec.scale or 1,shadow=spec.shadow,shadowLayer=spec.shadowLayer,seatHeightOffset=spec.seatHeightOffset}
  self.actors[a.id]=a;self.order[#self.order+1]=a;self.loading=true;self.metrics.loads=self.metrics.loads+1
  -- Load offscreen until the real bounds, scale and support are established.
  N.Call(actor,'SetUseCenterForOrigin',false,false,false);N.Call(actor,'SetNormalizedScaleAggressiveness',0);N.Call(actor,'SetRequestedScale',1);N.Call(actor,'SetScale',1);N.Call(actor,'SetAlpha',0);N.Call(actor,'Show')
  if spec.appearance then
   a.displayID=N.BodyDisplay(spec.appearance)
   if not a.displayID then self:Error(a,'No installed race/sex body reference for this capture');return a end
  end
  if spec.fileID then
   local loaded,result=N.Call(actor,'SetModelByFileID',spec.fileID);if not loaded or result==false then self:Error(a,'Installed object request rejected')end
  end
  if not spec.fileID or spec.probeObject then
   local good,probe=pcall(CreateFrame,spec.appearance and'DressUpModel'or'PlayerModel',nil,parent)
   if not good or not probe then self:Error(a,'Native animation/identity probe unavailable');return a end
   a.probe=probe;probe:SetSize(1,1);probe:SetPoint('TOPLEFT');probe:SetAlpha(0);probe:EnableMouse(false);N.Call(probe,'SetModelAlpha',0);N.Call(probe,'SetKeepModelOnHide',true)
   N.Call(probe,'SetScript','OnModelLoaded',function()if not a.failed then a.probeLoadEvent=true end end);probe:Show()
   if spec.unit=='player'then
    a.requested=true;local accepted,result=N.Call(actor,'SetModelByUnit','player',true,true)
    if not accepted or result==false then self:Error(a,'Current character model unavailable on this client')end
   elseif spec.displayID or a.displayID then
    a.displayID=spec.displayID or a.displayID;a.requested=true;local accepted,result=N.Call(actor,'SetModelByCreatureDisplayID',a.displayID)
    if not accepted or result==false then self:Error(a,'Native creature request rejected')end
   end
   local loaded,result
   if spec.fileID then loaded,result=N.Call(probe,'SetModel',spec.fileID)
   elseif spec.unit=='player'then loaded,result=N.Call(probe,'SetUnit','player')
   elseif spec.appearance then loaded,result=N.Call(probe,'SetDisplayInfo',a.displayID)
   else loaded,result=N.Call(probe,spec.displayID and'SetDisplayInfo'or'SetCreature',spec.displayID or spec.npcID,0)end
   if not loaded or result==false then self:Error(a,'Installed creature lookup rejected')end
  end
  return a
 end
 -- Two remembered-visitor slots are reused for the life of the scene. Retiring
 -- clears all installed models/probes, never leaves a hidden retry queue.
 function s:Retire(a)
  if not a then return end;a.retired=true;a.ready=false;a.route=nil;a.seating=nil;a.pendingInteraction=nil;a.awaitSupport=nil;a.awaitRegistration=nil
  for _,actor in pairs(a.variants or{[self.baseLayer]=a.actor})do N.Call(actor,'Hide');N.Call(actor,'ClearModel')end
  if a.probe then a.probe:Hide();N.Call(a.probe,'ClearModel')end
 end
 function s:Reuse(spec)
  local a=self.actors[spec.id];if not a then return self:Add(spec)end
  self:Retire(a)
  -- Reuse the original viewport slot; do not accumulate actors or probe frames.
  local reusable=a.probe;local fresh={reusableProbe=reusable,id=a.id,actor=a.actor,spec=spec,engine=self,status='loading remembered appearance',wait=0,capabilities={},scale=1,variants=a.variants,renderLayer=a.renderLayer,renderScene=a.renderScene}
  for k in pairs(a)do a[k]=nil end;for k,v in pairs(fresh)do a[k]=v end
  N.Call(a.actor,'SetAlpha',0);N.Call(a.actor,'Show');self.loading=true;self.metrics.loads=self.metrics.loads+1
  -- Add's probe setup is shared through a temporary ID-free slot constructor.
  local probe=a.reusableProbe
  if not probe then local ok;ok,probe=pcall(CreateFrame,'DressUpModel',nil,parent);if not ok or not probe then self:Error(a,'Captured appearance probe unavailable');return a end end
  a.probe=probe;a.reusableProbe=probe;probe:SetSize(1,1);probe:SetPoint('TOPLEFT');probe:SetAlpha(0);probe:EnableMouse(false);N.Call(probe,'SetModelAlpha',0);N.Call(probe,'SetKeepModelOnHide',true)
  N.Call(probe,'SetScript','OnModelLoaded',function()a.probeLoadEvent=true end);probe:Show()
  local ok,result
  a.displayID=N.BodyDisplay(spec.appearance)
  if not a.displayID then self:Error(a,'No installed race/sex body reference for this capture');return a end
  a.requested=true;ok,result=N.Call(a.actor,'SetModelByCreatureDisplayID',a.displayID)
  if not ok or result==false then self:Error(a,'Captured body model request rejected');return a end
  ok,result=N.Call(probe,'SetDisplayInfo',a.displayID)
  if not ok or result==false then self:Error(a,'Captured body unavailable on this client')end
  return a
 end
 -- Editor objects reuse 24 stable slots, including after delete/undo/reload.
 function s:LoadProp(spec)
  if not id(spec.fileID)or not spec.custom then return nil,'Invalid placed object'end
  local a=self.actors[spec.id];if not a then return self:Add(spec)end
  self:Retire(a)
  local fresh={id=a.id,actor=a.actor,probe=a.probe,spec=spec,engine=self,status='loading placed object',wait=0,capabilities={},scale=1,variants=a.variants,renderLayer=a.renderLayer,renderScene=a.renderScene}
  for k in pairs(a)do a[k]=nil end;for k,v in pairs(fresh)do a[k]=v end
  N.Call(a.actor,'SetAlpha',0);N.Call(a.actor,'SetScale',1);N.Call(a.actor,'SetRequestedScale',1);N.Call(a.actor,'Show')
  local ok,result=N.Call(a.actor,'SetModelByFileID',spec.fileID)
  if not ok or result==false then self:Error(a,'Installed object request rejected')end
  if spec.probeObject and a.probe then
   a.probeReady=false;a.probeLoadEvent=false;a.probe:Show()
   N.Call(a.probe,'SetScript','OnModelLoaded',function()if not a.failed then a.probeLoadEvent=true end end)
   local accepted,value=N.Call(a.probe,'SetModel',spec.fileID);if not accepted or value==false then self:Error(a,'Installed object animation probe rejected')end
  end
  self.loading=true;self.metrics.loads=self.metrics.loads+1;return a
 end
 function s:RefreshPlayer(a)
  if not a or a.spec.unit~='player'then return false end
  -- Native active bounds include the current pose/scale. A seated refresh
  -- must not size the standing body from a shorter, already scaled silhouette.
  N.Call(a.actor,'SetRequestedScale',1);N.Call(a.actor,'SetScale',1);N.Call(a.actor,'SetAnimation',0,0,1,0)
  local ok,result=N.Call(a.actor,'SetModelByUnit','player',true,true)
  if not ok or result==false then self:Error(a,'Current character model unavailable on this client');return false end
  if a.position then a.spec.at={unpack(a.position)};a.spec.floorUV=nil;a.spec.yaw=a.yaw end
  a.retired=nil;a.editorCanonicalApplied=nil;a.ready=false;a.failed=nil;a.wait=0;a.probeReady=false;a.probeLoadEvent=false;a.route=nil;a.restStage=nil;a.animation=nil;a.lastAnimationRate=nil;a.status='loading current character';self.loading=true
  N.Call(a.actor,'SetAlpha',0)
  if a.probe then a.probe:Show();local good,value=N.Call(a.probe,'SetUnit','player');if not good or value==false then self:Error(a,'Current character animation probe unavailable');return false end end
  return true
 end
 function s:Place(a,right,depth,height,yaw,pitch)
  if not a or not a.ready then return false end
  if a.spec.worldYaw then a.worldYaw=a.spec.worldYaw;N.Call(a.actor,'SetYaw',a.worldYaw)
  elseif yaw then local p,t=self.shot.position,self.shot.target;local base=math.atan2(t[2]-p[2],t[1]-p[1])-pi*.5;a.worldYaw=base+yaw;N.Call(a.actor,'SetYaw',a.worldYaw)end
  local angle=a.worldYaw or 0;local cx=(a.bounds[1]+a.bounds[4])*.5*a.scale;local cy=(a.bounds[2]+a.bounds[5])*.5*a.scale
  local x,y,z=N.World(self.shot,right,depth,height+(a.groundOffset or 0)-a.bounds[3]*a.scale)
  x,y=x-cos(angle)*cx+sin(angle)*cy,y-sin(angle)*cx-cos(angle)*cy
  -- Actor translation is model-scaled. Keep authoring/collision coordinates in
  -- world units and convert only at this native boundary. Previously a small
  -- candle's desk-height translation shrank with its model scale.
  local scale=math.max(.00001,a.scale);local nx,ny,nz=x/scale,y/scale,z/scale
  local good=N.Call(a.actor,'SetPosition',nx,ny,nz);a.nativeOrigin={x,y,z};a.nativePosition={nx,ny,nz}
  if a.spec.flying then N.Call(a.actor,'SetPitch',pitch or 0)
  elseif a.uprightActor~=a.actor then a.uprightPitch=N.Call(a.actor,'SetPitch',0);a.uprightRoll=N.Call(a.actor,'SetRoll',0);a.uprightActor=a.actor end
  a.position={right,depth,height};a.yaw=yaw or a.yaw;a.pitch=pitch or 0;self.metrics.moves=self.metrics.moves+1;if ns.WardenCanonicalPlayer then ns.WardenCanonicalPlayer.Update(self,a)end;return good
 end
 function s:Animate(a,animation,speed,offset)
  if not a or not a.ready or a.capabilities[animation]~=true then return false,'Animation unconfirmed'end
  speed=speed or 1
  -- Native animation already owns its clock. Restarting a walk with a new
  -- absolute offset every UI frame prevents some creature rigs from blending.
  if (not offset or offset==0)and a.animation==animation and math.abs(speed-(a.lastAnimationRate or 1))<.15 then return true end
  -- Rate changes must preserve the current native pose phase. Restarting the
  -- same walk at offset zero on acceleration produced a visible hitch.
  local phase=offset or 0
  if a.animation==animation and(not offset or offset==0)then phase=a.animationClock or 0 end
  local yes,result
  if phase>0 then yes,result=N.Call(a.actor,'SetAnimation',animation,0,speed,phase)
  else yes,result=N.Call(a.actor,'SetAnimation',animation,0,speed)end
  if not yes or result==false then self:Error(a,'Native animation rejected');return false end
  if a.animation==animation and phase>0 then self.metrics.phasePreserved=(self.metrics.phasePreserved or 0)+1 end
  a.animation=animation;a.animationClock=phase;a.lastAnimationRate=speed;self.metrics.animationChanges=(self.metrics.animationChanges or 0)+1;return true
 end
 function s:Route(a,path,duration,animation,nav)
  if not a or not a.ready or not path or a.capabilities[animation]~=true then return false,'Loaded actor and supported motion required'end
  if nav and nav.continuous and a.position then local p,q=a.position,path.samples[1]
   if sqrt((p[1]-q.x)^2+(p[2]-q.y)^2+(p[3]-q.z)^2)>.15 then return false,'Route start differs from resident position'end
  end
  if nav and nav.ground and N.GroundWalker(a)then nav=N.PeopleNavigation(nav,self,a)end
  local clear,why=N.CheckPath(path,nav)
  if not clear and nav and nav.ground and N.GroundWalker(a)then local goal=path.samples[#path.samples];path,why=N.WalkPath(a.position,goal.x,goal.y,nav);clear=path~=nil end
  if not clear then return false,why end
  local _,_,_,dx,dy=N.Sample(path,0);local target=math.atan2(dy,dx);local start=a.yaw or target
  local delta=(target-start+pi)%(2*pi)-pi
  a.route={path=path,duration=math.max(2,duration),elapsed=0,animation=animation,clock=0,nav=nav and(nav.base or nav),avoidAttempts=0,turn=nav and nav.ground and math.abs(delta)>.35 and{elapsed=0,duration=.55,from=start,delta=delta}or nil};return true
 end
 function s:Lighting(state,interior)
  local colors={dawn={.82,.70,.57},day={1,1,1},dusk={.92,.63,.39},night={.42,.53,.75}};local c=colors[state]or colors.day
  self.lightState,self.interior=state,interior
  local r=self.lightOverride;self.lightCapabilities={}
  for _,view in ipairs(self:RenderFrames())do
   N.Call(view,'SetLightAmbientColor',c[1]*(interior and .58 or .7),c[2]*(interior and .58 or .7),c[3]*(interior and .58 or .7))
   N.Call(view,'SetLightDiffuseColor',c[1]*.85,c[2]*.85,c[3]*.85);N.Call(view,'SetLightDirection',-.7,-.4,-1)
   local types=Enum and Enum.ModelLightType
   if types and types.Directional~=nil then N.Call(view,'SetLightType',types.Directional)end
   self.lightCapabilities=ns.WardenNativeEffects.ApplyLight(view,r,self.shot)
  end
 end
 function s:DressCaptured(a)
  if not a.spec.appearance or not a.probe then return end
  a.gearAttempts=(a.gearAttempts or 0)+1;a.dressedItems=a.dressedItems or 0
  -- Keep the baked body material. Undress/recompositing an offline base body
  -- can erase its skin. Only standalone geometry can safely be reconstructed;
  -- chest/leg/boot texture layers remain generic rather than falsely exact.
  local standalone={[1]=true,[3]=true,[15]=true,[16]=true,[17]=true}
  a.gearAppliedSlots=a.gearAppliedSlots or{};a.genericClothingSlots={}
  for i,row in ipairs(a.spec.gear or{})do if i<=19 and type(row)=='table'and(row[2]=='present'or row[2]=='pending')and id(row[3])then
   local slot=row[1]
   if not standalone[slot]then a.genericClothingSlots[#a.genericClothingSlots+1]=slot
   elseif not a.gearAppliedSlots[slot]then
    local item=row[4]~=false and row[4]or('item:'..row[3]);local hand=slot==16 and'MainHandSlot'or slot==17 and'SecondaryHandSlot'or nil
    local tried=N.Call(a.probe,'TryOn',item,hand)
    local good,info=N.Call(a.probe,'GetItemTransmogInfo',slot)
    if tried and good and info then
     local ok,result=N.Call(a.actor,'SetItemTransmogInfo',info,slot)
     if ok and(result==true or result==nil or result==0)then a.dressedItems=a.dressedItems+1;a.gearAppliedSlots[slot]=true end
    end
   end
  end end
 end
 function s:Tick(dt,animate)
  dt=clamp(dt,0,.25);self.metrics.updates=self.metrics.updates+1;self.clock=self.clock+dt;self.loading=false
  for _,a in ipairs(self.order)do
   if a.ready and not a.retired and not a.failed and a.spec.fileID and not a.spec.showcaseSupport then
    local requested=a.requestedRenderLayer or self.baseLayer
    local desired=N.PropRenderLayer(self,a,requested)
    if desired~=(a.renderLayer or self.baseLayer)then self:SetLayer(a,requested)end
   end
   if not a.retired and not a.failed and not a.ready then
    a.wait=a.wait+dt;self.loading=true
    if a.probe then
     local yes,display=N.Call(a.probe,'GetDisplayInfo');local hasFile,file=N.Call(a.probe,'GetModelFileID')
     a.probeDisplayID=yes and display or nil;a.probeModelFileID=hasFile and file or nil
     if not a.spec.fileID and yes and id(display)and not a.requested then
      if a.spec.displayID and display~=a.spec.displayID then self:Error(a,'Mismatched creature display')else
       a.displayID=display;a.requested=true;local good,result=N.Call(a.actor,'SetModelByCreatureDisplayID',display)
       if not good or result==false then self:Error(a,'Native creature request rejected')end
      end
     end
     if a.spec.fileID then
      -- The actor's own loaded bounds permit a static book even on clients
      -- without object animation introspection. Unsupported poses stay false.
      a.probeReady=a.probeLoadEvent==true or hasFile and file==a.spec.fileID or a.wait>=2
     elseif a.spec.unit=='player'then
      a.probeReady=a.probeLoadEvent==true or hasFile and id(file)==true
     elseif yes and id(display)and a.displayID then
      if display~=a.displayID then self:Error(a,'Mismatched creature display')
      else a.probeReady=a.probeLoadEvent==true or hasFile and id(file)==true end
     end
    end
    local yes,loaded=N.Call(a.actor,'IsLoaded');a.actorLoaded=yes and loaded==true;local b=a.actorLoaded and usableBounds(a.actor)
    if not b and a.actorLoaded and a.spec.effect then local ok,file=N.Call(a.actor,'GetModelFileID');if ok and file==a.spec.fileID then b={-.5,-.5,0,.5,.5,1};a.effectBoundsSource='authored unit extent; emitter has no usable native geometry bounds'end end
    if not a.failed and b and(not a.probe or a.probeReady)then
     b=N.StandingPlayerBounds(a,b);a.bounds=b;local w=math.max(b[4]-b[1],b[5]-b[2]);local h=b[6]-b[3]
     a.scale=a.spec.width and a.spec.width/w or a.spec.height and a.spec.height/h or a.spec.scale or 1
     if a.spec.maxWidth then a.scale=math.min(a.scale,a.spec.maxWidth/w)end
     a.authoredBaseScale=a.scale;a.scale=a.scale*(a.spec.sizeMultiplier or 1)
     N.Call(a.actor,'SetRequestedScale',a.scale);N.Call(a.actor,'SetScale',a.scale)
     a.ready=true;a.status='loaded';a.top=h*a.scale
     if a.probe then
      for _,animation in ipairs(a.spec.animations or{0,4})do local good,present=N.Call(a.probe,'HasAnimation',animation);a.capabilities[animation]=good and present==true end
      a.probe:Hide()
     end
     -- DressUpModel resolves native item appearances; the scene actor consumes
     -- its actual ItemTransmogInfo. No invented transmog IDs or own-unit gear.
     if a.spec.appearance then a.gearAttempts=0;self:DressCaptured(a);a.gearRetryAt=self.clock+1 end
     local p=a.spec.at or{0,0,0};self:Place(a,p[1],p[2],p[3],a.spec.yaw or 0);self:Animate(a,0,1,0)
     if self.onReady then self.onReady(a)end
     if a.effect then ns.WardenNativeEffects.Apply(a,a.effect)end
    elseif a.wait>=20 then self:Error(a,a.actorLoaded and'Creature model loaded; animation probe not ready after 20 visible seconds'or'Native model not ready after 20 visible seconds')end
   end
   if a.ready and not a.retired and a.spec.appearance and(a.gearAttempts or 0)<3 and self.clock>=(a.gearRetryAt or 0)then self:DressCaptured(a);a.gearRetryAt=self.clock+1 end
   if animate and not self.paused and a.ready and not a.retired and not a.failed then a.animationClock=(a.animationClock or 0)+dt*(a.lastAnimationRate or 1)end
   local r=animate and not a.retired and not a.failed and a.route
   if r then
    if a.spec.wildlife and ns.WardenWildlife.BeforeTick(self,a,r,dt)then
    elseif r.turn then
     local t=r.turn;t.elapsed=math.min(t.duration,t.elapsed+dt);local q=t.elapsed/t.duration;q=q*q*(3-2*q)
     self:Place(a,a.position[1],a.position[2],a.position[3],t.from+t.delta*q);self:Animate(a,0,1,0)
     if t.elapsed>=t.duration then r.turn=nil end
    else
    local elapsed=math.min(r.duration,r.elapsed+dt);local q,velocity=N.Pace(elapsed,r.duration)
    local x,y,z,dx,dy,dz=N.Sample(r.path,q);local yaw=math.atan2(dy,dx);local pitch=clamp(-math.atan2(dz,sqrt(dx*dx+dy*dy)),-.55,.55)
    local clear,other=N.CanStep(self,a,a.position,{x,y,z})
    if clear then
    r.elapsed=elapsed;r.blockedFor=0;a.collisionWait=nil
    self:Place(a,x,y,z,yaw,pitch)
    local speed=velocity*r.path.length;local stride=a.spec.stride or math.max(.1,(a.bounds[4]-a.bounds[1])*a.scale*.8)
    local rate=a.spec.flying and 1 or clamp(speed/stride,.35,2);r.clock=r.clock+dt*rate;self:Animate(a,r.animation,rate)
    if r.elapsed>=r.duration then a.route=nil;self:Animate(a,a.capabilities[97]and a.spec.sitAfter and 97 or 0,1,0);if self.onRouteEnd then self.onRouteEnd(a)end end
    else
     a.collisionWait=other and other.id;r.blockedFor=(r.blockedFor or 0)+dt;a.motionStatus='Waiting for another character';self:Animate(a,0,1)
     self.metrics.collisionWaits=(self.metrics.collisionWaits or 0)+1
     if self.clock>=(r.nextAvoidAt or 0)then
      r.nextAvoidAt=self.clock+.9;r.avoidAttempts=(r.avoidAttempts or 0)+1
      local goal=r.path.samples[#r.path.samples];local nav=r.nav and N.PeopleNavigation(r.nav,self,a)
      local path=r.avoidAttempts<=12 and nav and N.WalkPath(a.position,goal.x,goal.y,nav)
      if path then local speed=math.max(.35,r.path.length/r.duration);r.path=path;r.duration=math.max(2,path.length/speed);r.elapsed=0;r.blockedFor=0;r.stops=nil;r.pause=nil;self.metrics.collisionReplans=(self.metrics.collisionReplans or 0)+1
      elseif r.avoidAttempts>=6 then a.route=nil;a.pendingInteraction=nil;a.collisionWait=nil;a.motionStatus='Path occupied by another character';if self.onRouteBlocked then self.onRouteBlocked(a)end end
     end
    end
    end
   end
  end
 end
 function s:Pause(value)
  self.paused=value==true;for _,view in ipairs(self:RenderFrames())do N.Call(view,'SetPaused',self.paused,false)end
  for _,a in ipairs(self.order)do if a.probe then
   if not scene:IsShown()or a.retired or a.ready or a.failed then a.probe:Hide()else a.probe:Show();N.Call(a.probe,'SetModelAlpha',0)end
  end end
 end
 function s:Show(value)
  self.hidden=not value;scene:SetShown(value)
  for _,view in pairs(self.views)do local occupied=false;for _,a in ipairs(self.order)do if a.renderScene==view then occupied=true;break end end;view:SetShown(value and occupied)end
  self:Pause(not value)
  if value then for _,a in ipairs(self.order)do if a.probe and not a.retired and not a.ready and not a.failed then a.probe:Show();N.Call(a.probe,'SetModelAlpha',0)end end end
 end
 function s:Report()
  local out={version=N.VERSION,status=self.status,camera=self.camera,models={},errors=self.errors,metrics=self.metrics,visualVerification='Native visual inspection required; simulator cannot render models'}
  out.lightCapabilities=self.lightCapabilities;out.viewport={scene:GetWidth(),scene:GetHeight(),scene:GetEffectiveScale()};out.projectionSamples={}
  -- Record native projection output without guessing its units or claiming the
  -- mathematical registration surface proves final native art alignment.
  for _,sample in ipairs({{0,0,0},{1,0,0},{0,2,0},{0,0,1}})do
   local x,y,z=N.World(self.shot,unpack(sample));local good,u,v,depth=N.Call(scene,'Project3DPointTo2D',x,y,z)
   if good and finite(u)and finite(v)and finite(depth)then out.projectionSamples[#out.projectionSamples+1]={world={x,y,z},native={u,v,depth}}end
  end
  local good,x,y,z=N.Call(scene,'GetCameraRight');if good then out.nativeRight={x,y,z}end
  good,x,y,z=N.Call(scene,'GetCameraUp');if good then out.nativeUp={x,y,z}end
  for _,a in ipairs(self.order)do out.models[#out.models+1]={id=a.id,renderer='native ModelSceneActor',renderLayer=a.renderLayer or self.baseLayer,groundOffset=a.groundOffset or 0,shadowLayer=a.shadowLayer or'contact-shadows',seating=a.seating and{kind=a.seating.kind,phase=a.seating.phase,approach=a.seating.approach}or nil,unit=a.spec.unit,fileID=a.spec.fileID,npcID=a.spec.npcID,displayID=a.displayID,status=a.status,ready=a.ready==true,requestIssued=a.requested==true,actorLoaded=a.actorLoaded==true,probeReady=a.probeReady==true,probeDisplayID=a.probeDisplayID,probeModelFileID=a.probeModelFileID,probeLoadEvent=a.probeLoadEvent==true,bounds=a.bounds,scale=a.scale,position=a.position,nativeOrigin=a.nativeOrigin,nativePosition=a.nativePosition,positionSpace="world to model-scaled translation",floorUV=a.spec.floorUV,registrationPending=a.awaitRegistration==true,floorAnchorStatus=a.floorAnchorStatus,registrationAttempts=a.registrationAttempts,worldYaw=a.worldYaw,animation=a.animation,animationClock=a.animationClock,animationRate=a.lastAnimationRate,motionStatus=a.motionStatus,collisionWait=a.collisionWait,visitor=a.spec.visitor==true,rememberedGUID=a.spec.rememberedGUID,appearanceSource=a.spec.appearanceSource,likeness=a.spec.appearance and'Generic textured race/sex body; captured standalone gear only; body clothing, face and hair are generic'or nil,dressedItems=a.dressedItems,genericClothingSlots=a.genericClothingSlots,retired=a.retired==true,restStage=a.restStage,route=a.route and{elapsed=a.route.elapsed,duration=a.route.duration,length=a.route.path.length}or nil,capabilities=a.capabilities,shadow=a.shadow,collider=a.collider,hitbox=a.hitbox,effect=a.effectReport}end
  return out
 end
 s.status='native camera accepted; models not yet loaded';return s
end
