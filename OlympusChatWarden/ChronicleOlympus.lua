-- Historical copies of ONLY the supported, permitted Olympus API's public data.
local _,ns=...
local C,S,L=ns.Chronicle,ns.ChronicleStore,ns.OlympusConnection
local O={diagnostics={snapshots=0,unchanged=0,rejected=0}};ns.ChronicleOlympus=O
local subscriptions={};local running=false;local lastRead;local pending=false;local frame=CreateFrame('Frame')
local function Eligible() return running and C.Active() and L.permission=='granted' and L.state=='connected' end
local function Same(a,b) return ns.ChronicleBackup.Encode(a)==ns.ChronicleBackup.Encode(b) end
function O.Save(kind,board,payload,source)
    if not Eligible() then return end
    local owner=C.Owner();local c=S.Character(owner,false);if not c then return end
    local rows={};local unavailable=payload==nil
    if not unavailable then
        if type(payload)~='table' or getmetatable(payload) then O.diagnostics.rejected=O.diagnostics.rejected+1;return end
        if kind=='profile' then
            local row=S.PublicRow(kind,payload);if not row then O.diagnostics.rejected=O.diagnostics.rejected+1;return end;rows.self=row
        else
            if not S.Array(payload,200) then O.diagnostics.rejected=O.diagnostics.rejected+1;return end
            for i,input in ipairs(payload) do
                if type(input)=='string' and kind=='ranking' then input={name=input,place=i} end
                local row=S.PublicRow(kind,input)
                if not row then O.diagnostics.rejected=O.diagnostics.rejected+1;return end
                local key=kind=='wanted' and row.guid or 'row:'..i
                key=key or 'row:'..i
                if not S.Text(key,200) or rows[key] then O.diagnostics.rejected=O.diagnostics.rejected+1;return end
                rows[key]=row
            end
        end
    end
    local key=owner..'/'..kind..'/'..board
    local old=S.db.olympusState[key];local at=C.Stamp()
    if not old and unavailable then
        -- No returned board is not a historical event. Retain capability state only.
        S.db.olympusState[key]={kind=kind,rows={},unavailable=true,checkedAt=at};return
    end
    if old and old.unavailable==unavailable and (unavailable or Same(old.rows,rows)) then
        old.checkedAt=at;O.diagnostics.unchanged=O.diagnostics.unchanged+1;return
    end
    local mode=unavailable and 'unavailable' or ((not old or old.unavailable) and 'full' or 'delta')
    local changed,removed={},{}
    if not unavailable then
        local ids={};for id in pairs(rows) do ids[#ids+1]=id end;table.sort(ids)
        for _,id in ipairs(ids) do if mode=='full' or not old.rows[id] or not Same(old.rows[id],rows[id]) then changed[#changed+1]={key=id,values=rows[id]} end end
        if mode=='delta' then for id in pairs(old.rows) do if not rows[id] then removed[#removed+1]=id end end;table.sort(removed) end
    end
    local id=c.currentSession..'/olympus'..(c.sequence+1)
    local parts=math.max(1,math.ceil(math.max(#changed,#removed)/3));local prepared={}
    for part=1,parts do
        local data={format=1,kind=kind,board=board,id=id,part=part,parts=parts,apiVersion=1,mode=mode,rows={},removed={}}
        for i=(part-1)*3+1,math.min(part*3,#changed) do data.rows[#data.rows+1]=changed[i] end
        for i=(part-1)*3+1,math.min(part*3,#removed) do data.removed[#data.removed+1]=removed[i] end
        local details={snapshotID=id,snapshotKind=kind,board=board,part=part,parts=parts,rowCount=#data.rows,
            removedCount=#data.removed,apiVersion=1,snapshotMode=mode}
        local _,clock=C.Stamp()
        local candidate={schema=S.VERSION,id=owner..':'..(c.sequence+part),kind='olympus_snapshot',source=source or 'control',
            session=c.currentSession,character=owner,at=at,elapsed=C.Tick(),timeSource=clock,evidence='observed',
            location={},details=details,snapshot=data}
        if not S.Event(candidate,owner) or S.Size(candidate)>12000 then O.diagnostics.rejected=O.diagnostics.rejected+1;return end
        prepared[part]=data
    end
    for _,data in ipairs(prepared) do
        local event=C.Record('olympus_snapshot',source or 'control',{snapshotID=id,snapshotKind=kind,board=board,part=data.part,
            parts=data.parts,rowCount=#data.rows,removedCount=#data.removed,apiVersion=1,snapshotMode=mode},nil,'observed',{},nil,data)
        if not event then O.diagnostics.rejected=O.diagnostics.rejected+1;return end
    end
    S.db.olympusState[key]={kind=kind,rows=unavailable and old and old.rows or rows,unavailable=unavailable,checkedAt=at,snapshotID=id}
    O.diagnostics.snapshots=O.diagnostics.snapshots+1
end
function O.Rankings(payload,source)
    if payload~=nil and (type(payload)~='table' or getmetatable(payload)) then O.diagnostics.rejected=O.diagnostics.rejected+1;return end
    local boards={slayers={'month','all','signed'},donors={'month','all'},church={'missionaries','apostles'},games={'arena','bones'}}
    for family,names in pairs(boards) do
        local value=payload and payload[family]
        if value~=nil and type(value)~='table' then O.diagnostics.rejected=O.diagnostics.rejected+1;return end
        for _,name in ipairs(names) do O.Save('ranking',family..'.'..name,value and value[name],source) end
    end
end
function O.Stop() running=false;pending=false;frame:SetScript('OnUpdate',nil) end
local function Read()
    if not Eligible() then return end
    local now=C.Tick();if not now or lastRead and now>=lastRead and now-lastRead<10 then pending=true;return end
    lastRead=now;pending=false
    local ok,wanted,why=L.Call('GetWanted');if ok and not why then O.Save('wanted','wanted',wanted,'control') elseif why=='busy' then pending=true end
    local ok,profile,why=L.Call('GetProfile');if ok and not why then O.Save('profile','self',profile,'control') elseif why=='busy' then pending=true end
    local ok,rankings,why=L.Call('GetRankings');if ok and not why then O.Rankings(rankings,'control') elseif why=='busy' then pending=true end
end
function O.Start()
    running=true;if not Eligible() then return end
    local callbacks={WANTED_CHANGED=function(_,rows) O.Save('wanted','wanted',rows,'WANTED_CHANGED') end,
        PROFILE_CHANGED=function(_,profile) O.Save('profile','self',profile,'PROFILE_CHANGED') end,
        RANKINGS_CHANGED=function(_,rows) O.Rankings(rows,'RANKINGS_CHANGED') end}
    for event,fn in pairs(callbacks) do
        if not subscriptions[event] then local ok,result=L.Call('On',event,fn);subscriptions[event]=ok and result==true end
    end
    -- Three initial reads, throttled across rapid toggles. Later updates are pushed.
    Read()
    frame:SetScript('OnUpdate',function()
        if pending and Eligible() and (not lastRead or C.Tick()>=lastRead+10) then Read() end
    end)
end
