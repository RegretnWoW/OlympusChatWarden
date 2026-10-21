-- Notification preferences never change filtering or remove review originals.
local _,ns=...
local N={};ns.Notifications=N
local defaults={athena=false,athenaWatched=false,athenaEarned=false,badges=true,hidden=true,redacted=false,filtered=true,language=false,shield=true,spam=false,advertising=false,recruitment=false,chat=true}
local categories={filtered=true,language=true,shield=true,spam=true,advertising=true,recruitment=true}
function N.Initialize()
    local db=ns.DB.notifications
    if type(db)~='table' then
        db={badges=ns.DB.captureAlerts~=false,chat=not ns.DB.shield.quiet}
    end
    for key,value in pairs(defaults) do if type(db[key])~='boolean' then db[key]=value end end
    ns.DB.notifications=db
    ns.DB.captureAlerts=db.badges;ns.DB.shield.quiet=not db.chat
end
function N.Get(key)
    local db=ns.DB and ns.DB.notifications
    if db and type(db[key])=='boolean' then return db[key] end
    if key=='badges' then return ns.DB and ns.DB.captureAlerts~=false end
    if key=='chat' then return ns.DB and ns.DB.shield and not ns.DB.shield.quiet end
    return defaults[key]==true
end
function N.Category(source,wordAction)
    -- Derive spam before cached categories so rc48 review rows and saved
    -- spam shields also become quiet under the new independent preference.
    local reason=source and source.shieldReason
    if ns.CanRead(reason) and reason:find('Spam: Sales ad:',1,true) then return 'advertising' end
    if ns.CanRead(reason) and reason:find('Spam:',1,true) then return 'spam' end
    if ns.CanRead(reason) and reason:find(' repeated or similar whispers within ',1,true) then return 'spam' end
    local spamReason=source and source.spamReason
    if ns.CanRead(spamReason) then
        return spamReason:find('Rapid-message burst:',1,true) and 'spam' or 'recruitment'
    end
    -- Older language entries were cached as 'filtered'. Reclassify them too,
    -- while independent high-confidence wording matches still use word alerts.
    if source and source.language and (source.language.action=='Hidden' or source.language.action=='Redacted') and not source.shield and not ns.CanRead(reason) then
        wordAction=wordAction or source.wordAction or source.matches and ns.MatchAction(source.matches)
        if wordAction~='Hidden' and wordAction~='Redacted' then return 'language' end
    end
    if source and categories[source.notificationCategory] then
        return source.notificationCategory
    end
    if source and (source.shield or ns.CanRead(reason)) then return 'shield' end
    return 'filtered'
end
function N.Allows(entry)
    local category=N.Category(entry)
    if not N.Get('badges') or not N.Get(category) then return false end
    if category=='filtered' or category=='language' then
        local action=entry and entry.action
        if action=='Hidden' then return N.Get('hidden') end
        if action=='Redacted' then return N.Get('redacted') end
        return false -- Warnings and replacements stay quiet in the feed.
    end
    return true
end
function N.Chat(category)
    return N.Get('chat') and N.Get(category or 'shield')
end
function N.Set(key,value)
    if defaults[key]==nil or type(value)~='boolean' or not ns.DB then return false end
    if not ns.DB.notifications then N.Initialize() end
    ns.DB.notifications[key]=value
    ns.DB.captureAlerts=N.Get('badges');ns.DB.shield.quiet=not N.Get('chat')
    if ns.Review then ns.Review.Notify() end
    if ns.Activity and ns.DB.shield then ns.Activity.SyncShield() end
    if ns.RefreshReview then ns.RefreshReview() end
    if ns.RefreshNotificationsOptions then ns.RefreshNotificationsOptions() end
    return true
end
