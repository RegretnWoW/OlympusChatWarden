-- Fitted manuscript pages. Pagination changes presentation, never scene scope.
local _,ns=...
local M={VERSION=5};ns.AthenaBookReader=M
local function Clone(b) local o={};for k,v in pairs(b) do o[k]=v end;return o end
function M.Attach(p)
    local doc,scroll=p.document,p.scroll
    local PaintInk,HideInk
    doc.bookInkOverlay=true
    local set,getAnchor,restoreAnchor=doc.SetBlocks,doc.GetReadingAnchor,doc.RestoreReadingAnchor
    local right,rightScroll=ns.Art.Document(p.book,0,0,300,400);right:SetStyle('paper');rightScroll:Hide()
    p.rightPage,p.rightScroll=right,rightScroll
    right.bookInkOverlay=true
    scroll.ChatWardenPaged=true;rightScroll.ChatWardenPaged=true
    local art=p.book:CreateTexture(nil,'BACKGROUND',nil,0);art:SetAllPoints();art:SetTexture('Interface\\AddOns\\OlympusChatWarden\\Media\\Journal3\\OpenBook.tga')
    local single={};local bu,bv=.07,.105
    local regions={{0,bu,0,bv,'TOPLEFT'},{.5-bu,.5,0,bv,'TOPRIGHT'},
        {0,bu,1-bv,1,'BOTTOMLEFT'},{.5-bu,.5,1-bv,1,'BOTTOMRIGHT'},
        {bu,.5-bu,0,bv,'TOP'},{bu,.5-bu,1-bv,1,'BOTTOM'},
        {0,bu,bv,1-bv,'LEFT'},{.5-bu,.5,bv,1-bv,'RIGHT'},
        {bu,.5-bu,bv,1-bv,'CENTER'}}
    for i,r in ipairs(regions) do local t=p.book:CreateTexture(nil,'BACKGROUND',nil,0)
        t:SetTexture('Interface\\AddOns\\OlympusChatWarden\\Media\\Journal3\\OpenBook.tga');t:SetTexCoord(r[1],r[2],r[3],r[4]);single[i]=t
        if i<=4 then t:SetPoint(r[5]);t:SetSize(64,64)
        elseif i<=6 then t:SetPoint(i==5 and 'TOPLEFT' or 'BOTTOMLEFT',64,0);t:SetPoint(i==5 and 'TOPRIGHT' or 'BOTTOMRIGHT',-64,0);t:SetHeight(64)
        elseif i<=8 then t:SetPoint(i==7 and 'TOPLEFT' or 'TOPRIGHT',0,-64);t:SetPoint(i==7 and 'BOTTOMLEFT' or 'BOTTOMRIGHT',0,64);t:SetWidth(64)
        else t:SetPoint('TOPLEFT',64,-64);t:SetPoint('BOTTOMRIGHT',-64,64) end
    end
    p.book.ArtFrame:SetShown(false);p.book.ArtBacking:Hide();p.pageEdge:Hide()
    local turn=CreateFrame('Frame',nil,p.book);turn:SetAllPoints();turn:SetFrameLevel(p.book:GetFrameLevel()+100);turn:Hide()
    local foldShadow=turn:CreateTexture(nil,'BACKGROUND');foldShadow:SetTexture('Interface\\AddOns\\OlympusChatWarden\\Media\\Journal3\\Atmosphere.tga');foldShadow:SetTexCoord(0,.5,.5,1);foldShadow:SetVertexColor(.10,.055,.025,.26)
    local inkLayer=CreateFrame('Frame',nil,p.book);inkLayer:SetAllPoints();inkLayer:SetFrameLevel(p.book:GetFrameLevel()+4)
    local ink=inkLayer:CreateTexture(nil,'OVERLAY');ink:SetColorTexture(.98,.66,.16,.48);ink:SetSize(90,20);ink:Hide()
    local pages,source,pageIndex={}, {},1;local width,height,spread=300,400,false;local layoutKey
    local sourceRevision,renderedKey=0,nil
    local enablePrevious,enableNext=p.previous.SetEnabled,p.next.SetEnabled
    function p.previous:SetEnabled(value) enablePrevious(self,value or not p.sourceRail:IsShown() and pageIndex>1) end
    function p.next:SetEnabled(value) enableNext(self,value or not p.sourceRail:IsShown() and pageIndex+(spread and 1 or 0)<#pages) end
    local function Size(b)
        return ns.Theme.BookBlockMetrics(b,width,doc.fontScale)
    end
    local function Paginate()
        pages={{}};local used=0
        local function New()
            local page=pages[#pages];local last=page[#page]
            if #page>1 and last and (last.kind=='heading' or last.kind=='title') then
                table.remove(page);pages[#pages+1]={last};used=Size(last)
            elseif #page>0 then pages[#pages+1]={};used=0 end
        end
        local function Push(b) pages[#pages][#pages[#pages]+1]=b;used=used+Size(b) end
        for n,b in ipairs(source) do
            if type(b)=='string' then b={text=b} end
            if b.pageBreak then New() else
            local size=Size(b)
            if (b.kind=='heading' or b.kind=='title') and used+size+72>height then New() end
            local prose=not b.doodle and (not b.kind or b.kind=='body' or b.kind=='quote')
            if size<=height and (used+size<=height or not prose or height-used<100) then if used+size>height then New() end;local c=Clone(b);c.originBlock=n;Push(c)
            else
                local words={};for word in (b.text or ''):gmatch('%S+%s*')do
                    local token=Clone(b);token.text=word
                    local line=ns.Theme.DocumentTextSize(b.kind or 'body',doc.fontScale)+3
                    -- Ordinary words cannot fill a leaf even at one character
                    -- per line; avoid native remeasurement for each small token.
                    local worst=#word*line+line+8+(b.gap or 14)+(ns.AthenaBookArt and ns.AthenaBookArt.Height(b)or 0)
                    if worst>height and Size(token)>height then
                        -- A URL/name or unspaced script can itself be taller
                        -- than a leaf. Split only this oversized token at UTF-8
                        -- character boundaries; keep every byte and span offset.
                        for ch in word:gmatch('[%z\1-\127\194-\244][\128-\191]*')do words[#words+1]=ch end
                    else words[#words+1]=word end
                end
                local at,part=1,0
                while at<=#words do
                    if height-used<64 then New() end
                    local lo,hi,best=at,#words,at-1
                    while lo<=hi do local mid=math.floor((lo+hi)/2);local candidate=Clone(b);candidate.text=table.concat(words,'',at,mid)
                        if Size(candidate)<=height-used then best=mid;lo=mid+1 else hi=mid-1 end
                    end
                    -- Prefer at least two lines on either side of a split.
                    -- This changes only word boundaries, never the manuscript.
                    local line=ns.Theme.DocumentTextSize(b.kind or 'body',doc.fontScale)+3;local moved=false
                    if best>=at and best<#words then
                        local candidate=Clone(b);candidate.text=table.concat(words,'',at,best)
                        local page=pages[#pages];local headingOnly=#page==1 and (page[1].kind=='heading' or page[1].kind=='title')
                        if used>0 and not headingOnly and Size(candidate)<2*line+22 then New();best=at-1;moved=true
                        else
                            local rest=Clone(b);rest.text=table.concat(words,'',best+1,#words)
                            while best>at and Size(rest)<2*line+22 do
                                local shortened=Clone(b);shortened.text=table.concat(words,'',at,best-1)
                                if Size(shortened)<2*line+22 then break end
                                best=best-1;rest.text=table.concat(words,'',best+1,#words)
                            end
                        end
                    end
                    if best<at and not moved then if used>0 then New() else best=at end end
                    if best>=at then
                        part=part+1;local c=Clone(b);c.text=table.concat(words,'',at,best)
                        local offset=0;for wordIndex=1,at-1 do offset=offset+#words[wordIndex] end
                        c.spans={};for _,span in ipairs(b.spans or {}) do if span.last>offset and span.first<=offset+#c.text then local link=Clone(span);link.first=math.max(1,span.first-offset);link.last=math.min(#c.text,span.last-offset);c.spans[#c.spans+1]=link end end
                        if part>1 then c.margin=nil end;c.originBlock=n;c.originId=b.id;c.originOffset=offset;c.id=(b.id or tostring(n))..'/leaf/'..part;Push(c);at=best+1
                        if at<=#words then New() end
                    end
                end
            end
        end
            -- End one input block (explicit section breaks are not ink).
        end
        -- A terminal section break separates chapters; it is not a blank leaf
        -- after the manuscript. An empty leaf otherwise restores as block one.
        while #pages>1 and #pages[#pages]==0 do table.remove(pages)end
        pageIndex=math.max(1,math.min(pageIndex,#pages));if spread then pageIndex=math.floor((pageIndex-1)/2)*2+1 end
    end
    local folioLeft=p.book:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
    local folioRight=p.book:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
    folioLeft:SetTextColor(.32,.20,.11,1);folioRight:SetTextColor(.32,.20,.11,1)
    folioLeft:SetPoint('BOTTOMLEFT',p.book,'BOTTOMLEFT',50,24);folioRight:SetPoint('BOTTOMRIGHT',p.book,'BOTTOMRIGHT',-50,24)
    local function Render()
        if p.turnState then return end -- The turning sheet owns both snapshots until it lands.
        local key=tostring(sourceRevision)..'/'..tostring(layoutKey)..'/'..pageIndex
        local repaint=key~=renderedKey;renderedKey=key
        if repaint then
            doc:FinishWordReveal();right:FinishWordReveal()
            set(doc,pages[pageIndex] or {});right:SetBlocks(spread and pages[pageIndex+1] or {})
            doc:Refit();right:Refit();scroll:SetVerticalScroll(0);rightScroll:SetVerticalScroll(0)
        end
        rightScroll:SetShown(spread and (p.bookSection~=nil or not p.sourceRail:IsShown() and not p.memoryRail:IsShown()))
        if #source>0 then
            local last=math.min(#pages,pageIndex+(spread and 1 or 0))
            local heading
            for leaf=pageIndex,1,-1 do for n=#(pages[leaf] or {}),1,-1 do local b=pages[leaf][n];if b.kind=='heading' then heading=b.text;break end end;if heading then break end end
            p.pageProgress:SetText((p.savedReading and 'Saved copy • ' or '')..(heading and heading:sub(1,70)..' • ' or '')..'Page '..pageIndex..(last>pageIndex and '–'..last or '')..' / '..#pages)
            p.previous:SetEnabled(pageIndex>1 or p.volumeId~=nil);p.next:SetEnabled(last<#pages or p.volumeId~=nil)
        end
        folioLeft:SetText(tostring(pageIndex));folioRight:SetText(spread and pageIndex+1<=#pages and tostring(pageIndex+1) or '')
        p.readingPage=pageIndex;p.readingPageCount=#pages
        if p.OnReaderPageChanged then p:OnReaderPageChanged(pageIndex) end
        if p.SyncBookObject then p:SyncBookObject() end
        if PaintInk then PaintInk(repaint)end
        -- Repeated host layout ticks must not finish the writing effect. Start
        -- it only after the destination spread is installed, not on the sheet
        -- being turned away from a chapter selection.
        if repaint and #source>0 and not p.bookSection and not p.closedBookSide and not p.turnState then doc:RevealWords(ns.DB.journalWritingRate or 24) end
    end
    function p:BookLayout()
        if self.coverMotion then return end -- the fixed page block owns this scene until the board settles
        local available,h=self.book:GetWidth(),self.book:GetHeight()
        local nextSpread=available>=480
        local nextWidth=math.max(150,nextSpread and available*.29 or available*.66)
        -- Reserve the lower parchment for the folio and the curved outer edge.
        local nextHeight=math.max(80,h*.52)
        local nextKey=math.floor(nextWidth)..'/'..math.floor(nextHeight)..'/'..tostring(nextSpread)..'/'..tostring(doc.fontScale)
        -- Host refreshes often repeat the same layout. They must not cancel a turn.
        if self.turnState and nextKey==layoutKey then return end
        local changing=self.turnState and self.turnState.toSource and self.turnState.commit==true
        local anchor=changing and {block=1,leaf=1} or doc:GetReadingAnchor();if self.CancelPageTurn then self:CancelPageTurn() end
        spread,width,height=nextSpread,nextWidth,nextHeight
        local x=spread and available*.16 or (available-width)/2
        scroll:ClearAllPoints();scroll:SetPoint('TOPLEFT',x,-math.max(46,h*.22));scroll:SetSize(width,height)
        rightScroll:ClearAllPoints();rightScroll:SetPoint('TOPLEFT',available*.55,-math.max(46,h*.22));rightScroll:SetSize(width,height)
        right:SetFontScale(doc.fontScale or 1)
        art:SetShown(spread);for _,t in ipairs(single) do t:SetShown(not spread) end
        local key=math.floor(width)..'/'..math.floor(height)..'/'..tostring(spread)..'/'..tostring(doc.fontScale)
        if key~=layoutKey then layoutKey=key;Paginate();doc:RestoreReadingAnchor(anchor) end
        if self.LayoutBookEdges then self:LayoutBookEdges() end
        Render()
    end
    function doc:SetBlocks(blocks,sourceText)
        blocks=blocks or {}
        -- Background composition can replace spans/tables while the current
        -- sheet is in flight. Keep one latest update; do not repaint the old
        -- spread or cancel the animation before its destination is installed.
        if p.turnState and not p.sectionWrite and not p.sectionExitTransition then
            local copy={};for i,b in ipairs(blocks)do copy[i]=type(b)=='table'and Clone(b)or b end
            p.readerDeferredUpdate={blocks=copy,sourceText=sourceText,owner=p.owner,thread=p.threadId,volume=p.volumeId,section=p.bookSection}
            return
        end
        p.readerDeferredUpdate=nil
        -- A background manuscript update must not cancel the visible contents
        -- folio's turn or replace its current page.
        if p.bookSection and not p.sectionWrite then p.readerManuscriptSource=blocks;return end
        if p.turnState and not p.bookSection and not p.sectionExitTransition and #source==#blocks then
            local unchanged=true
            for i,b in ipairs(blocks) do
                local old=source[i]
                if type(b)~='table' or old.text~=b.text or old.id~=b.id or old.kind~=b.kind or old.activate~=b.activate or old.margin~=b.margin or old.spans~=b.spans then unchanged=false;break end
            end
            if unchanged then return end
        end
        if p.CancelPageTurn then p:CancelPageTurn() else turn:Hide();turn:SetScript('OnUpdate',nil) end;ink:Hide()
        blocks=blocks or {}
        if p.sectionExitTransition and not p.bookSection then p.sectionExitTransition=nil;p:SweepToBlocks(blocks);return end
        local identity=tostring(p.owner)..'/'..tostring(p.threadId)..'/'..tostring(p.volumeId)..'/'..tostring(p.selected)..'/'..tostring(p.bookSection)
        local anchor=p.readerSourceIdentity==identity and doc:GetReadingAnchor() or nil
        p.readerSourceIdentity=identity
        local same=#source==#blocks
        if same then for i,b in ipairs(blocks) do if source[i].text~=b.text or source[i].id~=b.id or source[i].kind~=b.kind or source[i].activate~=b.activate or source[i].doodle~=b.doodle or ns.AthenaBookArt.Key(source[i].journalArt)~=ns.AthenaBookArt.Key(b.journalArt) then same=false;break end end end
        if not same then source={};for i,b in ipairs(blocks) do source[i]=type(b)=='table' and Clone(b) or {text=b} end;sourceRevision=sourceRevision+1;pageIndex=1;Paginate()
            if anchor then doc:RestoreReadingAnchor(anchor) end
        end
        if p.readerLandingLeaf then pageIndex=p.readerLandingLeaf=='last'and #pages or tonumber(p.readerLandingLeaf)or 1;p.readerLandingLeaf=nil;if spread then pageIndex=math.floor((pageIndex-1)/2)*2+1 end end
        Render()
    end
    function doc:GetText() local out={};for _,b in ipairs(source) do out[#out+1]=b.text or '' end;return table.concat(out,'\n') end
    function doc:GetReadingAnchor()
        local b=pages[pageIndex] and pages[pageIndex][1]
        if not b then return {leaf=pageIndex}end
        return {id=b and (b.originId or b.id),block=b and b.originBlock or 1,offset=b and b.originOffset or 0,leaf=pageIndex}
    end
    function doc:RestoreReadingAnchor(anchor)
        if not anchor then return end
        local found, bestOffset
        for i,page in ipairs(pages) do for _,b in ipairs(page) do
            local matches=(anchor.id and (b.id==anchor.id or b.originId==anchor.id)) or (not anchor.id and b.originBlock==anchor.block)
            local offset=b.originOffset or 0
            if matches and offset<=(anchor.offset or 0) and (not bestOffset or offset>=bestOffset) then found=i;bestOffset=offset end
        end end
        pageIndex=found or math.max(1,math.min(tonumber(anchor.leaf) or pageIndex,#pages))
        if spread then pageIndex=math.floor((pageIndex-1)/2)*2+1 end;Render()
    end
    function p:ReaderSource() return source end
    function p:ReaderPageBounds()
        local out={limit=height,width=width,pages={}}
        for i,page in ipairs(pages) do local used=0;for _,b in ipairs(page) do used=used+Size(b)end;out.pages[i]=used end
        return out
    end
    function p:GoReadingPage(index)
        self.coverEndpoint=nil
        pageIndex=math.max(1,math.min(tonumber(index) or 1,#pages))
        if spread then pageIndex=math.floor((pageIndex-1)/2)*2+1 end
        Render();return true
    end
    function p:BookPlace() return {anchor=doc:GetReadingAnchor(),layout=layoutKey} end
    function p:RestoreBookPlace(place)
        if type(place)~='table' or type(place.anchor)~='table' then return end
        if place.layout==layoutKey then
            pageIndex=math.max(1,math.min(tonumber(place.anchor.leaf) or pageIndex,#pages));Render()
        else doc:RestoreReadingAnchor(place.anchor) end
    end

    -- Click-driven curved-sheet renderer. Visible regions are explicit texture
    -- quads, including every letter; there is no paused scale animation.
    local preview=CreateFrame('Frame',nil,p.book);preview:SetFrameLevel(p.book:GetFrameLevel()+40);preview:Hide()
    local guard=CreateFrame('Frame',nil,turn);guard:SetAllPoints(p.book);guard:SetFrameLevel(p.book:GetFrameLevel()+100);guard:EnableMouse(true)
    local leaf=CreateFrame('Frame',nil,turn);leaf:SetAllPoints(turn);leaf:SetFrameLevel(turn:GetFrameLevel()+1)
    local surface=ns.AthenaBookTurnSurface.New(leaf)
    local underSurface=ns.AthenaBookTurnSurface.New(preview)
    local director=ns.AthenaBookMotion.For(p)
    local leafDoc,leafScroll=ns.Art.Document(leaf,0,0,300,400);leafDoc:SetStyle('paper');leafScroll:SetAlpha(0)
    local backDoc,backScroll=ns.Art.Document(leaf,0,0,300,400);backDoc:SetStyle('paper');backScroll:SetAlpha(0)
    local previewDoc,previewScroll=ns.Art.Document(preview,0,0,300,400);previewDoc:SetStyle('paper')
    previewScroll:SetAlpha(0) -- Destination ink appears only when the sheet lands.
    local previewPaper=preview:CreateTexture(nil,'BACKGROUND');previewPaper:SetAllPoints();previewPaper:SetTexture('Interface\\AddOns\\OlympusChatWarden\\Media\\Journal3\\OpenBook.tga')
    local function Geometry(rightSide)
        local w,h=p.book:GetWidth(),p.book:GetHeight()
        local spine,half,top,pageHeight=ns.AthenaBookScene.PageGeometry(w,h)
        return rightSide and spine or spine-half,half,pageHeight,w*.05,top
    end
    local function Typeset(document,viewport,frame,rightSide,blocks)
        local _,_,_,inset=Geometry(rightSide)
        viewport:ClearAllPoints();viewport:SetPoint('TOPLEFT',frame,'TOPLEFT',inset,-16);viewport:SetSize(width,height)
        document.bookInkOverlay=true;document:SetFontScale(doc.fontScale or 1);document:SetBlocks(blocks or {});document:Refit();viewport:SetVerticalScroll(0)
    end
    -- Still and moving ink use the same pre-laid-out glyph quads. Native
    -- EditBoxes retain selection/click targets, never a second visible layout.
    local still={};local inkTick=CreateFrame('Frame',nil,p.book)
    for i,d in ipairs({doc,right})do
        local frame=CreateFrame('Frame',nil,p.book);frame:SetAllPoints();frame:SetFrameLevel(p.book:GetFrameLevel()+5)
        still[i]={frame=frame,surface=ns.AthenaBookTurnSurface.New(frame),document=d}
        d.bookInkChanged=function()inkTick:SetScript('OnUpdate',function(self)if PaintInk then PaintInk(false)end;self:SetScript('OnUpdate',nil)end)end
    end
    HideInk=function(index)if index then still[index].frame:Hide()else for _,view in ipairs(still)do view.frame:Hide()end end end
    PaintInk=function(rebuild)
        if p.turnState or p.coverMotion then return end
        if p.closedBookSide or p.sourceRail:IsShown()or p.memoryRail:IsShown()then HideInk();return end
        for index,view in ipairs(still)do
            local shown=index==1 and scroll:IsShown()or index==2 and rightScroll:IsShown()
            view.frame:SetShown(shown)
            if shown then
                if rebuild or view.key~=renderedKey then
                    local side=index==2;local _,half,h,inset=Geometry(side)
                    view.surface:Clear();view.surface:AddFace('front',view.document,{rightSide=side,half=half,height=h,textWidth=width,inset=inset,folio=pageIndex+index-1,onlyInk=true})
                    view.surface:Draw(0,side,p.book:GetWidth(),p.book:GetHeight());view.key=renderedKey
                    view.blocks={};for i,b in ipairs(view.document.blocks or {})do view.blocks[i]=Clone(b)end
                end
                view.surface:Reveal(view.document)
            end
        end
    end
    function p:SetBookPresentationAlpha(alpha)
        art:SetAlpha(alpha);scroll:SetAlpha(alpha);rightScroll:SetAlpha(alpha)
        for _,view in ipairs(still)do view.frame:SetAlpha(alpha)end
    end
    p.readerStillInk=still;p.RefreshPaperInk=function()PaintInk(false)end
    folioLeft:SetAlpha(0);folioRight:SetAlpha(0)
    local function StopTurn()
        if director.active and director.active.kind=='page'then director:Cancel(false)end
        p.readerDeferredUpdate=nil
        local state=p.turnState
        if state and state.toSource and state.commit==true then source,pages,pageIndex=state.toSource,state.toPages,state.target;sourceRevision=sourceRevision+1 end
        p.turnState=nil;turn:Hide();preview:Hide();turn:SetScript('OnUpdate',nil);surface:Hide();underSurface:Hide()
        scroll:SetAlpha(1);rightScroll:SetAlpha(1)
        leafDoc:SetBlocks({});backDoc:SetBlocks({});previewDoc:SetBlocks({})
        folioLeft:SetShown(not p.closedBookSide);folioRight:SetShown(not p.closedBookSide)
        if PaintInk then PaintInk(false)end
    end
    function p:CancelPageTurn() StopTurn() end
    function p:UpdatePageTurn(progress)
        local state=self.turnState;if not state then return false end
        state.progress=math.max(0,math.min(1,progress))
        leaf:Show();leaf:SetAlpha(1)
        surface:Draw(state.progress,state.delta<0,self.book:GetWidth(),self.book:GetHeight())
        state.visibleInk=surface.visibleInk;state.visiblePaper=surface.visiblePaper
        local w,h=self.book:GetWidth(),self.book:GetHeight();local lift=math.sin(state.progress*math.pi)
        local minX,maxX=w*.5,w*.5
        for i=0,16 do local x=surface:Point(i/16,.5,state.delta<0,state.progress,state.delta<0);minX=math.min(minX,x);maxX=math.max(maxX,x)end
        local shadowWidth=math.max(w*.12,maxX-minX+w*.08)
        local _,_,pageTop,pageHeight=ns.AthenaBookScene.PageGeometry(w,h)
        foldShadow:ClearAllPoints();foldShadow:SetPoint('TOPLEFT',self.book,'TOPLEFT',minX-w*.04,-pageTop-h*.03)
        foldShadow:SetSize(shadowWidth,pageHeight+h*.08);foldShadow:SetAlpha(.28*lift)
        return true
    end
    local function PrepareTurn(state)
        state.toPages=state.toPages or pages;state.bookWidth=p.book:GetWidth();state.bookHeight=p.book:GetHeight()
        local forward=state.delta<0;local origin,half,h,inset,top=Geometry(forward)
        -- Freeze what the reader is actually looking at, rather than a source
        -- page index that a section/navigation refresh may already have changed.
        local visibleInk=still[forward and spread and 2 or 1]
        local visible=forward and spread and right or doc
        local frontBlocks={};for i,b in ipairs(visibleInk.blocks or visible.blocks or {})do frontBlocks[i]=Clone(b)end
        state.frontSnapshot=frontBlocks
        p.turnState=state
        HideInk(forward and 2 or 1);if forward then rightScroll:SetAlpha(0)else scroll:SetAlpha(0)end
        preview:ClearAllPoints();preview:SetAllPoints(p.book)
        previewPaper:SetAlpha(0) -- The stationary page-block artwork owns this surface.
        previewPaper:SetTexture(ns.AthenaBookScene.Path('Paper'));previewPaper:SetTexCoord(0,1,0,1)
        Typeset(previewDoc,previewScroll,preview,forward,state.toPages[state.target+(forward and spread and 1 or 0)])
        Typeset(leafDoc,leafScroll,leaf,forward,state.frontSnapshot)
        Typeset(backDoc,backScroll,leaf,not forward,state.toPages[state.backPage])
        surface:Clear()
        surface:AddFace('front',leafDoc,{rightSide=forward,half=half,height=h,textWidth=width,inset=inset,folio=state.frontPage<=#pages and state.frontPage or nil,snapshot=visibleInk.surface})
        local _,_,_,backInset=Geometry(not forward)
        local writing=not p.bookSection and ns.DB.journalWritingRate~=0 and ns.DB.journalReducedMotion~=true
        local backUnwritten=writing and p.ReadingPageSeen and not p:ReadingPageSeen(state.backPage,state.toPages)
        local underPage=state.target+(forward and spread and 1 or 0)
        local underUnwritten=writing and p.ReadingPageSeen and not p:ReadingPageSeen(underPage,state.toPages)
        -- New manuscript ink is prepared but starts its first writing reveal
        -- only after landing. Already-read ink stays on its physical sheet.
        -- This avoids showing complete words in flight then clearing them.
        surface:AddFace('back',backDoc,{rightSide=not forward,half=half,height=h,textWidth=width,inset=backInset,folio=state.backPage<=#state.toPages and state.backPage or nil,hideInk=backUnwritten})
        underSurface:Clear();underSurface:AddFace('front',previewDoc,{rightSide=forward,half=half,height=h,textWidth=width,inset=inset,folio=underPage,onlyInk=true,hideInk=underUnwritten})
        underSurface:Draw(0,forward,p.book:GetWidth(),p.book:GetHeight())
        if forward then folioRight:Hide() else folioLeft:Hide() end
        preview:Show();turn:Show();p:UpdatePageTurn(0)
    end
    function p:BeginPageTurn(delta)
        if self.closedBookSide or self.turnState or (not self.bookSection and (self.sourceRail:IsShown() or self.memoryRail:IsShown())) then return false end
        doc:FinishWordReveal();right:FinishWordReveal();ink:Hide()
        local target=pageIndex-delta*(spread and 2 or 1)
        if target<1 or target>#pages then return false,'BOOK_EDGE' end
        local forward=delta<0
        PrepareTurn({delta=delta,target=target,from=pageIndex,progress=0,
            frontPage=pageIndex+(forward and spread and 1 or 0),backPage=target+(not forward and spread and 1 or 0)})
        if ns.WardenAudio then ns.WardenAudio.Play('book.page')end
        return true
    end
    function p:EndPageTurn(commit)
        local state=self.turnState;if not state then return false end
        state.commit=commit==true;local from=state.progress;local target=state.commit and 1 or 0;local elapsed=0
        local function finish()
            if self.turnState~=state then return end
            if state.commit then
                if state.toSource then source,pages=state.toSource,state.toPages end
                pageIndex=state.target
            else pageIndex=state.from end
            local pending=p.readerDeferredUpdate
            StopTurn();sourceRevision=sourceRevision+1;Render()
            if state.commit and ns.WardenAudio then ns.WardenAudio.Play('book.page.end')end
            if pending and pending.owner==p.owner and pending.thread==p.threadId and pending.volume==p.volumeId and pending.section==p.bookSection then
                doc:SetBlocks(pending.blocks,pending.sourceText)
            end
            if self.pendingWordReveal and not self.closedBookSide then local rate=self.pendingWordReveal;self.pendingWordReveal=nil;doc:RevealWords(rate) end
        end
        if ns.DB.journalReducedMotion==true then finish();return true end
        local duration=math.max(.24,ns.AthenaBookMotion.PAGE_SECONDS*math.abs(target-from))
        director:Start('page',turn,duration,function(q)self:UpdatePageTurn(from+(target-from)*q)end,finish)
        return true
    end
    function p:SweepToBlocks(blocks,direction,landing)
        self:CancelPageTurn()
        landing=landing or self.readerLandingLeaf
        if self.closedBookSide or self.openingCover or self.coverMotion or ns.DB.journalReducedMotion==true or #source==0 then self.readerLandingLeaf=landing;doc:SetBlocks(blocks);return end
        local priorSource,priorPages,priorIndex=source,pages,pageIndex
        source={};for i,b in ipairs(blocks) do source[i]=type(b)=='table' and Clone(b) or {text=b} end
        pageIndex=1;Paginate();local nextSource,nextPages=source,pages
        local target=landing=='last'and #nextPages or tonumber(landing)or 1;target=math.max(1,math.min(target,#nextPages));if spread then target=math.floor((target-1)/2)*2+1 end;self.readerLandingLeaf=nil
        source,pages,pageIndex=priorSource,priorPages,priorIndex
        local delta=direction or self.bookTurnDirection or -1;self.bookTurnDirection=nil;local forward=delta<0
        PrepareTurn({delta=delta,from=pageIndex,target=target,progress=0,
            frontPage=pageIndex+(forward and spread and 1 or 0),backPage=target+(not forward and spread and 1 or 0),toSource=nextSource,toPages=nextPages})
        self:EndPageTurn(true)
    end
    function p:TurnReadingPage(delta)
        if self.coverMotion then return true end
        self.coverEndpoint=nil
        if self.closedBookSide then self:OpenBook();return true end
        if self.turnState then return true end
        local ok,why=self:BeginPageTurn(delta,false)
        if why=='BOOK_EDGE' and self.OnBookBoundary and self:OnBookBoundary(delta) then return true end
        if why=='BOOK_EDGE' and self.CloseBook then self:CloseBook(delta>0 and 'front' or 'back');return true end
        if not ok or why then return ok end
        return self:EndPageTurn(true)
    end
    local edges={};p.pageTurnButtons={}
    for _,delta in ipairs({1,-1}) do
        local direction=delta
        local edge=CreateFrame('Button',nil,p.book);edges[#edges+1]=edge;edge:SetFrameLevel(p.book:GetFrameLevel()+20)
        edge:RegisterForClicks('LeftButtonUp')
        local hover=edge:CreateTexture(nil,'OVERLAY');hover:SetAllPoints();hover:SetColorTexture(.86,.67,.34,.10);hover:Hide()
        edge:SetScript('OnEnter',function() if not p.turnState then hover:Show() end end)
        edge:SetScript('OnLeave',function() hover:Hide() end)
        edge:SetScript('OnClick',function() hover:Hide();p:TurnReadingPage(direction) end)
        ns.Theme.Tooltip(edge,direction<0 and 'Turn the next page' or 'Turn the previous page','Click this edge of the journal to turn the paper across the spine.')
        local button=ns.UI2Components.Button(p.book,direction>0 and '‹'or'›',function()p:TurnReadingPage(direction)end,30)
        button:SetHeight(40);button:SetFrameLevel(p.book:GetFrameLevel()+21)
        ns.Theme.Tooltip(button,direction<0 and'Turn the next page'or'Turn the previous page')
        p.pageTurnButtons[#p.pageTurnButtons+1]=button
    end
    function p:LayoutBookEdges()
        local w,h=self.book:GetWidth(),self.book:GetHeight()
        for i,edge in ipairs(edges) do
            edge:ClearAllPoints();edge:SetPoint(i==1 and 'TOPLEFT' or 'TOPRIGHT',self.book,i==1 and 'TOPLEFT' or 'TOPRIGHT',i==1 and 3 or -3,-38)
            edge:SetSize(math.max(28,w*.05),math.max(60,h-68))
        end
        for i,button in ipairs(self.pageTurnButtons)do
            button:ClearAllPoints();button:SetPoint(i==1 and'RIGHT'or'LEFT',self.book,i==1 and'LEFT'or'RIGHT',i==1 and -4 or 4,0)
        end
    end
    p.bookCorners=edges;p.bookEdges=edges
    p.book:HookScript('OnSizeChanged',function(self)
        local state=p.turnState
        if state and state.bookWidth==self:GetWidth() and state.bookHeight==self:GetHeight() then return end
        StopTurn();Render()
    end)
    local combat=CreateFrame('Frame',nil,p.book);combat:RegisterEvent('PLAYER_REGEN_DISABLED');combat:SetScript('OnEvent',function() StopTurn();Render() end)
    p.book:HookScript('OnHide',function() StopTurn();right:FinishWordReveal();doc:FinishWordReveal();ink:Hide() end)
    local function readingKey(leaf,collection)
        local page=(collection or pages)[leaf];if not page or #page==0 then return end
        local parts={tostring(p.owner),tostring(p.threadId),tostring(p.volumeId),tostring(p.selected),tostring(p.bookSection),tostring(p.loreID)}
        for _,b in ipairs(page)do parts[#parts+1]=(b.kind or 'body')..':'..(b.text or '')end
        return ns.PackCrypto.Hex(ns.PackCrypto.SHA256(table.concat(parts,'\n')))
    end
    local function visits()
        if p.provider and p.provider.demo then p.revealedDemoPages=p.revealedDemoPages or {};return p.revealedDemoPages end
        local root=ns.DB.journalRevealPagesV1
        if type(root)~='table' or getmetatable(root)then root={};ns.DB.journalRevealPagesV1=root end
        return root
    end
    local function seen(leaf)
        local key=readingKey(leaf);local root=visits();local previous=key and type(root[key])=='number'
        if key then
            root[key]=ns.SafeNumber(ns.SafeCall(GetServerTime))or 1
            local n,oldest,at=0,nil,math.huge
            for k,t in pairs(root)do n=n+1;if k~=key and type(t)=='number'and t<at then oldest,at=k,t end end
            if n>2048 and oldest then root[oldest]=nil end
        end
        return previous
    end
    p.ReadingRevealKey=readingKey
    function p:ReadingPageSeen(leaf,collection)local key=readingKey(leaf,collection);return key and type(visits()[key])=='number'or false end
    local reveal=doc.RevealWords
    function doc:RevealWords(rate)
        if p.closedBookSide or p.openingCover then return end
        if p.turnState then p.pendingWordReveal=rate or 24;return end
        if self.wordReveal or right.wordReveal then return end
        local leftSeen=seen(pageIndex);local rightSeen=spread and seen(pageIndex+1)
        if ns.DB.journalWritingRate==0 or ns.DB.journalReducedMotion==true then self:FinishWordReveal();right:FinishWordReveal();return end
        rate=ns.DB.journalWritingRate or rate
        if not leftSeen then reveal(self,rate,true)end
        if spread and not rightSeen then
            right:RevealWords(rate,true)
            if self.wordReveal and right.wordReveal then
                right.wordReveal.resume=right:GetScript('OnUpdate');right.wordReveal.paused=true;right:SetScript('OnUpdate',nil)
            end
        end
        if not self.wordReveal and not right.wordReveal then return end
        ink:Show()
    end
    -- The page frame animates only while writing, then removes its callback.
    local glow=CreateFrame('Frame',nil,p.book)
    local oldReveal=doc.RevealWords
    function doc:RevealWords(rate)
        oldReveal(self,rate)
        if not self.wordReveal and not right.wordReveal then return end
        glow.elapsed=0;glow:SetScript('OnUpdate',function(self,dt)
            self.elapsed=self.elapsed+dt
            if not doc.wordReveal and right.wordReveal and right.wordReveal.paused then
                local r=right.wordReveal;r.paused=nil;right:SetScript('OnUpdate',r.resume);r.resume=nil
            end
            if not doc.wordReveal and not right.wordReveal then ink:Hide();self:SetScript('OnUpdate',nil);return end
            local active=doc.wordReveal and doc or right;local state=active.wordReveal;local row=state and state.queue[state.index]
            if row then local box=row.box;local size=ns.Theme.DocumentTextSize('body',doc.fontScale)
                if self.row~=row or self.word~=row.at then
                    self.row,self.word=row,row.at
                    local x,line,lastX,lastWidth=0,0,0,24;local ordinal=0
                    for word in row.text:gmatch('%S+%s*') do
                        ordinal=ordinal+1;box.measure:SetText(word);local w=math.max(1,box.measure:GetStringWidth() or size*#word*.5)
                        if x+w>box:GetWidth()-8 and x>0 then x=0;line=line+1 end
                        lastX,lastWidth=x,w;x=x+w;if ordinal>=math.max(1,row.at or 1) then break end
                    end
                    ink:ClearAllPoints();ink:SetPoint('TOPLEFT',box,'TOPLEFT',lastX-3,-line*(size+3)+1);ink:SetSize(math.min(lastWidth+8,box:GetWidth()),size+5)
                end
                ink:SetAlpha(.65+.25*math.sin(self.elapsed*4)^2)
            end
            for _,d in ipairs({doc,right}) do local r=d.wordReveal;local row=r and r.queue[r.index];if row then row.box:SetTextColor(.105,.065,.035,d.bookInkOverlay and 0 or 1) end end
        end)
    end
    -- Both folios must disappear when sources or memories replace the page.
    scroll:HookScript('OnHide',function() rightScroll:Hide();glow:SetScript('OnUpdate',nil);ink:Hide() end)
    local function wheel(_,delta) if delta~=0 then p:TurnReadingPage(delta>0 and 1 or -1) end end
    for _,frame in ipairs({p.book,scroll,rightScroll,doc,right}) do frame:EnableMouseWheel(true);frame:SetScript('OnMouseWheel',wheel) end
    p.writingGlow=ink;p.writingGlowFrame=glow
    p.readerLeaf=leaf;p.readerLeafDocument=leafDoc;p.readerReverseDocument=backDoc;p.readerSurface=surface;p.readerUnderSurface=underSurface;p.readerPreviewDocument=previewDoc;p.bookTurn=turn;p.bookPages=function() return pages end
    ns.AthenaBookObject.Attach(p,art,single,folioLeft,folioRight)
end
