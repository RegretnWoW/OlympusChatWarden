-- Relay composers and inbox views use the suite's native widgets. Outgoing
-- submission requires an explicit click; unfinished text is only saved locally.
local _,ns=...
local U={};ns.RelayUI=U
local S,P,D,V,T=ns.RelayStore,ns.RelayTransport,ns.RelayDiagnostics,ns.Art,ns.Theme
local function Label(parent,text,x,y,width,size)
    local t=V.Text(parent,text,x,y,width,size or 13,V.muted);t:SetHeight(20);return t
end
local function Stamp(at) return at and ns.SafeCall(date,'%Y-%m-%d %H:%M',at) or 'Not attempted' end
local statusNames={draft='Unfinished report',pending='Waiting to Deliver',sending='Sending',received='Delivered',failed='Needs Attention'}
local function State(r)
    if r.state=='pending' and r.autoRetry~=true then return 'Needs Attention' end
    return statusNames[r.state] or r.state
end
local function Message(r)
    if r.state=='received' then return 'Your report was delivered successfully.' end
    if r.state=='sending' then return 'Warden is sending your report.' end
    if r.state=='pending' and r.autoRetry==true then return "Warden will automatically try again while you're online." end
    return "Warden couldn't deliver your report. It is safely saved."..(r.autoRetry==false and ' Automatic delivery is paused.' or '')
end
local function Module(id) if id=='suite' then return 'CommandWarden / general' end;for _,row in ipairs(S.modules) do if row[1]==id then return row[2] end end;return id end
local function Multi(parent,x,y,w,h,limit,changed)
    local box=V.Panel(parent,x,y,w,h,'dark')
    local scroll=CreateFrame('ScrollFrame',nil,box);scroll:SetPoint('TOPLEFT',12,-10);scroll:SetSize(w-47,h-20)
    local edit=CreateFrame('EditBox',nil,scroll);edit.ChatWardenNoSpelling=true;edit.ChatWardenArtStyled=true;edit.ChatWardenRelayMulti=true
    edit:SetMultiLine(true);edit:SetAutoFocus(false);edit:SetMaxLetters(limit);edit:SetWidth(w-52);T.TextField(edit)
    edit:SetPoint('TOPLEFT');edit:SetHeight(h-20);scroll:SetScrollChild(edit);V.SkinScroll(scroll)
    local measure=edit:CreateFontString(nil,'OVERLAY');T.Body(measure);measure:SetWordWrap(true);measure:SetWidth(w-52);measure:Hide()
    edit:SetScript('OnTextChanged',function(self)
        measure:SetText(S.Safe(self:GetText() or ''));local height=math.max(h-20,(measure:GetStringHeight() or 0)+22)
        self:SetHeight(height)
        if scroll.ChatWardenUpdateScrollRange then scroll.ChatWardenUpdateScrollRange(math.max(0,height-scroll:GetHeight())) end
        changed(self:GetText() or '')
    end)
    edit:SetScript('OnCursorChanged',function(_,_,cy,_,ch)
        local pos=-cy;local offset=scroll:GetVerticalScroll() or 0
        if pos<offset then scroll:SetVerticalScroll(math.max(0,pos))
        elseif pos+(ch or 18)>offset+scroll:GetHeight() then scroll:SetVerticalScroll(math.max(0,pos+(ch or 18)-scroll:GetHeight())) end
    end)
    edit:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
    return edit
