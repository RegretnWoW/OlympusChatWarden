-- One player entry point. Protocol controls remain private Lab diagnostics.
local _,ns=...
local L,W,U,C=ns.AetherLive,ns.AetherLive.World,ns.UI2,ns.UI2Components
local function now()return ns.SafeNumber(ns.SafeCall(GetTime))or 0 end
local function approved()
 local r=ns.DB and ns.DB.aetherLiveConsent92
 return type(r)=='table'and r.version==2 and r.owner==ns.Permissions.Owner()and r.enabled==true
end
function L.Status()
 local s=L.runtime;local n,waiting,failed=0,0,0
 if s then for _,p in pairs(s.peers)do
  if p.status=='CONNECTED'and p.expires and p.expires>now()then n=n+1
  elseif p.status=='CONNECTING'or p.status=='DIRECTLY_REACHABLE'then waiting=waiting+1
  elseif p.status=='UNREACHABLE'or p.status=='TIMED_OUT'then failed=failed+1 end
 end end
 if W.phase=='leaving'then return'LEAVING','Leaving Aether Live','Restoring your private scene and recorded characters.'end
 if W.phase=='entering'then return'ENTERING','Entering Aether Live','Getting Aetheria ready for you. Fellow adventurers will appear once they connect.'end
 if L.pending then return L.pending.code and'ERROR'or'PENDING',L.pending.code and'Live connection unavailable'or'Getting Aetheria ready',L.pending.code and'Fireside could not start the connection. We will retry; connection details explain what happened. You can leave to cancel.'or'Your request is kept. Open Fireside to continue entering Aetheria, or leave to cancel.'end
 if not s or not s.enabled then return'OFF',L.lastLost and'Connection Lost'or'Disconnected',L.lastError or'Explore Aetheria with fellow Olympus members. Join whenever you want company; your private world is always yours.'end
 if s.pauseReason then return'PAUSED','Connection paused',s.pauseReason=='COMBAT_PAUSED'and'Connections will continue when combat ends. You can keep exploring.'or'WoW is currently holding outgoing connections. Fireside will wait until they are available again. Connection details can help if this continues.'end
 if n>0 then
  local waitingAppearance,incompatible=false,false
  for _,p in pairs(s.peers)do if p.status=='CONNECTED'then
   incompatible=incompatible or p.sceneCompatibility=='INCOMPATIBLE_GEOMETRY'
   waitingAppearance=waitingAppearance or not p.liveAppearance or p.renderReport and(p.renderReport.mode=='LOAD_FAILED'or p.renderReport.mode=='APPEARANCE_UNAVAILABLE')
  end end
  local detail=incompatible and'You are connected, but a shared place has changed. Use matching Fireside updates to explore it together.'or waitingAppearance and'You are connected. Some adventurers’ appearances are still arriving or could not be shown. Connection details explain what is available.'or'You have connected with fellow Fireside players. You will see one another when you explore the same place; some appearances may look approximate.'
  return'CONNECTED','Connected — '..n..(n==1 and' Player'or' Players'),detail
 end
 if waiting>0 then return'CONNECTING','Connecting','Looking for fellow adventurers and waiting for them to answer.'end
 if failed>0 then return'RETRYING','Retrying','We haven’t heard back yet. Fireside will keep trying while you explore.'end
 return'DISCOVERING','Discovering Players','You can explore while we look for company. Other players will appear when someone joins and connects with you.'
