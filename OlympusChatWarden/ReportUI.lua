local _, ns = ...
local T, P = ns.Theme, ns.Personal
local form
local issues = {{"Missed match", "Missed by the filter"}, {"False positive", "Should have stayed visible"},
    {"Wrong action", "Needed a different action"}}
local actionChoices = {}
local function Label(parent, text, x, y, width, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y); label:SetWidth(width); label:SetJustifyH("LEFT"); label:SetText(text)
    T.Light(label); return label
end
local function Button(parent, text, x, y, width, click)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24); button:SetPoint("TOPLEFT", x, y); button:SetText(text); button:SetScript("OnClick", click); T.ActionHelp(button, text)
    return button
end
local function Window(name, height, heading)
    local window = T.Window(name, UIParent, 720, height)
    T.Title(window, ns.NAME); T.Crest(window)
    window.Heading = T.Gold(Label(window, heading, 78, -30, 610, "GameFontNormalLarge"))
    T.Muted(Label(window, "Saved on this account. Share an export when you want to help improve the filter.", 78, -50, 610))
    return window
end
local function Edit(parent, x, y, width, height, maxLetters)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetSize(width, height); scroll:SetPoint("TOPLEFT", x, y)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true); edit:SetAutoFocus(false); T.Body(edit); T.Ink(edit)
    edit:SetMaxLetters(maxLetters); edit:SetSize(width - 5, height); scroll:SetScrollChild(edit)
    local measure = edit:CreateFontString(nil, "OVERLAY")
    T.Body(measure); measure:SetWordWrap(true); measure:SetWidth(width - 5); measure:Hide()
    edit:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""; local _, lines = text:gsub("\n", "\n"); measure:SetText(text)
        self:SetHeight(math.max(height, (lines + 3) * 18, measure.GetStringHeight and measure:GetStringHeight() + 30 or 0))
    end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    T.TextField(edit, scroll)
    return edit, scroll

