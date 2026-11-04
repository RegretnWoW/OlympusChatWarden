-- A reusable reader. Live and explicitly injected simulation providers never mix.
local _,ns=...
local J,V=ns.AthenaJournal,ns.Art
local U={};ns.AthenaJournalUI=U
local function Stamp(at) return ns.SafeCall(date,'%Y-%m-%d',at) or tostring(at or 'Date unknown') end
local messages={DENIED='Chronicle access is unavailable. Source-backed pages have been cleared.',COMBAT_WAIT='Reading resumes after combat.',
    INDEXING='Reading permitted history…',LOAD_WAIT='Waiting for saved history validation…',LINK_PENDING='Waiting for source links…',
    building='Building the existing history index…',loading='Validating saved history…',pending='Waiting for permitted history…',
    CURSOR_STALE='History changed. Refresh the library to obtain a current older-page cursor.',UNAVAILABLE='This source is unavailable. No passage has been invented.'}
local function Place(frame,x,y,w,h) frame:ClearAllPoints();frame:SetPoint('TOPLEFT',x,y);frame:SetSize(w,h) end
local function Action(callback)
    local a={callback=callback}
    function a:GetScript(key) if key=='OnClick' then return self.callback end end
    function a:SetEnabled(value) self.enabled=value end
    function a:Hide() end
    function a:Show() end
    function a:SetShown() end
    function a:SetText(text) self.text=text end
    function a:SetParent() end
    function a:ClearAllPoints() end
    function a:SetPoint() end
    function a:SetSize() end
    function a:SetStyle() end
    function a:SetVerticalScroll(value) self.offset=value end
    function a:GetVerticalScroll() return self.offset or 0 end
    function a:Refresh() end
    function a:IsShown() return self.shown==true end
    function a:Show() self.shown=true end
    function a:Hide() self.shown=false end
    return a
end
local function Choice(_,_,_,_,choices,get,choose)
    local a=Action(function() end);a.choices=choices;a.choose=choose;return a
