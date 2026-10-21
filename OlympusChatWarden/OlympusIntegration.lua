-- Prefer Olympus 1.2.4's supported native page. Retain the older launcher fallback.
local _, ns = ...
local I = {SOURCE_VERSION = "1.2.4", records = {}}
ns.OlympusIntegration = I
ns.OlympusLaunchers = I.records
local names = {"OlympusFrame", "OlympusFrameBasic", "OlympusFrameHD", "OlympusFrameHDBasic"}
local styles = {OlympusFrame = "old", OlympusFrameBasic = "old", OlympusFrameHD = "hd", OlympusFrameHDBasic = "hd"}
local manual, manualHost, hooked, queued, deferred
local watched = setmetatable({}, {__mode = "k"})
local points = {TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
    RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true}
local function SafeFrame(frame)
    local kind = type(frame)
    return (kind == "table" or kind == "userdata") and ns.Readable(frame)
        and type(frame.GetFrameLevel) == "function" and type(frame.GetFrameStrata) == "function"
        and not (frame.IsForbidden and frame:IsForbidden())
        and not (frame.IsProtected and frame:IsProtected())
end
local function Ready(frame, name)
    return SafeFrame(frame) and frame.style == styles[name] and type(frame.tabs) == "table"
        and ns.SafeNumber(frame.numTabs) and frame.numTabs > 0
end
local function Current(record)
    return _G[record.name] == record.host and Ready(record.host, record.name)
end
local function Enabled() return ns.DB ~= nil and ns.Membership and ns.Membership.Allowed() end
local function SyncOptions()
    if ns.SyncOptions then
        local ok, err = pcall(ns.SyncOptions)
        if not ok and geterrorhandler then pcall(geterrorhandler(), err) end
    end
end
local alertHosts = setmetatable({}, {__mode = "k"})
local function Badge(host)
    if not SafeFrame(host) then return end
    if not alertHosts[host] then
        local badge = ns.Theme.CaptureBadge(host)
        badge:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 2, -2)
        alertHosts[host] = badge
    end
    return alertHosts[host]
end
function I.HasNewCaptures()
    if ns.Activity then return ns.Activity.Unread()>0 end
    return ns.Review and ns.Review.Unread() > 0 or false
end
function I.UpdateAlerts()
    if not ns.DB then return end
    if ns.OlympusPanel then ns.OlympusPanel.Queue() end
    local active = Enabled() and ns.DB.captureAlerts ~= false and I.HasNewCaptures()
    -- This exact public button belongs to Olympus. No handler is replaced or
    -- invoked: clicking it continues to open Olympus normally.
    local minimap = _G.OlympusMinimapButton
    -- Olympus-owned minimap is not modified; Warden-owned launchers keep badges.
    for _, record in pairs(I.records) do Badge(record.button) end
    if manual then Badge(manual) end
    for host, badge in pairs(alertHosts) do
        badge:SetFrameLevel(host:GetFrameLevel() + 4)
        badge:SetShown(active and (host ~= minimap and host ~= _G.OlympusMinimapButton or SafeFrame(minimap)))
    end
end
function I.AcknowledgeAlerts()
    -- Opening a launcher does not read any individual message.
    I.UpdateAlerts()
end
function I.HasShownLauncher()
    if manual and manual:IsShown() then return true end
    for _, record in pairs(I.records) do if record.button:IsShown() then return true end end
    return false
end
function I.IsActive()
    if ns.OlympusConnection and ns.OlympusConnection.SurfaceReady() then return true end
    if not Enabled() then return false end
    if manual and SafeFrame(manualHost) then return true end
    for _, record in pairs(I.records) do if Current(record) then return true end end
    return false
end
local function Loaded()
    local api = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if type(api) == "function" then local ok, loaded = pcall(api, "Olympus"); if ok then return ns.Checked(loaded) end end
    for _, name in ipairs(names) do if _G[name] then return true end end
    return false
