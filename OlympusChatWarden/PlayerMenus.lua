-- Additive native player-menu actions. No protected target/menu replacements.
local _,ns=...
local M={};ns.PlayerMenus=M
function M.Name(ctx)
    if not ns.Readable(ctx) or type(ctx)~='table' then return end
    if ns.CanRead(ctx.unit) and ctx.unit~='' then
        if ns.SafeCall(UnitIsPlayer,ctx.unit)~=true then return end
        return ns.Shield.UnitName(ctx.unit)
    end
    if not ns.CanRead(ctx.name) then return end
    local name=ctx.name
    if not name:find('[ %-]') and ns.CanRead(ctx.surname) and ctx.surname~='' then name=name..' '..ctx.surname end
    name=ns.Shield.NormalName(name)
    if not name:find('-',1,true) and ns.CanRead(ctx.server) and ctx.server~='' then name=name..'-'..ctx.server end
    return name
end
function M.Add(root,ctx)
    if not ns.DB or not ns.DB.shield or not root or not root.CreateButton then return false end
    local S=ns.Shield;local name=M.Name(ctx);local key=name and S.Key(name)
    if not key or key==S.Key(S.UnitName('player')) then return false end
    if root.CreateDivider then root:CreateDivider() end
    if root.CreateTitle then root:CreateTitle(ns.NAME) end
    local function Button(label,fn,help)
        local item=root:CreateButton(label,function()
            local ok,err=fn();if err then ns.Print(err) end
        end)
        if item and item.SetTooltip then item:SetTooltip(function(tip)
            tip:AddLine(label,1,0.82,0.39);tip:AddLine(help,1,1,1,true)
        end) end
    end
    local allowed=ns.DB.shield.allowed[key]
    local shielded=false
    for _,item in ipairs(S.List()) do if item.key==key then shielded=true;break end end
    if not allowed then
        Button('Shield for 15 minutes',function() return S.Add(name,900) end,'Give this player a local timeout across your enabled Shield features.')
        Button('Shield until logout / reload',function() return S.Add(name,'session') end,'Shield this player for this game session.')
    end
    if shielded then Button('Remove shield',function() S.Remove(name);return true end,'End this shield now. Future contact is allowed.') end
    if allowed then Button('Stop allowing player',function() S.Unallow(name);return true end,'Put this player back under normal Shield protection.')
    else Button('Allow player',function() return S.Allow(name) end,'Remove their shield and exempt them from Shield. Your word filters still apply.') end
    Button('Manage in ChatWarden',function() ns.OpenShieldPlayer(name);return true end,'Open player details for more options, including a shield until you remove it.')
    Button('View captured chat',function() ns.OpenCapturePlayer(name);return true end,'Open Chat capture and search saved chat for this player.')
    return true
end
