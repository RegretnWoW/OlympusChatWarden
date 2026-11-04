-- A book-relative native reading camera. Actor/world coordinates stay authored;
-- no new furniture art, model copies, movement collectors or saved-state format.
local _,ns=...
local R={VERSION=3,PITCH=math.rad(72)};ns.WardenReadingCamera=R
local N=ns.WardenNativeScene
local function lerp(a,b,t)return a+(b-a)*t end
-- Owner-approved live calibration, still relative to the placed book and desk.
R.defaults={version=1,distance=1.1,height=0,pitch=69,yaw=-25,x=.03,y=.30}
R.limits={distance={.5,4},height={-2,4},pitch={40,89},yaw={-180,180},x={-4,4},y={-4,4}}
function R.Validate(value)
 if type(value)~='table'or getmetatable(value)or value.version~=1 then return nil,'Invalid Journal camera settings'end
 local out={version=1}
 for k,v in pairs(value)do if k~='version'and not R.limits[k]then return nil,'Unknown camera control'end end
 for k,range in pairs(R.limits)do local n=value[k];if type(n)~='number'or n~=n or n<range[1]or n>range[2]then return nil,'Out of range: '..k end;out[k]=n end
 return out
end
function R.Settings(scene)
 local clean=scene and R.Validate(scene.readingCameraTuning);if clean then return clean end
 local out={};for k,v in pairs(R.defaults)do out[k]=v end;return out
end
function R.Set(scene,value)
 if not scene or not scene.definition.reader then return false,'Select a room with a desk Journal'end
 local clean,why=R.Validate(value);if not clean then return false,why end
 scene.readingCameraTuning=clean;return true
end
function R.Target(scene,aspect)
 local e=scene.native;local book,desk=e.actors['room-book'],e.actors.desk
 if not book or not desk or not book.ready or not desk.ready or book.awaitSupport or not book.position or not desk.position or not desk.bounds then return nil,'Wait for the supported desk book'end
 local shot=scene.shot;local p=book.position;local tx,ty,tz=N.World(shot,p[1],p[2],p[3]+.035)
 local dx,dy=shot.target[1]-shot.position[1],shot.target[2]-shot.position[2];local length=math.sqrt(dx*dx+dy*dy);if length<.001 then return nil,'Invalid room camera'end
 dx,dy=dx/length,dy/length;local tuning=R.Settings(scene);local rx,ry=dy,-dx
 tx,ty=tx+rx*tuning.x+dx*tuning.y,ty+ry*tuning.x+dy*tuning.y
 local yaw=math.rad(tuning.yaw);local ca,sa=math.cos(yaw),math.sin(yaw);dx,dy=dx*ca-dy*sa,dx*sa+dy*ca;rx,ry=dy,-dx
 local pitch=math.rad(tuning.pitch)
 local cx,cy=N.World(shot,desk.position[1],desk.position[2],0);local angle=desk.worldYaw or 0;local c,s=math.cos(angle),math.sin(angle);local b=desk.bounds
 local hx=(b[4]-b[1])*(desk.scale or 1)*.5;local hy=(b[5]-b[2])*(desk.scale or 1)*.5
 local ox,oy=tx-cx,ty-cy;local x=math.abs(c*ox+s*oy);local y=math.abs(-s*ox+c*oy)
 -- Fit a conservative view rectangle inside the real rotated desk footprint.
 -- This keeps the tabletop as the backdrop, even when its editor yaw changes.
 local budgetX=math.max(.06,hx*.88-x);local budgetY=math.max(.06,hy*.88-y)
 -- Intersect all four perspective corner rays with the book's support plane.
 -- A symmetric rectangle estimate misses the larger far corners of the view.
 local lens=math.tan((shot.fov or .75)/2);local sp,cp=math.sin(pitch),math.cos(pitch);local reachX,reachY=0,0
 for _,u in ipairs({-1,1})do for _,v in ipairs({-1,1})do
  local denominator=sp-v*lens*cp
  local ax=(u*lens*aspect*sp*rx+v*lens*dx)/denominator
  local ay=(u*lens*aspect*sp*ry+v*lens*dy)/denominator
  reachX=math.max(reachX,math.abs(c*ax+s*ay));reachY=math.max(reachY,math.abs(-s*ax+c*ay))
 end end
 local fitDistance=math.min(budgetX/math.max(.01,reachX),budgetY/math.max(.01,reachY))
 local bb=book.bounds;local bookWidth=bb and math.max(bb[4]-bb[1],bb[5]-bb[2])*(book.scale or 1)or .65
 -- Leave a visible desk margin around the paper; the close-up is a desk view,
 -- not a macro shot of the book cover. Retain the accepted overhead angle.
 local deskDiagonal=math.sqrt((hx*2)^2+(hy*2)^2)
 local minimumSpan=math.max(2.8,bookWidth*4,deskDiagonal*1.6)
 local clearance=math.max(.5,(book.top or .2)+.3)
 -- An off-centre book can exceed the desk's inner rectangle. Never satisfy
 -- that impossible fit by driving the camera inside the book or tabletop.
 local distance=math.max(fitDistance,minimumSpan/(2*aspect*lens),clearance/sp)*tuning.distance
 distance=math.max(distance,(clearance-tuning.height)/sp)
 local span=2*distance*aspect*lens
 local horizontal=distance*math.cos(pitch);local vertical=distance*sp+tuning.height
 return{position={tx-dx*horizontal,ty-dy*horizontal,tz+vertical},target={tx,ty,tz},fov=shot.fov or .75,span=span,pitch=math.atan2(vertical,horizontal),book=book,desk=desk,clearance=vertical,tabletopFits=distance<=fitDistance+.0001,tuning=tuning}
