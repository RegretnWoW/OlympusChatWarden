local _,ns=...
local S,T=ns.Spelling,ns.Theme
local popup,heading,status,buttons,previous,nextWord,add,ignore,suggestionPanel
local marks,measure={},nil
S.marks=marks
local selected=1
local function Button(parent,label,x,y,width,fn,help)
    if ns.Workspace then local b=ns.Art.Button(parent,label,x,y,width,24,fn,'neutral');T.Tooltip(b,label,help);return b end
    local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetSize(width,24);b:SetPoint('TOPLEFT',x,y)
    b:SetText(label);b:SetScript('OnClick',fn);T.Tooltip(b,label,help);return b
end
local function Text(parent,x,y,width,value)
    local t=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
    t:SetPoint('TOPLEFT',x,y);t:SetWidth(width);t:SetJustifyH('LEFT');t:SetText(value or '');T.Light(t);return t
end
local function Position(frame,edit)
    local ok,x,y,w,h=pcall(edit.GetRect,edit)
    local scale=ns.SafeNumber(S.Call(edit,'GetEffectiveScale'))
    local ui=ns.SafeNumber(ns.SafeCall(UIParent.GetEffectiveScale,UIParent))
    x,y,w,h=ns.SafeNumber(x),ns.SafeNumber(y),ns.SafeNumber(w),ns.SafeNumber(h)
    if not ok or not x or not y or not w or not h or not scale or not ui or ui<=0 then return false end
    x,y,w,h=x*scale/ui,y*scale/ui,w*scale/ui,h*scale/ui
    local screenW=ns.SafeNumber(UIParent:GetWidth());local screenH=ns.SafeNumber(UIParent:GetHeight())
    if not screenW or not screenH then return false end
    local left=math.max(0,math.min(x,screenW-frame:GetWidth()))
    local bottom=y-frame:GetHeight()-3
    if bottom<0 then bottom=y+h+3 end
    bottom=math.max(0,math.min(bottom,screenH-frame:GetHeight()))
    frame:ClearAllPoints();frame:SetPoint('BOTTOMLEFT',UIParent,'BOTTOMLEFT',left,bottom);return true
end
local function Build()
    if popup then return end
    measure=UIParent:CreateFontString(nil,'OVERLAY');measure:Hide()
    local ok,frame=pcall(CreateFrame,'Frame','OlympusChatWardenSpellingPopup',UIParent,not ns.Workspace and 'BasicFrameTemplateWithInset' or nil)
    popup=ok and frame or CreateFrame('Frame','OlympusChatWardenSpellingPopupBasic',UIParent,'BackdropTemplate')
    popup:SetSize(370,350);popup:SetFrameStrata('TOOLTIP');popup:SetClampedToScreen(true);popup:EnableMouse(true)
    -- Keep the source window open. This small popup is deliberately outside
    -- Theme's feature-window stack, and closes when another window takes focus.
    T.SkinWindow(popup);T.Title(popup,'Spelling suggestions');T.Crest(popup,12,-8,44);popup:SetFrameLevel(100)
    if popup.CloseButton then popup.CloseButton:SetScript('OnClick',function() S.Hide();if S.Eligible(S.target) then S.target:SetFocus() end end) end
    heading=T.Gold(Text(popup,64,-28,290))
    Text(popup,64,-48,290,'Choose a replacement, save the word, or skip it.')
    suggestionPanel=T.Panel(popup,12,-76,346,166);S.suggestionPanel=suggestionPanel
    buttons={}
    for i=1,6 do buttons[i]=Button(suggestionPanel,'',8,-7-(i-1)*26,330,function(self)
        local item=S.results and S.results[selected]
        local ok,err=S.Correct(S.target,S.snapshot,item,self.replacement)
        if err then status:SetText(err) end
        if ok then S.Hide();S.snapshot=nil end
    end,'Replace only this occurrence in the original input. The message is not sent.') end
    previous=Button(popup,'Previous',12,-250,106,function() S.OpenSuggestions(selected-1) end,'Review the previous possible mistake.')
    nextWord=Button(popup,'Next',126,-250,106,function() S.OpenSuggestions(selected+1) end,'Review the next possible mistake.')
    Button(popup,'Close',240,-250,118,function() S.Hide();if S.Eligible(S.target) then S.target:SetFocus() end end,'Close suggestions and continue typing.')
    add=Button(popup,'Add word',12,-280,166,function()
        local item=S.results and S.results[selected];if item then S.AddWord(item.word) end;S.Hide();S.snapshot=nil
        if S.Eligible(S.target) then S.target:SetFocus() end
    end,'Remember this word in your personal dictionary on this account.')
    ignore=Button(popup,'Ignore this session',186,-280,172,function()
        local item=S.results and S.results[selected];if item then S.Ignore(item.word) end;S.Hide();S.snapshot=nil
        if S.Eligible(S.target) then S.target:SetFocus() end
    end,'Stop flagging this word until logout or reload.')
    status=T.Muted(Text(popup,14,-315,342))
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]='OlympusChatWardenSpellingPopup' end
    S.popup=popup;popup:Hide()
