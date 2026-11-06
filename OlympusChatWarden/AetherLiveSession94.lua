-- Temporary Live identity only. No authority grant, certificate import, record
-- authoring, historical capture or Relay preference is created by this module.
local _,ns=...
local L,C,X,A=ns.AetherLive,ns.AetherCertificates,ns.AetherCrypto,ns.AetherNative
local T={VERSION=1};L.Session=T
local function now()return ns.SafeNumber(ns.SafeCall(GetTime))or 0 end
local function hex(v,n)return type(v)=='string'and #v==n and not v:find('[^a-f0-9]')end
local function hash(v)return ns.PackCrypto.Hex(ns.PackCrypto.SHA256(v))end
local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
function T.Authorized()
 local r=ns.DB and ns.DB.aetherLiveConsent92;local m=ns.Membership
 return not ns.MainStorageBlocked and m and m.allowed==true and(m.method=='olympus-api'or m.method=='olympus')
  and r and r.version==2 and r.owner==ns.Permissions.Owner()and r.enabled==true and not ns.Permissions.Denied('network')or false
end
function T.LocalIdentity(me,material)
 return {id=hash('LIVE-ONLY/1\n'..C.Namespace()..'\n'..me.id..'\n'..material.public),public=material.public,
  principal=C.Principal(me.base,me.realm),guid=me.guid,liveOnly=true,scopes={live=true},trust='NATIVE_NAME_SESSION'}
end
function T.Resolve(id,c,native)
 local p=c.liveSessions and c.liveSessions[id]
 if not p or not p.liveOnly or p.expires<=now()or not p.scopes.live then return nil,'LIVE_KEY_PROOF_REQUIRED'end
 if native and p.guid and native.guid~=p.guid then return nil,'LIVE_NATIVE_IDENTITY_CHANGED'end
 if p.guid and C.IsRevoked(c.ledger,{guid=p.guid,keyID=hash(p.public)})then return nil,'PEER_KEY_REVOKED'end
 return p
end
local directory={status='NOT_STARTED',identities={},users=setmetatable({},{__mode='k'})};T.directory=directory
local function channelName()return C.Namespace()=='forever'and'FiresideAether'or'FiresideAetherTest'end
local function nativeChannel()
 if type(GetChannelName)~='function'then return end
 local ok,id,name=pcall(GetChannelName,channelName())
 if ok and type(id)=='number'and id>0 and type(name)=='string'and name:lower()==channelName():lower()then return id end
end
-- Chat channel numbers and the Channels window's display indices are different
-- namespaces. Blizzard's roster API consumes the latter (headers count too).
local function channelDisplay(channel)
 if type(GetNumDisplayChannels)~='function'or type(GetChannelDisplayInfo)~='function'then return end
 local n=ns.SafeNumber(ns.SafeCall(GetNumDisplayChannels))or 0
 for i=1,math.min(128,n)do
  local row={pcall(GetChannelDisplayInfo,i)}
  if row[1]and ns.CanRead(row[2])and row[2]:lower()==channelName():lower()and row[3]==false and row[5]==channel then
   -- Forever lists a joined channel before subscribing to its roster. A nil
   -- member count is pending data, not a missing or mismatched channel.
   local members=ns.SafeNumber(row[6]);return i,members and math.min(1000,math.max(0,members))or nil
  end
 end
end
function T.NativeIdentity(id)
 local p=directory.identities[id]
 if p and p.expires>now()and nativeChannel()==directory.channel then
  local display=channelDisplay(directory.channel);if not display or display~=directory.displayIndex then return end
  local roster=C_ChatInfo and C_ChatInfo.GetChannelRosterInfo or GetChannelRosterInfo
  if type(roster)~='function'then return end
  local row={pcall(roster,display,p.index)};local name=row[2]
  if row[1]and ns.CanRead(name)then
   if not name:find('-',1,true)then name=name..'-'..tostring(ns.SafeCall(GetRealmName)or'')end
   local current=L.Name(name)
   if current==id and row[5]==p.guid and ns.ChronicleStore.GUID(p.guid)then return p end
  end
 end
