-- Read-only loadouts. An observation after a fight never claims to be fight-time gear.
local _,ns=...
local C,S,X=ns.Chronicle,ns.ChronicleStore,ns.ChronicleCapture
local L={};ns.ChronicleLoadout=L
local generation,emptyHints,lastGear,traitRevision,extraSeen=0,{},nil,0,{}
local function Stable(unit,guid) return S.GUID(X.Call('UnitGUID',unit))==guid end
function L.Gear(unit,guid,source,guard)
    if not X.Ready() or X.Busy() or not Stable(unit,guid) then return end
    local slots,itemGUIDs={},{};local known=false
    for i=1,19 do
        local id=S.Integer(X.Call('GetInventoryItemID',unit,i),1,1000000000)
        local link=X.Call('GetInventoryItemLink',unit,i)
        local item=id and ns.ChronicleEvidence.ItemString(link,id)
        local state='unavailable'
        if id then state=item and 'present' or 'pending';known=true
        elseif unit=='player' and emptyHints[i] then state='empty';known=true
        elseif X.API('GetInventoryItemID') and X.API('GetInventoryItemLink') and X.API('GetInventoryItemTexture') then
            -- Multiple successful native nils can identify an empty own slot. For
            -- inspection nil also means unavailable, so never infer enemy empties.
            local fn=X.API('GetInventoryItemID');local ok,v=pcall(fn,unit,i)
            local ok2,v2=pcall(X.API('GetInventoryItemLink'),unit,i)
            local ok3,v3=pcall(X.API('GetInventoryItemTexture'),unit,i)
            if unit=='player' and ok and ok2 and ok3 and ns.Readable(v) and ns.Readable(v2) and ns.Readable(v3)
                and v==nil and v2==nil and v3==nil then state='empty';known=true end
        end
        slots[i]={i,state,id or false,item or false}
        itemGUIDs[i]=false
        if unit=='player' and id and ns.Readable(ItemLocation) and type(ItemLocation)=='table' and type(ItemLocation.CreateFromEquipmentSlot)=='function' then
            local ok,loc=pcall(ItemLocation.CreateFromEquipmentSlot,ItemLocation,i)
            local itemGUID=ok and S.Text(X.Call('C_Item.GetItemGUID',loc),128)
            if itemGUID and itemGUID:match('^Item%-%w[%w%-]*$') then itemGUIDs[i]=itemGUID end
        end
    end
    if not Stable(unit,guid) or not known or guard and not guard() then X.Mark('gear','No stable readable equipment baseline');return end
    -- Reject a loadout that changed while its slots were copied.
    for i,row in ipairs(slots) do
        local current=S.Integer(X.Call('GetInventoryItemID',unit,i),1,1000000000)
        if (row[2]=='present' or row[2]=='pending') and current~=row[3] or row[2]=='empty' and current~=nil then return end
        if row[2]=='present' and ns.ChronicleEvidence.ItemString(X.Call('GetInventoryItemLink',unit,i),current)~=row[4] then return end
    end
    if not Stable(unit,guid) or guard and not guard() then return end
    return X.Store('gear',{guid=guid,slots=slots,itemGUIDs=itemGUIDs},source)
end
function L.Appearance(unit,guid,source)
    if not X.Ready() or X.Busy() or not Stable(unit,guid) then return end
    local _,_,raceID=X.Call('UnitRace',unit);local _,_,classID=X.Call('UnitClass',unit)
    local data={guid=guid,raceID=S.Integer(raceID,1,1000),classID=S.Integer(classID,1,1000),
        sex=S.Integer(X.Call('UnitSex',unit),1,3),exact=false}
    if unit=='player' then
        data.nativeDisplayID=S.Integer(X.Call('C_PlayerInfo.GetNativeDisplayID'),1)
        data.displayID=S.Integer(X.Call('C_PlayerInfo.GetDisplayID'),1)
    end
    if not Stable(unit,guid) or not (data.raceID or data.nativeDisplayID) then return end
    return X.Store('appearance',data,source)
