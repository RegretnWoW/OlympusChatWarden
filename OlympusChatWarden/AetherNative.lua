-- Native event senders attribute transport sessions. Original records require
-- character signatures chained to the separately pinned Warden Authority.
-- Outer checksums are framing integrity only; they never authenticate authors.
local _,ns=...
local N,W,B,S=ns.AetherNet,ns.RelayTransport.Aether,ns.ChronicleBackup,ns.ChronicleStore
local C=ns.AetherCertificates
local A={VERSION=3,PROTOCOL='S7',controllers=setmetatable({},{__mode='k'})};ns.AetherNative=A
function A.RelayPaused()return ns.ClientBuild and ns.ClientBuild.aetherRelayPaused==true end
A.RelayPauseMessage='Aether Relay is taking a short break while we improve performance. Your saved records and sharing choices are kept. Aether Live is still available.'
A.DiscoveryLimits={peers=2,candidates=64,cooldowns=128,interval=120,replyWindow=180,advertisements=2}
local function wake() if A.Wake then A.Wake() end end
local function clock() return ns.SafeNumber(ns.SafeCall(GetServerTime)) or ns.SafeNumber(ns.SafeCall(time)) or 0 end
local function elapsed() return ns.SafeNumber(ns.SafeCall(GetTime)) or 0 end
local function hash(v) return ns.PackCrypto.Hex(ns.PackCrypto.SHA256(v)) end
local function count(t) local n=0;for _ in pairs(t or {}) do n=n+1 end;return n end
local function plain(t) return ns.Readable(t) and type(t)=='table' and not getmetatable(t) end
local function name(v)
 if not ns.CanRead(v) or #v>180 or v:find('[|:%c]') then return end
 local normalized=ns.Shield.NormalName(v)
 local base,realm=normalized:match('^([^%-]+)%-(.+)$')
 -- Missing realm and multiple interpretations stay unresolved. Use exact
 -- native UnitName normalisation for Forever, never strip a surname.
 if not base or not realm or realm:find('%-') or base:find('^%s') or base:find('%s$') then return end
 return base:lower()..'-'..realm:gsub('%s',''):lower(),normalized,base,realm
end
local function unit(u)
 local raw=ns.Shield.UnitName(u);if not raw then return end
 if not raw:find('-',1,true) then raw=raw..'-'..tostring(ns.SafeCall(GetRealmName) or '') end
 local id,display,base,realm=name(raw);local guid=ns.SafeCall(UnitGUID,u)
 if id and S.GUID(guid) then return {id=id,name=display,base=base,realm=realm,guid=guid} end
end
local channels={WHISPER=true,PARTY=true,RAID=true,INSTANCE_CHAT=true,GUILD=true}
local function channelAvailable(channel)
 if channel=='WHISPER' then return true end
 if channel=='GUILD' then return ns.Checked(ns.SafeCall(IsInGuild)) end
 if channel=='RAID' then return ns.Checked(ns.SafeCall(IsInRaid)) end
 if channel=='PARTY' then return ns.Checked(ns.SafeCall(IsInGroup)) and not ns.Checked(ns.SafeCall(IsInRaid)) end
 if channel=='INSTANCE_CHAT' then return ns.Checked(ns.SafeCall(IsInGroup,LE_PARTY_CATEGORY_INSTANCE or 2)) end
 return false
end
local function result(api,value,legacy)
 if not ns.Readable(value) then return false,'INACCESSIBLE_API_RESULT' end
 if value==true then return true,'ENQUEUED_UNVERIFIED' end
 local e=Enum and Enum[api]
 if type(value)=='number' then
  if plain(e) then
   if value==e.Success or api=='RegisterAddonMessagePrefixResult' and(value==e.DuplicatePrefix or value==e.AlreadyRegistered)then return true,'ENQUEUED_UNVERIFIED' end
   return false,'API_RESULT_'..value
  end
  -- Legacy number zero is documented success. Unknown nonzero codes fail.
  return value==0,value==0 and 'ENQUEUED_UNVERIFIED' or 'API_RESULT_'..value
 end
 if value==nil and legacy then return true,'LEGACY_RESULT_UNVERIFIED' end
 return false,'API_RESULT_DENIED'
end
local function safeCall(fn,...)
 if type(fn)~='function' then return false,'API_UNAVAILABLE' end
 local ok,v=pcall(fn,...);if not ok then return false,'API_EXCEPTION' end;return true,v
end
local serial=0
local function nonce(owner)
 serial=serial+1
 -- Public session/correlation ID, not entropy and not an authentication key.
 return hash(owner..'/'..clock()..'/'..elapsed()..'/'..serial):sub(1,20)
