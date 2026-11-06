-- Three bounded native woodland visitors. No legacy 2D / flying spawners.
local _,ns=...;local W={VERSION=3};ns.WardenWildlife=W
local N,S=ns.WardenNativeScene,ns.WardenWorldScenes
local player=S.residents.hall[1]
S.residents.hall={player,
 {id='stag',npcID=883,displayID=347,height=1.5,navigationRadius=.42,wildlife=true,at={-30,3,0},animations={0,4,5}},
 {id='rabbit',displayID=328,height=.4,wildlife=true,at={-30,3,0},animations={0,4,5}},
 {id='squirrel',npcID=1412,height=.3,wildlife=true,at={-30,3,0},animations={0,4,5}},
}
S.outside.hall={};S.outside.study={}
for _,id in ipairs({'bird','owl','fox','moth'})do S.paths[id]=nil;S.routes.study[id]=nil end
for _,id in ipairs({'stag','rabbit','squirrel'})do S.paths[id]={wildlife=true,firstDelay=id=='stag'and 5 or id=='rabbit'and 3 or 8,persistent=false}end
-- Keep the old award IDs readable without gating natural wildlife visits.
local Q=ns.WardenSanctuary
Q.rewards[#Q.rewards+1]={id='squirrel',title='Squirrel Visitor',track='Squirrel',reason='Ambient woodland visitor.'};Q.byID.squirrel=Q.rewards[#Q.rewards]
local owned=Q.Owned
Q.Owned=function(id,owner)return owned(id=='squirrel'and'fox'or id,owner)end
W.rules={stag={wait={75,150},speed=.58},rabbit={wait={45,105},speed=.48},squirrel={wait={55,135},speed=.52},['town-cat']={wait={90,180},speed=.46}}
-- Per-realm deterministic PRNG: no global math.randomseed and no saved-state
-- writes. Tests can supply a seed; normal sessions vary with their start time.
function W.Random(v)
 local seed=v.wildlifeSeed or math.floor((ns.SafeCall(GetTime)or 1)*1000)%2147483646+1
 seed=(seed*48271)%2147483647;v.wildlifeSeed=seed;return seed/2147483647
end
local function metric(v,a)
 v.wildlifeMetrics=v.wildlifeMetrics or{};local m=v.wildlifeMetrics[a.id]
 if not m then m={attempts=0,starts=0,exits=0,stops=0,rejected=0};v.wildlifeMetrics[a.id]=m end;return m
end
local function offscreen(s,a,p)
 if not p then return false end
 local x,y,z=N.World(s.shot,p[1]or p.x,p[2]or p.y,p[3]or p.z)
 local u=N.ProjectNative(a.engine.frame,s.shot,x,y,z);return u and(u<-.16 or u>1.16)or false
end
function W.Blocked(v,s,a)
 a.wildlifeRecover=true;a.wildlifeRealm=v;a.route=nil;s.routeAt[a.id]=v.age+2+W.Random(v)*3
 a.motionStatus='Waiting to resume from current position';a.engine:Animate(a,0,1)
 metric(v,a).reason=a.motionStatus
end
function W.Ended(v,s,a)
 if not offscreen(s,a,a.position)then return W.Blocked(v,s,a)end
 local r=W.rules[a.id];a.route=nil;a.wildlifeRecover=nil;a.wildlifeLastExit={unpack(a.position)}
 s.routeAt[a.id]=v.age+r.wait[1]+W.Random(v)*(r.wait[2]-r.wait[1]);a.motionStatus='Offscreen · waiting for next visit'
 metric(v,a).exits=metric(v,a).exits+1;N.Call(a.actor,'Hide');if s.shadows[a.id]then s.shadows[a.id]:Hide()end
end
function W.Navigation(s,a)
 local nav={ground=true,floor=0,radius=N.PersonRadius(a),obstacles={}}
 nav.polygon=N.FloorFence(a.engine.frame,s.shot,{-.6,.55,1.6,.985})
 if not nav.polygon then return nil,'Waiting for native woodland floor'end
 for _,prop in ipairs(s.native.order or{})do
  if prop~=a and prop.spec.fileID and not prop.spec.support and prop.spec.collision~=false and not(prop.editorHidden or prop.retired or prop.sceneHidden)then
   if not prop.ready or prop.awaitRegistration then return nil,'Waiting for scene object bounds: '..prop.id end
   local box=N.Footprint(s.shot,prop);if box then nav.obstacles[#nav.obstacles+1]=box end
  end
 end
 return N.PeopleNavigation(nav,a.engine,a)
end
-- Exact visibility-graph corners are retained: resampling could cut across a
-- prop. Combined paths and all retries remain strictly bounded.
function W.Combine(legs)
 local out={samples={},length=0,stops={}}
 for index,leg in ipairs(legs)do
  local compact={};for _,p in ipairs(leg.samples)do
   while #compact>=2 do local a,b=compact[#compact-1],compact[#compact];local dx,dy=b.x-a.x,b.y-a.y;local ex,ey=p.x-b.x,p.y-b.y
    if math.abs(dx*ey-dy*ex)>1e-8 or dx*ex+dy*ey<0 then break end;compact[#compact]=nil
   end;compact[#compact+1]=p
  end
  for i,p in ipairs(compact)do if index==1 or i>1 then
   if #out.samples>=N.MAX_PATH_SAMPLES then return nil,'Wildlife route sample budget'end
   out.samples[#out.samples+1]={x=p.x,y=p.y,z=p.z,distance=out.length+p.distance}
  end end
  out.length=out.length+leg.length;if index<#legs then out.stops[#out.stops+1]=out.length end
 end
 for i,d in ipairs(out.stops)do out.stops[i]=d/out.length end;return out
end
function W.Start(v,s,a)
 if s.key=='square'and a.spec.domestic then return W.TownStart(v,s,a)end
 if s.key~='hall'or not a.ready or a.failed then return false,'Wildlife unavailable'end
 if a.route then return true end
 local m=metric(v,a);m.attempts=m.attempts+1
 local function retry(why,delay)m.rejected=m.rejected+1;m.reason=why;a.motionStatus=why;s.routeAt[a.id]=v.age+(delay or 6);return false,why end
 if not a.capabilities[4]then return retry('Installed walk animation unavailable',60)end
 local nav,why=W.Navigation(s,a);if not nav then return retry(why,3)end
 for attempt=1,6 do
  local right=W.Random(v)>.5;local depth=.65+W.Random(v)*.18
  local uv={{right and 1.24 or -.24,depth},{.25+W.Random(v)*.5,.65+W.Random(v)*.19},{.25+W.Random(v)*.5,.65+W.Random(v)*.19},{right and .28 or .72,.65+W.Random(v)*.19},{right and -.24 or 1.24,.65+W.Random(v)*.18}}
  local points={};for _,p in ipairs(uv)do local x,y=N.AuthoredFloorPoint(a.engine.frame,s.shot,p[1],p[2],0);if not x then break end;points[#points+1]={x,y,0}end
  if #points==5 then
   if a.wildlifeRecover then points[1]={unpack(a.position)}end
   local legs={};for i=2,#points do local path,err=N.WalkPath(points[i-1],points[i][1],points[i][2],nav)
    if not path then why=err;break end;legs[#legs+1]=path
   end
   local path=#legs==4 and W.Combine(legs)
   if path and N.CheckPath(path,nav)and(a.wildlifeRecover or offscreen(s,a,points[1]))and offscreen(s,a,points[5])then
    if not a.wildlifeRecover then N.Call(a.actor,'Hide');a.spec.worldYaw=nil;a.engine:Place(a,points[1][1],points[1][2],0,0)end
    local ok,err=a.engine:Route(a,path,math.max(3,path.length/W.rules[a.id].speed),4,nav)
    if ok then
     a.wildlifeRecover=nil;a.wildlifeRealm=v;a.route.stops=path.stops;a.route.nextStop=1
     s.routeAt[a.id]=nil;a.motionStatus='Woodland visit · wandering and resting';m.starts=m.starts+1;m.reason=nil
     v.metrics.wildlifeVisits=(v.metrics.wildlifeVisits or 0)+1;return true
    end;why=err
   end
  end
 end
 return retry(why or'Waiting for a clear offscreen route')
end
function W.BeforeTick(engine,a,r,dt)
 if not r.stops then return false end
 local v=a.wildlifeRealm
 if r.pause then
  r.pause=math.max(0,r.pause-dt);engine:Animate(a,0,1)
  if r.pause==0 then
   r.pause=nil;local q=N.Pace(r.elapsed,r.duration);local _,_,_,dx,dy=N.Sample(r.path,math.min(1,q+.00001));local target=math.atan2(dy,dx)
   local start=a.yaw or target;local delta=(target-start+math.pi)%(2*math.pi)-math.pi
   if math.abs(delta)>.1 then r.turn={elapsed=0,duration=.55,from=start,delta=delta}end
  end;return true
 end
 local stop=r.stops[r.nextStop or 1];local q=N.Pace(r.elapsed,r.duration)
 if stop and q>=stop then
  r.nextStop=(r.nextStop or 1)+1;r.pause=2+(v and W.Random(v)or .5)*5;engine:Animate(a,0,1)
  a.motionStatus='Woodland visitor · resting';if v then local m=metric(v,a);m.stops=m.stops+1 end;return true
 end;return false
end
function W.TownStart(v,s,a)
 if not a.ready or a.failed or a.route then return false,'Domestic model unavailable or already walking'end
 local m=metric(v,a);m.attempts=m.attempts+1
 local function retry(why)m.rejected=m.rejected+1;m.reason=why;a.motionStatus=why;s.routeAt[a.id]=v.age+12;return false,why end
 if not a.capabilities[4]then return retry('Installed domestic walk animation unavailable')end
 local nav,why=ns.WardenSceneNavigation81.PortalNavigation(v,s,a,nil,{-.3,.40,1.3,.985});if not nav then return retry(why)end
 local targets={{1.24,.90},{.94,.89},{.795,.84},{.70,.64},{.51,.70},{.79,.84},{1.24,.90}}
 local points={};for i,p in ipairs(targets)do local x,y=N.AuthoredFloorPoint(s.native.frame,s.shot,p[1],p[2],0);if not x then return retry('Waiting for domestic entrance projection')end;points[i]={x,y,0}end
 if a.wildlifeRecover then points[1]={unpack(a.position)}end
 local legs={};for i=2,#points do local leg;leg,why=N.WalkPath(points[i-1],points[i][1],points[i][2],nav);if not leg then return retry(why)end;legs[#legs+1]=leg end
 local path;path,why=W.Combine(legs);if not path or not N.CheckPath(path,nav)then return retry(why or'No safe domestic street route')end
 if not a.wildlifeRecover then N.Call(a.actor,'Hide');a.spec.worldYaw=nil;a.engine:Place(a,unpack(points[1]))end
 local ok;ok,why=a.engine:Route(a,path,math.max(3,path.length/W.rules[a.id].speed),4,nav)
 if not ok then return retry(why)end
 a.wildlifeRecover=nil;a.wildlifeRealm=v;a.route.stops=path.stops;a.route.nextStop=1;s.routeAt[a.id]=nil;m.starts=m.starts+1;a.motionStatus='Town cat · wandering and resting';return true
end
function W.Report(v)return{version=W.VERSION,species=v.wildlifeMetrics or{},seed=v.wildlifeSeed,policy='Ambient animals always available; woodland species in Fields, domestic cat in Town Square; natural bounded visit intervals'}end
