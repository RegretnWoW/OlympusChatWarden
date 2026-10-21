-- A clipped viewport with a bounded pool of rows, shared by review and exports.
local _,ns=...
local V=ns.Art
function V.ScrollingList(parent,x,y,width,height,step,create,bind)
    local view={items={},rows={},step=step,offset=0,create=create,bind=bind}
    local scroll=CreateFrame('ScrollFrame',nil,parent);view.scroll=scroll
    scroll:SetPoint('TOPLEFT',x,y);scroll:SetSize(width,height)
    local content=CreateFrame('Frame',nil,scroll);content:SetSize(width,1);scroll:SetScrollChild(content);view.content=content
    V.SkinScroll(scroll)
    function view:Render()
        if self.rendering then return end;self.rendering=true
        local capacity=math.max(1,math.ceil(self.scroll:GetHeight()/self.step)+1)
        local first=math.floor(self.offset/self.step)+1
        for i=1,capacity do
            local index=first+i-1;local item=self.items[index]
            local row=self.rows[i]
            if not row and item then
                row=self.create(self.content);self.rows[i]=row
                if row.GetObjectType and row:GetObjectType()=='Button' then ns.Theme.ClickSound(row,'button') end
            end
            if row then
                row:ClearAllPoints();row:SetPoint('TOPLEFT',0,-(index-1)*self.step)
                row:SetWidth(self.scroll:GetWidth());row:SetShown(item~=nil)
                if item then self.bind(row,item,index) else row.item=nil end
            end
        end
        for i=capacity+1,#self.rows do self.rows[i].item=nil;self.rows[i]:Hide() end
        self.first=first
        if self.Changed then self.Changed(first,math.min(#self.items,math.ceil((self.offset+self.scroll:GetHeight())/self.step)),#self.items) end
        self.rendering=false
    end
    function view:Resize(w,h)
        self.scroll:SetSize(w,h);self.content:SetWidth(w)
    end
    function view:SetItems(items,preserve)
        local offset=self.offset
        if preserve then
            local old=self.items[math.floor(offset/self.step)+1]
            if old then for i,item in ipairs(items) do if item==old or old.id~=nil and item.id==old.id then offset=(i-1)*self.step+offset%self.step;break end end end
        elseif not preserve then offset=0 end
        self.items=items
        local height=math.max(self.scroll:GetHeight(),#items*self.step)
        self.content:SetHeight(height)
        local maximum=math.max(0,height-self.scroll:GetHeight())
        self.offset=math.max(0,math.min(maximum,offset))
        if self.scroll.ChatWardenUpdateScrollRange then self.scroll.ChatWardenUpdateScrollRange(maximum) end
        if self.scroll:GetVerticalScroll()~=self.offset then self.scroll:SetVerticalScroll(self.offset) end
        self:Render()
    end
    scroll:HookScript('OnVerticalScroll',function(_,offset) view.offset=offset or 0;view:Render() end)
    return view
end
-- A reading view is a stable page, not a live scoreboard ticker. Collection and
-- background indexing continue; applying new history is an explicit UI action.
function V.HistoryUpdateButton(page,x,y,width)
    local b=V.Button(page,'Update view',x,y,width or 190,28,function()
        page.dirty=true;page:Refresh(true)
    end,'neutral');b:Hide();page.historyUpdate=b
    ns.Theme.Tooltip(b,'New history available','Apply newly recorded history to this list. Your current page stays still while recording continues.')
    return b
end
function V.HoldHistoryView(page,owner,key,force)
    local old=page.historyView;local S=ns.ChronicleStore;local c=S.Character(owner,false)
    if force or page.dirty or not old or old.owner~=owner or old.character~=c or old.key~=key or S.blocked
        or old.generation~=ns.ChronicleActivities.generation then return false end
    local changed=old.revision~=c.revision
    if page.historyUpdate then page.historyUpdate:SetShown(changed) end
    return true
end
function V.CommitHistoryView(page,owner,key)
    local c=ns.ChronicleStore.Character(owner,false)
    local revision=ns.ChronicleActivities.ViewRevision(page.state) or c and c.revision
    page.historyView=c and {owner=owner,character=c,key=key,revision=revision,generation=ns.ChronicleActivities.generation} or nil
    if page.historyUpdate then page.historyUpdate:SetShown(c and revision~=c.revision or false) end
end
