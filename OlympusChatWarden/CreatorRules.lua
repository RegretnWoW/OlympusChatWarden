-- Researched aliases plus explicitly marked community/spelling candidates.
-- Matching these preferences does not establish a speaker's intent or a fact.
local _, ns = ...
ns.RULE_VERSION = "stock-3-guild-4-creator-4-tuning-4"
ns.PackNames = {"guild", "creator"}
ns.CreatorAliases = {}
local function Add(phrase, base, origin, kind, needsReference)
    if ns.RuleMeta[phrase] then return end
    ns.StockRules[#ns.StockRules + 1] = phrase
    ns.RuleMeta[phrase] = {id = "creator:" .. phrase, pack = "creator", base = base,
        origin = origin, version = 4, kind = kind, needsReference = needsReference}
    if kind == "alias" then ns.CreatorAliases[#ns.CreatorAliases + 1] = phrase end
end
local function Names(names, base, origin, kind, needsReference)
    for _, name in ipairs(names) do Add(name, base, origin, kind, needsReference) end
end
Names({"asmongold", "asmon", "zackrawrr", "asmonfresh", "asmongler"}, 0,
    "reported character/channel alias; Dot Esports name-reservation coverage", "alias")
Names({"asmontv", "asmongold tv"}, 0, "Asmongold TV YouTube channel", "alias")
Names({"asmongold247"}, 0, "community-reported alternate channel", "alias")
Names({"asmongo", "asmongus"}, 0, "community-reported character-name candidate; unverified", "alias")
Names({"asmon gold", "asmondgold", "asm0ngold", "asm0n", "asmon tv", "asmongold 247",
    "zackrawr", "zackrawwr", "zackraw", "zack rawrr", "zack rawr", "zakrawrr", "zakrawr",
    "zakrawwr", "zak rawrr", "zak rawr", "zachrawrr", "zachrawr"}, 0,
    "proposed spelling/spacing variant; Zakrawr requested by tester", "alias")

Names({"asmonbald"}, 82, "documented nickname; Know Your Meme", "nickname")
Names({"asmonmald"}, 82, "observed community nickname; r/Asmongold", "nickname")
Names({"asmonroach"}, 82, "observed community nickname; Steam discussion", "nickname")
Names({"baldmongold"}, 82, "observed community nickname; r/Asmongold", "nickname")
Names({"asmonmold"}, 82, "observed community nickname; r/videos", "nickname")
Names({"asmon bald", "asmon-bald", "asm0nbald", "asmon mald", "asmon-mald", "asm0nmald",
    "asmon roach", "asmon-roach", "asm0nroach", "bald mongold", "bald-mongold", "baldm0ngold",
    "asmon mold", "asmon-mold", "asm0nmold"}, 82,
    "proposed spacing/leetspeak variant of an observed nickname", "nickname")

Names({"asmonglod", "asmogold", "asmnogold", "asmongoldd", "asmonglodtv", "asmongoldtv", "asmon-gold", "asmon_gold", "asmong0ld", "asmongold live", "asmon live", "zackrawrrrr", "zackrawrrr", "zakrawrrr", "asmongod", "asmongould", "asmonn"}, 0,
    "author-requested spelling/channel variant; not an identity assertion", "alias")
Names({"asmongarbage", "asmontrash", "asmonloser", "asmonbozo", "asmonfraud", "asmonshill", "asmonclown", "asmoncringe", "asmonincel", "asmonsimp"}, 82,
    "author preference for creator-directed compound insult spelling", "nickname")

-- These fan titles are not claimed to be common or official. Require a
-- separate creator alias in the same bounded clause before applying rules.
Names({"roach king", "roachking", "the roach king"}, 0,
    "community-observed fan title; creator reference required", "title", true)
Names({"lord baldimort", "baldimort", "lord baldemort", "baldemort", "the baldfather", "baldfather",
    "baron von baldness", "bald king", "the bald king", "bald messiah", "the bald messiah",
    "bald oracle", "the bald oracle", "unwashed prophet", "the unwashed prophet"}, 72,
    "fan-site title/proposed spelling candidate; Asmongame; creator reference required", "title", true)
Names({"dr roachenstein", "dr. roachenstein", "roachenstein", "transmog tyrant", "the transmog tyrant",
    "gold baron", "the gold baron", "commander of the chair", "high priest of loot", "king of wow",
    "emperor of elwynn", "sultan of salt"}, 0,
    "fan-site title candidate; Asmongame; creator reference required", "title", true)

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

function ns.CreatorScore(before, after, meta)
    if meta.needsReference and not Reference(before .. " " .. after) then
        return 0, "ambiguous fan title without a separate Asmongold alias"
    end
    local score, detail = ns.GuildScore(before, after)
    detail = detail:gsub("guild", "creator")
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
            if Starts(direct, term) and score < 82 then score, detail = 82, "configured appearance/lifestyle tease: " .. term end
        end
        for _, term in ipairs(allegation) do
            if Starts(direct, term) and score < 90 then score, detail = 90, "direct creator allegation/insult: " .. term end
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
    return score, detail
end
