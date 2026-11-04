-- One menu over the persistent world; never a gameplay/scheduler pause.
-- menuHidden remains the existing internal storage flag, not another mode.
local _,ns=...
local U=ns.UI2
function U.StartupReady()
 if ns.MainStorageBlocked then
  local message='Fireside saved data needs recovery. Originals are retained. Use /fireside recovery to review your recovery copies.'
  ns.Print(message);return false,message
 end
 if ns.DB and not ns.Initializing and not ns.ChronicleStore.loading then return true end
 local message='Fireside is still loading. Please wait for archive validation to finish.'
 local now=ns.SafeNumber(ns.SafeCall(GetTime))or 0
 if not U.lastLoadingNotice or now-U.lastLoadingNotice>=3 then U.lastLoadingNotice=now;ns.Print(message)end
 return false,message
end
local function editable()
 return not U.locked and not(ns.UI2LayoutEditor and ns.UI2LayoutEditor.tx)and not(ns.WardenSceneEditor and ns.WardenSceneEditor.active)
end
local function closeOwnedPopups()
 if ns.UI2Forms.active then ns.UI2Forms.active:Hide()end -- retains unsent drafts
 for _,f in ipairs({U.navMenu or false,ns.UI2NotificationCenter.panel or false,ns.UI2Forms.escapeFrame or false})do if f then f:Hide()end end
 if U.search then U.search:ClearFocus()end
 if GameTooltip then GameTooltip:Hide()end
 -- Registered modals are reparented to UIParent. Follow only Warden ownership,
 -- never hide another addon's/native window or enumerate its descendants.
 if UIParent and UIParent.GetChildren then
  local children={UIParent:GetChildren()}
  for _,f in ipairs(children)do local owner=f.ChatWardenModalOwner
   for _=1,16 do if not owner then break end;if owner==U.window then f:Hide();break end;owner=owner.ChatWardenModalOwner end
  end
 end
end
function U.StopMenuWalking()
 local v=U.realm;local s=v and v:ActiveRoom();local a=s and s.native.actors.attendant
 if a and a.spec.controlled and a.route and not v.campfireWelcome and not(v.roomTravel and v.roomTravel.state)then
  a.route=nil;a.pendingInteraction=nil;a.engine:Animate(a,0,1);a.motionStatus='Menu open';ns.WardenCanonicalPlayer.Update(a.engine,a)
 end
end
function U.OpenMenu()
 local ready,why=U.StartupReady();if not ready then return false,why end
 if not editable()then return false,'Finish layout editing before opening the menu.'end
 if ns.Checked(ns.SafeCall(InCombatLockdown))then return false,'Open the menu after combat.'end
 if not ns.Membership.Allowed()then U.ShowVerification();return false,ns.Membership.Status()end
 if U.realm and U.realm.ExitJournal then U.realm:ExitJournal()end
 U.menuHidden=false
 return U.Open({page='overview'})
end
function U.CloseMenu()
 if not editable()then return false,'Finish layout editing before closing the menu.'end
 U.Ensure();U.Capture();closeOwnedPopups()
 if U.menuHidden then U.ApplyMenuState();return true end
 local v=U.realm
 if v and v.shelfFocus then ns.WardenShelfShowcase.Close(v,true)end
 if v and v.reader and(v.cameraMix>.001 or v.roomBookMotion)then
  local reduced=ns.DB.journalReducedMotion;ns.DB.journalReducedMotion=true
  v.roomBookMotion=nil;if v.roomBookDriver then v.roomBookDriver:Hide()end
  v.reader:CancelPageTurn();v.reader:CloseBook('front');ns.DB.journalReducedMotion=reduced
 end
 U.menuHidden=true;U.closingMenu=true;U.Refresh(true);U.closingMenu=nil;U.menuHidden=true;U.ApplyMenuState();return true
end
-- X exits the whole play window; Close Menu keeps the existing world visible.
function U.CloseWindow()
 if not U.window then return true end
 U.Capture();closeOwnedPopups();U.window:Hide();return true
end
function U.Hearth()
 if not editable()then return false,'Finish layout editing before hearthing.'end
 if ns.Checked(ns.SafeCall(InCombatLockdown))then return false,'Hearth after combat.'end
 if not ns.Membership.Allowed()then return false,ns.Membership.Status()end
 U.Ensure();local v=U.realm;local room=v and v:ActiveRoom();local t=v and v.roomTravel
 if not room or not t then return false,'Wait for the world to finish loading.'end
 if v.campfireWelcome then return false,'Finish or skip the campfire welcome first.'end
 if t.state then
  if t.state.navigation and t.state.link.to=='study'then return true,'Already hearthing to Olympian Oasis.'end
  return false,'Finish the current scene journey before hearthing.'
 end
 if room.key=='study'then return U.CloseMenu()end
 local handled,ok,why=ns.WardenRoomTravel.Navigate(v,{page='journey'})
 if not handled then return false,'No hearth destination is available from this room.'end
 if not ok then return false,why end
 -- The commit opens the destination route internally; it must not reopen UI.
 t.state.closeMenuOnArrival=true
 local closed,reason=U.CloseMenu()
 if not closed then t:Cancel(reason);return false,reason end
 return true,why
