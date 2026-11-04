-- Release notes for installed updates; no network request or version polling.
local _,ns=...
local T=ns.Theme
local window,queued,loginReady
local release=ns.VERSION
local previous={version='1.0.2',subtitle='Archived release notes',cards={
    {'ChatWarden inside Olympus','Use the compact panel for quick controls and recent activity. Right-click its tab to open the full UI.','overview'},
    {'Olympus membership and profile','Olympus 1.2.4 confirms membership after /oly privacy approval. Guild rank and connection status appear in the full UI.','olympus'},
    {'Mentions is now Alerts','Personal mentions and Wanted encounters share one page, with separate views, settings and unread counts.','mentions'},
    {'Wanted encounter alerts','Listed enemy targets and mouseovers can create alerts. Choose optional sound, popups and a per-player cooldown.','reports'},
    {'Quiet Wanted icons in chat','Full listed names get an icon with bounty details on hover. Chat icons never trigger Wanted alerts.','reports'},
    {'Activity and update history','Click recent entries to mark them read. Zeus matches the trim, and Previous/Next opens older update notes.','updates'},
}}
local v103={version='1.0.3',subtitle='Your history, preserved',cards={
    {'Optional Chronicle recording','Choose whether to save your travels, progress, gear, important encounters and permitted Olympus records.','recording'},
    {'Shared adventures','Browse recorded dungeon, raid and group history, with supported boss attempts and original sources.','overview'},
    {'Player histories','Review local encounters, native credit evidence, roster relationships and your personal notes.','mentions'},
    {'Time, progress and PvP visits','Inspect measured time, levels, quests, deaths, exploration and battleground visit history.','shield'},
    {'A quieter history browser','Events highlights meaningful changes. Custom filters and All recorded data keep the details available.','copy'},
    {'Keep it for the long run','History stays until you clear it. Complete-file backups protect it when you move or replace your PC.','export'},
}}
-- Keep published notes here when adding a new release. Older cards retain the
-- wording shipped in those versions; browsing them does not change settings.
local v110={version='1.1.0',subtitle='Your whole adventure, one Fireside suite',cards={
    {'Welcome to Fireside','Six connected modules bring your Chronicle, player dossiers, chat, signals and contact protection into one Olympus workspace.','overview'},
    {'ChronicleWarden comes first','Browse recorded milestones, shared activities, dungeon visits and optional duels. Dates, companions and original evidence stay connected.','chronicle'},
    {'Meet IntelWarden','Revisit remembered players, private notes and historical gear or talents. A live model appears only for the exact available player.','intel'},
    {'Duels with their own history','Separate opt-in keeps individual duel encounters and supported before/after observations. Unchanged gear and talents reuse saved configurations.','chronicle'},
    {'Artwork with clearer controls','Larger crests and sidebar buttons showcase the suite. ON/OFF badges stay readable, and window-size changes wait for Apply.','settings'},
    {'Your history stays yours','Recording remains optional, saved history does not expire, and complete-file backups keep working. No sharing is enabled automatically.','export'},
}}

