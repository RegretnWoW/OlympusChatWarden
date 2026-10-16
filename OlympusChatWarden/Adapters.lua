local _, ns = ...
local states = setmetatable({}, {__mode = "k"})
local installedFrames = setmetatable({}, {__mode = "k"})
local buttons = setmetatable({}, {__mode = "k"})
local chatInstalled, scanQueued, resetPending = false, false, false
local nextReviewKey, nextChatRevealKey = 0, 0

local function PreviewState(region, action)
    local label = ns.DemoStatuses and ns.DemoStatuses[region]
    if label then
        label:SetText(({Unchanged = "Visible - no active match", Warning = "Warning - text remains visible",
            Redacted = "Redacted words - Ctrl + left-click to reveal", Replaced = "Replaced wording - shown in gray", Hidden = "Hidden - original is in Review messages",
            Revealed = "Revealed - Ctrl + left-click to redact", Disabled = "Visible - filtering is disabled for this area",
            Unavailable = "Text unavailable"})[action] or action)
    end
end

local function RecordUI(region, state, matches, displayedAction)
    if not ns.Review or #matches == 0
        or (region.IsVisible and not region:IsVisible()) or not state.source then return end
    local source = state.source()
    if not source then return end
    local signature = tostring(ns.Interaction) .. ":" .. tostring(ns.PolicyRevision)
        .. ":" .. (source.kind or "ui") .. ":" .. tostring(source.questID or "")
        .. ":" .. (source.questTitle or "") .. ":" .. (source.npc or "")
    if state.logRaw == state.raw and state.logSignature == signature and ns.Review.Get(state.logID) then return state.logID end
    nextReviewKey = nextReviewKey + 1
    local id = ns.Review.Add(state.raw, matches, source, "ui:" .. nextReviewKey)
    if id then
        state.logRaw, state.logSignature, state.logID = state.raw, signature, id
        if state.displayOnly or state.keepLabel then
            local entry = ns.Review.Get(id)
            if entry then
                entry.action = displayedAction
                entry.displayOnly = true
                entry.captureSnapshot.actualAction = displayedAction
            end
        end
    end
    return id
end

local function SafeRegion(region)
    return region and region.GetText and region.GetParent and region.SetAlpha
        and not (region.IsForbidden and region:IsForbidden())
end

local function CanChange(region, state)
    if state.displayOnly or state.passive then
        -- Public nameplate text can be updated outside combat even when its
        -- engine parent is protected. Protected trees defer in combat.
        local object = region
        for _ = 1, 12 do
            if not object then return true end
            -- Shared engine roots also parent secure displays. Their status
            -- does not make every ordinary child label a protected control.
            if object == UIParent or object == WorldFrame then return true end
            if not ns.Readable(object) or (object.IsForbidden and object:IsForbidden()) then return false end
            if object.IsProtected and object:IsProtected()
                and (not (state.nativeNameplate or state.targetName) or InCombatLockdown and InCombatLockdown()) then return false end
            object = object.GetParent and object:GetParent()
        end
        return false
    end
    if state.bubble then
        local parent = region:GetParent()
        return ns.BubbleSafe and ns.BubbleSafe(state.bubble)
            and not (region.IsForbidden and region:IsForbidden())
            and parent and not (parent.IsForbidden and parent:IsForbidden())
            and not (parent.IsProtected and parent:IsProtected())
    end
    return not (InCombatLockdown and InCombatLockdown())
end

local function RestoreBubble(state)
    if state.bubble and state.bubbleHidden then
        state.bubble:SetAlpha(state.bubbleAlpha)
        state.bubbleHidden = false
    end
end
local function Write(region, state, text)
    if not ns.CanRead(text) then return false end
    local current = region:GetText()
    if ns.CanRead(current) and current == text then state.display = text; state.writeFailed = nil; return true end
    state.writing = true
    local ok = pcall(region.SetText, region, text)
    state.writing = false
    state.writeFailed = not ok
    if ok then state.display = text end
    return ok
end
local function Alpha(region, state, value)
    state.writingAlpha = true; region:SetAlpha(value); state.writingAlpha = false
end
local function Restore(region, state)
    ns.LabelReveal.Hide(region, state)
    if state.visual then state.visual:Hide() end
    if not state.displayOnly then Write(region, state, state.raw) end
    if not (state.nativeNameplate or state.targetName or state.preserveAlpha) then Alpha(region, state, state.alpha) end
    RestoreBubble(state)
end

local Apply
local inputRevision = 0
local function NativeName(state) return state.nativeNameplate or state.targetName end
local function PreservesAlpha(state) return state.nativeNameplate or state.targetName or state.preserveAlpha end
local revealTargets = setmetatable({}, {__mode = "k"})
local revealBadges = setmetatable({}, {__mode = "k"})
function ns.RevealModifier()
    return type(IsControlKeyDown) == "function" and ns.Checked(ns.SafeCall(IsControlKeyDown))
        and not (type(IsShiftKeyDown) == "function" and ns.Checked(ns.SafeCall(IsShiftKeyDown)))
        and not (type(IsAltKeyDown) == "function" and ns.Checked(ns.SafeCall(IsAltKeyDown)))
