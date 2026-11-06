-- Private, read-only zone playback. No sampling, saved state or public records.
local _,ns=...
local S,K,C=ns.ChronicleStore,ns.ChronicleCodec,ns.UI2Components
local R={VERSION=3,SCAN_SLICE=128,MAX_LINES=8192,MAX_EFFECTS=4096};ns.ChronicleReplay=R
local effectLabels={hearth='Hearthstone cast observed',['taxi-start']='Flight first observed',['taxi-end']='Flight ended: state observed',['session-start']='Confirmed login',['session-end']='Client session boundary; may be a reload',gap='Unrecorded interval'}
local function call(fn,...) if type(fn)~='function'then return end;local ok,a,b,c,d=pcall(fn,...);if ok then return a,b,c,d end end
local function plain(t)return ns.Readable(t)and type(t)=='table'and not getmetatable(t)end
function R.Allowed(owner)
 return owner==ns.Chronicle.Owner()and ns.Athena2.Permit('chronicle')and not S.loading and not S.blocked and S.Character(owner,false)~=nil
end
-- Only outdoor zone maps, or micro maps with a native rectangle on their zone.
-- World/native axes are deliberately never guessed or interpreted as UI axes.
function R.Map(id,cache)
 id=S.Integer(id,1,10000000);if not id then return end
 if cache[id]~=nil then return cache[id]or nil end
 local original=id;local info;local mapCall=ns.ChronicleRoute.MapCall
 for _=1,8 do
  info=mapCall('GetMapInfo',id)
  if not plain(info)then break end
  local mapType=S.Integer(info.mapType,0,6)
  if mapType==3 then
   local name=S.Text(info.name,144);if not name then break end
   local rect={0,1,0,1}
   if original~=id then
    local a,b,c,d=mapCall('GetMapRectOnMap',original,id)
    if not(S.Number(a,0,1)and S.Number(b,0,1)and S.Number(c,0,1)and S.Number(d,0,1)and a<b and c<d)then break end
    rect={a,b,c,d}
   end
   local out={id=id,name=name,rect=rect};cache[original]=out;return out
  end
  if mapType~=5 then break end -- never adopt dungeon/raid maps
  id=S.Integer(info.parentMapID,1,10000000);if not id then break end
 end
 cache[original]=false
end
local function eligible(e,owner)
 local l=e.location or {}
 return e.kind=='route_segment'and e.character==owner and not e.subject and plain(e.route)
  and l.inInstance~=true and (not l.instanceType or l.instanceType=='none')
end
local function firstAt(e)return e.route.firstAt or e.route.points and e.route.points[1]and e.route.points[1][1]or e.at end
local function before(a,b)
 local at,bt=firstAt(a.event),firstAt(b.event)
 return at<bt or at==bt and a.index<b.index
