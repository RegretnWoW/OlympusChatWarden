-- Received effects, never inferred casts. One permissioned native adapter for
-- personal Chronicle and eligible Intel; no Lab reads, combat log or saved cache.
local _,ns=...
local C,S,X=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture
local E={VERSION=1,SUBJECTS=64,INSTANCES=256,TOKENS=128,
    diagnostics={seen=0,accepted=0,coalesced=0,restricted=0,unstable=0,unknownRemoval=0,evicted=0,overflow=0}}
ns.AthenaCombatEvidence=E
local subjects,bindings,scans,order,count,epoch,owner={},{},{},{},0,0,nil
function E.Valid(d)
    if not S.Integer(d.spellID,1,1000000000) or not S.Integer(d.auraInstanceID,1,1000000000)
        or not S.Integer(d.auraEpoch,1) or not S.Text(d.transitionKey,256) or not S.Text(d.runID,256) or d.apiVersion~=1
        or not ({self=true,['eligible-other']=true})[d.subjectScope]
        or not ({baseline=true,applied=true,changed=true,removed=true})[d.effectTransition]
        or not ({helpful=true,harmful=true,unknown=true})[d.classification]
        or d.coverage~='Observed native effects only; gaps and actual uptime unknown'
        or not ({['native aura update']=true,['native aura getter baseline']=true})[d.method] then return false end
    local strength=d.effectTransition=='removed' and 'AURA_REMOVED_FROM_SUBJECT'
        or d.effectTransition=='applied' and 'AURA_APPLIED_TO_SUBJECT' or 'AURA_PRESENT_ON_SUBJECT'
    if d.evidenceStrength~=strength or d.actorCoverage~=(d.sourceGUID and 'verified native source unit' or 'unavailable or restricted')
        or d.sourceGUID~=nil and not X.Entity(d.sourceGUID) then return false end
    for _,key in ipairs({'helpful','harmful','bossAura'}) do if d[key]~=nil and type(d[key])~='boolean' then return false end end
    if d.applications~=nil and not S.Integer(d.applications,0,1000000) or d.duration~=nil and not S.Number(d.duration,0)
        or d.expirationTime~=nil and not S.Number(d.expirationTime,0) then return false end
    return d.classification==(d.harmful==true and 'harmful' or d.helpful==true and 'helpful' or 'unknown')
end
function E.ValidRecord(t,character)
    local d=t.details;local own=character:match('/(Player%-.+)$')
    if not S.GUID(t.subject) or (t.subject==own)~=(d.subjectScope=='self') then return false end
    if t.source=='UNIT_AURA' then return d.method=='native aura update' end
    return d.method=='native aura getter baseline' and (d.effectTransition=='baseline' or d.effectTransition=='changed')
        and ({control=true,PLAYER_TARGET_CHANGED=true,PLAYER_FOCUS_CHANGED=true,UPDATE_MOUSEOVER_UNIT=true,
            NAME_PLATE_UNIT_ADDED=true,GROUP_ROSTER_UPDATE=true,UNIT_TARGET=true})[t.source]==true
end
local function Note(reason)
    X.Mark('Combat effects',reason)
    if ns.ChronicleCoverage then ns.ChronicleCoverage.Note('Combat effects','partial',reason) end
end
local function Token(unit)
    unit=S.Text(unit,32)
    return unit and (unit=='player' or unit=='target' or unit=='focus' or unit=='mouseover' or unit=='pet'
        or unit:match('^party%d+$') or unit:match('^raid%d+$') or unit:match('^nameplate%d+$')
        or unit:match('^partypet%d+$') or unit:match('^raidpet%d+$') or unit:match('^boss%d+$') or unit:match('^%a+target$')) and unit or nil
end
local function Eligible(unit)
    if not X.Ready() or owner~=C.Owner() or not Token(unit) then return end
    local guid=S.GUID(X.Call('UnitGUID',unit));local own=select(2,C.Owner())
    if not guid or X.Bool(X.Call('UnitIsPlayer',unit))~=true then return end
    if guid==own then if C.PersonalEnabled() then return guid,'self' end
    elseif ns.AthenaCollectionPolicy.Deep(17,guid,{witness=true,priorityOnly=true}) then return guid,'eligible-other' end
