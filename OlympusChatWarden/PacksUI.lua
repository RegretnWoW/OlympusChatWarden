local _, ns = ...
local T,P=ns.Theme,ns.RulePacks
local window,mode,selected,rows,detail,paste,scroll,status,verify,install,enable,remove,sensitivity,stockNote
local preview,deleteArmed,editing=nil,nil,false
local lastPaste,wasRestoring
local importDraft,exportText='',''
local detailMeasure,previewMeasure
local choices={{'default','Default (main preset)'},{'off','Off'},{'strict','Mild'},{'balanced','Balanced'},{'aggressive','Strict'}}
local function Text(parent,value,x,y,width,paper)
    local f=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
    f:SetPoint('TOPLEFT',x,y); f:SetWidth(width); f:SetJustifyH('LEFT'); f:SetText(value or '')
    if paper then T.Ink(f) else T.Light(f) end
    return f
end
local function Button(parent,value,x,y,width,fn)
    local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
    b:SetSize(width,26); b:SetPoint('TOPLEFT',x,y); b:SetText(value); b:SetScript('OnClick',fn); T.ActionHelp(b,value); return b
end
local function Current()
    for _,row in ipairs(P.List()) do if row.id==selected then return row end end
end
local function Edit(text)
    editing=true; paste:SetText(text or ''); lastPaste=paste:GetText(); paste:SetCursorPosition(0); paste:ClearFocus(); editing=false
    scroll:SetVerticalScroll(0)
end
local function Mode(value)
    if paste and mode=='import' then importDraft=paste:GetText() or '' end
    local changed=mode~=value
    mode=value; deleteArmed=nil; ns.SyncPacks()
    if changed and paste then
        if value=='import' then Edit(importDraft); paste:SetFocus()
        elseif value=='export' then Edit(exportText) end
        ns.SyncPacks()
    end
end
local function PreviewText(m)
    return 'SIGNATURE VERIFIED\n\n'..m.title..'\nPublisher: '..m.author..'\nVersion: '..m.version
        ..(m.update and (' (updates '..m.previousVersion..')') or ' (new pack)')
        ..'\n\n'..m.description..'\n\n'..m.rules..' selected phrase/topic entries, '..m.gommage..' Gommage terms, '..m.replacements..' replacements.'
        ..'\nChanges: '..m.added..' added, '..m.removed..' removed, '..m.changed..' changed.'
        ..'\n\nInstalling keeps your personal rules and reports. Choose whether to enable this pack below; a new pack starts off.'
end
function ns.SyncPackProgress()
    if not window or not status then return end
    if P.Busy or P.Restoring then
        status:SetText((P.Restoring and 'Verifying saved packs: ' or '')..P.ProgressText())
    end