end
function U.Build(parent,host)
    -- The requested click-turn presentation starts animated once on upgrade.
    if ns.DB.journalClickTurnVersion~=1 then ns.DB.journalReducedMotion=false;ns.DB.journalClickTurnVersion=1 end
    local p=CreateFrame('Frame',nil,parent);p:SetAllPoints(parent);p:Hide();p.filter='all';p.order='newest';p.length='Chapter';p.view='reading';p.ChatWardenArtifact=true
    local title=V.Panel(p,0,0,1136,72,'dark')
    p.title=V.Text(title,'Athena’s Journal',80,-10,600,25,V.gold)
    p.title:SetWordWrap(false);p.title:SetHeight(30)
    p.modeText=V.Text(title,'Your adventure book',81,-42,650,13,V.muted)
    p.demo=V.Button(title,'Return to private Lab',850,-20,260,32,function() if ns.WardenSimLab then ns.WardenSimLab.Open('grounds') end end,'neutral');p.demo:Hide()
    local left=CreateFrame('Frame',nil,p);left:Hide();p.utilitySink=CreateFrame('Frame',nil,p);p.utilitySink:Hide()
    local book=V.Panel(p,0,0,1136,676,'paper')
    p.book=book
    p.pageEdge=book:CreateTexture(nil,'ARTWORK');p.pageEdge:SetColorTexture(.39,.23,.10,.16);p.pageEdge:SetPoint('TOPLEFT',10,-12);p.pageEdge:SetPoint('BOTTOMLEFT',10,12);p.pageEdge:SetWidth(3)
    p.pageSigil=V.Icon(book,'chronicle',28,0,0);p.pageSigil:ClearAllPoints();p.pageSigil:SetPoint('TOPRIGHT',-20,-18)
    p.leftTitle=V.Text(left,'Contents',16,-14,260,20,{.31,.15,.055})
    p.category=Choice(left,14,-48,270,{{'all','All passages'},{'MOMENT','Moments'},{'CHAPTER','Chapters'},{'SAGA','Sagas'},{'featured','Featured'}},function() return p.filter end,function(v) p.filter=v;p:RenderLibrary() end)
    p.sort=Choice(left,14,-88,270,{{'newest','Newest first'},{'oldest','Oldest first'},{'important','Important first'}},function() return p.order end,function(v) p.order=v;p:RenderLibrary() end)
    -- Data adapter for the existing permitted Journal index. No list frame,
    -- row buttons, rail, or scrollbar is constructed for Contents.
    p.list={items={},scroll=left,content=left}
    function p.list:SetItems(rows) self.items=rows or {};if p.bookSection=='search' and p.RenderBookSearch then p:RenderBookSearch()
        elseif (p.bookSection=='contents' or p.bookSection=='chapters' or p.bookSection=='loreIndex') and p.RenderSectionIndex and not p.sectionPreparing then p:RenderSectionIndex() end end
    function p.list:Render() end
    function p.list:Resize() end
    p.document,p.scroll=V.Document(book,26,-24,754,400);p.document:SetStyle('paper')
    p.context,p.contextScroll=V.Document(left,24,-330,250,100);p.context:SetStyle('paper')
    p.sourceRail=Action(function() end)
    p.inspector=Action(function() end);p.inspectorScroll=Action(function() end)
    function p.inspector:SetBlocks(blocks)
        self.blocks=blocks
        if blocks and #blocks>0 and p.PresentSources then p:PresentSources(blocks) end
    end
    p.closeSources=Action(function() p:CloseContents(true) end)
    p.gutter=p:CreateTexture(nil,'BACKGROUND');p.gutter:SetColorTexture(.20,.12,.055,.85)
    p.search,p.searchBox=V.Edit(left,14,-128,270,32,'Find a chapter…');p.search:SetScript('OnTextChanged',function(self) p.pendingSearch=self:GetText();p.searchWait=.3 end)
    p.libraryToggle=CreateFrame('Button',nil,book);p.libraryToggle:SetSize(100,24)
    p.libraryToggle.label=p.libraryToggle:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');p.libraryToggle.label:SetAllPoints();p.libraryToggle.label:SetText('Chapters');p.libraryToggle.label:SetTextColor(.38,.22,.08)
    p.libraryToggle:SetScript('OnClick',function() p:OpenContents() end)
    if ns.UI2Components then ns.UI2Components.TactileRow(p.libraryToggle,function()return true end)end
    p.status=V.Text(p,'',4,-630,1100,12,V.muted);p.status:SetHeight(30)
    p.notice=V.Text(book,'',30,-28,600,17,{.22,.15,.085});p.notice:SetHeight(100);p.notice:Hide()
    p.pageProgress=V.Text(p,'',112,-560,280,14,V.muted);p.pageProgress:SetHeight(28)
    p.refresh=Action(function() if p.collection~='all' then p:Start({threadId=p.threadId or p.library.index and p.library.index.threads.lifeId,volumeId=p.volumeId},true) else p:Start(nil,false) end end)
    p.older=Action(function() if p.collection~='all' then p:VolumeEdge(false) elseif p.library and p.library.nextCursor then p:Start(p.library.nextCursor,true) end end)
    p.previous=Action(function() if p.TurnReadingPage then p:TurnReadingPage(1) end end)
    p.next=Action(function() if p.TurnReadingPage then p:TurnReadingPage(-1) end end)
    p.latest=Action(function() if p.collection~='all' then p:VolumeEdge(true) else p:Start(nil,false) end end)
    p.lengthMenu=Choice(p,608,-560,174,{{'Short','Short'},{'Chapter','Chapter'},{'Epic','Epic'}},function() return p.length end,function(v) p.length=v;if p.view=='thread' then p:ShowThread() else p:ShowStory(p.story) end end)
    p.evidence=Action(function() p:ShowEvidence() end)
    p.back=Action(function() if p.view=='thread' and #p.breadcrumbs>0 then p:ReturnPath() elseif p.evidenceFromThread or p.threadId and p.view=='reading' then p:ShowThread() else p:ShowStory(p.story,true) end end)
    p.original=Action(function() p:OpenEvidence() end)
    p.sourceChoices={{false,'Choose an original source'}}
    p.sourceMenu=Choice(p,396,-600,510,p.sourceChoices,function() return p.evidenceRef or false end,function(ref) p.evidenceRef=ref or nil;p.original:SetEnabled(ref~=false) end,{maxRows=8})
    p.relatedChoices={{false,'Related passages'}}
    p.related=Choice(p,798,-560,338,p.relatedChoices,function() return false end,function(id) p:Follow(id) end,{maxRows=8})
    p.collection='life';p.collectionChoices={{'life','The Journey'},{'people','People & Companions'},{'places','Places'},{'pvp','Battlegrounds & PvP'},{'expeditions','Dungeons & Raids'},{'adventures','Growth & Other Chapters'},{'guild','Guild Chapters'},{'watch','The Watch'},{'protections','Private Protections'},{'sightings','Historical Sightings'},{'all','All Passages'}}
    p.collectionMenu=Choice(left,14,-48,270,p.collectionChoices,function() return p.collection end,function(v) p:SetCollection(v) end)
    p.contentChoices={{false,'Reading options'},{'voice','Narration: Natural Fantasy / Record'},{'lore','Show / hide lore context'},{'font','Text size: Small / Standard / Large / XL'},{'bookmark','Bookmark this page'},{'returnBookmark','Return to latest bookmark'},{'bookmarks','Bookmarked chapters'},{'removeBookmark','Remove latest bookmark'},{'clearBookmarks','Clear reading bookmarks'},{'prologue','Show / hide historical prelude'},{'motion','Page turns: animated / instant'},{'archive','Open full original history'},{'social','Friend / guild context'},{'protections','Private protection context'},{'sightings','Remember Signal sightings'},{'readSightings','Show historical sightings'}}
    p.contents=Choice(left,14,-88,270,p.contentChoices,function() return false end,function(key)
        if not key then return end
        if key=='bookmark' then p:SaveBookmark();return end
        if key=='returnBookmark' then p:RestoreBookmark(p.bookmark);return end
        if key=='clearBookmarks' then p.bookmarks={};p.bookmark=nil;p.status:SetText('Session reading bookmarks cleared. History is kept.');return end
        if key=='removeBookmark' then table.remove(p.bookmarks);p.bookmark=p.bookmarks[#p.bookmarks];p.status:SetText('Latest reading bookmark removed. History is kept.');return end
        if key=='bookmarks' then
            local rows={};for i,b in ipairs(p.bookmarks) do rows[#rows+1]={kind='bookmark',id=tostring(i),title='Reading place '..i,subtitle='Return to saved page in this session',bookmark=b} end
            p.list:SetItems(rows,true);p:OpenContents();return
        end
        if key=='prologue' then ns.DB.journalPrologueHidden=not ns.DB.journalPrologueHidden;if p.shelf=='lore' then p:RenderLoreList() else p:ShowThread() end;return end
        if key=='motion' then ns.DB.journalReducedMotion=not (ns.DB.journalReducedMotion~=false);p.document:FinishWordReveal();if p.rightPage then p.rightPage:FinishWordReveal() end;p.status:SetText(ns.DB.journalReducedMotion~=false and 'Instant pages enabled.' or 'Newly written pages reveal word by word. Click the page to finish. Saved copies open instantly.');return end
        if key=='archive' then if not p.provider.demo then ns.RecordingUI.OpenHistory(p.owner) else p.status:SetText('Synthetic originals are in the private Lab Evidence view.') end;return end
        if key=='font' then local scale=ns.DB.journalFontScale or 1;local anchor=p.document:GetReadingAnchor();ns.DB.journalFontScale=scale==1 and 1.2 or scale==1.2 and 1.4 or scale==1.4 and .85 or 1;p.document:SetFontScale(ns.DB.journalFontScale);p:Layout(p:GetWidth(),p:GetHeight());p.document:RestoreReadingAnchor(anchor);return end
        if key=='voice' then ns.DB.journalNarration=ns.AthenaChronicler.Voice()=='Natural Fantasy' and 'Observed Record' or 'Natural Fantasy';p:Recompose();return end
        if key=='lore' then ns.DB.journalLore=not ns.AthenaChronicler.Lore();p:Recompose();return end
        local fields={social='journalSocial',protections='journalProtections',sightings='journalCaptureSightings',readSightings='journalSightings'}
        local field=fields[key];if not field then return end
        if key=='social' then ns.DB[field]=not (ns.DB[field]~=false) else ns.DB[field]=not (ns.DB[field]==true) end
        p:Clear();p:Start()
    end)
    p.continue=V.Button(title,'Continue My Story',840,-20,260,32,function()
        local ts=p.library and p.library.index and p.library.index.threads
        if ts then p:OpenThread(ts.journeyId or ts.lifeId) else p.collection='life';p:Start() end
    end,'primary')

    ns.AthenaLoreUI.Attach(p);ns.AthenaMemoryUI.Attach(p);ns.AthenaRecollectionsUI.Attach(p)
    p.chronicleShelf=Action(function() end)
    p.collectionsShelf=Action(function() end)
    p.loreShelf=Action(function() end)
    if title.ArtFrame and type(title.ArtFrame.SetShown)=='function' then title.ArtFrame:SetShown(false) end;if title.ArtBacking and type(title.ArtBacking.Hide)=='function' then title.ArtBacking:Hide() end
    p.chapterFilter=ns.UI2Components.Button(title,'Activity',function()
        ns.UI2Forms.Form({title='Read Chapters',fields={{key='category',label='Activity',value=p.collection,choices={{'archive','All chapters'},{'questing','Questing'},{'dungeons','Dungeons'},{'raids','Raids'},{'battlegrounds','Battlegrounds'},{'duels','Duels / PvP'},{'world','World events'},{'guild','Guild & company'}}}},submitLabel='Read',submit=function(v) p:SetCollection(v.category);p.drawerOpen=false;p.drawerCollapsed=true;p:Layout(p:GetWidth(),p:GetHeight());return true end})
    end,130)
    function p:SetDestination(destination)
        if destination~='journey' then self.savedReading=nil;self.snapshotChecked=nil end
        -- A deliberate tab choice wins over the window's deferred first open.
        self.openJourneyPending=nil
        if self.destination=='journey' and self.collection=='life' and self.shelf~='lore' and self.shelf~='memories' and self.threadId then
            self.journeyPosition={owner=self.owner,threadId=self.threadId,volumeId=self.volumeId,storyId=self.selected,offset=self.scroll:GetVerticalScroll(),anchor=self.document:GetReadingAnchor()}
        end
        self.memoryRail:Hide();self.memoryReveal=false;self.memorySelection=nil;self.memoryRows=nil;self.memoryRail.body:SetBlocks({})
        self.destination=destination
        if destination=='lore' then self:SetShelf('lore')
        else self:SetShelf('chronicle');if destination=='journey' then self:SetCollection('life');self.drawerOpen=false;self.drawerCollapsed=true
            else self.drawerOpen=false;self.drawerCollapsed=true end
        end
        local jt=self.journeyPosition and self.library.index and self.library.index.threads.byID[self.journeyPosition.threadId]
        if destination=='journey' and jt and jt.collection=='life' and self.journeyPosition.owner==self.owner then
            local saved=self.journeyPosition;self:RestoreBookmark(saved);self.document:RestoreReadingAnchor(saved.anchor)
        end
        self:Layout(self:GetWidth(),self:GetHeight())
        if destination=='journey' and self.job and not self.job.done and not self.threadPlan then ns.AthenaReadingSnapshots.Restore(self) end
    end
    p.loreSections=Choice(left,12,-76,260,{{'all','All available history'},{'before','Before My Story'},{'ages','History & Great Events'},{'wars','Wars & Turning Points'},{'figures','People & Major Figures'},{'creatures','Creatures & Species'},{'nightelves','The Kaldorei'},{'alliance','Alliance Figures'},{'horde','Horde Figures'},{'ancientpowers','Ancients & Great Powers'},{'fallenpowers','Fallen Powers'},{'peoples','Peoples & Factions'},{'factions','Orders & Factions'},{'zones','World Atlas — All Zones'},{'eastern-kingdoms','Eastern Kingdoms'},{'kalimdor','Kalimdor'},{'zephras','Zephras Isle'},{'warcraft1','Warcraft I Figures'},{'warcraft2','Warcraft II Figures'},{'warcraft3','Warcraft III & Heritage'},{'classic','Classic Figures'},{'places','Lands & Landmarks'},{'cities','Cities & Strongholds'},{'dungeons','Dungeons & Raids'},{'battlegrounds','Battlegrounds'},{'artifacts','Relics & Artifacts'},{'worlds','Worlds & Continents'},{'questlines','Questlines Unfolding'},{'legends','Completed Legends'}},function() return p.loreSection or 'all' end,function(value) p.loreSection=value;p.loreCursor=nil;p.lorePage=1;p:RenderLoreList() end,{maxRows=9})
    p.loreSections:Hide()
    p.sourceMenu:SetParent(p.sourceRail);p.original:SetParent(p.sourceRail)
    p.confirmSpoilers=Action(function() p:FinishReveal(true) end)
    p.cancelSpoilers=Action(function() p:FinishReveal(false) end)
    p.regenerate=Action(function() p:Regenerate() end)
    p.recollect=Action(function() if not p:OpenRecollections(false) then p.pageProgress:SetText('Open a completed chapter to add a recollection.') end end)
    p.overflowChoices={{false,'Book actions'},{'saved','Open saved copy'},{'sources','Sources & Limits'},{'return','Return to previous book'},{'beginning','Read from Beginning'},{'latest','Latest chapter'},{'update','Update story'},{'regenerate','Regenerate this telling'},
        {'options','Reading options'},{'length','Passage length: Short / Chapter / Epic'},{'keyboard','Keyboard reading mode'},{'related','Chapters & related books'},{'recollections','Add / edit recollections'},{'memories','Conversations & Memories'},{'reveal','Read ahead: reveal spoilers…'},{'safe','Return to Story-Safe'}, {'lab','Return to private Lab'}}
    p.overflow=Choice(p,0,0,100,p.overflowChoices,function() return false end,function(key)
        if key=='saved' then p:CloseContents(true);if not ns.AthenaReadingSnapshots.Restore(p,p.collection) then p.status:SetText('No permitted saved copy is available for this collection.');p:OpenContents() end
        elseif key=='sources' then p:CloseContents(true);p:ShowEvidence()
        elseif key=='return' then if p.sourceRail:IsShown() then p.closeSources:GetScript('OnClick')(p.closeSources,'LeftButton') elseif #p.breadcrumbs>0 then p:ReturnPath() elseif p.threadId then p:ShowThread() else p:SetDestination('journey') end
        elseif key=='beginning' then if p.shelf=='lore' then p.lorePage=1;p.loreCursor=nil;p:RenderLoreList() else p:VolumeEdge(false) end
        elseif key=='latest' then if p.shelf~='lore' then p:VolumeEdge(true) end
        elseif key=='update' then if p.readFailure then p:Start(nil,true) elseif p.shelf=='lore' then p.loreContext=nil;p:RenderLoreList() else p.refresh:GetScript('OnClick')(p.refresh,'LeftButton') end
        elseif key=='regenerate' then p:Regenerate()
        elseif key=='options' then p:OpenContents();p.loreSections:Hide();p.category:Hide();p.contents:Show()
        elseif key=='length' and p.shelf=='chronicle' then p.length=p.length=='Short' and 'Chapter' or p.length=='Chapter' and 'Epic' or 'Short';if p.view=='thread' then p:ShowThread() else p:ShowStory(p.story) end
        elseif key=='keyboard' then p:SetKeyboardReading(not p.keyboardReading)
        elseif key=='related' then p.relatedExpanded=true;p:OpenContents();p.collectionMenu:Hide();p.related:Show()
        elseif key=='recollections' then if not p:OpenRecollections(false) then p.pageProgress:SetText('Open a completed chapter to add a recollection.') end
        elseif key=='memories' then p:ShowMemories()
        elseif key=='reveal' then p:RevealLore()
        elseif key=='safe' then local ctx=p:LoreContext();if ctx then ns.Athena.Knowledge.ResetReveals(ctx);p:RenderLoreList() end
        elseif key=='lab' and p.provider and p.provider.demo then p.demo:GetScript('OnClick')(p.demo,'LeftButton') end
    end,{maxRows=9})
    p.overflow:SetParent(left)
    function p:SetKeyboardReading(enabled)
        self.keyboardReading=enabled==true and type(self.EnableKeyboard)=='function';if self.EnableKeyboard then self:EnableKeyboard(self.keyboardReading) end
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
        self.pageProgress:SetText(self.keyboardReading and 'Keyboard: arrows / Page Up / Down • F6 books' or '')
    end
    p:SetScript('OnKeyDown',function(self,key)
        if key=='ESCAPE' and self.studyCamera and self.studyCamera.journalReading then self:CloseBook('front');if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false)end;return end
        if key=='ESCAPE' and self.bookSection then self:CloseContents(true);if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end;return end
        if self.immersive and key=='ESCAPE' then ns.UI2.immersive=false;ns.UI2.Refresh(true);return end
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
        if not (self.keyboardReading or self.immersive) or not self:IsShown() or not GetCurrentKeyBoardFocus or ns.SafeCall(GetCurrentKeyBoardFocus) then return end
        local handled=true;local scroll=self.bookSection and self.scroll or self.memoryRail:IsShown() and self.memoryRail.scroll or self.sourceRail:IsShown() and self.inspectorScroll or self.scroll
        if (key=='PAGEDOWN' or key=='PAGEUP' or key=='DOWN' or key=='UP') and (self.bookSection or not self.sourceRail:IsShown() and not self.memoryRail:IsShown()) then
            local b=(key=='PAGEDOWN' or key=='DOWN') and self.next or self.previous;b:GetScript('OnClick')(b,'LeftButton')
        elseif key=='PAGEDOWN' or key=='DOWN' then scroll:SetVerticalScroll(math.min(math.max(0,scroll:GetScrollChild():GetHeight()-scroll:GetHeight()),scroll:GetVerticalScroll()+(key=='DOWN' and 42 or scroll:GetHeight()*.8)))
        elseif key=='PAGEUP' or key=='UP' then scroll:SetVerticalScroll(math.max(0,scroll:GetVerticalScroll()-(key=='UP' and 42 or scroll:GetHeight()*.8)))
        elseif key=='LEFT' and (self.bookSection or not self.memoryRail:IsShown()) then self.previous:GetScript('OnClick')(self.previous,'LeftButton')
        elseif key=='RIGHT' and (self.bookSection or not self.memoryRail:IsShown()) then self.next:GetScript('OnClick')(self.next,'LeftButton')
        elseif key=='F6' then if self.contentsOpen then self:CloseContents(true) else self:OpenContents() end
        else handled=false end
        if handled and self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
    end)
    -- Reading modes extend this presentation list; they own no collector or snapshot storage here.
    p.readerModes={}
    function p:RegisterReadingMode(id,label,open)
        assert(type(id)=='string' and type(label)=='string' and type(open)=='function');self.readerModes[id]={label=label,open=open}
        self.collectionChoices[#self.collectionChoices+1]={id,label};self.collectionMenu:Refresh()
    end
    function p:Layout(width,height)
        local anchor=self.document:GetReadingAnchor()
        width=math.max(480,width or self:GetWidth());height=math.max(300,height or self:GetHeight())
        local bx,by,objectWidth,objectHeight=ns.AthenaBookScene.Bounds(self,width,height)
        local textScale=(ns.DB.journalFontScale or 1)*.54
        if self.turnState and math.abs(self.book:GetWidth()-objectWidth)<.01 and math.abs(self.book:GetHeight()-objectHeight)<.01 and self.document.fontScale==textScale then return end
        title:Hide();left:Hide();self.gutter:Hide();self.pageSigil:Hide();self.status:Hide();self.contextScroll:Hide()
        ns.AthenaBookScene.PlaceBook(self,width,height);book:Show();self.scroll:Show()
        self.libraryToggle:Hide()
        self.notice:SetWidth(width-72)
        self.document:SetFontScale(textScale)
        if self.BookLayout then self:BookLayout() end
        self.document:RestoreReadingAnchor(anchor)
        if self.LayoutBookSearch then self:LayoutBookSearch() end
    end
    function p:Clear()
        if self.ResetBookObject then self:ResetBookObject() end
        self.bookSection=nil;self.sectionReturn=nil;self.sectionWrite=nil;self.readerManuscriptSource=nil;self.sectionExitTransition=nil
        self.savedReading=nil;self.snapshotChecked=nil;self.sourceReturnPlace=nil
        self.recollectionSignature=nil;self.recollectionEditor:Hide();self.recollectionEditor.text:SetText('');self.recollectionBeforeGenerate=nil
        self.memorySignature=nil;self.rendered=false;self.appending=nil
        self.chapterTitles=nil
        self:SetKeyboardReading(false)
        self.notice:Hide();book:Show()
        self.memoryRail:Hide();self.memoryRail.body:SetBlocks({});self.memoryRail.settings:Hide();self.memoryReveal=false;self.memoryRows=nil;self.memorySelectedMoment=nil;self.memorySelection=nil;self.memoryReturn=nil;self.journeyPosition=nil
        self.job=nil;self.library=J.Library();self.identity=nil;self.story=nil;self.selected=nil;self.evidenceRef=nil;self.pendingSource=nil;self.view='reading';self.readFailure=nil;self.pendingCollection=nil;self.loadingMessage=nil;self.lorePending=nil;self.loreIndex=nil
        self.visibleStories={};self.readOffset=nil;self.bookmark=nil;self.bookmarks={};self.search:SetText('');self.pendingSearch=nil;self.searchResults=nil;self.searchJob=nil;self.threadParagraphs=nil;self.sourceRail:Hide();self.context:SetBlocks({});self.inspector:SetBlocks({});self.drawerOpen=false;self.drawerCollapsed=false;self.contentsOpen=false;self.contentsReturn=nil;left:Hide();self.shelf='chronicle';self.loreContext=nil;self.loreEntry=nil;self.loreID=nil;self.loreRows=nil;self.novelPosition=nil;self.revealContext=nil;self.revealTicket=nil;self.confirmSpoilers:Hide();self.cancelSpoilers:Hide()
        self.collection='life';self.relatedExpanded=nil;self.threadId=nil;self.volumeId=nil;self.threadPlan=nil;self.collectionState={};self.threadPositions={};self.breadcrumbs={};self.nextReadOffset=nil;self.scopeSignature=nil;self.permissionSignature=nil;self.evidenceFromThread=nil;self.pendingThread=nil;self.requestedStory=nil;self.allLoaded=nil
        if self.provider and self.provider.ClearPrivateSources then self.provider:ClearPrivateSources() end
        self.title:SetText('Athena’s Journal')
        self.modeText:SetText('No source-backed passage selected')
        for i=#self.sourceChoices,2,-1 do self.sourceChoices[i]=nil end
        for i=#self.relatedChoices,2,-1 do self.relatedChoices[i]=nil end
        V.CloseMenus();self.sourceMenu:Refresh();self.related:Refresh()
        self.list:SetItems({});self.document:SetBlocks({});self.sourceMenu:Hide();self.related:Hide();self.original:SetEnabled(false);self.original:Hide();self.back:Hide();self.evidence:SetEnabled(false);self.older:SetEnabled(false)
        self.previous:SetEnabled(false);self.next:SetEnabled(false)
    end
    function p:Owner() return host.owner or ns.Chronicle.Owner() end
    function p:ShowLoading(message)
        if self.shelf=='lore' and self.loreEntry and ns.Athena.Knowledge.GetLore(self.loreID,self:LoreContext()) then
            self.pageProgress:SetText('Lore of Azeroth • personal history preparing');return
        end
        if self.savedReading and self.savedReading.collection==self.collection and ns.AthenaReadingSnapshots.Valid(self) and self.shelf=='chronicle' then
            local progress=message or 'Preparing new pages…'
            self.pageProgress:SetText(self.readFailure and 'Saved copy • update paused' or ('Saved copy • '..progress));return
        end
        if self.readFailure then
            self.pageProgress:SetText('Reading paused • '..self.readFailure.status)
            self.document:SetBlocks({{kind='title',text='Your story could not be opened yet'},
                {text=messages[self.readFailure.status] or 'Athena could not finish preparing these pages.'},
                {kind='meta',text='History is kept. Book actions → Sources & Limits shows the reason; Update story retries.'}})
            return
        end
        if not message and ns.ChronicleStore.loading then message='Waiting for saved history validation…' end
        message=message or 'Athena is connecting your retained observations into chapters.'
        self.pageProgress:SetText(message)
        -- Keep an already opened manuscript in place while its update runs.
        if self.shelf=='chronicle' and (self.story or self.threadPlan) then return end
        if self.loadingMessage==message then return end;self.loadingMessage=message
        self.document:SetBlocks({{kind='title',text=self.shelf=='lore' and 'Opening Lore of Azeroth' or 'Opening your story'},
            {text=message},{kind='meta',text='Your saved history is kept. These reading pages are still being prepared.'}})
    end
    function p:SaveBookmark()
        if not self.provider or not self.provider:Allowed() then return end
        local b={owner=self.owner,shelf=self.shelf or 'chronicle',offset=self.scroll:GetVerticalScroll(),anchor=self.document:GetReadingAnchor()}
        if self.shelf=='lore' then if not self.loreID or not ns.Athena.Knowledge.GetLore(self.loreID,self:LoreContext()) then return end;b.loreID=self.loreID
        else b.threadId=self.threadId;b.volumeId=self.volumeId;b.storyId=self.selected end
        self.bookmark=b;self.bookmarks[#self.bookmarks+1]=b;if #self.bookmarks>16 then table.remove(self.bookmarks,1) end
        self.status:SetText('Reading place bookmarked for this character in this session.')
    end
    function p:RestoreBookmark(b)
        if not b or not self.provider or not self.provider:Allowed() or b.owner and b.owner~=self.owner then return end
        if b.shelf=='lore' then
            if self.shelf~='lore' then self:SetShelf('lore') end
            self:OpenLore(b.loreID);if self.loreID then self.scroll:SetVerticalScroll(b.offset or 0);self.document:RestoreReadingAnchor(b.anchor) end;return
        end
        if self.shelf=='lore' then self:SetShelf('chronicle') end
        self.threadId=b.threadId;self.volumeId=b.volumeId;self.nextReadOffset=b.offset;self.readOffset=b.offset
        if b.storyId then self:OpenStory(b.storyId);self.document:RestoreReadingAnchor(b.anchor) elseif b.threadId then self:OpenThread(b.threadId,b.volumeId);self.scroll:SetVerticalScroll(b.offset);self.document:RestoreReadingAnchor(b.anchor) end
    end
    function p:Recompose()
        if self.job and not self.job.done then return end
        self.readOffset=self.scroll:GetVerticalScroll();self.nextReadOffset=self.readOffset
        local id=self.selected;self.library.stories={};self.library.byID={};self.story=nil
        if id then self.requestedStory=id;self:Start({storyId=id},true)
        else local ts=self.library.index and self.library.index.threads;local threadId=self.threadId or ts and ts.lifeId;self:Start(threadId and {threadId=threadId,volumeId=self.volumeId} or nil,true) end
    end
    function p:Regenerate(skipQuestions)
        if not self.provider or not self.provider:Allowed() then return end
        if self.job and not self.job.done then self.pageProgress:SetText('A new telling is already being prepared.');return end
        if not skipQuestions and ns.DB.journalAskRecollections~=false and self:OpenRecollections(true) then return end
        ns.DB.journalEditions=ns.DB.journalEditions or {}
        ns.DB.journalEditions[self.owner]=((tonumber(ns.DB.journalEditions[self.owner]) or 0)+1)%1000000
        ns.DB.journalEditionRevision=(tonumber(ns.DB.journalEditionRevision) or 0)+1
        -- A new reading seed changes composition, never the evidence. Keep the
        -- completed page while the replacement passes the normal source path.
        self:Recompose()
    end
    function p:Follow(id)
        if not id or not self.provider or not self.provider:Allowed() then return end
        if id:match('^lore:') then self:OpenLore(id);return end
        if id:sub(1,6)=='intel:' then
            local guid=id:sub(7)
            if not self.provider.demo and ns.Modules.Enabled('intel') and self.story and self.story.participants[guid] then
                ns.WardenUI.Navigate('player',self.owner,guid,nil,{kind='story',owner=self.owner,id=self.selected})
            end
            return
        end
        self.breadcrumbs[#self.breadcrumbs+1]={threadId=self.threadId,volumeId=self.volumeId,storyId=self.selected,offset=self.scroll:GetVerticalScroll(),collection=self.collection}
        if #self.breadcrumbs>16 then table.remove(self.breadcrumbs,1) end
        if id:sub(1,9)=='thread/1/' then self:OpenThread(id) else self:OpenStory(id) end
    end
    function p:ReturnPath()
        local b=table.remove(self.breadcrumbs);if not b then return end
        self.collection=b.collection;self.threadId=b.threadId;self.volumeId=b.volumeId;self.nextReadOffset=b.offset;self.readOffset=b.offset
        if b.storyId then self:OpenStory(b.storyId);self.document:RestoreReadingAnchor(b.anchor) elseif b.threadId then self:OpenThread(b.threadId,b.volumeId);self.scroll:SetVerticalScroll(b.offset) end
    end
    function p:SetMode()
        if host.syntheticLabel then host.syntheticLabel:Hide() end
        self:Clear();self.destination='journey';self.drawerCollapsed=true;self.provider,self.owner=J.Live(),self:Owner();self.modeText:SetText('Chronicle of '..ns.WardenUI.OwnerName(self.owner));self.demo:Hide();self:Start()
    end
    function p:SetSimulation(provider,owner)
        if host.syntheticLabel then host.syntheticLabel:Show() end
        self:Clear();self.destination='journey';self.drawerCollapsed=true;self.provider=provider;self.owner=owner;self.modeText:SetText('SYNTHETIC — private Lab evidence');self.demo:Show();self:Start()
    end
    function p:Start(cursor,append)
        if self.job and not self.job.done then return end
        if not self.provider then self:SetMode();return end
        if not self.provider:Allowed() then self:Clear();self.status:SetText(messages.DENIED);self.notice:SetText('Your Journey is private. Enable ChronicleWarden and permitted local history to read it. Existing history is kept.');self.notice:Show();return end
        local owner=self.provider.demo and self.owner or self:Owner();local token=self.provider.Identity and self.provider:Identity(owner)
        if owner~=self.owner or self.identity and not J.SameHistory(self.identity,token) then self:Clear() end
        self.owner=owner;self.identity=token;self.library=self.library or J.Library()
        if not self.snapshotChecked then self.snapshotChecked=true;ns.AthenaReadingSnapshots.Restore(self) end
        self.readFailure=nil;self.loadingMessage=nil
        if not cursor and self.library.index and not self.provider.Identity then self.library.index=nil end
        if not cursor and self.collection~='all' then cursor={threadId=self.threadId or ns.AthenaStoryThreads.ID(owner,'LIFE','life'),volumeId=self.volumeId,fromBeginning=not self.library.index} end
        self.scopeSignature=ns.AthenaStoryContributions.Signature();self.permissionSignature=ns.AthenaStoryContributions.PermissionSignature()
        self.job=J.New(self.provider,owner,cursor,self.library);self.rendered=false;self.appending=append;self.older:SetEnabled(false);self.refresh:SetEnabled(false)
        self:ShowLoading()
    end
    function p:BeginSearch(query)
        if self.shelf=='lore' then self.lorePage=1;self.loreCursor=nil;self:RenderLoreList(query);return end
        self.searchResults=nil;self.searchJob=nil
        query=type(query)=='string' and query:lower() or ''
        if #query<2 then self:RenderLibrary();return end
        local ix=self.library and self.library.index;if not ix then return end
        local signature=self.scopeSignature;self.searchJob=coroutine.create(function()
            local result={}
            for i,node in ipairs(ix.nodes) do
                if not self.provider:Allowed() or signature~=ns.AthenaStoryContributions.Signature() then return end
                local label=ns.AthenaStoryPlanner.Text(node.place and (node.place.instanceName or node.place.zone),'A recorded moment')
                local match=label:lower():find(query,1,true)
                if not match then for guid in pairs(node.participants or {}) do for _,a in ipairs(ix.aliases[guid] or {}) do if a.at<=node.lastObservedAt and a.name:lower():find(query,1,true) then match=true;break end end;if match then break end end end
                local cached=self.library.byID[node.storyId]
                if not match and cached then match=(cached.title..' '..tostring(cached.narrativeSearch or '')):lower():find(query,1,true) end
                if match and not node.suppressed then result[#result+1]={kind='search',storyId=node.storyId,title=cached and cached.title or label,subtitle=Stamp(node.firstObservedAt)..' • Open chapter'} end
                if #result>=60 then break end
                if i%128==0 then coroutine.yield() end
            end
            self.searchResults=result;self:RenderLibrary()
        end)
    end
    function p:RenderLibrary()
        if self.shelf=='lore' then self:RenderLoreList();return end
        if self.searchResults then self.list:SetItems(self.searchResults,true);return end
        self.category:SetShown(self.collection=='all');self.sort:SetShown(self.collection=='all')
        local choices={{'life','The Journey'},{'archive','All chapters'},{'questing','Questing'},{'dungeons','Dungeons'},{'raids','Raids'},{'battlegrounds','Battlegrounds'},{'duels','Duels / PvP'},{'world','World events'},{'guild','Guild & company'},{'pvp','All PvP (legacy)'},{'expeditions','All Expeditions (legacy)'}};local ts=self.library and self.library.index and self.library.index.threads
        for _,entry in ipairs({{'places','Places & Paths'},{'adventures','Growth & Other Chapters'},{'people','People & Company'},{'guild','Guild & Fellowship'},{'watch','The Watch'},{'protections','Private Protections'},{'sightings','Historical Sightings'}}) do
            local permitted=(entry[1]~='protections' or ns.AthenaStoryContributions.Visible('historical_incident',self.provider)) and (entry[1]~='sightings' or ns.AthenaStoryContributions.Visible('signal_sighting',self.provider))
            local any=false;for _,t in ipairs(ts and ts.threads or {}) do if t.collection==entry[1] and t.episodeCount>0 then any=true;break end end
            if permitted and any then choices[#choices+1]=entry end
        end
        for id,mode in pairs(self.readerModes) do choices[#choices+1]={id,mode.label} end
        choices[#choices+1]={'archive','Complete Chronicle'};choices[#choices+1]={'conversations','Conversations & Memories'};choices[#choices+1]={'all','Original evidence & passages'}
        for i=#self.collectionChoices,1,-1 do self.collectionChoices[i]=nil end;for _,v in ipairs(choices) do self.collectionChoices[#self.collectionChoices+1]=v end
        for i=#self.overflowChoices,1,-1 do if self.overflowChoices[i][1]=='lab' then table.remove(self.overflowChoices,i) end end;if self.provider and self.provider.demo then self.overflowChoices[#self.overflowChoices+1]={'lab','Return to private Lab'} end;self.overflow:Refresh()
        self.collectionMenu:Refresh()
        if self.collection~='all' then
            local ix=self.library and self.library.index;local ts=ix and ix.threads;local rows={}
            if ts then
                local selected=ts.byID[self.threadId or ts.journeyId or ts.lifeId]
                if self.collection=='life' and selected then
                    local allowed={};for _,sid in ipairs(selected.episodeIds) do local ch=ix.narrative.chapterKeys[sid];if ch then allowed[ch.id]=true end end
                    for _,cid in ipairs(ix.narrative.chapterOrder) do local c=ix.narrative.chapters[cid]
                        if allowed[cid] then rows[#rows+1]={kind='chapter',id=cid,threadId=selected.id,volumeId=c.volumeId,title=self.chapterTitles and self.chapterTitles[cid] or c.title,subtitle=Stamp(c.at)} end
                    end
                else for _,t in ipairs(ts.threads) do if t.collection==self.collection then rows[#rows+1]={kind='thread',id=t.id,title=t.title,subtitle=t.episodeCount..(t.episodeCount==1 and ' chapter • ' or ' chapters • ')..#t.volumeIds..(#t.volumeIds==1 and ' volume' or ' volumes')} end end end
            end
            self.list:SetItems(rows,true);self:Layout(self:GetWidth(),self:GetHeight());return
        end
        local rows={};for _,s in ipairs(self.library and self.library.stories or {}) do
            if s.supportState~='INSUFFICIENT' and (self.filter=='all' or s.form==self.filter or self.filter=='featured' and s.featured) then rows[#rows+1]=s end
        end
        table.sort(rows,function(a,b)
            if self.order=='important' and a.featured~=b.featured then return a.featured end
            if a.firstObservedAt~=b.firstObservedAt then return self.order=='oldest' and a.firstObservedAt<b.firstObservedAt or self.order~='oldest' and a.firstObservedAt>b.firstObservedAt end
            return a.storyId<b.storyId
        end)
        self.visibleStories=rows;self.list:SetItems(rows,true);self.previous:SetEnabled(#rows>1);self.next:SetEnabled(#rows>1)
    end
    function p:Step(delta)
        if self.TurnReadingPage and self:TurnReadingPage(delta) then return end
        if self.threadId and self.selected and self.view=='reading' then
            local ts=self.library.index and self.library.index.threads;local thread=ts and ts.byID[self.threadId]
            for i,id in ipairs(thread and thread.episodeIds or {}) do if id==self.selected then
                local target=thread.episodeIds[i-delta]
                if target then
                    for _,vid in ipairs(thread.volumeIds) do for _,sid in ipairs(ts.volumes[vid].episodeIds) do if sid==target then self.volumeId=vid end end end
                    self:OpenStory(target)
                end
                return
            end end
        end
        if self.view=='thread' then
            local ts=self.library.index.threads;local thread=ts.byID[self.threadId]
            for i,id in ipairs(thread and thread.volumeIds or {}) do if id==self.volumeId then local nextId=thread.volumeIds[i-delta];if nextId then self:OpenThread(thread.id,nextId) end;return end end
            return
        end
        local rows=self.visibleStories or {};for i,s in ipairs(rows) do if s.storyId==self.selected then self:ShowStory(rows[(i-1+delta)%#rows+1]);return end end;self:ShowStory(rows[1])
    end
    function p:SetCollection(value)
        if not self.provider or not self.provider:Allowed() then self:Clear();return end
        if self.readerModes[value] then self.readerModes[value].open(self);return end
        if value=='conversations' then self:ShowMemories();return end
        self.relatedExpanded=nil
        if value~=self.collection then self.savedReading=nil;self.story=nil;self.threadPlan=nil;self.document:SetBlocks({}) end
        self.collectionState[self.collection]={threadId=self.threadId,volumeId=self.volumeId,offset=self.scroll:GetVerticalScroll(),story=self.selected}
        self.searchResults=nil;self.searchJob=nil;self.collection=value;local state=self.collectionState[value]
        self.category:SetShown(value=='all');self.sort:SetShown(value=='all');self:Layout(self:GetWidth(),self:GetHeight())
        -- An unfinished read has no published index yet. Absence at that
        -- point means waiting, not an empty archive. Finish the shared read
        -- before opening the requested collection's own source window.
        if self.job and not self.job.done or not self.library.index then
            self.pendingCollection=value;self:RenderLibrary();ns.AthenaReadingSnapshots.Restore(self,value);self:ShowLoading();return
        end
        self.pendingCollection=nil
        if value=='all' then self.threadId=nil;self.volumeId=nil;self.threadPlan=nil;self.older:SetText('Older passages');self:RenderLibrary();if not self.allLoaded then self.story=nil;self.library.stories={};self.library.byID={};self:Start(nil,false) else self:ShowStory(state and self.library.byID[state.story] or self.visibleStories[1]) end;return end
        local ts=self.library.index and self.library.index.threads
        local id=state and state.threadId
        if not id or not ts or not ts.byID[id] or ts.byID[id].collection~=value then id=nil;for _,t in ipairs(ts and ts.threads or {}) do if t.collection==value then id=t.id;break end end end
        if id then self:OpenThread(id,state and state.volumeId);if state then self.scroll:SetVerticalScroll(state.offset or 0) end
        else self.threadId=nil;self.volumeId=nil;self.story=nil;self.threadPlan=nil;self.related:Hide();self.back:Hide();self.evidence:SetEnabled(false);self.document:SetBlocks({{kind='title',text='The next chapter awaits'},{text='This collection has no supported chapters in the available archive.'}});self:RenderLibrary() end
    end
    function p:VolumeEdge(latest)
        local ts=self.library.index and self.library.index.threads;local thread=ts and ts.byID[self.threadId]
        if thread then self:OpenThread(thread.id,thread.volumeIds[latest and #thread.volumeIds or 1]) end
    end
    function p:OpenThread(id,volumeId)
        if not self.provider or not self.provider:Allowed() then self:Clear();return end
        local ts=self.library.index and self.library.index.threads;local t=ts and ts.byID[id]
        if not t then self.status:SetText('This book is unavailable in the permitted archive.');return end
        if self.threadId and self.view=='thread' then self.threadPositions[self.threadId]={volumeId=self.volumeId,offset=self.scroll:GetVerticalScroll()} end
        local remembered=not volumeId and self.threadPositions[id]
        volumeId=volumeId or remembered and remembered.volumeId
        local v=ns.AthenaStoryThreads.ResolveVolume(self.library.index,t,volumeId)
        if v and v.threadId~=id then v=nil end
        self.collection=t.collection;self.threadId=id;self.volumeId=v and v.id;self.evidenceFromThread=nil;self.pendingThread=true
        self.story=nil;self.selected=nil;self.readOffset=remembered and remembered.offset or 0;self.scroll:SetVerticalScroll(self.readOffset)
        local ready=true;for _,sid in ipairs(v and v.episodeIds or {}) do local s=self.library.byID[sid];if not s or s.indexSerial~=self.library.index.serial then ready=false;break end end
        if ready then self.pendingThread=nil;self:ShowThread();self:RenderLibrary()
        else self:Start({threadId=id,volumeId=self.volumeId},true) end
    end
    function p:ShowThread()
        if not self.provider or not self.provider:Allowed() then self:Clear();return end
        local ix=self.library.index;local ts=ix and ix.threads;local t=ts and ts.byID[self.threadId];local v=t and ts.volumes[self.volumeId]
        if not t then return end
        self.sourceRail:Hide();self.scroll:Show()
        local plan=ns.Metis.PlanThread(t,v,self.library);self.threadPlan=plan;self.view='thread';self.evidenceFromThread=nil
        self.pageProgress:SetText('Reading '..tostring(v and v.ordinal or 1)..' / '..math.max(1,#t.volumeIds)..' • '..self.length)
        self.title:SetText('Athena’s Journal');self.modeText:SetText((self.provider.demo and 'SYNTHETIC • ' or '')..'The Journey • '..ns.Metis.Voice()..' • Metis')
        local blocks=ns.Metis.FrontMatter(plan,t,v,ix,self.provider.demo)
        local paragraphs,why=ns.Metis.TryRender(plan,self.length)
        if not paragraphs then
            self.readFailure={status='UNAVAILABLE',detail=why};self.pageProgress:SetText('Existing reading kept • Metis update paused')
            if self.document:GetText()=='' then self:ShowLoading() end
            return
        end
        self.chapterTitles=self.chapterTitles or {};for _,chapter in ipairs(plan.manuscriptChapters or {}) do self.chapterTitles[chapter.id]=chapter.title end
        self.threadParagraphs=paragraphs
        self.currentChapter=self.requestedChapter or plan.manuscriptChapters and plan.manuscriptChapters[1] and plan.manuscriptChapters[1].id
        self.context:SetBlocks({{kind='title',text=t.title},{kind='meta',text='One life • connected chapters'},{text=v and 'Scenes share one manuscript. Open Sources & Limits for the original observations.' or 'No new chapters yet.'},{kind='meta',text='Narration: '..ns.AthenaChronicler.Voice()..' • '..self.length}})
        local priorStory,priorTitle
        for _,b in ipairs(paragraphs) do
            local chapter=b.chapterId or b.storyId
            local newChapter=chapter~=priorStory
            local heading=newChapter and b.title~=priorTitle and not b.interlude
            if heading then blocks[#blocks+1]={id='chapter/'..chapter,kind='heading',text=b.title} end
            priorStory=chapter;priorTitle=b.title
            local ref=b.privateMemory and not b.literal and b.memoryRefs and b.memoryRefs[1]
            local publicText={};for _,clause in ipairs(b.clauses or {}) do if not clause.ownerPrivate then publicText[#publicText+1]=clause.text end end
            blocks[#blocks+1]={id=newChapter and not heading and 'chapter/'..chapter or b.blockId,paragraphId=b.blockId,text=b.text,snapshotText=b.ownerPrivate and table.concat(publicText,' ') or nil,literal=b.literal==true,recollection=b.recollection,privateMemory=b.privateMemory,ownerPrivate=b.ownerPrivate,tone=ref and 'meta' or nil,tooltip=ref and 'Open the owner-private conversation folio. Excerpts stay concealed until you Reveal them.' or nil,tooltipTitle=ref and 'Selected memory' or nil,activate=ref and function() self:OpenMemory(ref) end or nil}
        end
        if #paragraphs==0 then blocks[#blocks+1]={text='No new chapters yet. Your retained observations remain in Chapters and the original archive.'} end
        -- Provenance and gap diagnostics belong in the source drawer.
        local wasSaved=self.savedReading
        ns.AthenaBookIllustrations.ReadingBlocks(self,blocks,paragraphs)
        blocks=ns.AthenaReadingSnapshots.EditionBlocks(self,blocks)
        self.document:SetBlocks(blocks);self.scroll:SetVerticalScroll(self.readOffset or 0);
        self.savedReading=nil;ns.AthenaReadingSnapshots.Save(self,blocks)
        if not wasSaved and ns.DB.journalReducedMotion==false then self.document:RevealWords(32) end
        if self.requestedChapter then
            self.pendingChapterAnchor={id='chapter/'..self.requestedChapter,block=1,offset=0}
            if not self.turnState then self.document:RestoreReadingAnchor(self.pendingChapterAnchor);self.pendingChapterAnchor=nil end
            self.requestedChapter=nil
        end
        self.nextReadOffset=nil;self.sourceMenu:Hide();self.original:Hide();self.back:SetText('Previous book');self.back:SetShown(#self.breadcrumbs>0);self.evidence:SetEnabled(#plan.episodes>0)
        self.older:SetText('Read from Beginning');self.older:SetEnabled(v~=nil);self.previous:SetEnabled(v and v.ordinal>1 or false);self.next:SetEnabled(v and v.ordinal<#t.volumeIds or false)
        for i=#self.relatedChoices,2,-1 do self.relatedChoices[i]=nil end
        self.relatedChoices[1]={false,'Chapters & related books'};local seen={}
        for _,s in ipairs(plan.episodes) do self.relatedChoices[#self.relatedChoices+1]={s.storyId,Stamp(s.firstObservedAt)..' • '..s.title}
            for _,tid in ipairs(ns.AthenaStoryThreads.Related(ix,s.storyId)) do if tid~=t.id and not seen[tid] then seen[tid]=true;self.relatedChoices[#self.relatedChoices+1]={tid,ts.byID[tid].title} end end
        end
        self.related:Refresh();self.related:SetShown(self.relatedExpanded==true and #self.relatedChoices>1)
    end
    function p:ThreadEvidence()
        self.sourceRail:Show();self.scroll:Hide()
        if not self.provider:Allowed() then self:Clear();return end
        self.readOffset=self.scroll:GetVerticalScroll();self.evidenceFromThread=true;self.view='evidence';self.related:Hide();self.back:SetText('Back to book')
        local blocks={{kind='title',text=(self.provider.demo and 'SYNTHETIC — ' or '')..'Book sources / limits'},{kind='meta',text='Narrative director: Metis '..ns.Metis.VERSION},{kind='heading',text='Recorded character evidence'},{text='This reading references existing chapters. Dates establish reading order, not uninterrupted activity. Other archives and unobserved intervals remain unknown. The historical prologue describes Warcraft world history, not personal achievements; the character’s own deeds require separate recorded evidence.'}}
        blocks[#blocks+1]={text='Routine objective updates, small skill changes and quest removals without an ending remain in the original archive. Metis may omit them from the manuscript; omission never marks a quest complete or deletes its evidence.'}
        for i=#self.sourceChoices,2,-1 do self.sourceChoices[i]=nil end;local seen={}
        for _,s in ipairs(self.threadPlan and self.threadPlan.episodes or {}) do
            blocks[#blocks+1]={kind='heading',text=s.title};blocks[#blocks+1]={kind='meta',text=s.storyId..' • '..s.supportState..(s.timeCoverage.partial and ' • partial source window' or '')..(s.timeCoverage.gaps and ' • observation gaps' or '')}
            for _,c in ipairs(s.factualClaims) do blocks[#blocks+1]={text=c.claimType..' • '..c.confidence};blocks[#blocks+1]={kind='meta',text=c.claimId..'\n'..table.concat(c.evidenceRefs,'\n')} end
            for _,ref in ipairs(s.sourceEvidenceRefs) do if not seen[ref] then seen[ref]=true;self.sourceChoices[#self.sourceChoices+1]={ref,ref} end end
        end
        blocks[#blocks+1]={kind='heading',text='World references'}
        local worldSeen={}
        for _,card in ipairs(self.threadPlan and self.threadPlan.prologue or {}) do
            blocks[#blocks+1]={kind='heading',text='WORLD HISTORY • '..card.title};blocks[#blocks+1]={text=card.worldRef..'\n'..card.sourceURL}
        end
        for _,para in ipairs(self.threadParagraphs or {}) do for _,card in ipairs(para.worldFacts or {}) do if not worldSeen[card.worldRef] then
            worldSeen[card.worldRef]=true;blocks[#blocks+1]={kind='heading',text=(card.kind=='WORLD_HISTORY' and 'WORLD CONTEXT • ' or 'QUEST REFERENCE • ')..card.title}
            blocks[#blocks+1]={text=card.worldRef..'\n'..(card.confidence or 'SOURCE_CONTEXT')..' • '..(card.sourceVersion or ns.Athena.Knowledge.Version().version)..'\n'..card.sourceURL..(card.questWorldRef and ('\nQuest context: '..card.questWorldRef) or '')..'\n'..tostring(para.qualification or 'World context has its own reference. Personal deeds and quest stages have separate original sources.')}
        end end end
        self.inspector:SetBlocks(blocks);self.inspectorScroll:SetVerticalScroll(0);self.sourceMenu:Refresh();self.sourceMenu:Show();self.original:Show();self.original:SetEnabled(false);self.back:Show()
    end
    function p:OpenStory(id)
        local story=self.library and self.library.byID[id];local index=self.library and self.library.index
        if story and (not index or story.indexSerial==index.serial) then self:ShowStory(story);return end
        local node=index and (index.byStory[id] or index.byActivity[id])
        if not node then self.status:SetText('This related chapter is unavailable in the permitted archive.');return end
        self.requestedStory=node.storyId;self:Start({storyId=node.storyId},true)
    end
    function p:ShowStory(story,restore)
        self.sourceRail:Hide();self.scroll:Show()
        if not self.provider or not self.provider:Allowed() then self:Clear();self.status:SetText(messages.DENIED);return end
        if story and self.library.index and story.indexSerial~=self.library.index.serial then self:OpenStory(story.storyId);return end
        local old=self.story;local same=old and story and old.storyId==story.storyId
        local offset=same and ((restore or self.view~='reading') and self.readOffset or self.scroll:GetVerticalScroll()) or 0
        self.story=story;self.selected=story and story.storyId;self.view='reading';self.evidenceFromThread=nil;self.evidenceRef=nil;self.sourceMenu:Hide();self.original:Hide();self.back:SetShown(self.threadId~=nil);self.back:SetText('Return to book');self.evidence:SetEnabled(story~=nil)
        self.pageProgress:SetText(story and (Stamp(story.firstObservedAt)..' • '..self.length) or 'Your first chapter awaits')
        local blocks={};if self.provider.demo then blocks[#blocks+1]={kind='heading',text='SYNTHETIC — private Lab evidence'} end
        if not story then
            blocks[#blocks+1]={kind='title',text='The next passage awaits'};blocks[#blocks+1]={text='No supported passage is ready in this part of your library. Older passages may contain another chapter.'}
        else
            blocks[#blocks+1]={kind='title',text=story.title};blocks[#blocks+1]={kind='meta',text=Stamp(story.firstObservedAt)..' • '..(story.form=='SAGA' and 'Saga' or story.form=='CHAPTER' and 'Chapter' or 'Moment')}
            local paragraphs,why=ns.Metis.TryStory(story,self.length)
            if not paragraphs then self.readFailure={status='UNAVAILABLE',detail=why};self.pageProgress:SetText('Existing reading kept • Metis update paused');if self.document:GetText()=='' then self:ShowLoading() end;return end
            for _,b in ipairs(paragraphs) do local ref=b.privateMemory and not b.literal and b.memoryRefs and b.memoryRefs[1];blocks[#blocks+1]={id=b.blockId,text=b.text,literal=b.literal==true,recollection=b.recollection,ownerPrivate=b.ownerPrivate,tone=ref and 'meta' or nil,tooltip=ref and 'Open the owner-private conversation folio.' or nil,tooltipTitle=ref and 'Selected memory' or nil,activate=ref and function() self:OpenMemory(ref) end or nil} end
            if story.supportState=='QUALIFIED' then blocks[#blocks+1]={kind='meta',text='* Sources / limits'} end
        end
        self.document:SetBlocks(blocks);self.scroll:SetVerticalScroll(self.nextReadOffset or offset or 0);self.nextReadOffset=nil
        if self.threadId and self.library.index then
            local t=self.library.index.threads.byID[self.threadId]
            for i,id in ipairs(t and t.episodeIds or {}) do if id==self.selected then self.previous:SetEnabled(i>1);self.next:SetEnabled(i<#t.episodeIds);break end end
        end
        for i=#self.relatedChoices,2,-1 do self.relatedChoices[i]=nil end
        local seen={}
        for _,id in ipairs(story and ns.AthenaStoryThreads.Related(self.library.index,story.storyId) or {}) do
            local t=self.library.index.threads.byID[id];self.relatedChoices[#self.relatedChoices+1]={id,t.title};seen[id]=true
        end
        if story and not self.provider.demo and ns.Modules.Enabled('intel') then
            local guids={};for guid in pairs(story.participants or {}) do guids[#guids+1]=guid end;table.sort(guids)
            for i=1,math.min(8,#guids) do self.relatedChoices[#self.relatedChoices+1]={'intel:'..guids[i],'Open recorded player dossier • '..guids[i]} end
        end
        for _,link in ipairs(story and story.plan and story.plan.links or {}) do
            local prior=self.library.byID[link.storyId] or self.library.index and self.library.index.byStory[link.storyId]
            if prior and not seen[prior.storyId] then
                seen[prior.storyId]=true;local title=prior.title or (prior.type=='SAGA' and 'Saga • ' or '')..(prior.place.instanceName or prior.place.zone or 'An earlier adventure')
                self.relatedChoices[#self.relatedChoices+1]={prior.storyId,title..' • '..Stamp(prior.firstObservedAt)}
            end
        end
        self.related:Refresh();self.related:SetShown(self.relatedExpanded==true and #self.relatedChoices>1);self.list:Render()
    end
    function p:ShowEvidence()
        self.sourceReturnPlace=self:BookPlace()
        if self.readFailure then
            self.sourceRail:Show();self.scroll:Hide();self.sourceMenu:Hide();self.original:Hide()
            self.inspector:SetBlocks({{kind='title',text='Journal reading could not finish'},
                {text=self.readFailure.status},{kind='meta',text=self.readFailure.detail},
                {text='Your original history has been kept. Use Book actions → Update story to try again.'}});return
        end
        if self.shelf=='lore' then self:ShowLoreSources();return end
        self.sourceRail:Show();self.scroll:Hide()
        if not self.provider:Allowed() then self:Clear();return end
        if self.view=='thread' then self:ThreadEvidence();return end
        if not self.story then return end
        if self.view=='reading' then self.readOffset=self.scroll:GetVerticalScroll() end
        self.view='evidence';self.evidenceFromThread=nil;self.back:SetText('Back to reading');self.related:Hide()
        local s=self.story;local blocks={{kind='title',text=self.provider.demo and 'SYNTHETIC — Sources / limits' or 'Sources / historical limits'},
            {text=s.storyStatus..' • '..s.supportState..' • '..#s.sourceEvidenceRefs..' sources'},
            {kind='meta',text='Coverage: '..(s.timeCoverage.partial and 'partial source window; ' or '')..(s.timeCoverage.unknownStart and 'arrival unknown; ' or '')..(s.timeCoverage.unknownEnd and 'departure unknown; ' or '')..(s.timeCoverage.gaps and 'observation gaps; ' or '')..'Continuity covers this validated observer archive. Unavailable archives and unseen intervals remain unknown.'}}
        for _,c in ipairs(s.factualClaims) do
            blocks[#blocks+1]={kind='heading',text=c.claimType:gsub('_',' ')}
            local values={};if type(c.value)=='table' then for _,key in ipairs({'count','boss','itemID','name','guid','zone','spellID','priorStory','before','after','questID','achievementID','objective','fulfilled','required','finished','slot','result','outcome','at'}) do if c.value[key]~=nil then values[#values+1]=key..': '..tostring(c.value[key]) end end else values[1]=tostring(c.value) end
            blocks[#blocks+1]={text=table.concat(values,' • ')};blocks[#blocks+1]={kind='meta',text=c.confidence..'\n'..table.concat(c.evidenceRefs,'\n')..(#c.disclaimers>0 and '\n'..table.concat(c.disclaimers,'; ') or '')}
        end
        for i=#self.sourceChoices,2,-1 do self.sourceChoices[i]=nil end
        for _,ref in ipairs(s.sourceEvidenceRefs) do self.sourceChoices[#self.sourceChoices+1]={ref,ref} end
        self.inspector:SetBlocks(blocks);self.inspectorScroll:SetVerticalScroll(0);self.sourceMenu:Refresh();self.sourceMenu:Show();self.original:Show();self.original:SetEnabled(self.evidenceRef~=nil);self.back:Show()
    end
    function p:OpenEvidence()
        if not self.evidenceRef or not self.provider:Allowed() then return end
        local found=false
        for _,s in ipairs(self.evidenceFromThread and self.threadPlan and self.threadPlan.episodes or self.story and {self.story} or {}) do
            for _,ref in ipairs(s.sourceEvidenceRefs) do if ref==self.evidenceRef then found=true;break end end
        end
        if not found then return end
        if self.evidenceRef:match('^conversation%-moment/1/') then self:OpenMemory(self.evidenceRef);return end
        self.pendingSource={ref=self.evidenceRef};self.status:SetText('Checking the original source…')
    end
    function p:SourceStep()
        local request=self.pendingSource;local e,state=self.provider:Resolve(request.ref)
        if not e then local message=messages[state] or 'The original source is unavailable.';if state~='INDEXING' and state~='LOAD_WAIT' and state~='LINK_PENDING' and state~='building' and state~='loading' then self:Clear() end;self.status:SetText(message);return end
        if e.observer~=self.owner or e.evidenceRef~=request.ref or e.accessScope=='PRIVATE_INCIDENT' or e.sourceContext and e.sourceContext.accessScope=='PRIVATE_INCIDENT' then self.pendingSource=nil;self.status:SetText(messages.DENIED);return end
        if e.storyPrivateProjection then
            self.inspector:SetBlocks({{kind='title',text='Private local protection source'},{text='Original ref: '..e.evidenceRef..'\nObserved: '..Stamp(e.observedAt)..'\nOwn action only. Raw text and other players’ identities are excluded.'}})
            self.pendingSource=nil;return
        end
        if self.provider.demo then
            self.inspector:SetBlocks({{kind='title',text='SYNTHETIC — Original source'},{kind='heading',text=e.source or 'Source'},
                {text=e.evidenceRef..'\nObserver: '..e.observer..'\nObserved: '..Stamp(e.observedAt)..'\nIsolated test evidence; never a gameplay record.'}});self.pendingSource=nil;return
        end
        local rows=ns.RecordingUI.Request({owner=e.observer,eventID=e.sourceRecordRef,mode='all',raw=true,page=0});if not rows then return end
        for _,row in ipairs(rows) do if row.id==e.sourceRecordRef then self.pendingSource=nil;ns.RecordingUI.OpenSource(nil,row);return end end
        self.pendingSource=nil;self.status:SetText('The original source is no longer available.')
    end
    function p:Refresh()
        if not self.provider then self:SetMode();return end
        if not self.provider:Allowed() then if not self.provider.demo then ns.AthenaReadingSnapshots.Clear(self.owner) end;self:Clear();self.status:SetText(messages.DENIED);self.notice:SetText('Your Journey is private. Enable ChronicleWarden and permitted local history to read it. Existing history is kept.');self.notice:Show();return end
        if self.savedReading and not ns.AthenaReadingSnapshots.Valid(self) then ns.AthenaReadingSnapshots.Clear(self.owner);self.savedReading=nil;self.document:SetBlocks({}) end
        self.notice:Hide()
        local recollectionSignature=ns.AthenaRecollections.Signature(self.provider,self.owner)
        if self.recollectionSignature and self.recollectionSignature~=recollectionSignature then
            self.recollectionSignature=recollectionSignature;self.savedReading=nil;self.document:SetBlocks({});self.threadParagraphs=nil
            if not self.job or self.job.done then self:Recompose() end
        end
        self.recollectionSignature=recollectionSignature
        local memoryService=self:MemoryService();local memorySignature=memoryService and memoryService.Signature(self.owner) or 'NO_CONVERSATIONS'
        if self.memorySignature and self.memorySignature~=memorySignature then
            if not self.provider.demo then ns.AthenaReadingSnapshots.Clear(self.owner) end;self.savedReading=nil
            self.memorySignature=memorySignature;self.memoryReveal=false;self.memoryRows=nil;self.memoryRail.body:SetBlocks({});self.memoryRail.settings:Hide()
            self.memoryRail.privateEdit:Hide();self.memoryRail.editBody:SetText('');self.memoryRail.editTitle:SetText('')
            -- A permission boundary must remove visible and hidden derived
            -- excerpts immediately, before the cooperative compositor resumes.
            self.document:SetBlocks({});self.inspector:SetBlocks({});self.threadParagraphs=nil;self.threadPlan=nil;self.story=nil;self.job=nil
            self.library.stories={};self.library.byID={};self.searchResults=nil;self.searchJob=nil
            for i=#self.sourceChoices,2,-1 do self.sourceChoices[i]=nil end
            if self.memoryRail:IsShown() then self:ShowMemories() else self:Recompose() end
            return
        end
        self.memorySignature=memorySignature
        if self.scopeSignature and self.scopeSignature~=ns.AthenaStoryContributions.Signature() then
            if self.permissionSignature~=ns.AthenaStoryContributions.PermissionSignature() then self:Clear();self.status:SetText('This passage’s source permissions or corrections changed. Refreshing permitted pages.');self:Start()
            else self:Recompose() end
            return
        end
        if not J.ValidLibrary(self.library) then self:Clear();self:Start();return end
        if self.library.index and not ns.AthenaStoryIndex.Valid(self.library.index) then self:Clear();self:Start();return end
        local owner=self.provider.demo and self.owner or self:Owner();local token=self.provider.Identity and self.provider:Identity(owner)
        if owner~=self.owner or self.identity and not J.SameHistory(self.identity,token) then self:Clear();self.owner=owner;self:Start();return end
        if not self.identity and token then self.identity=token end
        if self.readFailure then return end
        if self.pendingSearch~=nil then self.searchWait=math.max(0,(self.searchWait or 0)-.1);if self.searchWait<=0 then local q=self.pendingSearch;self.pendingSearch=nil;self:BeginSearch(q) end end
        if self.searchJob and coroutine.status(self.searchJob)~='dead' then local ok=coroutine.resume(self.searchJob);if not ok then self.searchJob=nil;self.searchResults=nil end end
        if self.pendingSource then self:SourceStep();return end
        if not self.job then self:Start();return end
        if self.job.done and self.rendered then
            if self.shelf=='lore' then self:RefreshLore();return end
            local changed=self.identity and token and self.identity.revision~=token.revision
            self.refresh:SetText(changed and 'New chapters • Update' or 'Update My Story')
            -- New accepted gameplay is available on Update; the open page and bookmark stay stable.
            return
        end
        local perf=ns.WardenPerformance;local deadline,start=perf.Begin(1);local status,steps
        for n=1,12 do
            steps=n;status=J.Pump(self.job)
            if self.job.done or status=='COMBAT_WAIT' or perf.Expired(deadline) then break end
        end
        perf.End('Athena stories',start,steps or 0)
        local index=self.job.index;local progress
        if ns.ChronicleStore.loading and not self.provider.demo then
            local load=ns.ChronicleStore.LoadStatus();progress='Validating saved history • '..tostring(load.chunks or 0)..' / '..tostring(load.totalChunks or 0)..' chunks'
        elseif status=='INDEXING' and index then
            progress=index.phase=='activities' and 'Preparing permitted activity links…' or (index.phase=='planning' or index.phase=='threads') and 'Arranging connected chapters…'
                or index.scanned and index.frontier and ('Connecting history • '..index.scanned..' / '..index.frontier.count..' entries reviewed')
                or ('Connecting permitted history • '..#index.facts..' useful references')
        end
        self.status:SetText(progress or messages[status] or (status=='READY' and 'Passages ready.' or 'History state: '..status))
        if not self.job.done then self:ShowLoading(progress or messages[status]);return end
        self.refresh:SetEnabled(true);if status~='READY' then
            -- Retain the diagnostic instead of silently clearing/restarting
            -- this failed coroutine every UI tick (and closing its menus).
            self.readFailure={status=status,detail=self.job.index and self.job.index.error or self.job.error or 'No additional source error was returned.'}
            if self.savedReading and ns.AthenaReadingSnapshots.Valid(self) then self:ShowLoading();return end
            self.document:SetBlocks({{kind='title',text='Your story could not be opened yet'},
                {text=messages[status] or 'Athena could not finish preparing these pages.'},
                {kind='meta',text='History is kept. Book actions → Sources & Limits shows the reason; Update story retries.'}})
            self.pageProgress:SetText('Reading paused • '..status);return
        end
        -- This identity describes the actual reviewed frontier, not events
        -- that arrived while the cooperative read was in flight.
        self.identity=self.job.index and self.job.index.identity or self.identity
        self.loadingMessage=nil
        self.rendered=true;self:RenderLibrary();self.older:SetEnabled(self.library.nextCursor~=nil)
        if not self.job.cursor or self.job.cursor.offset then self.allLoaded=true end
        if not self.identity then self.identity=token end
        if self.shelf=='lore' then self:RefreshLore();return end
        if self.shelf=='memories' then return end
        if self.pendingCollection then local requested=self.pendingCollection;self.pendingCollection=nil;self.pendingThread=nil;self:SetCollection(requested);return end
        if self.requestedStory then
            local chosen=self.library.byID[self.requestedStory]
            if not chosen then for _,s in ipairs(self.library.stories) do if s.sourceActivityRefs[1]==self.requestedStory then chosen=s;break end end end
            if chosen then self.requestedStory=nil;self:OpenStory(chosen.storyId);return
            elseif self.library.index and (self.library.index.byStory[self.requestedStory] or self.library.index.byActivity[self.requestedStory]) then self:OpenStory(self.requestedStory);return
            else self.requestedStory=nil end
        end
        if self.pendingThread or self.job.storyThread then
            self.pendingThread=nil;self.threadId=self.job.storyThread and self.job.storyThread.id or self.threadId;self.volumeId=self.job.volume and self.job.volume.id or self.volumeId
            self:ShowThread();self:RenderLibrary()
        elseif not self.story then self:ShowStory(self.visibleStories[1]) end
        self.status:SetText((self.provider.demo and 'SYNTHETIC • ' or '')..#self.library.stories..' passages opened • continuity indexed across permitted history.')
        if self.openJourneyPending then self.openJourneyPending=nil;self:SetDestination('journey') end
    end
    p:HookScript('OnHide',function(self) self.document:FinishWordReveal();if self.document.ClearFocus then self.document:ClearFocus() end end)
    p:SetScript('OnSizeChanged',function(self,w,h) self:Layout(w,h) end)
    p:SetScript('OnUpdate',function(self,dt) self.tick=(self.tick or 0)+dt;if self.tick>=.1 then self.tick=0;self:Refresh() end end)
    ns.AthenaBookReader.Attach(p)
    ns.AthenaBookSections.Attach(p)
    function p:CaptureReaderPlace()
        if self.bookSection and self.sectionReturn then return self.sectionReturn.reading end
        if not self.owner then return nil end
        return {owner=self.owner,shelf=self.shelf,destination=self.destination,collection=self.collection,
            threadId=self.threadId,volumeId=self.volumeId,storyId=self.selected,loreID=self.loreID,
            anchor=self.document:GetReadingAnchor(),place=self:BookPlace()}
    end
    function p:PersistReaderPlace()
        if not self.provider or self.provider.demo or not self.provider:Allowed() then return end
        local saved=self.contentsOpen and self.contentsReturn and self.contentsReturn.reading or self:CaptureReaderPlace()
        if not saved then return end
        ns.DB.journalReaderPlacesV2=ns.DB.journalReaderPlacesV2 or {}
        ns.DB.journalReaderPlacesV2[self.owner]=saved -- reversible presentation-only preference
        local keys={};for key in pairs(ns.DB.journalReaderPlacesV2) do if key~=self.owner then keys[#keys+1]=key end end;table.sort(keys)
        while #keys>15 do ns.DB.journalReaderPlacesV2[table.remove(keys,1)]=nil end
    end
    function p:RestoreReaderPlace(saved)
        if not saved or saved.owner~=self.owner or not self.provider or not self.provider:Allowed() then return false end
        if self.bookSection then self:LeaveBookSection(false) end
        self.readerPendingPlace=saved
        self.destination=saved.destination or 'journey';self.collection=saved.collection or 'life'
        if saved.shelf=='lore' and saved.loreID then self:SetShelf('lore');self:OpenLore(saved.loreID)
        else
            if self.shelf=='lore' then self:SetShelf('chronicle') end
            if saved.storyId then self:OpenStory(saved.storyId) elseif saved.threadId then self:OpenThread(saved.threadId,saved.volumeId) end
        end
        self:ApplyPendingPlace();return true
    end
    function p:ApplyPendingPlace()
        local saved=self.readerPendingPlace;if not saved or saved.owner~=self.owner then return end
        local match=saved.shelf=='lore' and self.shelf=='lore' and saved.loreID==self.loreID
            or saved.shelf~='lore' and self.shelf~='lore' and not self.pendingThread and
                (saved.storyId and saved.storyId==self.selected or not saved.storyId and saved.threadId==self.threadId and saved.volumeId==self.volumeId)
        if match then self.readerPendingPlace=nil;self:RestoreBookPlace(saved.place or {anchor=saved.anchor}) end
    end
    for _,name in ipairs({'ShowThread','ShowStory','OpenLore'}) do
        local original=p[name]
        p[name]=function(self,...) local result=original(self,...);self:ApplyPendingPlace();return result end
    end
    local clear=p.Clear
    function p:Clear() self:PersistReaderPlace();if self.bookSection then self:LeaveBookSection(false) end;self.sectionExitTransition=nil;self.readerRestore=nil;self.readerPendingPlace=nil;clear(self) end
    local refresh=p.Refresh
    function p:Refresh()
        local requested=self.readerRestore
        refresh(self)
        if requested and self.owner==requested.owner and self.provider and self.provider:Allowed() then self.readerRestore=self.readerRestore or requested end
        if self.readerRestore and self.rendered and self.library and self.library.index and self.library.index.status=='READY' and not self.pendingThread then
            local saved=self.readerRestore;self.readerRestore=nil;self:RestoreReaderPlace(saved)
        end
    end
    p:HookScript('OnHide',function(self) self:PersistReaderPlace() end)

    p:Clear();p:Layout(1136,676);return p
end