end
local function Summary(p)
    local pending,received,failed=0,0,0
    for _,r in ipairs(S.db and S.db.reports or {}) do
        if r.state=='received' then received=received+1 elseif r.state=='failed' or r.state=='pending' and r.autoRetry~=true then failed=failed+1
        elseif r.state~='draft' then pending=pending+1 end
    end
    local headings={report='Report a Bug',mine='My Reports',inbox='Developer Inbox',diagnostics='Advanced Support Tools',copy='Copy a report'}
    p.heroTitle:SetText(headings[p.mode] or 'Relay support')
    p.summary:SetText(S.blocked or (p.mode=='report' and 'Tell us what went wrong. Warden handles delivery after you submit.'
        or p.mode=='inbox' and (#(S.db and S.db.inbox or {})..' incoming reports • review labels stay local')
        or p.mode=='diagnostics' and 'Diagnostics, saved unfinished reports and developer tools. Nothing is sent here.'
        or pending..' waiting  •  '..received..' delivered  •  '..failed..' need attention'))
end
function U.Build(parent)
    local W=ns.Workspace
    local p=CreateFrame('Frame',nil,parent);p:SetAllPoints();p.mode='report';p.views={}
    local hero=V.Panel(p,0,0,1140,56,'minimal');V.Icon(hero,'relay',42,14,-7)
    p.heroTitle=V.Text(hero,'Write, review, then submit your report',72,-7,1030,18,V.gold)
    p.summary=V.Text(hero,'',73,-32,1024,12,V.blue)
    local function View(id) local f=CreateFrame('Frame',nil,p);f:SetPoint('TOPLEFT',0,-68);f:SetSize(1140,576);f:Hide();p.views[id]=f;return f end
    local c=View('report');p.composer=c
    local form=V.Panel(c,0,0,700,576,'dark');local preview=V.Panel(c,716,0,424,576,'dark')
    p.fields={module='suite',category='bug',title='',description='',steps=''}
    local function Changed()
        if p.loading then return end
        p.discardID=nil;if p.discard then p.discard:SetText('Discard unfinished text') end
        if p.draft then
            local same=true
            for _,key in ipairs({'module','category','title','description','steps'}) do if p.fields[key]~=p.draft.fields[key] then same=false;break end end
            if same then return end
            local ok,err=S.Save(p.draft.id,p.fields);if not ok then p.feedback:SetText(err);return end
        end
        p:InvalidatePreview()
        p.feedback:SetText('Your unfinished text is saved on this computer.')
    end
    Label(form,'Affected module',18,-12,312);Label(form,'Problem category',356,-12,320)
    p.module=V.Dropdown(form,18,-36,316,S.modules,function() return p.fields.module end,function(v) p.fields.module=v;Changed() end)
    p.category=V.Dropdown(form,356,-36,326,S.categories,function() return p.fields.category end,function(v) p.fields.category=v;Changed() end)
    Label(form,'Short title',18,-83,650)
    p.title=V.Edit(form,18,-106,664,34,'What went wrong?',function(v) p.fields.title=v;Changed() end);p.title:SetMaxLetters(96);p.title.ChatWardenNoSpelling=true
    Label(form,'What happened? (required)',18,-153,650)
    p.description=Multi(form,18,-178,664,148,3000,function(v) p.fields.description=v;Changed() end)
    Label(form,'Steps to reproduce (optional)',18,-338,650)
    p.steps=Multi(form,18,-363,664,108,1600,function(v) p.fields.steps=v;Changed() end)
    p.new=V.Button(form,'Start another report',18,-486,260,34,function() p:NewDraft() end,'neutral')
    p.feedback=V.Text(form,'',18,-535,660,13,V.blue);p.feedback:SetHeight(38)
    V.Text(preview,'Send to the Warden developer',18,-15,386,19,V.gold)
    p.attach=V.Check(preview,'Include Technical Details',18,-52,false,function(v)
        p.includeDiagnostics=v;p.diagnostics=v and D.Prepare() or '';p:InvalidatePreview()
    end,386)
    local explanation=Label(preview,'Include Warden version and diagnostic information to help investigate the problem.',18,-88,386,12);explanation:SetHeight(42)
    p.previewButton=V.Button(preview,'View Details',18,-140,180,28,function() p:Preview() end,'neutral')
    p.previewDoc,p.previewScroll=V.Document(preview,16,-184,390,220)
    p.sendReason=V.Text(preview,'',18,-424,386,12,V.blue);p.sendReason:SetHeight(26)
    p.send=V.Button(preview,'Submit Report',18,-456,388,36,function() p:Submit() end,'button')
    p.recipient=Label(preview,'',18,-506,386,12);p.recipient:SetHeight(64)
    function p:InvalidatePreview()
        self.previewWire=nil
        local ready=self.draft and S.Encode(S.Payload(self.draft,self.includeDiagnostics and self.diagnostics or ''))~=nil
        self.send:SetEnabled(ready and not S.blocked)
        self.sendReason:SetText(ready and 'Ready to submit.' or 'Enter a title and describe what happened.')
        self.previewDoc:SetBlocks({{kind='heading',text='We handle delivery'},
            {kind='body',text="After you submit, Warden saves your report and automatically tries to deliver it while you're online. You can close this window."},
            {kind='body',text='Technical details are optional. Chat logs, adventure history, player dossiers and private notes are excluded.'}})
    end
    function p:SetDraft(r)
        self.includeDiagnostics=false;self.diagnostics='';self.attach:SetChecked(false)
        self.loading=true;self.draft=r;self.fields={}
        for k,v in pairs(r.fields) do self.fields[k]=v end
        self.title:SetText(r.fields.title);self.description:SetText(r.fields.description);self.steps:SetText(r.fields.steps)
        self.module:Refresh();self.category:Refresh();self.loading=false;self:InvalidatePreview()
        self.recipient:SetText(r.selfTestReceiver and ('Developer self-test to '..S.Safe(P.LocalName())..'. Nothing sends until Submit Report.')
            or 'Your report and character name are shared with the Warden developer.')
        self.feedback:SetText('Your unfinished text stays on this computer.');self:SetView('report')
    end
    function p:NewDraft()
        for n=#(S.db and S.db.reports or {}),1,-1 do
            local r=S.db.reports[n];local f=r.fields
            if r.state=='draft' and not r.selfTestReceiver and f.title=='' and f.description=='' and f.steps=='' then self:SetDraft(r);return end
        end
        local r,err=S.New();if r then self:SetDraft(r) else self.feedback:SetText(err or 'Relay is unavailable.') end
    end
    function p:NewSelfTest() if ns.WardenSimLab then ns.WardenSimLab.Open('signals') end end
    function p:Preview()
        if not self.draft then return end
        local ok,err=S.Save(self.draft.id,self.fields);if not ok then self.feedback:SetText(err);return end
        local wire,reason=S.Encode(S.Payload(self.draft,self.includeDiagnostics and self.diagnostics or ''))
        self.previewWire=wire
        local f=self.draft.fields
        self.previewDoc:SetBlocks({{kind='heading',text='Report details'},
            {kind='body',text=f.title,literal=true},{kind='body',text=Module(f.module)..' • '..f.category},
            {kind='body',text=f.description,literal=true},{kind='body',text=f.steps~='' and f.steps or 'No reproduction steps included.',literal=true},
            {kind='heading',text='Technical Details'},
            {kind='body',text=self.includeDiagnostics and self.diagnostics or 'Not included.',literal=true},
            {kind='meta',text='Version: '..ns.VERSION..'\nReport ID: '..self.draft.id..'\nReport created: '..Stamp(self.draft.created)..' ('..tostring(self.draft.created)..')\nYour character name accompanies delivery.'}})
        if reason then self.feedback:SetText(reason) end
    end
    function p:Submit()
        if not self.draft then return end
        local ok,err=S.Save(self.draft.id,self.fields)
        if ok then ok,err=S.Submit(self.draft.id,self.includeDiagnostics and self.diagnostics or '') end
        if not ok then self.feedback:SetText(err or 'Please check your report.');return end
        self.lastReport=self.draft.id;self.mine.selected=S.Find(self.lastReport);self.mine.revision=nil
        self.draft=nil;self.previewWire=nil;self:SetView('mine')
        self.mine.hint:SetText('Report saved. Warden is handling delivery; you can close this window.')
    end
    local function Manager(id,inbox)
        local f=View(id);f.query='';f.status='all';f.module='all';f.version=''
        local function Disarm() f.deleteKey=nil;if f.delete then f.delete:SetText('Delete report') end end
        local function Dirty() Disarm();f.revision=nil;f:Refresh() end
        f.search=V.Edit(f,0,0,420,34,'Search reports...',function(v) f.query=v:lower();Dirty() end)
        local modules={{'all','All modules'}};for _,s in ipairs(S.modules) do modules[#modules+1]=s end
        f.moduleDrop=V.Dropdown(f,434,0,230,modules,function() return f.module end,function(v) f.module=v;Dirty() end)
        local states=inbox and {{'all','All statuses'},{'New','New'},{'Reviewing','Reviewing'},{'Confirmed','Confirmed'},{'Fixed','Fixed'},{'Closed','Closed'}}
            or {{'all','All statuses'},{'pending','Waiting to Deliver'},{'sending','Sending'},{'received','Delivered'},{'attention','Needs Attention'}}
        f.statusDrop=V.Dropdown(f,678,0,220,states,function() return f.status end,function(v) f.status=v;Dirty() end)
        f.versionEdit=V.Edit(f,912,0,228,34,'Version filter...',function(v) f.version=v:lower();Dirty() end)
        local left=V.Panel(f,0,-50,366,420,'dark');local right=V.Panel(f,382,-50,758,420,'dark')
        f.document=V.Document(right,14,-16,728,386)
        f.document:SetBlocks({{kind='title',text=inbox and 'No reports selected' or 'Your reports'},
            {kind='body',text=inbox and 'Incoming reports appear here after native delivery. Review labels are local and send no reply.' or 'Choose a report to read it. Choose Report a Bug to submit a new report. Unfinished text is available under Advanced Tools.'}})
        local function Select(r)
            if f.selected~=r then Disarm();f.advanced=false end
            f.selected=r;local data=r.wire and S.Decode(r.wire) or r.fields;local created=r.created or data and tonumber(data.created)
            local blocks={{kind='title',text=data.title~='' and data.title or 'Untitled report',literal=true},
                {kind='meta',text=State(r)..' • '..Module(data.module)..' • '..Stamp(r.submitted or created)},
                {kind='body',text=inbox and ('From '..S.Safe(r.sender)..' • received '..Stamp(r.received or r.receivedAt)..'\nReview status is local; no reply is sent.') or Message(r)},
                {kind='heading',text='What happened'}, {kind='body',text=data.description,literal=true},
                {kind='heading',text='How to reproduce'}, {kind='body',text=data.steps~='' and data.steps or 'No steps supplied.',literal=true},
                {kind='heading',text='Submitted'}, {kind='body',text=Stamp(r.submitted or created)},
                {kind='heading',text='Technical Details'}, {kind='body',text=data.diagnostics and data.diagnostics~='' and 'Included. Open Advanced Details to read it.' or 'Not included.'}}
            if f.advanced or inbox then
                blocks[#blocks+1]={kind='heading',text='Advanced Details'}
                blocks[#blocks+1]={kind='body',text='Report ID: '..(r.id or r.key or '')..'\nVersion: '..(data.version or ns.VERSION)..'\n'..(r.status or '')..'\nCreated: '..Stamp(created)..'\nLast attempt: '..Stamp(r.lastAttempt)..'\nDelivered: '..Stamp(r.received or r.receivedAt)..'\nNext retry: '..Stamp(r.nextAttempt)..'\nAttempts: '..tostring(r.attempts or 0)..'\n'..(data.diagnostics or ''),literal=true}
            end
            f.document:SetBlocks(blocks)
            if f.automatic then f.automatic:SetText(r.autoRetry==true and 'Pause delivery' or 'Enable auto delivery');f.automatic:SetEnabled(r.state=='pending' or r.state=='sending') end
            if f.retry then f.retry:SetEnabled(r.state=='pending' or r.state=='failed') end
            if f.edit then f.edit:SetText('Use as new report') end
            if f.continue then f.continue:SetShown(false) end
            if f.retry then f.retry:SetShown(f.advanced and (r.state=='pending' or r.state=='failed')) end
            if f.automatic then f.automatic:SetShown(f.advanced and (r.state=='pending' or r.state=='sending')) end
            if f.delete then f.delete:SetShown(inbox or f.advanced) end
            if f.edit then f.edit:SetShown(f.advanced) end
            if f.copy then f.copy:Show() end
            if f.advancedButton then f.advancedButton:SetEnabled(true) end
            local x=f.reviewState and 240 or 0;for _,b in ipairs(f.actions or {}) do if b~=f.delete and b:IsShown() then b:ClearAllPoints();b:SetPoint('TOPLEFT',x,-484);x=x+b:GetWidth()+10 end end
            if f.delete then f.delete:ClearAllPoints();f.delete:SetPoint('TOPLEFT',970,-484) end
            if f.list then f.list:Render() end
        end
        f.list=V.ScrollingList(left,10,-12,320,394,74,function(parent)
            local row=V.Button(parent,'',0,0,320,68,function(self) Select(self.report) end,'row')
            row.SelectedArt=V.Nine(row,'selected')
            row.icon=V.Icon(row,'event:messages',32,10,-16)
            row.title=V.Text(row,'',50,-10,254,14,V.gold);row.title:SetHeight(22);row.title:SetWordWrap(false)
            row.status=V.Text(row,'',50,-31,254,12,V.muted);row.status:SetHeight(17);row.status:SetWordWrap(false)
            row.date=V.Text(row,'',50,-49,254,11,V.muted);row.date:SetHeight(15);row.date:SetWordWrap(false);return row
        end,function(row,r)
            row.report=r;V.SetIcon(row.icon,ns.EventIcons.Relay(r));local fields=r.wire and S.Decode(r.wire) or r.fields
            row.SelectedArt:SetShown(f.selected==r)
            row.title:SetText(S.Safe(fields and fields.title~='' and fields.title or 'Untitled report'))
            row.status:SetText(State(r)..' • '..Module(fields.module))
            row.date:SetText(S.Safe(inbox and r.sender or Stamp(r.submitted or r.created)))
        end)
        f.hint=V.Text(f,'',0,-537,1140,12,V.blue);f.hint:SetHeight(40)
        local function Selected(keepDelete) if not keepDelete then Disarm() end;if not f.selected then f.hint:SetText('Choose a report first.');return end;return f.selected end
        local x=0
        f.actions={}
        local function Button(label,width,fn,kind) local b=V.Button(f,label,x,-484,width,34,fn,kind);x=x+width+10;f.actions[#f.actions+1]=b;return b end
        if not inbox then
            f.edit=Button('Use as new report',180,function() local r=Selected();if not r then return end
                if r.state=='draft' then p:SetDraft(r) else local copy,err=S.Copy(r.id);if copy then p:SetDraft(copy) else f.hint:SetText(err) end end
            end,'button')
            f.continue=Button('Continue editing',165,function() local r=Selected();if r and r.state=='draft' then p:SetDraft(r) end end,'neutral')
            f.retry=Button('Retry Now',125,function() local r=Selected();if r then local ok,err=P.Try(r.id);Dirty();f.hint:SetText(ok and 'Warden is sending your report.' or err) end end);f.retry:SetEnabled(false)
            f.automatic=Button('Resume delivery',170,function() local r=Selected();if r then local ok,err=P.SetAutomatic(r.id,r.autoRetry~=true);Dirty();if not ok then f.hint:SetText(err) end end end,'neutral');f.automatic:SetEnabled(false)
        else
            f.reviewState=V.Dropdown(f,0,-484,225,{{'New','Mark New'},{'Reviewing','Mark Reviewing'},{'Confirmed','Mark Confirmed'},{'Fixed','Mark Fixed'},{'Closed','Mark Closed'}},function() return f.selected and f.selected.state or 'New' end,function(v) local r=Selected();if r then S.SetInboxState(r.key,v);Dirty() end end);x=240
        end
        f.copy=Button('Copy report',130,function() local r=Selected();if r then p:CopyReport(r,inbox) end end,'neutral')
        f.delete=Button('Delete report',170,function()
            local r=Selected(true);if not r then return end
            local key=inbox and r.key or r.id
            if f.deleteKey~=key then f.deleteKey=key;f.delete:SetText('Confirm delete');f.hint:SetText('Delete this local report? Copy it or save a complete-file backup first. Click Confirm delete again.');return end
            local ok,err=S.Delete(key,inbox);f.deleteKey=nil;f.delete:SetText('Delete report')
            if ok then f.selected=nil;f.document:SetBlocks({{kind='body',text='Local report deleted. External copies and complete-file backups are separate.'}});Dirty() else f.hint:SetText(err or 'Unable to delete.') end
        end,'danger')
        f.advancedButton=Button('Advanced Details',145,function() local r=Selected();if r then f.advanced=not f.advanced;Select(r) end end,'neutral')
        f.advancedButton:SetEnabled(false)
        if not inbox then for _,b in ipairs({f.edit,f.continue,f.retry,f.automatic,f.delete}) do b:Hide() end end
        f:HookScript('OnHide',Disarm)
        function f:Refresh()
            -- A freshly loaded store has no mutation revision yet. nil==nil
            -- must not suppress the first population after login.
            local revision=S.revision or 0
            if self.revision==revision and self.store==S.db then return end
            self.revision=revision;self.store=S.db
            if inbox and not P.IsDeveloper() then self.list:SetItems({});self.document:SetBlocks({{kind='body',text='Developer Inbox requires the private Hephaestus companion with local test mode enabled.'}});return end
            local rows={};local list=S.db and (inbox and S.db.inbox or S.db.reports) or {}
            for n=#list,1,-1 do
                local r=list[n];local data=r.wire and S.Decode(r.wire) or r.fields
                local hay=data and (data.title..' '..data.description..' '..(r.sender or '')..' '..(r.id or r.key)):lower() or ''
                local statusMatch=self.status=='all' or self.status==r.state and (inbox or self.status~='pending' or r.autoRetry==true)
                    or not inbox and self.status=='attention' and (r.state=='failed' or r.state=='pending' and r.autoRetry~=true)
                if data and (inbox or r.state~='draft') and (self.query=='' or hay:find(self.query,1,true)) and statusMatch
                    and (self.module=='all' or self.module==data.module) and (self.version=='' or (data.version or ns.VERSION):lower():find(self.version,1,true)) then rows[#rows+1]=r end
            end
            local present=false;for _,r in ipairs(rows) do if r==self.selected then present=true;break end end
            if not present then
                self.selected=nil;self.advanced=false;Disarm()
                self.advancedButton:SetEnabled(false)
                for _,b in ipairs(self.actions or {}) do if b~=self.advancedButton then b:SetShown(false) end end
                self.document:SetBlocks({{kind='title',text=#rows>0 and 'Select a report' or 'No reports to show'},
                    {kind='body',text=inbox and 'Received reports appear here.' or 'Submitted reports appear here. Choose Report a Bug to get started.'}})
            end
            self.list:SetItems(rows,true);self.hint:SetText(#rows..' reports. Warden handles delivery of submitted reports while you are online.')
            if self.selected then Select(self.selected) end
            if self.reviewState then self.reviewState:Refresh() end
        end
        return f
    end
    p.mine=Manager('mine',false);p.inbox=Manager('inbox',true)
    local copy=View('copy')
    V.Text(copy,'Copy Report',16,-12,1100,23,V.gold)
    Label(copy,'Select the complete text and press Ctrl+C. Review identifying details before sharing. Copying sends nothing.',16,-53,1100)
    p.export=Multi(copy,0,-96,1140,414,12000,function(v)
        if p.exportOriginal and v~=p.exportOriginal then p.export:SetText(p.exportOriginal) end
    end)
    V.Button(copy,'Select all text',0,-530,230,34,function() p.export:SetFocus();p.export:HighlightText() end,'neutral')
    V.Button(copy,'Back to reports',902,-530,238,34,function() p:SetView(p.exportBack or 'mine') end,'neutral')
    function p:CopyReport(r,inbox)
        self.exportBack=inbox and 'inbox' or 'mine';self.exportOriginal=S.Export(r,inbox);self.export:SetText(self.exportOriginal);self.export:ClearFocus();self:SetView('copy')
    end
    local diagnostic=View('diagnostics')
    local panel=V.Panel(diagnostic,0,0,1140,452,'dark');p.healthDoc=V.Document(panel,18,-18,1104,414)
    function p:Health()
        local count=0;for _,id in ipairs(ns.Modules.order) do if ns.Modules.Enabled(id) then count=count+1 end end
        local blocks={{kind='title',text='Health summary'},
            {kind='body',text='Warden '..ns.VERSION..' • '..count..' optional modules running\nInitialization: '..(#(ns.StartupErrors or {})==0 and 'Ready' or 'Needs attention')..'\nArchive: '..(ns.ChronicleStore.loading and 'Validating saved history' or ns.ChronicleStore.db and 'Available' or 'Not loaded')..'\nOlympus: '..ns.OlympusConnection.StatusText()..'\nDelivery: '..(P.Busy() and 'Transfer in progress; awaiting receipt' or 'No active transfer; receiver availability unknown')},
            {kind='meta',text='Opening this page enables no profiling and sends nothing. Olympus access does not prove that a developer receiver is online.'},
            {kind='heading',text='Last native send'},
            {kind='body',text=P.DeliveryDetail()},
            {kind='body',text='Local receiver check: '..(P.IsDeveloper() and 'Developer Inbox available' or 'Standard reporting character')..'\nNative full identity: '..S.Safe(P.LocalIdentity() or 'Not available')..'\nThis local identity check is not part of the optional diagnostics attachment.'},
            {kind='heading',text='Capture limitations'},
            {kind='body',text='Only Warden Lua file names, line numbers and occurrence counts are retained from errors passed through the installed error handler. Original error messages, stacks, locals, player names and history are excluded. An error before Relay loads, or handled by another logger, may not be available. Paste useful details into your own description if needed.'}}
        local athena=ns.Athena.GetHealth('relay')
        if athena then blocks[#blocks+1]={kind='heading',text='Athena shared services'};blocks[#blocks+1]={kind='body',text=tostring(athena.operationalDecisions or 'Unknown')..' auditable operational decisions • '..tostring(athena.operationalActions or 'Unknown')..' action references • '..athena.errors..' service errors. Local only; no intelligence network.'} end
        if self.advancedHealth then blocks[#blocks+1]={kind='heading',text='Advanced diagnostics'};blocks[#blocks+1]={kind='body',text=D.Snapshot()} end
        self.healthDoc:SetBlocks(blocks)
        if self.selfTest then self.selfTest:SetShown(P.IsDeveloper()) end
    end
    V.Button(diagnostic,'Advanced details',0,-524,240,34,function() p.advancedHealth=not p.advancedHealth;p:Health() end,'neutral')
    V.Button(diagnostic,'Include Technical Details',256,-524,250,34,function()
        if not p.draft then p:NewDraft() else p:SetView('report') end
        p.includeDiagnostics=true;p.diagnostics=D.Prepare();p.attach:SetChecked(true);p:InvalidatePreview()
    end)
    V.Button(diagnostic,'Collection status',572,-524,230,34,function() local page=W.Destination('recording');if page then page:SetView('coverage') end end,'neutral')

    p.recoveryChoices={{false,'Recover unfinished report…'}}
    p.recovery=V.Dropdown(diagnostic,0,-470,760,p.recoveryChoices,function() return false end,function(id)
        local r=id and S.Find(id);if r and r.state=='draft' then p:SetDraft(r) end
    end,{maxRows=8})
    p.discard=V.Button(diagnostic,'Discard unfinished text',774,-470,344,32,function()
        local r=p.draft;if not r or r.state~='draft' then return end
        if p.discardID~=r.id then p.discardID=r.id;p.discard:SetText('Confirm discard of current form');return end
        local ok,err=S.Delete(r.id,false)
        if ok then p.draft=nil;p:SetView('report') else p.feedback:SetText(err or 'Unable to discard this text.') end
    end,'neutral')

    function p:SetView(mode)
        self.discardID=nil;if self.discard then self.discard:SetText('Discard unfinished text') end
        if mode=='lab' then if ns.WardenSimLab then ns.WardenSimLab.Open('diagnostics') end;mode='diagnostics' end
        mode=self.views[mode] and mode or 'report'
        if mode=='inbox' and not P.IsDeveloper() then mode='report' end
        self.mode=mode
        local tabs={{'report','Report a Bug',function() p:SetView('report') end,220},{'mine','My Reports',function() p:SetView('mine') end,220},{'diagnostics','Advanced Tools',function() p:SetView('diagnostics') end,220}}
        if P.IsDeveloper() then
            tabs[#tabs+1]={'inbox','Developer Inbox',function() p:SetView('inbox') end,220}

        end
        W.Tabs(tabs,mode=='copy' and (self.exportBack or 'mine') or mode)
        for k,view in pairs(self.views) do view:SetShown(k==mode) end
        if mode=='report' and not self.draft and S.db then
            local draft;for _,r in ipairs(S.db.reports) do if r.state=='draft' then draft=r end end
            if draft then self:SetDraft(draft);return else self:NewDraft();return end
        end
        if mode=='diagnostics' then
            for i=#self.recoveryChoices,2,-1 do self.recoveryChoices[i]=nil end
            for _,r in ipairs(S.db and S.db.reports or {}) do if r.state=='draft' and (r.fields.title~='' or r.fields.description~='') then self.recoveryChoices[#self.recoveryChoices+1]={r.id,(r.fields.title~='' and r.fields.title or 'Untitled report')..' • '..Stamp(r.updated or r.created)} end end
            self.recovery:Refresh();self:Health()
        end
        if mode=='mine' then self.mine:Refresh() elseif mode=='inbox' then self.inbox:Refresh() end
        Summary(self)
    end
    function p:Activate() self:SetView(self.mode) end
    function p:Refresh()
        Summary(self)
        if self.mode=='inbox' and not P.IsDeveloper() then self:SetView('report');return end
        if self.mode=='mine' then self.mine:Refresh() elseif self.mode=='inbox' then self.inbox:Refresh() end
    end
    p:SetScript('OnHide',function()
        for _,box in ipairs({p.title,p.description,p.steps,p.mine.search,p.inbox.search,p.mine.versionEdit,p.inbox.versionEdit,p.export}) do box:ClearFocus() end
    end)
    return p
end
