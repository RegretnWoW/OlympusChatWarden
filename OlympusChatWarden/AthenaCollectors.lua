-- Independently delivered, structured public evidence. No name-only joins,
-- raw message persistence, Who requests, or fabricated distant positions.
local _,ns=...
local C,S,X=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture
local P={};ns.AthenaCollectors=P
local seen,order={},{}
function P.Handle(event,...)
    if not X.Ready() or not (C.IntelEnabled() or C.PersonalEnabled() and event=='CHAT_MSG_GUILD_ACHIEVEMENT') then return end
    local text=ns.SafeString(select(1,...),4096);local guid=S.GUID(select(12,...))
    local line=S.Integer(select(11,...),1);local achievement=text and S.Integer(tonumber(text:match('|Hachievement:(%d+):')),1,10000000)
    if not guid or guid==select(2,C.Owner()) or not achievement then return end
    local key=line and event..':'..line
    if key and seen[key] then return end
    local name=S.Text(select(2,...),144)
    local record=X.Record('native_event',event,{recordType='public_achievement',achievementID=achievement,name=name,
        scope=event=='CHAT_MSG_GUILD_ACHIEVEMENT' and 'delivered guild-member announcement' or 'delivered vicinity announcement',
        lineID=line,localSighting=false},guid,false,{})
    if record and name then S.Observe(C.Owner(),guid,{name=name},record.at,event) end
    if record and key then
        if #order>=512 then seen[table.remove(order,1)]=nil end
        seen[key]=record.id;order[#order+1]=key
    end
end
-- Guild Chronicle owns guild-delivered announcements even with Intel disabled.
-- Vicinity announcements remain Intel-only. Neither route saves raw chat text.
X.Register(P,{'CHAT_MSG_ACHIEVEMENT','CHAT_MSG_GUILD_ACHIEVEMENT'},'history')
