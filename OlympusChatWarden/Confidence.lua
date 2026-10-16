-- Deterministic preference-match heuristics. Scores are NOT probabilities of intent.
local _, ns = ...
function ns.IsRedacted(match)
    return match.gommage == true or (match.score or 0) >= 65
end
function ns.MatchAction(matches)
    local score, redactions, replacements = 0, false, false
    for _, match in ipairs(matches) do
        score = math.max(score, match.score or 0)
        if (match.score or 0) >= 65 and match.replacement then replacements = true
        elseif ns.IsRedacted(match) then redactions = true end
    end
    if score >= 85 then return "Hidden", "High", score end
    if score >= 65 then return replacements and not redactions and "Replaced" or "Redacted", "Medium", score end
    if redactions then return "Redacted", score >= 40 and "Low" or "Display only", score end
    if score >= 40 then return "Warning", "Low", score end
    return "Unchanged", "Below minimum", score
end
local C = {Presets = {strict = 85, balanced = 65, aggressive = 40, maximum = 40},ActionPolicyVersion=4}
ns.Confidence = C
local actionScores={Unchanged=0,Warning=55,Redacted=80,Hidden=95}
function C.Policy(preset,kind,uncertain)
    if uncertain then return (preset=='aggressive' or preset=='maximum') and 'Warning' or 'Unchanged' end
    if kind=='threat' then return 'Hidden' end
    if kind=='criticism' or kind=='supportMild' then return preset=='strict' and 'Unchanged' or preset=='balanced' and 'Warning' or 'Hidden' end
    if kind=='topicBroad' then return (preset=='aggressive' or preset=='maximum') and 'Redacted' or 'Unchanged' end
    if kind=='topic' then return preset=='strict' and 'Unchanged' or 'Redacted' end
    return preset=='strict' and 'Warning' or preset=='balanced' and 'Redacted' or 'Hidden'
end
function C.GommageEnabled(settings,pack)
    if settings.gommage~=nil then return settings.gommage==true and not (settings.gommagePacks and settings.gommagePacks[pack]==false) end
    -- Read historical report settings and pre-toggle saved imports unchanged.
    return C.PackPreset(settings,pack)=='maximum'
end
ns.RULE_VERSION = ns.RULE_VERSION .. "-context-7-evasion-1-case-1-boundary-2-categories-1"
function C.PackPreset(settings, pack)
    local value = settings.packPresets and settings.packPresets[pack]
    return C.Presets[value] and value or (C.Presets[settings.preset] and settings.preset or "aggressive")
