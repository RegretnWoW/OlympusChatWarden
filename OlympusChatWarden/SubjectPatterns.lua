-- Shared bounded statement patterns for stock subject preferences.
local _,ns=...
local P={};ns.SubjectPatterns=P
local severe = {"npc", "npcs", "ragebaiter", "rage baiter", "ragebaiters", "clout farmer", "clout farmers", "boot licker", "boot lickers", "dick rider", "dick riders", "meat rider", "meat riders", "brainrotted", "brain rotted", "garbo", "trashcan", "trash cans", "dumbfk", "dipshyt", "dipshyts", "retard", "retards", "retarded", "kys", "kill yourself", "terminally online", "chronically online", "washed up", "washed-up", "has-been", "has been", "bitch", "bitches", "dipshit", "dumbass", "asshat", "buffoon", "bootlicker", "bootlickers", "brownnoser", "parasite", "piece of shit", "pieces of shit", "scumbag", "scumbags", "incel", "incels", "simp", "simps", "shill", "shills", "glazer", "glazers", "fraud", "frauds", "grifter", "griefers", "jackass", "jackasses", "shithead", "shitheads", "braindead", "brain dead", "degenerate", "creep", "weirdo", "sellout", "trash", "garbage", "scum", "idiots", "idiot", "morons", "moron",
    "losers", "loser", "clowns", "clown", "scrubs", "scrub", "shit", "dogshit",
    "assholes", "asshole", "cancer", "worthless", "pathetic", "stupid",
    "ass", "horrible", "dogwater", "dog water", "dogshit tier", "trash tier",
    "shit tier", "dumbfuck", "dipshits", "bozo", "bozos",
    "cringelords", "glazing", "meatrider", "meatriders", "dickrider", "dickriders",
    "mouthbreather", "mouthbreathers", "smoothbrain", "smoothbrains", "brainlets",
    "brainlet", "tool", "tools", "bums", "bum", "noob", "noobs", "skill issue"}
local moderate = {"bad", "dumb", "overrated", "annoying", "toxic", "cringe", "cringey",
    "terrible", "awful", "crybaby", "manchild", "washed", "brainrot", "cringelord", "tryhard", "clout chaser", "attention seeker", "elitist", "obnoxious", "incompetent", "cooked", "mid", "a walking l"}
P.Strong,P.Criticism=severe,moderate
local function Starts(text, term)
    return ns.Engine.EvasionPrefix(text, term) ~= nil
end
local function Trim(text) return text:match("^%s*(.-)%s*$") end

