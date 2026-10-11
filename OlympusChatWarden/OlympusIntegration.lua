-- Olympus 1.2.1's UI.lua creates these named windows on first open. Its UI
-- namespace is private; attach our own launcher without changing its tab list.
local _, ns = ...
local I = {SOURCE_VERSION = "1.2.1", records = {}}
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
    return ns.Review and ns.Review.Unread() > 0 or false
end
function I.UpdateAlerts()
    if not ns.DB then return end
    local active = Enabled() and ns.DB.captureAlerts ~= false and I.HasNewCaptures()
    -- This exact public button belongs to Olympus. No handler is replaced or
    -- invoked: clicking it continues to open Olympus normally.
    local minimap = _G.OlympusMinimapButton
    if SafeFrame(minimap) then Badge(minimap) end
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
function I.Status()
    if I.IsActive() then return "Olympus tab ready. Left-click for Review; right-click for Settings." end
    if Loaded() then return "Open Olympus once to create the ChatWarden tab. /ocw also opens setup." end
    return "Olympus required. Use /ocw for setup while installing/updating it."
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
            if SlashCmdList.OLYMPUSCHATWARDEN then SlashCmdList.OLYMPUSCHATWARDEN("options") end
        else ns.OpenReview() end
        self:SetChecked(false) -- launcher, not an Olympus page selection
    end
    if native then button:HookScript("OnClick", Click) else button:SetScript("OnClick", Click) end
    ns.Theme.Tooltip(button, ns.NAME, "Left-click: Review messages. Right-click: ChatWarden settings. Select messages in Review to dismiss their alerts.")
    return button
end
function I.Install()
    if not Enabled() or hooked or type(hooksecurefunc) ~= "function" then return end
    local ok = pcall(hooksecurefunc, "CreateFrame", function(kind, name)
        if Enabled() and ns.CanRead(kind) and kind:lower() == "frame" and ns.CanRead(name) and styles[name] then Queue() end
    end)
    hooked = ok
end
function I.Refresh()
    if not ns.DB then return end
    ns.Membership.Refresh()
    if InCombatLockdown and InCombatLockdown() then
        -- Defer native-host changes; do not display a minimap beside an old tab.
        if ns.BuildMinimap then ns.BuildMinimap() end
        SyncOptions()
        return
    end
    I.Install()
    if Enabled() then
        for _, name in ipairs(names) do
            local root = _G[name]
            if SafeFrame(root) and not watched[root] then
                watched[root] = true
                -- Watch even an unfinished constructor. Readiness may arrive
                -- after the CreateFrame hook's first deferred callback.
                root:HookScript("OnShow", Queue); root:HookScript("OnSizeChanged", Queue)
            end
            if Ready(root, name) and not I.records[root] then
                local record = {host = root, name = name, button = MakeTab(root)}
                I.records[root] = record
                -- Keep Olympus's original visibility/resize scripts intact.
            end
        end
    end
    local primary = manual
    for _, record in pairs(I.records) do
        local active = Enabled() and Current(record)
        if active then Place(record); if not primary or record.host:IsShown() then primary = record.button end end
        record.button:SetShown(active)
    end
    if manual then manual:SetShown(Enabled() and SafeFrame(manualHost)) end
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
-- Retain the narrow handoff for other verified hosts. The supplied Olympus
-- windows are now detected automatically; ordinary users need no adapter.
function I.AttachLauncher(parent, anchor, point, relativePoint, x, y)
    if InCombatLockdown and InCombatLockdown() then return false, "Wait until combat ends." end
    if not SafeFrame(parent) or not SafeFrame(anchor) or not points[point] or not points[relativePoint]
        or not ns.SafeNumber(x) or not ns.SafeNumber(y) then return false, "Verified parent, anchor and placement required." end
    if manual and manualHost ~= parent then return false, "Detach the previous launcher first." end
    if not manual then
        manual = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate"); manual:Hide()
        manualHost = parent; manual:SetSize(110, 24); manual:SetText("ChatWarden")
        manual:SetScript("OnClick", function() I.AcknowledgeAlerts(); ns.OpenReview() end)
        ns.Theme.Tooltip(manual, ns.NAME, "Open Review messages. Settings: /ocw.")
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
