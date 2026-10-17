-- Local English spelling assistance. This module never sends or submits text.
local _,ns=...
local S={ready=false,words={},buckets={},ignored={},MAX_TEXT=8192,MAX_WORDS=256};ns.Spelling=S
local position=1
local cache,cacheOrder={},{}
local vocabulary=ns.SpellingVocabulary
local common=vocabulary and vocabulary.words or {}
-- A compact frequency signal keeps aggressive automatic correction practical.
-- The full dictionary intentionally contains rare and dialect words; this set
-- lets a common candidate outrank one of those entries without hard-coding the
-- typo that produced it. It also protects ordinary doubled-letter words.
local frequent={}
for word in ([=[
a about after again against all also am an and any are around as at away back be because been before being best better between big both but by call came can come could day did do does done down each even every few find first for form found from get give go going good got great had has have he help her here him his how i if in into is it its just keep know last left let like little long look made make many may me meet might more most much must my need never new next no not now of off old on once one only or other our out over own people place play put raid raids really right root said same say see she should show small so some something still take tell test than that the their them then there these they thing think this those through time to too try two under up us use very want was way we well went were west what when where which while who why will with work would yes yet you your
add book boss chat close cool drop feel fight friend game games gear getting group guild heal healer hello house invite item items join level loot member message name party play player players please queue ready run server start tank team text thanks trade wait world
]=]):gmatch('%S+') do frequent[word]=true end
-- Established common typo pairs supplement the general candidate model.
local automatic={teh='the',hte='the',freind='friend',freinds='friends',recieve='receive',recieved='received',
    definately='definitely',definatly='definitely',occured='occurred',seperate='separate',wierd='weird',
    becuase='because',adress='address',untill='until',thier='their',acheive='achieve',acheived='achieved',
    begining='beginning',goverment='government',neccessary='necessary',publically='publicly',
    tommorow='tomorrow',truely='truly',wich='which',woudl='would',shoudl='should',coudl='could'}
local function DB() return ns.DB and ns.DB.spelling end
function S.Active() return ns.Active() and DB() and DB().enabled==true end
local function Word(value)
    if not ns.CanRead(value) then return end
    value=ns.Engine.Lower(value:match('^%s*(.-)%s*$'))
    if #value>=2 and #value<=32 and value:match("^[a-z]+['a-z]*$") and not value:find("''",1,true) and value:sub(-1)~="'" then return value end
end
function S.Initialize()
    local saved=DB();if type(saved)~='table' then saved={} end
    local personal,n={},0
    for word,yes in pairs(type(saved.personal)=='table' and saved.personal or {}) do
        local key=Word(word)
        if yes==true and key and n<512 and not personal[key] then personal[key]=true;n=n+1 end
    end
    ns.DB.spelling={enabled=saved.enabled==true,autoCorrect=saved.autoCorrect==true,personal=personal}
end
function S.Reset()
    if S.Hide then S.Hide() end
    S.target,S.snapshot,S.results,S.pendingText,S.elapsed=nil,nil,nil,nil,0
end
function S.SetEnabled(value)
    if type(value)~='boolean' then return false end
    DB().enabled=value;S.Reset();if ns.RefreshSpellingOptions then ns.RefreshSpellingOptions() end;return true
end
function S.SetOption(key,value)
    if key~='autoCorrect' or type(value)~='boolean' then return false end
    DB()[key]=value;S.Reset();if ns.RefreshSpellingOptions then ns.RefreshSpellingOptions() end;return true
