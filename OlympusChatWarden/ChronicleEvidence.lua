-- Read-only, own-character collectors. Missing/secret values stay unknown.
local _,ns=...
local C,S=ns.Chronicle,ns.ChronicleStore
local E={registered={},capabilities={},diagnostics={saved=0,unchanged=0,rejected=0,errors=0}};ns.ChronicleEvidence=E
local frame=CreateFrame('Frame');local owner,cache,jobs,queue=nil,{},{},{}
local function API(name)
    local a,b=name:match('^([^.]+)%.(.+)$');local value=a and _G[a] or _G[name]
    if a then value=ns.Readable(value) and type(value)=='table' and value[b] or nil end
    return type(value)=='function' and value or nil
end
local function Call(name,...)
    local fn=API(name);if not fn then return end
    local ok,a,b,c,d,e,f,g,h,i,j=pcall(fn,...)
    if ok then return a,b,c,d,e,f,g,h,i,j end
end
local function Bool(v)
    if not ns.Readable(v) then return end
    if v==true or v==1 then return true elseif v==false or v==0 then return false end
end
local function Table(v) return ns.Readable(v) and type(v)=='table' and not getmetatable(v) and v or nil end
local function Seen(family) E.capabilities[family]='Validated native values observed this session' end
local function Save(kind,key,data,source,evidence)
    if not C.InWorld() or owner~=C.Owner() or not next(data) then return end
    local encoded=ns.ChronicleBackup.Encode(data)
    if cache[key]==encoded then E.diagnostics.unchanged=E.diagnostics.unchanged+1;return end
    local event=C.Record(kind,source or 'checkpoint',data,nil,evidence or 'observed')
    if event then cache[key]=encoded;E.diagnostics.saved=E.diagnostics.saved+1;return event end
    E.diagnostics.rejected=E.diagnostics.rejected+1
