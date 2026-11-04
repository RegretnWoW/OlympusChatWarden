-- Recipient-only Direct Share. No Aether participation, public ledger,
-- forwarding, Bridge identity or background discovery is involved.
local _,ns=...
local D={PREFIX='OWDirect1',MAX_WIRE=10000};ns.DirectNative=D
local A,B,E=ns.AetherNative,ns.ChronicleBackup,ns.AthenaExchange
local function now() return ns.SafeNumber(ns.SafeCall(GetServerTime)) or 0 end
local function elapsed() return ns.SafeNumber(ns.SafeCall(GetTime)) or 0 end
local function hash(v) return ns.PackCrypto.Hex(ns.PackCrypto.SHA256(v)) end
local function plain(v) return ns.Readable(v) and type(v)=='table' and not getmetatable(v) end
local event=CreateFrame('Frame');D.frame=event
local function bound(target)
 for _,u in ipairs({'player','party1','party2','party3','party4'}) do local b=A.NativeUnit(u);if b and b.guid==target then return b end end
 for i=1,40 do local b=A.NativeUnit('raid'..i);if b and b.guid==target then return b end end
end
function D.Stop()
 local a=D.active;if a then a.enabled=false;a.queue={};a.incoming={};a.retry={};a.seen={};a.client:Leave() end
 D.active=nil;event:SetScript('OnUpdate',nil);return true