end
function ns.SyncPacks()
    if not window then return end
    local importing=mode=='import'; local exporting=mode=='export'; local item=Current()
    window.InstalledPane:SetShown(not importing and not exporting)
    window.PastePane:SetShown(importing or exporting)
    window.ImportHelp:SetText(exporting and 'Copy the complete text below. Nothing is sent automatically.'
        or 'Paste one complete OCWPACK1 string from the author. Verify, review, then install. Pasting alone changes nothing.')
    verify:SetShown(importing); verify:SetEnabled(not P.Restoring)
    verify:SetText(P.Busy and 'Cancel verification' or 'Verify pack')
    install:SetShown(importing); install:SetEnabled(preview~=nil and not P.Busy and not P.Restoring)
    enable:SetShown(importing and preview~=nil)
    window.PreviewScroll:SetShown(importing and preview~=nil)
    window.Preview:SetText(preview and PreviewText(preview) or '')
    scroll:ClearAllPoints(); scroll:SetPoint('TOPLEFT',window.PastePane,'TOPLEFT',16,-44)
    scroll:SetSize(758,importing and preview and 126 or 340)
    if paste.ChatWardenFitText then paste.ChatWardenFitText() end
    local list=P.List()
    for i,row in ipairs(rows) do
        local m=list[i]; local update=m and ns.PackUpdates.For(m.id); row.item=m; row:SetShown(m~=nil)
        if m then
            row.title:SetText(m.title); row.label=row.title
            row.note:SetText(m.stock and ('Stock | '..(m.enabled and 'On' or 'Off'))
                or m.error and 'Not loaded: verification failed' or m.updateRequired and ('v'..m.version..' | Update Required')
                or ('v'..m.version..' | '..(m.enabled and 'On' or 'Off')..(update and (' | Update v'..update.version) or '')))
            T.RowState(row,m.id==selected,m.error and 'Hidden' or 'Unchanged')
        end
    end
    sensitivity:SetShown(item~=nil and not item.error)
    if item and not item.error then sensitivity:Refresh() end
    remove:SetEnabled(item~=nil and not item.stock and not P.Busy and not P.Restoring)
    remove:SetText(deleteArmed and 'Confirm remove' or 'Remove pack')
    window.Export:SetEnabled(item~=nil and not item.stock and not item.error)
    stockNote:SetShown(item~=nil and item.stock)
    if item then
        detail:SetText(item.error and ('This saved pack was not loaded.\n\n'..item.error..'\n\nRemove it, then paste a fresh author-issued copy. Personal rules and reports are kept.')
            or item.stock and (item.title..'\nVersion '..item.version..' | Included with ChatWarden\n\n'..item.rules..' selected phrase/topic entries\n'..item.gommage..' Gommage terms\n'..item.replacements..' replacements\n\nYou can turn this pack off or choose its sensitivity. Ordinary mentions stay visible; context determines the score.\n\nGommage is a separate meme toggle. These stock packs have no literal Gommage lists or replacement entries. Built-in barber/body-label replacements are separate.')
            or (item.title..'\nVersion '..item.version..' by '..item.author..'\n\n'..item.description..(item.legacyGommage and '\n\nLegacy list retired. Update this pack for Gommage masks; scored rules remain active.' or '')..'\n\n'..item.rules..' selected phrase/topic entries\n'..item.gommage..' Gommage terms\n'..item.replacements..' replacements\n\nVerified author key: '..item.keyID..'\nPayload SHA-256:\n'..item.digest))
        local update=ns.PackUpdates.For(item.id)
        if item.updateRequired then detail:SetText(detail:GetText()..'\n\nUpdate Required\nThis pack and its Gommage masks are inactive. Its signed import, saved enabled choice and sensitivity are kept. Use Get packs link, then manually import the compatible signed version.') end
        if update then detail:SetText(detail:GetText()..'\n\nUpdate available: v'..update.version..' (catalog bundled with '..ns.PackCatalog.release..').\nUse Get packs link, then paste and verify the updated pack. Your sensitivity and enabled state are kept.') end
    else detail:SetText('Select a pack to change its sensitivity, export its signed text, or remove it.\n\nOlympus and Asmongold are the two stock packs. Import other categories only if you want them.\n\nOff pauses a pack without removing it. Default follows your main preset. Personal phrase rules remain separate.') end
    if P.Busy or P.Restoring then ns.SyncPackProgress()
    elseif P.LastError then status:SetText(P.LastError)
    elseif wasRestoring then
        status:SetText(next(P.Errors) and 'Some saved packs could not be verified. Select their entries for details.' or 'Saved packs verified.')
    end
    wasRestoring=P.Restoring
    if ns.PacksStatus then ns.PacksStatus:SetText(#ns.PackNames..' installed categories'..(P.Restoring and ' | verifying saved packs' or '')..' | '..#ns.PackUpdates.List()..' updates') end
end
function ns.OpenPacks(requestedMode)
    if not ns.DB then return end
    if not window then
        mode='installed'; rows={}
        window=T.Window('OlympusChatWardenPacks',UIParent,840,680); ns.PacksWindow=window
        T.Title(window,ns.NAME); T.Crest(window)
        T.Gold(Text(window,'Rule packs',78,-30,690))
        T.Muted(Text(window,'Author-signed preferences. Import data, review it, then choose what to enable.',78,-50,732))
        Button(window,'Installed packs',18,-80,156,function() Mode('installed') end)
        Button(window,'Paste import',184,-80,156,function() Mode('import') end)
        Button(window,'Get packs link',350,-80,156,function() ns.OpenPacks('download') end)
        ns.PacksStatus=T.Muted(Text(window,'',522,-86,298))
        window.InstalledPane=CreateFrame('Frame',nil,window); window.InstalledPane:SetPoint('TOPLEFT',14,-120); window.InstalledPane:SetSize(812,462)
        local list=T.Panel(window.InstalledPane,0,0,298,462)
        local rowHeight=math.min(46,math.floor(442/#P.Order)-3)
        for i=1,#P.Order do
            local row=CreateFrame('Button',nil,list); row:SetSize(280,rowHeight); row:SetPoint('TOPLEFT',9,-10-(i-1)*(rowHeight+3))
            row.background=row:CreateTexture(nil,'BACKGROUND'); row.background:SetAllPoints()
            row.title=Text(row,'',10,-7,256); row.title:SetWordWrap(false); row.label=row.title
            row.note=T.Muted(Text(row,'',10,-27,256)); row.note:SetWordWrap(false); T.SkinRow(row)
            row:SetScript('OnClick',function(self) selected=self.item and self.item.id; deleteArmed=nil; status:SetText(''); ns.SyncPacks() end)
            rows[i]=row
        end
        local paper=T.Panel(window.InstalledPane,310,0,502,462,true)
        local detailScroll=CreateFrame('ScrollFrame',nil,paper,'UIPanelScrollFrameTemplate')
        detailScroll:SetPoint('TOPLEFT',18,-18); detailScroll:SetSize(450,304)
        detail=CreateFrame('EditBox',nil,detailScroll); detail.ChatWardenNoSpelling=true;detail:SetMultiLine(true); detail:SetAutoFocus(false)
        T.Body(detail); T.Ink(detail); detail:SetSize(418,304); detailScroll:SetScrollChild(detail)
        detailMeasure=detail:CreateFontString(nil,'OVERLAY'); T.Body(detailMeasure); detailMeasure:SetWidth(418); detailMeasure:SetWordWrap(true); detailMeasure:Hide()
        detail:SetScript('OnTextChanged',function(self,userInput)
            if userInput then ns.SyncPacks(); return end
            detailMeasure:SetText(self:GetText()); self:SetHeight(math.max(304,detailMeasure:GetStringHeight()+24))
        end)
        detail:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
        T.TextField(detail, detailScroll)
        sensitivity=T.Dropdown(paper,18,-344,464,choices,
            function() return selected and (ns.DB.disabledPacks[selected] and 'off' or ns.DB.packPresets[selected]) or 'default' end,
            function(value) if selected then ns.SetPackPreset(selected,value); ns.SyncPacks(); ns.SyncOptions() end end)
        stockNote=Text(paper,'Stock packs can be turned off. They stay installed.',18,-382,464,true)
        remove=Button(paper,'Remove pack',18,-419,172,function()
            local item=Current(); if not item or item.stock then return end
            if deleteArmed~=item.id then deleteArmed=item.id; ns.SyncPacks(); status:SetText('Click Confirm remove to remove this pack. Personal rules and reports will stay.'); return end
            local ok,err=P.Remove(item.id); if ok then selected=nil; deleteArmed=nil end
            status:SetText(ok and 'Pack removed. Personal rules and reports are kept.' or err); ns.SyncPacks()
        end)
        window.Export=Button(paper,'Export signed pack',208,-419,190,function()
            local text=P.Export(selected); if not text then return end
            preview=nil; P.CancelPreview(); exportText=text; Mode('export'); Edit(exportText); status:SetText('Copy the complete signed string. Editing it invalidates its signature.')
        end)
        window.PastePane=T.Panel(window,14,-120,812,462,true)
        window.ImportHelp=Text(window.PastePane,'',16,-14,768,true)
        scroll=CreateFrame('ScrollFrame',nil,window.PastePane,'UIPanelScrollFrameTemplate')
        paste=CreateFrame('EditBox',nil,scroll);paste.ChatWardenNoSpelling=true; paste:SetMultiLine(true); paste:SetAutoFocus(false); paste:SetMaxLetters(140000)
        T.Body(paste); T.Ink(paste); scroll:SetScrollChild(paste)
        -- Empty/short drafts fill the viewport. Padding around the editor also
        -- focuses it, without covering its caret or the native scrollbar.
        ns.PackPasteScroll=scroll
        paste:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
        T.TextField(paste, scroll)
        paste:HookScript('OnTextChanged',function(self)
            -- Layout and font changes may notify without changing the actual text.
            local text=self:GetText()
            if not editing and mode=='import' and text~=lastPaste then
                lastPaste=text; preview=nil; P.CancelPreview()
                status:SetText('Paste is ready to verify.'); ns.SyncPacks()
            end
        end)
        window.PreviewScroll=CreateFrame('ScrollFrame',nil,window.PastePane,'UIPanelScrollFrameTemplate')
        window.PreviewScroll:SetPoint('TOPLEFT',16,-188); window.PreviewScroll:SetSize(758,214)
        window.Preview=CreateFrame('EditBox',nil,window.PreviewScroll);window.Preview.ChatWardenNoSpelling=true; window.Preview:SetMultiLine(true); window.Preview:SetAutoFocus(false)
        T.Body(window.Preview); T.Ink(window.Preview); window.Preview:SetSize(726,214); window.PreviewScroll:SetScrollChild(window.Preview)
        previewMeasure=window.Preview:CreateFontString(nil,'OVERLAY'); T.Body(previewMeasure); previewMeasure:SetWidth(726); previewMeasure:SetWordWrap(true); previewMeasure:Hide()
        window.Preview:SetScript('OnTextChanged',function(self,userInput)
            if userInput then self:SetText(preview and PreviewText(preview) or ''); return end
            previewMeasure:SetText(self:GetText()); self:SetHeight(math.max(214,previewMeasure:GetStringHeight()+24))
        end)
        window.Preview:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
        T.TextField(window.Preview, window.PreviewScroll)
        verify=Button(window.PastePane,'Verify pack',16,-419,144,function()
            if P.Busy then P.CancelImport(); return end
            preview=nil; local original=paste:GetText(); paste:ClearFocus()
            local ok,err=P.BeginImport(original,function(result,errorMessage)
                if paste:GetText()~=original then P.CancelPreview(); status:SetText('Paste changed during verification. Verify the new text.'); return end
                preview=result; enable:SetChecked(result and result.enabled or false)
                status:SetText(result and 'Signature verified. Review the pack, choose enable, then click Install pack.' or errorMessage); ns.SyncPacks()
            end)
            status:SetText(ok and 'Checking signature in the background...' or err); ns.SyncPacks()
        end)
        enable=CreateFrame('CheckButton',nil,window.PastePane,'UICheckButtonTemplate'); enable:SetPoint('TOPLEFT',174,-416)
        enable.Text:SetText('Enable pack after install'); T.Ink(enable.Text)
        T.Tooltip(enable,'Start using this pack','Check this to turn the pack on after installing. Leave it unchecked to save it for later.')
        install=Button(window.PastePane,'Install pack',606,-419,188,function()
            if not preview then return end
            local ok,err=P.Commit(preview.token,ns.Checked(enable:GetChecked()))
            if ok then selected=preview.id; preview=nil; Edit(''); importDraft=''; Mode('installed') end
            status:SetText(ok and 'Pack installed. Its sensitivity is available on the right.' or err); ns.SyncPacks()
        end)
        status=T.Muted(Text(window,'',18,-597,668))
        local back=Button(window,ns.Workspace and 'Back to Packs' or 'Close',ns.Workspace and 632 or 718,-626,ns.Workspace and 192 or 106,function()
            if ns.Workspace then paste:ClearFocus();ns.Workspace.Open('packs') else window:Hide() end
        end)
        ns.PackBackButton=back
        T.Muted(Text(window,'Mild, Balanced and Strict choose actions. Gommage is a separate toggle for curated masks from enabled packs.',18,-637,686))
        window:HookScript('OnShow',ns.SyncPacks); window:HookScript('OnHide',function() paste:ClearFocus() end)
        T.Tooltip(paste,'Pack text','Paste the entire contents of one pack file here. Verify pack checks it before anything is installed.')
        T.Tooltip(sensitivity,'Pack sensitivity','Default follows your main sensitivity. Off pauses this category without removing it.')
        ns.PackPasteBox,ns.PackVerifyButton,ns.PackInstallButton,ns.PackEnableCheckbox=paste,verify,install,enable
        ns.PackRemoveButton,ns.PackSensitivityDropdown,ns.PackRows,ns.PackDetailText=remove,sensitivity,rows,detail
    end
    if requestedMode=='import' or requestedMode=='installed' then Mode(requestedMode) end
    if requestedMode=='download' then
        preview=nil;P.CancelPreview();exportText=ns.PROJECT_URL..'/tree/main/rule-packs'
        Mode('export');Edit(exportText);paste:SetFocus();paste:HighlightText()
        status:SetText('Copy this link into your browser. Open the pack you want and copy its complete raw text into Paste import.')
    end
    local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    window:SetScale(math.min(1,math.max(0.5,(width-30)/840),math.max(0.5,(height-30)/680)))
    ns.SyncPacks(); T.ShowWindow(window)
end
