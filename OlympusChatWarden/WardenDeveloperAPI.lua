-- Versioned preview facade. Installed addons share WoW's Lua VM: this limits
-- host disclosures/operations, not the privileges of hostile installed Lua.
local _,ns=...
local K=ns.AetherExtensionContracts;local I={registry={},MAX_EXTENSIONS=16};ns.WardenExtensions=I
local A={};local public=_G.OlympusWarden
if public~=nil and(type(public)~='table'or public.API~=nil)then I.blocked='PUBLIC_NAMESPACE_COLLISION';return end
public=public or{};_G.OlympusWarden=public;public.API=A
local handles=setmetatable({},{__mode='k'});local version={major=1,minor=0,patch=0,stage='SECURITY_PREVIEW'}
local reference='org.olympus.developer-example'
local scopes=K.Set('profile.local_page profile.public_read profile.public_card presence.discover activity.local activity.invite activity.network')
local function copy(v)return ns.Athena.Copy(v)end
local function owner()return ns.Chronicle.Owner()end
local function now()return ns.SafeCall(GetServerTime)or 0 end
local function dev()return WARDEN_SIMULATOR_ISOLATED==true or ns.WardenSimLab and ns.WardenSimLab.Enabled()or false end
local function settings(create)
 if not ns.DB then return end
 if not ns.DB.developerExtensions and create then ns.DB.developerExtensions={version=1,owners={}}end
 local root=ns.DB.developerExtensions
 if not K.Plain(root)or root.version~=1 or not K.Plain(root.owners)then return end
 local key=owner();if not key then return end;local p=root.owners[key]
 if not p and create then p={enabled={},grants={},remoteCards=false,participating=false,available=false,invitations=false,blocked={},publishers={},emergencyOff=false};root.owners[key]=p end
 if not K.Plain(p)or not K.Plain(p.enabled)or not K.Plain(p.grants)or not K.Plain(p.blocked)or not K.Plain(p.publishers)then return end
 return p
end
function I.Policy()local p=settings(false);return copy(p or{enabled={},grants={},blocked={},publishers={},remoteCards=false,participating=false,available=false,invitations=false,emergencyOff=false})end
local function allowed(h,scope)
 local e=handles[h];local p=settings(false)
 if not e then return nil,'INVALID_EXTENSION_HANDLE'end
 if e.manifest.id~=reference then return nil,'PUBLIC_SDK_DISABLED'end
 if not dev()then return nil,'DEVELOPER_CONTEXT_REQUIRED'end
 if e.failed then return nil,e.failed end
 if not p or p.emergencyOff or p.enabled[e.manifest.id]~=true then return nil,'EXTENSION_DISABLED'end
 if scope and(not e.permissions[scope]or not p.grants[e.manifest.id]or p.grants[e.manifest.id][scope]~=true)then return nil,'PERMISSION_DENIED'end
 return e,p
end
-- Limits are per installed extension and cannot enable a disabled SDK.
local function quota(e,key,limit,seconds)
 local at=now();e.quotas=e.quotas or{};local q=e.quotas[key]
 if not q or at<q.at or at-q.at>=seconds then q={at=at,n=0};e.quotas[key]=q end
 if q.n>=limit then return false end;q.n=q.n+1;return true
end
local function content(text,name)
 if name and ns.Shield and ns.Shield.IsShielded(name)then return false end
 if ns.Active and ns.Active('chat')then
  if not ns.Find or not ns.MatchAction then return false end
  local ok,m=pcall(ns.Find,text,false,{kind='player',sender=name})
  if not ok then return false end
  local valid,action=pcall(ns.MatchAction,m);if not valid or action=='Hidden'or action=='Redacted'or action=='Replaced'then return false end
 end
 return true
end
function I.Check(h,scope)return allowed(h,scope)end
function I.Handle(id)local e=I.registry[id];return e and e.handle end
function A:GetVersion()return copy(version)end
function A:GetCapabilities()
 return {api=copy(version),publicThirdPartySDK=false,mode='DEVELOPER_REFERENCE_ONLY',profileLocalPages=true,dataOnlyCards=true,activityContracts=true,
  nativeActivityVerified=false,privateData=false,remoteCode=false,bulkMessaging=false,globalDiscovery=false,
  aether=ns.AetherNative.Capabilities(),reason='Public SDK disabled pending security/native qualification. Owner consent and private developer mode are required for the reference extension.'}
