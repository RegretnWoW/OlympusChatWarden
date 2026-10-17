-- Own-character route evidence only. No map writes, unit scanning or sharing.
local _,ns=...
local C,S=ns.Chronicle,ns.ChronicleStore
local R={INTERVAL=2,MAX_POINTS=60,MAX_SPAN=120,STILL_SPAN=1800,diagnostics={attempts=0,samples=0,unavailable=0,chunks=0}}
ns.ChronicleRoute=R
local frame=CreateFrame('Frame');local r={}
local function Call(fn,...)
    if type(fn)~='function' then return end
    local ok,a,b,c,d=pcall(fn,...);if ok then return a,b,c,d end
end
function R.Position()
    local owner=C.Owner();if not owner then return nil,'identity-unavailable' end
    local at,clock=C.Stamp();local elapsed=C.Tick();if not at or not elapsed then return nil,'clock-unavailable' end
    local api=ns.Readable(C_Map) and type(C_Map)=='table' and C_Map or nil
    local map=S.Integer(api and Call(api.GetBestMapForUnit,'player'),1,10000000)
    local x,y
    if map and api and type(api.GetPlayerMapPosition)=='function' then
        local pos=Call(api.GetPlayerMapPosition,map,'player')
        if ns.Readable(pos) and (type(pos)=='table' or type(pos)=='userdata') and type(pos.GetXY)=='function' then x,y=Call(pos.GetXY,pos) end
        x,y=S.Number(x,0,1),S.Number(y,0,1)
        if not x or not y then x,y=nil,nil end
    end
    -- Preserve native return order; do not assume an axis transform on Forever.
    local a,b,z,world=Call(UnitPosition,'player')
    a,b,z,world=S.Number(a,-1000000000,1000000000),S.Number(b,-1000000000,1000000000),
        S.Number(z,-1000000000,1000000000),S.Integer(world,0,10000000)
    if not a or not b or not world then a,b,z,world=nil,nil,nil,nil end
    local afterMap=S.Integer(api and Call(api.GetBestMapForUnit,'player'),1,10000000)
    if C.Owner()~=owner or map~=afterMap then return nil,'context-changed-during-read' end
    if not x and not a then return nil,'coordinates-unavailable' end
    local facing=S.Number(Call(GetPlayerFacing),0,math.pi*2+.001)
    local speed=S.Number(Call(GetUnitSpeed,'player'),0,100000)
    return {format=1,mapID=x and map or nil,worldMapID=world,timeSource=clock,
        point={at,elapsed,x or false,y or false,a or false,b or false,z or false,facing or false,speed or false,at,elapsed,1}},nil
end
local function Flush()
    local batch=r.batch;if not batch or #batch.points==0 then return end;r.batch=nil
    local last=batch.points[#batch.points];local first=batch.points[1]
    local packed=ns.ChronicleCodec.Encode(batch);if not packed then return end
    local event=S.Append(r.owner,{kind='route_segment',source='checkpoint',session=r.session,at=last[10],elapsed=last[11],
        timeSource=r.timeSource,evidence='observed',location=r.location or {},
        details={segment=r.segment,pointCount=#batch.points,firstAt=first[1],lastAt=last[10],
            firstElapsed=first[2],lastElapsed=last[11],gapBefore=r.gapBefore==true,continued=r.continued==true,
            method='own-player coordinates; native axes preserved'},route=packed})
    if event then R.diagnostics.chunks=R.diagnostics.chunks+1;r.continued=true;r.gapBefore=false end
end
local function Gap(reason)
    Flush();r.segment=nil;r.continued=false;r.gapBefore=true
    if not r.missing or r.missing~=reason then
        C.Record('collection_gap','checkpoint',{reason=reason})
    end
    r.missing=reason
end
function R.Sample()
    if not C.Active() or r.suspended or r.owner~=C.Owner() then return end
    R.diagnostics.attempts=R.diagnostics.attempts+1
    local p,why=R.Position()
    if not p then R.diagnostics.unavailable=R.diagnostics.unavailable+1;Gap(why);return end
    local point=p.point;local elapsed=point[2]
    if r.lastTick and (elapsed<r.lastTick or elapsed-r.lastTick>R.INTERVAL*3) then Gap('unmeasured-sampling-gap') end
    if r.lastAt and point[1]<r.lastAt then Gap('wall-clock-regression');return end
    local place=C.Place()
    if r.hasPosition and (r.mapID~=p.mapID or r.worldMapID~=p.worldMapID
        or (r.location and (r.location.instanceID~=place.instanceID or r.location.zone~=place.zone or r.location.subzone~=place.subzone))) then Gap('map-or-instance-transition') end
    r.hasPosition=true;r.mapID=p.mapID;r.worldMapID=p.worldMapID
    r.missing=nil;r.lastTick=elapsed;r.lastAt=point[1];r.timeSource=p.timeSource
    if not r.segment then local c=S.Character(r.owner,false);r.segment=r.session..'/route'..((c and c.sequence or 0)+1) end
    if not r.batch then r.batch={format=1,mapID=p.mapID,worldMapID=p.worldMapID,points={}};r.location=place end
    local points=r.batch.points;local previous=points[#points];local same=previous~=nil
    if same then for j=3,9 do if previous[j]~=point[j] then same=false;break end end end
    if same then previous[10]=point[1];previous[11]=elapsed;previous[12]=previous[12]+1
    else points[#points+1]=point end
    R.diagnostics.samples=R.diagnostics.samples+1
    -- Repeated stationary samples become a run; moving samples stay separate.
    if #points>=R.MAX_POINTS or elapsed-points[1][2]>=(#points==1 and R.STILL_SPAN or R.MAX_SPAN) then Flush() end
end
function R.Suspend(reason)
    Gap(reason or 'suspended');r.suspended=true;r.lastTick=nil;r.lastAt=nil
end
function R.Resume(reason)
    if not C.Active() then return end
    r.suspended=false;r.gapBefore=true;r.segment=nil;r.continued=false;r.lastTick=nil
    R.Sample()
end
function R.Stop() Flush();r={};frame:SetScript('OnUpdate',nil) end
function R.Start()
    R.Stop();if not C.Active() then return end
    local owner=C.Owner();local c=S.Character(owner,false);if not c then return end
    r={owner=owner,session=c.currentSession,gapBefore=true};R.Sample()
    local elapsed=0;frame:SetScript('OnUpdate',function(_,delta)
        elapsed=elapsed+delta;if elapsed<R.INTERVAL then return end;elapsed=0
        local ok=pcall(R.Sample);if not ok then C.diagnostics.errors=C.diagnostics.errors+1 end
    end)
end
function R.Flush() Flush() end
function R.Pending() return r.batch and #r.batch.points or 0 end
