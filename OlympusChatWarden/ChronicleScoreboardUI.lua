local _,ns=...
local U={};ns.ChronicleScoreboardUI=U
local V,T,B=ns.Art,ns.Theme,ns.ChronicleScoreboards
local function Number(n)
 if n==nil or n==false then return '—' end
 if n>=1000000 then return string.format('%.2fm',n/1000000) elseif n>=1000 then return string.format('%.1fk',n/1000) end
 return tostring(n)
end
function U.Build(parent)
 local f=V.Panel(parent,0,-139,1136,468,'dark');f:SetFrameLevel(parent:GetFrameLevel()+30);f:Hide()
 f.title=V.Text(f,'Captured scoreboard',18,-12,900,21,V.gold);f.title:SetHeight(28)
 f.status=V.Text(f,'',18,-45,1090,13,V.muted);f.status:SetHeight(36)
 f.choices={{false,'Choose a captured board'}}
 f.select=V.Dropdown(f,18,-84,760,f.choices,function() return f.board and f.board.id or false end,function(id)
  for _,r in ipairs(f.reports or {}) do if r.id==id then f:Present(f.state,f.reports,r);break end end
 end,{maxRows=8})
 f.mode=V.Dropdown(f,790,-84,194,{{'combat','Combat totals'},{'objectives','Objectives'}},function() return f.columnsMode or 'combat' end,function(v) f.columnsMode=v;f:Render() end)
 f.close=V.Button(f,'Back',996,-84,122,30,function() f:Hide() end,'neutral')
 f.match=V.Button(f,'Open match',960,-12,158,28,function()
  local a=B.Activity(f.state,f.board)
  if a then f:Hide();ns.WardenUI.Navigate('activity',f.state.owner,a.id) end
 end,'neutral')
 f.headers={}
 f.list=V.ScrollingList(f,18,-160,1070,270,29,function(parentRow)
  local row=CreateFrame('Frame',nil,parentRow);row:SetSize(1060,28);row:EnableMouse(true)
  row.background=row:CreateTexture(nil,'BACKGROUND');row.background:SetAllPoints(row)
  row.portrait=row:CreateTexture(nil,'ARTWORK');row.portrait:SetPoint('TOPLEFT',0,-2);row.portrait:SetSize(24,24)
  row.labels={}
  for n=1,9 do local text=V.Text(row,'',0,-5,100,13,V.white or {1,1,1});text:SetHeight(19);text:SetWordWrap(false);row.labels[n]=text end
  return row
 end,function(row,item,n)
  local v=item.values;row.background:SetColorTexture(v.faction==0 and .12 or .32,.16,v.faction==0 and .30 or .12,.72)
  ns.WardenCharacterCards.Icon(row.portrait,v.classToken)
  for i,label in ipairs(row.labels) do local col=f.columns[i]
   label:SetShown(col~=nil)
   if col then
    label:ClearAllPoints();label:SetPoint('TOPLEFT',col.x+(col.key=='name' and 30 or 0),-5);label:SetWidth(col.w-(col.key=='name' and 40 or 10))
    local value=col.key=='name' and (v.name or v.guid or 'Unknown player') or col.key=='classToken' and (v.classToken or '—')
      or col.objective and (function() for _,o in ipairs(v.objectives or {}) do if o[1]==col.objective then return Number(o[2]) end end;return '—' end)() or Number(v[col.key])
    label:SetText(value);label:SetJustifyH(i<=2 and 'LEFT' or 'RIGHT')
   end
  end
  local details={v.guid or 'GUID unavailable','Recorded row '..item.index,'Faction code: '..tostring(v.faction or 'unknown')}
  for _,o in ipairs(v.objectives or {}) do details[#details+1]=(o[4]~=false and o[4] or o[9]~=false and o[9] or 'Objective '..o[1])..': '..Number(o[2]) end
  T.Tooltip(row,v.name or 'Scoreboard player',table.concat(details,'\n'))
 end)
 function f:Render()
  local r=self.board;local rows=B.Rows(r);self.columns={{key='name',title='Player',x=0,w=225},{key='classToken',title='Class',x=225,w=115}}
  local specs=self.columnsMode=='objectives' and {} or {{'killingBlows','KB'},{'honorableKills','HK'},{'deaths','Deaths'},{'damageDone','Damage'},{'healingDone','Healing'},{'honorGained','Honor'}}
  if self.columnsMode=='objectives' then
   local seen={};for _,row in ipairs(rows) do for _,o in ipairs(row.values.objectives or {}) do if not seen[o[1]] then
    seen[o[1]]=true;specs[#specs+1]={o[1],o[4]~=false and o[4] or o[9]~=false and o[9] or 'Objective '..o[1]}
   end end end
  end
  -- Every objective stays accessible in each row's tooltip; six fit on a folio.
  for n=1,math.min(6,#specs) do local spec=specs[n];local w=720/math.min(6,#specs)
   self.columns[#self.columns+1]={key=self.columnsMode~='objectives' and spec[1] or nil,objective=self.columnsMode=='objectives' and spec[1] or nil,title=spec[2],x=340+(n-1)*w,w=w}
  end
  for n,col in ipairs(self.columns) do
   local h=self.headers[n];if not h then h=V.Button(self,'',0,0,100,28,function(button)
    local key=button.column;self.sortKey=self.sortKey==key and nil or key;self:Render()
   end,'neutral');self.headers[n]=h end
   h.column=col.key;h:ClearAllPoints();h:SetPoint('TOPLEFT',18+col.x,-124);h:SetWidth(col.w-6);h:SetText(col.title);h:Show()
  end
  for n=#self.columns+1,#self.headers do self.headers[n]:Hide() end
  if self.sortKey then local key=self.sortKey;table.sort(rows,function(a,b)
   local av,bv=a.values[key],b.values[key]
   if av==bv then return a.index<b.index end
   if type(av)=='number' and type(bv)=='number' then return av>bv end
   return tostring(av or '')<tostring(bv or '')
  end) end
  self.list:SetItems(rows)
  self.title:SetText((r and r.instanceName or 'Captured scoreboard')..' • '..#rows..' players')
  self.status:SetText(r and ((B.Complete(r) and 'All '..r.expectedRows..' native positions captured' or 'Partial board • '..#rows..' readable rows'..(r.expectedRows and ' of '..r.expectedRows or ''))..' • '..(r.phase or 'Legacy observation')..'\nObserved scores; final-result freshness is unverified. Hover a row for full objective details.') or 'No scoreboard was available for this event.')
  self.match:SetEnabled(B.Activity(self.state,r)~=nil)
 end
 function f:Present(st,reports,selected)
  self.state=st;self.reports=reports or {};self.board=selected or self.reports[1];self.sortKey=nil
  for n=#self.choices,2,-1 do self.choices[n]=nil end
  for _,r in ipairs(self.reports) do self.choices[#self.choices+1]={r.id,(r.instanceName or 'Match')..' • '..(ns.SafeCall(date,'%H:%M:%S',r.lastAt) or tostring(r.lastAt))..' • '..#B.Rows(r)..' rows'} end
  self.select:Refresh();self:Render();self:Show()
 end
 return f
end
