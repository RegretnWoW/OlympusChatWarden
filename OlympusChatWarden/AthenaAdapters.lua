-- Module-owned consumers. No historical replay or automatic sanction policy.
local _,ns=...
local A=ns.Athena
local signalled,signalOrder={},{}
A.Subscribe('alerts',{'decision','correction'},function(event)
    if not event.live or not ns.Notifications.Get('athena') then return end
    local context=A.GetPlayerContext('alerts',event.subject,'protection')
    if not context or not context.advisory then return end
    if signalled[event.subject] then return end
    if #signalOrder>=256 then signalled[table.remove(signalOrder,1)]=nil end
    signalled[event.subject]=true;signalOrder[#signalOrder+1]=event.subject
    ns.Print('Athena: a player in your local history has repeated spam-filter decisions. Review Messages for original decisions and corrections.')
    local causes={};for n=1,math.min(3,#context.sourceIDs) do causes[n]=context.sourceIDs[n] end
    A.RecordAction('alerts',{kind='local_advisory_notice',subject=event.subject},causes)
end)
-- Optional native activity notices. Only this login's accepted observations can
-- enter this queue; recovered history cannot replay alerts. Payloads remain in
-- the authoritative journal, with just identity markers held here until commit.
local pending,pendingCount,cooldowns,order={},0,{},{}
local function Choice(guid)
    if not A.Enabled('alerts') or not A.Enabled('intel') then return end
    -- The merged annotation is authoritative even while a journal writer has
    -- only a newer identity snapshot for this player.
    local p=ns.Chronicle.Profile(guid)
    if ns.Notifications.Get('athenaWatched') and p and p.personal and p.personal.watch then return 'watched' end
    if ns.Notifications.Get('athenaEarned') and ns.IntelPolicy.EarnedTier(guid)==1 then return 'earned' end
end
local function Deliver(guid,event,choice)
    local current=Choice(guid);if not current then return end;choice=current
    local now=ns.SafeNumber(ns.SafeCall(GetServerTime)) or 0
    if cooldowns[guid] and now>=cooldowns[guid] and now-cooldowns[guid]<300 then return end
    if not cooldowns[guid] then
        if #order>=256 then cooldowns[table.remove(order,1)]=nil end
        order[#order+1]=guid
    end
    cooldowns[guid]=now
    ns.Print('Athena: '..(choice=='watched' and 'a watched player' or 'an Important player')..' has a newly retained activity. Open IntelWarden for its dated source; this is not proof of proximity or misconduct.')
    A.RecordAction('alerts',{kind='retained_activity_notice',subject=guid,sourceEvidenceID=event.id})
end
function A.NativeNotice(e,status,generation)
    if not ns.Notifications.Get('athenaWatched') and not ns.Notifications.Get('athenaEarned') then return end
    -- Routine samples never produce a stream of notices.
    local key=e.details and e.details.recordType or e.kind
    if not ({group_roster=true,duel_session_end=true,duel_session_result=true,encounter_ended=true,public_achievement=true,important_player=true})[key] then return end
    local subjects={};if A.GUID(e.subject) then subjects[e.subject]=true end
    if e.kind=='group_roster' then for _,g in ipairs(e.details.members or {}) do if A.GUID(g) then subjects[g]=true end end end
    for guid in pairs(subjects) do local choice=Choice(guid);if choice then
        if status=='COMMITTED' then Deliver(guid,e,choice)
        elseif generation then
            local key=tostring(generation)..'/'..e.id;local row=pending[key]
            if row or pendingCount<512 then
                if not row then row={};pending[key]=row;pendingCount=pendingCount+1 end
                row[guid]=choice
            end
        end
    end end
end
function A.CommitLiveNotice(originalID,e,generation)
    local key=tostring(generation)..'/'..originalID;local row=pending[key]
    if not row then return end
    pending[key]=nil;pendingCount=pendingCount-1
    for guid,choice in pairs(row) do Deliver(guid,e,choice) end
end
local health={}
function A.ContributeHealth(module,summary)
    if module~='command' and module~='relay' or type(summary)~='table' then return false end
    local clean={}
    for _,key in ipairs({'enabled','errors','pending','received','sent','failures'}) do
        local n=ns.SafeNumber(summary[key]);if n and n>=0 then clean[key]=n end
    end
    health[module]=clean;return true
end
local GetHealth=A.GetHealth
function A.GetHealth(consumer)
    local out,why=GetHealth(consumer);if not out then return nil,why end
    out.modules=A.Copy(health);out.signalErrors=ns.SignalCore.errors
    if ns.AthenaIntakeContext then out.historyIntake=A.Copy(ns.AthenaIntakeContext.Health()) end
    return out
end
ns.WardenDB.GetHealth=A.GetHealth
local Changed=ns.RelayStore.Changed
function ns.RelayStore.Changed(...)
    local pending,received=0,0
    for _,r in ipairs(ns.RelayStore.db and ns.RelayStore.db.reports or {}) do
        if r.state=='pending' or r.state=='sending' then pending=pending+1 elseif r.state=='received' then received=received+1 end
    end
    A.ContributeHealth('relay',{pending=pending,received=received});return Changed(...)
end
