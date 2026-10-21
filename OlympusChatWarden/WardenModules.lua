-- Small lifecycle registry. Saved selection never grants collection consent.
local _,ns=...
local M={records={},frames={},revision=0};ns.Modules=M
M.order={'chat','chronicle','intel','shield','alerts'}
M.names={chat='ChatWarden',chronicle='ChronicleWarden',intel='IntelWarden',shield='ShieldWarden',alerts='SignalWarden Alerts'}
local aliases={messages='chat',capture='chat',rules='chat',packs='chat',reports='chat',mentions='alerts',olympusMuteSignal='alerts',wanted='alerts'}
function M.Key(id) return aliases[id] or id end
function M.Enabled(id)
    id=M.Key(id)
    if id=='core' or id=='signal' or id=='relay' or id=='settings' then return true end
    if id=='history' then return M.Enabled('chronicle') or M.Enabled('intel') end
    if not M.config then return true end -- compatibility for pure service callers before startup
    local r=M.records[id];return M.config.selected[id]==true and not (M.config.legacyHold and M.config.legacyHold[id]) and (not r or r.state~='error' and not r.runtimeDisabled)
end
function M.Selected(id) return M.config and M.config.selected[M.Key(id)]==true end
local personalEvents={PLAYER_XP_UPDATE=true,PLAYER_LEVEL_UP=true,QUEST_TURNED_IN=true,SKILL_LINES_CHANGED=true,PLAYER_MONEY=true,
    PLAYER_FLAGS_CHANGED=true,PLAYER_DEAD=true,PLAYER_ALIVE=true,PLAYER_UNGHOST=true,QUEST_ACCEPTED=true,QUEST_REMOVED=true,
    QUEST_LOG_UPDATE=true,UPDATE_FACTION=true,BAG_UPDATE_DELAYED=true,SPELLS_CHANGED=true,ACHIEVEMENT_EARNED=true,
    QUEST_LOOT_RECEIVED=true,QUEST_CURRENCY_LOOT_RECEIVED=true}
function M.Capable(id)
    if id=='core' or id=='signal' or id=='relay' then return true end
    local history=id=='history' or id=='chronicle' or id=='intel'
    return M.Enabled(id) and (not ns.Membership or ns.Membership.Allowed() or history and ns.Membership.LocalHistoryAllowed())
end
function M.EventAllowed(owner,event)
    return M.Enabled(owner) and (owner~='history' or not personalEvents[event] or M.Enabled('chronicle'))
end
local function Attach(r)
    local allowed=M.config and M.Capable(r.owner)
    for event in pairs(r.events) do
        local wanted=allowed and M.EventAllowed(r.owner,event)
        if wanted and not r.bound[event] then r.bound[event]=pcall(r.register,r.frame,event)
        elseif not wanted and r.bound[event] and r.unregister then pcall(r.unregister,r.frame,event);r.bound[event]=nil end
    end
    for name,fn in pairs(r.scripts) do local current=allowed and fn or nil;if r.installed[name]~=current then r.set(r.frame,name,current);r.installed[name]=current end end
