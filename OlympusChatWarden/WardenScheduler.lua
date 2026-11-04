-- Cooperative UI-thread work, deduplicated and idle when empty. Capture stays immediate.
local _,ns=...
local S={VERSION=1,jobs={},limit=64,sequence=0,completed=0,errors=0,cancelled=0,maxCallbackMS=0};ns.WardenScheduler=S
local frame=CreateFrame('Frame');local ranks={interactive=1,network=2,low=3,opportunistic=4}
function S.Cancel(key)
 local job=S.jobs[key]
 if job then
  S.jobs[key]=nil;S.cancelled=S.cancelled+1
  if type(job.options.onCancel)=='function' then pcall(job.options.onCancel) end
 end
 if not next(S.jobs) then frame:SetScript('OnUpdate',nil) end
end
function S.Submit(key,priority,step,options)
 if type(key)~='string' or #key>128 or type(step)~='function' or not ranks[priority] then return false end
 if not S.jobs[key] and ns.Athena2.Count(S.jobs)>=S.limit then return false,'BUSY' end
 S.sequence=S.sequence+1;S.jobs[key]={key=key,priority=priority,step=step,options=options or {},order=S.sequence}
 frame:SetScript('OnUpdate',function() S.Pump() end);return true
end
function S.Pump()
 local P=ns.WardenPerformance;local deadline,start=P.Begin(2);local combat=InCombatLockdown and InCombatLockdown();local used={}
 for _=1,16 do
  if P.Expired(deadline) then break end
  local chosen
  for key,j in pairs(S.jobs) do if not used[key] and (not combat or j.options.combat==true and j.priority=='interactive') then
   if not chosen or ranks[j.priority]<ranks[chosen.priority] or j.priority==chosen.priority and j.order<chosen.order then chosen=j end
  end end
  if not chosen then break end;used[chosen.key]=true
  local j=chosen
  local permitted=not j.options.module or (j.priority=='network' or j.options.module=='relay') and ns.Permissions.Background(j.options.module) or ns.Athena2.Permit(j.options.module)
  if not permitted then S.Cancel(j.key)
  else
   local ok,done=pcall(j.step,deadline,combat)
   if not ok then S.errors=S.errors+1;S.lastError=tostring(done):sub(1,180);S.Cancel(j.key)
   elseif done and S.jobs[j.key]==j then S.jobs[j.key]=nil;S.completed=S.completed+1 end
  end
 end
 local finish=P.Now();if start and finish then S.maxCallbackMS=math.max(S.maxCallbackMS,finish-start) end
 P.End('shared scheduler',start,ns.Athena2.Count(used))
 if not next(S.jobs) then frame:SetScript('OnUpdate',nil) end
end
function S.Health() return {pending=ns.Athena2.Count(S.jobs),completed=S.completed,errors=S.errors,cancelled=S.cancelled,maxCallbackMS=S.maxCallbackMS,lastError=S.lastError} end
