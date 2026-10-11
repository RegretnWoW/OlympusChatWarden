local _, ns = ...
local T, P = ns.Theme, ns.Personal
local window, mode, selected, page, seed = nil, "reports", nil, 1, nil
local rows, title, pager, previous, nextPage, detail, detailScroll, measure, phrase, action, enabled, status, save, remove, use, editor
local replacement, replacementLabel
local deleteArmed
local function Plain(text) return (text or ""):gsub("|", "||") end
local function Label(parent, text, x, y, width, paper)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y); label:SetWidth(width); label:SetJustifyH("LEFT"); label:SetText(text or "")
    if paper then T.Ink(label) else T.Light(label) end
    return label
end
local function Button(parent, text, x, y, width, fn)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24); button:SetPoint("TOPLEFT", x, y); button:SetText(text); button:SetScript("OnClick", fn); T.ActionHelp(button, text)
    return button
end
local function Items() return mode == "rules" and P.rules or P.reports end
local function Current()
    for _, item in ipairs(Items()) do if item.id == selected then return item end end
end
local function DetailsText()
    local item = Current()
    if mode == "rules" then return seed and ("Original report:\n\n" .. seed.original) or "" end
    if not item then return "Select a saved report.\n\nSaving a report alone leaves your rules unchanged.\n\nChoose Make a rule to select exact words and their action.\n\nUse Export reports to share examples for tuning. Nothing is sent automatically." end
    local result = item.actualAction and ("FILTER CHOSE: " .. T.Label(T.Actions, item.actualAction))
        or item.predictedAction and ("SETTINGS WHEN REPORTED: " .. T.Label(T.Actions, item.predictedAction))
        or "Original filter result unavailable for this older report."
    return result .. "\nWANTED: " .. T.Label(T.Actions, item.expectedAction) .. "\n\nORIGINAL MESSAGE\n" .. item.original
        .. (item.originalTruncated and "\n[Original shortened]" or "")
        .. (item.note ~= "" and "\n\nYOUR NOTE\n" .. item.note or "")
end
local function Select(id)
    selected, deleteArmed = id, nil
    local item = Current()
    if mode == "rules" then
        phrase:SetText(item and item.phrase or ""); action.value = item and item.action or seed and seed.expectedAction or "Redacted"
        enabled:SetChecked(not item or item.enabled); replacement:SetText(item and item.replacement or ""); action:Refresh()
    end
    status:SetText(""); ns.RefreshPersonal()
    detail:SetCursorPosition(0); detail:ClearFocus(); window.DetailScroll:SetVerticalScroll(0)
