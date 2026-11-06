-- Recovery admission is separate from the lossless byte codec. An intact byte
-- stream is not proof that this version can safely use its application data.
local _,ns=...
local P=ns.FiresideSavedData
local function plain(v)return type(v)=='table'and not getmetatable(v)end
local function owner(v)return type(v)=='string'and #v<=240 and v:match('^[^/]+/Player%-%d+%-%x+$')~=nil end
local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
local function map(t,identities)
 assert(plain(t),'Invalid owner/record map')
 for k,v in pairs(t)do assert(plain(v)and(not identities or owner(k)),'Invalid owner identity or record')end
end
-- Compare persisted roots before their first consumer can initialize defaults
-- or migrate them. Runtime cache cleanup is allowed after admission; the next
-- healthy save records the resulting, mutually consistent root summaries.
function P.RootManifest(base,r)
 local out={version=1,present=r~=nil,counts={}}
 if r==nil then return out end;assert(plain(r),'Invalid saved root')
 local function size(t)if t==nil then return 0 end;assert(plain(t),'Invalid saved data family');return count(t)end
 local function family(key,t)out.counts[key]=size(t)end
 local function owners(key,t,fields)
  family(key,t)
  for id,row in pairs(t or{})do
   assert(plain(row),'Invalid saved owner family');out.counts[key..'/'..tostring(id)]=1
   for _,field in ipairs(fields or{})do family(key..'/'..tostring(id)..'/'..field,row[field])end
  end
 end
 if base=='OlympusChatWardenDB'then
  owners('history',r.chronicle and r.chronicle.characters)
  for _,field in ipairs({'journalArtifacts','journalDrawings','developerExtensions'})do
   local t=r[field];owners(field,t and t.owners)
   if field=='journalArtifacts'then for id,row in pairs(t and t.owners or{})do family('badges/'..id,row.badges);family('sanctuary/'..id,row.sanctuary and row.sanctuary.earned)end end
  end
 elseif base=='OlympusWardenConversationDB'then owners('conversations',r.owners,{'moments','messages','order'})
 elseif base=='OlympusWardenRecollectionsDB'then owners('recollections',r.owners,{'notes'})
 elseif base=='OlympusWardenJournalDB'then family('pages',r.pages);family('editions',r.editions and r.editions.byID)
 elseif base=='OlympusWardenStartupDB'then owners('startup',r.characters);owners('legacy',r.legacy and r.legacy.characters)
 elseif base=='OlympusWardenRelayDB'then family('reports',r.reports);family('inbox',r.inbox)
 elseif base=='OlympusWardenPrivacyDB'then family('denials',r.all);owners('owner-denials',r.owners)
 elseif base=='OlympusWardenExchangeDB'then owners('exchange',r.characters)
  for _,field in ipairs({'netClients','netLocal','aetherCredentials','extensionActivities'})do owners(field,r[field]and r[field].owners)end
 elseif base=='OlympusWardenSimLabDB'then family('layouts',r.sceneLayouts and r.sceneLayouts.clients)
 end
 return out
end
function P.CompareRoot(expected,actual)
 assert(plain(expected)and expected.version==1 and plain(expected.counts),'Persisted root summary needs recovery')
 assert(not expected.present or actual.present,'A previously saved root is missing')
 for key,n in pairs(expected.counts)do
  assert(type(n)=='number'and n>=0 and n%1==0,'Invalid persisted family counter')
  assert((actual.counts[key]or 0)>=n,'A previously saved owner/data family is missing: '..tostring(key))
 end
 return true
end
function P.CurrentRootManifests()
 local out={}
 for _,base in ipairs(P.RootNames)do
  local name=ns.ClientCompat.StorageName(base);local root=base=='OlympusChatWardenDB'and ns.DB or _G[name]
  if type(root)=='table'and root.firesideStorage then root=P.Decode(root)end
  out[name]=P.RootManifest(base,root)
 end
 return out