end
local function Forget(guid)
    if subjects[guid] then subjects[guid]=nil;count=count-1 end
    scans[guid]=nil
end
local function Bind(unit)
    local guid,scope=Eligible(unit);local old=bindings[unit]
    if old and old~=guid then Forget(old);bindings[unit]=nil end
    if not guid then if old then bindings[unit]=nil end;return end
    local row=subjects[guid];local now=C.Tick() or 0
    if row and now-row.checked>120 then Forget(guid);row=nil end
    if not row then
        if count>=E.SUBJECTS then
            local oldest,at;for id,v in pairs(subjects) do if not at or v.checked<at then oldest,at=id,v.checked end end
            Forget(oldest);E.diagnostics.evicted=E.diagnostics.evicted+1
            Note('Live effect cache evicted; reacquisition is a new baseline, not known continuous uptime')
        end
        epoch=epoch+1;row={guid=guid,scope=scope,epoch=epoch,sequence=0,instances={},size=0,checked=now}
        subjects[guid]=row;count=count+1
    end
    if not old then
        local n=0;for _ in pairs(bindings) do n=n+1 end
        if n>=E.TOKENS then bindings={} end -- bindings are disposable; evidence is not.
    end
    bindings[unit]=guid;row.checked=now;return row
end
local function Stable(unit,row)
    local guid,scope=Eligible(unit)
    if guid==row.guid and scope==row.scope and subjects[guid]==row then return true end
    E.diagnostics.unstable=E.diagnostics.unstable+1;Forget(row.guid);bindings[unit]=nil
end
local function Read(unit,value)
    value=X.Table(value);if not value then return end
    local out=ns.ChronicleSource.Aura(value)
    if not out then E.diagnostics.restricted=E.diagnostics.restricted+1;return end
    if not out.spellID then E.diagnostics.restricted=E.diagnostics.restricted+1 end
    local token=Token(value.sourceUnit)
    if token then
        local actor=X.Entity(X.Call('UnitGUID',token))
        if actor and actor==X.Entity(X.Call('UnitGUID',token)) then out.sourceGUID=actor end
    end
    return out
end
local semantic={'spellID','applications','duration','helpful','harmful','bossAura','sourceGUID'}
local function Same(a,b)
    if not a then return false end
    for _,key in ipairs(semantic) do if a[key]~=b[key] then return false end end
    return true -- expiration-only refreshes are operational, not new effects.
end
local function Save(unit,row,value,transition,source)
    if not Stable(unit,row) then return end
    row.sequence=row.sequence+1
    local data={recordType='aura_effect',spellID=value.spellID,auraInstanceID=value.auraInstanceID,
        effectTransition=transition,auraEpoch=row.epoch,
        runID=X.runID,transitionKey='aura/'..row.epoch..'/'..row.sequence,
        subjectScope=row.scope,apiVersion=E.VERSION,classification=value.harmful==true and 'harmful' or value.helpful==true and 'helpful' or 'unknown',
        coverage='Observed native effects only; gaps and actual uptime unknown',
        actorCoverage=value.sourceGUID and 'verified native source unit' or 'unavailable or restricted',
        evidenceStrength=transition=='removed' and 'AURA_REMOVED_FROM_SUBJECT'
            or transition=='applied' and 'AURA_APPLIED_TO_SUBJECT' or 'AURA_PRESENT_ON_SUBJECT',
        method=source=='UNIT_AURA' and 'native aura update' or 'native aura getter baseline'}
    for _,key in ipairs({'applications','duration','expirationTime','helpful','harmful','bossAura','sourceGUID'}) do data[key]=value[key] end
    if not value.spellID then
        data={recordType='aura_partial',auraInstanceID=value.auraInstanceID,auraEpoch=row.epoch,
            effectTransition=transition,transitionKey='aura/'..row.epoch..'/'..row.sequence,runID=X.runID,subjectScope=row.scope,
            fieldReadability='spell identity unavailable or restricted; no spell or caster inferred',
            scope='Native aura-instance notification on verified subject; identity, continuity and actual uptime unknown'}
        for _,key in ipairs({'applications','duration','expirationTime','helpful','harmful','bossAura','sourceGUID'}) do data[key]=value[key] end
    end
    local event=X.Record('native_event',source,data,row.guid,false,C.Place())
    if event then E.diagnostics.accepted=E.diagnostics.accepted+1 end
    return event
