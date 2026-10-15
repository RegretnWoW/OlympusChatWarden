local _,ns=...
local T,C=ns.Theme,ns.ChatCapture
local panel,rows,listTitle,empty,details,scroll,previous,nextPage,pager,status,start,bookmark,remove,titleBox,noteBox,footer
local selected,view,page,query=nil,'capture',1,''
local queued,clearArmed=false,false
local function Plain(text) return (text or ''):gsub('|','||') end
local function Text(parent,x,y,width,text,paper)
    local t=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');t:SetPoint('TOPLEFT',x,y)
    t:SetWidth(width);t:SetJustifyH('LEFT');t:SetText(text or '');if paper then T.Ink(t) else T.Light(t) end;return t
end
local function Button(parent,text,width,x,y,fn,help)
    local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetSize(width,24);b:SetPoint('TOPLEFT',x,y)
    b:SetText(text);b:SetScript('OnClick',fn);if help then T.Tooltip(b,text,help) end;return b
end
local function Items()
    local result={};local source=C.Records(view=='bookmarks')
    for i=#source,1,-1 do
        local item=source[i]
        if query=='' then result[#result+1]=item
        else
            local text=(item.title or '')..' '..(item.note or '')..' '..(item.sender or '')..' '..(item.recipient or '')..' '..(item.channel or '')..' '..(item.original or '')
            if view=='bookmarks' then for _,entry in ipairs(item.records) do text=text..' '..entry.sender..' '..(entry.recipient or '')..' '..entry.original end end
            if ns.Engine.Lower(text):find(query,1,true) then result[#result+1]=item end
        end
    end
    return result
end
local function Detail()
    local text='Record chat\n\nStart capture saves supported player chat until paused, including across reloads. Use the switches below for whispers and guild/officer chat.\n\nSave an incident\n\nSelect a line, then Save bookmark. It keeps up to 10 already captured lines on each side. Titles and notes are optional.\n\nExport\n\nExport shown opens selection and privacy controls. Check the final text before copying.\n\nStorage limits\n\nCapture: 5,000 lines / 4 MB. Oldest lines roll off when full; there is no age expiry.\nBookmarks: 50 / 1 MB. Clearing capture keeps bookmarks.\nBattle.net, NPC and addon traffic are excluded.'
    if selected then
        if view=='bookmarks' then
            local lines={selected.title,selected.note or ''}
            for _,entry in ipairs(selected.records) do lines[#lines+1]=C.Line(entry) end
            text=table.concat(lines,'\n\n')
        else text=C.Line(selected) end
    end
    details:SetText(Plain(text));details:SetCursorPosition(0);details:ClearFocus()
    bookmark:SetEnabled(selected~=nil);bookmark:SetText(view=='bookmarks' and 'Save changes' or 'Save bookmark')
    remove:SetEnabled(selected~=nil and view=='bookmarks')
end
local function Select(item)
    selected=item;titleBox:SetText(item and view=='bookmarks' and item.title or '');noteBox:SetText(item and view=='bookmarks' and item.note or '')
    titleBox:ClearFocus();noteBox:ClearFocus();scroll:SetVerticalScroll(0);Detail()
end
local function Refresh()
    if not panel or not panel:IsShown() then return end
    start:SetText(C.db.enabled and 'Pause capture' or 'Start capture')
    status:SetText((C.db.enabled and 'Recording' or 'Paused')..'  |  '..#C.db.entries..' / 5,000 lines  |  '..#C.db.bookmarks..' bookmarks')
    local items=Items();local pages=math.max(1,math.ceil(#items/9));page=math.min(page,pages)
    local present=not selected
    for _,item in ipairs(items) do if item==selected then present=true end end
    if not present then Select(nil) end
    listTitle:SetText((view=='bookmarks' and 'Bookmarks' or 'Captured chat')..'  |  '..#items..' shown')
    empty:SetShown(#items==0)
    empty:SetText(query~='' and 'No matches.\n\nTry another name or clear the search.' or view=='bookmarks' and 'No bookmarks yet.\n\nPick a captured line and save a bookmark.' or 'No captured chat yet.\n\nStart capture to record future player messages.')
    pager:SetText('Page '..page..' / '..pages);previous:SetEnabled(page>1);nextPage:SetEnabled(page<pages)
    for i,row in ipairs(rows) do
        local item=items[(page-1)*9+i];row.item=item;row:SetShown(item~=nil)
        if item then
            row.label:SetText(Plain(view=='bookmarks' and item.title or item.sender..(item.recipient and ' -> '..item.recipient or '')))
            row.preview:SetText(Plain((view=='bookmarks' and (#item.records..' saved lines') or item.original):gsub('[\r\n]',' ')))
            T.RowState(row,item==selected,'Unchanged')
        end
    end
end
function ns.RefreshCapture()
    if queued or not panel or not panel:IsShown() then return end
    queued=true
    local function Run() queued=false;Refresh() end
    if C_Timer and C_Timer.After then C_Timer.After(0,Run) else Run() end
end
function ns.BuildCaptureReview(parent)
    if panel then return panel end
    panel=CreateFrame('Frame',nil,parent);panel:SetAllPoints(parent);ns.CaptureWindow=panel
    local toolbar=T.Panel(panel,14,-70,912,44)
    Text(toolbar,10,-15,50,'Show')
    ns.CaptureSource=T.Dropdown(toolbar,57,-9,157,{{'capture','Captured chat'},{'bookmarks','Bookmarks'}},function() return view end,
        function(v) view=v;page=1;Select(nil);Refresh() end)
    local search=CreateFrame('EditBox',nil,toolbar,'SearchBoxTemplate');search:SetSize(225,24);search:SetPoint('TOPLEFT',230,-10)
    search:SetAutoFocus(false);search:SetMaxLetters(128);T.TextField(search)
    search:SetScript('OnTextChanged',function(self)
        if SearchBoxTemplate_OnTextChanged then SearchBoxTemplate_OnTextChanged(self) end
        query=ns.Engine.Lower(self:GetText() or '');page=1;Refresh()
    end)
    search:SetScript('OnEscapePressed',function(self) self:ClearFocus() end);ns.CaptureSearch=search
    start=Button(toolbar,'Start capture',130,472,-10,function() C.SetOption('enabled',not C.db.enabled);Refresh() end,
        'Record supported player chat locally, including checked private chat types. Pause stops new recording and keeps saved chat. Recording works independently of filtering.')
    ns.CaptureExportButton=Button(toolbar,'Export shown',146,752,-10,function() ns.OpenExport(view=='bookmarks' and 'bookmarks' or 'capture',nil,Items()) end,
        'Preview the entries matching this view and search. Choose which entries, names and notes to share before copying.')
    local clear=Button(toolbar,'Clear capture',130,612,-10,function(self)
        if not clearArmed then clearArmed=true;self:SetText('Click to confirm');return end
        clearArmed=false;self:SetText('Clear capture');C.Clear();Select(nil);Refresh()
    end,'Click twice to delete the rolling capture. Saved bookmarks stay. Pause first if you want recording to stop too.')
    panel:SetScript('OnHide',function() clearArmed=false;clear:SetText('Clear capture') end)
    local list=T.Panel(panel,14,-122,350,444);listTitle=Text(list,12,-12,326);empty=T.Muted(Text(list,18,-68,314));rows={}
    for i=1,9 do
        local row=CreateFrame('Button',nil,list);rows[i]=row;row:SetSize(332,42);row:SetPoint('TOPLEFT',9,-34-(i-1)*44)
        row.background=row:CreateTexture(nil,'BACKGROUND');row.background:SetAllPoints()
        row.label=Text(row,12,-6,309);row.label:SetWordWrap(false)
        row.preview=T.Muted(Text(row,12,-23,309));row.preview:SetWordWrap(false);T.SkinRow(row)
        row:SetScript('OnClick',function(self) Select(self.item);Refresh() end)
        T.Tooltip(row,'Read this entry','Read the original on the right. Select a captured line to save the surrounding conversation as a bookmark.')
    end
    previous=Button(panel,'Previous',94,14,-577,function() page=math.max(1,page-1);Refresh() end)
    pager=Text(panel,121,-583,145);nextPage=Button(panel,'Next',94,270,-577,function() page=page+1;Refresh() end)
    local header=T.Panel(panel,376,-122,550,34);status=T.Gold(Text(header,12,-10,526))
    local paper=T.Panel(panel,376,-159,550,407,true)
    scroll=CreateFrame('ScrollFrame',nil,paper,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',16,-16);scroll:SetSize(502,204)
    details=CreateFrame('EditBox',nil,scroll);details:SetMultiLine(true);details:SetAutoFocus(false);T.Body(details)
    details:SetSize(502,204);scroll:SetScrollChild(details);T.Ink(details);T.TextField(details,scroll)
    details:HookScript('OnTextChanged',function(_,user) if user then Detail() end end)
    details:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
    Text(paper,18,-230,510,'Bookmark title',true)
    titleBox=CreateFrame('EditBox',nil,paper,'InputBoxTemplate');titleBox:SetSize(500,24);titleBox:SetPoint('TOPLEFT',24,-251)
    titleBox:SetMaxLetters(120);titleBox:SetAutoFocus(false);T.TextField(titleBox)
    Text(paper,18,-282,510,'Note (optional)',true)
    noteBox=CreateFrame('EditBox',nil,paper,'InputBoxTemplate');noteBox:SetSize(500,24);noteBox:SetPoint('TOPLEFT',24,-303)
    noteBox:SetMaxLetters(1000);noteBox:SetAutoFocus(false);T.TextField(noteBox)
    for _,box in ipairs({titleBox,noteBox}) do box:SetScript('OnEscapePressed',function(self) self:ClearFocus() end) end
    for i,spec in ipairs({{'whispers','Include whispers'},{'guild','Include guild / officer'}}) do
        local key=spec[1];local c=CreateFrame('CheckButton',nil,paper,'UICheckButtonTemplate');c:SetSize(26,26);c:SetPoint('TOPLEFT',12+(i-1)*260,-350)
        Text(c,30,-6,230,spec[2],true);c:SetChecked(C.db[key]);c:SetScript('OnClick',function(self) C.SetOption(key,ns.Checked(self:GetChecked())) end)
        T.Tooltip(c,spec[2],'Controls future recording of this chat type. Turning it off keeps lines already saved.')
    end
    bookmark=Button(panel,'Save bookmark',145,376,-577,function()
        if not selected then return end
        local ok,message
        if view=='bookmarks' then ok,message=C.UpdateBookmark(selected.id,titleBox:GetText(),noteBox:GetText())
        else ok,message=C.Bookmark(selected.id,titleBox:GetText(),noteBox:GetText()) end
        footer:SetText(message);Refresh();if view=='bookmarks' then Detail() end
    end,'Save this line and up to 10 already captured lines on each side, or update the selected bookmark title and note.')
    remove=Button(panel,'Delete bookmark',185,531,-577,function()
        if selected and view=='bookmarks' then C.RemoveBookmark(selected.id);Select(nil);Refresh() end
    end,'Delete the selected saved bookmark. The rolling chat capture stays.')
    footer=T.Muted(Text(panel,18,-615,898,'Saved locally until cleared or the storage limit is reached. Bookmarks survive clearing the capture.'))
    ns.CaptureRows,ns.CaptureStart,ns.CaptureBookmark,ns.CaptureTitle,ns.CaptureNote=rows,start,bookmark,titleBox,noteBox
    ns.CaptureRemove,ns.CaptureDetails=remove,details
    panel:SetScript('OnShow',Refresh);panel:Hide();Select(nil);return panel
end
function ns.OpenCapture() ns.OpenReview('capture') end
function ns.OpenCapturePlayer(name)
    ns.OpenCapture();view='capture';page=1;ns.CaptureSource:Refresh();Select(nil)
    ns.CaptureSearch:SetText(name or '');Refresh()
end
function ns.OpenCaptureBookmark(id)
    ns.OpenCapture();view='bookmarks';page=1;ns.CaptureSource:Refresh();ns.CaptureSearch:SetText('');Select(nil)
    for _,item in ipairs(C.db.bookmarks) do if item.id==id then Select(item);break end end
    Refresh()
end
