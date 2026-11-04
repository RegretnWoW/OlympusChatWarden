-- UI2: newly owned shell, routing and view construction. The four supplied
-- mockup density and the user's later top navigation direction are preserved.
local _,ns=...
local U={VERSION=1,back={},forward={},expanded={},builders={},limit=32};ns.UI2=U
local C,M,L=ns.UI2Components,ns.UI2Models,ns.UI2Layouts
local destinations={{'overview','Olympus Hall','INV_Misc_Tournaments_banner_Human'},{'intel','Aether','INV_Misc_GroupLooking'},{'wiki','Athenaeum','INV_Misc_Book_09'},{'journey','Olympian Oasis','INV_Misc_Book_11'},{'chronicle','Atlas','INV_Misc_PocketWatch_01'},{'messages','Logos','INV_Letter_15'},{'shield','Aegis','INV_Shield_06'},{'mentions','Vigil','INV_Misc_Bell_01'},{'settings','Settings','Trade_Engineering'}}
local byDestination={};for _,d in ipairs(destinations) do byDestination[d[1]]=d end
U.destinations=destinations
function U.NavigationOrder() return ns.UI2LayoutEngine.NavigationOrder() end
function U.SelectNavigationTab(id)
 if U.route and U.route.page~=id then ns.WardenAudio.Play('tab')end
 local editor=ns.UI2LayoutEditor
 if editor and editor.tx then editor.focus='tabs';editor.tabSelected=id;U.LayoutNavigation(U.window:GetWidth(),U.window:GetWidth()<1450);editor.UpdateToolbar();return true end
 local route={page=id,subsection=id=='intel'and'agora'or nil}
 local handled,ok,why=ns.WardenRoomTravel.Navigate(U.realm,route);if handled then return ok,why end
 return U.Open(route)
