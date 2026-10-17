-- Capability-gated preservation of own balances, lockouts and collections.
-- Initial catalogs are observations, never retroactive unlock events.
local _,ns=...
local C,S,X=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture
local G={};ns.ChronicleProgress=G
local balances,seen,added,lockSignature={},{},{},nil
local function Save(family,data,source,key,details)
    local hash=X.Store(family,data,source);if not hash then return end
    if seen[key]~=hash then
        details=details or {};details.recordType=details.recordType or family..'_observed'
        details.contentID=hash;details.family=family
        X.Record('native_event',source,details,nil,false);seen[key]=hash
    end
    return hash
end
function G.Currency(id,source,quantity,change,gain,destroy)
    if not X.Ready() or X.Busy() or not S.Integer(id,1,10000000) then return end
    local row=X.Table(X.Call('C_CurrencyInfo.GetCurrencyInfo',id))
    if not row or S.Integer(row.currencyID,1)~=id then balances[id]=nil;X.Mark('Currencies','Missing or mismatched native currency ID');return end
    local value=S.Number(row.quantity,0);if not value then balances[id]=nil;return end
    local data={currencyID=id,name=S.Text(row.name,144),quantity=value,maxQuantity=S.Number(row.maxQuantity,0),
        maxWeeklyQuantity=S.Number(row.maxWeeklyQuantity,0),quantityEarnedThisWeek=S.Number(row.quantityEarnedThisWeek,0),
        totalEarned=S.Number(row.totalEarned,0),isAccountWide=X.Bool(row.isAccountWide),catalogView='ID-bound balance; list discovery may be filtered or collapsed'}
    local before=balances[id]
    local scope=data.isAccountWide==true and 'account' or data.isAccountWide==false and 'character' or 'unknown'
    local comparable=before and before.scope==scope
    local details={recordType=comparable and before.quantity~=value and 'currency_changed' or 'currency_observed',
        currencyID=id,after=value,baseline=not comparable,scope=scope}
    if before and before.scope==details.scope and before.quantity~=value then details.before=before.quantity;details.delta=value-before.quantity end
    Save('currency',data,source,'currency:'..id,details)
    balances[id]={quantity=value,scope=details.scope}
end
function G.CurrencyList(source)
    local count=S.Integer(X.Call('C_CurrencyInfo.GetCurrencyListSize'),0,5000)
    if not count then X.Mark('Currencies','Currency list reader unavailable');return end
    -- Respect collapsed/filtered native lists. Do not expand headers or guess IDs.
    for i=1,count do
        local row=X.Table(X.Call('C_CurrencyInfo.GetCurrencyListInfo',i))
        local id=row and S.Integer(row.currencyID,1,10000000)
        if id and X.Bool(row.isHeader)==false then G.Currency(id,source) end
        X.Yield()
    end
end
function G.CurrencyEvent(id,quantity,change,gain,destroy)
    if not X.Ready() then return end
    id=S.Integer(id,1,10000000)
    if not id then X.Queue('currencies',function() G.CurrencyList('CURRENCY_DISPLAY_UPDATE') end);return end
    -- Copy the native payload immediately; enrichment may be delayed by combat.
    -- Its quantityChange remains separate from a later before/after getter delta.
    X.Record('native_event','CURRENCY_DISPLAY_UPDATE',{recordType='currency_changed',currencyID=id,
        after=S.Number(quantity,0),quantityChange=S.Number(change),quantityGainSource=S.Integer(gain,0),destroyReason=S.Integer(destroy,0)},nil,false)
    X.Queue('currency:'..id,function() G.Currency(id,'checkpoint') end)
