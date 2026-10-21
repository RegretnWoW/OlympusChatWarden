local _,ns=...
local J,V=ns.AthenaJournal,ns.Art
local U={};ns.AthenaJournalUI=U
local function Stamp(at) return ns.SafeCall(date,'%Y-%m-%d',at) or tostring(at or 'Date unknown') end
-- Explicit soft paragraph breaks also keep offline widget renders readable.
local function Wrap(text)
    local lines,line={},''
    for word in text:gmatch('%S+') do if #line+#word+1>84 then lines[#lines+1]=line;line=word else line=line=='' and word or line..' '..word end end
    lines[#lines+1]=line;return table.concat(lines,'\n')
end
local messages={DENIED='Chronicle access is unavailable. Story pages have been cleared.',COMBAT_WAIT='Story analysis resumes after combat.',
    INDEXING='Reading permitted history…',LOAD_WAIT='Waiting for saved history validation…',LINK_PENDING='Waiting for source links…',
    building='Building the existing history index…',loading='Validating saved history…',pending='Waiting for permitted history…',
    CURSOR_STALE='History changed during reading. Use Refresh chapters to try again.',UNAVAILABLE='A source is unavailable. No chapter has been invented.'}
function U.Build(parent,host)
    local p=CreateFrame('Frame',nil,parent);p:SetAllPoints(parent);p:Hide()
    local title=V.Panel(p,0,0,1136,82,'header');V.Icon(title,'chronicle',64,14,-8)
    V.Text(title,"Athena’s Journal",94,-12,690,26,V.gold)
    p.modeText=V.Text(title,'Live history • source-backed stories',94,-49,680,13,V.muted)
    p.demo=V.Button(title,'Return to Hephaestus Lab',850,-23,266,34,function() if ns.WardenSimLab then ns.WardenSimLab.Open('grounds') end end,'neutral');p.demo:Hide()
    local left=V.Panel(p,0,-96,350,490,'dark');local book=V.Panel(p,366,-96,770,490,'paper')
    V.Text(left,'Chapters',16,-13,300,20,V.gold)
    p.list=V.ScrollingList(left,14,-50,305,420,86,function(list)
        local row=V.Button(list,'',0,0,302,80,function(self) p.selected=self.item.storyId;p:ShowStory(self.item);p.list:Render() end,'row')
        row.icon=V.Icon(row,'chronicle',44,8,-12);row.title=V.Text(row,'',62,-9,229,15,V.gold);row.title:SetHeight(24);row.title:SetWordWrap(false)
        row.sub=V.Text(row,'',62,-38,226,12,V.muted);row.sub:SetHeight(32);row.active=V.Nine(row,'selected');return row
    end,function(row,s) row.item=s;row.title:SetText(s.title);row.sub:SetText(Stamp(s.firstObservedAt)..' • '..s.storyStatus..'\n'..#s.sourceEvidenceRefs..' supporting sources');row.active:SetShown(p.selected==s.storyId) end)
    p.document,p.scroll=V.Document(book,26,-24,702,438);p.document:SetStyle('paper')
    p.status=V.Text(p,'',4,-600,350,12,V.muted);p.status:SetHeight(34)
    p.refresh=V.Button(p,'Refresh chapters',0,-650,192,32,function() p:Start() end,'neutral')
    p.older=V.Button(p,'Read older passages',204,-650,220,32,function() if p.job and p.job.nextCursor then p:Start(p.job.nextCursor) end end,'neutral')
    p.evidence=V.Button(p,'Why Athena wrote this',438,-650,270,32,function() p:ShowEvidence() end,'neutral')
    p.back=V.Button(p,'Back to chapter',722,-650,184,32,function() p:ShowStory(p.story) end,'neutral')
    p.original=V.Button(p,'Open source',920,-650,216,32,function() p:OpenEvidence() end,'neutral')
    p.sourceChoices={{false,'Choose an evidence source'}}
    p.sourceMenu=V.Dropdown(p,366,-600,770,p.sourceChoices,function() return p.evidenceRef or false end,function(ref) p.evidenceRef=ref;p.original:SetEnabled(ref~=false) end,{maxRows=8});p.sourceMenu:Hide()
    function p:Clear()
        self.job=nil;self.story=nil;self.selected=nil;self.evidenceRef=nil;self.pendingSource=nil;self.list:SetItems({});self.document:SetBlocks({});self.sourceMenu:Hide();self.original:SetEnabled(false);self.evidence:SetEnabled(false);self.back:SetEnabled(false)
    end
    function p:SetMode()
        self:Clear();self.provider,self.owner=J.Live(),host.owner or ns.Chronicle.Owner()
        self.modeText:SetText('Live history • source-backed stories')
        self.demo:SetShown(false);self:Start()
    end
    function p:SetSimulation(provider,owner)
        self:Clear();self.provider=provider;self.owner=owner;self.modeText:SetText('SYNTHETIC — Hephaestus Lab evidence');self.demo:Show();self:Start()
    end
    function p:Start(cursor)
        self:Clear();self.owner=self.provider.demo and self.owner or host.owner or ns.Chronicle.Owner()
        self.job=J.New(self.provider,self.owner,cursor);self.rendered=false;self.older:SetEnabled(false)
        self.document:SetBlocks({{kind='title',text=self.provider.demo and 'SYNTHETIC — Hephaestus Lab evidence' or 'Your unwritten pages'},
            {text='Athena is reading permitted sources. Original history stays unchanged.'}})
    end
    function p:ShowStory(story)
        self.story=story;self.selected=story and story.storyId;self.evidenceRef=nil;self.sourceMenu:Hide();self.original:SetEnabled(false);self.back:SetEnabled(false);self.evidence:SetEnabled(story~=nil)
        local blocks={}
        if self.provider.demo then blocks[#blocks+1]={kind='heading',text='SYNTHETIC — Hephaestus Lab evidence'} end
        if not story then
            blocks[#blocks+1]={kind='title',text='The next chapter awaits'}
            blocks[#blocks+1]={text='No supported chapter was found in these passages.'}
            blocks[#blocks+1]={text='Ordinary history remains in Timeline and Activities.'}
            blocks[#blocks+1]={text='Read older passages, or return after another adventure.'}
        else
            blocks[#blocks+1]={kind='title',text=story.title}
            blocks[#blocks+1]={kind='meta',text=Stamp(story.firstObservedAt)..' • '..story.storyStatus..' • '..story.supportState}
            for _,b in ipairs(story.proseBlocks) do
                local lines={};for line in (Wrap(b.text)..'\n'):gmatch('(.-)\n') do lines[#lines+1]=line end
                for i,line in ipairs(lines) do blocks[#blocks+1]={text=line,gap=i<#lines and 0 or 14} end
            end
            if story.timeCoverage.partial or story.timeCoverage.unknownStart or story.timeCoverage.unknownEnd then blocks[#blocks+1]={kind='meta',text='This account is incomplete. Unseen intervals and missing boundaries remain unknown.'} end
            blocks[#blocks+1]={kind='meta',text=#story.sourceEvidenceRefs..' sources • '..#story.factualClaims..' supported claims • Why Athena wrote this opens the evidence.'}
        end
        self.document:SetBlocks(blocks);self.scroll:SetVerticalScroll(0);self.list:Render()
    end
    function p:ShowEvidence()
        if not self.story then return end
        local blocks={{kind='title',text=self.provider.demo and 'SYNTHETIC — Why Athena wrote this' or 'Why Athena wrote this'}}
        for _,c in ipairs(self.story.factualClaims) do
            blocks[#blocks+1]={kind='heading',text=c.claimType:gsub('_',' ')}
            local values={}
            if type(c.value)=='table' then for _,key in ipairs({'count','boss','itemID','name','guid','zone','spellID'}) do if c.value[key]~=nil then values[#values+1]=key..': '..tostring(c.value[key]) end end
            else values[1]=tostring(c.value) end
            if #values>0 then blocks[#blocks+1]={text=table.concat(values,' • ')} end
            blocks[#blocks+1]={kind='meta',text=c.confidence..' • '..table.concat(c.evidenceRefs,'\n')..(#c.disclaimers>0 and '\n'..table.concat(c.disclaimers,'; ') or '')}
        end
        for i=#self.sourceChoices,2,-1 do self.sourceChoices[i]=nil end
        for _,ref in ipairs(self.story.sourceEvidenceRefs) do self.sourceChoices[#self.sourceChoices+1]={ref,ref} end
        self.document:SetBlocks(blocks);self.scroll:SetVerticalScroll(0);self.sourceMenu:Show();self.status:SetText('Select an original source below. Permission is checked again when opening it.');self.back:SetEnabled(true)
    end
    function p:OpenEvidence()
        if not self.evidenceRef or not self.provider:Allowed() then return end
        local e,state=self.provider:Resolve(self.evidenceRef)
        if not e then self.status:SetText(messages[state] or 'Original source is not available yet.');return end
        if self.provider.demo then
            self.document:SetBlocks({{kind='title',text='DEMO — Original synthetic source'},{kind='heading',text=e.source or 'Source'},
                {text=e.evidenceRef..'\nObserver: '..e.observer..'\nObserved: '..Stamp(e.observedAt)..'\nThis is an isolated fixture, not a native gameplay record.'}});return
        end
        self.pendingSource={ref=self.evidenceRef,id=e.sourceRecordRef,owner=e.observer}
        self.status:SetText('Reading the permitted original source…')
    end
    function p:Refresh()
        if not self.provider then self:SetMode(false) end
        if not self.provider:Allowed() then self:Clear();self.status:SetText(messages.DENIED);return end
        if self.pendingSource then
            local request=self.pendingSource
            local permitted,state=self.provider:Resolve(request.ref)
            if not permitted then self.pendingSource=nil;self.status:SetText(messages[state] or 'Original source unavailable.');return end
            local rows=ns.RecordingUI.Request({owner=request.owner,eventID=request.id,mode='all',raw=true,page=0})
            if not rows then
                self.status:SetText('Reading the permitted original source…')
                return
            end
            for _,row in ipairs(rows) do if row.id==request.id then
                self.pendingSource=nil;ns.RecordingUI.OpenSource(nil,row);return
            end end
            self.pendingSource=nil;self.status:SetText('Original source is unavailable.');return
        end
        if not self.provider.demo and self.owner~=(host.owner or ns.Chronicle.Owner()) then self:Start() end
        if not self.job then self:Start() end
        local status=J.Pump(self.job)
        if status~='READY' then self.status:SetText(messages[status] or ('History state: '..status));return end
        if not self.rendered then
            self.rendered=true;local rows=J.Featured(self.job);self.list:SetItems(rows);self.selected=rows[1] and rows[1].storyId;self:ShowStory(rows[1]);self.older:SetEnabled(self.job.nextCursor~=nil)
            self.status:SetText((self.provider.demo and 'SYNTHETIC • ' or '')..#rows..' chapters • '..#self.job.stories..' activities reviewed.\nOriginal history is retained.')
        end
    end
    p:HookScript('OnHide',function(self) self:Clear();self.provider=nil end)
    p:SetScript('OnUpdate',function(self,dt) self.tick=(self.tick or 0)+dt;if self.tick>=.1 then self.tick=0;self:Refresh() end end)
    return p
end
