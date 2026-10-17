local _,ns=...
local C,S=ns.Chronicle,ns.ChronicleStore
local disclosure='ChronicleWarden and IntelWarden (Player Intelligence) save your route, encounters and locations, progress, gear and supported activity. No continuous tracking of other players. Permitted Olympus data stays dated; missing facts stay unknown. Kept locally until you clear it. Warden does not upload history or send messages.'
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
    ['Important players']='Friendly group companions, manually inspected players, encountered friends, bookmarked players and important opponents. A deliberate Inspect is a manual interaction, not evidence of combat participation.',
    Inspection='Ordinary GUID-matched inspection of important players, including your native Inspect window while recording. Saves readable gear, appearance, readable selected talents/ranks, native export and inspected specialization. Stale or competing requests are rejected. Missing fields stay unknown; no other-player reputation or unverified honor cache is saved.',
    ['PvP counters']='Readable lifetime/session/yesterday totals. Totals do not identify victims or prove individual victories.',
    ['Forever rank']='Readable rank-faction values only on verified client-build mappings. An unverified build does not receive a guessed rank.',
    ['Native kill credit']='Readable PARTY_KILL actor/target payloads, separated into self, current pet, group or unattributed credit. Live credit semantics remain unverified; these are not declared PvP wins.',
    ['Damage meter']='Supported post-combat session, source and spell totals. These are native summaries, not a raw chronological combat log or complete victim ledger.',
    ['PvP scores']='Readable final native scoreboard rows and match fields. Team totals do not establish per-player victim identities.',
    gear='Dated slot states, item payloads and readable item-instance IDs. Reused snapshots retain separate observation dates; later inspection is not fight-time gear.',
    traits='Committed native trait node/configuration chunks, or a GUID-matched inspected talent export and specialization ID when readable. IntelWarden > Talents shows dated selections, ranks, exports and older builds. Old export-only records need another inspection for readable choices. Partial chunks and specialization alone do not establish a full talent build.',
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
        ns.Print('History initialization: '..(S.loading and 'loading' or S.db and 'ready' or S.blocked and 'blocked' or 'unfinished')..'; addon startup stage: '..tostring(ns.InitializationStage or 'not recorded')..'.')
        if S.loadError then ns.Print(S.loadError) end
        for _,failure in ipairs(ns.StartupErrors or {}) do ns.Print('Startup: '..failure) end
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
    if argument=='statistics' then ns.ChronicleStatistics.Print()
    elseif argument:match('^statistics ids') then ns.ChronicleStatistics.PrintIDs(tonumber(argument:match('^statistics ids%s+(%d+)$')))
    elseif argument=='duels on' or argument=='duels off' then
        ns.ChronicleDuels.SetEnabled(argument=='duels on');ns.Print('Optional duel recording '..(S.db and S.db.duels and 'enabled' or 'off')..'. Local only; before/after captures are dated observations; received amounts have no attacker attribution. Main Chronicle consent is still required.')
    elseif argument=='on' then ns.Print(disclosure);C.SetEnabled(true);C.PrintStatus()
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
    local panel=CreateFrame('Frame',nil,nil,'BackdropTemplate');panel:SetSize(640,676);T.SkinWindow(panel)
    local body=CreateFrame('Frame',nil,panel);body:SetAllPoints(panel)
    local function Text(value,x,y,width,size,color) return V.Text(body,value,x,y,width,size or 14,color or V.gold) end
    local intro=Text('Your journey. Your player history.',22,-24,590,24)
    local purpose=Text('Explore your adventure in ChronicleWarden and remember players in IntelWarden. Recording starts off for new users; pausing keeps your existing history.',24,-65,590,15,V.muted);purpose:SetHeight(54)
    local check=V.Check(body,'Record Chronicle & Player Intelligence',22,-139,false,function(value)
        if not C.SetEnabled(value) then ns.Print(C.Status()) end;panel:Refresh()
    end,570)
    T.Tooltip(check,'Optional recording',disclosure..' Chat Capture and alert sounds can remain off. Turning this off keeps existing records; Clear history removes them.')
    local privacy=Text('Where the information comes from',24,-196,590,18)
    local privacyBody=Text(disclosure,24,-226,590,14,V.muted);privacyBody:SetHeight(96)
    local scope=Text('What Warden records',24,-330,590,18)
    local scopeBody=Text('Your route: every 2 seconds. Encounters keep available positions separately for you and the other player. Also records progress, gear, supported combat, native statistics, currencies, lockouts and collections. Missing details stay unknown.',24,-360,590,14,V.muted);scopeBody:SetHeight(96)
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
    local danger=V.Panel(body,16,-576,608,48,'minimal');panel.dangerZone=danger
    V.Text(danger,'Delete recorded history',14,-5,290,16,{1,.55,.4})
    V.Text(danger,'Back up first. Permanent removal.',14,-27,290,12,V.muted)
    local line=danger:CreateTexture(nil,'BORDER');line:SetPoint('TOPLEFT');line:SetPoint('BOTTOMLEFT');line:SetWidth(3);line:SetColorTexture(.72,.18,.12,1)
    clear:SetParent(danger);clear:ClearAllPoints();clear:SetPoint('TOPRIGHT',-8,-8);clear:SetWidth(290)
    local explanation=V.Button(body,'Show recording explanation',24,-544,290,26,function() C.MaybePrompt(true) end,'neutral')
    local duel=V.Check(body,'Optional: record duel history',322,-544,false,function(value)
        if not value then ns.ChronicleDuels.SetEnabled(false);panel:Refresh();return end
        local popup=panel.duelConsent
        if not popup then
            popup=V.Panel(UIParent,0,0,580,340,'dark');popup:ClearAllPoints();popup:SetPoint('CENTER');popup:SetFrameStrata('DIALOG');popup:SetClampedToScreen(true);popup:EnableMouse(true)
            V.Text(popup,'Remember your duels',24,-22,530,23,V.gold)
            local text=V.Text(popup,'Keep individual duels, verified results, and both players’ available gear and talents before and after each fight. Unchanged configurations share content while each duel keeps its own dated observations.',24,-72,530,15,V.muted);text:SetHeight(76)
            local limits=V.Text(popup,'Also saves bounded successful casts and damage/healing received during the duel window. Received amounts have no attacker attribution. Missing inspections and unknown outcomes stay unknown. This history stays on this computer until you clear it; nothing is uploaded.',24,-160,530,14,V.blue);limits:SetHeight(92)
            V.Button(popup,'Not now',24,-286,244,32,function() popup:Hide();panel:Refresh() end,'neutral')
            V.Button(popup,'Enable duel recording',284,-286,272,32,function()
                if ns.ChronicleDuels.SetEnabled(true) then
                    popup:Hide();ns.Print(S.db and S.db.enabled and 'Optional duel recording enabled.' or 'Duel recording selected. Enable Chronicle recording to begin collecting duels.')
                else ns.Print(C.Status()) end
                panel:Refresh()
            end)
            panel.duelConsent=popup
        end
        popup:Show();T.FocusWindow(popup);panel:Refresh()
    end,290)
    panel.duelCheck=duel
    T.Tooltip(duel,'Your duel history','Separate opt-in. Saves accepted challenges, verified results, both players’ available gear/talents before and after, successful casts and received damage/healing during the duel window. Received amounts have no attacker attribution. Local only; no raw combat log or scanning. Failed captures and unknown results stay visible. History is kept until you clear it.')
    local footer=Text('Kept until you clear it. Back up from Recording. Future sharing needs a separate opt-in.',24,-626,590,12,V.muted)
    function panel:Refresh()
        intro:SetText(S.loading and 'Your history is loading' or not S.db and 'Your history is unavailable' or C.Active() and 'Your adventure is recording' or 'Recording is paused • history kept')
        duel:SetChecked(S.db and S.db.duels==true and S.db.duelConsent==1);duel:SetEnabled(S.db~=nil and not S.blocked)
        check:SetChecked(S.db and S.db.enabled==true);check:SetEnabled(S.db~=nil and not S.blocked)
        local text=C.Status()
        if S.db and S.db.duels and not ns.ChronicleDuels.Enabled() then text=text..' Duel recording is selected but currently inactive.' end
        status:SetText(text)
        if S.loading then stats:SetText('Checking retained history. Record and player counts appear when validation finishes.')
        elseif not S.db then stats:SetText('Saved history is unavailable. The original saved file is preserved; no empty history has replaced it.')
        elseif not (InCombatLockdown and InCombatLockdown()) then
            local s=C.Statistics();stats:SetText(s.events..' retained events  |  '..s.profiles..' observed profiles  |  '..math.floor(s.seconds/60)..' measured minutes\n'..s.encounters..' local encounters  |  '..s.wantedEncounters..' Wanted encounters')
        end
    end
    function panel:ChatWardenLayout(w,h)
        local width=w-48
        for _,text in ipairs({intro,purpose,privacy,privacyBody,scope,scopeBody,status,stats,footer}) do text:SetWidth(width) end
        purpose:SetHeight(52);privacyBody:SetHeight(68);scopeBody:SetHeight(68)
        ns.Workspace.Place(check,22,-124,width,28)
        ns.Workspace.Place(privacy,24,-183,width,24);ns.Workspace.Place(privacyBody,24,-219,width,68)
        ns.Workspace.Place(scope,24,-302,width,24);ns.Workspace.Place(scopeBody,24,-338,width,68)
        ns.Workspace.Place(status,24,-418,width,36);ns.Workspace.Place(stats,24,-458,width,42)
        ns.Workspace.Place(retention,24,-540,270,32)
        ns.Workspace.Place(danger,24,-578,width,48)
        clear:ClearAllPoints();clear:SetPoint('TOPRIGHT',-12,-8);clear:SetSize(290,32)
        ns.Workspace.Place(explanation,24,-507,290,24)
        ns.Workspace.Place(duel,322,-507,width-322,28)
        ns.Workspace.Place(footer,24,-642,width,26)
    end
    panel:SetScript('OnShow',function() panel:Refresh() end)
    panel:SetScript('OnHide',function() panel.clearArmed=nil;clear:SetText('Clear recorded history') end)
    local elapsed=0;panel:SetScript('OnUpdate',function(_,delta) elapsed=elapsed+delta;if elapsed>=5 then elapsed=0;panel:Refresh() end end)
    T.BindSettings(panel);ns.ChronicleOptionsPanel=panel
    if parent and Settings and Settings.RegisterCanvasLayoutSubcategory then
        local category=Settings.RegisterCanvasLayoutSubcategory(parent,ns.Workspace and ns.Workspace.SettingsCanvas(panel,'chronicle') or panel,'Chronicle & Intel')
        if Settings.RegisterAddOnCategory then Settings.RegisterAddOnCategory(category) end
    end
