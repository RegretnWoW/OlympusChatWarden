local _, ns = ...
local P = {Revision=0, Busy=false, Restoring=false, Errors={}}; ns.RulePacks=P
P.Order={'guild','creator','gender','labels','reproductive','language','institutional','slogans','broad','america'}
P.StockVersions={guild=10,creator=9}
P.StockTitles={guild='Olympus Protection',creator='King Protection'}
local loaded, pending, token, stockRules, stockMeta = {},nil,0,{},{}
local stockCaptured=false
local jobs, worker, scheduled, current = {},nil,false,nil
local restoreSerial = 0
local C,D=ns.PackCrypto,ns.PackData
function P.Compatible(model)
    if model.id=='labels' then return model.schema==3 and model.purpose=='replacement' and model.version>=7 end
    return model.schema==5 and model.policy and model.policy.contract==1
end
local function SafeCall(fn,...)
    if type(fn)~='function' then return true end
    local ok,err=pcall(fn,...)
    if not ok and type(geterrorhandler)=='function' then
        local got,handler=pcall(geterrorhandler)
        if got and type(handler)=='function' then pcall(handler,'Olympus ChatWarden: '..tostring(err)) end
    end
    return ok,err
end
local function Changed()
    -- A presentation error must not stop a queued verification or leave Busy set.
    SafeCall(ns.SyncOptions)
    SafeCall(ns.SyncPacks)
    if ns.PackUpdates then SafeCall(ns.PackUpdates.Check) end
