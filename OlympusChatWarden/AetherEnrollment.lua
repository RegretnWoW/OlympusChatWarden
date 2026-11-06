-- Native identity observations -> delegated Hephaestus attestation -> offline issuer.
-- Payload GUIDs are never accepted as native sender identity.
local _,ns=...
local C,X,B=ns.AetherCertificates,ns.AetherCrypto,ns.ChronicleBackup
local E={VERSION=1,verifier=false};C.Enrollment=E
local function now()return math.floor(ns.SafeNumber(ns.SafeCall(GetServerTime))or 0)end
local function hash(s)return ns.PackCrypto.Hex(ns.PackCrypto.SHA256(s))end
local function plain(t)return ns.Readable(t)and type(t)=='table'and not getmetatable(t)end
local function exact(t,allowed)if not plain(t)then return false end;for k in pairs(t)do if not allowed[k]then return false end end;return true end
local function hex(s,n)return type(s)=='string'and #s==n and not s:find('[^a-f0-9]')end
local function count(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
local function encode(t)return B.Encode({t})end
local function state(a)a.enrollment=a.enrollment or{pending={},sent={},offers={},exports={}};a.enrollment.requests=a.enrollment.requests or{};return a.enrollment end
function E.EnableVerifier(enabled)
 if enabled then local c=ns.AetherNet.Cached();local cert=c and(E.Operator and E.Operator(c)or C.LocalCertificate(c));if not cert or not cert.scopes.enroll then return false,'A current Fireside Authority operator delegation is required.'end end
 E.verifier=enabled==true;if E.SaveVerifierPreference then E.SaveVerifierPreference(E.verifier)end;return true,enabled and'Hephaestus delegated enrollment verification is active.'or'Enrollment verification is paused.'
end
function E.BootstrapRequest()
 local m=C.LocalMaterial();local me=ns.AetherNative.NativeUnit('player')
 if not m or not me then return nil,'Import a helper-generated character key first.'end
 local request={version=1,namespace=C.Namespace(),name=me.base,realm=me.realm,guid=me.guid,public=m.public,issuedAt=now()}
 local wire=encode(request);local sig=X.Sign(m.seed,'AETHER-OPERATOR-BOOTSTRAP/1\n'..wire)
 return 'WAO1:'..C.Encode(wire)..':'..sig
end
local function peerNative(a,peer)
 -- Match exact normalized native full name AND readable UnitGUID from the
 -- same live unit token. Party/raid/target observations are not payload fields.
 local p;for _,v in pairs(a.peers)do if v.principal==peer and v.ready and v.expires>now()then p=v;break end end
 if not p then return end
 local parse=a.layerNames and ns.AetherLive.Name or ns.AetherNative.NativeName
 local id=parse(p.name);if not id then return end
 -- Native guild rosters identify distant members without a unit token. The
 -- key-possession challenge remains mandatory and this binding is reread at
 -- both request and response. No peer-supplied GUID is used.
 local n=math.min(1000,ns.SafeNumber(ns.SafeCall(GetNumGuildMembers))or 0)
 for i=1,n do
  local row={pcall(GetGuildRosterInfo,i)}
  if row[1]and ns.CanRead(row[2])then
   local name=row[2];if not name:find('-',1,true)then name=name..'-'..tostring(ns.SafeCall(GetRealmName)or'')end
   local nativeID,display,base,realm=parse(name);local guid=row[18]
   if nativeID==id and ns.Readable(guid)and ns.ChronicleStore.GUID(guid)then return{id=nativeID,name=display,base=base,realm=realm,guid=guid,bindingSource='native-guild-roster'},p end
  end
 end
 local session=ns.AetherLive and ns.AetherLive.Session
 local remote=session and session.NativeIdentity(id)
 if remote and remote.guid then remote.bindingSource='native-channel-roster';return remote,p end
 local units={'target','mouseover'};for i=1,4 do units[#units+1]='party'..i end;for i=1,40 do units[#units+1]='raid'..i end
 -- Nameplate units let an idle issuer verify nearby visible applicants without
 -- selecting targets. Neither a peer payload nor a typed name supplies a GUID.
 if C_NamePlate and type(C_NamePlate.GetNamePlates)=='function'then
  local ok,plates=pcall(C_NamePlate.GetNamePlates)
  if ok and plain(plates)then local n=0;for _,plate in ipairs(plates)do n=n+1;if n>40 then break end
   if type(plate)=='table'and type(plate.namePlateUnitToken)=='string'then units[#units+1]=plate.namePlateUnitToken end
  end end
 end
 for _,u in ipairs(units)do
  if ns.Checked(ns.SafeCall(UnitIsPlayer,u))and ns.Checked(ns.SafeCall(UnitIsVisible,u))then
   local native=ns.AetherNative.NativeUnit(u)
   if native and parse(native.name)==id and C.Principal(native.base,a.layerNames and'forever'or native.realm)==peer then return native,p end
  end
 end
 return nil,p
end
E.PeerNative=peerNative
local function sender(a,peer)for _,p in pairs(a.peers)do if p.principal==peer and p.ready and p.expires>now()then return p end end end
local function offerWire(cert,session,recipient)return 'AETHER-ENROLLMENT-OFFER/1\n'..cert..'\n'..session..'\n'..recipient end
local function operatorMatches(cert,peer,p,client)
 if cert.principal==peer then return true end
 -- A valid authority credential must match this key-proven native session.
 -- A layer label is not used as a whisper boundary or as identity evidence.
 return client.enrollmentOnly and client.layerNames and p.public==cert.public
  and(not p.guid or p.guid==cert.guid)and ns.AetherLive.Name(p.name)==ns.AetherLive.Name(cert.name..'-'..cert.realm)
end
function E.Handle(a,client,peer,kind,body)
 local enrollment=client.enrollmentOnly and ns.AetherServices and ns.AetherServices.EnrollmentAuthorized()
 if ns.MainStorageBlocked or not(ns.AetherNet.Preference()or enrollment)or ns.Permissions.Denied('network')then return false,'ENROLLMENT_NOT_AUTHORIZED'end
 if not plain(body)then return false,'ENROLLMENT_FIELDS'end
 local s=state(a);local p=sender(a,peer);if not p then return false,'ENROLLMENT_NATIVE_SESSION_REQUIRED'end
 if kind=='ENROLLMENT_OFFER'then
  if not exact(body,{certificate=true,session=true,signature=true})or body.session~=p.session or not hex(body.signature,128)then return false,'ENROLLMENT_OFFER_FIELDS'end
  local cert,why;if E.OperatorCertificate then cert,why=E.OperatorCertificate(body.certificate)else cert,why=C.Certificate(body.certificate)end
  if not cert or not cert.scopes.enroll or not operatorMatches(cert,peer,p,client)or C.IsRevoked(client,cert)then return false,why or'UNTRUSTED_ENROLLMENT_OPERATOR'end
  if not X.Verify(cert.public,offerWire(body.certificate,body.session,client.principal),body.signature)then return false,'ENROLLMENT_OPERATOR_SIGNATURE'end
  if count(s.offers)>=16 and not s.offers[peer]then return false,'ENROLLMENT_BOUND'end
  s.offers[peer]={certificate=body.certificate,expires=math.min(now()+180,cert.notAfter)};return true
 elseif kind=='ENROLLMENT_REQUEST'then
  local own=E.Operator and E.Operator(client)or C.LocalCertificate(client)
  if not E.verifier or not own or not own.scopes.enroll then return false,'ENROLLMENT_OPERATOR_UNAVAILABLE'end
  if not exact(body,{namespace=true,public=true,requestID=true,name=client.layerNames,realm=client.layerNames,guid=client.layerNames})or body.namespace~=C.Namespace()or not hex(body.public,64)or body.requestID~=hash(body.namespace..'/'..body.public)then return false,'ENROLLMENT_REQUEST_FIELDS'end
  local native=peerNative(a,peer);if not native then return false,'NATIVE_SENDER_GUID_BINDING_UNAVAILABLE'end
  local name,realm=native.base,native.realm
  if client.enrollmentOnly and client.layerNames then
   -- Payload GUIDs remain untrusted. Require the native GUID and exact name;
   -- only the owner's home-layer label is carried in the signed challenge.
   if body.guid~=native.guid or body.name~=native.base or not C.Principal(body.name,body.realm)
    or not ns.CanRead(body.realm)or #body.realm>96 or body.realm:find('[|:%c]')then return false,'ENROLLMENT_NATIVE_OWNER_MISMATCH'end
   name,realm=body.name,body.realm
  end
  if count(s.pending)>=16 then return false,'ENROLLMENT_BOUND'end
  local request=peer..'/'..body.requestID;if s.pending[request]and s.pending[request].expiresAt>now()then return false,'ENROLLMENT_ALREADY_PENDING'end
  s.serial=(s.serial or 0)+1
  local challenge={version=1,namespace=C.Namespace(),name=name,realm=realm,guid=native.guid,principal=C.Principal(name,realm),public=body.public,
   requestID=body.requestID,nonce=hash(a.session..'/'..p.session..'/'..now()..'/'..s.serial),issuedAt=now(),expiresAt=now()+180,witnessCertificate=own.blob}
  s.pending[request]=challenge;return client:Send(peer,'ENROLLMENT_CHALLENGE',challenge)
 elseif kind=='ENROLLMENT_CHALLENGE'then
  local f={version=true,namespace=true,name=true,realm=true,guid=true,principal=true,public=true,requestID=true,nonce=true,issuedAt=true,expiresAt=true,witnessCertificate=true}
  local offer=s.offers[peer];local material=C.LocalMaterial();local me=ns.AetherNative.NativeUnit('player')
  if not exact(body,f)or not offer or offer.expires<now()or body.witnessCertificate~=offer.certificate or not material or not me
   or body.version~=1 or body.namespace~=C.Namespace()or body.name~=me.base or body.realm~=me.realm or body.guid~=me.guid
   or body.principal~=(client.layerNames and C.Principal(me.base,me.realm)or client.principal)or body.public~=material.public or body.requestID~=hash(body.namespace..'/'..material.public)
   or not hex(body.nonce,64)or not ns.ChronicleStore.Integer(body.issuedAt,now()-180,now()+5)
   or not ns.ChronicleStore.Integer(body.expiresAt,now()+1,body.issuedAt+180)then return false,'ENROLLMENT_CHALLENGE_BINDING'end
  local signature=X.Sign(material.seed,'AETHER-ENROLLMENT-CHALLENGE/1\n'..encode(body))
  if not signature then return false,'ENROLLMENT_SIGNING_FAILED'end
  if count(s.requests)>=16 and not s.requests[peer]then return false,'ENROLLMENT_BOUND'end
  s.requests[peer]={requestID=body.requestID,nonce=body.nonce,expiresAt=body.expiresAt,issuer=body.witnessCertificate}
  return client:Send(peer,'ENROLLMENT_RESPONSE',{requestID=body.requestID,nonce=body.nonce,signature=signature})
 elseif kind=='ENROLLMENT_RESPONSE'then
  if not exact(body,{requestID=true,nonce=true,signature=true})or not hex(body.requestID,64)or not hex(body.nonce,64)or not hex(body.signature,128)then return false,'ENROLLMENT_RESPONSE_FIELDS'end
  local request=peer..'/'..body.requestID;local challenge=s.pending[request];local own=E.Operator and E.Operator(client)or C.LocalCertificate(client)
  if not E.verifier or not own or not own.scopes.enroll or not challenge or challenge.expiresAt<now()or challenge.nonce~=body.nonce or challenge.witnessCertificate~=own.blob then return false,'ENROLLMENT_CHALLENGE_EXPIRED'end
  local native=peerNative(a,peer)
  if not native or native.guid~=challenge.guid or native.base~=challenge.name or not client.layerNames and native.realm~=challenge.realm then return false,'NATIVE_SENDER_GUID_BINDING_CHANGED'end
  if not X.Verify(challenge.public,'AETHER-ENROLLMENT-CHALLENGE/1\n'..encode(challenge),body.signature)then return false,'ENROLLMENT_KEY_POSSESSION_REQUIRED'end
  if E.IssueVerified then local issued,why=E.IssueVerified(a,client,peer,challenge)
   if issued~=nil then if issued then s.pending[request]=nil end;return issued,why end
  end
  if native.bindingSource then return false,'REMOTE_ENROLLMENT_REQUIRES_AUTOMATIC_ISSUER'end
  local attestation=ns.Athena.Copy(challenge);attestation.observedAt=now();attestation.method='native_logged_sender_and_visible_unit_guid';attestation.possessionSignature=body.signature
  local wire=encode(attestation);local material=C.LocalMaterial();local signature=X.Sign(material.seed,'AETHER-ENROLLMENT-ATTESTATION/1\n'..wire)
  local result='WAE1:'..C.Encode(wire)..':'..signature
  if #s.exports>=32 then return false,'ENROLLMENT_EXPORT_BOUND'end
  s.exports[#s.exports+1]=result;s.pending[request]=nil
  if E.Completed then E.Completed(result)end;return true,'ENROLLMENT_EVIDENCE_READY_FOR_OFFLINE_AUTHORITY'
 elseif kind=='ENROLLMENT_ISSUED'then
  if not exact(body,{requestID=true,nonce=true,certificate=true})then return false,'ENROLLMENT_RESULT_FIELDS'end
  local pending=s.requests[peer];local cert,why=C.Certificate(body.certificate)
  if not pending or pending.expiresAt<now()or pending.requestID~=body.requestID or pending.nonce~=body.nonce
   or not cert or not cert.delegation or not operatorMatches(cert.delegation,peer,p,client)or cert.delegation.blob~=pending.issuer then return false,why or'ENROLLMENT_RESULT_BINDING'end
  local ok,reason=C.ImportCertificate(body.certificate,client)
  if ok then s.requests[peer]=nil;s.sent['request/'..peer..'/'..p.session]=now()end
  return ok,reason
 end
 return false,'ENROLLMENT_OPERATION_UNKNOWN'
end
function E.Pump(a,client)
 if not client:Joined()then return end
 local elapsed=ns.SafeNumber(ns.SafeCall(GetTime))or now()
 if a.enrollmentPumpAt and elapsed-a.enrollmentPumpAt<.5 then return end;a.enrollmentPumpAt=elapsed
 if ns.AetherAutomaticEnrollment then ns.AetherAutomaticEnrollment.RenewIssuer(client)end
 if E.AutoServing and E.AutoServing(client)then E.verifier=true elseif E.WantsVerifier then E.verifier=E.WantsVerifier()==true end
 local s=state(a)
 for k,v in pairs(s.pending)do if v.expiresAt<now()then s.pending[k]=nil end end
 for k,v in pairs(s.offers)do if v.expires<now()then s.offers[k]=nil end end
 for k,v in pairs(s.sent)do if v+300<now()then s.sent[k]=nil end end
 for k,v in pairs(s.requests)do if v.expiresAt<now()then s.requests[k]=nil end end
 local cert=C.LocalCertificate(client);local material=C.LocalMaterial()
 if not material then return end
 for _,p in pairs(a.peers)do if p.ready and p.expires>now()then
  local key=p.principal..'/'..p.session
  local operator=E.Operator and E.Operator(client)or cert
  if E.verifier and operator and operator.scopes.enroll and not s.sent['offer/'..key]then
   local sig=X.Sign(material.seed,offerWire(operator.blob,a.session,p.principal))
   if client:Send(p.principal,'ENROLLMENT_OFFER',{certificate=operator.blob,session=a.session,signature=sig})then s.sent['offer/'..key]=now()end
  elseif(E.NeedsCertificate and E.NeedsCertificate(cert)or not cert)and s.offers[p.principal]and not s.sent['request/'..key]then
   local body={namespace=C.Namespace(),public=material.public,requestID=hash(C.Namespace()..'/'..material.public)}
   if client.enrollmentOnly and client.layerNames then local me=ns.AetherNative.NativeUnit('player');if me then body.name,body.realm,body.guid=me.base,me.realm,me.guid end end
   if client:Send(p.principal,'ENROLLMENT_REQUEST',body)then s.sent['request/'..key]=now()end
  end
 end end
end
