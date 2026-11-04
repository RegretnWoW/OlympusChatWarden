-- Addressed Direct Share compatibility. Legacy public query/vote packets are retired.
-- Retained legacy state is rollback-only; no live addon-message/Bridge binding.
local _,ns=...
local R,P=ns.Athena2,ns.AthenaSharePolicy
local E={VERSION=1,MAX_WIRE=24000};ns.AthenaExchange=E;ns.RelayDirectShare=E
local allowed={OFFER=true,ACCEPT=true,DECLINE=true,DATA=true,ACK=true}
local envelopeFields={protocol=true,kind=true,id=true,sender=true,recipient=true,issuedAt=true,expiresAt=true,body=true}
local function validate(packet,now)
 local p=R.Copy(packet,2000);if not p then return end
 for key in pairs(p) do if not envelopeFields[key] then return end end
 if p.protocol~='AETHER_2' or not allowed[p.kind] or not R.Text(p.id,96) or not R.GUID(p.sender) or not R.GUID(p.recipient) or not R.Number(p.issuedAt,now-120,now+5) or not R.Number(p.expiresAt,now+1,now+180) or p.expiresAt<=p.issuedAt or type(p.body)~='table' then return end
 local ok,wire=pcall(ns.ChronicleBackup.Encode,p);if not ok or #wire>E.MAX_WIRE then return end;return p,wire
