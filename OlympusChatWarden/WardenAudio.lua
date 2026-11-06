-- Single bounded audio controller; no game CVar changes. One visible-context music owner.
local _,ns=...
local A={VERSION=9,last={},voices={},actors={},serial=0,metrics={played=0,cooldown=0,density=0,unsupported=0}};ns.WardenAudio=A
local base='Interface\\AddOns\\OlympusChatWarden\\Media\\Journal3\\Audio\\'
local assets=ns.WardenAudioAssets
local function time()return ns.SafeCall(GetTimePreciseSec)or ns.SafeCall(GetTime)or 0 end
local function flag(k)return not ns.DB or ns.DB[k]~=false end
local function cvar(k)local v=ns.SafeCall(GetCVar,k);if v=='0'or v==false then return false elseif v=='1'or v==true then return true end end
local function cue(names,group,cooldown)return{names=names,group=group,cooldown=cooldown or .16}end
A.cues={
 ['book.open']=cue({'clasp-a','clasp-b'},'journal'),['book.leather']=cue({'cover-open','leather-a'},'journal'),['book.settle']=cue({'cover-settle'},'journal'),
 ['book.close']=cue({'cover-close'},'journal'),['book.clasp']=cue({'clasp-a','clasp-b'},'journal'),['book.page']=cue({'paper-a','paper-b','paper-c','paper-d'},'journal'),['book.page.end']=cue({'cover-settle'},'journal',.3),
 tab=cue({'ui-a','ui-b'},'interface',.14),button=cue({'clasp-a','clasp-b'},'interface',.10),['ui.open']=cue({'fabric-a'},'interface',.4),['ui.close']=cue({'cloth-a'},'interface',.4),
 ['art.place']=cue({'metal-a'},'interface'),['art.metal']=cue({'metal-a'},'discovery',1),['art.fabric']=cue({'cloth-a','cloth-b','cloth-c'},'interface'),['draft.save']=cue({'ui-a'},'interface'),
 ['art.discover']=cue({'reward'},'discovery',1.5),notification=cue({'notice'},'interface',2),test=cue({'notice'},'test',1),
 ['forest.bed']=cue({'forest-air'},'environment',1),['study.bed']=cue({'study-air'},'environment',1),['study.music']=cue({'study-hearth-loop'},'music',1),['study.outro']=cue({'study-outro'},'music',1),candle=cue({'candle-bed'},'environment',1),
 ['wind.gust']=cue({'gust-1','gust-2'},'environment',18),['cloth.flutter']=cue({'wing-1','wing-2'},'environment',12),
 ['bird.call']=cue({'bird-1','bird-2','bird-3'},'environment',18),['bird.wings']=cue({'wing-1','wing-2'},'environment',10),
 ['owl.hoot']=cue({'owl-hoot'},'environment',38),['owl.wings']=cue({'wing-1','wing-2'},'environment',4),['owl.land']=cue({'rustle-1'},'environment',10),
 ['animal.move']=cue({'rustle-1','rustle-2'},'environment',8),['cat.purr']=cue({'purr-1','purr-2','purr-3'},'environment',22),['cat.move']=cue({'wing-1','wing-2'},'environment',12),
 ['wizard.cast']=cue({'spell-1','spell-2'},'environment',12),
 ['travel.hearth']=cue({'spell-1','spell-2'},'interface',2),['travel.flight']=cue({'wing-1','gust-1'},'interface',2),['travel.session']=cue({'notice'},'interface',2)}
-- Entitlement, presence and animation-state rules live in this one registry.
A.profiles={
 bird={reward='bird',flight={{.14,'bird.wings'},{.42,'bird.call'}}},owl={reward='owl',flight={{.08,'owl.wings'}},perch={{.38,'owl.hoot'}}},
 rabbit={reward='rabbit',move={{.20,'animal.move'}}},fox={reward='fox',move={{.22,'animal.move'}}},stag={reward='stag',move={{.20,'animal.move'}}},
 moth={reward='moth',silent=true},wizard={reward='wizard',cast={{.31,'wizard.cast'}}},magic={reward='wizard',cast={{.22,'wizard.cast'}}},
 guild={reward='guild',gust={{.38,'cloth.flutter'}}},alliance={reward='alliance',gust={{.38,'cloth.flutter'}}},
 foliage={permanent=true,gust={{.42,'wind.gust'}}},cat={reward='cat',rest={{.10,'cat.purr'}},react={{.30,'cat.purr'}},groom={{.20,'cat.move'}},stretch={{.22,'cat.move'}}}}