end
function A:IsFeatureAvailable(name)return self:GetCapabilities()[name]==true end
function A:RegisterExtension(m,callbacks)
 if not K.Keys(m,K.Set('id addon publisher title version apiMajor minMinor permissions pageTitle cardSchema activitySchema'))or not K.ID(m.id)
  or not K.Text(m.addon or'',80)or m.addon==''or not K.Text(m.publisher or'',80)or not K.Text(m.title or'',80)
  or type(m.version)~='string'or not m.version:match('^%d+%.%d+%.%d+$')or #m.version>24 or m.apiMajor~=1
  or not K.Int(m.minMinor or 0,0,version.minor)or not K.Array(m.permissions,8)
  or m.pageTitle~=nil and not K.Text(m.pageTitle,48)or m.cardSchema~=nil and m.cardSchema~=1 or m.activitySchema~=nil and m.activitySchema~=1
  or not K.Keys(callbacks,K.Set('BuildProfilePage OnReady OnDisable'))then return nil,'MANIFEST_INCOMPATIBLE'end
 local permissions={};for _,scope in ipairs(m.permissions)do if not scopes[scope]or permissions[scope]then return nil,'UNKNOWN_OR_DUPLICATE_PERMISSION'end;permissions[scope]=true end
 for _,fn in pairs(callbacks)do if type(fn)~='function'then return nil,'LOCAL_CALLBACK_REQUIRED'end end
 local old=I.registry[m.id]
 if old then if old.callbacks==callbacks and old.manifest.version==m.version and old.manifest.addon==m.addon then return old.handle,'ALREADY_REGISTERED'end;return nil,'EXTENSION_ID_COLLISION'end
 local count=0;for _ in pairs(I.registry)do count=count+1 end;if count>=I.MAX_EXTENSIONS then return nil,'EXTENSION_LIMIT'end
 local h={};local e={manifest=copy(m),permissions=permissions,callbacks=callbacks,handle=h,state=m.id==reference and'DISABLED'or'PUBLIC_SDK_DISABLED',errors=0,calls=0}
 handles[h]=e;I.registry[m.id]=e;return h,e.state
end
function A:GetExtension(id)local e=I.registry[id];if not e then return nil,'NOT_INSTALLED'end;local valid,why=allowed(e.handle);return {manifest=copy(e.manifest),state=valid and'READY'or e.failed or why or e.state,errors=e.errors,calls=e.calls}end
function A:UnregisterExtension(h)
 local e=handles[h];if not e then return false,'INVALID_EXTENSION_HANDLE'end
 handles[h]=nil;I.registry[e.manifest.id]=nil;return true,'UNLOADED'
end
local function invoke(e,name,...)
 if ns.Checked(ns.SafeCall(InCombatLockdown))then return nil,'COMBAT_DEFERRED'end
 local at=ns.SafeCall(GetTime)or 0;local b=e.budget
 if not b or at-b.at>=1 then b={at=at,count=0};e.budget=b end
 if b.count>=10 then return nil,'CALLBACK_RATE_LIMIT'end;b.count=b.count+1;e.calls=e.calls+1
 local start=ns.SafeCall(debugprofilestop);local ok,result=pcall(e.callbacks[name],...);local stop=ns.SafeCall(debugprofilestop)
 if not ok or start and stop and stop-start>8 then
  e.errors=e.errors+1;e.failed=not ok and'CALLBACK_FAILED'or'CALLBACK_OVER_BUDGET'
  -- Never retain arbitrary callback error strings, which may contain secrets.
  return nil,e.failed
 end
 return result or true
end
function I.Configure(id,grant,confirmed)
 if not confirmed or not ns.Permissions.Decide('UIAccess')or not dev()then return false,'EXPLICIT_DEVELOPER_OWNER_REQUIRED'end
 local e=I.registry[id];if not e or id~=reference then return false,'PUBLIC_SDK_DISABLED'end
 local p=settings(true);if not p then return false,'PREFERENCES_UNAVAILABLE'end
 p.enabled[id]=grant==true;p.grants[id]={};e.failed=nil;e.pageCache=nil
 if grant then for key in pairs(e.permissions)do p.grants[id][key]=true end end
 e.state=grant and'READY'or'DISABLED'
 if e.callbacks[grant and'OnReady'or'OnDisable']then invoke(e,grant and'OnReady'or'OnDisable')end
 if ns.UI2 then ns.UI2.Refresh(true)end;return true,e.state
end
function I.Options(changes,confirmed)
 if not confirmed or not ns.Permissions.Decide('UIAccess')then return false,'EXPLICIT_OWNER_REQUIRED'end
 if not K.Keys(changes,K.Set('remoteCards participating available invitations emergencyOff'))then return false,'UNKNOWN_SETTING'end
 local p=settings(true);if not p then return false,'PREFERENCES_UNAVAILABLE'end
 for key,value in pairs(changes)do if type(value)~='boolean'then return false,'BOOLEAN_REQUIRED'end end
 for key,value in pairs(changes)do p[key]=value end
 return true
