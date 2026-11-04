-- The same canonical UI2 subjects consume a derived public Net projection.
-- The existing native adapter owns I/O. This view adds no second profile DB.
local _,ns=...
local N,U,M,L,F=ns.AetherNet,ns.UI2,ns.UI2Models,ns.UI2Layouts,ns.UI2Forms
function N.Active()
 local c=N.Current;if not c or not c:Joined() then return end
 if c.nativeController then return c.nativeController.enabled and c or nil end
 return WARDEN_SIMULATOR_ISOLATED==true and c.options.fixture==true and c or nil
end
local current=N.Active
-- An authorized local publication is not a network request. Bootstrap the
-- existing durable native ledger without requiring a connected peer or target.
function N.PublicationClient()
 local c=current();if c then return c end
 if not ns.Permissions.Decide('UIAccess') then return nil,'Profile access is not authorized.' end
 if not N.Preference() or ns.Permissions.Denied('network') then return nil,'Aether participation is off. Enable it in Aether tools → Participation, privacy & sharing.' end
 if ns.AetherNative and ns.AetherNative.EnsureLocal then return ns.AetherNative.EnsureLocal() end
 return nil,'The local Aether ledger adapter is unavailable; existing drafts are kept.'
end
function N.PublicationAvailable()
 return current()~=nil or ns.Permissions.Decide('UIAccess') and N.Preference() and not ns.Permissions.Denied('network') and ns.PlayerCard.Own()~=nil and not ns.MainStorageBlocked or false
end
local function subjectType(key) return N.Subject('WIKI',key) and 'WIKI' or N.Subject('EVENT',key) and 'EVENT' or N.Subject('GUILD',key) and 'GUILD' or 'CHARACTER' end
local function draftTarget(key) return ns.ChronicleStore.GUID(key) or N.Subject('EVENT',key) or N.Subject('WIKI',key) or N.Subject('GUILD',key) end
function N.Cached()
 local c=N.Current;if not c or not c.nativeController and (WARDEN_SIMULATOR_ISOLATED~=true or c.options.fixture~=true) then return end
 local own=ns.PlayerCard.Own();local owner=c.saved and c.saved.owner or c.displayOwner
 if owner and owner~=own then return end
 c.displayOwner=own;return c
end
function N.ConnectionState()
 local c=N.Current;if c and c.nativeController then return c.nativeController.status end
 if current() then return 'SIMULATION_ONLY' end
 if N.Preference and N.Preference() then return 'AUTH_PENDING · TRANSPORT_UNAVAILABLE' end
 return 'CONSENT_OFF · TRANSPORT_UNAVAILABLE'
end
-- Read-only view of the existing transport. A queued record, cached activity,
-- discovery advertisement or simulated peer cannot create Connected status.
function N.ArtIndicator()
 if not N.Preference()then return 'OFF','Aether Beta · Off','Participation is off. Your private books and saved drafts remain available.'end
 local c=N.Cached();local adapter=c and c.nativeController
 if c and not adapter then return 'LIMITED','Aether Beta · Simulation','This isolated client is a simulator, not a verified native connection.'end
 local cap=ns.AetherNative.Capabilities(adapter)
 if cap.readiness=='UNENROLLED'then return 'LIMITED','Aether Beta · Limited','Enrollment is pending. Local creation remains available; authenticated propagation requires a verified certificate.'end
 if not cap.transportAPIAvailable then return 'UNAVAILABLE','Aether Beta · Unavailable','The required native transport is unavailable. This does not remove locally retained community content.'end
 local stale=false
 if adapter and adapter.enabled and adapter.WardenReachability then
  for guid in pairs(adapter.bindings or{})do
   local reach=adapter:WardenReachability(guid)
   if reach.status=='ONLINE'then return 'CONNECTED','Aether Beta · Connected','A recently acknowledged, GUID-bound peer is reachable. This is not proof of worldwide delivery or completed native qualification.'end
   if reach.status=='LAST_SEEN'then stale=true end
  end
 end
 if stale then return 'STALE','Aether Beta · Last seen','Previously acknowledged peers are no longer freshly confirmed. Their offline status is unknown.'end
 return 'READY','Aether Beta · Ready','The client is eligible to seek peers. No currently reachable peer has been confirmed.'