end
local function Present(unit,row,value,source,applied)
    local v=Read(unit,value);if not v or not Stable(unit,row) then return end
    local before=row.instances[v.auraInstanceID]
    if Same(before,v) then
        before.expirationTime=v.expirationTime;E.diagnostics.coalesced=E.diagnostics.coalesced+1;return
    end
    if not before and row.size>=E.INSTANCES then
        row.instances={};row.size=0;E.diagnostics.overflow=E.diagnostics.overflow+1
        Note('Live aura instance bound reached; retained history is untouched; new observations are baselines')
        applied=false
    end
    local transition=before and 'changed' or applied and 'applied' or 'baseline'
    if Save(unit,row,v,transition,source) then row.instances[v.auraInstanceID]=v;if not before then row.size=row.size+1 end end
end
local function List(value,fn)
    value=X.Table(value);if not value then return end
    local total=S.Integer(#value,0,1000000);if not total then return end
    if total>E.INSTANCES then E.diagnostics.overflow=E.diagnostics.overflow+1;Note('Aura update exceeds safe native read bound; coverage is partial') end
    for n=1,math.min(total,E.INSTANCES) do fn(value[n]) end
end
function E.Schedule(unit,source)
    unit=Token(unit);if not unit then return end
    local row=Bind(unit);if not row then return end
    if scans[row.guid] or source~='UNIT_AURA' and row.baselineRequested then return end
    row.baselineRequested=true
    if #order>=E.SUBJECTS then
        local fresh,seen={},{}
        for _,guid in ipairs(order) do if scans[guid] and not seen[guid] then fresh[#fresh+1]=guid;seen[guid]=true end end
        order=fresh
    end
    if not scans[row.guid] then order[#order+1]=row.guid end
    scans[row.guid]={unit=unit,row=row,source=source,filter=1,index=1,seen={}}
end
function E.Aura(unit,update)
    unit=Token(unit);if not unit then return end
    local row=Bind(unit);if not row then return end -- before payload work.
    E.diagnostics.seen=E.diagnostics.seen+1
    update=X.Table(update)
    if not update then E.diagnostics.restricted=E.diagnostics.restricted+1;Note('Aura payload unavailable or restricted');return end
    if X.Bool(update.isFullUpdate)==true then E.Schedule(unit,'UNIT_AURA');return end
    List(update.addedAuras,function(v) Present(unit,row,v,'UNIT_AURA',true) end)
    List(update.updatedAuraInstanceIDs,function(id)
        id=S.Integer(id,1,1000000000);if not id or not Stable(unit,row) then return end
        local v=X.Call('C_UnitAuras.GetAuraDataByAuraInstanceID',unit,id)
        local t=X.Table(v)
        if t and S.Integer(t.auraInstanceID,1)==id then Present(unit,row,t,'UNIT_AURA',false)
        else
            E.diagnostics.restricted=E.diagnostics.restricted+1;Note('Updated aura not readable; absence is not removal')
            -- The delivered instance ID is still a distinct native observation.
            -- Do not reuse an older spell identity when this read is restricted.
            Present(unit,row,{auraInstanceID=id},'UNIT_AURA',false)
        end
    end)
    List(update.removedAuraInstanceIDs,function(id)
        id=S.Integer(id,1,1000000000);if not id or not Stable(unit,row) then return end
        local prior=row.instances[id]
        if not prior then
            E.diagnostics.unknownRemoval=E.diagnostics.unknownRemoval+1
            Save(unit,row,{auraInstanceID=id},'removed','UNIT_AURA');return
        end
        if Save(unit,row,prior,'removed','UNIT_AURA') then row.instances[id]=nil;row.size=row.size-1 end
    end)
end
function E.Pending() return #order end
function E.Pump()
    if not X.Ready() or owner~=C.Owner() then return end
    local guid=order[1];if not guid then return end
    local job=scans[guid]
    if not job or not Stable(job.unit,job.row) then scans[guid]=nil;table.remove(order,1);return end
    if not X.API('C_UnitAuras.GetAuraDataByIndex') then
        X.Mark('Combat effects','Aura baseline getter unavailable; legal delivered deltas remain usable')
        scans[guid]=nil;table.remove(order,1);return
    end
    -- Eight legal getter reads per pump even in combat. No protected actions.
    for _=1,8 do
        if not Stable(job.unit,job.row) then break end
        local value=X.Call('C_UnitAuras.GetAuraDataByIndex',job.unit,job.index,job.filter==1 and 'HELPFUL' or 'HARMFUL')
        if not Stable(job.unit,job.row) then break end
        if ns.Readable(value) and value==nil then
            if job.filter==1 then job.filter=2;job.index=1
            else
                -- A full read is a baseline. Unseen old instances become
                -- unknown; it never manufactures a timed removal or uptime.
                for id in pairs(job.row.instances) do if not job.seen[id] then job.row.instances[id]=nil;job.row.size=job.row.size-1 end end
                scans[guid]=nil;table.remove(order,1);return
            end
        else
            local t=X.Table(value);local id=t and S.Integer(t.auraInstanceID,1)
            if id then job.seen[id]=true;Present(job.unit,job.row,t,job.source,false)
            else E.diagnostics.restricted=E.diagnostics.restricted+1 end
            job.index=job.index+1
            if job.index>E.INSTANCES then Note('Aura baseline incomplete at safe read bound');scans[guid]=nil;table.remove(order,1);return end
        end
    end
    if not subjects[guid] then scans[guid]=nil;table.remove(order,1)
    elseif #order>1 then table.remove(order,1);order[#order+1]=guid end
end
function E.Start() E.Stop();owner=C.Owner();if C.PersonalEnabled() then E.Schedule('player','control') end end
function E.Stop() subjects={};bindings={};scans={};order={};count=0;owner=nil end
function E.Counts() local n=0;for _,v in pairs(subjects) do n=n+v.size end;return count,n,#order end
function E.Revoke(guid)
    if not ns.AthenaEnrichment or not ns.AthenaEnrichment.Priority(guid) then Forget(guid) end
end
function E.WitnessBoundary()
    local others={};for guid,row in pairs(subjects) do if row.scope~='self' then others[#others+1]=guid end end
    for _,guid in ipairs(others) do Forget(guid) end
    for unit,guid in pairs(bindings) do if not subjects[guid] then bindings[unit]=nil end end
end
function E.Handle(event,a,b)
    if event=='UNIT_AURA' then E.Aura(a,b)
    elseif event=='NAME_PLATE_UNIT_REMOVED' then
        local unit=Token(a);local guid=unit and bindings[unit];if guid then Forget(guid);bindings[unit]=nil end
    elseif event=='GROUP_ROSTER_UPDATE' then
        local raid=X.Bool(X.Call('IsInRaid'))==true
        for n=1,raid and 40 or 4 do E.Schedule((raid and 'raid' or 'party')..n,event) end
    elseif event=='UNIT_TARGET' then local unit=Token(a);if unit then E.Schedule(unit..'target',event) end
    else
        E.Schedule(event=='PLAYER_TARGET_CHANGED' and 'target' or event=='PLAYER_FOCUS_CHANGED' and 'focus'
            or event=='UPDATE_MOUSEOVER_UNIT' and 'mouseover' or a,event)
    end
end
X.Register(E,{'UNIT_AURA','PLAYER_TARGET_CHANGED','PLAYER_FOCUS_CHANGED','UPDATE_MOUSEOVER_UNIT','UNIT_TARGET',
    'NAME_PLATE_UNIT_ADDED','NAME_PLATE_UNIT_REMOVED','GROUP_ROSTER_UPDATE'},'history')