end
local function directoryPump(s,d)
 local t=d.clock()
 directory.pumpCalls=(directory.pumpCalls or 0)+1;directory.lastPumpAt=t
 directory.users[s]=true
 if directory.owner~=s.context.owner then
  directory.owner=s.context.owner;directory.identities={};directory.cursor=1;directory.nextJoin=0;directory.nextScan=0
 end
 local roster=C_ChatInfo and C_ChatInfo.GetChannelRosterInfo or GetChannelRosterInfo
 local join=JoinTemporaryChannel or JoinChannelByName or C_ChatInfo and C_ChatInfo.JoinTemporaryChannel
 if type(roster)~='function'or type(GetNumDisplayChannels)~='function'or type(GetChannelDisplayInfo)~='function'or type(GetChannelName)~='function'or type(join)~='function'then directory.status='GUILD_AND_DIRECT_ONLY';return end
 local channel=nativeChannel()
 if not channel then
  if t>=(directory.nextJoin or 0)then
   directory.nextJoin=t+60;directory.status='JOINING_REALM_CHANNEL'
   directory.joinAttempts=(directory.joinAttempts or 0)+1
   local ok,value=pcall(join,channelName());directory.joinResult=not ok and'API_EXCEPTION'or value==false and'REJECTED'or'REQUESTED'
   if not ok or value==false then directory.status='REALM_CHANNEL_UNAVAILABLE'else directory.joined=true end
  end
  return
 end
 if directory.channel~=channel then directory.identities={};directory.cursor=1;directory.displayIndex=nil end
 directory.channel=channel
 if t<(directory.nextScan or 0)then return end
 local display,n=channelDisplay(channel)
 if not display then directory.status='WAITING_FOR_CHANNEL_ROSTER';directory.nextScan=t+2;directory.identities={};directory.displayIndex=nil;return end
 if directory.channel~=channel or directory.displayIndex~=display then directory.identities={};directory.cursor=1 end
 directory.displayIndex=display;directory.members=n
 if n==nil then
  directory.status='REQUESTING_CHANNEL_ROSTER';directory.nextScan=t+2
  if t>=(directory.nextRosterRequest or 0)then
   directory.nextRosterRequest=t+30;directory.rosterRequests=(directory.rosterRequests or 0)+1
   local select=SetSelectedDisplayChannel
   if type(select)=='function'then
    if not directory.selection then
     local previous=ns.SafeNumber(ns.SafeCall(GetSelectedDisplayChannel));local row=previous and{pcall(GetChannelDisplayInfo,previous)}
     directory.selection={display=display,previous=previous,name=row and row[1]and row[2],channel=row and row[5]}
    end
    directory.selection.display=display
    local ok,value=pcall(select,display);directory.rosterRequestResult=not ok and'API_EXCEPTION'or value==false and'REJECTED'or'REQUESTED'
   else directory.rosterRequestResult='API_UNAVAILABLE'end
  end
  return
 end
 directory.status='REALM_CHANNEL_JOINED'
 local scanned=0
 while directory.cursor<=n and scanned<12 do
  local row={pcall(roster,display,directory.cursor)};directory.cursor=directory.cursor+1;scanned=scanned+1;directory.rowsScanned=(directory.rowsScanned or 0)+1
  if not row[1]then directory.rosterErrors=(directory.rosterErrors or 0)+1 end
  if row[1]and ns.CanRead(row[2])then
   local name=row[2];if not name:find('-',1,true)then name=name..'-'..s.context.me.realm end
   local id,display,base,realm=d.name(name)
   if id and id~=s.context.me.id then
    local guid=row[5];guid=ns.Readable(guid)and ns.ChronicleStore.GUID(guid)and guid or nil
    if count(directory.identities)<128 or directory.identities[id]then directory.identities[id]={id=id,name=display,base=base,realm=realm,guid=guid,index=directory.cursor-1,expires=t+120,source='native-channel-roster'}end
    if count(s.peers)<20 and not s.peers[id]then s:Connect(display,'REALM_CHANNEL_ROSTER')end
   end
  end
 end
 if directory.cursor>n then
  directory.cursor=1;directory.nextScan=t+(directory.dirty and 2 or 60);directory.dirty=nil
  for id,p in pairs(directory.identities)do if p.expires<=t then directory.identities[id]=nil end end
 end
