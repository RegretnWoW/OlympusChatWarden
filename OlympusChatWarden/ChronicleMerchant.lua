-- Opt-in owner-private native business observations. No market valuation,
-- wallet-as-revenue inference, mail bodies or public sharing.
local _,ns=...
local C,S,X=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture
local M={types={auction_owned_observed=true,auction_invoice_observed=true,trade_completed_observed=true},
 events={'AUCTION_HOUSE_SHOW','AUCTION_HOUSE_CLOSED','OWNED_AUCTIONS_UPDATED','AUCTION_CANCELED','MAIL_SHOW','MAIL_CLOSED','MAIL_INBOX_UPDATE',
 'TRADE_PLAYER_ITEM_CHANGED','TRADE_TARGET_ITEM_CHANGED','TRADE_MONEY_CHANGED','UI_INFO_MESSAGE'}}
ns.ChronicleMerchant=M
local own,seen,auctionOpen,mailOpen,trade=nil,{},false,false,nil
local projection
function M.Selected()
    local pref=ns.DB and X.Table(ns.DB.merchantHistoryConsent);local owners=pref and pref.version==1 and X.Table(pref.owners)
    return owners and owners[C.Owner()]==true or false
end
function M.SetEnabled(v)
    if type(v)~='boolean' then return false,'Choose a recording preference.' end
    local owner=C.Owner();if not owner then return false,'Current character identity is unavailable.' end
    local pref=ns.DB.merchantHistoryConsent
    if pref~=nil and (not X.Table(pref) or pref.version~=1 or not X.Table(pref.owners)) then
        if v then return false,'Merchant preferences need recovery; existing value retained.' end
        ns.DB.merchantHistoryConsent=nil;M.Stop();return true,'Malformed merchant opt-in disabled.'
    end
    pref=pref or {version=1,owners={}};pref.owners[owner]=v and true or nil;ns.DB.merchantHistoryConsent=pref
    if not v then M.Stop() elseif C.InWorld() then M.Start() end
    return true,'Private merchant recording '..(v and 'enabled' or 'paused')..'. Existing observations are kept.'
end
local function ready() return M.Selected() and X.Ready() and C.PersonalEnabled() and own==C.Owner() end
function M.Valid(d)
    if d.scope~='owner-private native business evidence' or d.family~='merchant' or not S.Text(d.contentID,64) then return false end
    if d.recordType=='auction_owned_observed' then return S.Integer(d.auctionID,1) and ({active=true,sold=true,unknown=true})[d.phase] end
    if d.recordType=='auction_invoice_observed' then return d.phase=='seller invoice observed; payment collection unverified' and d.partial==true end
    if d.recordType=='trade_completed_observed' then return d.phase=='native trade success' end
    return false
end
function M.ValidateSnapshot(v)
    for _,k in ipairs({'auctionID','itemID','quantity','bidCopper','buyoutCopper','depositCopper','cutCopper','offeredCopper','requestedCopper'}) do if v[k]~=nil and not S.Integer(v[k],(k=='auctionID' or k=='itemID' or k=='quantity') and 1 or 0) then return false end end
    if v.auctionID then return ({active=true,sold=true,unknown=true})[v.status]==true and v.fullResults==true end
    if v.invoiceKind then return ({seller=true,seller_temp_invoice=true})[v.invoiceKind]==true and v.ambiguous==true end
    if not S.Text(v.tradeRef,256) or v.partnerGUID~=nil and not S.GUID(v.partnerGUID) or not S.Array(v.items,12) then return false end
    for _,r in ipairs(v.items) do if not S.Array(r,5) or #r~=5 or not S.Integer(r[1],1,2) or not S.Integer(r[2],1,6) or not S.Integer(r[3],1) or not S.Integer(r[4],1) or r[5]~=false and not S.Text(r[5],144) then return false end end
    return true
end
function M.Provenance(e)
    local r=e.details.recordType
    if e.subject~=e.character:match('/(Player%-.+)$') then return false end
    local context=X.Table(e.sourceContext)
    if not context or context.accessScope~='OWNER_PRIVATE' then return false end
    return r=='auction_owned_observed' and (e.source=='OWNED_AUCTIONS_UPDATED' or e.source=='AUCTION_HOUSE_SHOW')
        or r=='auction_invoice_observed' and (e.source=='MAIL_INBOX_UPDATE' or e.source=='MAIL_SHOW')
        or r=='trade_completed_observed' and e.source=='UI_INFO_MESSAGE'
