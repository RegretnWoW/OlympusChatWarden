-- Layout contracts from the user's four UI2 mockups. Artwork is a later pass.
-- New frame trees only; all routes still resolve through canonical page models.
local _,ns=...
local L={};ns.UI2Layouts=L
local C,M,P=ns.UI2Components,ns.UI2Models,ns.UI2Pages
local function r(title,detail,activate,more) local out=more or {};out.title=title;out.detail=detail;out.activate=activate;return out end
local function cap(title) return r(title,nil,nil,{wrap=true,height=48,kind='caption'}) end
local function h(rows,header) local n=header==false and 12 or 44;for _,v in ipairs(rows) do n=n+(v.height or 31) end;return n end
local function block(list,id,title,x,y,w,rows,more)
 -- Narrow supporting columns stack long labels before calculating their
 -- heights, so subsequent sections flow correctly instead of clipping.
 if w<=.35 then for _,row in ipairs(rows) do if row.detail and not row.cells and not row.widths and not row.stacked and (#tostring(row.detail)>12 or #tostring(row.title or '')>24) then row.stacked=true;row.height=math.max(52,row.height or 31) end end end
 local b=more or {};b.id=id;b.title=title;b.x=x;b.y=y;b.w=w;b.rows=rows;b.h=b.header==false and 12 or 44;list[#list+1]=b;return y+h(rows,b.header)+12
end
local function nav(kind,key,owner) return function() ns.UI2.Open({page=kind=='player' and 'intel' or 'chronicle',kind=kind,key=key,owner=owner}) end end
local function limited(rows,key,n)
 if #rows<=n then return rows end
 if ns.UI2.expanded[key] then
  local U=ns.UI2;U.sectionPages=U.sectionPages or {};local pages=math.max(1,math.ceil(#rows/40));local page=math.max(1,math.min(pages,U.sectionPages[key] or 1));local out={}
  if page>1 then out[#out+1]=r('Previous entries','Page '..(page-1),function() U.sectionPages[key]=page-1;U.Refresh(true) end,{height=36}) end
  for index=(page-1)*40+1,math.min(page*40,#rows) do out[#out+1]=rows[index] end
  if page<pages then out[#out+1]=r('Next entries','Page '..(page+1)..' of '..pages,function() U.sectionPages[key]=page+1;U.Refresh(true) end,{height=36}) end
  return out
 end
 local out={};for i=1,n do out[i]=rows[i] end
 out[#out+1]=r('Show all '..#rows..' entries','Expand here',function() ns.UI2.expanded[key]=true;ns.UI2.Refresh(true) end)
 return out
end
local function groups(rows)
 local out,key={},nil
 for _,v in ipairs(rows) do if v.kind=='section' then key=v.anchor;out[key or v.title]={};elseif key then out[key][#out[key]+1]=v end end
 return out
end
function L.Player(m,route)
 ns.UI2.sectionPages=ns.UI2.sectionPages or {}
 local b={}
 if route and route.projection=='public' then
  local public=m.aetherNet;local rows={}
  if public then
   rows[#rows+1]=r(public.identity.name or 'Identity not shared',public.identity.realm,nil,{size=25,height=48})
   for _,field in ipairs({'class','race','faction'}) do if public.identity[field] then rows[#rows+1]=r(field:sub(1,1):upper()..field:sub(2),public.identity[field]) end end
   rows[#rows+1]=r('Community rating',public.rating.count>0 and string.format('%.1f / 5 · %d ratings',public.rating.average,public.rating.count) or 'No ratings yet')
   rows[#rows+1]=r('Gamerzone',public.owner and public.owner.gamerzone or 'Not selected')
   if public.owner then rows[#rows+1]=r('About Me',public.owner.about,nil,{wrap=true,height=110}) end
   rows[#rows+1]=cap('Community profile · Private notes, watchlists and historical captures are excluded.')
  else rows[1]=cap(m.publicUnavailable or 'Aether Net is OFF. No published profile is available; unpublished owner drafts are private.') end
  rows[#rows+1]=r('Return to the full dossier','Same character',function() ns.UI2.OpenPlayer(m.key,m.owner) end,{height=42})
  rows[#rows+1]=r('Direct Share this card','Choose one recipient and review the exact fields',function() ns.AthenaSuiteUI.Direct(m.key,m.owner) end,{height=42})
  block(b,'profile','Public profile preview',0,0,1,rows)
  return b
 end
 local v=m.identity;local rating=m.remote and m.remote.rating;local count=rating and rating.count or 0
 local community=count>0 and string.format('%.1f / 5 · %d %s',rating.average,count,count==1 and 'rating' or 'ratings') or (m.aetherNet and 'Aether Net · No ratings yet' or 'Aether Net · OFF')
 if rating and(rating.pendingCount or 0)>0 then community=community..' · '..rating.pendingCount..' pending / historical'end
 local zone=m.declaration and ns.PlayerCard.zones[m.declaration.gamerzone]
 local identity={};if v.level then identity[#identity+1]='Level '..v.level end;if v.race then identity[#identity+1]=v.race end;if v.class then identity[#identity+1]=v.class:sub(1,1):upper()..v.class:sub(2):lower() end
 local voting=ns.PlayerCard.Voting(m.key);voting.guid=m.key
 local actions={{title='Share card',activate=function() ns.UI2.OpenPlayer(m.key,m.owner,'public') end},{title='Group up',activate=function() ns.UI2.canvas:Jump('group') end}}

 local top={r(m.title,community,nil,{size=25,height=42,widths={.6,.4}}),r(table.concat(identity,' · '),v.realm or '',nil,{height=28}),r(v.guild or 'Guild not recorded',m.asOf and 'As of selected date' or nil,m.guildRef and function() ns.UI2.OpenGuild(m.guildRef,m.owner) end or m.self and function() ns.UI2.Open({page='settings',category='profile'}) end,{height=28,badge='Gamerzone · '..(zone and zone.title or 'Not selected')}),{voting=voting,height=36},r(ns.UI2.voteFeedback or (m.sourceState=='synthetic' and 'HEPHAESTUS · Synthetic history and mock votes' or 'Community opinions are separate from recorded accomplishments.'),voting.reason,nil,{kind='caption',height=27})}
 local public=m.aetherNet or ns.AetherNet.ReadSubject('CHARACTER',m.key);local own=m.key==ns.PlayerCard.Own();local net=ns.AetherNet.Active()
 local about={};if public and public.owner then about[#about+1]=r('About Me',public.owner.about~='' and public.owner.about or 'Not provided',nil,{stacked=true,wrap=true,height=110})
 elseif own and m.profileDraft then
  local d=m.profileDraft;about[#about+1]=r('Your unpublished draft',(d.about~='' and d.about or 'About Me not written')..' · Gamerzone: '..(d.gamerzone and ns.PlayerCard.zones[d.gamerzone].title or 'Not selected'),nil,{stacked=true,wrap=true,height=86})
 else about[#about+1]=r('About Me','Not provided',nil,{height=36}) end
 if own then about[#about+1]={height=38,actions={{title=net and net.options.owns(net.principal,'CHARACTER',m.key) and 'Edit public profile' or 'Edit private draft',activate=function()
  if net and net.options.owns(net.principal,'CHARACTER',m.key) then ns.AetherNet.EditOwner(m.key) else ns.AetherNet.EditDraft(m.key) end
 end}}} end

 top[#top+1]={actions=actions,height=36,profileFooter=true}
 if ns.UI2.PlayerDateRows then ns.UI2.PlayerDateRows(m,route,top) end
 block(b,'identity','',0,0,1,top,{header=false,paper=false,portrait={owner=m.owner,guid=m.key,values=v,state=m.sourceState},compactPortrait=true})
 block(b,'about','About Me',.66,190,.34,about)
 local start=math.max(190,h(top,false)+12);local y,ry=start,start;local main,side=.66,.34
 local function section(title,rows,anchor) y=block(b,anchor,title,0,y,main,rows,{anchor=anchor}) end
 local rows={};local presented={}
 for _,kind in ipairs({'dungeon','raid','duel','boss'}) do
  local found={};for _,a in ipairs(m.activities) do if a.category==kind then found[#found+1]=a end end
  table.sort(found,function(a,c) local ar=a.concluded==true;local cr=c.concluded==true;if ar~=cr then return ar end;return a.at>c.at end)
  if #found>0 then
   rows[#rows+1]=r(({dungeon='Dungeon expeditions',raid='Raid adventures',duel='Duels',boss='World encounters'})[kind],nil,nil,{size=13,height=27})
   local key=m.key..'/adventure/'..kind;local expanded=ns.UI2.expanded[key];ns.UI2.sectionPages=ns.UI2.sectionPages or {}
   local page=math.max(1,math.min(math.max(1,math.ceil(#found/40)),ns.UI2.sectionPages[key] or 1));local first=expanded and (page-1)*40+1 or 1;local last=expanded and math.min(page*40,#found) or 1
   if expanded and page>1 then rows[#rows+1]=r('Previous adventures','Page '..(page-1),function() ns.UI2.sectionPages[key]=page-1;ns.UI2.Refresh(true) end,{height=36}) end
   for index=first,last do local a=found[index]
    assert(not presented[a.key],'Duplicate activity presentation');presented[a.key]=true
    rows[#rows+1]={adventure=a,height=240,activityKey=a.key}
   end
   if expanded and last<#found then rows[#rows+1]=r('Next adventures','Page '..(page+1)..' of '..math.ceil(#found/40),function() ns.UI2.sectionPages[key]=page+1;ns.UI2.Refresh(true) end,{height=36}) end
   if #found>1 and not expanded then local key=m.key..'/adventure/'..kind
    rows[#rows+1]=r((#found-1)..' other '..(kind=='dungeon' and (#found==2 and 'expedition' or 'expeditions') or kind=='raid' and (#found==2 and 'raid' or 'raids') or (#found==2 and 'activity' or 'activities')),'Expand here',function() ns.UI2.expanded[key]=true;ns.UI2.Refresh(true) end,{height=32})
   end
  end
 end
 if #rows==0 then rows[1]=cap('No shared dungeon, raid, duel or world encounter retained yet.') end
 section('Adventures',rows,'activities')
 local flat=P.Player(m,true);local s=groups(flat)
 local people={};local sorted={};for _,person in ipairs(m.companions) do sorted[#sorted+1]=person end
 table.sort(sorted,function(a,c) if a.friend~=c.friend then return a.friend==true end;return a.count>c.count or a.count==c.count and a.key<c.key end)
 local lastGroup
 for _,person in ipairs(sorted) do local group=person.friend and 'Recorded friends' or person.count>1 and 'Recurring companions' or 'Met on an adventure'
  if group~=lastGroup then people[#people+1]=r(group,nil,nil,{size=13,height=27});lastGroup=group end
  people[#people+1]=r(person.title,person.count..' distinct adventures · '..(person.latest or 'Shared history'),nav('player',person.key,m.owner),{person=person,stacked=true,height=49})
 end
 if #people==0 then people[1]=cap('No identifiable companions retained in these adventures.') end
 section('Companions · '..#m.companions,limited(people,m.key..'/companions',5),'companions')
 if m.progression then local growth={};for n=#m.progression.recent,1,-1 do local q=m.progression.recent[n];local title=q.title
  if q.kind=='quest_turnin' then local quest=q.questID and ns.AthenaWorldKnowledge.GetQuest(q.questID);title=title or quest and quest.title or 'Assignment completed'
  elseif q.kind=='level_change' then title=q.level and 'Reached level '..q.level or 'Level changed' else title=title or 'Achievement earned' end
  local entry=r(title,C.Stamp(q.at),nil,{stacked=true,height=48});growth[#growth+1]=entry
  if q.kind=='quest_turnin' and ns.AthenaJournalLinks then ns.AthenaJournalLinks.Row(entry,ns.AthenaJournalLinks.Subject('QUEST',q.questID,title)) end
 end;section('Progression',limited(growth,m.key..'/progression',5),'progression') end
 section(m.key==ns.PlayerCard.Own()and'My Posts'or'Agora posts',ns.AetherPosts.ProfileRows(m.key),'posts')
 if ns.WardenStudio.GalleryRows then section('Athena artifacts',ns.WardenStudio.GalleryRows(m.key),'artifacts')end
 section('Character story',{r(m.observer and 'Open your Journey' or 'Read your shared Journey','Athena’s illustrated journal',function() ns.AthenaJournalWindow.Open({owner=m.owner}) end,{stacked=true,height=52})},'story')
 section('Private notes & watchlist',s.notes or {},'notes')
 local match=m.match;local fellowship={}
 if match and match.score then fellowship[#fellowship+1]=r(match.score..'% Player Match',match.state=='Active request' and 'Actively looking for group' or match.state,nil,{size=20,height=42,stacked=true});for _,factor in ipairs(match.contributions or {}) do fellowship[#fellowship+1]=r(factor.reason,'+'..factor.points,nil,{size=13,height=26}) end
 else fellowship[#fellowship+1]=cap('No eligible current match context.') end
 for _,request in ipairs(m.requests or {}) do local quest=request.questID and ns.AthenaWorldKnowledge.GetQuest(request.questID);fellowship[#fellowship+1]=r(request.intent,quest and quest.title or request.activityID and 'Activity '..request.activityID or 'General request',nil,{stacked=true,height=49}) end
 fellowship[#fellowship+1]=r('Outreach',m.outreach,nil,{stacked=true,height=49})
 if m.listing then fellowship[#fellowship+1]=r(m.listing.title,'Inspect current group',function() ns.UI2.Open({page='intel',kind='group',generation=m.listing.generation,resultID=m.listing.resultID}) end,{stacked=true,height=49}) end
 ry=block(b,'fellowship','Fellowship',main,ry,side,fellowship,{anchor='group'})
 local pvp={};if m.pvp then
  pvp[#pvp+1]=r(m.pvp.matchCount..' recorded match boundaries',nil,nil,{size=16,height=34})
  for _,key in ipairs({'killingBlows','deaths','damageDone','healingDone'}) do local value=m.pvp.counters[key];if value~=nil then pvp[#pvp+1]=r(({killingBlows='Killing blows',deaths='Deaths',damageDone='Damage',healingDone='Healing'})[key],C.Number(value)) end end
  pvp[#pvp+1]=cap('Observed Fireside matches; not lifetime totals.')
 else pvp[1]=cap('No scoped scoreboard totals retained.') end
 pvp[#pvp+1]=cap('Wins and losses remain unknown where a result cannot be linked to this player’s team.')
 local matches=0
 local pvpKey=m.key..'/pvp';local pvpCount=0;for _,a in ipairs(m.activities) do if a.category=='battleground' or a.category=='arena' then pvpCount=pvpCount+1 end end
 local pvpPage=math.max(1,math.min(math.max(1,math.ceil(pvpCount/40)),ns.UI2.sectionPages[pvpKey] or 1))
 for _,a in ipairs(m.activities) do if a.category=='battleground' or a.category=='arena' then matches=matches+1
  if ns.UI2.expanded[pvpKey] and matches>(pvpPage-1)*40 and matches<=pvpPage*40 or not ns.UI2.expanded[pvpKey] and matches<=2 then assert(not presented[a.key]);presented[a.key]=true;pvp[#pvp+1]=r(a.place,a.status..' · '..C.Stamp(a.at),nav('activity',a.key,m.owner),{stacked=true,height=52}) end
 end end
 if ns.UI2.expanded[pvpKey] and pvpPage>1 then pvp[#pvp+1]=r('Previous matches','Page '..(pvpPage-1),function() ns.UI2.sectionPages[pvpKey]=pvpPage-1;ns.UI2.Refresh(true) end,{height=36}) end
 if ns.UI2.expanded[pvpKey] and pvpPage*40<matches then pvp[#pvp+1]=r('Next matches','Page '..(pvpPage+1),function() ns.UI2.sectionPages[pvpKey]=pvpPage+1;ns.UI2.Refresh(true) end,{height=36}) end
 if not ns.UI2.expanded[m.key..'/pvp'] and matches>2 then pvp[#pvp+1]=r('Show all '..matches..' match adventures','Expand here',function() ns.UI2.expanded[m.key..'/pvp']=true;ns.UI2.Refresh(true) end) end
 if public then
  pvp[#pvp+1]=r('Shared battleground observations',#public.matches..' distinct matches · '..public.unresolvedObservations..' unresolved observations',nil,{stacked=true,height=52})
  for i,match in ipairs(public.matches) do if i<=8 then
   pvp[#pvp+1]=r(match.metrics.mapName or 'Battleground',match.metrics.result or 'Outcome unknown',nil,{stacked=true,height=48})
   pvp[#pvp+1]=cap(match.sources..' source contributions · '..(#match.conflicts>0 and 'Conflicting fields remain unknown.' or 'Partial observed match; not lifetime statistics.'))
  end end
  if #public.matches>8 then pvp[#pvp+1]=cap('Additional shared matches remain in the bounded public cache; full event navigation is not yet available.') end
 end
 ry=block(b,'pvp','PvP history',main,ry,side,pvp,{anchor='pvp'})
 local claims={};for _,claim in ipairs(m.remote and m.remote.claims or {}) do local card=claim.card
  for _,spec in ipairs({{'guild','guild'},{'class','class'},{'race','race'}}) do if card[spec[1]] and card[spec[1]]~=v[spec[2]] then claims[#claims+1]=r('Peer-reported '..spec[1],card[spec[1]],nil,{stacked=true,height=49}) end end
 end
 if #claims>0 then ry=block(b,'claims','Additional shared information',main,ry,side,claims) end
 block(b,'coverage','About this history',0,math.max(y,ry),1,{cap('This page covers this observer’s retained history. Shared group membership does not prove attendance at every boss, and community stars are opinions.')})
 b.presentedActivities=presented
 return L.PlayerSections and L.PlayerSections(m,route,b) or b
end

function L.Activity(m)
 local b={};local source=m.sourceState=='synthetic' and 'HEPHAESTUS · SYNTHETIC OBSERVATIONS' or m.sourceState=='shared' and 'AUTHORIZED SHARED OBSERVATIONS · PARTIAL' or 'YOUR OBSERVED HISTORY'
 local top={r(m.title,m.status,nil,{size=23,height=48}),r(C.Stamp(m.firstAt)..' to '..(m.endAt and C.Stamp(m.endAt) or 'End not recorded'),source,nil,{kind='caption'}),r((m.sourceState=='shared' and 'Encounter attempts not shared' or m.attemptCount..' encounter attempts')..' · '..#m.participants..' known participants',m.combatSummary.minimum and m.combatSummary.minimum..'% lowest observed health' or m.measuredSeconds.value and string.format('%.1f observed minutes',m.measuredSeconds.value/60) or nil),r(m.summary,nil,nil,{wrap=true,height=68,size=14})}
 block(b,'identity','',0,0,1,top,{header=false,paper=false})
 local flat=P.Activity(m);local s=groups(flat);local y=202
 y=block(b,'encounters','Encounters & progression',0,y,.65,s.encounters or {},{anchor='encounters'})
 if s.scoreboard then y=block(b,'scoreboard','Match scoreboard',0,y,.65,s.scoreboard,{anchor='scoreboard'}) end
 local captures={};for _,capture in pairs(m.momentCaptures or{})do captures[#captures+1]=r(capture.title,C.Stamp(capture.at)..' · '..capture.status,nil,{height=32})end
 if #captures>0 then table.sort(captures,function(a,b)return a.title<b.title end);captures[#captures+1]=cap('Screenshot requests are linked to this event. Images stay in WoW’s Screenshots folder; no filenames or imported pictures are inferred.');y=block(b,'moments','Athena’s Moments',0,y,.65,captures,{anchor='moments'})end
 local qy=y;local qend=block(b,'quests','Quests & objectives',0,qy,.325,s.quests or {},{anchor='quests'})
 local lend=block(b,'loot','Loot & rewards',.325,qy,.325,s.loot or {},{anchor='loot'})
 y=math.max(qend,lend)
 local people={}
 if #m.participants==0 then people[1]=cap('No identifiable roster recorded. No participants inferred.') end
 for _,person in ipairs(m.participants) do local v=person.identity
  people[#people+1]=r(person.title,(v.class or 'Class unknown')..(v.level and ' · '..v.level or ''),nav('player',person.key,m.owner),{person=person,height=29,widths={.57,.43}})
 end
 local ry=block(b,'participants','Participants · '..#m.participants..' known',.65,202,.35,people,{anchor='participants'})
 if #m.participants<=8 then ry=block(b,'combat','Combat highlights',.65,ry,.35,s.combat or {},{anchor='combat'})
 else y=block(b,'combat','Combat highlights',0,y,.65,s.combat or {},{anchor='combat'}) end
 y=block(b,'timeline','Significant moments',0,y,.65,limited(s.timeline or {},m.key..'/timeline',16),{anchor='timeline'})
 
 y=block(b,'coverage','Sources & coverage',0,math.max(y,ry),1,s.coverage or {},{anchor='coverage'})
 if m._activity and m.owner==ns.Chronicle.Owner()then y=block(b,'share','Share as Post',0,y,1,{r('Share as Post','Review a limited owner-approved Athena observation',function()ns.AetherPosts.ShareActivity(m.owner,m.key)end)})end
 if m.eventRef then
  local ref=m.eventRef;local public=ns.AetherNet.ReadSubject('EVENT',ref.key)
  local feedback={cap('Participant commendations are opinions. Observed performance and global ratings remain separate.')}
  for _,person in ipairs(m.participants) do local p=person;feedback[#feedback+1]=r('Commend '..p.title,'Verified eligible participant required',function() ns.AetherNet.EventFeedback(ref.key,p.key) end,{height=36}) end
  for n,item in ipairs(public.feedback or {}) do if n<=20 then local f=item;feedback[#feedback+1]=r(item.category..' · '..item.author,item.text,nil,{wrap=true,stacked=true,height=75})
   local c=ns.AetherNet.Active();local actions={{title='Save content concern',activate=function() ns.UI2Operations.CommunityConcern('EVENT',m.key,f,'Event feedback') end}}
   if c and c.principal==f.author then actions[#actions+1]={title='Edit',activate=function() ns.AetherNet.EventFeedback(ref.key,f.target) end};actions[#actions+1]={title='Withdraw',activate=function() ns.AetherNet.RemoveFeedback(ref.key,f) end}
   else actions[#actions+1]={title='Mute author',activate=function() ns.AetherNet.MuteAuthor(f.author,true) end} end
   feedback[#feedback+1]={actions=actions,height=36}
  end end
  block(b,'feedback','Event feedback',0,y,1,feedback,{anchor='feedback'})
 end
 return b
end
function L.Guild(v,route)
 local c=ns.AetherNet.Active();local rating=v.rating;local entry=c and c.records['GUILD/'..v.key..'/GUILD_VOTE/'..c.principal..'/vote']
 local voting={kind='GUILD',key=v.key,maximum=10,enabled=ns.AetherNet.PublicationAvailable(),stars=entry and not entry.record.removed and entry.record.data.score,reason=ns.AetherNet.PublicationAvailable() and ns.AetherNet.PublicationScope() or 'Enable Aether participation to publish your rating.'}
 local rows={r(v.title,v.identity.realm,nil,{size=25,height=42}),
  r(rating.count>0 and string.format('%.1f / 10 · %d guild ratings',rating.average,rating.count) or 'No guild ratings yet',v.provisional and 'Provisional local identity' or 'Community observations',nil,{height=31}),
  r('Guildzone',v.guildzone or 'Not selected'),{voting=voting,height=36},
  cap('Recorded associations · Not a complete or current guild roster. Community opinions do not certify accomplishments.'),
  r(ns.UI2.voteFeedback or voting.reason,nil,nil,{kind='caption',wrap=true,height=32})}
 local members={};for _,member in ipairs(v.members) do local p=member
  local person=not v.provisional and c and c:View('CHARACTER',member.key);local identity=member.identity or person and person.identity or {}
  members[#members+1]=r(identity.name or 'Unidentified member','Observed association · current membership unknown',function() ns.UI2.OpenPlayer(p.key,v.owner) end,{person={owner=v.owner,key=member.key,values=identity,state=v.provisional and 'recorded' or 'shared'}})
 end
 local events={};for _,event in ipairs(v.events) do local e=event
  events[#events+1]=r(e.name,e.scope,(e.localActivity or ns.AetherNet.Subject('EVENT',e.key)) and function() ns.UI2.Open({page='chronicle',kind='activity',key=e.key,owner=e.owner or v.owner,originGuild=v.key}) end or nil)
 end
 return {{id='identity',title='Guild Profile',rows=rows},
  {id='members',title='Players',rows={{collection={key=v.key..'/players',label='players',items=members,height=430},height=430}}},
  {id='events',title='Events',rows={{collection={key=v.key..'/events',label='events',items=events,height=430},height=430}}},
  {id='posts',title='The Agora',rows={{title='Open community posts',detail='World and predefined rooms; no guild Wall',activate=function()ns.AetherPosts.Open({room='world'})end,height=55}}}}
end

function L.Home(route)
 local b={};local activities,st=M.Browse('activity',route.owner);local latest=activities and activities[1]
 local c=ns.ChronicleStore.Character(route.owner or ns.Chronicle.Owner(),false);local own=(route.owner or ns.Chronicle.Owner() or ''):match('/(Player%-.+)$');local p=c and c.profiles[own];local facts=p and p.facts or {}
 local profile,profileState;if own then profile,profileState=M.GetPlayerPage(own,route.owner) end
 local function fact(k) return profile and profile.identity[k] or facts[k] and facts[k].value end
 local zone=ns.SafeString(ns.SafeCall(GetZoneText),100) or 'Azeroth'
 local hero={r('Continue your journey',nil,nil,{size=16,height=30}),r('The road through '..zone,nil,nil,{size=28,height=52}),cap('Your recorded adventures, encounters and companions form the next chapter of your life in Azeroth.')}
 block(b,'hero','',0,0,.75,hero,{header=false,paper=false})
 local quick={r('View Chronicle','Open activity dossiers',function() ns.UI2.Open({page='chronicle'}) end,{height=39}),r('Open Intel','Find a person',function() ns.UI2.Open({page='intel'}) end,{height=39}),r('Check messages','Review captured messages',function() ns.UI2.Open({page='messages'}) end,{height=39}),r('Manage Fireside','Settings',function() ns.UI2.Open({page='settings'}) end,{height=39})}
 quick[#quick+1]=r('Open Olympus','Connected guild addon',function() local ok,why=ns.OlympusIntegration.Open();if not ok and ns.UI2Forms then ns.UI2Forms.Feedback(false,why or 'Olympus is not currently available.') end end,{height=39})
 local overviewY=math.max(232,block(b,'quick','Quick actions',.75,0,.25,quick))
 local identity={r(fact('name') or 'This character',fact('class') or 'Class not recorded',nil,{size=19,height=40}),r('Level',fact('level') and tostring(fact('level')) or 'Not recorded'),r('Guild',fact('guild') or 'Not recorded'),r('Current zone',zone)}
 local leftEnd=block(b,'character','Character overview',0,overviewY,.375,identity)
 local recent={}
 if latest then recent={r(M.Title(latest),M.Status(latest),nav('activity',latest.id,st.owner),{wrap=true,height=62}),r('Observed',C.Stamp(latest.startAt)),cap('Open the full activity page for encounters, participants, quests, loot and its connected timeline.')}
 else recent={cap('No retained activity is available yet. Existing archive validation continues independently.')} end
 local midEnd=block(b,'recent','Recent adventure',.375,overviewY,.375,recent)
 local alerts={};for n=#ns.Review.entries,math.max(1,#ns.Review.entries-4),-1 do local e=ns.Review.entries[n];alerts[#alerts+1]=r(e.sender or 'Review observation',e.action, function() ns.UI2.Open({page='messages',messageID=e.id}) end,{height=34}) end
 if #alerts==0 then alerts[1]=cap('No current review alerts. No external news feed is implied.') end
 block(b,'signals','Recent signals',.75,overviewY,.25,alerts)
 local y=math.max(leftEnd,midEnd)
 local intel={};local people=M.Browse('player',route.owner);for n=1,math.min(4,#(people or {})) do local person=people[n];intel[#intel+1]=r(person.title,'Open dossier',nav('player',person.key,person.owner)) end;if #intel==0 then intel[1]=cap('No retained player identity available.') end
 block(b,'people','People & shared history',0,y,.25,intel)
 local fellowship={};for _,person in ipairs(ns.Fellowship.Top()) do fellowship[#fellowship+1]=r(person.name,person.score..'% Player Match',nav('player',person.guid,ns.Chronicle.Owner())) end;if #fellowship==0 then fellowship[1]=cap('No fresh eligible request recorded. No background search runs when Home opens.') end
 block(b,'fellowship','Fellowship opportunities',.25,y,.25,fellowship)
 block(b,'aether','Aether activity',.5,y,.25,{cap(ns.AetherNet.ServiceState()),r('Peer exchange','P2P · original-author certificates'),cap('Local posts remain available before enrollment. Authenticated forwarding is implemented; real-client enrollment and delivery remain unverified.')})
 block(b,'resources','Resources & support',.75,y,.25,{r('Recording & data','Configure',function() ns.UI2.Open({page='settings',category='data'}) end),r('About this build','UI2 · development checkpoint'),r('Private Lab','Open Hephaestus',function() if ns.WardenSimLab then ns.WardenSimLab.Enable(true);ns.WardenSimLab.Open('grounds') end end)})
 local bottom=y+214
 block(b,'protection','Protection summary',0,bottom,.5,{r('Chat filtering',ns.DB.chat==false and 'Paused' or 'Enabled'),r('Shield',ns.DB.shield and ns.DB.shield.enabled==false and 'Paused' or 'Enabled'),r('Your preferences','Manage protections',function() ns.UI2.Open({page='settings',category='protections'}) end)})
 local health=ns.ChronicleStore.Residency()
 block(b,'health','Database health',.5,bottom,.5,{r('Archive state',health.validated and 'Validated retained history' or 'Validation in progress'),r('Loaded records',C.Number(health.loadedEvents)),r('Local recording',ns.Chronicle.InWorld() and 'Active' or 'Paused')})
 return b,not activities or own and not profile and profileState~='Access or module unavailable'
end
function L.Browse(route)
 local flat,_,pending=P.Browse(route);local rows={};for i=3,#flat do rows[#rows+1]=flat[i] end
 local b={};block(b,'results',route.page=='intel' and 'Player dossiers' or 'Activity dossiers',0,0,1,rows)
 return b,pending
end
function L.Chat(route)
 local b={};local entries=ns.Review.entries;local captures=ns.ChatCapture.db and ns.ChatCapture.db.entries or {};local selected=route.messageID and ns.Review.Get(route.messageID) or not route.activityID and entries[#entries]
 local source=route.activityID and ns.Activity.Get(route.activityID)
 local filters={r('All captured messages',tostring(#captures)),r('Review queue',tostring(#entries)),r('Private bookmarks',tostring(#(ns.ChatCapture.db and ns.ChatCapture.db.bookmarks or {}))),cap('Capture and review are local. Opening this workspace sends no message.')}
 block(b,'filters','Channels & filters',0,0,.19,filters)
 block(b,'tools','Chat tools',0,234,.19,{r('Capture preferences','Configure',function() ns.UI2.Open({page='settings',category='chat'}) end),r('Signed rule packs',#ns.RulePacks.Order..' installed'),r('Personal rules',#ns.Personal.rules..' saved'),r('Spelling','Existing dictionary preserved')})
 local messages={};for n=#entries,math.max(1,#entries-30),-1 do local e=entries[n];local entry=e
  messages[#messages+1]=r(e.sender or ns.Review.Source(e),(e.action or 'Review')..' · '..C.Stamp(e.timestamp,true),function() local copy={page='messages',messageID=entry.id};ns.UI2.Open(copy,true) end,{height=29,size=14})
  messages[#messages+1]=r(ns.Review.DisplayOriginal(e) or 'Message unavailable',nil,function() ns.UI2.Open({page='messages',messageID=entry.id},true) end,{height=62,wrap=true})
 end
 if #messages==0 then for n=#captures,math.max(1,#captures-15),-1 do local e=captures[n];messages[#messages+1]=r(e.sender,C.Stamp(e.timestamp,true));messages[#messages+1]=r(e.original,nil,nil,{wrap=true,height=62}) end end
 if #messages==0 then messages[1]=cap('No messages retained in the permitted capture scope. Enable capture in Settings if wanted.') end
 block(b,'history','Message history & review',.19,0,.49,messages)
 local review={}
 if source and not selected then
  review={r(ns.Activity.DisplayName(source.sender),'Mention · '..C.Stamp(source.timestamp,true),nil,{height=43,size=17}),r(source.preview or 'This message is no longer retained.',nil,nil,{height=115,wrap=true,size=15})}
  local guid=ns.Athena.ResolveContact(source.sender);if guid then review[#review+1]=r('Player context','Open dossier',nav('player',guid,ns.Chronicle.Owner())) end
 elseif selected then
  review={r(selected.sender or 'Observed text',selected.action,nil,{height=36,size=16}),r(ns.Review.DisplayOriginal(selected),nil,nil,{height=115,wrap=true,size=15})}
  local guid=selected.sender and ns.Athena.ResolveContact(selected.sender)
  if guid then review[#review+1]=r('Player context','Open canonical dossier',nav('player',guid,ns.Chronicle.Owner())) end
  review[#review+1]=r('Mark reviewed','Keep filtering policy unchanged',function() ns.Review.Mark(selected.id,'reviewed');ns.UI2.Refresh(true) end)
  review[#review+1]=cap('Report submission and per-message rule editing are still being migrated. No review action transmits a report.')
 else review[1]=cap('Choose a retained message to review its content and context.') end
 local ry=block(b,'selection','Message review',.68,0,.32,review)
 block(b,'queue','Review queue',.68,ry,.32,{r('Messages retained',tostring(#entries)),r('Unread alerts',tostring(ns.Review.Unread())),r('Current capture',ns.ChatCapture.db and ns.ChatCapture.db.enabled and 'Enabled' or 'Off')})
 return b
end
function L.Settings(route)
 local b={};block(b,'heading','',0,0,.75,{r('Settings',nil,nil,{size=30,height=54}),cap('Configure Olympus to fit your journey. Saved keys, scopes and consent remain unchanged.')},{header=false,paper=false})
 local categories={{'general','General'},{'profile','My Aether profile'},{'appearance','Appearance'},{'data','Data & performance'},{'notifications','Notifications'},{'aether','Aether'},{'protections','Protections'},{'modules','Modules'},{'advanced','Advanced'}}
 local cr={};for _,pair in ipairs(categories) do local key,title=pair[1],pair[2];cr[#cr+1]=r(title,key==(route.category or 'general') and 'Selected' or '',function() ns.UI2.Open({page='settings',category=key},true) end,{height=48,size=14}) end
 block(b,'categories','Settings categories',0,130,.25,cr)
 local category=route.category or 'general';local controls={}
 local function toggle(label,get,set,detail) controls[#controls+1]=r(label,get() and 'On · click to change' or 'Off · click to change',function() set(not get());ns.UI2.Refresh(true) end,{height=43});if detail then controls[#controls+1]=cap(detail) end end
 if category=='profile' then
  controls[#controls+1]=cap('Your player card is the same canonical Intel dossier. Aether stars are community opinions; Gamerzone is your optional self-description.')
  local own=ns.PlayerCard.Own();local declaration=ns.PlayerCard.Local(own)
  for _,key in ipairs(ns.PlayerCard.order) do local zone=key;local value=ns.PlayerCard.zones[zone]
   controls[#controls+1]=r(value.title,declaration and declaration.gamerzone==zone and 'Selected' or 'Choose',function() ns.PlayerCard.Select(zone);ns.UI2.Refresh(true) end,{height=38})
   controls[#controls+1]=cap(value.description)
  end
  controls[#controls+1]=r('Leave Gamerzone unset','Clear selection',function() ns.PlayerCard.Select(nil);ns.UI2.Refresh(true) end)
  controls[#controls+1]=r('Open my player card','Same Intel dossier',nav('player',own,ns.Chronicle.Owner()))
  controls[#controls+1]=cap('Choosing a zone never enables Aether or sends a card. New sharing fields require renewed consent. Private notes and watch status are never included.')
 elseif category=='notifications' then
  for _,spec in ipairs({{'badges','Notification bell & unread badges'},{'filtered','Filtered-message notifications'},{'hidden','Hidden messages'},{'redacted','Redacted messages & names'},{'language','Language filtering'},{'shield','Contact protection'},{'spam','Repeated messages & rapid chat'},{'advertising','Gold & paid-service ads'},{'recruitment','Recruitment ads'},{'athena','Athena filtering advisories'},{'athenaWatched','Watched-player activity'},{'athenaEarned','Important-player activity'}}) do local key,title=spec[1],spec[2]
   toggle(title,function() return ns.Notifications.Get(key) end,function(value) ns.Notifications.Set(key,value) end)
  end
  toggle('Mentions',function() return ns.Mentions.db and ns.Mentions.db.enabled end,function(value) ns.Mentions.Set('enabled',value) end)
  controls[#controls+1]=cap('Notification preferences change alerts only. Filtering, recorded originals, collection consent and sharing stay independent.')
 elseif category=='modules' then for _,id in ipairs(ns.Modules.order) do local key=id;toggle(ns.Modules.names[id],function() return ns.Modules.Selected(key) end,function(value) ns.Modules.Set(key,value) end) end
 elseif category=='data' then
  controls[#controls+1]=r('Local recording',ns.Chronicle.Status(),nil,{wrap=true,height=66})
  controls[#controls+1]=cap('Recording consent remains in the established consent workflow. Data removal and restore actions are not exposed until their UI2 migration is tested.')
 elseif category=='aether' then controls[#controls+1]=cap('Aether is off by default. Its independent identity, transport, queries and reciprocity remain capability-gated pending native validation.')
 elseif category=='appearance' then
  controls[#controls+1]=r('Window scale',tostring(ns.DB.workspaceScale or 'Fit screen'))
  controls[#controls+1]=r('Smaller interface','Reduce scale',function() ns.DB.workspaceScale=math.max(.5,(ns.DB.workspaceScale or 1)-.05);ns.UI2.Fit();ns.UI2.Refresh(true) end)
  controls[#controls+1]=r('Larger interface','Increase scale',function() ns.DB.workspaceScale=math.min(1.5,(ns.DB.workspaceScale or 1)+.05);ns.UI2.Fit();ns.UI2.Refresh(true) end)
 elseif category=='protections' then
  toggle('Shield protection',function() return ns.DB.shield.enabled~=false end,function(value) ns.Shield.SetOption('enabled',value) end)
  for _,kind in ipairs(ns.Shield.RuleKinds) do local rule=ns.Shield.GetRule(kind);controls[#controls+1]=r(ns.Shield.RuleTitles[kind],rule[1]..' in '..rule[2]..'s · shield '..rule[3]..'s') end
 elseif category=='chat' then for _,key in ipairs({'enabled','whispers','guild'}) do local k=key;toggle(({enabled='Local chat capture',whispers='Retain whispers',guild='Retain guild messages'})[key],function() return ns.ChatCapture.db[k]==true end,function(value) ns.ChatCapture.SetOption(k,value) end) end
 else
  toggle('Chat filtering',function() return ns.DB.chat~=false end,function(value) ns.DB.chat=value;ns.PolicyChanged();if ns.RefreshUI then ns.RefreshUI(true) end end)
  toggle('Minimap launcher',function() return ns.DB.wardenMinimap==true end,function(value) ns.WardenLaunchers.Set('wardenMinimap',value) end)
  toggle('Reduced Journey motion',function() return ns.DB.journalReducedMotion==true end,function(value) ns.DB.journalReducedMotion=value end)
  controls[#controls+1]=cap('Additional controls are undergoing a function-by-function parity audit. This UI2 checkpoint is not a replacement release.')
 end
 block(b,'controls',category=='general' and 'General settings' or category:sub(1,1):upper()..category:sub(2),.25,130,.50,controls)
 local health=ns.ChronicleStore.Residency();local hy=block(b,'health','Database health',.75,0,.25,{r('Retained history',health.validated and 'Validated' or 'Preparing'),r('Loaded records',C.Number(health.loadedEvents)),r('Packed archives',C.Number(health.packedCharacters)),cap('No online synchronization or backup schedule is assumed.')})
 hy=block(b,'backup','Backup & restore',.75,hy,.25,{cap('Existing backups are preserved. New restore and export controls await migration and verification.')})
 block(b,'verification','Build verification',.75,hy,.25,{r('UI2 migration','In progress'),r('Native actions','NATIVE-PENDING'),cap('This internal checkpoint is not approved for replacing UI1.')})
 return b
end
function L.Service(route)
 local b={};local title=({shield='Shield',mentions='Signal',relay='Relay'})[route.page] or 'Workspace'
 block(b,'heading','',0,0,1,{r(title,nil,nil,{size=30,height=55}),cap('Existing services and saved policy are preserved. UI2 action migration is in progress.')},{header=false,paper=false})
 local rows={}
 if route.page=='shield' then for _,contact in ipairs(ns.Shield.List()) do rows[#rows+1]=r(contact.name,contact.reason or 'Active protection') end;if #rows==0 then rows[1]=cap('No active contact shields.') end
 elseif route.page=='mentions' then for _,e in ipairs(ns.Review.entries) do if ns.Review.ActivityCategory(e)=='alerts' then rows[#rows+1]=r(e.sender or 'Alert',e.original,nil,{wrap=true,height=66}) end end;if #rows==0 then rows[1]=cap('No retained Signal alerts.') end
 else rows={r('Saved reports',tostring(#ns.Personal.reports)),r('Direct Share','Explicit review required · action migration pending'),r('Aether','Off by default · native transport pending'),cap('No message or report is sent by opening Relay.')} end
 block(b,'context',title..' context',0,132,.68,rows)
 block(b,'preferences','Preferences',.68,132,.32,{r('Configure '..title,'Central Settings',function() ns.UI2.Open({page='settings',category=route.page=='shield' and 'protections' or route.page=='relay' and 'aether' or 'notifications'}) end)})
 return b
end
