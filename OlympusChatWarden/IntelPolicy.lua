-- One relationship policy for historical projections and event-time detail gates.
-- Runtime context is disposable; the authoritative facts remain in the ledger.
local _,ns=...
local S,C=ns.ChronicleStore,ns.Chronicle
local P={LIMIT=512};ns.IntelPolicy=P
P.localSources={UNIT_TARGET=true,PLAYER_TARGET_CHANGED=true,UPDATE_MOUSEOVER_UNIT=true,PLAYER_FOCUS_CHANGED=true,NAME_PLATE_UNIT_ADDED=true,
    UNIT_FLAGS=true,UNIT_FACTION=true,UNIT_NAME_UPDATE=true,UNIT_LEVEL=true}
P.important={['encountered friend']=true,['personal bookmark']=true,['manual inspection']=true,['Wanted encounter']=true,['earned relationship']=true}
P.labels={['party teammate']='Recorded party teammate',['raid teammate']='Recorded raid teammate',
    ['encountered friend']='GUID-matched friend',['personal bookmark']='Personal bookmark',
    ['manual inspection']='Deliberately inspected',['Wanted encounter']='Direct Wanted observation',
    ['verified duel opponent']='Verified duel opponent',['native opponent']='Native player credit evidence',
    creatureCredit='Native creature credit evidence',nativeCredit='Native actor/target credit evidence',death='Observed player death',roster='Recorded group roster',
    scoreboard='GUID-bearing scoreboard',localUnit='Direct local observation',['earned relationship']='Recurring shared activity'}
function P.Classify(e,guid)
    local d=e.details or {}
    if e.kind=='important_player' and e.subject==guid and P.important[d.relationship]
        and (d.relationship~='manual inspection' or e.source=='INSPECT_READY') then return 1,d.relationship end
    if e.kind=='important_player' and e.subject==guid and (d.relationship=='party teammate' or d.relationship=='raid teammate') then return 2,'roster' end
    if e.kind=='group_roster' then for _,id in ipairs(d.members or {}) do if id==guid then return 2,'roster' end end end
    if e.kind=='native_snapshot' and e.capture.family=='scoreboard' and e.capture.values.guid==guid then return 2,'scoreboard' end
    if e.kind=='native_event' then
        if d.recordType=='duel_session_start' and e.source=='DUEL_COUNTDOWN' and d.accepted==true and d.opponentGUID==guid then return 2,'verified duel opponent' end
        if d.recordType=='native_kill_credit' and e.source=='PARTY_KILL' and (d.attackerGUID==guid or d.targetGUID==guid) then
            return 2,d.entityKind=='Player' and S.GUID(d.attackerGUID) and 'native opponent'
                or (d.entityKind=='Creature' or d.entityKind=='Vehicle') and 'creatureCredit' or 'nativeCredit'
        end
        if d.recordType=='witness_death' and e.subject==guid then return 2,'death' end
    end
    if e.kind=='player_observed' and e.subject==guid and d.localSighting and P.localSources[e.source] then
        if d.wantedListed==true then return 1,'Wanted encounter' end
        return 3,'localUnit'
    end
end
-- Relationship significance is derived from distinct local activity contexts,
-- never from spam/advisories, passive sightings, or imported peer reports.
P.THRESHOLD=8;P.MIN_CONTEXTS=3
function P.Accumulate(state,e,guid)
    state=state or {tier=3,earnedTier=3,score=0,contexts={},families={},days={},count=0}
    if e.originKind=='imported' or e.originKind=='action' or e.originKind=='assessment' then return state end
    local tier,reason=P.Classify(e,guid);if not tier then return state end
    if tier==1 then
        -- An acquisition result cannot authorize its own future acquisition.
        -- Watches and current friendship are live, independent permissions.
        if reason=='manual inspection' or reason=='Wanted encounter' then
            state.manualPriority=true;state.manualCause=reason;state.manualID=e.id;state.manualOwner=e.character;state.manualAt=e.at
            state.tier=1;state.reason=reason
        end
        return state
    end
    if tier>2 then return state end
    state.earnedTier=math.min(state.earnedTier or 3,2)
    local d=e.details or {};local family=reason=='roster' and 'group' or reason=='scoreboard' and 'battleground'
        or reason=='verified duel opponent' and 'duel' or reason=='death' and 'death' or 'credit'
    local capture=e.capture and e.capture.values or {}
    local context=(e.character or '')..'/'..(d.runID or capture.runID or d.duelID or e.session or e.id)..'/'..family..'/'..tostring(d.groupEpoch or capture.matchSequence or '')
    if family=='death' then state.tier=state.manualPriority and 1 or state.earnedTier;return state end
    local observer=e.character and e.character:match('/(Player%-.+)$')
    if family=='credit' and d.attackerGUID~=observer and d.targetGUID~=observer then state.tier=state.manualPriority and 1 or state.earnedTier;return state end
    if state.earnedTier~=1 and not state.contexts[context] then
        if state.count<64 then
            state.contexts[context]=e.id;state.count=state.count+1
            state.score=state.score+((family=='group' or family=='battleground' or family=='duel') and 2 or 1)
        end
        state.families[family]=true;state.days[math.floor(e.at/86400)]=true
        local families,days=0,0;for _ in pairs(state.families) do families=families+1 end;for _ in pairs(state.days) do days=days+1 end
        if state.score>=P.THRESHOLD and state.count>=P.MIN_CONTEXTS and (families>=2 or days>=2) then
            state.earnedTier=1;state.reason='Recurring shared activity';state.promotionID=e.id;state.promotionAt=e.at;state.promotionOwner=e.character
            -- Once established, no unbounded session-key cache is needed.
            state.contexts={};state.families={};state.days={}
        end
    end
    state.tier=state.manualPriority and 1 or state.earnedTier;return state
