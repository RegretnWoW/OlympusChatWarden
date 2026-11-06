-- Optional public adapter to the existing local Scene Editor. No private source
-- or separate persistence store: normal Set/Save/Undo/Export own every change.
local _,ns=...
local F,N,C=ns.Fireside3D,ns.WardenNativeScene,ns.WardenSceneObjectControls
local H=F.Hitboxes;local T={};F.HitboxEditor=T
local function editor()return ns.WardenSceneEditor end
local function clamp(n,a,b)return math.max(a,math.min(b,n))end
local function message(s)local e=editor();if e and e.Message then e.Message(s)end end
function T.Target(v)
 local e=editor();if not F.EditorCamera.Active(v)then return nil,'Open the scene editor first'end
 local r,row=e.Value(e.scene,e.selected)
 local a=row and row.kind=='native'and row.engine.actors[row.id]
 if not r or not a or not a.ready or not a.bounds or not a.position or a.retired or a.editorHidden then return nil,'Select a visible, loaded 3D object in the main editor'end
 if N.IsPerson(a)then return nil,'Select a prop; character navigation uses its existing radius'end
 return{record=r,row=row,actor=a,id=e.selected,scene=e.scene}
end
function T.Allowed(v)
 local e=editor()
 return F.EditorCamera.Active(v)and not ns.UI2.locked and not ns.MainStorageBlocked and not InCombatLockdown()
  and not(e.dragging or e.popup and e.popup:IsShown())and not(GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())
end
function T.Hover(v)
 local s=v.world3DHitboxTool;return s and s.panel:IsVisible()and s.panel:IsMouseOver()or false
end
function T.Commit(v,target,kind,boxes,noHistory,automatic)
 if not T.Allowed(v)or editor().scene~=target.scene or editor().selected~=target.id then return false,'Select the same object with no form open'end
 local r=H.Copy(target.record)
 if automatic then r[kind]=nil else
  local valid,why=H.Validate(kind,{enabled=true,boxes=boxes});if not valid then return false,why end;r[kind]=valid
 end
 return editor().Set(target.id,r,noHistory)
