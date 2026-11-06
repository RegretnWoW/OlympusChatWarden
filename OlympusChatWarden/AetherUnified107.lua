-- Live transports the existing public ledger; this module owns no record copy.
-- The original ledger validators, signatures, provenance and saved format remain.
local _,ns=...
local U={VERSION=1,status='Offline',metrics={received=0,rejected=0,slices=0,maxSliceMS=0,reconciled=0}};ns.AetherUnified=U
local N,A,L,C,G=ns.AetherNet,ns.AetherNative,ns.AetherLive,ns.AetherCertificates,ns.AetherLiveGameplay
local function now()return ns.SafeNumber(ns.SafeCall(GetTime))or 0 end
local function stamp()return ns.SafeNumber(ns.SafeCall(GetServerTime))or 0 end
local function cpu()return ns.WardenPerformance.Now()or now()*1000 end
function U.Available()return ns.ClientBuild.aetherUnified==true end
function U.Active()return U.Available()and L.Active()and not ns.Permissions.Denied('network')and not ns.MainStorageBlocked end
local function address(name)
 local id=L.Name(name);if not id then return end
 return'Live/'..ns.PackCrypto.Hex(ns.PackCrypto.SHA256(C.Namespace()..'/'..id)):sub(1,40)
end
function U.Freshness(t,key)
 if not U.Active()or not N.Subject(t,key)then return end
 local c=N.Cached();local a=c and c.nativeController;if not a or not a.unified then return end
 a.fresh=a.fresh or{};a.freshAt=a.freshAt or{}
 local id=t..'/'..key;if now()<(a.freshAt[id]or 0)then return end
 local count=0;for _ in pairs(a.fresh)do count=count+1 end;if count>=8 then return end
 a.freshAt[id]=now()+30;a.fresh[id]={t=t,key=key}
 -- Keep this view cache bounded too; it never stores record bodies.
 local n=0;for k,at in pairs(a.freshAt)do if at<now()then a.freshAt[k]=nil else n=n+1 end end
 if n>64 then a.freshAt={[id]=now()+30}end
end
local function checkpoint()
 local thread=coroutine.running()
 if thread and U.task and thread==U.task.thread then
  U.task.units=U.task.units+1
  if U.task.units>=24 or cpu()>=U.task.deadline then coroutine.yield()end
 end