end
local function Build(models)
    local names,rules,meta,literal,literalMeta,replacements,owners,literalOwners={},{},{},{},{},{},{},{}
    for _,phrase in ipairs(stockRules) do rules[#rules+1]=phrase; meta[phrase]=stockMeta[phrase]; owners[phrase]=stockMeta[phrase].pack end
    local bytes=0
    for _,id in ipairs(P.Order) do
        local model=models[id]
        if id=='guild' or id=='creator' or model then names[#names+1]=id end
        if model and P.Compatible(model) then
            for _,rule in ipairs(model.rules) do
                if owners[rule.phrase] and owners[rule.phrase]~=id then return nil,'A phrase conflicts with another installed pack.' end
                owners[rule.phrase]=id; bytes=bytes+#rule.phrase
                rules[#rules+1]=rule.phrase
                meta[rule.phrase]={id=id..':'..rule.phrase,pack=id,base=rule.score,origin=rule.origin,version=model.version,
                    role=rule.role,purpose=model.purpose,stance=model.stance,policy=model.schema>=3,contextual=model.schema>=4,
                    contractPolicy=model.schema==5 and model.policy or nil,
                    protectionProfile=model.schema==5 and model.purpose=='subject' and model.policy.profile or nil,
                    subjectModel=model.purpose=='subject' and model or nil}
            end
            for _,phrase in ipairs(model.gommage or {}) do
                if literalOwners[phrase] or stockMeta[phrase] then return nil,'A literal word conflicts with another installed pack.' end
                literalOwners[phrase]=id; bytes=bytes+#phrase; literal[#literal+1]=phrase
                literalMeta[phrase]={id='gommage:'..id..':'..phrase,pack=id,origin='author-signed Gommage display preference',version=model.version}
            end
            for _,rule in ipairs(model.replacements) do
                if owners[rule.phrase] and owners[rule.phrase]~=id then return nil,'A replacement conflicts with another installed pack.' end
                owners[rule.phrase]=id; bytes=bytes+#rule.phrase; replacements[rule.phrase]=rule.text
            end
            for _,rule in ipairs(model.statements or {}) do bytes=bytes+#rule.phrase end
        end
    end
    if bytes>ns.Engine.MAX_RULE_BYTES or #rules+#literal>ns.Engine.MAX_RULES then return nil,'Combined rule-pack budget exceeded.' end
    local matcher,err=ns.Engine.Compile(rules); if not matcher then return nil,err end
    local literalMatcher; literalMatcher,err=ns.Engine.CompileLiteral(literal); if not literalMatcher then return nil,err end
    local phrases={}; for phrase in pairs(replacements) do phrases[#phrases+1]=phrase end; table.sort(phrases)
    local replacementMatcher; replacementMatcher,err=ns.Engine.Compile(phrases); if not replacementMatcher then return nil,err end
    return {names=names,rules=rules,meta=meta,matcher=matcher,literal=literal,literalMeta=literalMeta,
        replacements=replacements,replacementMatcher=#phrases>0 and replacementMatcher or nil}
end
local function Apply(built)
    ns.PackNames,ns.StockRules,ns.RuleMeta,ns.Matcher=built.names,built.rules,built.meta,built.matcher
    ns.Gommage={Rules=built.literal,Meta=built.literalMeta}
    ns.BodyReplacementText,ns.BodyReplacements=built.replacements,built.replacementMatcher
    ns.DB.rules=nil -- legacy duplicated rule lists must never reactivate removed categories
    P.Revision=P.Revision+1
    local revisions={'stock-guild-10-creator-9-policy-4-packs-5-context-17-evasion-3-case-1-boundary-2-personal-2-replacement-1-gommage-3-spelling-vocab-1'}
    for _,id in ipairs(P.Order) do if loaded[id] then revisions[#revisions+1]=id..'-'..loaded[id].version end end
    ns.RULE_VERSION=table.concat(revisions,'-')
    if ns.PolicyChanged then ns.PolicyChanged() end
    Changed()
end
local function Clock()
    if type(debugprofilestop)=='function' then
        local ok,value=pcall(debugprofilestop)
        if ok and type(value)=='number' then return value/1000 end
    end
    if type(GetTimePreciseSec)=='function' then
        local ok,value=pcall(GetTimePreciseSec)
        if ok and type(value)=='number' then return value end
    end
    return GetTime and GetTime() or 0
end
local function Wall() return GetTime and GetTime() or 0 end
local function Complete(job,model,err)
    local ok=SafeCall(job.done,model,err)
    if not ok then
        pending=nil; P.Busy=false; P.Restoring=false; P.Progress=nil
        P.LastError='Pack processing failed. Reopen Rule packs and try again.'
        jobs={}; Changed()
    end
end
local Step
local function Schedule()
    if scheduled or not jobs[1] then return true end
    scheduled=true
    -- Native timers do not depend on a worker frame's visibility or UI layering.
    if C_Timer and type(C_Timer.After)=='function' then
        local ok=pcall(C_Timer.After,0,Step)
        if ok then
            if worker then worker:SetScript('OnUpdate',nil); worker:Hide() end
            return true
        end
    end
    local ok=pcall(function()
        if not worker then worker=CreateFrame('Frame') end
        worker:SetScript('OnUpdate',Step); worker:Show()
    end)
    if not ok then scheduled=false; return false end
    return true
end
Step=function()
    scheduled=false
    local start=Clock(); local steps=0
    while jobs[1] and steps<12 and (steps==0 or Clock()-start<0.002) do
        steps=steps+1; local job=jobs[1]
        -- Loading screens can defer timers: start the deadline on the first slice.
        if not job.started then job.started=Wall(); job.notified=job.started end
        if Wall()-job.started>=60 then
            table.remove(jobs,1)
            Complete(job,nil,'Verification timed out. Try again; no pack was installed.')
        else
            current=job
            local ok,result,err=coroutine.resume(job.co)
            current=nil; job.checkpoints=job.checkpoints+1
            P.Progress={stage=job.stage,checkpoints=job.checkpoints,elapsed=math.max(0,Wall()-job.started)}
            if not ok or coroutine.status(job.co)=='dead' then
                table.remove(jobs,1)
                Complete(job,ok and result or nil,not ok and 'Pack verification could not complete.' or err)
            elseif Wall()-job.notified>=0.2 then
                job.notified=Wall(); SafeCall(ns.SyncPackProgress)
            end
        end
    end
    if not jobs[1] then
        if worker then worker:Hide() end
    elseif not Schedule() then
        local stalled=jobs; jobs={}
        for _,job in ipairs(stalled) do Complete(job,nil,'Verification could not be scheduled. Reload and try again.') end
    end
end
local function Enqueue(fn,done)
    if type(coroutine)~='table' or type(coroutine.create)~='function'
        or type(coroutine.resume)~='function' or type(coroutine.status)~='function' then
        return false,'Pack verification is unavailable in this client. No pack was installed.'
    end
    local ok,co=pcall(coroutine.create,fn)
    if not ok then return false,'Pack verification could not start. No pack was installed.' end
    local now=Wall()
    local job={co=co,done=done,notified=now,checkpoints=0,stage='Starting verification'}
    jobs[#jobs+1]=job
    if #jobs==1 then P.Progress={stage=job.stage,checkpoints=0,elapsed=0} end
    if not Schedule() then table.remove(jobs); return false,'Verification could not be scheduled. Reload and try again.' end
    return true
end
local function Stage(value) if current then current.stage=value end end
local function Yield() coroutine.yield() end
local function Verify(text)
    Stage('Checking pack format')
    if type(text)~='string' or #text>140000 then return nil,'Paste one pack of at most 140,000 characters.' end
    text=text:gsub('[ \t\r\n]','')
    local kid,encoded,signature=text:match('^OCWPACK1:([0-9a-f]+):([A-Za-z0-9+/=]+):([A-Za-z0-9+/=]+)$')
    if not kid or #kid~=16 or not ns.TrustedPackKeys[kid] then return nil,'Unsupported format or unapproved signing key.' end
    Stage('Decoding pack')
    local data=C.Base64Decode(encoded,D.LIMIT,Yield); signature=C.Base64Decode(signature,256,Yield)
    if not data or not signature or #signature~=256 then return nil,'Invalid pack encoding or size.' end
    Stage('Checking author signature')
    if not C.Verify('OlympusChatWarden.RulePack.v1\0'..kid..'\0'..data,signature,ns.TrustedPackKeys[kid],Yield) then
        return nil,'Signature check failed. Use the complete original pack from the author.'
    end
    Stage('Checking pack rules')
    local model,err=D.Decode(data); if model==nil then return nil,err end
    model,err=D.Validate(model); if not model then return nil,err end
    Stage('Finishing verification')
    model.digest=C.Hex(C.SHA256(data,Yield)); model.keyID=kid; model.envelope=text
    return model
end
local function Summary(model)
    return {id=model.id,title=model.title,author=model.author,version=model.version,description=model.description,
        rules=#model.rules,gommage=#(model.gommage or {}),legacyGommage=model.schema==1,replacements=#model.replacements,digest=model.digest,keyID=model.keyID,
            enabled=ns.DB.disabledPacks[model.id]~=true,active=P.Compatible(model) and ns.DB.disabledPacks[model.id]~=true,
            updateRequired=not P.Compatible(model),stock=false,purpose=model.purpose,schema=model.schema,statements=#(model.statements or {})}
end
function P.List()
    local list={}
    for _,id in ipairs(P.Order) do
        if id=='guild' or id=='creator' then
            local count=0
            for _,meta in pairs(stockMeta) do if meta.pack==id then count=count+1 end end
            list[#list+1]={id=id,title=P.StockTitles[id],version=P.StockVersions[id],author='Regretn',enabled=not ns.DB.disabledPacks[id],stock=true,
                rules=count,gommage=0,replacements=0,
                description='Subject references and explicit viewing preferences use shared statement patterns. Context handling excludes negated or defended wording, quotations and reported speech.'}
        elseif loaded[id] then list[#list+1]=Summary(loaded[id])
        elseif P.Errors[id] then list[#list+1]={id=id,title=id..' (not loaded)',error=P.Errors[id],stock=false,enabled=false} end
    end
    return list
end
function P.Title(id) return P.StockTitles[id] or loaded[id] and loaded[id].title or id end
function P.Snapshot()
    local snapshot={}
    for _,id in ipairs(P.Order) do
        local m=loaded[id]
        if m then snapshot[id]={version=m.version,digest=m.digest,keyID=m.keyID,
            enabled=P.Compatible(m) and ns.DB.disabledPacks[id]~=true,updateRequired=not P.Compatible(m)} end
    end
    return snapshot
end
local function Candidate(model)
    if not P.Compatible(model) then return nil,'Update Required: this verified pack uses the old policy. Import the compatible signed version from the author.' end
    local existing=loaded[model.id]
    if existing then
        if model.version<existing.version then return nil,'Older versions cannot replace a newer installed pack.' end
        if model.version==existing.version then
            return nil,model.digest==existing.digest and 'This pack version is already installed.' or 'This version has different contents. The author must publish a higher version.'
        end
    end
    local models={}; for id,m in pairs(loaded) do models[id]=m end; models[model.id]=model
    local built,err=Build(models); if not built then return nil,err end
    token=token+1; pending={token=token,model=model,built=built,models=models,revision=P.Revision}
    local preview=Summary(model); preview.token=token; preview.update=existing~=nil
    preview.enabled=existing and not ns.DB.disabledPacks[model.id] or false
    if existing then preview.previousVersion=existing.version end
    local old,new={},{}
    local function Index(m,map)
        if not m then return end
        for _,r in ipairs(m.rules) do map['rule:'..r.phrase]=tostring(r.score)..':'..r.origin..':'..(r.role or 'legacy') end
        for _,r in ipairs(m.statements or {}) do map['statement:'..r.position..':'..r.phrase]=tostring(r.score)..':'..r.origin end
        for _,r in ipairs(m.literal or {}) do map['retired-literal:'..r]='1' end
        for _,r in ipairs(m.gommage or {}) do map['gommage:'..r]='1' end
        for _,r in ipairs(m.replacements) do map['replace:'..r.phrase]=r.text end
        if m.policy then map['policy']=m.policy.mode..':'..m.policy.declaration..':'..m.policy.profile end
    end
    Index(existing,old); Index(model,new)
    preview.added,preview.removed,preview.changed=0,0,0
    for k,v in pairs(new) do if not old[k] then preview.added=preview.added+1 elseif old[k]~=v then preview.changed=preview.changed+1 end end
    for k in pairs(old) do if not new[k] then preview.removed=preview.removed+1 end end
    return preview
end
function P.BeginImport(text,done)
    if P.Busy or P.Restoring then return false,'Wait for the current pack verification to finish.' end
    pending=nil; P.Busy=true; P.LastError=nil; P.Progress=nil
    local started,startErr=Enqueue(function() return Verify(text) end,function(model,err)
        P.Busy=false; P.Progress=nil
        local preview
        if model then
            local ok,result,reason=pcall(Candidate,model)
            if ok then preview,err=result,reason
            else pending=nil; err='Verified pack could not be prepared. No pack was installed.' end
        end
        Changed()
        if done then done(preview,err) end
    end)
    if not started then P.Busy=false; P.Progress=nil; Changed(); return false,startErr end
    Changed()
    return true
end
function P.ProgressText()
    local p=P.Progress
    if not p then return 'Starting verification...' end
    return p.stage..'... ('..math.floor(p.elapsed)..'s)'
end
function P.CancelImport()
    if not P.Busy then return false,'No import verification is running.' end
    local cancelled=jobs; jobs={}; pending=nil; P.Busy=false; P.Progress=nil
    for _,job in ipairs(cancelled) do Complete(job,nil,'Verification cancelled. No pack was installed.') end
    Changed(); return true
end
function P.CancelPreview() pending=nil end
function P.Suspend()
    -- Invalidate restore callbacks before stopping their queued signature work.
    -- Saved envelopes and already verified models are left intact.
    restoreSerial = restoreSerial + 1
    local cancelled=jobs; jobs={};pending=nil
    P.Busy=false;P.Restoring=false;P.Progress=nil
    for _,job in ipairs(cancelled) do Complete(job,nil,'Guild access ended. Verification paused; no pack was installed.') end
end
function P.Commit(previewToken,enable)
    if P.Busy or P.Restoring or not pending or pending.token~=previewToken or pending.revision~=P.Revision then
        return false,'The preview is no longer current. Verify the pack again.'
    end
    local m=pending.model; local existing=loaded[m.id]
    ns.DB.packImports[m.id]=m.envelope
    if type(enable)=='boolean' then ns.DB.disabledPacks[m.id]=not enable
    elseif not existing then ns.DB.disabledPacks[m.id]=true end
    loaded=pending.models; local built=pending.built; pending=nil; P.Errors[m.id]=nil; Apply(built)
    return true,m.id
end
function P.Remove(id)
    if P.Busy or P.Restoring then return false,'Wait for verification to finish.' end
    if id=='guild' or id=='creator' then return false,'Stock packs can be switched off, but not removed.' end
    if not loaded[id] and not P.Errors[id] then return false,'This pack is not installed.' end
    local models={}; for name,m in pairs(loaded) do if name~=id then models[name]=m end end
    local built,err=Build(models); if not built then return false,err end
    loaded=models; ns.DB.packImports[id]=nil; ns.DB.disabledPacks[id]=true; P.Errors[id]=nil; pending=nil; Apply(built)
    return true
end
function P.Export(id) return loaded[id] and loaded[id].envelope end
function P.Initialize()
    loaded,pending,P.Errors={},{},{}; pending=nil
    -- Apply exposes the combined runtime rules through ns.StockRules. Capture
    -- the original bundled base once; later initialization must not promote
    -- verified optional rules into that base or duplicate the stock list.
    if not stockCaptured then
        for _,phrase in ipairs(ns.StockRules) do stockRules[#stockRules+1]=phrase;stockMeta[phrase]=ns.RuleMeta[phrase] end
        stockCaptured=true
    end
    if type(ns.DB.packImports)~='table' then ns.DB.packImports={} end
    if ns.Modules and not ns.Modules.Enabled('chat') then
        P.RuntimeDeferred=true;ns.Matcher=nil;ns.PackNames=ns.PackNames or P.Order;return
    end
    P.RuntimeDeferred=false
    Apply(assert(Build(loaded)))
end
function P.Restore()
    restoreSerial = restoreSerial + 1
    local serial = restoreSerial
    local queue,restored={},{}
    for _,id in ipairs(P.Order) do
        if D.Optional[id] and ns.DB.packImports[id]~=nil then queue[#queue+1]={id=id,text=ns.DB.packImports[id]} end
    end
    P.Restoring=#queue>0
    local function Next()
        if serial ~= restoreSerial then return end
        local row=table.remove(queue,1)
        if not row then
            if next(restored) then
                local built,err=Build(restored)
                if not built then
                    -- Keep other valid packs if a signed set conflicts or exceeds
                    -- the aggregate budget. Rebuild once in the normal case.
                    local accepted={}
                    for _,id in ipairs(P.Order) do
                        if restored[id] then
                            accepted[id]=restored[id]; local candidate,reason=Build(accepted)
                            if candidate then built=candidate else accepted[id]=nil; P.Errors[id]=reason or err end
                        end
                    end
                    restored=accepted
                end
                if built then loaded=restored; Apply(built) end
            end
            P.Restoring=false; P.Progress=nil; Changed(); return
        end
        local started,startErr=Enqueue(function() return Verify(row.text) end,function(model,err)
            if serial ~= restoreSerial then return end
            if model and model.id~=row.id then model=nil; err='Saved pack identity does not match its category.' end
            if model then restored[row.id]=model end
            if not model then P.Errors[row.id]=err or 'Saved pack could not be verified.' end
            Next()
        end)
        if not started then P.Errors[row.id]=startErr; Next() end
    end
    Next(); Changed()
end