end
function L.RefreshStatus()
 if not U.window then return end
 local state,title,detail=L.Status()
 if U.aetherIndicator then
  local label=(W.active or L.pending or W.phase=='entering')and'Leave Aether Live'or'Enter Aether Live'
  U.aetherIndicator:SetLabel(label);U.aetherIndicator.label:SetTextColor(unpack(state=='CONNECTED'and C.colors.green or C.colors.blue))
  ns.Theme.Tooltip(U.aetherIndicator,'Aether Live',title..'\n'..detail)
 end
 if not L.statusButton and U.restoreMenu then
  local b=C.Button(U.window,'',function()if L.Status()=='CONNECTED'then L.People()else L.Information()end end,370);L.statusButton=b;b:SetHeight(25);b:SetPoint('BOTTOMLEFT',18,3)
  local leave=C.Button(U.window,'Leave Aether Live',function()L.Exit()end,175);L.leaveButton=leave;leave:SetHeight(25);leave:SetPoint('LEFT',b,'RIGHT',12,0)
 end
 if L.statusButton then
  local visible=W.active or L.pending~=nil
  L.statusButton:SetLabel(visible and title..' · Early Access'or'Aether Live · connection details');L.statusButton:SetShown(U.window:IsShown())
  L.leaveButton:SetShown(visible and U.window:IsShown())
  local level=U.restoreMenu:GetFrameLevel();L.statusButton:SetFrameLevel(level);L.leaveButton:SetFrameLevel(level)
 end
end
local function diagnosticValue(v)
 if v==nil then return'none'end
 if type(v)=='number'then return tostring(math.floor(v*100+.5)/100)end
 if type(v)=='boolean'then return tostring(v)end
 if type(v)~='string'then return'UNAVAILABLE'end
 return v:gsub('[%z\001-\031\127]',' '):sub(1,180)
