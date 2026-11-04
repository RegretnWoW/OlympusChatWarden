-- One local editor for every registered UI2 template. No content is exported.
local _,ns=...
local U,C,F,E=ns.UI2,ns.UI2Components,ns.UI2Forms,ns.UI2LayoutEngine
local D={};ns.UI2LayoutEditor=D
-- Opt-in, memory-only developer trace. No names, content or saved records.
function D.TraceDrag(event,id)
 if not D.dragTraceEnabled then return end
 D.dragTrace=D.dragTrace or {};if #D.dragTrace>=32 then table.remove(D.dragTrace,1) end
 local x,y=GetCursorPosition();D.dragTrace[#D.dragTrace+1]={event=event,card=id,x=x,y=y}
end
local function busy() return ns.Checked(ns.SafeCall(InCombatLockdown)) end
local function card(id) for _,v in ipairs(D.tx and D.tx.layout.cards or {}) do if v.id==id then return v end end end
local function eligible() return ns.DB and ns.Membership.Allowed() and not busy() and not U.locked end
local function contextValid()
 if not D.tx then return true end
 local r=U.route or {};local old=D.route or {}
 if r.key~=old.key or r.owner~=old.owner or r.asOf~=old.asOf or r.originGuild~=old.originGuild then return false end
 local module=({intel='intel',chronicle='chronicle',journey='chronicle',messages='chat',shield='shield',mentions='alerts',relay='relay'})[r.page]
 if D.tx.scope then local proof=E.Entitlement(r,D.tx.template);if not proof or proof.key~=D.tx.scope.key or proof.owner~=D.tx.owner then return false end end
 return not module or ns.Modules.Enabled(module)
end
local function rerender() if U.window and U.window:IsShown() then U.Refresh(true) end end
function D.Change(changes)
 local ok,why=E.Change(D.tx,D.selected,changes);D.message=ok and 'Unsaved layout changes' or why;rerender();return ok,why
end
function D.Reorder(id,target,region)
 if not D.tx then return false end
 local spec=E.templates[D.tx.template].cards[id];if not spec or not spec.canMove then return false,'Essential section stays anchored' end
 local current=card(id);region=region or E.Lane(current)
 if region~='left' and region~='center' and region~='right' then return false,'Choose a named column' end
 local all={};for _,v in ipairs(E.Order(D.tx.layout)) do if v.id~=id and E.Lane(v)==region then all[#all+1]=v end end
 local item=E.Copy(current);item.region=region;table.insert(all,math.max(1,math.min(#all+1,target)),item)
 local nextLayout=E.Copy(D.tx.layout);for n,v in ipairs(all) do for _,c in ipairs(nextLayout.cards) do if c.id==v.id then c.order=n;c.region=region end end end
 local clean,why=E.ValidateLayout(D.tx.template,nextLayout,true);if not clean then return false,why end
 E.Push(D.tx);D.tx.layout=clean;D.tx.dirty=true;D.selected=id;rerender();return true
end
function D.Move(delta)
 local c=card(D.selected);if not c then return false end;local index=0
 for _,v in ipairs(E.Order(D.tx.layout)) do if E.Lane(v)==E.Lane(c) then index=index+1;if v.id==c.id then return D.Reorder(c.id,index+delta,E.Lane(c)) end end end
end
function D.MoveLane(delta)
 local c=card(D.selected);if not c then return false end;local names={'left','center','right'};local index=E.Lane(c)=='left' and 1 or E.Lane(c)=='right' and 3 or 2
 return D.Reorder(c.id,1,names[math.max(1,math.min(3,index+delta))])
end
function D.Begin(template)
 if not eligible() then return false,'Layout editing is available after combat and verification.' end
 if D.tx then return false,'Finish the current layout first.' end
 U.Ensure();template=template or E.Template(U.route);if not E.templates[template] then return false,'No owned layout here.' end
 local tx,why=E.BeginScoped(template,U.route or {});if not tx then return false,why end
 D.tx=tx;D.route=E.Copy(U.route);D.offset=U.canvas.scroll:GetVerticalScroll();D.selected=E.templates[template].order[1];for _,id in ipairs(E.templates[template].order) do if E.templates[template].cards[id].canMove then D.selected=id;break end end;D.preview=false;D.message=D.tx.scope and 'PRIVATE · NOT PUBLISHED · Drag a handle to arrange.' or 'Drag a handle · Arrow keys move the selected section.'
 if template=='journey.chrome' then U.immersive=false end
 D.tabs=true;D.focus='cards';D.tabSelected=U.route and (U.route.page=='relay' and 'intel' or U.route.page) or 'overview'
 U.SetLayoutEditing(true)
 local ok,err=pcall(function() D.Ensure();rerender() end)
 if not ok then D.Cancel(false);return false,'Layout editor could not open: '..tostring(err) end
 return true
end
function D.Cancel(refresh)
 if not D.tx then U.SetLayoutEditing(false);return true end
 local offset=D.offset;U.EndNavigationDrag();D.tabs=nil;D.EndDrag();D.tx=nil;D.selected=nil;D.preview=false;D.drag=nil;U.canvas.layoutEditing=false
 U.SetLayoutEditing(false)
 if D.toolbar then D.toolbar:Hide() end;if D.ghost then D.ghost:Hide() end
 if D.dropMarker then D.dropMarker:Hide() end;if D.laneMarker then D.laneMarker:Hide() end;if D.more then D.more:Hide() end
 for _,frame in ipairs(U.canvas.cards or {}) do if frame.layoutOverlay then frame.layoutOverlay:SetScript('OnUpdate',nil) end end
 if U.route then U.route.scroll=offset end
 D.skipScrollCapture=true
 if refresh~=false then rerender() end;return true
end
function D.Save()
 if not eligible() or not contextValid() then D.Cancel();return false,'Editing ended; no layout was saved.' end
 local ok,why=E.SaveScoped(D.tx);if ok then local name=D.tx.template;D.Cancel(false);D.message='Layout saved for '..name;rerender();if ns.OlympusPanel then for _,page in ipairs(ns.OlympusPanel.pages) do ns.OlympusPanel.Refresh(page) end end end;return ok,why
end
function D.Navigate(fn)
 if not D.tx then return fn() end
 if not D.tx.dirty then D.Cancel(false);return fn() end
 F.Confirm('Discard unsaved layout changes?','The saved arrangement, player data and settings are unchanged. Confirm to leave this editor.',function() D.Cancel(false);fn();return true end)
 return false,'Unsaved layout confirmation opened'
end
function D.Picker()
 local choices={};for _,id in ipairs(E.templates[D.tx.template].order) do local s=E.templates[D.tx.template].cards[id];if not s.system then local c=card(id);choices[#choices+1]={id,s.label..(c.hidden and ' · hidden' or '')} end end
 F.Form({title='Choose or restore a section',help='All registered sections are listed, including ones with no content in this context.',fields={{key='card',label='Section',choices=choices,value=D.selected}},submitLabel='Select & restore',submit=function(v) D.selected=v.card;local c=card(v.card);if c.hidden then return D.Change({hidden=false}) end;rerender();return true end})
end
function D.Columns()
 F.Form({title='Column proportions',help='Your chosen columns stay in place at every interface scale. Scaling shrinks the whole interface uniformly.',fields={{key='columns',label='Layout',value=table.concat(D.tx.layout.columns,','),choices={{'3,6,3','Narrow / wide / narrow (3 : 6 : 3)'},{'4,4,4','Three equal columns (4 : 4 : 4)'},{'6,6','Two equal columns (6 : 6)'},{'12','One full-width column'}}}},submit=function(v) local out={};for n in v.columns:gmatch('%d+') do out[#out+1]=tonumber(n) end;local ok,why=E.Columns(D.tx,out);rerender();return ok,why end})
end
function D.ResetPage()
 local name=D.tx and D.tx.template or E.Template(U.route)
 return F.Confirm('Reset this page layout?','Only '..name..' is reset to the shipped author default. All player history, privacy choices and other page layouts are kept.',function()
  if D.tx then E.Push(D.tx);if D.tx.scope then D.tx.theme='navy' end;D.tx.layout=E.Default(name);D.tx.dirty=true;rerender();return true end
  E.Reset(name);rerender();return true
 end)
end
function D.Export(all)
 local text=E.Export(not all and (D.tx and D.tx.template or E.Template(U.route)) or nil,not all and D.tx and D.tx.layout or nil)
 return F.Copy(all and 'Export layout pack · all templates' or 'Export saved page layout',text)
end
function D.Import()
 if D.tx then return false,'Save or cancel the current editor before importing.' end
 return F.Form({title='Import layout pack',help='Paste a data-only Olympus layout export. Import changes presentation only. No player details, chat, notes, history, consent or network configuration are accepted.',fields={{key='pack',label='Layout JSON (maximum 64 KiB)',multiline=true,height=220,limit=E.maxBytes,code=true}},submitLabel='Validate & preview',submit=function(v,f)
  local pack,why=E.Import(v.pack);if not pack then return false,why end
  local names={};for name in pairs(pack.templates) do names[#names+1]=name end;table.sort(names)
  f.completed=true;f:Hide()
  F.Confirm('Apply '..pack.count..' validated layout templates?',table.concat(names,', ')..'. This replaces only these local layout preferences. All other settings and data stay unchanged.',function() local ok,reason=E.ApplyImport(pack);rerender();return ok,reason end)
  return false,'Review opened. Nothing is applied until confirmation.'
 end})
end
function D.AppearanceRows(rows)
 local function add(id,title,detail,fn) rows[#rows+1]={id=id,title=title,detail=detail,height=48,wrap=true,activate=fn} end
 add('LAYOUT.EDIT','Edit Layout','Arrange this page or choose Tabs to reorder navigation',function() D.Begin() end)
 add('LAYOUT.TABS.RESET','Reset Tab Order','Restore the ten default destinations',function() E.ResetNavigation();U.LayoutNavigation(U.window:GetWidth(),U.window:GetWidth()<1450);rerender() end)
 add('LAYOUT.EXPORT.ALL','Export Layout Pack','All saved page templates · creator workflow',function() D.Export(true) end)
 add('LAYOUT.IMPORT','Import Layout Pack','Validate before applying',D.Import)
 add('LAYOUT.RESET.ALL','Reset all page layouts','Presentation only · confirmation required',function() F.Confirm('Reset all page layouts?','All local layout overrides will be removed. Shipped defaults apply on every page. Data, privacy settings and consent remain unchanged.',function() E.Reset();rerender();return true end) end)
 add('LAYOUT.OFFICIAL','Official Olympus child layout','Only Fireside-owned shortcuts and activity region',function() D.Begin('olympus.panel') end)
 rows[#rows+1]={title='Layout exports contain positions and section IDs only. Send your export and screenshots to the builder to make an official author-default pack.',height=72,wrap=true,kind='caption'}
end
function D.Palette()
 if not D.tx or not D.tx.scope or D.tx.scope.kind~='CHARACTER' then return false,'Your private profile editor is required.' end
 local choices={};for _,id in ipairs(E.paletteOrder) do choices[#choices+1]={id,E.palette[id].label} end
 return F.Form({title='Player card background',help='Private preview only. Save Layout keeps this color for your own character. No network publication.',fields={{key='theme',label='Background Color',value=D.tx.theme,choices=choices}},submitLabel='Preview color',submit=function(v)
  if not E.palette[v.theme] or not contextValid() then return false,'Owner or palette unavailable' end
  E.Push(D.tx);D.tx.theme=v.theme;D.tx.dirty=true;rerender();return true
 end})
end
function D.Ensure()
 if D.toolbar then return end
 local bar=C.Card(U.stage,'',false);D.toolbar=bar;bar.heading:Hide();bar:SetPoint('TOPLEFT');bar:SetPoint('TOPRIGHT');bar:SetHeight(66);bar:SetFrameLevel(U.canvas:GetFrameLevel()+40)
 D.status=C.Text(bar,'',11,C.colors.gold);D.status:SetPoint('TOPLEFT',10,-4);D.status:SetPoint('TOPRIGHT',-10,-4);D.status:SetHeight(18)
 local buttons={{'Save',D.Save},{'Cancel',function() D.Cancel() end},{'Undo',function() E.Undo(D.tx);rerender() end},{'Preview',function() D.preview=not D.preview;rerender() end},{'Sections',D.Picker},{'More',function() D.More() end},{'Move Left',function() D.MoveTab(-1) end},{'Move Right',function() D.MoveTab(1) end},{'Reset Tab Order',function() E.ResetNavigation();U.LayoutNavigation(U.window:GetWidth(),false);D.UpdateToolbar() end}}
 local x=10
 for _,v in ipairs(buttons) do local width=#v[1]>9 and 128 or #v[1]>7 and 96 or 72;local btn=C.Button(bar,v[1],v[2],width);btn:SetPoint('TOPLEFT',x,-28);x=x+width+6;bar[v[1]]=btn end
 if bar.EnableKeyboard then bar:EnableKeyboard(true) end
 bar:SetScript('OnKeyDown',function(self,key)
  if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
  if not D.tx or D.preview or F.active and F.active:IsShown() then return end
  local handled=true
  if D.focus=='tabs' then
   if key=='LEFT' or key=='RIGHT' then D.MoveTab(key=='LEFT' and -1 or 1)
   elseif key=='TAB' then local order=U.NavigationOrder();local index=1;for n,id in ipairs(order) do if id==D.tabSelected then index=n end end;D.tabSelected=order[index%#order+1];U.LayoutNavigation(U.window:GetWidth(),U.window:GetWidth()<1450);D.UpdateToolbar()
   elseif key=='ESCAPE' then D.ToggleTabs() else handled=false end
  elseif key=='TAB' then local order=E.Order(D.tx.layout);local index=1;for n,c in ipairs(order) do if c.id==D.selected then index=n end end
   local step=IsShiftKeyDown and IsShiftKeyDown() and -1 or 1
   for _=1,#order do index=(index-1+step)%#order+1;if E.templates[D.tx.template].cards[order[index].id].canMove then D.selected=order[index].id;break end end;rerender()
  elseif key=='UP' or key=='DOWN' then D.Move(key=='UP' and -1 or 1)
  elseif key=='LEFT' or key=='RIGHT' then D.MoveLane(key=='LEFT' and -1 or 1)
  elseif key=='ESCAPE' then D.Cancel()
  else handled=false end
  if handled and self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
 end)
 bar:Hide()
end
function D.MoveTab(delta)
 D.focus='tabs'
 local order=U.NavigationOrder();for n,id in ipairs(order) do if id==D.tabSelected then return U.MoveNavigationTab(id,n+delta) end end
end
function D.UpdateToolbar()
 if not D.toolbar then return end
 local title='';for _,d in ipairs(U.destinations) do if d[1]==D.tabSelected then title=d[2] end end
 D.status:SetText('Drag cards or navigation tabs · Selected tab: '..title..' · Tab order saves automatically')
end
function D.ToggleTabs()
 if not D.tx then return false end
 D.tabs=true;D.focus='tabs';D.UpdateToolbar();return true
end
function D.More()
 if not D.tx then return end
 if D.more then D.more:SetShown(not D.more:IsShown());if D.controls[6] then D.controls[6]:SetEnabled(D.tx.scope and D.tx.scope.kind=='CHARACTER' or false) end;return end
 local menu=C.Card(D.toolbar,'Layout tools',false);D.more=menu;menu:SetPoint('TOPLEFT',10,-68);menu:SetSize(330,258);menu:SetFrameLevel(D.toolbar:GetFrameLevel()+10)
 local actions={{'Move left',function() D.MoveLane(-1) end},{'Move right',function() D.MoveLane(1) end},{'Move up',function() D.Move(-1) end},{'Move down',function() D.Move(1) end},{'Column widths',D.Columns},{'Background Color',D.Palette},{'Hide / restore',function() local v=card(D.selected);D.Change({hidden=not v.hidden}) end},{'Fold / unfold',function() local v=card(D.selected);D.Change({collapsed=not v.collapsed}) end},{'Reset page',D.ResetPage},{'Export page',function() D.Export(false) end}}
 D.controls={};for n,v in ipairs(actions) do local action=v[2];local button=C.Button(menu,v[1],function() menu:Hide();action() end,150);button:SetPoint('TOPLEFT',10+((n-1)%2)*160,-42-math.floor((n-1)/2)*41);D.controls[n]=button end;D.controls[6]:SetEnabled(D.tx.scope and D.tx.scope.kind=='CHARACTER' or false)
end
function D.EndDrag()
 D.drag=nil;if D.dragHandle then D.dragHandle:SetScript('OnUpdate',nil) end
 if D.ghost then D.ghost:Hide() end;if D.dropMarker then D.dropMarker:Hide() end;if D.laneMarker then D.laneMarker:Hide() end
end
function D.Target(canvas,x,y,id)
 if x<canvas:GetLeft() or x>canvas:GetRight() or y>canvas:GetTop() or y<canvas:GetBottom() then return end
 local lx=x-canvas:GetLeft();local ly=canvas.scroll:GetTop()-y+canvas.scroll:GetVerticalScroll();local lane
 for _,l in ipairs(canvas.lanes or {}) do if lx>=l.x and lx<=l.x+l.w+12 then lane=l;break end end
 if not lane or ly<(lane.top or 0) then return end
 local before,index;index=1;local marker=lane.top or 0
 for _,b in ipairs(canvas.placed or {}) do if b.id~=id and b.grid.lane==lane.name then
  if ly<b.grid.y+b.grid.h/2 then before=b.id;marker=b.grid.y;break end
  index=index+1;marker=b.grid.y+b.grid.h+6
 end end
 return {region=lane.name,index=index,y=marker,x=lane.x,w=lane.w,before=before}
end
function D.Decorate(canvas,frame,b)
 if frame.layoutOverlay then frame.layoutOverlay:Hide() end
 if not D.tx or D.preview then return end
 local spec=E.templates[D.tx.template].cards[b.id];if not spec.canMove then return end
 if not frame.layoutOverlay then
  local handle=C.Button(frame,'::',nil,30);frame.layoutOverlay=handle;handle:SetSize(30,22);handle:SetPoint('TOPRIGHT',-5,-4);handle:SetFrameLevel(frame:GetFrameLevel()+80);handle:RegisterForDrag('LeftButton')
  if handle.SetHitRectInsets then handle:SetHitRectInsets(-6,-6,-5,-5) end
  if handle.SetPropagateMouseClicks then handle:SetPropagateMouseClicks(false) end
  if handle.SetPropagateMouseMotion then handle:SetPropagateMouseMotion(false) end
  -- The entire visible title strip is a grab surface too. Body controls are
  -- never covered by an invisible full-card drag overlay.
  handle:SetScript('OnClick',function(self) if D.tx then D.focus='cards';D.selected=self.cardID;rerender() end end)
  handle:SetScript('OnEnter',function(self) if GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText('Move '..self.cardLabel..' · Drag or use arrow keys');GameTooltip:Show() end end)
  handle:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
  handle:SetScript('OnDragStart',function(self)
   if not D.tx or D.preview or D.drag or not eligible() then return end
   U.SetLayoutEditing(true);D.TraceDrag('card-start',self.cardID)
   D.focus='cards';D.selected=self.cardID;D.drag={id=self.cardID,width=canvas:GetWidth(),height=canvas:GetHeight()};D.dragHandle=self
   if not D.ghost then D.ghost=C.Card(U.window,'Moving section',false);D.ghost:SetSize(180,38);D.ghost:SetFrameStrata('TOOLTIP') end;D.ghost.title:SetText(self.cardLabel);D.ghost:Show()
   if not D.dropMarker then D.dropMarker=CreateFrame('Frame',nil,canvas.content);D.dropMarker:SetFrameLevel(canvas:GetFrameLevel()+110);C.Fill(D.dropMarker,C.colors.gold) end
   if not D.laneMarker then D.laneMarker=CreateFrame('Frame',nil,canvas.content);D.laneMarker:SetFrameLevel(canvas:GetFrameLevel()+1);C.Fill(D.laneMarker,{.3,.65,.9,.07}) end
   self:SetScript('OnUpdate',function(_,dt)
    if not D.tx or not D.drag then return D.EndDrag() end
    local cx,cy=GetCursorPosition();local scale=canvas:GetEffectiveScale();local x,y=cx/scale,cy/scale
    D.ghost:ClearAllPoints();D.ghost:SetPoint('BOTTOMLEFT',UIParent,'BOTTOMLEFT',cx/UIParent:GetEffectiveScale()+12,cy/UIParent:GetEffectiveScale()+12)
    D.dropMarker:Hide();D.laneMarker:Hide()
    if x>=canvas:GetLeft() and x<=canvas:GetRight() and y<=canvas:GetTop() and y>=canvas:GetBottom() then
     local delta=y>canvas:GetTop()-30 and -1 or y<canvas:GetBottom()+30 and 1 or 0;local scroll=canvas.scroll
     scroll:SetVerticalScroll(math.max(0,math.min(math.max(0,(canvas.total or 0)-scroll:GetHeight()),scroll:GetVerticalScroll()+delta*240*(dt or .016))))
    end
    local target=D.Target(canvas,x,y,self.cardID);D.drag.target=target
    if target then D.dropMarker:ClearAllPoints();D.dropMarker:SetPoint('TOPLEFT',target.x,-target.y);D.dropMarker:SetSize(target.w,3);D.dropMarker:Show();D.laneMarker:ClearAllPoints();D.laneMarker:SetPoint('TOPLEFT',target.x,-(canvas.lanes[1].top or 0));D.laneMarker:SetSize(target.w,math.max(canvas.total or 0,canvas:GetHeight()));D.laneMarker:Show() end
   end)
  end)
  handle:SetScript('OnDragStop',function(self)
   if not D.tx or not D.drag then return D.EndDrag() end
   local x,y=GetCursorPosition();local scale=canvas:GetEffectiveScale();local target=D.Target(canvas,x/scale,y/scale,self.cardID);D.EndDrag()
   D.TraceDrag(target and 'card-drop' or 'card-cancel',self.cardID)
   if target then D.Reorder(self.cardID,target.index,target.region);D.message='Snapped to '..target.region..' column · unsaved' else D.message='Drop canceled · draft unchanged' end;rerender()
  end)
  local heading=frame.heading
  heading:EnableMouse(true);heading:RegisterForDrag('LeftButton')
  if heading.SetPropagateMouseClicks then heading:SetPropagateMouseClicks(false) end
  if heading.SetPropagateMouseMotion then heading:SetPropagateMouseMotion(false) end
  heading:SetScript('OnDragStart',handle:GetScript('OnDragStart'));heading:SetScript('OnDragStop',handle:GetScript('OnDragStop'))
 end
 local h=frame.layoutOverlay;h.cardID=b.id;h.cardLabel=spec.label;h:SetActive(D.selected==b.id);h:Show()
 frame.heading.cardID=b.id;frame.heading.cardLabel=spec.label
 if not frame.layoutSelection then frame.layoutSelection=frame:CreateTexture(nil,'BORDER');frame.layoutSelection:SetPoint('TOPLEFT');frame.layoutSelection:SetPoint('TOPRIGHT');frame.layoutSelection:SetHeight(2);frame.layoutSelection:SetColorTexture(unpack(C.colors.gold)) end
 frame.layoutSelection:SetShown(D.selected==b.id)
end
function D.Render()
 local tx=D.tx;if not tx then if D.toolbar then D.toolbar:Hide() end;return end
 if not eligible() then D.Cancel(false);return end
 D.Ensure();D.toolbar:Show();D.status:SetText(D.preview and 'PREVIEW · actions disabled' or D.message or 'Unsaved arrangement')

 if U.journalHost then U.journalHost:Hide() end;U.canvas:Show();U.canvas:ClearAllPoints();U.canvas:SetPoint('TOPLEFT',0,-76);U.canvas:SetPoint('BOTTOMRIGHT')
 U.canvas.template=tx.template
 local blocks=U.lastBlocks
 if tx.template=='journey.chrome' or tx.template=='olympus.panel' then blocks={};for _,id in ipairs(E.templates[tx.template].order) do local s=E.templates[tx.template].cards[id];if not s.system then blocks[#blocks+1]={id=id,title=s.label,rows={{title=tx.template=='journey.chrome' and 'Book canvas, page turns, chapter links and reading controls stay intact. This edits the surrounding chrome.' or 'Only Fireside child regions are arranged. The official Olympus host and controls are not moved.',wrap=true,height=80}}} end end end
 U.canvas:Render(blocks or {},U.canvas.scroll:GetVerticalScroll());D.UpdateToolbar()
end
-- Install once after all canonical route and layout constructors exist.
local ensure=U.Ensure
function U.Ensure()
 local f=ensure();if not D.entry then
  D.entry=C.Button(U.contextFrame,'Edit Layout',function() D.Begin() end,108);D.entry:SetPoint('LEFT',78,0)
  U.hideMenu=C.Button(U.contextFrame,'Hide Menu',function()U.SetMenuHidden(true)end,104);U.hideMenu:SetPoint('LEFT',194,0)
  U.restoreMenu=C.Button(f,'Show Menu',function()U.SetMenuHidden(false)end,145);U.restoreMenu:SetPoint('BOTTOMRIGHT',f,'BOTTOMRIGHT',-28,2);U.restoreMenu:SetFrameLevel(f:GetFrameLevel()+180);U.restoreMenu:Hide()
  U.context:ClearAllPoints();U.context:SetPoint('LEFT',310,0)
  f:HookScript('OnHide',function() D.Cancel(false) end)
  -- A bounded native frame resize changes only the responsive projection.
  if f.SetResizable then f:SetResizable(true) end
  if f.SetResizeBounds then f:SetResizeBounds(880,600,2000,1400) elseif f.SetMinResize then f:SetMinResize(880,600) end
  local grip=C.Button(f,'/',nil,18);D.resizeGrip=grip;grip:SetPoint('BOTTOMRIGHT',-1,1);grip:SetSize(18,18)
  grip:SetScript('OnMouseDown',function() if not busy() then D.EndDrag();f:StartSizing('BOTTOMRIGHT') end end)
  grip:SetScript('OnMouseUp',function() f:StopMovingOrSizing() end)
  local resizing=false
  f:HookScript('OnSizeChanged',function()
   if resizing or not U.navigation then return end;resizing=true
   local width=f:GetWidth();local compact=width<1400;U.LayoutNavigation(width,compact)
   if U.LayoutHeader then U.LayoutHeader(width)end
   if U.route then U.Refresh(true) end;resizing=false
  end)
 end;return f
end
local refresh=U.Refresh
function U.Refresh(force)
 -- Hold the current measured surface under the pointer. Source/model refreshes
 -- resume on drop; context, permission or viewport changes still cancel safely.
 if D.drag and eligible() and contextValid() and U.canvas:GetWidth()==D.drag.width and U.canvas:GetHeight()==D.drag.height then return end
 if D.drag then D.EndDrag() end
 if D.tx and (not eligible() or not contextValid()) then D.Cancel(false) end
 -- Source/model updates on the same route must not reset a reader's scroll.
 -- U.Open creates a different route table, so explicit navigation still uses
 -- its own saved position instead of inheriting the previous subject's offset.
 local editScroll=D.tx and U.canvas and U.canvas.scroll:GetVerticalScroll()
 if U.canvas and U.route and D.renderedRoute==U.route and not D.tx and not D.skipScrollCapture then U.route.scroll=U.canvas.scroll:GetVerticalScroll() end
 D.skipScrollCapture=nil
 if U.canvas then U.canvas.template=E.Template(U.route);if not D.tx then U.canvas:ClearAllPoints();U.canvas:SetAllPoints(U.stage) end end
 refresh(force)
 D.renderedRoute=U.route
 if D.entry then local name=E.Template(U.route);local proof=E.Entitlement(U.route,name);D.entry:SetShown(not U.locked and not U.immersive and proof~=nil);D.entry:SetLabel(proof and proof.kind=='CHARACTER' and 'Edit Profile' or proof and proof.kind=='GUILD' and 'Edit Guild' or 'Edit Layout');D.entry:SetEnabled(not busy() and not D.tx);if U.hideMenu then U.hideMenu:SetEnabled(not busy()and not D.tx)end end
 if D.compactSections then D.compactSections:Hide() end
 if D.tx then if editScroll then U.canvas.scroll:SetVerticalScroll(editScroll) end;D.Render() end
end
for _,name in ipairs({'Open','Back','Forward'}) do local fn=U[name];U[name]=function(...) local args={...};if not D.tx then return fn(unpack(args)) end;return D.Navigate(function() return fn(unpack(args)) end) end end
local verification=U.ShowVerification
function U.ShowVerification() D.Cancel(false);if D.entry then D.entry:Hide() end;return verification() end
local rows=ns.UI2Settings.Rows
function ns.UI2Settings.Rows(category) local out=rows(category);if category=='appearance' then D.AppearanceRows(out) end;return out end
local events=CreateFrame('Frame');for _,event in ipairs({'PLAYER_REGEN_DISABLED','PLAYER_LOGOUT','PLAYER_ENTERING_WORLD'}) do events:RegisterEvent(event) end
events:SetScript('OnEvent',function() if D.tx then D.Cancel() end end)


local toolbarRefresh=U.Refresh
function U.Refresh(...)
 local result=toolbarRefresh(...);if D.tx then D.UpdateToolbar() end;return result
end
