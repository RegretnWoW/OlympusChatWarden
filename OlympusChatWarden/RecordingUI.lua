-- Read-only event browser. Only the visible page is materialized as UI rows.
local _,ns=...
local R={PAGE_SIZE=50,BUDGET=128};ns.RecordingUI=R
local C,S,V,T=ns.Chronicle,ns.ChronicleStore,ns.Art,ns.Theme
local names={recording_start='Recording started',recording_stop='Recording stopped',session_start='Session started',
    time_slice='Measured time',location='Location observed',level_change='Level changed',xp_change='XP changed',
    quest_turnin='Quest turned in',skill_change='Skill changed',money_change='Money changed',instance_enter='Instance entered',
    instance_exit='Instance exited',group_roster='Group observed',player_observed='Player observed',player_combat='Combat observation (older build)',
    player_kill_credit='Kill credit (older build)',player_death='Your character died',character_snapshot='Character observed',skill_observed='Skill observed',
    time_span='Measured world time',route_segment='Travel route segment',player_route='Historical player movement',player_route_gap='Historical movement gap',collection_gap='Recording gap',player_state='Character state',
    character_detail='Character details',equipment_observed='Equipment observed',equipment_change='Equipment changed',
    quest_accepted='Quest accepted',quest_removed='Quest removed from log',quest_observed='Quest log observed',quest_objective='Quest objective observed',
    loot_offered='Item offered in loot window',spell_learned='Spell learned',reputation_observed='Reputation observed',bind_observed='Bind location observed',
    olympus_snapshot='Olympus archive',inventory_observed='Bag item observed',spell_observed='Spellbook observed',achievement_earned='Achievement earned',native_snapshot='Preserved native snapshot',native_event='Native activity',loadout_observed='Loadout observed',important_player='Important player'}
R.Names=names
-- Presentation only: meaningful changes and native actions, not a claim that
-- every row is independently verified. Observations remain in the same ledger.
local eventKinds={level_change=true,quest_accepted=true,quest_turnin=true,quest_removed=true,
    player_death=true,achievement_earned=true,equipment_change=true,skill_change=true,
    instance_enter=true,instance_exit=true,spell_learned=true,collection_gap=true,
    native_event=true,bind_observed=true,important_player=true}
local nativeTitles={witness_state='Player state observed',witness_death='Death observed · cause unknown',witness_recovery='Recovery observed',witness_ability='Notable cast observed',encounter_started='Boss encounter started',encounter_ended='Boss encounter ended',
    boss_kill_event='Boss kill reported',native_kill_credit='Native kill credit',
    pvp_match_complete='Battleground match ended',duel_requested='Duel requested',duel_finished='Duel ended',
    recipe_learned='Recipe learned',native_craft_result='Item crafted',barber_choices_applied='Appearance changed',
    quest_item_received='Quest item reward delivered',quest_currency_received='Quest currency reward delivered',encounter_loot_delivery='Encounter loot delivery (recipient unknown)',
    collection_added='Collection added',reputation_standing_changed='Reputation changed',duel_session_request='Duel challenge',duel_session_start='Duel accepted',duel_session_end='Duel boundary',duel_session_result='Verified duel result'}
function R.IsEvent(e)
    if e.kind=='native_event' then return nativeTitles[e.details.recordType]~=nil end
    if e.kind=='bind_observed' then return e.source=='HEARTHSTONE_BOUND' end
    if e.kind=='important_player' then
        local localSource=e.source=='PLAYER_TARGET_CHANGED' or e.source=='UPDATE_MOUSEOVER_UNIT' or e.source=='PLAYER_FOCUS_CHANGED'
        return e.details.relationship=='manual inspection' and e.source=='INSPECT_READY' and S.GUID(e.subject)~=nil
            or e.details.relationship=='personal bookmark' or e.details.relationship=='Wanted encounter'
            and e.details.unitVisible==true and S.GUID(e.subject)~=nil and localSource
    end
    return eventKinds[e.kind]==true
end
function R.Title(e)
    local qualified=ns.AthenaHistorySchema and ns.AthenaHistorySchema.Title(e);if qualified then return qualified end
    if ns.AthenaObservationSchema then local title=ns.AthenaObservationSchema.Title(e);if title then return title end end
    if (e.details.recordType=='aura_effect' or e.details.recordType=='own_spell_success_count') and ns.AthenaCombatQueries then return ns.AthenaCombatQueries.Title(e) end
    if e.details.recordType=='statistic_observed' then return 'Native statistic observed' end
    if e.details.recordType=='score_capture_status' then return 'Scoreboard capture status' end
    if e.details.recordType=='boss_status_observed' then return 'Boss health at encounter end' end
    if e.kind=='important_player' and e.details.relationship=='manual inspection' and e.source=='INSPECT_READY' then return 'Player inspected' end
    if e.kind=='important_player' and e.details.relationship=='Wanted encounter' and R.IsEvent(e) then return 'Wanted encounter' end
    return e.kind=='native_event' and nativeTitles[e.details.recordType] or names[e.kind] or e.kind
end
function R.ClearCachedView()
    R.ClearIndex()
    if ns.WardenUI then ns.WardenUI.Clear() end
    local p=ns.Workspace and ns.Workspace.pages.recording
    if not p then return end
    p.selected=nil;p.snapshot=nil;p.restoreArmed=nil;p.filter.page=0;p.dirty=true;p.waiting=nil;p.wasWaiting=nil
    p.displayKey=nil;p.displayDB=nil
    p.sourceOrigin=nil;if p.sourceBack then p.sourceBack:Hide() end;if p.sourceStatus then p.sourceStatus:SetWidth(850) end
    p.list:SetItems({});p.detailDocument:SetBlocks(R.Detail())
    p.backupBox:SetText('');p.backupResult:SetText('Recorded history cleared. Recording is off. Backups you saved outside the addon are separate copies.')
    if p.activities then
        p.activities.state=nil;p.activities.selected=nil;p.activities.filter.guid=nil;p.activities.dirty=true
        p.activities.list:SetItems({});p.activities:ShowActivity(nil)
    end
    if p.intelligence then p.intelligence:Clear() end
