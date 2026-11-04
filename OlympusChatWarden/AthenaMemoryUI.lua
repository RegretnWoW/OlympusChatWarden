-- Owner-private folio and explicit collection controls. No implicit consent.
local _,ns=...
local U={};ns.AthenaMemoryUI=U
local V=ns.Art
function U.Attach(p)
    local f=V.Panel(p.utilitySink or p,0,-52,1080,500,'paper');p.memoryRail=f;f:Hide()
    f.title=V.Text(f,'Conversations & Memories',20,-14,650,22,{.31,.15,.055})
    f.status=V.Text(f,'Private • Off by default',20,-44,700,14,{.28,.22,.15});f.status:SetHeight(34)
    f.body,f.scroll=V.Document(f,20,-130,940,300);f.body:SetStyle('paper')
    f.back=V.Button(f,'Return to Journey',20,-80,180,28,function() p:ReturnFromMemories() end,'neutral')
    f.configure=V.Button(f,'Privacy & recording',208,-80,190,28,function() p:MemorySettings() end,'neutral')
    f.saved=V.Button(f,'Saved',408,-80,100,28,function() p.memoryMode='saved';p:ShowMemories() end,'neutral')
    f.inbox=V.Button(f,'Inbox',518,-80,100,28,function() p.memoryMode='inbox';p:ShowMemories() end,'neutral')
    f.reveal=V.Button(f,'Reveal private text',628,-80,190,28,function() p.memoryReveal=not p.memoryReveal;p:ShowMemories() end,'neutral')
    f.actions=V.Dropdown(f,210,-78,280,{{false,'Memory actions'},{'settings','Privacy & recording'},{'saved','Preserved moments'},{'inbox','Suggested & delivered lines'},{'reveal','Reveal / conceal private text'},{'previous','Previous saved page'},{'next','Next saved page'},{'note','Personal title & note'},{'restore','Restore to Story'},{'export','Export my private archive'}},function() return false end,function(action)
        if action=='settings' then p:MemorySettings()
        elseif action=='note' then p:MemoryNotes()
        elseif action=='export' then p:MemoryExport()
        elseif action=='restore' then local service=p:MemoryService();if service and p.memorySelectedMoment then service.Revise(p.memorySelectedMoment,{hideFromStory=false},p:MemoryContext());p:ShowMemories() end
        elseif action=='reveal' then p.memoryReveal=not p.memoryReveal;p:ShowMemories()
        elseif action=='next' and p.memoryNext then p.memoryCursors=p.memoryCursors or {};p.memoryCursors[#p.memoryCursors+1]=p.memoryCursor or 1;p.memoryCursor=p.memoryNext;p:ShowMemories()
        elseif action=='previous' and p.memoryCursors and #p.memoryCursors>0 then p.memoryCursor=table.remove(p.memoryCursors);p:ShowMemories()
        elseif action=='saved' or action=='inbox' then p.memoryMode=action;p.memoryCursor=nil;p.memoryCursors={};p:ShowMemories() end
    end)
    f.choices={{false,'Choose an eligible source'}}
    f.select=V.Dropdown(f,20,-114,460,f.choices,function() return p.memorySelection or false end,function(ref) p.memorySelection=ref or nil;p:MemorySelection() end)
    f.keep=V.Button(f,'Remember this',20,-420,170,28,function() p:KeepMemory() end,'primary')
    f.discard=V.Button(f,'Discard candidate',200,-420,180,28,function() local service=p:MemoryService();if service and p.memoryCandidate then service.DiscardCandidate(p.memoryCandidate,p:MemoryContext());p:ShowMemories() end end,'neutral')
    f.hide=V.Button(f,'Hide from Story',390,-420,170,28,function() local service=p:MemoryService();if service and p.memorySelectedMoment then service.Revise(p.memorySelectedMoment,{hideFromStory=true},p:MemoryContext());p:ShowMemories() end end,'neutral')
    f.delete=V.Button(f,'Delete selected',570,-420,160,28,function() p.memoryDeletePending=p.memorySelectedMoment;f.confirmDelete:SetShown(p.memoryDeletePending~=nil) end,'danger')
    f.confirmDelete=V.Button(f,'Confirm deletion',740,-420,180,28,function() local service=p:MemoryService();if service and p.memoryDeletePending then service.Delete(p.memoryDeletePending,p:MemoryContext(),true) end;p.memoryDeletePending=nil;f.confirmDelete:Hide();p:ShowMemories() end,'danger');f.confirmDelete:Hide()
    f.settings=V.Panel(f,14,-112,960,380,'paper');f.settings:Hide();f.checks={}
    f.privateEdit=V.Panel(f,14,-112,960,380,'paper');f.privateEdit:Hide()
    f.editTitle,f.editTitleBox=V.Edit(f.privateEdit,16,-12,800,30,'Personal title (not historical evidence)',nil);f.editTitle:SetMaxLetters(120)
    f.editBody,f.editBodyBox=V.Edit(f.privateEdit,16,-52,800,120,'Private note',nil,true)
    f.editDone=V.Button(f.privateEdit,'Save personal note',16,-180,200,28,function()
        local service=p:MemoryService();if service and not p.memoryExporting and p.memorySelectedMoment then service.Revise(p.memorySelectedMoment,{title=f.editTitle:GetText(),note=f.editBody:GetText()},p:MemoryContext()) end
        f.privateEdit:Hide();f.editBody:SetText('');f.editTitle:SetText('');p:ShowMemories()
    end,'primary')
    function p:MemoryNotes()
        local service=self:MemoryService();local moment=service and self.memorySelectedMoment and service.ResolveMoment(self.memorySelectedMoment,self:MemoryContext());if not moment then return end
        self.memoryExporting=false;f.editTitle:SetShown(true);f.editTitle:SetText(moment.revision.title or '');f.editBody:SetMaxLetters(1000);f.editBody:SetText(moment.revision.note or '');f.editDone:SetText('Save personal note');f.privateEdit:Show()
    end
    function p:MemoryExport()
        local service=self:MemoryService();if not service or not self.memoryReveal then f.status:SetText('Reveal your private text before deliberately exporting this owner’s archive.');return end
        local backup,why=service.ExportOwner(self:MemoryContext(),true);if not backup then f.status:SetText(why);return end
        self.memoryExporting=true;f.editTitle:Hide();f.editBody:SetMaxLetters(0);f.editBody:SetText(ns.Reports.JSON(backup));f.editBody:HighlightText();f.editDone:SetText('Close private export');f.privateEdit:Show()
        f.status:SetText('Owner-private local copy only. Select and copy; never send through Relay or guild chat.')
    end
    f:HookScript('OnHide',function() f.privateEdit:Hide();f.editBody:SetText('');f.editTitle:SetText('');p.memoryExporting=nil end)
    f.settingsScroll=CreateFrame('ScrollFrame',nil,f.settings);f.settingsScroll:SetPoint('TOPLEFT',8,-8);f.settingsScroll:SetSize(900,360);V.SkinScroll(f.settingsScroll)
    f.settingsBody=CreateFrame('Frame',nil,f.settingsScroll);f.settingsBody:SetSize(900,400);f.settingsScroll:SetScrollChild(f.settingsBody)
    local fields={{'enabled','Remember meaningful conversations'},{'partyRaid','Party and raid'},{'guild','Guild'},{'sayEmote','Say, yell and emotes'},{'instance','Instance chat'},{'publicChannels','Public channels / Trade'},{'whispers','Private whispers'},{'officer','Officer'},{'autoCandidates','Suggest meaningful exchanges'},{'autoPreserve','Automatically preserve qualified group exchanges'},{'showDirectQuotes','Allow exact quotes inline in my private Journey'}}
    for i,entry in ipairs(fields) do local key=entry[1];local column=i>6 and 1 or 0;local number=column==1 and i-7 or i-1
        f.checks[key]=V.Check(f.settingsBody,entry[2],18+column*460,-20-number*38,false,function(value) if f.settingsDraft then f.settingsDraft[key]=value==true end end,430)
        f.checks[key].Caption:SetHeight(44);f.checks[key].Caption:SetTextColor(.22,.15,.085)
    end
    f.apply=V.Button(f.settingsBody,'Apply explicit choices',20,-278,250,30,function()
        local service=p:MemoryService();if not service then return end
        local draft=f.settingsDraft;local policy={enabled=draft.enabled,autoCandidates=draft.autoCandidates,autoPreserve=draft.autoPreserve,showDirectQuotes=draft.showDirectQuotes,scopes={}}
        for _,key in ipairs({'partyRaid','guild','sayEmote','instance','publicChannels','whispers','officer'}) do policy.scopes[key]=draft[key]==true end
        local ok,why=service.SetConsent(p.owner,policy,true);f.settings:Hide();p:ShowMemories();f.status:SetText(ok and 'Choices saved. Collection requires Chronicle recording. New moments await normal WoW save.' or why)
    end,'primary')
    f.applyTop=V.Button(f.settings,'Apply explicit choices',18,-8,240,28,function() f.apply:GetScript('OnClick')(f.apply,'LeftButton') end,'primary')
    f.explanation=V.Text(f.settingsBody,'Nothing is enabled until you Apply. Every channel is separate. Pausing keeps existing memories. Private text stays local; messages do not prove their claims.',20,-320,850,14,{.28,.22,.15});f.explanation:SetHeight(60)
    function p:MemoryService()
        if not self.provider or not self.provider:Allowed() then return nil end
        if self.provider.demo then return self.provider.ConversationStore end
        if self.owner~=ns.Chronicle.Owner() then return nil end
        return ns.AthenaConversations
    end
    function p:MemoryContext()
        local service=self:MemoryService();return service and service.Context('chronicle',self.owner,{reveal=self.memoryReveal==true})
    end
    function p:MemorySettings()
        local service=self:MemoryService();if not service then f.status:SetText('No private conversation fixture supplied. Production settings are isolated.');return end
        local status=service.Status(self.owner);local policy=status.policy;local draft={}
        for _,key in ipairs({'enabled','autoCandidates','autoPreserve','showDirectQuotes'}) do draft[key]=policy[key]==true end
        for _,key in ipairs({'partyRaid','guild','sayEmote','instance','publicChannels','whispers','officer'}) do draft[key]=policy.scopes[key]==true end
        f.settingsDraft=draft;for key,check in pairs(f.checks) do check:SetChecked(draft[key]) end;f.settings:Show()
    end
    function p:ShowMemories()
        if self.shelf~='memories' then self.memoryReturn={owner=self.owner,threadId=self.threadId,volumeId=self.volumeId,storyId=self.selected,offset=self.scroll:GetVerticalScroll(),anchor=self.document:GetReadingAnchor()} end
        local service=self:MemoryService();self.destination='collections';self.shelf='memories';self.sourceRail:Hide();self.scroll:Hide();f:Show();f.settings:Hide();f.privateEdit:Hide();f.editBody:SetText('');f.editTitle:SetText('');f.confirmDelete:Hide()
        f.title:SetText((self.provider and self.provider.demo and 'SYNTHETIC • ' or '')..'Conversations & Memories')
        self.memorySelectedMoment=nil;self.memoryCandidate=nil;self.memoryHandles=nil
        for i=#f.choices,2,-1 do table.remove(f.choices,i) end
        if not service then f.body:SetBlocks({{kind='title',text='Private memory folio'},{text='No private conversation fixture is attached. Live conversations are not accessible in synthetic previews.'}});return end
        local status=service.Status(self.owner);f.status:SetText(status.state..' • '..status.moments..' preserved • '..math.floor(status.archiveBytes/1024)..' KiB • '..(status.warning or 'Local archive; normal WoW save required'))
        local ctx=self:MemoryContext()
        if self.memoryMode=='inbox' and ctx and self.memoryReveal then
            local lines=service.Staged(ctx) or {};self.memoryRows={}
            for i,e in ipairs(lines) do f.choices[#f.choices+1]={e.observationUID,'Delivered line '..i..' • '..e.channelKind};self.memoryRows[e.observationUID]={handle=e.observationUID,line=e} end
            for i,candidate in ipairs(service.Candidates(ctx) or {}) do f.choices[#f.choices+1]={candidate.ref,'Suggested memory '..i};self.memoryRows[candidate.ref]={candidate=candidate} end
        elseif ctx then
            self.memoryRows={};local rows,nextPage=service.ListMoments(self.owner,nil,self.memoryCursor,{context=ctx});self.memoryNext=nextPage
            for i,m in ipairs(rows or {}) do if m then f.choices[#f.choices+1]={m.momentRef,'Private memory '..((self.memoryCursor or 1)+i-1)};self.memoryRows[m.momentRef]={moment=m} end end
        end
        f.select:Refresh();f.body:SetBlocks({{kind='title',text=self.memoryMode=='inbox' and 'Suggested & delivered lines' or 'Preserved moments'},
            {text=self.memoryReveal and 'Choose an eligible source above. Inbox lines and suggestions expire; Remember this preserves only your selected source.' or 'Private excerpts are hidden. Reveal text deliberately to inspect or preserve eligible lines. Recording starts off and requires separate explicit choices.'},
            {kind='meta',text='Normal logout or /reload is required for WoW to save accepted moments. Hard-crash durability is not guaranteed.'}})
        f.keep:SetEnabled(false);f.hide:SetEnabled(false);f.delete:SetEnabled(false);f.discard:SetEnabled(false);self:Layout(self:GetWidth(),self:GetHeight())
    end
    function p:OpenMemory(ref)
        self.memoryMode='saved';self:ShowMemories();local service=self:MemoryService();local moment=service and service.ResolveMoment(ref,self:MemoryContext())
        if moment and not self.memoryRows[ref] then self.memoryRows[ref]={moment=moment};f.choices[#f.choices+1]={ref,'Linked private memory'} end
        self.memorySelection=ref;f.select:Refresh();self:MemorySelection()
    end
    function p:ReturnFromMemories()
        local saved=self.memoryReturn;self.memoryReturn=nil;f:Hide();self:SetDestination('journey')
        if saved and saved.owner==self.owner then self:RestoreBookmark(saved);self.document:RestoreReadingAnchor(saved.anchor) end
    end
    function p:MemorySelection()
        local service=self:MemoryService();local ctx=self:MemoryContext();local row=self.memoryRows and self.memoryRows[self.memorySelection]
        if not service or not ctx or not row then return end
        local blocks={{kind='title',text='Private conversation source'}}
        self.memorySelectedMoment=nil;self.memoryCandidate=nil;self.memoryHandles=nil
        if row.moment then
            local m=service.ResolveMoment(row.moment.momentRef,ctx)
            if not m then blocks[#blocks+1]={text='This source is no longer permitted.'}
            else
                self.memorySelectedMoment=m.momentRef;blocks[#blocks+1]={kind='meta',text=m.momentRef..'\n'..m.selectedBy..' • '..m.relationStrength}
                blocks[#blocks+1]={kind='meta',text='Observed '..m.observedFrom..' – '..m.observedTo..'. Journey links require matching retained context and chapter times. An unlinked memory remains preserved here.'}
                if self.memoryReveal and m.revision.title then blocks[#blocks+1]={text='Personal title: '..m.revision.title,literal=true} end
                if self.memoryReveal and m.revision.note then blocks[#blocks+1]={text='Personal note (not historical evidence): '..m.revision.note,literal=true} end
                if m.texts then for _,e in ipairs(m.texts) do blocks[#blocks+1]={kind='meta',text=e.channelKind..' • '..(e.speaker.name or 'Unknown speaker')..' • '..e.direction..' • '..e.textState};blocks[#blocks+1]={text=e.text,literal=true} end
                else blocks[#blocks+1]={text='Private text hidden; reveal requires the original channel to remain authorized.'} end
            end
        else
            local handles=row.candidate and row.candidate.messageEvidenceRefs or {row.handle};self.memoryHandles=handles;self.memoryCandidate=row.candidate and row.candidate.ref
            local wanted={};for _,h in ipairs(handles) do wanted[h]=true end
            local candidate=row.candidate and service.ResolveCandidate(row.candidate.ref,ctx)
            local available=candidate and candidate.messages or service.Staged(ctx) or {}
            for _,e in ipairs(available) do if wanted[e.observationUID] then blocks[#blocks+1]={kind='meta',text=e.channelKind..' • '..(e.speaker.name or 'Unknown speaker')..' • '..e.direction..' • '..e.observedAt..' • '..e.textState};blocks[#blocks+1]={text=e.text,literal=true} end end
        end
        blocks[#blocks+1]={kind='meta',text='A delivered message proves only that these words were received. It does not establish any asserted victory, relationship or accomplishment.'}
        f.body:SetBlocks(blocks);f.keep:SetEnabled(self.memoryHandles~=nil);f.hide:SetEnabled(self.memorySelectedMoment~=nil);f.delete:SetEnabled(self.memorySelectedMoment~=nil);f.discard:SetEnabled(self.memoryCandidate~=nil)
    end
    function p:KeepMemory()
        local service=self:MemoryService();local ctx=self:MemoryContext();if not service or not ctx or not self.memoryHandles then return end
        local ref,why=service.Pin(self.memoryHandles,ctx);self:ShowMemories();f.status:SetText(ref and 'Preserved locally; pending normal WoW save.' or why)
    end
    function p:LayoutMemories(width,height)
        local bh=height-58;f:ClearAllPoints();f:SetPoint('TOPLEFT',0,-52);f:SetSize(width,bh)
        f.status:SetWidth(width-40);f.title:SetWidth(width-40)
        for _,b in ipairs({f.configure,f.saved,f.inbox,f.reveal}) do b:Hide() end
        f.back:SetWidth(math.min(180,(width-50)/2));f.actions:ClearAllPoints();f.actions:SetPoint('TOPLEFT',30+f.back:GetWidth(),-78);f.actions:SetWidth(math.min(300,width-f.back:GetWidth()-55))
        f.select:SetWidth(width-40);f.scroll:ClearAllPoints();f.scroll:SetPoint('TOPLEFT',20,-152);f.scroll:SetSize(width-70,math.max(50,bh-202))
        local controls={f.keep,f.discard,f.hide,f.delete,f.confirmDelete};local each=math.min(180,(width-60)/4)
        for i,b in ipairs(controls) do b:ClearAllPoints();b:SetPoint('TOPLEFT',20+((i-1)%4)*(each+6),-(bh-38));b:SetWidth(each) end
        f.confirmDelete:SetPoint('TOPLEFT',20+3*(each+6),-(bh-38))
        f.settings:ClearAllPoints();f.settings:SetPoint('TOPLEFT',14,-112);f.settings:SetSize(width-28,math.max(100,bh-122))
        f.settingsScroll:ClearAllPoints();f.settingsScroll:SetPoint('TOPLEFT',8,-46);f.settingsScroll:SetSize(width-70,math.max(42,bh-190));f.settingsBody:SetWidth(width-90)
        f.privateEdit:SetSize(width-28,math.max(100,bh-122));f.editTitleBox:SetWidth(width-62);f.editBodyBox:SetWidth(width-62);f.editBodyBox:SetHeight(math.max(44,bh-240));f.editDone:ClearAllPoints();f.editDone:SetPoint('TOPLEFT',16,-(bh-162))
        local wide=width>=1000;local cw=wide and (width-110)/2 or width-120
        for i,entry in ipairs(fields) do local check=f.checks[entry[1]];local column=wide and (i>6 and 1 or 0) or 0;local number=wide and (column==1 and i-7 or i-1) or i-1
            check:ClearAllPoints();check:SetPoint('TOPLEFT',18+column*(cw+10),-12-number*52);check:SetWidth(cw);check.Caption:SetWidth(cw-35)
        end
        local endY=wide and 340 or 600;f.settingsBody:SetHeight(endY+120);f.apply:ClearAllPoints();f.apply:SetPoint('TOPLEFT',18,-endY)
        f.explanation:ClearAllPoints();f.explanation:SetPoint('TOPLEFT',18,-(endY+42));f.explanation:SetWidth(width-130)
    end
end
