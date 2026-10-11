-- Passive observation of the OlympusMute 1.3.2 sharing protocol.
-- No probes, replies, imported lists or inference from declined interactions.
local addon, ns = ...
local S = {}; ns.OlympusMuteSignal = S
local PREFIX, TITLE = "OMuteShare", "ChatWarden: OlympusMute Signal Detected"
local pending, observed = {}, {}
-- No age expiry. Bound storage to the 10,000 most recently observed characters.
local LIMIT = 10000
local function Clock()
    local value = ns.SafeNumber(ns.SafeCall(GetServerTime)) or ns.SafeNumber(ns.SafeCall(time))
    return value and value>0 and value<math.huge and math.floor(value) or nil
end
local tips = setmetatable({}, {__mode = "k"})
local channels = {WHISPER=true, PARTY=true, RAID=true, GUILD=true}
local function Realm()
    local value = ns.SafeCall(GetNormalizedRealmName) or ns.SafeCall(GetRealmName)
    return ns.CanRead(value) and ns.Engine.Lower((value:gsub("[%s%-]", ""))) or nil
end
local function Key(name, realm)
    if not ns.CanRead(name) or #name == 0 or #name > 128 or name:find("[%z\1-\32\127|:]") then return end
    local base, suffix = name:match("^([^%-]+)%-(.+)$")
    if base then name, realm = base, suffix end
    realm = ns.CanRead(realm) and realm ~= "" and ns.Engine.Lower((realm:gsub("[%s%-]", ""))) or Realm()
    if not realm or realm == "" or #realm > 128 or realm:find("[%z\1-\31\127|:]") then return end
    return ns.Engine.Lower(name) .. "-" .. realm
