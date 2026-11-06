-- One local coordinator over the existing world and personal-history engines.
-- Queries and private results never enter Aether or a persistent search database.
local _,ns=...
local G={PAGE=10};ns.AthenaGlobalSearch=G
local W,U,C=ns.AthenaLivingWiki,ns.UI2,ns.UI2Components
local E=ns.UI2LayoutEngine
E.Register('search',{
 {id='global-search-title',label='Search',region='header',span=12,minSpan=12,canMove=false,canResize=false,canHide=false,canCollapse=false},
 {id='search-world',label='The World',region='left',span=6,minSpan=3},
 {id='search-story',label='Your Story',region='center',span=6,minSpan=3}
})
ns.UI2DefaultLayouts.templates.search={columns={6,6},cards={
 {id='global-search-title',region='header',order=1,span=12,hidden=false,collapsed=false},
 {id='search-world',region='left',order=2,span=6,hidden=false,collapsed=false},
 {id='search-story',region='center',order=3,span=6,hidden=false,collapsed=false}
}}
local function offset(n) return type(n)=='number' and n==n and math.max(0,math.min(100000,math.floor(n))) or 0 end
local function row(title,detail,action) return {title=title,detail=detail,activate=action,height=57,stacked=true,wrap=true} end
local function move(route,field,value)
 local nextRoute={};for k,v in pairs(route) do nextRoute[k]=v end;nextRoute[field]=value;nextRoute.scroll=0;U.Open(nextRoute)