end
local function Mark(index,edit,item,snapshot)
    local mark=marks[index]
    if not mark then
        mark=CreateFrame('Button',nil,UIParent);marks[index]=mark;mark:SetFrameStrata('TOOLTIP');mark:SetFrameLevel(90)
        mark:RegisterForClicks('RightButtonUp');mark:EnableMouse(true)
        if mark.SetPassThroughButtons then pcall(mark.SetPassThroughButtons,mark,'LeftButton','MiddleButton','Button4','Button5') end
        local color=mark:CreateTexture(nil,'BACKGROUND');color:SetAllPoints(mark);color:SetColorTexture(1,0.22,0.04,0.30);mark.color=color
        local line=mark:CreateTexture(nil,'ARTWORK');line:SetPoint('BOTTOMLEFT',0,0);line:SetPoint('BOTTOMRIGHT',0,0);line:SetHeight(2);line:SetColorTexture(1,0.32,0.05,0.95);mark.line=line
        mark:SetScript('OnClick',function(self,button)
            if button=='RightButton' then S.OpenSuggestions(self.resultIndex,self.edit,self.snapshot,self.results) end
        end)
        T.Tooltip(mark,'Possible misspelling','Right-click for suggested spellings. Left-clicks continue to the original text field.')
    end
    mark.edit,mark.snapshot,mark.results,mark.resultIndex=edit,snapshot,S.results,index
    return mark
end
local function Font(edit)
    local ok,path,size,flags=pcall(function() return edit:GetFont() end)
    path=ok and ns.SafeString(path,260) or nil
    size=ok and ns.SafeNumber(size) or nil
    flags=ok and ns.SafeString(flags,64) or nil
    if path and size and size>0 and measure.SetFont then
        local called,success=pcall(measure.SetFont,measure,path,size,flags or '')
        if called and success~=false then return end
    end
    measure:SetFontObject(GameFontHighlight or 'GameFontHighlight')
end
local function Width(text) measure:SetText(text or '');return ns.SafeNumber(measure:GetStringWidth()) or #(text or '')*7 end
function S.Hide()
    if popup then popup:Hide() end
    for _,mark in ipairs(marks) do mark:Hide() end
end
function S.Visible()
    if popup and popup:IsShown() then return true end
    for _,mark in ipairs(marks) do if mark:IsShown() then return true end end
    return false
end
function S.IsPopupFocus(edit)
    -- A button click may clear keyboard focus; retain the target only while our
    -- popup is visible. A different focused input always replaces the session.
    return popup and popup:IsShown() and edit==nil and S.Eligible(S.target)
end
function S.OpenSuggestions(index,edit,snapshot,results)
    if edit then S.target,S.snapshot,S.results=edit,snapshot,results end
    if not S.Active() or not S.Eligible(S.target) then S.Reset();return false end
    if S.Call(S.target,'GetText')~=S.snapshot then S.Reset();return false end
    local results=S.results or {};if #results==0 then return false end
    Build();selected=math.max(1,math.min(index or 1,#results))
    local item=results[selected];local choices=S.Suggest(item.word)
    heading:SetText('Spelling '..selected..' / '..#results..': '..item.original)
    for i,b in ipairs(buttons) do
        b.replacement=choices[i];b:SetShown(choices[i]~=nil)
        if choices[i] then b:SetText(choices[i]) end
    end
    previous:SetEnabled(selected>1);nextWord:SetEnabled(selected<#results)
    status:SetText(#choices==0 and 'No suggestion found. You can add or ignore this word.'
        or (ns.DB.spelling.autoCorrect and 'Automatic correction is on for high-confidence typos only.' or 'Right-click suggestions never send your text.'))
    if not Position(popup,S.target) then S.Hide();return false end
    T.RegisterPopup(S.target,S.Hide)
    for _,mark in ipairs(marks) do mark:Hide() end
    popup:Show();return true
end
function S.ShowHighlights(edit,results)
    if #results==0 then S.Hide();return end
    Build()
    if popup:IsShown() then return end
    Font(edit)
    local text=S.Call(edit,'GetText') or ''
    local width=ns.SafeNumber(S.Call(edit,'GetWidth')) or 0
    local height=ns.SafeNumber(S.Call(edit,'GetHeight')) or 0
    local multiline=ns.Checked(S.Call(edit,'IsMultiLine'))
    local left,right=0,0
    if edit.GetTextInsets then
        local ok,a,b=pcall(edit.GetTextInsets,edit)
        if ok then left,right=ns.SafeNumber(a) or 0,ns.SafeNumber(b) or 0 end
    end
    local available=math.max(1,width-left-right);local cursor=ns.SafeNumber(S.Call(edit,'GetCursorPosition')) or #text
    local scroll=0
    if not multiline then scroll=math.max(0,Width(text:sub(1,cursor))-available+4) end
    for i,item in ipairs(results) do
        local mark=Mark(i,edit,item,S.snapshot);local x=left+Width(text:sub(1,item.first-1))-scroll
        local w=math.max(6,Width(item.original))
        if not multiline and x+w>=left and x<=left+available then
            -- Marks are pooled across inputs. A managed window may have fixed
            -- their layers since the last use; release those locks before moving.
            local fixedStrata=mark.HasFixedFrameStrata and mark:HasFixedFrameStrata()
            local fixedLevel=mark.HasFixedFrameLevel and mark:HasFixedFrameLevel()
            if mark.SetFixedFrameStrata then mark:SetFixedFrameStrata(false) end
            if mark.SetFixedFrameLevel then mark:SetFixedFrameLevel(false) end
            mark:SetParent(edit);mark:SetFrameStrata(edit:GetFrameStrata());mark:SetFrameLevel(edit:GetFrameLevel()+1)
            if fixedStrata then mark:SetFixedFrameStrata(true) end
            if fixedLevel then mark:SetFixedFrameLevel(true) end
            mark:ClearAllPoints();mark:SetPoint('LEFT',edit,'LEFT',x,0)
            mark:SetSize(w,math.max(12,height-4));mark:Show()
        else mark:Hide() end
    end
    for i=#results+1,#marks do marks[i]:Hide() end
end
