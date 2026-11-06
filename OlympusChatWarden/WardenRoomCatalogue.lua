-- Bundled scene definitions only. This is not a public extension or network API.
-- Templates describe an item; a room owns independent instances and placements.
local _,ns=...
local C={VERSION=1,MAX_ROOMS=32,MAX_ITEMS=128,MAX_LINKS=128};ns.WardenRoomCatalogue=C
local items,rooms,links={},{},{};local itemOrder,roomOrder,linkOrder={},{},{}
local function id(v)return type(v)=='string'and #v<=64 and v:match('^[a-z][a-z0-9%-]*$')~=nil end
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
local function copy(value,depth,budget)
 depth=depth or 0;budget=budget or{n=0}
 if type(value)~='table'then
  assert(type(value)=='nil'or type(value)=='boolean'or type(value)=='string'and #value<=1024 or finite(value),'Scene definitions must be plain finite data');return value
 end
 assert(depth<16 and not getmetatable(value),'Scene definition depth or metatable');budget.n=budget.n+1;assert(budget.n<=4096,'Scene definition budget')
 local out={};for k,v in pairs(value)do assert(type(k)=='string'or finite(k),'Invalid definition key');out[k]=copy(v,depth+1,budget)end;return out
end
C.Copy=copy
local function vector(v,n)if type(v)~='table'or #v~=n then return false end;for i=1,n do if not finite(v[i])then return false end end;return true end
function C.RegisterItem(key,spec)
 if not id(key)or items[key]or #itemOrder>=C.MAX_ITEMS then return false,'Invalid, duplicate or excessive item ID'end
 local ok,data=pcall(copy,spec);if not ok then return false,data end
 if type(data)~='table'or not finite(data.fileID)or data.fileID<1 or data.fileID%1~=0 or not finite(data.height)or data.height<=0 or data.height>12 or type(data.label)~='string'then return false,'An item needs a client model, label and bounded height'end
 if data.interaction and data.interaction~='chair'and data.interaction~='fire'then return false,'Unknown item interaction'end
 items[key]=data;itemOrder[#itemOrder+1]=key;return true
end
function C.Item(key)return items[key]and copy(items[key])end
function C.Items()local out={};for _,key in ipairs(itemOrder)do local row=copy(items[key]);row.itemID=key;out[#out+1]=row end;return out end
function C.Instantiate(key,placement)
 if not items[key]then return nil,'Unknown item template'end
 if placement~=nil and type(placement)~='table'then return nil,'Invalid item placement'end
 local out=copy(items[key]);for k,v in pairs(copy(placement or{}))do out[k]=v end;out.itemID=key
 if not id(out.id)or not vector(out.at,3)then return nil,'An instance needs its own stable ID and position'end
 return out
end
local function installRoom(key,spec,revision)
 if not id(key)or revision and not rooms[key]or not revision and(rooms[key]or #roomOrder>=C.MAX_ROOMS)then return false,'Invalid, duplicate or excessive room ID'end
 local ok,d=pcall(copy,spec);if not ok then return false,d end
 if type(d)~='table'or type(d.label)~='string'or type(d.shot)~='table'or not vector(d.shot.position,3)or not vector(d.shot.target,3)or not finite(d.shot.fov)or d.shot.fov<=.05 or d.shot.fov>=3 or type(d.navigation)~='table'or not finite(d.navigation.floor)or type(d.navigation.floorUV)~='table'or type(d.plates)~='table'or #d.plates>64 then return false,'Incomplete room camera, floor or artwork'end
 if d.shot.position[1]==d.shot.target[1]and d.shot.position[2]==d.shot.target[2]and d.shot.position[3]==d.shot.target[3]then return false,'Degenerate room camera'end
 if d.layoutSlot and not id(d.layoutSlot)then return false,'Invalid private layout slot'end
 d.layoutSlot=d.layoutSlot or key
 if revision and d.layoutSlot~=rooms[key].layoutSlot then return false,'A bundled revision must retain its private layout slot'end
 for other,room in pairs(rooms)do if other~=key and room.layoutSlot==d.layoutSlot then return false,'Each room needs a separate private layout slot'end end
 local layers={};for _,layer in ipairs(ns.WardenWorldScenes.layers)do layers[layer]=true end
 local plateIDs={};for _,p in ipairs(d.plates)do
  if not id(p[1])or plateIDs[p[1]]or type(p[2])~='string'or not layers[p[3]]or not vector(p[4],4)or p[4][3]<=0 or p[4][4]<=0 then return false,'Invalid or duplicate room plate'end;plateIDs[p[1]]=true
 end
 local fence=d.navigation.floorUV
 if type(fence[1])=='table'then if #fence<3 or #fence>16 then return false,'Floor polygon budget'end;for _,p in ipairs(fence)do if not vector(p,2)then return false,'Invalid floor point'end end
 elseif not vector(fence,4)or fence[3]<=fence[1]or fence[4]<=fence[2]then return false,'Invalid floor rectangle'end
 local objectIDs={};d.props=d.props or{};d.residents=d.residents or{};d.outside=d.outside or{};d.routes=d.routes or{};d.airOccluders=d.airOccluders or{}
 if type(d.props)~='table'or type(d.residents)~='table'or type(d.outside)~='table'or type(d.routes)~='table'or type(d.airOccluders)~='table'then return false,'Invalid room collections'end
 if #d.props>32 or #d.residents>12 or #d.outside>8 then return false,'Room object budget'end
 for _,group in ipairs({d.props,d.residents,d.outside})do for _,p in ipairs(group)do
  if not id(p.id)or objectIDs[p.id]or not vector(p.at,3)then return false,'Duplicate or invalid room instance'end;objectIDs[p.id]=true
  -- Quarantined prototypes remain valid authored references. Runtime actor
  -- admission blocks their renderer load; registration must retain the room.
  if p.modelKey and not(ns.WardenNativeScene.BundledPath(p)or ns.WardenNativeScene.ModelQuarantine and ns.WardenNativeScene.ModelQuarantine(p))then return false,'Unknown bundled model key'end
  if p.itemID and(not items[p.itemID]or p.fileID~=items[p.itemID].fileID)then return false,'Unknown or mismatched item template'end
 end end
 local props={};for _,p in ipairs(d.props)do props[p.id]=p end
 if d.reader and(not props.desk or not props['room-book'])then return false,'Reader room needs its desk and book anchors'end
 if d.flags~=nil and(type(d.flags)~='table'or #d.flags>12)then return false,'Flag budget'end
 local flagIDs={};for _,f in ipairs(d.flags or{})do
  if type(f)~='table'or not finite(f.id)or flagIDs[f.id]or(f.kind~='guild'and f.kind~='alliance')or not props[f.pole or'flagpole']or not(vector(f.box,3)or vector(f.box,4))or f.box[3]<=0 or f.box[4]and f.box[4]<=0 or f.layer and not layers[f.layer]then return false,'Invalid flag attachment'end
  if f.mount~=nil and f.mount~='architecture'or f.aspect~=nil and(not finite(f.aspect)or f.aspect<.4 or f.aspect>2)then return false,'Invalid flag surface'end
  if f.asset~=nil and(f.asset~='guild-hanging90'or f.kind~='guild'or not ns.WardenSceneAssets.assets[f.asset])then return false,'Unknown banner render'end
  flagIDs[f.id]=true
 end
 for _,p in ipairs(d.props)do local seen={};local target=p.support
  while target do if not props[target]or seen[target]or target==p.id then return false,'Missing or cyclic support'end;seen[target]=true;target=props[target].support end
 end
 d.id=key;rooms[key]=d;if not revision then roomOrder[#roomOrder+1]=key end
 if C.onRegister then C.onRegister(key,d)end;return true
end
function C.RegisterRoom(key,spec)return installRoom(key,spec,false)end
-- Shipped defaults only, installed during addon loading. This changes no saved
-- layouts, room instances or travel links; callers still receive owned copies.
function C.ReviseBundledRoom(key,spec)return installRoom(key,spec,true)end
function C.Room(key)return rooms[key]and copy(rooms[key])end
function C.HasRoom(key)return rooms[key]~=nil end
function C.Rooms()local out={};for _,key in ipairs(roomOrder)do out[#out+1]={id=key,label=rooms[key].label,interior=rooms[key].interior==true}end;return out end
function C.RegisterConnection(key,from,to,options)
 if not id(key)or links[key]or #linkOrder>=C.MAX_LINKS or not rooms[from]or not rooms[to]or from==to then return false,'Invalid, duplicate or unresolved room connection'end
 local ok,d=pcall(copy,options or{});if not ok then return false,d end
 if type(d)~='table'or d.label~=nil and type(d.label)~='string'then return false,'Invalid connection options'end
 if d.arrival and(not vector(d.arrival,3)or math.abs(d.arrival[1])>80 or math.abs(d.arrival[2])>80 or math.abs(d.arrival[3])>8)then return false,'Invalid arrival anchor'end
 if d.portal then
  if type(d.portal)~='table'then return false,'Invalid walking portal'end
  local fields={clickUV=4,triggerUV=4,approachUV=2,arrivalUV=2,arrivalWalkUV=2}
  for name in pairs(d.portal)do if not fields[name]then return false,'Unknown walking portal field'end end
  for name,n in pairs(fields)do local point=d.portal[name];if not vector(point,n)then return false,'Incomplete walking portal'end
   for i=1,n do if point[i]<0 or point[i]>1 then return false,'Walking portal outside scene'end end
   if n==4 and(point[3]<=point[1]or point[4]<=point[2]or point[3]-point[1]>.4 or point[4]-point[2]>.4)then return false,'Invalid walking portal area'end
  end
 end
 links[key]={id=key,from=from,to=to,label=d.label or rooms[to].label,arrival=d.arrival,portal=d.portal};linkOrder[#linkOrder+1]=key;return true
end
function C.Connection(key,from)local row=links[key];if not row or row.from~=from then return nil,'Connection is not available from this room'end;return copy(row)end
function C.Connections(from)local out={};for _,key in ipairs(linkOrder)do if links[key].from==from then out[#out+1]=copy(links[key])end end;return out end
-- Safe cancellation rather than a route/transition queue. Only local UI invokes it.
function C.Travel(realm,key)
 local current=realm.ActiveRoom and realm:ActiveRoom();local link,why=C.Connection(key,current and current.key)
 if not link then return false,why end
 return realm:OpenRoom(link.to,link.arrival)
end
