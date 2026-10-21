-- First ChronicleWarden / IntelWarden views. Summaries reference the existing ledger.
local _,ns=...
local U={};ns.WardenUI=U
local A,I,C,V,T,S=ns.ChronicleActivities,ns.ChronicleIntelligence,ns.Chronicle,ns.Art,ns.Theme,ns.ChronicleStore
local Safe=ns.WardenBrand.Text
local navigation=CreateFrame('Frame')
local function EndNavigation() U.pending=nil;navigation:SetScript('OnUpdate',nil) end
U.CancelNavigation=EndNavigation
local function Indexed(st,e) return e and (st.events[e.id]==e or st.intelligence and st.intelligence.events[e.id]==e) end
function U.PumpNavigation()
    local n=U.pending;if not n then return end
    local S,W=ns.ChronicleStore,ns.Workspace
    if S.blocked or not ns.Membership.Allowed() or S.Character(n.owner,false)~=n.character or n.character.events~=n.events
        or W.current~=n.fromPage or n.wasShown and not W.window:IsShown() then EndNavigation();return end
    if InCombatLockdown and InCombatLockdown() then return end
    local destination=(n.kind=='player' or n.kind=='scores') and 'intel' or 'chronicle'
    if ns.Modules.Route(destination)~=destination then EndNavigation();W.Open(destination);return end
    local st,status=A.Request(n.owner);if not st then if status=='blocked' then EndNavigation() end;return end
    if n.event and not Indexed(st,n.event) then EndNavigation();ns.Print('This historical source changed. Reopen the entry from its current history.');return end
    EndNavigation()
    local player=n.kind=='history' and st.players[n.id] or st.intelligence and st.intelligence.players[n.id]
    if n.kind=='player' or n.kind=='scores' or n.kind=='history' then
        if not ns.ChronicleStore.GUID(n.id) or n.id==n.owner:match('/(Player%-.+)$') or not player then
            if n.event then ns.Print('No exact player dossier is available. Opening the original source.');ns.RecordingUI.OpenSource(nil,n.event)
            else ns.Print('No recorded profile for this player is available in the selected history.') end;return
        end
    end
    if n.kind=='player' or n.kind=='scores' then
        local p=W.Destination('intel');if not p then return end;p.owner=n.owner;p.query='';p.search:SetText('');p.selected=n.id;p.detail='profile';p.mode=n.kind=='scores' and 'scoreboards' or 'all';p.scoreGuid=n.kind=='scores' and n.id or nil;p.returnTo=n.origin;p:Activate()
    elseif n.kind=='history' or n.kind=='activity' then
        local a=n.kind=='activity' and st.byID[n.id]
        if n.kind=='activity' and (not a or n.event and not a.evidenceSet[n.event.id]) then
            if n.event then ns.Print('This activity could not be resolved. Opening its source record.');ns.RecordingUI.OpenSource(nil,n.event) end;return
        end
        local p=W.Destination('chronicle');if not p then return end;p.owner=n.owner;p.mode='activities';p.detail='profile';p.returnTo=n.origin
        local view=p.activities;view.owner=n.owner;view.filter={page=0,guid=n.kind=='history' and n.id or nil};view.selected=a and a.id;view.personGUID=nil;view.linkedActivity=a and a.id;view.dirty=true;p:Activate()
    elseif n.kind=='highlight' and n.event then
        local p=W.Destination('chronicle');if not p then return end;p.owner=n.owner;p.mode='journal';p.detail='profile';p.query='';p.search:SetText('');p.linkedRow=U.Highlight(n.event);p.selected=n.event.id;p.returnTo=n.origin;p:Activate()
    end
end
function U.Navigate(kind,owner,id,event,origin)
    local S,W=ns.ChronicleStore,ns.Workspace;local c=owner and S.Character(owner,false)
    local destination=(kind=='player' or kind=='scores') and 'intel' or 'chronicle'
    if ns.Modules.Route(destination)~=destination then W.Open(destination);return false end
    if not c or S.blocked or not ns.Membership.Allowed() then return false end
    U.pending={kind=kind,owner=owner,id=id,event=event,origin=origin,character=c,events=c.events,fromPage=W.current,wasShown=W.window and W.window:IsShown()}
    navigation:SetScript('OnUpdate',U.PumpNavigation);U.PumpNavigation();return true
end
function U.Clear()
    EndNavigation()
    local W=ns.Workspace
    for _,id in ipairs({'intel','chronicle'}) do
        local p=W and W.pages[id]
        if p then
            p.historyView=nil;p.state=nil;p.rowState=nil;p.sourceCharacter=nil;p.rows={};p.selected=nil;p.currentRow=nil;p.noteDirty=nil;p.noteGUID=nil;p.linkedRow=nil;p.returnTo=nil
            p.list:SetItems({});p:ShowItem(nil);p.deep:Clear()
            if p.appearance then p.appearance:SetProfile(nil,nil);p.detail='profile' end
            p.activities.historyView=nil;p.activities.state=nil;p.activities.selected=nil;p.activities.list:SetItems({});p.activities:ShowActivity(nil)
            if p.timeline then p.timeline.historyView=nil;p.timeline.list:SetItems({});p.timeline.revision=nil end
        end
    end
    local home=W and W.pages.overview
    if home and home.cards then home.job=nil;home.revision=nil;home.list:SetItems({});home.search:SetText('') end
end
local function Stamp(at)
    if not at then return 'Not recorded' end
    local ok,value=pcall(date or os.date,'%Y-%m-%d %H:%M',at);return ok and value or tostring(at)
end
U.Stamp=Stamp
function U.OwnerName(owner)
    local c=ns.ChronicleStore.Character(owner,false);local guid=owner and owner:match('/(Player%-.+)$');local pr=c and c.profiles and c.profiles[guid]
    local name=pr and pr.facts and pr.facts.name and pr.facts.name.value
    if name then return name end
    if owner==C.Owner() then return ns.SafeCall(UnitName,'player') or 'This character' end
    return owner and ('Recorded character on '..(owner:match('^([^/]+)') or 'another realm')) or 'Recorded character'
end
function U.EventIcon(e)
    return ns.EventIcons.Record(e)