end
function N.ServiceState()
 if not N.Preference()then return 'Aether community · Participation off · Your drafts are kept'end
 local c=N.Cached();local cert=ns.AetherCertificates and ns.AetherCertificates.LocalCertificate(c)
 return cert and 'Aether community · Enrolled · original-author signatures'or'Aether community · Enrollment pending · local posts and ratings remain available'
end
function N.ReadSubject(t,key)
 local c=N.Cached();local view=c and c.options.identity(t,key) and c:View(t,key)
 if view then
  for _,row in pairs(c.records) do local r=row.record;if r.subjectType==t and r.subjectKey==key and r.origin~=c.principal and row.receivedAt and (not view.lastSynced or row.receivedAt>view.lastSynced) then view.lastSynced=row.receivedAt end end
  local muted=N.MutedAuthors and N.MutedAuthors() or {}
  for _,field in ipairs({'wall','feedback'}) do local visible={};for _,entry in ipairs(view[field] or {}) do if not muted[entry.author] then visible[#visible+1]=entry end end;view[field]=visible end
  for _,entry in ipairs(view.wall or {}) do entry.publicationState=entry.author==c.principal and 'locally-committed' or 'received';entry.delivery='No global delivery guarantee' end
  view.offline=not current();view.scope=view.offline and (c.nativeController and 'Cached · Last known · Native session attribution unverified' or 'Cached · Partial · simulation only') or view.scope;return view
 end
 return {subjectType=t,key=key,identity={},wall={},matches={},members={},events={},blocks={},current={},conflicts={},rating={count=0,maximum=t=='GUILD' and 10 or 5,scope='No synchronized ratings available'},unresolvedObservations=0,scope='Not yet synchronized',offline=true,claimed=false}
end
local function row(title,detail,fn,more) local r=more or {};r.title=title;r.detail=detail;r.activate=fn;return r end
local function cap(text) return row(text,nil,nil,{kind='caption',wrap=true,height=54}) end
local function changed() U.Refresh(true) end
function N.PublicationScope() return 'Aether community' end
local function nextRevision(c,t,key,kind,slot)
 return N.NextRevision(c,t,key,kind,slot)
end
function N.Vote(t,key,score)
 local c,why=N.PublicationClient();if not c then return false,why end
 if t~='GUILD' and t~='CHARACTER' then return false,'Event feedback is separate from global ratings.' end
 local max=t=='GUILD' and 10 or 5
 if score~=nil and (type(score)~='number' or score%1~=0 or score<1 or score>max) then return false,'Choose an integer from 1 to '..max..'.' end
 if t=='CHARACTER' and c.options.owns(c.principal,t,key) then return false,'You cannot rate your own character.' end
 local pair,why=c:Publish(t,key,t=='GUILD' and 'GUILD_VOTE' or 'PLAYER_VOTE','vote',score and {score=score} or {},nextRevision(c,t,key,t=='GUILD' and 'GUILD_VOTE' or 'PLAYER_VOTE','vote'),score==nil,true)
 changed();return pair~=nil,pair and (score and 'Rating saved.' or 'Rating removed.') or why
end
function N.Voting(guid)
 if not ns.ChronicleStore.GUID(guid) then return {enabled=false,reason='An exact character identity is required.'} end
 local c=current();if not c then return {enabled=N.PublicationAvailable() and guid~=ns.PlayerCard.Own(),reason=guid==ns.PlayerCard.Own() and 'You cannot rate your own character.' or N.PublicationAvailable() and 'Rate this player in the Aether community.' or 'Aether participation is off. Enable it in Aether tools → Participation, privacy & sharing.'} end
 local entry=c.records['CHARACTER/'..guid..'/PLAYER_VOTE/'..c.principal..'/vote']
 local own=c.options.owns(c.principal,'CHARACTER',guid)
 return {enabled=not own,stars=entry and not entry.record.removed and entry.record.data.score,
  revision=entry and entry.record.revision or 0,reason=own and 'You cannot rate your own character.' or N.PublicationScope()}
end
function N.EditDraft(key)
 if key~=ns.PlayerCard.Own() then return false,'Only your own unpublished profile draft can be edited.' end
 local d=ns.PlayerCard.Local(key) or {}
 return F.Form({title='Your profile · unpublished draft',help='Unpublished profile draft. Private Intel notes are never included.',
 fields={{key='about',label='About Me · 500 characters',value=d.about or '',multiline=true,height=110},
   {key='zone',label='Gamerzone',value=d.gamerzone or '',choices={{'','Not selected'},{'recreation','Recreation'},{'pro','Pro'},{'family','Family'},{'underground','Underground'}}}},
 submitLabel='Save unpublished draft',submit=function(v) local ok,why=ns.PlayerCard.SaveDraft(key,v.about,v.zone~='' and v.zone or nil);if ok then changed() end;return ok,why end})
end
function N.EditOwner(key)
 local c=N.PublicationClient();if not c or not c.options.owns(c.principal,'CHARACTER',key) then return false,'Verified character-owner proof required.' end
 local v=c:View('CHARACTER',key);local owner=v.owner or {}
 return F.Form({title='Your public profile',help='Share text and, only if selected below, your current character appearance. Missing customization details remain unknown. Private Intel notes and history are never copied here. Authenticated peer forwarding requires an enrolled character certificate; native delivery remains unverified.',
  fields={{key='about',label='About Me · 500 characters',value=owner.about or '',multiline=true,height=110},

   {key='appearance',label='Share my current character appearance',value=owner.appearance and'yes'or'no',choices={{'no','Do not share appearance'},{'yes','Share my body and visible equipment'}}},
   {key='zone',label='Gamerzone',value=owner.gamerzone or '',choices={{'','Not selected'},{'Recreation','Recreation'},{'Pro','Pro'},{'Family','Family'},{'Underground','Underground'}}}},
  submitLabel='Save public profile',submit=function(values)
   if not N.Text(values.about,500) then return false,'Use plain text, at most 500 characters, without links or WoW markup.' end
   local appearance;if values.appearance=='yes'then local reason;appearance,reason=ns.WardenAppearance.Capture(key);if not appearance then return false,reason end end
   local pair,why=c:Publish('CHARACTER',key,'OWNER','owner',{appearance=appearance,about=values.about,gamerzone=values.zone~='' and values.zone or nil,wallEnabled=owner.wallEnabled==true,drawingsAllowed=owner.drawingsAllowed},nextRevision(c,'CHARACTER',key,'OWNER','owner'),false,true)
   if pair then changed() end;return pair~=nil,pair and 'Public profile saved.' or why
  end})
end
function N.RefreshSubject(t,key)
 local c,why=N.PublicationClient();if not c then return F.Feedback(false,why) end
 local ok,why=c:Refresh(t,key);changed();return F.Feedback(ok,ok and 'Checking isolated peers; results remain partial.' or why)
end
function N.ReviewCurrent(model,kind)
 local data,why=N.ProjectCurrent(model,kind);if not data then return F.Feedback(false,why) end
 local publication,reason=N.PublicationClient();if not publication then return F.Feedback(false,reason) end
 local at=ns.SafeCall(date,'!%Y-%m-%d %H:%M UTC',data.observedAt) or tostring(data.observedAt)
 return F.Confirm('Review latest observed '..(kind=='GEAR' and 'equipment' or 'talents'),
  'Observed '..at..' · '..data.evidence..' · '..data.completeness..'. Only the selected, permitted current information is shared. Historical captures, private notes and Direct Shares stay private.',function()
   local latest=N.ProjectCurrent(model,kind);if not latest or ns.ChronicleBackup.Encode(latest)~=ns.ChronicleBackup.Encode(data) then return false,'Capture changed; review again.' end
   local pair,reason=N.PublishCurrent(model,kind,true);if pair then changed() end;return pair~=false and pair~=nil,reason
  end)
end
function N.BlockMember(key,principal,blocked)
 local c=N.PublicationClient();if not c or not c.options.owns(c.principal,subjectType(key),key) then return false,'Verified profile owner required.' end
 local slot=N.HideSlot(principal)
 return F.Confirm(blocked and 'Block future Wall writing?' or 'Allow future Wall writing?',
  'Applies only to this profile’s Wall. Votes, observed gameplay and your private Shield settings are unchanged.',function()
   local pair,why=c:Publish(subjectType(key),key,'BLOCK',slot,{principal=principal,blocked=blocked},nextRevision(c,subjectType(key),key,'BLOCK',slot),false,true)
   changed();return pair~=nil,why
  end)
end
function N.VisibleNotice(item)
 local c=N.Cached();if not c or item.owner~=ns.Chronicle.Owner() or not item.wallItem or not item.subjectGUID then return nil end
 local view=N.ReadSubject(item.subjectType or 'CHARACTER',item.subjectGUID)
 for _,post in ipairs(view and view.wall or {}) do if post.id==item.wallItem then return post end end
end
function N.Changed(c,record,id,context)
 if c~=N.Current then return end
 -- Cache tokens already include ledger revision. Keep the previous complete
 -- dossier visible while its replacement model is prepared.
 if (record.kind=='WALL' or record.kind==N.COMMUNITY_KIND) and context=='live' and not record.removed and record.origin~=c.principal
  and current()==c and ns.Modules.Enabled('alerts') and ns.Notifications.Get('athena') then
  if N.MutedAuthors and N.MutedAuthors()[record.origin] then return end
  local view=c:View(record.subjectType,record.subjectKey)
  for _,post in ipairs(view.wall) do if post.id==id then
   local notice='net-wall/'..N.HideSlot(id)
   if not ns.Activity.Get(notice) then ns.Activity.Add(notice,'athena',{owner=ns.Chronicle.Owner(),subjectGUID=record.subjectKey,subjectType=record.subjectType,wallItem=id,
    sender=post.authorName,preview='New public Wall activity',notificationPreference='athena',timestamp=record.issuedAt},false) end
  end end
 end
 -- The preview is resolved through the current moderated view when read. No
 -- original post text is saved in notifications or a second Wall inbox.
 if ns.UI2NotificationCenter then ns.UI2NotificationCenter.Refresh() end
end

function N.Candidates(query,kind)
 local c=N.Cached();local out,seen={},{};query=(query or ''):lower()
 if not c then return out end
 for _,pair in pairs(c.records) do local record=pair.record;local id=record.subjectType..'/'..record.subjectKey
  local hint=(record.kind=='IDENTITY' or record.kind=='EVENT_FACT') and record.data.name
  if hint and not pair.conflict and not record.removed and (not kind or record.subjectType==kind) and not seen[id]
   and (query=='' or (hint..' '..(record.data.realm or '')):lower():find(query,1,true)) then
   seen[id]=true;local v=c:View(record.subjectType,record.subjectKey)
   if v and v.event then v.identity={name=v.event.name,realm=v.event.realm} end
   if v and v.identity.name and v.identity.realm and (query=='' or (v.identity.name..' '..v.identity.realm):lower():find(query,1,true)) then
    out[#out+1]={kind=record.subjectType,key=record.subjectKey,name=v.identity.name,realm=v.identity.realm,scope='Partial Aether Net · isolated simulation'}
    if #out>=64 then break end
   end
  end
 end
 table.sort(out,function(a,b) return a.kind..a.name..a.key<b.kind..b.name..b.key end)
 return out
end

-- Private supporting namespace in the existing Exchange saved file. These
-- unsigned drafts are never ingested, digested, forwarded or auto-published.
local function draftState()
 local function shape(value,names)
  if type(value)~='table' or getmetatable(value) then return false end
  local allowed={};for k in names:gmatch('%S+') do allowed[k]=true end
  for k in pairs(value) do if not allowed[k] then return false end end;return true
 end
 local db=ns.Storage.OlympusWardenExchangeDB
 if db~=nil and (type(db)~='table' or db.schema~=1 or type(db.characters)~='table') then return nil,'Saved data requires recovery; kept unchanged.' end
 local root=db and db.netLocal
 if root==nil then return {schema=1,owners={}} end
 if not shape(root,'schema owners') or root.schema~=1 or type(root.owners)~='table' or getmetatable(root.owners) or ns.Athena2.Count(root.owners)>16 then return nil,'Draft storage requires recovery; kept unchanged.' end
 for owner,state in pairs(root.owners) do
  if not ns.ChronicleStore.GUID(owner) or not shape(state,'owner serial wantShare drafts muted native wiki') or type(state.owner)~='string' or #state.owner>192
   or type(state.serial)~='number' or state.serial<0 or state.serial>=1000000000 or state.serial%1~=0
   or type(state.wantShare)~='boolean' or type(state.drafts)~='table' or getmetatable(state.drafts) or ns.Athena2.Count(state.drafts)>32 then return nil,'Draft storage requires recovery; kept unchanged.' end
  if state.wiki~=nil and (not N.ValidateWikiLocal or not N.ValidateWikiLocal(state.wiki)) then return nil,'Local Wiki moderation needs recovery; kept unchanged.' end
  if state.native~=nil then
   local p=state.native
   if not shape(p,'version routes shareIdentity sharePresence') or p.version~=1 or type(p.routes)~='table' or getmetatable(p.routes) or #p.routes>20 or type(p.shareIdentity)~='boolean' or type(p.sharePresence)~='boolean' then return nil,'Native peer preferences need recovery.' end
   local n=0;for k,r in pairs(p.routes) do n=n+1;if type(k)~='number' or k%1~=0 or k<1 or k>#p.routes or not shape(r,'name channel') or not ns.CanRead(r.name) or #r.name>180 or not ({WHISPER=true,PARTY=true,RAID=true,INSTANCE_CHAT=true,GUILD=true})[r.channel] then return nil,'Native routes need recovery.' end end
   if n~=#p.routes then return nil,'Native route array needs recovery.' end
  end
  if state.muted~=nil then
   if type(state.muted)~='table' or getmetatable(state.muted) or ns.Athena2.Count(state.muted)>32 then return nil,'Local content preferences require recovery.' end
   for principal,value in pairs(state.muted) do if type(principal)~='string' or #principal>128 or not principal:match('^[%w_:/%.%-]+$') or value~=true then return nil,'Local content preferences require recovery.' end end
  end
  for id,d in pairs(state.drafts) do
   if type(id)~='string' or #id>24 or not id:match('^draft%-%d+$') or not shape(d,'id target author parent text doodle at postID postKind') or d.id~=id or d.author~=owner
    or not draftTarget(d.target) or not N.Text(d.text,d.parent and 280 or 500) or #d.text==0
    or d.parent~=nil and (type(d.parent)~='string' or #d.parent>384 or d.parent:sub(1,#(subjectType(d.target)..'/'..d.target..'/'))~=subjectType(d.target)..'/'..d.target..'/')
    or d.postID~=nil and (type(d.postID)~='string' or #d.postID>384 or d.postID:sub(1,#(subjectType(d.target)..'/'..d.target..'/'))~=subjectType(d.target)..'/'..d.target..'/')
    or d.postKind~=nil and d.postKind~='WALL' and d.postKind~=N.COMMUNITY_KIND
    or d.doodle~=nil and not ns.WardenDrawing.Decode(d.doodle)
    or type(d.at)~='number' or d.at~=d.at or d.at<0 or d.at>9999999999 then return nil,'Draft storage requires recovery; kept unchanged.' end
  end
 end
 -- Encoding happens only after the bounded shape/content checks above.
 if #ns.ChronicleBackup.Encode(root)>262144 then return nil,'Draft storage exceeds its bound; kept unchanged.' end
 return root
end
local function ownerDraftState(root)
 local author=ns.PlayerCard.Own();if not author then return nil,'Current author identity unavailable.' end
 local state=root.owners[author]
 if state and state.owner~=ns.Chronicle.Owner() then return nil,'Author scope differs; drafts kept unchanged.' end
 return state or {owner=ns.Chronicle.Owner(),serial=0,wantShare=false,drafts={}},author
end
local function saveLocal(root,author,state)
 if not root.owners[author] and ns.Athena2.Count(root.owners)>=16 then return false,'Local profile capacity reached.' end
 local staged=ns.Athena.Copy(root);staged.owners[author]=state
 if #ns.ChronicleBackup.Encode(staged)>262144 then return false,'Local draft byte limit reached.' end
 if ns.Storage.OlympusWardenExchangeDB==nil then ns.Storage.OlympusWardenExchangeDB={schema=1,characters={}} end
 ns.Storage.OlympusWardenExchangeDB.netLocal=staged;return true
end
function N.Preference()
 local root=draftState();local state=root and ownerDraftState(root);return state and state.wantShare==true or false
end
function N.NativePolicy(value,explicit)
 local root,why=draftState();if not root then return nil,why end
 local state,author=ownerDraftState(root);if not state then return nil,author end
 if value==nil then return ns.Athena.Copy(state.native) end
 if explicit~=true or not ns.Permissions.Decide('UIAccess') or type(value)~='table' then return false,'EXPLICIT_NATIVE_SCOPE_REQUIRED' end
 state=ns.Athena.Copy(state);state.native=ns.Athena.Copy(value)
 -- Validate through the same bounded parser before committing a new policy.
 local previous=ns.Storage.OlympusWardenExchangeDB and ns.Storage.OlympusWardenExchangeDB.netLocal
 local check=ns.Athena.Copy(root);check.owners[author]=state
 if not ns.Storage.OlympusWardenExchangeDB then ns.Storage.OlympusWardenExchangeDB={schema=1,characters={}} end
 ns.Storage.OlympusWardenExchangeDB.netLocal=check;local valid,reason=draftState();ns.Storage.OlympusWardenExchangeDB.netLocal=previous
 if not valid then return false,reason end
 return saveLocal(root,author,state)
end
function N.SetPreference(value)
 if type(value)~='boolean' then return false,'Choose On or Off.' end
 -- Withdrawal must stop a live session even if saved local preferences are
 -- malformed or current author identity is temporarily unavailable.
 if not value then ns.Permissions.Deny('network');if N.Current then N.Current:Leave() end
 elseif not ns.Permissions.Resume('network',true) then return false,'Verified explicit participation action required.' end
 local root,why=draftState();if not root then return false,why end
 local state,author=ownerDraftState(root);if not state then return false,author end
 state=ns.Athena.Copy(state);state.wantShare=value
 local ok,reason=saveLocal(root,author,state)
 if ok then
  -- This existing opt-in authorizes automatic community synchronization.
  -- It never commits drafts, publishes an About Me edit or enables capture.
  if value and ns.AetherNative and ns.AetherNative.EnsureLocal and (not N.Current or N.Current.nativeController) then ns.AetherNative.EnsureLocal() end
  changed()
 end;return ok,reason or 'Preference saved. Drafts remain private until explicitly published.'
end
function N.EventFeedback(key,target)
 local c=N.PublicationClient();if not c or not c.options.eventParticipant or c.options.eventParticipant(key,target,c.principal,'feedback')~=true then return F.Feedback(false,'Verified reviewer participation and target eligibility required. No public feedback was committed.') end
 return F.Form({title='Event commendation · attributable opinion',help='One editable contribution per author, event and participant. This never changes player stars, guild ratings, Shield policy or matchmaking.',fields={{key='category',label='Commendation',value='helpful',choices={{'helpful','Helpful teammate'},{'tanking','Tanking'},{'healing','Healing'},{'leadership','Leadership'},{'teamwork','Teamwork'}}},{key='text',label='Brief constructive context',value='',multiline=true,height=90}},submitLabel='Review and save opinion',submit=function(v)
  local slot=N.HideSlot(target);local pair,why=c:Publish('EVENT',key,'EVENT_FEEDBACK',slot,{version=1,target=target,category=v.category,text=v.text},nextRevision(c,'EVENT',key,'EVENT_FEEDBACK',slot),false,true)
  if pair then changed() end;return pair~=nil,why
 end})
end

function N.MutedAuthors()
 local root=draftState();local state=root and ownerDraftState(root);return state and state.muted or {}
end
function N.ApplyMutePreference(state,principal,muted)
 if type(principal)~='string' or #principal>128 or not principal:match('^[%w_:/%.%-]+$') or type(muted)~='boolean' then return false,'Exact author and local choice required.' end
 state.muted=state.muted or {}
 if muted and not state.muted[principal] and ns.Athena2.Count(state.muted)>=32 then return false,'Local muted-author limit reached.' end
 state.muted[principal]=muted and true or nil;return true
end
function N.MuteAuthor(principal,muted)
 local root,why=draftState();if not root then return false,why end;local state,author=ownerDraftState(root);if not state then return false,author end
 state=ns.Athena.Copy(state);local ok,reason=N.ApplyMutePreference(state,principal,muted);if not ok then return false,reason end
 local saved,message=saveLocal(root,author,state);if saved then changed() end;return saved,message
end
function N.RemoveFeedback(key,feedback)
 local c=N.PublicationClient();if not c or feedback.author~=c.principal then return F.Feedback(false,'Only the verified author can withdraw this opinion.') end
 return F.Confirm('Withdraw event feedback?','This withdraws only your event-specific opinion. Global ratings and observed facts are unchanged.',function()
  local pair,why=c:Publish('EVENT',key,'EVENT_FEEDBACK',N.HideSlot(feedback.target),{version=1,target=feedback.target,category=feedback.category,text=''},feedback.revision+1,true,true)
  if pair then changed() end;return pair~=nil,why
 end)
end

function N.Presence(guid)
 local cached=N.Cached();local adapter=cached and cached.nativeController
 local reach=adapter and adapter.WardenReachability and adapter:WardenReachability(guid) or {status='UNKNOWN',label='Unknown'}
 local p=N.ReadSubject('CHARACTER',guid).current.PRESENCE;local now=ns.SafeCall(GetServerTime) or 0
 local out={label='Activity unknown',activityKnown=false,wardenStatus=reach.label,online=reach.status,lastSeen=reach.at,expiresAt=reach.expiresAt,scope='Reachability requires an acknowledged, GUID-bound peer session; no offline status is inferred.',group={}}
 local d=p and p.value
 if not d or p.state=='Conflict' or type(d.observedAt)~='number' or type(d.validUntil)~='number' or d.observedAt>now or d.validUntil<=now or d.validUntil>d.observedAt+90 then return out end
 local label=({idle='Available',dungeon='Currently in a dungeon',raid='Currently Raiding',battleground='Currently in a battleground',arena='Currently in an arena',crafting='Currently Crafting'})[d.activity]
 if not label then return out end
 out.label=label..(d.place~='' and ' · '..d.place or '');out.activityKnown=true;out.at=d.observedAt;out.source=p.origin;out.expiresAt=math.min(out.expiresAt or d.validUntil,d.validUntil);return out
end
function N.OnlineWardenUsers()
 local c=current();local a=c and c.nativeController;local out={}
 if not a or not a.WardenReachability then return out end
 for guid,known in pairs(a.bindings or {}) do local reach=a:WardenReachability(guid)
  if reach.status=='ONLINE' then out[#out+1]={key=guid,title=known.name,at=reach.at,expiresAt=reach.expiresAt} end
 end
 table.sort(out,function(x,y) return x.title<y.title end);return out
end

-- Bounded local Wiki preferences use the existing Exchange netLocal namespace.
function N.WikiLocal(key)
 local root,why=draftState();if not root then return nil,why end
 local state,author=ownerDraftState(root);if not state then return nil,author end
 return ns.Athena.Copy(state.wiki and state.wiki.articles[key] or {hidden={},pins={},notes={},history={},locked=false})
end
function N.UpdateWikiLocal(key,update)
 if not ns.AthenaLivingWiki or not ns.AthenaLivingWiki.AdminAllowed or not ns.AthenaLivingWiki.AdminAllowed() then return false,'PRIVATE_DEVELOPER_REQUIRED' end
 local root,why=draftState();if not root then return false,why end
 local state,author=ownerDraftState(root);if not state then return false,author end
 state=ns.Athena.Copy(state);state.wiki=state.wiki or {version=1,articles={}}
 local article=state.wiki.articles[key] or {hidden={},pins={},notes={},history={},locked=false}
 local ok,reason=update(article,state);if not ok then return false,reason end
 state.wiki.articles[key]=article
 if not N.ValidateWikiLocal(state.wiki) then return false,'LOCAL_WIKI_BOUND' end
 return saveLocal(root,author,state)
end

