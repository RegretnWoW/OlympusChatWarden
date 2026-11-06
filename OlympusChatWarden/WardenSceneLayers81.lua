-- One logical actor survives a viewport-pass change. Previous model is cleared;
-- preserve route, world pose and animation phase while the cached model reloads.
local _,ns=...;local A={VERSION=81};ns.WardenSceneLayers81=A
function A.Stage(v,a,layer)
 if not a or not a.ready or a.layerRestore or not a.position or not a.engine.SetLayer or(a.renderLayer or'native')==layer then return false end
 local state={position={unpack(a.position)},yaw=a.yaw or 0,route=a.route,specAt=a.spec.at,anchor=a.floorAnchorHeld,
  animation=a.animation,rate=a.lastAnimationRate,clock=a.animationClock,notify=a.spec.socialVisitor and a.visit and a.visit.phase=='loading'}
 a.layerRestore=state;a.spec.at={unpack(state.position)};a.floorAnchorHeld=true
 local ok=a.engine:SetLayer(a,layer)
 if not ok then a.layerRestore=nil;a.spec.at=state.specAt;a.floorAnchorHeld=state.anchor;a.route=state.route;return false end
 v.sceneLayerChanges=(v.sceneLayerChanges or 0)+1;return true
end
local attach=ns.WardenRealm.Attach
ns.WardenRealm.Attach=function(...)
 local v=attach(...);if v.sceneLayers81 then return v end;v.sceneLayers81=true
 local ready,advance,seat=v.ActorReady,v.Advance,v.SeatPlayer
 v.ActorReady=function(self,s,a,...)
  local state=a.layerRestore;local controlled=a.spec.controlled;if state then a.spec.controlled=false end
  local result=ready(self,s,a,...);a.spec.controlled=controlled
  if state and a.ready and not a.retired then
   a.layerRestore=nil;a.spec.at=state.specAt;a.floorAnchorHeld=state.anchor
   a.engine:Place(a,state.position[1],state.position[2],state.position[3],state.yaw)
   a.route=state.route;a.engine:Animate(a,state.animation or 0,state.rate or 1,state.clock or 0)
   if state.notify and self.rememberedVisitors then self.rememberedVisitors:Ready(a)end
  elseif not state and a.ready and not a.retired and a.spec.nativePass and(a.renderLayer or'native')~=a.spec.nativePass then A.Stage(self,a,a.spec.nativePass)
  end;return result
 end
 v.SeatPlayer=function(self,s,a,intent)
  if intent.kind=='chair'then
   local reservation=self.rememberedVisitors and self.rememberedVisitors.reservations[s.key..'/'..intent.id]
   if reservation and reservation~=a.spec.sceneEntityID then a.motionStatus='Chair is in use';return false end
   for _,other in ipairs(s.native.order)do if other~=a and not other.retired and other.seating and other.seating.id==intent.id then a.motionStatus='Chair is occupied';return false end end
  end;return seat(self,s,a,intent)
 end
 v.Advance=function(self,dt)
  local result=advance(self,dt);local s=self:ActiveRoom()
  if s.key~='square'or self.campfireWelcome or self.closeupMode or self.age<(self.sceneLayerAt or 0)then return result end
  self.sceneLayerAt=self.age+.08
  for _,a in ipairs(s.native.order)do if a.ready and not(a.retired or a.failed or a.layerRestore)and a.position and(a.spec.controlled or a.spec.socialVisitor or a.spec.liveRemote or a.spec.canonicalNPC)then
   local phase=a.visit and a.visit.phase;local desired
   if phase=='entering'and not a.visit.emerged then desired='portal-native'
   else local u,w=ns.WardenNativeScene.AuthoredUV(s.native.frame,s.shot,a.position[1],a.position[2],0)
    desired=u and u>.24 and u<.53 and w<.64 and'town-behind-fountain'or'native'
   end
   if A.Stage(self,a,desired)then break end
  end end;return result
 end
 return v
end
