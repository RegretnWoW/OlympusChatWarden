-- Inspection UI for the shared intelligence foundation; no new recording choice.
local _,ns=...
local A,I,V,T=ns.ChronicleActivities,ns.ChronicleIntelligence,ns.Art,ns.Theme
local U={};ns.ChronicleIntelligenceUI=U
local function Stamp(at)
    if not at then return 'Not recorded' end
    local ok,v=pcall(date or os.date,'%Y-%m-%d %H:%M:%S',at);return ok and v or tostring(at)
end
local function Duration(n) return n and string.format('%.2f hours (%d seconds)',n/3600,math.floor(n)) or 'Not recorded' end
local function UTC(at)
    local ok,v=pcall(date or os.date,'!%Y-%m-%d',at);return ok and v or tostring(at)
end
local function Blocks()
    local out={};local function Put(kind,text) out[#out+1]={kind=kind,text=text} end
    return out,Put
end
local function Keys(map)
    local keys={};for key in pairs(map or {}) do keys[#keys+1]=key end
    table.sort(keys,function(a,b) return tonumber(a) and tonumber(b) and tonumber(a)<tonumber(b) or not (tonumber(a) and tonumber(b)) and a<b end)
    return keys
end
local function TimeDetail(i,m,label)
    local b,Put=Blocks();Put('title',label)
    if m.seconds==0 then Put('body','No eligible measured intervals in this view. Missing time is not a measured zero.');return b end
    Put('heading','Recorded in-world time: '..Duration(m.seconds))
    Put('body','Flagged AFK: '..Duration(m.afk)..'\nNot flagged AFK: '..Duration(m.nonAfk)..'\nAFK state unknown: '..Duration(m.afkUnknown))
    Put('body','Not flagged AFK does not mean actively playing. AFK and combat can overlap a location category; do not add them to location totals.')
    Put('heading','Activity context')
    for _,kind in ipairs(Keys(m.categories)) do Put('body',kind..': '..Duration(m.categories[kind])..string.format(' / %.1f%% of measured time',100*m.categories[kind]/m.seconds)) end
    Put('heading','Supported overlapping windows')
    Put('body','Measured time inside paired combat events: '..Duration(m.combatSeconds)..'\nMeasured time inside observed group segments: '..Duration(m.groupContextSeconds))
    Put('body','These are covered-window totals. Time outside them is unclassified, not proven out of combat or solo. A group segment is based on saved roster observations; it cannot establish exact time grouped with another player.')
    Put('heading','Zones')
    for _,zone in ipairs(Keys(m.zones)) do Put('body',zone..': '..Duration(m.zones[zone])) end
    Put('heading','What is included')
    Put('body','Only unique measured intervals are counted. Overlaps count once; contradictory dimensions become unknown. Offline/loading gaps are excluded. Compacted totals with unlocated holes and overlapping recording-clock ranges stay unallocated.')
    if i then
        Put('body','Unallocated reported time: '..Duration(i.excludedReportedSeconds)..'\nOverlapping measured coverage counted once: '..Duration(i.overlapSeconds))
        Put('body','Calendar views use recorded UTC dates. Intervals crossing a day, week or month boundary stay unassigned for that period instead of being prorated. Day-boundary unassigned time: '..Duration(i.calendarUnknown.day)..'. These are recorded-history totals, not lifetime /played.')
    end
    return b
end
function U.Rows(st,mode,guidFilter)
    local i=st.intelligence;local rows={};if not i then return rows end
    local function Add(id,title,sub,data,refs) rows[#rows+1]={id=id,title=title,sub=sub,data=data,refs=refs or {}} end
    if mode=='players' then
        local guids=Keys(i.players)
        for _,guid in ipairs(guids) do local p=I.Player(st,guid);Add(guid,A.Name(st,guid),p.description,p,p.evidence) end
    elseif mode=='battlegrounds' then
        for n=#st.activities,1,-1 do local a=st.activities[n]
            if a.kind=='battleground' or a.kind=='arena' then Add(a.id,ns.ChronicleActivitiesUI.Title(a),Stamp(a.startAt)..' | '..a.status,a,a.evidence) end
        end
    elseif mode=='scoreboards' then
        for n=#i.scoreboards,1,-1 do local e=i.events[i.scoreboards[n]];local v=e.capture.values
            if not guidFilter or v.guid==guidFilter then Add(e.id,v.name or v.guid or 'Scoreboard observation',Stamp(e.at)..' | Match assignment unknown',e,{e.id}) end
        end
    elseif mode=='progress' then
        for _,key in ipairs({'levels','xp','quests','skills','equipment','collections','achievements'}) do
            Add(key,({levels='Levels',xp='Experience',quests='Quest milestones',skills='Professions',equipment='Equipment changes',collections='Collection additions',achievements='Achievements'})[key],#i.progression[key]..' recorded source events',i.progression[key],i.progression[key])
        end
        Add('deaths','Death history',#i.deaths..' recorded deaths; killer unknown',i.deaths,i.deaths)
        for n=#i.zoneOrder,1,-1 do local zone=i.zoneOrder[n];local visit=i.visits[zone]
            Add('zone:'..zone,zone,#visit.evidence..' recorded zone-entry observations',visit,visit.evidence)
        end
    else
        if mode=='time' then Add('total','Measured time','Unique recorded intervals; overlapping dimensions',i.time,i.timeEvidence) end
        if mode=='sessions' then
            for n=#i.scopes,1,-1 do local s=i.scopes[n];Add(s.id,'Recording segment: '..Stamp(s.firstAt),s.partialStart and 'Partial start' or s.endReason or 'Open segment',s,s.evidence) end
        end
        for _,kind in ipairs({'day','week','month'}) do
            if mode==kind then
                local keys=Keys(i.periods[kind]);for n=#keys,1,-1 do local key=keys[n];local label=key
                    if kind=='day' then label=UTC(tonumber(key)*86400)
                    elseif kind=='week' then label=UTC((tonumber(key)*7-3)*86400)..' (week beginning)' end
                    Add(kind..':'..key,kind..': '..label..' UTC',Duration(i.periods[kind][key].seconds),i.periods[kind][key],i.periodEvidence[kind][key])
                end
            end
        end
    end
    return rows
end
function U.Detail(st,mode,row)
    if not row or not st or not st.intelligence then return {{kind='title',text='Your recorded history, connected'},
        {kind='body',text='Choose a time summary, player, battleground segment, scoreboard observation or milestone. These views use existing evidence. They add no collectors, sharing or saved copies of incidents.'}} end
    local i=st.intelligence;local data=row.data;local b,Put=Blocks()
    if mode=='time' or mode=='sessions' or mode=='day' or mode=='week' or mode=='month' then return TimeDetail(row.id=='total' and i or nil,data.time or data,row.title) end
    Put('title',row.title)
    if mode=='players' then
        local p=I.Player(st,row.id);local a=A.Player(st,row.id)
        Put('heading',p.description);Put('body',row.id)
        Put('body',p.recordedEncounters..' distinct recorded local sighting episodes.\nFirst: '..Stamp(p.firstEncounter)..'\nLast: '..Stamp(p.lastEncounter))
        Put('body','An episode requires local visibility evidence and a recorded gap of at least 120 seconds since the last local observation. Rapid targeting and mouseover repeats do not add episodes. These counts are not fights or physical departures.')
        for _,zone in ipairs(Keys(p.zones)) do Put('body',zone..': '..p.zones[zone]..' recorded encounters') end
        Put('heading','Native credit evidence against this player')
        Put('body',p.credits.own..' own native credits; '..p.credits.pet..' pet-associated; '..p.credits.group..' group-associated; '..p.credits.unattributed..' unattributed.\n'..p.credits.incoming..' native actor/target reports naming this player against our character.')
        Put('body','Individual killing blows, deaths caused by this player and a head-to-head kill/death ratio: Unknown. Native credit alone does not establish solo victory or killer attribution. NPC credit is excluded here.')
        if p.legacyRecords then Put('body',p.legacyRecords..' legacy combat/credit records remain inspectable. They are not promoted into the new native-credit or killer counts.') end
        Put('heading','Roster relationships')
        Put('body','First roster observation: '..Stamp(p.firstRoster)..'\nLast roster observation: '..Stamp(p.lastRoster)..'\n'..a.groupSegments..' observed group segments; '..a.listedDungeonSegments..' dungeon segments; '..a.listedRaidSegments..' raid segments with a roster association.')
        Put('body',a.bossAttemptsWhileListed..' boss attempts with a roster association; '..a.successResultsWhileListed..' successful and '..a.failureResultsWhileListed..' unsuccessful results while listed. Confirmed individual participation, exact shared duration, DPS and HPS remain unknown. An unsuccessful result is not an attributed wipe.')
        Put('heading','Dated identity and community context')
        local facts=p.facts or {};for n=math.max(1,#facts-4),#facts do local e=facts[n];Put('body',Stamp(e.at)..': '..e.details.name..' | Class: '..(e.details.class or 'Unknown')..' | Guild: '..(e.details.guild or 'Unknown')) end
        Put('body',#p.scoreboards..' scoreboard observations, without guessed teammate/opponent classification. '..#p.publicReports..' dated public Olympus rows. These do not establish local encounters.')
        for n=math.max(1,#p.publicReports-2),#p.publicReports do local report=p.publicReports[n];local e=i.events[report.eventID];local v=report.row.values or {}
            Put('body',report.kind..' / '..Stamp(e.at)..' / '..report.mode..' / '..(v.name or row.id)..(v.bounty and ' / bounty '..v.bounty or '')..'. Source observation; not current Wanted status.') end
        Put('heading','Your annotations');Put('body',(p.watch and 'On your personal watchlist.' or 'Not on your personal watchlist.')..'\n'..(p.note or 'No personal note saved.'))
    elseif mode=='battlegrounds' then
        local measured=I.ActivityTime(st,data)
        Put('body','First observed: '..Stamp(data.startAt)..'\nLast evidence: '..Stamp(data.lastAt)..'\nStatus: '..data.status..'\nUnique measured time inside this visit: '..Duration(measured and measured>0 and measured or nil))
        Put('body','This is a battleground/arena visit segment, not a guaranteed unique or complete match. Reloads and entry/exit boundaries stay separate. Match outcome for our character: Unknown. Scoreboards are not attached using map name, nearby time or a reused sequence.')
        Put('heading','Native completion reports')
        if #data.pvpReports==0 then Put('body','No linked completion report. No result was invented.') end
        for _,id in ipairs(data.pvpReports) do local e=st.events[id];Put('body',Stamp(e.at)..' / winner code: '..tostring(e.details.winner or 'Unknown')..' / native reported duration: '..tostring(e.details.duration or 'Unknown')..' seconds. This is not observed duration or a personal win/loss.') end
    elseif mode=='scoreboards' then
        local v=data.capture.values;Put('accent',v.instanceName or 'Battleground observation');Put('meta',Stamp(data.at)..' • '..(v.phase or 'Observation phase not recorded'))
        Put('body','Observed scores • final-result freshness is unverified. Original source retains player GUID, local report identity and native fields.')
        if v.objectives then
            Put('heading','Battleground objectives')
            for _,objective in ipairs(v.objectives) do Put('body',(objective[4]~=false and objective[4] or objective[9]~=false and objective[9] or 'Native objective '..objective[1])..': '..(objective[2]~=false and tostring(objective[2]) or 'Unknown')) end
            Put('meta',(v.objectivesComplete and 'All reported objective rows were readable.' or 'Partial objective coverage.')..' Values belong to this dated scoreboard observation. They are separate from native cumulative statistics and are not summed across refreshes.')
        end
        local labels={killingBlows='Killing blows',honorableKills='Honorable kills',deaths='Deaths',honorGained='Honor gained',damageDone='Damage done',healingDone='Healing done',faction='Native faction code',classToken='Class'}
        for _,key in ipairs({'killingBlows','honorableKills','deaths','honorGained','damageDone','healingDone','classToken'}) do
            local value=key=='classToken' and ns.ChronicleStore.Text(v[key],64) or ns.ChronicleStore.Integer(v[key],0)
            Put('body',labels[key]..': '..tostring(value~=nil and value or 'Not recorded'))
        end
        Put('body','One dated scoreboard observation. Sequence values can be reused, so unique match identity and final-result status remain unknown. Updates are not summed into lifetime totals. Honor kills are distinct from killing blows. A listed GUID is not proof of physical contact.')
    elseif mode=='progress' then
        if row.id=='xp' then
            Put('body',i.progression.xpObserved..' XP in recorded positive-change events. This is not lifetime XP. Quest reward fields are not added again.')
            Put('body','XP/hour over fully measured, value-linked update windows: '..(i.progression.rateSeconds>0 and string.format('%.1f over %d measured seconds',i.progression.rateXP*3600/i.progression.rateSeconds,i.progression.rateSeconds) or 'Not recorded')..'. Gaps, unmatched baselines and first updates are excluded.')
        elseif row.id=='deaths' then
            Put('body',#i.deaths..' recorded death events. Killer identity and opponent-specific death totals: Unknown. Nearby players and scoreboard deaths do not identify a killer.')
            for _,zone in ipairs(Keys(i.deathZones)) do Put('body',zone..': '..i.deathZones[zone]) end
        elseif row.id:sub(1,5)=='zone:' then
            Put('body','First recorded entry: '..Stamp(data.firstAt)..'\nLast recorded entry: '..Stamp(data.lastAt)..'\nMeasured zone time: '..Duration(i.time.zones[data.zone]))
            Put('body','Recorded zone transitions only. First recorded visit does not establish first-ever discovery; gaps may hide other visits. Your own travel routes remain in Recorded Events / All recorded data.')
        end
        local refs=row.refs or {};Put('heading','Recent source records')
        for n=#refs,math.max(1,#refs-19),-1 do local e=i.events[refs[n]];if e then Put('body',Stamp(e.at)..' / '..ns.RecordingUI.Title(e)..' / '..e.source) end end
        if row.id=='levels' then
            for n=#i.cases,1,-1 do local c=i.cases[n]
                if c.event.kind=='level_change' then Put('body','Level '..c.event.details.after..': measured time since the previous recorded level: '..Duration(c.measuredBetween)..(c.measuredBetween and (c.completeCoverage and ' (complete measured window)' or ' (partial measured coverage)') or '')) end
                if #b>55 then break end
            end
        end
    end
    Put('body','These summaries describe retained evidence. Imported backups keep their original labels. Nothing here independently verifies a source. Choose original evidence below to inspect its timestamp, scope and details.')
    return b
end
function U.Build(parent,host)
    local p=CreateFrame('Frame',nil,parent);p:SetAllPoints(parent);p.owner=ns.Chronicle.Owner();p.mode='time';p.page=0
    p.status=V.Text(p,'Summaries of existing local evidence. Recording and sharing choices stay unchanged.',4,-5,1120,14,V.blue);p.status:SetHeight(38)
    local modes={{'time','Measured time'},{'sessions','Recording segments'},{'day','Recorded days (UTC)'},{'week','Recorded weeks (UTC)'},{'month','Recorded months (UTC)'},{'players','Players & relationships'},{'battlegrounds','Battleground / arena visits'},{'scoreboards','Scoreboard observations'},{'progress','Progress, deaths & exploration'}}
    p.modeMenu=V.Dropdown(p,0,-54,350,modes,function() return p.mode end,function(v) p.mode=v;p.page=0;p.selected=nil;p.dirty=true;p:Refresh(true) end,{maxRows=8})
    local characters={{false,'This character'}};for owner in pairs(ns.ChronicleStore.db and ns.ChronicleStore.db.characters or {}) do if owner~=p.owner then characters[#characters+1]={owner,owner} end end
    p.ownerMenu=V.Dropdown(p,362,-54,352,characters,function() return p.owner~=ns.Chronicle.Owner() and p.owner or false end,function(v) p.owner=v or ns.Chronicle.Owner();p.page=0;p.selected=nil;p.state=nil;p:Refresh(true) end,{maxRows=8})
    p.search=V.Edit(p,726,-54,268,32,'Search summaries...',function(value) p.searchText=value;p.page=0;p.selected=nil;p.dirty=true end)
    p.target=V.Button(p,'Target',1006,-54,130,32,function()
        local guid=ns.ChronicleStore.GUID(ns.SafeCall(UnitGUID,'target'))
        if guid then p.search:SetText('');p.mode='players';p.selected=guid;p.page=0;p.dirty=true;p:Refresh(true)
        else p.status:SetText('Target an identifiable recorded player first. No name-only identity was guessed.') end
    end,'neutral')
    local listPanel=V.Panel(p,0,-107,430,500,'dark');local detailPanel=V.Panel(p,444,-107,692,500,'paper')
    p.document,p.detailScroll=V.Document(detailPanel,16,-16,642,390);p.document:SetBlocks(U.Detail())
    p.list=V.ScrollingList(listPanel,12,-13,383,472,65,function(parentRow)
        local row=V.Button(parentRow,'',0,0,380,59,function(self) p.selected=self.item.id;p:ShowItem(self.item);p.list:Render() end,'row')
        row.icon=V.Icon(row,'recording',27,14,-16);row.selectedArt=V.Nine(row,'selected');row.selectedArt:SetShown(false)
        row.title=V.Text(row,'',51,-10,310,14,V.gold);row.title:SetHeight(18);row.title:SetWordWrap(false)
        row.sub=V.Text(row,'',51,-32,310,12,V.muted);row.sub:SetHeight(18);row.sub:SetWordWrap(false);return row
    end,function(row,item) row.item=item;row.title:SetText(item.title);row.sub:SetText(item.sub);row.selectedArt:SetShown(p.selected==item.id) end)
    p.sources={{false,'Choose original evidence'}}
    p.sourceMenu=V.Dropdown(p,460,-525,660,p.sources,function() return p.sourceID or false end,function(v) p.sourceID=v or nil end,{maxRows=8})
    p.openSource=V.Button(p,'Open source record',460,-568,250,28,function()
        local e=p.state and (p.state.intelligence.events[p.sourceID] or p.state.events[p.sourceID])
        if e then ns.RecordingUI.OpenSource(host,e) end
    end,'neutral')
    p.rebuild=V.Button(p,'Advanced: rebuild summaries',722,-568,250,28,function() A.Clear();p.state=nil;p:Refresh(true) end,'neutral')
    p.newer=V.Button(p,'Newer 50',0,-621,170,32,function() p.page=math.max(0,p.page-1);p.selected=nil;p:Refresh(true) end,'neutral')
    p.older=V.Button(p,'Older 50',182,-621,170,32,function() p.page=p.page+1;p.selected=nil;p:Refresh(true) end,'neutral')
    p.count=V.Text(p,'',369,-628,760,13,V.muted);p.count:SetHeight(20)
    function p:ShowItem(item)
        self.document:SetBlocks(U.Detail(self.state,self.mode,item));self.detailScroll:SetVerticalScroll(0)
        for n=#self.sources,2,-1 do self.sources[n]=nil end
        local refs=item and item.refs or {}
        for n=#refs,math.max(1,#refs-49),-1 do local id=refs[n];local e=self.state and (self.state.intelligence.events[id] or self.state.events[id]);if e then self.sources[#self.sources+1]={id,Stamp(e.at)..' | '..e.kind} end end
        self.sourceID=self.sources[2] and self.sources[2][1] or nil;self.sourceMenu:Refresh();self.openSource:SetEnabled(self.sourceID~=nil)
    end
    function p:Clear()
        self.state=nil;self.selected=nil;self.rows=nil;self.list:SetItems({});self:ShowItem(nil)
        if self.sourceMenu.Menu then self.sourceMenu.Menu:Hide() end
    end
    function p:Refresh(force)
        if InCombatLockdown and InCombatLockdown() then self.status:SetText('Summaries update after combat. Supported recording continues.');return end
        local st,state=A.Request(self.owner or ns.Chronicle.Owner())
        if not st then
            local done,total,stage=A.Progress();self.status:SetText(state=='blocked' and 'Saved history unavailable to this build; original data is preserved.' or (stage=='summaries' and 'Summarizing measured intervals and history' or 'Reading existing history')..': '..done..' / '..total..' records.')
            self:Clear();return
        end
        if not force and not self.dirty and self.state==st and self.revision==st.revision then return end
        self.state=st;self.revision=st.revision;self.dirty=nil;self.modeMenu:Refresh();self.ownerMenu:Refresh()
        self.rows=U.Rows(st,self.mode,self.guidFilter)
        if self.searchText and self.searchText~='' then
            local matching={};for _,row in ipairs(self.rows) do if (row.title..' '..row.sub..' '..row.id):lower():find(self.searchText:lower(),1,true) then matching[#matching+1]=row end end;self.rows=matching
        end
        -- Target navigation selects only an exact GUID already in this index.
        if self.selected then for n,row in ipairs(self.rows) do if row.id==self.selected then self.page=math.floor((n-1)/50);break end end end
        local shown={};local selected;local first=self.page*50+1
        for n=first,math.min(first+49,#self.rows) do local row=self.rows[n];shown[#shown+1]=row;if row.id==self.selected then selected=row end end
        if not selected then self.selected=nil end
        self.list:SetItems(shown,true);self.newer:SetEnabled(self.page>0);self.older:SetEnabled(first+49<#self.rows)
        self.count:SetText('Page '..(self.page+1)..' | '..#shown..' shown | '..#self.rows..' summaries')
        self.status:SetText(self.guidFilter and ('Scoreboard observations for '..A.Name(st,self.guidFilter)..' • '..self.guidFilter..'. Updates are not summed into unique matches.') or 'Recorded evidence only. Unknown outcomes and unmatched scoreboards remain explicit. No new collection or sharing.')
        self:ShowItem(selected)
    end
    return p
end
