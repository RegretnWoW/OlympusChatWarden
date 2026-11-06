-- Shared signed ledger. The native adapter supplies identity and transport;
-- the isolated factory never establishes real client verification by itself.
local _,ns=...
local N={VERSION=5,SCHEMA=5,CONSENT=7,MAX_WIRE=24000,MAX_RECORDS=8192,MAX_PROFILE=128,
 MAX_BYTES=16777216,PROFILE_BYTES=262144,MAX_PEERS=20,CONCURRENCY=4,BATCH=4,TTL=604800,TOMBSTONE_TTL=2592000}
ns.AetherNet=N
-- Admission retry belongs to the existing persistence/lifecycle frame, not a
-- second work scheduler. Weak, bounded registrations contain no saved records.
N.recoveries=setmetatable({},{__mode='k'})
N.snapshotSizes=setmetatable({},{__mode='k'}) -- Qualified runtime lengths only.
-- Signed record-kind transition. WALL remains the exact legacy owner-policy
-- contract; COMMUNITY_WALL is independent of owner biography/participation.
-- Old peers reject this unknown kind safely. No signed bytes are rewritten.
N.COMMUNITY_KIND='COMMUNITY_WALL';N.COMMUNITY_VERSION=1
local B=ns.ChronicleBackup
local zones={Recreation=true,Pro=true,Family=true,Underground=true}
local function exact(t,allowed)
 if type(t)~='table' or getmetatable(t) then return false end
 for k in pairs(t) do if not allowed[k] then return false end end;return true
end
local function keys(s) local t={};for k in s:gmatch('%S+') do t[k]=true end;return t end
local function integer(v,a,b) return type(v)=='number' and v==v and v>=a and v<=b and v%1==0 end
-- ipairs/# silently ignore holes and map keys. Signed arrays and restored
-- snapshots must be dense, otherwise malformed input can erase a valid ledger.
local function array(v,maximum)
 if type(v)~='table' or getmetatable(v) then return false end
 local n=0;for k in pairs(v) do if not integer(k,1,maximum) then return false end;n=n+1 end
 if n>maximum then return false end
 for i=1,n do if v[i]==nil then return false end end
 return true
end
local function token(v,n) return type(v)=='string' and #v>0 and #v<=(n or 128) and v:match('^[%w_:/%.%-]+$')~=nil end
local function guid(v) return type(v)=='string' and #v<=96 and v:match('^Player%-[%w%-]+$')~=nil end
local function count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
local function subject(t,key)
 if t=='ROOM'then return ns.AetherPostRooms.Valid(key)and 'ROOM/'..key or nil end
 local wiki=t=='WIKI' and ns.AthenaLivingWiki and ns.AthenaLivingWiki.ValidKey(key)
 return (t=='CHARACTER' and guid(key) or t=='GUILD' and token(key) and key:match('^Guild%-') or t=='EVENT' and token(key) and key:match('^Event%-') or wiki) and t..'/'..key
end
local function text(s,limit)
 if type(s)~='string' or #s>limit*4 or s:gsub('[\r\n]',''):find('%c') or s:find('[|<>]') or s:find('%a+://') or s:lower():find('www%.') then return false end
 local i,n=1,0
 while i<=#s do
  local b=s:byte(i);local len=b<128 and 1 or b>=194 and b<=223 and 2 or b>=224 and b<=239 and 3 or b>=240 and b<=244 and 4
  if not len or i+len-1>#s then return false end
  for j=i+1,i+len-1 do local c=s:byte(j);if c<128 or c>191 then return false end end
  local second=s:byte(i+1)
  if len>=3 and (b==224 and second<160 or b==237 and second>=160 or b==240 and second<144 or b==244 and second>=144) then return false end
  i=i+len;n=n+1;if n>limit then return false end
 end
 return true
end
N.Text=text;N.Subject=subject
local fields=keys('schema subjectType subjectKey kind origin slot revision issuedAt expiresAt removed data sourceClass')
local shapes={POST=ns.AetherPosts.postFields,POST_UPVOTE=ns.AetherPosts.voteFields,EXTENSION_CARD=ns.AetherExtensionContracts.cardFields,ACTIVITY_ENVELOPE=ns.AetherExtensionContracts.envelopeFields,IDENTITY=keys('name realm class race faction'),OWNER=keys('about gamerzone wallEnabled policyRevision policyAt drawingsAllowed appearance'),
 PLAYER_VOTE=keys('score'),GUILD_VOTE=keys('score'),GUILD_ZONE=keys('guildzone'),
 BG=keys('matchID observationID mapName result killingBlows deaths damageDone healingDone'),
 WALL=keys('text parent policyRevision'),COMMUNITY_WALL=keys('text parent doodle'),WIKI_REPORT=keys('target reason'),HIDE=keys('target hidden'),BLOCK=keys('principal blocked since periods'),
 GEAR=keys('realm observedAt evidence quality completeness contentHash slots'),
 TALENTS=keys('realm observedAt evidence quality completeness contentHash specializationID exportString choices'),
 MEMBER=keys('guid asOf'),EVENT=keys('eventKey name activityType'),
 EVENT_FACT=keys('version name realm activityType runToken instanceID difficulty startAt endAt outcome participants sourceRef'),
 PRESENCE=keys('version activity place observedAt validUntil evidence'),EVENT_FEEDBACK=keys('version target category text'),CHARACTER_CERTIFICATE=keys('version certificate'),KEY_REVOCATION=keys('version issuer keyID revokedAt reason')}
local function recordKey(r) return subject(r.subjectType,r.subjectKey)..'/'..r.kind..'/'..r.origin..'/'..r.slot end
N.RecordKey=recordKey
function N.HideSlot(target) return ns.PackCrypto.Hex(ns.PackCrypto.SHA256(target)):sub(1,32) end
local function digest(pair,alternate) return ns.PackCrypto.Hex(ns.PackCrypto.SHA256(pair.wire..'\n'..pair.signature..(alternate and '\n'..alternate.wire..'\n'..alternate.signature or ''))) end
local build
function N.New(options)
 options=options or {}
 if WARDEN_SIMULATOR_ISOLATED~=true or options.fixture~=true then
  if N.NewProduction then return N.NewProduction(options) end
  return nil,'NATIVE_ADAPTER_UNAVAILABLE'
 end
 return build(options)
end
-- Installed once by the bundled native module. This is dependency wiring, not
-- identity proof: every admitted remote record still needs native ingress.
function N.InstallProduction(factory)
 if type(factory)~='function' or N.NewProduction then return false end
 N.NewProduction=factory(build);N.InstallProduction=nil;return true
