local _,ns=...
local C,S=ns.Chronicle,ns.ChronicleStore
local disclosure='Save your own route, player encounters and their locations, plus progress, gear and supported activity. Other players are not continuously tracked. This builds future Chronicle and Player Intelligence tools. Olympus boards are source snapshots; missing details stay unknown. History stays on this computer until you clear it. ChatWarden does not upload it or send messages.'
C.Disclosure=disclosure
C.CollectionHelp={
    Character='Your client/build, class/race/body identifiers, rested XP and readable honor values. These describe an observed state, not a newly earned milestone.',
    ['Player state']='Readable AFK, alive/dead/ghost, mounted, swimming, flight, transport, combat, vehicle, resting and PvP flags. Unchanged values are suppressed.',
    Equipment='Readable equipped item IDs and item payloads. Dated full gear objects also preserve slot states and own item GUIDs where available; missing slots remain unknown.',
    Quests='Native accept, turn-in and removal events plus readable quest log/objective snapshots. Removal alone does not establish abandonment or completion.',
    Reputation='Readable faction standings and known before/after changes. Initial values are baselines; rank/renown changes do not invent earned reputation.',
    ['Bag inventory']='Readable item IDs, payloads and quantities in carried bag slots. Slot contents do not prove an acquisition, trade, sale or loot winner.',
    Spellbook='Readable spellbook spell IDs and separate native learned-spell events. An initial spellbook does not establish historical learning dates.',
    ['Loot offered']='Item IDs and quantities offered in a native loot window. This does not establish who received them or what was killed.',
    ['Bind location']='The readable hearth/bind location name and dated native bind-change observations. No exact bind coordinates are invented.',
    Currencies='ID-bound native balances, readable caps and weekly totals, plus separate native currency-update payloads. Filtered/collapsed list discovery is not exhaustive. Only matching known scopes get balance differences.',
    Lockouts='Cached native saved-instance/world-boss entries, difficulty, flags and observed reset expiry. Cache freshness is unknown; complete means readable row coverage, not personal boss kills or a completed run.',
    Mounts='Owned mount ID/spell descriptors and separate explicit new-mount events. An initial catalog is not unlock history.',
    Pets='Owned pet GUID, species and readable basic descriptors. Private pet custom names and notes are excluded. Initial ownership is not a new unlock.',
    Toys='Owned toys from the current filtered native view and explicit new-toy events. Filters are not changed; omitted toys do not imply loss.',
    ['Important players']='Friendly group companions, encountered friends, bookmarked players and important opponents. Group membership alone does not prove proximity or boss participation.',
    Inspection='Ordinary GUID-matched inspection of important players, with ownership checks, timeout and backoff. Missing gear, talents or appearance remain unknown.',
    ['PvP counters']='Readable lifetime/session/yesterday totals. Totals do not identify victims or prove individual victories.',
    ['Forever rank']='Readable rank-faction values only on verified client-build mappings. An unverified build does not receive a guessed rank.',
    ['Native kill credit']='Readable PARTY_KILL actor/target payloads, separated into self, current pet, group or unattributed credit. Live credit semantics remain unverified; these are not declared PvP wins.',
    ['Damage meter']='Supported post-combat session, source and spell totals. These are native summaries, not a raw chronological combat log or complete victim ledger.',
    ['PvP scores']='Readable final native scoreboard rows and match fields. Team totals do not establish per-player victim identities.',
    gear='Dated slot states, item payloads and readable item-instance IDs. Reused snapshots retain separate observation dates; later inspection is not fight-time gear.',
    traits='Committed native trait node/configuration chunks or a subject-bound inspect export when readable. Partial chunks are not a guaranteed atomic full talent build.',
    appearance='Readable body/race/class/display descriptors. Opponent face/hair/transmog and portrait pixels may be unavailable; missing appearance is not reconstructed as fact.',
    barber='Readable option and choice IDs after an applied native barber change. Previewed or cancelled choices do not become history.',
    meter='Post-combat native source/spell aggregates with session/reset identifiers. Amounts are source summaries, not raw combat events.',
    scoreboard='Readable native match scoreboard rows. Names or totals are not converted into independently verified kills or encounters.',
    recap='Readable rows for an explicit native death-recap ID. A recap may be incomplete and does not justify guessing a killer.',
    equipment_set='Read-only named equipment-manager definitions and equipped flags. Definitions are separate from actual equipped gear.',
    stats='Readable effective attributes, armor, maximum health/power and supported combat ratings. They describe the observed loadout/time.',
    rank='Readable native rank-faction snapshot under the verified build adapter. This is dated source data, not an inferred title or promotion.',
    gear_condition='Readable per-slot durability observations. Durability changes do not establish a repair purchase or damage cause.',
    currency='Readable balance for a specific currency ID. Account/character scope and list-discovery limits remain separate; changes do not establish spending cause.',
    collection='Dated owned mount/pet/toy descriptors. Initial catalogs are observations; only explicit new-item events establish a new native delivery.',
    lockout_list='Readable cached saved-instance/world-boss rows in bounded parts. Complete describes cache-read coverage, not current server freshness or personal completion.',
}
function C.PrintStatus(diagnostics)
    ns.Print(C.Status());local stats=C.Statistics()
    ns.Print(stats.events..' retained events; '..stats.profiles..' observed player profiles; '..math.floor(stats.seconds)..' tracked seconds.')
    ns.Print('Saved history: '..stats.encounters..' direct-unit encounters; '..stats.wantedEncounters..' listed Wanted encounters. Raw combat-log recording is disabled on this client.')
    ns.Print('Native kill-credit observations: '..(stats.selfNativeCredits or 0)..' own; '..(stats.petNativeCredits or 0)..' current pet; '..(stats.groupNativeCredits or 0)..' group. These are separate from honorable-kill totals.')
    local storage=S.Storage();ns.Print('All characters: '..storage.events..' events; approximately '..string.format('%.2f',storage.bytes/1048576)..' MiB. '..storage.message)
    ns.Print(string.format('Storage estimates: own routes %.2f MiB; Player Intelligence %.2f MiB; historical player tracks/gaps %.2f MiB; other events %.2f MiB.',storage.ownRouteBytes/1048576,storage.playerIntelBytes/1048576,storage.playerRouteBytes/1048576,storage.otherBytes/1048576))
    ns.Print('No inferred victories, assists, dungeon completions or transaction causes. /ocw chronicle opens recording settings.')
    if diagnostics then
        ns.Print('Recording scope '..S.CONSENT..'; saved consent '..tostring(S.db and S.db.consentVersion or 'none')..'; prompt shown for scope '..tostring(S.db and S.db.promptSeen or 'none')..'. /ocw chronicle prompt reopens the explanation.')
        if ns.ChronicleRoute then ns.Print('Route: '..ns.ChronicleRoute.diagnostics.samples..' native samples this session; '..ns.ChronicleRoute.Pending()..' pending runs; '..ns.ChronicleRoute.diagnostics.unavailable..' unavailable attempts.') end
        if ns.ChronicleCapture then
            local x=ns.ChronicleCapture;ns.Print('Native snapshot errors: '..x.diagnostics.errors..'; rejected: '..x.diagnostics.rejected..'; objects saved: '..x.diagnostics.saved)
            for family,status in pairs(x.status) do ns.Print(family..': '..status) end
            for event,registered in pairs(x.registered) do ns.Print(event..': '..(registered and 'registered' or 'unavailable')..'; seen '..(x.events[event] or 0)) end
        end
        if ns.ChronicleEvidence then for _,family in ipairs(ns.ChronicleEvidence.Support()) do ns.Print(family.name..': '..family.status..'. '..family.methods) end end
        ns.Print('Collector errors: '..C.diagnostics.errors..'; dropped: '..C.diagnostics.dropped..'; duplicates grouped: '..C.diagnostics.duplicates..'; unmeasured gaps: '..C.diagnostics.gaps..'.')
        ns.Print('Estimated saved bytes: '..(stats.bytes or 0)..'; removed by earlier previews: '..(stats.pruned or 0)..'; rejected saved events: '..(stats.dropped or 0)..'. History no longer expires automatically.')
        ns.Print(C.combatSupport)
        ns.Print('Registration does not prove client support. "Seen" means a native event arrived while recording was enabled.')
        local names={};for event in pairs(C.registered) do names[#names+1]=event end;table.sort(names)
        for _,event in ipairs(names) do ns.Print(event..': '..(C.registered[event] and 'registered' or 'unavailable')..'; seen '..(C.diagnostics.events[event] or 0)) end
        for _,name in ipairs({'UnitGUID','UnitFullName','UnitName','GetRealmName','UnitXP','UnitXPMax','UnitLevel','GetMoney',
            'GetNumSkillLines','GetSkillLineInfo','GetNumGroupMembers','GetNumPartyMembers','GetNumRaidMembers','GetInstanceInfo'}) do
            ns.Print(name..': '..(type(_G[name])=='function' and 'present; native behaviour needs validation' or 'unavailable; collector uses only validated alternatives'))
        end
        local kinds={};for kind in pairs(stats.byKind) do kinds[#kinds+1]=kind end;table.sort(kinds)
        for _,kind in ipairs(kinds) do ns.Print(kind..': '..stats.byKind[kind]..' retained events') end
    end
end
function C.Slash(argument)
    argument=(argument or ''):lower()
    if argument=='on' then ns.Print(disclosure);C.SetEnabled(true);C.PrintStatus()
    elseif argument=='off' then C.SetEnabled(false);ns.Print(C.Status())
    elseif argument=='clear confirm' then
        ns.Print(C.Clear() and 'Chronicle and Player Intelligence history cleared. Recording is off.' or 'Unknown saved-data format preserved; this build is not recording it.')
    elseif argument=='clear' then ns.Print('This removes all recorded characters, player profiles, personal notes and watch flags. Use /ocw chronicle clear confirm. Recording will stop.')
    elseif argument=='status' or argument=='diagnostics' then C.PrintStatus(argument=='diagnostics')
    elseif argument=='prompt' then C.MaybePrompt(true)
    elseif argument=='events' or argument=='backup' or argument=='activities' then
        ns.Workspace.Open('recording');if argument~='events' then ns.Workspace.pages.recording:SetView(argument) end
    else ns.OpenChronicleOptions() end
end
function C.IntelSlash(argument)
    local guid=ns.SafeCall(UnitGUID,'target');local p=C.Profile(guid)
    if not p then ns.Print('No recorded profile for this target. Opt in under Settings > Chronicle & Intel, then observe an identifiable player.');return end
    local action,text=(argument or ''):match('^(%S+)%s*(.-)$');action=action and action:lower()
    if action=='bookmark' then
        local saved=ns.ChronicleEncounters and ns.ChronicleEncounters.Important('target','control','personal bookmark')
        ns.Print(saved and 'Important player recorded. Readable details will be saved when inspection is available.' or 'No readable player target, or recording is paused.')
    elseif action=='history' then
        ns.Workspace.Open('recording');local page=ns.Workspace.pages.recording
        if page then page.activities.filter.guid=guid;page.activities.filter.page=0;page.activities.dirty=true;page:SetView('activities') end
    elseif action=='note' then ns.Print(C.SetPersonal(guid,text,nil) and 'Personal note saved locally. Notes are your own remarks, not verified facts.' or 'Note not saved. Use plain text up to 512 characters while recording is enabled.')
    elseif action=='watch' or action=='unwatch' then ns.Print(C.SetPersonal(guid,nil,action=='watch') and 'Personal watch flag saved locally. It does not create alerts or a public listing.' or 'Watch flag not saved.')
    else
        local stats=C.PlayerStatistics(guid);local name=p.facts.name and p.facts.name.value or 'Unnamed player'
        ns.Print(name..': '..stats.encounters..' direct-unit encounter groups; '..stats.importantRecords..' important-player records.')
        ns.Print('Native credit evidence naming this player: '..stats.selfNativeCredits..' own; '..stats.petNativeCredits..' current pet; '..stats.groupNativeCredits..' group; '..stats.unattributedNativeCredits..' unattributed.')
        ns.Print('Older records: '..stats.legacyCombatEvents..' combat observations and '..stats.legacyKillCredits..' legacy credits. Evidence-record counts are not fights or PvP wins.')
        ns.Print('Facts are snapshots from their recorded source and time. /ocw intel bookmark | note TEXT | watch | unwatch applies to your current target.')
    end
end
function ns.BuildChronicleOptions(parent)
    if ns.ChronicleOptionsPanel then return end
    local T,V=ns.Theme,ns.Art
    local panel=CreateFrame('Frame',nil,nil,'BackdropTemplate');panel:SetSize(640,640);T.SkinWindow(panel)
    local body=CreateFrame('Frame',nil,panel);body:SetAllPoints(panel)
    local function Text(value,x,y,width,size,color) return V.Text(body,value,x,y,width,size or 14,color or V.gold) end
    local intro=Text('Your journey. Your player history.',22,-24,590,24)
    local purpose=Text('Start a useful history now for the Chronicle timeline and Player Intelligence tools we are building next. Recording is optional and starts off.',24,-65,590,15,V.muted);purpose:SetHeight(54)
    local check=V.Check(body,'Record Chronicle & Player Intelligence',22,-139,false,function(value)
        C.SetEnabled(value);panel:Refresh()
    end,570)
    T.Tooltip(check,'Optional recording',disclosure..' Chat Capture and alert sounds can remain off. Turning this off keeps existing records; Clear history removes them.')
    local privacy=Text('Where the information comes from',24,-196,590,18)
    local privacyBody=Text(disclosure,24,-226,590,14,V.muted);privacyBody:SetHeight(96)
    local scope=Text('What ChatWarden records',24,-330,590,18)
    local scopeBody=Text('Your route: every 2 seconds. Player encounters keep one location snapshot, with your position separate from theirs. No continuous other-player tracking. Also saves progress, gear, supported combat evidence, currencies, lockouts and collections. Missing details stay unknown.',24,-360,590,14,V.muted);scopeBody:SetHeight(96)
    local status=Text('',24,-468,590,14,V.blue);status:SetHeight(42)
    local stats=Text('',24,-515,590,13,V.muted);stats:SetHeight(58)
    panel.statusHelp=T.StatTooltip(status,'Recording status','Click for recording details. Recording requires your current consent and Olympus access. Pausing keeps history. Missing fields stay unknown.',function() ns.RecordingUI.OpenCollection('time') end)
    panel.statsHelp=T.StatTooltip(stats,'Retained history statistics','Click to see what these counts mean. Events are saved records, profiles are GUID-based observed players, and time excludes offline/loading gaps.',function() ns.RecordingUI.OpenCollection('storage') end)
    local retention=V.Button(body,'Browse events & back up',24,-582,258,32,function() ns.Workspace.Open('recording') end,'neutral')
    T.Tooltip(retention,'Keep your history','History stays until you clear it. There is no automatic age, count or storage expiry. Back up before replacing or formatting your PC.')
    local clear;clear=V.Button(body,'Clear recorded history',302,-582,290,32,function()
        if panel.clearArmed then C.Clear();panel.clearArmed=nil;clear:SetText('Clear recorded history')
        else panel.clearArmed=true;clear:SetText('Click again to clear all') end
        panel:Refresh()
    end,'danger')
    local explanation=V.Button(body,'Show recording explanation',24,-544,290,26,function() C.MaybePrompt(true) end,'neutral')
    local footer=Text('Kept until you clear it. Back up from Recording. Future sharing needs a separate opt-in.',24,-626,590,12,V.muted)
    function panel:Refresh()
        check:SetChecked(S.db and S.db.enabled==true);check:SetEnabled(not S.blocked)
        status:SetText(C.Status())
        if not (InCombatLockdown and InCombatLockdown()) then
            local s=C.Statistics();stats:SetText(s.events..' retained events  |  '..s.profiles..' observed player profiles  |  '..math.floor(s.seconds/60)..' tracked minutes\n'..s.encounters..' direct-unit encounters  |  '..s.wantedEncounters..' listed Wanted encounters\nClick these figures for an explanation. No history is backfilled.')
        end
    end
    function panel:ChatWardenLayout(w,h)
        local width=w-48
        for _,text in ipairs({intro,purpose,privacy,privacyBody,scope,scopeBody,status,stats,footer}) do text:SetWidth(width) end
        purpose:SetHeight(52);privacyBody:SetHeight(68);scopeBody:SetHeight(68)
        ns.Workspace.Place(check,22,-124,width,28)
        ns.Workspace.Place(privacy,24,-183,width,24);ns.Workspace.Place(privacyBody,24,-219,width,68)
        ns.Workspace.Place(scope,24,-302,width,24);ns.Workspace.Place(scopeBody,24,-338,width,68)
        ns.Workspace.Place(status,24,-428,width,42);ns.Workspace.Place(stats,24,-477,width,58)
        ns.Workspace.Place(retention,24,-565,270,32);ns.Workspace.Place(clear,320,-565,290,32)
        ns.Workspace.Place(explanation,24,-535,290,24)
        ns.Workspace.Place(footer,24,-623,width,26)
    end
    panel:SetScript('OnShow',function() panel:Refresh() end)
    panel:SetScript('OnHide',function() panel.clearArmed=nil;clear:SetText('Clear recorded history') end)
    local elapsed=0;panel:SetScript('OnUpdate',function(_,delta) elapsed=elapsed+delta;if elapsed>=5 then elapsed=0;panel:Refresh() end end)
    T.BindSettings(panel);ns.ChronicleOptionsPanel=panel
    if parent and Settings and Settings.RegisterCanvasLayoutSubcategory then
        local category=Settings.RegisterCanvasLayoutSubcategory(ns.Workspace and ns.Workspace.SettingsCanvas(panel,'chronicle') or panel,parent,'Chronicle & Intel')
        if Settings.RegisterAddOnCategory then Settings.RegisterAddOnCategory(category) end
    end
end
-- Separate from release notes and the launch tour: hiding either never consents.
local queued=false
function C.MaybePrompt(force)
    if queued or not C.promptReady or not S.db or S.blocked or not ns.Membership.Allowed() then
        if force then ns.Print('The recording explanation is available after world entry with Olympus access. '..C.Status()) end
        return
    end
    if not force and (S.db.promptSeen==S.CONSENT or S.db.consentVersion==S.CONSENT) then return end
    if InCombatLockdown and InCombatLockdown() then if force then ns.Print('Open the recording explanation after combat with /ocw chronicle prompt.') end;return end
    queued=true
    local function show()
        queued=false
        if not C.promptReady or not S.db or S.blocked or not force and (S.db.promptSeen==S.CONSENT or S.db.consentVersion==S.CONSENT)
            or not ns.Membership.Allowed() or not UIParent:IsVisible() or InCombatLockdown and InCombatLockdown() then return end
        local W=ns.Workspace
        if not force and W and W.window and W.window:IsShown() and W.current=='updates' then
            if not W.window.RecordingPromptHook then
                W.window.RecordingPromptHook=true;W.window:HookScript('OnHide',function() C.MaybePrompt() end)
            end
            return -- No seen marker until the explanation is actually shown.
        end
        local T,V=ns.Theme,ns.Art
        local popup=ns.RecordingConsentWindow
        if not popup then
            -- A true consent popup must not be mounted as a workspace editor.
            popup=V.Panel(UIParent,0,0,620,520,'dark','OlympusChatWardenRecordingConsent');popup:Hide();popup:ClearAllPoints();popup:SetPoint('CENTER')
            if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]='OlympusChatWardenRecordingConsent' end
            popup:SetFrameStrata('DIALOG');popup:SetClampedToScreen(true);popup:EnableMouse(true)
            popup.ChatWardenOwned=true;T.RegisterWindow(popup);ns.RecordingConsentWindow=popup
            V.Button(popup,'X',579,-13,27,27,function() popup:Hide() end,'danger')
            V.Icon(popup,'recording',46,24,-36)
            V.Text(popup,'Start your history with ChatWarden',83,-46,500,21,V.gold)
            local text=V.Text(popup,'Build a personal Chronicle, a future map replay of your travels, and Player Intelligence from your own history. Recording saves precise in-game positions and dated public Olympus information.',26,-110,565,16,V.gold);text:SetHeight(88)
            local scope=V.Text(popup,'Save your own route, progress, gear and supported activity for future Chronicle and Player Intelligence tools. Player encounters keep a single location snapshot when readable. Other players are not continuously tracked. Historical tracks stay saved; unavailable details remain unknown.',26,-215,565,14,V.muted);scope:SetHeight(80)
            local privacy=V.Text(popup,'Your new recorded history stays on this computer. Olympus supplies its existing permitted information; ChatWarden does not upload your route or history. Sharing in a future release would need a separate choice.',26,-311,565,14,V.muted);privacy:SetHeight(76)
            local control=V.Text(popup,'Optional. Covers eligible characters on this installation. Kept until you clear it. Pause, inspect events and back up from Recording. This does not turn on Chat Capture or alert sounds.',26,-403,565,13,V.blue);control:SetHeight(52)
            V.Button(popup,'Not now',26,-470,264,32,function() popup:Hide() end,'neutral')
            V.Button(popup,'Enable recording',307,-470,287,32,function()
                if C.SetEnabled(true) then popup:Hide();ns.Print('Recording enabled. Browse saved events and backups from Recording.') end
            end)
            popup:SetScript('OnHide',function() if S.db and S.db.consentVersion~=S.CONSENT then C.SetEnabled(false) end end)
        end
        S.db.promptSeen=S.CONSENT -- Dismiss, Escape and Not now never enable a new scope.
        popup:SetScale(math.min(1,(UIParent:GetWidth()-24)/620,(UIParent:GetHeight()-24)/520))
        popup:Show();T.FocusWindow(popup)
    end
    if C_Timer and C_Timer.After then C_Timer.After(3,show) else show() end
end
local prompt=CreateFrame('Frame')
prompt:RegisterEvent('PLAYER_REGEN_ENABLED');prompt:RegisterEvent('LOADING_SCREEN_DISABLED')
prompt:SetScript('OnEvent',function() C.MaybePrompt() end)
function ns.OpenChronicleOptions()
    ns.BuildOptions();if ns.Workspace then ns.Workspace.SettingsSub('chronicle') end
end
