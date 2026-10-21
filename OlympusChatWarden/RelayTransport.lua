-- Bounded, whisper-only transport. No guild broadcast, presence probes, remote commands,
-- executable serialization or dependency on Chronicle startup. Explicitly
-- submitted reports may retry automatically; drafts never transmit.
local ADDON,ns=...
local S=ns.RelayStore
local P={PREFIX='OWRelay1',PROTOCOL='1',CHUNK=80,MAX_CHUNKS=103,INTERVAL=.35,TIMEOUT=120,
    incoming={},outgoing={},rate={},receivers={'Olympus Wardn','Rune Escape'}};ns.RelayTransport=P
local pump=CreateFrame('Frame');local events=CreateFrame('Frame');local retry=CreateFrame('Frame')
local stages={H='readiness request',D='report data',F='receipt request',R='readiness reply',A='delivery receipt',E='receiver refusal'}
local function Clock() return ns.SafeCall(GetTime) or 0 end
local function Realm(v) return S.Text(v,128) and v:gsub('%s',''):lower() end
function P.Identity(value,realm)
    if not S.Text(value,180) then return end
    -- Forever may deliver First-Surname-Realm in chat. Reuse the same native
    -- surname handling as the rest of Warden rather than dropping the surname.
    if ns.Shield and ns.Shield.NormalName then value=ns.Shield.NormalName(value) end
    local n,r=value:match('^(.-)%-(.+)$');n=n or value;r=r or realm
    if not Realm(r) or n=='' or #n>64 or n:find('[|:%c]') then return end
    return n:lower()..'-'..Realm(r)
end
function P.LocalName()
    return ns.Shield and ns.Shield.UnitName('player') or ns.SafeCall(UnitName,'player')
end
function P.LocalIdentity() return P.Identity(P.LocalName(),ns.SafeCall(GetRealmName)) end
function P.WhisperTarget(value)
    if not S.Text(value,180) then return end
    local name=ns.Shield and ns.Shield.NormalName and ns.Shield.NormalName(value) or value
    local base,realm=name:match('^(.-)%-(.+)$')
    -- Forever routes same-realm whispers by First Surname, rejecting a realm
    -- suffix. Incoming sender identity remains fully qualified for verification.
    if base and Realm(realm)==Realm(ns.SafeCall(GetRealmName)) then return base end
    return name
end
function P.IsDeveloper()
    return ns.WardenSimLab and ns.WardenSimLab.Enabled() and S.db~=nil
        and IsLoggedIn and ns.Checked(ns.SafeCall(IsLoggedIn)) and P.LocalIdentity()~=nil or false
end
function P.Receiver(sender)
    for _,name in ipairs(P.receivers) do if sender==P.Identity(name,'Classic Beta PvP') then return true end end
    return false
end
local function CanUse()
    return S.db and not S.blocked and ns.Membership and ns.Membership.Allowed()
        and IsLoggedIn and ns.Checked(ns.SafeCall(IsLoggedIn)) and (Realm(ns.SafeCall(GetRealmName))=='classicbetapvp' or P.IsDeveloper())
end
local function Wake() pump:SetScript('OnUpdate',function() P.Pump() end) end
local function Notify() S.Changed() end
function P.RetryDelay(attempts)
    attempts=type(attempts)=='number' and attempts==attempts and attempts or 1
    return ({60,300,900,1800})[math.max(1,math.min(4,math.floor(attempts)))]
end
function P.Schedule()
    local pending=false
    for _,r in ipairs(S.db and S.db.reports or {}) do if r.state=='pending' and r.autoRetry==true then pending=true;break end end
    if not pending then retry:SetScript('OnUpdate',nil);return end
    local elapsed=0
    retry:SetScript('OnUpdate',function(_,dt)
        elapsed=elapsed+(dt or 0);if elapsed<5 then return end;elapsed=0;P.Automatic()
    end)
