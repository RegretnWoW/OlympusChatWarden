-- Own historical baselines. No historical turn-ins, rewards, visits or dates
-- are synthesized. These records use the canonical Chronicle ledger only.
local _,ns=...
local C,S,X=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture
local H={types={quest_completed_baseline=true,achievement_date_observed=true,played_observed=true,recipe_known_baseline=true}}
ns.ChronicleHistory=H
local owner,known,npc,playedRequested=nil,{},nil,nil
local function key(d)
    return d.recordType..':'..tostring(d.questID or d.achievementID or d.recipeID or '')
end
local function calendar(y,m,d)
    if not S.Integer(y,2004,9999) or not S.Integer(m,1,12) or not S.Integer(d,1,31) then return false end
    local days=({31,28,31,30,31,30,31,31,30,31,30,31})[m]
    if m==2 and (y%400==0 or y%4==0 and y%100~=0) then days=29 end
    return d<=days
end
function H.Valid(d)
    if d.recordType=='quest_completed_baseline' then return S.Integer(d.questID,1,10000000) and d.baseline==true and d.scope=='native completed list; character/account attribution unknown' end
    if d.recordType=='recipe_known_baseline' then return S.Integer(d.recipeID,1,10000000) and d.baseline==true and d.known==true and d.scope=='own open profession view' end
    if d.recordType=='played_observed' then return S.Integer(d.totalPlayed,0,100000000000) and S.Integer(d.levelPlayed,0,d.totalPlayed) and d.scope=='own native played response' end
    if d.recordType=='achievement_date_observed' then
        local y,m,dn=d.calendarYear,d.calendarMonth,d.calendarDay
        return S.Integer(d.achievementID,1,10000000) and d.baseline==true and d.scope=='native official calendar date; ownership separately qualified'
          and ((y==nil and m==nil and dn==nil) or calendar(y,m,dn))
          and (d.wasEarnedByMe==nil or type(d.wasEarnedByMe)=='boolean') and (d.accountFlag==nil or type(d.accountFlag)=='boolean')
    end
    return false
end
function H.Provenance(e)
    if e.subject~=nil then return false end
    local r=e.details.recordType
    if r=='played_observed' then return e.source=='TIME_PLAYED_MSG' end
    if r=='quest_completed_baseline' then return e.source=='control' end
    if r=='achievement_date_observed' then return e.source=='control' or e.source=='ACHIEVEMENT_EARNED' end
    if r=='recipe_known_baseline' then return e.source=='TRADE_SKILL_SHOW' or e.source=='TRADE_SKILL_LIST_UPDATE' end
    return false
end
local function record(d,source)
    if not X.Ready() or C.Owner()~=owner then return end
    local now=C.Stamp();if not now then return end
    local k=key(d);if d.baseline and known[k] then return end
    d.firstObservedAt=now
    local t={basis=d.baseline and 'baseline' or 'sample',precision=d.calendarDay and 'day' or 'unknown',sampledAt=now,firstObservedAt=now}
    local e=C.Record('native_event',source or 'control',d,nil,'observed',nil,nil,nil,nil,nil,nil,t)
    if e and d.baseline then known[k]=e.at end
    return e
end
function H.Completed(id,at) known['quest_completed_baseline:'..id]=at or C.Stamp() end
function H.Quests()
    local ids=X.Table(X.Call('C_QuestLog.GetAllCompletedQuestIDs'))
    if not ids or not S.Array(ids,50000) then X.Mark('Completed quests','Unavailable or unreadable; absence is not eligibility');return end
    for i,id in ipairs(ids) do
        if S.Integer(id,1,10000000) then record({recordType='quest_completed_baseline',questID=id,baseline=true,scope='native completed list; character/account attribution unknown'}) end
        if i%16==0 then X.Yield() end
    end
    X.Mark('Completed quests','First observed completed; original completion time and rewards unknown')
end
function H.Achievement(id,source)
    local fn=X.API('GetAchievementInfo');if not fn then return end
    local v={pcall(fn,id)}
    if not v[1] or not S.Integer(v[2],1) or v[2]~=id or X.Bool(v[5])~=true or X.Bool(v[16])==true then return end
    local month,day,year=S.Integer(v[6],1,12),S.Integer(v[7],1,31),S.Integer(v[8],0,9999)
    if year and year<100 then year=year+2000 end
    if not calendar(year,month,day) then year=nil;month=nil;day=nil end
    local flags=S.Integer(v[10],0);local accountMask=ns.Readable(ACHIEVEMENT_FLAGS_ACCOUNT) and S.Integer(ACHIEVEMENT_FLAGS_ACCOUNT,1)
    local account;if flags and accountMask then account=math.floor(flags/accountMask)%2==1 end
    record({recordType='achievement_date_observed',achievementID=id,name=S.Text(v[3],144),baseline=true,
        calendarYear=year,calendarMonth=month,calendarDay=day,achievementFlags=flags,accountFlag=account,
        wasEarnedByMe=X.Bool(v[14]),earnedBy=S.Text(v[15],128),scope='native official calendar date; ownership separately qualified'},source)
