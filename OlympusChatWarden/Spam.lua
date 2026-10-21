-- Private prototype: local behavioral spam protection, independent of rule packs.
local _,ns=...
local P={MAX_SENDERS=256,MAX_SEEN=1024,FLOOD_PAUSE=10,FLOOD_ESCALATION=60};ns.Spam=P
local senders,seen,order={},{},{}
local scopes={CHAT_MSG_CHANNEL='public',CHAT_MSG_SAY='public',CHAT_MSG_YELL='public',
    CHAT_MSG_EMOTE='public',CHAT_MSG_TEXT_EMOTE='public',CHAT_MSG_WHISPER='whispers',
    CHAT_MSG_PARTY='group',CHAT_MSG_PARTY_LEADER='group',CHAT_MSG_RAID='group',
    CHAT_MSG_RAID_LEADER='group',CHAT_MSG_RAID_WARNING='group',CHAT_MSG_INSTANCE_CHAT='group',
    CHAT_MSG_INSTANCE_CHAT_LEADER='group',CHAT_MSG_GUILD='guild',CHAT_MSG_OFFICER='guild'}
local defaults={enabled=true,advertising=true,recruitment=true,repetition=true,flooding=true,public=true,
    whispers=true,group=true,guild=true,count=5,window=10,duration=900,repeatCount=3,repeatWindow=30}
local fixed={count=true,window=true,repeatCount=true,repeatWindow=true}
local choices={count={[5]=true,[8]=true,[10]=true,[12]=true},window={[10]=true,[20]=true,[30]=true},
    repeatWindow={[10]=true,[20]=true,[30]=true},
    duration={[300]=true,[900]=true,[1800]=true},repeatCount={[3]=true,[4]=true,[5]=true}}
function P.Reset(name)
    if name then local key=ns.Shield.Key(name);if key then senders[key]=nil end
    else senders,seen,order={},{},{} end
end
function P.Initialize()
    local db=ns.DB.shield.spam
    if type(db)~='table' then db={} end
    ns.DB.shield.spam=db
    db.settingsVersion=3
    for key,value in pairs(defaults) do
        if type(value)=='boolean' then if type(db[key])~='boolean' then db[key]=value end
        elseif fixed[key] or not choices[key][db[key]] then db[key]=value end
    end
    P.Reset()
end
function P.Set(key,value)
    if fixed[key] or defaults[key]==nil or type(value)~=type(defaults[key]) then return false end
    if choices[key] and not choices[key][value] then return false end
    ns.DB.shield.spam[key]=value;P.Reset()
    if ns.RefreshSpamOptions then ns.RefreshSpamOptions() end
    return true
end
function P.Active(event)
    local db=ns.DB and ns.DB.shield and ns.DB.shield.spam
    return ns.Shield.Active() and db and db.enabled and scopes[event] and db[scopes[event]]
end
-- Detection-only folding. Never alter displayed text, identities or signed rules.
local lookalikes={['А']='a',['а']='a',['В']='b',['Е']='e',['е']='e',['К']='k',['к']='k',
    ['М']='m',['Н']='h',['О']='o',['о']='o',['Р']='p',['р']='p',['С']='c',['с']='c',
    ['Т']='t',['т']='t',['Х']='x',['х']='x',['У']='y',['у']='y',['І']='i',['і']='i',
    ['Ј']='j',['ј']='j',['Ѕ']='s',['ѕ']='s',['ԁ']='d',['ԛ']='q',['ԝ']='w',['ɡ']='g',
    ['ӏ']='l',['ℓ']='l',['ſ']='s',['Α']='a',['α']='a',['Β']='b',['Ε']='e',['ε']='e',
    ['Ι']='i',['ι']='i',['Κ']='k',['κ']='k',['Μ']='m',['Ν']='n',['Ο']='o',['ο']='o',
    ['Ρ']='p',['ρ']='p',['Τ']='t',['τ']='t',['Υ']='y',['Χ']='x',['χ']='x',
    ['\226\128\139']='',['\226\128\140']='',['\226\128\141']='',['\239\187\191']='',
    ['\194\160']=' ',['\226\128\137']=' ',['’']="'"}
local referenceLinks={item=true,spell=true,enchant=true,trade=true,profession=true,talent=true,
    achievement=true,quest=true,currency=true,battlepet=true,battlepetability=true,instancelock=true,
    journal=true,mount=true,toy=true,transmogappearance=true,transmogset=true,
    player=true,bnplayer=true,clubmember=true}
