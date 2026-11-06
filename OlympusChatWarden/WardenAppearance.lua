-- Explicit owner-authored appearance recipe, carried in the existing signed
-- Aether OWNER record. No passive collection, new database or trust shortcut.
local _,ns=...
local A={VERSION=1};ns.WardenAppearance=A
local function integer(v,a,b)return ns.Readable(v)and type(v)=='number'and v==v and v%1==0 and v>=a and v<=b end
local function plain(v)return ns.Readable(v)and type(v)=='table'and not getmetatable(v)end
local function shape(v,keys)if not plain(v)then return false end;for k in pairs(v)do if not keys[k]then return false end end;return true end
local function dense(v,maximum)
 if not plain(v)then return false end;local n=0;for k in pairs(v)do if not integer(k,1,maximum)then return false end;n=n+1 end
 for i=1,n do if v[i]==nil then return false end end;return n<=maximum
end
function A.Valid(v)
 if not shape(v,{version=true,client=true,observedAt=true,raceID=true,sex=true,nativeDisplayID=true,slots=true,choices=true,choiceSource=true})or v.version~=1
  or(v.client~='forever'and v.client~='retail-test')or not integer(v.observedAt,1,4102444800)or not integer(v.raceID,1,1000)
  or(v.sex~=2 and v.sex~=3)or v.nativeDisplayID~=nil and not integer(v.nativeDisplayID,1,1000000000)
  or not dense(v.slots,19)or #v.slots~=19 or not dense(v.choices,64)or(v.choiceSource~='unavailable'and v.choiceSource~='barber-current')then return false end
 for i,row in ipairs(v.slots)do if not dense(row,3)or #row~=3 or row[1]~=i or(row[2]~='present'and row[2]~='empty'and row[2]~='unknown')or(row[2]=='present'and not integer(row[3],1,1000000000))or(row[2]~='present'and row[3]~=false)then return false end end
 local seen={};for _,pair in ipairs(v.choices)do if not dense(pair,2)or #pair~=2 or not integer(pair[1],1,1000000000)or not integer(pair[2],1,1000000000)or seen[pair[1]]then return false end;seen[pair[1]]=true end
 return v.choiceSource~='unavailable'or #v.choices==0
