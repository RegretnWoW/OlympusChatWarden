local _,ns=...
local U={};ns.AthenaRecollectionsUI=U
local V,R=ns.Art,ns.AthenaRecollections
function U.Attach(p)
 local f=V.Panel(p,0,0,620,430,'dark');p.recollectionEditor=f;f:SetFrameLevel(p:GetFrameLevel()+70);f:Hide();f:EnableMouse(true)
 f.title=V.Text(f,'Athena’s Recollections',20,-16,560,22,V.gold)
 f.status=V.Text(f,'Your perspective • private to this character',20,-45,560,13,V.muted);f.status:SetHeight(32)
 f.choices={{false,'Choose a moment'}}
 f.select=V.Dropdown(f,20,-82,580,f.choices,function() return p.recollectionSelected or false end,function(key) p:SelectRecollection(key) end,{maxRows=8})
 f.question=V.Text(f,'What do you remember about this moment?',20,-122,580,15,V.gold);f.question:SetHeight(48)
 f.text,f.textBox=V.Edit(f,20,-172,580,112,'Your words, as you want them remembered',nil,true);f.text:SetMaxLetters(2000)
 f.feeling=V.Dropdown(f,20,-296,280,{{'unsaid','How did it feel? (optional)'},{'joyful','Joyful'},{'difficult','Difficult'},{'tense','Tense'},{'funny','Funny'},{'mixed','Mixed'},{'quiet','Quiet'}},function() return p.recollectionFeeling or 'unsaid' end,function(v) p.recollectionFeeling=v end)
 f.company=V.Dropdown(f,312,-296,288,{{'unsaid','How was the company? (optional)'},{'welcoming','Welcoming'},{'strained','Strained'},{'quiet','Quiet'},{'alone','I felt alone'}},function() return p.recollectionCompany or 'unsaid' end,function(v) p.recollectionCompany=v end)
 f.save=V.Button(f,'Save recollection',20,-344,190,30,function()
  local target=p.recollectionTargets and p.recollectionTargets[p.recollectionSelected]
  local ok,why=R.Save(p.provider,p.owner,target,{text=f.text:GetText(),feeling=p.recollectionFeeling,company=p.recollectionCompany})
  if not ok then f.status:SetText(why);return end
  local generate=p.recollectionBeforeGenerate;f:Hide();f.text:SetText('');p.recollectionBeforeGenerate=nil
  if generate then p:Regenerate(true) else p:Recompose() end
 end,'primary')
 f.skip=V.Button(f,'Skip and generate',222,-344,190,30,function()
  local generate=p.recollectionBeforeGenerate;f:Hide();f.text:SetText('');p.recollectionBeforeGenerate=nil
  if generate then p:Regenerate(true) end
 end,'neutral')
 f.delete=V.Button(f,'Remove recollection',424,-344,176,30,function()
  local target=p.recollectionTargets and p.recollectionTargets[p.recollectionSelected]
  if R.Delete(p.provider,p.owner,target) then f:Hide();f.text:SetText('');p.recollectionBeforeGenerate=nil;p:Recompose() end
 end,'neutral')
 f.ask=V.Check(f,'Ask before I regenerate a telling',20,-392,ns.DB.journalAskRecollections~=false,function(v) ns.DB.journalAskRecollections=v==true end,550)
 f.close=V.Button(f,'X',566,-10,34,28,function() f:Hide();p.recollectionBeforeGenerate=nil;f.text:SetText('') end,'neutral')
 local questions={adventure='How did this run feel? What made the group or the adventure memorable?',guild='What does this guild mean to you? What would you like remembered?',friend='What would you like remembered about this connection?',group='What brought this company together? How did it feel to adventure with them?',combat='What do you remember about this stretch of fighting?',quest='What mattered to you about this task?'}
 function p:SelectRecollection(key)
  self.recollectionSelected=key;local target=self.recollectionTargets and self.recollectionTargets[key]
  local note=target and R.Get(self.provider,self.owner,target)
  self.recollectionFeeling=note and note.feeling or 'unsaid';self.recollectionCompany=note and note.company or 'unsaid'
  f.text:SetText(note and note.text or '');f.feeling:Refresh();f.company:Refresh()
  f.question:SetText(target and questions[target.kind] or 'Choose a moment from this part of your story.')
  f.delete:SetEnabled(note~=nil);f.save:SetEnabled(target~=nil)
 end
 function p:OpenRecollections(beforeGenerate)
  if not self.provider or not self.provider:Allowed() or not R.Store(self.provider,self.owner) then return false end
  local plan=self.threadPlan
  if self.story then plan={index=self.library.index,owner=self.owner,episodes={self.story}} end
  local rows=self.activityTargets or R.Targets(plan);if #rows==0 then return false end
  self.recollectionTargets={};for i=#f.choices,2,-1 do f.choices[i]=nil end
  for i,row in ipairs(rows) do self.recollectionTargets[row.ref]=row;f.choices[#f.choices+1]={row.ref,tostring(i)..'. '..row.label} end
  self.recollectionBeforeGenerate=beforeGenerate==true;f.skip:SetText(beforeGenerate and 'Skip and generate' or 'Close')
  f.save:SetText(beforeGenerate and 'Save and generate' or 'Save recollection')
  f.status:SetText('Optional • your words stay private and are attributed to you. Leave any answer open.')
  self:SelectRecollection(rows[1].ref);f.select:Refresh();f:Show();return true
 end
 local function Layout()
  local w=math.min(620,math.max(500,p:GetWidth()-32));f:ClearAllPoints();f:SetPoint('CENTER',p,'CENTER',0,0);f:SetSize(w,430)
  for _,control in ipairs({f.select,f.textBox,f.question,f.status}) do control:SetWidth(w-40) end
  f.close:ClearAllPoints();f.close:SetPoint('TOPRIGHT',-14,-10)
  local third=(w-64)/3
  for i,b in ipairs({f.save,f.skip,f.delete}) do b:ClearAllPoints();b:SetPoint('TOPLEFT',20+(i-1)*(third+12),-344);b:SetWidth(third) end
  f.feeling:SetWidth((w-52)/2);f.company:ClearAllPoints();f.company:SetPoint('TOPLEFT',26+(w-40)/2,-296);f.company:SetWidth((w-52)/2)
 end
 p:HookScript('OnSizeChanged',Layout);p:HookScript('OnHide',function() f:Hide();f.text:SetText('');p.recollectionBeforeGenerate=nil end)
 Layout()
end