end
function I.Block(kind,id,value,confirmed)
 if not confirmed or not ns.Permissions.Decide('UIAccess')or type(value)~='boolean'then return false,'EXPLICIT_OWNER_REQUIRED'end
 if kind~='character'and kind~='publisher'then return false,'BLOCK_KIND'end
 if kind=='character'and not ns.ChronicleStore.GUID(id)or kind=='publisher'and not K.Token(id,128)then return false,'BLOCK_ID'end
 local p=settings(true);if not p then return false,'PREFERENCES_UNAVAILABLE'end
 p[kind=='character'and'blocked'or'publishers'][id]=value or nil;return true
end
function A:RequestPermissions(id)
 if not dev()or id~=reference or not I.registry[id]then return false,'PUBLIC_SDK_DISABLED'end
 local e=I.registry[id];local list=table.concat(e.manifest.permissions,', ')
 ns.UI2Forms.Confirm('Allow developer reference extension?',e.manifest.title..' requests: '..list..'. This does not grant private history access or enable the public SDK.',function()return I.Configure(id,true,true)end)
 return true,'OWNER_REVIEW_OPENED'
end
function A:GetPublicProfile(h,guid)
 local e,why=allowed(h,'profile.public_read');if not e then return nil,why end
 if not ns.ChronicleStore.GUID(guid)then return nil,'INVALID_SUBJECT'end
 if not quota(e,'read',120,60)then return nil,'EXTENSION_READ_QUOTA'end
 local p=settings(false);if p.blocked[guid]then return nil,'SUBJECT_BLOCKED'end
 local view=ns.AetherNet.ReadSubject('CHARACTER',guid);local out={guid=guid,identity={},scope='PUBLIC_SHARED_ONLY'}
 for _,key in ipairs({'name','realm','race','class','faction'})do local value=view.identity and view.identity[key];if type(value)=='string'and K.Text(value,80)then out.identity[key]=value end end
 if view.owner then if content(view.owner.about or'',out.identity.name)then out.about=view.owner.about end;out.gamerzone=view.owner.gamerzone end
 out.rating={average=view.rating.average,count=view.rating.count,kind='COMMUNITY_OPINION'};return out
