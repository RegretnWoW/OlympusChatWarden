-- Addon-owned attached lane. No secure row mutation, search API or native sort.
local _,ns=...
local R,V=ns.Athena2,ns.Art
local U={VERSION=1};ns.NativeLFGOverlay=U
function U.Attach(anchor,adapter,viewer,validation)
 if not R.Permit('intel') or not anchor then return nil,'NO_SAFE_ANCHOR' end
 local simulated=validation=='ISOLATED_SIMULATOR' and WARDEN_SIMULATOR_ISOLATED==true and ns.WardenSimLab and ns.WardenSimLab.Enabled()
 if not simulated then return nil,'NATIVE-PENDING: no native public row/anchor extension validated' end
 local p=anchor.OlympusMatchLane
 if not p then
  p=CreateFrame('Frame',nil,anchor);p:SetSize(330,280);p:SetPoint('TOPLEFT',anchor,'TOPRIGHT',8,0);p:SetFrameLevel(anchor:GetFrameLevel()+5)
  local bg=p:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();bg:SetColorTexture(.035,.06,.085,.98)
  V.Text(p,'Athena · Top Matches',14,-12,300,18,V.gold)
  p.note=V.Text(p,'Synthetic adapter · native ordering unchanged',14,-40,300,11,V.muted);p.note:SetHeight(30)
  p.rows={};for i=1,3 do local row=V.Button(p,'',12,-82-(i-1)*50,306,44,function(self) if self.key then ns.AthenaSuiteUI.Group(self.key,p.adapter,p.viewer) end end,'row')
   row.label=V.Text(row,'',10,-8,286,12,V.gold);row.label:SetHeight(30);p.rows[i]=row
  end
  V.Button(p,'Explain selected match',12,-239,306,30,function() if p.rows[1].key then ns.AthenaSuiteUI.Group(p.rows[1].key,p.adapter,p.viewer) end end,'neutral')
  anchor.OlympusMatchLane=p
 end
 p.adapter=adapter;p.viewer=viewer
 local rows=adapter:Rank(viewer,true)
 for i,row in ipairs(p.rows) do local item=rows[i];row.key=item and item.key;row:SetEnabled(item~=nil);row.label:SetText(item and ((item.match.score and item.match.score..'% Match' or item.match.state)..' · '..(item.listing.activityName or 'Native activity')) or 'No current result') end
 p:Show();return p
end
