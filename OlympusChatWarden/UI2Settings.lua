-- One settings registry. All mutations use the original service or saved key.
local _,ns=...
local U,C,F,L=ns.UI2,ns.UI2Components,ns.UI2Forms,ns.UI2Layouts
local S={};ns.UI2Settings=S
-- One existing Settings destination; audio is not hidden inside reader tuning.
S.categories={{'general','General'},{'appearance','Appearance'},{'chat','Logos & chat'},{'coverage','Text coverage'},{'capture','Chat capture'},{'spelling','Spelling'},{'language','Languages'},{'packs','Signed packs'},{'protections','Aegis & contacts'},{'spam','Spam protection'},{'notifications','Vigil & notifications'},{'recording','Atlas & recording'},{'privacy','Aether & privacy'},{'reading','Oasis & Journal'},{'aether','Aether community'},{'profile','My Aether profile'},{'data','Data & backups'},{'extensions','Developer extensions'},{'advanced','Advanced & help'}}
local function cap(text) return {title=text,kind='caption',wrap=true,height=60} end
local function action(id,title,detail,fn) return {id=id,title=title,detail=detail,activate=fn,height=43} end
local function block(id,title,x,y,w,rows)
 return {id=id,title=title,x=x,y=y,w=w,rows=rows}
end
local function row(rows,id,title,get,set,opts) rows[#rows+1]=F.Row(id,title,get,set,opts) end
local function boolean(rows,id,title,get,set,help) row(rows,id,title,get,set,{boolean=true,help=help}) end
local function keyBoolean(rows,key,title)
 boolean(rows,'SET.CHAT.'..key,title,function() return ns.DB[key]==true end,function(v)
  if not ns.Membership.Allowed() then return false,ns.Membership.Status() end
  ns.DB[key]=v;if key=='olympusMuteSignal' then ns.OlympusMuteSignal.SettingsChanged() end;ns.PolicyChanged();return true
 end)
end
local function consent(rows,id,title,get,set,disclosure)
 rows[#rows+1]=action(id,title,get() and 'Selected · turn off' or 'Off · review scope',function()
  if get() then F.Feedback(set(false)) else F.Confirm(title,disclosure,function() return set(true) end) end
 end)
end
table.insert(S.categories,3,{'sound','Sound & Ambience'})
function S.SoundRows()
 local rows={};local DB=ns.DB;local A=ns.WardenAudio
 local function setting(key,title,default)
  boolean(rows,'SET.SOUND.'..key,title,function()return default and DB[key]~=false or not default and DB[key]==true end,function(v)DB[key]=v;A.PreferencesChanged();if U.realm and U.realm.RefreshEffects then U.realm:RefreshEffects()end;return true end)
 end
 setting('wardenPhysicalSounds','Fireside sound effects',true)
 setting('wardenEnvironmentalAmbience','Environmental sounds',true)
 boolean(rows,'SET.SOUND.wardenMusic','Fireside music',A.MusicEnabled,A.SetMusicEnabled)
 setting('wardenInteractionSounds','World interaction sounds',true)
 row(rows,'SET.SOUND.VOLUME','Fireside sound volume',A.Volume,function(v)if type(v)~='number'or not({[0]=true,[25]=true,[50]=true,[75]=true,[100]=true})[v]then return false,'Choose a supported gain.'end;DB.wardenSoundVolume=v;A.Stop();return true end,{choices={{0,'Muted'},{25,'25% · very quiet'},{50,'50% · quiet'},{75,'75%'},{100,'100%'}}})
 setting('wardenJournalSounds','Journal sounds',true);setting('wardenInterfaceSounds','Menu and button sounds',true);setting('wardenDiscoverySounds','Keepsake discovery sounds',true)
 setting('livingRealmAmbience','Living world movement',true);setting('livingRealmClouds','Slow cloud movement',true);setting('journalCandle','Journal candle effect',true);setting('wardenCandleSound','Quiet candle crackle',false)
 boolean(rows,'SET.SOUND.REDUCED','Reduced motion',function()return DB.journalReducedMotion==true end,function(v)S.ApplyReading('journalReducedMotion',v);if U.realm and U.realm.RefreshEffects then U.realm:RefreshEffects()end;return true end)
 local _,status=A.Status();rows[#rows+1]=cap(status)
 rows[#rows+1]=action('SET.SOUND.TEST','Test sound effects','Original soft chime · SFX channel',function()local ok,why=A.Play('test');F.Feedback(ok,why)end)
 rows[#rows+1]=cap('Fireside volume changes its own pre-attenuated files. It never changes game sound settings or bypasses a mute. Existing explicit sound choices are preserved.')
 rows[#rows+1]=cap('Music defaults on. The menu plays Beyond the Horizon; the world plays the latest Roads to Olympus or Athena’s Hearth. Music continues in windowed and fullscreen views. The campfire welcome uses a short phrase from the same theme. You can turn all Fireside music off here or on the first setup page.')
 rows[#rows+1]=cap('The menu and Pyragore Fields remember their own playback positions. The Agora and Olympian Oasis share the home soundtrack. Resume precision is about two seconds, with short crossfades. Closing Fireside returns soundtrack control to WoW. WoW music mute and volume remain in effect. Credits: Media/Journal3/Audio/CREDITS67.txt.')
 if A.Diagnostics().music.resumeAvailable==false then rows[#rows+1]=cap('Your client can play the full music tracks. Resuming at the previous position and smooth crossfades are not available here.')end
 return rows
end
function S.Conversations(service,owner)
 service=service or ns.AthenaConversations;owner=owner or ns.Chronicle.Owner()
 local status=service.Status(owner);local policy=status.policy
 if not policy then return F.Feedback(false,'Private conversation settings are available only to their owner.') end
 local fields={}
 for _,pair in ipairs({{'enabled','Remember meaningful conversations'},{'partyRaid','Party and raid'},{'guild','Guild'},{'sayEmote','Say, yell and emotes'},{'instance','Instance chat'},{'publicChannels','Public and Trade channels'},{'whispers','Private whispers'},{'officer','Officer'},{'npcDialogue','Observed NPC and quest dialogue'},{'autoCandidates','Suggest meaningful exchanges'},{'autoPreserve','Keep meaningful moments automatically'},{'showDirectQuotes','Allow exact quotes in my private Journal'}}) do
  local key,title=pair[1],pair[2];local value=policy[key];if value==nil then value=policy.scopes[key] end
  fields[#fields+1]={key=key,label=title,value=value==true,choices={{false,'Off'},{true,'On'}}}
 end
 return F.Form({title='Private conversation scope',help='Nothing is enabled until you Apply. Each channel is independent. Conversation preservation also requires Atlas recording. Quotes and notes stay local, are never public Aether fields and do not establish the truth of a player’s claims. Pausing keeps preserved memories.',fields=fields,submitLabel='Apply explicit choices',submit=function(v)
  local updated={enabled=v.enabled,autoCandidates=v.autoCandidates,autoPreserve=v.autoPreserve,showDirectQuotes=v.showDirectQuotes,scopes={}}
  for _,key in ipairs({'partyRaid','guild','sayEmote','instance','publicChannels','whispers','officer','npcDialogue'}) do updated.scopes[key]=v[key] end
  return service.SetConsent(owner,updated,true)
 end})
end
function S.EditTuning(kind)
 local fields={};local rule=ns.Shield.GetRule(kind)
 for i,pair in ipairs({{'count','Triggers'},{'window','Within seconds'},{'duration','Protection duration (minutes)'}}) do fields[#fields+1]={key=pair[1],label=pair[2],value=i==3 and rule[i]/60 or rule[i],limit=5} end
 return F.Form({title=ns.Shield.RuleTitles[kind]..' · custom limits',help='2–20 triggers, within 10–600 seconds; shield for 1–60 minutes. Existing expiry times stay unchanged.',fields=fields,submit=function(v)
  local rules={};for _,key in ipairs(ns.Shield.RuleKinds) do local r=ns.Shield.GetRule(key);rules[key]={r[1],r[2],r[3]} end
  rules[kind]={tonumber(v.count),tonumber(v.window),tonumber(v.duration) and tonumber(v.duration)*60};return ns.Shield.SetTuning('custom',rules)
 end})
end
function S.BackupPart(index)
 if not S.backup then return false end
 S.backupIndex=math.max(1,math.min(index or 1,S.backup.total))
 local f=F.Copy('History backup · part '..S.backupIndex..' of '..S.backup.total,S.backup.parts[S.backupIndex],'History events and player profiles only. Settings, signed packs, chat, Relay, Aether and recovery journals require the complete SavedVariables file backup. Copy every part.')
 C.Button(f,'Previous part',function() S.BackupPart(S.backupIndex-1) end,150):SetPoint('BOTTOMLEFT',20,18)
 C.Button(f,'Next part',function() S.BackupPart(S.backupIndex+1) end,150):SetPoint('BOTTOMLEFT',178,18)
 return true
end
function S.CreateBackup()
 local origin=F.RouteKey()
 local ok,why=ns.ChronicleBackup.Begin(function(result,err)
  if result then S.backup=result;if F.RouteKey()==origin then S.BackupPart(1) end else F.Feedback(false,err,origin) end
 end)
 if not ok then return F.Feedback(false,why) end
 F.Feedback(true,'Preparing history backup. Recording remains paused.');return true
end
function S.RestoreBackup()
 return F.Form({title='Restore a history backup part',help='Pause recording first. Checksums, event IDs and linked objects are validated. Compatible records are merged; conflicting records leave history unchanged.',fields={{key='text',label='One complete backup part',multiline=true,height=230,code=true,limit=ns.ChronicleBackup.TEXT_LIMIT}},submitLabel='Validate part',submit=function(v)
  local part,why=ns.ChronicleBackup.Validate(v.text);if not part then return false,why end
  local text=v.text
  F.Confirm('Merge validated history part?',part.owner..' · part '..part.index..' of '..part.total..'. Existing history stays unless the validator confirms an identical or new record.',function() return ns.ChronicleBackup.Restore(text) end)
  return false,'Validated. Confirm the separate merge prompt.'
 end})
end
function S.ApplyReading(key,value)
 if ns.DB[key]==value then return true end
 ns.DB[key]=value
 local reader=ns.UI2.journalHost and ns.UI2.journalHost.reader
 if not reader then return true end
 if key=='journalFontScale' then ns.UI2.LayoutJournal()
 elseif key=='journalReducedMotion' then
  reader.document:FinishWordReveal();if reader.rightPage then reader.rightPage:FinishWordReveal() end
 elseif key=='journalNarration' or key=='journalLore' or key=='journalPrologueHidden' then
  -- Match the book's own reading controls: changing a setting must update
  -- the existing reader, rather than just its saved dropdown selection.
  if reader.provider then reader:Recompose() end
 end
 return true
end
function S.Rows(category)
 local rows={};local DB=ns.DB
 if category=='general' then
  keyBoolean(rows,'enabled','Enable wording filtering')
  boolean(rows,'SET.GENERAL.UPDATES','Show release notes after updates',function() return DB.showUpdates~=false end,function(v) DB.showUpdates=v;return true end)
  rows[#rows+1]=cap('All Fireside tools are available together. You choose what is recorded or shared in the privacy settings.')
  rows[#rows+1]=action('SET.GENERAL.PRIVACY','Recording & privacy','Choose what you remember and share',function() U.Open({page='settings',category='privacy'}) end)
  rows[#rows+1]=action('SET.GENERAL.SETUP','Replay welcome & quick tour','Campfire movie, then four short pages. Your existing settings are kept.',function() ns.OpenWelcome() end)
  rows[#rows+1]=action('SET.GENERAL.PATCHES','What’s new','Installed build notes · no Aether connection required',function() ns.OpenUpdates() end)
  rows[#rows+1]=action('SET.GENERAL.SOUND','Sound & Ambience','Music, sound effects, ambience, and reduced motion',function()U.Open({page='settings',category='sound'})end)
 elseif category=='sound'then
  return S.SoundRows()
 elseif category=='profile' then
  rows[#rows+1]=cap('Write a private draft for your own player profile. Saving does not publish it or join Aether. Community ratings stay separate from your recorded accomplishments.')
  local choices={{false,'Not selected'}};for _,key in ipairs(ns.PlayerCard.order) do choices[#choices+1]={key,ns.PlayerCard.zones[key].title} end
  row(rows,'SET.PROFILE.GAMERZONE','Gamerzone · unpublished draft',function() local d=ns.PlayerCard.Local(ns.PlayerCard.Own());return d and d.gamerzone or false end,function(v) return ns.PlayerCard.Select(v or nil) end,{choices=choices})
  rows[#rows+1]=action('SET.PROFILE.OPEN','Open my Aether profile','Your character’s existing profile',function() U.OpenPlayer(ns.PlayerCard.Own(),ns.Chronicle.Owner()) end)
 elseif category=='appearance' then
  rows[#rows+1]=action('SET.APPEARANCE.AUTOFIT','Fit interface to screen','Restore automatic sizing',function() DB.workspaceScale=nil;U.Fit();F.Feedback(true,'Automatic screen fit restored.') end)
  row(rows,'SET.APPEARANCE.SCALE','Interface scale',function() return DB.workspaceScale or 1 end,function(v) v=tonumber(v);if not v or v<.1 or v>1.5 then return false,'Choose 0.1–1.5.' end;DB.workspaceScale=v;U.Fit();return true end,{choices={{.1,'10%'},{.25,'25%'},{.5,'50%'},{.65,'65%'},{.8,'80%'},{1,'100%'},{1.2,'120%'},{1.5,'150%'}},help='Shrinks or enlarges the entire interface together. Your chosen columns and logical text sizes stay fixed; screen fitting limits enlargement.'})
  for _,pair in ipairs({{'wardenMinimap','Minimap launcher for Olympus Hall'},{'shopLauncher','Use Shop button for Olympus Hall'},{'inspectLauncher','Aether shortcut beside Inspect'}}) do local key,title=pair[1],pair[2];boolean(rows,'SET.LAUNCHER.'..key,title,function() return DB[key]==true end,function(v) return ns.WardenLaunchers.Set(key,v) end) end
  rows[#rows+1]=cap('Turn off the Shop shortcut to use WoW’s original button again.')
 elseif category=='modules' then
  rows[#rows+1]=cap('Fireside’s tools now stay available together. There are no module power switches. Your recording, chat capture and sharing choices have been kept.')
  rows[#rows+1]=action('SET.TOOLS.PRIVACY','Recording & privacy','Review your choices',function()U.Open({page='settings',category='privacy'})end)
 elseif category=='chat' then
  keyBoolean(rows,'chat','Filter incoming player chat')
  row(rows,'SET.CHAT.PRESET','Action preset',function() return DB.preset end,ns.SetPreset,{choices={{'strict','Mild'},{'balanced','Balanced'},{'aggressive','Strict'}}})
  boolean(rows,'SET.CHAT.GOMMAGE','Gommage display mask',function() return DB.gommage==true end,ns.SetGommage)
  keyBoolean(rows,'history','Keep optional review history')
  rows[#rows+1]=action('SET.CHAT.OLYMPUSMUTE','Compatible-sharing observations','Vigil notification settings',function() U.Open({page='settings',category='notifications'}) end)
  for _,pair in ipairs({{'coverage','Text coverage'},{'language','Languages'},{'spelling','Typing and typo matching'},{'packs','Signed packs'}}) do local category,title=pair[1],pair[2];rows[#rows+1]=action('SET.CHAT.OPEN.'..category,title,'Configure',function() U.Open({page='settings',category=category}) end) end
 elseif category=='coverage' then
  for _,pair in ipairs({{'npc','NPC speech'},{'dialogue','Quest and NPC dialogue'},{'vendor','Vendor labels'},{'bubbles','Overhead chat bubbles'},{'talkingHead','Talking-head captions'},{'barber','Barber and body-type wording'},{'playerNames','Player names'},{'npcNames','NPC names'},{'targetNames','Unit-frame names'},{'nameplates','Nameplate labels'},{'tooltips','Tooltips'}}) do keyBoolean(rows,pair[1],pair[2]) end
  rows[#rows+1]=cap('Name filtering works where WoW allows it. Some names and protected text cannot be changed.')
 elseif category=='capture' then
  for _,pair in ipairs({{'enabled','Retain local chat'},{'whispers','Include whispers'},{'guild','Include guild and officer chat'}}) do local key,title=pair[1],pair[2];boolean(rows,'SET.CAPTURE.'..key,title,function() return ns.ChatCapture.db and ns.ChatCapture.db[key]==true end,function(v) ns.ChatCapture.SetOption(key,v);return true end) end
  rows[#rows+1]=cap('Keeping recent chat is optional. Choose and review anything you export. NPC dialogue follows your conversation choices.')
  rows[#rows+1]=action('CHAT.CAPTURE.OPEN','Browse captured messages','Open Logos',function() ns.OpenCapture() end)
 elseif category=='spelling' then
  boolean(rows,'SET.SPELLING.ENABLE','Spelling highlights',function() return DB.spelling.enabled end,ns.Spelling.SetEnabled)
  boolean(rows,'SET.SPELLING.AUTO','Automatic high-confidence correction',function() return DB.spelling.autoCorrect end,function(v) return ns.Spelling.SetOption('autoCorrect',v) end)
  boolean(rows,'SET.SPELLING.TYPO','Typo-aware incoming filtering',function() return DB.typoFiltering end,ns.TypoFilter.Set)
  row(rows,'SET.SPELLING.MODE','Incoming typo mode',ns.TypoFilter.Mode,ns.TypoFilter.SetMode,{choices={{'balanced','Balanced'},{'aggressive','Aggressive prototype'}}})
  rows[#rows+1]=action('SET.SPELLING.ADD','Add dictionary word','Local account dictionary',function() F.Value('Add dictionary word','',ns.Spelling.AddWord,'One English word, 2–32 letters.') end)
  for _,word in ipairs(ns.Spelling.PersonalWords()) do local value=word;rows[#rows+1]=action('SET.SPELLING.REMOVE','Dictionary · '..word,'Remove',function() F.Feedback(ns.Spelling.RemoveWord(value)) end) end
 elseif category=='language' then
  boolean(rows,'SET.LANGUAGE.ENABLE','Language filtering',function() return DB.languageEnabled end,function(v) ns.Language.Set('enabled',v);return true end)
  for _,key in ipairs({'low','high'}) do local field=key;row(rows,'SET.LANGUAGE.'..key,key=='low' and 'Low confidence action' or 'High confidence action',function() return DB.languageFilter[field] end,function(v) ns.Language.Set(field,v);return true end,{choices={{'cover','Redact detected text'},{'hide','Hide message'},{'mark','Label only'},{'leave','Leave visible'}}}) end
  for _,key in ipairs({'maskNames','public','whispers','group','guild'}) do local field=key;boolean(rows,'SET.LANGUAGE.'..key,({maskNames='Filter player names',public='Public chat',whispers='Whispers',group='Party, raid and instance',guild='Guild and officer'})[key],function() return DB.languageFilter[field] end,function(v) ns.Language.Set(field,v);return true end) end
  for _,pair in ipairs(ns.Language.Choices) do local key,title=pair[1],pair[2];if key~='en' then boolean(rows,'SET.LANGUAGE.ALLOW.'..key,'Read '..title,function() return DB.languageFilter.allowed[key]==true end,function(v) ns.Language.Set(key,v);return true end) end end
 elseif category=='packs' then
  rows[#rows+1]=cap('Olympus Protection and King Protection are the stock categories. Optional vocabulary is supplied only by author-signed packs. Import and verification use the unchanged backend.')
  rows[#rows+1]=action('CHAT.PACKS.OPEN','Manage signed packs','Open the Logos rule-pack manager',function() ns.OpenPacks() end)
  for _,pack in ipairs(ns.PackNames) do local key=pack;row(rows,'SET.PACK.'..key,ns.RulePacks.Title(key),function() return DB.disabledPacks[key] and 'off' or DB.packPresets[key] or 'default' end,function(v) return ns.SetPackPreset(key,v) end,{choices={{'default','Follow main preset'},{'off','Off'},{'strict','Mild'},{'balanced','Balanced'},{'aggressive','Strict'}}}) end
  for _,pack in ipairs(ns.PackNames) do local key=pack;boolean(rows,'SET.PACK.MASK.'..key,'Curated Gommage masks · '..ns.RulePacks.Title(key),function() return not DB.gommagePacks or DB.gommagePacks[key]~=false end,function(v) DB.gommagePacks=DB.gommagePacks or {};DB.gommagePacks[key]=v;ns.PolicyChanged();return true end) end
 elseif category=='protections' then
  for _,pair in ipairs({{'enabled','Aegis contact protection'},{'whispers','Strong-wording whispers'},{'repeatedWhispers','Repeated whispers'},{'trades','Trade requests'},{'duels','Duel requests'},{'invites','Group invites'},{'visibleChat','Shielded player chat'},{'bubbles','Shielded chat bubbles'}}) do local key,title=pair[1],pair[2];boolean(rows,'SET.SHIELD.'..key,title,function() return DB.shield[key] end,function(v) ns.Shield.SetOption(key,v);return true end) end
  row(rows,'SET.SHIELD.PRESET','Protection preset',function() return DB.shield.profile end,function(v) return ns.Shield.SetTuning(v,DB.shield.custom) end,{choices={{'balanced','Balanced'},{'normal','Previous defaults'},{'custom','Custom limits'}}})
  rows[#rows+1]=action('SET.SHIELD.RESET','Restore Balanced timing defaults','Existing shield timers are kept',function() F.Feedback(ns.Shield.SetTuning('balanced')) end)
  for _,key in ipairs(ns.Shield.RuleKinds) do local kind=key;local rule=ns.Shield.GetRule(kind);rows[#rows+1]=action('SET.SHIELD.TUNING.'..kind,ns.Shield.RuleTitles[kind],rule[1]..' / '..rule[2]..' sec · '..(rule[3]/60)..' min',function() S.EditTuning(kind) end) end
  rows[#rows+1]=action('SHIELD.CONTACTS.OPEN','Manage contacts','Open Aegis',ns.OpenShield)
 elseif category=='spam' then
  for _,pair in ipairs({{'enabled','Spam protection'},{'advertising','Gold and paid-service ads'},{'recruitment','Guild recruitment ads'},{'repetition','Repeated messages'},{'flooding','Rapid messages'},{'public','Public chat'},{'whispers','Whispers'},{'group','Party and raid'},{'guild','Guild and officer'}}) do local key,title=pair[1],pair[2];boolean(rows,'SET.SPAM.'..key,title,function() return DB.shield.spam[key] end,function(v) return ns.Spam.Set(key,v) end) end
  row(rows,'SET.SPAM.DURATION','Automatic timeout',function() return DB.shield.spam.duration end,function(v) return ns.Spam.Set('duration',tonumber(v)) end,{choices={{300,'5 minutes'},{900,'15 minutes'},{1800,'30 minutes'}}})
 elseif category=='notifications' then
  keyBoolean(rows,'olympusMuteObserve','Passively observe compatible OlympusMute sharing')
  keyBoolean(rows,'olympusMuteSignal','Show sharing observations in tooltips')
  rows[#rows+1]=cap('Tooltip enhancement starts OFF for unset preferences. Passive observations send no probes, discard shared lists, and never prove installation or a mute action. Missing evidence means Unknown.')
  rows[#rows+1]=action('SET.SIGNAL.OLYMPUSMUTE','Review sharing observations','Open Vigil history',function() U.Open({page='mentions',category='olympusmute'}) end)
  keyBoolean(rows,'alertsEnabled','Enable Vigil alerts')
  for _,pair in ipairs({{'sanctuary','Oasis unlock celebrations'},{'badges','Notification bell and unread counts'},{'chat','Short notices in chat'},{'filtered','Word filtering'},{'hidden','Hidden messages'},{'redacted','Redacted messages and names'},{'language','Language filtering'},{'shield','Contact protection'},{'spam','Repeated and rapid chat'},{'advertising','Gold and service ads'},{'recruitment','Recruitment ads'},{'athena','Athena advisories'},{'athenaWatched','Watched-player activity'},{'athenaEarned','Important-player activity'}}) do local key,title=pair[1],pair[2];boolean(rows,'SET.NOTIFY.'..key,title,function() return ns.Notifications.Get(key) end,function(v) return ns.Notifications.Set(key,v) end) end
  for _,pair in ipairs({{'enabled','Mention alerts'},{'character','Watch my character name'},{'typos','Recognize name typos'},{'sound','Mention sound'},{'toast','Mention toast'}}) do local key,title=pair[1],pair[2];boolean(rows,'SET.MENTION.'..key,title,function() return ns.Mentions.db[key] end,function(v) return ns.Mentions.Set(key,v) end) end
  row(rows,'SET.MENTION.COOLDOWN','Mention cooldown',function() return ns.Mentions.db.cooldown end,function(v) return ns.Mentions.Set('cooldown',tonumber(v)) end,{help='0–120 seconds.'})
  for _,id in ipairs({'general','trade','lfg','other','say','yell','guild','party','raid','whispers'}) do local key=id;boolean(rows,'SET.MENTION.CHANNEL.'..key,'Mention channel · '..key,function() return ns.Mentions.db.channels[key] end,function(v) return ns.Mentions.SetChannel(key,v) end) end
  if ns.Wanted and ns.Wanted.db then
   for _,key in ipairs({'enabled','encounters','chatIndicators','badges','sound','toast'}) do local field=key;boolean(rows,'SET.WANTED.'..key,'Wanted · '..({enabled='alerts',encounters='encounter sightings',chatIndicators='chat indicators',badges='badges',sound='sound',toast='toast'})[key],function() return ns.Wanted.db[field] end,function(v) return ns.Wanted.Set(field,v) end) end
   row(rows,'SET.WANTED.COOLDOWN','Wanted sighting cooldown',function() return ns.Wanted.db.cooldown end,function(v) return ns.Wanted.Set('cooldown',tonumber(v)) end,{choices={{30,'30 seconds'},{60,'1 minute'},{300,'5 minutes'},{900,'15 minutes'},{1800,'30 minutes'}}})
  end
 elseif category=='extensions'then
  for _,entry in ipairs(ns.WardenExtensions and ns.WardenExtensions.SettingsRows()or{})do rows[#rows+1]=entry end
 elseif category=='recording' then
  consent(rows,'SET.RECORDING.MERCHANT','Private merchant history',ns.ChronicleMerchant.Selected,ns.ChronicleMerchant.SetEnabled,'Keep available details of your own auction listings, seller invoices and completed trades. Mail bodies are not saved, and Fireside does not guess market prices or profit. These records stay private; adventure recording must also be on.')
  local pref=ns.ChronicleStore.PreferenceRoot()
  consent(rows,'SET.RECORDING.ENABLE','Record adventures and player observations',function() return pref and pref.enabled==true end,ns.Chronicle.SetEnabled,ns.Chronicle.Disclosure)
  consent(rows,'SET.RECORDING.DUELS','Include duel history',function() return pref and pref.duels==true and pref.duelConsent==1 end,ns.ChronicleDuels.SetEnabled,'Keep accepted duels, available gear and talents before/after, successful casts and received damage/healing. Received amounts have no attacker attribution. Local only; main recording consent is also required.')
  rows[#rows+1]=cap(ns.Chronicle.Status())
  if ns.AthenaMoments then
   for _,pair in ipairs({{'enabled','Athena’s Moments · automatic screenshots'},{'effect','Subtle capture feedback'},{'cleanUI','Clean scenes when UI opacity can safely change'}})do local key,title=pair[1],pair[2];boolean(rows,'SET.MOMENTS.'..key,title,function()return ns.AthenaMoments.Status()[key]==true end,function(v)return ns.AthenaMoments.Set(key,v)end)end
   for _,category in ipairs({'level','quest','boss','instance','loot','pvp','duel','exploration'})do local key=category;boolean(rows,'SET.MOMENTS.CATEGORY.'..key,'Moments · '..key,function()return ns.AthenaMoments.Status().categories[key]~=false end,function(v)return ns.AthenaMoments.Set(key,v)end)end
   local m=ns.AthenaMoments.Status();rows[#rows+1]=cap('Screenshots: '..m.metrics.requested..' requests this session · '..m.queued..' queued · '..(m.last or m.api)..'. Images stay local; file association is unavailable to addon Lua.')
  end
  rows[#rows+1]=action('SET.RECORDING.CONVERSATIONS','Meaningful text and conversations','Independent channel and quotation choices',function()return S.Conversations()end)
  local text=ns.AthenaConversations.Status();local health=text.metrics or{};rows[#rows+1]=cap('Text: '..(health.seen or 0)..' seen · '..(health.displayVerified or 0)..' display-verified · '..text.staging..' staged · '..text.candidates..' candidates · '..text.moments..' preserved. '..(text.warning or text.state))
  rows[#rows+1]=cap('Text links: '..(health.linked or 0)..' · expired: '..(health.expired or 0)..' · rejected: '..(health.rejected or 0)..'. Journal quotations follow your separate channel and quotation choices.')
  if ns.AthenaTextSources then local sources={};for event,state in pairs(ns.AthenaTextSources.coverage)do sources[#sources+1]=event..': '..state end;table.sort(sources);if #sources>0 then rows[#rows+1]=cap(table.concat(sources,' · '))end end
  rows[#rows+1]=action('SET.RECORDING.BACKUP','Back up history','Data & backups',function() U.Open({page='settings',category='data'}) end)
 elseif category=='privacy' then
  consent(rows,'SET.PRIVACY.CONTACT','Inspect after first direct contact',ns.AthenaFirstContact.Selected,ns.AthenaFirstContact.SetEnabled,'One normal inspection attempt for a verified small-party companion or direct duel opponent. Saves only available dated gear/talents. No inspections of passing strangers; recording and player observations must already be enabled.')
  consent(rows,'SET.PRIVACY.INCIDENT','Minimal private protection context',ns.AthenaIncidents.Selected,ns.AthenaIncidents.SetEnabled,'Keep small summaries of local repeated filter decisions and Shield actions. No message text or allegations. Private local history; existing records remain when disabled.')
  consent(rows,'SET.PRIVACY.WITNESS','Visible player observations',ns.IntelWitness.Selected,ns.IntelWitness.SetEnabled,'Keep available player details, sightings and selected ability observations for important players. Unseen activity stays unknown. Nothing is uploaded automatically; adventure recording must also be on.')
  rows[#rows+1]=action('SET.PRIVACY.CONVERSATIONS','Conversations and memories','Review every private channel',function() S.Conversations() end)
 elseif category=='reading' then
  boolean(rows,'SET.READING.AMBIENCE','Living world movement',function()return DB.livingRealmAmbience~=false end,function(v)DB.livingRealmAmbience=v;if ns.UI2.realm then ns.UI2.realm:Stop()end;return true end,'Controls scenic movement, including woodland wildlife in Pyragore Fields and domestic animals in The Agora. Reduced motion and combat also restrict movement. Your saved scene layout is kept.')
  rows[#rows+1]=action('SET.READING.PHYSICALSOUND','Sound & Ambience','Journal sounds, volume and Test Sound',function()U.Open({page='settings',category='sound'})end)
  boolean(rows,'SET.READING.CANDLE','Journal candle effect',function()return DB.journalCandle~=false end,function(v)DB.journalCandle=v;return true end,'Controls the Journal’s decorative candle effect. Reduced motion keeps it still. Placed scene objects are edited separately in the scene editor.')
  for _,pair in ipairs({{'journalReducedMotion','Reduced motion and instant page turns'},{'journalAskRecollections','Ask for player recollections'},{'journalLore','Contextual lore'},{'journalPrologueHidden','Hide historical prologue'}}) do local key,title=pair[1],pair[2];boolean(rows,'SET.READING.'..key,title,function()
   if key=='journalAskRecollections' or key=='journalLore' then return DB[key]~=false end
   return DB[key]==true
  end,function(v) return S.ApplyReading(key,v) end) end
  row(rows,'SET.READING.SPEED','Journal writing animation',function() return DB.journalWritingRate or 32 end,function(v) if v~=0 and v~=32 and v~=64 then return false,'Choose a writing speed.' end;DB.journalWritingRate=v;return true end,{choices={{32,'Normal'},{64,'Faster'},{0,'Instant'}}})
  row(rows,'SET.READING.FONT','Journal text size',function() return DB.journalFontScale or 1 end,function(v) return S.ApplyReading('journalFontScale',tonumber(v)) end,{choices={{.85,'Small'},{1,'Standard'},{1.2,'Large'},{1.4,'Largest'}}})
  row(rows,'SET.READING.VOICE','Journal narration style',function() return ns.AthenaChronicler.Voice() end,function(v) return S.ApplyReading('journalNarration',v) end,{choices={{'Natural Fantasy','Natural fantasy'},{'Observed Record','Observed record'}}})
 elseif category=='aether' then
  local N=ns.AetherNet;local client=N.Active()
  rows[#rows+1]=action('AETHER.DISCLOSURE','Read sharing disclosure','Complete scope, privacy and consent terms',function() F.Copy('Aether sharing disclosure',ns.AthenaSharePolicy.Disclosure,'Read-only local terms. No enrollment or publication.') end)
  if ns.AetherUnified and ns.AetherUnified.Available()then
   rows[#rows+1]=cap('Aether · '..ns.AetherUnified.status..'. Saved community pages remain available while you are offline.')
   boolean(rows,'AETHER.PREFERENCE','Share my community contributions',function()return N.Preference()end,N.SetPreference,'Allow posts, profiles and adventure summaries you choose to publish to travel through Aether. Joining Live does not publish your drafts, private notes, conversations or watchlists.')
   rows[#rows+1]=action('AETHER.LIVE.JOIN',ns.AetherLive.Active()and'Leave Aether Live'or'Join Aether Live','Connect with the community. Sharing your own contributions stays your choice.',ns.AetherLive.Join)
   rows[#rows+1]=cap('Aether keeps approved community pages up to date while connected, even with this window closed. Availability depends on other participating players; Aether is not a permanent online archive.')
  elseif ns.AetherNative.RelayPaused()then
   rows[#rows+1]=cap(ns.AetherNative.RelayPauseMessage)
  else
  if ns.AetherServices then
   local service=ns.AetherServices;local status,detail=service.RelayStatus()
   rows[#rows+1]=cap('Aether Relay identity · '..detail)
   rows[#rows+1]=action('AETHER.ENROLL.AUTO',status=='ENROLLED'and'Recheck enrollment'or status=='OFF'and'Enroll in Aether Relay'or'Retry Relay enrollment','Automatic key and certificate setup · sharing stays your choice',function()return F.Feedback(service.RetryRelay())end)
   if service.Desired('relay')then rows[#rows+1]=action('AETHER.ENROLL.PAUSE','Pause automatic enrollment','Keep existing credentials and all history',function()return F.Feedback(service.PauseRelayEnrollment())end)end
   rows[#rows+1]=action('AETHER.ENROLL.DETAILS','Enrollment connection details','No keys, certificate text or private history',function()return F.Copy('Aether setup',service.Diagnostics())end)
  end
  boolean(rows,'AETHER.PREFERENCE','Share eligible community records through Relay',function() return N.Preference() end,N.SetPreference,'Exchange eligible community records with other Relay participants. Private drafts remain unpublished until you Post. This choice is separate from certificate enrollment, adventure recording and Aether Live.')
  rows[#rows+1]=action('AETHER.NATIVE.PEERS','Community connections','Preferred contacts & activity sharing',function() return ns.AetherNative.EditPolicy() end)
  rows[#rows+1]=cap(N.ServiceState())
  if ns.AetherRelay then
   local relay=ns.AetherRelay.Status();rows[#rows+1]=cap('Aether Relay · '..relay.state..' · '..relay.detail)
   rows[#rows+1]=action('AETHER.RELAY.STATUS','Aether Relay readiness','Read-only startup, transport and enrollment status',function()return F.Copy('Aether Relay readiness',ns.AetherRelay.Text(),'No key material, private history or automatic send is included.')end)
   rows[#rows+1]=action('AETHER.RELAY.RESUME','Resume consented Relay','Retry startup using your existing participation choice',function()return F.Feedback(ns.AetherRelay.Resume())end)
  end
  rows[#rows+1]=cap('Your dated equipment and talent records stay private. Review your latest available details on your player profile before choosing to share them. An observation does not prove an accomplishment. Older versions support sharing with a selected recipient only.')
  rows[#rows+1]=cap('Your character joins and renews automatically when a trusted Olympus host can welcome you. Waiting does not remove posts, drafts or history. Some connections may still be unavailable.')
  if ns.AetherAutomaticEnrollment then local _,detail=ns.AetherAutomaticEnrollment.Status();rows[#rows+1]=cap(detail)end
  if ns.AetherAutomaticEnrollment and ns.AetherAutomaticEnrollment.IssuerRole then
   local _,detail=ns.AetherAutomaticEnrollment.IssuerRole();rows[#rows+1]=cap(detail)
   rows[#rows+1]=action('AETHER.ISSUER.ROLE','Enrollment host status','Check this character’s host role without showing keys or certificates',function()local state,message=ns.AetherAutomaticEnrollment.IssuerRole();return F.Copy('Enrollment host status',state..'\n'..message,'No private key or certificate is included.')end)
  end
  end
  if ns.AetherLive and ns.AetherLive.FindPlayer then rows[#rows+1]=action('AETHER.LIVE.FIND','Find an adventurer','Connect by exact WoW Name-Realm while Live is on',ns.AetherLive.FindPlayer)end
  if client then rows[#rows+1]=action('AETHER.LEAVE','Pause Aether participation','Your drafts and existing history are kept',function() return N.SetPreference(false) end) end
  rows[#rows+1]=action('AETHER.PRESENCE.REVIEW','Share my activity briefly','90 seconds · explicit review · no roster',function() return ns.AthenaPublication.ReviewPresence() end)
  rows[#rows+1]=action('AETHER.PUBLIC.PREVIEW','Preview my public card','Preview your profile · nothing is sent',function() U.OpenPlayer(ns.PlayerCard.Own(),ns.Chronicle.Owner(),'public') end)
  rows[#rows+1]=action('AETHER.OWNER.DRAFT','Edit unpublished profile','Private draft · sharing choices unchanged',function() return N.EditDraft(ns.PlayerCard.Own()) end)
  rows[#rows+1]=action('AETHER.OWNER.PUBLIC','Edit my public profile','Existing profile · participation required · no online peer required',function() return N.EditOwner(ns.PlayerCard.Own()) end)
  if ns.WardenSimLab then rows[#rows+1]=action('AETHER.ENROLLMENT','Advanced enrollment import','Private Lab recovery tools · ordinary enrollment is automatic',function()return ns.AetherCertificates.ImportUI()end)end
  rows[#rows+1]=action('AETHER.NATIVE.READINESS','Check connection support','Read-only diagnostics · does not send or enable Aether',function()
   return F.Copy('Aether connection support',ns.RelayTransport.Aether.ReadinessText(),'This check shows what your WoW client supports. It does not prove another player can be reached and does not send anything. Olympus guild integration is optional.')
  end)
 elseif category=='data' then
  rows[#rows+1]=action('DATA.FILE.GUIDE','Complete SavedVariables backup','All settings, imports and history',function()
   local f=F.Copy('Complete SavedVariables backup','WTF/Account/<your account>/SavedVariables/OlympusChatWarden.lua','Exit WoW normally and keep it closed. Copy this file, its .bak and the pending recording journal to a private backup folder. A complete restore replaces account settings and history. The history text merge below only covers Atlas events and Aether profiles.')
   return f
  end)
  rows[#rows+1]=action('SET.DATA.PERSIST','Remember messages, alerts and contact activity',ns.Permissions.Denied('incidents') and 'Paused by privacy · review to resume' or DB.persistHistory~=false and 'On' or 'Off',function()
   local value=DB.persistHistory==false or ns.Permissions.Denied('incidents')
   if value then ns.History.SetEnabled(true);F.Feedback(true,'Future activity history will be remembered for this character.')
   else F.Confirm('Stop remembering activity history?','The saved Logos messages, Vigil alerts and contact activity for this character are removed. Current session entries remain until reload. Chronicle, capture, bookmarks, reports, rules and protection lists are separate.',function() ns.History.SetEnabled(false);return true end) end
  end)
  rows[#rows+1]=cap('History never expires automatically. A complete recovery backup is the SavedVariables file plus its .bak and pending recording journal while WoW is closed. Text backup covers Atlas events and Aether profiles only.')
  rows[#rows+1]=action('DATA.HISTORY.BACKUP','Create history text backup','Pause recording first',S.CreateBackup)
  if S.backup then rows[#rows+1]=action('DATA.HISTORY.PARTS','Copy prepared backup parts',S.backup.total..' parts',function() S.BackupPart(1) end) end
  rows[#rows+1]=action('DATA.HISTORY.RESTORE','Restore history part','Validate before merging',S.RestoreBackup)
  rows[#rows+1]=action('DATA.HISTORY.CANCEL','Cancel backup preparation','Original data is kept',function() ns.ChronicleBackup.Cancel();F.Feedback(true,'Backup preparation canceled.') end)
  rows[#rows+1]=action('DATA.HISTORY.CLEAR','Clear all local history and private records','Permanent · all recorded characters',function() F.Confirm('Clear all local history and private records?','Stops capture and Aether, then removes supported local character history, notes, conversations, Journal snapshots, capture messages, private drafts, exchange caches and Relay reports. Rules and protection settings remain. Remote copies cannot be recalled. Unsupported stores cause refusal without deletion.',function() return ns.Privacy.Erase('all','CLEAR ALL') end) end)
  rows[#rows+1]=action('DATA.CAPTURE.CLEAR','Clear captured chat','Bookmarks remain',function() F.Confirm('Clear captured chat?','Removes retained capture entries. Saved bookmarks, Chronicle and rules remain.',function() ns.ChatCapture.Clear();return true end) end)
  rows[#rows+1]=action('DATA.ACTIVITY.CLEAR','Clear message and alert history','Current character only',function() F.Confirm('Clear this character’s activity history?','Removes Messages, Alerts and contact activity. Capture, bookmarks, reports, rules, protection lists and Atlas history remain.',function() ns.History.Clear();return true end) end)
  rows[#rows+1]=action('DATA.CACHES.CLEAR','Clear temporary files from memory','Saved history and policy remain',function() F.Feedback(true,ns.Modules.ClearCaches()) end)
 elseif category=='advanced' then
  rows[#rows+1]=action('HELP.PUBLIC.FEEDBACK','Project feedback website','Copy public link',ns.OpenReportLink)
  rows[#rows+1]=action('HELP.COLLECTIONS','What Fireside remembers','Recording scope and limits',function() U.Open({page='settings',category='advanced',subsection='collection-help',topic='time'}) end)
  rows[#rows+1]=cap('Make Fireside your own. Change your preferences here; opening a feature never turns on recording or sharing.')
  rows[#rows+1]={title='Build',detail=ns.VERSION,height=38}
  rows[#rows+1]={title='Client compatibility',detail='Some features still need in-game testing',height=38}
  rows[#rows+1]=action('DATA.PERFORMANCE.PRINT','Print support performance summary','Developer diagnostics in chat',function() ns.WardenPerformance.Report();F.Feedback(true,'Performance summary printed locally. Nothing was sent.') end)
  if ns.WardenSimLab then rows[#rows+1]=action('LAB.OPEN','Hephaestus Lab','Scene editor, camera controls, and diagnostics',function() ns.WardenSimLab.Open() end) end
 else rows[#rows+1]=cap('Choose a settings category.') end
 return rows
end
function S.HealthRows()
 local store=ns.ChronicleStore;local health=store.Residency();local state
 if store.loading then state='Validating saved history'
 elseif store.blocked then state='Needs recovery · originals retained'
 elseif not store.db then state='History has not loaded'
 elseif health.errors>0 then state='Some character archives need attention'
 elseif health.packedCharacters>0 then state='Available · other characters open on request'
 else state='Available' end
 local rows={{title='Saved history',detail=state,height=52,stacked=true},{title='Loaded records',detail=C.Number(health.loadedEvents),height=42},{title='Loaded player identities',detail=C.Number(health.loadedProfiles),height=42},{title='Archives not opened',detail=C.Number(health.packedCharacters),height=42}}
 if health.errors>0 then rows[#rows+1]=cap('An archive could not be opened. Its original saved bytes are kept; it is not shown as empty history.') end
 local journal=ns.ChronicleStartupJournal;local recovery=journal and journal.Health()
 if recovery then rows[#rows+1]={title='Pending recording recovery',detail=recovery.integrity,height=60,stacked=true} end
 for owner in pairs(store.db and store.db.characters or {}) do if store.ArchiveError(owner) then rows[#rows+1]=cap(ns.WardenUI.OwnerName(owner)..' · could not open archive. Original retained.') end end
 rows[#rows+1]=cap('Recording and sharing choices stay separate. Automatic snapshots follow your Settings; disk saves occur on logout or reload.')
 return rows
end
function L.Settings(route)
 local category=route.category or 'general';local tabs={};local name
 for _,pair in ipairs(S.categories) do local key,title=pair[1],pair[2];if key==category then name=title end;tabs[#tabs+1]=action('SET.OPEN.'..key,title,key==category and 'Selected' or '',function() U.Open({page='settings',category=key},true) end);tabs[#tabs].height=34 end
 local details=S.HealthRows()
 if U.feedback then table.insert(details,1,cap(U.feedback)) end
 return {block('categories','Settings',0,0,.23,tabs),block('controls',name or 'Settings',.23,0,.54,S.Rows(category)),block('state','State & feedback',.77,0,.23,details)}
end