end
function E.New(options)
 options=options or {};local now=options.clock or R.Now
 E.instances=(E.instances or 0)+1
 local nonce=tostring(now())..'-'..E.instances
 local c={owner=options.owner,consent=0,sequence=0,seen={},pending={},inbox={},outbox={},rate={},shared=ns.AthenaSharedStore.New(now),ratings=ns.AthenaRatingStore.New(now),bytesIn=0,bytesOut=0,rejected=0,options=options}
 local function budget(key,limit)
  local row=c[key];if not row or row.at+60<=now() then row={at=now(),count=0};c[key]=row end
  row.count=row.count+1;return row.count<=limit
 end
 local function member() local a=options.authority and options.authority(c.owner);return a and a.verified and a.guid==c.owner and a end
 function c:Joined() return false end
 function c:Join() return false,'LEGACY_PUBLIC_RETIRED: Aether Net is the sole public authority.' end
 function c:Leave() self.consent=0;for id,p in pairs(self.pending) do if p.channel=='aether' then self.pending[id]=nil end end;return true end
 function c:Expire()
  for id,at in pairs(self.seen) do if at<=now() then self.seen[id]=nil end end
  for id,p in pairs(self.pending) do if p.expiresAt<=now() then self.pending[id]=nil end end
  for id,p in pairs(self.inbox) do if p.expiresAt<=now() then self.inbox[id]=nil end end
  for id,p in pairs(self.outbox) do if p.expiresAt<=now() then self.outbox[id]=nil end end
  for key,r in pairs(self.rate) do if r.at+60<=now() then self.rate[key]=nil end end
  self.shared:Expire()
 end
 function c:Packet(kind,target,body)
  self.sequence=self.sequence+1
  return {protocol='AETHER_2',kind=kind,id=nonce..'-'..self.sequence,sender=self.owner,recipient=target,issuedAt=now(),expiresAt=now()+120,body=body}
 end
 function c:Transmit(packet)
  if not member() then return false,'MEMBERSHIP_REQUIRED' end
  if packet and (packet.kind=='QUERY' or packet.kind=='REPLY' or packet.kind=='NO_DATA' or packet.kind=='VOTE') and not self:Joined() then return false,'AETHER_OFF' end
  local clean,wire=validate(packet,now());if not clean or clean.sender~=self.owner then return false,'INVALID_PACKET' end
  local transmit=options.nativeTransport or options.mockTransport
  if not transmit then return false,'NATIVE_UNAVAILABLE: explicit recipient-scoped native session required' end
  if not budget('sendBudget',32) then return false,'OUTBOUND_RATE_LIMIT' end
  if transmit(clean.recipient,clean)~=true then return false,'TRANSPORT_REFUSED' end
  self.bytesOut=self.bytesOut+#wire;return true
 end
 function c:Query() return nil,'LEGACY_PUBLIC_RETIRED' end
 function c:PreviewDirect(target,projection)
  if not member() or not R.GUID(target) or not P.ValidateDirect(projection,target) then return nil,'DIRECT_POLICY' end
  if projection.snapshot and projection.snapshot.observerOwner:match('/(Player%-.+)$')~=self.owner then return nil,'SNAPSHOT_OBSERVER' end
  self:Expire();if R.Count(self.outbox)>=20 then return nil,'OUTBOX_FULL' end
  local p=self:Packet('OFFER',target,{projection=projection});local clean,wire=validate(p,now());if not clean then return end
  self.outbox[p.id]={packet=clean,wire=wire,expiresAt=p.expiresAt,state='REVIEW'};return p.id,wire
 end
 function c:SendDirect(id,reviewedWire,userClick)
  local d=self.outbox[id];if not userClick or not d or d.wire~=reviewedWire or d.state~='REVIEW' or d.expiresAt<=now() then return false,'EXACT_REVIEW_REQUIRED' end
  -- Mark before synchronous mock delivery, just as an async live sender would.
  d.state='OFFERED';local ok,why=self:Transmit(d.packet);if not ok then d.state='REVIEW' end;return ok,why
 end
 function c:Decide(id,accept,userClick)
  local p=self.inbox[id];if not p or p.kind~='OFFER' or not userClick or p.decision or p.expiresAt<=now() then return false,'INCOMING_REVIEW_REQUIRED' end
  p.accepted=accept==true;p.decision=accept and 'ACCEPTED' or 'DECLINED';p.acceptedAt=accept and now() or nil
  if accept and p.body.projection.snapshot then p.reviewHash=ns.PackCrypto.Hex(ns.PackCrypto.SHA256(ns.ChronicleBackup.Encode(p.body.projection.snapshot))) end
  local ok,why=self:Transmit(self:Packet(accept and 'ACCEPT' or 'DECLINE',p.sender,{requestID=id}))
  if not ok then p.accepted=nil;p.decision=nil end;return ok,why
 end
 function c:CanVote() return false,'LEGACY_PUBLIC_RETIRED' end
 function c:Vote() return false,'LEGACY_PUBLIC_RETIRED' end
 function c:Receive(sender,packet)
  self:Expire();local authority=options.authority and options.authority(sender)
  if not member() or not authority or not authority.verified or authority.guid~=sender then self.rejected=self.rejected+1;return false,'SENDER_AUTHORITY' end
  if not budget('receiveBudget',64) then self.rejected=self.rejected+1;return false,'GLOBAL_RATE_LIMIT' end
  -- Rate limits precede decoding/projecting; per-peer and whole-session maps bounded.
  if not self.rate[sender] and R.Count(self.rate)>=64 then return false,'PEER_CAPACITY' end
  local rate=self.rate[sender] or {at=now(),count=0};self.rate[sender]=rate;rate.count=rate.count+1
  if rate.count>24 then self.rejected=self.rejected+1;return false,'RATE_LIMIT' end
  local p,wire=validate(packet,now());if not p or p.sender~=sender or p.recipient~=self.owner then self.rejected=self.rejected+1;return false,'ENVELOPE' end
  local replayKey=sender..'/'..p.id
  if self.seen[replayKey] then return false,'REPLAY' end
  if R.Count(self.seen)>=512 then return false,'REPLAY_CAPACITY' end
  self.seen[replayKey]=p.expiresAt;self.bytesIn=self.bytesIn+#wire
  local b=p.body
  local function keys(expected) for k in pairs(b) do if not expected[k] then return false end end;return true end
  if p.kind=='OFFER' then
   if not keys({projection=true}) or not P.ValidateDirect(b.projection,self.owner) or R.Count(self.inbox)>=20 then return false,'DIRECT_POLICY' end
   if b.projection.snapshot and b.projection.snapshot.observerOwner:match('/(Player%-.+)$')~=sender then return false,'SNAPSHOT_OBSERVER' end
   self.inbox[p.id]=p;return true,'REVIEW_REQUIRED'
  elseif p.kind=='ACCEPT' or p.kind=='DECLINE' then
   if not keys({requestID=true}) then return false,'DIRECT_FIELDS' end
   local d=self.outbox[b.requestID];if not d or d.state~='OFFERED' or d.packet.recipient~=sender then return false,'UNSOLICITED' end
   if p.kind=='DECLINE' then d.state='DECLINED';return true end
   d.state='ACCEPTED';return self:Transmit(self:Packet('DATA',sender,{requestID=b.requestID,projection=d.packet.body.projection}))
  elseif p.kind=='DATA' then
   if not keys({requestID=true,projection=true}) then return false,'DIRECT_FIELDS' end
   local offer=self.inbox[b.requestID]
   if not offer or not offer.accepted or offer.received or offer.sender~=sender or not P.ValidateDirect(b.projection,self.owner) or ns.ChronicleBackup.Encode(b.projection)~=ns.ChronicleBackup.Encode(offer.body.projection) then return false,'UNREVIEWED_DATA' end
   if b.projection.snapshot then
    local stored,why=ns.RelayStore.ImportHistorical(self.owner,sender,authority.principal,b.requestID,b.projection.snapshot,offer.acceptedAt,now(),offer.reviewHash,true,options.receivedStorage)
    if not stored then return false,why end
    offer.receivedSnapshot={snapshot=R.Copy(b.projection.snapshot,4000),sourceClass='received_direct',sender=sender,receivedAt=now()}
   else
    local stored,why=self.shared:Put(authority.principal,'direct/'..b.requestID,1,now()+3600,b.projection.card,authority.guid)
    if not stored then return false,why end
   end
   offer.received=true;return self:Transmit(self:Packet('ACK',sender,{requestID=b.requestID}))
  elseif p.kind=='ACK' then
   if not keys({requestID=true}) then return false,'ACK_FIELDS' end
   local d=self.outbox[b.requestID];if not d or d.packet.recipient~=sender or d.state~='ACCEPTED' then return false,'UNSOLICITED' end;d.state='RECEIVED';return true
  end
  return false,'UNSUPPORTED'
 end
 function c:ExportState()
  return {schema=1,owner=self.owner,consent=self.consent,claims=self.shared:Snapshot(),votes=self.ratings:Snapshot()}
 end
 function c:RestoreState(state)
  local clean=R.Copy(state,30000);if not clean or clean.schema~=1 or clean.owner~=self.owner or clean.consent~=0 and clean.consent~=2 and clean.consent~=3 and clean.consent~=P.CONSENT then return false,'STATE_VERSION_OWNER_OR_CONSENT' end
  for key in pairs(clean) do if not ({schema=true,owner=true,consent=true,claims=true,votes=true})[key] then return false,'STATE_FIELD' end end
  local shared=ns.AthenaSharedStore.New(now);local ratings=ns.AthenaRatingStore.New(now)
  local ok,why=shared:Restore(clean.claims,options.authority);if not ok then return false,why end
  ok,why=ratings:Restore(clean.votes,options.authority);if not ok then return false,why end
  self.shared=shared;self.ratings=ratings;self.legacyState=clean;self.consent=0;return true
 end
 return c
end
