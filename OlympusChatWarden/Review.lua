-- Session-only blocked-message inbox. No chat/player metadata in SavedVariables.
local _, ns = ...
local R = {entries = {}, byKey = {}, bytes = 0, nextID = 0,
    MAX_ENTRIES = 200, MAX_BYTES = 1048576, MAX_TEXT = 8192, MAX_MATCHES = 32}
ns.Review = R

function ns.Readable(value)
    return not (issecretvalue and issecretvalue(value))
        and not (canaccessvalue and not canaccessvalue(value))
end
function ns.SafeString(value, limit)
    if not ns.CanRead(value) then return nil end
    return value:sub(1, limit or 256)
end
function ns.SafeNumber(value)
    if not ns.Readable(value) or type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge then return nil end
    return value
end
function ns.SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and ns.Readable(value) then return value end
end
function ns.SessionTime()
    return ns.SafeNumber(ns.SafeCall(GetTime)) or 0
end
local function Timestamp()
    return ns.SafeNumber(ns.SafeCall(time)) or ns.SafeNumber(ns.SafeCall(GetServerTime))
end
function R.TimeLabel(entry)
    if entry.timestamp and date then
        local label = ns.SafeCall(date, "%Y-%m-%d %H:%M:%S", entry.timestamp)
        if ns.CanRead(label) then return label end
    end
    return string.format("Session +%.1fs", entry.sessionTime or 0)
end
function R.IsUnreadAlert(entry)
    return entry and entry.hiddenMessage == true and entry.action == "Hidden" and not entry.read
end
function R.Unread()
    local count = 0
    for _, entry in ipairs(R.entries) do if R.IsUnreadAlert(entry) then count = count + 1 end end
    return count
end
function R.Notify()
    if ns.QueueReviewRefresh then ns.QueueReviewRefresh() end
    if ns.OlympusIntegration then ns.OlympusIntegration.UpdateAlerts() end
end
function R.Clear()
    R.entries, R.byKey, R.bytes = {}, {}, 0
    R.Notify()
end
function R.Remove(id)
    for i, entry in ipairs(R.entries) do
        if entry.id == id then
            table.remove(R.entries, i); R.bytes = R.bytes - entry.bytes
            if entry.key then R.byKey[entry.key] = nil end
            R.Notify(); return true
        end
    end
    return false
end
function R.Mark(id, decision)
    for _, entry in ipairs(R.entries) do
        if entry.id == id then entry.read, entry.decision = true, decision or entry.decision; R.Notify(); return true end
    end
    return false
end
function R.Get(id)
    for _, entry in ipairs(R.entries) do if entry.id == id then return entry end end
end
function R.Source(entry)
    local label = ({player = "Player chat", npc = "NPC chat", quest = "Quest", gossip = "Gossip",
        barber = "Barber shop", talkingHead = "Talking head", bubble = "Chat bubble", demo = "Local test", vendor = "Vendor text", olympus = "Olympus addon", playerName = "Player name", npcName = "NPC name", targetName = "Target-frame name", tooltip = "Tooltip"})[entry.kind] or "UI text"
    return label .. (entry.questTitle and (": " .. entry.questTitle) or entry.sender and (": " .. entry.sender)
        or entry.npc and (": " .. entry.npc) or "")