end
function H.Achievements()
    local categories=X.Table(X.Call('GetCategoryList'));if not categories or not S.Array(categories,5000) then X.Mark('Achievement dates','Achievement catalog unavailable');return end
    local read=0
    for _,category in ipairs(categories) do
        local count=S.Integer(X.Call('GetCategoryNumAchievements',category),0,5000)
        for i=1,count or 0 do
            local id=S.Integer(X.Call('GetAchievementInfo',category,i),1,10000000)
            if id then H.Achievement(id,'control') end
            read=read+1;if read>=50000 then X.Mark('Achievement dates','Partial catalog; safety bound reached');return end
            X.Yield()
        end
    end
    X.Mark('Achievement dates','Official calendar dates only; no exact hour or inferred personal completion')
end
function H.Recipes(source)
    local ids=X.Table(X.Call('C_TradeSkillUI.GetAllRecipeIDs'));if not ids or not S.Array(ids,30000) then X.Mark('Known recipes','Native profession view unavailable');return end
    for _,id in ipairs(ids) do
        local info=S.Integer(id,1,10000000) and X.Table(X.Call('C_TradeSkillUI.GetRecipeInfo',id))
        if info and X.Bool(info.learned)==true then record({recordType='recipe_known_baseline',recipeID=id,known=true,baseline=true,scope='own open profession view'},source) end
        X.Yield()
    end
end
function H.QuestNPC(data)
    local now=C.Stamp()
    if npc and npc.owner==C.Owner() and npc.questID==data.questID and now and now>=npc.at and now-npc.at<=30 then
        data.npcGUID=npc.guid;data.npcID=npc.id;data.npcObservedAt=npc.at
    end
    npc=nil
end
function H.Start()
    owner=C.Owner();known={};npc=nil
    X.Queue('historical-baselines',function()
        local c=S.WriterCharacter(owner,false)
        for i,e in ipairs(c and c.events or {}) do
            local d=e.details
            if H.types[d.recordType] and d.baseline then known[key(d)]=e.at
            elseif e.kind=='quest_turnin' then H.Completed(d.questID,e.at) end
            if i%128==0 then X.Yield() end
        end
        H.Quests();H.Achievements()
    end,true)
    local now=C.Tick()
    if now and (not playedRequested or now-playedRequested>=1800) and X.API('RequestTimePlayed') then
        playedRequested=now;X.Call('RequestTimePlayed')
    end
end
function H.Stop() owner=nil;known={};npc=nil end
function H.Handle(event,a,b)
    if not X.Ready() or C.Owner()~=owner then return end
    if event=='TIME_PLAYED_MSG' then
        local total,level=S.Integer(a,0,100000000000),S.Integer(b,0,100000000000)
        if total and level and level<=total then record({recordType='played_observed',totalPlayed=total,levelPlayed=level,scope='own native played response'},event) end
    elseif event=='ACHIEVEMENT_EARNED' then
        local id=S.Integer(a,1);if id then X.Queue('achievement-date:'..id,function() H.Achievement(id,event) end) end
    elseif event=='TRADE_SKILL_SHOW' or event=='TRADE_SKILL_LIST_UPDATE' then X.Queue('known-recipes',function() H.Recipes(event) end,true)
    elseif event=='QUEST_FINISHED' or event=='PLAYER_ENTERING_WORLD' then npc=nil
    elseif event=='QUEST_DETAIL' or event=='QUEST_PROGRESS' or event=='QUEST_COMPLETE' then
        npc=nil
        local id=S.Integer(X.Call('GetQuestID'),1,10000000);local guid=S.Text(X.Call('UnitGUID','questnpc'),128)
        if id and guid and guid:match('^Creature%-') then
            local creature=tonumber(guid:match('^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-'))
            if S.Integer(creature,1) then npc={owner=owner,questID=id,guid=guid,id=creature,at=C.Stamp()} end
        end
    end
end
