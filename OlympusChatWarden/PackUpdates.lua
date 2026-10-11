-- Advisory build-time catalog only. Import signatures remain authoritative.
local _, ns = ...
local U = {}; ns.PackUpdates = U
local notified, ready = {}, false
function U.List()
    local result = {}
    if not ns.DB or ns.RulePacks.Restoring then return result end
    local installed = ns.RulePacks.Snapshot()
    for _, id in ipairs(ns.RulePacks.Order) do
        local item, latest = installed[id], ns.PackCatalog.packs[id]
        if item and latest and item.keyID == latest.keyID and item.version < latest.version then
            result[#result+1] = {id=id, title=ns.RulePacks.Title(id), version=latest.version, installed=item.version}
        end
    end
    return result
end
function U.For(id)
    for _, item in ipairs(U.List()) do if item.id == id then return item end end
end
function U.Check()
    if not ready or not ns.DB or ns.Initializing or ns.RulePacks.Restoring then return end
    local names = {}
    for _, item in ipairs(U.List()) do
        if notified[item.id] ~= item.version then
            notified[item.id] = item.version
            names[#names+1] = item.title .. ' v' .. item.version
        end
    end
    if #names > 0 then
        ns.Print('Updates for your installed packs: ' .. table.concat(names, ', ') .. '. Open /ocw packs and choose Get packs link. Catalog: ' .. ns.PackCatalog.release .. '.')
    end
end
local events=CreateFrame('Frame'); events:RegisterEvent('PLAYER_LOGIN')
events:SetScript('OnEvent',function() ready=true; U.Check() end)
