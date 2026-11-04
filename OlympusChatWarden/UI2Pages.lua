-- UI2 composed pages: compact tables, linked identities, in-page sections.
local _,ns=...
local P={};ns.UI2Pages=P
local C,M=ns.UI2Components,ns.UI2Models
local function add(rows,kind,title,detail,activate,more)
 local row=more or {};row.kind=kind;row.title=title;row.detail=detail;row.activate=activate;rows[#rows+1]=row;return row
end
local function section(rows,title,anchor) return add(rows,'section',title,nil,nil,{anchor=anchor}) end
local function go(kind,key,owner) return function() ns.UI2.Open({page=kind=='player' and 'intel' or kind=='activity' and 'chronicle' or kind,kind=kind,key=key,owner=owner}) end end
local function source(rows,m)
 add(rows,'caption',m.sourceState=='synthetic' and 'HEPHAESTUS · SIMULATED OBSERVATIONS' or m.sourceState=='unknown' and 'NO RETAINED OBSERVATIONS' or 'YOUR OBSERVED HISTORY',m.sourceState=='synthetic' and 'Synthetic evidence · native behavior not verified' or 'Local, source-qualified information')
end
local function metrics(rows,list)
 local cells,widths={},{};local n=math.min(#list,5)
 for i=1,n do local r=list[i];cells[i]=C.Number(r.value)..'  '..r.label;widths[i]=1/n end
 if n>0 then add(rows,'columns','',nil,nil,{cells=cells,widths=widths,height=42}) end
end
function P.Activity(m)
 local rows={};add(rows,'hero',m.title,m.status);source(rows,m)
 add(rows,'row',m.status,C.Stamp(m.firstAt)..' → '..(m.endAt and C.Stamp(m.endAt) or 'End not recorded'))
 metrics(rows,m.metrics)
 if m.measuredSeconds.value then add(rows,'caption','Measured time in observed segments',string.format('%.1f minutes',m.measuredSeconds.value/60)) end
 section(rows,'Encounters & progression','encounters')
 if #m.encounters==0 then add(rows,'caption','No encounter outcomes recorded','Completion and boss attendance remain unknown') end
 for _,t in ipairs(m.encounters) do
  local parts={#t.attempts..(#t.attempts==1 and ' attempt' or ' attempts')}
  for _,spec in ipairs({{t.defeats,'defeat'},{t.victories,'victory'},{t.unresolved,'unresolved'}}) do if spec[1]>0 then parts[#parts+1]=spec[1]..' '..(spec[2]=='victory' and spec[1]>1 and 'victories' or spec[2]..(spec[2]~='unresolved' and spec[1]>1 and 's' or '')) end end
  local row=add(rows,'row',t.title,table.concat(parts,' · '),nil,{stacked=true,height=68,size=19})
  if ns.AthenaJournalLinks then ns.AthenaJournalLinks.Row(row,ns.AthenaJournalLinks.Subject('BOSS',t.encounterID,t.title)) end
 end
 if #m.boards>0 then
  local b=m.boards[1];section(rows,'Match scoreboard','scoreboard')
  add(rows,'caption',b.complete and 'Complete captured scoreboard' or 'Partial scoreboard observation','Latest board for this exact match · '..C.Stamp(b.lastAt))
  local widths={.34,.11,.11,.11,.17,.16}
  add(rows,'columns','',nil,nil,{cells={'Player','Kills','HK','Deaths','Damage','Healing'},widths=widths})
  for _,r in ipairs(b.rows) do add(rows,'row','',nil,r.key and go('player',r.key,m.owner),{cells={r.title,C.Number(r.values.killingBlows),C.Number(r.values.honorableKills),C.Number(r.values.deaths),C.Number(r.values.damageDone),C.Number(r.values.healingDone)},widths=widths}) end
 end
 section(rows,'Participants · '..#m.participants..' identified','participants')
 if #m.participants==0 then add(rows,'caption','No identifiable roster was recorded','No players have been inferred') else
  add(rows,'columns','',nil,nil,{cells={'Player','Class / level','Guild','Role observed'},widths={.30,.24,.30,.16}})
  for _,r in ipairs(m.participants) do local v=r.identity
   add(rows,'row','',nil,go('player',r.key,m.owner),{person=r,cells={r.title,(v.class or 'Unknown class')..(v.level and ' · '..v.level or ''),v.guild or 'Not recorded',r.role or 'Not recorded'},widths={.30,.24,.30,.16},height=30})
  end
 end
 section(rows,'Quests & objectives','quests')
 if #m.quests==0 then add(rows,'caption','No linked quest changes recorded','This does not establish whether anyone had related quests') end
 for _,r in ipairs(m.quests) do local row=add(rows,'row',r.title,r.status..' · '..C.Stamp(r.at,true));if ns.AthenaJournalLinks then ns.AthenaJournalLinks.Row(row,ns.AthenaJournalLinks.Subject('QUEST',r.questID,r.title)) end end
 section(rows,'Loot & rewards','loot')
 if #m.loot==0 then add(rows,'caption','No linked item receipt recorded','This does not mean no loot dropped') end
 for _,r in ipairs(m.loot) do
  local row=add(rows,'row',r.title,(r.quantity.value and '×'..r.quantity.value..' · ' or '')..r.recipient,nil,{icon=r.icon,stacked=true,height=52,itemLink=r.link})
  if ns.AthenaJournalLinks then ns.AthenaJournalLinks.Row(row,ns.AthenaJournalLinks.Subject('ITEM',r.itemID,r.title)) end
  add(rows,'caption',r.scope,'Observed '..C.Stamp(r.at))
 end
 section(rows,'Combat observations','combat')
 if m._activity then for _,r in ipairs(ns.UI2Combat.Rows('chronicle',m.owner,nil,{activity=m._activity.id,label=m.title..' · linked combat'})) do rows[#rows+1]=r end end
 local combat=m.combatSummary
 if combat and combat.minimum~=nil then
  add(rows,'row','Lowest observed health',combat.minimum..'%',nil,{size=18,height=41})
  if combat.closeCall then add(rows,'row','Recovery after low health',combat.recoveryObserved and 'Observed' or 'Not recorded',nil,{stacked=true,height=52}) end
 elseif #m.combat==0 then add(rows,'caption','No personal combat highlights recorded',nil,nil,{wrap=true,height=48})
 end
 section(rows,'Connected timeline','timeline')
 for _,r in ipairs(m.timeline) do local anchor=r.section;add(rows,'row',r.title,C.Stamp(r.at,true),anchor and function() ns.UI2.canvas:Jump(anchor) end,{stacked=true,height=49}) end
 if (m.timelineOmitted or 0)>0 then add(rows,'caption','The overview prioritizes battles, quest developments and rewards.','Full details remain in each section on this page.',nil,{stacked=true,height=56}) end
 section(rows,'Your perspective','recollections')
 section(rows,'Sources & coverage','coverage')
 for _,text in ipairs(m.coverage) do add(rows,'caption',text,'',nil,{wrap=true,height=38}) end
 if m._activity then add(rows,'row','Read this adventure in Athena',nil,function() ns.AthenaJournalWindow.Open({owner=m.owner,activityRef=ns.Athena.EvidenceRef(m._activity.anchor)}) end) end
 return rows,{{'encounters','Encounters'},{'participants','People'},{'quests','Quests'},{'loot','Loot'},{'timeline','Timeline'},{'coverage','Coverage'}}
end
function P.Player(m,compact)
 local rows={};local v=m.identity
 add(rows,'hero',m.title,m.watch and 'Watched / important' or m.relationship);source(rows,m)
 local parts={};for _,k in ipairs({'level','race','class','guild'}) do if v[k]~=nil then parts[#parts+1]=(k=='level' and 'Level ' or '')..v[k] end end
 add(rows,'row',#parts>0 and table.concat(parts,' · ') or 'Identity details not recorded','Last observed: '..C.Stamp(m.lastAt),nil,{person={key=m.key,owner=m.owner,identity=v},height=38})
 metrics(rows,m.metrics)
 if not compact then
 section(rows,'Relationships & shared history','relationships')
 add(rows,'row',m.relationship or 'No relationship observations',m.watch and 'On your private watchlist' or 'Not watched')
 for _,r in ipairs(m.interactions) do add(rows,'row',r.title,C.Stamp(r.at)) end
 section(rows,'Shared activities','activities')
 if #m.activities==0 then add(rows,'caption','No shared activity retained','No inferred attendance or accomplishments') end
 for _,r in ipairs(m.activities) do add(rows,'row',r.title,r.status..' · '..C.Stamp(r.at),go('activity',r.key,r.owner),{height=51,stacked=true}) end
 end
 if m.pvp and not compact then
  section(rows,'Observed PvP','pvp');add(rows,'caption',m.pvp.scope,m.pvp.matchCount..' recorded matches · '..m.pvp.coverage)
  for _,k in ipairs({'killingBlows','honorableKills','deaths','damageDone','healingDone','honorGained'}) do if m.pvp.counters[k]~=nil then add(rows,'row',({killingBlows='Killing blows',honorableKills='Honorable kills',deaths='Deaths',damageDone='Damage',healingDone='Healing',honorGained='Honor'})[k],C.Number(m.pvp.counters[k])) end end
 end
 if #m.equipment>0 then
  section(rows,'Last recorded equipment','equipment')
  for _,slot in ipairs(ns.WardenDossier.slots) do local r=ns.WardenDossier.Slot(m.equipment[1],slot[1]);if r[2]~='unavailable' then add(rows,'row',slot[2],r[3] and tostring(r[3]) or 'Observed empty') end end
 end
 section(rows,'Group & public intelligence','group')
 if m.listing then add(rows,'row',m.listing.title,'Inspect current listing',function() ns.UI2.Open({page='intel',kind='group',generation=m.listing.generation,resultID=m.listing.resultID}) end)
 else add(rows,'caption','No current validated leader listing','Opening this dossier does not search, contact or invite anyone') end
 add(rows,'caption','Aether information is separate from your observations','No public claim or rating has been attached to this dossier')
 section(rows,'Private notes & watchlist','notes')
 if m.note and m.note~='' then add(rows,'row',m.note,'Private note',nil,{wrap=true,height=64}) else add(rows,'caption','No private note saved','Notes are never treated as collector evidence') end
 if m.owner==ns.Chronicle.Owner() and m.known then
  add(rows,'row',m.watch and 'Remove from watchlist' or 'Watch this player','Private and reversible',function() if ns.Chronicle.SetPersonal(m.key,nil,not m.watch) then M.Clear();ns.UI2.Refresh(true) end end)
  add(rows,'row','Write a private note','Edit',function() ns.UI2.EditNote(m) end)
 end
 section(rows,'Observation coverage','coverage');for _,text in ipairs(m.coverage) do add(rows,'caption',text,'',nil,{wrap=true,height=38}) end
 return rows,{{'relationships','Relationship'},{'activities','Activities'},{'group','Group context'},{'notes','Notes'},{'coverage','Coverage'}}
end
function P.Group(m)
 local rows={};add(rows,'hero',m.title,'Group intelligence');source(rows,m)
 add(rows,'caption',m.native,'Read-only adapter · no Apply, sort or outbound traffic')
 metrics(rows,{{label='Group Match',value=m.match.score},{label='Identified members',value=m.listing.knownMembers},{label='Advertised size',value=m.listing.numMembers}})
 section(rows,'Match explanation');for _,r in ipairs(m.match.reasons or {}) do add(rows,'row',r) end;for _,r in ipairs(m.match.blockers or {}) do add(rows,'row',r,'Ineligible') end
 section(rows,'Legitimately exposed members')
 for _,r in ipairs(m.members) do add(rows,'row',r.name or 'Identity not exposed',r.role or 'Role not exposed',r.resolved and go('player',r.guid),{person=r.resolved and {key=r.guid,identity=r,owner=ns.Chronicle.Owner()} or nil}) end
 return rows,{}
end
function P.Browse(route)
 local kind=route.page=='intel' and 'player' or 'activity';local found,st=M.Browse(kind,route.owner,route.query)
 local rows={};add(rows,'hero',kind=='player' and 'People you have encountered' or 'Your adventures','Select a complete dossier')
 add(rows,'caption','One subject · one page',kind=='player' and 'Identity, encounters, activities and notes together' or 'Encounters, people, quests, loot and timeline together')
 if not found then add(rows,'caption','History is being prepared',type(st)=='string' and st or '');return rows,{},true end
 for _,r in ipairs(found) do add(rows,'row',kind=='player' and r.title or M.Title(r),kind=='player' and 'Open player dossier' or M.Status(r)..' · '..C.Stamp(r.startAt),go(kind,kind=='player' and r.key or r.id,st.owner)) end
 if #found==0 then add(rows,'caption','No matching retained observations','Try a different local search or generate a private Lab test world') end
 return rows,{}
end
function P.Home(route)
 local rows={};add(rows,'hero','Your world, connected','Fireside · UI2 development checkpoint')
 add(rows,'caption','A new presentation layer over your existing history','No recording or networking settings change when a page opens')
 section(rows,'Continue your story');add(rows,'row','Athena’s Journal','Open your saved book',function() ns.UI2.Open({page='journey'}) end)
 local activities,st=M.Browse('activity',route.owner)
 section(rows,'Recent adventures')
 if activities then for n=1,math.min(6,#activities) do local a=activities[n];add(rows,'row',M.Title(a),M.Status(a)..' · '..C.Stamp(a.startAt),go('activity',a.id,st.owner)) end
 else add(rows,'caption','History is being prepared',type(st)=='string' and st or '') end
 section(rows,'Protection & participation')
 add(rows,'row','Chat filtering',ns.DB.chat==false and 'Paused' or 'Enabled')
 add(rows,'row','Shield',ns.DB.shield and ns.DB.shield.enabled==false and 'Paused' or 'Enabled')
 add(rows,'row','Local recording',ns.Chronicle.Status())
 add(rows,'row','Aether transport','Native validation pending · no background connection')
 section(rows,'Build status');add(rows,'caption','UI2 is under construction','Module and action parity are not yet complete')
 return rows,{},not activities
end
