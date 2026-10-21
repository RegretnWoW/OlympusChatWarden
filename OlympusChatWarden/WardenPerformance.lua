-- Cooperative deadlines and voluntary session-only developer measurements.
-- No saved telemetry, timer, inspection or forced garbage collection.
local _,ns=...
local P={MS=2,active=false,stats={}};ns.WardenPerformance=P
function P.Wrap(object,key,name)
    local fn=object and object[key];if type(fn)~='function' then return end
    local function Finish(label,start,heap,...)
        P.End(label,start,1)
        local row=P.stats[label];local current=ns.SafeCall(collectgarbage,'count')
        if row and heap and ns.SafeNumber(current) then
            row.heapNet=(row.heapNet or 0)+current-heap;row.heapGrowth=(row.heapGrowth or 0)+math.max(0,current-heap)
        end
        return ...
    end
    object[key]=function(...)
        if not P.active then return fn(...) end
        local window=ns.Workspace and ns.Workspace.window
        local label=name..(window and window:IsShown() and ' / UI open' or ' / UI closed')
        if name=='capture pump' or name=='evidence pump' then label=label..(object.Pending()>0 and ' / queued' or ' / scheduler only') end
        local start=P.Now();local heap=ns.SafeCall(collectgarbage,'count')
        return Finish(label,start,ns.SafeNumber(heap),fn(...))
    end
end
function P.Now()
    if type(debugprofilestop)~='function' then return end
    local ok,n=pcall(debugprofilestop)
    if ok and ns.SafeNumber(n) and n>=0 then return n end
end
function P.Begin(limit)
    local now=P.Now();return now and now+math.min(P.MS,limit or P.MS),now
end
function P.Expired(deadline)
    if not deadline then return false end
    local now=P.Now();return now and now>=deadline or false
end
function P.End(name,start,units)
    if not P.active or not start then return end
    local now=P.Now();if not now or now<start then return end
    local row=P.stats[name]
    if not row then row={calls=0,total=0,max=0,units=0};P.stats[name]=row end
    local elapsed=now-start;row.calls=row.calls+1;row.total=row.total+elapsed;row.max=math.max(row.max,elapsed);row.units=row.units+(units or 0)
end
function P.Report()
    ns.Print('Warden profiling '..(P.active and 'running' or 'off')..'. Batch target: '..P.MS..' ms; an individual operation or GC can exceed it.')
    local memory=ns.SafeCall(collectgarbage,'count')
    if ns.SafeNumber(memory) then ns.Print(string.format('Whole UI Lua heap: %.1f MiB (all addons, not Warden alone).',memory/1024)) end
    local addons=C_AddOns
    ns.SafeCall(addons and addons.UpdateAddOnMemoryUsage or UpdateAddOnMemoryUsage)
    local own=ns.SafeCall(addons and addons.GetAddOnMemoryUsage or GetAddOnMemoryUsage,'OlympusChatWarden')
    if ns.SafeNumber(own) then ns.Print(string.format('Client-attributed Warden memory: %.1f MiB.',own/1024)) end
    local names={};for name in pairs(P.stats) do names[#names+1]=name end;table.sort(names)
    for _,name in ipairs(names) do local r=P.stats[name];ns.Print(string.format('%s: %d calls, %.2f ms total, %.3f ms/call, %.2f ms max, %d work units.',name,r.calls,r.total,r.total/math.max(1,r.calls),r.max,r.units))
        if r.heapGrowth then ns.Print(string.format('  Sampled heap growth %.1f KiB; net %.1f KiB. Includes GC/nested calls; not retained allocation.',r.heapGrowth,r.heapNet)) end
    end
    ns.Print('Timings are inclusive: nested measurements overlap. Profiling adds overhead while enabled; normal gameplay reads no diagnostic timers or heap samples.')
    local S=ns.ChronicleStore;local residency=S.Residency();local events,profiles,bytes=residency.loadedEvents,residency.loadedProfiles,residency.expandedBytes
    if not residency.validated then ns.Print('Retained ledger is not validated in this session; historical totals are unavailable.')
    else ns.Print(string.format('Loaded ledger: %d events, %d profiles; %.1f MiB structural estimate (not client memory attribution).',events,profiles,bytes/1048576)) end
    ns.Print(string.format('Character archives: %d loaded / %d still packed; %.1f MiB encoded packed strings; %d validation failures (originals kept).',residency.loadedCharacters,residency.packedCharacters,residency.packedBytes/1048576,residency.errors))
    local J=ns.ChronicleStartupJournal
    if J then ns.Print('Startup recovery: '..J.Count()..' local observations awaiting merge'..(J.Busy() and ' (recovering).' or '.')..(J.error and ' '..J.error or '')) end
    if S and S.LoadStatus then
        local l=S.LoadStatus();if l.pumps>0 then ns.Print(string.format('History validation: %d / %d chunks; %d worker calls with Warden closed, %d open; longest callback interval %.2f s. Background FPS setting: %s.',l.chunks,l.totalChunks,l.closedPumps,l.openPumps,l.longestInterval,tostring(l.backgroundFPS or 'unavailable'))) end
        if l.elapsed then ns.Print(string.format('Current-character validation duration: %.2f s.',l.elapsed)) end
        if l.sampledPeakKiB then ns.Print(string.format('Sampled validation peak: %.1f MiB whole UI Lua heap (only sampled with profiling enabled).',l.sampledPeakKiB/1024)) end
        local all=S.allCharacterLoad;if all and all.started and all.finished then ns.Print(string.format('Explicit all-character loading duration: %.2f s.',all.finished-all.started)) end
    end
    local seen,limit=ns.Chronicle.RuntimeCounts();ns.Print('Recent-player dedup: '..seen..' / '..limit..'; nameplate bindings: '..(ns.NameDisplays and ns.NameDisplays.BindingCount() or 0)..' / 100.')
    local spelling=ns.Spelling;local words,buckets=0,0
    for _ in pairs(spelling and spelling.words or {}) do words=words+1 end
    for _ in pairs(spelling and spelling.buckets or {}) do buckets=buckets+1 end
    ns.Print('Spelling: '..words..' expanded words / '..buckets..' suggestion buckets; '..tostring(ns.SpellingDictionary and ns.SpellingDictionary.data and #ns.SpellingDictionary.data or 0)..' raw dictionary bytes. Loads when an eligible field is used.')
    local startup=ns.ChronicleStartup and ns.ChronicleStartup.diagnostics or {}
    ns.Print('Startup preservation: '..(startup.merged or 0)..' merged; '..(startup.overflow or 0)..' overflow; '..(startup.discarded or 0)..' discarded. Coverage remains partial; see recorded gaps.')
    local A=ns.ChronicleActivities;local caches=0
    for _ in pairs(A and A.caches or {}) do caches=caches+1 end
    local done,total;if A then done,total=A.Progress() end
    ns.Print('Derived character caches: '..caches..'; index progress '..tostring(done or 0)..' / '..tostring(total or 0)..'.')
end
function P.Slash(text)
    local action=(text or ''):lower()
    if action=='start' then P.active=true;P.stats={};ns.Print('Warden profiling started for this login. Use /warden perf stop when finished.')
    elseif action=='stop' then P.Report();P.active=false;P.stats={}
    elseif action=='reset' then P.stats={};ns.Print('Warden profile measurements reset.')
    else P.Report();ns.Print('/warden perf start | status | stop | reset. Measurements stay in memory for this login only.') end
end
