-- Optional screenshot requests over accepted Chronicle evidence. No images,
-- filenames, gallery database, camera movement or network publication.
local _,ns=...
local M={VERSION=1,MAX_QUEUE=4,MAX_PER_MINUTE=9,OFFSETS={0,1.8,4.0},metrics={events=0,requested=0,signals=0,failed=0,coalesced=0,limited=0},queue={},recent={},budget={},coverage={}}
ns.AthenaMoments=M
local frame=CreateFrame('Frame');local current,pending,hidden,flash,ready,feedbackAt,lastSignal
local function now()return ns.SafeNumber(ns.SafeCall(GetServerTime))or 0 end
local function tick()return ns.SafeNumber(ns.SafeCall(GetTime))or 0 end
local function safe(v,n)return ns.SafeString(v,n or 256)end
local function copy(v)return ns.Athena.Copy(v)end
local function policy(create)
 local db=ns.DB;if not db then return end
 if db.athenaMoments==nil and create then db.athenaMoments={version=1,owners={}}end
 local root=db.athenaMoments
 if not ns.Readable(root)or type(root)~='table'or root.version~=1 or type(root.owners)~='table'then return end
 local owner=ns.Chronicle.Owner();local p=owner and root.owners[owner]
 if not p and create and owner then p={enabled=false,effect=true,cleanUI=false,categories={}};root.owners[owner]=p end
 return p
end
function M.Status()
 local p=policy(false)
 return {enabled=p and p.enabled==true,effect=not p or p.effect~=false,cleanUI=p and p.cleanUI==true,categories=copy(p and p.categories or{}),
  metrics=copy(M.metrics),queued=#M.queue+(current and 1 or 0)+(pending and not current and 1 or 0),last=M.last,coverage=copy(M.coverage),api=type(Screenshot)=='function'and'AVAILABLE_NATIVE_NOT_TESTED'or'UNAVAILABLE',
  recovery=hidden and'UI_ALPHA_RESTORE_PENDING'or nil}
end
function M.Set(key,value)
 if not ns.Permissions.Decide('UIAccess')or type(value)~='boolean'then return false,'EXPLICIT_OWNER_UI_REQUIRED'end
 local p=policy(true);if not p then return false,'MOMENTS_PREFERENCES_UNAVAILABLE'end
 if key=='enabled'or key=='effect'or key=='cleanUI'then p[key]=value
 elseif ({level=true,quest=true,boss=true,instance=true,loot=true,pvp=true,duel=true,exploration=true})[key]then p.categories[key]=value
 else return false,'UNKNOWN_MOMENTS_SETTING'end
 if key=='enabled'and not value then M.Boundary('DISABLED')end
 return true,'Moments preferences saved. History and text consent are unchanged.'
end
local function combat()return ns.Checked(ns.SafeCall(InCombatLockdown))or ns.Checked(ns.SafeCall(UnitAffectingCombat,'player'))end
local function recording()return ns.Chronicle.InWorld()and ns.Chronicle.PersonalEnabled()end
function M.RestoreUI()
 if not hidden then return true end
 local h=hidden
 -- Alpha restoration never calls Show: an intentionally hidden UI stays hidden.
 if not UIParent or not UIParent.SetAlpha then return false end
 local alpha=ns.SafeNumber(ns.SafeCall(UIParent.GetAlpha,UIParent))
 if alpha==0 then local ok=pcall(UIParent.SetAlpha,UIParent,h.alpha);if not ok then return false end end
 hidden=nil
 if ns.DB then ns.DB.athenaMomentUIRecovery=nil end
 return true
end
local function clean()
 local p=policy(false)
 if not p or not p.cleanUI or combat()or not ready or not ns.Chronicle.InWorld()then return false end
 if not UIParent or not UIParent.IsProtected or ns.Checked(ns.SafeCall(UIParent.IsProtected,UIParent))or not ns.Checked(ns.SafeCall(UIParent.IsShown,UIParent))then return false end
 local alpha=ns.SafeNumber(ns.SafeCall(UIParent.GetAlpha,UIParent));if not alpha or alpha<=0 then return false end
 hidden={alpha=alpha,restoreAt=tick()+.15}
 ns.DB.athenaMomentUIRecovery={version=1,alpha=alpha,owner=ns.Chronicle.Owner()}
 local ok=pcall(UIParent.SetAlpha,UIParent,0)
 if not ok or ns.SafeNumber(ns.SafeCall(UIParent.GetAlpha,UIParent))~=0 then M.RestoreUI();return false end
 return true
