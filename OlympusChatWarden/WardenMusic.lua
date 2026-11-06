-- Resumable music is part of the existing Warden audio owner, not another scene
-- clock. Only approved local cues are used; no seek API or game-volume changes.
local _,ns=...
local A=ns.WardenAudio
local M={VERSION=1,voices={},marks={},metrics={segments=0,transitions=0,hitches=0},MAX_VOICES=3};ns.WardenMusic=M
local nativeUpdate,nativeRelease=A.UpdateStudyMusic,A.ReleaseStudyMusic
local base='Interface\\AddOns\\OlympusChatWarden\\Media\\Journal3\\Audio\\'
local known={['warden-menu-theme']=true,['roads-olympus-master']=true,['study-hearth-loop']=true,['warden-cinematic-action']=true}
local function finite(v)return type(v)=='number'and v==v and v>-math.huge and v<math.huge end
local function now()local v=ns.SafeCall(GetTimePreciseSec)or ns.SafeCall(GetTime);return finite(v)and v or 0 end
local function position(s,t)
 local p=s.position+math.max(0,t-s.started)
 return s.asset.loop and p%s.asset.seconds or math.min(s.asset.seconds,p)
end
local function progress(write)
 if type(ns.DB)~='table'then return end
 local root=ns.DB.wardenMusicProgress
 if root==nil and write then root={version=1,tracks={}};ns.DB.wardenMusicProgress=root end
 if root==nil then return end
 if type(root)~='table'or getmetatable(root)or root.version~=1 or type(root.tracks)~='table'or getmetatable(root.tracks)then M.persistenceError='Incompatible music bookmarks retained unchanged.';return end
 local n=0;for _ in pairs(root.tracks)do n=n+1;if n>8 then M.persistenceError='Music bookmark limit; original retained.';return end end
 return root
end
local function bookmark(id,asset)
 if not asset.stream.resume then return 0 end
 local root=progress(false);local row=root and root.tracks[id]
 if type(row)=='table'and not getmetatable(row)and finite(row.position)and row.position>=0 then return row.position%asset.seconds end
 return(M.marks[id]or 0)%asset.seconds
end
function M.Save(t)
 local s=M.active;if not s or not s.asset.stream.resume then return end
 local p=position(s,t or now());M.marks[s.id]=p
 local root=progress(true);if not root then return end
 local old=root.tracks[s.id]
 if old~=nil and(type(old)~='table'or getmetatable(old)or not finite(old.position)or old.position<0)then M.persistenceError='Invalid music bookmark retained; session resume remains available.';return end
 root.tracks[s.id]={position=math.floor(p*1000+.5)/1000,revision=s.asset.stream.revision}
end
local function retire(v,ms,t)
 if v.fading then return end
 if v.handle and type(StopSound)=='function'then pcall(StopSound,v.handle,ms or 650)end
 v.fading=true;v.endsAt=t+(ms or 650)/1000
end
local function prune(t)
 for i=#M.voices,1,-1 do if M.voices[i].endsAt<=t then table.remove(M.voices,i)end end
end
local function retireAll(ms,t)for _,v in ipairs(M.voices)do retire(v,ms,t)end end
function M.Release(ms)
 if M.nativeMode then return nativeRelease()end
 local t=now();M.Save(t);M.active=nil;retireAll(ms or 650,t)
 local owned=M.held;M.held=nil
 if owned then A.inMusicCall=true;pcall(StopMusic);A.inMusicCall=nil end
 A.musicOwned=false;A.musicGain=nil;A.musicTrack=nil;A.musicEndsAt=nil
 return owned==true
end
local function hold(t)
 if M.held and t<(M.holdUntil or 0)then return true end
 A.inMusicCall=true;local ok,result=pcall(PlayMusic,base..'Soundtracks59\\music-owner.ogg');A.inMusicCall=nil
 if not ok or result==false then return false end
 M.held=true;M.holdUntil=t+3300;A.musicOwned=true;return true
