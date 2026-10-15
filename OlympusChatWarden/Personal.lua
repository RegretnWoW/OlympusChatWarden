-- Saved user reports and explicit personal rules.
local _, ns = ...
local P = {MAX_RULES = 200, MAX_REPORTS = 200, MAX_BYTES = 1048576, rules = {}, reports = {}}
ns.Personal = P
ns.RULE_VERSION = (ns.RULE_VERSION or "stock") .. "-personal-2-replacement-1"
local scores = {Unchanged = 0, Warning = 55, Redacted = 80, Hidden = 95, Replaced = 80}
local function Copy(item) local copy = {}; for k, v in pairs(item) do copy[k] = v end; return copy end
local function Clip(text, limit)
    if not ns.CanRead(text) then return "" end
    local n = math.min(#text, limit)
    while n > 0 and text:byte(n + 1) and text:byte(n + 1) >= 128 and text:byte(n + 1) <= 191 do n = n - 1 end
    return text:sub(1, n)
end
local function Compile(rules)
    local phrases, byPhrase = {}, {}
    for _, rule in ipairs(rules) do
        if rule.enabled then phrases[#phrases + 1] = rule.phrase; byPhrase[rule.phrase] = rule end
    end
    local matcher, err = ns.Engine.Compile(phrases)
    return matcher, byPhrase, err
end
local function Commit(rules, matcher, byPhrase)
    P.rules, P.matcher, P.byPhrase = rules, matcher, byPhrase
    ns.DB.personalRules = rules; ns.PolicyChanged()
    if ns.RefreshPersonal then ns.RefreshPersonal() end
end
function P.ValidateReplacement(text)
    if not ns.CanRead(text) or #text < 1 or #text > 120 or text:match("^%s*$")
        or text:find("[|%c]") or text:find("[^ -~]") then
        return nil, "Enter 1-120 printable English characters, without markup or line breaks."
    end
    return text
end
function P.PrepareRule(phrase, action, id, original, enabled, replacement)
    if scores[action] == nil then return nil, "Choose a rule action." end
    if action == "Replaced" then
        local clean, err = P.ValidateReplacement(replacement)
        if not clean then return nil, err end
        replacement = clean
    end
    local clean, err = ns.Engine.Validate({phrase})
    if not clean or #clean ~= 1 then return nil, err or "Enter a phrase." end
    phrase = clean[1]
    if original then
        local probe = ns.Engine.Compile({phrase})
        if #probe:Find(original) == 0 then return nil, "Choose exact words from the message, outside hyperlinks or markup." end
    end
    local rules, selected, highest = {}, nil, 0
    for _, rule in ipairs(P.rules) do
        local copy = Copy(rule); rules[#rules + 1] = copy; highest = math.max(highest, rule.id)
        if id == rule.id or not id and phrase == rule.phrase then selected = copy end
        if id and id ~= rule.id and phrase == rule.phrase then return nil, "That phrase already has a personal rule." end
    end
    if id and not selected then return nil, "That rule no longer exists." end
    if not selected then
        if #rules >= P.MAX_RULES then return nil, "Personal rule list is full (200). Remove a rule first." end
        selected = {id = highest + 1, enabled = true}; rules[#rules + 1] = selected
    end
    selected.phrase, selected.action = phrase, action
    selected.replacement = action == "Replaced" and replacement or nil
    if type(enabled) == "boolean" then selected.enabled = enabled end
    local matcher, byPhrase, compileError = Compile(rules)
    if not matcher then return nil, compileError end
    return {rules = rules, matcher = matcher, byPhrase = byPhrase, rule = selected}
end
function P.SaveRule(phrase, action, id, original, enabled, replacement)
    local prepared, err = P.PrepareRule(phrase, action, id, original, enabled, replacement)
    if not prepared then return false, err end
    Commit(prepared.rules, prepared.matcher, prepared.byPhrase)
    local message=prepared.rule.enabled and "Rule saved and enabled. Applies to new messages and supported text."
        or "Rule saved but switched off. Enable it to apply it."
    if prepared.rule.enabled and ns.DB.chat==false then message=message.." Player chat filtering is off in Settings." end
    return true, message, prepared.rule.id
end
function P.ChangeRule(id, enabled, remove)
    local rules, found = {}, false
    for _, rule in ipairs(P.rules) do
        local copy = Copy(rule)
        if rule.id == id then found = true; copy.enabled = enabled end
        if rule.id ~= id or not remove then rules[#rules + 1] = copy end
    end
    if not found then return false, "That rule no longer exists." end
    local matcher, byPhrase, err = Compile(rules)
    if not matcher then return false, err end
    Commit(rules, matcher, byPhrase); return true
end
function P.Hits(text,typoWork)
    if not P.matcher then return {} end
    local found, err = P.matcher:Find(text, true)
    if err then return {}, err end
    if typoWork then for _,hit in ipairs(ns.TypoFilter.Hits(P.matcher,text,found,typoWork)) do found[#found+1]=hit end end
    table.sort(found, function(a, b)
        if a.first~=b.first then return a.first<b.first end
        if a.last~=b.last then return a.last>b.last end
        return not a.typo and b.typo==true
    end)
    local hits, cursor = {}, 1
    for _, hit in ipairs(found) do
        if hit.first >= cursor then
        local phrase = P.matcher.rules[hit.rule]; local rule = P.byPhrase[phrase]
        hit.phrase, hit.score, hit.action = phrase, scores[rule.action], rule.action
        hit.replacement = rule.replacement
        hit.pack, hit.id, hit.origin = "personal", "personal:" .. rule.id, "saved personal phrase rule"
        hit.threshold, hit.reason = 0, "personal action: " .. rule.action
        if hit.typo then hit.reason=hit.reason..'; spelling guess: '..text:sub(hit.first,hit.last)..' -> '..phrase..' ('..hit.typoEdits..' edits)' end
        hits[#hits + 1] = hit; cursor = hit.last + 1
        end
    end
    return hits
end
function P.Initialize()
    P.rules, P.reports, P.reportBytes, P.nextReportID = {}, {}, 0, 0
    local seen, ids, highest = {}, {}, 0
    for i, rule in ipairs(type(ns.DB.personalRules) == "table" and ns.DB.personalRules or {}) do
        if i > P.MAX_RULES then break end
        if type(rule) == "table" and ns.CanRead(rule.phrase) and scores[rule.action] ~= nil and (rule.action ~= "Replaced" or P.ValidateReplacement(rule.replacement)) then
            local clean = ns.Engine.Validate({rule.phrase})
            if clean and clean[1] and not seen[clean[1]] then
                local id = ns.SafeNumber(rule.id)
                if not id or id < 1 or id % 1 ~= 0 or id > 1000000000 or ids[id] then id = highest + 1 end
                highest = math.max(highest, id); ids[id], seen[clean[1]] = true, true
                P.rules[#P.rules + 1] = {id = id, phrase = clean[1], action = rule.action, replacement = rule.action == "Replaced" and rule.replacement or nil, enabled = rule.enabled ~= false}
            end
        end
    end
    P.matcher, P.byPhrase = Compile(P.rules)
    local reportIDs = {}
    local function Import(report)
        local copy = ns.Reports.Normalize(report)
        if not copy or #P.reports >= P.MAX_REPORTS then return end
        local id = copy.id
        if not id or id < 1 or id % 1 ~= 0 or id > 1000000000 or reportIDs[id] then id = P.nextReportID + 1 end
        copy.id = id
        local bytes = #ns.Reports.JSON(copy)
        if P.reportBytes + bytes > P.MAX_BYTES then return end
        reportIDs[id] = true
        P.reports[#P.reports + 1] = copy; P.reportBytes = P.reportBytes + bytes
        P.nextReportID = math.max(P.nextReportID, id)
    end
    for _, report in ipairs(type(ns.DB.personalReports) == "table" and ns.DB.personalReports or {}) do Import(report) end
    ns.DB.personalRules, ns.DB.personalReports = P.rules, P.reports
    ns.PolicyChanged()
end
function P.SaveReport(original, action, note, source, draft, phrase, feedback)
    if not ns.CanRead(original) or original:match("^%s*$") then return false, "Enter the original message." end
    if scores[action] == nil then return false, "Choose the wanted action." end
    local prepared, err
    if phrase ~= nil then
        if #original > 8192 or draft and draft.originalTruncated then return false, "Save this shortened report first, then create a rule from a complete message." end
        prepared, err = P.PrepareRule(phrase, action, nil, original, true)
        if not prepared then return false, err end
    end
    local record = ns.Reports.Build(original, action, note, source or "manual", draft, feedback)
    if not record then return false, "Choose a report action and a complete message." end
    record.id = P.nextReportID + 1
    local index
    if record.captureID ~= "" then
        for i, saved in ipairs(P.reports) do if saved.captureID == record.captureID then index = i; record.id = saved.id end end
    end
    local bytes, replaced = #ns.Reports.JSON(record), index and #ns.Reports.JSON(P.reports[index]) or 0
    if not index and #P.reports >= P.MAX_REPORTS or P.reportBytes - replaced + bytes > P.MAX_BYTES then
        return false, "Saved reports are full. Export them, then remove a report before adding another."
    end
    if index then table.remove(P.reports, index) else P.nextReportID = record.id end
    P.reports[#P.reports + 1] = record; P.reportBytes = P.reportBytes - replaced + bytes
    if prepared then Commit(prepared.rules, prepared.matcher, prepared.byPhrase) end
    if ns.RefreshPersonal then ns.RefreshPersonal() end
    if ns.RefreshReview then ns.RefreshReview() end
    if ns.RefreshReportExport then ns.RefreshReportExport() end
    return true, prepared and "Report and personal phrase rule saved." or "Report saved. Your filtering rules have not changed.", record.id
end
function P.RemoveReport(id)
    for i, report in ipairs(P.reports) do
        if report.id == id then
            P.reportBytes = P.reportBytes - #ns.Reports.JSON(report); table.remove(P.reports, i)
            if ns.RefreshPersonal then ns.RefreshPersonal() end
            if ns.RefreshReview then ns.RefreshReview() end
            if ns.RefreshReportExport then ns.RefreshReportExport() end
            return true
        end
    end
    return false
end
