-- First activity browser. Uses the same derived records as player-history queries.
local _,ns=...
local A,V,T=ns.ChronicleActivities,ns.Art,ns.Theme
local U={};ns.ChronicleActivitiesUI=U
local function Time(at)
    if not at then return 'unknown' end
    local ok,value=pcall(date or os.date,'%Y-%m-%d %H:%M:%S',at);return ok and value or tostring(at)
end
local labels={dungeon='Dungeon segment',raid='Raid segment',group='Group observations',boss='Boss result without instance entry',battleground='Battleground visit',arena='Arena visit'}
function U.Title(a) return (labels[a.kind] or a.kind)..' - '..(a.context.instanceName or a.context.zone or 'Unknown instance') end
function U.Detail(st,a,guid)
    local b={};local function Put(kind,text) b[#b+1]={kind=kind,text=text} end
    if guid then
        local p=A.Player(st,guid)
        Put('heading',A.Name(st,guid)..' - recorded group history')
        Put('body',p.listedDungeonSegments..' dungeon segments; '..p.listedRaidSegments..' raid segments with a roster association. '..p.successResultsWhileListed..' successful and '..p.failureResultsWhileListed..' failed boss results with that player listed in a saved roster. These are not confirmed individual attendance or player-caused outcomes.')
        Put('body','Confirmed boss participation, exact grouped time and matched DPS/HPS: unavailable. Native credit records: '..p.selfCredits..' own, '..p.petCredits..' pet, '..p.groupCredits..' group. These counts are not individual killing blows or lifetime totals.')
    end
    if not a then
        Put('title','Your shared adventures')
        Put('body','Choose a dungeon, raid or group segment. These views connect existing records; they do not need a damage meter or enable recording. Use the player selector or target a recorded player to see your group history together.')
        Put('heading','What the record can tell you')
        Put('body','A saved group list establishes roster membership at its observation time. It does not prove nearby presence, individual boss participation or a completed dungeon. Reloads and recording gaps remain separate segments.')
        Put('heading','Your original history stays intact')
        Put('body','Activity summaries are rebuilt locally from the original records. No new sharing or collectors are enabled. Old records without enough context remain unlinked or partial.')
        return b
    end
    Put('title',U.Title(a))
    Put('body','First observed: '..Time(a.startAt)..'\n'..(a.endAt and 'Observed end: '..Time(a.endAt) or 'Last linked evidence: '..Time(a.lastAt))..'\nStatus: '..a.status..' | Whole-instance completion: unknown')
    Put('meta','Activity: '..a.id..'\nRecording character: '..a.owner..'\nBoundary: '..a.startReason..(a.endReason and ' / '..a.endReason or ''))
    local measured=ns.ChronicleIntelligence.ActivityTime(st,a)
    Put('body',(measured and measured>0 and 'Unique measured world time inside this observed segment: '..math.floor(measured)..' seconds.' or 'Measured world time: unavailable; no eligible measured interval.')..' This is measured coverage within the observed context, not total run duration or exact time grouped with another player.')
    if a.pvpReports then
        Put('heading','Observed PvP visit')
        Put('body',#a.pvpReports..' native completion reports linked to this visit context. A visit does not establish a unique complete match. Personal win/loss and scoreboard assignment remain unknown. Recording > Intelligence shows the preserved scoreboard observations separately.')
    end
    Put('heading','Boss attempts and native results')
    if #a.attempts==0 then Put('body','No linked boss start or result records. This does not mean no bosses were attempted.') end
    for i,t in ipairs(a.attempts) do
        Put('heading',i..'. '..(t.name or 'Encounter '..t.encounterID)..' - '..t.outcome)
        Put('body','Start: '..Time(t.startAt)..' | End: '..Time(t.endAt)..'\nDifficulty ID: '..tostring(t.difficultyID or 'unknown')..' | Individual participation: unknown'..(t.interruption and '\nInterrupted: '..t.interruption or '')..(t.missingStart and '\nOnly a result was observed; no start was invented.' or ''))
        Put('meta','Source records: '..table.concat(t.evidence,', '))
    end
    Put('heading','Players associated through saved rosters')
    local people={};for player in pairs(a.members) do people[#people+1]=player end;table.sort(people)
    if #people==0 then Put('body','No identifiable companions in linked roster evidence.') end
    for _,player in ipairs(people) do Put('body',A.Name(st,player,a.lastAt)..'\n'..player) end
    Put('body','These names use historical observations at or before this segment. A GUID without a saved historical name stays a GUID. Later renames do not rewrite earlier names.')
    Put('heading','Roster evidence and boundaries')
    Put('body',#a.rosters..' saved roster observations. Lists may be partial; changes indicate who was or was no longer listed at a later observation, not an exact join or leave time. Roster updates deferred during combat cannot reconstruct attendance throughout a boss attempt.'..(a.carriedRoster and '\nIncludes a last-known roster from before this segment: '..a.carriedRoster..'. Its membership was not freshly verified at entry.' or ''))
    Put('heading','Performance and source records')
    Put('body','DPS, HPS, deaths, interrupts and dispels are not assigned to these attempts in this preview. Preserved meter results remain separate until native session-to-encounter matching is validated. Missing values are unknown, not zero. Choose a source record below to inspect the original evidence.')
    return b
end
function U.Build(parent,host)
    local p=CreateFrame('Frame',nil,parent);p:SetAllPoints(parent);p.filter={page=0};p.owner=ns.Chronicle.Owner()
    local status=V.Text(p,'Activities use existing history. Recording and your privacy choice stay unchanged.',4,-5,1120,14,V.blue);status:SetHeight(38);p.status=status
    V.Edit(p,0,-52,400,32,'Search activities, bosses or players...',function(value) p.filter.search=value;p.filter.page=0;p.dirty=true end)
    V.Dropdown(p,412,-52,272,{{false,'All activities'},{'dungeon','Dungeons'},{'raid','Raids'},{'group','Group observations'},{'battleground','Battleground visits'},{'arena','Arena visits'},{'boss','Unmatched boss context'}},function() return p.filter.kind or false end,function(value) p.filter.kind=value or nil;p.filter.page=0;p.dirty=true end)
    local characters={{false,'This character'}}
    for owner in pairs(ns.ChronicleStore.db and ns.ChronicleStore.db.characters or {}) do
        if owner~=p.owner then characters[#characters+1]={owner,owner} end
    end
    V.Dropdown(p,696,-52,440,characters,function() return p.owner~=ns.Chronicle.Owner() and p.owner or false end,function(value)
        p.owner=value or ns.Chronicle.Owner();p.selected=nil;p.state=nil;p.filter.guid=nil;p.filter.page=0;p.dirty=true
        p.list:SetItems({});p:ShowActivity(nil);p:Refresh(true)
    end,{maxRows=8})
    p.people={{false,'Player in selected activity'}}
    p.peopleMenu=V.Dropdown(p,0,-96,400,p.people,function()
        if p.selected then for _,choice in ipairs(p.people) do if choice[1]==p.filter.guid then return p.filter.guid end end end
        return false
    end,function(value) p.filter.guid=value or nil;p.filter.page=0;p.selected=nil;p.dirty=true end,{maxRows=8})
    p.target=V.Button(p,'Target history',412,-96,190,28,function()
        local guid=ns.ChronicleStore.GUID(ns.SafeCall(UnitGUID,'target'))
        if guid then p.filter.guid=guid;p.filter.page=0;p.selected=nil;p.dirty=true
        else status:SetText('Target an identifiable player first. No player was guessed from a name.') end
    end,'neutral')
    p.allPlayers=V.Button(p,'All players',614,-96,180,28,function() p.filter.guid=nil;p.selected=nil;p.filter.page=0;p.dirty=true end,'neutral')
    p.rebuild=V.Button(p,'Rebuild views',806,-96,190,28,function() A.Clear();p.dirty=true end,'neutral')
    T.Tooltip(p.rebuild,'Rebuild activities','Rebuild local summaries from original evidence. No saved records, consent, notes or settings change.')
    local listPanel=V.Panel(p,0,-139,430,468,'dark');local detailPanel=V.Panel(p,444,-139,692,468,'paper')
    p.document,p.detailScroll=V.Document(detailPanel,16,-16,642,360);p.document:SetBlocks(U.Detail())
    p.list=V.ScrollingList(listPanel,12,-13,383,440,65,function(parentRow)
        local row=V.Button(parentRow,'',0,0,380,59,function(self) p.selected=self.activity.id;p.sourcePage=0;p:ShowActivity(self.activity);p.list:Render() end,'row')
        row.icon=V.Icon(row,'recording',27,14,-16);row.selectedArt=V.Nine(row,'selected');row.selectedArt:SetShown(false)
        row.title=V.Text(row,'',51,-10,310,14,V.gold);row.title:SetHeight(18);row.title:SetWordWrap(false)
        row.sub=V.Text(row,'',51,-32,310,12,V.muted);row.sub:SetHeight(18);row.sub:SetWordWrap(false);return row
    end,function(row,a)
        row.activity=a;row.selectedArt:SetShown(p.selected==a.id);row.title:SetText(U.Title(a));row.sub:SetText(Time(a.startAt)..' | '..#a.attempts..' boss records | '..a.status)
    end)
    p.sources={{false,'Choose original evidence'}}
    p.sourceMenu=V.Dropdown(p,460,-526,660,p.sources,function() return p.sourceID or false end,function(value) p.sourceID=value or nil end,{maxRows=8})
    p.openSource=V.Button(p,'Open source record',460,-568,220,28,function()
        local e=p.state and p.state.events[p.sourceID]
        if e then
            host.filter={page=0,mode='all',search=e.id,kinds={[e.kind]=true},raw=true};host.rawCheck:SetChecked(true)
            host.search:SetText(e.id);host.debounce=nil;host.filter.eventID=e.id
            host:SetView('events');host.selected=e.id;host.detailDocument:SetBlocks(ns.RecordingUI.Detail(e));host.list:Render()
        end
    end,'neutral')
    p.previousSources=V.Button(p,'Earlier sources',692,-568,202,28,function() p.sourcePage=math.max(0,(p.sourcePage or 0)-1);p:Sources() end,'neutral')
    p.nextSources=V.Button(p,'More sources',906,-568,214,28,function() p.sourcePage=(p.sourcePage or 0)+1;p:Sources() end,'neutral')
    p.newer=V.Button(p,'Newer 50',0,-621,170,32,function() p.filter.page=math.max(0,p.filter.page-1);p.dirty=true end,'neutral')
    p.older=V.Button(p,'Older 50',182,-621,170,32,function() p.filter.page=p.filter.page+1;p.dirty=true end,'neutral')
    p.count=V.Text(p,'',369,-628,760,13,V.muted);p.count:SetHeight(20)
    function p:Sources()
        for i=#self.sources,2,-1 do self.sources[i]=nil end
        local a=self.state and self.state.byID[self.selected];local refs=a and a.evidence or {};local first=(self.sourcePage or 0)*50+1
        for i=first,math.min(first+49,#refs) do
            local e=self.state.events[refs[i]]
            if e then self.sources[#self.sources+1]={e.id,Time(e.at)..' | '..e.kind..' | '..e.source} end
        end
        self.sourceID=self.sources[2] and self.sources[2][1] or nil;self.sourceMenu:Refresh()
        self.previousSources:SetEnabled((self.sourcePage or 0)>0);self.nextSources:SetEnabled(first+49<#refs);self.openSource:SetEnabled(self.sourceID~=nil)
    end
    function p:ShowActivity(a)
        self.document:SetBlocks(U.Detail(self.state,a,self.state and self.filter.guid));self.detailScroll:SetVerticalScroll(0)
        for i=#self.people,2,-1 do self.people[i]=nil end
        if a then
            local sorted={};for guid in pairs(a.members) do sorted[#sorted+1]=guid end;table.sort(sorted)
            for _,guid in ipairs(sorted) do self.people[#self.people+1]={guid,A.Name(self.state,guid,a.lastAt)} end
        else
            self.selected=nil;self.sourceID=nil;self.sourcePage=0
            if self.peopleMenu.Menu then self.peopleMenu.Menu:Hide() end
            if self.sourceMenu.Menu then self.sourceMenu.Menu:Hide() end
        end
        self.peopleMenu:Refresh();self:Sources()
    end
    function p:Refresh(force)
        if InCombatLockdown and InCombatLockdown() then self.status:SetText('Activity views update after combat. Supported recording continues.');return end
        local st,state=A.Request(self.owner or ns.Chronicle.Owner())
        if not st then
            local done,total=A.Progress()
            self.status:SetText(state=='blocked' and 'This saved history is unavailable to this build. Its original data is preserved; no activities were guessed.' or 'Organizing existing history: '..done..' / '..total..' records. Your original records stay intact.')
            if state=='blocked' then self.state=nil;self.selected=nil;self.list:SetItems({});self:ShowActivity(nil) end
            return
        end
        if not force and not self.dirty and self.state==st and self.revision==st.revision then return end
        self.state=st;self.revision=st.revision;self.dirty=nil
        local f={kind=self.filter.kind,guid=self.filter.guid,search=self.filter.search,limit=(self.filter.page+1)*50+1}
        local found=A.Query(st,f);local shown={};local first=self.filter.page*50+1
        for i=first,math.min(first+49,#found) do shown[#shown+1]=found[i] end
        self.list:SetItems(shown,true);self.newer:SetEnabled(self.filter.page>0);self.older:SetEnabled(#found>=first+50)
        self.count:SetText('Page '..(self.filter.page+1)..' | '..#shown..' shown | '..#st.activities..' activity segments | '..st.processed..' source records indexed')
        self.status:SetText(self.filter.guid and 'Player: '..A.Name(st,self.filter.guid)..'. Roster associations are separate from confirmed boss attendance.' or 'Existing local evidence only. Segments may be interrupted; instance exit never means completion.')
        local selected
        for _,a in ipairs(shown) do if a.id==self.selected then selected=a;break end end
        if not selected then self.selected=nil end
        self:ShowActivity(selected)
    end
    return p
end