end
local function Hours(n) return n and n>0 and string.format('%.1f hr',n/3600) or 'Not recorded' end
local function Count(map) local n=0;for _ in pairs(map or {}) do n=n+1 end;return n end
local function Own(st) return st.owner:match('/(Player%-.+)$') end
local function Last(p)
    local facts=p.facts or {};return facts[#facts]
end
function U.Players(st,mode,query)
    local rows={};local i=st.intelligence
    if not i then return rows end
    query=(query or ''):lower()
    for guid,raw in pairs(i.players) do if guid~=Own(st) then
        local p=I.Player(st,guid);local e=Last(p);local d=e and e.details or {}
        local seen=math.max(p.lastLocalAt or 0,p.lastRoster or 0,p.lastInspection or 0,p.lastScoreAt or 0,e and e.at or 0)
        local name=A.Name(st,guid)
        local matches=mode~='recent' or (p.lastLocalAt~=nil or p.lastRoster~=nil or p.lastInspection~=nil or p.lastScoreAt~=nil)
        if mode=='watch' then matches=p.watch end
        local hay=(name..' '..guid..' '..(d.guild or '')..' '..(d.class or p.scoreIdentity and p.scoreIdentity.class or '')..' '..p.tierLabel):lower()
        if matches and (query=='' or hay:find(query,1,true)) then
            rows[#rows+1]={id=guid,title=name,sub=p.description..' • '..Stamp(seen>0 and seen or nil),at=seen,data=p,refs=p.evidence}
        end
    end end
    table.sort(rows,function(a,b) return a.at>b.at or a.at==b.at and a.id<b.id end)
    return rows
end
function U.PlayerStats(st)
    local c=ns.ChronicleStore.Character(st.owner,false);local revision=c and c.revision
    local cached=st.playerStats
    if cached and cached.revision==st.revision and cached.profileRevision==revision then return cached end
    local stats={profiles=0,encounters=0,rosters=0,watch=0,revision=st.revision,profileRevision=revision}
    for guid in pairs(st.intelligence and st.intelligence.players or {}) do
        if guid~=Own(st) then
            local p=I.Player(st,guid);stats.profiles=stats.profiles+1;stats.encounters=stats.encounters+p.recordedEncounters
            if p.lastRoster then stats.rosters=stats.rosters+1 end
            if p.watch then stats.watch=stats.watch+1 end
        end
    end
    st.playerStats=stats;return stats
end
function U.Highlight(e)
    local d=e.details;local title=ns.RecordingUI.Title(e)
    if e.kind=='level_change' then title='Reached level '..tostring(d.after)
    elseif e.kind=='quest_turnin' then title='Quest turned in'..(d.name and ': '..d.name or d.questID and ' # '..d.questID or '')
    elseif e.kind=='skill_change' then title=(d.skill or 'Profession')..' rank changed'
    elseif d.recordType=='encounter_ended' or d.recordType=='boss_kill_event' then title=d.name or 'Boss result recorded'
    elseif d.recordType=='pvp_match_complete' then title='PvP completion report' end
    return {id=e.id,title=title,sub=Stamp(e.at)..' | '..(e.location.zone or 'Location not recorded'),at=e.at,event=e,icon=U.EventIcon(e),refs={e.id}}
end
function U.Highlights(st,query)
    local rows={};local i=st.intelligence;if not i then return rows end
    -- A bounded recent selection from each existing index. No full ledger scan.
    local lists={i.progression.levels,i.progression.achievements,i.progression.collections,i.progression.receipts or {}}
    local seen={};query=(query or ''):lower()
    local function Add(row)
        local hay=(row.title..' '..row.sub):lower()
        if not seen[row.id] and (query=='' or hay:find(query,1,true)) then rows[#rows+1]=row;seen[row.id]=true end
    end
    for _,refs in ipairs(lists) do for n=#refs,math.max(1,#refs-49),-1 do
        local e=i.events[refs[n]]
        if e then
            local d=e.details;local title=ns.RecordingUI.Title(e);local notable=true
            if e.kind=='level_change' then title='Reached level '..tostring(d.after)
            elseif d.recordType=='quest_item_received' then
                -- A loot offer or bag baseline does not prove acquisition.
                -- Missing cached quality stays unknown, never a guessed rarity.
                local getter=GetItemInfo or C_Item and C_Item.GetItemInfo
                local name,_,quality=ns.WardenBrand.Values(getter,d.itemString or d.itemID)
                if not ns.SafeNumber(quality) and C_Item and C_Item.GetItemInfo~=getter then
                    name,_,quality=ns.WardenBrand.Values(C_Item.GetItemInfo,d.itemString or d.itemID)
                end
                quality=ns.SafeNumber(quality);notable=quality~=nil and quality>=3
                title='Notable reward received • '..(ns.SafeString(name,144) or 'Item '..tostring(d.itemID))
            end
            if notable then Add({id=e.id,title=title,sub=Stamp(e.at)..' | '..(e.location.zone or 'Location not recorded'),at=e.at,event=e,icon=U.EventIcon(e),refs={e.id}}) end
        end
    end end
    for n=#st.activities,math.max(1,#st.activities-49),-1 do
        local a=st.activities[n]
        if ({dungeon=true,raid=true,boss=true,battleground=true,arena=true,duel=true})[a.kind] then
            Add({id='activity:'..a.id,title=ns.ChronicleActivitiesUI.Title(a,st),sub=Stamp(a.startAt)..' • '..(a.context.instanceName or a.context.zone or 'Location unavailable'),at=a.startAt,activity=a,icon=ns.EventIcons.Activity(a),refs=a.evidence})
        end
    end
    table.sort(rows,function(a,b) return a.at>b.at or a.at==b.at and a.id<b.id end)
    while #rows>200 do rows[#rows]=nil end
    return rows
end
function U.Profile(st,row)
    local b={};local function Put(kind,text) b[#b+1]={kind=kind,text=Safe(text)} end
    if not row then
        Put('title','Players you remember');Put('body','Choose a player to open their recorded profile. Search a name, guild, class or GUID. Recent players includes sightings, roster associations, inspections and GUID-bearing scoreboard reports. Each keeps its source; none implies a fight.')
        Put('heading','Built from your own history');Put('body','Recording is optional. Previously saved observations stay available while recording is paused. Public Olympus information is dated and kept separate from personal encounters.');return b
    end
    local p=I.Player(st,row.id);local a=A.Player(st,row.id);local e=Last(p);local d=e and e.details or {}
    Put('title',row.title)
    local identity={};for _,v in ipairs({d.class or p.scoreIdentity and p.scoreIdentity.class or '',d.level and 'Level '..d.level or '',d.guild or ''}) do if v~='' then identity[#identity+1]=v end end
    Put('accent',table.concat(identity,' • '));Put('meta','Identity observed '..Stamp(e and e.at or p.scoreIdentity and p.scoreIdentity.at))
    Put('heading',(p.tier and 'Tier '..p.tier..' • ' or '')..p.tierLabel)
    local reasons={};for _,r in ipairs(p.tierReasons) do reasons[#reasons+1]=r.label..(r.at and ' • '..Stamp(r.at) or '') end
    Put('body',#reasons>0 and table.concat(reasons,'\n') or 'No supported local or activity classification. External source information stays separate.')
    Put('meta','Tiers describe recorded relationships and dossier depth. They are not danger ratings or confidence scores. Historical importance does not mean a player is currently inspectable.')
    Put('heading','Personal encounters')
    Put('body',p.recordedEncounters..' local encounter episodes\nFirst encounter: '..Stamp(p.firstEncounter)..'\nLatest encounter: '..Stamp(p.lastEncounter)..'\nLatest roster observation: '..Stamp(p.lastRoster))
    if p.lastInspection then Put('body','Latest manual inspection: '..Stamp(p.lastInspection)) end
    local zones={};for zone in pairs(p.zones or {}) do if zone~='unknown' then zones[#zones+1]=zone end end;table.sort(zones)
    if #zones>0 then Put('body','Encounter zones: '..table.concat(zones,', ')) end
    if a.listedDungeonSegments+a.listedRaidSegments+a.groupSegments>0 then
        Put('heading','Shared adventures');Put('body',a.listedDungeonSegments..' dungeon segments • '..a.listedRaidSegments..' raid segments • '..a.groupSegments..' group segments')
    end
    Put('meta','Roster presence does not confirm individual boss participation.')
    Put('heading','PvP evidence')
    Put('body',p.credits.own..' own native credits • '..p.credits.pet..' pet-associated\n'..p.credits.group..' group-associated • '..p.credits.unattributed..' unattributed')
    Put('meta','Individual last hits, confirmed killers and a personal kill/death ratio are unknown.')
    Put('meta','Native inspected honor and other-player reputation are unavailable. Shared honor-cache values are not attached without reliable player identity. Personal credit, match scoreboards and Olympus reports remain separate sources.')
    local duels=ns.ChronicleDuels.History(st,row.id)
    if duels.total>0 then
        Put('heading','Duels & rival history');Put('body',duels.wins..' verified wins • '..duels.losses..' verified losses • '..duels.unknown..' unknown outcomes\n'..duels.total..' accepted duel sessions • '..duels.challenges..' challenges without observed acceptance')
        Put('body','First duel: '..Stamp(duels.firstAt)..'\nMost recent duel: '..Stamp(duels.lastAt)..(duels.rate and ('\nVerified-result win rate: '..math.floor(duels.rate*100+.5)..'%') or ''))
        for n=1,math.min(5,#duels.rows) do local a=duels.rows[n];Put('body',Stamp(a.startAt)..' • '..a.duel.result..' • '..(a.context.zone or 'Unknown zone')) end
        Put('meta','Open Shared history for individual Duel Analysis pages. Scoreboard presence, native kill credit and Wanted sightings remain distinct sources; none is counted as a duel win.')
    end
    Put('heading','Your note');Put('body',p.note or 'No personal note saved.');Put('meta',p.watch and 'On your watchlist' or 'Not on your watchlist')
    if #p.publicReports>0 then Put('heading','Olympus intelligence');Put('body',#p.publicReports..' dated Olympus observations. Open Evidence for their original dates and source.') end
    if #p.scoreboards>0 then
        Put('heading','Observed PvP scoreboards');Put('body','First report: '..Stamp(p.firstScoreAt)..'\nLatest report: '..Stamp(p.lastScoreAt))
        local reports=p.scoreReports or {}
        for n=#reports,math.max(1,#reports-2),-1 do
            local report=reports[n];local v=report.object.capture.values
            local function Value(key) local x=ns.ChronicleStore.Integer(v[key],0);return x~=nil and tostring(x) or 'Unknown' end
            Put('heading','Latest observation in saved report • '..Stamp(report.lastAt))
            Put('body','Killing blows: '..Value('killingBlows')..' • Honorable kills: '..Value('honorableKills')..' • Deaths: '..Value('deaths')..'\nDamage: '..Value('damageDone')..' • Healing: '..Value('healingDone'))
        end
        Put('meta','Repeated updates are grouped by their saved report token. A token can be reused and is not a verified match ID. Unique matches, summed totals, wins and K/D remain unknown. PvP reports opens all original observations for this GUID.')
    end
    return b
end
function U.ChronicleDetail(st,row)
    if not row then return {{kind='title',text='Your adventure, remembered'},
        {kind='body',text='Highlights selects notable levels, achievements, collection additions, supported rare reward receipts and shared adventures. My Timeline follows your character’s ordinary events. Full source history retains technical observations and every accepted original.'},
        {kind='heading',text='Only the time you recorded'},
        {kind='body',text='Stats describe retained evidence. Unrecorded time and unsupported outcomes remain unknown. Time & averages explains measured coverage; Activities shows the shared-adventure records.'}} end
    if row.activity and row.activity.kind=='duel' then return ns.DuelUI.Blocks(st,row.activity) end
    local b={};local function Put(kind,text) b[#b+1]={kind=kind,text=Safe(text)} end
    Put('title',row.title);Put('meta',row.sub)
    if row.activity then
        local a=row.activity;local seconds=I.ActivityTime(st,a)
        Put('heading','Shared adventure')
        if a.context and (a.context.instanceName or a.context.zone) then Put('accent',a.context.instanceName or a.context.zone) end
        Put('body','First observed: '..Stamp(a.startAt)..'\nLast evidence: '..Stamp(a.lastAt)..'\nRecorded segment: '..a.status)
        Put('body','Measured time in this segment: '..Hours(seconds)..'\n'..#a.attempts..' recorded boss attempts or results.')
        local members={};for guid in pairs(a.members or {}) do members[#members+1]=A.Name(st,guid) end;table.sort(members)
        if #members>0 then Put('heading','Associated roster');Put('body',table.concat(members,', '));Put('meta','Roster association; individual boss attendance remains unknown.') end
        Put('meta','Recorded segment • completion remains '..(a.completion or 'unknown'))
    else
        local e=row.event;local d=e.details
        if e.kind=='level_change' then Put('heading','A new level');Put('body','Recorded change: level '..d.before..' to '..d.after..'.')
        elseif e.kind=='quest_turnin' then
            Put('heading','Quest milestone');Put('body','Quest #'..d.questID..' was turned in.')
            if d.rewardXP then Put('body','Native quest reward: '..d.rewardXP..' XP. This is not added again to XP-change totals.') end
        elseif e.kind=='skill_change' then Put('heading','Profession progress');Put('body',(d.skill or 'Profession')..': '..tostring(d.before or 'Unknown')..' to '..d.after..'.')
        elseif e.kind=='player_death' then Put('body','Your character died here. A confirmed killer was not recorded.')
        elseif e.kind=='equipment_change' then Put('body','Equipment slot '..d.slot..' changed.'..(d.itemID and '\nObserved item ID: '..d.itemID or '\nThe slot was empty or its item was unavailable.'))
        elseif e.kind=='achievement_earned' then Put('body','Achievement #'..d.achievementID..' was recorded as earned.')
        else Put('body','A milestone was saved in your personal history.') end
    end
    Put('heading','Supporting evidence');Put('body','Original record opens the saved facts. Evidence opens their wider historical context.')
    return b
end
function U.AthenaStory(st,row,out,chapterPage)
    if not row then return end
    local dossier=ns.Athena.GetDossier('intel',row.id,{limit=50,chapterPage=chapterPage or 0})
    if not dossier then out[#out+1]={kind='meta',text='Athena is preparing shared evidence references. Old archives remain lazy.'};return end
    local function Put(kind,text) out[#out+1]={kind=kind,text=text} end
    Put('heading','Athena • shared local evidence')
    Put('body','Earned relationship: '..({[1]='Important',[2]='Activity',[3]='Casual'})[dossier.earnedTier]..' • '..#dossier.observers..' loaded observer histories. '..dossier.coverage)
    if dossier.promotion then Put('body','Important since '..Stamp(dossier.promotion.at)..' • '..dossier.promotion.reason);Put('meta','Promotion source: '..dossier.promotion.id..' • Observer: '..dossier.promotion.observer) end
    local f=dossier.freshness
    local labels={pets='Observed pets & companions',groups='Roster roles & leadership',targeting='Targeting episodes',casts='Cast / interruption notices',
        identity='Identity & visible use',gear='Gear & talent evidence',public='Public milestones',guild='Guild associations',effects='Observed effects',social='Social sources'}
    Put('heading','Observed evidence categories')
    for _,key in ipairs({'pets','groups','targeting','casts','identity','gear','effects','public','guild','social'}) do
        local v=dossier.observedCategories and dossier.observedCategories[key]
        Put('body',labels[key]..': '..(v and (v.count..' observations • '..v.provisional..' provisional • '..Stamp(v.firstAt)..' → '..Stamp(v.lastAt)) or 'not observed / native availability unknown'))
    end
    Put('body','Last player evidence: '..Stamp(f.player)..'\nLast local encounter: '..Stamp(f.localEncounter)..'\nEquipment inspected: '..Stamp(f.gear)..'\nTalents inspected: '..Stamp(f.talents)..'\nChat filtering: '..Stamp(f.chat)..'\nProtection changed: '..Stamp(f.shield))
    if #dossier.chapters>0 then
        Put('heading','Activity chapters • page '..((dossier.chapterPage or 0)+1)..' • '..dossier.chapterCount..' retained contexts')
        for _,chapter in ipairs(dossier.chapters) do
            Put('body',chapter.kind..' • '..Stamp(chapter.at)..' • '..(chapter.evidenceCount or #chapter.evidence)..' shared source references')
            Put('meta','Observer: '..chapter.observer..'\nOriginal source: '..tostring(chapter.evidence[1] or 'Unavailable'))
        end
    end
    local context=dossier.protection
    if context and context.filtered>0 then
        Put('heading','Local protection history')
        Put('body',context.filtered..' filtered messages • '..context.spam..' eligible spam decisions • '..context.corrected..' corrected • '..context.sessions..' sessions. '..context.horizon)
        if context.advisory then Put('accent',context.advisory);Put('meta','Local advisory only. Review original decisions in Messages and report false positives there; this never asserts malicious behavior.') end
    end
    for _,gap in ipairs(dossier.gaps) do
        local hours=math.floor(gap.seconds/3600);Put('meta','Observation gap • '..math.floor(hours/24)..' days, '..(hours%24)..' hours • '..gap.explanation..'. Observation resumed at the next source.')
    end
    for _,gap in ipairs(dossier.localGaps or {}) do
        Put('meta','Local observation gap • '..math.floor(gap.seconds/3600)..' hours • '..gap.explanation)
    end
    return dossier
end
function U.OpenChapterSource(chapter)
    local id=chapter and chapter.evidence and chapter.evidence[1]
    if not id or not ns.Athena.GetEvidence('intel',id,chapter.observer) then return false end
    local st=ns.ChronicleActivities.Request(chapter.observer)
    local e=st and (st.events[id] or st.intelligence.events[id])
    if not e then return false end
    ns.RecordingUI.OpenSource(nil,e);return true
end
function U.PlayerStory(st,row,chapterPage)
    if not row then return {{kind='title',text='Players along your path'},{kind='body',text='Select someone you met, grouped with or inspected. Their dossier brings your dated observations, shared adventures and private notes together.'},{kind='heading',text='Begin with an inspection'},{kind='body',text='With recording enabled, inspect a player normally to preserve supported gear and talents. Saved profiles remain available while recording is paused.'}} end
    local p=I.Player(st,row.id);local e=Last(p);local d=e and e.details or {};local shared=A.Player(st,row.id)
    local out={{kind='title',text=Safe(row.title)},{kind='accent',text=Safe(table.concat({d.class or 'Class not recorded',d.level and 'Level '..d.level or 'Level not recorded',d.guild or 'Guild not recorded'},' • '))},
        {kind='meta',text='Identity observed '..Stamp(e and e.at or p.scoreIdentity and p.scoreIdentity.at)},
        {kind='heading',text=p.tierLabel},{kind='body',text=p.description},
        {kind='heading',text='Your history together'},{kind='body',text=p.recordedEncounters..' local encounter episodes • '..shared.listedDungeonSegments..' dungeon segments • '..shared.listedRaidSegments..' raid segments\nFirst encounter: '..Stamp(p.firstEncounter)..'\nLatest encounter: '..Stamp(p.lastEncounter)},
        {kind='meta',text='Roster associations do not confirm individual boss participation.'}}
    if p.lastInspection then out[#out+1]={kind='body',text='Last manual inspection: '..Stamp(p.lastInspection)..'\nOpen Appearance & Gear or Talents for dated configurations.'} end
    local duels=ns.ChronicleDuels.History(st,row.id)
    if duels.total>0 then out[#out+1]={kind='heading',text='Duels remembered'};out[#out+1]={kind='body',text=duels.wins..' verified wins • '..duels.losses..' verified losses • '..duels.unknown..' unknown results'} end
    out[#out+1]={kind='heading',text=p.watch and 'On your watchlist' or 'Your private note'};out[#out+1]={kind='body',text=p.note or 'Add a note below to remember why this player matters to you.'}
    if ns.AthenaEnrichment and st.owner==C.Owner() then
        for _,block in ipairs(ns.AthenaEnrichment.Blocks(row.id,false)) do out[#out+1]=block end
    end
    U.AthenaStory(st,row,out,chapterPage)
    out[#out+1]={kind='meta',text='Details & limits explains native credit, public reports and unknown values. Original record opens the saved source.'};return out
end
function U.Build(parent,kind)
    local W=ns.Workspace;local p=CreateFrame('Frame',nil,parent);p:SetAllPoints(parent);p:Hide()
    p.kind=kind;p.owner=C.Owner();p.mode=kind=='intel' and 'recent' or 'journal';p.query='';p.page=0
    local icon=kind=='intel' and 'IntelWarden' or 'ChronicleWarden'
    local hero=V.Panel(p,0,0,1136,82,'header');local crest=V.Texture(hero,icon,{0,0,512,512});crest:SetPoint('TOPLEFT',15,-9);crest:SetSize(64,64)
    p.heroTitle=V.Text(hero,kind=='intel' and 'Players along your path' or 'Your adventure, remembered',92,-15,kind=='intel' and 580 or 1000,24,V.gold);p.heroTitle:SetHeight(30);p.heroTitle:SetWordWrap(false)
    p.heroSummary=V.Text(hero,kind=='intel' and 'Recently met players and the facts you have kept.' or 'Personal milestones, recorded time and shared adventures.',93,-43,kind=='intel' and 580 or 1000,13,V.muted);p.heroSummary:SetHeight(21);p.heroSummary:SetWordWrap(false)
    if kind=='intel' then
        p.heroTitle:SetWidth(430);p.heroSummary:SetWidth(430)
        p.profileButton=V.Button(hero,'Dossier',540,-25,100,32,function() p.detail='profile';p:Activate() end,'neutral')
        p.gearButton=V.Button(hero,'Appearance & Gear',648,-25,180,32,function() p.detail='gear';p:Activate() end,'neutral')
        p.talentButton=V.Button(hero,'Talents',836,-25,100,32,function() p.detail='talents';p:Activate() end,'neutral')
        p.combatButton=V.Button(hero,'Combat History',944,-25,174,32,function() p.detail='combat';p:Activate() end,'neutral')
        p.appearance=ns.WardenDossier.Build(p,p)
        p.talents=ns.WardenDossier.BuildTalents(p)
        p.combat=ns.IntelCombatUI.Build(p,p)
    end
    p.cards={}
    for n=1,4 do
        local card=V.Panel(p,(n-1)*287,-96,275,77,'dark');card.label=V.Text(card,'',16,-13,245,12,V.blue)
        card.value=V.Text(card,'',16,-35,245,22,V.gold);p.cards[n]=card
    end
    local choices={{false,'This character'}}
    for owner in pairs(ns.ChronicleStore.db and ns.ChronicleStore.db.characters or {}) do if owner~=p.owner then choices[#choices+1]={owner,U.OwnerName(owner)} end end
    p.ownerMenu=V.Dropdown(p,0,-189,330,choices,function() return p.owner~=C.Owner() and p.owner or false end,function(owner)
        p.owner=owner or C.Owner();p.selected=nil;p.page=0;p.state=nil;p:Refresh(true)
    end,{maxRows=8})
    p.search=V.Edit(p,342,-189,494,32,kind=='intel' and 'Search name, guild, class or GUID...' or 'Search recent highlights...',function(value) p.query=value;p.selected=nil;p.page=0;p.dirty=true;p:Refresh(true) end)
    p.target=V.Button(p,kind=='intel' and 'My target' or 'Record settings',848,-189,136,32,function()
        if kind~='intel' then ns.OpenChronicleOptions();return end
        local guid=ns.ChronicleStore.GUID(ns.SafeCall(UnitGUID,'target'))
        if not guid or guid==p.owner:match('/(Player%-.+)$') then p.status:SetText('Select another player with recorded history.');return end
        local intel=p.state and p.state.intelligence
        if not intel or not intel.players[guid] then
            -- An empty view has no Intel projection; combat can also defer its
            -- preparation. Use the existing cooperative navigation, binding the
            -- clicked GUID rather than reading a later replacement target.
            local queued=U.Navigate('player',p.owner,guid)
            if queued and not U.pending then return end
            p.status:SetText(queued and 'Opening recorded target when the saved player view is ready. View preparation waits until after combat.'
                or 'Saved player history is not ready. Wait for history validation, then try again.')
            return
        end
        p.mode='all';p.query='';p.search:SetText('');p.selected=guid;p:Activate();p:Refresh(true)
    end,'neutral')
    p.dataTools=V.Button(p,'Data & Backups',996,-189,140,32,function() W.Open('recording') end,'neutral')
    p.body=CreateFrame('Frame',nil,p);p.body:SetPoint('TOPLEFT',0,-236);p.body:SetSize(1136,380)
    local left=V.Panel(p.body,0,0,390,380,'dark');local right=V.Panel(p.body,404,0,732,380,'dark')
    p.document,p.scroll=V.Document(right,18,-54,677,304)
    p.detailsToggle=V.Button(right,'Details & limits',18,-12,196,28,function() p.showDetails=not p.showDetails;p:ShowItem(p.currentRow) end,'neutral')
    p.detailsToggle:SetShown(kind=='intel')
    p.chapterNewer=V.Button(right,'Newer chapters',466,-12,116,28,function() p.chapterPage=math.max(0,(p.chapterPage or 0)-1);p:ShowItem(p.currentRow) end,'neutral')
    p.chapterOlder=V.Button(right,'Older chapters',592,-12,122,28,function() p.chapterPage=(p.chapterPage or 0)+1;p:ShowItem(p.currentRow) end,'neutral')
    p.chapterNewer:SetShown(kind=='intel');p.chapterOlder:SetShown(kind=='intel')
    local chapterChoices={{false,'Open chapter source'}}
    p.chapterSource=V.Dropdown(right,226,-12,228,chapterChoices,function() return false end,function(n)
        local chapter=p.dossier and p.dossier.chapters[n]
        if chapter then U.OpenChapterSource(chapter) end
    end,{maxRows=7});p.chapterSource:SetHeight(28);p.chapterSource:SetShown(kind=='intel')
    p.dismissAdvisory=V.Button(right,'Dismiss local advisory',226,-12,228,28,function()
        if p.currentRow then ns.Athena.DismissAdvisory('intel',p.currentRow.id);p:ShowItem(p.currentRow) end
    end,'neutral');p.dismissAdvisory:Hide()
    if kind~='intel' then p.scroll:ClearAllPoints();p.scroll:SetPoint('TOPLEFT',right,'TOPLEFT',18,-18);p.scroll:SetHeight(340) end
    p.list=V.ScrollingList(left,12,-13,343,352,64,function(host)
        local row=V.Button(host,'',0,0,340,58,function(self) p.selected=self.item.id;p:ShowItem(self.item);p.list:Render() end,'row')
        row.icon=V.Icon(row,kind=='intel' and 'event:reports' or 'event:capture',32,12,-13)
        row.title=V.Text(row,'',54,-9,272,14,V.gold);row.title:SetHeight(19);row.title:SetWordWrap(false)
        row.sub=V.Text(row,'',54,-32,272,11,V.muted);row.sub:SetHeight(18);row.sub:SetWordWrap(false)
        row.active=V.Nine(row,'selected');return row
    end,function(row,item) row.item=item;row.title:SetText(Safe(item.title));row.sub:SetText(Safe(item.sub));row.active:SetShown(p.selected==item.id);V.SetIcon(row.icon,item.icon or (kind=='intel' and 'event:reports' or 'event:capture')) end)
    p.open=V.Button(p,'Original record',412,-628,162,30,function()
        local row=p.currentRow;if not row then return end
        local ref=row.refs and row.refs[#row.refs];local st=p.state;local intel=st and st.intelligence
        local e=row.event or ref and st and (intel and intel.events[ref] or st.events[ref])
        if e then ns.RecordingUI.OpenSource(nil,e)
        else p.status:SetText('Original source is not ready. Wait for the saved view, then reopen the entry.') end
    end,'neutral')
    p.evidence=V.Button(p,'Evidence',584,-628,134,30,function()
        local row=p.currentRow;if not row then return end
        local host=W.Destination('recording');if not host then return end;host:SetView('intelligence')
        local view=host.intelligence;view.owner=p.owner;view.mode=kind=='intel' and 'players' or 'progress';view.selected=kind=='intel' and row.id or nil;view.dirty=true;view:Refresh(true)
    end,'neutral')
    p.note=V.Edit(p,412,-578,514,30,'Your private note...');p.note:SetMaxLetters(512);p.note.ChatWardenNoSpelling=true
    p.note:HookScript('OnTextChanged',function(_,user) if user then p.noteDirty=true end end)
    p.save=V.Button(p,'Save note',938,-578,180,30,function()
        local row=p.currentRow;if not row or p.owner~=C.Owner() then return end
        local st=p:ReadyPlayer(row);if not st then return end
        local pr=I.Player(st,row.id);local ok,why=C.SetPersonal(row.id,p.note:GetText(),pr.watch)
        if ok then p.noteDirty=nil end
        p.status:SetText(ok and 'Personal note saved on this computer.' or why or 'Unable to save this note.');p:Refresh(true)
    end,'neutral')
    p.watch=V.Button(p,'Watch player',728,-628,190,30,function()
        local row=p.currentRow;if not row or p.owner~=C.Owner() then return end
        local st=p:ReadyPlayer(row);if not st then return end
        local pr=I.Player(st,row.id);C.SetPersonal(row.id,pr.note,not pr.watch);p:Refresh(true)
    end,'neutral')
    p.newer=V.Button(p,'Newer 50',0,-628,146,30,function() p.page=math.max(0,p.page-1);p.selected=nil;p:Refresh(true) end,'neutral')
    p.older=V.Button(p,'Older 50',156,-628,146,30,function() p.page=p.page+1;p.selected=nil;p:Refresh(true) end,'neutral')
    p.status=V.Text(p,'Reading retained history...',4,-664,904,11,V.muted);p.status:SetHeight(26)
    p.status:SetWidth(690);V.HistoryUpdateButton(p,704,-664,208)
    p.back=V.Button(p,'Back to previous view',928,-664,208,26,function()
        local dest=p.returnTo;if dest then U.Navigate(dest.kind,dest.owner,dest.id,dest.event) end
    end,'neutral');p.back:Hide()
    p.shared=V.Button(p,'Shared activities',928,-628,208,30,function()
        if p.currentRow then U.Navigate('history',p.owner,p.currentRow.id,nil,{kind='player',owner=p.owner,id=p.currentRow.id}) end
    end,'neutral');p.shared:SetShown(kind=='intel')
    p.deep=ns.ChronicleIntelligenceUI.Build(p,p);p.deep:Hide()
    p.activities=ns.ChronicleActivitiesUI.Build(p,p);p.activities:Hide()
    if kind=='chronicle' then p.timeline=ns.AthenaTimelineUI.Build(p,p);p.storybook=ns.AthenaJournalUI.Build(p,p) end
    function p:ReadyPlayer(row)
        if not row then return end
        if not self.state then
            -- Hidden pages retain rendered rows, not the full history index.
            -- A click must reacquire that index before using the saved row.
            self.selected=row.id;self.dirty=true;self:Refresh(true)
        end
        local st=self.state
        if st and st.owner==self.owner and st.intelligence and st.intelligence.players[row.id] then return st end
    end
    function p:ShowItem(row)
        if kind=='intel' and row and not self.state then self:ReadyPlayer(row);return end
        local changed=self.currentRow and row and self.currentRow.id~=row.id or (self.currentRow~=nil)~=(row~=nil)
        local offset=row and self.savedSelection==row.id and self.savedScroll or not changed and (self.scroll:GetVerticalScroll() or 0) or 0
        self.currentRow=row
        if changed then self.chapterPage=0 end
        local blocks=kind=='intel' and (self.showDetails and U.Profile(self.state,row) or U.PlayerStory(self.state,row,self.chapterPage)) or U.ChronicleDetail(self.state,row)
        local dossier=kind=='intel' and row and ns.Athena.GetDossier('intel',row.id,{limit=50,chapterPage=self.chapterPage or 0})
        self.dossier=dossier
        for n=#chapterChoices,2,-1 do chapterChoices[n]=nil end
        for n,chapter in ipairs(dossier and dossier.chapters or {}) do chapterChoices[#chapterChoices+1]={n,chapter.kind..' • '..Stamp(chapter.at)} end
        self.chapterSource:SetEnabled(dossier and #dossier.chapters>0 or false)
        self.chapterNewer:SetShown(kind=='intel' and row~=nil and not self.showDetails);self.chapterOlder:SetShown(kind=='intel' and row~=nil and not self.showDetails)
        self.chapterNewer:SetEnabled(dossier and dossier.hasNewerChapters or false);self.chapterOlder:SetEnabled(dossier and dossier.hasOlderChapters or false)
        if kind=='intel' and row and self.showDetails and self.owner==C.Owner() and ns.AthenaEnrichment then
            for _,block in ipairs(ns.AthenaEnrichment.Blocks(row.id,true)) do blocks[#blocks+1]=block end
        end
        self.document:SetBlocks(blocks);self.scroll:SetVerticalScroll(offset)
        self.savedSelection=nil;self.savedScroll=nil
        local context=kind=='intel' and row and ns.Athena.GetPlayerContext('intel',row.id,'protection')
        self.dismissAdvisory:SetShown(context and context.advisory~=nil or false)
        self.chapterSource:SetShown(kind=='intel' and row~=nil and not self.showDetails and not (context and context.advisory))
        self.detailsToggle:SetText(self.showDetails and 'Back to dossier' or 'Details & limits')
        self.open:SetEnabled(row~=nil);self.evidence:SetEnabled(row~=nil)
        self.shared:SetEnabled(row~=nil)
        local editing=kind=='intel' and self.detail~='gear' and self.detail~='talents' and self.detail~='combat'
        self.note:SetShown(editing);self.save:SetShown(editing);self.watch:SetShown(editing)
        self.note:GetParent():SetShown(editing)
        if kind=='intel' then
            self.heroTitle:SetText(Safe(row and row.title or 'Players along your path'))
            self.heroSummary:SetText(row and 'Your recorded dossier • personal notes and evidence' or 'Recently met players and the facts you have kept.')
            self.gearButton:SetEnabled(row~=nil)
            self.talentButton:SetEnabled(row~=nil)
            self.combatButton:SetEnabled(row~=nil)
            if self.detail=='gear' then self.appearance:SetProfile(self.owner,row,self.state) end
            if self.detail=='talents' then self.talents:SetProfile(self.owner,row,self.state) end
            if self.detail=='combat' then self.combat:SetProfile(self.owner,row,self.state) end
            local pr=row and I.Player(self.state,row.id)
            if self.noteGUID~=(row and row.id) or not self.noteDirty then self.note:SetText(pr and pr.note or '');self.noteGUID=row and row.id;self.noteDirty=nil;self.note:ClearFocus() end
            self.save:SetEnabled(pr~=nil and self.owner==C.Owner());self.watch:SetEnabled(pr~=nil and self.owner==C.Owner())
            self.watch:SetText(pr and pr.watch and 'Unwatch player' or 'Watch player')
            right:SetHeight(330);self.scroll:SetHeight(256)
        end
    end
    function p:Activate()
        local specs=kind=='intel' and {{'recent','Recent players'},{'all','All profiles'},{'watch','My watchlist'},{'scoreboards','PvP reports'}} or {{'storybook','Storybook'},{'journal','Highlights'},{'timeline','My Timeline'},{'time','Time & averages'},{'activities','Activities'},{'progress','Progress'}}
        local tabs={};for _,spec in ipairs(specs) do local mode=spec[1];tabs[#tabs+1]={mode,spec[2],function()
            local guid=kind=='intel' and self.mode~='scoreboards' and self.selected
            self.mode=mode;self.detail='profile';self.selected=nil;self.page=0;self.linkedRow=nil
            if mode=='scoreboards' then self.scoreGuid=guid;self.returnTo=guid and {kind='player',owner=self.owner,id=guid} end
            self:Activate();self:Refresh(true)
        end,210} end
        tabs[#tabs+1]={'recording-settings','Recording settings',function() ns.OpenChronicleOptions() end,210}
        W.Tabs(tabs,self.mode)
        local storybook=self.mode=='storybook'
        local deep=self.mode=='time' or self.mode=='progress' or self.mode=='scoreboards';local timeline=self.mode=='timeline';local activities=self.mode=='activities' or timeline
        local summary=not storybook and not deep and not activities and self.detail~='gear' and self.detail~='talents' and self.detail~='combat'
        if self.historyUpdate then self.historyUpdate:Hide() end
        hero:SetShown(not storybook and not deep and not activities);for _,card in ipairs(self.cards) do card:SetShown(summary) end
        self.ownerMenu:SetShown(summary);self.search:GetParent():SetShown(summary);self.target:SetShown(summary)
        self.dataTools:SetShown(summary)
        self.body:SetShown(summary);self.deep:SetShown(deep);self.activities:SetShown(activities and not timeline);if self.timeline then self.timeline:SetShown(timeline) end
        for _,control in ipairs({self.open,self.evidence,self.note,self.save,self.watch,self.newer,self.older,self.status}) do control:SetShown(summary) end
        self.shared:SetShown(kind=='intel' and summary);self.back:SetShown(self.returnTo~=nil)
        self.note:GetParent():SetShown(kind=='intel' and summary)
        if self.appearance then self.appearance:SetShown(not deep and not activities and self.detail=='gear') end
        if self.talents then self.talents:SetShown(not deep and not activities and self.detail=='talents') end
        if self.combat then self.combat:SetShown(not deep and not activities and self.detail=='combat') end
        if deep then self.deep.owner=self.owner;self.deep.mode=self.mode;self.deep.guidFilter=self.mode=='scoreboards' and self.scoreGuid or nil;self.deep.dirty=true end
        if self.storybook then self.storybook:SetShown(storybook) end
        self:Refresh(true)
    end
    function p:Refresh(force)
        if self.mode=='storybook' then self.storybook:Refresh(force);return end
        if self.mode=='timeline' then self.timeline:Refresh(force);return end
        if self.mode=='time' or self.mode=='progress' or self.mode=='scoreboards' then self.deep:Refresh(force);return end
        if self.mode=='activities' then self.activities:Refresh(force);return end
        if InCombatLockdown and InCombatLockdown() then self.status:SetText('Summaries refresh after combat.');return end
        if kind=='chronicle' then
            local own=self.owner==C.Owner();local profile=own and ns.OlympusConnection.Profile()
            local class,token=ns.WardenBrand.Values(UnitClass,'player');class=class~='' and class or token
            self.heroTitle:SetText(Safe(own and (profile and profile.name or ns.SafeCall(UnitName,'player')) or U.OwnerName(self.owner)))
            self.heroSummary:SetText(own and Safe('Current character • Level '..tostring(ns.SafeCall(UnitLevel,'player') or 'unknown')..' • '..(class or 'Class unknown')..' • '..(profile and profile.guild or 'Guild not supplied')) or 'Recorded character • personal milestones and measured history')
        end
        local viewKey=self.mode..'/'..(self.detail or 'profile')..'/'..self.page..'/'..(self.query or '')
        if (not self.detail or self.detail=='profile') and V.HoldHistoryView(self,self.owner,viewKey,force) then return end
        local st,state=A.Request(self.owner)
        if not st then
            local old=self.historyView
            if state~='blocked' and old and old.owner==self.owner and old.key==viewKey and old.generation==A.generation
                and old.character==ns.ChronicleStore.Character(self.owner,false) then
                self.open:SetEnabled(false);self.evidence:SetEnabled(false);self.save:SetEnabled(false);self.watch:SetEnabled(false)
                self.status:SetText(A.ProgressText()..' Previous page and unsaved note kept.');return
            end
            self.state=nil;self.selected=nil;self.currentRow=nil;self.list:SetItems({});self:ShowItem(nil)
            for _,card in ipairs(self.cards) do card.value:SetText('Preparing view…') end
            self.status:SetText(state=='blocked' and 'Saved history is preserved but unavailable to this build.' or A.ProgressText());return
        end
        local c=ns.ChronicleStore.Character(self.owner,false);local revision=c and c.revision
        local enrichmentRevision=ns.AthenaEnrichment and ns.AthenaEnrichment.revision or 0
        if not force and not self.dirty and self.state==st and self.revision==st.revision and self.profileRevision==revision and self.enrichmentRevision==enrichmentRevision and self.athenaRevision==((ns.Athena.queryRevision or 0)+ns.Athena.revision) then return end
        self.state=st;self.sourceCharacter=c;self.revision=st.revision;self.profileRevision=revision;self.athenaRevision=(ns.Athena.queryRevision or 0)+ns.Athena.revision;self.dirty=nil
        self.enrichmentRevision=enrichmentRevision
        local i=st.intelligence or I.New(st.owner)
        local rows=self.rows
        if not rows or self.rowState~=st or self.rowRevision~=st.revision or self.rowProfileRevision~=revision
            or self.rowMode~=self.mode or self.rowQuery~=self.query or self.rowLinked~=self.linkedRow then
            rows=kind=='intel' and U.Players(st,self.mode,self.query) or U.Highlights(st,self.query)
            self.rowState=st;self.rowRevision=st.revision;self.rowProfileRevision=revision;self.rowMode=self.mode;self.rowQuery=self.query;self.rowLinked=self.linkedRow
        end
        if kind=='chronicle' and self.linkedRow then
            local r=self.linkedRow
            if Indexed(st,r.event) then
                local present=false;for _,row in ipairs(rows) do if row.id==r.id then present=true;break end end
                if not present then rows[#rows+1]=r;table.sort(rows,function(a,b) return a.at>b.at or a.at==b.at and a.id<b.id end) end
            else self.linkedRow=nil end
        end
        local stats
        if kind=='intel' then local counts=U.PlayerStats(st);stats={{'Retained profiles',tostring(counts.profiles)},{'Local encounter episodes',tostring(counts.encounters)},{'Players seen on rosters',tostring(counts.rosters)},{'Your watchlist',tostring(counts.watch)}}
        else stats={{'Measured world time',Hours(i.time.seconds)},{'Flagged AFK',i.time.seconds>0 and string.format('%.0f min',i.time.afk/60) or 'Not recorded'},{'Quest turn-ins',tostring(#i.progression.quests)},{'Linked-window XP / hr',i.progression.rateSeconds>0 and string.format('%.0f',i.progression.rateXP*3600/i.progression.rateSeconds) or 'Not recorded'}} end
        for n,stat in ipairs(stats) do self.cards[n].label:SetText(stat[1]);self.cards[n].value:SetText(stat[2]) end
        if self.selected then for n,row in ipairs(rows) do if row.id==self.selected then self.page=math.floor((n-1)/50);break end end end
        self.page=math.min(self.page,math.max(0,math.ceil(#rows/50)-1))
        local shown,selected={},nil;for n=self.page*50+1,math.min(#rows,self.page*50+50) do local row=rows[n];shown[#shown+1]=row;if row.id==self.selected then selected=row end end
        self.selected=selected and selected.id;self.rows=rows;self.list:SetItems(shown,true)
        if self.savedListOffset then
            self.list.offset=math.max(0,math.min(self.savedListOffset,#shown*self.list.step-self.list.scroll:GetHeight()));self.list.scroll:SetVerticalScroll(self.list.offset);self.list:Render();self.savedListOffset=nil
        end
        self:ShowItem(selected)
        self.newer:SetEnabled(self.page>0);self.older:SetEnabled((self.page+1)*50<#rows)
        self.status:SetText('Page '..(self.page+1)..' | '..#rows..(kind=='intel' and ' matching profiles' or ' recent highlights')..' | '..(C.Active() and 'Recording on' or 'Recording paused')..' | Saved observations only.')
        if not self.detail or self.detail=='profile' then V.CommitHistoryView(self,self.owner,self.mode..'/'..(self.detail or 'profile')..'/'..self.page..'/'..(self.query or '')) end
    end
    p:SetScript('OnUpdate',function(self,elapsed) self.tick=(self.tick or 0)+elapsed;if self.tick>=.5 then self.tick=0;self:Refresh() end end)
    p:HookScript('OnHide',function(self)
        if kind=='intel' then ns.Athena.ReleaseDossiers() end
        self.savedSelection=self.selected;self.savedScroll=self.scroll:GetVerticalScroll() or 0
        self.savedListOffset=self.list.offset
        -- Keep only the rendered page, its source identity and draft note while
        -- hidden. Drop full projection references; reopening need not blank an
        -- already completed page merely because a new batch is being indexed.
        self.state=nil;self.rowState=nil;self.sourceCharacter=nil;self.rows=nil;self.revision=nil
        if not self.historyView or not ns.Modules.Enabled(kind) or S.blocked or self.historyView.generation~=A.generation then
            self.historyView=nil;self.currentRow=nil;self.list:SetItems({});self.document:SetBlocks({})
        end
        local selected=self.deep.selected;self.deep:Clear();self.deep.selected=selected
        local activity,person=self.activities.selected,self.activities.personGUID
        self.activities.historyView=nil;self.activities.state=nil;self.activities.list:SetItems({});self.activities:ShowActivity(nil)
        self.activities.selected=activity;self.activities.personGUID=person
        if self.appearance then self.appearance.job=nil;self.appearance.rows={};self.appearance.jobRevision=nil;self.appearance:ClearModel() end
        if self.talents then self.talents.job=nil;self.talents.rows={};self.talents.jobRevision=nil;self.talents:Render() end
        if self.combat then self.combat:Clear() end
    end)
    return p
end
