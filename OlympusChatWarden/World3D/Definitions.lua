-- One shipped neighborhood. square keeps the existing Live scene wire identity;
-- the existing geometry digest rejects clients with different world definitions.
local _,ns=...
local F={VERSION=1,enabled=true,PRIMARY='square',BASE='e4cc9f8da008fd065d933e6d142dde854108d53a'};ns.Fireside3D=F
local C=ns.WardenRoomCatalogue
F.homeDoor={side='negative-y',width=2.2,wallThickness=.2}
F.bounds={-36,-28,36,32}
F.houses={{id='player-home',at={0,14,0}},{id='house-west',at={-17,14,0}},{id='house-east',at={17,14,0}},{id='house-southwest',at={-17,-12,0}},{id='house-southeast',at={17,-12,0}}}
local props={}
for _,h in ipairs(F.houses)do props[#props+1]={id=h.id,fileID=190430,label=h.id=='player-home'and'Your Home'or'Neighborhood House',width=12,at=h.at,yaw=0,worldYaw=0,house3D=true,collision=true}end
local function add(row)props[#props+1]=row end
add({id='desk',fileID=198603,label='Home table',height=.9,at={0,14,0},yaw=0})
add({id='room-book',fileID=200912,label='Athena Journal',width=.65,at={0,14,.915},support='desk',supportOffset={0,0,.015},probeObject=true,animations={0,146,147,148,149},interaction='journal',collision=false})
add({id='chair',fileID=198114,label='Home chair',height=1.55,at={2,12,0},yaw=0,interaction='chair',seatFraction=.29,seatHeightOffset=.3})
add({id='shelf-right',fileID=242995,label='Badge and memento shelf',height=2.3,at={2.4,16,0},yaw=math.pi,worldYaw=math.pi,interaction='showcase',showcaseSupport=true})
add({id='firepit',fileID=189705,label='Gathering fire',width=1.3,at={0,-1,0},interaction='fire',nativeEffects=true,collisionRadius=.65})
for i,p in ipairs({{-5,-2},{5,-2}})do add({id='public-chair-'..i,fileID=198114,label='Gathering chair',height=1.55,at={p[1],p[2],0},yaw=i==1 and 0 or math.pi,interaction='chair',seatFraction=.29,seatHeightOffset=.3})end
for i,p in ipairs({{-30,25},{30,25},{-30,-23},{30,-23}})do add({id='tree-'..i,fileID=189923,label='Evergreen',height=7,at={p[1],p[2],0},collisionRadius=.8})end
F.npcPaths={{{-7,-2},{-7,3},{-4,5}},{{7,-2},{7,3},{4,5}},{{-2,16},{-2,13},{-3,12}}}
F.props=props
local d={label='Fireside — The New Home',interior=false,world3D=true,reader=true,layoutSlot='fireside-3d',shot={id='fireside-3d-world-v1',position={0,-18,8},target={0,0,1},fov=.85},
 navigation={floor=0,floorUV={0,0,1,1},worldBounds=F.bounds,coordinateSpace='WORLD_XYZ_3D_V1',npcPaths=F.npcPaths,homeDoor=F.homeDoor,houseModel=190430},
 props=props,residents={{id='attendant',unit='player',controlled=true,height=1.85,at={0,-7,0},animations={0,4,5,96,97,98,102,103,104},navigationRadius=.3}},outside={},plates={},routes={},airOccluders={},flags={},book={offset={0,0,.015},wideScale=.65},musicScene='forest',walkSpeed=4,artRevision='3d-neighborhood-v1'}
assert(C.ReviseBundledRoom(F.PRIMARY,d))
function F.IsScene(s)return s and s.definition and s.definition.world3D==true end
-- Old links stay recoverable as shipped metadata but are not active 3D travel.
function F.SceneKey()return F.PRIMARY end
