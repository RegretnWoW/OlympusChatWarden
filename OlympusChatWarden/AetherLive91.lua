-- Authenticated volatile Live sessions. Historical Relay remains independent.
local _,ns=...
local A,C,X,N=ns.AetherNative,ns.AetherCertificates,ns.AetherCrypto,ns.AetherNet
local L={VERSION=2,PREFIX='OWALive1',PUBLIC_ENABLED=true,NATIVE_VERIFIED=false,AVATARS_ENABLED=true};ns.AetherLive=L
local function count(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
local function hex(s,n)return type(s)=='string'and #s==n and not s:find('[^a-f0-9]')end
local function clock()return ns.SafeNumber(ns.SafeCall(GetTime))or 0 end
local function stamp()return math.floor(ns.SafeNumber(ns.SafeCall(GetServerTime))or 0)end
local function hash(s)return ns.PackCrypto.Hex(ns.PackCrypto.SHA256(s))end
-- Forever's native realm labels describe layers, not whisper destinations.
-- This address is volatile and used only by Live and its enrollment carrier;
-- certificate principals, saved owners and historical Relay remain unchanged.
function L.Name(value)
 if C.Namespace()=='forever'and ns.CanRead(value)then
  value=ns.Shield.NormalName(value)
  if not value:find('-',1,true)then
   local layer=ns.SafeCall(GetNormalizedRealmName)or ns.SafeCall(GetRealmName)
   if ns.CanRead(layer)then value=value..'-'..layer end
  end
 end
 local id,display,base,realm=A.NativeName(value)
 if id and C.Namespace()=='forever'then id=base:lower()..'-forever'end
 return id,display,base,realm
end
function L.WhisperTarget(value)
 if C.Namespace()=='forever'then local id,_,base=L.Name(value);return id and base end
 return ns.RelayTransport.WhisperTarget(value)
end
local function nativeRoster()
 local out={};local n=math.min(1000,ns.SafeNumber(ns.SafeCall(GetNumGuildMembers))or 0)
 for i=1,n do
  local row={pcall(GetGuildRosterInfo,i)};local id,display
  if row[1]and ns.CanRead(row[2])then
   local name=row[2];if not name:find('-',1,true)then name=name..'-'..tostring(ns.SafeCall(GetRealmName)or'')end
   id,display=L.Name(name)
  end
  local guid=row[18]
  if row[1]and id and ns.Readable(guid)and ns.ChronicleStore.GUID(guid)then out[id]={name=display,guid=guid}end
 end
 return out
end
local function verifiedMember()
 local m=ns.Membership;return m and m.allowed==true and(m.method=='olympus-api'or m.method=='olympus')
end
local function context(purpose)
 if ns.MainStorageBlocked or not ns.Permissions.Owner()or ns.Permissions.Denied('network')then return nil,'PRIVACY_OR_RECOVERY_BLOCK'end
 if not verifiedMember()then return nil,'OLYMPUS_VERIFICATION_REQUIRED'end
 local authorized=purpose=='enrollment'and ns.AetherServices and ns.AetherServices.EnrollmentAuthorized()or purpose~='enrollment'and L.Session and L.Session.Authorized()
 if not authorized then return nil,'EXPLICIT_SERVICE_CONSENT_REQUIRED'end
 local me=A.NativeUnit('player');local ledger=N.Cached();local cert,why=C.LocalCertificate(ledger);local material=C.LocalMaterial()
 if not me or not material then return nil,why or'LIVE_CHARACTER_KEY_REQUIRED'end
 me.id=L.Name(me.name)
 if C.IsRevoked(ledger,{guid=me.guid,keyID=hash(material.public)})then return nil,'KEY_REVOKED'end
 local runtime;if purpose=='enrollment'then runtime=ns.AetherServices and ns.AetherServices.runtime else runtime=L.runtime end
 local active=runtime and runtime.enabled and runtime.context
 if active and active.cert.liveOnly and active.material.public==material.public then cert=active.cert end
 if not cert and L.Session then cert=L.Session.LocalIdentity(me,material)end
 if not cert or not(cert.scopes.community or cert.scopes.live)then return nil,why or'LIVE_IDENTITY_UNAVAILABLE'end
 return {me=me,cert=cert,material=material,ledger=ledger,owner=ns.Permissions.Owner()}
end
local function defaults(purpose)
 local prefix=purpose=='enrollment'and'OWAEnroll1'or L.PREFIX
 return {clock=clock,stamp=stamp,hash=hash,name=L.Name,context=function()return context(purpose)end,roster=nativeRoster,capability=purpose=='enrollment'and'2:enrollment98'or'4:aetheria99',liveSession=true,purpose=purpose or'live',prefix=prefix,
  certificate=function(id,c)
   -- Reuse verified public credentials already accepted by Relay. Never
   -- broadcast certificate blobs or create/enable a Relay ledger here.
   local a=c.ledger and c.ledger.nativeController
   local service=purpose=='enrollment'and ns.AetherServices and ns.AetherServices.runtime or L.runtime
   local native=c.roster[id];local peer=service and service.peers and service.peers[id]
   local _,_,base,realm=A.NativeName(native and native.name or peer and peer.name or id);local principal=base and C.Principal(base,realm)
   local cert=c.liveCredentials and c.liveCredentials[id]or a and a.certified[principal];cert=cert and C.Certificate(cert.blob)
   -- A current authority-issued community grant authorizes enrolled peers
   -- across Olympus guilds. A native roster GUID, when present, must agree.
   -- Neither an unsigned membership claim nor a discovery hint grants access.
   if cert and C.IsRevoked(c.ledger,cert)then return nil,'PEER_KEY_REVOKED'end
   local matches=cert and(cert.principal==principal or C.Namespace()=='forever'and L.Name(cert.name..'-'..cert.realm)==id)
   if not cert or native and cert.guid~=native.guid or not matches or not cert.scopes.community then
    if L.Session then return L.Session.Resolve(id,c,native)end
    return nil,'VERIFIED_PEER_CERTIFICATE_REQUIRED'
   end
   return cert
  end,
  sign=function(c,wire)return X.Sign(c.material.seed,wire)end,
  verify=function(cert,wire,sig)return X.Verify(cert.public,wire,sig)end,
  register=function()
   return A.EnsurePrefix(prefix)
  end,
  send=function(text,channel,target)
   if A.Restricted()then return false,'COMBAT_OR_NATIVE_RESTRICTED'end
   if ns.RelayTransport.Busy and ns.RelayTransport.Busy()or ns.RelayTransport.outgoing and #ns.RelayTransport.outgoing>0 then return false,'GAMEPLAY_TRAFFIC_PRIORITY'end
   local f=C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
   if type(f)~='function'then return false,'ORDINARY_API_UNAVAILABLE'end
   local nativeTarget=target and L.WhisperTarget(target)
   L.nativeTargets=L.nativeTargets or{};L.nativeTargets[purpose or'live']=nativeTarget
   local ok,v=pcall(f,prefix,text,channel,nativeTarget)
   if not ok then return false,'API_EXCEPTION'end
   return A.NativeResult('SendAddonMessageResult',v,true)
  end,
  sendLogged=function(text,channel,target)
   if A.Restricted()then return false,'CONNECTION_PAUSED'end
   if ns.RelayTransport.Busy and ns.RelayTransport.Busy()or ns.RelayTransport.outgoing and #ns.RelayTransport.outgoing>0 then return false,'COMMUNICATION_YIELD'end
   local f=C_ChatInfo and C_ChatInfo.SendAddonMessageLogged
   if type(f)~='function'then return false,'LOGGED_API_UNAVAILABLE'end
   local ok,v=pcall(f,prefix,text,channel,target and L.WhisperTarget(target))
   if not ok then return false,'API_EXCEPTION'end
   return A.NativeResult('SendAddonMessageResult',v,true)
  end,
  guild=function()return ns.Checked(ns.SafeCall(IsInGuild))end,
  neighbors=function(c)
   local out={};local a=c.ledger and c.ledger.nativeController
   if not a or not a.enabled or not N.Preference()then return out end
   for id,p in pairs(a.peers)do
    if #out<2 and p.ready and p.expires>stamp()and a.routes[id]then out[#out+1]=p.name end
   end
   return out
  end,
  budget=function(bytes,service)return A.TakeBudget(bytes,service or'live')end,
  paused=A.Restricted,nativeDiagnostics=A.ConnectionDiagnostics,workBudget=function(thread)X.RecoveryBudget(thread,(ns.WardenPerformance.Now())+2)end}
end
local kinds={FEATURES=true,HELLO=true,HELLO_ACK=true,PING=true,PONG=true,TEST=true,TEST_ACK=true,LEAVE=true,ERROR=true,CAPABILITY=true}
local function parse(text)
 if type(text)~='string'or #text>255 or text:find('[%z\001-\031\127]')then return end
 local f={};for v in(text..'|'):gmatch('(.-)|')do f[#f+1]=v end
 if #f~=10 or f[1]~='L1'or not kinds[f[2]]or not hex(f[3],12)or not(f[4]=='-'or hex(f[4],12))
  or not f[5]:match('^[1-9]%d*$')or #f[5]>7 or not hex(f[6],12)or not f[7]:match('^%d+$')or #f[7]~=10
  or #f[8]>24 or not f[8]:match('^[%w_:%-]*$')or not hex(f[9],16)or not hex(f[10],128)then return end
 return {kind=f[2],session=f[3],destination=f[4],seq=tonumber(f[5]),nonce=f[6],at=tonumber(f[7]),data=f[8],key=f[9],signature=f[10],wire=text:sub(1,#text-129)}
end
L.Parse=parse
function L.New(fixture,purpose)
 if fixture and WARDEN_SIMULATOR_ISOLATED~=true then return nil,'FIXTURE_DISABLED'end
 local d=fixture or defaults(purpose);local s={enabled=false,guildDiscovery=true,peers={},queue={},jobs={},pending={},rows={},hints={},partial={},hintRates={},metrics={sent=0,bytes=0,received=0,rejected=0,dropped=0,retries=0,acked=0,budgetWaits=0,cryptoSlices=0,hints=0,forwarded=0},status='OFF',serial=0}
 local function note(p,status,detail)
  if p then p.status=status;p.detail=detail end
  local row={at=d.stamp(),peer=p and p.name or'',state=status,detail=detail or''};s.rows[#s.rows+1]=row;if #s.rows>96 then table.remove(s.rows,1)end
 end
 local function valid()
  if not s.enabled then return false end
  local c=d.context();return c and c.owner==s.context.owner and c.me.id==s.context.me.id and c.cert.id==s.context.cert.id
 end
 local function token(tag)s.serial=s.serial+1;return d.hash(s.session..'/'..s.serial..'/'..tag):sub(1,12)end
 local function wake()if s==L.runtime then A.Wake()end end
 local function job(run)
  if #s.jobs>=8 then s.metrics.dropped=s.metrics.dropped+1;return false end
  s.jobs[#s.jobs+1]=coroutine.create(run);wake();return true
 end
 local function enqueue(text,p,channel,request,bootstrap)
  if #text>255 or #s.queue>=32 then s.metrics.dropped=s.metrics.dropped+1;return false end
  s.queue[#s.queue+1]={text=text,peer=p,channel=channel or'WHISPER',expires=d.clock()+35,request=request,bootstrap=bootstrap};return true
 end
 local function signed(p,kind,nonce,data,reliable,destination,cacheOnly)
  if not valid()or not p.cert then return false end
  local session=s.session;local seq=s.serial+1;s.serial=seq
  local wire=table.concat({'L1',kind,session,destination or p.session or'-',seq,nonce,d.stamp(),data or'',s.context.cert.id:sub(1,16)},'|')
  return job(function()
   local current=d.certificate(p.id,s.context)
   if not current or current.id~=p.cert.id then if kind=='PING'then p.pingQueued=nil end;note(p,'DENIED','Peer credential or membership changed');return end
   local sig=d.sign(s.context,'AETHER-LIVE/1\n'..p.id..'\n'..wire)
   if not sig or not s.enabled or session~=s.session then if kind=='PING'then p.pingQueued=nil end;return end
   local text=wire..'|'..sig;local request
   if cacheOnly then p.leave=text;return end
   if reliable then
    if count(s.pending)>=12 then if kind=='PING'then p.pingQueued=nil end;s.metrics.dropped=s.metrics.dropped+1;return end
    request={nonce=nonce,kind=kind,peer=p,text=text,attempts=0,deadline=d.clock()+75,queued=true,created=d.clock()};s.pending[nonce]=request
   end
   enqueue(text,p,nil,request);if kind=='PING'then p.pingQueued=nil end
  end)
 end
 local function peer(name,path)
  local id,display=d.name(name);if not id or id==s.context.me.id then return end
  local p=s.peers[id]
  if not p then if count(s.peers)>=20 then s.metrics.dropped=s.metrics.dropped+1;return end;p={id=id,name=display,status='DISCOVERED',path=path,seen={},rateAt=-100,rate=0,nextAttempt=0};s.peers[id]=p end
  return p
 end
 local function resolve(p)
  s.context.roster=s.roster
  local cert,why=d.certificate(p.id,s.context)
  if not cert then note(p,'DENIED',why);return false end
  p.cert=cert;return true
 end
 function s:Start(explicit)
  if explicit~=true then return false,'EXPLICIT_LIVE_CONSENT_REQUIRED'end
  if self.enabled then return true,'ALREADY_ACTIVE'end
  if not fixture and not L.PUBLIC_ENABLED then return false,'PUBLIC_LIVE_DISABLED'end
  local c,why=d.context();if not c then self.status=why;return false,why end
  local ok,reason=d.register();self.registrationResult=reason or(ok and'ACCEPTED'or'FAILED');if not ok then self.status=reason;return false,reason end
  self.departures={};self.context=c;self.roster=d.roster();c.roster=self.roster;self.serial=self.serial+1;self.session=d.hash(c.me.id..'/'..d.clock()..'/'..d.stamp()..'/'..self.serial):sub(1,12)
  self.startedAt=d.clock();self.registered=true;self.enabled=true;self.status='DISCOVERING';self.nextPresence=d.clock()+3;self.nextRoster=d.clock()+120;self.lastCheck=-100;note(nil,'JOIN','Experimental Live; native connectivity UNVERIFIED');wake();return true
 end
 function s:SetGuildDiscovery(value)
  if type(value)~='boolean'then return false end
  self.guildDiscovery=value
  for i=#self.queue,1,-1 do if not value and self.queue[i].channel=='GUILD'then table.remove(self.queue,i);self.metrics.dropped=self.metrics.dropped+1 end end
  if value and self.enabled then self.nextPresence=d.clock()+3 end
  return true
 end
 function s:Connect(name,path)
  if not valid()then return false,'LIVE_CONSENT_REQUIRED'end
  local p=peer(name,path or'KNOWN_CONTACT');if not p then return false,'EXACT_NAME_REALM_REQUIRED'end
  if d.clock()<p.nextAttempt then return false,'PEER_BACKOFF'end
  if p.hello or p.session and p.expires and p.expires>d.clock()then return true,'ALREADY_PENDING_OR_CONNECTED'end
  if not resolve(p)then p.nextAttempt=d.clock()+60;if self.RequestCredential then self:RequestCredential(p)end;return false,p.detail end
  p.nextAttempt=d.clock()+60;p.hello=token('hello');p.seen={};note(p,'CONNECTING','WHISPER; waiting for signed ACK')
  return signed(p,'HELLO',p.hello,d.capability or'1',true,'-')
 end
 local function neighbors()
  local out={}
  for _,name in ipairs(d.neighbors and d.neighbors(s.context)or{})do
   local id,display=d.name(name)
   if id and id~=s.context.me.id and #out<2 and d.certificate(id,s.context)then out[#out+1]={id=id,name=display}end
  end
  return out
 end
 local function hintWire(h)return table.concat({h.session,h.id,h.expires,h.endpoint,'1'},'\n')end
 local function forward(h,exclude)
  if h.hop>=2 then return end
  for _,p in ipairs(neighbors())do if p.id~=exclude and p.id~=h.origin then
   local head=table.concat({'L1','LIVE_HELLO',h.session,h.id,h.expires,h.hop+1,'1',h.endpoint},'|')
   if #s.queue<=30 then
    enqueue(head,p);enqueue('L1|LIVE_PROOF|'..h.id..'|'..h.key..'|'..h.signature,p);s.metrics.forwarded=s.metrics.forwarded+1
   end
  end end
 end
 function s:AdvertiseTopology()
  if not valid()or #self.context.me.name>140 or #neighbors()==0 then return false end
  local h={session=self.session,id=token('discovery'),expires=d.stamp()+90,hop=-1,endpoint=self.context.me.name,origin=self.context.me.id,key=self.context.cert.id:sub(1,16)}
  return job(function()
   h.signature=d.sign(self.context,'AETHER-LIVE-DISCOVERY/1\n'..hintWire(h))
   if h.signature and valid()then forward(h);self.hints[h.id]={expires=h.expires,origin=h.origin}end
  end)
 end
 function s:DiscoveryIngress(text,sender)
  local id=d.name(sender);local authorized=false
  for _,n in ipairs(neighbors())do if id==n.id then authorized=true;break end end
  if not authorized then return false end
  local sid,mid,expiry,hop,endpoint=text:match('^L1|LIVE_HELLO|([a-f0-9]+)|([a-f0-9]+)|(%d+)|([012])|1|([^|]+)$')
  if sid then
   local origin,display=d.name(endpoint);expiry=tonumber(expiry);hop=tonumber(hop)
   if not hex(sid,12)or not hex(mid,12)or #endpoint>140 or not origin or origin==self.context.me.id
    or expiry<=d.stamp()or expiry>d.stamp()+95 or self.hints[mid]or count(self.partial)>=8 then return false end
   if not self.hintRates[id]and count(self.hintRates)>=20 then return false end
   local rate=self.hintRates[id]or{at=d.clock(),n=0};self.hintRates[id]=rate
   if rate.at+60<=d.clock()then rate.at=d.clock();rate.n=0 end
   if rate.n>=4 then self.metrics.dropped=self.metrics.dropped+1;return false end;rate.n=rate.n+1
   self.partial[id..'/'..mid]={session=sid,id=mid,expires=expiry,hop=hop,endpoint=endpoint,origin=origin,via=id,untilAt=d.clock()+20}
   return true
  end
  local message,key,signature=text:match('^L1|LIVE_PROOF|([a-f0-9]+)|([a-f0-9]+)|([a-f0-9]+)$')
  local h=message and self.partial[id..'/'..message]
  if not h or not hex(key,16)or not hex(signature,128)or h.untilAt<d.clock()then return false end
  self.partial[id..'/'..message]=nil;h.key,h.signature=key,signature
  return self:VerifyDiscovery(h)
 end
 function s:VerifyDiscovery(h)
  return job(function()
   local cert=d.certificate(h.origin,self.context)
   if not cert and self.RequestCredential then
    local candidate=peer(h.endpoint,'UNVERIFIED_RELAY_HINT')
    if candidate then candidate.hintVia=h.via;candidate.deferredHint=h;self:RequestCredential(candidate)end
    return
   end
   if not cert or cert.id:sub(1,16)~=h.key or not d.verify(cert,'AETHER-LIVE-DISCOVERY/1\n'..hintWire(h),h.signature)
    or not valid()or h.expires<=d.stamp()or self.hints[h.id]then self.metrics.rejected=self.metrics.rejected+1;return end
   if count(self.hints)>=32 then self.metrics.dropped=self.metrics.dropped+1;return end
   self.hints[h.id]={expires=h.expires,origin=h.origin};self.metrics.hints=self.metrics.hints+1
   local p=peer(h.endpoint,'RELAY_HINT_VIA/'..h.via)
   if p then
    if p.retired and p.retired[h.session]or p.latestHintExpiry and h.expires<p.latestHintExpiry then return end
    p.latestHintExpiry=h.expires
    if p.rxSession and p.rxSession~=h.session then
     p.session=nil;p.hello=nil;p.expires=nil;p.nextAttempt=0
     for key,r in pairs(self.pending)do if r.peer==p then self.pending[key]=nil end end
     note(p,'DISCOVERED','Fresh signed session hint; new direct ACK required')
    end
    p.discoveryExpires=h.expires;p.hintVia=h.via
    if p.status~='CONNECTED'then note(p,'DISCOVERED','Verified short-lived Relay hint; direct ACK still required');self:Connect(h.endpoint,p.path)end
   end
   forward(h,h.via)
  end)
 end
 function s:Ping(name)
  local p=self.peers[d.name(name)];if not valid()or not p or not p.session then return false,'HANDSHAKE_REQUIRED'end
  if p.pingQueued then return true,'PING_ALREADY_QUEUED'end
  for _,r in pairs(self.pending)do if r.peer==p and r.kind=='PING'then return true,'PING_ALREADY_PENDING'end end
  local nonce=token('ping');p.pingQueued=true;local ok=signed(p,'PING',nonce,'',true);if not ok then p.pingQueued=nil end;return ok
 end
 function s:Test(name,text)
  local p=self.peers[d.name(name)]
  if not valid()or not p or p.status~='CONNECTED'then return false,'ACK_CONFIRMED_CONNECTION_REQUIRED'end
  if type(text)~='string'or #text<1 or #text>24 or not text:match('^[%w_%-]+$')then return false,'USE_1_TO_24_LETTERS_DIGITS_DASH_UNDERSCORE'end
  for _,r in pairs(self.pending)do if r.peer==p and r.kind=='TEST'then return false,'TEST_ALREADY_PENDING'end end
  return signed(p,'TEST',token('test'),text,true)
 end
 local function ack(p,f,kind)
  local r=s.pending[f.nonce]
  if not r or r.peer~=p or r.kind~=kind or r.deadline<d.clock()or not r.sentAt then return false end
  s.pending[f.nonce]=nil;s.metrics.acked=s.metrics.acked+1;p.rttMS=math.max(0,(d.clock()-r.sentAt)*1000);p.lastVerified=d.stamp();p.expires=d.clock()+120
  return r
 end
 local function incoming(p,f)
  if f.kind=='HELLO'then
   if f.destination~='-'or f.data~=(d.capability or'1')then return end
   if p.session and p.session~=f.session then
    for key,r in pairs(s.pending)do if r.peer==p then s.pending[key]=nil end end
    p.hello=nil
   end
   p.session=f.session;p.expires=d.clock()+120;p.lastVerified=d.stamp();if p.status~='CONNECTED'then note(p,'DIRECTLY_REACHABLE','Signed WHISPER received; ACK not confirmed')end
   signed(p,'HELLO_ACK',f.nonce,d.capability or'1');s:Ping(p.name)
  elseif f.destination~=s.session or p.session and f.session~=p.session then return
  elseif f.kind=='HELLO_ACK'then
   if f.data~=(d.capability or'1')or f.nonce~=p.hello or not ack(p,f,'HELLO')then return end
   p.hello=nil;p.session=f.session;if p.status~='CONNECTED'then note(p,'DIRECTLY_REACHABLE','Signed HELLO_ACK')end;s:Ping(p.name)
  elseif(f.kind=='CAPABILITY'or f.kind=='ERROR')and f.nonce==p.hello then
   if ack(p,f,'HELLO')then p.hello=nil;note(p,f.kind=='CAPABILITY'and'INCOMPATIBLE'or'DENIED',f.data)end
  elseif not p.session then return
  elseif f.kind=='PING'then signed(p,'PONG',f.nonce,'')
  elseif f.kind=='PONG'then
   if ack(p,f,'PING')then
    -- Simultaneous discovery can lose a HELLO_ACK while the signed PING/PONG
    -- already confirms both directions. Do not let that obsolete request
    -- later downgrade a connected peer or start a handshake storm.
    for key,r in pairs(s.pending)do if r.peer==p and(r.kind=='HELLO'or r.kind=='PING')then s.pending[key]=nil end end
    p.hello=nil;p.timedOutKind=nil;p.confirmedSession=p.session;p.nextPing=d.clock()+45;note(p,'CONNECTED','Signed PONG; application delivery confirmed');signed(p,'LEAVE',token('leave'),'',false,nil,true)
   end
  elseif f.kind=='FEATURES'then
   if p.status=='CONNECTED'and(f.data=='sync107'or f.data=='sync108')then p.applicationVersion=f.data=='sync108'and 2 or 1;p.applicationSession=p.session end
  elseif f.kind=='TEST'then
   if p.status~='CONNECTED'or #f.data<1 then return end
   p.lastTest=f.data;signed(p,'TEST_ACK',f.nonce,f.data);note(p,'CONNECTED','Received diagnostic TEST '..f.data)
  elseif f.kind=='TEST_ACK'then
   local r=s.pending[f.nonce];if not r or not r.text:find('|'..f.data..'|',1,true)then return end
   if ack(p,f,'TEST')then p.lastTestACK=f.data;note(p,'CONNECTED','TEST_ACK '..f.data)end
  elseif f.kind=='LEAVE'then
   p.session=nil;p.hello=nil;p.expires=nil;p.nextAttempt=d.clock()+2;for key,r in pairs(s.pending)do if r.peer==p then s.pending[key]=nil end end;note(p,'OFFLINE','Explicit signed LEAVE')
  elseif f.kind=='ERROR'or f.kind=='CAPABILITY'then note(p,f.kind=='ERROR'and'DENIED'or'INCOMPATIBLE',f.data)end
 end
 function s:Ingress(prefix,text,channel,sender,logged)
  if not self.enabled or prefix~=(d.prefix or L.PREFIX)or(channel~='WHISPER'and channel~='GUILD')or not valid()then return false end
  -- Native events may omit the realm for a same-realm sender. Qualify only
  -- this server-attributed event using our native realm. Forever's volatile
  -- First Surname address is normalized separately from saved identity.
  if self.context.me.realm and ns.CanRead and ns.CanRead(sender)and not sender:find('-',1,true)then sender=sender..'-'..self.context.me.realm end
  local id,display=d.name(sender);if not id or id==self.context.me.id then return false end
  if type(text)~='string'or #text>255 then self.metrics.rejected=self.metrics.rejected+1;return false end
  if self.SessionIngress and self:SessionIngress(text,channel,id,display)then return true end
  if self.GameIngress and self:GameIngress(text,channel,id,display,logged)then return true end
  if channel=='WHISPER'and(text:sub(1,14)=='L1|LIVE_HELLO|'or text:sub(1,14)=='L1|LIVE_PROOF|')then return self:DiscoveryIngress(text,display)end
  if channel=='GUILD'then
   if not self.guildDiscovery then return false end
   local session,at=text:match('^L1|PRESENCE|([a-f0-9]+)|(%d+)|1$')
   if not hex(session,12)or not at or math.abs(d.stamp()-tonumber(at))>90 or not self.roster[id]then return false end
   local p=peer(display,'SAME_GUILD_HINT');if p and p.status~='CONNECTED'and d.clock()>=p.nextAttempt then self:Connect(display,'SAME_GUILD_HINT')end
   return true -- Hint only; never connected, trusted or a claimed global roster.
  end
  local f=parse(text);if not f or math.abs(d.stamp()-f.at)>90 then self.metrics.rejected=self.metrics.rejected+1;return false end
  local p=self.peers[id]
  if not p then if f.kind~='HELLO'or not(self.roster[id]or d.certificate(id,self.context))then return false end;p=peer(display,'ENROLLED_DIRECT')end
  if not p then return false end
  if d.clock()-p.rateAt>=10 then p.rateAt=d.clock();p.rate=0 end
  p.rate=p.rate+1;if p.rate>8 or self.inboundAt and self.inboundAt==d.stamp()and(self.inboundCount or 0)>=8 then self.metrics.rejected=self.metrics.rejected+1;return false end
  if self.inboundAt~=d.stamp()then self.inboundAt=d.stamp();self.inboundCount=0 end;self.inboundCount=self.inboundCount+1
  if f.kind~='HELLO'and f.destination~=self.session then return false end
  local refusal=(f.kind=='CAPABILITY'or f.kind=='ERROR')and p.hello==f.nonce
  if f.kind~='HELLO'and f.kind~='HELLO_ACK'and not refusal and(not p.session or p.session~=f.session)then return false end
  if p.busy then return false end
  p.busy=true;local session=self.session
  local queued=job(function()
   local cert=self.IngressCredential and self:IngressCredential(id,f.key,f.session)or d.certificate(id,self.context)
   if(not cert or cert.id:sub(1,16)~=f.key or cert.liveOnly and cert.session~=f.session)and self.RequestCredential then self:RequestCredential(p)end
   if cert and(not cert.liveOnly or cert.session==f.session)and cert.id:sub(1,16)==f.key and d.verify(cert,'AETHER-LIVE/1\n'..self.context.me.id..'\n'..f.wire,f.signature)
    and self.enabled and session==self.session and math.abs(d.stamp()-f.at)<=90 then
    p.cert=cert;if cert.liveOnly then cert.expires=d.clock()+180 end;self.metrics.received=self.metrics.received+1
    if p.rxSession and p.rxSession~=f.session then
     if f.kind~='HELLO'and(f.kind~='HELLO_ACK'or f.nonce~=p.hello)then p.busy=nil;return end
     p.retired=p.retired or{}
     for session,expires in pairs(p.retired)do if expires<d.stamp()then p.retired[session]=nil end end
     if p.retired[f.session]then p.busy=nil;return end
     if count(p.retired)>=8 then p.busy=nil;return end
     -- Cover both sides of the accepted clock-skew/replay interval, then
     -- release old IDs. Reconnect protection must not become a lifetime limit.
     p.retired[p.rxSession]=d.stamp()+181;p.highSeq=0;p.seen={};p.seenOrder={};p.answers={};p.requests={}
    end
    p.rxSession=f.session
    local key=f.session..'/'..f.seq
    if p.seen[key]then
     -- Lost ACKs may be replayed from the bounded cached signed answer; never
     -- execute TEST twice, regenerate a response or advance sequence state.
     if p.answers and p.answers[key]then enqueue(p.answers[key],p)end
    elseif f.seq>math.max(0,(p.highSeq or 0)-32)then
     -- Native delivery and finite retries can reorder control packets. Keep a
     -- bounded replay window; a newer PING must not invalidate a lost HELLO_ACK.
     p.highSeq=math.max(p.highSeq or 0,f.seq)
     p.seen[key]=true;p.seenOrder=p.seenOrder or{};p.seenOrder[#p.seenOrder+1]=key
     if #p.seenOrder>32 then local old=table.remove(p.seenOrder,1);p.seen[old]=nil;if p.answers then p.answers[old]=nil end end
     if f.kind=='HELLO'or f.kind=='PING'or f.kind=='TEST'then
      p.requests=p.requests or{};p.requests[#p.requests+1]={nonce=f.nonce,key=key};if #p.requests>32 then table.remove(p.requests,1)end
     end
     if f.kind=='HELLO'and f.data~=(d.capability or'1')then signed(p,'CAPABILITY',f.nonce,'BUILD_OR_PROTOCOL',false,f.session)
     else incoming(p,f)end
    end
   else
    self.metrics.rejected=self.metrics.rejected+1
    if cert and cert.liveOnly and cert.session~=f.session and f.kind=='HELLO'and self.RequestCredential then self:RequestCredential(p)end
   end
   p.busy=nil
  end)
  if not queued then p.busy=nil end;return queued
 end
 function s:Pump()
  self.pumpCalls=(self.pumpCalls or 0)+1;self.lastPumpAt=d.clock();self.pumpStage='START'
  if not self.enabled and #self.queue==0 then return end
  local at=d.clock()
  if self.enabled and self.SessionPump then self:SessionPump()end
  if self.enabled and at-(self.lastCheck or -100)>=2 then
   self.lastCheck=at;if not valid()then self:Leave('Eligibility, enrollment or privacy changed');return end
   local revision=self.context.ledger and self.context.ledger.revision or 0
   if self.credentialRevision~=revision then
    self.credentialRevision=revision
    for _,p in pairs(self.peers)do if p.cert and not d.certificate(p.id,self.context)then
     p.session=nil;p.hello=nil;p.expires=nil
     for key,r in pairs(self.pending)do if r.peer==p then self.pending[key]=nil end end
     note(p,'DENIED','Peer credential revoked, expired or no longer eligible')
    end end
   end
  end
  if self.enabled and at>=self.nextRoster then self.roster=d.roster();self.context.roster=self.roster;self.nextRoster=at+120 end
  local paused,reason;if d.paused then paused,reason=d.paused()end
  self.pauseReason=paused and(reason or'PAUSED')or nil
  if self.enabled and paused then self.pumpStage='PAUSED';return end
  self.pumpStage='CRYPTO_AND_CONTROL'
  local thread=self.jobs[1]
  if thread then
   if d.workBudget then d.workBudget(thread)end
   self.metrics.cryptoSlices=self.metrics.cryptoSlices+1;local ok,err=coroutine.resume(thread)
   if not ok or coroutine.status(thread)=='dead'then table.remove(self.jobs,1)end
   if not ok then self.metrics.rejected=self.metrics.rejected+1;self.status='CRYPTO_JOB_FAILED';if fixture and d.onError then d.onError(tostring(err))end;for _,p in pairs(self.peers)do p.busy=nil end end
  end
  if self.enabled then
   for key,h in pairs(self.hints)do if h.expires<=d.stamp()then self.hints[key]=nil end end
   for key,h in pairs(self.partial)do if h.untilAt<=at or h.expires<=d.stamp()then self.partial[key]=nil end end
   for key,r in pairs(self.pending)do
    if r.deadline<=at or r.attempts>=3 and not r.queued and at>=(r.retryAt or 0)then
     self.pending[key]=nil;r.peer.hello=nil;r.peer.timedOutKind=r.kind;note(r.peer,'TIMED_OUT',r.kind..' ACK missing; enqueue is not delivery')
    elseif not r.queued and r.retryAt and at>=r.retryAt then r.queued=enqueue(r.text,r.peer,nil,r);if r.queued then self.metrics.retries=self.metrics.retries+1 end end
   end
   for _,p in pairs(self.peers)do
    if p.expires and p.expires<=at then p.expires=nil;p.session=nil;p.hello=nil;note(p,'UNREACHABLE','No fresh application ACK; partition or offline')
    elseif p.status=='CONNECTED'and at>=(p.nextPing or math.huge)then p.nextPing=at+60;self:Ping(p.name)
    elseif p.session and(p.confirmedSession~=p.session or p.timedOutKind=='PING')and p.status~='CONNECTED'and at>=(p.nextPing or 0)then
     -- A bounded crypto/pending queue may refuse the first challenge when a
     -- group arrives simultaneously. Retry that challenge without restarting
     -- the already authenticated session or waiting two minutes for expiry.
     p.nextPing=at+12;self:Ping(p.name)
    end
   end
   if at>=self.nextPresence then
    -- Shared Relay topology is only a discovery route. Movement and TEST never
    -- enter the Relay record pipeline. Refresh is deliberately infrequent.
    self.nextPresence=at+90+(tonumber(self.session:sub(1,2),16)%16);self:AdvertiseTopology()
    if self.guildDiscovery and d.guild()then enqueue('L1|PRESENCE|'..self.session..'|'..d.stamp()..'|1',nil,'GUILD')end
   end
  end
  local q=self.queue[1]
  if q then
   if not valid()then self:Leave('Permission changed before send');return end
   if q.expires<=at or q.request and self.pending[q.request.nonce]~=q.request or q.peer and not d.certificate(q.peer.id,self.context)and not(q.bootstrap and(q.peer.publicCredentialReply or self.roster[q.peer.id]or self.peers[q.peer.id]and self.peers[q.peer.id].hintVia))then table.remove(self.queue,1);self.metrics.dropped=self.metrics.dropped+1
   elseif d.budget(#q.text)then
    local ok,why=d.send(q.text,q.channel,q.peer and q.peer.name);self.lastNativeResult=why
    if ok then
     self.metrics.sent=self.metrics.sent+1;self.metrics.bytes=self.metrics.bytes+#q.text;table.remove(self.queue,1)
     if q.peer then q.peer.enqueue=why end
     if q.request then local r=q.request;r.queued=false;r.attempts=r.attempts+1;r.sentAt=at;r.retryAt=at+({8,16,25})[r.attempts]end
     local f=parse(q.text)
     if q.peer and f and(f.kind=='HELLO_ACK'or f.kind=='PONG'or f.kind=='TEST_ACK')then
      q.peer.answers=q.peer.answers or{}
      -- Match response nonce to its originating request's sequence.
      for _,row in ipairs(q.peer.requests or{})do if row.nonce==f.nonce then q.peer.answers[row.key]=q.text end end
     end
    elseif why~='COMBAT_OR_NATIVE_RESTRICTED'and why~='GAMEPLAY_TRAFFIC_PRIORITY'then
     table.remove(self.queue,1);if q.request then q.request.queued=false;q.request.attempts=q.request.attempts+1;q.request.retryAt=at+16 end
     if q.peer then note(q.peer,'DENIED',why)end
    end
   else self.metrics.budgetWaits=self.metrics.budgetWaits+1 end
  end
  self.pumpStage='COMPLETE'
 end
 function s:Leave(reason)
  -- Withdrawal is synchronous, including during combat. No delayed packet may
  -- resume a withdrawn session. Peers expire without a LEAVE if sending is blocked.
  if not self.enabled then return true end
  self.departures={}
  for _,p in pairs(self.peers)do
   if p.session and p.cert then
    -- A cached signed LEAVE is prepared during the active handshake. Avoid
    -- synchronous crypto, saving, or background work when consent is withdrawn.
    if p.leave then
     if d.budget(#p.leave)then d.send(p.leave,'WHISPER',p.name)
     else self.departures[#self.departures+1]={text=p.leave,name=p.name,expires=d.clock()+8,owner=self.context.owner}end
    end
   end
  end
  self.enabled=false;self.queue={};self.jobs={};self.pending={};self.hints={};self.partial={};self.hintRates={};self.context=nil;self.roster={};self.status='OFF'
  for _,p in pairs(self.peers)do p.session=nil;p.rxSession=nil;p.hello=nil;p.cert=nil;p.busy=nil;p.pingQueued=nil;p.seen={};p.highSeq=nil;p.seenOrder=nil;p.retired=nil;p.answers=nil;p.requests=nil;p.leave=nil;p.expires=nil;p.status='OFFLINE';p.nextAttempt=0 end
  if self.GameLeave then self:GameLeave()end
  if self.SessionLeave then self:SessionLeave()end
  note(nil,'LEAVE',reason or'Owner left');wake();return true
 end
 function s:FlushDepartures()
  local q=self.departures and self.departures[1];if not q then return end
  local c=d.context()
  if d.clock()>=q.expires or not c or c.owner~=q.owner then table.remove(self.departures,1)
  elseif not(d.paused and d.paused())and d.budget(#q.text)then d.send(q.text,'WHISPER',q.name);table.remove(self.departures,1)end
  if #self.departures==0 then wake()end
 end
 function s:Export()
  local out={format='FIRESIDE_AETHER_LIVE_2',nativeVerified=false,worldAvatars=L.AVATARS_ENABLED,enabled=self.enabled,guildDiscovery=self.guildDiscovery,status=self.status,peers={},metrics={},rows=self.rows,
   discovery='Guild and enrolled contacts; signed Relay hints (2 hops/90s). Native realm/layer reachability UNVERIFIED.',relayUnchanged=true,persistedPackets=0,publicEnabled=L.PUBLIC_ENABLED}
  for k,v in pairs(self.metrics)do out.metrics[k]=v end
  local paused,reason;if d.paused then paused,reason=d.paused()end
  out.connection={prefix=d.prefix or L.PREFIX,registered=self.registered==true,registrationResult=self.registrationResult or'NOT_ATTEMPTED',
   enabled=self.enabled,valid=self.enabled and valid()or false,paused=paused==true,pauseReason=reason or'NONE',pumpCalls=self.pumpCalls or 0,
   pumpStage=self.pumpStage or'NOT_STARTED',lastPumpAge=self.lastPumpAt and math.max(0,d.clock()-self.lastPumpAt),
   activeSeconds=self.startedAt and math.max(0,d.clock()-self.startedAt),controlQueue=#self.queue,cryptoQueue=#self.jobs,pendingACKs=count(self.pending),
   roster=count(self.roster or{}),peerCount=count(self.peers),lastSendResult=self.lastNativeResult or'NOT_ATTEMPTED',
   ordinaryEvents=self.ordinaryEvents or 0,loggedEvents=self.loggedEvents or 0,lastReceiveAge=self.lastReceiveAt and math.max(0,d.clock()-self.lastReceiveAt),
   native=d.nativeDiagnostics and d.nativeDiagnostics()or nil}
  for _,p in pairs(self.peers)do out.peers[#out.peers+1]={name=p.name,state=p.status,detail=p.detail,path=p.path,hintVia=p.hintVia,enqueue=p.enqueue,lastVerified=p.lastVerified,rttMS=p.rttMS,testACK=p.lastTestACK}end
  return out
 end
 if ns.AetherLiveGameplay and purpose~='enrollment'and d.purpose~='enrollment'then
  s.QueueControl=enqueue;s.CryptoJob=job;s.Valid=valid;s.SessionPeer=peer
  s.QueueCredential=function(text,p)
   if not p or text:sub(1,3)~='C2|'or not s.enabled then return false end
   return enqueue(text,p,'WHISPER',nil,true)
  end
  s.AdvertiseApplications=function(self,p)return signed(p,'FEATURES',token('features'),'sync108',false)end
  ns.AetherLiveGameplay.Attach(s,d,fixture)
 end
 if d.purpose=='enrollment'or purpose=='enrollment'then s.QueueControl=enqueue;s.CryptoJob=job;s.Valid=valid;s.SessionPeer=peer end
 if L.Session and d.liveSession then L.Session.Attach(s,d)end
 return s
end
function L.Runtime()if not L.runtime then L.runtime=L.New()end;return L.runtime end
function L.Active()return L.runtime and L.runtime.enabled==true end
function L.HasWork()return L.pending~=nil or L.Active()or L.runtime and L.runtime.departures and #L.runtime.departures>0 end
function L.Queued()return L.runtime and(#L.runtime.queue>0 or L.runtime.GameQueued and L.runtime:GameQueued())end
function L.ControlQueued()return L.runtime and #L.runtime.queue>0 end
function L.Pump()if L.runtime then L.runtime:FlushDepartures();L.runtime:Pump();if ns.AetherUnified then ns.AetherUnified.Pump(L.runtime)end;if L.runtime.GamePump then L.runtime:GamePump()end end;if L.WorldPump then L.WorldPump()end end
function L.Event(kind,...)
 if not L.runtime then return end
 if L.Session then L.Session.Event(kind,...)end
 if kind=='CHAT_MSG_ADDON'or kind=='CHAT_MSG_ADDON_LOGGED'then
  local prefix=...;if prefix==L.PREFIX then local s=L.runtime;local key=kind=='CHAT_MSG_ADDON'and'ordinaryEvents'or'loggedEvents';s[key]=(s[key]or 0)+1;s.lastReceiveAt=clock()end
 end
 if kind=='CHAT_MSG_ADDON'then return L.runtime:Ingress(...)end
 if kind=='CHAT_MSG_ADDON_LOGGED'then local prefix,text,channel,sender=...;if type(text)=='string'and text:sub(1,3)=='P2|'then return L.runtime:Ingress(prefix,text,channel,sender,true)end end
 if kind=='PLAYER_LOGOUT'then L.runtime:Leave('Logout')
 elseif kind=='PLAYER_ENTERING_WORLD'and L.runtime.enabled then L.runtime.nextPresence=clock()+3
 elseif kind=='GUILD_ROSTER_UPDATE'and L.runtime.enabled then L.runtime.nextRoster=0 end
end