end
function I.Page(id,guid,ownerScope)
 local e=I.registry[id];local valid,why=e and allowed(e.handle,'profile.local_page')
 local rows={};local blocks={{id='extensions',title=e and e.manifest.pageTitle or'Extension unavailable',x=0,y=0,w=1,rows=rows}}
 rows[1]={title='Return to player profile',detail='Same canonical player',height=36,activate=function()ns.UI2.OpenPlayer(guid,ownerScope)end}
 if not valid or not e.callbacks.BuildProfilePage then rows[#rows+1]={title=why or'EXTENSION_UNAVAILABLE',kind='caption'};return blocks end
 local prefs=settings(false);if prefs and prefs.blocked[guid]then rows[#rows+1]={title='SUBJECT_BLOCKED',kind='caption'};return blocks end
 local at=ns.SafeCall(GetTime)or 0;local cached=e.pageCache
 if cached and cached.guid==guid and cached.owner==ownerScope and cached.fn==e.callbacks.BuildProfilePage and at>=cached.at and at-cached.at<1 then return cached.blocks end
 local data,denial=A:GetPublicProfile(e.handle,guid);if not data then rows[#rows+1]={title=denial or'PROFILE_UNAVAILABLE',kind='caption'};return blocks end
 local host={};local n=0
 function host:Text(title,value)
  if n>=48 or not K.Text(title,64)or not K.Text(value or'',512)then error('HOST_ROW_BOUND')end;n=n+1
  rows[#rows+1]={title=title,detail=value,stacked=true,wrap=true,height=68}
 end
 function host:Button(label,fn)
  if n>=48 or not K.Text(label,48)or type(fn)~='function'then error('HOST_ACTION_BOUND')end;n=n+1
  rows[#rows+1]={title=label,height=38,activate=function()
   if not allowed(e.handle,'profile.local_page')then return end
   e.pageCache=nil;local old=e.callbacks.__action;e.callbacks.__action=fn;invoke(e,'__action');e.callbacks.__action=old;e.pageCache=nil
  end}
 end
 local ok,errorCode=invoke(e,'BuildProfilePage',copy(data),host)
 if not ok then rows={rows[1],{title=errorCode,kind='caption'}};blocks[1].rows=rows else e.pageCache={guid=guid,owner=ownerScope,at=at,fn=e.callbacks.BuildProfilePage,blocks=blocks}end
 return blocks
end
function I.ProfileBlocks(model,route,blocks)
 if route.extension then return I.Page(route.extension,model.key,model.owner)end
 local rows={}
 for id,e in pairs(I.registry)do if allowed(e.handle,'profile.local_page')and e.callbacks.BuildProfilePage then local key=id
  rows[#rows+1]={title=e.manifest.pageTitle or e.manifest.title,detail='Installed developer extension',height=40,activate=function()ns.UI2.Open({page='intel',kind='player',key=model.key,owner=model.owner,extension=key})end}
 end end
 table.sort(rows,function(a,b)return a.title<b.title end)
 local p=settings(false)
 if p and p.remoteCards and not p.emergencyOff then
  local view=ns.AetherNet.ReadSubject('CHARACTER',model.key)
  for _,card in ipairs(view.extensionCards or{})do if #rows<32 and not p.publishers[card.origin]and not p.blocked[model.key]and content(card.data.title..' '..card.data.text,view.identity and view.identity.name)then
   local d=card.data;rows[#rows+1]={title=d.title,detail=d.text..(d.score and' · '..d.score or'')..' · '..card.authentication,stacked=true,height=88,icon=ns.WardenArt.Path(K.icons[d.icon])}
  end end
 end
 if #rows>0 then
  local y=190;for _,b in ipairs(blocks)do if(b.x or 0)>=.6 then local height=44;for _,r in ipairs(b.rows or{})do height=height+(r.height or 31)end;y=math.max(y,(b.y or 0)+height+12)end end
  blocks[#blocks+1]={id='extensions',title='Approved extensions',x=.66,y=y,w=.34,rows=rows}
 end
 return blocks
end
function A:PublishProfileCard(h,card)
 local e,why=allowed(h,'profile.public_card');if not e then return nil,why end
 if not K.Plain(card)then return nil,'CARD_SCHEMA'end
 local p=settings(false);if p.emergencyOff then return nil,'EXTENSIONS_STOPPED'end
 local d=copy(card);d.version=1;d.schemaVersion=1;d.extension=e.manifest.id
 local valid,reason=K.Card(d);if not valid then return nil,reason end
 if not content(d.title..' '..d.text)then return nil,'EXISTING_CHAT_POLICY_REJECTED'end
 if not quota(e,'publish',4,60)then return nil,'EXTENSION_PUBLICATION_QUOTA'end
 if d.available or d.invitations then return nil,'ACTIVITY_AVAILABILITY_NOT_PUBLISHED_IN_SECURITY_PREVIEW'end
 local c,err=ns.AetherNet.PublicationClient();if not c then return nil,err end
 local guid=ns.PlayerCard.Own();local slot='sdk/'..d.extension..'/'..d.cardID
 local pair,id=c:Publish('CHARACTER',guid,'EXTENSION_CARD',slot,d,ns.AetherNet.NextRevision(c,'CHARACTER',guid,'EXTENSION_CARD',slot),false,true)
 if not pair then return nil,id end
 if c.Save then local ok,failure=c:Save();if not ok then return nil,failure end end
 return {id=id,state='LOCAL_COMMITTED',authority='OWNER_DECLARED_EXTENSION_CARD; NOT_OFFICIAL_ACHIEVEMENT',delivery='UNCONFIRMED'}
end
function A:DiscoverParticipants(h,activityType)
 local e,p=allowed(h,'presence.discover');if not e then return nil,p end
 if not K.ID(activityType)then return nil,'INVALID_ACTIVITY_TYPE'end
 if not p.participating or p.emergencyOff then return {},'PARTICIPATION_OFF'end
 -- No remote activity availability is advertised in this security preview.
 -- Existing acknowledged Warden sessions alone do not imply game consent.
 return {},'NO_VERIFIED_ACTIVITY_OPT_IN; NATIVE_PENDING'
end
function I.SettingsRows()
 local p=I.Policy();local rows={{title='Aether Developer API 1.0 · Security preview',detail='Public third-party SDK disabled. No Banner gameplay or automatic invitations.',wrap=true,height=64}}
 rows[#rows+1]={title='Stop all extension operations',detail=p.emergencyOff and'Stopped'or'No emergency stop',height=40,activate=function()I.Options({emergencyOff=not p.emergencyOff},true);ns.UI2.Refresh(true)end}
 for id,e in pairs(I.registry)do if dev()then local key=id;local enabled=p.enabled[id]==true
  rows[#rows+1]={title=e.manifest.title,detail=enabled and'Owner approved · revoke'or'Off · review permissions',height=48,activate=function()if enabled then I.Configure(key,false,true)else A:RequestPermissions(key)end end}
 end end
 rows[#rows+1]={title='Show approved data-only profile cards',detail=p.remoteCards and'On'or'Off',height=40,activate=function()I.Options({remoteCards=not p.remoteCards},true);ns.UI2.Refresh(true)end}
 return rows
end
