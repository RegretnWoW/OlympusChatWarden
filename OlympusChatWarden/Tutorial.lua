-- Optional plain-language help and a once-per-account welcome introduction.
local _, ns = ...
local T = ns.Theme
local welcome, tutorial, body, scroll, measure, tabs
local pageID, loginReady, queued, deferFrame = "basics", false, false
local pages = {
    {id = "basics", title = "Overview", text = [[OLYMPUS CHATWARDEN

Open the ChatWarden workspace from Olympus or /ocw. Overview is the default page. Use the sidebar for pages and horizontal tabs for views.

ACCESS

ChatWarden requires Olympus as a separate word in your current character's guild name. This temporary local check does not verify official affiliation. When Olympus provides its membership API, that check takes priority.

Guild changes are checked automatically. All features stop outside a qualifying guild, including capture, reports, exports and pack actions. Open tools close and settings lock. Saved data is kept; access resumes when the character qualifies.

Messages: your filtering feed across all channels, including whispers. Review warnings, replacements, redactions and hidden originals. Ctrl + left-click reveals covered names.
Shield: contact alerts and shielded or allowed players.
Mentions: your full character name, nicknames and literal watch phrases. Badges start on; sound and toast start off.
Chat capture: saved chat, incident bookmarks and whisper conversations. Recording starts off.

DISPLAY

Gold [!]: warning; the message remains visible.
Bronze bars: matching words are covered.
Gray text: a wording replacement.
Hidden: removed from chat; its original remains in Messages.

Ctrl + left-click a covered phrase to reveal or cover it. Hold Ctrl to reveal filtered tooltip text. Some protected labels do not support click-to-reveal.

Messages contains wording/language filtering activity: warnings, replacements, redactions and hidden messages. Ordinary chat stays out. Warnings and replacements appear quietly; the Messages badge counts eligible unread hides by default. Redaction alerts have a separate switch and start off. Shield, spam and advertising records appear in Shield; Mentions contains mention activity. Overview combines these feeds. Select an entry to clear its category's unread state. Language-only filtering and spam/advertising notifications start quiet. Settings > Notifications controls badges, categories and Shield notices without changing filtering.

STORAGE

Messages, Mentions, contact alerts and read states now survive reloads and logins, separately for each character. History restores quietly and oldest records roll off at the limits.

Settings > Activity history controls saving and Clear all history for this character. Clearing history keeps rules, reports, capture, bookmarks and protection lists. Session shields still end on logout or reload; saved timed shields retain their original expiry.

COMMANDS

/ocw: overview
/ocw settings: settings
/ocw overview: dashboard
/ocw mentions: mention alerts
/ocw inbox: message review
/ocw shield: player management
/ocw capture: recording and bookmarks
/ocw export: report export preview
/ocw languages: language settings
/ocw spelling: spelling suggestions
/ocw help: this guide]]},
    {id = "mentions", title = "Mentions", text = [[MENTION ALERTS

Open Mentions or /ocw mentions. Use the page’s Enable/Pause Mentions button or click its icon to toggle alerts. Your full current character name, including the Forever surname, is watched automatically. Mention settings lets you add nicknames and literal watch phrases, edit or disable them, and choose channels.

Badges start on; sound and toast start off. Optional sound and toast share an adjustable cooldown. Your own messages, duplicate deliveries, hidden chat and shielded contacts do not trigger mention alerts. Redacted previews stay redacted. Multiple phrases in one message create one entry.

Read an entry or use Mark all read for the current category. Overview, category pages and the Olympus launcher share their unread counts. Reading Messages does not clear an unread mention from the same line.

The shared activity stream is limited to 300 entries or 1 MB in memory. Messages, Mentions, contact alerts and read states are saved per character by default. Saved history has a 2 MB budget per character, 12 characters and 8 MB total. Use Settings > Activity history to stop remembering or clear this character’s activity. Watch phrases and channel preferences persist. Capture stays opt-in and is independent of mention detection.]]},
    {id = "confidence", title = "Filtering", text = [[SENSITIVITY

Mild: warns on strong eligible expressions. Mild unwanted opinions stay visible.
Balanced (new-user default): follows the author's display preferences. Mild unwanted support or criticism warns; stronger promotion or attacks redact.
Broad: hides eligible unwanted expressions and recognizes wider selected topics.
Context handling keeps neutral references, genuine questions, quotations and the opposite stance visible. Recognized explicit threats use separate protection.
Gommage starts off. It is the separate, deliberately exaggerated meme option: cover the original curated lists in any preset, even inside criticism or questions.

RESULTS

Warnings keep the message visible. Redactions cover matched wording. Hidden messages retain their original for review.
Current terminology packs recognize topics without filtering a bare reference. They filter support/promotion of the author's selected concepts and leave criticism visible. Protected subjects such as USA have the opposite direction: praise stays visible and directed attacks may filter. Broad recognizes wider topics, but does not bypass the context checks.
Examples in Balanced: DEI is useful warns; We should adopt DEI hiring policies redacts; What does DEI mean stays visible. USA sucks redacts; Why does USA suck stays visible.
Topic preferences, replacements and Gommage masks are separate from abuse signals and cannot automatically shield a sender.

Actions follow topic relevance, expressed stance and strength, then the preset. Why filtered? and reports retain those separate interpretations. They are bounded wording inferences, not calibrated probabilities or a judgment about a player.

Context handling is always active; the old switch has been removed. Choose Mild, Balanced or Broad to adjust actions. Genuine questions and reported wording are interpreted separately from direct assertions.

EXPERIMENTAL INCOMING TYPO FILTERING

This build also checks close English spelling guesses in other players' chat, including eligible words in directed statement patterns. Matching keeps the selected action policy. Gommage guesses add no score. Originals remain unchanged in Review and reports. Incorrect guesses are possible.

Settings > Spelling > Typo-aware incoming filtering starts enabled in Balanced mode by default. Choose Balanced, Aggressive or Off to compare; subsequent choices persist. Typing highlights and automatic correction are separate. Your own messages, names, NPC/system text and native hyperlinks are excluded from the extra pass. Existing rc60 signed packs remain valid.

REVIEW

Select a message and choose Why filtered? for its matched rules. Report problem saves feedback about ChatWarden. Report player opens Blizzard's report flow for a player-chat message; you still choose the reason and submit it yourself. Saving a ChatWarden report alone does not change filtering.

Personal phrase rules can keep text visible, warn, redact, hide or replace it. Other matching rules and coverage settings still apply.]]},
    {id = "presets", title = "Settings", text = [[SETTINGS WORKSPACE

The Settings landing page opens Filtering, Languages, Shield, Spam, Notifications and Spelling. Each detail page uses the full workspace. Filtering includes direct sensitivity dropdowns for installed packs. Spelling has a scrolling personal dictionary. Mention preferences remain in Mentions > Mention settings. Window size is available from the Settings landing page.

COVERAGE

Player chat and accessible chat bubbles start on. NPC chat, quests/dialogue, vendors, names, nameplates and general tooltip filtering start off.

Barber & body-type wording starts on. It replaces Body Type 1 with Male and Body Type 2 with Female. These replacements are built in.

NAME LABELS

Chat names follow Player chat wording rules. For other labels, enable Player names or NPC names, then Unit-frame names or Nameplates. Language name covering has its own switch. Enable nameplate visibility in WoW separately.

Filtering preserves native targeting and selection. Protected labels may be unavailable, especially in combat. Floating-name Ctrl-click is experimental; read originals in Messages if it does not respond.

SIGNED IMPORTS

Olympus Protection and King Protection are included. No additional vocabulary packs are bundled.

Rule packs > Paste import > Verify pack. Review the result and enabled state, then Install pack. Only author-signed data is accepted. Verification does not install a pack by itself.

Each installed category can follow the main sensitivity, use its own sensitivity or be turned off. Imports and their enabled states persist across reloads.

Updates are checked only against the catalog bundled with the addon. Get packs link opens a copyable download location. No automatic download or installation occurs.]]},
    {id = "shield", title = "Shield", text = [[CONTACT PROTECTION

Shield starts on. Settings > ChatWarden > Shield has switches for each protection.

Strong-wording whispers: 3 in 2 minutes; shield 10 minutes.
Repeated whispers: 6 in 30 seconds; shield 10 minutes.
Trades, duels and group invites: 4 requests in 60 seconds; shield 5 minutes.

These are Balanced defaults and are shown beneath every check, including while Custom limits are selected. Settings > Shield offers Custom limits for each check: 2–20 triggers, a 10–600 second window and 1–60 timeout minutes. Apply saves all limits together and resets detection counters. Reset defaults restores Balanced. Existing shield timers keep their expiry. Your individual protection switches are retained.

REPEATED WHISPERS

Counts identical or slightly changed incoming whispers from one player. Case, punctuation and spacing changes are normalized. Replying resets that player's counter. Allowed players are exempt. No word match or chat recording is required.

SPAM PROTECTION

Open Shield settings > Spam protection. Each check and chat type has its own switch. Public chat, whispers, groups and guild/officer chat start checked.

Sales ads: website plus gold or paid-service wording. Common lookalike letters are recognized. Links alone do not trigger it. Applies the automatic timeout.

Guild recruitment: recruiting, direct guild invites and named-guild raid/team pitches with a reply or sign-up request. Hides the ad without timing out the player. Olympus guild ads are exempt by name; this does not verify affiliation. Guild mentions and Discord links alone stay visible.

Repeated messages: 3 identical or similar messages in 30 seconds. Applies the automatic timeout.

Rapid chat: 5 messages in 10 seconds, even with different text. First burst pauses that player's chat for 10 seconds. A second new burst within a minute applies the automatic timeout. Slower messages do not extend the pause.

These limits are fixed. Automatic timeout is adjustable and starts at 15 minutes. Counts follow one player across checked chat types; duplicate deliveries to chat windows count once. Pauses affect chat only. Timed shields also use your enabled contact protections. Existing shields are kept on upgrade.

Review > Shield shows alerts and recent examples. Remove shield ends a pause or timeout. Allow player bypasses these checks. Hidden originals stay in Messages. Repeated-message spam, rapid chat and ads have separate notification switches and start quiet. Settings > ChatWarden > Notifications controls badges and chat notices without changing filtering.

Reports keep spam settings, the pause/timeout stage and the recorded filter result. Event-only captures have no confirmed result. Battle.net, NPC and your own messages are excluded. Counters and brief pauses clear on reload; chat recording is not required.

PLAYER MANAGEMENT

Shield > Recent alerts, Active shields or Allowed players. Select a player to see applicable actions. Remove shield ends a stored shield; End chat pause clears a brief pause. An unshielded player offers Add shield, and an allowed player offers Stop allowing. Historical alerts remain after removal with the current status.

Add player accepts a full name (and realm when needed). Duplicate identities are rejected without changing the existing duration. A new shield opens Active shields with the player selected. Allowed players still use ordinary word filters.

Right-click player names for shortcuts. Export shields opens a selectable privacy preview. Shields are local preferences, not moderator findings.

LIMITS

Request declines depend on client support. Bubbles require reliable speaker attribution. Battle.net whispers are not covered.

OLYMPUSMUTE SIGNAL TOOLTIPS

On by default. Adds ChatWarden: OlympusMute Signal Detected when compatible sharing was observed. This does not prove current addon use; absence of a note proves nothing. Observations have no age expiry, with a 10,000-player limit. Disabling detection preserves history.]]},
    {id = "capture", title = "Chat capture", text = [[RECORDING

Open Capture or /ocw capture. Start Capture and the page icon both toggle recording; the button becomes Pause Capture while recording. Use Capture settings for whisper and guild/officer switches.

Records supported player chat, including your own messages. Continues across normal logouts and reloads until paused. Recording is independent of word filtering.

Battle.net, NPC and addon traffic are excluded. Turning off a chat-type switch affects future recording only.

STORAGE

Up to 5,000 lines or 4 MB. No age expiry. Oldest lines are replaced when full. Pause keeps existing records. Clear capture deletes the rolling log but keeps bookmarks.

BOOKMARKS

Select a line, enter a title or note, then Save bookmark. Saves up to 10 already captured lines before and after it. Future messages are not added.

The Bookmarks tab lists saved incidents. Titles and notes can be updated. Limit: 50 bookmarks or 1 MB, separate from the rolling capture.

RIGHT-CLICK ACTIONS

Chat-name menus offer Start/Pause capture, View captured chat and Bookmark this chat message. Exact-line bookmarking requires that line in the current session capture. Otherwise, select a saved line manually.

EXPORT

Search or select a view, then Export shown. Choose entries and privacy settings in the preview. Each bookmark includes its saved stretch. Remove individual lines in the final text if needed.]]},
    {id = "languages", title = "Languages", text = [[LANGUAGE FILTERING

SETUP

Open /ocw languages. Turn on Enable language filtering and check the languages you read. English stays allowed. The master switch starts off.

DEFAULTS WHEN ENABLED

Low confidence: redact detected text.
High confidence: hide message.
Filter player names too: off.
Confidence always runs with a fixed minimum of 4 letters per portion.

MOSTLY NON-PREFERRED TEXT

When at least 85% of readable letters are detected as non-preferred, use the High action. This includes recognized writing systems whose exact language is uncertain. A wholly Cyrillic message can therefore be hidden without claiming it is definitely Russian or Ukrainian. Messages explains this rule separately from confidence.

ACTION CHOICES

Redact detected text: cover matching portions; keep the rest readable.
Hide message: remove the whole qualifying line, including its name.
Label only: keep the message readable with a language label.
Leave visible: make no language change.

Both dropdowns offer these actions. Low handles partial, less certain matches. High handles strong estimates and mostly non-preferred text. Your choice to Hide also applies to qualifying mixed messages.

PLAYER NAMES

Enable Filter player names too to cover matching names alongside redacted text. Hidden messages already hide their names. Label-only and Leave visible results keep names readable. English-only and preferred-language replies stay visible with the matching name covered. A name alone never hides a message or increases confidence.

The same reading list controls names. Cyrillic names cannot distinguish Russian from Ukrainian; allowing either keeps Cyrillic names. Han uses its shared Chinese/Japanese entry. Latin names cannot identify a language reliably; use My rules for a specific name.

Personal/category rules still apply to chat names separately. Covered names appear in Messages as Player name entries. Ctrl + left-click reveals or covers them. Normal clicks and right-click menus keep the real player identity.

REVIEW AND REPORTS

Hidden-message alerts start on and redaction alerts start off. Enable either independently in Notifications; category preferences still apply. Select one to clear its badges everywhere. Why filtered? shows the detection and action rule. Allow language updates the reading list.

Report a problem saves feedback. Report a miss from the player's chat-name menu or paste an example. Received examples keep their message-time settings and action rule; pasted examples use current settings. Export previews let you select records, hide known names and omit notes.

COVERAGE

Use the Public, Whispers, Group and Guild switches. Your own messages, NPC chat, emotes and Battle.net are excluded from language message rules. Four letters is eligibility, not proof. Unknown Latin text and unsupported scripts may stay visible. Protected labels may remain visible. Review and chat capture keep originals. Word filters and Shield remain independent.]]},
    {id = "reports", title = "Reports", text = [[SAVE FEEDBACK

Missed message: Report a missed message, or right-click a chat name > Report missed filter.
Incorrect result: select the original in Messages > Report a problem.

Choose the expected action, add a note if needed, and save. A report records feedback only. Also apply a personal phrase rule changes your filter immediately.

READ AND SHARE REPORTS

Reports includes Read reports and Share preview in the main workspace. Read reports shows the original and your feedback. Share preview selects the reports to export and controls privacy. Rules has its own sidebar page.

EXPORT PREVIEW

Reports, Shield lists, captured chat and bookmarks use the same preview. The page heading identifies the current tool: Report exports, Shield exports, Chat Capture exports or Bookmark exports.

1. Select the entries to include.
2. Choose whether to hide known player names.
3. Choose whether to include notes and Shield reasons.
4. Enter other names to hide if required.
5. Review and edit the final text.
6. Select all text, Ctrl+C, then paste into your chosen reporting channel.

Known names start hidden. Notes start excluded. Name removal does not guarantee anonymity; check the final text for other identifying details.

Selections and privacy changes rebuild the preview. Make final text edits last. New messages do not alter the open export batch.

Filter feedback retains matched-rule details. Signed pack exports preserve their complete signed text. Nothing is submitted automatically.]]},
    {id = "spelling", title = "Spelling", text = [[SPELLING ASSISTANCE

Enable spelling highlights in Settings > Spelling. This starts off.

Possible English spelling mistakes receive an orange highlight in accessible one-line text inputs. Right-click a highlighted word to choose a suggestion, save a personal word or ignore it until reload.

Automatic correction is a separate option and starts off. It applies a clear best correction after you finish a word. Ambiguous text stays unchanged. Corrections never send the message.

Password, protected, numeric, IME, code/import and read-only fields are excluded. Links, known player names and common WoW terms are skipped. American and British spellings are supported. No text leaves the game.

INCOMING FILTERING

Typo-aware incoming filtering is separate from typing assistance. Balanced is enabled once by default. It matches installed phrases while using the English dictionary to protect correctly spelled words, without loading the suggestion index. Known names and ambiguous different guesses stay unchanged. Choose Balanced, Aggressive or Off in Settings > Spelling. Why filtered? and saved reports preserve originals, guesses, edit counts and the message-time mode. Optional watch-phrase typo alerts are in Mention settings; names and nicknames remain literal.

WINDOWS AND UPDATE NOTES

All addon pages, editors, exports and guides now share one bronze main window with compact page bars. Overview feature icons and the header Filtering/Shield icons toggle their features. Inactive icons have a minus badge. Messages shows selected originals automatically; Overview keeps a safe preview until Show original is clicked. Details and Actions have separate framed boxes. Lists use padded rows and always-visible scrollbars, and keep your place as new messages arrive. Blue buttons indicate selected views or primary actions, gray buttons navigate or offer utilities, and red buttons remove data or protection. Updates contains the 1.0 launch tour and feature locations. Settings > Window size lets you save a 50-150% size using the slider or typed input; Fit to screen restores automatic sizing. Use the sidebar and tabs to switch views. Drag the header to move the workspace. Dropdowns and spelling suggestions close when switching views.

Rules contains personal phrase actions. Reports contains saved filter feedback and its Share preview. They have separate pages; reports never change rules automatically.

Update notes appear once after an installed release changes. Use /ocw updates or the Updates sidebar page to reopen them. Turn off automatic notes on that screen if desired.]]},}
ns.HelpPages = pages
local function Label(parent, text, x, y, width, font, paper)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y); label:SetWidth(width); label:SetJustifyH("LEFT"); label:SetText(text)
    if paper then T.Ink(label) else T.Light(label) end
    return label
