-- Raw chat is kept briefly in RAM to resolve a clicked line. Only saving a report persists it.
local _, ns = ...
local C = {MAX_ENTRIES = 500, MAX_BYTES = 524288, MAX_TEXT = 8192, MAX_AGE = 600,
    entries = {}, bytes = 0, nextID = 0, hooks = {}}
ns.ChatReports = C
local eventFrame, clickHooked, refHooked, pendingClick, awaitingMenu
local session = tostring(ns.SessionTime()) .. ":" .. tostring(math.random(10000, 99999))
local supported = {}
C.Events = {"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_CHANNEL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE"}
for _, event in ipairs(C.Events) do supported[event] = true end
for _, event in ipairs({"CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER"}) do
    C.Events[#C.Events + 1] = event; supported[event] = true
end
local function Clip(text, limit)
    local n = math.min(#text, limit)
    while n > 0 and text:byte(n + 1) and text:byte(n + 1) >= 128 and text:byte(n + 1) <= 191 do n = n - 1 end
    return text:sub(1, n)
end
local function NameKey(name)
    if not ns.CanRead(name) or name == "" then return nil end
    -- Native menus/links can spell Forever's surname with a hyphen. Share the
    -- Shield identity and never case-map individual bytes of a UTF-8 name.
    return ns.Shield and ns.Shield.Key(name) or ns.Engine.Lower(name:match("^%s*(.-)%s*$"))
end
local function RemoveFirst()
    local old = table.remove(C.entries, 1)
    if old then C.bytes = C.bytes - old.bytes end
end
function C.Prune()
    local oldest = ns.SessionTime() - C.MAX_AGE
    while C.entries[1] and C.entries[1].sessionTime < oldest do RemoveFirst() end
end
function C.Capture(event, message, sender, lineID)
    if not ns.DB or not ns.CanRead(message) or not ns.CanRead(sender)
        or not NameKey(sender) or not ns.CanRead(event) or not supported[event] then return end
    local id = ns.SafeNumber(lineID)
    if id and (id <= 0 or id % 1 ~= 0) then id = nil end
    C.Prune()
    local deliveryKey=not id and ns.ChatFallbackKey(event,message,{sender=sender}) or nil
    if id or deliveryKey then
        for i = #C.entries, 1, -1 do
            local old = C.entries[i]
            if old.event==event and NameKey(old.sender)==NameKey(sender)
                and (id and old.lineID==id or deliveryKey and old.deliveryKey==deliveryKey) then return old end
        end
    end
    C.nextID = C.nextID + 1
    local entry = {original = Clip(message, C.MAX_TEXT), sender = Clip(sender, 128), event = Clip(event, 128),
        lineID = id, deliveryKey=deliveryKey, sessionTime = ns.SessionTime(),
        timestamp = ns.SafeNumber(ns.SafeCall(time)) or ns.SafeNumber(ns.SafeCall(GetServerTime)),
        truncated = #message > C.MAX_TEXT, captureID = session .. ":" .. C.nextID,
        capturePolicy = {preset = ns.DB.preset, context = ns.DB.context == true,typoFiltering=ns.DB.typoFiltering==true,typoFilteringMode=ns.TypoFilter.Mode(),
            enabled = ns.DB.enabled == true, chatEnabled = ns.DB.chat ~= false,
            adapterSupported = supported[event] == true, disabledPacks = {}, packPresets = ns.Reports.PackPresets(ns.DB.packPresets),
            threshold = ns.Confidence.Presets[ns.DB.preset], exceptionCount = #ns.DB.exceptions}}
    for _, pack in ipairs(ns.PackNames) do entry.capturePolicy.disabledPacks[pack] = ns.DB.disabledPacks[pack] == true end
    entry.captureSnapshot = ns.Reports.Snapshot(message, "player", event, entry.capturePolicy,{kind='player',sender=sender})
    -- Event delivery alone does not prove what a native chat filter displayed.
    entry.captureSnapshot.actualAction=nil;entry.captureSnapshot.actionRecorded=false
    entry.bytes = #entry.original + #entry.sender + #entry.event + #ns.Reports.JSON(entry.captureSnapshot) + 512
    if entry.bytes > C.MAX_BYTES then return end
    while #C.entries >= C.MAX_ENTRIES or C.bytes + entry.bytes > C.MAX_BYTES do RemoveFirst() end
    C.entries[#C.entries + 1] = entry; C.bytes = C.bytes + entry.bytes
    return entry
end
function C.RecordOutcome(entry,action,source,diagnostic,preview)
    if type(entry)~='table' or type(entry.captureSnapshot)~='table'
        or not ({Unchanged=true,Warning=true,Redacted=true,Replaced=true,Hidden=true})[action] then return false end
    local snapshot=entry.captureSnapshot;local before=#ns.Reports.JSON(snapshot)
    snapshot.actualAction=action;snapshot.actionRecorded=true;snapshot.analysisTiming='chat-filter'
    snapshot.diagnosticError=diagnostic
    if source and (source.shield or source.spam) then snapshot.combinedPredictedAction='Hidden' end
    snapshot.spamContext=ns.Spam and ns.Spam.Context(entry.event,source,entry.original)
    if source and source.shield then snapshot.shieldReason=source.shieldReason end
    local delta=#ns.Reports.JSON(snapshot)-before
    entry.bytes=entry.bytes+delta;C.bytes=C.bytes+delta
    while C.bytes>C.MAX_BYTES and #C.entries>0 do RemoveFirst() end
    if ns.Mentions then ns.Mentions.Observe(entry,source,preview) end
    return true
end
function C.Find(sender, lineID)
    C.Prune()
    local name, id = NameKey(sender), ns.SafeNumber(lineID)
    if not name or not id or id <= 0 then return end
    for i = #C.entries, 1, -1 do
        local entry = C.entries[i]
        if entry.lineID == id and NameKey(entry.sender) == name then return entry end
    end
end
function C.ParseLink(link)
    if not ns.CanRead(link) then return end
    local sender, rest = link:match("^player:([^:]+):?(.*)$")
    if not sender or not NameKey(sender) then return end
    local field = rest:match("^([^:]*)")
    local id = field:match("^%d+$")
    id = id and tonumber(id)
    if id and id <= 0 then id = nil end
    return sender, id
end
function C.MenuMatches(menu, click)
    if not menu or not click or (menu.frame and menu.frame ~= click.frame) then return false end
    local wanted = NameKey(click.sender)
    for _, name in ipairs(menu.names) do if NameKey(name) == wanted then return true end end
    return false
end
function C.OnClick(frame, link, _, button)
    pendingClick = nil
    if not ns.Readable(button) or button ~= "RightButton" or not ns.Readable(frame) then return end
    local sender, lineID = C.ParseLink(link)
    if not sender then return end
    local click = {sender = sender, lineID = lineID, frame = frame, when = ns.SessionTime()}
    pendingClick = click
    -- Classic dispatch may expose the link only after its menu was generated.
    if awaitingMenu and ns.SessionTime() - awaitingMenu.when < 1 and C.MenuMatches(awaitingMenu, click) then
        awaitingMenu.click = click
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, function() if pendingClick == click then pendingClick = nil end end) end
end
local function Candidates(sender, exact)
    local found = {}
    if exact then found[1] = exact end
    for i = #C.entries, 1, -1 do
        local entry = C.entries[i]
        if entry ~= exact and NameKey(entry.sender) == NameKey(sender) then found[#found + 1] = entry end
        if #found >= 20 then break end
    end
    return found
end
function C.SelectDraft(draft, index)
    local entry = draft.choices[index]
    if not entry then return draft end
    draft.choiceIndex = index
    draft.original, draft.captureID, draft.chatLineID = entry.original, entry.captureID, entry.lineID
    draft.capturedTimestamp, draft.capturedSessionTime = entry.timestamp, entry.sessionTime
    draft.originalTruncated, draft.event, draft.capturePolicy = entry.truncated, entry.event, entry.capturePolicy
    draft.captureSnapshot = entry.captureSnapshot
    draft.selection = entry == draft.exact and "clicked-line" or "recent-selection"
    draft.status = (draft.selection == "clicked-line" and "Clicked message" or "Selected recent message")
        .. " - " .. ns.Review.TimeLabel(entry) .. ". Choose its wanted action and save."
    return draft
end
function C.Open(click)
    C.Prune()
    local exact = click and C.Find(click.sender, click.lineID)
    local draft = {source = "player", reportMethod = "chat-name-menu", selection = "manual",
        choices = Candidates(click and click.sender, exact), choiceIndex = 0, exact = exact,
        status = "The clicked message is unavailable. Paste it here, or choose a recent message."}
    if exact then C.SelectDraft(draft, 1) end
    ns.OpenReport(nil, "Missed match", draft)
end
function C.Cycle(draft)
    if not draft or not draft.choices or #draft.choices == 0 then return end
    return C.SelectDraft(draft, (draft.choiceIndex or 0) % #draft.choices + 1)
end
function C.BuildMenu(_, root, ctx)
    awaitingMenu = nil
    local shieldMenu=ns.PlayerMenus and ns.PlayerMenus.Add(root,ctx)
    if not ns.Active() or not ns.Readable(ctx) or type(ctx) ~= "table" or not ns.CanRead(ctx.name) then return end
    if not ns.Readable(ctx.chatFrame) then return end
    local frame = ctx.chatFrame
    if not frame and (not ns.Readable(ctx.unit) or (ctx.unit and ctx.unit ~= "")) then return end
    local menu = {frame = frame, names = {ctx.name}, when = ns.SessionTime()}
    for _, part in ipairs({"surname", "server"}) do
        local suffix = ctx[part]
        if ns.CanRead(suffix) and suffix ~= "" then
            menu.names[#menu.names + 1] = ctx.name .. " " .. suffix
            menu.names[#menu.names + 1] = ctx.name .. "-" .. suffix
        end
    end
    if ns.CanRead(ctx.surname) and ctx.surname ~= "" and ns.CanRead(ctx.server) and ctx.server ~= "" then
        menu.names[#menu.names + 1] = ctx.name .. " " .. ctx.surname .. "-" .. ctx.server
    end
    local fresh = pendingClick and ns.SessionTime() - pendingClick.when < 1
    if fresh and C.MenuMatches(menu, pendingClick) then menu.click = pendingClick end
    -- Only chat-name menus. Portraits, rosters, Battle.net and unrelated menus are untouched.
    if not frame and not menu.click then return end
    if not root or not root.CreateButton then return end
    local click=menu.click
    local recording=ns.ChatCapture and ns.ChatCapture.db.enabled
    if not ns.DB.chat and not recording then return end
    awaitingMenu = menu
    root=shieldMenu or ns.PlayerMenus.Submenu(root)
    if not root then return end
    if ns.DB.chat then
    local item = root:CreateButton("Report missed filter", function() C.Open(menu.click) end)
    if item and item.SetTooltip then item:SetTooltip(function(tooltip)
        tooltip:AddLine("Report missed filter", 1, 0.82, 0.39)
        tooltip:AddLine("Review the message, choose its wanted action and save an example for rule tuning.", 1, 1, 1, true)
    end) end
    end
    -- Some Classic menus receive their clicked hyperlink after construction.
    -- Resolve the clicked line at activation, while hiding this action when paused.
    if recording then root:CreateButton('Bookmark this message',function()
        local click=menu.click
        local entry=click and ns.ChatCapture.Find(click.sender,click.lineID)
        if not entry then
            ns.Print('This clicked line is not in the active capture. Start capture for future messages, or choose a saved line in Chat capture.')
            ns.OpenCapturePlayer(click and click.sender or ctx.name);return
        end
        local ok,message=ns.ChatCapture.Bookmark(entry.id,'','');ns.Print(message)
        if ok then ns.OpenCaptureBookmark(ns.ChatCapture.nextBookmark) end
    end) end
end
function C.Install()
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        for _, event in ipairs(C.Events) do eventFrame:RegisterEvent(event) end
        eventFrame:SetScript("OnEvent", C.OnEvent)
    end
    if not clickHooked and EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkClick", function(_, frame, link, text, button)
            C.OnClick(frame, link, text, button)
        end, C)
        clickHooked = true
    end
    if not refHooked and type(SetItemRef) == "function" and type(hooksecurefunc) == "function" then
        hooksecurefunc("SetItemRef", function(link, text, button, frame) C.OnClick(frame, link, text, button) end)
        refHooked = true
    end
    if Menu and type(Menu.ModifyMenu) == "function" then
        for _, tag in ipairs({"MENU_UNIT_FRIEND", "MENU_UNIT_PLAYER", "MENU_UNIT_SELF", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER",
            "MENU_UNIT_RAID", "MENU_UNIT_ENEMY_PLAYER", "MENU_UNIT_GUILD", "MENU_UNIT_GUILD_OFFLINE", "MENU_UNIT_IGNORE"}) do
            if not C.hooks[tag] then Menu.ModifyMenu(tag, C.BuildMenu); C.hooks[tag] = true end
        end
    end
end
function C.OnEvent(_, event, message, sender, ...)
    -- Line ID is event argument 11: nine arguments after text and sender.
    if ns.ChatCapture then
        local channel=ns.SafeString(select(7,...),128) or ns.SafeString(select(2,...),128)
        ns.ChatCapture.Record(event,message,sender,select(9,...),channel~='' and channel or nil)
    end
    local entry=C.Capture(event, message, sender, select(9, ...))
    if entry then entry.channel=ns.SafeString(select(7,...),128) or ns.SafeString(select(2,...),128) end
    if entry and ns.Mentions and C_Timer and C_Timer.After then C_Timer.After(0,function() ns.Mentions.Unrendered(entry) end) end
end
