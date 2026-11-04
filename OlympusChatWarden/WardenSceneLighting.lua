-- Realm-clock selection happens only on scene entry. No epoch-hour guessing,
-- per-frame clock query, persisted preview, or lighting changes during reading.
local _,ns=...
local L={VERSION=1,boundaries={dawn=5,day=8,dusk=17,night=20}};ns.WardenSceneLighting=L
local function finite(v,lo,hi)v=ns.SafeNumber(v);return v and v>=lo and v<=hi end
local function read()
 local ok,t=pcall(function()if C_DateAndTime and type(C_DateAndTime.GetCurrentCalendarTime)=='function'then return C_DateAndTime.GetCurrentCalendarTime()end end)
 if ok and ns.Readable(t)and type(t)=='table'and finite(t.hour,0,23)and finite(t.minute,0,59)then return t.hour*60+t.minute,'calendar'end
 if type(GetGameTime)=='function'then local ok,h,m=pcall(GetGameTime);if ok and finite(h,0,23)and finite(m,0,59)then return h*60+m,'game-time'end end
 return nil,'unavailable'
end
function L.Classify(minutes)
 local h=(minutes%1440)/60;local b=L.boundaries
 if h>=b.night or h<b.dawn then return'night'end
 if h>=b.dusk then return'dusk'end
 return h>=b.day and'day'or'dawn'
end
function L.Open()
 local minutes,source=read();local t=ns.SafeCall(GetTime)or 0;local inside=ns.SafeCall(IsInInstance)==true
 if inside and L.realmAnchor then
  local expected=(L.realmAnchor.minutes+(t-L.realmAnchor.at)/60)%1440
  local delta=minutes and math.abs((minutes-expected+720)%1440-720)or 1440
  if delta>90 then minutes=expected;source='realm-anchor-during-instance'end
 elseif minutes then L.realmAnchor={minutes=minutes,at=t}end
 L.minutes,L.source=minutes,source;L.state=minutes and L.Classify(minutes)or L.state or'day';L.verifiedClock=minutes~=nil;L.session=(L.session or 0)+1
 return L.override or L.state
end
function L.Current()return L.override or L.state or L.Open()end
function L.Override(state)
 if not(ns.WardenSimLab and ns.WardenSimLab.Enabled())then return false end
 if state~=nil and not({dawn=true,day=true,dusk=true,night=true})[state]then return false end
 L.override=state;if not state then L.Open()end
 local v=ns.UI2 and ns.UI2.realm;if v then v:ApplyLighting(L.Current())end;return true
end
function L.ActorTint(state,interior)
 local p=interior and{dawn={1,.89,.77},day={1,1,1},dusk={1,.77,.55},night={.80,.70,.58}}or{dawn={.96,.80,.73},day={1,1,1},dusk={.85,.59,.46},night={.37,.46,.64}}
 return unpack(p[state]or p.day)
end
