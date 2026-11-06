-- Passive optional presentation/diagnostic extension. No frames, collection,
-- identity allowlist or developer engine is installed by the public addon.
local _,ns=...
OlympusWardenSimLabHost=function(extension)
    if type(extension)~='table' or extension.apiVersion~=1 then return false end
    extension.Host=ns;ns.WardenSimLab=extension;return true
end