end
local function Button(parent, text, x, y, width, fn)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24); button:SetPoint("TOPLEFT", x, y); button:SetText(text); button:SetScript("OnClick", fn); T.ActionHelp(button, text)
    return button
end
local function Fit(window)
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    if w and h and w > 30 and h > 30 then
        window:SetScale(math.min(1, (w - 30) / window:GetWidth(), (h - 30) / window:GetHeight()))
    end
end
local function Page(id)
    for _, page in ipairs(pages) do if page.id == id then return page end end
end
function ns.TutorialTopics()
    local topics={};for _,page in ipairs(pages) do topics[#topics+1]={id=page.id,title=page.title} end;return topics
end
function ns.TutorialPage(id) return Page(id) or pages[1] end
local function SetPage(id)
    local page = Page(id) or pages[1]; pageID = page.id
    tutorial.Heading:SetText(page.title)
    body:SetText(page.text); body:SetCursorPosition(0); body:ClearFocus()
    scroll:SetVerticalScroll(0)
    for i, tab in ipairs(tabs) do tab:SetEnabled(pages[i].id ~= pageID) end
end
function ns.OpenTutorial(requestedPage)
    if not ns.DB then return end
    if not tutorial then
        tutorial = T.Window("OlympusChatWardenGuide", UIParent, 780, 620)
        ns.TutorialWindow = tutorial; T.Title(tutorial, ns.NAME); T.Crest(tutorial)
        tutorial.Heading = T.Gold(Label(tutorial, "How filtering works", 78, -30, 670, "GameFontNormalLarge"))
        T.Muted(Label(tutorial, "Filtering, contact protection, recording and export reference.", 78, -50, 670))
        local navigation = T.Panel(tutorial, 14, -76, 752, 42); tabs = {}
        for i, page in ipairs(pages) do
            local id = page.id
            local step = math.floor(732 / #pages)
            tabs[i] = Button(navigation, page.title, 10 + (i - 1) * step, -9, step - 8, function() SetPage(id) end)
        end
        local paper = T.Panel(tutorial, 14, -126, 752, 428, true)
        scroll = CreateFrame("ScrollFrame", nil, paper, "UIPanelScrollFrameTemplate")
        scroll:SetSize(700, 390); scroll:SetPoint("TOPLEFT", 18, -18)
        body = CreateFrame("EditBox", nil, scroll); ns.TutorialText = body;body.ChatWardenNoSpelling=true
        body:SetMultiLine(true); body:SetAutoFocus(false); T.Body(body); T.Ink(body)
        body:SetSize(696, 390); scroll:SetScrollChild(body)
        measure = body:CreateFontString(nil, "OVERLAY"); T.Body(measure)
        measure:SetWordWrap(true); measure:SetWidth(696); measure:Hide()
        body:SetScript("OnTextChanged", function(self, userInput)
            if userInput then self:SetText(Page(pageID).text); return end
            measure:SetText(self:GetText() or "")
            local _, lines = (self:GetText() or ""):gsub("\n", "\n")
            self:SetHeight(math.max(390, (lines + 3) * 18, measure:GetStringHeight() + 30))
        end)
        body:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        T.TextField(body, scroll)
        Button(tutorial, "Try preview", 18, -569, 145, ns.MakeDemo)
        Button(tutorial, "Settings", 175, -569, 130, function() SlashCmdList.OLYMPUSCHATWARDEN("options") end)
        Button(tutorial, "My reports", 317, -569, 145, function() ns.OpenPersonal("reports") end)
        Button(tutorial, "Rule packs", 474, -569, 175, function() ns.OpenPacks() end)
        Button(tutorial, "Close", 662, -569, 100, function() tutorial:Hide() end)
        tutorial:HookScript("OnHide", function() body:ClearFocus() end)
    end
    SetPage(type(requestedPage) == "string" and requestedPage or pageID)
    Fit(tutorial); T.ShowWindow(tutorial)
end
function ns.OpenWelcome()
    if not ns.DB then return end
    if InCombatLockdown and InCombatLockdown() then
        ns.Print("Open the introduction after combat with /ocw welcome."); return
    end
    if not welcome then
        welcome = T.Window("OlympusChatWardenWelcome", UIParent, 680, 530)
        ns.WelcomeWindow = welcome; T.Title(welcome, ns.NAME); T.Crest(welcome)
        T.Gold(Label(welcome, "Olympus ChatWarden overview", 78, -30, 570, "GameFontNormalLarge"))
        T.Muted(Label(welcome, "Local filtering, contact protection and optional chat recording.", 78, -50, 570))
        local cards = {
            {"Filtering and review", "Configure sensitivity and coverage in Settings. Messages retains filtered originals. Select hidden messages to clear their unread badges."},
            {"Contact protection", "Shield starts on with Balanced protection. It detects strong wording, repeated whispers and repeated requests. Manage players in Review > Shield."},
            {"Chat capture and exports", "Recording starts off. Start it in Chat capture, save incident bookmarks, and select entries and privacy options before copying an export."},
        }
        for i, card in ipairs(cards) do
            local panel = T.Panel(welcome, 18, -84 - (i - 1) * 98, 644, 88, true)
            T.Heading(Label(panel, card[1], 14, -12, 616, "GameFontNormal", true))
            Label(panel, card[2], 14, -34, 616, nil, true)
        end
        welcome.Status = T.Muted(Label(welcome, "", 20, -398, 640))
        T.Muted(Label(welcome, "Open this overview with /ocw welcome. Full reference: /ocw help.", 20, -432, 640))
        Button(welcome, "Close", 20, -470, 110, function() welcome:Hide() end)
        Button(welcome, "Settings", 142, -470, 140, function()
            SlashCmdList.OLYMPUSCHATWARDEN("options")
        end)
        Button(welcome, "How filtering works", 294, -470, 200, function()
            ns.OpenTutorial("basics")
        end)
        T.Muted(Label(welcome, "Data stays local. Reports are shared only when you copy and submit them.", 20, -507, 640))
    end
    local preset = ({aggressive = "Broad", balanced = "Balanced", strict = "Mild"})[ns.DB.preset] or 'Balanced'
    welcome.Status:SetHeight(34)
    welcome.Status:SetText("Filter: " .. (ns.Active() and "active" or "paused") .. "  |  Current sensitivity: " .. preset
        .. (ns.Membership and ("\n" .. ns.Membership.Status()) or ""))
    Fit(welcome); T.ShowWindow(welcome)
    if welcome:IsShown() then ns.DB.welcomeSeen = 1 end
end
function ns.CheckWelcome(event)
    if event == "PLAYER_LOGIN" then loginReady = true end
    if not loginReady and IsLoggedIn then loginReady = IsLoggedIn() == true end
    if not loginReady or not ns.DB or ns.DB.welcomeSeen == 1 or queued
        or InCombatLockdown and InCombatLockdown() or not UIParent:IsVisible() then return end
    queued = true
    local function Show()
        queued = false
        if ns.DB and ns.DB.welcomeSeen ~= 1 and UIParent:IsVisible()
            and not (InCombatLockdown and InCombatLockdown()) then ns.OpenWelcome() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Show)
    else
        if not deferFrame then deferFrame = CreateFrame("Frame") end
        deferFrame:SetScript("OnUpdate", function(self) self:SetScript("OnUpdate", nil); Show() end)
    end
end
