-- Shared Olympus styling; selecting a module never grants recording consent.
local _,ns=...
local U={};ns.ModuleUI=U
local M,V,T=ns.Modules,ns.Art,ns.Theme
local specs={
 {'chat','messages','Filter unwanted chat and improve spelling.'},
 {'shield','shield','Manage unwanted player interactions.'},
 {'intel','intel','Remember players, encounters and useful information.'},
 {'chronicle','chronicle','Record your adventures and memorable milestones.'},
 {'alerts','mentions','Optional notifications and awareness features.'},
}
function U.BuildNativeRoot()
    if U.category or not Settings or not Settings.RegisterCanvasLayoutCategory then return U.category end
    local f=CreateFrame('Frame');f:SetSize(640,350)
    local title=f:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');title:SetPoint('TOPLEFT',24,-26);title:SetText('Olympus Warden')
    local text=f:CreateFontString(nil,'OVERLAY','GameFontHighlight');text:SetPoint('TOPLEFT',24,-72);text:SetWidth(580);text:SetText('Choose the Warden features you want. Disabled modules keep their saved data. Support and essential reporting are always included.')
    V.Button(f,'CommandWarden settings',24,-150,310,36,function() ns.Workspace.Open('settings') end)
    V.Button(f,'Choose modules',24,-202,310,36,function() ns.Workspace.Open('modules') end,'neutral')
    U.category=Settings.RegisterCanvasLayoutCategory(f,'Olympus Warden');Settings.RegisterAddOnCategory(U.category);U.nativeRoot=f;return U.category
end
function U.Build(parent)
    local p=CreateFrame('Frame',nil,parent);p:SetAllPoints();p:Hide();p.rows={}
    V.Text(p,'Choose the features you want to use',14,-12,1100,22,V.gold)
    V.Text(p,'Turning a module off stops its optional work. Your saved data and recording choices are kept.',14,-48,1100,14,V.muted)
    for n,s in ipairs(specs) do
        local id=s[1];local card=V.Panel(p,0,-84-(n-1)*88,1140,80,'dark');V.Icon(card,s[2],76,10,-2)
        V.Text(card,M.names[id],96,-10,580,20,V.gold);V.Text(card,s[3],97,-42,690,14,V.muted)
        local check=V.Check(card,'Use this module',815,-12,M.Enabled(id),function(value) M.Set(id,value);p:Refresh() end,300)
        local state=V.Text(card,'',818,-44,300,12,V.blue);state:SetHeight(26);p.rows[id]={check=check,state=state}
    end
    V.Text(p,'Always included: CommandWarden, local Signal Core and Relay support. Nothing is submitted automatically.',12,-540,1110,14,V.gold)
    p.notice=V.Text(p,'Recording and duels still need separate consent. Disabling keeps saved evidence. See Performance for runtime details.',12,-577,1110,13,V.muted);p.notice:SetHeight(36)
    V.Button(p,'Chat Only',0,-628,230,36,function() M.Preset(false);p:Refresh() end,'neutral')
    V.Button(p,'Full Suite',246,-628,230,36,function() M.Preset(true);p:Refresh() end,'neutral')
    p.resume=V.Button(p,'Resume legacy selections',492,-628,300,36,function() for _,id in ipairs(M.order) do if M.config.legacyHold and M.config.legacyHold[id] then M.Set(id,true) end end;p:Refresh() end,'neutral')
    V.Button(p,'Performance details',808,-628,332,36,function() ns.Workspace.Open('performance') end,'neutral')
    function p:Refresh()
        local held=false;for id,row in pairs(self.rows) do local legacy=M.config.legacyHold and M.config.legacyHold[id];held=held or legacy;row.check:SetChecked(M.Selected(id));row.state:SetText(M.State(id)..(legacy and ' • legacy pause kept' or M.records[id].runtimeDisabled and ' • starts after combat' or id=='shield' and not M.Enabled('chat') and ' • wording rule needs Chat' or '')) end
        self.resume:SetShown(held==true)
        self.notice:SetText(M.cleanupPending and 'Optional processing has stopped. Display cleanup and navigation changes apply after combat.' or held and 'Your old global pause is preserved. Resume legacy selections when ready; recording and duel consent are unchanged.' or 'Recording and duels still need separate consent. Disabling keeps saved evidence. See Performance for runtime details.')
    end
    function p:Activate() ns.Workspace.CommandTabs('modules');self:Refresh() end
    return p
