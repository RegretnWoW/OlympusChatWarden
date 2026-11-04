-- Last-loaded integration routes: no old screen can be reached by a shortcut.
local _,ns=...
local U,L,C,F,O=ns.UI2,ns.UI2Layouts,ns.UI2Components,ns.UI2Forms,ns.UI2Operations
local W=ns.Workspace
-- A deliberate retained-history search is separate from opting into alerts.
-- Both entry points resolve one canonical source; bell visibility stays under
-- the unchanged notification preferences and hidden-preview policy.
local N=ns.UI2NotificationCenter
function N.OpenSource(id)
 if not ns.Membership.Allowed() then return false,ns.Membership.Status() end
 local item=ns.Activity.Get(id);if not item then return false,'This notification is no longer retained.' end
 local ok,why
 if item.directOffer then
  local c=ns.DirectNative.active and ns.DirectNative.active.client
  if not c or not c.inbox[item.directOffer] or c.inbox[item.directOffer].expiresAt<=ns.RelayStore.Now() then return false,'This addressed offer has expired.' end
  ok,why=ns.AthenaSuiteUI.DirectInbox(c,item.directOffer)
 elseif item.reviewID then
  if not ns.Review.Get(item.reviewID) then return false,'The original message is no longer retained.' end
  ok,why=U.Open({page='messages',messageID=item.reviewID,activityID=id})
 elseif item.categories.mentions and type(item.event)=='string' and item.event:match('^CHAT_MSG_') then ok,why=U.Open({page='messages',activityID=id})
 elseif item.eventKey then ok,why=U.Open({page='chronicle',kind='activity',key=item.eventKey,owner=item.owner})
 elseif item.wallItem then
  if not ns.AetherNet.VisibleNotice(item) then return false,'This Wall post is unavailable.' end
  if item.subjectType=='EVENT' then ok,why=U.Open({page='chronicle',kind='activity',key=item.subjectGUID,owner=item.owner,jump='discussion',wallItem=item.wallItem}) else ok,why=N.OpenWall(item.subjectGUID,item.owner,item.wallItem) end
 elseif item.subjectGUID or item.wanted and item.wanted.guid then ok,why=U.OpenPlayer(item.subjectGUID or item.wanted.guid,item.owner or ns.Chronicle.Owner())
 else ok,why=U.Open({page='mentions',selectedID=id}) end
 if ok then ns.Activity.Mark(id);if N.panel then N.panel:Hide() end end
 return ok,why
end
function N.OpenItem(id)
 for _,item in ipairs(N.List()) do if item.id==id then return N.OpenSource(id) end end
 return false,'This notification is outside the enabled alert categories.'
end
W.SettingsSub=W.Settings
W.SettingsDestination=function(category) W.Settings(category);return nil end
W.ScaleSettings=function() return W.Settings('appearance') end
W.HistorySettings=function() return W.Settings('data') end
W.CaptureSettings=function() return W.Settings('capture') end
W.MentionSettings=function() return W.Settings('notifications') end
W.WantedSettings=W.MentionSettings
W.WatchPhrases=function(phrase) U.Open({page='mentions'});if phrase then return O.MentionPhrase(phrase) end end
W.ShieldEditor=function(name) U.Open({page='shield'});return O.ShieldAdd(name) end
W.RuleEditor=function(rule,seed) U.Open({page='messages',subsection='rules'});return O.Rule(rule or seed and {phrase=seed,action='Redacted',enabled=true}) end
W.ExceptionEditor=function() return U.Open({page='messages',subsection='rules'}) end
W.PackSensitivity=function(id) return U.Open({page='settings',category='packs',selectedID=id}) end
W.Guide=function(topic) return U.Open({page='settings',category='advanced',subsection='help',topic=topic}) end
W.Welcome=function() return U.Open({page='settings',category='modules'}) end
W.SettingsCanvas=function() return U.optionsPanel end
W.ToggleFeature=function(key)
 if key=='filtering' then ns.DB.enabled=not ns.DB.enabled;ns.PolicyChanged();F.Feedback(true,'Wording filtering '..(ns.DB.enabled and 'enabled.' or 'paused.'));return true
 elseif key=='shield' then ns.Shield.SetOption('enabled',not ns.DB.shield.enabled);F.Feedback(true,'Shield '..(ns.DB.shield.enabled and 'enabled.' or 'paused.'));return true end
 return U.Open({page='settings',category='modules'})
