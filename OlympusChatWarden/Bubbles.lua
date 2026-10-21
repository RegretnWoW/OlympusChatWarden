-- Stock accessible chat bubbles only. Never enumerate arbitrary WorldFrame children.
local _, ns = ...
local function OwnedFrame(...) return ns.Modules and ns.Modules.Frame('chat',...) or CreateFrame(...) end
local tracked = setmetatable({}, {__mode = "k"})
local recent, timer, nextBubble = {}, 0, 0
local frame = OwnedFrame("Frame")
local events = {"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_PARTY"}
local status = {seen = 0, skipped = 0, errors = 0, active = 0}
local function RestoreShield(bubble, data)
    if data and data.shieldAlpha then
        if ns.BubbleSafe(bubble) then pcall(bubble.SetAlpha, bubble, data.shieldAlpha) end
        data.shieldAlpha = nil
    end
end

function ns.BubbleSafe(bubble)
    if not ns.Readable(bubble) or not bubble or not bubble.GetChildren or not bubble.SetAlpha then return false end
    if bubble.IsForbidden and bubble:IsForbidden() then return false end
    if bubble.IsProtected and bubble:IsProtected() then return false end
    return true
end
local function SafeObject(object)
    return ns.Readable(object) and object and not (object.IsForbidden and object:IsForbidden())
        and not (object.IsProtected and object:IsProtected())
end
local function Locate(bubble)
    local function Walk(object, depth)
        if not SafeObject(object) then return nil end
        local direct = object.String
        if direct and SafeObject(direct) and direct.GetObjectType and direct:GetObjectType() == "FontString" then return direct end
        -- Only a recognized bubble holder may use the region fallback. A
        -- skin addon can put sender-name FontStrings on the outer frame.
        if (object.Center or object.Tail) and object.GetRegions then
            local regions = {object:GetRegions()}
            for _, region in ipairs(regions) do
                if SafeObject(region) and region.GetObjectType and region:GetObjectType() == "FontString" then return region end
            end
        end
        if depth > 0 and object.GetChildren then
            local children = {object:GetChildren()}
            for _, child in ipairs(children) do
                local found = Walk(child, depth - 1)
                if found then return found end
            end
        end
    end
    return Walk(bubble, 2)
end
local function Recent(text)
    local now, selected = ns.SessionTime(), nil
    for i = #recent, 1, -1 do
        local item = recent[i]
        if now - item.at > 10 then table.remove(recent, i)
        elseif item.text == text then
            if selected and (selected.source.sender ~= item.source.sender or selected.source.event ~= item.source.event) then
                return nil -- same wording from multiple speakers: omit ambiguous identity
            end
            selected = item
        end
    end
    return selected
end
function ns.BubbleAllowed(text)
    if not ns.Active("bubbles") then return false end
    local item = Recent(text)
    if item then return ns.Active(item.source.kind == "npc" and "npc" or "chat") end
    -- The bubble API supplies no sender. Unattributed text is filtered only
    -- when both chat scopes are enabled, rather than guessing its origin.
    return ns.Active("chat") and ns.Active("npc")
end
function ns.BubbleLanguage(text)
    local item=Recent(text)
    if item and item.source.kind=='player' and ns.Language then
        return ns.Language.Check(text,item.source.event,item.source)
    end
end
local function Source(text, identity)
    local item = Recent(text)
    local result = {kind = "bubble", panel = "Overhead chat bubble #" .. identity,
        zone = ns.SafeString(ns.SafeCall(GetRealZoneText), 128)}
    if item then
        for _, key in ipairs({"sender", "guid", "class", "channel", "event"}) do result[key] = item.source[key] end
        if item.source.kind == "npc" then result.npc = item.source.sender end
        result.language=ns.BubbleLanguage(text)
    end
    return result
