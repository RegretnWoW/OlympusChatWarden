-- Optional plain-language help and a once-per-account welcome introduction.
local _, ns = ...
local T = ns.Theme
local welcome, tutorial, body, scroll, measure, tabs
local pageID, loginReady, queued, deferFrame = "basics", false, false
local pages = {
    {id = "basics", title = "Overview", text = [[GETTING STARTED

Open ChatWarden from Olympus or type /ocw. Overview brings your filtering, mentions, Shield and Wanted alerts together.

Messages: Read filtered messages and see why they matched.
Alerts: Find personal mentions and Olympus Wanted encounters. Choose a type with the tabs.
Shield: Manage unwanted contact and players you have shielded.
Capture: Record chat when you want to keep a conversation.
Recording: Inspect your optional Chronicle and Player Intelligence history, and back it up.
Rules: Add your own phrases and replacements.
Packs: Choose which optional topics to filter.
Reports: Save examples of missed or incorrect filtering.
Updates: Read patch highlights, browse older updates, take the tour or open this guide.

READING FILTERED CHAT

A gold [!] is a warning. The message stays visible.
Bronze bars cover matching words. Ctrl + left-click to reveal or cover them again.
Replacements change the displayed wording. Hidden messages leave chat, but you can read their originals in Messages.

Select a feed entry to mark it read. Each feed has its own unread count. Nothing is sent automatically.

GUILD ACCESS

With Olympus 1.2.4 or later, open /oly privacy and choose Yes for Olympus ChatWarden. Olympus then checks your membership. Your guild and guild rank appear above Zeus in the full UI. A title appears only when Olympus supplies a selected title. Connection status is in the top bar. Right-click ChatWarden's tab in Olympus to open the full UI.

Older Olympus versions use the local guild-name check. Protection pauses when access is missing; your settings and saved activity are kept.

USEFUL COMMANDS

/ocw: Open ChatWarden.
/ocw alerts: Open Alerts. /ocw mentions also works.
/ocw capture: Open Capture.
/ocw test <phrase>: Check how your word filters handle a phrase, without posting it.
/ocw updates: Read patch highlights.
/ocw help: Open this guide.]]},
    {id = "wanted", title = "Wanted alerts", text = [[OLYMPUS WANTED ALERTS

Wanted encounters appear in Alerts > Wanted, Overview > View All and the compact Olympus panel's scrolling list.

An encounter means an attackable player you targeted or moused over matched a GUID on Olympus's Wanted list. Its entry saves the time, zone and Olympus-listed bounty.

An exact full listed name in visible chat gets a small Wanted icon. Hover for the listed bounty and kills. This works in your own chat and outgoing whispers too. Chat icons do not create feed entries, badges, sounds or popups. First names alone, typo guesses, hidden messages and covered names do not match.

Open Alerts > Wanted settings to choose encounter sounds, popups and badges, or change the cooldown. Sound and toast start off. The default encounter cooldown is five minutes per player. Chat icons have their own switch and never send notifications.

Olympus supplies and manages the Wanted board. ChatWarden saves your personal alerts and their historical bounty details. Grant access in /oly privacy; permission loss pauses alerts and clears the live list. Saved alerts follow your Activity history setting.]]},
    {id = "recording", title = "Recording", text = [[YOUR WARDEN HISTORY

Recording > Activities connects your saved dungeon, raid, group and PvP visit records. Choose a player to see associated history, inspect boss results and open original evidence. A damage meter is not required. The complete Chronicle timeline and player dossiers will build on this foundation.

The first-login explanation asks whether to start. Older recording scopes need a fresh choice; valid scope5 consent stays and old history is kept. Choose Enable recording or Not now. Reopen the explanation with /ocw chronicle prompt. Change your choice under Settings > Chronicle & Intel.

WHAT IS SAVED

Save supported progress, equipment, bags, quests, spells, reputation, character states and identifiable player observations. Precise samples of your own travels support future map playback. Save permitted Olympus Wanted lists, your profile and public rankings. Each record keeps its source and time. Unknown stays unknown. Raw combat logs are disabled; Capture and alert sounds stay independent.

Some facts come from Olympus's shared information, such as Wanted listings. Your recorded history stays on this computer. ChatWarden does not upload it. Future sharing would need a separate choice.

READ YOUR HISTORY

Open Recording > Activities for your first shared-activity history. Roster association is not confirmed boss attendance; an exit is not dungeon completion. Reloads and recording gaps remain separate segments. Performance matching stays unavailable until validated.

Open Recording > Intelligence for measured time, recorded days/weeks/months, player encounters and roster relationships, native credit evidence, battleground visits, progression, deaths and exploration. Scoreboard observations stay separate when match identity is uncertain. A native credit is not a solo victory, and an enemy nearby when you died does not identify a killer.

Open Recorded Events for the original evidence. Events is the quiet default, showing milestones, boss results and meaningful changes. Choose All recorded data for observations and background collection, or select your own event types. These filters never delete history or change recording.

Time spans, stationary route runs and multipart Olympus updates keep the list compact. Select a record for original details; Show raw Olympus parts exposes separate saved parts. Refresh saves pending route/time buffers. Collection Status has a scrollable list: click an item for what it saves, when it records, an example and its limits. Recording statistics also open these explanations. Search, filter and Newer/Older reach older history. Browsing works with recording off; history stays until you clear it.

BACK UP BEFORE CHANGING PCs

Open Recording > Backup & Restore. File backup is the default. Exit WoW normally and keep it closed. Copy WTF/Account/<account>/SavedVariables/OlympusChatWarden.lua to another drive, or use the optional Windows Backup Tool for one verified ZIP. It keeps a safety copy before restoring. Full-file restore replaces all saved ChatWarden settings and history.

Choose History-only text merge to combine records without replacing settings. Pause recording, create a snapshot and copy every numbered part to a text file. Creation runs in small steps. Resume recording when the snapshot is ready. To restore, pause recording and paste each part separately. Click Restore this part twice. Imports merge history, keep existing notes and leave recording off. Keep backups private.]]},
    {id = "mentions", title = "Mentions", text = [[WATCH YOUR NAME

Mentions watches your first name and full character name. For Rune Escape, both "Rune, ready?" and "Rune Escape, ready?" work. No @ is needed. A surname alone does not match automatically.

Open Alerts > Mention settings to add nicknames or watch phrases and choose your channels. Names and nicknames match exactly, ignoring letter case. Close typo matching is available for watch phrases.

ALERTS

Mentions starts on. Badges are on; sound and popup alerts start off. You can enable either in Mention settings and set a cooldown.

The cooldown limits sounds and popups, not feed entries. Several matches in one message still create one entry.

Your own messages, hidden messages and shielded players stay quiet. Covered text stays covered in the preview.

KEEPING YOUR PLACE

Select an entry to mark it read, or choose Mark all read. The Mentions and Wanted tabs each mark only their own type read; All alerts marks both. Reading Messages does not clear an unread mention from the same message.

Mentions works with Capture off. Saved mentions, read states and watch phrases return after reload. Settings > Activity history controls saved feed history.]]},
    {id = "confidence", title = "Filtering", text = [[CHOOSE A PRESET

Mild: Leaves mild opinions visible and warns on stronger wording.
Balanced: The default. Warns on mild opinions, covers stronger wording and hides serious directed abuse.
Strict: Takes stronger action on the same topics. It does not turn on extra packs.

Clear real-world threats against covered players or groups can be hidden in every preset. Ordinary combat talk is left visible when the meaning is unclear.

WHAT PACKS DO

Olympus Protection and King Protection are included. Other topics come from optional packs you import and enable.

Each pack has its own topic and direction. For example, USA Protection checks insults about the USA. Terminology packs check support or promotion of their selected topics. Questions, neutral discussion and criticism are usually left visible.

Gommage is a separate meme toggle, off by default. It covers the pack's curated words even in questions or criticism.

CHECK A RESULT

Open Messages, select an entry and choose Why filtered? to see the matches. Ctrl + left-click reveals covered wording where supported.

Report filter problem saves an example for review. It does not change your filters or automatically report the player. Use Rules if you want to change how a phrase is handled now.

TRY A PHRASE

Type /ocw test followed by the phrase. It uses your current word-filter settings and sends nothing. It does not test spam, language filtering or Shield limits.]]},
    {id = "presets", title = "Settings", text = [[WHERE TO FIND THINGS

Settings has pages for Filtering, Languages, Shield, Spam, Notifications and Spelling. Window size and Activity history are on the Settings page. Mention settings and Wanted settings are inside Alerts.

WHAT GETS FILTERED

Player chat and chat bubbles start on. NPC text, quests, vendors, names and general tooltip filtering start off. Choose the places you want in Settings > Filtering.

Barber & body-type wording replaces Body Type 1 with Male and Body Type 2 with Female. Turn off that switch to stop both the built-in replacements and imported label variants.

Names and nameplates are experimental. Enable the name filter and the display option you want to use. WoW controls whether nameplates are visible. Some protected labels cannot be changed or clicked, especially in combat. Read covered names in Messages if reveal does not work on a label.

IMPORT A PACK

Open the separate pack download and choose a file from Import These Packs. Copy the whole file, then open Packs > Import signed pack > Verify pack > Install pack.

Updating the addon does not update your imported packs. Import the newer file to get its changes and name. Your enabled choice and sensitivity are kept.

Each installed pack can follow your main preset, use its own preset or be turned off. Packs marked Update Required pause until updated. Body-label replacements v7 remains compatible.

WINDOW AND HISTORY

Drag the top bar to move ChatWarden. Settings > Window size changes its size; Fit to screen restores the automatic size.

Settings > Activity history controls saved Messages, Alerts and Shield activity for this character. Clearing history keeps your rules, reports, Capture and bookmarks.]]},
    {id = "shield", title = "Shield", text = [[CONTACT PROTECTION

Shield helps with repeated whispers, unwanted requests and strong directed abuse. It starts on. Open Settings > Shield to choose which checks to use.

Balanced defaults:
Strong-wording whispers: 3 in 2 minutes; shield for 10 minutes.
Repeated whispers: 6 in 30 seconds; shield for 10 minutes.
Trades, duels and group invites: 4 in 60 seconds; shield for 5 minutes.

Replying resets that player's repeated-whisper counter. Accepting a request resets its request counter. A warning or redaction alone does not make someone eligible for a shield.

MANAGE PLAYERS

Use Recent alerts, Active shields and Allowed players. Select a player to add or remove a shield, end a chat pause or change their allowed status.

Allowed players bypass Shield checks. Your ordinary word filters still apply. Enter the full player name when adding someone; include the realm if needed.

SPAM

Settings > Spam controls sales ads, guild recruitment, repeated messages and rapid chat. The automatic timeout starts at 15 minutes.

Guild recruitment ads are hidden without timing out the sender. Olympus guild ads are exempt. A link or guild mention alone is not enough.

Spam notices start quiet. You can change them in Settings > Notifications. Capture does not need to be running.

CUSTOM LIMITS

Choose Custom limits in Settings > Shield, enter your values and apply them. Applying changes resets detection counters, while existing shields keep their end times. Battle.net whispers are not covered.]]},
    {id = "capture", title = "Chat Capture", text = [[START RECORDING

Capture starts off. Click Start Capture or the icon beside the page title to begin. Pause Capture stops new recording and keeps what you have saved.

Capture settings controls whispers and guild/officer chat. Your own messages are recorded too. NPC, Battle.net and addon messages are excluded.

Recording stays on across reloads and logins until you pause it. It works separately from filtering.

FIND A CONVERSATION

Use the search and channel controls, or open Conversations for whispers. Capture keeps up to 5,000 lines or 4 MB; the oldest lines are replaced when full.

BOOKMARK AN INCIDENT

Select a captured line and add a bookmark. Give it a title or note. It saves up to 10 already recorded lines before and after the selected line; later messages are not added.

Bookmarks have their own limit of 50 entries or 1 MB. Clearing the rolling capture keeps bookmarks.

COPY OR EXPORT

Choose the view or bookmark you want, then open its export preview. Select the entries, hide names if wanted and check the text before copying it. Nothing is uploaded automatically.]]},
    {id = "languages", title = "Languages", text = [[CHOOSE WHAT YOU READ

Language filtering starts off. Open Settings > Languages, turn it on and check the languages you want to keep. English stays allowed.

Choose actions for low and high confidence. The defaults cover less certain matches and hide stronger matches. You can instead show a label or leave the text visible.

Mostly non-preferred text can use the high-confidence action even when the exact language is unclear. Short or uncertain text may stay visible.

PLAYER NAMES

Filter player names too is a separate switch and starts off. It uses the same language list. A name alone does not hide a message.

Some writing systems are shared between languages. Cyrillic names, for example, do not reliably distinguish Russian from Ukrainian. Latin names cannot reliably identify a language.

Covered names can be read in Messages. Ctrl + left-click reveals them where supported; normal clicks still select the real player.

REVIEW A MATCH

Select the entry in Messages and choose Why filtered? If the reading list needs a change, use Allow language or return to Languages settings.

Public chat, whispers, group chat and guild chat have separate switches. Your own messages, NPC chat, emotes and Battle.net messages are excluded.

Word filters and Shield still work independently. Change alerts in Settings > Notifications.]]},
    {id = "reports", title = "Reports", text = [[SAVE AN EXAMPLE

For an incorrect result, select the message in Messages and choose Report filter problem.

For a missed message, use Report missed filter from the player's chat-name menu, or paste the example into a new report.

Choose the action you expected, add a note if useful and save. Reports do not train the filter or change its rules. To change a phrase now, add a personal rule in Rules.

REPORT A PLAYER

Report player opens WoW's reporting flow. Choose the reason and submit it yourself. Saving a ChatWarden filter report does not report anyone to Blizzard.

READ AND SHARE

Reports > Read reports shows your saved feedback. Share preview lets you choose which reports to copy.

Select the entries, choose whether to hide names and include notes, then review the final text. Name hiding can miss identifying details, so check before sharing.

Make final text edits after changing selections and privacy options; those controls rebuild the preview. Select all, press Ctrl+C and paste where you want to share it.

Shield lists, Capture and bookmarks use the same export preview. Nothing is submitted automatically.]]},
    {id = "spelling", title = "Spelling", text = [[HELP WHILE TYPING

Open Settings > Spelling and turn on spelling highlights. This starts off. Right-click a highlighted word for suggestions, add it to your dictionary or ignore it until reload.

Automatic correction is a separate option, also off by default. It changes clear typos after you finish a word. Ambiguous words stay as suggestions. It never sends a message for you.

WoW terms, Olympus names, known player names and your personal words are recognized. Links, commands and protected inputs are skipped.

CHECK INCOMING TYPOS

Typo-aware incoming filtering is separate from typing help. Balanced matching starts on. You can choose Balanced, Aggressive or Off in Settings > Spelling.

It checks close spellings against your active rules. Correctly spelled words and known names are protected from extra guesses. Exact rules still apply. Why filtered? shows when a spelling guess affected a result.

UPDATES AND HELP

Updates > Patch Notes shows the installed version and short highlights. Full notes on GitHub gives you the release link. Launch Tour introduces each feature; User Guide has these instructions.

Update notes appear once after an installed release changes. Turn off Show future update notes if you prefer to open them yourself with /ocw updates.]]},
}
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
    local preset = ({aggressive = "Strict", balanced = "Balanced", strict = "Mild"})[ns.DB.preset] or 'Balanced'
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
