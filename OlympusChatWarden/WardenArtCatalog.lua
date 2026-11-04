-- Curated presentation references. No collectors, saved state, network records,
-- startup enumeration or Blizzard image files are introduced by this catalogue.
local _,ns=...
local C={VERSION=1,entries=ns.WardenArtCandidates or {},byID={},reviews={},cache={},order={},CACHE_LIMIT=64}
ns.WardenArtCatalog=C
C.sources={['classic-atlas']='https://github.com/Hoizame/WoW_ClassicUIResources/blob/master/RawData/UiTextureAtlasElement.lua',
 ['atlas-info']='https://github.com/Resike/BlizzardInterfaceResources/blob/master/Resources/Data/AtlasInfo.lua',
 ['blizzard-ui-source']='Installed Blizzard UI XML / existing client texture references',
 ['blizzard-api']='Installed Blizzard API documentation: Texture / Item / Spell / Map'}
for _,e in ipairs(C.entries)do C.byID[e.id]=e end
local function id(v)return type(v)=='number'and v==v and v>0 and v<2147483648 and v==math.floor(v)end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<10000000 end
local function call(f,...)if type(f)~='function'then return end;local ok,a=pcall(f,...);if ok then return a end end
local function path(v)return id(v)or type(v)=='string'and #v<256 and v:match('^[Ii]nterface[\\/]')and not v:find('%.%.')end
function C.Client()
 local target=ns.ClientBuild and ns.ClientBuild.target or 'unknown'
 return ns.ClientCompat and (ns.ClientCompat.client..'/'..target)or target
end
function C.Environment()return WARDEN_SIMULATOR_ISOLATED and 'simulator' or 'native'end
function C.Fallback(purpose)
 return {path=ns.WardenArt.Path('Divider'),uv={0,1,0,1},width=512,height=24,alpha=.55,fallback=true,purpose=purpose,status='Olympus fallback'}
end
function C.ValidateInfo(a)
 if type(a)~='table'or not path(a.file or a.filename)then return nil,'No usable texture reference'end
 if not finite(a.width)or not finite(a.height)or a.width<1 or a.height<1 or a.width>8192 or a.height>8192 then return nil,'Invalid / oversized dimensions'end
 local uv={a.leftTexCoord,a.rightTexCoord,a.topTexCoord,a.bottomTexCoord}
 for i=1,4 do local v=uv[i];if not finite(v)or v<0 or v>1 then return nil,'Invalid crop'end end
 if #uv~=4 or uv[1]>=uv[2]or uv[3]>=uv[4]then return nil,'Invalid crop'end
 return {path=a.file or a.filename,uv=uv,width=a.width,height=a.height,alpha=1,status='API-reported; visual inspection required'}
