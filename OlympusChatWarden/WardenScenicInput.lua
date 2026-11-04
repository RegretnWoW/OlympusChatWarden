-- Scene-only input. The canvas keeps its wheel handlers; empty canvas clicks
-- reach the same bounded movement controller as the actual scenic floor.
local _,ns=...
local X={};ns.WardenScenicInput=X
function X.Attach(v,U)
 local s=v.forest;local floor=s.groundClick
 floor:SetParent(U.window);floor:ClearAllPoints()
 floor:SetPoint('TOPLEFT',U.stage,'TOPLEFT',0,-35);floor:SetPoint('BOTTOMRIGHT',U.stage,'BOTTOMRIGHT')
 function v:CursorSceneClick(scene,source)
  local scale=scene.frame:GetEffectiveScale();local x,y=GetCursorPosition();local left,top=scene.frame:GetLeft(),scene.frame:GetTop()
  if not left or not top or scale<=0 then return false,'Scene viewport unavailable'end
  local u,q=(x/scale-left)/scene.drawWidth,(top-y/scale)/scene.drawHeight
  local ok,why=self:ClickScene(scene,u,q)
  self.lastWalkStatus=ok and'Character interaction'or why;self.sceneClickCount=(self.sceneClickCount or 0)+1;scene.clickCount=(scene.clickCount or 0)+1
  self.lastSceneClick={scene=scene.key,u=u,v=q,accepted=ok==true,reason=why,source=source}
  return ok,why
 end
 floor:SetScript('OnClick',function()v:CursorSceneClick(s,'field floor')end)
 -- These three existing wheel surfaces cover otherwise empty Hall ground.
 -- Children retain their own buttons, links, dragging and selection handlers.
 for _,frame in ipairs({U.canvas,U.canvas.scroll,U.canvas.content})do
  frame:HookScript('OnMouseUp',function(self,button)
   local scene=v:ActiveRoom()
   if button~='LeftButton'or not scene.active or not U.route or U.route.page=='journey'or U.route.page=='chronicle'and U.route.subsection=='replay'or ns.UI2Components.EditBlocked(self)then return end
   -- A card's decorative margin is not exposed ground either.
   local x,y=GetCursorPosition();local scale=self:GetEffectiveScale();x,y=x/scale,y/scale
   for _,card in ipairs(U.canvas.cards or{})do if card:IsVisible()then local l,b,w,h=card:GetRect();if l and x>=l and x<=l+w and y>=b and y<=b+h then return end end end
   v:CursorSceneClick(scene,'exposed scene canvas')
  end)
 end
 function v:StackFieldInput()
  local highest=U.stage:GetFrameLevel()
  -- In the full scene there are no visible cards to protect; bring its floor
  -- above stale mouse containers. Normal cards retain their existing order.
  if not U.canvas:IsVisible()then
   local count=0;local function visit(f)
    count=count+1;if count>2048 or f.ChatWardenModal then return end
    highest=math.max(highest,f:GetFrameLevel());for _,child in ipairs({f:GetChildren()})do visit(child)end
   end
   visit(U.stage);visit(s.frame)
  end
  if floor.SetFixedFrameLevel then floor:SetFixedFrameLevel(false)end
  floor:SetFrameLevel(highest+1)
  if floor.SetFixedFrameLevel then floor:SetFixedFrameLevel(true)end
 end
 function v:RefreshFieldInput()
  -- Shared scene means shared input on exposed ground, regardless of which
  -- content tab is open. Card surfaces remain above this floor.
  floor:SetShown(s.active and self.frame:IsVisible())
  if ns.WardenSceneEditor and ns.WardenSceneEditor.active then floor:EnableMouse(false)end
  self:StackFieldInput()
 end
 local before=U.window.ChatWardenBeforeFocus
 U.window.ChatWardenBeforeFocus=function(window)if before then before(window)end;v:StackFieldInput()end
 v:RefreshFieldInput()
end
