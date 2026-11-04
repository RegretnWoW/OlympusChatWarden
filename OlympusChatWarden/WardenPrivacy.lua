-- Scoped local deletion adapters. Preflight all supported roots before mutation;
-- unknown schemas are retained, and a refusal is never reported as an erase.
local _,ns=...
local V={VERSION=1};ns.Privacy=V
local function plain(t) return ns.Readable(t) and type(t)=='table' and not getmetatable(t) end
function V.Stop(all)
 local durable=true
 for _,scope in ipairs({'history','capture','conversations','incidents'}) do if not ns.Permissions.Deny(scope,nil,all) then durable=false end end
 -- The deny latch is effective even if these richer stores cannot be edited.
 local db=ns.DB
 if plain(db) then
  if plain(db.chatCapture) then db.chatCapture.enabled=false end
  if plain(db.chronicle) then db.chronicle.enabled=false end
 end
 if ns.ChatCapture and plain(ns.ChatCapture.db) then ns.ChatCapture.db.enabled=false end
 if ns.Chronicle then ns.Chronicle.SetEnabled(false);ns.Chronicle.RefreshGate() end
 if ns.ChronicleStartup then ns.ChronicleStartup.Cancel() end
 if ns.ChronicleStartupLegacy then ns.ChronicleStartupLegacy.Cancel() end
 if ns.AthenaConversations then ns.AthenaConversations.ResetRuntime() end
 if ns.Modules then ns.Modules.dirty=true;ns.Modules.Reconcile() end
 return durable,durable and 'All local capture stopped. Filtering and Shield preferences are unchanged. Saved archives are retained.' or 'Capture is blocked by an unsupported emergency-deny record. Preserve that record; repair is required before explicit resumption.'
end
function V.Withdraw()
 local ok,why=ns.Permissions.Deny('network')
 local c=ns.AetherNet.Current;if c then c:Leave() end
 local saved,reason=ns.AetherNet.SetPreference(false)
 if ok then return true,saved and 'Aether participation is OFF. Existing peer copies cannot be recalled.' or 'Aether is durably OFF. Rich preferences need recovery and were preserved: '..tostring(reason) end
 return false,why or reason
end
local function shape(root,version,field)
 return root==nil or plain(root) and root.version==version and plain(root[field])
end
local function rows(map)
 if map==nil then return true end
 if not plain(map) then return false end
 for _,row in pairs(map) do if not plain(row) then return false end end
 return true