end
local function chunks(wire)
 local out={};local first=1
 while first<=#wire do
  local last=math.min(first+179,#wire)
  while last>=first and wire:byte(last+1) and wire:byte(last+1)>=128 and wire:byte(last+1)<=191 do last=last-1 end
  if last<first then return end
  out[#out+1]=wire:sub(first,last);first=last+1
 end
 return out
end
local function restricted()
 if ns.Checked(ns.SafeCall(InCombatLockdown)) then return true,'COMBAT_PAUSED' end
 local lockdown=C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
 if type(lockdown)=='function'then
  local ok,v=safeCall(lockdown)
  if not ok or not ns.Readable(v)or type(v)~='boolean'then return true,'CHAT_LOCKDOWN_UNREADABLE'end
  if v then return true,'CHAT_LOCKDOWN'end
 end
 -- Forever 1.60 reports the realm-wide outgoing flag as true even where
 -- native addon sends work. Its actual messaging lockdown and send results
 -- decide availability. Keep the older flag as diagnostics, never as a
 -- permanent pause on this client. Retail retains the conservative flag gate.
 if ns.ClientCompat and ns.ClientCompat.client=='forever'then return false end
 local f=C_ChatInfo and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted
 if f then local ok,v=safeCall(f);if not ok or not ns.Readable(v) or v==true then return true,'NATIVE_RESTRICTED' end end
 return false
end
local prefixes={}
function A.EnsurePrefix(prefix)
 if type(prefix)~='string'or #prefix<1 or #prefix>16 or prefix:find('[%c]')then return false,'INVALID_PREFIX'end
 if prefixes[prefix]then return true,'PREFIX_ALREADY_REGISTERED'end
 local probe=C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered or IsAddonMessagePrefixRegistered
 if type(probe)=='function'then local ok,v=safeCall(probe,prefix);if ok and ns.Readable(v)and v==true then prefixes[prefix]=true;return true,'PREFIX_ALREADY_REGISTERED'end end
 local f=C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
 local ok,v=safeCall(f,prefix);if not ok then return false,v end
 local accepted,why=result('RegisterAddonMessagePrefixResult',v,C_ChatInfo==nil)
 -- The documented zero/one results are stable across Forever/legacy clients
 -- even when the enumeration table is not exposed. Other failures stay closed.
 if not accepted and ns.Readable(v)and v==1 then accepted=true;why='PREFIX_ALREADY_REGISTERED'end
 if accepted then prefixes[prefix]=true end;return accepted,why
end
local function register()return A.EnsurePrefix(W.PREFIX)end
function A.TakeBudget(bytes,service)
 service=service or'relay'
 local at=elapsed();local b=A.byteBudget or {at=at,bytes=768,messages=2};A.byteBudget=b
 local dt=math.max(0,at-b.at);b.at=at;b.bytes=math.min(768,b.bytes+dt*480);b.messages=math.min(2,b.messages+dt*2)
 local live=ns.AetherLive and ns.AetherLive.Queued()
 if live then
  local isLive=service=='live'or service=='live-game'or service=='live-records'
  if service=='live-records'and(ns.AetherLive.ControlQueued()or ns.AetherLive.runtime and #ns.AetherLive.runtime.gameOrder>0)then return false end
  if service=='live-game'and ns.AetherLive.ControlQueued()then return false end
  if isLive and(b.liveStreak or 0)>=3 then
   for a in pairs(A.controllers)do if a.enabled and #a.queue>0 then return false end end
  elseif not isLive and(b.liveStreak or 0)<3 then return false end
 end
 if b.bytes<bytes or b.messages<1 then return false end
 b.bytes=b.bytes-bytes;b.messages=b.messages-1;b.liveStreak=(service=='live'or service=='live-game'or service=='live-records')and(b.liveStreak or 0)+1 or 0
 A.traffic=A.traffic or{};local t=A.traffic[service]or{messages=0,bytes=0};A.traffic[service]=t;t.messages=t.messages+1;t.bytes=t.bytes+bytes
 return true
end
function A.TransportCapabilities()
 local logged=type(C_ChatInfo and C_ChatInfo.SendAddonMessageLogged)=='function'
 local ordinary=type(C_ChatInfo and C_ChatInfo.SendAddonMessage)=='function'or type(SendAddonMessage)=='function'
 local registration=type(C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix)=='function'
 return {available=logged and registration,loggedAvailable=logged,sendAvailable=ordinary,registerAvailable=registration,
  reason=not logged and'LOGGED_API_UNAVAILABLE'or not registration and'PREFIX_API_UNAVAILABLE'or'API_AVAILABLE'}
end
-- Read only, on-demand diagnostics. Never includes packet bodies or credentials.
function A.ConnectionDiagnostics()
 local cap=A.TransportCapabilities();local paused,reason=restricted()
 local f=C_ChatInfo and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted
 local restriction='API_ABSENT'
 if type(f)=='function'then local ok,v=safeCall(f);restriction=not ok and'API_ERROR'or not ns.Readable(v)and'UNREADABLE'or v==true and'TRUE'or v==false and'FALSE'or'UNEXPECTED_RESULT'end
 cap.paused=paused;cap.pauseReason=reason or'NONE';cap.outgoingRestricted=restriction
 local lockdown=C_ChatInfo and C_ChatInfo.InChatMessagingLockdown;cap.chatLockdown='API_ABSENT'
 if type(lockdown)=='function'then local ok,v=safeCall(lockdown);cap.chatLockdown=not ok and'API_ERROR'or not ns.Readable(v)and'UNREADABLE'or v==true and'TRUE'or v==false and'FALSE'or'UNEXPECTED_RESULT'end
 cap.restrictionPolicy=ns.ClientCompat and ns.ClientCompat.client=='forever'and'FOREVER_LOCKDOWN_AND_SEND_RESULT'or'REALM_FLAG_AND_LOCKDOWN'
 cap.combat=ns.Checked(ns.SafeCall(InCombatLockdown));cap.workerAttached=A.frame and A.frame:GetScript('OnUpdate')~=nil or false
 cap.pumpCalls=A.pumpCalls or 0;cap.lastPumpAge=A.lastPumpAt and math.max(0,elapsed()-A.lastPumpAt)or nil
 return cap
end
function A.Capabilities(controller)
 local c=controller and controller.client or N.Current;local material=C.LocalMaterial();local cert=C.LocalCertificate(c)
 local transport=A.TransportCapabilities();local send=transport.available
 local connected=0;local native=controller or c and c.nativeController
 if native and native.enabled and N.Preference()then for _,p in pairs(native.peers)do if p.ready and p.expires>clock()then connected=connected+1 end end end
 local readiness='LOCAL_ONLY'
 if N.Preference()then if not material or not cert then readiness='UNENROLLED'else readiness=send and'RELAY_CAPABLE'or'AUTHENTICATED'end end
 return {state='NATIVE_UNVERIFIED',mode='AUTOMATIC_SELECTIVE_SESSION_PEERS',prefix=W.PREFIX,
  readiness=readiness,implemented=true,eligible=N.Preference()and material~=nil and cert~=nil and send,transportAPIAvailable=transport.available,adapterInitialized=native~=nil and native.registered==true,recovery=native and native.client and native.client.RecoveryStatus and native.client:RecoveryStatus()or nil,currentlyConnected=connected>0,connectedPeers=connected,framesHandedToNativeAPI=native and native.metrics.sent or 0,peerAcknowledgments=native and native.metrics.acked or 0,durableAcceptanceSupported=false,delivery='UNVERIFIED; REACHABILITY_LIMITED',codePathAvailable=true,nativeVerified=false,localPublication=true,
  registerAvailable=transport.registerAvailable,sendAvailable=transport.sendAvailable,loggedAvailable=transport.loggedAvailable,
  trustTier='NATIVE_SESSION_ATTRIBUTED',durableSignatures=true,remoteGM=false,globalDiscovery=false,
  nativeDeliveryVerified=false,olympusRequired=false,maximumPeers=20,maximumFrameBytes=255,
  automaticDiscovery=true,proximityCandidate=ns.ClientCompat.client=='forever',inventoryVersion=1,nativeMultiHop=false,multiHopCodePath=true,
  enrollmentAuthority='Fireside Authority',nativeEnrollmentVerified=false,eventFeedback='UNSUPPORTED_SHARED_RUN_PROOF',ownerProfiles='CERTIFICATE_OR_FIRST_PARTY_NATIVE_BINDING',latestCaptures='SOURCE_QUALIFIED_OBSERVER_REPORTS',
  reason='Origin certificates and signatures support forwarding independently of the author or issuer being online. Real-client enrollment/sender-to-GUID tests remain NOT TESTED. Unenrolled records remain pending and are not circulated as authenticated.'}
end
local function create(build,config)
 if not plain(config) or config.explicit~=true then return nil,'EXPLICIT_NATIVE_SESSION_REQUIRED' end
 local me=unit('player');if not me or not ns.Permissions.Owner() or ns.MainStorageBlocked then return nil,'LOCAL_NATIVE_OWNER_UNAVAILABLE' end
 local own=ns.SafeCall(UnitGUID,'player');if not S.GUID(own) then return nil,'LOCAL_NATIVE_OWNER_UNAVAILABLE' end
 local a={owner=own,identity=me,principal='Native/'..hash(me.id):sub(1,40),session=nonce(me.id),peers={},routes={},queue={},incoming={},seen={},retry={},sequence=0,
  enabled=false,registered=false,status='CONSENT_OFF',lastSend=-100,metrics={sent=0,received=0,rejected=0,acked=0,dropped=0},authored={},cacheOrigins={},cacheProof={},bindings={},certified={},verifiedWires={},issuerWires={},
  shareIdentity=config.shareIdentity==true,sharePresence=config.sharePresence==true,automatic=true,candidates={},discoveryCaps={},cooldowns={},discoverySequence=0}
 a.cacheOrigins[a.principal]={name=me.name};a.originsRevision=1
 local function origin(principal,display)
  if not a.cacheOrigins[principal]or a.cacheOrigins[principal].name~=display then a.cacheOrigins[principal]={name=display};a.originsRevision=(a.originsRevision or 0)+1 end
 end
 local receiving,restoring,restoreGUID
 local function permission() return a.enabled and N.Preference() and not ns.Permissions.Denied('network') and ns.Permissions.Owner()==me.realm..'/'..own end
 -- Prefer the canonical owner token: realm formatting can differ in API
 -- presentation but the verified local GUID and exact startup owner must hold.
 local localOwner=ns.Permissions.Owner()
 permission=function() return a.enabled and(N.Preference()or ns.AetherUnified and ns.AetherUnified.Active()) and not ns.Permissions.Denied('network') and ns.Permissions.Owner()==localOwner end
 local function author(principal)
  if principal=='Issuer/'..C.AUTHORITY then return {verified=true,eligible=true,principal=principal,name=C.LABEL,trustTier='PINNED_AUTHORITY'}end
  local cert=a.certified[principal];if cert then return {verified=true,eligible=true,principal=principal,name=cert.name..'-'..cert.realm,trustTier='CERTIFICATE_HISTORICAL_OR_CURRENT'}end
  if principal==a.principal then return {verified=true,eligible=true,principal=principal,name=me.name,trustTier='LOCAL_FIRSTHAND'} end
  for _,p in pairs(a.peers) do if p.principal==principal and p.ready and p.expires>clock() then return {verified=true,eligible=true,principal=principal,name=p.name,trustTier='NATIVE_SESSION_ATTRIBUTED'} end end
  local cached=a.cacheOrigins[principal];if cached then return {verified=true,eligible=true,principal=principal,name=cached.name,trustTier='LOCAL_UNVERIFIED_CACHE'} end
 end
 local function binding(principal)
  if principal==a.principal then return me end
  for _,u in ipairs({'party1','party2','party3','party4','raid1','raid2','raid3','raid4','raid5','raid6','raid7','raid8','raid9','raid10','raid11','raid12','raid13','raid14','raid15','raid16','raid17','raid18','raid19','raid20','raid21','raid22','raid23','raid24','raid25','raid26','raid27','raid28','raid29','raid30','raid31','raid32','raid33','raid34','raid35','raid36','raid37','raid38','raid39','raid40'}) do
   local p=unit(u);if p and 'Native/'..hash(p.id):sub(1,40)==principal then return p end
  end
 end
 local function confirmed(p)
  if not p.postsOffered and a.routes[name(p.name)]then p.postsOffered=true;a:Enqueue(name(p.name),'S7|P|'..a.session..'|1')end
  if ns.WardenComposition and not p.artOffered and a.routes[name(p.name)]then
   p.artOffered=a:Enqueue(name(p.name),'S7|J|'..a.session..'|3')==true
   if p.artOffered then a:Enqueue(name(p.name),'S7|J|'..a.session..'|2')end -- older installed catalogues
  end
  local b=binding(p.principal)
  if b and (a.bindings[b.guid] or count(a.bindings)<64) then
   a.bindings[b.guid]={principal=p.principal,session=p.session,name=b.name,at=clock()}
  end
 end
 function a:WardenReachability(guid)
  local known=self.bindings[guid];if not known then return {status='UNKNOWN',label='Unknown'} end
  if permission() then for _,p in pairs(self.peers) do
   if p.principal==known.principal and p.session==known.session and p.ready and p.expires>clock() and known.at<=clock() and clock()-known.at<90 then
    return {status='ONLINE',label='Fireside Online',at=known.at,expiresAt=math.min(p.expires,known.at+90)}
   end
  end end
  return {status='LAST_SEEN',label='Fireside User · Last Seen',at=known.at}
 end
 local function checksum(wire)return 'integrity-'..hash(wire)end
 local c
 local function proofKey(wire,sig)return hash(wire..sig)end
 local function verify(principal,wire,sum)
  if type(sum)~='string'then return false end
  if sum:sub(1,3)=='P1:'then
   local cert=C.VerifyRecord(principal,wire,sum,c,restoring==true)
   if not cert then return false end
   if count(a.verifiedWires)>=4096 then a.verifiedWires={}end
   a.verifiedWires[hash(wire)]=cert;a.certified[principal]=cert;origin(principal,cert.name..'-'..cert.realm);return true
  elseif sum:sub(1,3)=='R1:'then
   local issuer=C.VerifyIssuer(principal,wire,sum);if not issuer then return false end
   if count(a.issuerWires)>=512 then a.issuerWires={}end;a.issuerWires[hash(wire)]=issuer;return true
  end
  if sum~=checksum(wire)then return false end
  local record=(B.DecodeChunk(wire)or{})[1];if receiving and not restoring and record and record.schema==N.SCHEMA then return false end
  if restoring then return a.cacheProof[hash(wire)]==principal end
  return principal==a.principal and not receiving or receiving and receiving.principal==principal and receiving.ready and permission()or false
 end
 local options={sourceClass='native_session_v1',recordTTL=N.TTL,packetTTL=90,queryTimeout=120,reciprocal=true,batch=1,principal=a.principal,session=a.session,clock=clock,
  identity=function(t,k)return N.Subject(t,k)~=nil end,authority=author,
  authorGUID=function(p)local b=a.certified[p]or binding(p);return b and b.guid end,
  owns=function(p,t,g)
   if restoring and restoreGUID and restoreGUID[p]==g then return t=='CHARACTER'end
   local cert=a.certified[p];if cert and cert.scopes.self and cert.guid==g then return t=='CHARACTER'end
   local b=binding(p);return t=='CHARACTER'and b and b.guid==g or false
  end,
  sign=function(wire)
   local row=(B.DecodeChunk(wire)or{})[1]
   if row and row.schema==N.SCHEMA and row.origin==a.principal then return C.SignRecord(wire,c)or checksum(wire)end
   return checksum(wire)
  end,verify=verify,
  recordPolicy=function(r,archived)
   if r.sourceClass~='native_session_v1'then return false,'NATIVE_SOURCE_CLASS'end
   local encoded=B.Encode({r});local cert=a.verifiedWires[hash(encoded)]
   if r.origin=='Issuer/'..C.AUTHORITY then
    local issuer=a.issuerWires[hash(encoded)]
    return C.RootRecordPolicy(r,issuer,archived)and true or false,'AUTHORITY_RECORD_POLICY'
   end
   local allowed={POST=true,POST_UPVOTE=true,EXTENSION_CARD=true,ACTIVITY_ENVELOPE=true,IDENTITY=true,OWNER=true,HIDE=true,BLOCK=true,GEAR=true,TALENTS=true,COMMUNITY_WALL=true,WIKI_REPORT=true,PLAYER_VOTE=true,GUILD_VOTE=true,EVENT_FACT=true,PRESENCE=true}
   if archived and(r.kind=='WALL'or r.kind==N.COMMUNITY_KIND)then return true end
   if not allowed[r.kind]then return false,'NATIVE_AUTHORITY_CONTRACT_UNAVAILABLE_FOR_KIND'end
   if receiving and not cert then return false,'AUTHOR_ENROLLMENT_REQUIRED'end
   if ns.AetherPosts.IsKind(r.kind)and r.subjectType~='ROOM'then return false,'ROOM_POST_SCOPE'end
   if r.kind=='ACTIVITY_ENVELOPE'then return false,'SDK_NATIVE_ACTIVITY_NOT_QUALIFIED'end
   if r.kind=='EXTENSION_CARD'then
    local b=cert or binding(r.origin)
    if not b or b.guid~=r.subjectKey or cert and not cert.scopes.self then return false,'EXTENSION_OWNER_CERTIFICATE_REQUIRED'end
    if not r.removed and r.data.extension~='org.olympus.developer-example'then return false,'PUBLIC_SDK_DISABLED'end
   end
   if r.kind=='WIKI_REPORT'and r.subjectType~='WIKI'then return false,'WIKI_REPORT_SCOPE'end
   if r.kind=='IDENTITY'then local b=cert or binding(r.origin)
    if not restoring and(not b or r.subjectKey~=b.guid or r.data.name~=(b.base or b.name)or r.data.realm~=b.realm)then return false,'CERTIFIED_GUID_NAME_BINDING_REQUIRED'end
   end
   if(r.kind=='OWNER'or r.kind=='HIDE'or r.kind=='BLOCK')and not restoring then local b=cert or binding(r.origin)
    if r.subjectType~='CHARACTER'or not b or b.guid~=r.subjectKey or cert and not cert.scopes.self then return false,'CHARACTER_OWNER_SCOPE_REQUIRED'end
   end
   if r.kind=='EVENT_FACT'and(type(r.data.runToken)~='string'or type(r.data.participants)~='table'or r.subjectKey~='Event-'..hash(r.origin..'/'..r.data.runToken):sub(1,40)or #r.data.participants>0 or r.data.outcome=='full_clear')then return false,'SESSION_EVENT_SCOPE'end
   if r.kind=='PRESENCE'and not restoring then local b=cert or binding(r.origin);if not b or b.guid~=r.subjectKey or r.data.place~=''then return false,'CURRENT_SELF_BINDING_REQUIRED'end end
   if not archived and not permission()then return false,'AETHER_WITHDRAWN'end
   return true
  end,
  preferProof=function(old,new)
   local incoming=C.VerifyRecord(a.principal,new.wire,new.signature,c)
   if not incoming then local r=(B.DecodeChunk(new.wire)or{})[1];incoming=r and C.VerifyRecord(r.origin,new.wire,new.signature,c)end
   if not incoming then return false end
   local before=C.VerifyRecord(incoming.principal,old.wire,old.signature,c,true)
   return not before or incoming.epoch>before.epoch or incoming.epoch==before.epoch and incoming.notAfter>before.notAfter
  end,
  recordStatus=function(row)return C.Status(row,c,a.principal)end,
  trustLabel=function()return 'Fireside Authority signatures where marked; pending and historical records remain labelled. Native delivery unverified.'end,
  eventIdentity=function(r)return r.subjectKey=='Event-'..hash(r.origin..'/'..r.data.runToken):sub(1,40)end,
  eventParticipant=function()return false end,eventReviewer=function()return false end,
  presenceProof=function(r)return(restoring or receiving and r.origin==receiving.principal)and r.data.evidence=='successful_craft'or r.origin==a.principal and ns.AthenaPublication.craft and ns.AthenaPublication.craft.owner==localOwner end,
  directory=function()local out={};for _,p in pairs(a.peers)do if p.ready and p.expires>clock()then out[#out+1]=p.principal end end;table.sort(out);return out end,
  inventoryPeer=function(principal)for id,p in pairs(a.peers)do if p.principal==principal and p.ready and p.expires>clock()and a.routes[id]and a.routes[id].inventory then return true end end;return false end,
  roomPeer=function(principal)for _,p in pairs(a.peers)do if p.principal==principal and p.ready and p.postsVersion==1 and p.expires>clock()then return true end end;return false end,
  authorEpoch=function(principal)local cert=a.certified[principal];return cert and cert.epoch or 0 end,
  canRelay=function(row,peer)
   local r=row.record or(B.DecodeChunk(row.pair.wire)or{})[1];if not r then return false end
   if peer and r.data and r.data.composition then
    local supported=false;for _,p in pairs(a.peers)do if p.principal==peer and p.ready and p.expires>clock()and(p.artVersion or 0)>=(r.data.composition.catalog or 1)then supported=true;break end end
    if not supported then return false end
   end
   if r.kind=='WALL'or r.kind==N.COMMUNITY_KIND and not(ns.AetherUnified and ns.AetherUnified.Available())then return false end
   if r.origin=='Issuer/'..C.AUTHORITY then return C.VerifyIssuer(r.origin,row.pair.wire,row.pair.signature)~=nil end
   return C.VerifyRecord(r.origin,row.pair.wire,row.pair.signature,c)~=nil
  end,
  control=function(peer,kind,body)return C.Enrollment.Handle(a,c,peer,kind,body)end,
  resolveEvent=function(st,run)if st.owner~=localOwner then return end;local token=hash(localOwner..'/'..run.anchor):sub(1,40);return {key='Event-'..hash(a.principal..'/'..token):sub(1,40),runToken=token,realm=me.realm,trustTier='LOCAL_OBSERVER_REPORT'}end}
 local restoreContext
 options.recoveryPause=function()restoreContext={active=restoring,guid=restoreGUID};restoring=nil;restoreGUID=nil end
 options.recoveryResume=function()if restoreContext then restoring=restoreContext.active;restoreGUID=restoreContext.guid;restoreContext=nil end end
 options.recoveryComplete=function()if N.Preference()and not ns.Permissions.Denied('network')then a:Start(true)end;if ns.UI2 and ns.UI2.window and ns.UI2.window:IsShown()then ns.UI2.Refresh(true)end end
 local why;c,why=build(options);if not c then return nil,why end;a.client=c;c.nativeController=a;c.displayOwner=own
 function a:Status()local capability=A.Capabilities(self);return {assessment=capability,state=self.status,native='NATIVE_UNVERIFIED',trust='NATIVE_SESSION_ATTRIBUTED',peers=count(self.peers),queued=#self.queue,reach='Automatic P2P forwarding of authority-certified records; enrollment and live delivery require native qualification',metrics=ns.Athena.Copy(self.metrics),discoveryCandidates=count(self.candidates),nativeMultiHop=capability.nativeMultiHop,multiHopCodePath=capability.multiHopCodePath}end
 function a:Approve(target,channel,explicit)
  local id,display=name(target);channel=channel or 'WHISPER'
  if explicit~=true or not id or id==me.id or not channels[channel] then return false,'EXACT_APPROVED_REACHABLE_ROUTE_REQUIRED' end
  if not self.routes[id] and count(self.routes)>=20 then return false,'PEER_LIMIT' end
  self.routes[id]={name=display,channel=channel};return true
 end
 local function rawSend(route,text)
  if not permission() or not a.registered or not channelAvailable(route.channel) or #text>255 then return false,'ROUTE_OR_CONSENT_UNAVAILABLE' end
  local block,reason=restricted();if block then return false,reason end
  -- Aether is background traffic. Yield to existing report/direct transfers;
  -- one shared Aether bucket covers all owner controllers, control and UGC.
  if ns.RelayTransport.Busy and ns.RelayTransport.Busy() or ns.RelayTransport.outgoing and #ns.RelayTransport.outgoing>0 then return false,'COMMUNICATION_YIELD' end
  if not A.TakeBudget(#text) then return false,'COMMUNICATION_YIELD' end
  -- All payloads use the logged API. Native frames contain readable text, not
  -- base64/compressed UGC. Absence is a capability refusal, never a tunnel.
  local f=C_ChatInfo and C_ChatInfo.SendAddonMessageLogged
  local ok,value=safeCall(f,W.PREFIX,text,route.channel,route.channel=='WHISPER' and ns.RelayTransport.WhisperTarget(route.name) or nil)
  if not ok then return false,value end
  return result('SendAddonMessageResult',value,true)
 end
 function a:Jitter(tag,low,high)
  -- Scheduling dispersion is not authentication. Avoid a cryptographic hash
  -- per overheard beacon in a crowded city; the public session already varies
  -- the inexpensive deterministic mixer across clients and reconnects.
  local text=me.id..'/'..self.session..'/'..tag;local v=5381
  for i=1,#text do v=(v*33+text:byte(i))%4294967296 end
  return low+(v/4294967295)*(high-low)
 end
 local function autoCount()
  local n=0;for id,r in pairs(a.routes) do local p=a.peers[id]
   if r.automatic and (p and p.expires>clock() or r.attemptAt and r.attemptAt+30>clock()) then n=n+1 end
  end;return n
 end
 function a:Advertise(channel,id,slots)
  if not permission() or not self.registered or restricted() then return false end
  local f=C_ChatInfo and C_ChatInfo.SendAddonMessage
  if type(f)~='function' then return false end
  if channel=='SAY' and ns.ClientCompat.client~='forever' or channel~='SAY' and not channelAvailable(channel) then return false end
  local text='S7|B|'..self.session..'|'..c:Inventory().digest..'|'..tostring(slots)..'|I1'
  if not A.TakeBudget(#text) then return false end
  local route=id and self.routes[id]
  local ok,v=safeCall(f,W.PREFIX,text,channel,channel=='WHISPER' and route and ns.RelayTransport.WhisperTarget(route.name) or nil)
  local sent,why=ok and result('SendAddonMessageResult',v,true)
  if sent then self.metrics.discoverySent=(self.metrics.discoverySent or 0)+1;self.metrics.bytesSent=(self.metrics.bytesSent or 0)+#text;if route then route.advertisedSession=self.session end end
  return sent,why
 end
 function a:DiscoveryIngress(text,channel,sender)
  if not permission() or not ns.CanRead(text) or #text>120 then return false,'DISCOVERY_POLICY' end
  if channel=='SAY' then if ns.ClientCompat.client~='forever' then return false,'PROXIMITY_UNSUPPORTED' end
  elseif channel~='WHISPER' and not channelAvailable(channel) then return false,'DISCOVERY_CHANNEL' end
  local session,digest,slots=text:match('^S7|B|([a-f0-9]+)|([a-f0-9]+)|([012])|I1$')
  if not session or #session~=20 or #digest~=64 then return false,'DISCOVERY_FIELDS' end
  local id,display=name(sender);if not id or id==me.id then return false,'DISCOVERY_NAME' end
  self.metrics.discoveryReceived=(self.metrics.discoveryReceived or 0)+1
  if self.discoveryCaps[id] or count(self.discoveryCaps)<64 then self.discoveryCaps[id]={session=session,digest=digest,expires=clock()+240} end
  local r=self.routes[id];if r then
   r.inventory=true;r.inventoryDigest=digest
   if channel=='WHISPER' and r.advertisedSession~=self.session then self:Advertise('WHISPER',id,0) end
  end
  if slots=='0' then
   self.candidates[id]=nil;if self.pendingDiscovery and self.pendingDiscovery.id==id then self.pendingDiscovery=nil end
   return true,'DISCOVERY_BUSY'
  end
  -- A beacon is not a credential and never makes the sender Online. Only
  -- a direct logged session handshake can admit its authored records.
  self.nextBeacon=math.max(self.nextBeacon or 0,elapsed()+self:Jitter('passive/'..session,5,20))
  if self.cooldowns[id] and self.cooldowns[id]>clock() or self.peers[id] and self.peers[id].expires>clock() or r and not r.automatic then return true,'DISCOVERY_COOLDOWN' end
  if not self.candidates[id] and count(self.candidates)>=64 then return true,'DISCOVERY_RESERVOIR_FULL' end
  local candidate={id=id,name=display,session=session,digest=digest,expires=clock()+240,at=elapsed()+self:Jitter('reply/'..id..'/'..session,3,A.DiscoveryLimits.replyWindow)}
  self.candidates[id]=candidate
  if not self.pendingDiscovery or candidate.at<self.pendingDiscovery.at then self.pendingDiscovery=candidate end
  return true,'DISCOVERY_DEFERRED'
 end
 function a:DiscoveryPump()
  if not self.registered or restricted() then return end
  for id,p in pairs(self.candidates) do if p.expires<=clock() then self.candidates[id]=nil end end
  for id,p in pairs(self.discoveryCaps) do if p.expires<=clock() then self.discoveryCaps[id]=nil end end
  for id,at in pairs(self.cooldowns) do if at<=clock() then self.cooldowns[id]=nil end end
  for id,r in pairs(self.routes) do if r.automatic and not self.peers[id] and r.attemptAt and r.attemptAt+60<=clock() then self.routes[id]=nil end end
  for id,r in pairs(self.routes) do if r.automatic and r.connectedAt and r.connectedAt+300<=clock() then
   self.routes[id]=nil;self.peers[id]=nil;self.budgets[id]=nil;self.cooldowns[id]=clock()+600
   for key,p in pairs(self.retry) do if p.peer==id then self.retry[key]=nil end end
   self.nextBeacon=math.min(self.nextBeacon or math.huge,elapsed()+self:Jitter('rotate/'..id,15,60))
  end end
  local pending=self.pendingDiscovery
  if pending and pending.expires<=clock() then self.pendingDiscovery=nil;pending=nil end
  if pending and pending.at<=elapsed() and autoCount()<A.DiscoveryLimits.peers and #self.queue<12 then
   self.pendingDiscovery=nil;self.candidates[pending.id]=nil
   if count(self.routes)<20 and count(self.cooldowns)<128 then
    self.routes[pending.id]={name=pending.name,channel='WHISPER',automatic=true,attemptAt=clock(),inventory=true,inventoryDigest=pending.digest}
    self.cooldowns[pending.id]=clock()+300;self:Advertise('WHISPER',pending.id,0);self:Hello(pending.id)
    self.metrics.discoveryAttempts=(self.metrics.discoveryAttempts or 0)+1
   end
  end
  local busy=self.busyPending and (not self.lastBeacon or elapsed()-self.lastBeacon>=2)
  if not busy and (autoCount()>=A.DiscoveryLimits.peers or elapsed()<(self.nextBeacon or math.huge)) then return end
  if #self.queue>=12 then return end
  local history={};for _,at in ipairs(self.beacons or {}) do if at+120>elapsed() then history[#history+1]=at end end;self.beacons=history
  if #history>=A.DiscoveryLimits.advertisements then return end
  local channel
  if channelAvailable('GUILD') then channel='GUILD'
  elseif channelAvailable('INSTANCE_CHAT') then channel='INSTANCE_CHAT'
  elseif channelAvailable('RAID') then channel='RAID'
  elseif channelAvailable('PARTY') then channel='PARTY'
  elseif ns.ClientCompat.client=='forever' and (self.proximityRetryAt or 0)<=clock() then channel='SAY' end
  self.discoverySequence=self.discoverySequence+1
  self.nextBeacon=elapsed()+120+self:Jitter('beacon/'..self.discoverySequence,0,120)
  if not channel then return end
  local sent=self:Advertise(channel,nil,busy and 0 or 2)
  if sent then self.beacons[#self.beacons+1]=elapsed();self.lastBeacon=elapsed();self.busyPending=nil
  elseif channel=='SAY' then self.proximityRetryAt=clock()+600;self.nextBeacon=elapsed()+30 end
 end
 function a:Enqueue(id,text,receipt)
  if not permission() or #self.queue>=72 or type(text)~='string' or #text>255 or not self.routes[id] then return false,'NATIVE_QUEUE_OR_ROUTE_BOUND' end
  self.queue[#self.queue+1]={peer=id,text=text,receipt=receipt,attempts=0,expires=clock()+30};return true
 end
 function a:Hello(id,echo)
  return self:Enqueue(id,'S7|H|'..self.session..'|'..(echo or '-'))
 end
 function a:OpenLedger(explicit)
  if A.RelayPaused()then return false,A.RelayPauseMessage end
  if explicit~=true or not N.Preference() or ns.Permissions.Denied('network') or ns.MainStorageBlocked then return false,'EXPLICIT_NATIVE_POLICY_REQUIRED' end
  self.enabled=true
  local joined,err=c:Join(N.CONSENT,true);if not joined then self:Stop();return false,err end
  self.status='LOCAL_LEDGER_READY';return true
 end
 function a:Start(explicit)
  if A.RelayPaused()then return false,A.RelayPauseMessage end
  if c.recovery and c.recovery.state~='READY'then self.status='LOCAL_LEDGER_RECOVERING';return true,self.status end
  local joined,err=self:OpenLedger(explicit);if not joined then return false,err end
  if self.registered then wake();return true,self.status end
  local transport=A.TransportCapabilities();if not transport.available then self.status='LOCAL_LEDGER_READY · '..transport.reason;wake();return true,self.status end
  local ok,reason=register();if not ok then self.status='LOCAL_LEDGER_READY · '..reason;wake();return true,self.status end
  self.registered=true;self.status='LOCAL_LEDGER_READY · NATIVE_DELIVERY_UNVERIFIED'
  for id in pairs(self.routes) do self:Advertise('WHISPER',id,0);self:Hello(id) end;self.lastHello=clock()
  self.nextBeacon=elapsed()+self:Jitter('initial',15,90)
  wake()
  return true,'Native adapter started; real delivery and sender behavior remain unverified.'
 end
 function a:Stop()
  self.enabled=false;self.queue={};self.logical={};self.retry={};self.incoming={};self.seen={};self.peers={};self.ackHello={};self.budgets={};self.candidates={};self.discoveryCaps={};self.cooldowns={};self.pendingDiscovery=nil;self.sync=nil;self.status='CONSENT_OFF';wake();return true
 end
 local function dispatch(peer,wire)
  local pieces=chunks(wire);if not pieces or #pieces>60 or #a.queue+#pieces>72 or count(a.retry)>=4 then return false end
  a.sequence=a.sequence+1;local id=a.session..'-'..a.sequence;local digest=hash(wire):sub(1,16)
  local frames={};for i,piece in ipairs(pieces) do frames[i]='S7|D|'..id..'|'..i..'|'..#pieces..'|'..digest..'|'..piece;if #frames[i]>255 then return false end end
  local refs={};local outer=B.DecodeChunk(wire);local signed=outer and outer[1];local packet=signed and B.DecodeChunk(signed.wire);packet=packet and packet[1]
  for _,pair in ipairs(packet and packet.body and packet.body.rows or{})do if type(pair)=='table'and pair.wire then local r=(B.DecodeChunk(pair.wire)or{})[1];if r and ns.AetherPosts.IsKind(r.kind)then refs[#refs+1]=r.data.postID end end end
  a.retry[peer..'/'..id]={peer=peer,id=id,frames=frames,at=clock(),attempts=0,postRefs=refs}
  a.postTransfers=a.postTransfers or{};for _,ref in ipairs(refs)do a.postTransfers[ref]={peer=peer,state='QUEUED_TO_KNOWN_PEER',at=clock()}end
  for _,frame in ipairs(frames) do a:Enqueue(peer,frame) end;return true
 end
 options.send=function(principal,wire)
  local peer;for id,p in pairs(a.peers) do if p.principal==principal and p.ready and p.expires>clock() then peer=id end end
  if not peer or not permission() or type(wire)~='string' or #wire>10000 then return false end
  -- 72 frames at .35 sec keeps a queued packet inside the engine's 30-sec
  -- replay window. Oversize deltas fail backpressure instead of aging in a
  -- multi-minute queue. Ordinary four-record pages fit the native budget.
  a.logical=a.logical or {};if #a.logical>=16 then return false end
  a.logical[#a.logical+1]={peer=peer,wire=wire,expires=clock()+60};return true
 end
 function a:Ingress(prefix,text,channel,sender,event)
  if prefix~=W.PREFIX or not permission() or not ns.CanRead(text) or #text>255 then return false,'NATIVE_INGRESS_POLICY' end
  local b=self.ingressBudget;if not b or b.at<clock() then b={at=clock(),count=0};self.ingressBudget=b end;b.count=b.count+1
  if b.count>32 then return false,'NATIVE_GLOBAL_INGRESS_BOUND' end
  if event=='CHAT_MSG_ADDON' and text:sub(1,5)=='S7|B|' then return self:DiscoveryIngress(text,channel,sender) end
  if event~='CHAT_MSG_ADDON_LOGGED' then return false,'NATIVE_LOGGED_REQUIRED' end
  local id,display=name(sender);local route=id and self.routes[id]
  if id and id~=me.id and not route and channel=='WHISPER' and text:match('^S7|H|[a-f0-9]+|[a-f0-9%-]+$') and self.automatic and self.registered and autoCount()<A.DiscoveryLimits.peers and count(self.routes)<20 and count(self.cooldowns)<128 and (self.cooldowns[id] or 0)<=clock() then
   route={name=display,channel='WHISPER',automatic=true,attemptAt=clock()};self.routes[id]=route
  end
  if not route or route.channel~=channel or not channelAvailable(channel) then return false,'UNAPPROVED_NATIVE_SENDER' end
  local budget=self.budgets or {};self.budgets=budget;local rate=budget[id]
  if not rate or rate.at+60<=clock() then rate={at=clock(),n=0};budget[id]=rate end;rate.n=rate.n+1;if rate.n>240 then return false,'NATIVE_SENDER_RATE' end
  local nonce,echo=text:match('^S7|H|([a-f0-9]+)|([a-f0-9%-]+)$')
  if nonce then
   if #nonce~=20 or echo~='-' and echo~=self.session then return false,'HANDSHAKE_SESSION' end
   if not self.peers[id] and count(self.peers)>=20 then return false,'PEER_LIMIT' end
   local p=self.peers[id];if p and p.session~=nonce then
    self.incoming={};for key,r in pairs(self.retry) do if r.peer==id then self.retry[key]=nil end end
    if self.ackHello then self.ackHello[id]=nil end
   end
   local principal='Native/'..hash(id):sub(1,40)
   local cap=self.discoveryCaps[id];if cap and cap.session==nonce and cap.expires>clock() then route.inventory=true;route.inventoryDigest=cap.digest end
   if route.advertisedSession~=self.session then self:Advertise('WHISPER',id,0) end
   if not self.cacheOrigins[principal] and count(self.cacheOrigins)>=N.MAX_RECORDS+21 then return false,'NATIVE_CACHE_AUTHOR_BOUND' end
   -- A reciprocal hello in the same session must retain negotiated features.
   -- Replacing this table lost Posts v1 just after its capability frame arrived.
   p=p and p.session==nonce and p or{};p.name=display;p.principal='Native/'..hash(id):sub(1,40);p.session=nonce;p.ready=p.ready or echo==self.session;p.expires=clock()+180;self.peers[id]=p
   if route.automatic then if not route.connectedAt then self.busyPending=true;route.connectedAt=clock() end;self.cooldowns[id]=clock()+300 end
   origin(p.principal,display);if p.ready then confirmed(p) end
   if echo=='-' then self:Hello(id,nonce) elseif not self.ackHello or not self.ackHello[id] then self.ackHello=self.ackHello or {};self.ackHello[id]=true;self:Hello(id,nonce) end
   return true,'NATIVE_SESSION_HANDSHAKE'
  end
  local p=self.peers[id]
  -- A capability advertisement can precede the final reciprocal hello. It is
  -- inert metadata: no records or identity authority are accepted here.
  local postSession=text:match('^S7|P|([a-f0-9]+)|1$');if postSession then if not p or p.expires<=clock()or postSession~=p.session then return false,'CAPABILITY_SESSION'end;p.postsVersion=1;self.inventorySync=self.inventorySync or{};self.inventorySync[id]=nil;c.inventoryCache=nil;return true,'ROOM_POSTS_1'end
  local artSession,artVersion=text:match('^S7|J|([a-f0-9]+)|([123])$');if artSession then
   if not ns.WardenComposition or not p or p.expires<=clock()or artSession~=p.session then return false,'CAPABILITY_SESSION'end
   local version=math.max(p.artVersion or 0,tonumber(artVersion))
   if version~=p.artVersion then p.artVersion=version;self.inventorySync=self.inventorySync or{};self.inventorySync[id]=nil;c.inventoryCache=nil end
   return true,'ART_RECIPES_'..version
  end
  if not p or not p.ready or p.expires<=clock() then return false,'NATIVE_HANDSHAKE_REQUIRED' end
  local ack=text:match('^S7|A|([a-f0-9]+%-%d+)$')
  if ack then local key=id..'/'..ack;if self.retry[key] then for _,ref in ipairs(self.retry[key].postRefs or{})do self.postTransfers=self.postTransfers or{};self.postTransfers[ref]={peer=p.name,state='ENVELOPE_ACKNOWLEDGED_BY_KNOWN_PEER',at=clock()}end;self.retry[key]=nil;self.metrics.acked=self.metrics.acked+1;confirmed(p) end;return true end
  local mid,index,total,digest,piece=text:match('^S7|D|([a-f0-9]+%-%d+)|(%d+)|(%d+)|([a-f0-9]+)|(.*)$')
  index,total=tonumber(index),tonumber(total)
  if not mid or #mid>32 or mid:sub(1,20)~=p.session or not index or not total or index<1 or index>total or total>180 or #digest~=16 or #piece>180 then return false,'NATIVE_FRAME_FIELDS' end
  local key=id..'/'..mid
  if self.seen[key] then self:Enqueue(id,'S7|A|'..mid);return true,'DUPLICATE_FRAME' end
  local r=self.incoming[key]
  if not r then if count(self.incoming)>=4 then return false,'NATIVE_REASSEMBLY_BOUND' end;r={parts={},bytes=0,total=total,digest=digest,expires=clock()+60};self.incoming[key]=r end
  if r.total~=total or r.digest~=digest or r.parts[index] and r.parts[index]~=piece then self.incoming[key]=nil;return false,'NATIVE_FRAME_CONFLICT' end
  if not r.parts[index] then r.parts[index]=piece;r.bytes=r.bytes+#piece end;if r.bytes>24000 then self.incoming[key]=nil;return false,'NATIVE_REASSEMBLY_BYTES' end
  for i=1,total do if not r.parts[i] then return true,'PARTIAL' end end
  local wire=table.concat(r.parts);self.incoming[key]=nil;if hash(wire):sub(1,16)~=digest then return false,'NATIVE_FRAME_CHECKSUM' end
  receiving=p;local ok,accepted,why=pcall(c.Receive,c,p.principal,wire);receiving=nil
  if not ok or not accepted then self.metrics.rejected=self.metrics.rejected+1;self.lastReject=ok and why or 'NATIVE_RECORD_REJECTED';return false,self.lastReject end
  if count(self.seen)>=128 then return false,'NATIVE_REPLAY_BOUND' end
  self.seen[key]=clock()+120;p.expires=clock()+180;self.metrics.received=self.metrics.received+1;self:Enqueue(id,'S7|A|'..mid);return true
 end
 function a:PostStatus(id)local v=self.postTransfers and self.postTransfers[id];return v and v.at+600>clock()and ns.Athena.Copy(v)or{state='RECIPIENT_OR_ROOM_AVAILABILITY_UNKNOWN'}end
 function a:Pump()
  if A.RelayPaused()then self:Stop();return false end
  if not permission() then self:Stop();return false end
  for k,r in pairs(self.incoming) do if r.expires<=clock() then self.incoming[k]=nil end end
  for k,t in pairs(self.seen) do if t<=clock() then self.seen[k]=nil end end
  for id,p in pairs(self.peers) do if p.expires<=clock() then self.peers[id]=nil;self.status='NATIVE_UNVERIFIED_CACHE_ONLY' end end
  C.AdoptIssued(c);C.UpgradePending(c);C.Enrollment.Pump(a,c)
  self:DiscoveryPump()
  if self.registered and clock()-(self.lastHello or 0)>=60 then for id,r in pairs(self.routes) do if not r.automatic and channelAvailable(r.channel) or r.automatic and self.peers[id] and self.peers[id].expires-clock()<90 then self:Hello(id) end end;self.lastHello=clock() end
  for key,r in pairs(self.retry) do if r.at+10*(r.attempts+1)<=clock() then
   if r.attempts>=2 then self.retry[key]=nil;self.metrics.dropped=self.metrics.dropped+1 else r.at=clock();r.attempts=r.attempts+1;for _,frame in ipairs(r.frames) do self:Enqueue(r.peer,frame) end end
  end end
  self.logical=self.logical or {}
  local nextWire=self.logical[1]
  if nextWire then
   if nextWire.expires<=clock() or not self.peers[nextWire.peer] then table.remove(self.logical,1);self.metrics.dropped=self.metrics.dropped+1
   else
    -- Native queues are slower than in-process fixtures. Re-stamp only this
    -- adapter's outer session envelope at dispatch, never the public record.
    local outer=B.DecodeChunk(nextWire.wire);local signed=outer and outer[1];local packet=signed and B.DecodeChunk(signed.wire);packet=packet and packet[1]
    if packet then packet.at=clock();local wire=B.Encode({packet});local current=B.Encode({{wire=wire,signature=checksum(wire)}});if dispatch(nextWire.peer,current) then table.remove(self.logical,1) end
    else table.remove(self.logical,1);self.metrics.dropped=self.metrics.dropped+1 end
   end
  end
  if clock()-(self.prunedAt or 0)>=60 then
   self.prunedAt=clock();for ref,v in pairs(self.postTransfers or{})do if v.at+600<=clock()then self.postTransfers[ref]=nil end end;if count(self.postTransfers or{})>128 then self.postTransfers={}end;for id,digest in pairs(self.authoredIDs or {}) do if not c.records[id] and not c.floors[id] then self.authoredIDs[id]=nil;self.authored[digest]=nil end end
   local kept={[self.principal]=true};for _,entries in ipairs({c.records,c.floors}) do for _,row in pairs(entries) do local r=row.record or (B.DecodeChunk(row.pair.wire) or {})[1];if r then kept[r.origin]=true end end end
   for _,p in pairs(self.peers) do kept[p.principal]=true end
   for key in pairs(self.cacheOrigins)do if not kept[key]then self.cacheOrigins[key]=nil;self.originsRevision=(self.originsRevision or 0)+1 end end
   for id in pairs(self.budgets or {}) do if not self.routes[id] then self.budgets[id]=nil end end
  end
  -- Previously selected self-fields only. Drafts and historical captures
  -- are never renewed or published by this background producer.
  if #self.queue<12 then
   if self.shareIdentity and clock()-(self.identityAt or 0)>=300 then
    self.identityAt=clock()
    local data={name=me.base,realm=me.realm}
    for key,fn in pairs({class=UnitClass,race=UnitRace,faction=UnitFactionGroup}) do local value=ns.SafeCall(fn,'player');if ns.CanRead(value) and #value<=80 then data[key]=value end end
    local pair=c:Publish('CHARACTER',own,'IDENTITY','identity',data,N.NextRevision(c,'CHARACTER',own,'IDENTITY','identity'),false,true)
    if not pair then self.lastPublicationError='IDENTITY_PUBLICATION_FAILED' end
   end
   if self.sharePresence and clock()-(self.presenceAt or 0)>=30 then
    self.presenceAt=clock()
    local data=ns.AthenaPublication.Presence()
    if data then local pair=c:Publish('CHARACTER',own,'PRESENCE','presence',data,N.NextRevision(c,'CHARACTER',own,'PRESENCE','presence'),false,true);if pair then self.presenceAt=clock() end end
   end
  end
  -- Reconcile public subjects after a new eligible peer/session appears or
  -- this author commits a revision. No peer means no synchronization queue.
  local peers={};for id,peer in pairs(self.peers) do if peer.ready and peer.expires>clock() then peers[#peers+1]=id..'/'..peer.session end end;table.sort(peers)
  self.inventorySync=self.inventorySync or {}
  for id,p in pairs(self.peers) do if p.ready and p.expires>clock() and self.routes[id] and self.routes[id].inventory and #self.queue<12 and #self.logical<4 then
   local token=p.session..'/'..(self.authoredRevision or 0)..'/'..(self.routes[id].inventoryDigest or '')
   local previous=self.inventorySync[id]
   if not previous or previous.token~=token or previous.at+300<=clock() then
    local ok=c:Reconcile(p.principal);if ok then self.inventorySync[id]={token=token,at=clock()} end
   end
  end end
  for id in pairs(self.inventorySync) do if not self.peers[id] then self.inventorySync[id]=nil end end
  local legacyPeer=false;for id,p in pairs(self.peers) do if p.ready and p.expires>clock() and self.routes[id] and not self.routes[id].inventory then legacyPeer=true end end
  if #peers>0 and legacyPeer then
   local token=table.concat(peers,';')..'/'..tostring(self.authoredRevision or 0)
   if not self.sync or self.sync.token~=token then
    local subjects,seen={},{}
    for _,row in pairs(c.records) do local r=row.record;local key=r.subjectType..'/'..r.subjectKey
     if r.expiresAt>clock()and c:Wanted(r.subjectType,r.subjectKey)and options.canRelay(row)and not seen[key] then seen[key]=true;subjects[#subjects+1]={t=r.subjectType,key=r.subjectKey} end
    end
    -- Recent public updates are considered before older subject history.
    table.sort(subjects,function(x,y)return x.t..x.key<y.t..y.key end)
    self.sync={token=token,subjects=subjects,index=1,nextAt=0,attempts=0}
   end
   local sync=self.sync;local subject=sync.subjects[sync.index]
   if subject and clock()>=sync.nextAt and #self.queue<12 and #self.logical<8 and count(c.pending)<N.CONCURRENCY then
    local ok,why=c:Refresh(subject.t,subject.key);sync.nextAt=clock()+(ok and 1 or 10)
    if ok or why=='QUERY_COOLDOWN' then sync.index=sync.index+1;sync.attempts=0
    else sync.attempts=sync.attempts+1;if sync.attempts>=3 then sync.index=sync.index+1;sync.attempts=0 end end
   end
  else self.sync=nil end
  c:Pump()
  if elapsed()-self.lastSend<.35 then return false end
  local r=self.queue[1];if not r then self.status=self.registered and (count(self.peers)>0 and 'LOCAL_LEDGER_READY · PEER_SYNC_AVAILABLE' or 'LOCAL_LEDGER_READY · NO_REACHABLE_PEERS') or 'LOCAL_LEDGER_READY · TRANSPORT_UNAVAILABLE';return false end
  if r.expires<=clock() then table.remove(self.queue,1);self.metrics.dropped=self.metrics.dropped+1;return false end
  self.lastSend=elapsed();local ok,why=rawSend(self.routes[r.peer],r.text)
  if ok then table.remove(self.queue,1);self.metrics.sent=self.metrics.sent+1;self.metrics.bytesSent=(self.metrics.bytesSent or 0)+#r.text
   local mid,index,total=r.text:match('^S7|D|([a-f0-9]+%-%d+)|(%d+)|(%d+)|');local retry=mid and self.retry[r.peer..'/'..mid];if retry and index==total then for _,ref in ipairs(retry.postRefs or{})do self.postTransfers[ref]={peer=r.peer,state='TRANSFERRED_TO_KNOWN_PEER',at=clock()}end end
  elseif why~='COMMUNICATION_YIELD' and why~='COMBAT_PAUSED' and why~='NATIVE_RESTRICTED' then r.attempts=r.attempts+1;if r.attempts>3 then table.remove(self.queue,1);self.metrics.dropped=self.metrics.dropped+1 end;self.status=why end
  return ok,why
 end
 local publish=c.Publish
 c.Publish=function(self,...) local pair,why=publish(self,...);if pair then a.authoredIDs=a.authoredIDs or {};local old=a.authoredIDs[why];if old then a.authored[old]=nil end;local digest=hash(pair.wire);a.authoredIDs[why]=digest;a.authored[digest]=true;a.authoredRevision=(a.authoredRevision or 0)+1 end;return pair,why end
 local leave=c.Leave;c.Leave=function(self,...) a:Stop();return leave(self,...) end
 -- Retained legacy session bytes remain read-only. Certificate-backed originals
 -- can be forwarded after validation without turning the author into a peer.
 local snapshot,restore=c.Snapshot,c.Restore
 local metadata,metadataBytes,metadataRevision
 function c:SnapshotMetadataVersion()return a.originsRevision or 0 end
 function c:SnapshotMetadata(checkpoint)
  if metadataRevision~=a.originsRevision then
   local authors={};for principal,v in pairs(a.cacheOrigins)do authors[principal]={name=v.name};if checkpoint then checkpoint()end end
   metadata={version=1,authors=authors,sourceClass='native_session_v1'};metadataBytes=B.EncodedSize(metadata,checkpoint);metadataRevision=a.originsRevision
  end
  return metadata,metadataBytes
 end
 c.Snapshot=function(self) local value=snapshot(self);value.native={version=1,authors=ns.Athena.Copy(a.cacheOrigins),sourceClass='native_session_v1'};return value end
 c.Restore=function(self,value,checkpoint)
  if not plain(value) or not plain(value.native) or value.native.version~=1 or value.native.sourceClass~='native_session_v1' or not plain(value.native.authors) or count(value.native.authors)>N.MAX_RECORDS+21 then return false,'NATIVE_CACHE_PROVENANCE_REQUIRED' end
  local origins={};for principal,v in pairs(value.native.authors) do if not plain(v) then return false,'NATIVE_CACHE_AUTHOR' end;local id,display=name(v.name);if not id or principal~='Native/'..hash(id):sub(1,40) then return false,'NATIVE_CACHE_AUTHOR' end;origins[principal]={name=display};if checkpoint then checkpoint()end end
  if not plain(value.records) or not plain(value.floors) or #value.records+#value.floors>N.MAX_RECORDS then return false,'NATIVE_CACHE_BOUND' end
  local clean={};for k,v in pairs(value)do if k~='native'then clean[k]=v end end;local proofs={};local identities={[a.principal]=own}
  local priorOrigins,priorCertified=a.cacheOrigins,a.certified
  options.recoveryAbort=function()a.cacheOrigins=priorOrigins;a.originsRevision=(a.originsRevision or 0)+1;a.certified=priorCertified;restoring=nil;restoreGUID=nil;a.cacheProof={}end
  for _,entries in ipairs({clean.records,clean.floors}) do for _,row in ipairs(entries) do
   if not plain(row) or not plain(row.pair) or not ns.CanRead(row.pair.wire) or #row.pair.wire>10000 then return false,'NATIVE_CACHE_RECORD' end
   local parsed=B.DecodeChunk(row.pair.wire);local record=parsed and parsed[1];if not record or record.sourceClass~='native_session_v1'then return false,'NATIVE_CACHE_RECORD'end
   local certified=C.VerifyRecord(record.origin,row.pair.wire,row.pair.signature,c,true)
   local issuer=C.VerifyIssuer(record.origin,row.pair.wire,row.pair.signature)
   if certified then origins[record.origin]={name=certified.name..'-'..certified.realm};identities[record.origin]=certified.guid;a.certified[record.origin]=certified end
   if record.origin~=a.principal and not origins[record.origin]and not issuer then return false,'NATIVE_CACHE_RECORD'end
   proofs[hash(row.pair.wire)]=record.origin
   if record.kind=='IDENTITY' then
    local id=record.data and name(tostring(record.data.name)..'-'..tostring(record.data.realm))
    if not id or record.origin~='Native/'..hash(id):sub(1,40) or not S.GUID(record.subjectKey) or identities[record.origin] and identities[record.origin]~=record.subjectKey then return false,'NATIVE_CACHE_IDENTITY_CONFLICT' end
    identities[record.origin]=record.subjectKey
   elseif record.kind=='OWNER' then
    -- Previously admitted bytes remain a last-known local cache. This does
    -- not authenticate a remote origin for forwarding or grant live ownership.
    if not S.GUID(record.subjectKey) or identities[record.origin] and identities[record.origin]~=record.subjectKey then return false,'NATIVE_CACHE_IDENTITY_CONFLICT' end
    identities[record.origin]=record.subjectKey
   end
   if checkpoint then checkpoint()end
  end end
  local prior=a.cacheOrigins;a.cacheOrigins=origins;a.originsRevision=(a.originsRevision or 0)+1;a.cacheProof=proofs;restoring=true;restoreGUID=identities
  local ok,accepted,why
  if checkpoint then ok=true;accepted,why=restore(self,clean,checkpoint)else ok,accepted,why=pcall(restore,self,clean)end
  restoring=nil;restoreGUID=nil;a.cacheProof={}
  if not ok or not accepted then a.cacheOrigins=prior;a.originsRevision=(a.originsRevision or 0)+1;return false,ok and why or 'NATIVE_CACHE_REJECTED' end
  -- Restore the author's local index; canRelay independently verifies every
  -- certified original. Cached authors never become authenticated live peers.
  a.authored={};a.authoredIDs={}
  for id,row in pairs(self.records) do if row.record.origin==a.principal then local key=hash(row.pair.wire);a.authored[key]=true;a.authoredIDs[id]=key end;if checkpoint then checkpoint()end end
  options.recoveryAbort=nil
  a.authoredRevision=(a.authoredRevision or 0)+1
  return true
 end
 if config.routes~=nil then if not plain(config.routes) or #config.routes>20 then return nil,'NATIVE_ROUTE_BOUND' end;for _,r in ipairs(config.routes) do if not plain(r) then return nil,'NATIVE_ROUTE_POLICY' end;local ok,err=a:Approve(r.name,r.channel,true);if not ok then return nil,err end end end
 local perf=ns.WardenPerformance
 if perf and perf.Wrap then perf.Wrap(a,'Pump','Aether transport');perf.Wrap(c,'Compact','Aether cache expiry')end
 if ns.AetherUnified then ns.AetherUnified.Bind(c,a,options,function(peer)receiving=peer end)end
 A.controllers[a]=true;return c
end
assert(N.InstallProduction(function(build) return function(config) return create(build,config) end end))
function W.NewNative(config) return N.NewProduction(config) end
A.NativeName=name;A.NativeUnit=unit;A.SplitText=chunks;A.NativeResult=result;A.Restricted=restricted
function A.EnsureLocal()
 if A.RelayPaused()and not(ns.AetherUnified and ns.AetherUnified.Available())then return nil,A.RelayPauseMessage end
 if not(ns.AetherUnified and ns.AetherUnified.Active())and not N.Preference() or ns.Permissions.Denied('network') then return nil,'Aether participation is off. Your private drafts are kept.' end
 local own=ns.PlayerCard.Own();if not own then return nil,'Current local character identity is unavailable.' end
 local c=N.Current
 if c and (not c.nativeController or c.nativeController.owner~=own) then return nil,'The existing ledger belongs to a different authority; it is kept unchanged.' end
 if not c then
  local policy=N.NativePolicy() or {version=1,routes={},shareIdentity=false,sharePresence=false}
  local why;c,why=N.NewProduction({explicit=true,routes=policy.routes,shareIdentity=policy.shareIdentity,sharePresence=policy.sharePresence});if not c then return nil,why end
  local ok,reason=N.Bind(c,c.nativeController.owner);if not ok then return nil,reason end
  N.Current=c
 end
 local ok,why=c.nativeController:Start(true);if not ok then return nil,why end
 return c
end
function A.Configure(policy,explicit)
 if A.RelayPaused()then return false,A.RelayPauseMessage end
 if not ns.Permissions.Decide('UIAccess') or explicit~=true or not N.Preference() then return false,'EXPLICIT_NATIVE_SCOPE_REQUIRED' end
 local c,why=N.NewProduction({explicit=true,routes=policy and policy.routes,shareIdentity=policy and policy.shareIdentity,sharePresence=policy and policy.sharePresence});if not c then return false,why end
 local saved,reason=N.NativePolicy(policy,true);if not saved then return false,reason end
 if N.Current then N.Current:Leave() end
 local ok,err=N.Bind(c,c.nativeController.owner);if not ok then return false,err end
 N.Current=c;return c.nativeController:Start(true)
end
function A.EditPolicy()
 local old=N.NativePolicy() or {version=1,routes={},shareIdentity=false,sharePresence=false}
 local text={};for _,r in ipairs(old.routes or {}) do text[#text+1]=r.name end
 return ns.UI2Forms.Form({title='Preferred Aether peers · native candidate',help='Participating peers are discovered automatically where supported. These optional exact name-realm contacts supplement discovery. Authority-certified originals can be forwarded. Real-client enrollment and delivery remain unverified. Drafts stay private.',
  fields={{key='names',label='Approved reachable contacts · one exact name-realm per line',value=table.concat(text,'\n'),multiline=true,height=130,limit=3600},
   {key='shareIdentity',label='Automatically share my native name/GUID declaration with approved peers',value=old.shareIdentity,choices={{false,'Off'},{true,'On'}}},
   {key='sharePresence',label='Automatically share my coarse self-activity for 90 seconds',value=old.sharePresence,choices={{false,'Off'},{true,'On'}}}},submitLabel='Approve scope and start candidate session',submit=function(v)
    local policy={version=1,routes={},shareIdentity=v.shareIdentity==true,sharePresence=v.sharePresence==true};local seen={}
    for value in (v.names or ''):gmatch('[^\r\n]+') do local id,display=name(value);if not id or seen[id] or #policy.routes>=20 then return false,'Use up to 20 unique exact name-realm contacts.' end;seen[id]=true;policy.routes[#policy.routes+1]={name=display,channel='WHISPER'} end
    return A.Configure(policy,true)
   end})
end
function A.RestoreLocal()
 if ns.AetherUnified and ns.AetherUnified.Available()then return ns.AetherUnified.Restore()end
 -- Leave the saved ledger untouched and avoid its startup validation work.
 if A.RelayPaused()then return end
 if N.Current or not ns.Permissions.Owner() then return end
 local policy=N.NativePolicy()
 local stored=ns.Storage.OlympusWardenExchangeDB
 if not policy and not N.Preference() and not (stored and stored.netClients) then return end
 policy=policy or {version=1,routes={},shareIdentity=false,sharePresence=false}
 local c,why=N.NewProduction({explicit=true,routes={},shareIdentity=policy.shareIdentity,sharePresence=policy.sharePresence});if not c then A.lastError=why;return end
 local ok,err=N.Bind(c,c.nativeController.owner);if not ok then A.lastError=err;return end
 N.Current=c
 -- Prior explicit native scope can resume metadata sync; old consent or a
 -- mere Olympus verification transition cannot create that scope.
 if N.Preference() and not ns.Permissions.Denied('network') then
  for _,r in ipairs(policy.routes) do c.nativeController:Approve(r.name,r.channel,true) end
  c.nativeController:Start(true)
 end
end
local event=CreateFrame('Frame');A.frame=event
for _,name in ipairs({'PLAYER_LOGIN','PLAYER_LOGOUT','PLAYER_ENTERING_WORLD','CHAT_MSG_ADDON','CHAT_MSG_ADDON_LOGGED','GROUP_ROSTER_UPDATE','GUILD_ROSTER_UPDATE','CHANNEL_ROSTER_UPDATE','CHANNEL_COUNT_UPDATE','CHANNEL_UI_UPDATE','CHAT_MSG_CHANNEL_NOTICE'}) do pcall(event.RegisterEvent,event,name) end
event:SetScript('OnEvent',function(_,kind,...)
 if ns.AetherLive then ns.AetherLive.Event(kind,...)end
 if ns.AetherServices then ns.AetherServices.Event(kind,...)end
 if kind=='CHAT_MSG_ADDON' or kind=='CHAT_MSG_ADDON_LOGGED' then local prefix,text,channel,sender=...;if prefix~=W.PREFIX then return end
  for a in pairs(A.controllers) do if a.enabled then a:Ingress(prefix,text,channel,sender,kind) end end
 elseif kind=='PLAYER_LOGOUT' then for a in pairs(A.controllers) do if a.client.Save then a.client:Save() end;a.client:Leave() end
 elseif kind=='PLAYER_LOGIN' then A.RestoreLocal() end
 if kind=='PLAYER_ENTERING_WORLD' then for a in pairs(A.controllers) do a.candidates={};a.pendingDiscovery=nil;a.nextBeacon=elapsed()+a:Jitter('zone/'..clock(),15,90) end end
end)
local dt=0
local function update(_,step) dt=dt+(step or 0);if dt<.35 then return end;dt=0;A.pumpCalls=(A.pumpCalls or 0)+1;A.lastPumpAt=elapsed();if ns.AetherLive then ns.AetherLive.Pump()end;if ns.AetherServices then ns.AetherServices.Pump()end;for a in pairs(A.controllers) do if a.enabled then a:Pump() end end;if ns.AetherUnified and ns.AetherUnified.Available()and not(ns.AetherLive and ns.AetherLive.HasWork())then A.Wake()end end
function A.Wake() local enabled=ns.AetherLive and(ns.AetherLive.HasWork and ns.AetherLive.HasWork()or ns.AetherLive.Active())or ns.AetherServices and ns.AetherServices.HasWork()or false;for a in pairs(A.controllers) do if a.enabled and (a.registered and (a.automatic or next(a.routes)) or a.shareIdentity or a.sharePresence) then enabled=true;break end end;event:SetScript('OnUpdate',enabled and update or nil) end
local legacyCapabilities=W.Capabilities
W.Capabilities=function() local c=legacyCapabilities();local native=A.Capabilities();for k,v in pairs(native) do c[k]=v end;c.status='NATIVE_UNVERIFIED';c.nativeStatus='CONSENT_DRIVEN_AUTOMATIC';c.identityModel='NATIVE_EVENT_SENDER_SESSION';return c end