end
local function ConfigureReveal(cover, state)
    if state.routeRevision == inputRevision then return end
    state.routeRevision = inputRevision
    if NativeName(state) then
        -- A visible button outside the native unit hit area needs no engine
        -- mouse pass-through configuration. Native name clicks stay untouched.
        state.revealReady, state.revealRoute = true, "separate"
        return
    end
    -- Retry after construction/modifier/combat transitions instead of latching
    -- an early mouse-API denial until reload. Only owned controls are changed.
    if type(cover.SetPassThroughButtons) == "function"
        and pcall(cover.SetPassThroughButtons, cover, "RightButton", "MiddleButton", "Button4", "Button5") then
        state.revealReady, state.revealRoute = true, "passThrough"
    elseif not NativeName(state) and type(cover.SetPropagateMouseClicks) == "function"
        and pcall(cover.SetPropagateMouseClicks, cover, true) then
        -- A UI child can propagate non-left events through its own native
        -- ancestor. Independent world/target controls must use pass-through.
        state.revealReady, state.revealRoute = true, "propagate"
    else state.revealReady, state.revealRoute = false, nil end
end
local function RouteMouse(cover, state, mouse)
    if state.revealRoute == "separate" then return mouse == "LeftButton" end
    if state.revealRoute ~= "propagate" then return true end
    local consume = mouse == "LeftButton" and (state.pressed or ns.RevealModifier())
    local ok = pcall(cover.SetPropagateMouseClicks, cover, not consume)
    if not ok then state.revealReady = false; cover:EnableMouse(false) end
    return ok and consume
end
local function SetRevealInput(cover, active, ready, state)
    local enabled = state and state.pressed or active and ready and ns.RevealModifier() or false
    -- Do not move a press from its original native button if Ctrl is pressed
    -- midway through an ordinary click.
    if enabled and not cover:IsMouseEnabled() and type(IsMouseButtonDown) == "function"
        and ns.Checked(ns.SafeCall(IsMouseButtonDown, "LeftButton")) then enabled = false end
    if cover:IsMouseEnabled() ~= enabled then cover:EnableMouse(enabled) end
end
local function SyncBadge(badge, data)
    if data.redacted and not data.revealReady then ConfigureReveal(badge, data) end
    SetRevealInput(badge, data.redacted and ns.Active("barber") and badge:IsVisible()
        and not (InCombatLockdown and InCombatLockdown()), data.revealReady, data)
end
local function SyncReveal(region, state)
    if state.linkView then ns.LabelReveal.Sync(region, state, CanChange) end
end
local input = CreateFrame("Frame")
local releaseQueued
local function ReleaseCapture()
    releaseQueued = false
    for region, state in pairs(revealTargets) do
        state.pressed = nil
        for _, button in ipairs(state.unitButtons or {}) do button.pressed = nil end
        SyncReveal(region, state)
    end
    for badge, data in pairs(revealBadges) do data.pressed = nil; SyncBadge(badge, data) end
end
for _, event in ipairs({"MODIFIER_STATE_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GLOBAL_MOUSE_DOWN", "GLOBAL_MOUSE_UP"}) do input:RegisterEvent(event) end
input:SetScript("OnEvent", function(_, event, button)
    if event == "GLOBAL_MOUSE_DOWN" or event == "GLOBAL_MOUSE_UP" then
        ns.LabelReveal.GlobalMouse(event, button, revealTargets, CanChange)
        if event == "GLOBAL_MOUSE_DOWN" then return end
    else ns.LabelReveal.CancelGlobalMouse() end
    if event == "GLOBAL_MOUSE_UP" then
        if not releaseQueued then
            releaseQueued = true
            if C_Timer and C_Timer.After then C_Timer.After(0, ReleaseCapture) end
        end
        return
    end
    inputRevision = inputRevision + 1
    for region, state in pairs(revealTargets) do SyncReveal(region, state) end
    for badge, data in pairs(revealBadges) do SyncBadge(badge, data) end
end)
local inputElapsed = 0
input:SetScript("OnUpdate", function(_, elapsed)
    if releaseQueued and not (C_Timer and C_Timer.After) then ReleaseCapture() end
    -- A cheap edge sample covers native plates that swallow global events.
    -- Geometry and target traversal still run only during the Ctrl gesture.
    if next(revealTargets) then ns.LabelReveal.PollMouse(revealTargets,CanChange) end
    -- Follow moving plates/scrolling labels only while the reveal gesture is
    -- active. No text-tree traversal outside the reveal gesture.
    if not ns.RevealModifier() then inputElapsed = 0; return end
    inputElapsed = inputElapsed + elapsed; if inputElapsed < 0.05 then return end
    inputElapsed = 0
    for region, state in pairs(revealTargets) do SyncReveal(region, state) end
    for badge, data in pairs(revealBadges) do SyncBadge(badge, data) end
end)
local function DisplayLabel(region, state, matches, action)
    if not state.visual then
        local visual = CreateFrame("Button", nil, region:GetParent())
        visual:EnableMouse(false); visual:SetAllPoints(region)
        local text = visual:CreateFontString(nil, "OVERLAY")
        text:SetAllPoints(visual)
        state.visual, state.visualText = visual, text
    end
    local visual, text = state.visual, state.visualText
    visual:SetFrameLevel(region:GetParent():GetFrameLevel() + 1)
    local font, size, flags = region:GetFont()
    if font then text:SetFont(font, size, flags) end
    -- Auto-sized headings/choice FontStrings can report zero layout height.
    -- Give the copy a measured rectangle rather than copying that empty box.
    local width = region:GetWidth() or 0
    if width <= 0 then width = math.max(region:GetStringWidth() or 0, 1) end
    local height = math.max(region:GetHeight() or 0, region:GetStringHeight() or 0, size or 12)
    visual:ClearAllPoints(); visual:SetPoint("CENTER", region, "CENTER")
    visual:SetSize(width, height)
    if region.GetJustifyH then text:SetJustifyH(region:GetJustifyH()) end
    if region.GetJustifyV and text.SetJustifyV then text:SetJustifyV(region:GetJustifyV()) end
    if region.GetWordWrap then text:SetWordWrap(region:GetWordWrap()) else text:SetWordWrap(false) end
    if region.GetTextColor then
        local r, g, b = region:GetTextColor()
        -- FontString alpha is also returned by GetTextColor. The original is
        -- already transparent on subsequent scans; never copy its zero alpha.
        text:SetTextColor(r, g, b, 1)
    end
    text:SetText(action == "Warning" and ns.RenderWarning(state.raw)
        or state.revealed and action == "Redacted" and ns.RenderRevealed(state.raw, matches, text)
        or ns.RenderRedacted(state.raw, matches, text))
    state.display = text:GetText()
    Alpha(region, state, 0)
    visual:SetAlpha(state.alpha); visual:SetShown(not region.IsShown or region:IsShown())
    visual:EnableMouse(false)