end
function T.Event(kind,index)
 if(kind=='CHANNEL_ROSTER_UPDATE'or kind=='CHANNEL_COUNT_UPDATE')and type(index)=='number'and directory.displayIndex and index~=directory.displayIndex then return end
 if kind=='CHANNEL_ROSTER_UPDATE'or kind=='CHANNEL_COUNT_UPDATE'or kind=='CHANNEL_UI_UPDATE'or kind=='CHAT_MSG_CHANNEL_NOTICE'then
  -- Coalesce events; never throw away an in-progress scan on every roster tick.
  directory.dirty=true;directory.nextScan=math.min(directory.nextScan or 0,now()+2)
 end
end
local function wire(namespace,sender,recipient,source,destination,nonce,key,public)
 return table.concat({'AETHER-LIVE-SESSION/1',namespace,sender,recipient,source,destination,nonce,key,public},'\n')
end
function T.Attach(s,d)
 local certificate=d.certificate
 function s:IngressCredential(id,key,session)
  local cert=d.certificate(id,self.context)
  if cert and cert.id:sub(1,16)==key and(not cert.liveOnly or cert.session==session)then return cert end
  local enrolled=certificate(id,self.context)
  if enrolled and not enrolled.liveOnly and enrolled.id:sub(1,16)==key then return enrolled end
  local native=self.roster[id]or T.NativeIdentity(id)
  local temporary=T.Resolve(id,self.context,native)
  if temporary and temporary.id:sub(1,16)==key and temporary.session==session and(not cert or cert.public==temporary.public)then return temporary end
  return nil
 end
 d.certificate=function(id,c)
  local cert,why=certificate(id,c);if why=='PEER_KEY_REVOKED'then return nil,why end
  local native=c.roster and c.roster[id]or T.NativeIdentity(id)
  local temporary=T.Resolve(id,c,native);local preferred=s.peers[id]and s.peers[id].cert
  -- C2 and E2 can finish in either order. Once the peer begins a session,
  -- retain its chosen credential ID for that session when the validated
  -- public certificate proves the same key/tag. Revocation always wins and
  -- this does not upgrade a temporary identity into a record authority.
  if cert and preferred and preferred.liveOnly and temporary and preferred.id==temporary.id
   and cert.public==temporary.public then return temporary end
  if cert then return cert end;return temporary,why or'LIVE_KEY_PROOF_REQUIRED'
 end
 local request=s.RequestCredential
 local function send(text,p)
  if not s.enabled or not s.Valid()then return false end
  return s.QueueControl(text,{id=p.id,name=p.name,publicCredentialReply=true},'WHISPER',nil,true)
 end
 local function ask(p)
  if not s.enabled or not s.Valid()or d.clock()<(p.liveKeyRetry or 0)then return false end
  p.liveKeyRetry=d.clock()+15;s.liveKeySerial=(s.liveKeySerial or 0)+1
  local nonce=d.hash(s.session..'/'..s.liveKeySerial..'/'..p.id..'/'..d.clock()):sub(1,12)
  p.liveKeyRequest={nonce=nonce,untilAt=d.clock()+45,session=s.session}
  return send('E2|GET|'..s.session..'|'..nonce,p)
 end
 function s:RequestCredential(p)
  -- Keep the existing public authority-certificate exchange for old/enrolled
  -- peers. The separate E2 proof never enters Certificate() or Relay storage.
  if request and(self.context.cert.blob or ns.AetherUnified and ns.AetherUnified.Available())then request(self,p)end
  return ask(p)
 end
 function s:SessionIngress(text,channel,id,display)
  if text:sub(1,3)~='E2|'then return false end
  local function reject()self.metrics.rejected=self.metrics.rejected+1;return true end
  if channel~='WHISPER'then return reject()end
  local p=self.SessionPeer(display,'NATIVE_SENDER_KEY_PROOF');if not p then return reject()end
  if d.clock()-(p.liveKeyRateAt or-100)>=30 then p.liveKeyRateAt=d.clock();p.liveKeyRate=0 end
  p.liveKeyRate=(p.liveKeyRate or 0)+1;if p.liveKeyRate>12 then return reject()end
  local source,nonce=text:match('^E2|GET|([a-f0-9]+)|([a-f0-9]+)$')
  if source then
   if not hex(source,12)or not hex(nonce,12)or d.clock()<(p.liveKeyReplyAt or 0)then return reject()end
   p.liveKeyReplyAt=d.clock()+5;local session=self.session;local context=self.context
   self.CryptoJob(function()
    local key=context.cert.id:sub(1,16)
    local unsigned=wire(C.Namespace()..'/'..(d.purpose or'live'),context.me.id,id,session,source,nonce,key,context.material.public)
    local sig=d.sign(context,unsigned)
    if not self.enabled or self.session~=session or not sig then return end
    send(table.concat({'E2','K',session,source,nonce,key,context.material.public,sig},'|'),p)
    if not d.certificate(id,context)then ask(p)end
   end)
   return true
  end
  local destination,key,public,signature
  source,destination,nonce,key,public,signature=text:match('^E2|K|([a-f0-9]+)|([a-f0-9]+)|([a-f0-9]+)|([a-f0-9]+)|([a-f0-9]+)|([a-f0-9]+)$')
  local wanted=p.liveKeyRequest
  if not hex(source,12)or not hex(destination,12)or not hex(nonce,12)or not hex(key,16)or not hex(public,64)or not hex(signature,128)
   or destination~=self.session or not wanted or wanted.session~=self.session or wanted.nonce~=nonce or wanted.untilAt<d.clock()or p.liveKeyBusy then return reject()end
  p.liveKeyBusy=true;local session=self.session
  local context=self.context
  if not self.CryptoJob(function()
   if not self.enabled or self.session~=session or not self.Valid()then p.liveKeyBusy=nil;return end
   local valid=d.verify({public=public},wire(C.Namespace()..'/'..(d.purpose or'live'),id,context.me.id,source,session,nonce,key,public),signature)
   p.liveKeyBusy=nil
   if not valid or not self.enabled or self.session~=session or p.liveKeyRequest~=wanted or wanted.untilAt<d.clock()then reject();return end
   local native=self.roster[id]or T.NativeIdentity(id)
   local _,_,base,realm=d.name(display)
   local identity={id=key..d.hash('LIVE-ONLY/1\n'..C.Namespace()..'\n'..id..'\n'..public):sub(17),public=public,
    principal=C.Principal(base,realm),guid=native and native.guid or nil,scopes={live=true},liveOnly=true,
    session=source,expires=d.clock()+180,trust='NATIVE_NAME_SESSION',affiliation='NOT_REMOTELY_ATTESTED'}
   if identity.guid and C.IsRevoked(self.context.ledger,{guid=identity.guid,keyID=d.hash(public)})then reject();return end
   self.context.liveSessions=self.context.liveSessions or{};self.context.liveSessions[id]=identity;p.liveKeyRequest=nil;p.nextAttempt=0
   if p.session and p.session~=source then
    p.session=nil;p.hello=nil;p.expires=nil;p.cert=nil;p.status='DISCOVERED'
    for nonce,r in pairs(self.pending)do if r.peer==p then self.pending[nonce]=nil end end
   end
   self:Connect(display,'NATIVE_SENDER_KEY_PROOF')
  end)then p.liveKeyBusy=nil end
  return true
 end
 function s:SessionPump()
  self.sessionPumpCalls=(self.sessionPumpCalls or 0)+1
  if not self.Valid()then self.sessionPumpStage='INVALID_CONTEXT';return end
  if d.paused and d.paused()then self.sessionPumpStage='PAUSED';return end
  self.sessionPumpStage='DIRECTORY'
  if d.directory then d.directory(self)else
   directoryPump(self,d)
   -- Both independent services consume the same bounded native roster cache;
   -- one controller completing a scan must not starve the other of hints.
   for id,p in pairs(directory.identities)do
    if count(self.peers)>=20 then break end
    if p.expires>d.clock()and not self.peers[id]then self:Connect(p.name,'REALM_CHANNEL_ROSTER')end
   end
  end
  self.sessionPumpStage='COMPLETE'
 end
 function s:SessionLeave()
  for _,p in pairs(self.peers)do p.liveKeyRequest=nil;p.liveKeyBusy=nil;p.liveKeyRetry=nil;p.liveKeyReplyAt=nil;p.liveKeyRateAt=nil;p.liveKeyRate=nil end
  directory.users[self]=nil
  for user in pairs(directory.users)do if user.enabled then return end end
  local selection=directory.selection
  if selection and type(SetSelectedDisplayChannel)=='function'and ns.SafeCall(GetSelectedDisplayChannel)==selection.display and selection.previous then
   local row={pcall(GetChannelDisplayInfo,selection.previous)}
   if row[1]and row[2]==selection.name and row[5]==selection.channel then pcall(SetSelectedDisplayChannel,selection.previous)end
  end
  directory.selection=nil;directory.nextRosterRequest=nil
  if directory.joined and directory.owner==ns.Permissions.Owner()then
   local leave=LeaveChannelByName or C_ChatInfo and C_ChatInfo.LeaveChannelByName
   if type(leave)=='function'then pcall(leave,channelName())end
  end
  directory.joined=nil;directory.owner=nil;directory.channel=nil;directory.displayIndex=nil;directory.identities={};directory.status='LEFT'
 end
 local export=s.Export
 function s:Export()
  local r=export(self);r.liveIdentity=self.context and self.context.cert.liveOnly and'NATIVE_NAME_SESSION'or'AUTHORITY_CERTIFICATE'
  local guidCount=0;for _,p in pairs(directory.identities)do if p.guid then guidCount=guidCount+1 end end
  r.directory={state=directory.status,members=directory.members,channel=directory.channel,displayIndex=directory.displayIndex,channelName=channelName(),identities=count(directory.identities),guidIdentities=guidCount,
   cursor=directory.cursor,rowsScanned=directory.rowsScanned or 0,rosterErrors=directory.rosterErrors or 0,joinAttempts=directory.joinAttempts or 0,joinResult=directory.joinResult or'NOT_ATTEMPTED',
   rosterRequests=directory.rosterRequests or 0,rosterRequestResult=directory.rosterRequestResult or'NOT_ATTEMPTED',rosterRequestAPI=type(SetSelectedDisplayChannel)=='function',
   pumpCalls=directory.pumpCalls or 0,sessionPumpCalls=self.sessionPumpCalls or 0,sessionPumpStage=self.sessionPumpStage or'NOT_STARTED',
   channelAPI=type(GetChannelName)=='function',countAPI=type(GetChannelDisplayInfo)=='function'and type(GetNumDisplayChannels)=='function',rosterAPI=type(GetChannelRosterInfo or C_ChatInfo and C_ChatInfo.GetChannelRosterInfo)=='function',
   joinAPI=type(JoinTemporaryChannel or JoinChannelByName or C_ChatInfo and C_ChatInfo.JoinTemporaryChannel)=='function',
   scope='Native channel/guild/direct reachable partition; not a guaranteed realm directory'}
  for _,row in ipairs(r.peers)do local p=self.peers[d.name(row.name)];row.trust=p.cert and(p.cert.liveOnly and'NATIVE_NAME_SESSION'or'AUTHORITY_CERTIFICATE')or'UNVERIFIED';row.recordAuthority=false end
  return r
 end
end