local v111={version='1.1.1',subtitle='CommandWarden, RelayWarden and safer history',cards={
    {'CommandWarden and feature choices','Choose Chat Only or individual features in one control center. Disabling a module keeps saved history, notes and recording choices.','modules'},
    {'Meet RelayWarden','Submit once. My Reports tracks validated delivery and retries while online. Drafts stay local; Technical Details starts off.','relay'},
    {'A clearer Olympus workspace','Larger crests, clear ON/OFF states and adaptive Olympus controls improve readability. Chat Capture still defaults off.','overview'},
    {'Your character becomes ready first','Your current character validates first; other archives load on request. Chat reports 25/50/75/100% progress with Fireside closed.','chronicle'},
    {'Protect eligible startup events','Accepted startup events survive normal logout/reload. Overflow is counted; movement, inspections and full duels remain partly uncaptured.','recording'},
    {'Dossiers, notes and complete backups','Player menus open exact saved dossiers, notes and watchlist entries. One Windows backup keeps history, reports and pending recovery.','intel'},
}}
local v112={version='1.1.2',subtitle='Recording startup hotfix',cards={
    {'Recording resumes after login','Fixes a login timing issue that could leave recording waiting for world entry after history finished loading.','chronicle'},
    {'New players reach IntelWarden','With recording active, new inspections and encounters can save again. Recent players, profiles and gear use the same retained evidence.','intel'},
    {'Your history and choices stay kept','Existing history, notes, watchlists and consent are preserved. Disabled modules and paused recording keep their current settings.','recording'},
    {'A shorter recording check','Use /warden chronicle check for three lines showing recording status, world readiness and collector counters.','settings'},
}}
local v113={version='1.1.3',subtitle='Inspection, shortcuts and reliable views',cards={
    {'Historical talent trees','Browse recorded native positions, connections and ranks. Zoom scales icons and labels together; Reset always restores 100%. Copy exports in a separate dialog.','intel'},
    {'Equipment tooltips and links','Recorded item IDs get native item-type tooltips and clearly labeled links. Exact saved modifiers take priority; short owned-cache retries can complete late inspection links.','intel'},
    {'Reports appear after login','My Reports and Developer Inbox now populate saved reports before any new submission. Delivery behavior and existing reports are unchanged.','relay'},
    {'Three native shortcuts','Optional shop, minimap and Inspect side-tab shortcuts use native framing and Fireside artwork. Each starts off in CommandWarden Settings.','settings'},
    {'Safer tooltips and cleaner views','Protected tooltip text is checked before comparison. Duplicate CommandWarden header buttons and overlapping talent instructions are removed.','overview'},
    {'Inspect from Olympus','Inspect target opens normal Blizzard inspection and the exact recorded Intel dossier. Consent, history and module choices stay intact.','olympus'},
}}
local dev8={version='1.1.4-athena-living-dev8',subtitle='Athena’s Journal — The Journey DEV8',cards={
    {'A continuous manuscript','The Journey gathers meaningful quest and activity developments into connected scenes. Routine roster observations and skill polls stay in the evidence archive.','chronicle'},
    {'The world and your own story','A historical prologue leads into your character’s life. Bundled quest references add supported motives, objectives and context, with future outcomes kept behind their reveal gates.','chronicle'},
    {'Books drawn from one life','Collections and Lore of Azeroth remain other paths through the same retained history. Reading positions, chapter navigation and Sources & Limits stay close at hand.','chronicle'},
    {'Private memories, by choice','Conversation preservation starts off. Selected, permitted memories can accompany an adventure; private speech never becomes proof of its outcome.','settings'},
    {'Less repeated work in crowds','Large guild rosters retain compact change signatures. Unchanged meter results avoid repeat hashing, and empty meter timers stop creating a stream of records.','overview'},
    {'History and membership','Existing history and consent stay kept. Olympus guild verification is active. This development candidate still needs native performance and reading checks.','recording'},
}}
local dev10={version='1.1.4-athena-living-dev10',subtitle='Athena’s Journal — The Bronze Chronicle DEV10',cards={
    {'A bronze magical book','Fitted pages, a wide two-page spread, animated page turns and a word-by-word blue ink reveal. Choose instant page effects in Reading options.','chronicle'},
    {'Keep your completed reading','Suitable saved reading copies reopen after normal logout or reload. Athena keeps the old book visible while its finished replacement is prepared.','recording'},
    {'Another telling of your journey','Regenerate varies wording and eligible lore without changing your recorded deeds. Parallel quest work and returns can share connected passages.','chronicle'},
    {'The Lore Codex','147 subjects and 238 sourced facts enrich the organized lore library and relevant scenes. Warcraft III through Classic/Forever; missing fields stay unknown.','chronicle'},
    {'Open early, keep reading','Opening during archive validation now waits and continues. Library controls keep their layout, and public historical lore can open while personal history loads.','overview'},
    {'Your sources and choices stay kept','The 5,020-quest corpus and accepted history remain intact. Guild verification is active. Native animation, layout and crowd performance checks remain pending.','settings'},
}}
ns.InstalledUpdate={version=release,subtitle='Athena’s Journal — Metis 1.0',cards={
    {'Meet Metis','One narrative director now brings significance, scene planning, lore, continuity, composition and editorial checks into the same engine.','chronicle'},
    {'Plan before composing','Parallel errands can share one planned scene. Interrupted updates revise the same subject when no other scene intervenes.','chronicle'},
    {'Manuscript memory','Rebuildable source anchors track introduced developments, unfinished quests, recurring people and earlier close calls. A return can receive a spaced, source-backed callback.','chronicle'},
    {'A final editorial gate','Every narrative path uses the same reference checks. A failed replacement keeps your completed reading copy available.','recording'},
    {'Consistent book typography','Missing scaled font families are included. Body paragraphs and page measurements use the same size rules, including quotations.','settings'},
    {'Your world and history stay kept','Bronze book effects, saved copies and Regenerate remain. The quest and lore corpora are unchanged; normal guild verification stays active. Native checks remain pending.','overview'},
}}
ns.UpdateHistory={ns.InstalledUpdate,dev10,dev8,v113,v112,v111,v110,v103,previous,
    {version='1.0.1',subtitle='Archived release notes',cards={
        {'Smarter filtering','Better context handling means fewer false matches in questions, criticism and ordinary discussion.','messages'},
        {'First-name Mentions','Your first name or full name can trigger Mentions. No @ needed, and Capture can stay off.','mentions'},
        {'Clearer pack names','Optional packs have clearer names. Import updated packs separately to see the new names.','packs'},
        {'WoW-friendly spelling','More game terms and Olympus names are recognized. Ambiguous corrections stay suggestions.','settings'},
        {'Your settings stay yours','Existing choices and saved activity are kept. The launch tour now has its own tab.','reports'},
    }},
    {version='1.0.0',subtitle='Archived release notes',cards={
        {'Incoming spelling and evasion matching','On by default in Balanced matching mode. Close misspellings can match enabled rules and use their normal actions, including Hide. Originals stay intact.','settings'},
        {'Compare the results','Settings > Spelling has Aggressive incoming typo filtering. Turn it off to compare normal matching. Your own messages and name labels are excluded.','settings'},
        {'Reports and sharing in one window','Read reports and Share preview now share one window. Choose entries and privacy before copying. Language-only notifications start off.','reports'},
        {'Spelling assistance','Optional English spelling highlights, right-click suggestions and automatic correction. Enable the options you want in Settings > Spelling.','settings'},
        {'Windows and settings','Keep Review, Rules, Reports and help open together. Window layers move together. The Language guide button now fits inside Settings.','overview'},
    }},
}
local function Label(parent,text,x,y,width,font)
    local label=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall')
    label:SetPoint('TOPLEFT',x,y);label:SetWidth(width);label:SetJustifyH('LEFT');label:SetWordWrap(true);label:SetText(text)
    return label
