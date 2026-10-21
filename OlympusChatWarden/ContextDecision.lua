-- Shared bounded grammar. Optional topic vocabulary remains in signed packs.
local _,ns=...
local D={VERSION=2};ns.ContextDecision=D
function D.CopyEvidence(source,target)
    for _,key in ipairs({'stance','strength','certainty','contextCue','detectorType','stanceSource','target','preferenceKind'}) do
        local value=source[key]
        if ns.CanRead(value) then target[key]=value:sub(1,512) end
    end
    if source.contextPolicyVersion==1 or source.contextPolicyVersion==2 or source.contextPolicyVersion==3 or source.contextPolicyVersion==4 then target.contextPolicyVersion=source.contextPolicyVersion end
    for _,key in ipairs({'targetFirst','targetLast'}) do
        local value=source[key]
        if type(value)=='number' and value>=1 and value<=ns.Engine.MAX_TEXT and value==math.floor(value) then target[key]=value end
    end
    return target
end
local function Trim(text) return text:match('^%s*(.-)%s*$') end
local function Any(text,phrases)
    for _,phrase in ipairs(phrases) do
        local at=1
        while true do
            local a,b=text:find(phrase,at,true);if not a then break end
            if not text:sub(a-1,a-1):match('[%w_]') and not text:sub(b+1,b+1):match('[%w_]') then return phrase end
            at=a+1
        end
    end
