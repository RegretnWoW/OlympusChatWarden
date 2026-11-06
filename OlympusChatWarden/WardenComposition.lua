-- Shared, bounded art recipes. Only this catalogue can name a texture. No remote
-- paths, URLs, scripts, history references, or entitlement claims are accepted.
local _,ns=...
local C={VERSION=3,MAX_LAYERS=12,MAX_TEXT=64};ns.WardenComposition=C
C.base='Interface\\AddOns\\OlympusChatWarden\\Media\\Journal3\\'
C.catalog={}
local ids={'woodland','westfall','barrens','greattree','deadmines','molten','battleground','haunted','jungle','snow','dragon','arcane','laurel','banner','nameplate','corner'}
for n,id in ipairs(ids)do local col,row=(n-1)%4,math.floor((n-1)/4)
 C.catalog[id]={path=C.base..'Mementos.tga',uv={col/4,(col+1)/4,row/4,(row+1)/4},title=id,aspect=id=='banner'and .5 or 1,playerSafe=true,version=1}
end
local function plain(t)return type(t)=='table'and getmetatable(t)==nil end
local function finite(n,a,b)return type(n)=='number'and n==n and n>=a and n<=b end
local function artID(v)return type(v)=='string'and #v<=96 and v:match('^[a-z][a-z0-9%-:]*$')~=nil end
local function keys(t,allowed)if not plain(t)then return false end;for k in pairs(t)do if not allowed[k]then return false end end;return true end
C.charms={seal=5,book=6,flower=7,fang=8,sword=9,ribbon=10,banner=11,laurel=12,stone=13,hammer=14,crystal=15,medal=16}

-- Commemorative symbols, not item ownership. Quest identities come from the
-- preserved QuestData source; boss IDs resolve through ChronicleRunEndpoints.
C.memories={
 {key='quest-18',slot=1,title='Northshire bandanna clasp',quest=18},
 {key='quest-166',slot=2,title='VanCleef wanted-notice seal',quest=166},
 {key='quest-176',slot=3,title='Hogger bounty seal',quest=176},
 {key='quest-114',slot=4,title='Maybell’s liquor-and-letter pin',quest=114},
 {key='boss-vancleef',slot=5,title='Edwin VanCleef mask pin',boss='Edwin VanCleef',map=36},
 {key='boss-arugal',slot=6,title='Arugal moon-wolf seal',boss='Archmage Arugal',map=33},
 {key='boss-mutanus',slot=7,title='Mutanus dream-eye pin',boss='Mutanus the Devourer',map=43},
 {key='boss-thermaplugg',slot=8,title='Thermaplugg engineering cog',boss='Mekgineer Thermaplugg',map=90},
 {key='boss-archaedas',slot=9,title='Archaedas stone disc',boss='Archaedas',map=70},
 {key='boss-theradras',slot=10,title='Theradras earth-crown pin',boss='Princess Theradras',map=349},
 {key='boss-eranikus',slot=11,title='Eranikus dream-eye seal',boss='Shade of Eranikus',map=109},
 {key='boss-thaurissan',slot=12,title='Thaurissan imperial seal',boss='Emperor Dagran Thaurissan',map=230},
 {key='boss-rivendare',slot=13,title='Rivendare knight’s seal',boss='Baron Rivendare',map=329},
 {key='boss-ragnaros',slot=14,title='Ragnaros firelord emblem',boss='Ragnaros',map=409},
 {key='boss-onyxia',slot=15,title='Onyxia dragon-eye pendant',boss='Onyxia',map=249},
 {key='boss-nefarian',slot=16,title='Nefarian wing-and-scepter pin',boss='Nefarian',map=469}}