end
function U.ToggleMenu()
 if not U.window or not U.window:IsShown()or U.menuHidden then return U.OpenMenu()end
 return U.CloseMenu()
end
-- Compatibility for retained callers, with the new landing-page contract.
function U.SetMenuHidden(value)if value then return U.CloseMenu()end;return U.OpenMenu()end
local apply=U.ApplyMenuState
function U.ApplyMenuState(...)
 apply(...)
 -- One persistent footer surface, ready for future world controls. Keep its
 -- matching top rule above scene viewports without intercepting world input.
 if U.footerBand then
  U.footerBand:SetShown(U.menuHidden or not U.immersive)
  U.footer:SetShown(not U.menuHidden and not U.immersive)
 end
 if U.hideMenu then U.hideMenu:Hide()end
 U.LayoutMenuTools()
 if U.restoreMenu then U.restoreMenu:SetLabel(U.menuHidden and'Open Menu'or'Close Menu');U.restoreMenu:Show()end
 if U.menuHidden and ns.ChronicleReplay and ns.ChronicleReplay.view then ns.ChronicleReplay.view:Hide()end
 if U.menuEscape then if U.menuHidden then U.menuEscape.silent=true;U.menuEscape:Hide();U.menuEscape.silent=nil else U.menuEscape:Show()end end
end
function U.LayoutMenuTools()
 if not U.window or not U.restoreMenu or U.layingOutMenuTools then return end
 U.layingOutMenuTools=true
 local ULE=ns.UI2LayoutEditor;local visible=not U.menuHidden and not U.locked
 -- The cinematic's widgets are built inside the realm constructor, before
 -- the footer toggle exists. Dock Skip only after that anchor is available.
 local skip=U.realm and U.realm.welcomeSkip
 if skip and skip.footerAnchor~=U.restoreMenu then
  skip:ClearAllPoints();skip:SetPoint('RIGHT',U.restoreMenu,'LEFT',-10,0);skip.footerAnchor=U.restoreMenu
 end
 local E=ns.UI2LayoutEngine;local proof=U.route and E.Entitlement(U.route,E.Template(U.route))
 local previous=U.restoreMenu
 for _,button in ipairs({ULE and ULE.entry or false,U.forwardButton or false,U.backButton or false})do
  if button then
   if not button.firesideMenuDocked then
    button:SetParent(U.window);button:ClearAllPoints();button:SetPoint('RIGHT',previous,'LEFT',-7,0);button.firesideMenuDocked=true
   end
   button:SetShown(visible and(button~=ULE.entry or proof~=nil and not U.immersive))
   previous=button
  end
 end
 -- Reserve a bottom row only when a real auxiliary control is visible.
 -- Player profiles no longer have a bottom section toolbar.
 U.context:Hide();U.contextFrame:ClearAllPoints()
 U.contextFrame:SetPoint('BOTTOMLEFT',U.window,'BOTTOMLEFT',14,33)
 U.contextFrame:SetPoint('BOTTOMRIGHT',U.window,'BOTTOMRIGHT',-14,33)
 if U.route and(U.route.page=='intel'or U.route.page=='relay')then U.browseButton:Hide()end
 local auxiliary=visible and(U.browseButton:IsShown()or ULE and ULE.compactSections and ULE.compactSections:IsShown())
 U.contextFrame:SetShown(auxiliary==true)
 if U.stage and not U.immersive then
  U.stage:ClearAllPoints();U.stage:SetPoint('TOPLEFT',U.window,'TOPLEFT',14,-141)
  U.stage:SetPoint('BOTTOMRIGHT',U.window,'BOTTOMRIGHT',-14,auxiliary and 69 or 33)
 end
 -- These controls form one band above passive world layers after focus changes.
 local level=U.restoreMenu:GetFrameLevel()
 for _,button in ipairs({U.backButton,U.forwardButton,ULE and ULE.entry or false})do if button then ns.WardenSceneGraph.StackTree(button,level)end end
 if ns.WardenWindow and ns.WardenWindow.StackGrip then ns.WardenWindow.StackGrip()end
 U.layingOutMenuTools=nil
