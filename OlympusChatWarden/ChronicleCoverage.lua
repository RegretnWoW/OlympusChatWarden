-- Aggregate known collection failures. Absence of a gap is never proof of completeness.
local _,ns=...
local C,S=ns.Chronicle,ns.ChronicleStore
local V={LIMIT=32,INTERVAL=30};ns.ChronicleCoverage=V
local pending,count={},0
local states={};V.states=states
function V.State(family,state,reason)
    if not ({active=true,paused=true,unavailable=true,unreadable=true,deferred=true,partial=true,failed=true})[state] then return end
    if not states[family] then local n=0;for _ in pairs(states) do n=n+1 end;if n>=32 then return end end
    local previous=states[family];states[family]={state=state,at=C.Stamp(),reason=S.Text(reason,200),lastValidatedAt=state=='active' and C.Stamp() or previous and previous.lastValidatedAt}
end
function V.Note(family,state,reason,n)
    if not C.InWorld() then return end
    family=S.Text(family,96);state=S.Text(state,64);reason=S.Text(reason,200)
    local at=C.Stamp();if not family or not state or not reason or not at then return end
    local key=family..':'..state
    if not pending[key] and count>=V.LIMIT-1 then family='Additional collectors';state='partial';reason='Additional collection gaps exceeded the diagnostic category bound';key='overflow' end
    local row=pending[key]
    if not row then row={family=family,coverage=state,reason=reason,firstAt=at,count=0};pending[key]=row;count=count+1 end
    row.lastAt=at;row.count=row.count+(S.Integer(n,1,1000000) or 1)
end
function V.Flush(force)
    if count==0 then return end
    if not C.Active() then pending={};count=0;return end
    local at=C.Stamp();if not at then return end
    for key,row in pairs(pending) do
        if force or at-row.firstAt>=V.INTERVAL then
            if C.Record('collection_gap','control',row) then pending[key]=nil;count=count-1 end
        end
    end
end
function V.Clear() pending={};count=0;for family in pairs(states) do V.State(family,'paused','Recording boundary; unread intervals remain unknown') end end
function V.Pending() return count end
