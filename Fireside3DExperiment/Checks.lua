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
