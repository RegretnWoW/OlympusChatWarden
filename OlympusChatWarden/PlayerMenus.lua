-- Additive native player-menu actions. Keep each capability independently gated.
local _,ns=...
local M={};ns.PlayerMenus=M
function M.Submenu(root)
    if not ns.Membership.Allowed() or not root or not root.CreateButton then return end
    if root.CreateDivider then root:CreateDivider() end
    return root:CreateButton('Olympus Warden')
end
function M.Name(ctx)
    if not ns.Readable(ctx) or type(ctx)~='table' then return end
    if ns.CanRead(ctx.unit) and ctx.unit~='' then
        if not ns.Checked(ns.SafeCall(UnitIsPlayer,ctx.unit)) then return end
        return ns.Shield.UnitName(ctx.unit)
    end
    if not ns.CanRead(ctx.name) then return end
    local name=ctx.name
    if not name:find('[ %-]') and ns.CanRead(ctx.surname) and ctx.surname~='' then name=name..' '..ctx.surname end
    name=ns.Shield.NormalName(name)
    if not name:find('-',1,true) and ns.CanRead(ctx.server) and ctx.server~='' then name=name..'-'..ctx.server end
    return name
end
function M.Player(ctx)
    local name=M.Name(ctx);local key=name and ns.Shield.Key(name)
    if not key or key==ns.Shield.Key(ns.Shield.UnitName('player')) then return end
    return name,key
end
function M.Section(menu,label)
    if menu.CreateTitle then menu:CreateTitle(label) elseif menu.CreateDivider then menu:CreateDivider() end
end
function M.Button(menu,label,owner,fn,help)
    local item=menu:CreateButton(label,function()
        if not ns.Membership.Allowed() then ns.Print(ns.Membership.Status());return end
        if owner and not ns.Modules.Enabled(owner) then ns.Workspace.Open('modules');return end
        local ok,err=fn();if err then ns.Print(err) end
    end)
    if item and item.SetTooltip then item:SetTooltip(function(tip) tip:AddLine(label,1,.82,.39);tip:AddLine(help,1,1,1,true) end) end
    return item
end
function M.Add(root,ctx,menu)
    if not ns.Membership.Allowed() or not ns.Modules.Enabled('shield') or not ns.DB.shield then return false end
    local S=ns.Shield;local name,key=M.Player(ctx);if not name then return false end
    menu=menu or M.Submenu(root);if not menu then return false end
    M.Section(menu,'ShieldWarden')
    local function Button(label,fn,help)
        return M.Button(menu,label,'shield',fn,help)
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
    end
    Button('Manage player',function() ns.OpenShieldPlayer(name);return true end,'Open ShieldWarden details and saved contact settings. Pausing protection keeps your contacts.')
    return menu
end
function M.History(ctx)
    if not ns.Membership.Allowed() or not (ns.Modules.Enabled('intel') or ns.Modules.Enabled('chronicle')) then return end
    local A=ns.ChronicleActivities;local owner=ns.Chronicle.Owner();local st=A.Peek(owner)
    if not st then return end
    local name,key=M.Player(ctx);if not name then return end
    local guid=ns.CanRead(ctx.unit) and ns.ChronicleStore.GUID(ns.SafeCall(UnitGUID,ctx.unit)) or ns.ChronicleStore.GUID(ctx.guid)
    guid=guid or st.menuNames[key]
    if not guid or guid==owner:match('/(Player%-.+)$') then return end
    return st,owner,guid
end
function M.AddHistory(ctx,menu)
    local st,owner,guid=M.History(ctx);if not st then return end
    local intel=st.intelligence and st.intelligence.players[guid]
    local c=ns.ChronicleStore.Character(owner,false)
    local profile=c and c.profiles[guid];local personal=profile and profile.personal
    local annotated=personal and (personal.watch==true or type(personal.note)=='string' and personal.note~='')
    local shared=st.players[guid]
    local function Open(kind)
        local current,currentOwner,currentGUID=M.History(ctx)
        if current~=st or currentOwner~=owner or currentGUID~=guid then return false,'This player history is no longer available. Reopen the menu.' end
        if InCombatLockdown and InCombatLockdown() then return false,'Open player history after combat.' end
        return ns.WardenUI.Navigate(kind,owner,guid)
    end
    if ns.Modules.Enabled('intel') and (intel and #intel.evidence>0 or annotated) then
        M.Section(menu,'IntelWarden')
        M.Button(menu,'View Player Intelligence','intel',function() return Open('player') end,'Open this exact player’s existing dossier. No inspection or recording is started.')
    end
    if ns.Modules.Enabled('chronicle') and shared and #shared.activities>0 then
        M.Section(menu,'ChronicleWarden')
        M.Button(menu,'View Shared History','chronicle',function() return Open('history') end,'Open retained shared activities filtered to this player. Roster evidence does not imply confirmed participation.')
    end
end
