local _, ns = ...
local T, P = ns.Theme, ns.Personal
local instances={}
local function Instance(mode)
local window, selected, page, seed = nil, nil, 1, nil
local Refresh
local rows, title, pager, previous, nextPage, detail, detailScroll, phrase, action, enabled, status, save, remove, use, editor
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
    if mode == "rules" then return seed and {"Original report", seed.original} or {} end
    if not item then return {"Select a saved report.\n\nReports save examples and feedback. They do not change filtering.\n\nExport reports opens a privacy preview. Nothing is sent automatically."} end
    local result = item.actualAction and ("Filter chose: " .. T.Label(T.Actions, item.actualAction))
        or item.predictedAction and ("Settings when reported: " .. T.Label(T.Actions, item.predictedAction))
        or "Original filter result unavailable for this older report."
    local sections={"Report #"..item.id.."\n"..result.."\nWanted: "..T.Label(T.Actions,item.expectedAction),
        "\nOriginal message",item.original}
    if item.originalTruncated then sections[#sections+1]="[Original shortened]" end
    if item.note and item.note~="" then sections[#sections+1]="\nYour note";sections[#sections+1]=item.note end
    return sections
end
local function Select(id)
    selected, deleteArmed = id, nil
    local item = Current()
    if mode == "rules" then
        phrase:SetText(item and item.phrase or ""); action.value = item and item.action or seed and seed.expectedAction or "Redacted"
        enabled:SetChecked(not item or item.enabled); replacement:SetText(item and item.replacement or ""); action:Refresh()
    end
    status:SetText(""); Refresh()
    detail:ClearFocus(); window.DetailScroll:SetVerticalScroll(0)
end
Refresh=function()
    if not window or not window:IsShown() then return end
    local items = Items(); local pages = math.max(1, math.ceil(#items / 8)); page = math.min(page, pages)
    title:SetText((mode == "rules" and "My phrase rules" or "My saved reports") .. "  |  " .. #items)
    pager:SetText("Page " .. page .. " / " .. pages); previous:SetEnabled(page > 1); nextPage:SetEnabled(page < pages)
    for i, row in ipairs(rows) do
        local item = items[#items - (page - 1) * 8 - i + 1]; row.item = item
        if item then
            row.title:SetText(mode == "rules" and ((item.enabled and "ON" or "OFF") .. "  |  " .. T.Label(T.Actions, item.action))
                or ('#'..item.id..'  |  '..(item.actualAction and (item.actualAction .. " > " .. item.expectedAction) or ("Wanted: " .. item.expectedAction))))
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
    detail:SetSections(DetailsText())
    save:SetShown(mode == "rules")
    remove:SetEnabled(Current() ~= nil); remove:SetText(deleteArmed and "Confirm delete" or mode == "rules" and "Delete rule" or "Delete report")
end
local function Open()
    local first=not window
    if not window then
        window = T.Window(mode=="rules" and "OlympusChatWardenRules" or "OlympusChatWardenReports", UIParent, 800, 630)
        if mode=="rules" then ns.RulesWindow=window else ns.ReportsWindow=window end
        T.Title(window, ns.NAME); T.Crest(window)
        T.Gold(Label(window, mode=="rules" and "My rules" or "My reports", 78, -30, 690))
        T.Muted(Label(window, mode=="rules" and "Personal phrase actions. Applies to new matching text." or "Saved filter feedback. Nothing is sent automatically.", 78, -50, 690))
        local toolbar = T.Panel(window, 14, -74, 772, 42)
        if mode=="rules" then
            Button(toolbar,"New rule",10,-9,140,function() seed=nil;Select(nil) end)
            T.Muted(Label(toolbar,"Rules change filtering. Reports are managed separately.",166,-16,590))
        else
            Button(toolbar,"Report a miss",10,-9,140,function() ns.OpenReport(nil,"Missed match") end)
            Button(toolbar,"Export reports",164,-9,150,function() ns.OpenReportExport() end)
            Button(toolbar,"Send feedback",328,-9,150,function() ns.OpenReportLink() end)
        end
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
        T.Tooltip(phrase,"Exact phrase","Enter the words to match, without quotation marks around them. Matches ignore English capitalization and use whole words. Rules apply to new messages, not earlier chat lines. A player name rule covers matching name text; it does not silence everything that player says.")
        Label(editor, "What should happen when this phrase appears?", 18, -88, 430, true)
        action = T.Dropdown(editor, 18, -112, 430, T.RuleActions, function() return action and action.value or "Redacted" end,
            function(value) action.value = value; Refresh() end)
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
        if mode=="rules" then ns.RulePhraseBox, ns.RuleReplacementBox, ns.RuleActionDropdown = phrase, replacement, action end
        Label(editor, "Exact whole words: 3-120 English characters. Applies to new chat; coverage and exceptions still apply.", 18, -244, 430, true)
        local scroll = CreateFrame("ScrollFrame", nil, window.Paper, "UIPanelScrollFrameTemplate"); window.DetailScroll = scroll
        detail = T.ReadOnlyDocument(scroll);if mode=="reports" then ns.PersonalDocument=detail else ns.RulesDocument=detail end
        status = Label(window.Paper, "", 18, -370, 430, true)
        previous = Button(window, "Previous", 14, -546, 90, function() page = math.max(1, page - 1); Refresh() end)
        nextPage = Button(window, "Next", 209, -546, 90, function() page = page + 1; Refresh() end)
        pager = Label(window, "", 113, -552, 95)
        save = Button(window, "Save personal rule", 312, -546, 175, function()
            local ok, message, id = P.SaveRule(phrase:GetText(), action.value, selected, seed and seed.original, ns.Checked(enabled:GetChecked()), replacement:GetText())
            if ok then seed = nil; Select(id) end
            status:SetText(message)
        end)
        remove = Button(window, "Delete report", 502, -546, 140, function()
            local item = Current(); if not item then return end
            if deleteArmed ~= item.id then deleteArmed = item.id; Refresh(); return end
            if mode == "rules" then P.ChangeRule(item.id, nil, true) else P.RemoveReport(item.id) end
            Select(nil)
        end)
        Button(window, "Close", 686, -546, 100, function() window:Hide() end)
        T.Muted(Label(window, mode=="rules" and "Rules are saved on this account. Existing chat lines are not rewritten." or "Reports are saved on this account. Deleting a report leaves your rules unchanged.", 18, -593, 764))
        window:SetScript("OnShow", Refresh)
        window:SetScript("OnHide", function() deleteArmed = nil; phrase:ClearFocus(); replacement:ClearFocus(); detail:ClearFocus() end)
    end
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    window:SetScale(math.min(1, (w - 30) / 800, (h - 30) / 630)); T.ShowWindow(window)
    if first then Select(nil) else Refresh() end
end

return {Open=Open,Refresh=function() if window then Refresh() end end}
end
local function Open(mode)
    if not ns.DB then return end
    instances[mode]=instances[mode] or Instance(mode)
    instances[mode].Open()
end
function ns.OpenRules() Open('rules') end
function ns.OpenReports() ns.OpenExport('reports',nil,nil,'review') end
function ns.OpenPersonal(mode) if mode=='rules' then ns.OpenRules() else ns.OpenReports() end end
function ns.RefreshPersonal()
    for _,instance in pairs(instances) do instance.Refresh() end
    if ns.RefreshReportsView then ns.RefreshReportsView() end
end