end
local function Yield() coroutine.yield() end
local function Schedule(key,fn)
    if jobs[key] then jobs[key].again=fn;return end
    jobs[key]={thread=coroutine.create(fn)};queue[#queue+1]=key
end
function E.Pump()
    if not C.InWorld() or owner~=C.Owner() then return end
    if InCombatLockdown and InCombatLockdown() then return end
    -- Four rows per frame. Bursts coalesce by collector, never an unbounded timer queue.
    for _=1,4 do
        local key=queue[1];if not key then break end
        local job=jobs[key];local ok=coroutine.resume(job.thread)
        if not ok then E.diagnostics.errors=E.diagnostics.errors+1 end
        if not ok or coroutine.status(job.thread)=='dead' then
            table.remove(queue,1);jobs[key]=nil
            if job.again then Schedule(key,job.again) end
        end
    end
end
function E.ItemString(link,id)
    if not ns.CanRead(link) or #link>2048 then return end
    local value=link:match('|H(item:[^|]+)|h') or link:match('^(item:[%d:%-]+)$')
    if S.Text(value,512) and tonumber(value:match('^item:(%d+)'))==id then return value end
end
function E.Character(source)
    local version,build,buildDate,interface=Call('GetBuildInfo')
    local _,_,classID=Call('UnitClass','player');local _,_,raceID=Call('UnitRace','player')
    local data={locale=S.Text(Call('GetLocale'),16),clientVersion=S.Text(version,64),build=S.Text(build,32),
        buildDate=S.Text(buildDate,64),interface=S.Integer(interface,1),classID=S.Integer(classID,1,1000),raceID=S.Integer(raceID,1,1000),
        sex=S.Integer(Call('UnitSex','player'),1,3),restedXP=S.Integer(Call('GetXPExhaustion'),0),
        honor=S.Integer(Call('UnitHonor','player'),0),honorMax=S.Integer(Call('UnitHonorMax','player'),0),
        honorLevel=S.Integer(Call('UnitHonorLevel','player'),0)}
    if next(data) then Seen('Character');Save('character_detail','character',data,source) end
end
function E.State(source)
    local data={}
    local specs={afk={'UnitIsAFK','player'},dead={'UnitIsDead','player'},ghost={'UnitIsGhost','player'},
        mounted={'IsMounted'},swimming={'IsSwimming'},flying={'IsFlying'},onTaxi={'UnitOnTaxi','player'},
        inCombat={'UnitAffectingCombat','player'},inVehicle={'UnitInVehicle','player'},resting={'IsResting'},pvp={'UnitIsPVP','player'}}
    for k,spec in pairs(specs) do data[k]=Bool(Call(unpack(spec))) end
    if next(data) then Seen('Player state');Save('player_state','state',data,source) end
end
function E.Equipment(source,slot,hasCurrent)
    slot=S.Integer(slot,1,19);if not slot then return end
    local id=S.Integer(Call('GetInventoryItemID','player',slot),1,1000000000)
    if not id and hasCurrent~=false then return end -- nil getter alone never proves removal
    local data={slot=slot,itemID=id,hasCurrent=id and true or false}
    if id then data.itemString=E.ItemString(Call('GetInventoryItemLink','player',slot),id) end
    local key='equipment:'..slot;local previous=cache[key]
    if not previous and not id then return end
    Seen('Equipment');Save(previous and 'equipment_change' or 'equipment_observed',key,data,source)
end
local function Equipment(source)
    Schedule('equipment',function() for i=1,19 do E.Equipment(source,i);Yield() end end)
end
function E.Quests(source)
    if not API('C_QuestLog.GetInfo') or not API('C_QuestLog.GetNumQuestLogEntries') then return end
    Schedule('quests',function()
        local count=S.Integer(Call('C_QuestLog.GetNumQuestLogEntries'),0,1000);if not count then return end
        for i=1,count do
            local q=Table(Call('C_QuestLog.GetInfo',i));local id=q and S.Integer(q.questID,1,10000000)
            if id and Bool(q.isHeader)==false then
                local data={questID=id,title=S.Text(q.title,256),level=S.Integer(q.level,0,1000),
                    frequency=S.Integer(q.frequency,0,1000),suggestedGroup=S.Integer(q.suggestedGroup,0,1000)}
                Seen('Quests');Save('quest_observed','quest:'..id,data,source);Yield()
                local rows=Table(Call('C_QuestLog.GetQuestObjectives',id))
                if rows and #rows<=100 then for j,row in ipairs(rows) do
                    row=Table(row)
                    if row then
                        local d={questID=id,objective=j,title=S.Text(row.text,256),objectiveType=S.Text(row.type,64),
                            fulfilled=S.Integer(row.numFulfilled,0),required=S.Integer(row.numRequired,0),finished=Bool(row.finished)}
                        if d.fulfilled and d.required and d.finished~=nil then Save('quest_objective','objective:'..id..':'..j,d,source) end
                    end
                    Yield()
                end end
            end
            Yield()
        end
    end)
end
function E.Reputation(source)
    if not API('C_Reputation.GetFactionDataByIndex') then return end
    Schedule('reputation',function()
        local count=S.Integer(Call('C_Reputation.GetNumFactions'),0,2000);if not count then return end
        for i=1,count do
            local row=Table(Call('C_Reputation.GetFactionDataByIndex',i));local id=row and S.Integer(row.factionID,1,10000000)
            if id and (Bool(row.isHeader)==false or Bool(row.isHeaderWithRep)==true) then
                local data={factionID=id,name=S.Text(row.name,144),reaction=S.Integer(row.reaction,1,100),
                    standing=S.Integer(row.currentStanding),beforeMax=S.Integer(row.currentReactionThreshold),afterMax=S.Integer(row.nextReactionThreshold)}
                if data.standing then Seen('Reputation');Save('reputation_observed','reputation:'..id,data,source) end
            end
            Yield()
        end
    end)
end
function E.Bags(source)
    if not API('C_Container.GetContainerItemInfo') then return end
    Schedule('bags',function()
        for bag=0,4 do -- backpack and four ordinary bags; no closed-bank or account-bank guesses
            local count=S.Integer(Call('C_Container.GetContainerNumSlots',bag),0,200)
            if count then for slot=1,count do
                local ok,value=pcall(API('C_Container.GetContainerItemInfo'),bag,slot)
                local row=ok and Table(value)
                local id=row and S.Integer(row.itemID,1,1000000000);local quantity=row and S.Integer(row.stackCount,1,1000000)
                if id and quantity then
                    local data={bagID=bag,slot=slot,itemID=id,quantity=quantity,hasCurrent=true,itemString=E.ItemString(row.hyperlink,id),bound=Bool(row.isBound)}
                    Seen('Bag inventory');Save('inventory_observed','bag:'..bag..':'..slot,data,source)
                elseif ok and ns.Readable(value) and value==nil and cache['bag:'..bag..':'..slot]
                    and S.Integer(Call('C_Container.GetContainerNumSlots',bag),0,200)==count then
                    Save('inventory_observed','bag:'..bag..':'..slot,{bagID=bag,slot=slot,hasCurrent=false},source)
                end
                -- A documented empty slot is a slot state, never a transaction cause.
                Yield()
            end end
        end
    end)
end
function E.Spells(source)
    if not API('C_SpellBook.GetSpellBookSkillLineInfo') then return end
    local enums=ns.Readable(Enum) and type(Enum)=='table' and Enum.SpellBookSpellBank
    local bank=enums and S.Integer(enums.Player,0,100);if not bank then return end
    Schedule('spells',function()
        local count=S.Integer(Call('C_SpellBook.GetNumSpellBookSkillLines'),0,100);if not count then return end
        for i=1,count do
            local tab=Table(Call('C_SpellBook.GetSpellBookSkillLineInfo',i))
            local offset=tab and S.Integer(tab.itemIndexOffset,0,10000);local n=tab and S.Integer(tab.numSpellBookItems,0,1000)
            if offset and n then for slot=offset+1,offset+n do
                local row=Table(Call('C_SpellBook.GetSpellBookItemInfo',slot,bank));local id=row and S.Integer(row.spellID,1,10000000)
                if id and Bool(row.isOffSpec)==false then
                    local data={spellID=id,name=S.Text(row.name,144),rank=S.Text(row.subName,64),passive=Bool(row.isPassive),
                        actionID=S.Integer(row.actionID,1,10000000),skillLine=i}
                    Seen('Spellbook');Save('spell_observed','spell:'..id,data,source)
                end
                Yield()
            end end
            Yield()
        end
    end)
end
function E.Bind(source)
    local name=Call('GetBindLocation');if S.Text(name,144) then Seen('Bind location');Save('bind_observed','bind',{name=name},source) end
end
function E.Loot()
    -- Snapshot synchronously while the loot window exists; never calls LootSlot.
    local count=S.Integer(Call('GetNumLootItems'),0,100);if not count then return end
    for slot=1,count do
        local link=Call('GetLootSlotLink',slot)
        local id=ns.CanRead(link) and S.Integer(tonumber(link:match('|Hitem:(%d+)')),1,1000000000)
        local _,name,quantity=Call('GetLootSlotInfo',slot);quantity=S.Integer(quantity,1,1000000)
        if id and quantity then
            Seen('Loot offered');C.Record('loot_offered','LOOT_OPENED',{slot=slot,itemID=id,quantity=quantity,
                name=S.Text(name,144),itemString=E.ItemString(link,id)})
        end
    end
end
local families={Character={'GetBuildInfo','UnitSex'},['Player state']={'IsMounted','UnitIsAFK'},
    Equipment={'GetInventoryItemID'},Quests={'C_QuestLog.GetInfo','C_QuestLog.GetQuestObjectives'},
    Reputation={'C_Reputation.GetFactionDataByIndex'},['Bag inventory']={'C_Container.GetContainerItemInfo'},
    Spellbook={'C_SpellBook.GetSpellBookItemInfo'},['Loot offered']={'GetLootSlotLink','GetLootSlotInfo'},['Bind location']={'GetBindLocation'}}
function E.Support()
    local out={}
    for family,methods in pairs(families) do
        local present={};for _,name in ipairs(methods) do present[#present+1]=name..': '..(API(name) and 'present' or 'unavailable') end
        out[#out+1]={name=family,status=E.capabilities[family] or 'No validated values observed this session',methods=table.concat(present,'; ')}
    end
    if ns.ChronicleCapture then for family,status in pairs(ns.ChronicleCapture.status) do out[#out+1]={name=family,status=status,methods='Forever contract adapter; registration/synthetic tests do not establish native availability'} end end
    table.sort(out,function(a,b) return a.name<b.name end);return out
end
function E.Stop() owner=nil;cache={};jobs={};queue={};frame:SetScript('OnUpdate',nil) end
function E.Suspend() jobs={};queue={};frame:SetScript('OnUpdate',nil) end
function E.Start()
    if not C.Active() then return end
    if owner~=C.Owner() then E.Stop();owner=C.Owner() end
    E.Character('control');E.State('control');E.Bind('control');Equipment('control');E.Quests('control');E.Reputation('control');E.Bags('control');E.Spells('control')
    local elapsed=0;frame:SetScript('OnUpdate',function(_,delta)
        E.Pump();elapsed=elapsed+(S.Number(delta,0) or 0)
        if elapsed>=10 then elapsed=0;local ok=pcall(E.State,'checkpoint');if not ok then E.diagnostics.errors=E.diagnostics.errors+1 end end
    end)
end
function E.Handle(event,...)
    if not C.InWorld() or owner~=C.Owner() then return end
    local a,b,c=...
    if event=='PLAYER_EQUIPMENT_CHANGED' then E.Equipment(event,a,Bool(b))
    elseif event=='UNIT_INVENTORY_CHANGED' then if a=='player' then Equipment(event) end
    elseif event=='QUEST_ACCEPTED' then
        -- Modern: questID. Older documented contract: logIndex, questID.
        local id=S.Integer(b~=nil and b or a,1,10000000)
        if id then C.Record('quest_accepted',event,{questID=id},nil,'confirmed');E.Quests(event) end
    elseif event=='QUEST_REMOVED' then
        local id=S.Integer(a,1,10000000);if id then C.Record('quest_removed',event,{questID=id,wasReplayQuest=Bool(b)},nil,'confirmed') end
    elseif event=='QUEST_LOG_UPDATE' then E.Quests(event)
    elseif event=='UPDATE_FACTION' then E.Reputation(event)
    elseif event=='BAG_UPDATE_DELAYED' then E.Bags(event)
    elseif event=='SPELLS_CHANGED' then E.Spells(event)
    elseif event=='LEARNED_SPELL_IN_TAB' or event=='LEARNED_SPELL_IN_SKILL_LINE' then
        local id=S.Integer(a,1,10000000);if id then C.Record('spell_learned',event,{spellID=id,skillLine=S.Integer(b,1,1000),guildPerk=Bool(c)},nil,'confirmed') end
    elseif event=='ACHIEVEMENT_EARNED' then
        local id=S.Integer(a,1,10000000);if id then C.Record('achievement_earned',event,{achievementID=id,alreadyEarned=Bool(b)},nil,'confirmed') end
    elseif event=='LOOT_OPENED' then E.Loot()
    elseif event=='HEARTHSTONE_BOUND' then E.Bind(event)
    elseif event=='PLAYER_LEVEL_UP' or event=='UPDATE_EXHAUSTION' or event=='HONOR_XP_UPDATE' then E.Character(event)
    elseif (event=='PLAYER_FLAGS_CHANGED' or event=='UNIT_ENTERED_VEHICLE' or event=='UNIT_EXITED_VEHICLE') and a~='player' then return
    else E.State(event) end
end
local events={'PLAYER_EQUIPMENT_CHANGED','UNIT_INVENTORY_CHANGED','QUEST_ACCEPTED','QUEST_REMOVED','QUEST_LOG_UPDATE',
    'UPDATE_FACTION','BAG_UPDATE_DELAYED','SPELLS_CHANGED','LEARNED_SPELL_IN_TAB','LEARNED_SPELL_IN_SKILL_LINE',
    'ACHIEVEMENT_EARNED','LOOT_OPENED','HEARTHSTONE_BOUND','PLAYER_LEVEL_UP','UPDATE_EXHAUSTION','HONOR_XP_UPDATE',
    'PLAYER_FLAGS_CHANGED','PLAYER_ALIVE','PLAYER_UNGHOST','PLAYER_MOUNT_DISPLAY_CHANGED','PLAYER_REGEN_ENABLED',
    'PLAYER_REGEN_DISABLED','PLAYER_CONTROL_GAINED','PLAYER_CONTROL_LOST','UNIT_ENTERED_VEHICLE','UNIT_EXITED_VEHICLE'}
for _,event in ipairs(events) do E.registered[event]=pcall(frame.RegisterEvent,frame,event) end
frame:SetScript('OnEvent',function(_,event,...)
    local ok=pcall(E.Handle,event,...);if not ok then E.diagnostics.errors=E.diagnostics.errors+1 end
end)
