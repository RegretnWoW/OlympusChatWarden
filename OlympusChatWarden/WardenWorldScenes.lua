-- Authored fixed-camera sets. Native object IDs reference installed assets only.
-- Shared native projection, art registration and grounding require client visual review.
local _,ns=...
local S={VERSION=6,aspect=16/9,artStatus='camera-matched art integration; native appearance awaits client verification'};ns.WardenWorldScenes=S
S.shots={
 hall={id='hall38-fixed',position={8.168,-18.255,6.5},target={0,0,1.2},fov=.75},
 study={id='study51-low-convergence',position={6.126,-13.691,3.0},target={0,0,1},fov=.75},
}
-- Human furniture exists in the installed Forever build index. Rendering and
-- support contacts still require native inspection; metadata is not visual proof.
S.props={
 study={
  -- Owner export54: explicit world contacts; no screen-anchor relocation.
  {id='desk',fileID=198175,height=.95,maxWidth=3.6,path='world/generic/human/passive doodads/desks/fancydesk01.m2',worldYaw=-1.586399627624023,at={3.622445440455194,2.675504089724439,-0.125},sizeMultiplier=1.0,shadow={["depth"]=2,["enabled"]=true,["opacity"]=0.92,["width"]=2,["x"]=1,["y"]=0},shadowLayer="contact-shadows"},
  {id='chair',fileID=198114,height=1.55,seatFraction=.29,path='world/generic/human/passive doodads/chairs/generalchairhighend01.m2',worldYaw=0.9443277877677547,at={1.643868500463658,-0.4776510683202502,0},sizeMultiplier=1.0,shadow={["depth"]=1,["enabled"]=true,["opacity"]=0.92,["width"]=1,["x"]=0,["y"]=0},shadowLayer="contact-shadows",seatHeightOffset=0.3},
  {id='shelf-left',fileID=198047,height=2.3,path='world/generic/human/passive doodads/bookshelves/abbeyshelf01.m2',worldYaw=1.5551930259657702,at={-5.061024208380861,0.5597731600518132,0},sizeMultiplier=1,shadow={["depth"]=2,["enabled"]=true,["opacity"]=0.92,["width"]=2,["x"]=0,["y"]=0},shadowLayer="contact-shadows"},
  {id='shelf-right',fileID=242995,showcaseSupport=true,height=2.3,empty=true,path='world/expansion02/doodads/dalaran/dalaran_bookcase_empty_01.m2',worldYaw=-0.8882679268262913,at={-3.017672192748343,4.631007107426012,0},sizeMultiplier=1,shadow={["depth"]=2,["enabled"]=true,["opacity"]=0.92,["width"]=2,["x"]=0,["y"]=0},shadowLayer="contact-shadows"},
  {id='candle',fileID=198076,height=.38,support='desk',supportOffset={.325,-.26,0},path='world/generic/human/passive doodads/candelabras/generalcandelabra01.m2',worldYaw=1.3962634015954636,at={3.947445440455195,2.41550408972444,0.8249999999999997},sizeMultiplier=1,shadow={["depth"]=1,["enabled"]=true,["opacity"]=0.92,["width"]=1,["x"]=0,["y"]=0},shadowLayer="contact-shadows"},
  {id='room-book',fileID=200912,width=.65,support='desk',supportOffset={-.475,-.675,.065},supportYaw=true,animations={0,146,147,148,149},probeObject=true,nativeSequenceSeconds=.333,path='world/goober/g_bookopenmediumbrown.m2',worldYaw=-1.586399627624023,at={3.147445440455196,2.000504089724441,0.8899999999999998},sizeMultiplier=1,shadowLayer="contact-shadows"},
  {id='flagpole',fileID=198199,height=2.25,collisionRadius=.12,path='world/generic/human/passive doodads/flagpole/flagpole01.m2',worldYaw=0.0,at={-2.324738575290328,23.59343117213681,0},sizeMultiplier=0.4,shadowLayer="contact-shadows"},
  {id='side-table',fileID=198604,height=.8,collision=true,collisionRadius=0,worldYaw=0.4363323129985824,at={-2.175,-2.739353480708668,0},sizeMultiplier=1,shadow={["depth"]=3,["enabled"]=true,["opacity"]=0.92,["width"]=3,["x"]=0,["y"]=0},shadowLayer="contact-shadows"},
 },
 hall={
  {id='tree-left',fileID=189923,height=4.8,worldYaw=0.0,sizeMultiplier=1.15,at={-4.728041753035585,-3.372214340655975,0},collisionRadius=.3,path='world/azeroth/elwynn/passivedoodads/trees/elwynnfirtree01.m2'},
  {id='firepit',fileID=189705,width=1.5,worldYaw=0.0,sizeMultiplier=1,at={-0.21999999999999992,-2.914,0},nativeEffects=true,path='world/azeroth/elwynn/passivedoodads/campfire/elwynncampfire.m2'},
  {id='flagpole',fileID=198199,height=3.2,worldYaw=0,at={5,0,0},floorUV={.84,.68},path='world/generic/human/passive doodads/flagpole/flagpole01.m2'},
 },
}
function S.Props(scene)
 local out={};for _,spec in ipairs(S.props[scene.key])do out[#out+1]=spec end
 local keys={};for id in pairs(scene.customSpecs or{})do keys[#keys+1]=id end;table.sort(keys)
 for _,id in ipairs(keys)do out[#out+1]=scene.customSpecs[id]end;return out
end
-- Owner-approved Integrated44 export. Multipliers retain the original editor scale basis.
S.book={offset={0,0,0},wideScale=.65}
S.residents={
 study={
  {id='attendant',unit='player',controlled=true,height=1.85,at={-3.1,1.8,0},floorUV={.32,.65},navigationRadius=.45,animations={0,4,52,54,96,97,98,102,103,104}},
 },
 hall={
  {id='attendant',unit='player',controlled=true,height=1.85,at={-4.1,2.7,0},floorUV={.28,.65},navigationRadius=.45,animations={0,4,52,54,96,97,98,102,103,104}},
  {id='rabbit',family='rabbit',height=.4,reward='rabbit',at={-30,3,0},animations={0,4,5}},
  {id='owl',family='owl',height=.7,reward='owl',at={30,7,5},animations={0,4,135,233,234},flying=true},
  {id='stag',npcID=883,height=1.5,reward='stag',at={-30,8,0},animations={0,4,96,97,98}},
  {id='fox',family='fox',height=.6,reward='fox',at={30,5,0},animations={0,4,96,97,98}},
  {id='moth',family='moth',height=.20,reward='moth',at={-30,2,1.1},animations={0,4,135,233,234},flying=true},
 },
}
-- Arbitrary ordered passes; shared depth is reserved for interacting native props.
S.layers={'sky','cloud-far','cloud-near','outside-native','mountains','hills','city','near-roofs','scene-backing','portal-native','water','bridge','gatehouse','window-flags','shell','room-frames','contact-shadows','shelf-props','shelf-badges','native-rear','flags','native','foreground','desk-props-front'}
S.artRevision={hall='a2-heartland-50',study='river-home-51'}
-- A replacement room has its own private placement slot; previous room settings remain intact.
S.layoutSlots={study='study-owner63',hall='hall-owner63'}
S.lighting={hall={["ambient"]=0.58,["blue"]=1,["diffuse"]=0.85,["green"]=1,["mode"]="directional",["red"]=1,["x"]=-0.7,["y"]=0.6,["z"]=-0.10000000000000014},study={["ambient"]=0.25,["blue"]=1,["diffuse"]=0.85,["green"]=1,["mode"]="directional",["red"]=1,["x"]=-4.5,["y"]=3.3000000000000016,["z"]=-0.7000000000000001}}
S.homeAnchor={id='riverside-blue-gable',houseBoundsUV={650/1672,260/941,850/1672,387/941},view='Upper residential floor of blue-gabled timber house above west river wall, left of the main gate. New canal-side city view, not the outdoor city plate.'}
local function skyPlates()
 return{
  {'sky','sky49','sky',{0,0,1,1}},
  {'cloud-far-a','cloud49','cloud-far',{0,-.05,1.2,.52}},
  {'cloud-far-b','cloud49','cloud-far',{1.2,-.05,1.2,.52}},
  {'cloud-near-a','cloud49','cloud-near',{0,.03,1.45,.36}},
  {'cloud-near-b','cloud49','cloud-near',{1.45,.03,1.45,.36}},
 }
end
S.plates={hall={
 {'sky','a2-sky','sky',{0,0,1,1}},
 {'cloud-far-a','a2-cloud-far-left','cloud-far',{.08,.01,.26,.16}},
 {'cloud-far-b','a2-cloud-far-right','cloud-far',{.64,.025,.27,.16}},
 {'cloud-near-a','a2-cloud-near-left','cloud-near',{.30,-.08,.32,.27}},
 {'cloud-near-b','a2-cloud-near-right','cloud-near',{.85,-.06,.32,.27}},
 {'terrain','a2-mountains','mountains',{0,0,1,1}},
 {'hills','a2-hills','hills',{0,0,1,1}},
 {'city','a2-city','city',{0,0,1,1}},
 {'backing','a2-backing','scene-backing',{0,0,1,1}},
 {'river','a2-river','water',{0,0,1,1}},
 {'bridge','a2-bank-bridge','bridge',{0,0,1,1}},
 {'gatehouse','a2-gatehouse','gatehouse',{0,0,1,1}},
 {'ground','a2-ground','shell',{0,0,1,1}},
},study={
 {'sky','home51-sky','sky',{0,0,1,1}},
 {'cloud-far-a','a2-cloud-far-left','cloud-far',{.14,.12,.18,.10}},
 {'cloud-far-b','a2-cloud-far-right','cloud-far',{.66,.10,.19,.10}},
 {'cloud-near-a','a2-cloud-near-left','cloud-near',{.37,.025,.21,.10}},
 {'cloud-near-b','a2-cloud-near-right','cloud-near',{.85,.015,.22,.10}},
 {'mountains','home51-mountains','mountains',{0,0,1,1}},
 {'hills','home51-hills','hills',{0,0,1,1}},
 {'city','home51-city','city',{0,0,1,1}},
 {'roofs','home51-roofs','near-roofs',{0,0,1,1}},
 {'backing','home51-backing','scene-backing',{0,0,1,1}},
 {'river','home51-water','water',{0,0,1,1}},
 {'bridge','home51-bridge-quays','bridge',{0,0,1,1}},
 {'ground','home51-floor','shell',{0,0,1,1}},
 {'shell','home51-shell','shell',{0,0,1,1}},
 {'window-frames','home51-frames','room-frames',{0,0,1,1}},
}}
S.airOccluders={hall={'ground'},study={'ground','shell','window-frames'}}

S.outside={
 hall={{id='bird',family='bird',height=.60,reward='bird',at={-30,10,4.5},animations={0,4,135,233,234},flying=true}},
 study={{id='bird',family='bird',height=.48,reward='bird',at={-30,10,4.5},animations={0,4,135,233,234},flying=true},
  {id='owl',family='owl',height=.55,reward='owl',at={30,12,6},animations={0,4,135,233,234},flying=true}},
}
-- Right/depth/elevation in REAL scene units; depth varies on both ground and
-- flight routes. Control points avoid the desk and the shelving footprints.
S.paths={
 rabbit={duration=32,animation=4,screen=true,curves={{{-.16,.64,0},{.24,.64,0},{.70,.61,0},{1.16,.63,0}}}},
 stag={duration=54,animation=4,screen=true,curves={{{-.20,.60,0},{.20,.59,0},{.74,.58,0},{1.20,.60,0}}}},
 fox={duration=38,animation=4,screen=true,curves={{{1.16,.66,0},{.74,.63,0},{.24,.65,0},{-.16,.65,0}}}},
 bird={duration=22,animations={135,233,234},screen=true,curves={{{-.16,.24,4.5},{.25,.20,4.8},{.70,.24,5.2},{1.16,.26,4.5}}}},
 owl={duration=28,animations={135,233,234},screen=true,curves={{{1.16,.25,4.8},{.70,.20,5.2},{.25,.29,4.6},{-.16,.24,4.8}}}},
 moth={duration=48,animations={135,233,234},screen=true,curves={{{-.16,.49,1.1},{.24,.47,1.7},{.74,.50,1.4},{1.16,.48,1.1}}}},
}
-- Walk to a useful resting point, wait, then return along the same aisle.
-- Study points are floor contacts in the artwork and are inverted through the
-- actual client projection, never treated as hard-coded guessed world positions.
local function aisle(a,b,c,d,uv,duration,wait,delay)
 return{duration=duration,speed=.85,wait=wait,firstDelay=delay,animation=4,persistent=true,ground=true,backtrack=true,floorUV=uv,
  curves={{{a,b,0},{a+(c-a)/3,b+(d-b)/3,0},{a+2*(c-a)/3,b+2*(d-b)/3,0},{c,d,0}}}}
end
S.paths.attendant=aisle(.28,.65,.40,.76,true,7,18,6);S.paths.attendant.fire=true
S.paths.wizard=aisle(.72,.64,.64,.73,true,7,23,15);S.paths.wizard.fire=true
S.routes={study={attendant=aisle(.32,.65,.44,.61,true,7,24,6),wizard=aisle(.69,.64,.58,.59,true,7,29,14)},hall={}}
-- The house's exterior wildlife stays beyond its windows despite the lower
-- shared camera. Screen placement is inverted on a native depth plane.
for _,id in ipairs({'bird','owl'})do local original=S.paths[id];local route={};for key,value in pairs(original)do route[key]=value end;route.viewDepth=40;S.routes.study[id]=route end
S.navigation={study={floorUV={{.02,.66},{.285,.535},{.98,.645},{.98,.985},{.02,.985}},floor=0,contactOffset=0},hall={floorUV={.015,.495,.985,.985},floor=0,contactOffset=-.035}}
function S.Route(scene,id)return S.routes[scene]and S.routes[scene][id]or S.paths[id]end
S.compositing={
 background='Camera-matched distant world, walls and ground plate; no duplicated desk/chair/NPC/animal pixels.',
 native='Interacting indoor/ground actors and props share one native depth buffer. A matched outside-bird pass sits behind window/landscape masks.',
 foreground='Only non-interacting scenic framing. No painted substitute for an interactive desk edge, seat or perch.',
 camera='Fixed projection. Reading zoom transforms the whole composite uniformly; no independent actor rescaling.',
 effects='Separate live anchored effects. No baked fire, smoke or sparks.',
}
