-- Optional personal guild-language preset. A guild name alone scores zero.
local _, ns = ...
ns.RULE_VERSION = "stock-2-guild-4"
ns.PackNames[#ns.PackNames + 1] = "guild"
for _, name in ipairs({"olympus", "olmypus", "olypmus", "olymups", "olympuss", "olymps"}) do
    ns.StockRules[#ns.StockRules + 1] = name
    ns.RuleMeta[name] = {id = "guild:" .. name, pack = "guild", base = 0,
        origin = "user-requested Olympus guild preference", version = 4}
end

local severe = {"npc", "npcs", "ragebaiter", "rage baiter", "ragebaiters", "clout farmer", "clout farmers", "boot licker", "boot lickers", "dick rider", "dick riders", "meat rider", "meat riders", "brainrotted", "brain rotted", "garbo", "trashcan", "trash cans", "dumbfk", "dipshyt", "dipshyts", "retard", "retards", "retarded", "kys", "kill yourself", "terminally online", "chronically online", "washed up", "washed-up", "has-been", "has been", "bitch", "bitches", "dipshit", "dumbass", "asshat", "buffoon", "bootlicker", "bootlickers", "brownnoser", "parasite", "piece of shit", "pieces of shit", "scumbag", "scumbags", "incel", "incels", "simp", "simps", "shill", "shills", "glazer", "glazers", "fraud", "frauds", "grifter", "griefers", "jackass", "jackasses", "shithead", "shitheads", "braindead", "brain dead", "degenerate", "creep", "weirdo", "sellout", "trash", "garbage", "scum", "idiots", "idiot", "morons", "moron",
    "losers", "loser", "clowns", "clown", "scrubs", "scrub", "shit", "dogshit",
    "assholes", "asshole", "cancer", "worthless", "pathetic", "stupid", "dumb",
    "ass", "horrible", "dogwater", "dog water", "dogshit tier", "trash tier",
    "shit tier", "dumbfuck", "dipshits", "bozo", "bozos",
    "cringelords", "glazing", "meatrider", "meatriders", "dickrider", "dickriders",
    "mouthbreather", "mouthbreathers", "smoothbrain", "smoothbrains", "brainlets",
    "brainlet", "tool", "tools", "bums", "bum", "noob", "noobs", "skill issue"}
local moderate = {"bad", "overrated", "annoying", "toxic", "cringe", "cringey",
    "terrible", "awful", "crybaby", "manchild", "washed", "brainrot", "cringelord", "tryhard", "clout chaser", "attention seeker", "elitist", "obnoxious", "incompetent", "cooked", "mid", "a walking l"}
local function Starts(text, term)
    return ns.Engine.EvasionPrefix(text, term) ~= nil
end
local function Trim(text) return text:match("^%s*(.-)%s*$") end

function ns.GuildScore(before, after)
    -- Bound the grammar to the same sentence/markup segment supplied by Confidence.
    local tail = Trim(after)
    tail = tail:gsub("^%d+%s+", "", 1) -- Olympus 2, etc.
    tail = tail:gsub("^'s%s+", "", 1)
    local stem = tail
    for _, noun in ipairs({"guild members", "guild players", "guild", "members", "players", "people"}) do
        if Starts(stem, noun) then stem = Trim(stem:sub(ns.Engine.EvasionPrefix(stem,noun) + 1)); break end
    end
    if Starts(stem, "sucks") or Starts(stem, "suck") then return 90, "direct guild insult: suck/sucks" end
    local linked = false
    for _, copula in ipairs({"looks like", "seems like", "acts like", "sounds like", "is", "are"}) do
        if Starts(stem, copula) then stem = Trim(stem:sub(ns.Engine.EvasionPrefix(stem,copula) + 1)); linked = true; break end
    end
    -- Prevent bare co-occurrence: 'Olympus defeated those trash players'.
    if linked then
        for _ = 1, 5 do
            local removed = false
            for _, filler in ipairs({"all", "just", "really", "so", "absolute", "absolutely",
                "fucking", "a bunch of", "full of", "nothing but", "such", "total", "complete", "literally", "still", "a", "an", "the"}) do
                if Starts(stem, filler) then stem = Trim(stem:sub(ns.Engine.EvasionPrefix(stem,filler) + 1)); removed = true; break end
            end
            if not removed then break end
        end
        for _, term in ipairs(severe) do if Starts(stem, term) then return 90, "direct guild insult: " .. term end end
        for _, term in ipairs(moderate) do if Starts(stem, term) then return 90, "direct guild criticism: " .. term end end
        -- Explicit tester preference for a bare directed taunt. The identity
        -- word alone, unrelated people and longer identity discussion are not rules.
        if Starts(stem, "gay") then
            local rest = Trim(stem:sub(ns.Engine.EvasionPrefix(stem,"gay") + 1))
            if rest == "" or rest:match("^%p+$") then return 90, "configured directed taunt" end
        end
        -- Negation is never stripped: 'Olympus is not trash' stays visible.
    end
    for _, term in ipairs(severe) do
        if Starts(tail, term) then
            local rest = Trim(tail:sub(ns.Engine.EvasionPrefix(tail,term) + 1))
            if rest == "" or rest:match("^%p+$") or Starts(rest, "guild") or Starts(rest, "members") then
                return 90, "direct elliptical guild insult: " .. term
            end
        end
    end
    local lead = Trim(before)
    for _, term in ipairs({"fuck", "fucking", "screw", "i hate", "we hate", "hate", "death to"}) do
        local suffix = lead:sub(-#term)
        local preceding = lead:sub(-#term - 1, -#term - 1)
        if ns.Engine.EvasionSuffix(lead,term) then return 90, "hostile guild phrase: " .. term end
    end
    for _, term in ipairs(severe) do
        for _, suffix in ipairs({term, term .. " guild", term .. " from", term .. " in", term .. " of"}) do
            if ns.Engine.EvasionSuffix(lead,suffix) then
                return (suffix == term or suffix == term .. " guild") and 90 or 72, "guild-directed insult: " .. term
            end
        end
    end
    return 0, "guild mentioned without a recognized directed insult"
end