end
function U.Bind(c,a,options,receiving)
 if not U.Available()then return end
 a.unified=true;a.work={};a.syncAt={}
 -- Session routing is separate from signed record authorship. This address
 -- is never saved as an author or substituted into an original record.
 options.envelopePrincipal=assert(address(a.identity.name))
 options.packetTTL=240;options.queryTimeout=240
 options.checkpoint=checkpoint
 options.control=function()return false,'LEGACY_ENROLLMENT_CHANNEL_RETIRED'end
 -- Receiving public originals is independent of permission to publish locally.
 local publish=c.Publish
 c.Publish=function(self,...)
  if not N.Preference()then return nil,'Choose community sharing before publishing. Your draft is kept.'end
  return publish(self,...)
 end
 options.send=function(principal,wire)
  local live=L.runtime;if not U.Active()or not live or type(wire)~='string'or #wire>10000 then return false end
  for _,p in pairs(a.peers)do if p.principal==principal and p.ready and p.expires>stamp()then
   return live:QueueApplication(p.live,'records',wire)
  end end
  return false
 end
 a.Start=function(self,explicit)
  if explicit~=true or ns.MainStorageBlocked or ns.Permissions.Denied('network')or not(U.Active()or N.Preference())then return false,'Join Aether Live to connect. Saved pages and drafts remain available.'end
  if c.recovery and c.recovery.state~='READY'then self.status='RECOVERING';return true end
  local ok,why=c:Join(N.CONSENT,true);if not ok then return false,why end
  local cert=C.LocalCertificate(c);if cert and cert.principal==self.principal then self.certified[self.principal]=cert end
  self.enabled=true;self.registered=U.Active();self.status=U.Active()and'LIVE_SHARED_RECORDS'or'OFFLINE_PUBLIC_CACHE';return true
 end
 a.OpenLedger=a.Start
 a.Approve=function()return false,'Aether Live finds your community connections automatically.'end
 a.Ingress=function()return false,'LEGACY_TRANSPORT_RETIRED'end
 a.Pump=function()end -- Shared work is scheduled once through Live, never here.
 a.Stop=function(self)
  self.enabled=false;self.registered=false;self.peers={};self.routes={};self.work={};self.syncAt={};self.status='OFFLINE_PUBLIC_CACHE'
  if U.task and U.task.owner==self then ns.PackCrypto.RecoveryBudget(U.task.thread,nil);ns.AetherCrypto.RecoveryBudget(U.task.thread,nil);U.task=nil end
  if A.Wake then A.Wake()end
  return true
 end
 a.ReceiveLive=function(self,p,wire)
  if not U.Active()or not self.enabled or not p or #self.work>=4 then return false end
  local known=self.peers[p.id];if not known or known.live~=p or known.session~=p.session then return false end
  self.work[#self.work+1]={peer=p,wire=wire,session=p.session,expires=now()+90};return true
 end
 a.BeginReceive=function(self,p)receiving(p)end
 a.EndReceive=function()receiving(nil)end
end
function U.Restore()
 if not U.Available()or N.Current or ns.MainStorageBlocked then return end
 local stored=ns.Storage.OlympusWardenExchangeDB
 if not(stored and stored.netClients)then return end
 local c,why=N.NewProduction({explicit=true,routes={}});if not c then U.lastError=why;return end
 local ok,reason=N.Bind(c,c.nativeController.owner);if not ok then U.lastError=reason;return end
 N.Current=c
end
function U.Attach(s)
 if not U.Available()then return end
 if ns.AetherServices then ns.AetherServices.AttachEnrollment(s)end
end
local function startTask(a,run,peer)
 U.task={owner=a,peer=peer,thread=coroutine.create(run)}
end
local function step()
 local task=U.task;if not task then return end
 if not U.Active()or not task.owner.enabled or task.peer and(task.peer.live.status~='CONNECTED'or task.peer.live.session~=task.peer.session)then U.task=nil;return end
 local start=cpu();task.deadline=start+1.5;task.units=0
 ns.PackCrypto.RecoveryBudget(task.thread,task.deadline);ns.AetherCrypto.RecoveryBudget(task.thread,task.deadline)
 task.owner:BeginReceive(task.peer)
 local ok,accepted,why=coroutine.resume(task.thread)
 task.owner:EndReceive();ns.PackCrypto.RecoveryBudget(task.thread,nil);ns.AetherCrypto.RecoveryBudget(task.thread,nil)
 U.metrics.slices=U.metrics.slices+1;U.metrics.maxSliceMS=math.max(U.metrics.maxSliceMS,cpu()-start)
 if not ok then U.lastError=tostring(accepted):sub(1,160);U.metrics.rejected=U.metrics.rejected+1;U.task=nil
 elseif coroutine.status(task.thread)=='dead'then
  if accepted==false then U.lastError=why;U.metrics.rejected=U.metrics.rejected+1 end
  U.task=nil
 end
end
function U.Pump(s)
 if not U.Available()then return end
 if not U.Active()then
  local a=N.Current and N.Current.nativeController;if a and a.unified and a.enabled then N.Current:Leave()end
  U.task=nil;U.status='Offline';return
 end
 if not s or not s.Valid()then return end
 if not(C_ChatInfo and type(C_ChatInfo.SendAddonMessageLogged)=='function')then U.status='Community connection unavailable on this client';return end
 local c,why=A.EnsureLocal();if not c then U.lastError=why;return end
 local a=c.nativeController
 if c.recovery and c.recovery.state~='READY'then U.status='Loading saved community pages';return end
 if not a.enabled then a:Start(true)end
 if not a.enabled then return end
 U.Attach(s)
 if s.enrollmentScope and #s.queue<4 then s.enrollmentScope:Pump()end
 if now()>=(a.peerAt or 0)then
  a.peerAt=now()+1;local active={}
  for id,p in pairs(s.peers)do
   if p.status=='CONNECTED'and p.applicationVersion==G.APPLICATION_PROTOCOL and p.applicationSession==p.session and(p.expires or 0)>now()then
    local known=s.context.liveCredentials and s.context.liveCredentials[id]
    if(not known or(known.notAfter or 0)<stamp()+180)and now()>=(p.communityCredentialAt or 0)then p.communityCredentialAt=now()+45;s:RequestCredential(p)end
    -- A later durable certificate can arrive without replacing a working
    -- temporary Live connection. Never derive durable authorship from E2.
    local cert=s.context.liveCredentials and s.context.liveCredentials[id]or p.cert
    local principal=address(p.name)
    if principal then
     active[id]=true
     local peer=a.peers[id]
     if not peer or peer.session~=p.session or peer.principal~=principal then peer={principal=principal,name=p.name,session=p.session,ready=true,live=p,postsVersion=1,artVersion=3};a.peers[id]=peer;a.syncAt[id]=nil end
     peer.expires=stamp()+15;a.routes[id]={inventory=true}
     if cert and cert.scopes.community and not cert.liveOnly and cert.public==p.cert.public and not C.IsRevoked(c,cert)then
      peer.certificate=cert;a.certified[cert.principal]=cert
      if cert.guid then a.bindings[cert.guid]={principal=principal,session=p.session,name=p.name,at=stamp()}end
     else peer.certificate=nil end
    end
   end
  end
  for id in pairs(a.peers)do if not active[id]then a.peers[id]=nil;a.routes[id]=nil;a.syncAt[id]=nil end end
 end
 U.status=next(a.peers)and'Synchronizing community pages'or'Waiting for company'
 if a.sharedRevision~=c.revision then a.sharedRevision=c.revision;a.syncAt={}end
 -- Control and movement always get the first opportunity at the shared budget.
 if #s.queue>0 or #s.jobs>0 or #s.gameOrder>0 or A.Restricted()then return end
 if U.task then step();return end
 local work=table.remove(a.work,1)
 if work and work.expires>now()and work.peer.status=='CONNECTED'and work.peer.session==work.session then
  local peer;for _,p in pairs(a.peers)do if p.live==work.peer then peer=p;break end end
  if peer then startTask(a,function()local ok,err=c:Receive(peer.principal,work.wire);if ok then U.metrics.received=U.metrics.received+1;U.lastError=nil end;return ok,err end,peer);step();return end
 end
 if now()<(a.pumpAt or 0)then return end;a.pumpAt=now()+2
 startTask(a,function()
  C.AdoptIssued(c);C.UpgradePending(c)
  local id,fresh=next(a.fresh or{})
  if fresh then a.fresh[id]=nil;c:Refresh(fresh.t,fresh.key)end
  for id,p in pairs(a.peers)do
   if p.announcedRevision~=c.revision and not s.applicationOut[id]then
    local digest=c:Inventory(p.principal).digest
    if s:QueueApplication(p.live,'inventory',digest)then p.announcedRevision=c.revision end
   end
   if not s.applicationOut[id]and not(c.inventories or{})[p.principal]and(not a.syncAt[id]or now()>=a.syncAt[id])then
    if c:Reconcile(p.principal)then a.syncAt[id]=now()+120;U.metrics.reconciled=U.metrics.reconciled+1 end
    break
   end
  end
  c:Pump();return true
 end);step()
end
assert(G.RegisterApplication('records',{maxBytes=10000,receive=function(s,p,wire)
 local c=N.Cached();local a=c and c.nativeController
 return a and a.unified and a:ReceiveLive(p,wire)or false
end}))
assert(G.RegisterApplication('inventory',{maxBytes=64,receive=function(s,p,digest)
 if #digest~=64 or digest:find('[^a-f0-9]')then return false end
 local c=N.Cached();local a=c and c.nativeController;local peer=a and a.unified and a.peers[p.id]
 if peer and digest~=peer.advertisedDigest and now()>=(peer.nextInventoryHint or 0)then
  peer.advertisedDigest=digest;peer.nextInventoryHint=now()+15;a.syncAt[p.id]=0
 end
 return true
end}))
