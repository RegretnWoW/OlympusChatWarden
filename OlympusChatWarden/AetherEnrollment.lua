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
local function state(a)a.enrollment=a.enrollment or{pending={},sent={},offers={},exports={}};return a.enrollment end
function E.EnableVerifier(enabled)
 if enabled then local c=ns.AetherNet.Cached();local cert=c and C.LocalCertificate(c);if not cert or not cert.scopes.enroll then return false,'A current Fireside Authority operator delegation is required.'end end
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
 local id=ns.AetherNative.NativeName(p.name);if not id then return end
 local units={'target','mouseover'};for i=1,4 do units[#units+1]='party'..i end;for i=1,40 do units[#units+1]='raid'..i end
 for _,u in ipairs(units)do
  if ns.Checked(ns.SafeCall(UnitIsPlayer,u))and ns.Checked(ns.SafeCall(UnitIsVisible,u))then
   local native=ns.AetherNative.NativeUnit(u)
   if native and native.id==id and C.Principal(native.base,native.realm)==peer then return native,p end
  end
 end
 return nil,p
end
E.PeerNative=peerNative
local function sender(a,peer)for _,p in pairs(a.peers)do if p.principal==peer and p.ready and p.expires>now()then return p end end end
local function offerWire(cert,session,recipient)return 'AETHER-ENROLLMENT-OFFER/1\n'..cert..'\n'..session..'\n'..recipient end
function E.Handle(a,client,peer,kind,body)
 if not plain(body)then return false,'ENROLLMENT_FIELDS'end
 local s=state(a);local p=sender(a,peer);if not p then return false,'ENROLLMENT_NATIVE_SESSION_REQUIRED'end
 if kind=='ENROLLMENT_OFFER'then
  if not exact(body,{certificate=true,session=true,signature=true})or body.session~=p.session or not hex(body.signature,128)then return false,'ENROLLMENT_OFFER_FIELDS'end
  local cert,why=C.Certificate(body.certificate);if not cert or not cert.scopes.enroll or cert.principal~=peer or C.IsRevoked(client,cert)then return false,why or'UNTRUSTED_ENROLLMENT_OPERATOR'end
  if not X.Verify(cert.public,offerWire(body.certificate,body.session,client.principal),body.signature)then return false,'ENROLLMENT_OPERATOR_SIGNATURE'end
  if count(s.offers)>=16 and not s.offers[peer]then return false,'ENROLLMENT_BOUND'end
  s.offers[peer]={certificate=body.certificate,expires=math.min(now()+180,cert.notAfter)};return true
 elseif kind=='ENROLLMENT_REQUEST'then
  local own=C.LocalCertificate(client)
  if not E.verifier or not own or not own.scopes.enroll then return false,'ENROLLMENT_OPERATOR_UNAVAILABLE'end
  if not exact(body,{namespace=true,public=true,requestID=true})or body.namespace~=C.Namespace()or not hex(body.public,64)or body.requestID~=hash(body.namespace..'/'..body.public)then return false,'ENROLLMENT_REQUEST_FIELDS'end
  local native=peerNative(a,peer);if not native then return false,'NATIVE_SENDER_GUID_BINDING_UNAVAILABLE'end
  if count(s.pending)>=16 then return false,'ENROLLMENT_BOUND'end
  local request=peer..'/'..body.requestID;if s.pending[request]and s.pending[request].expiresAt>now()then return false,'ENROLLMENT_ALREADY_PENDING'end
  s.serial=(s.serial or 0)+1
  local challenge={version=1,namespace=C.Namespace(),name=native.base,realm=native.realm,guid=native.guid,principal=peer,public=body.public,
   requestID=body.requestID,nonce=hash(a.session..'/'..p.session..'/'..now()..'/'..s.serial),issuedAt=now(),expiresAt=now()+180,witnessCertificate=own.blob}
  s.pending[request]=challenge;return client:Send(peer,'ENROLLMENT_CHALLENGE',challenge)
 elseif kind=='ENROLLMENT_CHALLENGE'then
  local f={version=true,namespace=true,name=true,realm=true,guid=true,principal=true,public=true,requestID=true,nonce=true,issuedAt=true,expiresAt=true,witnessCertificate=true}
  local offer=s.offers[peer];local material=C.LocalMaterial();local me=ns.AetherNative.NativeUnit('player')
  if not exact(body,f)or not offer or offer.expires<now()or body.witnessCertificate~=offer.certificate or not material or not me
   or body.version~=1 or body.namespace~=C.Namespace()or body.name~=me.base or body.realm~=me.realm or body.guid~=me.guid
   or body.principal~=client.principal or body.public~=material.public or body.requestID~=hash(body.namespace..'/'..material.public)
   or not hex(body.nonce,64)or not ns.ChronicleStore.Integer(body.issuedAt,now()-180,now()+5)
   or not ns.ChronicleStore.Integer(body.expiresAt,now()+1,body.issuedAt+180)then return false,'ENROLLMENT_CHALLENGE_BINDING'end
  local signature=X.Sign(material.seed,'AETHER-ENROLLMENT-CHALLENGE/1\n'..encode(body))
  return client:Send(peer,'ENROLLMENT_RESPONSE',{requestID=body.requestID,nonce=body.nonce,signature=signature})
 elseif kind=='ENROLLMENT_RESPONSE'then
  if not exact(body,{requestID=true,nonce=true,signature=true})or not hex(body.requestID,64)or not hex(body.nonce,64)or not hex(body.signature,128)then return false,'ENROLLMENT_RESPONSE_FIELDS'end
  local request=peer..'/'..body.requestID;local challenge=s.pending[request];local own=C.LocalCertificate(client)
  if not E.verifier or not own or not own.scopes.enroll or not challenge or challenge.expiresAt<now()or challenge.nonce~=body.nonce or challenge.witnessCertificate~=own.blob then return false,'ENROLLMENT_CHALLENGE_EXPIRED'end
  local native=peerNative(a,peer)
  if not native or native.guid~=challenge.guid or native.base~=challenge.name or native.realm~=challenge.realm then return false,'NATIVE_SENDER_GUID_BINDING_CHANGED'end
  if not X.Verify(challenge.public,'AETHER-ENROLLMENT-CHALLENGE/1\n'..encode(challenge),body.signature)then return false,'ENROLLMENT_KEY_POSSESSION_REQUIRED'end
  local attestation=ns.Athena.Copy(challenge);attestation.observedAt=now();attestation.method='native_logged_sender_and_visible_unit_guid';attestation.possessionSignature=body.signature
  local wire=encode(attestation);local material=C.LocalMaterial();local signature=X.Sign(material.seed,'AETHER-ENROLLMENT-ATTESTATION/1\n'..wire)
  local result='WAE1:'..C.Encode(wire)..':'..signature
  if #s.exports>=32 then return false,'ENROLLMENT_EXPORT_BOUND'end
  s.exports[#s.exports+1]=result;s.pending[request]=nil
  if E.Completed then E.Completed(result)end;return true,'ENROLLMENT_EVIDENCE_READY_FOR_OFFLINE_AUTHORITY'
 end
 return false,'ENROLLMENT_OPERATION_UNKNOWN'
end
function E.Pump(a,client)
 if not client:Joined()then return end
 if E.WantsVerifier then E.verifier=E.WantsVerifier()==true end
 local s=state(a)
 for k,v in pairs(s.pending)do if v.expiresAt<now()then s.pending[k]=nil end end
 for k,v in pairs(s.offers)do if v.expires<now()then s.offers[k]=nil end end
 for k,v in pairs(s.sent)do if v+300<now()then s.sent[k]=nil end end
 local cert=C.LocalCertificate(client);local material=C.LocalMaterial()
 if not material then return end
 for _,p in pairs(a.peers)do if p.ready and p.expires>now()then
  local key=p.principal..'/'..p.session
  if E.verifier and cert and cert.scopes.enroll and not s.sent['offer/'..key]then
   local sig=X.Sign(material.seed,offerWire(cert.blob,a.session,p.principal))
   if client:Send(p.principal,'ENROLLMENT_OFFER',{certificate=cert.blob,session=a.session,signature=sig})then s.sent['offer/'..key]=now()end
  elseif not cert and s.offers[p.principal]and not s.sent['request/'..key]then
   if client:Send(p.principal,'ENROLLMENT_REQUEST',{namespace=C.Namespace(),public=material.public,requestID=hash(C.Namespace()..'/'..material.public)})then s.sent['request/'..key]=now()end
  end
 end end
end
