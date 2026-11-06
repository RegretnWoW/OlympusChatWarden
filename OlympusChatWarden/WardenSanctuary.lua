-- Owner-private cosmetics derived from accepted Athena evidence. The store is
-- journalArtifacts.owners[owner].sanctuary; overrides never write entitlements.
local _,ns=...
local Q={VERSION=1,queueLimit=48,preview=false,labBypass=false,pendingPets={}};ns.WardenSanctuary=Q
local M=ns.WardenMementos
local function plain(v)return type(v)=='table'and getmetatable(v)==nil end
local function count(v)local n=0;for _ in pairs(v or{})do n=n+1 end;return n end
local function current()return ns.Chronicle.Owner()end
local function permitted()return ns.Permissions.Decide('UIAccess')end
local function stamp()return ns.SafeCall(GetServerTime)or ns.SafeCall(time)or 0 end
Q.rewards={
 {id='guild',title='Olympus Standard',permanent=true,track='GuildFlag',reason='Always at home in your Sanctuary.'},
 {id='cat',title="Athena’s Cat",permanent=true,track='CatRest',reason='The study’s permanent resident.'},
 {id='owl',title='Owl Companion',track='OwlPerch',reason='Observe a documented owl in your owned companion collection.'},
 {id='rabbit',title='Rabbit Visitor',track='Rabbit',reason='Observe a documented rabbit in your owned companion collection.'},
 {id='bird',title='Birds of the Sanctuary',track='Bird',reason='Observe a documented bird companion in your collection.'},
 {id='moth',title='Glimmerwing Visitor',track='Moth',reason='Complete the documented Sprite Darter acquisition finale.'},
 {id='fox',title='Woodland Fox',track='Fox',reason='Collect five distinct companion species · a Fireside cosmetic milestone.'},
 {id='stag',title='Rare Woodland Stag',track='Stag',reason='Collect ten distinct companion species · a Fireside cosmetic milestone.'},
 {id='alliance',title='Alliance Standards',track='AllianceFlag',reason='Complete every battleground badge in the fixed launch roster.'},
 {id='wizard',title='Sanctuary Wizard',track='Wizard',reason='Qualify every dungeon badge with a native instance-completion result.'},
}
Q.byID={};for _,r in ipairs(Q.rewards)do Q.byID[r.id]=r end
local ambient={cat=true,owl=true,rabbit=true,bird=true,moth=true,fox=true,stag=true,squirrel=true}
function Q.IsAmbient(id)return ambient[id]==true end
function Q.CollectionRewards()
 local out={};for _,r in ipairs(Q.rewards)do if not ambient[r.id]or r.id=='cat'or r.id=='rabbit'or r.id=='stag'or r.id=='squirrel'then out[#out+1]=r end end;return out
end
-- IDs name documented companion NPCs, not arbitrary wild owls/rabbits. Native
-- ownership is still required. Source qualification is retained in the build.
Q.petCreatures={ [7553]='owl',[7555]='owl',[7560]='rabbit',[7389]='bird',[7390]='bird' }
Q.spriteFinale=4298
local function state(owner,create)
 local s=M.OwnerState(owner,create);if not s then return end
 local r=s.sanctuary
 if r==nil and create then
  r={version=1,roster=1,earned={},species={},notified={},pending={},badgeStages={},badgeCharms={}};s.sanctuary=r
  -- Adopt already retained artifacts silently. A later render is not an unlock.
  for id,b in pairs(s.badges)do if plain(b)then
   local stage,charms=M.Progress(b);r.badgeStages[id]=stage or 0;r.badgeCharms[id]={}
   for _,key in ipairs(charms or{})do r.badgeCharms[id][key]=true end
  end end
 end
 if not plain(r)or r.version~=1 then return end
 for _,key in ipairs({'earned','species','notified','pending','badgeStages','badgeCharms'})do if not plain(r[key])then return end end
 return r,s
end
Q.State=state
local function enabled()return ns.Notifications.Get('badges')and ns.Notifications.Get('sanctuary')end
local function notify(owner,notice,silent)
 local r=state(owner,true);if not r or r.notified[notice.key]then return end
 -- The registry has a finite catalogue; retain dedupe across reload, including
 -- deliberately disabled and historical notices. Never flood on migration.
 if count(r.notified)>=8192 then return end
 r.notified[notice.key]=true
 if silent or not enabled()then return end
 notice.owner=owner
 if #r.pending>=Q.queueLimit then
  -- Coalesce an older notice for this same badge, preserving its latest art.
  for i,old in ipairs(r.pending)do if old.art and old.art==notice.art then table.remove(r.pending,i);break end end
 end
 if #r.pending<Q.queueLimit then r.pending[#r.pending+1]=notice end
 if ns.Activity then ns.Activity.Add('sanctuary:'..owner..':'..notice.key,'sanctuary',{sender='Athena’s Sanctuary',preview=notice.title..' · '..notice.reason,rewardKey=notice.key,owner=owner},false)end
 if Q.Pump then Q.Pump()end
end
local function grant(owner,id,e,reason,silent)
 if Q.IsAmbient(id)then return false end -- Ambient fauna is no longer an entitlement. Retained historical awards are untouched.
 local r=state(owner,true);if not r or r.earned[id]or not Q.byID[id]then return false end
 r.earned[id]={at=e and e.at or stamp(),ref=e and e.id,reason=reason,criterion=1}
 notify(owner,{key='actor/'..id,id=id,title=Q.byID[id].title,reason=reason},silent)
 if ns.UI2 and ns.UI2.realm then ns.UI2.realm:RefreshEffects()end
 return true
end
local function prestige(owner,s,r,e,silent)
 local roster=ns.WardenSanctuaryRoster
 if not roster then return end
 for _,pair in ipairs({{'alliance','battlegrounds'},{'wizard','dungeons'}})do
  local list=roster[pair[2]];local ready=list and #list>0
  for _,id in ipairs(list or{})do local b=s.badges[id]
   -- A finishing boss, advanced artwork, days observed or a visit never
   -- substitutes for the existing native completion channel.
   local enough=plain(b)and(pair[1]=='alliance'and(b.matchCount or 0)>0 or pair[1]=='wizard'and(b.completionCount or 0)>0)
   if not enough then ready=false;break end
  end
  if ready then grant(owner,pair[1],e,pair[1]=='alliance'and'All launch-roster battleground results recorded.'or'Native completion results recorded for every launch-roster dungeon.',silent)end
 end
end
function Q.Reconcile(owner)
 local r,s=state(owner,true);if not r then return end
 prestige(owner,s,r,nil,true)
end
function Q.Observe(e,replay)
 if e.character~=current()or e.subject and e.subject~=select(2,ns.Chronicle.Owner())then return end
 local r,s=state(e.character,true);if not r then return end
 local d=e.details or{};local silent=replay==true
 if e.kind=='native_event'and d.recordType=='collection_added'and d.collectionType=='pet'and e.source=='NEW_PET_ADDED'then
  if replay then return end
  if type(d.battlePetGUID)=='string'and count(Q.pendingPets)<128 then Q.pendingPets[d.battlePetGUID]=true end;return
 end
 local capture=e.capture
 if e.kind=='native_event'and d.recordType=='collection_observed'and d.collectionType=='pet'and type(d.contentID)=='string'then
  local object=ns.ChronicleCapture.Find(e.character,d.contentID);capture=object and object.capture
 end
 if capture and capture.family=='collection'and plain(capture.values)then
  local p=capture.values
  if p.collectionType~='pet'or p.collected~=true or p.scope~='collection-system'or type(p.speciesID)~='number'or p.speciesID%1~=0 or p.speciesID<=0 then return end
  local key=tostring(p.speciesID);silent=silent or not Q.pendingPets[p.battlePetGUID]
  if not r.species[key]and count(r.species)<512 then r.species[key]={ref=e.id,at=e.at,creatureID=p.creatureID}end
  local actor=Q.petCreatures[p.creatureID]
  if actor then grant(e.character,actor,e,'Observed in your owned companion collection.',silent)end
  if actor=='owl'then grant(e.character,'bird',e,'An owl companion was observed in your collection.',silent)end
  local n=count(r.species)
  if n>=5 then grant(e.character,'fox',e,'Five distinct owned companion species · Fireside cosmetic reward.',silent)end
  if n>=10 then grant(e.character,'stag',e,'Ten distinct owned companion species · Fireside cosmetic reward.',silent)end
  if p.battlePetGUID then Q.pendingPets[p.battlePetGUID]=nil end
 elseif e.kind=='quest_turnin'and e.source=='QUEST_TURNED_IN'and d.questID==Q.spriteFinale then
  grant(e.character,'moth',e,'Recorded completion of the Sprite Darter acquisition finale.',silent)
 end
end
function Q.BadgeChanged(owner,s,b,e,previous,previousCharms,replay)
 local r=state(owner,true);if not r then return end
 local old=r.badgeStages[b.art]or 0;local stage=b.stage or 1
 if stage>old then
  r.badgeStages[b.art]=stage
  notify(owner,{key='badge/'..b.art..'/'..stage,art=b.art,stage=stage,title=b.title..' · '..ns.WardenComposition.stages[stage],reason=old==0 and'First accepted arrival observation.'or'Your recorded adventures developed this keepsake.'},replay)
 end
 local known=r.badgeCharms[b.art]or{};r.badgeCharms[b.art]=known
 for _,key in ipairs(b.charms or{})do if not known[key]then
  known[key]=true;local m=ns.WardenComposition.memoryByKey[key]
  notify(owner,{key='piece/'..b.art..'/'..key,art=b.art,stage=stage,piece=key,title=m and m.title or'Keepsake embellishment',reason='New decoration from accepted adventure evidence.'},replay)
 end end
 prestige(owner,s,r,e,replay)
end
function Q.Owned(id,owner)
 local definition=Q.byID[id];if not definition then return false end
 if definition.permanent then return true end
 local r=state(owner or current(),false);return r and r.earned[id]~=nil or false
end
function Q.Available(id)
 return Q.IsAmbient(id)or ns.ClientCompat and ns.ClientCompat.IsRetailTest()or Q.preview or Q.ActiveBypass()or Q.Owned(id)
end
function Q.ActiveBypass()return Q.labBypass and ns.WardenSimLab and ns.WardenSimLab.Enabled()or false end
function Q.SetLabBypass(value)
 if not(ns.WardenSimLab and ns.WardenSimLab.Enabled())then return false end
 Q.labBypass=value==true
 if ns.UI2 and ns.UI2.realm then ns.UI2.realm:RefreshEffects()end
 return true
end
function Q.ExitPreview()
 Q.preview=false;Q.previewRoute=nil
 local u=ns.UI2;if u and u.realm then u.realm.previewRoute=nil;u.realm:EndShowcase();u.realm:RefreshEffects();if u.canvas and not u.realm.reading then u.canvas:Show()end end
 if Q.previewBar then Q.previewBar:Hide()end
end
function Q.Preview(which,roomID)
 if not permitted()then return false end
 roomID=roomID or(which=='study'and'study'or'hall');if not ns.WardenRoomCatalogue.HasRoom(roomID)then return false end
 Q.preview=true;Q.previewSwitch=true;ns.UI2.Open({page=which=='study'and'journey'or'overview',sceneRoom=roomID});Q.previewSwitch=nil;Q.previewRoute=ns.UI2.route
 local v=ns.UI2.realm;if not v then Q.preview=false;return false end
 if not v.reading then v.previewRoute=ns.UI2.route;ns.UI2.canvas:Hide()end
 v:BeginShowcase();v:RefreshEffects()
 if not Q.previewBar then
  local C=ns.UI2Components;local f=C.Card(ns.UI2.window,'Preview — Rewards Not Yet Earned',false);Q.previewBar=f
  f:SetSize(560,85);f:SetPoint('BOTTOM',0,40);f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetFrameLevel(ns.UI2.window:GetFrameLevel()+120)
  C.Button(f,'Realm Window',function()Q.Preview('realm')end,150):SetPoint('BOTTOMLEFT',12,10)
  C.Button(f,'Athena’s Study',function()Q.Preview('study')end,170):SetPoint('BOTTOMLEFT',174,10)
  C.Button(f,'Exit Preview',Q.ExitPreview,170):SetPoint('BOTTOMRIGHT',-12,10)
 end
 Q.previewBar:Show();return true
end
function Q.Inspect(id)
 if not permitted()then return false end
 Q.OpenCollection();if Q.collection then Q.collection.status:SetText(Q.byID[id]and Q.byID[id].reason or'Inspect your earned badge in Bookbinder.')end
end
-- Installed WoW icons replace the retired 2D actor rigs in reward thumbnails.
Q.rewardIcons={squirrel="Interface\\Icons\\inv_pet_mechanicalsquirrel",cat="Interface\\Icons\\ability_hunter_pet_cat",owl="Interface\\Icons\\ability_hunter_pet_owl",rabbit="Interface\\Icons\\inv_misc_rabbit",bird="Interface\\Icons\\ability_hunter_pet_owl",moth="Interface\\Icons\\ability_hunter_pet_moth",fox="Interface\\Icons\\ability_hunter_aspectofthefox",stag="Interface\\Icons\\ability_druid_travelform",wizard="Interface\\Icons\\spell_arcane_blast",guild="Interface\\Icons\\inv_bannerpvp_01",alliance="Interface\\Icons\\inv_bannerpvp_02"}
function Q.Art(host,notice)
 if host.compositionPool then ns.WardenComposition.Render(host,{version=1,catalog=3,layers={}})end
 if host.rewardTexture then host.rewardTexture:Hide()end
 for _,t in ipairs(host.rewardPieces or{})do t:Hide()end
 if notice.art and ns.WardenComposition.catalog[notice.art]then
  if notice.piece then
   local B=ns.WardenComposition;local m=B.memoryByKey[notice.piece];local cell=B.charms[notice.piece]
   if cell then
    local t=host.rewardTexture or host:CreateTexture(nil,'ARTWORK');host.rewardTexture=t;t:SetAllPoints();t:SetTexture(m and(m.path or B.base..'MemoryPins.tga')or B.base..'InkColorized.tga')
    local x,y=(cell-1)%4,math.floor((cell-1)/4);t:SetTexCoord(x/4+.002,(x+1)/4-.002,y/4+.002,(y+1)/4-.002);t:Show();return
   end
  end
  if not notice.piece and notice.stage==6 then
   local charms={};for _,item in ipairs(M.Inventory(current()))do if item.art==notice.art then charms=item.charms;break end end
   ns.WardenComposition.Render(host,{version=1,catalog=3,layers={{art=notice.art,stage=6,charms=charms,x=0,y=0,w=1000,h=1000}}});return
  end
  if not notice.piece and(notice.stage or 1)>=5 then
   local pieces=ns.WardenComposition.Pieces({art=notice.art,stage=notice.stage},3);local role=notice.stage==5 and'ornament'or'metal';local used=0
   host.rewardPieces=host.rewardPieces or{}
   for _,p in ipairs(pieces)do if p.role==role then
    used=used+1;local t=host.rewardPieces[used]or host:CreateTexture(nil,'ARTWORK');host.rewardPieces[used]=t
    t:ClearAllPoints();t:SetPoint('TOPLEFT',p.x*host:GetWidth(),-p.y*host:GetHeight());t:SetSize(p.w*host:GetWidth(),p.h*host:GetHeight());t:SetTexture(p.art.path);t:SetTexCoord(unpack(p.art.uv));local c=p.color or{1,1,1};t:SetVertexColor(c[1],c[2],c[3]);t:Show()
   end end
   if used>0 then return end
  end
  ns.WardenComposition.Render(host,{version=1,catalog=3,layers={{art=notice.art,stage=notice.stage or 1,x=0,y=0,w=1000,h=1000}}});return
 end
 local icon=Q.rewardIcons[notice.id]
 if icon then
  local tex=host.rewardTexture or host:CreateTexture(nil,'ARTWORK');host.rewardTexture=tex
  tex:ClearAllPoints();tex:SetPoint('CENTER');local side=math.min(host:GetWidth(),host:GetHeight());tex:SetSize(side,side)
  tex:SetTexture(icon);tex:SetTexCoord(0,1,0,1);tex:SetVertexColor(1,1,1,1);tex:Show()
 end
end
function Q.Attach(window)
 if Q.popup then return end
 local C=ns.UI2Components;local f=C.Card(window,'Sanctuary keepsake unlocked',false);Q.popup=f
 f:SetSize(420,150);f:SetPoint('TOPRIGHT',-18,-235);f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetFrameLevel(window:GetFrameLevel()+100);f:Hide()
 f.art=CreateFrame('Frame',nil,f);f.art:SetSize(84,84);f.art:SetPoint('TOPLEFT',12,-43);f.art:EnableMouse(false)
 f.name=C.Text(f,'',15,C.colors.gold);f.name:SetPoint('TOPLEFT',108,-40);f.name:SetWidth(296);f.name:SetHeight(36);f.name:SetJustifyH('LEFT');f.name:SetWordWrap(true)
 f.reason=C.Text(f,'',12,C.colors.text);f.reason:SetPoint('TOPLEFT',108,-77);f.reason:SetWidth(296);f.reason:SetHeight(40);f.reason:SetJustifyH('LEFT');f.reason:SetWordWrap(true)
 C.Button(f,'Inspect',function()local n=f.notice;f:Hide();if n and n.art then local b;for _,item in ipairs(M.Inventory(current()))do if item.art==n.art then b=item;break end end;if b then ns.WardenStudio.InspectArtifact(b)else Q.Inspect()end else Q.Inspect(n and n.id)end end,90):SetPoint('BOTTOMRIGHT',-12,7)
 C.Button(f,'×',function()f:Hide();Q.Pump()end,28):SetPoint('TOPRIGHT',-4,-2)
 f:SetScript('OnShow',function()f.started=ns.SafeCall(GetTime)or 0;if ns.WardenAudio then ns.WardenAudio.Play('art.discover','sanctuary')end end)
 f:SetScript('OnHide',function()f.notice=nil;f:SetScript('OnUpdate',nil);f:SetAlpha(1)end)
 window:HookScript('OnHide',function()Q.ExitPreview();f:Hide()end)
 window:HookScript('OnShow',function()Q.Pump()end)
end
function Q.ShowNotice(n,test)
 local f=Q.popup;if not f then return false end
 f.notice=n;Q.Art(f.art,n);f.title:SetText(test and'TEST — No reward granted'or'Sanctuary keepsake unlocked');f.name:SetText(n.title);f.reason:SetText(n.reason);f:Show();f.started=ns.SafeCall(GetTime)or 0
 f:SetScript('OnUpdate',function()
  local elapsed=(ns.SafeCall(GetTime)or f.started)-f.started
  if not permitted()or elapsed>=6 then f:Hide();Q.Pump();return end
  f:SetAlpha(ns.DB.journalReducedMotion and 1 or math.min(1,elapsed/.35,(6-elapsed)/.4))
 end);return true
end
function Q.Pump()
 if not Q.popup or Q.popup:IsShown()or not ns.UI2.window:IsShown()or not permitted()or not enabled()then return end
 local r=state(current(),false);if not r or #r.pending==0 then return end
 -- Consume obsolete queued animal notices without changing earned keepsakes or
 -- their historical references. Natural fauna no longer announces an unlock.
 for _=1,math.min(#r.pending,Q.queueLimit)do local n=table.remove(r.pending,1)
  if type(n)=='table'and n.owner==current()and not Q.IsAmbient(n.id)then Q.ShowNotice(n);return end
 end
end
function Q.TestPopup(id)
 if not(ns.WardenSimLab and ns.WardenSimLab.Enabled())then return false end
 if id=='badge'or id=='badge-upgrade'or id=='badge-piece'then
  local art=ns.WardenActivityArt.rows[1];local n={art=art.id,stage=id=='badge'and 1 or 5,title='TEST · '..art.title,reason='Private Lab artwork test · no badge or acquisition written.'}
  if id=='badge-piece'then n.piece=art.memories[1].key;n.title=art.memories[1].title end
  return Q.ShowNotice(n,true)
 end
 if not Q.byID[id]then return false end
 return Q.ShowNotice({id=id,title=Q.byID[id].title,reason='Private Lab presentation test · no entitlement or evidence written.'},true)
end
function Q.OpenCollection()
 if not permitted()then return false end
 M.Request(current());Q.Reconcile(current())
 local f=Q.collection
 if not f then
  f=ns.UI2Forms.Form({title='Athena’s Sanctuary',help='Wildlife visits the fields naturally; cats wander Pyragore. Standards remain private keepsakes.',fields={},cancelLabel='Close'});if not f then return false end;Q.collection=f;f:SetHeight(700);f:SetWidth(720)
  local body=f.scroll:GetScrollChild();body:SetHeight(870)
  f.tiles={};for i,r in ipairs(Q.CollectionRewards())do
   local tile=ns.UI2Components.Card(body,r.title,true);tile:SetSize(312,148);tile:SetPoint('TOPLEFT',12+(i-1)%2*328,-12-math.floor((i-1)/2)*165)
   local art=CreateFrame('Frame',nil,tile);art:SetSize(80,80);art:SetPoint('TOPLEFT',8,-44);Q.Art(art,{id=r.id})
   tile.label=ns.UI2Components.Text(tile,'',12,{.18,.13,.07});tile.label:SetPoint('TOPLEFT',96,-43);tile.label:SetWidth(202);tile.label:SetHeight(94);tile.label:SetJustifyH('LEFT');tile.label:SetWordWrap(true);f.tiles[i]=tile
  end
  ns.UI2Components.Button(f,'Preview Sanctuary',function()f:Hide();Q.Preview('realm')end,210):SetPoint('BOTTOMLEFT',18,18)
 end
 for i,r in ipairs(Q.CollectionRewards())do
  local message=Q.IsAmbient(r.id)and(r.id=='cat'and'Wanders Pyragore at natural intervals.'or'Visits the fields at natural intervals.')or(Q.Owned(r.id)and(r.permanent and'Always available'or'Unlocked')or'Locked')..'\n'..r.reason
  f.tiles[i].label:SetText(message)
 end
 if ns.UI2Forms.active and ns.UI2Forms.active~=f then ns.UI2Forms.active:Hide()end;ns.UI2Forms.active=f;f:Show();return true
end
function Q.ResetRuntime()
 Q.ExitPreview();Q.labBypass=false;Q.pendingPets={};if Q.popup then Q.popup:Hide()end;if Q.collection then Q.collection:Hide()end
end
