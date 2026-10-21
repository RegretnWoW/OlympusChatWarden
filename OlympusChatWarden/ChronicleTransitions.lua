-- Small event-time copies of structured native facts. No getters after the event,
-- chat parsing, transaction inference, inspection or polling.
local _,ns=...
local S,X=ns.ChronicleStore,ns.ChronicleCapture
local T={BOSS_LIMIT=40};ns.ChronicleTransitions=T
function T.Receipt(event,a,b,c,d)
    local data
    if event=='QUEST_LOOT_RECEIVED' then
        local quest=S.Integer(a,1,10000000);local quantity=S.Integer(c,1,1000000)
        local id=ns.CanRead(b) and #b<=2048 and S.Integer(tonumber(b:match('|Hitem:(%d+)') or b:match('^item:(%d+)')),1,1000000000)
        local item=id and ns.ChronicleEvidence.ItemString(b,id)
        if quest and quantity and item then data={recordType='quest_item_received',questID=quest,itemID=id,itemString=item,quantity=quantity,scope='native quest reward delivery'} end
    elseif event=='QUEST_CURRENCY_LOOT_RECEIVED' then
        local quest=S.Integer(a,1,10000000);local currency=S.Integer(b,1,10000000);local quantity=S.Integer(c,1,1000000000)
        if quest and currency and quantity then data={recordType='quest_currency_received',questID=quest,currencyID=currency,quantity=quantity,scope='native quest reward delivery'} end
    elseif event=='ENCOUNTER_LOOT_RECEIVED' then
        local encounter=S.Integer(a,1,10000000);local id=S.Integer(b,1,1000000000);local quantity=S.Integer(d,1,1000000)
        local item=id and ns.ChronicleEvidence.ItemString(c,id)
        -- The pinned payload has no recipient GUID. Preserve delivery without
        -- turning it into proof that this character obtained the item.
        if encounter and id and quantity then data={recordType='encounter_loot_delivery',encounterID=encounter,itemID=id,itemString=item,quantity=quantity,scope='recipient unknown'} end
    end
    return data
end
function T.Bosses(payload)
    local value=X.Table(payload);local rows={}
    if not value then return rows,nil,false,'Boss status payload unavailable' end
    local total=#value;local complete=total<=T.BOSS_LIMIT
    for n=1,math.min(total,T.BOSS_LIMIT) do
        local raw=X.Table(value[n]);local id=raw and S.Integer(raw.creatureID,1,1000000000)
        local name=raw and S.Text(raw.creatureName,144);local hp=raw and S.Number(raw.remainingHealthPercent,0,100)
        if id or name or hp then rows[#rows+1]={creatureID=id,creatureName=name,remainingHealthPercent=hp,part=n,partial=not (id and name and hp)} end
        if not id or not name or not hp then complete=false end
    end
    -- Reject non-array metadata as complete, without walking unbounded input.
    if total<=T.BOSS_LIMIT and not S.Array(value,T.BOSS_LIMIT) then complete=false end
    return rows,S.Integer(total,0,1000000),complete,complete and nil or 'Boss status payload partial or beyond bound'
end
function T.Handle(event,...)
    local data=T.Receipt(event,...)
    if data then X.Record('native_event',event,data,nil,false);X.Mark('Reward deliveries','Readable structured native delivery observed; recipient limits retained')
    elseif ns.ChronicleCoverage then ns.ChronicleCoverage.Note('Reward delivery','partial','Structured reward payload unreadable or incomplete') end
end
X.Register(T,{'QUEST_LOOT_RECEIVED','QUEST_CURRENCY_LOOT_RECEIVED','ENCOUNTER_LOOT_RECEIVED'})
X.Mark('Reward deliveries','Native event registration attempted; waiting for readable delivery')
