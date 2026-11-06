-- Public hub. Local scene state only; no evidence, network or history migration.
local _,ns=...;local C,S=ns.WardenRoomCatalogue,ns.WardenWorldScenes
for index,name in ipairs(S.layers)do if name=='contact-shadows'then table.insert(S.layers,index+1,'town-behind-fountain');table.insert(S.layers,index+2,'town-fountain');break end end
local function item(key,placement)return assert(C.Instantiate(key,placement))end
local props={
 item('campfire',{id='firepit',width=1.3,height=1.2,at={0,0,0},floorUV={.586,.709},nativeEffects=true,interaction='fire'}),
 item('human-chair',{id='public-chair-1',height=1.25,at={0,0,0},floorUV={.635,.729},worldYaw=-1.8,interaction='chair',seatFraction=.29}),
 item('human-chair',{id='public-chair-2',height=1.25,at={0,0,0},floorUV={.572,.772},worldYaw=.7,interaction='chair',seatFraction=.29}),
 {id='town-fountain',fileID=198247,label='Fountain',height=1.4,maxWidth=5.5,at={0,0,0},floorUV={.393,.609},nativePass='town-fountain',nativeEffects=true,collisionRadius=0},
}
-- Existing installed human lantern references. These remain scene placements,
-- not new visually qualified production-library entries.
for _,r in ipairs({
 {'gate-west',198327,.184,.785,1.4,.65},{'gate-east',198327,.725,.785,1.4,.65},
 {'bridge-west',198327,.086,.482,1.0,.40},{'bridge-east',198327,.176,.561,1.0,.43},
 {'quay',198327,.192,.508,1.0,.42},{'archive',198291,.235,.436,1.6,.42},
 {'civic-west',198291,.483,.375,1.6,.42},{'civic-east',198291,.532,.375,1.6,.42},
 {'tavern-west',198291,.663,.439,1.6,.45},{'tavern-east',198291,.747,.419,1.6,.45},
 {'stable',198291,.846,.639,1.6,.45},{'forge',198291,.907,.395,1.6,.42},
})do props[#props+1]={id='lantern-'..r[1],fileID=r[2],label='Lantern',height=r[6],at={0,0,r[5]},floorUV={r[3],r[4]},collision=false,nativeEffects=true,shadow={enabled=false}}end
-- Keep the original model placements as inert authored anchors. The custom M2
-- stays quarantined. A top-pinned cloth render uses the proven atlas player;
-- Fields/Home retain their existing sideways pole standards unchanged.
local flags={}
for index,r in ipairs({
 {'civic-west',.466,.293,1.18,2.5},{'civic-east',.548,.293,1.18,2.5},
 {'tavern-west',.651,.345,1.05,2.2},{'tavern-east',.784,.324,1.05,2.2},
 {'archive',.274,.345,.90,1.9},{'quay',.166,.476,.92,1.5},
 {'forge',.925,.425,.90,1.8},{'gate-west',.184,.812,1.30,2.2},{'gate-east',.732,.812,1.30,2.2},
})do
 local id='olympus-flag-'..r[1]
 props[#props+1]={id=id,modelKey='olympus-cloth82',label='Olympus Banner',height=r[4],at={0,0,r[5]},floorUV={r[2],r[3]},worldYaw=0,collision=false,shadow={enabled=false},animations={0}}
 local height=r[4]*(r[1]:find('gate-',1,true)and .130 or .110);local width=height*ns.WardenSceneAssets.assets['guild-hanging90'].aspect/S.aspect
 flags[#flags+1]={id=100+index,kind='guild',pole=id,mount='architecture',asset='guild-hanging90',layer=r[1]:find('gate-',1,true)and'desk-props-front'or'flags',box={r[2]-width*.5,r[3]-.012,width,height}}
end
local population={
 gates={
  {id='market-corner',concealed={.363,.445},floor={.436,.505},clear={.455,.640},ignore='market-front'},
  {id='tavern-lane',concealed={.825,.440},floor={.840,.525},clear={.780,.585},ignore='tavern-front'},
  {id='stable-corner',concealed={.867,.683},floor={.778,.754},clear={.690,.770},ignore='stable-front'},
 },
 destinations={{.465,.684},{.705,.668},{.517,.813},{.424,.732},{.758,.563},{.575,.565},{.563,.874}},
 exit='square-to-fields',exitEndUV={.508,1.30},publicObjects=true,
}
local scenery={
 {id='fountain-base',uv={.294,.551,.495,.625}},
 {id='market-front',uv={.220,.402,.397,.492}},
 {id='civic-front',uv={.435,.392,.575,.437}},
 {id='tavern-front',uv={.625,.412,.866,.494}},
 {id='forge-front',uv={.918,.441,.999,.574}},
 {id='stable-front',uv={.807,.606,.999,.859}},
 {id='west-quay',uv={.002,.603,.199,.788}},
 {id='west-gate',uv={.002,.810,.233,.999}},
 {id='east-gate',uv={.700,.808,.772,.999}},
}
-- The approach road belongs behind the distant city arches. Keep its pixels,
-- placement, floor and travel geometry unchanged; only correct paint order.
local plates=C.Copy(ns.WardenTownArt82.plates)
ns.WardenWorldArt.assets['square84-home-interior']={width=345,height=200,aspect=345/200,
 path='Interface\\AddOns\\OlympusChatWarden\\Media\\TownSquare84\\home-interior.tga',uv={0,.673828125,0,.78125}}
for _,plate in ipairs(plates)do
 if plate[1]=='ground-canal'then plate[3]='hills'
 elseif plate[1]=='bridge-quay'then plate[3]='room-frames'end
 -- Soft contact under the facade, not a second baked shadow in the artwork.
 -- Offsets and dimensions are relative to each plate and remain editable.
 if plate[1]=='tavern'or plate[1]=='civic-hall'or plate[1]=='archive-market'or plate[1]=='forge'or plate[1]=='stables'then
  plate[5]={enabled=true,width=.88,depth=.10,x=.50,y=.965,opacity=.64}
 end
end
for index,plate in ipairs(plates)do
 if plate[1]=='residence'then
  -- Different frame levels make this order deterministic even when textures
  -- are remounted from saved layouts or lighting changes.
  table.insert(plates,index,{'residence-interior','square84-home-interior','scene-backing',{.0794479628235908,.29817691102283106,.1118568524112735,.11521794973515981}})
  break
 end
end
local definition={label='The Agora',interior=false,musicScene='town',surface='stone',
 shot={id='town81-gathering',position={0,-26,10},target={0,0,1.2},fov=.75},
 -- Private integration build restores the authored scene for calibration.
 props=props,nativeObjectsPaused=false,residents={{id='attendant',unit='player',controlled=true,height=1.85,at={0,0,0},floorUV={.51,.84},navigationRadius=.40,animations={0,4,52,54,96,97,98,102,103,104}},
  {id='town-cat',npcID=7381,height=.36,navigationRadius=.16,wildlife=true,domestic=true,at={-30,3,0},animations={0,4,5}}},
 outside={},plates=plates,navigation={floorUV={.015,.400,.985,.985},floor=0,contactOffset=-.02,scenery=scenery},
 routes={},airOccluders={},lighting={mode='directional',ambient=.53,diffuse=.82,red=1,green=.91,blue=.79,x=-.7,y=.6,z=-1},
 artRevision='town-square82-four-state',layoutSlot='town-square81',flags=flags,population=population,
 nativeVerification='Top-hung cloth animation rendered from one fixed mesh, top suspension and approved material; downward folds and proportional upright emblem. Existing atlas playback, no custom M2. Final native-client appearance requires inspection.'}
assert(C.RegisterRoom('square',definition))
S.lighting.square=definition.lighting;S.population={hall={destinations={{.27,.68},{.4,.76},{.63,.73},{.76,.65}},exit='hall-to-oasis',publicObjects=true},square=population}
S.paths['town-cat']={wildlife=true,firstDelay=12,persistent=false}
assert(C.RegisterConnection('hall-to-oasis','hall','square',{label='Enter The Agora',portal={clickUV={.59,.32,.73,.585},triggerUV={.60,.505,.72,.575},approachUV={.65,.54},arrivalUV={.508,.935},arrivalWalkUV={.508,.84}}}))
assert(C.RegisterConnection('oasis-to-hall','study','square',{label='Enter The Agora',portal={clickUV={.015,.80,.22,.985},triggerUV={.025,.84,.205,.975},approachUV={.13,.90},arrivalUV={.242,.588},arrivalWalkUV={.30,.645}}}))
assert(C.RegisterConnection('square-to-fields','square','hall',{label='Return to Pyragore Fields',portal={clickUV={.341,.861,.664,.999},triggerUV={.362,.956,.652,.989},approachUV={.508,.941},arrivalUV={.65,.595},arrivalWalkUV={.65,.67}}}))
assert(C.RegisterConnection('square-to-home','square','study',{label='Enter Olympian Oasis',portal={clickUV={.012,.446,.233,.611},triggerUV={.206,.538,.233,.576},approachUV={.243,.591},arrivalUV={.235,.86},arrivalWalkUV={.30,.84}}}))
-- Hearth is a destination service, not an invisible walking shortcut.
function C.HearthDestination(from)
 if not C.HasRoom(from)or from=='study'then return end
 return{id='hearth-home',from=from,to='study',label='Olympian Oasis',portal={arrivalUV={.235,.86},arrivalWalkUV={.30,.84}}}
end
ns.WardenTownSquare81={version=81,definition=definition}
