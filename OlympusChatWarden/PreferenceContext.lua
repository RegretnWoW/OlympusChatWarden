-- Grammar only. Concepts, usage modes and declaration eligibility come from
-- the verified schema-5 author policy, never an ID-based vocabulary override.
local _,ns=...
local P=ns.ProtectionContext;local G=P.Grammar
local Trim,Any,Prefix,Suffix=G.Trim,G.Any,G.Prefix,G.Suffix
local F={VERSION=6};ns.PreferenceContext=F
local function Result(eligible,stance,strength,cue,preference)
    return {eligible=eligible,stance=stance,strength=strength,certainty=eligible and 'high' or 'low',
        contextCue=cue,preferenceKind=preference,detectorType='topicPreference',stanceSource='inferred',contextPolicyVersion=4,
        kind=strength=='strong' and 'supportStrong' or strength=='mild' and 'supportMild' or 'reference',
        confidenceScore=eligible and (strength=='strong' and 90 or 55) or 0,shieldEligible=false}
end
function F.Action(decision,preset)
    if not decision.eligible then return 'Unchanged' end
    if decision.strength=='strong' then return preset=='strict' and 'Warning' or preset=='balanced' and 'Redacted' or 'Hidden' end
    return preset=='strict' and 'Unchanged' or preset=='balanced' and 'Warning' or 'Redacted'
end
local questions={'why','how','what','when','where','who','which','is','are','do','does','did','can','could','should','would','will','has','have','if'}
local reports={'said','says','say','saying','told','wrote','writes','claims','claimed','reported','quoted','quoting','hear','heard','read','reads',
    'definition of','meaning of','the definition','discusses','discussing','discussion of','explain','explaining','talking about'}
local opposition={"don't support",'do not support','not support','i oppose','we oppose','i reject','we reject','i hate','we hate',
    'stop using','stop promoting','stop supporting','stop adopting','stop requiring','stop implementing','against','making fun of','mocking','i dislike','we dislike'}
local negative={'bad','useless','stupid','nonsense','absurd','wrong','harmful','ridiculous','cringe','garbage','trash','terrible','awful','unnecessary','ineffective'}
local positive={'good','great','useful','helpful','important','beneficial','valuable','necessary','fair','effective','positive','sensible','worthwhile','essential','wonderful','excellent','amazing','awesome','the best'}
local weak={'i support','we support','i endorse','we endorse','i like','we like','i love','we love','i favor','we favor','i favour','we favour','i approve of','we approve of',
    'i agree with','we agree with','i believe in','we believe in','in favor of','in favour of','i strongly support','we strongly support','i fully support','we fully support'}
