-- Toggle only this addon's links in-place, retaining native chat history/order.
local _, ns = ...
local C = {MAX_ENTRIES = 4096, MAX_BYTES = 1048576, bytes = 0}
ns.ChatReveal = C
local cells, byKey, order, cursor, nextID = {}, {}, {}, 1, 0
local frames = setmetatable({}, {__mode = "k"})
local pending, installed, fallbackQueue, fallbackFrame = {}, false, {}
local session = tostring(math.floor((GetTime and GetTime() or 0) * 1000)) .. tostring(math.random(10000, 99999))
local prefix = "addon:OlympusChatWarden:" .. session .. ":"
local pattern = "(|H" .. prefix .. "(%d+)|h)(.-)(|h)"
local function SafeFrame(frame)
    return ns.Readable(frame) and frame and frame ~= UIParent
        and not (frame.IsForbidden and frame:IsForbidden())
        and not (frame.IsProtected and frame:IsProtected())
end
function C.RegisterFrame(frame) if SafeFrame(frame) then frames[frame] = true end end
function C.Rewrite(text)
    if not ns.CanRead(text) or not text:find("|H" .. prefix, 1, true) then return text end
    return (text:gsub(pattern, function(open, id, label, close)
        local cell = cells[tonumber(id)]
        return open .. (cell and (cell.shown and cell.gray or cell.bars) or label) .. close
    end))
end
local function RewriteFrame(frame)
    if not SafeFrame(frame) then return 0 end
    local changed = 0
    if type(frame.ForEachMessage) == "function" then
        -- The native iterator exposes each entry; change only its message text.
        -- Timestamps, channel data, colors, scroll position and ordering survive.
        local ok = pcall(frame.ForEachMessage, frame, function(entry)
            if ns.Readable(entry) and type(entry) == "table" and ns.CanRead(entry.message) then
                local updated = C.Rewrite(entry.message)
                if updated ~= entry.message then entry.message = updated; changed = changed + 1 end
            end
            return false
        end)
        if ok and changed > 0 then
            if frame.MarkDisplayDirty then pcall(frame.MarkDisplayDirty, frame) end
            if frame.RefreshIfNecessary then pcall(frame.RefreshIfNecessary, frame) end
            return changed
        end
    elseif type(frame.TransformMessages) == "function" then
        pcall(frame.TransformMessages, frame,
            function(message) return ns.CanRead(message) and C.Rewrite(message) ~= message end,
            function(message, r, g, b, ...)
                changed = changed + 1
                return C.Rewrite(message), r, g, b, ...
            end)
        if changed > 0 then
            if frame.RefreshIfNecessary then pcall(frame.RefreshIfNecessary, frame) end
            return changed
        end
    end
    -- Compatibility for accessible custom chat displays: only descendants of
    -- a known chat frame and only fontstrings containing our own link markup.
    local visited, hooks = 0, C.regionHooks
    if not hooks then hooks = setmetatable({}, {__mode = "k"}); C.regionHooks = hooks end
    local function Scan(root, depth)
        if visited >= 512 or depth > 4 or not SafeFrame(root) then return end
        visited = visited + 1
        for _, region in ipairs(root.GetRegions and {root:GetRegions()} or {}) do
            if region.GetObjectType and region:GetObjectType() == "FontString" and region.GetText and region.SetText
                and not (region.IsForbidden and region:IsForbidden()) then
                local text = region:GetText()
                if ns.CanRead(text) and text:find("|H" .. prefix, 1, true) then
                    if not hooks[region] then
                        local writing = false
                        hooks[region] = true
                        hooksecurefunc(region, "SetText", function(self, value)
                            if writing or not ns.CanRead(value) then return end
                            local updated = C.Rewrite(value)
                            if updated ~= value then writing = true; self:SetText(updated); writing = false end
                        end)
                    end
                    local updated = C.Rewrite(text)
                    if updated ~= text then region:SetText(updated); changed = changed + 1 end
                end
            end
        end
        for _, child in ipairs(root.GetChildren and {root:GetChildren()} or {}) do Scan(child, depth + 1) end
    end
    pcall(Scan, frame, 0)
    return changed