end
function T.Command(v,command)
 local s=v.world3DHitboxTool;if not s or not T.Allowed(v)then return end
 local target,why=T.Target(v);if not target then message(why);return end
 local boxes=H.Boxes(target.actor,s.kind,target.record[s.kind]);local index=clamp(s.index,1,math.max(1,#boxes));local b=boxes[index]
 if command=='previous'or command=='next'then s.index=#boxes>0 and(index+(command=='next'and 1 or-1)-1)%#boxes+1 or 1;return end
 if command=='automatic'then local ok,err=T.Commit(v,target,s.kind,nil,false,true);if not ok then message(err)end;return end
 if command=='add'or command=='duplicate'then
  -- A disabled auto footprint (such as the open tent) is only a preview.
  if not target.record[s.kind]and b and b.enabled==false then boxes={}end
  if #boxes>=H.MAX_BOXES then message('Limit: eight boxes per object and control');return end
  local new=command=='duplicate'and b and H.Copy(b)or{enabled=true,width=1,depth=1,x=0,y=0}
  if s.kind=='hitbox'and not new.height then new.height=1;new.z=0 end
  if command=='duplicate'then new.x=clamp((new.x or 0)+.3,-10,10);new.y=clamp((new.y or 0)+.3,-10,10)end
  boxes[#boxes+1]=new;s.index=#boxes
 elseif command=='remove'then if b then table.remove(boxes,index)end;s.index=math.max(1,math.min(index,#boxes))
 elseif command=='enabled'then if not b then return end;b.enabled=b.enabled==false
 elseif command=='fit'then boxes[index]=H.Default(target.actor,s.kind);boxes[index].enabled=true
 else return end
 local ok,err=T.Commit(v,target,s.kind,boxes);if not ok then message(err)end
end
function T.Exact(v)
 local s=v.world3DHitboxTool;local e=editor();if not T.Allowed(v)or not e.ShowForm then return end
 local target,why=T.Target(v);if not target then message(why);return end
 local boxes=H.Boxes(target.actor,s.kind,target.record[s.kind]);local index=s.index;local b=boxes[index];if not b then return end
 local kind=s.kind;local fields={{key='enabled',label='Enabled',value=b.enabled~=false and'yes'or'no',choices={{'yes','Yes'},{'no','No'}}}}
 local keys=kind=='hitbox'and{'width','depth','height','x','y','z'}or{'width','depth','x','y'}
 for _,key in ipairs(keys)do fields[#fields+1]={key=key,label=key,value=tostring(b[key]or 0),limit=24}end
 return e.ShowForm({title='Box '..index..' · '..(kind=='collider'and'walking collision'or'clickable area'),help='Intrinsic object units; follows object rotation and scale. Save through the main editor.',fields=fields,submitLabel='Apply box',submit=function(values)
  if e.scene~=target.scene or e.selected~=target.id then return false,'Select the same object again'end
  local value={enabled=values.enabled=='yes'};for _,key in ipairs(keys)do value[key]=tonumber(values[key]);if not value[key]then return false,'Enter a number for '..key end end
  local valid,err=C.Validate(kind,value);if not valid then return false,err end
  -- Existing forms submit while their popup is still shown. Their Set path
  -- supplies the same guarded validation/history used by every other form.
  if ns.MainStorageBlocked or ns.UI2.locked or InCombatLockdown()then return false,'Scene editing is unavailable'end
  local current=e.Value(target.scene,target.id);if not current then return false,'Object unavailable'end
  local parts=H.Boxes(target.actor,kind,current[kind]);if not parts[index]then return false,'Box changed; reopen exact values'end
  parts[index]=valid;current[kind]={enabled=true,boxes=parts};return e.Set(target.id,current)
 end})
end
function T.Cursor(frame)
 local x,y=GetCursorPosition();local scale=frame:GetEffectiveScale();local left,top=frame:GetLeft(),frame:GetTop()
 if not left or not top or scale<=0 then return end;return x/scale-left,top-y/scale
end
function T.EndDrag(v,cancel)
 local s=v.world3DHitboxTool;local d=s and s.drag;if not d then return end
 s.drag=nil;local e=editor();e.firesideBoxDragging=nil
 if cancel and e.scene==d.target.scene and e.selected==d.target.id and T.Allowed(v)then e.Set(d.target.id,d.target.record,true)end
end
function T.BeginDrag(v,index,face)
 local s=v.world3DHitboxTool;if not s or s.drag or not T.Allowed(v)then return end
 local target,why=T.Target(v);if not target then message(why);return end
 s.index=index;local boxes=H.Boxes(target.actor,s.kind,target.record[s.kind]);local r=boxes[index];if not r then return end
 local a=target.actor;local shape=H.Shape(target.row.engine.shot,a,r);local origin,axis=T.Handle(shape,face,s.kind)
 local frame=target.row.engine.frame;local x,y=T.Cursor(frame);if not x then return end
 local d={target=target,boxes=boxes,index=index,face=face,start={x,y},kind=s.kind,base=H.Copy(r),ratio=H.Ratio(a),shape=shape}
 if face=='move'then
  d.map=F.Coordinates.FloorMap(frame,target.row.engine.shot,origin[3]);if not d.map then message('Wait for native projection');return end
  d.wx,d.wy=d.map(x/frame:GetWidth(),y/frame:GetHeight());if not d.wx then return end
 else
  d.axis=H.AxisMap(frame,target.row.engine.shot,origin,axis);if not d.axis then message('Rotate the camera to see this side before dragging it');return end
 end
 editor().Push();s.drag=d;editor().firesideBoxDragging=true;F.EditorCamera.Clear(v)
end
function T.Handle(b,face,kind)
 local z=kind=='collider'and b.bottom+.04 or(b.bottom+b.top)*.5
 local p={b.centerX,b.centerY,z};local axis
 if face:sub(1,1)=='x'then axis={b.cos,b.sin,0};local sign=face=='x+'and 1 or-1;p[1]=p[1]+axis[1]*b.halfX*sign;p[2]=p[2]+axis[2]*b.halfX*sign
 elseif face:sub(1,1)=='y'then axis={-b.sin,b.cos,0};local sign=face=='y+'and 1 or-1;p[1]=p[1]+axis[1]*b.halfY*sign;p[2]=p[2]+axis[2]*b.halfY*sign
 elseif face:sub(1,1)=='z'then axis={0,0,1};p[3]=face=='z+'and b.top or b.bottom end
 return p,axis
end
function T.Drag(v)
 local s=v.world3DHitboxTool;local d=s.drag;if not d then return end
 if not T.Allowed(v)or editor().selected~=d.target.id or editor().scene~=d.target.scene then T.EndDrag(v,false);return end
 if IsKeyDown and IsKeyDown('ESCAPE')then T.EndDrag(v,true);return end
 if not IsMouseButtonDown('LeftButton')then T.EndDrag(v,false);return end
 local frame=d.target.row.engine.frame;local x,y=T.Cursor(frame);if not x then return end
 local r
 if d.face=='move'then
  local wx,wy=d.map(x/frame:GetWidth(),y/frame:GetHeight());if not wx then return end
  local dx,dy=wx-d.wx,wy-d.wy;r=H.Copy(d.base)
  r.x=clamp((r.x or 0)+(dx*d.shape.cos+dy*d.shape.sin)/d.ratio,-10,10)
  r.y=clamp((r.y or 0)+(-dx*d.shape.sin+dy*d.shape.cos)/d.ratio,-10,10)
 else local amount=d.axis(x-d.start[1],y-d.start[2]);if not amount then return end;r=H.Resize(d.base,d.face,amount/d.ratio)end
 r.enabled=true;d.boxes[d.index]=r
 -- Ignore identical cursor samples: reapplying every native actor would disrupt
 -- idle projection and turn a simple drag into needless full-scene work.
 local key=table.concat({r.x or 0,r.y or 0,r.z or 0,r.width,r.depth,r.height or 0},':')
 if d.last==key then return end
 local ok,why=T.Commit(v,d.target,d.kind,d.boxes,true)
 if ok then d.last=key else T.EndDrag(v,false);message(why)end
end
local function button(parent,label,x,y,w,fn)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate');b:SetPoint('TOPLEFT',x,y);b:SetSize(w,22);b:SetText(label);b:SetScript('OnClick',fn);return b
end
function T.Ensure(v)
 if v.world3DHitboxTool then return v.world3DHitboxTool end
 local s={kind='collider',index=1,lines={},handles={}};v.world3DHitboxTool=s
 local panel=CreateFrame('Frame',nil,v.frame);s.panel=panel;panel:SetPoint('TOPLEFT',12,-100);panel:SetSize(360,204);panel:EnableMouse(true)
 local bg=panel:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();bg:SetColorTexture(.025,.04,.035,.97)
 local title=panel:CreateFontString(nil,'OVERLAY','GameFontNormal');title:SetPoint('TOPLEFT',8,-8);title:SetText('Hitboxes · select object in main editor')
 s.title=title
 button(panel,'Walking',8,-31,95,function()T.EndDrag(v,false);s.kind='collider';s.index=1 end)
 button(panel,'Click area',109,-31,95,function()T.EndDrag(v,false);s.kind='hitbox';s.index=1 end)
 button(panel,'Close',268,-31,82,function()T.EndDrag(v,false);panel:Hide();s.overlay:Hide()end)
 button(panel,'Previous',8,-58,78,function()T.Command(v,'previous')end)
 button(panel,'Next',90,-58,60,function()T.Command(v,'next')end)
 button(panel,'Add box',156,-58,92,function()T.Command(v,'add')end)
 button(panel,'Duplicate',254,-58,96,function()T.Command(v,'duplicate')end)
 button(panel,'Remove',8,-85,78,function()T.Command(v,'remove')end)
 button(panel,'On / Off',90,-85,78,function()T.Command(v,'enabled')end)
 button(panel,'Auto-fit box',174,-85,112,function()T.Command(v,'fit')end)
 button(panel,'Exact values',8,-112,112,function()T.Exact(v)end)
 button(panel,'Use automatic',126,-112,130,function()T.Command(v,'automatic')end)
 local info=panel:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');info:SetPoint('TOPLEFT',8,-141);info:SetWidth(344);info:SetJustifyH('LEFT');s.info=info
 local help=panel:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');help:SetPoint('TOPLEFT',8,-174);help:SetText('Drag +/- sides; center moves box. Escape cancels drag.\nSave / Undo / Export through the main editor.')
 local overlay=CreateFrame('Frame',nil,v.frame);s.overlay=overlay;overlay:SetAllPoints(v:ActiveRoom().native.frame);overlay:EnableMouse(false)
 panel:SetScript('OnUpdate',function(_,dt)
  if not F.EditorCamera.Active(v)then T.EndDrag(v,false);panel:Hide();overlay:Hide();return end
  s.clock=(s.clock or 0)+dt;if s.clock<.04 then return end;s.clock=0;T.Drag(v);T.Draw(v)
 end)
 panel:HookScript('OnHide',function()T.EndDrag(v,false);overlay:Hide()end)
 panel:Hide();overlay:Hide();return s
end
function T.Open(v,kind)
 if not F.EditorCamera.Active(v)then return false,'Open the existing scene editor first'end
 local s=T.Ensure(v);T.EndDrag(v,false);s.kind=kind or s.kind;s.index=1;s.panel:Show();T.Draw(v);return true
end
function T.Draw(v)
 local s=v.world3DHitboxTool;local e=editor();local target,why=T.Target(v)
 local p=e.panel and e.panel.frame;local strata=p and p:GetFrameStrata()or'FULLSCREEN_DIALOG';local level=p and p:GetFrameLevel()or 100
 s.panel:SetFrameStrata(strata);s.panel:SetFrameLevel(level+3);s.overlay:SetFrameStrata(strata);s.overlay:SetFrameLevel(math.max(1,level-1))
 for _,l in ipairs(s.lines)do l:Hide()end;for _,b in ipairs(s.handles)do b:Hide()end
 if not target or not T.Allowed(v)then s.info:SetText(why or'Finish the current form or object drag first');s.overlay:Hide();return end
 if s.target~=target.id then s.target=target.id;s.index=1 end
 local boxes,enabled=H.Boxes(target.actor,s.kind,target.record[s.kind]);s.index=clamp(s.index,1,math.max(1,#boxes))
 s.title:SetText('Hitboxes · '..(target.actor.spec.label or target.id))
 local current=boxes[s.index];local automatic=not target.record[s.kind]
 s.info:SetText((s.kind=='collider'and'Walking footprints'or'Clickable volumes')..' · '..(automatic and'Automatic preview'or('Box '..s.index..' / '..#boxes))..'\n'..(current and enabled and current.enabled~=false and'Enabled'or'Disabled / empty')..' · '..(s.kind=='collider'and'Green: blocks walking; gaps remain open.'or'Blue: selects interactions; does not block walking.'))
 s.overlay:Show();local engine=target.row.engine;local width,height=engine.frame:GetWidth(),engine.frame:GetHeight();local used,handles=0,0
 local function project(p)local u,w=N.ProjectNative(engine.frame,engine.shot,p[1],p[2],p[3]);if u and u>=0 and u<=1 and w>=0 and w<=1 then return u*width,-w*height end end
 local function line(a,b,selected,on)
  local x,y=project(a);local xx,yy=project(b);if not x or not xx or not s.overlay.CreateLine then return end
  used=used+1;local l=s.lines[used]
  if not l then l=s.overlay:CreateLine(nil,'OVERLAY');s.lines[used]=l end
  l:SetThickness(selected and 3 or 1.5);l:SetColorTexture(on and(s.kind=='collider'and .25 or .3)or .6,on and(s.kind=='collider'and 1 or .65)or .6,on and(s.kind=='collider'and .4 or 1)or .6,selected and 1 or .7)
  l:SetStartPoint('TOPLEFT',x,y);l:SetEndPoint('TOPLEFT',xx,yy);l:Show()
 end
 local function handle(b,index,face,label)
  local point=T.Handle(b,face,s.kind);local x,y=project(point);if not x then return end
  handles=handles+1;local h=s.handles[handles]
  if not h then
   h=CreateFrame('Button',nil,s.overlay,'UIPanelButtonTemplate');h:SetSize(28,22);h:RegisterForClicks('LeftButtonDown','LeftButtonUp');h:RegisterForDrag('LeftButton')
   h:SetScript('OnMouseDown',function(self,key)if key=='LeftButton'then if self.face=='select'then s.index=self.box else T.BeginDrag(v,self.box,self.face)end end end)
   h:SetScript('OnMouseUp',function(_,key)if key=='LeftButton'then T.EndDrag(v,false)end end)
   h:SetScript('OnDragStop',function()T.EndDrag(v,false)end);s.handles[handles]=h
  end
  h.box=index;h.face=face;h:ClearAllPoints();h:SetPoint('CENTER',s.overlay,'TOPLEFT',x,y);h:SetText(label);h:Show()
 end
 for i,r in ipairs(boxes)do
  local b=H.Shape(engine.shot,target.actor,r);local selected=i==s.index;local on=enabled and r.enabled~=false
  if b then
   local bottom=s.kind=='collider'and b.bottom+.04 or b.bottom;local top=s.kind=='hitbox'and b.top
   for k,pnt in ipairs(b.corners)do local next=b.corners[k%4+1];line({pnt[1],pnt[2],bottom},{next[1],next[2],bottom},selected,on)
    if top then line({pnt[1],pnt[2],top},{next[1],next[2],top},selected,on);line({pnt[1],pnt[2],bottom},{pnt[1],pnt[2],top},selected,on)end
   end
   if selected then
    for _,face in ipairs(s.kind=='hitbox'and{'x-','x+','y-','y+','z-','z+'}or{'x-','x+','y-','y+'})do handle(b,i,face,face:upper())end
    handle(b,i,'move',tostring(i)..'+')
   else handle(b,i,'select',tostring(i))end
  end
 end
end
function T.BindExistingEditor()
 local e=editor();if not e or e.fireside3DHitboxesBound or not(e.CheckRecord and e.Value and e.Set and e.Export and e.Validate and e.UpdateHandle)then return false end
 e.fireside3DHitboxesBound=true
 local check=e.CheckRecord
 e.CheckRecord=function(key,id,r)
  if type(r)~='table'or getmetatable(r)then return check(key,id,r)end
  local extra={};local clean={};for k,x in pairs(r)do
   if(k=='collider'or k=='hitbox')and H.Compound(x)then
    local scene=e.Scene(key);local row=e.Find(key,id)
    if not F.IsScene(scene)or not row or row.kind~='native'then return nil,'Compound boxes are for experimental 3D props'end
    local valid,why=H.Validate(k,x);if not valid then return nil,why end;extra[k]=valid
   else clean[k]=x end
  end
  local valid,why=check(key,id,clean);if not valid then return nil,why end;for k,x in pairs(extra)do valid[k]=x end;return valid
 end
 local export,validate=e.Export,e.Validate
 e.Export=function(...)local out=export(...);if F.IsScene(e.Scene(e.scene))then out.version=6 end;return out end
 e.Validate=function(r,...)
  if type(r)=='table'and r.version==6 and r.scene==F.PRIMARY then
   local data={};for k,x in pairs(r)do data[k]=x end;data.version=5
   local out,why=validate(data,...);if out then out.version=6 end;return out,why
  end;return validate(r,...)
 end
 local geometry=e.GeometryForm
 if geometry then e.GeometryForm=function(kind,...)
  local v=e.Realm();if v and F.EditorCamera.Active(v)and(kind=='collider'or kind=='hitbox')then return T.Open(v,kind)end
  return geometry(kind,...)
 end end
 local update=e.UpdateHandle
 e.UpdateHandle=function(...)
  local out=update(...);local v=e.Realm();local s=v and v.world3DHitboxTool
  if s and s.panel:IsShown()and F.EditorCamera.Active(v)then if e.handle then e.handle:Hide()end;local scene=e.Scene(e.scene);if scene.controlGuide then scene.controlGuide:Hide()end end
  return out
 end
 return true
end
