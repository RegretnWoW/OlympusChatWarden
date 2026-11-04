-- One Wiki destination in the existing UI2 shell and Back/Forward history.
local _,ns=...
local W,U,C,F,E,N=ns.AthenaLivingWiki,ns.UI2,ns.UI2Components,ns.UI2Forms,ns.UI2LayoutEngine,ns.AetherNet
local P={};ns.AthenaWikiUI=P
local specs={};local authored={columns={8,4},cards={}}
for i,pair in ipairs({{'search','Athena’s Living Wiki','header'},{'identity','Article','header'},{'navigation','Explore','center'},{'results','Search results','left'},{'overview','Overview','left'},{'appearance','Appearance & environment','left'},{'history','Lore & history','left'},{'gameplay','Gameplay','left'},{'encounters','Encounters','left'},{'related','Related articles','center'},{'adventures','My Adventures','center'},{'discussion','Community discussion','left'},{'sources','Sources','center'},{'status','Status','header'}}) do
 local header=pair[3]=='header';local span=header and 12 or pair[3]=='left' and 8 or 4
 specs[#specs+1]={id=pair[1],label=pair[2],region=pair[3],span=span,minSpan=header and 12 or 3,maxSpan=12,minWidth=header and 280 or 300,canMove=not header,canResize=not header,canHide=pair[1]~='search',canCollapse=not header,system=pair[1]=='status'}
 authored.cards[#authored.cards+1]={id=pair[1],region=pair[3],order=i,span=span,hidden=false,collapsed=false}
end
E.Register('wiki',specs);ns.UI2DefaultLayouts.templates.wiki=authored
local function row(title,detail,fn,more) local r=more or {};r.title=title;r.detail=detail;r.activate=fn;return r end
local function prose(title,text) return row(title,text,nil,{stacked=true,wrap=true,height=64}) end
local function caption(s) return row(s,nil,nil,{kind='caption',wrap=true,height=48}) end
local function block(out,id,title,rows,extra) local b=extra or {};b.id=id;b.title=title;b.rows=rows;b.anchor=b.anchor or id;out[#out+1]=b;return b end
local function refresh() if U.route and U.route.page=='wiki' then U.Refresh(true) end end
function W.Open(key,options)
 options=options or {};if key and not W.ValidKey(key) then return false,'EXACT_WIKI_ID_REQUIRED' end
 return U.Open({page='wiki',key=key,owner=ns.Chronicle.Owner(),query=options.query,wikiKind=options.kind or 'ALL',wikiOffset=options.offset or 0,discussionPage=options.discussionPage,factOffset=options.factOffset,jump=options.jump})
end
U.OpenWiki=W.Open
local state={};P.state=state
function P.InvalidatePrivate()
 W.history=nil;state.adventures=nil;state.adventureThread=nil;state.article=nil;state.historyIndex=nil
end
local driver=CreateFrame('Frame')
local function allowedHistory()
 return W.history and W.history.owner==ns.Chronicle.Owner() and W.history.provider:Allowed() or false
end
function P.Wake()
 if driver:GetScript('OnUpdate') then return end
 local elapsed,dirty=0,false
 driver:SetScript('OnUpdate',function(self,dt)
  if not U.route or U.route.page~='wiki' or not U.window or not U.window:IsShown() then self:SetScript('OnUpdate',nil);return end
  elapsed=elapsed+(dt or .016)
  if not ns.Membership.Allowed() then P.InvalidatePrivate();self:SetScript('OnUpdate',nil);return end
  local index=W.BeginIndex()
  if not index.done then for _=1,4 do W.PumpIndex();if index.done then break end end;dirty=true end
  if index.status=='READY' and state.job and not state.job.done then W.PumpSearch(state.job);dirty=true end
  if W.history and not W.history.index.done then W.PumpHistory();dirty=true end
  if W.history and not allowedHistory() then P.InvalidatePrivate();dirty=true end
  if state.adventureThread and coroutine.status(state.adventureThread)~='dead' then
   local ok=coroutine.resume(state.adventureThread);if not ok then state.adventures={};state.adventureThread=nil end;dirty=true
  end
  if elapsed>=.15 then
   elapsed=0
   -- Revalidate owner permissions even when the public catalogue is idle.
   if state.privateOwner and state.privateOwner~=ns.Chronicle.Owner() then P.InvalidatePrivate();dirty=true end
   if dirty then dirty=false;refresh() end
  end
 end)
end
local function selectType(route)
 local choices={{'ALL','All subjects'}};for kind,label in pairs(W.types) do choices[#choices+1]={kind,label} end;table.sort(choices,function(a,b) return a[2]<b[2] end)
 F.Form({title='Search the Living Wiki',fields={{key='query',label='Name, alias, or exact ID',value=route.query or ''},{key='kind',label='Subject category',value=route.wikiKind or 'ALL',choices=choices}},submitLabel='Search',submit=function(v) W.Open(nil,{query=v.query,kind=v.kind});return true end})
end
local function revealReference()
 local ctx=W.Context(ns.Chronicle.Owner());if not ctx then return F.Feedback(false,'Athena reference permissions are unavailable for this character.') end
 local ticket,why=ns.Athena.Knowledge.RequestReveal(ctx,'ALL');if not ticket then return F.Feedback(false,why) end
 return F.Confirm('Reveal reference spoilers for this character?',
  'This changes the existing Athena spoiler choice for both the Wiki and your books. It can reveal eligible quest conclusions and later reference chapters. It never completes quests or changes recorded adventures.',function()
   local ok,reason=ns.Athena.Knowledge.ConfirmReveal(ctx,ticket);if ok then state.article=nil;state.request=nil;refresh() end;return ok,reason
  end)
end
local function discussionRows(article,route)
 return{caption('Discuss Warcraft with the community in the Agora. Articles do not have separate public Walls.'),row('Open the Agora','World and predefined rooms',function()ns.AetherPosts.Open({room='world'})end,{height=48}),row('Draft a discussion about '..article.title,'Review before publication',function()ns.AetherPosts.Composer({room='world',body=article.title..': ',spoiler=false,tags={'lore'}})end,{height=55})}
end
local function Article(out,route)
 local ctx,index=W.Context(ns.Chronicle.Owner());local article,why=W.Resolve(route.key,ctx)
 if not article then block(out,'status','Article unavailable',{caption(why=='NOT_INDEXED' and 'This subject is not in the installed reference edition. Search by name or return to the previous article.' or 'The knowledge index is still being prepared.')});return end
 state.article=article
 local identity={row(article.title,nil,nil,{kind='hero',size=29,height=54,icon=article.icon}),caption((W.types[article.kind] or 'Warcraft reference')..' · Source-backed encyclopedia')}
 if #(article.quickFacts or {})>0 then
  identity[#identity+1]=row('Quick Facts',nil,nil,{kind='section',height=30})
  local qualifications,seenQual={},{}
  local start=math.max(0,math.floor(tonumber(route.factOffset) or 0));local limit=16
  for i=start+1,math.min(start+limit,#article.quickFacts) do local fact=article.quickFacts[i]
   local key=fact.key and W.Canonical(fact.key);local linked=key and W.index.byKey[key]
   identity[#identity+1]=row(fact.label,fact.value,linked and function() W.Open(key) end or nil,{height=30,wrap=true,widths={.28,.72},itemLink=key and key:match('^item:%d+$') and ('item:'..key:match(':(%d+)$')) or nil})
   if fact.qualification and not seenQual[fact.qualification] then seenQual[fact.qualification]=true;qualifications[#qualifications+1]=fact.qualification end
  end
  local actions={}
  if start>0 then actions[#actions+1]={title='Previous facts',activate=function() W.Open(article.key,{factOffset=math.max(0,start-limit)}) end} end
  if start+limit<#article.quickFacts then actions[#actions+1]={title='More facts',activate=function() W.Open(article.key,{factOffset=start+limit}) end} end
  if #actions>0 then identity[#identity+1]={actions=actions,height=34} end
  if #qualifications>0 then identity[#identity+1]=caption(table.concat(qualifications,' · ')) end
 end
 if article.fields.itemID then identity[#identity+1]=row('Item tooltip','Hover to inspect in the current client',nil,{height=32,itemLink='item:'..article.fields.itemID}) end
 if #(article.questNavigation or {})>0 then
  identity[#identity+1]=row('Quest chain · known steps and branches',nil,nil,{kind='section',height=30})
  for _,step in ipairs(article.questNavigation) do if step.role:find('Previous',1,true) then local key=step.key;identity[#identity+1]=row(step.role,step.label..' →',function() W.Open(key) end,{wrap=true,height=34}) end end
  identity[#identity+1]=row('Current quest',article.title,nil,{height=30})
  for _,step in ipairs(article.questNavigation) do if step.role:find('Next',1,true) then local key=step.key;identity[#identity+1]=row(step.role,'→ '..step.label,function() W.Open(key) end,{wrap=true,height=34}) end end
 end
 if #(article.dungeonQuests or {})>0 then
  identity[#identity+1]=row('Related dungeon quests',nil,nil,{kind='section',height=30})
  for _,quest in ipairs(article.dungeonQuests) do local key=quest.key;identity[#identity+1]=row(quest.label,'Open quest',function() W.Open(key) end,{height=32,wrap=true}) end
 end
 block(out,'identity',article.title,identity,{paper=false,header=false})
 local nav={row('Search all subjects','One search. All of Azeroth.',function() W.Open() end)}
 for _,pair in ipairs({{'overview','Overview'},{'history','Lore & history'},{'gameplay','Gameplay'},{'adventures','My Adventures'},{'discussion','Community'}}) do local anchor=pair[1];nav[#nav+1]=row(pair[2],nil,function() U.canvas:Jump(anchor) end) end
 block(out,'navigation','In this article',nav)
 local sections={overview={},appearance={},history={},gameplay={}}
 sections.overview[1]=caption(article.summary)
 if article.locked then
  sections.overview[#sections.overview+1]=caption('Some quest-derived passages are concealed by the current character’s stage, source eligibility, or spoiler settings.')
  sections.overview[#sections.overview+1]={actions={{title='Spoiler settings',activate=revealReference}},height=40}
 end
 for _,part in ipairs(article.sections) do
  local title=part.title:lower();local lane=title:find('appearance',1,true) or title:find('environment',1,true) or title:find('location',1,true)
  local group=lane and 'appearance' or (title:find('history',1,true) or title:find('lore',1,true) or title:find('background',1,true) or title:find('motivation',1,true) or title:find('relationship',1,true)) and 'history' or title=='overview' and 'overview' or 'gameplay'
  sections[group][#sections[group]+1]=prose(part.title,part.text)
 end
 local gameplay=sections.gameplay
 if article.fields.requiredLevel then gameplay[#gameplay+1]=row('Required level',tostring(article.fields.requiredLevel)) end
 if article.fields.level then gameplay[#gameplay+1]=row('Reference level',tostring(article.fields.level)) end
 if article.fields.stage then gameplay[#gameplay+1]=row('Your recorded quest stage',({[0]='Not recorded',[2]='Accepted',[3]='Objectives observed',[4]='Turned in'})[article.fields.stage] or 'Observed') end
 for _,id in ipairs({'overview','appearance','history','gameplay'}) do if #sections[id]>0 then block(out,id,({overview='Overview',appearance='Appearance & environment',history='Lore & history',gameplay='Gameplay & objectives'})[id],sections[id]) end end
 local encounters,links={},{}
 for _,ref in ipairs(article.related) do local item=ref;local indexed=W.index.byKey[item.key]
  local target=(ref.role=='Boss' or indexed and indexed.kind=='BOSS') and encounters or links
  target[#target+1]=row((ref.order and tostring(ref.order)..'. ' or '')..(ref.label or indexed.title),ref.role,function() W.Open(item.key) end,{wrap=true,height=44})
 end
 if article.kind=='INSTANCE' then
  if #encounters>0 then table.insert(encounters,1,caption(article.rosterComplete and 'Boss roster supplied by this reference edition.' or 'Catalogued encounters only. This edition does not establish a complete or currently available boss roster.'))
  else encounters[1]=caption('The installed reference does not include a verified boss roster for this location. A Codex roster will appear here when that source is merged.') end
 end
 if #encounters>0 then block(out,'encounters','Bosses & encounters',encounters) end
 if #links>0 then block(out,'related','Related articles',links) end
 local privateRows={caption('Private to this character. Community contributions never create adventure evidence.')}
 if state.historyIndex~=index or state.privateKey~=article.key then
  state.historyIndex=index;state.privateKey=article.key;state.privateOwner=ns.Chronicle.Owner()
  local rows,status,thread=W.Adventures(article.key,state.privateOwner);state.adventures=rows;state.adventureThread=thread;state.privateStatus=status
 end
 if not index or not ctx or not ns.Athena.Knowledge.ContextAllowed(ctx) then state.adventures={};privateRows[#privateRows+1]=caption('No eligible personal-history projection is currently available.')
 elseif state.adventureThread and coroutine.status(state.adventureThread)~='dead' then privateRows[#privateRows+1]=caption('Reading your permitted observations…')
 elseif #(state.adventures or {})==0 then privateRows[#privateRows+1]=caption('No matching source-backed interaction is present in the permitted archive.') end
 for _,fact in ipairs(state.adventures or {}) do local entry=fact
  privateRows[#privateRows+1]=row((fact.kind or 'Observation'):gsub('_',' '),C.Stamp(fact.at),function()
   local currentContext,currentIndex=W.Context(ns.Chronicle.Owner())
   if entry.owner~=ns.Chronicle.Owner() or not currentIndex or not currentContext or not ns.Athena.Knowledge.ContextAllowed(currentContext) then return F.Feedback(false,'This private evidence is no longer permitted in the current character context.') end
   F.Form({title='Your recorded observation',help='Owner-private source evidence. No community publication is performed.',fields={{key='source',label='Source reference',value=entry.ref,readOnly=true},{key='place',label='Recorded place',value=entry.place or 'Not recorded',readOnly=true}},cancelLabel='Close'})
  end,{wrap=true,height=46})
 end
 privateRows[#privateRows+1]=row('Refresh history',nil,function() P.InvalidatePrivate();W.StartHistory();P.Wake();refresh() end)
 block(out,'adventures','My Adventures',privateRows)
 block(out,'discussion','Community · questions & tips',discussionRows(article,route))
 local sources={caption('Reference sources are separate from community opinions and recorded personal history.')}
 for i,url in ipairs(article.sources) do if i>8 then break end;local link=url
  sources[#sources+1]=row(url:match('^https?://([^/]+)') or 'Bundled source','View source link',function() F.Form({title='Reference source',fields={{key='url',label='Source URL',value=link,readOnly=true}},cancelLabel='Close'}) end,{wrap=true,height=42})
 end
 block(out,'sources','About these references',sources)
end
function P.Blocks(route)
 P.Wake();local out={};local index=W.BeginIndex()
 block(out,'search','Athena’s Living Wiki',{caption('One search. All of Azeroth. Use the search bar above for names, aliases, or IDs such as quest:65.'),{actions={{title='Search & filter',activate=function() selectType(route) end},{title='My history',activate=function() U.Open({page='overview',subsection='search',query=route.query or ''}) end}},height=40}})
 if index.status~='READY' then
  block(out,'status',index.status=='FAILED' and 'Reference index unavailable' or 'Opening the encyclopedia',{caption(index.status=='FAILED' and 'A knowledge adapter failed. Existing references and saved history have been preserved.' or 'Preparing a compact offline search index…')});return out,index.status~='FAILED'
 end
 if route.key then
  if not W.history then W.StartHistory(ns.Chronicle.Owner()) end
  Article(out,route);return out,false
 end
 local request=tostring(route.query or '')..'/'..tostring(route.wikiKind)..'/'..tostring(route.wikiOffset)..'/'..index.generation
 if state.request~=request then state.request=request;state.job=W.BeginSearch(route.query,route.wikiKind,route.wikiOffset);state.article=nil end
 if not state.job.done then W.PumpSearch(state.job);block(out,'status','Searching Azeroth',{caption('Matching indexed subjects…')});return out,true end
 local rows={};local ctx=W.Context(ns.Chronicle.Owner());local groups,order={},{}
 for _,result in ipairs(state.job.rows) do if not groups[result.kind] then groups[result.kind]={};order[#order+1]=result.kind end;groups[result.kind][#groups[result.kind]+1]=result end
 for _,kind in ipairs(order) do
  rows[#rows+1]=row(W.types[kind],nil,nil,{kind='section',height=32})
  for _,result in ipairs(groups[kind]) do local item=result;local article=W.Resolve(result.key,ctx)
   rows[#rows+1]=row(result.title,article and article.summary or 'Bundled reference',function() W.Open(item.key) end,{stacked=true,wrap=true,height=88,icon=result.icon})
  end
 end
 if #rows==0 then rows[1]=caption('No indexed subject matches this search. Try a partial name, an alias, or a typed ID. Uninstalled Codex content is not invented.') end
 local paging={}
 if (route.wikiOffset or 0)>0 then paging[#paging+1]={title='Previous results',activate=function() W.Open(nil,{query=route.query,kind=route.wikiKind,offset=math.max(0,route.wikiOffset-W.RESULTS)}) end} end
 if state.job.nextOffset then paging[#paging+1]={title='More results',activate=function() W.Open(nil,{query=route.query,kind=route.wikiKind,offset=state.job.nextOffset}) end} end
 if #paging>0 then rows[#rows+1]={actions=paging,height=40} end
 block(out,'results',(route.query and route.query~='' and ('Results for “'..route.query..'”') or 'Explore the encyclopedia')..' · '..state.job.total,rows)
 local explore={row('Choose a subject category',W.types[route.wikiKind] or 'All subjects',function() selectType(route) end)}
 for _,q in ipairs({'Stormwind','The Deadmines','Defias','Ragnaros'}) do local query=q;explore[#explore+1]=row(q,'Explore references',function() W.Open(nil,{query=query}) end) end
 if index.truncated then explore[#explore+1]=caption('This edition reached the search-index capacity. Exact installed reference keys remain bounded; additional content needs a reviewed capacity update.') end
 block(out,'navigation','Discover Azeroth',explore)
 return out,false
end
