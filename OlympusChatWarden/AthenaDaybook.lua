-- A chronological reading projection over the existing permitted Journal APIs.
-- No collectors, raw-route replay, canonical history store or narrator rewrite.
local _,ns=...
local D={VERSION=1,MAX_FACTS=20000,MAX_BLOCKS=260};ns.AthenaDaybook=D
local J=ns.AthenaJournal
local function copy(v) return ns.Athena.Copy(v) end
local function valid(job) return job.provider:Allowed() and job.owner==job.ownerScope end
local function day(at) return type(at)=='number' and at>0 and ns.SafeCall(date,'%Y-%m-%d',at) or nil end
local function inside(e,window) return e and type(e.observedAt)=='number' and e.observedAt>=window.firstAt and e.observedAt<=window.lastAt and (not window.session or e.session==window.session) end
local function read(job,method,...)
 for _=1,100000 do
  if not valid(job) then error('DENIED') end
  local rows,nextPage,checkpoint=method(job.provider,...)
  if rows then coroutine.yield();return rows,nextPage,checkpoint end
  if not ({INDEXING=true,LOAD_WAIT=true,LINK_PENDING=true,building=true,loading=true,pending=true})[nextPage] then error(nextPage or 'UNAVAILABLE') end
  coroutine.yield()
 end;error('SOURCE_WAIT_LIMIT')
