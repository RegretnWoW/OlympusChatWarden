-- Pack-gated stock protection, with reusable bounded clause/quotation context.
-- Optional vocabulary and its policy remain in verified authored packs.
local _,ns=...
local P={VERSION=1};ns.ProtectionContext=P
local E=ns.Engine
local function Trim(s) return s:match('^%s*(.-)%s*$') end
local function Word(c) return c~='' and (c:match('[%w_]') or c:byte()>=128) end
local function Any(s,list)
    for _,phrase in ipairs(list) do
        local at=1
        while true do
            local a,b=s:find(phrase,at,true);if not a then break end
            if not Word(s:sub(a-1,a-1)) and not Word(s:sub(b+1,b+1)) then return phrase,a,b end
            at=a+1
        end
    end
end
local function Prefix(s,list,work)
    for _,phrase in ipairs(list) do
        local n=E.EvasionPrefix(s,phrase) or work and ns.TypoFilter and ns.TypoFilter.ContextPrefix(s,phrase,work)
        if n then return phrase,n end
    end
end
local function Suffix(s,list)
    for _,phrase in ipairs(list) do
        local first=#s-#phrase+1
        if first>=1 and s:sub(first)==phrase and not Word(s:sub(first-1,first-1)) then return phrase,first end
        if phrase:find("'",1,true) then
            local variant=phrase:gsub("'",'’');local at=#s-#variant+1
            if at>=1 and s:sub(at)==variant and not Word(s:sub(at-1,at-1)) then return phrase,at end
        end
        local n=E.EvasionSuffix(s,phrase);if n then return phrase,n end
    end
end
local function Result(kind,cue,a,b)
    local strong=kind=='attack' or kind=='severe' or kind=='deathWish' or kind=='threat'
    return {eligible=kind~=nil,kind=kind,stance=kind=='threat' and 'threat' or kind and 'criticism' or 'neutral',
        strength=kind=='threat' and 'threat' or strong and 'strong' or kind=='groupInsult' and 'moderate' or kind and 'mild' or 'none',
        certainty=kind and 'high' or 'low',contextCue=cue,first=a,last=b,
        confidenceScore=kind=='threat' and 95 or strong and 90 or kind=='groupInsult' and 82 or kind and 55 or 0,
        shieldEligible=strong,detectorType='subjectProtection',stanceSource='inferred',contextPolicyVersion=3}
end
local actions={
    guild={minor={'Unchanged','Warning','Redacted'},roast={'Unchanged','Warning','Redacted'},
        groupInsult={'Unchanged','Redacted','Redacted'},attack={'Warning','Redacted','Hidden'},
        severe={'Warning','Hidden','Hidden'},deathWish={'Warning','Hidden','Hidden'},threat={'Hidden','Hidden','Hidden'}},
    creator={minor={'Unchanged','Unchanged','Warning'},roast={'Unchanged','Unchanged','Warning'},
        groupInsult={'Unchanged','Redacted','Redacted'},attack={'Warning','Redacted','Hidden'},
        severe={'Warning','Hidden','Hidden'},deathWish={'Warning','Hidden','Hidden'},threat={'Hidden','Hidden','Hidden'}},
    country={minor={'Unchanged','Warning','Redacted'},roast={'Unchanged','Warning','Redacted'},
        groupInsult={'Unchanged','Warning','Redacted'},attack={'Warning','Redacted','Hidden'},
        severe={'Warning','Hidden','Hidden'},deathWish={'Warning','Hidden','Hidden'},threat={'Hidden','Hidden','Hidden'}}}
function P.Action(pack,kind,preset,affectionate)
    local row=actions[pack] and actions[pack][kind]
    if not row then return 'Unchanged' end
    local column=preset=='strict' and 1 or preset=='balanced' and 2 or 3
    if affectionate and kind=='minor' then return column==1 and 'Unchanged' or 'Warning' end
    return row[column]
end