end
local function Button(text,x,width,fn)
    local button=CreateFrame('Button',nil,window,'UIPanelButtonTemplate')
    button:SetPoint('TOPLEFT',x,-622);button:SetSize(width,26);button:SetText(text);button:SetScript('OnClick',fn)
    T.ActionHelp(button,text);return button
end
function ns.OpenUpdates()
    if not ns.DB then return end
    if InCombatLockdown and InCombatLockdown() then ns.Print('Open update notes after combat with /ocw updates.');return end
    if not window then
        window=T.Window('OlympusChatWardenUpdates',UIParent,680,716);ns.UpdateWindow=window
        T.Title(window,ns.NAME);T.Crest(window)
        T.Gold(Label(window,"What's new",78,-30,570,'GameFontNormalLarge'))
        T.Muted(Label(window,'Update '..release..'  |  Your existing settings and saved data are kept.',78,-52,570))
        local cards=ns.InstalledUpdate.cards
        for i,card in ipairs(cards) do
            local panel=T.Panel(window,18,-84-(i-1)*78,644,70,true)
            T.Heading(T.Body(Label(panel,card[1],14,-10,616,'GameFontNormal')))
            T.Ink(T.Body(Label(panel,card[2],14,-30,616)))
        end
        local show=CreateFrame('CheckButton',nil,window,'UICheckButtonTemplate');show:SetPoint('TOPLEFT',14,-568);show:SetSize(26,26)
        Label(show,'Show this screen after future updates',30,-6,580)
        show:SetScript('OnClick',function(self) ns.DB.showUpdates=ns.Checked(self:GetChecked()) end)
        T.Tooltip(show,'Update notes','Show notes once after an installed release changes. Reopen them anytime with /ocw updates. No online update check is performed.')
        window.ShowUpdates=show
        Button('Get packs link',18,195,function() ns.OpenPacks('download') end)
        Button('Rule packs',225,195,function() ns.OpenPacks('installed') end)
        Button('Close',542,120,function() window:Hide() end)
        T.Muted(Label(window,'Reopen these notes with /ocw updates or Updates in the sidebar.',20,-684,640))
    end
    window.ShowUpdates:SetChecked(ns.DB.showUpdates~=false)
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    window:SetScale(math.min(1,(w-30)/680,(h-30)/716))
    T.ShowWindow(window)
    if window:IsShown() then ns.DB.updateSeen=release end
end
function ns.CheckUpdateScreen(event)
    if ns.Modules and ns.Modules.needsWelcome then return end
    if event=='PLAYER_LOGIN' then loginReady=true end
    if not loginReady and IsLoggedIn then loginReady=IsLoggedIn()==true end
    if loginReady and ns.DB and ns.Active() and ns.DB.welcomeSeen~=1 then
        ns.DB.updateSeen=release;return -- the introduction covers this release for new users
    end
    if queued or not loginReady or not ns.DB or not ns.Active() or ns.DB.welcomeSeen~=1
        or ns.DB.showUpdates==false or ns.DB.updateSeen==release or not UIParent:IsVisible()
        or InCombatLockdown and InCombatLockdown() then return end
    queued=true
    local function Show()
        queued=false
        if ns.DB and ns.Active() and ns.DB.welcomeSeen==1 and ns.DB.showUpdates~=false
            and ns.DB.updateSeen~=release and UIParent:IsVisible()
            and not (InCombatLockdown and InCombatLockdown()) then ns.OpenUpdates() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0,Show)
    else
        local frame=CreateFrame('Frame');frame:SetScript('OnUpdate',function(self) self:SetScript('OnUpdate',nil);Show() end)
    end
end