function P.Score(before, after, profile,work)
    local function ContentStart(text,term) return ns.Engine.EvasionPrefix(text,term) or ns.TypoFilter and ns.TypoFilter.ContextPrefix(text,term,work) end
    -- Bound the grammar to the same sentence/markup segment supplied by Confidence.
    local tail = Trim(after)
    tail = tail:gsub("^%d+%s+", "", 1) -- Olympus 2, etc.
    tail = tail:gsub("^'s%s+", "", 1)
    -- Optional subject vocabulary is read only from the verified signed model.
    for _,rule in ipairs(profile and profile.statements or {}) do
        if rule.position=='after' and ContentStart(tail,rule.phrase)
            or rule.position=='before' and ns.Engine.EvasionSuffix(Trim(before),rule.phrase) then
            return rule.score,'configured subject statement: '..rule.phrase,rule.score>=95 and 'threat' or rule.score<=55 and 'criticism' or rule.score==82 and 'preference' or 'strong'
        end
    end
    for _,phrase in ipairs({'i will kill','we will kill',"i'll kill",'i am going to kill',"i'm going to kill",'i will murder','we will murder','death to'}) do
        if ns.Engine.EvasionSuffix(Trim(before),phrase) then return 95,'explicit directed threat: '..phrase,'threat' end
    end
    if ContentStart(tail,'kill yourself') or Starts(tail,'kys') then return 95,'explicit directed self-harm threat','threat' end
    local stem = tail
    for _, noun in ipairs({"guild members", "guild players", "guilds", "guild", "members", "players", "people"}) do
        if Starts(stem, noun) then stem = Trim(stem:sub(ns.Engine.EvasionPrefix(stem,noun) + 1)); break end
    end
    if ContentStart(stem, "sucks") or ContentStart(stem, "suck") then return 90, "direct subject insult: suck/sucks" end
    local linked = false
    for _, copula in ipairs({"looks like", "seems like", "acts like", "sounds like", "is", "are"}) do
        if Starts(stem, copula) then stem = Trim(stem:sub(ns.Engine.EvasionPrefix(stem,copula) + 1)); linked = true; break end
    end
    -- Prevent bare co-occurrence: 'Olympus defeated those trash players'.
    if linked then
        if Starts(stem,'not only') then stem=Trim(stem:sub(ns.Engine.EvasionPrefix(stem,'not only')+1)) end
        for _ = 1, 5 do
            local removed = false
            for _, filler in ipairs({"all", "just", "really", "so", "absolute", "absolutely",
                "fucking", "a bunch of", "full of", "nothing but", "such", "total", "complete", "literally", "still", "a", "an", "the"}) do
                if Starts(stem, filler) then stem = Trim(stem:sub(ns.Engine.EvasionPrefix(stem,filler) + 1)); removed = true; break end
            end
            if not removed then break end
        end
        for _,rule in ipairs(profile and profile.statements or {}) do
            if rule.position=='predicate' and ContentStart(stem,rule.phrase) then return rule.score,'configured subject predicate: '..rule.phrase,rule.score>=95 and 'threat' or rule.score<=55 and 'criticism' or rule.score==82 and 'preference' or 'strong' end
        end
        for _, term in ipairs(severe) do if ContentStart(stem, term) then return 90, "direct subject insult: " .. term,'strong' end end
        for _, term in ipairs(moderate) do if ContentStart(stem, term) then return 55, "direct subject criticism: " .. term,'criticism' end end
        -- Explicit tester preference for a bare directed taunt. The identity
        -- word alone, unrelated people and longer identity discussion are not rules.
        if Starts(stem, "gay") then
            local rest = Trim(stem:sub(ns.Engine.EvasionPrefix(stem,"gay") + 1))
            if rest == "" or rest:match("^%p+$") then return 90, "configured directed taunt" end
        end
        -- Negation is never stripped: 'Olympus is not trash' stays visible.
    end
    for _, term in ipairs(severe) do
        local consumed=ContentStart(tail,term)
        if consumed then
            local rest = Trim(tail:sub(consumed + 1))
            if rest == "" or rest:match("^%p+$") or Starts(rest, "guild") or Starts(rest, "members") then
                return 90, "direct elliptical subject insult: " .. term
            end
        end
    end
    local lead = Trim(before)
    for _, term in ipairs({"fuck", "fucking", "screw", "i hate", "we hate", "hate", "death to"}) do
        local suffix = lead:sub(-#term)
        local preceding = lead:sub(-#term - 1, -#term - 1)
        if ns.Engine.EvasionSuffix(lead,term) then return 90, "hostile subject phrase: " .. term end
    end
    for _, term in ipairs(severe) do
        for _, suffix in ipairs({term, term .. " guild", term .. " from", term .. " in", term .. " of"}) do
            if ns.Engine.EvasionSuffix(lead,suffix) then
                return (suffix == term or suffix == term .. " guild") and 90 or 72, "subject-directed insult: " .. term
            end
        end
    end
    -- Mild wording also occurs without a linking verb: 'dumb Olympus' or
    -- 'Olympus dumb'. Keep its severity consistent with 'Olympus is dumb'.
    for _,term in ipairs(moderate) do
        local consumed=ContentStart(tail,term)
        local rest=consumed and Trim(tail:sub(consumed+1))
        if rest and (rest=='' or rest:match('^%p+$') or Starts(rest,'guild') or Starts(rest,'members'))
            or ns.Engine.EvasionSuffix(lead,term) then
            return 55,'direct subject criticism: '..term,'criticism'
        end
    end
    return 0, "subject mentioned without a recognized directed insult"
end
