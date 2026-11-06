-- Scene props -> existing book-cover/motion and badge recipes/showcase rules.
-- All content and saved layouts below are synthetic session-only demo state.
local _,ns=...
local N,C,S=ns.WardenNativeScene,ns.WardenComposition,ns.ExperimentShelfState
local L={};ns.ExperimentLibrary=L
local art='Interface\\AddOns\\Fireside3DExperiment\\Media\\Library\\'
ns.DB={journalReducedMotion=false}
ns.SafeCall=function(fn,...)if type(fn)=='function'then local ok,value=pcall(fn,...);if ok then return value end end end
ns.SafeNumber=function(n)return type(n)=='number'and n==n and n or nil end
ns.Theme={Tooltip=function(frame,title,body)
 frame:HookScript('OnEnter',function()GameTooltip:SetOwner(frame,'ANCHOR_RIGHT');GameTooltip:SetText(title);if body then GameTooltip:AddLine(body,1,1,1,true)end;GameTooltip:Show()end)
 frame:HookScript('OnLeave',function()GameTooltip:Hide()end)
end}
local function label(parent,text,x,y,w,h)
 local f=parent:CreateFontString(nil,'OVERLAY','GameFontNormal');f:SetPoint('TOPLEFT',x,y);f:SetSize(w,h);f:SetText(text);return f
end
local function button(parent,text,x,y,w,fn)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetPoint('TOPLEFT',x,y);b:SetSize(w,26);b:SetText(text);b:SetScript('OnClick',fn);return b
end
local function panel(parent,title)
 local f=CreateFrame('Frame',nil,parent);f:SetAllPoints();f:SetFrameLevel(parent:GetFrameLevel()+300);f:EnableMouse(true)
 local bg=f:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();bg:SetColorTexture(.055,.065,.08,1)
 label(f,title,24,-14,800,30);f:Hide();return f
end
local pages={
 {'The Third Dimension','DEMO JOURNAL\n\nThis is a synthetic test manuscript, not your recorded history.\n\nA house, a table, a chair and two scenic people share one native scene. Your own character moves through it.'},
 {'One world','Rotate completely around the house while moving. Pitch and zoom. Check the floor contacts, table, chair and people for sliding or floating.'},
 {'Take a seat','Click the outside chair. Approach, sit, rotate the camera, then stand with WASD. The existing Fireside seating and animation routines own this interaction.'},
 {'A journal in the house','The native book uses Fireside’s existing book model and open/close sequences when the client supports them. These covers and page timing reuse the existing Journal presentation code.'},
 {'Memories on a shelf','Open the interior showcase. Select two slots to swap badges, remove a badge, or restore the sample layout. Save and Cancel affect only this session.'},
 {'Back to the world','Close the reader and continue walking. Nothing here collects history, grants earned badges, writes a database or changes your real WoW character position.'},
}
function L.DefaultShelf()
 local state={version=1,slots={}};for i,id in ipairs(ns.ExperimentSampleIDs)do state.slots[i]=id end;return state
end
function L.Pick(engine,shot,ids,u,v)
 local winner,nearest
 for _,id in ipairs(ids)do local a=engine.actors[id]
  if a and a.ready and not a.failed then
   local bounds=ns.WardenSceneObjectControls.ProjectPick(engine,shot,a)
   if ns.WardenSceneObjectControls.ContainsPick(bounds,u,v)then
    local p=a.position;local _,_,depth=N.Project(engine.viewShot or shot,p[1],p[2],p[3]+a.top*.5,engine.frame:GetWidth()/engine.frame:GetHeight())
    if depth and depth>0 and(not nearest or depth<nearest)then winner=id;nearest=depth end
   end
  end
 end
 return winner
end
function L.Approach(engine,shot,a,id,nav)
 local prop=engine.actors[id];if not prop or not prop.ready then return nil,'Object is not loaded'end
 if id=='room-book'then prop=engine.actors.table end
 local box=prop and N.Footprint(shot,prop);if not box then return nil,'Object support is not loaded'end
 local p=prop.position;local margin=nav.radius+.2
 local best
 for _,point in ipairs({{box.left-margin,p[2]},{box.right+margin,p[2]},{p[1],box.near-margin},{p[1],box.far+margin}})do
  local dx,dy=a.position[1]-point[1],a.position[2]-point[2]
  if dx*dx+dy*dy<.02 and N.CheckPath({samples={{x=point[1],y=point[2],z=0}}},nav)then return false end -- already at a valid approach
  local path=N.WalkPath(a.position,point[1],point[2],nav)
  if path and(not best or path.length<best.length)then best=path end
 end
 return best,best and nil or 'No clear approach; verify the interior doorway trial'