end
local function feedback()
 local p=policy(false);if not p or p.effect==false or combat()or not UIParent or not ready then return end
 if not flash then
  flash=CreateFrame('Frame',nil,UIParent);flash:SetAllPoints(UIParent);flash:EnableMouse(false);flash:SetFrameStrata('FULLSCREEN_DIALOG')
  local t=flash:CreateTexture(nil,'OVERLAY');t:SetAllPoints(flash);t:SetColorTexture(.92,.75,.39,.08)
 end
 flash.started=tick();flash:Show()
end
local function metadata(item,index,status,actual,reason)
 local data={recordType='moment_capture',momentRef=item.id,requestRef=item.id..'/'..index,sourceRef=item.link.sourceRef,activityRef=item.link.activityRef,
  sessionRef=item.event.session,category=item.category,burstIndex=index,burstCount=3,intendedUI=item.modes[index],actualUI=actual or'visible',captureStatus=status,
  reason=reason,questID=item.event.details.questID,itemID=item.event.details.itemID,encounterID=item.event.details.encounterID}
 local e=ns.Chronicle.Record('native_event','ATHENA_MOMENT',data,nil,'observed',item.event.location)
 if not e then M.metrics.failed=M.metrics.failed+1;M.last='METADATA_ADMISSION_FAILED; CAPTURE_NOT_CONFIRMED';return end
 M.last=status;return e