local webLinks={url=true,urlcopy=true,web=true,weblink=true,website=true,http=true,https=true}
local Domain
local function Plain(text)
    local links={total=0,web=0,reference=0}
    -- Keep visible web addresses and external URL targets. Dropping every
    -- hyperlink discarded clickable seller domains before the link check.
    -- Game-reference payloads and labels remain excluded from ad evidence.
    text=text:gsub('|H(.-)|h(.-)|h',function(target,label)
        links.total=links.total+1
        local lower=ns.Engine.Lower(target)
        local kind=lower:match('^([^:]+):')
        if referenceLinks[kind] then links.reference=links.reference+1;return ' ' end
        if webLinks[kind] or lower:find('^https?://') or lower:find('^www%.') or Domain(lower) then
            links.web=links.web+1
            return ' '..target..' '..label..' '
        end
        return ' '..label..' '
    end):gsub('|T.-|t',' '):gsub('|A.-|a',' ')
        :gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')
    text=text:gsub('[\194-\244][\128-\191]+',function(glyph)
        if lookalikes[glyph]~=nil then return lookalikes[glyph] end
        if #glyph==3 then
            local a,b,c=glyph:byte(1,3);local point=(a-224)*4096+(b-128)*64+c-128
            if point>=65281 and point<=65374 then return string.char(point-65248) end
        end
        return glyph
    end)
    return (ns.Engine.Lower(text):gsub('[ \t\r\n\v\f]+',' ')),links
end
local function Letter(byte) return byte and byte>=97 and byte<=122 end
local function Word(text,word)
    local position=1
    while true do
        local first,last=text:find(word,position,true)
        if not first then return false end
        if not Letter(text:byte(first-1)) and not Letter(text:byte(last+1)) then return true end
        position=first+1
    end
end
Domain=function(text)
    for _,ending in ipairs({'com','net','gg'}) do
        local position=1
        while true do
            local first,last=text:find('[a-z0-9%-]+%.'..ending,position)
            if not first then break end
            if not Letter(text:byte(last+1)) then return true end
            position=last+1
        end
    end
    return false
end
local function AdEvidence(message,incomingTypos)
    if not ns.CanRead(message) then return {status='unreadable'} end
    if #message>ns.Engine.MAX_TEXT then return {status='oversized'} end
    local text,links=Plain(message)
    local link=text:find('https?://%S+') or text:find('www%.[a-z0-9%-]+%.[a-z]+')
        or Domain(text)
    if not link then return {status='no-link',link=false,hyperlinks=links.total,webLinks=links.web,referenceLinks=links.reference} end
    text=text:gsub('https?://%S+',' '):gsub('www%.%S+',' '):gsub('[a-z0-9%-]+%.[a-z]+%S*',' ')
    local function Has(word) return Word(text,word) or incomingTypos and ns.TypoFilter.Contains(text,word) end
    local service=Has('gold') or Has('leveling') or Has('levelling')
        or Has('powerleveling') or Has('boost') or Has('boosting')
    local sale=Has('buy') or Has('sell') or Has('selling') or Has('wts')
        or Has('seller') or Has('cheap') or Has('paid') or Has('delivery')
        or Has('delivered') or Has('refund') or Has('discount')
        or text:find('%$%s*%d') or text:find('€%s*%d') or text:find('£%s*%d')
        or text:find('%d%s*usd') and Word(text,'usd')
    -- Some sellers describe a managed service without saying "buy" or quoting a price.
    local offer=Word(text,'our team') and (Word(text,'handle') or Word(text,'handles'))
        or Word(text,'we offer') or Word(text,'we provide') or Word(text,'we boost') or Word(text,'we level')
    return {link=true,service=service==true,sale=sale and true or false,offer=offer==true,
        hyperlinks=links.total,webLinks=links.web,referenceLinks=links.reference,
        status=not service and 'no-service' or not (sale or offer) and 'no-sale-or-offer' or 'match'}
end
function P.Advertisement(message,incomingTypos)
    return AdEvidence(message,incomingTypos).status=='match'
