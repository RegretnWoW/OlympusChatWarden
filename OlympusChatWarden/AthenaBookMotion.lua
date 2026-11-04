-- Authored articulation poses, not duplicated raster frames. One transition
-- clock drives the board, paper and study camera. No persisted player state.
local _,ns=...
local A={VERSION=2,PAGE_SECONDS=1.08,COVER_SECONDS=1.28,CAMERA_SECONDS=1.0};ns.AthenaBookMotion=A
-- angle (degrees), curl (radians), upper/lower corner twist. These deliberately
-- asymmetric poses describe a leaf lifting, rolling over its gutter and settling.
A.page={
 {0,0,0},{1,.035,-.01},{3,.09,-.025},{6,.17,-.045},
 {10,.28,-.065},{15,.42,-.09},{21,.58,-.115},{28,.75,-.14},
 {36,.92,-.16},{45,1.06,-.18},{55,1.18,-.19},{66,1.27,-.19},
 {77,1.33,-.18},{87,1.37,-.16},{96,1.38,-.13},{104,1.35,-.095},
 {112,1.29,-.05},{120,1.21,0},{128,1.11,.04},{136,.99,.075},
 {144,.86,.10},{151,.72,.115},{157,.59,.12},{162,.47,.115},
 {166,.36,.10},{170,.26,.08},{173,.18,.06},{175.5,.115,.04},
 {177.5,.067,.025},{179,.032,.012},{179.7,.009,.003},{180,0,0}}
-- A rigid board with a small coherent hinge rise, never a changing-width image.
-- Samples are nonuniformly spaced in angle to author the ease/settle explicitly.
A.cover={
 {0,0},{.5,.001},{1.5,.003},{3,.006},{5.5,.011},{9,.018},
 {13.5,.026},{19,.035},{25.5,.044},{33,.053},{41.5,.061},{51,.068},
 {61,.074},{71.5,.078},{82,.080},{92.5,.079},{103,.075},{113,.069},
 {122.5,.062},{131.5,.055},{139.5,.047},{146.5,.039},{152.5,.032},{158,.025},
 {163,.019},{167.5,.014},{171.5,.010},{175,.006},{177.7,.003},{179.4,.001},
 {179.55,.0007},{179.72,.0004},{179.85,.0002},{179.94,.0001},{179.985,0},{180,0}}
local function lerp(a,b,t)return a+(b-a)*t end
function A.Sample(poses,t)
 local at=math.max(0,math.min(1,t))*(#poses-1);local i=math.min(#poses-1,math.floor(at)+1);local f=at-(i-1);local a,b=poses[i],poses[i+1]
 local function channel(k)
  local y0,y1=a[k]or 0,b[k]or 0;local d=y1-y0
  local m0=i==1 and 0 or ((b[k]or 0)-(poses[i-1][k]or 0))/2
  local m1=i+1==#poses and 0 or ((poses[i+2][k]or 0)-(a[k]or 0))/2
  -- Monotone cubic interpolation: continuous velocity at control poses and
  -- no over-rotation or curl overshoot between them.
  if d==0 then m0,m1=0,0 else
   if m0*d<0 then m0=0 end;if m1*d<0 then m1=0 end
   local q=(m0/d)^2+(m1/d)^2;if q>9 then local scale=3/math.sqrt(q);m0,m1=m0*scale,m1*scale end
  end
  local f2,f3=f*f,f*f*f
  return (2*f3-3*f2+1)*y0+(f3-2*f2+f)*m0+(-2*f3+3*f2)*y1+(f3-f2)*m1
 end
 return channel(1)*math.pi/180,channel(2),channel(3),i
end
function A.Ease(t)t=math.max(0,math.min(1,t));return t*t*t*(t*(t*6-15)+10)end
function A.Now()return ns.SafeCall(GetTimePreciseSec)or ns.SafeCall(GetTime)or 0 end
function A.NoteTexture()
 if A.currentMetrics then A.currentMetrics.textureWrites=A.currentMetrics.textureWrites+1 end
end
function A.For(p)
 if p.bookMotion then return p.bookMotion end
 local m={reader=p,serial=0};p.bookMotion=m
 function m:Cancel(finish)
  local state=self.active;if not state then return end
  self.active=nil;state.host:SetScript('OnUpdate',nil)
  if finish then state.pose(1);state.finish()elseif state.cancel then state.cancel()end
 end
 function m:Seek(q)
  local state=self.active;if not state then return false end
  state.progress=math.max(0,math.min(1,q));A.currentMetrics=state.metrics;state.pose(state.progress);A.currentMetrics=nil;return true
 end
 function m:Start(kind,host,duration,pose,finish,cancel)
  if self.active then return false end
  self.serial=self.serial+1
  local controls=kind=='page'and #A.page or #A.cover
  local state={kind=kind,host=host,duration=duration,pose=pose,finish=finish,cancel=cancel,progress=0,serial=self.serial,
   metrics={controls=controls,updates=0,maxStep=0,maxGap=0,maxPoseMS=0,textureWrites=0,indices={[1]=true}}}
  self.active=state;local preparation=A.Now();pose(0);state.metrics.initialPoseMS=(A.Now()-preparation)*1000
  -- Pose zero must reach the display before the clock starts. Starting before
  -- preparation charged texture/layout work against the animation and skipped
  -- its first poses on the very next OnUpdate.
  host:SetScript('OnUpdate',function()
   if self.active~=state then return end
   if ns.DB.journalReducedMotion==true then self:Cancel(true);return end
   local stamp=A.Now()
   if not state.start then state.start=stamp;state.last=stamp;return end
   local metrics=state.metrics;metrics.maxGap=math.max(metrics.maxGap,stamp-state.last);state.last=stamp
   local desired=math.max(0,math.min(1,(stamp-state.start)/state.duration))
   -- Do not leap over physical controls after a hitch. A slow client may take
   -- longer to settle, but it never catches up with a large visible pose jump.
   local q=math.min(desired,state.progress+1/(controls-1));if q>1-1e-9 then q=1 end
   local before=A.Now();local step=q-state.progress;self:Seek(q)
   metrics.updates=metrics.updates+1;metrics.maxStep=math.max(metrics.maxStep,step);metrics.maxPoseMS=math.max(metrics.maxPoseMS,(A.Now()-before)*1000)
   local index=math.min(controls,math.floor(q*(controls-1))+1);metrics.indices[index]=true
   if q==1 then self.lastMeasurement={kind=kind,requested=duration,elapsed=A.Now()-state.start,metrics=metrics};self.active=nil;host:SetScript('OnUpdate',nil);finish()end
  end)
  return true
 end
 p.book:HookScript('OnHide',function()m:Cancel(true)end)
 return m
end
