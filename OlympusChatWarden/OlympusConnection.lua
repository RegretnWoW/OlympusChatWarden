-- Olympus's supported, consented API. Keep one handle and session-only profile data.
local addon,ns=...
local C={state='missing',surfaceState='waiting',modern=false,listeners={}}
ns.OlympusConnection=C
local handle,api,attempted,nextAttempt,nextRead,queued,reading
local roles={king='King',councillor='High Councillor',steward='Steward',treasurer='Treasurer',
    guildmaster='Guild Master',officer='Officer',member='Member'}
local reasons={missing='Older Olympus: using the local guild-name check.',
    restart='Enable Olympus 1.2.4 or later and fully restart WoW so its API can load.',
    pending='Open /oly privacy and choose Yes for Olympus ChatWarden.',
    refused='Olympus data access is declined. Choose Yes in /oly privacy to enable protection.',
    waiting='Waiting for Olympus to provide this character\'s membership.',
    busy='Olympus is busy. Connection will retry shortly.',
    error='Olympus could not answer. Protection is paused until membership can be checked.',
    unsupported='This Olympus API version needs a compatible ChatWarden update.',
    registration='Olympus could not connect ChatWarden. Restart WoW and check again.',
    connected='Membership confirmed by Olympus.',
    ['not-member']='Olympus does not recognize this character as a member. Protection is disabled.'}
function C.Subscribe(fn) if type(fn)=='function' then C.listeners[#C.listeners+1]=fn end end
function C.Plain(value,limit)
    if not ns.CanRead(value) or #value>1024 then return nil end
    value=value:gsub('|H.-|h(.-)|h','%1'):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')
        :gsub('|T.-|t',''):gsub('|A.-|a',''):gsub('|',''):gsub('[%z\1-\31\127]',' ')
        :gsub('^%s+',''):gsub('%s+$','')
    return value~='' and ns.Reports.Clip(value,limit or 128) or nil
end
local function Changed()
    if queued then return end;queued=true
    local function Notify()
        queued=false
        if not ns.DB or ns.Initializing then return end
        if ns.Membership then ns.Membership.Refresh() end
        for _,fn in ipairs(C.listeners) do
            local ok,err=pcall(fn)
            if not ok and geterrorhandler then pcall(geterrorhandler(),err) end
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0,Notify) else Notify() end
end
local function State(value,detail)
    local changed=C.state~=value or C.detail~=detail
    C.state,C.detail=value,detail
    if changed then Changed() end
end
function C.Reason() return reasons[C.state] or reasons.error end
function C.StatusText()
    return ({connected='Olympus Connected',pending='Permission Needed',refused='Access Declined',
        ['not-member']='Membership Unconfirmed',missing='Legacy Connection',unsupported='Update Needed',
        busy='Olympus Busy',waiting='Checking Membership',restart='Restart WoW',registration='Connection Failed'})[C.state]
        or 'Connection Unavailable'
end
function C.Role(value) return roles[value] or 'Member' end
function C.Profile()
    if C.permission~='granted' or not C.profile then return nil end
    local copy={};for key,value in pairs(C.profile) do copy[key]=value end;return copy
end
local function Take(profile)
    if not ns.Readable(profile) or type(profile)~='table' or not ns.Readable(profile.member)
        or type(profile.member)~='boolean' then C.profile=nil;State('error','invalid-profile');return false end
    local copy={member=profile.member}
    if profile.member then
        for _,key in ipairs({'name','guild','rank','title'}) do copy[key]=C.Plain(profile[key],key=='name' and 144 or 128) end
        copy.role=ns.CanRead(profile.role) and roles[profile.role] and profile.role or 'member'
        -- An honor's frame key is not a texture path. It is intentionally not loaded as artwork.
    end
    C.profile=copy
    State(copy.member and 'connected' or 'not-member')
    Changed();return true
end
function C.Call(method,...)
    if not handle or type(handle[method])~='function' then return false,nil,'unavailable' end
    local ok,a,b=pcall(handle[method],handle,...)
    return ok,a,b
