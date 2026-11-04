-- New UI2 visual primitives. No dependency on legacy Art/Workspace constructors.
local _,ns=...
local C={};ns.UI2Components=C
C.colors={ink={.018,.031,.052,1},surface={.027,.049,.077,1},raised={.04,.065,.098,1},line={.43,.32,.17,1},gold={.88,.70,.40,1},blue={.39,.73,.91,1},text={.95,.93,.87,1},muted={.65,.70,.74,1},green={.45,.79,.64,1}}
function C.EditBlocked(frame)
 local p=frame;for _=1,40 do if not p then return false end;if p.layoutEditing then return true end;local parent=p.GetParent and p:GetParent();if parent==p then return false end;p=parent end;return true
end
local font='Fonts\\FRIZQT__.TTF'
function C.Portrait(texture,person)
 local v=person.values or person.identity or {}
 local synthetic=person.state=='synthetic' or person.sourceState=='synthetic'
 local live=not synthetic and ns.WardenCharacterCards.Portrait(texture,{owner=person.owner,guid=person.guid or person.key,values=v})
 -- Some clients/emulators return a generic inventory icon instead of a unit
 -- portrait. Use the existing class emblem as the user-selected fallback.
 local path=ns.SafeString(ns.SafeCall(texture.GetTexture,texture),260)
 if live and path and path:lower():gsub('/','\\'):find('interface\\icons\\',1,true)==1 then live=false end
 if live then
  -- GetTexture can return a numeric asset ID even when SetTexture used a
  -- path. Resolve the known generic placeholders with ordinary owned textures.
  if not C.portraitPlaceholders then C.portraitPlaceholders={};C.portraitProbes={}
   for _,asset in ipairs({'Interface\\Icons\\Achievement_Character_Default','Interface\\Icons\\INV_Misc_QuestionMark'}) do
    local probe=texture:GetParent():CreateTexture(nil,'BACKGROUND');probe:SetTexture(asset);probe:Hide();C.portraitProbes[#C.portraitProbes+1]=probe
    local value=ns.SafeCall(probe.GetTexture,probe);if value~=nil then C.portraitPlaceholders[value]=true end
   end
  end
  local value=ns.SafeCall(texture.GetTexture,texture);if value~=nil and C.portraitPlaceholders[value] then live=false end
 end
 if not live then
  ns.WardenCharacterCards.Icon(texture,type(v.class)=='string' and v.class:upper() or nil)
 end
 return live
end
function C.Fill(parent,color,layer)
 local t=parent:CreateTexture(nil,layer or 'BACKGROUND');t:SetAllPoints(parent);t:SetColorTexture(unpack(color));return t
end
-- New parchment section, with independently constructed bronze rules/header.
function C.Card(parent,title,paper)
 local f=CreateFrame('Frame',nil,parent);f.paper=paper~=false
 f.background=C.Fill(f,f.paper and {.93,.88,.77,1} or C.colors.surface)
 f.material=ns.WardenArt.Texture(f,f.paper and 'Parchment'or 'TempleBackdrop')
 -- Paper starts below the engraved header; its transparent bevels and corners
 -- show the scene rather than a rectangular parchment strip underneath.
 if f.paper then
  f.background:ClearAllPoints();f.background:SetPoint('TOPLEFT',0,-34);f.background:SetPoint('BOTTOMRIGHT')
  f.material:SetPoint('TOPLEFT',0,-34);f.material:SetPoint('BOTTOMRIGHT')
 else f.material:SetAllPoints();f.material:SetTexCoord(.30,.70,.20,.80);f.material:SetVertexColor(.65,.72,.82,1)end
 f.heading=CreateFrame('Frame',nil,f);f.heading:SetPoint('TOPLEFT',1,-1);f.heading:SetPoint('TOPRIGHT',-1,-1);f.heading:SetHeight(33)
 f.headerArt=ns.WardenArt.Band(f.heading,'SectionHeader');f.title=C.Text(f.heading,title,15,C.colors.text);f.title:SetPoint('LEFT',42,0);f.title:SetPoint('RIGHT',-42,0)
 for _,side in ipairs({'TOP','BOTTOM','LEFT','RIGHT'}) do local t=f:CreateTexture(nil,'BORDER');t:SetColorTexture(.61,.43,.19,1)
  if side=='TOP' or side=='BOTTOM' then t:SetPoint(side..'LEFT');t:SetPoint(side..'RIGHT');t:SetHeight(1) else t:SetPoint('TOP'..side);t:SetPoint('BOTTOM'..side);t:SetWidth(1) end
 end
 f.torchFrame=ns.WardenArt.Frame(f,f.paper,false)
 return f
end
-- One compact experience inside the dossier's adventure collection. All
-- controls link back to the same canonical activity or person; no nested tabs.
function C.AdventureRow(parent)
 local f=CreateFrame('Frame',nil,parent);C.Fill(f,{.65,.48,.25,.06})
 f.title=C.Text(f,'',20,{.015,.028,.045,1});f.title:SetPoint('TOPLEFT',10,-6);f.title:SetPoint('TOPRIGHT',-235,-6);f.title:SetHeight(27)
 f.outcome=C.Text(f,'',14,{.05,.20,.13,1});f.outcome:SetPoint('TOPRIGHT',-10,-8);f.outcome:SetSize(225,24);f.outcome:SetJustifyH('RIGHT')
 f.meta=C.Text(f,'',11,{.06,.07,.08,1});f.meta:SetPoint('TOPLEFT',10,-36);f.meta:SetPoint('TOPRIGHT',-10,-36);f.meta:SetHeight(20)
 f.metrics={}
 for index=1,3 do local box=CreateFrame('Frame',nil,f);box.value=C.Text(box,'',20,{.035,.10,.16,1});box.value:SetPoint('TOPLEFT',0,0);box.value:SetHeight(25);box.label=C.Text(box,'',11,{.06,.07,.08,1});box.label:SetPoint('TOPLEFT',0,-25);box.label:SetHeight(17);f.metrics[index]=box end
 f.summary=C.Text(f,'',13,{.025,.04,.06,1});f.summary:SetPoint('TOPLEFT',10,-106);f.summary:SetPoint('TOPRIGHT',-10,-106);f.summary:SetHeight(41);f.summary:SetWordWrap(true)
 f.people={}
 for index=1,3 do local button=CreateFrame('Button',nil,f);button:SetSize(160,25);button.icon=button:CreateTexture(nil,'ARTWORK');button.icon:SetSize(23,23);button.icon:SetPoint('LEFT');button.label=C.Text(button,'',11,{.025,.04,.06,1});button.label:SetPoint('LEFT',28,0);button.label:SetPoint('RIGHT');button.label:SetHeight(24);button:SetScript('OnClick',function(self) if not C.EditBlocked(self) and self.person then ns.UI2.OpenPlayer(self.person.key,self.person.owner) end end);C.TactileRow(button,function(self)return self.person~=nil end);f.people[index]=button end
 f.reward=CreateFrame('Button',nil,f);f.reward:SetPoint('TOPLEFT',10,-179);f.reward:SetPoint('TOPRIGHT',-10,-179);f.reward:SetHeight(22)
 f.reward.icon=f.reward:CreateTexture(nil,'ARTWORK');f.reward.icon:SetSize(20,20);f.reward.icon:SetPoint('LEFT');f.reward.label=C.Text(f.reward,'',11,{.025,.04,.06,1});f.reward.label:SetPoint('LEFT',27,0);f.reward.label:SetPoint('RIGHT');f.reward.label:SetHeight(22)
 f.reward:SetScript('OnEnter',function(self) if self.item and self.item.link and GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_RIGHT');pcall(GameTooltip.SetHyperlink,GameTooltip,self.item.link);GameTooltip:Show() end end)
 f.reward:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
 f.open=C.Button(f,'Explore adventure',function() ns.UI2.Open({page='chronicle',kind='activity',key=f.model.key,owner=f.model.owner}) end,150);f.open:SetPoint('BOTTOMLEFT',10,4)
 f.chapter=C.Button(f,'Read chapter',function() ns.AthenaJournalWindow.Open({owner=f.model.owner,storyId=f.model.chapterId}) end,130);f.chapter:SetPoint('BOTTOMLEFT',168,4)
 function f:Render(m)
  self.model=m;local width=self:GetWidth();local narrow=width<600;local extra=narrow and 30 or 0
  self.title:ClearAllPoints();self.title:SetPoint('TOPLEFT',10,-6);self.title:SetSize(math.max(80,width-(narrow and 20 or 255)),27);self.title:SetText(m.place or m.title)
  self.outcome:ClearAllPoints();self.outcome:SetPoint(narrow and 'TOPLEFT' or 'TOPRIGHT',narrow and 10 or -10,narrow and -35 or -8);self.outcome:SetSize(math.min(width-20,225),24);self.outcome:SetJustifyH(narrow and 'LEFT' or 'RIGHT');self.outcome:SetText(m.status)
  local label=({dungeon='Dungeon expedition',raid='Raid expedition',duel='Duel',boss='World encounter'})[m.category] or 'Adventure'
  self.meta:ClearAllPoints();self.meta:SetPoint('TOPLEFT',10,-36-extra);self.meta:SetWidth(width-20);self.meta:SetText(label..' · '..C.Stamp(m.at)..(m.category=='duel' and m.location and ' · '..m.location or ''))
  for index,pair in ipairs({{m.attempts>0 and m.attempts or nil,'Encounter attempts'},{m.knownParticipants>0 and m.knownParticipants or nil,'Known players'},{m.details.loot>0 and m.details.loot or nil,'Rewards observed'}}) do local box=self.metrics[index];box:ClearAllPoints();box:SetPoint('TOPLEFT',10+(index-1)*(width-20)/3,-61);box:SetSize((width-20)/3-8,42);box.value:SetText(pair[1] and tostring(pair[1]) or '—');box.label:SetText(pair[2]) end
  for index,box in ipairs(self.metrics) do box:ClearAllPoints();box:SetPoint('TOPLEFT',10+(index-1)*(width-20)/3,-61-extra);if width<500 then box.label:SetText(({'Attempts','Players','Rewards'})[index]) end end
  self.summary:ClearAllPoints();self.summary:SetPoint('TOPLEFT',10,-106-extra);self.summary:SetWidth(width-20);self.summary:SetText(m.summary~='' and m.summary or (m.category=='duel' and 'The recorded opponent and outcome are linked to this duel.' or 'Open the expedition to explore its retained encounters and history.'))
  local summaryHeight=math.max(41,self.summary:GetStringHeight());self.summary:SetHeight(summaryHeight);local peopleY=106+extra+summaryHeight+5
  for index,button in ipairs(self.people) do local person=m.people[index];button:SetShown(person~=nil);if person then button.person=person;button:ClearAllPoints();button:SetPoint('TOPLEFT',10+(index-1)*math.min(180,(width-20)/3),-peopleY);button:SetWidth(math.min(172,(width-20)/3-6));C.Portrait(button.icon,person);button.label:SetText(person.title) end end
  if width<500 then for index,button in ipairs(self.people) do button:ClearAllPoints();button:SetPoint('TOPLEFT',10,-peopleY-(index-1)*30);button:SetWidth(width-20) end end
  local peopleRows=width<500 and math.max(1,math.min(3,#m.people)) or 1
  self.reward:ClearAllPoints();self.reward:SetPoint('TOPLEFT',10,-peopleY-peopleRows*30);self.reward:SetPoint('TOPRIGHT',-10,-peopleY-peopleRows*30)
  local reward=m.rewards[1];self.reward:SetShown(reward~=nil);self.reward.item=reward
  if reward then self.reward.icon:SetTexture(reward.icon or 'Interface\\Icons\\INV_Misc_QuestionMark');self.reward.label:SetText(reward.title..' · '..reward.recipient..(#m.rewards>1 and ' · More rewards on the adventure page' or '')) end
  self.chapter:SetShown(m.chapterId~=nil)
  self.chapter:ClearAllPoints();self.chapter:SetPoint('BOTTOMLEFT',width<350 and 10 or 168,width<350 and 37 or 4)
 end
 return f
end
function C.Canvas(parent)
 local p=CreateFrame('Frame',nil,parent);p:SetAllPoints(parent);p.cards={};p.cardByID={};p.blocks={}
 p.scroll=CreateFrame('ScrollFrame',nil,p);p.scroll:SetPoint('TOPLEFT');p.scroll:SetPoint('BOTTOMRIGHT',-5,0);p.scroll:EnableMouseWheel(true)
 p.content=CreateFrame('Frame',nil,p.scroll);p.content:SetSize(1,1);p.scroll:SetScrollChild(p.content)
 local function row(host)
  local f=CreateFrame('Button',nil,host);f.background=C.Fill(f,{0,0,0,0});f.icon=f:CreateTexture(nil,'ARTWORK');f.icon:SetSize(25,25);f.icon:SetPoint('LEFT',1,0)
  f.cells={};for n=1,8 do f.cells[n]=C.Text(f,'',12,{.13,.17,.21,1}) end
  f.line=f:CreateTexture(nil,'BORDER');f.line:SetPoint('BOTTOMLEFT');f.line:SetPoint('BOTTOMRIGHT');f.line:SetHeight(1);f.line:SetColorTexture(.54,.43,.29,.22)
  f:SetScript('OnClick',function(self) if not C.EditBlocked(self) and self.item and self.item.activate then self.item.activate() end end)
  f:SetScript('OnEnter',function(self) if self.item and self.item.activate then self.background:SetColorTexture(.22,.42,.65,.15) end;if self.item and self.item.itemLink and GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_RIGHT');pcall(GameTooltip.SetHyperlink,GameTooltip,self.item.itemLink);GameTooltip:Show() elseif self.item and self.item.wikiKey and GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText('Open Living Wiki · '..self.item.title);GameTooltip:AddLine('Reference knowledge; recorded outcomes stay on this adventure.',1,1,1,true);GameTooltip:Show() end end)
  f:SetScript('OnLeave',function(self) self.background:SetColorTexture(0,0,0,0);if self.item and (self.item.itemLink or self.item.wikiKey) and GameTooltip then GameTooltip:Hide() end end)
  C.TactileRow(f)
  return f
 end
 function p:Render(blocks,offset)
  local E=ns.UI2LayoutEngine;local template=self.template or E.Template(ns.UI2 and ns.UI2.route)
  self.template=template;self.blocks=blocks;local width=math.max(280,self.scroll:GetWidth());self.content:SetWidth(width);local bottom=0;self.anchors={}
  for _,old in pairs(self.cardByID) do old:Hide();for _,r in ipairs(old.rows) do r.item=nil;for _,button in ipairs(r.actions or {}) do button.item=nil end;for _,button in ipairs(r.votes or {}) do button.voteGUID=nil end;for _,tile in ipairs(r.tiles or {}) do tile.item=nil end;if r.adventure then r.adventure.model=nil;for _,person in ipairs(r.adventure.people) do person.person=nil end;r.adventure.reward.item=nil end end end
  self.cards={}
  self.probe=self.probe or C.Text(self,'',14);self.probe:Hide()
  local function textHeight(text,w,size)
   self.probe:SetFont(font,size,'');self.probe:SetWidth(math.max(20,w));self.probe:SetWordWrap(true);self.probe:SetText(ns.WardenBrand.Text(text or ''));return math.max(size+3,self.probe:GetStringHeight())
  end
  local function measure(b,w)
   local left=b.portrait and (b.compactPortrait and 112 or 148) or 12;local usable=w-left-20;local height=b.header==false and 12 or 44
   for _,r in ipairs(b.rows or {}) do
    local size=r.size or (r.kind=='hero' and 26 or r.kind=='section' and 16 or r.kind=='caption' and 12 or 14);local rh=r.height or 31
    if r.actions or r.voting then
     local cols=math.max(1,math.floor(usable/126));r.layoutActionCols=cols;r.layoutVoteY=r.actions and math.ceil(#r.actions/cols)*36 or 0;rh=math.max(rh,r.layoutVoteY+(r.voting and 40 or 0))
    elseif r.collection then rh=r.collection.height or 380
    elseif r.adventure then local extra=(usable<600 and 30 or 0)+(usable<500 and math.max(0,math.min(3,#r.adventure.people)-1)*30 or 0)+(usable<350 and r.adventure.chapterId and 33 or 0);rh=math.max(270+extra,rh,211+textHeight(r.adventure.summary,usable-20,13)+extra)
    elseif r.tiles then for _,t in ipairs(r.tiles) do rh=math.max(rh,34+textHeight(t.detail,usable/2-28,12)+12) end
    elseif r.composition then rh=math.max(rh,math.min(usable/ns.WardenComposition.DisplayAspect(r.composition),640))
    elseif not r.talentTree and not r.equipment then
     local indent=(r.person or r.icon) and 32 or 0
     if r.detail and not r.cells and usable<540 then r.stacked=true end
     if r.stacked then rh=math.max(rh,12+textHeight(r.title,usable-indent,size)+textHeight(r.detail,usable-indent,12));r.layoutTitleHeight=textHeight(r.title,usable-indent,size)
     else local values=r.cells or {r.title or '',r.detail or ''};local widths=r.widths or {r.detail and .62 or 1,.38};for n,v in ipairs(values) do rh=math.max(rh,10+textHeight(v,(usable-indent)*(widths[n] or 1/#values)-8,size)) end end
    end
    r.layoutHeight=rh;height=height+rh
   end
   return math.max(height,b.portrait and (b.compactPortrait and 158 or 190) or 0)
  end
  local tx=ns.UI2LayoutEditor and ns.UI2LayoutEditor.tx;self.layoutEditing=tx and tx.template==template or false
  local preview=ns.UI2LayoutEditor and ns.UI2LayoutEditor.preview
  local placed,columns,lanes=E.Solve(template,blocks,width,measure,tx and tx.template==template and tx.layout or nil,self.layoutEditing and not preview,width*(ns.SafeNumber(ns.SafeCall(self.GetEffectiveScale,self)) or 1));self.columns=columns;self.placed=placed;self.lanes=lanes
  for i,b in ipairs(placed) do
   local key=template..'/'..b.id;local card=self.cardByID[key];if not card then card=C.Card(self.content,b.title,b.paper);card.rows={};self.cardByID[key]=card end
   self.cards[i]=card;card.descriptor=b;card.layoutID=b.id;card:Show();if card.layoutSelection then card.layoutSelection:Hide() end;local theme=b.id=='identity' and template=='intel.player' and E.Theme(ns.UI2.route);card.cardTheme=theme;card.background:SetColorTexture(unpack(theme and theme.bg or b.paper==false and C.colors.surface or {.93,.88,.77,1}));card.material:SetShown(not theme);card.title:SetText(ns.WardenBrand.Text(b.title or E.templates[template].cards[b.id].label));local x,w,y,height=b.grid.x,b.grid.w,b.grid.y,b.grid.h
   card:ClearAllPoints();card:SetPoint('TOPLEFT',x,-y);card:SetSize(w,height);card.heading:SetShown(b.header~=false and true)
   if b.anchor then self.anchors[b.anchor]=y end
   if not card.portrait then card.portrait=card:CreateTexture(nil,'ARTWORK') end
   card.portrait:Hide()
   if not card.portraitNote then card.portraitNote=C.Text(card,'Class icon\nPortrait unavailable',10,C.colors.muted);card.portraitNote:SetWordWrap(true) end
   card.portraitNote:Hide()
   if b.portrait and true then card.portrait:ClearAllPoints();card.portrait:SetPoint('TOPLEFT',16,-22);card.portrait:SetSize(b.compactPortrait and 88 or 120,b.compactPortrait and 88 or 120);local live=C.Portrait(card.portrait,b.portrait);card.portrait:Show();card.portraitNote:ClearAllPoints();card.portraitNote:SetPoint('TOP',card.portrait,'BOTTOM',0,-5);card.portraitNote:SetSize(b.compactPortrait and 88 or 120,32);card.portraitNote:SetShown(not live) end
   local contentLeft=b.portrait and (b.compactPortrait and 112 or 148) or 12
   local at=b.header==false and 8 or 38
   for n,r in ipairs(true and not b.collapsed and b.rows or {}) do local f=card.rows[n];if not f then f=row(card);card.rows[n]=f end
    f:Show();f.item=r;f:ClearAllPoints();f:SetPoint('TOPLEFT',contentLeft,-at);f:SetSize(w-contentLeft-12,r.layoutHeight or r.height or 31);f.icon:Hide();local indent=0
    if r.composition then
     if not f.composition then f.composition=CreateFrame('Frame',nil,f)end
     local aspect=ns.WardenComposition.DisplayAspect(r.composition);local height=math.min(f:GetWidth()/aspect,f:GetHeight());f.composition:ClearAllPoints();f.composition:SetPoint('CENTER');f.composition:SetSize(height*aspect,height);f.composition:Show();ns.WardenComposition.Render(f.composition,r.composition)
    elseif f.composition then f.composition:Hide()end
    if r.doodle then if not f.doodle then f.doodle=CreateFrame('Frame',nil,f);f.doodle:SetAllPoints()end;f.doodle:Show();ns.WardenDrawing.Render(f.doodle,r.doodle)elseif f.doodle then f.doodle:Hide()end
    if r.adventure then if not f.adventure then f.adventure=C.AdventureRow(f);f.adventure:SetAllPoints() end;f.adventure:Show();f.adventure:Render(r.adventure)
    elseif f.adventure then f.adventure:Hide() end
    if r.person then C.Portrait(f.icon,r.person);f.icon:Show();indent=32 elseif r.icon then f.icon:SetTexture(r.icon);f.icon:SetTexCoord(0,1,0,1);f.icon:Show();indent=32 end
    if r.collection then
     if not f.collection then f.collection=C.Collection(f);f.collection:SetAllPoints(f) end;f.collection:Show();f.collection:Render(r.collection)
    elseif f.collection then f.collection:Hide() end
    if r.talentTree then
     if not f.talentTree then f.talentTree=ns.WardenTalents.Build(f,{inline=true});f.talentTree:SetAllPoints(f) end
     local data=r.talentTree;f.talentTree:Present(data.values,data.objects,data.at,data.key)
    elseif f.talentTree then f.talentTree:Hide() end
    if r.equipment then
     if not f.equipment then f.equipment=C.Equipment(f);f.equipment:SetAllPoints(f) end
     f.equipment:Render(r.equipment)
    elseif f.equipment then f.equipment:Hide() end
    f.tiles=f.tiles or {}
    if r.badge then
     if not f.badge then f.badge=CreateFrame('Frame',nil,f);C.Fill(f.badge,{.35,.23,.10,1});f.badge.label=C.Text(f.badge,'',12,C.colors.gold);f.badge.label:SetPoint('LEFT',9,0);f.badge.label:SetPoint('RIGHT',-9,0) end
     f.badge:SetPoint('TOPRIGHT',-2,-1);f.badge:SetSize(math.min(300,f:GetWidth()/2),24);f.badge.label:SetText(r.badge);f.badge:Show()
    elseif f.badge then f.badge:Hide() end
    for column=1,2 do local tile=f.tiles[column];local data=r.tiles and r.tiles[column]
     if data then
      if not tile then tile=CreateFrame('Button',nil,f);f.tiles[column]=tile;tile.background=C.Fill(tile,{.68,.53,.31,.10});tile.title=C.Text(tile,'',14,{.015,.028,.045,1});tile.title:SetPoint('TOPLEFT',9,-5);tile.title:SetPoint('TOPRIGHT',-9,-5);tile.title:SetHeight(22);tile.detail=C.Text(tile,'',12,{.045,.05,.06,1});tile.detail:SetPoint('TOPLEFT',9,-28);tile.detail:SetPoint('BOTTOMRIGHT',-9,5);tile.detail:SetWordWrap(true);tile:SetScript('OnClick',function(self) if not C.EditBlocked(self) and self.item and self.item.activate then self.item.activate() end end) end
      C.TactileRow(tile);tile:Show();tile.item=data;tile:ClearAllPoints();tile:SetPoint('TOPLEFT',(column-1)*(f:GetWidth()/2),0);tile:SetSize(f:GetWidth()/2-6,r.height or 74);tile.title:SetText(data.title);tile.detail:SetText(data.detail or '')
     elseif tile then tile:Hide() end
    end
    f.votes=f.votes or {}
    f.actions=f.actions or {}
    for index=1,math.max(4,#(r.actions or {}),#f.actions) do local button=f.actions[index];local data=r.actions and r.actions[index]
     if data then if not button then button=C.Button(f,'',function(self) self.item.activate() end,120);f.actions[index]=button end;button.item=data;button:SetLabel(data.title);button:ClearAllPoints();button:SetPoint('TOPLEFT',((index-1)%(r.layoutActionCols or 4))*126,-4-math.floor((index-1)/(r.layoutActionCols or 4))*36);button:SetSize(math.min(120,f:GetWidth()),30);button:Show()
     elseif button then button:Hide() end
    end
    if r.voting then C.Rating(f,r.voting,r.layoutVoteY or 0) else for _,button in ipairs(f.votes) do button:Hide() end;if f.withdraw then f.withdraw:Hide() end end
    local values=(r.composition or r.doodle or r.adventure or r.tiles or r.voting or r.actions or r.talentTree or r.equipment or r.collection) and {} or r.cells or {r.title or '',r.detail or ''};local widths=r.widths or {r.detail and .62 or 1,.38};local tx=indent
    for c=1,8 do local label=f.cells[c];label:Hide();if values[c]~=nil then
     local cw=(w-contentLeft-16-indent)*(widths[c] or 1/#values);label:ClearAllPoints();label:SetPoint('TOPLEFT',r.stacked and indent or tx,r.stacked and (c==1 and -2 or -(r.layoutTitleHeight or 22)-5) or -3);label:SetSize(math.max(10,(r.stacked and w-contentLeft-22-indent or cw-6)),r.stacked and (c==1 and (r.layoutTitleHeight or 22) or (r.layoutHeight or r.height or 50)-(r.layoutTitleHeight or 22)-10) or (r.layoutHeight or r.height or 31)-6)
     label:SetFont(font,r.size or (r.kind=='hero' and 26 or r.kind=='section' and 16 or r.kind=='caption' and 12 or 14),'')
     label:SetTextColor(unpack(r.color or (b.paper==false and (card.cardTheme and card.cardTheme.fg or C.colors.text) or r.kind=='caption' and {.045,.05,.06,1} or {.015,.028,.045,1})))
     if r.stacked and c>1 then label:SetFont(font,12,'') end
     label:SetWordWrap(true);label:SetText(ns.WardenBrand.Text(values[c]));label:Show();tx=tx+cw
    end end
    at=at+(r.layoutHeight or r.height or 31)
   end
   for n=b.collapsed and 1 or #(b.rows or {})+1,#card.rows do card.rows[n]:Hide();card.rows[n].item=nil end
   if ns.UI2LayoutEditor then ns.UI2LayoutEditor.Decorate(self,card,b) end
   bottom=math.max(bottom,y+height+12)
  end
  self.laneGuides=self.laneGuides or {}
  for i=1,3 do local g=self.laneGuides[i];local lane=lanes[i]
   if self.layoutEditing and not preview and lane then if not g then g=CreateFrame('Frame',nil,self.content);self.laneGuides[i]=g;g.fill=C.Fill(g,{.25,.55,.8,.035});g.label=C.Text(g,'',11,C.colors.muted);g.label:SetPoint('TOPLEFT',5,-4) end;g:ClearAllPoints();g:SetPoint('TOPLEFT',lane.x,-lane.top);g:SetSize(lane.w,math.max(50,bottom-lane.top,self.scroll:GetHeight()-lane.top));g.label:SetText(lane.name:sub(1,1):upper()..lane.name:sub(2));g:Show()
   elseif g then g:Hide() end
  end
  self.total=bottom;self.content:SetHeight(math.max(1,bottom));self.scroll:SetVerticalScroll(math.max(0,math.min(offset or 0,math.max(0,bottom-self.scroll:GetHeight()))))
 end
 function p:Jump(anchor) self.scroll:SetVerticalScroll(math.min(self.anchors[anchor] or 0,math.max(0,(self.total or 0)-self.scroll:GetHeight()))) end
 p.scroll:SetScript('OnMouseWheel',function(self,delta) self:SetVerticalScroll(math.max(0,math.min(math.max(0,(p.total or 0)-self:GetHeight()),self:GetVerticalScroll()-delta*58))) end)
 local function wheel(_,delta)local fn=p.scroll:GetScript('OnMouseWheel');if fn then fn(p.scroll,delta)end end
 for _,frame in ipairs({p,p.content,p.scroll})do
  frame:EnableMouse(true);frame:EnableMouseWheel(true)
  if frame~=p.scroll then frame:SetScript('OnMouseWheel',wheel)end
 end
 return p
end
function C.Text(parent,text,size,color)
 local f=parent:CreateFontString(nil,'OVERLAY');f:SetFont(font,size or 13,'');f:SetTextColor(unpack(color or C.colors.text));f:SetJustifyH('LEFT');f:SetJustifyV('MIDDLE');f:SetWordWrap(false);f:SetText(ns.WardenBrand.Text(text or ''));return f
end
function C.Star(parent,size)
 local f=CreateFrame('Frame',nil,parent);f:SetSize(size,size)
 f.outline={};local points={};for i=0,9 do local angle=-math.pi/2+i*math.pi/5;local radius=i%2==0 and size/2 or size*.21;points[i+1]={size/2+math.cos(angle)*radius,-size/2-math.sin(angle)*radius} end
 for i=1,10 do local line=f:CreateLine(nil,'ARTWORK');line:SetStartPoint('TOPLEFT',f,unpack(points[i]));line:SetEndPoint('TOPLEFT',f,unpack(points[i%10+1]));line:SetThickness(1.4);line:SetColorTexture(unpack(C.colors.gold));f.outline[#f.outline+1]=line end
 return f
end
function C.Bell(parent,size)
 local f=CreateFrame('Frame',nil,parent);f:SetSize(size,size)
 local points={{.29,.66},{.33,.30},{.42,.20},{.58,.20},{.67,.30},{.71,.66},{.82,.78},{.18,.78},{.29,.66}}
 for i=1,#points-1 do local line=f:CreateLine(nil,'ARTWORK');line:SetStartPoint('TOPLEFT',f,points[i][1]*size,-points[i][2]*size);line:SetEndPoint('TOPLEFT',f,points[i+1][1]*size,-points[i+1][2]*size);line:SetThickness(2);line:SetColorTexture(unpack(C.colors.gold)) end
 for _,part in ipairs({{.45,.12,.55,.12},{.43,.88,.57,.88}}) do local line=f:CreateLine(nil,'ARTWORK');line:SetStartPoint('TOPLEFT',f,part[1]*size,-part[2]*size);line:SetEndPoint('TOPLEFT',f,part[3]*size,-part[4]*size);line:SetThickness(2);line:SetColorTexture(unpack(C.colors.gold)) end
 return f
end
-- Shared inset treatment for action rows, small icon controls and pooled lists.
-- Move only visual regions: the input rectangle and nested controls stay fixed.
function C.TactileRow(button,eligible)
 if button.materialFace then return button.materialFace end
 local face=CreateFrame('Frame',nil,button);face:SetAllPoints(button);face:EnableMouse(false);button.materialFace=face
 local regions={button:GetRegions()}
 for _,region in ipairs(regions)do
  local points={};for i=1,region:GetNumPoints()do points[i]={region:GetPoint(i)}end
  region:SetParent(face);region:ClearAllPoints()
  for _,point in ipairs(points)do if point[2]==button then point[2]=face end;region:SetPoint(unpack(point))end
 end
 local bed=face:CreateTexture(nil,'BACKGROUND',nil,-7);bed:SetAllPoints();bed:SetColorTexture(.23,.13,.045,.045)
 local top=face:CreateTexture(nil,'BORDER');top:SetPoint('TOPLEFT',1,-1);top:SetPoint('TOPRIGHT',-1,-1);top:SetHeight(1)
 local bottom=face:CreateTexture(nil,'BORDER');bottom:SetPoint('BOTTOMLEFT',1,1);bottom:SetPoint('BOTTOMRIGHT',-1,1);bottom:SetHeight(1)
 local light=face:CreateTexture(nil,'OVERLAY');light:SetPoint('TOPLEFT',1,-1);light:SetPoint('BOTTOMRIGHT',-1,1);light:SetColorTexture(.83,.66,.34,.10)
 button.wardenTactileEligible=eligible or function(self)return self.item and(self.item.activate~=nil)or self.person~=nil or self.item and self.item.itemLink~=nil end
 local function paint(self)
  local enabled=self:IsEnabled()and self.wardenTactileEligible(self);local held=self.wardenHeld;local hover=self.wardenHover
  bed:SetShown(enabled);top:SetShown(enabled);bottom:SetShown(enabled);light:SetShown(enabled and(held or hover or self.active==true))
  top:SetColorTexture(.92,.78,.48,held and .12 or hover and .55 or .20);bottom:SetColorTexture(.12,.065,.02,held and .64 or .22)
 end
 ns.Theme.Tactile(button,face)
 for _,event in ipairs({'OnEnter','OnLeave','OnMouseDown','OnMouseUp','OnEnable','OnDisable','OnShow'})do button:HookScript(event,paint)end
 button:HookScript('OnClick',function(self)if self.wardenTactileEligible(self)and ns.WardenAudio then ns.WardenAudio.Play('button')end end)
 button.materialPaint=paint;paint(button);return face
end
function C.Button(parent,label,click,width)
 local f=CreateFrame('Button',nil,parent);f:SetSize(width or 100,28)
 local face=CreateFrame('Frame',nil,f);face:SetAllPoints();face:EnableMouse(false);f.face=face;f.fill=C.Fill(face,C.colors.raised);f.fill:Hide()
 local edge=face:CreateTexture(nil,'BORDER');edge:SetPoint('BOTTOMLEFT');edge:SetPoint('BOTTOMRIGHT');edge:SetHeight(1);edge:SetColorTexture(unpack(C.colors.line));f.edge=edge
 f.label=C.Text(face,label,12,C.colors.text);f.label:SetPoint('LEFT',10,0);f.label:SetPoint('RIGHT',-10,0)
 f.label:SetJustifyH('CENTER');f.torchArt=ns.WardenArt.ButtonBand(face,'ButtonNormal');edge:Hide()
 if f.SetPushedTextOffset then f:SetPushedTextOffset(0,0)end
 f.stateGlow=face:CreateTexture(nil,'ARTWORK');f.stateGlow:SetPoint('TOPLEFT',1,-1);f.stateGlow:SetPoint('BOTTOMRIGHT',-1,1);f.stateGlow:SetColorTexture(.78,.48,.10,.10);f.stateGlow:Hide()
 ns.Theme.Tactile(f,face)
 local function paint(self)
  local disabled=not self:IsEnabled();local tint=disabled and .4 or self.held and .72 or 1
  -- Normal, selected and hover images have different transparent silhouettes.
  -- Keep one outline for every state; state is tint/light, never new geometry.
  self.torchArt:SetArt('ButtonNormal');for _,texture in ipairs(self.torchArt)do texture:SetVertexColor(tint,tint,tint,1)end
  if self.structuralTab then
   self.fill:Show()
   self.torchArt:SetShown(false)
   local active=self.active==true
   self.fill:SetColorTexture(active and .045 or .022,active and .095 or .049,active and .145 or .082,1)
   self.tabMaterial:SetAlpha(disabled and .18 or self.held and .35 or active and .72 or self.hovered and .48 or .26)
   self.tabTop:SetAlpha(active and .9 or self.hovered and .65 or .34)
   self.tabLeft:SetAlpha(active and .7 or .25);self.tabRight:SetAlpha(active and .7 or .25)
   self.tabJoin:SetShown(active)
  else
   self.fill:Hide()
  end
  self.stateGlow:SetShown(not disabled and(self.active or self.hovered));self.edge:SetShown(not self.structuralTab and self.active==true)
  self.label:SetTextColor(unpack(disabled and C.colors.muted or(self.active or self.hovered)and C.colors.gold or C.colors.text))
 end
 f:SetScript('OnClick',function(self,...) if not C.EditBlocked(self) and click then if not self.destination and ns.WardenAudio then ns.WardenAudio.Play('button')end;return click(self,...) end end)
 f:SetScript('OnEnter',function(self)self.hovered=true;paint(self)end)
 f:SetScript('OnLeave',function(self)self.hovered=nil;self.held=nil;paint(self)end)
 f:HookScript('OnMouseDown',function(self)self.held=true;paint(self)end);f:HookScript('OnMouseUp',function(self)self.held=nil;paint(self)end)
 f:HookScript('OnEnable',paint);f:HookScript('OnDisable',paint)
 function f:SetLabel(text) self.label:SetText(ns.WardenBrand.Text(text)) end
 function f:GetText() return self.label:GetText() end
 function f:SetActive(active) self.active=active;self:GetScript('OnLeave')(self);self.edge:SetColorTexture(unpack(active and C.colors.gold or C.colors.line));self.UpdateTactile()end
 return f
end
-- Small window controls share the existing frame and tactile states.
function C.WindowIcon(button,kind)
 local face=button.face or button;local icon=button.windowIcon
 if not icon then icon=face:CreateTexture(nil,'OVERLAY');icon:SetSize(21,21);button.windowIcon=icon end
 icon:SetParent(face);icon:ClearAllPoints();icon:SetPoint('CENTER',face,'CENTER',0,0)
 icon:SetTexture('Interface\\AddOns\\OlympusChatWarden\\Media\\Window64\\'..kind..'.tga');button.windowIconKind=kind;button.label:Hide()
end
-- Mounted navigation leaves share the panel material and stay physically fixed
-- during hover/press. Ordinary action buttons retain their existing treatment.
function C.NavigationTab(parent,label,click,width)
 local f=C.Button(parent,label,click,width);f.structuralTab=true
 f.tabMaterial=ns.WardenArt.Texture(f.face,'TempleBackdrop','BACKGROUND',2)
 f.mountedFrame=ns.WardenArt.Frame(f.face,false,false)
 f.tabMaterial:SetPoint('TOPLEFT',1,-1);f.tabMaterial:SetPoint('BOTTOMRIGHT',-1,1)
 f.tabMaterial:SetTexCoord(.18,.82,.22,.78)
 local function rule(a,b)
  local t=f.face:CreateTexture(nil,'BORDER');t:SetColorTexture(.68,.43,.17,1)
  t:SetPoint(a);t:SetPoint(b);return t
 end
 f.tabTop=rule('TOPLEFT','TOPRIGHT');f.tabTop:SetHeight(1)
 f.tabLeft=rule('TOPLEFT','BOTTOMLEFT');f.tabLeft:SetWidth(1)
 f.tabRight=rule('TOPRIGHT','BOTTOMRIGHT');f.tabRight:SetWidth(1)
 f.tabJoin=f.face:CreateTexture(nil,'BORDER');f.tabJoin:SetColorTexture(.045,.095,.145,1)
 f.tabJoin:SetPoint('BOTTOMLEFT',1,-3);f.tabJoin:SetPoint('BOTTOMRIGHT',-1,-3);f.tabJoin:SetHeight(4)
 f:SetActive(false);return f
end
function C.Edit(parent,width,placeholder)
 local f=CreateFrame('EditBox',nil,parent);f:SetSize(width,28);f.background=C.Fill(f,C.colors.ink);f.torchArt=ns.WardenArt.Band(f,'ButtonPressed');f:SetAutoFocus(false);f:SetFont(font,12,'');f:SetJustifyH('LEFT');f:SetTextColor(unpack(C.colors.text));f:SetTextInsets(16,16,3,3);f:SetMaxLetters(512)
 f.hint=C.Text(f,placeholder,12,C.colors.muted);f.hint:SetPoint('LEFT',10,0);f.hint:SetPoint('RIGHT',-10,0)
 f:SetScript('OnTextChanged',function(self) self.hint:SetShown(self:GetText()=='');if self.changed then self.changed(self:GetText()) end end)
 f:SetScript('OnEscapePressed',function(self) self:ClearFocus() end);return f
end
function C.Stamp(at,short) return at and (ns.SafeCall(date,short and '%H:%M' or '%d %b %Y · %H:%M',at) or 'Date unavailable') or 'Not recorded' end
function C.Number(n) if type(n)~='number' then return 'Not recorded' end;if n>=1000000 then return string.format('%.1fm',n/1000000) end;if n>=1000 then return string.format('%.1fk',n/1000) end;return tostring(n) end
-- A single composed page, virtualized by visible rows. The model may contain
-- thousands of entries; the frame pool follows viewport size, not history size.
function C.Page(parent)
 local p=CreateFrame('Frame',nil,parent);p:SetAllPoints(parent);p.items={};p.pool={};p.offset=0
 p.scroll=CreateFrame('ScrollFrame',nil,p);p.scroll:SetPoint('TOPLEFT');p.scroll:SetPoint('BOTTOMRIGHT',-10,0);p.scroll:EnableMouseWheel(true)
 p.content=CreateFrame('Frame',nil,p.scroll);p.content:SetSize(1,1);p.scroll:SetScrollChild(p.content)
 p.rail=CreateFrame('Frame',nil,p);p.rail:SetPoint('TOPRIGHT');p.rail:SetPoint('BOTTOMRIGHT');p.rail:SetWidth(3);C.Fill(p.rail,C.colors.ink)
 p.thumb=p.rail:CreateTexture(nil,'ARTWORK');p.thumb:SetWidth(3);p.thumb:SetColorTexture(unpack(C.colors.gold))
 local function makeRow()
  local row=CreateFrame('Button',nil,p.content);row.background=C.Fill(row,{0,0,0,0})
  row.icon=row:CreateTexture(nil,'ARTWORK');row.icon:SetPoint('LEFT',5,0);row.icon:SetSize(24,24)
  row.cells={};for n=1,8 do row.cells[n]=C.Text(row,'',13) end
  row.rule=row:CreateTexture(nil,'BORDER');row.rule:SetPoint('BOTTOMLEFT');row.rule:SetPoint('BOTTOMRIGHT');row.rule:SetHeight(1);row.rule:SetColorTexture(.18,.23,.28,.6)
  row:SetScript('OnClick',function(self) if not C.EditBlocked(self) and self.item and self.item.activate then self.item.activate() end end)
  row:SetScript('OnEnter',function(self) if self.item and self.item.activate then self.background:SetColorTexture(.13,.20,.27,1) end end)
  row:SetScript('OnLeave',function(self) self.background:SetColorTexture(unpack(self.color or {0,0,0,0})) end)
  C.TactileRow(row)
  return row
 end
 function p:Paint()
  if not self.items then return end
  local w=math.max(100,self.scroll:GetWidth());local h=math.max(1,self.scroll:GetHeight());local top=self.scroll:GetVerticalScroll();local slot=0
  local lo,hi=1,#self.items
  while lo<hi do local mid=math.floor((lo+hi)/2);local item=self.items[mid];if item.y+item.height<top then lo=mid+1 else hi=mid end end
  for index=lo,#self.items do local item=self.items[index];if item.y>top+h+50 then break end
   slot=slot+1;local row=self.pool[slot];if not row then row=makeRow();self.pool[slot]=row end
   row.item=item;row:ClearAllPoints();row:SetPoint('TOPLEFT',0,-item.y);row:SetSize(w,item.height);row:Show()
   row.color=p.paper and (index%2==0 and {.86,.79,.66,.2} or {0,0,0,0}) or item.kind=='section' and C.colors.surface or item.kind=='columns' and C.colors.raised or index%2==0 and {.085,.115,.15,.45} or {0,0,0,0};row.background:SetColorTexture(unpack(row.color))
   row.rule:SetShown(item.kind~='space');row.icon:Hide()
   local indent=12
   if item.person then ns.WardenCharacterCards.Portrait(row.icon,{owner=item.person.owner,guid=item.person.key,values=item.person.identity or {}});row.icon:Show();indent=38 end
   if item.icon then row.icon:SetTexture(item.icon);row.icon:SetTexCoord(0,1,0,1);row.icon:Show();indent=38 end
   local cells=item.cells or {item.title or '',item.detail or ''};local widths=item.widths or (#cells==1 and {1} or {.62,.38});local x=indent
   for n=1,8 do local f=row.cells[n];f:Hide();if cells[n]~=nil then
    f:ClearAllPoints();f:SetPoint('TOPLEFT',x,-4);local cw=math.max(20,(w-indent-12)*(widths[n] or 1/#cells));f:SetSize(cw-8,item.height-8)
    f:SetFont(font,item.kind=='hero' and 24 or item.kind=='section' and 14 or item.kind=='caption' and 11 or 12,'')
    f:SetTextColor(unpack(p.paper and (item.kind=='caption' and {.26,.28,.30,1} or {.09,.14,.19,1}) or (item.kind=='hero' or item.kind=='section') and C.colors.gold or item.kind=='columns' and C.colors.muted or n==1 and C.colors.text or C.colors.muted))
    -- Explicit branching avoids boolean values becoming a text color.
    if item.kind=='hero' or item.kind=='section' then f:SetTextColor(unpack(C.colors.gold)) end
    f:SetWordWrap(item.wrap==true);f:SetText(ns.WardenBrand.Text(cells[n]));f:Show();x=x+cw
   end end
  end
  for n=slot+1,#self.pool do self.pool[n]:Hide() end
  local thumbHeight=math.max(24,math.min(h,h*h/math.max(h,self.total or h)))
  self.thumb:ClearAllPoints();self.thumb:SetPoint('TOP',0,-(self.total and self.total>h and top/(self.total-h)*(h-thumbHeight) or 0));self.thumb:SetHeight(thumbHeight)
 end
 function p:SetItems(items,offset)
  local y=0;self.anchors={}
  for _,item in ipairs(items) do item.height=item.height or (item.kind=='hero' and 46 or item.kind=='section' and 38 or item.kind=='caption' and 30 or 30);item.y=y;y=y+item.height;if item.anchor then self.anchors[item.anchor]=item.y end end
  self.items=items;self.total=y;self.content:SetSize(math.max(1,self.scroll:GetWidth()),math.max(1,y));self.scroll:SetVerticalScroll(math.max(0,math.min(offset or 0,math.max(0,y-self.scroll:GetHeight()))));self:Paint()
 end
 function p:Jump(anchor) self.scroll:SetVerticalScroll(math.min(self.anchors[anchor] or 0,math.max(0,(self.total or 0)-self.scroll:GetHeight())));self:Paint() end
 p.scroll:SetScript('OnMouseWheel',function(self,delta) self:SetVerticalScroll(math.max(0,math.min(math.max(0,(p.total or 0)-self:GetHeight()),self:GetVerticalScroll()-delta*64)));p:Paint() end)
 local function wheel(_,delta)local fn=p.scroll:GetScript('OnMouseWheel');if fn then fn(p.scroll,delta)end end
 for _,frame in ipairs({p,p.content,p.scroll})do
  frame:EnableMouse(true);frame:EnableMouseWheel(true)
  if frame~=p.scroll then frame:SetScript('OnMouseWheel',wheel)end
 end
 p.scroll:SetScript('OnVerticalScroll',function() p:Paint() end)
 p:SetScript('OnSizeChanged',function() p.content:SetWidth(math.max(1,p.scroll:GetWidth()));p:Paint() end)
 return p
end