end
-- Only the approved public surface can be opened. A discovered native window
-- or minimap button does not authorize a fallback handler invocation.
function I.Available()
    return ns.OlympusConnection and ns.OlympusConnection.SurfaceReady()==true or false
end
function I.ValidIconTexture(value)
    local number=ns.SafeNumber(value)
    if number then return number>0 and number%1==0 and number<=2147483647 end
    if not ns.CanRead(value) or #value>512 or value:find('[%c|:]') or value:find('..',1,true) then return false end
    value=value:gsub('/','\\')
    -- Native getters can return internal handles such as "mask0". They are
    -- not file paths; SetTexture(handle) can assert in the client, outside Lua.
    return value:lower():match('^interface\\[^\\]+\\.+')~=nil
end
local function ReadIcon(icon)
    if not icon then return end
    for _,method in ipairs({'GetTextureFilePath','GetTexture','GetTextureFileID'}) do
        local value=ns.SafeCall(icon[method],icon)
        if I.ValidIconTexture(value) then return value end
    end
end
function I.IconTexture()
    local button=_G.OlympusMinimapButton
    -- Reading a public texture is safe even when the owning button is protected.
    -- Some releases expose it as a normal texture rather than .icon.
    if button and ns.Readable(button) and not (button.IsForbidden and button:IsForbidden()) then
        local regions={button.icon,button.Icon,ns.SafeCall(button.GetNormalTexture,button)}
        -- ipairs cannot traverse nil holes in the public fields above.
        for index=1,3 do
            local icon=regions[index]
            local texture=ReadIcon(icon)
            if type(texture)=='string' and texture~='' or ns.SafeNumber(texture) and texture>0 then return texture,'minimap' end
        end
        if button.GetRegions then
            local found={pcall(button.GetRegions,button)}
            if found[1] then for index=2,math.min(#found,18) do
                local region=found[index];local texture=ReadIcon(region)
                if type(texture)=='string' and texture:lower():find('olympus',1,true)
                    and texture:lower():find('logo',1,true) then return texture,'minimap region' end
            end end
        end
    end
    local api=C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local metadata=ns.SafeCall(api,'Olympus','IconTexture')
    if ns.CanRead(metadata) and metadata~='' then
        metadata=metadata:gsub('/','\\')
        if (metadata:find('\\',1,true) or metadata:match('%.%w+$')) and not metadata:lower():find('^interface\\') then
            metadata='Interface\\AddOns\\Olympus\\'..metadata
        end
        if I.ValidIconTexture(metadata) then return metadata,'metadata' end
    end
    -- Public Olympus.toc IconTexture; reference its installed asset, never copy it.
    -- https://github.com/dnl-gentile/olympus-addon/blob/main/Olympus/Olympus.toc
    if not button and not Loaded() then return nil,'Olympus unavailable' end
    return 'Interface\\AddOns\\Olympus\\media\\logo128.tga','installed logo128'
end
function I.ApplyIcon(texture)
    -- Keep a bundled fallback ready for an explicit native load failure.
    if not texture.ChatWardenFallback and texture.GetParent then
        local parent=texture:GetParent()
        if parent and parent.CreateTexture then
            local fallback=parent:CreateTexture(nil,'ARTWORK',nil,0)
            ns.Art.SetIcon(fallback,'olympus');fallback:SetAllPoints(texture)
            texture.ChatWardenFallback=fallback
        end
    end
    if texture.ChatWardenFallback then texture.ChatWardenFallback:Show() end
    -- Copy the loaded public minimap icon first. Metadata may point at a file
    -- absent from an older Olympus install, so never leave a failed load blank.
    local lastResult,lastReadBack,requested
    local function Load(path)
        if not I.ValidIconTexture(path) then lastResult='invalid texture reference';return false end
        if type(path)=='string' then path=path:gsub('/','\\') end
        if type(path)=='string' and path:lower():match('^interface\\addons\\olympus\\media\\logo%d+$') then path=path..'.tga' end
        requested=path
        if texture.ChatWardenOlympusTexture==path then
            lastResult='unchanged';lastReadBack=ReadIcon(texture);return true
        end
        local ok,loaded=pcall(texture.SetTexture,texture,path)
        lastResult=ok and (type(loaded)=='boolean' and tostring(loaded) or type(loaded)) or 'error'
        texture.ChatWardenOlympusTexture=nil
        if not ok or loaded==false then return false end
        texture.ChatWardenOlympusTexture=path
        lastReadBack=ReadIcon(texture)
        -- This client's custom-file getters can be absent/unreported. A void
        -- SetTexture result is not a failed load of the verified installed logo.
        -- Do not overwrite a valid lion texture with our fallback just because
        -- its read-back is unavailable.
        return true
    end
    local candidate,source=I.IconTexture()
    local loaded=candidate~=nil and Load(candidate) or false
    if not loaded and candidate~=nil then
        candidate='Interface\\AddOns\\Olympus\\media\\logo128.tga'
        loaded=Load(candidate)
    end
    local function SaveDiagnostic()
        if not ns.DB then return end
        if type(ns.DB.uiDiagnostics)~='table' then ns.DB.uiDiagnostics={} end
        ns.DB.uiDiagnostics.olympusIcon={source=I.IconSource,requested=ns.SafeString(requested,512) or ns.SafeNumber(requested),
            setResult=lastResult,readBack=ns.SafeString(lastReadBack,512) or ns.SafeNumber(lastReadBack) or 'unreported',
            fallback=not loaded,nativeFontFamilies=_G.ChatWardenFont14~=nil,addonVersion=ns.VERSION}
    end
    if not loaded then
        I.IconSource='bundled fallback'
        SaveDiagnostic()
        -- The primary texture may already have its portrait mask. Its atlas
        -- coordinates cannot be changed, even when the native load fails.
        -- The independent, unmasked fallback owns its own atlas crop.
        if texture.ChatWardenFallback then texture:Hide()
        elseif not texture.ChatWardenOlympusMasked then ns.Art.SetIcon(texture,'olympus');texture:Show() end
        return false
    end
    I.IconSource=source or 'installed logo'
    if texture.ChatWardenFallback then texture.ChatWardenFallback:Hide() end
    texture.ChatWardenArt=nil;texture.ChatWardenIconBox=nil
    -- SetTexCoord is forbidden after SetMask on this client. Configure the
    -- full image once, before attaching our mask, and retain it on refresh.
    if not texture.ChatWardenOlympusMasked then
        texture:SetTexCoord(0,1,0,1)
        if texture.SetMask then
            texture.ChatWardenOlympusMasked=pcall(texture.SetMask,texture,'Interface\\CharacterFrame\\TempPortraitAlphaMask')
        end
    end
    texture:Show();texture:SetVertexColor(1,1,1,1)
    if texture.SetDrawLayer then texture:SetDrawLayer('OVERLAY',1) end
    SaveDiagnostic()
    return true
end
function I.Open()
    -- Olympus owns its window focus, tabs and strata. The approved API is the
    -- sole opener; absence leaves local Warden history and /warden available.
    if not ns.OlympusConnection then return false,'Olympus is not ready.' end
    return ns.OlympusConnection.OpenSurface()
end
function I.Status()
    if ns.OlympusConnection and ns.OlympusConnection.modern then
        local c=ns.OlympusConnection
        return c.Reason()..(c.surfaceState=='surface-full' and ' Another addon is using the native page; /ocw opens the full workspace.' or '')
    end
    if I.IsActive() then return "Olympus tab ready. Open the Warden suite; right-click for CommandWarden settings." end
    if Loaded() then return "Open Olympus once to create the Warden tab. /ocw opens the Warden suite." end
    return "Olympus required. Use /ocw to open Warden while installing/updating it."
end
local function Queue()
    if queued then return end
    queued = true
    local function Run() queued = false; I.Refresh() end
    -- CreateFrame's secure hook runs before Olympus finishes its constructor.
    -- Defer attachment until the complete window and native border exist.
    if C_Timer and C_Timer.After then C_Timer.After(0, Run)
    else
        deferred = deferred or CreateFrame("Frame")
        deferred:SetScript("OnUpdate", function(self) self:SetScript("OnUpdate", nil); Run() end)
    end
end
local function Place(record)
    local root, button = record.host, record.button
    local level = root:GetFrameLevel()
    if SafeFrame(root.NineSlice) then level = math.max(level, root.NineSlice:GetFrameLevel()) end
    button:SetFrameLevel(level + 12)
    -- Below the 62px portrait, above the left column's bottom-up native tabs.
    button:ClearAllPoints(); button:SetPoint("TOPRIGHT", root, "TOPLEFT", 0, -76)
end
local function OpenHome()
    if ns.Workspace then ns.Workspace.Open('overview') else ns.OpenReview() end
end
function I.HookNativeTabRoot() return false end -- retained compatibility entry point; no Olympus UI hooks
local function MakeTab(root)
    local ok, button = pcall(CreateFrame, "CheckButton", nil, root, "RightSideTabTemplate")
    local native = ok and button and button.Icon
    if not native then
        if ok and button then button:Hide() end
        button = CreateFrame("CheckButton", nil, root)
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        button.Icon = button:CreateTexture(nil, "ARTWORK")
        button.Icon:SetSize(30, 30); button.Icon:SetPoint("CENTER")
    end
    button:Hide(); button:SetSize(32, 32)
    local art
    for _, region in ipairs({button:GetRegions()}) do
        if region.GetDrawLayer and region:GetDrawLayer() == "BORDER" then art = region; break end
    end
    if not art then
        art = button:CreateTexture(nil, "BORDER")
        art:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab"); art:SetSize(64, 64)
    end
    art:ClearAllPoints(); art:SetPoint("TOPRIGHT", 3, 11); art:SetTexCoord(1, 0, 0, 1)
    button.ChatWardenArt = art
    button.Icon:SetTexture(ns.Theme.Icon); button.Icon:SetTexCoord(0, 1, 0, 1)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local function Click(self, mouse)
        I.AcknowledgeAlerts()
        if mouse == "RightButton" then
            ns.Workspace.Open('settings')
        else OpenHome() end
        self:SetChecked(false) -- launcher, not an Olympus page selection
    end
    if native then button:HookScript("OnClick", Click) else button:SetScript("OnClick", Click) end
    ns.Theme.Tooltip(button, ns.NAME, "Left-click: CommandWarden. Right-click: CommandWarden settings. Open a recent activity entry to mark it read.")
    return button
end
function I.Install() end -- public RegisterSurface replaces private window discovery hooks
function I.Refresh()
    if not ns.DB then return end
    ns.Membership.Refresh()
    if InCombatLockdown and InCombatLockdown() then
        -- Defer native-host changes; do not display a minimap beside an old tab.
        if ns.BuildMinimap then ns.BuildMinimap() end
        SyncOptions()
        return
    end
    if ns.OlympusPanel then ns.OlympusPanel.Ensure() end
    local native=ns.OlympusConnection and ns.OlympusConnection.SurfaceReady()
    if native then for _,name in ipairs(names) do I.HookNativeTabRoot(_G[name]) end end
    I.Install()
    local primary = manual
    for _, record in pairs(I.records) do
        local active = not native and Enabled() and Current(record)
        if active then Place(record); if not primary or record.host:IsShown() then primary = record.button end end
        record.button:SetShown(active)
    end
    if manual then manual:SetShown(not native and Enabled() and SafeFrame(manualHost)) end
    ns.OlympusLauncher = primary
    I.UpdateAlerts()
    if ns.BuildMinimap then ns.BuildMinimap() end
    SyncOptions()
end
-- Discover already-constructed or late-created host windows after every
-- reload, including constructors using a locally cached CreateFrame function.
-- A missing/lazy host remains accessible through /ocw until attachment.
local discovery = CreateFrame("Frame")
local elapsed = 0
discovery:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.5 then return end
    elapsed = 0
    if not ns.DB then return end
    if ns.OlympusConnection then ns.OlympusConnection.Refresh() end
    if not (InCombatLockdown and InCombatLockdown()) and ns.OlympusPanel then ns.OlympusPanel.Ensure() end
    if SafeFrame(_G.OlympusMinimapButton) and not alertHosts[_G.OlympusMinimapButton] then I.UpdateAlerts() end
    if ns.OlympusConnection and ns.OlympusConnection.SurfaceReady() then
        if not (InCombatLockdown and InCombatLockdown()) then for _,name in ipairs(names) do I.HookNativeTabRoot(_G[name]) end end
        return
    end
    if not Enabled() or (InCombatLockdown and InCombatLockdown()) then return end
    if not alertHosts[_G.OlympusMinimapButton] then I.UpdateAlerts() end
    local refresh = not I.IsActive()
    for _, name in ipairs(names) do
        local root = _G[name]
        if Ready(root, name) then
            local record = I.records[root]
            if not record or not record.button:IsShown() then refresh = true end
        end
    end
    if refresh then I.Refresh() end
end)
local function OlympusOwned(frame)
    for _=1,32 do
        if not frame then return false end
        for _,name in ipairs(names) do if frame==_G[name] then return true end end
        if frame==_G.OlympusMinimapButton then return true end
        local name=frame.GetName and ns.SafeString(ns.SafeCall(frame.GetName,frame),128)
        if name and name:match('^Olympus') and not name:match('^OlympusChatWarden') and not name:match('^OlympusWarden') then return true end
        frame=frame.GetParent and ns.SafeCall(frame.GetParent,frame)
    end
    return frame~=nil -- refuse an unresolvable ancestry rather than modifying it
