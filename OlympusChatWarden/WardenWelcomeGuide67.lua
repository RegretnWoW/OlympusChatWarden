-- First deliberate open: animated identity, live campfire, then a short tour.
-- One canonical character; no consent, history or layout changes from viewing.
local _,ns=...
local U,O,C=ns.UI2,ns.UI2Onboarding,ns.WardenCampfireWelcome
local F={VERSION=1,BRAND_SECONDS=2.2,REVEAL_SECONDS=1,EXIT_SECONDS=.85};ns.WardenWelcomeGuide=F
local originalStop=C.Stop
local function busy()return ns.Checked(ns.SafeCall(InCombatLockdown))end
local function ease(q)q=math.max(0,math.min(1,q));return q*q*(3-2*q)end
function F.Active()return F.state~=nil end
function F.NeedsWelcome()
 return ns.DB and ns.Modules.config and(ns.Modules.needsWelcome or ns.Modules.config.onboardingDone~=true)and not O.deferred and not F.deferred
end
local function hideIntro()
 if F.intro then F.intro:Hide()end
 if F.driver then F.driver:Hide()end
 if F.escape then F.escape.silent=true;F.escape:Hide();F.escape.silent=nil end
end
local function stopOwnTravel(state)
 local t=U.realm and U.realm.roomTravel
 if t and state and state.travelState and t.state==state.travelState then t:Cancel('Welcome tour closed')end
end
function F.Cancel(reason)
 local state=F.state;F.state=nil;hideIntro();stopOwnTravel(state)
 F.last={status=reason or'Closed',completed=false};return true
end
function F.Complete()
 F.state=nil;hideIntro();F.deferred=nil;O.deferred=nil
 ns.DB.firesideWelcomeGuide=O.VERSION;ns.DB.updateSeen=ns.UI2PatchNotes.version
 F.last={status='Ready to explore',completed=true}
end
function F.ShowSetup(message)
 local state=F.state;if not state or not U.window:IsVisible()then return false end
 if busy()then F.Cancel('Continue the welcome after combat');return false end
 stopOwnTravel(state);state.phase='setup';hideIntro();F.internal=true
 if ns.UI2Forms.active then ns.UI2Forms.active:Hide()end
 local ok,why=U.OpenMenu();if ok then ok=O.Open(true)end;F.internal=nil
 if not ok then F.Cancel(why);return false end
 if message then O.message=message;O.Render()end;return true
end
function F.OnMovieStopped(reason)
 local state=F.state;if not state or(state.phase~='cinematic'and state.phase~='exit')then return end
 if not U.window:IsVisible()or reason=='Window closed'or reason=='Logout'or reason=='Scene hidden'or busy()then F.Cancel(reason);return end
 if reason=='Finished'or reason=='Skipped'then ns.DB.firesideWelcomeIntro=F.VERSION
 else F.lastMovieError=reason;state.message='The welcome movie could not finish. You can try it again later from Settings → General.'end
 state.phase='outro';state.elapsed=0;F.black:SetAlpha(1);F.logoHost:SetAlpha(0)
 F.skip:Hide();F.status:SetText('');F.intro:Show();F.intro:EnableMouse(true);F.driver:Show()
end
function F.Skip()
 local state=F.state;if not state or state.phase=='setup'or state.phase=='exit'or state.phase=='outro'then return end
 stopOwnTravel(state);state.phase='exit';state.elapsed=0;state.exitAlpha=F.black:GetAlpha();state.stopReason='Skipped'
 F.logoHost:SetAlpha(0);F.skip:Hide();F.status:SetText('');F.intro:Show();F.intro:EnableMouse(true);F.driver:Show()
end
local function tryMovie(state)
 local v=U.realm;local room=v and v:ActiveRoom();if not room then return end
 if room.key~='hall'then
  if not state.travelState and not v.roomTravel.state then
   local link;for _,candidate in ipairs(ns.WardenRoomCatalogue.Connections(room.key))do if candidate.to=='hall'and candidate.portal then link=candidate;break end end
   if not link then state.message='Watch the campfire welcome from Olympus Fields whenever you are ready.';F.Skip();return end
   local ok,why=v.roomTravel:Request(link.id)
   if ok then state.travelState=v.roomTravel.state
   elseif ns.DB.journalReducedMotion or ns.DB.livingRealmAmbience==false then state.message='You can watch the welcome from Olympus Fields. Your movement preferences have been kept.';F.Skip()
   else F.lastMovieError=why end
  end;return
 end
 if v.roomTravel.state then return end
 if not state.force and ns.DB.firesideWelcomeIntro==F.VERSION then F.ShowSetup();return end
 local ok,why=C.Start(v,true)
 if ok then state.phase='cinematic';state.reveal=0;v.campfireWelcome.replay=state.force==true
 else F.lastMovieError=why end