end
Apply = function(region, state)
    if not CanChange(region, state) then
        if state.linkView then ns.LabelReveal.Hide(region,state) end
        local control = state.displayOnly and state.visual or state.cover
        if control then control:EnableMouse(false) end
        return
    end
    if not ns.CanRead(state.raw) then
        state.action = "Unavailable"
        PreviewState(region, "Unavailable")
        if state.cover then state.cover:EnableMouse(false); state.cover:Hide() end
        if state.warning then state.warning:Hide() end
        Restore(region, state)
        return
    end
    local wordActive = ns.Active(state.scope)
    local nameActive = state.languageName and ns.Language and ns.Language.NamesActive()
    local active = wordActive or nameActive
    if active and state.available then active = ns.SafeCall(state.available) == true end
    if active and state.bubble and ns.BubbleAllowed then active = ns.BubbleAllowed(state.raw) end
    local matches = active and (state.matchRaw == state.raw
        and state.matchRevision == ns.PolicyRevision and state.cachedMatches or
            (nameActive and ns.Language.NameMatches(state.raw,wordActive and ns.Find(state.raw) or {}) or ns.Find(state.raw))) or {}
    state.matchRaw, state.matchRevision, state.cachedMatches = state.raw, active and ns.PolicyRevision or nil, matches
    local language=active and state.bubble and ns.BubbleLanguage and ns.BubbleLanguage(state.raw)
    if language then matches=ns.Language.Display(matches,language) end
    if #matches == 0 and not language then
        state.revealed = false
        state.action = not ns.Active(state.scope) and "Disabled" or "Unchanged"
        PreviewState(region, state.action)
        if state.cover then state.cover:EnableMouse(false); state.cover:Hide() end
        if state.warning then state.warning:Hide() end
        Restore(region, state)
        return
    end
    local action = ns.MatchAction(matches)
    if language then action=ns.Language.Action(action,language) end
    -- A control/name stays selectable. High-strength matches cover its words
    -- instead of removing the entire label or overwriting its native identity.
    if (state.displayOnly or state.keepLabel) and action == "Hidden" then action = "Redacted" end
    local retained = RecordUI(region, state, matches, action)
    if state.tooltip then
        ns.LabelReveal.Hide(region, state)
        state.matches = matches
        if action == "Hidden" then action = "Redacted" end
        state.revealed = action == "Redacted" and ns.RevealModifier() or false
        state.action = state.revealed and "Revealed" or action
        Write(region, state, action == "Warning" and ns.RenderWarning(state.raw)
            or state.revealed and ns.RenderRevealed(state.raw, matches, region)
            or ns.RenderRedacted(state.raw, matches, region))
        return
    end
    if action ~= "Redacted" then ns.LabelReveal.Hide(region, state) end
    if state.displayOnly then
        state.action, state.matches = action, matches
        if action == "Redacted" then
            if state.visual then state.visual:Hide() end
            revealTargets[region] = state
            ns.LabelReveal.Update(region, state, CanChange, Apply)
            PreviewState(region, state.action)
            return
        end
        DisplayLabel(region, state, matches, action)
        if action == "Redacted" and state.revealed then state.action = "Revealed" end
        return
    end
    if action == "Hidden" and not retained then action = "Warning" end
    state.action = action
    PreviewState(region, action)
    if state.warning then state.warning:Hide() end
    if action == "Replaced" then
        state.revealed = false
        if state.cover then state.cover:EnableMouse(false); state.cover:Hide() end
        Write(region, state, ns.RenderRedacted(state.raw, matches, region))
        if not PreservesAlpha(state) then Alpha(region, state, state.alpha) end
        RestoreBubble(state); state.matches = matches
        return
    end
    if action ~= "Redacted" then
        state.revealed = false
        if state.cover then state.cover:EnableMouse(false); state.cover:Hide() end
        Write(region, state, action == "Warning" and ns.RenderWarning(state.raw) or state.raw)
        if not PreservesAlpha(state) then Alpha(region, state, action == "Hidden" and 0 or state.alpha) end
        if state.bubble and action == "Hidden" then
            local alpha = state.bubble:GetAlpha()
            if not state.bubbleHidden or alpha > 0 then state.bubbleAlpha = alpha end
            state.bubbleHidden = true; state.bubble:SetAlpha(0)
        else RestoreBubble(state) end
        state.matches = matches
        return
    end
    state.matches = matches
    RestoreBubble(state)
    local rendered = ns.RenderSelective(state.raw, matches, region, state.revealed and state.revealedSpans or nil)
    if language and language.kind=='strict-script' and ns.LanguageDisplay then rendered=ns.LanguageDisplay.MessageLinks(rendered,region) end
    if not Write(region, state, rendered) then
        state.action = "Unavailable"
        local entry = retained and ns.Review.Get(retained)
        if entry then entry.action = "Unchanged"; entry.captureSnapshot.actualAction = "Unchanged"
            entry.captureSnapshot.diagnosticError = "Native text label could not be updated." end
        if state.cover then state.cover:EnableMouse(false); state.cover:Hide() end
        return
    end
    state.action = state.revealed and "Revealed" or "Redacted"
    PreviewState(region, state.action)
    revealTargets[region] = state
    ns.LabelReveal.Update(region, state, CanChange, Apply)
