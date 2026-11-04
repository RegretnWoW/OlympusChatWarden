-- One owner-scoped scenic position. This is not gameplay/location evidence.
local _,ns=...;local P={VERSION=1};ns.WardenCanonicalPlayer=P
local function valid(row)
 if type(row)~='table'or getmetatable(row)or not ns.WardenRoomCatalogue.HasRoom(row.room)or type(row.position)~='table'then return false end
 for i=1,3 do local n=row.position[i];if type(n)~='number'or n~=n or math.abs(n)>(i==3 and 8 or 80)then return false end end
 return type(row.yaw)=='number'and row.yaw==row.yaw and math.abs(row.yaw)<100
end
function P.Update(engine,a)
 if not a.spec.controlled or a.spec.unit~='player'or not ns.UI2 or not ns.UI2.realm then return end
 local v=ns.UI2.realm;if v:ActiveRoom().native~=engine then return end
 local state=v.playerState;local owner=ns.Chronicle.Owner()
 if not state or state.owner~=owner then state={owner=owner,room=v.currentRoomKey,position={0,0,0},yaw=0};v.playerState=state end
 state.room=v.currentRoomKey;state.observed=true;for i=1,3 do state.position[i]=a.position[i]end;state.yaw=a.yaw or 0
end
function P.Save(v)
 local state=v.playerState;if not state or not state.observed or state.owner~=ns.Chronicle.Owner()or not valid(state)then return false,'No valid canonical position'end
 local bank=ns.DB.wardenScenePlayer
 if bank==nil then bank={version=1,owners={}};ns.DB.wardenScenePlayer=bank end
 if type(bank)~='table'or getmetatable(bank)or bank.version~=1 or type(bank.owners)~='table'or getmetatable(bank.owners)then return false,'Newer or malformed scenic state retained'end
 if not bank.owners[state.owner]then local n=0;for _ in pairs(bank.owners)do n=n+1 end;if n>=16 then return false,'Scenic owner budget; existing owners retained'end end
 bank.owners[state.owner]={room=state.room,position={unpack(state.position)},yaw=state.yaw};return true
end
function P.Restore(v)
 local owner=ns.Chronicle.Owner();local bank=ns.DB and ns.DB.wardenScenePlayer
 local saved=type(bank)=='table'and not getmetatable(bank)and bank.version==1 and type(bank.owners)=='table'and bank.owners[owner]
 if valid(saved)then
  v.currentRoomKey=saved.room;v.playerState={owner=owner,room=saved.room,position={unpack(saved.position)},yaw=saved.yaw,observed=true}
  local s=v:EnsureRoom(saved.room);s.pendingArrival={unpack(saved.position)};v.playerRestoreYaw=saved.yaw
 else v.playerState={owner=owner,room=v.currentRoomKey or'hall',position={0,0,0},yaw=0}end
end
function P.Bind(v,U)
 if v.canonicalPlayerBound then return end;v.canonicalPlayerBound=true;P.Restore(v)
 U.window:HookScript('OnHide',function()v.playerSaveOK,v.playerSaveReason=P.Save(v)end)
 local events=CreateFrame('Frame');events:RegisterEvent('PLAYER_LOGOUT');events:SetScript('OnEvent',function()v.playerSaveOK,v.playerSaveReason=P.Save(v)end);v.playerPersistenceEvents=events
 if ns.FiresideSavedData then ns.FiresideSavedData.Rearm()end
 local ready=v.ActorReady
 v.ActorReady=function(self,s,a,...)
  local out=ready(self,s,a,...)
  if a.spec.controlled and a.ready and s.key==self.currentRoomKey and self.playerRestoreYaw then a.engine:Place(a,a.position[1],a.position[2],a.position[3],self.playerRestoreYaw);self.playerRestoreYaw=nil end
  return out
 end
 local report=v.Report
 v.Report=function(self,...)
  local out=report(self,...);local loaded=0;for _,s in ipairs(self:Scenes())do for _,a in ipairs(s.native.order)do if a.spec.controlled and a.ready and not a.retired then loaded=loaded+1 end end end
  out.canonicalPlayer={version=1,state=ns.WardenRoomCatalogue.Copy(self.playerState),loadedPlayerModels=loaded,saveOK=self.playerSaveOK,saveReason=self.playerSaveReason,visitors='Separate remembered GUID identities; never share the local player state'};return out
 end
end
local attach=ns.WardenRealm.Attach
ns.WardenRealm.Attach=function(...)local v=attach(...);P.Bind(v,ns.UI2);return v end
