local _,ns=...
local H={};ns.WardenHomeUI=H
local V,A,Q=ns.Art,ns.ChronicleActivities,ns.WardenSearch
local Safe=ns.WardenBrand.Text
function H.Build(parent)
    local W=ns.Workspace;local p=CreateFrame('Frame',nil,parent);p:SetAllPoints(parent);p:Hide()
    local hero=V.Panel(p,0,0,1136,96,'header');local crest=V.Texture(hero,'Warden',{0,0,512,512});crest:SetPoint('TOPLEFT',14,-14);crest:SetSize(68,68)
    p.heroTitle=V.Text(hero,'Warden overview',92,-16,990,25,V.gold);p.heroTitle:SetHeight(30);p.heroTitle:SetWordWrap(false);p.heroTitle:SetJustifyV('TOP')
    p.heroSummary=V.Text(hero,'Your Warden overview',92,-54,990,14,V.muted);p.heroSummary:SetHeight(22);p.heroSummary:SetWordWrap(false);p.heroSummary:SetJustifyV('TOP')
    p.search=V.Edit(p,0,-112,960,36,'Search names, places, events and chat across Warden...',function() p.pending=true end);p.search:SetMaxLetters(160)
    p.search:SetScript('OnEnterPressed',function() p:Search() end)
    V.Button(p,'Search all',974,-112,162,36,function() p:Search() end,'button')
    p.cards={}
    for n,label in ipairs({'Measured recorded time','Retained player profiles','Recorded quest turn-ins','Recorded activities'}) do
        local c=V.Panel(p,(n-1)*287,-234,275,74,'minimal');c.label=V.Text(c,label,14,-11,247,13,V.muted);c.value=V.Text(c,'Reading...',14,-33,247,22,V.gold);p.cards[n]=c
        c.action=CreateFrame('Button',nil,c);c.action:SetAllPoints(c)
        c.action:SetScript('OnClick',function() if type(c.destination)=='function' then c.destination() elseif c.destination then W.Open(c.destination) end end)
    end
    p.states={};p.stateLabels={};for n,label in ipairs({'Protection','Adventure recording','Capture or support','Olympus connection'}) do
        local box=V.Panel(p,(n-1)*287,-164,275,58,'dark');p.stateLabels[n]=V.Text(box,label,14,-7,247,12,V.muted);p.states[n]=V.Text(box,'',14,-29,247,15,V.gold)
    end
    p.states[2]:ClearAllPoints();p.states[2]:SetPoint('TOPLEFT',14,-25);p.states[2]:SetHeight(31)
    if not ns.Theme.DocumentFont(p.states[2],13) then local path=p.states[2]:GetFont();p.states[2]:SetFont(path,13,'') end
    p.label=V.Text(p,'Recent highlights',4,-324,1128,17,V.gold)
    p.label:SetHeight(24);p.label:SetWordWrap(false)
    local panel=V.Panel(p,0,-354,1136,262,'dark')
    local function FitHighlights(count)
        local height=math.min(262,math.max(100,count*58+28));panel:SetHeight(height);p.list:Resize(1087,height-28)
        p.status:ClearAllPoints();p.status:SetPoint('TOPLEFT',4,-354-height-14)
    end
    p.list=V.ScrollingList(panel,14,-14,1087,232,58,function(host)
        local row=V.Button(host,'',0,0,1084,52,function(self) Q.Open(self.item) end,'row')
        row.icon=V.Icon(row,'overview',42,8,-5);row.title=V.Text(row,'',60,-7,994,14,V.gold);row.title:SetHeight(20);row.title:SetWordWrap(false)
        row.sub=V.Text(row,'',60,-30,994,11,V.muted);row.sub:SetHeight(18);row.sub:SetWordWrap(false);return row
    end,function(row,item)
        row.item=item;row.title:SetText(Safe(item.title));row.sub:SetText(Safe(item.group..' | '..item.sub))
        V.SetIcon(row.icon,item.icon or 'event:messages')
    end)
    p.list.scroll.ChatWardenHideWhenFit=true
    p.status=V.Text(p,'',4,-630,1120,12,V.muted);p.status:SetHeight(42)
    local function EmptyHighlight(rows)
        if #rows>0 then return end
        local enabled=ns.Modules.Enabled('history');local saved=ns.ChronicleStore.db
        local consent=saved and saved.enabled and saved.consentVersion==ns.ChronicleStore.CONSENT
        rows[1]={id='ready',icon='overview',group='CommandWarden',
            title=enabled and (consent and 'Your next milestone will appear here' or 'Start preserving your adventure') or 'Your Warden control center',
            sub=enabled and (consent and 'Browse retained events or check collection status in Data & Backups.' or 'Review recording, privacy and backup choices in Data & Backups. Nothing starts without your consent.') or 'Choose modules, change settings or open Relay support.',
            data={page=enabled and 'recording' or 'modules'}}
    end
    function p:Search()
        local text=self.search:GetText();self.job=Q.Begin(text);self.pending=nil;self.status:SetText('Searching saved data on this computer...')
        self.resultCount=0;self.searchDraw=0;self.resultDone=false
        FitHighlights(#self.job.results)
        self.list:SetItems(self.job.results);self.label:SetText(self.job.query=='' and 'Recent highlights' or 'Search results • '..Safe(text))
        if self.job.query=='' then self.job=nil;self:Refresh(true) end
    end
    function p:Activate()
        W.CommandTabs('overview')
        if self.searchNeedsRefresh then self.searchNeedsRefresh=nil;self:Search() end;self:Refresh(true)
    end
    function p:Refresh(force)
        if InCombatLockdown and InCombatLockdown() then return end
        local own=ns.OlympusConnection.Profile();local class,token=ns.WardenBrand.Values(UnitClass,'player');class=class~='' and class or token;local level=ns.SafeNumber(ns.SafeCall(UnitLevel,'player'))
        self.heroTitle:SetText(Safe(own and own.name or ns.SafeCall(UnitName,'player') or 'Warden overview'))
        local summary={};for _,v in ipairs({class or '',level and level>0 and 'Level '..level or '',own and own.guild or ''}) do if v~='' then summary[#summary+1]=v end end
        self.heroSummary:SetText(Safe(table.concat(summary,' • ')))
        local M=ns.Modules;local metrics={}
        local function Metric(label,value,dest) metrics[#metrics+1]={label,value,dest} end
        local st,state
        if ns.Modules.Enabled('history') then st,state=A.Request(ns.Chronicle.Owner()) else state='disabled' end
        if st and (force or self.revision~=st.revision) then
            self.revision=st.revision
            if not self.job then
                local rows={};if ns.Modules.Enabled('chronicle') then for n,row in ipairs(ns.WardenUI.Highlights(st)) do if n>30 then break end;rows[#rows+1]={id=row.id,title=row.title,sub=row.sub,icon=row.icon,group='ChronicleWarden',data={event=row.event,highlight=row.id,owner=st.owner,page='chronicle'}} end end
                for _,entry in ipairs(ns.Activity.List()) do if #rows>=30 then break end
                    local c=entry.categories or {};local owner=c.shield and 'shield' or (c.mentions or c.wanted or c.olympusmute) and 'alerts' or 'chat'
                    if M.Enabled(owner) then rows[#rows+1]={id=entry.id,title=ns.Activity.DisplayName(entry.sender),sub=ns.Activity.EventLabel(entry)..' • '..ns.WardenUI.Stamp(entry.timestamp),group=M.names[owner],icon=ns.EventIcons.Chat(entry),data={activity=entry,page=owner=='shield' and 'shield' or owner=='alerts' and 'mentions' or 'messages'}} end
                end
                local hasHighlights=#rows>0;EmptyHighlight(rows)
                FitHighlights(#rows);self.list:SetItems(rows,true);self.status:SetText(not ns.Modules.Enabled('chronicle') and 'Player dossiers are available in IntelWarden. Chronicle is off; its saved history is kept.' or hasHighlights and 'Your latest recorded milestones. Open Chronicle to explore more, or Recent activity for chat and protection.' or 'No highlights yet. Open Data & Backups to review recording and retained events.')
            end
        elseif not st and not self.job then
            local rows={};for _,entry in ipairs(ns.Activity.List()) do if #rows>=30 then break end;local c=entry.categories or {};local owner=c.shield and 'shield' or (c.mentions or c.wanted or c.olympusmute) and 'alerts' or 'chat';if M.Enabled(owner) then rows[#rows+1]={id=entry.id,title=ns.Activity.DisplayName(entry.sender),sub=ns.Activity.EventLabel(entry)..' • '..ns.WardenUI.Stamp(entry.timestamp),group=M.names[owner],icon=ns.EventIcons.Chat(entry),data={activity=entry,page=owner=='shield' and 'shield' or owner=='alerts' and 'mentions' or 'messages'}} end end
            EmptyHighlight(rows)
            FitHighlights(#rows);self.list:SetItems(rows,true)
            local done,total=A.Progress();self.status:SetText(state=='disabled' and 'Only selected features are running. Explore more in Modules; your existing history stays preserved.' or state=='blocked' and 'Saved history is preserved but unavailable to this build.' or 'Reading retained evidence: '..done..' / '..total)
        end
        if st then local i=st.intelligence;if M.Enabled('chronicle') and i then Metric('Measured recorded time',i.time.seconds>0 and string.format('%.1f hours',i.time.seconds/3600) or 'Not recorded','chronicle');Metric('Recorded activities',tostring(#st.activities),'chronicle') end;if M.Enabled('intel') then Metric('Remembered players',tostring(ns.WardenUI.PlayerStats(st).profiles),'intel') end end
        if not st then
            if M.Enabled('chronicle') then Metric('Recorded adventure',ns.ChronicleStore.loading and 'Loading history' or 'Organizing history','chronicle') end
            if M.Enabled('intel') then Metric('Remembered players',ns.ChronicleStore.loading and 'Loading history' or 'Organizing profiles','intel') end
        end
        if M.Enabled('chat') then Metric('Recent chat activity',tostring(#ns.Activity.List('messages')),'messages') end
        if M.Enabled('shield') then Metric('Shielded contacts',tostring(#ns.Shield.List()),'shield') end
        if M.Enabled('alerts') then Metric('Unread signals',tostring(ns.Activity.Unread('alerts')),'mentions') end
        if M.Enabled('chat') then
            Metric('Saved chat lines',tostring(#ns.ChatCapture.db.entries),'capture')
            Metric('Personal chat rules',tostring(#ns.Personal.rules),'rules')
            Metric('Spelling assistance',ns.Spelling.Active() and 'Enabled' or 'Paused',function() W.SettingsSub('spelling') end)
        end
        if #metrics==0 then Metric('Support','Ready','relay');Metric('Module selection','Available','modules') end
        for n,card in ipairs(self.cards) do local m=metrics[n];card:SetShown(m~=nil);if m then card.label:SetText(m[1]);card.value:SetText(m[2]);card.destination=m[3];card.action:SetEnabled(true) end end
        local protection={};if M.Selected('chat') then protection[#protection+1]=ns.Active('chat') and 'Filtering on' or 'Filtering paused' end;if M.Selected('shield') then protection[#protection+1]=ns.Active('shield') and 'Shield on' or 'Shield paused' end
        self.states[1]:SetText(#protection>0 and table.concat(protection,' • ') or 'Local support ready')
        local count=0;for _,id in ipairs(M.order) do if M.Enabled(id) then count=count+1 end end
        local health=ns.Athena.GetHealth('command')
        self.heroSummary:SetText(Safe(table.concat(summary,' • ')..' • '..count..' optional modules running'..(health and (health.errors>0 and ' • Athena needs attention' or ' • Athena ready') or '')))
        local store=ns.ChronicleStore;local saved=store.db
        self.states[2]:SetText(not M.Enabled('history') and 'History modules off • data kept'
            or store.loading and (ns.Chronicle.InWorld() and 'Recording • history loading' or 'Loading saved history')
            or store.blocked and (ns.Chronicle.InWorld() and 'Recording • history needs recovery' or 'Unavailable • saved history kept')
            or saved and saved.needsConsentUpgrade and 'Off — review recording consent'
            or (not saved or saved.consentVersion~=store.CONSENT) and 'Off — opt in to start'
            or not saved.enabled and 'Off — history kept'
            or ns.Chronicle.Active() and 'Recording'
            or 'Paused • history kept')
        self.stateLabels[3]:SetText(M.Enabled('chat') and 'Chat capture' or 'Relay delivery')
        self.states[3]:SetText(not M.Enabled('chat') and 'Only after Submit' or ns.ChatCapture.db.enabled and ns.Membership.allowed and 'Active' or 'Paused')
        self.states[4]:SetText(ns.OlympusConnection.state=='connected' and 'Connected' or ns.OlympusConnection.StatusText())
    end
    p:SetScript('OnUpdate',function(self,elapsed)
        if self.job and not self.job.done then
            Q.Pump(self.job)
            if self.resultCount~=#self.job.results or self.resultDone~=self.job.done then
                self.resultCount=#self.job.results;self.resultDone=self.job.done;FitHighlights(#self.job.results);self.list:SetItems(self.job.results,true)
            end
            self.searchDraw=(self.searchDraw or 0)+elapsed
            if self.searchDraw>=.2 or self.job.done then
                self.searchDraw=0;local groups={};for label,count in pairs(self.job.matches) do groups[#groups+1]=label..': '..count end;table.sort(groups)
                self.status:SetText((self.job.error or self.job.stale and 'History changed. Search again for current results.' or self.job.done and 'Search complete.' or 'Searching... '..self.job.processed..' records checked.')..' '..table.concat(groups,' | ')..' • Up to 30 results per group.\nSearch includes saved metadata and chat. Equipment contents and raw snapshot fields are not indexed. Hidden chat opens through its original view.')
            end
        end
        self.tick=(self.tick or 0)+elapsed;if self.tick>=.5 then self.tick=0;self:Refresh() end
    end)
    p:HookScript('OnHide',function(self)
        self.searchNeedsRefresh=self.job and self.job.query~='' or nil
        self.job=nil;self.revision=nil;self.list:SetItems({})
    end)
    return p
end