end
function L.Traits(source)
    if not X.Ready() or X.Busy() then return end
    local guid=S.GUID(X.Call('UnitGUID','player'));if not guid then return end
    local revision=traitRevision
    local configs={};local active=S.Integer(X.Call('C_ClassTalents.GetActiveConfigID'),1)
    if active then configs[active]=true end
    local constants=X.Table(Constants);local legacy=constants and X.Table(constants.LegacyConsts)
    if legacy then for _,key in ipairs({'LEGACY_TREE_PROFESSIONS_ID','LEGACY_TREE_ADVENTURE_ID','LEGACY_TREE_PROGRESSION_ID'}) do
        local tree=S.Integer(legacy[key],1);local config=tree and S.Integer(X.Call('C_Traits.GetConfigIDByTreeID',tree),1)
        if config then configs[config]=true end
    end end
    for config in pairs(configs) do
        -- Do not record staged choices as committed. Missing staged-state support
        -- remains unavailable rather than trusting UI preview values.
        if X.Bool(X.Call('C_Traits.ConfigHasStagedChanges',config))==false then
            local info=X.Table(X.Call('C_Traits.GetConfigInfo',config));local trees=info and X.Table(info.treeIDs)
            if trees and S.Array(trees,20) then for _,tree in ipairs(trees) do
                tree=S.Integer(tree,1);local ids=tree and X.Table(X.Call('C_Traits.GetTreeNodes',tree))
                if ids and S.Array(ids,1500) then
                    local rows={};local part=0;local parts=math.max(1,math.ceil(#ids/30))
                    local function flush()
                        if not Stable('player',guid) or revision~=traitRevision or X.Bool(X.Call('C_Traits.ConfigHasStagedChanges',config))~=false then return end
                        part=part+1
                        local hash=X.Store('traits',{guid=guid,configID=config,treeID=tree,nodes=rows,committed=true},source)
                        if hash then X.Record('native_event',source,{recordType='trait_tree_nodes',traitRef=hash,traitObservedAt=C.Stamp(),
                            part=part,parts=parts,partial=parts>1},nil,false) end
                        rows={}
                    end
                    for _,id in ipairs(ids) do
                        if revision~=traitRevision or X.Bool(X.Call('C_Traits.ConfigHasStagedChanges',config))~=false then return end
                        id=S.Integer(id,1);local node=id and X.Table(X.Call('C_Traits.GetNodeInfo',config,id))
                        local entry=node and X.Table(node.activeEntry)
                        local entryID=entry and S.Integer(entry.entryID,1);local rank=node and S.Integer(node.currentRank,0,1000)
                        if id and rank then rows[#rows+1]={id,entryID or false,rank} end
                        if #rows>=30 then flush() end;X.Yield()
                    end
                    if #rows>0 then flush() end
                end
            end end
        else X.Mark('traits','Unavailable or staged configuration; committed snapshot deferred') end
    end
end
function L.Milestone(source,reason)
    if not X.Ready() then return end
    local trigger=C.Stamp();local token=generation
    X.Queue('own-loadout',function()
        local guid=S.GUID(X.Call('UnitGUID','player'));if not guid or token~=generation then return end
        local gear=L.Gear('player',guid,source);local appearance=L.Appearance('player',guid,source);local at=C.Stamp()
        if gear then X.refs.gear={hash=gear,at=at} end
        if appearance then X.refs.appearance={hash=appearance,at=at} end
        if gear or appearance then
            -- Repeated unchanged checkpoints are coalesced; milestones keep their
            -- own dates even when they share immutable content.
            if reason~='equipment' or gear~=lastGear then
                X.Record('loadout_observed',source,{reason=reason,triggerAt=trigger,observedAt=at})
            end
            lastGear=gear
        end
        L.Stats(source,guid)
    end)
end
local function Extra(family,values,source,key)
    local hash=X.Store(family,values,source)
    if hash and extraSeen[key]~=hash then
        X.Record('native_event',source,{recordType=family..'_observed',contentID=hash,family=family});extraSeen[key]=hash
    end
end
function L.Stats(source,guid)
    if not X.Ready() or X.Busy() or not Stable('player',guid) then return end
    local data={guid=guid};local known=false
    for i,key in ipairs({'strength','agility','stamina','intellect','spirit'}) do
        local _,effective=X.Call('UnitStat','player',i);data[key]=S.Number(effective,0);if data[key] then known=true end
    end
    local _,armor=X.Call('UnitArmor','player');data.armor=S.Number(armor,0)
    data.healthMax=S.Number(X.Call('UnitHealthMax','player'),0);data.powerMax=S.Number(X.Call('UnitPowerMax','player'),0)
    data.powerType=S.Integer(X.Call('UnitPowerType','player'),0,100);data.crit=S.Number(X.Call('GetCritChance'),0);data.haste=S.Number(X.Call('GetHaste'))
    if (known or data.armor or data.healthMax) and Stable('player',guid) then Extra('stats',data,source,'stats') end
    local rows={}
    for slot=1,19 do
        local current,maximum=X.Call('GetInventoryItemDurability',slot)
        current=S.Integer(current,0);maximum=S.Integer(maximum,0)
        if current and maximum then rows[#rows+1]={slot,current,maximum} end
    end
    if #rows>0 and Stable('player',guid) then Extra('gear_condition',{guid=guid,slots=rows},source,'condition') end
end
function L.Sets(source)
    if not X.Ready() or X.Busy() or X.Bool(X.Call('C_EquipmentSet.CanUseEquipmentSets'))~=true then return end
    local guid=S.GUID(X.Call('UnitGUID','player'));local ids=X.Table(X.Call('C_EquipmentSet.GetEquipmentSetIDs'))
    if not guid or not ids or not S.Array(ids,100) then return end
    for _,id in ipairs(ids) do
        id=S.Integer(id,0);local name,_,setID,isEquipped
        if id then name,_,setID,isEquipped=X.Call('C_EquipmentSet.GetEquipmentSetInfo',id) end
        local items=id and X.Table(X.Call('C_EquipmentSet.GetItemIDs',id));local ignored=id and X.Table(X.Call('C_EquipmentSet.GetIgnoredSlots',id))
        if S.Text(name,144) and S.Integer(setID,0)==id and items and ignored then
            local slots,skip={},{}
            for slot=1,19 do slots[slot]=S.Integer(items[slot],0) or false;skip[slot]=X.Flag(ignored[slot]) end
            if Stable('player',guid) then Extra('equipment_set',{guid=guid,setID=id,name=name,items=slots,ignored=skip,isEquipped=X.Bool(isEquipped)},source,'set:'..id) end
        end
        X.Yield()
    end
end
function L.Barber(source)
    if not X.Ready() or X.Busy() then return end
    local guid=S.GUID(X.Call('UnitGUID','player'));local categories=X.Table(X.Call('C_BarberShop.GetAvailableCustomizations'))
    if not guid or not categories or not S.Array(categories,40) then return end
    local rows={}
    for _,category in ipairs(categories) do
        category=X.Table(category);local options=category and X.Table(category.options)
        if options and S.Array(options,100) then for _,option in ipairs(options) do
            option=X.Table(option);local id=option and S.Integer(option.id,1)
            local choices=option and X.Table(option.choices);local choiceIndex=option and S.Integer(option.currentChoiceIndex,1,1000)
            local choice=choices and choiceIndex and X.Table(choices[choiceIndex]);local choiceID=choice and S.Integer(choice.id,1)
            if id and choiceID then rows[#rows+1]={S.Integer(category.id,1) or false,S.Integer(category.chrModelID,1) or false,id,choiceID} end
        end end
    end
    if #rows>0 and Stable('player',guid) then
        local hash=X.Store('barber',{guid=guid,customizations=rows,exact=false},source)
        if hash then X.Record('native_event',source,{recordType='barber_choices_applied',contentID=hash,family='barber'}) end
    end
end
function L.Start()
    generation=generation+1;emptyHints={};lastGear=nil;extraSeen={}
    L.Milestone('control','recording baseline');X.Queue('traits',function() L.Traits('control') end)
    X.Queue('equipment-sets',function() L.Sets('control') end)
end
function L.Stop() generation=generation+1;emptyHints={};lastGear=nil;extraSeen={} end
function L.Handle(event,a,b)
    if event=='PLAYER_EQUIPMENT_CHANGED' then
        local slot=S.Integer(a,1,19);if slot then emptyHints[slot]=X.Bool(b)==false or nil end
        L.Milestone(event,'equipment')
    elseif event=='UNIT_INVENTORY_CHANGED' then if ns.CanRead(a) and a=='player' then L.Milestone(event,'equipment') end
    elseif event=='TRAIT_CONFIG_UPDATED' or event=='ACTIVE_COMBAT_CONFIG_CHANGED' or event=='TRAIT_CONFIG_LIST_UPDATED' then
        traitRevision=traitRevision+1;X.Queue('traits',function() L.Traits(event) end);L.Milestone(event,'talents changed')
    elseif event=='BARBER_SHOP_APPEARANCE_APPLIED' or event=='BARBER_SHOP_RESULT' and X.Bool(a)==true then
        -- Applied event is authoritative; merely opening/previewing is ignored.
        if event=='BARBER_SHOP_APPEARANCE_APPLIED' then L.Barber(event) end
        L.Milestone(event,'appearance applied')
    elseif event=='EQUIPMENT_SETS_CHANGED' then X.Queue('equipment-sets',function() L.Sets(event) end)
    elseif event=='UPDATE_INVENTORY_DURABILITY' or event=='UNIT_STATS' and ns.CanRead(a) and a=='player' then L.Milestone(event,'character condition')
    elseif event=='ITEM_DATA_LOAD_RESULT' then L.Milestone(event,'equipment')
    else L.Milestone(event,'milestone') end
end
X.Register(L,{'PLAYER_EQUIPMENT_CHANGED','UNIT_INVENTORY_CHANGED','ITEM_DATA_LOAD_RESULT','PLAYER_LEVEL_UP','PLAYER_DEAD',
    'ENCOUNTER_START','ENCOUNTER_END','BOSS_KILL','PVP_MATCH_COMPLETE','PLAYER_REGEN_ENABLED',
    'TRAIT_CONFIG_UPDATED','TRAIT_CONFIG_LIST_UPDATED','ACTIVE_COMBAT_CONFIG_CHANGED','BARBER_SHOP_APPEARANCE_APPLIED','BARBER_SHOP_RESULT',
    'EQUIPMENT_SETS_CHANGED','UPDATE_INVENTORY_DURABILITY','UNIT_STATS'})
