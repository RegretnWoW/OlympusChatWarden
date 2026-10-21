-- Optional native-UI entry points. No replacement of native secure handlers.
local _,ns=...
local L={};ns.WardenLaunchers=L
local S=ns.ChronicleStore
local worker=CreateFrame('Frame');local pending
local icon='Interface\\AddOns\\OlympusChatWarden\\Media\\Warden\\WardenMicro.tga'
local function Busy() return ns.Checked(ns.SafeCall(InCombatLockdown)) end
local function Guid(unit) return S.GUID(ns.SafeCall(UnitGUID,unit)) end
local function Access() return ns.DB and ns.Membership.Allowed() end
function L.ToggleMain()
    local window=ns.Workspace.window
    if window and window:IsShown() then window:Hide();return true end
    if Busy() then ns.Print('Open Warden after combat.');return false end
    if not Access() then ns.Print(ns.Membership.Status());return false end
    return ns.Workspace.Open('overview')
end
local function InspectUnitToken()
    local f=InspectFrame
    if not f or f.IsForbidden and f:IsForbidden() then return end
    return ns.SafeString(type(f.GetInspectUnit)=='function' and ns.SafeCall(f.GetInspectUnit,f) or f.unit,32)
end
function L.CanInspect(unit)
    local guid=Guid(unit)
    return Access() and ns.Modules.Enabled('intel') and not Busy() and guid~=nil and guid~=Guid('player')
        and ns.Checked(ns.SafeCall(UnitIsPlayer,unit)) and ns.Checked(ns.SafeCall(UnitIsVisible,unit))
        and (type(CanInspect)~='function' or ns.Checked(ns.SafeCall(CanInspect,unit,true)))
end
local function Stop() pending=nil;worker:SetScript('OnUpdate',nil) end
local function Pump()
    local p=pending;if not p then return end
    if not Access() or not ns.Modules.Enabled('intel') or ns.Chronicle.Owner()~=p.owner or Guid(p.unit)~=p.guid then Stop();return end
    if S.loading or S.blocked then p.waitedForHistory=true;return end
    if p.waitedForHistory then p.started=ns.SafeNumber(ns.SafeCall(GetTime)) or p.started;p.waitedForHistory=nil end
    if (ns.SafeNumber(ns.SafeCall(GetTime)) or p.started)-p.started>10 then
        Stop();ns.Print('No recorded inspection response arrived. Check range and recording status, then inspect again.');return
    end
    if Busy() then return end
    if ns.Chronicle.Profile(p.guid) then
        Stop();ns.WardenUI.Navigate('player',p.owner,p.guid)
    end
end
function L.OpenIntel(unit,inspect)
    if not Access() then return false end
    if not ns.Modules.Enabled('intel') then ns.Workspace.Open('modules');return false end
    if Busy() then ns.Print('Open player intelligence after combat.');return false end
    local guid=Guid(unit);local owner=ns.Chronicle.Owner()
    if not guid or guid==Guid('player') then ns.Print('Choose an available player other than yourself.');return false end
    Stop()
    if inspect then
        if not L.CanInspect(unit) then ns.Print('This player is not available for a normal inspection.');return false end
        if type(InspectUnit)~='function' and type(InspectFrame_Show)~='function' then
            local load=C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
            if type(load)=='function' then pcall(load,'Blizzard_InspectUI') end
        end
        local fn=type(InspectUnit)=='function' and InspectUnit or InspectFrame_Show
        if type(fn)~='function' then ns.Print('The native inspection window is unavailable on this client.');return false end
        local ok=pcall(fn,unit)
        if not ok or Guid(unit)~=guid then ns.Print('The native inspection did not open for this player.');return false end
    end
    if not S.loading and not S.blocked and ns.Chronicle.Profile(guid) then ns.WardenUI.Navigate('player',owner,guid);return true end
    if ns.Chronicle.InWorld() then
        pending={guid=guid,owner=owner,unit=unit,started=ns.SafeNumber(ns.SafeCall(GetTime)) or 0}
        worker:SetScript('OnUpdate',Pump);worker:Show()
        ns.Print('Inspection requested. IntelWarden will open when this player’s recorded response arrives.')
    else ns.Print('Native inspection opened. '..ns.Chronicle.Status()..' A new dossier requires active recording.') end
    return true
end
local function Tooltip(button,title,text)
    button:SetScript('OnEnter',function(self)
        if GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText(title);GameTooltip:AddLine(text,.8,.8,.8,true);GameTooltip:Show() end
    end)
    button:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
