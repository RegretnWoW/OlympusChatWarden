-- Small, temporary preservation window while an existing archive validates.
-- No late unit reads, SavedVariables writes, inspection or inferred outcomes.
local _,ns=...
local C,S=ns.Chronicle,ns.ChronicleStore
local B={LIMIT=256,BYTES=131072,diagnostics={}};ns.ChronicleStartup=B
local pending
local function Eligible(saved)
    return type(saved)=='table' and not getmetatable(saved) and saved.schema==S.VERSION
        and saved.enabled==true and saved.consentVersion==S.CONSENT and ns.DB and ns.DB.enabled
        and ns.Membership and ns.Membership.Allowed()
end
function B.Begin(source)
    pending=nil;B.diagnostics={captured=0,merged=0,overflow=0,discarded=0}
    if not Eligible(source) then return end
    local owner=C.Owner();local at=C.Stamp()
    pending={source=source,owner=owner,firstAt=at,rows={},bytes=0,duels=source.duels==true and source.duelConsent==1,quests={}}
end
function B.Cancel()
    if pending then B.diagnostics.discarded=#pending.rows;pending=nil end
end
function B.Handle(event,a,b,c,d,e,f)
    local p=pending
    if not p or not S.loading or ns.DB.chronicle~=p.source or not Eligible(p.source) then return end
    if event=='PLAYER_ENTERING_WORLD' then p.world=true;p.started=true;p.owner=p.owner or C.Owner();p.firstAt=p.firstAt or C.Stamp();return end
    if event=='PLAYER_LEAVING_WORLD' then p.world=false;return end
    if event=='PLAYER_LOGOUT' then B.Cancel();return end
    if not p.world or C.Owner()~=p.owner then return end
    local kind,details,evidence='native_event',nil,'observed'
    local bosses
    if event=='QUEST_LOOT_RECEIVED' or event=='QUEST_CURRENCY_LOOT_RECEIVED' or event=='ENCOUNTER_LOOT_RECEIVED' then
        details=ns.ChronicleTransitions.Receipt(event,a,b,c,d)
    elseif event=='QUEST_TURNED_IN' then local id=S.Integer(a,1,10000000);if id then
        local tick=C.Tick();if not tick or p.quests[id] and tick-p.quests[id]<2 then return end
        details={questID=id,rewardXP=S.Integer(b,0),rewardCopper=S.Integer(c,0)};kind='quest_turnin';evidence='confirmed'
    end
    elseif event=='QUEST_ACCEPTED' or event=='QUEST_REMOVED' or event=='ACHIEVEMENT_EARNED' then
        local id=S.Integer(event=='QUEST_ACCEPTED' and (b~=nil and b or a) or a,1,10000000)
        if id then
            kind=event=='QUEST_ACCEPTED' and 'quest_accepted' or event=='QUEST_REMOVED' and 'quest_removed' or 'achievement_earned'
            details=kind=='achievement_earned' and {achievementID=id} or {questID=id};evidence='confirmed'
            local value;if ns.Readable(b) and type(b)=='boolean' then value=b end
            if kind=='achievement_earned' then details.alreadyEarned=value elseif kind=='quest_removed' then details.wasReplayQuest=value end
        end
    elseif event=='BOSS_KILL' or event=='ENCOUNTER_START' or event=='ENCOUNTER_END' then
        local id=S.Integer(a,1,10000000);if id then details={recordType=event=='BOSS_KILL' and 'boss_kill_event' or event=='ENCOUNTER_START' and 'encounter_started' or 'encounter_ended',encounterID=id,name=S.Text(b,144)}
            if event~='BOSS_KILL' then details.difficultyID=S.Integer(c,0);details.groupSize=S.Integer(d,0,100);details.success=S.Integer(e,0,1) end
            if event=='ENCOUNTER_END' then
                local total,complete;bosses,total,complete=ns.ChronicleTransitions.Bosses(f)
                details.bossStatusReadCount=#bosses;details.bossStatusTotal=total;details.bossStatusComplete=complete
            end
        end
    elseif event=='PVP_MATCH_COMPLETE' then details={recordType='pvp_match_complete',winner=S.Integer(a,0,100),duration=S.Number(b,0)}
    elseif p.duels and event=='DUEL_REQUESTED' then local name=S.Text(a,144);if name then details={recordType='duel_requested',name=name} end
    elseif p.duels and event=='DUEL_FINISHED' then details={recordType='duel_finished',resultKnown=false} end
    if not details then return end
    local at,clock=C.Stamp();local tick=C.Tick();local location=C.Place()
    if not at or not tick or C.Owner()~=p.owner then return end
    if kind=='native_event' then details.evidenceClass,details.outcome,details.outcomeScope=ns.ChronicleCapture.Classify(kind,event,details) end
    local row={kind=kind,source=event,details=details,evidence=evidence,at=at,elapsed=tick,timeSource=clock,location=location}
    local bytes=S.Size(row)
    if #p.rows>=B.LIMIT or p.bytes+bytes>B.BYTES then B.diagnostics.overflow=B.diagnostics.overflow+1+#(bosses or {});return end
    p.rows[#p.rows+1]=row;p.bytes=p.bytes+bytes;B.diagnostics.captured=B.diagnostics.captured+1
    local parent=#p.rows
    for _,data in ipairs(bosses or {}) do
        data.recordType='boss_status_observed';data.encounterID=details.encounterID;data.parts=details.bossStatusTotal
        data.evidenceClass,data.outcome,data.outcomeScope=ns.ChronicleCapture.Classify('native_event',event,data)
        local child={kind='native_event',source=event,details=data,evidence='observed',at=at,elapsed=tick,timeSource=clock,location=location,startupParent=parent}
        local size=S.Size(child)
        if #p.rows<B.LIMIT and p.bytes+size<=B.BYTES then
            p.rows[#p.rows+1]=child;p.bytes=p.bytes+size;B.diagnostics.captured=B.diagnostics.captured+1
        else B.diagnostics.overflow=B.diagnostics.overflow+1 end
    end
    if kind=='quest_turnin' then p.quests[details.questID]=tick end
end
function B.Merge()
    local p=pending;pending=nil
    -- A late permission/identity decision can leave no eligible buffer. Mark
    -- that coverage as unknown after validation, without collecting while locked.
    if not p and C.promptReady and Eligible(S.db) then p={owner=C.Owner(),rows={},started=true} end
    if not p or not p.started then return end
    if not Eligible(S.db) or C.Owner()~=p.owner then B.diagnostics.discarded=#p.rows;return end
    local character=S.Character(p.owner,true);character.sessionSequence=character.sessionSequence+1
    local session=p.owner..'/s'..character.sessionSequence;character.currentSession=session
    local ids={}
    for n,row in ipairs(p.rows) do
        row.session=session
        if row.startupParent then row.details.encounterRef=ids[row.startupParent];row.startupParent=nil end
        local duel=row.source=='DUEL_REQUESTED' or row.source=='DUEL_FINISHED'
        local saved=(not duel or S.db.duels==true and S.db.duelConsent==1) and S.Append(p.owner,row)
        if saved then ids[n]=saved.id;B.diagnostics.merged=B.diagnostics.merged+1 else B.diagnostics.discarded=B.diagnostics.discarded+1 end
    end
    C.diagnostics.gaps=C.diagnostics.gaps+1
    local at,clock=C.Stamp();local tick=C.Tick()
    if at and tick then S.Append(p.owner,{kind='collection_gap',source='control',session=session,at=at,elapsed=tick,timeSource=clock,evidence='observed',location={},
        details={reason='Startup coverage is partial: no routes, inspections, scoreboard snapshots or full duel sessions during archive validation',
            firstAt=p.firstAt,lastAt=at,count=B.diagnostics.merged,samples=B.diagnostics.overflow+B.diagnostics.discarded}}) end
end
local frame=CreateFrame('Frame')
for _,event in ipairs({'PLAYER_ENTERING_WORLD','PLAYER_LEAVING_WORLD','PLAYER_LOGOUT','QUEST_TURNED_IN','QUEST_ACCEPTED','QUEST_REMOVED','ACHIEVEMENT_EARNED',
    'BOSS_KILL','ENCOUNTER_START','ENCOUNTER_END','PVP_MATCH_COMPLETE','DUEL_REQUESTED','DUEL_FINISHED',
    'QUEST_LOOT_RECEIVED','QUEST_CURRENCY_LOOT_RECEIVED','ENCOUNTER_LOOT_RECEIVED'}) do pcall(frame.RegisterEvent,frame,event) end
frame:SetScript('OnEvent',function(_,event,...) B.Handle(event,...) end)
