-- Allowlisted aggregate snapshots only. Never attach a log, chat, name, GUID,
-- note, player profile, location or historical record to a bug report.
local _,ns=...
local D={errors={},prepared={}};ns.RelayDiagnostics=D
function D.Capture(err)
    if not ns.CanRead(err) then return end
    if #err>8192 then err=err:sub(1,8192) end
    local file,line=err:match('OlympusChatWarden[/\\]([%w_]+%.lua):(%d+)')
    if not file then return end
    local key=file..':'..line
    for _,r in ipairs(D.errors) do if r.location==key then r.count=r.count+1;return end end
    if #D.errors<20 then D.errors[#D.errors+1]={location=key,count=1} end
end
function D.Initialize()
    if D.installed then return end;D.installed=true
    if type(geterrorhandler)=='function' and type(seterrorhandler)=='function' then
        local original=geterrorhandler()
        if type(original)=='function' then
            local reentry=false
            seterrorhandler(function(err,...)
                if not reentry then reentry=true;pcall(D.Capture,err);reentry=false end
                return original(err,...)
            end)
        end
    end
end
local function Flag(v) return v==true and 'yes' or v==false and 'no' or 'unavailable' end
function D.Snapshot()
    local S,C=ns.ChronicleStore,ns.Chronicle
    local lines={'diagnostics=1','version='..ns.VERSION,'initialization='..(ns.Initializing and 'in progress' or 'finished'),
        'startupFailureCount='..#(ns.StartupErrors or {}),'wardenErrorLocations='..#D.errors,
        'historyLoading='..Flag(S and S.loading~=nil and S.loading~=false),'historyBlocked='..Flag(S and S.blocked~=nil and S.blocked~=false),
        'recordingActive='..Flag(C and type(C.Active)=='function' and ns.SafeCall(C.Active)==true),'olympusConnected='..Flag(ns.OlympusConnection and ns.OlympusConnection.state=='connected'),
        'addonMessagingAPI='..Flag(type(C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage)=='function'),
        'performanceProfiling='..Flag(ns.WardenPerformance and ns.WardenPerformance.active==true)}
    for _,name in ipairs({'Chronicle','ChronicleActivities','WardenDossier','Shield','Mentions','ChatCapture','RelayTransport'}) do lines[#lines+1]='module.'..name..'='..Flag(type(ns[name])=='table') end
    if ns.Modules and ns.Modules.config then for _,id in ipairs(ns.Modules.order) do lines[#lines+1]='feature.'..id..'='..ns.Modules.State(id) end end
    for _,key in ipairs({'errors','dropped','gaps'}) do
        local value=C and C.diagnostics and C.diagnostics[key]
        lines[#lines+1]='collection.'..key..'='..(type(value)=='number' and value==value and tostring(math.floor(math.min(value,999999999))) or 'unavailable')
    end
    local J=ns.ChronicleStartupJournal
    if J then
        local h=J.Health()
        lines[#lines+1]='startup.accepted='..h.accepted..'; committed='..h.committed..'; pending='..h.pending..'; rejected='..h.rejected
        lines[#lines+1]='startup.integrity='..(h.error and 'attention' or h.pending>0 and 'pending' or 'no detected error')..'; handoffThisLogin='..Flag(h.lastHandoff~=nil)
    end
    local included=0
    for n,r in ipairs(D.errors) do
        local line='errorLocation.'..n..'='..r.location..' ('..math.min(r.count,99999)..')'
        if #table.concat(lines,'\n')+#line+1>1740 then break end
        lines[#lines+1]=line;included=n
    end
    if included<#D.errors then lines[#lines+1]='errorLocationsOmitted='..(#D.errors-included) end
    return table.concat(lines,'\n')
end
function D.Prepare()
    local text=D.Snapshot();D.prepared={[text]=true};return text
end
function D.Valid(v) return type(v)=='string' and #v<=1800 and D.prepared[v]==true end
