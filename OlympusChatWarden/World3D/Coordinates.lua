-- Scene-specific transform boundary from the in-client tested prototype.
local _,ns=...
local N,C=ns.WardenNativeScene,ns.WardenSceneObjectControls
local W={VERSION=1,FLOOR_Z=0};ns.Fireside3D.Coordinates=W
function W.Bind(engine)
 engine.world3D=true;engine.roomKey='fireside-3d'
 engine.coordinateSpace='world XYZ; camera-independent'
 engine.legacyScreenCorrections=false;engine.legacyShadows=false
 -- Reuse native loading/animation/routing, replacing only this scene's placement boundary.
 local refresh=engine.RefreshPlayer
 if refresh then engine.RefreshPlayer=function(self,a,...)if a then a.worldAnchor=nil end;return refresh(self,a,...)end end
 function engine:Place(a,x,y,z,yaw,pitch)
  if not a or not a.ready then return false end
  local scale=a.scale
  assert(type(scale)=='number' and scale>0,'Invalid model scale')
  -- A fixed model-space anchor, captured at load, keeps feet/prop bases at their world point.
  -- This is geometric pivot alignment, not screen-space or distance-dependent compensation.
  if not a.worldAnchor then a.worldAnchor={(a.bounds[1]+a.bounds[4])*.5,(a.bounds[2]+a.bounds[5])*.5,a.bounds[3]} end
  local anchor=a.worldAnchor;local angle=yaw or a.worldYaw or 0
  local cx,cy=anchor[1]*scale,anchor[2]*scale
  local ox=x-math.cos(angle)*cx+math.sin(angle)*cy
  local oy=y-math.sin(angle)*cx-math.cos(angle)*cy
  local oz=z-anchor[3]*scale
  -- Preserve the existing native API's model-scaled translation convention ONLY at this boundary.
  -- No camera, FOV, viewport, floorUV, groundOffset, view-layer or depth-size term is used.
  local nx,ny,nz=ox/scale,oy/scale,oz/scale
  local ok=N.Call(a.actor,'SetPosition',nx,ny,nz)
  local turned=N.Call(a.actor,'SetYaw',angle)
  N.Call(a.actor,'SetPitch',pitch or 0);N.Call(a.actor,'SetRoll',0)
  a.presentationFactor=1;a.renderScale=scale;a.groundOffset=0
  a.worldYaw=angle;a.yaw=angle;a.pitch=pitch or 0
  a.position={x,y,z};a.worldPosition=a.position
  a.nativeOrigin={ox,oy,oz};a.nativePosition={nx,ny,nz}
  self.metrics.moves=self.metrics.moves+1
  if ns.WardenCanonicalPlayer then ns.WardenCanonicalPlayer.Update(self,a)end
  return ok and turned
 end
 return engine
end
-- Fit the same plane homography used by N.FloorPoint, using four actual native projections.
-- Once per frame, no mathematical-FOV fallback and no camera-sensitive actor changes.
function W.FloorMap(frame,shot)
 local function project(x,y)return N.ProjectNative(frame,shot,x,y,W.FLOOR_Z)end
 local x0,y0=project(0,0);local x1,y1=project(2,0);local x2,y2=project(0,2);local x3,y3=project(2,2)
 if not(x0 and x1 and x2 and x3)then return nil,'Native floor projection unavailable' end
 local ax,bx,cx=x1-x3,x2-x3,x0-x1+x3-x2
 local ay,by,cy=y1-y3,y2-y3,y0-y1+y3-y2
 local det=ax*by-bx*ay;if math.abs(det)<1e-12 then return nil,'Degenerate native floor projection' end
 local g,h=(cx*by-bx*cy)/det,(ax*cy-cx*ay)/det
 local a,b,c=x1-x0+g*x1,x2-x0+h*x2,x0
 local d,e,f=y1-y0+g*y1,y2-y0+h*y2,y0
 local view=frame.firesideViewShot or shot;local eye,target=view.position,view.target
 local fx,fy,fz=target[1]-eye[1],target[2]-eye[2],target[3]-eye[3]
 local length=math.sqrt(fx*fx+fy*fy+fz*fz)
 if length<.0001 then return nil,'Degenerate camera direction' end
 return function(u,v)
  local ar,ad,br,bd=a-u*g,b-u*h,d-v*g,e-v*h
  local determinant=ar*bd-ad*br;if math.abs(determinant)<1e-12 then return end
  local x,y=2*((u-c)*bd-ad*(v-f))/determinant,2*(ar*(v-f)-br*(u-c))/determinant
  -- Bound the background plane; there is no navigation or shadow in screen coordinates.
  if x~=x or y~=y or math.abs(x)>512 or math.abs(y)>512 then return end
  -- A projective inverse also describes the plane behind the eye; reject that branch.
  local depth=((x-eye[1])*fx+(y-eye[2])*fy+(W.FLOOR_Z-eye[3])*fz)/length
  if depth<=.01 then return end
  return x,y
 end
end