end
function L.ConnectionDiagnosticsText()
 local r=L.Runtime():Export();local _,title,detail=L.Status();local lines={'FIRESIDE_AETHER_LIVE_2','Diagnostic revision: 110.1','Native connectivity/rendering: UNVERIFIED',title,detail}
 local function line(label,...)local a={...};for i=1,select('#',...)do a[i]=diagnosticValue(a[i])end;lines[#lines+1]=label..table.concat(a,' | ')end
 if ns.AetherUnified then lines[#lines+1]='Community sync: '..ns.AetherUnified.status;lines[#lines+1]='Sync received / rejected / maximum slice ms: '..tostring(ns.AetherUnified.metrics.received)..' | '..tostring(ns.AetherUnified.metrics.rejected)..' | '..tostring(ns.AetherUnified.metrics.maxSliceMS);lines[#lines+1]='Sync result: '..tostring(ns.AetherUnified.lastError or'none')end
 local c=r.connection or{};local a=c.native or{};local d=r.directory or{};local g=r.gameplay or{};local m=r.metrics or{}
 line('Build: ',ns.VERSION,ns.ClientBuild and ns.ClientBuild.target)
 local membership=ns.Membership or{}
 line('Membership verified / method / local access / reason: ',membership.allowed,membership.method,membership.Allowed and membership.Allowed(),membership.Status and membership.Status())
 local me=ns.AetherNative.NativeUnit('player')
 line('Local character address / realm / realm ID: ',me and me.name,ns.SafeCall(GetRealmName),ns.SafeCall(GetRealmID))
 line('Last native whisper target Live / enrollment: ',L.nativeTargets and L.nativeTargets.live,L.nativeTargets and L.nativeTargets.enrollment)
 line('Live address policy: ',ns.AetherCertificates.Namespace()=='forever'and'FIRST_SURNAME_ACROSS_FOREVER_LAYERS'or'EXACT_NATIVE_REALM')
 line('Revision / geometry / gameplay protocol: ',r.sharedRevision,r.geometrySignature,r.gameplayProtocol)
 line('Runtime enabled / context valid / prefix / registered / registration: ',c.enabled,c.valid,c.prefix,c.registered,c.registrationResult)
 line('Paused / reason / combat / native restriction probe: ',c.paused,c.pauseReason,a.combat,a.outgoingRestricted)
 line('Chat messaging lockdown / availability policy: ',a.chatLockdown,a.restrictionPolicy)
 line('API ordinary / logged / prefix registration: ',a.sendAvailable,a.loggedAvailable,a.registerAvailable)
 line('Native worker attached / calls / last tick seconds ago: ',a.workerAttached,a.pumpCalls,a.lastPumpAge)
 line('Live worker calls / stage / last tick seconds ago / active seconds: ',c.pumpCalls,c.pumpStage,c.lastPumpAge,c.activeSeconds)
 line('Session worker calls / stage: ',d.sessionPumpCalls,d.sessionPumpStage)
 line('Directory / channel / id / members / candidates / GUID bindings: ',d.state,d.channelName,d.channel,d.members,d.identities,d.guidIdentities)
 line('Directory verified display index / roster count source: ',d.displayIndex,'GetChannelDisplayInfo; name and local channel number checked')
 line('Directory API channel / count / roster / join: ',d.channelAPI,d.countAPI,d.rosterAPI,d.joinAPI)
 line('Directory worker / join attempts / last result / rows / cursor / roster errors: ',d.pumpCalls,d.joinAttempts,d.joinResult,d.rowsScanned,d.cursor,d.rosterErrors)
 line('Roster subscription requests / result / API available: ',d.rosterRequests,d.rosterRequestResult,d.rosterRequestAPI)
 line('Queues control / crypto / ACKs / roster / peers / budget waits: ',c.controlQueue,c.cryptoQueue,c.pendingACKs,c.roster,c.peerCount,m.budgetWaits)
 line('Control sends / received / rejects / drops / ACKs / retries / last send result: ',m.sent,m.received,m.rejected,m.dropped,m.acked,m.retries,c.lastSendResult)
 line('Native receive ordinary / logged / last receive seconds ago: ',c.ordinaryEvents,c.loggedEvents,c.lastReceiveAge)
 local runtime=L.runtime;local app=r.applications or{}
 line('Community messages queued / received / ACKs / dropped / retries: ',app.queued,app.received,app.acked,app.dropped,app.retries)
 line('Community frames attempted / sent / received / last send / last rejection: ',app.frameAttempts,app.framesSent,app.framesReceived,runtime and runtime.applicationLastSend,runtime and runtime.applicationLastReject)
 line('Community wire protocol / queued transfers / queued bytes: ',ns.AetherLiveGameplay.APPLICATION_PROTOCOL,runtime and runtime.applicationCount,runtime and runtime.applicationBytes)
 line('Owner appearance / identity / startup error: ',r.appearanceCapture,r.liveIdentity,L.lastStartupError)
 line('Last profile identity source / error: ',L.lastProfileSource,L.lastProfileError)
 line('Gameplay sends / bytes / rejects / fragments out / in / appearance ACKs / movement ACKs: ',g.sent,g.bytes,g.rejected,g.fragmentsSent,g.fragmentsReceived,g.appearanceACKs,g.movementACKs)
 local v=U.realm;local scene=v and v:ActiveRoom();local t=v and v.roomTravel;local trip=t and(t.state and t.state.link or t.last)or{};local actor=scene and scene.native and scene.native.actors.attendant
 line('Scene / Live phase / window visible: ',scene and scene.key,W.phase,U.window and U.window:IsShown()or false)
 line('Travel phase / from / to / last result / error: ',t and t.state and t.state.phase or'idle',trip.from,trip.to,t and t.last and t.last.status,t and t.lastError)
 line('Arrival follow-up walk: ',t and t.last and t.last.arrivalWalkWarning or'No blocked follow-up')
 local input=v and v.lastSceneClick or{}
 line('Scene update error / last ground click / accepted / seating: ',v and v.lastError,input.reason,input.accepted,actor and actor.seating and actor.seating.phase)
 line('Player ready / retired / registration pending / spawn pending / failed / motion: ',actor and actor.ready or false,actor and actor.retired or false,actor and actor.awaitRegistration or false,actor and actor.awaitSpawn or false,actor and actor.failed,actor and actor.motionStatus)
 local pending=scene and scene.pendingWorldCalibration;local ground=scene and scene.native.frame and scene.native.frame.firesideAuthoredGround
 line('Perspective applied / pending / attempts / reason / authored ground verified: ',scene and scene.worldCalibration~=nil,pending~=nil,pending and pending.attempts,pending and pending.reason,ground and ground.corroborated or false)
 local fire=scene and scene.native.actors.firepit
 line('Firepit contact bounds / native sizing scale: ',fire and(fire.boundsSource or'Native bounds'),fire and fire.scale)
 if scene and actor and actor.ready and actor.bounds then
  local nav,why=v:GroundNavigation(scene,actor);line('Current movement navigation: ',nav and'READY'or why)
  if nav and actor.position then local p=actor.position;local ok,blocked=ns.WardenNativeScene.CheckPath({samples={{x=p[1],y=p[2],z=p[3]}},length=0},nav)
   line('Current player contact valid / reason: ',ok,blocked)
  end
  for _,spec in ipairs(ns.WardenWorldScenes.Props(scene))do local prop=scene.native.actors[spec.id]
   if spec.collision~=false and not spec.support and(not prop or not prop.ready or prop.awaitRegistration)then
    line('Waiting prop / ready / retired / hidden / registration / load state: ',spec.id,prop and prop.ready or false,prop and prop.retired or false,prop and prop.editorHidden or spec.defaultHidden or false,prop and prop.awaitRegistration or false,prop and prop.status)
   end
  end
 end
 local services=ns.AetherServices;local enroll=services and services.runtime
 line('Enrollment desired / running / status / startup error: ',services and services.Desired('relay')or false,enroll and enroll.enabled or false,enroll and enroll.status,services and services.error)
 for _,p in ipairs(r.peers or{})do
  line('Peer: ',p.name,p.state,p.path,p.detail,p.scene,p.sceneCompatibility,p.gameError,p.rttMS)
  local visual=p.render or{};line('  Appearance sent / received / ACK / render / reason: ',p.appearanceSent,p.appearanceReceived,p.appearanceACKed,visual.mode,visual.reason)
  local peerID=L.Name(p.name);local peer=runtime and runtime.peers[peerID];local sending=runtime and runtime.applicationOut[peerID];local incoming=peer and peer.gameParts and peer.gameParts.S
  line('  Community peer protocol / outgoing part / parts / incoming parts / total: ',peer and peer.applicationVersion,sending and sending.next,sending and #sending.parts,incoming and incoming.n,incoming and incoming.total)
  if p.geometryDetail then line('  Position check: ',p.geometryDetail)end
 end
 lines[#lines+1]='Persisted Live packets: 0; keys, certificates, packet bodies and private history: excluded'
 if ns.FiresideStartupTiming then lines[#lines+1]=ns.FiresideStartupTiming.Text()end
 return table.concat(lines,'\n')
end
function L.CopyDiagnostics()
 return ns.UI2Forms.Copy('Aether Live connection diagnostics',L.ConnectionDiagnosticsText(),'Includes participating character addresses, connection counters and Aetheria travel status. No keys, certificate blobs, private Athena records or actual WoW locations.')
end
-- Live profiles are a view of the current connection, never a recorded sighting.
local function connected(p)
 return L.runtime and L.runtime.enabled and p and p.status=='CONNECTED'and p.expires and p.expires>now()
end
local function plain(value,limit)
 return type(value)=='string'and value:gsub('[%z\001-\031\127]',' '):sub(1,limit or 180):gsub('|','||')or''
end
function L.ConnectedPlayer(id)
 local p=L.runtime and L.runtime.peers[id];if connected(p)then return p end
end
function L.PlayerName(p)
 local _,_,base=L.Name(p and p.name);return plain(base or p and p.name or'Fellow adventurer',100)
end
local function place(p)
 local state=p and p.liveState
 if state and state.received and now()-state.received<=35 then
  local room=ns.WardenLocations81.Get(state.scene);if room then return room.title end
 end
 return'Exploring Aetheria'
end
function L.ProfileGUID(p)
 if not p then return end
 local guid=p.cert and p.cert.guid
 if ns.ChronicleStore.GUID(guid)then return guid,'CONNECTION_IDENTITY'end
 local runtime=L.runtime;local native=runtime and runtime.roster and runtime.roster[p.id]
 if native and ns.ChronicleStore.GUID(native.guid)then return native.guid,'NATIVE_GUILD_ROSTER'end
 -- A stale guild row without a GUID must not hide a fresh channel identity.
 native=L.Session.NativeIdentity(p.id)
 if native and ns.ChronicleStore.GUID(native.guid)then return native.guid,'NATIVE_CHANNEL_ROSTER'end
 -- E2 deliberately retains its selected credential for the current session.
 -- A later verified C2 certificate can supply the profile GUID without
 -- changing that credential, granting record authority or saving a sighting.
 local context=runtime and runtime.context;local saved=context and context.liveCredentials and context.liveCredentials[p.id]
 local cert=saved and saved.blob and ns.AetherCertificates.Certificate(saved.blob)
 if cert and p.cert and cert.public==p.cert.public and cert.scopes.community and ns.ChronicleStore.GUID(cert.guid)
  and L.Name(cert.name..'-'..cert.realm)==p.id and not ns.AetherCertificates.IsRevoked(context.ledger,cert)then
  return cert.guid,'VERIFIED_PUBLIC_CERTIFICATE'
 end
end
function L.OpenPlayer(id)
 local p=L.ConnectedPlayer(id)
 local function failed(message)
  L.lastProfileError=message
  ns.SafeCall(ns.Print,message)
  return false,message
 end
 if not p then return failed('This adventurer has left Live. Find your company in Players in Aether Live.')end
 local guid,source=L.ProfileGUID(p)
 if not ns.ChronicleStore.GUID(guid)then return failed('We are still confirming this adventurer’s character. Please try their profile again in a moment.')end
 L.lastProfileError=nil;L.lastProfileSource=source
 -- The normal Aether profile, keyed by the character's confirmed GUID.
 -- An old dossier date/scroll position must not turn this into a past view.
 local ok,why=U.Open({page='intel',kind='player',key=guid,owner=ns.Chronicle.Owner(),asOfSet=true,scroll=0})
 if not ok then return failed(why or'The profile could not open yet. Please try again in a moment.')end
 return ok,why
end
function L.People()U.Ensure();U.menuHidden=false;return U.Open({page='intel',subsection='live-players'})end
local function row(title,detail,activate,height)
 return{title=title,detail=detail,activate=activate,height=height or 54,wrap=true,stacked=true}
end
function L.PeopleBlocks()
 local _,title,detail=L.Status();local players={}
 for _,p in pairs(L.runtime and L.runtime.peers or{})do if connected(p)then players[#players+1]=p end end
 table.sort(players,function(a,b)return a.name<b.name end)
 local rows={row(title,detail,nil,86)}
 for _,p in ipairs(players)do local id=p.id;rows[#rows+1]=row(L.PlayerName(p),place(p)..' · Open Aether profile',function()L.OpenPlayer(id)end)end
 if #players==0 then rows[#rows+1]=row('Your company is on its way','Connected players will appear here, even when they are exploring another place. Discovery can take a little time.',nil,78)end
 rows[#rows+1]=row('Back to Olympus Hall','Your world and history are kept',function()U.Open({page='home'})end)
 return{{id='identity',title='Players in Aether Live',x=0,y=0,w=1,rows=rows}}
end
function L.Information()
 local state,title,detail=L.Status()
 return ns.UI2Forms.Form({title='Aether Live · Early access',help=title..'\n'..detail,fields={},paragraphs={
  'Live lets fellow adventurers see your character, where you are in Aetheria and what you do together. These moments of presence expire; they are not added to your private adventure history.',
  'When WoW can show the current player, Fireside uses that appearance. Otherwise some clothing, face, hair or forms may look approximate.',
  'Citizens bring Aetheria to life with their own routines. Shared activities will grow as Fireside grows.',
  'Leaving Live restores your private scene. Aether Relay keeps its existing settings.',
  'Fireside checks incoming connections before players appear. Your client does not independently confirm another player’s Olympus membership. Being connected never grants access to private adventure records.',
  'If someone is missing, use Find an adventurer in Settings. Only reachable players can connect; no global player list is promised.'},submitLabel='Copy connection diagnostics',submit=function()
   L.CopyDiagnostics()
   return true
  end})
end
local diagnosticsSlash=SlashCmdList and SlashCmdList.OLYMPUSCHATWARDEN
if diagnosticsSlash then SlashCmdList.OLYMPUSCHATWARDEN=function(message)
 local command=type(message)=='string'and message:lower():match('^%s*(.-)%s*$')
 if command=='diagnostics'or command=='aether diagnostics'then return L.CopyDiagnostics()end
 return diagnosticsSlash(message)
end end
local function enter()
 if not ns.Membership or ns.Membership.allowed~=true or(ns.Membership.method~='olympus-api'and ns.Membership.method~='olympus')then
  L.lastError='Olympus membership verification is required. The private Lab bypass does not authorize networking.';U.ShowVerification();return false,L.lastError
 end
 if ns.MainStorageBlocked then L.lastError='Saved data is protected. Recover it before joining Live.';return false,L.lastError end
 if not ns.Permissions.Resume('network',true)then return false,'Live participation was not authorized'end
 local key,keyReason=ns.AetherAutomaticEnrollment.EnsureKey('live')
 if not key then L.lastStartupError=keyReason;L.lastError='Your character key could not be prepared. Open connection details to see why.';L.pending={since=now(),nextCheck=now()+30,stage='KEY',code=keyReason};ns.AetherNative.Wake();L.RefreshStatus();return false,L.lastError end
 local client=L.Runtime();local ok,why=client:Start(true)
 if ok then
  L.lastError=nil;L.lastStartupError=nil;L.lastLost=nil;W.enterAt=now()
  if not(U.window and U.window:IsShown())then L.pending={since=now(),nextCheck=now()+5,stage='READY_ON_OPEN'};return true end
  local shown,reason=W.Enter()
  if shown then L.pending=nil;L.entryPending=true
  else client:Leave(reason);L.lastStartupError=reason;L.pending={since=now(),nextCheck=now()+10,stage='SCENE',code=reason}end
  L.RefreshStatus();return shown,reason
 end
 L.lastStartupError=why;L.lastError='Fireside could not start the Live connection. Open connection details to see why.'
 L.pending={since=now(),nextCheck=now()+30,stage='CONNECTION',code=why};ns.AetherNative.Wake();L.RefreshStatus();return false,L.lastError
end
function L.Exit()
 if ns.AetherServices then ns.AetherServices.SetDesired('live',false)end
 L.requested=nil;L.entryPending=nil;L.pending=nil;L.lastLost=nil;L.lastError=nil;L.lastStartupError=nil;local ok,why=W.Leave('Owner left Aether Live');L.RefreshStatus();return ok,why
end
function L.Join()
 U.Ensure()
 if W.phase=='leaving'then W.Leave('Finish Live exit before rejoining',true)
 elseif W.active or L.pending or W.phase=='entering'then return L.Exit()end
 if approved()then
  if ns.AetherServices then local ok,why=ns.AetherServices.SetDesired('live',true);if not ok then return false,why end end
  L.requested=true;local ok,why=enter();if not ok then ns.UI2Forms.Feedback(false,why)end;return ok,why
 end
 return ns.UI2Forms.Form({title='Enter Aether Live · Experimental',help='Explore Aetheria with fellow Olympus members. Aether Live is still growing, and some connections or appearances may be unavailable.',fields={},paragraphs={
  'Live shares your verified character identity, available appearance, Fireside scene, movement and basic public-object interactions with participating players. Presence expires and is never saved as an Athena history.',
  'Your remembered characters wait in your private world while Live is on. Leaving brings you back, with their records and your history kept.',
  'Joining Live also keeps approved community pages up to date. Publishing your own posts, profile or adventures stays a separate choice. Your private drafts and recordings are never published by joining.',
  'Your character name becomes visible in the Aether channel roster so players can find one another. Connections confirm the WoW sender and key; a temporary connection does not independently certify another player’s Olympus membership.',
  'Aether can keep catching up while the Fireside window is closed. Leave Live whenever you like. Saved pages stay available offline, but unavailable records cannot always be recovered.'},
  submitLabel='Agree and enter Aether Live',submit=function()
   if ns.MainStorageBlocked then return false,'Saved data is protected. No consent or database was replaced.'end
   ns.DB.aetherLiveConsent92={version=2,owner=ns.Permissions.Owner(),enabled=true};L.requested=true
   if ns.AetherServices then local ok,why=ns.AetherServices.SetDesired('live',true);if not ok then return false,why end end
   return enter()
  end})
end
function L.Withdraw()
 L.Exit()
 if ns.DB and not ns.MainStorageBlocked then ns.DB.aetherLiveConsent92=nil end
 return true
end
function L.WelcomeBusy()
 local guide=ns.WardenWelcomeGuide;local setup=ns.UI2Onboarding;local notes=ns.UI2PatchNotes
 return guide and(guide.Active()or guide.NeedsWelcome())or setup and setup.window and setup.window:IsShown()or notes and notes.window and notes.window:IsShown()or false
end
local pump=L.WorldPump
function L.WorldPump()
 if L.WelcomeBusy()then return end -- Retain consent; finish the welcome before entering a shared place.
 if W.phase=='live'then L.entryPending=nil end
 if L.pending and now()>=L.pending.nextCheck then
  L.pending.nextCheck=now()+5
  if not L.requested or not approved()or ns.Permissions.Denied('network')or ns.MainStorageBlocked then L.pending=nil;L.requested=nil;L.lastError='Live entry cancelled; your private world is kept.'
  elseif U.window and U.window:IsShown()then enter()end
  L.RefreshStatus()
 end
 pump()
end
function L.BeforeWindowHide()
 if L.requested and(L.entryPending or L.pending or W.active or W.phase=='entering')then
  L.entryPending=nil;L.pending={since=now(),nextCheck=now()+5,stage='RESUME_ON_OPEN'};ns.AetherNative.Wake()
 end
end
function L.ResumeRequested()
 if not approved()or ns.Permissions.Denied('network')or ns.MainStorageBlocked then return false end
 L.requested=true;return enter()
end
function L.Retry()
 if not approved()then return L.Join()end
 if ns.AetherServices then local ok,why=ns.AetherServices.SetDesired('live',true);if not ok then return false,why end end
 L.pending=nil;L.requested=true;return enter()
end
function L.FindPlayer()
 local forever=ns.AetherCertificates.Namespace()=='forever'
 return ns.UI2Forms.Form({title='Find an adventurer',help=forever and'Ask a fellow Fireside player for their first name and surname. You can find each other across layers and guilds; no layer name is needed.'or'Ask a fellow Fireside player for their character name and realm. A direct request can help you find each other across guilds.',fields={{key='peer',label=forever and'First name and surname'or'Character name and realm',value=''}},submitLabel='Find player',submit=function(values)
  local s=L.Runtime();if not s.enabled then if ns.AetherServices then ns.AetherServices.Require('live','find-player')end;return false,'Join Aether Live to look for an adventurer. Your pages remain open.'end
  local ok,why=s:Connect(values.peer,'OWNER_DIRECT_REQUEST');if not ok and why~='LIVE_KEY_PROOF_REQUIRED'and why~='VERIFIED_PEER_CERTIFICATE_REQUIRED'then return false,why end
  return true,'Looking for that adventurer. A confirmed reply is needed before they appear.'
 end})
end
local oldTools=U.OpenAetherTool
function U.OpenAetherTool(section)
 if section=='live-status'then L.Information();return true end
 if section=='live-players'then return L.People()end
 if section=='live-find'then return L.FindPlayer()end
 if section=='live-consent'then return ns.UI2Forms.Confirm('Withdraw Aether Live consent','Leave Live and ask again the next time you enter. Relay settings and history stay unchanged.',L.Withdraw)end
 return oldTools(section)
end
if U.aetherToolChoices then
 U.aetherToolChoices[#U.aetherToolChoices+1]={'live-status','Aether Live · connection status'}
 U.aetherToolChoices[#U.aetherToolChoices+1]={'live-players','Aether Live · players and profiles'}
 U.aetherToolChoices[#U.aetherToolChoices+1]={'live-find','Aether Live · find an adventurer'}
 U.aetherToolChoices[#U.aetherToolChoices+1]={'live-consent','Aether Live · withdraw consent'}
end
