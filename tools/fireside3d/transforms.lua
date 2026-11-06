-- The editor publishes transforms; a recorded native actor independently applies
-- model-scaled translation, yaw and physical size. No private code is executed.
local ns={Fireside3D={},WardenCanonicalPlayer={Update=function()end}}
local function load(p)return assert(loadfile('OlympusChatWarden/'..p))('test',ns)end
load('WardenSceneObjectControls.lua');load('WardenNativeScene.lua');load('World3D/Coordinates.lua');load('World3D/Hitboxes.lua')
local W,H,C=ns.Fireside3D.Coordinates,ns.Fireside3D.Hitboxes,ns.WardenSceneObjectControls
local function near(a,b)assert(math.abs(a-b)<1e-8,tostring(a)..' differs from '..tostring(b))end
local function point(a,b)for i=1,3 do near(a[i],b[i])end end
local function native()
 local n={scale=1,scaleCalls=0,positionCalls=0,yawCalls=0}
 function n:SetRequestedScale(s)self.requested=s;self.scaleCalls=self.scaleCalls+1 end
 function n:SetScale(s)self.scale=s end
 function n:SetPosition(x,y,z)self.position={x,y,z};self.positionCalls=self.positionCalls+1 end
 function n:SetYaw(yaw)self.yaw=yaw;self.yawCalls=self.yawCalls+1 end
 function n:SetPitch()end;function n:SetRoll()end
 -- This computes the rendered world point from received native commands; it
 -- never reads the editor's logical scale, position, anchor or collision box.
 function n:World(p)
  local c,s=math.cos(self.yaw),math.sin(self.yaw)
  return{self.scale*(self.position[1]+c*p[1]-s*p[2]),self.scale*(self.position[2]+s*p[1]+c*p[2]),self.scale*(self.position[3]+p[3])}
 end
 return n
end
local shot={position={0,-18,8},target={0,0,1},fov=.85}
local engine=W.Bind({metrics={moves=0},shot=shot,actors={}})
local a={ready=true,engine=engine,id='tent',actor=native(),spec={fileID=202016,worldYaw=-.4},bounds={-2,-3,-.7,4,5,2.5},scale=.75,authoredBaseScale=.75,editorBaseScale=.75,yaw=-.2}
engine.actors.tent=a
local anchor={1,1,-.7};local target={3,17,1};local legacy={engine={world3D=false},id='legacy'};local legacyCalls=0;local fail=false;local canonicalYaw
local e={}
e.Find=function(key,id)if id=='native/tent'then return{kind='native',engine=engine,id='tent'}elseif id=='native/legacy'then return{kind='native',engine={world3D=false,actors={legacy=legacy}},id='legacy'}end end
-- Public Apply contract fixture: the editor changes the desired spec angle and
-- physical scale, invalidates presentation, then supplies its previous facing.
e.Apply=function(key,id,r)
 if id=='native/legacy'then assert(not legacy.world3DEditApplying);legacyCalls=legacyCalls+1;return true,'legacy untouched'end
 if id=='missing'then return false,'unknown object'end
 a.spec.worldYaw=canonicalYaw or r.yaw*math.pi/180
 a.scale=a.editorBaseScale*r.scale;a.top=(a.bounds[6]-a.bounds[3])*a.scale;a.renderScale=nil
 assert(engine:Place(a,r.x,r.y,r.z,a.yaw or 0))
 if fail then error('fixture apply failure')end
 return true,'applied'
