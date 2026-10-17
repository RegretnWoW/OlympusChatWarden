-- Important friendly and hostile players; no passerby inspect sweep.
local _,ns=...
local C,S,X,L=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture,ns.ChronicleLoadout
local I={};ns.ChronicleEncounters=I
local important,pending,requests,reputation,lastRequest,epoch,hooked={},nil,{}, {},-100,0,false
local function Units()
    local units={'target','focus','mouseover'}
    for i=1,4 do units[#units+1]='party'..i end
    for i=1,40 do units[#units+1]='raid'..i end
    return units
end
local function Record(source,data,guid) return X.Record('important_player',source,data,guid,false) end
function I.Important(unit,source,reason)
    if not X.Ready() or X.Busy() then return end
    local guid=S.GUID(X.Call('UnitGUID',unit));if not guid or guid==S.GUID(X.Call('UnitGUID','player')) then return end
    local old=important[guid];local now=C.Tick();if not now then return end
    if old and old.reason==reason and now-old.tick<60 then old.unit=unit;return guid end
    local name=S.Text(X.Call('UnitName',unit),144)
    if not name or S.GUID(X.Call('UnitGUID',unit))~=guid then return end
    C.ObserveUnit(unit,source,ns.Checked(X.Call('UnitIsVisible',unit)))
    local appearance=L.Appearance(unit,guid,source);local at=C.Stamp()
    local event=Record(source,{name=name,relationship=reason,unitVisible=X.Bool(X.Call('UnitIsVisible',unit)),
        appearanceRef=appearance,appearanceObservedAt=appearance and at,inspection='not yet available'},guid)
    important[guid]={unit=unit,reason=reason,tick=now,source=source,attempts=0,event=event and event.id}
    requests[#requests+1]=guid
    return guid
end
function I.ImportantGUID(guid,source,reason)
    if X.Busy() then X.Queue('important:'..guid,function() I.ImportantGUID(guid,source,reason) end);return end
    for _,unit in ipairs(Units()) do if S.GUID(X.Call('UnitGUID',unit))==guid then return I.Important(unit,source,reason) end end
    X.Mark('Important players','Encounter saved; no current unit for detailed inspection')
end
function I.IsImportant(guid) return important[guid]~=nil end
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
    if not X.Ready() or X.Busy() then return end
    local guid=S.GUID(X.Call('UnitGUID',unit));if not guid then return end
    local p=C.Profile(guid)
    if p and p.personal and p.personal.watch then return I.Important(unit,source,'personal bookmark') end
    local name=S.Text(X.Call('UnitName',unit),144)
    local friend=name and X.Table(X.Call('C_FriendList.GetFriendInfo',name))
    -- Ordinary character friendship is GUID-bound. No Battle.net lookup, private
    -- notes, friend-list census or name-only relationship merge.
    if friend and S.GUID(friend.guid)==guid then return I.Important(unit,source,'encountered friend') end
    local wanted=ns.Wanted and X.Table(ns.Wanted.byGUID)
    if wanted and wanted[guid] then return I.Important(unit,source,'Wanted encounter') end
end
local function InstallHooks()
    if hooked or type(hooksecurefunc)~='function' or not X.API('NotifyInspect') then return end
    -- Observe global inspect ownership without replacing any client function.
    hooksecurefunc('NotifyInspect',function()
        epoch=epoch+1
        if pending and I.requesting then pending.epoch=epoch else pending=nil;lastRequest=C.Tick() or lastRequest end
    end)
    if X.API('ClearInspectPlayer') then hooksecurefunc('ClearInspectPlayer',function() epoch=epoch+1;pending=nil end) end
    hooked=true
end
function I.InspectPump()
    if not X.Ready() or X.Busy() then return end
    local now=C.Tick();if not now then return end
    if pending then
        if now-pending.at<8 then return end
        X.Mark('Inspection','Timed out; encounter retained with partial details');pending=nil
    end
    if not hooked or now-lastRequest<5 then return end
    if InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown() then return end
    local guid=table.remove(requests,1);local v=guid and important[guid];if not v then return end
    if S.GUID(X.Call('UnitGUID',v.unit))~=guid or X.Bool(X.Call('CanInspect',v.unit,true))~=true then
        X.Mark('Inspection','Important player currently unavailable; no substitute identity');return
    end
    local fn=X.API('NotifyInspect');if not fn then return end
    pending={guid=guid,unit=v.unit,at=now,epoch=epoch,reason=v.reason}
    I.requesting=true;local ok=pcall(fn,v.unit);I.requesting=false;lastRequest=now
    if not ok then pending=nil;X.Mark('Inspection','Normal inspection unavailable') end
end
function I.InspectReady(guid)
    guid=S.GUID(guid);if not guid then return end
    local p=pending
    if not p or p.guid~=guid or p.epoch~=epoch or S.GUID(X.Call('UnitGUID',p.unit))~=guid or X.Busy() then return end
    local function owned() return pending==p and p.epoch==epoch end
    local gear=L.Gear(p.unit,guid,'INSPECT_READY',owned);local appearance=L.Appearance(p.unit,guid,'INSPECT_READY')
    local traits
    -- Shared targetless trait cache is read only while this owned response and
    -- target GUID remain stable. Never request another identity by display name.
    if X.Bool(X.Call('C_Traits.HasValidInspectData'))==true then
        local export=S.Text(X.Call('C_Traits.GenerateInspectImportString',p.unit),5000)
        if export then traits=X.Store('traits',{guid=guid,exportString=export},'INSPECT_READY') end
    end
    if pending~=p or p.epoch~=epoch or S.GUID(X.Call('UnitGUID',p.unit))~=guid then return end
    local at=C.Stamp()
    Record('INSPECT_READY',{relationship=p.reason,inspection=gear and 'partial readable inspection' or 'gear unavailable',
        gearRef=gear,gearObservedAt=gear and at,traitRef=traits,traitObservedAt=traits and at,
        appearanceRef=appearance,appearanceObservedAt=appearance and at,observedAt=at,partial=true},guid)
    pending=nil;X.Mark('Inspection','GUID-matched normal inspect response saved; appearance may be incomplete')
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
    important={};pending=nil;requests={};reputation={};InstallHooks()
    X.Queue('important-group',function() I.Group('GROUP_ROSTER_UPDATE') end)
    X.Queue('reputation-baseline',I.ReputationBaseline)
    X.Mark('Inspection',hooked and 'Normal inspection enabled only for important players' or 'Passive mode: inspect ownership hooks unavailable')
end
function I.Stop() important={};pending=nil;requests={};reputation={} end
function I.Handle(event,a,b)
    if event=='GROUP_ROSTER_UPDATE' or event=='PARTY_MEMBERS_CHANGED' then X.Queue('important-group',function() I.Group(event) end)
    elseif event=='PLAYER_TARGET_CHANGED' then I.Observe('target',event)
    elseif event=='UPDATE_MOUSEOVER_UNIT' then I.Observe('mouseover',event)
    elseif event=='PLAYER_FOCUS_CHANGED' then I.Observe('focus',event)
    elseif event=='INSPECT_READY' then I.InspectReady(a)
    elseif event=='UNIT_NAME_UPDATE' then
        if ns.CanRead(a) then C.ObserveUnit(a,event,ns.Checked(X.Call('UnitIsVisible',a))) end
    elseif event=='FACTION_STANDING_CHANGED' then local id=S.Integer(a,1,10000000);if id then X.Queue('reputation:'..id,function() I.Reputation(event,id) end) end
    elseif event=='UPDATE_FACTION' then X.Queue('reputation-baseline',I.ReputationBaseline)
    elseif event=='NEW_RECIPE_LEARNED' then local id=S.Integer(a,1,10000000);if id then X.Record('native_event',event,{recordType='recipe_learned',recipeID=id,level=S.Integer(b,1,1000)}) end
    elseif event=='TRADE_SKILL_ITEM_CRAFTED_RESULT' then
        local row=X.Table(a);local id=row and S.Integer(row.itemID,1,1000000000);local quantity=row and S.Integer(row.quantity,1,1000000)
        if id and quantity then X.Record('native_event',event,{recordType='native_craft_result',itemID=id,quantity=quantity,
            itemString=ns.ChronicleEvidence.ItemString(row.hyperlink,id)}) end
    end
end
X.Register(I,{'GROUP_ROSTER_UPDATE','PARTY_MEMBERS_CHANGED','PLAYER_TARGET_CHANGED','UPDATE_MOUSEOVER_UNIT','PLAYER_FOCUS_CHANGED',
    'INSPECT_READY','UNIT_NAME_UPDATE','FACTION_STANDING_CHANGED','UPDATE_FACTION','NEW_RECIPE_LEARNED','TRADE_SKILL_ITEM_CRAFTED_RESULT'})