end
function R.Reset(v)
 local old=v.nativeReadingScene
 if old then N.ViewCamera(old.native,nil);v.nativeReadingScene=nil;v.readingCameraKey=nil end
end
function R.Apply(v,w,h,mix)
 local scene=v.studyScene
 if not v.reading or v.campfireWelcome or v.shelfFocus or not scene or not scene.definition.reader or mix<=.00001 then R.Reset(v);return false end
 if not scene.native.frame then v.readingCameraStatus='Native viewport unavailable; simulator cannot render the desk camera';return false end
 local target,why=R.Target(scene,w/h);if not target then R.Reset(v);v.readingCameraStatus=why;return false end
 if v.nativeReadingScene and v.nativeReadingScene~=scene then R.Reset(v)end
 local base=scene.shot;local shot={position={},target={},fov=base.fov}
 for i=1,3 do shot.position[i]=lerp(base.position[i],target.position[i],mix);shot.target[i]=lerp(base.target[i],target.target[i],mix)end
 local key=table.concat({scene.key,w,h,mix,unpack(shot.position)},':')..':'..table.concat(shot.target,':')
 if v.readingCameraKey~=key then
  if not N.ViewCamera(scene.native,shot)then R.Reset(v);v.readingCameraStatus='Installed client rejected the reading camera';return false end
  v.readingCameraKey=key
 end
 v.nativeReadingScene=scene;v.readingCameraStatus='Native book-relative camera; authored world basis preserved'
 v.readingCameraTarget={position=target.position,target=target.target,span=target.span,pitchDegrees=math.deg(target.pitch),clearance=target.clearance,tabletopFits=target.tabletopFits,tuning=target.tuning,bookPosition={unpack(target.book.position)},deskPosition={unpack(target.desk.position)}}
 return true
end
local bind=ns.WardenRoomBook.Bind
function R.Stack(v)
 if not v.reading or not v.reader or v.cameraMix<=.001 then return end
 local highest=v.studyScene.frame:GetFrameLevel()
 for _,host in pairs(v.studyScene.layers)do highest=math.max(highest,host:GetFrameLevel())end
 for _,engine in ipairs({v.studyScene.native,v.studyScene.nativeAir})do
  for _,host in ipairs(engine.RenderFrames and engine:RenderFrames()or{})do highest=math.max(highest,host:GetFrameLevel())end
 end
 if v.reader.book:GetFrameLevel()<=highest then ns.WardenSceneGraph.StackTree(v.reader.book,highest+2)end
end
function ns.WardenRoomBook.Bind(v,p,U)
 local out=bind(v,p,U)
 if p.readingCamera62 then return out end;p.readingCamera62=true
 p.closeBook:Hide();p.closeBook:HookScript('OnShow',function(self)self:Hide()end)
 local layout=v.Layout
 v.Layout=function(self,...)
  local out=layout(self,...);R.Stack(self);local reading=self.reading and self.cameraMix>.001
  U.backButton:SetShown(not reading and not U.menuHidden);U.forwardButton:SetShown(not reading and not U.menuHidden)
  return out
 end
 local before=U.window.ChatWardenBeforeFocus
 U.window.ChatWardenBeforeFocus=function(self)if before then before(self)end;R.Stack(v)end
 local report=v.Report
 v.Report=function(self,...)
  local out=report(self,...);out.layout={busy=self.layingOut==true,errors=self.layoutErrors or 0,lastError=self.lastLayoutError};out.readingCamera={version=R.VERSION,status=self.readingCameraStatus,target=self.readingCameraTarget,active=self.nativeReadingScene~=nil,textScale=.54,topNavigationHidden=self.reading and self.cameraMix>.001,readerLevel=p.book:GetFrameLevel()};out.closeupVisibility={mode=self.closeupMode,kept=self.closeupMode and N.closeupActors[self.closeupMode]};return out
 end
 return out
end
