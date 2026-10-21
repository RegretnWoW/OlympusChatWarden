-- Local, reversible contact protection. No peer lists, probes or reporting.
local _, ns = ...
local function OwnedFrame(...) return ns.Modules and ns.Modules.Frame('shield',...) or CreateFrame(...) end
local S={alerts={},capabilities={}};ns.Shield=S
S.Profiles={
    balanced={title='Balanced protection',whispers={3,120,600},repeatedWhispers={6,30,600},trades={4,60,300},duels={4,60,300},invites={4,60,300}},
    normal={title='Normal Harassment',whispers={3,120,600},repeatedWhispers={6,30,600},trades={4,600,900},duels={4,120,600},invites={4,600,900}},
}
S.RuleKinds={'trades','duels','invites','whispers','repeatedWhispers'}
S.RuleTitles={trades='Trade requests',duels='Duel requests',invites='Group invites',whispers='Strong-wording whispers',repeatedWhispers='Repeated whispers'}
local function ValidRule(rule)
    if type(rule)~='table' then return false end
    for i,range in ipairs({{2,20},{10,600},{60,3600}}) do
        local v=ns.SafeNumber(rule[i]);if not v or v%1~=0 or v<range[1] or v>range[2] then return false end
    end
    return rule[3]%60==0
end
function S.GetRule(kind)
    local db=ns.DB and ns.DB.shield
    if db and db.profile=='custom' and db.custom and ValidRule(db.custom[kind]) then return db.custom[kind] end
    local preset=db and S.Profiles[db.profile] or S.Profiles.balanced
    return (preset or S.Profiles.balanced)[kind]
end
local contacts,counts,seen,seenOrder,pending={},{},{},{},{}
local MAX=512
local function Clock() return ns.SafeNumber(ns.SafeCall(GetServerTime)) or ns.SafeNumber(ns.SafeCall(time)) end
local function RealmKey(value)
    return ns.CanRead(value) and ns.Engine.Lower((value:gsub('[%s%-]',''))) or nil
end
local function HomeRealm() return ns.SafeCall(GetNormalizedRealmName) or ns.SafeCall(GetRealmName) end
local function Home(value)
    local key=RealmKey(value)
    return key and (key==RealmKey(ns.SafeCall(GetNormalizedRealmName)) or key==RealmKey(ns.SafeCall(GetRealmName)))
end
function S.SplitNames()
    -- Forever returns the surname in UnitFullName's usual realm position.
    local fn=UnitFullName or UnitName;if type(fn)~='function' then return false end
    local ok,first,second=pcall(fn,'player')
    return ok and ns.CanRead(first) and not first:find(' ',1,true)
        and ns.CanRead(second) and second~='' and ns.CanRead(HomeRealm()) and not Home(second) or false
end
function S.NormalName(name)
    if not ns.CanRead(name) or not S.SplitNames() then return name end
    local first,rest=name:match('^([^%-]+)%-(.+)$')
    if not first or first:find(' ',1,true) or Home(rest) then return name end
    local surname,realm=rest:match('^([^%-]+)%-(.+)$')
    if surname then return first..' '..surname..'-'..realm end
    return first..' '..rest
end
function S.Key(name)
    if not ns.CanRead(name) or #name>128 then return end
    name=name:match('^%s*(.-)%s*$')
    name=S.NormalName(name)
    local base,realm=name:match('^([^%-]+)%-(.+)$')
    base=base or name
    if base:find('-',1,true) then return end
    realm=realm or HomeRealm()
    if not ns.CanRead(realm) then return end
    if realm:find('[%z\1-\31\127|:%%]') then return end
    realm=realm:gsub('[%s%-]','')
    -- This client supports first name + surname. Preserve internal spaces in
    -- the identity; reject control characters, markup and ambiguous spacing.
    if base=='' or realm=='' or base:find('[%z\1-\31\127|:%%]') or base:find('^ ') or base:find(' $')
        or base:find('  ',1,true) or realm:find('[%z\1-\31\127|:%%]') then return end
    return ns.Engine.Lower(base)..'-'..ns.Engine.Lower(realm)
end
function S.UnitName(unit)
    local fn=UnitFullName or UnitName
    if type(fn)~='function' then return end
    local ok,name,realm=pcall(fn,unit)
    if ok and ns.CanRead(name) then
        if S.SplitNames() and not name:find(' ',1,true) and ns.CanRead(realm) and realm~='' and not Home(realm) then
            name,realm=name..' '..realm,HomeRealm()
        end
        return S.NormalName(name..(ns.CanRead(realm) and realm~='' and '-'..realm or ''))
    end