end
function V.Preflight(scope)
 if scope~='owner' and scope~='all' then return false,'Choose current character or all characters.' end
 local owner=ns.Permissions.Owner();if scope=='owner' and not owner then return false,'Current owner identity is unavailable; no data was removed.' end
 local d=ns.DB;local S=ns.ChronicleStore
 if ns.MainStorageBlocked then return false,ns.MainStorageBlocked end
 if not plain(d) then return false,'Main settings need recovery; no data was removed.' end
 if ns.UI2LayoutEngine and not ns.UI2LayoutEngine.PrivacyPreflight() then return false,'Private presentation drafts need recovery; originals retained.' end
 for _,field in ipairs({'journalDrawings','developerExtensions','agora','journalArtifacts'})do if not shape(d[field],1,'owners')or d[field]and not rows(d[field].owners)then return false,'Private '..field..' needs recovery; originals retained.'end end
 local history=d.chronicle
 if history~=nil and (not plain(history) or history.schema~=S.VERSION or not plain(history.characters)) then return false,'Chronicle schema is unsupported; original archive retained.' end
 local startup=ns.Storage.OlympusWardenStartupDB
 if startup~=nil and (not plain(startup) or (startup.version~=1 and startup.version~=2) or not plain(startup.characters)
  or startup.legacy~=nil and not shape(startup.legacy,1,'characters')) then return false,'Recovery journal schema is unsupported; original journal retained.' end
 if not shape(ns.Storage.OlympusWardenConversationDB,1,'owners') then return false,'Conversation archive schema is unsupported; original retained.' end
 if not shape(ns.Storage.OlympusWardenRecollectionsDB,1,'owners') then return false,'Recollection schema is unsupported; original retained.' end
 if not shape(ns.Storage.OlympusWardenJournalDB,1,'pages') then return false,'Journal snapshot schema is unsupported; original retained.' end
 for _,root in ipairs({ns.Storage.OlympusWardenConversationDB or {},ns.Storage.OlympusWardenRecollectionsDB or {}}) do
  if not rows(root.owners) then return false,'Private owner records need recovery; originals retained.' end
 end
 if ns.Storage.OlympusWardenConversationDB then for _,row in pairs(ns.Storage.OlympusWardenConversationDB.owners) do
  if row.order~=nil and not plain(row.order) then return false,'Conversation order needs recovery; originals retained.' end
 end end
 if ns.Storage.OlympusWardenJournalDB and ns.AthenaLibraryEditions and not ns.AthenaLibraryEditions.Validate(ns.Storage.OlympusWardenJournalDB.editions) then return false,'Saved editions need recovery; originals retained.' end
 if ns.Storage.OlympusWardenJournalDB and not rows(ns.Storage.OlympusWardenJournalDB.pages) then return false,'Reading copies need recovery; originals retained.' end
 for _,field in ipairs({'journalReadingPlaces','journalReaderPlacesV2','activityRunSeparations','playerCards','dossierViews'}) do
  if not rows(d[field]) then return false,'Local '..field..' records need recovery; originals retained.' end
 end
 if d.journalEditions~=nil then
  if not plain(d.journalEditions) then return false,'Journal edition map needs recovery; original retained.' end
  for _,edition in pairs(d.journalEditions) do if not S.Integer(edition,0,1000000) then return false,'Journal edition value needs recovery; original retained.' end end
 end
 if d.characterHistory~=nil and (not plain(d.characterHistory) or not rows(d.characterHistory.characters)) then return false,'Character snapshot records need recovery; originals retained.' end
 local exchange=ns.Storage.OlympusWardenExchangeDB
 if exchange~=nil and (not plain(exchange) or exchange.schema~=1 or not plain(exchange.characters)
  or exchange.netClients~=nil and (not plain(exchange.netClients) or exchange.netClients.schema~=2 or not plain(exchange.netClients.owners))
  or exchange.netLocal~=nil and (not plain(exchange.netLocal) or exchange.netLocal.schema~=1 or not plain(exchange.netLocal.owners))) then return false,'Exchange/private draft schema is unsupported; original retained.' end
 if exchange and exchange.extensionActivities and(not plain(exchange.extensionActivities)or exchange.extensionActivities.version~=1 or not rows(exchange.extensionActivities.owners))then return false,'Extension preview state needs recovery; originals retained.'end
 if exchange and exchange.netLocal and not rows(exchange.netLocal.owners) then return false,'Private draft owners need recovery; originals retained.' end
 if scope=='owner' and exchange and exchange.aetherCredentials~=nil and (not plain(exchange.aetherCredentials) or exchange.aetherCredentials.schema~=1 or not rows(exchange.aetherCredentials.owners)) then return false,'Character credentials need recovery; sharing stopped and originals retained.' end
 if d.athena~=nil and (not plain(d.athena) or d.athena.operational~=nil and (not plain(d.athena.operational) or not rows(d.athena.operational.decisions) or not rows(d.athena.operational.actions))) then return false,'Operational history needs recovery; originals retained.' end
 local relay=ns.Storage.OlympusWardenRelayDB
 if scope=='all' and relay~=nil and (not plain(relay) or relay.schema~=ns.RelayStore.SCHEMA or not plain(relay.reports) or not plain(relay.inbox)) then return false,'Relay schema is unsupported; original retained.' end
 return true,owner