end
function A.Capture(key)
 if not ns.Permissions.Decide('UIAccess')or key~=ns.PlayerCard.Own()or ns.SafeCall(UnitGUID,'player')~=key then return nil,'Only your own readable appearance can be shared.'end
 -- SafeCall deliberately returns one value. UnitRace's numeric ID is third.
 local ok,_,_,race=pcall(UnitRace,'player');if not ok or not ns.Readable(race)then race=nil end
 local sex=ns.SafeCall(UnitSex,'player')
 local d={version=1,client=ns.ClientCompat.IsRetailTest()and'retail-test'or'forever',observedAt=ns.SafeCall(GetServerTime)or ns.SafeCall(time),raceID=race,sex=sex,slots={},choices={},choiceSource='unavailable'}
 local display=C_PlayerInfo and ns.SafeCall(C_PlayerInfo.GetNativeDisplayID);if integer(display,1,1000000000)then d.nativeDisplayID=display end
 for slot=1,19 do
  local good,item=pcall(function()return GetInventoryItemID('player',slot)end);local texOK,texture=pcall(function()return GetInventoryItemTexture('player',slot)end)
  local state=good and integer(item,1,1000000000)and'present'or good and texOK and ns.Readable(item)and ns.Readable(texture)and item==nil and texture==nil and'empty'or'unknown'
  d.slots[slot]={slot,state,state=='present'and item or false}
 end
 -- Native display preferences are part of visible equipment. Unknown settings
 -- stay unknown; hiding a known slot does not invent an item appearance.
 for _,slot in ipairs({1,15})do
  local visible=ns.SafeCall(slot==1 and ShowingHelm or ShowingCloak)
  if visible==false then d.slots[slot]={slot,'empty',false}end
 end
 -- Read only current, unapplied-change-free barber selections. Outside that
 -- supported context, retain explicit unknowns instead of guessed face/hair.
 local barber=C_BarberShop
 if barber and ns.SafeCall(barber.HasAnyChanges)==false then
  local categories=ns.SafeCall(barber.GetAvailableCustomizations)
  if plain(categories)and #categories<=16 then local seen={};local valid=true
   for _,category in ipairs(categories)do if plain(category)and plain(category.options)and #category.options<=64 then
    for _,option in ipairs(category.options)do local choices=plain(option)and option.choices;local at=plain(option)and option.currentChoiceIndex
     local choice=plain(choices)and integer(at,1,#choices)and choices[at]
     if plain(choice)and integer(option.id,1,1000000000)and integer(choice.id,1,1000000000)and not seen[option.id]then
      if #d.choices>=64 then valid=false;break end;seen[option.id]=true;d.choices[#d.choices+1]={option.id,choice.id}
     end
    end
   end end
   if valid and #d.choices>0 then d.choiceSource='barber-current'else d.choices={}end
  end
 end
 if ns.SafeCall(UnitGUID,'player')~=key or not A.Valid(d)then return nil,'The client did not provide a stable supported appearance recipe.'end
 return d
end
-- Live can announce a reliable body while inventory/customization capture is
-- unavailable. Unknown equipment stays unknown; this recipe is never saved.
function A.Minimal(key)
 if not ns.Permissions.Decide('UIAccess')or key~=ns.PlayerCard.Own()or ns.SafeCall(UnitGUID,'player')~=key then return end
 local ok,_,_,race=pcall(UnitRace,'player');local sex=ns.SafeCall(UnitSex,'player')
 if not ok or not integer(race,1,1000)or(sex~=2 and sex~=3)then return end
 local d={version=1,client=ns.ClientCompat.IsRetailTest()and'retail-test'or'forever',observedAt=ns.SafeCall(GetServerTime)or ns.SafeCall(time),raceID=race,sex=sex,slots={},choices={},choiceSource='unavailable'}
 for i=1,19 do d.slots[i]={i,'unknown',false}end
 if ns.SafeCall(UnitGUID,'player')==key and A.Valid(d)then return d end
end
-- Appearance V2 is a volatile Live recipe, never an OWNER/Relay record. The
-- optional source is the owner's already-loaded comparison model in the Lab.
function A.ValidLive(v)
 if not shape(v,{version=true,body=true,formID=true,formDisplayID=true,visuals=true,enchants=true})or v.version~=2 or not A.Valid(v.body)
  or not integer(v.formID,0,1000)or not integer(v.formDisplayID,0,1000000000)or not dense(v.visuals,19)or not dense(v.enchants,19)then return false end
 for _,group in ipairs({{v.visuals,4},{v.enchants,2}})do local seen={}
  for _,row in ipairs(group[1])do if not dense(row,group[2])or #row~=group[2]or not integer(row[1],1,19)or seen[row[1]]then return false end;seen[row[1]]=true
   for i=2,group[2]do if not integer(row[i],0,1000000000)then return false end end
  end
 end;return true
end
function A.CaptureLive(source)
 local body,why=A.Capture(ns.SafeCall(UnitGUID,'player'));if not body then return nil,why end
 local form=ns.SafeCall(GetShapeshiftFormID)
 local v={version=2,body=body,formID=integer(form,0,1000)and form or 0,formDisplayID=0,visuals={},enchants={}}
 if source and type(source.GetDisplayInfo)=='function'then local ok,id=pcall(source.GetDisplayInfo,source);if ok and integer(id,1,1000000000)then v.formDisplayID=id end end
 for slot=1,19 do
  if source and type(source.GetItemTransmogInfo)=='function'then
   local ok,info=pcall(source.GetItemTransmogInfo,source,slot)
   if ok and ns.Readable(info)and type(info)=='table'then
    local ap,secondary,illusion=info.appearanceID,info.secondaryAppearanceID or 0,info.illusionID or 0
    if integer(ap,0,1000000000)and integer(secondary,0,1000000000)and integer(illusion,0,1000000000)then v.visuals[#v.visuals+1]={slot,ap,secondary,illusion}end
   end
  end
  local link=ns.SafeCall(GetInventoryItemLink,'player',slot)
  if ns.Readable(link)and type(link)=='string'then local enchant=tonumber(link:match('item:%d+:(%d+):'))
   if integer(enchant,1,1000000000)then v.enchants[#v.enchants+1]={slot,enchant}end
  end
 end
 if A.ValidLive(v)then return v end;return nil,'A supported Live appearance could not be captured.'
end
function A.Shared(guid)
 local N=ns.AetherNet;local c=N and N.Cached and N.Cached();if not c then return end
 local view=c:View('CHARACTER',guid);local owner=view and view.owner;local d=owner and owner.appearance
 if not d or owner.authentication~='AUTHENTICATED'or d.client~=(ns.ClientCompat.IsRetailTest()and'retail-test'or'forever')or not A.Valid(d)then return end
 if N.MutedAuthors and N.MutedAuthors()[owner.principal]then return end
 return d
end