end
local function Save()
    local saved={}
    for key,item in pairs(contacts) do
        if not item.session then saved[key]={name=item.name,expires=item.expires,reason=item.reason} end
    end
    ns.DB.shield.contacts=saved
end
local function Changed()
    if ns.PolicyChanged then ns.PolicyChanged() end
    if ns.RefreshShield then ns.RefreshShield() end
end
function S.Active(kind)
    return ns.DB and (not ns.Modules or ns.Modules.Enabled('shield')) and ns.Membership.Allowed() and ns.DB.shield and ns.DB.shield.enabled and (not kind or ns.DB.shield[kind]~=false)
end
function S.Initialize()
    local db=ns.DB.shield
    if type(db)~='table' then db={} end
    ns.DB.shield=db
    if type(db.enabled)~='boolean' then db.enabled=true end
    if not S.Profiles[db.profile] and db.profile~='custom' then db.profile='balanced' end
    for _,key in ipairs({'whispers','repeatedWhispers','trades','duels','invites','visibleChat','bubbles'}) do
        if type(db[key])~='boolean' then db[key]=true end
    end
    if type(db.quiet)~='boolean' then db.quiet=false end
    -- Apply the requested launch defaults once to rc31 installs as well.
    -- Later changes to these options remain the player's choice.
    if db.defaultsVersion~=2 then
        db.enabled=true;db.profile='normal';db.quiet=false;db.defaultsVersion=2
        ns.DB.olympusMuteSignal=true
    end
    if db.tuningV1~=true then
        if db.profile=='normal' then db.profile='balanced' end
        db.tuningV1=true
    end
    local custom=type(db.custom)=='table' and db.custom or {};db.custom={}
    for _,kind in ipairs(S.RuleKinds) do
        local r=ValidRule(custom[kind]) and custom[kind] or S.Profiles.balanced[kind]
        db.custom[kind]={r[1],r[2],r[3]}
    end
    local allowed={};local n=0
    for key,name in pairs(type(db.allowed)=='table' and db.allowed or {}) do
        if n<MAX and S.Key(name)==key then allowed[key]=name;n=n+1 end
    end
    db.allowed=allowed;contacts={};counts={};seen={};seenOrder={};pending={}
    if ns.WhisperRepeat then ns.WhisperRepeat.Reset() end
    local now=Clock();n=0
    for key,item in pairs(type(db.contacts)=='table' and db.contacts or {}) do
        if n<MAX and type(item)=='table' and S.Key(item.name)==key and not allowed[key]
            and ns.SafeNumber(item.expires) and (item.expires==0 or now and item.expires>now) then
            contacts[key]={name=item.name,expires=item.expires,reason=ns.SafeString(item.reason,160) or 'Saved shield'};n=n+1
        end
    end
    Save()
    if ns.Spam then ns.Spam.Initialize() end
end
function S.Prune()
    if not ns.DB or not ns.DB.shield then return end
    local now=Clock();local changed=false
    if now then
        for key,item in pairs(contacts) do
            if item.expires>0 and item.expires<=now then contacts[key]=nil;counts[key]=nil;changed=true end
        end
    end
    local t=ns.SessionTime()
    for key,item in pairs(counts) do if t-item.last>600 then counts[key]=nil end end
    if ns.WhisperRepeat then ns.WhisperRepeat.Prune() end
    if ns.Spam then ns.Spam.Prune() end
    if changed then Save();Changed() end
