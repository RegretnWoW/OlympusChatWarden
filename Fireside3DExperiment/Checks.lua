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
assert(loadfile('Fireside3DExperiment/Background.lua'))('test',ns)
local B=ns.ExperimentBackground
local checked=0
for degrees=0,330,30 do
 for _,pitch in ipairs({-.05,.35,1.1}) do
  local yaw=degrees*math.pi/180
  local view={position={3-12*math.cos(pitch)*math.cos(yaw),4-12*math.cos(pitch)*math.sin(yaw),math.max(.4,1.3+12*math.sin(pitch))},target={3,4,1.3},fov=.85}
  for _,v in ipairs({.1,.3,.5,.7,.9,.99}) do
   for _,u in ipairs({0,.2,.5,.8,1}) do
    local x,y=B.GroundPoint(view,u,v,16/9)
    if x then
     local pu,pv,depth=N.Project(view,x,y,0,16/9)
     assert(depth>0 and math.abs(pu-u)<1e-7 and math.abs(pv-v)<1e-7,'ground projection disagrees with native scene math')
     checked=checked+1
    end
   end
  end
 end
end
assert(checked>100)
local level={position={0,-10,2},target={0,0,2},fov=.85}
assert(not B.GroundPoint(level,.5,.1,16/9),'sky rays must not draw floor')
print('PASS: '..checked..' inverse-ground projection samples; horizon rejection')
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
