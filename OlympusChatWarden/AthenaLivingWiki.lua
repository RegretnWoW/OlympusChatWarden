-- Presentation index over canonical knowledge references. Never SavedVariables.
local _,ns=...
local W={VERSION=1,MAX_RECORDS=100000,MAX_POSTINGS=2000000,BUDGET=96,RESULTS=30,sources={},generation=0}
ns.AthenaLivingWiki=W;ns.WardenDB.LivingWiki=W
W.types={QUEST='Quests',CHAIN='Quest chains',NPC='People & NPCs',CREATURE='Creatures',INSTANCE='Dungeons & raids',BOSS='Bosses',BATTLEGROUND='Battlegrounds',ZONE='Zones',PLACE='Places',FACTION='Factions',EVENT='History & events',ITEM='Items & equipment',LORE='Lore'}
local function copy(v) return ns.Athena.Copy(v) end
local function norm(s) return tostring(s or ''):lower():gsub('’',"'"):gsub('[%p%s]+',' '):match('^%s*(.-)%s*$') end
W.NormalizeText=norm
function W.Key(kind,id)
 kind=type(kind)=='string' and kind:upper();if type(id)=='number' and (id~=id or id%1~=0 or id<1) then return nil end;local k=tostring(id or ''):lower()
 if not W.types[kind] or #k==0 or #k>112 or not k:match('^[%w][%w_%.%-]*$') then return nil end
 return kind:lower()..':'..k
end
function W.ValidKey(key)
 if type(key)~='string' or #key>128 then return false end
 local kind,id=key:match('^(%a+):([%w_%.%-]+)$');return kind and W.Key(kind,id)==key or false