end
local function Refresh()
    local changed = 0
    for frame in pairs(frames) do
        if ns.ChatFonts then ns.ChatFonts.Prepare(frame) end
        changed = changed + RewriteFrame(frame)
    end
    if ns.ChatFonts then ns.ChatFonts.Refresh() end
    return changed
end
local function Evict(slot)
    local id = order[slot]
    local old = id and cells[id]
    if old then
        if old.shown then old.shown = false; Refresh() end
        C.bytes = C.bytes - old.bytes
        if old.key then byKey[old.key] = nil end
        cells[id] = nil
    end
    order[slot] = nil
end
function ns.Marker(original, match, owner, key, restoreColor, layoutPrefix)
    C.RegisterFrame(owner)
    local unique = key and (key .. ":" .. match.first .. ":" .. match.last)
    local id = unique and byKey[unique]
    if not id or not cells[id] then
        local bars, gray = ns.BarText(original, owner, layoutPrefix), ns.GrayText(original, owner, restoreColor)
        local bytes = #original + #bars + #gray + #(unique or "") + 128
        if bytes > C.MAX_BYTES then return bars end
        Evict(cursor)
        while C.bytes + bytes > C.MAX_BYTES do
            cursor = cursor % C.MAX_ENTRIES + 1
            Evict(cursor)
        end
        nextID = nextID + 1; id = nextID
        cells[id] = {bars = bars, gray = gray, shown = false, key = unique, bytes = bytes}
        C.bytes = C.bytes + bytes
        order[cursor] = id; cursor = cursor % C.MAX_ENTRIES + 1
        if unique then byKey[unique] = id end
    end
    local cell = cells[id]
    return "|H" .. prefix .. id .. "|h" .. (cell.shown and cell.gray or cell.bars) .. "|h"
end
local function Toggle(link, frame)
    local id = tonumber(link:match("^" .. prefix .. "(%d+)$"))
    local cell = id and cells[id]
    if not cell then return end
    C.RegisterFrame(frame)
    cell.shown = not cell.shown
    if Refresh() == 0 then
        cell.shown = not cell.shown
        ns.Print("This chat display could not update the line. You can read the original in Review messages.")
    end
end
function ns.OnLink(link, frame, button)
    if not ns.CanRead(link) or not ns.Readable(button) or not ns.Readable(frame) or button ~= "LeftButton"
        or not ns.RevealModifier or not ns.RevealModifier() then return end
    local name=ns.LanguageDisplay and ns.LanguageDisplay.CanReveal(link)
    if not name and not link:match("^" .. prefix .. "%d+$") then return end
    if pending[link] then return end
    pending[link] = true
    -- Native click and SetItemRef callbacks may describe the same click.
    -- Coalesce them, then update text after native input handling completes.
    local function Run()
        pending[link] = nil
        if not ns.Membership.Allowed() then return end
        if name then ns.LanguageDisplay.Toggle(link,frame) else Toggle(link,frame) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Run)
    else
        if not fallbackFrame then fallbackFrame = CreateFrame("Frame") end
        fallbackQueue[#fallbackQueue + 1] = Run
        fallbackFrame:SetScript("OnUpdate", function(self)
            self:SetScript("OnUpdate", nil)
            local queued = fallbackQueue; fallbackQueue = {}
            for _, callback in ipairs(queued) do callback() end
        end)
    end
end
function C.Install()
    if installed then return end
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkClick", function(_, frame, link, _, button)
            ns.OnLink(link, frame, button)
        end, C)
        EventRegistry:RegisterCallback("SetItemRef", function(_, link, _, button, frame)
            ns.OnLink(link, frame, button)
        end, C)
        installed = true
    elseif type(SetItemRef) == "function" then
        hooksecurefunc("SetItemRef", function(link, _, button, frame) ns.OnLink(link, frame, button) end)
        installed = true
    end
end