-- Replace non-readable markup with equal-length blanks: byte offsets still
-- refer to the original, and a link/texture is a hard context boundary.
function P.Prepare(lower,hits,matcher,settings,original)
    local state={quotes={},targets={},concepts={},byPack={guild={},creator={}},regions={}}
    local parts,offset,regionFirst={},0,1
    -- Parse native escapes before folding ASCII case: |H / |T / |A are
    -- case-sensitive. Folding first can erase a hyperlink's boundary.
    for _,piece in ipairs(E.Segments(original or lower)) do
        local color=piece.text:match('^|c%x%x%x%x%x%x%x%x$') or piece.text=='|r'
        parts[#parts+1]=piece.editable and E.Lower(piece.text) or string.rep(' ',#piece.text)
        if not piece.editable and not color then
            state.regions[#state.regions+1]={regionFirst,offset}
            regionFirst=offset+#piece.text+1
        end
        offset=offset+#piece.text
    end
    state.regions[#state.regions+1]={regionFirst,#lower}
    state.plain=table.concat(parts)
    local open,quote,i=nil,nil,1
    while i<=#state.plain do
        local s=state.plain;local c=s:sub(i,i);local q,n=c,1
        if s:sub(i,i+2)=='“' or s:sub(i,i+2)=='‘' then q=s:sub(i,i+2);n=3
        elseif s:sub(i,i+2)=='”' or s:sub(i,i+2)=='’' then q=s:sub(i,i+2);n=3 end
        local apostrophe=(q=="'" or q=='’') and Word(s:sub(i-1,i-1)) and Word(s:sub(i+n,i+n))
        if not apostrophe then
            if not open and (q=='"' or q=="'" or q=='“' or q=='‘') then open,quote={first=i,innerFirst=i+n},q
            elseif open and (q==quote or quote=='“' and q=='”' or quote=='‘' and q=='’') then
                open.last=i+n-1;open.innerLast=i-1;state.quotes[#state.quotes+1]=open;open,quote=nil,nil
            end
        end
        i=i+n
    end
    if open then open.last=#state.plain;open.innerLast=#state.plain;open.unclosed=true;state.quotes[#state.quotes+1]=open end
    for _,hit in ipairs(hits) do
        local meta=ns.RuleMeta[matcher.rules[hit.rule]]
        -- Keep signed topic ranges for bounded object-list grammar, including
        -- installed disabled packs as grammatical boundaries only. Each pack
        -- still independently controls whether it can contribute an action.
        if meta and meta.contractPolicy and meta.purpose=='topic' and meta.role=='topic' then
            state.concepts[#state.concepts+1]={first=hit.first,last=hit.last}
        end
        if meta and actions[meta.protectionProfile or meta.pack] and not (settings.disabledPacks and settings.disabledPacks[meta.pack]) then
            local target={first=hit.first,last=hit.last,pack=meta.pack}
            state.targets[#state.targets+1]=target
            local list=state.byPack[meta.pack] or {};state.byPack[meta.pack]=list;list[#list+1]=target
        end
    end
    for _,list in pairs(state.byPack) do table.sort(list,function(a,b) return a.first<b.first end) end
    table.sort(state.concepts,function(a,b) return a.last<b.last or a.last==b.last and a.first>b.first end)
    return state
end
function P.Scope(state,hit)
    local s=state.plain;local first,last=math.max(1,hit.first-240),math.min(#s,hit.last+240)
    local regionFirst,regionLast=1,#s
    local low,high=1,#state.regions
    while low<=high do
        local mid=math.floor((low+high)/2);local range=state.regions[mid]
        if hit.first<range[1] then high=mid-1 elseif hit.first>range[2] then low=mid+1
        else first=math.max(first,range[1]);last=math.min(last,range[2]);regionFirst,regionLast=range[1],range[2];break end
    end
    local quote
    low,high=1,#state.quotes
    while low<=high do
        local mid=math.floor((low+high)/2);local q=state.quotes[mid]
        if hit.first<q.innerFirst then high=mid-1 elseif hit.first>q.innerLast then low=mid+1
        else if hit.last<=q.innerLast then quote=q end;break end
    end
    local function Sentence(c,i)
        if c:match('[%.!%?;\n]') then
            -- Keep punctuation evasion inside a word, but never cross a normal
            -- sentence boundary or a semicolon to find an unrelated assertion.
            if c~=';' and c~='\n' and Word(s:sub(i-1,i-1)) and Word(s:sub(i+1,i+1)) then return false end
            return true
        end
    end
    for i=hit.first-1,first,-1 do if Sentence(s:sub(i,i),i) then first=i+1;break end end
    for i=hit.last+1,last do if Sentence(s:sub(i,i),i) then last=i-1;break end end
    if quote then first=math.max(first,quote.innerFirst);last=math.min(last,quote.innerLast) end
    local sentenceFirst,sentenceLast=first,last
    local separators={' but ',' however ',' however, ',' and ',' whereas ',' yet ',','}
    for _,sep in ipairs(separators) do
        local at=first
        while true do
            local a,b=s:find(sep,at,true);if not a or a>last then break end
            if b<hit.first then first=math.max(first,b+1)
            elseif a>hit.last then last=math.min(last,a-1);break end
            at=b+1
        end
    end
    return {first=first,last=last,regionFirst=regionFirst,regionLast=regionLast,sentenceFirst=sentenceFirst,sentenceLast=sentenceLast,quote=quote,
        before=Trim(s:sub(first,hit.first-1)),after=Trim(s:sub(hit.last+1,last))}
end
local defenses={"don't say","do not say","stop saying","don't call","do not call","stop calling",'avoid saying',
    'wrong to say','wrong to call','not saying','never said','never called',"don't think",'do not think',
    "don't believe",'do not believe','not true that','no one should say','nobody should say','disagree with',
    "don't agree with",'do not agree with','reject the statement','oppose the idea',"don't support the claim",'do not support the claim','not all'}
local reports={'said','says','say','saying','told','wrote','writes','claims','claimed','reported','quoted','quoting',
    'hear','heard','read','reads','reading','the phrase','the term','the quote','definition of','meaning of'}
local questions={'why','how','what','when','where','who','which','is','are','do','does','did','can','could','should','would','will','has','have','if'}
local function Guard(state,hit,context)
    local b,a=context.before:gsub('’',"'"),context.after
    local surrounding=state.plain:sub(math.max(1,context.first-80),context.last+80)
    if Any(b,defenses) or Suffix(b,{"don't hate",'do not hate',"doesn't hate",'does not hate','never hated',
        "don't fucking hate",'do not fucking hate',"don't really hate",'do not really hate','never fucking hated'}) then
        return 'negated, disavowed or discouraged expression'
    end
    if Prefix(b,questions) or state.plain:sub(context.sentenceLast+1,context.sentenceLast+1)=='?' then
        return 'question or conditional; no asserted attack established'
    end
    if Any(b,{'i wonder','we wonder','wondering if','whether','not sure if','unsure if','maybe','perhaps','apparently','allegedly','supposedly'}) then
        return 'uncertain or attributed interpretation; left visible'
    end
    if Any(b,{'as if','yeah right'}) or Any(a,{'yeah right'}) or surrounding:find('/s',1,true) then
        return 'sarcasm or uncertain interpretation; left visible'
    end
    if context.quote then
        local q=context.quote
        if q.unclosed then return 'unfinished quotation; stance uncertain' end
        local lead=Trim(state.plain:sub(math.max(1,q.first-80),q.first-1))
        local tail=Trim(state.plain:sub(q.last+1,math.min(#state.plain,q.last+80)))
        if Any(lead,defenses) then return 'disavowed quotation' end
        local endorsed=Suffix(lead,{'i agree with','we agree with','i endorse','we endorse'})
        local cue,n=Prefix(tail,{'and i agree','and we agree','and i endorse that','and we endorse that'})
        if cue then
            local rest=Trim(tail:sub(n+1))
            endorsed=rest=='' or rest:match('^%p+$') or Prefix(rest,{'with that insult','with that statement','with that quote'})
        end
        if not endorsed or Prefix(tail,{'but i disagree','but we disagree','but i do not agree',"but i don't agree"}) then
            return 'quoted wording without a clearly attached endorsement'
        end
    elseif Any(b,reports) then return 'reported wording without a clearly attached endorsement' end
end
local nouns={'guild members','guild players','members','players','people','guild'}
local fillers={'not only','all','just','really','so','absolute','absolutely','fucking','a bunch of','full of','nothing but',
    'such','total','complete','literally','still','a','an','the'}
local roasts={'idiots','idiot','clowns','clown','fools','fool','losers','loser','bozos','bozo','scrubs','scrub','noobs','noob'}
local extreme={'disgusting piece of shit','pieces of shit','piece of shit','fucking trash','fucking garbage','fucking idiots','fucking idiot'}
local minor={'trash','garbage','useless','sucks','suck'}
local function AfterSpace(state,hit,context)
    local at=hit.last+1
    while at<=context.last and state.plain:sub(at,at):match('%s') do at=at+1 end
    return Trim(state.plain:sub(at,context.last)),at
end
local function Consume(s,at,n)
    local rest=s:sub(n+1);local leading=rest:match('^%s*')
    return Trim(rest),at+n+#leading
end
local function Classify(state,hit,meta,context,work)
    local s=state.plain;local before=Trim(s:sub(context.first,hit.first-1))
    local tail,at=AfterSpace(state,hit,context)
    local vocative=Trim(s:sub(context.sentenceFirst,hit.first-1)):gsub('[,%s]+$','')
    if context.before=='' and (tail=='' or tail:match('^%p+$')) then
        local term,count=Prefix(vocative,{'kill yourself','kys'},work)
        if term and Trim(vocative:sub(count+1))=='' then
            return Result('threat','explicit self-harm encouragement with a covered vocative',context.sentenceFirst,context.sentenceFirst+count-1)
        end
    end
    if tail=='' then
        local following=s:sub(hit.last+1,context.sentenceLast)
        if following:match('^%s*,') then
            local rest=following:gsub('^[,%s]+','');local term,count=Prefix(rest,{'kill yourself','kys'},work)
            if term then local a=context.sentenceLast-#rest+1;return Result('threat','explicit covered self-harm encouragement',a,a+count-1) end
        end
    end
    -- A possessive followed by a specific object is criticism of that object,
    -- not automatically a personal attack. Group membership is handled below.
    if Prefix(tail,{"'s"}) then tail,at=Consume(tail,at,2) end
    local group=meta.role=='groupReference'
    local noun,n=Prefix(tail,nouns)
    if noun then group=noun~='guild';tail,at=Consume(tail,at,n) end
    if Suffix(before,{'all','every member of','all members of','members of','everyone in'}) then group=true end
    local selfHarm,nself=Prefix(tail,{'kill yourself','kys'},work)
    if selfHarm then return Result('threat','explicit covered self-harm encouragement',at,at+nself-1) end
    local harm,pos=Suffix(before,{'kill yourself','kys'})
    if harm then return Result('threat','explicit covered self-harm encouragement',context.first+pos-1,hit.first-1) end
    if Any(tail,{'in a duel','in pvp','in the arena','in arena','in game','in-game'}) then
        return Result(nil,'gameplay wording; real-world harm is not established')
    end
    local threat,pos=Suffix(before,{'i will kill','we will kill',"i'll kill",'i am going to kill',"i'm going to kill",'i want to kill','we want to kill',
        'i will murder','we will murder',"i'll kill every member of",'i will kill every member of','we will kill every member of',
        'i will hurt',"i'll hurt",'i want to hurt','i will attack','we will attack',"i'll attack", "we'll attack",
        'i am going to attack',"i'm going to attack",'we are going to attack',"we're going to attack"})
    -- The real-world cue must attach to the target, not a different object or
    -- a negated aside such as "in game, not IRL". Bare combat wording is uncertain.
    if threat and Prefix(tail,{'in real life','irl','at your house','at his house','at their house'}) then
        return Result('threat','explicit real-world harm directed at a covered subject',context.first+pos-1,context.last)
    end
    local wish,pos=Suffix(before,{'i hope all','we hope all','i hope','we hope','i hope every member of','we hope every member of'})
    if wish then
        local rest=tail;local _,count=Prefix(rest,{'members','players','people'})
        if count then rest=Trim(rest:sub(count+1)) end
        if Prefix(rest,{'die','dies','will die'}) then return Result('deathWish','explicit death wish directed at a covered subject',context.first+pos-1,context.last) end
    end
    local hostile,pos=Suffix(before,{'i fucking hate','we fucking hate','fucking hate','fuck'})
    -- Recognize this common censored form only at an attached clause edge.
    local censor=before:match('()%f[%a]f%*%*%*%s*$')
    if hostile or censor then
        local ownObject=not noun and tail~='' and not tail:match('^%p+$') and not Prefix(tail,{'lol','lmao'})
        if not ownObject then return Result('severe','explicit severe directed abuse',context.first+(pos or censor)-1,hit.first-1) end
    end
    local hate,pos=Suffix(before,{'i hate','we hate','hate','screw'})
    if hate and (tail=='' or tail:match('^%p+$') or noun) then
        return Result('minor','direct general hostility toward a covered subject',context.first+pos-1,hit.first-1)
    end
    local linked,used=Prefix(tail,{'looks like','seems like','acts like','sounds like','is','are'})
    local pred,predAt=tail,at
    if linked then
        pred,predAt=Consume(tail,at,used)
        if Prefix(pred,{'not','never','no',"isn't","aren't"}) and not Prefix(pred,{'not only'}) then
            return Result(nil,'negated predicate; no endorsed attack')
        end
        -- Retain intensification as severity evidence before stripping fillers.
        local ex,exn=Prefix(pred,extreme,work)
        if ex then return Result('severe','severe abusive predicate: '..ex,predAt,predAt+exn-1) end
        for _=1,7 do
            local ex,exn=Prefix(pred,extreme,work)
            if ex then return Result('severe','severe abusive predicate: '..ex,predAt,predAt+exn-1) end
            local _,count=Prefix(pred,fillers);if not count then break end
            pred,predAt=Consume(pred,predAt,count)
        end
    end
    local neg=Prefix(pred,{'not','never','no'})
    if neg then return Result(nil,'negated predicate; no endorsed attack') end
    local term,count=Prefix(pred,extreme,work)
    if term and linked then return Result('severe','severe abusive predicate: '..term,predAt,predAt+count-1) end
    -- A direct covered-subject allegation is a strong expression. A bare
    -- topic mention, quoted report, or a different noun such as "terrorist
    -- hunter" does not establish this assertion.
    term,count=Prefix(pred,{'terrorists','terrorist'},work)
    if term and (linked=='is' or linked=='are') and (Trim(pred:sub(count+1))=='' or Trim(pred:sub(count+1)):match('^%p+$')) then
        return Result('attack','direct covered terrorist allegation',predAt,predAt+count-1)
    end
    if meta.pack=='creator' and linked then
        local tease=Prefix(pred,{'bald','balding','baldheaded','bald-headed','has no hair'})
        if tease then return Result(nil,'familiar appearance joke; no policy action') end
    end
    term,count=Prefix(pred,roasts,work)
    if term and (linked or pred:sub(count+1):match('^%s*%p*$')) then
        return Result(group and 'groupInsult' or meta.pack=='creator' and 'roast' or 'minor',
            group and 'direct insult toward covered guild members' or 'mild directed roast: '..term,predAt,predAt+count-1)
    end
    term,count=Prefix(pred,minor,work)
    if term and (linked or term=='sucks' or term=='suck' or pred:sub(count+1):match('^%s*%p*$')) then
        return Result(group and 'groupInsult' or 'minor','direct general criticism: '..term,predAt,predAt+count-1)
    end
    term,count=Prefix(pred,ns.SubjectPatterns.Criticism,work)
    if term and (linked or pred:sub(count+1):match('^%s*%p*$')) then
        return Result('minor','mild directed criticism: '..term,predAt,predAt+count-1)
    end
    term,count=Prefix(pred,ns.SubjectPatterns.Strong,work)
    if term and linked then return Result('attack','direct covered abusive expression: '..term,predAt,predAt+count-1) end
    -- Existing stock nickname vocabulary is retained; only its explicit stock
    -- classification is read here. No optional phrase is substituted or added.
    if meta.kind=='nickname' and before=='' and (tail=='' or tail:match('^%p+$') or Prefix(tail,{'lol','lmao'})) then
        return meta.protectionKind=='banter' and Result(nil,'familiar stock nickname; no policy action')
            or Result(meta.protectionKind or 'roast','curated stock nickname class',hit.first,hit.last)
    end
    return Result(nil,'reference without a recognized attack on that subject')
end
local function OtherTarget(state,hit,meta,first,last)
    for pack,list in pairs(state.byPack) do if pack~=meta.pack then
        local low,high=1,#list
        while low<=high do
            local mid=math.floor((low+high)/2)
            if list[mid].first<first then low=mid+1 else high=mid-1 end
        end
        if list[low] and list[low].first<=last and list[low].last<=last then return true end
    end end
    return false
end
-- Target-independent bounded grammar for the signed preference contract.
P.Grammar={Trim=Trim,Any=Any,Prefix=Prefix,Suffix=Suffix}
P.Guard=Guard
function P.Evaluate(state,hit,meta,work)
    local context=P.Scope(state,hit)
    local blocked=Guard(state,hit,context)
    if blocked then return Result(nil,blocked) end
    if meta.pack=='guild' and (Suffix(context.before,{'mount','mountain'}) or Prefix(context.after,{'is a greek mountain','is the greek mountain'})) then
        return Result(nil,'geographical reference; guild target not established')
    end
    local result=Classify(state,hit,meta,context,work)
    if context.quote then return result end
    -- One bounded follow-up with an unambiguous, syntactically attached
    -- antecedent. Never infer a target across messages or arbitrary prose.
    local followLimit=math.min(context.regionLast,context.last+160)
    local rawFollow=state.plain:sub(context.last+1,followLimit)
    local followFirst=context.last+1+#rawFollow:match('^%s*')
    local follow=Trim(rawFollow)
    if not OtherTarget(state,hit,meta,context.first,followLimit) then
        local pronoun=meta.pack=='creator' and 'him' or 'them'
        local threat,count=Prefix(follow,{'but i want to hurt '..pronoun..' in real life','but i will hurt '..pronoun..' in real life',
            'and i want to hurt '..pronoun..' in real life'})
        local antecedent=Prefix(context.after,{'is','are',"isn't","aren't"})
        local content=context.after:gsub("^isn't%s+",''):gsub("^aren't%s+",''):gsub('^is%s+',''):gsub('^are%s+','')
        content=content:gsub('^not%s+',''):gsub('^an?%s+','')
        local predicate,n=Prefix(content,{'bald','balding','idiot','clown','trash','great','good','online','idiots','useless'})
        antecedent=antecedent and predicate and (Trim(content:sub(n+1))=='' or Trim(content:sub(n+1))=='lol')
        if threat and antecedent and not Any(context.after,{'with','near','beside','behind','and','who'}) then
            result=Result('threat','explicit real-world harm with a bounded covered-subject antecedent',followFirst,followFirst+count-1)
        end
    end
    if result.kind=='minor' and meta.pack=='guild' then
        local affectionate=Prefix(follow,{'but i still love those guys','but i love those guys','but i still love them','but i love them',
            'but we love them',', but i still love those guys',', but i love those guys'})
        local again=follow:match('^;%s*i%s+love%s+()') or follow:match('^but%s+i%s+love%s+()')
            or follow:match('^but%s+i%s+still%s+love%s+()')
        if again then
            local at=followFirst+again-1
            for _,target in ipairs(state.targets) do
                if target.pack=='guild' and target.first==at then
                    local rest=Trim(state.plain:sub(target.last+1,followLimit))
                    if rest=='' or rest:match('^%p+$') then affectionate=true end
                end
            end
        end
        if affectionate then result.affectionate=true;result.contextCue=result.contextCue..'; narrowly attached affectionate banter' end
    end
    if result.first then
        while result.first<result.last and state.plain:sub(result.first,result.first):match('%s') do result.first=result.first+1 end
        while result.last>result.first and state.plain:sub(result.last,result.last):match('%s') do result.last=result.last-1 end
    end
    return result
end
