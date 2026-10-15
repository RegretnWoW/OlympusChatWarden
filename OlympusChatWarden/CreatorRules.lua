-- Curated subject references and explicit nickname viewing preferences.
-- Matching these preferences does not establish a speaker's intent or a fact.
local _, ns = ...
ns.RULE_VERSION = "stock-4-guild-8-creator-7-tuning-5"
ns.PackNames = {"guild", "creator"}
ns.CreatorAliases = {}
local function Add(phrase, base, origin, kind, needsReference)
    if ns.RuleMeta[phrase] then return end
    ns.StockRules[#ns.StockRules + 1] = phrase
    ns.RuleMeta[phrase] = {id = "creator:" .. phrase, pack = "creator", base = base,
        origin = origin, version = 8, kind = kind, needsReference = needsReference,role=kind=='alias' and 'reference' or 'preference'}
    if kind == "alias" then ns.CreatorAliases[#ns.CreatorAliases + 1] = phrase end
end
local function Names(names, base, origin, kind, needsReference)
    for _, name in ipairs(names) do Add(name, base, origin, kind, needsReference) end
end
Names({"asmongold", "asmon", "zackrawrr", "asmonfresh", "asmongler"}, 0,
    "reported character/channel alias; Dot Esports name-reservation coverage", "alias")
Names({"asmontv", "asmongold tv"}, 0, "Asmongold TV YouTube channel", "alias")
-- Keep submitted/common misspellings as identity references with zero base.
-- Symbol/spacing/leetspeak variants are already handled by the matcher.
Names({"asmondgold", "zackrawr", "zakrawrr", "zakrawr"}, 0,
    "retained spelling preference; Zakrawr explicitly requested by tester", "alias")

Names({"asmonbald"}, 82, "documented nickname; Know Your Meme", "nickname")
Names({"asmonmald"}, 82, "observed community nickname; r/Asmongold", "nickname")
Names({"asmonroach"}, 82, "observed community nickname; Steam discussion", "nickname")
Names({"baldmongold"}, 82, "observed community nickname; r/Asmongold", "nickname")
Names({"asmonmold"}, 82, "observed community nickname; r/videos", "nickname")
Names({"asmonglod", "asmogold", "asmnogold", "asmongoldd", "asmonglodtv", "asmongoldtv"}, 0,
    "author-requested spelling/channel variant; not an identity assertion", "alias")
Names({"asmongarbage", "asmontrash", "asmonloser", "asmonbozo", "asmonfraud", "asmonshill", "asmonclown", "asmoncringe", "asmonincel", "asmonsimp"}, 82,
    "author preference for creator-directed compound insult spelling", "nickname")

-- Speculative fan titles and invented aliases are deliberately omitted. Add
-- a personal rule if a particular title is part of your own viewing preference.

local function Word(c)
    return c and c ~= "" and (c:match("[%w_]") or c:byte() >= 128)
end
local function Has(text, phrase)
    local position = 1
    while true do
        local first, last = text:find(phrase, position, true)
        if not first then return false end
        if not Word(text:sub(first - 1, first - 1)) and not Word(text:sub(last + 1, last + 1)) then return true end
        position = first + 1
    end
end
local function Starts(text, term)
    return ns.Engine.EvasionPrefix(text, term) ~= nil
end
local function Trim(text) return text:match("^%s*(.-)%s*$") end
local referenceMatcher
local function Reference(text)
    if not referenceMatcher then referenceMatcher=assert(ns.Engine.Compile(ns.CreatorAliases)) end
    return #referenceMatcher:FindFlexible(text,true)>0
end
local appearance = {"bald", "balding", "baldheaded", "bald-headed", "neckbeard", "unwashed",
    "smelly", "stinky", "dirty", "disgusting", "greasy", "washed up", "washed-up",
    "a rat", "a roach", "a cockroach", "a caveman", "a basement dweller", "a no life", "a no-life"}
local allegation = {"a liar", "a hypocrite", "a scammer", "a grifter", "a fraud", "a sellout",
    "liar", "hypocrite", "scammer", "grifter", "fraud", "sellout"}

function ns.CreatorScore(before, after, meta,work)
    local function ContentStart(text,term) return ns.Engine.EvasionPrefix(text,term) or ns.TypoFilter and ns.TypoFilter.ContextPrefix(text,term,work) end
    if meta.needsReference and not Reference(before .. " " .. after) then
        return 0, "ambiguous fan title without a separate Asmongold alias"
    end
    local score, detail, patternKind = ns.SubjectPatterns.Score(before, after,nil,work)
    detail = detail:gsub("subject", "creator")
    local tail = Trim(after):gsub("^'s%s+", "", 1)
    -- This precise submitted taunt is a personal preference, not an inference
    -- about anyone. Do not extend it to ordinary sentences about children.
    if Starts(tail, "likes kids") then
        local rest = Trim(tail:sub(ns.Engine.EvasionPrefix(tail,"likes kids") + 1))
        if rest == "" or rest:match("^%p+$") then score, detail = 90, "configured directed taunt" end
    end
    -- Only a directly attached insult, with bounded spacing/punctuation. Do
    -- not normalize whole messages or join unrelated words across clauses.
    local insult = tail:gsub("^[:,%-]+%s*", "")
    local asserted = false
    for _, prefix in ipairs({"is", "are"}) do
        if Starts(insult, prefix) then insult = Trim(insult:sub(ns.Engine.EvasionPrefix(insult,prefix) + 1)); asserted = true; break end
    end
    if asserted then
        for _ = 1, 4 do
            local changed = false
            for _, filler in ipairs({"a", "an", "the", "just", "really", "fucking"}) do
                if Starts(insult, filler) then insult = Trim(insult:sub(ns.Engine.EvasionPrefix(insult,filler) + 1)); changed = true; break end
            end
            if not changed then break end
        end
    end
    local rest = insult:match("^b[%s_%-]*i[%s_%-]*t[%s_%-]*c[%s_%-]*h(.*)$")
    if rest and not Word(rest:sub(1, 1)) and (asserted or Trim(rest) == "" or rest:match("^%p")) then
        score, detail = 90, "direct creator insult, including spaced spelling"
    end
    local direct = tail
    local linked = false
    for _, prefix in ipairs({"looks like", "seems like", "acts like", "is", "are", "looks", "seems"}) do
        if Starts(direct, prefix) then direct = Trim(direct:sub(ns.Engine.EvasionPrefix(direct,prefix) + 1)); linked = true; break end
    end
    if linked then
        for _ = 1, 4 do
            local changed = false
            for _, filler in ipairs({"just", "really", "so", "fucking", "absolutely", "still"}) do
                if Starts(direct, filler) then direct = Trim(direct:sub(ns.Engine.EvasionPrefix(direct,filler) + 1)); changed = true; break end
            end
            if not changed then break end
        end
        for _, term in ipairs(appearance) do
            if ContentStart(direct, term) and score < 82 then score, detail = 82, "configured appearance/lifestyle tease: " .. term end
        end
        for _, term in ipairs(allegation) do
            if ContentStart(direct, term) and score < 90 then score, detail = 90, "direct creator allegation/insult: " .. term end
        end
    end
    for _, phrase in ipairs({"needs a shower", "needs to shower", "never showers", "doesn't shower",
        "does not shower", "never washes", "has no hair", "has a receding hairline"}) do
        if Starts(tail, phrase) and score < 82 then score, detail = 82, "configured hair/hygiene tease: " .. phrase end
    end
    local lead = Trim(before)
    for _, term in ipairs({"bald", "balding", "unwashed", "smelly", "stinky", "greasy", "neckbeard"}) do
        if ns.Engine.EvasionSuffix(lead,term) and score < 82 then
            score, detail = 82, "configured creator-directed tease: " .. term
        end
    end
    if score < meta.base then
        score, detail = meta.base, "configured nickname preference: " .. (meta.kind or "nickname")
    end
    if score~=55 and patternKind=='criticism' then patternKind=nil end
    return score, detail,patternKind or (score>=95 and 'threat' or score>=85 and 'strong' or score>0 and 'preference')
end