end
-- Legacy embedding remains available for other verified hosts, never Olympus.
function I.AttachLauncher(parent, anchor, point, relativePoint, x, y)
    if InCombatLockdown and InCombatLockdown() then return false, "Wait until combat ends." end
    if not SafeFrame(parent) or not SafeFrame(anchor) or not points[point] or not points[relativePoint]
        or not ns.SafeNumber(x) or not ns.SafeNumber(y) then return false, "Verified parent, anchor and placement required." end
    if OlympusOwned(parent) or OlympusOwned(anchor) then return false,'Olympus-owned UI is read-only. Use its approved surface or /warden.' end
    if manual and manualHost ~= parent then return false, "Detach the previous launcher first." end
    if not manual then
        manual = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate"); manual:Hide()
        manualHost = parent; manual:SetSize(110, 24); manual:SetText("Warden")
        manual:SetScript("OnClick", function() I.AcknowledgeAlerts(); OpenHome() end)
        ns.Theme.Tooltip(manual, ns.NAME, "Open CommandWarden. Settings: /ocw settings.")
    end
    manual:ClearAllPoints(); manual:SetPoint(point, anchor, relativePoint, x, y)
    manual:SetFrameLevel(math.max(parent:GetFrameLevel(), anchor:GetFrameLevel()) + 2)
    I.Refresh(); return true
end
function I.DetachLauncher()
    if InCombatLockdown and InCombatLockdown() then return false, "Wait until combat ends." end
    if manual then manual:Hide() end
    manual, manualHost = nil, nil; I.Refresh(); return true
end
OlympusChatWardenIntegration = {AttachLauncher = I.AttachLauncher, DetachLauncher = I.DetachLauncher}
