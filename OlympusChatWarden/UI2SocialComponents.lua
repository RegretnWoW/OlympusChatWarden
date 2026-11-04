-- Small composed controls, reused by the existing canonical dossier pages.
local _,ns=...
local C=ns.UI2Components
local outline=C.Star
function C.Star(parent,size)
 local f=outline(parent,size);local layers={}
 -- A bounded polygon scanline fill; no external asset dependency.
 local points={};for i=0,9 do local a=-math.pi/2+i*math.pi/5;local r=i%2==0 and size/2 or size*.21;points[#points+1]={size/2+math.cos(a)*r,size/2+math.sin(a)*r} end
 for y=1,size-1,1 do local xs={};for i,a in ipairs(points) do local b=points[i%10+1];if (a[2]<=y and b[2]>y) or (b[2]<=y and a[2]>y) then xs[#xs+1]=a[1]+(y-a[2])*(b[1]-a[1])/(b[2]-a[2]) end end;table.sort(xs)
  for i=1,#xs-1,2 do local line=f:CreateLine(nil,'ARTWORK');line:SetStartPoint('TOPLEFT',f,xs[i],-y);line:SetEndPoint('TOPLEFT',f,xs[i+1],-y);line:SetThickness(1.3);layers[#layers+1]=line end
 end
 function f:SetGold(on) for _,line in ipairs(self.outline or {}) do line:SetColorTexture(unpack(on and C.colors.gold or {.32,.36,.40,1})) end;for _,line in ipairs(layers) do line:SetColorTexture(unpack(on and C.colors.gold or {.32,.36,.40,1})) end end
 f:SetGold(false);return f
end
local function paint(row,value) for n,b in ipairs(row.votes) do if b.star then b.star:SetGold(n<=(value or 0)) end end end
function C.Rating(row,voting,y)
 row.rating=voting;local max=voting.maximum or 5;local step=math.min(26,(row:GetWidth()-28)/max)
 for n=1,math.max(max,#row.votes) do local button=row.votes[n]
  if n<=max then
   if not button then local score=n;button=CreateFrame('Button',nil,row);button:SetSize(24,26);button.star=C.Star(button,18);button.star:SetPoint('CENTER');row.votes[n]=button
    button:SetScript('OnClick',function(self)
     if C.EditBlocked(self) or not row.rating then return end
     if not row.rating.enabled then ns.UI2.voteFeedback=row.rating.reason or 'This rating is not authorized.';ns.UI2.Refresh(true);return end
     local v=row.rating;local ok,why
     if v.kind=='GUILD' then ok,why=ns.AetherNet.Vote('GUILD',v.key,score) else ok,why=ns.PlayerCard.Vote(v.guid,score) end
     ns.UI2.voteFeedback=why or (ok and 'Rating saved.' or 'Your rating could not be saved.');ns.UI2.Refresh(true)
    end)
    button:SetScript('OnEnter',function(self) local v=row.rating;if not v then return end
     if v.enabled and not C.EditBlocked(self) then paint(row,score) end
     if GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText((v.kind=='GUILD' and 'Guild ' or 'Rate this player ')..score..' of '..(v.maximum or 5)..' stars\nYour vote: '..(v.stars or 'None')..' · Community average is shown separately.\n'..(v.reason or ''));GameTooltip:Show() end
    end)
    button:SetScript('OnLeave',function() paint(row,row.rating and row.rating.stars);if GameTooltip then GameTooltip:Hide() end end)
   end
   if not button.materialFace then local face=C.TactileRow(button,function()return row.rating and row.rating.enabled==true end);button.star:SetParent(face);button.star:ClearAllPoints();button.star:SetPoint('CENTER',face,'CENTER')end
   button.voteGUID=voting.guid or voting.key;button:SetEnabled(true);button:SetAlpha(voting.enabled and 1 or .55);button:ClearAllPoints();button:SetPoint('TOPLEFT',(n-1)*step,-y-4);button:SetSize(step,26);button:Show()
  elseif button then button:Hide() end
 end
 paint(row,voting.stars)
 if not row.withdraw then row.withdraw=C.Button(row,'x',function(self)
  local v=row.rating;if not v or not v.enabled or C.EditBlocked(self) then return end
  local ok,why;if v.kind=='GUILD' then ok,why=ns.AetherNet.Vote('GUILD',v.key,nil) else ok,why=ns.PlayerCard.Vote(v.guid,nil) end
  ns.UI2.voteFeedback=why or (ok and 'Rating removed.' or 'Your vote could not be withdrawn.');ns.UI2.Refresh(true)
 end,24);row.withdraw:SetScript('OnEnter',function(self) if GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText('Withdraw your vote');GameTooltip:Show() end end);row.withdraw:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end) end
 row.withdraw:ClearAllPoints();row.withdraw:SetPoint('TOPLEFT',max*step+2,-y-4);row.withdraw:SetSize(24,26);row.withdraw:SetShown(voting.stars~=nil);row.withdraw:SetEnabled(voting.enabled==true)
end
function C.Collection(parent)
 local f=CreateFrame('Frame',nil,parent);f.pool={};f.filtered={}
 f.search=C.Edit(f,150,'Filter this list');f.search:SetPoint('TOPLEFT',0,-2);f.search:SetPoint('TOPRIGHT',0,-2)
 f.scope=C.Text(f,'',11,{.13,.17,.21,1});f.scope:SetPoint('TOPLEFT',0,-34);f.scope:SetPoint('TOPRIGHT',0,-34);f.scope:SetHeight(24)
 f.scroll=CreateFrame('ScrollFrame',nil,f);f.scroll:SetPoint('TOPLEFT',0,-62);f.scroll:SetPoint('BOTTOMRIGHT');f.scroll:EnableMouseWheel(true)
 f.content=CreateFrame('Frame',nil,f.scroll);f.content:SetWidth(100);f.content:SetHeight(1);f.scroll:SetScrollChild(f.content)
 function f:Paint()
  local width=math.max(100,self.scroll:GetWidth());self.content:SetWidth(width);local first=math.floor(self.scroll:GetVerticalScroll()/72)+1;local limit=math.ceil(math.max(1,self.scroll:GetHeight())/72)+1
  for i=1,math.max(limit,#self.pool) do local row=self.pool[i];local item=i<=limit and self.filtered[first+i-1]
   if item then
    if not row then row=CreateFrame('Button',nil,self.content);self.pool[i]=row;row.icon=row:CreateTexture(nil,'ARTWORK');row.icon:SetPoint('TOPLEFT',0,-8);row.icon:SetSize(27,27);row.title=C.Text(row,'',13,{.025,.04,.06,1});row.title:SetPoint('TOPLEFT',34,-4);row.title:SetPoint('TOPRIGHT',-4,-4);row.title:SetHeight(26);row.detail=C.Text(row,'',11,{.13,.17,.21,1});row.detail:SetPoint('TOPLEFT',34,-31);row.detail:SetPoint('TOPRIGHT',-4,-31);row.detail:SetHeight(33);row.detail:SetWordWrap(true);row:SetScript('OnClick',function(self) if not C.EditBlocked(self) and self.item and self.item.activate then self.item.activate() end end) end
    C.TactileRow(row);row.item=item;row:ClearAllPoints();row:SetPoint('TOPLEFT',0,-(first+i-2)*72);row:SetSize(width,72);row.title:SetText(item.title);row.detail:SetText(item.detail or '');row.icon:SetShown(item.person~=nil);if item.person then C.Portrait(row.icon,item.person) end;row:Show()
   elseif row then row:Hide();row.item=nil end
  end
 end
 function f:Filter()
  self.filtered={};local query=(self.search:GetText() or ''):lower()
  for _,item in ipairs(self.data and self.data.items or {}) do if query=='' or ((item.title or '')..' '..(item.detail or '')):lower():find(query,1,true) then self.filtered[#self.filtered+1]=item end end
  self.scope:SetText(#self.filtered..' '..(self.data and self.data.label or 'entries')..' · Recorded associations');self.content:SetHeight(math.max(1,#self.filtered*72));self.scroll:SetVerticalScroll(0);self:Paint()
 end
 function f:Render(data)
  if self.key~=data.key then self.key=data.key;self.search:SetText('');self.scroll:SetVerticalScroll(0) end
  local offset=self.scroll:GetVerticalScroll();self.data=data;self:Filter();self.scroll:SetVerticalScroll(math.min(offset,math.max(0,#self.filtered*72-self.scroll:GetHeight())));self:Paint()
 end
 f.search:SetScript('OnTextChanged',function() if not C.EditBlocked(f) then f:Filter() end end)
 f.scroll:SetScript('OnMouseWheel',function(self,delta) if C.EditBlocked(self) then return end;self:SetVerticalScroll(math.max(0,math.min(math.max(0,#f.filtered*72-self:GetHeight()),self:GetVerticalScroll()-delta*58)));f:Paint() end)
 return f
end