end

-- Bubble polling/source capture must read the original, not our texture markup.
function ns.RegionOriginal(region)
    local state = states[region]
    return state and state.raw or region:GetText()
end

function ns.TrackRegion(region, scope, sourceProvider, bubble, options)
    if not SafeRegion(region) then return end
    if bubble then
        if not ns.BubbleSafe(bubble) then return end
    elseif not (options and (options.displayOnly or (options.nativeNameplate or options.targetName)))
        and InCombatLockdown and InCombatLockdown() then return end
    if region.GetObjectType and region:GetObjectType() ~= "FontString" then return end
    local parent = region:GetParent()
    if not parent or (parent.IsForbidden and parent:IsForbidden())
        or (parent.IsProtected and parent:IsProtected()) and not (options and (options.nativeNameplate or options.targetName)) then return end
    if options and options.displayOnly and not CanChange(region, {displayOnly = true}) then return end
    local state = states[region]
    if not state then
        state = {scope = scope, raw = region:GetText(), alpha = region:GetAlpha(), revealed = false, source = sourceProvider}
        state.bubble, state.bubbleAlpha = bubble, bubble and bubble:GetAlpha()
        state.displayOnly = options and options.displayOnly == true
        state.keepLabel = options and options.keepLabel == true
        state.passive = options and options.passive == true
        state.nativeNameplate = options and options.nativeNameplate == true
        state.targetName = options and options.targetName == true
        state.identity = options and options.identity
        state.preserveAlpha = options and options.preserveAlpha == true
        state.tooltip = options and options.tooltip == true
        state.unit = options and options.unit
        state.controlHost = options and options.controlHost
        state.available = options and options.available
        state.languageName = options and options.languageName == true
        states[region] = state
        hooksecurefunc(region, "SetText", function(_, text)
            if state.writing then return end
            if not ns.CanRead(text) then
                state.raw, state.revealed, state.pressed = nil, false, nil
            elseif state.raw ~= text then
                state.raw, state.revealed, state.pressed = text, false, nil
            end
            Apply(region, state)
        end)
        -- Follow native quest fades and name visibility on every label copy.
        do
            hooksecurefunc(region, "SetAlpha", function(_, alpha)
                if state.writingAlpha or not ns.SafeNumber(alpha) then return end
                state.alpha = alpha
                if state.linkView and state.linkHidden then
                    Alpha(region, state, 0); ns.LabelReveal.Sync(region, state, CanChange)
                else Apply(region, state) end
            end)
            if type(region.SetTextColor) == "function" then
                hooksecurefunc(region, "SetTextColor", function(_, _, _, _, alpha)
                    if ns.SafeNumber(alpha) then state.alpha = alpha end
                    Apply(region, state)
                end)
            end
            for _, method in ipairs({"Show", "Hide"}) do
                if type(region[method]) == "function" then hooksecurefunc(region, method, function() Apply(region, state) end) end
            end
        end
    else
        if sourceProvider then state.source = sourceProvider end
        if state.scope ~= scope then state.revealed = false end
        state.scope = scope
        if options then
            state.languageName = options.languageName == true
            state.available = options.available
            state.unit = options.unit
            state.controlHost = options.controlHost
            if options.preserveAlpha ~= nil then state.preserveAlpha = options.preserveAlpha == true end
            if state.identity ~= options.identity then state.revealed = false; state.pressed = nil; state.logSignature = nil end
            state.identity = options.identity
        end
        local text = region:GetText()
        if not ns.CanRead(text) then state.raw, state.revealed, state.pressed = nil, false, nil
        elseif state.raw ~= text and state.display ~= text then state.raw, state.revealed, state.pressed = text, false, nil end
    end
    Apply(region, state)
