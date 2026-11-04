-- UI2-owned input/confirmation components. These never build legacy panels.
local _,ns=...
local F={serial=0,drafts={}};ns.UI2Forms=F
local C=ns.UI2Components
function F.RouteKey(route)
 route=route or ns.UI2.route or {};return (route.page or '')..'/'..tostring(route.category or route.subsection or '')
end
function F.Feedback(ok,why,origin)
 if origin and origin~=F.RouteKey() then return ok,why end
 ns.UI2.feedback=why or (ok and 'Saved.' or 'The change was not accepted.')
 ns.UI2.feedbackRoute=F.RouteKey()
 if ns.UI2.window then ns.UI2.Refresh(true) end
 return ok,why
end
function F.Close(f) if f then f:Hide() end end
function F.Form(spec)
 if not ns.Membership.Allowed() and not spec.privacy then ns.UI2.ShowVerification();return false end
 local U=ns.UI2;U.Ensure();if F.active then F.active:Hide() end
 F.serial=F.serial+1
 local helpHeight=math.max(40,math.ceil(#(spec.help or '')/78)*19)
 local fieldsHeight=0;for _,field in ipairs(spec.fields or {}) do fieldsHeight=fieldsHeight+42+(field.multiline and (field.height or 110) or 32) end
 for _,paragraph in ipairs(spec.paragraphs or {}) do fieldsHeight=fieldsHeight+math.max(28,math.ceil(#paragraph/76)*19)+12 end
 local owner=spec.owner or U.window
 local f=C.Card(owner,spec.title or 'Edit',false);f:SetSize(720,math.min(owner:GetHeight()-28,810,math.max(300,helpHeight+156+fieldsHeight)));f:SetPoint('CENTER');f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetFrameLevel(100);f:EnableMouse(true)
 ns.Theme.RegisterModal(f,owner)
 if not owner.ChatWardenModalHideHook then owner.ChatWardenModalHideHook=true;owner:HookScript('OnHide',function()if F.active and F.active.ChatWardenModalOwner==owner then F.active:Hide()end end)end
 f.spec=spec;f.inputs={};f.values={};f.dirty=false
 function f:ReadInputs()
  local changed=false
  for _,field in ipairs(self.spec.fields or {}) do local input=self.inputs[field.key]
   if input and not field.choices and not field.readOnly then local value=input:GetText();if self.values[field.key]~=value then self.values[field.key]=value;changed=true end end
  end
  return changed
 end
 local old=spec.draftKey and F.drafts[spec.draftKey]
 local help=C.Text(f,spec.help or '',12,C.colors.muted);help:SetPoint('TOPLEFT',20,-46);help:SetPoint('TOPRIGHT',-20,-46);help:SetHeight(helpHeight);help:SetWordWrap(true);f.help=help
 local scroll=CreateFrame('ScrollFrame',nil,f);scroll:SetPoint('TOPLEFT',20,-(helpHeight+56));scroll:SetPoint('BOTTOMRIGHT',-25,102);scroll:EnableMouseWheel(true)
 local body=CreateFrame('Frame',nil,scroll);body:SetSize(665,1);scroll:SetScrollChild(body);f.scroll=scroll
 scroll:SetScript('OnMouseWheel',function(self,d) self:SetVerticalScroll(math.max(0,math.min(math.max(0,body:GetHeight()-self:GetHeight()),self:GetVerticalScroll()-d*48))) end)
 local at=0
 local function changed(field,value)
  f.values[field.key]=value;f.dirty=true
  if spec.draftKey then F.drafts[spec.draftKey]=f.values end
  if spec.changed then local ok,why=spec.changed(f.values,field.key);if ok==false then f.status:SetText(why or 'Not saved.') end end
 end
 for _,field in ipairs(spec.fields or {}) do
  local key=field.key;local value=old and old[key];if value==nil then value=field.value end;if value==nil then value='' end;f.values[key]=value
  local label=C.Text(body,field.label or key,13);label:SetPoint('TOPLEFT',0,-at);label:SetSize(650,22)
  local input
  if field.choices then
   input=C.Button(body,'',function(self)
    local menu=self.menu
    if menu and menu:IsShown() then menu:Hide();return end
    if not menu then
     menu=C.Card(f,'Choose '..(field.label or key),false);self.menu=menu;menu:SetFrameStrata('TOOLTIP');menu:SetSize(420,math.min(620,50+#field.choices*33));menu:SetPoint('CENTER');menu:EnableMouse(true)
     local page=C.Page(menu);menu.page=page;page:ClearAllPoints();page:SetPoint('TOPLEFT',8,-38);page:SetPoint('BOTTOMRIGHT',-8,8)
     local items={};for _,choice in ipairs(field.choices) do local id,title=choice[1],choice[2];items[#items+1]={title=title,height=33,activate=function() changed(field,id);self:SetLabel(title);menu:Hide() end} end;page:SetItems(items)
    end
    menu:Show()
   end,650)
   local title=tostring(value);for _,choice in ipairs(field.choices) do if choice[1]==value then title=choice[2] end end;input:SetLabel(title)
  else
   input=C.Edit(body,650,field.placeholder or '');input:SetMaxLetters(field.limit or 512);input.ChatWardenNoSpelling=field.code==true;input:SetMultiLine(field.multiline==true);input:SetText(tostring(value));input:SetAutoFocus(false)
   if field.multiline then input:SetFont('Fonts\\FRIZQT__.TTF',13,'');input:SetTextInsets(8,8,5,5) end
   input:SetScript('OnTextChanged',function(self) if self.hint then self.hint:SetShown(self:GetText()=='') end;if not field.readOnly then changed(field,self:GetText()) end end)
   if field.readOnly then input:SetScript('OnEditFocusGained',function(self) self:HighlightText() end) end
  end
  input:SetPoint('TOPLEFT',0,-at-24);input:SetSize(650,field.multiline and (field.height or 110) or 32);input:SetEnabled(field.enabled~=false)
  f.inputs[key]=input;at=at+24+input:GetHeight()+18
 end
 for _,paragraph in ipairs(spec.paragraphs or {}) do
  local text=C.Text(body,paragraph,13);local height=math.max(28,math.ceil(#paragraph/76)*19)
  text:SetPoint('TOPLEFT',0,-at);text:SetSize(650,height);text:SetWordWrap(true);at=at+height+12
 end
 body:SetHeight(math.max(1,at))
 f.status=C.Text(f,'',12,C.colors.blue);f.status:SetPoint('BOTTOMLEFT',20,55);f.status:SetPoint('BOTTOMRIGHT',-20,55);f.status:SetHeight(38);f.status:SetWordWrap(true)
 local submit=C.Button(f,spec.submitLabel or 'Save',function()
  f:ReadInputs()
  local ok,why=spec.submit(f.values,f)
  if ok then f.completed=true;if spec.draftKey then F.drafts[spec.draftKey]=nil end;f:Hide();F.Feedback(true,why) else f.status:SetText(why or 'Check the entered values. Nothing was changed.') end
 end,200);submit:SetPoint('BOTTOMLEFT',20,18);f.submit=submit;submit:SetShown(spec.submit~=nil)
 C.Button(f,spec.cancelLabel or 'Cancel',function() f:Hide() end,130):SetPoint('BOTTOMRIGHT',-20,18)
 f:SetScript('OnHide',function()
  local changed=f:ReadInputs()
  if not f.completed then
   if spec.draftKey then F.drafts[spec.draftKey]=f.values end
   if changed and spec.changed then local ok,why=spec.changed(f.values);if ok==false then U.feedback=why or 'The last draft edit could not be saved.' end end
   if spec.cancel then spec.cancel(f.values) end
  end
  for _,input in pairs(f.inputs) do if input.menu then input.menu:Hide() end end;if F.active==f then F.active=nil end
 end)
 f.escape=function() f:Hide() end
 -- A single named Escape target hides only the top UI2 modal.
 if not F.escapeFrame then F.escapeFrame=CreateFrame('Frame','OlympusUI2ModalEscape',U.window);F.escapeFrame:Hide();F.escapeFrame:SetScript('OnHide',function() if F.active then F.active:Hide() end end);if UISpecialFrames then table.insert(UISpecialFrames,'OlympusUI2ModalEscape') end end
 F.active=f;F.escapeFrame:Show();f:Show();return f
end
function F.Confirm(title,help,action,actionLabel)
 -- Confirmations all have the same fixed shape. Reuse their widgets instead
 -- of permanently allocating another frame tree on every toggle/delete.
 -- A confirmation executing its callback is never reused: that callback may
 -- legitimately open a second review before the first one returns.
 if F.active then F.active:Hide() end
 F.confirmations=F.confirmations or {}
 local f
 for _,candidate in ipairs(F.confirmations) do if not candidate.confirmRunning and not candidate:IsShown() then f=candidate;break end end
 if not f then
  local dialog
  dialog=F.Form({title=title,help=help,fields={},submitLabel='Confirm',cancelLabel='Cancel',submit=function()
   local callback=dialog.confirmAction;dialog.confirmRunning=true
   local ok,result,why=pcall(callback);dialog.confirmRunning=nil
   if not ok then error(result,0) end
   return result,why
  end})
  f=dialog;F.confirmations[#F.confirmations+1]=f
 else
  local height=math.max(40,math.ceil(#(help or '')/78)*19)
  f.completed=nil;f.dirty=false;f.status:SetText('');f.title:SetText(title);f.spec.title=title;f.spec.help=help
  f.help:SetText(help or '');f.help:SetHeight(height)
  f:SetHeight(math.min(ns.UI2.window:GetHeight()-28,810,math.max(300,height+156)))
  f.scroll:ClearAllPoints();f.scroll:SetPoint('TOPLEFT',20,-(height+56));f.scroll:SetPoint('BOTTOMRIGHT',-25,102);f.scroll:SetVerticalScroll(0)
  F.active=f;F.escapeFrame:Show();f:Show()
 end
 f.confirmAction=action;f.submit:SetLabel(actionLabel or 'Confirm')
 return f
end
function F.Value(title,value,set,help,options)
 options=options or {};return F.Form({title=title,help=help,fields={{key='value',label=title,value=value,choices=options.choices,limit=options.limit,multiline=options.multiline,code=options.code}},submit=function(v) return set(v.value) end})
end
function F.Copy(title,text,help)
 return F.Form({title=title,help=help or 'Select the text and press Ctrl+C. Nothing is sent.',fields={{key='copy',label='Copy text',value=text,limit=math.max(512,#(text or '')),multiline=true,height=380,readOnly=true,code=true}},cancelLabel='Done'})
end
function F.Row(id,title,get,set,options)
 options=options or {};local value=get();local detail=options.boolean and (value and 'On' or 'Off') or tostring(value or 'Not selected')
 if options.choices then for _,choice in ipairs(options.choices) do if choice[1]==value then detail=choice[2] end end end
 local row={id=id,title=title,detail=detail,height=44,activate=function()
  local function apply(v) local ok,why=set(v);if ok==nil then ok=true end;return ok,why end
  if options.boolean then F.Feedback(apply(not get()))
  else F.Value(title,get(),apply,options.help,options) end
 end}
 return row
end
