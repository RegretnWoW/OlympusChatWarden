-- Adapted from WardenWorldRealm.lua SeatPlayer/UpdatePlayerSeat/LeavePlayerSeat/InteractPlayer
-- at base 9bc2326f67532c548102caa831b20af2234d6bfe. Keeps Fireside's approach,
-- settle/hold/leave states, seat offsets, animation selection, routing and clearance.
-- Only the production UI/preferences coupling and attendant ID are adapted.
local _,ns=...
local N=ns.WardenNativeScene
local I={};ns.ExperimentInteractions=I
local function moving()return not InCombatLockdown()end
function I.Bind(engine,shot,navigation)
 local s={native=engine,shot=shot,routeAt={}}
 local v={}
 function v:GroundNavigation(_,a)return navigation(a)end
 function v:SeatPlayer(s,a,intent)
  local prop=s.native.actors[intent.id];if not prop or not prop.ready or prop.editorHidden then a.motionStatus='Seat unavailable';return false end
  local p={unpack(a.position)};local target={unpack(p)};local yaw=a.yaw or 0
  if intent.kind=='chair'then
   target={prop.position[1],prop.position[2],prop.position[3]+prop.top*(prop.spec.seatFraction or .29)-a.top*.32+(prop.seatHeightOffset or 0)}
   yaw=(prop.worldYaw or 0)-(math.atan2(s.shot.target[2]-s.shot.position[2],s.shot.target[1]-s.shot.position[1])-math.pi*.5)
  else target[3]=target[3]+(prop.seatHeightOffset or 0);yaw=math.atan2(prop.position[2]-p[2],prop.position[1]-p[1])end
  a.seating={kind=intent.kind,id=intent.id,phase='settle',elapsed=0,duration=intent.kind=='chair'and 1.1 or 1,approach=p,from=p,to=target,fromYaw=a.yaw or yaw,delta=(yaw-(a.yaw or yaw)+math.pi)%(2*math.pi)-math.pi,animation=intent.animation}
  a.spec.worldYaw=nil;a.engine:Animate(a,intent.kind=='chair'and 4 or a.capabilities[96]and 96 or intent.animation,1)
  a.motionStatus='Taking a seat';return true
 end
 function v:UpdatePlayerSeat(s,a,dt)
  local state=a.seating;if not state or state.phase=='hold'or not moving()then return end
  state.elapsed=math.min(state.duration,state.elapsed+dt);local q=state.elapsed/state.duration;q=q*q*(3-2*q)
  local p,t=state.from,state.to
  local target={p[1]+(t[1]-p[1])*q,p[2]+(t[2]-p[2])*q,p[3]+(t[3]-p[3])*q}
  if not N.CanStep(a.engine,a,a.position,target)then state.elapsed=math.max(0,state.elapsed-dt);a.motionStatus='Waiting for chair clearance';return end
  a.engine:Place(a,target[1],target[2],target[3],state.fromYaw+state.delta*q)
  if state.elapsed<state.duration then return end
  if state.phase=='leaving'then
   a.seating=nil;a.engine:Animate(a,0,1);if a.spec.socialVisitor then if a.visit then a.visit.next=(self.rememberedVisitors.clock or 0)+1 end;return end;local after=state.after;if after then self:ClickScene(s,after[1],after[2])end
  else state.phase='hold';a.engine:Animate(a,state.animation,1);a.motionStatus=state.kind=='chair'and'Sitting on chair'or'Sitting at fire'end
 end
 function v:LeavePlayerSeat(s,a,u,y)
  local state=a.seating;if not state then return false end
  state.phase='leaving';state.elapsed=0;state.duration=.85;state.from={unpack(a.position)};state.to={unpack(state.approach)};state.fromYaw=a.yaw or 0;state.delta=0;state.after=u and{u,y}or nil
  a.engine:Animate(a,state.kind=='fire'and a.capabilities[98]and 98 or 4,1);a.motionStatus='Standing up';return true
 end
 function v:InteractPlayer(s,id)
  local a=s.native.actors.player;local prop=s.native.actors[id]
  if not a or not a.ready or not prop or not prop.ready or prop.editorHidden then return false,'Character or seat is not ready'end
  if not moving() then return false,'Scene interaction is paused'end
  local kind=prop.spec.interaction or(id=='chair'and'chair'or id=='firepit'and'fire');if not kind then return false,'Not a seat'end
  if a.seating and a.seating.id==id and a.seating.phase~='leaving'then return true end
  local animation=kind=='fire'and a.capabilities[97]and 97 or nil
  if kind=='chair'then for _,id in ipairs({102,103,104})do if a.capabilities[id]then animation=id;break end end end
  if not animation or not a.capabilities[4]then return false,'Required sitting or walking animation unavailable'end
  local nav,why=self:GroundNavigation(s,a);if not nav then return false,why end
  local box=N.Footprint(s.shot,prop);local p=prop.position;local margin=nav.radius+.15
  local candidates={{box.left-margin,p[2],0},{box.right+margin,p[2],0},{p[1],box.near-margin,0},{p[1],box.far+margin,0}}
  local best;for _,point in ipairs(candidates)do local path=N.WalkPath(a.position,point[1],point[2],nav);if path and(not best or path.length<best.length)then best=path end end
  if not best then return false,'No clear approach to seat'end
  a.seating=nil;a.restStage=nil;a.spec.worldYaw=nil;a.pendingInteraction={kind=kind,id=id,animation=animation};s.routeAt[a.id]=nil
  local yes;yes,why=a.engine:Route(a,best,math.max(2,best.length/N.WALK_SPEED+.65),4,nav)
  if not yes then a.pendingInteraction=nil;return false,why end
  return true
 end
 return v,s
end
