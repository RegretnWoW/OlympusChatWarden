-- One shipped neighborhood. square keeps the existing Live scene wire identity;
-- the existing geometry digest rejects clients with different world definitions.
local _,ns=...
local F={VERSION=8,enabled=true,PRIMARY='square',BASE='e4cc9f8da008fd065d933e6d142dde854108d53a'};ns.Fireside3D=F
local C=ns.WardenRoomCatalogue
F.homeDoor={side='negative-y',width=2.2,wallThickness=.2}
F.bounds={-32,-24,32,34}
-- The user confirmed this M2 in Forever. WMO research remains manual only.
F.campLayout=true;F.manualBuildingTests=false;F.homeSite={0,16,0}
F.houses={{id='player-home',fileID=202016,label='Furbolg camp shelter',at={0,16,0}}}
F.preferredBuilding={fileID=202016,label='Furbolg forest tent',height=3.2,buttonLabel='Add forest tent',desiredLayout='Woodland shelter with a visible open entrance',layoutVerified=false,renderEvidence='USER_REPORT'}
F.buildingCandidates={
 {id='test-forest-tent',fileID=202016,label='Furbolg forest tent',width=6,at={0,23,0}},
 {id='test-tent',fileID=328178,label='Night Elf tent',width=6,at={0,23,0}},
 {id='house-west',fileID=106965,label='Elwynn farmhouse',width=14,at={-26,12,0}},
 {id='player-home',fileID=106851,label='Goldshire Inn',width=24,at={0,23,0}},
 {id='house-east',fileID=106848,label='Goldshire blacksmith',width=14,at={26,12,0}},
 {id='house-southwest',fileID=107232,label='Elwynn stables',width=18,at={0,-22,0}},
}
function F.BuildingCandidate(fileID)for _,h in ipairs(F.buildingCandidates)do if h.fileID==fileID then return h end end end
function F.HomeReady(s)
 if F.manualBuildingTests then return true end
 local home=s.native.actors['player-home'];return home and home.ready and not home.failed or false
end
local props={}
local function add(row)props[#props+1]=row end
add({id='player-home',fileID=202016,label='Furbolg camp shelter',height=5.5,at={0,16,0},worldYaw=-math.pi/2,collision=false,house3D=true})
add({id='desk',fileID=198603,label='Journal table',height=.9,at={-1,16,0},yaw=0,homeInterior=true})
add({id='room-book',fileID=200912,label='Athena Journal',width=.65,at={-1,16,.915},support='desk',supportOffset={0,0,.015},probeObject=true,animations={0,146,147,148,149},interaction='journal',collision=false,homeInterior=true})
add({id='shelf-right',fileID=242995,label='Badge and memento shelf',height=2.3,at={1.4,17,0},yaw=math.pi,worldYaw=math.pi,interaction='showcase',showcaseSupport=true,homeInterior=true})
add({id='firepit',fileID=189705,label='Camp fire',width=1.3,at={0,6,0},interaction='fire',nativeEffects=true,collisionRadius=.65})
for i,p in ipairs({{-3.6,6},{3.6,6},{-2.5,2.4},{2.5,2.4}})do
 add({id=i==1 and'chair'or'public-chair-'..(i-1),fileID=198114,label='Camp chair',height=1.55,at={p[1],p[2],0},worldYaw=math.atan2(6-p[2],-p[1]),interaction='chair',seatFraction=.29,seatHeightOffset=.3})
end
for i,p in ipairs({{-24,27},{24,27},{-24,-18},{24,-18}})do add({id='tree-'..i,fileID=189923,label='Evergreen',height=7,at={p[1],p[2],0},collisionRadius=.8})end
F.npcPaths={{{-8,0},{-8,4},{-6,8}},{{8,0},{8,4},{6,8}},{{-4,18},{-4,15},{-5,14}}}
F.props=props
local d={label='Fireside — Forest Camp',interior=false,world3D=true,reader=true,layoutSlot='fireside-3d-camp8',shot={id='fireside-3d-world-v4',position={0,-18,8},target={0,0,1},fov=.85},
 navigation={floor=0,floorUV={0,0,1,1},worldBounds=F.bounds,coordinateSpace='WORLD_XYZ_3D_V1',npcPaths=F.npcPaths,homeDoor=F.homeDoor,houseModels={202016},automaticBuildings=true,buildingZone='Forest camp'},
 props=props,residents={{id='attendant',unit='player',controlled=true,height=1.85,at={0,-4,0},animations={0,4,5,96,97,98,102,103,104},navigationRadius=.3}},outside={},plates={},routes={},airOccluders={},flags={},book={offset={0,0,.015},wideScale=.65},musicScene='forest',walkSpeed=4,artRevision='3d-forest-camp-v8'}
assert(C.ReviseBundledRoom(F.PRIMARY,d))
function F.IsScene(s)return s and s.definition and s.definition.world3D==true end
-- Old links stay recoverable as shipped metadata but are not active 3D travel.
function F.SceneKey()return F.PRIMARY end
