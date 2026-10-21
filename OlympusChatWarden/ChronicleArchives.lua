-- On-demand character materialization. Opaque archives always remain in the
-- authoritative saved root until their private candidate passes validation.
local _,ns=...
local S=ns.ChronicleStore
local frame=CreateFrame('Frame')
local queue,queued,errors,job={},{},{},nil
local function Clock() return ns.SafeCall(GetTime) end
local Character=S.Character
function S.Character(owner,create)
    local c=Character(owner,false)
    if c and c.storageFormat~=nil then return nil,errors[owner] and 'failed' or 'packed' end
    if c then return c,'ready' end
    if create then return Character(owner,true) end
    return nil,S.blocked and 'blocked' or 'empty'
end
function S.ArchiveError(owner) return errors[owner] end
function S.CancelArchives()
    queue={};queued={};job=nil;frame:SetScript('OnUpdate',nil)
end
local Initialize=S.Initialize
function S.Initialize(...)
    S.CancelArchives();errors={};S.materializationRevision=0;S.allCharacterLoad=nil
    return Initialize(...)
end
function S.RequestCharacter(owner)
    if S.blocked or S.loading or not S.db then return nil,'blocked' end
    local c=S.db.characters[owner]
    if not c then return nil,'empty' end
    if c.storageFormat==nil then return c,'ready' end
    if errors[owner] then return nil,'failed' end
    if not queued[owner] then
        queue[#queue+1]={owner=owner,source=c,db=S.db};queued[owner]=true
        frame:SetScript('OnUpdate',function() S.PumpArchives() end);frame:Show()
    end
    return nil,'loading'
end
function S.RequireCharacters(owner)
    if S.blocked or not S.db then return false,'Saved history is unavailable.' end
    local pending=false
    local function Check(key)
        local _,status=S.RequestCharacter(key)
        if status=='failed' then return false,errors[key] end
        if status=='loading' or status=='blocked' then pending=true end
        return true
    end
    if owner then local ok,err=Check(owner);if not ok then return false,err end
    else
        for key in pairs(S.db.characters) do local ok,err=Check(key);if not ok then return false,err end end
        if pending and not S.allCharacterLoad then S.allCharacterLoad={started=Clock()} end
    end
    return not pending,pending and 'Loading requested character history; original archives are kept.' or nil
end
function S.PumpArchives()
    if S.loading or S.blocked or not S.db then return end
    if not job then
        job=table.remove(queue,1)
        if not job then frame:SetScript('OnUpdate',nil);return end
        local j=job
        j.thread=coroutine.create(function()
            local steps=0
            local clean=S.Normalize({schema=S.VERSION,characters={[j.owner]=j.source}},function(kind,n)
                if kind=='checksum blocks' then steps=steps+n;if steps<8 then return end end
                steps=0;coroutine.yield()
            end)
            return clean and clean.characters[j.owner],S.validationFailure
        end)
    end
    local j=job
    if S.db~=j.db or S.db.characters[j.owner]~=j.source then queued[j.owner]=nil;job=nil;return end
    local start=ns.WardenPerformance.Now();local budget=InCombatLockdown and InCombatLockdown() and 1 or 2
    for _=1,(start and 64 or 8) do
        local ok,c,reason=coroutine.resume(j.thread)
        if not ok or coroutine.status(j.thread)=='dead' then
            if ok and c then
                S.db.characters[j.owner]=c;S.materializationRevision=(S.materializationRevision or 0)+1
            else errors[j.owner]=ok and reason or 'Character history validation raised an error; original archive kept.' end
            if not c and not errors[j.owner] then errors[j.owner]='Character history validation failed; original archive kept.' end
            queued[j.owner]=nil;job=nil;S.revision=S.revision+1
            if ns.Workspace then ns.Workspace.Queue() end
            if S.allCharacterLoad and not S.allCharacterLoad.finished then
                local complete=true;for _,v in pairs(S.db.characters) do if v.storageFormat then complete=false;break end end
                if complete then S.allCharacterLoad.finished=Clock() end
            end
            return
        end
        if start and (ns.WardenPerformance.Now() or start)-start>=budget then break end
    end
end
local PrepareLogout=S.PrepareLogout
function S.PrepareLogout() S.CancelArchives();return PrepareLogout() end
local CancelLoad=S.CancelLoad
function S.CancelLoad() S.CancelArchives();return CancelLoad() end
function S.Residency()
    local saved=S.db or ns.DB and ns.DB.chronicle
    local out={loadedCharacters=0,packedCharacters=0,loadedEvents=0,loadedProfiles=0,expandedBytes=0,packedBytes=0,errors=0,validated=S.db~=nil}
    for _,c in pairs(type(saved)=='table' and type(saved.characters)=='table' and saved.characters or {}) do
        if type(c)=='table' then
        if c.storageFormat then
            out.packedCharacters=out.packedCharacters+1
            for _,chunks in ipairs({c.eventChunks or {},c.profileChunks or {}}) do for _,text in ipairs(chunks) do if type(text)=='string' then out.packedBytes=out.packedBytes+#text end end end
        else
            out.loadedCharacters=out.loadedCharacters+1;out.loadedEvents=out.loadedEvents+(type(c.events)=='table' and #c.events or 0);out.expandedBytes=out.expandedBytes+(S.Number(c.bytes,0) or 0)
            for _ in pairs(type(c.profiles)=='table' and c.profiles or {}) do out.loadedProfiles=out.loadedProfiles+1 end
        end
        end
    end
    for _ in pairs(errors) do out.errors=out.errors+1 end
    return out
end
