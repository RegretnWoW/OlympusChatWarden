-- Important friendly and hostile players; no passerby inspect sweep.
local _,ns=...
local C,S,X,L=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture,ns.ChronicleLoadout
local I={AUTO_BACKOFF=300,QUEUE_LIMIT=64};ns.ChronicleEncounters=I
local important,pending,requests,reputation,lastRequest,epoch,hooked={},nil,{}, {},-100,0,false
local priorities={}
local Reply
local externalRequest,nativeShowHooked,nativeChangedHooked,nativeFrameHooked
local gearCompletion,watchPending
local function Enrichment(guid,state,reason,gear,traits)
    if ns.AthenaEnrichment then ns.AthenaEnrichment.Inspection(guid,state,reason,gear,traits) end
end
local function Trace(guid,code,source,category)
    if ns.AthenaLab and ns.AthenaLab.Report then ns.AthenaLab.Report(source or 'INSPECT_READY',guid,code,category or 'gear and talents','inspection guard') end
end
local function NativeUnit()
    local f=InspectFrame;if not ns.Readable(f) or not f then return end
    local unit=type(f.GetInspectUnit)=='function' and ns.SafeCall(f.GetInspectUnit,f) or f.unit
    return S.Text(unit,32)
end
local function NativeStable(p)
    return NativeUnit()==p.unit and S.GUID(X.Call('UnitGUID',p.unit))==p.guid
        and X.Bool(X.Call('UnitIsPlayer',p.unit))==true and X.Bool(X.Call('UnitIsVisible',p.unit))==true
end
function I.NativeInspect(unit)
    local r=externalRequest
    if not X.Ready() or not C.IntelEnabled() or X.Busy() or not r or r.epoch~=epoch or not ns.CanRead(unit) or r.unit~=unit then return end
    if not NativeStable(r) or r.guid==S.GUID(X.Call('UnitGUID','player')) then return end
    local now=C.Tick();if not now or now-r.at>8 then return end
    -- The native Show/UnitChanged post-hook confirms intent. NotifyInspect alone
    -- from an unrelated addon never qualifies for saved player intelligence.
    pending={guid=r.guid,unit=unit,at=r.at,epoch=epoch,reason='manual inspection',native=true}
    local old=important[r.guid]
    important[r.guid]={unit=unit,reason='manual inspection',tick=now,source='INSPECT_READY',lastAttempt=old and old.lastAttempt,queued=old and old.queued}
    X.Mark('Inspection','Manual inspection requested; waiting for matching native response')
end
local function InstallNativeHooks()
    if type(hooksecurefunc)~='function' then return end
    if not nativeShowHooked and type(InspectFrame_Show)=='function' then
        hooksecurefunc('InspectFrame_Show',function(unit) I.NativeInspect(unit) end);nativeShowHooked=true
    end
    if not nativeChangedHooked and type(InspectFrame_UnitChanged)=='function' then
        hooksecurefunc('InspectFrame_UnitChanged',function() I.NativeInspect(NativeUnit()) end);nativeChangedHooked=true
    end
    if InspectFrame and InspectFrame~=nativeFrameHooked and type(InspectFrame.UnitChanged)=='function' then
        hooksecurefunc(InspectFrame,'UnitChanged',function() I.NativeInspect(NativeUnit()) end);nativeFrameHooked=InspectFrame
    end