end
ns.SetReviewTab=function(tab) return ns.OpenReview(tab) end
ns.ToggleReview=function() if U.window and U.window:IsShown() and U.route.page=='messages' then U.window:Hide();return true end;return ns.OpenReview() end
ns.OpenExport=function(kind,mode,records) if kind=='reports' or kind=='shield' or kind=='capture' or kind=='bookmarks' then return O.Export(kind,mode,records) end;return W.Settings('data') end
ns.OpenReportExport=function(mode) return U.Open({page='messages',subsection='reports',mode=mode,postAction='export-reports'}) end
ns.OpenShieldExport=function() U.Open({page='shield'});return O.Export('shield') end
ns.OpenTutorial=function(topic) return W.Guide(topic) end
ns.PhraseTester.Open=function() local ok=U.Open({page='messages',subsection='test'});if ok then return O.TestPhrase() end;return false end
ns.OpenUpdates=function() if ns.DB then ns.DB.updateSeen=ns.InstalledUpdate and ns.InstalledUpdate.version or ns.VERSION end;return U.Open({page='settings',category='advanced',subsection='updates'}) end
-- Prompt uses the same saved consent fields and disclosures, with a new form.
function ns.Chronicle.MaybePrompt(force)
 local S=ns.ChronicleStore;local pref=S.PreferenceRoot()
 if not ns.DB or not pref or not ns.Chronicle.promptReady or not ns.Membership.Allowed() or not UIParent:IsVisible() then return false end
 if not force and (not ns.Modules.Enabled('history') or S.loading or pref.promptSeen==S.CONSENT or pref.consentVersion==S.CONSENT) then return false end
 if InCombatLockdown and InCombatLockdown() then return false,'Recording consent is available after combat.' end
 if ns.RecordingConsentWindow and ns.RecordingConsentWindow:IsShown() then return true end
 if not force and U.window and U.window:IsShown() then return false end
 local ok=U.Open({page='settings',category='recording'});if not ok then return false end
 pref.promptSeen=S.CONSENT;S.preferencesChanged=true
 local form=F.Form({title='Remember your adventure',help=ns.Chronicle.Disclosure,paragraphs={'Recording starts off. This applies to eligible characters on this installation. Pausing keeps existing history. Duel recording, conversations, first-contact inspection and public sharing require their own choices. Canceling does not enable recording.'},submitLabel='Enable recording',submit=function() return ns.Chronicle.SetEnabled(true) end,cancelLabel='Not now'})
 ns.RecordingConsentWindow=form;return true
