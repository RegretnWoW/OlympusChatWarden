-- Cooperative local catalogs, global search and precise source routing.
-- Derived caches only: no collectors, consent mutation or legacy screens.
local _,ns=...
local U,M,L,F,C=ns.UI2,ns.UI2Models,ns.UI2Layouts,ns.UI2Forms,ns.UI2Components
local B={catalogs={},searches={},filters={}};ns.UI2Browse=B
local function act(id,title,detail,fn,height) return {id=id,title=title,detail=detail,activate=fn,height=height or 40} end
local function cap(text) return {title=text or '',kind='caption',height=54,wrap=true} end
local function block(id,title,x,w,rows,y) return {id=id,title=title,x=x,y=y or 0,w=w,rows=rows} end
local function clone(route) local out={};for k,v in pairs(route) do out[k]=v end;return out end
local function go(route) return function() U.Open(route) end end
local function contains(text,query) return not query or query=='' or tostring(text or ''):lower():find(query:lower(),1,true)~=nil end
function B.ActivityMatches(st,activity,query)
 if not query or query=='' then return true end
 local context=activity.context or {}
 if contains(table.concat({context.instanceName or '',context.zone or '',activity.kind or '',activity.id or '',M.Title(activity)},' '),query) then return true end
 for guid in pairs(activity.members or {}) do if contains(guid,query) or contains(ns.ChronicleActivities.Name(st,guid,activity.lastAt),query) then return true end end
 for _,attempt in ipairs(activity.attempts or {}) do if contains(attempt.name,query) then return true end end
 return false
end
local progressKinds={level_change=true,quest_turnin=true,quest_accepted=true,quest_removed=true,quest_objective=true,skill_change=true,achievement=true,death=true,exploration=true,zone_change=true,money_change=true,spell_learned=true}
local function keepCatalog(key,catalog)
 B.serial=(B.serial or 0)+1;catalog.used=B.serial;B.catalogs[key]=catalog
 local count,oldest,evict=0
 for id,value in pairs(B.catalogs) do count=count+1;if id~=key and (not oldest or value.used<oldest) then oldest=value.used;evict=id end end
 if count>8 and evict then B.catalogs[evict]=nil end
