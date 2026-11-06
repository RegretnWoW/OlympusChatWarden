-- Wiki discussions are ordinary Aether records. Local developer moderation is
-- a bounded preference projection in Exchange.netLocal, never canonical lore.
local _,ns=...
local W,N,F=ns.AthenaLivingWiki,ns.AetherNet,ns.UI2Forms
local function count(t) local n=0;for _ in pairs(t or {}) do n=n+1 end;return n end
local function plain(t) return type(t)=='table' and not getmetatable(t) end
local function shape(t,keys)
 if not plain(t) then return false end;local allowed={};for k in keys:gmatch('%S+') do allowed[k]=true end
 for k in pairs(t) do if not allowed[k] then return false end end;return true
end
local function scalar(v,max) return v==nil or type(v)=='boolean' or type(v)=='string' and #v<=(max or 1200) end
function N.ValidateWikiLocal(root)
 if not shape(root,'version articles') or root.version~=1 or not plain(root.articles) or count(root.articles)>64 then return false end
 for key,a in pairs(root.articles) do
  if not W.ValidKey(key) or not shape(a,'hidden pins notes locked history serial reviewed') or type(a.locked)~='boolean' or not plain(a.hidden) or count(a.hidden)>64 or not plain(a.pins) or count(a.pins)>32 or not plain(a.notes) or count(a.notes)>8 or not plain(a.history) or #a.history>40 then return false end
  for _,set in ipairs({a.hidden,a.pins}) do for id,value in pairs(set) do if type(id)~='string' or #id>384 or value~=true then return false end end end
  for id,note in pairs(a.notes) do if type(id)~='string' or #id>40 or not shape(note,'text at') or not N.Text(note.text,1000) or type(note.at)~='number' or note.at<0 or note.at~=note.at then return false end end
  if a.reviewed~=nil then if not plain(a.reviewed) or count(a.reviewed)>64 then return false end;for id,v in pairs(a.reviewed) do if type(id)~='string' or #id>384 or v~=true then return false end end end
  if a.serial~=nil and (type(a.serial)~='number' or a.serial<0 or a.serial>1000000000 or a.serial%1~=0) then return false end
  local entries=0
  for i,h in pairs(a.history) do
   entries=entries+1
   if type(i)~='number' or i%1~=0 or i<1 or i>#a.history or not shape(h,'action target at before after undone') or not ({HIDE=true,REMOVE=true,PIN=true,LOCK=true,NOTE=true,MUTE=true,REVIEW=true,UNDO=true})[h.action]
    or type(h.target)~='string' or #h.target>384 or type(h.at)~='number' or h.at<0 or h.at~=h.at or not scalar(h.before,4000) or not scalar(h.after,4000) or h.undone~=nil and type(h.undone)~='boolean' then return false end
  end
  if entries~=#a.history then return false end
 end
 return true
end
function W.AdminAllowed()
 local extension=ns.WardenSimLab
 return extension and extension.installed==true and extension.apiVersion==1 and type(extension.Enabled)=='function' and extension.Enabled()==true
  and ns.Membership.Allowed() and ns.Permissions.Decide('UIAccess') or false
