-- Native character friends only. This current roster is disposable acquisition
-- authority, not a second historical database. No Battle.net or private notes.
local _,ns=...
local C,S,X=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture
local F={};ns.AthenaSocial=F
local owner,known,proof,ready=nil,{},{},false
local function Active() return C.IntelEnabled() and X.Ready() and owner==C.Owner() end
local function Notice(guid,active,source)
    local old=known[guid]
    if old==active then return end
    local e=X.Record('native_event',source,{recordType='friend_status',after=active,before=old,
        baseline=old==nil,scope='GUID-verified character friend'},guid,false)
    if not e then return end
    known[guid]=active
    proof[guid]={active=active,at=e.at,source=e.source,sourceID=e.id,origin='native character friend'}
    if ns.ChronicleEncounters then ns.ChronicleEncounters.CancelWatch(guid) end
    if not active and ns.AthenaCombatEvidence then ns.AthenaCombatEvidence.Revoke(guid) end
    if not active and ns.AthenaObservations then ns.AthenaObservations.Revoke(guid) end
    if active and ns.AthenaEnrichment then ns.AthenaEnrichment.PriorityChanged(guid) end
end
function F.Friend(guid) return Active() and known[guid]==true end
function F.State(guid)
    if not Active() then return 'inactive' end
    if known[guid]==true then return ready and 'verified native friend' or 'last verified friend; roster refreshing' end
    if known[guid]==false then return 'verified friendship removed' end
    return ready and 'not in current native roster' or 'unresolved roster'
end
function F.Proof(guid) return Active() and proof[guid] and ns.Athena.Copy(proof[guid]) or nil end
function F.Status() return {ready=ready==true,owner=owner,source='native character friends; GUID only'} end
function F.Unit(unit,source)
    if not Active() then return end
    local guid=S.GUID(X.Call('UnitGUID',unit));local name=S.Text(X.Call('UnitName',unit),144)
    local info=name and X.Table(X.Call('C_FriendList.GetFriendInfo',name))
    if not guid or not info or S.GUID(info.guid)~=guid or S.GUID(X.Call('UnitGUID',unit))~=guid then return end
    Notice(guid,true,source);return F.Friend(guid)
end
function F.Refresh(source)
    if not Active() then return end
    -- RequiresFriendList returns nothing when not ready. Missing, restricted,
    -- partial and unstable lists cannot prove that a friendship ended.
    local count=S.Integer(X.Call('C_FriendList.GetNumFriends'),0,200)
    if not count then ready=false;return end
    local snapshot={}
    for n=1,count do
        local info=X.Table(X.Call('C_FriendList.GetFriendInfoByIndex',n))
        local guid=info and S.GUID(info.guid)
        if not guid or snapshot[guid] then ready=false;return end
        snapshot[guid]=true
    end
    if S.Integer(X.Call('C_FriendList.GetNumFriends'),0,200)~=count then ready=false;return end
    ready=true
    for guid in pairs(snapshot) do Notice(guid,true,source) end
    for guid,active in pairs(known) do
        if active and not snapshot[guid] and X.Bool(X.Call('C_FriendList.IsFriend',guid))==false then Notice(guid,false,source) end
    end
    if ns.AthenaEnrichment then ns.AthenaEnrichment.RefreshVisible() end
end
function F.Start() owner=C.Owner();known={};proof={};ready=false;F.Refresh('control') end
function F.Stop() owner=nil;known={};proof={};ready=false end
function F.Handle(event) F.Refresh(event) end
X.Register(F,{'FRIENDLIST_UPDATE'},'intel')