end
function P.ApplicationRoot(base,r)
 if r==nil then return true end
 assert(plain(r),'Invalid application root')
 if base=='OlympusChatWardenDB'then
  assert(type(r.schema)=='number'and r.schema%1==0 and r.schema>=1 and r.schema<=11,'Unsupported main schema')
  if r.chronicle~=nil then
   assert(plain(r.chronicle)and type(r.chronicle.schema)=='number'and r.chronicle.schema>=1 and r.chronicle.schema<=6,'Unsupported history schema')
   map(r.chronicle.characters,true)
  end
 elseif base=='OlympusWardenPrivacyDB'then assert(r.version==1 and plain(r.all)and plain(r.owners),'Unsupported privacy schema');map(r.owners,true)
 elseif base=='OlympusWardenRelayDB'then assert(r.schema==1 and plain(r.reports)and plain(r.inbox),'Unsupported Relay schema')
 elseif base=='OlympusWardenStartupDB'then assert((r.version==1 or r.version==2)and plain(r.characters),'Unsupported recording journal schema');map(r.characters,true)
 elseif base=='OlympusWardenConversationDB'or base=='OlympusWardenRecollectionsDB'then assert(r.version==1,'Unsupported private archive schema');map(r.owners,true)
 elseif base=='OlympusWardenJournalDB'then assert(r.version==1,'Unsupported reading-copy schema');map(r.pages)
  for _,row in pairs(r.pages)do assert(owner(row.owner),'Invalid reading-copy owner')end
 elseif base=='OlympusWardenExchangeDB'then assert(r.schema==1 and plain(r.characters),'Unsupported Exchange schema')
  for k,v in pairs(r.characters)do assert(type(k)=='string'and k:match('^Player%-%d+%-%x+$')and plain(v),'Invalid Exchange character')end
 end
 return true
