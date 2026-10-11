-- Explicit user reports; no network submission or automatic rule learning.
local _, ns = ...
local R = {MAX_MATCHES = 32}
ns.Reports = R
local actions = {Unchanged = true, Warning = true, Redacted = true, Hidden = true, Replaced = true}
function R.Clip(text, limit)
    if not ns.CanRead(text) then return "" end
    local n = math.min(#text, limit)
    while n > 0 and text:byte(n + 1) and text:byte(n + 1) >= 128 and text:byte(n + 1) <= 191 do n = n - 1 end
    return text:sub(1, n)
end
local function Quote(text)
    return '"' .. text:gsub('[%z\1-\31\\"|]', function(c)
        if c == '"' then return '\\"' end
        if c == '\\' then return '\\\\' end
        return string.format('\\u%04x', c:byte())
    end) .. '"'
end
function R.JSON(value, array, depth)
    local kind = type(value)
    if kind == "string" then return Quote(value) end
    if kind == "boolean" then return value and "true" or "false" end
    if kind == "number" then return ns.SafeNumber(value) and tostring(value) or "null" end
    if kind ~= "table" then return "null" end
    local parts, childDepth = {}, depth and depth + 1 or nil
    local indent = depth and ("\n" .. string.rep("  ", depth + 1)) or ""
    local ending = depth and ("\n" .. string.rep("  ", depth)) or ""
    if array then
        for _, item in ipairs(value) do parts[#parts + 1] = R.JSON(item, false, childDepth) end
        return #parts == 0 and "[]" or "[" .. indent .. table.concat(parts, "," .. indent) .. ending .. "]"
    end
    local keys = {}; for key in pairs(value) do if type(key) == "string" then keys[#keys + 1] = key end end
    table.sort(keys)
    for _, key in ipairs(keys) do
        parts[#parts + 1] = Quote(key) .. (depth and ": " or ":")
            .. R.JSON(value[key], key == "matches" or key == "records", childDepth)
    end
    return #parts == 0 and "{}" or "{" .. indent .. table.concat(parts, "," .. indent) .. ending .. "}"
end
local function Packs(source)
    local packs = {}
    for _, pack in ipairs(ns.RulePacks.Order) do
        if source and source[pack] ~= nil then packs[pack] = source[pack] == true end
    end
    return packs
end
function R.PackPresets(source)
    local presets = {}
    for _, pack in ipairs(ns.RulePacks.Order) do
        local value = source and source[pack]
        if value ~= nil then presets[pack] = ns.Confidence.Presets[value] and value or "default" end
    end
    return presets
end
local function Scope(source)
    return ({player = "chat", npc = "npc", bubble = "bubbles", barber = "barber",
        vendor = "vendor", olympus = "olympusText", playerName = "playerNames", npcName = "npcNames", targetName = "targetNames", tooltip = "tooltips", talkingHead = "talkingHead", quest = "dialogue", gossip = "dialogue", demo = "preview"})[source]
end
function R.Snapshot(text, source, event, policy, sourceInfo)
    local settings = policy or ns.DB
    local scope = Scope(source)
    local active = settings.enabled ~= false and (not scope or ns.DB[scope] ~= false)
    if policy and policy.chatEnabled ~= nil then active = policy.enabled and policy.chatEnabled and policy.adapterSupported end
    local matches, candidates, err = ns.Confidence.Analyze(ns.Matcher, text, settings, ns.ExceptionMatcher)
    local predicted, _, score = ns.MatchAction(matches)
    local retained = {}
    for i, hit in ipairs(candidates) do
        if i > R.MAX_MATCHES then break end
        local copy = {score = hit.score, threshold = hit.threshold, accepted = hit.accepted, gommage = hit.gommage == true,
            first = hit.first, last = hit.last}
        for _, field in ipairs({"phrase", "pack", "id", "origin", "reason", "replacement", "action"}) do copy[field] = R.Clip(hit[field], 512) end
        retained[#retained + 1] = copy
    end
    local languageContext=ns.Language and ns.Language.Context(text,event,sourceInfo or {kind=source})
    local language=languageContext and languageContext.result
    local combined=language and ns.Language.Action(active and predicted or 'Unchanged',language) or active and predicted or 'Unchanged'
    return {addonVersion = ns.VERSION, ruleVersion = ns.RULE_VERSION, preset = settings.preset,
        context = settings.context ~= false, bodyTypeWording = settings.barber ~= false, threshold = ns.Confidence.Presets[settings.preset],
        disabledPacks = Packs(settings.disabledPacks), packPresets = R.PackPresets(settings.packPresets),
        signedPacks = ns.RulePacks.Snapshot(),
        packsVerifying = ns.RulePacks.Restoring == true,
        exceptionCount = settings.exceptionCount or #ns.DB.exceptions,
        enabled = settings.enabled ~= false, coverageEnabled = active == true,
        actualAction = combined, predictedAction = predicted, wordPredictedAction=predicted,combinedPredictedAction=combined,
        language=language,languageContext=languageContext,
        score = score, event = event, matches = retained, matchCount = #candidates,
        diagnosticError = err, metadataKnown = true, analysisTiming = "message-capture"}
end
function R.ReviewDraft(entry)
    return {captureSnapshot = entry.captureSnapshot, originalTruncated = entry.truncated == true,
        captureID = entry.captureID, capturedTimestamp = entry.timestamp, capturedSessionTime = entry.sessionTime,
        event = entry.event, reportMethod = "review", selection = "review-original"}
end
function R.Normalize(record)
    if type(record) ~= "table" or not ns.CanRead(record.original) or not actions[record.expectedAction] then return end
    local out = {original = R.Clip(record.original, 8192), note = R.Clip(record.note, 1000),
        originalTruncated = record.originalTruncated == true or #record.original > 8192,
        expectedAction = record.expectedAction, feedback = R.Clip(record.feedback, 64),
        source = R.Clip(record.source, 64), id = ns.SafeNumber(record.id), timestamp = ns.SafeNumber(record.timestamp),
        captureID = R.Clip(record.captureID, 256), matches = {}}
    for _, key in ipairs({"addonVersion", "ruleVersion", "preset", "event", "reportMethod", "selection", "diagnosticError", "analysisTiming", "shieldReason"}) do
        if ns.CanRead(record[key]) then out[key] = R.Clip(record[key], 256) end
    end
    for _, key in ipairs({"capturedTimestamp", "capturedSessionTime", "score", "threshold", "exceptionCount", "matchCount"}) do
        out[key] = ns.SafeNumber(record[key])
    end
    for _, key in ipairs({"context", "enabled", "coverageEnabled", "packsVerifying", "bodyTypeWording", "displayOnly", "nameDisplay"}) do
        if type(record[key]) == "boolean" then out[key] = record[key] end
    end
    out.actualAction = actions[record.actualAction] and record.actualAction or nil
    out.predictedAction = actions[record.predictedAction] and record.predictedAction or nil
    out.wordPredictedAction=actions[record.wordPredictedAction] and record.wordPredictedAction or nil
    out.combinedPredictedAction=actions[record.combinedPredictedAction] and record.combinedPredictedAction or nil
    out.metadataKnown = record.metadataKnown == true or out.actualAction ~= nil and out.preset ~= nil
    if record.language and ns.Language then out.language=ns.Language.Copy(record.language) end
    if record.languageContext and ns.Language then out.languageContext=ns.Language.CopyContext(record.languageContext) end
    if type(record.disabledPacks) == "table" then out.disabledPacks = Packs(record.disabledPacks) end
    if type(record.packPresets) == "table" then out.packPresets = R.PackPresets(record.packPresets) end
    if type(record.signedPacks) == "table" then
        out.signedPacks = {}
        for _, id in ipairs(ns.RulePacks.Order) do
            local pack = record.signedPacks[id]
            if type(pack) == "table" and ns.SafeNumber(pack.version) and type(pack.digest) == "string"
                and #pack.digest == 64 and not pack.digest:find("[^0-9a-f]") and type(pack.keyID) == "string"
                and #pack.keyID == 16 and not pack.keyID:find("[^0-9a-f]") then
                out.signedPacks[id] = {version = pack.version, digest = pack.digest, keyID = pack.keyID, enabled = pack.enabled == true}
            end
        end
    end
    for i, hit in ipairs(type(record.matches) == "table" and record.matches or {}) do
        if i > R.MAX_MATCHES then break end
        if type(hit) == "table" then
            local copy = {score = ns.SafeNumber(hit.score), threshold = ns.SafeNumber(hit.threshold), accepted = hit.accepted == true, gommage = hit.gommage == true,
                first = ns.SafeNumber(hit.first), last = ns.SafeNumber(hit.last)}
            for _, key in ipairs({"phrase", "pack", "id", "origin", "reason", "replacement", "action"}) do copy[key] = R.Clip(hit[key], 512) end
            out.matches[#out.matches + 1] = copy
        end
    end
    out.matchCount = out.matchCount or #out.matches
    out.matchesTruncated = record.matchesTruncated == true or out.matchCount > #out.matches
    return out
end
function R.Build(original, action, note, source, draft, feedback)
    draft = draft or {}
    local snapshot = draft.captureSnapshot or R.Snapshot(original, source, draft.event)
    local record = {}
    for key, value in pairs(snapshot) do record[key] = value end
    if not draft.captureSnapshot then
        -- A pasted example was not observed by the addon at message time.
        -- Export the current analysis without claiming a historic decision.
        record.actualAction, record.analysisTiming = nil, "report-save"
    end
    record.original, record.expectedAction, record.note, record.source = original, action, note, source
    record.feedback, record.captureID = feedback or "Missed match", draft.captureID
    record.originalTruncated = draft.originalTruncated == true
    record.timestamp = ns.SafeNumber(ns.SafeCall(time)) or ns.SafeNumber(ns.SafeCall(GetServerTime))
    record.capturedTimestamp, record.capturedSessionTime = draft.capturedTimestamp, draft.capturedSessionTime
    record.reportMethod, record.selection = draft.reportMethod or "manual", draft.selection
    return R.Normalize(record)
end
function R.Export(mode)
    if ns.Export then return (ns.Export.Build(ns.Export.Batch('reports',mode))) end
    local records = {}
    for _, record in ipairs(ns.Personal.reports) do
        if mode ~= "misses" or record.feedback == "Missed match" then records[#records + 1] = R.Normalize(record) end
    end
    return R.JSON({schema = 3, addon = "OlympusChatWarden", displayName = ns.NAME,
        exportVersion = ns.VERSION, scope = mode == "misses" and "Missed messages" or "User reports",
        recordCount = #records, totalSavedRecords = #ns.Personal.reports, records = records,
        privacy = "Dedicated player names, GUIDs and channel fields are omitted. Original text, including reported names, and notes may identify people; check before sharing."}, false, 0)
end
