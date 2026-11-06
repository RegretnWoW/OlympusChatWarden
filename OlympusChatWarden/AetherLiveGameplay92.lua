-- Ephemeral gameplay over an ACK-confirmed, certificate-bound native sender.
-- Public credentials bootstrap trust; they are not identity until key proof.
-- No Live packet enters the historical ledger, publication or recovery store.
local _,ns=...
local G={VERSION=3,PROTOCOL=2,MAX_APPEARANCE=1800};ns.AetherLiveGameplay=G
-- Compare the navigable world, not a paint revision. Compute once from bundled
-- definitions, never from a private layout or a peer's claimed geometry.
function G.GeometryWire(catalogue)
 local function encode(v)
  local t=type(v)
  if t=='nil'then return'n'end
  if t=='boolean'then return v and't'or'f'end
  if t=='number'then return'd'..string.format('%.12g',v)..';'end
  if t=='string'then return's'..#v..':'..v end
  assert(t=='table','Geometry must contain authored values only')
  local keys={};for k in pairs(v)do keys[#keys+1]=k end
  table.sort(keys,function(a,b)if type(a)==type(b)then return a<b end;return type(a)<type(b)end)
  local out={'{'};for _,k in ipairs(keys)do out[#out+1]=encode(k);out[#out+1]=encode(v[k])end;out[#out+1]='}';return table.concat(out)
 end
 local world={protocol=G.PROTOCOL,projection=1,collision=3,rooms={}}
 local fields={'id','fileID','modelKey','at','floorUV','worldYaw','height','width','maxWidth','sizeMultiplier','collision','collisionRadius','navigationRadius','defaultHidden','support','supportOffset','interaction','seatFraction','seatHeightOffset'}
 for _,key in ipairs({'hall','square'})do
  local d=assert(catalogue.Room(key),'Shared room missing');local r={shot=d.shot,navigation=d.navigation,calibration=d.worldCalibration,walkSpeed=d.walkSpeed,props={},residents={},links={}}
  for _,p in ipairs(d.props or{})do if p.collision~=false then local item={};for _,field in ipairs(fields)do item[field]=p[field]end;r.props[#r.props+1]=item end end
  table.sort(r.props,function(a,b)return a.id<b.id end)
  for _,p in ipairs(d.residents or{})do if p.unit=='player'then r.residents[#r.residents+1]={id=p.id,height=p.height,navigationRadius=p.navigationRadius,at=p.at,floorUV=p.floorUV}end end
  for _,p in ipairs((catalogue.PortalDefaults or catalogue.Connections)(key))do r.links[#r.links+1]={id=p.id,to=p.to,arrival=p.arrival,portal=p.portal}end
  table.sort(r.links,function(a,b)return a.id<b.id end);world.rooms[key]=r
 end
 return encode(world)
end
if ns.WardenRoomCatalogue and ns.WardenRoomCatalogue.Room and ns.PackCrypto then
 G.GEOMETRY_SIGNATURE=ns.PackCrypto.Hex(ns.PackCrypto.SHA256(G.GeometryWire(ns.WardenRoomCatalogue)))
 G.SCENE_REVISION='g104-'..G.GEOMETRY_SIGNATURE:sub(1,24)
 -- This legacy alias is enabled only for the frozen Public92 geometry digest.
 -- Cosmetic hotfixes keep it; a collider, floor, projection or prop change does not.
 if G.GEOMETRY_SIGNATURE=='8c976356b613947ded82b03abf6034fb38702cbf37b332f6e4a420ef698ed7a3'then G.SCENE_REVISION='a92-f55d738f'end
elseif rawget(_G,'WARDEN_SIMULATOR_ISOLATED')==true then G.SCENE_REVISION='a92-fixture'end
function G.Compatible(revision)return G.SCENE_REVISION~=nil and revision==G.SCENE_REVISION end
local function finite(n,a,b)return type(n)=='number'and n==n and n>=a and n<=b end
local function int(n,a,b)return finite(n,a,b)and n%1==0 end
local function size(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
local function split(s,sep)local t={};for x in(s..sep):gmatch('(.-)'..sep)do t[#t+1]=x end;return t end
local function number(s,a,b)local n=tonumber(s);return int(n,a,b)and n or nil end
local sceneCode={hall='f',square='a'};local sceneKey={f='hall',a='square'}
G.Scenes=sceneCode
function G.AppearanceEncode(a,form)
 if not ns.WardenAppearance.Valid(a)then return end
 local slots,choices={},{}
 for i,r in ipairs(a.slots)do slots[i]=r[2]=='present'and tostring(r[3])or r[2]=='empty'and'0'or'-1'end
 for i,r in ipairs(a.choices)do choices[i]=r[1]..'_'..r[2]end
 return table.concat({a.raceID,a.sex,a.nativeDisplayID or 0,int(form,0,1000)and form or 0,table.concat(slots,','),table.concat(choices,','),a.choiceSource},':')
end
function G.AppearanceDecode(text,at)
 if type(text)~='string'or #text>G.MAX_APPEARANCE then return end
 if text:sub(1,3)=='v2:'then local v=G.AppearanceDecodeV2(text,at);if v then return v.body,v.formID,v end;return end
 local f=split(text,':');if #f~=7 then return end
 local a={version=1,client=ns.ClientCompat.IsRetailTest()and'retail-test'or'forever',observedAt=at,
  raceID=number(f[1],1,1000),sex=number(f[2],2,3),slots={},choices={},choiceSource=f[7]}
 local display=number(f[3],0,1000000000);local form=number(f[4],0,1000);if not display or not form then return end
 if display>0 then a.nativeDisplayID=display end
 local slots=split(f[5],',');if #slots~=19 then return end
 for i,s in ipairs(slots)do local n=number(s,-1,1000000000);if not n then return end;a.slots[i]={i,n>0 and'present'or n==0 and'empty'or'unknown',n>0 and n or false}end
 if f[6]~=''then
  local choices=split(f[6],',');if #choices>64 then return end
  for i,s in ipairs(choices)do local x,y=s:match('^(%d+)_(%d+)$');x,y=number(x,1,1000000000),number(y,1,1000000000);if not x or not y then return end;a.choices[i]={x,y}end
 end
 if not ns.WardenAppearance.Valid(a)then return end
 return a,form
end
-- The public sender stays on V1 until native V2 reconstruction is qualified.
-- The Lab round-trips this same bounded codec; no extra packet or persistence
-- channel is introduced. A large recipe fails explicitly, never truncates.
G.PUBLIC_APPEARANCE_V2=true
function G.AppearanceEncodeV2(v)
 if not ns.WardenAppearance.ValidLive(v)then return nil,'INVALID_APPEARANCE_V2'end
 local base=G.AppearanceEncode(v.body,v.formID);if not base then return end
 local visuals,enchants={},{}
 for i,row in ipairs(v.visuals)do visuals[i]=table.concat(row,'_')end
 for i,row in ipairs(v.enchants)do enchants[i]=table.concat(row,'_')end
 local wire='v2:'..base..':'..v.formDisplayID..':'..table.concat(visuals,',')..':'..table.concat(enchants,',')
 if #wire>G.MAX_APPEARANCE then return nil,'APPEARANCE_V2_TOO_LARGE'end;return wire
end
function G.AppearanceDecodeV2(text,at)
 if type(text)~='string'or #text>G.MAX_APPEARANCE then return end
 local f=split(text,':');if #f~=11 or f[1]~='v2'then return end
 local body,form=G.AppearanceDecode(table.concat(f,':',2,8),at);if not body then return end
 local v={version=2,body=body,formID=form,formDisplayID=number(f[9],0,1000000000),visuals={},enchants={}}
 for _,part in ipairs({{f[10],v.visuals,4},{f[11],v.enchants,2}})do if part[1]~=''then
  local rows=split(part[1],',');if #rows>19 then return end
  for _,row in ipairs(rows)do local values=split(row,'_');if #values~=part[3]then return end
   for i,value in ipairs(values)do values[i]=number(value,0,1000000000);if values[i]==nil then return end end;part[2][#part[2]+1]=values
  end
 end end
 if ns.WardenAppearance.ValidLive(v)then return v end
end
local function quant(n)return math.floor(n*100+.5)end
function G.StateEncode(s)
 if not s or not sceneCode[s.scene]or not G.Compatible(s.revision)then return end
 local p,g=s.position,s.destination or s.position
 if type(p)~='table'or type(g)~='table'then return end
 for i=1,3 do if not finite(p[i],-80,80)or not finite(g[i],-80,80)then return end end
 if not finite(s.yaw or 0,-32,32)or not finite(s.duration or 0,0,120)or not int(s.animation or 0,0,1000)then return end
 local seat=s.seat or'';if #seat>48 or not seat:match('^[%w%-_]*$')then return end
 return table.concat({sceneCode[s.scene],s.revision,quant(p[1]),quant(p[2]),quant(p[3]),quant(s.yaw or 0),
  quant(g[1]),quant(g[2]),quant(g[3]),quant(s.duration or 0),s.animation or 0,seat},',')
end
function G.StateDecode(text)
 if type(text)~='string'or #text>190 then return end
 local f=split(text,',');if #f~=12 or not sceneKey[f[1]]or not G.Compatible(f[2])then return end
 local n={};for i=3,10 do n[i]=number(f[i],-8000,i==10 and 12000 or 8000);if not n[i]then return end end
 local anim=number(f[11],0,1000);if not anim or #f[12]>48 or not f[12]:match('^[%w%-_]*$')or n[10]<0 or math.abs(n[5])>800 or math.abs(n[9])>800 or math.abs(n[6])>3200 then return end
 return{scene=sceneKey[f[1]],revision=f[2],position={n[3]/100,n[4]/100,n[5]/100},yaw=n[6]/100,
  destination={n[7]/100,n[8]/100,n[9]/100},duration=n[10]/100,animation=anim,seat=f[12]~=''and f[12]or nil}
end
-- Application consumers share Live's authenticated sessions, fragmentation,
-- acknowledgments and native budget. Readable community data uses logged I/O.
G.Applications={}
G.APPLICATION_PROTOCOL=2
-- Logged messages stay readable and single-line. Restore the exact original
-- signed bytes after reassembly; never alter a record before verification.
function G.LoggedText(value)
 return(value:gsub('\\','\\\\'):gsub('[%z\1-\31\127]',function(c)
  if c=='\n' then return'\\n'elseif c=='\r'then return'\\r'elseif c=='\t'then return'\\t'end
  return string.format('\\x%02x',c:byte())
 end))
end
function G.UnloggedText(value)
 if type(value)~='string'or value:find('[%z\1-\31\127]')then return end
 local out={};local i=1
 while i<=#value do
  local c=value:sub(i,i)
  if c~='\\'then out[#out+1]=c;i=i+1
  else
   local code=value:sub(i+1,i+1);local decoded=({['\\']='\\',n='\n',r='\r',t='\t'})[code]
   if decoded then out[#out+1]=decoded;i=i+2
   elseif code=='x'and value:sub(i+2,i+3):match('^%x%x$')then out[#out+1]=string.char(tonumber(value:sub(i+2,i+3),16));i=i+4
   else return end
  end
 end
 local raw=table.concat(out);if #raw>10000 or raw:find('%z')or G.LoggedText(raw)~=value then return end;return raw
end
function G.RegisterApplication(name,spec)
 if type(name)~='string'or #name>16 or not name:match('^[a-z][a-z0-9]*$')or G.Applications[name]or type(spec)~='table'or type(spec.receive)~='function'then return false end
 G.Applications[name]=spec;return true
end
function G.Fragments(payload)
 local out={};local first=1
 while first<=#payload do local last=math.min(first+119,#payload)
  while last>=first and last<#payload and payload:byte(last+1)>=128 and payload:byte(last+1)<192 do last=last-1 end
  if last<first then return end;out[#out+1]=payload:sub(first,last);first=last+1
 end
 return out
end
function G.Attach(s,d,fixture)
 local C=ns.AetherCertificates
 s.gameQueue={};s.gameOrder={};s.gameMetrics={sent=0,bytes=0,received=0,rejected=0,coalesced=0,appearanceACKs=0,credentialChecks=0,fragmentsReceived=0,fragmentsSent=0,movementACKs=0}
 s.applicationOut={};s.applicationOrder={};s.applicationWaiting={};s.applicationCount=0;s.applicationSerial=0;s.applicationBytes=0;s.applicationMetrics={queued=0,received=0,acked=0,dropped=0,retries=0,frameAttempts=0,framesSent=0,framesReceived=0}
 local function reject()s.gameMetrics.rejected=s.gameMetrics.rejected+1;return true end
 local function queue(text,p,channel)
  if #s.queue>=28 then return false end
  if text:sub(1,3)=='C2|'then return s.QueueCredential(text,p)end
  return s.QueueControl(text,p,channel)
 end
 local function credentials()
  if not s.context then return end
  s.context.liveCredentials=s.context.liveCredentials or{};return s.context.liveCredentials
 end
 function s:RequestCredential(p)
  if not C.Decode or not self.Valid()or not(self.roster[p.id]or p.hintVia or p.status=='CONNECTED')then return false end
  if d.clock()<(p.credentialRetry or 0)then return false end
  p.credentialRetry=d.clock()+45;p.credentialParts=nil;p.credentialWanted=d.clock()+70
  return queue('C2|GET|'..self.session,p)
 end
 local function receiveCredential(text,channel,id,display)
  if not C.Decode or not C.Encode then return reject()end
  local p=s.peers[id]
  if text:match('^C2|GET|[a-f0-9]+$')then
   if #text~=19 or channel~='WHISPER'then return reject()end
   local now=d.clock();s.credentialSentAt=s.credentialSentAt or{}
   for key,at in pairs(s.credentialSentAt)do if now-at>180 then s.credentialSentAt[key]=nil end end
   if not s.roster[id]and not d.certificate(id,s.context)then
    -- A signed topology hint can introduce previously unknown guilds.
    -- Releasing OUR PUBLIC certificate grants no trust or gameplay access.
    -- Limit unknown-address responses globally, as well as per address.
    if now<(s.unknownCredentialAt or-100)+30 then return reject()end;s.unknownCredentialAt=now
   end
   if size(s.credentialSentAt)>=20 and not s.credentialSentAt[id]then return reject()end
   if now<(s.credentialSentAt[id]or-100)+45 then return true end
   local current=C.LocalCertificate and C.LocalCertificate(s.context.ledger)
   local blob=current and current.public==s.context.material.public and current.blob or s.context.cert.blob
   if not blob or #blob>6500 then return reject()end
   local encoded=C.Encode(blob);if #encoded>8800 then return reject()end
   -- One bounded transfer, pumped through the same budget. No certificate
   -- is trusted until C.Certificate verifies its chain and native name/GUID.
   s.credentialSentAt[id]=now
   s.credentialOut=s.credentialOut or{}
   if #s.credentialOut>=4 then return reject()end
   s.credentialOut[#s.credentialOut+1]={peer={id=id,name=display,publicCredentialReply=true},data=encoded,next=1,total=math.ceil(#encoded/200),expires=now+90}
   return true
  end
  if channel~='WHISPER'or not p or not p.credentialWanted or p.credentialWanted<d.clock()then return reject()end
  local index,total,data=text:match('^C2|CERT|(%d+)|(%d+)|([%w%+/%-_=]+)$')
  index,total=tonumber(index),tonumber(total)
  if not int(index,1,44)or not int(total,1,44)or index>total or #data>200 then return reject()end
  local r=p.credentialParts
  if not r then r={total=total,parts={},n=0};p.credentialParts=r end
  if r.total~=total then return reject()end
  if not r.parts[index]then r.parts[index]=data;r.n=r.n+1 end
  if r.n==total then
   p.credentialParts=nil;p.credentialWanted=nil;local encoded=table.concat(r.parts)
   s.CryptoJob(function()
    local blob=C.Decode(encoded,6500);local cert=blob and C.Certificate(blob)
    s.gameMetrics.credentialChecks=s.gameMetrics.credentialChecks+1
    local endpoint=cert and d.name(cert.name..'-'..cert.realm)
    local native=s.roster[id]
    if not s.enabled or not cert or endpoint~=id or not cert.scopes.community or native and cert.guid~=native.guid or C.IsRevoked(s.context.ledger,cert)then reject();return end
    local bank=credentials();if size(bank)>=20 and not bank[id]then reject();return end
    bank[id]=cert;p.nextAttempt=0
    if p.deferredHint then local h=p.deferredHint;p.deferredHint=nil;s:VerifyDiscovery(h)
    else s:Connect(display,'VERIFIED_COMMUNITY_CREDENTIAL')end
   end)
  end
  return true
 end
 function s:Publish(kind,payload,refresh)
  if(kind~='A'and kind~='M')or type(payload)~='string'or #payload>(kind=='A'and G.MAX_APPEARANCE or 190)then return false end
  self.localGame=self.localGame or{};if self.localGame[kind]~=payload or refresh==true and kind=='M'then
   self.gameSerial=(self.gameSerial or 0)+1;self.localGame[kind]=payload
   self.localVersions=self.localVersions or{};self.localVersions[kind]=self.gameSerial
   self.localAt=self.localAt or{};self.localAt[kind]=d.stamp()
   for _,p in pairs(self.peers)do p.gameOffered=p.gameOffered or{};p.gameOffered[kind]=nil end
  end;return true
 end
 local function offer(p,kind,payload,version)
  local key=p.id..'/'..kind;local old=s.gameQueue[key]
  if old and old.version==version then return end
  if not old and #s.gameOrder>=40 then return end
  if old then s.gameMetrics.coalesced=s.gameMetrics.coalesced+1 else s.gameOrder[#s.gameOrder+1]=key end
  s.gameQueue[key]={peer=p,kind=kind,payload=payload,version=version,next=1,total=math.ceil(#payload/120),expires=d.clock()+45,at=kind=='M'and s.localAt and s.localAt[kind]}
  p.gameOffered=p.gameOffered or{};p.gameOffered[kind]=version
 end
 function s:QueueApplication(p,name,payload)
  local spec=G.Applications[name]
  if not self.enabled or not self.Valid()or not spec or not p or p.status~='CONNECTED'or p.applicationVersion~=G.APPLICATION_PROTOCOL or p.applicationSession~=p.session
   or not p.expires or p.expires<d.clock()or type(payload)~='string'or #payload>(spec.maxBytes or 10000)or #payload>10000 or payload:find('%z')or not d.sendLogged then return false end
  if self.applicationCount>=8 or self.applicationBytes+#payload>48000 then return false end
  local body=name..':'..G.LoggedText(payload);local parts=G.Fragments(body);if not parts or #parts>84 then return false end
  self.applicationSerial=self.applicationSerial+1;if self.applicationSerial>9999999 then return false end
  local q={peer=p,session=self.session,destination=p.session,version=self.applicationSerial,parts=parts,next=1,expires=d.clock()+180,bytes=#payload,retries=0}
  if self.applicationOut[p.id]then self.applicationWaiting[#self.applicationWaiting+1]=q else self.applicationOut[p.id]=q;self.applicationOrder[#self.applicationOrder+1]=p.id end
  self.applicationCount=self.applicationCount+1
  self.applicationBytes=self.applicationBytes+#payload;self.applicationMetrics.queued=self.applicationMetrics.queued+1;return true
 end
 local function dropApplication(id,acked)
  local q=s.applicationOut[id];if not q then return end
  s.applicationBytes=s.applicationBytes-q.bytes;s.applicationOut[id]=nil
  s.applicationCount=s.applicationCount-1
  for i=#s.applicationOrder,1,-1 do if s.applicationOrder[i]==id then table.remove(s.applicationOrder,i)end end
  for i,pending in ipairs(s.applicationWaiting)do if pending.peer.id==id then s.applicationOut[id]=pending;table.remove(s.applicationWaiting,i);s.applicationOrder[#s.applicationOrder+1]=id;break end end
  local key=acked and'acked'or'dropped';s.applicationMetrics[key]=s.applicationMetrics[key]+1
 end
 local function appACK(p,kind,seq)
  local text=table.concat({'P2',s.session,p.session,seq,d.stamp(),'K',1,1,kind},'|')
  -- ACKs are gameplay maintenance, bounded/coalesced, not signed control jobs.
  s.gameACK=s.gameACK or{};s.gameACK[p.id..'/'..kind]={text=text,peer=p,expires=d.clock()+20}
 end
 function s:GameIngress(text,channel,id,display,logged)
  if text:sub(1,3)=='C2|'then return receiveCredential(text,channel,id,display)end
  if text:sub(1,3)~='P2|'then return false end
  if channel~='WHISPER'then return reject()end
  local p=self.peers[id]
  if not p or p.status~='CONNECTED'or not p.session or not p.expires or p.expires<d.clock()or not d.certificate(id,self.context)then return reject()end
  local session,destination,seq,at,kind,index,total,data=text:match('^P2|([a-f0-9]+)|([a-f0-9]+)|(%d+)|(%d+)|([AMKS])|(%d+)|(%d+)|(.*)$')
  if kind=='S'then
   self.applicationMetrics.framesReceived=self.applicationMetrics.framesReceived+1
   if logged~=true or p.applicationVersion~=G.APPLICATION_PROTOCOL or p.applicationSession~=p.session or data:find('[%z\1-\31\127]')then self.applicationLastReject='LOGGED_FRAME_OR_PROTOCOL';return reject()end
  elseif not data or not data:match('^[%w,:_%-]*$')then return reject()end
  seq,at,index,total=tonumber(seq),tonumber(at),tonumber(index),tonumber(total)
  if session~=p.session or destination~=self.session or not int(seq,1,9999999)or not int(at,1,4102444800)or math.abs(d.stamp()-at)>30
   or not int(index,1,kind=='S'and 84 or 15)or not int(total,1,kind=='S'and 84 or 15)or index>total or #data>120 then return reject()end
  if d.clock()-(p.gameRateAt or-100)>=10 then p.gameRateAt=d.clock();p.gameRate=0 end
  p.gameRate=(p.gameRate or 0)+1;if p.gameRate>64 then return reject()end
  p.gameSession=p.gameSession or session
  if p.gameSession~=session then p.gameSession=session;p.gameReceived={};p.gameParts={};p.gameACKed={};p.gameOffered={}end
  p.gameACKed=p.gameACKed or{}
  if kind=='K'then
   if index~=1 or total~=1 or(data~='A'and data~='M'and data~='S')then return reject()end
   if data=='S'then local q=self.applicationOut[p.id];if q and q.version==seq and q.destination==p.session then dropApplication(p.id,true);p.expires=d.clock()+120;return true end;return reject()end
   local localVersion=self.localVersions and self.localVersions[data]
   if localVersion~=seq then return reject()end
   if data=='A'and p.gameACKed.A~=seq then self.gameMetrics.appearanceACKs=self.gameMetrics.appearanceACKs+1 end
   if data=='M'and p.gameACKed.M~=seq then self.gameMetrics.movementACKs=self.gameMetrics.movementACKs+1 end
   p.gameACKed[data]=seq;p.expires=d.clock()+120;return true
  end
  p.gameReceived=p.gameReceived or{};p.gameParts=p.gameParts or{}
  self.gameMetrics.fragmentsReceived=self.gameMetrics.fragmentsReceived+1
  local prior=p.gameReceived[kind]or 0
  if seq<=prior then
   if seq==prior and d.clock()>=(p.gameACKAt or 0)then appACK(p,kind,seq);p.gameACKAt=d.clock()+2 end
   return true
  end
  local r=p.gameParts[kind]
  if not r or seq>r.seq then r={seq=seq,total=total,parts={},n=0,expires=d.clock()+(kind=='S'and 180 or 35)};p.gameParts[kind]=r end
  if seq~=r.seq or total~=r.total or r.expires<d.clock()then return reject()end
  if not r.parts[index]then r.parts[index]=data;r.n=r.n+1 end
  if r.n==total then
   p.gameParts[kind]=nil;local payload=table.concat(r.parts)
   if kind=='A'then
    local appearance,form,v2=G.AppearanceDecode(payload,at);if not appearance then return reject()end
    p.liveAppearance=appearance;p.liveAppearanceV2=v2;p.liveForm=form;p.appearanceVersion=seq
   elseif kind=='S'then
    local name,encoded=payload:match('^([a-z][a-z0-9]*):(.*)$');local body=encoded and G.UnloggedText(encoded);local spec=name and G.Applications[name]
    if not spec or not body or #body>(spec.maxBytes or 10000)then self.applicationLastReject='APPLICATION_TEXT_OR_SIZE';return reject()end
    local ok,accepted=pcall(spec.receive,self,p,body);if not ok or accepted~=true then return reject()end
    self.applicationMetrics.received=self.applicationMetrics.received+1
   else
    local state=G.StateDecode(payload);if not state then
     local revision=payload:match('^[fa],([%w%-_]+),');p.sceneCompatibility=revision and not G.Compatible(revision)and'INCOMPATIBLE_GEOMETRY'or'INVALID_MOVEMENT'
     p.gameError='SCENE_OR_PAYLOAD_INCOMPATIBLE';return reject()
    end
    p.sceneCompatibility='COMPATIBLE';p.gameError=nil
    state.received=d.clock();state.at=at;state.seq=seq;p.liveState=state
   end
   p.gameReceived[kind]=seq;p.expires=d.clock()+120;self.gameMetrics.received=self.gameMetrics.received+1;appACK(p,kind,seq)
  end
  return true
 end
 function s:GameQueued()return #self.gameOrder>0 or next(self.applicationOut)~=nil or self.gameACK and next(self.gameACK)~=nil end
 function s:GamePump()
  if not self.enabled or not self.Valid()then return end
  if d.paused and d.paused()then return end
  local now=d.clock()
  if self.gameSession~=self.session then
   self.gameSession=self.session;self.gameQueue={};self.gameOrder={};self.gameACK={};self.credentialSentAt={};self.credentialOut={}
   self.applicationOut={};self.applicationOrder={};self.applicationWaiting={};self.applicationCount=0;self.applicationSerial=0;self.applicationBytes=0
   self.gameSerial=0;self.localGame={};self.localVersions={};self.localAt={}
   -- Supplement guild announcements with existing enrolled topology contacts.
   self.nextContact=now+4
  end
  if now>=(self.nextContact or 0)then
   self.nextContact=now+45
   for _,name in ipairs(d.neighbors and d.neighbors(self.context)or{})do self:Connect(name,'RELAY_CONTACT')end
   for _,p in pairs(self.peers)do
    if p.status~='CONNECTED'and now>=p.nextAttempt then self:Connect(p.name,p.path)end
    if p.credentialParts and(p.credentialWanted or 0)<now then p.credentialParts=nil end
   end
  end
  local transfer=self.credentialOut and self.credentialOut[1]
  if transfer then
   if transfer.expires<now then table.remove(self.credentialOut,1)
   elseif #self.queue<4 then
    local index=transfer.next;local payload=transfer.data:sub((index-1)*200+1,index*200)
    if queue('C2|CERT|'..index..'|'..transfer.total..'|'..payload,transfer.peer)then
     transfer.next=index+1;if transfer.next>transfer.total then table.remove(self.credentialOut,1)end
    end
   end
  end
  for _,p in pairs(self.peers)do if p.status=='CONNECTED'and p.session and p.expires and p.expires>now then
   if p.gameSession~=p.session then p.gameSession=p.session;p.gameReceived={};p.gameParts={};p.gameACKed={};p.gameOffered={};p.appearanceSentVersion=nil;p.liveState=nil;p.liveAppearance=nil;p.liveAppearanceV2=nil;p.liveForm=nil;p.renderReport=nil;p.renderActor=nil;p.renderItems=nil;p.sceneCompatibility=nil end
   if self.AdvertiseApplications and now>=(p.nextApplications or 0)then p.nextApplications=now+30;self:AdvertiseApplications(p)end
   for _,kind in ipairs({'M','A'})do
    local payload=self.localGame and self.localGame[kind];local version=self.localVersions and self.localVersions[kind]
    local relevant=kind=='A'or not p.liveState or not self.localScene or p.liveState.scene==self.localScene or p.lastSentScene~=self.localScene
    p.gameOffered=p.gameOffered or{}
    p.gameRetryAt=type(p.gameRetryAt)=='table'and p.gameRetryAt or{}
    if payload and relevant and(p.gameOffered[kind]~=version or p.gameACKed[kind]~=version and now>=(p.gameRetryAt[kind]or 0))then
     offer(p,kind,payload,version);p.gameRetryAt[kind]=now+18
     if kind=='M'then p.lastSentScene=self.localScene end
    end
   end
  end end
  -- Essential signed handshakes and withdrawal run before application data.
  if #self.queue>0 or #self.jobs>0 then return end
  local ackKey,ack=next(self.gameACK or{})
  for key,value in pairs(self.gameACK or{})do if value.text:sub(-1)~='S'then ackKey,ack=key,value;break end end
  if ack and(ack.text:sub(-1)~='S'or #self.gameOrder==0)then
   if ack.expires<now or ack.peer.status~='CONNECTED'then self.gameACK[ackKey]=nil;return end
   if d.budget(#ack.text,'live-game')then
    local ok=d.send(ack.text,'WHISPER',ack.peer.name)
    if ok then self.gameACK[ackKey]=nil;self.gameMetrics.sent=self.gameMetrics.sent+1;self.gameMetrics.bytes=self.gameMetrics.bytes+#ack.text end
   end;return
  end
  local key=self.gameOrder[1];local q=key and self.gameQueue[key]
  if not q then
   -- Background traffic gets only bandwidth left by control, movement and appearance.
   local id,app
   for i=1,#self.applicationOrder do
    local candidate=table.remove(self.applicationOrder,1);self.applicationOrder[#self.applicationOrder+1]=candidate
    local q=self.applicationOut[candidate]
    if q and(q.next<=#q.parts or now>=(q.retryAt or 0)or q.expires<now)then id,app=candidate,q;break end
   end
   if not app then return end
   local p=app.peer
   if app.expires<now or p.status~='CONNECTED'or p.session~=app.destination or self.session~=app.session then dropApplication(id);return end
   if app.next>#app.parts then
    if now<(app.retryAt or 0)then return end
    if app.retries>=2 then dropApplication(id);return end
    app.next=1;app.retries=app.retries+1;self.applicationMetrics.retries=self.applicationMetrics.retries+1
   end
   local text=table.concat({'P2',self.session,p.session,app.version,d.stamp(),'S',app.next,#app.parts,app.parts[app.next]},'|')
   if d.budget(#text,'live-records')then self.applicationMetrics.frameAttempts=self.applicationMetrics.frameAttempts+1;local ok,result=d.sendLogged(text,'WHISPER',p.name);self.applicationLastSend=result
    if ok then self.applicationMetrics.framesSent=self.applicationMetrics.framesSent+1;app.next=app.next+1;app.retryAt=now+30;self.gameMetrics.sent=self.gameMetrics.sent+1;self.gameMetrics.bytes=self.gameMetrics.bytes+#text end
   end
   return
  end
  local p=q.peer
  if q.expires<now or p.status~='CONNECTED'or not p.session or not d.certificate(p.id,self.context)then
   self.gameQueue[key]=nil;table.remove(self.gameOrder,1);return
  end
  local data=q.payload:sub((q.next-1)*120+1,q.next*120)
  local text=table.concat({'P2',self.session,p.session,q.version,q.at or d.stamp(),q.kind,q.next,q.total,data},'|')
  if d.budget(#text,'live-game')then
   local ok=d.send(text,'WHISPER',p.name)
   if ok then
    self.gameMetrics.sent=self.gameMetrics.sent+1;self.gameMetrics.bytes=self.gameMetrics.bytes+#text;self.gameMetrics.fragmentsSent=self.gameMetrics.fragmentsSent+1
    q.next=q.next+1
    table.remove(self.gameOrder,1)
    if q.next>q.total then if q.kind=='A'then p.appearanceSentVersion=q.version end;self.gameQueue[key]=nil else self.gameOrder[#self.gameOrder+1]=key end
   end
  end
 end
 function s:GameLeave()
  self.applicationOut={};self.applicationOrder={};self.applicationWaiting={};self.applicationCount=0;self.applicationBytes=0
  self.gameQueue={};self.gameOrder={};self.gameACK={};self.localGame={};self.localVersions={};self.localAt={};self.credentialOut={};self.credentialSentAt={}
  for _,p in pairs(self.peers)do p.liveState=nil;p.liveAppearance=nil;p.liveAppearanceV2=nil;p.liveForm=nil;p.renderReport=nil;p.renderActor=nil;p.renderItems=nil;p.sceneCompatibility=nil;p.appearanceSentVersion=nil;p.gameParts=nil;p.credentialParts=nil;p.credentialWanted=nil;p.gameOffered=nil;p.gameReceived=nil;p.gameACKed=nil;p.gameSession=nil end
 end
 local export=s.Export
 function s:Export()
  local out=export(self);out.gameplay=self.gameMetrics;out.applications=self.applicationMetrics;out.sharedRevision=G.SCENE_REVISION;out.geometrySignature=G.GEOMETRY_SIGNATURE;out.gameplayProtocol=G.PROTOCOL
  out.appearanceCapture=ns.AetherLive.localAppearanceStatus or'NOT_REQUESTED'
  out.authentication='Signed certificate and two-way challenge; gameplay bound to the authenticated native sender + both session IDs; sequences/freshness checked. No per-frame signatures.'
  out.appearance='Self-reported recipe; native unit likeness when readable, otherwise declared race/sex and available standalone equipment. Unknown face/body customizations are not invented.'
  for _,row in ipairs(out.peers)do local p=self.peers[d.name(row.name)];row.scene=p.liveState and p.liveState.scene;row.appearanceReceived=p.liveAppearance~=nil;row.gameError=p.gameError
   row.appearanceSent=self.localVersions and self.localVersions.A~=nil and p.appearanceSentVersion==self.localVersions.A or false
   row.appearanceACKed=self.localVersions and self.localVersions.A~=nil and p.gameACKed and p.gameACKed.A==self.localVersions.A or false
   row.sceneCompatibility=p.sceneCompatibility or'AWAITING_MOVEMENT';row.render=p.renderReport;row.geometryDetail=p.gameErrorDetail
  end
  return out
 end
end