end
function S.Initialize()
    pending, observed = {}, {}
    local now=Clock()
    local saved=ns.DB and ns.DB.olympusMuteSeen
    if now and type(saved)=="table" then
        for who,seen in pairs(saved) do
            if ns.CanRead(who) and who:find("-",1,true) and Key(who)==who
                and type(seen)=="number" and seen==seen and seen%1==0
                and seen>0 and seen<=now then observed[who]=seen end
        end
    end
    local entries={}
    for who,seen in pairs(observed) do entries[#entries+1]={who=who,seen=seen} end
    table.sort(entries,function(a,b) return a.seen>b.seen or a.seen==b.seen and a.who<b.who end)
    for i=LIMIT+1,#entries do observed[entries[i].who]=nil end
    if ns.DB then ns.DB.olympusMuteSeen=observed end
end
function S.SettingsChanged()
    pending={}
    if ns.ScanTooltips then ns.ScanTooltips() end
end
local function UnitKey(unit)
    if not ns.CanRead(unit) then return end
    local fn = UnitFullName or UnitName
    if type(fn) ~= "function" then return end
    local ok, name, realm = pcall(fn, unit)
    if ok and ns.Readable(name) and ns.Readable(realm) then return Key(name, realm) end
end
local function ValidPayload(payload)
    if #payload > 4400 or payload:sub(1, 3) ~= "v1;" then return false end
    local counts, found = {g=0, w=0}, 0
    for item in (payload:sub(4) .. ";"):gmatch("([^;]*);") do
        local kind, value = item:match("^([gw]):(.+)$")
        if not kind then return false end
        -- Reject malformed escaping and markup; the content is discarded.
        if value:gsub("%%%x%x", ""):find("%%") then return false end
        value = value:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
        if value:find("[%z\1-\31\127|]") then return false end
        counts[kind], found = counts[kind] + 1, found + 1
        if counts[kind] > 100 then return false end
    end
    return found > 0
end
function S.Observe(prefix, text, channel, sender)
    if not ns.Active("olympusMuteSignal") or not ns.CanRead(prefix) or prefix ~= PREFIX
        or not ns.CanRead(text) or #text > 240 or not ns.CanRead(channel) or not channels[channel] then return end
    local who = Key(sender)
    if not who or who == UnitKey("player") then return end
    local id, index, total, part = text:match("^(%d+):(%d+)/(%d+):(.*)$")
    if not id or #id ~= 5 or tonumber(id) < 10000 or #index > 2 or #total > 2 or #part > 220 then return end
    index, total = tonumber(index), tonumber(total)
    if total < 1 or total > 20 or index < 1 or index > total then return end
    local now, count = ns.SessionTime(), 0
    for key, entry in pairs(pending) do
        if now - entry.time > 30 then pending[key] = nil else count = count + 1 end
    end
    local slot = who .. ":" .. channel .. ":" .. id
    local entry = pending[slot]
    if not entry then
        if count >= 16 then return end
        entry = {time=now, total=total, parts={}, count=0}; pending[slot] = entry
    end
    if total ~= entry.total or entry.parts[index] and entry.parts[index] ~= part then pending[slot] = nil; return end
    if entry.parts[index] then return end
    entry.parts[index], entry.count = part, entry.count + 1
    if entry.count < total then return end
    pending[slot] = nil
    if not ValidPayload(table.concat(entry.parts)) then return end
    local timestamp=Clock()
    if not timestamp then return end -- session timers cannot be persisted
    if not observed[who] then
        local size, oldest, oldestTime = 0, nil, math.huge
        for key, seen in pairs(observed) do
            size = size + 1
            if seen < oldestTime then oldest, oldestTime = key, seen end
        end
        if size >= LIMIT then observed[oldest] = nil end
    end
    observed[who] = timestamp
    ns.DB.olympusMuteSeen=observed
    if ns.ScanTooltips then ns.ScanTooltips() end
end
function S.ClearTooltip(tip) tips[tip] = nil end
local function OwnTitle(tip, state)
    local region = state and _G[state.name .. "TextLeft" .. state.first]
    return region and ns.SafeCall(region.GetText, region) == TITLE
end
local function SeenText(now, seen)
    local age = math.max(0, math.floor((now - seen) / 60))
    local label=age==0 and "just now" or age<60 and age.." min ago"
        or age<1440 and math.floor(age/60).." hr ago" or math.floor(age/1440).." days ago"
    return "Compatible sharing last observed " .. label .. "."
end
function S.IsTooltipLine(tip, index)
    local state = tips[tip]
    return state and index >= state.first and index <= state.first + 1 and OwnTitle(tip, state)
end
function S.UpdateTooltip(tip, name)
    local who
    if ns.Active("olympusMuteSignal") and type(tip.GetUnit) == "function" then
        local ok, _, unit = pcall(tip.GetUnit, tip)
        if ok and ns.CanRead(unit) and ns.Checked(ns.SafeCall(UnitIsPlayer, unit)) then who = UnitKey(unit) end
    end
    local seen = who and observed[who]
    local now=Clock()
    if seen and (not now or seen>now) then seen=nil end
    local state = tips[tip]
    if OwnTitle(tip, state) then
        if state.who == who and seen then
            local line = _G[state.name .. "TextLeft" .. (state.first+1)]
            if line and line.SetText then line:SetText(SeenText(now,seen)) end
            return
        end
        -- Remove only our own text if a tooltip is reused without clearing.
        for i=state.first,state.first+1 do
            local region = _G[state.name .. "TextLeft" .. i]
            if region and region.SetText then region:SetText("") end
        end
    end
    tips[tip] = nil
    if not seen or not tip.AddLine then return end
    local count = ns.SafeNumber(ns.SafeCall(tip.NumLines, tip))
    if not count then return end
    tips[tip] = {who=who, name=name, first=count+1}
    tip:AddLine(TITLE, 1, 0.72, 0.25, true)
    tip:AddLine(SeenText(now,seen), 0.75, 0.75, 0.75, true)
    tip:Show()
end
local registered = false
local events = CreateFrame("Frame")
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "CHAT_MSG_ADDON"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then S.Observe(...); return end
    if event == "ADDON_LOADED" and ... ~= addon then return end
    if not registered then
        local fn = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
        if type(fn) == "function" then
            local ok, result = pcall(fn, PREFIX)
            registered = ok and result ~= false
        end
    end
end)