end
function D.Create(recipient,explicit)
 if explicit~=true or not ns.Permissions.Decide('UIAccess') or ns.MainStorageBlocked or not plain(recipient) then return nil,'EXPLICIT_DIRECT_SCOPE_REQUIRED' end
 local me=A.NativeUnit('player');local peer=bound(recipient.guid)
 local id=A.NativeName((recipient.name or '')..'-'..(recipient.realm or ''))
 if not me or not peer or peer.guid==me.guid or peer.id~=id then return nil,'CURRENT_NATIVE_GROUP_GUID_NAME_BINDING_REQUIRED' end
 if type(C_ChatInfo and C_ChatInfo.SendAddonMessageLogged)~='function' then return nil,'LOGGED_NATIVE_API_UNAVAILABLE' end
 local ok,result=pcall(C_ChatInfo.RegisterAddonMessagePrefix,D.PREFIX)
 if not ok or not A.NativeResult('RegisterAddonMessagePrefixResult',result,false) then return nil,'DIRECT_PREFIX_UNAVAILABLE' end
 D.Stop()
 local a={owner=me.guid,peer=peer,identity=me,enabled=true,queue={},incoming={},retry={},seen={},sequence=0,session=hash(me.id..'/'..now()..'/'..elapsed()):sub(1,16),lastSend=-10,lastAt=now()}
 local function permitted() local b=bound(peer.guid);return a.enabled and not (a.client and a.client.privacyDetached) and not ns.MainStorageBlocked and ns.Permissions.Decide('UIAccess') and ns.SafeCall(UnitGUID,'player')==me.guid and b and b.id==peer.id end
 local options={owner=me.guid,clock=now,nativeStatus='NATIVE_UNVERIFIED_RECIPIENT_SESSION',authority=function(guid)
  local b=guid==me.guid and A.NativeUnit('player') or guid==peer.guid and bound(guid)
  if permitted() and b and (guid==me.guid or b.id==peer.id) then return {guid=guid,verified=true,principal='DirectSession/'..b.id,trustTier='NATIVE_CURRENT_GROUP_BINDING'} end
 end}
 local c=E.New(options);a.client=c;c.nativeDirect=a
 local leave=c.Leave;c.Leave=function(self,...) a.enabled=false;a.queue={};a.incoming={};a.retry={};a.seen={};if D.active==a then D.active=nil;event:SetScript('OnUpdate',nil) end;return leave(self,...) end
 function a:Enqueue(text)
  if not permitted() or type(text)~='string' or #text>255 or #self.queue>=120 then return false end
  self.queue[#self.queue+1]={text=text,expires=now()+55};return true
 end
 options.nativeTransport=function(target,packet)
  if target~=peer.guid or not permitted() then return false end
  local wire=B.Encode({packet});if #wire>D.MAX_WIRE then a.lastError='SELECTED_CAPTURE_EXCEEDS_NATIVE_BUDGET';return false end
  local pieces=A.SplitText(wire);if not pieces or #pieces>60 or #a.queue+#pieces>120 then return false end
  local n=0;for _ in pairs(a.retry) do n=n+1 end;if n>=4 then return false end
  a.sequence=a.sequence+1;local mid=a.session..'-'..a.sequence;local digest=hash(wire):sub(1,16);local frames={}
  for i,p in ipairs(pieces) do frames[i]='D1|D|'..mid..'|'..i..'|'..#pieces..'|'..digest..'|'..p end
  for _,frame in ipairs(frames) do if #frame>255 then return false end end
  a.retry[mid]={frames=frames,at=now(),tries=0};for _,frame in ipairs(frames) do a:Enqueue(frame) end;return true
 end
 function a:Ingress(prefix,text,channel,sender,kind)
  if not permitted() or prefix~=D.PREFIX or kind~='CHAT_MSG_ADDON_LOGGED' or channel~='WHISPER' or A.NativeName(sender)~=peer.id or not ns.CanRead(text) or #text>255 then return false,'DIRECT_NATIVE_SOURCE' end
  if not self.rate or self.rate.at+60<=now() then self.rate={at=now(),n=0} end;self.rate.n=self.rate.n+1;if self.rate.n>360 then return false,'DIRECT_RATE' end
  local ack=text:match('^D1|A|([a-f0-9]+%-%d+)$');if ack then self.retry[ack]=nil;return true end
  local mid,index,total,digest,piece=text:match('^D1|D|([a-f0-9]+%-%d+)|(%d+)|(%d+)|([a-f0-9]+)|(.*)$');index,total=tonumber(index),tonumber(total)
  if not mid or #mid>40 or not index or not total or total<1 or total>60 or index<1 or index>total or #digest~=16 then return false,'DIRECT_FRAME' end
  if self.seen[mid] then self:Enqueue('D1|A|'..mid);return true end
  local r=self.incoming[mid]
  if not r then local n=0;for _ in pairs(self.incoming) do n=n+1 end;if n>=4 then return false,'DIRECT_REASSEMBLY_BOUND' end;r={parts={},total=total,digest=digest,bytes=0,expires=now()+55};self.incoming[mid]=r end
  if r.total~=total or r.digest~=digest or r.parts[index] and r.parts[index]~=piece then self.incoming[mid]=nil;return false,'DIRECT_CONFLICT' end
  if not r.parts[index] then r.parts[index]=piece;r.bytes=r.bytes+#piece end
  if r.bytes>D.MAX_WIRE then self.incoming[mid]=nil;return false,'DIRECT_BYTES' end
  for i=1,total do if not r.parts[i] then return true,'PARTIAL' end end
  local wire=table.concat(r.parts);self.incoming[mid]=nil;if hash(wire):sub(1,16)~=digest then return false,'DIRECT_CHECKSUM' end
  local decoded=B.DecodeChunk(wire);local packet=decoded and decoded[1];if not plain(packet) then return false,'DIRECT_PACKET' end
  local ok,accepted,why=pcall(c.Receive,c,peer.guid,packet);if not ok or not accepted then return false,ok and why or 'DIRECT_PACKET_REFUSED' end
  self.seen[mid]=now()+180;self:Enqueue('D1|A|'..mid)
  if packet.kind=='OFFER' then ns.Activity.Add('direct/'..packet.id,'athena',{directOffer=packet.id,subjectGUID=peer.guid,owner=ns.Chronicle.Owner(),sender=peer.name,preview='Private Direct Share offer · review required',timestamp=now(),notificationPreference='athena'},false) end
  if ns.UI2.route and ns.UI2.route.page=='relay' then ns.UI2.Refresh(true) end
  return true
 end
 function a:Pump()
  if not permitted() or now()-self.lastAt>600 then D.Stop();return false end
  for id,r in pairs(self.incoming) do if r.expires<=now() then self.incoming[id]=nil end end
  for id,t in pairs(self.seen) do if t<=now() then self.seen[id]=nil end end
  for id,r in pairs(self.retry) do if r.at+50<=now() then
   if r.tries>=1 then self.retry[id]=nil else r.tries=1;r.at=now();for _,frame in ipairs(r.frames) do self:Enqueue(frame) end end
  end end
  c:Expire();local r=self.queue[1];if not r or elapsed()-self.lastSend<.35 then return false end
  if r.expires<=now() then table.remove(self.queue,1);return false end
  if A.Restricted() then return false end
  self.lastSend=elapsed();local ok,v=pcall(C_ChatInfo.SendAddonMessageLogged,D.PREFIX,r.text,'WHISPER',ns.RelayTransport.WhisperTarget(peer.name))
  if ok and A.NativeResult('SendAddonMessageResult',v,true) then table.remove(self.queue,1);self.lastAt=now();return true end
  a.lastError='DIRECT_NATIVE_SEND_REFUSED';return false
 end
 local boundState,why=ns.AthenaExchangeState.Bind(c)
 if not boundState then a.enabled=false;return nil,why end
 D.active=a;E.Current=c
 local tick=0;event:SetScript('OnUpdate',function(_,dt) tick=tick+(dt or 0);if tick>=.35 then tick=0;if D.active==a then a:Pump() end end end)
 return c,'NATIVE_UNVERIFIED · Exact current group recipient only; server-logged text; no public Aether distribution.'
end
function D.Listen()
 return ns.UI2Forms.Form({title='Approve one Direct Share contact',help='Both players must approve each other and remain in the same native party or raid. This permission lasts only this session (10 minutes idle). No Aether opt-in or public sync. Messages use WoW’s logged addon API; this is not end-to-end encryption. Native delivery remains unverified.',fields={{key='guid',label='Exact recipient GUID',value='',limit=96},{key='name',label='Exact character name',value='',limit=128},{key='realm',label='Realm',value='',limit=128}},submitLabel='Approve this session contact',submit=function(v) local c,why=D.Create(v,true);return c~=nil,why end})
end
event:RegisterEvent('CHAT_MSG_ADDON_LOGGED');event:RegisterEvent('PLAYER_LOGOUT')
event:SetScript('OnEvent',function(_,kind,...) if kind=='PLAYER_LOGOUT' then D.Stop() elseif D.active then local prefix,text,channel,sender=...;return D.active:Ingress(prefix,text,channel,sender,kind) end end)