end
function D.Catalog(provider,owner)
 local job={provider=provider,owner=owner,ownerScope=owner,status='INDEXING',days={},byKey={},calls=0}
 job.thread=coroutine.create(function()
  local cursor,frontier;local count=0
  repeat
   local rows,nextPage=read(job,provider.Facts,owner,cursor,frontier);cursor=nextPage
   for _,e in ipairs(rows) do
    if e.observer==owner and e.accessScope~='PRIVATE_INCIDENT' and not e.storyPrivateProjection and not (e.sourceContext and e.sourceContext.accessScope=='PRIVATE_INCIDENT') then
     local key=day(e.observedAt)
     if key then
      local row=job.byKey[key]
      if not row then row={key=key,label=key,firstAt=e.observedAt,lastAt=e.observedAt,count=0,gaps=false,calendar='Local calendar date'};job.byKey[key]=row;job.days[#job.days+1]=row end
      row.firstAt=math.min(row.firstAt,e.observedAt);row.lastAt=math.max(row.lastAt,e.observedAt);row.count=row.count+1
      row.gaps=row.gaps or e.family=='collection_gap' or e.family=='recording_stop'
      row.clockUncertain=row.clockUncertain or e.clock~='server'
     end
     count=count+1;if count>=D.MAX_FACTS then job.limited=true;cursor=nil;break end
    end
   end
  until not cursor
  table.sort(job.days,function(a,b) return a.key>b.key end);job.done=true;job.status='READY'
 end)
 return job
end
function D.Pump(job)
 if not valid(job) then job.done=true;job.status='DENIED';job.days={};job.byKey={};job.blocks={};job.refs={};job.thread=nil;return job.status end
 if job.done then return job.status end
 local ok,why=coroutine.resume(job.thread)
 if not ok then job.done=true;job.status=tostring(why):match('([A-Z_]+)$') or 'UNAVAILABLE';job.error=tostring(why);job.blocks=nil end
 return job.status
end
local function periodProvider(base,owner,window)
 local p={demo=base.demo,name='Daybook · '..window.label,JournalStore=base.JournalStore}
 function p:Allowed() return base:Allowed() end
 if base.Identity then function p:Identity(who) return base:Identity(who) end end
 function p:WorldEnvironment() return base.WorldEnvironment and base:WorldEnvironment() end
 if base.WorldQuest then function p:WorldQuest(id,env) return base:WorldQuest(id,env) end end
 function p:StoryContent(kind) return kind~='protections' and base.StoryContent and base:StoryContent(kind) end
 function p:Facts(who,cursor,frontier)
  local rows,nextPage,checkpoint=base:Facts(who,cursor,frontier);if not rows then return nil,nextPage end
  local out={};for _,e in ipairs(rows) do if e.observer==owner and inside(e,window) and not e.storyPrivateProjection then out[#out+1]=e end end
  return out,nextPage,checkpoint
 end
 function p:Activities(who,cursor,frontier)
  local rows,nextPage=base:Activities(who,cursor,frontier);if not rows then return nil,nextPage end
  local out={}
  for _,n in ipairs(rows) do
   if n.observer==owner and n.firstObservedAt>=window.firstAt and n.lastObservedAt<=window.lastAt then out[#out+1]=n end
  end
  return out,nextPage
 end
 function p:Resolve(ref)
  local e,why=base:Resolve(ref)
  if e and e.observer==owner and inside(e,window) and e.accessScope~='PRIVATE_INCIDENT' and not e.storyPrivateProjection then return e end
  return nil,why or 'OUTSIDE_DAYBOOK_WINDOW'
 end
 function p:ConversationsForStory(story,node)
  -- Existing conversation service owns eligibility. Only dated, approved
  -- moments in this period are eligible; no arbitrary live chat is imported.
  local out={}
  for _,moment in ipairs(base.ConversationsForStory and base:ConversationsForStory(story,node) or {}) do
   local first=moment.observedFrom or moment.observedAt or moment.at or moment.firstAt
   local last=moment.observedTo or first
   local overlaps=type(first)=='number'and type(last)=='number'and(last>=window.firstAt and first<=window.lastAt or window.key and day(first)<=window.key and day(last)>=window.key)
   if overlaps and (not window.session or window.session==moment.sessionRef)and(not moment.owner or moment.owner==owner) then out[#out+1]=moment end
  end
  return out
 end
 return p
end
D.PeriodProvider=periodProvider
-- Honest connective annotations fill permitted event families not voiced by
-- the existing Metis scene renderer. They make no inferred services or travel.
local function annotation(f)
 local d,loc=f.details or {},f.location or {};local kind=f.family
 if kind=='location' then return 'The record places this character in '..(loc.subzone or loc.zone or 'an unnamed area')..'. It does not establish the intervening route.'
 elseif kind=='collection_gap' then return 'A recording gap interrupts the account. The intervening activity is unknown.'
 elseif kind=='recording_stop' then return 'Recording stopped here; later events may be absent.'
 elseif kind=='session_start' or kind=='recording_start' then return 'A recorded segment begins here. Earlier activity is not established by this boundary.'
 elseif kind=='instance_enter' then return 'An entry into '..(loc.instanceName or loc.zone or 'an instance')..' was recorded. Entry alone does not establish a full clear.'
 elseif kind=='instance_exit' then return 'An instance exit was recorded. Unobserved encounters remain unknown.'
 elseif kind=='item_received' or kind=='quest_item_received' or kind=='encounter_loot_delivery' then
  return 'The archive records '..(d.itemName or d.itemID and ('item #'..d.itemID) or 'an item receipt')..(d.count and (' × '..d.count) or '')..'. This receipt does not establish a boss drop or a future source of the item.'
 elseif kind=='group_roster' then return 'A dated group roster was observed. It does not establish continuous attendance between roster observations.'
 elseif kind=='level_change' then return 'A level milestone was recorded'..(d.afterLevel and (' at level '..d.afterLevel) or '')..'.'
 elseif kind=='quest_accepted' or kind=='quest_turnin' or kind=='quest_objective' or kind=='quest_removed' or kind=='quest_observed' then
  local what=({quest_accepted='An assignment was accepted',quest_turnin='A quest turn-in was recorded',quest_objective='Quest objective progress was observed',quest_removed='A quest left the recorded log',quest_observed='A quest was observed in the log'})[kind]
  return what..': '..(d.title or d.questID and ('quest #'..d.questID) or 'an unnamed quest')..'.'
 elseif kind=='skill_change' or kind=='spell_learned' then return 'A recorded '..(kind=='spell_learned' and 'spell-learning' or 'skill')..' update occurred. It does not by itself establish a trainer interaction.' end
end
function D.Compose(provider,owner,window)
 local job={provider=provider,owner=owner,ownerScope=owner,status='INDEXING',window=copy(window),refs={},blocks={}}
 job.thread=coroutine.create(function()
  if not window or not day(window.firstAt) or not day(window.lastAt) or window.firstAt>window.lastAt then error('INVALID_WINDOW') end
  local source=periodProvider(provider,owner,window);local library=J.Library();local cursor;local rendered,used,refSet={},{},{};local stages=0
  repeat
   local part=J.New(source,owner,cursor,library)
   while not part.done do if not valid(job) then error('DENIED') end;J.Pump(part);coroutine.yield() end
   if part.status~='READY' then error(part.status) end
   for _,story in ipairs(part.chapterStories or part.stories) do
    local paragraphs,why=ns.Metis.TryStory(story,'Epic');if not paragraphs then error(why or 'NARRATION_UNAVAILABLE') end
    for _,b in ipairs(paragraphs) do
     if #rendered>=D.MAX_BLOCKS then job.limited=true;break end
     local row={id=b.blockId or 'daybook/'..#rendered,text=b.text,kind=b.kind=='quote' and 'quote' or 'body',at=b.at or story.firstObservedAt,source=b,ownerPrivate=b.ownerPrivate,literal=b.literal,recollection=b.recollection,privateMemory=b.privateMemory}
     rendered[#rendered+1]=row;for _,ref in ipairs(b.evidenceRefs or {}) do used[ref]=true;if not refSet[ref] then refSet[ref]=true;job.refs[#job.refs+1]=ref end end
    end
    coroutine.yield()
   end
   cursor=part.nextCursor;stages=stages+1;if stages>=16 then job.limited=true;cursor=nil end
  until not cursor or job.limited
  job.index=library.index;local extra=0
  for i,f in ipairs(job.index and job.index.facts or {}) do
   if inside(f,window) and not f.storyPrivateProjection then
    if #job.refs<D.MAX_FACTS and not refSet[f.evidenceRef] then refSet[f.evidenceRef]=true;job.refs[#job.refs+1]=f.evidenceRef end
    if not used[f.evidenceRef] then local prose=annotation(f)
     if prose and #rendered<D.MAX_BLOCKS then extra=extra+1;rendered[#rendered+1]={id='daybook/observation/'..f.evidenceRef,kind='body',text=prose,at=f.observedAt,source={evidenceRefs={f.evidenceRef},at=f.observedAt}} end
    end
   end
   if i%128==0 then coroutine.yield() end
  end
  table.sort(rendered,function(a,b) return a.at==b.at and a.id<b.id or a.at<b.at end)
  local blocks={{kind='meta',text='ATHENA’S DAYBOOK · PRIVATE DAILY ACCOUNT'},{kind='title',text=window.label},{kind='meta',text=(ns.SafeCall(date,'%H:%M',window.firstAt) or '?')..' – '..(ns.SafeCall(date,'%H:%M',window.lastAt) or '?')..' · '..(window.calendar or 'Local calendar date')},{text='These are the observations retained for this period, not a continuous account of the entire day. Recording gaps and unobserved movement remain unknown.'}}
  local heading
  if window.clockUncertain then blocks[#blocks+1]={kind='meta',text='Some observation times use the local or an unspecified clock; their dates and ordering should be read with that limit.'} end
  for _,b in ipairs(rendered) do
   local label=ns.SafeCall(date,'%H:%M',b.at) or 'Time uncertain'
   if label~=heading then blocks[#blocks+1]={id='time/'..b.id,kind='heading',text=label};heading=label end
   blocks[#blocks+1]=b
  end
  if #rendered==0 then blocks[#blocks+1]={text='No eligible narrated observations are available in this window.'} end
  blocks[#blocks+1]={kind='meta',text='This edition does not infer conversations, trading, training, continuous routes, or quest completions from proximity. Undated/private exchanges stay in Memories unless the existing source service supplies an eligible dated moment.'}
  if job.limited then blocks[#blocks+1]={kind='meta',text='This long period reached the bounded reading limit; this telling is partial. Original history remains unchanged.'} end
  job.blocks=blocks;job.versions={daybook=D.VERSION,metis=ns.Metis.VERSION,calliope=ns.Metis.Calliope and ns.Metis.Calliope.VERSION,author=ns.AthenaLiteraryAuthor and ns.AthenaLiteraryAuthor.VERSION,knowledge=ns.Athena.Knowledge.VERSION,addon=ns.VERSION}
  job.done=true;job.status='READY'
 end)
 return job
end
