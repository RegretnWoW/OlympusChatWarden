-- Stock Olympus protection. A guild name alone scores zero.
local _, ns = ...
ns.RULE_VERSION = "stock-guild-10"
ns.PackNames[#ns.PackNames + 1] = "guild"
for _, name in ipairs({"olympus", "olmypus", "olypmus", "olymups", "olympuss", "olymps"}) do
    ns.StockRules[#ns.StockRules + 1] = name
    ns.RuleMeta[name] = {id = "guild:" .. name, pack = "guild", base = 0,
        origin = "user-requested Olympus guild preference", version = 10,role='reference'}
end

function ns.GuildScore(before,after,work)
    local score,reason,kind=ns.SubjectPatterns.Score(before,after,nil,work)
    return score,reason:gsub("subject","guild"),kind
end
