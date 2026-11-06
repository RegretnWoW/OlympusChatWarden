-- One logical canvas. Windowed resizing changes uniform scale, including every
-- native ModelScene; fullscreen contains that canvas without stretching it.
local _,ns=...;local U,C,T=ns.UI2,ns.UI2Components,ns.Theme
local W={width=1600,height=900};ns.WardenWindow=W
local function busy()return ns.Checked(ns.SafeCall(InCombatLockdown))end
function W.SyncMatte()
 local f,m=U.window,W.matte;if not f or not m then return end
 -- Focus changes the complete window tree's strata and level. The independent
 -- fullscreen backing must follow it, always one level below the world.
 m:SetFrameStrata(f:GetFrameStrata());m:SetFrameLevel(math.max(0,f:GetFrameLevel()-1))
end
function W.StackGrip()
 local grip=ns.UI2LayoutEditor and ns.UI2LayoutEditor.resizeGrip
 if not grip or not U.restoreMenu then return end
 ns.WardenSceneGraph.StackTree(grip,U.restoreMenu:GetFrameLevel()+1)
 grip:SetShown(not W.fullscreen)
end
function W.RelayoutOwned()
 local v=U.realm;if v and v.frame:IsVisible()then v:Layout();if v.RefreshFieldInput then v:RefreshFieldInput()end end
 local replay=ns.ChronicleReplay and ns.ChronicleReplay.view;if replay and replay:IsVisible()then replay:FitMap()end
 if UIParent.GetChildren then for _,f in ipairs({UIParent:GetChildren()})do
  if f.ChatWardenModalOwner==U.window and f:IsShown()then T.FitWindow(f,f:GetWidth(),f:GetHeight())end
 end end
end
function W.Fit()
 local f=U.window;if not f or busy()or W.fitting then return end;W.fitting=true
 if f:GetWidth()~=W.width or f:GetHeight()~=W.height then f:SetSize(W.width,W.height)end
 local scale
 if W.fullscreen then
  -- The live torch extends twelve design units above its mounting. Contain
  -- that artwork as well, so fullscreen never clips the flame at the screen.
  scale=math.min(UIParent:GetWidth()/W.width,UIParent:GetHeight()/(W.height+24))
  f:ClearAllPoints();f:SetPoint('CENTER',UIParent,'CENTER');W.SyncMatte();W.matte:Show()
 else scale=T.WindowScale(W.width,W.height);if W.matte then W.matte:Hide()end end
 f:SetScale(scale);f.ChatWardenWindowScale=scale;f.ChatWardenFitWidth=W.width;f.ChatWardenFitHeight=W.height
 if U.LayoutNavigation then U.LayoutNavigation(W.width,false)end
 if U.LayoutJournal then U.LayoutJournal()end
 if U.fullscreenButton then C.WindowIcon(U.fullscreenButton,W.fullscreen and'windowed'or'fullscreen');T.Tooltip(U.fullscreenButton,W.fullscreen and'Restore window'or'Fullscreen','Uniform proportions are preserved.')end
 W.StackGrip()
 W.fitting=nil
 if U.route and f:IsShown()then U.Refresh(true)end
 W.RelayoutOwned()
 -- Native viewports can settle a frame after their effective scale changes.
 -- One bounded two-frame reflow preserves replay cursor and book motion.
 if W.reflow then W.reflow.remaining=2;W.reflow:Show()end
end
function W.Toggle()
 if busy()then return false end
 local f=U.window
 if not W.fullscreen then
  local point,relative,to,x,y=f:GetPoint(1);W.restore={point or'CENTER',relative or UIParent,to or'CENTER',x or 0,y or 0}
  W.fullscreen=true;W.matte:Show()
 else
  W.fullscreen=false;W.matte:Hide();f:ClearAllPoints();f:SetPoint(unpack(W.restore or{'CENTER',UIParent,'CENTER',0,0}))
 end
 W.Fit();return true