end
local function RecruitmentVerb(word)
    local target='recruiting'
    if word==target then return word end
    if word:sub(1,3)~='rec' or math.abs(#word-#target)>1 then return word end
    local i,j,edits=1,1,0
    while i<=#word and j<=#target do
        if word:sub(i,i)==target:sub(j,j) then i=i+1;j=j+1
        else
            edits=edits+1;if edits>1 then return word end
            if #word<#target then j=j+1
            elseif #word>#target then i=i+1
            elseif word:sub(i,i)==target:sub(j+1,j+1) and word:sub(i+1,i+1)==target:sub(j,j) then i=i+2;j=j+2
            else i=i+1;j=j+1 end
        end
    end
    if edits+(#word-i+1)+(#target-j+1)<=1 then return target end
    return word
end
function P.Recruitment(message,incomingTypos)
    if not ns.CanRead(message) or #message>ns.Engine.MAX_TEXT then return false end
    local text=Plain(message)
    local tag=text:match('<([^<>\r\n]+)>')
    local named=tag and #tag<=100 and tag:find('%S')
    if not named and not Word(text,'guild') then return false end
    -- Exempt the advertised Olympus guild, not an unrelated Olympus mention.
    -- This is a local name exception, not official federation verification.
    if named then
        if tag:find('%f[a-z0-9]olympus%f[^a-z0-9]') then return false end
    elseif text:find('^%s*olympus%f[^a-z0-9]') or text:find('%f[a-z]olympus guild%f[^a-z]') then
        return false
    end
    local joinNamed=named and text:find('%f[a-z]join%s*<')
    -- A guild named "Raid Friends" is not itself evidence of a raid pitch.
    -- Judge the invitation/activity in the body, keeping the tag for identity.
    if named then text=text:gsub('<[^<>\r\n]+>',' ',1) end
    -- One edit in the recruitment verb (for example "recuiting") is enough
    -- only after the guild context gate. Normalize before checking negations.
    text=text:gsub('%a+',function(word)
        if incomingTypos and word:sub(1,3)=='rec' and ns.TypoFilter.Pair(word,'recruiting') then return 'recruiting' end
        return RecruitmentVerb(word)
    end)
    -- Ordinary guild mentions and explicit "not recruiting" statements stay visible.
    if text:find("%f[a-z]not recruiting%f[^a-z]") or text:find("%f[a-z]not currently recruiting%f[^a-z]")
        or text:find("%f[a-z]no longer recruiting%f[^a-z]")
        or text:find("%f[a-z]isn't recruiting%f[^a-z]") or text:find("%f[a-z]aren't recruiting%f[^a-z]") then return false end
    if Word(text,'recruiting') then return true end
    if Word(text,'recruitment') and (Word(text,'open') or Word(text,'apply') or Word(text,'join')
        or Word(text,'whisper') or text:find('/w%f[^a-z]')) then return true end
    if text:find('%f[a-z]join our guild%f[^a-z]') or text:find('%f[a-z]join the guild%f[^a-z]')
        or joinNamed then return true end
    local roles=Word(text,'members') or Word(text,'raiders') or Word(text,'players')
        or Word(text,'healers') or Word(text,'tanks') or Word(text,'dps')
    local seeking=Word(text,'lfm') or Word(text,'seeking') or text:find('%f[a-z]looking for%f[^a-z]')
    if roles and seeking then return true end
    -- A guild pitch may invite a reply without using "recruiting".
    local activity=Word(text,'raid') or Word(text,'raiding') or Word(text,'raids') or Word(text,'progression')
        or Word(text,'pvp') or Word(text,'premades') or Word(text,'dungeons')
    local invitation=text:find('%f[a-z]if you%S* interested%f[^a-z]')
        or Word(text,'interested') and text:find('%f[a-z]let me know%f[^a-z]') or text:find('%f[a-z]whisper me%f[^a-z]')
        or text:find('%f[a-z]whisper for%f[^a-z]') or text:find('/w%f[^a-z]')
        or text:find('%f[a-z]message me%f[^a-z]') or text:find('%f[a-z]message for%f[^a-z]')
        or text:find('%f[a-z]dm me%f[^a-z]') or text:find('%f[a-z]dm for%f[^a-z]')
        or text:find('%f[a-z]pm me%f[^a-z]') or text:find('%f[a-z]pm for%f[^a-z]')
        or text:find('%f[a-z]pst%f[^a-z]') or text:find('%f[a-z]sign up%f[^a-z]')
    -- A direct guild-invite offer does not need a raid schedule. Other reply
    -- and sign-up wording still needs a named guild and an activity pitch.
    for _,contact in ipairs({'whisper','message','dm','pm','pst'}) do
        if text:find('%f[a-z]'..contact..'%s+for%s+a?%s*guild invite%f[^a-z]')
            or text:find('%f[a-z]'..contact..'%s+me%s+for%s+a?%s*guild invite%f[^a-z]') then return true end
    end
    if text:find('/w%s+for%s+a?%s*guild invite%f[^a-z]') then return true end
    return named and activity and invitation and true or false
end
function P.RecruitmentMatch(event,message,source)
    local db=ns.DB and ns.DB.shield and ns.DB.shield.spam
    if not P.Active(event) or not db.recruitment then return false end
    local S=ns.Shield;local key=S.Key(source and source.sender)
    return key~=nil and key~=S.Key(S.UnitName('player')) and not ns.DB.shield.allowed[key]
        and P.Recruitment(message,ns.TypoFilter.Allowed(event,source)) or false
end
function P.Prune()
    local now=ns.SessionTime()
    for key,item in pairs(senders) do if now-item.last>P.FLOOD_ESCALATION then senders[key]=nil end end
end
function P.Count() local n=0;for _ in pairs(senders) do n=n+1 end;return n end
function P.PauseRemaining(name)
    local S,db=ns.Shield,ns.DB and ns.DB.shield and ns.DB.shield.spam
    if not S.Active() or not db or not db.enabled or not db.flooding then return 0 end
    local key=S.Key(name)
    if not key or key==S.Key(S.UnitName('player')) or ns.DB.shield.allowed[key] then return 0 end
    local item=senders[key]
    return item and item.pausedUntil and math.max(0,item.pausedUntil-ns.SessionTime()) or 0
end
function P.FloodPause(event,source)
    if not P.Active(event) or P.PauseRemaining(source and source.sender)<=0 then return end
    local key=ns.Shield.Key(source and source.sender)
    local item=senders[key]
    return item.pauseReason
end
function P.Context(event,source,message)
    local db=ns.DB and ns.DB.shield and ns.DB.shield.spam;if not db then return end
    local copy={scope=scopes[event],active=P.Active(event)==true}
    for key in pairs(defaults) do copy[key]=db[key] end
    local S=ns.Shield;local key=S.Key(source and source.sender)
    copy.senderKeyValid=key~=nil;copy.ownSender=key~=nil and key==S.Key(S.UnitName('player'))
    copy.senderAllowed=key~=nil and ns.DB.shield.allowed[key]~=nil
    copy.visibleChat=ns.DB.shield.visibleChat~=false
    if message then
        local incomingTypos=ns.TypoFilter.Allowed(event,source)
        local ad=AdEvidence(message,incomingTypos)
        copy.adCandidate=ad.status=='match';copy.adStatus=ad.status;copy.adProbeVersion=3
        copy.adLink=ad.link;copy.adService=ad.service;copy.adSale=ad.sale;copy.adOffer=ad.offer
        copy.adHyperlinks=ad.hyperlinks;copy.adWebLinks=ad.webLinks;copy.adReferenceLinks=ad.referenceLinks
        copy.recruitmentCandidate=P.Recruitment(message,incomingTypos)
    end
    copy.status=source and source.filterStatus or not copy.active and 'paused'
        or not key and 'sender-unavailable' or copy.ownSender and 'own-sender'
        or copy.senderAllowed and 'allowed-sender' or 'no-trigger'
    if source and source.spamReason then
        copy.reason=source.spamReason;copy.triggered=true;copy.messageOnly=true
        if source.spamReason:find('Rapid-message burst:',1,true) then copy.floodStage='pause' end
    elseif source and source.shieldReason and source.shieldReason:find('Spam:',1,true) then
        copy.reason=source.shieldReason;copy.triggered=true
        if source.shieldReason:find('Flooding:',1,true) then copy.floodStage='timeout' end
    end
    return copy
end
function P.Copy(value)
    if type(value)~='table' then return end
    local out={}
    for key,default in pairs(defaults) do
        if type(value[key])==type(default) and (not choices[key] or choices[key][value[key]]) then out[key]=value[key] end
    end
    for _,key in ipairs({'active','triggered','messageOnly','senderKeyValid','ownSender','senderAllowed','visibleChat','adCandidate','recruitmentCandidate','adLink','adService','adSale','adOffer'}) do
        if type(value[key])=='boolean' then out[key]=value[key] end
    end
    if value.adProbeVersion==2 or value.adProbeVersion==3 then out.adProbeVersion=value.adProbeVersion end
    for _,key in ipairs({'adHyperlinks','adWebLinks','adReferenceLinks'}) do
        local n=ns.SafeNumber(value[key])
        if n and n>=0 and n<=4096 and n%1==0 then out[key]=n end
    end
    if ns.CanRead(value.adStatus) then out.adStatus=ns.Reports.Clip(value.adStatus,64) end
    if value.scope=='public' or value.scope=='whispers' or value.scope=='group' or value.scope=='guild' then out.scope=value.scope end
    if ns.CanRead(value.reason) then out.reason=ns.Reports.Clip(value.reason,256) end
    if ns.CanRead(value.status) then out.status=ns.Reports.Clip(value.status,64) end
    if value.floodStage=='pause' or value.floodStage=='timeout' then out.floodStage=value.floodStage end
    return out
end
local function Evidence(name,lines)
    local alert=ns.Shield.alerts[1]
    if alert and alert.name==name then
        alert.evidence={};for i=math.max(1,#lines-4),#lines do alert.evidence[#alert.evidence+1]=lines[i].original end
    end
end
function P.Observe(event,message,source,id)
    if not P.Active(event) or not ns.CanRead(message) or #message>ns.Engine.MAX_TEXT then return false end
    local S,db=ns.Shield,ns.DB.shield.spam
    local name=source and source.sender;local key=S.Key(name)
    if not key or key==S.Key(S.UnitName('player')) or ns.DB.shield.allowed[key] or S.IsShielded(name) then return false end
    id=id or ns.ChatFallbackKey(event,message,source)
    if seen[id] then return false end
    seen[id]=true;order[#order+1]=id
    if #order>P.MAX_SEEN then seen[table.remove(order,1)]=nil end
    local now=ns.SessionTime();local item=senders[key]
    if not item then
        if P.Count()>=P.MAX_SENDERS then
            local oldest,at;for k,v in pairs(senders) do if not at or v.last<at then oldest,at=k,v.last end end
            senders[oldest]=nil
        end
        item={lines={},flood={}};senders[key]=item
    end
    item.last=now
    local normalized,long=ns.WhisperRepeat.Normalize(message)
    local recent,similar={},0
    for _,line in ipairs(item.lines) do
        if now-line.at<=math.max(db.window,db.repeatWindow) then
            recent[#recent+1]=line
            if now-line.at<=db.repeatWindow and normalized and line.text
                and ns.WhisperRepeat.Similar(line.text,normalized,line.long,long) then similar=similar+1 end
        end
    end
    recent[#recent+1]={at=now,text=normalized,long=long,original=ns.Reports.Clip(message,512)}
    while #recent>12 do table.remove(recent,1) end
    item.lines=recent
    local flood={}
    for _,at in ipairs(item.flood) do if now-at<=db.window then flood[#flood+1]=at end end
    flood[#flood+1]=now;while #flood>12 do table.remove(flood,1) end
    item.flood=flood
    local reason
    if db.advertising and P.Advertisement(message,ns.TypoFilter.Allowed(event,source)) then reason='Sales ad: link plus gold or paid-service wording'
    elseif db.repetition and normalized and similar+1>=db.repeatCount then reason='Repeated messages: '..(similar+1)..' in '..db.repeatWindow..' seconds'
    elseif db.flooding and #flood>=db.count then
        if item.lastBurst and now-item.lastBurst<=P.FLOOD_ESCALATION then
            reason='Flooding: repeated bursts of '..db.count..' messages in '..db.window..' seconds within 60 seconds'
        else
            item.lastBurst=now;item.pausedUntil=now+P.FLOOD_PAUSE;item.flood={}
            item.pauseReason='Rapid-message burst: '..#flood..' messages in '..db.window..' seconds'
            S.Alert(name,'Flood pause',item.pauseReason..'. Chat paused for 10 seconds; no contact shield added.')
            Evidence(name,recent)
            if ns.Notifications and ns.Notifications.Chat('spam') or not ns.Notifications and not ns.DB.shield.quiet then
                ns.Print('ChatWarden: rapid chat paused for 10 seconds. /ocw shield to review or allow.')
            end
            return true
        end
    end
    if not reason then return false end
    local ok=S.Add(name,db.duration,'Spam: '..reason)
    if not ok then return false end
    -- Keep a short, session-only incident context in Shield. Never auto-send it.
    Evidence(name,recent)
    local category=reason:find('Sales ad:',1,true) and 'advertising' or 'spam'
    if ns.Notifications and ns.Notifications.Chat(category) or not ns.Notifications and not ns.DB.shield.quiet then
        ns.Print('ChatWarden Shield: '..reason..'. /ocw shield to undo or allow.')
    end
    return true
end
local events=CreateFrame('Frame')
for event in pairs(scopes) do pcall(events.RegisterEvent,events,event) end
events:SetScript('OnEvent',function(_,event,message,...)
    if not ns.DB then return end
    local source,id=ns.ChatReviewSource(event,...);P.Observe(event,message,source,id)
end)