end
function U.MoveNavigationTab(id,target)
 local editor=ns.UI2LayoutEditor
 if not editor or not editor.tx or not editor.tabs or ns.Checked(ns.SafeCall(InCombatLockdown)) or not ns.Membership.Allowed() or U.locked then return false end
 local order=U.NavigationOrder();local from
 for i,key in ipairs(order) do if key==id then from=i;break end end;if not from then return false end
 table.remove(order,from);table.insert(order,math.max(1,math.min(#order+1,target)),id)
 ns.UI2LayoutEngine.SaveNavigation(order);editor.tabSelected=id
 U.LayoutNavigation(U.window:GetWidth(),U.window:GetWidth()<1450);editor.UpdateToolbar();return true
end
function U.NavigationMenu()
 if not U.navMenu then
  local menu=C.Card(U.navigationFrame,'All destinations',false);U.navMenu=menu;menu:SetSize(250,398);menu:SetPoint('TOPRIGHT',0,-48);menu:SetFrameStrata('TOOLTIP');menu:SetFrameLevel(U.window:GetFrameLevel()+130);menu.buttons={};menu:Hide()
  for i=1,#destinations do local button=C.Button(menu,'',function() local id=menu.buttons[i].destination;menu:Hide();U.SelectNavigationTab(id) end,226);button:SetPoint('TOPLEFT',12,-39-(i-1)*35);menu.buttons[i]=button end
 end
 if U.navMenu:IsShown() then U.navMenu:Hide();return end
 for i,id in ipairs(U.NavigationOrder()) do local button=U.navMenu.buttons[i];button.destination=id;button:SetLabel(byDestination[id][2]);button:SetActive(U.route and U.route.page==id) end
 U.navMenu:Show()
end
function U.OpenAetherProfile(guid,owner)
 return U.OpenPlayer(guid or ns.PlayerCard.Own(),owner or ns.Chronicle.Owner())
end
function U.ApplyMenuState()
 if not U.window then return end
 if U.menuHidden then
  for _,name in ipairs({'header','navigationFrame','contextFrame','footer','footerBand','canvas','immersiveButton'})do if U[name]then U[name]:Hide()end end
  if U.journalHost then U.journalHost.ownerMenu:Hide();U.journalHost.syntheticLabel:Hide()end
 end
 -- The persistent menu toggle owns its visibility. Briefly hiding it during a
 -- background refresh cancels a native mouse press before OnClick can fire.
 if U.realm and U.realm.RefreshFieldInput then U.realm:RefreshFieldInput()end
end
function U.SetMenuHidden(value)
 local editor=ns.UI2LayoutEditor
 if U.locked or editor and editor.tx then return false,'Finish layout editing before hiding the menu.'end
 U.menuHidden=value==true;U.Refresh(true);return true
end
local aliases={home='overview',chat='messages',signal='mentions',capture='messages',rules='messages',packs='messages',reports='relay',recording='settings',performance='settings',modules='settings',updates='settings'}
local function copy(t) local out={};for k,v in pairs(t or {}) do out[k]=v end;return out end
local function busy() return ns.Checked(ns.SafeCall(InCombatLockdown)) end
local function tick(_,dt)
 U.elapsed=(U.elapsed or 0)+(dt or .016);if U.elapsed<(U.pending and .2 or 1) then return end;U.elapsed=0
 local now=ns.SafeNumber(ns.SafeCall(GetServerTime)) or 0
 if U.pending or U.nextRefreshAt and now>=U.nextRefreshAt then U.Refresh() end
end
function U.ScheduleRefresh(model,pending)
 local route=U.route or {};U.pending=pending;U.elapsed=0
 local presenceView=model and model.kind=='player' and not model.asOf or route.page=='intel' and route.subsection=='warden-online'
 local expiry=model and model.kind=='player' and model.presence and model.presence.expiresAt
 local now=ns.SafeNumber(ns.SafeCall(GetServerTime)) or 0
 U.nextRefreshAt=presenceView and now+30 or nil
 if expiry and expiry>now then U.nextRefreshAt=math.min(U.nextRefreshAt or expiry,expiry) end
 U.window:SetScript('OnUpdate',(pending or U.nextRefreshAt) and tick or nil)
end
-- Layout transactions own the pointer. Also disable movability so a client
-- drag bubbling to an ancestor cannot turn a card gesture into window motion.
function U.SetLayoutEditing(active)
 local f=U.window;if not f then return end
 if active and not U.layoutMotionLocked then
  U.layoutWasMovable=not f.IsMovable or f:IsMovable();U.layoutMotionLocked=true
  f:StopMovingOrSizing();f:SetMovable(false)
 elseif not active and U.layoutMotionLocked then
  f:StopMovingOrSizing();f:SetMovable(U.layoutWasMovable~=false)
  U.layoutMotionLocked=nil;U.layoutWasMovable=nil
 end
end
-- Shell and resize integration use the same destination list. A stale nine-tab
-- layout placed Home on top of Living Wiki after native window resizing.
function U.CenterNavigationContents(button)
 if not button.torchIcon then return end
 local aspect=button.torchIcon.WardenArtAspect or 1;local size=button:GetHeight()-4
 local iw=aspect>=1 and size or size*aspect;local ih=aspect>=1 and size/aspect or size
 -- Center between the left bevel and the first visible letter, not the label
 -- region's left anchor. The centered label itself never moves.
 local textLeft=56+math.max(0,(button:GetWidth()-66-button.label:GetStringWidth())/2)
 button.torchIcon:SetSize(iw,ih);button.torchIcon:ClearAllPoints();button.torchIcon:SetPoint('LEFT',(textLeft+2-iw)/2,0)
 button.label:ClearAllPoints();button.label:SetPoint('TOPLEFT',56,-3);button.label:SetPoint('BOTTOMRIGHT',-10,3);button.label:SetJustifyH('CENTER');button.label:SetJustifyV('MIDDLE');button.label:SetWordWrap(false)
end
function U.LayoutHeader(width)
 if not U.search then return end
 U.myCard:ClearAllPoints();U.myCard:SetPoint('TOPLEFT',330,-22);U.myCard:SetWidth(145)
 U.aetherIndicator:ClearAllPoints();U.aetherIndicator:SetPoint('TOPLEFT',487,-22);U.aetherIndicator:SetWidth(200)
 U.search:ClearAllPoints();U.search:SetPoint('TOPRIGHT',-170,-22);U.search:SetWidth(math.max(100,width-170-705));U.search:SetHeight(36);U.search:SetTextInsets(26,26,4,4)
 U.search.hint:ClearAllPoints();U.search.hint:SetPoint('LEFT',26,0);U.search.hint:SetPoint('RIGHT',-26,0);if U.search.background then U.search.background:Hide()end
 U.myCard:SetHeight(36);U.aetherIndicator:SetHeight(36)
 for _,b in ipairs({U.fullscreenButton,ns.UI2NotificationCenter and ns.UI2NotificationCenter.button,U.closeButton})do b:SetHeight(36)end
end
function U.LayoutNavigation(width,compact)
 if not U.navigation then return end
 local order=U.NavigationOrder();local available=width-28;local total=0
 local widths={}
 for _,id in ipairs(order)do
  local button=U.navigation[id];button:SetLabel(byDestination[id][2]);button.label:SetFont('Fonts\\FRIZQT__.TTF',14,'')
  if not button.fullLabelMeasure then button.fullLabelMeasure=C.Text(button.face or button,'',14,C.colors.text);button.fullLabelMeasure:SetSize(2048,40);button.fullLabelMeasure:SetWordWrap(false);button.fullLabelMeasure:Hide()end
  button.fullLabelMeasure:SetText(byDestination[id][2]);local text=button.fullLabelMeasure:GetStringWidth();if not text or text<=0 then text=#byDestination[id][2]*8 end
  widths[id]=math.max(110,math.ceil(text)+76);total=total+widths[id]+5
 end
 local overflow=total>available;local start=U.navStart or 1
 if not overflow then start=1 else
  available=available-92
  local active=U.route and (U.route.page=='relay' and 'intel' or U.route.page);local editor=ns.UI2LayoutEditor
  if editor and editor.tx and editor.tabs then active=editor.tabSelected end
  local index=1;for i,id in ipairs(order) do if id==active then index=i end end
  if index<start then start=index end
  local used=0;for i=start,index do used=used+widths[order[i]]+5 end
  while used>available and start<index do used=used-widths[order[start]]-5;start=start+1 end
 end
 U.navStart=start;U.navVisible={};local x=0
 for _,button in pairs(U.navigation) do button:Hide() end
 for i=start,#order do local id=order[i];local w=widths[id];if overflow and x+w>available then break end
  if not overflow then w=w+(available-total)/#order end
  local button=U.navigation[id];button:ClearAllPoints();button:SetPoint('TOPLEFT',x,-2);button:SetWidth(w);button:SetLabel(byDestination[id][2]);button.label:SetFont('Fonts\\FRIZQT__.TTF',14,'');button:Show();U.CenterNavigationContents(button)
  local editor=ns.UI2LayoutEditor;button:SetActive(editor and editor.tx and editor.tabs and editor.tabSelected==id or U.route and (U.route.page=='relay' and 'intel' or U.route.page)==id)
  U.navVisible[#U.navVisible+1]={id=id,index=i,x=x,w=w};x=x+w+5
 end
 if U.navOverflow then U.navOverflow:SetShown(overflow);U.navOverflow:ClearAllPoints();U.navOverflow:SetPoint('TOPRIGHT',0,-2) end
end
function U.EndNavigationDrag()
 U.navDrag=nil;if U.navGhost then U.navGhost:Hide() end;if U.navMarker then U.navMarker:Hide() end
 for _,button in pairs(U.navigation or {}) do button:SetScript('OnUpdate',nil) end
end
function U.BeginNavigationDrag(button)
 local d=ns.UI2LayoutEditor;if not d or not d.tx or not d.tabs or ns.Checked(ns.SafeCall(InCombatLockdown)) then return end
 U.SetLayoutEditing(true);d.focus='tabs';d.tabSelected=button.destination;U.navDrag={id=button.destination};d.UpdateToolbar()
 if not U.navGhost then
  U.navGhost=CreateFrame('Frame',nil,U.window);U.navGhost:SetFrameStrata('TOOLTIP');U.navGhost:EnableMouse(false);U.navGhost.art=ns.WardenArt.Band(U.navGhost,'ButtonSelected');U.navGhost.icon=U.navGhost:CreateTexture(nil,'ARTWORK');U.navGhost.icon:SetSize(38,38);U.navGhost.icon:SetPoint('LEFT',12,0);U.navGhost.label=C.Text(U.navGhost,'',14,C.colors.gold);U.navGhost.label:SetPoint('LEFT',56,0);U.navGhost.label:SetJustifyH('CENTER');U.navGhost.label:SetPoint('RIGHT',-12,0)
 end
 U.navGhost:SetSize(button:GetWidth(),button:GetHeight());ns.WardenArt.Icon(U.navGhost.icon,button.destination);U.navGhost.label:SetText(button:GetText());U.navGhost:SetAlpha(.9);U.navGhost:Show()
 if not U.navMarker then U.navMarker=CreateFrame('Frame',nil,U.navigationFrame);C.Fill(U.navMarker,C.colors.gold);U.navMarker:SetSize(3,42);U.navMarker:SetFrameLevel(button:GetFrameLevel()+10) end
 button:SetScript('OnUpdate',function()
  local cx,cy=GetCursorPosition();local scale=U.navigationFrame:GetEffectiveScale();local x=cx/scale-U.navigationFrame:GetLeft();local y=cy/scale
  U.navGhost:ClearAllPoints();U.navGhost:SetPoint('TOPLEFT',U.navigationFrame,'BOTTOMLEFT',x+12,y-U.navigationFrame:GetBottom()-14)
  local valid=y>=U.navigationFrame:GetBottom()-12 and y<=U.navigationFrame:GetTop()+12;U.navDrag.target=nil
  if not valid then U.navMarker:Hide();return end
  for _,v in ipairs(U.navVisible or {}) do if x>=v.x-8 and x<=v.x+v.w+8 then
   local after=x>v.x+v.w/2;local from=1;for i,id in ipairs(U.NavigationOrder()) do if id==button.destination then from=i end end
   local target=v.index+(after and 1 or 0);if target>from then target=target-1 end
   U.navDrag.target=target;U.navMarker:ClearAllPoints();U.navMarker:SetPoint('TOPLEFT',v.x+(after and v.w or 0),-2);U.navMarker:Show();break
  end end
 end)
end
function U.FinishNavigationDrag()
 local drag=U.navDrag;U.EndNavigationDrag();if drag and drag.target then U.MoveNavigationTab(drag.id,drag.target) end
end
function U.Fit()
 if not U.window or busy() then return end
 local width,height=1600,940;U.window:SetSize(width,height)
 U.LayoutNavigation(width,false)
 ns.Theme.FitWindow(U.window,width,height)
 if U.LayoutJournal then U.LayoutJournal() end
 if U.route and U.window:IsShown() then U.Refresh(true) end
end
function U.Ensure()
 if U.window then return U.window end
 local f=CreateFrame('Frame','OlympusUI2',UIParent);U.window=f;ns.Workspace.window=f;f:SetSize(1600,940);f:SetPoint('CENTER');f:SetFrameStrata('DIALOG');f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(true);f.ChatWardenOwned=true
 U.shellFill=C.Fill(f,C.colors.ink)
 U.shellArt=ns.WardenArt.Texture(f,'TempleBackdrop');U.shellArt:SetPoint('TOPLEFT',0,-84);U.shellArt:SetPoint('BOTTOMRIGHT',0,30);U.torchFrame=ns.WardenArt.Frame(f,false,false)
 local header=CreateFrame('Frame',nil,f);U.header=header;header:SetPoint('TOPLEFT');header:SetPoint('TOPRIGHT');header:SetHeight(138);U.headerFill=C.Fill(header,{.025,.065,.115,1});header:EnableMouse(true);header:RegisterForDrag('LeftButton');header:SetScript('OnDragStart',function() if not busy() and not U.layoutMotionLocked and not (ns.UI2LayoutEditor and ns.UI2LayoutEditor.tx) then f:StartMoving() end end);header:SetScript('OnDragStop',function() f:StopMovingOrSizing() end)
 local crest=header:CreateTexture(nil,'ARTWORK');crest:SetTexture(ns.WardenBrand.Path('Warden'));crest:SetPoint('TOPLEFT',14,-8);crest:SetSize(64,64)
 local title=C.Text(header,'OLYMPUS',27,C.colors.gold);title:SetPoint('TOPLEFT',88,-14);title:SetSize(320,31)
 local tag=C.Text(header,'YOUR STORY THROUGH AZEROTH',11,C.colors.gold);tag:SetPoint('TOPLEFT',89,-47);tag:SetSize(330,20)
 local headerArt=ns.WardenArt.Texture(header,'HeaderBackdrop');headerArt:SetAllPoints();headerArt:SetTexCoord(0,1,0,1)
 crest:Hide();title:Hide();tag:Hide();U.torchLogo=ns.WardenArt.Texture(header,'BrandHeader','ARTWORK');U.torchLogo:SetPoint('TOPLEFT',12,-3);U.torchLogo:SetSize(300,75)
  U.search=C.Edit(header,380,'Search the world and your story…');U.search:SetPoint('TOPRIGHT',-110,-22);U.search:SetHeight(34)
 U.search:SetScript('OnEnterPressed',function(self)
   local query=self:GetText();self:ClearFocus();U.Open({page='search',owner=ns.Chronicle.Owner(),query=query,wikiKind='ALL'})
 end)
 U.myCard=C.Button(header,'Aether Profile',function() U.OpenAetherProfile() end,145);U.myCard:SetPoint('TOPRIGHT',-502,-24)
 U.aetherIndicator=C.Button(header,'Aether Beta',function()U.Open({page='relay',subsection='aether'})end,200);U.aetherIndicator:SetPoint('TOPLEFT',340,-24)
 local indicatorPending=false;local indicatorTimer
 local function updateIndicator()
  local state,label,help=ns.AetherNet.ArtIndicator();U.aetherIndicator:SetLabel(label)
  local colors={CONNECTED=C.colors.green,OFF=C.colors.muted,STALE=C.colors.gold,LIMITED=C.colors.gold,READY=C.colors.blue,UNAVAILABLE=C.colors.muted}
  U.aetherIndicator.label:SetTextColor(unpack(colors[state]or C.colors.muted));ns.Theme.Tooltip(U.aetherIndicator,label,help)
 end
 local function scheduleIndicator()
  updateIndicator();if indicatorPending or not header:IsShown()or not C_Timer then return end
  indicatorPending=true;local function refresh()indicatorPending=false;indicatorTimer=nil;if header:IsShown()then scheduleIndicator()end end
  if C_Timer.NewTimer then indicatorTimer=C_Timer.NewTimer(30,refresh)elseif C_Timer.After then C_Timer.After(30,refresh)else indicatorPending=false end
 end
 U.RefreshAetherIndicator=updateIndicator
 header:HookScript('OnShow',scheduleIndicator);header:HookScript('OnHide',function()if indicatorTimer and indicatorTimer.Cancel then indicatorTimer:Cancel();indicatorTimer=nil;indicatorPending=false end end)
 U.closeButton=C.Button(header,'',function() f:Hide() end,40);U.closeButton:SetPoint('TOPRIGHT',-14,-22);C.WindowIcon(U.closeButton,'close');ns.Theme.Tooltip(U.closeButton,'Close Fireside','Close the complete Fireside window.')
 ns.UI2NotificationCenter.Attach(header,f)
 local rule=header:CreateTexture(nil,'BORDER');rule:SetPoint('BOTTOMLEFT');rule:SetPoint('BOTTOMRIGHT');rule:SetHeight(2);rule:SetColorTexture(.64,.44,.17,.95);U.headerSeparator=rule
 U.branding={U.torchLogo,headerArt,rule}
 local navigation=CreateFrame('Frame',nil,f);U.navigationFrame=navigation;navigation:SetPoint('TOPLEFT',14,-87);navigation:SetPoint('TOPRIGHT',-14,-87);navigation:SetHeight(46);C.Fill(navigation,{.026,.063,.108,1});U.navigation={}
 for i,d in ipairs(destinations) do local key=d[1];local button=C.NavigationTab(navigation,d[2],function() U.SelectNavigationTab(key) end,170);button:SetHeight(42);button:SetPoint('TOPLEFT',(i-1)*175,-2)
  local icon=(button.face or button):CreateTexture(nil,'ARTWORK');ns.WardenArt.Icon(icon,key);button.torchIcon=icon;icon:SetSize(28,28);icon:SetPoint('LEFT',8,0);button.label:ClearAllPoints();button.label:SetPoint('LEFT',40,0);button.label:SetPoint('RIGHT',-10,0);button.label:SetFont('Fonts\\FRIZQT__.TTF',15,'');U.navigation[key]=button;button.destination=key;button:RegisterForDrag('LeftButton')
  if button.SetPropagateMouseClicks then button:SetPropagateMouseClicks(false) end
  button:SetScript('OnDragStart',U.BeginNavigationDrag);button:SetScript('OnDragStop',U.FinishNavigationDrag)
  button:HookScript('OnEnter',function(self) if GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_BOTTOM');GameTooltip:SetText(d[2]);local editor=ns.UI2LayoutEditor;if editor and editor.tx and editor.tabs then GameTooltip:AddLine('Drag to reorder · Use Move Left / Move Right for overflow tabs',1,.85,.5,true) end;GameTooltip:Show() end end)
  button:HookScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
 end
 U.navOverflow=C.Button(navigation,'More...',U.NavigationMenu,86);U.navOverflow:SetHeight(42);U.navOverflow:Hide()
 local context=CreateFrame('Frame',nil,f);U.contextFrame=context;context:SetPoint('TOPLEFT',14,-141);context:SetPoint('TOPRIGHT',-14,-141);context:SetHeight(32)
 U.backButton=C.Button(context,'‹',U.Back,30);U.backButton:SetPoint('LEFT')
 U.forwardButton=C.Button(context,'›',U.Forward,30);U.forwardButton:SetPoint('LEFT',35,0)
 for _,pair in ipairs({{U.backButton,'Back · Previous page'},{U.forwardButton,'Forward · Next page'}}) do local text=pair[2];pair[1]:SetScript('OnEnter',function(self) if GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_TOP');GameTooltip:SetText(text);GameTooltip:Show() end end);pair[1]:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end) end
 U.context=C.Text(context,'',12,C.colors.muted);U.context:SetPoint('LEFT',78,0);U.context:SetPoint('RIGHT',-125,0)
 U.browseButton=C.Button(context,'Browse',function() if U.route.page=='intel' or U.route.page=='relay' then return U.AetherTools() end;U.Open({page='chronicle',owner=U.route.owner,query=U.route.query}) end,110);U.browseButton:SetPoint('RIGHT')
 U.immersiveButton=C.Button(context,'Immersive reading',function() U.immersive=not U.immersive;U.Refresh(true) end,165);U.immersiveButton:SetPoint('RIGHT');U.immersiveButton:Hide()
 U.sectionLinks={}
 -- Profile sections remain in the content canvas; no bottom jump toolbar.
 U.stage=CreateFrame('Frame',nil,f);U.stage:SetPoint('TOPLEFT',14,-181);U.stage:SetPoint('BOTTOMRIGHT',-14,immersive and 14 or 33)
 U.canvas=C.Canvas(U.stage)
 U.footerBand=CreateFrame('Frame',nil,f);U.footerBand:SetPoint('BOTTOMLEFT');U.footerBand:SetPoint('BOTTOMRIGHT');U.footerBand:SetHeight(31);U.footerBand:EnableMouse(false)
 local footerBlue=ns.WardenArt.Texture(U.footerBand,'HeaderBackdrop','BACKGROUND');footerBlue:SetAllPoints();footerBlue:SetTexCoord(0,1,.3,.7);U.footerBlue=footerBlue
 local footerRule=U.footerBand:CreateTexture(nil,'BORDER');footerRule:SetPoint('TOPLEFT');footerRule:SetPoint('TOPRIGHT');footerRule:SetHeight(2);footerRule:SetColorTexture(.64,.44,.17,.95);U.footerSeparator=footerRule
 U.footer=C.Text(U.footerBand,'',10,C.colors.muted);U.footer:SetPoint('BOTTOMLEFT',18,8);U.footer:SetPoint('BOTTOMRIGHT',-14,8);U.footer:SetHeight(18)
 ns.WardenRealm.Attach(U,f)
 ns.WardenSanctuary.Attach(f)
 f:Hide();f:SetScript('OnHide',function()
  if U.realm and U.realm.roomTravel then U.realm.roomTravel:Cancel('Window closed')end
  U.Capture();U.EndNavigationDrag();if U.navMenu then U.navMenu:Hide() end;f:StopMovingOrSizing()
 end)
 local resize=CreateFrame('Frame');for _,event in ipairs({'DISPLAY_SIZE_CHANGED','UI_SCALE_CHANGED','PLAYER_REGEN_ENABLED'}) do resize:RegisterEvent(event) end
 resize:SetScript('OnEvent',function() U.Fit() end)
 if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]='OlympusUI2' end
 ns.Theme.RegisterWindow(f,true);U.Fit();return f
end
function U.Capture()
 if not U.route or not U.canvas then return end
 if U.route.page=='journey' then
  U.route.immersive=U.immersive;ns.AthenaJournalWindow.SavePlace();local reader=U.journalHost and U.journalHost.reader
  if reader and reader.BookPlace then U.route.bookPlace=reader:BookPlace();U.route.bookStory=reader.selected;U.route.bookThread=reader.threadId end
  return
 end
 U.route.scroll=U.canvas.scroll:GetVerticalScroll()
 if U.route.page=='intel' and U.route.kind=='player' then local row=ns.DB.dossierViews and ns.DB.dossierViews[ns.Chronicle.Owner()];if row and row.id==tostring(U.route.owner)..'/'..tostring(U.route.key) then row.scroll=U.route.scroll end end
end
function U.Back()
 if #U.back==0 then return false end;U.Capture();U.forward[#U.forward+1]=copy(U.route);local route=table.remove(U.back);return U.Open(route,true)
end
function U.Forward()
 if #U.forward==0 then return false end;U.Capture();U.back[#U.back+1]=copy(U.route);local route=table.remove(U.forward);return U.Open(route,true)
end
function U.Open(route,replacing)
 if not ns.DB or busy() then return false,'Open Olympus after combat' end
 if GameTooltip then GameTooltip:Hide() end
 if not ns.Membership.Allowed() then U.pendingVerifiedRoute=type(route)=='table' and copy(route) or nil;U.ShowVerification();return false,ns.Membership.Status() end
 U.locked=false;U.EndNavigationDrag();if U.navMenu then U.navMenu:Hide() end;if U.verification then U.verification:Hide() end
 route=type(route)=='table' and copy(route) or {page=route or 'overview'};route.page=aliases[route.page] or route.page or 'overview';route.owner=route.owner or ns.Chronicle.Owner()
 if route.page=='intel' and route.kind=='player' then
  local owner=ns.Chronicle.Owner();local saved=ns.DB.dossierViews
  if type(saved)~='table' or getmetatable(saved) then saved={};ns.DB.dossierViews=saved end
  local context=saved[owner];local id=tostring(route.owner)..'/'..tostring(route.key)
  if not route.asOfSet and route.asOf==nil and type(context)=='table' and context.id==id then route.asOf=ns.ChronicleStore.Integer(context.asOf,1,9999999999);route.scroll=route.scroll or context.scroll end
  saved[owner]={id=id,asOf=route.asOf,scroll=route.scroll or 0}
  local keys={};for key in pairs(saved) do if key~=owner then keys[#keys+1]=key end end;table.sort(keys);while #keys>15 do saved[table.remove(keys,1)]=nil end
 end
 if not U.route or U.route.key~=route.key then U.voteFeedback=nil end
 U.Ensure();U.Capture()
 if U.route and not replacing then U.back[#U.back+1]=copy(U.route);while #U.back>U.limit do table.remove(U.back,1) end;U.forward={} end
 U.route=route;ns.Workspace.current=route.page
 -- An explicit player-profile navigation must reveal its content even when
 -- the scenic menu was hidden. Preserve window mode and the normal Back route.
 if route.page=='intel'and route.kind=='player'then U.menuHidden=false end
 if route.page~='journey'and U.realm and U.realm.reader then
  local p=U.realm.reader;local reduced=ns.DB.journalReducedMotion;ns.DB.journalReducedMotion=true
  U.realm.roomBookMotion=nil;if U.realm.roomBookDriver then U.realm.roomBookDriver:Hide()end;p:CloseBook('front');ns.DB.journalReducedMotion=reduced
 end
 -- Only explicit navigation replaces the header query. Background refreshes
 -- must leave unsubmitted text and the native edit cursor alone.
 if U.search:GetText()~=(route.query or '') then U.search:SetText(route.query or '') end
 if route.page=='journey' and not route.sceneRoom and not route.storyId and U.journalHost and U.journalHost.owner==route.owner and U.journalHost.reader.rendered and ns.Athena.Enabled('chronicle') and ns.Membership.LocalHistoryAllowed() then route.bookOpened=true end
 U.restoreBookPlace=route.page=='journey' and route.bookPlace or nil
 U.immersive=false -- Fullscreen is now a universal window control.
 U.stage:Show();U.window:Show();U.Refresh(true)
 if route.page=='messages' then
  if route.activityID then ns.Activity.Mark(route.activityID) end
  if route.messageID then local entry=ns.Review.Get(route.messageID)
   if entry and not entry.read then ns.Review.Mark(entry.id,'viewed') end
   for _,item in ipairs(ns.Activity.entries) do if item.reviewID==route.messageID then ns.Activity.Mark(item.id) end end
  end
 end
 return true,U.window
end
function U.OpenPlayer(guid,owner,projection)
 return U.Open({page='intel',kind='player',key=guid,owner=owner or ns.Chronicle.Owner(),projection=projection})
end
function U.OpenGuild(key,owner) return U.Open({page='intel',kind='guild',key=key,owner=owner}) end
function U.Refresh(force)
 if not U.window or not U.window:IsShown() then return end
 if not ns.Membership.Allowed() then U.ShowVerification();return end
 if not U.route then return end
 local route=U.route;local model,state,blocks,pending
 local worldRoom=U.realm.pendingRoomKey or(ns.WardenSanctuary.previewSwitch and route.sceneRoom)or U.realm.currentRoomKey or'hall'
 local homeScene=worldRoom~='hall'and ns.WardenRoomCatalogue.Room(worldRoom).reader
 local replay=route.page=='chronicle'and route.subsection=='replay'and not route.kind
 if ns.ChronicleReplay and ns.ChronicleReplay.view and not replay then ns.ChronicleReplay.view:Hide()end
 if route.page~='messages' and ns.UI2Operations then ns.UI2Operations.revealedID=nil end
 if route.page=='intel' and route.kind=='player' then model,state=M.GetPlayerPage(route.key,route.owner,route.asOf)
 elseif route.page=='intel' and route.kind=='guild' then model,state=M.GetGuildPage(route.key,route.owner)
 elseif route.page=='chronicle' and route.kind=='activity' then model,state=M.GetActivityPage(route.key,route.owner)
 elseif route.kind=='group' then model,state=M.GetGroupPage(route.generation,route.resultID,route.groupAdapter,route.groupContext) end
 if (route.kind=='player' or route.kind=='activity' or route.kind=='group' or route.kind=='guild') and not model then
  local blocked=state=='blocked' or state=='disabled' or M.lastError~=nil
  local text=M.lastError and 'This dossier could not be prepared. Retry or open support diagnostics.' or state=='blocked' and 'This character’s history could not be opened. Original saved records are retained.' or state=='disabled' and 'This module is paused.' or state or 'Preparing dossier'
  local rows={{title=text,kind='caption',height=50,wrap=true},{title='Your original history is unchanged.',kind='caption'}}
  if M.lastError then rows[#rows+1]={title='Retry dossier',height=42,activate=function() M.Clear();U.Refresh(true) end} end
  blocks={{id='status',title='Opening your dossier',x=0,y=0,w=1,rows=rows}}
  pending=not blocked and text~='Guild source unavailable' and text~='Activity unavailable' and text~='Player identity unavailable' and text~='Listing expired or unavailable' and text~='Access or module unavailable'
 elseif model then
  if not force and U.model==model and U.presentedRoute==route then U.ScheduleRefresh(model,state=='refreshing');return end
  pending=state=='refreshing'
  U.model=model
  if model.kind=='player' then blocks=L.Player(model,route);if ns.WardenExtensions then blocks=ns.WardenExtensions.ProfileBlocks(model,route,blocks)end elseif model.kind=='activity' then blocks=L.Activity(model) elseif model.kind=='guild' then blocks=L.Guild(model) else local rows=ns.UI2Pages.Group(model);blocks={{id='group',title=model.title,x=0,y=0,w=1,rows=rows}} end
 elseif route.page=='intel'and route.subsection=='agora'then blocks=ns.AetherPosts.Blocks(route)
 elseif route.page=='search' then blocks,pending=ns.AthenaGlobalSearch.Blocks(route)
 elseif route.page=='wiki' then blocks,pending=ns.AthenaWikiUI.Blocks(route)
 elseif route.page=='overview' then blocks,pending=L.Home(route)
 elseif replay then blocks={}
 elseif route.page=='chronicle' or route.page=='intel' then blocks,pending=L.Browse(route)
 elseif route.page=='messages' then blocks=L.Chat(route)
 elseif route.page=='settings' then blocks=L.Settings(route)
 elseif route.page=='journey'and homeScene and(not U.menuHidden or U.realm.journalReading)then
  if not U.hostingJournal and (not route.bookOpened or not U.journalHost or U.journalHost.owner~=route.owner) then
   local ok,why=ns.AthenaJournalWindow.Open({owner=route.owner,storyId=route.storyId});route.bookOpened=ok
   if not ok then blocks={{id='status',title='Athena’s Journal',rows={{title=why or 'Enable permitted Chronicle history to open this book.',wrap=true,height=60}}}} end
  end
  if route.bookOpened or U.hostingJournal then U.LayoutJournal();U.journalHost:Show();blocks={} end
 elseif route.page=='journey'then blocks={}
 else blocks=L.Service(route) end
 local reading=(not U.menuHidden or U.realm.journalReading)and route.page=='journey'and homeScene and(route.bookOpened or U.hostingJournal)
 U.canvas:SetShown(not reading and not replay);if U.journalHost and not reading then U.journalHost:Hide() end
 U.canvas:Render(blocks or {},route.scroll or 0);U.lastBlocks=blocks or {}
 if replay then ns.ChronicleReplay.Show(U.stage,route.owner)end
 if route.jump and U.canvas.anchors[route.jump] then U.canvas:Jump(route.jump);route.scroll=U.canvas.scroll:GetVerticalScroll();route.jump=nil end
 local immersive=reading and U.immersive
 U.navigationFrame:SetShown(not immersive);U.contextFrame:SetShown(not immersive)
 U.header:SetShown(not immersive);U.footer:SetShown(not immersive);U.footerBand:SetShown(not immersive);U.shellFill:SetShown(not immersive)
 U.headerFill:SetShown(not immersive);U.shellArt:Hide();U.realm:Select(route,reading,immersive or U.menuHidden);U.torchFrame:SetShown(not immersive);for _,art in ipairs(U.branding) do art:SetShown(not immersive and not(art==U.torchLogo and U.realm.headerTorch)) end
 U.myCard:SetShown(not immersive);U.search:SetShown(not immersive);U.header:SetHeight(immersive and 64 or 138)
 U.contextFrame:ClearAllPoints();U.contextFrame:SetPoint('TOPLEFT',14,reading and U.immersive and -87 or -141);U.contextFrame:SetPoint('TOPRIGHT',-14,reading and U.immersive and -87 or -141)
 U.stage:ClearAllPoints();U.stage:SetPoint('TOPLEFT',14,immersive and -45 or -181);U.stage:SetPoint('BOTTOMRIGHT',-14,immersive and 14 or 33)
 if reading then U.LayoutJournal();local reader=U.journalHost.reader
  if U.restoreBookPlace and reader.selected==route.bookStory and reader.threadId==route.bookThread and reader.RestoreBookPlace then reader:RestoreBookPlace(U.restoreBookPlace) end
  U.restoreBookPlace=nil
 end
 if not U.journalActions then
  U.journalActions={}
  for i,choice in ipairs({{'Chapters',function(p) p:OpenContents('life') end},{'Daybook',function(p) p:OpenDaybook() end},{'Library',function(p) p:OpenLibraryFolios() end},{'Mark',function(p) p:SaveBookmark() end}}) do
   local callback=choice[2]
   local button=C.Button(U.contextFrame,choice[1],function()
    local p=U.journalHost and U.journalHost.reader
    if p and p.rendered and p.provider and p.provider:Allowed() then callback(p) end
   end,88)
   button:SetPoint('RIGHT',-172-(4-i)*94,0);U.journalActions[i]=button
  end
 end
 for _,button in ipairs(U.journalActions) do button:Hide();button:SetEnabled(reading==true) end
 U.immersiveButton:Hide();U.immersiveButton:SetLabel(U.immersive and 'Exit Reading' or 'Immersive reading')
 U.immersiveButton:SetParent(immersive and U.window or U.contextFrame);U.immersiveButton:ClearAllPoints()
 if immersive then U.immersiveButton:SetPoint('TOPLEFT',18,-24) else U.immersiveButton:SetPoint('RIGHT') end
 for key,button in pairs(U.navigation) do button:SetActive(key==(route.page=='relay' and 'intel' or route.page)) end
 if U.RefreshAetherIndicator then U.RefreshAetherIndicator()end
 U.context:SetText('');U.context:Hide()
 U.backButton:SetEnabled(#U.back>0);U.forwardButton:SetEnabled(#U.forward>0);U.browseButton:SetShown(route.kind=='activity' or route.kind=='player' or route.page=='intel' or route.page=='relay');U.browseButton:SetLabel((route.page=='intel' or route.page=='relay') and 'Aether tools' or 'Browse')
 for _,link in ipairs(U.sectionLinks) do link:SetShown(model and model.kind=='player' and route.projection~='public' and not route.directory or false) end
 U.context:SetPoint('RIGHT',model and model.kind=='player' and -735 or reading and -420 or -125,0)
 U.footer:SetText('Fireside 1.0 · Aether Beta 0.1 · Integrated 77 · Media cleanup 1')
 U.LayoutNavigation(U.window:GetWidth(),U.window:GetWidth()<1450)
 U.presentedRoute=route;U.ScheduleRefresh(model,pending);U.ApplyMenuState()
end
-- This surface contains no dossier, history, book, inbox or search projection.
-- The gate is product access control, not a cryptographic secret boundary.
function U.ShowVerification()
 if not ns.DB then return false end
 if busy() then
  if U.window then U.window:Hide() end
  if ns.UI2Forms.active then ns.UI2Forms.active:Hide() end
  return false,'Verification controls are available after combat.'
 end
 U.Ensure();U.Capture();U.locked=true;U.immersive=false
 for _,key in ipairs({'header','navigationFrame','contextFrame','stage','footer','footerBand','immersiveButton','noteEditor'}) do if U[key] then U[key]:Hide() end end
 if ns.UI2NotificationCenter.panel then ns.UI2NotificationCenter.panel:Hide() end
 if ns.UI2Forms.active and not ns.UI2Forms.active.spec.privacy then ns.UI2Forms.active:Hide() end
 U.model=nil;U.lastBlocks={};U.pending=false;U.window:SetScript('OnUpdate',nil);U.shellFill:Show()
 local f=U.verification
 if not f then
  f=C.Card(U.window,'Fireside — Verification Required',false);U.verification=f;f:SetPoint('CENTER');f:SetSize(810,380)
  f.message=C.Text(f,'Olympus membership must be verified before you can access Fireside.',19,C.colors.gold);f.message:SetPoint('TOPLEFT',28,-65);f.message:SetSize(750,55);f.message:SetWordWrap(true)
  f.explanation=C.Text(f,'Previously authorized background recording and Aether participation can continue independently.',16);f.explanation:SetPoint('TOPLEFT',28,-136);f.explanation:SetSize(750,60);f.explanation:SetWordWrap(true)
  f.status=C.Text(f,'',14,C.colors.muted);f.status:SetPoint('TOPLEFT',28,-216);f.status:SetSize(750,62);f.status:SetWordWrap(true)
  C.Button(f,'Retry verification',function() ns.Membership.Refresh();U.VerificationChanged() end,200):SetPoint('BOTTOMLEFT',28,28)
  C.Button(f,'Recording and privacy controls',U.ShowPrivacy,300):SetPoint('BOTTOMLEFT',242,28)
  C.Button(f,'Close',function() U.window:Hide() end,100):SetPoint('BOTTOMRIGHT',-28,28)
 end
 f.status:SetText('Verification status: '..ns.Membership.Status());f:Show();U.window:Show();return true
end
function U.ShowPrivacy()
 if not ns.DB or busy() then return false,'Privacy controls are available after combat.' end
 if not ns.Membership.Allowed() then U.ShowVerification() end
 return ns.UI2Forms.Form({privacy=true,title='Recording and privacy controls',help='These controls remain available without Olympus verification. They do not open recorded information or enable recording or networking.',
  fields={{key='action',label='Choose an action',value='stop',choices={{'stop','Stop background recording'},{'withdraw','Withdraw Aether participation'},{'clear','Erase this character’s local history and private notes'},{'clearAll','Erase all characters and unscoped local capture data'}}},
   {key='confirm',label='For deletion, type CLEAR or CLEAR ALL',limit=12}},submitLabel='Apply privacy choice',
  paragraphs={'Stopping recording pauses Chronicle and optional chat capture. Aether withdrawal stops participation; private drafts are never sent automatically.',
   'CLEAR erases this character’s owner-scoped history, conversations and private notes. CLEAR ALL also erases all characters, unscoped captures, drafts and local Relay records. Rules and protection settings remain. Unsupported stores cause refusal; peer copies cannot be recalled.'},
  submit=function(values)
   if values.action=='withdraw' then return ns.Privacy.Withdraw() end
   if values.action=='stop' then return ns.Privacy.Stop() end
   if values.action=='clear' then return ns.Privacy.Erase('owner',values.confirm) end
   if values.action=='clearAll' then return ns.Privacy.Erase('all',values.confirm) end
   return false,'Choose a privacy action.'
  end})
end
function U.VerificationChanged()
 if not U.window or not U.window:IsShown() then return end
 if not ns.Membership.Allowed() then return U.ShowVerification() end
 if U.locked then
  local route=U.pendingVerifiedRoute or U.route or {page='overview'};U.pendingVerifiedRoute=nil
  return U.Open(route,true)
 end
end
function U.CreateJournalHost()
 U.Ensure();if U.journalHost then return U.journalHost end
 local f=CreateFrame('Frame',nil,U.stage);U.journalHost=f;f.ui2Host=true;f.ChatWardenOwned=true;f:SetAllPoints(U.stage)
 f.ownerChoices={{false,'This character'}}
 f.ownerMenu=C.Button(f,'This character',function()
  local index=1;for n,choice in ipairs(f.ownerChoices) do if (choice[1] or ns.Chronicle.Owner())==f.owner then index=n;break end end
  local nextChoice=f.ownerChoices[index%#f.ownerChoices+1];ns.AthenaJournalWindow.Open({owner=nextChoice[1] or ns.Chronicle.Owner()})
 end,250);f.ownerMenu:SetPoint('TOPLEFT',0,-1)
 function f.ownerMenu:Refresh() self:SetLabel(f.owner==ns.Chronicle.Owner() and 'This character' or ns.WardenUI.OwnerName(f.owner)) end
 f.syntheticLabel=C.Text(f,'SYNTHETIC · Private Lab story',11,C.colors.gold);f.syntheticLabel:SetPoint('TOPLEFT',265,-9);f.syntheticLabel:SetSize(360,20);f.syntheticLabel:Hide()
 f.reader=ns.AthenaJournalUI.Build(f,f);f.reader:Show()
 f:HookScript('OnHide',function() ns.AthenaJournalWindow.SavePlace() end)
 f:Hide();return f
end
function U.LayoutJournal()
 local f=U.journalHost;if not f then return end
 local width,height=U.stage:GetWidth(),U.stage:GetHeight();f:SetSize(width,height)
 f.reader:ClearAllPoints();f.reader.immersive=U.immersive==true;f.ownerMenu:Hide();f.syntheticLabel:SetShown(not U.immersive and f.reader.provider and f.reader.provider.demo or false)
 local clear=U.menuHidden or U.immersive
 f.reader:SetPoint('TOPLEFT',0,clear and 0 or -35);f.reader:SetSize(width,height-(clear and 0 or 35));f.reader:Layout(width,height-(clear and 0 or 35))
 -- The old fixed manuscript status anchor crossed the lower paragraphs when
 -- hosted at a different size. Keep this UI status beside the owner selector;
 -- only the book's own folio numbers remain on the parchment.
 local progress=f.reader.pageProgress
 progress:ClearAllPoints();progress:SetPoint('TOPRIGHT',f,'TOPRIGHT',-10,-8);progress:SetSize(math.max(160,width*.45),22);progress:SetJustifyH('RIGHT');progress:SetTextColor(unpack(C.colors.muted));progress:SetShown(not clear)
end
function U.HostJourney(f)
 if not ns.Membership.Allowed() then U.ShowVerification();return false end
 U.LayoutJournal()
 if not U.route or U.route.page~='journey' then
  U.hostingJournal=true;U.Open({page='journey',owner=f.owner,storyId=f.reader.requestedStory,bookOpened=true});U.hostingJournal=nil
 end
 U.window:Show()
end
function U.EditNote(m)
 local f=U.noteEditor
 if not f then
  f=C.Card(U.window,'Private player note',true);U.noteEditor=f;f:SetSize(600,220);f:SetPoint('CENTER');f:SetFrameLevel(U.window:GetFrameLevel()+50)
  f.input=C.Edit(f,560,'Write a private note…');f.input:SetPoint('TOPLEFT',20,-55);f.input:SetMaxLetters(512)
  f.status=C.Text(f,'',12,C.colors.muted);f.status:SetPoint('TOPLEFT',20,-100);f.status:SetSize(560,38)
  local save=C.Button(f,'Save note',function()
   local context=f.model;if context and context.owner==ns.Chronicle.Owner() and ns.Chronicle.SetPersonal(context.key,f.input:GetText(),nil) then M.Clear();f:Hide();U.Refresh(true) else f.status:SetText('This retained player cannot be annotated in the current scope.') end
  end,130);save:SetPoint('BOTTOMLEFT',20,20)
  C.Button(f,'Cancel',function() f:Hide() end,100):SetPoint('BOTTOMRIGHT',-20,20)
 end
 f.model=m;f.input:SetText(m.note or '');f.status:SetText('Saved only to your existing private player note. Never shared or treated as evidence.');f:Show()
end
-- Compatibility routing only. None of these invokes an old screen constructor.
local W=ns.Workspace
W.Open=function(page) return U.Open({page=page}) end
W.Ensure=function() local f=U.Ensure();W.window=f;return f end
W.Fit=U.Fit
W.Refresh=function() U.Refresh() end
W.HostJourney=U.HostJourney
W.Settings=function(category) return U.Open({page='settings',category=category}) end
W.Back=U.Back;W.Forward=U.Forward
W.ModulesChanged=function() if U.window and U.window:IsShown() then U.Refresh(true) end end
W.pages={}
ns.WardenUI.Navigate=function(kind,owner,key)
 if kind=='story' then return U.Open({page='journey',owner=owner,storyId=key}) end
 return U.Open({page=kind=='player' and 'intel' or 'chronicle',kind=kind=='player' and 'player' or 'activity',owner=owner,key=key})
end
ns.AthenaSuiteUI.OpenPlayer=function(guid,owner) return ns.WardenUI.Navigate('player',owner,guid) end
ns.AthenaSuiteUI.Profile=function(guid,owner) return U.OpenPlayer(guid,owner) end
ns.AthenaSuiteUI.Card=function(guid,owner) return U.OpenPlayer(guid,owner) end
ns.AthenaSuiteUI.Group=function(key) local generation,resultID=key:match('^(%d+):(%d+)$');return U.Open({page='intel',kind='group',generation=tonumber(generation),resultID=tonumber(resultID)}) end
ns.BuildOptions=function() -- New routing entry; old Blizzard category frame is retired.
 if U.optionsRegistered or not ns.DB then return end;U.optionsRegistered=true
end
-- Welcome is owned by UI2Startup and the cinematic-first guide.

-- One visible Aether destination. Legacy Intel/Relay route IDs and all their
-- permission checks remain intact; this chooser only routes existing actions.
U.aetherToolChoices={{'agora','The Agora · Posts & rooms'},{'profiles','Player profiles & intelligence'},{'mine','My Aether Profile'},{'online','Online Fireside Users'},{'consent','Participation, privacy & sharing'},{'reports','Reports & delivery'},{'direct','Recipient-only Direct Share'}}
function U.OpenAetherTool(section)
 local owner=U.route and U.route.owner or ns.Chronicle.Owner()
 if section=='agora'then return ns.AetherPosts.Open({room='world'})
 elseif section=='mine'then return U.OpenAetherProfile()
 elseif section=='profiles'then return U.Open({page='intel',owner=owner})
 elseif section=='online'then return U.Open({page='intel',subsection='warden-online',owner=owner})
 elseif section=='reports'then return U.Open({page='relay'})
 elseif section=='consent'then return U.Open({page='relay',subsection='aether'})
 elseif section=='direct'then return U.Open({page='relay',subsection='direct'})end
 return false,'Unknown Aether destination'
end
function U.AetherTools()
 return ns.UI2Forms.Form({title='Aether',help='One player profile, with retained Athena intelligence and existing community tools. Choosing a destination changes no recording or sharing permissions.',fields={{key='section',label='Open',value='profiles',choices=U.aetherToolChoices}},submitLabel='Open',submit=function(v)return U.OpenAetherTool(v.section)end})
end
