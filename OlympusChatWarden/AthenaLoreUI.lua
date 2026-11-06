-- Same book, separate world-reference lens. Every visible row is gated first.
local _,ns=...
local L={};ns.AthenaLoreUI=L
local K=ns.Athena.Knowledge
function L.Attach(p)
    function p:LoreContext()
        if not self.provider or not self.provider:Allowed() then return nil end
        if not self.library.index or self.library.index.status~='READY' then
            return K.Context('chronicle',self.owner)
        end
        if self.loreIndex~=self.library.index then self.loreContext=nil;self.loreIndex=self.library.index end
        self.loreContext=self.loreContext or K.Context('chronicle',self.owner,{index=self.library.index})
        return self.loreContext
    end
    function p:SetShelf(shelf)
        if not self.provider or not self.provider:Allowed() then self:Clear();return end
        self.sourceRail:Hide();self.pendingSource=nil;self.sourceMenu:Hide();self.original:Hide()
        if shelf=='lore' then
            if self.shelf~='lore' then self.novelPosition={threadId=self.threadId,volumeId=self.volumeId,selected=self.selected,place=self:BookPlace(),offset=self.scroll:GetVerticalScroll(),collection=self.collection,view=self.view} end
            self.shelf='lore';self.view='lore';self.loreContext=nil;self.loreCursor=nil;self.lorePages={};self.lorePage=1;self:RenderLoreList()
        else
            self.shelf='chronicle';self.loreID=nil;self.loreContext=nil;self.loreEntry=nil;self.loreRows=nil
            local b=self.novelPosition;self.novelPosition=nil
            if b then self.collection=b.collection;self.threadId=b.threadId;self.volumeId=b.volumeId;self.nextReadOffset=b.offset;self.readOffset=b.offset
                if b.selected then self:OpenStory(b.selected) elseif b.threadId then self:OpenThread(b.threadId,b.volumeId) end
                self:RestoreBookPlace(b.place)
            elseif self.threadId then self:ShowThread()
            elseif self.library.index and self.library.index.status=='READY' then self:SetCollection(self.collection) end
            self:RenderLibrary()
        end
        self:Layout(self:GetWidth(),self:GetHeight())
    end
    function p:RenderLoreList(query,cursor)
        self.collectionMenu:Hide();self.category:Hide();self.sort:Hide();self.contents:Hide();self.contextScroll:Hide();self.searchBox:Show();self.search:Show();self.loreSections:Show()
        self.loreQuery=query or self.loreQuery or '';local ctx=self:LoreContext()
        if not ctx then
            self.lorePending=true;self.loreRows=nil;self.list:SetItems({});self.previous:SetEnabled(false);self.next:SetEnabled(false);self.evidence:SetEnabled(false)
            self:ShowLoading('Connecting your discoveries to the history of Azeroth…');return
        end
        self.lorePending=nil
        local rows,nextPage=K.Search('LORE',{text=self.loreQuery,section=self.loreSection or 'all'},ctx,cursor,20)
        if not rows then self.loreContext=nil;self.loreEntry=nil;self.loreRows=nil;self.list:SetItems({});self.document:SetBlocks({{kind='title',text='Lore of Azeroth'},{text='The reference is unavailable for this character, permission or game version.'}});return end
        self.loreRows=rows;self.loreNext=nextPage;local list={}
        for _,entry in ipairs(rows) do list[#list+1]={kind='lore',loreID=entry.id or 'zone:'..entry.mapID,title=entry.title,subtitle='History of Azeroth'} end
        -- No count or hidden proper noun is presented for inaccessible material.
        if #list==0 then list[1]={kind='loreLocked',title='Undiscovered entry',subtitle='Story-Safe • no identifying preview'} end
        self.list:SetItems(list,true)
        local chosen
        for _,entry in ipairs(rows) do if (entry.id or 'zone:'..entry.mapID)==self.loreID then chosen=entry;break end end
        if not chosen then self.loreID=list[1].loreID end
        if self.loreID then self:OpenLore(self.loreID) else self.loreEntry=nil;self.document:SetBlocks({{kind='title',text='Lore of Azeroth'},{text='Your discoveries unlock more of this companion to My Chronicle. Unseen names and endings remain hidden.'}}) end
        self.previous:SetEnabled((self.lorePage or 1)>1);self.next:SetEnabled(nextPage~=nil);self.status:SetText('Lore of Azeroth • Story-Safe • History is distinct from personal deeds')
    end
    function p:OpenLore(id,restore)
        local ctx=self:LoreContext();local entry=ctx and K.GetLore(id,ctx)
        self.sourceRail:Hide();self.scroll:Show();self.sourceMenu:Hide();self.original:Hide();self.back:Hide();self.related:Hide();self.pendingSource=nil
        if not entry then self.loreEntry=nil;self.loreID=nil;self.document:SetBlocks({{kind='title',text='Undiscovered entry'},{text='This page is not available in the current Story-Safe view.'}});self.evidence:SetEnabled(false);return end
        local offset=restore and self.scroll:GetVerticalScroll() or 0;self.loreID=id;self.loreEntry=entry;self.view='lore'
        local blocks={{kind='meta',text=(self.provider.demo and 'SYNTHETIC • ' or '')..(entry.revealedManually and 'WORLD HISTORY • Explicit spoiler reading' or 'WORLD HISTORY • Story-Safe')},
            {kind='title',text=entry.title},{kind='meta',text=entry.era=='WC1_CLASSIC_FOREVER' and 'Warcraft I through Classic / Forever' or entry.era=='WC3_CLASSIC_FOREVER' and 'Warcraft III • Classic / Forever' or entry.era or 'FOREVER_START'}}
        if entry.catalogReferenceOnly then
            blocks[#blocks+1]={kind='meta',text='Basic source reference • current placement has not been verified.'}
            if entry.catalogReferenceMetadata and entry.catalogReferenceMetadata.sourceNameConflict then
                blocks[#blocks+1]={kind='meta',text='The sources give different names for this reference. Identity remains under review.'}
            end
        end
        if entry.facts then
            local labels={role='Place in the world',appearance='Appearance',location='Setting',history='History',motivation='Purpose',conflict='Conflict',stakes='What was at stake',outcome='Historical outcome',relationships='People and ties',context='The wider world'}
            for _,fact in ipairs(entry.facts) do blocks[#blocks+1]={kind='heading',text=labels[fact.field] or fact.field};blocks[#blocks+1]={id=fact.worldRef,text=fact.text} end
        else blocks[#blocks+1]={text=entry.body} end
        self.document:SetBlocks(blocks)
        for i=#self.relatedChoices,2,-1 do self.relatedChoices[i]=nil end;self.relatedChoices[1]={false,'Connected lore'}
        for _,id in ipairs(entry.relatedIDs or {}) do local other=K.GetLore(id,ctx);if other then self.relatedChoices[#self.relatedChoices+1]={id,other.title} end end
        self.related:Refresh();self.related:SetShown(self.relatedExpanded==true and #self.relatedChoices>1)
        self.scroll:SetVerticalScroll(offset);self.evidence:SetEnabled(true);self.list:Render()
    end
    function p:ShowLoreSources()
        local ctx=self:LoreContext();local e=ctx and self.loreID and K.GetLore(self.loreID,ctx)
        if not e then self:OpenLore(self.loreID);return end
        self.sourceRail:Show();self.scroll:Hide();self.sourceMenu:Hide();self.original:Hide();self.back:Hide()
        local blocks={{kind='title',text=(self.provider.demo and 'SYNTHETIC • ' or '')..'Source & Era'},{kind='heading',text='World history'},
            {text=e.title..'\n'..(e.era or 'FOREVER_START')},{kind='meta',text=e.worldRef..'\n'..e.sourceURL..(e.relatedWorldRef and ('\nQuest association: '..e.relatedWorldRef..'\n'..e.relatedSourceURL) or '')},
            {text='This is static world context. It does not claim that this character witnessed historical events, met an NPC, or received a reward.'},
            {kind='meta',text=e.missing and ('Unknown fields: '..table.concat(e.missing,', ')) or ''}}
        for _,fact in ipairs(e.facts or {}) do blocks[#blocks+1]={kind='meta',text=fact.field..' • '..fact.worldRef..'\n'..fact.sourceURL} end
        self.inspector:SetBlocks(blocks)
        self.inspectorScroll:SetVerticalScroll(0)
    end
    function p:LoreStep(delta)
        local page=self.lorePage or 1
        if delta<0 and self.loreNext then self.lorePages[page]=self.loreCursor;self.lorePage=page+1;self.loreCursor=self.loreNext;self:RenderLoreList(nil,self.loreCursor)
        elseif delta>0 and page>1 then self.lorePage=page-1;self.loreCursor=self.lorePages[page-1];self:RenderLoreList(nil,self.loreCursor) end
    end
    function p:RevealLore()
        local ctx=self:LoreContext();if not ctx then return end
        local ticket,warning=K.RequestReveal(ctx,'ALL');if not ticket then self.status:SetText('Reference spoilers are unavailable for this context.');return end
        self.revealTicket=ticket;self.revealContext=ctx
        self.sourceRail:Show();self.scroll:Hide();self.sourceMenu:Hide();self.original:Hide();self.back:Hide()
        self.inspector:SetBlocks({{kind='title',text='Reveal story spoilers?'},{text=warning},{text='Use Confirm spoilers to read eligible future references for this character. Cancel keeps Story-Safe mode. This does not change quest progress.'}})
        self.confirmSpoilers:Show();self.cancelSpoilers:Show()
    end
    function p:FinishReveal(confirmed)
        if self.revealContext then if confirmed then K.ConfirmReveal(self.revealContext,self.revealTicket) else K.CancelReveal(self.revealContext) end end
        self.revealTicket=nil;self.revealContext=nil;self.confirmSpoilers:Hide();self.cancelSpoilers:Hide();self.sourceRail:Hide()
        if confirmed then self:RenderLoreList() end
    end
    function p:RefreshLore()
        if not self.provider:Allowed() then self:Clear();return end
        if (self.lorePending or self.loreIndex~=self.library.index) and self.library.index and self.library.index.status=='READY' then self:RenderLoreList();return end
        if self.loreID and not K.GetLore(self.loreID,self:LoreContext()) then self.loreContext=nil;self.loreEntry=nil;self.loreID=nil;self.inspector:SetBlocks({});self.sourceRail:Hide();self:RenderLoreList() end
    end
end
