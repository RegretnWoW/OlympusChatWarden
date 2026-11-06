-- One pooled interaction response. No object/model deformation or new timers.
local _,ns=...;local H={VERSION=1};ns.WardenSceneHover=H
local C,N=ns.WardenSceneObjectControls,ns.WardenNativeScene
local function inside(u,v,b)return u>=b[1]and u<=b[3]and v>=b[2]and v<=b[4]end
function H.Person(v,s,u,y)
 local best;local own,owner=ns.PlayerCard.Own(),ns.Chronicle.Owner()
 for _,a in ipairs(s.native.order)do if a.spec.unit~='player'and N.IsPerson(a)and a.ready and not(a.editorHidden or a.retired or a.failed or a.awaitSpawn or a.sceneHidden)then
  if a.spec.liveRemote then
   local p=ns.AetherLive.ConnectedPlayer(a.liveIdentity);local b=p and C.ProjectPick(s.native,s.shot,a)
   if C.ContainsPick(b,u,y)and(not best or b.bottom>best.bounds[4])then best={id=a.id,title=ns.AetherLive.PlayerName(p),kind='live-person',peer=p.id,bounds={b.left,b.top,b.right,b.bottom}}end
  elseif a.spec.canonicalNPC and type(a.spec.label)=='string'then
   local b=C.ProjectPick(s.native,s.shot,a)
   if C.ContainsPick(b,u,y)and(not best or b.bottom>best.bounds[4])then best={id=a.id,title=a.spec.label,kind='citizen',bounds={b.left,b.top,b.right,b.bottom}}end
  else
  local guid=a.spec.rememberedGUID
  if guid~=own and guid~=owner then
  local b=guid and ns.ChronicleStore.GUID(guid)and C.ProjectPick(s.native,s.shot,a)
  if C.ContainsPick(b,u,y)and(not best or b.bottom>best.bounds[4])then
   local owner=ns.Chronicle.Owner();if H.nameOwner~=owner then H.nameOwner=owner;H.names={};H.nameOrder={}end
   local cached=H.names[guid];local now=ns.SafeCall(GetTime)or 0
   if not cached or now>=cached.retry then
    local model=ns.UI2Models.GetPlayerPage(guid,owner);local name=model and model.title
    if a.spec.unit=='player'then name=ns.SafeCall(UnitName,'player')or name end
    if not cached then H.nameOrder[#H.nameOrder+1]=guid;if #H.nameOrder>16 then H.names[table.remove(H.nameOrder,1)]=nil end end
    cached={title=name or'Player profile',known=name~=nil,retry=now+(name and 5 or 1)};H.names[guid]=cached
   end
   best={id=a.id,title=cached.title,kind='person',guid=guid,bounds={b.left,b.top,b.right,b.bottom}}
  end
 end
 end end end;return best
end
function H.Target(v,s,u,y)
 if not s or not s.active or v.cameraMix>.001 or v.roomBookMotion or v.shelfFocus then return end
 if s==v.studyScene and C.ContainsPick(ns.WardenRoomBook.Pick(v),u,y)then
  local b=ns.WardenRoomBook.Pick(v);return{id='book',title="Athena's Journal",bounds={b.left,b.top,b.right,b.bottom}}
 end
 local person=H.Person(v,s,u,y);if person then return person end
 local id=v:PickSceneObject(s,u,y)
 if id then local a=s.native.actors[id];local b=C.ProjectPick(s.native,s.shot,a)
  return{id=id,title=id=='shelf-right'and'Badge Showcase'or(a.spec.interaction=='fire'or id=='firepit')and'Campfire'or(a.spec.interaction=='chair'or id=='chair')and'Chair'or a.spec.label or id,bounds={b.left,b.top,b.right,b.bottom}}
 end
 for _,link in ipairs(ns.WardenRoomCatalogue.Connections(s.key))do if link.portal and ns.WardenWorldScale.InAuthoredUV(s,u,y,link.portal.clickUV)then
  return{id=link.id,title=link.label or(ns.WardenRoomCatalogue.Room(link.to)or{}).label or'Enter scene',bounds=ns.WardenWorldScale.ProjectAuthoredBox(s,link.portal.clickUV)or link.portal.clickUV,destination=link.to}
 end end
end
function H.Bind(v,U)
 if v.hoverResponse then return end
 local h={};v.hoverResponse=h
 local f=CreateFrame('Frame',nil,U.window);h.frame=f;f:SetFrameLevel(U.stage:GetFrameLevel()+3);f:EnableMouse(false);f:Hide();h.edges={}
 -- Hardware gear cursor and tooltip only. Normal play has no hover/click box.
 local function clear()
  if h.cursorOwned then ns.SafeCall(ResetCursor);h.cursorOwned=nil end
  if h.tooltip then if GameTooltip then GameTooltip:Hide()end;if ns.WardenLocations81 then ns.WardenLocations81.Hide()end;h.tooltip=nil end
  h.target=nil;if not h.pulse then f:Hide()end
 end
 h.Clear=clear
 function h:Update(dt)
  self.clock=(self.clock or 0)+dt
  if not U.menuHidden or not v.frame:IsVisible()or ns.WardenSceneEditor and ns.WardenSceneEditor.active or v.roomTravel and v.roomTravel.state or v.cameraMix>.001 then clear();self.pulse=nil;f:Hide();return end
  local s=v:ActiveRoom();if not s or not s.frame or not s.groundClick then clear();return end;local focus
  if self.clock>=(self.nextScan or 0)then
   self.nextScan=self.clock+.07;self.scanTarget=nil
   if type(GetMouseFoci)=='function'then local rows=GetMouseFoci();focus=rows and rows[1]elseif type(GetMouseFocus)=='function'then focus=GetMouseFocus()end
   local allowed=focus==s.groundClick or focus==v.roomBookHit
   if not focus and type(MouseIsOver)=='function'then allowed=MouseIsOver(s.groundClick)and not U.canvas:IsVisible()end
   if allowed then local x,y=GetCursorPosition();local scale=s.frame:GetEffectiveScale();local l,t=s.frame:GetLeft(),s.frame:GetTop()
    if l and t and scale>0 then self.scanTarget=H.Target(v,s,(x/scale-l)/s.drawWidth,(t-y/scale)/s.drawHeight)end
   end
  end
  local target=self.scanTarget
  if target then
   if not self.target or self.target.id~=target.id then self.since=self.clock
    if ns.WardenLocations81 then ns.WardenLocations81.Show(s.groundClick,target);self.tooltip=true elseif GameTooltip then GameTooltip:SetOwner(s.groundClick,'ANCHOR_CURSOR');GameTooltip:SetText(target.title);GameTooltip:Show();self.tooltip=true end
   end
   self.target=target;self.scene=s;if ns.WardenLocations81 then ns.WardenLocations81.Position()end
   if not self.cursorOwned and type(SetCursor)=='function'then local ok,result=pcall(SetCursor,'INTERACT_CURSOR');self.cursorOwned=ok and result~=false end
  else clear()end
  local b=self.target and self.target.bounds or self.pulse and self.pulse.bounds
  if not b then return end
  if ns.DB.journalReducedMotion then self.pulse=nil end
  local pulse=self.pulse and(self.clock-self.pulse.at)/.24
  if pulse and pulse>=1 then self.pulse=nil;pulse=nil;if not self.target then f:Hide();return end end
  local reduced=ns.DB.journalReducedMotion;local q=reduced and 1 or math.min(1,(self.clock-(self.since or self.clock))/.14)
  local pad=pulse and 3+8*pulse or 2+2*q;local width=(b[3]-b[1])*s.drawWidth+2*pad;local height=(b[4]-b[2])*s.drawHeight+2*pad
  local level=s.groundClick:GetFrameLevel()+1;if f:GetFrameLevel()~=level then f:SetFrameLevel(level)end
  f:ClearAllPoints();f:SetPoint('TOPLEFT',s.frame,'TOPLEFT',b[1]*s.drawWidth-pad,-b[2]*s.drawHeight+pad);f:SetSize(width,height);f:SetAlpha(pulse and(1-pulse)*.65 or q*.28)
  for i,t in ipairs(self.edges)do t:ClearAllPoints();if i<=2 then t:SetPoint(i==1 and'TOPLEFT'or'BOTTOMLEFT');t:SetSize(width,1)else t:SetPoint(i==3 and'TOPLEFT'or'TOPRIGHT');t:SetSize(1,height)end end;f:Show()
 end
 local click,stop=v.ClickScene,v.Stop
 v.ClickScene=function(self,s,u,y)
  local target=H.Target(self,s,u,y)
  if target and target.kind=='live-person'then return ns.AetherLive.OpenPlayer(target.peer)end
  if target and target.kind=='person'and target.guid~=ns.PlayerCard.Own()and target.guid~=ns.Chronicle.Owner()then local ok,why=U.OpenPlayer(target.guid,ns.Chronicle.Owner());return ok,ok and'Opened Aether profile'or why end
  local ok,why=click(self,s,u,y)
  if ok and target then h.pulse={at=h.clock or 0,bounds=target.bounds};h.scene=s end;return ok,why
 end
 -- Pointer feedback remains available when ambient animation is reduced or
 -- paused. Hidden parent scenes automatically suspend this input-only poll.
 local poll=CreateFrame('Frame',nil,v.frame);poll:SetAllPoints();poll:EnableMouse(false)
 poll:SetScript('OnUpdate',function(_,dt)h:Update(math.min(.25,dt))end);h.poll=poll
 v.Stop=function(self,...)clear();h.pulse=nil;f:Hide();return stop(self,...)end
 U.window:HookScript('OnHide',clear)
end
local attach=ns.WardenRealm.Attach
ns.WardenRealm.Attach=function(...)local v=attach(...);H.Bind(v,ns.UI2);return v end