function A.Volume()local v=ns.DB and ns.DB.wardenSoundVolume;if type(v)~='number'or v~=v then v=50 end;if v<=0 then return 0 end;return math.max(25,math.min(100,math.floor(v/25+.5)*25))end
function A.MusicEnabled()return flag('wardenMusic')end
function A.SetMusicEnabled(value)
 if type(value)~='boolean'or not ns.DB then return false,'Choose music on or off.'end
 ns.DB.wardenMusic=value
 if value then A.musicSuppressed=nil;A.completedCinematic=nil end
 A.PreferencesChanged();return true
end
function A.Status(group,channel)
 if not flag('wardenPhysicalSounds')or A.Volume()==0 then return false,'Fireside sound is muted.'end
 if cvar('Sound_EnableAllSound')==false then return false,'WoW sound is muted.'end
 local music=group=='music'or group=='outdoorMusic'or group=='menuMusic'or group=='cinematicMusic'
 channel=channel or(music and'Music'or group=='environment'and'Ambience'or'SFX')
 local enable=channel=='Music'and'Sound_EnableMusic'or channel=='Ambience'and'Sound_EnableAmbience'or'Sound_EnableSFX'
 local gain=channel=='Music'and'Sound_MusicVolume'or channel=='Ambience'and'Sound_AmbienceVolume'or'Sound_SFXVolume'
 if cvar(enable)==false or tonumber(ns.SafeCall(GetCVar,gain))==0 then return false,'The WoW '..channel..' channel is muted.'end
 if music and not A.MusicEnabled()then return false,'Fireside music is off.'end
 if group=='environment'and not flag('wardenEnvironmentalAmbience')then return false,'Environmental Ambience is off.'end
 if not music and group~='environment'and not flag('wardenInteractionSounds')then return false,'Interaction Sounds are off.'end
 if group=='journal'and not flag('wardenJournalSounds')or group=='interface'and not flag('wardenInterfaceSounds')or group=='discovery'and not flag('wardenDiscoverySounds')then return false,'This sound group is off.'end
 if music then
  if type(PlayMusic)~='function'or type(StopMusic)~='function'then return false,'Native music takeover/release is unavailable.'end
 elseif type(PlaySoundFile)~='function'then return false,'Sound-file playback is unavailable.'end
 return true,channel..' channel · '..A.Volume()..'% Fireside gain · game preferences apply.'
end
local function stop(v)if v.handle and type(StopSound)=='function'then pcall(StopSound,v.handle,120)end end
function A.Stop(scope)if(not scope or scope=='music')and A.ReleaseStudyMusic then A.ReleaseStudyMusic()end;for i=#A.voices,1,-1 do local v=A.voices[i];if not scope or v.scope==scope then stop(v);table.remove(A.voices,i)end end end
local frame=CreateFrame('Frame');local update
local function wake()if not frame:GetScript('OnUpdate')then frame:SetScript('OnUpdate',function()update()end)end end
function A.CanTrack()
 if A.handleCapability~=nil then return A.handleCapability end
 if type(PlaySoundFile)~='function'or type(StopSound)~='function'then A.handleCapability=false;return false end
 local ok,played,handle=pcall(PlaySoundFile,base..'handle-probe-50.ogg','SFX')
 A.handleCapability=ok and played==true and handle~=nil
 if A.handleCapability then pcall(StopSound,handle,0)else A.lastError='This client does not provide stoppable sound handles. Ambience, actor audio and music are unavailable here.'end
 return A.handleCapability
