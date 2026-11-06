-- One connected-event page over existing references, not another activity store.
local _,ns=...
local H={};ns.ChronicleEventHub=H
local function Stamp(at) return ns.SafeCall(date,'%H:%M:%S',at) or tostring(at or '?') end
function H.Loot(st,a)
 local rows={};if not st or not a then return rows end
 local own=st.owner:match('/(Player%-.+)$')
 for _,ref in ipairs(a.evidence or {}) do
  local e=st.events[ref];local d=e and e.details or {};local family=d.recordType or e and e.kind
  if family=='item_received' or family=='quest_item_received' or family=='encounter_loot_delivery' then
   rows[#rows+1]={event=e,itemID=d.itemID,itemString=d.itemString,quantity=d.quantity,encounterID=d.encounterID,
    recipient=(family=='item_received' or family=='quest_item_received') and e.subject==own and ns.ChronicleActivities.Name(st,own,e.at) or 'Unknown',
    scope=family=='encounter_loot_delivery' and 'Encounter delivery report; recipient unknown' or 'Your recorded item receipt'}
  end
 end
 table.sort(rows,function(x,y) return x.event.at<y.event.at or x.event.at==y.event.at and x.event.id<y.event.id end)
 return rows
end
function H.Targets(st,a)
 local out={};if not st or not a then return out end
 for _,id in ipairs(a.evidence or {}) do local e=st.events[id];local family=e and (e.details.recordType or e.kind)
  local kind=({instance_enter='adventure',instance_exit='adventure',encounter_ended='adventure',group_roster='group',quest_turnin='quest',adventure_combat_summary='combat',guild_affiliation='guild'})[family]
  if kind then out[#out+1]={ref=ns.Athena.EvidenceRef(e.id),at=e.at,kind=kind,sourceRecordRef=e.id,label=(a.context.instanceName or a.context.zone or 'Adventure')..' • '..Stamp(e.at)} end
 end
 return out
end
function H.Blocks(st,a,tab)
 if not a then return {{kind='title',text='Your adventures'},{text='Choose a run, battle or gathering. Its encounters, people, rewards, scoreboard and recollections are gathered here.'}} end
 local U=ns.ChronicleActivitiesUI;local b={{kind='title',text=U.Title(a,st)}}
 local function Put(kind,text,activate) b[#b+1]={kind=kind,text=text,activate=activate} end
 local refs={};for _,id in ipairs(a.evidence) do local e=st.events[id];if e then refs[#refs+1]=e end end
 table.sort(refs,function(x,y) return x.at<y.at or x.at==y.at and x.id<y.id end)
 if tab=='people' then
  local people={};for guid in pairs(a.members) do people[#people+1]=guid end;table.sort(people)
  for _,guid in ipairs(people) do
   local card=ns.WardenCharacterCards.FromState(st,guid,a.lastAt);local v=card and card.values
   Put('heading',ns.ChronicleActivities.Name(st,guid,a.lastAt),function() ns.WardenUI.Navigate('player',st.owner,guid) end)
   if v then Put('body',(v.level and 'Level '..v.level..' • ' or '')..(v.race or '')..' '..(v.class or '')..(v.guild and '\n<'..v.guild..'>' or '')) end
  end
  Put('meta',#people..' identifiable people in linked rosters. Roster membership does not prove individual participation in every encounter.')
 elseif tab=='timeline' or tab=='sources' then
  Put('meta',#refs..' connected original records. Showing the latest 120; the original archive retains all records.')
  for n=math.max(1,#refs-119),#refs do local e=refs[n]
   Put('body',Stamp(e.at)..' • '..ns.RecordingUI.Title(e),function() ns.RecordingUI.OpenSource(nil,e) end)
  end
 elseif tab=='loot' then
  local rows=H.Loot(st,a)
  Put('meta','Captured item receipts and encounter delivery reports. These are observations, not a complete loot ledger; overlapping sources are not summed.')
  for _,row in ipairs(rows) do
   local e=row.event;local name=ns.SafeString(ns.SafeCall(GetItemInfo or C_Item and C_Item.GetItemInfo,row.itemString or row.itemID),144)
   Put('heading',name or ('Item #'..tostring(row.itemID or 'unknown')),function() ns.RecordingUI.OpenSource(nil,e) end)
   Put('body','Quantity: '..tostring(row.quantity or 'Unknown')..' · Recipient: '..row.recipient..'\nObserved '..Stamp(e.at)..(row.encounterID and ' · Encounter #'..row.encounterID or ''))
   Put('meta',row.scope..' · Open for the original source and saved item identity.')
  end
  if #rows==0 then Put('body','No linked loot receipts were captured for this run. This does not mean no loot dropped.') end
 elseif tab=='rewards' then
  for _,e in ipairs(refs) do local d=e.details;local k=d.recordType or e.kind
   if e.kind:find('quest',1,true) or k:find('loot',1,true) or k=='item_received' or e.kind=='equipment_change' then
    Put('heading',ns.RecordingUI.Title(e));local text=d.objective or d.itemString or d.itemID and 'Item #'..d.itemID or d.title
    Put('body',Stamp(e.at)..(text and '\n'..text or '')..(d.quantity and '\nQuantity: '..d.quantity or ''),function() ns.RecordingUI.OpenSource(nil,e) end)
   end
  end
  if #b==1 then Put('body','No linked quest, loot or equipment records were captured for this event.') end
 elseif tab=='memories' then
  local provider=ns.AthenaJournal.Live();local count=0
  for _,target in ipairs(H.Targets(st,a)) do local note=ns.AthenaRecollections.Get(provider,st.owner,target)
   if note then count=count+1;Put('heading',Stamp(target.at)..' • Your recollection')
    if note.text~='' then b[#b+1]={kind='quote',literal=true,text=note.text} end
    if note.feeling~='unsaid' then Put('body','You remembered this as '..ns.AthenaRecollections.feelings[note.feeling]:lower()..'.') end
    if note.company~='unsaid' then Put('body','Company: '..ns.AthenaRecollections.company[note.company]) end
   end
  end
  if count==0 then Put('body','What made this adventure memorable? Add your perspective with “Recollect” above. Your words stay private and remain separate from recorded facts.') end
 else
  Put('accent',U.Status(a));Put('meta','First observed '..Stamp(a.startAt)..' • Last evidence '..Stamp(a.lastAt)..' • '..tostring(a.recordingSegments or 1)..' recorded visit(s)')
  local deaths,quests,loot=0,0,0
  for _,e in ipairs(refs) do local k=e.details.recordType or e.kind
   if e.kind=='player_death' then deaths=deaths+1 end
   if e.kind=='quest_turnin' then quests=quests+1 end
   if k=='item_received' or k=='encounter_loot_delivery' then loot=loot+1 end
  end
  Put('body',#a.attempts..' encounter records • '..deaths..' recorded deaths • '..quests..' quest hand-ins • '..loot..' loot notices')
  for _,t in ipairs(a.attempts) do Put('heading',(t.name or 'Encounter '..t.encounterID)..' • '..t.outcome)
   Put('body',Stamp(t.startAt)..' → '..Stamp(t.endAt)..(t.interruption and '\n'..t.interruption or '')) end
  for _,id in ipairs(a.pvpReports or {}) do local e=st.events[id]
   if e then Put('body','Native match completion • winner code '..tostring(e.details.winner or 'unknown')..' • reported duration '..tostring(e.details.duration or '?')..' seconds') end
  end
  local boards=ns.ChronicleScoreboards.List(st,a)
  Put('heading','Scoreboard');Put('body',#boards>0 and #boards..' complete-board or partial observations. Open Scoreboard above to read the full table.' or 'No readable scoreboard was captured for this event.')
  Put('meta','Returns and supported reloads share this run. “Separate visits” corrects grouping. Unmatched meter sessions remain unassigned; nearby time does not prove an encounter match.')
 end
 return b
end
function H.Attach(p,detailPanel)
 local V=ns.Art
 p.hubTab='overview'
 p.peopleCards=V.ScrollingList(detailPanel,16,-94,642,266,100,function(parentRow)
  local row=ns.WardenCharacterCards.Build(parentRow,610);row:EnableMouse(true)
  row:SetScript('OnMouseUp',function(self,button) if button=='LeftButton' and self.card then ns.WardenUI.Navigate('player',p.owner,self.card.guid) end end)
  return row
 end,function(row,card) row:SetCard(card) end)
 p.peopleCards.scroll:Hide()
 p.lootRows=V.ScrollingList(detailPanel,16,-94,642,266,82,function(host)
  local row=V.Button(host,'',0,0,642,76,function(self)
   if self.loot then
    local handled=self.itemLink and ns.SafeCall(HandleModifiedItemClick,self.itemLink)
    if not handled then ns.RecordingUI.OpenSource(nil,self.loot.event) end
   end
  end,'row')
  row.icon=row:CreateTexture(nil,'ARTWORK');row.icon:SetPoint('TOPLEFT',12,-14);row.icon:SetSize(42,42)
  row.title=V.Text(row,'',66,-9,554,15,V.gold);row.title:SetHeight(22);row.title:SetWordWrap(false)
  row.info=V.Text(row,'',66,-35,554,12,V.muted);row.info:SetHeight(34)
  row:SetScript('OnEnter',function(self)
   if not GameTooltip or not self.loot then return end
   GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
   if self.itemLink then ns.SafeCall(GameTooltip.SetHyperlink,GameTooltip,self.itemLink) else GameTooltip:SetText('Item details unavailable') end
   GameTooltip:AddLine(self.loot.scope,.8,.85,.9,true);GameTooltip:AddLine('Click: original record. Native modified item clicks retain their normal behavior.',.8,.85,.9,true);GameTooltip:Show()
  end)
  row:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
  return row
 end,function(row,loot)
  row.loot=loot;row.itemLink=loot.itemString or loot.itemID and ('item:'..loot.itemID)
  local name,link,_,_,_,_,_,_,_,icon=ns.WardenBrand.Values(GetItemInfo or C_Item and C_Item.GetItemInfo,row.itemLink or loot.itemID)
  row.title:SetText(ns.WardenBrand.Text(name or ('Item #'..tostring(loot.itemID or 'unknown'))))
  row.icon:SetTexture(icon or 'Interface\\Icons\\INV_Misc_QuestionMark')
  row.info:SetText('Quantity '..tostring(loot.quantity or 'Unknown')..' · '..loot.recipient..' · '..Stamp(loot.event.at)..'\n'..loot.scope)
 end)
 p.lootRows.scroll:Hide()
 p.lootEmpty=V.Text(detailPanel,'No linked loot receipts were captured for this run. This does not mean no loot dropped.',18,-110,620,15)
 p.lootEmpty:SetHeight(72);p.lootEmpty:Hide()
 p.hubMenu=V.Dropdown(p,460,-150,430,{{'overview','Run overview'},{'people','People'},{'timeline','Timeline'},{'loot','Loot drops'},{'rewards','Quests & rewards'},{'memories','Recollections'},{'sources','Source records'}},function() return p.hubTab end,function(v) p.hubTab=v;p:ShowActivity(ns.ChronicleActivities.View(p.state,p.selected)) end)
 p.board=ns.ChronicleScoreboardUI.Build(p)
 p.boardButton=V.Button(p,'Scoreboard',902,-150,218,30,function() local a=ns.ChronicleActivities.View(p.state,p.selected);p.board:Present(p.state,ns.ChronicleScoreboards.List(p.state,a)) end,'neutral')
 p.recollect=V.Button(p,'Recollect',902,-190,218,28,function()
  local a=ns.ChronicleActivities.View(p.state,p.selected);local targets=H.Targets(p.state,a);if #targets==0 then return end
  local ctx=p.recollectionContext
  if not ctx then
   ctx=CreateFrame('Frame',nil,p);ctx:SetAllPoints(p);ctx:SetFrameLevel(p:GetFrameLevel()+60);ctx:Hide();p.recollectionContext=ctx
   function ctx:Recompose() self:Hide();p.hubTab='memories';p:ShowActivity(ns.ChronicleActivities.View(p.state,p.selected)) end
   ns.AthenaRecollectionsUI.Attach(ctx)
  end
  ctx.owner=p.owner;ctx.provider=ns.AthenaJournal.Live();ctx.activityTargets=targets;ctx:Show();ctx:OpenRecollections(false)
 end,'neutral')
 p:HookScript('OnHide',function() p.board:Hide();if p.recollectionContext then p.recollectionContext:Hide() end end)
end
function H.ShowPeople(p,a)
 local loot=a and p.hubTab=='loot'
 p.lootRows.scroll:SetShown(loot==true)
 p.lootEmpty:Hide()
 if loot then
  local rows=H.Loot(p.state,a);p.peopleCards.scroll:Hide();p.detailScroll:Hide();p.lootRows:SetItems(rows);p.lootEmpty:SetShown(#rows==0);return
 end
 local people=a and p.hubTab=='people' and a.kind~='duel'
 p.peopleCards.scroll:SetShown(people==true);p.detailScroll:SetShown(not people)
 if not people then return end
 local rows={};for guid in pairs(a.members) do
  local card=ns.WardenCharacterCards.FromState(p.state,guid,a.lastAt)
  if not card then card={owner=p.owner,guid=guid,at=a.lastAt,values={name=ns.ChronicleActivities.Name(p.state,guid,a.lastAt)}} end
  rows[#rows+1]=card
 end
 table.sort(rows,function(a,b) return a.values.name<b.values.name end);p.peopleCards:SetItems(rows)
end
