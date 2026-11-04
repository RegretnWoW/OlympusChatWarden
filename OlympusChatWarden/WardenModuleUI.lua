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
    local title=f:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');title:SetPoint('TOPLEFT',24,-26);title:SetText('Fireside')
    local text=f:CreateFontString(nil,'OVERLAY','GameFontHighlight');text:SetPoint('TOPLEFT',24,-72);text:SetWidth(580);text:SetText('All Fireside tools are available together. Recording and sharing remain your choice.')
    V.Button(f,'Fireside settings',24,-150,310,36,function() ns.Workspace.Open('settings') end)
    V.Button(f,'Recording and privacy',24,-202,310,36,function() ns.UI2.Open({page='settings',category='privacy'}) end,'neutral')
    U.category=Settings.RegisterCanvasLayoutCategory(f,'Fireside');Settings.RegisterAddOnCategory(U.category);U.nativeRoot=f;return U.category
end
function U.Build(parent)
    local p=CreateFrame('Frame',nil,parent);p:SetAllPoints();p:Hide()
    V.Text(p,'Your Fireside tools work together',14,-12,1100,22,V.gold)
    V.Text(p,'All tools stay available. Recording, private-chat capture and sharing still follow your choices.',14,-48,1100,14,V.muted)
    for n,s in ipairs(specs)do
        local card=V.Panel(p,0,-84-(n-1)*88,1140,80,'dark');V.Icon(card,s[2],76,10,-2)
        V.Text(card,M.names[s[1]],96,-10,580,20,V.gold);V.Text(card,s[3],97,-42,900,14,V.muted)
    end
    V.Button(p,'Recording and privacy',0,-565,320,36,function()ns.UI2.Open({page='settings',category='privacy'})end,'neutral')
    function p:Refresh()end
    function p:Activate()self:Refresh()end
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
        local blocks={{kind='heading',text='Running features'}, {kind='body',text='All tools are available together. Privacy choices, combat and client capabilities can still limit individual operations.'}}
        for _,id in ipairs(M.order) do blocks[#blocks+1]={kind='body',text=M.names[id]..' • '..M.State(id)..' • included'} end
        blocks[#blocks+1]={kind='heading',text='Saved history loading'}
        local l=ns.ChronicleStore.LoadStatus();blocks[#blocks+1]={kind='body',text=l.loading and ('Validating '..l.chunks..' / '..l.totalChunks..' chunks. '..l.closedPumps..' worker calls with Fireside closed; '..l.openPumps..' open. Chat reports each quarter. Client background throttling can slow progress.') or 'No validation in progress. Opening this page does not load an unused archive.'}
        blocks[#blocks+1]={kind='heading',text='What cleanup means'}
        if ns.Athena and ns.Athena.Knowledge then
            local K=ns.Athena.Knowledge;local ctx=K.Context('command',ns.Chronicle.Owner(),{purpose='DIAGNOSTICS'});local reference=ctx and K.Coverage('QUEST',ctx)
            local version=K.Version()
            blocks[#blocks+1]={kind='heading',text='World & Quest references'}
            blocks[#blocks+1]={text=version.version..' • '..(reference and reference.knownSourceIDs or version.knownSourceIDs)..' known source quests. Coverage is partial; reference data is separate from personal history.'}
        end
        blocks[#blocks+1]={kind='body',text='Clear unused caches leaves active dictionaries, protection thresholds and history views intact. Loaded source and SavedVariables stay in memory. No saved history, notes, imports or consent is deleted. Native memory savings depend on your configuration and retained data.'}
        self.document:SetBlocks(blocks)
    end
    function p:Activate() ns.Workspace.CommandTabs('performance');self:Refresh() end
    p:SetScript('OnUpdate',function(self,elapsed) self.tick=(self.tick or 0)+elapsed;if self.tick>1 then self.tick=0;self:Refresh() end end)
    return p
end
function U.Welcome()return false end -- First deliberate open now owns welcome/setup.
