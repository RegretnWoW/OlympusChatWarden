-- Owned, lazy reader window. Does not reparent or mutate a Blizzard panel.
local _,ns=...
local W={};ns.AthenaJournalWindow=W
local V,T,J=ns.Art,ns.Theme,ns.AthenaJournal
local function Busy() return ns.Checked(ns.SafeCall(InCombatLockdown)) end
local function Allowed() return ns.DB and ns.Membership.Allowed() and ns.Athena.Enabled('chronicle') and ns.Membership.LocalHistoryAllowed() end
function W.Invalidate()
    if W.window then W.window.reader:Clear();W.window.reader.provider=nil;W.window.ownerMenu:SetEnabled(Allowed()) end
end
local function SavePlace()
    local p=W.window and W.window.reader
    if not p or not p.provider or p.provider.demo or not p.provider:Allowed() then return end
    if p.PersistReaderPlace then p:PersistReaderPlace() end
    local saved=p.destination=='journey' and {owner=p.owner,threadId=p.threadId,volumeId=p.volumeId,storyId=p.selected,offset=p.scroll:GetVerticalScroll(),anchor=p.document:GetReadingAnchor()} or p.journeyPosition
    if not saved or not saved.threadId then return end
    ns.DB.journalReadingPlaces=ns.DB.journalReadingPlaces or {};ns.DB.journalReadingPlaces[p.owner]=ns.Athena.Copy(saved)
    -- Presentation preferences only. Removing an old reading position never
    -- changes a character's retained history or protected bookmarks.
    local keys={};for key in pairs(ns.DB.journalReadingPlaces) do if key~=p.owner then keys[#keys+1]=key end end;table.sort(keys)
    while #keys>15 do ns.DB.journalReadingPlaces[table.remove(keys,1)]=nil end
end
W.SavePlace=SavePlace
function W.Close() W.pending=nil;if W.window then SavePlace();W.window:Hide();if W.window.ui2Host then if not ns.UI2.Back() then ns.UI2.Open({page='overview'}) end elseif W.window.workspaceEmbedded then ns.Workspace.Open('overview') end end end
function W.Fit()
    local f=W.window;if not f or Busy() then return end
    if f.ui2Host then ns.UI2.LayoutJournal();return end
    if f.workspaceEmbedded then
        f:SetScale(1);local width,height=f:GetWidth(),f:GetHeight()
        f.reader:ClearAllPoints();f.reader:SetPoint('TOPLEFT',0,-48);f.reader:SetSize(width,height-48);f.reader:Layout(width,height-48)
        f.ownerMenu:ClearAllPoints();f.ownerMenu:SetPoint('TOPLEFT',210,-5);f.ownerMenu:SetWidth(250)
        return
    end
    local width=math.max(700,math.min(1800,f:GetWidth()));local height=math.max(440,math.min(1100,f:GetHeight()))
    f:SetSize(width,height);T.FitWindow(f,width,height)
    f.reader:ClearAllPoints();f.reader:SetPoint('TOPLEFT',16,-70);f.reader:SetSize(width-32,height-86);f.reader:Layout(width-32,height-86)
    f.openWarden:ClearAllPoints();f.openWarden:SetPoint('TOPRIGHT',-54,-20);f.openWarden:SetWidth(width<900 and 160 or 210)
    if f.ownerMenu then f.ownerMenu:ClearAllPoints();f.ownerMenu:SetPoint('TOPLEFT',190,-20);f.ownerMenu:SetWidth(math.max(150,math.min(250,width-450))) end
end
local function Ensure()
    if W.window then return W.window end
    -- UI2 supplies a new host; the illustrated reader and page-turn mechanics
    -- remain the same. The retired standalone window is never constructed.
    if ns.UI2 and ns.UI2.CreateJournalHost then W.window=ns.UI2.CreateJournalHost();return W.window end
    local f=V.Panel(UIParent,0,0,1120,800,'dark','OlympusWardenAthenaJournal');W.window=f
    -- The illustrated volume provides the surface; controls sit above it like
    -- bronze bookmarks, without another rectangular window border around it.
    if f.ArtFrame and f.ArtFrame.SetShown then f.ArtFrame:SetShown(false) end
    if f.ArtBacking and f.ArtBacking.Hide then f.ArtBacking:Hide() end
    f:ClearAllPoints();f:SetPoint('CENTER');f.ChatWardenOwned=true;f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(true)
    if f.SetResizable then f:SetResizable(true) end
    if f.SetResizeBounds then f:SetResizeBounds(700,440,1800,1100) end
    f.crest=V.Icon(f,'chronicle',54,18,-12)
    f.title=V.Text(f,'Athena',84,-19,140,28,V.gold)
    f.syntheticLabel=V.Text(f,'SYNTHETIC PREVIEW',84,-49,180,10,V.muted);f.syntheticLabel:Hide()
    f.openWarden=V.Button(f,'Open Fireside',0,0,230,34,function() if Busy() then ns.Print('Open Fireside after combat.');return end;W.Close();ns.Workspace.Open(ns.Modules.InitialRoute()) end,'neutral')
    f.close=V.Button(f,'X',0,0,30,30,W.Close,'danger');f.close:ClearAllPoints();f.close:SetPoint('TOPRIGHT',-16,-24)
    f.ownerChoices={{false,'This character'}}
    f.ownerMenu=V.Dropdown(f,238,-22,250,f.ownerChoices,function() return f.owner~=ns.Chronicle.Owner() and f.owner or false end,function(owner) W.Open({owner=owner or ns.Chronicle.Owner()}) end,{maxRows=8})
    f.drag=CreateFrame('Frame',nil,f);f.drag:SetPoint('TOPLEFT',0,0);f.drag:SetSize(224,74);f.drag:EnableMouse(true);f.drag:RegisterForDrag('LeftButton')
    f.drag:SetScript('OnDragStart',function() if not Busy() then f:StartMoving() end end);f.drag:SetScript('OnDragStop',function() f:StopMovingOrSizing() end)
    f.reader=ns.AthenaJournalUI.Build(f,f)
    f.resize=V.Button(f,'↘',0,0,26,22,function() end,'neutral');f.resize:ClearAllPoints();f.resize:SetPoint('BOTTOMRIGHT',-2,1)
    f.resize:SetScript('OnMouseDown',function(_,button) if button=='LeftButton' and not Busy() then f:StartSizing('BOTTOMRIGHT') end end)
    f.resize:SetScript('OnMouseUp',function() f:StopMovingOrSizing();W.Fit() end)
    T.Tooltip(f.resize,'Resize Athena','Drag this corner outside combat. The reader fits smaller screens automatically.')
    f:SetScript('OnSizeChanged',function() if W.layingOut then return end;W.layingOut=true;W.Fit();W.layingOut=nil end)
    f:HookScript('OnHide',function() SavePlace();f:StopMovingOrSizing() end)
    f:HookScript('OnShow',function() f.reader:Refresh() end)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]='OlympusWardenAthenaJournal' end
    T.RegisterWindow(f);W.layingOut=true;W.Fit();W.layingOut=nil
    f.reader:Show();return f