end
function C.ClearCache()C.cache={};C.order={}end
function C.Probe(entry)
 if type(entry)=='string'then entry=C.byID[entry]end
 if type(entry)~='table'or type(entry.id)~='string'or type(entry.ref)~='string'then return nil,'Malformed registry entry'end
 local key=C.Client()..':'..entry.id;local cached=C.cache[key];if cached then return cached.art,cached.reason end
 local art,why
 if entry.kind=='atlas'then
  local api=C_Texture and C_Texture.GetAtlasInfo
  if not api then why='Atlas API unsupported'else local info=call(api,entry.ref);if info then art,why=C.ValidateInfo(info)else why='Atlas unavailable'end end
 elseif entry.kind=='texture'and path(entry.ref)then
  local uv=entry.uv or {0,1,0,1}
  art,why=C.ValidateInfo({file=entry.ref,width=entry.width or 256,height=entry.height or 128,leftTexCoord=uv[1],rightTexCoord=uv[2],topTexCoord=uv[3],bottomTexCoord=uv[4]})
  if art then art.status='Path reference only; visual inspection required';art.alpha=entry.alpha or 1 end
 else why='Requires an explicit recorded identifier'end
 if art then art.id=entry.id;art.ref=entry.ref;art.kind=entry.kind end
 C.order[#C.order+1]=key;if #C.order>C.CACHE_LIMIT then C.cache[table.remove(C.order,1)]=nil end
 C.cache[key]={art=art,reason=why};return art,why
end
function C.Review(entry,purpose,approved)
 if not C.byID[entry]or type(purpose)~='string'or #purpose>80 then return false end
 C.reviews[C.Environment()..':'..C.Client()..':'..purpose..':'..entry]={approved=approved==true,environment=C.Environment(),client=C.Client()};return true
end
-- Editorial approvals are separate from native render results. This initially
-- empty table is populated only for visually inspected, packaged candidates.
C.production={}
C.purposes={
 ['journal.chapter.banner']={'Banner-SmallFiligree','Banner-BgFiligree'},
 ['journal.prologue.alliance']={'AllianceAssaultsMapBanner'},
 ['journal.prologue.horde']={'HordeAssaultsMapBanner'},
 ['journal.quest.header']={'QuestNormal'},
 ['journal.dungeon.victory']={'ScenarioTrackerToast-FinalFiligree','GarrMission_RewardsBanner'},
 ['journal.raid.victory']={'GarrMission_RewardsBanner','ScenarioTrackerToast-FinalFiligree'},
 ['journal.chapter.divider']={'Banner-SmallFiligree'},
 ['journal.pvp']={'combat_swords-icon'},['journal.guild']={'hud-microbutton-Guild-Banner'},
 ['journal.milestone']={'StoryHeader-CheevoIcon'},['journal.recollection']={'Banner-SmallFiligree'},
 ['journal.loot.rare']={'Garr_TownHallBanner_LevelFiligree'}}
function C.Select(purpose)
 for _,name in ipairs(C.purposes[purpose]or {})do
  local entry
  for _,e in ipairs(C.entries)do if e.ref==name or e.id==name then entry=e;break end end
  if entry then local key=C.Environment()..':'..C.Client()..':'..purpose..':'..entry.id;local review=C.reviews[key]
   if not(review and not review.approved)and (review and review.approved or C.production[name])then
    local art=C.Probe(entry);if art then art.purpose=purpose;art.alpha=entry.alpha or .65;return art end
   end
  end
 end
 return C.Fallback(purpose)
end
function C.Dynamic(kind,context)
 if type(context)~='table'or context.recorded~=true or not id(context.id)then return nil,'No recorded identifier'end
 local icon
 if kind=='item'then icon=call(C_Item and C_Item.GetItemIconByID,context.id)or call(GetItemIcon,context.id)
 elseif kind=='spell'then icon=call(C_Spell and C_Spell.GetSpellTexture,context.id)or call(GetSpellTexture,context.id)
 else return nil,'Unsupported dynamic icon'end
 if not path(icon)then return nil,'Icon unavailable'end
 return {path=icon,uv={0,1,0,1},width=64,height=64,alpha=1,dynamic=kind,id=context.id,status='Recorded reference; client icon'}
end
function C.Class(context)
 if type(context)~='table'or context.recorded~=true or not id(context.id)or type(GetClassInfo)~='function'then return nil end
 local ok,_,token=pcall(GetClassInfo,context.id);local coords=ok and type(token)=='string'and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[token]
 if type(coords)~='table'or #coords~=4 then return nil end
 return C.ValidateInfo({file='Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES',width=64,height=64,leftTexCoord=coords[1],rightTexCoord=coords[2],topTexCoord=coords[3],bottomTexCoord=coords[4]})
end
function C.Map(context)
 if type(context)~='table'or context.recorded~=true or not id(context.id)then return nil,'No recorded map identifier'end
 local layers=call(C_Map and C_Map.GetMapArtLayers,context.id);local layer=type(layers)=='table'and layers[1]
 if type(layer)~='table'then return nil,'Map artwork API unavailable'end
 for _,key in ipairs({'layerWidth','layerHeight','tileWidth','tileHeight'})do if not finite(layer[key])or layer[key]<=0 or layer[key]>8192 then return nil,'Invalid map geometry'end end
 local cols,rows=math.ceil(layer.layerWidth/layer.tileWidth),math.ceil(layer.layerHeight/layer.tileHeight)
 if cols*rows>12 then return nil,'Map exceeds 12-tile budget'end
 local textures=call(C_Map.GetMapArtLayerTextures,context.id,1);if type(textures)~='table'or #textures~=cols*rows then return nil,'Incomplete map artwork'end
 local out={width=layer.layerWidth,height=layer.layerHeight,tiles={},mapID=context.id}
 for i=1,cols*rows do local file=textures[i]
  if not id(file)then return nil,'Invalid map tile'end
  local x,y=((i-1)%cols)*layer.tileWidth,math.floor((i-1)/cols)*layer.tileHeight
  local w,h=math.min(layer.tileWidth,layer.layerWidth-x),math.min(layer.tileHeight,layer.layerHeight-y)
  out.tiles[i]={path=file,x=x,y=y,width=w,height=h,uv={0,w/layer.tileWidth,0,h/layer.tileHeight},alpha=.65}
 end
 return out
end
function C.MapBanner(context)
 if type(context)~='table'or context.recorded~=true or not id(context.id)then return nil end
 local banners=call(C_Map and C_Map.GetMapBannersForMap,context.id)
 local name=type(banners)=='table'and banners[1]and banners[1].atlasName
 if type(name)=='string'and #name<=160 then local info=call(C_Texture and C_Texture.GetAtlasInfo,name);return C.ValidateInfo(info)end
end
function C.Apply(texture,art)
 if not art or not path(art.path)then art=C.Fallback()end
 local ok=false
 if art.kind=='atlas'and texture.SetAtlas then ok=pcall(texture.SetAtlas,texture,art.ref,false)end
 if not ok then texture:SetTexture(art.path);texture:SetTexCoord(unpack(art.uv or {0,1,0,1}))end
 texture:SetAlpha(art.alpha or 1);return art
end
-- Existing public art facade remains the single point used by presentation.
ns.WardenArt.Catalog=C
function ns.WardenArt.Semantic(purpose)return C.Select(purpose)end
