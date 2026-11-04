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
 local _,_,race=ns.SafeCall(UnitRace,'player');local sex=ns.SafeCall(UnitSex,'player')
 local d={version=1,client=ns.ClientCompat.IsRetailTest()and'retail-test'or'forever',observedAt=ns.SafeCall(GetServerTime)or ns.SafeCall(time),raceID=race,sex=sex,slots={},choices={},choiceSource='unavailable'}
 local display=C_PlayerInfo and ns.SafeCall(C_PlayerInfo.GetNativeDisplayID);if integer(display,1,1000000000)then d.nativeDisplayID=display end
 for slot=1,19 do
  local good,item=pcall(function()return GetInventoryItemID('player',slot)end);local texOK,texture=pcall(function()return GetInventoryItemTexture('player',slot)end)
  local state=good and integer(item,1,1000000000)and'present'or good and texOK and ns.Readable(item)and ns.Readable(texture)and item==nil and texture==nil and'empty'or'unknown'
  d.slots[slot]={slot,state,state=='present'and item or false}
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
function A.Shared(guid)
 local N=ns.AetherNet;local c=N and N.Cached and N.Cached();if not c or not N.Preference()or ns.Permissions.Denied('network')then return end
 local view=c:View('CHARACTER',guid);local owner=view and view.owner;local d=owner and owner.appearance
 if not d or owner.authentication~='AUTHENTICATED'or d.client~=(ns.ClientCompat.IsRetailTest()and'retail-test'or'forever')or not A.Valid(d)then return end
 if N.MutedAuthors and N.MutedAuthors()[owner.principal]then return end
 return d
end
