-- Pure world/codec checks. No saved data, credentials, auth, networking or private addon is executed.
local ns={WardenWorldScenes={layers={'native','contact-shadows'},props={},residents={},outside={},navigation={}}}
local function load(path)return assert(loadfile('OlympusChatWarden/'..path))('test',ns)end
load('WardenRoomCatalogue.lua');local C=ns.WardenRoomCatalogue
for _,key in ipairs({'hall','square'})do assert(C.RegisterRoom(key,{label=key,layoutSlot=key,shot={position={0,-18,8},target={0,0,1},fov=.85},navigation={floor=0,floorUV={0,0,1,1}},plates={},props={},residents={}}))end
C.onRegister=function(key,d)ns.WardenWorldScenes.props[key]=d.props;ns.WardenWorldScenes.residents[key]=d.residents;ns.WardenWorldScenes.outside[key]=d.outside;ns.WardenWorldScenes.navigation[key]=d.navigation end
load('WardenSceneObjectControls.lua');load('WardenNativeScene.lua');load('World3D/Definitions.lua');load('World3D/Coordinates.lua');load('World3D/Scene.lua')
local F,N=ns.Fireside3D,ns.WardenNativeScene
assert(#F.houses==0 and #F.buildingCandidates==4 and F.manualBuildingTests and F.PRIMARY=='square')
local models={};for _,h in ipairs(F.buildingCandidates)do assert(not models[h.fileID],'each candidate must use a different model');models[h.fileID]=true;assert(N.ActorAllowed({roomKey='fireside-3d'},h),'manual Elwynn requests must remain allowed')end
assert(models[106851]and models[106965]and models[106848]and models[107232],'only the requested Elwynn buildings may be selected')
local d=C.Room('square');assert(d.world3D and d.reader and #d.plates==0 and #d.outside==0 and #d.flags==0 and d.layoutSlot=='fireside-3d-elwynn-manual')
assert(d.navigation.automaticBuildings==false and #d.navigation.houseModels==0)
for _,p in ipairs(d.props)do assert(not p.house3D and not F.BuildingCandidate(p.fileID),'no candidate may be requested by startup props')end
assert(C.Room('hall').layoutSlot=='hall','old layout metadata must remain recoverable')
assert(#d.props+#d.residents+3+8<=N.MAX_ACTORS,'include existing eight Live peer slots in actor budget')
local wall=F.HomeWalls({centerX=0,centerY=14,halfX=6,halfY=4,cos=1,sin=0})
local nav={ground=true,floor=0,radius=.3,boundary=F.bounds,obstacles=wall}
local function segment(x,y,tx,ty)return{samples={{x=x,y=y,z=0},{x=tx,y=ty,z=0}}}end
assert(N.CheckPath(segment(0,8,0,13),nav),'home doorway must admit a player')
assert(not N.CheckPath(segment(3,8,3,13),nav),'home front wall must block')
assert(not N.CheckPath(segment(0,13,0,20),nav),'home back wall must block')
local rotated=F.HomeWalls({centerX=0,centerY=0,halfX=6,halfY=4,cos=0,sin=1})
assert(N.CheckPath(segment(6,0,0,0),{ground=true,floor=0,radius=.3,obstacles=rotated}),'rotated doorway uses world collider basis')
local house=C.Copy(F.buildingCandidates[1]);house.house3D=true;local failed={spec=house,ready=false,failed=true}
local sampleScene={definition={props={house}},native={actors={[house.id]=failed},order={failed}},shot=d.shot}
ns.WardenWorldScenes.Props=function(s)return s.definition.props end
assert(F.Navigation({},sampleScene,{spec={controlled=true}}),'a reported missing house must not freeze all player movement')
failed.failed=nil;assert(not F.Navigation({},sampleScene,{spec={controlled=true}}),'pending house bounds must still block unsafe movement')
-- Removing automatic buildings must leave the existing housing objects active.
local home={id='player-home',spec=house,ready=false,bounds={-12,-10,0,12,10,8},actor={GetModelFileID=function()return 106851 end}}
local seatSpec;for _,p in ipairs(d.props)do if p.id=='chair'then seatSpec=p end end
local seat={id='chair',spec=seatSpec,ready=true,actor={Hide=function(self)self.hidden=true end}}
local interiors={actors={['player-home']=home,chair=seat},order={home,seat},Place=function(_,a,x,y,z)a.position={x,y,z}end,Error=function(_,a,why)a.failed=true;a.status=why end}
home.engine=interiors;seat.engine=interiors
local room={native=interiors};local realm={};realm.ActorReady=function(_,s,a)return F.ActorReady(realm,s,a)end
F.ActorReady(realm,room,seat);assert(not seat.awaitHome and seat.position[1]==seatSpec.at[1],'furniture remains active in the open scene without a house')
assert(F.HomeReady({native={actors={}}}),'manual building isolation must not gate the real Journal/chair/shelf')
local calls,messages={},{};ns.Print=function(message)messages[#messages+1]=message end
local nativeProp={SetModelByFileID=function(_,id)calls[#calls+1]=id;return true end}
local diagnostic=F.Coordinates.Bind({order={},metrics={moves=0},LoadProp=function(self,spec)
 assert(N.Call(nativeProp,'SetModelByFileID',spec.fileID));local actor={id=spec.id,spec=spec,ready=false};self.order[#self.order+1]=actor;return actor
end})
for i,h in ipairs(F.buildingCandidates)do
 local a=diagnostic:LoadProp({id='custom-'..i,fileID=h.fileID,custom=true})
 assert(calls[i]==h.fileID and a.buildingAttempt.fileID==h.fileID and a.buildingAttempt.sequence==i,'diagnostics must retain every manual request and its native path')
 assert(a.buildingAttempt.phase=='native request returned; waiting for bounds')
end
assert(#calls==4 and #messages==4,'no hard one-building limit, quarantine, replacement or duplicate request')
local report=F.BuildingReport({native=diagnostic});assert(not report.visualVerified and report.automaticBuildings==false and #report.buildings==4 and report.lastAttempt.fileID==107232)
ns.Print=nil
local engine=F.Coordinates.Bind({metrics={moves=0}})
local native={};function native:SetPosition(x,y,z)self.position={x,y,z}end
function native:SetYaw(yaw)self.yaw=yaw end;function native:SetPitch()end;function native:SetRoll()end
function native:SetScale()error('placement cannot apply perspective scale')end
local a={ready=true,spec={},bounds={-1,-2,-.5,3,4,2},scale=.5,groundOffset=100,actor=native}
for i=0,359 do
 engine.shot={position={math.cos(i)*20,math.sin(i)*20,3},target={4,6,1},fov=.85}
 assert(engine:Place(a,4,6,0,.5));assert(a.position[1]==4 and a.position[2]==6 and a.presentationFactor==1 and a.scale==.5)
end
-- Hash/codec are the shipped gameplay implementation, never an alternate transport.
load('PackCrypto.lua');ns.AetherLive={};load('AetherLiveGameplay92.lua')
local G=ns.AetherLiveGameplay;assert(G.PROTOCOL==2 and G.Scenes.square=='a')
local revision=G.SCENE_REVISION;assert(revision and G.Compatible(revision)and not G.Compatible('old-geometry'))
local state={scene='square',revision=revision,position={0,-7,0},destination={4,-7,0},yaw=.4,duration=1,animation=4}
local wire=assert(G.StateEncode(state));local decoded=assert(G.StateDecode(wire))
assert(decoded.scene=='square'and decoded.position[2]==-7 and decoded.destination[1]==4)
local before=G.GeometryWire(C);local changed=C.Room('square');changed.navigation.homeDoor.width=2.4;assert(C.ReviseBundledRoom('square',changed));assert(before~=G.GeometryWire(C),'door geometry must affect compatibility')
-- Catalog stays unloaded until the existing editor asks for it.
load('World3D/Catalog.lua');assert(not F.Catalog.rows and not Fireside3DAssetIndex)
local requested=0
LoadAddOn=function(name)assert(name=='Fireside3DAssets');requested=requested+1;assert(loadfile('Fireside3DAssets/Index.lua'))();return true end
local rows=assert(F.Catalog.Search('106851'));assert(#rows==1 and rows[1].status=='ELWYNN_WMO_RENDER_UNVERIFIED')
assert(F.Catalog.Search('house')and requested==1,'lazy catalog should load only once')
for _,r in ipairs(Fireside3DAssetIndex)do assert(F.Catalog.Compatible(r)or F.Catalog.IsCandidate(r))end
assert(not F.Catalog.Compatible(rows[1])and F.Catalog.IsCandidate(rows[1]),'Elwynn WMO entries remain candidates, not compatible/verified props')
assert(#F.Catalog.Search('','Elwynn buildings')==4,'all four buildings must remain available in the existing editor')
assert(#F.Catalog.Search('203656')==0 and #F.Catalog.Search('190430')==0,'remove rejected Arathi and swamp building references')
assert(not F.Catalog.IsCandidate({fileID=106851,format='WMO',zone='Other zone',status='ELWYNN_WMO_RENDER_UNVERIFIED'}))
assert(not F.Catalog.Compatible({format='M2',era='RETAIL'}),'retail housing must not appear in the Forever catalog')
local editor={ObjectCatalogue={{198049,'Existing shelf',2.3,0,'Shelves'}},FilterObjects=function()return{}end}
editor.AddObjectForm=function()
 local found=false;for _,r in ipairs(editor.ObjectCatalogue)do if r[1]==106851 then assert(r[3]==10 and r[2]:find('unverified',1,true));found=true end end
 assert(found,'dropdown choices must also exist in the editor selection lookup');return 'original form'
end
ns.WardenSceneEditor=editor;assert(F.Catalog.BindExistingEditor());assert(editor.AddObjectForm()=='original form')
local count=#editor.ObjectCatalogue;editor.AddObjectForm();assert(#editor.ObjectCatalogue==count,'do not append duplicates on reopening')
assert(#editor.FilterObjects('Elwynn buildings','goldshireinn.wmo')==1,'search supports the actual Elwynn model path')
ns.WardenSceneEditor=nil
print('PASS: no automatic building requests, all four editor candidates retained, unchanged manual native loading with per-model diagnostics, active housing objects, fresh layout slot, logical collision, 360 placement, Live slots/codec/geometry and lazy editor selection')
-- Existing Live publisher: no handshake/transport is run. Verify manual movement
-- uses the same M state/codec and coalescing, with a bounded six-Hz signature.
ns.WardenRealm={Attach=function()return{}end};ns.WardenCanonicalPlayer={Save=function()return true end};ns.SafeCall=function(fn,...)if fn then return fn(...)end end
ns.SafeNumber=function(n)return type(n)=='number'and n or nil end
local clock=0;GetTime=function()return clock end
load('AetherLiveWorld92.lua')
local W=ns.AetherLive.World;W.lastObservedForm=0;W.nextAppearance=1e9
local actor={ready=true,position={0,-7,0},yaw=0,animation=4,manualMovement=true}
local shared={key='square',definition=d,native={actors={attendant=actor}}}
local sent={};local client={Publish=function(_,kind,payload,coalesced)assert(kind=='M'and coalesced);sent[#sent+1]=assert(G.StateDecode(payload))end}
W.Publish({},shared,client);assert(#sent==1 and sent[1].animation==4)
clock=.05;actor.position={.2,-7,0};W.Publish({},shared,client);assert(#sent==1,'do not exceed existing coalesced movement cadence')
clock=.2;actor.position={.8,-7,0};W.Publish({},shared,client);assert(#sent==2 and math.abs(sent[2].position[1]-.8)<1e-6)
actor.manualMovement=false;actor.animation=0;W.Publish({},shared,client);assert(#sent==3 and sent[3].animation==0,'final idle position must publish immediately')
print('PASS: existing Live M channel/codec, six-Hz manual movement coalescing, immediate stop, unchanged scene wire code and protocol version')
local clipped=F.ClipPolygon({{-1,-1},{2,-1},{2,2},{-1,2}},function(p)return p[1]end,function(n)return n>=0 end)
for _,p in ipairs(clipped)do assert(p[1]>=0)end
local oldNavigation=F.Navigation
F.Navigation=function()return{ground=true,floor=0,radius=.3,boundary=F.bounds,obstacles={}}end
local remote={spec={liveRemote=true,appearance={raceID=1,sex=2}},ready=true,position={0,0,0},world3DTarget={position={4,0,0},yaw=0,animation=4}}
local rendered={order={remote},Place=function(_,a,x,y,z)a.position={x,y,z}end,Animate=function(_,a,id)a.animation=id end}
for i=1,30 do F.StepRemote({}, {native=rendered},remote,.05)end
assert(math.abs(remote.position[1]-4)<.01 and remote.position[3]==0,'validated Live target must converge in world coordinates')
remote.world3DTarget.animation=0;F.StepRemote({}, {native=rendered},remote,.05);assert(remote.animation==0)
F.Navigation=oldNavigation
print('PASS: floor-decal clipping and world-space rendering convergence of already-validated Live movement states')
