local _,ns=...
local A,V=ns.Athena,ns.Art
local U={};ns.AthenaTimelineUI=U
local function Stamp(at) return ns.SafeCall(date,'%Y-%m-%d %H:%M',at) or tostring(at or 'Not recorded') end
function U.Build(parent,host)
    local p=CreateFrame('Frame',nil,parent);p:SetAllPoints(parent);p:Hide();p.cursors={false};p.page=1
    V.Text(p,'My Timeline',18,-12,1090,25,V.gold)
    p.subtitle=V.Text(p,'Journey selects events. All history and Guild history link the original sources.',18,-53,680,14,V.muted)
    p.mode='journey'
    local function Mode(mode) p.mode=mode;p.page=1;p.cursors={false};p:Refresh(true) end
    V.Button(p,'Journey',450,-8,150,32,function() Mode('journey') end,'neutral')
    V.Button(p,'All history',614,-8,150,32,function() Mode('all') end,'neutral')
    V.Button(p,'Guild history',778,-8,150,32,function() Mode('guild') end,'neutral')
    V.Button(p,'My Combat',942,-8,158,32,function() Mode('combat') end,'neutral')
    p.search=V.Edit(p,720,-48,380,30,'Search all or guild history…',function(value)
        p.query=value;if p.mode=='journey' and value~='' then p.mode='all' end
        p.page=1;p.cursors={false};p:Refresh(true)
    end)
    p.list=V.ScrollingList(p,18,-88,1085,444,70,function(list)
        local row=V.Button(list,'',0,0,1080,64,function(self)
            if self.item then ns.RecordingUI.OpenSource(host,self.item.event) end
        end,'row')
        row.icon=V.Icon(row,'chronicle',46,10,-8);row.title=V.Text(row,'',70,-7,980,16,V.gold)
        row.sub=V.Text(row,'',70,-35,980,12,V.muted);row.title:SetHeight(24);row.sub:SetHeight(20);return row
    end,function(row,item)
        row.item=item;row.title:SetText(item.title:gsub('_',' '));row.sub:SetText(Stamp(item.occurredAt)..' • '..(item.association or item.zone or 'Location not recorded')..' • '..item.source)
        V.SetIcon(row.icon,ns.EventIcons.Record(item.event))
    end)
    p.status=V.Text(p,'Reading retained milestones…',18,-550,1090,13,V.muted)
    p.combatSummary=V.Text(p,'',18,-84,1085,13,V.muted);p.combatSummary:SetHeight(72);p.combatSummary:Hide()
    p.newer=V.Button(p,'Newer',18,-590,210,34,function() p.page=math.max(1,p.page-1);p:Refresh(true) end,'neutral')
    p.older=V.Button(p,'Older / continue reading',244,-590,300,34,function()
        if p.nextCursor then p.page=p.page+1;p.cursors[p.page]=p.nextCursor;p:Refresh(true) end
    end,'neutral')
    V.Button(p,'Full source history',730,-590,360,34,function() ns.Workspace.Open('recording') end,'neutral')
    V.HistoryUpdateButton(p,556,-590,160)
    function p:Refresh(force)
        local owner=host.owner or ns.Chronicle.Owner();local c=ns.ChronicleStore.Character(owner,false)
        if self.owner~=owner then self.owner=owner;self.page=1;self.cursors={false};force=true end
        if not self.combatIndexing and V.HoldHistoryView(self,owner,self.mode..'/'..self.page..'/'..(self.query or ''),force) then return end
        if not force and self.revision==(c and c.revision) and not self.combatIndexing then return end
        self.combatSummary:SetShown(self.mode=='combat')
        self.list.scroll:ClearAllPoints();self.list.scroll:SetPoint('TOPLEFT',18,self.mode=='combat' and -168 or -88)
        self.list:Resize(1085,self.mode=='combat' and 364 or 444)
        self.combatIndexing=false
        if self.mode=='combat' then
            local summary,state=A.GetMyCombat('chronicle',owner)
            if summary then
                self.combatIndexing=state=='INDEXING'
                self.combatSummary:SetText('Confirmed own spells: '..ns.AthenaCombatQueries.Top(summary.castSpells,3)
                    ..'\nEffects present/applied on you: '..ns.AthenaCombatQueries.Top(summary.effects,3)
                    ..'\n'..(summary.pairedWindows>0 and summary.pairedWindows..' paired windows • '..math.floor(summary.measuredSeconds)..' measured seconds' or 'No paired window recorded; combat duration unknown')
                    ..' • '..(summary.complete and 'last source '..(summary.lastAt and Stamp(summary.lastAt) or 'not recorded') or 'reading '..summary.scanned..' / '..summary.total..' sources')
                    ..'\n'..ns.AthenaCombatQueries.MeterLine(summary)..' • samples only; gaps unknown')
            else self.combatSummary:SetText('Combat evidence is not available yet. Prior activity is unknown.') end
        end
        local rows,nextCursor
        if self.mode=='combat' then rows,nextCursor=A.GetCombatHistory('chronicle',owner,nil,self.cursors[self.page] or nil,{limit=12,search=self.query})
        elseif self.mode=='journey' then rows,nextCursor=A.GetCharacterTimeline('chronicle',owner,self.cursors[self.page] or nil,12)
        else
            local query=self.mode=='guild' and A.GetGuildHistory or A.GetCharacterHistory
            rows,nextCursor=query('chronicle',owner,self.cursors[self.page] or nil,{limit=12,search=self.query})
        end
        if not rows then
            if nextCursor=='CURSOR_STALE' then self.page=1;self.cursors={false};self.revision=nil;self.status:SetText('History order changed; restarting from the newest page.');return end
            self.status:SetText('Validating requested history. Existing evidence is kept.');return
        end
        self.revision=c and c.revision;self.nextCursor=nextCursor;self.list:SetItems(rows,true);self.dirty=nil
        if not self.combatIndexing then V.CommitHistoryView(self,owner,self.mode..'/'..self.page..'/'..(self.query or '')) end
        self.newer:SetEnabled(self.page>1);self.older:SetEnabled(nextCursor~=nil)
        self.status:SetText(#rows>0 and 'Page '..self.page..' • '..#rows..' character events • select one for original evidence'
            or nextCursor and 'No character events in this section. Continue to older history.' or 'No character events recorded yet. Detailed observations remain in Full source history.')
    end
    local elapsed=0;p:SetScript('OnUpdate',function(self,dt) elapsed=elapsed+dt;if elapsed>=.5 then elapsed=0;self:Refresh() end end)
    p:HookScript('OnHide',function(self) self.historyView=nil;self.list:SetItems({});self.revision=nil;ns.AthenaCombatQueries.Release(self.owner) end)
    return p
end
