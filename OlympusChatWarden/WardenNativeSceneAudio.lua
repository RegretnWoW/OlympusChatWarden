-- Installed sound references use the existing bounded Warden voice controller.
-- No sound extraction, volume CVars, independent timers or real-unit footsteps.
local _,ns=...;local A,D,N=ns.WardenAudio,ns.WardenNativeAudioData,ns.WardenNativeScene
local J={VERSION=1,serial=0};ns.WardenNativeSceneAudio=J
-- Installed Forever reference, probed as 22050 Hz / 54393 samples. No audio distributed.
D.hearth={{fileID=569735,seconds=2.46680272,path='sound/spells/teleport.ogg'}}
D['hearth-cast']={{fileID=568938,seconds=2.97097506,path='sound/spells/precastmagelow.ogg'}}
for _,id in ipairs({'bird.call','bird.wings','owl.hoot','owl.wings','owl.land','animal.move','cat.purr','cat.move','wizard.cast'})do A.cues[id]=nil end
for _,id in ipairs({'bird','owl','rabbit','fox','stag','moth','cat','wizard','magic'})do A.profiles[id]=nil end
A.cues['cloth.flutter'].names={'cloth-a','cloth-b'}
function A.PlayNative(group,scope,quiet)
 local rows=D[group];if not rows or #rows==0 then return false,'No safe native sound for this actor'end
 local allowed,why=A.Status('environment','SFX');if not allowed then return false,why end
 if not A.CanTrack()then return false,A.lastError end
 local stamp=ns.SafeCall(GetTimePreciseSec)or ns.SafeCall(GetTime)or 0
 if A.nativeBackoff and stamp<A.nativeBackoff then return false,'Native playback retry cooldown'end
 local hearth=group=='hearth'or group=='hearth-cast'
 if not hearth and stamp<(A.nativeNext or 0)or #A.voices>=8 then return false,'Native sound density limit'end
 J.serial=J.serial+1;local row=rows[(J.serial-1)%#rows+1]
 local ok,playing,handle=pcall(PlaySoundFile,row.fileID,'SFX')
 if not ok or playing==false or not handle then
  if handle and type(StopSound)=='function'then pcall(StopSound,handle,0)end
  A.nativeBackoff=stamp+30;return false,'Client refused a stoppable native sound'
 end
 A.nativeNext=stamp+(quiet and .22 or .5)
 A.voices[#A.voices+1]={id='native.'..group,asset=row.fileID,handle=handle,scope=scope or'scene',group='environment',channel='SFX',untilAt=stamp+row.seconds}
 A.metrics.nativePlayed=(A.metrics.nativePlayed or 0)+1;return true
end
local function small(a)
 local p=a.spec.appearance;local race=p and p.raceID
 if not race and a.spec.unit=='player'then local _,_,id=ns.SafeCall(UnitRace,'player');race=id end
 return race==7 or race==9
end
function J.Tick(v,dt)
 local scene=v:ActiveRoom()
 if not scene or not scene.active or not v.frame:IsVisible()or ns.DB.journalReducedMotion or ns.DB.livingRealmAmbience==false or ns.Checked(ns.SafeCall(InCombatLockdown))or ns.WardenSceneEditor and ns.WardenSceneEditor.active then return end
 for _,a in ipairs(scene.native.order)do
  if a.ready and not a.retired and not a.failed and a.position and not a.editorHidden then
   local p=a.position;local old=a.lastSoundPosition;a.lastSoundPosition={p[1],p[2],p[3]}
   if N.IsPerson(a)then
    local r=a.route
    if r and not r.turn and not a.collisionWait and not a.seating and old and v:VisibleActor(scene,a)then
     local distance=math.sqrt((p[1]-old[1])^2+(p[2]-old[2])^2)
     if distance<.5 then a.stepDistance=(a.stepDistance or 0)+distance else a.stepDistance=0 end
     if(a.stepDistance or 0)>.5 and v.age>=(a.nextStepSound or 0)then
      a.stepDistance=0;a.nextStepSound=v.age+.32
      A.PlayNative('step-'..(small(a)and'small'or'mediumlarge')..'-'..(scene.definition and scene.definition.interior and'wood'or'grass'),'scene',true)
     end
    else a.stepDistance=0 end
   elseif a.spec.wildlife and a.route and v:VisibleActor(scene,a)then
    a.nextAnimalSound=a.nextAnimalSound or(v.age+15+ns.WardenWildlife.Random(v)*25)
    if v.age>=a.nextAnimalSound then
     a.nextAnimalSound=v.age+40+ns.WardenWildlife.Random(v)*45
     A.PlayNative(a.id,'scene',false)
    end
   end
  else a.lastSoundPosition=nil;a.stepDistance=0 end
 end
end
local attach=ns.WardenRealm.Attach
ns.WardenRealm.Attach=function(...)
 local v=attach(...);if not v.nativeAudioBound then v.nativeAudioBound=true
  local advance=v.Advance;v.Advance=function(self,dt)local out=advance(self,dt);J.Tick(self,dt);return out end
 end;return v
end
