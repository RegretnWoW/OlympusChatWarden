-- Experimental copy: only the cover asset path is retargeted.
-- Covers and binding belong to the reader; closing never changes its manuscript.
local _,ns=...
local O={VERSION=1};ns.AthenaBookObject=O
local coverPath='Interface\\AddOns\\Fireside3DExperiment\\Media\\Library\\AthenaBookCovers.tga'
function O.Attach(p,art,single,folioLeft,folioRight)
    local cover=CreateFrame('Button',nil,p.book);cover:SetFrameLevel(p.book:GetFrameLevel()+220);cover:Hide()
    local motionGuard=CreateFrame('Frame',nil,p.book);motionGuard:SetAllPoints();motionGuard:SetFrameLevel(p.book:GetFrameLevel()+219);motionGuard:EnableMouse(true);motionGuard:Hide()
    local motion
    local leather=cover:CreateTexture(nil,'BACKGROUND');leather:SetAllPoints();leather:SetTexture(coverPath)
    local title=cover:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
    title:SetPoint('TOPLEFT',cover,'TOPLEFT',28,-60);title:SetPoint('TOPRIGHT',cover,'TOPRIGHT',-28,-60);title:SetHeight(66)
    title:SetTextColor(.83,.64,.32);title:SetText('ATHENA’S\nJOURNAL')
    local function Inscription(parent,text,callback)
        local button=CreateFrame('Button',nil,parent);button:SetSize(120,24)
        local label=button:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');label:SetAllPoints();label:SetText(text);label:SetTextColor(.70,.51,.26)
        button:SetScript('OnClick',callback);return button
    end
    local close=Inscription(p.book,'Close book',function() p:CloseBook('front') end)
    close:SetPoint('TOPRIGHT',p.book,'TOPRIGHT',-24,-10);close:SetFrameLevel(p.book:GetFrameLevel()+20)
    ns.Theme.Tooltip(close,'Close the journal','Keep your passage marked and inspect the covers.')
    ns.Theme.Tooltip(cover,'Athena’s Journal','Front: right opens the first page; left turns the book over. Back: left opens the last page; right turns it over. Drag sideways to turn the closed book over.')
    local function Paint()
        local front=p.closedBookSide=='front'
        leather:SetTexCoord(front and 0 or .5,front and .5 or 1,0,1)
        title:SetShown(front)
    end
    local function StopCover()
        cover:SetScript('OnUpdate',nil);cover.dragStart=nil;cover.dragMoved=nil;p.coverTurning=nil
        if motion then p.closedBookSide=not motion.opening and motion.side or nil;motion=nil end
        p.coverMotion=nil;motionGuard:Hide();if p.SetBookPresentationAlpha then p:SetBookPresentationAlpha(1)end
        if cover.turnWidth then cover:SetWidth(cover.turnWidth);cover.turnWidth=nil end
        cover:SetAlpha(1)
    end
    function p:SyncBookObject()
        if self.coverMotion then return end
        local closed=self.closedBookSide~=nil
        local w,h=self.book:GetWidth(),self.book:GetHeight()
        local ch=math.max(180,h-8);local cw=math.min(w-16,ch*.76)
        cover:ClearAllPoints();cover:SetPoint('CENTER',self.book,'CENTER',0,0);cover:SetSize(cw,ch)
        art:SetShown(not closed and w>=480)
        for _,texture in ipairs(single) do texture:Hide() end
        folioLeft:SetShown(not closed);folioRight:SetShown(not closed)
        self.libraryToggle:SetShown(not closed);close:SetShown(not closed)
        for _,corner in ipairs(self.bookCorners or {}) do corner:SetShown(not closed) end
        if closed then
            self.scroll:Hide();self.rightScroll:Hide();self.search:Hide();self.search:ClearFocus();self.notice:Hide()
            if self.memoryRail.privateEdit then self.memoryRail.privateEdit:Hide() end
            if self.recollectionEditor then self.recollectionEditor:Hide() end
            Paint();cover:Show()
        else cover:Hide() end
        if self.RefreshPaperInk then self:RefreshPaperInk()end
    end
    local function Transition(opening,side)
        local w,h=p.book:GetWidth(),p.book:GetHeight();local ch=math.max(180,h-8);local cw=math.min(w-16,ch*.76)
        motion={opening=opening,side=side};p.coverMotion=motion;motionGuard:Show();cover:Show();local elapsed=0
        p.closedBookSide=nil;p.scroll:Show();p:BookLayout();leather:SetTexCoord(side=='front'and 0 or .5,side=='front'and .5 or 1,0,1);title:SetShown(side=='front')
        -- A cover pivots about its binding. The sheet layout stays fixed while
        -- the cover folds away/towards the reader; only presentation is animated.
        cover:SetScript('OnUpdate',function(_,dt)
            elapsed=elapsed+math.min(math.max(dt or .016,0),.1);local t=math.min(1,elapsed/.65);local ease=.5-.5*math.cos(t*math.pi)
            local fold=opening and ease or 1-ease;local ratio=math.max(.003,math.cos(fold*math.pi/2));local front=side=='front'
            cover:ClearAllPoints();cover:SetPoint(front and'LEFT'or'RIGHT',p.book,'CENTER',(front and-1 or 1)*cw*.5*(1-fold),0);cover:SetSize(cw*ratio,ch)
            leather:SetTexCoord(front and 0 or .5,front and .5 or 1,0,1);title:SetShown(front and ratio>.7);cover:SetAlpha(opening and 1-ease*ease or 1)
            if p.SetBookPresentationAlpha then p:SetBookPresentationAlpha(opening and ease or 1-ease)end
            if t==1 then motion=nil;p.coverMotion=nil;StopCover();if opening then p.closedBookSide=nil else p.closedBookSide=side end;p:SyncBookObject();if opening then p:BookLayout()end end
        end)
    end
    function p:CloseBook(side)
        self:CancelPageTurn();StopCover();self.document:FinishWordReveal();self.rightPage:FinishWordReveal()
        side=side=='back'and'back'or'front'
        if ns.DB.journalReducedMotion~=true and not self.closedBookSide then Transition(false,side)else self.closedBookSide=side;self:SyncBookObject()end
        return true
    end
    function p:OpenBook()
        local side=self.closedBookSide;StopCover();self.closedBookSide=nil;cover:Hide();self.scroll:Show();self:BookLayout()
        if side and ns.DB.journalReducedMotion~=true then Transition(true,side)end
        if self.LayoutBookSearch then self:LayoutBookSearch() end
        return true
    end
    function p:ResetBookObject()
        StopCover();self:CancelPageTurn();self.closedBookSide=nil;cover:Hide()
    end
    function p:FlipClosedBook()
        if not self.closedBookSide or self.coverTurning then return false end
        local from=self.closedBookSide;local to=from=='front' and 'back' or 'front'
        if ns.DB.journalReducedMotion==true then self.closedBookSide=to;Paint();return true end
        self.coverTurning=true;local elapsed=0;cover.turnWidth=cover:GetWidth()
        cover:SetScript('OnUpdate',function(_,dt)
            elapsed=elapsed+math.min(dt or .016,.1);local t=math.min(1,elapsed/.5)
            self.closedBookSide=t<.5 and from or to;Paint()
            local ratio=math.abs(math.cos(t*math.pi));cover:SetWidth(math.max(1,cover.turnWidth*ratio));title:SetShown(self.closedBookSide=='front' and ratio>.7)
            cover:SetAlpha(ratio<.004 and 0 or 1)
            if t==1 then StopCover();Paint() end
        end)
        return true
    end
    function p:ActivateCover(half)
        if self.coverTurning or self.coverMotion or not self.closedBookSide then return false end
        if self.closedBookSide=='front' and half=='left' or self.closedBookSide=='back' and half=='right' then return self:FlipClosedBook() end
        return self:OpenBook()
    end
    local function Cursor()
        if not GetCursorPosition then return end
        local x=ns.SafeNumber(ns.SafeCall(GetCursorPosition));local scale=cover:GetEffectiveScale()
        return x and scale>0 and x/scale
    end
    cover:SetScript('OnMouseDown',function(_,button)
        if button~='LeftButton' or p.coverTurning then return end
        cover.dragStart=Cursor();cover.dragMoved=false
    end)
    cover:SetScript('OnMouseUp',function(_,button)
        if button~='LeftButton' or p.coverTurning then return end
        local x=Cursor();local moved=x and cover.dragStart and math.abs(x-cover.dragStart)>24
        cover.dragStart=nil
        if moved then p:FlipClosedBook()
        else local center=cover:GetLeft()+cover:GetWidth()/2
            local half=x and (x<center and 'left' or 'right') or (p.closedBookSide=='front' and 'right' or 'left')
            p:ActivateCover(half)
        end
    end)
    p.book:HookScript('OnHide',StopCover)
    p.book:HookScript('OnSizeChanged',function() StopCover() end)
    local combat=CreateFrame('Frame',nil,p.book);combat:RegisterEvent('PLAYER_REGEN_DISABLED');combat:SetScript('OnEvent',function() StopCover();Paint() end)
    p.bookCover=cover;p.closeBook=close
end
