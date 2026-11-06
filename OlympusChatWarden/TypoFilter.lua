-- Private incoming-chat experiment. Match original byte ranges against the
-- installed rules; never rewrite signed models, identities or message text.
local _,ns=...
local F={Revision=0,MAX_TEXT=4096,MAX_WORDS=96,MAX_CHECKS=1200,MAX_STATES=48,MAX_HITS=128,MAX_INDEX_RULES=5000,MAX_INDEX_BYTES=180000,
    stats={messages=0,checks=0,cacheHits=0,hits=0,limited=0,builds=0}}
ns.TypoFilter=F
local indexes=setmetatable({}, {__mode='k'})
local probeCache,probeOrder={},{}
local events={CHAT_MSG_CHANNEL=true,CHAT_MSG_SAY=true,CHAT_MSG_YELL=true,CHAT_MSG_WHISPER=true,
    CHAT_MSG_PARTY=true,CHAT_MSG_PARTY_LEADER=true,CHAT_MSG_RAID=true,CHAT_MSG_RAID_LEADER=true,
    CHAT_MSG_RAID_WARNING=true,CHAT_MSG_INSTANCE_CHAT=true,CHAT_MSG_INSTANCE_CHAT_LEADER=true,
    CHAT_MSG_GUILD=true,CHAT_MSG_OFFICER=true,CHAT_MSG_EMOTE=true,CHAT_MSG_TEXT_EMOTE=true}
function F.Mode(settings) return (settings or ns.DB or {}).typoFilteringMode=='aggressive' and 'aggressive' or 'balanced' end
function F.SetMode(mode)
    if mode~='balanced' and mode~='aggressive' or not ns.DB then return false end
    ns.DB.typoFilteringMode=mode;ns.PolicyChanged()
    if ns.RefreshSpellingOptions then ns.RefreshSpellingOptions() end;return true
end
local names,namesStamp={},nil
function F.Identity(source)
    return tostring(math.floor(ns.SessionTime()))..':'..(source and ns.SafeString(source.sender,128) or '')
end
function F.Names(source)
    local stamp=math.floor(ns.SessionTime())
    if stamp~=namesStamp then namesStamp=stamp;names=ns.Spelling and ns.Spelling.Names(nil) or {} end
    local out={};for word in pairs(names) do out[word]=true end
    if source then for _,key in ipairs({'sender','recipient'}) do
        local value=source[key]
        if ns.CanRead(value) then for word in value:gmatch('[A-Za-z]+') do out[ns.Engine.Lower(word)]=true end end
    end end
    return out