end
function L.New(parent,engine,shot,onOpen)
 local self={engine=engine,shot=shot,saved=L.DefaultShelf(),clicks=0,opens=0}
 local reader=panel(parent,'DEMO JOURNAL — synthetic pages');self.reader=reader
 local p=reader;p.book=CreateFrame('Frame',nil,p);p.book:SetSize(820,490);p.book:SetPoint('CENTER',0,-10)
 local paper=p.book:CreateTexture(nil,'BACKGROUND');paper:SetAllPoints();paper:SetTexture(art..'OpenBook.tga')
 p.scroll=CreateFrame('Frame',nil,p.book);p.scroll:SetPoint('TOPLEFT',50,-65);p.scroll:SetSize(340,350)
 p.rightScroll=CreateFrame('Frame',nil,p.book);p.rightScroll:SetPoint('TOPLEFT',430,-65);p.rightScroll:SetSize(340,350)
 local left=label(p.scroll,'',0,0,340,350);left:SetJustifyH('LEFT');left:SetJustifyV('TOP');left:SetTextColor(.22,.13,.07)
 local right=label(p.rightScroll,'',0,0,340,350);right:SetJustifyH('LEFT');right:SetJustifyV('TOP');right:SetTextColor(.22,.13,.07)
 p.document={FinishWordReveal=function()end};p.rightPage={FinishWordReveal=function()end}
 p.search=CreateFrame('EditBox',nil,p.book);p.search:SetAutoFocus(false);p.search:Hide();p.notice=label(p.book,'',0,0,1,1);p.notice:Hide();p.memoryRail={}
 p.libraryToggle=button(p.book,'First page',340,-450,130,function()p:CancelPageTurn();self.leaf=1;p:BookLayout()end)
 self.leaf=1
 function p:BookLayout()
  local a,b=pages[self.owner.leaf],pages[self.owner.leaf+1]
  paper:SetShown(not self.closedBookSide)
  left:SetText(a and(a[1]..'\n\n'..a[2])or'');right:SetText(b and(b[1]..'\n\n'..b[2])or'')
  self.scroll:SetShown(not self.closedBookSide);self.rightScroll:SetShown(not self.closedBookSide)
 end
 p.owner=self
 function p:CancelPageTurn()if self.bookMotion then self.bookMotion:Cancel(true)end end
 function p:SetBookPresentationAlpha(alpha)self.scroll:SetAlpha(alpha);self.rightScroll:SetAlpha(alpha)end
 ns.AthenaBookObject.Attach(p,paper,{},p.scroll,p.rightScroll)
 local openBook,closeBook=p.OpenBook,p.CloseBook
 p.OpenBook=function(reader,...)
  if not self.preparedReader then self:NativePose(true)end
  return openBook(reader,...)
 end
 p.CloseBook=function(reader,...)
  self:NativePose(false);return closeBook(reader,...)
 end
 local motion=ns.AthenaBookMotion.For(p)
 local turn=CreateFrame('Frame',nil,p.book);turn:SetAllPoints();turn:SetFrameLevel(p.book:GetFrameLevel()+30);turn:EnableMouse(false)
 local sheet=turn:CreateTexture(nil,'OVERLAY');sheet:SetTexture(art..'OpenBook.tga');sheet:Hide()
 local function turnPage(delta)
  if p.closedBookSide or p.coverMotion or p.coverTurning or motion.active then return end
  local nextLeaf=math.max(1,math.min(#pages-1,self.leaf+delta));if nextLeaf==self.leaf then return end
  motion:Start('page',p.book,ns.AthenaBookMotion.PAGE_SECONDS,function(q)
   local angle=ns.AthenaBookMotion.Sample(ns.AthenaBookMotion.page,q)
   local width=math.max(1,math.abs(math.cos(angle))*370)
   sheet:ClearAllPoints();sheet:SetPoint(math.cos(angle)>0 and'LEFT'or'RIGHT',p.book,'CENTER',0,0);sheet:SetSize(width,450)
   sheet:SetTexCoord(math.cos(angle)>0 and .5 or 0,math.cos(angle)>0 and 1 or .5,0,1);sheet:Show()
   if q>=.5 then self.leaf=nextLeaf;p:BookLayout()end
  end,function()sheet:Hide();self.leaf=nextLeaf;p:BookLayout()end)
 end
 button(p.book,'Previous',40,-450,110,function()turnPage(-2)end)
 button(p.book,'Next',670,-450,110,function()turnPage(2)end)
 button(reader,'Return to scene',805,-18,160,function()self:Close()end)
 p.closedBookSide='front';p:SyncBookObject()
 local showcase=panel(parent,'DEMO BADGES & MEMENTOS — session layout');self.showcase=showcase
 local note=label(showcase,'Select a badge, then a destination to swap. Sample art is not earned history.',24,-48,920,40)
 local positions={{420,-95},{300,-215},{540,-215},{300,-335},{540,-335},{300,-455},{540,-455}}
 local tiles={}
 function self:PaintShelf()
  for i,tile in ipairs(tiles)do
   local id=self.work.slots[i];tile.art:Hide()
   if id then
    tile.art:Show();C.Render(tile.art,{version=1,catalog=3,layers={{art=id,x=0,y=0,w=1000,h=1000,stage=5,charms=ns.ExperimentSampleCharms[id]}}})
   end
   tile.caption:SetText((self.selected==i and '> 'or'')..i..(id and '' or ' (empty)'))
  end
 end
 for i,pos in ipairs(positions)do
  local slot=i;local tile=CreateFrame('Button',nil,showcase);tile:SetPoint('TOPLEFT',pos[1],pos[2]);tile:SetSize(110,110)
  tile.art=CreateFrame('Frame',nil,tile);tile.art:SetAllPoints();tile.art:EnableMouse(false)
  tile.caption=label(tile,'',0,0,110,18);tiles[i]=tile
  tile:SetScript('OnClick',function()
   if self.selected then S.Swap(self.work,self.selected,slot);self.selected=nil else self.selected=slot end
   self:PaintShelf()
  end)
 end
 button(showcase,'Remove',24,-590,110,function()if self.selected then self.work.slots[self.selected]=nil;self.selected=nil;self:PaintShelf()end end)
 button(showcase,'Restore samples',145,-590,150,function()self.work=L.DefaultShelf();self.selected=nil;self:PaintShelf()end)
 button(showcase,'Save session',310,-590,130,function()local valid,why=S.Validate(self.work);if valid then self.saved=valid;self.selected=nil;note:SetText('Layout saved for this session only.');self:PaintShelf()else note:SetText(why)end end)
 button(showcase,'Cancel edits',455,-590,130,function()self.work=S.Validate(self.saved);self.selected=nil;note:SetText('Unsaved changes discarded.');self:PaintShelf()end)
 button(showcase,'Return to scene',805,-18,160,function()self:Close()end)
 function self:IsModal()return reader:IsShown()or showcase:IsShown()or self.bookTransition~=nil end
 function self:Support()
  local book,tableActor=engine.actors['room-book'],engine.actors.table
  if book and book.ready and tableActor and tableActor.ready then engine:Place(book,tableActor.position[1],tableActor.position[2],tableActor.position[3]+tableActor.top+.015,0)end
 end
 function self:NativePose(opening)
  local book=engine.actors['room-book']
  self.nativeBookPose=engine:Animate(book,opening and 148 or 146,1)==true
  self.poseTransition={opening=opening,elapsed=0}
 end
 function self:Open(id)
  local actor=engine.actors[id];if not actor or not actor.ready then return false,'Object unavailable'end
  onOpen();self.opens=self.opens+1
  if id=='room-book'then
   self.bookTransition={opening=true,elapsed=0};self:NativePose(true)
  else self.work=S.Validate(self.saved);self.selected=nil;note:SetText('Select a badge, then a destination to swap. Session-only demo.');self:PaintShelf();showcase:Show()end
  return true
 end
 function self:Close(immediate)
  local wasBook=reader:IsShown()or self.bookTransition and self.bookTransition.opening
  p:CancelPageTurn();p:ResetBookObject();reader:Hide();showcase:Hide();sheet:Hide();self.selected=nil
  self.bookTransition=nil;self.poseTransition=nil
  if wasBook and not immediate then
   local book=engine.actors['room-book'];self.bookTransition={opening=false,elapsed=0}
   self:NativePose(false)
  elseif immediate then local book=engine.actors['room-book'];if book and book.ready then engine:Animate(book,147,1)end end
 end
 function self:Tick(dt)
  local pose=self.poseTransition
  if pose then pose.elapsed=pose.elapsed+dt;if pose.elapsed>=.333 then engine:Animate(engine.actors['room-book'],pose.opening and 149 or 147,1);self.poseTransition=nil end end
  local m=self.bookTransition;if not m then return end
  m.elapsed=m.elapsed+dt
  if m.elapsed>=2.6 then self.bookTransition=nil;if m.opening then reader:Show();p.closedBookSide='front';p:SyncBookObject();self.preparedReader=true;p:OpenBook();self.preparedReader=nil end end
 end
 return self
end
