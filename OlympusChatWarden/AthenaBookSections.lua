-- Sections are ink in the existing BookReader, never a second visual surface.
local _,ns=...
local S={VERSION=1};ns.AthenaBookSections=S
local function Copy(t) local out={};for k,v in pairs(t or {}) do out[k]=v end;return out end
function S.Attach(p)
    local stateKeys={'shelf','view','destination','collection','threadId','volumeId','selected','story','threadPlan','loreID','loreEntry','loreContext','currentChapter','savedReading','novelPosition','memoryReturn','bookFlow'}
    local function Link(text,activate,detail)
        return {text=text,kind='body',gap=8,activate=activate,tooltipTitle=text,tooltip=detail or 'Read this section',tone='heading'}
    end
    function p:HoldReadingPlace(id)
        if not self.bookSection then
            local state={};for _,key in ipairs(stateKeys) do state[key]=self[key] end
            self.sectionReturn={owner=self.owner,source=self:ReaderSource(),place=self:BookPlace(),reading=self.CaptureReaderPlace and self:CaptureReaderPlace(),state=state}
        end
        self.bookSection=id
    end
    function p:WriteBookSection(id,blocks)
        local sameSection=self.bookSection==id and not self.folioTransition;self.folioTransition=nil
        local place=sameSection and self:BookPlace()
        if sameSection then
            local old=self:ReaderSource();local same=#old==#blocks
            if same then for i,b in ipairs(blocks)do if old[i].id~=b.id or old[i].kind~=b.kind or old[i].text~=b.text or old[i].pageBreak~=b.pageBreak then same=false;break end end end
            if same then return end
        end
        self:HoldReadingPlace(id);self.contentsOpen=id=='contents' or id=='chapters' or id=='loreIndex'
        self.sectionWrite=true
        if sameSection or self.openingCover then self.document:SetBlocks(blocks) else self:SweepToBlocks(blocks,self.bookTurnDirection) end
        self.sectionWrite=nil;if place then self:RestoreBookPlace(place) end
        self.scroll:Show()
    end
    function p:LeaveBookSection(restore)
        local saved=self.sectionReturn
        self.search:Hide();self.search:ClearFocus()
        self:CancelPageTurn();if self.memoryRail.privateEdit then self.memoryRail.privateEdit:Hide() end;self.bookSection=nil;self.contentsOpen=false;self.sectionReturn=nil;self.readerManuscriptSource=nil
        if saved and saved.owner==self.owner then
            if restore then for _,key in ipairs(stateKeys) do self[key]=saved.state[key] end end
            -- A navigation departure must retain its visible folio until the
            -- destination is ready. Restoring the saved manuscript here used
            -- to repaint both pages before SweepToBlocks began moving paper.
            if restore then self.document:SetBlocks(saved.source);self:RestoreBookPlace(saved.place) end
        end
        self.sourceRail:Hide();self.memoryRail:Hide();self.scroll:Show();self:BookLayout()
    end
    function p:CloseContents(restore) self:LeaveBookSection(restore~=false) end
    local function ReturnLink()
        return Link('Return to the marked passage',function() p:CloseContents(true) end,'Resume the exact book and reading anchor from before these reference pages.')
    end
    local function Prepare()
        -- Capture the manuscript before an index API selects its first entry.
        if not p.bookSection then p:HoldReadingPlace('contents') end
    end
    function p:ActivateIndexEntry(row)
        self.readerRestore=nil;self.readerPendingPlace=nil;self.folioRouteReturn=nil
        self:LeaveBookSection(false);self.sectionExitTransition=true
        if row.kind=='bookmark' then self:RestoreBookmark(row.bookmark)
        elseif row.kind=='lore' then self:OpenLore(row.loreID)
        elseif row.kind=='loreLocked' then self:WriteBookSection('loreIndex',{{kind='title',text='Undiscovered history'},{text='Explore and progress to unlock these pages.'},ReturnLink()})
        elseif row.kind=='search' then self:OpenStory(row.storyId)
        elseif row.kind=='thread' then self:OpenThread(row.id)
        elseif row.kind=='chapter' then self.requestedChapter=row.id;self:OpenThread(row.threadId,row.volumeId)
        elseif row.kind=='volume' then self:OpenThread(row.threadId,row.id)
        else self:ShowStory(row) end
    end
    function p:RenderSectionIndex()
        if self.sectionPreparing or not self.bookSection then return end
        local blocks={{kind='meta',text='ATHENA’S JOURNAL'},{kind='title',text=self.bookSection=='loreIndex' and 'Lore of Azeroth' or 'Contents'}}
        blocks[#blocks+1]=ReturnLink()
        local function Section(label,callback) blocks[#blocks+1]=Link(label,callback) end
        blocks[#blocks+1]={kind='heading',text='Sections of the journal'}
        for ordinal,choice in ipairs(self.collectionChoices or {}) do
            local id,label=choice[1],choice[2]
            Section(string.format('%02d.  %s',ordinal,label),function()
                if self.readerModes and self.readerModes[id] then self:LeaveBookSection(false);self.readerModes[id].open(self)
                else self:OpenContents(id) end
            end)
        end
        Section('Lore of Azeroth',function() self:OpenContents('lore') end)
        Section('Conversations & Memories',function() self:ShowMemories() end)
        Section('Books & reading marks',function() self:OpenReadingMarks() end)
        Section('Endnotes & reading preferences',function() self:OpenEndnotes() end)
        if self.bookSection~='loreIndex' then
            local threads=self.library and self.library.index and self.library.index.threads
            local thread=threads and threads.byID[self.threadId or '']
            if thread and #thread.volumeIds>0 then
                blocks[#blocks+1]={kind='heading',text='Volumes'}
                for ordinal,volumeID in ipairs(thread.volumeIds) do
                    if ordinal>2 then break end
                    local volume=threads.volumes[volumeID];local id=volumeID;local tid=thread.id
                    blocks[#blocks+1]=Link(volume.title or ('Volume '..tostring(volume.ordinal or '')),function() self:ActivateIndexEntry({kind='volume',threadId=tid,id=id}) end)
                end
                if #thread.volumeIds>2 then blocks[#blocks+1]=Link('All volumes',function() self:OpenVolumes(thread) end) end
            end
        end
        -- Chapter links use source anchors, so changing text size keeps them correct.
        local marked=self.sectionReturn
        local chapterBlocks={}
        for n,block in ipairs(marked and marked.source or {}) do
            if block.kind=='heading' then chapterBlocks[#chapterBlocks+1]={block=n,id=block.id,title=block.text} end
        end
        if #chapterBlocks>0 then
            blocks[#blocks+1]={pageBreak=true}
            blocks[#blocks+1]={kind='title',text='Chapters in this volume'}
            for _,chapter in ipairs(chapterBlocks) do
                local anchor={id=chapter.id,block=chapter.block,offset=0}
                blocks[#blocks+1]=Link(chapter.title,function()
                    self:CloseContents(true);self.document:RestoreReadingAnchor(anchor)
                end,'Turn directly to this chapter in the marked volume.')
            end
        end
        blocks[#blocks+1]={pageBreak=true}
        blocks[#blocks+1]={kind='meta',text=self.bookSection=='loreIndex' and 'THE WORLD BEYOND THE PAGE' or 'VOLUMES & CHAPTERS'}
        blocks[#blocks+1]={kind='title',text=self.bookSection=='loreIndex' and 'History & legends' or 'Chapters'}
        local rows=self.list.items or {}
        if #rows==0 then blocks[#blocks+1]={text='No permitted chapters are available in this collection yet.'} end
        for _,row in ipairs(rows) do
            local entry=row
            blocks[#blocks+1]=Link(entry.title or 'Untitled passage',function() self:ActivateIndexEntry(entry) end)
            if entry.subtitle and entry.subtitle~='' then blocks[#blocks+1]={kind='meta',text=entry.subtitle,gap=16} end
        end
        if self.bookSection=='loreIndex' then
            if self.loreNext then blocks[#blocks+1]=Link('Further history',function() self.sectionPreparing=true;self:LoreStep(-1);self.sectionPreparing=nil;self:RenderSectionIndex() end) end
            if (self.lorePage or 1)>1 then blocks[#blocks+1]=Link('Earlier history',function() self.sectionPreparing=true;self:LoreStep(1);self.sectionPreparing=nil;self:RenderSectionIndex() end) end
        end
        self:WriteBookSection(self.bookSection,blocks)
    end
    function p:OpenContents(collection)
        Prepare();self.sectionPreparing=true
        if not collection then self.bookSection='contents' end
        if collection=='lore' or not collection and self.shelf=='lore' then
            self.bookSection='loreIndex';self:SetShelf('lore')
        elseif collection then
            if self.shelf~='chronicle' then self:SetShelf('chronicle') end
            self.bookSection='chapters';self:SetCollection(collection)
        end
        self.sectionPreparing=nil;self:RenderSectionIndex()
    end
    function p:OpenVolumes(thread)
        local blocks={{kind='title',text='Volumes'},ReturnLink()}
        for _,volumeID in ipairs(thread.volumeIds) do local id=volumeID;local volume=self.library.index.threads.volumes[id]
            blocks[#blocks+1]=Link(volume.title or ('Volume '..tostring(volume.ordinal or '')),function() self:ActivateIndexEntry({kind='volume',threadId=thread.id,id=id}) end)
        end
        self:WriteBookSection('volumes',blocks)
    end
    function p:OpenReadingMarks()
        Prepare();local blocks={{kind='meta',text='THE PRIVATE LIBRARY'},{kind='title',text='Books & reading marks'},ReturnLink()}
        blocks[#blocks+1]=Link('Read the permitted saved copy',function()
            self:LeaveBookSection(true)
            if not ns.AthenaReadingSnapshots.Restore(self,self.collection) then self:WriteBookSection('marks',{{kind='title',text='No saved copy'},{text='There is no permitted saved copy for the selected collection.'},ReturnLink()}) end
        end)
        blocks[#blocks+1]=Link('Mark the passage I was reading',function()
            self:LeaveBookSection(true);self:SaveBookmark();self:OpenReadingMarks()
        end)
        for i,bookmark in ipairs(self.bookmarks or {}) do local saved=bookmark;blocks[#blocks+1]=Link('Reading mark '..i,function() self:LeaveBookSection(false);self:RestoreBookmark(saved) end) end
        self:WriteBookSection('marks',blocks)
    end
    function p:OpenEndnotes()
        Prepare();self:WriteBookSection('notes',{{kind='meta',text='AT THE END OF THE VOLUME'},{kind='title',text='Notes & sources'},ReturnLink(),
            Link('Places & paths',function() self:OpenContents('places') end),
            Link('Adventures & battles',function() self:OpenContents('archive') end),
            Link('Saved books & reading marks',function() self:OpenReadingMarks() end),
            Link('Reading preferences',function() self:OpenReadingPreferences() end),
            Link('Find a chapter',function() self:OpenBookSearch() end),
            Link('On this telling: actions & related passages',function() self:OpenBookActions() end),
            Link('Sources & historical limits',function() self:LeaveBookSection(true);self:ShowEvidence() end),
            Link('Private recollections',function() self:LeaveBookSection(true);self:OpenRecollections(false) end)})
    end
    function p:OpenReadingPreferences()
        Prepare();local blocks={{kind='title',text='On reading this book'},ReturnLink()}
        for _,choice in ipairs(self.contentChoices) do
            local item=choice
            if item[1] and item[1]~='bookmarks' then blocks[#blocks+1]=Link(item[2],function()
                if item[1]=='font' or item[1]=='motion' then self.contents.choose(item[1]);self:OpenReadingPreferences()
                else self:LeaveBookSection(true);self.contents.choose(item[1]) end
            end) end
        end
        blocks[#blocks+1]=Link('Keyboard reading: '..(self.keyboardReading and 'enabled' or 'disabled'),function() self:SetKeyboardReading(not self.keyboardReading);self:OpenReadingPreferences() end)
        self:WriteBookSection('preferences',blocks)
    end
    function p:OpenBookActions()
        Prepare();local blocks={{kind='title',text='On this telling'},ReturnLink()}
        for _,choice in ipairs(self.overflowChoices) do local item=choice
            if item[1] then blocks[#blocks+1]=Link(item[2],function()
                if item[1]=='options' then self:OpenReadingPreferences()
                elseif item[1]=='related' then
                    local related={{kind='title',text='Connected passages'},ReturnLink()}
                    for _,entry in ipairs(self.relatedChoices) do local other=entry;if other[1] then related[#related+1]=Link(other[2],function() self:LeaveBookSection(true);self:Follow(other[1]) end) end end
                    self:WriteBookSection('related',related)
                else self:LeaveBookSection(true);self.overflow.choose(item[1]) end
            end) end
        end
        self:WriteBookSection('actions',blocks)
    end
    function p:LayoutBookSearch()
        local visible=not self.closedBookSide and self.bookSection=='search' and self.readingPage==1
        self.search:SetShown(visible)
        if visible then
            local w=self.book:GetWidth();local wide=w>=480
            self.search:SetParent(self.book);self.search:ClearAllPoints();self.search:SetPoint('TOPLEFT',self.book,'TOPLEFT',w*(wide and .055 or .12),-110)
            self.search:SetSize(w*(wide and .40 or .76),28);self.search:SetTextColor(.23,.12,.045)
        end
    end
    function p:OnReaderPageChanged() self:LayoutBookSearch() end
    function p:OpenBookSearch()
        Prepare();self.bookSection='search';self:RenderBookSearch()
    end
    function p:RenderBookSearch()
        if self.bookSection~='search' then return end
        local blocks={{kind='title',text='Find a chapter'},{text='',gap=90},{kind='meta',text='Write a title or phrase on the line above. Results follow below.'},ReturnLink()}
        for _,row in ipairs(self.list.items or {}) do local entry=row;blocks[#blocks+1]=Link(entry.title or 'Passage',function() self:ActivateIndexEntry(entry) end) end
        self:WriteBookSection('search',blocks);self:LayoutBookSearch()
    end
    function p:PresentSources(input)
        local blocks={};for _,b in ipairs(input) do blocks[#blocks+1]=Copy(b) end
        blocks[#blocks+1]=ReturnLink()
        for _,choice in ipairs(self.sourceChoices or {}) do if choice[1] then
            local ref=choice[1];blocks[#blocks+1]=Link(choice[2],function() self.evidenceRef=ref;self:OpenEvidence() end)
        end end
        if self.revealTicket then
            blocks[#blocks+1]=Link('Confirm deliberate spoiler reading',function() self:LeaveBookSection(false);self:FinishReveal(true) end)
            blocks[#blocks+1]=Link('Keep Story-Safe reading',function() self:FinishReveal(false);self:CloseContents(true) end)
        end
        self:WriteBookSection('sources',blocks)
    end
    -- Reuse the existing privacy-gated memory methods; only their output is
    -- redirected. Private text is never read from the store by this presenter.
    local memory=p.memoryRail
    local bodySet=memory.body.SetBlocks
    function memory.body:SetBlocks(blocks)
        bodySet(self,blocks)
        if not blocks or #blocks==0 or not p.PresentMemoryPages then return end
        p:PresentMemoryPages(blocks)
    end
    function p:PresentMemoryPages(input)
        local blocks={{kind='meta',text='OWNER-PRIVATE MEMORIES'}}
        for _,b in ipairs(input) do blocks[#blocks+1]=Copy(b) end
        blocks[#blocks+1]=ReturnLink()
        local function Command(label,field)
            local control=memory[field]
            if control and control.GetScript then blocks[#blocks+1]=Link(label,function() local callback=control:GetScript('OnClick');if callback then callback(control,'LeftButton');if self.bookSection=='memories' then self:PresentMemoryPages(memory.body.blocks or {}) end end end) end
        end
        Command(self.memoryReveal and 'Conceal private excerpts' or 'Deliberately reveal private excerpts','reveal')
        Command('Preserved moments','saved');Command('Suggested & delivered lines','inbox')
        for _,choice in ipairs(memory.choices or {}) do if choice[1] then local ref=choice[1];blocks[#blocks+1]=Link(choice[2],function() self.memorySelection=ref;self:MemorySelection() end) end end
        if self.memoryHandles then Command('Remember this selected source','keep');Command('Discard this candidate','discard') end
        Command('Privacy & recording choices','configure')
        if memory.confirmDelete and memory.confirmDelete:IsShown() then Command('Confirm deletion of the selected private memory','confirmDelete') end
        if self.memorySelectedMoment then
            blocks[#blocks+1]=Link('Write a personal title or note',function() self:MemoryNotes() end)
            blocks[#blocks+1]=Link('Prepare my private archive for copying',function() self:MemoryExport() end)
            Command('Hide selected memory from the story','hide');Command('Delete selected memory','delete') end
        self:WriteBookSection('memories',blocks)
    end
    local showEvidence=p.ShowEvidence
    function p:ShowEvidence(...) Prepare();return showEvidence(self,...) end
    local showMemories=p.ShowMemories
    function p:ShowMemories(...)
        if not self.provider or not self.provider:Allowed() then self:Clear();return end
        Prepare();return showMemories(self,...)
    end
    local memorySettings=p.MemorySettings
    function p:MemorySettings()
        memorySettings(self)
        local draft=memory.settingsDraft
        if draft then self:PresentMemoryPolicy(draft)
        else self:WriteBookSection('memoryPolicy',{{kind='title',text='Conversation privacy'},{text='No permitted conversation archive is available for this reading context.'},ReturnLink()}) end
    end
    function p:PresentMemoryPolicy(draft)
        local blocks={{kind='title',text='On preserving conversations'},ReturnLink()}
        local labels={enabled='Remember meaningful conversations',autoCandidates='Suggest meaningful exchanges',autoPreserve='Preserve qualified group exchanges',showDirectQuotes='Allow exact quotes in my private Journey',partyRaid='Party and raid',guild='Guild',sayEmote='Say, yell and emotes',instance='Instance chat',publicChannels='Public channels and Trade',whispers='Private whispers',officer='Officer chat'}
        local keys={};for key in pairs(draft) do keys[#keys+1]=key end;table.sort(keys)
        for _,key in ipairs(keys) do local field=key;blocks[#blocks+1]=Link((labels[field] or field)..': '..(draft[field] and 'yes' or 'no'),function() draft[field]=not draft[field];if memory.checks[field] then memory.checks[field]:SetChecked(draft[field]) end;self:PresentMemoryPolicy(draft) end) end
        blocks[#blocks+1]=Link('Apply these explicit choices',function() memory.apply:GetScript('OnClick')(memory.apply,'LeftButton');self:ShowMemories() end)
        self:WriteBookSection('memoryPolicy',blocks)
    end

    local function PlaceMemoryEditor()
        local f=memory.privateEdit;if not f then return end
        f:SetParent(p.book);f:SetFrameLevel(p.book:GetFrameLevel()+25)
        if f.ArtFrame then f.ArtFrame:Hide() end;if f.ArtBacking then f.ArtBacking:Hide() end
        local w=math.min(640,p.book:GetWidth()*.76);local h=math.max(190,p.book:GetHeight()-210)
        f:ClearAllPoints();f:SetPoint('TOPLEFT',p.book,'TOPLEFT',(p.book:GetWidth()-w)/2,-130);f:SetSize(w,h)
        memory.editTitleBox:SetWidth(w-32);memory.editBodyBox:SetWidth(w-32);memory.editBodyBox:SetHeight(math.max(70,h-100))
        memory.editDone:ClearAllPoints();memory.editDone:SetPoint('TOPLEFT',16,-h+34)
        f:Show()
    end
    local memoryNotes,memoryExport=p.MemoryNotes,p.MemoryExport
    function p:MemoryNotes()
        memoryNotes(self);if memory.privateEdit and memory.privateEdit:IsShown() then
            self:WriteBookSection('memoryWriting',{{kind='title',text='A personal recollection'},{text='Your title and note are private; they are not historical evidence.'},ReturnLink()});PlaceMemoryEditor()
        end
    end
    function p:MemoryExport()
        memoryExport(self);if memory.privateEdit and memory.privateEdit:IsShown() then
            self:WriteBookSection('memoryWriting',{{kind='title',text='Your private archive'},{text='Copy deliberately. This text stays local and is not sent through Relay.'},ReturnLink()});PlaceMemoryEditor()
        end
    end

end