end
function F.Tick(dt)
 local state=F.state;if not state then return end
 if not U.window:IsVisible()then F.Cancel('Window closed');return end
 if not ns.Membership.Allowed()then F.Cancel('Access changed');return end
 if busy()then
  if U.realm.campfireWelcome then originalStop(U.realm,'Interrupted')end
  F.Cancel('Continue the welcome after combat');return
 end
 dt=math.max(0,math.min(.25,dt));state.elapsed=(state.elapsed or 0)+dt
 F.age=(F.age or 0)+dt
 if F.logoHost:IsVisible()and F.logoHost:GetAlpha()>.001 then
  local b=ns.WardenArt.headerFlame;F.flame:Draw(b.width,b.height,F.age,1,not ns.DB.journalReducedMotion)
 end
 if state.phase=='brand'then
  F.black:SetAlpha(1);F.logoHost:SetAlpha(ease(state.elapsed/.8))
  if state.elapsed>=F.BRAND_SECONDS then state.phase='waiting';state.elapsed=0;state.poll=.5 end
 elseif state.phase=='waiting'then
  F.black:SetAlpha(1);F.logoHost:SetAlpha(1);state.poll=(state.poll or 0)+dt
  if state.elapsed>8 then F.status:SetText('Getting your welcome ready…')end
  if state.elapsed>=60 then state.message='The movie is taking longer to load. You can watch it later from Settings → General.';F.Skip();return end
  if state.poll>=.5 and not ns.Initializing and not ns.ChronicleStore.loading then state.poll=0;tryMovie(state)end
 elseif state.phase=='cinematic'then
  local movie=U.realm.campfireWelcome;if not movie then F.OnMovieStopped('Interrupted');return end
  if movie.phase=='read'then
   state.reveal=math.min(F.REVEAL_SECONDS,(state.reveal or 0)+dt);local q=ease(state.reveal/F.REVEAL_SECONDS)
   local ending=ease(((movie.elapsed or 0)-21.25)/1.25)
   F.black:SetAlpha(math.max(1-q,ending));F.logoHost:SetAlpha(1-q);F.status:SetText('');F.skip:SetShown(q<1)
   local cover=F.black:GetAlpha()>.001;F.intro:SetShown(cover);F.intro:EnableMouse(cover)
  end
 elseif state.phase=='exit'then
  F.black:SetAlpha((state.exitAlpha or 0)+(1-(state.exitAlpha or 0))*ease(state.elapsed/F.EXIT_SECONDS))
  if state.elapsed>=F.EXIT_SECONDS then
   local reason=state.stopReason or'Skipped'
   if U.realm.campfireWelcome then originalStop(U.realm,reason,true)end
   F.OnMovieStopped(reason)
  end
 elseif state.phase=='outro'then
  if state.elapsed>=.45 then F.ShowSetup(state.message)end
 end