end
local ensure=U.Ensure
function U.Ensure(...)
 local f=ensure(...)
 if not U.menuEscape then
  U.hideMenu:SetLabel('Close Menu');U.restoreMenu:SetLabel('Open Menu')
  U.hideMenu:Hide();U.restoreMenu:SetScript('OnClick',U.ToggleMenu)
  U.closeButton:SetScript('OnClick',U.CloseWindow)
  ns.Theme.Tooltip(U.closeButton,'Close Fireside','Close the entire Fireside window. Close Menu keeps your world visible.')
  ns.Theme.Tooltip(U.navigation.journey,'Hearth to Olympian Oasis','Cast your scenic Hearthstone, then travel home with the menu closed.')
  -- Escape closes the menu without briefly hiding/unloading the world window.
  -- In the world, leave Escape to WoW; modal Escape retains its normal priority.
  if UISpecialFrames then for i=#UISpecialFrames,1,-1 do if UISpecialFrames[i]=='OlympusUI2' then table.remove(UISpecialFrames,i)end end end
  local e=CreateFrame('Frame','OlympusWardenMenuEscape',UIParent);e:Hide();U.menuEscape=e
  local border=CreateFrame('Frame',nil,f);border:SetAllPoints();border:EnableMouse(false);border:SetFrameLevel(f:GetFrameLevel()+170);U.playWindowBorder=border
  U.footerBand:SetFrameLevel(U.restoreMenu:GetFrameLevel()-1)
  for _,edge in ipairs({'TOP','BOTTOM','LEFT','RIGHT'})do
   local line=border:CreateTexture(nil,'OVERLAY');line:SetColorTexture(.64,.44,.17,.95)
   if edge=='TOP'or edge=='BOTTOM'then line:SetHeight(2);line:SetPoint(edge..'LEFT',border,edge..'LEFT');line:SetPoint(edge..'RIGHT',border,edge..'RIGHT')
   else line:SetWidth(2);line:SetPoint('TOP'..edge,border,'TOP'..edge);line:SetPoint('BOTTOM'..edge,border,'BOTTOM'..edge)end
  end
  function U.StackHeaderFlame()
   local host=U.realm and U.realm.headerFlameHost
   if host and host:GetFrameLevel()<=border:GetFrameLevel()then ns.WardenSceneGraph.StackTree(host,border:GetFrameLevel()+1)end
  end
  U.StackHeaderFlame()
  local before=f.ChatWardenBeforeFocus
  f.ChatWardenBeforeFocus=function(self)if before then before(self)end;U.StackHeaderFlame()end
  e:SetScript('OnHide',function(self)if not self.silent and U.window:IsVisible()and not U.menuHidden then U.CloseMenu()end end)
  if UISpecialFrames then table.insert(UISpecialFrames,1,'OlympusWardenMenuEscape')end
  f:HookScript('OnHide',function()e.silent=true;e:Hide();e.silent=nil end)
  local v=U.realm;local click,move,input=v.ClickScene,v.MovePlayer,v.RefreshFieldInput
  v.ClickScene=function(self,...)if not U.menuHidden then return false,'Close the menu to explore'end;return click(self,...)end
  v.MovePlayer=function(self,...)if not U.menuHidden then return false,'Close the menu to explore'end;return move(self,...)end
  v.RefreshFieldInput=function(self,...)
   local out=input(self,...)
   if not U.menuHidden then
    for _,s in ipairs(self:Scenes())do s.groundClick:EnableMouse(false)end
    if self.roomBookHit then self.roomBookHit:EnableMouse(false)end
   end
   return out
  end
 end
 return f
end
local open=U.Open
function U.Open(...)
 local ready,why=U.StartupReady();if not ready then return false,why end
 local hidden=U.menuHidden;local travel=U.realm and U.realm.roomTravel
 local preserve=travel and travel.committing==true
 preserve=preserve or U.closingMenu==true or U.openingWorldJournal==true
 U.menuHidden=preserve and hidden or false
 local ok,why=open(...);if not ok then U.menuHidden=hidden;U.ApplyMenuState()end
 if ok and preserve and U.menuHidden~=hidden then U.menuHidden=hidden;U.Refresh(true);U.ApplyMenuState()end
 if ok and not U.menuHidden then U.StopMenuWalking()end
 return ok,why
end
local select=U.SelectNavigationTab
function U.SelectNavigationTab(id)
 if id=='journey'and not(ns.UI2LayoutEditor and ns.UI2LayoutEditor.tx)then
  local ok,why=U.Hearth();if not ok then ns.UI2Forms.Feedback(ok,why)end;return ok,why
 end
 return select(id)
end
ns.WardenLaunchers.ToggleMain=U.ToggleMenu
local refresh=U.Refresh
function U.Refresh(...)local result=refresh(...);U.LayoutMenuTools();return result end
local workspaceOpen=ns.Workspace.Open
ns.Workspace.Open=function(page,...)if page==nil or page=='overview'then return U.OpenMenu()end;return workspaceOpen(page,...)end
local slash=SlashCmdList and SlashCmdList.OLYMPUSCHATWARDEN
if slash then SlashCmdList.OLYMPUSCHATWARDEN=function(message)if not message or not message:find('%S')then return U.OpenMenu()end;return slash(message)end end
