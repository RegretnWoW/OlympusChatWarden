-- One predicate layer over existing consent/settings, plus a deny-only safety
-- latch. No positive permission, key or evidence is stored in the latch.
local _,ns=...
local P={VERSION=1,revision=0};ns.Permissions=P
local function plain(v) return not (issecretvalue and issecretvalue(v)) and not (canaccessvalue and not canaccessvalue(v)) and type(v)=='table' and not getmetatable(v) and not (canaccesstable and not canaccesstable(v)) end
-- Permission metadata is read field-by-field. A history root can contain a
-- secret native observation while its consent scalars remain safely readable;
-- never iterate that root or treat this as permission to inspect its evidence.
local function object(v) return not (issecretvalue and issecretvalue(v)) and not (canaccessvalue and not canaccessvalue(v)) and type(v)=='table' and not getmetatable(v) end
local function field(t,key)
 if not object(t) then return end
 local ok,v=pcall(function() return t[key] end)
 if ok and not (issecretvalue and issecretvalue(v)) and not (canaccessvalue and not canaccessvalue(v)) then return v end
end
local fields={history=true,capture=true,conversations=true,incidents=true,network=true}
function P.Owner()
 local ok,guid=pcall(function() return UnitGUID('player') end)
 local good,realm=pcall(function() return GetRealmName() end)
 if ok and good and not (issecretvalue and (issecretvalue(guid) or issecretvalue(realm))) and not (canaccessvalue and (not canaccessvalue(guid) or not canaccessvalue(realm))) and type(guid)=='string' and guid:match('^Player%-[%w%-]+$') and type(realm)=='string' and #realm>0 then return realm..'/'..guid end
end
local function latch(create)
 local root=ns.Storage.OlympusWardenPrivacyDB
 if root==nil and create then root={version=1,all={},owners={}};ns.Storage.OlympusWardenPrivacyDB=root end
 if root==nil then return end
 if not plain(root) or root.version~=1 or not plain(root.all) or not plain(root.owners) then return nil,'UNSUPPORTED_DENY_RECORD' end
 for k,v in pairs(root.all) do if not fields[k] or type(v)~='boolean' then return nil,'INVALID_DENY_RECORD' end end
 local count=0;for owner,row in pairs(root.owners) do
  count=count+1;if count>64 or type(owner)~='string' or #owner>256 or not plain(row) then return nil,'INVALID_DENY_RECORD' end
  for k,v in pairs(row) do if not fields[k] or type(v)~='boolean' then return nil,'INVALID_DENY_RECORD' end end
 end
 return root
end
function P.Denied(scope,owner)
 local root,why=latch(false);if why then return true end
 if not root then return false end
 local row=root.owners[owner or P.Owner() or ''];if row and row[scope]~=nil then return row[scope]==true end;return root.all[scope]==true
end
function P.Deny(scope,owner,all)
 if not fields[scope] then return false,'UNKNOWN_PRIVACY_SCOPE' end
 local root,why=latch(true);if not root then return false,why end
 owner=owner or P.Owner();if all or not owner then root.all[scope]=true
 else
  if not root.owners[owner] then local n=0;for _ in pairs(root.owners) do n=n+1 end;if n>=64 then root.all[scope]=true else root.owners[owner]={} end end
  if root.owners[owner] then root.owners[owner][scope]=true end
 end
 P.revision=P.revision+1;return true
end
function P.Resume(scope,confirmed)
 if not fields[scope] or confirmed~=true or not P.Decide('UIAccess') then return false,'EXPLICIT_VERIFIED_OWNER_ACTION_REQUIRED' end
 if ns.MainStorageBlocked then return false,ns.MainStorageBlocked end
 local root,why=latch(false);if why then return false,why end
 if root then local owner=P.Owner();if not owner then return false,'OWNER_UNAVAILABLE' end;root.owners[owner]=root.owners[owner] or {};if root.all[scope] then root.owners[owner][scope]=false else root.owners[owner][scope]=nil end end
 P.revision=P.revision+1;return true
end
local function selected(id)
 local modules=ns.Modules;return not modules or modules.Enabled(id)
end
function P.HistoryConsent(saved)
 if ns.MainStorageBlocked then return false end
 saved=saved or ns.ChronicleStore and ns.ChronicleStore.PreferenceRoot and ns.ChronicleStore.PreferenceRoot() or ns.DB and ns.DB.chronicle
 return not P.Denied('history') and field(saved,'enabled')==true and field(saved,'consentVersion')==(ns.ChronicleStore and ns.ChronicleStore.CONSENT or 5) or false
end
function P.Decide(action,context)
 local db=ns.DB
 if action=='PrivacyEmergency' then return true end
 if action=='UIAccess' then return ns.Membership~=nil and ns.Membership.Allowed() end
 if action=='OfficialGuild' then return P.Decide('UIAccess') and ns.OlympusConnection and ns.OlympusConnection.state=='connected' or false end
 if action=='AetherParticipation' then return not P.Denied('network') and context and context.consent==ns.AetherNet.CONSENT and context.authorized==true or false end
 if ns.MainStorageBlocked and ({HistoryCollect=true,ChatCapture=true,ConversationCollect=true,IncidentCollect=true})[action] then return false end
 if not object(db) then return false end
 if action=='HistoryCollect' then return selected('history') and P.HistoryConsent(context and context.saved) end
 if action=='ChatFilter' then return selected('chat') and field(db,'enabled')==true end
 if action=='ShieldProtect' then return selected('shield') and (field(db,'shield')==nil or object(field(db,'shield')) and field(field(db,'shield'),'enabled')~=false) end
 if action=='SignalCollect' then return selected('alerts') and field(db,'alertsEnabled')~=false and not P.Denied('incidents') end
 if action=='ChatCapture' then return selected('chat') and not P.Denied('capture') and object(field(db,'chatCapture')) and field(field(db,'chatCapture'),'enabled')==true end
 if action=='ConversationCollect' then return not P.Denied('conversations') and P.Decide('HistoryCollect') end
 if action=='IncidentCollect' then return not P.Denied('incidents') and field(db,'history')~=false and field(db,'persistHistory')~=false end
 return false
end
function P.Background(module)
 if module=='chronicle' or module=='intel' or module=='history' then return P.Decide('HistoryCollect') end
 if module=='chat' then return P.Decide('ChatFilter') or P.Decide('ChatCapture') end
 if module=='shield' then return P.Decide('ShieldProtect') end
 if module=='alerts' then return P.Decide('SignalCollect') end
 return module=='core' or module=='command' or module=='relay'
end