end
function W.RegisterSource(id,source)
 assert(type(id)=='string' and #id<=64 and type(source)=='table' and type(source.Enumerate)=='function' and type(source.Resolve)=='function','Invalid Wiki source adapter')
 W.sources[id]=source;W.Invalidate()
end
function W.Invalidate() W.generation=W.generation+1;W.index=nil;W.queryCache={} end
local function gramKeys(text)
 local out,seen={},{}
 for word in text:gmatch('%S+') do for i=1,#word-2 do local g=word:sub(i,i+2);if not seen[g] then seen[g]=true;out[#out+1]=g end end end
 return out
end
local function terms(row)
 if row.terms then return row.terms end
 local out,seen={},{};local function add(text) local t=norm(text);if not seen[t] then seen[t]=true;out[#out+1]=t end end
 add(row.title);for _,alias in ipairs(row.aliases) do add(alias) end;row.terms=out;return out
end
local function postings(index)
 if index.postingsReady then return end
 if not index.postingThread then index.postingThread=coroutine.create(function()
  local lists={};local count=0
  for i,row in ipairs(index.rows) do
   local seen={};for _,t in ipairs(terms(row)) do for _,g in ipairs(gramKeys(t)) do if not seen[g] then
    seen[g]=true
    if count<W.MAX_POSTINGS then local list=lists[g] or {};lists[g]=list;list[#list+1]=i;count=count+1 else index.truncated=true end
   end end end
   if i%W.BUDGET==0 then coroutine.yield() end
  end
  index.postings={};local visited=0
  for g,list in pairs(lists) do
   -- Three bytes address all MAX_RECORDS subjects. Rebuildable postings keep
   -- neither boxed Lua numbers nor per-row duplicate bigram/unigram lists.
   for i,n in ipairs(list) do list[i]=string.char(n%256,math.floor(n/256)%256,math.floor(n/65536)) end
   index.postings[g]=table.concat(list);lists[g]=nil;visited=visited+1
   if visited%W.BUDGET==0 then coroutine.yield() end
  end
  index.postingCount=count;index.postingsReady=true
 end) end
 while not index.postingsReady do
  local ok,why=coroutine.resume(index.postingThread);if not ok then error(why) end
  if not index.postingsReady then coroutine.yield() end
 end
 index.postingThread=nil
end
function W.ReleaseSearch()
 local index=W.index;if not index or not index.done or index.postingThread then return false end
 index.postings=nil;index.postingsReady=nil;index.postingThread=nil;index.postingCount=0
 for _,row in ipairs(index.rows) do row.terms=nil end
 if ns.AthenaLoreCodex and ns.AthenaLoreCodex.ReleaseDerived then ns.AthenaLoreCodex.ReleaseDerived() end
 return true
end
function W.BeginIndex()
 if W.index then return W.index end
 local index={generation=W.generation,status='INDEXING',rows={},byKey={},aliases={},postings={},idPostings={},counts={},postingCount=0,errors={}}
 W.index=index
 index.thread=coroutine.create(function()
  local sourceIDs={};for id in pairs(W.sources) do sourceIDs[#sourceIDs+1]=id end;table.sort(sourceIDs)
  local visits=0
  local function emit(sourceID,id,meta)
   visits=visits+1
   if visits%W.BUDGET==0 then coroutine.yield() end
   if type(meta)~='table' or not W.ValidKey(meta.key) or not W.types[meta.kind] or type(meta.title)~='string' or #meta.title==0 or #meta.title>256 then return end
   local row=index.byKey[meta.key]
   if not row then
    if #index.rows>=W.MAX_RECORDS then index.truncated=true;return end
    row={key=meta.key,kind=meta.kind,title=meta.title,aliases={},references={},nativeID=meta.nativeID,icon=meta.icon,category=meta.category}
    index.rows[#index.rows+1]=row;row.ordinal=#index.rows;index.byKey[row.key]=row
    index.counts[row.kind]=(index.counts[row.kind] or 0)+1
   end
   row.nativeID=row.nativeID or meta.nativeID;row.icon=row.icon or meta.icon
   if #row.references>=16 then index.truncated=true;return end
   row.references[#row.references+1]={source=sourceID,id=id}
   if meta.kind=='BOSS' and row.kind~='BOSS' or meta.kind=='CREATURE' and row.kind=='NPC' then index.counts[row.kind]=index.counts[row.kind]-1;row.kind=meta.kind;index.counts[row.kind]=(index.counts[row.kind] or 0)+1 end
   local function alias(value)
    if type(value)~='string' or #value>256 or value==row.title or #row.aliases>=16 then return end
    for _,prior in ipairs(row.aliases) do if prior==value then return end end;row.aliases[#row.aliases+1]=value
   end
   alias(meta.title);for _,value in ipairs(meta.aliases or {}) do alias(value) end
   for _,key in ipairs(meta.redirects or {}) do if W.ValidKey(key) and not index.byKey[key] then index.aliases[key]=row.key end end
   if meta.nativeID then local k=tostring(meta.nativeID);index.idPostings[k]=index.idPostings[k] or {};index.idPostings[k][row.key]=true end
  end
  for _,sourceID in ipairs(sourceIDs) do
   local source=W.sources[sourceID]
   -- Adapter exceptions fail this index visibly; do not silently publish a half catalogue.
   source.Enumerate(function(id,meta) emit(sourceID,id,meta) end)
  end
  index.sortedByKind={ALL={}}
  for _,row in ipairs(index.rows) do local list=index.sortedByKind[row.kind] or {};index.sortedByKind[row.kind]=list;list[#list+1]=row;index.sortedByKind.ALL[#index.sortedByKind.ALL+1]=row end
  for _,list in pairs(index.sortedByKind) do table.sort(list,function(a,b) return a.title==b.title and a.key<b.key or a.title<b.title end) end
  index.status='READY';index.done=true
 end)
 return index
end
function W.PumpIndex()
 local index=W.BeginIndex();if index.done then return index.status end
 local ok,err=coroutine.resume(index.thread)
 if not ok then index.status='FAILED';index.done=true;index.error=tostring(err) end
 return index.status
end
function W.Canonical(key)
 local index=W.BeginIndex();return index.aliases[key] or key
end
function W.BeginSearch(query,kind,offset)
 W.lastSearchAt=GetTime and GetTime() or 0
 local index=W.BeginIndex();query=type(query)=='string' and query:sub(1,160):match('^%s*(.-)%s*$') or '';local q=norm(query)
 local job={query=query,kind=kind,offset=math.max(0,math.floor(tonumber(offset) or 0)),generation=index.generation,rows={},done=false}
 job.thread=coroutine.create(function()
  if index.status~='READY' then job.waiting=true;return end
  if q=='' then
   local list=index.sortedByKind[kind or 'ALL'] or {};job.total=#list
   for i=job.offset+1,math.min(#list,job.offset+W.RESULTS) do job.rows[#job.rows+1]=list[i] end
   job.nextOffset=job.offset+W.RESULTS<#list and job.offset+W.RESULTS or nil;job.done=true;return
  end
  local candidates,seen={},{}
  local function add(row) if row and not seen[row.key] then seen[row.key]=true;candidates[#candidates+1]=row end end
  local exact=index.byKey[W.Canonical(query:lower())];add(exact)
  local numeric=query:match('^%s*#?(%d+)%s*$');if numeric then for key in pairs(index.idPostings[numeric] or {}) do add(index.byKey[key]) end end
  if not (exact and W.ValidKey(query:lower())) then
   local grams=gramKeys(q)
   if #grams==0 then
    -- Short/initial-based queries retain full alias and substring quality.
    for i,row in ipairs(index.rows) do
     local match=#q~=1
     if not match then for _,term in ipairs(terms(row)) do for word in term:gmatch('%S+') do if word:sub(1,1)==q then match=true;break end end;if match then break end end end
     if match then add(row) end;if i%W.BUDGET==0 then coroutine.yield() end
    end
   else
    postings(index);local shortest
    for _,g in ipairs(grams) do local list=index.postings[g];if not list then shortest='';break end;if not shortest or #list<#shortest then shortest=list end end
    for at=1,#(shortest or ''),3 do
     local a,b,c=shortest:byte(at,at+2);add(index.rows[a+b*256+c*65536])
     if at%(W.BUDGET*3)==1 then coroutine.yield() end
    end
   end
  end
  local ranked={}
  for i,row in ipairs(candidates) do
   local score=row==exact and 2000 or numeric and row.nativeID and tostring(row.nativeID)==numeric and 1800 or q=='' and 10 or 0
   for n,term in ipairs(terms(row)) do
    if term==q then score=math.max(score,n==1 and 1200 or 1100)
    elseif term:sub(1,#q)==q then score=math.max(score,900)
    elseif term:find(q,1,true) then score=math.max(score,600) end
   end
   if score>0 and (not kind or kind=='ALL' or row.kind==kind) then ranked[#ranked+1]={row=row,score=score} end
   if i%W.BUDGET==0 then coroutine.yield() end
  end
  table.sort(ranked,function(a,b) return a.score==b.score and (a.row.title==b.row.title and a.row.key<b.row.key or a.row.title<b.row.title) or a.score>b.score end)
  job.total=#ranked;job.rows={}
  for i=job.offset+1,math.min(#ranked,job.offset+W.RESULTS) do job.rows[#job.rows+1]=ranked[i].row end
  job.nextOffset=job.offset+W.RESULTS<#ranked and job.offset+W.RESULTS or nil;job.done=true
 end)
 return job
end
function W.PumpSearch(job)
 if job.generation~=W.generation then job.done=true;job.error='INDEX_CHANGED';return 'STALE' end
 if W.BeginIndex().status~='READY' then return W.PumpIndex() end
 if job.waiting then return 'WAITING' end
 if not job.done then local ok,err=coroutine.resume(job.thread);if not ok then job.done=true;job.error=tostring(err) end end
 return job.done and 'READY' or 'SEARCHING'
end
function W.Resolve(key,context)
 local index=W.BeginIndex();if index.status~='READY' then return nil,index.status end
 key=W.Canonical(key);local row=index.byKey[key];if not row then return nil,'NOT_INDEXED' end
 local article={key=key,kind=row.kind,title=row.title,nativeID=row.nativeID,icon=row.icon,sections={},related={},sources={},fields={},quickFacts={},questNavigation={},dungeonQuests={},referenceOnly=true}
 local seen={}
 for _,ref in ipairs(row.references) do
  local source=W.sources[ref.source];local value=source and source.Resolve(ref.id,context)
  if value then
   local priority=value.priority or 50
   if type(value.summary)=='string' and value.summary~='' and priority>(article.summaryPriority or -1) then article.summary=value.summary;article.summaryPriority=priority end
   article.icon=article.icon or value.icon
   article.expectedBosses=math.max(article.expectedBosses or 0,value.expectedBosses or 0)
   article.locked=article.locked or value.locked;article.lockReason=article.lockReason or value.lockReason
   article.rosterComplete=article.rosterComplete or value.rosterComplete
   for _,fact in ipairs(value.quickFacts or {}) do
    local token='fact/'..fact.label..'/'..fact.value..'/'..(fact.key or '')
    if not seen[token] then seen[token]=true;article.quickFacts[#article.quickFacts+1]=fact end
    if fact.sourceURL and not seen[fact.sourceURL] then seen[fact.sourceURL]=true;article.sources[#article.sources+1]=fact.sourceURL end
   end
   for _,step in ipairs(value.questNavigation or {}) do article.questNavigation[#article.questNavigation+1]=step end
   for _,quest in ipairs(value.dungeonQuests or {}) do
    if not seen['dungeon/'..quest.key] then seen['dungeon/'..quest.key]=true;article.dungeonQuests[#article.dungeonQuests+1]=quest end
   end
   for field,v in pairs(value.fields or {}) do if v~='UNKNOWN' and v~=nil and article.fields[field]==nil then article.fields[field]=v end end
   for _,section in ipairs(value.sections or {}) do
    if type(section.text)=='string' and section.text~='' and section.text~='UNKNOWN' and not seen[section.text] then article.sections[#article.sections+1]=section;seen[section.text]=true end
   end
   for _,other in ipairs(value.related or {}) do
    local destination=W.Canonical(type(other)=='table' and other.key or other)
    if destination~=key and index.byKey[destination] and not seen[destination] then article.related[#article.related+1]={key=destination,label=type(other)=='table' and other.label or index.byKey[destination].title,role=type(other)=='table' and other.role,order=type(other)=='table' and other.order};seen[destination]=true end
   end
   for _,sourceRef in ipairs(value.sources or {}) do if not seen[sourceRef] then article.sources[#article.sources+1]=sourceRef;seen[sourceRef]=true end end
  end
 end
 if article.rosterComplete and article.expectedBosses then local found=0;for _,r in ipairs(article.related) do if r.role=='Boss' then found=found+1 end end;if found<article.expectedBosses then article.rosterComplete=false;article.incompleteRelations=true end end
 article.summary=article.summary or (#article.sections>0 and article.sections[1].text) or 'A named reference in the bundled Warcraft knowledge. Further descriptions have not been verified in this edition.'
 return article
end
-- The private history projection is built through the existing source reader.
-- No gameplay collector, saved history schema or Journal reader is changed.
function W.Context(owner)
 owner=owner or ns.Chronicle.Owner();local K=ns.Athena.Knowledge
 local reader=ns.AthenaJournalWindow and ns.AthenaJournalWindow.window and ns.AthenaJournalWindow.window.reader
 local index=reader and reader.owner==owner and reader.library and reader.library.index
 if index and index.status=='READY' and index.provider:Allowed() then return K.Context('chronicle',owner,{index=index}),index end
 local state=W.history
 if state and state.owner==owner and state.provider:Allowed() then
  if state.index.status=='READY' then return K.Context('chronicle',owner,{index=state.index}),state.index end
 end
 return K.Context('chronicle',owner),nil
end
function W.StartHistory(owner)
 owner=owner or ns.Chronicle.Owner()
 if W.history and W.history.owner==owner and W.history.provider:Allowed() then return W.history end
 local provider=ns.AthenaJournal.Live();if not provider:Allowed() then W.history=nil;return nil,'DENIED' end
 provider.PrivateFacts=nil -- Wiki never requests the private protection/memory folios.
 W.history={owner=owner,provider=provider,index=ns.AthenaStoryIndex.New(provider,owner)};return W.history
end
function W.PumpHistory()
 local h=W.history;if not h then return end
 if h.owner~=ns.Chronicle.Owner() or not h.provider:Allowed() then W.history=nil;return 'DENIED' end
 return ns.AthenaStoryIndex.Pump(h.index)
end
function W.Adventures(key,owner)
 owner=owner or ns.Chronicle.Owner();if owner~=ns.Chronicle.Owner() then return {},'OWNER_SCOPE' end
 local ctx,index=W.Context(owner);if not ctx or not ns.Athena.Knowledge.ContextAllowed(ctx) or not index then return {},'PRIVATE_HISTORY_UNAVAILABLE' end
 local article=W.Resolve(key,ctx);if not article then return {} end
 local out={};local row=W.index.byKey[article.key];local names={[norm(row.title)]=true};for _,a in ipairs(row.aliases) do names[norm(a)]=true end
 local function work()
  local function permitted() return owner==ns.Chronicle.Owner() and ns.Athena.Knowledge.ContextAllowed(ctx) and index.provider:Allowed() end
  local function clear() for i=#out,1,-1 do out[i]=nil end end
  if not permitted() then clear();return end
  for i,f in ipairs(index.facts) do
   local d,loc=f.details or {},f.location or {};local id=tonumber(article.key:match(':(%d+)$'));local match=false
   if article.kind=='QUEST' then match=id and d.questID==id
   elseif article.kind=='NPC' or article.kind=='CREATURE' or article.kind=='BOSS' then match=id and (d.npcID==id or d.creatureID==id or d.entityID==id) or names[norm(d.npcName or d.creatureName or d.bossName)]
   elseif article.kind=='ITEM' then match=id and d.itemID==id
   else match=names[norm(loc.instanceName or loc.zone)] or names[norm(d.place or d.locationName)] end
   if match and not f.storyPrivateProjection and #out<40 then out[#out+1]={ref=f.evidenceRef,sourceRef=f.sourceRecordRef,at=f.observedAt,kind=f.family,place=loc.zone or loc.instanceName,owner=owner} end
   if i%128==0 then coroutine.yield();if not permitted() then clear();return end end
  end
  if not permitted() then clear();return end
  table.sort(out,function(a,b) return (a.at or 0)>(b.at or 0) end)
 end
 return out,'READING',coroutine.create(work)
end

-- Article keys and cached discussions remain usable after search scratch is freed.
if CreateFrame then
 local idle=CreateFrame('Frame');local elapsed=0
 idle:SetScript('OnUpdate',function(_,dt)
  elapsed=elapsed+(dt or 0);if elapsed<15 then return end;elapsed=0
  local route=ns.UI2 and ns.UI2.route
  local visible=ns.UI2 and ns.UI2.window and ns.UI2.window:IsShown() and route and (route.page=='search' or route.page=='wiki' and not route.key)
  if not visible and W.lastSearchAt and GetTime()-W.lastSearchAt>90 then W.ReleaseSearch();W.lastSearchAt=nil end
 end)
end
