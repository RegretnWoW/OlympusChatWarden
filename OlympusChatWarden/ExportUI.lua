local _,ns=...
local T,E=ns.Theme,ns.Export
local instances={}
local function Instance(isReports)
local window,batch,rows,preview,scroll,count,pager,previous,nextPage,hideNames,includeNotes,extraNames,scope,scopeText,listView,listBatch
local page=1
local view,selected,deleteArmed='share'
local title,subtitle,listTitle,privacy,paper,reportPaper,reportDocument,reviewTab,shareTab,reportButton,deleteButton,copyButton,resetButton,includeAll,includeNone,footer,feedbackButton,backButton
local function Plain(text) return (text or ''):gsub('|','||') end
local function Text(parent,x,y,width,text,paper)
    local label=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
    label:SetPoint('TOPLEFT',x,y);label:SetWidth(width);label:SetJustifyH('LEFT');label:SetText(text or '')
    if paper then T.Ink(label) else T.Light(label) end;return label
end
local function Button(parent,text,width,x,y,fn,help)
    local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetSize(width,24);b:SetPoint('TOPLEFT',x,y)
    b:SetText(text);b:SetScript('OnClick',fn);if help then T.Tooltip(b,text,help) end;return b
end
local function ReportSections(item)
    if not item then return {'Select a saved report.\n\nReports save filter feedback. They do not change your rules.\n\nChoose Share preview to select reports, hide names and copy the final text.'} end
    local result=item.actualAction and ('Filter chose: '..T.Label(T.Actions,item.actualAction))
        or item.predictedAction and ('Settings when reported: '..T.Label(T.Actions,item.predictedAction))
        or 'Original filter result unavailable for this older report.'
    local parts={'Report #'..item.id..'\n'..result..'\nWanted: '..T.Label(T.Actions,item.expectedAction),'\nOriginal message',item.original}
    if item.originalTruncated then parts[#parts+1]='[Original shortened]' end
    if item.note and item.note~='' then parts[#parts+1]='\nYour note';parts[#parts+1]=item.note end
    return parts
end
local function BindRow(row,item,index)
    local reviewing=batch.kind=='reports' and view=='review'
    row.index=index;row.item=item;row.label:SetWidth(row:GetWidth()-24);row.detail:SetWidth(row:GetWidth()-24)
    row.label:SetText(reviewing and ('#'..item.id..'  |  '..(item.actualAction or 'Unknown')..' > '..(item.expectedAction or 'Unknown'))
        or ((batch.selected[index]==false and '[  ]  ' or '[x]  ')..Plain(ns.Reports.Clip(E.Label(item),72))))
    row.detail:SetText(Plain(ns.Reports.Clip(reviewing and (item.original or ''):gsub('[\r\n]',' ') or item.note or item.reason or item.event or item.expectedAction or '',72)))
    T.RowState(row,reviewing and item.id==selected or not reviewing and batch.selected[index]~=false,'Unchanged')
end
local function Refresh(rebuild)
    if not window or not batch then return end
    local reviewing=batch.kind=='reports' and view=='review'
    local toolTitle=batch.kind=='reports' and (reviewing and 'My Reports' or 'Report exports')
        or ({shield='Shield exports',capture='Chat Capture exports',bookmarks='Bookmark exports'})[batch.kind] or 'Export preview'
    window.ChatWardenTitle=toolTitle
    if ns.Workspace then ns.Workspace.ToolTitle(window,toolTitle) end
    local n=0;for i=1,#batch.items do if batch.selected[i]~=false then n=n+1 end end
    if rebuild then local json=E.Build(batch);preview:SetText(json);preview:SetCursorPosition(0);preview:ClearFocus();scroll:SetVerticalScroll(0) end
    count:SetText(reviewing and (#batch.items..' saved reports. Select a row to read it.') or (n..' / '..#batch.items..' entries included. Click a row to include or leave it out.'))
    title:SetText(batch.kind=='reports' and 'My reports' or 'Choose what to share')
    subtitle:SetText(reviewing and 'Read saved feedback or choose Share preview to prepare an export.' or 'Local preview. Nothing is sent for you. Selection and privacy changes rebuild the text.')
    footer:SetText(reviewing and 'Reports are saved on this account. Deleting a report leaves your rules unchanged.' or 'Check the final text, then Select all text and Ctrl+C. Other identifying details may remain.')
    listTitle:SetText(reviewing and 'My saved reports' or 'Entries to export')
    privacy:SetShown(not reviewing);paper:SetShown(not reviewing);reportPaper:SetShown(reviewing)
    includeAll:SetShown(not reviewing);includeNone:SetShown(not reviewing);reportButton:SetShown(reviewing)
    copyButton:SetShown(not reviewing);resetButton:SetShown(not reviewing);deleteButton:SetShown(reviewing)
    reviewTab:SetShown(batch.kind=='reports');shareTab:SetShown(batch.kind=='reports')
    reviewTab:SetEnabled(not reviewing);shareTab:SetEnabled(reviewing)
    if ns.Workspace then
        backButton:SetShown(not reviewing)
        ns.Workspace.Place(feedbackButton,window:GetWidth()-(reviewing and 138 or 258),-(window:GetHeight()-66),108,32)
        for _,pair in ipairs({{reviewTab,reviewing},{shareTab,not reviewing}}) do
            local button,active=pair[1],pair[2]
            if button.ArtNormal then
                button.ViewArt=button.ViewArt or ns.Art.Nine(button,'button')
                button.ViewArt:SetShown(active);button.ArtNormal:SetShown(not active);button.Caption:SetAlpha(1)
            end
        end
    end
    local current
    if listView then
        listView:SetItems(batch.items,listBatch==batch);listBatch=batch
    else
        local pages=math.max(1,math.ceil(#batch.items/9));page=math.min(page,pages)
        pager:SetText('Page '..page..' / '..pages);previous:SetEnabled(page>1);nextPage:SetEnabled(page<pages)
        for i,row in ipairs(rows) do
        local index=(page-1)*9+i;local item=batch.items[index];row.index=index;row.item=item;row:SetShown(item~=nil)
            if item then BindRow(row,item,index) end
        end
    end
    for _,item in ipairs(batch.items) do if item.id==selected then current=item;break end end
    if reviewing then
        if ns.Workspace then
            local blocks=current and {{text='Report #'..current.id,kind='title'},
                {text='Filter result',kind='heading'},{text=current.actualAction or current.predictedAction or 'Not recorded',kind='warning'},
                {text='Wanted result',kind='heading'},{text=T.Label(T.Actions,current.expectedAction),kind='accent'},
                {text='Original message',kind='heading'},{text=current.original,kind='quote'}}
                or {{text='Your saved reports',kind='title'},{text='Select a report on the left to read its original and feedback.',kind='body'},
                    {text='Ready to share?',kind='heading'},{text='Share preview lets you choose entries and hide names before copying. Reports stay local until you share them.',kind='body'}}
            if current and current.note and current.note~='' then blocks[#blocks+1]={text='Your note',kind='heading'};blocks[#blocks+1]={text=current.note,kind='body'} end
            reportDocument:SetBlocks(blocks,table.concat(ReportSections(current),'\n'))
        else reportDocument:SetSections(ReportSections(current)) end
    end
    deleteButton:SetEnabled(current~=nil);deleteButton:SetText(deleteArmed and 'Confirm delete' or 'Delete report')
    hideNames:SetChecked(batch.hideNames);includeNotes:SetChecked(batch.includeNotes)
end
local function View(value) view=value;deleteArmed=nil;Refresh() end
local function Open(kind,mode,records,requestedView)
    if not window then
        window=T.Window(isReports and 'OlympusChatWardenReports' or 'OlympusChatWardenExport',UIParent,940,678);ns.ExportWindow=window
        T.Title(window,ns.NAME);T.Crest(window)
        title=T.Gold(Text(window,78,-30,720,'Choose what to share'))
        subtitle=T.Muted(Text(window,78,-49,820,''))
        scope=T.Dropdown(window,14,-74,240,{{'all','All saved reports'},{'misses','Missed messages only'}},
            function() return batch and batch.mode or 'all' end,function(v) ns.OpenExport('reports',v,nil,view) end)
        reviewTab=Button(window,'Read reports',160,266,-74,function() View('review') end,'Read saved report details without leaving this window.')
        shareTab=Button(window,'Share preview',160,436,-74,function() View('share') end,'Choose entries and privacy options, then review the final text before copying.')
        scopeText=T.Gold(Text(window,606,-82,320))
        local toolbar=T.Panel(window,14,-108,912,44)
        includeAll=Button(toolbar,'Include all',116,10,-10,function() batch.selected={};Refresh(true) end,'Include every entry in this export snapshot.')
        includeNone=Button(toolbar,'Include none',116,136,-10,function()
            for i=1,#batch.items do batch.selected[i]=false end;Refresh(true)
        end,'Leave all entries out, then click just the ones you want.')
        reportButton=Button(toolbar,'Report a miss',156,10,-10,function() ns.OpenReport(nil,'Missed match') end,'Save a missed-filter example. This does not send a Blizzard player report.')
        count=Text(toolbar,266,-16,636)
        local list=T.Panel(window,14,-160,350,444);rows={}
        listTitle=T.Gold(Text(list,12,-12,326,'Entries to export'))
        local function NewRow(parent)
            local row=CreateFrame('Button',nil,parent);row:SetSize(332,ns.Workspace and 58 or 42)
            row.background=row:CreateTexture(nil,'BACKGROUND');row.background:SetAllPoints()
            row.label=Text(row,12,ns.Workspace and -12 or -6,308);row.label:SetWordWrap(false);if ns.Workspace then row.label:SetHeight(16) end
            row.title=row.label
            row.detail=T.Muted(Text(row,12,ns.Workspace and -32 or -23,308));row.detail:SetWordWrap(false);if ns.Workspace then row.detail:SetHeight(14) end;T.SkinRow(row)
            row:SetScript('OnClick',function(self)
                if batch.kind=='reports' and view=='review' then selected=self.item.id;deleteArmed=nil;Refresh();reportDocument:ClearFocus()
                else batch.selected[self.index]=batch.selected[self.index]==false;Refresh(true) end
            end)
            T.Tooltip(row,'Report or export entry','Read reports: select a report to read it. Share preview: include or leave out an entry without deleting the saved record.')
            return row
        end
        if ns.Workspace then
            listView=ns.Art.ScrollingList(list,9,-34,306,396,62,NewRow,BindRow);rows=listView.rows
        else
            for i=1,9 do local row=NewRow(list);rows[i]=row;row:SetPoint('TOPLEFT',9,-34-(i-1)*44) end
        end
        privacy=T.Panel(window,376,-160,550,138)
        T.Gold(Text(privacy,12,-12,526,'Privacy options'))
        local function Check(label,y,fn,help)
            local c=CreateFrame('CheckButton',nil,privacy,'UICheckButtonTemplate');c:SetSize(26,26);c:SetPoint('TOPLEFT',8,y)
            Text(c,30,-6,490,label);c:SetScript('OnClick',fn);T.Tooltip(c,label,help);return c
        end
        hideNames=Check('Hide known player names',-30,function(self) batch.hideNames=ns.Checked(self:GetChecked());Refresh(true) end,
            'Replace names ChatWarden knows with [player], including names inside message text and player links. Check for other identifying details yourself.')
        includeNotes=Check('Include notes / Shield reasons',-58,function(self) batch.includeNotes=ns.Checked(self:GetChecked());Refresh(true) end,
            'Notes and Shield reasons start left out. Rule-match details in filter reports stay included.')
        local extraLabel=Text(privacy,12,-91,526,'Other names to hide (separate with commas):')
        extraNames=CreateFrame('EditBox',nil,privacy,'InputBoxTemplate');extraNames:SetSize(508,24);extraNames:SetPoint('TOPLEFT',20,-108)
        extraNames:SetAutoFocus(false);extraNames:SetMaxLetters(1000);T.TextField(extraNames)
        extraNames:SetScript('OnTextChanged',function(self,user) if user then batch.extraNames=self:GetText() or '';Refresh(true) end end)
        extraNames:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
        T.Tooltip(extraNames,'Other names to hide','Add names from pasted reports that ChatWarden does not know. Turn on Hide known player names to apply them.')
        paper=T.Panel(window,376,-306,550,298,true)
        local previewHeading=T.Heading(Text(paper,14,-12,520,'Final text — you can edit this before copying',true))
        scroll=CreateFrame('ScrollFrame',nil,paper,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',14,-36);scroll:SetSize(502,246)
        preview=CreateFrame('EditBox',nil,scroll);preview.ChatWardenNoSpelling=true;preview:SetMultiLine(true);preview:SetAutoFocus(false);T.Body(preview)
        preview:SetMaxLetters(67108864);preview:SetSize(502,246);scroll:SetScrollChild(preview);T.Ink(preview);T.TextField(preview,scroll)
        preview:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
        reportPaper=ns.Workspace and ns.Art.Panel(window,376,-160,550,444,'paper') or T.Panel(window,376,-160,550,444,true)
        local reportScroll=CreateFrame('ScrollFrame',nil,reportPaper,'UIPanelScrollFrameTemplate')
        reportScroll:SetPoint('TOPLEFT',14,-14);reportScroll:SetSize(502,412)
        reportDocument=T.ReadOnlyDocument(reportScroll);if isReports then ns.PersonalDocument=reportDocument end
        if ns.Workspace then reportDocument:SetStyle('paper') end
        if listView then
            pager=Text(window,26,-621,324)
            listView.Changed=function(first,last,total) pager:SetText(total>0 and (first..'-'..last..' of '..total..'  |  Scroll to browse') or 'No entries') end
        else
            previous=Button(window,'Previous',94,14,-615,function() page=math.max(1,page-1);Refresh() end)
            pager=Text(window,121,-621,145)
            nextPage=Button(window,'Next',94,270,-615,function() page=page+1;Refresh() end)
        end
        copyButton=Button(window,'Select all text',145,376,-615,function() preview:SetFocus();preview:HighlightText() end,'Select the final text, then press Ctrl+C to copy it.')
        resetButton=Button(window,'Reset preview',185,531,-615,function() Refresh(true) end,'Rebuild the export using your choices. This discards edits made in the final text box.')
        deleteButton=Button(window,'Delete report',185,376,-615,function()
            if not selected then return end
            if deleteArmed~=selected then deleteArmed=selected;Refresh();return end
            ns.Personal.RemoveReport(selected);selected=nil;deleteArmed=nil;ns.RefreshReportsView()
        end,'Click twice to delete the selected saved report. Personal rules are kept.')
        feedbackButton=Button(window,'Feedback',86,726,-615,function() ns.OpenReportLink() end,'Open the GitHub feedback link. For moderator reports, use your own reporting channel.')
        backButton=Button(window,'Close',100,826,-615,function() window:Hide() end)
        footer=T.Muted(Text(window,18,-653,900,''))
        if ns.Workspace then
            local W=ns.Workspace
            function window:ChatWardenLayout(w,h)
                local left=340;local x=372;local right=w-x-18;local contentHeight=h-214
                W.Place(scope,18,-18,282,32);W.Place(reviewTab,314,-18,172,32);W.Place(shareTab,498,-18,172,32)
                W.Place(scopeText,batch and batch.kind=='reports' and 690 or 22,-28,batch and batch.kind=='reports' and w-712 or w-44)
                W.Place(toolbar,18,-64,w-36,48);W.Place(count,266,-17,w-312)
                W.Place(list,18,-128,left,contentHeight);W.Place(listTitle,14,-14,left-28)
                W.Place(listView.scroll,14,-44,left-48,contentHeight-62);listView:Resize(left-48,contentHeight-62)
                W.Place(privacy,x,-128,right,158);W.Place(extraLabel,14,-91,right-28);W.Place(extraNames,22,-114,right-44,28)
                W.Place(paper,x,-302,right,h-388);W.Place(previewHeading,14,-14,right-28)
                W.Place(scroll,14,-44,right-48,h-448)
                W.Place(reportPaper,x,-128,right,contentHeight);W.Place(reportScroll,14,-18,right-48,contentHeight-36)
                W.Place(pager,26,-(h-60),left-16)
                W.Place(copyButton,x,-(h-66),160,32);W.Place(resetButton,x+172,-(h-66),174,32)
                W.Place(deleteButton,x,-(h-66),185,32)
                W.Place(feedbackButton,w-258,-(h-66),108,32);W.Place(backButton,w-138,-(h-66),120,32)
                backButton:SetText('Back to Reports');W.Place(footer,22,-(h-22),w-44)
                listView:SetItems(batch and batch.items or {},true)
            end
            window.ChatWardenExportList=listView
        end
        window:SetScript('OnHide',function() preview:ClearFocus();extraNames:ClearFocus();reportDocument:ClearFocus();deleteArmed=nil end)
    end
    local keep=batch and batch.kind==kind and kind=='reports' and window:IsShown() and not records and (mode==nil or mode==batch.mode)
    if not keep then batch=E.Batch(kind,mode,records);page=1;selected=nil;extraNames:SetText('');extraNames:ClearFocus() end
    view=kind=='reports' and (requestedView or 'share') or 'share'
    window.ChatWardenTitle=kind=='reports' and (view=='review' and 'My Reports' or 'Report exports')
        or ({shield='Shield exports',capture='Chat Capture exports',bookmarks='Bookmark exports'})[kind] or 'Export preview'
    batch.mode=mode and (mode=='misses' and 'misses' or 'all') or batch.mode or 'all';scope:SetShown(kind=='reports');scope:Refresh()
    scopeText:ClearAllPoints();scopeText:SetPoint('TOPLEFT',kind=='reports' and 606 or 14,-82);scopeText:SetWidth(kind=='reports' and 320 or 912)
    scopeText:SetText(({reports='Filter feedback',shield='Current shielded players',capture='Captured chat',bookmarks='Saved incident bookmarks'})[kind] or kind)
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    if w and h and w>30 and h>30 then window:SetScale(math.min(1,(w-30)/940,(h-30)/678)) end
    ns.ExportBatch=batch;ns.ExportText=preview;ns.ExportRows=rows
    ns.ExportHideNames,ns.ExportIncludeNotes,ns.ExportExtraNames=hideNames,includeNotes,extraNames
    if kind=='reports' then ns.ReportsWindow=window;ns.ReportExportWindow=window;ns.ReportExportText=preview end
    if kind=='reports' then ns.ReportReadButton,ns.ReportShareButton=reviewTab,shareTab end
    T.ShowWindow(window);Refresh(not keep)
end
-- Freeze the batch while it is reviewed; background arrivals/deletions do not overwrite edits.
local function RefreshReportsView()
    if not window or not window:IsShown() or not batch or batch.kind~='reports' or view~='review' then return end
    batch=E.Batch('reports',batch.mode);ns.ExportBatch=batch;Refresh(true)
end
return {Open=Open,Refresh=RefreshReportsView}
end
function ns.OpenExport(kind,mode,records,requestedView)
    local key=kind=='reports' and 'reports' or 'exports'
    instances[key]=instances[key] or Instance(key=='reports')
    instances[key].Open(kind,mode,records,requestedView)
end
function ns.RefreshReportExport() end
function ns.RefreshReportsView() if instances.reports then instances.reports.Refresh() end end
function ns.OpenReportExport(mode) ns.OpenExport('reports',mode) end
function ns.OpenShieldExport() ns.OpenExport('shield') end
