-- Launch-only room registry from the retained, verified Forever zone catalogue.
-- Names are public reference data, never current-player location announcements.
local _,ns=...
local R={VERSION=1,byID={},order={}};ns.AetherPostRooms=R
local cities={['Stormwind City']=true,Ironforge=true,Darnassus=true,Orgrimmar=true,['Thunder Bluff']=true,Undercity=true}
local function slug(s)return s:lower():gsub("['’]",''):gsub('[^%w]+','-'):gsub('^%-',''):gsub('%-$','')end
local function add(id,title,category,source)
 if R.byID[id]then return end;local r={id=id,title=title,category=category,loreID=source};R.byID[id]=r;R.order[#R.order+1]=r
end
function R.Ensure()
 if not R.base then R.base=true;add('world','The World Hall','World');add('pvp','PvP','PvP');add('pve','PvE','PvE')end
 local L=ns.AthenaLoreCodex;if L and not R.loaded then
  for _,id in ipairs(L.order)do local e=L.byID[id];if e and e.kind=='place'and e.zoneCatalog then
   local title=e.title=='Stormwind'and'Stormwind City'or e.title;local city=cities[title];add((city and'city:'or'zone:')..slug(title),title,city and'Cities'or'Zones',id)
  end end;R.loaded=true
  table.sort(R.order,function(a,b)if a.category~=b.category then return a.category<b.category end;return a.title<b.title end)
 end
end
function R.Valid(id)R.Ensure();return type(id)=='string'and R.byID[id]~=nil end
function R.Get(id)R.Ensure();return R.byID[id]end
function R.List(category)R.Ensure();local rows={};for _,r in ipairs(R.order)do if not category or r.category==category then rows[#rows+1]=r end end;return rows end
function R.Suggest(place)R.Ensure();for _,r in ipairs(R.order)do if r.title==place or r.title=='Stormwind City'and place=='Stormwind'then return r.id end end;return'world'end