end
function ns.RegionDisplayStatus(region)
    local state = states[region]
    if not state then return "Untracked" end
    if not CanChange(region, state) then return "Restricted" end
    return state.action
end

function ns.ResetBubbleRegion(region)
    local state = states[region]
    if not state or not state.bubble then return end
    if not CanChange(region, state) then return end
    Restore(region, state)
    if state.cover then state.cover:EnableMouse(false); state.cover:Hide() end
    if state.warning then state.warning:Hide() end
    state.raw, state.matches, state.logRaw, state.logSignature, state.logID = nil, nil, nil, nil, nil
    state.display = nil
    state.revealed = false
end

function ns.RefreshUI(reset)
    for region, state in pairs(states) do
        if reset then state.revealed = false; state.pressed = nil end
        Apply(region, state)
    end
    if ns.RefreshBarber then ns.RefreshBarber() end
    if ns.QueueNameScan then ns.QueueNameScan() end
end

function ns.ScanUI()
    -- Explicit narrative/label allowlists; never enumerate arbitrary UI.
    for _, name in ipairs({"QuestInfoDescriptionText", "QuestInfoRewardText", "QuestProgressText", "GreetingText", "GossipGreetingText", "QuestInfoTitleHeader", "QuestProgressTitleText"}) do
        local regionName = name
        local isLog = regionName:find("QuestInfo", 1, true) == 1 and QuestInfoFrame and QuestInfoFrame.questLog
        local source = ns.UIReviewSource((regionName == "GreetingText" or regionName == "GossipGreetingText") and "gossip" or "quest", regionName, isLog)
        ns.TrackRegion(_G[name], "dialogue", function()
            return ns.UIReviewSource((regionName == "GreetingText" or regionName == "GossipGreetingText") and "gossip" or "quest", regionName, isLog)
        end, nil, {displayOnly = regionName == "QuestInfoTitleHeader" or regionName == "QuestProgressTitleText",
            preserveAlpha = true, keepLabel = true,
            identity = tostring(source.questID or source.questTitle or "") .. ":" .. tostring(ns.Interaction)})
    end
    if ns.ScanExtraText then ns.ScanExtraText() end
    local gossip = GossipFrame
    local panel = gossip and gossip.GreetingPanel
    local scroll = panel and panel.ScrollBox
    local function Greeting(frame)
        if not frame then return end
        ns.TrackRegion(frame.GreetingText, "dialogue", function() return ns.UIReviewSource("gossip", "Gossip greeting") end)
    end
    Greeting(gossip); Greeting(panel)
    if scroll and type(scroll.ForEachFrame) == "function" then
        local count = 0
        ns.SafeCall(scroll.ForEachFrame, scroll, function(frame)
            count = count + 1; if count <= 100 then Greeting(frame) end
        end)
    elseif scroll and type(scroll.GetFrames) == "function" then
        local frames = ns.SafeCall(scroll.GetFrames, scroll)
        if type(frames) == "table" then for i, frame in ipairs(frames) do if i > 100 then break end; Greeting(frame) end end
    end
    if TalkingHeadFrame and TalkingHeadFrame.TextFrame then
        ns.TrackRegion(TalkingHeadFrame.TextFrame.Text, "talkingHead", function() return ns.UIReviewSource("talkingHead", "Talking-head caption") end)
    end
end

function ns.RevealStatus()
    local ready, unavailable = 0, 0
    for region, state in pairs(revealTargets) do
        if (state.action == "Redacted" or state.action == "Revealed") and (not region.IsVisible or region:IsVisible()) then
            if state.revealReady and state.geometryReady ~= false and CanChange(region, state)
                and (not state.available or ns.SafeCall(state.available) == true) then ready = ready + 1 else unavailable = unavailable + 1 end
        end
    end
    return "Ctrl + left-click reveal: " .. ready .. " supported labels; " .. unavailable .. " restricted/unavailable. Click one covered phrase to toggle it."
end

function ns.QueueScan(reset)
    resetPending = resetPending or reset
    if scanQueued then return end
    scanQueued = true
    local function Run()
        scanQueued = false
        ns.ScanUI()
        ns.RefreshUI(resetPending)
        resetPending = false
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Run) else Run() end
end

