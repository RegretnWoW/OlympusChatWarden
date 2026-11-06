-- One bounded, versioned vector-ink component for private pages and public
-- attachments. Strict ASCII coordinates only; no code, URLs or texture paths.
local _,ns=...
local D={VERSION=1,MAX_BYTES=8192,MAX_STROKES=256,MAX_POINTS=1536,MAX_PRIVATE=128};ns.WardenDrawing=D
D.PUBLIC={MAX_BYTES=2048,MAX_STROKES=96,MAX_POINTS=480}
D.palette={{.12,.09,.06},{.35,.16,.08},{.12,.27,.48},{.42,.12,.18},{.12,.36,.23},{.5,.33,.08},{.35,.18,.44},{.92,.85,.68}}
D.sizes={2,4,7}
local function plain(v)return type(v)=='table'and getmetatable(v)==nil and ns.Readable(v)end
local function integer(v,a,b)return type(v)=='number'and v==v and v%1==0 and v>=a and v<=b end
local function copy(v)return ns.Athena.Copy(v)end
function D.Decode(wire,limits)
 limits=limits or D
 if type(wire)~='string'or #wire>limits.MAX_BYTES or wire:sub(1,4)~='WD1:'then return nil,'DRAWING_FORMAT_OR_SIZE'end
 local strokes={};local total=0;local body=wire:sub(5)
 if body==''then return {version=1,strokes={}}end
 for part in body:gmatch('[^;]+')do
  if #strokes>=limits.MAX_STROKES then return nil,'DRAWING_STROKE_LIMIT'end
  local color,size,points=part:match('^([1-8])([1-3]):([a-f0-9]+)$')
  if not color or #points%4~=0 or #points<4 then return nil,'DRAWING_STROKE_FORMAT'end
  local row={color=tonumber(color),size=tonumber(size),points={}}
  for i=1,#points,4 do local x,y=tonumber(points:sub(i,i+1),16),tonumber(points:sub(i+2,i+3),16)
   if not x or not y then return nil,'DRAWING_POINT'end
   total=total+1;if total>limits.MAX_POINTS then return nil,'DRAWING_POINT_LIMIT'end;row.points[#row.points+1]={x,y}
  end
  strokes[#strokes+1]=row
 end
 local out={version=1,strokes=strokes};local canonical=D.Encode(out,limits)
 if canonical~=wire then return nil,'NONCANONICAL_DRAWING'end;return out
end
function D.Encode(model,limits)
 limits=limits or D
 if not plain(model)or model.version~=1 or not plain(model.strokes)or #model.strokes>limits.MAX_STROKES then return nil,'DRAWING_MODEL'end
 for k in pairs(model)do if k~='version'and k~='strokes'then return nil,'DRAWING_FIELD'end end
 local rows={};local total=0;local strokeCount=0
 for k in pairs(model.strokes)do if not integer(k,1,#model.strokes)then return nil,'DRAWING_ARRAY'end;strokeCount=strokeCount+1 end
 if strokeCount~=#model.strokes then return nil,'DRAWING_ARRAY'end
 for _,stroke in ipairs(model.strokes)do
  if not plain(stroke)or not integer(stroke.color,1,8)or not integer(stroke.size,1,3)or not plain(stroke.points)or #stroke.points<1 then return nil,'DRAWING_STROKE'end
  for k in pairs(stroke)do if k~='color'and k~='size'and k~='points'then return nil,'DRAWING_FIELD'end end
  local points={};local count=0;for k in pairs(stroke.points)do if not integer(k,1,#stroke.points)then return nil,'DRAWING_ARRAY'end;count=count+1 end
  if count~=#stroke.points then return nil,'DRAWING_ARRAY'end
  for _,point in ipairs(stroke.points)do
   if not plain(point)or not integer(point[1],0,255)or not integer(point[2],0,255)then return nil,'DRAWING_POINT'end
   for k in pairs(point)do if k~=1 and k~=2 then return nil,'DRAWING_POINT'end end
   total=total+1;if total>limits.MAX_POINTS then return nil,'DRAWING_POINT_LIMIT'end
   points[#points+1]=string.format('%02x%02x',point[1],point[2])
  end
  rows[#rows+1]=stroke.color..stroke.size..':'..table.concat(points)
 end
 local wire='WD1:'..table.concat(rows,';');if #wire>limits.MAX_BYTES then return nil,'DRAWING_BYTES'end;return wire
end
function D.Simplify(points,tolerance)
 if #points<3 then return points end
 local keep={[1]=true,[#points]=true};local stack={{1,#points}};local threshold=(tolerance or .65)^2
 while #stack>0 do
  local span=table.remove(stack);local first,last=span[1],span[2];local a,b=points[first],points[last];local dx,dy=b[1]-a[1],(b[2]-a[2])*.5;local length=dx*dx+dy*dy;local far,index=threshold,nil
  for i=first+1,last-1 do local px,py=points[i][1]-a[1],(points[i][2]-a[2])*.5;local at=length>0 and math.max(0,math.min(1,(px*dx+py*dy)/length))or 0;local d=(px-at*dx)^2+(py-at*dy)^2;if d>far then far,index=d,i end end
  if index then keep[index]=true;stack[#stack+1]={first,index};stack[#stack+1]={index,last}end
 end
 local out={};for i,point in ipairs(points)do if keep[i]then out[#out+1]=point end end;return out
end
function D.New(wire,limits)
 limits=limits or D
 local model,why
 if wire~=nil then model,why=D.Decode(wire,limits)else model={version=1,strokes={}}end
 if not model then return nil,why end
 local e={model=model,undo={},redo={},limits=limits}
 local function checkpoint()e.undo[#e.undo+1]=assert(D.Encode(e.model,limits));if #e.undo>20 then table.remove(e.undo,1)end;e.redo={}end
 function e:Stroke(color,size,points)
  local candidate=copy(self.model);candidate.strokes[#candidate.strokes+1]={color=color,size=size,points=copy(points)}
  local encoded,err=D.Encode(candidate,limits);if not encoded then return false,err end;checkpoint();self.model=candidate;return true
 end
 function e:Erase(x,y,radius,width,height)
  if not integer(x,0,255)or not integer(y,0,255)then return false end
  width,height=width or 510,height or 255;local w=math.min(width,height*2);local h=w/2
  local px,py=x*w/255,y*h/255;local candidate=copy(self.model);local changed=false
  local function hit(a,b,limit)
   local ax,ay=a[1]*w/255,a[2]*h/255;local bx,by=b[1]*w/255,b[2]*h/255;local dx,dy=bx-ax,by-ay
   local t=dx*dx+dy*dy>0 and math.max(0,math.min(1,((px-ax)*dx+(py-ay)*dy)/(dx*dx+dy*dy)))or 0
   return(px-ax-t*dx)^2+(py-ay-t*dy)^2<=limit*limit
  end
  for i=#candidate.strokes,1,-1 do local stroke=candidate.strokes[i];local limit=(radius or 12)+D.sizes[stroke.size]/2
   for j=1,#stroke.points do if hit(stroke.points[j],stroke.points[math.min(j+1,#stroke.points)],limit)then table.remove(candidate.strokes,i);changed=true;break end end
  end
  if changed then checkpoint();self.model=candidate end;return changed
 end
 function e:Undo()local previous=table.remove(self.undo);if not previous then return false end;self.redo[#self.redo+1]=assert(D.Encode(self.model,limits));self.model=assert(D.Decode(previous,limits));return true end
 function e:Redo()local next=table.remove(self.redo);if not next then return false end;self.undo[#self.undo+1]=assert(D.Encode(self.model,limits));self.model=assert(D.Decode(next,limits));return true end
 function e:Clear()checkpoint();self.model={version=1,strokes={}}end
 function e:Save()return D.Encode(self.model,limits)end
 return e
end
function D.Render(parent,wire)
 local model,why=D.Decode(wire);if not model then return false,why end
 parent.ink=parent.ink or{};for _,t in ipairs(parent.ink)do t:Hide()end
 local n=0;local pw,ph=parent:GetWidth(),parent:GetHeight();local w=math.min(pw,ph*2);local h=w/2;local ox,oy=(pw-w)/2,(ph-h)/2
 if type(parent.CreateLine)~='function'then return false,'DRAWING_LINE_API_UNAVAILABLE'end
 local function segment(a,b,stroke)
  n=n+1;local t=parent.ink[n];if not t then t=parent:CreateLine(nil,'ARTWORK');parent.ink[n]=t end
  local x1,y1=ox+a[1]*w/255,oy+a[2]*h/255;local x2,y2=ox+b[1]*w/255,oy+b[2]*h/255
  if x1==x2 and y1==y2 then x2=x2+.1 end
  local c=D.palette[stroke.color];t:SetColorTexture(c[1],c[2],c[3],1);t:ClearAllPoints()
  t:SetStartPoint('BOTTOMLEFT',parent,x1,y1);t:SetEndPoint('BOTTOMLEFT',parent,x2,y2);t:SetThickness(D.sizes[stroke.size]);if t.SetDrawLayer then t:SetDrawLayer(parent.compositionPool and 'OVERLAY'or'ARTWORK')end;t:Show()
 end
 for _,stroke in ipairs(model.strokes)do if #stroke.points==1 then segment(stroke.points[1],stroke.points[1],stroke)else for i=2,#stroke.points do segment(stroke.points[i-1],stroke.points[i],stroke)end end end
 return true,n
end
local function private(create)
 if not ns.DB then return end
 if not ns.DB.journalDrawings and create then ns.DB.journalDrawings={version=1,owners={}}end
 local root=ns.DB.journalDrawings;if not plain(root)or root.version~=1 or not plain(root.owners)then return end
 local owner=ns.Chronicle.Owner();if not owner then return end
 local r=root.owners[owner];if not r and create then r={};root.owners[owner]=r end
 if r and plain(r)then return r end
end
function D.PrivateSave(page,wire)
 if not ns.Permissions.Decide('UIAccess')or type(page)~='string'or #page<1 or #page>512 then return false,'EXACT_OWNER_PAGE_REQUIRED'end
 local decoded,why=D.Decode(wire);if not decoded then return false,why end
 local r=private(true);if not r then return false,'DRAWING_ARCHIVE_UNAVAILABLE'end
 local count=0;for _ in pairs(r)do count=count+1 end;if not r[page]and count>=D.MAX_PRIVATE then return false,'PRIVATE_DRAWING_CAPACITY'end
 r[page]={version=1,wire=wire,at=ns.SafeCall(GetServerTime)or 0,ownerPrivate=true,evidence=false};return true
end
function D.PrivateGet(page)
 if not ns.Permissions.Decide('UIAccess')then return end;local r=private(false);local value=r and r[page]
 if plain(value)and D.Decode(value.wire)then return copy(value)end
end
function D.PrivatePages()
 local pages={};if not ns.Permissions.Decide('UIAccess')then return pages end
 for key,row in pairs(private(false)or{})do if type(key)=='string'and plain(row)and D.Decode(row.wire)then pages[#pages+1]=key end end
 table.sort(pages);return pages
end
function D.ResetPrivacyRuntime()if D.window and D.window.Discard then D.window:Discard()end end
function D.Open(options)
 if not ns.Permissions.Decide('UIAccess')then return nil,'OWNER_ACCESS_REQUIRED'end
 options=options or{};local editor,why=D.New(options.wire,options.limits);if not editor then return nil,why end
 if D.window and not options.inline then return D.window:Present(options,editor)end
 local C=ns.UI2Components;local f=CreateFrame('Frame',nil,options.inline and options.parent or UIParent);if not options.inline then D.window=f end;f:SetSize(options.privateBook and 580 or 660,options.privateBook and 390 or 480);f:SetPoint('CENTER');f:SetFrameStrata('DIALOG');f:EnableMouse(true);if f.SetPropagateMouseClicks then f:SetPropagateMouseClicks(false)end;if not options.inline then ns.Theme.RegisterWindow(f,true);f:SetClampedToScreen(true)end
 if ns.WardenArt then ns.WardenArt.Frame(f,true,true)end
 local bg=f:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();bg:SetColorTexture(.88,.81,.65,1)
 local title=f:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');title:SetPoint('TOPLEFT',16,-14);title:SetTextColor(.18,.12,.07,1);title:SetText(options.title or'Private sketch · not historical evidence')
 local canvas=CreateFrame('Frame',nil,f);canvas:SetPoint('TOPLEFT',16,-70);canvas:SetSize(f:GetWidth()-32,f:GetHeight()-160);canvas:EnableMouse(true);f.canvas=canvas;f.editor=editor
 local paper=canvas:CreateTexture(nil,'BACKGROUND');paper:SetAllPoints();paper:SetColorTexture(.96,.9,.76,1)
 local tool,color,size='pen',1,1;local points;local remaining=0;local held=false;local finish
 local usage=f:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');usage:SetPoint('BOTTOMLEFT',16,52);usage:SetTextColor(.25,.17,.09);f.usage=usage
 local function refresh()local wire=assert(editor:Save());D.Render(canvas,wire);local n=0;for _,s in ipairs(editor.model.strokes)do n=n+#s.points end;usage:SetText(#editor.model.strokes..' / '..editor.limits.MAX_STROKES..' strokes · '..n..' / '..editor.limits.MAX_POINTS..' points · '..#wire..' / '..editor.limits.MAX_BYTES..' bytes')end
 local function position()
  local x,y=GetCursorPosition();local scale=canvas:GetEffectiveScale();local left,bottom=canvas:GetLeft(),canvas:GetBottom()
  if not x or not y or not left or not bottom or not scale or scale<=0 then return end
  local pw,ph=canvas:GetWidth(),canvas:GetHeight();local w=math.min(pw,ph*2);local h=w/2
  x=(x/scale-left-(pw-w)/2)/w;y=(y/scale-bottom-(ph-h)/2)/h;if x<0 or x>1 or y<0 or y>1 then return end
  return math.floor(x*255+.5),math.floor(y*255+.5)
 end
 local function sample()
  if options.canDraw and not options.canDraw()then return end
  local x,y=position();if not x then return end
  if tool=='eraser'then if editor:Erase(x,y,12,canvas:GetWidth(),canvas:GetHeight())then refresh()end;return end
  if not points then return end;local last=points[#points]
  if #points<remaining and(not last or math.abs(last[1]-x)+math.abs(last[2]-y)>=3)then
   points[#points+1]={x,y};local preview=copy(editor.model);preview.strokes[#preview.strokes+1]={color=color,size=size,points=points}
   local encoded=D.Encode(preview,editor.limits);if encoded then D.Render(canvas,encoded)end
  end
 end
 canvas:SetScript('OnMouseDown',function(_,button)if button~='LeftButton'or options.canDraw and not options.canDraw()then return end;held=true;points={};remaining=editor.limits.MAX_POINTS;for _,stroke in ipairs(editor.model.strokes)do remaining=remaining-#stroke.points end;sample();canvas:SetScript('OnUpdate',function()if held and IsMouseButtonDown and not IsMouseButtonDown('LeftButton')then finish()else sample()end end)end)
 finish=function()
  canvas:SetScript('OnUpdate',nil);held=false
  if tool=='pen'and points and #points>0 then points=D.Simplify(points,.65);local ok,err=editor:Stroke(color,size,points);if not ok then title:SetText(err)end end
  points=nil;refresh()
 end
 canvas:SetScript('OnMouseUp',finish);f:SetScript('OnHide',function()canvas:SetScript('OnUpdate',nil);held=false;points=nil end)
 local x=16
 for _,entry in ipairs({{'Pen',function()tool='pen'end},{'Eraser',function()tool='eraser';title:SetText('Eraser · removes touched strokes')end},{'Brush',function()size=size%3+1;title:SetText('Brush size '..size)end}})do C.Button(f,entry[1],entry[2],80):SetPoint('TOPLEFT',x,-38);x=x+84 end
 for i=1,8 do local n=i;local b=C.Button(f,tostring(i),function()color=n;tool='pen'end,30);b:SetPoint('TOPLEFT',x,-38);local swatch=b:CreateTexture(nil,'OVERLAY');swatch:SetPoint('CENTER');swatch:SetSize(16,16);swatch:SetColorTexture(unpack(D.palette[n]));x=x+34 end
 local buttons={{'Undo',function()editor:Undo();refresh()end},{'Redo',function()editor:Redo();refresh()end},{'Clear',function()editor:Clear();refresh()end},
  {'Save',function()finish();local wire=editor:Save();local ok,err=options.save and options.save(wire);if ok then f:Hide()else title:SetText(err or'Save unavailable')end end},
  {'Close',function()f:Hide()end}}
 f.controls={};for i,b in ipairs(buttons)do local button=C.Button(f,b[1],b[2],105);f.controls[b[1]]=button;button:SetSize((f:GetWidth()-64)/5,30);button:SetPoint('BOTTOMLEFT',16+(i-1)*(f:GetWidth()-24)/5,16)end
 function f:SetWire(wire) local nextEditor,err=D.New(wire,editor.limits);if not nextEditor then return false,err end;options.wire=wire;editor=nextEditor;self.editor=editor;refresh();return true end
 function f:Discard()self:Hide();editor=assert(D.New());self.editor=editor;options={};for _,line in ipairs(canvas.ink or{})do line:Hide()end end
 function f:Present(nextOptions,nextEditor)
  self:Hide();options=nextOptions;editor=nextEditor;self.editor=editor;tool,color,size='pen',1,1
  self:SetParent(UIParent);self:SetScale(options.parent and options.parent:GetEffectiveScale()/UIParent:GetEffectiveScale() or ns.Theme.WindowScale(660,480));self:SetSize(options.privateBook and 580 or 660,options.privateBook and 390 or 480);canvas:SetSize(self:GetWidth()-32,self:GetHeight()-160);self:ClearAllPoints();if options.privateBook then self:SetPoint('BOTTOMRIGHT',options.parent,'BOTTOMRIGHT',-24,44)else self:SetPoint('CENTER')end;for i,name in ipairs({'Undo','Redo','Clear','Save','Close'})do local b=self.controls[name];b:SetSize((self:GetWidth()-64)/5,30);b:ClearAllPoints();b:SetPoint('BOTTOMLEFT',16+(i-1)*(self:GetWidth()-24)/5,16)end;title:SetText(options.title or'Private sketch · not historical evidence');refresh();self:Show();ns.Theme.FocusWindow(self);return self
 end
 if options.privateBook then f:ClearAllPoints();f:SetPoint('BOTTOMRIGHT',options.parent,'BOTTOMRIGHT',-24,44)end
 f:SetScale(options.parent and options.parent:GetEffectiveScale()/UIParent:GetEffectiveScale() or ns.Theme.WindowScale(660,480));refresh();f:Show();if options.inline then f:SetScale(1);f:ClearAllPoints();f:SetPoint('TOPLEFT',options.parent,'TOPLEFT',0,-(options.inlineY or 0));f:SetFrameStrata(options.parent:GetFrameStrata());f:SetFrameLevel(options.parent:GetFrameLevel()+1)else ns.Theme.FocusWindow(f)end;return f
end
