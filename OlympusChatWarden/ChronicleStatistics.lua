-- Native displayed statistics are dated observations, never invented events.
local _,ns=...
local C,S,X=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture
local T={MAX_CATEGORIES=256,MAX_STATISTICS=4096,READS_PER_STEP=4,MIN_INTERVAL=120,latest={},catalog={},categories={},diagnostics={reads=0,saved=0,unchanged=0,unavailable=0}}
ns.ChronicleStatistics=T
local epoch,owner,catalogKey,pending,lastRead=0,nil,nil,false,nil
local function Own() local value=C.Owner();return value end
local function ScopeFlag(flags)
    local account=S.Integer(_G.ACHIEVEMENT_FLAGS_ACCOUNT,1);local n=S.Integer(flags,0)
    if not n or not account then return end
    -- A metadata flag is retained as a flag, not promoted to GetStatistic scope.
    return math.floor(n/account)%2==1
end
local function Info(...)
    local fn=X.API('GetAchievementInfo');if not fn then return end
    local v={pcall(fn,...)};if not v[1] then return end
    return S.Integer(v[2],1,10000000),S.Text(v[3],144),S.Integer(v[10],0),X.Bool(v[16])
end
function T.Numeric(value)
    if not S.Text(value,256) or not value:match('^[0-9]+$') or #value>12 then return end
    return S.Integer(tonumber(value),0,1000000000000)
end
local function Stable(token) return epoch==token and X.Ready() and Own()==owner and not X.Busy() end
local function Context()
    local _,build=X.Call('GetBuildInfo')
    return S.Text(build,32),S.Text(X.Call('GetLocale'),16)