end
local function extra(job,route)
 if not job.editions then
  job.editions={};local provider=ns.AthenaJournal.Live()
  if ns.Modules.Enabled('chronicle') and provider:Allowed() then
   for _,edition in ipairs(ns.AthenaLibraryEditions.List(provider,route.owner)) do job.editions[#job.editions+1]={id=edition.id,title=edition.title,note=edition.note,provider=provider} end
  end
 end
 if job.editionsDone then return end
 local query=(route.query or ''):lower();job.editionAt=(job.editionAt or 0)+1;local candidate=job.editions[job.editionAt]
 if not candidate then job.editionsDone=true;return end
 local edition=ns.AthenaLibraryEditions.Get(candidate.provider,route.owner,candidate.id)
 if not edition then return end
 local match=(edition.title..' '..(edition.note or '')):lower():find(query,1,true)
 if not match then for _,block in ipairs(edition.blocks or {}) do if (block.text or ''):lower():find(query,1,true) then match=true;break end end end
 if match and query~='' then job.saved[#job.saved+1]={title=edition.title,sub='Preserved Daybook edition · private',edition=candidate.id} end
end
local priority={dungeon=100,raid=100,battleground=100,arena=100,duel=100,boss=90,guild=80,group=50,zone=30,session=10}
local function storyResults(state)
 local out,seen={},{};state.linkPending=false
 local function add(key,value) if not seen[key] then seen[key]=true;out[#out+1]=value end end
 for _,item in ipairs(state.history.results) do
  local data=item.data or {};local event=data.event
  if event then
   local st,status=ns.ChronicleActivities.Request(data.owner)
   if not st then
    if status=='building' then ns.ChronicleActivities.Pump();state.linkPending=true end
   else
    local best
    for id in pairs(st.links[event.id] or {}) do
     local activity=ns.ChronicleActivities.View(st,id)
     if activity and (not best or (priority[activity.kind] or 0)>(priority[best.kind] or 0)) then best=activity end
    end
    if best then add('activity/'..data.owner..'/'..best.id,{title=ns.UI2Models.Title(best,st),sub=ns.UI2Models.Status(best,st)..' · '..ns.UI2Components.Stamp(best.startAt),route={page='chronicle',kind='activity',owner=data.owner,key=best.id}})
    else add(item.id,item) end
   end
  else add(data.guid and ('player/'..tostring(data.owner)..'/'..data.guid) or item.id,item) end
 end
 for _,item in ipairs(state.saved) do add('edition/'..item.edition,item) end
 return out
end
function G.Blocks(route)
 local query=route.query or '';local kind=route.wikiKind or 'ALL'
 local state=G.state
 if not state or state.route~=route or state.revision~=ns.Modules.revision or state.generation~=W.generation then
  state={route=route,revision=ns.Modules.revision,generation=W.generation,world=W.BeginSearch(query,kind,offset(route.wikiOffset)),history=ns.WardenSearch.Begin(query),saved={}}
  G.state=state
 end
 local deadline,start=ns.WardenPerformance.Begin(2)
 for _=1,8 do
  if state.world.done then break end;W.PumpSearch(state.world)
  if W.index and W.index.status=='FAILED' then state.world.done=true;state.world.error=W.index.error;break end
  if ns.WardenPerformance.Expired(deadline) then break end
 end
 ns.WardenPerformance.End('global world search',start)
 ns.WardenSearch.Pump(state.history,96);extra(state,route)
 local world,story={},{}
 world[#world+1]=row(W.types[kind] or 'All world knowledge','Choose a category',function()
  local choices={{'ALL','All world knowledge'}}
  local keys={};for k in pairs(W.types) do keys[#keys+1]=k end;table.sort(keys)
  for _,k in ipairs(keys) do choices[#choices+1]={k,W.types[k]} end
  ns.UI2Forms.Form({title='The World',fields={{key='kind',label='Subject category',value=kind,choices=choices}},submit=function(values)
   local nextRoute={};for field,value in pairs(route) do nextRoute[field]=value end;nextRoute.wikiKind=values.kind;nextRoute.wikiOffset=0;U.Open(nextRoute);return true
  end})
 end)
 for _,result in ipairs(state.world.rows) do
  local item=result;world[#world+1]=row(item.title,W.types[item.kind],function() W.Open(item.key) end)
 end
 if state.world.error then world[#world+1]=row('World references could not be opened','Existing knowledge is retained. Retry this search.')
 elseif not state.world.done then world[#world+1]=row('Searching world references…','Local encyclopedia only')
 elseif #state.world.rows==0 then world[#world+1]=row('No matching world reference','Try a name, alias or typed ID such as quest:65.') end
 if offset(route.wikiOffset)>0 then world[#world+1]=row('Previous world results',nil,function() move(route,'wikiOffset',math.max(0,offset(route.wikiOffset)-W.RESULTS)) end) end
 if state.world.nextOffset then world[#world+1]=row('More world results',tostring(state.world.total)..' matches',function() move(route,'wikiOffset',state.world.nextOffset) end) end
 local personal=storyResults(state)
 local first=offset(route.storyOffset)
 for i=first+1,math.min(#personal,first+G.PAGE) do
  local item=personal[i];story[#story+1]=row(item.title,item.sub,function()
   if item.route then U.Open(item.route)
   elseif item.edition then
    U.Open({page='journey',owner=route.owner});local p=U.journalHost and U.journalHost.reader
    if p then p.pendingSearchEdition=item.edition end
   else local ok,why=ns.UI2Browse.OpenSearch(item);if not ok then ns.UI2Forms.Feedback(false,why) end end
  end)
 end
 if not state.history.done or not state.editionsDone or state.linkPending then story[#story+1]=row('Searching your retained story…','Private history stays on this computer.')
 elseif #personal==0 then story[#story+1]=row('No matching retained history','Only existing, permitted observations and saved editions are searched.') end
 if first>0 then story[#story+1]=row('Previous story results',nil,function() move(route,'storyOffset',math.max(0,first-G.PAGE)) end) end
 if first+G.PAGE<#personal then story[#story+1]=row('More of your story',nil,function() move(route,'storyOffset',first+G.PAGE) end) end
 local wide=U.stage and U.stage:GetWidth()>=1050
 local function height(rows) local n=44;for _,r in ipairs(rows) do n=n+(r.height or 31) end;return n end
 return {
  {id='global-search-title',title='Search · '..query,x=0,y=0,w=1,rows={{title='One search · The World and Your Story',detail='Reference knowledge alongside your permitted local history. Nothing is transmitted.',wrap=true,height=52}}},
  {id='search-world',title='The World',x=0,y=110,w=wide and .5 or 1,rows=world},
  {id='search-story',title='Your Story',x=wide and .5 or 0,y=wide and 110 or 122+height(world),w=wide and .5 or 1,rows=story}
 },not state.world.done or not state.history.done or not state.editionsDone or state.linkPending
end
if type(ns.Modules.ClearHistoryCaches)=='function' then
 local clear=ns.Modules.ClearHistoryCaches
 ns.Modules.ClearHistoryCaches=function(...) G.state=nil;return clear(...) end
end