end
local function Units()
    local units={'target','focus','mouseover'}
    for i=1,4 do units[#units+1]='party'..i end
    for i=1,40 do units[#units+1]='raid'..i end
    return units
end
local function Record(source,data,guid)
    if source=='INSPECT_READY' and ns.AthenaObservationSchema and ns.AthenaEnrichment.Priority(guid) then data=ns.AthenaObservationSchema.Inspection(data,guid) end
    return X.Record('important_player',source,data,guid,false)
end
function I.Important(unit,source,reason)
    if not X.Ready() or X.Busy() then return end
    local guid=S.GUID(X.Call('UnitGUID',unit));if not guid or guid==S.GUID(X.Call('UnitGUID','player')) then return end
    if ns.AthenaEnrichment and ns.AthenaEnrichment.Priority(guid) then return ns.AthenaEnrichment.Opportunity(unit,source) end
    if (reason=='party teammate' or reason=='raid teammate') and ns.IntelPolicy.Tier(guid)~=1 then
        -- A roster proves activity, not an established relationship. Preserve
        -- its source while avoiding mass inspections of a first group.
        C.ObserveUnit(unit,source,ns.Checked(X.Call('UnitIsVisible',unit)));return guid
    end
    local old=important[guid];local now=C.Tick();if not now then return end
    if old and old.reason==reason and now-old.tick<60 then old.unit=unit;return guid end
    local name=S.Text(X.Call('UnitName',unit),144)
    if not name or S.GUID(X.Call('UnitGUID',unit))~=guid then return end
    C.ObserveUnit(unit,source,ns.Checked(X.Call('UnitIsVisible',unit)))
    local appearance=L.Appearance(unit,guid,source);local at=C.Stamp()
    local event=Record(source,{name=name,relationship=reason,unitVisible=X.Bool(X.Call('UnitIsVisible',unit)),
        appearanceRef=appearance,appearanceObservedAt=appearance and at,inspection='not yet available'},guid)
    local v={unit=unit,reason=reason,tick=now,source=source,event=event and event.id,lastAttempt=old and old.lastAttempt,queued=old and old.queued}
    important[guid]=v
    if not v.queued and #requests<I.QUEUE_LIMIT and (not v.lastAttempt or now-v.lastAttempt>=I.AUTO_BACKOFF) then v.queued=true;requests[#requests+1]=guid end
    return guid
end
function I.ImportantGUID(guid,source,reason)
    if X.Busy() then X.Queue('important:'..guid,function() I.ImportantGUID(guid,source,reason) end);return end
    for _,unit in ipairs(Units()) do if S.GUID(X.Call('UnitGUID',unit))==guid then return I.Important(unit,source,reason) end end
    X.Mark('Important players','Encounter saved; no current unit for detailed inspection')
end
function I.IsImportant(guid) return important[guid] and not important[guid].contactOnly and important[guid].reason~=nil or ns.IntelPolicy.Tier(guid)==1 end
function I.InspectionState(guid)
    local v=important[guid];local now=C.Tick()
    if pending and pending.guid==guid then return 'pending','Waiting for matching native inspection' end
    if v and v.queued then return 'queued','Queued behind other safe inspection opportunities' end
    if v and v.lastAttempt and now and now-v.lastAttempt<I.AUTO_BACKOFF then return 'cooldown','Inspection backoff; retry on a later unit opportunity' end
    return 'missing','Not yet requested at a safe native opportunity'
end
function I.RequestInspection(guid,unit,reason,watchOnly,priorityOnly,contactBasis)
    if not X.Ready() or not C.IntelEnabled() then return 'permission_off','Player recording is off' end
    if not S.GUID(guid) or S.GUID(X.Call('UnitGUID',unit))~=guid or X.Bool(X.Call('UnitIsPlayer',unit))~=true then return 'waiting_for_unit','No matching player unit' end
    if contactBasis and (not ns.AthenaFirstContact or not ns.AthenaFirstContact.Permitted(guid,contactBasis)) then return 'permission_off','First-contact inspection is not authorized' end
    local state,why=I.InspectionState(guid)
    if state=='queued' or state=='pending' or state=='cooldown' then return state,why end
    if not hooked or not X.API('NotifyInspect') or not X.API('CanInspect') then return 'API_unavailable','Safe native inspection is unavailable' end
    if X.Bool(X.Call('UnitIsEnemy','player',unit))==true or X.Bool(X.Call('CanInspect',unit,true))~=true then return 'not_inspectable','Player cannot currently be inspected' end
    if #requests>=I.QUEUE_LIMIT then return 'capacity','Inspection queue full; retained watch will retry on a new opportunity' end
    if not important[guid] then
        local count,expired=0,nil;local now=C.Tick()
        for id,row in pairs(important) do
            count=count+1
            if (row.watchOnly or row.priorityOnly or row.contactOnly) and not row.queued and not (pending and pending.guid==id)
                and now and now-(row.lastAttempt or row.tick or now)>=I.AUTO_BACKOFF then expired=id end
        end
        if count>=512 then
            if expired then important[expired]=nil
            else return 'capacity','Inspection priority cache full; retry on a new opportunity' end
        end
    end
    local v=important[guid] or {};important[guid]=v
    v.unit=unit;v.reason=reason;v.watchOnly=watchOnly==true;v.priorityOnly=priorityOnly==true;v.tick=C.Tick();v.queued=true;requests[#requests+1]=guid
    v.contactOnly=contactBasis~=nil;v.contactBasis=contactBasis
    return 'queued','Queued for a safe native inspection'
end
function I.CancelContactWork()
    for guid,v in pairs(important) do if v.contactOnly then v.queued=nil;v.unit=nil;for n=#requests,1,-1 do if requests[n]==guid then table.remove(requests,n) end end end end
    if pending and pending.contactOnly then pending=nil end
    if gearCompletion and gearCompletion.contactOnly then gearCompletion=nil end
end
function I.CancelWatch(guid)
    local eligible,reason,watchOnly
    if ns.AthenaEnrichment then eligible,reason,watchOnly=ns.AthenaEnrichment.Priority(guid) end
    local v=important[guid]
    for _,row in ipairs({v or false,pending and pending.guid==guid and pending or false,
        gearCompletion and gearCompletion.guid==guid and gearCompletion or false}) do
        if row and (row.watchOnly or row.priorityOnly) and eligible then row.watchOnly=watchOnly;row.reason=reason end
    end
    if eligible then return end
    if v and (v.watchOnly or v.priorityOnly) then
        v.queued=nil;v.reason=nil;v.unit=nil
        for n=#requests,1,-1 do if requests[n]==guid then table.remove(requests,n) end end
    end
    if pending and pending.guid==guid and (pending.watchOnly or pending.priorityOnly) then pending=nil end
    if gearCompletion and gearCompletion.guid==guid and (gearCompletion.watchOnly or gearCompletion.priorityOnly) then gearCompletion=nil end
end
function I.RememberDuel(guid,unit)
    if not X.Ready() or not S.GUID(guid) or guid==S.GUID(X.Call('UnitGUID','player')) then return end
    local old=important[guid] or {}
    important[guid]={unit=unit and S.GUID(X.Call('UnitGUID',unit))==guid and unit or old.unit,
        reason='verified duel opponent',tick=C.Tick(),source='DUEL_COUNTDOWN',lastAttempt=old.lastAttempt,queued=old.queued}
end
function I.Group(source)
    if not X.Ready() or X.Busy() then return end
    local raid=ns.Checked(X.Call('IsInRaid'));local count=S.Integer(X.Call('GetNumGroupMembers'),0,40)
    if not count then count=raid and S.Integer(X.Call('GetNumRaidMembers'),0,40) or S.Integer(X.Call('GetNumPartyMembers'),0,4);if not raid and count then count=count+1 end end
    if not count then return end
    for i=1,(raid and count or math.max(0,count-1)) do
        I.Important((raid and 'raid' or 'party')..i,source,raid and 'raid teammate' or 'party teammate')
        X.Yield()
    end
end
function I.Observe(unit,source)
    if not X.Ready() then return end
    local guid=S.GUID(X.Call('UnitGUID',unit));if not guid then return end
    local p=C.Profile(guid)
    if S.loading or p and p.watchContext=='unresolved' then
        watchPending=true;X.Mark('Watchlist context','Unknown while profiles validate; earlier watch state is not inferred')
    end
    if ns.AthenaEnrichment and ns.AthenaEnrichment.Priority(guid) then
        if ns.IntelWitness and ns.IntelWitness.Enabled() then return guid end -- its verified unit route owns this event
        return ns.AthenaEnrichment and ns.AthenaEnrichment.Opportunity(unit,source) or I.Important(unit,source,'personal bookmark')
    end
    if X.Busy() then return end
    if (not important[guid] or not important[guid].reason) and ns.IntelPolicy.EarnedTier(guid)==1 then return I.Important(unit,source,'earned relationship') end
    local name=S.Text(X.Call('UnitName',unit),144)
    local friend=name and X.Table(X.Call('C_FriendList.GetFriendInfo',name))
    if ns.AthenaSocial and ns.AthenaSocial.Unit(unit,source) then return ns.AthenaEnrichment.Opportunity(unit,source,guid) end
    -- Ordinary character friendship is GUID-bound. No Battle.net lookup, private
    -- notes, friend-list census or name-only relationship merge.
    if friend and S.GUID(friend.guid)==guid then return I.Important(unit,source,'encountered friend') end
    local wanted=ns.Wanted and X.Table(ns.Wanted.byGUID)
    if wanted and wanted[guid] then return I.Important(unit,source,'Wanted encounter') end
end
local function InstallHooks()
    if type(hooksecurefunc)~='function' or not X.API('NotifyInspect') then return end
    InstallNativeHooks()
    if hooked then return end
    -- Observe global inspect ownership without replacing any client function.
    hooksecurefunc('NotifyInspect',function(unit)
        epoch=epoch+1
        gearCompletion=nil
        externalRequest=nil
        if pending and I.requesting then pending.epoch=epoch else
            Reply(pending,nil,nil,nil,'another native inspection took ownership');pending=nil;lastRequest=C.Tick() or lastRequest
            local guid=ns.CanRead(unit) and S.GUID(X.Call('UnitGUID',unit));local now=C.Tick()
            if X.Ready() and not X.Busy() and guid and now then externalRequest={guid=guid,unit=unit,at=now,epoch=epoch} end
        end
    end)
    if X.API('ClearInspectPlayer') then hooksecurefunc('ClearInspectPlayer',function() epoch=epoch+1;Reply(pending,nil,nil,nil,'native inspection cleared');pending=nil;externalRequest=nil end) end
    hooked=true
end
-- One bounded priority request per explicit duel/phase token. The ordinary
-- 300-second policy, native UI ownership and five-second global spacing remain.
function I.Priority(guid,token,valid,callback)
    if not X.Ready() or not S.GUID(guid) or type(valid)~='function' or not valid() then return false end
    local now=C.Tick();if not now then return false end
    for n=#priorities,1,-1 do
        local p=priorities[n]
        if not p.valid() or now-p.at>15 then
            table.remove(priorities,n);if p.callback then p.callback(nil,nil,nil,'capture opportunity expired') end
        end
    end
    for _,p in ipairs(priorities) do if p.token==token then return true end end
    if #priorities>=4 then return false end
    priorities[#priorities+1]={guid=guid,token=token,valid=valid,callback=callback,at=now};return true
end
Reply=function(p,gear,traits,appearance,reason)
    if p and p.priority and p.priority.callback then p.priority.callback(gear,traits,appearance,reason) end
    if p and reason then Enrichment(p.guid,'error',reason) end
    if p and reason then
        local code=reason=='inspection timed out' and 'INSPECT_TIMEOUT' or reason=='late inspection response' and 'LATE_RESPONSE'
            or reason=='native inspection unavailable' and 'API_UNAVAILABLE' or 'OWNERSHIP_CHANGED'
        Trace(p.guid,code)
    end
end
function I.Pending() return pending~=nil or #requests>0 or #priorities>0 end
local function MissingGearLinks(hash)
    local object=hash and X.Find(C.Owner(),hash)
    for _,slot in ipairs(object and object.capture.values.slots or {}) do if slot[2]=='pending' then return true end end
    return false
end
local function CompleteGear(now)
    local p=gearCompletion;if not p or now<p.next then return end
    local function owned()
        return X.Ready() and not X.Busy() and p==gearCompletion and p.epoch==epoch and C.Owner()==p.owner
            and (not ns.Modules or ns.Modules.Enabled('intel'))
            and S.GUID(X.Call('UnitGUID',p.unit))==p.guid and X.Bool(X.Call('UnitIsVisible',p.unit))==true
            and (not p.contactOnly or ns.AthenaFirstContact.Permitted(p.guid,p.contactBasis))
            and (not p.native or NativeStable(p))
    end
    if now-p.at>4 or p.tries>=3 or not owned() then gearCompletion=nil;return end
    p.tries=p.tries+1;p.next=now+({.6,1.4,2})[p.tries]
    local hash=L.Gear(p.unit,p.guid,'INSPECT_READY',owned)
    if not owned() then gearCompletion=nil;return end
    if hash and hash~=p.hash then
        local at=C.Stamp();Record('INSPECT_READY',{relationship=p.reason,gearRef=hash,gearObservedAt=at,
            observedAt=at,inspection='item cache completed after inspection',partial=true},p.guid);p.hash=hash
        Enrichment(p.guid,'partial',nil,hash)
    end
    if hash and not MissingGearLinks(hash) or p.tries>=3 then gearCompletion=nil end
end
function I.InspectPump()
    if not X.Ready() or not C.IntelEnabled() or X.Busy() then return end
    local now=C.Tick();if not now then return end
    if watchPending and not S.loading and not S.blocked and S.Character(C.Owner(),false) then
        watchPending=nil
        -- Recheck only still-visible units now. Never backdate an inspection or
        -- claim that a current watch flag proves an earlier watchlist state.
        for _,unit in ipairs({'target','focus','mouseover'}) do
            if X.Bool(X.Call('UnitIsVisible',unit))==true then
                local guid=S.GUID(X.Call('UnitGUID',unit));local e=ns.AthenaEnrichment
                if e and e.Priority(guid) then e.Reconcile(unit,'control') else I.Observe(unit,'control') end
            end
        end
        X.Mark('Watchlist context','Current watchlist validated; past unrecognized sightings remain historically unknown')
    end
    CompleteGear(now)
    if pending then
        if now-pending.at<8 then return end
        Reply(pending,nil,nil,nil,'inspection timed out');X.Mark('Inspection','Timed out; encounter retained with partial details');pending=nil
    end
    local waiting=requests[1];local head=waiting and important[waiting]
    local function Wait(code)
        if head and head.labWait~=code then head.labWait=code;Trace(waiting,code,'control') end
    end
    if not hooked then Wait('API_UNAVAILABLE');return end
    if now-lastRequest<5 then Wait('GLOBAL_THROTTLE');return end
    if InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown() then Wait('NATIVE_UI_BUSY');return end
    local priority
    while #priorities>0 do
        local p=table.remove(priorities,1)
        if p.valid() and now-p.at<=15 then priority=p;break
        elseif p.callback then p.callback(nil,nil,nil,'capture opportunity expired') end
    end
    local guid=priority and priority.guid or table.remove(requests,1);local v=guid and important[guid]
    if priority then
        local unit
        for _,candidate in ipairs(Units()) do if S.GUID(X.Call('UnitGUID',candidate))==guid then unit=candidate;break end end
        v={unit=unit,reason='verified duel opponent'}
    end
    if not v then return end
    v.queued=nil
    v.labWait=nil
    if not priority and v.lastAttempt and now-v.lastAttempt<I.AUTO_BACKOFF then return end
    if (v.watchOnly or v.priorityOnly) and (not ns.AthenaEnrichment or not ns.AthenaEnrichment.Priority(guid)) then return end
    if v.contactOnly and (not ns.AthenaFirstContact or not ns.AthenaFirstContact.Permitted(guid,v.contactBasis)) then return end
    if (v.watchOnly or v.priorityOnly or v.reason=='earned relationship') and ns.AthenaEnrichment then v.unit=ns.AthenaEnrichment.Resolve(guid) end
    if not v.unit or S.GUID(X.Call('UnitGUID',v.unit))~=guid or X.Bool(X.Call('UnitIsEnemy','player',v.unit))==true or X.Bool(X.Call('CanInspect',v.unit,true))~=true
        or S.GUID(X.Call('UnitGUID',v.unit))~=guid then
        if priority and priority.callback then priority.callback(nil,nil,nil,'player unavailable or not inspectable') end
        Enrichment(guid,'not_inspectable','Player currently unavailable; waiting for a new unit opportunity')
        Trace(guid,'NOT_INSPECTABLE','control')
        X.Mark('Inspection','Important player currently unavailable; no substitute identity');return
    end
    local fn=X.API('NotifyInspect');if not fn then return end
    if v.contactOnly and not ns.AthenaFirstContact.BeginAttempt(guid,v.unit,v.contactBasis) then return end
    pending={guid=guid,unit=v.unit,at=now,epoch=epoch,reason=v.reason,priority=priority,watchOnly=v.watchOnly,priorityOnly=v.priorityOnly,contactOnly=v.contactOnly,contactBasis=v.contactBasis}
    I.requesting=true;local ok,accepted=pcall(fn,v.unit);I.requesting=false;lastRequest=now;v.lastAttempt=now
    if important[guid] then important[guid].lastAttempt=now end
    Enrichment(guid,'pending','Waiting for matching native inspection')
    if not ok or ns.Readable(accepted) and accepted==false then Reply(pending,nil,nil,nil,'native inspection unavailable');pending=nil;X.Mark('Inspection','Normal inspection unavailable') end
end
function I.TalentChoices(owned,ownConfig)
    -- This is the native Inspect configuration, never the recorder's active
    -- config. The targetless cache is valid only inside our owned response.
    local constants=X.Table(Constants);local traitConsts=constants and X.Table(constants.TraitConsts)
    local config=ownConfig or traitConsts and S.Integer(traitConsts.INSPECT_TRAIT_CONFIG_ID,-1000000000,1000000000)
    if not config or not owned() or not ownConfig and X.Bool(X.Call('C_Traits.HasValidInspectData'))~=true then return end
    local info=X.Table(X.Call('C_Traits.GetConfigInfo',config));if not owned() then return end
    local trees=info and X.Table(info.treeIDs)
    if not trees or S.Integer(info.ID)~=config or #trees==0 then return end
    local rows,seen,read,total,complete={}, {},0,0,#trees<=4
    local layouts={}
    for t=1,math.min(4,#trees) do
        local tree=S.Integer(trees[t],1,1000000000)
        local nodes=tree and X.Table(X.Call('C_Traits.GetTreeNodes',tree))
        if not owned() then return end
        if not nodes then complete=false else
            local layout
            if not ownConfig then
                layout={tree=tree,rows={},groups=ns.WardenTalents.Groups(tree),complete=true};layouts[#layouts+1]=layout
            end
            total=total+#nodes
            for n=1,math.min(#nodes,math.max(0,256-read)) do
                local id=S.Integer(nodes[n],1,1000000000)
                local node=id and X.Table(X.Call('C_Traits.GetNodeInfo',config,id));read=read+1
                if not owned() then return end
                if not node or S.Integer(node.ID)~=id then complete=false;if layout then layout.complete=false end else
                    if layout then
                        local geometry=ns.WardenTalents.Node(config,tree,node,owned);if not owned() then return end
                        if geometry then layout.rows[#layout.rows+1]=geometry else layout.complete=false end
                    end
                    local active=X.Table(node.activeEntry);local rank=active and S.Integer(active.rank,0,1000)
                    local entry=active and S.Integer(active.entryID,1,1000000000)
                    if rank and rank>0 and entry then
                        if not seen[id] and #rows<80 then
                            local e=X.Table(X.Call('C_Traits.GetEntryInfo',config,entry));if not owned() then return end
                            local definition=e and S.Integer(e.definitionID,1,1000000000)
                            local d=definition and X.Table(X.Call('C_Traits.GetDefinitionInfo',definition));if not owned() then return end
                            rows[#rows+1]={tree,id,entry,rank,definition or false,d and S.Integer(d.spellID,1,1000000000) or false}
                            seen[id]=true
                        elseif not seen[id] then complete=false end
                    elseif S.Integer(node.currentRank,0,1000)~=0 then complete=false end
                end
            end
            if read<total then complete=false;if layout then layout.complete=false end end
        end
    end
    if not owned() or not ownConfig and X.Bool(X.Call('C_Traits.HasValidInspectData'))~=true then return end
    return rows,complete,read,total,layouts
end
function I.InspectReady(guid)
    guid=S.GUID(guid);if not guid or not X.Ready() or not C.IntelEnabled() then return end
    local p=pending
    if not p then Trace(guid,'NO_OWNED_REQUEST');return end
    if p.guid~=guid then Trace(guid,'NO_OWNED_REQUEST');return end
    if p.epoch~=epoch then Trace(guid,'OWNERSHIP_CHANGED');return end
    if S.GUID(X.Call('UnitGUID',p.unit))~=guid then Trace(guid,'GUID_MISMATCH');return end
    if X.Busy() then Trace(guid,'COMBAT_DEFERRED');return end
    if p.priority and not p.priority.valid() then Reply(p,nil,nil,nil,'capture phase ended');pending=nil;externalRequest=nil;return end
    if p.contactOnly and not ns.AthenaFirstContact.Permitted(guid,p.contactBasis) then pending=nil;return end
    local now=C.Tick();if not now or now-p.at>=8 then Reply(p,nil,nil,nil,'late inspection response');pending=nil;externalRequest=nil;X.Mark('Inspection','Late inspect response ignored');return end
    if p.native and not NativeStable(p) then Trace(guid,'GUID_MISMATCH');return end
    local function owned() return X.Ready() and not X.Busy() and pending==p and p.epoch==epoch
        and (not p.contactOnly or ns.AthenaFirstContact.Permitted(guid,p.contactBasis))
        and S.GUID(X.Call('UnitGUID',p.unit))==guid and (not p.native or NativeStable(p)) end
    if p.native then
        C.ObserveUnit(p.unit,'INSPECT_READY',true)
        if not owned() then return end
    end
    local gear=L.Gear(p.unit,guid,'INSPECT_READY',owned);if not owned() then return end
    local appearance=L.Appearance(p.unit,guid,'INSPECT_READY')
    local traits,export,specialization
    -- Shared targetless trait cache is read only while this owned response and
    -- target GUID remain stable. Never request another identity by display name.
    if X.Bool(X.Call('C_Traits.HasValidInspectData'))==true then
        export=S.Text(X.Call('C_Traits.GenerateInspectImportString',p.unit),5000)
    end
    if not owned() then return end
    specialization=S.Integer(X.Call('C_SpecializationInfo.GetInspectSpecialization',p.unit),1,1000000)
    if not owned() then return end
    local choices,complete,read,total,layouts=I.TalentChoices(owned);if not owned() then return end
    if export or specialization or choices then
        local values={guid=guid,exportString=export,specializationID=specialization,choices=choices,
            choicesComplete=complete,nodesRead=read,nodesTotal=total,layoutRefs=ns.WardenTalents.Store(layouts,owned)}
        if not owned() then return end
        if not X.Validate({format=1,family='traits',values=values}) then values.layoutRefs=nil end
        -- Preserve the original export even if a large readable projection does
        -- not fit the existing snapshot size limit. Never silently call it complete.
        while choices and not X.Validate({format=1,family='traits',values=values}) and #choices>0 do
            table.remove(choices);values.choicesComplete=false
        end
        if not X.Validate({format=1,family='traits',values=values}) then values={guid=guid,exportString=export,specializationID=specialization} end
        traits=X.Store('traits',values,'INSPECT_READY')
    end
    if not owned() then return end
    X.Mark('traits',export and 'GUID-matched native talent export saved' or specialization and 'Inspected specialization saved; talent export unavailable' or 'Inspected talents unavailable; no local-player substitute')
    -- The pinned native honor UI uses a targetless getter and an update with no
    -- GUID/readiness token. Do not attach that shared cache to this response.
    X.Mark('Inspected PvP','Unavailable: native honor cache cannot be independently tied to this inspected GUID')
    X.Mark('Inspected reputation','Unavailable: no supported other-player reputation API')
    local at=C.Stamp()
    if not p.priority then Record('INSPECT_READY',{relationship=p.reason,inspection=gear and 'partial readable inspection' or 'gear unavailable',
        gearRef=gear,gearObservedAt=gear and at,traitRef=traits,traitObservedAt=traits and at,
        appearanceRef=appearance,appearanceObservedAt=appearance and at,observedAt=at,partial=true},guid) end
    if p.native then
        for n=#requests,1,-1 do if requests[n]==guid then table.remove(requests,n) end end
        if important[guid] then important[guid].queued=nil;important[guid].lastAttempt=now end
    end
    Reply(p,gear,traits,appearance)
    if p.native and ns.ChronicleDuels then ns.ChronicleDuels.ManualCapture(guid,gear,traits,appearance) end
    Enrichment(guid,(gear or traits) and 'saved' or 'partial',nil,gear,traits)
    -- Native item links can arrive after INSPECT_READY. Re-read this owned cache
    -- at most three times; never issue another inspection or change duel timing.
    if not p.priority and (not gear or MissingGearLinks(gear)) then
        gearCompletion={guid=guid,unit=p.unit,owner=C.Owner(),epoch=epoch,native=p.native,reason=p.reason,
            at=now,next=now+.2,tries=0,hash=gear,watchOnly=p.watchOnly,priorityOnly=p.priorityOnly,contactOnly=p.contactOnly,contactBasis=p.contactBasis}
    end
    pending=nil;externalRequest=nil;X.Mark('Inspection',p.native and 'Manual inspection saved for this player; appearance may be incomplete' or 'GUID-matched normal inspect response saved; appearance may be incomplete')
end
function I.Reputation(source,id)
    if not X.Ready() or X.Busy() then return end
    local row=X.Table(X.Call('C_Reputation.GetFactionDataByID',id));if not row then return end
    local standing=S.Integer(row.currentStanding);local reaction=S.Integer(row.reaction,1,100)
    if not standing or not reaction then reputation[id]=nil;return end
    local before=reputation[id]
    if before and standing~=before.standing then
        -- Standard reaction-based factions have a continuous standing scale.
        -- Renown/friendship systems need their own scale; do not invent a delta.
        local major=X.Bool(X.Call('C_Reputation.IsMajorFaction',id))
        X.Record('native_event',source,{recordType='reputation_standing_changed',factionID=id,name=S.Text(row.name,144),
            beforeStanding=before.standing,afterStanding=standing,reaction=reaction,
            delta=major==false and standing-before.standing or nil})
    end
    reputation[id]={standing=standing,reaction=reaction}
end
function I.ReputationBaseline()
    local count=S.Integer(X.Call('C_Reputation.GetNumFactions'),0,2000);if not count then return end
    for i=1,count do
        local row=X.Table(X.Call('C_Reputation.GetFactionDataByIndex',i));local id=row and S.Integer(row.factionID,1,10000000)
        if id then I.Reputation('control',id) end;X.Yield()
    end
end
function I.Start()
    important={};pending=nil;externalRequest=nil;gearCompletion=nil;watchPending=S.loading and true or nil;requests={};priorities={};reputation={};InstallHooks()
    X.Queue('important-group',function() I.Group('GROUP_ROSTER_UPDATE') end)
    X.Queue('reputation-baseline',I.ReputationBaseline)
    X.Mark('Inspection',hooked and 'Important-player inspections and deliberate native inspections enabled' or 'Passive mode: inspect ownership hooks unavailable')
end
function I.Stop() important={};pending=nil;externalRequest=nil;gearCompletion=nil;watchPending=nil;requests={};priorities={};reputation={} end
function I.Handle(event,a,b)
    if event=='ADDON_LOADED' then InstallHooks()
    elseif event=='GROUP_ROSTER_UPDATE' or event=='PARTY_MEMBERS_CHANGED' then X.Queue('important-group',function() I.Group(event) end)
    elseif event=='PLAYER_TARGET_CHANGED' then I.Observe('target',event)
    elseif event=='UPDATE_MOUSEOVER_UNIT' then I.Observe('mouseover',event)
    elseif event=='PLAYER_FOCUS_CHANGED' then I.Observe('focus',event)
    elseif event=='INSPECT_READY' then I.InspectReady(a)
    elseif event=='NAME_PLATE_UNIT_REMOVED' then
        if ns.AthenaEnrichment then ns.AthenaEnrichment.Removed(a) end
    elseif event=='NAME_PLATE_UNIT_ADDED' or event=='UNIT_FLAGS' or event=='UNIT_FACTION' or event=='UNIT_LEVEL' or event=='UNIT_INVENTORY_CHANGED' then
        if event~='UNIT_INVENTORY_CHANGED' and ns.IntelWitness and ns.IntelWitness.Enabled() then return end
        if ns.AthenaEnrichment then ns.AthenaEnrichment.Opportunity(a,event=='UNIT_INVENTORY_CHANGED' and 'UNIT_INVENTORY_CHANGED' or event) end
    elseif event=='PLAYER_REGEN_ENABLED' then
        if ns.AthenaEnrichment then ns.AthenaEnrichment.Pump() end
    elseif event=='FRIENDLIST_UPDATE' then
        if ns.AthenaEnrichment then ns.AthenaEnrichment.RefreshVisible() end
    elseif event=='UNIT_NAME_UPDATE' then
        if ns.AthenaEnrichment and not (ns.IntelWitness and ns.IntelWitness.Enabled()) then ns.AthenaEnrichment.Opportunity(a,event) end
        -- Nameplate identity updates belong to the optional coalescing path.
        -- Routing them through generic 30-second encounters defeats that policy.
        if ns.CanRead(a) and not a:match('^nameplate') then C.ObserveUnit(a,event,ns.Checked(X.Call('UnitIsVisible',a))) end
    elseif event=='FACTION_STANDING_CHANGED' then local id=S.Integer(a,1,10000000);if id then X.Queue('reputation:'..id,function() I.Reputation(event,id) end) end
    elseif event=='UPDATE_FACTION' then X.Queue('reputation-baseline',I.ReputationBaseline)
    elseif event=='NEW_RECIPE_LEARNED' then local id=S.Integer(a,1,10000000);if id then X.Record('native_event',event,{recordType='recipe_learned',recipeID=id,level=S.Integer(b,1,1000)}) end
    elseif event=='TRADE_SKILL_ITEM_CRAFTED_RESULT' then
        local row=X.Table(a);local id=row and S.Integer(row.itemID,1,1000000000);local quantity=row and S.Integer(row.quantity,1,1000000)
        if id and quantity then X.Record('native_event',event,{recordType='native_craft_result',itemID=id,quantity=quantity,
            itemString=ns.ChronicleEvidence.ItemString(row.hyperlink,id)}) end
    end
end
X.Register(I,{'ADDON_LOADED','GROUP_ROSTER_UPDATE','PARTY_MEMBERS_CHANGED','PLAYER_TARGET_CHANGED','UPDATE_MOUSEOVER_UNIT','PLAYER_FOCUS_CHANGED',
    'INSPECT_READY','UNIT_NAME_UPDATE','NAME_PLATE_UNIT_ADDED','NAME_PLATE_UNIT_REMOVED','UNIT_FLAGS','UNIT_FACTION','UNIT_LEVEL','UNIT_INVENTORY_CHANGED','PLAYER_REGEN_ENABLED','FRIENDLIST_UPDATE'},'intel')
X.Register(I,{'FACTION_STANDING_CHANGED','UPDATE_FACTION','NEW_RECIPE_LEARNED','TRADE_SKILL_ITEM_CRAFTED_RESULT'},'chronicle')