end
function G.Lockouts(source)
    if not X.Ready() or X.Busy() then return end
    local count=S.Integer(X.Call('GetNumSavedInstances'),0,500)
    local bosses=S.Integer(X.Call('GetNumSavedWorldBosses'),0,500)
    if not count and not bosses then X.Mark('Lockouts','Saved-instance readers unavailable');return end
    local rows={};local complete=count~=nil and bosses~=nil;local at=C.Stamp();if not at then return end
    for i=1,count or 0 do
        -- First ten returns are verified in the pinned RaidInfoFrame UI. Later
        -- undocumented tuple fields are deliberately not treated as boss counts.
        local name,id,reset,difficulty,locked,extended,high,isRaid,maxPlayers,difficultyName=X.Call('GetSavedInstanceInfo',i)
        id=S.Integer(id,0);name=S.Text(name,144);reset=S.Number(reset,0)
        if id and name and reset then
            rows[#rows+1]={name,id,S.Integer(high,0) or false,S.Integer(difficulty,0) or false,X.Flag(locked),X.Flag(extended),
                X.Flag(isRaid),S.Integer(maxPlayers,0) or false,S.Text(difficultyName,144) or false,at+reset,false}
        else complete=false end
        X.Yield()
    end
    for i=1,bosses or 0 do
        local name,id,reset=X.Call('GetSavedWorldBossInfo',i);name=S.Text(name,144);id=S.Integer(id,0);reset=S.Number(reset,0)
        if name and id and reset then rows[#rows+1]={name,id,false,false,'true','unavailable','unavailable',false,false,at+reset,true}
        else complete=false end;X.Yield()
    end
    table.sort(rows,function(a,b) return ns.ChronicleBackup.Encode(a)<ns.ChronicleBackup.Encode(b) end)
    -- The list is chunked independently; all chunks and their count are labelled.
    local parts=math.max(1,math.ceil(#rows/12));local scope={}
    for part=1,parts do
        local chunk={};for i=(part-1)*12+1,math.min(#rows,part*12) do chunk[#chunk+1]=rows[i] end
        local hash=X.Store('lockout_list',{rows=chunk,complete=complete,instanceCount=count,worldBossCount=bosses},source)
        scope[#scope+1]=hash or 'unavailable'
        if hash and seen['lockouts:'..part]~=hash then
            X.Record('native_event',source,{recordType='lockout_list_observed',contentID=hash,family='lockout_list',part=part,parts=parts,partial=not complete},nil,false)
            seen['lockouts:'..part]=hash
        end
    end
    lockSignature=table.concat(scope,':');X.Mark('Lockouts',complete and 'Readable saved-instance snapshot; does not prove personal boss kills' or 'Partial saved-instance snapshot; missing rows are not removals')
end
local function Added(kind,id,source)
    local data={recordType='collection_added',collectionType=kind,collectionID=kind~='pet' and id or nil,
        battlePetGUID=kind=='pet' and id or nil,baseline=false,scope='collection-system'}
    local key=kind..':'..id
    if not added[key] then X.Record('native_event',source,data,nil,false);added[key]=true end
end
function G.Mount(id,source)
    if not X.Ready() or X.Busy() then return end
    local name,spell,icon,active,usable,origin,favorite,specific,faction,hidden,collected,returned=X.Call('C_MountJournal.GetMountInfoByID',id)
    if S.Integer(returned,1)~=id or X.Bool(collected)~=true then return end
    Save('collection',{collectionType='mount',collectionID=id,name=S.Text(name,144),spellID=S.Integer(spell,1),
        scope='collection-system',collected=true},source,'mount:'..id,{recordType='collection_observed',collectionType='mount',collectionID=id,baseline=true})
end
function G.Pet(id,source)
    if not X.Ready() or X.Busy() then return end
    if not S.Text(id,128) then return end
    local row=X.Table(X.Call('C_PetJournal.GetPetInfoTableByPetID',id));if not row then return end
    local species=S.Integer(row.speciesID,1);if not species then return end
    Save('collection',{collectionType='pet',battlePetGUID=id,speciesID=species,name=S.Text(row.name,144),
        creatureID=S.Integer(row.creatureID,1),displayID=S.Integer(row.displayID,1),petLevel=S.Integer(row.petLevel,0,1000),
        petType=S.Integer(row.petType,0,100),scope='collection-system',collected=true},source,'pet:'..id,
        {recordType='collection_observed',collectionType='pet',battlePetGUID=id,baseline=true})
end
function G.Toy(id,source)
    if not X.Ready() or X.Busy() then return end
    if X.Bool(X.Call('PlayerHasToy',id))~=true then return end
    local returned,name=X.Call('C_ToyBox.GetToyInfo',id)
    if S.Integer(returned,1)~=id then return end
    Save('collection',{collectionType='toy',collectionID=id,name=S.Text(name,144),scope='collection-system',collected=true,catalogView='Current filtered toy view or explicit new-toy event; not exhaustive'},
        source,'toy:'..id,{recordType='collection_observed',collectionType='toy',collectionID=id,baseline=true})
end
function G.Catalog(kind,source)
    if not X.Ready() or X.Busy() then return end
    if kind=='mount' then
        local ids=X.Table(X.Call('C_MountJournal.GetMountIDs'))
        if not ids or not S.Array(ids,20000) then X.Mark('Mounts','Owned catalog API unavailable');return end
        for _,id in ipairs(ids) do id=S.Integer(id,1);if id then G.Mount(id,source) end;X.Yield() end
        X.Mark('Mounts','Readable owned mount observations; initial catalog is not unlock history')
    elseif kind=='pet' then
        local ids=X.Table(X.Call('C_PetJournal.GetOwnedPetIDs'))
        if not ids or not S.Array(ids,20000) then X.Mark('Pets','Owned-pet catalog API unavailable');return end
        for _,id in ipairs(ids) do if S.Text(id,128) then G.Pet(id,source) end;X.Yield() end
        X.Mark('Pets','Readable owned pet observations; no private custom names or notes')
    elseif kind=='toy' then
        local count=S.Integer(X.Call('C_ToyBox.GetNumFilteredToys'),0,20000)
        if not count then X.Mark('Toys','Toy catalog reader unavailable');return end
        for i=1,count do local id=S.Integer(X.Call('C_ToyBox.GetToyFromIndex',i),1);if id then G.Toy(id,source) end;X.Yield() end
        X.Mark('Toys','Filtered native view only; no filter changes or inferred removals')
    end
end
function G.Start()
    balances={};seen={};added={};lockSignature=nil
    X.Queue('currencies',function() G.CurrencyList('control') end)
    X.Queue('lockouts',function() G.Lockouts('control') end)
    for _,v in ipairs({'mount','pet','toy'}) do local kind=v;X.Queue('catalog:'..kind,function() G.Catalog(kind,'control') end) end
end
function G.Stop() balances={};seen={};added={};lockSignature=nil end
function G.Handle(event,a,b,c,d,e)
    if event=='CURRENCY_DISPLAY_UPDATE' then G.CurrencyEvent(a,b,c,d,e)
    elseif event=='UPDATE_INSTANCE_INFO' then X.Queue('lockouts',function() G.Lockouts(event) end)
    elseif event=='NEW_MOUNT_ADDED' or event=='NEW_TOY_ADDED' then
        local id=S.Integer(a,1);local kind=event=='NEW_MOUNT_ADDED' and 'mount' or 'toy'
        if id then Added(kind,id,event);X.Queue(kind..':'..id,function() if kind=='mount' then G.Mount(id,event) else G.Toy(id,event) end end) end
    elseif event=='NEW_PET_ADDED' then
        local id=S.Text(a,128);if id then Added('pet',id,event);X.Queue('pet:'..id,function() G.Pet(id,event) end) end
    elseif event=='PET_JOURNAL_LIST_UPDATE' then X.Queue('catalog:pet',function() G.Catalog('pet',event) end)
    elseif event=='TOYS_UPDATED' then X.Queue('catalog:toy',function() G.Catalog('toy',event) end) end
end
X.Register(G,{'CURRENCY_DISPLAY_UPDATE','UPDATE_INSTANCE_INFO','NEW_MOUNT_ADDED','NEW_TOY_ADDED','NEW_PET_ADDED','PET_JOURNAL_LIST_UPDATE','TOYS_UPDATED'})
