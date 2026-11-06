-- Presentation names only. Scene IDs and saved owner/layout keys stay stable.
local _,ns=...;local L={VERSION=81,world='Aetheria',city='Pyragore'};ns.WardenLocations81=L
L.rooms={
 hall={title='Pyragore Fields',city='Pyragore',description='Open fields beyond the city gates, where the road to Pyragore begins.'},
 square={title='The Agora',city='Pyragore',description='The bustling heart of Pyragore, where merchants, travelers, and adventurers gather.'},
 study={title='Olympian Oasis',city='Pyragore',description='Your private riverside retreat, above the streets of Pyragore.'},
}
function L.Get(key)return L.rooms[key]end
function L.Caption(key)local r=L.Get(key);return r and(r.title..'\n'..r.city..' · '..L.world)or key end
function L.Position()
 local f=L.frame;if not f or not f:IsShown()then return end
 local scale=UIParent:GetEffectiveScale();local x,y=GetCursorPosition();local width,height=UIParent:GetWidth(),UIParent:GetHeight()
 x=math.max(8,math.min(width-f:GetWidth()-8,x/scale+18));y=math.max(f:GetHeight()+8,math.min(height-8,y/scale-16))
 f:ClearAllPoints();f:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',x,y)
end
function L.Hide()if L.frame then L.frame:Hide()end end
function L.Show(owner,target)
 if not L.frame then
  local f=CreateFrame('Frame',nil,UIParent,BackdropTemplateMixin and'BackdropTemplate'or nil);L.frame=f;f:EnableMouse(false);f:SetFrameStrata('TOOLTIP')
  if f.SetBackdrop then f:SetBackdrop({edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}});f:SetBackdropBorderColor(.83,.67,.33,1)end
  local bg=f:CreateTexture(nil,'BACKGROUND');bg:SetPoint('TOPLEFT',3,-3);bg:SetPoint('BOTTOMRIGHT',-3,3);bg:SetTexture(ns.WardenArt.Path('HeaderBackdrop'));bg:SetVertexColor(.76,.85,1,1)
  local wash=f:CreateTexture(nil,'BACKGROUND',nil,1);wash:SetPoint('TOPLEFT',4,-4);wash:SetPoint('BOTTOMRIGHT',-4,4);wash:SetColorTexture(.035,.12,.34,.46)
  f.title=f:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');f.title:SetPoint('TOPLEFT',15,-12);f.title:SetJustifyH('LEFT');f.title:SetTextColor(1,.85,.46)
  f.sub=f:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');f.sub:SetPoint('TOPLEFT',15,-39);f.sub:SetTextColor(.86,.76,.52)
  f.divider=f:CreateTexture(nil,'OVERLAY');f.divider:SetPoint('TOPLEFT',15,-61);f.divider:SetHeight(1);f.divider:SetColorTexture(.80,.66,.36,.8)
  f.description=f:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');f.description:SetPoint('TOPLEFT',15,-75);f.description:SetJustifyH('LEFT');f.description:SetTextColor(.94,.92,.85)
  for _,row in ipairs({{f.title,20},{f.sub,12},{f.description,14}})do local font,_,flags=row[1]:GetFont();if font then row[1]:SetFont(font,row[2],flags)end end
  if not f.SetBackdrop then for i=1,4 do local edge=f:CreateTexture(nil,'BORDER');edge:SetColorTexture(.83,.67,.33,1);if i<3 then edge:SetPoint(i==1 and'TOPLEFT'or'BOTTOMLEFT');edge:SetSize(420,1)else edge:SetPoint(i==3 and'TOPLEFT'or'TOPRIGHT');edge:SetSize(1,116)end end end
 end
 local f=L.frame;local location=target.destination and L.Get(target.destination)
 if location then
  f:SetSize(420,116);f.title:SetWidth(390);f.title:SetText(location.title);f.sub:SetText(location.city..' · '..L.world);f.sub:Show();f.divider:SetWidth(390);f.divider:Show();f.description:SetWidth(390);f.description:SetText(location.description);f.description:Show()
  local height=f.description:GetStringHeight();f:SetHeight(math.max(108,89+(height or 26)))
 else
  f.title:SetWidth(360);f.title:SetText(target.title or'');f.sub:Hide();f.divider:Hide();f.description:Hide();f:SetSize(math.min(390,math.max(90,f.title:GetStringWidth()+30)),46);f.title:SetWidth(f:GetWidth()-30)
 end
 if GameTooltip then GameTooltip:Hide()end;f:Show();L.Position();return true
end
