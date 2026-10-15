local _, ns = ...
local R, T = ns.Review, ns.Theme
local window, listTitle, details, detailScroll, rows, previous, nextPage, pageText, sourceDropdown, allowLanguage
local reportButton, reportPlayerButton, correctButton, reasonButton, detailTitle, footer, savedButton, empty
local selected, page, filter, query, showReasons = nil, 1, "all", "", false
local queued, clearArmed = false, false
local messagePage, shieldPage, capturePage, reviewTab, messageTab, shieldTab, captureTab
local PAGE_SIZE = 9
local function Plain(text) return (text or ""):gsub("|", "||") end
local function Text(parent, font, x, y, width, value)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetPoint("TOPLEFT", x, y); label:SetWidth(width); label:SetJustifyH("LEFT")
    label:SetText(value or ""); T.Light(label); return label
end
local function Button(parent, text, width, x, y, click)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24); button:SetPoint("TOPLEFT", x, y); button:SetText(text)
    button:SetScript("OnClick", click); T.ActionHelp(button, text); return button
end
local function Saved(entry)
    if not entry or not entry.reportID then return nil end
    for _, record in ipairs(ns.Personal.reports) do if record.id == entry.reportID then return record end end
end
function R.Filtered(kind, needle)
    local result = {}
    needle = (needle or ""):lower()
    for i = #R.entries, 1, -1 do
        local entry = R.entries[i]
        local haystack = (R.Source(entry) .. " " .. (entry.event or "") .. " " .. (entry.panel or "") .. " " .. entry.original):lower()
        if (kind == "all" or kind == entry.kind) and (needle == "" or haystack:find(needle, 1, true)) then result[#result + 1] = entry end
    end
    return result
end
function R.DetailText(entry, reasons, sections)
    if not entry then
        local text="Read a message\n\nSelect a row on the left. Its original appears here, and its unread badge clears.\n\nCheck a result\n\nWhy filtered? explains the rule. Report problem saves ChatWarden feedback. Report player opens Blizzard's flow for player chat. Dismiss removes the saved history entry.\n\nReport a miss\n\nUse Report a miss above, or right-click the player's name in chat."
        return sections and {text} or text
    end
    local name=entry.kind=='playerName' or entry.kind=='targetName' or entry.kind=='npcName'
    local lines = {R.Source(entry), R.TimeLabel(entry), name and "\nOriginal name / label\n" or "\nOriginal message\n", entry.original}
    if sections then
        lines[1]=R.Source({kind=entry.kind})
        local identity=entry.sender or entry.npc or entry.questTitle
        if identity then table.insert(lines,2,identity) end
    end
    if entry.truncated then lines[#lines + 1] = "[Long original shortened in review history]" end
    lines[#lines + 1] = "\nResult\n"
    lines[#lines + 1] = ({Hidden='Hidden from chat.',Redacted='Covered text.',Warning='Visible with a warning.',
        Replaced='Shown with replacement wording.',Unchanged='Kept visible.'})[entry.action] or entry.action
    if entry.spamReason then
        lines[#lines+1]=entry.spamReason..(entry.spamReason:find('Rapid-message burst:',1,true)
            and '. Chat paused for 10 seconds. No contact shield was added.'
            or '. Only this message was hidden.')
    end
    if entry.language then
        local language=entry.language
        lines[#lines+1]='Language filter: '..language.label..((language.kind or language.evidence=='writing-system') and '' or ' — '..language.confidence..' confidence')
        if language.evidence=='writing-system' then lines[#lines+1]='Writing system detected; exact language uncertain.' end
        if language.basis=='mostly-non-preferred' then lines[#lines+1]='High action: at least 85% of readable text is non-preferred.'
        elseif language.kind=='sender-language' then lines[#lines+1]='High-confidence text and the name matched your language preferences.'
        elseif language.kind=='sender-script' then lines[#lines+1]='Your sender rule hides every message from this name, including English.'
        elseif language.kind=='strict-script' then lines[#lines+1]='A checked writing system matched your explicit text rule.' end
    end
    if entry.action=='Redacted' then lines[#lines+1]='Ctrl + left-click covered text to reveal it where supported.' end
    local record = Saved(entry)
    if record then
        lines[#lines + 1] = "\nSaved report\n"
        lines[#lines + 1] = ({["Correct match"] = "Looks right", ["False positive"] = "Should have stayed visible",
            ["Wrong action"] = "Needed a different action"})[record.feedback] or record.feedback
        lines[#lines + 1] = "Wanted: " .. T.Label(T.Actions, record.expectedAction)
        if record.note and record.note ~= "" then lines[#lines + 1] = record.note end
    end
    if reasons then
        lines[#lines + 1] = "\nWhy this matched\n"
        if entry.language then lines[#lines+1]=entry.language.reason end
        local preset = ({maximum = "Gommage (legacy)", aggressive = "Broad", balanced = "Balanced", strict = "Mild"})[entry.preset] or "Unknown"
        local contextual=false;for _,match in ipairs(entry.matches) do if match.contextPolicyVersion==2 then contextual=true;break end end
        if #entry.matches>0 then lines[#lines + 1] = "Preset when received: " .. preset end
        lines[#lines + 1] = entry.spamReason and (entry.spamReason:find('Rapid-message burst:',1,true)
            and 'Spam protection: first rapid-message burst. A second full burst within 60 seconds triggers your automatic timeout.'
            or 'Spam protection: guild recruitment wording. No player timeout or wording score added.')
            or entry.shieldReason and (entry.shieldReason .. ". Contact protection; content score unchanged.")
            or entry.language and ('Wording score: '..(entry.score or 0)..'. Language confidence is separate.')
            or contextual and ('Display result: '..entry.action..'. Interpretation evidence is listed separately for each match.')
            or "Confidence: " .. (entry.confidence or "Unknown") .. " match strength"
        for i, match in ipairs(entry.matches) do
            local explanation = match.pack == 'language-script' and 'Name matched a non-preferred writing system; no wording score added.'
                or match.pack == "personal" and "Your saved phrase rule."
                or match.gommage and "Gommage display mask; score unchanged."
                or match.pack == "bodyLabels" and "Built-in Body Type 1/2 wording preference."
                or (match.pack == "guild" or match.pack == "creator") and "Name with nearby insulting or teasing wording."
                or "Phrase matched an enabled category."
            lines[#lines + 1] = i .. ". " .. (match.phrase or "Matched wording") .. " - " .. explanation
            if match.typo then lines[#lines+1]='Spelling guess: '..entry.original:sub(match.first,match.last)..' -> '..match.phrase..' ('..(match.typoEdits or '?')..' edits). Rule action unchanged.' end
            if match.gommage and match.score == 0 then
                lines[#lines + 1] = "Category: " .. (match.pack or "unknown") .. "; display only, no confidence contribution."
            elseif match.policy then
                lines[#lines+1]='Category: '..(match.pack or 'unknown')..'; '..(match.ruleKind or 'configured rule')..'; action '..(match.action or entry.action)..'.'
                if match.stance then lines[#lines+1]='Interpretation: '..match.stance..'; expression '..(match.strength or 'unknown')..'; evidence '..(match.certainty or 'unknown')..'. This interpretation is inferred from the wording.' end
                if match.reason then lines[#lines+1]=match.reason end
            elseif match.threshold then
                lines[#lines + 1] = "Category: " .. (match.pack or "unknown") .. "; score " .. (match.score or 0) .. "; minimum " .. match.threshold
            end
        end
        if entry.matchCount > #entry.matches then lines[#lines + 1] = "First " .. #entry.matches .. " of " .. entry.matchCount .. " matches shown." end
        if entry.rendered then lines[#lines+1]='\nDisplay preview\n';lines[#lines+1]=entry.rendered end
    end
    return sections and lines or table.concat(lines, "\n")
end
function R.ReaderBlocks(entry,reasons)
    if not entry then return {{text='Review filtered chat',kind='title'},{text='Select a message on the left to read its original and result.',kind='body'}} end
    local verdict=({Hidden='Hidden from chat',Redacted='Text covered',Warning='Visible with a warning',Replaced='Wording replaced',Unchanged='Kept visible'})[entry.action] or entry.action
    local tone=entry.action=='Hidden' and 'danger' or (entry.action=='Redacted' or entry.action=='Warning') and 'warning' or 'success'
    local blocks={{text=verdict,kind='title',tone=tone},{text=R.Source({kind=entry.kind})..'  /  '..R.TimeLabel(entry),kind='meta'},
        {text=(entry.kind=='playerName' or entry.kind=='npcName' or entry.kind=='targetName') and 'Original name or label' or 'Original message',kind='heading'},
        {text=R.DisplayOriginal(entry),kind='quote'}}
    if entry.truncated then blocks[#blocks+1]={text='Long original shortened in review history.',kind='meta'} end
    if entry.restored then blocks[#blocks+1]={text='Saved from an earlier session.',kind='meta'} end
    local summary=entry.shieldReason or entry.spamReason or entry.language and entry.language.reason
        or (#entry.matches>0 and (#entry.matches..' wording match'..(#entry.matches==1 and '' or 'es')..' under your saved filtering preferences.'))
        or 'Your filtering preferences determined this result.'
    for _,match in ipairs(entry.matches) do if match.contextPolicyVersion==2 and match.stance then
        local meaning=match.stance=='threat' and 'a recognized explicit threat'
            or match.stance=='support' and ((match.strength=='strong' and 'strong promotion' or 'mild support')..' of a selected topic')
            or (match.strength or '')..' directed criticism'
        summary='Interpreted as '..meaning..' under your selected category preference. Result: '..(match.action or entry.action)..'.'
        break
    end end
    blocks[#blocks+1]={text='Filter summary',kind='heading'};blocks[#blocks+1]={text=summary,kind='body'}
    local record=Saved(entry)
    if record then
        blocks[#blocks+1]={text='Saved feedback',kind='heading'}
        blocks[#blocks+1]={text=(record.feedback or 'Saved report')..' / Wanted: '..T.Label(T.Actions,record.expectedAction),kind='accent'}
        if record.note and record.note~='' then blocks[#blocks+1]={text=record.note,kind='body'} end
    end
    if reasons then
        local lines=R.DetailText(entry,true,true);local include=false
        for _,line in ipairs(lines) do
            if line:find('Why this matched',1,true) then include=true end
            if include then
                local trimmed=line:match('^%s*(.-)%s*$')
                blocks[#blocks+1]={text=trimmed,kind=line:match('^\n.+\n$') and 'heading'
                    or trimmed:match('^%d+%. ') and 'accent' or trimmed:match('^Category:') and 'meta'
                    or trimmed:match('^Preset') and 'meta' or trimmed:match('^Confidence:') and 'meta' or 'body'}
            end
        end
    else blocks[#blocks+1]={text='Choose Why filtered? for individual matches, confidence and spelling evidence.',kind='meta'} end
    return blocks
end
local function UpdateDetails(resetScroll)
    local entry = R.Get(selected)
    if details then
        details:SetSections(R.DetailText(entry,showReasons,true));ns.ReviewDetails=details.boxes[1]
        if resetScroll then detailScroll:SetVerticalScroll(0) end
        detailTitle:SetText(entry and ((entry.kind=='playerName' and 'Original name' or 'Original message').."  |  " .. entry.action) or "Message review")
        reportButton:SetEnabled(entry ~= nil); correctButton:SetEnabled(entry ~= nil); reasonButton:SetEnabled(entry ~= nil)
        reportPlayerButton:SetEnabled(R.CanReportPlayer(entry) == true)
        reasonButton:SetText(showReasons and "Hide details" or "Why filtered?")
        if allowLanguage then
            allowLanguage:SetShown(entry~=nil and entry.language~=nil)
            local language=entry and entry.language
            allowLanguage:SetText(language and language.id=='mixed' and 'Languages...' or 'Allow language')
            allowLanguage:SetEnabled(not (language and ns.DB.languageFilter and ns.DB.languageFilter.allowed[language.id]))
        end
        footer:SetText(entry and Saved(entry) and "Report saved. Open My reports to review or export it."
            or "Review history lasts this session. Saved reports and personal phrase rules survive reload.")
    end
end
local function Select(entry)
    selected = entry and entry.id or nil; showReasons = false
    if entry and not entry.read then R.Mark(entry.id) end
    UpdateDetails(true)
end
function ns.RefreshReview()
    if ns.MinimapButton then
        local unread = R.Unread()
        ns.MinimapButton.Count:SetText(unread > 99 and "99+" or unread > 0 and tostring(unread) or "")
    end
    if not window or not window:IsShown() then return end
    local visible = R.Filtered(filter, query)
    local pages = math.max(1, math.ceil(#visible / PAGE_SIZE)); page = math.min(page, pages)
    local selectedVisible = not selected
    for _, entry in ipairs(visible) do if entry.id == selected then selectedVisible = true end end
    if not selectedVisible or selected and not R.Get(selected) then Select(nil) end
    listTitle:SetText(#visible.." messages  |  "..R.Unread().." unread hidden")
    savedButton:SetText("My reports (" .. #ns.Personal.reports .. ")")
    pageText:SetText("Page " .. page .. " / " .. pages)
    previous:SetEnabled(page > 1); nextPage:SetEnabled(page < pages)
    empty:SetShown(#visible == 0)
    empty:SetText(#R.entries == 0 and "No filtered messages yet.\n\nMessages appear here as the filter catches them."
        or "No messages match this source or search.\n\nTry All sources or clear the search.")
    for i, row in ipairs(rows) do
        local entry = visible[(page - 1) * PAGE_SIZE + i]; row.entry = entry
        if entry then
            local snippet = entry.original:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                :gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("[\r\n]", " ")
            row.label:SetText(Plain(entry.action .. "  |  " .. R.Source(entry)))
            row.alert:SetShown(R.IsUnreadAlert(entry) and ns.DB.captureAlerts ~= false)
            row.preview:SetText(Plain(snippet)); T.RowState(row, entry.id == selected, entry.action)
        end
        row:SetShown(entry ~= nil)
    end
    UpdateDetails(false)
end
function ns.QueueReviewRefresh()
    if queued then return end
    queued = true
    local function Refresh() queued = false; ns.RefreshReview() end
    if C_Timer and C_Timer.After then C_Timer.After(0, Refresh) else Refresh() end
end
function ns.SetReviewTab(tab)
    reviewTab=tab=='shield' and 'shield' or tab=='capture' and 'capture' or 'messages'
    if reviewTab=='shield' and not shieldPage then shieldPage=ns.BuildShieldReview(messagePage:GetParent()) end
    if reviewTab=='capture' and not capturePage then capturePage=ns.BuildCaptureReview(messagePage:GetParent()) end
    messagePage:SetShown(reviewTab=='messages')
    if shieldPage then shieldPage:SetShown(reviewTab=='shield') end
    if capturePage then capturePage:SetShown(reviewTab=='capture') end
    messageTab:SetEnabled(reviewTab~='messages');shieldTab:SetEnabled(reviewTab~='shield')
    captureTab:SetEnabled(reviewTab~='capture')
    if reviewTab=='shield' then ns.RefreshShield() else ns.RefreshReview() end
end
function ns.OpenReview(tab)
    if not window then
        window = T.Window("OlympusChatWardenInbox", UIParent, 940, 678)
        ns.ReviewWindow = window; T.Title(window, "Olympus ChatWarden"); T.Crest(window)
        T.Gold(Text(window, "GameFontNormalLarge", 78, -30, 720, "Review & Protection"))
        T.Muted(Text(window, "GameFontHighlightSmall", 78, -49, 720, "Messages, contact alerts and player management.  v" .. ns.VERSION))
        messageTab=Button(window,"Messages",120,14,-70,function() ns.SetReviewTab('messages') end)
        shieldTab=Button(window,"Shield",120,144,-70,function() ns.SetReviewTab('shield') end)
        captureTab=Button(window,"Chat capture",120,274,-70,function() ns.SetReviewTab('capture') end)
        ns.ReviewRulesButton=Button(window,"My rules",120,806,-70,function() ns.OpenPersonal('rules') end)
        local updates=Button(window,'Updates',100,696,-70,function() ns.OpenUpdates() end)
        T.Tooltip(updates,'Update notes','Read what changed in this release. These notes open once after updating unless you turn that off.')
        T.Tooltip(ns.ReviewRulesButton,'My rules','Open your saved phrase rules directly. Rules apply to new matching chat and supported text; existing chat lines are not rewritten.')
        T.Tooltip(captureTab,"Chat capture","Start or pause local recording, save incident bookmarks and choose what to export. Capture starts off.")
        T.Tooltip(shieldTab,"ChatWarden Shield","Review contact alerts and manage shielded or allowed players. Protection settings are in ChatWarden Options.")
        local pages=CreateFrame("Frame",nil,window);pages:SetPoint("TOPLEFT",0,-38);pages:SetPoint("BOTTOMRIGHT",0,0)
        ns.ReviewHelpButton=Button(pages,'Help',86,726,-577,function()
            ns.OpenTutorial(reviewTab=='capture' and 'capture' or reviewTab=='shield' and 'shield' or 'reports')
        end)
        ns.ReviewSettingsButton=Button(pages,'Settings',100,826,-577,function() SlashCmdList.OLYMPUSCHATWARDEN('options') end)
        T.Tooltip(ns.ReviewSettingsButton,'Settings','Open ChatWarden settings. This button stays here on every review tab.')
        messagePage=CreateFrame("Frame",nil,pages);messagePage:SetAllPoints(pages)
        local toolbar = T.Panel(messagePage, 14, -70, 912, 44)
        Text(toolbar, "GameFontHighlightSmall", 10, -15, 50, "Source")
        local sources = {}; for _, choice in ipairs(T.Sources) do if choice[1] ~= "manual" then sources[#sources + 1] = choice end end
        sourceDropdown = T.Dropdown(toolbar, 57, -9, 157, sources, function() return filter end, function(value)
            filter = value; page = 1; Select(nil); ns.RefreshReview()
        end)
        local search = CreateFrame("EditBox", nil, toolbar, "SearchBoxTemplate")
        search:SetSize(225, 24); search:SetPoint("TOPLEFT", 230, -10); search:SetAutoFocus(false); search:SetMaxLetters(128)
        search:SetScript("OnTextChanged", function(self)
            if SearchBoxTemplate_OnTextChanged then SearchBoxTemplate_OnTextChanged(self) end
            query = self:GetText() or ""; page = 1; Select(nil); ns.QueueReviewRefresh()
        end)
        search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        T.TextField(search)
        Button(toolbar, "Report a miss", 130, 472, -10, function() ns.OpenReport(nil) end)
        savedButton = Button(toolbar, "Saved reports", 130, 612, -10, function() ns.OpenPersonal("reports") end)
        ns.MessagesExportButton=Button(toolbar,'Export reports',146,752,-10,function() ns.OpenReportExport() end)
        local list = T.Panel(messagePage, 14, -122, 350, 444)
        local clear = Button(list, "Clear", 73, 264, -7, function()
            if clearArmed then R.Clear(); Select(nil); clearArmed = false; window.ClearHistoryButton:SetText("Clear")
            else clearArmed = true; window.ClearHistoryButton:SetText("Confirm") end
        end)
        window.ClearHistoryButton = clear
        T.Tooltip(clear, "Clear session history", "Removes the messages in this review inbox. Saved reports are kept.")
        window:SetScript("OnHide", function() clearArmed = false; clear:SetText("Clear") end)
        listTitle = Text(list, "GameFontHighlightSmall", 12, -12, 245)
        empty = T.Muted(Text(list, "GameFontHighlight", 18, -68, 314))
        rows = {}
        for i = 1, PAGE_SIZE do
            local row = CreateFrame("Button", nil, list)
            row:SetSize(332, 42); row:SetPoint("TOPLEFT", 9, -34 - (i - 1) * 44)
            row.background = row:CreateTexture(nil, "BACKGROUND"); row.background:SetAllPoints()
            row.alert = T.CaptureBadge(row)
            row.alert:ClearAllPoints(); row.alert:SetPoint("TOPLEFT", 8, -5)
            row.label = Text(row, "GameFontHighlightSmall", 29, -6, 292); row.label:SetWordWrap(false)
            row.preview = T.Muted(Text(row, "GameFontHighlightSmall", 12, -23, 309)); row.preview:SetWordWrap(false)
            T.SkinRow(row); row:SetScript("OnClick", function(self) Select(self.entry); ns.RefreshReview() end)
            rows[i] = row
        end
        previous = Button(messagePage, "Previous", 94, 14, -577, function() page = math.max(1, page - 1); Select(nil); ns.RefreshReview() end)
        nextPage = Button(messagePage, "Next", 94, 270, -577, function() page = page + 1; Select(nil); ns.RefreshReview() end)
        pageText = Text(messagePage, "GameFontHighlightSmall", 121, -583, 145)
        local header = T.Panel(messagePage, 376, -122, 550, 34)
        detailTitle = T.Gold(Text(header, "GameFontNormal", 12, -10, 260))
        allowLanguage = Button(header,'Allow language',126,276,-5,function()
            local entry=R.Get(selected)
            if entry and entry.language then
                if not ns.Language.Allow(entry.language) then ns.OpenLanguageOptions() end
                UpdateDetails(false)
            end
        end)
        ns.ReviewAllowLanguage=allowLanguage
        T.Tooltip(allowLanguage,'Allow language','Adds this language or shared writing system to the list you read. Its text and corresponding name characters stay visible in future. Existing Review entries stay. Wording rules and Shield still apply. Mixed detections open settings.')
        reasonButton = Button(header, "Why filtered?", 130, 409, -5, function() showReasons = not showReasons; UpdateDetails(true) end)
        local paper = T.Panel(messagePage, 376, -159, 550, 407, true)
        detailScroll = CreateFrame("ScrollFrame", nil, paper, "UIPanelScrollFrameTemplate")
        detailScroll:SetPoint("TOPLEFT", 16, -16); detailScroll:SetPoint("BOTTOMRIGHT", -32, 16)
        details=T.ReadOnlyDocument(detailScroll);ns.ReviewDocument=details
        correctButton = Button(messagePage, "Dismiss", 105, 376, -577, function()
            if selected then R.Remove(selected); Select(nil); ns.RefreshReview() end
        end)
        T.Tooltip(correctButton, "Dismiss this message", "Removes it from the session inbox. Saved reports and phrase rules are kept.")
        reportButton = Button(messagePage, "Report problem", 135, 486, -577, function()
            local entry = R.Get(selected); if entry then ns.OpenReport(entry, "False positive") end
        end)
        T.Tooltip(reportButton, "Report a filtering problem", "Saves feedback for ChatWarden. This does not report the player to Blizzard.")
        reportPlayerButton = Button(messagePage, "Report player", 95, 626, -577, function()
            local entry = R.Get(selected)
            local _, status = R.ReportPlayer(entry)
            footer:SetText(status)
        end)
        ns.ReviewReportPlayerButton = reportPlayerButton
        T.Tooltip(reportPlayerButton, "Report player", "Opens Blizzard's report window for the selected live player-chat message. You still choose the reason and submit the report yourself. Old entries may use a player link in chat instead.")
        footer = T.Muted(Text(messagePage, "GameFontHighlightSmall", 18, -615, 898))
        window:SetScript("OnShow", ns.RefreshReview); Select(nil)
    end
    local width = UIParent.GetWidth and UIParent:GetWidth() or 1000
    local height = UIParent.GetHeight and UIParent:GetHeight() or 700
    if width and height and width > 0 and height > 0 then window:SetScale(math.min(1, (width - 30) / 940, (height - 30) / 678)) end
    T.ShowWindow(window); ns.SetReviewTab(tab)
end
function ns.ToggleReview()
    if window and window:IsShown() then window:Hide() else ns.OpenReview() end
end

-- Standalone launcher retired in rc19. Olympus owns the minimap button.
function ns.BuildMinimap() end