end
function M.Frame(owner,...)
    local f=CreateFrame(...);local r={owner=owner,frame=f,events={},scripts={},bound={},installed={},register=f.RegisterEvent,unregister=f.UnregisterEvent,set=f.SetScript}
    M.frames[#M.frames+1]=r
    f.RegisterEvent=function(self,event)
        r.events[event]=true
        if M.config and M.Capable(owner) and M.EventAllowed(owner,event) then local value=r.register(self,event);r.bound[event]=true;return value end
    end
    f.UnregisterEvent=function(self,event) r.events[event]=nil;r.bound[event]=nil;if r.unregister then return r.unregister(self,event) end end
    f.SetScript=function(self,name,fn)
        if name=='OnEvent' or name=='OnUpdate' then
            r.scripts[name]=fn
            if not M.config or not M.Capable(owner) then r.installed[name]=nil;return r.set(self,name,nil) end
            r.installed[name]=fn
        end
        return r.set(self,name,fn)
    end
    return f
end
function M.SyncFrames() for _,r in ipairs(M.frames) do Attach(r) end end
function M.Initialize(existing)
    local saved=ns.DB.moduleSelection
    if type(saved)~='table' or saved.version~=1 or type(saved.selected)~='table' then
        local on=ns.DB.enabled~=false
        saved={version=1,selected={chat=existing or on,chronicle=existing or false,intel=existing or false,
            shield=existing and (not ns.DB.shield or ns.DB.shield.enabled~=false) or false,
            alerts=existing and ns.DB.alertsEnabled~=false or false},onboardingDone=existing==true}
        -- Preserve configured features from the old global pause, without
        -- silently resuming previously inactive collection or enforcement.
        if existing and not on then saved.legacyHold={};for id,selected in pairs(saved.selected) do if id~='chat' and selected then saved.legacyHold[id]=true end end end
        ns.DB.moduleSelection=saved
    end
    for _,id in ipairs(M.order) do
        saved.selected[id]=saved.selected[id]==true;M.records[id]=M.records[id] or {state='not initialized'}
        local r=M.records[id];r.initialized=false;r.runtimeDisabled=nil;if r.state=='error' then r.state='not initialized';r.error=nil end
    end
    M.activityHistoryReady=false
    M.config=saved;M.needsWelcome=saved.onboardingDone~=true;M.dirty=true
end
function M.Register(id,initialize,stop,start) M.records[id]=M.records[id] or {};local r=M.records[id];r.initialize=initialize;r.stop=stop;r.start=start end
local function Run(r,key)
    local fn=r[key];if not fn then return true end
    local ok,err=pcall(fn)
    if not ok then r.state='error';r.error='Module operation failed; saved data retained.';M.errors=(M.errors or 0)+1
        if ns.Initializing and ns.StartupErrors then ns.StartupErrors[#ns.StartupErrors+1]='Optional module initialization failed.' end
        if key~='stop' and r.stop then pcall(r.stop) end
        local handler=geterrorhandler and geterrorhandler();if type(handler)=='function' then pcall(handler,err) end
    end
    return ok
end
function M.Reconcile()
    if not M.config or M.busy then return end;M.busy=true
    local permission=not ns.Membership or ns.Membership.Allowed()
    local localHistory=ns.Membership and ns.Membership.LocalHistoryAllowed() or permission
    if not M.dirty and M.permission==permission and M.localHistory==localHistory then M.busy=false;return end
    M.permission=permission;M.localHistory=localHistory;M.dirty=false
    for _,id in ipairs(M.order) do
        local r=M.records[id];local wanted=M.config.selected[id]==true
        if wanted and M.config.legacyHold and M.config.legacyHold[id] then
            r.state='paused';r.runtimeDisabled=true
        elseif not wanted then
            if r.state=='enabled' or r.state=='suspended' then Run(r,'stop') end
            r.runtimeDisabled=nil;if r.state~='error' then r.state='disabled' end
        elseif r.state~='error' and r.state~='enabled' and InCombatLockdown and InCombatLockdown() then
            r.state='suspended';r.runtimeDisabled=true;M.pendingCombat=true
        elseif r.state~='error' and ns.Membership and not ns.Membership.Allowed() and not ((id=='chronicle' or id=='intel') and localHistory) then
            if r.state=='enabled' then Run(r,'stop') end;r.state='suspended'
        elseif r.state~='error' then
            r.runtimeDisabled=nil
            local ready=r.initialized
            if not ready then ready=Run(r,'initialize');r.initialized=ready end
            if ready then
                local before=r.state;r.state=ns.Membership and not ns.Membership.Allowed() and not ((id=='chronicle' or id=='intel') and localHistory) and 'suspended' or 'enabled'
                if r.state=='enabled' and before~='enabled' then Run(r,'start') end
            end
        end
    end
    M.busy=false;M.SyncFrames()
    if ns.Athena and ns.Athena.ContributeHealth then local count=0;for _,id in ipairs(M.order) do if M.Enabled(id) then count=count+1 end end;ns.Athena.ContributeHealth('command',{enabled=count,errors=M.errors or 0}) end
    if not ns.Initializing and ns.Chronicle then ns.Chronicle.RefreshGate() end
    if M.needsWelcome and M.worldReady and ns.ModuleUI then ns.ModuleUI.Welcome() end
end
function M.Set(id,value)
    id=M.Key(id);if not M.config or not M.names[id] or type(value)~='boolean' then return false end
    local held=M.config.legacyHold and M.config.legacyHold[id]
    if M.config.selected[id]==value and M.records[id].state~='error' and not held then return true end
    if M.config.legacyHold then M.config.legacyHold[id]=nil end
    if (id=='chronicle' or id=='intel') and M.BeforeScopeChange then M.BeforeScopeChange() end
    M.config.selected[id]=value;M.dirty=true
    local r=M.records[id];if value and r.state=='error' then r.state='not initialized';r.error=nil;r.initialized=false end
    M.Reconcile()
    if M.ScopeChanged then M.ScopeChanged() end
    M.revision=M.revision+1
    if ns.Workspace and ns.Workspace.ModulesChanged then ns.Workspace.ModulesChanged() end
    return true
end
function M.Preset(full)
    if M.BeforeScopeChange then M.BeforeScopeChange() end
    M.config.legacyHold=nil;for _,id in ipairs(M.order) do M.config.selected[id]=full==true or id=='chat' end;M.dirty=true
    M.Reconcile();if M.ScopeChanged then M.ScopeChanged() end;M.revision=M.revision+1
    if ns.Workspace and ns.Workspace.ModulesChanged then ns.Workspace.ModulesChanged() end
end
function M.Route(id)
    local key=M.Key(id)
    if M.names[key] and not M.Enabled(key) then return 'modules' end
    return id
end
function M.InitialRoute()
    local count=0;for _,id in ipairs(M.order) do if M.Enabled(id) then count=count+1 end end
    return count==1 and M.Enabled('chat') and 'messages' or 'overview'
end
function M.State(id) local r=M.records[M.Key(id)];return r and r.state or 'always available' end