end
function W.NetworkModeration() return false,'SITEWIDE_MODERATOR_PROOF_UNAVAILABLE: the existing native adapter has session attribution, not a durable administrator credential.' end
function N.WikiLocked(key) local a=N.WikiLocal(key);return a and a.locked==true or false end
local baseRead=N.ReadSubject
function N.ReadSubject(kind,key)
 local view=baseRead(kind,key);if kind~='WIKI' then return view end
 local localState=N.WikiLocal(key);local muted=N.MutedAuthors();local rows={};local hidden={}
 for _,post in ipairs(view.wall or {}) do if localState and localState.hidden[post.id] or muted[post.author] then hidden[post.id]=true end end
 for _,post in ipairs(view.wall or {}) do if not hidden[post.id] and not (post.parent and hidden[post.parent]) then
  local row=ns.Athena.Copy(post);row.pinned=localState and localState.pins[post.id] or nil;rows[#rows+1]=row
 end end
 view.wall=rows;view.localLocked=localState and localState.locked or false;view.editorialNotes=localState and localState.notes or {};view.moderationScope='Local installation only';view.reports=view.reports or {}
 return view
end
local function change() if ns.UI2Models then ns.UI2Models.Clear() end;if ns.UI2 then ns.UI2.Refresh(true) end end
local function now() return ns.SafeCall(time) or 0 end
function W.Moderate(key,action,target,value,scope)
 if not W.AdminAllowed() then return false,'PRIVATE_DEVELOPER_REQUIRED' end
 if scope and scope~='local' then return W.NetworkModeration() end
 if not W.ValidKey(key) or not ({HIDE=true,REMOVE=true,PIN=true,LOCK=true,NOTE=true,MUTE=true,REVIEW=true})[action] then return false,'INVALID_MODERATION_ACTION' end
 target=target or ''
 if type(target)~='string' or #target>384 then return false,'EXACT_TARGET_REQUIRED' end
 if action=='NOTE' then if #target==0 or #target>40 or not target:match('^[%w_-]+$') or not N.Text(value,1000) then return false,'EDITORIAL_NOTE_BOUND' end
 elseif type(value)~='boolean' then return false,'EXPLICIT_BOOLEAN_REQUIRED' end
 local before
 local ok,why=N.UpdateWikiLocal(key,function(a,state)
  if action=='PIN' or action=='HIDE' or action=='REMOVE' then
   local c=N.Cached();local exists=false
   for _,post in ipairs(c and c:View('WIKI',key).wall or {}) do if post.id==target then exists=true end end
   if not exists then return false,'POST_NOT_AVAILABLE' end
   local set=action=='PIN' and a.pins or a.hidden;before=set[target]==true;set[target]=value and true or nil
  elseif action=='MUTE' then before=state.muted and state.muted[target]==true or false;local accepted,reason=N.ApplyMutePreference(state,target,value);if not accepted then return false,reason end
  elseif action=='REVIEW' then
   local c=N.Cached();local exists=false;for _,report in ipairs(c and c:View('WIKI',key).reports or {}) do if report.id==target then exists=true end end
   if not exists then return false,'REPORT_NOT_AVAILABLE' end
   a.reviewed=a.reviewed or {};before=a.reviewed[target]==true;a.reviewed[target]=value and true or nil
  elseif action=='LOCK' then before=a.locked;a.locked=value
  elseif action=='NOTE' then before=a.notes[target] and a.notes[target].text or '';a.notes[target]=value~='' and {text=value,at=now()} or nil end
  if #a.history>=40 then table.remove(a.history,1) end
  a.history[#a.history+1]={action=action,target=target,at=now(),before=before,after=value};return true
 end)
 if ok then change() end
 return ok,why or 'Applied on this installation only; no network administrator action was sent.'
end
function W.UndoModeration(key)
 if not W.AdminAllowed() then return false,'PRIVATE_DEVELOPER_REQUIRED' end
 local state=N.WikiLocal(key);local h,index
 for i=#(state and state.history or {}),1,-1 do local row=state.history[i];if not row.undone and row.action~='UNDO' then h=row;index=i;break end end
 if not h then return false,'NO_REVERSIBLE_LOCAL_ACTION' end
 local ok,why=N.UpdateWikiLocal(key,function(a,state)
  local old=a.history[index];if not old or old.at~=h.at or old.action~=h.action or old.undone then return false,'MODERATION_HISTORY_CHANGED' end
  if h.action=='MUTE' then local accepted,reason=N.ApplyMutePreference(state,h.target,h.before==true);if not accepted then return false,reason end
  elseif h.action=='REVIEW' then a.reviewed=a.reviewed or {};a.reviewed[h.target]=h.before and true or nil
  elseif h.action=='PIN' then a.pins[h.target]=h.before and true or nil
  elseif h.action=='HIDE' or h.action=='REMOVE' then a.hidden[h.target]=h.before and true or nil
  elseif h.action=='LOCK' then a.locked=h.before==true
  elseif h.action=='NOTE' then a.notes[h.target]=h.before and h.before~='' and {text=h.before,at=now()} or nil end
  old.undone=true;if #a.history>=40 then table.remove(a.history,1) end
  a.history[#a.history+1]={action='UNDO',target=h.target,at=now(),before=h.after,after=h.before};return true
 end)
 if ok then change() end;return ok,why
end
function W.ReportPost(key,post)
 if not W.ValidKey(key) then return false,'EXACT_WIKI_SUBJECT_REQUIRED' end
 if not N.PublicationClient() then
  if ns.UI2Operations and ns.UI2Operations.CommunityConcern then return ns.UI2Operations.CommunityConcern('WIKI',key,post,'Living Wiki discussion') end
  return F.Feedback(false,'Connect to approved Aether peers to submit a report. Cached discussions remain readable.')
 end
 return F.Form({title='Report this contribution',help='Your reason is an attributable community report sent to approved reachable peers. It is not verified lore or an automatic removal.',fields={{key='reason',label='Reason · 280 characters',limit=280,value='',multiline=true,height=100}},submitLabel='Review report',submit=function(v)
  if not N.Text(v.reason,280) or #v.reason==0 then return false,'Write a plain-text reason within 280 characters.' end
  return F.Confirm('Submit this report?','The report identifies this contribution on '..key..'.\n'..v.reason,function()
   local c,why=N.PublicationClient();if not c then return false,why end
   local found=false;for _,p in ipairs(c:View('WIKI',key).wall) do if p.id==post.id then found=true end end
   if not found then return false,'The contribution is no longer available.' end
   local slot=N.HideSlot(post.id);local pair,why=c:Publish('WIKI',key,'WIKI_REPORT',slot,{target=post.id,reason=v.reason},N.NextRevision(c,'WIKI',key,'WIKI_REPORT',slot),false,true)
   if pair then change() end;return pair~=nil,pair and 'Report submitted.' or why
  end)
 end})
end
function W.Discussion(key,page)
 local view=N.ReadSubject('WIKI',key);local roots,children={},{}
 for _,p in ipairs(view.wall) do if p.parent then children[p.parent]=children[p.parent] or {};children[p.parent][#children[p.parent]+1]=p else roots[#roots+1]=p end end
 table.sort(roots,function(a,b) if (a.pinned==true)~=(b.pinned==true) then return a.pinned==true end;return a.at==b.at and a.id<b.id or a.at>b.at end)
 page=math.max(1,math.min(math.max(1,math.ceil(#roots/10)),math.floor(tonumber(page) or 1)))
 local rows={};for i=(page-1)*10+1,math.min(page*10,#roots) do local p=roots[i];rows[#rows+1]=p
  table.sort(children[p.id] or {},function(a,b) return a.at==b.at and a.id<b.id or a.at<b.at end)
  for _,reply in ipairs(children[p.id] or {}) do rows[#rows+1]=reply end
 end
 return {view=view,rows=rows,page=page,pages=math.max(1,math.ceil(#roots/10)),rootCount=#roots,drafts={},state=N.ConnectionState(),live=N.Active()~=nil}
end