end
local function Suffix(text,phrases)
    for _,phrase in ipairs(phrases) do
        local preceding=text:sub(-#phrase-1,-#phrase-1)
        if text:sub(-#phrase)==phrase and not preceding:match('[%w_]') then return phrase end
        local last=text:sub(-1)
        if (not last:match('[a-z]') or last==phrase:sub(-1)) and ns.Engine.EvasionSuffix(text,phrase) then return phrase end
    end
end
local function Prefix(text,phrases,work)
    for _,phrase in ipairs(phrases) do
        local consumed=text:sub(1,#phrase)==phrase and not text:sub(#phrase+1,#phrase+1):match('[%w_]') and #phrase
            or ns.Engine.EvasionPrefix(text,phrase)
            or work and ns.TypoFilter and ns.TypoFilter.ContextPrefix(text,phrase,work)
        if consumed then return phrase,consumed end
    end
end
function D.Scope(before,after)
    before=before:sub(-100):gsub('’',"'");after=after:sub(1,100):gsub('’',"'")
    -- Do not borrow stance from another coordinated/contrasting assertion.
    local cut=0
    for _,separator in ipairs({' but ',' however ',' however, ',' and ',' whereas ',' yet ',','}) do
        local at=1
        while true do local a,b=before:find(separator,at,true);if not a then break end;cut=math.max(cut,b);at=b+1 end
        local first=after:find(separator,1,true)
        if first then
            local remainder=Trim(after:sub(first+#separator))
            local conditional=before:match('^%s*if%s*$') or before:match('^%s*if%s+')
            local question=Prefix(remainder,{'why','how','what','where','when','who'})
            -- Keep the question attached to its conditional premise when a
            -- writer inserts the usual comma: 'If USA is bad, why does ...?'.
            if not (separator==',' and conditional and question) then after=after:sub(1,first-1) end
        end
    end
    if cut>0 then before=before:sub(cut+1) end
    return Trim(before),Trim(after)
end
local function Result(stance,strength,certainty,cue,eligible,detector)
    return {stance=stance,strength=strength,certainty=certainty,contextCue=cue,
        eligible=eligible==true,detectorType=detector or 'topicPreference',contextPolicyVersion=2,
        stanceSource='inferred'}
end
local function Block(before,after,quoted)
    local lead=before:gsub('^[%s,:%-]+','')
    -- A conditional premise followed by a question is not an assertion of
    -- that premise: 'If USA is so bad why does ...?'. Require grammar on
    -- both sides; punctuation alone does not establish speaker stance.
    if lead=='if' or lead:match('^if%s+') then
        for _,word in ipairs({'why','how','what','where','when','who'}) do
            local a,b=after:find('%f[%a]'..word..'%s+')
            if a and not after:sub(1,a-1):find('[%.!;]')
                and Prefix(after:sub(b+1),{'is','are','do','does','did','can','could','should','would','will','has','have'}) then
                return 'question','conditional premise within a question'
            end
        end
    end
    if lead:match('^(why)%f[%W]') or lead:match('^(how)%f[%W]') or lead:match('^(what)%f[%W]')
        or lead:match('^(when)%f[%W]') or lead:match('^(where)%f[%W]') or lead:match('^(which)%f[%W]')
        or lead:match('^(who)%f[%W]') then return 'question','question about the referenced topic' end
    if Prefix(lead,{'is','are','do','does','did','can','could','should','would','will','has','have'}) then
        return 'question','interrogative clause about the referenced topic'
    end
    local defense=Any(lead,{"don't say","do not say","stop saying","don't call","do not call","stop calling",
        'wrong to say','wrong to call','never said','never called','not saying','nobody should say','no one should say','nobody should call','no one should call',
        'disagree with','oppose the idea','reject the statement'})
    if defense then return 'opposition','discouraging or denying the expression: '..defense end
    if quoted then return 'quoted','quoted wording; speaker stance is not established' end
    local report=Any(lead,{'say','said','says','saying','write','wrote','writes','claim','claims','claimed','quoted','quoting','reported',
        'heard that','the article','the book','the report','the study','the phrase','the term','definition of',
        'meaning of','discusses','discussing','discussion of','debate about','talking about','explain'})
    if report then return 'neutral','discussion or reported wording: '..report end
end
local opposition={"i oppose","we oppose","i reject","we reject","i hate","we hate",'against',
    "don't support","do not support","not support","don't adopt","do not adopt",'stop using','stop promoting',
    'stop supporting','stop adopting','stop implementing','stop requiring','reject','oppose','mocking','making fun of'}
local negative={'bad','useless','stupid','nonsense','absurd','wrong','harmful','ridiculous','cringe','garbage','trash','terrible','awful','unnecessary','ineffective'}
local positive={'good','great','useful','helpful','important','beneficial','valuable','necessary','fair','effective','positive','sensible','worthwhile','essential','wonderful','excellent','amazing','awesome','the best'}
local weakLead={'i support','we support','i like','we like','i love','we love','i favor','we favor','i favour','we favour',
    'i approve of','we approve of','i agree with','we agree with','i believe in','we believe in','in favor of','in favour of'}
local strongLead={}
for _,subject in ipairs({'we should','we must','we need to','everyone should','everyone must','people should','people must','you should','you must','i want to','we want to',"let's",'let us'}) do
    for _,verb in ipairs({'adopt','implement','promote','require','embrace','normalize','normalise','expand','prioritize','prioritise','use','support'}) do
        strongLead[#strongLead+1]=subject..' '..verb
    end
end
for _,phrase in ipairs({'i strongly support','we strongly support','i fully support','we fully support',
    'i recommend','we recommend','i advocate','we advocate','i want more','we want more','we need more','we need','we demand',
    'please adopt','please implement','please promote','please support','please use'}) do strongLead[#strongLead+1]=phrase end
local function Lead(text)
    -- Optional determiners are grammatical, not a lookup of category terms.
    return Trim(text:gsub('%s+the$',''):gsub('%s+our$',''):gsub('%s+these$',''):gsub('%s+this$',''))
end
local function Predicate(after)
    local verb,used=Prefix(after,{'is','are','seems','seem','sounds','sound','can be','should be','must be','needs to be'})
    if not verb then return nil end
    local rest=Trim(after:sub(used+1))
    for _=1,4 do
        local filler,n=Prefix(rest,{'really','very','so','quite','actually','absolutely','a','an','the'})
        if not filler then break end;rest=Trim(rest:sub(n+1))
    end
    return rest,verb
end
function D.Topic(before,after,meta,quoted,work)
    before,after=D.Scope(before,after)
    local stance,cue=Block(before,after,quoted)
    if stance then return Result(stance,'none','high',cue,false) end
    local lead=Lead(before)
    local opposed=Suffix(lead,opposition)
    local predicate,verb=Predicate(after)
    if predicate and (Prefix(predicate,{"not","never","no"}) or verb=="isn't" or verb=="aren't") then
        return Result('opposition','none','high','negated positive/adoption statement',false)
    end
    local bad=predicate and Prefix(predicate,negative,work) or Prefix(after,{'sucks','suck'})
    if opposed or bad then return Result('opposition','none','high','criticism of selected concept: '..(opposed or bad),false) end
    local strong=Suffix(lead,strongLead)
    if not strong and Prefix(lead,{'adopt','implement','promote','embrace','require','normalize','normalise','support','use'})
        and not lead:find(' ',1,true) then strong=lead end
    local passive=predicate and Prefix(predicate,{'adopted','implemented','required','promoted','mandatory','expanded'})
    if strong or passive and (verb=='should be' or verb=='must be' or verb=='needs to be') then
        return Result('support','strong','high','advocacy/adoption: '..(strong or verb..' '..passive),true)
    end
    local weak=Suffix(lead,weakLead) or predicate and Prefix(predicate,positive,work)
        or Prefix(after,{'helps','works','matters','benefits','improves','has helped','has improved'})
    if weak then return Result('support','mild','high','positive opinion: '..weak,true) end
    if meta.role=='advocacy' or meta.role=='advocacyBroad' then
        -- The author explicitly signed this phrase as an assertive slogan.
        if before=='' and (after=='' or after:match('^%p+$')) then
            return Result('support','strong','high','author-signed assertive wording',true)
        end
    end
    return Result('neutral','none','low','topic reference without a supported speaker stance',false)
end
function D.Subject(before,after,score,kind,quoted)
    before,after=D.Scope(before,after)
    do
        local stance,cue=Block(before,after,quoted)
        if stance then return Result(stance,'none','high',cue,false,'subjectProtection') end
        local assertion=after:gsub('^%s*','')
        if assertion:match('^is%s+not%s+') or assertion:match('^are%s+not%s+')
            or assertion:match("^isn't%s+") or assertion:match("^aren't%s+") then
            if not assertion:match('^%a+%s+not%s+only%s+') then return Result('opposition','none','high','negated directed statement',false,'subjectProtection') end
        end
        if Suffix(before,{"don't hate","do not hate","doesn't hate","does not hate","never hated","not hating"}) then
            return Result('opposition','none','high','negated hostility',false,'subjectProtection')
        end
    end
    if score<=0 then return Result('neutral','none','low','reference without a recognized directed attack',false,'subjectProtection') end
    return Result(kind=='threat' and 'threat' or 'criticism',kind=='threat' and 'threat' or kind=='criticism' and 'mild' or 'strong',
        'high','recognized directed expression',true,kind=='threat' and 'threat' or 'subjectProtection')
end