local function BarberLabel(button)
    if InCombatLockdown and InCombatLockdown() then return end
    local sexes = Enum and Enum.UnitSex
    if not sexes or not button.ClearTooltipLines or not button.AddTooltipLine then return end
    local original
    if button.sexID == sexes.Male then original = BODY_1
    elseif button.sexID == sexes.Female then original = BODY_2 end
    if not ns.CanRead(original) then return end
    local matches = ns.Active("barber") and ns.Find(original) or {}
    local action = #matches > 0 and ns.MatchAction(matches) or nil
    local redacted = action == "Redacted"
    local replaced = action == "Replaced"
    local data = buttons[button]
    if not data then
        data = {}; buttons[button] = data
        hooksecurefunc(button, "SetBodyType", BarberLabel)
    end
    if not data.badge and (redacted or replaced) and not (InCombatLockdown and InCombatLockdown()) then
        local badge = CreateFrame("Button", nil, button)
        badge:SetSize(80, 17)
        badge:SetPoint("TOP", button, "BOTTOM", 0, -3)
        local texture = badge:CreateTexture(nil, "BACKGROUND")
        texture:SetAllPoints()
        texture:SetColorTexture(unpack(ns.RedactionColor))
        local label = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetAllPoints(); label:SetTextColor(0.69, 0.71, 0.73)
        badge:EnableMouse(false); badge:RegisterForClicks("LeftButtonUp")
        ConfigureReveal(badge, data); revealBadges[badge] = data
        badge:SetScript("OnMouseDown", function(self, mouse)
            if mouse == "LeftButton" and ns.RevealModifier() and data.revealReady then data.pressed = true end
            RouteMouse(self, data, mouse)
        end)
        badge:SetScript("OnMouseUp", function(self, mouse)
            local owned = data.pressed
            local consume = RouteMouse(self, data, mouse)
            data.pressed = nil
            if consume and owned and mouse == "LeftButton" and ns.RevealModifier() and data.redacted
                and not (InCombatLockdown and InCombatLockdown()) then
                data.revealed = not data.revealed; BarberLabel(button)
            end
            SyncBadge(self, data)
        end)
        ns.Theme.Tooltip(badge, "Body-type wording", "Barber & body-type wording in Settings changes Body Type 1/2 to Male/Female without a pack. If a label is redacted by another rule, Ctrl + left-click reveals or re-covers it.")
        data.texture, data.label = texture, label
        data.badge = badge
    end
    if data.original ~= original or data.revision ~= ns.PolicyRevision then data.revealed = false; data.pressed = nil end
    data.original, data.match, data.revision = original, matches[1], ns.PolicyRevision
    if #matches > 0 and ns.Review and not (button.IsVisible and not button:IsVisible()) then
        local signature = original .. ":" .. tostring(ns.Interaction) .. ":" .. tostring(ns.PolicyRevision)
        if data.logSignature ~= signature or not ns.Review.Get(data.logID) then
            nextReviewKey = nextReviewKey + 1
            data.logID = ns.Review.Add(original, matches, ns.UIReviewSource("barber", "Body-type tooltip"), "barber:" .. nextReviewKey)
            if data.logID then data.logSignature = signature end
        end
    end
    if action == "Hidden" and not (data.logID and ns.Review.Get(data.logID)) then action = "Warning" end
    button:ClearTooltipLines()
    if action ~= "Hidden" then
        button:AddTooltipLine(replaced and ns.RenderRedacted(original, matches) or redacted and (data.revealed and ns.RenderRevealed(original, matches)
            or ns.RenderRedacted(original, matches))
            or action == "Warning" and ns.RenderWarning(original) or original, HIGHLIGHT_FONT_COLOR)
    end
    if data.badge then
        data.texture:SetShown(redacted and not data.revealed)
        data.label:SetText(replaced and ns.RenderRedacted(original, matches, data.label) or original)
        data.label:SetShown(replaced or data.revealed)
        data.badge:SetShown(redacted or replaced)
        data.redacted = redacted
        SyncBadge(data.badge, data)
    end
    -- Restrict visible-label handling to the known sex-selector buttons.
    -- Track originals so pooled buttons and disabling coverage restore correctly.
    local nativeLabel = false
    for _, region in ipairs(button.GetRegions and {button:GetRegions()} or {}) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then
            local raw = ns.RegionOriginal(region)
            if ns.CanRead(raw) and (raw == BODY_1 or raw == BODY_2
                or ns.BuiltinBodyReplacements and #ns.BuiltinBodyReplacements:Find(raw)>0
                or ns.BodyReplacements and #ns.BodyReplacements:Find(raw)>0) then
                nativeLabel = true
                ns.TrackRegion(region, "barber", function() return ns.UIReviewSource("barber", "Body-type label") end)
            end
        end
    end
    if nativeLabel and replaced and data.badge then data.badge:Hide() end
end

function ns.RefreshBarber()
    if InCombatLockdown and InCombatLockdown() then return end
    local frame = BarberShopFrame
    local pool = frame and frame.sexButtonPool
    if pool and pool.EnumerateActive then
        for button in pool:EnumerateActive() do BarberLabel(button) end
    end
end

local npcEvents = {"CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_WHISPER", "CHAT_MSG_MONSTER_EMOTE"}
local playerEvents = {"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_CHANNEL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE",
    "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER"}
local npcLookup = {}
for _, event in ipairs(npcEvents) do npcLookup[event] = true end

function ns.ChatFilter(frame, event, message, ...)
    local source, key = ns.ChatReviewSource(event, ...)
    local capture=ns.ChatReports and ns.ChatReports.Capture(event,message,source.sender,select(10,...))
    local safePreview
    local function Record(action,info,diagnostic)
        if capture then ns.ChatReports.RecordOutcome(capture,action,info or source,diagnostic,safePreview) end
    end
    local function Decorate(text)
        if not ns.Wanted then return text end
        local ok,result=pcall(ns.Wanted.Decorate,frame,text,capture,source)
        if ok and ns.CanRead(result) then return result end
        return text
    end
    local shielded,shieldSource
    if ns.Shield then shielded,shieldSource=ns.Shield.FilterChat(event,message,...) end
    if shielded then Record('Hidden',shieldSource);return true end
    if not ns.Active(npcLookup[event] and "npc" or "chat") or not ns.CanRead(message) then
        Record('Unchanged',shieldSource);return false
    end
    local matches = ns.Find(message,ns.TypoFilter.Allowed(event,source),source)
    local language = ns.Language and ns.Language.Check(message,event,source)
    if source.kind=='player' and ns.Language and ns.Language.NamesActive() and ns.ChatReports then
        -- Resolve the final native name label against this exact original before
        -- the formatter runs, including Label/Leave actions. The existing bounded
        -- report cache deduplicates chat-window callbacks and the event receiver.
        ns.ChatReports.Capture(event,message,source.sender,select(10,...))
    end
    if #matches == 0 and not language then
        Record('Unchanged',shieldSource,shieldSource and shieldSource.filterStatus=='review-unavailable' and 'Original could not be retained for review.' or nil)
        local decorated=Decorate(message)
        if decorated~=message then return false,decorated,... end
        return false
    end
    local wordAction = ns.MatchAction(matches)
    local action = ns.Language and ns.Language.Action(wordAction,language) or wordAction
    local displayMatches = ns.Language and ns.Language.Display(matches,language) or matches
    source.language = language
    source.hiddenMessage = action == "Hidden"
    local lineKey = key
    if not lineKey then
        -- Some clients omit a readable line ID. Each render still needs an
        -- independent reveal state even for identical messages in one tick.
        nextChatRevealKey = nextChatRevealKey + 1
        lineKey = "chat-render:" .. nextChatRevealKey
    end
    key = key or capture and capture.deliveryKey or ns.ChatFallbackKey(event, message, source)
    local frameName = frame and frame.GetName and ns.SafeString(ns.SafeCall(frame.GetName, frame), 128) or tostring(frame)
    local revealKey = lineKey .. ":" .. (frameName or "chat") .. ":" .. tostring(ns.PolicyRevision)
    local rendered = action == "Hidden" and "[Hidden - original available in review inbox]"
        or ns.RenderRedacted(message, displayMatches, frame, true, revealKey)
    if language and language.kind=='strict-script' and action~='Hidden' and ns.LanguageDisplay then
        rendered=ns.LanguageDisplay.MessageLinks(rendered,frame)
    end
    if wordAction == "Warning" then rendered = ns.RenderWarning(rendered) end
    if language and language.action == "Warning" then rendered = "|cffb0b5bb[Language: " .. language.label .. "]|r " .. rendered end
    local retained
    safePreview=action=='Hidden' and '[Hidden message]' or ns.Engine.Render(message,displayMatches,function(original,match)
        return match.replacement or (ns.IsRedacted(match) and '[redacted]' or original)
    end)
    if ns.Review then
        local preview = action == "Hidden" and rendered or ns.Engine.Render(message, displayMatches, function(original, match)
            return match.replacement or (ns.IsRedacted(match) and "[redacted]" or original)
        end)
        if wordAction == "Warning" then preview = "[!] " .. preview end
        if language and language.action == "Warning" then preview = "[Language: " .. language.label .. "] " .. preview end
        retained = ns.Review.Add(message, matches, source, key, preview)
    end
    ns.Stats.chatMatches = ns.Stats.chatMatches + #matches
    -- Fail open if an original could not be retained for review.
    if action == "Hidden" then
        Record(retained and 'Hidden' or 'Unchanged',source,not retained and 'Original could not be retained for review.' or nil)
        return retained ~= nil
    end
    Record(action,source)
    return false, Decorate(rendered), ...
end

function ns.InstallAdapters()
    if not chatInstalled then
        local register = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
        if type(register) == "function" then
            for _, event in ipairs(playerEvents) do register(event, ns.ChatFilter) end
            for _, event in ipairs(npcEvents) do register(event, ns.ChatFilter) end
            chatInstalled = true
        end
    end
    ns.ChatReveal.Install()
    if ns.LanguageDisplay then
        ns.LanguageDisplay.Install()
        if not ns.LanguageDisplay.systemInstalled then
            local register=ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
            if type(register)=='function' then register('CHAT_MSG_SYSTEM',ns.LanguageDisplay.SystemFilter);ns.LanguageDisplay.systemInstalled=true end
        end
    end
    local barber = BarberShopFrame
    if barber and not installedFrames[barber] and type(barber.UpdateSex) == "function" then
        hooksecurefunc(barber, "UpdateSex", ns.RefreshBarber)
        barber:HookScript("OnShow", ns.RefreshBarber)
        installedFrames[barber] = true
    end
    local gossip = GossipFrame
    if gossip then
        local hooks = type(installedFrames[gossip]) == "table" and installedFrames[gossip] or {}
        installedFrames[gossip] = hooks
        if not hooks.register and type(gossip.RegisterFontString) == "function" then
            hooks.register = true
            hooksecurefunc(gossip, "RegisterFontString", function(_, region)
                if SafeRegion(region) and region:GetParent() and region:GetParent().GreetingText == region then
                    ns.TrackRegion(region, "dialogue", function() return ns.UIReviewSource("gossip", "Gossip greeting") end)
                elseif SafeRegion(region) and region:GetParent() and region:GetParent().GetFontString
                    and region:GetParent():GetFontString() == region then
                    ns.TrackRegion(region, "dialogue", function() return ns.UIReviewSource("gossip", "Gossip/quest choice") end,
                        nil, {displayOnly = true})
                end
            end)
        end
        if not hooks.update and type(gossip.Update) == "function" then
            hooks.update = true; hooksecurefunc(gossip, "Update", function() ns.QueueScan(false) end)
        end
        if not hooks.show then
            hooks.show = true; gossip:HookScript("OnShow", function() ns.QueueScan(true) end)
        end
    end
end

function ns.MakeDemo()
    if InCombatLockdown and InCombatLockdown() then
        ns.Print("Open Filter preview after combat so it can apply your settings."); return
    end
    if not ns.Demo then
        local T = ns.Theme
        local demo = T.Window("OlympusChatWardenDemo", UIParent, 680, 424)
        T.Title(demo, "Olympus ChatWarden"); T.Crest(demo)
        local function Text(parent, x, y, width, value, font)
            local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
            text:SetPoint("TOPLEFT", x, y); text:SetWidth(width); text:SetJustifyH("LEFT")
            text:SetText(value); T.Light(text); return text
        end
        T.Gold(Text(demo, 78, -30, 575, "Filter preview", "GameFontNormalLarge"))
        T.Muted(Text(demo, 78, -50, 575, "Uses your sensitivity and rule packs. Text-area switches do not disable these local tests."))
        ns.DemoStatuses, ns.DemoExamples, ns.DemoLabels = {}, {}, {}
        local examples = {{"Warning example", "We found a safe space near the inn."}, {"Redaction example", "An inclusive language guide visits the village."},
            {"Hide example", "Body Type 1 and birthing person"}}
        for i, spec in ipairs(examples) do
            local row = T.Panel(demo, 14, -82 - (i - 1) * 84, 652, 76)
            ns.DemoLabels[i] = T.Gold(Text(row, 12, -10, 180, spec[1], "GameFontNormal"))
            local status = T.Muted(Text(row, 194, -12, 442, ""))
            local text = Text(row, 14, -39, 612, spec[2], "GameFontHighlight")
            ns.DemoStatuses[text] = status; ns.DemoExamples[i] = text
        end
        ns.DemoLow, ns.DemoText, ns.DemoHigh = ns.DemoExamples[1], ns.DemoExamples[2], ns.DemoExamples[3]
        T.Muted(Text(demo, 18, -344, 646, "Ctrl + left-click redacted text to reveal its matched words; repeat to redact. Hidden originals stay in Review."))
        local reset = CreateFrame("Button", nil, demo, "UIPanelButtonTemplate")
        reset:SetSize(140, 24); reset:SetPoint("BOTTOMLEFT", 18, 34); reset:SetText("Reset preview")
        reset:SetScript("OnClick", function() ns.RefreshUI(true) end)
        local review = CreateFrame("Button", nil, demo, "UIPanelButtonTemplate")
        review:SetSize(160, 24); review:SetPoint("BOTTOMLEFT", 170, 34); review:SetText("Review messages")
        review:SetScript("OnClick", ns.OpenReview)
        ns.Demo = demo
    end
    if ns.DemoPackRevision ~= ns.RulePacks.Revision then
        ns.DemoPackRevision = ns.RulePacks.Revision
        local examples = ns.RuleMeta["safe space"] and ns.RuleMeta["inclusive language"] and {
            {"Warning example", "We found a safe space near the inn."},
            {"Redaction example", "An inclusive language guide visits the village."},
            {"Hide example", "Body Type 1 and birthing person"}} or {
            {"Normal mention", "Thanks Olympus for the group!"},
            {"Guild criticism", "Olympus is overrated."},
            {"Directed insult", "Asmon that guy sucks."}}
        for i, spec in ipairs(examples) do ns.DemoLabels[i]:SetText(spec[1]); ns.DemoExamples[i]:SetText(spec[2]) end
    end
    ns.Theme.ShowWindow(ns.Demo)
    for i, region in ipairs(ns.DemoExamples) do
        local index = i
        ns.TrackRegion(region, "preview", function() return {kind = "demo", panel = "Preview example " .. index} end)
    end
    ns.RefreshUI(true)
end

