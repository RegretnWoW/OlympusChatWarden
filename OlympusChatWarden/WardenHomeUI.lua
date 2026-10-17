local _,ns=...
local H={};ns.WardenHomeUI=H
local V,A,Q=ns.Art,ns.ChronicleActivities,ns.WardenSearch
local Safe=ns.WardenBrand.Text
function H.Build(parent)
    local W=ns.Workspace;local p=CreateFrame('Frame',nil,parent);p:SetAllPoints(parent);p:Hide()
    local hero=V.Panel(p,0,0,1136,96,'header');local crest=V.Texture(hero,'Warden',{0,0,512,512});crest:SetPoint('TOPLEFT',14,-14);crest:SetSize(68,68)
    p.heroTitle=V.Text(hero,'Warden overview',92,-16,990,25,V.gold);p.heroTitle:SetHeight(30);p.heroTitle:SetWordWrap(false);p.heroTitle:SetJustifyV('TOP')
    p.heroSummary=V.Text(hero,'Your Warden overview',92,-54,990,14,V.muted);p.heroSummary:SetHeight(22);p.heroSummary:SetWordWrap(false);p.heroSummary:SetJustifyV('TOP')
    p.heroTitle:SetWidth(620);p.heroSummary:SetWidth(620)
    p.chronicle=V.Button(hero,'Open Chronicle',744,-31,182,34,function() W.Open('chronicle') end,'button')
    p.intel=V.Button(hero,'Player dossiers',938,-31,182,34,function() W.Open('intel') end,'neutral')
    p.search=V.Edit(p,0,-112,960,36,'Search names, places, events and chat across Warden...',function() p.pending=true end);p.search:SetMaxLetters(160)
    p.search:SetScript('OnEnterPressed',function() p:Search() end)
    V.Button(p,'Search all',974,-112,162,36,function() p:Search() end,'button')
    p.cards={}
    for n,label in ipairs({'Measured recorded time','Retained player profiles','Recorded quest turn-ins','Recorded activities'}) do
        local c=V.Panel(p,(n-1)*287,-234,275,74,'minimal');c.label=V.Text(c,label,14,-11,247,13,V.muted);c.value=V.Text(c,'Reading...',14,-33,247,22,V.gold);p.cards[n]=c
        c.action=CreateFrame('Button',nil,c);c.action:SetAllPoints(c)
        c.action:SetScript('OnClick',function() W.Open(n==2 and 'intel' or 'chronicle');if n==4 then W.pages.chronicle.mode='activities';W.pages.chronicle:Activate() end end)
        ns.Theme.Tooltip(c.action,label,n==2 and 'Open your recorded player directory.' or n==4 and 'Open your recorded shared adventures.' or 'Open your personal Chronicle.')
    end
    p.states={};for n,label in ipairs({'Chat protection','Chronicle recording','Chat capture','Olympus connection'}) do
        local box=V.Panel(p,(n-1)*287,-164,275,58,'dark');V.Text(box,label,14,-7,247,12,V.muted);p.states[n]=V.Text(box,'',14,-29,247,15,V.gold)
    end
    p.label=V.Text(p,'Recent highlights',4,-324,1128,17,V.gold)
    p.label:SetHeight(24);p.label:SetWordWrap(false)
    local panel=V.Panel(p,0,-354,1136,262,'dark')
    local function FitHighlights(count)
        local height=math.min(262,math.max(100,count*58+28));panel:SetHeight(height);p.list:Resize(1087,height-28)
        p.status:ClearAllPoints();p.status:SetPoint('TOPLEFT',4,-354-height-14)
    end
    p.list=V.ScrollingList(panel,14,-14,1087,232,58,function(host)
        local row=V.Button(host,'',0,0,1084,52,function(self) Q.Open(self.item) end,'row')
        row.icon=V.Icon(row,'overview',32,12,-10);row.title=V.Text(row,'',54,-7,1000,14,V.gold);row.title:SetHeight(20);row.title:SetWordWrap(false)
        row.sub=V.Text(row,'',54,-30,1000,11,V.muted);row.sub:SetHeight(18);row.sub:SetWordWrap(false);return row
    end,function(row,item)
        row.item=item;row.title:SetText(Safe(item.title));row.sub:SetText(Safe(item.group..' | '..item.sub))
        V.SetIcon(row.icon,item.icon or ({IntelWarden='intel',SignalWarden='mentions',ShieldWarden='shield',ChatWarden='messages',ChronicleWarden='chronicle'})[item.group] or 'overview')
    end)
    p.list.scroll.ChatWardenHideWhenFit=true
    p.status=V.Text(p,'',4,-630,1120,12,V.muted);p.status:SetHeight(42)
    function p:Search()
        local text=self.search:GetText();self.job=Q.Begin(text);self.pending=nil;self.status:SetText('Searching saved data on this computer...')
        self.resultCount=0;self.searchDraw=0;self.resultDone=false
        FitHighlights(#self.job.results)
        self.list:SetItems(self.job.results);self.label:SetText(self.job.query=='' and 'Recent highlights' or 'Search results • '..Safe(text))
        if self.job.query=='' then self.job=nil;self:Refresh(true) end
    end
    function p:Activate()
        W.Tabs({{'home','Home',function() W.Open('overview') end,210},{'activity','Recent activity',function() W.Open('activity') end,210}},'home')
        if self.searchNeedsRefresh then self.searchNeedsRefresh=nil;self:Search() end;self:Refresh(true)
    end
    function p:Refresh(force)
        if InCombatLockdown and InCombatLockdown() then return end
        local own=ns.OlympusConnection.Profile();local class,token=ns.WardenBrand.Values(UnitClass,'player');class=class~='' and class or token;local level=ns.SafeNumber(ns.SafeCall(UnitLevel,'player'))
        self.heroTitle:SetText(Safe(own and own.name or ns.SafeCall(UnitName,'player') or 'Warden overview'))
        local summary={};for _,v in ipairs({class or '',level and level>0 and 'Level '..level or '',own and own.guild or ''}) do if v~='' then summary[#summary+1]=v end end
        self.heroSummary:SetText(Safe(table.concat(summary,' • ')))
        local st,state=A.Request(ns.Chronicle.Owner())
        if st and (force or self.revision~=st.revision) then
            self.revision=st.revision;local i=st.intelligence or ns.ChronicleIntelligence.New(st.owner)
            self.cards[1].value:SetText(i.time.seconds>0 and string.format('%.1f hours',i.time.seconds/3600) or 'Not recorded')
            self.cards[2].value:SetText(tostring(ns.WardenUI.PlayerStats(st).profiles));self.cards[3].value:SetText(tostring(#i.progression.quests));self.cards[4].value:SetText(tostring(#st.activities))
            if not self.job then
                local rows={};for n,row in ipairs(ns.WardenUI.Highlights(st)) do if n>30 then break end;rows[#rows+1]={id=row.id,title=row.title,sub=row.sub,icon=row.icon,group='ChronicleWarden',data={event=row.event,highlight=row.id,owner=st.owner,page='chronicle'}} end
                FitHighlights(#rows);self.list:SetItems(rows,true);self.status:SetText(#rows>0 and 'Your latest recorded milestones. Open Chronicle to explore more, or Recent activity for chat and protection.' or 'Your journal is ready. Opt in through Data & Backups when you want to start preserving your adventure.')
            end
        elseif not st and not self.job then
            local done,total=A.Progress();self.status:SetText(state=='blocked' and 'Saved history is preserved but unavailable to this build.' or 'Reading retained evidence: '..done..' / '..total)
        end
        self.states[1]:SetText((ns.Active('chat') and 'Filtering on' or 'Filtering off')..' • '..(ns.Active('shield') and 'Shield on' or 'Shield off'))
        self.states[2]:SetText(ns.ChronicleStore.loading and 'Loading saved history' or ns.Chronicle.Active() and 'Recording' or 'Paused • history kept')
        self.states[3]:SetText(ns.ChatCapture.db.enabled and ns.Membership.allowed and 'Active' or 'Paused')
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
                self.status:SetText((self.job.stale and 'History changed. Search again for current results.' or self.job.done and 'Search complete.' or 'Searching... '..self.job.processed..' records checked.')..' '..table.concat(groups,' | ')..' • Up to 30 results per group.\nSearch includes saved metadata and chat. Equipment contents and raw snapshot fields are not indexed. Hidden chat opens through its original view.')
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
