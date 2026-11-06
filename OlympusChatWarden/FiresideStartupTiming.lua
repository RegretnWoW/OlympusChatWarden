-- Session-only startup timings. No history, private values or saved telemetry.
local _,ns=...
local T={VERSION=1,active=true,stages={}};ns.FiresideStartupTiming=T
local function clock(fn)
 if type(fn)~='function'then return end;local ok,v=pcall(fn);if ok and type(v)=='number'and v==v then return v end
end
function T.Begin(name,cooperative,force)
 if not T.active and not force then return end
 return {wall=clock(GetTime),cpu=not cooperative and clock(debugprofilestop),cooperative=cooperative}
end
function T.Finish(name,start,ok)
 if not start then return end
 local row=T.stages[name]or{calls=0,cpuMS=0,elapsed=0,failed=0};T.stages[name]=row;row.calls=row.calls+1
 local cpu,wall=clock(debugprofilestop),clock(GetTime)
 if cpu and start.cpu then row.cpuMS=row.cpuMS+math.max(0,cpu-start.cpu)end
 if start.cooperative then row.cooperative=true end
 if wall and start.wall then row.elapsed=row.elapsed+math.max(0,wall-start.wall)end
 if ok==false then row.failed=row.failed+1 end
end
-- Only synchronous entry points use this wrapper; yielding validation paths
-- mark their own boundaries and keep their existing coroutine structure.
function T.Wrap(fn,name,onceAfterReady)
 return function(...)
  if not T.active and(not onceAfterReady or T.stages[name])then return fn(...)end
  local start=T.Begin(name,false,onceAfterReady);local ok,a,b,c,d=pcall(fn,...);T.Finish(name,start,ok)
  if not ok then error(a,0)end;return a,b,c,d
 end
end
T.started=clock(GetTime);T.static=T.Begin('static Lua and data')
function T.Text()
 local out={'Fireside loading details · session only'}
 local elapsed=T.ready and T.started and T.ready-T.started or T.started and clock(GetTime)and clock(GetTime)-T.started
 out[#out+1]='Readiness gate: '..(T.ready and'cleared'or'waiting')..'; addon-side elapsed seconds: '..string.format('%.3f',elapsed or 0)
 local names={};for name in pairs(T.stages)do names[#names+1]=name end;table.sort(names)
 for _,name in ipairs(names)do local r=T.stages[name];local cpu=r.cooperative and'CPU not isolated across frames'or string.format('%.2f ms CPU',r.cpuMS);out[#out+1]=string.format('%s: %s / %.3f s elapsed / %d calls / %d failures',name,cpu,r.elapsed,r.calls,r.failed)end
 if not T.stages['Aether runtime construction']then out[#out+1]='Aether runtime construction: not started before the readiness measurement ended'end
 local i=ns.AthenaLoreBuildIndex and ns.AthenaLoreBuildIndex.metrics
 if i then out[#out+1]=string.format('Lore registration indexes: %d ID builds / %d NPC builds / %d ID visits',i.idBuilds,i.npcBuilds,i.idVisits)end
 local loader=ns.ChronicleStore and ns.ChronicleStore.LoadStatus and ns.ChronicleStore.LoadStatus()
 if loader then out[#out+1]=string.format('History worker: %.1f ms CPU / %.2f ms maximum slice / %d frames / %d resumes / %.3f s longest frame interval',loader.cpuMS or 0,loader.maxSliceMS or 0,loader.pumps or 0,loader.resumes or 0,loader.longestInterval or 0)end
 out[#out+1]='These stages can overlap. WoW file loading before this addon runs is not measured. No disk-loading speed or network delivery is inferred.'
 return table.concat(out,'\n')
end
