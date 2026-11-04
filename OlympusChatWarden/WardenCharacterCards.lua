-- Reusable, dated identity/appearance cards for important people. No crowd scan,
-- remote health, fabricated face, or second character-history database.
local _,ns=...
local G={VERSION=1};ns.WardenCharacterCards=G
local S,X,C=ns.ChronicleStore,ns.ChronicleCapture,ns.Chronicle
local atlas={WARRIOR={0,.25,0,.25},MAGE={.25,.49609375,0,.25},ROGUE={.49609375,.7421875,0,.25},DRUID={.7421875,.98828125,0,.25},
 HUNTER={0,.25,.25,.5},SHAMAN={.25,.49609375,.25,.5},PRIEST={.49609375,.7421875,.25,.5},WARLOCK={.7421875,.98828125,.25,.5},PALADIN={0,.25,.5,.75}}
function G.Capture(guid,data,appearance,gear,traits,source)
 if not X.Ready() or X.Busy() or not ns.AthenaEnrichment.Priority(guid) then return end
 local v={guid=guid,portraitKind='class-emblem',exact=false}
 for _,key in ipairs({'name','realm','class','race','guild','faction'}) do v[key]=S.Text(data and data[key],144) end
 for _,key in ipairs({'level','raceID','classID','sex'}) do v[key]=S.Integer(data and data[key],1,1000) end
 if not v.name then return end
 for key,spec in pairs({appearanceRef={appearance,'appearance'},gearRef={gear,'gear'},traitRef={traits,'traits'}}) do
  local object=spec[1] and X.Find(C.Owner(),spec[1])
  if object and object.capture.family==spec[2] and object.capture.values.guid==guid then v[key]=spec[1] end
 end
 return X.Store('character_card',v,source)
end
function G.FromState(st,guid,at)
 if not st or not S.GUID(guid) then return end
 local p=st.intelligence and st.intelligence.players[guid];local best
 -- Only the existing accepted important-player links can authorize a card.
 for _,id in ipairs(p and p.evidence or {}) do local e=st.events[id];local d=e and e.details
  if e and e.kind=='important_player' and d.cardRef and (not at or e.at<=at) and (not best or e.at>best.at) then
   local object=X.Find(st.owner,d.cardRef)
   if object and (not at or object.at<=at) and object.capture.family=='character_card' and object.capture.values.guid==guid then
    best={values=object.capture.values,at=e.at,sourceRef=e.id,owner=st.owner,guid=guid}
   end
  end
 end
 return best
end
function G.Icon(texture,class)
 texture:SetTexture('Interface\\Icons\\INV_Misc_Book_09');texture:SetTexCoord(0,1,0,1)
 local coords=ns.Readable(CLASS_ICON_TCOORDS) and type(CLASS_ICON_TCOORDS)=='table' and CLASS_ICON_TCOORDS[class or ''] or atlas[class or '']
 if ns.Readable(coords) and type(coords)=='table' then
  local a,b,c,d=S.Number(coords[1]),S.Number(coords[2]),S.Number(coords[3]),S.Number(coords[4])
  if a and b and c and d then texture:SetTexture('Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES');texture:SetTexCoord(a,b,c,d) end
 end
end
function G.Portrait(texture,card)
 G.Icon(texture,card.values.class)
 if card.owner~=C.Owner() or not ns.Membership.Allowed() or X.Busy() or type(SetPortraitTexture)~='function' then return false end
 local unit=ns.WardenDossier and ns.WardenDossier.Resolve(card.guid)
 if not unit or S.GUID(X.Call('UnitGUID',unit))~=card.guid then return false end
 local ok=pcall(SetPortraitTexture,texture,unit)
 if not ok or S.GUID(X.Call('UnitGUID',unit))~=card.guid then G.Icon(texture,card.values.class);return false end
 texture:SetTexCoord(0,1,0,1);return true
end
function G.Build(parent,width)
 local V=ns.Art;local f=V.Panel(parent,0,0,width or 340,94,'dark')
 f.icon=f:CreateTexture(nil,'ARTWORK');f.icon:SetPoint('TOPLEFT',12,-15);f.icon:SetSize(56,56)
 f.name=V.Text(f,'',80,-10,(width or 340)-94,17,V.gold);f.name:SetHeight(24);f.name:SetWordWrap(false)
 f.identity=V.Text(f,'',80,-36,(width or 340)-94,13,V.blue);f.identity:SetHeight(21);f.identity:SetWordWrap(false)
 f.guild=V.Text(f,'',80,-59,(width or 340)-94,12,V.muted);f.guild:SetHeight(23);f.guild:SetWordWrap(false)
 function f:SetCard(card)
  self.card=card;self:SetShown(card~=nil);if not card then return end
  local v=card.values;local live=G.Portrait(self.icon,card);self.name:SetText(v.name or 'Recorded companion')
  self.identity:SetText((v.level and 'Level '..v.level..' • ' or '')..(v.race or '')..' '..(v.class or 'Class unknown'))
  self.guild:SetText(v.guild and '<'..v.guild..'>' or 'Guild not recorded')
  ns.Theme.Tooltip(self,'Recorded character card','Identity observed at '..tostring(card.at)..(live and '. Portrait shows the currently visible person.' or '. The class emblem is illustrative; exact offline face unavailable.')..' Gear and appearance references retain their original dates.')
 end
 f:Hide();return f
end
