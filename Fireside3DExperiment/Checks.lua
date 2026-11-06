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
