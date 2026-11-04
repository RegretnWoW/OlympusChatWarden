-- Bounded SDK activity contracts, not a Banner game or a second messenger.
-- Native transport is deliberately unavailable until consent/proof QA passes.
local _,ns=...
local K=ns.AetherExtensionContracts
local T={VERSION=1,MAX_BYTES=65536,MAX_MESSAGES=128,MAX_OUTBOX=64,MAX_SESSIONS=16};ns.AetherActivityService=T
local function copy(v)return ns.Athena.Copy(v)end
local function count(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
local function bytes(v)return #ns.ChronicleBackup.Encode({v})end
local receipts=K.Set('LOCAL_COMMITTED PENDING_ROUTE FORWARDED ACKNOWLEDGED APPLIED EXPIRED REJECTED CONFLICT')
function T.New(o)
 if not K.Plain(o)or not ns.ChronicleStore.GUID(o.owner)or type(o.clock)~='function'or type(o.verify)~='function'or type(o.authorize)~='function'then return nil,'ACTIVITY_ADAPTER_REQUIRED'end
 local root=o.root or{version=1,sequence=0,definitions={},messages={},outbox={},inbox={},sessions={},invites={},receipts={},awards={}}
 if not K.Keys(root,K.Set('version sequence definitions messages outbox inbox sessions invites receipts awards'))or root.version~=1 or not K.Int(root.sequence,0,1000000)then return nil,'ACTIVITY_STATE_PRESERVED_UNSUPPORTED'end
 for _,key in ipairs({'definitions','messages','outbox','inbox','sessions','invites','receipts','awards'})do if not K.Plain(root[key])or count(root[key])>T.MAX_MESSAGES then return nil,'ACTIVITY_STATE_BOUND'end end
 if bytes(root)>T.MAX_BYTES then return nil,'ACTIVITY_STATE_BOUND'end
 for id,e in pairs(root.messages)do local ok=K.Envelope(e,o.clock(),true);if not ok or e.envelopeID~=id then return nil,'INVALID_RETAINED_ENVELOPE'end end
 if count(root.definitions)>16 or count(root.outbox)>T.MAX_OUTBOX or count(root.sessions)>T.MAX_SESSIONS then return nil,'ACTIVITY_STATE_BOUND'end
 for id,d in pairs(root.definitions)do if not K.Plain(d)or not K.ID(d.extension)or not K.ID(d.activityID)or id~=d.extension..'/'..d.activityID or not K.Int(d.version,1,1000)or not K.Int(d.minimum,1,8)or not K.Int(d.maximum,d.minimum,8)or d.authority~='COORDINATOR_SIGNED'then return nil,'INVALID_RETAINED_DEFINITION'end end
 for id,row in pairs(root.outbox)do if not K.Plain(row)or not root.messages[id]or row.id~=id or not K.Int(row.attempts,0,1000000)or not K.Int(row.nextAt,0,2147483647)or not K.Int(row.expiresAt,1,2147483647)then return nil,'INVALID_RETAINED_OUTBOX'end end
 for _,row in pairs(root.sessions)do if not K.Plain(row)or not ns.ChronicleStore.GUID(row.authority)or not ns.ChronicleStore.GUID(row.holder)or not K.Array(row.participants,8)or not K.Int(row.revision,0,1000000)or not K.Plain(row.history)or not K.Token(row.head,384)or not K.Int(row.expiresAt,1,2147483647)then return nil,'INVALID_RETAINED_SESSION'end end
 for _,row in pairs(root.inbox)do if not K.Plain(row)or not ns.ChronicleStore.GUID(row.author)then return nil,'INVALID_RETAINED_INBOX'end end
 for _,row in pairs(root.receipts)do if not K.Plain(row)or not receipts[row.state]then return nil,'INVALID_RETAINED_RECEIPT'end end
 for id,row in pairs(root.invites)do if not root.messages[id]or not K.Envelope(row,o.clock(),true)or row.kind~='INVITE'then return nil,'INVALID_RETAINED_INVITE'end end
 for _,row in pairs(root.awards)do if not K.Plain(row)or row.renown~=0 or row.official~=false or not K.Token(row.session,128)then return nil,'INVALID_RETAINED_AWARD'end end
 local S={root=root,owner=o.owner,metrics={accepted=0,rejected=0,duplicate=0,forwarded=0},native=false}
 local function transaction(fn)
  local next=copy(S.root);local ok,value,why=fn(next);if not ok then return nil,value or why end
  if bytes(next)>T.MAX_BYTES or count(next.messages)>T.MAX_MESSAGES or count(next.outbox)>T.MAX_OUTBOX or count(next.sessions)>T.MAX_SESSIONS then return nil,'ACTIVITY_STORAGE_BOUND'end
  if o.save then local saved,accepted,reason=pcall(o.save,copy(next));if not saved or accepted~=true then S.saveError='ACTIVITY_SAVE_FAILED';return nil,S.saveError..(type(reason)=='string'and(' · '..reason)or'')end end
  S.root=next;S.saveError=nil;return value or true,why
 end
 local function enabled()return not o.enabled or o.enabled()==true end
 function S.Define(d)
  if not enabled()then return false,'ACTIVITY_DISABLED'end
  if not K.Keys(d,K.Set('extension activityID version ruleset minimum maximum authority'))or not K.ID(d.extension)or not K.ID(d.activityID)
   or not K.Int(d.version,1,1000)or not K.Token(d.ruleset)or not K.Int(d.minimum,1,8)or not K.Int(d.maximum,d.minimum,8)or d.authority~='COORDINATOR_SIGNED'then return false,'ACTIVITY_DEFINITION'end
  local key=d.extension..'/'..d.activityID
  local previous=S.root.definitions[key];if previous and ns.ChronicleBackup.Encode({previous})~=ns.ChronicleBackup.Encode({d})then return false,'RULESET_COLLISION'end
  return transaction(function(r)if count(r.definitions)>=16 and not r.definitions[key]then return false,'DEFINITION_BOUND'end;r.definitions[key]=copy(d);return true,true end)
 end
 function S.Queue(d)
  if not enabled()then return nil,'ACTIVITY_DISABLED'end
  if not K.Plain(d)then return nil,'ENVELOPE_SCHEMA'end
  if d.actorGUID and d.actorGUID~=S.owner then return nil,'ACTOR_IMPERSONATION_REJECTED'end
  local e=copy(d);local at=o.clock();e.version=1;e.actorGUID=S.owner;e.issuedAt=at;e.expiresAt=e.expiresAt or at+3600
  local nextSequence=S.root.sequence+1;e.envelopeID=e.envelopeID or S.owner..'/'..at..'/'..nextSequence
  local valid,why=K.Envelope(e,at);if not valid then return nil,why end
  local auth,reason=o.authorize(e,'create');if not auth then return nil,reason or'RECIPIENT_CONSENT_REQUIRED'end
  return transaction(function(r)
   if r.messages[e.envelopeID]then return false,'DUPLICATE_LOCAL_ID'end
   if e.kind=='INVITE'then
    local live=0;for _,v in pairs(r.invites)do if v.expiresAt>at and v.targetGUID==e.targetGUID then live=live+1 end end
    if live>=1 then return false,'INVITE_COOLDOWN'end;r.invites[e.envelopeID]=copy(e)
   end
   r.sequence=nextSequence;r.messages[e.envelopeID]=e
   r.outbox[e.envelopeID]={id=e.envelopeID,attempts=0,nextAt=at,expiresAt=e.expiresAt,state='PENDING_ROUTE'}
   r.receipts[e.envelopeID]={state='LOCAL_COMMITTED',at=at,actor=e.actorGUID,recipient=e.targetGUID,scope='This client retained an authorized envelope; no delivery proof.'}
   return true,{id=e.envelopeID,state='LOCAL_COMMITTED'}
  end)
 end
 function S.Receive(e,proof,relay)
  if not enabled()then return false,'ACTIVITY_DISABLED'end
  local valid,why=K.Envelope(e,o.clock());if not valid then return false,why end
  local author=o.verify(e,proof,relay)
  if author~=e.actorGUID then S.metrics.rejected=S.metrics.rejected+1;return false,'AUTHOR_PROOF_REQUIRED'end
  local consent,reason=o.authorize(e,'receive');if not consent then return false,reason or'RECIPIENT_CONSENT_REQUIRED'end
  local prior=S.root.messages[e.envelopeID]
  if prior then
   if ns.ChronicleBackup.Encode({prior})==ns.ChronicleBackup.Encode({e})then S.metrics.duplicate=S.metrics.duplicate+1;return true,'DUPLICATE'end
   return false,'ACTION_ID_CONFLICT'
  end
  local result,err=transaction(function(r)
   r.messages[e.envelopeID]=copy(e);r.inbox[e.envelopeID]={id=e.envelopeID,author=author,relay=relay,at=o.clock(),state='APPLIED'}
   local definition=r.definitions[e.extension..'/'..e.activityID]
   if e.targetGUID~=S.owner and not o.relay then return false,'WRONG_RECIPIENT'end
   if not definition or e.targetGUID~=S.owner then
    r.inbox[e.envelopeID].state='PENDING_EXTENSION'
    r.outbox[e.envelopeID]={id=e.envelopeID,attempts=0,nextAt=o.clock(),expiresAt=e.expiresAt,state='PENDING_ROUTE'}
    return true,'PENDING_EXTENSION'
   end
   if definition.version~=e.rulesVersion then return false,'RULE_VERSION'end
   local s=r.sessions[e.sessionID]
   if e.kind=='SESSION'then
    local b=e.body
    if s then return false,'SESSION_COLLISION'end
    if b.authority~=e.actorGUID or b.holder~=e.actorGUID or e.sequence~=0 or e.prior~='root'or not b.participants then return false,'SESSION_AUTHORITY'end
    if #b.participants<definition.minimum or #b.participants>definition.maximum then return false,'PARTY_SIZE'end
    r.sessions[e.sessionID]={authority=b.authority,holder=b.holder,participants=copy(b.participants),revision=0,head=e.envelopeID,history={},state='ACTIVE',expiresAt=e.expiresAt,rulesVersion=e.rulesVersion}
   elseif e.kind=='TURN'or e.kind=='RESULT'then
    if not s then return false,'SESSION_REQUIRED'end
    if s.state=='CONFLICT'then return false,'CONFLICT_PENDING_RECONCILIATION'end
    if s.expiresAt<=o.clock()then return false,'SESSION_EXPIRED'end
    if e.actorGUID~=s.authority then return false,'COORDINATOR_SIGNATURE_REQUIRED'end
    local fork=s.history[e.sequence]
    if fork and fork.prior==e.prior and fork.id~=e.envelopeID then
     s.state='CONFLICT';s.conflict={first=fork.id,second=e.envelopeID,prior=e.prior};r.inbox[e.envelopeID].state='CONFLICT'
     for _,award in pairs(r.awards)do if award.session==e.sessionID then award.state='DISPUTED'end end
     return true,'CONFLICT'
    end
    if e.sequence~=s.revision+1 or e.prior~=s.head then return false,'STALE_OR_MISSING_PREDECESSOR'end
    local holder=e.body.nextHolder or s.holder;local member=false;for _,g in ipairs(s.participants)do if g==holder then member=true end end
    if not member then return false,'HOLDER_NOT_PARTICIPANT'end
    s.history[e.sequence]={id=e.envelopeID,prior=e.prior};s.revision=e.sequence;s.head=e.envelopeID;s.holder=holder
    if e.kind=='RESULT'then s.state='RESULT_PENDING';s.resultRef=e.envelopeID end
   elseif e.kind=='ACCEPT'or e.kind=='DECLINE'or e.kind=='CANCEL'then
    local invite=r.messages[e.body.replyTo]
    if not invite or invite.kind~='INVITE'or invite.expiresAt<=o.clock()then return false,'INVITE_EXPIRED_OR_UNKNOWN'end
    local expected=e.kind=='CANCEL'and invite.actorGUID or invite.targetGUID
    if e.actorGUID~=expected then return false,'INVITE_ACTOR_REQUIRED'end
    r.invites[invite.envelopeID]=nil
   elseif e.kind=='INVITE'then
    if e.targetGUID~=S.owner and not o.relay then return false,'WRONG_RECIPIENT'end
    r.invites[e.envelopeID]=copy(e)
   elseif e.kind=='RECEIPT'then return false,'UNSUPPORTED_RECEIPT_AUTHORITY'end
   r.receipts[e.envelopeID]={state='APPLIED',at=o.clock(),actor=author,recipient=S.owner,hop=relay,scope='Validated by this client; not global consensus or gameplay proof.'}
   return true,'APPLIED'
  end)
  if result then S.metrics.accepted=S.metrics.accepted+1 else S.metrics.rejected=S.metrics.rejected+1 end
  return result~=nil,err or result
 end
 function S.Pump()
  if not enabled()then return false,'ACTIVITY_DISABLED'end
  local ids={};for id in pairs(S.root.outbox)do ids[#ids+1]=id end;table.sort(ids);local work=0
  for _,id in ipairs(ids)do if work>=2 then break end;local row=S.root.outbox[id];local at=o.clock()
   if row.expiresAt<=at then
    local ok,why=transaction(function(r)r.outbox[id]=nil;r.receipts[id]={state='EXPIRED',at=at,scope='No delivery guarantee'};return true,true end);if not ok then return false,why end
   elseif row.nextAt<=at then
    work=work+1;local e=S.root.messages[id];local permission=o.authorize(e,'forward')
    local ok,why=transaction(function(r)local next=r.outbox[id];next.state=permission and'PENDING_ROUTE'or'PENDING_RECIPIENT_CONSENT';next.nextAt=at+300
     if permission and o.transport then next.attempts=next.attempts+1;next.nextAt=at+math.min(3600,15*2^math.min(next.attempts,8))end;return true,true end)
    if not ok then return false,why end
    if permission and o.transport then
     local sent,accepted=pcall(o.transport,copy(e));accepted=sent and accepted==true
     local stored,reason=transaction(function(r)local next=r.outbox[id];if not next then return false,'OUTBOX_CHANGED'end;next.state=accepted and'FORWARDED'or'PENDING_ROUTE';r.receipts[id]={state=next.state,at=at,actor=e.actorGUID,recipient=e.targetGUID,scope='Transport attempt only; recipient application not proven.'};return true,true end)
     if not stored then return false,reason end;if accepted then S.metrics.forwarded=S.metrics.forwarded+1 end
    end
   end
  end
  return true
 end
 function S.Acknowledge(id,recipient,processed,proof)
  if not enabled()then return false,'ACTIVITY_DISABLED'end
  local e=S.root.messages[id];if not e or recipient~=e.targetGUID or not o.verifyReceipt or o.verifyReceipt(id,recipient,processed,proof)~=true then return false,'RECEIPT_PROOF_REQUIRED'end
  local ok,why=transaction(function(r)r.receipts[id]={state=processed and'APPLIED'or'ACKNOWLEDGED',at=o.clock(),recipient=recipient,scope=processed and'This recipient processed this envelope'or'This recipient acknowledged this envelope; application unproven'};r.outbox[id]=nil;return true,true end)
  return ok~=nil,why
 end
 function S.Redeem(sessionID,resultRef)
  local s=S.root.sessions[sessionID]
  if not s or s.state~='RESULT_PENDING'or s.resultRef~=resultRef then return nil,'VERIFIED_RESULT_REQUIRED'end
  local key=sessionID..'/'..S.owner;if S.root.awards[key]then return copy(S.root.awards[key]),'ALREADY_RECORDED'end
  return transaction(function(r)
   local award={receipt=key,session=sessionID,result=resultRef,recipient=S.owner,state='DEVELOPER_TEST_ONLY',renown=0,official=false}
   r.awards[key]=award;return true,copy(award)
  end)
 end
 function S.Snapshot()return copy(S.root)end
 return S
end
-- Owner-local preview state nests in the existing Exchange SavedVariables.
local function current(h)
 local ext,why=ns.WardenExtensions.Check(h,'activity.local');if not ext then return nil,why end
 local storage=ns.Storage.OlympusWardenExchangeDB
 if storage==nil then storage={schema=1,characters={}};ns.Storage.OlympusWardenExchangeDB=storage end
 if not K.Plain(storage)or storage.schema~=1 or not K.Plain(storage.characters)then return nil,'EXCHANGE_PRESERVED_UNSUPPORTED'end
 if not storage.extensionActivities then storage.extensionActivities={version=1,owners={}}end
 local root=storage.extensionActivities;if not K.Plain(root)or root.version~=1 or not K.Plain(root.owners)then return nil,'ACTIVITY_STATE_PRESERVED_UNSUPPORTED'end
 local owner=ns.Chronicle.Owner();local rows=root.owners[owner]
 if not rows then rows={};root.owners[owner]=rows end;if not K.Plain(rows)or count(rows)>16 then return nil,'ACTIVITY_OWNER_BOUND'end
 local id=ext.manifest.id
 return T.New({owner=ns.PlayerCard.Own(),root=rows[id],clock=function()return ns.SafeCall(GetServerTime)or 0 end,
  enabled=function()return ns.WardenExtensions.Check(h,'activity.local')~=nil end,
  save=function(value)rows[id]=value;return true end,
  verify=function()return nil end, -- no SDK-native ingress before qualification
  authorize=function(e)return e.actorGUID==ns.PlayerCard.Own()and e.targetGUID==ns.PlayerCard.Own(),'RECIPIENT_CONSENT_NOT_VERIFIED'end})
end
local api=_G.OlympusWarden and _G.OlympusWarden.API
if api then
 function api:DefineActivity(h,d)local s,why=current(h);if not s then return nil,why end;return s.Define(d)end
 function api:QueueActivity(h,e)local s,why=current(h);if not s then return nil,why end;return s.Queue(e)end
 function api:ActivityStatus(h)local s,why=current(h);if not s then return nil,why end;return {mode='LOCAL_PREVIEW',native='SDK_NATIVE_TRANSPORT_NOT_QUALIFIED',outbox=count(s.root.outbox),bytes=bytes(s.root),messages=count(s.root.messages)}end
end
