-- Display-only adapters. Native label text and roster identities stay intact.
local _, ns = ...
local N = {hooks = {}, queued = false, plateCounts = {seen = 0, filtered = 0, restricted = 0}}
ns.NameDisplays = N
local function Enabled(scope)
    return ns.Active(scope) or scope=='playerNames' and ns.Language and ns.Language.NamesActive()
end
local unitRoots = {"TargetFrame", "FocusFrame", "TargetFrameToT", "FocusFrameToT", "PlayerFrame", "PetFrame", "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4"}
-- The native compact party/raid layouts replace the older party buttons.
-- Check only these bounded, known roots; never walk arbitrary addon trees.
for i=1,5 do unitRoots[#unitRoots+1]="CompactPartyFrameMember"..i end
for i=1,40 do unitRoots[#unitRoots+1]="CompactRaidFrame"..i end
for group=1,8 do for member=1,5 do unitRoots[#unitRoots+1]="CompactRaidGroup"..group.."Member"..member end end
local targetRevision = 0
local plateGeneration = {}
local plateBindings,bindingsCount={},0
N.bindingStats={bound=0,reused=0}
function N.BindingCount() return bindingsCount end
local function TargetScope(unit)
    if type(UnitIsPlayer) ~= "function" then return end
    local ok, player = pcall(UnitIsPlayer, unit)
    if not ok or not ns.Readable(player) then return end
    if type(player) ~= "boolean" and player ~= 0 and player ~= 1 and player ~= nil then return end
    return ns.Checked(player) and "playerNames" or "npcNames"
end
local function Public(object)
    local kind = type(object)
    return (kind == "table" or kind == "userdata") and ns.Readable(object)
        and not (object.IsForbidden and object:IsForbidden())
end
local function Visible(object)
    return Public(object) and (not object.IsVisible or object:IsVisible())
end
local fallbackUnits={PlayerFrame='player',PetFrame='pet',TargetFrame='target',FocusFrame='focus',TargetFrameToT='targettarget',FocusFrameToT='focustarget'}
for i=1,4 do fallbackUnits['PartyMemberFrame'..i]='party'..i end
local function UnitToken(root,key)
    if not ns.Readable(root.displayedUnit) or not ns.Readable(root.unit) then return end
    local token=ns.SafeString(root.displayedUnit,64) or ns.SafeString(root.unit,64)
    if not token and type(root.GetAttribute)=='function' then
        local ok,value=pcall(root.GetAttribute,root,'unit')
        if not ok or not ns.Readable(value) then return end
        token=ns.SafeString(value,64)
    end
    return token or fallbackUnits[key]
end
local function NameLabels(root,key)
    local labels,seen={},{}
    local function Add(region)
        if Public(region) and ns.SafeCall(region.GetObjectType,region)=='FontString' and not seen[region] then
            seen[region]=true;labels[#labels+1]=region
        end
    end
    local function Path(...)
        local object=root
        for _,part in ipairs({...}) do if not Public(object) then return end;object=object[part] end
        return object
    end
    Add(root.name);Add(root.Name);Add(root.NameText)
    Add(Path('textureFrame','Name'));Add(Path('NameFrame','Name'));Add(Path('NameFrame','NameText'))
    Add(Path('TargetFrameContent','TargetFrameContentMain','Name'))
    Add(Path('PlayerFrameContent','PlayerFrameContentMain','Name'))
    Add(Path('PlayerFrameContent','PlayerFrameContentMain','PlayerName'))
    Add(_G[key..'TextureFrameName']);Add(_G[key..'Name']);Add(_G[key:gsub('Frame$','')..'Name'])
    return labels
end
function ns.NamePlateUnit(plate, frame)
    if not Public(plate) or not Public(frame) then return end
    local unit = type(plate.GetUnit) == "function" and ns.SafeCall(plate.GetUnit, plate)
    return ns.SafeString(unit, 64) or ns.SafeString(frame.unit, 64)
end
local function Track(region, scope, kind, panel, available)
    if not Enabled(scope) or not Visible(region) then return end
    ns.TrackRegion(region, scope, function() return {kind = kind, panel = panel} end, nil,
        {displayOnly = true, available = available,languageName=scope=='playerNames'})
end
local function Rows(list, callback)
    if not Visible(list) then return end
    if type(list.ForEachFrame) == "function" then
        local count = 0
        ns.SafeCall(list.ForEachFrame, list, function(row)
            count = count + 1
            if count <= 100 and Visible(row) then callback(row) end
        end)
        return
    end
    local rows = list.buttons
    if type(rows) ~= "table" and type(list.GetFrames) == "function" then rows = ns.SafeCall(list.GetFrames, list) end
    if type(rows) ~= "table" then return end
    local count = 0
    for _, row in pairs(rows) do
        count = count + 1; if count > 100 then break end
        if Visible(row) then callback(row) end
    end
end
local function NamedRows(prefix, suffix, scope, kind, panel, count)
    for i = 1, count do Track(_G[prefix .. i .. suffix], scope, kind, panel) end
end
local function Hook(object, method, callback)
    if not Public(object) or type(object[method]) ~= "function" then return end
    N.hooks[object] = N.hooks[object] or {}
    if N.hooks[object][method] then return end
    if pcall(hooksecurefunc, object, method, callback) then N.hooks[object][method] = true end
end
local function Install()
    -- Names come from the native Classic friends/guild templates. Scroll-row
    -- redraws are hooked because rows are reused without another roster event.
    for _, method in ipairs({"FriendsFrame_UpdateFriendButton", "FriendsFrame_UpdateFriends",
        "IgnoreList_Update", "GuildStatus_Update", "GuildRoster_Update", "WhoList_Update",
        "MerchantFrame_Update", "MerchantFrame_UpdateMerchantInfo", "MerchantFrame_UpdateBuybackInfo"}) do
        Hook(_G, method, function() ns.QueueNameScan() end)
    end
    for _, method in ipairs({"QuestInfo_ShowObjectives", "QuestInfo_ShowObjectivesText", "QuestInfo_ShowRewards", "QuestInfo_Display", "QuestLog_UpdateQuestDetails", "QuestMapFrame_ShowQuestDetails", "QuestMapFrame_UpdateAll", "QuestLogQuests_Update"}) do
        Hook(_G, method, function() ns.QueueScan(false) end)
    end
    for _, method in ipairs({"UnitFrame_Update", "UnitFrame_UpdateName", "CompactUnitFrame_UpdateName", "CompactUnitFrame_SetUnit"}) do
        Hook(_G, method, function(root)
            -- Native unit updates also serve party/raid frames. Queue only the
            -- explicit target roots we filter, never unrelated unit UI.
            if root then for _, key in ipairs(unitRoots) do if root == _G[key] then ns.QueueNameScan(); break end end end
        end)
    end
    for _, name in ipairs({"FriendsFrame", "GuildFrame", "CommunitiesFrame", "MerchantFrame", "GossipFrame", "QuestFrame", "QuestMapFrame", "QuestLogFrame", "WorldMapFrame", "CompactPartyFrame", "CompactRaidFrameContainer"}) do
        local root = _G[name]
        if Public(root) and root.HookScript and not N.hooks[root] then
            N.hooks[root] = {visibility = true}
            root:HookScript("OnShow", function() ns.QueueNameScan() end)
        end
    end
    local gossipScroll = GossipFrame and GossipFrame.GreetingPanel and GossipFrame.GreetingPanel.ScrollBox
    local memberList = CommunitiesFrame and CommunitiesFrame.MemberList
    for _, scroll in pairs({gossip = gossipScroll, guild = memberList and memberList.ScrollBox}) do
        Hook(scroll, "FullUpdate", function() ns.QueueNameScan() end)
        Hook(scroll, "SetDataProvider", function() ns.QueueNameScan() end)
    end
end
function N.Status()
    if not ns.Active("nameplates") then return "Nameplates off. Your WoW visibility settings stay unchanged." end
    if not ns.Active("playerNames") and not ns.Active("npcNames") then return "Name filtering off. Enable Player names or NPC names." end
    local c = N.plateCounts
    if c.seen == 0 then return "No visible nameplates detected. Enable nameplates in WoW to filter their labels." end
    return c.seen .. " visible nameplates; " .. c.filtered .. " filtered; " .. c.restricted .. " unavailable/restricted."
end
function ns.ScanExtraText()
    -- Item identities, prices, quantities and objective counts remain native.
    -- Reward names use passive copies, never the text a native handler reads.
    local detailSource = ns.UIReviewSource("quest", "Quest objective")
    local logSource = ns.UIReviewSource("quest", "Quest log objective", true)
    local function Objective(region, isLog, description)
        if not Visible(region) then return end
        local source = isLog and logSource or detailSource
        local quest = source.questID or source.questTitle
            or (isLog and ns.SafeNumber(ns.SafeCall(GetQuestLogSelection))) or ""
        local panel = description and "Quest log description" or isLog and "Quest log objective" or "Quest objective"
        ns.TrackRegion(region, "dialogue", function()
            return ns.UIReviewSource("quest", panel, isLog)
        end, nil, {keepLabel = true, preserveAlpha = true,
            identity = (isLog and "log:" or "detail:") .. tostring(quest) .. ":" .. ns.Interaction})
    end
    Objective(QuestInfoObjectivesText, QuestInfoFrame and QuestInfoFrame.questLog)
    Objective(QuestLogObjectivesText, true)
    for i = 1, 40 do
        Objective(_G["QuestInfoObjective" .. i], QuestInfoFrame and QuestInfoFrame.questLog)
        Objective(_G["QuestLogObjective" .. i], true)
    end
    local objectiveFrame = QuestInfoObjectivesFrame
    local pooled = Visible(objectiveFrame) and objectiveFrame.Objectives
    if type(pooled) == "table" then
        for i = 1, math.min(#pooled, 40) do Objective(pooled[i], QuestInfoFrame and QuestInfoFrame.questLog) end
    end
    Objective(QuestLogQuestDescription, true, true)
    -- Classic's map log reuses explicit native frame pools rather than the
    -- QuestLogObjectiveN globals. Read only their narrative Text field.
    local mapScroll = QuestScrollFrame or QuestMapFrame and QuestMapFrame.QuestsFrame
    if Public(mapScroll) and Public(mapScroll.ScrollFrame) then mapScroll = mapScroll.ScrollFrame end
    local function MapPool(pool, title)
        if type(pool) ~= "table" or type(pool.EnumerateActive) ~= "function" then return end
        pcall(function()
            local count = 0
            for row in pool:EnumerateActive() do
                count = count + 1; if count > 100 then break end
                if Visible(row) and Visible(row.Text) then
                    local questID = ns.SafeNumber(row.questID)
                    ns.TrackRegion(row.Text, "dialogue", function()
                        return {kind = "quest", panel = title and "Map quest title" or "Map quest objective", questID = questID}
                    end, nil, {displayOnly = true, keepLabel = true,
                        identity = "map:" .. tostring(questID) .. ":" .. tostring(ns.Interaction),
                        available = function() return Visible(row) and ns.SafeNumber(row.questID) == questID end})
                end
            end
        end)
    end
    if Public(mapScroll) then
        MapPool(mapScroll.titleFramePool, true); MapPool(mapScroll.objectiveFramePool, false)
    end
    local function RewardNames(frame)
        if not Visible(frame) or type(frame.RewardButtons) ~= "table" then return end
        for i = 1, math.min(#frame.RewardButtons, 40) do
            local row = frame.RewardButtons[i]
            if Visible(row) and Visible(row.Name) then
                local itemID, questID = ns.SafeNumber(row.itemID), detailSource.questID or ""
                ns.TrackRegion(row.Name, "dialogue", function()
                    return ns.UIReviewSource("quest", "Quest reward item", QuestInfoFrame and QuestInfoFrame.questLog)
                end, nil, {displayOnly = true, keepLabel = true,
                    identity = "reward:" .. tostring(questID) .. ":" .. tostring(itemID) .. ":" .. ns.Interaction,
                    available = function() return Visible(frame) and Visible(row) end})
            end
        end
    end
    RewardNames(QuestInfoRewardsFrame); RewardNames(MapQuestInfoRewardsFrame)
    for i = 1, 12 do
        local row = _G["MerchantItem" .. i]
        Track(Public(row) and row.Name or _G["MerchantItem" .. i .. "Name"], "vendor", "vendor", "Vendor item label")
    end
    -- Gossip options are real choice buttons. The passive display does not
    -- capture their clicks or replace text used by the selection handler.
    for i = 1, 32 do
        local button = _G["GossipTitleButton" .. i]
        if Visible(button) and button.GetFontString then Track(button:GetFontString(), "dialogue", "gossip", "Gossip choice") end
    end
    local scroll = GossipFrame and GossipFrame.GreetingPanel and GossipFrame.GreetingPanel.ScrollBox
    Rows(scroll, function(row)
        if row.GreetingText then ns.TrackRegion(row.GreetingText, "dialogue", function() return ns.UIReviewSource("gossip", "Gossip greeting") end) end
        Track(row.Title, "dialogue", "gossip", "Gossip/quest choice")
        if row.GetFontString then Track(row:GetFontString(), "dialogue", "gossip", "Gossip/quest choice") end
    end)
    Install(); N.Scan()
end
function N.Scan()
    if not ns.DB then return end
    if Enabled("playerNames") then
        NamedRows("GuildFrameButton", "Name", "playerNames", "playerName", "Guild roster", 40)
        NamedRows("GuildFrameGuildStatusButton", "Name", "playerNames", "playerName", "Guild status", 40)
        NamedRows("WhoFrameButton", "Name", "playerNames", "playerName", "Who list", 40)
        Track(GuildMemberDetailName, "playerNames", "playerName", "Guild member details")
        local communities = CommunitiesFrame
        local members = Visible(communities) and communities.MemberList
        Rows(Public(members) and members.ScrollBox, function(row)
            local function MemberRow() return Public(row) and type(row.memberInfo) == "table" and ns.CanRead(row.memberInfo.name) end
            if MemberRow() then
                Track(Public(row.NameFrame) and row.NameFrame.Name, "playerNames", "playerName", "Guild roster", MemberRow)
            end
        end)
        Track(Visible(communities) and Public(communities.GuildMemberDetailFrame) and communities.GuildMemberDetailFrame.Name,
            "playerNames", "playerName", "Guild member details")
        for _, name in ipairs({"FriendsFrameFriendsScrollFrame", "FriendsFrameIgnoreScrollFrame"}) do
            Rows(_G[name], function(row) Track(row.name, "playerNames", "playerName", "Friends / ignore list") end)
        end
    end
    if ns.Active("npcNames") then
        for _, name in ipairs({"MerchantNameText", "GossipFrameTitleText", "GossipFrameNpcNameText", "QuestFrameNpcNameText"}) do
            Track(_G[name], "npcNames", "npcName", "NPC window heading")
        end
        for _, root in pairs({gossip = GossipFrame, quest = QuestFrame, merchant = MerchantFrame}) do
            if Visible(root) then
                Track(Public(root.NameFrame) and root.NameFrame.Name, "npcNames", "npcName", "NPC window heading")
                Track(Public(root.TitleContainer) and root.TitleContainer.TitleText, "npcNames", "npcName", "NPC window heading")
                Track(root.TitleText, "npcNames", "npcName", "NPC window heading")
            end
        end
        local talking = TalkingHeadFrame and TalkingHeadFrame.NameFrame
        Track(Public(talking) and talking.Name, "npcNames", "npcName", "Talking-head name")
    end
    local languageNames=ns.Language and ns.Language.NamesActive()
    if (ns.Active("targetNames") or languageNames) and (Enabled("playerNames") or ns.Active("npcNames")) then
        local seen={}
        for _, key in ipairs(unitRoots) do
            local root = _G[key]
            if Visible(root) and not seen[root] then
                seen[root]=true
                local unit = UnitToken(root,key)
                local exists = unit and type(UnitExists) == "function" and ns.Checked(ns.SafeCall(UnitExists, unit))
                local scope = exists and TargetScope(unit)
                if exists and scope and Enabled(scope) and (ns.Active('targetNames') or scope=='playerNames' and languageNames) then
                  for _,region in ipairs(NameLabels(root,key)) do if Visible(region) then
                    local revision = targetRevision
                    local guid = type(UnitGUID) == "function" and ns.SafeString(ns.SafeCall(UnitGUID, unit), 128)
                    local function Available()
                        if revision ~= targetRevision or not (ns.Active('targetNames') or scope=='playerNames' and ns.Language.NamesActive())
                            or not Enabled(scope) or not Visible(root) then return false end
                        local currentUnit = UnitToken(root,key)
                        if currentUnit ~= unit or not ns.Checked(ns.SafeCall(UnitExists, unit)) then return false end
                        if guid and ns.SafeString(ns.SafeCall(UnitGUID, unit), 128) ~= guid then return false end
                        return TargetScope(unit) == scope
                    end
                    ns.TrackRegion(region, "targetNames", function() return {kind = "targetName", panel = key} end, nil,
                        {keepLabel = true, passive = true, targetName = true, controlHost = root, available = Available,
                         languageName=scope=='playerNames',identity = (guid or unit) .. ":" .. revision})
                  end end
                end
            end
        end
    end
    N.plateCounts = {seen = 0, filtered = 0, restricted = 0}
    if (ns.Active("nameplates") or languageNames) and (Enabled("playerNames") or ns.Active("npcNames")) and C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = ns.SafeCall(C_NamePlate.GetNamePlates)
        if type(plates) == "table" then
            local count = 0
            for _, plate in pairs(plates) do
                count = count + 1; if count > 100 then break end
                N.plateCounts.seen = N.plateCounts.seen + 1
                local unitFrame = Visible(plate) and plate.UnitFrame
                local unit = ns.NamePlateUnit(plate, unitFrame)
                if unit and type(UnitIsPlayer) == "function" then
                    local scope = TargetScope(unit)
                    if scope then
                        local player = scope == "playerNames"
                        if Enabled(scope) and (ns.Active('nameplates') or player and languageNames) and Visible(unitFrame.name) then
                            local generation = plateGeneration[unit] or 0
                            local guid = ns.SafeString(ns.SafeCall(UnitGUID, unit), 128)
                            local binding=plateBindings[unit]
                            local reuse=guid and binding and binding.plate==plate and binding.frame==unitFrame and binding.region==unitFrame.name
                                and binding.guid==guid and binding.generation==generation and binding.scope==scope
                                and binding.revision==ns.PolicyRevision and ns.RegionBindingCurrent(unitFrame.name)
                            -- Nameplate targeting uses its unit token, never the
                            -- displayed FontString. Render in place so native
                            -- names-only alpha/scale rules remain in force.
                            if not reuse then
                            ns.TrackRegion(unitFrame.name, scope, function()
                                return {kind = player and "playerName" or "npcName", panel = "Nameplate"}
                            end, nil, {keepLabel = true, passive = true, nativeNameplate = true, controlHost = plate, unit = unit,
                             languageName=player,identity = (guid or unit) .. ":" .. generation, available = function()
                                local token = ns.NamePlateUnit(plate, unitFrame)
                                if token ~= unit or generation ~= (plateGeneration[unit] or 0) or not Visible(plate) then return false end
                                if guid and ns.SafeString(ns.SafeCall(UnitGUID, token), 128) ~= guid then return false end
                                return (ns.Active('nameplates') or player and ns.Language.NamesActive()) and TargetScope(token) == scope
                            end})
                            if not binding then
                                if bindingsCount>=100 then plateBindings={};bindingsCount=0 end
                                bindingsCount=bindingsCount+1
                            end
                            plateBindings[unit]={plate=plate,frame=unitFrame,region=unitFrame.name,guid=guid,generation=generation,scope=scope,revision=ns.PolicyRevision}
                            N.bindingStats.bound=N.bindingStats.bound+1
                            else N.bindingStats.reused=N.bindingStats.reused+1 end
                            local action = ns.RegionDisplayStatus(unitFrame.name)
                            if action == "Redacted" or action == "Revealed" or action == "Replaced" then N.plateCounts.filtered = N.plateCounts.filtered + 1
                            elseif action == "Restricted" or action == "Unavailable" or action == "Untracked" then
                                N.plateCounts.restricted = N.plateCounts.restricted + 1
                            end
                        end
                    else N.plateCounts.restricted = N.plateCounts.restricted + 1 end
                end
                if not unit or type(UnitIsPlayer) ~= "function" then N.plateCounts.restricted = N.plateCounts.restricted + 1 end
            end
        end
    end
end
function ns.QueueNameScan()
    if N.queued or not ns.DB then return end
    N.queued = true
    local function Run() N.queued = false; ns.ScanExtraText() end
    if C_Timer and C_Timer.After then C_Timer.After(0, Run) else Run() end
end
local events = CreateFrame("Frame")
for _, event in ipairs({"NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_NAME_UPDATE",
    "GUILD_ROSTER_UPDATE", "FRIENDLIST_UPDATE", "IGNORELIST_UPDATE", "WHO_LIST_UPDATE",
    "BN_FRIEND_INFO_CHANGED", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_TARGET", "GROUP_ROSTER_UPDATE", "MERCHANT_SHOW", "MERCHANT_UPDATE", "PLAYER_REGEN_ENABLED", "ADDON_LOADED"}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
        local token = ns.SafeString(unit, 64)
        if token and token:match("^nameplate%d+$") then
            plateGeneration[token] = (plateGeneration[token] or 0) + 1
            if plateBindings[token] then plateBindings[token]=nil;bindingsCount=bindingsCount-1 end
        end
    end
    if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED"
        or event == "UNIT_TARGET" and (unit == "target" or unit == "focus") then targetRevision = targetRevision + 1 end
    ns.QueueNameScan()
end)
local elapsed = 0
events:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta; if elapsed < 0.35 or not ns.DB then return end
    elapsed = 0
    -- Discover newly pooled visible rows. Disabled name options do no polling.
    if Enabled("playerNames") or ns.Active("npcNames") or ns.Active("dialogue") or ns.Active("vendor") then ns.QueueNameScan() end
end)
