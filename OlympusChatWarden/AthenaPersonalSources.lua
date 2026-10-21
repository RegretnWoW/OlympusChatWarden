-- Own native outcome/window notices only. No trade contents, mail bodies,
-- recipient strings, remote auctions, balances or inferred completed exchange.
local _,ns=...
local C,S,X=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture
local P={};ns.AthenaPersonalSources=P
P.sources={MAIL_SEND_SUCCESS=true,MAIL_SUCCESS=true,AUCTION_HOUSE_AUCTION_CREATED=true,
    TRADE_SHOW=true,TRADE_ACCEPT_UPDATE=true,TRADE_CLOSED=true,TRADE_REQUEST_CANCEL=true,PARTY_INVITE_REQUEST=true,PARTY_INVITE_CANCEL=true,
    TAXIMAP_OPENED=true,TAXIMAP_CLOSED=true}
local own,sequence,trade,taxi=nil,0,nil,false
function P.Start() own=C.Owner();sequence=0;trade=nil;taxi=false end
function P.Stop() own=nil;trade=nil;taxi=false end
function P.Handle(event,a,b)
    if not C.PersonalEnabled() or not X.Ready() or own~=C.Owner() or not P.sources[event] then return end
    local phase,scope,provisional
    local auction,playerAccepted,targetAccepted
    if event=='TRADE_SHOW' then if trade then return end;trade={};phase='Trade window observed';scope='own trade UI opened; transfer not established'
    elseif event=='TRADE_ACCEPT_UPDATE' then
        if not trade then return end
        local player=S.Integer(a,0,1);local target=S.Integer(b,0,1)
        if player==nil and target==nil then return end
        local signature=tostring(player)..'/'..tostring(target);if trade.accept==signature then return end;trade.accept=signature
        if player~=nil then playerAccepted=player==1 end;if target~=nil then targetAccepted=target==1 end
        phase='Trade acceptance state observed';scope='native acceptance flags only; completed transfer unknown';provisional=true
    elseif event=='TRADE_CLOSED' or event=='TRADE_REQUEST_CANCEL' then
        if not trade then return end;trade=nil;phase=event=='TRADE_CLOSED' and 'Trade window closed' or 'Trade request cancelled';scope='native window boundary; no completed transfer inferred'
    elseif event=='MAIL_SEND_SUCCESS' or event=='MAIL_SUCCESS' then phase=event=='MAIL_SEND_SUCCESS' and 'Own mail send success notice' or 'Own mail action success notice';scope='own native success notice; delivery, contents and value unknown'
    elseif event=='AUCTION_HOUSE_AUCTION_CREATED' then auction=S.Integer(a,1);phase='Own auction listing created notice';scope='native listing notice; no sale or revenue inferred';provisional=auction==nil
    elseif event=='PARTY_INVITE_REQUEST' or event=='PARTY_INVITE_CANCEL' then phase=event=='PARTY_INVITE_REQUEST' and 'Group invitation received' or 'Group invitation cancelled';scope='own invitation notice; sender identity and accepted membership unknown';provisional=true
    elseif event=='TAXIMAP_OPENED' then if taxi then return end;taxi=true;phase='Taxi map opened';scope='native travel UI only; no flight or first discovery inferred'
    elseif event=='TAXIMAP_CLOSED' then if not taxi then return end;taxi=false;phase='Taxi map closed';scope='native travel UI only; no flight or first discovery inferred' end
    if not phase or S.GUID(X.Call('UnitGUID','player'))~=select(2,C.Owner()) then return end
    sequence=sequence+1
    X.Record('native_event',event,{recordType='personal_source',phase=phase,auctionID=auction,playerAccepted=playerAccepted,targetAccepted=targetAccepted,attribution='SELF_ACTION',scope=scope,
        evidenceState=provisional and 'PROVISIONAL_OBSERVATION' or 'VERIFIED_FACT',interpretationVersion=1,sourceVersion=1,
        subjectEligibility='SELF',fieldReadability='Native event only; private fields not read',
        interpretationStatus=provisional and 'UNRESOLVED_INTERPRETATION' or 'RAW_OBSERVED',runID=X.runID,
        sourceOccurrenceKey='personal/'..sequence,coverage='Dated observed source; unobserved intervals unknown'},select(2,C.Owner()),false)
end
local events={};for event in pairs(P.sources) do events[#events+1]=event end
X.Register(P,events,'chronicle')