end
-- Separate from release notes and the launch tour: hiding either never consents.
local queued=false
function C.MaybePrompt(force)
    if S.loading then
        if force then C.promptAfterLoad=true;ns.Print('Your saved history is still loading. The recording explanation will open when validation finishes. '..C.Status()) end
        return
    end
    if queued or not C.promptReady or not S.db or S.blocked or not ns.Membership.Allowed() then
        if force then
            ns.Print((not S.db or S.blocked) and C.Status() or not ns.Membership.Allowed() and ns.Membership.Status() or 'The recording explanation is available after world entry. '..C.Status())
        end
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
            V.Text(popup,'Remember your adventure with Olympus Warden',83,-46,500,21,V.gold)
            local text=V.Text(popup,'Explore personal milestones in ChronicleWarden and players you remember in IntelWarden. Recording is optional and starts off.',26,-110,565,16,V.gold);text:SetHeight(88)
            local scope=V.Text(popup,'Saves your precise route every two seconds, progress, gear and supported activities. Player encounters keep available locations, not continuous tracks. Dated permitted Olympus data is included. Missing facts stay unknown; duel recording needs a separate choice.',26,-215,565,14,V.muted);scope:SetHeight(80)
            local privacy=V.Text(popup,'History stays on this computer until you clear it. Warden does not upload it or send messages. You control deliberate exports and backups; future sharing needs separate consent. Existing historical tracks remain saved.',26,-311,565,14,V.muted);privacy:SetHeight(76)
            local control=V.Text(popup,'Applies to eligible characters on this installation. Pausing keeps history. Review and back up from Data & Backups. This does not enable Chat Capture or alert sounds.',26,-403,565,13,V.blue);control:SetHeight(52)
            V.Button(popup,'Not now',26,-470,264,32,function() popup:Hide() end,'neutral')
            V.Button(popup,'Enable recording',307,-470,287,32,function()
                if C.SetEnabled(true) then popup:Hide();ns.Print('Recording enabled. Browse saved events and backups from Recording.') end
            end)
            popup:SetScript('OnHide',function() if S.db and S.db.consentVersion~=S.CONSENT then C.SetEnabled(false) end end)
        end
        S.db.promptSeen=S.CONSENT -- Dismiss, Escape and Not now never enable a new scope.
        T.FitWindow(popup,620,520)
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
