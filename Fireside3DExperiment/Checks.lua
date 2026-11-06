-- Run from repository root using Lua 5.1. Pure engine checks, no simulated rendering.
local ns={}
assert(loadfile('Fireside3DExperiment/Vendor/WardenSceneObjectControls.lua'))('test',ns)
assert(loadfile('Fireside3DExperiment/Vendor/WardenNativeScene.lua'))('test',ns)
local N=ns.WardenNativeScene
local function segment(x,y,a,b) return {samples={{x=x,y=y,z=0},{x=a,y=b,z=0}}} end
local nav={ground=true,radius=.3,boundary={-24,-24,24,24},obstacles={{id='house',left=-6,right=6,near=-4,far=4}}}
assert(not N.CheckPath(segment(0,-8,0,8),nav),'swept wall collision must reject tunnelling')
assert(N.CheckPath(segment(8,-8,8,8),nav),'exterior route should stay clear')
assert(not N.CheckPath(segment(23,8,24,8),nav),'player radius must stay on floor')
nav.obstacles={{id='front left',left=-6,right=-1.1,near=-4,far=-3.75},{id='front right',left=1.1,right=6,near=-4,far=-3.75}, {id='table',left=-.5,right=.5,near=-.5,far=.5}}
assert(N.CheckPath(segment(0,-6,0,-2),nav),'authored doorway should admit a player')
assert(not N.CheckPath(segment(2,-6,2,-2),nav),'doorway wall must block')
assert(not N.CheckPath(segment(0,-2,0,2),nav),'table must block')
local shot={position={0,-20,10},target={0,0,1},fov=.85}
local x,y,z=N.World(shot,3,4,0)
assert(x==3 and y==4 and z==0,'fixed authored coordinate basis changed')
for degrees=0,359 do
 local angle=degrees*math.pi/180
 local view={position={-12*math.cos(angle),-12*math.sin(angle),5},target={0,0,1},fov=.85}
 local u,v,depth=N.Project(view,0,0,1,16/9)
 assert(math.abs(u-.5)<1e-9 and math.abs(v-.5)<1e-9 and depth>0,'orbit must keep its target centered')
