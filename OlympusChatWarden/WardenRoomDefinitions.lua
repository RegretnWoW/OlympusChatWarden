-- Adopt accepted Hall/Oasis data without moving a single authored contact.
-- Legacy S.* tables remain compatibility views; new rooms register one record.
local _,ns=...;local C,S=ns.WardenRoomCatalogue,ns.WardenWorldScenes
local byFile={};for _,item in ipairs(C.Items())do byFile[item.fileID]=item.itemID end
for _,group in pairs(S.props)do for i,old in ipairs(group)do
 local itemID=assert(byFile[old.fileID],'Built-in prop missing reusable template');local placement=C.Copy(old);placement.fileID=nil
 local p=assert(C.Instantiate(itemID,placement))
 -- Keep the accepted width/height normalization and full-bounds collisions.
 p.height,p.width,p.collisionRadius=old.height,old.width,old.collisionRadius
 group[i]=p
end end
local function install(key,d)
 S.shots[key]=d.shot;S.props[key]=d.props;S.residents[key]=d.residents;S.outside[key]=d.outside;S.plates[key]=d.plates
 S.navigation[key]=d.navigation;S.routes[key]=d.routes;S.airOccluders[key]=d.airOccluders;S.artRevision[key]=d.artRevision;S.layoutSlots[key]=d.layoutSlot
end
C.onRegister=install
for _,entry in ipairs({{'hall','Olympus Fields',false},{'study','Olympian Oasis',true}})do
 local key=entry[1]
 local flags=key=='hall'and{{id=1,kind='guild',box={.839,.232,.15},pole='flagpole'}}or{{id=4,kind='guild',box={.435,.032,.06},scale=.25,pole='flagpole'}}
 assert(C.RegisterRoom(key,{label=entry[2],interior=entry[3],lighting=S.lighting and S.lighting[key],shot=S.shots[key],props=S.props[key],residents=S.residents[key],outside=S.outside[key],plates=S.plates[key],navigation=S.navigation[key],routes=S.routes[key],airOccluders=S.airOccluders[key],artRevision=S.artRevision[key],layoutSlot=S.layoutSlots[key]or key,reader=key=='study',book=key=='study'and S.book or nil,flags=flags}))
end
-- Click the painted gate, then approach its road on the registered field floor.
-- The city journey is covered by the transition, rather than fake scaling or
-- walking a model over a distant painted building without a real ground plane.
assert(C.RegisterConnection('hall-to-oasis','hall','study',{label='Visit Olympian Oasis',portal={clickUV={.59,.32,.73,.585},triggerUV={.60,.505,.72,.575},approachUV={.65,.54},arrivalUV={.13,.88},arrivalWalkUV={.28,.84}}}))
assert(C.RegisterConnection('oasis-to-hall','study','hall',{label='Return to Olympus Fields',portal={clickUV={.015,.80,.22,.985},triggerUV={.025,.84,.205,.975},approachUV={.13,.90},arrivalUV={.65,.56},arrivalWalkUV={.65,.67}}}))
function S.Room(key)return C.Room(key)end