end
-- An event sequence is a reservation watermark, not the set of committed IDs.
-- The startup journal can legitimately fill holes below an earlier watermark.
-- Persist exact accepted membership as canonical interval text (one string,
-- avoiding a large SavedVariables literal table and its Lua constant limit).
local function integer(n)return type(n)=='number'and n==n and n%1==0 and n>=0 and n<=1000000000 end
local function intervals(text,total,checkpoint)
 assert(type(text)=='string'and integer(total),'Invalid accepted-history membership')
 local out,at,n,last={},1,0,-1
 while at<=#text do
  local a,b,finish=text:match('^(%d+):(%d+);()',at)
  a,b=tonumber(a),tonumber(b)
  assert(a and b and integer(a)and integer(b)and a>=1 and b>=a and a>last+1,'Invalid accepted-history interval')
  assert(text:sub(at,finish-1)==a..':'..b..';','Noncanonical accepted-history interval')
  out[#out+1]=a;out[#out+1]=b;n=n+b-a+1;last=b;at=finish
  if checkpoint and #out%512==0 then checkpoint()end
 end
 assert(n==total,'Accepted-history membership count changed');return out
end
local function literalIDs(text,key,checkpoint)
 local ids,n,at,last={},0,1
 if text==nil then return ids,n end
 assert(type(text)=='string','Invalid literal history membership')
 while at<=#text do
  local word,finish=text:match('^(%d+);()',at);local number=tonumber(word)
  assert(word and word:sub(1,1)=='0'and #key+1+#word<=256 and integer(number)and number>=1 and(not last or word>last),'Invalid literal history identity')
  ids[word]=true;n=n+1;at=finish;last=word
  if checkpoint and n%256==0 then checkpoint()end
 end
 return ids,n
end
local function member(r,n)
 local low,high=1,#r/2
 while low<=high do local mid=math.floor((low+high)/2);local at=mid*2
  if n<r[at-1]then high=mid-1 elseif n>r[at]then low=mid+1 else return true end
 end
 return false
end
local function membership(ids,checkpoint,literal)
 -- Fixed-size sorts and bounded merge work keep the login worker cooperative.
 if checkpoint then
  for first=1,#ids,512 do
   local block={};for i=first,math.min(first+511,#ids)do block[#block+1]=ids[i]end
   table.sort(block);for i,v in ipairs(block)do ids[first+i-1]=v end;checkpoint()
  end
  local width,buffer=512,{}
  while width<#ids do
   local steps=0
   for first=1,#ids,width*2 do
    local middle,last=math.min(first+width-1,#ids),math.min(first+width*2-1,#ids);local a,b=first,middle+1
    for at=first,last do
     if a<=middle and(b>last or ids[a]<=ids[b])then buffer[at]=ids[a];a=a+1 else buffer[at]=ids[b];b=b+1 end
     steps=steps+1;if steps%2048==0 then checkpoint()end
    end
   end
   ids,buffer=buffer,ids;width=width*2;checkpoint()
  end
 else table.sort(ids)end
 if literal then
  local text,last={}
  for i,word in ipairs(ids)do
   assert(not last or word>last,'Duplicate literal history identity');text[#text+1]=word..';';last=word
   if checkpoint and i%2048==0 then checkpoint()end
  end
  return table.concat(text)
 end
 local text,first,last={}
 for i,n in ipairs(ids)do
  assert(not last or n>last,'Duplicate accepted history identity')
  if last and n~=last+1 then text[#text+1]=first..':'..last..';';first=n end
  first=first or n;last=n
  if checkpoint and i%2048==0 then checkpoint()end
 end
 if last then text[#text+1]=first..':'..last..';'end
 return table.concat(text)
end
-- Packed archives are inspected one bounded chunk at a time; only numeric
-- identity membership is sorted, never a second retained history database.
function P.HistoryManifest(main,expected,checkpoint)
 local out={version=1,owners={},families={}}
 local history=main and main.chronicle
 for key,c in pairs(history and history.characters or{})do
  local row={events=0,profiles=0,sequence=c.sequence or 0,identity=0,identity2=0,prefixEvents=0,prefixIdentity=0,prefixIdentity2=0};local prior=expected and expected.owners and expected.owners[key]
  assert(not prior or prior.literal==nil or prior.accepted~=nil,'Literal membership lacks accepted history')
  local literals,literalCount=literalIDs(prior and prior.literal,key,checkpoint)
  local accepted=prior and prior.accepted~=nil and intervals(prior.accepted,prior.events-literalCount,checkpoint);local ids,words={},{}
  -- Every accepted ID proves this exact owner prefix below. Hash that fixed
  -- prefix once per owner, then continue the same two hashes over each suffix.
  local prefix=key..':';local ownerHash,ownerHash2=0,5381
  for i=1,#prefix do local b=prefix:byte(i);ownerHash=(ownerHash*33+b)%4294967291;ownerHash2=(ownerHash2*65599+b*b*131+b)%4294967291 end
  local function event(e)
   assert(type(e.id)=='string'and type(key)=='string'and e.id:sub(1,#prefix)==prefix,'Invalid history identity')
   local suffix=e.id:sub(#key+2);local sequence=tonumber(suffix)
   assert(#e.id<=256 and suffix:match('^%d+$')and integer(sequence)and sequence>=1,'Invalid history sequence')
   local canonical=suffix==tostring(sequence)
   if canonical then ids[#ids+1]=sequence else words[#words+1]=suffix end
   local h,h2=ownerHash,ownerHash2;for i=#prefix+1,#e.id do local b=e.id:byte(i);h=(h*33+b)%4294967291;h2=(h2*65599+b*b*131+b)%4294967291 end
   row.identity=(row.identity+h)%4294967291;row.identity2=(row.identity2+h2)%4294967291;row.events=row.events+1
   if prior and(accepted and(canonical and member(accepted,sequence)or not canonical and literals[suffix])or not accepted and sequence<=prior.sequence)then row.prefixEvents=row.prefixEvents+1;row.prefixIdentity=(row.prefixIdentity+h)%4294967291;row.prefixIdentity2=(row.prefixIdentity2+h2)%4294967291 end
   if checkpoint and row.events%32==0 then checkpoint()end
  end
  if c.storageFormat==1 then
   assert(ns.ChronicleBackup,'History decoder is unavailable')
   for _,text in ipairs(c.eventChunks or{})do local records=assert(ns.ChronicleBackup.DecodeChunk(text),'Invalid saved history chunk');for _,e in ipairs(records)do event(e)end end
   for _,text in ipairs(c.profileChunks or{})do local records=assert(ns.ChronicleBackup.DecodeChunk(text),'Invalid saved profile chunk');row.profiles=row.profiles+#records;if checkpoint then checkpoint()end end
  else for _,e in ipairs(c.events or{})do event(e)end;row.profiles=count(c.profiles)end
  row.accepted=membership(ids,checkpoint);if #words>0 then row.literal=membership(words,checkpoint,true)end;out.owners[key]=row
 end
 out.families.chronicle=count(history and history.characters)
 return out
end
-- Upgrade an older watermark-only marker using a verified checkpoint that
-- matches ALL of its committed-history counters. This supplies membership;
-- it never restores older content or changes the current primary database.
function P.ResolveHistoryMarker(expected,store,checkpoint)
 if not expected then return end
 assert(plain(expected)and expected.version==1 and plain(expected.owners)and plain(expected.families),'Expected-history marker needs recovery')
 local result={version=1,owners={},families=expected.families};local unresolved=0
 for key,row in pairs(expected.owners)do
  assert(plain(row)and integer(row.events)and integer(row.profiles)and integer(row.sequence),'Invalid expected-history counters')
  result.owners[key]=row;if row.accepted==nil then unresolved=unresolved+1 end
 end
 if unresolved==0 then return expected end
 for _,generation in ipairs(store and store.generations or{})do
  local payload=generation.roots and generation.roots[ns.ClientCompat.StorageName('OlympusChatWardenDB')]
  local ok,root=pcall(P.Decode,payload)
  if ok and plain(root)and root.schema and plain(root.chronicle)then
   local witness=P.HistoryManifest(root,nil,checkpoint)
   for key,row in pairs(result.owners)do local w=witness.owners[key]
    if row.accepted==nil and w and w.events==row.events and w.profiles==row.profiles and w.sequence==row.sequence and w.identity==row.identity and w.identity2==row.identity2 then
     local copy={};for k,v in pairs(row)do copy[k]=v end;copy.accepted=w.accepted;copy.literal=w.literal;result.owners[key]=copy;unresolved=unresolved-1
    end
   end
  end
  if unresolved==0 then break end
 end
 -- Without a matching witness, retain the stricter old prefix test. If its
 -- exact counts/checksums still match, the next healthy save upgrades normally.
 return result
end
local function redact(base,r,key)
 if not r then return end
 local guid=key:match('/(Player%-.+)$')
 local function remove(t,k)if plain(t)then t[k]=nil end end
 if base=='OlympusChatWardenDB'then
  if r.chronicle then remove(r.chronicle.characters,key);r.chronicle.enabled=false end
  for _,field in ipairs({'journalReadingPlaces','journalReaderPlacesV2','journalEditions','activityRunSeparations','dossierViews'})do remove(r[field],key)end
  remove(r.playerCards,guid)
  if r.characterHistory then remove(r.characterHistory.characters,'guid:'..guid)end
  if r.merchantHistoryConsent then remove(r.merchantHistoryConsent.owners,key)end
  for _,field in ipairs({'journalDrawings','journalArtifacts','developerExtensions'})do if r[field]then remove(r[field].owners,key)end end
  if r.agora then remove(r.agora.owners,guid)end
  if r.athena and r.athena.operational then for _,field in ipairs({'decisions','actions'})do
   local out={};for _,row in ipairs(r.athena.operational[field]or{})do if row.observer~=guid then out[#out+1]=row end end;r.athena.operational[field]=out
  end end
 elseif base=='OlympusWardenStartupDB'then remove(r.characters,key);if r.legacy then remove(r.legacy.characters,key)end
 elseif base=='OlympusWardenConversationDB'or base=='OlympusWardenRecollectionsDB'then
  remove(r.owners,key)
  if base=='OlympusWardenConversationDB'then
   assert(ns.AthenaConversations and ns.AthenaConversations.Recount,'Conversation validator unavailable')
   local bytes,moments=ns.AthenaConversations.Recount(r);assert(bytes and moments,'Conversation recount failed');r.bytes=bytes;r.moments=moments
  end
 elseif base=='OlympusWardenJournalDB'then
  for k,row in pairs(r.pages)do if row.owner==key then r.pages[k]=nil end end
  for k,row in pairs(r.editions and r.editions.byID or{})do if row.owner==key then r.editions.byID[k]=nil end end
 elseif base=='OlympusWardenExchangeDB'then
  remove(r.characters,guid)
  for _,field in ipairs({'netClients','aetherCredentials'})do if r[field]then remove(r[field].owners,guid)end end
  if r.extensionActivities then remove(r.extensionActivities.owners,key)end
  if r.netLocal then for k,row in pairs(r.netLocal.owners)do if row.owner==key then r.netLocal.owners[k]=nil end end end
 end
end
-- Build all redacted checkpoints privately before an owner erase is allowed.
-- Unreadable quarantine cannot be proven owner-safe: refuse, preserve it, and
-- ask for an external recovery instead of deleting another owner's evidence.
function P.PrepareOwnerErase(key)
 assert(owner(key),'Invalid erase owner')
 local store=P.RecoveryStore()
 if not store then return function()end end
 assert(not store.retained or next(store.retained)==nil,'Quarantined originals need external recovery before owner-scoped erasure')
 local function generations(list)
  local out={}
  for i,g in ipairs(list or{})do
   local copy={roots={},sequence=g.sequence,savedAt=g.savedAt,verified=g.verified}
   for _,base in ipairs(P.RootNames)do
    local name=ns.ClientCompat.StorageName(base);local payload=g.roots[name];assert(payload~=nil,'Incomplete checkpoint; erase refused')
    if payload==false then copy.roots[name]=false else
     local r=P.Decode(payload);P.ApplicationRoot(base,r);redact(base,r,key);copy.roots[name]=P.Encode(r)
    end
   end
   out[i]=copy
  end
  return out
 end
 local copies,undo=generations(store.generations),generations(store.undo)
 return function()
  store.generations=copies;store.undo=undo
  store.expectedHistory=P.HistoryManifest(ns.DB)
  store.expectedRoots=P.CurrentRootManifests()
  store.erasures=store.erasures or{};store.erasures[key]={at=ns.SafeCall(GetServerTime)or 0,scope='owner',revision=store.sequence or 0}
 end
end
function P.CompareHistory(expected,actual)
 if not expected then return true end
 assert(plain(expected)and expected.version==1 and plain(expected.owners)and plain(expected.families),'Expected-history marker needs recovery')
 for key,before in pairs(expected.owners)do
  local after=actual.owners[key]
  assert(after and after.events>=before.events and after.profiles>=before.profiles and after.sequence>=before.sequence,'Previously saved character history is missing or smaller: '..tostring(key))
  assert(after.prefixEvents==before.events and after.prefixIdentity==before.identity,'Previously saved event identities are missing despite newer records: '..tostring(key))
  assert(before.identity2==nil or after.prefixIdentity2==before.identity2,'Previously saved event identity checksum changed: '..tostring(key))
  assert(after.events~=before.events or after.identity==before.identity,'Previously saved event identities changed: '..tostring(key))
 end
 for key,n in pairs(expected.families)do assert((actual.families[key]or 0)>=n,'Previously saved data family is missing: '..key)end
 return true
end
-- Qualify one bounded saved chunk at a time. Keep only duplicate identities
-- and snapshot objects needed by dependency checks, not a second full ledger.
function P.ValidateHistory(history)
 local S,B,X=ns.ChronicleStore,ns.ChronicleBackup,ns.ChronicleCapture
 assert(S and B,'History validation is unavailable')
 assert(history.consentVersion==nil or S.Integer(history.consentVersion,1,S.CONSENT),'Unsupported history consent version')
 local header={};for k,v in pairs(history)do if k~='characters'then header[k]=v end end;header.characters={}
 assert(S.Normalize(header),'Unsupported history metadata')
 for key,c in pairs(history.characters)do
  local template={};for k,v in pairs(c)do if k~='events'and k~='profiles'and k~='eventChunks'and k~='profileChunks'then template[k]=v end end
  template.storageFormat=1;template.eventChunks={};template.profileChunks={}
  local function qualify(events,profiles,legacyEvents,legacyProfiles)
   local sample={};for k,v in pairs(template)do sample[k]=v end
   if events then sample.eventChunks={events}end;if profiles then sample.profileChunks={profiles}end
   if legacyEvents or legacyProfiles then sample.storageFormat=nil;sample.eventChunks=nil;sample.profileChunks=nil;sample.events=legacyEvents or{};sample.profiles=legacyProfiles or{}end
   local result=assert(S.Normalize({schema=history.schema,consentVersion=history.consentVersion,characters={[key]=sample}}),'Invalid checkpoint character chunk')
   return result.characters[key]
  end
  qualify()
  assert(c.storageFormat==nil or c.storageFormat==1,'Unsupported character storage format')
  local seen,objects,refs={},{},{}
  local function accept(e)
   assert(not seen[e.id],'Duplicate checkpoint event identity');seen[e.id]=true
   local d=e.details
   assert(X or not(e.capture or d.gearRef or d.traitRef or d.appearanceRef or d.cardRef or d.contentID),'Snapshot dependency validator unavailable')
   if X then
    if e.capture then objects[e.details.contentID]=e;refs[#refs+1]=e
    else
     local d=e.details
     if d.gearRef or d.traitRef or d.appearanceRef or d.cardRef or d.contentID then
      refs[#refs+1]={kind=e.kind,details={gearRef=d.gearRef,traitRef=d.traitRef,appearanceRef=d.appearanceRef,cardRef=d.cardRef,contentID=d.contentID,family=d.family}}
     end
    end
   end
  end
  if c.storageFormat==1 then
   assert(c.events==nil and c.profiles==nil and S.Array(c.eventChunks,1000000000)and S.Array(c.profileChunks,1000000000),'Invalid packed character arrays')
   for _,text in ipairs(c.eventChunks)do for _,e in ipairs(qualify(text).events)do accept(e)end end
  else
   assert(c.events==nil or S.Array(c.events,1000000000),'Invalid checkpoint event array')
   local buffer={};for _,e in ipairs(c.events or{})do
    buffer[#buffer+1]=e;if #buffer==32 then for _,valid in ipairs(qualify(nil,nil,buffer).events)do accept(valid)end;buffer={}end
   end
   if #buffer>0 then for _,valid in ipairs(qualify(nil,nil,buffer).events)do accept(valid)end end
  end
  if X then for _,e in ipairs(refs)do assert(X.Dependencies(e,objects))end end
  seen,objects,refs=nil,nil,nil
  local profilesSeen={}
  local function profiles(text)
   local valid=qualify(nil,text)
   for guid in pairs(valid.profiles)do assert(not profilesSeen[guid],'Duplicate checkpoint profile identity');profilesSeen[guid]=true end
  end
  if c.storageFormat==1 then for _,text in ipairs(c.profileChunks)do profiles(text)end
  else
   assert(c.profiles==nil or plain(c.profiles),'Invalid checkpoint profile map')
   local buffer,n={},0;for guid,p in pairs(c.profiles or{})do
    buffer[guid]=p;n=n+1
    if n==32 then qualify(nil,nil,{},buffer);buffer={};n=0 end
   end
   if n>0 then qualify(nil,nil,{},buffer)end
  end
 end
 return true
end
function P.ValidateGeneration(generation,retainedExchange)
 assert(plain(generation)and plain(generation.roots),'Invalid checkpoint')
 local roots={};local C=ns.ClientCompat
 for _,base in ipairs(P.RootNames)do
  local payload=generation.roots[C.StorageName(base)]
  assert(payload~=nil,'Incomplete checkpoint')
  if payload~=false then roots[base]=P.Decode(payload);P.ApplicationRoot(base,roots[base])end
 end
 assert(roots.OlympusChatWardenDB,'Missing checkpoint main root')
 local history=roots.OlympusChatWardenDB.chronicle
 if history then P.ValidateHistory(history)end
 -- Qualify pending observations with the actual replay/ID-remap algorithm
 -- on PRIVATE copies. Keep the complete original journal in the restore;
 -- neither validation failure nor a dry-run can consume accepted evidence.
 local startup=roots.OlympusWardenStartupDB
 if startup then
  assert(ns.ChronicleStartupJournal and ns.ChronicleStartupJournal.ValidateRecovery,'Recording recovery validator is unavailable')
  ns.ChronicleStartupJournal.ValidateRecovery(history,startup)
 end
 -- Network identities, anti-replay counters and consent are never rolled
 -- back with history. ScheduleRestore supplies the unchanged CURRENT root.
 if retainedExchange then
  local previous=roots.OlympusWardenExchangeDB
  if not retainedExchange.value and previous then
   assert(next(previous.characters)==nil,'Missing current sharing identity requires separate recovery; checkpoint retained')
   for _,field in ipairs({'netClients','netLocal','aetherCredentials','extensionActivities'})do
    assert(not previous[field]or not previous[field].owners or next(previous[field].owners)==nil,'Missing current sharing identity requires separate recovery; checkpoint retained')
   end
  end
  roots.OlympusWardenExchangeDB=retainedExchange.value
 end
 local reading=roots.OlympusWardenJournalDB
 if reading and next(reading.pages)~=nil or reading and reading.editions then
  assert(ns.AthenaReadingSnapshots and ns.AthenaReadingSnapshots.ValidateSaved,'Saved reading validator unavailable')
  ns.AthenaReadingSnapshots.ValidateSaved(reading,history)
 end
 local conversations=roots.OlympusWardenConversationDB
 if conversations then
  assert(ns.AthenaConversations and ns.AthenaConversations.ValidateSaved,'Conversation recovery validator unavailable')
  ns.AthenaConversations.ValidateSaved(conversations)
 end
 local recollections=roots.OlympusWardenRecollectionsDB
 if recollections then
  assert(ns.AthenaRecollections and ns.AthenaRecollections.ValidateSaved,'Recollection recovery validator unavailable')
  ns.AthenaRecollections.ValidateSaved(recollections,history)
 end
 -- Sharing credentials and replay counters are still retained from the
 -- current root; historical recovery must never roll them back.
 for _,base in ipairs({'OlympusWardenExchangeDB'})do
  local r=roots[base];local records=r and(r.owners or r.pages or r.characters)
  assert(base=='OlympusWardenExchangeDB'and retainedExchange or not records or next(records)==nil,'Checkpoint has private records requiring application recovery; original files retained')
  if base=='OlympusWardenExchangeDB'and r and not retainedExchange then for _,field in ipairs({'netClients','netLocal','aetherCredentials','extensionActivities'})do assert(not r[field]or not r[field].owners or next(r[field].owners)==nil,'Network identity must be retained from the current save; rollback refused')end end
 end
 return roots
end