end
-- Metadata only until a zone is selected. The selected zone decodes lazily, one
-- validated segment at a time. Merge sorting also yields after bounded work.
function R.Index(owner,zone)
 if not R.Allowed(owner)then return nil,'Journey Replay is private to this character.'end
 local character=S.Character(owner,false);local events=character.events;local count=#events
 local job={owner=owner,character=character,events=events,zones={},refs={},travel={},cache={},done=false,examined=0}
 job.thread=coroutine.create(function()
  local byID={}
  for i=1,count do
   local e=events[i]
   if eligible(e,owner)then
    local map=R.Map(e.route.mapID,job.cache)
    if map then
     local z=byID[map.id];if not z then z={id=map.id,name=map.name,segments=0};byID[map.id]=z;job.zones[#job.zones+1]=z end
     z.segments=z.segments+1
     if zone==map.id then job.refs[#job.refs+1]={event=e,index=i,map=map}end
    end
   end
   if zone and ns.ChronicleTravel and ns.ChronicleTravel.ValidRecord(e,owner)then
    local d=e.details;local map=R.Map(d.mapID or(e.location or{}).uiMapID,job.cache)
    if map and map.id==zone then if #job.travel<R.MAX_EFFECTS then job.travel[#job.travel+1]=e else job.effectsLimited=true end end
   end
   job.examined=i;if i%R.SCAN_SLICE==0 then coroutine.yield()end
  end
  table.sort(job.zones,function(a,b)return a.name<b.name or a.name==b.name and a.id<b.id end)
  local refs=job.refs;local width=1;local n=#refs;local work=0
  while width<n do
   local out={}
   for start=1,n,width*2 do
    local a,b,ae,be=start,start+width,math.min(n,start+width-1),math.min(n,start+width*2-1)
    while a<=ae or b<=be do
     if a<=ae and(b>be or before(refs[a],refs[b]))then out[#out+1]=refs[a];a=a+1 else out[#out+1]=refs[b];b=b+1 end
     work=work+1;if work%R.SCAN_SLICE==0 then coroutine.yield()end
    end
   end
   refs=out;width=width*2
  end
  table.sort(job.travel,function(a,b)return a.at<b.at or a.at==b.at and a.id<b.id end)
  job.refs=refs;job.done=true
 end)
 return job
end
function R.Pump(job)
 if not job or job.done then return true end
 if not R.Allowed(job.owner)or S.Character(job.owner,false)~=job.character or job.character.events~=job.events then job.error='This private history changed or is no longer available.';job.done=true;job.thread=nil;job.refs={};return true end
 local ok,why=coroutine.resume(job.thread)
 if not ok then job.error='Recorded travel could not be prepared.';job.done=true;job.thread=nil;job.refs={}end
 if job.done then job.thread=nil end
 return job.done
end
function R.Continuous(a,b)
 if not a or not b or a.event.session~=b.event.session or a.mapID~=b.mapID or a.worldMapID~=b.worldMapID then return false end
 if a.event~=b.event then
  local x,y=a.event.details or {},b.event.details or {}
  if y.gapBefore or y.continued~=true or not x.segment or x.segment~=y.segment then return false end
 end
 local dt=b.point[2]-a.point[11];local wall=b.point[1]-a.point[10]
 if dt<0 or dt>6.01 or wall<0 or wall>7 then return false end
 local dx,dy=b.x-a.x,b.y-a.y
 if dx*dx+dy*dy>.0144 then return false end -- large unmeasured jump, not invented travel
 if a.point[5]~=false and b.point[5]~=false and a.worldMapID then
  local x,y=b.point[5]-a.point[5],b.point[6]-a.point[6]
  local speed=math.max(a.point[9]or 0,b.point[9]or 0)
  if x*x+y*y>math.max(50,speed*dt*3+15)^2 then return false end
 end
 return true
end
function R.Cursor(refs)
 local cursor={refs=refs,segment=0,point=0,decoded=nil,previous=nil,seen=0,rejected=0,breaks=0}
 function cursor:Next()
  if self.decoder then
   local ok,value=coroutine.resume(self.decoder)
   if not ok or coroutine.status(self.decoder)=='dead'then
    self.decoder=nil;self.decoded=ok and value or nil
    if not self.decoded then self.rejected=self.rejected+1;self.previous=nil;return nil,'pending'end
   else return nil,'pending'end
  end
  -- Bound even a very long run of invalid/missing segments per update.
  for _=1,64 do
   if not self.decoded or self.point>=#self.decoded.points then
    self.segment=self.segment+1;local ref=self.refs[self.segment]
    if not ref then self.decoded=nil;return nil,'done'end
    self.ref=ref;self.point=0
    -- The canonical decoder yields between checksum blocks. No point is
    -- exposed until its whole segment has passed checksum/content validation.
    self.decoder=coroutine.create(function()return K.Decode(ref.event.route,function()coroutine.yield()end)end)
    return nil,'pending'
   end
   self.point=self.point+1;local p=self.decoded.points[self.point];local rect=self.ref.map.rect
   local x,y=S.Number(p[3],0,1),S.Number(p[4],0,1)
   if x and y then
    local out={x=rect[1]+x*(rect[2]-rect[1]),y=rect[3]+y*(rect[4]-rect[3]),point=p,
     facing=S.Number(p[8],0,math.pi*2+.001),event=self.ref.event,mapID=self.decoded.mapID,worldMapID=self.decoded.worldMapID}
    out.connect=R.Continuous(self.previous,out);if not out.connect then self.breaks=self.breaks+1 end
    self.previous=out;self.seen=self.seen+1;return out
   end
   self.rejected=self.rejected+1;self.previous=nil
  end
  return nil,'pending'
 end
 return cursor
end
-- Angles are recorded GetPlayerFacing radians: north=0, west=pi/2.
-- Interpolation is presentation only; never infer facing from route tangents.
function R.Facing(a,b,t)
 if type(a)~='number'or type(b)~='number'then return nil end
 local circle=math.pi*2;local delta=(b-a+math.pi)%circle-math.pi
 return(a+delta*math.max(0,math.min(1,t)))%circle
end
function R.Build(parent)
 local f=CreateFrame('Frame',nil,parent);f:SetAllPoints();f.ChatWardenOwned=true;f:EnableMouse(true)
 C.Fill(f,{.025,.04,.065,1})
 local title=C.Text(f,'Journey Replay',22,C.colors.gold);title:SetPoint('TOPLEFT',14,-8);title:SetHeight(28)
 C.Button(f,'Back to Chronicle',function()ns.UI2.Open({page='chronicle'})end,180):SetPoint('TOPRIGHT',-10,-4)
 f.caption=C.Text(f,'Your recorded travels · Private to this character',12);f.caption:SetPoint('TOPLEFT',14,-43);f.caption:SetPoint('RIGHT',-10,0);f.caption:SetHeight(20)
 f.list=CreateFrame('ScrollFrame',nil,f);f.list:SetPoint('TOPLEFT',16,-78);f.list:SetPoint('BOTTOMLEFT',16,72);f.list:SetWidth(224);f.list:EnableMouseWheel(true);f.list:SetFrameLevel(f:GetFrameLevel()+35);C.Fill(f.list,{.025,.04,.065,.98});ns.WardenArt.Frame(f.list,false,false)
 f.zoneButton=C.Button(f,'Zones',function()f.list:SetShown(not f.list:IsShown())end,100);f.zoneButton:SetPoint('RIGHT',f,'TOPRIGHT',-204,-20)
 f.listContent=CreateFrame('Frame',nil,f.list);f.listContent:SetSize(224,1);f.list:SetScrollChild(f.listContent);f.zones={}
 f.list:SetScript('OnMouseWheel',function(self,d)self:SetVerticalScroll(math.max(0,math.min(math.max(0,f.listContent:GetHeight()-self:GetHeight()),self:GetVerticalScroll()-d*48)))end)
 f.instrument=CreateFrame('Frame',nil,f);f.instrument:SetPoint('TOPLEFT',8,-72);f.instrument:SetPoint('BOTTOMRIGHT',-8,4);ns.WardenArt.Frame(f.instrument,false,true)
 f.area=CreateFrame('Frame',nil,f.instrument);f.area:SetPoint('TOPLEFT',46,-46);f.area:SetPoint('BOTTOMRIGHT',-46,64);f.area:EnableMouse(true);f.area:EnableMouseWheel(true);f.area:SetClipsChildren(true)
 local rim=ns.WardenArt.Texture(f.instrument,'TempleBackdrop','BACKGROUND');rim:SetAllPoints();rim:SetVertexColor(.38,.25,.14,1)
 f.rail={};local corners={{'TOPLEFT',0,.14,0,.18},{'TOPRIGHT',.86,1,0,.18},{'BOTTOMLEFT',0,.14,.82,1},{'BOTTOMRIGHT',.86,1,.82,1}}
 for _,part in ipairs(corners)do local t=f.instrument:CreateTexture(nil,'OVERLAY');t:SetTexture('Interface\\AddOns\\OlympusChatWarden\\Media\\Replay32\\MapFrame.tga');t:SetTexCoord(part[2]*.75,part[3]*.75,part[4],part[5]);t:SetSize(46,46);t:SetPoint(part[1]);f.rail[#f.rail+1]=t end
 for _,part in ipairs({{'TOP',.14,.86,0,.18},{'BOTTOM',.14,.86,.82,1},{'LEFT',0,.14,.18,.82},{'RIGHT',.86,1,.18,.82}})do local t=f.instrument:CreateTexture(nil,'OVERLAY');t:SetTexture('Interface\\AddOns\\OlympusChatWarden\\Media\\Replay32\\MapFrame.tga');t:SetTexCoord(part[2]*.75,part[3]*.75,part[4],part[5]);if part[1]=='TOP'or part[1]=='BOTTOM'then t:SetPoint(part[1]..'LEFT',46,0);t:SetPoint(part[1]..'RIGHT',-46,0);t:SetHeight(46)else t:SetPoint('TOP'..part[1],0,-46);t:SetPoint('BOTTOM'..part[1],0,46);t:SetWidth(46)end;f.rail[#f.rail+1]=t end
 f.map=CreateFrame('Frame',nil,f.area);f.map:SetPoint('CENTER');f.map:SetSize(1,1)
 f.tiles={};f.ink={};f.legs={};f.inkUsed=0
 f.marker=f.map:CreateTexture(nil,'OVERLAY');f.marker:SetTexture('Interface\\Minimap\\MinimapArrow');f.marker:SetSize(20,20);f.marker:Hide()
 f.neutral=f.map:CreateTexture(nil,'OVERLAY');f.neutral:SetColorTexture(1,.88,.54,1);f.neutral:SetSize(6,6);f.neutral:Hide()
 f.message=C.Text(f.area,'Choose a zone with recorded travel.',17);f.message:SetPoint('CENTER');f.message:SetWidth(700);f.message:SetWordWrap(true);f.message:SetJustifyH('CENTER')
 f.status=C.Text(f,'',12);f.status:SetPoint('BOTTOMLEFT',24,44);f.status:SetPoint('RIGHT',-24,0);f.status:SetHeight(20)
 f.play=C.Button(f,'Pause',function()f.playing=not f.playing;f.play:SetLabel(f.playing and 'Pause'or'Play');f:ClearEffect();f:Arm()end,90);f.play:SetPoint('BOTTOMLEFT',24,10);f.play:SetEnabled(false)
 f.restart=C.Button(f,'Restart',function()f:Restart()end,110);f.restart:SetPoint('LEFT',f.play,'RIGHT',8,0);f.restart:SetEnabled(false)
 f.fit=C.Button(f,'Whole zone',function()f.fitMode=true;f.zoom=1;f.panX=0;f.panY=0;f:FitMap()end,100);f.fit:SetPoint('LEFT',f.restart,'RIGHT',8,0)
 f.fill=C.Button(f,'Fill map',function()f.fitMode=false;f.zoom=1;f.panX=0;f.panY=0;f:FitMap()end,90);f.fill:SetPoint('LEFT',f.fit,'RIGHT',6,0)
 f.expand=C.Button(f,'Expand map',function()f:SetExpanded(not f.expanded)end,110);f.expand:SetPoint('LEFT',f.fill,'RIGHT',6,0)
 f.note=C.Text(f,'Wheel: zoom · Drag: pan · Click: expand · Recorded facing',11);f.note:SetPoint('LEFT',f.expand,'RIGHT',12,0);f.note:SetPoint('RIGHT',-18,0)
 f.list:Hide()
 function f:SetExpanded(value)
  self.expanded=value;self.caption:SetShown(not value);title:SetShown(not value);self.instrument:ClearAllPoints();self.instrument:SetPoint('TOPLEFT',8,value and-2 or-72);self.instrument:SetPoint('BOTTOMRIGHT',-8,4);self.expand:SetLabel(value and'Restore map'or'Expand map');self:FitMap()
 end
 f.area:SetScript('OnMouseWheel',function(_,delta)f.zoom=math.max(1,math.min(3,(f.zoom or 1)+delta*.15));f:FitMap()end)
 f.area:SetScript('OnMouseDown',function(_,button)if button=='LeftButton'then local x,y=GetCursorPosition();f.drag={x=x,y=y,px=f.panX or 0,py=f.panY or 0}end end)
 f.area:SetScript('OnMouseUp',function()local d=f.drag;f.drag=nil;if d and not d.moved then f:SetExpanded(not f.expanded)end end)
 local art='Interface\\AddOns\\OlympusChatWarden\\Media\\Replay32\\'
 f.tip=f.map:CreateTexture(nil,'OVERLAY',nil,3);f.tip:SetTexture(art..'Glow.tga');f.tip:SetBlendMode('ADD');f.tip:SetSize(20,20);f.tip:Hide()
 f.particles={};for i=1,6 do local t=f.map:CreateTexture(nil,'OVERLAY',nil,3);t:SetTexture(art..'Glow.tga');t:SetBlendMode('ADD');t:SetSize(4,4);t:Hide();f.particles[i]=t end
 f.effectFrame=CreateFrame('Frame',nil,f.map);f.effectFrame:SetSize(40,40);f.effectFrame:SetFrameLevel(f.map:GetFrameLevel()+5);f.effectFrame:EnableMouse(false);f.effectFrame:Hide()
 f.effectIcon=f.effectFrame:CreateTexture(nil,'OVERLAY');f.effectIcon:SetPoint('CENTER');f.effectIcon:SetSize(34,34)
 f.effectRing=f.effectFrame:CreateTexture(nil,'ARTWORK');f.effectRing:SetTexture(art..'Ring.tga');f.effectRing:SetPoint('CENTER');f.effectRing:SetBlendMode('ADD')
 function f:ClearEffect()
  self.effect=nil;self.effectFrame:Hide();self.tip:Hide();for _,t in ipairs(self.particles)do t:Hide()end
  self.marker:SetAlpha(1);self.neutral:SetAlpha(1);if ns.WardenAudio then ns.WardenAudio.Stop('journey-replay')end
 end
 function f:PlaceEffect()
  local e=self.effect;if not e then return end;self.effectFrame:ClearAllPoints();self.effectFrame:SetPoint('CENTER',self.map,'TOPLEFT',e.x*self.map:GetWidth(),-e.y*self.map:GetHeight())
 end
 function f:ShowEffect(kind,position,event,preview)
  if not effectLabels[kind]or not R.Allowed(self.owner)or preview and not(ns.WardenSimLab and ns.WardenSimLab.Enabled())or not position or not S.Number(position.x,0,1)or not S.Number(position.y,0,1)then return false end
  self:ClearEffect();self.effect={kind=kind,x=position.x,y=position.y,elapsed=0,duration=ns.DB.journalReducedMotion and .55 or 1.45,event=event,approximate=position.approximate,preview=preview}
  self.effectIcon:SetTexture(art..(kind=='hearth'and'Hearth.tga'or kind:find('taxi',1,true)and'Flight.tga'or'Glow.tga'))
  self.effectIcon:SetBlendMode((kind=='hearth'or kind:find('taxi',1,true))and'BLEND'or'ADD');self.effectIcon:SetShown(kind~='gap');self.effectRing:SetShown(kind~='gap');self.effectFrame:Show();self:PlaceEffect();local facing=self.markerFacing;if event or kind=='gap'then facing=nil end;self:Mark(position.x,position.y,facing)
  if ns.WardenAudio and kind~='gap'then ns.WardenAudio.Play(kind=='hearth'and'travel.hearth'or kind:find('taxi',1,true)and'travel.flight'or'travel.session','journey-replay')end
  self.status:SetText((preview and'LAB FIXTURE · 'or'')..effectLabels[kind]..(position.approximate and' · Position approximated inside one recorded leg'or''))
  return true
 end
 function f:StepEffect(dt)
  local e=self.effect;if not e then return false end;e.elapsed=e.elapsed+math.min(.1,math.max(0,dt));local q=math.min(1,e.elapsed/e.duration);local fade=math.min(1,q*5,(1-q)*5)
  self.effectFrame:SetAlpha(ns.DB.journalReducedMotion and 1 or fade);local scale=1/math.max(.01,self.map:GetEffectiveScale());self.effectRing:SetSize((32+12*q)*scale,(32+12*q)*scale)
  self.effectIcon:SetSize(32*scale,32*scale);self.effectIcon:ClearAllPoints();self.effectIcon:SetPoint('CENTER',0,not ns.DB.journalReducedMotion and e.kind=='taxi-start'and q*10*scale or 0)
  local leaving=e.kind=='hearth'or e.kind=='taxi-start'or e.kind=='session-end'or e.kind=='gap';self.marker:SetAlpha(leaving and 1-q or q);self.neutral:SetAlpha(leaving and 1-q or q)
  if q>=1 then self:ClearEffect();return false end;return true
 end
 function f:TravelEffects(a,b)
  local list=self.ready and self.ready.travel or{}
  for _=1,16 do local e=list[self.travelCursor or 1];if not e or e.at>b.point[10]then return end;self.travelCursor=(self.travelCursor or 1)+1
   if e.session==b.event.session then local position=ns.ChronicleTravel.Position(e,self.selected,a,b);if position then self:ShowEffect(e.details.direction,position,e);return end end
  end
 end
 function f:ClearInk()
  for _,t in ipairs(self.ink)do t:Hide()end;self.legs={};self.inkUsed=0;self.activeLeg=nil;self.trailLimited=nil;self.trailBreak=true;self.neutral:Hide()
 end
 function f:DrawLeg(i)
  local p=self.legs[i];if not p then return end
  local line=self.ink[i];local native
  if not line then
   if type(self.map.CreateLine)=='function'then line=call(self.map.CreateLine,self.map,nil,'ARTWORK',nil,2);native=line~=nil end
   if not line then line=self.map:CreateTexture(nil,'ARTWORK',nil,2);line:SetTexture('Interface\\Buttons\\WHITE8X8')end
   line:SetColorTexture(.64,.68,.54,.9);self.ink[i]=line;p.native=native
  end
  local width,height=self.map:GetWidth(),self.map:GetHeight();local thickness=2/math.max(.01,self.map:GetEffectiveScale())
  line:ClearAllPoints()
  if type(line.SetStartPoint)=='function'and type(line.SetThickness)=='function'then
   line:SetThickness(thickness);line:SetStartPoint('TOPLEFT',self.map,p[1]*width,-p[2]*height);line:SetEndPoint('TOPLEFT',self.map,p[3]*width,-p[4]*height)
  else
   local dx,dy=(p[3]-p[1])*width,-(p[4]-p[2])*height
   line:SetPoint('CENTER',self.map,'TOPLEFT',(p[1]+p[3])*width/2,-(p[2]+p[4])*height/2)
   line:SetSize(math.max(.01,math.sqrt(dx*dx+dy*dy)),thickness);line:SetRotation(math.atan2(dy,dx))
  end
  line:Show()
 end
 function f:BeginLeg(a,b)
  self.activeLeg=nil;if not b.connect or not a then self.trailBreak=true;return end
  -- Reuse one line throughout this recorded pair, rather than adding a line
  -- every animation frame. Merge only forward, virtually collinear samples;
  -- accumulated error is limited to half a screen pixel. Corners stay intact.
  local last=self.legs[self.inkUsed];local merge=false
  if not self.trailBreak and last and last[3]==a.x and last[4]==a.y then
   local w,h=self.map:GetWidth(),self.map:GetHeight();local dx,dy=(b.x-last[1])*w,(b.y-last[2])*h
   local len=math.sqrt(dx*dx+dy*dy);local error=len>0 and math.abs((a.x-last[1])*w*dy-(a.y-last[2])*h*dx)/len or 0
   local forward=(a.x-last[1])*w*(b.x-a.x)*w+(a.y-last[2])*h*(b.y-a.y)*h>=0
   merge=forward and (last.error or 0)+error<=.5/math.max(.01,self.map:GetEffectiveScale())
   if merge then last.error=(last.error or 0)+error end
  end
  self.trailBreak=nil
  if merge then self.activeLeg=self.inkUsed
  elseif a.x~=b.x or a.y~=b.y then
   if self.inkUsed>=R.MAX_LINES then self.trailLimited=true;return end
   self.inkUsed=self.inkUsed+1;self.legs[self.inkUsed]={a.x,a.y,a.x,a.y,error=0};self.activeLeg=self.inkUsed
  end
 end
 function f:FitMap()
  if not self.art then return end
  local sx,sy=self.area:GetWidth()/self.art.width,self.area:GetHeight()/self.art.height;local scale=(self.fitMode and math.min(sx,sy)or math.max(sx,sy))*(self.zoom or 1)
  self.map:SetSize(self.art.width*scale,self.art.height*scale)
  local mx,my=math.max(0,(self.map:GetWidth()-self.area:GetWidth())/2),math.max(0,(self.map:GetHeight()-self.area:GetHeight())/2)
  self.panX=math.max(-mx,math.min(mx,self.panX or 0));self.panY=math.max(-my,math.min(my,self.panY or 0));self.map:ClearAllPoints();self.map:SetPoint('CENTER',self.area,'CENTER',self.panX,self.panY)
  self.lineScale=self.map:GetEffectiveScale()
  for i,tile in ipairs(self.art.tiles)do local t=self.tiles[i];t:ClearAllPoints();t:SetPoint('TOPLEFT',self.map,'TOPLEFT',tile.x*scale,-tile.y*scale);t:SetSize(tile.width*scale,tile.height*scale)end
  for i=1,self.inkUsed do self:DrawLeg(i)end
  if self.markerX then self:Mark(self.markerX,self.markerY,self.markerFacing)end
  self:PlaceEffect()
 end
 function f:Mark(x,y,facing)
  self.markerX=x;self.markerY=y;self.markerFacing=facing
  self.marker:Hide();self.neutral:Hide();local marker=facing~=nil and type(self.marker.SetRotation)=='function'and self.marker or self.neutral
  if marker==self.marker then marker:SetRotation(facing)end
  marker:ClearAllPoints();marker:SetPoint('CENTER',self.map,'TOPLEFT',x*self.map:GetWidth(),-y*self.map:GetHeight());marker:Show()
  local scale=1/math.max(.01,self.map:GetEffectiveScale());self.tip:ClearAllPoints();self.tip:SetPoint('CENTER',self.map,'TOPLEFT',x*self.map:GetWidth(),-y*self.map:GetHeight());self.tip:SetSize(18*scale,18*scale);self.tip:SetShown(self.playing and not ns.DB.journalReducedMotion and not self.effect)
  for i,t in ipairs(self.particles)do t:SetShown(self.playing and not ns.DB.journalReducedMotion and not self.effect and i<=3);t:ClearAllPoints();local angle=(self.inkAge or 0)*1.3+i*2.4;t:SetPoint('CENTER',self.tip,'CENTER',math.cos(angle)*7*scale,math.sin(angle)*6*scale);t:SetSize(3*scale,3*scale);t:SetAlpha(.35)end
 end
 function f:Ink(x,y)
  local i=self.activeLeg;local p=i and self.legs[i];if not p then return end
  p[3],p[4]=x,y;self:DrawLeg(i)
 end
 function f:Release()
  self:ClearEffect();self.drag=nil;self.travelCursor=nil
  self:SetScript('OnUpdate',nil);self.job=nil;self.ready=nil;self.cursor=nil;self.current=nil;self.nextPoint=nil;self.character=nil;self.events=nil;self.art=nil;self.owner=nil;self.selected=nil;self.playing=false
  self:ClearInk();self.marker:Hide();self.markerX=nil;self.markerY=nil;self.play:SetEnabled(false);self.restart:SetEnabled(false)
  self.status:SetText('');self.caption:SetText('Your recorded travels · Private to this character')
  for _,t in ipairs(self.tiles)do t:Hide();t:SetTexture(nil)end
  for _,b in ipairs(self.zones)do b:Hide();b.zone=nil;b:SetLabel('')end
 end
 function f:Restart()
  if not self.ready or not self.art then return end
  self:ClearEffect();self.travelCursor=1;self.cursor=R.Cursor(self.ready.refs);self.current=nil;self.nextPoint=nil;self.segmentTime=0;self:ClearInk();self.marker:Hide();self.markerX=nil;self.markerY=nil;self.playing=true;self.play:SetLabel('Pause');self:Arm()
 end
 function f:Select(id)
  local map=R.Map(id,{});if not map or map.id~=id then return end
  self:ClearEffect();self.list:Hide();self.zoom=1;self.panX=0;self.panY=0;self.zoneButton:SetLabel(map.name)
  self.job=nil;self.ready=nil;self.cursor=nil;self.current=nil;self.nextPoint=nil;self.selected=id;self.art=nil;self.playing=false;self.marker:Hide();self.markerX=nil;self:ClearInk()
  self.caption:SetText(map.name..' · All retained visits · Private replay');self.status:SetText('Preparing recorded travel…')
  for _,t in ipairs(self.tiles)do t:Hide();t:SetTexture(nil)end
  local ok,art,why=pcall(ns.WardenArtCatalog.Map,{id=id,recorded=true});if not ok then art=nil;why='Blizzard map artwork cannot be read on this client.'end
  self.message:SetText(why or 'Preparing recorded travel…');self.message:Show();self.play:SetEnabled(false);self.restart:SetEnabled(false)
  if not art then self.status:SetText('Blizzard map artwork is unavailable on this client.');self:SetScript('OnUpdate',nil);return end
  self.art=art
  for i,tile in ipairs(art.tiles)do local t=self.tiles[i];if not t then t=self.map:CreateTexture(nil,'BACKGROUND');self.tiles[i]=t end;t:SetTexture(tile.path);t:SetTexCoord(unpack(tile.uv));t:SetAlpha(1);t:Show()end
  self:FitMap();self.caption:SetText(map.name..' · All retained visits · Private replay')
  self.job=R.Index(self.owner,id);self:Arm()
 end
 function f:ShowZones(job)
  for _,b in ipairs(self.zones)do b:Hide();b.zone=nil end
  for i,z in ipairs(job.zones)do
   local b=self.zones[i];if not b then b=C.Button(self.listContent,'',function(self)f:Select(self.zone)end,216);self.zones[i]=b end
   b.zone=z.id;b:SetLabel(z.name);b:SetPoint('TOPLEFT',0,-(i-1)*40);b:SetSize(216,36);b:Show();b:SetActive(z.id==self.selected)
  end
  self.listContent:SetHeight(math.max(1,#job.zones*40));self.list:SetVerticalScroll(0)
 end
 function f:Advance(dt)
  if not self.cursor then return end
  self.inkAge=(self.inkAge or 0)+math.max(0,dt);if self.effect then self:StepEffect(dt);return end
  -- At most eight endpoints and bounded ink cells in one frame. Excess elapsed
  -- time after a hitch is discarded rather than fast-forwarded over history.
  local budget=math.min(math.max(dt or 0,0),.1)
  for _=1,8 do
   if not self.nextPoint then
    local point,state=self.cursor:Next()
    if not point then
     if state=='done'then self.playing=false;self:ClearEffect();self.play:SetLabel('Play');self.status:SetText(self.cursor.seen==0 and 'No valid recorded map coordinates in this zone.'or'Replay complete · '..self.cursor.seen..' recorded positions'..(self.cursor.rejected>0 and ' · Unavailable coordinates omitted'or'')..(self.trailLimited and' · Trail detail limit reached'or''));if self.cursor.seen==0 then self.message:SetText('No valid recorded map coordinates in this zone.');self.message:Show();self.play:SetEnabled(false)end end
     return
    end
    self.nextPoint=point;self.segmentTime=0;self:BeginLeg(self.current,point)
    local distance=self.current and math.sqrt((point.x-self.current.x)^2+(point.y-self.current.y)^2)or 0
    self.duration=point.connect and math.max(.16,math.min(1.6,distance/.06))or .20
    if not point.connect and self.current then self:ShowEffect('gap',{x=self.current.x,y=self.current.y});return end
   end
   local point=self.nextPoint;local used=math.min(budget,self.duration-self.segmentTime);self.segmentTime=self.segmentTime+used;budget=budget-used
   local t=self.segmentTime/self.duration
   if point.connect and self.current then
    local x,y=self.current.x+(point.x-self.current.x)*t,self.current.y+(point.y-self.current.y)*t
    self:Ink(x,y);self:Mark(x,y,t>=1 and point.facing or R.Facing(self.current.facing,point.facing,t))
   elseif t>=1 then self:Mark(point.x,point.y,point.facing)
   else self.marker:Hide();self.neutral:Hide()end
   if t<1 then return end
   local previous=self.current;self.current=point;self.nextPoint=nil;self.status:SetText(C.Stamp(point.point[1])..' · '..self.cursor.seen..' recorded positions'..(self.trailLimited and' · Trail detail limit reached; marker continues'or''));self:TravelEffects(previous,point);if self.effect then return end
   if budget<=0 then return end
  end
 end
 function f:Tick(dt)
  if self.drag then local x,y=GetCursorPosition();local d=self.drag;local scale=math.max(.01,self.area:GetEffectiveScale());if math.abs(x-d.x)+math.abs(y-d.y)>5 then d.moved=true end;if d.moved then self.panX=d.px+(x-d.x)/scale;self.panY=d.py+(y-d.y)/scale;self:FitMap()end end
  if not R.Allowed(self.owner)or S.Character(self.owner,false)~=self.character or self.character.events~=self.events then self:Release();self.message:SetText('This private history is no longer available. Reopen Chronicle to continue.');self.message:Show();self.play:SetEnabled(false);self.restart:SetEnabled(false);return end
  if self.art and self.lineScale~=self.map:GetEffectiveScale()then self:FitMap()end
  if self.job then
   local job=self.job;R.Pump(job)
   if job.done then
    self.job=nil
    if job.error then self.message:SetText(job.error);self.message:Show();self:SetScript('OnUpdate',nil);return end
    self:ShowZones(job)
    if self.selected then self.ready=job;self.message:Hide();self.play:SetEnabled(true);self.restart:SetEnabled(true);self:Restart()
    else self.message:SetText(#job.zones>0 and 'Choose a zone to watch your recorded journeys.'or'No zone travel with a supported reference map has been recorded.');self.status:SetText('Saved routes are never changed.');self:SetScript('OnUpdate',nil)end
   end
   return
  end
  if self.playing then self:Advance(dt)end
  if self.effect and self.effect.preview and not self.playing then self:StepEffect(dt)end
  -- A paused replay keeps a cheap privacy check; it does no history animation.
 end
 function f:Arm()self:SetScript('OnUpdate',function(self,dt)
  if not self.playing and not self.job and not self.drag and not self.effect then self.idle=(self.idle or 0)+dt;if self.idle<.25 then return end;self.idle=0 end
  self:Tick(dt)
 end)end
 function f:Present(owner)
  if self.owner==owner and self.character==S.Character(owner,false)then return end
  self:Release();self.owner=owner;self.caption:SetText('Your recorded travels · Private to this character')
  if not R.Allowed(owner)then
   local message='No recorded zone travel is available for this character.'
   if owner~=ns.Chronicle.Owner()or not ns.Athena2.Permit('chronicle')then message='Journey Replay is private to this character.'end
   if S.loading then message='Saved route history is still loading. Reopen Journey Replay when it is ready.'
   elseif S.blocked then message='Saved route history is unavailable. Original records are retained.'end
   self.message:SetText(message);self.message:Show();return
  end
  self.character=S.Character(owner,false);self.events=self.character.events;self.job=R.Index(owner);self:Arm()
 end
 f.area:SetScript('OnSizeChanged',function()f:FitMap()end)
 f:SetScript('OnHide',function(self)self:Release()end)
 return f
end
function R.Show(parent,owner)
 if not R.view then R.view=R.Build(parent)end
 R.view:Show();R.view:Present(owner);return R.view
end
