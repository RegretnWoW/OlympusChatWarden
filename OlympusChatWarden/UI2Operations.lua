-- Operational UI2 pages over existing services. No legacy visual constructors.
local _,ns=...
local U,C,F,L=ns.UI2,ns.UI2Components,ns.UI2Forms,ns.UI2Layouts
local O={};ns.UI2Operations=O
local function cap(text,height) text=text or '';return {title=text,kind='caption',wrap=true,height=math.max(34,math.min(height or 120,math.ceil(#text/53)*19+14))} end
local function act(id,title,detail,fn,height) return {id=id,title=title,detail=detail,activate=fn,height=height or 40} end
local function block(id,title,x,y,w,rows)
 if w<=.4 then for _,row in ipairs(rows) do if row.detail and not row.cells and (#tostring(row.detail)>10 or #tostring(row.title)>24) then row.stacked=true;row.height=math.max(52,row.height or 40) end end end
 return {id=id,title=title,x=x,y=y,w=w,rows=rows}
end
local function go(route) return function() U.Open(route) end end
local function copy(route) local out={};for k,v in pairs(route) do out[k]=v end;return out end
local function routeTo(route,key,value) local out=copy(route);out[key]=value;out.scroll=0;return out end
local function matches(text,query) return not query or query=='' or tostring(text or ''):lower():find(query:lower(),1,true)~=nil end
local function feedback(rows) if U.feedback then rows[#rows+1]=cap(U.feedback) end end
local function settings(category) return go({page='settings',category=category}) end
local function paginate(rows,route,tag)
 if #rows<=40 then return rows end
 local page=math.max(1,math.min(math.ceil(#rows/40),tonumber(route.listPage) or 1));local out={}
 out[1]=act(tag..'.PAGE','Page '..page..' of '..math.ceil(#rows/40),#rows..' matching entries',nil)
 if page>1 then out[#out+1]=act(tag..'.PREVIOUS','Previous entries','',go(routeTo(route,'listPage',page-1))) end
 for n=(page-1)*40+1,math.min(page*40,#rows) do out[#out+1]=rows[n] end
 if page*40<#rows then out[#out+1]=act(tag..'.NEXT','Next entries','',go(routeTo(route,'listPage',page+1))) end
 return out
end
-- Export is a deliberate selection and privacy review, using the original
-- Export.Batch/Build sanitizer. Only the final copy artifact is a text field.
function O.Export(kind,mode,records)
 local batch=ns.Export.Batch(kind,mode,records);O.exportBatch=batch
 local choices={};for i,item in ipairs(batch.items) do choices[#choices+1]={i,ns.Export.Label(item)} end
 local function preview()
  return F.Form({title='Export privacy review',help=#batch.items..' retained records. Names are hidden and private notes excluded by default. Review the final text before copying; no delivery occurs.',fields={{key='selection',label='Included entries',value=batch.scope or 'all',choices={{'all','Include all entries'},{'none','Include no entries'},{'custom','Use individually selected entries'}}},{key='hide',label='Known names',value=batch.hideNames,choices={{true,'Hide known names'},{false,'Include known names'}}},{key='notes',label='Private notes',value=batch.includeNotes,choices={{false,'Exclude notes'},{true,'Include notes'}}},{key='names',label='Additional names to hide (comma separated)',value=batch.extraNames,limit=1000}},submitLabel='Build copy preview',submit=function(v)
   batch.scope=v.selection;if v.selection=='all' then batch.selected={} elseif v.selection=='none' then for i=1,#batch.items do batch.selected[i]=false end end
   batch.hideNames=v.hide;batch.includeNotes=v.notes;batch.extraNames=v.names
   F.Copy('Reviewed '..kind..' export',ns.Export.Build(batch),'Ctrl+C copies the selected, sanitized export. Check for any other identifying details before sharing.');return false,'Copy preview opened.'
  end})
 end
 if #choices==0 then return F.Feedback(false,'No records are available in this scope.') end
 local f=preview()
 C.Button(f,'Choose entries',function()
  local selector=F.Form({title='Choose export entries',help='All entries start included. Select an entry to toggle it; your selection is kept for this export only.',fields={{key='entry',label='Entry',value=1,choices=choices}},submitLabel='Toggle selected entry',submit=function(v) local id=tonumber(v.entry);batch.scope='custom';batch.selected[id]=batch.selected[id]==false;return false,(batch.selected[id]==false and 'Excluded: ' or 'Included: ')..tostring(choices[id][2]) end})
  C.Button(selector,'Review privacy',preview,170):SetPoint('BOTTOMLEFT',230,18)
 end,170):SetPoint('BOTTOMLEFT',230,18)
 return f
end
function O.Rule(rule)
 return F.Form({title=rule and rule.id and 'Edit personal rule' or 'New personal rule',help='Personal phrase rules use the original validator. This does not modify an author-signed pack.',fields={{key='phrase',label='Exact phrase',value=rule and rule.phrase,limit=160},{key='action',label='Action',value=rule and rule.action or 'Redacted',choices=ns.Theme.Actions},{key='replacement',label='Replacement (only for Replace)',value=rule and rule.replacement or '',limit=160},{key='enabled',label='Status',value=not rule or rule.enabled~=false,choices={{true,'Enabled'},{false,'Paused'}}}},submit=function(v) return ns.Personal.SaveRule(v.phrase,v.action,rule and rule.id,nil,v.enabled,v.replacement) end})
end
local function sensitive(item) return item and (item.action=='Hidden' or item.action=='Redacted' or item.action=='Replaced') end
function O.ToggleOriginal(route,item)
 O.revealedID=O.revealedID==item.id and nil or item.id;return U.Refresh(true)
end
function O.CaptureActions(detail,records,title)
 local captured={};for _,e in ipairs(records) do captured[#captured+1]=e end
 local function retained()
  local map={};for _,e in ipairs(ns.ChatCapture.db.entries) do map[e.id]=e end
  local out={};for _,e in ipairs(captured) do if map[e.id]~=e then return nil,'Selected capture changed; select it again.' end;out[#out+1]=e end
  return out
 end
 detail[#detail+1]=act('CHAT.CAPTURE.COPY','Copy selection','Retained lines only · local copy',function()
  local rows,why=retained();if not rows then return F.Feedback(false,why) end;local lines={};for _,e in ipairs(rows) do lines[#lines+1]=ns.ChatCapture.Line(e) end;return F.Copy(title or 'Captured chat',table.concat(lines,'\n\n'))
 end)
 detail[#detail+1]=act('CHAT.CAPTURE.EXPORT','Export selection','Review selected lines and privacy',function() local rows,why=retained();if not rows then return F.Feedback(false,why) end;return O.Export('capture',nil,rows) end)
 detail[#detail+1]=act('CHAT.CAPTURE.RULE','Create personal rule','Prefill from the selected message · save separately',function()
  local rows,why=retained();if not rows then return F.Feedback(false,why) end;return O.Rule({phrase=rows[#rows].original,action='Redacted',enabled=true})
 end)
 detail[#detail+1]=act('CHAT.CAPTURE.DELETE','Delete selection from capture','Bookmarks and other capture stay',function()
  F.Confirm('Delete selected capture?',#captured..' selected retained lines. Bookmarks and unrelated messages remain.',function()
   local rows,why=retained();if not rows then return false,why end;local removed=ns.ChatCapture.RemoveRecords(rows);return removed==#rows,'Removed '..removed..' selected lines. Bookmarks kept.'
  end)
 end)
end
function O.SignalText(item)
 local review=item.reviewID and ns.Review.Get(item.reviewID)
 if sensitive(review) or sensitive(item) then return review and review.filtered and review.filtered~=review.original and review.filtered or 'Hidden message · Original concealed' end
 return item.preview or item.text or 'Source text unavailable'
end
function O.SignalHighlighted(item)
 local text=O.SignalText(item);local review=item.reviewID and ns.Review.Get(item.reviewID)
 local function plain(v) return v:gsub('|','||') end
 if sensitive(item) or sensitive(review) then return plain(text) end
 local ranges={};for _,hit in ipairs(item.mentionMatches or {}) do
  local a,b=ns.SafeNumber(hit.first),ns.SafeNumber(hit.last)
  if a and b and a%1==0 and b%1==0 and a>=1 and b>=a and b<=#text then ranges[#ranges+1]={a,b} end
 end
 table.sort(ranges,function(a,b) return a[1]<b[1] or a[1]==b[1] and a[2]>b[2] end)
 local out,cursor={},1;for _,range in ipairs(ranges) do if range[1]>=cursor then
  out[#out+1]=plain(text:sub(cursor,range[1]-1));out[#out+1]='|cff1a4a66'..plain(text:sub(range[1],range[2]))..'|r';cursor=range[2]+1
 end end;out[#out+1]=plain(text:sub(cursor));return table.concat(out)
end
function O.SignalCapture(item)
 local e=item.sender and item.lineID and ns.ChatCapture.Find(item.sender,item.lineID)
 return e and e.event==item.event and e or nil
end
function O.MuteMatches(item)
 local n=0
 for _,hit in ipairs(item.mentionMatches or {}) do
  if hit.id==0 then ns.Mentions.Set('character',false);n=n+1
  else for _,phrase in ipairs(ns.Mentions.db.phrases) do if phrase.id==hit.id and phrase.text==hit.text then ns.Mentions.Change(hit.id,false,false);n=n+1;break end end end
 end
 return n>0,n>0 and ('Muted '..n..' matched watch phrases.') or 'Matched phrases are no longer available; nothing changed.'
end
function O.FilterReport(entry,kind,draft)
 local original=entry and ns.Review.DisplayOriginal(entry) or draft and draft.original or ''
 local sources={};for _,pair in ipairs(ns.Theme.Sources) do if pair[1]~='all' then sources[#sources+1]=pair end end
 return F.Form({title='Filter feedback',draftKey='filter-report/'..tostring(entry and entry.id or draft and (draft.captureID or draft.contextKey) or 'manual'),help='Saved locally. Feedback never learns a rule or sends a report. Add a personal rule separately when you want one.',fields={{key='original',label='Original message',value=original,multiline=true,height=110,limit=8192,code=true},{key='issue',label='Issue',value=kind or 'Wrong action',choices={{'Missed match','Missed by filter'},{'False positive','Should have stayed visible'},{'Wrong action','Needed another action'}}},{key='action',label='Expected action',value=kind=='False positive' and 'Unchanged' or 'Redacted',choices=ns.Theme.Actions},{key='source',label='Source',value=entry and entry.kind or draft and draft.source or 'manual',choices=sources},{key='note',label='Your note',multiline=true,height=65,limit=1000}},submit=function(v)
  local ok,why=ns.Personal.SaveReport(v.original,v.issue=='False positive' and 'Unchanged' or v.action,v.note,v.source,entry or draft,nil,v.issue)
  if ok and entry then ns.Review.Mark(entry.id,'Reported') end;return ok,why
 end})
end
function O.TestPhrase()
 return F.Form({title='Test filter',help='Uses your current signed packs, exceptions, personal rules and preset. No chat delivery, history, capture or contact detector calls.',fields={{key='phrase',label='Phrase to test',value='',limit=2048}},submitLabel='Analyze phrase',submit=function(v)
  local result,why=ns.PhraseTester.Analyze(v.phrase);if not result then return false,why end
  O.phraseResult=result;U.Open({page='messages',subsection='test'});return true,'Phrase analyzed without sending or recording it.'
 end})
end
function O.ImportPack()
 local origin=F.RouteKey()
 return F.Form({title='Import signed rule pack',draftKey='pack-import',help='Paste the complete signed envelope. The normal author signature and version validator must approve it before a separate install confirmation.',fields={{key='text',label='Signed envelope',multiline=true,height=280,limit=600000,code=true}},submitLabel='Verify signature',submit=function(v)
  O.packPreview=nil
  local ok,why=ns.RulePacks.BeginImport(v.text,function(preview,err)
   if not preview then F.Feedback(false,err,origin);return end
   O.packPreview=preview
   if F.RouteKey()==origin then O.ReviewPack() end
  end)
  if not ok then return false,why end;return true,'Pack verification started. No pack has been installed yet.'
 end})
end
function O.ReviewPack()
 local preview=O.packPreview;if not preview then return false,'Verify a signed pack first.' end
 return F.Form({title='Verified pack · '..preview.title,help='Author: '..preview.author..' · version '..preview.version..'. Added '..preview.added..', changed '..preview.changed..', removed '..preview.removed..'. Signature verified by the unchanged importer.',fields={{key='enable',label='After installation',value=preview.enabled==true,choices={{false,'Keep disabled'},{true,'Enable this pack'}}}},submitLabel='Install verified pack',submit=function(fields) local ok,why=ns.RulePacks.Commit(preview.token,fields.enable);if ok then O.packPreview=nil end;return ok,why end})
end
function O.ChatFilters(route)
 local kinds={{false,'All source types'}};local seen={}
 for _,entry in ipairs(route.subsection=='capture' and ns.ChatCapture.db and ns.ChatCapture.db.entries or ns.Review.entries or {}) do
  local kind=entry.kind;if kind and not seen[kind] then seen[kind]=true;kinds[#kinds+1]={kind,ns.Review.Source({kind=kind})} end
 end
 return F.Form({title='Filter retained messages',fields={{key='sender',label='Sender contains',value=route.sender or '',limit=128},{key='channel',label='Channel or event contains',value=route.channel or '',limit=128},{key='sourceKind',label='Source type',value=route.sourceKind or false,choices=kinds},{key='age',label='Time scope',value=route.age or 0,choices={{0,'All retained'},{3600,'Last hour'},{86400,'Last day'},{604800,'Last week'}}},{key='unread',label='Read state',value=route.unread==true,choices={{false,'All entries'},{true,'Unread only'}}}},submit=function(v) local nextRoute=copy(route);for k,value in pairs(v) do nextRoute[k]=value end;nextRoute.scroll=0;nextRoute.listPage=1;U.Open(nextRoute,true);return true end})
end
function L.Chat(route)
 local section=route.subsection or 'review';local b={};local tools={}
 local revealSelection=section..'/'..tostring(route.owner)..'/'..tostring(route.messageID or route.captureID or route.selectedID)
 if O.revealSelection~=revealSelection then O.revealSelection=revealSelection;O.revealedID=nil end
 for _,pair in ipairs({{'review','Review queue'},{'capture','Captured chat'},{'conversations','Whisper conversations'},{'bookmarks','Bookmarks'},{'rules','Personal rules'},{'reports','Filter feedback'},{'packs','Signed packs'},{'test','Test filter'}}) do local key,title=pair[1],pair[2];tools[#tools+1]=act('CHAT.OPEN.'..key,title,key==section and 'Selected' or '',go({page='messages',subsection=key})) end
 tools[#tools+1]=act('CHAT.FILTER','Message filters','Sender, channel, time, read state',function() O.ChatFilters(route) end)
 tools[#tools+1]=act('CHAT.SETTINGS','Chat preferences','Settings',settings('chat'));feedback(tools)
 if not ns.Modules.Enabled('chat') then table.insert(tools,1,cap('Chat is paused. Retained history and configuration remain available. Opening this page does not restart chat collection.')) end
 b[#b+1]=block('tools','Chat tools',0,0,.20,tools)
 local rows,detail={},{}
 if section=='rules' then
  rows[#rows+1]=act('CHAT.RULE.NEW','New personal rule','Add exact phrase',function() O.Rule() end)
  rows[#rows+1]=act('CHAT.EXCEPTIONS','Phrase exceptions',#ns.DB.exceptions..' saved',function() F.Value('Phrase exceptions',table.concat(ns.DB.exceptions,'\n'),function(v) local list={};for text in v:gmatch('[^\r\n]+') do list[#list+1]=text end;return ns.SetExceptions(list) end,'Add one exception per line. Normal sentence filtering still applies.',{multiline=true,limit=12000}) end)
  for _,rule in ipairs(ns.Personal.rules) do if matches(rule.phrase,route.query) then local selected=rule;rows[#rows+1]=act('CHAT.RULE.SELECT',rule.phrase,rule.action..(rule.enabled and ' · On' or ' · Off'),function() U.Open(routeTo(route,'selectedID',selected.id)) end) end end
  for _,rule in ipairs(ns.Personal.rules) do if rule.id==tonumber(route.selectedID) then local selected=rule;detail={cap(rule.phrase),act('CHAT.RULE.EDIT','Edit rule',rule.action,function() O.Rule(selected) end),act('CHAT.RULE.TOGGLE',rule.enabled and 'Pause rule' or 'Enable rule','Applies to new messages',function() F.Feedback(ns.Personal.ChangeRule(selected.id,not selected.enabled,false)) end),act('CHAT.RULE.DELETE','Delete rule','Personal rule only',function() F.Confirm('Delete personal rule?',selected.phrase,function() return ns.Personal.ChangeRule(selected.id,false,true) end) end)} end end
 elseif section=='packs' then
  rows[#rows+1]=act('CHAT.PACKS.IMPORT','Import or update pack','Verify signed envelope',O.ImportPack)
  if O.packPreview then rows[#rows+1]=act('CHAT.PACKS.REVIEW','Review verified pack',O.packPreview.title,O.ReviewPack) end
  if ns.RulePacks.Busy then rows[#rows+1]=cap(ns.RulePacks.ProgressText());rows[#rows+1]=act('CHAT.PACKS.CANCEL','Cancel verification','No installation',function() F.Feedback(ns.RulePacks.CancelImport()) end) end
  for _,pack in ipairs(ns.RulePacks.List()) do local item=pack;rows[#rows+1]=act('CHAT.PACKS.SELECT',pack.title,'v'..tostring(pack.version or '?')..(pack.stock and ' · Stock' or ' · Signed import'),go(routeTo(route,'selectedID',item.id)))
   if pack.id==route.selectedID then detail={cap(pack.description or pack.error or ''),{title='Publisher',detail=pack.author or 'Unavailable',height=35},act('CHAT.PACKS.CONFIGURE','Category sensitivity','Settings → Signed packs',settings('packs'))}
    if not pack.stock then detail[#detail+1]=act('CHAT.PACKS.EXPORT','Copy signed envelope','Original verified bytes',function() F.Copy('Signed pack envelope',ns.RulePacks.Export(item.id) or '') end);detail[#detail+1]=act('CHAT.PACKS.REMOVE','Remove imported pack','Stock categories are kept',function() F.Confirm('Remove optional pack?',item.title,function() return ns.RulePacks.Remove(item.id) end) end) end
   end
  end
  detail[#detail+1]=cap('Optional categories remain author-signed. The UI never substitutes vocabulary or bypasses verification.')
 elseif section=='report' then
  rows[#rows+1]=cap('Filter feedback is a local workflow. It is separate from a Relay bug report.')
  rows[#rows+1]=act('CHAT.REPORT.COMPOSE','Write filter feedback','Review original and expected result',function() O.FilterReport(route.reportEntry,route.reportKind,route.reportDraft) end)
 elseif section=='reports' then
  rows[#rows+1]=act('CHAT.REPORT.NEW','New filter feedback','Saved locally',function() O.FilterReport(nil,'Missed match') end)
  rows[#rows+1]=act('CHAT.REPORT.EXPORT','Select feedback to export','Privacy review',function() O.Export('reports',route.mode) end)
  for n=#ns.Personal.reports,1,-1 do local report=ns.Personal.reports[n];if (not route.mode or route.mode~='misses' or report.feedback=='Missed match') and matches(report.original,route.query) then rows[#rows+1]=act('CHAT.REPORT.OPEN','Feedback #'..report.id,report.feedback or report.expectedAction,go(routeTo(route,'selectedID',report.id))) end
   if report.id==tonumber(route.selectedID) then local item=report;detail={cap(report.original,160),{title='Expected result',detail=report.expectedAction,height=35},cap(report.note or ''),act('CHAT.REPORT.DELETE','Delete feedback','Rules stay unchanged',function() F.Confirm('Delete saved feedback?','Only this local feedback record is removed.',function() return ns.Personal.RemoveReport(item.id) end) end)} end
  end
 elseif section=='test' then
  rows[#rows+1]=act('CHAT.TEST.RUN','Analyze a phrase','No sending or collection',O.TestPhrase)
  if O.phraseResult then rows[#rows+1]=cap(O.phraseResult.text,100);rows[#rows+1]={title='Predicted action',detail=O.phraseResult.action,height=40};rows[#rows+1]=cap(O.phraseResult.preview,120)
   for _,hit in ipairs(O.phraseResult.candidates or {}) do detail[#detail+1]=cap((ns.RulePacks.Title(hit.pack) or hit.pack or 'Rule')..' · '..(hit.reason or 'Analysis')) end
  end
 elseif section=='conversations' then
  rows[#rows+1]=cap('Whispers already retained in Capture, grouped by exact normalized person and realm. Retention limits mean earlier conversation may be missing.')
  local chosen
  for _,group in ipairs(ns.ChatCapture.Conversations()) do local g=group
   if matches(g.sender,route.sender) and matches(g.sender..' '..(g.preview or ''),route.query) then rows[#rows+1]=act('CHAT.CONVERSATION.SELECT',g.sender,#g.records..' retained lines · '..C.Stamp(g.timestamp),go(routeTo(route,'conversationID',g.id))) end
   if g.id==route.conversationID then chosen=g end
  end
  if chosen then
   detail[#detail+1]={title=chosen.sender,detail=#chosen.records..' retained lines',height=45}
   O.CaptureActions(detail,chosen.records,'Conversation with '..chosen.sender)
   detail[#detail+1]=cap('Showing the newest '..math.min(50,#chosen.records)..' retained lines. Copy/export/delete use this exact person’s retained selection, not other conversations.')
   for i=math.max(1,#chosen.records-49),#chosen.records do local e=chosen.records[i];detail[#detail+1]={title=ns.Activity.DisplayName(e.sender),detail=C.Stamp(e.timestamp),height=32};detail[#detail+1]=cap(e.original,160) end
  end
 elseif section=='bookmarks' then
  rows[#rows+1]=act('CHAT.BOOKMARK.EXPORT','Export bookmarks','Privacy review',function() O.Export('bookmarks') end)
  for _,item in ipairs(ns.ChatCapture.db and ns.ChatCapture.db.bookmarks or {}) do local bookmark=item;rows[#rows+1]=act('CHAT.BOOKMARK.OPEN',item.title,C.Stamp(item.timestamp),go(routeTo(route,'selectedID',item.id)))
   if item.id==tonumber(route.selectedID) then detail={cap(item.note or ''),act('CHAT.BOOKMARK.EDIT','Edit bookmark','Local title and note',function() F.Form({title='Edit bookmark',fields={{key='title',label='Title',value=bookmark.title,limit=120},{key='note',label='Note',value=bookmark.note,multiline=true,limit=1000}},submit=function(v) return ns.ChatCapture.UpdateBookmark(bookmark.id,v.title,v.note) end}) end),act('CHAT.BOOKMARK.DELETE','Delete bookmark','Capture entries remain',function() F.Confirm('Delete bookmark?',bookmark.title,function() local present=false;for _,saved in ipairs(ns.ChatCapture.db.bookmarks) do if saved.id==bookmark.id then present=true;break end end;if not present then return false,'This bookmark is no longer available.' end;ns.ChatCapture.RemoveBookmark(bookmark.id);return true,'Bookmark deleted. Captured chat was kept.' end) end)};for _,record in ipairs(item.records) do detail[#detail+1]=cap(ns.ChatCapture.Line(record),96) end end
  end
 else
  local captures=section=='capture';local entries=captures and ns.ChatCapture.db and ns.ChatCapture.db.entries or ns.Review.entries;local chosen;local scoped={}
  rows[#rows+1]=act('CHAT.EXPORT',captures and 'Export selected chat scope' or 'Write filter feedback','Privacy review / local save',function() if captures then O.Export('capture',nil,scoped) else O.FilterReport(nil,'Missed match') end end)
  if not captures then rows[#rows+1]=act('CHAT.REVIEW.CLEAR','Clear review queue','Feedback and rules kept',function() F.Confirm('Clear all review entries?','This removes this character’s retained review queue. Saved feedback, personal rules and Chronicle history stay.',function() ns.Review.Clear();return true end) end) end
  for n=#(entries or {}),1,-1 do local item=entries[n];local unread=not item.read;local now=ns.SafeCall(GetServerTime) or 0
   if matches(item.original,route.query) and matches(item.sender,route.sender) and matches((item.channel or '')..' '..(item.event or ''),route.channel) and (not route.sourceKind or item.kind==route.sourceKind) and (not route.unread or unread) and (not route.age or route.age==0 or item.timestamp and now-item.timestamp<=tonumber(route.age)) then
    scoped[#scoped+1]=item
    local id=item.id;rows[#rows+1]=act(captures and 'CHAT.CAPTURE.SELECT' or 'CHAT.REVIEW.SELECT',ns.Activity.DisplayName(item.sender or 'Message'),C.Stamp(item.timestamp,true)..' · '..(item.action or item.channel or item.event or 'Captured'),go(routeTo(route,captures and 'captureID' or 'messageID',id)))
   end
   if item.id==(captures and tonumber(route.captureID) or tonumber(route.messageID)) then chosen=item end
  end
  if chosen then local item=chosen
   local revealed=not sensitive(item) or O.revealedID==item.id
   detail={cap(revealed and (ns.Review.DisplayOriginal(item) or item.original) or 'Original concealed locally. Choose Show original to reveal this retained entry.',180),{title='Source',detail=item.channel or item.event or item.kind or 'Manual',height=35},{title='Filter decision',detail=item.action or 'Capture only',height=35}}
   if sensitive(item) then detail[#detail+1]=act('CHAT.ORIGINAL.TOGGLE',revealed and 'Hide original' or 'Show original','Local reveal only · no network action',function() O.ToggleOriginal(route,item) end) end
   if revealed and not captures then
    detail[#detail+1]=act('CHAT.REVIEW.COPY','Copy message','Exact retained original · local copy',function() F.Copy('Selected message',ns.Review.DisplayOriginal(item) or item.original) end)
    detail[#detail+1]=act('CHAT.REVIEW.RULE','Create personal rule','Prefill only; save separately',function() O.Rule({phrase=ns.Review.DisplayOriginal(item) or item.original,action='Redacted',enabled=true}) end)
   end
   if item.filtered and (revealed or item.action~='Hidden' and item.filtered~=item.original) then detail[#detail+1]=cap(item.filtered,120) end
   if item.reason and revealed then detail[#detail+1]=cap(item.reason) end
   detail[#detail+1]=act('CHAT.REPORT.SELECTED','Report this result','Explicit local feedback',function() O.FilterReport(item,'Wrong action') end)
   if captures then
    O.CaptureActions(detail,{item},'Selected captured message')
    detail[#detail+1]=act('CHAT.CAPTURE.BOOKMARK','Bookmark conversation','Preserve nearby capture context',function() F.Form({title='Bookmark conversation',fields={{key='title',label='Title',value='Conversation with '..(item.sender or 'player'),limit=120},{key='note',label='Private note',multiline=true,limit=1000}},submit=function(v) return ns.ChatCapture.Bookmark(item.id,v.title,v.note) end}) end)
   else
    detail[#detail+1]=act('CHAT.REVIEW.READ','Mark reviewed','Filtering unchanged',function() F.Feedback(ns.Review.Mark(item.id,'reviewed')) end)
    detail[#detail+1]=act('CHAT.REVIEW.FALSE_POSITIVE','Should have stayed visible','No automatic rule learning',function() O.FilterReport(item,'False positive') end)
    if item.language then detail[#detail+1]=act('CHAT.REVIEW.LANGUAGE','Allow this language','Future language filtering only; wording rules remain',function() if ns.Language.Allow(item.language) then F.Feedback(true,'Language preference updated. Existing review entries are kept.') else ns.OpenLanguageOptions() end end) end
    if ns.Review.CanReportPlayer(item) then detail[#detail+1]=act('CHAT.REVIEW.REPORT_PLAYER','Open Blizzard player report','Review and submit in Blizzard’s interface',function() F.Feedback(ns.Review.ReportPlayer(item)) end) end
    detail[#detail+1]=act('CHAT.REVIEW.DELETE','Dismiss review entry','Remove local review evidence',function() F.Confirm('Dismiss this review entry?','Filtering rules and Chronicle history remain unchanged.',function() return ns.Review.Remove(item.id) end) end)
   end
   local guid=item.sender and ns.Athena.ResolveContact(item.sender);if guid then detail[#detail+1]=act('CHAT.PLAYER.OPEN','Player dossier',ns.Activity.DisplayName(item.sender),function() U.OpenPlayer(guid,route.owner) end) end
   detail[#detail+1]=act('CHAT.SHIELD.OPEN','Manage contact protection','Shield',function() ns.OpenShieldPlayer(item.sender) end)
  elseif route.activityID then local item=ns.Activity.Get(route.activityID);if item then detail={cap(item.preview,140),{title='Sender',detail=ns.Activity.DisplayName(item.sender),height=40},act('CHAT.NOTIFICATION.SOURCE','Related player','Open dossier when identifiable',function() local guid=ns.Athena.ResolveContact(item.sender);if guid then U.OpenPlayer(guid,route.owner) end end)} end end
 end
 if #detail==0 then detail[1]=cap('Choose an entry for its details and available actions.') end
 b[#b+1]=block('content',({rules='Personal rules',packs='Signed packs',reports='Filter feedback',test='Test filter',bookmarks='Bookmarks',capture='Captured chat',conversations='Whisper conversations'})[section] or 'Review queue',.20,0,.46,paginate(rows,route,'CHAT'))
 b[#b+1]=block('selection','Selected entry',.66,0,.34,detail)
 return b
end
function O.ShieldAdd(name)
 return F.Form({title='Protect against unwanted contact',help='Temporary, session and permanent shields use the same existing contact validator. Allowed players bypass Shield. Filtering settings stay independent.',fields={{key='name',label='Player name (include realm when needed)',value=name or '',limit=128},{key='duration',label='Duration',value=900,choices={{300,'5 minutes'},{900,'15 minutes'},{1800,'30 minutes'},{3600,'1 hour'},{86400,'1 day'},{0,'Permanent'},{'session','This session'}}},{key='reason',label='Private reason',value='Manually shielded',limit=160}},submit=function(v) return ns.Shield.Add(v.name,v.duration,v.reason) end})
end
function O.Shield(route)
 local tools={act('SHIELD.ADD','Add shield','Choose player and duration',function() O.ShieldAdd(route.contact) end),act('SHIELD.ALLOW','Allow player','Bypass contact protection',function() F.Value('Allow player','',ns.Shield.Allow,'Adding a player to Allowed removes their current shield. Word filters remain independent.',{limit=128}) end),act('SHIELD.EXPORT','Export active shields','Select and review privacy',function() O.Export('shield') end),act('SHIELD.SETTINGS','Protection rules','Settings',settings('protections')),act('SHIELD.SPAM','Spam and rapid chat','Settings',settings('spam'))};feedback(tools)
 table.insert(tools,1,act('SHIELD.SEARCH','Find contact',route.query~='' and route.query or 'Names and realms',function()
  F.Value('Find protected or allowed contact',route.query or '',function(value)
   local nextRoute=routeTo(route,'query',value);nextRoute.listPage=1;nextRoute.selectedID=nil;nextRoute.contact=nil;U.Open(nextRoute,true);return true
  end,'Search active shields and allowed contacts by name or realm. Existing contacts are kept.',{limit=128})
 end))
 local rows,detail={},{}
 if not ns.Modules.Enabled('shield') then table.insert(tools,1,cap('Shield is paused. Saved contacts are kept; this page does not restart protection.')) end
 for _,contact in ipairs(ns.Shield.List()) do if matches(contact.name,route.query) then local item=contact;rows[#rows+1]=act('SHIELD.SELECT',contact.name,contact.session and 'This session' or contact.expires==0 and 'Permanent' or 'Until '..C.Stamp(contact.expires),go(routeTo(route,'selectedID',contact.key)))
  if route.selectedID==contact.key then detail={cap(contact.reason or 'Protected contact'),{title='Protection',detail=contact.session and 'Session' or contact.expires==0 and 'Permanent' or C.Stamp(contact.expires),height=40},act('SHIELD.REMOVE','Remove shield','Contact can resume',function() F.Feedback(ns.Shield.Remove(item.name)) end),act('SHIELD.ALLOW.SELECTED','Allow this player','Remove shield and bypass protection',function() F.Confirm('Allow '..item.name..'?','Their current shield is removed. Ordinary word filtering still applies.',function() return ns.Shield.Allow(item.name) end) end)} end
 end end
 for key,name in pairs(ns.DB.shield.allowed) do if matches(name,route.query) then local identity,display=key,name;rows[#rows+1]=act('SHIELD.SELECT.ALLOWED',name,'Allowed',go(routeTo(route,'selectedID',identity)))
  if key==route.selectedID then detail={cap('This player bypasses Shield. Ordinary word filters still apply.'),act('SHIELD.UNALLOW','Remove from Allowed',display,function() ns.Shield.Unallow(display);F.Feedback(true,'Removed from Allowed. No shield was added.') end)} end
 end end
 local contact=route.contact;for _,entry in ipairs(ns.Shield.List()) do if entry.key==route.selectedID then contact=entry.name end end;contact=contact or ns.DB.shield.allowed[route.selectedID]
 if contact then local guid=ns.Athena.ResolveContact(contact)
  if #detail==0 then detail[1]=cap('No active shield or allow entry for '..contact..'. Expired shields are not retained as active protection.');detail[#detail+1]=act('SHIELD.ADD.SELECTED','Add shield',contact,function() O.ShieldAdd(contact) end) end
  local remaining=ns.Spam.PauseRemaining(contact);if remaining and remaining>0 then detail[#detail+1]={title='Rapid chat pause',detail=math.ceil(remaining)..' seconds remaining',height=40} end
  if guid then detail[#detail+1]=act('SHIELD.PLAYER','Player dossier','Open this person’s profile',function() U.OpenPlayer(guid,route.owner) end) end
  detail[#detail+1]=act('SHIELD.CHAT','Related messages','Search retained sender',go({page='messages',subsection='capture',sender=contact}))
 end
 if #rows==0 then rows[1]=cap('No active shields or allowed contacts match this search.') end
 if #detail==0 then detail[1]=cap('Select a contact or add a shield. Saved contact protection remains available independently of Chat.') end
 local alerts={};for _,alert in ipairs(ns.Shield.alerts) do alerts[#alerts+1]=act('SHIELD.ALERT',alert.name or 'Protection',alert.kind..' · '..C.Stamp(alert.timestamp,true),function() ns.OpenShieldPlayer(alert.name) end);if #alerts>=12 then break end end
 local bottom=44;for _,item in ipairs(tools) do bottom=bottom+(item.height or 31) end
 local first=block('tools','Shield actions',0,0,.23,tools);bottom=44;for _,item in ipairs(tools) do bottom=bottom+(item.height or 31) end
 return {first,block('contacts','Contacts',.23,0,.43,paginate(rows,route,'SHIELD')),block('selection','Selected contact',.66,0,.34,detail),block('alerts','Recent protection alerts',0,bottom+16,.23,alerts)}
end
function O.MentionPhrase(phrase)
 local channels={{'all','All selected channels'}};for _,id in ipairs({'general','trade','lfg','other','say','yell','guild','party','raid','whispers'}) do channels[#channels+1]={id,id} end
 return F.Form({title=phrase and 'Edit watched phrase' or 'Watch a phrase',fields={{key='text',label='Phrase',value=phrase and phrase.text,limit=120},{key='kind',label='Kind',value=phrase and phrase.kind or 'phrase',choices={{'phrase','Phrase'},{'nickname','Nickname'}}},{key='channel',label='Channel',value=phrase and phrase.channel or 'all',choices=channels}},submit=function(v) return ns.Mentions.Save(v.text,v.kind,phrase and phrase.id,v.channel) end})
end
function O.Signal(route)
 local visible={};local now=ns.SafeCall(GetServerTime) or 0
 local category=route.category~='all' and route.category or nil
 for _,item in ipairs(ns.Activity.List(category)) do
  if matches((item.sender or '')..' '..(item.preview or ''),route.query) and (not route.unread or ns.Activity.EntryUnread(item,category)) and (not route.age or route.age==0 or item.timestamp and now-item.timestamp<=route.age) then visible[#visible+1]=item end
 end
 local tools={};for _,pair in ipairs({{'all','All notifications'},{'mentions','Mentions'},{'wanted','Wanted sightings'},{'olympusmute','Olympus sharing'},{'messages','Filtered messages'},{'shield','Protection alerts'},{'athena','Athena activity'}}) do local key,title=pair[1],pair[2];tools[#tools+1]=act('SIGNAL.FILTER.'..key,title,(route.category or 'all')==key and 'Selected' or '',go(routeTo(route,'category',key))) end
 tools[#tools+1]=act('SIGNAL.UNREAD','Unread only',route.unread and 'On' or 'Off',go(routeTo(route,'unread',not route.unread)))
 tools[#tools+1]=F.Row('SIGNAL.AGE','Notification time scope',function() return route.age or 0 end,function(v) U.Open(routeTo(route,'age',v),true);return true end,{choices={{0,'All retained'},{3600,'Last hour'},{86400,'Last day'},{604800,'Last week'}}})
 tools[#tools+1]=act('SIGNAL.MARKALL','Mark visible notifications read','Same state as the bell',function() for _,item in ipairs(visible) do ns.Activity.Mark(item.id,category) end;F.Feedback(true,'Marked visible notifications read.') end)
 tools[#tools+1]=act('SIGNAL.SETTINGS','Alert preferences','Settings',settings('notifications'));feedback(tools)
 if not ns.Modules.Enabled('alerts') then table.insert(tools,1,cap('Signal is paused. These are retained notifications; opening this page does not restart alerts. Chat and Shield remain independent.')) end
 local rows,detail={},{}
 for _,item in ipairs(visible) do local id=item.id
  rows[#rows+1]=act('SIGNAL.SELECT',ns.Activity.DisplayName(item.sender or 'Olympus'),C.Stamp(item.timestamp)..(ns.Activity.EntryUnread(item) and ' · Unread' or ''),go(routeTo(route,'selectedID',id)))
 if item.id==route.selectedID then local id=item.id;detail={cap(O.SignalHighlighted(item),120),act('SIGNAL.COPY','Copy visible alert','Safe preview only · does not mark read',function() F.Copy('Selected Signal alert',O.SignalText(item)) end),act('SIGNAL.SOURCE','Open source','Exact message, person or adventure',function() F.Feedback(ns.UI2NotificationCenter.OpenSource(id)) end),act('SIGNAL.READ','Mark read','Updates the shared bell immediately',function() F.Feedback(ns.Activity.Mark(id)) end),act('SIGNAL.DISMISS','Dismiss notification','Source evidence is kept',function() F.Feedback(ns.Activity.Remove(id)) end)}
  local captured=O.SignalCapture(item)
  if captured then detail[#detail+1]=act('SIGNAL.BOOKMARK','Bookmark retained context','Exact captured line and nearby context',function()
   local current=O.SignalCapture(item);if current~=captured then return F.Feedback(false,'Captured source is no longer available.') end
   F.Form({title='Bookmark Signal context',fields={{key='title',label='Title',value='Signal from '..(item.sender or 'player'),limit=120},{key='note',label='Private note',multiline=true,limit=1000}},submit=function(v) if O.SignalCapture(item)~=captured then return false,'Source changed; nothing saved.' end;return ns.ChatCapture.Bookmark(captured.id,v.title,v.note) end})
  end) end
  if item.mentionMatches and #item.mentionMatches>0 then detail[#detail+1]=act('SIGNAL.MUTE.MATCHES','Mute matched watch phrases','Only matching IDs that still have the same wording',function() F.Feedback(O.MuteMatches(item)) end) end
  if item.wanted then detail[#detail+1]=act('SIGNAL.OLYMPUS','Open Olympus','Official guild addon · no new lookup',function() local ok,why=ns.OlympusIntegration.Open();F.Feedback(ok,why) end) end
  if item.categories.olympusmute then local observation=ns.OlympusMuteSignal.Observation(item.sender)
   detail[#detail+1]=cap('A complete compatible sharing payload was observed on '..(item.channel or 'an allowed channel')..'. The shared list was discarded and never imported. This does not prove addon installation or a mute action.',180)
   detail[#detail+1]=cap(observation and observation.source..' · '..C.Stamp(observation.at)..'. '..observation.limits or 'No retained sender observation is available. Absence means Unknown.',180)
   detail[#detail+1]=act('SIGNAL.OLYMPUSMUTE.SETTINGS','Sharing observation preferences','Signal settings · passive observation and optional tooltip',settings('notifications'))
  end
 end
 end
 if #rows==0 then rows[1]=cap('No retained notifications in this scope.') end
 if #detail==0 then detail[1]=cap('Choose a notification. Hidden-message previews stay hidden. No remote lookup or presence probe runs when this page opens.') end
 local phrases={act('SIGNAL.PHRASE.ADD','Watch a phrase','Mention or nickname',function() O.MentionPhrase() end)}
 for _,phrase in ipairs(ns.Mentions.db and ns.Mentions.db.phrases or {}) do local item=phrase;phrases[#phrases+1]=act('SIGNAL.PHRASE.EDIT',phrase.text,phrase.enabled and 'Enabled · edit' or 'Paused · edit',function() O.MentionPhrase(item) end);phrases[#phrases+1]=act('SIGNAL.PHRASE.TOGGLE',phrase.enabled and 'Pause phrase' or 'Enable phrase',phrase.text,function() F.Feedback(ns.Mentions.Change(item.id,not item.enabled,false)) end);phrases[#phrases+1]=act('SIGNAL.PHRASE.DELETE','Remove phrase',phrase.text,function() F.Confirm('Remove watched phrase?',item.text,function() return ns.Mentions.Change(item.id,false,true) end) end) end
 local bottom=44;for _,item in ipairs(detail) do bottom=bottom+(item.height or 31) end
 local selected=block('selection','Selected notification',.66,0,.34,detail);bottom=44;for _,item in ipairs(detail) do bottom=bottom+(item.height or 31) end
 return {block('filters','Signal filters',0,0,.23,tools),block('history','Notification history',.23,0,.43,paginate(rows,route,'SIGNAL')),selected,block('phrases','Watched phrases',.66,bottom+12,.34,paginate(phrases,route,'SIGNAL.PHRASES'))}
end
function O.EditRelay(report)
 local R=ns.RelayStore
 if not report or report.state~='draft' then return F.Feedback(false,'Only an unfinished draft can be edited.') end
 return F.Form({title='Bug report · local draft',draftKey='relay/'..report.id,help='Text is saved to this same draft as you edit. Closing or switching pages never submits it. Chat, history and private notes are excluded from optional diagnostics.',fields={{key='module',label='Affected module',value=report.fields.module,choices=R.modules},{key='category',label='Problem category',value=report.fields.category,choices=R.categories},{key='title',label='Short title',value=report.fields.title,limit=96},{key='description',label='What happened?',value=report.fields.description,multiline=true,height=130,limit=3000},{key='steps',label='Steps to reproduce',value=report.fields.steps,multiline=true,height=90,limit=1600}},changed=function(v) return R.Save(report.id,v) end,submitLabel='Save draft',submit=function(v) local ok,why=R.Save(report.id,v);if ok then U.Open({page='relay',selectedID=report.id}) end;return ok,why or 'Draft saved. Nothing was sent.' end})
end
function O.PreviewRelay(report)
 local R,D=ns.RelayStore,ns.RelayDiagnostics
 local diagnostics=O.relayDiagnostics and O.relayDiagnostics[report.id] or ''
 local wire,why=R.Encode(R.Payload(report,diagnostics));if not wire then return F.Feedback(false,why) end
 O.relayPreview={id=report.id,wire=wire,diagnostics=diagnostics}
 local recipients=report.selfTestReceiver and ('this developer character ('..report.selfTestReceiver..')') or table.concat(ns.RelayTransport.receivers,', ')
 local f=F.Form({title='Review bug report before submission',help='The report and your character name go to '..recipients..'. Delivery remains subject to the existing realm, access and transport gates.',paragraphs={report.fields.title,report.fields.description,report.fields.steps,diagnostics~='' and diagnostics or 'Technical details are excluded.'},fields={{key='review',label='Review statement',value=false,choices={{false,'I have not finished reviewing'},{true,'I reviewed this exact report and recipient policy'}}}},submitLabel='Submit reviewed report',submit=function(v)
  local reviewed=O.relayPreview
  if not v.review or not reviewed or reviewed.id~=report.id or R.Encode(R.Payload(report,reviewed.diagnostics))~=reviewed.wire then return false,'Review this exact report before submitting.' end
  local ok,err=R.Submit(report.id,reviewed.diagnostics)
  if ok then O.relayPreview=nil;U.Open({page='relay',selectedID=report.id}) end;return ok,err or 'Report queued. A final matching receipt is required before it is shown as delivered.'
 end})
 C.Button(f,'Read report text',function() F.Copy('Report and technical details',R.Export(report,false)..'\n\nReviewed diagnostics:\n'..diagnostics);O.relayPreview=nil end,180):SetPoint('BOTTOMLEFT',230,18)
 return f
end
function O.ShareHistorical(model,row,family)
 local snapshot,why=ns.AthenaSharePolicy.HistoricalSnapshot(model.owner,model.key,model.identity.realm,row,model.loadoutIndex and model.loadoutIndex.objects)
 if not snapshot then return F.Feedback(false,why) end
 return F.Form({title='Share selected historical capture',help='Choose one exact recipient. The next Relay page reviews this capture only; nothing is sent here. Live delivery requires an approved identity/transport adapter.',
 fields={{key='guid',label='Recipient character GUID',value='',limit=96},{key='name',label='Recipient name',value='',limit=128},{key='realm',label='Recipient realm',value='',limit=128}},
 submitLabel='Review in Relay',submit=function(v)
  if not ns.ChronicleStore.GUID(v.guid) or not ns.Athena2.Text(v.name,128) or not ns.Athena2.Text(v.realm,128) then return false,'An exact recipient GUID, name and realm are required.' end
  local client=ns.RelayDirectShare.Current
  if not client or not client.options.mockTransport and (not client.nativeDirect or not client.nativeDirect.enabled or client.nativeDirect.peer.guid~=v.guid) then
   local why;client,why=ns.DirectNative.Create(v,true);if not client then return false,why end
  end
  return O.DirectReview(client,{kind='historical',snapshot=snapshot},{guid=v.guid,name=v.name,realm=v.realm})
 end})
end
function O.DirectReview(client,profile,recipient)
 if not client or not profile or not recipient or not ns.ChronicleStore.GUID(recipient.guid) then return false,'A resolved subject and exact recipient are required.' end
 local old=O.direct;local previous=old and old.offerID and old.client.outbox[old.offerID]
 if previous and previous.state=='REVIEW' then old.client.outbox[old.offerID]=nil end
 O.direct={client=client,profile=profile,recipient=recipient,scope=profile.kind=='historical' and 'historical' or profile.kind=='event' and 'event' or 'identity'}
 return U.Open({page='relay',subsection='direct'})
end
local function directCardRows(projection)
 local rows={};local card=projection and ns.AthenaSharePolicy.ValidateDirect(projection,projection.recipient)
 if not card then return {cap('No validated public fields are available for this offer.')} end
 if card.snapshot then
  local s=card.snapshot;local decoded=ns.ChronicleBackup.DecodeChunk(s.captureWire);local cap=decoded and decoded[1]
  rows[#rows+1]={title='Selected historical '..s.family,detail=C.Stamp(s.observedAt)..' · '..s.realm,height=44}
  rows[#rows+1]={title='Observer and source',detail=ns.WardenUI.OwnerName(s.observerOwner)..' · '..s.source,height=44}
  rows[#rows+1]=cap and {title='Scope',detail='One recorded capture · '..#s.dependencies..' layout dependencies',height=40} or {title='Capture could not be decoded',height=40}
  rows[#rows+1]={title='Received snapshots remain peer-provided history. They never become firsthand observations or public Aether data.',wrap=true,height=64,kind='caption'}
  if cap and cap.family=='gear' then for _,slot in ipairs(ns.WardenDossier.slots) do local v=ns.WardenDossier.Slot({object={capture=cap}},slot[1]);rows[#rows+1]={title=slot[2],detail=v[3]~=false and ('Item #'..v[3]) or v[2]=='empty' and 'Confirmed empty' or 'Not observed',height=34} end
  elseif cap and cap.values.exportString then rows[#rows+1]=act('DIRECT.HISTORY.EXPORT','Copy recorded talent export','Original captured string',function() F.Copy('Selected historical export',cap.values.exportString) end) end
  return rows
 end
 card=card.card
 for _,pair in ipairs({{'name','Character'},{'realm','Realm'},{'class','Class'},{'race','Race'},{'faction','Faction'},{'levelBand','Recorded level band'},{'guild','Recorded guild'},{'activityType','Activity'},{'mapName','Place'},{'outcome','Outcome'},{'coverage','Coverage'}}) do
  if card[pair[1]] then rows[#rows+1]={title=pair[2],detail=tostring(card[pair[1]]),height=40} end
 end
 local zone=card.declaration and ns.PlayerCard.zones[card.declaration.gamerzone]
 if zone then rows[#rows+1]={title='Owner-selected Gamerzone',detail=zone.title,height=40} end
 if card.rating then rows[#rows+1]={title='Community opinions',detail=(card.rating.average and tostring(card.rating.average)..' / 5' or 'Not rated')..' · '..card.rating.count..' ratings',height=40} end
 if card.pvp then for _,pair in ipairs({{'matchCount','Observed matches'},{'killingBlows','Killing blows'},{'deaths','Deaths'},{'damageDone','Damage'},{'healingDone','Healing'}}) do if card.pvp[pair[1]]~=nil then rows[#rows+1]={title=pair[2],detail=C.Number(card.pvp[pair[1]]),height=38} end end;rows[#rows+1]=cap(card.pvp.coverage) end
 return rows
end
function O.CommunityConcern(subjectType,key,post,kind)
 if not ns.Permissions.Decide('UIAccess') or type(post)~='table' or not ns.AetherNet.Subject(subjectType,key) then return false,'Exact community source required.' end
 local source=table.concat({'Context: '..tostring(kind),'Subject: '..subjectType..'/'..key,'Record: '..tostring(post.id),'Author: '..tostring(post.author),'Author name: '..tostring(post.authorName or post.author),'Quoted content:',tostring(post.text or '')},'\n')
 return F.Form({title='Save a community content concern',help='Creates a private, unsent Relay draft for your review. This does not report to Blizzard, notify a moderator, hide content or change another player’s rating. Any later Relay submission is a separate explicit action.',
  paragraphs={source},fields={{key='note',label='What concerns you about this content?',value='',limit=1200,multiline=true,height=100}},submitLabel='Save unsent Relay draft',submit=function(v)
   local R=ns.RelayStore;local draft,why=R.New();if not draft then return false,why end
   local ok,err=R.Save(draft.id,{module='intel',category='other',title='Community content concern',description=source:sub(1,1700)..'\n\nConcern: '..(v.note or ''),steps='Saved on this computer from '..subjectType..' page. No moderation or network submission performed.'})
   if not ok then R.Delete(draft.id);return false,err end
   U.Open({page='relay',selectedID=draft.id});return true,'Unsent Relay draft saved. Review it before deciding whether to submit.'
  end})
end
function O.RelayFilters(route)
 local R=ns.RelayStore;local modules={{false,'All modules'}};for _,pair in ipairs(R.modules) do modules[#modules+1]=pair end
 local categories={{false,'All problem categories'}};for _,pair in ipairs(R.categories) do categories[#categories+1]=pair end
 local statuses=route.subsection=='inbox' and {{'all','All statuses'},{'New','New'},{'Reviewing','Reviewing'},{'Confirmed','Confirmed'},{'Fixed','Fixed'},{'Closed','Closed'}} or {{'all','All statuses'},{'draft','Unfinished drafts'},{'pending','Waiting for delivery'},{'sending','Sending'},{'received','Delivered'},{'attention','Needs attention'},{'failed','Failed'}}
 return F.Form({title='Filter saved reports',fields={{key='query',label='Title, description, sender or report ID',value=route.query or '',limit=256},{key='status',label='Delivery or review status',value=route.status or 'all',choices=statuses},{key='reportModule',label='Affected module',value=route.reportModule or false,choices=modules},{key='reportCategory',label='Problem category',value=route.reportCategory or false,choices=categories},{key='reportVersion',label='Version contains',value=route.reportVersion or '',limit=48}},submit=function(v)
  local nextRoute=copy(route);for key,value in pairs(v) do nextRoute[key]=value end;nextRoute.selectedID=nil;nextRoute.listPage=1;nextRoute.scroll=0;U.Open(nextRoute,true);return true
 end})
end
local relayStates={draft='Unfinished draft',pending='Waiting for delivery',sending='Sending',received='Delivered',failed='Needs attention'}
local function relayState(report) return report.state=='pending' and report.autoRetry==false and 'Delivery paused' or relayStates[report.state] or report.state end
function O.RelayMatches(report,data,route)
 local inbox=route.subsection=='inbox';local state=route.status
 local status=not state or state=='all' or state==report.state and (inbox or state~='pending' or report.autoRetry~=false) or not inbox and state=='attention' and (report.state=='failed' or report.state=='pending' and report.autoRetry==false)
 return data and status and matches(table.concat({data.title or '',data.description or '',report.sender or '',report.id or report.key or ''},' '),route.query) and (not route.reportModule or route.reportModule==data.module) and (not route.reportCategory or route.reportCategory==data.category) and matches(data.version or ns.VERSION,route.reportVersion)
end
function O.Relay(route)
 local R,P=ns.RelayStore,ns.RelayTransport
 local directTools={act('DIRECT.NATIVE.APPROVE','Approve Direct Share contact','One current group member · this session only',function() ns.DirectNative.Listen() end),act('DIRECT.NATIVE.STOP','Stop Direct Share session','Cancel unsent frames and pending receipt retries',function() ns.DirectNative.Stop();F.Feedback(true,'Direct Share stopped. Previously delivered data cannot be recalled.') end)}
 local tools={act('RELAY.NEW','Report a bug','Create a local draft',function() local r,why=R.New();if r then U.Open({page='relay',selectedID=r.id});O.EditRelay(r) else F.Feedback(false,why) end end),act('RELAY.MINE','My reports','Drafts and delivery states',go({page='relay'})),act('RELAY.DIRECT','Direct Share','Exact addressed preview',go({page='relay',subsection='direct'})),act('RELAY.AETHER','Aether participation','Consent and public fields',go({page='relay',subsection='aether'}))}
 for _,item in ipairs(directTools) do tools[#tools+1]=item end
 local dc=ns.DirectNative.active and ns.DirectNative.active.client
 if dc then for id,offer in pairs(dc.inbox) do if offer.expiresAt>ns.RelayStore.Now() then local request=id;tools[#tools+1]=act('DIRECT.NATIVE.OFFER.'..id,'Review addressed offer',offer.sender,function() ns.AthenaSuiteUI.DirectInbox(dc,request) end) end end end
 
 tools[#tools+1]=act('RELAY.FILTERS','Filter saved reports','Status, module, category and version',function() O.RelayFilters(route) end)
 tools[#tools+1]=act('RELAY.DIAGNOSTICS','Technical details','Review before attachment',go({page='relay',subsection='diagnostics'}));feedback(tools)
 table.insert(tools,1,act('AETHER.PROFILES','Player profiles','Athena intelligence and community · same player dossier',go({page='intel',owner=route.owner})))
 local rows,detail={},{}
 if R.blocked then rows[1]=cap(R.blocked)
 elseif route.subsection=='aether' then
  rows=ns.UI2Settings.Rows('aether');detail={cap('Existing Aether consent and privacy controls. Drafts never publish automatically.'),act('AETHER.OWN','My Aether Profile','Same complete player profile',function() U.OpenAetherProfile() end)}
 elseif route.subsection=='diagnostics' then
  rows[1]=cap('Optional troubleshooting details include your version, feature status and recent error locations. They exclude chat, adventures and private notes. You can preview them before sharing; preparing them sends nothing.')
  rows[2]=act('RELAY.DIAGNOSTICS.PREVIEW','Preview troubleshooting details','No attachment or submission yet',function() F.Copy('Technical details preview',ns.RelayDiagnostics.Prepare()) end)
 elseif route.subsection=='direct' then
  local d=O.direct
  if not d then rows[1]=cap('Choose a player’s Share card to review exactly what you want to send. Sharing through this connection is not available yet.');rows[2]=act('RELAY.PUBLIC','Preview my share card','Open this player’s profile',function() U.OpenPlayer(ns.PlayerCard.Own(),route.owner,'public') end)
  else
   rows[1]={title='To '..(d.recipient.name or d.recipient.guid),detail=d.recipient.realm or '',height=40}
   rows[2]=F.Row('DIRECT.SCOPE','Shared scope',function() return d.scope end,function(v) local old=d.offerID and d.client.outbox[d.offerID];if old and old.state=='REVIEW' then d.client.outbox[d.offerID]=nil end;d.scope=v;d.offerID=nil;d.wire=nil;return true end,{choices=d.profile.kind=='historical' and {{'historical','This selected historical capture'}} or d.profile.kind=='event' and {{'event','Event card'}} or {{'identity','Identity only'},{'career','Supported career summary'}}})
   rows[3]=cap('Private notes, conversations, exact movements and raw named scoreboards are excluded. Direct Share does not enroll you in Aether.')
   rows[4]=act('DIRECT.PREVIEW','Prepare addressed offer','Local review only',function()
    local projection,why=ns.AthenaSharePolicy.ProjectDirect(d.profile,d.recipient.guid,d.scope);if not projection then return F.Feedback(false,why) end
    local old=d.offerID and d.client.outbox[d.offerID];if old and old.state=='REVIEW' then d.client.outbox[d.offerID]=nil end
    local id,wire=d.client:PreviewDirect(d.recipient.guid,projection);if not id then return F.Feedback(false,wire or 'This offer could not be prepared.') end;d.offerID=id;d.wire=wire
    -- Render the prepared state before opening its copy dialog. Closing a
    -- read-only preview does not submit a form or trigger a page refresh.
    U.Refresh(true);F.Copy('Exact addressed offer',wire);return true
   end)
   local offer=d.offerID and d.client.outbox[d.offerID]
   detail[1]=cap(d.client.options.mockTransport and 'ISOLATED MOCK TRANSPORT · no game or Bridge delivery' or d.client.options.nativeTransport and 'Early access · one recipient · current group contact · WoW may log these messages' or 'This connection is unavailable')
   detail[2]={title='Offer state',detail=offer and offer.state or 'Not sent',height=40}
   if offer then
    for _,row in ipairs(directCardRows(offer.packet.body.projection)) do detail[#detail+1]=row end
    if offer.state=='REVIEW' then
     if d.client.options.mockTransport or d.client.options.nativeTransport then detail[#detail+1]=act('DIRECT.SEND','Send reviewed offer','Explicit addressed delivery',function() F.Confirm('Send this exact offer?',d.recipient.name or d.recipient.guid,function() return d.client:SendDirect(d.offerID,d.wire,true) end) end) end
     detail[#detail+1]=act('DIRECT.CANCEL','Cancel unsent offer','Delivered messages cannot be recalled',function() local current=d.offerID and d.client.outbox[d.offerID];if current and current.state=='REVIEW' then d.client.outbox[d.offerID]=nil end;d.offerID=nil;d.wire=nil;F.Feedback(true,'Unsent offer cleared.') end)
    end
   end
  end
 elseif route.subsection=='direct-inbox' then
  local d=O.directInbox;local offer=d and d.client.inbox[d.id]
  if offer then
   rows[1]=cap('Offer from '..offer.sender);rows[2]=cap(offer.received and 'Received · final receipt returned' or offer.decision or 'Waiting for your review')
   detail=directCardRows(offer.body.projection)
   if not offer.decision then
    rows[#rows+1]=act('DIRECT.INBOX.ACCEPT','Accept reviewed data','This addressed offer only',function() F.Confirm('Accept addressed public data?','Information received from others stays separate from your own recorded adventures.',function() return d.client:Decide(d.id,true,true) end) end)
    rows[#rows+1]=act('DIRECT.INBOX.DECLINE','Decline offer','Your adventure history is unchanged',function() F.Feedback(d.client:Decide(d.id,false,true)) end)
   end
   local card=offer.body.projection and offer.body.projection.card
   if offer.received and card and card.kind=='player' then detail[#detail+1]=act('DIRECT.INBOX.PLAYER','Open player dossier','The same player profile; shared information keeps its source',function() U.OpenPlayer(card.personKey,route.owner) end) end
  else rows[1]=cap('This addressed offer is unavailable or expired.') end
 else
  local inbox=route.subsection=='inbox'
  if inbox and not P.IsDeveloper() then rows[1]=cap('The developer inbox is not authorized for this character.')
  else
   for n=#(R.db and (inbox and R.db.inbox or R.db.reports) or {}),1,-1 do
    local report=(inbox and R.db.inbox or R.db.reports)[n];local data=report.wire and R.Decode(report.wire) or report.fields;local id=inbox and report.key or report.id
    if O.RelayMatches(report,data,route) then rows[#rows+1]=act('RELAY.SELECT',data.title~='' and data.title or 'Untitled draft',relayState(report)..' · '..C.Stamp(report.created or report.received or report.receivedAt),go(routeTo(route,'selectedID',id))) end
    if id==route.selectedID and data then local selected=report
     detail={cap(data.title),{title='State',detail=relayState(report),height=40},cap(report.status),cap(data.description,160),cap(data.steps,110),act('RELAY.EXPORT','Copy report','Review identifying details',function() F.Copy('Bug report',R.Export(selected,inbox)) end)}
     local module=data.module;for _,pair in ipairs(R.modules) do if pair[1]==module then module=pair[2] end end
     detail[#detail+1]={title='Affected module',detail=module,height=40};detail[#detail+1]={title='Version',detail=data.version or ns.VERSION,height=40}
     for _,field in ipairs({{'created','Created'},{'submitted','Submitted'},{'lastAttempt','Last delivery attempt'},{'nextAttempt','Next scheduled retry'},{'receivedAt','Final receipt'}}) do if report[field[1]] then detail[#detail+1]={title=field[2],detail=C.Stamp(report[field[1]]),height=40} end end
     if report.attempts~=nil then detail[#detail+1]={title='Delivery attempts',detail=tostring(report.attempts),height=40} end
     if inbox and report.sender then detail[#detail+1]={title='Submitted by',detail=report.sender,height=40} end
     if inbox then
      detail[#detail+1]=F.Row('RELAY.INBOX.STATE','Developer review state',function() return selected.state end,function(v) return R.SetInboxState(selected.key,v) end,{choices={{'New','New'},{'Reviewing','Reviewing'},{'Confirmed','Confirmed'},{'Fixed','Fixed'},{'Closed','Closed'}}})
     elseif report.state=='draft' then
      detail[#detail+1]=act('RELAY.EDIT','Continue draft','Same saved report ID',function() O.EditRelay(selected) end)
      detail[#detail+1]=act('RELAY.DIAGNOSTICS.ATTACH','Technical details','Review optional attachment',function()
       O.relayDiagnostics=O.relayDiagnostics or {};local text=ns.RelayDiagnostics.Prepare()
       local f=F.Copy('Optional report diagnostics',text,'Only this allowlisted text is attached if you choose Include. Chat, history, private notes and dossiers are excluded.')
       C.Button(f,'Include these details',function() O.relayDiagnostics[selected.id]=text;f:Hide();F.Feedback(true,'Technical details selected. Report remains a draft.') end,220):SetPoint('BOTTOMLEFT',20,18)
       C.Button(f,'Exclude details',function() O.relayDiagnostics[selected.id]='';f:Hide();F.Feedback(true,'Technical details excluded.') end,180):SetPoint('BOTTOMLEFT',250,18)
      end)
      detail[#detail+1]=act('RELAY.SUBMIT.PREVIEW','Review and submit','Separate explicit confirmation',function() O.PreviewRelay(selected) end)
     else
      detail[#detail+1]=act('RELAY.COPY.DRAFT','Duplicate as draft','Original submission kept',function() local draft,why=R.Copy(selected.id);if draft then U.Open({page='relay',selectedID=draft.id});O.EditRelay(draft) else F.Feedback(false,why) end end)
      if report.state=='pending' or report.state=='sending' then detail[#detail+1]=act('RELAY.AUTOMATIC',report.autoRetry and 'Pause delivery' or 'Resume delivery','User-controlled retry',function() F.Confirm(report.autoRetry and 'Pause report delivery?' or 'Resume report delivery?','Only this already-submitted report changes. Its saved content remains.',function() return P.SetAutomatic(selected.id,not selected.autoRetry) end) end) end
      if report.state=='pending' or report.state=='failed' then detail[#detail+1]=act('RELAY.RETRY','Retry now','Existing receiver and permission checks',function() F.Confirm('Retry submitted report?','The same reviewed payload is offered to the configured developer receiver.',function() return P.Try(selected.id) end) end) end
     end
     detail[#detail+1]=act('RELAY.DELETE','Delete local report','Permanent removal',function() F.Confirm('Delete this local report?','Copy it first if needed. Active transfers must finish or be paused before deletion.',function() return R.Delete(inbox and selected.key or selected.id,inbox) end) end)
    end
   end
  end
 end
 if #rows==0 then rows[1]=cap('No reports in this scope. Start a report to create a local draft. Opening Relay sends nothing.') end
 if #detail==0 then detail[1]=cap('Choose a saved report. A draft, queued report and final delivery receipt are distinct states. Live Aether Bridge transport remains pending.') end
 return {block('tools','Aether & Relay actions',0,0,.22,tools),block('content',route.subsection=='inbox' and 'Developer inbox' or route.subsection=='direct' and 'Direct Share' or route.subsection=='aether' and 'Aether participation & privacy' or 'Local reports',.22,0,.40,paginate(rows,route,'RELAY')),block('selection','Details & actions',.62,0,.38,detail)}
end
local oldService=L.Service
function L.Service(route)
 if route.page=='shield' then return O.Shield(route) elseif route.page=='mentions' then return O.Signal(route) elseif route.page=='relay' and O.Relay then return O.Relay(route) end
 return oldService(route)
end
-- Legacy integration entry points now land on these new components.
ns.PhraseTester.Open=O.TestPhrase
ns.OpenReport=function(entry,kind,draft) local ok=U.Open({page='messages',subsection='report',reportEntry=entry,reportKind=kind,reportDraft=draft});if ok then O.FilterReport(entry,kind,draft) end;return ok end
ns.Workspace.Copy=function(text,title) return F.Copy(title or 'Copy preview',text) end
ns.AthenaSuiteUI.Health=function() return U.Open({page='settings',category='data'}) end
ns.AthenaSuiteUI.Aether=function(client) return U.Open({page='settings',category='aether'}) end
ns.AthenaSuiteUI.DirectLanding=function() return U.Open({page='relay',subsection='direct'}) end
ns.AthenaSuiteUI.Direct=function(guid,owner)
 local profile=ns.AthenaProfiles.GetPlayer(guid,owner,'intel');if not profile then return false,'Profile is still preparing.' end
 return F.Form({title='Choose a Direct Share recipient',help='Review the card in Relay before sending. Both players must approve the current group contact. This does not join Aether or share your private history.',fields={{key='guid',label='Recipient GUID',value='',limit=96},{key='name',label='Exact name',value='',limit=128},{key='realm',label='Realm',value='',limit=128}},submitLabel='Review addressed card',submit=function(v) local c,why=ns.DirectNative.Create(v,true);if not c then return false,why end;return O.DirectReview(c,profile,v) end})
end
ns.AthenaSuiteUI.DirectReview=O.DirectReview
ns.AthenaSuiteUI.DirectInbox=function(client,id) if not client or not client.inbox[id] then return false end;O.directInbox={client=client,id=id};return U.Open({page='relay',subsection='direct-inbox'}) end
ns.RelayUI.Open=function(mode) return U.Open({page='relay',subsection=mode}) end
