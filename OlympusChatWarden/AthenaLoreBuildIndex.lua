-- Transient indexes shared only while the bundled lore segments register.
-- Append-only registration advances the same maps; final Codex owns its maps.
local _,ns=...
local I={metrics={calls=0,idVisits=0,npcVisits=0,idBuilds=0,npcBuilds=0}};ns.AthenaLoreBuildIndex=I
local state
function I.Get(withNPC)
 local timing=ns.FiresideStartupTiming;local start=timing and timing.Begin('lore registration indexes')
 local d=assert(ns.AthenaLoreCodexInput,'Lore registration source unavailable')
 if not state or state.source~=d then state={source=d,byID={},byNPC={},count=0};I.metrics.idBuilds=I.metrics.idBuilds+1 end
 I.metrics.calls=I.metrics.calls+1
 for i=state.count+1,#d.entries do
  local e=d.entries[i];state.byID[e.id]=e;I.metrics.idVisits=I.metrics.idVisits+1
  if state.npcReady then for _,id in ipairs(e.npcIDs or{})do state.byNPC[id]=e end end
 end
 state.count=#d.entries
 if withNPC and not state.npcReady then
  for _,e in ipairs(d.entries)do for _,id in ipairs(e.npcIDs or{})do state.byNPC[id]=e end;I.metrics.npcVisits=I.metrics.npcVisits+1 end
  state.npcReady=true;I.metrics.npcBuilds=I.metrics.npcBuilds+1
 end
 if timing then timing.Finish('lore registration indexes',start)end
 return state.byID,state.byNPC
end
function I.Release()state=nil;I.released=true end
