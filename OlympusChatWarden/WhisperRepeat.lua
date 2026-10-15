-- Session-only similarity counters; independent of vocabulary and chat capture.
local _,ns=...
local R={MAX_SENDERS=256,MAX_GROUPS=4,MAX_TEXT=512};ns.WhisperRepeat=R
local senders={}
function R.Reset(name)
    if name then local key=ns.Shield.Key(name);if key then senders[key]=nil end
    else senders={} end
end
function R.Prune()
    local now=ns.SessionTime()
    local rule=ns.Shield.GetRule('repeatedWhispers');local window=rule and rule[2] or 30
    for key,item in pairs(senders) do if now-item.last>window then senders[key]=nil end end
end
function R.Normalize(text)
    text=text:gsub('|H.-|h(.-)|h','%1'):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('|T.-|t',''):gsub('|A.-|a','')
    local plain=ns.Engine.Lower(text):gsub('%s+',' '):match('^%s*(.-)%s*$')
    local normalized=plain:gsub('%p',''):gsub('%s+',' '):match('^%s*(.-)%s*$')
    if normalized=='' then normalized=plain end
    if normalized=='' then return end
    if #normalized<=R.MAX_TEXT then return normalized end
    -- Long messages use full normalized content, never a shared truncated prefix.
    local a,b=5381,7
    for i=1,#normalized do local byte=normalized:byte(i);a=(a*33+byte)%4294967296;b=(b*65599+byte)%4294967296 end
    return '#'..#normalized..':'..a..':'..b,true
end
function R.Similar(a,b,longA,longB)
    if a==b then return true end
    if longA or longB or math.min(#a,#b)<4 then return false end
    local limit=math.min(3,math.max(1,math.floor(math.min(#a,#b)*0.08)))
    if math.abs(#a-#b)>limit then return false end
    -- Banded edit distance: bounded substitutions, insertions and deletions.
    local previous={};for j=0,math.min(#b,limit) do previous[j]=j end
    for i=1,#a do
        local current={[0]=i};local best=limit+1
        for j=math.max(1,i-limit),math.min(#b,i+limit) do
            local value=math.min((previous[j] or limit+1)+1,(current[j-1] or limit+1)+1,
                (previous[j-1] or limit+1)+(a:byte(i)==b:byte(j) and 0 or 1))
            current[j]=value;best=math.min(best,value)
        end
        if best>limit then return false end
        previous=current
    end
    return (previous[#b] or limit+1)<=limit
end
function R.Observe(message,name)
    local S=ns.Shield
    if not S.Active('repeatedWhispers') then return false end
    local key=S.Key(name)
    if not key or key==S.Key(S.UnitName('player')) or ns.DB.shield.allowed[key] or S.IsShielded(name) then return false end
    local text,long=R.Normalize(message);if not text then return false end
    local rule=S.GetRule('repeatedWhispers');local now=ns.SessionTime()
    if not senders[key] then
        local count,oldest,at=0,nil,nil
        for id,item in pairs(senders) do count=count+1;if not at or item.last<at then oldest,at=id,item.last end end
        if count>=R.MAX_SENDERS then senders[oldest]=nil end
        senders[key]={groups={}}
    end
    local item=senders[key];item.last=now;local groups,matched={},nil
    for _,group in ipairs(item.groups) do
        local times={}
        for _,at in ipairs(group.times) do if now-at<=rule[2] then times[#times+1]=at end end
        if #times>0 then
            group.times=times;groups[#groups+1]=group
            if not matched and R.Similar(group.text,text,group.long,long) then matched=group end
        end
    end
    item.groups=groups
    if not matched then
        if #groups>=R.MAX_GROUPS then table.remove(groups,1) end
        matched={text=text,long=long,times={}};groups[#groups+1]=matched
    end
    matched.times[#matched.times+1]=now
    if #matched.times<rule[1] then return false end
    senders[key]=nil
    local reason=rule[1]..' repeated or similar whispers within '..rule[2]..' seconds'
    local ok=S.Add(name,rule[3],reason)
    if ok and (ns.Notifications and ns.Notifications.Chat('spam') or not ns.Notifications and not ns.DB.shield.quiet) then ns.Print('ChatWarden Shield: repeated whispers silenced. /ocw shield to review or remove.') end
    return ok==true
end
function R.Count() local count=0;for _ in pairs(senders) do count=count+1 end;return count end
local events=CreateFrame('Frame');events:RegisterEvent('CHAT_MSG_WHISPER_INFORM')
events:SetScript('OnEvent',function(_,_,_,recipient)
    if ns.CanRead(recipient) then R.Reset(recipient) end
end)