end
local function Check(bubble)
    if not ns.BubbleSafe(bubble) then status.skipped = status.skipped + 1; return end
    local data = tracked[bubble]
    RestoreShield(bubble, data)
    if bubble.IsShown and not bubble:IsShown() then
        if data and data.visible then ns.ResetBubbleRegion(data.region); data.visible = false end
        return
    end
    local region = Locate(bubble)
    if not region or not region.GetText or not ns.CanRead(ns.RegionOriginal(region)) then
        status.skipped = status.skipped + 1; return
    end
    if not data then
        data = {region = region, visible = true}; tracked[bubble] = data
        status.seen = status.seen + 1
        if bubble.HookScript then
            bubble:HookScript("OnHide", function()
                RestoreShield(bubble, data)
                ns.ResetBubbleRegion(data.region); data.visible = false
            end)
        end
    elseif data.region ~= region then
        ns.ResetBubbleRegion(data.region); data.region = region; data.raw = nil
    end
    local raw = ns.RegionOriginal(region)
    if data.raw ~= raw or not data.visible then
        ns.ResetBubbleRegion(region)
        nextBubble = nextBubble + 1; data.identity = nextBubble
        data.raw, data.visible, data.revision = raw, true, nil
    end
    if data.revision ~= ns.PolicyRevision or data.enabled ~= ns.DB.enabled then
        ns.TrackRegion(region, "bubbles", function()
            local text = ns.RegionOriginal(region)
            -- A pooled String's SetText hook can run before the next poll.
            -- Advance its identity here so that poll does not capture it twice.
            if data.raw ~= text then
                nextBubble = nextBubble + 1; data.identity, data.raw = nextBubble, text
            end
            return Source(text, data.identity)
        end, bubble)
        data.revision, data.enabled = ns.PolicyRevision, ns.DB.enabled
    end
    -- SetText hooks cover text changes; rescans cover engine-reapplied alpha.
    ns.TrackRegion(region, "bubbles", nil, bubble)
    local item = Recent(raw)
    if ns.Shield and ns.Shield.HideBubble(item and item.source) then
        local alpha = ns.SafeNumber(ns.SafeCall(bubble.GetAlpha, bubble))
        if alpha then data.shieldAlpha = alpha; bubble:SetAlpha(0) end
    end
end
function ns.ScanBubbles()
    if not ns.DB then return end
    if not C_ChatBubbles or type(C_ChatBubbles.GetAllChatBubbles) ~= "function" then return end
    local ok, bubbles = pcall(C_ChatBubbles.GetAllChatBubbles)
    if not ok or not ns.Readable(bubbles) or type(bubbles) ~= "table" then status.skipped = status.skipped + 1; return end
    local present, count = {}, 0
    for _, bubble in pairs(bubbles) do
        count = count + 1
        if count > 128 then break end
        present[bubble] = true
        local success = pcall(Check, bubble)
        if not success then status.errors = status.errors + 1 end
    end
    status.active = math.min(count, 128)
    for bubble, data in pairs(tracked) do
        if not present[bubble] and data.visible then
            RestoreShield(bubble, data)
            pcall(ns.ResetBubbleRegion, data.region); data.visible = false; data.raw = nil
        end
    end
end
function ns.RefreshBubbles() ns.ScanBubbles() end
function ns.BubbleStatus()
    local available = C_ChatBubbles and type(C_ChatBubbles.GetAllChatBubbles) == "function"
    return "Overhead bubble filtering is " .. (ns.DB.bubbles and "on" or "off") .. ". "
        .. (available and "Accessible bubble text will use your current settings." or "This client does not offer accessible bubble text.")

end
for _, event in ipairs(events) do frame:RegisterEvent(event) end
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(_, event, message, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        recent = {}
        for bubble, data in pairs(tracked) do RestoreShield(bubble, data); pcall(ns.ResetBubbleRegion, data.region); data.raw, data.visible = nil, false end
        return
    end
    if not ns.DB or not ns.Membership.Allowed() or not ns.CanRead(message) or #message > ns.Engine.MAX_TEXT then return end
    -- Chat events are independent of chat-frame filter/suppression callbacks.
    local source = ns.ChatReviewSource(event, ...)
    if #recent >= 128 then table.remove(recent, 1) end
    recent[#recent + 1] = {text = message, source = source, at = ns.SessionTime()}
    timer = 0.1
end)
frame:SetScript("OnUpdate", function(_, elapsed)
    timer = timer + elapsed
    if timer < 0.1 then return end
    timer = 0
    ns.ScanBubbles()
end)
