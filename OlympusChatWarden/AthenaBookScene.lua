-- Journal3 pose layer. Manuscripts, pagination and anchors remain owned by the
-- existing reader. Legacy presentation remains available to private Lab rollback.
local _,ns=...
local J={VERSION=4};ns.AthenaBookScene=J
local B=ns.WardenComposition;local O=ns.AthenaBookObject;J.LegacyAttach=O.Attach
function J.Path(id)return B.base..id..'.tga'end
-- A single physical desk plane owns the camera. The book has one aspect in
-- regular, immersive, narrow and ultrawide windows; neither axis is stretched.
function J.Bounds(reader,width,height)
 local plane=ns.UI2 and ns.UI2.realm and ns.UI2.realm.readingPlane
 if plane and plane:IsShown()and plane:GetWidth()>1 and plane:GetHeight()>1 then
  local pw,ph=plane:GetWidth(),plane:GetHeight()
  local ratio=plane:GetEffectiveScale()/reader:GetEffectiveScale();pw=pw*ratio;ph=ph*ratio
  local x=plane:GetLeft()*ratio-reader:GetLeft();local y=reader:GetTop()-plane:GetTop()*ratio
  local realm=ns.UI2.realm
  -- Typeset at the reading target once. Camera motion changes the entire book's
  -- uniform scale/position, never page width, pagination or live font metrics.
  local logical=realm and realm.bookTargetWidth and realm.bookTargetWidth*ratio or pw*.61
  local scale=pw*.61/logical
  return x+pw*.195,-(y+ph*.25),logical,logical/1.6,scale
 end
 local bw=math.min(width*.82,height*.78*1.6);return(width-bw)/2,-(height-bw/1.6)/2,bw,bw/1.6,1
end
function J.PlaceBook(p,width,height)
 local x,y,w,h,scale=J.Bounds(p,width,height);scale=scale or 1
 p.book:SetScale(scale);p.book:ClearAllPoints();p.book:SetPoint('TOPLEFT',p,'TOPLEFT',x/scale,y/scale);p.book:SetSize(w,h)
 return x,y,w,h,scale
end
-- Shared physical leaf envelope, in book-local coordinates. The live paper,
-- moving sheet and frozen ink must use this same tabletop-anchored geometry.
function J.PageGeometry(w,h)return w*.5,w*.39,h*.13,h*.70 end
function J.Project(x,y,w,h)
 local v=math.max(0,math.min(1,y/h));local half=w*.5;local factor=.06*v;factor=factor+.94
 local px=x-half;px=px*factor;px=px+half;return px,y
