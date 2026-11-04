-- Native room prop -> existing close-up reader. No page/evidence storage changes.
local _,ns=...
local B={SECONDS=2.6};ns.WardenRoomBook=B
local N=ns.WardenNativeScene
function B.Pick(v)
 local s=v.studyScene;local a=s and s.native.actors['room-book']
 if not a or not a.ready or a.editorHidden or a.awaitSupport then return end
 return ns.WardenSceneObjectControls.ProjectPick(s.native,s.shot,a)
end
function B.Bind(v,p,U)
 if p.nativeRoomBound then return end;p.nativeRoomBound=true
 local sync,open,close,binder=p.SyncBookObject,p.OpenBook,p.CloseBook,p.OpenBookbinder
 -- The clock belongs to the stable window, not a clipped / reparented scene.
 local driver=CreateFrame('Frame',nil,U.window);driver:SetAllPoints(v.frame);driver:EnableMouse(false);driver:Hide();v.roomBookDriver=driver
 local function isBinder()return v.editingCover or p.binder and p.binder:IsShown()end
 local function representation()
  if v.campfireWelcome then p:Hide();if v.roomBookHit then v.roomBookHit:Hide()end;driver:Hide();return end
  if v.preparingRoomEndpoint then return end
  if not v.reading or not v.studyScene.definition.reader then
   if not v.studyScene.definition.reader then v.journalReading=nil;v.roomBookMotion=nil;v.cameraMix=0 end
   p:Hide();if v.roomBookHit then v.roomBookHit:Hide()end;return
  end
  if not p.closedBookSide and not v.roomBookMotion and v.cameraMix<.999 and not v.shelfFocus and not(ns.WardenSceneEditor and ns.WardenSceneEditor.active)then
   v.roomBookMotion={elapsed=0,opening=true,side='front',from=v.cameraMix,target=1,room=v.studyScene.key,nativePoseSupported=false,recovered=true};driver:Show()
  end
  local reading=not p.closedBookSide and not v.roomBookMotion and not v.shelfFocus
  if reading and v.journalReading and U.journalHost and not U.journalHost:IsShown()then U.journalHost:Show();U.LayoutJournal()end
  p:SetShown(reading or isBinder())
  local a=v.studyScene.native.actors['room-book']
  if a then
   -- The physical prop owns the cover motion; the paper reader owns the settled
   -- close-up. Apply the handoff immediately, before the next actor tick.
   a.sceneHidden=isBinder()or reading
   if a.sceneHidden then N.Call(a.actor,'Hide');if a.hit then a.hit:Hide()end;if v.studyScene.shadows[a.id]then v.studyScene.shadows[a.id]:Hide()end
   elseif a.ready and not v.roomBookMotion then a.engine:Animate(a,147,1)end
  end
  if v.roomBookHit then v.roomBookHit:SetShown(U.menuHidden==true and not reading and not isBinder()and not v.roomBookMotion and not v.shelfFocus)end
  -- Keep the one window-owned controller armed while reading. A late reader
  -- restore/layout can change framing after the opening has already settled.
  if reading or v.roomBookMotion then driver:Show()elseif p.closedBookSide then driver:Hide()end
 end
 v.SyncRoomBook=representation
 p.SyncBookObject=function(reader,...)
  local out=sync(reader,...)
  if v.preparingRoomEndpoint then return out end
  representation();return out
 end
 local function finish(opening,side)
  v.roomBookMotion=nil;driver:Hide();p.closedBookSide=not opening and side or nil
  v:SetCameraMix(opening and 1 or 0)
  local a=v.studyScene.native.actors['room-book'];if a and a.ready then a.engine:Animate(a,opening and 149 or 147,1)end
  if opening then p.scroll:Show();p:BookLayout()end
  p:SyncBookObject();v:RefreshEffects()
  if not opening and v.journalReading then v.journalReading=nil;U.Refresh(true)end
 end
 function v:ExitJournal()
  if not self.journalReading then return end
  self.journalReading=nil;self.roomBookMotion=nil;driver:Hide();p:CancelPageTurn()
  p.closedBookSide='front';self:SetCameraMix(0);p:SyncBookObject()
 end
 function v:AdvanceRoomBook(dt)
  local m=self.roomBookMotion;if not m then return end
  if not self.studyScene.definition.reader or m.room and m.room~=self.studyScene.key then self.roomBookMotion=nil;return end
  m.elapsed=math.min(B.SECONDS,m.elapsed+dt)
  if self.lastRoomBookTransition then self.lastRoomBookTransition.ticks=(self.lastRoomBookTransition.ticks or 0)+1;self.lastRoomBookTransition.elapsed=m.elapsed end
  local a=self.studyScene.native.actors['room-book']
  if a and a.ready and m.nativePoseSupported and not m.poseSettled and m.elapsed>=(a.spec.nativeSequenceSeconds or .333)then
   m.poseSettled=true;a.engine:Animate(a,m.opening and 149 or 147,1)
  end
  local q=m.elapsed/B.SECONDS;q=q*q*(3-2*q)
  self:SetCameraMix(m.from+(m.target-m.from)*q)
  if m.elapsed>=B.SECONDS then finish(m.opening,m.side)end
 end
 driver:SetScript('OnUpdate',function(_,dt)
  if not v.reading or not v.frame:IsVisible()then driver:Hide();return end
  if v.roomBookMotion then v:AdvanceRoomBook(math.max(0,dt));return end
  driver.elapsed=(driver.elapsed or 0)+math.max(0,dt);if driver.elapsed<.1 then return end;driver.elapsed=0
  if v.journalReading and not v.shelfFocus and not isBinder()then
   -- Source refreshes and window focus can hide the reader after it has opened.
   -- Recover presentation only; never restart collectors, replace text or travel.
   if p.closedBookSide then p.closedBookSide=nil end
   representation();if ns.WardenReadingCamera then ns.WardenReadingCamera.Stack(v)end
  elseif not p.closedBookSide and v.cameraMix<.999 and not v.shelfFocus and not isBinder()then representation()
  elseif p.closedBookSide then driver:Hide()end
 end)
 driver:SetScript('OnHide',function()
  local m=v.roomBookMotion;if m and not v.frame:IsVisible()then
   v.roomBookMotion=nil
   if m.opening then p.closedBookSide=nil else p.closedBookSide=m.side end
   v.cameraMix=m.target
  end
 end)
 function v:OpenRoomBook(opening,side)
  if self.campfireWelcome then return false,'The campfire welcome owns the camera'end
  if self.shelfFocus then return false end
  if not self.studyScene.definition.reader then self.roomBookMotion=nil;self.cameraMix=0;p:Hide();return false end
  local editing=ns.WardenSceneEditor and ns.WardenSceneEditor.active
  if editing then self.roomBookMotion=nil end
  if self.roomBookMotion or p.turnState then return false end
  p:CancelPageTurn();p.document:FinishWordReveal();p.rightPage:FinishWordReveal()
  side=side=='back'and'back'or'front'
  -- Retain AthenaFinalBookUI's existing endpoint selection, saved back folio,
  -- typesetting and deferred-bookmark handling. Only its physical cover motion
  -- is replaced. Preparation is synchronous and never exposes intermediate ink.
  local from=self.cameraMix;local reduced=ns.DB.journalReducedMotion
  self.preparingRoomEndpoint=true;ns.DB.journalReducedMotion=true
  local prepared,result=pcall(function()
   if p.bookMotion and p.bookMotion.active then p.bookMotion:Cancel(true)end
   if opening then return open(p)else return close(p,side)end
  end)
  ns.DB.journalReducedMotion=reduced;self.preparingRoomEndpoint=nil
  p.cameraPreparing=nil;p.openingCover=nil
  if not prepared then
   self.lastBookError=tostring(result);self.cameraMix=from;p.closedBookSide=side
   return false,'Journal opening was interrupted; click the book to try again'
  end
  if result==false then return false end
  self.lastBookError=nil
  self.cameraMix=from;p.closedBookSide=side
  if editing then finish(opening,side);return true end
  if ns.DB.journalReducedMotion==true then finish(opening,side);return true end
  local a=self.studyScene.native.actors['room-book'];local animation=opening and 148 or 146
  self.roomBookMotion={room=self.studyScene.key,opening=opening,side=side,elapsed=0,from=self.cameraMix,target=opening and 1 or 0,
   animation=animation,nativePoseSupported=a and a.capabilities[animation]==true or false}
  self.lastRoomBookTransition={animation=animation,duration=B.SECONDS,nativePoseSupported=self.roomBookMotion.nativePoseSupported,ticks=0,from=from,target=self.roomBookMotion.target,clock='stable window driver'}
  p:Hide();if a then a.sceneHidden=nil;if a.ready then a.engine:Animate(a,animation,1)end end
  if self.roomBookHit then self.roomBookHit:Hide()end
  if ns.WardenAudio then ns.WardenAudio.Play(opening and'book.open'or'book.leather','cover')end
  driver:Show();self:RefreshEffects();return true
 end
 p.OpenBook=function(reader,...)
  if not v.reading or isBinder()then return open(reader,...)end
  return v:OpenRoomBook(true,reader.closedBookSide)
 end
 p.CloseBook=function(reader,side)
  if not v.reading or isBinder()then return close(reader,side)end
  return v:OpenRoomBook(false,side)
 end
 p.OpenBookbinder=function(reader,...)
  if ns.WardenShelfShowcase then return ns.WardenShelfShowcase.OpenFromReader(reader)end
  if v.roomBookMotion then return false end
  v.editingCover=true;reader:Show();local result=binder(reader,...);v.editingCover=nil
  if reader.binder and not reader.binder.roomVisibilityHook then
   reader.binder.roomVisibilityHook=true;reader.binder:HookScript('OnHide',function()v:SetCameraMix(0);representation()end)
  end
  if isBinder()then v:SetCameraMix(1);reader:Show()end;representation();return result
 end
 p:HookScript('OnShow',function()if not v.roomBookMotion then representation()end end)
 -- Full-floor input is a sibling of the wide reader. Hidden reader children
 -- cannot intercept it, and fixed navigation chrome stays above this surface.
 local click=v.studyScene.groundClick
 click:SetParent(U.window);click:ClearAllPoints()
 -- Leave the owner row and fixed chrome outside the floor's hit rectangle.
 click:SetPoint('TOPLEFT',U.stage,'TOPLEFT',0,-35);click:SetPoint('BOTTOMRIGHT',U.stage,'BOTTOMRIGHT')
 local hit=CreateFrame('Button',nil,U.window);v.roomBookHit=hit;hit:RegisterForClicks('LeftButtonUp')
 function v:StackStudyInput()
  click=self.studyScene.groundClick;click:SetParent(U.window);click:ClearAllPoints();click:SetPoint('TOPLEFT',U.stage,'TOPLEFT',0,-35);click:SetPoint('BOTTOMRIGHT',U.stage,'BOTTOMRIGHT')
  local highest=U.stage:GetFrameLevel()
  local function visit(f)
   highest=math.max(highest,f:GetFrameLevel())
   for _,child in ipairs({f:GetChildren()})do if not child.ChatWardenModal then visit(child)end end
  end
  visit(U.stage);visit(self.studyScene.frame)
  local function level(f,n)
   if f.SetFixedFrameLevel then f:SetFixedFrameLevel(false)end
   f:SetFrameLevel(n)
   if f.SetFixedFrameLevel then f:SetFixedFrameLevel(true)end
  end
  if U.canvas:IsVisible()then level(click,math.max(1,U.canvas:GetFrameLevel()-1))else level(click,highest+1)end;level(hit,highest+2)
 end
 local beforeFocus=U.window.ChatWardenBeforeFocus
 U.window.ChatWardenBeforeFocus=function(window)if beforeFocus then beforeFocus(window)end;v:StackStudyInput()end
 v:StackStudyInput()
 function v:ClickRoomBook()
  local ok,why
  if not self.reading or not self.studyScene.active or not self.frame:IsVisible()then ok,why=false,'Home is hidden'
  elseif ns.WardenSceneEditor and ns.WardenSceneEditor.active then ok,why=false,'Close the scene editor before reading'
  else
   self.shelfQueued=nil
   if self.journalReading and(self.roomBookMotion or not p.closedBookSide)then
    -- A repeated click must re-arm presentation, rather than acknowledge a
    -- stranded hidden driver left by an interrupted close-up.
    driver:Show();representation();return true
   end
   ok,why=U.CloseMenu()
   if ok then
    local previousRoute,previousForward,previousBack=U.route,U.forward,{}
    for i,route in ipairs(U.back)do previousBack[i]=route end
    self.journalReading=true;U.openingWorldJournal=true
    local called;called,ok,why=pcall(U.Open,{page='journey',sceneRoom=self.currentRoomKey})
    U.openingWorldJournal=nil
    if not called then self.lastBookError=tostring(ok);ok=false;why='Journal view could not be prepared'end
    if ok and U.route.bookOpened then
     local opened;opened,ok,why=pcall(self.OpenRoomBook,self,true,'front')
     if not opened then self.lastBookError=tostring(ok);ok=false;why='Journal opening was interrupted'end
    else ok=false;why=type(why)=='string'and why or'Journal history is not available yet'end
    if not ok then
     self.journalReading=nil;self.roomBookMotion=nil;driver:Hide()
     -- A failed open must not leave the empty journey canvas covering the
     -- world. Restore the prior route/history so the next click can retry.
     U.route=previousRoute;U.back=previousBack;U.forward=previousForward
     ns.Workspace.current=previousRoute and previousRoute.page
     U.Refresh(true)
    end
   end
  end
  self.bookClickCount=(self.bookClickCount or 0)+1;self.lastBookClick={accepted=ok==true,reason=why}
  return ok,why
 end
 hit:SetScript('OnClick',function()
  if N.IsSimulator()then return v:ClickRoomBook()end
  -- Use the same oriented volume as the floor route, not the rectangular
  -- button's empty corners. Misses pass through to the existing floor action.
  return v:CursorSceneClick(v.studyScene,'desk book surface')
 end)
 local sceneClick=v.ClickScene
 v.ClickScene=function(self,s,u,y)
  if s==self.studyScene and self.reading and self.cameraMix<.001 and ns.WardenSceneObjectControls.ContainsPick(B.Pick(self),u,y)then return self:ClickRoomBook()end
  return sceneClick(self,s,u,y)
 end
 if N.IsSimulator()then
  local label=hit:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');label:SetAllPoints();label:SetText('Open book\n(native model requires WoW)');label:SetTextColor(1,.85,.5)
 end
 function v:LayoutRoomBookHit()
  if self.shelfFocus then hit:Hide();hit:EnableMouse(false);return end
  local x,y=self:BookAnchor();local s=self.studyScene;local rx,rt=s.frame:GetLeft(),s.frame:GetTop();local left,top=U.stage:GetLeft(),U.stage:GetTop()
  if not rx or not rt or not left or not top then return end
  local a=s.native.actors['room-book'];local w=math.max(42,s.drawWidth*.045);local h=math.max(28,s.drawHeight*.07)
  local volume=B.Pick(self);self.roomBookPick=volume
  if volume then
   x,y=(volume.left+volume.right)/2,(volume.top+volume.bottom)/2
   w=math.max(24,(volume.right-volume.left)*s.drawWidth);h=math.max(24,(volume.bottom-volume.top)*s.drawHeight)
  end
  hit:ClearAllPoints();hit:SetPoint('TOPLEFT',U.stage,'TOPLEFT',rx+x*s.drawWidth-left-w/2,rt-y*s.drawHeight-top+h/2);hit:SetSize(w,h)
  hit:EnableMouse(U.menuHidden==true and(volume~=nil or N.IsSimulator())and not U.canvas:IsVisible()and not(ns.WardenSceneEditor and ns.WardenSceneEditor.active))
  self.bookInputStatus=volume and'Native oriented book bounds registered'or N.IsSimulator()and'Simulator placeholder only'or'Waiting for native book projection'
 end
 -- Native projection may become valid after the actor-ready callback. Retry
 -- only while this small closed-book surface is visible, without a new timer.
 hit:SetScript('OnUpdate',function(_,dt)
  if not v.reading or v.roomBookMotion then return end
  hit.elapsed=(hit.elapsed or 0)+(dt or 0);if hit.elapsed<.2 then return end;hit.elapsed=0;v:LayoutRoomBookHit()
 end)
 local report=v.Report
 v.Report=function(self,...)
  local out=report(self,...);out.bookInput={clicks=self.bookClickCount or 0,last=self.lastBookClick,status=self.bookInputStatus,bounds=self.roomBookPick,error=self.lastBookError};out.bookCamera={mix=self.cameraMix,transform=self.cameraTransform,driverShown=driver:IsShown(),driverVisible=driver:IsVisible(),animating=self.roomBookMotion~=nil,readerVisible=p:IsVisible(),closedSide=p.closedBookSide,worldReading=self.journalReading==true,preparing=self.preparingRoomEndpoint==true};return out
 end
 v:LayoutRoomBookHit();representation()
end