end
local function Send(target,wire)
    local fn=C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
    local route=P.WhisperTarget(target)
    local detail={api=C_ChatInfo and C_ChatInfo.SendAddonMessage and 'C_ChatInfo.SendAddonMessage' or 'SendAddonMessage',kind=wire:sub(1,1),bytes=#wire,restricted='unavailable'}
    P.lastSendDetail=detail
    local function Refuse(reason) detail.accepted=false;detail.reason=reason;return false,reason end
    if not CanUse() then return Refuse('Delivery is paused until Olympus access returns.') end
    if not route or type(fn)~='function' then return Refuse('Native addon messaging or its target is unavailable.') end
    if #wire>240 then return Refuse('The protocol message exceeds the native size bound.') end
    if C_ChatInfo and type(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted)=='function' then
        local ok,value=pcall(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted)
        if ok and ns.Readable(value) and type(value)=='boolean' then detail.restricted=value and 'yes' or 'no' end
    end
    -- Forever can report a restricted realm while its supported native send API
    -- accepts whispers (Olympus uses that API directly). Let the actual call
    -- enforce native restrictions; the advisory query alone is not its result.
    -- Native enum Success is 0 in the documented API. Legacy returns may be nil.
    -- Neither API acceptance nor this result ever marks a report Received.
    local ok,result=pcall(fn,P.PREFIX,wire,'WHISPER',route)
    local success=Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success or 0
    if not ok then return Refuse('The native send API raised an error.') end
    if not ns.Readable(result) then return Refuse('The native send result is unavailable.') end
    local accepted=result==nil or result==success or result==true
    local label=result==nil and 'legacy nil' or type(result)=='boolean' and tostring(result) or type(result)=='number' and tostring(result) or 'unsupported result'
    if type(result)=='number' and Enum and type(Enum.SendAddonMessageResult)=='table' then
        for name,value in pairs(Enum.SendAddonMessageResult) do
            if value==result and type(name)=='string' and name:match('^[%w_]+$') then label=name..' ('..result..')';break end
        end
    end
    detail.result=label;detail.accepted=accepted;detail.reason=accepted and 'Native API accepted the message; no receipt yet.' or 'Native send refused: '..label..'.'
    return accepted,detail.reason
end
function P.DeliveryDetail()
    local d=P.lastSendDetail
    if not d then return 'No native send attempted this session.' end
    return d.reason..'\nAPI: '..d.api..' • '..(stages[d.kind] or 'protocol message')..' • '..d.bytes..' bytes\nRealm restriction advisory: '..d.restricted..'. A matching final receipt is still required.'
end
local function Queue(target,wire)
    if #P.outgoing>=48 then return false end
    P.outgoing[#P.outgoing+1]={target=target,wire=wire};Wake();return true
end
local function Control(target,kind,id,extra) return Queue(target,kind..'|1|'..id..'|'..extra) end
function P.Busy(id) return P.active and (not id or P.active.report.id==id) or false end
local function End(state,message)
    local a=P.active;if not a then return end
    a.report.state=state;a.report.status=message
    a.report.nextAttempt=state=='pending' and a.report.autoRetry==true and S.Now()+P.RetryDelay(a.report.attempts) or nil
    if state=='received' or state=='failed' then a.report.autoRetry=false end
    P.active=nil;P.autoNotBefore=Clock()+10;P.Schedule();Notify()
end
local function Hex(s) return (s:gsub('.',function(c) return string.format('%02x',c:byte()) end)) end
local function Unhex(s)
    if #s>160 or #s%2~=0 or s:find('[^0-9a-f]') then return end
    return (s:gsub('..',function(c) return string.char(tonumber(c,16)) end))
end
local function Contact(a)
    a.target=a.report.selfTestReceiver and P.LocalName() or P.receivers[a.receiver]
    a.identity=P.Identity(a.target,'Classic Beta PvP');a.phase='hello';a.deadline=Clock()+12;a.next=0
    a.report.status='Contacting '..a.target..'. Awaiting receiver readiness.';Notify()
end
function P.Try(id)
    local r=S.Find(id)
    if not r or not r.wire or r.state=='received' or r.state=='draft' then return false,'Choose a submitted report.' end
    if P.active then return false,'Another report is sending. Retry this one when it finishes.' end
    if r.selfTestReceiver and (not P.IsDeveloper() or r.selfTestReceiver~=P.LocalIdentity()) then return false,'This self-test can only send from its original developer character.' end
    if r.lastAttempt and S.Now()-r.lastAttempt<30 then return false,'Wait 30 seconds between delivery attempts.' end
    if not CanUse() then r.state='pending';r.status='Pending. Delivery requires Olympus access on Classic Beta PvP.';Notify();return false,r.status end
    local fn=C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
    if type(fn)~='function' or not P.registered then r.state='pending';r.status='Addon messaging is unavailable. Keep this report and copy it if needed.';Notify();return false,r.status end
    r.lastAttempt=S.Now();r.attempts=(r.attempts or 0)+1;r.state='sending';r.nextAttempt=nil
    P.active={report=r,receiver=1,count=math.ceil(#r.wire/P.CHUNK),created=Clock()};Contact(P.active);Wake();return true
end
function P.SetAutomatic(id,enabled)
    local r=S.Find(id)
    if not r or not r.wire or r.state~='pending' and r.state~='sending' then return false,'Choose a pending or sending report.' end
    if enabled and r.selfTestReceiver and (not P.IsDeveloper() or r.selfTestReceiver~=P.LocalIdentity()) then return false,'Open this self-test on its original developer character.' end
    r.autoRetry=enabled==true
    if not r.autoRetry and P.Busy(id) then End('pending','Automatic delivery paused by you. The report is kept.') end
    r.nextAttempt=r.autoRetry and math.max(S.Now(),(r.lastAttempt or 0)+30) or nil
    r.status=r.autoRetry and 'Automatic delivery enabled. Warden will retry while you are logged in.' or 'Automatic delivery paused. The report is kept locally.'
    P.Schedule();Notify();return true
end
function P.Automatic()
    if P.active or not CanUse() or Clock()<(P.autoNotBefore or 0) then return end
    local selected
    for _,r in ipairs(S.db.reports) do
        if r.state=='pending' and r.autoRetry==true and (not r.selfTestReceiver or P.IsDeveloper() and r.selfTestReceiver==P.LocalIdentity()) then
            local due=type(r.nextAttempt)=='number' and r.nextAttempt==r.nextAttempt and r.nextAttempt or math.max(S.Now(),(r.lastAttempt or 0)+P.RetryDelay(r.attempts))
            r.nextAttempt=due
            if due<=S.Now() and (not selected or due<selected.nextAttempt) then selected=r end
        end
    end
    if selected then
        local ok=P.Try(selected.id)
        if not ok then selected.nextAttempt=S.Now()+P.RetryDelay(selected.attempts) end
    end
    P.Schedule()
end
local function ReceiverTimeout(a)
    if not a.report.selfTestReceiver and a.receiver<#P.receivers then a.receiver=a.receiver+1;Contact(a)
    else End('pending',a.report.selfTestReceiver and 'No self-whisper receipt. Native self-delivery may be unavailable; check diagnostics.' or 'No receiver receipt yet. Automatic delivery retries while enabled and you are logged in.') end
end
function P.Pump()
    local now=Clock()
    for key,t in pairs(P.incoming) do if t.expires<now then P.incoming[key]=nil end end
    for key,r in pairs(P.rate) do if r.at+60<now then P.rate[key]=nil end end
    if not CanUse() then
        if P.active then End('pending','Delivery paused. Your report is kept; retry after access or connection returns.') end
        P.outgoing={};P.incoming={}
    end
    if P.active then
        local a=P.active
        if now-a.created>P.TIMEOUT then End('pending','Transfer timed out before a final receipt. Retry later.')
        elseif now>a.deadline then ReceiverTimeout(a) end
    end
    if not P.lastSend or now-P.lastSend>=P.INTERVAL then
        local message=table.remove(P.outgoing,1)
        if message then local accepted=Send(message.target,message.wire);P.lastSend=now
            if not accepted then Notify() end
        elseif P.active then
            local a=P.active;local r=a.report;local wire
            if a.phase=='hello' then
                wire='H|1|'..r.id..'|'..a.count..'|'..#r.wire..'|'..r.checksum;a.phase='ready'
            elseif a.phase=='data' then
                local index=a.next;wire='D|1|'..r.id..'|'..index..'|'..Hex(r.wire:sub((index-1)*P.CHUNK+1,index*P.CHUNK));a.next=index+1
                if index==a.count then a.phase='finish' end
            elseif a.phase=='finish' then wire='F|1|'..r.id..'|'..r.checksum;a.phase='receipt';a.deadline=now+15 end
            if wire then
                P.lastSend=now
                local accepted,reason=Send(a.target,wire)
                if not accepted then End('pending',reason..' During '..(stages[wire:sub(1,1)] or 'delivery')..'. The report is kept for retry.') end
            end
        end
    end
    if not P.active and not next(P.incoming) and #P.outgoing==0 then pump:SetScript('OnUpdate',nil) end
end
local function Parts(wire)
    local parts={};for item in (wire..'|'):gmatch('(.-)|') do parts[#parts+1]=item;if #parts>6 then return end end
    return parts
end
function P.Handle(prefix,wire,channel,sender)
    if not ns.CanRead(prefix) or not ns.CanRead(channel) or prefix~=P.PREFIX or channel~='WHISPER' or not CanUse() or not S.Text(wire,240) or not S.Text(sender,180) then return end
    local who=P.Identity(sender,ns.SafeCall(GetRealmName));if not who then return end
    local parts=Parts(wire);if not parts or parts[2]~='1' or not S.ID(parts[3]) then return end
    local kind,id=parts[1],parts[3];local a=P.active
    if kind=='R' or kind=='A' or kind=='E' then
        if #parts~=4 or not a or id~=a.report.id or who~=a.identity or not (P.Receiver(who) or a.report.selfTestReceiver and who==a.report.selfTestReceiver) then return end
        if kind=='E' then
            local permanent=parts[4]=='integrity' or parts[4]=='invalid' or parts[4]=='conflict'
            End(permanent and 'failed' or 'pending',permanent and 'Receiver validation failed. The original submission is kept; retry or duplicate it to edit.' or 'The receiver could not accept this transfer. Your report is kept; retry or copy it.');return
        end
        if parts[4]~=a.report.checksum then return end
        if kind=='R' and (a.phase=='ready' or a.phase=='receipt') then
            a.phase='data';a.next=1;a.deadline=Clock()+100;a.report.status='Sending bounded report chunks. Waiting for a complete-report receipt.';Notify();Wake()
        elseif kind=='A' and (a.phase=='ready' or a.phase=='receipt') then
            a.report.receivedBy=who;a.report.receivedAt=S.Now()
            End('received','Received by '..a.target..'. Receiver saves to disk on normal logout or reload.')
        end
        return
    end
    if not P.IsDeveloper() then return end
    local key=who..'/'..id;local t=P.incoming[key]
    if kind=='H' then
        if #parts~=6 or not parts[4]:match('^%d+$') or not parts[5]:match('^%d+$') or not parts[6]:match('^%x%x%x%x%x%x%x%x$') then return end
        local count,size=tonumber(parts[4]),tonumber(parts[5]);local hash=parts[6]
        if count<1 or count>P.MAX_CHUNKS or size<1 or size>S.MAX_BYTES or count~=math.ceil(size/P.CHUNK) then return end
        local old=S.Receipt(who,id,hash)
        if old~=nil then Control(sender,old and 'A' or 'E',id,old and hash or 'conflict');return end
        if t then
            if t.hash==hash and t.size==size and t.count==count then Control(sender,'R',id,hash) end
            return
        end
        local n=0;for _,v in pairs(P.incoming) do n=n+1;if v.sender==who then return end end
        if n>=4 or #S.db.inbox>=S.MAX_INBOX then return end
        local rate=P.rate[who]
        if rate and Clock()-rate.at<60 and rate.count>=2 then return end
        if not rate or Clock()-rate.at>=60 then rate={at=Clock(),count=0};P.rate[who]=rate end
        local peers=0;for _ in pairs(P.rate) do peers=peers+1 end;if peers>128 then P.rate[who]=nil;return end
        rate.count=rate.count+1
        P.incoming[key]={sender=who,hash=hash,count=count,size=size,chunks={},bytes=0,received=0,expires=Clock()+P.TIMEOUT}
        Control(sender,'R',id,hash);Wake()
    elseif kind=='D' then
        if #parts~=5 or not t or not parts[4]:match('^%d+$') then return end
        local index=tonumber(parts[4]);if index<1 or index>t.count then return end
        local chunk=Unhex(parts[5]);if not chunk then return end
        if #chunk~=(index==t.count and t.size-(t.count-1)*P.CHUNK or P.CHUNK) then return end
        if t.chunks[index] then if t.chunks[index]~=chunk then P.incoming[key]=nil end;return end
        t.bytes=t.bytes+#chunk;t.received=t.received+1;t.chunks[index]=chunk
    elseif kind=='F' then
        if #parts~=4 then return end
        if not t then local old=S.Receipt(who,id,parts[4]);if old then Control(sender,'A',id,parts[4]) end;return end
        if parts[4]~=t.hash or t.received~=t.count or t.bytes~=t.size then return end
        local content=table.concat(t.chunks);P.incoming[key]=nil
        if S.Checksum(content)~=t.hash then Control(sender,'E',id,'integrity');return end
        local p=S.Decode(content)
        if not p or p.id~=id then Control(sender,'E',id,'invalid');return end
        if S.Receive(who,p,content,t.hash) then Control(sender,'A',id,t.hash) else Control(sender,'E',id,'capacity') end
    end
end
function P.Initialize()
    P.autoNotBefore=P.autoNotBefore or Clock()+15;P.Schedule()
    if P.registered then return end
    local fn=C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
    if type(fn)=='function' then
        local ok,value=pcall(fn,P.PREFIX);local success=false
        if ok and ns.Readable(value) then
            if type(value)=='boolean' or value==nil then success=value==nil or value==true
            elseif Enum and Enum.RegisterAddonMessagePrefixResult then success=value==Enum.RegisterAddonMessagePrefixResult.Success end
        end
        local query=C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered
        if ok and type(query)=='function' then local read,registered=pcall(query,P.PREFIX);success=read and ns.Readable(registered) and ns.Checked(registered) end
        P.registered=success
    end
end
for _,event in ipairs({'ADDON_LOADED','PLAYER_LOGIN','PLAYER_LOGOUT','CHAT_MSG_ADDON'}) do events:RegisterEvent(event) end
events:SetScript('OnEvent',function(_,event,...)
    if event=='CHAT_MSG_ADDON' then P.Handle(...)
    elseif event=='PLAYER_LOGOUT' then if P.active then End('pending','Interrupted before receipt; retry after login.') end
    elseif event=='ADDON_LOADED' then local name=...;if name==ADDON then S.Initialize();P.Initialize() end
    else P.Initialize() end
end)