end
local function PlaceMinimap(button)
    local angle=math.rad((ns.SafeNumber(ns.DB.wardenMinimapAngle) or 45)%360)
    -- Follow the actual map size; a fixed radius puts the button inside larger maps.
    local rx=(ns.SafeNumber(Minimap:GetWidth()) or 140)/2+14
    local ry=(ns.SafeNumber(Minimap:GetHeight()) or 140)/2+14
    button:ClearAllPoints();button:SetPoint('CENTER',Minimap,'CENTER',math.cos(angle)*rx,math.sin(angle)*ry)
end
local function MakeMinimap()
    local b=CreateFrame('Button',nil,Minimap);b:SetSize(32,32);b:SetFrameLevel(Minimap:GetFrameLevel()+6)
    local back=b:CreateTexture(nil,'BACKGROUND');back:SetSize(26,26);back:SetPoint('CENTER',0,0);back:SetTexture('Interface\\Minimap\\UI-Minimap-Background')
    local image=b:CreateTexture(nil,'ARTWORK');image:SetSize(23,23);image:SetPoint('CENTER',0,0);image:SetTexture(icon);b.icon=image
    -- This stock ring has centered artwork, unlike the padded legacy tracking sheet.
    local border=b:CreateTexture(nil,'OVERLAY');border:SetSize(34,34);border:SetPoint('CENTER',0,0);border:SetTexture('Interface\\Common\\RingBorder');b.border=border
    b:SetHighlightTexture('Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight','ADD');b:RegisterForClicks('LeftButtonUp','RightButtonUp');b:RegisterForDrag('LeftButton')
    b:SetScript('OnClick',function(_,mouse)
        if Busy() then ns.Print('Open Warden after combat.');elseif Access() then ns.Workspace.Open(mouse=='RightButton' and 'settings' or 'overview') else ns.Print(ns.Membership.Status()) end
    end)
    b:SetScript('OnDragStart',function()
        if Busy() or type(GetCursorPosition)~='function' then return end
        b:SetScript('OnUpdate',function()
            if Busy() then b:SetScript('OnUpdate',nil);return end
            local x,y=ns.WardenBrand.Values(GetCursorPosition);local cx,cy=ns.WardenBrand.Values(Minimap.GetCenter,Minimap)
            local scale=ns.SafeNumber(ns.SafeCall(Minimap.GetEffectiveScale,Minimap))
            if not ns.SafeNumber(x) or not ns.SafeNumber(y) or not ns.SafeNumber(cx) or not ns.SafeNumber(cy) or not scale or scale<=0 then return end
            local a=math.atan2(y/scale-cy,x/scale-cx);ns.DB.wardenMinimapAngle=math.deg(a)%360;PlaceMinimap(b)
        end)
    end)
    b:SetScript('OnDragStop',function() b:SetScript('OnUpdate',nil) end)
    b:SetScript('OnHide',function() b:SetScript('OnUpdate',nil) end)
    Minimap:HookScript('OnSizeChanged',function() if ns.DB and not Busy() then PlaceMinimap(b) end end)
    Tooltip(b,'Olympus Warden','Left-click: CommandWarden. Right-click: Settings. Drag to move around the minimap.')
    return b
end
local function ShopLayout(button,shop)
    local side=math.max(8,math.min(22,shop:GetWidth()-10,shop:GetHeight()-12))
    button.icon:SetSize(side,side);button.icon:ClearAllPoints();button.icon:SetPoint('CENTER',0,0)
end
local function InspectTabAnchor(button,host)
    local tabs=host.ModeTabs;local last
    for _,tab in ipairs(tabs and tabs.Tabs or {}) do if tab:IsShown() then last=tab end end
    button:ClearAllPoints()
    if last then button:SetPoint('TOPLEFT',last,'BOTTOMLEFT',0,0)
    elseif tabs then button:SetPoint('TOPLEFT',tabs,'TOPLEFT',0,0)
    else button:SetPoint('TOPLEFT',host,'TOPRIGHT',0,-30) end