end
function W.BeginScale()
 if busy()or W.fullscreen then return false end
 if ns.UI2LayoutEditor then ns.UI2LayoutEditor.EndDrag()end
 local x,y=GetCursorPosition();local f=U.window;local scale=f:GetScale();local ps=UIParent:GetEffectiveScale()
 W.drag={x=x,y=y,scale=scale,w=W.width*scale*ps,h=W.height*scale*ps};return true
end
function W.UpdateScale()
 local d=W.drag;if not d then return end
 local x,y=GetCursorPosition();local factor=math.max(.05,1+((x-d.x)*d.w-(y-d.y)*d.h)/(d.w*d.w+d.h*d.h))
 local fit=math.min((UIParent:GetWidth()-26)/W.width,(UIParent:GetHeight()-26)/W.height)
 U.window:SetScale(math.max(.1,math.min(fit,d.scale*factor)))
end
function W.EndScale()
 if not W.drag then return end;W.UpdateScale();W.drag=nil
 ns.DB.workspaceScale=1;local base=T.WindowScale(W.width,W.height)
 ns.DB.workspaceScale=math.max(.1,math.min(1.5,U.window:GetScale()/base));W.Fit()
end
function W.Attach()
 local f=U.window;if W.attached or not f then return end;W.attached=true
 if f:GetFrameLevel()<1 then f:SetFrameLevel(1)end
 local matte=CreateFrame('Frame',nil,UIParent);W.matte=matte;matte:SetAllPoints(UIParent);matte:SetFrameStrata('DIALOG');matte:SetFrameLevel(f:GetFrameLevel()-1);matte:EnableMouse(true);C.Fill(matte,C.colors.ink);matte:Hide()
 hooksecurefunc(f,'SetFrameStrata',W.SyncMatte);hooksecurefunc(f,'SetFrameLevel',W.SyncMatte);W.SyncMatte()
 local button=C.Button(U.header,'',W.Toggle,48);C.WindowIcon(button,'fullscreen');U.fullscreenButton=button;button:SetPoint('TOPRIGHT',-63,-22)
 if ns.UI2NotificationCenter and ns.UI2NotificationCenter.button then ns.UI2NotificationCenter.button:ClearAllPoints();ns.UI2NotificationCenter.button:SetPoint('TOPRIGHT',-120,-22)end
 U.LayoutHeader(W.width)
 if f.SetResizable then f:SetResizable(false)end
 local grip=ns.UI2LayoutEditor and ns.UI2LayoutEditor.resizeGrip
 if grip then
  grip.label:Hide()
  local icon=(grip.face or grip):CreateTexture(nil,'OVERLAY');icon:SetTexture('Interface\\AddOns\\OlympusChatWarden\\Media\\Window64\\drag.tga');icon:SetSize(16,16);icon:SetPoint('CENTER');grip.dragIcon=icon
  grip:SetScript('OnMouseDown',W.BeginScale);grip:SetScript('OnMouseUp',W.EndScale)
  grip:SetScript('OnUpdate',function()if W.drag then W.UpdateScale()end end)
  T.Tooltip(grip,'Hold and drag to resize','Drag this corner to make Fireside larger or smaller. The world keeps its proportions.')
 end
 local before=f.ChatWardenBeforeFocus
 f.ChatWardenBeforeFocus=function(self)if before then before(self)end;W.StackGrip()end
 f:HookScript('OnHide',function()W.EndScale();matte:Hide()end)
 f:HookScript('OnShow',function()if W.fullscreen then W.Fit()end end)
 U.header:HookScript('OnDragStart',function()if W.fullscreen then f:StopMovingOrSizing()end end)
 W.Fit()
 local reflow=CreateFrame('Frame',nil,f);W.reflow=reflow;reflow:Hide();reflow:SetScript('OnUpdate',function(self)
  W.RelayoutOwned();self.remaining=(self.remaining or 1)-1;if self.remaining<=0 then self:Hide()end
 end)
end
U.Fit=W.Fit
-- Workspace captured the previous fit function before this module loaded.
-- Every scale/settings entry must use the same 1600x900 proportional canvas.
ns.Workspace.Fit=W.Fit
local ensure=U.Ensure
function U.Ensure(...)local f=ensure(...);W.Attach();return f end
