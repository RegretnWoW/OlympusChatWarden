-- Local scene rectangles only. Canonical connections are never rewritten.
local _,ns=...;local C=ns.WardenRoomCatalogue
local get,list=C.Connection,C.Connections;local overrides={}
function C.PortalDefaults(room)return list(room)end
function C.PortalRectangle(room,id,field,r)
 if ns.AetherLive and ns.AetherLive.World and ns.AetherLive.World.active then return false,'Live uses the official world geometry'end
 local link=get(id,room);if not link or not link.portal or(field~='clickUV'and field~='triggerUV')then return false,'Unknown entrance'end
 if r~=nil then
  if type(r)~='table'or getmetatable(r)then return false,'Invalid entrance box'end
  for _,k in ipairs({'x','y','width','height','scale'})do local n=r[k];if type(n)~='number'or n~=n or math.abs(n)==math.huge then return false,'Finite entrance dimensions required'end end
  if r.x<0 or r.y<0 or r.width<=0 or r.height<=0 or r.scale<.05 or r.scale>5 or r.x+r.width*r.scale>1 or r.y+r.height*r.scale>1 then return false,'Entrance box must stay inside the scene'end
  if r.hidden~=nil and type(r.hidden)~='boolean'then return false,'Invalid entrance visibility'end
 end
 overrides[room]=overrides[room]or{};overrides[room][id]=overrides[room][id]or{};overrides[room][id][field]=r and{r.x,r.y,r.x+r.width*r.scale,r.y+r.height*r.scale,hidden=r.hidden==true}or nil;return true
end
local function apply(row)
 if ns.AetherLive and ns.AetherLive.World and ns.AetherLive.World.active then return row end
 local values=overrides[row.from]and overrides[row.from][row.id];if not values or not row.portal then return row end
 for field,r in pairs(values)do
  if r.hidden then row.portal=nil;return row end
  row.portal[field]={r[1],r[2],r[3],r[4]}
  if field=='triggerUV'then row.portal.approachUV={(r[1]+r[3])/2,(r[2]+r[4])/2}end
 end;return row
end
function C.Connection(id,room)local row,why=get(id,room);return row and apply(row),why end
function C.Connections(room)local rows=list(room);for i,row in ipairs(rows)do rows[i]=apply(row)end;return rows end
