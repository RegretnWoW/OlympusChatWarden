-- Two independently chosen services over the existing identity/key foundation.
-- Enrollment transport accepts ONLY the existing certificate ceremony. It has
-- no record ledger, publication, inventory, history or avatar packet handler.
local _,ns=...
local L,C,E,B,A=ns.AetherLive,ns.AetherCertificates,ns.AetherCertificates.Enrollment,ns.ChronicleBackup,ns.AetherNative
local S={VERSION=1,PREFIX='OWAEnroll1',prompts={}};ns.AetherServices=S
local function now()return ns.SafeNumber(ns.SafeCall(GetTime))or 0 end
local function stamp()return ns.SafeNumber(ns.SafeCall(GetServerTime))or 0 end
local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
local function plain(v)return ns.Readable(v)and type(v)=='table'and not getmetatable(v)end
local function storage(create)
 if not ns.DB then return nil,'SETTINGS_UNAVAILABLE'end
 local r=ns.DB.aetherServices94
 if r~=nil and(not plain(r)or r.version~=1 or not plain(r.owners))then return nil,'SERVICE_SETTINGS_NEED_RECOVERY'end
 local owner=ns.Permissions.Owner();if not owner then return nil,'NATIVE_OWNER_REQUIRED'end
 if create and ns.MainStorageBlocked then return nil,'SAVED_DATA_PROTECTED'end
 if r==nil and create then r={version=1,owners={}};ns.DB.aetherServices94=r end
 local row=r and r.owners[owner]
 if row~=nil and(not plain(row)or row.live~=nil and type(row.live)~='boolean'or row.relay~=nil and type(row.relay)~='boolean')then return nil,'SERVICE_SETTINGS_NEED_RECOVERY'end
 if row==nil and create then if count(r.owners)>=64 then return nil,'SERVICE_OWNER_BOUND'end;row={};r.owners[owner]=row end
 return row
end
function S.Desired(service)local row=storage(false);return row and row[service]==true or false end
function S.SetDesired(service,value)
 if(service~='live'and service~='relay')or type(value)~='boolean'then return false,'INVALID_SERVICE'end
 local row,why=storage(true);if not row then return false,why end
 row[service]=value;S.nextCheck=0;A.Wake();return true
end
function S.EnrollmentAuthorized()
 if ns.AetherUnified and ns.AetherUnified.Available()then return ns.AetherUnified.Active()end
 if A.RelayPaused()then return false end
 return not ns.MainStorageBlocked and not ns.Permissions.Denied('network')and(S.Desired('relay')or ns.AetherNet.Preference())or false
end
local function credential()return C.LocalCertificate(ns.AetherNet.Cached())end
function S.RelayStatus()
 if ns.AetherUnified and ns.AetherUnified.Available()then return L.Active()and'CONNECTED'or'OFF','Aether Live connects your community pages. What you publish stays your choice.'end
 if A.RelayPaused()then return'PAUSED',A.RelayPauseMessage end
 local _,settingsError=storage(false);if settingsError then return'ERROR','Enrollment settings need attention; existing data is kept.'end
 local cert=credential();if cert then return'ENROLLED','Enrolled · sharing stays your choice'end
 if S.error then return'ERROR','Setup could not finish · Retry'end
 if S.EnrollmentAuthorized()then
  local e=S.runtime and S.runtime.enrollmentScope;local offers=e and e.native.enrollment and e.native.enrollment.offers
  if offers and next(offers)then return'PENDING','Pending · host found; waiting for character verification'end
  return'PENDING','Pending · looking for an enrollment host'
 end
 return'OFF','Prepare your identity for Aether Relay. Record sharing stays off.'