end
local function clip(s,index,entry,gain,t)
 local stream=s.asset.stream;local row=stream.chunks[index]
 if not row or gain==0 then return false end
 local off=entry and row.points[entry]or 0
 local suffix=entry and('e'..string.format('%02d',entry))or'b'
 local file=base..stream.path..'\\s'..string.format('%03d',index)..'-'..suffix..'-'..gain..'.ogg'
 local ok,playing,handle=pcall(PlaySoundFile,file,'Music')
 if not ok or playing==false or handle==nil then if handle and type(StopSound)=='function'then pcall(StopSound,handle,0)end;return false end
 prune(t)
 while #M.voices>=M.MAX_VOICES do local v=table.remove(M.voices,1);if v.handle then pcall(StopSound,v.handle,0)end end
 M.voices[#M.voices+1]={handle=handle,endsAt=t+row.length-off+stream.overlap,file=file}
 M.capable=true;M.metrics.segments=M.metrics.segments+1;s.gain=gain;A.musicGain=gain
 return true
end
local function entryAt(asset,p)
 local chunks=asset.stream.chunks
 for i=#chunks,1,-1 do local row=chunks[i]
  if p>=row.start then
   local entry=1;for j,v in ipairs(row.points)do if row.start+v<=p+.000001 then entry=j else break end end
   return i,entry,row.start+row.points[entry]
  end
 end
 return 1,1,0
end
local function start(id,asset,token,p,t)
 local i,entry,actual=entryAt(asset,p);local row=asset.stream.chunks[i]
 local s={id=id,asset=asset,token=token,position=actual,started=t,nextAt=t+row.start+row.length-actual,nextIndex=i+1,lastSave=t}
 if not clip(s,i,entry,A.Volume(),t)then return false end
 M.active=s;A.musicTrack=id;A.musicOwned=true;A.musicEndsAt=t+asset.seconds-actual
 return true
end
local function fallback(why)
 M.Release(0);M.capable=false;M.nativeMode=true;M.error=why
 return nativeUpdate()
end
function M.Update()
 if M.nativeMode then return nativeUpdate()end
 local id,group,token=A.MusicRequest();local changed=id~=A.musicRequest or token~=A.musicToken
 if changed then A.musicSuppressed=nil;A.musicRequest=id;A.musicToken=token end
 local allowed,why=A.Status(group or'music','Music')
 if not id or not allowed then M.Release();return false,why end
 if A.musicSuppressed then return false,'Another music action has taken control.'end
 local asset=ns.WardenAudioAssets[id]
 if not known[id]or not asset or type(asset.stream)~='table'or type(asset.stream.chunks)~='table'or not finite(asset.seconds)or asset.seconds<=0 or asset.seconds>3600 or #asset.stream.chunks<1 or #asset.stream.chunks>128 then M.Release();return false,'Invalid local music playlist.'end
 if type(PlaySoundFile)~='function'or type(StopSound)~='function'then return fallback('This client lacks stoppable sound handles; native full tracks play without resume/crossfade.')end
 local t=now();prune(t)
 if M.active and M.active.id==id and M.active.token==token then return true end
 M.Save(t);retireAll(650,t);M.active=nil
 if not hold(t)then return false,'Native soundtrack ownership unavailable.'end
 if not start(id,asset,token,bookmark(id,asset),t)then return fallback('This client refused a stoppable music cue; native full-track playback is available without resume/crossfade.')end
 M.metrics.transitions=M.metrics.transitions+1;M.error=nil;return true
end
function M.Tick()
 if M.nativeMode then return end
 local t=now();prune(t);local s=M.active;if not s then return end
 if t-s.lastSave>=5 then M.Save(t);s.lastSave=t end
 if t<s.nextAt then return end
 if A.Volume()==0 then M.Update();return end
 local chunks=s.asset.stream.chunks
 if s.nextIndex>#chunks then
  if not s.asset.loop then A.completedCinematic=s.token;M.Release();M.Update();return end
  s.nextIndex=1
 end
 if t-s.nextAt>s.asset.stream.overlap then
  local p=position(s,t);retireAll(650,t)
  if not start(s.id,s.asset,s.token,p,t)then fallback('Music cue unavailable after a long frame; native fallback active.')end
  M.metrics.hitches=M.metrics.hitches+1;return
 end
 local row=chunks[s.nextIndex]
 if not clip(s,s.nextIndex,nil,A.Volume(),t)then fallback('Music cue unavailable; native fallback active.');return end
 s.nextAt=s.nextAt+row.length;s.nextIndex=s.nextIndex+1
 if M.held and t>=(M.holdUntil or 0)then hold(t)end
end
function M.External()
 local t=now();M.Save(t);retireAll(650,t);M.active=nil;M.held=nil
 -- The external caller now owns native music: never StopMusic on its behalf.
end
A.UpdateStudyMusic=M.Update;A.ReleaseStudyMusic=M.Release;A.MusicTick=M.Tick;A.OnExternalMusic=M.External
local diagnostics=A.Diagnostics
function A.Diagnostics()
 local d=diagnostics();d.music.resumeAvailable=M.capable;d.music.resumePrecisionSeconds=M.capable and 2 or nil;d.music.backend=M.nativeMode and'native fallback'or'bounded cue playback';d.music.handles=#M.voices;d.music.error=M.error or d.music.error;d.music.persistenceError=M.persistenceError
 if M.active then d.music.position=position(M.active,now())end
 d.music.behavior='Crossfade and per-track bookmarks; native fallback cannot seek';return d
end
local event=CreateFrame('Frame');event:RegisterEvent('PLAYER_LOGOUT')
event:SetScript('OnEvent',function()M.Release(0)end)