end
function U.BuildPerformance(parent)
    local p=CreateFrame('Frame',nil,parent);p:SetAllPoints();p:Hide()
    local panel=V.Panel(p,0,0,1140,546,'dark');p.document=V.Document(panel,22,-20,1096,504)
    p.hint=V.Text(p,'Profiling stays off until you explicitly start it with /warden perf start.',4,-562,1120,14,V.muted);p.hint:SetHeight(40)
    V.Button(p,'Clear unused caches',0,-620,300,36,function() p.hint:SetText(M.ClearCaches());p:Refresh() end,'neutral')
    V.Button(p,'Print performance status',316,-620,300,36,function() ns.WardenPerformance.Report() end,'neutral')
    V.Button(p,'Support diagnostics',632,-620,300,36,function() local page=ns.Workspace.Destination('relay');if page then page:SetView('diagnostics') end end,'neutral')
    function p:Refresh()
        local blocks={{kind='heading',text='Running features'}, {kind='body',text='Module selection controls work, not recording consent. Enabled features can still be paused by their own controls or unavailable while Olympus access is pending.'}}
        for _,id in ipairs(M.order) do blocks[#blocks+1]={kind='body',text=M.names[id]..' • '..M.State(id)..(M.Selected(id) and ' • selected' or ' • excluded')} end
        blocks[#blocks+1]={kind='heading',text='Saved history loading'}
        local l=ns.ChronicleStore.LoadStatus();blocks[#blocks+1]={kind='body',text=l.loading and ('Validating '..l.chunks..' / '..l.totalChunks..' chunks. '..l.closedPumps..' worker calls with Warden closed; '..l.openPumps..' open. Chat reports each quarter. Client background throttling can slow progress.') or 'No validation in progress. Opening this page does not load an unused archive.'}
        blocks[#blocks+1]={kind='heading',text='What cleanup means'}
        blocks[#blocks+1]={kind='body',text='Clear unused caches leaves active dictionaries, protection thresholds and history views intact. Loaded source and SavedVariables stay in memory. No saved history, notes, imports or consent is deleted. Native memory savings depend on your configuration and retained data.'}
        self.document:SetBlocks(blocks)
    end
    function p:Activate() ns.Workspace.CommandTabs('performance');self:Refresh() end
    p:SetScript('OnUpdate',function(self,elapsed) self.tick=(self.tick or 0)+elapsed;if self.tick>1 then self.tick=0;self:Refresh() end end)
    return p
end
function U.Welcome()
    if not M.needsWelcome or not ns.Membership.Allowed() or InCombatLockdown and InCombatLockdown() then return end
    if U.welcome then U.welcome:Show();return end
    local f=V.Panel(UIParent,0,0,740,690,'dark','OlympusWardenModuleWelcome');f:ClearAllPoints();f:SetPoint('CENTER');f:SetFrameStrata('DIALOG');f:SetClampedToScreen(true);f:EnableMouse(true);T.RegisterWindow(f);U.welcome=f
    local selected={chat=true,shield=false,intel=false,chronicle=false,alerts=false};local checks={}
    V.Text(f,'Welcome to Olympus Warden',30,-24,675,25,V.gold)
    V.Text(f,'Make Warden Your Own',30,-69,675,22,V.gold)
    V.Text(f,'Choose the features you want to use. You can change your selection at any time.',30,-108,675,15,V.muted)
    for n,s in ipairs(specs) do
        local id=s[1];local y=-155-(n-1)*76;V.Icon(f,s[2],70,24,y+3)
        checks[id]=V.Check(f,M.names[id],112,y-3,selected[id],function(value) selected[id]=value end,580)
        V.Text(f,s[3],142,y-34,550,14,V.muted)
    end
    V.Text(f,'Always included: Warden Core, Relay support and essential Signal reporting.',30,-543,680,14,V.gold)
    V.Text(f,'History recording and duels remain opt-in. Choosing a module does not enable recording or sharing.',30,-579,680,14,V.muted)
    local function Preset(full) for _,id in ipairs(M.order) do selected[id]=full or id=='chat';checks[id]:SetChecked(selected[id]) end end
    V.Button(f,'Select All',28,-634,205,36,function() Preset(true) end,'neutral')
    V.Button(f,'Chat Only',247,-634,205,36,function() Preset(false) end,'neutral')
    V.Button(f,'Start Warden',466,-634,245,36,function()
        M.BeforeScopeChange();for _,id in ipairs(M.order) do M.config.selected[id]=selected[id]==true end
        M.config.onboardingDone=true;M.needsWelcome=false;ns.DB.welcomeSeen=1;ns.DB.updateSeen=ns.VERSION;M.dirty=true;M.Reconcile();M.ScopeChanged();f:Hide();ns.Workspace.ModulesChanged();ns.Workspace.Open(M.InitialRoute())
    end)
    f:Show()
end
