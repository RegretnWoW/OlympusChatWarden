-- One bounded activity stream; views share IDs and category read state.
local _,ns=...
local A={entries={},byID={},MAX_ENTRIES=300,MAX_BYTES=1048576,bytes=0,listeners={}}
ns.Activity=A
local function Category(key,category)
    return not category or key==category or category=='alerts' and (key=='mentions' or key=='wanted' or key=='olympusmute')
end
function A.Initialize() A.entries={};A.byID={};A.bytes=0 end
function A.Subscribe(fn) A.listeners[#A.listeners+1]=fn end
function A.Changed()
    if (A.batch or 0)>0 then return end
    if A.changing then A.again=true;return end
    A.changing=true
    -- An optional display listener must not prevent history from being queued
    -- or leave this dispatcher permanently locked after a native UI error.
    local errors={}
    for _,fn in ipairs(A.listeners) do local ok,err=pcall(fn);if not ok then errors[#errors+1]=err end end
    if ns.OlympusIntegration then
        local ok,err=pcall(ns.OlympusIntegration.UpdateAlerts);if not ok then errors[#errors+1]=err end
    end
    A.changing=false
    if A.again then A.again=nil end
    if geterrorhandler then for _,err in ipairs(errors) do pcall(geterrorhandler(),err) end end
end
function A.Key(event,lineID,text,sender)
    return lineID and lineID>0 and ('chat:'..event..':'..lineID) or ns.ChatFallbackKey(event,text,{sender=sender})
end
function A.Remove(id,silent)
    local item=A.byID[id];if not item then return false end
    local review=item.reviewID and ns.Review.Get(item.reviewID)
    if review then review.activityEvicted=true end
    if item.shieldAlert then item.shieldAlert.activityEvicted=true end
    A.byID[id]=nil;A.bytes=A.bytes-(item.bytes or 0)
    for i,old in ipairs(A.entries) do if old==item then table.remove(A.entries,i);break end end
    if not silent then A.Changed() end;return true
end
function A.Add(id,category,data,quiet)
    local item=A.byID[id]
    if not item then
        local bytes=#(data.text or '')+#(data.preview or '')+#(data.sender or '')+512
        if bytes>A.MAX_BYTES then return end
        while #A.entries>=A.MAX_ENTRIES or A.bytes+bytes>A.MAX_BYTES do A.Remove(A.entries[1].id,true) end
        item={id=id,categories={},read={},quiet={},bytes=bytes,at=ns.SessionTime(),timestamp=data.timestamp or ns.SafeCall(time)}
        A.entries[#A.entries+1]=item;A.byID[id]=item;A.bytes=A.bytes+bytes
    end
    local before=item.bytes
    for key,value in pairs(data) do item[key]=value end
    item.bytes=#(item.text or '')+#(item.preview or '')+#(item.sender or '')+512
    A.bytes=A.bytes+item.bytes-before
    while A.bytes>A.MAX_BYTES and #A.entries>0 do A.Remove(A.entries[1].id,true) end
    if not A.byID[id] then return end
    if not item.categories[category] then item.categories[category]=true;item.read[category]=false end
    item.quiet[category]=quiet==true;A.Changed();return item
end
function A.Get(id) return A.byID[id] end
function A.Unread(category)
    if not ns.Notifications.Get('badges') then return 0 end
    local count=0
    for _,item in ipairs(A.entries) do
        for key in pairs(item.categories) do
            if Category(key,category) and not item.read[key] and not item.quiet[key] then count=count+1;break end
        end
    end
    return count
end
function A.Mark(id,category)
    local item=A.byID[id];if not item then return false end
    for key in pairs(item.categories) do if Category(key,category) then item.read[key]=true end end
    if item.shieldAlert and (not category or category=='shield') then item.shieldAlert.chatWardenRead=true end
    if item.reviewID and (not category or category==ns.Review.ActivityCategory(ns.Review.Get(item.reviewID))) then local r=ns.Review.Get(item.reviewID);if r then r.read=true end end
    A.Changed();return true
end
function A.MarkCategory(category)
    if category=='shield' then for _,alert in ipairs(ns.Shield.alerts) do alert.chatWardenRead=true end end
    for _,item in ipairs(A.entries) do
        for key in pairs(item.categories) do if Category(key,category) then item.read[key]=true end end
        if item.categories[category] and item.reviewID then local r=ns.Review.Get(item.reviewID);if r then r.read=true end end
    end
    A.Changed()
end
function A.List(category)
    local out={};for i=#A.entries,1,-1 do local item=A.entries[i]
        for key in pairs(item.categories) do if Category(key,category) then out[#out+1]=item;break end end
    end;return out
end
function A.EntryUnread(item,category)
    if not item or not item.categories then return false end
    for key in pairs(item.categories) do if Category(key,category) and not item.read[key] then return true end end
    return false
end
function A.DisplayName(name)
    name=name or 'Unknown player'
    local matches=ns.Active('chat') and ns.Find(name) or {}
    if ns.Language then matches=ns.Language.NameMatches(name,matches) end
    return ns.Engine.Render(name,matches,function(original,match) return ns.IsRedacted(match) and '[redacted]' or match.replacement or original end)
end
function A.EventLabel(item)
    if item.categories and item.categories.olympusmute then return 'OlympusMute sharing observed' end
    if item.wanted and ns.Wanted.ValidRecord(item.wanted) then
        return item.wanted.kind=='encounter' and 'Wanted Encounter' or 'Wanted Mention'
    end
    local labels={}
    local categories=item.categories or {}
    local entry=item.reviewID and ns.Review.Get(item.reviewID)
    if categories.mentions then labels[#labels+1]='Mention' end
    if categories.shield or entry and entry.shieldReason then labels[#labels+1]='Shield Alert' end
    if entry and entry.spamReason then labels[#labels+1]='Spam' end
    if entry and entry.language then labels[#labels+1]='Language Filter' end
    local action=entry and entry.action or item.action
    if categories.messages or item.reviewID or not item.categories then
        local label=ns.Review.IsNameRecord(entry) and 'Redacted Name' or ({Hidden='Hidden Message',Redacted='Redacted Message',Warning='Warning',Replaced='Replacement',Unchanged='Message'})[action]
        if label then labels[#labels+1]=label end
    end
    return #labels>0 and table.concat(labels,' / ') or nil
end
function A.SafePreview(entry)
    if ns.Review.IsNameRecord(entry) then return 'Player name covered. Ctrl + left-click the covered name to reveal it.' end
    if entry.action=='Hidden' then return '[Hidden message]' end
    return (entry.rendered or '[Filtered text]'):gsub('|TInterface\\AddOns\\OlympusChatWarden\\Media\\Bar:.-|t','[Redacted]')
end
function A.SyncReview()
    A.batch=(A.batch or 0)+1
    local present={}
    for _,entry in ipairs(ns.Review.entries) do
        if not entry.activityEvicted then
        local id=entry.activityID or entry.key or 'review:'..entry.id;present[id]=true
        local category=ns.Review.ActivityCategory(entry)
        local old=A.Get(id)
        if old then for _,key in ipairs({'messages','shield','activity'}) do if key~=category and not (key=='shield' and old.shieldAlert) then old.categories[key]=nil;old.read[key]=nil;old.quiet[key]=nil end end end
        local quiet=category=='activity' or entry.read==true or not ns.Notifications.Allows(entry)
            or category=='messages' and not ns.Review.IsUnreadAlert(entry)
        local item=A.Add(id,category,{reviewID=entry.id,sender=entry.sender or entry.npc or 'UI text',event=entry.event,
            channel=entry.channel,preview=A.SafePreview(entry),
            action=entry.action,timestamp=entry.timestamp},quiet)
        if item then item.read[category]=entry.read==true end
        end
    end
    local removed={};for _,item in ipairs(A.entries) do if item.reviewID and not present[item.id] then removed[#removed+1]=item.id end end
    for _,id in ipairs(removed) do
        local item=A.byID[id]
        if item.categories.mentions or item.shieldAlert then item.categories.messages=nil;item.categories.activity=nil;if not item.shieldAlert then item.categories.shield=nil end;item.reviewID=nil
        else A.Remove(id,true) end
    end
    A.batch=A.batch-1;A.Changed()
end
function A.SyncShield()
    A.batch=(A.batch or 0)+1
    local present={}
    for _,alert in ipairs(ns.Shield.alerts) do
        if not alert.activityEvicted then
        local id='shield:'..tostring(alert.id or alert);present[id]=true
        if alert.chatWardenCount~=alert.count then alert.chatWardenRead=false;alert.chatWardenCount=alert.count end
        local category=ns.Notifications.Category({shieldReason=alert.message})
        local item=A.Add(id,'shield',{shieldAlert=alert,sender=alert.name,preview=alert.message,event=alert.kind,action='Shield',triggerCount=alert.count,timestamp=alert.timestamp},not ns.Notifications.Get(category))
        if item then item.read.shield=alert.chatWardenRead==true end
        end
    end
    local removed={};for _,item in ipairs(A.entries) do if item.shieldAlert and not present[item.id] then removed[#removed+1]=item.id end end
    for _,id in ipairs(removed) do A.Remove(id,true) end;A.batch=A.batch-1;A.Changed()
end