end
function ns.RefreshPersonal()
    if not window or not window:IsShown() then return end
    local items = Items(); local pages = math.max(1, math.ceil(#items / 8)); page = math.min(page, pages)
    title:SetText((mode == "rules" and "My phrase rules" or "My saved reports") .. "  |  " .. #items)
    pager:SetText("Page " .. page .. " / " .. pages); previous:SetEnabled(page > 1); nextPage:SetEnabled(page < pages)
    for i, row in ipairs(rows) do
        local item = items[#items - (page - 1) * 8 - i + 1]; row.item = item
        if item then
            row.title:SetText(mode == "rules" and ((item.enabled and "ON" or "OFF") .. "  |  " .. T.Label(T.Actions, item.action))
                or (item.actualAction and (item.actualAction .. " > " .. item.expectedAction) or ("Wanted: " .. item.expectedAction)))
            row.preview:SetText(Plain(mode == "rules" and item.phrase or item.original:gsub("[\r\n]", " ")))
            T.RowState(row, item.id == selected, mode == "rules" and item.action or item.expectedAction)
        end
        row:SetShown(item ~= nil)
    end
    replacement:SetShown(mode == "rules" and action.value == "Replaced")
    replacementLabel:SetShown(mode == "rules" and action.value == "Replaced")
    editor:SetShown(mode == "rules"); detailScroll = window.DetailScroll
    detailScroll:SetShown(mode == "reports" or seed ~= nil)
    if mode == "rules" then
        detailScroll:ClearAllPoints(); detailScroll:SetPoint("TOPLEFT", window.Paper, "TOPLEFT", 18, -288)
        detailScroll:SetSize(421, 60)
    else
        detailScroll:ClearAllPoints(); detailScroll:SetPoint("TOPLEFT", window.Paper, "TOPLEFT", 18, -18)
        detailScroll:SetSize(421, 342)
    end
    local text = Plain(DetailsText())
    if detail:GetText() ~= text then detail:SetText(text) end
    measure:SetText(text)
    detail:SetHeight(math.max(mode == "reports" and 342 or 60, measure:GetStringHeight() + 30))
    use:SetShown(mode == "reports"); use:SetEnabled(Current() ~= nil and not Current().originalTruncated)
    save:SetShown(mode == "rules")
    remove:SetEnabled(Current() ~= nil); remove:SetText(deleteArmed and "Confirm delete" or mode == "rules" and "Delete rule" or "Delete report")
    window.Mode:Refresh()
end
function ns.OpenPersonal(requestedMode)
    if requestedMode == "reports" or requestedMode == "rules" then mode, selected, seed, page = requestedMode, nil, nil, 1 end
    if not window then
        window = T.Window("OlympusChatWardenPersonal", UIParent, 800, 630)
        ns.PersonalWindow = window; T.Title(window, ns.NAME); T.Crest(window)
        T.Gold(Label(window, "My reports & phrase rules", 78, -30, 690))
        T.Muted(Label(window, "Saved on this account. Nothing is sent automatically.", 78, -50, 690))
        local toolbar = T.Panel(window, 14, -74, 772, 42)
        window.Mode = T.Dropdown(toolbar, 10, -8, 220, {{"reports", "My saved reports"}, {"rules", "My phrase rules"}},
            function() return mode end, function(value) mode, page, seed = value, 1, nil; Select(nil) end)
        Button(toolbar, "New rule", 244, -9, 100, function() mode, seed, page = "rules", nil, 1; Select(nil) end)
        Button(toolbar, "Report a miss", 353, -9, 120, function() ns.OpenReport(nil, "Missed match") end)
        Button(toolbar, "Export reports", 482, -9, 135, function() ns.OpenReportExport() end)
        Button(toolbar, "Send feedback", 626, -9, 135, function() ns.OpenReportLink() end)
        local list = T.Panel(window, 14, -124, 285, 410)
        title = Label(list, "", 12, -12, 261); rows = {}
        for i = 1, 8 do
            local row = CreateFrame("Button", nil, list); row:SetSize(267, 44); row:SetPoint("TOPLEFT", 9, -36 - (i - 1) * 46)
            row.background = row:CreateTexture(nil, "BACKGROUND"); row.background:SetAllPoints()
            row.title = Label(row, "", 10, -6, 242); row.title:SetWordWrap(false)
            row.label = row.title
            row.preview = T.Muted(Label(row, "", 10, -25, 242)); row.preview:SetWordWrap(false)
            T.SkinRow(row); row:SetScript("OnClick", function(self) seed = nil; Select(self.item and self.item.id) end); rows[i] = row
        end
        window.Paper = T.Panel(window, 312, -124, 474, 410, true)
        editor = CreateFrame("Frame", nil, window.Paper); editor:SetAllPoints()
        Label(editor, "Exact phrase", 18, -18, 430, true)
        phrase = CreateFrame("EditBox", nil, editor, "InputBoxTemplate"); phrase:SetSize(422, 26); phrase:SetPoint("TOPLEFT", 24, -42)
        phrase:SetAutoFocus(false); phrase:SetMaxLetters(120); phrase:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        T.TextField(phrase)
        T.Tooltip(phrase,"Exact phrase","Use specific wording you want to change. A whole phrase is safer than a very short or common word.")
        Label(editor, "What should happen when this phrase appears?", 18, -88, 430, true)
        action = T.Dropdown(editor, 18, -112, 430, T.RuleActions, function() return action and action.value or "Redacted" end,
            function(value) action.value = value; ns.RefreshPersonal() end)
        enabled = CreateFrame("CheckButton", nil, editor, "UICheckButtonTemplate"); enabled:SetPoint("TOPLEFT", 12, -209)
        enabled.Text:SetText("Enable this personal rule"); T.Ink(enabled.Text)
        T.Tooltip(enabled,"Use this rule","Turn the rule off to keep it saved without applying it.")
        replacementLabel = Label(editor, "Replacement text (shown in gray)", 18, -151, 430, true)
        replacement = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
        replacement:SetSize(422, 26); replacement:SetPoint("TOPLEFT", 24, -173)
        replacement:SetAutoFocus(false); replacement:SetMaxLetters(120)
        replacement:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        T.TextField(replacement)
        T.Tooltip(replacement,"Your replacement","This wording appears in gray instead of the matching phrase. It is not filtered again.")
        T.Tooltip(action,"What should happen?","Pick how this phrase should appear. Your personal rule works across sensitivity presets, but still follows text-area switches and exceptions.")
        ns.RulePhraseBox, ns.RuleReplacementBox, ns.RuleActionDropdown = phrase, replacement, action
        Label(editor, "Whole phrases: 3-120 English characters. Replacement text: 1-120. Coverage and exceptions apply.", 18, -244, 430, true)
        local scroll = CreateFrame("ScrollFrame", nil, window.Paper, "UIPanelScrollFrameTemplate"); window.DetailScroll = scroll
        detail = CreateFrame("EditBox", nil, scroll); detail:SetMultiLine(true); detail:SetAutoFocus(false)
        T.Body(detail); T.Ink(detail); detail:SetSize(416, 342); scroll:SetScrollChild(detail)
        measure = detail:CreateFontString(nil, "OVERLAY"); T.Body(measure)
        measure:SetWordWrap(true); measure:SetWidth(416); measure:Hide()
        detail:HookScript("OnTextChanged", function(self, userInput) if userInput then self:SetText(Plain(DetailsText())) end end)
        detail:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        T.TextField(detail, scroll)
        status = Label(window.Paper, "", 18, -370, 430, true)
        previous = Button(window, "Previous", 14, -546, 90, function() page = math.max(1, page - 1); ns.RefreshPersonal() end)
        nextPage = Button(window, "Next", 209, -546, 90, function() page = page + 1; ns.RefreshPersonal() end)
        pager = Label(window, "", 113, -552, 95)
        use = Button(window, "Make a rule", 312, -546, 145, function()
            local report = Current(); if not report or report.originalTruncated then return end
            seed, mode, page = report, "rules", 1; Select(nil)
        end)
        save = Button(window, "Save personal rule", 312, -546, 175, function()
            local ok, message, id = P.SaveRule(phrase:GetText(), action.value, selected, seed and seed.original, ns.Checked(enabled:GetChecked()), replacement:GetText())
            if ok then seed = nil; Select(id) end
            status:SetText(message)
        end)
        remove = Button(window, "Delete report", 502, -546, 140, function()
            local item = Current(); if not item then return end
            if deleteArmed ~= item.id then deleteArmed = item.id; ns.RefreshPersonal(); return end
            if mode == "rules" then P.ChangeRule(item.id, nil, true) else P.RemoveReport(item.id) end
            Select(nil)
        end)
        Button(window, "Close", 686, -546, 100, function() window:Hide() end)
        T.Muted(Label(window, "Save a phrase rule to change your filter. Export reports to share feedback. Deleting a report keeps its phrase rules.", 18, -593, 764))
        window:SetScript("OnShow", ns.RefreshPersonal)
        window:SetScript("OnHide", function() deleteArmed = nil; phrase:ClearFocus(); replacement:ClearFocus(); detail:ClearFocus() end)
    end
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    window:SetScale(math.min(1, (w - 30) / 800, (h - 30) / 630)); T.ShowWindow(window); Select(selected)
end
