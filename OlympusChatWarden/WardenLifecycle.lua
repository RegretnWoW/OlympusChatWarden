-- Adapters around existing services; no new collectors or saved history format.
local _,ns=...
local M=ns.Modules
local function Init(name) local v=ns[name];if v and v.Initialize then v.Initialize() end end
function M.LoadActivityHistory()
    if not M.activityHistoryReady and (M.Enabled('chat') or M.Enabled('shield') or M.Enabled('alerts')) then
        local ok,err=pcall(Init,'History');M.activityHistoryReady=ok
        if not ok then
            if ns.Initializing then ns.StartupErrors[#ns.StartupErrors+1]='Activity history initialization failed.' end
            local handler=geterrorhandler and geterrorhandler();if type(handler)=='function' then pcall(handler,err) end
        end
    end
end
function M.LoadHistory()
    local S=ns.ChronicleStore
    if S.loading or S.db and S.db==ns.DB.chronicle then return true end
    ns.Chronicle.Initialize(true);if M.worldReady then ns.Chronicle.ModuleWorldReady() end;return not S.blocked or S.loading
end
function M.ClearHistoryCaches()
    ns.ChronicleActivities.Clear();ns.WardenDossier.caches=setmetatable({},{__mode='kv'})
    if ns.Athena and ns.Athena.ClearHistoryContext then ns.Athena.ClearHistoryContext() end
    if ns.WardenSearch.CancelOpen then ns.WardenSearch.CancelOpen() end
    if ns.WardenUI.CancelNavigation then ns.WardenUI.CancelNavigation() end
    local W=ns.Workspace
    for _,id in ipairs({'chronicle','intel'}) do local p=W and W.pages[id];if p and p:IsShown() then p:Hide();if M.Enabled(id) then p:Show() end end end
end
function M.ClearCaches()
    -- Active caches include protection thresholds, current dictionary state and
    -- in-use evidence selections. Leave them intact during routine cleanup.
    if not M.Enabled('history') then M.ClearHistoryCaches() end
    if not M.Enabled('chat') and ns.Spelling.Release then ns.Spelling.Release() end
    if not M.Enabled('shield') then ns.Spam.Reset() end
    return 'Unused temporary caches cleared. Active filtering, protection and history views were kept.'
end
local deferredChatCleanup
local function ChatUICleanup()
    if InCombatLockdown and InCombatLockdown() then deferredChatCleanup=true;M.cleanupPending=true;return end
    deferredChatCleanup=nil;M.cleanupPending=nil
    if ns.RefreshUI then ns.RefreshUI(true) end
    if ns.NameDisplays.ClearBindings then ns.NameDisplays.ClearBindings() end
end
M.BeforeScopeChange=function() if ns.Chronicle.Active() then ns.Chronicle.Flush() end end
local previousScope
function M.PrimeScope() previousScope=tostring(M.Enabled('chronicle'))..'/'..tostring(M.Enabled('intel')) end
function M.ScopeChanged()
    M.LoadActivityHistory()
    local scope=tostring(M.Enabled('chronicle'))..'/'..tostring(M.Enabled('intel'))
    if scope~=previousScope then
        previousScope=scope;ns.Chronicle.ModuleBoundary();M.ClearHistoryCaches()
        if M.Enabled('history') then M.LoadHistory();ns.Chronicle.RefreshGate() else ns.ChronicleStore.CancelLoad() end
    end
    if ns.Workspace and ns.Workspace.window then ns.Workspace.Queue() end
end
M.Register('chat',function() if ns.RulePacks.RuntimeDeferred then ns.RulePacks.Initialize() end;Init('Language');Init('ChatCapture');Init('Spelling') end,function()
    ns.RulePacks.Suspend();ns.PacksSuspended=true;if ns.Spelling.Release then ns.Spelling.Release() end
    ChatUICleanup()
    ns.Matcher=nil;ns.BodyReplacements=nil;ns.Gommage=nil;ns.RulePacks.RuntimeDeferred=true
end,function()
    if ns.RulePacks.RuntimeDeferred then ns.RulePacks.Initialize() end
    if not ns.Initializing and ns.Membership.Allowed() then ns.PacksSuspended=nil;ns.RulePacks.Restore() end
    if ns.InstallAdapters then ns.InstallAdapters() end
end)
M.Register('shield',function() Init('Shield') end,function() ns.Shield.Suspend();ns.Spam.Reset() end)
M.Register('alerts',function() Init('Mentions');Init('Wanted');Init('OlympusMuteSignal') end,function()
    ns.Wanted.Stop();ns.OlympusMuteSignal.Stop()
    if ns.HideWantedToast then ns.HideWantedToast() end
end,function() ns.Wanted.Refresh() end)
M.Register('chronicle',M.LoadHistory,function() end)
M.Register('intel',M.LoadHistory,function()
    ns.ChronicleEncounters.Stop();ns.WardenDossier.caches=setmetatable({},{__mode='kv'})
end)
ns.SignalCore.Subscribe('chat.displayed','alerts','mentions',function(e) ns.Mentions.Observe(e.entry,e.source,e.preview) end)
ns.SignalCore.Subscribe('chat.received','chat','capture',function(e) ns.ChatCapture.Record(e.event,e.message,e.sender,e.lineID,e.channel) end)
ns.SignalCore.Subscribe('chat.unrendered','alerts','mentions',function(e) ns.Mentions.Unrendered(e.entry) end)
-- Stable stateless helpers remain callable. Optional producers and UI entry
-- points receive their own gates instead of waking a disabled module.
local function Guard(owner,key,id)
    local fn=owner and owner[key];if type(fn)~='function' then return end
    owner[key]=function(...) if not M.Enabled(id) then return nil,'Module disabled. Open Settings > Modules & Performance.' end;return fn(...) end
end
for _,key in ipairs({'Request','Pump'}) do Guard(ns.WardenDossier,key,'intel') end
for _,key in ipairs({'ObserveUnit','ImportantGUID','NativeInspect','ObserveImportant','InspectPump','Request'}) do Guard(ns.ChronicleEncounters,key,'intel') end
for _,key in ipairs({'Find','Observe','Unrendered'}) do Guard(ns.Mentions,key,'alerts') end
for _,key in ipairs({'Record'}) do Guard(ns.ChatCapture,key,'chat') end
for _,key in ipairs({'Observe','ObserveWhisper','FilterChat','Prune'}) do Guard(ns.Shield,key,'shield') end
for _,key in ipairs({'Observe','Context'}) do Guard(ns.Spam,key,'shield') end
Guard(ns.OlympusMuteSignal,'Observe','alerts')
local events=CreateFrame('Frame');events:RegisterEvent('PLAYER_REGEN_ENABLED');events:RegisterEvent('PLAYER_ENTERING_WORLD');events:RegisterEvent('PLAYER_LEAVING_WORLD');events:RegisterEvent('PLAYER_LOGOUT')
events:SetScript('OnEvent',function(_,event,initial,reload)
    if not ns.DB or not M.config then return end
    if event=='PLAYER_ENTERING_WORLD' then
        -- Access can resolve inside Core's callback for this same event. A
        -- newly attached recorder may not receive an in-flight native event.
        -- This always-on lifecycle observer preserves the handoff even then;
        -- Chronicle still checks history validation, modules and consent.
        M.worldReady=true;ns.Chronicle.ModuleWorldReady(initial,reload)
    elseif event=='PLAYER_LEAVING_WORLD' or event=='PLAYER_LOGOUT' then
        M.worldReady=false;ns.Chronicle.ModuleWorldLeft()
    end
    if event=='PLAYER_LOGOUT' then if not M.Enabled('history') then ns.ChronicleStore.PrepareLogout() end;return end
    if event=='PLAYER_REGEN_ENABLED' and deferredChatCleanup then ChatUICleanup() end
    if event=='PLAYER_REGEN_ENABLED' and M.pendingCombat then M.pendingCombat=false;M.dirty=true;M.Reconcile();M.ScopeChanged() end
    if event=='PLAYER_REGEN_ENABLED' and ns.Workspace and ns.Workspace.moduleLayoutPending then ns.Workspace.ModulesChanged() end
    if (event=='PLAYER_ENTERING_WORLD' or event=='PLAYER_REGEN_ENABLED') and M.needsWelcome and ns.ModuleUI then ns.ModuleUI.Welcome() end
end)