end
local codes={ENROLLMENT_OFFER='O',ENROLLMENT_REQUEST='Q',ENROLLMENT_CHALLENGE='C',ENROLLMENT_RESPONSE='R',ENROLLMENT_ISSUED='I'}
local kinds={O='ENROLLMENT_OFFER',Q='ENROLLMENT_REQUEST',C='ENROLLMENT_CHALLENGE',R='ENROLLMENT_RESPONSE',I='ENROLLMENT_ISSUED'}
function S.AttachEnrollment(s)
 if s.enrollmentScope then return s.enrollmentScope end
 local layerNames=C.Namespace()=='forever'
 local function principal(name)local _,_,base,realm=A.NativeName(name);return C.Principal(base,layerNames and'forever'or realm)end
 local state={out={},incoming={},completed={},serial=0,metrics={sent=0,received=0,rejected=0,retries=0},native={peers={},layerNames=layerNames}};s.enrollmentScope=state
 local client={enrollmentOnly=true,layerNames=layerNames}
 function client:Joined()return s.enabled and S.EnrollmentAuthorized()end
 function client:Send(principal,kind,body)
  if not self:Joined()or not codes[kind]then return false,'ENROLLMENT_ONLY_SCOPE'end
  local peer
  -- Principal is derived from the server-attributed full name, never a field
  -- in the received certificate request.
  for _,p in pairs(s.peers)do local _,_,base,realm=A.NativeName(p.name)
   if p.status=='CONNECTED'and p.cert and C.Principal(base,layerNames and'forever'or realm)==principal then peer=p;break end
  end
  if not peer then return false,'ENROLLMENT_PEER_UNREACHABLE'end
  local key=peer.id..'/'..kind;if state.out[key]then return false,'ENROLLMENT_ALREADY_QUEUED'end
  if count(state.out)>=8 then return false,'ENROLLMENT_QUEUE_FULL'end
  local raw=B.Encode({body});if type(raw)~='string'or #raw>10000 then return false,'ENROLLMENT_PACKET_BOUND'end
  local wire=C.Encode(raw);local total=math.ceil(#wire/180);if total>80 then return false,'ENROLLMENT_PACKET_BOUND'end
  state.serial=state.serial+1;if state.serial>9999999 then return false,'ENROLLMENT_SESSION_EXHAUSTED'end
  state.out[key]={peer=peer,kind=codes[kind],wire=wire,seq=state.serial,total=total,next=1,attempts=0,expires=now()+180,session=s.session,destination=peer.session}
  return true
 end
 state.client=client
 local function nativePeer(p)
  local row={name=p.name,principal=principal(p.name),public=p.cert.public,guid=p.cert.guid,session=p.session,ready=true,expires=stamp()+p.expires-now()}
  state.native.peers[p.id]=row;return row
 end
 local function reject()state.metrics.rejected=state.metrics.rejected+1;return true end
 local function ack(p,seq)
  if #s.queue<8 then s.QueueControl('R4|A|'..s.session..'|'..p.session..'|'..seq,p,'WHISPER')end
 end
 local gameplay=s.GameIngress
 function s:GameIngress(text,channel,id,...)
  if text:sub(1,3)~='R4|'then return gameplay and gameplay(self,text,channel,id,...)or false end
  local p=self.peers[id]
  if channel~='WHISPER'or not p or p.status~='CONNECTED'or not p.session or not p.cert or(p.expires or 0)<=now()or not client:Joined()then return reject()end
  local source,destination,seq=text:match('^R4|A|([a-f0-9]+)|([a-f0-9]+)|(%d+)$')
  if source then
   seq=tonumber(seq);if source~=p.session or destination~=self.session or not seq or seq<1 or seq>9999999 then return reject()end
   for key,q in pairs(state.out)do if q.peer==p and q.seq==seq then state.out[key]=nil end end;return true
  end
  local kind,index,total,data
  source,destination,seq,kind,index,total,data=text:match('^R4|([a-f0-9]+)|([a-f0-9]+)|(%d+)|([OQCRI])|(%d+)|(%d+)|([%w_%-]+)$')
  seq,index,total=tonumber(seq),tonumber(index),tonumber(total)
  if source~=p.session or destination~=self.session or not seq or seq<1 or seq>9999999 or not kinds[kind]
   or not index or not total or total<1 or total>80 or index<1 or index>total or #data>180 then return reject()end
  local token=id..'/'..source..'/'..seq
  local completed=state.completed[id]
  if not completed or completed.session~=source then completed={session=source,high=0,seen={}};state.completed[id]=completed end
  if seq<=completed.high-128 then return reject()end
  if completed.seen[seq]then ack(p,seq);return true end
  local r=state.incoming[token]
  if not r then if count(state.incoming)>=8 then return reject()end;r={parts={},n=0,total=total,kind=kind,expires=now()+180};state.incoming[token]=r end
  if r.total~=total or r.kind~=kind then return reject()end
  if not r.parts[index]then r.parts[index]=data;r.n=r.n+1 end
  if r.n==total and not r.busy then
   r.busy=true;local session=self.session
   if not self.CryptoJob(function()
    if not self.enabled or session~=self.session or p.session~=source or p.status~='CONNECTED'or not client:Joined()then return end
    local raw=C.Decode(table.concat(r.parts),10000);local decoded=raw and B.DecodeChunk(raw);local body=decoded and decoded[1]
    if not plain(body)then reject();state.incoming[token]=nil;return end
    local peerPrincipal=principal(p.name)
    state.native.session=self.session;client.principal=principal(self.context.me.name);nativePeer(p)
    local allowed,why=E.Handle(state.native,client,peerPrincipal,kinds[kind],body)
    if allowed then state.metrics.received=state.metrics.received+1
    else state.lastError=why;state.metrics.rejected=state.metrics.rejected+1 end
    -- ACK receipt, never authority or certificate validity. Invalid packets
    -- are not dispatched again and do not produce a retry flood.
    completed.high=math.max(completed.high,seq);completed.seen[seq]=true
    for previous in pairs(completed.seen)do if previous<=completed.high-128 then completed.seen[previous]=nil end end
    state.incoming[token]=nil;ack(p,seq)
   end)then r.busy=nil end
  end
  return true
 end
 function state:Pump()
  if not client:Joined()then return end
  local known=ns.AetherNet.Cached();client.records=known and known.records;client.floors=known and known.floors;client.revision=known and known.revision or 0
  self.native.session=s.session;client.principal=principal(s.context.me.name)
  local active={}
  for id,p in pairs(s.peers)do if p.status=='CONNECTED'and p.cert and(p.expires or 0)>now()then
   active[id]=true;nativePeer(p)
  end end
  for id in pairs(self.native.peers)do if not active[id]then self.native.peers[id]=nil end end
  if not A.Restricted()and not self.pumpQueued and now()>=(self.nextPump or 0)and #s.jobs==0 then
   self.nextPump=now()+(ns.AetherUnified and ns.AetherUnified.Available()and 15 or 1);self.pumpQueued=true
   if not s.CryptoJob(function()self.pumpQueued=nil;if client:Joined()then E.Pump(self.native,client)end end)then self.pumpQueued=nil end
  end
  for key,r in pairs(self.incoming)do if r.expires<=now()then self.incoming[key]=nil end end
  for key,q in pairs(self.out)do
   if q.expires<=now()or q.peer.status~='CONNECTED'or q.session~=s.session or q.destination~=q.peer.session then self.out[key]=nil
   elseif q.next>q.total then
    if now()>=(q.retryAt or 0)then
     if q.attempts>=2 then self.lastError='ENROLLMENT_DELIVERY_TIMEOUT';self.out[key]=nil
     else q.next=1;q.attempts=q.attempts+1;self.metrics.retries=self.metrics.retries+1 end
    end
   elseif #s.queue<4 and #s.jobs==0 then
    local data=q.wire:sub((q.next-1)*180+1,q.next*180)
    if s.QueueControl(table.concat({'R4',s.session,q.peer.session,q.seq,q.kind,q.next,q.total,data},'|'),q.peer,'WHISPER')then
     q.next=q.next+1;q.retryAt=now()+40;self.metrics.sent=self.metrics.sent+1
    end;break
   end
  end
 end
 return state
end
function S.EnrollRelay()
 if ns.AetherUnified and ns.AetherUnified.Available()then return L.Join()end
 if A.RelayPaused()then return false,A.RelayPauseMessage end
 if not ns.Permissions.Decide('UIAccess')or ns.MainStorageBlocked then return false,'Your saved data needs attention before enrollment can start.'end
 if not ns.Permissions.Resume('network',true)then return false,'Network participation was not authorized.'end
 local ok,why=S.SetDesired('relay',true);if not ok then return false,why end
 S.error=nil;S.nextCheck=0;S.Pump();return true,'Enrollment started. Historical sharing and publication stay off.'
end
function S.RetryRelay()
 if not S.EnrollmentAuthorized()then return S.EnrollRelay()end
 if S.runtime then S.runtime:Leave('Enrollment retry requested');S.runtime=nil end
 S.error=nil;S.nextCheck=0;S.Pump();return true
end
function S.PauseRelayEnrollment()
 local ok,why=S.SetDesired('relay',false);if not ok then return false,why end
 if S.runtime then S.runtime:Leave('Enrollment paused by owner');S.runtime=nil end
 S.error=nil;return true,ns.AetherNet.Preference()and'Enrollment will continue under your existing Relay sharing choice. Pause that choice separately to stop it.'or'Automatic enrollment is paused. Existing keys, certificates and history are kept.'
end
function S.Pump()
 if ns.AetherUnified and ns.AetherUnified.Available()then
  -- No separate enrollment connection or directory. The existing Live request
  -- can resume independently of whether its window is open.
  if S.runtime then S.runtime:Leave('Enrollment moved to Aether Live');S.runtime=nil end
  if now()>=(S.nextCheck or 0)then
   S.nextCheck=now()+10
   if S.Desired('live')and not(L.WelcomeBusy and L.WelcomeBusy())and L.Session.Authorized()and not L.requested and not L.Active()then L.ResumeRequested()end
  end
  return
 end
 if A.RelayPaused()and S.runtime then S.runtime:Leave('Relay paused for this build');S.runtime=nil end
 local owner=ns.Permissions.Owner();if S.owner~=owner then
  if S.runtime then S.runtime:Leave('Character changed');S.runtime=nil end;S.owner=owner;S.error=nil;S.nextCheck=0
 end
 if S.runtime and S.runtime.enabled then
  S.runtime:Pump();if S.runtime.enabled then S.runtime.enrollmentScope:Pump()end
 end
 if now()>=(S.nextUI or 0)then
  S.nextUI=now()+1;local status,detail=S.RelayStatus();local liveStatus=L.Status and select(2,L.Status())or'OFF';local token=status..'/'..detail..'/'..liveStatus
  if S.uiState~=token then S.uiState=token
   if ns.UI2.window and ns.UI2.window:IsShown()and ns.UI2.route and(ns.UI2.route.page=='home'or ns.UI2.route.page=='settings')then ns.UI2.Refresh(true)end
  end
 end
 if now()<(S.nextCheck or 0)then return end;S.nextCheck=now()+10
 if S.Desired('live')and ns.UI2.window and ns.UI2.window:IsShown()and not(L.WelcomeBusy and L.WelcomeBusy())and L.Session.Authorized()and not L.requested and not L.Active()then L.ResumeRequested()end
 if not S.EnrollmentAuthorized()then if S.runtime then S.runtime:Leave('Enrollment paused')end;return end
 local cert=credential();local host=ns.AetherAutomaticEnrollment.LocalIssuer(ns.AetherNet.Cached(),true)
 if cert and not E.NeedsCertificate(cert)and not host then
  if S.runtime and S.runtime.enabled and not next(S.runtime.enrollmentScope.out)and #S.runtime.queue==0 and #S.runtime.jobs==0 then S.runtime:Leave('Enrollment complete')end
  S.nextCheck=now()+60;return
 end
 if S.runtime and S.runtime.enabled then S.error=nil;return end
 local key,why=ns.AetherAutomaticEnrollment.EnsureKey('enrollment');if not key then S.error=why;return end
 local s=L.New(nil,'enrollment');S.runtime=s;S.AttachEnrollment(s)
 local ok,reason=s:Start(true);S.error=not ok and reason or nil
 if not ok then return end
 -- Public root-signed issuer endpoints are rendezvous hints, never proof of
 -- issuer authority; the existing offer chain and challenge verify authority.
 for _,blob in ipairs(ns.AetherAutomaticIssuerGrants or{})do local d=ns.AetherAutomaticEnrollment.Delegation(blob)
  if d then s:Connect(d.name..'-'..d.realm,'PINNED_ISSUER_ENDPOINT')end
 end
end
function S.HasWork()return not ns.MainStorageBlocked and not ns.Permissions.Denied('network')and(S.Desired('live')or S.EnrollmentAuthorized()or S.runtime and S.runtime.enabled)or false end
function S.Event(kind,...)
 if L.Session then L.Session.Event(kind,...)end
 if kind=='CHAT_MSG_ADDON'and S.runtime then S.runtime:Ingress(...)
 elseif kind=='PLAYER_LOGOUT'then if S.runtime then S.runtime:Leave('Logout')end
 elseif kind=='PLAYER_LOGIN'or kind=='GUILD_ROSTER_UPDATE'then S.nextCheck=0;A.Wake()end
end
function S.Require(service,action)
 if service=='relay'and ns.AetherUnified and ns.AetherUnified.Available()then service='live'end
 if service=='relay'and A.RelayPaused()then return ns.UI2Forms.Feedback(false,A.RelayPauseMessage)end
 local ready=service=='live'and L.Active()or service=='relay'and credential()~=nil
 if ready then return true end
 local key=service..'/'..(action or'feature');if now()<(S.prompts[key]or 0)then return false,'Enrollment is available from Olympus Hall.'end;S.prompts[key]=now()+120
 local pending=service=='live'and(L.pending or S.Desired('live'))or service=='relay'and S.EnrollmentAuthorized()
 local title=pending and'Aether setup is still in progress'or service=='live'and'Aether Live Required'or'Aether Relay Required'
 local help=pending and'Your request is kept. You can keep exploring Fireside while setup continues.'or service=='live'and'This action uses Aether Live to connect with other adventurers. Your offline pages remain available.'or'This action needs an Aether Relay identity. Enrollment keeps sharing and publication as separate choices.'
 ns.UI2Forms.Form({title=title,help=help,fields={},cancelLabel='Not Now',submitLabel=pending and'Retry'or service=='live'and'Join Aether Live'or'Enroll in Aether Relay',submit=function()
  if service=='live'then
   return L.Retry()
  end
  if pending then return S.RetryRelay()end;return S.EnrollRelay()
 end})
 return false,help
end
function S.RequireSharing(action)
 if not credential()then return S.Require('relay',action)end
 if ns.AetherNet.Preference()and not ns.Permissions.Denied('network')then return true end
 local key='sharing/'..(action or'feature');if now()<(S.prompts[key]or 0)then return false end;S.prompts[key]=now()+120
 ns.UI2Forms.Form({title='Choose what you share',help='Your character is enrolled. Community sharing is currently off. Review your sharing choices before publishing community contributions. You can still receive approved shared pages while connected. Your private pages and drafts remain available.',fields={},cancelLabel='Not Now',submitLabel='Review sharing choices',submit=function()ns.UI2.Open({page='settings',category='aether'});return true end})
 return false
end
function S.Diagnostics()
 local state=S.RelayStatus();local r=S.runtime;local issuer=ns.AetherAutomaticEnrollment.IssuerRole()
 return table.concat({'FIRESIDE_AETHER_SETUP_1','Relay identity: '..state,'Historical sharing: '..tostring(ns.AetherNet.Preference()),'Enrollment host: '..issuer,
  'Connection: '..tostring(r and r.status or'OFF'),'Startup result: '..tostring(S.error or'none'),'Enrollment result: '..tostring(r and r.enrollmentScope.lastError or'none'),
  'Native realm delivery: UNVERIFIED','Keys, certificate blobs and private history: excluded'},'\n')
end