end
function V.Erase(scope,confirmation)
 if confirmation~=(scope=='all' and 'CLEAR ALL' or 'CLEAR') then return false,'Exact deletion confirmation required.' end
 V.Stop(scope=='all');V.Withdraw()
 local ok,owner=V.Preflight(scope);if not ok then return false,'Capture/sharing stopped. Erase refused: '..tostring(owner) end
 local recoveryCommit
 if ns.FiresideSavedData then
  if scope=='all'then recoveryCommit=ns.FiresideSavedData.PurgeRecovery
  else
   local prepared,commit=pcall(ns.FiresideSavedData.PrepareOwnerErase,owner)
   if not prepared then return false,'Capture/sharing stopped. Erase refused; recovery files retained: '..tostring(commit)end
   recoveryCommit=commit
  end
 end
 local all=scope=='all';local d=ns.DB;local guid=owner and owner:match('/(Player%-.+)$')
 if ns.UI2LayoutEditor then ns.UI2LayoutEditor.Cancel(false) end
 if ns.UI2LayoutEngine then if all then if plain(d.ui2Layouts) then d.ui2Layouts.subjects={} end else ns.UI2LayoutEngine.ClearOwned(owner) end end
 local function remove(map,key) if not plain(map) then return end;if all then for k in pairs(map) do map[k]=nil end elseif key then map[key]=nil end end
 ns.ChronicleStore.CancelLoad();ns.ChronicleStore.CancelArchives();ns.ChronicleStartup.Cancel();ns.ChronicleStartupLegacy.Cancel()
 if ns.ChronicleBackup then ns.ChronicleBackup.Cancel() end
 local journal=ns.ChronicleStartupJournal;if journal then journal.Reset() end
 if plain(d.merchantHistoryConsent) then remove(d.merchantHistoryConsent.owners,owner) elseif all then d.merchantHistoryConsent=nil end
 if ns.ChronicleMerchant then ns.ChronicleMerchant.Stop() end
 if plain(d.chronicle) then remove(d.chronicle.characters,owner);d.chronicle.enabled=false end
 if ns.ChronicleStore.db and ns.ChronicleStore.db~=d.chronicle then remove(ns.ChronicleStore.db.characters,owner) end
 if ns.Storage.OlympusWardenStartupDB then remove(ns.Storage.OlympusWardenStartupDB.characters,owner);if ns.Storage.OlympusWardenStartupDB.legacy then remove(ns.Storage.OlympusWardenStartupDB.legacy.characters,owner) end end
 if ns.Storage.OlympusWardenConversationDB then remove(ns.Storage.OlympusWardenConversationDB.owners,owner)
  local bytes,moments=0,0;for _,r in pairs(ns.Storage.OlympusWardenConversationDB.owners) do
   if type(r)=='table' then moments=moments+#(r.order or {});bytes=bytes+#ns.Reports.JSON(r) end
  end
  local recounted,counted=ns.AthenaConversations.Recount(ns.Storage.OlympusWardenConversationDB)
  ns.Storage.OlympusWardenConversationDB.bytes=recounted or bytes;ns.Storage.OlympusWardenConversationDB.moments=counted or moments
 end
 if ns.Storage.OlympusWardenRecollectionsDB then remove(ns.Storage.OlympusWardenRecollectionsDB.owners,owner) end
 if ns.Storage.OlympusWardenJournalDB then
  for k,row in pairs(ns.Storage.OlympusWardenJournalDB.pages) do if all or plain(row) and row.owner==owner then ns.Storage.OlympusWardenJournalDB.pages[k]=nil end end
  for k,row in pairs(ns.Storage.OlympusWardenJournalDB.editions and ns.Storage.OlympusWardenJournalDB.editions.byID or {}) do if all or row.owner==owner then ns.Storage.OlympusWardenJournalDB.editions.byID[k]=nil end end
 end
 for _,field in ipairs({'journalReadingPlaces','journalReaderPlacesV2','journalEditions','activityRunSeparations','playerCards','dossierViews'}) do remove(d[field],field=='playerCards' and guid or owner) end
 if plain(d.characterHistory) then remove(d.characterHistory.characters,guid and 'guid:'..guid) end
 if plain(d.agora)and plain(d.agora.owners)then remove(d.agora.owners,guid)end
 if plain(d.journalDrawings)and plain(d.journalDrawings.owners)then remove(d.journalDrawings.owners,owner)end
 if plain(d.journalArtifacts)and plain(d.journalArtifacts.owners)then remove(d.journalArtifacts.owners,owner)end
 if d.developerExtensions and plain(d.developerExtensions)and plain(d.developerExtensions.owners)then remove(d.developerExtensions.owners,owner)end
 local exchange=ns.Storage.OlympusWardenExchangeDB
 if exchange then
  if exchange.extensionActivities then remove(exchange.extensionActivities.owners,owner)end
  if all then exchange.aetherCredentials=nil elseif plain(exchange.aetherCredentials)then remove(exchange.aetherCredentials.owners,guid)end
  remove(exchange.characters,guid);if exchange.netClients then remove(exchange.netClients.owners,guid) end
  if exchange.netLocal then for key,row in pairs(exchange.netLocal.owners) do if all or row.owner==owner then exchange.netLocal.owners[key]=nil end end end
 end
 if ns.AetherNet.ForgetLocal then ns.AetherNet.ForgetLocal(all and nil or guid) end
 if ns.AthenaExchangeState.ForgetLocal then ns.AthenaExchangeState.ForgetLocal(all and nil or guid) end
 ns.AthenaConversations.ResetRuntime();if ns.WardenBookbinder then ns.WardenBookbinder.ResetPrivacyRuntime()end;if ns.WardenMementos then ns.WardenMementos.ResetRuntime()end;if ns.WardenStudio then ns.WardenStudio.ResetPrivacyRuntime()end;if ns.WardenDrawing then ns.WardenDrawing.ResetPrivacyRuntime()end;ns.AthenaReadingSnapshots.packedFirst=nil
 if not all and plain(d.athena) and plain(d.athena.operational) then
  local op=d.athena.operational;for _,field in ipairs({'decisions','actions'}) do local rows={};for _,r in ipairs(op[field] or {}) do if r.observer~=guid then rows[#rows+1]=r end end;op[field]=rows end
 end
 if all then
  if ns.ChatCapture.db then ns.ChatCapture.db.entries={};ns.ChatCapture.db.bookmarks={};ns.ChatCapture.db.enabled=false end
  if plain(d.chatCapture) then d.chatCapture.entries={};d.chatCapture.bookmarks={};d.chatCapture.enabled=false end
  d.athena=nil
  d.personalReports={}
  if ns.Personal then ns.Personal.reports=d.personalReports;ns.Personal.reportBytes=0;ns.Personal.nextReportID=0 end
  if ns.Storage.OlympusWardenRelayDB then ns.Storage.OlympusWardenRelayDB.reports={};ns.Storage.OlympusWardenRelayDB.inbox={};ns.Storage.OlympusWardenRelayDB.serial=0 end
  if ns.RelayStore then ns.RelayStore.db=ns.Storage.OlympusWardenRelayDB end
 end
 -- Runtime evidence must not later flush deleted content back into saved data.
 if ns.History.ResetPrivacyRuntime then ns.History.ResetPrivacyRuntime() end
 if ns.AthenaAdventureEvidence then ns.AthenaAdventureEvidence.Clear() end
 if ns.AthenaCastCounts then ns.AthenaCastCounts.Clear() end
 ns.ChronicleActivities.Clear();ns.Athena.ClearHistoryContext();ns.UI2Models.Clear()
 if ns.AthenaJournalWindow then ns.AthenaJournalWindow.Invalidate() end
 if ns.UI2 then ns.UI2.model=nil;ns.UI2.back={};ns.UI2.forward={};ns.UI2.pendingVerifiedRoute=nil end
 V.last={scope=scope,owner=owner,completed=true}
 if recoveryCommit then recoveryCommit()end
 return true,all and 'All supported local capture/history, private notes, conversations, reading copies, drafts, exchange caches and local Relay records erased. Rules, protection settings and remote copies remain.'
  or 'Current character’s owner-scoped local history and private stores erased. Other characters and unscoped shared capture/Relay records remain; use CLEAR ALL to erase those.'
end