end
local function Owner(owner)
    local current=ns.Chronicle.Owner();local c=owner and ns.ChronicleStore.db and ns.ChronicleStore.db.characters[owner]
    if owner==current then return current end
    return c and ns.ChronicleStore.Text(owner,256) and owner or current
end
function W.Open(options)
    options=type(options)=='table' and options or {}
    if not ns.Membership.Allowed() then if ns.UI2 then ns.UI2.ShowVerification() end;return false,'VERIFICATION_REQUIRED' end
    if not Allowed() then W.Invalidate();ns.Print('Enable ChronicleWarden and permitted local history to open Athena.');return false end
    if Busy() then W.pending={owner=options.owner,storyId=options.storyId,activityRef=options.activityRef};ns.Print('Athena will open after combat.');return false,'COMBAT_WAIT' end
    local f=Ensure();local owner=Owner(options.owner or f.owner)
    if f.owner~=owner then f.reader:Clear();f.reader.provider=nil end
    f.owner=owner;f.reader.requestedStory=options.storyId or options.activityRef
    f.ownerMenu:SetEnabled(true)
    for i=#f.ownerChoices,2,-1 do f.ownerChoices[i]=nil end
    for key in pairs(ns.ChronicleStore.db and ns.ChronicleStore.db.characters or {}) do if key~=ns.Chronicle.Owner() then f.ownerChoices[#f.ownerChoices+1]={key,ns.WardenUI.OwnerName(key)} end end
    f.ownerMenu:Refresh()
    W.pending=nil;W.Fit()
    if ns.Workspace.HostJourney then ns.Workspace.HostJourney(f) elseif ns.Workspace.window then ns.Workspace.window:Hide() end
    f:Show();f.reader:Refresh()
    if not options.storyId and not options.activityRef then
        local saved=ns.DB.journalReadingPlaces and ns.DB.journalReadingPlaces[owner]
        if saved and saved.owner==owner then f.reader.journeyPosition=ns.Athena.Copy(saved) end
        local place=ns.DB.journalReaderPlacesV2 and ns.DB.journalReaderPlacesV2[owner]
        if place then f.reader.openJourneyPending=nil;f.reader.readerRestore=ns.Athena.Copy(place);f.reader:Refresh()
        elseif f.reader.rendered then f.reader:SetDestination('journey') else f.reader.openJourneyPending=true end
    end
    if f.reader.requestedStory and f.reader.library then
        local s=f.reader.library.byID[f.reader.requestedStory]
        if not s then for _,v in ipairs(f.reader.library.stories) do if v.sourceActivityRefs[1]==f.reader.requestedStory then s=v;break end end end
        if s then f.reader.requestedStory=nil;f.reader:OpenStory(s.storyId)
        elseif f.reader.library.index and f.reader.job and f.reader.job.done then f.reader:OpenStory(f.reader.requestedStory) end
    end
    T.FocusWindow(f);return true,f
end
function W.Toggle()
    if W.pending or W.window and W.window:IsShown() then W.Close();return true end
    return W.Open()
end
function W.OpenSource(ref)
    local p=W.window and W.window.reader;if not p then return false end
    p.evidenceRef=ref;p:OpenEvidence();return p.pendingSource~=nil
end
-- A distinct alias only when no installed addon already owns /athena.
function W.RegisterSlash()
    if W.slashChecked then return end;W.slashChecked=true
    for key,value in pairs(_G) do if type(key)=='string' and key:match('^SLASH_') and ns.CanRead(value) and value:lower()=='/athena' then W.slashConflict=true;return end end
    SLASH_OLYMPUSWARDENATHENA1='/athena';SlashCmdList.OLYMPUSWARDENATHENA=function() W.Open() end
end
local events=CreateFrame('Frame')
for _,event in ipairs({'PLAYER_LOGIN','PLAYER_REGEN_ENABLED','UI_SCALE_CHANGED','DISPLAY_SIZE_CHANGED'}) do events:RegisterEvent(event) end
events:SetScript('OnEvent',function(_,event)
    if event=='PLAYER_LOGIN' then W.RegisterSlash() end
    if not Allowed() then W.pending=nil;W.Invalidate();return end
    if event=='PLAYER_REGEN_ENABLED' and W.pending then W.Open(W.pending) elseif W.window and not Busy() then W.Fit() end
end)
local oldClear=ns.WardenUI.Clear
ns.WardenUI.Clear=function(...) W.Invalidate();return oldClear(...) end
local oldCaches=ns.Modules.ClearHistoryCaches
ns.Modules.ClearHistoryCaches=function(...) W.Invalidate();return oldCaches(...) end