local strong={}
for _,subject in ipairs({'we should','we should all','we must','we need to','everyone should','everyone must','people should','people must','you should','you must',"let's",'let us',
    'i encourage everyone to','we encourage everyone to','i encourage you to','we encourage you to'}) do
    for _,verb in ipairs({'adopt','implement','promote','require','expand','use','share','vote','vote for','be required to share','be required to use'}) do
        strong[#strong+1]=subject..' '..verb
    end
end
local imperative={'adopt','implement','promote','require','expand','use','share','vote','vote for','please vote','please vote for','please adopt','please use','please support','support'}
local ownPractice={'i use','we use','our guild uses','our team uses','our group uses','i am using',"i'm using",'we are using',"we're using"}
local preferences={}
for _,subject in ipairs({'i','we','our guild','our team','our group'}) do
    local verb=(subject=='i' or subject=='we') and 'prefer' or 'prefers'
    for _,form in ipairs({'',' using',' to use'}) do preferences[#preferences+1]=subject..' '..verb..form end
end
local practicePredicates={'our standard','my standard','our usual wording','my usual wording',
    'our preferred wording','my preferred wording','our default wording','my default wording',
    'our terminology','my terminology','how we speak here','how i speak here',
    'way we speak here','way i speak here'}
local function OwnPracticePredicate(predicate,verb)
    if not predicate or (verb~='is' and verb~='are') then return false end
    local phrase,n=Prefix(predicate,practicePredicates)
    if not phrase then return false end
    local rest=Trim(predicate:sub(n+1))
    if phrase=='our standard' or phrase=='my standard' then
        local _,used=Prefix(rest,{'wording','terminology','practice'})
        if used then rest=Trim(rest:sub(used+1)) end
    end
    local _,used=Prefix(rest,{'in our announcements','in our guild','in our team','in our group','in guild chat','here'})
    if used then rest=Trim(rest:sub(used+1)) end
    -- Require a complete declared practice, not a noun such as "our standard
    -- example of bad wording", or a guessed third-party implementation report.
    return rest=='' or rest:match('^%p+$')~=nil
end
local rejectionVerbs={'hate','dislike','reject','oppose','disagree with',"don't like",'do not like'}
local rejectionEndings={'for that reason','for this reason','at all','in practice','personally','now'}
local function RejectsOwnPractice(state,hit,context,termQuote)
    -- Inspect one immediately attached contrast, within the same readable
    -- region. This is not a message-wide exemption and cannot cancel another
    -- pack, promotion, declaration or a literal Gommage cover.
    if termQuote then context=P.Scope(state,{first=context.quote.first,last=context.quote.last}) end
    local follow=state.plain:sub(context.last+1,math.min(context.regionLast,context.last+160))
    follow=Trim(follow:match('^[^\r\n]*'))
    -- A semicolon is normally an assertion boundary. Only an immediately
    -- attached "however" can introduce this narrow same-practice contrast.
    if follow:match('^;[ \t]*however[%s,]') then follow=Trim(follow:sub(2)) end
    follow=follow:gsub('^,%s*',''):gsub('’',"'")
    local contrast,n=Prefix(follow,{'but','however','yet'})
    if not contrast then return false end
    follow=Trim(follow:sub(n+1)):gsub('^,%s*','')
    local objects={'it','that wording','this wording','that terminology','this terminology',state.plain:sub(hit.first,hit.last)}
    local subject,used=Prefix(follow,{'i','we'});if not subject then return false end
    follow=Trim(follow:sub(used+1))
    local verb;verb,used=Prefix(follow,rejectionVerbs);if not verb then return false end
    follow=Trim(follow:sub(used+1))
    local object;object,used=Prefix(follow,objects);if not object then return false end
    local rest=Trim(follow:sub(used+1))
    -- A comma can introduce the same short adverbial ending. Consume it only
    -- when a recognized ending follows; do not erase an arbitrary next clause.
    if rest:sub(1,1)==',' then
        local aside=Trim(rest:sub(2));local _,ending=Prefix(aside,rejectionEndings)
        if ending then rest=aside end
    end
    local _,ending=Prefix(rest,rejectionEndings)
    if ending then rest=Trim(rest:sub(ending+1)) end
    return rest=='' or rest:match('^[%.!;]')~=nil or Prefix(rest,{'and','because','since'})~=nil
end
local affiliation={"i'm a","i'm an","i'm",'i am a','i am an','i am','i identify as a','i identify as',
    "i'm voting","i'm voting for",'i am voting','i am voting for','i vote','i vote for','i voted','i voted for','i will vote','i will vote for'}
local function Lead(before)
    return Trim(before:gsub('%s+the$',''):gsub('%s+our$',''):gsub('%s+this$',''):gsub('%s+these$',''))
end
local function Predicate(after)
    local verb,n=Prefix(after,{'is','are','seems','seem','sounds','sound','can be','should be','must be','needs to be'})
    if not verb then return nil end
    local rest=Trim(after:sub(n+1))
    for _=1,4 do local _,used=Prefix(rest,{'really','very','so','quite','actually','absolutely','a','an','the'})
        if not used then break end;rest=Trim(rest:sub(used+1)) end
    return rest,verb
end
local function PronounValues(after)
    local verb,n=Prefix(after,{'are','is'})
    if not verb then
        n=after:match('^%s*:()');if not n then return end;n=n-1
    end
    local rest=Trim(after:sub(n+1));local values=rest:match('^([a-z]+/[a-z/]+)')
    if not values or #values>60 or values:match('/$') then return end
    local count=0;for part in values:gmatch('[^/]+') do if #part>20 then return end;count=count+1 end
    if count<2 or count>3 then return end
    local remaining=Trim(rest:sub(#values+1))
    if remaining~='' and not remaining:match('^%p+$') then return end
    return values
end
local function Evaluate(state,hit,meta,work,context)
    local q=context.quote
    local before,after=context.before,context.after
    -- A quoted term can be the object of an asserted opinion about wording;
    -- a quoted assertion remains reported speech unless explicitly endorsed.
    local termQuote=q and not q.unclosed and Trim(state.plain:sub(q.innerFirst,q.innerLast))==state.plain:sub(hit.first,hit.last)
    if termQuote then
        before=Trim(state.plain:sub(math.max(context.regionFirst,q.first-160),q.first-1))
        after=Trim(state.plain:sub(q.last+1,math.min(context.regionLast,q.last+160)))
        before,after=ns.ContextDecision.Scope(before,after)
        if after:match('^[^%.!;]*%?') then return Result(false,'neutral','none','question about the quoted terminology') end
    else
        local blocked=P.Guard(state,hit,context)
        if blocked then return Result(false,'neutral','none',blocked) end
    end
    before=before:gsub('’',"'");after=after:gsub('’',"'")
    if Any(after,{'ironically','as a joke','to mock','mockingly','sarcastically'}) then
        return Result(false,'neutral','none','explicit joking or mocking usage; no affirmative preference established')
    end
    local requiredUsage=(before:match('^require%s+[%a ]-to%s+say$') or before:match('^require%s+[%a ]-to%s+use$'))
        and not Any(before,{'not','never'})
    if Prefix(before,questions) or Any(before,reports) and not requiredUsage or Any(before,{'maybe','perhaps','allegedly','apparently','whether','not sure','unsure'}) then
        return Result(false,'neutral','none','question, reporting or uncertain attribution')
    end
    if Suffix(before,opposition) then return Result(false,'opposition','none','rejection or criticism of the selected concept') end
    local predicate,verb=Predicate(after)
    if predicate and Prefix(predicate,{'not','never','no'}) or Prefix(after,{"isn't","aren't"}) then
        return Result(false,'opposition','none','negated opinion; no affirmative preference match')
    end
    if predicate and Prefix(predicate,negative,work) or Prefix(after,{'sucks','suck'}) then
        return Result(false,'opposition','none','criticism of the selected concept')
    end
    local policy=meta.contractPolicy
    if meta.role=='declaration' then
        if q then return Result(false,'neutral','none','quoted pronoun declaration; own speaker attribution is not established') end
        if policy.declaration=='pronouns' and (before=='my' or before=='' and after:match('^:')) then
            local values=PronounValues(after)
            if values then
                local decision=Result(true,'usage','mild','explicit pronoun declaration; selected viewing preference, not an inferred political belief','pronoun_declaration')
                local start=state.plain:find(values,hit.last+1,true)
                decision.first=hit.first;decision.last=start+#values-1
                return decision
            end
        end
        return Result(false,'neutral','none','pronoun words without an explicit first-person/profile declaration')
    end
    local lead=Lead(before)
    local promotion=Suffix(lead,strong)
    if not promotion then
        for _,command in ipairs(imperative) do if lead==command then promotion=command;break end end
        if requiredUsage then promotion='require terminology adoption' end
    end
    local passive=predicate and Prefix(predicate,{'adopted','implemented','required','promoted','mandatory','expanded'})
    if promotion or passive and (verb=='should be' or verb=='must be' or verb=='needs to be') then
        return Result(true,'support','strong','clear call for adoption, requirements or persuasion','promotion')
    end
    if policy.declaration=='affiliation' and not q and Suffix(lead,affiliation) then
        return Result(true,'declaration','mild','explicit first-person affiliation/voting; viewing preference, not a persuasion or misconduct claim','declared_affiliation')
    end
    if policy.mode=='usage' and (not q or termQuote)
        and (Suffix(lead,ownPractice) or OwnPracticePredicate(predicate,verb)) then
        if RejectsOwnPractice(state,hit,context,termQuote) then
            return Result(false,'opposition','none','immediately attached rejection of the same terminology; affirmative own practice not established')
        end
        return Result(true,'usage','mild','deliberate affirmative own terminology practice; no belief inferred','selected_terminology_usage')
    end
    if Suffix(lead,preferences) then
        if RejectsOwnPractice(state,hit,context,termQuote) then
            return Result(false,'opposition','none','immediately attached rejection of the same first-person preference')
        end
        if Prefix(after,{'not','never','to be avoided','to be removed','to be banned','be avoided','be removed','be banned',
            'were not','was not','had not',"wasn't","weren't"}) then
            return Result(false,'opposition','none','preference rejects use of the selected concept')
        end
        return Result(true,'support','mild','explicit favorable first-person preference for the selected concept','support')
    end
    if Suffix(lead,weak) or predicate and Prefix(predicate,positive,work)
        or Prefix(after,{'helps','works','matters','benefits','improves','has helped','has improved'}) then
        -- Support must concern the selected convention, not a person receiving
        -- unrelated care. Unqualified topic references do not pass this gate.
        return Result(true,'support','mild','clear favorable statement about the selected concept','support')
    end
    return Result(false,'neutral','none','selected concept without a qualifying assertion or usage')
end
local function BareObjectLead(text)
    return text=='' or text=='the' or text=='our' or text=='this' or text=='these'
end
local qualifierEndings={'for everyone','for real','at school','at work','at home','in school','in schools',
    'in our guild','in our team','in our group','in guild chat','here','today','now','everywhere','wholeheartedly'}
local function QualifyingTail(text)
    -- A small grammar of complete modifiers, not an arbitrary suffix exemption.
    -- New predicates, conditions, attribution and unsupported wording fail it.
    if #text>80 then return false end
    for _=1,2 do
        if text=='' or text:match('^%p+$') then return true end
        local _,used=Prefix(text,qualifierEndings);if not used then return false end
        text=Trim(text:sub(used+1))
    end
    return text=='' or text:match('^%p+$')~=nil
end
local function JoinedLead(state,hit,context)
    -- Share a predicate only across bare, authored objects joined by "and".
    -- New predicates, unknown intervening wording, comma/or lists, sentences,
    -- quote boundaries and native markup do not acquire inherited stance.
    if not BareObjectLead(context.before) or not QualifyingTail(context.after) then return end
    local current=hit;local concepts=state.concepts
    for count=1,4 do
        local low,high,at=1,#concepts,nil
        while low<=high do
            local mid=math.floor((low+high)/2)
            if concepts[mid].last<current.first then at=mid;low=mid+1 else high=mid-1 end
        end
        local previous=at and concepts[at]
        if not previous or previous.first<math.max(context.sentenceFirst,context.regionFirst,hit.first-240) then return end
        local join=Trim(state.plain:sub(previous.last+1,current.first-1))
        if join~='and' and join~='and the' and join~='and our' and join~='and this' and join~='and these' then return end
        local source=P.Scope(state,previous)
        if source.quote~=context.quote then return end
        if not BareObjectLead(source.before) then return source.before end
        current=previous
    end
end
function F.Evaluate(state,hit,meta,work)
    local context=P.Scope(state,hit)
    local lead=JoinedLead(state,hit,context)
    if lead then context.before=lead end
    local decision=Evaluate(state,hit,meta,work,context)
    if lead and decision.eligible then
        decision.contextCue=decision.contextCue..'; shared statement applies to this joined topic'
    end
    return decision
end