C.memoryByKey={};for _,m in ipairs(C.memories)do C.memoryByKey[m.key]=m;C.charms[m.key]=m.slot end
C.stages={'Ink stamp','Colored stamp','Paper drawing','Colored paper drawing','Ornamented paper','Metal-mounted keepsake'}
function C.Validate(v)
 if not keys(v,{version=true,layers=true,base=true,catalog=true})or v.version~=1 or(v.catalog~=nil and not finite(v.catalog,1,10000))or(v.base~=nil and not({blank=true,cover=true,banner=true,collection=true})[v.base])or not plain(v.layers)or #v.layers>C.MAX_LAYERS then return false,'ART_RECIPE'end
 local n=0;for k in pairs(v.layers)do if not finite(k,1,#v.layers)or k%1~=0 then return false,'ART_ARRAY'end;n=n+1 end;if n~=#v.layers then return false,'ART_ARRAY'end
 for _,l in ipairs(v.layers)do
  if not keys(l,{art=true,x=true,y=true,w=true,h=true,rotation=true,opacity=true,tint=true,text=true,growth=true,stage=true,charms=true})or not artID(l.art)
   or not finite(l.x,0,1000)or not finite(l.y,0,1000)or not finite(l.w,20,1000)or not finite(l.h,20,1000)
   or l.x+l.w>1000 or l.y+l.h>1000 or not finite(l.rotation or 0,-180,180)or not finite(l.opacity or 100,10,100)then return false,'ART_LAYER'end
  if l.tint~=nil and not finite(l.tint,1,8)then return false,'ART_TINT'end
  if l.growth~=nil and(not finite(l.growth,0,3)or l.growth%1~=0)then return false,'ART_GROWTH'end
  if l.stage~=nil and(not finite(l.stage,1,6)or l.stage%1~=0)then return false,'ART_STAGE'end
  if l.charms~=nil then
   if not plain(l.charms)or #l.charms>4 then return false,'ART_MEMENTOS'end
   local count,seen=0,{};for key,value in pairs(l.charms)do
    if not finite(key,1,#l.charms)or key%1~=0 or not C.charms[value]or seen[value]then return false,'ART_MEMENTOS'end
    if C.memoryByKey[value]and C.memoryByKey[value].questStory and(v.catalog or 1)<3 then return false,'ART_CATALOG'end
    count=count+1;seen[value]=true
   end
   if count~=#l.charms then return false,'ART_MEMENTOS'end
  end
  if l.text~=nil and(type(l.text)~='string'or #l.text>C.MAX_TEXT or l.text:find('[|%z\1-\31]'))then return false,'ART_TEXT'end
 end
 return true
end
function C.Copy(v)if not C.Validate(v)then return end;return ns.Athena.Copy(v)end
local function atlasCell(n)local col,row=(n-1)%4,math.floor((n-1)/4);return{col/4+.002,(col+1)/4-.002,row/4+.002,(row+1)/4-.002}end
-- A single artifact keeps its seal, paper and regional identity as it develops.
-- These are cosmetic recipe stages, never evidence of a clear or an award.
local function LegacyPieces(l,catalogVersion)
 local a=(not catalogVersion or catalogVersion==1)and C.catalog[l.art]
 if not a then return{{art=C.catalog.nameplate,x=0,y=0,w=1,h=1}},true end
 if not a.activity then return{{art=a,x=0,y=0,w=1,h=1}}end
 local stage=l.stage or(l.growth and l.growth+1)or 1
 local pieces={};local function add(art,x,y,w,h,color,desaturated)
  pieces[#pieces+1]={art=art,x=x,y=y,w=w,h=h,color=color,desaturated=desaturated==true}
 end
 local paper={path=C.base..'Paper.tga',uv={0,1,0,1}}
 local ink={path=C.base..'InkSymbols.tga',uv=atlasCell(a.activity.stamp)}
 if stage>=6 then add(a,0,0,1,1)end
 local margin=stage>=5 and .12 or .035
 add(paper,margin,margin,1-margin*2,1-margin*2,{.92,.85,.70})
 if stage<=2 then
  local stamp=stage==1 and ink or{path=C.base..'InkColorized.tga',uv=ink.uv}
  add(stamp,.22,.17,.56,.56,stage==1 and{.29,.19,.12}or{1,1,1},stage==1)
 else
  -- Crop away the advanced tile's metal border for its paper-art stages.
  local uv=a.uv;local dx,dy=uv[2]-uv[1],uv[4]-uv[3]
  local drawing={path=a.path,uv={uv[1]+dx*.16,uv[2]-dx*.16,uv[3]+dy*.16,uv[4]-dy*.16}}
  add(drawing,.17,.15,.66,.66,stage==3 and{.69,.60,.47}or{1,1,1},stage==3)
  -- The first seal stays embedded in the finished record.
  add(ink,.70,.73,.18,.18,{.34,.22,.13},true)
 end
 if stage==5 then
  local uv=atlasCell(12)
  add({path=C.base..'InkColorized.tga',uv=uv},.015,.28,.16,.40,{.85,.77,.53})
  add({path=C.base..'InkColorized.tga',uv={uv[2],uv[1],uv[3],uv[4]}},.825,.28,.16,.40,{.85,.77,.53})
 end
 for i,name in ipairs(l.charms or{})do
  local positions={{.03,.60},{.70,.05},{.68,.65},{.04,.04}};local p=positions[i]
  add({path=C.base..'InkColorized.tga',uv=atlasCell(C.charms[name])},p[1],p[2],.24,.24)
 end
 return pieces,false,stage
end

-- Catalogue 1 signed snapshots retain their original presentation.
function C.Pieces(l,catalogVersion)
 if not catalogVersion or catalogVersion==1 then return LegacyPieces(l,catalogVersion)end
 local a=(catalogVersion==2 or catalogVersion==3)and C.catalog[l.art]
 if not a then return{{art=C.catalog.nameplate,x=0,y=0,w=1,h=1}},true end
 if not a.activity then return{{art=a,x=0,y=0,w=1,h=1}}end
 local stage=l.stage or(l.growth and l.growth+1)or 1;local pieces={}
 local function add(art,x,y,w,h,color,gray,role)pieces[#pieces+1]={art=art,x=x,y=y,w=w,h=h,color=color,desaturated=gray==true,role=role}end
 local plaques=ns.WardenPlaqueArt;local mount=stage>=6 and plaques and(plaques.byID[l.art]or plaques.fallbacks[a.activity.family])
 -- The metal keepsake collects its stamp and mementos inside the subject's
 -- existing inner field. Earlier paper stages retain their edge decorations.
 local inset=mount and mount.inset and mount.inset[math.min(4,#(l.charms or{}))+1]
 -- Catalogue 2 keeps its accepted presentation. Catalogue 3 uses the same
 -- mount pixels as a recessed back and a separately occluding front rim.
 local materials=catalogVersion==3 and mount and mount.layers
 if mount then add(materials and materials.back or mount,0,0,1,1,nil,false,materials and'metal-back'or'metal')end
 local ink={path=C.base..string.format('Stamps%02d.tga',a.activity.sheet),uv=a.activity.uv}
 -- Stamps sit directly on the journal. Developed artwork already includes its
 -- own irregular paper edges; no additional rectangular canvas is needed.
 if stage<=2 then add(ink,.12,.10,.76,.66,stage==1 and{.34,.24,.16}or{1,1,1},stage==1,'pigment')
 else
  -- Preserve the entire approved illustration, including its irregular edges.
  -- The final metal is composited above this intact paper, not used to crop it.
  add({path=a.path,uv=a.uv},mount and .12 or .075,mount and .10 or .075,mount and .76 or .85,mount and .76 or .85,stage==3 and{.69,.60,.47}or{1,1,1},stage==3,'pigment')
  -- Once colored, the original stamp stays colored, including on metal.
  local p=inset and inset[1]or{.71,.75,.18,.16}
  add(ink,p[1],p[2],p[3],p[4],{1,1,1},false,'seal')
 end
 if stage>=5 then
  local uv=atlasCell(12)
  add({path=C.base..'InkColorized.tga',uv=uv},.015,.28,.16,.40,{.85,.77,.53},false,'ornament')
  add({path=C.base..'InkColorized.tga',uv={uv[2],uv[1],uv[3],uv[4]}},.825,.28,.16,.40,{.85,.77,.53},false,'ornament')
 end
 if stage>=6 and not mount then
  local uv=a.uv;local dx,dy=uv[2]-uv[1],uv[4]-uv[3];local rim=.13
  add({path=a.path,uv={uv[1],uv[2],uv[3],uv[3]+dy*rim}},0,0,1,rim,nil,false,'metal')
  add({path=a.path,uv={uv[1],uv[2],uv[4]-dy*rim,uv[4]}},0,1-rim,1,rim,nil,false,'metal')
  add({path=a.path,uv={uv[1],uv[1]+dx*rim,uv[3]+dy*rim,uv[4]-dy*rim}},0,rim,rim,1-rim*2,nil,false,'metal')
  add({path=a.path,uv={uv[2]-dx*rim,uv[2],uv[3]+dy*rim,uv[4]-dy*rim}},1-rim,rim,rim,1-rim*2,nil,false,'metal')
 end
 for i,name in ipairs(stage>=5 and l.charms or{})do local pos={{.03,.60},{.70,.05},{.68,.65},{.04,.04}};local p=inset and inset[i+1]or{pos[i][1],pos[i][2],.24,.24}
  add({path=C.memoryByKey[name]and(C.memoryByKey[name].path or C.base..'MemoryPins.tga')or C.base..'InkColorized.tga',uv=atlasCell(C.charms[name])},p[1],p[2],p[3],p[4],nil,false,'memento')
 end
 if materials then
  add(materials.glass,0,0,1,1,nil,false,'glass');pieces[#pieces].alpha=.35
  add(materials.front,0,0,1,1,nil,false,'metal')
 end
 return pieces,false,stage
end
local TL,BL,TR,BR=UPPER_LEFT_VERTEX or 1,LOWER_LEFT_VERTEX or 2,UPPER_RIGHT_VERTEX or 3,LOWER_RIGHT_VERTEX or 4
function C.Quad(t,parent,points)
 local x1,y1,x2,y2,x3,y3,x4,y4=unpack(points)
 local loX,hiX=math.min(x1,x2,x3,x4),math.max(x1,x2,x3,x4);local loY,hiY=math.min(y1,y2,y3,y4),math.max(y1,y2,y3,y4)
 t:ClearAllPoints();t:SetPoint('TOPLEFT',parent,'TOPLEFT',loX,-loY);t:SetSize(math.max(.01,hiX-loX),math.max(.01,hiY-loY))
 if t.SetVertexOffset then t:SetVertexOffset(TL,x1-loX,loY-y1);t:SetVertexOffset(TR,x2-hiX,loY-y2);t:SetVertexOffset(BL,x3-loX,hiY-y3);t:SetVertexOffset(BR,x4-hiX,hiY-y4)end
end
-- Flat profile display contains the artwork; physical book/shelf projections
-- continue to use their explicit surface transform.
function C.DisplayAspect(v)
 if type(v)~='table'or v.base or type(v.layers)~='table'or #v.layers~=1 then return 1 end
 local l=v.layers[1];if l.x~=0 or l.y~=0 or l.w~=1000 or l.h~=1000 or(l.rotation or 0)~=0 then return 1 end
 for _,piece in ipairs(C.Pieces(l,v.catalog))do if piece.role=='metal'or piece.role=='paper'then
  local uv=piece.art.uv;local aspect=(uv[2]-uv[1])/math.max(.00001,uv[4]-uv[3]);return math.max(.4,math.min(2.5,aspect))
 end end;return 1
end
function C.Render(parent,v,project)
 local ok,why=C.Validate(v);if not ok then return false,why end
 parent.compositionPool=parent.compositionPool or{}
 parent.compositionLayers=parent.compositionLayers or{}
 for _,r in ipairs(parent.compositionPool)do r.texture:Hide();if r.label then r.label:Hide()end end
 if parent.compositionText then parent.compositionText:Clear()end
 for _,host in ipairs(parent.compositionLayers)do host:Hide();if host.compositionText then host.compositionText:Clear()end end
 local w,h=parent:GetWidth(),parent:GetHeight()
 if v.base=='cover'then
  parent.compositionBase=parent.compositionBase or parent:CreateTexture(nil,'BACKGROUND');local t=parent.compositionBase
  local ch=h;local cw=math.min(w,ch*.76);local left=(w-cw)/2;t:SetTexture(C.base..'FrontCover.tga');t:ClearAllPoints();t:SetPoint('TOPLEFT',left,0);t:SetSize(cw,ch);t:Show()
  project=project or function(u,vv)return left+cw*(.16+u*.71),ch*(.14+vv*.65)end
 elseif parent.compositionBase then parent.compositionBase:Hide()end
 local used=0
 for i,l in ipairs(v.layers)do
  -- Native texture batching does not promise creation order for equal draw
  -- priorities. One bounded host per artifact preserves recipe stacking;
  -- Explicit sublevels preserve the artifact's material stack. Separate
  -- artifact hosts prevent another badge's backing from covering this rim.
  -- Composition labels are flat quads, so they stay on their artifact host
  -- instead of inheriting the curved reader's sixteen depth buckets.
  local host=parent.compositionLayers[i]
  if not host then host=CreateFrame('Frame',nil,parent);host:SetAllPoints(parent);host:EnableMouse(false);parent.compositionLayers[i]=host end
  host:SetFrameLevel(parent:GetFrameLevel()+i);host:Show()
  local function point(u,vv)
   local x=u*l.w;x=x+l.x;x=x/1000;local y=vv*l.h;y=y+l.y;y=y/1000
   local angle=(l.rotation or 0)*math.pi;angle=angle/180
   local cx=l.w/2;cx=cx+l.x;cx=cx/1000;local cy=l.h/2;cy=cy+l.y;cy=cy/1000
   local dx=x-cx;dx=dx*w;local dy=y-cy;dy=dy*h
   local cosine,sine=math.cos(angle),math.sin(angle)
   local rx=dx*cosine;local ry=dy*sine;rx=rx-ry;local centerX=cx*w;rx=rx+centerX;x=rx/w
   local sx=dx*sine;local sy=dy*cosine;sx=sx+sy;local centerY=cy*h;sx=sx+centerY;y=sx/h
   if project then return project(x,y)end;return x*w,y*h
  end
  local pieces,missing,stage=C.Pieces(l,v.catalog);local first
  if parent.compositionAnimation and (parent.compositionAnimation.to==2 or parent.compositionAnimation.to==4)then
   local gray={};for k,value in pairs(l)do gray[k]=value end;gray.stage=parent.compositionAnimation.to-1
   local base=C.Pieces(gray,v.catalog);local combined={}
   for _,piece in ipairs(base)do piece.role='underpaint';combined[#combined+1]=piece end
   for _,piece in ipairs(pieces)do if piece.role=='pigment'then combined[#combined+1]=piece end end;pieces=combined
  end
  local roleIndex={}
  for pieceIndex,original in ipairs(pieces)do
   local piece={};for k,value in pairs(original)do piece[k]=value end
   local anim=parent.compositionAnimation
   if anim and (anim.layer==nil or anim.layer==i) then
    local q=anim.progress or 0
    if piece.role=='pigment'and(anim.to==2 or anim.to==4)then
     piece.h=piece.h*q;local uv=piece.art.uv;piece.art={path=piece.art.path,uv={uv[1],uv[2],uv[3],uv[3]+(uv[4]-uv[3])*q}}
    elseif (piece.role=='ornament'and anim.to==5)or((piece.role=='metal'or piece.role=='metal-back'or piece.role=='glass')and anim.to==6)or(piece.role=='memento'and anim.to=='memento')then
     local direction=piece.x<.5 and -1 or 1;piece.x=piece.x+direction*.16*(1-q)^2;piece.y=piece.y-.06*math.sin(q*math.pi)*(1-q)
    end
   end
   used=used+1;local r=parent.compositionPool[used]
   if not r then r={texture=host:CreateTexture(nil,'ARTWORK'),label=host:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')};parent.compositionPool[used]=r end
   r.texture:SetParent(host);r.label:SetParent(host)
   local layer,sublevel='ARTWORK',math.max(-8,math.min(7,pieceIndex-9))
   if piece.role=='paper'then layer,sublevel='BORDER',0
   elseif piece.role=='underpaint'then sublevel=-8
   elseif piece.role=='pigment'then sublevel=-4
   elseif piece.role=='metal-back'then sublevel=4
   elseif piece.role=='metal'then
    if v.catalog==3 and stage==6 and ns.WardenPlaqueArt.materialVersion then layer,sublevel='OVERLAY',7 else sublevel=4 end
   elseif piece.role=='glass'then layer,sublevel='OVERLAY',6
   elseif piece.role=='ornament'then roleIndex.ornament=(roleIndex.ornament or 0)+1;layer,sublevel='OVERLAY',math.min(0,roleIndex.ornament-3)
   elseif piece.role=='seal'then layer,sublevel='OVERLAY',1
   elseif piece.role=='memento'then roleIndex.memento=(roleIndex.memento or 0)+1;layer,sublevel='OVERLAY',math.min(7,roleIndex.memento+1)end
   r.texture:SetDrawLayer(layer,sublevel);r.role=piece.role;r.artifact=i;r.pieceIndex=pieceIndex
   first=first or r;r.texture:SetTexture(piece.art.path);r.texture:SetTexCoord(unpack(piece.art.uv))
   if r.texture.SetDesaturated then r.texture:SetDesaturated(piece.desaturated==true)end
   local tint=l.tint and ns.WardenDrawing and ns.WardenDrawing.palette[l.tint]or{1,1,1};local color=piece.color or{1,1,1}
   if piece.role=='glass'then tint={1,1,1}end
   r.texture:SetVertexColor(tint[1]*color[1],tint[2]*color[2],tint[3]*color[3],(l.opacity or 100)/100*(piece.alpha or 1))
   local x1,y1=point(piece.x,piece.y);local x2,y2=point(piece.x+piece.w,piece.y);local x3,y3=point(piece.x,piece.y+piece.h);local x4,y4=point(piece.x+piece.w,piece.y+piece.h)
   C.Quad(r.texture,parent,{x1,y1,x2,y2,x3,y3,x4,y4});r.texture:Show()
  end
  local label=l.text;local a=C.catalog[l.art]
  if not label and stage and stage<=2 and a then label=a.title end
  if missing or label and label~=''then
   label=missing and'Artwork unavailable'or label
   if ns.AthenaBookTurnSurface and ns.JournalGlyphs then
    -- Reuse the reader's glyph engine so the inscription follows the same
    -- cover/rotation transform as its paper, including an edge-on cover pose.
    host.compositionText=host.compositionText or ns.AthenaBookTurnSurface.New(host)
    local s=host.compositionText;local start=s.used+1;local size=65;local length=math.min(850,ns.AthenaBookTurnSurface.Advance(label,size,'meta'))
    s:AddText('art',label,0,0,size,850,'meta');local color=stage and{.30,.22,.14}or{.68,.49,.24}
    for n=start,s.used do local glyph=s.pool[n]
     local function vertex(x,y)return point((1000-length)/2000+x/1000,.79+y/1000)end
     local x1,y1=vertex(glyph.x,glyph.y);local x2,y2=vertex(glyph.x+glyph.w,glyph.y);local x3,y3=vertex(glyph.x,glyph.y+glyph.h);local x4,y4=vertex(glyph.x+glyph.w,glyph.y+glyph.h)
     if glyph.fallback then
      local scale=math.max(.01,math.abs(x2-x1)/math.max(1,glyph.w));local f=glyph.fallback;f:SetParent(host);f:SetDrawLayer('OVERLAY');f:SetScale(scale);f:ClearAllPoints();f:SetPoint('TOPLEFT',parent,'TOPLEFT',x1/scale,-y1/scale);f:Show()
     else glyph.region:SetParent(host);glyph.region:SetDrawLayer('OVERLAY');C.Quad(glyph.region,parent,{x1,y1,x2,y2,x3,y3,x4,y4});glyph.region:SetVertexColor(color[1],color[2],color[3],(l.opacity or 100)/100);glyph.region:Show()end
    end
   else local x,y=point(.5,.79);local f=first.label;f:ClearAllPoints();f:SetPoint('CENTER',parent,'TOPLEFT',x,-y);f:SetWidth(math.max(20,l.w*w/1000));f:SetText(label);f:SetTextColor(.30,.22,.14);f:Show()end
  end
 end
 return true,#v.layers
end

-- Finite presentation. Hiding or interruption settles to the accepted recipe.
function C.Animate(parent,v,from,to,project)
 if not C.Validate(v)then return false end
 parent.compositionAnimator=parent.compositionAnimator or CreateFrame('Frame',nil,parent)
 local f=parent.compositionAnimator;f:SetScript('OnUpdate',nil);parent.compositionAnimation=nil
 if ns.DB and ns.DB.journalReducedMotion==true then return C.Render(parent,v,project)end
 local elapsed=0;parent.compositionAnimation={from=from,to=to,progress=0}
 local function finish()f:SetScript('OnUpdate',nil);parent.compositionAnimation=nil;C.Render(parent,v,project)end
 f.finishComposition=finish
 if not f.cleanupHook then f.cleanupHook=true;f:HookScript('OnHide',function()if parent.compositionAnimation and f.finishComposition then f.finishComposition()end end)end
 f:Show();C.Render(parent,v,project)
 if ns.WardenAudio then ns.WardenAudio.Play(to==6 and'art.metal'or'art.discover')end
 f:SetScript('OnUpdate',function(_,dt)
  if not parent:IsVisible()then finish();return end
  elapsed=elapsed+math.min(.1,math.max(0,dt));local q=math.min(1,elapsed/1.05)
  parent.compositionAnimation.progress=q*q*(3-2*q);C.Render(parent,v,project)
  if q==1 then finish()end
 end);return true
end