end
ns.WardenSceneEditor=e
assert(W.BindExistingEditor()and not W.BindExistingEditor())
local box={enabled=true,width=2,depth=1,x=.4,y=-.3};a.collider={boxes={box}}
local custom={x=.4,y=-.3,z=.2,width=2,depth=1,height=1.1}
local lastCorner
for _,multiplier in ipairs({.05,.25,.5,1,2,5,1,.25,1})do
 for _,degrees in ipairs({-360,-180,-90,0,45,90,180,360})do
  local r={x=target[1],y=target[2],z=target[3],yaw=degrees,scale=multiplier}
  local ok,why=e.Apply('square','native/tent',r);assert(ok and why=='applied'and not a.world3DEditApplying)
  near(a.actor.scale,.75*multiplier);near(a.actor.requested,a.actor.scale);near(a.actor.yaw,degrees*math.pi/180)
  point(a.position,target);point(a.actor:World(anchor),target)
  -- A vertex away from the pivot must actually rotate and resize in the model,
  -- not merely change a report or the editor's projected selection rectangle.
  local corner=a.actor:World({4,5,-.7});local c,s=math.cos(a.actor.yaw),math.sin(a.actor.yaw)
  point(corner,{target[1]+a.actor.scale*(c*3-s*4),target[2]+a.actor.scale*(s*3+c*4),target[3]})
  if degrees==45 then lastCorner=corner elseif degrees==90 then assert(math.abs(corner[1]-lastCorner[1])+math.abs(corner[2]-lastCorner[2])>.01)end
  -- Compound colliders/click volumes must share that same transformed model frame.
  local footprint=H.Footprints(shot,a)[1];local shape=H.Shape(shot,a,custom)
  for i,p in ipairs({{-1,-1},{1,-1},{1,1},{-1,1}})do
   local nativeCorner={anchor[1]+(box.x+p[1]*box.width*.5)/.75,anchor[2]+(box.y+p[2]*box.depth*.5)/.75,anchor[3]}
   local rendered=a.actor:World(nativeCorner);near(rendered[1],footprint.corners[i][1]);near(rendered[2],footprint.corners[i][2])
  end
  local bottom=a.actor:World({anchor[1]+custom.x/.75,anchor[2]+custom.y/.75,anchor[3]+custom.z/.75})
  near(bottom[1],shape.centerX);near(bottom[2],shape.centerY);near(bottom[3],shape.bottom)
  near(shape.top,bottom[3]+custom.height*multiplier)
 end
end
-- During saved-player restoration, the existing editor can select a different
-- canonical angle internally. The adapter must use the angle it actually writes.
canonicalYaw=.9;assert(e.Apply('square','native/tent',{x=3,y=17,z=1,yaw=180,scale=1}));near(a.actor.yaw,.9);canonicalYaw=nil
-- Outside Apply, persistent spec yaw must not freeze player/NPC movement facing.
assert(engine:Place(a,4,18,0,-1.2));near(a.actor.yaw,-1.2);point(a.actor:World(anchor),{4,18,0})
local calls=a.actor.scaleCalls;for i=0,359 do
 engine.shot={position={20*math.cos(i),20*math.sin(i),8},target={4,18,1},fov=.85}
 assert(engine:Place(a,4,18,0,-1.2))
end
assert(a.actor.scaleCalls==calls,'camera orbit cannot change physical scale')
-- Error cleanup and nested scopes must never leave a permanent yaw override.
fail=true;local ok,err=pcall(e.Apply,'square','native/tent',{x=3,y=17,z=1,yaw=45,scale=1});assert(not ok and err:find('fixture apply failure',1,true)and not a.world3DEditApplying);fail=false
assert(engine:Place(a,3,17,1,-.6));near(a.actor.yaw,-.6)
a.world3DEditApplying='outer';assert(e.Apply('square','native/tent',{x=3,y=17,z=1,yaw=0,scale=1}));assert(a.world3DEditApplying=='outer');a.world3DEditApplying=nil
assert(e.Apply('hall','native/legacy',{})and legacyCalls==1);local missing,why=e.Apply('square','missing',{});assert(missing==false and why=='unknown object')
-- Save/undo/reload already route through Apply: replaying complete records must
-- restore the exact native model and preserve the same world-space pivot.
local first={x=3,y=17,z=1,yaw=35,scale=.4};local second={x=3,y=17,z=1,yaw=120,scale=2.5}
assert(e.Apply('square','native/tent',first));local oldPoint=a.actor:World({4,5,-.7})
assert(e.Apply('square','native/tent',second));assert(e.Apply('square','native/tent',first));point(a.actor:World({4,5,-.7}),oldPoint)
-- A newly created native actor needs scale even if the logical cache matches.
a.actor=native();assert(engine:Place(a,3,17,1,35*math.pi/180));near(a.actor.scale,.3);assert(a.actor.scaleCalls==1);point(a.actor:World(anchor),target)
-- A failed scale API cannot silently cache success or move using another scale.
local failure=native();local setScale=failure.SetScale;failure.SetScale=function()error('fixture native scale failure')end
a.actor=failure;a.renderScale=nil;assert(not engine:Place(a,3,17,1,0));assert(a.renderScale==nil and failure.positionCalls==0)
failure.SetScale=setScale;assert(engine:Place(a,3,17,1,0));near(failure.scale,.3);point(failure:World(anchor),target)
print('PASS: editor angle overrides stale facing only inside Apply; actual native requested/physical scale, asymmetric fixed pivot through full rotations and scale changes, compound collider/click-volume alignment')
print('PASS: canonical restoration, movement-facing isolation, idle scale caching, error/nesting cleanup, legacy delegation, undo/reload record replay, replacement actor and failed-scale retry')