end
local function save(key,values,d,source)
    if not ready() then return end
    local encoded=ns.ChronicleBackup.Encode(values);if seen[key]==encoded then return end
    local hash=X.Store('merchant',values,source);if not hash then return end
    d.contentID=hash;d.family='merchant';d.scope='owner-private native business evidence'
    local e=X.Record('native_event',source,d,select(2,C.Owner()),false)
    if e then seen[key]=encoded end
    return e
end
function M.Auctions(source)
    if not ready() or not auctionOpen then return end
    local full=X.Bool(X.Call('C_AuctionHouse.HasFullOwnedAuctionResults'))
    local count=S.Integer(X.Call('C_AuctionHouse.GetNumOwnedAuctions'),0,5000)
    if full~=true or not count then X.Mark('Merchant auctions','Owned listings unavailable or partial; missing rows are not sales');return end
    local types=X.Table(Enum);types=types and X.Table(types.AuctionStatus)
    for i=1,count do
        local r=X.Table(X.Call('C_AuctionHouse.GetOwnedAuctionInfo',i));local id=r and S.Integer(r.auctionID,1)
        if id then
            local phase=types and types.Sold==r.status and 'sold' or types and types.Active==r.status and 'active' or 'unknown'
            local item=X.Table(r.itemKey)
            save('auction:'..id,{auctionID=id,itemID=item and S.Integer(item.itemID,1),quantity=S.Integer(r.quantity,1),
                status=phase,bidCopper=S.Integer(r.bidAmount,0),buyoutCopper=S.Integer(r.buyoutAmount,0),
                timeLeftSeconds=S.Number(r.timeLeftSeconds,0),fullResults=true},
                {recordType='auction_owned_observed',auctionID=id,phase=phase,partial=false},source)
        end
        X.Yield()
    end
    X.Mark('Merchant auctions','Own listings observed; sold status is not payment received')
end
function M.Invoices(source)
    if not ready() or not mailOpen then return end
    local count=S.Integer(X.Call('GetInboxNumItems'),0,5000)
    if not count then X.Mark('Merchant invoices','Inbox invoice API unavailable');return end
    -- Invoice API has no durable message/auction ID. Preserve ambiguous source
    -- observations without adding them to sales or payment/revenue totals.
    for i=1,count do
        local kind,name,_,bid,buyout,deposit,cut,delay,_,_,quantity=X.Call('GetInboxInvoiceInfo',i)
        if kind=='seller' or kind=='seller_temp_invoice' then
            local v={invoiceKind=kind,itemName=S.Text(name,144),bidCopper=S.Integer(bid,0),buyoutCopper=S.Integer(buyout,0),
                depositCopper=S.Integer(deposit,0),cutCopper=S.Integer(cut,0),delaySeconds=S.Number(delay,0),quantity=S.Integer(quantity,1),ambiguous=true}
            local fingerprint=ns.ChronicleBackup.Encode(v)
            save('invoice:'..fingerprint,v,{recordType='auction_invoice_observed',phase='seller invoice observed; payment collection unverified',partial=true},source)
        end
        X.Yield()
    end
