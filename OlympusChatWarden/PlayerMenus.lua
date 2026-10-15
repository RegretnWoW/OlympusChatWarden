-- Additive native player-menu actions. No protected target/menu replacements.
local _,ns=...
local M={};ns.PlayerMenus=M
function M.Submenu(root)
    if not ns.Active() or not root or not root.CreateButton then return end
    if root.CreateDivider then root:CreateDivider() end
    return root:CreateButton('ChatWarden')
end
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
    if not ns.Active() or not ns.DB.shield or not root or not root.CreateButton then return false end
    local S=ns.Shield;local name=M.Name(ctx);local key=name and S.Key(name)
    if not key or key==S.Key(S.UnitName('player')) then return false end
    local capture=ns.ChatCapture and ns.ChatCapture.db
    local hasCapture=capture and (capture.enabled or #capture.entries>0)
    if not ns.DB.shield.enabled and not hasCapture then return false end
    local menu=M.Submenu(root)
    if not menu or not menu.CreateButton then return false end
    local function Button(label,fn,help)
        local item=menu:CreateButton(label,function()
            local ok,err=fn();if err then ns.Print(err) end
        end)
        if item and item.SetTooltip then item:SetTooltip(function(tip)
            tip:AddLine(label,1,0.82,0.39);tip:AddLine(help,1,1,1,true)
        end) end
    end
    local allowed=ns.DB.shield.allowed[key]
    local shielded=false
    for _,item in ipairs(S.List()) do if item.key==key then shielded=true;break end end
    if ns.DB.shield.enabled and not allowed and not shielded then
        Button('Shield for 15 minutes',function() return S.Add(name,900) end,'Give this player a local timeout across your enabled Shield features.')
    end
    if ns.DB.shield.enabled then
        if shielded then Button('Remove shield',function() S.Remove(name);return true end,'End this shield now. Future contact is allowed.') end
        if allowed then Button('Stop allowing player',function() S.Unallow(name);return true end,'Put this player back under normal Shield protection.')
        else Button('Allow player',function() return S.Allow(name) end,'Remove their shield and exempt them from Shield. Your word filters still apply.') end
        Button('Manage player',function() ns.OpenShieldPlayer(name);return true end,'Open player details for additional shield durations and saved contact settings.')
    end
    if hasCapture then
        Button('View captured chat',function() ns.OpenCapturePlayer(name);return true end,'Find this player in locally saved chat. Recording is controlled in Chat capture.')
    end
    return menu
end