end
local function budget()
 local rows={};for _,at in ipairs(M.budget)do if at+60>tick()then rows[#rows+1]=at end end;M.budget=rows
 if #rows>=M.MAX_PER_MINUTE then return false end;rows[#rows+1]=tick();return true
end
function M.Classify(e)
 local d=e.details or{};local f=d.recordType or e.kind
 if f=='level_change'and d.after and d.before and d.after>d.before then return 'level' end
 if f=='quest_turnin'and d.questID then
  local chains=ns.AthenaQuestChains
  if chains and #chains.Previous(d.questID)>0 and #chains.Following(d.questID)==0 then return 'quest' end
  return nil,'QUEST_NOT_KNOWN_CHAIN_CONCLUSION'
 end
 if f=='boss_kill_event'or f=='encounter_ended'and d.success==1 then
  for _,endpoint in ipairs(ns.ChronicleRunEndpoints or{})do if e.location.instanceID==endpoint.mapID then for _,id in ipairs(endpoint.encounterIDs)do if id==d.encounterID then return 'instance'end end end end
  return 'boss'
 end
 if f=='instance_completed'and e.source=='LFG_COMPLETION_REWARD'then return 'instance'end
 if f=='item_received'or f=='quest_item_received'or f=='encounter_loot_delivery'then
  local info=GetItemInfo or C_Item and C_Item.GetItemInfo
  if type(info)=='function'then local ok,_,_,quality=pcall(info,d.itemID);if ok and ns.SafeNumber(quality)and quality>=3 then return 'loot'end end
  return nil,'ITEM_QUALITY_NOT_AVAILABLE_OR_NOT_NOTABLE'
 end
 if f=='pvp_match_complete'and e.source=='PVP_MATCH_COMPLETE'then return 'pvp'end -- completion, never an inferred owner win
 if f=='duel_session_result'and d.resultKnown==true and(d.result=='win'or d.result=='loss')then return 'duel'end
 if f=='exploration_discovery'and e.source=='CHAT_MSG_SYSTEM'and d.method=='localized native exploration notice'then return 'exploration'end
end
function M.Context(e)
 local C=ns.Chronicle;local place=e and e.location or C.Place()or{};local anchor=e and{sourceRef=ns.Athena.EvidenceRef(e.id),at=e.at,sessionRef=e.session,owner=e.character,event=e}or M.anchor
 local base={sessionRef=e and e.session or M.session,instanceID=place.instanceID,zone=place.zone}
 if not anchor or anchor.owner~=C.Owner()or now()-anchor.at>90 or now()<anchor.at-5 then return base end
 local prior=anchor.event and anchor.event.location or{};if prior.zone~=place.zone or prior.instanceID~=place.instanceID then return base end
 local ctx=e and e.sourceContext or ns.AthenaIntakeContext.State(anchor.owner,anchor.sessionRef)
 local instance=ctx and ctx.instanceRef;local encounter=ctx and ctx.encounterRef
 local activity=encounter and('activity:ENCOUNTER_ATTEMPT:'..encounter)or instance and('activity:'..(place.instanceType=='raid'and'RAID_RUN'or place.instanceType=='pvp'and'BATTLEGROUND_VISIT'or'INSTANCE_VISIT')..':'..instance)
 if e and e.details.recordType=='encounter_started'then activity='activity:ENCOUNTER_ATTEMPT:'..e.id end
 return {sourceRef=anchor.sourceRef,sessionRef=anchor.sessionRef,activityRef=activity,eventAt=anchor.at,eventCategory=anchor.category,
  instanceID=place.instanceID,mapID=anchor.event and anchor.event.sourceContext and anchor.event.sourceContext.mapID,zone=place.zone}
end
function M.Accepted(e,status,live)
 if not live or not e or not e.character or not e.session then return end
 M.session=e.session
 local family=e.details.recordType or e.kind
 if family=='moment_capture'then return end
 if e.kind=='location'or e.kind=='instance_enter'or e.kind=='instance_exit'or e.kind=='recording_stop'then M.anchor=nil end
 local category,why=M.Classify(e)
 if category or why then M.coverage[family]=category and'ACCEPTED_SOURCE_TRIGGER'or why end
 local textRelevant=category or family=='quest_accepted'or family=='quest_turnin'or family=='encounter_started'or family=='encounter_ended'or family=='instance_completed'
 if textRelevant then
  M.anchor={sourceRef=ns.Athena.EvidenceRef(e.id),at=e.at,sessionRef=e.session,owner=e.character,event=e,category=category or family}
  local link=M.Context(e);link.eventCategory=category or family
  if ns.AthenaConversations then ns.AthenaConversations.Trigger(e,link)end
 end
 if not category then return end
 M.metrics.events=M.metrics.events+1
 local p=policy(false);if not p or not p.enabled or p.categories[category]==false or not recording()then return end
 for key,at in pairs(M.recent)do if at+120<now()then M.recent[key]=nil end end
 local d=e.details;local key=e.session..'/'..category..'/'..tostring(d.encounterID or d.duelID or d.questID or d.itemID or d.after or e.id)
 if M.recent[key]and M.recent[key]+12>=now()then M.metrics.coalesced=M.metrics.coalesced+1;return end
 if #M.queue+(current and 1 or 0)>=M.MAX_QUEUE then M.metrics.limited=M.metrics.limited+1;M.last='BURST_QUEUE_LIMIT';return end
 M.recent[key]=now()
 local modes
 -- Keep precedence explicit: evidence-sensitive captures always retain UI.
 if category=='loot'or category=='pvp'then modes={'visible','visible','visible'}elseif category=='level'or category=='exploration'then modes={'clean','clean','clean'}else modes={'visible','clean','visible'}end
 p.sequence=(ns.SafeNumber(p.sequence)or 0)+1
 M.queue[#M.queue+1]={id='athena-moment/1/'..e.id..'/'..p.sequence,event=e,category=category,modes=modes,link=M.Context(e),index=1,at=tick(),deadline=tick()+20}
 frame:SetScript('OnUpdate',function()M.Pump()end)
end
function M.Boundary(reason)
 if pending then metadata(pending.item,pending.index,'INTERRUPTED',pending.actual,reason);pending=nil end
 M.queue={};current=nil;M.anchor=nil;feedbackAt=nil;M.RestoreUI();if flash then flash:Hide()end
 if not hidden then frame:SetScript('OnUpdate',nil)end
end
function M.Pump()
 local ok,err=pcall(function()
  if hidden and tick()>=hidden.restoreAt then M.RestoreUI()end
  if feedbackAt and tick()>=feedbackAt then feedbackAt=nil;feedback()end
  if flash and flash:IsShown()and tick()-flash.started>.18 then flash:Hide()end
  if not recording()or not ready then M.Boundary('WORLD_OR_RECORDING_BOUNDARY');return end
  if pending and tick()-pending.at>=6 then metadata(pending.item,pending.index,'NO_CONFIRMATION',pending.actual,'NO_NATIVE_RESULT_SIGNAL');pending=nil end
  if not current then current=table.remove(M.queue,1)end
  if not current then if not pending and not hidden and not feedbackAt and(not flash or not flash:IsShown())then frame:SetScript('OnUpdate',nil)end;return end
  if pending or tick()<current.at+M.OFFSETS[current.index]then return end
  local item=current;local index=item.index
  if tick()>item.deadline then metadata(item,index,'INTERRUPTED','visible','BURST_DEADLINE');current=nil;return end
  if not budget()then metadata(item,index,'RATE_LIMITED','visible','GLOBAL_CAPTURE_BUDGET');M.metrics.limited=M.metrics.limited+1;current=nil;return end
  if type(Screenshot)~='function'then metadata(item,index,'UNSUPPORTED','visible','SCREENSHOT_API_UNAVAILABLE');M.metrics.failed=M.metrics.failed+1;current=nil;return end
  local alreadyHidden=UIParent and(not ns.Checked(ns.SafeCall(UIParent.IsShown,UIParent))or ns.SafeNumber(ns.SafeCall(UIParent.GetAlpha,UIParent))==0)
  local actual=alreadyHidden and'user_hidden'or item.modes[index]=='clean'and clean()and'opacity_zero'or'visible'
  if not metadata(item,index,'REQUESTED',actual)then M.RestoreUI();current=nil;return end
  pending={item=item,index=index,actual=actual,at=tick()}
  local accepted=pcall(Screenshot)
  if not accepted then metadata(item,index,'FAILED',actual,'SCREENSHOT_API_EXCEPTION');pending=nil;M.metrics.failed=M.metrics.failed+1;M.RestoreUI()
  else M.metrics.requested=M.metrics.requested+1;feedbackAt=tick()+.25 end
  item.index=index+1;if item.index>3 then current=nil end
 end)
 if not ok then M.last='CAPTURE_SEQUENCE_ERROR';M.metrics.failed=M.metrics.failed+1;M.RestoreUI();M.queue={};current=nil;pending=nil end
end
function M.Result(event)
 if not pending then return end
 if event~='SCREENSHOT_SUCCEEDED'and event~='SCREENSHOT_FAILED'then return end
 if lastSignal and tick()-lastSignal<.25 then return end
 lastSignal=tick()
 local p=pending;pending=nil
 metadata(p.item,p.index,'SIGNAL_OBSERVED_WHILE_PENDING',p.actual,'ATTRIBUTION_UNCERTAIN; '..event..'; NO_REQUEST_ID_OR_FILENAME')
 if event=='SCREENSHOT_FAILED'then M.metrics.failed=M.metrics.failed+1 end
 M.metrics.signals=M.metrics.signals+1;M.RestoreUI()
end
function M.Discovery(message)
 if not ns.Chronicle.InWorld()or not ns.CanRead(message)then return end
 for _,format in ipairs({ERR_ZONE_EXPLORED_XP or false,ERR_ZONE_EXPLORED or false})do if ns.CanRead(format)then
  local pattern=format:gsub('([%(%)%.%+%-%*%?%[%]%^%$])','%%%1'):gsub('%%s','(.-)'):gsub('%%d','(%%d+)')
  local place=message:match('^'..pattern..'$')
  if safe(place,144)and place~=''then return ns.Chronicle.Record('native_event','CHAT_MSG_SYSTEM',{recordType='exploration_discovery',name=place,method='localized native exploration notice'},nil,'observed')end
 end end
end
for _,event in ipairs({'PLAYER_LOGIN','PLAYER_ENTERING_WORLD','PLAYER_LEAVING_WORLD','PLAYER_LOGOUT','PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED','SCREENSHOT_SUCCEEDED','SCREENSHOT_FAILED','CHAT_MSG_SYSTEM'})do pcall(frame.RegisterEvent,frame,event)end
frame:SetScript('OnEvent',function(_,event,...)
 if event=='PLAYER_ENTERING_WORLD'then ready=true
 elseif event=='PLAYER_LOGIN'then
  local r=ns.DB and ns.DB.athenaMomentUIRecovery
  if type(r)=='table'and r.version==1 and ns.SafeNumber(r.alpha)and r.alpha>=0 and r.alpha<=1 then hidden={alpha=r.alpha,restoreAt=0};M.RestoreUI()end
 elseif event=='PLAYER_LEAVING_WORLD'or event=='PLAYER_LOGOUT'then ready=false;M.Boundary(event)
 elseif event=='PLAYER_REGEN_DISABLED'or event=='PLAYER_REGEN_ENABLED'then M.RestoreUI()
 elseif event=='SCREENSHOT_SUCCEEDED'or event=='SCREENSHOT_FAILED'then M.Result(event)
 elseif event=='CHAT_MSG_SYSTEM'then M.Discovery(...)end
end)
M.frame=frame