end
function R.OpenSource(host,e)
    local W=ns.Workspace;local origin=W.current~='recording' and W.pages[W.current] and {page=W.current} or nil
    if origin then local page=W.pages[W.current];origin.duelPhase=page.activities and page.activities.analysis and page.activities.analysis.phase end
    if not host or not host.rawCheck then
        host=ns.Workspace.Destination('recording')
        if not host then return end
    end
    host.filter={page=0,mode='all',search=e.id,kinds={[e.kind]=true},raw=true,owner=e.character}
    host.rawCheck:SetChecked(true);host.search:SetText(e.id);host.debounce=nil;host.filter.eventID=e.id
    if origin then
        host.sourceOrigin=origin
        if not host.sourceBack then host.sourceBack=V.Button(host,'Back to previous view',716,0,216,30,function()
            local dest=host.sourceOrigin;host.sourceOrigin=nil;host.sourceBack:Hide();if host.sourceStatus then host.sourceStatus:SetWidth(850) end
            if dest then
                local page=W.Destination(dest.page);local analysis=page and page.activities and page.activities.analysis
                if dest.duelPhase and analysis and analysis.activity then analysis.phase=dest.duelPhase;analysis:Render() end
            end
        end,'neutral') end
        host.sourceBack:SetFrameLevel(host:GetFrameLevel()+8);host.sourceBack:Show();if host.sourceStatus then host.sourceStatus:SetWidth(700) end
    end
    host:SetView('events');host.selected=e.id;host.detailDocument:SetBlocks(R.Detail(e));host.list:Render()
end
local function Time(at)
    local ok,value=pcall(date or function(_,v) return tostring(v) end,'%Y-%m-%d %H:%M:%S',at)
    return ok and value or tostring(at)
end
local function Summary(e)
    local d=e.details
    if e.kind=='level_change' then return 'Level '..d.before..' to '..d.after end
    if e.kind=='skill_change' then return d.skill..' / '..d.after..(d.maximum and ' of '..d.maximum or '') end
    if e.kind=='time_span' then return math.floor(d.seconds)..' seconds'..(d.afk and ' (AFK)' or '') end
    if e.kind=='route_segment' or e.kind=='player_route' then
        local samples=e.route.observations
        if not samples then samples=0;for _,point in ipairs(e.route.points or {}) do samples=samples+point[12] end end
        if e.kind=='player_route' then return (d.name or e.subject)..' / '..samples..' samples' end
        return samples..' samples / '..d.pointCount..' runs'
    end
    if e.kind=='native_snapshot' then return e.details.family..' / '..e.details.contentID:sub(1,12) end
    if e.kind=='native_event' then
        if d.recordType=='encounter_loot_delivery' then return 'Item '..d.itemID..' / '..d.quantity..' / recipient unknown' end
        if d.recordType=='quest_item_received' then return 'Quest '..d.questID..' / Item '..d.itemID..' / '..d.quantity end
        if d.recordType=='quest_currency_received' then return 'Quest '..d.questID..' / Currency '..d.currencyID..' / '..d.quantity end
        if d.recordType=='boss_status_observed' then return (d.creatureName or d.creatureID and 'Creature '..d.creatureID or 'Boss')..(d.remainingHealthPercent~=nil and ' / '..d.remainingHealthPercent..'% health' or ' / health unavailable') end
        if d.encounterID then return (d.name or 'Encounter '..d.encounterID)..(d.recordType=='encounter_ended' and (d.success==1 and ' / Success' or d.success==0 and ' / Unsuccessful' or ' / Outcome unknown') or '') end
        if d.recordType=='native_craft_result' then return 'Item '..d.itemID..' / '..d.quantity..' crafted' end
        if d.recordType=='recipe_learned' then return 'Recipe '..d.recipeID end
        return d.name or (d.recordType:gsub('_',' '))
    end
    if e.kind=='important_player' then return (e.details.name or e.subject)..' / '..(e.details.relationship or 'important encounter') end
    if e.kind=='loadout_observed' then return e.details.reason end
    if e.kind=='olympus_snapshot' then return d.board..' / '..d.snapshotMode end
    return d.name or d.skill or d.questID and 'Quest '..d.questID or e.location.instanceName or e.location.zone or e.source
end
-- A cursor keeps at most one page and a sentinel. Type aliases are view-only;
-- native records retain their original kind, subtype and source in the ledger.
local function Matches(e,f)
    local native=e.kind=='native_event'
    local action=native and nativeTitles[e.details.recordType]~=nil
    local kindMatches=f.kinds and (f.kinds[e.kind]==true or native and
        (action and f.kinds.native_actions==true or not action and f.kinds.native_background==true))
        or not f.kinds and (not f.kind or f.kind==e.kind or native and
            (f.kind=='native_actions' and action or f.kind=='native_background' and not action))
    if not kindMatches or f.mode=='events' and not R.IsEvent(e)
        or f.since and e.at<f.since or f.eventID and e.id~=f.eventID
        or not (f.mode=='all' or f.raw or f.kind=='native_snapshot' or f.kinds and f.kinds.native_snapshot==true or e.kind~='native_snapshot')
        or not f.raw and e.kind=='olympus_snapshot' and e.snapshot.part~=e.snapshot.parts then return false end
    if f.search and f.search~='' then
        local text=table.concat({R.Title(e),e.kind,e.source,e.character,e.subject or '',
            e.id,e.details.recordType or '',tostring(Summary(e)),e.location.zone or '',e.location.subzone or ''},' '):lower()
        return text:find(f.search:lower(),1,true)~=nil
    end
    return true