end
print('PASS: swept collision, floor boundary, approximate doorway, furniture collision, fixed basis, 360 orbit projections')
-- Exercise the adapted production seat controller using pure actor records.
-- Place/Animate/Route record native boundary calls; this is not a visual simulator.
assert(loadfile('Fireside3DExperiment/Interactions.lua'))('test',ns)
local combat=false
InCombatLockdown=function()return combat end
local e={actors={},order={}}
local a={id='player',spec={unit='player',controlled=true},ready=true,position={0,-3,0},top=1.85,scale=1,bounds={-.3,-.3,0,.3,.3,1.85},capabilities={[0]=true,[4]=true,[102]=true},engine=e,yaw=0}
local seat={id='chair',spec={fileID=198114,interaction='chair',seatFraction=.29},ready=true,position={0,0,0},top=1.55,scale=1,bounds={-.5,-.5,0,.5,.5,1.55},worldYaw=0}
e.actors={player=a,chair=seat};e.order={a,seat}
function e:Place(who,x,y,z,yaw)who.position={x,y,z};who.yaw=yaw;return true end
function e:Animate(who,id)assert(who.capabilities[id]);who.lastAnimation=id;return true end
function e:Route(who,path,duration,animation,nav)assert(N.CheckPath(path,nav));who.route={path=path};return true end
local v,s=ns.ExperimentInteractions.Bind(e,shot,function()
 return N.PeopleNavigation({ground=true,floor=0,radius=.3,boundary={-10,-10,10,10},obstacles={N.Footprint(shot,seat)}},e,a)
end)
assert(v:InteractPlayer(s,'chair') and a.pendingInteraction and a.route,'click must plan a clear approach')
local intent=a.pendingInteraction;local endpoint=a.route.path.samples[#a.route.path.samples]
e:Place(a,endpoint.x,endpoint.y,0,0);a.route=nil;a.pendingInteraction=nil
local approach={unpack(a.position)}
assert(v:SeatPlayer(s,a,intent) and a.seating.phase=='settle')
for i=1,12 do v:UpdatePlayerSeat(s,a,.1)end
assert(a.seating.phase=='hold' and a.lastAnimation==102,'settle must select probed chair animation')
assert(a.position[1]==seat.position[1] and a.position[2]==seat.position[2])
v:LeavePlayerSeat(s,a)
for i=1,10 do v:UpdatePlayerSeat(s,a,.1)end
assert(not a.seating and a.lastAnimation==0 and a.position[1]==approach[1] and a.position[2]==approach[2],'stand must return to approach before free movement')
a.capabilities[102]=false
local yes,why=v:InteractPlayer(s,'chair');assert(not yes and why:find('animation'),'unsupported poses must fail explicitly')
a.capabilities[102]=true;combat=true
assert(not v:InteractPlayer(s,'chair'),'combat must block interactions');combat=false
-- Same native body selector as the production visitor path, without private history.
assert(N.BodyDisplay({raceID=1,sex=2})==1276 and N.BodyDisplay({raceID=1,sex=3})==176)
local npc={id='npc-outside',spec={appearance={raceID=1,sex=3}},ready=true,position={2,-3,0},top=1.8,scale=1,authoredBaseScale=1}
e.order[#e.order+1]=npc
e:Place(a,0,-3,0,0)
assert(not N.CanStep(e,a,a.position,{4,-3,0}),'swept person clearance must block walking through NPC')
assert(N.CanStep(e,a,a.position,{0,-4,0}))
print('PASS: chair approach, settle/hold/stand, unsupported animation, combat guard, generic NPC selection and NPC clearance')
-- Scene-specific transform separation: camera changes never change actor transforms.
assert(loadfile('Fireside3DExperiment/WorldSpace.lua'))('test',ns)
local W=ns.ExperimentWorldSpace
local calls=0
local native={}
function native:SetPosition(x,y,z)self.position={x,y,z};calls=calls+1 end
function native:SetYaw(y)self.yaw=y end
function native:SetPitch(p)self.pitch=p end
function native:SetRoll(r)self.roll=r end
function native:SetScale()error('camera/placement must not change model scale')end
local en=W.Bind({shot=shot,metrics={moves=0}})
local actor={actor=native,ready=true,spec={floorUV={.9,.1},worldYaw=9},bounds={-2,-1,-.5,4,3,5},scale=.6,groundOffset=99}
local function near(x,y)assert(math.abs(x-y)<1e-7,tostring(x)..' != '..tostring(y))end
for degrees=0,359 do
 local angle=degrees*math.pi/180
 -- Intentionally mutate the authored shot too: placement and collision no longer depend on it.
 en.shot={position={10*math.cos(angle),10*math.sin(angle),8},target={-3,9,2},fov=.3+angle*.1}
 assert(en:Place(actor,3,4,0,.7))
 near(actor.position[1],3);near(actor.position[2],4);near(actor.position[3],0)
 near(native.position[1]*actor.scale+math.cos(.7)*actor.worldAnchor[1]*actor.scale-math.sin(.7)*actor.worldAnchor[2]*actor.scale,3)
 near(native.position[2]*actor.scale+math.sin(.7)*actor.worldAnchor[1]*actor.scale+math.cos(.7)*actor.worldAnchor[2]*actor.scale,4)
 near(native.position[3]*actor.scale+actor.worldAnchor[3]*actor.scale,0)
 local box=N.Footprint(en.shot,actor);near(box.centerX,3);near(box.centerY,4)
 local x,y,z=N.World(en.shot,3,4,0);assert(x==3 and y==4 and z==0)
end
assert(calls==360 and actor.scale==.6 and en.legacyShadows==false)
-- Feed recorded-style native pixel projections to the existing normalization/plane fit.
-- This validates mapping/invariants, not the client's actual projection or native API behavior.
local frame={}
function frame:GetWidth()return 1600 end
function frame:GetHeight()return 900 end
function frame:GetEffectiveScale()return 1 end
function frame:Project3DPointTo2D(x,y,z)
 local u,v,d=N.Project(self.firesideViewShot,x,y,z,1600/900)
 if not u then return end
 return u*1600,(1-v)*900,d
end
local samples=0
for degrees=0,330,30 do
 for _,pitch in ipairs({.12,.5,1.1})do
  local yaw=degrees*math.pi/180
  frame.firesideViewShot={position={3-12*math.cos(pitch)*math.cos(yaw),4-12*math.cos(pitch)*math.sin(yaw),1.3+12*math.sin(pitch)},target={3,4,1.3},fov=.85}
  local map=assert(W.FloorMap(frame,frame.firesideViewShot))
  for _,point in ipairs({{0,0},{3,4},{-4,-2},{7,8}})do
   local u,v=N.Project(frame.firesideViewShot,point[1],point[2],0,1600/900)
   if u then local x,y=map(u,v);near(x,point[1]);near(y,point[2]);samples=samples+1 end
  end
 end
end
local projection=frame.Project3DPointTo2D;frame.Project3DPointTo2D=nil
assert(not W.FloorMap(frame,shot),'missing native projection must hide ground, not use a second perspective')
frame.Project3DPointTo2D=projection
print('PASS: 360 camera-independent world placements, scale/anchor/collision invariance, '..samples..' native-plane mapping samples, missing-projection rejection; legacy shadows disabled')
-- Moving world anchor while a follow camera rotates/pitches; several model sizes.
for _,scale in ipairs({.25,1,3})do
 actor.scale=scale
 for degrees=0,350,10 do
  local q=degrees*math.pi/180;local x,y=3+math.sin(q)*2,4+math.cos(q)*2
  en.shot={position={x-9*math.cos(q),y-9*math.sin(q),2+degrees*.02},target={x,y,1.3},fov=.85}
  assert(en:Place(actor,x,y,0,q))
  near(actor.worldPosition[1],x);near(actor.worldPosition[2],y)
  local box=N.Footprint(en.shot,actor);near(box.centerX,x);near(box.centerY,y)
  near(native.position[1]*scale+math.cos(q)*actor.worldAnchor[1]*scale-math.sin(q)*actor.worldAnchor[2]*scale,x)
  near(native.position[2]*scale+math.sin(q)*actor.worldAnchor[1]*scale+math.cos(q)*actor.worldAnchor[2]*scale,y)
  near(native.position[3]*scale+actor.worldAnchor[3]*scale,0)
 end
end
print('PASS: moving world contacts/colliders during follow-camera changes at three fixed model scales')
