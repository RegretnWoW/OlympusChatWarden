-- Literal matching and alert delivery are independent of UI presentation.
local _,ns=...
local M={MAX_PHRASES=100,lastAlert=-math.huge};ns.Mentions=M
M.MAX_MATCHES=M.MAX_PHRASES+2 -- custom watches plus the automatic first/full name
local defaults={enabled=true,character=true,typos=true,sound=false,toast=false,cooldown=10}
local channelDefaults={general=true,trade=true,lfg=true,other=true,say=true,yell=true,guild=true,party=true,raid=true,whispers=true}
function M.Initialize()
    local db=type(ns.DB.mentions)=='table' and ns.DB.mentions or {};ns.DB.mentions=db;M.db=db
    for k,v in pairs(defaults) do if type(db[k])~=type(v) then db[k]=v end end
    db.cooldown=math.max(0,math.min(120,tonumber(db.cooldown) or 10))
    if type(db.channels)~='table' then db.channels={} end
    for key,v in pairs(channelDefaults) do if type(db.channels[key])~='boolean' then db.channels[key]=v end end
    local saved=db.phrases;db.phrases={};local seen={}
    for _,p in ipairs(type(saved)=='table' and saved or {}) do
        if type(p)=='table' and ns.CanRead(p.text) and #p.text>=2 and #p.text<=120 and not p.text:find('[|%c]') and #db.phrases<M.MAX_PHRASES then
            local key=ns.Engine.Lower(p.text);if not seen[key] then seen[key]=true;db.phrases[#db.phrases+1]={id=#db.phrases+1,text=p.text,enabled=p.enabled~=false,kind=p.kind=='nickname' and 'nickname' or 'phrase',channel=channelDefaults[p.channel]~=nil and p.channel or 'all'} end
        end
    end
    if M.PrepareTypos then M.PrepareTypos(true) end
end
function M.Set(key,value)
    if not ns.Membership.Allowed() or not M.db then return false end
    if key=='cooldown' then local n=tonumber(value);if not n or n<0 or n>120 then return false end;M.db[key]=n
    elseif type(defaults[key])=='boolean' and type(value)=='boolean' then M.db[key]=value else return false end
    if M.PrepareTypos then M.PrepareTypos(true) end
    ns.Activity.Changed();return true
end
function M.SetChannel(key,value)
    if not ns.Membership.Allowed() or channelDefaults[key]==nil or type(value)~='boolean' then return false end
    M.db.channels[key]=value;ns.Activity.Changed();return true
end
function M.Save(text,kind,id,channel)
    if not ns.Membership.Allowed() or not ns.CanRead(text) then return false,'Enter a phrase.' end
    text=text:match('^%s*(.-)%s*$')
    if #text<2 or #text>120 or text:find('[|%c]') then return false,'Use 2-120 characters without markup or line breaks.' end
    local item,highest=nil,0
    for _,p in ipairs(M.db.phrases) do
        highest=math.max(highest,p.id)
        if p.id==id then item=p end
        if p.id~=id and ns.Engine.Lower(p.text)==ns.Engine.Lower(text) then return false,'That phrase already exists.' end
    end
    if not item then
        if #M.db.phrases>=M.MAX_PHRASES then return false,'Remove a phrase before adding another.' end
        item={id=highest+1,enabled=true};M.db.phrases[#M.db.phrases+1]=item
    end
    item.text=text;item.kind=kind=='nickname' and 'nickname' or 'phrase';item.channel=channelDefaults[channel]~=nil and channel or 'all'
    if M.PrepareTypos then M.PrepareTypos(true) end
    ns.Activity.Changed();return true,'Watch phrase saved.',item.id
end
function M.Change(id,enabled,remove)
    if not ns.Membership.Allowed() then return false end
    for i,p in ipairs(M.db.phrases) do if p.id==id then if remove then table.remove(M.db.phrases,i) else p.enabled=enabled==true end;ns.Activity.Changed();return true end end
    return false
end
function M.Character()
    local name=ns.Shield.UnitName('player');return name and name:match('^([^%-]+)')
end
function M.CharacterNames()
    -- Read the current identity each time: no saved name or spelling dictionary
    -- is needed, and changing characters cannot leave another name watched.
    local name=M.Character();local names={}
    if name and #name>=2 then
        names[1]=name
        local first=name:match('^(%S+)')
        if first and #first>=2 and first~=name then names[2]=first end
    end
    return names
end
function M.Channel(event,channel)
    if event=='CHAT_MSG_CHANNEL' then
        local name=ns.Engine.Lower(channel or '')
        if name:find('lookingforgroup',1,true) or name:find('looking for group',1,true) then return 'lfg' end
        if name:find('trade',1,true) then return 'trade' end
        if name:find('general',1,true) then return 'general' end
        return 'other'
    end
    if event=='CHAT_MSG_WHISPER' then return 'whispers' end
    if event=='CHAT_MSG_GUILD' or event=='CHAT_MSG_OFFICER' then return 'guild' end
    if event:find('RAID',1,true) then return 'raid' end
    if event:find('PARTY',1,true) or event:find('INSTANCE_CHAT',1,true) then return 'party' end
    return event=='CHAT_MSG_SAY' and 'say' or event=='CHAT_MSG_YELL' and 'yell' or 'other'
end
local function Letter(c) return c and (c>=128 or c>=48 and c<=57 or c>=65 and c<=90 or c>=97 and c<=122 or c==95) end
function M.Plain(text)
    return (text or ''):gsub('|H.-|h(.-)|h','%1'):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('|T.-|t',''):gsub('|A.-|a','')
end
local typoMatcher,typoModels,typoKey
function M.PrepareTypos(changed)
    if not M.db or not ns.DB.typoFiltering or not M.db.typos then return end
    local phrases,models={},{}
    for _,p in ipairs(M.db.phrases) do if p.enabled and p.kind=='phrase' and #p.text>=5 then
        phrases[#phrases+1]=ns.Engine.Lower(p.text);models[ns.Engine.Lower(p.text)]=p
    end end
    local key=table.concat(phrases,'\031')
    if changed or typoKey~=key then typoMatcher=#phrases>0 and ns.Engine.CompileLiteral(phrases) or nil;typoModels=models;typoKey=key end
    if typoMatcher then ns.TypoFilter.Prepare(typoMatcher) end
end
function M.Find(text,channel,hasLinks)
    local phrases={}
    if M.db.character then for _,name in ipairs(M.CharacterNames()) do
        phrases[#phrases+1]={id=0,text=name,kind='character',enabled=true,channel='all'}
    end end
    for _,p in ipairs(M.db.phrases) do phrases[#phrases+1]=p end
    hasLinks=hasLinks or text:find('|H',1,true)~=nil
    text=M.Plain(text)
    local found,seen={},{};local lower=ns.Engine.Lower(text)
    for _,p in ipairs(phrases) do if p.enabled and (p.channel=='all' or p.channel==channel) then
        local needle=ns.Engine.Lower(p.text);local position=1
        while position<=#lower do
            local first,last=lower:find(needle,position,true);if not first then break end
            if not Letter(lower:byte(first-1)) and not Letter(lower:byte(last+1)) then
                local covered=false
                if p.kind=='character' then for _,hit in ipairs(found) do
                    if hit.kind=='character' and first>=hit.first and last<=hit.last then covered=true;break end
                end end
                if not covered then
                    if not seen[needle] then found[#found+1]={id=p.id,text=p.text,first=first,last=last,kind=p.kind};seen[needle]=true end
                    break
                end
            end
            position=last+1
        end
    end end
    if M.db.typos and ns.DB.typoFiltering and not hasLinks then
        M.PrepareTypos()
        if typoMatcher then
            local work=ns.TypoFilter.Work(text,{typoFilteringMode='balanced'})
            for _,hit in ipairs(ns.TypoFilter.Hits(typoMatcher,text,{},work)) do
                local phrase=typoMatcher.rules[hit.rule];local p=typoModels[phrase]
                if hit.typoEdits==1 and p and (p.channel=='all' or p.channel==channel) and not seen[phrase] then
                    found[#found+1]={id=p.id,text=p.text,first=hit.first,last=hit.last,kind='phrase',typo=true};seen[phrase]=true
                end
            end
        end
    end
    return found
end
function M.Observe(entry,source,preview,assessment)
    if not M.db or not M.db.enabled or not ns.Active() or not entry or entry.event=='CHAT_MSG_WHISPER_INFORM' then return end
    local own=ns.Shield.Key(ns.Shield.UnitName('player'));local sender=ns.Shield.Key(entry.sender)
    if not sender or own and sender==own or ns.Shield.IsShielded(entry.sender) or ns.Spam.PauseRemaining(entry.sender)>0 then return end
    local snapshot=entry.captureSnapshot
    if not snapshot or snapshot.actualAction=='Hidden' or source and (source.shield or source.spam) then return end
    -- An event-only capture is analyzed but cannot claim a confirmed display.
    if snapshot.actionRecorded~=true and not assessment then return end
    if entry.mentionProcessed then return end
    entry.mentionProcessed=true
    local channel=source and source.channel or entry.channel or ''
    local scope=M.Channel(entry.event,channel);if not M.db.channels[scope] then return end
    local visible=(preview or entry.original):gsub('|Hplayer:[^|]+|h(.-)|h',function(label) return ns.Activity.DisplayName(M.Plain(label)) end)
    visible=M.Plain(visible)
    local matches=M.Find(visible,scope,entry.original:find('|H',1,true)~=nil);if #matches==0 then return end
    local id=entry.deliveryKey or ns.Activity.Key(entry.event,entry.lineID,entry.original,entry.sender)
    local existing=ns.Activity.Get(id);if existing and existing.categories.mentions then return existing end
    local item=ns.Activity.Add(id,'mentions',{sender=entry.sender,event=entry.event,channel=channel,preview=visible,
        text=visible,mentionMatches=matches,timestamp=entry.timestamp,lineID=entry.lineID,action=snapshot.actualAction},false)
    if item and ns.SessionTime()-M.lastAlert>=M.db.cooldown then
        M.lastAlert=ns.SessionTime()
        if M.db.sound and type(PlaySound)=='function' then pcall(PlaySound,SOUNDKIT and SOUNDKIT.TELL_MESSAGE or 3081,'Master') end
        if M.db.toast and ns.ShowMentionToast then ns.ShowMentionToast(item) end
    end
    return item
end
function M.Unrendered(entry)
    if not entry or entry.captureSnapshot.actionRecorded or not M.db or not M.db.enabled or not ns.Active() then return end
    local source={kind='player',sender=entry.sender,channel=entry.channel,event=entry.event}
    local matches=ns.Active('chat') and ns.Find(entry.original,ns.TypoFilter.Allowed(entry.event,source),source) or {}
    local language=ns.Language.Check(entry.original,entry.event,source)
    if ns.Language.Action(ns.MatchAction(matches),language)=='Hidden' then return end
    local spam=ns.Spam.Context(entry.event,source,entry.original)
    if spam and spam.active and (spam.advertising and spam.adCandidate or spam.recruitment and spam.recruitmentCandidate) then return end
    local display=ns.Language.Display(matches,language)
    local preview=ns.Engine.Render(entry.original,display,function(original,hit) return ns.IsRedacted(hit) and '[redacted]' or hit.replacement or original end)
    M.Observe(entry,source,preview,true)
end