end
local gommageKey, gommageMatcher
local function GommageMatcher(settings)
    if not ns.Gommage then return end
    local enabled, keys = {}, {}
    for _, pack in ipairs(ns.PackNames) do
        if C.GommageEnabled(settings,pack) and not (settings.disabledPacks and settings.disabledPacks[pack]) then
            enabled[pack] = true; keys[#keys + 1] = pack
        end
    end
    local key = tostring(ns.RulePacks and ns.RulePacks.Revision or 0) .. ":" .. table.concat(keys, ":")
    if key ~= gommageKey then
        local rules = {}
        for _, phrase in ipairs(ns.Gommage.Rules) do
            if enabled[ns.Gommage.Meta[phrase].pack] then rules[#rules + 1] = phrase end
        end
        gommageMatcher = #rules > 0 and assert(ns.Engine.CompileLiteral(rules)) or nil
        gommageKey = key
    end
    return gommageMatcher
end
function C.PrepareTypos(settings,prepare)
    prepare(ns.Matcher)
    if ns.Personal and ns.Personal.matcher then prepare(ns.Personal.matcher) end
    local masks=GommageMatcher(settings)
    if masks then prepare(masks) end
    if settings.barber~=false then
        if ns.BodyReplacements then prepare(ns.BodyReplacements) end
        if ns.BuiltinBodyReplacements then prepare(ns.BuiltinBodyReplacements) end
    end
end
local function Word(byte)
    return byte and ((byte >= 48 and byte <= 57) or (byte >= 97 and byte <= 122) or byte == 95 or byte >= 128)
end
local function Has(text, phrase)
    local position = 1
    while true do
        local first, last = text:find(phrase, position, true)
        if not first then return false end
        if not Word(text:byte(first - 1)) and not Word(text:byte(last + 1)) then return true end
        position = first + 1
    end
end
local function Any(text, phrases)
    for _, phrase in ipairs(phrases) do if Has(text, phrase) then return phrase end end
end
local criticism = {"stop using", "do not use", "don't use", "reject", "rejects", "rejected", "oppose", "opposes", "opposed", "against", "disagree with", "not support", "don't support", "do not support", "avoid saying", "avoid the phrase", "criticize", "criticise", "criticizes", "criticises"}
local discussion = {"the phrase", "the term", "a phrase", "a term", "definition of", "defined as", "means", "what does", "what is meant by"}
local positive = {"promote", "promotes", "support", "supports", "embrace", "embraces", "implement", "adopt", "encourage", "encourages"}
local context = {"diversity", "equity", "inclusion", "pronouns", "gender", "anti-racism", "antiracism", "dei"}
local function PreferenceContext(before,after)
    -- A selected wording preference is not an abuse judgment. Bound polarity
    -- to the current clause; Gommage masks are evaluated separately afterward.
    local stop=after:find(' but ',1,true) or after:find(' however',1,true)
    if stop then after=after:sub(1,stop-1) end
    local lead=before:sub(-80):gsub("don't oppose",'support'):gsub('do not oppose','support')
    local opposed=Any(lead,criticism) or Any(lead,{"don't support","do not support","stop saying","stop calling","making fun of","mocking","mock","lol","lmao"})
        or Any(after:sub(1,80),{'is bad','are bad','is nonsense','is absurd','is wrong','are wrong','is harmful','are harmful','is stupid','are stupid','is ridiculous','are ridiculous','is cringe','are cringe','sucks','suck'})
    if opposed then return false,'selected wording criticized or mocked: '..opposed end
    local supported=Any(lead,positive) or Any(lead,{'i like','we like','i love','we love','in favor of','in favour of','agree with'})
        or Any(after:sub(1,80),{'is good','are good','is great','are great','is wonderful','are wonderful','is important','are important','is the best','are the best'})
    return true,supported and 'configured supportive wording preference: '..supported or 'configured terminology preference',supported~=nil
end
local function SentenceStop(lower,i)
    local c=lower:sub(i,i)
    if c:match("[%.!%?]") and lower:sub(i-1,i-1):match("[%w]") and lower:sub(i+1,i+1):match("[%w]") then return false end
    return c:match("[%.!%?;\n]") ~= nil
end
local function ContextGroups(lower)
    local groups,offset,group={},0,nil
    for _,piece in ipairs(ns.Engine.Segments(lower)) do
        if piece.editable or piece.text:match('^|c%x%x%x%x%x%x%x%x$') or piece.text=='|r' then
            if not group then group={offset+1,offset};groups[#groups+1]=group end
            group[2]=offset+#piece.text
        else group=nil end
        offset=offset+#piece.text
    end
    return groups
end
local function Window(lower, hit, groups)
    local first = math.max(hit.segmentFirst or 1, hit.first - 100)
    local last = math.min(hit.segmentLast or #lower, hit.last + 100)
    if groups then
        local low,high=1,#groups
        while low<=high do
            local mid=math.floor((low+high)/2);local group=groups[mid]
            if hit.first<group[1] then high=mid-1 elseif hit.first>group[2] then low=mid+1
            else first=math.max(group[1],hit.first-100);last=math.min(group[2],hit.last+100);break end
        end
    end
    for i = hit.first - 1, first, -1 do
        if SentenceStop(lower,i) then first = i + 1; break end
    end
    for i = hit.last + 1, last do
        if SentenceStop(lower,i) then last = i - 1; break end
    end
    return first, last
end
local function AdjacentCreatorInsult(before, after)
    if Any(before:sub(-60), {"said", "says", "wrote", "quoted", "quoting", "quote", "don't say", "do not say", "stop saying"}) then return false end
    local tail = after:gsub("^[%s,:%-]+", "")
    local rest = tail:match("^that%s+guy%s+(.+)") or tail:match("^this%s+guy%s+(.+)")
    if not rest then return false end
    for _ = 1, 3 do
        local first, remainder = rest:match("^([a-z]+)%s+(.+)")
        if first == "really" or first == "just" or first == "fucking" or first == "absolutely" then rest = remainder else break end
    end
    if not rest:match("^sucks%f[%W]") then return false end
    return not rest:match("^sucks%s+up%f[%W]") and not rest:match("^sucks%s+in%f[%W]")
        and not rest:match("^sucks%s+out%f[%W]")
end
local function BodyLabelCase(replacement, original)
    if original == original:upper() then return replacement:upper() end
    local first = original:match("[a-zA-Z]")
    if first and first == first:upper() then return replacement:sub(1, 1):upper() .. replacement:sub(2) end
    return replacement
end
local function Quoted(before, after)
    for _, quote in ipairs({'"', "'"}) do
        local count = 0
        for i = 1, #before do
            if before:sub(i, i) == quote and not (quote == "'" and Word(before:byte(i - 1)) and Word(before:byte(i + 1))) then count = count + 1 end
        end
        if count % 2 == 1 and after:find(quote, 1, true) then return true end
    end
    -- UTF-8 curly quotation marks are context cues; matching rules remain ASCII.
    return (before:find("“", 1, true) and after:find("”", 1, true))
        or (before:find("‘", 1, true) and after:find("’", 1, true))
end
function C.Analyze(matcher, text, settings, exceptionMatcher,incomingTypos,source)
    settings = settings or {}
    local threshold = C.Presets[settings.preset] or C.Presets.aggressive
    if type(text) ~= "string" or #text > ns.Engine.MAX_TEXT then return {}, {}, "unsupported" end
    local hits, errorMessage = matcher:FindFlexible(text, true)
    if errorMessage then return {}, {}, errorMessage end
    local typoWork=incomingTypos and settings.typoFiltering and ns.TypoFilter.Work(text,settings,source) or nil
    local function WithTypos(target,found)
        if typoWork then for _,hit in ipairs(ns.TypoFilter.Hits(target,text,found,typoWork)) do
            if #found<ns.Engine.MAX_CANDIDATES then found[#found+1]=hit end
        end end
        return found
    end
    hits=WithTypos(matcher,hits)
    local lower = ns.Engine.Lower(text)
    local contextGroups=ContextGroups(lower)
    local protection
    if ns.ProtectionContext then
        for _,hit in ipairs(hits) do
            local meta=ns.RuleMeta[matcher.rules[hit.rule]]
            if meta and (meta.pack=='guild' or meta.pack=='creator' or meta.contractPolicy)
                and not (settings.disabledPacks and settings.disabledPacks[meta.pack]) then
                protection=ns.ProtectionContext.Prepare(lower,hits,matcher,settings,text);break
            end
        end
    end
    local exceptions, exceptionError = {}, nil
    if exceptionMatcher then exceptions, exceptionError = exceptionMatcher:Find(text, true) end
    if exceptionError then return {}, {}, exceptionError end
    local report, accepted = {}, {}
    -- Build a per-position index so corroboration does not become O(hit-count squared).
    local starts = {}
    for _, hit in ipairs(hits) do
        local meta = ns.RuleMeta[matcher.rules[hit.rule]]
        if (not meta or (meta.pack ~= "guild" and meta.pack ~= "creator"))
            and (not meta or not settings.disabledPacks or not settings.disabledPacks[meta.pack]) then
            starts[hit.first] = math.max(starts[hit.first] or 0, hit.last)
        end
    end
    local exceptionStarts = {}
    for _, hit in ipairs(exceptions) do exceptionStarts[hit.first] = hit.last end
    for _, hit in ipairs(hits) do
        local phrase = matcher.rules[hit.rule]
        local meta = ns.RuleMeta[phrase] or {id = "custom:" .. phrase, pack = "custom", base = 95, origin = "custom user rule"}
        local packThreshold = C.Presets[C.PackPreset(settings, meta.pack)]
        local first, last = Window(lower, hit, contextGroups)
        local before, after = lower:sub(first, hit.first - 1), lower:sub(hit.last + 1, last)
        -- Formatting codes carry no grammatical meaning. Keep all matching
        -- offsets in the original text; never join words across item/player links.
        before=before:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')
        after=after:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')
        -- Contrast clauses separate prior criticism/support from the next assertion.
        local contrastEnd
        for _, contrast in ipairs({" but ", " however ", " however, "}) do
            local position = 1
            while true do
                local a, b = before:find(contrast, position, true)
                if not a then break end
                contrastEnd = math.max(contrastEnd or 0, b); position = b + 1
            end
        end
        if contrastEnd then before = before:sub(contrastEnd + 1) end
        local score, reasons = meta.base, {"base " .. meta.base .. " (" .. meta.pack .. ")"}
        if hit.evasion then reasons[#reasons+1] = "bounded spelling/spacing/symbol variation" end
        local directed = meta.pack == "guild" or meta.pack == "creator" or meta.policy and meta.purpose=='subject'
        local policy=meta.policy or meta.pack=='guild' or meta.pack=='creator'
        local topic=meta.policy and meta.purpose=='topic'
        local semantic=meta.contextual or meta.pack=='guild' or meta.pack=='creator'
        local kind,decision
        local modernTopic=meta.contractPolicy and topic
        local stockProtection=ns.ProtectionContext and (meta.pack=='guild' or meta.pack=='creator' or meta.protectionProfile)
        if stockProtection then
            decision=protection and not (settings.disabledPacks and settings.disabledPacks[meta.pack])
                and ns.ProtectionContext.Evaluate(protection,hit,meta,typoWork)
                or {eligible=false,confidenceScore=0,contextCue='pack disabled',contextPolicyVersion=3}
            score=decision.confidenceScore or 0;kind=decision.kind or 'reference'
            reasons={'stock protection: '..decision.contextCue}
        elseif modernTopic then
            decision=protection and not (settings.disabledPacks and settings.disabledPacks[meta.pack])
                and ns.PreferenceContext.Evaluate(protection,hit,meta,typoWork)
                or {eligible=false,confidenceScore=0,contextCue='pack disabled',contextPolicyVersion=4}
            score=decision.confidenceScore or 0;kind=decision.kind or 'reference'
            reasons={'signed viewing preference: '..decision.contextCue}
        elseif meta.pack == "guild" then
            local detail
            score, detail,kind = ns.GuildScore(before, after,typoWork)
            reasons = {"guild context " .. score .. ": " .. detail}
        elseif meta.pack == "creator" then
            local detail
            score, detail,kind = ns.CreatorScore(before, after, meta,typoWork)
            if score < 90 and AdjacentCreatorInsult(before, after) then
                score, detail = 90, "adjacent creator reference: that/this guy sucks"
            end
            reasons = {"creator context " .. score .. ": " .. detail}
        elseif meta.policy and meta.role=='reference' then
            local detail
            score,detail,kind=ns.SubjectPatterns.Score(before,after,meta.subjectModel,typoWork)
            reasons={'subject context '..score..': '..detail}
        end
        kind=kind or (topic and (meta.role=='viewpoint' and 'topic' or meta.role) or meta.role=='threat' and 'threat' or score>=95 and 'threat' or score>=85 and 'strong' or score>=65 and 'preference' or score>0 and 'criticism')
        if not stockProtection and not modernTopic and semantic and topic then
            decision=ns.ContextDecision.Topic(before,after,meta,Quoted(before,after),typoWork)
            local mode=C.PackPreset(settings,meta.pack)
            local wider=meta.role=='topicBroad' or meta.role=='advocacyBroad'
            if wider and mode~='aggressive' and mode~='maximum' then
                decision.eligible=false;decision.contextCue=decision.contextCue..'; wider coverage is off in this preset'
            end
            kind=decision.strength=='mild' and 'supportMild' or 'supportStrong'
            score=decision.eligible and (decision.strength=='mild' and 55 or 90) or 0
        elseif not stockProtection and semantic and directed then
            decision=ns.ContextDecision.Subject(before,after,score,kind,Quoted(before,after))
            if not decision.eligible then score=0 end
        end
        if decision and not stockProtection and not modernTopic then reasons[#reasons+1]=decision.contextCue end
        if topic and not semantic and (meta.stance=='avoid-support' or meta.role=='viewpoint') then
            local allowed,detail,supported=PreferenceContext(before,after)
            if not allowed or meta.role=='viewpoint' and not supported then score=0 end
            reasons[#reasons+1]=meta.role=='viewpoint' and not supported and 'no explicit supportive statement for this viewpoint reference' or detail
        end
        local rawScore=score
        local contextUncertain=false
        if hit.typo then reasons[#reasons+1]='spelling guess: '..text:sub(hit.first,hit.last)..' -> '..phrase..' ('..hit.typoEdits..' edits)' end
        local excluded = false
        for i = first, last do
            if exceptionStarts[i] and exceptionStarts[i] <= last then excluded = true; break end
        end
        local disabled = settings.disabledPacks and settings.disabledPacks[meta.pack]
        local negative = (Any(before:sub(-60), criticism)
            or Any(after:sub(1, 60), {"is not", "is nonsense", "is absurd", "should not be used", "is wrong", "is harmful"}))
        if directed and not semantic then
            negative = negative or Any(before:sub(-60), {"don't say", "do not say", "stop saying",
                "don't call", "do not call", "stop calling", "don't hate", "do not hate", "not saying"})
        end
        if directed and not semantic then
            local detail
            score,detail=ns.DirectedContext.Apply(before,after,score,Quoted(before,after))
            if detail then reasons[#reasons+1]=detail end
            contextUncertain=detail and (detail:find('capped',1,true)~=nil or detail:find('question',1,true)~=nil) or false
            -- Retain the old objection safeguards for less explicit defenses.
            -- "not only" asserts the wording and is not a negation exception.
            if negative and not after:match('^%s*is%s+not%s+only%s+') and not after:match('^%s*are%s+not%s+only%s+') then
                score=math.min(score,55);reasons[#reasons+1]='objection context; stock score capped at 55: '..negative
            end
        end
        if negative and not directed and not topic then score = score - 35; reasons[#reasons + 1] = "-35 criticism/negation: " .. negative end
        if not semantic then
            if not directed and not topic and Quoted(before, after) then score = score - 15; reasons[#reasons + 1] = "-15 quoted wording" end
            local mention = Any(before:sub(-60), discussion)
            if mention and not topic then
                score=policy and math.min(score,55) or score-20;contextUncertain=policy==true
                reasons[#reasons+1]='term discussion: '..mention
            end
            if not policy and not directed and meta.base < 85 and not negative then
                local cue = Any(before .. " " .. after, context)
                local support = Any(before:sub(-60), positive)
                if cue then score = score + 12; reasons[#reasons + 1] = "+12 nearby vocabulary: " .. cue end
                if support then score = score + 10; reasons[#reasons + 1] = "+10 support/adoption cue: " .. support end
                for i = first, last do
                    if starts[i] and ((i < hit.first and starts[i] < hit.first) or i > hit.last) then
                        score = score + 10; reasons[#reasons + 1] = "+10 nearby independent rule"; break
                    end
                end
            end
            -- Author feedback: a body-type label inside a sock-photo trade
            -- request should warn, rather than hiding the entire request.
            -- Use bounded, whole-word cues; other accepted rules keep their scores.
            local nearby = before .. " " .. after
            if meta.pack == "labels" and Any(nearby, {"wtb", "wts"})
                and Any(nearby, {"sock pics", "sock pic"}) then
                score = math.min(score, 55)
                reasons[#reasons + 1] = "55 cap: body-type label in a sock-photo trade request"
            end
        end
        score = math.max(0, math.min(100, score))
        local confidenceScore,action,shieldEligible=score,nil,false
        if policy then
            local uncertain=not semantic and (contextUncertain or rawScore>score and score<=55)
            action=stockProtection and ns.ProtectionContext.Action(meta.protectionProfile or meta.pack,decision.kind,C.PackPreset(settings,meta.pack),decision.affectionate)
                or modernTopic and ns.PreferenceContext.Action(decision,C.PackPreset(settings,meta.pack))
                or (score>0 and C.Policy(C.PackPreset(settings,meta.pack),kind,uncertain) or 'Unchanged')
            score=actionScores[action]
            shieldEligible=stockProtection and decision.eligible==true and decision.shieldEligible==true
                or not stockProtection and (kind=='strong' or kind=='threat') and confidenceScore>=80 and score>=80
                    and (not decision or decision.detectorType~='topicPreference')
            reasons[#reasons+1]='action preset: '..(C.PackPreset(settings,meta.pack)=='strict' and 'Mild' or C.PackPreset(settings,meta.pack)=='balanced' and 'Balanced' or 'Strict')..'; '..tostring(kind)..' -> '..action
            if typoWork and (typoWork.contextRepairs or 0)>0 then reasons[#reasons+1]='bounded context spelling repair used' end
        end
        if disabled then reasons[#reasons + 1] = "pack disabled" end
        if excluded then reasons[#reasons + 1] = "exception phrase in same context window" end
        -- Stock protection covers the qualifying expression, not its subject
        -- reference. Preserve both offsets for recovery and spelling evidence.
        local match = {first = (stockProtection or modernTopic) and decision.first or hit.first,
            last = (stockProtection or modernTopic) and decision.last or hit.last, rule = hit.rule, phrase = phrase,
            score = score, pack = meta.pack, id = meta.id, origin = meta.origin,typo=hit.typo==true,typoEdits=hit.typoEdits,
            reason = table.concat(reasons, "; "), threshold = policy and 0 or packThreshold,
            confidenceScore=policy and confidenceScore or nil,policy=policy==true,action=action,ruleKind=kind,shieldEligible=shieldEligible,
            accepted = not disabled and not excluded and (policy and score>0 or not policy and score>=packThreshold)}
        if decision then
            if decision.eligible and (hit.typo or typoWork and (typoWork.contextRepairs or 0)>0) then decision.certainty='medium' end
            for _,key in ipairs({'stance','strength','certainty','contextCue','detectorType','stanceSource','contextPolicyVersion','preferenceKind'}) do match[key]=decision[key] end
            match.target=phrase
            if stockProtection or modernTopic then match.targetFirst=hit.first;match.targetLast=hit.last end
            if stockProtection and decision.certainty~='high' then match.shieldEligible=false end
        end
        report[#report + 1] = match
        if match.accepted then accepted[#accepted + 1] = match end
    end
    local vocabularyMatcher = GommageMatcher(settings)
    if vocabularyMatcher then
        local literal, literalError = vocabularyMatcher:FindFlexible(text, true)
        if literalError then return {}, {}, literalError end
        literal=WithTypos(vocabularyMatcher,literal)
        if #hits + #literal > ns.Engine.MAX_CANDIDATES then return {}, {}, "candidate budget exceeded" end
        for _, hit in ipairs(literal) do
            local phrase = vocabularyMatcher.rules[hit.rule]
            local meta = ns.Gommage.Meta[phrase]
            if C.GommageEnabled(settings,meta.pack) then
            local first, last = Window(lower, hit)
            local excluded = false
            for i = first, last do
                if exceptionStarts[i] and exceptionStarts[i] <= last then excluded = true; break end
            end
            local disabled = settings.disabledPacks and settings.disabledPacks[meta.pack]
            local reason = "Gommage display mask; no confidence score contribution"
            if hit.evasion then reason = reason .. "; bounded spelling/spacing/symbol variation" end
            if hit.typo then reason=reason..'; spelling guess: '..text:sub(hit.first,hit.last)..' -> '..phrase..' ('..hit.typoEdits..' edits)' end
            if disabled then reason = reason .. "; pack disabled" end
            if excluded then reason = reason .. "; exception phrase in same context window" end
            local match = {first = hit.first, last = hit.last, rule = hit.rule,
                phrase = phrase, score = 0, gommage = true, action = "Redacted", pack = meta.pack, id = meta.id, origin = meta.origin,
                reason = reason, threshold = 0, accepted = not disabled and not excluded,typo=hit.typo==true,typoEdits=hit.typoEdits}
            report[#report + 1] = match
            if match.accepted then accepted[#accepted + 1] = match end
            end
        end
    end
    -- Explicit display substitutions override only overlapping stock hits.
    -- The common wording switch controls both built-in labels and imported variants.
    local replacementSources = {}
    if ns.BodyReplacements and not (settings.disabledPacks and settings.disabledPacks.labels) then
        replacementSources[#replacementSources+1] = {ns.BodyReplacements, ns.BodyReplacementText, "labels", "author-signed display replacement"}
    end
    if ns.BuiltinBodyReplacements then
        replacementSources[#replacementSources+1] = {ns.BuiltinBodyReplacements, ns.BuiltinBodyText, "bodyLabels", "built-in body-type wording"}
    end
    if settings.barber ~= false then
    for _, source in ipairs(replacementSources) do
        local replacements, replacementError = source[1]:FindFlexible(text, true)
        if replacementError then return {}, {}, replacementError end
        replacements=WithTypos(source[1],replacements)
        for _, hit in ipairs(replacements) do
            local first, last = Window(lower, hit)
            local excluded = false
            for i = first, last do
                if exceptionStarts[i] and exceptionStarts[i] <= last then excluded = true; break end
            end
            local phrase = source[1].rules[hit.rule]
            hit.phrase, hit.pack, hit.id = phrase, source[3], source[3] .. ":replacement:" .. phrase
            hit.score, hit.threshold, hit.action = 80, 0, "Replaced"
            hit.replacement = BodyLabelCase(source[2][phrase], text:sub(hit.first, hit.last))
            hit.origin, hit.reason = source[4], "display replacement: " .. hit.replacement
            if hit.typo then hit.reason=hit.reason.."; spelling guess: "..text:sub(hit.first,hit.last).." -> "..phrase end
            hit.accepted = not excluded
            if hit.accepted then
                for _, stock in ipairs(report) do
                    if stock.first <= hit.last and stock.last >= hit.first then stock.accepted = false end
                end
                accepted[#accepted + 1] = hit
            end
            report[#report + 1] = hit
        end
    end
    end
    if ns.Personal and settings.personalRules ~= false then
        local personal, personalError = ns.Personal.Hits(text,typoWork)
        if personalError then return {}, {}, personalError end
        for _, hit in ipairs(personal) do
            local first, last = Window(lower, hit)
            local excluded = false
            for i = first, last do
                if exceptionStarts[i] and exceptionStarts[i] <= last then excluded = true; break end
            end
            hit.accepted = not excluded and hit.score > 0
            if excluded then hit.reason = hit.reason .. "; exception phrase in same context window"
            else
                for _, stock in ipairs(report) do
                    if stock.first <= hit.last and stock.last >= hit.first then
                        stock.accepted = false; stock.reason = stock.reason .. "; overridden by " .. hit.id
                    end
                end
            end
            report[#report + 1] = hit
            if hit.accepted then accepted[#accepted + 1] = hit end
        end
    end
    -- Merge only eligible ranges after personal overrides have been applied.
    local function Order(a, b) return a.first < b.first or (a.first == b.first and a.last > b.last) end
    table.sort(accepted, Order); table.sort(report, Order)
    local result, masks = {}, {}
    for _, hit in ipairs(accepted) do
        if hit.accepted and hit.gommage then masks[#masks + 1] = hit end
        if hit.accepted and not hit.gommage then
        local previous = result[#result]
        if previous and hit.first <= previous.last then
            local first, last = previous.first, math.max(previous.last, hit.last)
            local count = (previous.overlapCount or 1) + 1
            if hit.score > previous.score then
                previous = {}; for key, value in pairs(hit) do previous[key] = value end
                result[#result] = previous
            end
            previous.first, previous.last, previous.overlapCount = first, last, count
        else
            local copy = {}; for key, value in pairs(hit) do copy[key] = value end
            result[#result + 1] = copy
        end
        end
    end
    for _, match in ipairs(result) do
        if match.overlapCount then
            match.reason = match.reason .. "; " .. match.overlapCount .. " overlapping accepted rules; strongest score retained"
        end
    end
    -- Overlay display-only ranges AFTER the unchanged Broad merge. Splitting at
    -- boundaries prevents a mask from expanding a warning or affecting scores.
    if #masks > 0 then
        local merged = {}
        for _, hit in ipairs(masks) do
            local previous = merged[#merged]
            if previous and hit.first <= previous.last then previous.last = math.max(previous.last, hit.last)
            else local copy = {}; for k,v in pairs(hit) do copy[k]=v end; merged[#merged+1]=copy end
        end
        local points, seen = {}, {}
        for _, list in ipairs({result, merged}) do
            for _, hit in ipairs(list) do
                for _, point in ipairs({hit.first, hit.last+1}) do
                    if not seen[point] then seen[point]=true; points[#points+1]=point end
                end
            end
        end
        table.sort(points)
        local composed, normalIndex, maskIndex = {}, 1, 1
        for i=1,#points-1 do
            local first, last = points[i], points[i+1]-1
            while result[normalIndex] and result[normalIndex].last < first do normalIndex=normalIndex+1 end
            while merged[maskIndex] and merged[maskIndex].last < first do maskIndex=maskIndex+1 end
            local normal, mask = result[normalIndex], merged[maskIndex]
            if normal and normal.first > first then normal=nil end
            if mask and mask.first > first then mask=nil end
            local source = normal or mask
            if source then
                local copy = {}; for k,v in pairs(source) do copy[k]=v end
                copy.first, copy.last = first, last
                copy.gommage = mask ~= nil
                if mask and normal then copy.reason=copy.reason.."; separate Gommage display mask (score unchanged)" end
                composed[#composed+1]=copy
            end
        end
        result = composed
    end
    return result, report,nil,typoWork
end
function C.Describe(match, hidePhrase)
    if match.policy then return (hidePhrase and 'Match' or match.phrase)..' — '..(match.action or 'Unchanged')..'; '..(match.ruleKind or 'configured rule')..'. '..match.reason end
    if match.gommage and match.score == 0 then
        return (hidePhrase and "Match" or match.phrase) .. " — Gommage display only; no score contribution. " .. match.reason
    end
    local _, confidence = ns.MatchAction({match})
    return (hidePhrase and "Match" or match.phrase) .. " — " .. confidence .. " match confidence " .. match.score .. "/100, threshold " .. match.threshold
        .. ", " .. (match.accepted and "eligible" or "left visible") .. ". " .. match.reason
end