end
local function tradeRead()
    if not ready() or not trade then return end
    local v={tradeRef=trade.ref,partnerGUID=S.GUID(X.Call('UnitGUID','NPC')),offeredCopper=S.Integer(X.Call('GetPlayerTradeMoney'),0),
        requestedCopper=S.Integer(X.Call('GetTargetTradeMoney'),0),items={}}
    for side,api in ipairs({'GetTradePlayerItemInfo','GetTradeTargetItemInfo'}) do
        for slot=1,6 do
            local name,_,quantity=X.Call(api,slot)
            local link=X.Call(side==1 and 'GetTradePlayerItemLink' or 'GetTradeTargetItemLink',slot)
            local id=ns.CanRead(link) and tonumber(link:match('item:(%d+)')) or nil
            if S.Integer(id,1) and S.Integer(quantity,1) then v.items[#v.items+1]={side,slot,id,quantity,S.Text(name,144) or false} end
        end
    end
    trade.values=v
end
function M.Start()
    own=C.Owner();seen={};auctionOpen=false;mailOpen=false;trade=nil
    if not M.Selected() then return end
    X.Queue('merchant-seed',function()
        local c=S.WriterCharacter(own,false)
        for i,e in ipairs(c and c.events or {}) do
            local d=e.details
            if e.capture and e.capture.family=='merchant' then
                local v=e.capture.values;local encoded=ns.ChronicleBackup.Encode(v)
                if v.auctionID then seen['auction:'..v.auctionID]=encoded
                elseif v.invoiceKind then seen['invoice:'..encoded]=encoded end
            end
            if i%128==0 then X.Yield() end
        end
    end,true)
end
function M.Stop() own=nil;seen={};auctionOpen=false;mailOpen=false;trade=nil;projection=nil end
-- Rebuildable business history over accepted source IDs; never a second saved
-- ledger. Positive wallet deltas are deliberately not summed as earnings.
function M.Query(consumer,owner)
    if consumer~='chronicle' or not ns.Athena.Enabled(consumer) or owner~=C.Owner() then return nil,'DENIED' end
    local c,status=S.Character(owner,false);if not c then S.RequestCharacter(owner);return nil,status end
    local p=projection
    if not p or p.character~=c or p.offset>#c.events or p.offset>0 and c.events[p.offset].id~=p.highwater then
        p={character=c,owner=owner,offset=0,auctions={},trades=0,invoices=0,milestones={},thresholds={},sources={}};projection=p
    end
    for i=p.offset+1,math.min(#c.events,p.offset+512) do
        local e=c.events[i];local d=e.details
        if (e.kind=='character_snapshot' and S.Integer(d.copper,0)) or e.kind=='money_change' and S.Integer(d.after,0) then
            p.balance=e.kind=='money_change' and d.after or d.copper;p.balanceAt=e.at;p.balanceSource=e.id
            if e.kind=='money_change' and S.Integer(d.before,0) and d.after>d.before then
                for _,threshold in ipairs({1000000,10000000,100000000,1000000000}) do
                    if d.before<threshold and d.after>=threshold and not p.thresholds[threshold] then
                        p.thresholds[threshold]=true;p.milestones[#p.milestones+1]={copper=threshold,at=e.at,sourceID=e.id}
                    end
                end
            end
        elseif d.recordType=='auction_owned_observed' then p.auctions[d.auctionID]={phase=d.phase,at=e.at,sourceID=e.id}
        elseif d.recordType=='trade_completed_observed' then p.trades=p.trades+1;p.lastTrade=e.id
        elseif d.recordType=='auction_invoice_observed' then p.invoices=p.invoices+1 end
        p.offset=i;p.highwater=e.id
    end
    p.active=0;p.sold=0;p.unknown=0
    for _,a in pairs(p.auctions) do local key=a.phase=='active' and 'active' or a.phase=='sold' and 'sold' or 'unknown';p[key]=p[key]+1 end
    p.complete=p.offset==#c.events;return p,p.complete and 'READY' or 'INDEXING'
end
function M.Handle(event,a,b)
    if not ready() then return end
    if event=='AUCTION_HOUSE_SHOW' then auctionOpen=true
    elseif event=='AUCTION_HOUSE_CLOSED' then auctionOpen=false
    elseif event=='MAIL_SHOW' then mailOpen=true
    elseif event=='MAIL_CLOSED' then mailOpen=false
    elseif event=='TRADE_SHOW' then trade={ref=(X.runID or 'unknown')..'/'..tostring(C.Tick())};tradeRead()
    elseif event=='TRADE_PLAYER_ITEM_CHANGED' or event=='TRADE_TARGET_ITEM_CHANGED' or event=='TRADE_MONEY_CHANGED' or event=='TRADE_ACCEPT_UPDATE' then tradeRead()
    elseif event=='TRADE_REQUEST_CANCEL' then trade=nil
    elseif event=='TRADE_CLOSED' then if trade then trade.closed=C.Tick() end
    elseif event=='UI_INFO_MESSAGE' then
        local message=ns.CanRead(b) and b
        if trade and ns.CanRead(ERR_TRADE_COMPLETE) and message==ERR_TRADE_COMPLETE and (not trade.closed or C.Tick()-trade.closed<=2) then
            -- Only native success establishes completion. Accepted flags and
            -- window-close never enter this path. Snapshot remains partial.
            local values=trade.values;trade=nil
            if values then save('trade:'..values.tradeRef,values,{recordType='trade_completed_observed',phase='native trade success',partial=true},event) end
        end
    end
    if auctionOpen and (event=='AUCTION_HOUSE_SHOW' or event=='OWNED_AUCTIONS_UPDATED') then X.Queue('merchant-auctions',function() M.Auctions(event) end,true) end
    if mailOpen and (event=='MAIL_SHOW' or event=='MAIL_INBOX_UPDATE') then X.Queue('merchant-invoices',function() M.Invoices(event) end,true) end
end