end
function S.PersonalWords()
    local out={};for word in pairs(DB() and DB().personal or {}) do out[#out+1]=word end
    table.sort(out);return out
end
function S.AddWord(value)
    local word=Word(value);if not word then return false,'Enter one English word (2-32 letters).' end
    if not DB().personal[word] and #S.PersonalWords()>=512 then return false,'Your dictionary is full (512 words).' end
    DB().personal[word]=true;cache={};cacheOrder={};S.pendingText=nil
    if ns.DB.typoFiltering then ns.PolicyChanged() end
    if ns.RefreshSpellingOptions then ns.RefreshSpellingOptions() end;return true
end
function S.RemoveWord(value)
    local word=Word(value);if not word then return false end
    DB().personal[word]=nil;cache={};cacheOrder={};S.pendingText=nil
    if ns.DB.typoFiltering then ns.PolicyChanged() end
    if ns.RefreshSpellingOptions then ns.RefreshSpellingOptions() end;return true
end
function S.Ignore(value)
    local word=Word(value);if not word then return false end
    if not S.ignored[word] then
        local count=0;for _ in pairs(S.ignored) do count=count+1 end
        if count>=512 then S.ignored={} end
    end
    S.ignored[word]=true;S.pendingText=nil
    if ns.DB.typoFiltering then ns.PolicyChanged() end;return true
end
-- Build only while opted in. Bounded batches avoid indexing 90k words at login.
function S.LoadStep()
    if S.ready then return true end
    local data=ns.SpellingDictionary and ns.SpellingDictionary.data
    if not data then return false end
    local P=ns.WardenPerformance;local deadline,start=P.Begin();local used=0
    for _=1,4000 do
        if used%32==0 and P.Expired(deadline) then break end;used=used+1
        local stop=data:find('\n',position,true)
        if not stop then S.ready=true;ns.SpellingDictionary.data=nil;P.End('spelling load',start,used);return true end
        local word=data:sub(position,stop-1);position=stop+1
        if word~='' then
            S.words[word]=true
            local key=word:sub(1,1)..#word
            S.buckets[key]=S.buckets[key] or {};S.buckets[key][#S.buckets[key]+1]=word
        end
    end
    P.End('spelling load',start,used);return false
end
function S.Known(word,names)
    return S.words[word] or common[word] or S.ignored[word] or DB() and DB().personal[word] or names and names[word]
        or word:sub(-2)=="'s" and S.Known(word:sub(1,-3),names) or false
end
-- Membership lookup only: known spellings protect against fuzzy guesses.
-- Binary search the existing sorted data without loading 90k suggestion buckets.
local filterKnown,filterOrder={},{}
function S.KnownForFiltering(word)
    if S.Known(word) then return true end
    if S.ready then return false end
    if filterKnown[word]~=nil then return filterKnown[word] end
    local data=ns.SpellingDictionary and ns.SpellingDictionary.data
    if not data then return false end
    local low,high,found=1,#data,false
    while low<=high do
        local start=math.floor((low+high)/2)
        while start>1 and data:byte(start-1)~=10 do start=start-1 end
        local stop=data:find('\n',start,true) or #data+1
        local candidate=data:sub(start,stop-1)
        if candidate==word then found=true;break
        elseif candidate<word then low=stop+1 else high=start-1 end
    end
    filterKnown[word]=found;filterOrder[#filterOrder+1]=word
    if #filterOrder>512 then filterKnown[table.remove(filterOrder,1)]=nil end
    return found
end
local function Blank(text)
    -- Keep byte positions unchanged so selecting/correcting cannot damage links.
    local function spaces(s) return string.rep(' ',#s) end
    text=text:gsub('|H.-|h.-|h',spaces):gsub('|T.-|t',spaces):gsub('|A.-|a',spaces)
        :gsub('|c%x%x%x%x%x%x%x%x',spaces):gsub('|r',spaces)
    text=text:gsub('%S+',function(token)
        local lower=ns.Engine.Lower(token)
        if lower:find('://',1,true) or lower:find('www.',1,true) or lower:find('@',1,true)
            or lower:find('%.[a-z][a-z]+[/:%p]*$') or token:find('[%d_]') then return spaces(token) end
        return token
    end)
    local command=text:match('^%s*/%S+%s*')
    if command then
        local verb=command:match('/([^%s]+)')
        -- Code, macros and addon commands are not prose. Chat commands may be.
        local chat={s=true,say=true,y=true,yell=true,p=true,party=true,g=true,guild=true,o=true,officer=true,raid=true,ra=true,r=true,reply=true}
        if not chat[ns.Engine.Lower(verb or '')] and not tonumber(verb) and verb~='w' and verb~='whisper' then return spaces(text) end
        text=spaces(command)..text:sub(#command+1)
        if verb=='w' or verb=='whisper' then
            -- Forever first-name + surname targets are ambiguous; skip slash whispers.
            return spaces(text)
        end
    end
    return text
end
function S.Analyze(text,names)
    if not ns.CanRead(text) or #text>S.MAX_TEXT or not S.ready then return {} end
    local clean=Blank(text);local out={};local index=1;local count=0
    while count<S.MAX_WORDS do
        local first,last=clean:find("[A-Za-z]+['A-Za-z]*",index)
        if not first then break end;index=last+1;count=count+1
        local original=text:sub(first,last);local word=ns.Engine.Lower(original)
        local before,after=clean:byte(first-1),clean:byte(last+1)
        -- Do not classify ASCII fragments of another writing system as English.
        if #word>=3 and #word<=32 and not (before and before>=128 or after and after>=128)
            and not original:match('^[A-Z]+$') and not S.Known(word,names) then
            out[#out+1]={word=word,original=original,first=first,last=last}
            if #out==64 then break end
        end
    end
    return out
end
local function Distance(a,b) return ns.SpellingMatch.Distance(a,b,2,false) end
function S.Suggest(value,onlyOneEdit)
    local word=Word(value);if not word or not S.ready then return {} end
    if cache[word] then return cache[word].choices,cache[word].oneEdit end
    local hits={}
    local function Add(candidate,score)
        if candidate~=word and (S.words[candidate] or common[candidate] or DB().personal[candidate]) then
            hits[candidate]=math.min(hits[candidate] or 99,score)
        end
    end
    ns.SpellingMatch.OneEdit(word,Add)
    local candidate=automatic[word];if candidate then Add(candidate,0.25) end
    -- Preserve the complete one-edit candidate set for automatic decisions;
    -- the six visible suggestions must not hide a competing likely result.
    local oneEdit={};for candidate,score in pairs(hits) do oneEdit[candidate]=score end
    if onlyOneEdit and not next(hits) then return {},oneEdit end
    -- Two-edit fallback is bounded and used only on an explicit suggestions click.
    if not next(hits) then
        local checked=0
        for length=math.max(2,#word-2),math.min(32,#word+2) do
            local key=word:sub(1,1)..length
            for _,buckets in ipairs({vocabulary and vocabulary.buckets or {},S.buckets}) do
                for _,candidate in ipairs(buckets[key] or {}) do
                    if checked>=2500 then break end;checked=checked+1
                    local d=Distance(word,candidate);if d<=2 then Add(candidate,d) end
                end
            end
        end
    end
    local function Score(candidate)
        return hits[candidate]-(frequent[candidate] and 0.25 or common[candidate] and 0.15 or 0)
    end
    local out={};for candidate in pairs(hits) do out[#out+1]=candidate end
    table.sort(out,function(a,b)
        if Score(a)~=Score(b) then return Score(a)<Score(b) end
        if math.abs(#a-#word)~=math.abs(#b-#word) then return math.abs(#a-#word)<math.abs(#b-#word) end
        return a<b
    end)
    for i=#out,7,-1 do out[i]=nil end
    cache[word]={choices=out,oneEdit=oneEdit};cacheOrder[#cacheOrder+1]=word
    if #cacheOrder>64 then cache[table.remove(cacheOrder,1)]=nil end
    return out,oneEdit
end
function S.AutoCandidate(value,names)
    local word=Word(value);if not word or not S.ready then return end
    if common[word] or S.ignored[word] or DB().personal[word] or names and names[word] then return end
    local candidate=automatic[word]
    if candidate and (S.words[candidate] or common[candidate] or DB().personal[candidate]) then return candidate end
    local originalKnown=S.Known(word,names)
    -- Common words are stronger evidence than an edit-distance match. This
    -- prevents valid words such as "too", "meet" and "root" from being folded
    -- into another word merely because they contain a repeated letter.
    if frequent[word] then return end
    -- An accidental doubled letter is a common typing error and has one clear
    -- correction when collapsing that pair creates a known word. A rare word
    -- from the large dictionary may still be repaired when the shorter result
    -- is common English; this is what makes the model useful beyond unknown
    -- dictionary entries without relying on per-typo overrides.
    if originalKnown and #word>=4 then
        local collapsed
        for i=1,#word-1 do
            if word:sub(i,i)==word:sub(i+1,i+1) then
                local shorter=word:sub(1,i)..word:sub(i+2)
                if frequent[shorter] and (S.words[shorter] or common[shorter] or DB().personal[shorter]) then
                    if collapsed and collapsed~=shorter then return end
                    collapsed=shorter
                end
            end
        end
        if collapsed then return collapsed end
    end
    -- Do not change a valid word merely because swapping its letters creates
    -- a more common word (for example, "quite" and "quiet").
    if originalKnown then return end
    local _,hits=S.Suggest(word,true)
    local best,score,runner=nil,math.huge,math.huge
    for candidate,cost in pairs(hits) do
        local ranked=cost-(frequent[candidate] and 0.25 or common[candidate] and 0.15 or 0)
        if ranked<score then runner=score;best,score=candidate,ranked
        elseif ranked<runner then runner=ranked end
    end
    if best and score<=1 and runner-score>=0.2 then return best end
end
local function Call(edit,method,...)
    if not edit or not ns.Readable(edit) then return end
    local ok,fn=pcall(function() return edit[method] end)
    if not ok or type(fn)~='function' then return end
    return ns.SafeCall(fn,edit,...)
end
S.Call=Call
function S.Eligible(edit)
    if not edit or not ns.Readable(edit) then return false end
    if Call(edit,'IsForbidden')~=false or Call(edit,'IsProtected')~=false then return false end
    if Call(edit,'GetObjectType')~='EditBox' or Call(edit,'IsVisible')~=true then return false end
    if edit.ChatWardenNoSpelling or Call(edit,'IsEnabled')==false then return false end
    for _,method in ipairs({'IsPassword','IsSecureText','IsNumeric','IsInIMECompositionMode'}) do
        local fn=edit[method]
        if type(fn)=='function' then
            local ok,value=pcall(fn,edit)
            if not ok or not ns.Readable(value) or ns.Checked(value) then return false end
        end
    end
    local text=Call(edit,'GetText')
    return ns.CanRead(text) and #text<=S.MAX_TEXT
end
function S.Correct(edit,snapshot,item,replacement)
    if not S.Active() or not S.Eligible(edit) or not ns.CanRead(snapshot) or not item then return false,'This input is no longer available.' end
    if Call(edit,'GetText')~=snapshot or snapshot:sub(item.first or 0,item.last or 0)~=item.original then
        return false,'Text changed. Open suggestions again.'
    end
    local word=Word(replacement)
    if not word or not (S.words[word] or common[word] or DB().personal[word]) then return false end
    if item.original:match('^[A-Z]') then word=word:sub(1,1):upper()..word:sub(2) end
    local maximum=ns.SafeNumber(Call(edit,'GetMaxLetters'))
    if maximum and maximum>0 and #snapshot-#item.original+#word>maximum then return false,'The corrected text would exceed this field limit.' end
    -- Native Insert triggers the field's normal user-edit path. Never submit it.
    local ok=pcall(function() edit:SetFocus();edit:HighlightText(item.first-1,item.last);edit:Insert(word) end)
    if not ok then return false,'This field does not allow corrections.' end
    S.pendingText=nil;return true
end
function S.TryAutoCorrect(edit,text)
    if not S.Active() or not DB().autoCorrect or not S.Eligible(edit) or Call(edit,'GetText')~=text then return false end
    local cursor=ns.SafeNumber(Call(edit,'GetCursorPosition'))
    if cursor and cursor~=#text then return false end
    if not text:match('[%s%.,!%?;:]$') then return false end
    local clean=Blank(text)
    local first,_,completed=clean:find("([A-Za-z]+['A-Za-z]*)[%s%.,!%?;:]+$")
    if not completed then return false end
    local before=clean:byte(first-1)
    if #completed<3 or #completed>32 or completed:match('^[A-Z]+$') or before and before>=128 then return false end
    local word=ns.Engine.Lower(completed)
    local replacement=S.AutoCandidate(word,S.Names(edit))
    if not replacement then return false end
    local item={word=word,original=completed,first=first,last=first+#completed-1}
    local suffix=text:sub(item.last+1)
    if #suffix>3 or not suffix:match('^[%s%.,!%?;:]+$') then return false end
    local ok=S.Correct(edit,text,item,replacement)
    if ok then S.lastAuto={original=item.original,replacement=replacement};return true end
    return false
end
function S.Names(edit)
    local names={}
    local function Add(value)
        if ns.CanRead(value) then for word in value:gmatch('[A-Za-z]+') do names[ns.Engine.Lower(word)]=true end end
    end
    for _,unit in ipairs({'player','target','focus','mouseover'}) do Add(ns.Shield.UnitName(unit)) end
    for i=1,40 do Add(ns.Shield.UnitName('raid'..i));if i<=4 then Add(ns.Shield.UnitName('party'..i)) end end
    Add(Call(edit,'GetAttribute','tellTarget'));return names
end
local elapsed=0
local driver=CreateFrame('Frame');S.driver=driver
driver:SetScript('OnUpdate',function(_,dt)
    elapsed=elapsed+dt;if elapsed<0.1 then return end;elapsed=0
    if not S.Active() then if S.target or S.Visible and S.Visible() then S.Reset() end;return end
    local edit=ns.SafeCall(GetCurrentKeyBoardFocus)
    if S.IsPopupFocus and S.IsPopupFocus(edit) then return end
    if not S.Eligible(edit) then S.Reset();return end
    if not S.ready then S.LoadStep();return end
    local text=Call(edit,'GetText')
    if edit~=S.target or text~=S.pendingText then
        if S.Hide then S.Hide() end
        S.target,S.pendingText,S.elapsed=edit,text,0
        if S.TryAutoCorrect(edit,text) then S.pendingText=Call(edit,'GetText') end
        return
    end
    S.elapsed=(S.elapsed or 0)+0.1
    if S.elapsed<0.3 then return end
    if S.snapshot~=text or S.lastTarget~=edit then
        S.snapshot,S.lastTarget=text,edit;S.results=S.Analyze(text,S.Names(edit))
    end
    if S.ShowHighlights then S.ShowHighlights(edit,S.results) end
end)