end
local settings=L.Settings
function L.Settings(route)
 if route.category~='advanced' or route.subsection~='help' and route.subsection~='updates' and route.subsection~='collection-help' then return settings(route) end
 local rows,links={},{}
 if route.subsection=='collection-help' then
  local guide=ns.CollectionGuide;local topic=guide.topics[route.topic or 'time']
  if not topic then return settings({category='advanced'}) end
  rows[1]={title=topic.label,kind='hero',height=48}
  for _,pair in ipairs({{'What is remembered',topic.what},{'When it is recorded',topic.when},{'Example',topic.example},{'Limits',topic.limit}}) do
   rows[#rows+1]={title=pair[1],kind='section',height=30}
   rows[#rows+1]={title=pair[2],kind='caption',wrap=true,height=math.max(42,math.ceil(#pair[2]/98)*20+16)}
  end
  links[1]={id='HELP.COLLECTION.HISTORY',title='Open recorded history',detail='Curated Chronicle history',height=48,activate=function() ns.RecordingUI.OpenHistory(route.owner) end}
  local topics={};for key,value in pairs(guide.topics) do topics[#topics+1]={key=key,title=value.label} end
  table.sort(topics,function(a,b) return a.title<b.title end)
  for _,item in ipairs(topics) do local key=item.key;links[#links+1]={title=item.title,height=36,activate=function() U.Open({page='settings',category='advanced',subsection='collection-help',topic=key,owner=route.owner},true) end} end
 elseif route.subsection=='updates' then
  local index=math.max(1,math.min(#ns.UpdateHistory,tonumber(route.releaseIndex) or 1));local release=ns.UpdateHistory[index]
  rows[1]={title=release.version,detail=release.subtitle,height=48,size=20}
  for _,card in ipairs(release.cards) do rows[#rows+1]={title=card[1],detail=card[2],height=86,stacked=true,wrap=true} end
  for _,delta in ipairs({1,-1}) do local destination=index+delta;if destination>=1 and destination<=#ns.UpdateHistory then links[#links+1]={title=delta==1 and 'Previous release' or 'Newer release',detail=ns.UpdateHistory[destination].version,height=42,activate=function() U.Open({page='settings',category='advanced',subsection='updates',releaseIndex=destination},true) end} end end
  links[#links+1]={title='Release notes link',detail='Copy URL',height=42,activate=function() F.Copy('Release notes',ns.PROJECT_URL..'/releases') end}
 else
  local page=ns.TutorialPage(route.topic)
  rows[1]={title=page.title,kind='hero',height=48}
  for paragraph in page.text:gmatch('[^\n]+') do rows[#rows+1]={title=paragraph,kind='caption',wrap=true,height=math.max(30,math.ceil(#paragraph/105)*20+12)} end
  for _,topic in ipairs(ns.TutorialTopics()) do local key=topic.id or topic[1];local title=topic.title or topic[2];links[#links+1]={title=title,height=38,activate=function() W.Guide(key) end} end
 end
 links[#links+1]={title='Back to Settings',height=40,activate=function() W.Settings('advanced') end}
 return {{id='content',title=route.subsection=='updates' and 'Release history' or route.subsection=='collection-help' and 'What Fireside remembers' or 'Fireside guide',x=0,y=0,w=.75,rows=rows},{id='topics',title='Topics & navigation',x=.75,y=0,w=.25,rows=links}}
end
function ns.AthenaSuiteUI.Outreach(target,context,coordinator)
 coordinator=coordinator or ns.RelayOutreach.Current
 local session,why=coordinator:Prepare(target,context,{userInitiated=true})
 if not session then return F.Feedback(false,why) end
 local ok=U.OpenPlayer(target.guid,ns.Chronicle.Owner());if not ok then coordinator:Cancel('Contact review could not open');return false end
 return F.Form({title='Review group contact',help=session.target.name..' · '..session.target.realm..' · '..session.route,paragraphs={session.message,'This is one user-selected target. Live Apply, Invite and whisper automation remain gated. A positive reply is not evidence of joining; only a roster event confirms membership.'},cancel=function() if coordinator.session and coordinator.session.id==session.id and coordinator.session.state=='PREPARING' then coordinator:Cancel('Contact review cancelled') end end,fields={{key='review',label='Review message',value=false,choices={{false,'Still reviewing'},{true,'I reviewed this exact message and target'}}}},submitLabel='Continue reviewed contact',submit=function(v)
  if not v.review then return false,'Review the exact target and text first.' end
  local sent,status=coordinator:Send(true,session.message)
  if not coordinator.options.mockSend and session.route~='NATIVE_APPLY' then F.Copy('Reviewed whisper text',session.message,'Paste into an ordinary whisper to the selected player. Nothing was sent automatically.');return false,status end
  return sent,status
 end})
end
-- One consumable workflow intent also survives combat-deferred navigation.
-- Back/Forward restore the page without unexpectedly reopening its modal.
local open=U.Open
function U.Open(route,replacing)
 if F.active then F.active:Hide() end
 local ok,window=open(route,replacing)
 if ok and U.route then
  local intent=U.route.postAction;U.route.postAction=nil
  if intent=='pack-import' then O.ImportPack()
  elseif intent=='pack-download' then F.Copy('Find signed rule packs',ns.PROJECT_URL..'/tree/main/rule-packs','Copy this link into your browser. Paste one complete signed envelope into Import. No browser request or installation runs automatically.')
  elseif intent=='export-reports' then O.Export('reports',U.route.mode)
  elseif intent=='feedback-link' then F.Copy('Public project feedback',ns.REPORT_URL or ns.PROJECT_URL..'/issues','This public website is separate from Relay reports. Remove identifying information before posting. Copying this link sends nothing.')
  elseif intent=='filter-report' then O.FilterReport(U.route.reportEntry,U.route.reportKind,U.route.reportDraft) end
 end
 return ok,window
end
ns.OpenReport=function(entry,kind,draft) return U.Open({page='messages',subsection='report',reportEntry=entry,reportKind=kind,reportDraft=draft,postAction='filter-report'}) end
ns.OpenReportLink=function() return U.Open({page='settings',category='advanced',postAction='feedback-link'}) end
-- Retained book/help controls that formerly requested a legacy record panel.
ns.RecordingUI.OpenHistory=function(owner)
 return U.Open({page='chronicle',subsection='life',owner=owner or ns.Chronicle.Owner()})
end
local chronicleSlash=ns.Chronicle.Slash
ns.Chronicle.Slash=function(argument)
 local key=(argument or ''):lower()
 if key=='events' then return ns.RecordingUI.OpenHistory()
 elseif key=='activities' then return U.Open({page='chronicle',subsection='activities'})
 elseif key=='backup' then return U.Open({page='settings',category='data'}) end
 return chronicleSlash(argument)
end
local intelSlash=ns.Chronicle.IntelSlash
ns.Chronicle.IntelSlash=function(argument)
 if (argument or ''):lower():match('^%s*(.-)%s*$')=='history' then
  local guid=ns.ChronicleStore.GUID(ns.SafeCall(UnitGUID,'target'))
  if not guid or not ns.Chronicle.Profile(guid) then
   local why='No recorded profile for this target. Select an identifiable recorded player first.';ns.Print(why);return false,why
  end
  return ns.WardenUI.Navigate('history',ns.Chronicle.Owner(),guid)
 end
 return intelSlash(argument)
end
ns.RecordingUI.OpenCollection=function(key)
 if key=='storage' or key=='backup' or key=='preservation' then return U.Open({page='settings',category='data'}) end
 if key=='time' then return U.Open({page='chronicle',subsection='time'}) end
 local owner=type(key)=='string' and key:match('^character:(.+)$')
 if owner then return ns.RecordingUI.OpenHistory(owner) end
 if ({gear=true,traits=true,appearance=true,barber=true,equipment_set=true,stats=true,collection=true,currency=true,rank=true,lockout=true,lockout_list=true,meter=true,recap=true})[key] then
  return U.Open({page='chronicle',subsection='collections',collectionFamily=key})
 end
 if ns.CollectionGuide.topics[key or 'time'] then return U.Open({page='settings',category='advanced',subsection='collection-help',topic=key or 'time'}) end
 return F.Feedback(false,'This collection topic is unavailable. Saved history is kept.')
end
ns.AthenaSuiteUI.Group=function(key,adapter,viewer)
 adapter=adapter or ns.AthenaNativeLFGAdapter.Current
 local listing=adapter:Get(key);if not listing then return false,'Listing expired or unavailable' end
 return U.Open({page='intel',kind='group',generation=listing.generation,resultID=listing.resultID,groupAdapter=adapter,groupContext=viewer})
end
