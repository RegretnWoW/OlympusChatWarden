-- Client differences stay here; gameplay collectors and saved schemas are shared.
local _,ns=...
local C={};ns.ClientCompat=C
local function readable(v)
    return not (issecretvalue and issecretvalue(v))
        and not (canaccessvalue and not canaccessvalue(v))
end
local version,build,interface
if type(GetBuildInfo)=='function' then
    local ok,a,b,_,d=pcall(GetBuildInfo)
    if ok then
        if readable(a) and type(a)=='string' then version=a end
        if readable(b) and type(b)=='string' then build=b end
        if readable(d) and type(d)=='number' then interface=d end
    end
end
local project,mainline=WOW_PROJECT_ID,WOW_PROJECT_MAINLINE
local retail=readable(project) and readable(mainline) and type(project)=='number'
    and type(mainline)=='number' and project==mainline
if type(project)~='number' and interface then retail=interface>=100000 end
C.client=retail and 'retail' or interface and interface>=16000 and interface<17000 and 'forever' or 'other'
C.version,C.build,C.interface=version,build,interface
local package=ns.ClientBuild or {}
function C.IsRetailTest()
    return C.client=='retail' and package.target=='retail-test' and package.localTesting==true
end
-- Names change only in the test installation. No history is copied or migrated.
-- Even a misinstalled Retail package cannot write the Forever global names.
local isolated=package.target=='retail-test' or C.client=='retail'
local roots={FiresideRecoveryDB=true,OlympusWardenPrivacyDB=true,OlympusChatWardenDB=true,OlympusWardenRelayDB=true,
    OlympusWardenStartupDB=true,OlympusWardenConversationDB=true,OlympusWardenJournalDB=true,
    OlympusWardenRecollectionsDB=true,OlympusWardenExchangeDB=true,OlympusWardenSimLabDB=true}
function C.StorageName(name)
    if roots[name] then return name..(isolated and 'RetailTest' or '') end
end
-- A private proxy, not a global metatable or an API replacement. Writes to a
-- replaced root reach the declared SavedVariable immediately, including logout.
ns.Storage=setmetatable({},{
    __index=function(_,key) local name=C.StorageName(key);if name then return ns.FiresideSavedData and ns.FiresideSavedData.Read(name,_G[name])or _G[name] end end,
    __newindex=function(_,key,value)
        local name=C.StorageName(key);assert(name,'Unknown Fireside storage root')
        if not(ns.FiresideSavedData and ns.FiresideSavedData.blocked[name])then _G[name]=value end
    end,
})
function C.Status()
    return {client=C.client,version=C.version,build=C.build,interface=C.interface,
        package=package.target,localTesting=C.IsRetailTest(),isolatedStorage=isolated}
end
