-- One composer: caption, approved art and the existing shared stroke editor.
-- Publication still goes through AetherPosts' explicit immutable review step.
local _,ns=...
local S={VERSION=1};ns.WardenStudio=S
local B,D=ns.WardenComposition,ns.WardenDrawing
function S.Open(value,id)
 if not ns.Permissions.Decide('UIAccess')then return false,'OWNER_UI_REQUIRED'end
 if S.form then return S.form:ResetStudio(value,id)end
 local A,R,F,C=ns.AetherPosts,ns.AetherPostRooms,ns.UI2Forms,ns.UI2Components
 local recipe=value.composition and B.Copy(value.composition)or{version=1,catalog=3,layers={}};if not recipe then return false,'ART_RECIPE'end
 local editorOwner=ns.Chronicle.Owner();local drawer;local mode='pen';local selected=1;local undo,redo={},{};local artIds={};for key,a in pairs(B.catalog)do if a.playerSafe then artIds[#artIds+1]=key end end;table.sort(artIds);local artAt=1
 local choices={};for _,r in ipairs(R.List())do choices[#choices+1]={r.id,r.category..' · '..r.title}end
 local function save(v)
  if editorOwner~=ns.Chronicle.Owner()then return false,'Character changed; reopen this owner’s draft before saving.'end
  local wire=drawer and drawer.editor:Save()or value.doodle;local data={body=v.body or'',spoiler=v.spoiler==true,tags=value.tags or{},parent=value.parent,editing=value.editing,event=value.event,privateSource=value.privateSource}
  data.room=(value.parent or value.editing)and value.room or v.room
  data.doodle=wire and wire~='WD1:'and wire or nil
  data.composition=(#recipe.layers>0 or recipe.base=='cover')and B.Copy(recipe)or nil
  local draft,why=A.SaveDraft(data,id);if not draft then return false,why end;if ns.WardenAudio then ns.WardenAudio.Play('draft.save')end;A.Open({view='drafts',draft=draft.id});return true,'Private artwork draft saved. Choose Publish to review a public snapshot.'
 end
 local f=F.Form({title=value.parent and'Reply · Agora Studio'or'Agora Studio',help='Write, arrange approved art and draw in one workspace. Creative artwork is not proof of an accomplishment. Private drafts stay private; Publish creates a reviewed, signed snapshot. Public bytes remain strictly bounded.',
  fields={{key='body',label='Caption · optional with artwork',value=value.body or'',limit=800,multiline=true,height=80},
   {key='room',label='Community room',value=value.room or'world',choices=choices,enabled=not value.parent and not value.editing},
   {key='spoiler',label='Spoilers',value=value.spoiler==true,choices={{false,'No'},{true,'Hide until opened'}}}},submitLabel='Save private draft',submit=save})
 if not f then return f end
 local body=f.scroll:GetScrollChild();local top=body:GetHeight()+10;body:SetHeight(top+600)
 drawer=D.Open({inline=true,parent=body,inlineY=top,limits=D.PUBLIC,wire=value.doodle,title='Canvas · pen, eraser or arrange',canDraw=function()return mode=='pen'and editorOwner==ns.Chronicle.Owner()end})
 f.studio={drawer=drawer,recipe=recipe};drawer.controls.Save:Hide();drawer.controls.Close:Hide()
 local canvas=drawer.canvas
 local function paint()
  f.studio.recipe=recipe;B.Render(canvas,recipe);D.Render(canvas,assert(drawer.editor:Save()))
  local n=#ns.ChronicleBackup.Encode({{body=f.inputs.body:GetText(),composition=recipe,doodle=drawer.editor:Save()}})
  f.status:SetText('Private draft · art '..#recipe.layers..' / '..B.MAX_LAYERS..' layers · preview '..n..' bytes; complete post limit '..A.MAX_POST_BYTES..' bytes. Signing adds an envelope.')
 end
 local function checkpoint()undo[#undo+1]={recipe=B.Copy(recipe),wire=drawer.editor:Save()};if #undo>20 then table.remove(undo,1)end;redo={}end
 local function restore(stack,other)
  local x=table.remove(stack);if not x then return end;other[#other+1]={recipe=B.Copy(recipe),wire=drawer.editor:Save()};recipe=x.recipe;drawer:SetWire(x.wire);paint()
 end
 drawer.controls.Undo:SetScript('OnClick',function()restore(undo,redo)end);drawer.controls.Redo:SetScript('OnClick',function()restore(redo,undo)end)
 local select;local picker
 select=C.Button(drawer,'Choose artwork',function()
  if picker then picker:SetShown(not picker:IsShown());return end
  picker=C.Card(f,'Approved artwork',false);picker:SetSize(560,440);picker:SetPoint('CENTER');picker:SetFrameStrata('TOOLTIP');picker:SetFrameLevel(f:GetFrameLevel()+60);picker:EnableMouse(true)
  local query=C.Edit(picker,390,'Find an illustration…');query:SetPoint('TOPLEFT',15,-42);query:SetMaxLetters(64)
  local close=C.Button(picker,'Close',function()picker:Hide()end,100);close:SetPoint('TOPRIGHT',-15,-42)
  local page=C.Page(picker);page:ClearAllPoints();page:SetPoint('TOPLEFT',15,-84);page:SetPoint('BOTTOMRIGHT',-15,48)
  local offset=1;local draw
  draw=function()
   local matched={};local filter=query:GetText():lower()
   for index,id in ipairs(artIds)do local a=B.catalog[id];if filter==''or a.title:lower():find(filter,1,true)or id:find(filter,1,true)then matched[#matched+1]={index=index,id=id,title=a.title}end end
   if offset>#matched then offset=1 end;local items={}
   for n=offset,math.min(#matched,offset+15)do local item=matched[n];items[#items+1]={title=item.title,height=34,activate=function()artAt=item.index;select:SetLabel(item.title);picker:Hide()end}end
   page:SetItems(items)
  end
  C.Button(picker,'Previous',function()offset=math.max(1,offset-16);draw()end,125):SetPoint('BOTTOMLEFT',15,10)
  C.Button(picker,'Next',function()offset=offset+16;draw()end,125):SetPoint('BOTTOMRIGHT',-15,10)
  query:SetScript('OnTextChanged',function()offset=1;draw()end);draw()
 end,180);select:SetPoint('BOTTOMRIGHT',-14,18)
 local function tool(label,n,fn)local b=C.Button(body,label,fn,102);b:SetPoint('TOPLEFT',(n-1)*108,-top+32);return b end
 tool('Add art',1,function()if #recipe.layers>=B.MAX_LAYERS then f.status:SetText('Layer limit reached. Remove one first; nothing was truncated.');return end;checkpoint();recipe.layers[#recipe.layers+1]={art=artIds[artAt],x=350,y=250,w=260,h=440};selected=#recipe.layers;paint()end)
 tool('Pen / arrange',2,function()mode=mode=='pen'and'arrange'or'pen';f.status:SetText('Mode: '..mode..' · drag the selected artwork in Arrange mode.')end)
 tool('Remove art',3,function()if recipe.layers[selected]then checkpoint();table.remove(recipe.layers,selected);selected=math.max(1,selected-1);paint()end end)
 tool('Rotate',4,function()local l=recipe.layers[selected];if l then checkpoint();l.rotation=((l.rotation or 0)+15+180)%360-180;paint()end end)
 tool('Fade',5,function()local l=recipe.layers[selected];if l then checkpoint();l.opacity=(l.opacity or 100)>30 and(l.opacity or 100)-20 or 100;paint()end end)
 tool('Layer up',6,function()if selected<#recipe.layers and recipe.layers[selected]then checkpoint();recipe.layers[selected],recipe.layers[selected+1]=recipe.layers[selected+1],recipe.layers[selected];selected=selected+1;paint()end end)
 local function lower(label,index,fn)local b=C.Button(body,label,fn,102);b:SetPoint('TOPLEFT',(index-1)*108,-top-490);return b end
 local function resize(delta)
  local l=recipe.layers[selected];if not l then return end;checkpoint()
  local width=math.max(80,math.min(800,l.w+delta));local height=math.max(80,math.min(900,l.h+delta))
  l.x=math.floor(math.max(0,math.min(1000-width,l.x+(l.w-width)/2)));l.y=math.floor(math.max(0,math.min(1000-height,l.y+(l.h-height)/2)));l.w=width;l.h=height;paint()
 end
 lower('Smaller',1,function()resize(-50)end);lower('Larger',2,function()resize(50)end)
 lower('Tint',3,function()local l=recipe.layers[selected];if l then checkpoint();l.tint=(l.tint or 0)%8+1;paint()end end)
 lower('Art stage',4,function()local l=recipe.layers[selected];if l and B.catalog[l.art].activity then checkpoint();l.stage=(l.stage or 1)%6+1;paint()end end)
 lower('Layer down',5,function()if selected>1 and recipe.layers[selected]then checkpoint();recipe.layers[selected],recipe.layers[selected-1]=recipe.layers[selected-1],recipe.layers[selected];selected=selected-1;paint()end end)
 local inscription=C.Edit(body,420,'Short artwork inscription');inscription:SetPoint('TOPLEFT',0,-top-530);inscription:SetMaxLetters(B.MAX_TEXT)
 lower('Add text',6,function()
  local text=inscription:GetText();if text==''or #text>B.MAX_TEXT or text:find('[|%z\1-\31]')or #recipe.layers>=B.MAX_LAYERS then return end
  checkpoint();recipe.layers[#recipe.layers+1]={art='nameplate',text=text,x=180,y=750,w=640,h=130};selected=#recipe.layers;paint()
 end)
 local function point()
  local x,y=GetCursorPosition();local scale=canvas:GetEffectiveScale();return(x/scale-canvas:GetLeft())/canvas:GetWidth(),(canvas:GetTop()-y/scale)/canvas:GetHeight()
 end
 canvas:HookScript('OnMouseDown',function(_,button)
  if button~='LeftButton'or editorOwner~=ns.Chronicle.Owner()then return end;checkpoint()
  if mode=='pen'then return end
  local u,v=point();for i=#recipe.layers,1,-1 do local l=recipe.layers[i];if u*1000>=l.x and u*1000<=l.x+l.w and v*1000>=l.y and v*1000<=l.y+l.h then selected=i;break end end
  local l=recipe.layers[selected];if not l then return end;local dx,dy=u*1000-l.x,v*1000-l.y
  canvas:SetScript('OnUpdate',function()local x,y=point();l.x=math.floor(math.max(0,math.min(1000-l.w,x*1000-dx)));l.y=math.floor(math.max(0,math.min(1000-l.h,y*1000-dy)));paint()end)
 end)
 canvas:HookScript('OnMouseUp',function()canvas:SetScript('OnUpdate',nil);paint()end)
 f:HookScript('OnHide',function()drawer:Hide();canvas:SetScript('OnUpdate',nil);if picker then picker:Hide()end end)
 function f:ResetStudio(nextValue,nextID)
  local nextRecipe=nextValue.composition and B.Copy(nextValue.composition)or{version=1,catalog=3,layers={}};if not nextRecipe then return false,'ART_RECIPE'end
  if F.active and F.active~=self then F.active:Hide()end
  value,id=nextValue,nextID;recipe=nextRecipe;undo,redo={},{};selected=1;mode='pen';editorOwner=ns.Chronicle.Owner()
  self.completed=nil;self.dirty=false;self.values.body=value.body or'';self.values.room=value.room or'world';self.values.spoiler=value.spoiler==true
  self.inputs.body:SetText(self.values.body);self.inputs.room:SetLabel(R.Get(self.values.room).title);self.inputs.room:SetEnabled(not value.parent and not value.editing);self.inputs.spoiler:SetLabel(value.spoiler and'Hide until opened'or'No')
  local ok,why=drawer:SetWire(value.doodle or'WD1:');if not ok then return false,why end
  self.scroll:SetVerticalScroll(0);F.active=self;self:Show();drawer:Show();if F.escapeFrame then F.escapeFrame:Show()end;paint();return self
 end
 function f:ClearPrivateStudio()
  self:Hide();value={};id=nil;editorOwner=nil;recipe={version=1,catalog=3,layers={}};undo,redo={},{};selected=1
  self.values.body='';self.inputs.body:SetText('');drawer:SetWire('WD1:');self.studio.recipe=recipe
  for _,field in ipairs(self.spec.fields)do if field.key=='body'then field.value=''end end
  B.Render(canvas,recipe)
 end
 S.form=f
 paint();return f
end
function S.ShareCover()
 local recipe=ns.WardenMementos.Snapshot(ns.Chronicle.Owner());if not recipe then return false,'OWN_COVER_REQUIRED'end
 return ns.AetherPosts.Composer({body='',room='world',spoiler=false,tags={'art'},composition=recipe})
end
function S.ShareArtifact(item)
 if not item or not item.art then return false,'ARTIFACT_REQUIRED'end
 local earned;for _,b in ipairs(ns.WardenMementos.Inventory(ns.Chronicle.Owner()))do if b.art==item.art then earned=b;break end end
 if not earned then return false,'OWN_ARTIFACT_REQUIRED'end
 local recipe={version=1,catalog=3,base='collection',layers={{art=earned.art,stage=earned.stage,charms=ns.Athena.Copy(earned.charms),x=180,y=80,w=640,h=840}}}
 return ns.AetherPosts.Composer({body='',room='world',spoiler=false,tags={'art'},composition=recipe})
end
function S.InspectArtifact(item)
 if not item or not ns.WardenComposition.catalog[item.art]then return false end
 local f=S.inspector
 if not f then
  f=ns.UI2Forms.Form({title='An Athena keepsake',help='An evolving cosmetic record of observed activity. This artwork does not certify a whole-instance clear or ownership of a depicted item.',fields={},cancelLabel='Close'})
  if not f then return end;f:SetHeight(680);local body=f.scroll:GetScrollChild();body:SetHeight(410)
  f.art=CreateFrame('Frame',nil,body);f.art:SetSize(340,340);f.art:SetPoint('TOP',0,-5)
  local action=ns.UI2Components.Button(f,'Share artwork',function()local current=f.item;f:Hide();S.ShareArtifact(current)end,180);action:SetPoint('BOTTOMLEFT',20,18);f.share=action;S.inspector=f
  f.previewStage=0;local preview=ns.UI2Components.Button(f,'Preview next stage',function()
   f.previewStage=f.previewStage%6+1;local item=f.item;f.title:SetText('Visual preview · '..B.stages[f.previewStage]..' · Earned '..B.stages[item.stage or 1]);B.Render(f.art,{version=1,catalog=3,layers={{art=item.art,stage=f.previewStage,charms=item.charms or{},x=0,y=0,w=1000,h=1000}}})
  end,190);preview:SetPoint('BOTTOMRIGHT',-20,18)
 end
 if not f.provenance then local body=f.scroll:GetScrollChild();f.provenance=body:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');f.provenance:SetPoint('TOPLEFT',10,-350);f.provenance:SetWidth(450);f.provenance:SetJustifyH('LEFT')end
 local lines={item.commemoration or'', 'Personal memories · source IDs stay in your private inspection:'}
 for _,memory in ipairs(item.memories or{})do lines[#lines+1]=memory.title..(memory.criterion and' · '..memory.criterion or'')..' · '..memory.ref..(memory.eventRef and' · '..memory.eventRef or'')..(memory.firstObserved and' · '..tostring(memory.firstObserved)or' · date unavailable')end
 local activity=ns.WardenActivityArt.byID[item.art];local unlocked={};for _,memory in ipairs(item.memories or{})do unlocked[memory.key]=true end
 for _,memory in ipairs(activity and activity.memories or{})do
  local _,criterion=ns.WardenMementos.KeepsakeCriterion(item,memory.criterion)
  lines[#lines+1]=(unlocked[memory.key]and'Unlocked · 'or'Locked · ')..memory.title..' · '..criterion
 end
 f.provenance:SetText(table.concat(lines,'\n'));f.scroll:GetScrollChild():SetHeight(400+#lines*40)
 f.item=ns.Athena.Copy(item);f.previewStage=0;f.title:SetText(item.title..' · '..B.stages[item.stage or 1]);f.share:SetShown(item.owner==nil or item.owner==ns.Chronicle.Owner())
 local view={version=1,catalog=3,layers={{art=item.art,stage=item.stage or 1,charms=item.charms or{},x=0,y=0,w=1000,h=1000}}};local change=ns.WardenMementos.TakeEvolution(ns.Chronicle.Owner(),item.key);if change then B.Animate(f.art,view,change.from,change.to)else B.Render(f.art,view)end
 if ns.UI2Forms.active and ns.UI2Forms.active~=f then ns.UI2Forms.active:Hide()end;ns.UI2Forms.active=f;f:Show();return f
end
function S.ShareCollection()
 local f=S.collectionForm;local F,C=ns.UI2Forms,ns.UI2Components
 if not f then
  f=F.Form({title='Choose keepsakes to share',help='Select up to twelve current artifacts. This freezes only their artwork; source records and future changes remain private. Continue opens Agora Studio for caption, drawing and explicit publication review.',fields={},submitLabel='Continue to Studio',submit=function()
   if f.owner~=ns.Chronicle.Owner()then return false,'Character changed. Reopen this selection.'end
   local layers={};for _,item in ipairs(f.inventory)do if f.selected[item.art]then
    local n=#layers;layers[n+1]={art=item.art,stage=item.stage,charms=ns.Athena.Copy(item.charms),x=n%3*333+10,y=math.floor(n/3)*250+10,w=313,h=230}
   end end
   if #layers==0 then return false,'Choose at least one keepsake.'end
   S.Open({body='',room='world',spoiler=false,tags={'art'},composition={version=1,catalog=3,base='collection',layers=layers}});return true
  end})
  if not f then return end;S.collectionForm=f;f:SetHeight(690)
  local body=f.scroll:GetScrollChild();body:SetHeight(430);f.page=C.Page(body);f.page:ClearAllPoints();f.page:SetAllPoints()
  function f:RefreshSelection()
   local rows={};for _,item in ipairs(self.inventory)do rows[#rows+1]={title=(self.selected[item.art]and'✓ 'or'+ ')..item.title,detail=B.stages[item.stage],height=40,activate=function()
    if self.selected[item.art]then self.selected[item.art]=nil else local count=0;for _ in pairs(self.selected)do count=count+1 end;if count>=B.MAX_LAYERS then self.status:SetText('Twelve selected. Remove a selection before adding another; nothing was truncated.');return end;self.selected[item.art]=true end
    self:RefreshSelection()
   end}end;self.page:SetItems(rows)
  end
 end
 f.owner=ns.Chronicle.Owner();f.inventory=ns.WardenMementos.Inventory(f.owner);f.selected={};f.status:SetText('');f.completed=nil;f:RefreshSelection()
 if F.active and F.active~=f then F.active:Hide()end;F.active=f;f:Show();return f
end
function S.NewBanner()
 return S.Open({body='',room='world',spoiler=false,tags={'art'},composition={version=1,catalog=3,base='banner',layers={{art='banner',x=240,y=0,w=520,h=1000}}}})
end
function S.ResetPrivacyRuntime()
 if S.form then S.form:ClearPrivateStudio()end
 if S.inspector then S.inspector:Hide();S.inspector.item=nil;B.Render(S.inspector.art,{version=1,catalog=3,layers={}})end
 if S.collectionForm then local f=S.collectionForm;f:Hide();f.inventory={};f.selected={};f.owner=nil;f.page:SetItems({})end
 S.galleryCache=nil
end
function S.GalleryRows(guid)
 local rows={};local A=ns.AetherPosts;local c=ns.AetherNet.Cached()
 local own=guid==ns.PlayerCard.Own()
 if own then
  rows[#rows+1]={title='Athena’s Sanctuary',detail='Companions, standards and a fully animated preview',activate=function()ns.WardenSanctuary.OpenCollection()end,height=52,stacked=true}
  rows[#rows+1]={title='Share your cover',detail='Exterior only · review a frozen snapshot in Agora Studio',activate=S.ShareCover,height=52,stacked=true}
  rows[#rows+1]={title='Arrange your keepsakes',detail='Your private home shelf showcase',activate=function()ns.UI2.Open({page='journey'});local p=ns.UI2.journalHost and ns.UI2.journalHost.reader;if p then p:OpenBookbinder()end end,height=48}
  rows[#rows+1]={title='Share selected keepsakes',detail='Choose a frozen artwork collection',activate=S.ShareCollection,height=48}
  rows[#rows+1]={title='Make a commemorative banner',detail='Creative artwork · no game or accomplishment claim',activate=S.NewBanner,height=48}
  local inventory=ns.WardenMementos.Inventory(ns.Chronicle.Owner())
  for i=1,math.min(6,#inventory)do local item=inventory[i]
   rows[#rows+1]={composition={version=1,catalog=3,layers={{art=item.art,stage=item.stage,charms=item.charms,x=0,y=0,w=1000,h=1000}}},height=160}
   rows[#rows+1]={title=item.title,detail=B.stages[item.stage]..' · inspect or deliberately share this artwork',activate=function()S.InspectArtifact(item)end,height=46,stacked=true}
  end
 end
 if c then
  local ix=A.Index(c);local found={}
  for _,row in ipairs(ix.rows)do
   if not row.record.removed and row.record.data.composition and({cover=true,collection=true,banner=true})[row.record.data.composition.base]then
    local p=A.Projection(c,row,ix,math.floor(ns.SafeCall(GetServerTime)or 0))
    local visible=A.Get(c,p.postID)
    if visible and p.authorGUID==guid then found[#found+1]=p end
   end
  end
  table.sort(found,function(a,b)return a.updatedAt>b.updatedAt end)
  for i=1,math.min(6,#found)do local p=found[i]
   rows[#rows+1]={composition=B.Copy(p.composition),height=260}
   rows[#rows+1]={title=p.composition.base=='cover'and'Published cover artwork'or'Published keepsake artwork',detail='A frozen, author-shared composition · no private sources or inside pages',activate=function()A.Open({room=p.room,post=p.postID})end,height=48}
  end
  if #found==0 then rows[#rows+1]={title='No shared artwork retained',detail='Private books and drawings are never uploaded automatically.',height=54,stacked=true}end
 end
 return rows
end
