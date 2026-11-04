-- Native multi-pass scenes own presentation. Legacy sliding 2D actors are disabled.
local _,ns=...
ns.WardenRealm={VERSION=3,legacy2DDisabled=true}
local R=ns.WardenRealm
function R.ClockStep(clock,elapsed,t)
 t=t or ns.SafeCall(GetTimePreciseSec)or ns.SafeCall(GetTime)or 0;local d=0
 if type(t)=='number'and t==t then if clock.last and t>clock.last then d=math.min(.25,t-clock.last)end;clock.last=t end
 if d==0 and type(elapsed)=='number'and elapsed==elapsed then d=math.max(0,math.min(.25,elapsed))end;return d
end