end
function A.Play(id,scope)
 local c=A.cues[id];if not c then return false,'Unknown sound cue.'end
 local ok,why=A.Status(c.group);if not ok then return false,why end
 local stamp=time();if stamp-(A.last[id]or-1000)<c.cooldown then A.metrics.cooldown=A.metrics.cooldown+1;return false,'Sound cooldown.'end
 if A.backoff and stamp<A.backoff then return false,'Playback retry cooling down.'end
 if(c.group=='environment'or c.group=='music')and not A.CanTrack()then A.metrics.unsupported=A.metrics.unsupported+1;return false,A.lastError end
 for i=#A.voices,1,-1 do if A.voices[i].untilAt<=stamp then table.remove(A.voices,i)end end
 if #A.voices>=8 or c.group=='environment'and stamp<(A.nextAmbient or 0)then A.metrics.density=A.metrics.density+1;return false,'Sound density limit.'end
 A.serial=A.serial+1;local name=c.names[(A.serial-1)%#c.names+1];local asset=assets[name]
 if not asset then A.lastError='Missing sound definition: '..name;return false,A.lastError end
 local channel=c.group=='environment'and'Ambience'or c.group=='music'and'Music'or'SFX'
 local success,playing,handle=pcall(PlaySoundFile,base..(asset.file or name)..'-'..A.Volume()..'.'..asset.extension,channel)
 if not success or playing==false then A.lastError='The client refused '..id;A.backoff=stamp+30;return false,A.lastError end
 A.last[id]=stamp;A.voices[#A.voices+1]={id=id,asset=name,group=c.group,handle=handle,scope=scope or c.group,untilAt=stamp+asset.seconds,channel=channel}
 if c.group=='environment'and id~='forest.bed'and id~='study.bed'and id~='candle'then A.nextAmbient=stamp+2.4 end
 A.metrics.played=A.metrics.played+1;A.lastError=nil;wake();return true,'Playback requested; audibility depends on the client and output device.'
end
local function voice(scope)for _,v in ipairs(A.voices)do if v.scope==scope then return v end end end
-- Native music handoff: no zone playlist reconstruction or global volume changes.
function A.ReleaseStudyMusic()
 if not A.musicOwned then return false end
 A.musicOwned=false;A.musicGain=nil;A.musicTrack=nil;A.musicEndsAt=nil;A.inMusicCall=true
 if type(StopMusic)=='function'then pcall(StopMusic)end
 A.inMusicCall=nil;return true
end
-- Menu/world/cinematic share a single native soundtrack. Window size never gates it.
-- Full-file fallback; WardenMusic adds bounded crossfade/resume cue playback.
function A.MusicRequest()
 local U=ns.UI2;local movie=U and U.realm and U.realm.campfireWelcome
 if not movie then A.completedCinematic=nil end
 if not(A.realm and A.realm.frame:IsVisible())then return end
 if movie and movie.phase=='read'and movie~=A.completedCinematic then return 'warden-cinematic-action','cinematicMusic',movie end
 local intro=ns.WardenWelcomeGuide and ns.WardenWelcomeGuide.state
 if intro and intro.phase~='setup'then return 'warden-menu-theme','menuMusic'end
 if U and U.window and U.window:IsVisible()and not U.menuHidden then return 'warden-menu-theme','menuMusic'end
 if A.scene=='study'or A.scene=='town'then return 'study-hearth-loop','music'end
 if A.scene=='forest'then return 'roads-olympus-master','outdoorMusic'end
end
function A.UpdateStudyMusic()
 local track,group,token=A.MusicRequest()
 if track~=A.musicRequest or token~=A.musicToken then A.ReleaseStudyMusic();A.musicSuppressed=nil;A.musicRequest=track;A.musicToken=token end
 local allowed,why=A.Status(group or 'music','Music')
 if not track or not allowed then A.ReleaseStudyMusic();return false,why end
 if A.musicSuppressed then return false,'Another music action has taken control.'end
 local asset=assets[track];local stamp=time()
 if not asset or type(asset.seconds)~='number'or asset.seconds~=asset.seconds or asset.seconds<=0 or asset.seconds>3600 then A.ReleaseStudyMusic();A.musicError='Invalid soundtrack metadata.';return false,A.musicError end
 local renew=A.musicOwned and A.musicGain==A.Volume()and A.musicTrack==track and A.musicEndsAt and stamp>=A.musicEndsAt
 if renew and not asset.loop then A.completedCinematic=token;A.ReleaseStudyMusic();return false,'Cinematic cue completed.'end
 if A.musicOwned and A.musicGain==A.Volume()and A.musicTrack==track and not renew then return true end
 if not renew then A.ReleaseStudyMusic()end;A.Stop('study-outro');A.inMusicCall=true
 local ok,result=pcall(PlayMusic,base..(asset.file or track)..'-'..A.Volume()..'.ogg');A.inMusicCall=nil
 if not ok or result==false then A.musicError='The client refused scene music.';A.musicSuppressed=true;return false,A.musicError end
 A.musicOwned=true;A.musicGain=A.Volume();A.musicTrack=track;A.musicEndsAt=stamp+asset.seconds;A.musicError=nil
 A.metrics.musicRequests=(A.metrics.musicRequests or 0)+1;if renew then A.metrics.musicRenewals=(A.metrics.musicRenewals or 0)+1 end
 wake();return true
end
function A.ExternalMusicAction()
 if not A.inMusicCall then if A.OnExternalMusic then A.OnExternalMusic()end;A.musicOwned=false;A.musicGain=nil;A.musicTrack=nil;A.musicEndsAt=nil;A.musicSuppressed=A.musicRequest~=nil end
end
if type(hooksecurefunc)=='function'then
 if type(PlayMusic)=='function'then pcall(hooksecurefunc,'PlayMusic',A.ExternalMusicAction)end
 if type(StopMusic)=='function'then pcall(hooksecurefunc,'StopMusic',A.ExternalMusicAction)end
end
function A.Scene(realm,scene)
 local changed=A.realm~=realm or A.scene~=scene
 if changed then A.musicSuppressed=nil end
 if changed then A.Stop('scene');A.Stop('candle');for id in pairs(A.actors)do A.Stop('actor:'..id)end;A.actors={}end
 A.realm,A.scene=realm,scene;if scene then wake()else A.Stop();A.completedCinematic=nil;A.musicToken=nil;frame:SetScript('OnUpdate',nil)end
 A.UpdateStudyMusic()
end
function A.Actor(id,profile,object,state,elapsed,duration,visible)
 if not A.profiles[profile]or not A.scene then return false end
 local a=A.actors[id]
 if not a then local n=0;for _ in pairs(A.actors)do n=n+1 end;if n>=32 then return false end;a={generation=0,fired={}};A.actors[id]=a end
 if a.state~=state or(elapsed or 0)<(a.elapsed or 0)then a.generation=a.generation+1;a.fired={}end
 a.profile,a.object,a.state,a.elapsed,a.duration,a.visible,a.updated=profile,object,state,elapsed or 0,math.max(.01,duration or 1),visible~=false,time()
 return true
end
local function eligible(a,stamp)
 if not a.object or not a.object:IsVisible()or not a.visible or stamp-a.updated>1 then return false,'hidden'end
 local p=A.profiles[a.profile]
 if p.reward and ns.WardenSanctuary and not ns.WardenSanctuary.Available(p.reward)then return false,'locked'end
 return true
end
function A.PreferencesChanged()
 A.UpdateStudyMusic()
 for i=#A.voices,1,-1 do local v=A.voices[i];if not A.Status(v.group,v.channel)then stop(v);table.remove(A.voices,i)end end
 if A.scene then wake()end
end
update=function()
 if A.MusicTick then A.MusicTick()end
 local stamp=time();if stamp<(A.nextTick or 0)then return end;A.nextTick=stamp+.10
 for i=#A.voices,1,-1 do local v=A.voices[i];if v.untilAt<=stamp then table.remove(A.voices,i)elseif not A.Status(v.group,v.channel)then stop(v);table.remove(A.voices,i)end end
 local realm=A.realm
 if A.scene and(not realm or not realm.frame:IsVisible())then A.Scene(nil,nil);return end
 if A.scene then
  local bed=A.scene=='study'and'study.bed'or'forest.bed';if not voice('scene')then A.Play(bed,'scene')end
  A.UpdateStudyMusic()
  if A.scene=='study'and realm.candle:IsVisible()and flag('wardenCandleSound')then if not voice('candle')then A.Play('candle','candle')end else A.Stop('candle')end
  for id,a in pairs(A.actors)do
   local ok,reason=eligible(a,stamp)
   if not ok then A.Stop('actor:'..id);a.suppressed=reason
   else
    a.suppressed=nil;local p=A.profiles[a.profile];local events=p[a.state]or{}
    local cycle=math.floor(a.elapsed/a.duration);local q=(a.elapsed%a.duration)/a.duration
    for i,e in ipairs(events)do local token=a.generation..':'..cycle..':'..i
     if q>=e[1]and a.fired[i]~=token then a.fired[i]=token;if not p.silent then A.Play(e[2],'actor:'..id)end end
    end
   end
  end
 end
 if not A.scene and #A.voices==0 then frame:SetScript('OnUpdate',nil)end
end
A.Update=update
function A.Diagnostics()
 local out={scene=A.scene or'none',handles={},actors={},metrics=A.metrics,handleCapability=A.handleCapability,lastError=A.lastError,music={enabled=A.MusicEnabled(),owned=A.musicOwned==true,track=A.musicTrack,request=A.musicRequest,endsAt=A.musicEndsAt,suppressed=A.musicSuppressed,error=A.musicError,behavior='Visible menu/world/cinematic; bounded loop renewal; native restart, no seek API'}}
 for _,v in ipairs(A.voices)do out.handles[#out.handles+1]={cue=v.id,handle=v.handle,scope=v.scope,channel=v.channel,untilAt=v.untilAt}end
 for id,a in pairs(A.actors)do out.actors[#out.actors+1]={id=id,profile=a.profile,state=a.state,visible=a.visible,suppressed=a.suppressed}end
 return out
end