end
function F.Bind()
 if F.driver or not U.window then return end
 local driver=CreateFrame('Frame',nil,U.window);F.driver=driver;driver:Hide()
 driver:SetScript('OnUpdate',function(_,dt)
  local ok,why=pcall(F.Tick,dt);if not ok then F.lastMovieError=tostring(why):sub(1,180)
   if U.realm.campfireWelcome then originalStop(U.realm,'Controller error')end
   F.ShowSetup('The welcome movie could not start. Your world and saved settings are kept.')
  end
 end)
 local overlay=CreateFrame('Frame',nil,U.window);F.intro=overlay;F.wait=overlay;overlay:SetAllPoints(U.window)
 overlay:SetFrameStrata('DIALOG');overlay:SetFrameLevel(U.window:GetFrameLevel()+600);overlay:EnableMouse(true)
 F.black=ns.UI2Components.Fill(overlay,{0,0,0,1})
 local host=CreateFrame('Frame',nil,overlay);F.logoHost=host;host:SetSize(300,75);host:SetPoint('CENTER',0,20);host:SetScale(1.6);host:SetAlpha(0)
 if host.SetClipsChildren then host:SetClipsChildren(false)end
 F.logo=ns.WardenArt.Texture(host,'BrandHeader','ARTWORK');F.logo:SetAllPoints()
 F.flame=ns.WardenFlame.Surface(host,'brand',0);local b=ns.WardenArt.headerFlame
 ns.WardenSceneGraph.Place(F.flame.frame,host,b.x,b.y,b.width,b.height)
 F.status=ns.UI2Components.Text(overlay,'',13,ns.UI2Components.colors.muted);F.status:SetPoint('BOTTOM',0,80);F.status:SetSize(600,36)
 F.skip=ns.UI2Components.Button(overlay,'Skip intro',F.Skip,150);F.skip:SetPoint('RIGHT',U.restoreMenu,'LEFT',-10,0)
 overlay:Hide()
 local escape=CreateFrame('Frame','FiresideIntroEscape',UIParent);F.escape=escape;escape:Hide()
 escape:SetScript('OnHide',function(self)if not self.silent and F.state then F.Skip()end end)
 if UISpecialFrames then table.insert(UISpecialFrames,1,'FiresideIntroEscape')end
 U.window:HookScript('OnHide',function()
  if U.realm.campfireWelcome then originalStop(U.realm,'Window closed')end
  F.Cancel('Window closed');if O.window then O.window:Hide()end
 end)
 local click,move=U.realm.ClickScene,U.realm.MovePlayer
 local function blocked()local s=F.state;return s and(s.phase~='setup'and s.phase~='cinematic'or F.intro:IsShown())end
 U.realm.ClickScene=function(self,...)if blocked()then return false,'Welcome intro'end;return click(self,...)end
 -- The black overlay blocks physical clicks. The cinematic's own scripted
 -- approach must still be able to call the normal movement service beneath it.
 U.realm.MovePlayer=function(self,...)local s=F.state;if s and s.phase~='setup'and s.phase~='cinematic'then return false,'Welcome intro'end;return move(self,...)end
end
function F.Begin(force)
 if ns.MainStorageBlocked then return false,'Saved data needs recovery. Use /fireside recovery; originals have been retained.'end
 if not ns.DB or not ns.Modules.config or ns.Initializing or ns.ChronicleStore.loading then return false,'Wait for Fireside to finish loading.'end
 if busy()then return false,'Start your welcome after combat.'end
 if not ns.Membership.Allowed()then return false,ns.Membership.Status()end
 if F.state then return true,'Welcome already open'end
 if not force and not F.NeedsWelcome()then return false end
 if U.realm and(U.realm.campfireWelcome or U.realm.roomTravel.state or U.realm.roomBookMotion or U.realm.shelfFocus)then return false,'Finish the current interaction, then try the welcome again.'end
 U.Ensure();F.Bind();F.internal=true
 if not U.window:IsVisible()then U.OpenMenu()end
 U.StopMenuWalking();local ok,why=U.CloseMenu();F.internal=nil;if not ok then return false,why end
 F.deferred=nil;O.deferred=nil;F.state={phase='brand',elapsed=0,force=force==true}
 F.age=0;F.black:SetAlpha(1);F.logoHost:SetAlpha(0);F.status:SetText('');F.skip:Show();F.intro:EnableMouse(true);F.intro:Show();F.escape:Show();F.driver:Show()
 if ns.WardenAudio then ns.WardenAudio.PreferencesChanged()end;return true
end
function C.Stop(v,reason,seen)
 local state=F.state
 if state and(reason=='Finished'or reason=='Skipped')then
  if state.phase=='exit'then return true end
  if state.phase=='cinematic'and F.black:GetAlpha()<.98 then
   state.phase='exit';state.elapsed=0;state.exitAlpha=F.black:GetAlpha();state.stopReason=reason
   F.logoHost:SetAlpha(0);F.skip:Hide();F.intro:Show();F.intro:EnableMouse(true);F.driver:Show();return true
  end
 end
 local ok=originalStop(v,reason,seen);if ok then F.OnMovieStopped(reason)end;return ok
end
local ensure=U.Ensure
function U.Ensure(...)local f=ensure(...);F.Bind();return f end
local open=U.Open
function U.Open(...)
 local ok,why=open(...);if ok and not F.internal and not F.state and F.NeedsWelcome()then F.Begin(false)end;return ok,why
end
ns.OpenWelcome=function()return F.Begin(true)end
ns.ModuleUI.Welcome=function()return false end
ns.CheckWelcome=function()return false end
local check=ns.CheckUpdateScreen
ns.CheckUpdateScreen=function(...)if F.NeedsWelcome()or F.Active()then return end;return check(...)end
local prompt=ns.Chronicle.MaybePrompt
ns.Chronicle.MaybePrompt=function(...)if F.NeedsWelcome()or F.Active()then return false end;return prompt(...)end