end
local function Permission()
    local ok,status=C.Call('Status')
    if not ok or not ns.CanRead(status) or (status~='granted' and status~='pending' and status~='refused') then
        C.permission=nil;C.profile=nil;State('error','status');return false
    end
    if C.permission~=status then C.profile=nil;nextRead=nil;C.permission=status;Changed() end
    if status~='granted' then C.profile=nil;State(status);return false end
    return true
end
function C.Ensure()
    local current=_G.OlympusAPI
    if not ns.Readable(current) or type(current)~='table' then
        local metadata=C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
        local version=ns.SafeCall(metadata,'Olympus','Version')
        local major,minor,patch
        if ns.CanRead(version) then major,minor,patch=version:match('^(%d+)%.(%d+)%.(%d+)') end
        major,minor,patch=tonumber(major),tonumber(minor),tonumber(patch)
        C.modern=major~=nil and (major>1 or major==1 and (minor>2 or minor==2 and patch>=4)) or false
        C.permission=nil;C.profile=nil;State(C.modern and 'restart' or 'missing');return false
    end
    C.modern=true
    if not ns.Readable(current.VERSION) or current.VERSION~=1 or type(current.Register)~='function' then
        C.profile=nil;State('unsupported');return false
    end
    if api~=current then
        api=current;handle=nil;attempted=nil;nextAttempt=nil;C.profile=nil;C.permission=nil
    end
    if handle then return true end
    local now=ns.SessionTime()
    if attempted and (not nextAttempt or now<nextAttempt) then return false end
    attempted=true
    local ok,result,why=pcall(api.Register,addon)
    if not ok or not ns.Readable(result) or type(result)~='table' then
        C.profile=nil;State('registration',ns.SafeString(why,64) or 'failed')
        -- A missing privacy module can become ready after a load event. Other failures
        -- require a new session; never repeatedly register a name already taken.
        nextAttempt=why=='consent' and now+5 or nil;return false
    end
    handle=result;nextAttempt=nil
    C.Call('On','PERMISSION_CHANGED',function()
        C.profile=nil;nextRead=nil;C.Refresh(true);Changed()
    end)
    C.Call('On','PROFILE_CHANGED',function(_,profile)
        if Permission() then nextRead=ns.SessionTime()+5;Take(profile) end
    end)
    C.Call('On','WANTED_CHANGED',function(_,rows)
        if Permission() and ns.Wanted then ns.Wanted.Receive(rows) end
    end)
    return true
end
function C.Refresh(force)
    if reading then return end
    if not C.Ensure() or not Permission() then return end
    local now=ns.SessionTime()
    if not force and (C.profile or nextRead and now<nextRead) then return end
    reading=true;nextRead=now+5
    local ok,profile,why=C.Call('GetProfile')
    reading=false
    if ok and profile~=nil then return Take(profile) end
    C.profile=nil
    if why=='pending' or why=='refused' then C.permission=why;State(why)
    else State(ok and why=='busy' and 'busy' or 'error',ns.SafeString(why,64)) end
end
function C.Invalidate()
    C.profile=nil;nextRead=nil
    if C.modern and C.permission=='granted' then State('waiting') end
end
function C.Has(feature)
    if not handle or not api or type(api.Has)~='function' then return false end
    local ok,yes=pcall(api.Has,feature);return ok and yes==true
end
function C.HasSurface() return C.Has('ui.surface') end
function C.RegisterSurface(spec)
    if not C.HasSurface() then return false,'unavailable' end
    local ok,result,why=C.Call('RegisterSurface',spec)
    C.surfaceState=ok and result==true and 'ready' or ns.SafeString(why,64) or 'failed'
    Changed();return ok and result==true,C.surfaceState
end
function C.SurfaceReady() return C.surfaceState=='ready' end
function C.OpenSurface()
    if InCombatLockdown and InCombatLockdown() then return false,'Open Olympus after combat.' end
    local ok,result,why=C.Call('OpenSurface')
    if ok and result==true then return true end
    return false,why=='hidden' and 'The Olympus page is not available yet.' or 'The Olympus page could not open. Use /ocw after checking your connection.'
end
function C.RefreshSurface()
    if C.SurfaceReady() and not (InCombatLockdown and InCombatLockdown()) then C.Call('RefreshSurface') end
end