end
function S.List()
    local list={};local now=Clock()
    for key,item in pairs(contacts) do
        if item.expires==0 or now and item.expires>now then
            list[#list+1]={key=key,name=item.name,expires=item.expires,session=item.session,reason=item.reason}
        end
    end
    table.sort(list,function(a,b) return a.key<b.key end);return list
end
function S.HasShield(name)
    local key=S.Key(name);local item=key and contacts[key];local now=Clock()
    return item and not ns.DB.shield.allowed[key] and (item.expires==0 or now and item.expires>now) or false
end
function S.IsShielded(name)
    return S.Active() and S.HasShield(name) or false
end
function S.Alert(name,kind,message)
    local now=ns.SessionTime();local last=S.alerts[1]
    if last and last.at and last.name==name and last.kind==kind and last.message==message and now-last.at<30 then
        last.count=last.count+1;last.at=now;last.timestamp=Clock();last.activityEvicted=nil
    else
        S.nextAlertID=(S.nextAlertID or 0)+1
        table.insert(S.alerts,1,{id=S.nextAlertID,name=name,kind=kind,message=message,at=now,timestamp=Clock(),count=1})
        if #S.alerts>200 then table.remove(S.alerts) end
    end
    if ns.Activity then ns.Activity.SyncShield() end
    if ns.RefreshShield then ns.RefreshShield() end
end
function S.AthenaContext(name)
    local guid=ns.Athena and ns.Athena.ResolveContact(name)
    return guid and ns.Athena.GetPlayerContext('shield',guid,'protection')
end
function S.Add(name,duration,reason)
    if not ns.DB or not ns.DB.shield then return false,'Shield is not ready.' end
    local key=S.Key(name);local now=Clock()
    if not key or key==S.Key(S.UnitName('player')) then return false,'Enter a player name, with realm if needed.' end
    if ns.DB.shield.allowed[key] then return false,'Remove this player from Allowed first.' end
    if S.HasShield(name) then return false,'This player is already shielded. Remove the existing shield before adding a different duration.' end
    if duration~='session' and duration~=0 and (not ns.SafeNumber(duration) or duration<1 or not now) then return false,'Invalid duration or unavailable clock.' end
    local n=0;for _ in pairs(contacts) do n=n+1 end
    if not contacts[key] and n>=MAX then return false,'Shield list is full. Remove an entry first.' end
    contacts[key]={name=name,expires=duration=='session' and 0 or duration==0 and 0 or now+duration,
        session=duration=='session',reason=reason or 'Manually shielded'}
    counts[key]=nil;Save();S.Alert(name,'Shield',reason or 'Manually shielded');Changed()
    if ns.Athena then ns.Athena.Try(ns.Athena.RecordAction,'shield',{kind='shield_added',subject=ns.Athena.ResolveContact(name),nameKey=key}) end
    if ns.WhisperRepeat then ns.WhisperRepeat.Reset(name) end
    if ns.Spam then ns.Spam.Reset(name) end
    return true
end
function S.Remove(name)
    local key=S.Key(name);if not key then return false,'Enter a valid player name.' end
    local existed=contacts[key]~=nil
    contacts[key]=nil;counts[key]=nil;Save();Changed()
    if existed and ns.Athena then ns.Athena.Try(ns.Athena.RecordAction,'shield',{kind='shield_removed',subject=ns.Athena.ResolveContact(name),nameKey=key}) end
    if ns.WhisperRepeat then ns.WhisperRepeat.Reset(name) end
    if ns.Spam then ns.Spam.Reset(name) end
    return true,'Shield removed. This player can contact you again.'
end
function S.Allow(name)
    local key=S.Key(name);if not key then return false,'Enter a valid player name.' end
    local n=0;for _ in pairs(ns.DB.shield.allowed) do n=n+1 end
    if n>=MAX and not ns.DB.shield.allowed[key] then return false,'Allowed list is full.' end
    ns.DB.shield.allowed[key]=name;S.Remove(name);return true
end
function S.Unallow(name)
    local key=S.Key(name);if key then ns.DB.shield.allowed[key]=nil;counts[key]=nil;Changed() end
    if ns.WhisperRepeat then ns.WhisperRepeat.Reset(name) end
    if ns.Spam then ns.Spam.Reset(name) end
end
function S.Reset(name,kind)
    local key=S.Key(name);if key and counts[key] then counts[key][kind]=nil end
end
function S.SetProfile(profile)
    if not S.Profiles[profile] and profile~='custom' then return end
    ns.DB.shield.profile=profile;counts={};pending={};Changed()
    if ns.WhisperRepeat then ns.WhisperRepeat.Reset() end
    if ns.Spam then ns.Spam.Reset() end
end
function S.SetTuning(profile,rules)
    if profile~='balanced' and profile~='custom' and profile~='normal' then return false,'Choose a protection preset.' end
    local copy={}
    if profile=='custom' then
        for _,kind in ipairs(S.RuleKinds) do
            local rule=type(rules)=='table' and rules[kind]
            if not ValidRule(rule) then return false,S.RuleTitles[kind]..': use 2–20 triggers, 10–600 seconds and 1–60 timeout minutes.' end
            copy[kind]={rule[1],rule[2],rule[3]}
        end
        ns.DB.shield.custom=copy
    end
    S.SetProfile(profile);return true,'Protection settings saved. Existing shield expiry times are unchanged.'
end
function S.SetOption(key,value)
    if key=='quiet' and ns.Notifications then return ns.Notifications.Set('chat',not value) end
    ns.DB.shield[key]=value;counts={};pending={};Changed()
    if ns.WhisperRepeat then ns.WhisperRepeat.Reset() end
    if ns.Spam then ns.Spam.Reset() end
end
function S.ReduceSignals(previous,now,rule)
    local recent={}
    for _,at in ipairs(previous or {}) do if now-at<=rule[2] then recent[#recent+1]=at end end
    recent[#recent+1]=now;return recent,#recent>=rule[1]
end
function S.Observe(kind,name)
    if not S.Active(kind) then return false end
    local key=S.Key(name)
    if not key or key==S.Key(S.UnitName('player')) or ns.DB.shield.allowed[key] then return false end
    if S.IsShielded(name) then return true end
    local rule=S.GetRule(kind);if not rule then return false end
    local now=ns.SessionTime()
    if not counts[key] then
        local n=0;local oldest,at
        for id,item in pairs(counts) do n=n+1;if not at or item.last<at then oldest,at=id,item.last end end
        if n>=MAX then counts[oldest]=nil end
        counts[key]={}
    end
    local record=counts[key];record.last=now
    local recent,threshold=S.ReduceSignals(record[kind],now,rule);record[kind]=recent
    if threshold then
        local reason=rule[1]..' '..kind..' signals within '..rule[2]..' seconds'
        local ok=S.Add(name,rule[3],reason)
        if ok and (ns.Notifications and ns.Notifications.Chat('shield') or not ns.Notifications and not ns.DB.shield.quiet) then ns.Print('ChatWarden Shield: temporary protection added. /ocw shield to review or undo.') end
        return ok
    end
    return false
end
function S.ObserveWhisper(message,source,key)
    if not (S.Active('whispers') or S.Active('repeatedWhispers')) or not ns.CanRead(message) or #message>ns.Engine.MAX_TEXT then return end
    key=key or ns.ChatFallbackKey('CHAT_MSG_WHISPER',message,source)
    if seen[key] then return end
    seen[key]=true;seenOrder[#seenOrder+1]=key
    if #seenOrder>1024 then seen[table.remove(seenOrder,1)]=nil end
    if ns.WhisperRepeat and ns.WhisperRepeat.Observe(message,source.sender) then return end
    if not S.Active('whispers') or ns.Modules and not ns.Modules.Enabled('chat') then return end
    -- Gommage-only masks contribute zero. Replacements are not harassment signals.
    for _,match in ipairs(ns.Find(message)) do
        if match.shieldEligible==true and not match.replacement and match.accepted~=false then S.Observe('whispers',source.sender);return end
    end
end
function S.FilterChat(event,message,...)
    if not S.Active() or not ns.CanRead(message) or #message>ns.Engine.MAX_TEXT
        or event=='CHAT_MSG_WHISPER_INFORM' or event:find('CHAT_MSG_MONSTER_',1,true) then return false end
    local source,key=ns.ChatReviewSource(event,...)
    if ns.Spam then ns.Spam.Observe(event,message,source,key) end
    if event=='CHAT_MSG_WHISPER' then S.ObserveWhisper(message,source,key) end
    local enabled
    if event=='CHAT_MSG_WHISPER' then enabled=S.Active('whispers') or S.Active('repeatedWhispers')
    else enabled=S.Active('visibleChat') end
    if not enabled then return false end
    if not S.IsShielded(source.sender) then
        local pause=ns.Spam and ns.Spam.FloodPause(event,source)
        local recruitment=ns.Spam and ns.Spam.RecruitmentMatch(event,message,source)
        if not pause and not recruitment then return false end
        source.hiddenMessage=true;source.spam=true
        source.spamReason=recruitment and 'Guild recruitment ad' or pause
        source.notificationCategory=recruitment and 'recruitment' or 'spam'
        local id=ns.Review.Add(message,{},source,key or ns.ChatFallbackKey(event,message,source),
            recruitment and '[Guild recruitment ad - original in Review]' or '[Rapid chat paused - original in Review]')
        source.filterStatus=id and (recruitment and 'hidden-recruitment' or 'hidden-flood-pause') or 'review-unavailable'
        return id~=nil,source
    end
    local contact=contacts[S.Key(source.sender)]
    source.hiddenMessage=true;source.shield=true
    source.shieldReason='ChatWarden Shield: '..(contact and contact.reason or 'Locally silenced')
    local id=ns.Review.Add(message,{},source,key or ns.ChatFallbackKey(event,message,source),'[Shielded contact - original in Review]')
    source.filterStatus=id and 'hidden-shield' or 'review-unavailable'
    return id~=nil,source -- Never lose an original that could not be retained.
end
function S.HideBubble(source)
    return source and source.kind~='npc' and S.Active('bubbles') and S.IsShielded(source.sender)
end
local events=OwnedFrame('Frame')
local map={TRADE_REQUEST='trades',DUEL_REQUESTED='duels',DUEL_TO_THE_DEATH_REQUESTED='duels',PARTY_INVITE_REQUEST='invites'}
function S.Suspend() counts,seen,seenOrder,pending={},{},{},{} end
for _,event in ipairs({'CHAT_MSG_WHISPER','TRADE_REQUEST','TRADE_SHOW','TRADE_CLOSED','TRADE_REQUEST_CANCEL',
    'DUEL_REQUESTED','DUEL_TO_THE_DEATH_REQUESTED','DUEL_FINISHED','DUEL_COUNTDOWN','PARTY_INVITE_REQUEST','PARTY_INVITE_CANCEL','PLAYER_LOGIN'}) do
    local ok=pcall(events.RegisterEvent,events,event)
    if map[event] and event~='DUEL_TO_THE_DEATH_REQUESTED' then S.capabilities[map[event]]=ok end
end
S.capabilities.whispers=true
local function Decline(kind,event,name)
    local fn=kind=='trades' and CancelTrade or kind=='duels' and CancelDuel or DeclineGroup
    local ok,result=false,nil
    if type(fn)=='function' then ok,result=pcall(fn) end
    if ok and result~=false then
        local popup=kind=='trades' and 'TRADE' or kind=='duels' and event or 'PARTY_INVITE'
        ns.SafeCall(StaticPopup_Hide,popup)
        S.Alert(name,kind,'Request declined locally')
    else S.Alert(name,kind,'Could not decline on this client; handle the request manually') end
end
local hooked=false
events:SetScript('OnEvent',function(_,event,name,...)
    if event=='PLAYER_LOGIN' then
        S.capabilities.trades=S.capabilities.trades and type(CancelTrade)=='function'
        S.capabilities.duels=S.capabilities.duels and type(CancelDuel)=='function'
        S.capabilities.invites=S.capabilities.invites and type(DeclineGroup)=='function'
        if not hooked and type(hooksecurefunc)=='function' then
            hooked=true
            for fn,kind in pairs({AcceptTrade='trades',AcceptGroup='invites',AcceptDuel='duels'}) do
                local scope=kind
                if type(_G[fn])=='function' then pcall(hooksecurefunc,fn,function()
                    if pending[scope] then S.Reset(pending[scope],scope);pending[scope]=nil end
                end) end
            end
        end
        return
    end
    if not ns.DB or not ns.DB.shield then return end
    if event=='CHAT_MSG_WHISPER' then
        local source,key=ns.ChatReviewSource(event,...);S.ObserveWhisper(name,source,key);return
    end
    if event=='TRADE_CLOSED' or event=='TRADE_REQUEST_CANCEL' then pending.trades=nil;return end
    if event=='PARTY_INVITE_CANCEL' then pending.invites=nil;return end
    if event=='DUEL_COUNTDOWN' then if pending.duels then S.Reset(pending.duels,'duels') end;pending.duels=nil;return end
    if event=='DUEL_FINISHED' then pending.duels=nil;return end
    -- TRADE_SHOW is not a new request: it can also result from our own action.
    if event=='TRADE_SHOW' then return end
    local kind=map[event]
    if kind and S.capabilities[kind] and S.Key(name) and S.Active(kind) then
        pending[kind]=name
        if S.Observe(kind,name) then Decline(kind,event,name) end
    end
end)
local elapsed=0
events:SetScript('OnUpdate',function(_,dt)
    elapsed=elapsed+dt;if elapsed<1 then return end;elapsed=0;S.Prune()
    if ns.ShieldWindow and ns.ShieldWindow:IsVisible() and ns.RefreshShield then ns.RefreshShield() end
end)
