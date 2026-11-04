-- Local scenic Hearthstone choreography. Never casts a real/protected spell.
-- Spell8690 supplies the client cast time; installed Forever model/sound refs
-- are metadata-checked. Native visual/audible parity still requires inspection.
local _,ns=...
local H={VERSION=1,SPELL=8690,CAST_SOUND_SECONDS=2.97097506,EFFECT_SECONDS=1.5};ns.WardenHearth=H
local N=ns.WardenNativeScene
local function clock()return ns.SafeCall(GetTimePreciseSec)or ns.SafeCall(GetTime)end
local function duration(ms)
 local ok,n=pcall(function()if issecretvalue and issecretvalue(ms)then return end;return tonumber(ms)end)
 if ok and type(n)=='number'and n==n and n>=1000 and n<=30000 then return n/1000 end
end
function H.CastTime()
 if C_Spell and type(C_Spell.GetSpellInfo)=='function'then
  local info=ns.SafeCall(C_Spell.GetSpellInfo,H.SPELL)
  if type(info)=='table'then local seconds=duration(info.castTime);if seconds then return seconds,'C_Spell.GetSpellInfo(8690)'end end
 end
 if type(GetSpellInfo)=='function'then
  -- SafeCall intentionally returns only one value; legacy castTime is fourth.
  local ok,_,_,_,ms=pcall(GetSpellInfo,H.SPELL);local seconds=ok and duration(ms);if seconds then return seconds,'GetSpellInfo(8690)'end
 end
 if C_Spell and type(C_Spell.RequestLoadSpellData)=='function'then pcall(C_Spell.RequestLoadSpellData,H.SPELL)end
 return nil,'Waiting for the client Hearthstone spell data; try again shortly'
end
function H.Begin(state,v,seconds,source)
 local a=state.scene.native.actors.attendant
 local h={spellID=H.SPELL,seconds=seconds,castTimeSource=source,elapsed=0,started=clock(),animationSupported=a and a.ready and a.capabilities[52]==true and a.capabilities[54]==true or false,
  verification='Installed references and API requests; native appearance/audio not certified'};state.hearth=h
 if a and a.ready and a.position then
  state.actor=a;a.route=nil;a.seating=nil;a.pendingInteraction=nil;a.restStage=nil;a.manualUntil=v.age+seconds+H.EFFECT_SECONDS+2
  a.engine:Place(a,a.position[1],a.position[2],a.position[3],a.yaw)
  if h.animationSupported and not ns.DB.journalReducedMotion then a.engine:Animate(a,52,1)end
  -- One reusable actor slot. Preload for the whole cast, hidden until completion.
  if not ns.DB.journalReducedMotion and a.engine.LoadProp then
   h.effect=a.engine:LoadProp({id='hearth-teleport',fileID=167094,effect=true,custom=true,scale=1,collisionRadius=0,at={unpack(a.position)}})
   if h.effect then h.effect.sceneHidden=true;N.Call(h.effect.actor,'Hide')end
  end
 end
 H.CastSound(h)
 return h
end
function H.CastSound(h)
 local played,why=ns.WardenAudio.PlayNative('hearth-cast','hearth')
 h.soundRequested=h.soundRequested or played==true;h.soundStatus=why
 h.nextSound=h.elapsed+(played and H.CAST_SOUND_SECONDS or .5)
end
function H.Cleanup(state,keepCompletion)
 local h=state and state.hearth;if not h then return end
 if not keepCompletion then ns.WardenAudio.Stop('hearth')end
 if h.effect then h.effect.sceneHidden=true;h.effect.engine:Retire(h.effect);h.effect=nil end
 if state.actor then state.actor.manualUntil=nil end
end
function H.Tick(state,dt)
 local h=state.hearth
 h.elapsed=h.elapsed+math.max(0,math.min(60,tonumber(dt)or 0))
 local now=clock();if type(now)=='number'and type(h.started)=='number'and now>=h.started then h.elapsed=math.max(h.elapsed,now-h.started)end
 if not h.completed and h.elapsed>=h.seconds then
  h.completed=true;h.completedAt=h.seconds;ns.WardenAudio.Stop('hearth')
  local a=state.actor
  if a and a.ready and h.animationSupported and not ns.DB.journalReducedMotion then a.engine:Animate(a,54,1)end
  local played,why=ns.WardenAudio.PlayNative('hearth','hearth');h.completionSoundRequested=played==true;h.completionSoundStatus=why
  local fx=h.effect
  if fx and fx.ready and not fx.failed and a and a.position and not ns.DB.journalReducedMotion then
   fx.sceneHidden=nil;fx.engine:Place(fx,unpack(a.position));N.Call(fx.actor,'SetAlpha',1);N.Call(fx.actor,'Show')
   local ok,value=N.Call(fx.actor,'SetAnimation',0,0,1,0);h.effectRequested=ok and value~=false
  else h.effectStatus=ns.DB.journalReducedMotion and'Reduced motion'or'Installed teleport emitter not ready'end
 elseif not h.completed and h.elapsed>=(h.nextSound or 0)then
  ns.WardenAudio.Stop('hearth');H.CastSound(h)
 end
 if h.completed and h.elapsed>=h.seconds+(ns.DB.journalReducedMotion and .15 or H.EFFECT_SECONDS)then H.Cleanup(state,true);return true end
 return false
end