end
function B.Catalog(kind,owner)
 if not ns.Athena2.Permit(kind=='player' and 'intel' or 'chronicle') then return nil,'Access or module unavailable' end
 local st,why=ns.ChronicleActivities.Request(owner);if not st then return nil,why end
 local ready,state=ns.AthenaProfiles.Ensure(st,owner);if not ready then return nil,state end
 local character=ns.ChronicleStore.Character(owner,false);local revision=tostring(st.revision)..'/'..tostring(st.processed)..'/'..tostring(character and character.revision)
 local key=owner..'/'..kind;local old=B.catalogs[key]
 if old and old.revision==revision then keepCatalog(key,old);return old.done and old or nil,old.error or 'Arranging local history' end
 local catalog={revision=revision,rows={},byID={},state=st};keepCatalog(key,catalog)
 local thread=coroutine.create(function()
  if kind=='player' then
   local n,seen=0,{};local function add(guid)
    if seen[guid] then return end;seen[guid]=true
    local profile=character and character.profiles[guid];local facts=profile and profile.facts or {};local function fact(k) return facts[k] and facts[k].value end
    local name=fact('name') or ns.ChronicleActivities.Name(st,guid) or 'Name not recorded'
    catalog.rows[#catalog.rows+1]={key=guid,title=name,owner=owner,search=table.concat({name,guid,fact('guild') or '',fact('class') or ''},' ')}
    n=n+1;if n%64==0 then coroutine.yield() end
   end
   for guid in pairs(st.players) do add(guid) end
   for guid in pairs(character and character.profiles or {}) do add(guid) end
   table.sort(catalog.rows,function(a,b) return a.title<b.title or a.title==b.title and a.key<b.key end)
  elseif kind=='progress' or kind=='collections' then
   for n=#(character and character.events or {}),1,-1 do local event=character.events[n]
    if kind=='collections' and event.capture or kind=='progress' and progressKinds[event.kind] then
     catalog.rows[#catalog.rows+1]=event;catalog.byID[event.id]=event
    end
    if n%64==0 then coroutine.yield() end
   end
  else
   local seen={};for n=#st.activities,1,-1 do local a=ns.ChronicleActivities.View(st,st.activities[n].id);local context=st.athena2 and st.athena2.partyContexts and st.athena2.partyContexts[a.id]
    if not seen[a.id] and not (a.kind=='group' and context and context.supportsAdventure and not context.outsideAdventure) then
     seen[a.id]=true;catalog.rows[#catalog.rows+1]=a
    end
    if n%64==0 then coroutine.yield() end
   end
  end
  catalog.done=true
 end)
 local ok=ns.WardenScheduler.Submit('ui2 catalog/'..key,'interactive',function()
  if B.catalogs[key]~=catalog then return true end
  if ns.ChronicleStore.Character(owner,false)~=character then B.catalogs[key]=nil;return true end
  local resumed,error=coroutine.resume(thread);if not resumed then catalog.error=tostring(error);catalog.done=true;return true end
  return coroutine.status(thread)=='dead'
 end,{module=kind=='player' and 'intel' or 'chronicle',onCancel=function() if B.catalogs[key]==catalog then B.catalogs[key]=nil end end})
 if not ok then B.catalogs[key]=nil;return nil,'The local view queue is busy. Try again.' end
 return nil,'Arranging local history'
end
function B.Filters(route)
 local owners={{ns.Chronicle.Owner(),'This character'}}
 for owner in pairs(ns.ChronicleStore.db and ns.ChronicleStore.db.characters or {}) do if owner~=ns.Chronicle.Owner() then owners[#owners+1]={owner,ns.WardenUI.OwnerName(owner)} end end
 local fields={{key='owner',label='Recorded by',value=route.owner,choices=owners},{key='query',label=route.page=='chronicle' and 'Adventure, boss or participant' or 'Player name, guild or class',value=route.query or '',limit=256}}
 if route.page=='chronicle' then fields[#fields+1]={key='activityKind',label='Activity type',value=route.activityKind or false,choices={{false,'All activities'},{'dungeon','Dungeons'},{'raid','Raids'},{'group','Groups and guild company'},{'guild','Guild milestones'},{'battleground','Battlegrounds'},{'arena','Arenas'},{'boss','World encounters'},{'duel','Duels'},{'duel_win','Verified duel victories'},{'duel_loss','Verified duel defeats'},{'duel_unknown','Unresolved duels'}}} end
 if route.guid then fields[#fields+1]={key='playerScope',label='Participant scope',value=route.guid,choices={{route.guid,'Only the selected player'},{false,'All players'}}} end
 return F.Form({title='History filters',fields=fields,submit=function(v) local nextRoute=clone(route);nextRoute.owner=v.owner;nextRoute.query=v.query;nextRoute.activityKind=v.activityKind or nil;if route.guid then nextRoute.guid=v.playerScope or nil end;if v.owner~=route.owner then nextRoute.guid=nil end;nextRoute.listPage=1;nextRoute.scroll=0;U.Open(nextRoute,true);return true end})
end
-- Filtering is cooperative too. A small visible page must not synchronously
-- rescan hundreds of thousands of archived observations on every refresh.
function B.Filter(catalog,scope,predicate)
 if not predicate then return catalog.rows end
 local job=B.filters[scope]
 if job and job.catalog==catalog then if job.error then return nil,job.error end;return job.done and job.rows or nil end
 job={catalog=catalog,rows={},position=1};B.filters[scope]=job
 B.filterSerial=(B.filterSerial or 0)+1;job.used=B.filterSerial
 local count,oldest,evict=0
 for key,value in pairs(B.filters) do count=count+1;if key~=scope and (not oldest or value.used<oldest) then oldest=value.used;evict=key end end
 if count>8 and evict then B.filters[evict]=nil end
 local accepted=ns.WardenScheduler.Submit('ui2 filter/'..job.used,'interactive',function()
  if B.filters[scope]~=job then return true end
  local ok,why=pcall(function()
   for n=job.position,math.min(job.position+63,#catalog.rows) do
    local item=catalog.rows[n];if predicate(item) then job.rows[#job.rows+1]=item end
    job.position=n+1
   end
  end)
  if not ok then job.error='This local filter could not be prepared.';job.done=true;return true end
  job.done=job.position>#catalog.rows;return job.done
 end,{module=scope:sub(1,5)=='intel' and 'intel' or 'chronicle',onCancel=function() if B.filters[scope]==job then B.filters[scope]=nil end end})
 if not accepted then B.filters[scope]=nil;return nil,'The local view queue is busy. Try again.' end
 return nil
end
local function filterScope(route,kind)
 return table.concat({route.page or '',route.owner or '',kind or '',route.query or '',route.activityKind or '',route.guid or '',route.collectionFamily or ''},'/')
end
local function filterError(scope,why)
 return {cap(why),act('BROWSE.FILTER.RETRY','Retry local filter','Saved records are retained',function() B.filters[scope]=nil;U.Refresh(true) end)}
end
function B.Source(event)
 if type(event)~='table' or not ns.ChronicleStore.Text(event.id,512) then return false,'Source unavailable.' end
 local owner=event.character or ns.Chronicle.Owner()
 return U.Open({page='settings',category='advanced',subsection='source',sourceEvent=event,owner=owner})
end
local priority={dungeon=100,raid=100,battleground=100,arena=100,duel=100,boss=90,guild=80,group=50,zone=30,session=10}
function B.OpenSearch(row)
 local d=row and row.data;if not d then return false,'Search result unavailable.' end
 if d.character and ns.ChronicleStore.Character(d.owner,false)~=d.character then return false,'This history changed. Search again.' end
 if d.guid then return U.OpenPlayer(d.guid,d.owner)
 elseif d.activity then return ns.UI2NotificationCenter.OpenSource(d.activity.id)
 elseif d.capture then return U.Open({page='messages',subsection='capture',captureID=d.capture.id})
 elseif d.bookmark then return U.Open({page='messages',subsection='bookmarks',selectedID=d.bookmark.id})
 elseif d.entry then return U.Open({page='messages',subsection=d.page,selectedID=d.entry.id})
 elseif d.event then
  local e=d.event;local guid=ns.ChronicleStore.GUID(e.subject or (e.details or {}).guid)
  if guid and (e.kind=='player_observed' or e.kind=='important_player') then return U.OpenPlayer(guid,d.owner) end
  local st=ns.ChronicleActivities.Request(d.owner);if not st then return false,'Wait for this character’s history to finish preparing, then open the result.' end
  local best;for id in pairs(st.links[e.id] or {}) do local a=ns.ChronicleActivities.View(st,id);if a and (not best or (priority[a.kind] or 0)>(priority[best.kind] or 0)) then best=a end end
  if best then return U.Open({page='chronicle',kind='activity',key=best.id,owner=d.owner}) end
  return U.Open({page='chronicle',subsection='progress',owner=d.owner,selectedID=e.id})
 end
 return U.Open({page=d.page or 'overview'})
end
ns.WardenSearch.Open=B.OpenSearch
function B.Search(route)
 local query=route.query or '';local job=B.searches[query]
 if not job or job.route~=route or job.moduleRevision~=ns.Modules.revision then job=ns.WardenSearch.Begin(query);job.route=route;B.searches={[query]=job} end
 if not job.done then ns.WardenSearch.Pump(job,128) end
 local rows={}
 for _,result in ipairs(job.results) do local item=result;rows[#rows+1]=act('SEARCH.OPEN',result.title,result.sub,function() local ok,why=B.OpenSearch(item);if not ok then F.Feedback(false,why) end end,52);rows[#rows].stacked=true end
 for _,candidate in ipairs(ns.AetherNet.Candidates(query)) do local subject=candidate
  rows[#rows+1]=act('SEARCH.NET.SUBJECT',subject.name..' · '..subject.realm,subject.kind=='GUILD' and 'Guild · partial shared information' or 'Character · partial shared information',function()
   if subject.kind=='EVENT' then U.Open({page='chronicle',kind='activity',key=subject.key,owner=route.owner}) elseif subject.kind=='GUILD' then U.OpenGuild(subject.key) else U.OpenPlayer(subject.key,route.owner) end
  end,52)
 end
 if #rows==0 then rows[1]=cap(job.done and 'No matching retained subjects. Try a different search.' or 'Searching permitted local sources…') end
 return {block('results','Search · '..query,0,1,rows)},not job.done
end
local home=L.Home
function L.Home(route) if route.subsection=='search' then return B.Search(route) end;return home(route) end
function B.SnapshotRows(event,owner)
 local snapshot=event.capture or {};local v=snapshot.values or {};local family=snapshot.family;local rows={}
 local function value(key,label)
  local x=v[key];if x~=nil then rows[#rows+1]={title=label,detail=type(x)=='boolean' and (x and 'Yes' or 'No') or tostring(x),height=38} end
 end
 local guid=ns.ChronicleStore.GUID(v.guid or event.subject)
 if family=='gear' or family=='traits' or family=='character_card' or family=='appearance' or family=='barber' or family=='equipment_set' then
  for _,pair in ipairs({{'name','Name'},{'realm','Realm'},{'level','Level'},{'race','Race'},{'class','Class'},{'guild','Guild'},{'faction','Faction'},{'isEquipped','Equipped when observed'}}) do value(pair[1],pair[2]) end
  if family=='gear' then
   local G=ns.WardenDossier
   for _,slot in ipairs(G.slots) do local item=G.Slot({object=event},slot[1]);local id=item[3]~=false and item[3]
    local title=id and ns.SafeString(ns.SafeCall(GetItemInfo or C_Item and C_Item.GetItemInfo,id),200)
    rows[#rows+1]={title=slot[2],detail=title or id and 'Item #'..id or item[2]=='empty' and 'Confirmed empty' or 'Not observed',height=38}
   end
  elseif family=='traits' then
   for _,choice in ipairs(v.choices or {}) do local title,icon=ns.WardenDossier.TalentLabel(choice);rows[#rows+1]={title=title,icon=icon,detail='Recorded rank '..choice[4],height=38} end
   if v.exportString then rows[#rows+1]=act('CHR.TRAITS.EXPORT','Copy recorded talent export','This dated observation',function() F.Copy('Recorded talents',v.exportString) end) end
  elseif family=='appearance' or family=='barber' then rows[#rows+1]=cap('Appearance attributes were observed. They do not provide a reliable offline portrait or a reconstruction of the player’s past appearance.') end
  if guid then rows[#rows+1]=act('CHR.COLLECTION.PLAYER','Open player dossier','Same person and recorded history',function() U.OpenPlayer(guid,owner) end) end
 elseif family=='stats' then
  for _,pair in ipairs({{'strength','Strength'},{'agility','Agility'},{'stamina','Stamina'},{'intellect','Intellect'},{'spirit','Spirit'},{'armor','Armor'},{'healthMax','Maximum health'},{'powerMax','Maximum power'},{'crit','Critical strike'},{'haste','Haste'}}) do value(pair[1],pair[2]) end
 elseif family=='collection' then
  for _,pair in ipairs({{'name','Collected item'},{'collectionType','Collection'},{'collected','Collected when observed'},{'petLevel','Companion level'},{'scope','Scope'}}) do value(pair[1],pair[2]) end
 elseif family=='currency' then
  for _,pair in ipairs({{'name','Currency'},{'quantity','Amount observed'},{'maxQuantity','Maximum amount'},{'quantityEarnedThisWeek','Earned this week'},{'maxWeeklyQuantity','Weekly limit'},{'totalEarned','Total reported by client'},{'isAccountWide','Shared across characters'}}) do value(pair[1],pair[2]) end
 elseif family=='rank' then
  for _,pair in ipairs({{'renownLevel','Renown level'},{'renownReputationEarned','Reputation earned'},{'renownLevelThreshold','Next level threshold'},{'maxLevel','Maximum level'}}) do value(pair[1],pair[2]) end
 elseif family=='lockout' then
  for _,pair in ipairs({{'name','Saved instance'},{'difficultyName','Difficulty'},{'locked','Saved to this instance'},{'extended','Extended'},{'maxPlayers','Group capacity'}}) do value(pair[1],pair[2]) end
  if v.resetAt then rows[#rows+1]={title='Reset reported',detail=C.Stamp(v.resetAt),height=38} end
 elseif family=='lockout_list' then
  rows[#rows+1]=cap(v.complete and 'Complete saved-instance observation. A lockout is not proof of a full clear.' or 'Partial saved-instance observation. Other saved instances may be missing.')
  for _,saved in ipairs(v.rows or {}) do rows[#rows+1]={title=saved[1],detail=saved[10] and C.Stamp(saved[10]) or 'Reset not recorded',height=44} end
 elseif family=='meter' then
  value('totalAmount','Observed combat total');value('durationSeconds','Observed seconds')
  for _,source in ipairs(v.sources or {}) do local key=ns.ChronicleStore.GUID(source[1]);rows[#rows+1]={title=source[3]~=false and source[3] or 'Unidentified source',detail=C.Number(source[5])..(source[6]~=false and ' · '..C.Number(source[6])..' per second' or ''),height=44,activate=key and function() U.OpenPlayer(key,owner) end} end
 elseif family=='merchant' then
  value('auctionID','Auction');value('itemID','Item');value('status','Observed listing state');value('bidCopper','Bid · copper');value('buyoutCopper','Buyout · copper');value('depositCopper','Deposit · copper');value('cutCopper','Auction cut · copper');value('offeredCopper','Offered gold · copper');value('requestedCopper','Requested gold · copper')
  for _,item in ipairs(v.items or {}) do rows[#rows+1]={title=(item[1]==1 and 'Given · ' or 'Received · ')..(item[5]~=false and item[5] or 'Item '..item[3]),detail='× '..item[4],icon=ns.ChronicleCapture.Call('C_Item.GetItemIconByID',item[3]),height=42} end
  rows[#rows+1]=cap('Owner-private observation. A sold listing is not received payment; invoice matches remain uncertain. Profit and market value are not inferred.')
 elseif family=='recap' then
  value('healthMax','Maximum health observed')
  for _,hit in ipairs(v.rows or {}) do rows[#rows+1]={title=hit[3]~=false and hit[3] or 'Damage event',detail=C.Number(hit[5])..(hit[4]~=false and ' · '..hit[4] or ''),height=42} end
 else rows[#rows+1]=cap('This dated observation is retained with its related character or adventure. It does not establish a reward, purchase or accomplishment.') end
 return rows
end
function B.History(route)
 if route.historyMode=='merchant' then
  local rows={F.Row('CHR.HISTORY.MODE','History scope',function()return 'merchant'end,function(v)local r=clone(route);r.historyMode=v;U.Open(r,true);return true end,{choices={{'life','Personal history'},{'guild','Guild history'},{'combat','My combat'},{'merchant','Merchant history'}}})}
  local value,state=ns.ChronicleMerchant.Query('chronicle',route.owner or ns.Chronicle.Owner())
  if not value or state~='READY' then rows[#rows+1]=cap(state=='DENIED' and 'Private business history is available only to its character owner.' or 'Preparing retained business history…');return rows,{},state=='INDEXING' end
  rows[#rows+1]=cap('Your private merchant observations. Missing details stay unknown; money gained is not treated as auction profit.')
  rows[#rows+1]={title='Latest recorded balance',detail=value.balance and string.format('%.2f gold · %s',value.balance/10000,C.Stamp(value.balanceAt)) or 'Not recorded',height=44}
  for _,spec in ipairs({{'active','Active listings last observed'},{'sold','Distinct auctions observed sold'},{'trades','Confirmed successful trades'},{'invoices','Invoice observations · not unique sales'}})do rows[#rows+1]={title=spec[2],detail=value[spec[1]]>0 and tostring(value[spec[1]]) or 'Not recorded',height=42}end
  rows[#rows+1]={title='Revenue / profit',detail='Not established · invoice matching and payment collection require stronger identity',height=54,wrap=true}
  for _,m in ipairs(value.milestones)do local id=m.sourceID;rows[#rows+1]=act('CHR.MERCHANT.MILESTONE',C.Number(m.copper/10000)..' gold crossed',C.Stamp(m.at)..' · observed wallet threshold, not lifetime earnings',function()local r=clone(route);r.historyMode='life';r.query='money_change';r.selectedID=id;U.Open(r,true)end,50)end
  rows[#rows+1]=act('CHR.MERCHANT.SOURCES','Business source observations','Inspect private auction and trade records',function()local r=clone(route);r.historyMode='life';r.query='auction';U.Open(r,true)end)
  return rows,{},false
 end
 if route.historyMode=='combat' and not route.combatEvidence then
  local rows,detail,pending=ns.UI2Combat.History(route)
  table.insert(rows,1,F.Row('CHR.HISTORY.MODE','History scope',function()return 'combat'end,function(v)local r=clone(route);r.historyMode=v;U.Open(r,true);return true end,{choices={{'life','Personal history'},{'guild','Guild history'},{'combat','My combat'},{'merchant','Merchant history'}}}))
  return rows,detail,pending
 end
 local mode=route.historyMode or 'life';local service=mode=='guild' and ns.Athena.GetGuildHistory or mode=='combat' and ns.Athena.GetCombatHistory or ns.Athena.GetCharacterHistory
 local entries,cursor
 if mode=='combat' then entries,cursor=service('chronicle',route.owner,nil,route.historyCursor,{limit=20,search=route.query,scope=route.combatEvidenceScope})
 else entries,cursor=service('chronicle',route.owner,route.historyCursor,{limit=20,search=route.query}) end
 local rows={F.Row('CHR.HISTORY.MODE','History scope',function() return mode end,function(v) local out=clone(route);out.historyMode=v;out.historyCursor=nil;out.historyCursors={};out.selectedID=nil;U.Open(out,true);return true end,{choices={{'life','Personal history'},{'guild','Guild history'},{'combat','My combat'},{'merchant','Merchant history'}}})}
 if not entries then
  local denied=cursor=='DENIED' or cursor=='INVALID_SUBJECT' or cursor=='INVALID_CURSOR' or cursor=='CURSOR_STALE'
  rows[#rows+1]=cap(denied and 'This scope is unavailable or changed. Start again from its newest observations.' or 'Opening this character’s retained history…')
  if denied then rows[#rows+1]=act('CHR.HISTORY.RESTART','Newest observations','Restart this scope',function() local out=clone(route);out.historyCursor=nil;out.historyCursors={};U.Open(out,true) end) end
  return rows,{},not denied
 end
 if #(route.historyCursors or {})>0 then rows[#rows+1]=act('CHR.HISTORY.PREVIOUS','Newer observations','Same history scope',function()
  local out=clone(route);local back={};for n,value in ipairs(route.historyCursors) do back[n]=value end
  out.historyCursor=table.remove(back) or nil;out.historyCursors=back;out.selectedID=nil;U.Open(out,true)
 end) end
 local detail={};local pending=false
 if mode=='combat' then rows[#rows+1]=act('CHR.COMBAT.STATISTICS','Combat statistics','Return to scoped totals and spells',function()local r=clone(route);r.combatEvidence=nil;U.Open(r,true)end) end
 for _,entry in ipairs(entries) do local event=entry.event;local out=clone(route);out.selectedID=event.id
  rows[#rows+1]=act('CHR.HISTORY.SELECT',entry.title or ns.RecordingUI.Title(event),C.Stamp(event.at)..(entry.association and ' · '..entry.association or ''),go(out),52);rows[#rows].stacked=true
  if route.selectedID==event.id then
   detail[#detail+1]=cap(entry.title or ns.RecordingUI.Title(event));detail[#detail+1]={title='Observed',detail=C.Stamp(event.at),height=38}
   local t=event.temporal;local d=event.details or {}
   detail[#detail+1]={title='Time basis',detail=t and (t.basis=='baseline' and 'Already present when first observed · original date unknown' or t.basis=='sample' and 'State sampled at '..C.Stamp(t.sampledAt) or t.basis=='aggregate' and 'Observed interval · not an exact occurrence' or 'WoW reported this at '..C.Stamp(t.eventAt)) or 'Legacy observation · original timing precision unknown',height=56,wrap=true}
   if d.calendarYear then detail[#detail+1]={title='Official calendar date',detail=string.format('%04d-%02d-%02d · day precision',d.calendarYear,d.calendarMonth,d.calendarDay),height=42} end
   if d.wasEarnedByMe~=nil then detail[#detail+1]={title='Earned by this character',detail=d.wasEarnedByMe and 'Confirmed by WoW' or 'Not established · account/other-character completion',height=42} end
   if d.totalPlayed then detail[#detail+1]={title='Time played reported by WoW',detail=string.format('%.1f hours · this level %.1f hours',d.totalPlayed/3600,d.levelPlayed/3600),height=42} end
   detail[#detail+1]={title='Place',detail=event.location and (event.location.subzone or event.location.zone) or 'Not recorded',height=38}
   if event.capture then for _,row in ipairs(B.SnapshotRows(event,route.owner)) do detail[#detail+1]=row end
   else for _,pair in ipairs({{'name','Name'},{'guildName','Guild'},{'guildRank','Observed guild rank'},{'description','Development'},{'objective','Objective'},{'before','Previous observation'},{'after','Later observation'},{'delta','Change'}}) do local value=(event.details or {})[pair[1]];if type(value)=='string' or type(value)=='number' then detail[#detail+1]={title=pair[2],detail=tostring(value),height=40} end end end
   detail[#detail+1]=act('CHR.HISTORY.RELATED','Open related adventure','If an unambiguous recorded link exists',function() B.OpenSearch({data={event=event,owner=route.owner}}) end)
  end
 end
 if cursor then rows[#rows+1]=act('CHR.HISTORY.NEXT','Older observations','Continue retained history',function()
  local out=clone(route);local back={};for n,value in ipairs(route.historyCursors or {}) do back[n]=value end
  back[#back+1]=route.historyCursor or false;out.historyCursors=back;out.historyCursor=cursor;out.selectedID=nil;U.Open(out,true)
 end) end
 if #entries==0 then rows[#rows+1]=cap(cursor and 'No matching observations in this stretch. Continue to older history.' or 'No matching observations retained.') end
 if mode=='combat' then
  local summary,state=ns.Athena.GetMyCombat('chronicle',route.owner)
  if summary then
   detail[#detail+1]={title='Confirmed own spells',detail=ns.AthenaCombatQueries.Top(summary.castSpells,3),height=58,stacked=true,wrap=true}
   detail[#detail+1]={title='Effects observed on you',detail=ns.AthenaCombatQueries.Top(summary.effects,3),height=58,stacked=true,wrap=true}
   detail[#detail+1]=cap(summary.pairedWindows>0 and summary.pairedWindows..' paired windows · '..math.floor(summary.measuredSeconds)..' measured seconds' or 'No paired window recorded; combat duration unknown')
   detail[#detail+1]=cap(ns.AthenaCombatQueries.MeterLine(summary)..'. Samples only; gaps remain unknown. Received damage does not establish its attacker.')
   pending=state=='INDEXING'
  end
 elseif mode=='guild' then detail[#detail+1]=cap('Guild association comes from observed affiliation and roster context. A baseline does not establish a join date; membership alone does not prove attendance, a boss kill or an official guild event.') end
 return rows,detail,pending
end
function B.Personal(route,st)
 local rows,detail={},{}
 local filter={limit=50,offset=((route.listPage or 1)-1)*50};local source=route.subsection
 local i=st.intelligence
 if source=='life' then return B.History(route)
 elseif source=='time' and i and i.time then
  local scope=route.timeScope or 'total';local choices={{'total','All measured history'},{'sessions','Recording segments'},{'day','UTC days'},{'week','UTC weeks'},{'month','UTC months'}}
  rows[1]=F.Row('CHR.TIME.SCOPE','Time scope',function() return scope end,function(value) local out=clone(route);out.timeScope=value;out.timeKey=nil;out.listPage=1;U.Open(out,true);return true end,{choices=choices})
  local time=i.time
  local groups={}
  if scope=='sessions' then for _,segment in ipairs(i.scopes or {}) do groups[#groups+1]={key=segment.id,title=C.Stamp(segment.firstAt),time=segment.time,partial=segment.partialStart,reason=segment.endReason} end
  elseif scope~='total' then for key,metric in pairs(i.periods[scope] or {}) do
   local stamp=scope=='day' and ns.SafeCall(date,'!%Y-%m-%d',tonumber(key)*86400) or scope=='week' and ns.SafeCall(date,'!%Y-%m-%d',(tonumber(key)*7-3)*86400) or key
   groups[#groups+1]={key=key,title=tostring(stamp)..' UTC',time=metric}
  end end
  table.sort(groups,function(a,b) return a.key>b.key end)
  local page=math.max(1,math.min(math.max(1,math.ceil(#groups/40)),tonumber(route.listPage) or 1));local selected
  for n=(page-1)*40+1,math.min(page*40,#groups) do local item=groups[n]
   local out=clone(route);out.timeKey=item.key
   rows[#rows+1]=act('CHR.TIME.SELECT',item.title,item.time and string.format('%.1f measured minutes',item.time.seconds/60) or 'No measured interval',go(out))
  end
  for _,item in ipairs(groups) do if item.key==route.timeKey then selected=item;time=item.time end end
  for _,delta in ipairs({-1,1}) do if page+delta>=1 and page+delta<=math.ceil(#groups/40) then local out=clone(route);out.listPage=page+delta;rows[#rows+1]=act('CHR.TIME.PAGE',delta<0 and 'Newer periods' or 'Older periods','',go(out)) end end
  if scope~='total' and not selected then detail[1]=cap('Choose a recorded period. Calendar views use UTC; intervals crossing a calendar boundary remain unassigned rather than being estimated.')
  elseif time then
   local function duration(title,seconds) detail[#detail+1]={title=title,detail=type(seconds)=='number' and string.format('%.1f minutes',seconds/60) or 'Not recorded',height=40} end
   duration('Measured in-world time',time.seconds);duration('Flagged AFK',time.afk);duration('Not flagged AFK',time.nonAfk);duration('AFK state unknown',time.afkUnknown)
   duration('Covered combat windows',time.combatSeconds);duration('Covered group windows',time.groupContextSeconds)
   detail[#detail+1]=cap('Not flagged AFK does not establish active play. Group and combat windows can overlap. Offline/loading gaps are excluded; missing time is not zero.')
   for kind,seconds in pairs(time.categories or {}) do duration('Activity · '..kind,seconds) end
   for zone,seconds in pairs(time.zones or {}) do duration(zone,seconds) end
   if selected and selected.partial then detail[#detail+1]=cap('The beginning of this recording segment was not observed.') end
   if scope=='total' then
    duration('Unallocated reported time',i.excludedReportedSeconds);duration('Overlapping coverage counted once',i.overlapSeconds)
    for kind,seconds in pairs(i.calendarUnknown or {}) do duration('Unassigned across UTC '..kind..' boundaries',seconds) end
    local growth=i.progression or {};detail[#detail+1]={title='Linked-window experience per hour',detail=growth.rateSeconds and growth.rateSeconds>0 and C.Number(growth.rateXP*3600/growth.rateSeconds) or 'Not recorded',height=44}
    detail[#detail+1]=cap('Experience rate uses only matching XP endpoints with complete measured coverage. It does not estimate a lifetime leveling rate.')
   end
  end
 elseif source=='scoreboards' then
  for _,board in ipairs(ns.ChronicleScoreboards.List(st)) do local selected=board;local activity=ns.ChronicleScoreboards.Activity(st,board);rows[#rows+1]=act('CHR.SCOREBOARD.OPEN',board.instanceName or 'Recorded match',C.Stamp(board.lastAt)..(ns.ChronicleScoreboards.Complete(board) and ' · Whole board' or ' · Partial'),activity and go({page='chronicle',kind='activity',owner=st.owner,key=activity.id,jump='scoreboard'}) or function() F.Feedback(false,'This board has no unambiguous linked match. No match identity was inferred.') end) end
 else
  local catalog,state=B.Catalog(source=='collections' and 'collections' or 'progress',st.owner)
  if not catalog then return {cap(state)},{},true end
  if catalog.error then return {cap('This local history could not be prepared.'),act('CHR.PROGRESS.RETRY','Retry local view','Saved records are retained',function() B.catalogs[st.owner..'/'..(source=='collections' and 'collections' or 'progress')]=nil;U.Refresh(true) end)},{},false end
  local scope=filterScope(route,source)
  if source=='collections' then rows[#rows+1]=F.Row('CHR.COLLECTION.SCOPE','Collection',function() return route.collectionFamily or false end,function(value) local out=clone(route);out.collectionFamily=value or nil;out.selectedID=nil;out.listPage=1;U.Open(out,true);return true end,{choices={{false,'All collections'},{'gear','Equipment'},{'traits','Talents'},{'appearance','Appearance'},{'barber','Barber changes'},{'equipment_set','Equipment sets'},{'stats','Combat stats'},{'collection','Collected companions and mounts'},{'currency','Currencies'},{'rank','Reputation and ranks'},{'lockout','Saved instances'},{'lockout_list','Saved-instance lists'},{'meter','Combat totals'},{'recap','Damage recaps'}}}) end
  local function matches(e)
   local guid=e.capture and e.capture.values and e.capture.values.guid or e.subject
   return (not route.guid or guid==route.guid) and contains(ns.RecordingUI.Title(e),route.query) and (not route.collectionFamily or e.capture and e.capture.family==route.collectionFamily)
  end
  local entries,why=B.Filter(catalog,scope,(route.query and route.query~='' or route.collectionFamily or route.guid) and matches or nil)
  if not entries then return why and filterError(scope,why) or {cap('Finding matching observations…')},{},not why end
  local page=math.max(1,tonumber(route.listPage) or 1);local first=(page-1)*40+1
  if page>1 then local previous=clone(route);previous.listPage=page-1;rows[#rows+1]=act('CHR.PROGRESS.PREVIOUS','Newer entries','',go(previous)) end
  for n=first,math.min(first+39,#entries) do local e=entries[n];local out=clone(route);out.selectedID=e.id;rows[#rows+1]=act('CHR.PROGRESS.SELECT',ns.RecordingUI.Title(e),C.Stamp(e.at),go(out)) end
  if first+39<#entries then local nextRoute=clone(route);nextRoute.listPage=page+1;rows[#rows+1]=act('CHR.PROGRESS.NEXT','Older entries','',go(nextRoute)) end
  local selected=route.selectedID and catalog.byID[route.selectedID]
  if selected and not matches(selected) then selected=nil end
  if selected then
   detail[#detail+1]=cap(ns.RecordingUI.Title(selected));detail[#detail+1]={title='Observed',detail=C.Stamp(selected.at),height=40}
   local d=selected.details or {};for _,pair in ipairs({{'name','Name'},{'skill','Skill'},{'level','Level'},{'current','Current'},{'previous','Previous'},{'delta','Change'},{'objective','Objective'},{'description','Description'}}) do if d[pair[1]]~=nil and type(d[pair[1]])~='table' then detail[#detail+1]={title=pair[2],detail=tostring(d[pair[1]]),height=40} end end
   if selected.location then detail[#detail+1]={title='Place',detail=selected.location.subzone or selected.location.zone or 'Not recorded',height=40} end
   if selected.capture then for _,row in ipairs(B.SnapshotRows(selected,route.owner)) do detail[#detail+1]=row end end
   detail[#detail+1]=act('CHR.PROGRESS.RELATED','Related adventure','Source-backed link only',function() return B.OpenSearch({data={event=selected,owner=route.owner}}) end)
  end
 end
 if #rows==0 then rows[1]=cap('No observations in this retained scope.') end
 if #detail==0 then detail[1]=cap('Choose an entry. Changes describe recorded observations, not inferred purchases, rewards or causes.') end
 return rows,detail
end
function L.Browse(route)
 if route.page=='intel' and route.subsection=='warden-online' and ns.Athena2.Permit('intel') then
  local rows={cap('Recently acknowledged, eligible Fireside peers. This is a partial list; absence does not mean offline.')}
  for _,person in ipairs(ns.AetherNet.OnlineWardenUsers()) do local p=person
   rows[#rows+1]=act('INT.ONLINE.OPEN',p.title,'Fireside Online',function() return U.OpenPlayer(p.key,route.owner) end,48)
   rows[#rows].stacked=true
  end
  if #rows==1 then rows[#rows+1]=cap('No recently confirmed Fireside peers. Cached activities do not establish connectivity.') end
  return {block('filters','People filters',0,.22,{act('INT.ALL','All recorded players','Return to player dossiers',go({page='intel',owner=route.owner}))}),block('results','Online Fireside Users',.22,.78,rows)},false
 end
 local kind=route.page=='intel' and 'player' or 'activity';local catalog,state=B.Catalog(kind,route.owner)
 if not catalog then
  local opening={cap(state=='blocked' and 'This history could not be opened. Original saved records are retained.' or state)}
  if kind=='activity' then opening[#opening+1]=act('CHR.REPLAY','Journey Replay','Watch your recorded zone travel',go({page='chronicle',subsection='replay',owner=ns.Chronicle.Owner()}))end
  return {block('results','Opening retained history',0,1,opening)},state~='Access or module unavailable' and state~='blocked' and state~='disabled'
 end
 if catalog.error then return {block('results','History view unavailable',0,1,{cap('This local view could not be prepared. Original saved records are retained.'),act('BROWSE.RETRY','Retry local view','Rebuild disposable index',function() B.catalogs[route.owner..'/'..kind]=nil;U.Refresh(true) end)})},false end
 local tools={act('BROWSE.FILTERS','History filters','Character and activity scope',function() B.Filters(route) end)}
 if kind=='player' then tools[#tools+1]=act('INT.ONLINE','Online Fireside Users','Recently acknowledged eligible peers',go({page='intel',subsection='warden-online',owner=route.owner})) end
 if kind=='player' then tools[#tools+1]=act('INT.TARGET','My target','Open this character’s profile',function()
  local guid=ns.ChronicleStore.GUID(ns.SafeCall(UnitGUID,'target'))
  if ns.SafeCall(UnitIsPlayer,'target')~=true or not guid then return F.Feedback(false,'Select an identifiable player first.') end
  return U.OpenPlayer(guid,ns.Chronicle.Owner())
 end) end
 if kind=='activity' then
  tools[#tools+1]=act('CHR.REPLAY','Journey Replay','Watch your recorded zone travel',go({page='chronicle',subsection='replay',owner=ns.Chronicle.Owner()}))
  tools[#tools+1]=act('CHR.TARGET','Target history','Recorded adventures with this exact player',function()
   local guid=ns.ChronicleStore.GUID(ns.SafeCall(UnitGUID,'target'))
   if ns.SafeCall(UnitIsPlayer,'target')~=true or not guid then return F.Feedback(false,'Target an identifiable player first. No identity was guessed from a name.') end
   local out=clone(route);out.guid=guid;out.subsection='activities';out.selectedID=nil;out.listPage=1;out.scroll=0;return U.Open(out,true)
  end)
  if route.guid then local out=clone(route);out.guid=nil;out.listPage=1;tools[#tools+1]=act('CHR.ALL.PLAYERS','All players','Remove the selected participant scope',go(out)) end
  for _,pair in ipairs({{'activities','Adventures'},{'life','Life, guild and combat'},{'progress','Progress and discoveries'},{'time','Time and zones'},{'scoreboards','Captured scoreboards'},{'collections','Character collections'}}) do local key,title=pair[1],pair[2];local out=clone(route);out.subsection=key;out.selectedID=nil;out.listPage=1;out.scroll=0;tools[#tools+1]=act('CHR.VIEW.'..key,title,(route.subsection or 'activities')==key and 'Selected' or '',go(out)) end
 end
 tools[#tools+1]=act('BROWSE.SETTINGS','Recording and privacy','Settings',go({page='settings',category=kind=='player' and 'privacy' or 'recording'}))
 local rows,detail,pending={},{},false
 if kind=='activity' and route.subsection and route.subsection~='activities' then rows,detail,pending=B.Personal(route,catalog.state)
 else
  local scope=filterScope(route,kind)
  local filterNeeded=route.query and route.query~='' or route.activityKind or route.guid
  local found,why=B.Filter(catalog,scope,filterNeeded and function(item)
   local title=kind=='player' and item.title or M.Title(item)
   return (kind=='player' and contains(item.search,route.query) or kind=='activity' and B.ActivityMatches(catalog.state,item,route.query)) and (not route.activityKind or item.kind==route.activityKind or item.kind=='duel' and item.duel and item.duel.accepted and route.activityKind=='duel_'..item.duel.result) and (not route.guid or item.members and item.members[route.guid])
  end or nil)
  if not found then return {block('filters','History filters',0,.22,tools),block('results','Retained history',.22,.78,why and filterError(scope,why) or {cap('Finding matching subjects…')})},not why end
  local page=math.max(1,math.min(math.ceil(#found/40),tonumber(route.listPage) or 1));rows[1]={title=#found..' matching '..(kind=='player' and 'people' or 'adventures'),detail='Page '..page..' of '..math.max(1,math.ceil(#found/40)),height=35}
  if page>1 then local nextRoute=clone(route);nextRoute.listPage=page-1;rows[#rows+1]=act('BROWSE.PREVIOUS','Previous entries','',go(nextRoute)) end
  for n=(page-1)*40+1,math.min(page*40,#found) do local item=found[n];rows[#rows+1]=act('BROWSE.OPEN',kind=='player' and item.title or M.Title(item),kind=='player' and 'Open player dossier' or M.Status(item)..' · '..C.Stamp(item.startAt),go({page=route.page,kind=kind,key=kind=='player' and item.key or item.id,owner=route.owner}),52);rows[#rows].stacked=true end
  if page*40<#found then local nextRoute=clone(route);nextRoute.listPage=page+1;rows[#rows+1]=act('BROWSE.NEXT','Next entries','',go(nextRoute)) end
 end
 local blocks={block('filters',kind=='player' and 'People filters' or 'Chronicle',0,.22,tools),block('results',kind=='player' and 'Player dossiers' or 'Retained history',.22,#detail>0 and .44 or .78,rows)}
 if #detail>0 then blocks[#blocks+1]=block('selection','Selected observation',.66,.34,detail) end
 return blocks,pending
end
-- Retained-history search remains available through B.Search / My history.
-- The shell owns the global Wiki search handler; do not replace it here.
ns.RecordingUI.OpenSource=function(_,event) return B.Source(event) end
local settings=L.Settings
function L.Settings(route)
 if route.subsection~='source' then return settings(route) end
 local event=route.sourceEvent;if not event then return {block('source','Developer source inspector',0,1,{cap('Source unavailable.')})} end
 local rows={cap('Developer diagnostics · original source fields. This inspector does not replace normal person or adventure pages.'),{title='Source record',detail=event.id,height=44},{title='Observed',detail=C.Stamp(event.at),height=40}}
 local function walk(value,prefix,depth)
  if depth>4 or #rows>160 then return end
  local keys={};for key in pairs(value) do keys[#keys+1]=key end;table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
  for _,key in ipairs(keys) do local v=value[key];local label=prefix..tostring(key);if type(v)=='table' then walk(v,label..' / ',depth+1) else rows[#rows+1]={title=label,detail=tostring(v),height=34} end end
 end
 walk(event,'',0);return {block('source','Developer source inspector',0,1,rows)}
end
