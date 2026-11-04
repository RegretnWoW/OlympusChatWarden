-- A physical cover editor inside the existing reader. Transactions never mutate
-- entitlements; Save is the sole owner-design commit. No extra public profile.
local _,ns=...
local B,M,C=ns.WardenComposition,ns.WardenMementos,ns.UI2Components
local E={VERSION=1};ns.WardenBookbinder=E
function E.Open(p)
 if ns.WardenShelfShowcase then return ns.WardenShelfShowcase.OpenFromReader(p)end
 if p.owner~=ns.Chronicle.Owner()or not ns.Permissions.Decide('UIAccess')then return false,'OWN_JOURNAL_REQUIRED'end
 if p.binder then p.binder:Show();return true end
 if E.active then E.active:Hide()end
 if p.binderCache then return p.binderCache:BeginTransaction()end
 local editorOwner=p.owner;local before=M.Design(editorOwner);local work=B.Copy(before);local undo,redo={},{};local selected=1;local cursor=1;local closed=false;local dragOwner
 p:CancelPageTurn();local oldMotion=ns.DB.journalReducedMotion;ns.DB.journalReducedMotion=true;p:CloseBook('front');ns.DB.journalReducedMotion=oldMotion
 p.journal3WorkingRecipe=work
 local f=CreateFrame('Frame',nil,p.book);f:SetAllPoints();f:SetFrameLevel(p.bookCover:GetFrameLevel()+10);f:EnableMouse(true);p.binder=f;p.binderCache=f;E.active=f;p.bookCover:EnableMouse(false)
 local title=f:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');title:SetPoint('TOPLEFT',20,-10);title:SetText('The Bookbinder');title:SetTextColor(.91,.77,.48)
 local status=f:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');status:SetPoint('BOTTOMLEFT',18,8);status:SetPoint('BOTTOMRIGHT',-18,8);status:SetText('Drag a keepsake or use arrows · 12 placements across 24 grid cells · Save keeps your cover.');status:SetTextColor(.9,.79,.6)
 local function snapshot()undo[#undo+1]=B.Copy(work);if #undo>20 then table.remove(undo,1)end;redo={}end
 local handles={};local render
 local function layout()
  p.journal3WorkingRecipe=work;p:Journal3RefreshCover()
  for i,h in ipairs(handles)do if not work.layers[i]then h:Hide()end end
  local project=p.journal3Pose.project
  for i,l in ipairs(work.layers)do
   local h=handles[i]
   if not h then h=CreateFrame('Button',nil,f);h:SetFrameStrata(f:GetFrameStrata());h:EnableMouse(true);h:SetMovable(true);h:RegisterForClicks('LeftButtonUp');h:RegisterForDrag('LeftButton');if h.SetPropagateMouseClicks then h:SetPropagateMouseClicks(false)end;if h.SetPropagateMouseMotion then h:SetPropagateMouseMotion(false)end;local backing=h:CreateTexture(nil,'BACKGROUND');backing:SetSize(34,34);backing:SetPoint('TOPRIGHT');backing:SetColorTexture(.13,.08,.035,.85);local ink=h:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');ink:SetSize(34,34);ink:SetPoint('TOPRIGHT');ink:SetText('::');ink:SetTextColor(1,.88,.5);handles[i]=h
    h:SetScript('OnClick',function(self)selected=self.index;render()end)
    local function stop(self)
     if not self.placing then return end;self.placing=nil;self:SetScript('OnUpdate',nil)
     dragOwner=nil
     if ns.UI2 then ns.UI2.SetLayoutEditing(false)end;render();if self.moved and ns.WardenAudio then ns.WardenAudio.Play('art.place')end
    end
    local function start(self)
     if self.placing or editorOwner~=ns.Chronicle.Owner()or p.owner~=editorOwner then return end
     local x,y=GetCursorPosition();local scale=p.book:GetEffectiveScale();local u,v=p.journal3Pose.inverse(x/scale-p.book:GetLeft(),p.book:GetTop()-y/scale)
     local layer=work.layers[self.index];if not layer then return end
     self.grabU=u-layer.x/1000;self.grabV=v-layer.y/1000;self.downX=x;self.downY=y;self.placing=true;self.moved=false;selected=self.index
     dragOwner=self;self:Raise()
     if ns.UI2 then ns.UI2.SetLayoutEditing(true)end
     self:SetScript('OnUpdate',function()
      if type(IsMouseButtonDown)=='function'and not IsMouseButtonDown('LeftButton')then stop(self);return end
      if editorOwner~=ns.Chronicle.Owner()or p.owner~=editorOwner then stop(self);return end
      local x,y=GetCursorPosition();local scale=p.book:GetEffectiveScale();local u,v=p.journal3Pose.inverse(x/scale-p.book:GetLeft(),p.book:GetTop()-y/scale)
      if not self.moved then if math.abs(x-self.downX)+math.abs(y-self.downY)<5 then return end;snapshot();self.moved=true end
      local layer=work.layers[self.index];if not layer then return end
      local columns=math.ceil((layer.w+20)/250);local rows=math.ceil((layer.h+10)*6/1000)
      local col=math.max(0,math.min(4-columns,math.floor((u-self.grabU)*4+.5)));local row=math.max(0,math.min(6-rows,math.floor((v-self.grabV)*6+.5)))
      layer.x=col*250+10;layer.y=math.floor(row*1000/6)+5;layout()
     end)
    end
    h:SetScript('OnDragStart',start);h:SetScript('OnDragStop',stop)
    h:SetScript('OnMouseDown',function(self,button)if button=='LeftButton'then start(self)end end);h:SetScript('OnMouseUp',stop)
   end
   h.index=i;h:SetFrameLevel(f:GetFrameLevel()+20+i+(dragOwner==h and 20 or 0));local x,y=project(l.x/1000,l.y/1000);local right,bottom=project((l.x+l.w)/1000,(l.y+l.h)/1000)
   h:ClearAllPoints();h:SetPoint('TOPLEFT',f,'TOPLEFT',x,-y);h:SetSize(math.max(34,right-x),math.max(34,bottom-y));h:Show()
  end
 end
 local tools={};local function button(text,fn,n)
  local b=ns.UI2Components.Button(f,text,fn,92);b:SetPoint('TOPRIGHT',-16,-12-(n-1)*34);tools[#tools+1]=b;return b
 end
 button('Undo',function()local v=table.remove(undo);if v then redo[#redo+1]=B.Copy(work);work=v;render()end end,1)
 button('Redo',function()local v=table.remove(redo);if v then undo[#undo+1]=B.Copy(work);work=v;render()end end,2)
 button('Remove',function()if work.layers[selected]then snapshot();table.remove(work.layers,selected);selected=math.max(1,selected-1);render()end end,3)
 button('Layer up',function()if selected<#work.layers and work.layers[selected]then snapshot();work.layers[selected],work.layers[selected+1]=work.layers[selected+1],work.layers[selected];selected=selected+1;render()end end,4)
 button('Layer down',function()if selected>1 and work.layers[selected]then snapshot();work.layers[selected],work.layers[selected-1]=work.layers[selected-1],work.layers[selected];selected=selected-1;render()end end,5)
 local function resize(grow)
  local l=work.layers[selected];if not l then return end;snapshot()
  local columns=math.max(1,math.min(2,math.ceil((l.w+20)/250)+(grow and 1 or -1)))
  local rows=math.max(1,math.min(3,math.ceil((l.h+10)*6/1000)+(grow and 1 or -1)))
  l.w=columns*250-20;l.h=math.floor(rows*1000/6)-14
  l.x=math.min(l.x,1000-l.w-10);l.y=math.min(l.y,1000-l.h-5);render()
 end
 button('Larger',function()resize(true)end,6);button('Smaller',function()resize(false)end,7)
 local function finish(save)
  if save then
   if editorOwner~=ns.Chronicle.Owner()or p.owner~=editorOwner then status:SetText('Character changed. Reopen your own Bookbinder before saving.');return end
   local ok,why=M.SaveDesign(editorOwner,work);if not ok then status:SetText(why);return end
  end
  if save and ns.WardenAudio then ns.WardenAudio.Play('draft.save')end
  closed=true;for _,h in ipairs(handles)do h.placing=nil;h:SetScript('OnUpdate',nil)end;dragOwner=nil;p.journal3WorkingRecipe=nil;p.binder=nil;p.bookCover:EnableMouse(true);f:Hide();if E.active==f then E.active=nil end;p:Journal3RefreshCover();if ns.UI2 then ns.UI2.SetLayoutEditing(false)end
 end
 local function nudge(dx,dy)
  if editorOwner~=ns.Chronicle.Owner()or p.owner~=editorOwner then return end
  local l=work.layers[selected];if not l then return end;snapshot()
  local columns=math.ceil((l.w+20)/250);local rows=math.ceil((l.h+10)*6/1000)
  local col=math.floor((l.x-10)/250)+dx;local row=math.floor((l.y-5)*6/1000+.01)+dy
  col=math.max(0,math.min(4-columns,col));row=math.max(0,math.min(6-rows,row))
  l.x=col*250+10;l.y=math.floor(row*1000/6)+5;render()
 end
 for i,spec in ipairs({{'Left',-1,0},{'Right',1,0},{'Up',0,-1},{'Down',0,1}})do
  local b=C.Button(f,spec[1],function()nudge(spec[2],spec[3])end,44);b:SetPoint('TOPRIGHT',i%2==1 and -64 or -16,-250-math.floor((i-1)/2)*34)
 end
 button('Save',function()finish(true)end,10);button('Cancel',function()finish(false)end,11)
 local inventory=M.Inventory(p.owner);local slots={}
 for i=1,6 do local b=CreateFrame('Button',nil,f);b:SetSize(64,64);b:SetPoint('TOPLEFT',18,-44-(i-1)*70);b.preview=CreateFrame('Frame',nil,b);b.preview:SetAllPoints();b.preview:EnableMouse(false);b:RegisterForClicks('LeftButtonUp','RightButtonUp');slots[i]=b;local face=C.TactileRow(b,function(self)return self.item~=nil end);b.preview:SetParent(face);b.preview:SetAllPoints(face)
  b:SetScript('OnClick',function(self,button)
   local item=self.item;if not item then return end;if button=='RightButton'then ns.WardenStudio.InspectArtifact(item);return end;if #work.layers>=B.MAX_LAYERS then status:SetText('Cover full: remove a placement before adding another.');return end
   snapshot();local n=#work.layers;local col=n%4;local row=math.floor(n/4);local span=item.family=='banner'and 2 or 1
   work.layers[n+1]={art=item.art,stage=item.stage,charms=ns.Athena.Copy(item.charms),x=col*250+10,y=math.floor(row*1000/6)+5,w=230,h=span==2 and 318 or 152};selected=n+1;render()
  end)
 end
 local pager=ns.UI2Components.Button(f,'More keepsakes',function()inventory=M.Inventory(p.owner);cursor=cursor+6;if cursor>#inventory then cursor=1 end;render()end,125);pager:SetPoint('BOTTOMLEFT',16,34)
 local sanctuary=C.Button(f,'Sanctuary',function()ns.WardenSanctuary.OpenCollection()end,110);sanctuary:SetPoint('BOTTOMLEFT',148,34)
 render=function()
  for n,b in ipairs(slots)do local item=inventory[cursor+n-1];b.item=item;b:SetShown(item~=nil);if item then
   local view={version=1,catalog=3,layers={{art=item.art,stage=item.stage,charms=item.charms,x=0,y=0,w=1000,h=1000}}};local change=M.TakeEvolution(p.owner,item.key);if change then B.Animate(b.preview,view,change.from,change.to)else B.Render(b.preview,view)end
   ns.Theme.Tooltip(b,item.title,(item.commemoration or B.stages[item.stage])..' · '..(item.questsCount or 0)..' distinct quest completions; '..(item.victories or 0)..' distinct boss victories. Cosmetic history, not a certified whole-instance clear. Removing a placement keeps this memento.')
  end end
  if #inventory==0 then status:SetText('No reliably observed entry stamps yet. Your existing cover is preserved. Gameplay collection follows your current consent settings.')end
  layout()
 end
 function f:DiscardPrivateDesign()
  self:Hide();work={version=1,catalog=3,layers={}};undo,redo={},{};before=nil;inventory={}
  for _,slot in ipairs(slots)do slot.item=nil;B.Render(slot.preview,{version=1,catalog=3,layers={}})end
  B.Render(p.journal3Adornment,{version=1,catalog=3,layers={}})
 end
 function f:BeginTransaction()
  if p.owner~=ns.Chronicle.Owner()or not ns.Permissions.Decide('UIAccess')then return false,'OWN_JOURNAL_REQUIRED'end
  editorOwner=p.owner;before=M.Design(editorOwner);work=B.Copy(before);undo,redo={},{};selected=1;cursor=1;closed=false;inventory=M.Inventory(editorOwner)
  p:CancelPageTurn();local reduced=ns.DB.journalReducedMotion;ns.DB.journalReducedMotion=true;p:CloseBook('front');ns.DB.journalReducedMotion=reduced
  p.journal3WorkingRecipe=work;p.binder=self;E.active=self;p.bookCover:EnableMouse(false)
  status:SetText('Drag a keepsake or use arrows · 12 placements across 24 grid cells · Save keeps your cover.');self:Show();render();return true
 end
 f:HookScript('OnHide',function()p.bookCover:EnableMouse(true);if E.active==f then E.active=nil end;if not closed then p.journal3WorkingRecipe=nil;p.binder=nil;for _,h in ipairs(handles)do h:SetScript('OnUpdate',nil)end;if ns.UI2 then ns.UI2.SetLayoutEditing(false)end end end)
 render();return true
end
function E.ResetPrivacyRuntime()if E.active then E.active:DiscardPrivateDesign()end end
