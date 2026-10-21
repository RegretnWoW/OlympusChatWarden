-- Automatic, local Guild Chronicle. Native affiliation and group-at-event
-- context are evidence; neither is official event authority or boss attendance.
local _,ns=...
local G={};ns.AthenaGuild=G
local C,S,X=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture
local owner,previous,members,seeded=nil,nil,{},false
local memberOrder={}
local function Remember(guid,signature)
    if members[guid]==nil then
        memberOrder[#memberOrder+1]=guid
        if #memberOrder>1000 then members[table.remove(memberOrder,1)]=nil end
    end
    members[guid]=signature
end
local function Active() return C.PersonalEnabled() and C.InWorld() end
local function Affiliation(unit)
    local name,rank,_,realm=X.Call('GetGuildInfo',unit)
    if not ns.Readable(realm) then return end
    name=S.Text(name,128);rank=S.Text(rank,128);realm=S.Text(realm,128) or S.Text(X.Call('GetRealmName'),128)
    if not name or not realm then return end
    return {guildName=name,guildRealm=realm,guildRank=rank}
end
local function Own()
    if not Active() or X.Bool(X.Call('IsInGuild'))~=true then return end
    return Affiliation('player')
end
function G.Observe(source)
    if not Active() or owner~=C.Owner() then return end
    local inside=X.Bool(X.Call('IsInGuild'));if inside==nil then return end
    local v=inside and Affiliation('player') or {after=false}
    if not v or inside==false and S.Text(X.Call('GetGuildInfo','player'),128) then return end
    v.after=inside
    local signature=(v.guildRealm or '')..'/'..(v.guildName or '')..'/'..(v.guildRank or '')..'/'..tostring(inside)
    if previous and signature==previous.signature then return end
    v.recordType='guild_affiliation';v.baseline=previous==nil;v.before=previous and previous.after
    v.guildBefore=previous and previous.guildName;v.guildBeforeRealm=previous and previous.guildRealm;v.guildBeforeRank=previous and previous.guildRank
    v.scope='own native guild affiliation'
    local e=X.Record('native_event',source,v,select(2,C.Owner()),false)
    if e then v.signature=signature;previous=v end
end
function G.Roster(source)
    local own=Own();if not own or owner~=C.Owner() then return end
    -- The guild club, never arbitrary community IDs. Structured member GUIDs
    -- are mandatory; private notes, BNet IDs and last-online fields are ignored.
    local club=X.Call('C_Club.GetGuildClubId')
    if not S.Text(club,128) and not S.Integer(club,1) then return end
    local ids=X.Table(X.Call('C_Club.GetClubMembers',club));if not ids or #ids>1000 then X.Mark('Guild roster','Unavailable or unsupported roster size; no name-only merge');return end
    local pending={};for _,id in ipairs(ids) do if S.Text(id,128) or S.Integer(id,1) then pending[#pending+1]=id end end
    local observedOwner=owner
    -- A roster callback has no member facts in its payload. Read the catalog
    -- cooperatively and date each fact when read, never at the triggering event.
    -- Every readable fact is written before yielding; no raw roster rows linger.
    X.Queue('athena-guild-roster',function()
    -- Cross-login equality is seeded only from this owner's validated originals.
    -- No unvalidated archive becomes live social authority; no old row is edited.
    local c=S.Character(observedOwner,false)
    while not c and S.loading do
        X.Yield();if owner~=observedOwner or not Active() then return end;c=S.Character(observedOwner,false)
    end
    if not seeded and c then
        for n=#c.events,1,-1 do
            local e=c.events[n];local d=e.details
            if d.recordType=='guild_member_observed' and d.guildRealm==own.guildRealm and d.guildName==own.guildName and S.GUID(e.subject) and members[e.subject]==nil then
                Remember(e.subject,(d.guildRealm or '')..'/'..(d.guildName or '')..'/'..(d.guildRank or '?'))
                if #memberOrder==1000 then break end
            end
            if n%128==0 then X.Yield() end
        end
        seeded=true
    end
    local began=ns.WardenPerformance and ns.WardenPerformance.Now()
    for n,id in ipairs(pending) do
        if owner~=observedOwner or C.Owner()~=observedOwner or not Active() then return end
        if S.Text(id,128) or S.Integer(id,1) then
            local info=X.Table(X.Call('C_Club.GetMemberInfo',club,id));local guid=info and S.GUID(info.guid)
            local rank=info and S.Text(info.guildRank,128)
            info=nil
            if guid then
                local current=Own();local currentClub=X.Call('C_Club.GetGuildClubId')
                if not current or current.guildName~=own.guildName or current.guildRealm~=own.guildRealm
                    or not ns.Readable(currentClub) or currentClub~=club then return end
                local signature=own.guildRealm..'/'..own.guildName..'/'..(rank or '?')
                if members[guid]~=signature then
                    local e=X.Record('native_event',source,{recordType='guild_member_observed',guildName=own.guildName,guildRealm=own.guildRealm,
                        guildRank=rank,baseline=members[guid]==nil,scope='GUID-bearing native guild roster',observedAt=C.Stamp()},guid,false)
                    if e then Remember(guid,signature) end
                end
            end
        end
        local now=ns.WardenPerformance and ns.WardenPerformance.Now()
        if n%8==0 or began and now and now-began>=2 then X.Yield();began=ns.WardenPerformance and ns.WardenPerformance.Now() end
    end
    end,true)
end
local activities={group_roster=true,instance_enter=true,instance_exit=true,achievement_earned=true}
local native={encounter_started=true,encounter_ended=true,boss_kill_event=true,pvp_match_complete=true,duel_session_start=true,duel_session_result=true,group_assignment=true,group_transition=true}
function G.Context(kind,source,data)
    if not Active() then return data end
    local public=kind=='native_event' and data.recordType=='public_achievement' and source=='CHAT_MSG_GUILD_ACHIEVEMENT'
    if not activities[kind] and not (kind=='native_event' and native[data.recordType]) and not public then return data end
    local own=Own();if not own then return data end
    -- Copy fields, not another event/payload. The one accepted canonical event
    -- is shared by character, player and guild projections and the same journal.
    local out={};for k,v in pairs(data) do out[k]=v end
    out.guildName=own.guildName;out.guildRealm=own.guildRealm;out.guildRank=own.guildRank
    out.guildAssociated=true
    if public then out.orgAffiliation='native guild announcement; not an official event';return out end
    local raid=X.Bool(X.Call('IsInRaid'))==true
    local total=S.Integer(X.Call('GetNumGroupMembers'),0,40)
    if not total then out.orgAffiliation='affiliation known; group denominator unavailable';return out end
    total=math.max(1,total)
    local all,same,seen={}, {},{};local known=0
    local function Unit(unit)
        local guid=S.GUID(X.Call('UnitGUID',unit));if not guid or seen[guid] then return end
        local match=unit=='player' and true or X.Bool(X.Call('UnitIsInMyGuild',unit))
        if S.GUID(X.Call('UnitGUID',unit))~=guid then return end
        seen[guid]=true;all[#all+1]=guid
        if match~=nil then known=known+1 end
        if match==true then same[#same+1]=guid end
    end
    Unit('player')
    for n=1,raid and total or total-1 do Unit((raid and 'raid' or 'party')..n) end
    -- Inconsistent/stale native counts never become a confirmed denominator.
    local current=Own()
    if not current or current.guildName~=own.guildName or current.guildRealm~=own.guildRealm then return data end
    local nowTotal=S.Integer(X.Call('GetNumGroupMembers'),0,40)
    if not nowTotal or math.max(1,nowTotal)~=total or #all>total or known>total then out.orgAffiliation='inconsistent group denominator';return out end
    out.guildContextMembers=all;out.guildContextGuildMembers=same;out.guildContextKnown=#all;out.guildContextSame=#same
    out.guildGroupSize=total;out.guildContextUnknown=total-known
    out.guildMajority=total>1 and #same>total/2
    out.orgAffiliation=out.guildMajority and 'measured guild majority; group at event, not attendance'
        or out.guildContextUnknown>0 and 'guild associated; membership incomplete' or 'guild associated; no guild majority'
    return out
end
function G.Start() owner=C.Owner();previous=nil;members={};memberOrder={};seeded=false;G.Observe('control');G.Roster('control') end
function G.Stop() owner=nil;previous=nil;members={};memberOrder={};seeded=false end
function G.Handle(event,unit)
    if event=='PLAYER_GUILD_UPDATE' and S.Text(unit,32)~='player' then return end
    G.Observe(event);G.Roster(event)
end
X.Register(G,{'GUILD_ROSTER_UPDATE','PLAYER_GUILD_UPDATE'},'chronicle')
