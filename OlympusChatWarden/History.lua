-- Bounded per-character review history. Detection counters remain session-only.
local _,ns=...
local H={MAX_CHARACTERS=12,MAX_BYTES=8*1024*1024,MAX_CHARACTER_BYTES=2*1024*1024}
ns.History=H
local ready,restoring,dirty,queued,owner=false,false,false,false
local actions={Hidden=true,Redacted=true,Warning=true,Replaced=true,Unchanged=true}
local function NameIdentity()
    local name=ns.Shield.Key(ns.Shield.UnitName('player'))
    return name and 'name:'..name
end
local function Identity()
    local guid=ns.SafeString(ns.SafeCall(UnitGUID,'player'),128)
    if guid and guid~='' then return 'guid:'..guid end
    return NameIdentity()
end
local function Integer(value,maximum)
    return ns.SafeNumber(value) and value>=0 and value<=maximum and value%1==0 and value or nil
end
-- Copy only ordinary SavedVariables values, with byte/node/depth bounds.
-- No runtime frame, metatable, callback or cyclic reference enters the save.
local function Copy(value,budget,depth,seen)
    depth=depth or 0;seen=seen or {}
    if budget.bytes<=0 or budget.nodes<=0 or depth>10 then return end
    budget.nodes=budget.nodes-1
    local kind=type(value)
    if kind=='string' then
        if #value>32768 or #value+16>budget.bytes then return end
        budget.bytes=budget.bytes-#value-16;return value
    elseif kind=='number' then
        if not ns.SafeNumber(value) then return end
        budget.bytes=budget.bytes-16;return value
    elseif kind=='boolean' then budget.bytes=budget.bytes-8;return value
    elseif kind~='table' or seen[value] or getmetatable(value)~=nil then return end
    seen[value]=true;local out={};local count=0;budget.bytes=budget.bytes-32
    for key,item in pairs(value) do
        count=count+1;if count>512 or budget.bytes<=0 or budget.nodes<=0 then break end
        if type(key)=='string' and #key<=128 or type(key)=='number' and Integer(key,1024) then
            local copied=Copy(item,budget,depth+1,seen)
            if copied~=nil then out[key]=copied;budget.bytes=budget.bytes-(type(key)=='string' and #key+8 or 8) end
        end
    end
    seen[value]=nil;return out
end
local function List(source,limit,bytes,validate)
    local out={};local used=0;local seen={}
    if type(source)~='table' then return out,used end
    local count=math.min(#source,512)
    -- Keep the newest records within each budget, then restore chronological order.
    for i=count,math.max(1,count-limit+1),-1 do
        local budget={bytes=math.min(bytes-used,131072),nodes=5000}
        local initial=budget.bytes;local item=Copy(source[i],budget)
        if budget.bytes>0 and budget.nodes>0 and type(item)=='table' and validate(item) and not seen[item.id] then
            local size=initial-budget.bytes
            if used+size<=bytes then item.bytes=size;table.insert(out,1,item);seen[item.id]=true;used=used+size end
        end
        if used>=bytes-512 then break end
    end
    return out,used
end
local function ReviewValid(item)
    if not (Integer(item.id,2147483000) and item.id>0 and type(item.original)=='string'
        and #item.original<=ns.Review.MAX_TEXT and actions[item.action] and type(item.matches)=='table'
        and #item.matches<=ns.Review.MAX_MATCHES) then return false end
    for _,key in ipairs({'kind','event','sender','guid','class','channel','npc','questTitle','panel','zone','shieldReason','spamReason','rendered','preset','confidence','captureID','decision','addonVersion','ruleVersion','nameOriginal'}) do
        if item[key]~=nil and type(item[key])~='string' then return false end
    end
    for _,key in ipairs({'timestamp','score','threshold','exceptionCount','matchCount','reportID','questID','originalBytes'}) do
        if item[key]~=nil and not ns.SafeNumber(item[key]) then return false end
    end
    item.matchCount=Integer(item.matchCount,1000000) or #item.matches
    for _,match in ipairs(item.matches) do
        if type(match)~='table' then return false end
        for _,key in ipairs({'phrase','pack','id','origin','reason','replacement','action','ruleKind','stance','strength','certainty','contextCue','detectorType','stanceSource','target','preferenceKind'}) do
            if match[key]~=nil and type(match[key])~='string' then return false end
        end
        for _,key in ipairs({'score','threshold','first','last','targetFirst','targetLast','typoEdits','confidenceScore','contextPolicyVersion'}) do
            if match[key]~=nil and not ns.SafeNumber(match[key]) then return false end
        end
        if match.typo and (not Integer(match.first,#item.original) or match.first<1
            or not Integer(match.last,#item.original) or match.last<match.first or not match.phrase) then return false end
    end
    if item.language~=nil then
        item.language=ns.Language.Copy(item.language)
        if not item.language or not item.language.label or not item.language.reason then return false end
    end
    if item.captureSnapshot~=nil then
        if type(item.captureSnapshot)~='table' then return false end
        for _,key in ipairs({'disabledPacks','packPresets'}) do
            if item.captureSnapshot[key]~=nil and type(item.captureSnapshot[key])~='table' then return false end
        end
    end
    return true
end
local function ActivityValid(item)
    if type(item.id)~='string' or #item.id>512 or type(item.categories)~='table' then return false end
    if not (item.categories.messages==true or item.categories.mentions==true or item.categories.shield==true or item.categories.activity==true or item.categories.wanted==true or item.categories.olympusmute==true) then return false end
    if item.categories.olympusmute and (item.event~='OLYMPUSMUTE_OBSERVED' or type(item.sender)~='string' or type(item.preview)~='string') then return false end
    if item.categories.wanted and (not ns.Wanted or not ns.Wanted.ValidRecord(item.wanted)) then return false end
    for _,key in ipairs({'text','preview','sender','event','channel','action'}) do
        if item[key]~=nil and type(item[key])~='string' then return false end
    end
    if item.timestamp~=nil and not ns.SafeNumber(item.timestamp) then return false end
    if item.reviewID~=nil and not Integer(item.reviewID,2147483000) then return false end
    if item.shieldID~=nil and not Integer(item.shieldID,2147483000) then return false end
    if item.categories.mentions then
        local text=item.text or item.preview
        if type(text)~='string' or type(item.sender)~='string' or type(item.mentionMatches)~='table'
            or #item.mentionMatches>(ns.Mentions and ns.Mentions.MAX_MATCHES or 102) then return false end
        for _,match in ipairs(item.mentionMatches) do
            if type(match)~='table' or type(match.text)~='string' or not Integer(match.id,2147483000)
                or not Integer(match.first,#text) or match.first<1 or not Integer(match.last,#text) or match.last<match.first then return false end
        end
    end
    item.read=type(item.read)=='table' and item.read or {};item.quiet=type(item.quiet)=='table' and item.quiet or {}
    return true
end
local function AlertValid(item)
    return Integer(item.id,2147483000) and item.id>0 and type(item.name)=='string'
        and ns.Shield.Key(item.name)~=nil and type(item.kind)=='string' and type(item.message)=='string'
        and (item.timestamp==nil or ns.SafeNumber(item.timestamp))
end
local function Normalize(value)
    value=type(value)=='table' and value or {}
    local review,rbytes=List(value.review,ns.Review.MAX_ENTRIES,1048576,ReviewValid)
    local activity,mbytes=List(value.activity,ns.Activity.MAX_ENTRIES,786432,ActivityValid)
    -- Shield alerts are newest-first; List expects chronological input.
    local chronological={};local raw=type(value.alerts)=='table' and value.alerts or {}
    for i=math.min(#raw,200),1,-1 do chronological[#chronological+1]=raw[i] end
    local alerts,abytes=List(chronological,200,196608,AlertValid)
    local reverse={};for i=#alerts,1,-1 do reverse[#reverse+1]=alerts[i] end
    return {review=review,activity=activity,alerts=reverse,bytes=rbytes+mbytes+abytes,
        updated=ns.SafeNumber(value.updated) or 0}
end
local function Trim(store)
    local count,bytes=0,0
    for _,data in pairs(store.characters) do count=count+1;bytes=bytes+(data.bytes or 0) end
    while count>H.MAX_CHARACTERS or bytes>H.MAX_BYTES do
        local oldest,at
        for key,data in pairs(store.characters) do if key~=owner and (not at or data.updated<at) then oldest,at=key,data.updated end end
        if not oldest then break end
        bytes=bytes-store.characters[oldest].bytes;store.characters[oldest]=nil;count=count-1
    end
end
function H.Flush()
    if not ready or restoring or not owner or not ns.DB then return end
    local store=ns.DB.characterHistory
    if type(store)~='table' or type(store.characters)~='table' then return end
    if ns.DB.persistHistory==false then store.characters[owner]=nil;dirty=false;return end
    local activity={}
    for _,item in ipairs(ns.Activity.entries) do
        local row={shieldID=item.shieldAlert and item.shieldAlert.id}
        for _,key in ipairs({'id','reviewID','sender','event','channel','preview','text','mentionMatches','timestamp','action','read','quiet','categories','wanted'}) do row[key]=item[key] end
        activity[#activity+1]=row
    end
    local data=Normalize({review=ns.Review.entries,activity=activity,alerts=ns.Shield.alerts,
        updated=ns.SafeCall(time) or ns.SafeCall(GetServerTime) or 0})
    store.characters[owner]=data;Trim(store);dirty=false
end
function H.Queue()
    if not ready or restoring then return end
    dirty=true;if queued then return end;queued=true
    local function Save() queued=false;if dirty then H.Flush() end end
    if C_Timer and C_Timer.After then C_Timer.After(2,Save) else Save() end
end
function H.Initialize()
    ready=false;restoring=true;owner=Identity();H.owner=owner
    if type(ns.DB.persistHistory)~='boolean' then ns.DB.persistHistory=true end
    local old=type(ns.DB.characterHistory)=='table' and ns.DB.characterHistory or {}
    local alias=NameIdentity()
    if owner and owner~=alias and type(old.characters)=='table' and old.characters[alias] then
        old.characters[owner]=old.characters[owner] or old.characters[alias];old.characters[alias]=nil
    end
    local store={version=1,characters={}};local count=0
    -- Always retain the current character even when repairing a bloated save.
    if owner and type(old.characters)=='table' and type(old.characters[owner])=='table' then store.characters[owner]=Normalize(old.characters[owner]) end
    for key,value in pairs(type(old.characters)=='table' and old.characters or {}) do
        count=count+1;if count>64 then break end
        if key~=owner and type(key)=='string' and #key<=180 and type(value)=='table' then store.characters[key]=Normalize(value) end
    end
    ns.DB.characterHistory=store;Trim(store)
    ns.DB.historySequence=(Integer(ns.DB.historySequence,2147483000) or 0)+1
    local data=owner and ns.DB.persistHistory and store.characters[owner]
    ns.Review.entries={};ns.Review.byKey={};ns.Review.bytes=0;ns.Review.nextID=0
    ns.Shield.alerts={};ns.Shield.nextAlertID=0;ns.Activity.Initialize()
    if data then
        for _,entry in ipairs(data.review) do
            entry.restored=true;entry.key=nil;entry.lineID=nil;entry.sessionTime=0
            entry.activityID='saved-review:'..entry.id;entry.read=entry.read==true;entry.activityEvicted=true
            ns.Review.entries[#ns.Review.entries+1]=entry;ns.Review.bytes=ns.Review.bytes+entry.bytes
            ns.Review.nextID=math.max(ns.Review.nextID,entry.id)
        end
        local alerts={}
        for _,alert in ipairs(data.alerts) do
            alert.at=nil;alert.count=Integer(alert.count,1000000) or 1
            alert.activityEvicted=true;alert.chatWardenCount=alert.count;alerts[alert.id]=alert
            ns.Shield.alerts[#ns.Shield.alerts+1]=alert;ns.Shield.nextAlertID=math.max(ns.Shield.nextAlertID,alert.id)
        end
        -- Rebuild in the original shared order, including rows with two categories.
        ns.Activity.batch=(ns.Activity.batch or 0)+1
        for i,item in ipairs(data.activity) do
            local entry=item.reviewID and ns.Review.Get(item.reviewID)
            local alert=item.shieldID and alerts[item.shieldID]
            local id=alert and 'shield:'..alert.id or 'saved-activity:'..i
            if entry then entry.activityID=id;entry.activityEvicted=false end
            if alert then alert.activityEvicted=false end
            for _,category in ipairs({'messages','mentions','shield','activity','wanted','olympusmute'}) do
                if item.categories[category] and ((category=='messages' or category=='activity') and entry or category=='shield' and (alert or entry) or category=='mentions' or category=='wanted' and ns.Wanted.ValidRecord(item.wanted) or category=='olympusmute') then
                    local restored=ns.Activity.Add(id,category,{reviewID=entry and entry.id,shieldAlert=alert,
                        sender=item.sender,event=item.event,channel=item.channel,preview=item.preview,text=item.text,
                        mentionMatches=item.mentionMatches,timestamp=item.timestamp,action=item.action,wanted=item.wanted},item.quiet[category]==true)
                    if restored then restored.read[category]=item.read[category]==true end
                end
            end
        end
        ns.Activity.SyncReview();ns.Activity.SyncShield();ns.Activity.batch=ns.Activity.batch-1
    end
    restoring=false;ready=owner~=nil;dirty=false
    ns.Activity.Changed()
end
function H.CaptureID(id) return 'review:'..tostring(ns.DB.historySequence or 0)..':'..id end
function H.SetEnabled(value)
    if not ns.Membership.Allowed() then return false end
    ns.DB.persistHistory=value==true;H.Flush();return true
end
function H.Clear()
    if not ns.Membership.Allowed() then return false end
    restoring=true;ns.Review.Clear();ns.Activity.Initialize();ns.Shield.alerts={};restoring=false
    H.Flush();ns.Activity.Changed();return true
end
function H.Stats()
    return #ns.Review.entries,#ns.Activity.List('mentions'),#ns.Shield.alerts
end
local events=CreateFrame('Frame');events:RegisterEvent('PLAYER_LOGOUT');events:RegisterEvent('PLAYER_LOGIN')
events:SetScript('OnEvent',function(_,event)
    if event=='PLAYER_LOGOUT' then H.Flush()
    elseif ns.DB and (not ready or Identity()~=owner) then H.Flush();H.Initialize() end
end)
ns.Activity.Subscribe(H.Queue)