end
-- Balanced repairs need a close unknown spelling. Exact words always win.
function F.Pair(word,target,mode,maximum)
    if word==target then return 0 end
    mode=mode or F.Mode()
    if mode=='balanced' then
        if #word<3 or #target<4 or #word==3 and #target~=4 or ns.Spelling.KnownForFiltering(word) then return end
        local limit=(#word>=9 and #target>=9 and word:sub(1,2)==target:sub(1,2) and word:sub(-2)==target:sub(-2)) and 2 or 1
        local distance=ns.SpellingMatch.Distance(word,target,limit,true)
        if distance<=limit then return distance end
    else
        if #word<4 or #target<4 then return end
        local limit=maximum or (#target>=7 and 2 or 1)
        local distance=ns.SpellingMatch.Distance(word,target,limit,true)
        if distance<=limit then return distance end
    end
end
function F.ContextPrefix(text,term,work)
    if not work or work.limited then return end
    local position,changed=1,false
    for target in term:gmatch('[A-Za-z]+') do
        local a,b=text:find('^[A-Za-z]+',position)
        if not a then return end
        local word=text:sub(a,b)
        if word~=target then
            if work.names[word] or work.checks>=F.MAX_CHECKS then return end
            work.checks=work.checks+1;F.stats.checks=F.stats.checks+1
            if not F.Pair(word,target,work.mode) then return end
            changed=true
        end
        position=b+1
        local _,space=text:find('^%s+',position);if space then position=space+1 end
    end
    if changed then work.contextRepairs=(work.contextRepairs or 0)+1;return position-1 end
end
local function SafeText(text)
    local function blank(value) return string.rep(' ',#value) end
    return (text:gsub('https?://%S+',blank):gsub('www%.%S+',blank):gsub('[%w._%%+%-]+@[%w.%-]+',blank))
end
function F.Allowed(event,source)
    if not ns.DB or not ns.DB.typoFiltering or not ns.Active('chat') or not events[event] or not source or source.kind~='player' then return false end
    local key=ns.Shield and ns.Shield.Key(source.sender)
    return key~=nil and key~=ns.Shield.Key(ns.Shield.UnitName('player'))
end
function F.Set(value)
    if type(value)~='boolean' or not ns.DB then return false end
    ns.DB.typoFiltering=value;ns.PolicyChanged()
    if ns.RefreshSpellingOptions then ns.RefreshSpellingOptions() end
    return true
end
local function Tokens(text,maximum)
    local out={};local lower=ns.Engine.Lower(text);local position=1
    maximum=maximum or F.MAX_WORDS
    while #out<maximum do
        local first,last=lower:find('[a-z]+',position)
        if not first then break end;position=last+1
        local before,after=lower:byte(first-1),lower:byte(last+1)
        local function blocked(c) return c and (c>=128 or c>=48 and c<=57 or c==95) end
        out[#out+1]={word=lower:sub(first,last),first=first,last=last,valid=not blocked(before) and not blocked(after) and last-first<32}
    end
    return out,position<=#text and #out==maximum
end
local function Signatures(word,fn)
    fn(word)
    for i=1,#word do fn(word:sub(1,i-1)..word:sub(i+1)) end
end
local function Bucket(map,key,word)
    local list=map[key];if not list then list={};map[key]=list end
    if #list<96 then list[#list+1]=word end
end
local function Build(matcher)
    local index={root={},words={},deletes={},edges={},cache={},order={},ready=false,position=1,bytes=0}
    indexes[matcher]=index;F.stats.builds=F.stats.builds+1
    local function Step()
        if indexes[matcher]~=index or not ns.Active() then return end
        local stop=math.min(#matcher.rules,F.MAX_INDEX_RULES,index.position+79)
        for id=index.position,stop do
            local phrase=matcher.rules[id];local meta=ns.RuleMeta and ns.RuleMeta[phrase]
            local personal=ns.Personal and matcher==ns.Personal.matcher and ns.Personal.byPhrase[phrase]
            if (not personal or personal.action~='Unchanged') and (matcher~=ns.Matcher or not meta or not (ns.DB.disabledPacks and ns.DB.disabledPacks[meta.pack])) and index.bytes+#phrase<=F.MAX_INDEX_BYTES then
                index.bytes=index.bytes+#phrase
                local words={};for word in phrase:gmatch('[a-z]+') do words[#words+1]=word end
                if #words>0 and #words<=12 and not phrase:find("[^a-z %-']") then
                    local node=index.root
                    for _,word in ipairs(words) do
                        if not index.words[word] then
                            index.words[word]=true
                            if #word>=4 and #word<=32 then
                                Signatures(word,function(signature) Bucket(index.deletes,signature,word) end)
                                Bucket(index.edges,'p'..word:sub(1,2)..#word,word)
                                Bucket(index.edges,'s'..word:sub(-2)..#word,word)
                            end
                        end
                        node[word]=node[word] or {};node=node[word]
                    end
                    node[false]=node[false] or {};node[false][#node[false]+1]=id
                end
            end
        end
        index.position=stop+1
        if stop==#matcher.rules or stop==F.MAX_INDEX_RULES then index.ready=true;F.Revision=F.Revision+1
        elseif C_Timer and C_Timer.After then C_Timer.After(0,Step)
        else Step() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0,Step) else Step() end
    return index
end
function F.Prepare(matcher) if matcher then return indexes[matcher] or Build(matcher) end end
function F.Invalidate()
    indexes=setmetatable({}, {__mode='k'});probeCache,probeOrder={},{};F.Revision=F.Revision+1
    if ns.DB and ns.DB.typoFiltering and ns.Matcher and ns.Active() then
        ns.Confidence.PrepareTypos(ns.DB,Build)
        if ns.Mentions and ns.Mentions.PrepareTypos then ns.Mentions.PrepareTypos() end
    end
end
function F.Work(text,settings,source)
    F.stats.messages=F.stats.messages+1
    return {checks=0,hits=0,limited=#text>F.MAX_TEXT,mode=F.Mode(settings),names=F.Names(source),ambiguous=0}
end
local function Choices(index,word,work)
    local cacheKey=work.mode..':'..word
    if index.cache[cacheKey] then F.stats.cacheHits=F.stats.cacheHits+1;return index.cache[cacheKey] end
    local out,seen={},{}
    if index.words[word] then out[1]={word=word,edits=0};seen[word]=true end
    if #word<(work.mode=='balanced' and 3 or 4) or #word>32 then return out end
    if work.mode=='balanced' and ns.Spelling.KnownForFiltering(word) then return out end
    local limit=work.mode=='aggressive' and (#word>=7 and 2 or 1) or (#word>=9 and 2 or 1)
    local checked=0
    local function Consider(candidate)
        if seen[candidate] then return end;seen[candidate]=true
        if checked>=64 or work.checks>=F.MAX_CHECKS then work.limited=true;return end
        checked=checked+1;work.checks=work.checks+1;F.stats.checks=F.stats.checks+1
        local distance=F.Pair(word,candidate,work.mode,limit)
        if distance then out[#out+1]={word=candidate,edits=distance} end
    end
    Signatures(word,function(signature) for _,candidate in ipairs(index.deletes[signature] or {}) do Consider(candidate) end end)
    if limit==2 then
        for length=#word-2,#word+2 do
            for _,side in ipairs({'p'..word:sub(1,2),'s'..word:sub(-2)}) do
                for _,candidate in ipairs(index.edges[side..length] or {}) do Consider(candidate) end
            end
        end
    end
    table.sort(out,function(a,b) return a.edits<b.edits or a.edits==b.edits and a.word<b.word end)
    for i=#out,7,-1 do out[i]=nil end
    if not work.limited then
        index.cache[cacheKey]=out;index.order[#index.order+1]=cacheKey
        if #index.order>256 then index.cache[table.remove(index.order,1)]=nil end
    end
    return out
end
function F.Hits(matcher,text,exact,work)
    if not work or work.limited or #text>F.MAX_TEXT then return {} end
    local index=indexes[matcher] or Build(matcher)
    if not index.ready then return {} end
    local out,seen,offset,words={}, {},0,0
    for _,hit in ipairs(exact or {}) do seen[hit.first..':'..hit.last..':'..hit.rule]=true end
    for _,piece in ipairs(ns.Engine.Segments(text)) do
        if piece.editable then
            local tokens,limited=Tokens(SafeText(piece.text),F.MAX_WORDS-words);words=words+#tokens
            if limited then work.limited=true end
            local choices={}
            for i,token in ipairs(tokens) do
                if work.mode=='balanced' and work.names[token.word] then choices[i]=index.words[token.word] and {{word=token.word,edits=0}} or {}
                else choices[i]=token.valid and Choices(index,token.word,work) or {} end
            end
            for first,token in ipairs(tokens) do
                local states={{node=index.root,edits=0,changed=0}}
                for last=first,math.min(#tokens,first+11) do
                    if last>first and not piece.text:sub(tokens[last-1].last+1,tokens[last].first-1):match("^[ \t%-']+$") then break end
                    local nextStates={}
                    for _,state in ipairs(states) do for _,choice in ipairs(choices[last]) do
                        local child=state.node[choice.word];local edits=state.edits+choice.edits
                        local changed=state.changed+(choice.edits>0 and 1 or 0)
                        if child and edits<=(work.mode=='balanced' and 2 or 3) and changed<=2 and #nextStates<F.MAX_STATES then
                            nextStates[#nextStates+1]={node=child,edits=edits,changed=changed}
                            if edits>0 and child[false] then for _,id in ipairs(child[false]) do
                                local x,y=offset+token.first,offset+tokens[last].last;local key=x..':'..y..':'..id
                                if not seen[key] and #out<F.MAX_HITS then
                                    seen[key]=true;out[#out+1]={first=x,last=y,rule=id,typo=true,typoEdits=edits,
                                        segmentFirst=offset+1,segmentLast=offset+#piece.text}
                                end
                            end end
                        end
                    end end
                    states=nextStates;if #states==0 then break end
                end
            end
        end
        offset=offset+#piece.text
    end
    -- Prefer the nearest phrase for an identical original span. Otherwise a
    -- two-edit singular rule could overpower a closer one-edit plural rule
    -- merely because its signed score is higher. Exact matches win that span.
    local nearest={}
    for _,hit in ipairs(exact or {}) do nearest[hit.first..':'..hit.last]=0 end
    for _,hit in ipairs(out) do
        local key=hit.first..':'..hit.last
        nearest[key]=math.min(nearest[key] or 99,hit.typoEdits)
    end
    local alternatives,best={},{}
    if work.mode=='balanced' then for _,hit in ipairs(out) do
        local key=hit.first..':'..hit.last
        if hit.typoEdits==nearest[key] then
            local meta=matcher==ns.Matcher and ns.RuleMeta[matcher.rules[hit.rule]]
            -- Existing zero-score aliases for one stock identity are equivalent
            -- guesses. Count that identity once; do not merge optional phrases,
            -- nicknames, preference terms or different personal actions.
            local equivalent=meta and (meta.pack=='guild' and meta.base==0 or meta.pack=='creator' and meta.kind=='alias')
            local group=equivalent and meta.pack..':alias' or 'rule:'..hit.rule
            alternatives[key]=alternatives[key] or {};alternatives[key][group]=true
            if not best[key] or matcher.rules[hit.rule]<matcher.rules[best[key].rule] then best[key]=hit end
        end
    end end
    local counts={}
    for key,groups in pairs(alternatives) do local n=0;for _ in pairs(groups) do n=n+1 end;counts[key]=n end
    local filtered={}
    for _,hit in ipairs(out) do
        local key=hit.first..':'..hit.last
        if hit.typoEdits==nearest[key] and (work.mode~='balanced' or counts[key]==1 and best[key]==hit) then filtered[#filtered+1]=hit
        elseif work.mode=='balanced' and (counts[key] or 0)>1 then work.ambiguous=work.ambiguous+1 end
    end
    out=filtered
    work.hits=work.hits+#out;F.stats.hits=F.stats.hits+#out
    if work.limited then F.stats.limited=F.stats.limited+1 end
    return out
end
-- Behavioral ad keywords use the same distance primitive, with a separate
-- small cache. URL/guild context gates remain in Spam.lua.
function F.Contains(text,target)
    if not target:match('^[a-z]+$') or #target<4 or #text>F.MAX_TEXT then return false end
    local mode=F.Mode();local key=mode..':'..text
    local probe=probeCache[key]
    if not probe then
        probe={tokens=Tokens(SafeText(text)),results={},checks=0};probeCache[key]=probe;probeOrder[#probeOrder+1]=key
        if #probeOrder>64 then probeCache[table.remove(probeOrder,1)]=nil end
    end
    if probe.results[target]~=nil then return probe.results[target] end
    local limit=#target>=7 and 2 or 1;local found=false
    for _,token in ipairs(probe.tokens) do
        if token.valid and #token.word>=4 and math.abs(#token.word-#target)<=limit and probe.checks<384 then
            probe.checks=probe.checks+1
            if F.Pair(token.word,target,mode) then found=true;break end
        end
    end
    probe.results[target]=found;return found
end
function F.Context(active,work,settings)
    local pending=0;for _,index in pairs(indexes) do if not index.ready then pending=pending+1 end end
    return {enabled=(settings or ns.DB or {}).typoFiltering==true,active=active==true,mode=work and work.mode or F.Mode(settings),version=3,ambiguous=work and work.ambiguous or 0,contextRepairs=work and work.contextRepairs or 0,
        maxText=F.MAX_TEXT,maxWords=F.MAX_WORDS,maxChecks=F.MAX_CHECKS,revision=F.Revision,pendingIndexes=pending,
        limited=work and work.limited==true or false,checks=work and work.checks or 0}
end
local identityEvents=CreateFrame('Frame')
for _,event in ipairs({'GROUP_ROSTER_UPDATE','PARTY_MEMBERS_CHANGED','PLAYER_TARGET_CHANGED','PLAYER_FOCUS_CHANGED','PLAYER_ENTERING_WORLD'}) do
    pcall(identityEvents.RegisterEvent,identityEvents,event)
end
identityEvents:SetScript('OnEvent',function() namesStamp=nil;F.Revision=F.Revision+1 end)
