-- WoW compiles each addon's SavedVariables as one Lua chunk. Large literal
-- ledgers can exceed its constant-table limit BEFORE addon validation runs.
-- Keep the live tables unchanged; serialize large roots as lossless data strings
-- at logout. This is data encoding, not executable Lua or asset compression.
local _,ns=...
local P={VERSION=1,RAW_NODES=4096,CHUNK=65536,blocked={},errors={},restored={},admitted={},badCopies=setmetatable({},{__mode='k'})};ns.FiresideSavedData=P
local names={'OlympusWardenPrivacyDB','OlympusChatWardenDB','OlympusWardenRelayDB','OlympusWardenStartupDB','OlympusWardenConversationDB','OlympusWardenJournalDB','OlympusWardenRecollectionsDB','OlympusWardenExchangeDB','OlympusWardenSimLabDB'}
P.RootNames=names
local function finite(n)return n==n and n~=math.huge and n~=-math.huge end
local function checksum(a,b,s)
 -- Adler-32 is unchanged. Reducing per bounded block avoids two modulo
 -- operations per byte while keeping every integer exactly representable.
 for first=1,#s,5552 do
  for i=first,math.min(first+5551,#s)do a=a+s:byte(i);b=b+a end
  a=a%65521;b=b%65521
 end
 return a,b
end
local function large(root)
 local seen,count={},0
 local function visit(v,depth)
  count=count+1;if count>P.RAW_NODES then return true end
  if type(v)~='table'then return false end
  if seen[v]or depth>64 or getmetatable(v)then return true end;seen[v]=true
  for k,x in pairs(v)do if visit(k,depth+1)or visit(x,depth+1)then return true end end
  seen[v]=nil;return false
 end
 return visit(root,0)
end
function P.Encode(root)
 local chunks,parts,size,bytes,ancestors={}, {},0,0,{}
 local a,b=1,0
 local function flush()if size>0 then chunks[#chunks+1]=table.concat(parts);parts={};size=0 end end
 local function emit(s)
  a,b=checksum(a,b,s)
  bytes=bytes+#s;local at=1
  while at<=#s do local n=math.min(P.CHUNK-size,#s-at+1);parts[#parts+1]=s:sub(at,at+n-1);size=size+n;at=at+n;if size==P.CHUNK then flush()end end
 end
 local function value(v,depth)
  assert(depth<=64,'Saved data nesting exceeds 64 levels')
  local t=type(v)
  if t=='string'then emit('s'..#v..':');emit(v)
  elseif t=='number'then assert(finite(v),'Non-finite saved number');local s=string.format('%.17g',v);emit('n'..#s..':'..s)
  elseif t=='boolean'then emit(v and'b1'or'b0')
  else
   assert(t=='table'and not getmetatable(v)and not ancestors[v],'Unsupported or cyclic saved data');ancestors[v]=true
   local n=0;for k in pairs(v)do assert(type(k)=='string'or type(k)=='number'or type(k)=='boolean','Unsupported saved key');n=n+1 end
   emit('t'..n..':');for k,x in pairs(v)do value(k,depth+1);value(x,depth+1)end;ancestors[v]=nil
  end
 end
 value(root,0);flush()
 return{firesideStorage=1,bytes=bytes,checksum=b*65536+a,chunks=chunks}
end
function P.Decode(saved,validateOnly)
 assert(type(saved)=='table'and not getmetatable(saved)and saved.firesideStorage==1,'Unsupported Fireside saved-data format')
 assert(type(saved.chunks)=='table'and not getmetatable(saved.chunks),'Missing saved data chunks')
 local total,a,b=0,1,0;local count=0
 for k,s in pairs(saved.chunks)do
  assert(type(k)=='number'and k%1==0 and k>=1 and k<=#saved.chunks and type(s)=='string'and #s>0 and #s<=P.CHUNK,'Invalid saved chunk')
  total=total+#s;count=count+1
 end
 for _,s in ipairs(saved.chunks)do a,b=checksum(a,b,s)end
 assert(count==#saved.chunks and total==saved.bytes and b*65536+a==saved.checksum,'Saved data length or checksum mismatch')
 local chunk,offset,consumed=1,1,0
 local function take(n)
  assert(n>=0 and n%1==0 and n<=total-consumed,'Truncated saved data')
  local current=saved.chunks[chunk]
  if current and n<=#current-offset+1 then
   local result=current:sub(offset,offset+n-1);offset=offset+n;consumed=consumed+n
   if offset>#current then chunk=chunk+1;offset=1 end
   return result
  end
  local parts={}
  while n>0 do local s=saved.chunks[chunk];assert(s,'Missing saved chunk');local k=math.min(n,#s-offset+1);parts[#parts+1]=s:sub(offset,offset+k-1);offset=offset+k;n=n-k;consumed=consumed+k;if offset>#s then chunk=chunk+1;offset=1 end end
  return table.concat(parts)
 end
 local function length()
  local current=saved.chunks[chunk]
  if current then
   local last=current:find(':',offset,true)
   if last and last-offset<=11 then
    local digits=current:sub(offset,last-1);assert(digits:match('^%d+$'),'Invalid saved length')
    local n=tonumber(digits);assert(n and n<=total,'Invalid saved length')
    consumed=consumed+last-offset+1;offset=last+1;if offset>#current then chunk=chunk+1;offset=1 end
    return n
   end
  end
  local s='';for _=1,12 do local c=take(1);if c==':'then local n=tonumber(s);assert(n and n<=total,'Invalid saved length');return n end;assert(c:match('^%d$'),'Invalid saved length');s=s..c end
  error('Invalid saved length',0)
 end
 local validatedTable={}
 local function value(depth,keyValue)
  assert(depth<=64,'Saved data nesting exceeds 64 levels');local tag=take(1)
  if tag=='b'then local c=take(1);assert(c=='0'or c=='1','Invalid saved boolean');return c=='1'end
  local n=length()
  if tag=='s'then
   if validateOnly and not keyValue then
    assert(n<=total-consumed,'Truncated saved data')
    while n>0 do local s=saved.chunks[chunk];assert(s,'Missing saved chunk');local k=math.min(n,#s-offset+1);offset=offset+k;n=n-k;consumed=consumed+k;if offset>#s then chunk=chunk+1;offset=1 end end
    return true
   end
   return take(n)
  elseif tag=='n'then local s=take(n);assert(s:match('^[%d%.eE%+%-]+$'),'Invalid saved number');local v=tonumber(s);assert(v and finite(v),'Invalid saved number');return v end
  assert(tag=='t'and not keyValue and n<=(total-consumed)/4,'Invalid saved table');local out={}
  for _=1,n do local k=value(depth+1,true);assert(type(k)=='string'or type(k)=='number'or type(k)=='boolean','Invalid saved key');assert(out[k]==nil,'Duplicate saved key');local v=value(depth+1,false);out[k]=validateOnly and true or v end
  return validateOnly and validatedTable or out
 end
 local result=value(0);assert(consumed==total and type(result)=='table','Trailing or invalid saved data');return result
end
local function recovery(create)
 local name=ns.ClientCompat.StorageName('FiresideRecoveryDB');local root=name and _G[name]
 if root==nil and create and FiresideRecoveryRuntime then root={version=1,generations={}};_G[name]=root end
 if type(root)=='table'and not getmetatable(root)and root.version==1 and type(root.generations)=='table'and not getmetatable(root.generations)then
  if root.enabled~=nil and type(root.enabled)~='boolean'then return end
  if root.primaryExpected~=nil and type(root.primaryExpected)~='boolean'then return end
  if root.clientTarget~=nil and root.clientTarget~=(ns.ClientBuild and ns.ClientBuild.target)then return end
  if root.expectedRoots~=nil then
   if type(root.expectedRoots)~='table'or getmetatable(root.expectedRoots)then return end
   for name,summary in pairs(root.expectedRoots)do if type(name)~='string'or type(summary)~='table'or getmetatable(summary)or summary.version~=1 or type(summary.present)~='boolean'or type(summary.counts)~='table'or getmetatable(summary.counts)then return end end
  end
  if root.sequence~=nil and(type(root.sequence)~='number'or not finite(root.sequence)or root.sequence%1~=0 or root.sequence<0 or root.sequence>9007199254740990)then return end
  if root.erasures~=nil then
   if type(root.erasures)~='table'or getmetatable(root.erasures)then return end
   for owner,tombstone in pairs(root.erasures)do if type(owner)~='string'or type(tombstone)~='table'or getmetatable(tombstone)or type(tombstone.revision)~='number'or not finite(tombstone.revision)or tombstone.revision<0 or tombstone.revision%1~=0 then return end end
  end
  for i,copy in pairs(root.generations)do if type(i)~='number'or i%1~=0 or i<1 or i>10 or type(copy)~='table'then return end end
  return root
 end
end
if ns.FiresideStartupTiming then recovery=ns.FiresideStartupTiming.Wrap(recovery,'backup metadata')end
P.RecoveryStore=recovery
local function admit(name,value)
 if P.admitted[name]==value and value~=nil then return true end
 local store=recovery();local expected=store and store.expectedRoots and store.expectedRoots[name]
 local ok,why=true
 if not store and _G[ns.ClientCompat.StorageName('FiresideRecoveryDB')]~=nil then ok=false;why='Independent recovery metadata needs recovery'
 elseif expected and P.RootManifest then
  local baseName;for _,base in ipairs(names)do if ns.ClientCompat.StorageName(base)==name then baseName=base;break end end
  if baseName then ok,why=pcall(function()return P.CompareRoot(expected,P.RootManifest(baseName,value))end)end
 end
 if not ok then P.blocked[name]=true;P.errors[name]=tostring(why);return false end
 P.admitted[name]=value;return true
end
function P.Enabled()
 if ns.DB and not ns.MainStorageBlocked then return ns.DB.firesideAutomaticBackups~=false end
 local store=recovery();if store and type(store.enabled)=='boolean'then return store.enabled end
 return true
end
function P.Frequency()
 local n=ns.DB and ns.DB.firesideBackupFrequency;return(n==3600 or n==86400)and n or 0
end
function P.Retention()
 local n=ns.DB and ns.DB.firesideBackupRetention;return(n==5 or n==10)and n or 2
end
function P.SetFrequency(value)if value~=0 and value~=3600 and value~=86400 then return false end;ns.DB.firesideBackupFrequency=value;return true end
function P.SetRetention(value)
 if value~=2 and value~=5 and value~=10 then return false end;ns.DB.firesideBackupRetention=value
 -- Rotation only happens after a complete healthy save. A settings click must
 -- not discard an unexamined or damaged checkpoint.
 return true
end
function P.SetEnabled(value)
 if type(value)~='boolean'or not ns.DB then return false end
 ns.DB.firesideAutomaticBackups=value;local store=recovery(true);if store then store.enabled=value end;return true
end
-- Pick one complete generation for all missing roots. Per-root fallback could
-- otherwise combine new reading references with older history. Validation-only
-- parsing checks every payload without expanding an extra live database.
local selectedCheckpoints=setmetatable({},{__mode='k'})
local function completeCheckpoint(generation)
 if type(generation)~='table'or type(generation.roots)~='table'or P.badCopies[generation]then return false end
 for _,base in ipairs(names)do local payload=generation.roots[ns.ClientCompat.StorageName(base)]
  if payload~=false and not pcall(P.Decode,payload,true)then P.badCopies[generation]=true;return false end
 end
 return true
end
local function checkpoint(name,store)
 local generations=store and store.generations;if not generations then return end
 local generation=selectedCheckpoints[generations]
 if not generation or P.badCopies[generation]then
  generation=nil
  for i=1,10 do if completeCheckpoint(generations[i])then generation=generations[i];break end end
  selectedCheckpoints[generations]=generation
 end
 if generation then
  local candidate=generation.roots[name];if candidate==false then return nil,false end
  local ok,result=pcall(P.Decode,candidate);if ok then return result,true end
  P.badCopies[generation]=true;selectedCheckpoints[generations]=nil;return checkpoint(name,store)
 end
end
function P.Retain(name,source)
 if source==nil then return true end
 local store=recovery(true);if not store then return false,'Recovery store needs attention; original retained'end
 local ok,payload=pcall(P.Encode,source);if not ok then return false,'Original could not be preserved; restore refused'end
 if type(store.retained)~='table'or getmetatable(store.retained)then
  if store.retained~=nil then return false,'Retained-original store needs attention'end;store.retained={}
 end
 local copies=store.retained[name];if copies~=nil and(type(copies)~='table'or getmetatable(copies))then return false,'Retained-original store needs attention'end
 copies=copies or{}
 local entries,bytes=0,0
 for _,group in pairs(store.retained)do
  if type(group)~='table'or getmetatable(group)then return false,'Retained-original store needs attention'end
  for _,old in ipairs(group)do
   if type(old)~='table'or type(old.chunks)~='table'or type(old.bytes)~='number'then return false,'Retained-original store needs attention'end
   entries=entries+1;bytes=bytes+old.bytes
  end
 end
 for _,old in ipairs(copies)do
  local equal=old.bytes==payload.bytes and old.checksum==payload.checksum and #old.chunks==#payload.chunks
  if equal then for i,s in ipairs(payload.chunks)do if old.chunks[i]~=s then equal=false;break end end end
  if equal then return true end
 end
 -- Quarantine is never evicted automatically. Reaching the disclosed ceiling
 -- refuses the risky operation while retaining all existing originals.
 if entries>=20 or bytes+payload.bytes>1073741824 then return false,'Quarantine capacity reached (20 originals / 1 GiB). Preserve the save files externally before recovery; no original was discarded'end
 store.retained[name]=copies;copies[#copies+1]=payload;return true
end
local function recovered(name,result,store)
 -- Snapshot creation is optional; recovery/protected reads are always active.
 -- Preserve the separately persisted OFF choice when restoring older settings.
 if name==ns.ClientCompat.StorageName('OlympusChatWardenDB')and store and type(store.enabled)=='boolean'then result.firesideAutomaticBackups=store.enabled end
 _G[name]=result;P.restored[name]=true;P.blocked[name]=nil;return result
end
function P.Read(name,saved)
 if P.blocked[name]then return 'FIRESIDE_SAVED_DATA_UNAVAILABLE'end
 if(type(saved)~='table'or saved.firesideStorage==nil)and not admit(name,saved)then return 'FIRESIDE_SAVED_DATA_UNAVAILABLE'end
 if name==ns.ClientCompat.StorageName('OlympusChatWardenDB')and type(saved)=='table'and saved.firesideStorage==nil then
  local store=recovery();local established=store and(store.primaryExpected==true or next(store.generations)~=nil)
  if established and(saved.schema==nil or next(saved)==nil)then
   P.blocked[name]=true;P.errors[name]='An established main save is unexpectedly empty or lacks its schema; original and recovery checkpoints retained'
   return 'FIRESIDE_SAVED_DATA_UNAVAILABLE'
  end
 end
 if saved==nil then
  local root=recovery()
  if root and root.primaryExpected==true and name==ns.ClientCompat.StorageName('OlympusChatWardenDB')then
   P.blocked[name]=true;P.errors[name]='An established main save is missing. Recovery requires explicit review; checkpoints retained'
   return 'FIRESIDE_SAVED_DATA_UNAVAILABLE'
  end
  if root and root.primaryExpected==true then
   local latest=root.generations[1];local payload=latest and latest.roots and latest.roots[name]
   if payload and payload~=false then P.blocked[name]=true;P.errors[name]='Previously saved auxiliary data is missing; explicit recovery required';return 'FIRESIDE_SAVED_DATA_UNAVAILABLE'end
  end
  local result,found=checkpoint(name,root);if found then return recovered(name,result,root)end
  local recoveryName=ns.ClientCompat.StorageName('FiresideRecoveryDB')
  local expectedMain=root and root.primaryExpected==true and name==ns.ClientCompat.StorageName('OlympusChatWardenDB')
  if found==nil and(expectedMain or root and next(root.generations)~=nil or not root and _G[recoveryName]~=nil)then P.blocked[name]=true;P.errors[name]='Saved data and recovery copies need attention; originals retained';return 'FIRESIDE_SAVED_DATA_UNAVAILABLE'end
 end
 if type(saved)~='table'or saved.firesideStorage==nil then return saved end
 if P.blocked[name]then return 'FIRESIDE_SAVED_DATA_UNAVAILABLE'end
 local ok,result=pcall(P.Decode,saved)
 if ok then if not admit(name,result)then return 'FIRESIDE_SAVED_DATA_UNAVAILABLE'end;_G[name]=result;return result end
 -- A syntactically valid older copy may omit newer accepted history. Damaged
 -- primary data is preserved in place; never silently roll it back.
 -- Preserve malformed bytes in their declared root. Callers receive an invalid
 -- type and their normal recovery path cannot overwrite the retained archive.
 P.blocked[name]=true;P.errors[name]=tostring(result);if ns.Print then ns.Print('Athena’s Safeguard preserved an unreadable save. Use /fireside recovery to review available copies.')end;return 'FIRESIDE_SAVED_DATA_UNAVAILABLE'
end
-- Protected reads can already have decoded an intact envelope before an
-- application/identity check fails. WoW will still serialize its globals at
-- logout. Preserve that known table in compiler-safe form even while semantic
-- writes/checkpoint rotation are blocked; never initialize or repair its data.
local function sealProtectedRoots()
 for _,base in ipairs(names)do
  local name=ns.ClientCompat.StorageName(base);local root=_G[name]
  local known=P.admitted[name]==root or base=='OlympusChatWardenDB'and ns.DB==root
  if known and type(root)=='table'and root.firesideStorage==nil and large(root)then
   local ok,value=pcall(P.Encode,root)
   if ok then _G[name]=value else P.errors[name]='Protected original could not be encoded: '..tostring(value)end
  end
 end
end
function P.Seal()
 if P.restorePending then
  for _,base in ipairs(names)do local name=ns.ClientCompat.StorageName(base);local payload=P.restorePending[name];if payload==false then _G[name]=nil else _G[name]=payload end end
  P.restorePending=nil;return
 end
 local mainName=ns.ClientCompat.StorageName('OlympusChatWardenDB')
 local rawMain=_G[mainName]
 if ns.DB and type(rawMain)=='table'and not rawMain.firesideStorage and rawMain~=ns.DB then
  P.blocked[mainName]=true;P.errors[mainName]='The saved main root was replaced after load; sealing and rotation refused';ns.MainStorageBlocked=P.errors[mainName];sealProtectedRoots();return
 end
 if P.CheckHistory and not P.CheckHistory()then sealProtectedRoots();return end
 local wantBackup=P.Enabled()
 local store=recovery();local now=ns.SafeCall and(ns.SafeCall(GetServerTime)or ns.SafeCall(time))or 0
 local latest=store and store.generations[1];local last=latest and latest.savedAt
 if wantBackup and P.Frequency()>0 and type(now)=='number'and type(last)=='number'and now>=last and now-last<P.Frequency()then wantBackup=false end
 local snapshot={roots={}};local complete=ns.DB and type(_G[mainName])=='table'and not ns.Initializing and not ns.MainStorageBlocked and not(ns.ChronicleStore and(ns.ChronicleStore.loading or ns.ChronicleStore.blocked))and not(ns.StartupErrors and #ns.StartupErrors>0)
 for _,base in ipairs(names)do local name=ns.ClientCompat.StorageName(base);local root=name and _G[name]
  if P.ApplicationRoot and type(root)=='table'and not root.firesideStorage then
   local ok,why=pcall(P.ApplicationRoot,base,root)
   if not ok then P.blocked[name]=true;P.errors[name]=tostring(why);complete=false end
  end
  if P.blocked[name]then complete=false
  elseif type(root)=='table'and not root.firesideStorage and(wantBackup or large(root))then
   local ok,result=pcall(P.Encode,root)
   if ok then snapshot.roots[name]=result;if large(root)then _G[name]=result end
   else P.errors[name]=tostring(result);complete=false end
  elseif type(root)=='table'and not root.firesideStorage then -- Small roots stay native when backups are disabled.
  elseif root==nil then snapshot.roots[name]=false
  elseif type(root)=='table'and root.firesideStorage==1 then snapshot.roots[name]=root
  else complete=false
  end
 end
 -- Two complete checkpoints, in a different addon's file. No partially built
 -- generation is installed, and failed startup never advances the checkpoint.
 if complete and ns.ChronicleStore and ns.ChronicleStore.Residency then local health=ns.ChronicleStore.Residency();if health.errors and health.errors>0 then complete=false end end
 if ns.ChronicleStartupJournal and ns.ChronicleStartupJournal.error or ns.ChronicleStartupLegacy and ns.ChronicleStartupLegacy.error then complete=false end
 if not complete then sealProtectedRoots()end
 local rootManifests
 if complete and P.CurrentRootManifests then local ok,result=pcall(P.CurrentRootManifests);if not ok then P.errors.recovery=tostring(result);return end;rootManifests=result end
 local store=complete and recovery(true)
 -- Persist only a presence marker when optional snapshots are OFF. A missing
 -- main file must still be recognized as a failed read on the next login.
 if store then store.primaryExpected=true;store.clientTarget=ns.ClientBuild and ns.ClientBuild.target;store.enabled=P.Enabled();store.expectedHistory=P.pendingHistory or store.expectedHistory;store.expectedRoots=rootManifests or store.expectedRoots end
 if store and wantBackup then
  store.enabled=true;store.sequence=(type(store.sequence)=='number'and store.sequence or 0)+1;snapshot.sequence=store.sequence;snapshot.savedAt=now;snapshot.verified='Ready startup; typed lossless payloads with length and Adler checksums'
  local generations={snapshot}
  for i=1,10 do local old=store.generations[i]
   if old and P.badCopies[old]then local ok,why=P.Retain('damaged-checkpoint-'..tostring(old.sequence or i),old);if not ok then P.errors.recovery=why;return end
   elseif old and #generations<P.Retention()then generations[#generations+1]=old end
  end
  store.generations=generations
 end
end
function P.PurgeRecovery(erase)
 local name=ns.ClientCompat.StorageName('FiresideRecoveryDB');local root=recovery()
 local expected=root and root.primaryExpected==true or P.blocked[ns.ClientCompat.StorageName('OlympusChatWardenDB')]==true or ns.MainStorageBlocked~=nil
 if _G[name]~=nil then _G[name]={version=1,generations={},enabled=P.Enabled(),clientTarget=root and root.clientTarget,primaryExpected=expected or nil,expectedHistory=erase==false and root and root.expectedHistory or nil,expectedRoots=erase==false and root and root.expectedRoots or nil,erasure=erase~=false and{reason='Explicit data deletion',at=ns.SafeCall and ns.SafeCall(GetServerTime)or 0}or root and root.erasure}end;P.restorePending=nil
end
function P.ScheduleRestore(index)
 if type(index)~='number'or index%1~=0 or index<1 or index>10 then return false,'Choose an available recovery copy'end
 local store=recovery();local candidate=store and store.generations[index];if type(candidate)~='table'or type(candidate.roots)~='table'then return false,'That recovery copy is unavailable'end
 if not P.ValidateGeneration then return false,'Application recovery validator is unavailable; originals retained'end
 local retainedExchange={}
 local exchange=_G[ns.ClientCompat.StorageName('OlympusWardenExchangeDB')]
 if exchange~=nil then
  local ok,value=pcall(function()local r=exchange.firesideStorage and P.Decode(exchange)or P.Decode(P.Encode(exchange));P.ApplicationRoot('OlympusWardenExchangeDB',r);return r end)
  if not ok then return false,'Current sharing identity needs recovery; rollback refused without changing it'end
  retainedExchange.value=value
 end
 local valid,roots=pcall(P.ValidateGeneration,candidate,retainedExchange)
 if not valid then P.badCopies[candidate]=true;P.errors.restore=tostring(roots);return false,'Recovery copy needs application recovery: '..tostring(roots)..'. No saved data was changed'end
 local history=roots.OlympusChatWardenDB and roots.OlympusChatWardenDB.chronicle
 for owner,tombstone in pairs(type(store.erasures)=='table'and store.erasures or{})do
  if history and history.characters[owner]and(type(candidate.sequence)~='number'or candidate.sequence<=(tombstone.revision or 0))then
   return false,'This copy predates an explicit character erase and could resurrect deleted records; restore refused'
  end
 end
 local restore,rootManifests={},{}
 for _,base in ipairs(names)do local name=ns.ClientCompat.StorageName(base);local payload=candidate.roots[name]
  if payload~=false then local ok=pcall(P.Decode,payload,true);if not ok then P.badCopies[candidate]=true;return false,'Recovery copy failed validation; no saved data was changed'end end
  -- Restore cannot opt a player into capture, communication, or sharing. The
  -- current independent deny latch remains authoritative across rollback.
  local root=roots[base]
  if base=='OlympusWardenPrivacyDB'then
   local current=_G[name]
   if current then
    local ok,value=pcall(function()return current.firesideStorage and P.Decode(current)or P.Decode(P.Encode(current))end)
    if not ok or not pcall(P.ApplicationRoot,base,value)then return false,'Current privacy permissions need recovery; restore refused'end
    root=value
   else root={version=1,all={},owners={}}end
   for _,scope in ipairs({'history','capture','conversations','incidents','network'})do
    root.all[scope]=true;for _,row in pairs(root.owners)do row[scope]=true end
   end
  end
  if base=='OlympusChatWardenDB'and root then
   root.firesideAutomaticBackups=P.Enabled()
   if root.chronicle then root.chronicle.enabled=false end
   if root.chatCapture then root.chatCapture.enabled=false end
   root.persistHistory=false
  end
  restore[name]=root and P.Encode(root)or false
  rootManifests[name]=P.RootManifest(base,root)
 end
 -- Preserve the current roots too, before a deliberate rollback. A failed
 -- preservation attempt refuses the entire restore, with originals intact.
 local undo={roots={}}
 for _,base in ipairs(names)do local name=ns.ClientCompat.StorageName(base);local root=_G[name]
  if P.blocked[name]then local ok,why=P.Retain(name,root);if not ok then return false,why end end
  local ok,payload
  if type(root)=='table'and root.firesideStorage==1 then
   ok=pcall(P.Decode,root,true);payload=root
   if not ok then
    -- A corrupt primary is precisely why this restore may be needed. Keep
    -- its literal envelope in quarantine; never mislabel it as a valid undo
    -- payload or require the damaged bytes to validate before recovery.
    local retained,why=P.Retain(name,root);if not retained then return false,why end
    undo.quarantined=undo.quarantined or{};undo.quarantined[name]=true;payload=false;ok=true
   end
  else ok,payload=pcall(P.Encode,root or{})end
  if not ok then return false,'Current save could not be preserved; restore refused'end
  undo.roots[name]=root~=nil and payload or false
 end
 store.undo={undo,store.undo and store.undo[1]or nil}
 store.expectedHistory=P.HistoryManifest(roots.OlympusChatWardenDB)
 store.expectedRoots=rootManifests
 P.restorePending=restore;P.Rearm();return true
end
local function historyInputs()
 local store=recovery();local main=ns.DB
 if not main or ns.MainStorageBlocked or P.blocked[ns.ClientCompat.StorageName('OlympusChatWardenDB')]then return false end
 if not store and _G[ns.ClientCompat.StorageName('FiresideRecoveryDB')]~=nil then
  local name=ns.ClientCompat.StorageName('OlympusChatWardenDB');P.blocked[name]=true;P.errors[name]='Independent recovery metadata is unreadable; primary and recovery files retained';ns.MainStorageBlocked=P.errors[name];return false
 end
 local expected=store and store.expectedHistory
 if store and not expected and store.generations[1]and not store.erasure then
  local payload=store.generations[1].roots and store.generations[1].roots[ns.ClientCompat.StorageName('OlympusChatWardenDB')]
  local decoded,prior=pcall(P.Decode,payload)
  if not decoded then P.errors.recovery='Latest checkpoint needs recovery; rotation refused';return false end
  local valid,value=pcall(P.HistoryManifest,prior)
  if not valid then P.errors.recovery=tostring(value);return false end
  expected=value;store.expectedHistory=value
 end
 return main,expected,store
end
local function historyFailure(reason)
 local name=ns.ClientCompat.StorageName('OlympusChatWardenDB');P.blocked[name]=true;P.errors[name]=tostring(reason);ns.MainStorageBlocked='Previously saved history needs recovery; original data and checkpoints retained'
 return false
end
function P.CheckHistory()
 if not P.HistoryManifest then return true end
 local main,expected,store=historyInputs();if not main then return false end
 local ok,manifest=pcall(function()
  expected=P.ResolveHistoryMarker(expected,store)
  return P.HistoryManifest(main,expected)
 end)
 if ok then local valid,why=pcall(P.CompareHistory,expected,manifest);if not valid then ok=false;manifest=why end end
 if not ok then return historyFailure(manifest)end
 P.pendingHistory=manifest;return true
end
function P.CheckHistoryCooperative(checkpoint)
 local timing=ns.FiresideStartupTiming;local start=timing and timing.Begin('history integrity',true)
 if not P.HistoryManifest then if timing then timing.Finish('history integrity',start)end;return true end
 local main,expected,store=historyInputs();if not main then if timing then timing.Finish('history integrity',start,false)end;return false end
 local probe=coroutine.create(function()
  expected=P.ResolveHistoryMarker(expected,store,coroutine.yield)
  local manifest=P.HistoryManifest(main,expected,coroutine.yield)
  P.CompareHistory(expected,manifest);return manifest
 end)
 while true do
  local ok,value=coroutine.resume(probe)
  if not ok then if timing then timing.Finish('history integrity',start,false)end;return historyFailure(value)end
  if coroutine.status(probe)=='dead'then P.pendingHistory=value;if timing then timing.Finish('history integrity',start)end;return true end
  checkpoint()
 end
end
function P.Report()
 local root=recovery();local copies={};if root then for i=1,10 do local copy=root.generations[i];if copy and not P.badCopies[copy]then copies[#copies+1]={index=i,savedAt=copy.savedAt}end end end
 local invalidRecovery=not root and _G[ns.ClientCompat.StorageName('FiresideRecoveryDB')]~=nil
 local pendingError=ns.ChronicleStartupJournal and ns.ChronicleStartupJournal.error or ns.ChronicleStartupLegacy and ns.ChronicleStartupLegacy.error
 local errors=P.errors;if pendingError then errors={};for k,v in pairs(P.errors)do errors[k]=v end;errors.recording=pendingError end
 return{version=P.VERSION,protected=invalidRecovery or pendingError~=nil or ns.MainStorageBlocked~=nil or next(P.blocked)~=nil or ns.ChronicleStore and ns.ChronicleStore.blocked==true,errors=errors,pendingError=pendingError,restored=P.restored,recoveryCopies=#copies,copies=copies,enabled=P.Enabled(),frequency=P.Frequency(),retention=P.Retention(),primaryExpected=root and root.primaryExpected==true,protection='Always active; failed reads retain originals and block replacement',separateFile=true,encoding='Lossless typed chunks; no executable saved data'}
end
-- Register after static writers, and re-arm after the canonical player's
-- runtime-created logout writer. All producers retain their live table aliases.
local event=CreateFrame('Frame');P.event=event
function P.Rearm()event:UnregisterEvent('PLAYER_LOGOUT');event:RegisterEvent('PLAYER_LOGOUT')end
event:RegisterEvent('PLAYER_LOGIN')
event:SetScript('OnEvent',function(_,kind)if kind=='PLAYER_LOGIN'then P.Rearm()else P.Seal()end end)

if ns.FiresideStartupTiming then P.Read=ns.FiresideStartupTiming.Wrap(P.Read,"saved root decode and admission")end
