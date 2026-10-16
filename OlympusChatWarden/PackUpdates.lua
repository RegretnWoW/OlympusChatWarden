-- Advisory build-time catalog only. Import signatures remain authoritative.
local _, ns = ...
local U = {}; ns.PackUpdates = U
local ready = false
function U.List()
    local result = {}
    if not ns.DB or ns.RulePacks.Restoring then return result end
    local installed = ns.RulePacks.Snapshot()
    for _, id in ipairs(ns.RulePacks.Order) do
        local item, latest = installed[id], ns.PackCatalog.packs[id]
        if item and latest and item.keyID == latest.keyID and (item.updateRequired or item.version < latest.version) then
            result[#result+1] = {id=id, title=ns.RulePacks.Title(id), version=latest.version, installed=item.version,required=item.updateRequired}
        end
    end
    return result
end
function U.For(id)
    for _, item in ipairs(U.List()) do if item.id == id then return item end end
end
function U.Check()
    if not ready or not ns.DB or ns.Initializing or ns.RulePacks.Restoring then return end
    local names,required = {},0
    if type(ns.DB.packUpdateNotices)~='table' then ns.DB.packUpdateNotices={} end
    for _, item in ipairs(U.List()) do
        local key=(item.required and 'contract1:' or 'update:')..item.id..':'..item.version
        if not ns.DB.packUpdateNotices[key] then
            ns.DB.packUpdateNotices[key]=true
            names[#names+1] = item.title .. ' v' .. item.version
            if item.required then required=required+1 end
        end
    end
    if #names > 0 then
        ns.Print(required>0 and (required..' filter pack'..(required==1 and ' requires an update' or 's require updates')..'. Old packs and their Gommage masks are paused. Open /ocw packs > Get packs link.')
            or ('Updates for your installed packs: '..table.concat(names,', ')..'. Open /ocw packs > Get packs link.'))
    end
end
local events=CreateFrame('Frame'); events:RegisterEvent('PLAYER_LOGIN')
events:SetScript('OnEvent',function() ready=true; U.Check() end)