end
function T.Discover(token)
    local categories=X.Table(X.Call('GetStatisticsCategoryList'))
    if not categories then X.Mark('Native statistics','Unavailable: native statistics category reader did not return data');return false end
    local catalog,byID,groups={}, {},{}
    local categoryCount=#categories;local total=0;local complete=categoryCount<=T.MAX_CATEGORIES
    for index=1,math.min(categoryCount,T.MAX_CATEGORIES) do
        if not Stable(token) then return false end
        local category=S.Integer(categories[index],1,10000000)
        if category then
            local label,parent=X.Call('GetCategoryInfo',category)
            local count=S.Integer(X.Call('GetCategoryNumAchievements',category),0,100000)
            groups[#groups+1]={id=category,title=S.Text(label,144),parentID=S.Integer(parent,-1,10000000),reported=count}
            if count then for n=1,math.min(count,T.MAX_STATISTICS-total) do
                if not Stable(token) then return false end
                local id,name,flags,isStatistic=Info(category,n);total=total+1
                if id and isStatistic~=false and not byID[id] then
                    local row={id=id,categoryID=category,title=name,achievementFlags=flags,accountFlag=ScopeFlag(flags)}
                    catalog[#catalog+1]=row;byID[id]=row
                end
                if total%T.READS_PER_STEP==0 then X.Yield() end
            end
            else complete=false end
            if total>=T.MAX_STATISTICS then complete=false;break end
        else complete=false end
        X.Yield()
    end
    if not Stable(token) then return false end
    T.catalog=catalog;T.byID=byID;T.categories=groups;T.catalogComplete=complete
    return true
end
local function Signature(d)
    return ns.ChronicleBackup.Encode({statisticID=d.statisticID,categoryID=d.categoryID,title=d.title,displayValue=d.displayValue,
        nativeScope=d.nativeScope,accountFlag=d.accountFlag,locale=d.locale,build=d.build,achievementFlags=d.achievementFlags})
end
function T.Read(row,source,token)
    if not Stable(token) then return end
    local value=X.Call('GetStatistic',row.id);T.diagnostics.reads=T.diagnostics.reads+1
    value=S.Text(value,256)
    if not value or value=='--' or value=='-' then T.diagnostics.unavailable=T.diagnostics.unavailable+1;row.available=false;return end
    row.available=true;row.checkedAt=C.Stamp()
    local build,locale=Context()
    local data={recordType='statistic_observed',statisticID=row.id,categoryID=row.categoryID,title=row.title,
        displayValue=value,numericValue=T.Numeric(value),nativeScope='unknown',accountFlag=row.accountFlag,achievementFlags=row.achievementFlags,
        build=build,locale=locale,observedAt=C.Stamp()}
    local before=T.latest[row.id];local signature=Signature(data)
    if before and before.signature==signature then T.diagnostics.unchanged=T.diagnostics.unchanged+1;return end
    -- A lower number is just a lower observed value: cause/reset/scope unknown.
    if before and before.event.details.numericValue and data.numericValue then data.valueDecreased=data.numericValue<before.event.details.numericValue end
    if not Stable(token) then return end
    local e=X.Record('native_event',source or 'checkpoint',data,nil,false)
    if e then T.latest[row.id]={event=e,signature=signature};T.diagnostics.saved=T.diagnostics.saved+1 end
end
local function ReadAll(token,source)
    T.reading=true
    for n,row in ipairs(T.catalog) do
        if not Stable(token) then T.reading=false;return end
        T.Read(row,source,token)
        if n%T.READS_PER_STEP==0 then X.Yield() end
    end
    lastRead=C.Tick()
    T.reading=false
    X.Mark('Native statistics',#T.catalog..' native IDs discovered; '..T.diagnostics.saved..' dated observations saved this session. Scope and native freshness remain unverified.')
end
function T.Request(source)
    if not X.Ready() or not T.ready then return end
    pending=source or 'checkpoint'
    if T.reading then return end
    local now=C.Tick();if not now or lastRead and now-lastRead<T.MIN_INTERVAL then return end
    local token=epoch;local requested=pending;pending=false;lastRead=now
    X.Queue('native-statistics-read',function() ReadAll(token,requested) end,true)
end
function T.Pump()
    if pending and T.ready and not X.Busy() then T.Request(pending) end
end
function T.Start()
    epoch=epoch+1;local token=epoch;owner=Own();T.latest={};T.ready=false;T.reading=false;pending=false;lastRead=nil
    T.diagnostics={reads=0,saved=0,unchanged=0,unavailable=0}
    if not X.API('GetStatistic') or not X.API('GetStatisticsCategoryList') or not X.API('GetCategoryNumAchievements') or not X.API('GetAchievementInfo') then
        X.Mark('Native statistics','Unavailable: one or more native statistic APIs are missing');return
    end
    local build,locale=Context();local key=owner..'/'..tostring(build)..'/'..tostring(locale)
    X.Queue('native-statistics-start',function()
        local c=S.Character(owner,false);if not c then return end
        for n,e in ipairs(c.events) do
            if not Stable(token) then return end
            if e.details.recordType=='statistic_observed' and e.details.statisticID then
                T.latest[e.details.statisticID]={event=e,signature=Signature(e.details)}
            end
            if n%128==0 then X.Yield() end
        end
        if catalogKey~=key then if not T.Discover(token) then return end;catalogKey=key end
        if not Stable(token) then return end
        T.ready=true;ReadAll(token,'control')
    end,true)
end
function T.Stop() epoch=epoch+1;owner=nil;T.latest={};T.ready=false;T.reading=false;pending=false;lastRead=nil end
function T.Get(id)
    local row=T.byID and T.byID[id];local saved=T.latest[id]
    return saved and saved.event,row and row.available==true or false,row and row.checkedAt
end
function T.Inventory()
    return {categories=T.categories,statistics=T.catalog,complete=T.catalogComplete==true,scopeVerified=false,liveVerified=false}
end
function T.Print()
    ns.Print('Native statistics: '..#T.categories..' categories; '..#T.catalog..' IDs. Character/account scope, resets and update latency are unverified.')
    for _,row in ipairs(T.categories) do ns.Print('Category '..row.id..': '..(row.title or 'Unknown title')..'; native entries '..tostring(row.reported or 'unknown')) end
    ns.Print('Values are native displayed strings. Commas, decimals and units are not guessed. Saved totals remain separate from Warden encounters and duel records.')
end
function T.PrintIDs(page)
    page=S.Integer(page,1,1000) or 1;local first=(page-1)*50+1
    ns.Print('Native statistic IDs, page '..page..'. Saved values are dated observations; native scope remains unknown.')
    for n=first,math.min(first+49,#T.catalog) do
        local row=T.catalog[n];local saved=T.latest[row.id]
        ns.Print(row.id..' / category '..row.categoryID..' / '..(row.title or 'Unknown title')..' / '..(saved and saved.event.details.displayValue or 'Unavailable'))
    end
    ns.Print('Catalog has '..#T.catalog..' IDs. /warden chronicle statistics ids PAGE browses another fifty.')
end
function T.Handle(event)
    if not X.Ready() then return end
    T.Request(event)
end
X.Register(T,{'ACHIEVEMENT_EARNED','PLAYER_LEVEL_UP','QUEST_TURNED_IN','PVP_MATCH_COMPLETE','DUEL_FINISHED','ENCOUNTER_END','BOSS_KILL','PLAYER_PVP_KILLS_CHANGED'})
