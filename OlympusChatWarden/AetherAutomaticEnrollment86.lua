-- Automatic character enrollment. Only public, root-signed issuer delegations
-- ship in the addon; the Authority private key remains outside the client.
local _,ns=...
local C,E,X=ns.AetherCertificates,ns.AetherCertificates.Enrollment,ns.AetherCrypto
local A={VERSION=1,MAX_LIFE=2592000,RENEW_BEFORE=259200};ns.AetherAutomaticEnrollment=A
local function now()return math.floor(ns.SafeNumber(ns.SafeCall(GetServerTime))or 0)end
local function hash(s)return ns.PackCrypto.Hex(ns.PackCrypto.SHA256(s))end
local function hex(s,n)return type(s)=='string'and #s==n and not s:find('[^a-f0-9]')end
local function text(s,n)return type(s)=='string'and #s>0 and #s<=n and not s:find('[|%z\001-\031\127]')end
local function integer(s)local n=tonumber(s);return n and n%1==0 and n>=0 and tostring(n)==s and n end
local function fields(wire)
 if type(wire)~='string'or #wire>2048 then return end
 local f={};for line in(wire..'\n'):gmatch('(.-)\n')do if line:find('[\r|%z]')then return end;f[#f+1]=line end
 if #f==13 then return f end
end
local function unpackBlob(blob,tag)
 if type(blob)~='string'or #blob>3000 then return end
 local b,s,p=blob:match('^'..tag..'|([%w_%-]+)|([a-f0-9]+)|([%w_%-]+)$')
 local wire=b and C.Decode(b,2048);local f=fields(wire)
 if f and f[1]==tag and hex(s,128)then return f,wire,s,p end
end
local grants,leaves={},{}
local checkedKeys=setmetatable({},{__mode='k'})
function A.Delegation(blob)
 local cached=grants[blob];if cached then if cached.namespace~=C.Namespace()then return nil,'DELEGATION_NAMESPACE'end;return cached end
 local f,wire,sig,chain=unpackBlob(blob,'WAD1');if not f then return nil,'DELEGATION_FORMAT'end
 local root=C.Authority(f[2],chain=='none'and'-'or C.Decode(chain,4096))
 local issued,expiry,life=integer(f[10]),integer(f[11]),integer(f[12])
 if not root or not hex(f[3],32)or f[4]~=C.Namespace()or not text(f[6],96)or not text(f[7],96)
  or not ns.ChronicleStore.GUID(f[8])or not hex(f[9],64)or f[5]~=C.Principal(f[6],f[7])
  or not issued or issued>now()+5 or expiry~=0 or not life or life<3600 or life>A.MAX_LIFE or f[13]~='issue-community'
  or not X.Verify(root.public,'AETHER-AUTOMATIC-ISSUER/1\n'..wire,sig)then return nil,'DELEGATION_AUTHORITY'end
 local d={issuer=f[2],id=hash(blob),serial=f[3],namespace=f[4],principal=f[5],name=f[6],realm=f[7],guid=f[8],public=f[9],
  keyID=hash(f[9]),notBefore=issued,notAfter=9999999999,maxLife=life,blob=blob,scopes={enroll=true},automatic=true}
 if ns.Athena2.Count(grants)>=16 then grants={}end;grants[blob]=d;return d
end
local originalCertificate=C.Certificate
function C.Certificate(blob,historical)
 if type(blob)~='string'or blob:sub(1,5)~='WAC2|'then return originalCertificate(blob,historical)end
 local cached=leaves[blob]
 if cached then if cached.namespace~=C.Namespace()then return nil,'CERTIFICATE_NAMESPACE'end;if not historical and now()>cached.notAfter then return nil,'CERTIFICATE_EXPIRED'end;return cached end
 local f,wire,sig,parent=unpackBlob(blob,'WAC2');if not f then return nil,'CERTIFICATE_FORMAT'end
 local d,why=A.Delegation(C.Decode(parent,3000));if not d then return nil,why end
 local epoch,before,after=integer(f[10]),integer(f[11]),integer(f[12])
 if f[2]~=d.id or not hex(f[3],32)or f[4]~=d.namespace or not text(f[6],96)or not text(f[7],96)
  or f[5]~=C.Principal(f[6],f[7])or not ns.ChronicleStore.GUID(f[8])or not hex(f[9],64)
  or not epoch or epoch<1 or not before or before<d.notBefore or before>now()+5 or not after or after<=before
  or after-before>d.maxLife or f[13]~='community,self'
  or not X.Verify(d.public,'AETHER-DELEGATED-CERTIFICATE/1\n'..wire,sig)then return nil,'DELEGATED_CERTIFICATE_INVALID'end
 if not historical and now()>after then return nil,'CERTIFICATE_EXPIRED'end
 local cert={issuer=d.issuer,id=hash(blob),serial=f[3],namespace=f[4],principal=f[5],name=f[6],realm=f[7],guid=f[8],public=f[9],
  keyID=hash(f[9]),epoch=epoch,notBefore=before,notAfter=after,scopes={community=true,self=true},blob=blob,delegation=d}
 if ns.Athena2.Count(leaves)>=128 then leaves={}end;leaves[blob]=cert;return cert
end
local revoked=C.IsRevoked
function C.IsRevoked(client,cert)return revoked(client,cert)or cert.delegation and revoked(client,cert.delegation)or false end
function A.LocalIssuer(client,identityOnly)
 local enroll=ns.AetherServices and ns.AetherServices.EnrollmentAuthorized()
 if ns.MainStorageBlocked or not(identityOnly or ns.AetherNet.Preference()or enroll)or ns.Permissions.Denied('network')then return end
 local m=C.LocalMaterial();local me=ns.AetherNative and ns.AetherNative.NativeUnit('player');if not m or not me then return end
 for _,blob in ipairs(ns.AetherAutomaticIssuerGrants or{})do local d=A.Delegation(blob)
  if d and d.public==m.public and d.guid==me.guid and d.principal==C.Principal(me.base,me.realm)and not C.IsRevoked(client,d)then return d end
 end
end
function A.IssuerRole()
 if ns.MainStorageBlocked then return'ISSUER_UNAVAILABLE','Saved data needs recovery; enrollment hosting is paused.'end
 local c=ns.AetherNet.Cached();local d=A.LocalIssuer(c,true)
 if not d then return'ISSUER_UNAVAILABLE','This character and its current key do not match an enrollment host grant.'end
 local lab=ns.WardenSimLab
 if not(ns.AetherNet.Preference()or ns.AetherServices and ns.AetherServices.EnrollmentAuthorized())or lab and(lab.error or lab.db and lab.db.enrollmentEnabled==false)then return'ISSUER_PAUSED','Your enrollment host identity matches. Hosting is paused; historical Relay participation stays your choice.'end
 local service=ns.AetherServices and ns.AetherServices.runtime;local native=c and c.nativeController
 if not(service and service.enabled and service.registered or native and native.enabled)then return'ISSUER_PAUSED','Your host identity matches. The enrollment connection is starting or unavailable; check connection support and retry.'end
 return'ISSUER_ACTIVE','Your host identity matches and the enrollment connection is active. Native delivery still depends on a reachable applicant.'
end
-- WoW's native random API is distinct from fastrandom and standard Lua's
-- seedable PRNG. Refuse replaced/tainted or emulated providers in production.
local random=math.random
function A.RandomBytes()
 if WARDEN_SIMULATOR_ISOLATED==true and A.RandomFixture then return A.RandomFixture()end
 if type(random)~='function'or random==fastrandom or math.random~=random or type(math.randomseed)=='function'
  or type(issecurevariable)~='function'then return nil,'NATIVE_KEY_GENERATOR_UNAVAILABLE'end
 local ok,secure=pcall(issecurevariable,math,'random');if not ok or not secure then return nil,'NATIVE_KEY_GENERATOR_UNAVAILABLE'end
 local bytes={};for i=1,32 do local good,b=pcall(random,0,255)
  if not good or type(b)~='number'or b%1~=0 or b<0 or b>255 then return nil,'NATIVE_KEY_GENERATOR_UNAVAILABLE'end
  bytes[i]=string.format('%02x',b)
 end;return table.concat(bytes)
end
function A.EnsureKey(scope)
 local service=scope=='live'and ns.AetherLive and ns.AetherLive.Session and ns.AetherLive.Session.Authorized()or scope=='enrollment'and ns.AetherServices and ns.AetherServices.EnrollmentAuthorized()
 if ns.MainStorageBlocked or not ns.Permissions.Decide('UIAccess')or not(ns.AetherNet.Preference()or service)or ns.Permissions.Denied('network')then return false,'ENROLLMENT_NOT_AUTHORIZED'end
 local me=ns.AetherNative and ns.AetherNative.NativeUnit('player');if not me then return false,'NATIVE_IDENTITY_UNAVAILABLE'end
 local root=ns.Storage.OlympusWardenExchangeDB
 if root~=nil and(not ns.Readable(root)or type(root)~='table'or getmetatable(root)or root.schema~=1 or type(root.characters)~='table')then return false,'EXCHANGE_RECOVERY_REQUIRED'end
 local k=root and root.aetherCredentials
 if k~=nil and(not ns.Readable(k)or type(k)~='table'or getmetatable(k)or k.schema~=1 or type(k.owners)~='table'or getmetatable(k.owners))then return false,'CREDENTIAL_RECOVERY_REQUIRED'end
 local owner=ns.PlayerCard.Own();if not owner then return false,'NATIVE_OWNER_REQUIRED'end
 local old=k and k.owners[owner]
 if old~=nil then
  if type(old)~='table'or getmetatable(old)or old.namespace~=C.Namespace()or not hex(old.seed,64)or not hex(old.public,64)then return false,'CREDENTIAL_RECOVERY_REQUIRED'end
  local checked=checkedKeys[old]
  if not checked or checked.seed~=old.seed or checked.public~=old.public then
   if X.Public(old.seed)~=old.public then return false,'CREDENTIAL_RECOVERY_REQUIRED'end
   checkedKeys[old]={seed=old.seed,public=old.public}
  end
  return true,'EXISTING_KEY_RETAINED'
 end
 local seed,why=A.RandomBytes();if not hex(seed,64)then return false,why or'NATIVE_KEY_GENERATOR_UNAVAILABLE'end
 local public=X.Public(seed);if not hex(public,64)then return false,'KEY_GENERATION_FAILED'end
 return C.ImportKey('WAK1|'..C.Namespace()..'|'..public..'|'..seed)
end
function A.Issue(client,challenge)
 local d=A.LocalIssuer(client);local m=C.LocalMaterial();if not d or not m then return nil,'AUTOMATIC_ISSUER_UNAVAILABLE'end
 local at=now();local f={'WAC2',d.id,hash(challenge.nonce..challenge.public..at):sub(1,32),d.namespace,challenge.principal,
  challenge.name,challenge.realm,challenge.guid,challenge.public,tostring(at),tostring(math.max(at-5,d.notBefore)),tostring(at+d.maxLife-5),'community,self'}
 local wire=table.concat(f,'\n');local sig=X.Sign(m.seed,'AETHER-DELEGATED-CERTIFICATE/1\n'..wire)
 local blob=sig and('WAC2|'..C.Encode(wire)..'|'..sig..'|'..C.Encode(d.blob))
 local cert=blob and C.Certificate(blob);if not cert or C.IsRevoked(client,cert)then return nil,'ISSUED_CERTIFICATE_REJECTED'end
 return blob
end
function E.OperatorCertificate(blob)return A.Delegation(blob)or C.Certificate(blob)end
function E.Operator(client)return A.LocalIssuer(client)or C.LocalCertificate(client)end
function E.NeedsCertificate(cert)return not cert or cert.notAfter-now()<A.RENEW_BEFORE end
function A.RenewIssuer(client)
 local d=A.LocalIssuer(client);if not d or not E.NeedsCertificate(C.LocalCertificate(client))then return end
 local challenge={principal=d.principal,name=d.name,realm=d.realm,guid=d.guid,public=d.public,nonce=hash(d.id..'/'..now())}
 local blob=A.Issue(client,challenge);if blob then return C.ImportCertificate(blob,client)end
end
function E.AutoServing(client)
 local d=A.LocalIssuer(client);if not d then return false end
 local lab=ns.WardenSimLab;if lab and(lab.error or lab.db and lab.db.enrollmentEnabled==false)then return false end
 return true
end
function E.IssueVerified(a,client,peer,challenge)
 if not E.AutoServing(client)then return nil end
 local blob,why=A.Issue(client,challenge);if not blob then return false,why end
 local ok,reason=client:Send(peer,'ENROLLMENT_ISSUED',{requestID=challenge.requestID,nonce=challenge.nonce,certificate=blob})
 if ok then E.lastIssuedAt=now();E.issued=(E.issued or 0)+1 end;return ok,reason
end
function A.Status()
 if not ns.AetherNet.Preference()then return 'OFF','Join Aether to connect. Your private history and drafts stay on this computer.'end
 if ns.MainStorageBlocked then return 'PROTECTED','Saved data needs recovery. Your existing data is kept.'end
 local c=ns.AetherNet.Cached();local issuer=A.LocalIssuer(c)
 if issuer then return E.AutoServing(c)and'ISSUER_ACTIVE'or'ISSUER_PAUSED',E.AutoServing(c)and'Automatic enrollment issuer is active while you are online.'or'Automatic enrollment is paused.'end
 local cert=C.LocalCertificate(c);if cert then return 'ENROLLED','You have joined Aether. Your character renews enrollment automatically when a verifier is reachable.'end
 return 'PENDING',A.lastError and'Joined. Automatic setup is waiting for a supported client and healthy saved data. Existing keys and history are kept; enrollment will retry.'or'Joined. Waiting for a reachable verifier to confirm your character. Enrollment retries automatically.'
end
function ns.AetherNet.JoinUI()
 if ns.AetherServices then return ns.UI2Forms.Feedback(ns.AetherServices.EnrollRelay())end
 local state,detail=A.Status()
 if ns.AetherNet.Preference()then return ns.UI2Forms.Form({title='Aether',help=detail,fields={},submitLabel='Open Aether',submit=function()ns.UI2.Open({page='relay',subsection='aether'});return true end})end
 return ns.UI2Forms.Form({title='Join Aether',help='Connect with Fireside players. Joining is optional.',fields={},paragraphs={
  'Your character identity is used to enroll you automatically when a trusted verifier is reachable.',
  'Posts you choose to publish and eligible community records can synchronize with other participants.',
  'Your private history, conversations and drafts stay private. Joining does not turn on recording.',
  'You can leave Aether in Settings at any time.'},submitLabel='Join Aether',submit=function()
  local ok,why=ns.AetherNet.SetPreference(true);if not ok then return false,why end
  local ready,reason=A.EnsureKey();A.lastError=not ready and reason or nil
  if ready and ns.AetherRelay then ns.AetherRelay.Resume()end
  ns.UI2.Open({page='relay',subsection='aether'});return true,ready and'Joined Aether. Enrollment continues automatically.'or'Joined Aether. '..tostring(reason)
 end})
end
local frame=CreateFrame('Frame');local elapsed=0
frame:SetScript('OnUpdate',function(_,dt)
 elapsed=elapsed+(dt or 0);if elapsed<10 then return end;elapsed=0
 if ns.Initializing or not ns.AetherNet.Preference()or ns.Permissions.Denied('network')or ns.MainStorageBlocked then return end
 local ok,why=A.EnsureKey();A.lastError=not ok and why or nil
 if ok and ns.AetherRelay then local c=ns.AetherNet.Cached();if not c or not c.nativeController or not c.nativeController.enabled then ns.AetherRelay.Resume()end end
end)
