-- Sparse, owner-private travel observations in the existing Chronicle ledger.
-- A successful cast proves the cast, not destination arrival. Taxi samples prove
-- the observed state, not the exact instant of departure/landing.
local _,ns=...
local C,S=ns.Chronicle,ns.ChronicleStore
local T={VERSION=1,types={travel_observation=true},spells={[8690]='hearth'}};ns.ChronicleTravel=T
local actions={hearth=true,['taxi-start']=true,['taxi-end']=true,['session-start']=true,['session-end']=true}
local sources={UNIT_SPELLCAST_SUCCEEDED=true,PLAYER_CONTROL_LOST=true,PLAYER_CONTROL_GAINED=true,checkpoint=true,PLAYER_ENTERING_WORLD=true,PLAYER_LOGIN=true,PLAYER_LOGOUT=true}
local lastTaxi,lastTaxiAt,lastOwner,lastSession
function T.Valid(d)
 if d.recordType~='travel_observation'or not actions[d.direction]or not sources[d.method]or d.scope~='owner-private replay evidence'then return false end
 if d.direction=='hearth'and(d.spellID~=8690 or d.method~='UNIT_SPELLCAST_SUCCEEDED')then return false end
 if(d.mapID~=nil or d.uiX~=nil or d.uiY~=nil)and not(S.Integer(d.mapID,1,10000000)and S.Number(d.uiX,0,1)and S.Number(d.uiY,0,1))then return false end
 return d.firstAt==nil or S.Integer(d.firstAt,1)and S.Integer(d.lastAt,d.firstAt)and d.lastAt-d.firstAt<=6
end
function T.ValidRecord(e,owner)
 local d=e.details or{};return e.kind=='native_event'and e.character==owner and e.subject==owner:match('/(Player%-.+)$')and T.Valid(d)and e.source==d.method
  and(d.direction~='session-start'or(d.method=='PLAYER_ENTERING_WORLD'or d.method=='PLAYER_LOGIN')and d.loginConfirmed==true)
  and(d.direction~='session-end'or d.method=='PLAYER_LOGOUT')
  and(not d.direction:find('taxi',1,true)or({PLAYER_CONTROL_LOST=true,PLAYER_CONTROL_GAINED=true,checkpoint=true})[d.method])or false
end
local function write(action,source,position,firstAt)
 if not C.Active()or not C.PersonalEnabled()then return end
 local owner,guid=C.Owner();if not owner or not guid then return end
 local p=position or ns.ChronicleRoute.Position();local at=C.Stamp();if not at then return end
 local d={recordType='travel_observation',direction=action,method=source,scope='owner-private replay evidence',partial=true}
 if p and p.mapID and p.point[3]~=false and p.point[4]~=false then d.mapID=p.mapID;d.uiX=p.point[3];d.uiY=p.point[4];d.partial=false end
 if action=='hearth'then d.spellID=8690 elseif action=='session-start'then d.loginConfirmed=true end
 if not(firstAt and at>=firstAt and at-firstAt<=6)then firstAt=nil end
 if firstAt then d.firstAt=firstAt;d.lastAt=at end
 local direct=action=='hearth'or action=='session-start'or action=='session-end'
 local temporal={version=1,basis=direct and'callback'or'sample',precision=firstAt and'interval'or'second',eventAt=direct and at or nil,sampledAt=at,observedFrom=firstAt,observedTo=firstAt and at or nil}
 return C.Record('native_event',source,d,guid,action=='hearth'and'confirmed'or'observed',C.Place(),nil,nil,nil,nil,nil,temporal)
end
function T.Cast(spellID)if T.spells[spellID]then return write('hearth','UNIT_SPELLCAST_SUCCEEDED')end end
function T.Boundary(action,source,confirmed)
 if action=='session-start'and not confirmed then return end
 return write(action,source)
end
function T.Gap()lastTaxi,lastTaxiAt,lastOwner,lastSession=nil,nil,nil,nil end
function T.Taxi(position,source)
 if not C.Active()or not C.PersonalEnabled()then T.Gap();return end
 local owner=C.Owner();local ch=owner and S.WriterCharacter(owner,false);local session=ch and ch.currentSession
 if owner~=lastOwner or session~=lastSession then T.Gap();lastOwner,lastSession=owner,session end
 local state=ns.SafeCall(UnitOnTaxi,'player');if type(state)~='boolean'and state~=0 and state~=1 then return end;state=ns.Checked(state)
 local at=C.Stamp();if state~=lastTaxi and lastTaxi~=nil then write(state and'taxi-start'or'taxi-end',source or'checkpoint',position,lastTaxiAt)end
 lastTaxi,lastTaxiAt=state,at
end
function T.Handle(event)T.Taxi(nil,event)end
ns.ChronicleCapture.Register(T,{'PLAYER_CONTROL_LOST','PLAYER_CONTROL_GAINED'},'chronicle')
-- A missing position can be approximated only inside one short continuous leg.
function T.Position(e,map,a,b)
 local d=e.details or{};local native=ns.ChronicleReplay.Map(d.mapID,{})
 if native and native.id==map and S.Number(d.uiX,0,1)and S.Number(d.uiY,0,1)then local r=native.rect;return{x=r[1]+d.uiX*(r[2]-r[1]),y=r[3]+d.uiY*(r[4]-r[3]),approximate=false}end
 if not a or not b or not b.connect or a.event.session~=e.session or b.event.session~=e.session or a.event.character~=e.character or b.event.character~=e.character then return end
 if a.event.timeSource~=e.timeSource or b.event.timeSource~=e.timeSource or not S.Number(e.elapsed,a.point[2],b.point[2])then return end
 local am,bm=ns.ChronicleReplay.Map(a.mapID,{}),ns.ChronicleReplay.Map(b.mapID,{})
 if not am or not bm or am.id~=map or bm.id~=map then return end
 local first,last=a.point[1],b.point[1];if last<=first or last-first>4.01 or e.at<first or e.at>last then return end
 local q=(e.at-first)/(last-first);return{x=a.x+(b.x-a.x)*q,y=a.y+(b.y-a.y)*q,approximate=true}
end
