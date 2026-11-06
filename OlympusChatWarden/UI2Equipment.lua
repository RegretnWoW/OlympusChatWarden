-- Read-only paper doll for the selected existing equipment observation.
local _,ns=...
local C,G,S=ns.UI2Components,ns.WardenDossier,ns.ChronicleStore
local slotTokens={[1]='HeadSlot',[2]='NeckSlot',[3]='ShoulderSlot',[15]='BackSlot',[5]='ChestSlot',[4]='ShirtSlot',[19]='TabardSlot',[9]='WristSlot',[10]='HandsSlot',[6]='WaistSlot',[7]='LegsSlot',[8]='FeetSlot',[11]='Finger0Slot',[12]='Finger1Slot',[13]='Trinket0Slot',[14]='Trinket1Slot',[16]='MainHandSlot',[17]='SecondaryHandSlot',[18]='RangedSlot'}
function C.Equipment(parent)
 local p=CreateFrame('Frame',nil,parent);p:SetSize(650,530);C.Fill(p,{.025,.045,.07,1});p.slots={}
 p.title=C.Text(p,'Equipment',16,C.colors.gold);p.title:SetPoint('TOPLEFT',12,-10);p.title:SetPoint('TOPRIGHT',-12,-10);p.title:SetHeight(24)
 p.caption=C.Text(p,'',11,C.colors.muted);p.caption:SetPoint('TOPLEFT',12,-37);p.caption:SetPoint('TOPRIGHT',-12,-37);p.caption:SetHeight(30);p.caption:SetWordWrap(true)
 p.figure=CreateFrame('Frame',nil,p);p.figure:SetPoint('TOP',0,-85);p.figure:SetSize(160,335)
 p.portrait=p.figure:CreateTexture(nil,'ARTWORK');p.portrait:SetSize(112,112);p.portrait:SetPoint('CENTER',0,34)
 p.name=C.Text(p.figure,'',15,C.colors.text);p.name:SetPoint('TOPLEFT',0,-5);p.name:SetPoint('TOPRIGHT',0,-5);p.name:SetHeight(44);p.name:SetJustifyH('CENTER');p.name:SetWordWrap(true)
 p.appearance=C.Text(p.figure,'',11,C.colors.muted);p.appearance:SetPoint('BOTTOMLEFT',0,10);p.appearance:SetPoint('BOTTOMRIGHT',0,10);p.appearance:SetHeight(45);p.appearance:SetJustifyH('CENTER');p.appearance:SetWordWrap(true)
 for n,slot in ipairs(G.slots)do
  local b=CreateFrame('Button',nil,p);p.slots[n]=b;b.slotID=slot[1];b.label=slot[2];b:SetSize(40,40)
  b.back=C.Fill(b,{.12,.15,.19,1});b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetPoint('TOPLEFT',3,-3);b.icon:SetPoint('BOTTOMRIGHT',-3,3)
  b.border=b:CreateTexture(nil,'OVERLAY');b.border:SetAllPoints();b.border:SetTexture('Interface\\Buttons\\UI-Quickslot2');b.border:SetVertexColor(.80,.61,.31,1)
  b.unknown=C.Text(b,'',16,C.colors.gold);b.unknown:SetAllPoints();b.unknown:SetJustifyH('CENTER')
  b:SetScript('OnClick',function(self,button)if not C.EditBlocked(self)then G.ItemClick(self,button)end end)
  b:SetScript('OnEnter',function(self)
   if not GameTooltip then return end;GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText(self.label)
   if self.link then ns.SafeCall(GameTooltip.SetHyperlink,GameTooltip,self.link)elseif self.itemID then ns.SafeCall(GameTooltip.SetItemByID,GameTooltip,self.itemID)end
   GameTooltip:AddLine(self.itemName or self.state=='empty' and 'Empty' or self.itemID and ('Item #'..self.itemID) or 'Not observed',.90,.90,.90,true)
   GameTooltip:AddLine(self.observed or '',.65,.75,.84,true)
   if self.itemID and not self.link then GameTooltip:AddLine('Exact item modifiers were not recorded.',.9,.7,.35,true)end
   GameTooltip:Show()
  end);b:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide()end end)
 end
 function p:Layout()
  local w=self:GetWidth();local compact=w<540;local size=compact and 34 or 42;local side=compact and 14 or 20
  self.figure:SetWidth(math.max(80,math.min(190,w-2*(size+side+12))))
  for n,b in ipairs(self.slots)do
   b:ClearAllPoints();b:SetSize(size,size)
   if n<=16 then
    local right=n>8;local row=(n-1)%8;local y=-76-row*46
    b:SetPoint(right and 'TOPRIGHT' or 'TOPLEFT',right and -side or side,y)
   else
    b:SetPoint('TOP',self,'TOP',(n-18)*(size+25),-459)
   end
  end
 end
 local function stopModel(self)
  self.boundUnit=nil;self.figure:SetScript('OnUpdate',nil)
  if self.model then self.model:Hide();ns.SafeCall(self.model.ClearModel,self.model)end
  self.portrait:Show()
 end
 function p:Appearance()
  stopModel(self);local m=self.data.person or {};local guid=m.key or m.guid
  local unit=self.data.live and self.data.owner==ns.Chronicle.Owner() and not ns.Checked(ns.SafeCall(InCombatLockdown)) and G.Resolve(guid)
  self.appearance:SetText('Portrait\nAppearance not recorded')
  if not unit or m.state=='synthetic' then return end
  if not self.model then local ok,model=pcall(CreateFrame,'PlayerModel',nil,self.figure);if ok and model and type(model.SetUnit)=='function'then self.model=model;model:SetPoint('TOPLEFT',0,-45);model:SetPoint('BOTTOMRIGHT',0,58);model:EnableMouse(true)
   local angle,x=0,nil
   model:SetScript('OnMouseDown',function(_,button)if button=='LeftButton'and not C.EditBlocked(self)then x=ns.SafeNumber(ns.SafeCall(GetCursorPosition))end end)
   model:SetScript('OnMouseUp',function()x=nil end)
   self.rotate=function()if x then local nextX=ns.SafeNumber(ns.SafeCall(GetCursorPosition));if nextX then angle=angle+(nextX-x)*.01;x=nextX;ns.SafeCall(model.SetRotation,model,angle)end end end
  end end
  local model=self.model;if not model then return end
  local ok=pcall(model.SetUnit,model,unit);if not ok or G.Resolve(guid)~=unit then return end
  self.boundUnit=unit;self.portrait:Hide();model:Show();ns.SafeCall(model.SetPortraitZoom,model,0);ns.SafeCall(model.SetCamDistanceScale,model,1.1);self.appearance:SetText('Live appearance\nDrag to rotate')
  local dt=0;self.figure:SetScript('OnUpdate',function(_,elapsed)
   if self.rotate then self.rotate()end;dt=dt+elapsed;if dt<.25 then return end;dt=0
   if self.data.owner~=ns.Chronicle.Owner()or not ns.Modules.Enabled('intel')or not ns.Membership.Allowed()or ns.Checked(ns.SafeCall(InCombatLockdown))or G.Resolve(guid)~=self.boundUnit then stopModel(self);self.appearance:SetText('Appearance unavailable\nRecorded items remain')end
  end)
 end
 function p:Render(data)
  self.data=data;self:Layout();self.title:SetText(data.title or 'Recorded equipment');self.caption:SetText(data.caption or 'Slots without an observation remain unknown.');self.name:SetText(data.person and data.person.title or '')
  C.Portrait(self.portrait,data.person or {values={}})
  local byID={};for _,slot in ipairs(data.slots or {})do byID[slot[1]]=slot end
  for _,b in ipairs(self.slots)do local r=byID[b.slotID]or{b.slotID,'unavailable',false,false};local id=type(r[3])=='number'and r[3]or nil;local payload=type(r[4])=='string'and r[4]or nil
   b.state=r[2];b.itemID=id;b.link=nil;b.clickLink=nil;b.observed=data.caption;b.itemName=nil
   local itemName,quality,icon
   if id then local a,_,q,_,_,_,_,_,_,texture=ns.WardenBrand.Values(GetItemInfo or C_Item and C_Item.GetItemInfo,payload or id);itemName,quality,icon=a,q,texture end
   b.itemName=S.Text(itemName,200);b.link=payload and (payload:find('|H',1,true)and payload or '|H'..payload..'|h['..(b.itemName or 'Item #'..tostring(id))..']|h')or nil
   b.clickLink=b.link or id and '|Hitem:'..id..'|h['..(b.itemName or 'Item #'..id)..']|h'
   local _,slotIcon=ns.SafeCall(GetInventorySlotInfo,slotTokens[b.slotID]);b.icon:SetTexture(ns.Readable(icon)and icon or slotIcon or 'Interface\\Icons\\INV_Misc_QuestionMark');b.icon:SetAlpha(id and 1 or .28)
   b.unknown:SetText(id and ''or r[2]=='empty'and '-'or '?')
   local cr,cg,cb=ns.SafeCall(GetItemQualityColor,quality);if not ns.SafeNumber(cr)then cr,cg,cb=.8,.61,.31 end;b.border:SetVertexColor(cr,cg,cb,1)
   if b.icon.SetDesaturated then b.icon:SetDesaturated(not id)end
  end
  self:Appearance();self:Show()
 end
 p:SetScript('OnSizeChanged',function(self)self:Layout()end);p:SetScript('OnHide',function(self)stopModel(self);self.data=nil end)
 return p
end
