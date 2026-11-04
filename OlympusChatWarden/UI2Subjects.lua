-- Additional subject actions stay on the same canonical person/run page.
local _,ns=...
local U,L,F,C,G=ns.UI2,ns.UI2Layouts,ns.UI2Forms,ns.UI2Components,ns.WardenDossier
local function act(id,title,detail,fn,height) return {id=id,title=title,detail=detail,activate=fn,height=height or 40} end
local function cap(text) return {title=text,kind='caption',wrap=true,height=54} end
local function move(route,key,value)
 local out={};for k,v in pairs(route) do out[k]=v end;out[key]=value;return U.Open(out,true)
end
local function append(b,title,rows,anchor)
 local bottom=0;for _,block in ipairs(b) do local height=block.header==false and 12 or 44;for _,row in ipairs(block.rows or {}) do height=height+(row.height or 31) end;bottom=math.max(bottom,(block.y or 0)+height+12) end
 b[#b+1]={id=anchor,title=title,x=0,y=bottom,w=1,rows=rows,anchor=anchor};return b[#b]
end
local function itemRow(snapshot,slot)
 local r=G.Slot(snapshot,slot[1]);local id=r[3]~=false and r[3];local payload=r[4]~=false and r[4]
 local name,_,_,_,_,_,_,_,_,icon=ns.WardenBrand.Values(GetItemInfo or C_Item and C_Item.GetItemInfo,payload or id)
 name=ns.SafeString(name,200);local link=payload and (payload:find('|H',1,true) and payload or '|H'..payload..'|h['..(name or 'Item #'..tostring(id))..']|h')
 return {title=slot[2],detail=name or id and 'Item #'..id or r[2]=='empty' and 'Confirmed empty' or 'Not observed',icon=ns.Readable(icon) and icon or nil,itemLink=link,height=38,activate=link and function() ns.SafeCall(HandleModifiedItemClick,link) end}
end
function U.LiveAppearance(m)
 if m.owner~=ns.Chronicle.Owner() or not ns.Modules.Enabled('intel') or not ns.Membership.Allowed() then return F.Feedback(false,'Live appearance is available only in your enabled local Intel view.') end
 if InCombatLockdown and InCombatLockdown() then return F.Feedback(false,'Live appearance is available after combat.') end
 local unit=G.Resolve(m.key);if not unit then return F.Feedback(false,'This exact player is not currently visible. Their recorded history remains available; an offline face is not invented.') end
 local form=F.Form({title='Live appearance · '..m.title,help='Shows the currently visible, GUID-matched person. It is not a reconstruction of historical gear. This view never requests an inspection or changes equipment.',cancelLabel='Close'})
 form:SetHeight(620);local ok,model=pcall(CreateFrame,'PlayerModel',nil,form)
 if not ok or not model or type(model.SetUnit)~='function' then form.status:SetText('The client model API is unavailable. Native rendering remains unverified.');return form end
 model:SetPoint('TOPLEFT',20,-112);model:SetPoint('BOTTOMRIGHT',-20,102);model:EnableMouse(true);model:EnableMouseWheel(true)
 local zoom,angle,dragX=1,0,nil
 local function visible() return not (InCombatLockdown and InCombatLockdown()) and G.Resolve(m.key)==unit and ns.Modules.Enabled('intel') and ns.Membership.Allowed() end
 local function call(name,...) return ns.SafeCall(model[name],model,...) end
 local function reset() if not visible() then return end;zoom=1;angle=0;call('SetPortraitZoom',0);call('SetCamDistanceScale',zoom);call('SetPosition',0,0,0);call('SetRotation',angle) end
 local function change(delta) if not visible() then return end;zoom=math.max(.35,math.min(2.8,zoom-delta*.15));call('SetCamDistanceScale',zoom) end
 call('SetKeepModelOnHide',true);model:Show();local bound=pcall(model.SetUnit,model,unit)
 if not bound or not visible() then model:Hide();call('ClearModel');form.status:SetText('The native model could not be bound to this exact player.');return form end
 reset();form.status:SetText('Drag to rotate; mouse wheel or buttons to zoom. Native visual fidelity requires an in-game check.')
 model:SetScript('OnMouseWheel',function(_,delta) change(delta) end)
 model:SetScript('OnMouseDown',function(_,button) if button=='LeftButton' then dragX=ns.SafeNumber(ns.SafeCall(GetCursorPosition)) end end)
 model:SetScript('OnMouseUp',function() dragX=nil end)
 local elapsed=0;model:SetScript('OnUpdate',function(_,dt)
  elapsed=elapsed+(dt or 0);if elapsed<.1 then return end;elapsed=0
  if not visible() then model:Hide();call('ClearModel');form.status:SetText('The player is no longer available, or live viewing is paused.');return end
  if dragX then local current=ns.SafeNumber(ns.SafeCall(GetCursorPosition));if current then angle=angle+(current-dragX)*.01;dragX=current;call('SetRotation',angle) end end
 end)
 C.Button(form,'Zoom out',function() change(-1) end,130):SetPoint('BOTTOMLEFT',20,18)
 C.Button(form,'Reset model',reset,130):SetPoint('BOTTOMLEFT',160,18)
 C.Button(form,'Zoom in',function() change(1) end,130):SetPoint('BOTTOMLEFT',300,18)
 form:HookScript('OnHide',function() dragX=nil;call('ClearModel');model:Hide() end)
 return form
end
function U.PlayerDateRows(m,route,rows)
 local dates={{false,'Latest known'}}
 for n,at in ipairs(m.observedDates or {}) do if n<=180 then dates[#dates+1]={at,ns.SafeCall(date,'!%Y-%m-%d UTC',at) or tostring(at)} end end
  rows[#rows+1]=F.Row('INT.ASOF','Recorded date',function() return route.asOf or false end,function(value)
   local out={};for k,v in pairs(route) do out[k]=v end;out.asOf=value or nil;out.asOfSet=true;out.gearSet=nil;out.talentSet=nil;out.gearObservation=nil;out.talentObservation=nil;out.combatRecord=nil;U.Open(out,true);return true
  end,{choices=dates})
  if m.asOf then rows[#rows+1]=cap('Factual history as of '..tostring(ns.SafeCall(date,'!%Y-%m-%d %H:%M UTC',m.asOf) or m.asOf)..'. Community opinions, Wall, private notes and grouping preferences below are PRESENT-DAY context.') end

end
function L.PlayerSections(m,route,b)
 if route.projection=='public' then return b end
 local presence=m.presence or {label='Activity unknown',group={},scope='Current group unknown'}
 local top=b[1] and b[1].rows
 if top then
  local footer;for _,row in ipairs(top) do if row.profileFooter then footer=row end end
  if footer then for i,row in ipairs(top) do if row==footer then table.remove(top,i);break end end end
  local status=presence.wardenStatus or 'Unknown'
  top[#top+1]={title=(status=='Unknown' and 'Fireside status: Unknown' or status)..' · '..presence.label,detail=presence.online=='LAST_SEEN' and (ns.SafeCall(date,'%Y-%m-%d %H:%M',presence.lastSeen) or 'Previously confirmed') or (#(presence.group or {})>0 and 'Known group companions' or 'Current group unknown'),stacked=true,wrap=true,height=44}
  for i,p in ipairs(presence.group or {}) do if i<=4 then local person=p;top[#top+1]={title=person.title,detail='Current · authorized group observation',person={key=person.key,owner=m.owner,values=person.identity or {}},activate=function() U.OpenPlayer(person.key,m.owner) end,height=32} end end
  if #(presence.group or {})>4 then top[#top+1]=cap('Current group · '..#presence.group..' known players') end
  if footer then if m.owner==ns.Chronicle.Owner() then footer.actions[#footer.actions+1]={title='Live appearance',activate=function() U.LiveAppearance(m) end} end;top[#top+1]=footer end
 end
 local function stamp(at) return ns.SafeCall(date,'!%Y-%m-%d %H:%M:%S UTC',at) or C.Stamp(at) end
 local function history(family) U.Open({page='chronicle',subsection='collections',collectionFamily=family,guid=m.key,owner=m.owner}) end
 local function equipment(rows,values,caption,live)
  rows[#rows+1]={height=530,equipment={slots=values and values.slots or {},caption=caption,title='Equipment',owner=m.owner,live=live==true,person={owner=m.owner,key=m.key,title=m.title,values=m.identity,state=m.sourceState}}}
 end
 local function capture(rows,kind,sets)
  local field=kind=='gear' and 'gearSet' or 'talentSet';local atField=kind=='gear' and 'gearObservation' or 'talentObservation'
  local preferred=1
  if kind=='traits'and not route[field]and sets[1]then for n,item in ipairs(sets)do if item.at==sets[1].at and item.object and item.object.capture.values.layoutRefs then preferred=n;break end end end
  local index=math.max(1,math.min(#sets,tonumber(route[field]) or preferred));local build=sets[index]
  if not build then return end
  local choices={};for n,item in ipairs(sets) do choices[#choices+1]={n,stamp(item.at)} end
  rows[#rows+1]=F.Row(kind=='gear' and 'INT.GEAR.SELECT' or 'INT.TALENT.SELECT','Captured '..(kind=='gear' and 'equipment' or 'talent build'),function() return index end,function(value)
   local nextRoute={};for k,v in pairs(route) do nextRoute[k]=v end;nextRoute[field]=value;nextRoute[atField]=nil;U.Open(nextRoute,true);return true
  end,{choices=choices})
  local observations=build.observations or {};local selected=build
  if #observations>0 then
   local entries={};for n,item in ipairs(observations) do entries[#entries+1]={n,stamp(item.at)} end
   local at=math.max(1,math.min(#observations,tonumber(route[atField]) or #observations));selected=observations[at]
   rows[#rows+1]=F.Row(kind=='gear' and 'INT.GEAR.OBSERVATION' or 'INT.TALENT.OBSERVATION','Exact observation time',function() return at end,function(value) move(route,atField,value);return true end,{choices=entries})
  end
  local event=selected.event or selected.object
  rows[#rows+1]=cap('Historical local capture · '..stamp(selected.at)..' · '..(event and event.source or 'Source unavailable')..'. Observer: '..ns.WardenUI.OwnerName(m.owner)..'.')
  if ns.UI2Operations.ShareHistorical and m.owner==ns.Chronicle.Owner() then
   rows[#rows+1]=act(kind=='gear' and 'INT.GEAR.SHARE' or 'INT.TALENT.SHARE','Share this capture','Selected recipient · review before sending',function() ns.UI2Operations.ShareHistorical(m,selected,kind) end)
  end
  return selected
 end
 local function shared(rows,kind)
  if ns.AetherNet.PublicationAvailable() and ns.AetherNet.ProjectCurrent(m,kind) then
   rows[#rows+1]=act('INT.NET.PUBLISH.'..kind,'Review latest '..(kind=='GEAR' and 'equipment' or 'talents')..' for sharing','Latest observation only · explicit confirmation',function() ns.AetherNet.ReviewCurrent(m,kind) end)
  end
  local current=m.aetherNet and m.aetherNet.current and m.aetherNet.current[kind]
  if not current then rows[#rows+1]=cap('Aether '..(kind=='GEAR' and 'equipment' or 'talents')..': Not shared. Your historical captures remain private.');return end
  rows[#rows+1]=cap('Community '..(kind=='GEAR' and 'equipment' or 'talents')..' · observed '..stamp(current.observedAt)..'. Historical captures are listed separately.')
  local v=current.value;if not v then return end
  if kind=='GEAR' then
   equipment(rows,v,'Aether equipment · observed '..stamp(current.observedAt),not m.asOf)
  else
   rows[#rows+1]={title='Shared talent observation',detail=v.completeness..' · '..#v.choices..' readable choices',height=38}
   rows[#rows+1]={height=600,talentTree={values=v,objects={},at=stamp(current.observedAt),key='shared/'..m.key..'/'..tostring(current.observedAt)}}
   if v.exportString then rows[#rows+1]=act('INT.NET.EXPORT','Copy latest shared export','Source-qualified current projection',function() F.Copy('Latest shared talent export',v.exportString) end) end
  end
 end
 local function received(rows,family)
  local copies={};for _,row in ipairs(m.receivedCaptures or {}) do if row.snapshot.family==family then copies[#copies+1]=row end end
  if #copies==0 then return end
  local key=family=='gear' and 'receivedGear' or 'receivedTalents';local index=math.max(1,math.min(#copies,tonumber(route[key]) or 1))
  local choices={};for n,row in ipairs(copies) do choices[#choices+1]={n,stamp(row.snapshot.observedAt)..' · '..row.sender} end
  rows[#rows+1]=F.Row('INT.RECEIVED.'..family,'Received captures · private',function() return index end,function(value) move(route,key,value);return true end,{choices=choices})
  local row=copies[index];local s=row.snapshot;local values=ns.ChronicleBackup.DecodeChunk(s.captureWire)[1];local objects={}
  for _,dep in ipairs(s.dependencies) do objects[dep.contentID]={capture=ns.ChronicleBackup.DecodeChunk(dep.captureWire)[1]} end
  rows[#rows+1]=cap('Received from '..row.sender..' · original observer '..s.observerOwner..' · observed '..stamp(s.observedAt)..'. Imported only after recipient acceptance. Not firsthand or public current data.')
  rows[#rows+1]=act('INT.RECEIVED.DELETE.'..family,'Delete this received copy','Original sender history is preserved',function()
   F.Confirm('Delete this private received copy?','Removes only this recipient’s copy. Your own captures and the sender’s original are preserved.',function()
    local ok,why=ns.RelayStore.DeleteReceived(ns.PlayerCard.Own(),row.id,true);if ok then M.Clear();U.Refresh(true) end;return ok,why
   end)
  end)
  if family=='gear' then equipment(rows,values.values,'Private shared capture · observed '..stamp(s.observedAt),false)
  else
   if ns.WardenTalents.Projection(values.values,objects) and ns.WardenTalents.Layout(ns.WardenTalents.Projection(values.values,objects)) then
    rows[#rows+1]={height=600,talentTree={values=values.values,objects=objects,at=stamp(s.observedAt),key='received/'..row.id}}
   else rows[#rows+1]=cap('Shared partial / export-only build. Tree layout was not captured.');rows[#rows+1]={height=600,talentTree={values=values.values,objects=objects,at=stamp(s.observedAt),key='received/'..row.id}} end
   if values.values.exportString then rows[#rows+1]=act('INT.RECEIVED.EXPORT','Copy received original export','Sender-supplied original string',function() F.Copy('Received historical export',values.values.exportString) end) end
  end
 end
 local talents={};shared(talents,'TALENTS')
 local build=capture(talents,'traits',m.talentSets or {})
 if not build then
  talents[#talents+1]=cap('No historical talents recorded. This does not mean the character has no talents. Recording consent may be disabled or the client may not expose readable data.')
  talents[#talents+1]={height=600,talentTree={values={choices={}},objects={},at='Not recorded',key='unknown/'..m.owner..'/'..m.key}}
 else
  local values=build.object.capture.values;local trees=ns.WardenTalents.Projection(values,m.loadoutIndex and m.loadoutIndex.objects or {})
  talents[#talents+1]={title='Specialization',detail=G.Specialization(values.specializationID) or 'Not observed',height=38}
  if trees and ns.WardenTalents.Layout(trees) then
   talents[#talents+1]={height=600,talentTree={values=values,objects=m.loadoutIndex.objects,at=stamp(build.at),key=m.owner..'/'..m.key..'/'..build.hash}}
  else
   talents[#talents+1]=cap(values.exportString and 'Export only / partial. A complete historical tree was not captured.' or 'Partial talent observation. Missing layout and ranks remain unknown.')
   talents[#talents+1]={height=600,talentTree={values=values,objects=m.loadoutIndex.objects,at=stamp(build.at),key=m.owner..'/'..m.key..'/'..build.hash}}
  end
  if values.exportString then talents[#talents+1]=act('INT.TALENT.EXPORT','Copy recorded native export','Original saved export · unchanged',function() F.Copy('Recorded talent export',values.exportString) end) end
 end
 talents[#talents+1]=act('INT.TALENT.HISTORY','All talent observations','Filtered Chronicle · same player',function() history('traits') end)
 received(talents,'traits')
 append(b,'Talents',talents,'talents')
 local equipment={};shared(equipment,'GEAR')
 local snapshot=capture(equipment,'gear',m.gearSets or {})
 if not snapshot then
  equipment[#equipment+1]={height=530,equipment={slots={},caption='No equipment observation · ? means not observed',title='Equipment',owner=m.owner,live=not m.asOf,person={owner=m.owner,key=m.key,title=m.title,values=m.identity,state=m.sourceState}}}
 else
  equipment[#equipment+1]={height=530,equipment={slots=snapshot.object.capture.values.slots,caption='Recorded '..stamp(snapshot.at),title='Equipment',owner=m.owner,live=not m.asOf,person={owner=m.owner,key=m.key,title=m.title,values=m.identity,state=m.sourceState}}}
 end
 equipment[#equipment+1]=act('INT.GEAR.HISTORY','All equipment observations','Filtered Chronicle · same player',function() history('gear') end)
 received(equipment,'gear')
 append(b,'Equipment',equipment,'equipment')
 append(b,'Captured history',{
  act('INT.HISTORY.OPEN','Open captured history','Same player and observer in Chronicle',function() history(nil) end),
  act('INT.HISTORY.CONSENT','Recording and capture preferences','Review existing consent · never enabled automatically',function() U.Open({page='settings',category='recording'}) end),
  cap('Dated local captures survive network disable. A currently visible model is labeled Live appearance and must match this exact GUID; it cannot reconstruct past appearance.')},'history')

 local combat={act('INT.COMBAT.TOGGLE',route.combatOpen and 'Collapse combat history' or 'Explore combat history','This same player dossier · recorded source observations',function() move(route,'combatOpen',not route.combatOpen) end)}
 if route.combatOpen then
  for _,r in ipairs(ns.UI2Combat.Rows('intel',m.owner,m.key,{label='Observed combat for this player'})) do combat[#combat+1]=r end
  combat[#combat+1]=act('INT.COMBAT.DETAILS',route.combatDetails and 'Hide Evidence Details' or 'Evidence Details','Original recorded sources',function()move(route,'combatDetails',not route.combatDetails)end)
 end
 if route.combatOpen and route.combatDetails then
  local choices={{'all','All evidence'},{'pvp','PvP credits and duels'},{'pve','Creature credits'},{'abilities','Selected casts'},{'casts','Cast notifications'},{'effects','Effects on this player'},{'pets','Pets and companions'},{'groups','Roles and leadership'},{'targeting','Contextual targeting'},{'identity','Identity observations'},{'gear','Gear and talents'},{'public','Public milestones'},{'guild','Guild associations'},{'states','States and other evidence'}}
  combat[#combat+1]=F.Row('INT.COMBAT.FILTER','Evidence category',function() return route.combatFilter or 'all' end,function(value)
   local r={};for k,v in pairs(route) do r[k]=v end;r.combatFilter=value;r.combatPage=0;r.combatRecord=nil;U.Open(r,true);return true
  end,{choices=choices})
  combat[#combat+1]=cap('Effects on a player do not prove who cast them. Targeting does not prove intent; observations, credits and unknown causes remain distinct. Coverage is intermittent.')
  local page=math.max(0,tonumber(route.combatPage) or 0);local data,state=ns.UI2Models.CombatEvidence(m,route.combatFilter,page)
  if not data then combat[#combat+1]=cap(state)
  elseif data.error then combat[#combat+1]=cap('Could not prepare this evidence. Source history is kept.')
  else
   if page>0 then combat[#combat+1]=act('INT.COMBAT.NEWER','Newer evidence','Page '..page,function() move(route,'combatPage',page-1) end) end
   for _,e in ipairs(data.rows) do local event=e
    combat[#combat+1]=act('INT.COMBAT.SELECT',ns.IntelCombatUI.Title(e,m.key),stamp(e.at)..' · '..(e.source or 'Source unavailable'),function() move(route,'combatRecord',event.id) end,52)
    if route.combatRecord==e.id then
     combat[#combat+1]=cap('Observed by '..ns.WardenUI.OwnerName(m.owner)..' · '..(e.evidence or 'observation')..'. '..(e.details.evidenceState or 'Recorded source; missing attribution stays unknown.'))
     for _,spec in ipairs({{'attackerGUID','Actor'},{'targetGUID','Target'},{'ownerGUID','Associated owner'},{'petGUID','Pet'},{'spellID','Spell ID'},{'creatureName','Creature'},{'role','Observed role'},{'classification','Classification'},{'method','Observation method'},{'result','Recorded result'},{'count','Count'}}) do local value=e.details[spec[1]]
      if value~=nil then
       if ns.ChronicleStore.GUID(value) then local guid=value;combat[#combat+1]=act('INT.COMBAT.PERSON',spec[2],ns.ChronicleActivities.Name(m._sourceState,guid,e.at),function() U.OpenPlayer(guid,m.owner) end)
       elseif type(value)=='string' or type(value)=='number' then combat[#combat+1]={title=spec[2],detail=tostring(value),height=34} end
      end
     end
    end
   end
   if #data.rows==0 then combat[#combat+1]=cap('No matching retained evidence. Missing observations do not establish zero activity.') end
   if data.more then combat[#combat+1]=act('INT.COMBAT.OLDER','Older evidence','Page '..(page+2),function() move(route,'combatPage',page+1) end) end
  end
 end
 append(b,'Combat history',combat,'combat')
 if m.owner==ns.Chronicle.Owner() then local context=ns.Athena.GetPlayerContext('intel',m.key,'protection')
  if context and context.advisory then local rows={cap(context.advisory..' Local advisory only; this does not establish malicious behavior.'),act('INT.ADVISORY.DISMISS','Dismiss local advisory','Original decisions stay intact',function() local ok=ns.Athena.DismissAdvisory('intel',m.key);ns.UI2Models.Clear();U.Refresh(true);return F.Feedback(ok,ok and 'Local advisory dismissed.' or 'Advisory changed; nothing dismissed.') end)}
   local refs={};for _,id in ipairs(context.sourceIDs) do refs[id]=true end;local available=0
   for _,entry in ipairs(ns.Review.entries) do if entry.guid==m.key and refs[entry.athenaDecisionID] then local selected=entry;available=available+1
    if available<=10 then rows[#rows+1]=act('INT.ADVISORY.SOURCE','Review retained source decision',stamp(entry.timestamp),function() U.Open({page='messages',subsection='review',messageID=selected.id,owner=m.owner}) end) end
   end end
   if available==0 then rows[#rows+1]=cap('No original review entry remains for these advisory references. The view does not guess a replacement from the player’s name.') end
   append(b,'Local protection advisory',rows,'advisory')
  end
 end
 return b
end
function ns.UI2Operations.Recollection(m,target)
 local st=ns.ChronicleActivities.Peek(m.owner);if not st then return F.Feedback(false,'Wait for the retained activity to finish opening.') end
 local targets=ns.ChronicleEventHub.Targets(st,m._activity);if #targets==0 then return F.Feedback(false,'No supported recollection target was recorded for this activity.') end
 target=target or targets[1];local provider=ns.AthenaJournal.Live();local note=ns.AthenaRecollections.Get(provider,m.owner,target)
 local choices={};local selected=1;for n,t in ipairs(targets) do choices[#choices+1]={n,C.Stamp(t.at)..' · '..t.kind};if t.ref==target.ref then selected=n end end
 local feelings,company={},{};for key,title in pairs(ns.AthenaRecollections.feelings) do feelings[#feelings+1]={key,title} end;for key,title in pairs(ns.AthenaRecollections.company) do company[#company+1]={key,title} end
 table.sort(feelings,function(a,b) return a[2]<b[2] end);table.sort(company,function(a,b) return a[2]<b[2] end)
 local draftKey='recollection/'..m.owner..'/'..target.kind..'/'..target.ref
 local f=F.Form({title='Your perspective · '..m.title,draftKey=draftKey,help='Your words stay private and separate from recorded facts. They never grant attendance, rewards or verified outcomes. Drafts are kept separately for each recorded moment.',changed=function(v,key)
  if key=='target' and v.target~=selected then local nextTarget=targets[v.target];v.target=selected;if nextTarget then ns.UI2Operations.Recollection(m,nextTarget) end end
  return true
 end,fields={{key='target',label='Recorded moment',value=selected,choices=choices},{key='text',label='What made it memorable?',value=note and note.text or '',multiline=true,height=120,limit=2000},{key='feeling',label='Feeling',value=note and note.feeling or 'unsaid',choices=feelings},{key='company',label='Company',value=note and note.company or 'unsaid',choices=company}},submit=function(v) return ns.AthenaRecollections.Save(provider,m.owner,target,{text=v.text,feeling=v.feeling,company=v.company}) end})
 C.Button(f,'Delete recollection',function() F.Confirm('Delete private recollection?','Recorded activity evidence remains unchanged.',function() local ok,why=ns.AthenaRecollections.Delete(provider,m.owner,target);if ok then F.drafts[draftKey]=nil end;return ok,why end) end,190):SetPoint('BOTTOMLEFT',230,18)
 return f
end
local activity=L.Activity
function L.Activity(m)
 local b=activity(m);local route=U.route or {};local st=ns.ChronicleActivities.Peek(m.owner)
 -- A source reference alone is not proof that Metis has written a chapter.
 -- Only offer the link when the finished manuscript actually contains this run.
 local chapter=ns.UI2Models.ActivityChapter(st,m._activity)
 for _,section in ipairs(b) do if section.anchor=='coverage' then
  local rows={};for _,row in ipairs(section.rows) do if row.title~='Read this adventure in Athena' then rows[#rows+1]=row end end
  if chapter then rows[#rows+1]=act('CHR.STORY.OPEN','Read this adventure in Athena','Open its existing chapter',function() ns.AthenaJournalWindow.Open({owner=m.owner,storyId=chapter}) end) end
  section.rows=rows
 end end
 if #m.boards>0 then
  local choices={};for n,board in ipairs(m.boards) do choices[#choices+1]={n,C.Stamp(board.lastAt)..' · '..(board.phase or 'Observation')} end
  local index=math.max(1,math.min(#m.boards,tonumber(route.boardIndex) or 1));local board=m.boards[index];local mode=route.boardMode or 'combat'
  local rows={F.Row('CHR.BOARD.SELECT','Scoreboard observation',function() return index end,function(v) move(route,'boardIndex',v);return true end,{choices=choices}),F.Row('CHR.BOARD.MODE','Columns',function() return mode end,function(v) move(route,'boardMode',v);return true end,{choices={{'combat','Combat totals'},{'objectives','Objectives'}}}),cap((board.complete and 'Whole captured board' or 'Partial observation')..' · '..C.Stamp(board.lastAt)..'. Totals belong to this match observation.')}
  local specs={{'killingBlows','Kills'},{'honorableKills','HK'},{'deaths','Deaths'},{'damageDone','Damage'},{'healingDone','Healing'}}
  if mode=='objectives' then specs={};local seen={};for _,person in ipairs(board.rows) do for _,objective in ipairs(person.values.objectives or {}) do if not seen[objective[1]] then seen[objective[1]]=true;specs[#specs+1]={objective[1],objective[4]~=false and objective[4] or objective[9]~=false and objective[9] or 'Objective '..objective[1]} end end end end
  local objectivePage=math.max(1,tonumber(route.objectivePage) or 1);if mode=='objectives' and #specs>5 then rows[#rows+1]=act('CHR.BOARD.OBJECTIVES','More objective columns','Next five',function() move(route,'objectivePage',objectivePage*5>=#specs and 1 or objectivePage+1) end) end
  local columns={};for n=mode=='objectives' and (objectivePage-1)*5+1 or 1,math.min(mode=='objectives' and objectivePage*5 or 5,#specs) do columns[#columns+1]=specs[n] end
  local widths={.34};for n=1,#columns do widths[n+1]=.66/math.max(1,#columns) end
  local headers={'Player'};for _,spec in ipairs(columns) do headers[#headers+1]=spec[2] end
  rows[#rows+1]={cells=headers,widths=widths,height=35}
  rows[#rows+1]=F.Row('CHR.BOARD.SORT','Sort captured board',function() return route.boardSort or false end,function(v) move(route,'boardSort',v);return true end,{choices={{false,'Captured order'},{'killingBlows','Killing blows'},{'honorableKills','Honorable kills'},{'deaths','Deaths'},{'damageDone','Damage'},{'healingDone','Healing'}}})
  local people={};for n,person in ipairs(board.rows) do people[#people+1]={row=person,position=n} end
  if route.boardSort then table.sort(people,function(a,b) local av,bv=a.row.values[route.boardSort],b.row.values[route.boardSort];if av==bv then return a.position<b.position end;return type(av)=='number' and (type(bv)~='number' or av>bv) end) end
  for _,entry in ipairs(people) do local person=entry.row;local cells={person.title}
   for _,spec in ipairs(columns) do local value=person.values[spec[1]];if mode=='objectives' then value=nil;for _,objective in ipairs(person.values.objectives or {}) do if objective[1]==spec[1] then value=objective[2] end end end;cells[#cells+1]=C.Number(value) end
   rows[#rows+1]={cells=cells,widths=widths,height=32,activate=person.key and function() U.OpenPlayer(person.key,m.owner) end}
  end
  for _,block in ipairs(b) do if block.anchor=='scoreboard' then
   local old=0;for _,row in ipairs(block.rows) do old=old+(row.height or 31) end;local new=0;for _,row in ipairs(rows) do new=new+(row.height or 31) end;local delta=new-old;block.rows=rows
   for _,later in ipairs(b) do if later~=block and (later.y or 0)>(block.y or 0) and ((later.x or 0)<.65 or later.w==1) then later.y=later.y+delta end end;break
  end end
 end
 local rows={}
 if m.duelSnapshots then
  local phase=route.duelPhase=='after' and 'after' or 'before'
  append(b,'Duel observations',{F.Row('CHR.DUEL.PHASE','Loadout observation',function() return phase end,function(v) move(route,'duelPhase',v);return true end,{choices={{'before','Before the duel'},{'after','After the duel'}}}),F.Row('CHR.DUEL.UNKNOWN','Show unobserved equipment slots',function() return route.duelUnknown==true end,function(v) move(route,'duelUnknown',v);return true end,{boolean=true}),cap('Dated endpoints do not prove equipment used throughout combat. Received damage and healing do not identify the attacker or caster. Unobserved is not confirmed empty.')},'duel')
  local sides={};local top=0;for _,block in ipairs(b) do local h=block.header==false and 12 or 44;for _,r in ipairs(block.rows or {}) do h=h+(r.height or 31) end;top=math.max(top,(block.y or 0)+h+12) end
  for n,side in ipairs(m.duelSnapshots) do local observation=side.phases[phase];local items={}
   items[#items+1]=cap(observation and (phase=='before' and 'Before · ' or 'After · ')..C.Stamp(observation.at) or 'This observation was not recorded.')
   items[#items+1]={title='Received damage',detail=C.Number(side.damage)..' · attacker unknown',height=40};items[#items+1]={title='Received healing',detail=C.Number(side.healing)..' · caster unknown',height=40};items[#items+1]={title='Successful casts observed',detail=C.Number(side.casts),height=40}
   items[#items+1]=cap(side.gearComparison..'. Matching observations do not prove no changes during the duel.')
   local unknown=0;for _,slot in ipairs(G.slots) do local value=G.Slot(observation and observation.gear,slot[1]);if value[2]~='unavailable' or route.duelUnknown then items[#items+1]=itemRow(observation and observation.gear,slot) else unknown=unknown+1 end end
   if unknown>0 then items[#items+1]=cap(unknown..' slots were not observed. Enable Show unobserved equipment slots for individual details.') end
   local traits=observation and observation.traits;items[#items+1]=cap('Talents · '..side.traitComparison)
   if traits then local values=traits.capture.values;for _,choice in ipairs(values.choices or {}) do local title,icon=G.TalentLabel(choice);items[#items+1]={title=title,icon=icon,detail='Recorded rank '..choice[4],height=40} end
    if values.exportString then items[#items+1]=act('CHR.DUEL.TALENT.EXPORT','Copy recorded talent export','Selected dated observation',function() F.Copy('Recorded duel talents',values.exportString) end) end
   else items[#items+1]=cap('Selected talent observation unavailable. No talent tree is inferred.') end
   b[#b+1]={id=n==1 and 'duel-self' or 'duel-opponent',title=side.title,x=(n-1)*.5,y=top,w=.5,rows=items,anchor='duel-'..n}
  end
 end
 if st and m.owner==ns.Chronicle.Owner() then
  rows[1]=act('CHR.RECOLLECTION.EDIT','Add or edit your perspective','Private recollection',function() ns.UI2Operations.Recollection(m) end)
  for _,target in ipairs(ns.ChronicleEventHub.Targets(st,m._activity)) do local note=ns.AthenaRecollections.Get(ns.AthenaJournal.Live(),m.owner,target)
   if note then local remembered=target;rows[#rows+1]=act('CHR.RECOLLECTION.SELECT',note.text~='' and note.text or 'Private recollection',C.Stamp(target.at),function() ns.UI2Operations.Recollection(m,remembered) end,70);rows[#rows].wrap=true end
  end
 end
 if #rows>0 then append(b,'Your perspective',rows,'recollections') end
 if st and m._activity and m._activity.run then append(b,'Run grouping',{act('CHR.RUN.GROUPING',#(m._activity.segmentIDs or {})>1 and 'Separate recorded visits' or 'Allow automatic visit grouping','Original records are kept',function()
  F.Confirm('Change grouping for this run?','Use only when these recorded visits represent different resets or expeditions. Original source records remain intact.',function()
   ns.ChronicleRuns.SeparateVisits(st,m._activity);ns.ChronicleActivities.Clear();ns.UI2Models.Clear();ns.UI2Browse.catalogs={};if ns.Athena.ClearHistoryContext then ns.Athena.ClearHistoryContext() end
   U.Open({page='chronicle',owner=m.owner});return true
  end)
 end)},'grouping') end
 return b
end
-- Source jumps from the book become an intentional developer inspector, while
-- person/adventure links continue to resolve their canonical pages.
local create=U.CreateJournalHost
function U.CreateJournalHost()
 local host=create();local reader=host.reader
 if reader and not reader.ui2PrivacyRoute then reader.ui2PrivacyRoute=true;reader.MemorySettings=function(self) local service=self:MemoryService();if not service then return false end;return ns.UI2Settings.Conversations(service,self.owner) end end
 return host
end