end
local fields = {"kind", "event", "sender", "guid", "class", "channel", "npc", "questTitle", "panel", "zone", "shieldReason"}
function R.Add(original, matches, source, key, rendered)
    if not ns.DB or not ns.CanRead(original) or (#matches == 0 and not (source and (source.shield or source.language))) then return nil end
    local action, confidence = ns.MatchAction(matches)
    if source and source.language and ns.Language then
        action=ns.Language.Action(action,source.language)
        if #matches==0 then confidence='Language: '..source.language.confidence end
    end
    if source and source.shield then action, confidence = "Hidden", "Contact shield" end
    if source and source.displayOnly and action=='Hidden' then action='Redacted' end
    if ns.DB.history == false and action ~= "Hidden" then return nil end
    source = source or {}
    key = ns.SafeString(key, 512)
    if key and R.byKey[key] then return R.byKey[key] end
    R.nextID = R.nextID + 1
    local entry = {id = R.nextID, key = key, timestamp = Timestamp(), sessionTime = ns.SessionTime(),
        original = ns.Reports.Clip(original, R.MAX_TEXT), truncated = #original > R.MAX_TEXT,
        originalBytes = #original, matches = {}, matchCount = #matches, score = 0,
        preset = ns.DB.preset, context = ns.DB.context, read = false, decision = "Unreviewed"}
    entry.action, entry.confidence = action, confidence
    entry.hiddenMessage = source.hiddenMessage == true and action == "Hidden"
    entry.addonVersion, entry.ruleVersion = ns.VERSION, ns.RULE_VERSION or "stock-1"
    entry.threshold, entry.exceptionCount = ns.Confidence.Presets[ns.DB.preset], #ns.DB.exceptions
    entry.disabledPacks = {}
    entry.packPresets = ns.Reports.PackPresets(ns.DB.packPresets)
    for _, pack in ipairs(ns.PackNames) do entry.disabledPacks[pack] = ns.DB.disabledPacks[pack] == true end
    entry.rendered = ns.SafeString(rendered, R.MAX_TEXT)
    entry.renderedTruncated = ns.CanRead(rendered) and #rendered > R.MAX_TEXT or false
    for _, name in ipairs(fields) do entry[name] = ns.SafeString(source[name], name == "questTitle" and 256 or 128) end
    entry.questID = ns.SafeNumber(source.questID)
    entry.captureID = "review:" .. tostring(ns.SessionTime()) .. ":" .. entry.id
    entry.captureSnapshot = ns.Reports.Snapshot(original, entry.kind, entry.event,nil,source)
    entry.captureSnapshot.actualAction = action
    if source.shield then entry.captureSnapshot.shieldReason = source.shieldReason end
    if source.language and ns.Language then
        entry.language=ns.Language.Copy(source.language)
        entry.captureSnapshot.language=entry.language
    end
    for i, match in ipairs(matches) do
        entry.score = math.max(entry.score, match.score or 0)
        if i <= R.MAX_MATCHES then
            local copy = {score = match.score, threshold = match.threshold, accepted = match.accepted, gommage = match.gommage == true,
                first=match.first,last=match.last}
            for _, name in ipairs({"phrase", "pack", "id", "origin", "reason", "replacement", "action"}) do copy[name] = ns.SafeString(match[name], 512) end
            entry.matches[#entry.matches + 1] = copy
        end
    end
    if source.displayOnly then
        entry.captureSnapshot.displayOnly=true
        entry.captureSnapshot.nameDisplay=source.nameDisplay==true
        entry.captureSnapshot.coverageEnabled=true
        entry.captureSnapshot.combinedPredictedAction=action
        entry.captureSnapshot.matches=entry.matches
        entry.captureSnapshot.matchCount=#matches
    end
    -- Include strings/metadata in the eviction budget, not only the message body.
    local bytes = #entry.original + #(entry.rendered or "") + #(entry.key or "")
        + #entry.addonVersion + #entry.ruleVersion + #ns.Reports.JSON(entry.captureSnapshot)
        + (entry.language and #ns.Reports.JSON(entry.language) or 0)
    for _, name in ipairs(fields) do bytes = bytes + #(entry[name] or "") end
    for _, match in ipairs(entry.matches) do
        for _, name in ipairs({"phrase", "pack", "id", "origin", "reason", "replacement", "action"}) do bytes = bytes + #(match[name] or "") end
    end
    entry.bytes = bytes
    while #R.entries >= R.MAX_ENTRIES or R.bytes + bytes > R.MAX_BYTES do
        local old = table.remove(R.entries, 1)
        if not old then return nil end
        R.bytes = R.bytes - old.bytes
        if old.key then R.byKey[old.key] = nil end
    end
    R.entries[#R.entries + 1] = entry
    R.bytes = R.bytes + bytes
    if key then R.byKey[key] = entry.id end
    R.Notify()
    return entry.id
end

function ns.ChatReviewSource(event, ...)
    local sender, channel, channelBaseName = select(1, ...), select(3, ...), select(8, ...)
    local lineID, guid = select(10, ...), select(11, ...)
    local source = {kind = event:find("CHAT_MSG_MONSTER_", 1, true) and "npc" or "player",
        event = event, sender = ns.SafeString(sender, 128), guid = ns.SafeString(guid, 128),
        channel = ns.SafeString(channelBaseName, 128) or ns.SafeString(channel, 128)}
    if source.kind == "player" and source.guid then
        source.class = ns.SafeString(ns.SafeCall(GetPlayerInfoByGUID, source.guid), 128)
    end
    local id = ns.SafeNumber(lineID)
    -- Chat argument 11 (message included) identifies a line across chat windows.
    local key = id and id > 0 and ("chat:" .. event .. ":" .. tostring(id)) or nil
    return source, key
end
function ns.ChatFallbackKey(event, message, source)
    -- For events without a readable line ID, coalesce same-frame callbacks.
    -- Hash is bounded; no complete-message duplicate is retained in the key index.
    local hash = 5381
    for i = 1, #message do hash = (hash * 33 + message:byte(i)) % 4294967296 end
    return "fallback:" .. event .. ":" .. (source.sender or "?") .. ":"
        .. tostring(math.floor(ns.SessionTime() * 4)) .. ":" .. tostring(#message) .. ":" .. tostring(hash)
end
function ns.UIReviewSource(kind, panel, useQuestLog)
    local source = {kind = kind, panel = panel,
        zone = ns.SafeString(ns.SafeCall(GetRealZoneText), 128)}
    if kind == "quest" then
        source.questID = ns.SafeNumber(ns.SafeCall(useQuestLog and C_QuestLog and C_QuestLog.GetSelectedQuest or GetQuestID))
        if source.questID and source.questID <= 0 then source.questID = nil end
        if source.questID and C_QuestLog and C_QuestLog.GetTitleForQuestID then
            source.questTitle = ns.SafeString(ns.SafeCall(C_QuestLog.GetTitleForQuestID, source.questID), 256)
        end
        if not source.questTitle and not useQuestLog then source.questTitle = ns.SafeString(ns.SafeCall(GetTitleText), 256) end
    end
    if (kind == "quest" and not useQuestLog) or kind == "gossip" then source.npc = ns.SafeString(ns.SafeCall(UnitName, "npc"), 128) end
    if kind == "talkingHead" and TalkingHeadFrame and TalkingHeadFrame.NameFrame and TalkingHeadFrame.NameFrame.Name then
        source.npc = ns.SafeString(ns.SafeCall(TalkingHeadFrame.NameFrame.Name.GetText, TalkingHeadFrame.NameFrame.Name), 128)
    end
    return source
end