end
local function Streams(f)
    local streams,total={},0
    for owner,c in pairs(S.db and S.db.characters or {}) do
        if not f.owner or f.owner==owner then
            streams[#streams+1]={owner=owner,character=c,raw=c.events,count=#c.events,tail=c.events[#c.events],events=c.events,index=#c.events}
            total=total+#c.events
        end
    end
    return streams,total
end
local function Next(j)
    local chosen,event
    for _,stream in ipairs(j.streams) do
        local e=stream.events[stream.index]
        if e and (not event or e.at>event.at or e.at==event.at and e.id>event.id) then chosen,event=stream,e end
    end
    if not event then j.complete=true;return end
    chosen.index=chosen.index-1;j.scanned=j.scanned+1
    if Matches(event,j.filter) then
        j.matched=j.matched+1
        if j.matched>j.skip then
            if event.snapshot and not j.filter.raw then local copy={};for k,v in pairs(event) do copy[k]=v end;copy.grouped=true;event=copy end
            j.items[#j.items+1]=event
            if #j.items>R.PAGE_SIZE then j.items[#j.items]=nil;j.more=true;j.complete=true end
        end
    end
end
local function Cursor(filter)
    local streams,total=Streams(filter)
    return {filter=filter,streams=streams,total=total,skip=math.max(0,filter.page or 0)*R.PAGE_SIZE,
        matched=0,scanned=0,indexed=0,items={},more=false,revision=S.revision,db=S.db}
end
-- Synchronous query for existing diagnostic consumers. The visible browser uses
-- Request instead, so even an empty search through years of history yields.
function R.Query(filter)
    local ready,reason=S.RequireCharacters(filter and filter.owner)
    if not ready then return nil,false,nil,reason end
    local j=Cursor(filter or {})
    while not j.complete do Next(j) end
    return j.items,j.more,j.total
end
local caches=setmetatable({},{__mode='k'})
local job
function R.ClearIndex() job=nil;caches=setmetatable({},{__mode='k'}) end
local function Stable(j)
    if j.db~=S.db or S.blocked then return false end
    for _,s in ipairs(j.streams) do
        if S.Character(s.owner,false)~=s.character or s.character.events~=s.raw or s.raw[s.count]~=s.tail then return false end
    end
    return true
end
local function Key(f)
    local parts={}
    for _,k in ipairs({'mode','owner','kind','page','search','since','eventID','raw'}) do
        local v=tostring(f[k]);parts[#parts+1]=#v..':'..v
    end
    local keys={};for k,v in pairs(f.kinds or {}) do if v then keys[#keys+1]=k end end;table.sort(keys)
    parts[#parts+1]=f.kinds and 'custom' or 'all'
    for _,k in ipairs(keys) do parts[#parts+1]=#k..':'..k end
    return table.concat(parts,';')
end
function R.Progress()
    return job and {phase=job.build and 'indexing' or 'searching',indexed=job.indexed,scanned=job.scanned,total=job.total,complete=job.complete} or nil
end
function R.Pump()
    if not job or job.complete or InCombatLockdown and InCombatLockdown() then return 0 end
    if not Stable(job) then job=nil;return 0 end
    local used=0
    while used<R.BUDGET and not job.complete do
        if job.build then
            local stream=job.streams[job.build]
            if not stream then job.build=nil
            else
                local cache=stream.cache
                if cache.count<stream.count then
                    local e=stream.raw[cache.count+1];cache.count=cache.count+1;cache.tail=e
                    if R.IsEvent(e) then cache.items[#cache.items+1]=e end
                    job.indexed=job.indexed+1;used=used+1
                else
                    stream.events=cache.items;stream.index=#cache.items;job.build=job.build+1
                end
            end
        else Next(job);used=used+1 end
    end
    return used
end
function R.Request(filter)
    if S.blocked or not S.db then R.ClearIndex();return {},false,0,S.revision end
    local ready,reason=S.RequireCharacters(filter.owner)
    if not ready then R.ClearIndex();R.archiveStatus=reason;return nil,false,0 end
    R.archiveStatus=nil
    local key=Key(filter)
    if job and (job.key~=key or not Stable(job) or job.complete and job.revision~=S.revision) then job=nil end
    if not job then
        local f={};for k,v in pairs(filter) do f[k]=v end
        if filter.kinds then f.kinds={};for k,v in pairs(filter.kinds) do f.kinds[k]=v end end
        job=Cursor(f);job.key=key
        if f.mode=='events' then
            job.build=1
            for _,stream in ipairs(job.streams) do
                local cache=caches[stream.character]
                if not cache or cache.raw~=stream.raw or cache.count>stream.count or stream.raw[cache.count]~=cache.tail then
                    cache={raw=stream.raw,count=0,items={}};caches[stream.character]=cache
                end
                stream.cache=cache
            end
        end
    end
    R.Pump()
    if job and job.complete then return job.items,job.more,job.total,job.revision end
    return nil,false,job and job.total or 0
end
function R.Detail(e)
    if not e then return {{kind='title',text='Your recording history'},
        {kind='body',text='Events shows milestones, instance entries and exits, boss results and other meaningful changes. Choose All recorded data to inspect observations, routes, measured time and background records. Event types lets you make your own selection. These choices only change the view; recording and retention stay the same.'},
        {kind='body',text='Browse measured world time, travel routes, progress, player observations and dated Olympus data. Choose several event types, or uncheck types you do not want to see. Time spans and stationary samples are compacted; multipart Olympus updates appear together. Select a record for its source and details.'},
        {kind='heading',text='Saved until you clear it'},
        {kind='body',text='History has no automatic age, count or size expiry. Recording is optional. Events from before you opted in cannot be recovered.'},
        {kind='heading',text='Keep a backup'},
        {kind='body',text='Back up your history before replacing or formatting a PC. Use Backup & Restore above. Turning recording off keeps existing history.'},
        {kind='heading',text='Supported observations only'},
        {kind='body',text='Raw combat-log recording is disabled on this client. Unknown details stay unknown. Routes describe your character. Public Wanted lists and rankings are dated source snapshots; appearing in one does not mean you encountered that player.'},
        {kind='heading',text='Measured world time'},
        {kind='body',text='Observed time in the world while recording is active. AFK time is included and marked separately. Offline time, loading screens and unmeasured gaps are excluded. This is not your lifetime /played total.'}} end
    local out={{kind='title',text=R.Title(e)},{kind='heading',text=Time(e.at)},
        {kind='body',text='Source: '..e.source..'\nEvidence: '..e.evidence..'\nClock: '..e.timeSource..'\nCharacter: '..e.character},
        {kind='meta',text='Event: '..e.id..'\nSession: '..e.session..'\nElapsed client seconds: '..e.elapsed}}
    local provenance=ns.ChronicleActivities.Provenance(e)
    if e.details.evidenceState then out[#out+1]={kind='body',text='Evidence status: '..e.details.evidenceState..'\nScope: '..(e.details.scope or 'Original source')..'\nReadability: '..e.details.fieldReadability..'\nInterpretation version: '..e.details.interpretationVersion} end
    out[#out+1]={kind='body',text='Technical source: '..provenance.source..'\nObservation context: '..provenance.context..'\nHistorical scope: '..provenance.scope..'. These are descriptions of the saved record, not independent verification.'}
    local evidenceLabels={['native-event']='Native event delivery', ['value-snapshot']='Observed native values', ['source-aggregate']='Native source summary'}
    out[#out+1]={kind='body',text='Evidence class: '..(evidenceLabels[e.details.evidenceClass] or 'Not recorded for this event')..'. This describes the source, not independent verification.'}
    if e.details.outcome then out[#out+1]={kind='body',text='Native outcome: '..e.details.outcome..' ('..e.details.outcomeScope..'). Applies only to that source and scope.'} end
    if e.restored then out[#out+1]={kind='body',text='Restored from a user backup. Its original source and time are preserved; this import is not an independent observation.'} end
    if e.subject then out[#out+1]={kind='heading',text='Observed player'};out[#out+1]={kind='body',text=e.subject} end
    local playerTrack=e.kind=='player_route' or e.kind=='player_route_gap'
    out[#out+1]={kind='heading',text=playerTrack and 'Your observer context; not the tracked player position' or e.subject and 'Your location when this observation was recorded' or 'Your character location'}
    local keys={};for k in pairs(e.location) do keys[#keys+1]=k end;table.sort(keys)
    for _,k in ipairs(keys) do out[#out+1]={kind='body',text=k..': '..tostring(e.location[k])} end
    if #keys==0 then out[#out+1]={kind='body',text='Not available.'} end
    if e.encounterPosition then
        local p=e.encounterPosition
        out[#out+1]={kind='heading',text='Encounter location snapshot'}
        out[#out+1]={kind='body',text='Read at '..Time(p.at)..'. One snapshot when this encounter began; no movement between encounters is recorded. UI coordinates are map fractions; native axes retain UnitPosition return order. Observer coordinates never stand in for the other player.'}
        for _,role in ipairs({'observer','subject'}) do
            out[#out+1]={kind='heading',text=role=='observer' and 'Your position at the encounter' or 'Other player position returned by the API'}
            local values={};for k,v in pairs(p[role] or {}) do values[#values+1]=k..'='..string.format('%.17g',v) end
            table.sort(values);out[#out+1]={kind='body',text=#values>0 and table.concat(values,', ') or 'Coordinates unavailable. No position was inferred.'}
        end
    end
    out[#out+1]={kind='heading',text='Recorded details'};keys={};for k in pairs(e.details) do keys[#keys+1]=k end;table.sort(keys)
    for _,k in ipairs(keys) do local v=e.details[k];out[#out+1]={kind='body',text=k..': '..(type(v)=='table' and table.concat(v,', ') or tostring(v))} end
    if #keys==0 then out[#out+1]={kind='body',text='No additional details.'} end
    if e.route then
        local route,err=ns.ChronicleCodec.Decode(e.route)
        out[#out+1]={kind='heading',text='Original coordinate samples'}
        out[#out+1]={kind='body',text=(playerTrack and 'Historical track retained from an earlier build. No new other-player tracks are collected. Coordinates belong to '..e.subject..'. Sample interval: '..e.details.interval..' seconds. Group membership does not prove proximity or dungeon participation. ' or 'Own character only. ')..'UI coordinates are fractions on mapID; native axes retain UnitPosition return order on worldMapID. Missing values are unavailable, not zero. Repeated identical observations are runs; no path is invented between samples.'}
        if not route then out[#out+1]={kind='body',text='Route could not be decoded: '..tostring(err)}
        else
            out[#out+1]={kind='body',text='UI mapID: '..tostring(route.mapID or 'unavailable')..'; native worldMapID: '..tostring(route.worldMapID or 'unavailable')}
            local labels={'at','elapsed','uiX','uiY','native1','native2','native3','facing','speed','lastAt','lastElapsed','observations'}
            for i,point in ipairs(route.points) do
                local row={};for j,label in ipairs(labels) do row[#row+1]=label..'='..(point[j]==false and 'unavailable' or string.format('%.17g',point[j])) end
                out[#out+1]={kind='body',text=i..': '..table.concat(row,', ')}
            end
        end
    end
    if e.snapshot then
        out[#out+1]={kind='heading',text='Dated Olympus source data'}
        out[#out+1]={kind='body',text='This is a copy of permitted Olympus API data at the recorded time. A full snapshot establishes the returned board; a delta lists changes/removals. Unavailable means no data was returned, not an empty board. Public rows are not personal encounters or independently verified events.'}
        local parts={e}
        if e.grouped then
            parts={};local c=S.Character(e.character,false)
            for _,item in ipairs(c and c.events or {}) do if item.snapshot and item.snapshot.id==e.snapshot.id then parts[#parts+1]=item end end
            table.sort(parts,function(a,b) return a.snapshot.part<b.snapshot.part end)
        end
        for _,part in ipairs(parts) do
            local snap=part.snapshot
            out[#out+1]={kind='meta',text='Part '..snap.part..'/'..snap.parts..' | '..part.id}
            for _,row in ipairs(snap.rows) do
                local values={};local sorted={};for k in pairs(row.values) do sorted[#sorted+1]=k end;table.sort(sorted)
                for _,k in ipairs(sorted) do values[#values+1]=k..'='..tostring(row.values[k]) end
                out[#out+1]={kind='body',text=row.key..': '..table.concat(values,', ')}
            end
            for _,key in ipairs(snap.removed) do out[#out+1]={kind='body',text='Removed from returned board: '..key} end
        end
    end
    local objects={}
    if e.capture then objects[#objects+1]=e end
    if ns.ChronicleCapture then
        local seen={}
        for _,key in ipairs({'gearRef','traitRef','appearanceRef','contentID'}) do
            local hash=e.details[key]
            if hash and not seen[hash] and not e.capture then
                seen[hash]=true;local object=ns.ChronicleCapture.Find(e.character,hash)
                if object then objects[#objects+1]=object else out[#out+1]={kind='body',text='Snapshot unavailable: '..hash} end
            end
        end
    end
    for _,object in ipairs(objects) do
        out[#out+1]={kind='heading',text='Saved '..object.capture.family..' data'}
        out[#out+1]={kind='meta',text='Content observed first: '..Time(object.at)..'. The activity details keep the actual later observation time. These IDs do not include portrait pixels.'}
        local function lines(value,prefix)
            local sorted={};for k in pairs(value) do sorted[#sorted+1]=k end
            table.sort(sorted,function(a,b) return tostring(a)<tostring(b) end)
            for _,k in ipairs(sorted) do
                local v=value[k];local label=prefix..tostring(k)
                if type(v)=='table' then lines(v,label..'.') else out[#out+1]={kind='body',text=label..': '..tostring(v)} end
            end
        end
        lines(object.capture.values,'')
    end
    if e.kind=='native_event' then out[#out+1]={kind='body',text='Native source evidence, not an inferred victory, kill ledger or dungeon completion. Gear references are dated observations, not proof of the gear used at the event.'} end
    if e.kind=='loot_offered' then out[#out+1]={kind='body',text='Observed in a loot window. This does not establish who acquired it, a kill, or a loot winner.'} end
    if e.kind=='inventory_observed' then out[#out+1]={kind='body',text='Contents of this bag slot at the recorded time. This does not establish an acquisition, sale, trade or loss.'} end
    if e.kind=='quest_removed' then out[#out+1]={kind='body',text='The native quest-removed event arrived. Removal alone does not distinguish a turn-in, abandonment or other cause.'} end
    return out
end
function R.CollectionItems(stats,storage)
    local G=ns.CollectionGuide;local reports={}
    for _,family in ipairs(ns.ChronicleEvidence.Support()) do reports[family.name]=family end
    local rows,byKey={},{}
    local function Add(key,metrics,info)
        local entry=info or G.topics[key];local report=reports[key]
        local row={key=key,label=entry and entry.label or key,info=entry,metrics=metrics,
            summary=entry and entry.what or 'Collector diagnostic: click for details',
            status=report and report.status or C.Active() and 'Waiting for readable values or a matching native event. Check saved events for actual history.' or C.Status(),
            methods=report and report.methods}
        rows[#rows+1]=row;byKey[key]=true
    end
    Add('time',string.format('%d saved records; %d player profiles. Measured world time: %d minutes, including %d marked AFK minutes. Pending own-route runs: %d.',stats.events,stats.profiles,math.floor(stats.seconds/60),math.floor(stats.afkSeconds/60),ns.ChronicleRoute.Pending()))
    Add('storage',storage.partial and string.format('%d loaded records; %d characters remain packed. Every archive is retained. Total structural estimate: %.2f MiB. Open a character or request an all-character view to validate its records.',storage.events,storage.packedCharacters,storage.bytes/1048576)
        or string.format('%d records across %d characters; %.2f MiB estimated retained data. Your routes: %.2f MiB. Player Intelligence: %.2f MiB. Historical player tracks and gaps: %.2f MiB. Other events: %.2f MiB. %s',storage.events,storage.characters,storage.bytes/1048576,storage.ownRouteBytes/1048576,storage.playerIntelBytes/1048576,storage.playerRouteBytes/1048576,storage.otherBytes/1048576,storage.message))
    for _,entry in ipairs(storage.breakdown) do
        local info={};for k,v in pairs(G.topics.storage) do info[k]=v end;info.label='History: '..entry.name
        Add('character:'..entry.owner,entry.loaded==false and (entry.owner..'\nArchive retained but not loaded. Record counts and categories are unavailable until validation, not zero.') or string.format('%s\n%d records; %.2f MiB estimated retained data. Your routes: %.2f MiB / %d samples. Player Intelligence: %.2f MiB. Historical player tracks and gaps: %.2f MiB / %d samples. Other events: %.2f MiB.',entry.owner,entry.events,entry.bytes/1048576,entry.ownRouteBytes/1048576,entry.ownRouteSamples,entry.playerIntelBytes/1048576,entry.playerRouteBytes/1048576,entry.playerRouteSamples,entry.otherBytes/1048576),info)
    end
    Add('route',string.format('This addon session: %d own-route samples and %d unavailable attempts. Current-character saved samples: %d.',ns.ChronicleRoute.diagnostics.samples,ns.ChronicleRoute.diagnostics.unavailable,stats.ownRouteSamples))
    Add('Player encounter locations',string.format('Current character: %d grouped encounters, including %d with dated Wanted context. Historical other-player movement is retained; new continuous movement is not collected.',stats.encounters,stats.wantedEncounters))
    local keys={};for key in pairs(G.topics) do if not byKey[key] and key~='olympus' and key~='preservation' then keys[#keys+1]=key end end
    table.sort(keys,function(a,b) return G.topics[a].label<G.topics[b].label end)
    for _,key in ipairs(keys) do Add(key) end
    local extra={};for key in pairs(reports) do if not byKey[key] and key~='olympus' and key~='preservation' then extra[#extra+1]=key end end;table.sort(extra)
    for _,key in ipairs(extra) do Add(key) end
    Add('olympus',string.format('This addon session: %d public archive updates; %d unchanged updates suppressed. A board does not establish a local sighting.',ns.ChronicleOlympus.diagnostics.snapshots,ns.ChronicleOlympus.diagnostics.unchanged))
    Add('preservation',storage.message)
    return rows
end
function R.OpenCollection(key)
    ns.Workspace.Open('recording')
    local p=ns.Workspace.pages.recording
    if not p then return end -- Access may have changed since the metric was shown.
    p:SetView('coverage');p:SelectCollection(key or 'time')
end
function R.Build(parent)
    local W=ns.Workspace;local p=CreateFrame('Frame',nil,parent);p:SetAllPoints(parent);p:Hide()
    p.filter={page=0,mode='events'};p.live=true;p.view='events'
    p.events=CreateFrame('Frame',nil,p);p.events:SetAllPoints(p)
    p.backup=CreateFrame('Frame',nil,p);p.backup:SetAllPoints(p);p.backup:Hide()
    p.coverage=CreateFrame('Frame',nil,p);p.coverage:SetAllPoints(p);p.coverage:Hide()
    p.activities=ns.ChronicleActivitiesUI.Build(p,p);p.activities:Hide()
    p.intelligence=ns.ChronicleIntelligenceUI.Build(p,p);p.intelligence:Hide()
    local coveragePanel=V.Panel(p.coverage,0,0,1136,650,'dark')
    coveragePanel:SetWidth(388)
    V.Text(coveragePanel,'Choose what you want to understand',16,-16,352,15,V.gold)
    local detailPanel=V.Panel(p.coverage,404,0,732,650,'paper')
    p.coverageDocument,p.coverageScroll=V.Document(detailPanel,18,-16,670,616)
    p.collectionSelected='time'
    p.coverageList=V.ScrollingList(coveragePanel,12,-54,337,574,62,function(host)
        local row=V.Button(host,'',0,0,334,56,function(self) p:SelectCollection(self.topic.key) end,'row')
        row.label=V.Text(row,'',14,-10,304,14,V.gold);row.label:SetHeight(19);row.label:SetWordWrap(false)
        row.summary=V.Text(row,'',14,-32,304,12,V.muted);row.summary:SetHeight(16);row.summary:SetWordWrap(false)
        row.selectedArt=V.Nine(row,'selected');row.selectedArt:SetShown(false)
        return row
    end,function(row,topic)
        row.topic=topic;row.label:SetText(topic.label);row.summary:SetText(topic.summary or 'Click for recording details')
        row.selectedArt:SetShown(p.collectionSelected==topic.key)
        T.Tooltip(row,topic.label,'Click for what is saved, when it records, an example and its limits.')
    end)
    function p:SelectCollection(key)
        self.collectionSelected=key
        local topic=self.collectionByKey and self.collectionByKey[key]
        if topic then self.coverageDocument:SetBlocks(ns.CollectionGuide.Describe(topic));self.coverageScroll:SetVerticalScroll(0) end
        self.coverageList:Render()
    end
    local e=p.events
    local status=V.Text(e,'',4,-5,850,14,V.blue);status:SetHeight(42);p.sourceStatus=status
    p.statusHelp=T.StatTooltip(status,'Recording and measured time','Measured world time covers observed recording-active intervals; marked AFK is included, offline/loading gaps are excluded. Estimated history describes this character, not measured file size or memory. Pending route runs are your own not-yet-flushed samples. Click for collection details and all-character storage.',function() p:SetView('coverage');p:SelectCollection('time') end)
    V.Button(e,'Recording settings',920,-3,216,32,function() ns.OpenChronicleOptions() end,'neutral')
    local search=V.Edit(e,0,-54,390,32,'Search recorded events...',function(value) p.filter.search=value;p.filter.eventID=nil;p.dirty=true;p.debounce=.35 end);p.search=search
    local characters={{false,'All recorded characters'},{'current','This character'}}
    local function reset() p.filter.page=0;p.filter.eventID=nil;p.dirty=true;p:Refresh(true) end
    local owner=V.Dropdown(e,402,-54,390,characters,function() return p.filter.owner and 'current' or false end,
        function(v) p.filter.owner=v=='current' and C.Owner() or nil;reset() end)
    local kinds={{false,'All event types'},{'none','Clear selection'}};local sorted={};for kind in pairs(names) do sorted[#sorted+1]=kind end;table.sort(sorted)
    for _,kind in ipairs(sorted) do
        kinds[#kinds+1]={kind,kind=='native_event' and 'Native activity (all)' or names[kind]}
        if kind=='native_event' then
            kinds[#kinds+1]={'native_actions','Native actions'}
            kinds[#kinds+1]={'native_background','Native background summaries'}
        end
    end
    local defaultHidden={}
    p.typeFilter=V.Dropdown(e,804,-54,332,kinds,function() return p.filter.kinds end,function(v)
        local wasEvents=p.filter.mode=='events'
        if v==false then p.filter.kinds=nil
        elseif v=='none' then p.filter.kinds={}
        else
            if not p.filter.kinds then
                p.filter.kinds={}
                for kind in pairs(names) do if not wasEvents or eventKinds[kind] and kind~='native_event' then p.filter.kinds[kind]=true end end
                if wasEvents then p.filter.kinds.native_actions=true end
            end
            if v=='native_event' then
                p.filter.kinds.native_actions=nil;p.filter.kinds.native_background=nil
            elseif v=='native_actions' or v=='native_background' then
                if p.filter.kinds.native_event then
                    p.filter.kinds.native_event=nil;p.filter.kinds.native_actions=true;p.filter.kinds.native_background=true
                end
            end
            p.filter.kinds[v]=not p.filter.kinds[v] or nil
        end
        p.filter.mode='all' -- An explicit type selection can include observations.
        p.filter.kind=nil;reset()
    end,{multiple=true,clearValue='none',maxRows=9,defaultExcluded=defaultHidden})
    T.Tooltip(p.typeFilter,'Choose event types','Check the types you want. Native actions keeps boss, duel, crafting and other notable actions separate from Native background summaries. Native activity (all) includes both. Custom selections can include observations; choose Events to return to the quiet default. Recording stays unchanged.')
    local live=V.Check(e,'Live updates',0,-96,true,function(v) p.live=v;if v then reset() end end,180)
    V.Button(e,'Refresh',194,-96,150,28,function() C.Flush();p.dirty=true;p:Refresh(true) end,'neutral')
    p.rawCheck=V.Check(e,'Show raw Olympus parts',365,-96,false,function(v)
        p.filter.raw=v;if v then p.filter.mode='all' end;reset()
    end,290)
    function p:SetRecordMode(mode)
        self.filter.mode=mode=='events' and 'events' or 'all';self.filter.kinds=nil;self.filter.kind=nil
        self.filter.raw=false;self.rawCheck:SetChecked(false);reset()
    end
    p.recordMode=V.Dropdown(e,680,-96,456,{{'events','View: Events'},{'all','View: All recorded data'}},
        function() return p.filter.mode or 'all' end,function(mode) p:SetRecordMode(mode) end)
    local listPanel=V.Panel(e,0,-139,430,468,'dark');local detailPanel=V.Panel(e,444,-139,692,468,'paper')
    local doc=V.Document(detailPanel,16,-16,660,435);doc:SetBlocks(R.Detail())
    p.detailDocument=doc
    p.list=V.ScrollingList(listPanel,12,-13,383,440,65,function(parentRow)
        local row=V.Button(parentRow,'',0,0,380,59,function(self)
            p.selected=self.event.id;doc:SetBlocks(R.Detail(self.event));p.list:Render()
        end,'row')
        row.icon=V.Icon(row,'event:capture',27,14,-16)
        row.selectedArt=V.Nine(row,'selected');row.selectedArt:SetShown(false)
        row.title=V.Text(row,'',51,-10,310,14,V.gold);row.title:SetHeight(18);row.title:SetWordWrap(false)
        row.sub=V.Text(row,'',51,-32,310,12,V.muted);row.sub:SetHeight(18);row.sub:SetWordWrap(false)
        return row
    end,function(row,event)
        row.event=event;row.selectedArt:SetShown(p.selected==event.id)
        V.SetIcon(row.icon,ns.EventIcons.Record(event));row.title:SetText(R.Title(event))
        row.sub:SetText(Time(event.at)..'  |  '..tostring(Summary(event)))
        T.Tooltip(row,names[event.kind] or event.kind,Time(event.at)..'\n'..event.source..'\n'..event.character)
    end)
    local newer=V.Button(e,'Newer 50',0,-621,170,32,function() p.filter.page=math.max(0,p.filter.page-1);p.dirty=true;p:Refresh(true) end,'neutral')
    local older=V.Button(e,'Older 50',182,-621,170,32,function() p.filter.page=p.filter.page+1;p.dirty=true;p:Refresh(true) end,'neutral')
    local count=V.Text(e,'',369,-628,760,13,V.muted)
    count:SetHeight(20)
    p.countHelp=T.StatTooltip(count,'Event counts and paging','Each page shows up to 50 matching records. Saved events counts every retained record in the selected character scope, including types hidden by the current view. Filters do not change collection or delete history. Click for details.',function() p:SetView('coverage');p:SelectCollection('storage') end)
    local b=CreateFrame('Frame',nil,p.backup);b:SetAllPoints(p.backup);p.textBackup=b;b:Hide()
    V.Text(b,'History-only text merge (advanced)',8,-62,1090,24,V.gold)
    local how=V.Text(b,'Use this only to merge history without replacing settings. Pause recording, create a snapshot, and copy every numbered part from the same backup. Restore each part separately with recording off. Existing personal notes are kept. For a large history or a new PC, use File backup instead.',8,-108,1100,14,V.muted);how:SetHeight(82)
    local boxFrame=V.Panel(b,8,-257,1128,287,'dark')
    local scroll=CreateFrame('ScrollFrame',nil,boxFrame);scroll:SetPoint('TOPLEFT',14,-12);scroll:SetSize(1074,260);V.SkinScroll(scroll)
    local box=CreateFrame('EditBox',nil,scroll);box.ChatWardenNoSpelling=true;box:SetMultiLine(true);box:SetAutoFocus(false)
    box:SetFontObject(GameFontHighlight);box:SetMaxLetters(33000);box:SetSize(1074,260);scroll:SetScrollChild(box);T.TextField(box,scroll)
    box:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
    p.backupBox=box
    local result=V.Text(b,'Your backup contains identifiable player history and personal notes. Keep it private.',8,-556,1110,13,V.blue);result:SetHeight(54)
    p.backupResult=result
    local part=V.Text(b,'No text backup created.',590,-222,540,13,V.gold)
    local function showPart()
        box:SetText(p.snapshot.parts[p.part]);box:SetCursorPosition(0);scroll:SetVerticalScroll(0);p.restoreArmed=nil
        part:SetText('Part '..p.part..' of '..p.snapshot.total..'  |  Backup '..p.snapshot.batch:sub(1,12))
        box:HighlightText();box:SetFocus()
    end
    V.Button(b,'Create text backup',8,-215,220,32,function()
        local started,err=ns.ChronicleBackup.Begin(function(snapshot,message)
            p.snapshot=snapshot;p.part=1
            if snapshot then showPart();result:SetText('Snapshot ready. Copy all '..snapshot.total..' parts before deleting or replacing anything. You can resume recording now; new events are not added to this snapshot.') else result:SetText(message) end
        end)
        result:SetText(started and 'Creating your private snapshot in small steps. Keep recording paused until it is ready.' or err)
    end)
    V.Button(b,'Previous part',240,-215,158,32,function() if p.snapshot then p.part=math.max(1,p.part-1);showPart() end end,'neutral')
    V.Button(b,'Next part',410,-215,158,32,function() if p.snapshot then p.part=math.min(p.snapshot.total,p.part+1);showPart() end end,'neutral')
    V.Button(b,'Restore this part',8,-621,250,32,function()
        local text=box:GetText()
        if p.restoreArmed~=text then
            local data,err=ns.ChronicleBackup.Validate(text)
            if not data then result:SetText(err);return end
            p.restoreArmed=text;result:SetText('Ready to merge part '..data.index..' of '..data.total..'. This restores private history from a file you trust. Click Restore this part again to confirm.');return
        end
        p.restoreArmed=nil;local ok,message=ns.ChronicleBackup.Restore(text);result:SetText(message);if ok then p.dirty=true end
    end,'neutral')
    V.Button(b,'Pause recording',274,-621,220,32,function() C.SetEnabled(false);result:SetText('Recording is off. Existing history is kept. You can restore now.') end,'neutral')
    V.Button(b,'Select all text',510,-621,220,32,function() box:SetFocus();box:HighlightText() end,'neutral')
    V.Button(b,'Cancel backup',746,-621,220,32,function() ns.ChronicleBackup.Cancel();result:SetText('Backup creation cancelled. Existing history is kept.') end,'neutral')
    local f=CreateFrame('Frame',nil,p.backup);f:SetAllPoints(p.backup);p.fileBackup=f
    V.Text(f,'One file holds your complete Warden history and settings',8,-64,1100,23,V.gold)
    local intro=V.Text(f,'WoW already saves your history and settings in the file below. Keep a backup copy outside the addon folder. You do not need numbered text parts for a complete backup.',8,-105,1100,15,V.muted);intro:SetHeight(48)
    p.savedFilePath=V.Edit(f,8,-166,1100,32,'',nil)
    p.savedFilePath:SetText('WTF/Account/<your account>/SavedVariables/OlympusChatWarden.lua')
    p.savedFilePath:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
    local filePanel=V.Panel(f,8,-219,1128,333,'paper')
    p.fileGuide=V.Document(filePanel,18,-16,1060,300)
    p.fileGuide:SetBlocks({
        {kind='heading',text='1. Save and fully close WoW'},
        {kind='body',text='Exit normally so WoW writes the latest data. Pausing recording alone does not save a new file. Keep the game closed throughout backup or restore.'},
        {kind='heading',text='2. Make one backup ZIP'},
        {kind='body',text='Run the optional ChatWarden Backup Tool for Windows. Choose the file above inside your WoW folder, then save a dated backup ZIP to another folder or drive. The tool checks its checksum. It runs outside WoW and is downloaded separately.'},
        {kind='heading',text='3. Restore with WoW closed'},
        {kind='body',text='Choose your backup ZIP and the correct account destination in the tool. It keeps a safety copy of existing data before restoring. A complete restore replaces all saved ChatWarden settings and history, including the saved recording choice.'},
        {kind='heading',text='Without the Windows tool'},
        {kind='body',text='Copy OlympusChatWarden.lua from the SavedVariables folder to a safe location. To restore, put that copy back in the same account folder with WoW closed. The .lua.bak file beside it can also be kept as an extra older recovery copy.'},
    })
    local privacy=V.Text(f,'Complete-file backups include filters, signed imports, chat captures, player history, personal notes and Relay drafts/inbox. Keep them private. History-only text merges do not include Relay reports. File backup copies data; it does not upload it.',8,-565,1100,13,V.blue);privacy:SetHeight(48)
    V.Button(f,'Select saved-file path',8,-621,270,32,function() p.savedFilePath:SetFocus();p.savedFilePath:HighlightText() end,'neutral')
    p.fileModeButton=V.Button(p.backup,'File backup (recommended)',8,-8,340,32,function() p:SetBackupMode('file') end)
    p.textModeButton=V.Button(p.backup,'History-only text merge',362,-8,300,32,function() p:SetBackupMode('text') end,'neutral')
    function p:SetBackupMode(mode)
        self.backupMode=mode=='text' and 'text' or 'file'
        self.fileBackup:SetShown(self.backupMode=='file');self.textBackup:SetShown(self.backupMode=='text')
        self.savedFilePath:ClearFocus();self.backupBox:ClearFocus()
        self.fileModeButton:SetEnabled(self.backupMode~='file');self.textModeButton:SetEnabled(self.backupMode~='text')
    end
    p:SetBackupMode('file')
    function p:SetView(view)
        self.view=view;if view=='backup' then self:SetBackupMode(self.backupMode or 'file') end;self.events:SetShown(view=='events');self.backup:SetShown(view=='backup');self.coverage:SetShown(view=='coverage');self.activities:SetShown(view=='activities');self.intelligence:SetShown(view=='intelligence')
        W.Tabs({{'events','Recorded Events',function() p:SetView('events') end,200},
            {'activities','Activity evidence',function() p:SetView('activities') end,180},
            {'intelligence','Summary evidence',function() p:SetView('intelligence') end,180},
            {'backup','Backup & Restore',function() p:SetView('backup') end,220},
            {'coverage','Collection Status',function() p:SetView('coverage') end,220}},view)
        self:Refresh(true)
    end
    function p:Activate() self:SetView(self.view) end
    function p:Refresh(force)
        if self.view=='activities' then self.activities:Refresh(force);return end
        if self.view=='intelligence' then self.intelligence:Refresh(force);return end
        if InCombatLockdown and InCombatLockdown() then count:SetText('Viewer updates after combat. Supported recording continues.');return end
        -- Aggregate statistics can scan a cold ledger. Keep opening the event
        -- browser cheap; full measured-time/storage figures live in Collection Status.
        local character=S.Character(C.Owner(),false)
        status:SetText(C.Status()..(S.loading and '\nRecord counts appear after history validation finishes.' or '\nThis character: '..(character and #character.events or 0)..' records | ~'..string.format('%.2f',(character and character.bytes or 0)/1048576)..' MiB | Pending runs: '..ns.ChronicleRoute.Pending()..' | Click for collection details.'))
        if self.view=='coverage' then
            local s=C.Statistics();local storage=S.Storage()
            local topics=R.CollectionItems(s,storage)
            self.collectionByKey={};for _,topic in ipairs(topics) do self.collectionByKey[topic.key]=topic end
            self.coverageList:SetItems(topics,true)
            local selected=self.collectionByKey[self.collectionSelected] or topics[1]
            self.collectionSelected=selected.key;self.coverageDocument:SetBlocks(ns.CollectionGuide.Describe(selected))
            return
        end
        if self.view~='events' then return end
        if InCombatLockdown and InCombatLockdown() then count:SetText('Viewer updates after combat. Supported recording continues.');return end
        if not force and not self.waiting and not self.dirty and self.selected and self.revision~=S.revision then
            count:SetText('New history available. Click Refresh when ready; your selected source stays in place. Recording continues.');return
        end
        if not force and not self.waiting and not self.dirty and (not self.live or self.filter.page>0 or self.revision==S.revision) then return end
        self.revision=S.revision;self.dirty=nil
        owner:Refresh();self.recordMode:Refresh();self.rawCheck:SetChecked(self.filter.raw==true)
        for kind in pairs(names) do defaultHidden[kind]=self.filter.mode=='events' and (not eventKinds[kind] or kind=='native_event') or nil end
        defaultHidden.native_background=self.filter.mode=='events' or nil
        defaultHidden.native_actions=nil
        kinds[1][2]=self.filter.mode=='events' and 'Event types (Events view)' or 'All event types';self.typeFilter:Refresh()
        local items,more,total,revision=R.Request(self.filter)
        local displayKey=Key(self.filter);local sameView=self.displayKey==displayKey and self.displayDB==S.db
        self.waiting=items==nil
        if not items then
            self.wasWaiting=true
            if not sameView then
                self.list:SetItems({});newer:SetEnabled(false);older:SetEnabled(false)
                self.detailDocument:SetBlocks({{kind='title',text='Loading recorded history'},
                    {kind='body',text='Reading saved records in small steps. You can change filters or leave this page. Recording continues; your history stays intact.'}})
            end
            local progress=R.Progress()
            count:SetText(R.archiveStatus or ((progress and progress.phase=='indexing' and 'Preparing Events index' or 'Searching recorded history')..' | '..(progress and progress.indexed+progress.scanned or 0)..' records checked this request | '..total..' saved records'))
            return
        end
        self.revision=revision;self.list:SetItems(items,sameView);self.displayKey=displayKey;self.displayDB=S.db
        local selected=false;for _,item in ipairs(items) do if item.id==self.selected then selected=true;break end end
        if self.selected and not selected then self.selected=nil;self.detailDocument:SetBlocks(R.Detail()) end
        if self.selected and selected then for _,item in ipairs(items) do if item.id==self.selected then self.detailDocument:SetBlocks(R.Detail(item));break end end
        elseif self.wasWaiting then self.detailDocument:SetBlocks(R.Detail()) end
        self.wasWaiting=nil
        newer:SetEnabled(self.filter.page>0);older:SetEnabled(more)
        count:SetText('Page '..(self.filter.page+1)..'  |  '..#items..' matching events shown  |  '..total..' saved events in this character scope')
    end
    local elapsed=0;p:SetScript('OnUpdate',function(_,delta)
        elapsed=elapsed+delta
        if p.debounce then p.debounce=p.debounce-delta;if p.debounce<=0 then p.debounce=nil;reset() end;return end
        if p.waiting and p.view=='events' then p:Refresh(true)
        elseif elapsed>=2 then elapsed=0;p:Refresh() end
    end)
    return p
end