end
function L.Refresh()
    if not ns.DB then return end
    if Busy() then L.deferred=true;return end
    L.deferred=nil
    local shop=StoreMicroButton or ShopMicroButton
    if ns.DB.shopLauncher and shop and not (shop.IsForbidden and shop:IsForbidden()) then
        if not L.shop or L.shop:GetParent()~=shop then
            if L.shop then L.shop:Hide() end
            local b=CreateFrame('Button',nil,shop);b:SetAllPoints(shop);b:SetFrameLevel(shop:GetFrameLevel()+5);b:RegisterForClicks('LeftButtonUp')
            local back=b:CreateTexture(nil,'BACKGROUND');back:SetPoint('CENTER',0,0);back:SetAtlas('UI-HUD-MicroMenu-ButtonBG-Up',true);b.background=back
            local down=b:CreateTexture(nil,'BACKGROUND');down:SetPoint('CENTER',0,0);down:SetAtlas('UI-HUD-MicroMenu-ButtonBG-Down',true);down:Hide();b.pushedBackground=down
            local image=b:CreateTexture(nil,'ARTWORK');image:SetTexture(icon);b.icon=image;ShopLayout(b,shop)
            b:SetScript('OnMouseDown',function(_,mouse) if mouse=='LeftButton' then back:Hide();down:Show() end end)
            local function Release() down:Hide();back:Show() end
            b:SetScript('OnMouseUp',Release);b:SetScript('OnHide',Release)
            shop:HookScript('OnSizeChanged',function() if not Busy() then ShopLayout(b,shop) end end)
            b:SetHighlightTexture('Interface\\Buttons\\UI-Common-MouseHilight','ADD')
            b:SetScript('OnClick',L.ToggleMain)
            Tooltip(b,'Olympus Warden','Toggle Warden open or closed. Disable the shop-button shortcut in CommandWarden > Settings to restore the shop button.')
            L.shop=b
        end
        ShopLayout(L.shop,shop);L.shop:Show()
    elseif L.shop then L.shop:Hide() end
    if ns.DB.wardenMinimap and Minimap and not (Minimap.IsForbidden and Minimap:IsForbidden()) then
        if not L.minimap then L.minimap=MakeMinimap() end
        PlaceMinimap(L.minimap);L.minimap:Show()
    elseif L.minimap then L.minimap:Hide() end
    local host=InspectFrame
    if ns.DB.inspectLauncher and host and not (host.IsForbidden and host:IsForbidden()) then
        if not L.inspect or L.inspect:GetParent()~=host then
            if L.inspect then L.inspect:Hide() end
            local b=CreateFrame('Frame',nil,host,'LargeSideTabButtonTemplate');b:EnableMouse(true)
            b.Icon:SetTexture('Interface\\AddOns\\OlympusChatWarden\\Media\\Warden\\IntelWarden.tga');b.Icon:SetSize(38,38);b.icon=b.Icon;b:SetChecked(false)
            b:SetCustomOnMouseUpHandler(function(self,mouse,upInside)
                if mouse~='LeftButton' or not upInside or not self.wardenEnabled then return end
                local unit=InspectUnitToken()
                if not unit or Guid(unit)~=self.guid then ns.Print('The inspected player changed. Reopen the correct player’s inspection.');return end
                L.OpenIntel(unit,false)
            end)
            Tooltip(b,'Open in IntelWarden','Open this exact inspected player’s saved dossier. Recording is required to save a new player; opening a dossier never enables it.')
            host:HookScript('OnShow',L.Refresh)
            if type(host.InitializeModeTabLayout)=='function' then hooksecurefunc(host,'InitializeModeTabLayout',L.Refresh) end
            L.inspect=b
        end
        L.inspect.guid=Guid(InspectUnitToken());L.inspect.wardenEnabled=Access() and ns.Modules.Enabled('intel') and L.inspect.guid~=nil and L.inspect.guid~=Guid('player')
        L.inspect.Icon:SetDesaturated(not L.inspect.wardenEnabled);InspectTabAnchor(L.inspect,host);L.inspect:Show()
    elseif L.inspect then L.inspect:Hide() end
end
function L.Set(key,value)
    if not ns.DB or (key~='shopLauncher' and key~='inspectLauncher' and key~='wardenMinimap') or type(value)~='boolean' then return false end
    ns.DB[key]=value;L.Refresh();return true
end
local events=CreateFrame('Frame')
for _,event in ipairs({'ADDON_LOADED','PLAYER_LOGIN','PLAYER_ENTERING_WORLD','PLAYER_REGEN_ENABLED','INSPECT_READY','PLAYER_TARGET_CHANGED','DISPLAY_SIZE_CHANGED','UI_SCALE_CHANGED'}) do events:RegisterEvent(event) end
events:SetScript('OnEvent',function() L.Refresh();if pending then Pump() end end)
local changed=ns.Workspace.ModulesChanged
ns.Workspace.ModulesChanged=function(...) local result=changed(...);L.Refresh();return result end
