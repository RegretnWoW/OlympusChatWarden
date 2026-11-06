-- Book-native folios and Daybook reuse the existing reader, page geometry,
-- motion and UI2 route stack. No separate Journal window or content database.
local _,ns=...
local F={VERSION=1};ns.AthenaFinalBookUI=F
local E,D,L=ns.AthenaLibraryEditions,ns.AthenaDaybook,ns.AthenaJournalLinks
local stateKeys={'shelf','view','destination','collection','threadId','volumeId','selected','story','threadPlan','loreID','loreEntry','loreContext','currentChapter','savedReading','novelPosition','memoryReturn','bookSection','contentsOpen','sectionReturn','daybookWindow','daybookReading','editionID','libraryCopyKey','folioCollection','daybookCatalog','daybookJob','bookFlow','chapterGroupKey'}
local function shallow(t) local out={};for k,v in pairs(t or {}) do out[k]=v end;return out end
local function stamp(at) return ns.SafeCall(date,'%Y-%m-%d %H:%M',at) or 'Date uncertain' end
local function link(text,callback,tip) return {id='folio-link/'..text,text=text,kind='body',tone='heading',gap=10,activate=callback,tooltipTitle=text,tooltip=tip or 'Turn to this folio'} end
local function title(name,kicker) return {{kind='meta',text=kicker or 'ATHENA’S JOURNAL'},{kind='title',text=name}} end
function F.Attach(p)
 if p.finalBookAttached then return end;p.finalBookAttached=true;p.bookTrail={}
 local originalPlace,originalRestore=p.BookPlace,p.RestoreBookPlace
 local originalCapture,originalRestoreReader=p.CaptureReaderPlace,p.RestoreReaderPlace
 local originalClear,originalRefresh,originalLayout=p.Clear,p.Refresh,p.Layout
 local originalReturn=p.LeaveBookSection
 local writer={};p.folioWriter=writer
 local function allowed() return p.provider and p.provider:Allowed() and p.owner~=nil end
 local function returnLink() return link('Return to the marked passage',function() p:ReturnFolio() end,'Return to the exact preceding page, including reference folios.') end
 local function hideWriting()
  for _,input in ipairs(writer.inputs or {}) do input:Hide();input:ClearFocus() end
 end
 function p:CaptureFolio()
  local state={owner=self.owner,source=self:ReaderSource(),place=originalPlace(self),values={}}
  for _,key in ipairs(stateKeys) do state.values[key]=self[key] end
  return state
 end
 function p:PushFolio()
  if self.folioRestoring or self.folioReplacing then return end
  self.bookTrail[#self.bookTrail+1]=self:CaptureFolio();if #self.bookTrail>12 then table.remove(self.bookTrail,1) end
 end
 function p:ReturnFolio()
  hideWriting();self:CancelPageTurn()
  local saved=table.remove(self.bookTrail)
  if not saved and self.persistedBookTrail and #self.persistedBookTrail>0 and allowed() then return self:RestoreReaderPlace(table.remove(self.persistedBookTrail)) end
  if not saved or saved.owner~=self.owner or not allowed() then return originalReturn(self,true) end
  self.folioRestoring=true
  for _,key in ipairs(stateKeys) do self[key]=saved.values[key] end
  self.sectionWrite=true;self.document:SetBlocks(saved.source);self.sectionWrite=nil;self.scroll:Show();self.sourceRail:Hide();self.memoryRail:Hide()
  originalRestore(self,saved.place);self.folioRestoring=nil;self:BookLayout();self:LayoutFolioWriting()
 end
 function p:CloseContents(restore)
  if restore~=false and #self.bookTrail>0 then return self:ReturnFolio() end
  hideWriting();return originalReturn(self,restore~=false)
 end
 function p:Folio(id,blocks,push)
  if not allowed() then return false end
  if push~=false then self:PushFolio() end
  hideWriting();self.sourceRail:Hide();self.memoryRail:Hide()
  self:WriteBookSection(id,blocks);self:LayoutFolioWriting();return true
 end
 local function entries(blocks,rows,activate)
  for i,row in ipairs(rows) do
   if i>1 and (i-1)%10==0 then blocks[#blocks+1]={pageBreak=true};blocks[#blocks+1]={kind='heading',text='Continued'} end
   local entry=row;local printed=link(entry.title or entry.label or 'Untitled passage',function() activate(entry) end);printed.id='folio-row/'..tostring(entry.id or entry.loreID or entry.key or entry.storyId or entry.title or i);blocks[#blocks+1]=printed
   if entry.subtitle then blocks[#blocks+1]={kind='meta',text=entry.subtitle} end
  end
 end
 function p:OpenFrontispiece()
  local b=title('Athena’s Journal','THE CHRONICLES OF AZEROTH')
  b[#b+1]={text=self.library and self.library.index and self.library.index.ownerIdentity and self.library.index.ownerIdentity.name or 'A private chronicle of recorded adventures'}
  b[#b+1]={kind='meta',text='The Journey · Lore of Azeroth · Athena’s Daybook'};b[#b+1]=link('Open the Contents',function() self:OpenContents() end);b[#b+1]=returnLink();self:Folio('frontispiece',b)
 end
 -- The contents is a stable subject index, not one entry per repeat visit.
 -- All rows retain their original story/volume IDs and permitted owner index.
 function p:ChapterGroups()
  local ix=self.library and self.library.index;local ts=ix and ix.threads
  if not ts then return {} end
  local groups,order,seen={}, {},{}
  local function add(key,name,category,row)
   if seen[row.storyId or row.id]then return end;seen[row.storyId or row.id]=true
   local g=groups[key];if not g then g={id=key,title=name,category=category,rows={},at=row.at or 0};groups[key]=g;order[#order+1]=g end
   g.rows[#g.rows+1]=row;g.at=math.min(g.at,row.at or 0)
  end
  local journey=ts.byID[ts.journeyId or ts.lifeId];local allowedChapters={}
  for _,sid in ipairs(journey and journey.episodeIds or {})do local e=ts.episodes[sid];local n=e and e.node
   if n and n.type~='INSTANCE_VISIT' and n.type~='RAID_RUN' and n.type~='BATTLEGROUND_MATCH' and n.type~='BATTLEGROUND_VISIT' then
    local ch=ix.narrative.chapterKeys[sid];if ch then allowedChapters[ch.id]=true end
   end
  end
  for _,cid in ipairs(ix.narrative.chapterOrder or {})do local ch=ix.narrative.chapters[cid]
   if allowedChapters[cid]then local name=self.chapterTitles and self.chapterTitles[cid]or ch.title
    add('journey/'..name,name,'journey',{kind='chapter',id=cid,title=name,threadId=journey.id,volumeId=ch.volumeId,at=ch.at})
   end
  end
  for _,sid in ipairs(ts.chronology or {})do local e=ts.episodes[sid];local n=e and e.node;local place=n and n.place or {}
   local category=n and ({INSTANCE_VISIT='dungeon',RAID_RUN='raid',BATTLEGROUND_MATCH='battleground',BATTLEGROUND_VISIT='battleground'})[n.type]
   if category then
    local name=place.instanceName or place.zone or (category=='raid'and 'Raid expeditions'or category=='dungeon'and 'Dungeon expeditions'or 'Battles')
    local key=category..'/'..tostring(place.instanceID or name)
    add(key,name,category,{kind='search',storyId=sid,id=sid,title=name,at=n.firstObservedAt or 0})
   end
  end
  local rank={journey=1,dungeon=2,raid=3,battleground=4}
  table.sort(order,function(a,b)if a.category~=b.category then return rank[a.category]<rank[b.category]end;if a.at~=b.at then return a.at<b.at end;return a.id<b.id end)
  for _,g in ipairs(order)do table.sort(g.rows,function(a,b)if a.at~=b.at then return a.at<b.at end;return a.id<b.id end)end
  return order
 end
 function p:OpenChapterGroup(group)
  self.bookFlow='events';self.chapterGroupKey=group.id
  local b=title(group.title,'CHAPTER EVENTS');b[#b+1]=link('Back to Chapters',function()self:OpenContents()end)
  for i,row in ipairs(group.rows)do local entry=row
   b[#b+1]=link(stamp(entry.at)..' · '..(group.category=='journey'and 'Read this chapter'or 'Read this adventure'),function()
    self.readerRestore=nil;self.readerPendingPlace=nil;self.pendingChapterAnchor=nil;self.folioRouteReturn=nil
    self:LeaveBookSection(false);self.sectionExitTransition=true;self.bookFlow='event'
    if entry.kind=='chapter'then self.requestedChapter=entry.id;self:OpenThread(entry.threadId,entry.volumeId)
    else self:OpenStory(entry.storyId)end
   end)
  end
  self:Folio('chapterEvents',b)
 end
 function p:OpenChapterEvents()
  self.bookFlow='events';local b=title('Chapter events','THE ADVENTURES ALONG THE WAY')
  for _,group in ipairs(self:ChapterGroups())do if group.category~='journey'then local g=group
   b[#b+1]=link(g.title..' · '..#g.rows..(#g.rows==1 and ' adventure'or ' adventures'),function()self:OpenChapterGroup(g)end)
  end end
  if #b==2 then b[#b+1]={text='Further adventures will appear here as they are recorded.'}end
  self:Folio('chapterEventsIndex',b)
 end
 function p:BeginJourney()
  local ts=self.library and self.library.index and self.library.index.threads;local t=ts and ts.byID[ts.journeyId or ts.lifeId]
  if not t then return false end
  self.readerRestore=nil;self.readerPendingPlace=nil;self.pendingChapterAnchor=nil;self.requestedChapter=nil;self.folioRouteReturn=nil
  self:LeaveBookSection(false);self.sectionExitTransition=true;self.bookFlow='journey'
  self:OpenThread(t.id,t.volumeIds[1]);return true
 end
 function p:OnBookBoundary(delta)
  self.bookTurnDirection=delta
  if delta>0 then
   if self.bookFlow=='journey'then
    local ts=self.library.index.threads;local t=ts.byID[self.threadId]
    for i,id in ipairs(t and t.volumeIds or{})do if id==self.volumeId and i>1 then self:OpenFlowVolume(t.id,t.volumeIds[i-1],'last');return true end end
    self:OpenContents();return true
   end
   if self.bookFlow=='events'or self.bookSection=='chapterEventsIndex'then
    local ts=self.library.index.threads;local t=ts.byID[ts.journeyId or ts.lifeId]
    if t and #t.volumeIds>0 then self:OpenFlowVolume(t.id,t.volumeIds[#t.volumeIds],'last');return true end
    self:OpenContents();return true
   end
   if self.bookFlow=='event'then self:ReturnFolio();return true end
   self:CloseBook('front');return true
  end
  if self.bookFlow=='chapters'then return self:BeginJourney()end
  if self.bookFlow=='journey'then
   local ts=self.library.index.threads;local t=ts.byID[self.threadId]
   for i,id in ipairs(t and t.volumeIds or {})do if id==self.volumeId and t.volumeIds[i+1]then self:OpenThread(t.id,t.volumeIds[i+1]);return true end end
   self:OpenChapterEvents();return true
  end
  self:CloseBook('back');return true
 end
 function p:OpenFlowVolume(threadId,volumeId,edge)
  self.readerRestore=nil;self.readerPendingPlace=nil;self.finalRestore=nil;self.folioRouteReturn=nil;self.pendingChapterAnchor=nil
  self:LeaveBookSection(false);self.sectionExitTransition=true;self.bookFlow='journey';self.flowLanding={threadId=threadId,volumeId=volumeId,edge=edge};self:OpenThread(threadId,volumeId)
 end
 local showFlowThread=p.ShowThread
 function p:ShowThread()
  local target=self.flowLanding
  if target and target.threadId==self.threadId and target.volumeId==self.volumeId then self.readerLandingLeaf=target.edge;self.flowLanding=nil end
  return showFlowThread(self)
 end
 local closeCover=p.CloseBook
 function p:CloseBook(side)
  if side~='back' and not self.closedBookSide then self.backCoverFolio=nil end
  if side=='back' and not self.closedBookSide and self.rendered then self.backCoverFolio=self:CaptureFolio()end
  return closeCover(self,side)
 end
 local openCover=p.OpenBook
 function p:OpenBook()
  if self.coverMotion or self.turnState or self.bookMotion and self.bookMotion.active then return false end
  local side=self.closedBookSide;local ending
  if side=='back'then
   ending=self.backCoverFolio and self.backCoverFolio.owner==self.owner and self.backCoverFolio or nil

  end
  -- An explicit cover endpoint wins over deferred bookmark/route restoration.
  self.readerRestore=nil;self.readerPendingPlace=nil;self.finalRestore=nil;self.folioRouteReturn=nil;self.pendingChapterAnchor=nil
  -- Select and typeset the destination while the cover still occludes it.
  -- The board and camera must not capture the preceding folio and then replace
  -- that ink partway through opening. Keep framing owned by the controller.
  self.openingCover=true;self.cameraPreparing=true
  if side=='front'then self:OpenContents()
  elseif side=='back'then
   if ending and ending.source and #ending.source>0 then
    self:CancelPageTurn();for _,key in ipairs(stateKeys)do self[key]=ending.values[key]end
    self.bookSection=self.bookSection or 'backEnding';self.contentsOpen=false
    self.sectionWrite=true;self.document:SetBlocks(ending.source);self.sectionWrite=nil;self.scroll:Show()
   else self:OpenChapterEvents()end
  end
  if side and self.GoReadingPage then self:GoReadingPage(side=='back' and self.readingPageCount or 1);self.coverEndpoint=side=='back'and side or nil end
  self.closedBookSide=side;self.cameraPreparing=nil;openCover(self);self.openingCover=nil
  self.bookCoverOwner=self.owner
  return true
 end
 function p:RenderSectionIndex()
  if self.sectionPreparing or not self.bookSection then return end
  local id=self.bookSection
  if id~='contents' and id~='chapters' and id~='loreIndex' then return end
  local b=title(id=='loreIndex' and 'Lore of Azeroth' or id=='chapters' and 'Chapters & volumes' or 'Contents')
  if id=='chapters'then
   self.bookFlow='chapters';b=title('Chapters','THE CHRONICLES OF A RECORDED LIFE')
   b[#b+1]=link('Introduction · begin the Journey',function()self:BeginJourney()end)
   for _,group in ipairs(self:ChapterGroups())do local g=group
    b[#b+1]=link(g.title,function()self:OpenChapterGroup(g)end)
    b[#b+1]={kind='meta',text=#g.rows..(g.category=='journey'and (#g.rows==1 and ' recorded chapter'or ' recorded chapters')or (#g.rows==1 and ' recorded adventure'or ' recorded adventures'))}
   end
   if #b==3 then b[#b+1]={text='Chapters will appear as the permitted history finishes loading.'}end
   self:Folio(id,b,false);return
  end
  b[#b+1]=returnLink()
  if id=='contents' then
   b[#b+1]=link('Frontispiece',function() self:OpenFrontispiece() end)
   b[#b+1]=link('Badge showcase · the home display shelf',function()ns.WardenShelfShowcase.OpenFromReader(self)end)
   for _,row in ipairs({{'The Journey',function() self:OpenContents('life') end},{'Library · saved books',function() self:OpenLibraryFolios() end},{'Lore of Azeroth',function() self:OpenContents('lore') end},{'Memories & Recollections',function() self:OpenMemoryContents() end},{'Athena’s Daybook',function() self:OpenDaybook() end},{'Bookmarks',function() self:OpenReadingMarks() end},{'Sources & Limits',function() self:ShowEvidence() end},{'On reading · type & page preferences',function() self:OpenReadingPreferences() end}}) do b[#b+1]=link(row[1],row[2]) end
   b[#b+1]={pageBreak=true};b[#b+1]={kind='title',text='In the marked volume'}
   local marked=self.sectionReturn and self.sectionReturn.source or {};local count=0
   for n,block in ipairs(marked) do if block.kind=='heading' and block.id then
    local anchor={id=block.id,block=n,offset=0};count=count+1
    b[#b+1]=link(block.text,function() self:CloseContents(true);self.document:RestoreReadingAnchor(anchor) end)
   end end
   if count==0 then b[#b+1]={text='Open a Journey volume to list its chapters here.'} end
  else
   if id=='loreIndex' then b[#b+1]={text='World history is separate from your own deeds. Only this character’s permitted reference pages are listed.'}
   else b[#b+1]={text='Choose a recorded chapter or volume. A distant chapter opens directly without hundreds of physical turns.'} end
   b[#b+1]={pageBreak=true};b[#b+1]={kind='title',text=id=='loreIndex' and 'History & legends' or 'Chapters'}
   entries(b,self.list.items or {},function(row)
    self:PushFolio();self.folioReplacing=true;self:ActivateIndexEntry(row);self.folioReplacing=nil
   end)
   if #(self.list.items or {})==0 then b[#b+1]={text='This collection is still preparing, or no permitted entries are available.'} end
   if id=='loreIndex' then
    if self.loreNext then b[#b+1]=link('Further history',function() self.sectionPreparing=true;self:LoreStep(-1);self.sectionPreparing=nil;self:RenderSectionIndex() end) end
    if (self.lorePage or 1)>1 then b[#b+1]=link('Earlier history',function() self.sectionPreparing=true;self:LoreStep(1);self.sectionPreparing=nil;self:RenderSectionIndex() end) end
   end
  end
  self:Folio(id,b,false)
 end
 local oldOpenContents=p.OpenContents
 function p:OpenContents(collection)
  if not allowed() then return false end;self:PushFolio();self.folioReplacing=true;self.folioTransition=true
  if not collection then collection='life'end
  oldOpenContents(self,collection);self.folioReplacing=nil
 end
 function p:OpenLibraryFolios()
  local b=title('The private Library','BOOKS KEPT FOR ANOTHER DAY');b[#b+1]=returnLink()
  b[#b+1]=link('Athena’s Daybook · living account',function() self:OpenDaybook() end)
  local rows,why=E.List(self.provider,self.owner)
  if #rows>0 then b[#b+1]={kind='heading',text='Preserved Daybook editions'} end
  for _,row in ipairs(rows) do local id=row.id;b[#b+1]=link(row.title,function() self:OpenEdition(id) end);b[#b+1]={kind='meta',text=stamp(row.savedAt)..' · private, frozen manuscript'} end
  if #rows==0 then b[#b+1]={text=why or 'No Daybook snapshots have been saved for this character yet.'} end
  local copies=ns.AthenaReadingSnapshots.ListCopies(self)
  if #copies>0 then b[#b+1]={pageBreak=true};b[#b+1]={kind='heading',text='Existing saved manuscripts'} end
  for _,row in ipairs(copies) do local key=row.key;b[#b+1]=link(row.title,function() self:OpenLibraryCopy(key) end) end
  self:Folio('library',b)
 end
 function p:OpenLibraryCopy(key)
  local blocks=ns.AthenaReadingSnapshots.CopyBlocks(self,key);if not blocks then return self:OpenLibraryFolios() end
  self:PushFolio();self.libraryCopyKey=key;local out=title('A saved manuscript','EXISTING JOURNAL READING COPY');out[#out+1]=returnLink();for _,v in ipairs(blocks) do out[#out+1]=v end;self:Folio('libraryCopy',out,false)
 end
 function p:OpenReadingMarks()
  local b=title('Reading marks');b[#b+1]=returnLink();b[#b+1]=link('Mark the passage I was reading',function() self:CloseContents(true);self:SaveBookmark();self:OpenReadingMarks() end)
  for i,bookmark in ipairs(self.bookmarks or {}) do local mark=bookmark;b[#b+1]=link('Reading mark '..i..' · '..(mark.label or mark.storyId or mark.threadId or 'a folio'),function() self:RestoreBookmark(mark) end) end
  b[#b+1]=link('Visit the private Library',function() self:OpenLibraryFolios() end);self:Folio('marks',b)
 end
 function p:OpenSketchbook(key)
  if self.owner~=ns.Chronicle.Owner()then return false,'CURRENT_OWNER_REQUIRED'end
  key=key or 'notebook/1';local saved=ns.WardenDrawing.PrivateGet(key)
  local b=title('My private sketch','OWNER-AUTHORED · NOT VERIFIED HISTORY');b[#b+1]=returnLink()
  b[#b+1]={text='A drawing kept on this personal page. It is never automatically published or used as historical evidence.'}
  if saved then b[#b+1]={doodle=saved.wire,text='',kind='body',id='private-sketch/'..key}end
  b[#b+1]=link(saved and 'Open my drawing drawer' or 'Draw on this page',function()
   ns.WardenDrawing.Open({title='My Journal drawing drawer',privateBook=true,parent=self.book,wire=saved and saved.wire,save=function(wire)
    local ok,why=ns.WardenDrawing.PrivateSave(key,wire);if ok then self:OpenSketchbook(key)end;return ok,why
   end})
  end)
  b[#b+1]=link('Another sketch page',function()local used={};for _,page in ipairs(ns.WardenDrawing.PrivatePages())do used[page]=true end;for i=1,ns.WardenDrawing.MAX_PRIVATE do local next='notebook/'..i;if not used[next]and next~=key then self:OpenSketchbook(next);return end end end)
  self:Folio('privateSketch',b);return true
 end
 function p:OpenMemoryContents()
  local b=title('Memories & recollections','PRIVATE WORDS, SEPARATE FROM VERIFIED HISTORY');b[#b+1]=returnLink()
  b[#b+1]=link('My private sketchbook',function()self:OpenSketchbook('notebook/1')end)
  for _,page in ipairs(ns.WardenDrawing.PrivatePages())do local key=page;b[#b+1]=link('Sketch · '..key,function()self:OpenSketchbook(key)end)end
  b[#b+1]=link('Preserved conversations & memories',function() self:PushFolio();self:ShowMemories() end)
  b[#b+1]=link('My written recollections',function() if not self:OpenRecollections(false) then self:Folio('recollections',{{kind='title',text='My recollections'},{text='Open a recorded chapter with eligible moments to add or review your personal recollections.'},returnLink()}) end end)
  self:Folio('memoryContents',b)
 end
 local showEvidence=p.ShowEvidence
 local presentMemory=p.PresentMemoryPages
 function p:PresentMemoryPages(...)
  presentMemory(self,...);self.memoryRail:Hide();self.scroll:Show();self:BookLayout()
 end
 local memorySettings=p.MemorySettings
 function p:MemorySettings(...) memorySettings(self,...);self.memoryRail:Hide();self.scroll:Show();self:BookLayout() end
 function p:ShowEvidence()
  self:PushFolio()
  if self.bookSection=='daybook' and self.daybookReading then
   local b=title('Daybook sources & limits');b[#b+1]=returnLink()
   b[#b+1]={text='Only retained, permitted observations in the selected dated window support this telling. Gaps are not filled with invented activity.'}
   for _,ref in ipairs(self.daybookReading.refs or {}) do b[#b+1]={kind='meta',text=ref} end
   self:Folio('sources',b,false);return
  elseif self.bookSection=='edition' and self.editionID then
   local edition=E.Get(self.provider,self.owner,self.editionID);local b=title('Sources of this preserved edition');b[#b+1]=returnLink()
   for _,ref in ipairs(edition and edition.refs or {}) do b[#b+1]={kind='meta',text=ref} end
   b[#b+1]={text='These are the references recorded at save time. The frozen text is not regenerated from newer evidence.'};self:Folio('sources',b,false);return
  end
  if self.bookSection then originalReturn(self,true) end
  showEvidence(self)
 end
 function p:OpenDaybook()
  if not allowed() then return false end
  if not self.daybookCatalog or self.daybookCatalog.owner~=self.owner then self.daybookCatalog=D.Catalog(self.provider,self.owner) end
  self:RenderDaybookIndex(true);return true
 end
 function p:RenderDaybookIndex(push)
  local c=self.daybookCatalog;local b=title('Athena’s Daybook','THE DAYS OF A RECORDED LIFE');b[#b+1]=returnLink()
  b[#b+1]={text='A detailed, chronological counterpart to The Journey. Dates use the client’s local calendar. Missing records and gaps remain unknown.'}
  if not c or not c.done then b[#b+1]={text='Reading the permitted dates…'}
  elseif c.status~='READY' then b[#b+1]={text='These dates could not be opened: '..tostring(c.status)..'. Existing books are retained.'}
  else
   entries(b,c.days,function(window) self:ReadDaybook(window) end)
   if #c.days==0 then b[#b+1]={text='No dated observations are available in this character’s permitted archive.'} end
   if c.limited then b[#b+1]={kind='meta',text='This date list shows part of a long history. Your full history is still kept.'} end
  end
  b[#b+1]=link('Refresh recorded days',function() self.daybookCatalog=D.Catalog(self.provider,self.owner);self:RenderDaybookIndex(false) end)
  self:Folio('daybookIndex',b,push)
 end
 function p:ReadDaybook(window,restoring)
  if not allowed() then return false end
  if not restoring then self:PushFolio() end
  self.daybookWindow=ns.Athena.Copy(window);self.daybookJob=D.Compose(self.provider,self.owner,window);self.daybookReading=nil
  self:Folio('daybook',{{kind='title',text='Athena’s Daybook'},{kind='meta',text=window.label},{text='Composing the existing source-backed telling for this period…'},returnLink()},false)
 end
 function p:RenderDaybook()
  local job=self.daybookJob;if not job or not job.done then return end
  if job.status~='READY' then self:Folio('daybook',{{kind='title',text='This day is unavailable'},{text='The original archive is retained. '..tostring(job.status)},returnLink()},false);return end
  self.daybookReading=job
  local blocks={};for _,b in ipairs(job.blocks) do local row=shallow(b);L.Decorate(self,row,b.source or b);blocks[#blocks+1]=row end
  self.daybookSaveBlocks=blocks
  local out={};for _,b in ipairs(blocks) do out[#out+1]=b end
  out[#out+1]={pageBreak=true};out[#out+1]={kind='heading',text='Keep this day'}
  out[#out+1]=link('Save Snapshot',function() self:SaveDaybookSnapshot() end,'Freeze the actual text you are reading into a private Library edition.')
  out[#out+1]=link('Refresh this living account',function()
   self.daybookRestorePlace=originalPlace(self);self.daybookCatalog=D.Catalog(self.provider,self.owner);self.daybookRefreshKey=self.daybookWindow.key
   self:Folio('daybook',{{kind='title',text='Refreshing the living account'},{text='New observations may extend this day. Preserved editions remain unchanged.'},returnLink()},false)
  end)
  out[#out+1]=returnLink();self:Folio('daybook',out,false)
  if self.daybookRestorePlace then originalRestore(self,self.daybookRestorePlace);self.daybookRestorePlace=nil end
 end
 function p:OpenEdition(id,restoring)
  local row,why=E.Get(self.provider,self.owner,id);if not row then self:Folio('library',{{kind='title',text='Saved edition unavailable'},{text=why or 'This private book is unavailable.'},returnLink()});return false end
  if not restoring then self:PushFolio() end;self.editionID=id
  local b=title(row.title,'A PRESERVED DAYBOOK EDITION');b[#b+1]={kind='meta',text='Saved '..stamp(row.savedAt)..' · '..row.window.label}
  if row.note~='' then b[#b+1]={kind='heading',text='A note in the owner’s hand'};b[#b+1]={kind='quote',text=row.note};b[#b+1]={kind='meta',text='User-authored commentary; not verified Warcraft evidence.'} end
  for _,block in ipairs(row.blocks) do b[#b+1]=block end
  b[#b+1]={pageBreak=true};b[#b+1]=link('Rename this edition or edit my note',function() self:EditEdition(row) end)
  b[#b+1]=link('Delete this edition…',function()
   self:Folio('deleteEdition',{{kind='title',text='Delete this private edition?'},{text='This permanently removes only the selected reading copy. The original observations are retained.'},link('Keep this book',function() self:ReturnFolio() end),link('Delete this edition permanently',function() local ok,message=E.Delete(self.provider,self.owner,id,true);if ok then self:OpenLibraryFolios() else self:Folio('deleteEdition',{{kind='title',text='Deletion refused'},{text=message},returnLink()},false) end end)})
  end)
  b[#b+1]=returnLink();if self.snapshotMessage then b[#b+1]={kind='meta',text=self.snapshotMessage};self.snapshotMessage=nil end;self:Folio('edition',b,false);return true
 end
 function p:BeginFolioWriting(name,fields,commit,help)
  self:PushFolio();hideWriting();writer.fields=fields;writer.commit=commit;writer.inputs=writer.inputs or {}
  local b=title(name);b[#b+1]={text=help or 'Your title and note stay private.'}
  b[#b+1]={text='',gap=240};b[#b+1]=link('Save these words',function()
   if not writer.commit or not allowed() then return false end
   local values={};for i,field in ipairs(writer.fields or {}) do values[field.key]=writer.inputs[i]:GetText() end
   local ok,message=writer.commit(values)
   if not ok then self:Folio('writing',{{kind='title',text=name},{text=message or 'Nothing was saved.'},{text='',gap=240},link('Try saving again',function() writer.save() end),returnLink()},false);self:LayoutFolioWriting() end
  end);writer.save=b[#b].activate;b[#b+1]=returnLink()
  self:Folio('writing',b,false)
  for i,field in ipairs(fields) do
   local edit=writer.inputs[i]
   if not edit then edit=CreateFrame('EditBox',nil,self.book);writer.inputs[i]=edit;edit:SetAutoFocus(false);edit:SetTextInsets(4,4,3,3);edit:SetTextColor(.23,.13,.06);edit:SetScript('OnEscapePressed',function(self) self:ClearFocus() end);local rule=edit:CreateTexture(nil,'BACKGROUND');rule:SetColorTexture(.43,.30,.14,.4);rule:SetPoint('BOTTOMLEFT');rule:SetPoint('BOTTOMRIGHT');rule:SetHeight(1) end
   edit:SetMultiLine(field.multiline==true);edit:SetMaxLetters(field.limit or 2000);ns.Theme.ReaderFont(edit,16,'body','paper');edit:SetText(field.value or '')
   edit.fieldLabel=edit.fieldLabel or edit:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');edit.fieldLabel:SetPoint('BOTTOMLEFT',edit,'TOPLEFT',0,4);edit.fieldLabel:SetText(field.label or field.key);edit.fieldLabel:SetTextColor(.38,.22,.10)
  end
  self:LayoutFolioWriting()
 end
 function p:LayoutFolioWriting()
  local shown=self.bookSection=='writing' and self.readingPage==1 and not self.closedBookSide
  for i,input in ipairs(writer.inputs or {}) do
   input:SetShown(shown and writer.fields and writer.fields[i]~=nil)
   if shown and writer.fields[i] then local w,h=self.book:GetWidth(),self.book:GetHeight();local x=w*.16;local width=w*.29
    local offset=math.max(h*.36,120)+(i-1)*math.min(92,h*.17)
    input:ClearAllPoints();input:SetPoint('TOPLEFT',self.book,'TOPLEFT',x,-offset);input:SetSize(width,writer.fields[i].multiline and math.min(116,h*.21)or 30)
   end
  end
 end
 function p:SaveDaybookSnapshot()
  local job=self.daybookReading;if not job or job.status~='READY' then return false end
  local token,why=E.NewToken(self.provider,self.owner);if not token then return self:Folio('saveSnapshot',{{kind='title',text='Snapshot not saved'},{text=why},returnLink()}) end
  local frozen={};for _,block in ipairs(self.daybookSaveBlocks) do local row=shallow(block);row.source=nil;row.activate=nil;frozen[#frozen+1]=ns.Athena.Copy(row) end
  local refs=ns.Athena.Copy(job.refs);local window=ns.Athena.Copy(job.window);local versions=ns.Athena.Copy(job.versions)
  -- Presentation callbacks and job source handles never enter SavedVariables.
  for _,b in ipairs(frozen) do b.source=nil;b.activate=nil end
  self:BeginFolioWriting('Preserve this day',{{key='title',label='Edition title',value='Daybook · '..window.label,limit=160},{key='note',label='Optional note in your own words',value='',limit=2000,multiline=true}},function(values)
   local id,message=E.Save(self.provider,self.owner,{token=token,title=values.title,note=values.note,window=window,versions=versions,blocks=frozen,refs=refs})
   if not id then return false,message end
   self.snapshotMessage=message;self:OpenEdition(id,true);return true
  end,'The actual authored text at this moment will be frozen. The living account can continue. WoW saves accepted editions on normal reload/logout; this is not a crash-proof disk commit.')
 end
 function p:EditEdition(row)
  self:BeginFolioWriting('The owner’s inscription',{{key='title',label='Edition title',value=row.title,limit=160},{key='note',label='User-authored note',value=row.note,limit=2000,multiline=true}},function(values)
   local ok,why=E.Edit(self.provider,self.owner,row.id,values.title,values.note);if ok then self:OpenEdition(row.id,true) end;return ok,why
  end,'Only this title and your note change. The frozen manuscript is preserved verbatim.')
 end
 -- Native recollection methods retain their source validation. Their controls
 -- are presented as printed selections and writing lines on these same pages.
 local openRecollections=p.OpenRecollections
 function p:OpenRecollections(beforeGenerate)
  local ok=openRecollections(self,beforeGenerate);if not ok then return false end
  self.recollectionEditor:Hide();local b=title('My recollections','USER-AUTHORED · PRIVATE PERSPECTIVE');b[#b+1]=returnLink()
  for _,choice in ipairs(self.recollectionEditor.choices) do if choice[1] then local ref=choice[1];b[#b+1]=link(choice[2],function() self:WriteRecollection(ref,beforeGenerate) end) end end
  if beforeGenerate then b[#b+1]=link('Skip these optional notes and regenerate',function() self:Regenerate(true) end) end
  self:Folio('recollections',b);return true
 end
 function p:WriteRecollection(ref,beforeGenerate)
  self:SelectRecollection(ref);local target=self.recollectionTargets[ref];local note=ns.AthenaRecollections.Get(self.provider,self.owner,target)
  local feeling=note and note.feeling or 'unsaid';local company=note and note.company or 'unsaid'
  local function write()
   self:BeginFolioWriting('A memory in my own hand',{{key='text',label='Your recollection · optional personal perspective',value=note and note.text or '',limit=2000,multiline=true}},function(values)
    local ok,why=ns.AthenaRecollections.Save(self.provider,self.owner,target,{text=values.text,feeling=feeling,company=company})
    if ok then if beforeGenerate then self:Regenerate(true) else self:Recompose();self:ReturnFolio() end end;return ok,why
   end,'These are your words and feelings, not new verified gameplay evidence.')
  end
  local function choices(push)
   local b=title('How I remember this moment','OPTIONAL · OWNER-AUTHORED PERSPECTIVE');b[#b+1]=returnLink()
   b[#b+1]=link('Write or revise my own words',write)
   b[#b+1]=link('Sketch this recollection',function()self:OpenSketchbook(target.ref)end)
   b[#b+1]={kind='heading',text='Feeling · '..ns.AthenaRecollections.feelings[feeling]}
   for _,key in ipairs({'unsaid','joyful','difficult','tense','funny','mixed','quiet'}) do local id=key;b[#b+1]=link(ns.AthenaRecollections.feelings[id],function() feeling=id;choices(false) end) end
   b[#b+1]={kind='heading',text='Company · '..ns.AthenaRecollections.company[company]}
   for _,key in ipairs({'unsaid','welcoming','strained','quiet','alone'}) do local id=key;b[#b+1]=link(ns.AthenaRecollections.company[id],function() company=id;choices(false) end) end
   if note then b[#b+1]=link('Remove this personal recollection',function() if ns.AthenaRecollections.Delete(self.provider,self.owner,target) then self:Recompose();self:ReturnFolio() end end) end
   self:Folio('recollectionChoices',b,push)
  end
  choices(true)
 end
 function p:MemoryNotes()
  local service=self:MemoryService();local moment=service and self.memorySelectedMoment and service.ResolveMoment(self.memorySelectedMoment,self:MemoryContext())
  if not moment then return false end;local ref=self.memorySelectedMoment
  self:BeginFolioWriting('A note beside this memory',{{key='title',label='Personal title',value=moment.revision.title or '',limit=120},{key='note',label='Your own private note',value=moment.revision.note or '',limit=1000,multiline=true}},function(values)
   local ok,why=service.Revise(ref,{title=values.title,note=values.note},self:MemoryContext())
   if ok then self:ShowMemories() end;return ok,why
  end,'Your title and note are commentary, not a change to the recorded conversation.');return true
 end
 function p:MemoryExport()
  local service=self:MemoryService();if not service or not self.memoryReveal then return false end
  local archive,why=service.ExportOwner(self:MemoryContext(),true)
  if not archive then return self:Folio('memories',{{kind='title',text='Private archive unavailable'},{text=why or 'No permitted export.'},returnLink()}) end
  self:BeginFolioWriting('A private archive for copying',{{key='archive',label='Select and copy deliberately; never sent automatically',value=ns.Reports.JSON(archive),limit=0,multiline=true}},function() self:ReturnFolio();return true end,'This owner-private copy is not sent to Wiki, Aether or Relay.')
 end
 -- State contains typed destinations and anchors, not copied history/prose.
 function p:FolioState()
  return {section=self.bookSection,closedSide=self.closedBookSide,day=self.daybookWindow and shallow(self.daybookWindow),edition=self.editionID,copyKey=self.libraryCopyKey,memoryRef=self.memorySelectedMoment or self.memorySelection,memoryMode=self.memoryMode,sourceRef=self.evidenceRef,collection=self.folioCollection or self.collection,place=originalPlace(self)}
 end
 function p:BookPlace() local place=originalPlace(self);place.folio=self:FolioState();return place end
 function p:RestoreFolioState(state)
  if not state then return end
  if not state.section then if state.closedSide then self:CloseBook(state.closedSide) end;return end
  self.folioReplacing=true
  local id=state.section
  if id=='contents' then self:OpenContents()
  elseif id=='chapters' then self:OpenContents(state.collection)
  elseif id=='loreIndex' then self:OpenContents('lore')
  elseif id=='libraryCopy' and state.copyKey then self:OpenLibraryCopy(state.copyKey)
  elseif id=='library' then self:OpenLibraryFolios()
  elseif id=='marks' then self:OpenReadingMarks()
  elseif id=='daybookIndex' then self:OpenDaybook()
  elseif id=='daybook' and state.day then self.daybookRestorePlace=state.place;self:ReadDaybook(state.day,true)
  elseif id=='edition' and state.edition then self:OpenEdition(state.edition,true)
  elseif id=='preferences' then self:OpenReadingPreferences()
  elseif id=='memories' then self.memoryReveal=false;self.memoryMode=state.memoryMode;self:ShowMemories();if state.memoryRef then self.memorySelection=state.memoryRef;self:MemorySelection() end
  elseif id=='memoryContents' or id=='recollections' then self:OpenMemoryContents()
  elseif id=='sources' then self.evidenceRef=state.sourceRef;self:ShowEvidence() end
  self.folioReplacing=nil
  if id~='daybook' then originalRestore(self,state.place) end
  if state.closedSide then self:CloseBook(state.closedSide) end
 end
 function p:RestoreBookPlace(place)
  if place and place.folio and place.folio.section and self.bookSection~=place.folio.section then self:RestoreFolioState(place.folio) end
  originalRestore(self,place)
  if ns.UI2 and ns.UI2.route and ns.UI2.route.page=='journey' then self.folioSeenRoute=ns.UI2.route end
 end
 function p:CaptureReaderPlace()
  if self.turnState and self.turnState.commit then self:CancelPageTurn() end
  local saved=originalCapture(self);if not saved then return end;saved=ns.Athena.Copy(saved)
  saved.folio=self:FolioState();saved.bookmarks={}
  for i=math.max(1,#(self.bookmarks or {})-31),#(self.bookmarks or {}) do saved.bookmarks[#saved.bookmarks+1]=ns.Athena.Copy(self.bookmarks[i]) end
  saved.trail=ns.Athena.Copy(self.persistedBookTrail or {})
  for _,entry in ipairs(self.bookTrail) do local v=entry.values
   saved.trail[#saved.trail+1]={owner=entry.owner,shelf=v.shelf,destination=v.destination,collection=v.collection,threadId=v.threadId,volumeId=v.volumeId,storyId=v.selected,loreID=v.loreID,place=entry.place,anchor=entry.place.anchor,folio={section=v.bookSection,day=v.daybookWindow and shallow(v.daybookWindow),edition=v.editionID,copyKey=v.libraryCopyKey,collection=v.collection,place=entry.place}}
  end
  while #saved.trail>12 do table.remove(saved.trail,1) end
  return saved
 end
 function p:RestoreReaderPlace(saved)
  if not saved or saved.owner~=self.owner or not allowed() then return false end
  self.bookmarks=ns.Athena.Copy(saved.bookmarks or self.bookmarks or {});self.bookmark=self.bookmarks[#self.bookmarks]
  if saved.trail then self.persistedBookTrail=ns.Athena.Copy(saved.trail) end
  self.finalRestore=saved.folio;return originalRestoreReader(self,saved)
 end
 local saveMark,restoreMark=p.SaveBookmark,p.RestoreBookmark
 function p:SaveBookmark()
  if not allowed() then return end
  if self.bookSection then
   self.bookmarks=self.bookmarks or {};self.bookmarks[#self.bookmarks+1]={owner=self.owner,folio=self:FolioState(),label=self.bookSection};self.bookmark=self.bookmarks[#self.bookmarks]
  else saveMark(self) end
  while #self.bookmarks>32 do table.remove(self.bookmarks,1) end;self:PersistReaderPlace()
 end
 function p:RestoreBookmark(mark)
  if mark and mark.owner==self.owner and mark.folio then self:PushFolio();self:RestoreFolioState(mark.folio);return true end
  return restoreMark(self,mark)
 end
 function p:Clear()
  originalClear(self);hideWriting();self.backCoverFolio=nil;self.coverEndpoint=nil;self.pendingChapterAnchor=nil;self.pendingSearchEdition=nil;self.bookTrail={};self.persistedBookTrail=nil;self.daybookCatalog=nil;self.daybookJob=nil;self.daybookReading=nil;self.daybookSaveBlocks=nil;self.editionID=nil;self.finalRestore=nil;self.folioRouteReturn=nil
  self.daybookWindow=nil;self.daybookRefreshKey=nil;self.daybookRestorePlace=nil;self.libraryCopyKey=nil
  for _,input in ipairs(writer.inputs or {}) do input:SetText('') end;writer.fields=nil;writer.commit=nil;writer.save=nil
 end
 function p:Refresh()
  local route=ns.UI2 and ns.UI2.route
  if route and route.page=='journey' and route.owner==self.owner and route~=self.folioSeenRoute then
   self.folioSeenRoute=route
   if route.bookPlace then self.folioRouteReturn={route=route,place=route.bookPlace} end
  end
    if self.turnState or self.coverMotion then return end
  originalRefresh(self)
  if not allowed() then hideWriting();self.bookTrail={};self.daybookCatalog=nil;self.daybookJob=nil;self.daybookReading=nil;return end
  if self.daybookCatalog and not self.daybookCatalog.done then
   for _=1,3 do D.Pump(self.daybookCatalog);if self.daybookCatalog.done then break end end
   if self.daybookCatalog.done then
    if self.daybookRefreshKey then local window=self.daybookCatalog.byKey[self.daybookRefreshKey];self.daybookRefreshKey=nil;if window then self:ReadDaybook(window,true) end
    elseif self.bookSection=='daybookIndex' then self:RenderDaybookIndex(false) end
   end
  end
  if self.daybookJob and not self.daybookJob.done then
   for _=1,3 do D.Pump(self.daybookJob);if self.daybookJob.done then break end end
   if self.daybookJob.done and self.bookSection=='daybook' then self:RenderDaybook() end
  end
  if self.finalRestore and self.rendered and not self.pendingThread and not self.readerPendingPlace then local state=self.finalRestore;self.finalRestore=nil;self:RestoreFolioState(state) end
  if self.pendingChapterAnchor and self.rendered and not self.pendingThread and not self.turnState then
   local anchor=self.pendingChapterAnchor;self.pendingChapterAnchor=nil;self.document:RestoreReadingAnchor(anchor)
  end
  if self.pendingSearchEdition and self.rendered and not self.pendingThread and not self.turnState then
   local edition=self.pendingSearchEdition;self.pendingSearchEdition=nil;self:OpenEdition(edition)
  end
  local returning=self.folioRouteReturn
  if returning and (ns.UI2.route~=returning.route or returning.route.owner~=self.owner) then self.folioRouteReturn=nil
  elseif returning and self.rendered and not self.pendingThread and not self.turnState then self.folioRouteReturn=nil;self:RestoreBookPlace(returning.place) end
  if self.coverEndpoint and self.rendered and not self.pendingThread and not self.turnState and not self.closedBookSide then
   local endpoint=self.coverEndpoint;self.coverEndpoint=nil;self:GoReadingPage(endpoint=='back'and self.readingPageCount or 1)
  end
  if self.rendered and self.bookCoverOwner~=self.owner then
   self.bookCoverOwner=self.owner
   if not (route and (route.storyId or route.bookPlace))and not self.readerPendingPlace and not self.finalRestore then self.bookFlow='front';self:CloseBook('front')end
  end
 end
 local onPage=p.OnReaderPageChanged
 function p:OnReaderPageChanged(...) if onPage then onPage(self,...) end;self:LayoutFolioWriting() end
 function p:Layout(w,h)
  originalLayout(self,w or self:GetWidth(),h or self:GetHeight());self:LayoutFolioWriting()
 end
 p.libraryToggle.label:SetText('Contents')
 local singlePaper=p.book:CreateTexture(nil,'BACKGROUND',nil,1);singlePaper:SetAllPoints();singlePaper:SetTexture('Interface\\AddOns\\OlympusChatWarden\\Media\\AthenaBookBronze.tga');singlePaper:SetTexCoord(0,.5,0,1);singlePaper:Hide()
 local sync=p.SyncBookObject
 function p:SyncBookObject(...) sync(self,...);singlePaper:SetShown(not self.closedBookSide and self.book:GetWidth()<480);self:LayoutFolioWriting() end
 -- A narrative story's typed evidence also supplies links outside full volumes.
 local set=p.document.SetBlocks
 function p.document:SetBlocks(blocks,...)
  -- Saved editions may pass their own tables to the reader. Decorations belong
  -- to this presentation only, never back into those immutable saved blocks.
  local presentation={};for i,b in ipairs(blocks or {})do
   if type(b)=='table'then local copy={};for k,v in pairs(b)do copy[k]=v end;presentation[i]=copy else presentation[i]=b end
  end;blocks=presentation
  if p.loreEntry and p.shelf=='lore' then
   local refs={{type='WIKI',key=p.loreID,label=p.loreEntry.title}}
   for _,id in ipairs(p.loreEntry.relatedIDs or {}) do local e=ns.Athena.Knowledge.GetLore(id,p:LoreContext());if e then refs[#refs+1]={type='WIKI',key=id,label=e.title} end end
   for _,b in ipairs(blocks or {}) do L.Decorate(p,b,{wikiRefs=refs}) end
  elseif p.story and (not p.bookSection or p.bookSection=='sources') then for _,b in ipairs(blocks or {}) do L.Decorate(p,b,p.story) end end
  for _,b in ipairs(blocks or {})do if type(b)=='table'and not b.journalArt then ns.AthenaBookArt.Decorate(p,b,b)end end
  return set(self,blocks,...)
 end
end
local build=ns.AthenaJournalUI.Build
function ns.AthenaJournalUI.Build(...) local p=build(...);F.Attach(p);return p end
