-- Native-projected scenic footprints. No persisted cache or guessed floor.
local _,ns=...;local N=ns.WardenNativeScene
local A={VERSION=81};ns.WardenSceneNavigation81=A
function A.Scenery(s)
 local spec=ns.WardenWorldScenes.navigation[s.key];if not spec or not spec.scenery then return{}end
 local shot=s.shot;local key=table.concat({s.drawWidth or 0,s.drawHeight or 0,unpack(shot.position)},':')..':'..table.concat(shot.target,':')..':'..shot.fov
 if s.sceneryNavigationKey==key and s.sceneryNavigation then return s.sceneryNavigation end
 local boxes={}
 for _,r in ipairs(spec.scenery)do
  local q=N.FloorFence(s.native.frame,shot,r.uv);if not q then return nil,'Waiting for native scenery floor registration'end
  local left,right,near,far=math.huge,-math.huge,math.huge,-math.huge
  for _,p in ipairs(q)do left=math.min(left,p[1]);right=math.max(right,p[1]);near=math.min(near,p[2]);far=math.max(far,p[2])end
  boxes[#boxes+1]={id='scenery/'..r.id,left=left,right=right,near=near,far=far,polygon=q,scenery=true}
 end
 s.sceneryNavigationKey=key;s.sceneryNavigation=boxes;return boxes
end
function A.PortalNavigation(v,s,a,ignore,wide)
 local nav,why=v:GroundNavigation(s,a);if not nav then return nil,why end
 local base={};for k,value in pairs(nav.base or nav)do base[k]=value end
 base.base=nil;base.obstacles={}
 for _,b in ipairs((nav.base or nav).obstacles or{})do if b.id~='scenery/'..tostring(ignore)then base.obstacles[#base.obstacles+1]=b end end
 if wide then base.polygon=N.FloorFence(s.native.frame,s.shot,wide);if not base.polygon then return nil,'Waiting for native entrance registration'end end
 return N.PeopleNavigation(base,s.native,a)
end