end
build=function(options)
 if type(options.verify)~='function' or type(options.sign)~='function' or type(options.authority)~='function'
  or type(options.identity)~='function' or type(options.owns)~='function' or not token(options.principal) then return nil,'AUTHORITY_ADAPTER_REQUIRED' end
 local now=options.clock or function() return time() end
 local batch=options.batch or N.BATCH
 local function maximumTTL(r)return (r.kind=='CHARACTER_CERTIFICATE'or r.kind=='KEY_REVOCATION')and N.TOMBSTONE_TTL or (r.removed and N.TOMBSTONE_TTL or N.TTL)end
 -- A principal identifies a voter, not a transport session. Two alts share
 -- one vote ledger but must never share replay IDs or lookup correlation.
 -- These are isolated fixture identifiers, not native identity credentials.
 if options.session~=nil and not token(options.session,64) then return nil,'SESSION_TOKEN' end
 N.fixtureSerial=(N.fixtureSerial or 0)+1
 local session=ns.PackCrypto.Hex(ns.PackCrypto.SHA256(options.session or ('fixture/'..N.fixtureSerial..'/'..now()))):sub(1,24)
 local c={options=options,principal=options.principal,consent=0,records={},revision=0,bytes=0,sequence=0,
  pending={},expected={},rates={},queries={},outbox={},coverage={},seen={},floors={},floorBytes=0,listeners={},interests={},metrics={accepted=0,rejected=0,bytesIn=0,bytesOut=0},status='ISOLATED_SIMULATION'}
 c.session=session
 function c:SubjectLimit(t)return t=='ROOM'and ns.AetherPosts.MAX_ROOM or N.MAX_PROFILE end
 function c:SubjectBytes(t)return t=='ROOM'and 2097152 or N.PROFILE_BYTES end
 function c:Wanted(t,k)return t~='ROOM'or ns.AetherPosts.Wanted(self,k)end
 function c:CacheToken() return tostring(self.revision)..'/'..math.floor(now()/60)..'/'..tostring(self:Joined()) end
 local function authorized(principal)
  local a=options.authority(principal)
  return type(a)=='table' and a.verified==true and a.eligible==true and a.principal==principal and a or nil
 end
 function c:Joined() return ns.Permissions.Decide('AetherParticipation',{consent=self.consent,authorized=authorized(self.principal)~=nil}) end
 function c:Join(version,explicit)
  if ns.Permissions.Denied('network') or version~=N.CONSENT or explicit~=true or not authorized(self.principal) then return false,'EXPLICIT_CURRENT_CONSENT_REQUIRED' end
  self.consent=version;return true
 end
 function c:Leave() self.consent=0;self.pending={};self.expected={};self.outbox={};self.listeners={};self.interests={};self.inventories={};return true end
 local function budget(peer,limit)
  local r=c.rates[peer];if not r or r.at+60<=now() then r={at=now(),n=0};c.rates[peer]=r end
  r.n=r.n+1;return r.n<=limit
 end
 local function validate(r,archived,localArchive)
  if not exact(r,fields) or r.schema~=N.SCHEMA or not subject(r.subjectType,r.subjectKey) or not shapes[r.kind]
   or not token(r.origin) or not token(r.slot,96) or not integer(r.revision,1,1000000000)
   or not integer(r.issuedAt,archived and 1 or now()-N.TOMBSTONE_TTL-N.TTL,now()+5) or not integer(r.expiresAt,archived and 1 or now()+1,now()+N.TOMBSTONE_TTL+5)
   or r.expiresAt<=r.issuedAt or r.expiresAt-r.issuedAt>maximumTTL(r)
   or r.removed~=nil and type(r.removed)~='boolean' or r.sourceClass~=(options.sourceClass or 'synthetic_fixture')
   or not exact(r.data,shapes[r.kind]) or not authorized(r.origin) then return false,'RECORD_POLICY' end
  if options.recordPolicy then local ok,why=options.recordPolicy(r,archived);if not ok then return false,why or 'TRUST_CAPABILITY_REQUIRED' end end
  if r.subjectType=='WIKI' and r.kind~=N.COMMUNITY_KIND and r.kind~='WIKI_REPORT' then return false,'WIKI_KIND_SCOPE' end
  if r.subjectType=='EVENT' and not ({EVENT_FACT=true,EVENT_FEEDBACK=true,COMMUNITY_WALL=true,HIDE=true,BLOCK=true})[r.kind] then return false,'EVENT_KIND_SCOPE' end
  if not options.identity(r.subjectType,r.subjectKey) then return false,'IDENTITY_UNVERIFIED' end
  local d,k=r.data,r.kind
  if r.subjectType=='ROOM'then return ns.AetherPosts.Validate(r,localArchive==true,options.owns)end
  if ns.AetherPosts.IsKind(k)then return false,'ROOM_SUBJECT_REQUIRED'end
  if (k=='WALL'or k==N.COMMUNITY_KIND)and not archived then return false,'COMMUNITY_WALL_RETIRED'end
  if k=='OWNER' or k=='GUILD_ZONE' or k=='HIDE' or k=='BLOCK' then
   if not options.owns(r.origin,r.subjectType,r.subjectKey) then return false,'OWNER_PROOF_REQUIRED' end
  end
  if k=='IDENTITY' then
   if r.slot~='identity' or not text(d.name,80) or #d.name==0 or not text(d.realm,80) or #d.realm==0 then return false,'IDENTITY_FIELDS' end
   for key,v in pairs(d) do if not text(v,80) then return false,'IDENTITY_TEXT' end end
  elseif k=='EXTENSION_CARD'then
   if r.subjectType~='CHARACTER'or not options.owns(r.origin,'CHARACTER',r.subjectKey)then return false,'EXTENSION_PROFILE_OWNER_REQUIRED'end
   local ok,why=ns.AetherExtensionContracts.Card(d,r.removed);if not ok then return false,why end
   if not r.removed and r.slot~='sdk/'..d.extension..'/'..d.cardID then return false,'EXTENSION_SLOT'end
  elseif k=='ACTIVITY_ENVELOPE'then
   if r.subjectType~='CHARACTER'or r.removed or not options.owns(r.origin,'CHARACTER',d.actorGUID)or r.subjectKey~=d.actorGUID then return false,'EXTENSION_ACTOR_OWNER_REQUIRED'end
   local ok,why=ns.AetherExtensionContracts.Envelope(d,now(),archived);if not ok then return false,why end
   if r.slot~='sdk/'..d.envelopeID then return false,'ENVELOPE_SLOT'end
  elseif k=='PLAYER_VOTE' or k=='GUILD_VOTE' then
   if (r.subjectType~='CHARACTER' and r.subjectType~='GUILD') or r.slot~='vote' or (k=='PLAYER_VOTE')~=(r.subjectType=='CHARACTER') or not r.removed and not integer(d.score,1,k=='PLAYER_VOTE' and 5 or 10) or r.removed and next(d) then return false,'VOTE_POLICY' end
   if k=='PLAYER_VOTE' and options.owns(r.origin,r.subjectType,r.subjectKey) then return false,'SELF_VOTE' end
  elseif k=='OWNER' then
   if d.appearance~=nil and(not ns.WardenAppearance.Valid(d.appearance)or d.appearance.observedAt>r.issuedAt or r.issuedAt-d.appearance.observedAt>N.TTL)then return false,'OWNER_APPEARANCE_FIELDS'end
   if r.subjectType~='CHARACTER' or r.slot~='owner' or d.about~=nil and not text(d.about,500) or not r.removed and (d.gamerzone~=nil and not zones[d.gamerzone] or type(d.wallEnabled)~='boolean'
    or d.drawingsAllowed~=nil and type(d.drawingsAllowed)~='boolean' or not integer(d.policyRevision,1,r.revision) or not integer(d.policyAt,0,r.issuedAt)) then return false,'OWNER_FIELDS' end
  elseif k=='GUILD_ZONE' then
   if r.subjectType~='GUILD' or r.slot~='zone' or not r.removed and not zones[d.guildzone] then return false,'GUILD_ZONE' end
  elseif k=='WALL' or k==N.COMMUNITY_KIND then
   if (r.subjectType~='CHARACTER' and ((r.subjectType~='EVENT' and r.subjectType~='WIKI' and r.subjectType~='GUILD') or k~='COMMUNITY_WALL')) or not text(d.text,d.parent and 280 or 500) or not r.removed and #d.text==0
    or k=='WALL' and not integer(d.policyRevision,1,1000000000) or d.parent~=nil and not token(d.parent,384) then return false,'WALL_FIELDS' end
   if d.doodle~=nil then
    if k~=N.COMMUNITY_KIND or r.removed or not ns.WardenDrawing.Decode(d.doodle,ns.WardenDrawing.PUBLIC)then return false,'DRAWING_INVALID'end
    local mine=options.owns(r.origin,r.subjectType,r.subjectKey)
    local view=not mine and c:View(r.subjectType,r.subjectKey)
    if not archived and not mine and(not view or not view.owner or view.owner.drawingsAllowed~=true)then return false,'DRAWING_PROFILE_OWNER_PERMISSION_REQUIRED'end
   end
  elseif k=='WIKI_REPORT' then
   local prefix='WIKI/'..r.subjectKey..'/'..N.COMMUNITY_KIND..'/'
   if r.subjectType~='WIKI' or not token(d.target,384) or d.target:sub(1,#prefix)~=prefix or r.slot~=N.HideSlot(d.target)
    or not text(d.reason,280) or not r.removed and #d.reason==0 then return false,'WIKI_REPORT_FIELDS' end
  elseif k=='HIDE' then
   if (r.subjectType~='CHARACTER' and r.subjectType~='EVENT' and r.subjectType~='GUILD') or not token(d.target,384) or r.slot~=N.HideSlot(d.target) or type(d.hidden)~='boolean' then return false,'HIDE_FIELDS' end
  elseif k=='BLOCK' then
   if (r.subjectType~='CHARACTER' and r.subjectType~='EVENT' and r.subjectType~='GUILD') or not token(d.principal) or r.slot~=N.HideSlot(d.principal) or type(d.blocked)~='boolean'
    or not integer(d.since,0,r.issuedAt) or not authorized(d.principal) or not array(d.periods,16) then return false,'BLOCK_FIELDS' end
   local last=-1;for _,period in ipairs(d.periods) do
    if not array(period,2) or #period~=2 or not integer(period[1],0,r.issuedAt) or not integer(period[2],period[1],r.issuedAt) or period[1]<last then return false,'BLOCK_PERIOD' end
    last=period[2]
   end
  elseif k=='GEAR' or k=='TALENTS' then
   if r.subjectType~='CHARACTER' or r.slot~='current' or r.removed or not text(d.realm,80) or #d.realm==0
    or not options.identity(r.subjectType,r.subjectKey,d.realm) or not integer(d.observedAt,1,r.issuedAt)
    or r.issuedAt-d.observedAt>N.TTL or not ({INSPECT_READY=true,PLAYER_EQUIPMENT_CHANGED=true,TRAIT_CONFIG_UPDATED=true,PLAYER_LOGIN=true})[d.evidence]
    or not ({observed=true,partial=true})[d.quality] or not token(d.contentHash,64) or #d.contentHash~=64
    or not ({complete=true,partial=true,export_only=k=='TALENTS'})[d.completeness] then return false,'CURRENT_SOURCE_FIELDS' end
   if k=='GEAR' then
    if not array(d.slots,19) or #d.slots~=19 then return false,'GEAR_SLOTS' end
    for i,s in ipairs(d.slots) do
     if not array(s,3) or #s~=3 or s[1]~=i or not ({present=true,empty=true,unknown=true})[s[2]]
      or s[2]=='present' and not integer(s[3],1,1000000000) or s[2]~='present' and s[3]~=false then return false,'GEAR_SLOT' end
    end
   else
    if d.specializationID~=nil and not integer(d.specializationID,1,1000000) or d.exportString~=nil and (not text(d.exportString,2048) or #d.exportString==0)
     or not array(d.choices,64) then return false,'TALENT_FIELDS' end
    local seen={};for _,choice in ipairs(d.choices) do
     if not array(choice,6) or #choice~=6 then return false,'TALENT_CHOICE' end
     for i,v in ipairs(choice) do if not integer(v,0,1000000000) and not (i>=5 and v==false) then return false,'TALENT_RANK' end end
     local id=choice[1]..'/'..choice[2];if seen[id] then return false,'DUPLICATE_TALENT' end;seen[id]=true
    end
    if d.completeness=='export_only' and (not d.exportString or #d.choices>0) or d.completeness=='complete' and #d.choices==0 then return false,'TALENT_COMPLETENESS' end
   end
  elseif k=='BG' then
   if r.subjectType~='CHARACTER' or not token(d.observationID,96) or r.slot~=d.observationID or not text(d.mapName,80)
    or d.matchID~=nil and not token(d.matchID,96) or d.result~=nil and not ({win=true,loss=true,unknown=true})[d.result] then return false,'BG_FIELDS' end
   for _,key in ipairs({'killingBlows','deaths','damageDone','healingDone'}) do if d[key]~=nil and not integer(d[key],0,1000000000) then return false,'BG_NUMBER' end end
   if d.matchID and not (options.matchIdentity and options.matchIdentity(r,d)) then return false,'MATCH_PROOF_REQUIRED' end
   if d.result and d.result~='unknown' and not (options.matchIdentity and options.matchIdentity(r,d,true)) then return false,'TEAM_RESULT_PROOF_REQUIRED' end
  elseif k=='MEMBER' then
   if r.subjectType~='GUILD' or not guid(d.guid) or r.slot~=d.guid or not integer(d.asOf,0,now()+5)
    or not (options.memberLink and options.memberLink(r.subjectKey,d.guid,r.origin)) then return false,'MEMBERSHIP_PROOF_REQUIRED' end
  elseif k=='PRESENCE' then
   if r.subjectType~='CHARACTER' or r.slot~='presence' or d.version~=1 or not options.owns(r.origin,'CHARACTER',r.subjectKey)
    or not ({idle=true,dungeon=true,raid=true,battleground=true,arena=true,crafting=true})[d.activity] or not text(d.place,80)
    or not integer(d.observedAt,r.issuedAt-30,r.issuedAt) or not integer(d.validUntil,d.observedAt+1,d.observedAt+90)
    or not ({local_group=true,instance_observed=true,successful_craft=true,owner_declaration=true})[d.evidence]
    or d.activity=='crafting' and (d.evidence~='successful_craft' or not options.presenceProof or options.presenceProof(r)~=true)
    then return false,'PRESENCE_OWNER_SOURCE_REQUIRED' end
  elseif k=='EVENT_FACT' then
   if r.subjectType~='EVENT' or d.version~=1 or not text(d.name,80) or #d.name==0 or not text(d.realm,80) or #d.realm==0
    or not ({dungeon=true,raid=true,battleground=true,arena=true,duel=true,boss=true,guild=true,world=true})[d.activityType]
    or not token(d.runToken,96) or not token(d.sourceRef,96) or r.slot~=d.sourceRef
    or not integer(d.startAt,1,r.issuedAt) or d.endAt~=nil and not integer(d.endAt,d.startAt,r.issuedAt)
    or d.instanceID~=nil and not integer(d.instanceID,1,1000000000) or d.difficulty~=nil and not integer(d.difficulty,0,1000)
    or not ({unknown=true,partial=true,final_encounter_won=true,full_clear=true})[d.outcome] or not array(d.participants,40)
    or not (options.eventIdentity and options.eventIdentity(r)==true) then return false,'SHARED_EVENT_PROOF_REQUIRED' end
   if d.outcome=='full_clear' and not (options.eventCompletion and options.eventCompletion(r)==true) then return false,'EVENT_COMPLETE_PROOF_REQUIRED' end
   local seen={};for _,g in ipairs(d.participants) do
    if not guid(g) or seen[g] or not (options.eventParticipant and options.eventParticipant(r.subjectKey,g,r.origin,'publish')==true) then return false,'EVENT_PARTICIPANT_CONSENT_REQUIRED' end;seen[g]=true
   end
  elseif k=='EVENT_FEEDBACK' then
   if r.subjectType~='EVENT' or d.version~=1 or not guid(d.target) or r.slot~=N.HideSlot(d.target)
    or not ({helpful=true,tanking=true,healing=true,leadership=true,teamwork=true})[d.category] or not text(d.text,280)
    or not (options.eventReviewer and options.eventReviewer(r.subjectKey,r.origin,d.target)==true)
    or not (options.eventParticipant and options.eventParticipant(r.subjectKey,d.target,r.origin,'feedback')==true) then return false,'EVENT_REVIEW_PROOF_REQUIRED' end
  elseif k=='EVENT' then
   if r.subjectType~='GUILD' or not token(d.eventKey) or r.slot~=d.eventKey or not text(d.name,80)
    or not ({dungeon=true,raid=true,battleground=true})[d.activityType] or not (options.eventIdentity and options.eventIdentity(r)) then return false,'EVENT_PROOF_REQUIRED' end
  end
  return true
 end
 function c:Accept(pair,context)
  if self.recovery and self.recovery.state~='READY'then return false,'LEDGER_RECOVERING'end
  if not exact(pair,keys('wire signature')) or type(pair.wire)~='string' or #pair.wire>4096 or not token(pair.signature,4096) then return false,'SIGNED_RECORD_REQUIRED' end
  local decoded=B.DecodeChunk(pair.wire);local r=array(decoded,1) and #decoded==1 and decoded[1]
  if type(r)~='table' or not token(r.origin) or not options.verify(r.origin,pair.wire,pair.signature) then return false,'ORIGIN_SIGNATURE' end
  local archived=context=='restore-expired' or context=='restore-state' or context=='preflight-expired'
  local ok,why=validate(r,archived,context=='restore-state');if not ok then self.metrics.rejected=self.metrics.rejected+1;return false,why end
  local id=recordKey(r);local old=self.records[id]
  if ns.AetherPosts.IsKind(r.kind)then
   local valid,reason=ns.AetherPosts.BeforeAccept(self,r,context=='restore-state',old,#pair.wire+#pair.signature)
   if not valid then if reason=='POST_DEPENDENCY_MISSING'and not archived then ns.AetherPosts.Hold(self,pair)end;return false,reason end
  end
  local floor=self.floors[id]
  if floor and floor.revision>=r.revision then return false,'COMPACTED_REVISION' end
  if old and old.record.revision>r.revision then return false,'STALE_REVISION' end
  if old and old.record.revision==r.revision then
   if old.pair.wire==pair.wire then
    if options.preferProof and options.preferProof(old.pair,pair)then
     local size=#pair.wire+#pair.signature;local delta=size-old.bytes;local profileBytes=0
     for _,rows in ipairs({self.records,self.floors})do for _,row in pairs(rows)do if row.record.subjectType==r.subjectType and row.record.subjectKey==r.subjectKey then profileBytes=profileBytes+row.bytes end end end
     if self.bytes+self.floorBytes+delta>N.MAX_BYTES or profileBytes+delta>self:SubjectBytes(r.subjectType) then return false,'CACHE_BOUND'end
     local updated={};for k,v in pairs(old)do updated[k]=v end;updated.pair=pair;updated.bytes=size;updated.digest=digest(pair);self.records[id]=updated;self.bytes=self.bytes+delta;self.revision=self.revision+1
     return true,'PROOF_UPGRADED'
    end
    return true,'DUPLICATE'
   elseif old.alternate and old.alternate.wire==pair.wire then return true,'DUPLICATE'end
   local variants={old.pair,pair};if old.alternate then variants[#variants+1]=old.alternate end
   table.sort(variants,function(a,b) return a.wire<b.wire end)
   local first,second=variants[1]
   for _,variant in ipairs(variants) do if variant.wire~=first.wire then second=variant;break end end
   local size=#first.wire+#first.signature+(second and #second.wire+#second.signature or 0)
   local profileBytes=0;for _,entries in ipairs({self.records,self.floors}) do for _,entry in pairs(entries) do if entry.record.subjectType==r.subjectType and entry.record.subjectKey==r.subjectKey then profileBytes=profileBytes+entry.bytes end end end
   if self.bytes+self.floorBytes-old.bytes+size>N.MAX_BYTES or profileBytes-old.bytes+size>self:SubjectBytes(r.subjectType) then return false,'CACHE_BOUND' end
   old.conflict=true;old.pair=first;old.alternate=second;old.record=assert(B.DecodeChunk(first.wire))[1]
   self.bytes=self.bytes-old.bytes+size;old.bytes=size;old.digest=digest(first,second)
   self.revision=self.revision+1;return false,'SAME_REVISION_CONFLICT'
  end
  if old and not r.removed and not old.record.removed and (r.kind=='WALL' or r.kind==N.COMMUNITY_KIND) and old.record.data.parent~=r.data.parent then return false,'POST_PARENT_IMMUTABLE' end
  if old and not r.removed and not old.record.removed and (r.kind=='GEAR' or r.kind=='TALENTS' or r.kind=='PRESENCE') and old.record.data.observedAt>r.data.observedAt then return false,'OLDER_OBSERVATION' end
  if old and not r.removed and not old.record.removed and r.kind=='OWNER' and (r.data.policyRevision<old.record.data.policyRevision
   or (r.data.wallEnabled~=old.record.data.wallEnabled or r.data.drawingsAllowed~=old.record.data.drawingsAllowed)and r.data.policyRevision<=old.record.data.policyRevision) then return false,'WALL_POLICY_ROLLBACK' end
  if (r.kind=='WALL' or r.kind==N.COMMUNITY_KIND) and not r.removed and not archived then
   local view=self:View(r.subjectType,r.subjectKey);local block=view.blocks and view.blocks[r.origin]
   if block then
    if block.blocked then return false,'WALL_MEMBER_BLOCKED' end
    for _,period in ipairs(block.periods) do if r.issuedAt>=period[1] and r.issuedAt<=period[2] then return false,'WALL_MEMBER_BLOCKED' end end
   end
  end
  if r.data.doodle and not archived and not r.removed and(not old or old.record.data.doodle~=r.data.doodle)then
   self.drawingRates=self.drawingRates or{};self.drawingHashes=self.drawingHashes or{}
   for key,at in pairs(self.drawingRates)do if at+60<=now()then self.drawingRates[key]=nil end end
   for key,at in pairs(self.drawingHashes)do if at+300<=now()then self.drawingHashes[key]=nil end end
   local last=self.drawingRates[r.origin];local content=r.origin..'/'..N.HideSlot(r.data.doodle)
   if last and last+30>now()then return false,'DRAWING_RATE_LIMIT'end
   if self.drawingHashes[content]then return false,'REPEATED_DRAWING'end
   if count(self.drawingRates)>=128 or count(self.drawingHashes)>=512 then return false,'DRAWING_RATE_STATE_BOUND'end
  end
  local profile=subject(r.subjectType,r.subjectKey);local size=#pair.wire+#pair.signature
  local n,bytes,total=0,0,0
  if self.restoreQuota then local q=self.restoreQuota.profiles[profile];n=q and q.count or 0;bytes=q and q.bytes or 0;total=self.restoreQuota.count
  else
   for _,entries in ipairs({self.records,self.floors})do for _,row in pairs(entries)do total=total+1;if subject(row.record.subjectType,row.record.subjectKey)==profile then n=n+1;bytes=bytes+row.bytes end end end
  end
  if not old and(total>=N.MAX_RECORDS or n>=self:SubjectLimit(r.subjectType))or self.bytes+self.floorBytes-(old and old.bytes or 0)+size>N.MAX_BYTES or bytes-(old and old.bytes or 0)+size>self:SubjectBytes(r.subjectType)then return false,'CACHE_BOUND'end
  self.records[id]={record=r,pair=pair,bytes=size,digest=digest(pair),receivedAt=now()};self.bytes=self.bytes-(old and old.bytes or 0)+size
  if self.restoreQuota then local q=self.restoreQuota.profiles[profile]or{count=0,bytes=0};self.restoreQuota.profiles[profile]=q;q.count=q.count+(old and 0 or 1);q.bytes=q.bytes-(old and old.bytes or 0)+size;self.restoreQuota.count=total+(old and 0 or 1)end
  if r.data.doodle and not archived and not r.removed then self.drawingRates=self.drawingRates or{};self.drawingHashes=self.drawingHashes or{};self.drawingRates[r.origin]=now();self.drawingHashes[r.origin..'/'..N.HideSlot(r.data.doodle)]=now()end
  self.revision=self.revision+1;self.metrics.accepted=self.metrics.accepted+1
  if ns.AetherPosts.IsKind(r.kind)then ns.AetherPosts.LedgerChanged(self,self.records[id],old)end
  if ns.AetherPosts.IsKind(r.kind)and not archived then ns.AetherPosts.Accepted(self,r);if r.kind=='POST'then ns.AetherPosts.Drain(self)end end
  if context~='preflight' and context~='preflight-expired' and context~='restore-state' then
   if options.changed then options.changed(self,r,id,context or 'direct') end
   if N.Changed then N.Changed(self,r,id,context or 'direct') end
  end
  return true
 end
 function c:Publish(t,key,kind,slot,data,revision,removed,explicit)
  if self.recovery and self.recovery.state~='READY'then return false,'LEDGER_RECOVERING'end
  if not self:Joined() then return nil,'AETHER_OFF' end
  if explicit~=true then return nil,'USER_ACTION_REQUIRED' end
  data=ns.Athena.Copy(data)
  if kind=='OWNER' and not removed then
   local previous=self.records[subject(t,key)..'/OWNER/'..self.principal..'/owner'];local old=previous and previous.record
   data.policyRevision=data.policyRevision or (old and old.data.wallEnabled==data.wallEnabled and old.data.drawingsAllowed==data.drawingsAllowed and old.data.policyRevision or revision)
   data.policyAt=data.policyAt or (old and old.data.wallEnabled==data.wallEnabled and old.data.drawingsAllowed==data.drawingsAllowed and old.data.policyAt or now())
  end
  if kind=='BLOCK' then
   local old=self.records[subject(t,key)..'/BLOCK/'..self.principal..'/'..slot]
   data.since=data.blocked and now() or old and old.record.data.since or now()
   data.periods=old and ns.Athena.Copy(old.record.data.periods) or {}
   if old and old.record.data.blocked and not data.blocked then
    if #data.periods>=16 then return nil,'BLOCK_HISTORY_BOUND' end
    data.periods[#data.periods+1]={old.record.data.since,now()}
   elseif old and old.record.data.blocked and data.blocked then data.since=old.record.data.since end
  end
  local r={schema=N.SCHEMA,subjectType=t,subjectKey=key,kind=kind,origin=self.principal,slot=slot,revision=revision,
   issuedAt=now(),expiresAt=now()+(removed and N.TOMBSTONE_TTL or options.recordTTL or N.TTL),removed=removed or nil,data=data,sourceClass=options.sourceClass or 'synthetic_fixture'}
  local ok,why=validate(r);if not ok then return nil,why end
  if (kind=='WALL' or kind==N.COMMUNITY_KIND) and not removed then
   local view=self:View(t,key);local policy=view.owner
   if kind=='WALL' and (not policy or not policy.wallEnabled or data.policyRevision~=policy.policyRevision) then return nil,'LEGACY_WALL_POLICY_REQUIRED' end
   if data.parent then local parent
    for _,post in ipairs(view.wall) do if post.id==data.parent and not post.parent then parent=post end end
    if not parent then return nil,'PARENT_REQUIRED' end
   end
   if not budget('post/'..key,20) then return nil,'POST_RATE_LIMIT' end
   for _,row in pairs(self.records) do local old=row.record
    if (old.kind=='WALL' or old.kind==N.COMMUNITY_KIND) and old.origin==self.principal and old.subjectKey==key and old.slot~=slot and old.issuedAt+60>now() and old.data.text==data.text then return nil,'DUPLICATE_BODY' end
   end
  end
  if kind=='WIKI_REPORT' and not removed and not budget('wiki-report/'..key,20) then return nil,'REPORT_RATE_LIMIT' end
  local wire=B.Encode({r});local pair={wire=wire,signature=options.sign(wire)}
  local id=recordKey(r);local prior,floor=self.records[id],self.floors[id]
  local bytes,floorBytes,revision,acceptedCount=self.bytes,self.floorBytes,self.revision,self.metrics.accepted
  local accepted,reason=self:Accept(pair,'local');if not accepted then return nil,reason end
  -- Commit the existing bound ledger before attempting any propagation.
  -- Transport availability and delivery acknowledgments are not commit gates.
  if self.Save then
   local saved,why=self:Save()
   if not saved then
    self.records[id],self.floors[id]=prior,floor;self.bytes,self.floorBytes,self.revision=bytes,floorBytes,revision;self.metrics.accepted=acceptedCount
    self.saveError=why;return nil,why or 'LOCAL_LEDGER_SAVE_FAILED'
   end
   self.saveError=nil
  end
  for peer,subjects in pairs(self.listeners) do if subjects[subject(t,key)] and subjects[subject(t,key)]>now() then
   self:Send(peer,'PUSH',{subjectType=t,key=key,request='live',rows={pair}})
  end end
  return pair,recordKey(r)
 end
 local function visible(row) return not row.conflict and not row.record.removed and row.record.expiresAt>now() and authorized(row.record.origin) end
 function c:View(t,key)
  if not subject(t,key) then return nil end
  local v={subjectType=t,key=key,identity={},conflicts={},rating={count=0,scope='Known synchronized member opinions'},wall={},members={},events={},matches={},
   sourceCount=0,unresolvedObservations=0,matchLowerBound=0,reports={},scope='Partial · isolated peer simulation',claimed=false,status='LIVE_SERVICE_BLOCKED',blocks={},current={}}
  if options.sourceClass then v.scope=options.trustLabel and options.trustLabel()or 'Partial · native session-attributed reports; no durable owner proof';v.status='NATIVE_UNVERIFIED';v.trustTier='NATIVE_SESSION_ATTRIBUTED';v.rating.scope='Session-attributed opinions; account/alt uniqueness unverified' end
  local sources,identities,owners,hidden,posts,members,events,matches,unresolved,guildzones={},{},{},{},{},{},{},{},{},{}
  local sum=0;local current={GEAR={},TALENTS={},PRESENCE={}};local eventFacts={};v.feedback={};v.extensionCards={}
  for id,row in pairs(self.records) do local r=row.record;local d=r.data
   if r.subjectType==t and r.subjectKey==key then
    if row.conflict then v.conflicts[#v.conflicts+1]=id end
    if visible(row) then
     sources[r.origin]=true
     if r.kind=='IDENTITY' then
      for field,value in pairs(d) do identities[field]=identities[field] or {};identities[field][value]=true end
     elseif r.kind=='OWNER' and options.owns(r.origin,t,key) then owners[#owners+1]=r
     elseif r.kind=='GUILD_ZONE' and options.owns(r.origin,t,key) then guildzones[#guildzones+1]=r
     elseif r.kind=='PLAYER_VOTE' or r.kind=='GUILD_VOTE' then sum=sum+d.score;v.rating.count=v.rating.count+1;if options.recordStatus and options.recordStatus(row)~='AUTHENTICATED'then v.rating.pendingCount=(v.rating.pendingCount or 0)+1 end
     elseif r.kind=='HIDE' and options.owns(r.origin,t,key) then hidden[d.target]=d.hidden
     elseif r.kind=='BLOCK' and options.owns(r.origin,t,key) then v.blocks[d.principal]={blocked=d.blocked,at=r.issuedAt,since=d.since,periods=d.periods,revision=r.revision}
     elseif current[r.kind] then current[r.kind][#current[r.kind]+1]=row
     elseif r.kind=='WALL' or r.kind==N.COMMUNITY_KIND then posts[id]=r
     elseif r.kind=='WIKI_REPORT' then v.reports[#v.reports+1]={id=id,target=d.target,reason=d.reason,author=r.origin,at=r.issuedAt,revision=r.revision}
     elseif r.kind=='EVENT_FACT' then eventFacts[#eventFacts+1]=r
     elseif r.kind=='EVENT_FEEDBACK' then v.feedback[#v.feedback+1]={id=id,author=r.origin,target=d.target,category=d.category,text=d.text,at=r.issuedAt,revision=r.revision,scope='Attributable participant opinion; not a performance statistic'}
     elseif r.kind=='EXTENSION_CARD'then v.extensionCards[#v.extensionCards+1]={id=id,data=ns.Athena.Copy(d),origin=r.origin,at=r.issuedAt,expiresAt=r.expiresAt,authentication=options.recordStatus and options.recordStatus(row)or'UNVERIFIED'}
     elseif r.kind=='MEMBER' then members[d.guid]=math.max(members[d.guid] or 0,d.asOf)
     elseif r.kind=='EVENT' then events[d.eventKey]={key=d.eventKey,name=d.name,activityType=d.activityType,scope='Guild members participated'}
     elseif r.kind=='BG' then
      if d.matchID then matches[d.matchID]=matches[d.matchID] or {};matches[d.matchID][#matches[d.matchID]+1]=r
      else unresolved[r.origin]=(unresolved[r.origin] or 0)+1;v.unresolvedObservations=v.unresolvedObservations+1 end
     end
    end
   end
  end
  if t=='EVENT' then
   v.event={key=key,verified=#eventFacts>0,correlation=#eventFacts>0 and 'ATTESTED_SHARED_ID' or 'CANDIDATE',sources={},participants={},scope='Authorized shared projection; partial coverage'}
   if options.sourceClass then v.event.verified=false;v.event.correlation='SESSION_ATTRIBUTED_REPORT';v.event.scope='Observer report attributed to a native session; not independently verified common-run proof' end
   local fields={'name','realm','activityType','runToken','instanceID','difficulty','outcome'};local memberSet={}
   for _,field in ipairs(fields) do local values={};for _,record in ipairs(eventFacts) do local value=record.data[field];if value~=nil then values[tostring(value)]=value end end
    if count(values)==1 then local _,value=next(values);v.event[field]=value elseif count(values)>1 then v.conflicts[#v.conflicts+1]='event/'..field;v.event.correlation='CONFLICT';v.event.verified=false end
   end
   for _,record in ipairs(eventFacts) do local d=record.data
    v.event.startAt=math.min(v.event.startAt or d.startAt,d.startAt);if d.endAt then v.event.endAt=math.max(v.event.endAt or d.endAt,d.endAt) end
    v.event.sources[#v.event.sources+1]={author=record.origin,sourceRef=d.sourceRef,observedAt=d.endAt or d.startAt}
    for _,g in ipairs(d.participants) do memberSet[g]=true end
   end
   for g in pairs(memberSet) do v.event.participants[#v.event.participants+1]=g end;table.sort(v.event.participants)
   table.sort(v.event.sources,function(a,b) return a.author==b.author and a.sourceRef<b.sourceRef or a.author<b.author end)
   table.sort(v.feedback,function(a,b) return a.id<b.id end)
  end
  for field,values in pairs(identities) do if count(values)==1 then v.identity[field]=next(values) else v.conflicts[#v.conflicts+1]='identity/'..field end end
  if #owners==1 then local r=owners[1];v.owner={appearance=r.data.appearance and ns.Athena.Copy(r.data.appearance),authentication=options.recordStatus and options.recordStatus(self.records[recordKey(r)])or'UNVERIFIED',principal=r.origin,about=r.data.about,gamerzone=r.data.gamerzone,wallEnabled=r.data.wallEnabled,drawingsAllowed=r.data.drawingsAllowed,revision=r.revision,at=r.issuedAt,policyRevision=r.data.policyRevision,policyAt=r.data.policyAt};v.claimed=true
  elseif #owners>1 then v.conflicts[#v.conflicts+1]='owner' end
  if #guildzones==1 then v.guildzone=guildzones[1].data.guildzone;v.claimed=true elseif #guildzones>1 then v.conflicts[#v.conflicts+1]='guild-owner' end
  if v.rating.count>0 then v.rating.average=sum/v.rating.count end
  v.rating.maximum=t=='GUILD' and 10 or 5
  do
   local eligible={}
   for id,r in pairs(posts) do local block=v.blocks[r.origin]
    local blocked=block and block.blocked and r.issuedAt>=block.since
    for _,period in ipairs(block and block.periods or {}) do if r.issuedAt>=period[1] and r.issuedAt<=period[2] then blocked=true end end
    local policy=r.kind==N.COMMUNITY_KIND or v.owner and v.owner.wallEnabled and r.data.policyRevision==v.owner.policyRevision and r.issuedAt>=v.owner.policyAt
    if not hidden[id] and policy
     and not blocked then eligible[id]=r end
   end
   for id,r in pairs(eligible) do local parent=r.data.parent;local p=parent and eligible[parent]
    if not parent or p and not p.data.parent then
     local a=authorized(r.origin);v.wall[#v.wall+1]={authentication=options.recordStatus and options.recordStatus(self.records[id]),id=id,kind=r.kind,legacy=r.kind=='WALL',author=r.origin,authorName=a and a.name or r.origin,text=r.data.text,doodle=r.data.doodle,parent=parent,revision=r.revision,at=r.issuedAt}
    end
   end
  end
  for kind,rows in pairs(current) do
   table.sort(rows,function(a,b) if a.record.data.observedAt~=b.record.data.observedAt then return a.record.data.observedAt>b.record.data.observedAt end;return a.record.origin<b.record.origin end)
   local first=rows[1]
   if first then
    local d=first.record.data;local conflict=false;local origins={}
    local function valueWire(v)
     if kind=='PRESENCE' then return B.Encode({activity=v.activity,place=v.place,validUntil=v.validUntil,evidence=v.evidence}) end
     return B.Encode(kind=='GEAR' and {slots=v.slots} or {specializationID=v.specializationID,exportString=v.exportString,choices=v.choices})
    end
    local content=valueWire(d)
    for _,entry in ipairs(rows) do if entry.record.data.observedAt==d.observedAt then
     if entry.record.data.contentHash~=d.contentHash or valueWire(entry.record.data)~=content then conflict=true end;origins[#origins+1]=entry.record.origin
    end end
    local state=conflict and 'Conflict' or kind=='PRESENCE' and (d.validUntil<=now() and 'Expired' or 'Fresh') or now()-d.observedAt>86400 and 'Stale' or d.completeness~='complete' and 'Partial' or 'Latest known'
    table.sort(origins);v.current[kind]={state=state,value=not conflict and ns.Athena.Copy(d) or nil,observedAt=d.observedAt,receivedAt=first.receivedAt,origin=first.record.origin,sources=origins,expiresAt=kind=='PRESENCE' and d.validUntil or first.record.expiresAt}
   end
  end
  table.sort(v.wall,function(a,b) return a.at==b.at and a.id<b.id or a.at>b.at end)
  for key,rows in pairs(matches) do
   local match={key=key,sources=count(rows),metrics={},conflicts={}}
   for _,field in ipairs({'mapName','result','killingBlows','deaths','damageDone','healingDone'}) do
    local values={};for _,r in ipairs(rows) do if r.data[field]~=nil then values[tostring(r.data[field])]=r.data[field] end end
    if count(values)==1 then local _,value=next(values);match.metrics[field]=value elseif count(values)>1 then match.conflicts[#match.conflicts+1]=field end
   end
   v.matches[#v.matches+1]=match
  end
  for guid,at in pairs(members) do v.members[#v.members+1]={key=guid,asOf=at,scope='Observed member; current roster unknown'} end
  for _,e in pairs(events) do v.events[#v.events+1]=e end
  for _ in pairs(sources) do v.sourceCount=v.sourceCount+1 end
  for _,n in pairs(unresolved) do v.matchLowerBound=math.max(v.matchLowerBound,n) end
  v.matchLowerBound=math.max(v.matchLowerBound,#v.matches)
  for _,list in ipairs({v.members,v.events,v.matches}) do table.sort(list,function(a,b) return a.key<b.key end) end
  table.sort(v.conflicts)
  return v
 end
 function c:Manifest(t,key,offset,peer)
  local rows={};for id,row in pairs(self.records) do local r=row.record
   if r.subjectType==t and r.subjectKey==key and self:Wanted(t,key)and r.expiresAt>now() and (not options.canRelay or options.canRelay(row,peer)) then rows[#rows+1]={id=id,revision=r.revision,digest=row.digest,conflict=row.conflict or false} end
  end
  for id,row in pairs(self.floors) do local decoded=B.DecodeChunk(row.pair.wire);local r=decoded and decoded[1]
   if r and r.subjectType==t and r.subjectKey==key and self:Wanted(t,key)and (not options.canRelay or options.canRelay(row,peer)) then rows[#rows+1]={id=id,revision=r.revision,digest=digest(row.pair,row.alternate),conflict=row.alternate~=nil} end
  end
  table.sort(rows,function(a,b) return a.id<b.id end)
  local out={};offset=offset or 0
  for i=offset+1,math.min(#rows,offset+batch) do out[#out+1]=rows[i] end
  return out,offset+batch<#rows and offset+batch or nil
 end
 function c:Send(peer,kind,body)
  if not self:Joined() or not authorized(peer) then return false,'AETHER_OFF_OR_PEER' end
  if type(options.send)~='function' then return false,'LIVE_SERVICE_BLOCKED' end
  if not budget('out',240) then return false,'SEND_RATE_LIMIT' end
  self.sequence=self.sequence+1
  local packet={protocol='AETHER_NET_5',kind=kind,sender=options.envelopePrincipal or self.principal,recipient=peer,id=self.session..'-'..self.sequence,at=now(),body=body}
  local wire=B.Encode({packet});if #wire>N.MAX_WIRE then return false,'WIRE_BOUND' end
  local outer=B.Encode({{wire=wire,signature=options.sign(wire)}});if #outer>N.MAX_WIRE then return false,'WIRE_BOUND' end
  self.metrics.bytesOut=self.metrics.bytesOut+#outer;return options.send(peer,outer)==true
 end
 -- Optional inventory extension of the existing signed session protocol. It
 -- advertises only relay-eligible public subjects; original record validation
 -- still runs on every DELTA. Older peers never receive this extension unless
 -- their transport advertises I1 support.
 function c:Inventory(peer)
  local roomPeer=not peer or options.roomPeer and options.roomPeer(peer);local stamp=tostring(self.revision)..'/'..math.floor(now()/30)..'/'..tostring(roomPeer)..'/'..tostring(peer)
  if self.inventoryCache and self.inventoryCache.stamp==stamp then return self.inventoryCache end
  local groups={}
  for _,entries in ipairs({self.records,self.floors}) do for id,row in pairs(entries) do
   if options.checkpoint then options.checkpoint()end
   local r=row.record or (B.DecodeChunk(row.pair.wire) or {})[1]
   if r and(r.subjectType~='ROOM'or roomPeer)and self:Wanted(r.subjectType,r.subjectKey)and (entries==self.floors or r.expiresAt>now()) and (not options.canRelay or options.canRelay(row,peer)) then
    local key=subject(r.subjectType,r.subjectKey);local g=groups[key]
    if not g then g={t=r.subjectType,key=r.subjectKey,at=r.issuedAt,parts={}};groups[key]=g end
    g.at=math.max(g.at,r.issuedAt);g.parts[#g.parts+1]=id..'/'..r.revision..'/'..(row.digest or digest(row.pair,row.alternate))
   end
  end end
  local rows,parts={},{}
  for key,g in pairs(groups) do table.sort(g.parts);g.digest=ns.PackCrypto.Hex(ns.PackCrypto.SHA256(table.concat(g.parts,'\n')));g.parts=nil;rows[#rows+1]=g;parts[#parts+1]=key..'/'..g.digest end
  table.sort(parts);table.sort(rows,function(x,y)if x.at~=y.at then return x.at>y.at end;return x.t..x.key<y.t..y.key end)
  self.inventoryCache={stamp=stamp,rows=rows,digest=ns.PackCrypto.Hex(ns.PackCrypto.SHA256(table.concat(parts,'\n')))};return self.inventoryCache
 end
 function c:Reconcile(peer)
  if not self:Joined() or not options.inventoryPeer or not options.inventoryPeer(peer) or not authorized(peer) then return false,'INVENTORY_PEER_REQUIRED' end
  self.inventories=self.inventories or {};local old=self.inventories[peer]
  if old and old.expires>now() then return false,'INVENTORY_BUSY' end
  if count(self.inventories)>=N.CONCURRENCY and not old then return false,'INVENTORY_BOUND' end
  local request=self.session..'-i-'..tostring(self.sequence+1)
  self.inventories[peer]={request=request,offset=0,expires=now()+180,waiting=true}
  if not self:Send(peer,'INVENTORY_QUERY',{offset=0,request=request}) then self.inventories[peer]=nil;return false,'INVENTORY_BACKPRESSURE' end
  return true
 end
 function c:Refresh(t,key,onlyPeer)
  if not self:Joined() then return false,'AETHER_OFF' end
  if not subject(t,key) or not options.identity(t,key) then return false,'EXACT_IDENTITY_REQUIRED' end
  if not self:Wanted(t,key)then return false,'ROOM_NOT_SUBSCRIBED'end
  if #self.outbox+count(self.pending)>=N.MAX_PEERS then return false,'QUERY_QUEUE_BOUND' end
  for id,at in pairs(self.queries) do if at+60<=now() then self.queries[id]=nil;self.coverage[id]=nil end end
  if count(self.queries)>=64 then return false,'QUERY_CACHE_BOUND' end
  local id=subject(t,key);if self.queries[id] and self.queries[id]+10>now() then return false,'QUERY_COOLDOWN' end
  self.interests[id]=now()+120
  local peers=options.directory and options.directory() or {};self.queries[id]=now()
  local cover={queried=0,responses=0,unavailable=0,at=now(),state='Partial'};self.coverage[id]=cover
  local selected={}
  for _,peer in ipairs(peers) do if not selected[peer] and cover.queried<N.MAX_PEERS and #self.outbox+count(self.pending)<N.MAX_PEERS and peer~=self.principal and authorized(peer) then
   if(not onlyPeer or peer==onlyPeer)and(t~='ROOM'or options.roomPeer and options.roomPeer(peer))then selected[peer]=true
   cover.queried=cover.queried+1;self.outbox[#self.outbox+1]={peer=peer,t=t,key=key,cover=cover}
   end
  end end
  self:Pump();return true
 end
 function c:Pump()
  self:Compact()
  for peer,q in pairs(self.inventories or {}) do
   if q.expires<=now() then self.inventories[peer]=nil
   elseif not q.waiting and #self.outbox+count(self.pending)<2 and count(self.expected)<2 then
    local todo=q.todo and q.todo[1]
    if todo and (not q.retryAt or q.retryAt<=now()) then
     local ok,why=self:Refresh(todo.t,todo.key,peer)
     if ok then table.remove(q.todo,1);q.retryAt=nil else q.retryAt=now()+(why=='QUERY_COOLDOWN' and 10 or 5) end
    elseif not todo and q.next==nil then self.inventories[peer]=nil
    elseif not todo then
     q.waiting=true;q.offset=q.next;q.expires=now()+180
     if not self:Send(peer,'INVENTORY_QUERY',{offset=q.offset,request=q.request}) then self.inventories[peer]=nil end
    end
   end
  end
  for id,at in pairs(self.seen) do if at<=now() then self.seen[id]=nil end end
  for id,p in pairs(self.expected) do if p.expires<=now() then self.expected[id]=nil end end
  for id,p in pairs(self.pending) do if p.expires<=now() then p.cover.unavailable=p.cover.unavailable+1;self.pending[id]=nil end end
  for peer,subjects in pairs(self.listeners) do for id,at in pairs(subjects) do if at<=now() then subjects[id]=nil end end;if not next(subjects) then self.listeners[peer]=nil end end
  for id,at in pairs(self.interests) do if at<=now() then self.interests[id]=nil end end
  while #self.outbox>0 and count(self.pending)<N.CONCURRENCY do
   local q=table.remove(self.outbox,1);local id=q.peer..'/'..subject(q.t,q.key)
   local request=self.session..'-q-'..tostring(self.sequence+1)
   self.pending[id]={cover=q.cover,expires=now()+(options.queryTimeout or 15),t=q.t,key=q.key,request=request}
   if not self:Send(q.peer,'LOOKUP',{subjectType=q.t,key=q.key,offset=0,request=request}) then self.pending[id]=nil;q.cover.unavailable=q.cover.unavailable+1 end
  end
 end
 function c:Receive(peer,wire)
  if self.recovery and self.recovery.state~='READY'then return false,'LEDGER_RECOVERING'end
  if not self:Joined() or not authorized(peer) then return false,'AETHER_OFF_OR_PEER' end
  if type(wire)~='string' or #wire>N.MAX_WIRE or not budget('in/'..peer,120) then return false,'WIRE_OR_RATE_BOUND' end
  local outer=B.DecodeChunk(wire);local signed=array(outer,1) and #outer==1 and outer[1]
  if not exact(signed,keys('wire signature')) or type(signed.wire)~='string' or not token(signed.signature,256) or not options.verify(peer,signed.wire,signed.signature) then return false,'PEER_SIGNATURE' end
  local rows=B.DecodeChunk(signed.wire);local p=array(rows,1) and #rows==1 and rows[1]
  if not exact(p,keys('protocol kind sender recipient id at body')) or p.protocol~='AETHER_NET_5' or p.sender~=peer or p.recipient~=(options.envelopePrincipal or self.principal)
   or not token(p.id) or not integer(p.at,now()-(options.packetTTL or 30),now()+5) or type(p.body)~='table' then return false,'PACKET_POLICY' end
  local packetID=peer..'/'..p.id
  if self.seen[packetID] then return true,'DUPLICATE_PACKET' end
  if count(self.seen)>=4096 then return false,'REPLAY_CACHE_BOUND' end
  self.seen[packetID]=now()+math.max(60,(options.packetTTL or 30)+30)
  local b=p.body
  if p.kind:match('^ENROLLMENT_')then if options.control then return options.control(peer,p.kind,b)end;return false,'ENROLLMENT_UNSUPPORTED'end
  if p.kind=='INVENTORY_QUERY' or p.kind=='INVENTORY' then
   if not options.inventoryPeer or not options.inventoryPeer(peer) or not exact(b,keys('offset request rows next digest')) or not token(b.request) or not integer(b.offset,0,N.MAX_RECORDS) then return false,'INVENTORY_POLICY' end
   if p.kind=='INVENTORY_QUERY' then
    local inventory=self:Inventory(peer);local page={}
    for i=b.offset+1,math.min(#inventory.rows,b.offset+4) do page[#page+1]=inventory.rows[i] end
    return self:Send(peer,'INVENTORY',{request=b.request,offset=b.offset,rows=page,next=b.offset+4<#inventory.rows and b.offset+4 or nil,digest=inventory.digest})
   end
   local q=self.inventories and self.inventories[peer]
   if not q or not q.waiting or q.request~=b.request or q.offset~=b.offset or not array(b.rows,4) or not token(b.digest,64) or #b.digest~=64
    or b.next~=nil and (b.next~=b.offset+4 or b.next>N.MAX_RECORDS) then return false,'UNSOLICITED_INVENTORY' end
   -- Validate the entire small page before creating any lookup work.
   for _,r in ipairs(b.rows) do
    if not exact(r,keys('t key at digest')) or not subject(r.t,r.key) or not options.identity(r.t,r.key) or not integer(r.at,1,now()+5) or not token(r.digest,64) or #r.digest~=64 then return false,'INVENTORY_FIELDS' end
   end
   local localGroups={};for _,r in ipairs(self:Inventory(peer).rows) do localGroups[subject(r.t,r.key)]=r.digest end
   q.todo={};for _,r in ipairs(b.rows) do if self:Wanted(r.t,r.key)and(r.t~='ROOM'or options.roomPeer and options.roomPeer(peer))and localGroups[subject(r.t,r.key)]~=r.digest then q.todo[#q.todo+1]={t=r.t,key=r.key} end end
   q.waiting=false;q.next=b.next;q.expires=now()+180;return true
  end
  if not exact(b,keys('subjectType key offset rows next ids request')) or not token(b.request) or not subject(b.subjectType,b.key) or not options.identity(b.subjectType,b.key) then return false,'SUBJECT_POLICY' end
  self.metrics.bytesIn=self.metrics.bytesIn+#wire
  if p.kind=='LOOKUP' then
   if not self:Wanted(b.subjectType,b.key)then return false,'ROOM_NOT_SUBSCRIBED'end
   if not integer(b.offset,0,self:SubjectLimit(b.subjectType)) then return false,'CURSOR' end
   if not self.listeners[peer] and count(self.listeners)>=N.MAX_PEERS then return false,'LISTENER_BOUND' end
   self.listeners[peer]=self.listeners[peer] or {};local subjects=self.listeners[peer]
   if not subjects[subject(b.subjectType,b.key)] and count(subjects)>=64 then return false,'LISTENER_SUBJECT_BOUND' end
   subjects[subject(b.subjectType,b.key)]=now()+120
   local manifest,nextOffset=self:Manifest(b.subjectType,b.key,b.offset,peer)
   local sent=self:Send(peer,'MANIFEST',{subjectType=b.subjectType,key=b.key,rows=manifest,next=nextOffset,request=b.request})
   -- The same bounded lookup protocol can reconcile in both directions. A
   -- peer need not already know the subject of a locally authored publication.
   local query=subject(b.subjectType,b.key)
   if options.reciprocal and (not options.inventoryPeer or not options.inventoryPeer(peer)) and (not self.queries[query] or self.queries[query]+60<=now()) then self:Refresh(b.subjectType,b.key,peer) end
   return sent
  elseif p.kind=='MANIFEST' then
   local pending=self.pending[peer..'/'..subject(b.subjectType,b.key)]
   if not pending or pending.request~=b.request or not array(b.rows,batch) then return false,'UNSOLICITED_MANIFEST' end
   local ids={}
   for _,entry in ipairs(b.rows) do
    if not exact(entry,keys('id revision digest conflict')) or not token(entry.id,384) or not integer(entry.revision,1,1000000000) or not token(entry.digest,64) or #entry.digest~=64 then return false,'MANIFEST_FIELDS' end
    local old=self.records[entry.id];local floor=self.floors[entry.id]
    if not old and floor then old={record={revision=floor.revision},digest=digest(floor.pair,floor.alternate)} end
    if not old or old.record.revision<entry.revision or old.record.revision==entry.revision and old.digest~=entry.digest then ids[#ids+1]=entry.id end
   end
   if #ids>0 then
    local expectedID=peer..'/'..subject(b.subjectType,b.key);local expected=self.expected[expectedID]
    if not expected or expected.request~=b.request then expected={ids={},expires=now()+(options.queryTimeout or 30),request=b.request};self.expected[expectedID]=expected end
    for _,id in ipairs(ids) do expected.ids[id]=true end
    self:Send(peer,'GET',{subjectType=b.subjectType,key=b.key,ids=ids,request=b.request})
   end
   if b.next~=nil then if not integer(b.next,1,self:SubjectLimit(b.subjectType)) then return false,'CURSOR' end;self:Send(peer,'LOOKUP',{subjectType=b.subjectType,key=b.key,offset=b.next,request=b.request})
   else pending.cover.responses=pending.cover.responses+1;self.pending[peer..'/'..subject(b.subjectType,b.key)]=nil;self:Pump() end
   return true
  elseif p.kind=='GET' then
   if not array(b.ids,batch) then return false,'DELTA_BOUND' end
   local deltas={};for _,id in ipairs(b.ids) do local row=self.records[id] or self.floors[id]
    local r=row and (row.record or B.DecodeChunk(row.pair.wire)[1])
    if type(id)~='string' or row and (r.subjectType~=b.subjectType or r.subjectKey~=b.key) then return false,'SUBJECT_MISMATCH' end
    if row and (not options.canRelay or options.canRelay(row,peer)) then deltas[#deltas+1]=row.pair;if row.alternate then deltas[#deltas+1]=row.alternate end end
   end
   for i=1,#deltas,batch do local entries={};for j=i,math.min(#deltas,i+batch-1) do entries[#entries+1]=deltas[j]end;self:Send(peer,'DELTA',{subjectType=b.subjectType,key=b.key,rows=entries,request=b.request})end
   return true
  elseif p.kind=='DELTA' or p.kind=='PUSH' then
   local expected=self.expected[peer..'/'..subject(b.subjectType,b.key)]
   local live=p.kind=='PUSH' and b.request=='live' and self.interests[subject(b.subjectType,b.key)] and self.interests[subject(b.subjectType,b.key)]>now()
   if not live and (not expected or expected.request~=b.request) or not array(b.rows,batch) then return false,'UNSOLICITED_DELTA' end
   -- Stage the bounded packet before committing any row. A malformed later
   -- row must not partly replace a valid public ledger or raise a notice.
   local staged=assert(build(options));for id,row in pairs(self.records) do staged.records[id]=row end;for id,row in pairs(self.floors) do staged.floors[id]=row end;staged.bytes=self.bytes;staged.floorBytes=self.floorBytes
   for _,pair in ipairs(b.rows) do
    if not exact(pair,keys('wire signature')) or type(pair.wire)~='string' or #pair.wire>4096 or not token(pair.signature,4096) then return false,'SIGNED_RECORD_REQUIRED' end
    local decoded=B.DecodeChunk(pair.wire);local r=array(decoded,1) and #decoded==1 and decoded[1]
    if type(r)~='table' or not shapes[r.kind] or not subject(r.subjectType,r.subjectKey) or not token(r.origin) or not token(r.slot,96)
     or r.subjectType~=b.subjectType or r.subjectKey~=b.key or not live and not expected.ids[recordKey(r)] then return false,'SUBJECT_MISMATCH' end
    local id=recordKey(r);if staged.records[id] and staged.records[id]==self.records[id] then staged.records[id]=ns.Athena.Copy(staged.records[id]) end
    local accepted,why=staged:Accept(pair,live and 'preflight' or 'preflight-expired')
    if not accepted and why~='SAME_REVISION_CONFLICT' and why~='STALE_REVISION' and why~='COMPACTED_REVISION' and why~='WALL_MEMBER_BLOCKED' and why~='OLDER_OBSERVATION'and why~='POST_DEPENDENCY_MISSING'and why~='UPVOTE_REVISION_OR_VISIBILITY'and why~='POST_REMOVED' then return false,why end
   end
   for _,pair in ipairs(b.rows) do self:Accept(pair,live and 'live' or 'restore-expired') end
   self:Compact();return true
  end
  return false,'PROTOCOL_KIND'
 end
 function c:Cancel(t,key)
  local subjectID=subject(t,key);if not subjectID then return false end
  self.interests[subjectID]=nil
  for id,p in pairs(self.pending) do if p.t==t and p.key==key then self.pending[id]=nil end end
  for id in pairs(self.expected) do if id:sub(-#subjectID)==subjectID then self.expected[id]=nil end end
  for i=#self.outbox,1,-1 do local q=self.outbox[i];if q.t==t and q.key==key then table.remove(self.outbox,i) end end
  if self.coverage[subjectID] then self.coverage[subjectID].state='Canceled · Partial' end;return true
 end
 function c:Compact()
  local at=now()
  if self.compactRevision==self.revision and self.compactRecords==self.records and self.compactFloors==self.floors and at<(self.compactDue or 0)then return true end
  local due=math.huge
  for id,row in pairs(self.records) do if options.checkpoint then options.checkpoint()end;if row.record.expiresAt<=at then
   if count(self.floors)>=N.MAX_RECORDS then return false,'FLOOR_CAPACITY' end
   self.floors[id]={revision=row.record.revision,record=row.record,pair=row.pair,alternate=row.alternate,bytes=row.bytes};self.floorBytes=self.floorBytes+row.bytes;self.records[id]=nil;self.bytes=self.bytes-row.bytes;self.revision=self.revision+1
  else due=math.min(due,row.record.expiresAt)end end
  for id,floor in pairs(self.floors) do
   if options.checkpoint then options.checkpoint()end
   local r=floor.record;if not r then local decoded=B.DecodeChunk(floor.pair.wire);r=decoded and decoded[1]end
   -- Revocation evidence protects persistent issuer grants too. Retain it;
   -- expiry must never silently re-authorize a previously revoked key.
   if r and r.kind~='KEY_REVOCATION'then
    local expires=r.issuedAt+N.TTL+N.TOMBSTONE_TTL+1
    if expires<=at then self.floorBytes=self.floorBytes-floor.bytes;self.floors[id]=nil;self.revision=self.revision+1
    else due=math.min(due,expires)end
   end
  end
  self.compactRevision,self.compactDue,self.compactRecords,self.compactFloors=self.revision,due,self.records,self.floors
  return true
 end
 function c:Snapshot()
  local rows={};for id,row in pairs(self.records) do rows[#rows+1]={id=id,pair=row.pair,alternate=row.alternate,receivedAt=row.receivedAt} end
  table.sort(rows,function(a,b) return a.id<b.id end)
  local floors={};for id,row in pairs(self.floors) do floors[#floors+1]={id=id,pair=row.pair,alternate=row.alternate} end;table.sort(floors,function(a,b) return a.id<b.id end)
  return ns.Athena.Copy({schema=2,consent=N.CONSENT,principal=self.principal,sequence=self.sequence,records=rows,floors=floors})
 end
 local function monotonic()return ns.WardenPerformance and ns.WardenPerformance.Now()or os and os.clock and os.clock()*1000 or 0 end
 function c:RecoveryStatus()
  local j=self.recovery;return j and{state=j.state,phase=j.phase,scheduled=j.scheduled==true,processed=j.processed,total=j.total,maxSliceMS=j.maxSliceMS,cpuMS=j.cpuMS,reason=j.reason,retries=j.retries or 0}or{state='READY',phase='COMPLETED'}
 end
 function c:RecoveryStep(budget)
  local j=self.recovery;if not j or j.state~='RECOVERING'or j.running or self.privacyDetached then return true end
  j.running=true;j.phase='ACTIVE'
  local begin=monotonic();j.deadline=begin+math.max(.25,math.min(4,budget or 2));j.units=0
  if options.recoveryResume then options.recoveryResume()end
  if ns.AetherCrypto and ns.AetherCrypto.RecoveryBudget then ns.AetherCrypto.RecoveryBudget(j.thread,j.deadline)end
  ns.PackCrypto.RecoveryBudget(j.thread,j.deadline)
  local resumed,accepted,why=coroutine.resume(j.thread)
  j.running=nil
  ns.PackCrypto.RecoveryBudget(j.thread,nil)
  if ns.AetherCrypto and ns.AetherCrypto.RecoveryBudget then ns.AetherCrypto.RecoveryBudget(j.thread,nil)end
  if options.recoveryPause then options.recoveryPause()end
  local elapsed=monotonic()-begin;j.maxSliceMS=math.max(j.maxSliceMS,elapsed);j.cpuMS=j.cpuMS+elapsed
  if not resumed or coroutine.status(j.thread)=='dead'and accepted~=true then
   j.state='RECOVERY_REQUIRED';j.phase='FAILED';j.scheduled=false;N.recoveries[self]=nil;j.reason=tostring(resumed and why or accepted):sub(1,180);if options.recoveryAbort then options.recoveryAbort()end;return true
  elseif coroutine.status(j.thread)=='dead'then
   j.state='READY';j.phase='COMPLETED';j.scheduled=false;N.recoveries[self]=nil;j.thread=nil;j.snapshot=nil;if options.recoveryComplete then options.recoveryComplete()end;return true
  end
  return false
 end
 function c:ScheduleRecovery(force)
  local j=self.recovery;if not j or self.privacyDetached or j.state~='RECOVERING'and j.state~='PAUSED'then return false,'RECOVERY_NOT_PENDING'end
  if j.scheduled then return true,'RECOVERY_QUEUED'end
  if j.manualPause then return false,'RECOVERY_PAUSED'end
  if not force and monotonic()<(j.retryAt or 0)then return false,'RECOVERY_RETRY_WAIT'end
  if not ns.WardenScheduler then j.state='RECOVERING';j.phase='MANUAL';return true,'RECOVERY_PENDING_MANUAL'end
  local function canceled()
   if self.recovery~=j or j.state=='READY'or j.state=='CANCELLED'or j.state=='PRIVACY_ERASED'then return end
   j.scheduled=false;j.state='PAUSED';j.phase=j.manualPause and'PAUSED'or'WAITING_CAPACITY';j.reason='SCHEDULER_CANCELLED';j.retryAt=monotonic()+1000
   if N.WakeMaintenance then N.WakeMaintenance()end
  end
  local ok,why=ns.WardenScheduler.Submit('aether-restore/'..self.principal,'low',function()
   if self.recovery~=j or self.privacyDetached then return true end
   return self:RecoveryStep()
  end,{onCancel=canceled})
  j.retries=(j.retries or 0)+1
  if ok then j.state='RECOVERING';j.phase='QUEUED';j.scheduled=true;j.reason=nil;return true,'RECOVERY_QUEUED'end
  j.scheduled=false;j.state='PAUSED';j.phase='WAITING_CAPACITY';j.reason=why or'SCHEDULER_REJECTED';j.retryAt=monotonic()+1000
  if N.WakeMaintenance then N.WakeMaintenance()end
  return false,'RECOVERY_WAITING_CAPACITY'
 end
 function c:ResumeRecovery()
  local j=self.recovery;if not j or j.state~='PAUSED'then return false end;j.manualPause=nil
  return self:ScheduleRecovery(true)
 end
 function c:PauseRecovery()
  if not self.recovery or self.recovery.state~='RECOVERING'then return false end
  self.recovery.manualPause=true;self.recovery.state='PAUSED';self.recovery.phase='PAUSED';self.recovery.scheduled=false;if ns.WardenScheduler then ns.WardenScheduler.Cancel('aether-restore/'..self.principal)end;return true
 end
 function c:CancelRecovery(reason)
  local j=self.recovery;if not j or j.state=='READY'then return false end
  j.state=reason=='privacy'and'PRIVACY_ERASED'or'CANCELLED';j.phase='CANCELLED';j.reason=reason or'EXPLICIT_CANCEL';j.scheduled=false;j.thread=nil;j.snapshot=nil;N.recoveries[self]=nil
  if ns.WardenScheduler then ns.WardenScheduler.Cancel('aether-restore/'..self.principal)end
  if options.recoveryAbort then options.recoveryAbort()end;return true
 end
 function c:BeginRestore(snapshot)
  if self.recovery and self.recovery.state~='READY'then return false,'RECOVERY_ALREADY_ACTIVE'end
  for other in pairs(N.recoveries)do if other~=self and other.principal==self.principal then return false,'RECOVERY_ALREADY_ACTIVE'end end
  if count(N.recoveries)>=64 then return false,'RECOVERY_CAPACITY'end
  local j={state='RECOVERING',snapshot=snapshot,processed=0,total=type(snapshot)=='table'and type(snapshot.records)=='table'and #snapshot.records+(type(snapshot.floors)=='table'and #snapshot.floors or 0)or 0,maxSliceMS=0,cpuMS=0};self.recovery=j
  local function checkpoint()j.processed=j.processed+1;j.units=j.units+1;if j.units>=8 or monotonic()>=j.deadline then coroutine.yield()end end
  j.thread=coroutine.create(function()return self:Restore(snapshot,checkpoint)end)
  N.recoveries[self]=j;local ok,why=self:ScheduleRecovery(true)
  if N.WakeMaintenance then N.WakeMaintenance()end
  return true,why -- Accepted request does not falsely assert scheduler admission.
 end
 function c:Restore(snapshot,checkpoint)
  if not exact(snapshot,keys('schema consent principal sequence records floors')) or snapshot.schema~=2 or (snapshot.consent~=5 and snapshot.consent~=6 and snapshot.consent~=N.CONSENT) or snapshot.principal~=self.principal
   or not integer(snapshot.sequence,0,1000000000) or not array(snapshot.records,N.MAX_RECORDS) or not array(snapshot.floors,N.MAX_RECORDS) or #snapshot.records+#snapshot.floors>N.MAX_RECORDS then return false,'SNAPSHOT_SCHEMA' end
  local staged=assert(build(options));staged.restoreQuota={count=0,profiles={}}
  for _,row in ipairs(snapshot.records) do
   if type(row)~='table'then return false,'SNAPSHOT_FIELDS'end
   if staged.records[row.id]then return false,'DUPLICATE_SNAPSHOT_ID'end
   if not exact(row,keys('id pair alternate receivedAt')) or not integer(row.receivedAt,1,now()+5) then return false,'SNAPSHOT_FIELDS' end
   local ok,why=staged:Accept(row.pair,'restore-state');if not ok then return false,why end
   if not staged.records[row.id] then return false,'SNAPSHOT_ID' end
   staged.records[row.id].receivedAt=row.receivedAt
   if row.alternate then staged.restoreQuota=nil;local valid=staged:Accept(row.alternate,'restore-state');if valid or not staged.records[row.id].conflict then return false,'CONFLICT_PROOF_REQUIRED'end end
   if checkpoint then checkpoint()end
  end
  for _,row in ipairs(snapshot.floors) do
   if not exact(row,keys('id pair alternate')) or staged.records[row.id] then return false,'FLOOR_FIELDS' end
   local ok,why=staged:Accept(row.pair,'restore-state');if not ok then return false,why end
   local entry=staged.records[row.id];if not entry or entry.record.expiresAt>now() then return false,'FLOOR_ID' end
   if row.alternate then staged.restoreQuota=nil;local valid=staged:Accept(row.alternate,'restore-state');if valid or not entry.conflict then return false,'FLOOR_CONFLICT'end end
   if checkpoint then checkpoint()end
  end
  for id,row in pairs(staged.records)do if row.record.expiresAt<=now()then staged.floors[id]={revision=row.record.revision,record=row.record,pair=row.pair,alternate=row.alternate,bytes=row.bytes};staged.floorBytes=staged.floorBytes+row.bytes;staged.records[id]=nil;staged.bytes=staged.bytes-row.bytes end;if checkpoint then checkpoint()end end
  for id,row in pairs(staged.floors)do if row.record.kind~='KEY_REVOCATION'and row.record.issuedAt+N.TTL+N.TOMBSTONE_TTL<now()then staged.floorBytes=staged.floorBytes-row.bytes;staged.floors[id]=nil end;if checkpoint then checkpoint()end end
  self:Leave();self.queries={};self.coverage={};self.seen={}
  local prepared;if self.BuildSaveView then prepared=self:BuildSaveView(checkpoint,staged.records,staged.floors,self.revision+1,math.max(self.sequence,snapshot.sequence))end
  self.records=staged.records;self.floors=staged.floors;self.bytes=staged.bytes;self.floorBytes=staged.floorBytes;self.sequence=math.max(self.sequence,snapshot.sequence);self.revision=self.revision+1;if prepared then prepared.sequence=self.sequence;prepared.snapshot.sequence=self.sequence;self.snapshotView=prepared end;return true
 end
 return c
end
-- One durable public ledger namespace in the existing Exchange saved file.
-- No consent or authority callbacks/keys are persisted. Invalid/older saves are
-- held unchanged for recovery; restoring never enrolls a client.
function N.Bind(c,owner,storage)
 if not c or not guid(owner) then return false,'EXACT_LOCAL_OWNER_REQUIRED' end
 if c.saved then return false,'ALREADY_BOUND' end
 if storage==nil then
  if ns.Storage.OlympusWardenExchangeDB==nil then ns.Storage.OlympusWardenExchangeDB={schema=1,characters={}} end
  storage=ns.Storage.OlympusWardenExchangeDB
 end
 if type(storage)~='table' or storage.schema~=1 or type(storage.characters)~='table' then return false,'SAVE_ROOT_RECOVERY' end
 local root=storage.netClients
 if root and (not exact(root,keys('schema owners')) or root.schema~=2 or type(root.owners)~='table' or count(root.owners)>4) then return false,'NET_SAVE_RECOVERY' end
 local old=root and root.owners[owner]
 if old then local ok,why=c:BeginRestore(old);if not ok then return false,why end end
 c.saved={owner=owner,storage=storage}

 local rowCache=setmetatable({},{__mode='k'});local ownerBytes=setmetatable({},{__mode='k'})
 local function saveClock()return ns.WardenPerformance and ns.WardenPerformance.Now()or os and os.clock and os.clock()*1000 or 0 end
 local function arrayCost(n)
  local digits,power,d=0,1,1
  while power<=n do local high=math.min(n,power*10-1);digits=digits+(high-power+1)*d;power=power*10;d=d+1 end
  return 2+#tostring(n)+3*n+digits
 end
 function c:BuildSaveView(checkpoint,records,floors,revision,sequence)
  sequence=sequence or self.sequence
  local rows,dead={},{};local payload,deadPayload=0,0
  local function collect(map,dest,isFloor)
   local bytes=0
   for id,row in pairs(map)do
    local cached=rowCache[row]
    if not cached or cached.pair~=row.pair or cached.alternate~=row.alternate or cached.at~=row.receivedAt or cached.floor~=isFloor then
     local entry={id=id,pair=ns.Athena.Copy(row.pair),alternate=row.alternate and ns.Athena.Copy(row.alternate),receivedAt=not isFloor and row.receivedAt or nil}
     cached={pair=row.pair,alternate=row.alternate,at=row.receivedAt,floor=isFloor,entry=entry,bytes=B.EncodedSize(entry)};rowCache[row]=cached
    end
    dest[#dest+1]=cached.entry;bytes=bytes+cached.bytes;if checkpoint then checkpoint()end
   end
   return bytes
  end
  payload=collect(records or self.records,rows,false);deadPayload=collect(floors or self.floors,dead,true)
  local snapshot={schema=2,consent=N.CONSENT,principal=self.principal,sequence=sequence,records=rows,floors=dead}
  local header={schema=2,consent=N.CONSENT,principal=self.principal,sequence=sequence,records={},floors={}}
  local nativeBytes=0;if self.SnapshotMetadata then local native,n=self:SnapshotMetadata(checkpoint);snapshot.native=native;nativeBytes=B.EncodedSize('native')+n end
  local ownBytes=B.EncodedSize(header)-6+arrayCost(#rows)+payload+arrayCost(#dead)+deadPayload+nativeBytes;local bytes=ownBytes
  local current=self.saved.storage.netClients or{schema=2,owners={}}
  if not exact(current,keys('schema owners'))or current.schema~=2 or type(current.owners)~='table'or getmetatable(current.owners)or count(current.owners)>4 then error('NET_SAVE_RECOVERY')end
  for key,other in pairs(current.owners)do if key~=owner then
   local n=N.snapshotSizes[other]or ownerBytes[other];if not n then n=B.EncodedSize(other,checkpoint);ownerBytes[other]=n;N.snapshotSizes[other]=n end;bytes=bytes+n
  end end
  if checkpoint then checkpoint()end
  return{snapshot=snapshot,ownBytes=ownBytes,bytes=bytes,revision=revision or self.revision,sequence=sequence,nativeRevision=self.SnapshotMetadataVersion and self:SnapshotMetadataVersion(),root=current}
 end
 function c:PrepareSave()
  if self.loggingOut then return false,'INCOMPLETE_SNAPSHOT_LAST_VALID_STATE_PRESERVED'end
  if self.privacyDetached or self.recovery and self.recovery.state~='READY'then return false,'RECOVERY_STATE_PRESERVED'end
  local j=self.savePreparation
  if not j or j.state~='PREPARING'then
   j={state='PREPARING',maxSliceMS=0,cpuMS=0};self.savePreparation=j
   local expected,sequence=self.revision,self.sequence
   local function checkpoint()if saveClock()>=j.deadline then coroutine.yield()end end
   j.thread=coroutine.create(function()local view=self:BuildSaveView(checkpoint);if expected~=self.revision or sequence~=self.sequence then return false,'SNAPSHOT_SUPERSEDED'end;return view end)
  end
  if not ns.WardenScheduler then return false,'SNAPSHOT_PREPARATION_PENDING'end
  if j.scheduled then return false,'SNAPSHOT_PREPARATION_PENDING'end
  local ok=ns.WardenScheduler.Submit('net save/'..owner,'low',function()
   if self.privacyDetached or self.savePreparation~=j then return true end
   local begin=saveClock();j.deadline=begin+2
   local ok,value,why=coroutine.resume(j.thread);local elapsed=saveClock()-begin
   j.maxSliceMS=math.max(j.maxSliceMS,elapsed);j.cpuMS=j.cpuMS+elapsed
   if not ok or coroutine.status(j.thread)=='dead'then
    j.scheduled=false;j.state=ok and type(value)=='table'and'READY'or why=='SNAPSHOT_SUPERSEDED'and'STALE'or'FAILED';j.reason=ok and why or tostring(value);j.nextAt=saveClock()+1000
    if j.state=='READY'then self.snapshotView=value;local saved,reason=self:Save();self.saveError=not saved and reason or nil end
    if j.state=='FAILED'then self.saveError='SNAPSHOT_PREPARATION_FAILED · '..tostring(j.reason):sub(1,120)end
    return true
   end;return false
  end,{module='relay',onCancel=function()j.scheduled=false end})
  j.scheduled=ok==true;if N.WakeMaintenance then N.WakeMaintenance()end;return false,ok and'SNAPSHOT_PREPARATION_PENDING'or'SNAPSHOT_WAITING_CAPACITY'
 end
 function c:Save()
  if self.privacyDetached then return false,'PRIVACY_ERASED_SESSION'end
  if self.recovery and self.recovery.state~='READY'then return false,'RECOVERY_STATE_PRESERVED'end
  local current=self.saved.storage.netClients or{schema=2,owners={}}
  if type(current.owners)~='table'or getmetatable(current.owners)then return false,'NET_SAVE_RECOVERY'end
  if not current.owners[owner]and count(current.owners)>=4 then return false,'NET_OWNER_CAPACITY'end
  if not self.snapshotView and(next(self.records)or next(self.floors)or next(current.owners))then return self:PrepareSave()end
  local view=self.snapshotView
  if not view or view.revision~=self.revision or view.sequence~=self.sequence or view.root~=current or view.nativeRevision~=(self.SnapshotMetadataVersion and self:SnapshotMetadataVersion())then
   local ok,value=pcall(self.BuildSaveView,self);if not ok then return false,'SNAPSHOT_CONSTRUCTION_FAILED'end;view=value
  end
  if view.bytes>8388608 then return false,'NET_SAVE_BYTE_BOUND'end
  local staged={schema=2,owners={}};for key,value in pairs(current.owners)do staged.owners[key]=value end
  staged.owners[owner]=view.snapshot;self.saved.storage.netClients=staged;N.snapshotSizes[view.snapshot]=view.ownBytes;view.root=staged;self.snapshotView=view
  self.saveState='ACCEPTED_IN_MEMORY_PENDING_NORMAL_WOW_SAVE';return true
 end
 function c:SaveStatus()
  local j=self.savePreparation;return{state=self.saveError and'FAILED'or j and j.state or self.saveState or'NOT_YET_SAVED',reason=self.saveError or j and j.reason,maxSliceMS=j and j.maxSliceMS or 0,cpuMS=j and j.cpuMS or 0,diskDurabilityVerified=false}
 end
 if not old and not next(c.records)and not next(c.floors)and(not root or not next(root.owners))then c.snapshotView=c:BuildSaveView()end
 local function queue()
  if c.savePreparation and c.savePreparation.state=='PREPARING'then c:PrepareSave();return end
  if ns.WardenScheduler then ns.WardenScheduler.Submit('net save/'..owner,'low',function() local ok,why=c:Save();c.saveError=not ok and why or nil;return true end,{module='relay'}) end
 end
 for _,method in ipairs({'Accept','Publish','Compact','Leave'}) do local original=c[method]
  local operation=method
  c[method]=function(self,...) local revision=self.revision;local a,b=original(self,...);if a and(not self.recovery or self.recovery.state=='READY')and(operation=='Leave'or self.revision~=revision)then queue()end;return a,b end
 end
 N.bound=N.bound or setmetatable({},{__mode='k'});N.bound[c]=true
 return true
end
local persist=CreateFrame('Frame');persist:RegisterEvent('PLAYER_LOGOUT');persist:RegisterEvent('PLAYER_ENTERING_WORLD')
local nextMaintenance=0
function N.Maintenance()
 local at=ns.WardenPerformance and ns.WardenPerformance.Now()or os and os.clock and os.clock()*1000 or 0
 if at<nextMaintenance then return end;nextMaintenance=at+1000
 for client,j in pairs(N.recoveries)do if client.privacyDetached or j.state=='READY'or j.state=='CANCELLED'or j.state=='PRIVACY_ERASED'or j.state=='RECOVERY_REQUIRED'then N.recoveries[client]=nil
  elseif not j.manualPause and not j.scheduled then client:ScheduleRecovery(false)end end
 local saving=false;for client in pairs(N.bound or{})do local j=client.savePreparation;if j and(j.state=='PREPARING'or j.state=='STALE')then saving=true;if j.state=='STALE'and at>=(j.nextAt or 0)then client.savePreparation=nil;client:PrepareSave()elseif j.state=='PREPARING'and not j.scheduled then client:PrepareSave()end end end
 if not next(N.recoveries)and not saving then persist:SetScript('OnUpdate',nil)end
end
function N.WakeMaintenance()persist:SetScript('OnUpdate',N.Maintenance)end
persist:SetScript('OnEvent',function(_,event)
 if event=='PLAYER_ENTERING_WORLD'then nextMaintenance=0;N.Maintenance();return end
 for client in pairs(N.recoveries)do client:CancelRecovery('logout')end
 for client in pairs(N.bound or {})do
  client.loggingOut=true;local j=client.savePreparation;if j then j.state='CANCELLED';j.thread=nil;j.scheduled=false;if ns.WardenScheduler then ns.WardenScheduler.Cancel('net save/'..client.saved.owner)end end
  if client.Save then local ok,why=client:Save();client.saveError=not ok and why or nil end
 end
end)

-- Fixed latest-only projection from existing local capture indexes. Never
-- accepts a selected old row, received share, or a caller-supplied raw dossier.
function N.ProjectCurrent(model,kind)
 if not model or model.owner~=ns.Chronicle.Owner() or not model.loadoutIndex or not ns.ChronicleStore.db or not ns.ChronicleStore.db.enabled then return nil,'LOCAL_CAPTURE_CONSENT_REQUIRED' end
 local family=kind=='GEAR' and 'gear' or kind=='TALENTS' and 'traits';if not family then return nil,'CURRENT_KIND' end
 local sets=family=='gear' and model.gearSets or model.talentSets
 local latest
 for _,set in ipairs(sets or {}) do for _,row in ipairs(set.observations or {}) do if not latest or row.at>latest.at then latest=row end end end
 if not latest or not latest.object or latest.object.capture.values.guid~=model.key then return nil,'NO_LOCAL_CURRENT_CAPTURE' end
 local v=latest.object.capture.values;local event=latest.event or latest.object
 local out={realm=model.identity.realm,observedAt=latest.at,evidence=event.source,quality='observed',completeness='complete',contentHash=latest.hash}
 if family=='gear' then
  out.slots={};for i=1,19 do local slot=ns.WardenDossier.Slot(latest,i);local status=slot[2]=='unavailable' and 'unknown' or slot[2]
   out.slots[i]={i,status,slot[3]};if status=='unknown' then out.completeness='partial';out.quality='partial' end
  end
 else
  out.specializationID=v.specializationID;out.exportString=v.exportString and #v.exportString<=2048 and v.exportString or nil
  out.choices={};for i,choice in ipairs(v.choices or {}) do if i<=64 then out.choices[#out.choices+1]=ns.Athena.Copy(choice) end end
  out.completeness=#out.choices==0 and out.exportString and 'export_only' or v.choicesComplete and #(v.choices or {})<=64 and 'complete' or 'partial'
  out.quality=out.completeness=='complete' and 'observed' or 'partial'
 end
 return out
end
-- Compaction preserves signed revision floors. Every local producer must
-- advance those floors as well as active records after an offline interval.
function N.NextRevision(c,t,key,kind,slot)
 local id=t..'/'..key..'/'..kind..'/'..c.principal..'/'..slot
 local row=c.records[id] or c.floors[id]
 local record=row and row.record
 if row and not record then local decoded=B.DecodeChunk(row.pair.wire);record=decoded and decoded[1] end
 local revision=record and record.revision or 0
 if revision>=1000000000 then return nil end
 return revision+1
end
function N.PublishCurrent(model,kind,explicit)
 local c=N.PublicationClient and N.PublicationClient() or N.Active and N.Active();if not c or explicit~=true then return false,'AETHER_OFF_OR_REVIEW_REQUIRED' end
 local data,why=N.ProjectCurrent(model,kind);if not data then return false,why end
 return c:Publish('CHARACTER',model.key,kind,'current',data,N.NextRevision(c,'CHARACTER',model.key,kind,'current'),false,true)
end

function N.ForgetLocal(owner)
 for c in pairs(N.bound or {}) do if not owner or c.saved and c.saved.owner==owner then c:Leave();c.privacyDetached=true;c:CancelRecovery('privacy');local j=c.savePreparation;if j then j.state='PRIVACY_ERASED';j.thread=nil end;c.snapshotView=nil;N.bound[c]=nil;if ns.WardenScheduler and c.saved then ns.WardenScheduler.Cancel('net save/'..c.saved.owner) end end end
 if N.Current and (not owner or N.Current.displayOwner==owner or N.Current.saved and N.Current.saved.owner==owner) then N.Current:Leave();N.Current=nil end
end