end
local context,summary,hints,count,owner,seedSource,token,pending,seeding={},{},{},0,nil,nil,0,{},false
local function Remember(guid,tier,e,replay)
    if not S.GUID(guid) or guid==select(2,C.Owner()) or not tier or tier>2 then return end
    local prior=summary[guid] and summary[guid].earnedTier
    local v=P.Accumulate(summary[guid],e,guid);summary[guid]=v
    if not replay and prior~=1 and v.earnedTier==1 and ns.AthenaEnrichment then ns.AthenaEnrichment.PriorityChanged(guid) end
    if v.tier==1 then pending[guid]=true end
    if context[guid] then context[guid]=v;return end
    if count>=P.LIMIT then
        local replace;for id,row in pairs(context) do if row.tier==2 then replace=id;break end end
        if not replace then return end
        context[replace]=nil;count=count-1
    end
    -- The hot set is bounded. Compact significance summaries scale only with
    -- genuinely referenced Activity/Important identities, never city sightings.
    -- Eviction cannot erase progress or disable a previously earned player.
    context[guid]=v;count=count+1
end
function P.Notice(e,replay)
    if not C.IntelEnabled() then return end
    if owner~=C.Owner() then P.Reset() end
    local d=e.details
    for _,guid in ipairs({e.subject or false,d.attackerGUID or false,d.targetGUID or false,d.opponentGUID or false}) do
        if guid then Remember(guid,P.Classify(e,guid),e,replay) end
    end
    if e.kind=='group_roster' then for _,guid in ipairs(d.members) do Remember(guid,P.Classify(e,guid),e,replay) end end
    if e.capture and e.capture.family=='scoreboard' then local guid=e.capture.values.guid;Remember(guid,P.Classify(e,guid),e,replay) end
end
function P.Tier(guid)
    if not C.IntelEnabled() then return nil,'disabled' end
    local profile=C.Profile(guid)
    if profile and profile.personal and profile.personal.watch then return 1,'current watchlist' end
    if ns.AthenaSocial and ns.AthenaSocial.Friend(guid) then return 1,'GUID-matched current friend' end
    local v=summary[guid]
    if hints[guid] then return 1,'Relationship index rebuilding; prior capture priority kept' end
    if ns.Athena and ns.Athena.CachedCaptureTier(guid)==1 then return 1,'Last verified relationship index' end
    return v and v.tier or 3,v and v.reason or S.loading and 'unresolved history' or 'no cached relationship'
end
function P.ManualTier(guid) local v=summary[guid];return v and v.manualPriority and 1 or nil,v and v.manualCause end
function P.Explain(guid) local v=summary[guid];return v and ns.Athena.Copy(v) or {earnedTier=3,tier=P.Tier(guid)} end
function P.EarnedTier(guid)
    local v=summary[guid]
    return ns.Athena and ns.Athena.EarnedTier(guid)==1 and 1 or v and v.earnedTier or 3
end
function P.Reset() context={};summary={};hints={};pending={};count=0;owner=C.Owner();seedSource=nil;token=token+1;seeding=false end
function P.CancelSeed() seedSource=nil;seeding=false;token=token+1 end
function P.PreparePriorityCache()
    if not ns.Athena then return end
    local j=ns.ChronicleStartupJournal
    if j and j.Count()>0 then
        for guid in pairs(pending) do local state=summary[guid];if state and state.tier==1 then ns.Athena.RememberRelationship(owner,guid,state,true) end end
    end
    for guid in pairs(hints) do ns.Athena.RememberRelationship(owner,guid,{earnedTier=3,captureHint=true,manualOwner=owner},true) end
    ns.Athena.CheckpointPriorityMetadata()
end
function P.AcceptShared(guid,state)
    if state and state.earnedTier==1 then summary[guid]=ns.Athena.Copy(state);pending[guid]=true end
end
function P.Pump()
    if not C.IntelEnabled() or not C.InWorld() or S.loading or S.blocked then return end
    local j=ns.ChronicleStartupJournal
    if j and (j.Busy() or j.Count()>0) then return end
    local c=S.Character(C.Owner(),false);if not c then return end
    if ns.ChronicleCapture.Pending()>=200 then return end
    if not seeding and ns.Athena then
        local n=0;for guid in pairs(pending) do
            if summary[guid] then ns.Athena.RememberRelationship(owner,guid,summary[guid]) end
            pending[guid]=nil;n=n+1;if n>=16 then break end
        end
    end
    if c==seedSource then return end
    -- Pending session/record IDs may have been rebased by the journal. Rebuild
    -- once from committed canonical sources, carrying eligibility (not scores)
    -- until the cooperative pass finishes. Replay cannot double the score.
    for guid,state in pairs(summary) do if state.tier==1 then hints[guid]=true end end
    context={};summary={};count=0;pending={};seeding=true
    seedSource=c;local epoch=token
    ns.ChronicleCapture.Queue('intel-tier-context',function()
        -- Most recent relationships first; no account-wide materialization.
        for n=1,#c.events do
            if epoch~=token or C.Owner()~=owner or S.Character(owner,false)~=c or not C.IntelEnabled() then return end
            P.Notice(c.events[n],true)
            if n%128==0 then ns.ChronicleCapture.Yield() end
        end
        seeding=false;hints={}
        if ns.Athena then ns.Athena.ReconcilePriorityOwner(owner,summary) end
    end,true)
end
function P.Count() return count,P.LIMIT end
function P.SummaryCount() local n=0;for _ in pairs(summary) do n=n+1 end;return n end