end
local function Fit(window)
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    if w and h and w > 0 and h > 0 then window:SetScale(math.min(1, (w - 30) / 720, (h - 30) / window:GetHeight())) end
end
local function RefreshForm()
    for i = #actionChoices, 1, -1 do actionChoices[i] = nil end
    for _, choice in ipairs(T.Actions) do
        if form.label ~= "Missed match" or choice[1] ~= "Unchanged" then actionChoices[#actionChoices + 1] = choice end
    end
    form.choice:Refresh(); form.action:Refresh(); form.sourceDropdown:Refresh()
    form.action:SetEnabled(form.label ~= "False positive")
    form.sourceDropdown:SetEnabled(not form.entry and not (form.draft and form.draft.original))
    form.rulePhrase:SetEnabled(ns.Checked(form.saveRule:GetChecked()))
    form.help:SetText(form.label == "Missed match" and "Check the missed message below and choose how you want it handled."
        or form.label == "False positive" and "This message should have stayed visible. Add a note if it helps explain why."
        or "Choose the action this message should have received, then save your report.")
end
local function ApplyDraft(draft)
    form.draft = draft
    form.source = form.entry and form.entry.kind or draft and draft.source or form.source or "manual"
    local original = form.entry and form.entry.original or draft and draft.original
    form.original:SetText(original and original:gsub("|", "||") or "")
    form.original:SetCursorPosition(0); form.original:ClearFocus(); form.originalScroll:SetVerticalScroll(0)
    local choices = form.recentChoices
    for i = #choices, 1, -1 do choices[i] = nil end
    choices[1] = {0, "Choose a recent message"}
    for i, entry in ipairs(draft and draft.choices or {}) do
        local preview = ns.Reports.Clip(entry.original:gsub("[\r\n]", " "), 70)
        choices[#choices + 1] = {i, i .. ". " .. preview:gsub("|", "||")}
    end
    form.recent:SetShown(#choices > 1); form.recent:Refresh()
    form.originalHint:SetText(original and "Captured original - select text to copy" or "Paste the exact message here")
    RefreshForm()
    if draft then form.status:SetText(draft.status or "Check the original, then save your report.") end
end
function ns.OpenReport(entry, initialLabel, draft)
    if not form then
        form = Window("OlympusChatWardenReport", 700, "Report a problem")
        ns.ReportWindow = form
        form.help = Label(form, "", 20, -78, 680)
        T.Gold(Label(form, "What went wrong?", 20, -110, 225))
        T.Gold(Label(form, "What should happen?", 260, -110, 220))
        T.Gold(Label(form, "Message source", 500, -110, 200))
        form.choice = T.Dropdown(form, 20, -132, 225, issues, function() return form.label end, function(value)
            form.label = value; form.expected = value == "Missed match" and "Redacted"
                or value == "False positive" and "Unchanged" or form.expected
            RefreshForm()
        end)
        form.action = T.Dropdown(form, 260, -132, 220, actionChoices, function() return form.expected end,
            function(value) form.expected = value end)
        local sources = {}; for _, choice in ipairs(T.Sources) do if choice[1] ~= "all" then sources[#sources + 1] = choice end end
        form.sourceDropdown = T.Dropdown(form, 500, -132, 200, sources, function() return form.source end,
            function(value) form.source = value end)
        local paper = T.Panel(form, 18, -178, 684, 204, true)
        T.Heading(Label(paper, "Original message", 14, -12, 330, "GameFontNormal"))
        form.originalHint = T.Heading(Label(paper, "", 14, -34, 650))
        form.recentChoices = {}
        form.recent = T.Dropdown(paper, 405, -9, 260, form.recentChoices,
            function() return form.draft and form.draft.choiceIndex or 0 end,
            function(value)
                if value == 0 then return end
                local nextDraft = ns.ChatReports.SelectDraft(form.draft, value)
                if nextDraft then ApplyDraft(nextDraft) end
            end)
        form.original, form.originalScroll = Edit(paper, 14, -62, 640, 124, 16384)
        form.original:HookScript("OnTextChanged", function(self, userInput)
            local original = form.entry and form.entry.original or form.draft and form.draft.original
            if userInput and original then self:SetText(original:gsub("|", "||")) end
        end)
        local notes = T.Panel(form, 18, -394, 684, 112, true)
        T.Heading(Label(notes, "Why? (optional)", 14, -12, 650, "GameFontNormal"))
        T.Heading(Label(notes, "Add a short note if you want. What felt wrong about this result?", 14, -34, 650))
        form.note, form.noteScroll = Edit(notes, 14, -60, 640, 36, 1000)
        local rules = T.Panel(form, 18, -516, 684, 92)
        form.saveRule = CreateFrame("CheckButton", nil, rules, "UICheckButtonTemplate")
        form.saveRule:SetPoint("TOPLEFT", 6, -4); form.saveRule.Text:SetText("Also apply a personal phrase rule")
        T.Light(form.saveRule.Text); form.saveRule:SetScript("OnClick", RefreshForm)
        form.rulePhrase = CreateFrame("EditBox", nil, rules, "InputBoxTemplate")
        form.rulePhrase:SetSize(635, 24); form.rulePhrase:SetPoint("TOPLEFT", 26, -35)
        form.rulePhrase:SetAutoFocus(false); form.rulePhrase:SetMaxLetters(120)
        form.rulePhrase:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        T.TextField(form.rulePhrase)
        T.Muted(Label(rules, "Optional: enter exact words from the message. A report alone leaves your rules unchanged.", 24, -70, 638))
        T.Tooltip(form.choice,"What went wrong?","Was the message missed, caught by mistake, or given the wrong treatment?")
        T.Tooltip(form.action,"What should happen?","Pick the result you would have preferred for this message.")
        T.Tooltip(form.sourceDropdown,"Where did you see it?","Choose chat, a tooltip, a name, or the other area where the original appeared.")
        T.Tooltip(form.original,"Original message","Keep the wording exactly as it appeared so the report is useful. Captured originals are read-only; you can select and copy them.")
        T.Tooltip(form.note,"Anything else?","A short explanation is enough. This note is optional.")
        T.Tooltip(form.saveRule,"Also make a rule","Check this only if you want to change your own filter now. Leaving it off saves feedback without changing filtering.")
        T.Tooltip(form.rulePhrase,"Phrase to change","Enter just the words you want your new rule to match, rather than the whole conversation.")
        form.status = Label(form, "", 20, -618, 680)
        form.save = Button(form, "Save report", 20, -654, 160, function()
            local actual = form.entry and form.entry.action or form.draft and form.draft.captureSnapshot
                and form.draft.captureSnapshot.actualAction
            if form.label == "Wrong action" and actual and form.expected == actual then
                form.status:SetText("Choose a different wanted action for this report."); return
            end
            local original = form.entry and form.entry.original or form.draft and form.draft.original or form.original:GetText()
            local recordDraft = form.entry and ns.Reports.ReviewDraft(form.entry) or form.draft
            local ok, message, id = P.SaveReport(original, form.expected, form.note:GetText(), form.source, recordDraft,
                ns.Checked(form.saveRule:GetChecked()) and form.rulePhrase:GetText() or nil, form.label)
            form.status:SetText(message)
            if ok then
                if form.entry then form.entry.reportID = id; ns.Review.Mark(form.entry.id, "Reported") end
                ns.Print(message); form:Hide(); ns.RefreshReview()
                if ns.RefreshReportExport then ns.RefreshReportExport() end
            end
        end)
        Button(form, "Cancel", 600, -654, 100, function() form:Hide() end)
        T.Muted(Label(form, "Nothing is sent automatically. Find saved reports and share an export from My reports.", 20, -685, 680))
        form:HookScript("OnHide", function()
            form.original:ClearFocus(); form.note:ClearFocus(); form.rulePhrase:ClearFocus()
        end)
    end
    form.entry, form.label = entry, initialLabel or (entry and "False positive" or "Missed match")
    form.expected = form.label == "Missed match" and "Redacted" or "Unchanged"
    form.source = entry and entry.kind or draft and draft.source or "manual"
    form.saveRule:SetChecked(false); form.rulePhrase:SetText(""); form.rulePhrase:ClearFocus()
    form.Heading:SetText(entry and "Review this filter result" or "Report a missed message")
    ApplyDraft(draft); form.note:SetText(""); form.note:ClearFocus(); form.noteScroll:SetVerticalScroll(0)
    form.status:SetText(entry and ("The filter chose: " .. T.Label(T.Actions, entry.action) .. ". Save records your report.")
        or draft and draft.status or "Your report is saved only when you click Save report.")
    Fit(form); T.ShowWindow(form)
end
-- WoW has no general browser launcher here: show a selectable URL and explicit steps.
local reportLinkWindow
function ns.OpenReportLink()
    if not reportLinkWindow then
        reportLinkWindow = Window("OlympusChatWardenReportLink", 360, "Send feedback on GitHub")
        ns.ReportLinkWindow = reportLinkWindow
        Label(reportLinkWindow, "1. Select the link below, press Ctrl+C, and open it in your browser.\n2. Start an issue, then return here and copy your report export.\n3. Paste the export into the issue and explain what you expected.", 20, -82, 680)
        local paper = T.Panel(reportLinkWindow, 18, -156, 684, 64, true)
        local link = CreateFrame("EditBox", nil, paper, "InputBoxTemplate")
        link:SetPoint("TOPLEFT", 22, -18); link:SetSize(632, 26)
        link:SetAutoFocus(false); link:SetMaxLetters(200); link:SetText(ns.REPORT_URL)
        ns.ReportLinkText = link
        link:HookScript("OnTextChanged", function(self, userInput)
            if userInput then self:SetText(ns.REPORT_URL) end
        end)
        link:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        T.TextField(link)
        Button(reportLinkWindow, "Select link", 20, -237, 130, function() link:SetFocus(); link:HighlightText() end)
        Button(reportLinkWindow, "Export reports", 165, -237, 150, function() ns.OpenReportExport() end)
        Button(reportLinkWindow, "Close", 600, -237, 100, function() reportLinkWindow:Hide() end)
        T.Muted(Label(reportLinkWindow, "GitHub reports are public. Check messages and notes for identifying details.\nReports do not automatically train the filter. Nothing is sent automatically.", 20, -284, 680))
        reportLinkWindow:HookScript("OnHide", function() link:ClearFocus() end)
    end
    Fit(reportLinkWindow); T.ShowWindow(reportLinkWindow)
end