end
function J.Attach(p,art,single,folioLeft,folioRight)
 local A=ns.AthenaBookMotion;local director=A.For(p)
 local cover=CreateFrame('Button',nil,p.book);cover:SetAllPoints();cover:SetFrameLevel(p.book:GetFrameLevel()+220);cover:Hide()
 local guard=CreateFrame('Frame',nil,cover);guard:SetAllPoints();guard:EnableMouse(true);guard:Hide()
 local leather=cover:CreateTexture(nil,'ARTWORK');local inside=cover:CreateTexture(nil,'ARTWORK');inside:SetTexture(J.Path('OpenBook'));inside:Hide()
 local adorn=CreateFrame('Frame',nil,cover);adorn:SetAllPoints();adorn:SetFrameLevel(cover:GetFrameLevel()+2);adorn:EnableMouse(false)
 local shadow=p.book:CreateTexture(nil,'BACKGROUND',nil,-2);shadow:SetTexture(ns.WardenWorldArt.assets['contact-shadow42'].tiles[1].path);shadow:SetTexCoord(0,1,0,1);shadow:SetVertexColor(.025,.015,.008,.65);p.journalContactShadow=shadow
 local body=CreateFrame('Frame',nil,p.book);body:SetAllPoints();body:SetFrameLevel(p.book:GetFrameLevel()+2);body:EnableMouse(false);body:Hide()
 local pageBlock=body:CreateTexture(nil,'ARTWORK');pageBlock:SetTexture(J.Path('OpenBook'))
 local spine=cover:CreateTexture(nil,'BORDER');spine:SetTexture(J.Path('FrontCover'));spine:SetTexCoord(.025,.19,.07,.96)
 local thickness=cover:CreateTexture(nil,'OVERLAY');thickness:SetTexture(J.Path('FrontCover'));thickness:SetTexCoord(.94,.96,.08,.92);thickness:SetVertexColor(.65,.54,.40,1)
 local close=CreateFrame('Button',nil,p.book);close:SetSize(100,26);close:SetPoint('TOPRIGHT',-28,-6);close:SetFrameLevel(p.book:GetFrameLevel()+24)
 local label=close:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');label:SetAllPoints();label:SetText('Close journal');label:SetTextColor(.66,.47,.24);close:SetScript('OnClick',function()p:CloseBook('front')end)
 if ns.UI2Components then ns.UI2Components.TactileRow(close,function()return true end)end
 -- Prepare all bounded textures before a transition is requested. No texture
 -- path changes occur on the turning board except its front/back face switch.
 local warm=CreateFrame('Frame',nil,p.book);warm:SetPoint('TOPLEFT');warm:SetSize(1,1);warm:SetAlpha(.001);warm:EnableMouse(false)
 for _,id in ipairs({'FrontCover','BackCover','OpenBook','Paper','Atmosphere'})do local t=warm:CreateTexture(nil,'BACKGROUND');t:SetAllPoints();t:SetTexture(J.Path(id))end
 local motion;local currentPose={};p.journal3Pose=currentPose
 local function recipe()
  if motion and motion.recipe then return motion.recipe end
  -- Live keepsakes are displayed on the home shelf. Preserve old saved cover
  -- designs and signed snapshots, without reattaching them to this book.
  return{version=1,catalog=3,layers={}}
 end
 local function resetInk()
  for index,view in ipairs(p.readerStillInk or{})do view.surface.projector=nil;view.surface.clipMin=nil;view.surface.clipMax=nil;view.surface.inkMotion=nil;view.surface:Draw(0,index==2,p.book:GetWidth(),p.book:GetHeight())end
 end
 local function pose(t,side,turnover)
  local w,h=p.book:GetWidth(),p.book:GetHeight();local half=w*.5;local hinge=half;local front=side~='back';local sign=front and 1 or -1
  if motion then motion.width=w;motion.height=h end
  local angle,rise,_,poseID=A.Sample(A.cover,t);local c,s=math.cos(angle),math.sin(angle)
  local function project(u,v)
   local z=half*s*u;local perspective=1/(1-z/(half*5))
   return hinge+sign*half*c*u*perspective,h*.5+(v*h-h*.5)*perspective-z*.30-h*rise*u
  end
  local x1,y1=project(0,0);local x2,y2=project(1,0);local x3,y3=project(0,1);local x4,y4=project(1,1)
  local moving=motion and not motion.turnover
  local skin=front and'FrontCover'or'BackCover'
  if turnover and c<0 then skin=front and'BackCover'or'FrontCover'end
  if leather.skin~=skin then leather:SetTexture(J.Path(skin));leather.skin=skin end
  leather:SetTexCoord(0,1,0,1);B.Quad(leather,cover,{x1,y1,x2,y2,x3,y3,x4,y4});leather:SetVertexColor(1-.17*math.abs(s),1-.17*math.abs(s),1-.17*math.abs(s),1);leather:SetShown(not moving or c>=0)
  inside:SetTexCoord(front and 0 or .5,front and .5 or 1,0,1)
  if front then B.Quad(inside,cover,{x2,y2,x1,y1,x4,y4,x3,y3})else B.Quad(inside,cover,{x1,y1,x2,y2,x3,y3,x4,y4})end
  inside:SetShown(moving and c<0);body:SetShown(moving)
  spine:ClearAllPoints();spine:SetPoint('TOPLEFT',p.book,'TOPLEFT',w*.486,-h*.10);spine:SetSize(w*.028,h*.85);spine:SetAlpha(math.min(1,math.abs(s)*3));spine:SetShown(moving)
  -- The painted leather and stationary paper block already contain their
  -- physical edges. A second near-degenerate edge quad creates an oversized
  -- strip on the emulator, so it contributes no separate overlay.
  thickness:Hide()
  shadow:ClearAllPoints();shadow:SetPoint('TOPLEFT',p.book,'TOPLEFT',w*.08+sign*s*w*.05,-h*.18);shadow:SetSize(w*.84,h*.78);shadow:SetAlpha(.48+.14*math.abs(s))
  currentPose.t,currentPose.side,currentPose.hinge,currentPose.span,currentPose.poseID=t,side,hinge,half*c*sign,poseID
  currentPose.project=function(u,v)return project(.16+u*.71,.14+v*.65)end
  currentPose.inverse=function(x,y)local v=y/h;local u=c~=0 and(x-hinge)/(half*c*sign)or 0;return(u-.16)/.71,(v-.14)/.65 end
  adorn:SetShown(front and c>.12);B.Render(adorn,recipe(),currentPose.project)
  if moving then
   art:Hide()
   -- Reveal the stationary page geometrically behind the board, not by fading
   -- or swapping a complete open-book image. Its ink follows the same clip.
   local cut=front and math.max(half,math.min(w,math.max(x2,x4)))or math.min(half,math.max(0,math.min(x2,x4)))
   local left,right=front and cut or 0,front and w or cut
   pageBlock:SetTexCoord(left/w,right/w,0,1);B.Quad(pageBlock,body,{left,0,right,0,left,h,right,h});pageBlock:SetShown(right-left>.01)
   local fixed=p.readerStillInk and p.readerStillInk[front and 2 or 1]
   if fixed then fixed.frame:Show();fixed.surface.projector=nil;fixed.surface.inkMotion=nil;fixed.surface.clipMin=left;fixed.surface.clipMax=right;fixed.surface:Draw(0,front,w,h)end
   local carried=p.readerStillInk and p.readerStillInk[front and 1 or 2]
   if carried then
    carried.frame:SetShown(c<-.55);local surf=carried.surface;surf.clipMin=nil;surf.clipMax=nil;surf.inkMotion=true
    surf.projector=function(sx,vy,rightSide)
     local spineX,paperHalf,paperTop,paperHeight=J.PageGeometry(w,h);local u=rightSide and sx or 1-sx
     local rawX=spineX+(rightSide and 1 or -1)*paperHalf*u
     local yy=paperTop+h*.03*(1-u)^2+vy*(paperHeight-h*.03*(1-u)^2-h*.03*u*u)
     local xx;xx,yy=J.Project(rawX,yy,w,h)
     local distance=front and(half-xx)/half or(xx-half)/half
     local px,py=project(distance,yy/h);return px,py,math.abs(s)*half,1
    end
    if c<-.55 then surf:Draw(0,not front,w,h)end
   end
  end
 end
 local function clean()
  guard:Hide();body:Hide();spine:Hide();thickness:Hide();p.coverTurning=nil;p.coverMotion=nil;motion=nil;resetInk()
 end
 function p:SyncBookObject()
  if self.coverMotion or self.cameraPreparing then return end
  local closed=self.closedBookSide~=nil;if not art.bookSkin then art:SetTexture(J.Path('OpenBook'));art.bookSkin=true;if ns.AthenaBookMotion then ns.AthenaBookMotion.NoteTexture()end end;art:SetTexCoord(0,1,0,1);art:SetShown(not closed)
  for _,v in ipairs(single)do v:Hide()end
  folioLeft:SetShown(not closed);folioRight:SetShown(not closed);self.libraryToggle:Hide();close:Hide()
  if not closed then shadow:ClearAllPoints();shadow:SetPoint('TOPLEFT',p.book,'TOPLEFT',-p.book:GetWidth()*.035,-p.book:GetHeight()*.055);shadow:SetSize(p.book:GetWidth()*1.07,p.book:GetHeight()*1.08);shadow:SetAlpha(.72);shadow:Show()end
  for _,edge in ipairs(self.bookCorners or{})do edge:SetShown(not closed)end
  for _,button in ipairs(self.pageTurnButtons or{})do button:SetShown(not closed)end
  if closed then self.scroll:Hide();self.rightScroll:Hide();self.search:Hide();self.search:ClearFocus();self.notice:Hide();pose(0,self.closedBookSide);cover:Show()
  else cover:Hide();self:SetBookPresentationAlpha(1)end
  if self.RefreshPaperInk then self:RefreshPaperInk()end
 end
 local function transition(opening,side)
  p.cameraPreparing=true;p.closedBookSide=nil;p.scroll:Show();p:BookLayout();p.cameraPreparing=nil
  motion={opening=opening,side=side,recipe=B.Copy(recipe())};local state=motion;p.coverMotion=state;cover:Show();guard:Show()
  local camera=p.studyCamera;local from=camera and(camera.cameraMix or(opening and 0 or 1))or 0;local target=opening and 1 or 0
  local function draw(q)
   if camera and camera.reading then local ct=A.Ease(math.min(1,q*A.COVER_SECONDS/A.CAMERA_SECONDS));camera:SetCameraMix(from+(target-from)*ct)end
   pose(opening and q or 1-q,side)
   if ns.WardenAudio then
    if q>.12 and not state.leather then state.leather=true;ns.WardenAudio.Play('book.leather','cover')end
    if q>.91 and not state.contact then state.contact=true;ns.WardenAudio.Play(opening and'book.settle'or'book.close','cover')end
   end
  end
  local function finish()
   clean();if opening then p.closedBookSide=nil else p.closedBookSide=side end;p:SyncBookObject()
   if opening then p:BookLayout();p.document:RevealWords(ns.DB.journalWritingRate or 24)end
  end
  if ns.WardenAudio then ns.WardenAudio.Play(opening and'book.open'or'book.leather','cover')end
  director:Start('cover',cover,A.COVER_SECONDS,draw,finish,function()draw(1);finish()end)
 end
 function p:CloseBook(side)
  if director.active then return false end
  self:CancelPageTurn();self.document:FinishWordReveal();self.rightPage:FinishWordReveal();side=side=='back'and'back'or'front'
  if ns.DB.journalReducedMotion~=true and not self.closedBookSide then transition(false,side)else self.closedBookSide=side;self:SyncBookObject()end;return true
 end
 function p:OpenBook()
  if director.active then return false end
  local side=self.closedBookSide
  if side and ns.DB.journalReducedMotion~=true then transition(true,side)
  else self.closedBookSide=nil;cover:Hide();self.scroll:Show();self:BookLayout();self:SyncBookObject()end
  if self.LayoutBookSearch then self:LayoutBookSearch()end;return true
 end
 function p:ResetBookObject()director:Cancel(true);clean();self:CancelPageTurn();self.closedBookSide=nil;cover:Hide()end
 function p:FlipClosedBook()
  if not self.closedBookSide or director.active then return false end
  local before=self.closedBookSide;local side=before=='front'and'back'or'front'
  if ns.DB.journalReducedMotion==true then self.closedBookSide=side;pose(0,side);return true end
  motion={side=before,turnover=true,recipe=B.Copy(recipe())};self.coverMotion=motion;guard:Show()
  director:Start('flip',cover,A.COVER_SECONDS,function(q)pose(q,before,true)end,function()clean();p.closedBookSide=side;p:SyncBookObject()end,function()clean();p.closedBookSide=before;p:SyncBookObject()end)
  return true
 end
 function p:ActivateCover(half)
  if self.binder and self.binder:IsShown()or director.active or not self.closedBookSide then return false end
  if self.closedBookSide=='front'and half=='left'or self.closedBookSide=='back'and half=='right'then return self:FlipClosedBook()end
  return self:OpenBook()
 end
 cover:SetScript('OnClick',function()local x=ns.SafeNumber(ns.SafeCall(GetCursorPosition));local scale=p.book:GetEffectiveScale();p:ActivateCover(x and scale and x/scale<p.book:GetLeft()+p.book:GetWidth()/2 and'left'or'right')end)
 p.book:HookScript('OnSizeChanged',function()
  if motion and(math.abs(p.book:GetWidth()-(motion.width or p.book:GetWidth()))>.01 or math.abs(p.book:GetHeight()-(motion.height or p.book:GetHeight()))>.01)then director:Cancel(true)
  elseif not motion and p.closedBookSide then pose(0,p.closedBookSide)end
 end)
 p.bookCover,p.closeBook,p.journal3Adornment=cover,close,adorn;p.journal3Body,p.journal3PageBlock=body,pageBlock
 function p:Journal3RefreshCover()if self.closedBookSide and not director.active then pose(0,self.closedBookSide)end end
 function p:OpenBookbinder()return ns.WardenBookbinder.Open(self)end
 function p:Journal3Pose(t,side)
  if not(ns.WardenSimLab and ns.WardenSimLab.Enabled())then return false end
  director:Cancel(true);motion={preview=true,opening=true,side=side or'front',recipe=B.Copy(recipe())};self.coverMotion=motion;cover:Show();pose(t,side or'front');return true
 end
end

O.Attach=function(...)
 if ns.WardenSimLab and ns.WardenSimLab.Enabled()and ns.DB.journal3LegacyRenderer==true then return J.LegacyAttach(...)end
 return J.Attach(...)
end
