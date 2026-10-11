local _,ns=...
local T,E=ns.Theme,ns.Export
local window,batch,rows,preview,scroll,count,pager,previous,nextPage,hideNames,includeNotes,extraNames,scope,scopeText
local page=1
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
local function Refresh()
    if not window or not batch then return end
    local json,n=E.Build(batch);preview:SetText(json);preview:SetCursorPosition(0);preview:ClearFocus();scroll:SetVerticalScroll(0)
    count:SetText(n..' / '..#batch.items..' entries included. Click a row to include or leave it out.')
    local pages=math.max(1,math.ceil(#batch.items/9));page=math.min(page,pages)
    pager:SetText('Page '..page..' / '..pages);previous:SetEnabled(page>1);nextPage:SetEnabled(page<pages)
    for i,row in ipairs(rows) do
        local index=(page-1)*9+i;local item=batch.items[index];row.index=index;row:SetShown(item~=nil)
        if item then
            row.label:SetText((batch.selected[index]==false and '[  ]  ' or '[x]  ')..Plain(ns.Reports.Clip(E.Label(item),72)))
            row.detail:SetText(Plain(ns.Reports.Clip(item.note or item.reason or item.event or item.expectedAction or '',72)))
            T.RowState(row,batch.selected[index]~=false,'Unchanged')
        end
    end
    hideNames:SetChecked(batch.hideNames);includeNotes:SetChecked(batch.includeNotes)
end
function ns.OpenExport(kind,mode,records)
    if not window then
        window=T.Window('OlympusChatWardenExport',UIParent,940,678);ns.ExportWindow=window
        T.Title(window,ns.NAME);T.Crest(window)
        T.Gold(Text(window,78,-30,720,'Choose what to share'))
        T.Muted(Text(window,78,-49,820,'Local preview. Nothing is sent for you. Changing a selection or privacy option rebuilds the text.'))
        scope=T.Dropdown(window,14,-74,240,{{'all','All saved reports'},{'misses','Missed messages only'}},
            function() return batch and batch.mode or 'all' end,function(v) ns.OpenReportExport(v) end)
        scopeText=T.Gold(Text(window,266,-82,654))
        local toolbar=T.Panel(window,14,-108,912,44)
        Button(toolbar,'Include all',116,10,-10,function() batch.selected={};Refresh() end,'Include every entry in this export snapshot.')
        Button(toolbar,'Include none',116,136,-10,function()
            for i=1,#batch.items do batch.selected[i]=false end;Refresh()
        end,'Leave all entries out, then click just the ones you want.')
        count=Text(toolbar,266,-16,636)
        local list=T.Panel(window,14,-160,350,444);rows={}
        T.Gold(Text(list,12,-12,326,'Entries to export'))
        for i=1,9 do
            local row=CreateFrame('Button',nil,list);rows[i]=row;row:SetSize(332,42);row:SetPoint('TOPLEFT',9,-34-(i-1)*44)
            row.background=row:CreateTexture(nil,'BACKGROUND');row.background:SetAllPoints()
            row.label=Text(row,12,-6,308);row.label:SetWordWrap(false)
            row.detail=T.Muted(Text(row,12,-23,308));row.detail:SetWordWrap(false);T.SkinRow(row)
            row:SetScript('OnClick',function(self) batch.selected[self.index]=batch.selected[self.index]==false;Refresh() end)
            T.Tooltip(row,'Include this entry','Click to include or leave out this entry. This only changes your export, not your saved records.')
        end
        local privacy=T.Panel(window,376,-160,550,138)
        T.Gold(Text(privacy,12,-12,526,'Privacy options'))
        local function Check(label,y,fn,help)
            local c=CreateFrame('CheckButton',nil,privacy,'UICheckButtonTemplate');c:SetSize(26,26);c:SetPoint('TOPLEFT',8,y)
            Text(c,30,-6,490,label);c:SetScript('OnClick',fn);T.Tooltip(c,label,help);return c
        end
        hideNames=Check('Hide known player names',-30,function(self) batch.hideNames=ns.Checked(self:GetChecked());Refresh() end,
            'Replace names ChatWarden knows with [player], including names inside message text and player links. Check for other identifying details yourself.')
        includeNotes=Check('Include notes / Shield reasons',-58,function(self) batch.includeNotes=ns.Checked(self:GetChecked());Refresh() end,
            'Notes and Shield reasons start left out. Rule-match details in filter reports stay included.')
        Text(privacy,12,-91,526,'Other names to hide (separate with commas):')
        extraNames=CreateFrame('EditBox',nil,privacy,'InputBoxTemplate');extraNames:SetSize(508,24);extraNames:SetPoint('TOPLEFT',20,-108)
        extraNames:SetAutoFocus(false);extraNames:SetMaxLetters(1000);T.TextField(extraNames)
        extraNames:SetScript('OnTextChanged',function(self,user) if user then batch.extraNames=self:GetText() or '';Refresh() end end)
        extraNames:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
        T.Tooltip(extraNames,'Other names to hide','Add names from pasted reports that ChatWarden does not know. Turn on Hide known player names to apply them.')
        local paper=T.Panel(window,376,-306,550,298,true)
        T.Heading(Text(paper,14,-12,520,'Final text — you can edit this before copying',true))
        scroll=CreateFrame('ScrollFrame',nil,paper,'UIPanelScrollFrameTemplate');scroll:SetPoint('TOPLEFT',14,-36);scroll:SetSize(502,246)
        preview=CreateFrame('EditBox',nil,scroll);preview:SetMultiLine(true);preview:SetAutoFocus(false);T.Body(preview)
        preview:SetMaxLetters(67108864);preview:SetSize(502,246);scroll:SetScrollChild(preview);T.Ink(preview);T.TextField(preview,scroll)
        preview:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
        previous=Button(window,'Previous',94,14,-615,function() page=math.max(1,page-1);Refresh() end)
        pager=Text(window,121,-621,145)
        nextPage=Button(window,'Next',94,270,-615,function() page=page+1;Refresh() end)
        Button(window,'Select all text',145,376,-615,function() preview:SetFocus();preview:HighlightText() end,'Select the final text, then press Ctrl+C to copy it.')
        Button(window,'Reset preview',185,531,-615,Refresh,'Rebuild the export using your choices. This discards edits made in the final text box.')
        Button(window,'Feedback',86,726,-615,function() ns.OpenReportLink() end,'Open the GitHub feedback link. For moderator reports, use your own reporting channel.')
        Button(window,'Close',100,826,-615,function() window:Hide() end)
        T.Muted(Text(window,18,-653,900,'Check the final text, then Select all text and Ctrl+C. Hidden names are a convenience; other identifying details may remain.'))
        window:SetScript('OnHide',function() preview:ClearFocus();extraNames:ClearFocus() end)
    end
    batch=E.Batch(kind,mode,records);page=1;extraNames:SetText('');extraNames:ClearFocus()
    batch.mode=mode=='misses' and 'misses' or 'all';scope:SetShown(kind=='reports');scope:Refresh()
    scopeText:SetText(({reports='Filter feedback',shield='Current shielded players',capture='Captured chat',bookmarks='Saved incident bookmarks'})[kind] or kind)
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    if w and h and w>30 and h>30 then window:SetScale(math.min(1,(w-30)/940,(h-30)/678)) end
    ns.ExportBatch=batch;ns.ExportText=preview;ns.ExportRows=rows
    ns.ExportHideNames,ns.ExportIncludeNotes,ns.ExportExtraNames=hideNames,includeNotes,extraNames
    if kind=='reports' then ns.ReportExportWindow=window;ns.ReportExportText=preview end
    T.ShowWindow(window);Refresh()
end
-- Freeze the batch while it is reviewed; background arrivals/deletions do not overwrite edits.
function ns.RefreshReportExport() end
function ns.OpenReportExport(mode) ns.OpenExport('reports',mode) end
function ns.OpenShieldExport() ns.OpenExport('shield') end
