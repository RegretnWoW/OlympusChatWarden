-- A short player-facing tour. Choices are staged; browsing grants no consent.
local _,ns=...
local C,U,T=ns.UI2Components,ns.UI2,ns.Theme
local O={VERSION=2,steps={},options={},byKey={}};ns.UI2Onboarding=O
local function busy()return ns.Checked(ns.SafeCall(InCombatLockdown))end
local function step(title,help)local s={title=title,help=help,options={}};O.steps[#O.steps+1]=s;return s end
local function option(s,key,title,help,get,set)
 local v={key=key,title=title,help=help,get=get,set=set};s.options[#s.options+1]=v;O.options[#O.options+1]=v;O.byKey[key]=v
end
local function reading(key,default)
 return function()if ns.DB[key]==nil then return default end;return ns.DB[key]==true end,
  function(v)return ns.UI2Settings.ApplyReading(key,v)end
end
local s=step('Make yourself at home','Fireside is your own little world inside WoW. Close Menu to explore, then click a clear patch of ground to walk. Hover over objects: a gear means there is something to use.')
option(s,'music','Enjoy the Fireside soundtrack','Different music accompanies the menu, the Fields and your home. WoW’s music volume and mute still apply.',ns.WardenAudio.MusicEnabled,ns.WardenAudio.SetMusicEnabled)
option(s,'automaticBackups','Keep automatic snapshots','Athena’s Safeguard always protects failed reads. Optional local snapshots add recovery copies of settings and history when WoW saves. Change frequency and retention in Settings → Data & backups.',ns.FiresideSavedData.Enabled,ns.FiresideSavedData.SetEnabled)
local get,set=reading('journalReducedMotion',false)
option(s,'journalReducedMotion','Use less animation','Keep page turns and camera changes simple. You can change this later in Settings → Oasis & Journal.',get,set)
s=step('Keep the stories you want','Your Journal can turn the adventures you play into a personal story. Recording is optional, stays on this computer, and does not share your history. Chat and private conversations have separate controls in Settings.')
option(s,'recording','Remember my adventures','Keep quests, encounters and other supported adventure history for Atlas and Athena’s Journal. Leave off to explore without recording.',function()return ns.Permissions.HistoryConsent()end,function(v)
 if v and not ns.Modules.Selected('chronicle')then local ok,why=ns.Modules.Set('chronicle',true);if ok==false then return false,why end end
 return ns.Chronicle.SetEnabled(v)
end)
get,set=reading('journalAskRecollections',true)
option(s,'journalAskRecollections','Let me add my own memories','Occasionally invite you to add your perspective to a recorded adventure. You can always skip the invitation.',get,set)
get,set=reading('journalLore',true)
option(s,'journalLore','Add a little world lore','Include background about the places you visit alongside your own story.',get,set)
s=step('Your tools, working together','Everything is ready to use: there are no modules to switch on or off. These tools work together while your recording and privacy choices stay yours.')
s.tips={{'Logos · comfortable chat','Manage wording filters and chat tools without searching through the rest of the menu.'},
 {'Aegis · unwanted contact','Manage invitations and repeated unwanted interactions.'},
 {'Vigil · useful notices','Choose the mentions and alerts you want. The bell gathers your notifications.'},
 {'Aether · people and community','Explore player profiles and community features. Sharing and private-chat capture remain separate choices in Settings.'}}
local final=step('Your next adventure starts here','You do not need to learn every tab now. Start with the world and your Journal; come back to the rest when you need them. Save & explore applies the choices you made in this tour.')
final.tips={
 {'Explore the Fields','Close Menu and click the ground to walk. Hover over an entrance to see where it leads.'},
 {'Find your home','The gatehouse leads to Olympian Oasis. Its tab is your Hearthstone shortcut home. The home’s lower-left exit returns to the Fields.'},
 {'Read, remember and discover','Your home’s book opens Athena’s Journal. Atlas holds adventure history and routes; Athenaeum is your library of world knowledge.'},
 {'Meet people at your pace','Aether brings together player profiles and community features. Review sharing in Settings → Aether community when you are ready.'},
 {'Your menu is always nearby','Open Menu returns to Olympus Hall. Settings holds sound, privacy and this welcome tour whenever you want another look.'}}
function O.Set(key,value)
 if not O.byKey[key]or type(value)~='boolean'or not O.draft then return false end
 O.draft[key]=value;O.dirty[key]=value~=O.original[key];O.Render(true);return true
end
local function text(parent,value,size,color,x,y,width,height)
 local f=C.Text(parent,value,size,color);f:SetPoint('TOPLEFT',x,y);f:SetSize(width,height);f:SetWordWrap(true);return f
end
function O.Defer()
 O.deferred=true
 if ns.WardenWelcomeGuide then ns.WardenWelcomeGuide.Cancel('Tour saved for later')end
 if O.window then O.window:Hide()end
 if U.window and U.window:IsVisible()then U.CloseMenu()end
 return true
end
function O.Ensure()
 if O.window then return end
 local shield=CreateFrame('Button',nil,UIParent);O.shield=shield;shield:SetAllPoints(U.window);shield:SetFrameStrata('FULLSCREEN_DIALOG');shield:SetFrameLevel(190);shield:EnableMouse(true);C.Fill(shield,{.005,.012,.024,.65});shield.ChatWardenModalOwner=U.window;shield:Hide()
 local f=C.Card(UIParent,'Welcome to Fireside',false);O.window=f;ns.ModuleUI.welcome=f;f.heading:Hide()
 f:SetSize(960,760);f:SetPoint('CENTER',U.window,'CENTER');f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetFrameLevel(200);f:EnableMouse(true);f:SetClampedToScreen(true);f.ChatWardenModalOwner=U.window
 local logo=ns.WardenArt.Texture(f,'BrandHeader','ARTWORK');logo:SetSize(300,75);logo:SetPoint('TOP',0,-37);O.logo=logo
 local host=CreateFrame('Frame',nil,f);host:SetPoint('TOPLEFT',logo,'TOPLEFT');host:SetSize(300,75);if host.SetClipsChildren then host:SetClipsChildren(false)end
 O.flame=ns.WardenFlame.Surface(host,'brand',0);local b=ns.WardenArt.headerFlame
 ns.WardenSceneGraph.Place(O.flame.frame,host,b.x,b.y,b.width,b.height)
 O.title=text(f,'',24,C.colors.gold,32,-132,896,37)
 O.progress=text(f,'',12,C.colors.muted,32,-174,896,23)
 O.help=text(f,'',14,C.colors.text,32,-211,896,85)
 local body=CreateFrame('Frame',nil,f);body:SetPoint('TOPLEFT',30,-307);body:SetPoint('BOTTOMRIGHT',-30,125);O.page=C.Page(body)
 O.status=text(f,'',12,C.colors.gold,32,-650,896,42)
 O.back=C.Button(f,'Back',function()O.Go(-1)end,110);O.back:SetPoint('BOTTOMLEFT',32,28)
 O.later=C.Button(f,'Finish later',O.Defer,150);O.later:SetPoint('BOTTOMLEFT',154,28)
 O.next=C.Button(f,'Continue',function()O.Go(1)end,220);O.next:SetPoint('BOTTOMRIGHT',-32,28)
 local age=0;f:SetScript('OnUpdate',function(_,dt)age=age+math.max(0,math.min(.1,dt));O.flame:Draw(b.width,b.height,age,1,not(ns.DB and ns.DB.journalReducedMotion))end)
 f:SetScript('OnShow',function()shield:Show();T.FitWindow(f,960,760)end)
 f:SetScript('OnHide',function()
  shield:Hide();if O.escape then O.escape.silent=true;O.escape:Hide();O.escape.silent=nil end
  local guide=ns.WardenWelcomeGuide
  if O.hasOpened and guide and guide.state and guide.state.phase=='setup'then O.deferred=true;guide.Cancel('Tour saved for later')end
 end)
 local escape=CreateFrame('Frame','FiresideWelcomeEscape',UIParent);O.escape=escape;escape:Hide()
 escape:SetScript('OnHide',function(self)if not self.silent and f:IsShown()then O.Defer()end end)
 if UISpecialFrames then table.insert(UISpecialFrames,1,'FiresideWelcomeEscape')end
 f:Hide()
end
function O.Render(keepScroll)
 local s=O.steps[O.index];if not s then return end
 O.title:SetText(s.title);O.progress:SetText('A quick welcome · '..O.index..' / '..#O.steps)
 O.help:SetText(s.help);O.back:SetEnabled(O.index>1);O.next:SetLabel(s==final and'Save & explore'or'Continue')
 O.status:SetText(O.message or(s==final and('Your choices: music '..(O.draft.music and'on'or'off')..' · adventure recording '..(O.draft.recording and'on'or'off')..'. You can change these in Settings.')or'Your choices are saved only when you choose Save & explore.'))
 local items={}
 if s.tips then
  if s==final and O.RecordingSummary then items[#items+1]={title=O.RecordingSummary(),wrap=true,height=170}end
  for _,tip in ipairs(s.tips)do items[#items+1]={title=tip[1]..'\n'..tip[2],wrap=true,height=tip[3]or 62}end
 else for _,v in ipairs(s.options)do local key=v.key;local warning=O.OptionWarning and O.OptionWarning(v)
  items[#items+1]={title=(O.draft[key]and'[x]  'or'[ ]  ')..v.title..'\n'..v.help..(warning and'\n|cffffcc66'..warning..'|r'or''),
  detail=O.draft[key]and'On · click to change'or'Off · click to change',widths={.78,.22},wrap=true,height=v.risk and 132 or 82,activate=function()O.Set(key,not O.draft[key])end}end end
 O.page:SetItems(items,keepScroll and O.page.scroll:GetVerticalScroll()or 0)
end
function O.Open(force)
 if not ns.DB or not ns.Modules.config or busy()or not ns.Membership.Allowed()or O.applying then return false end
 if not force and((not ns.Modules.needsWelcome and not(O.NeedsRecordingReview and O.NeedsRecordingReview()))or O.deferred)then return false end
 U.Ensure();O.Ensure();if O.window:IsShown()and not force then return true end
 O.draft={};O.original={};O.dirty={};O.message=nil;O.index=1;O.deferred=nil
 for _,v in ipairs(O.options)do local value=v.get()==true;O.draft[v.key]=value;O.original[v.key]=value end
 O.Render();O.hasOpened=true;O.window:Show();O.escape:Show();return true
end
function O.Go(delta)
 if not O.draft or busy()then O.message='Continue your tour after combat.';if O.window then O.Render()end;return false end
 if delta>0 and O.index==#O.steps then return O.Finish()end
 O.index=math.max(1,math.min(#O.steps,O.index+delta));O.message=nil;O.Render();return true
end
function O.Finish()
 if O.applying or not O.draft or O.index~=#O.steps or busy()or not ns.Membership.Allowed()then return false end
 O.applying=true
 local function apply()
  for _,v in ipairs(O.options)do if O.dirty[v.key]and not v.group then
   local ok,why=v.set(O.draft[v.key]);if ok==false then return false,v.title..': '..tostring(why or'Please try this choice again.')end
   O.dirty[v.key]=nil;O.original[v.key]=O.draft[v.key]
  end end
  if O.ApplyRecordingGroups then local ok,why=O.ApplyRecordingGroups();if not ok then return false,why end end
  if not O.draft.recording then local ok=ns.Chronicle.SetEnabled(false);if ok==false then return false,'Your recording choice could not be saved.'end end
  if O.MarkRecordingReview then local ok,why=O.MarkRecordingReview();if not ok then return false,why end end
  return true
 end
 local ran,ok,why=pcall(apply);O.applying=nil
 if not ran or not ok then O.message=ran and why or'A choice could not be saved. Your other choices are kept; please try again.';O.Render();return false end
 ns.Modules.config.onboardingDone=true;ns.Modules.needsWelcome=false;ns.DB.welcomeSeen=1;ns.DB.firesideWelcomeGuide=O.VERSION
 if ns.WardenWelcomeGuide then ns.WardenWelcomeGuide.Complete()end
 O.window:Hide();U.CloseMenu();return true
end
ns.ModuleUI.Welcome=function()return false end -- First deliberate open owns the cinematic/tour sequence.
ns.OpenWelcome=function()return O.Open(true)end
ns.CheckWelcome=function()return false end
local oldPrompt=ns.Chronicle.MaybePrompt
ns.Chronicle.MaybePrompt=function(...)
 if ns.Modules.needsWelcome or O.window and O.window:IsShown()or ns.WardenWelcomeGuide and ns.WardenWelcomeGuide.Active()then return false end
 return oldPrompt(...)
end

-- Installed release notes are local UI, independent of collectors and Aether.
local P={};ns.UI2PatchNotes=P
P.version=ns.ClientBuild and ns.ClientBuild.revision or ns.VERSION
P.subtitle='Aether Live · Welcome to the future of Fireside'
P.cards={{'Aether grows with us','One connection now brings our community together. Aether Live carries approved profiles, Agora conversations and shared adventures alongside the living world.'},
 {'A little more to discover','Join Live and your saved community pages can catch up with other participating players, even while Fireside is closed. Return later and see what your fellow adventurers have shared.'},
 {'Your story stays your choice','Joining does not publish your drafts, private notes, watchlists or conversations. Choose community sharing when you want to post, update your public profile or share an adventure.'},
 {'Friends, a little more familiar','Supported outfit appearances travel with Live. Gear updates keep the same character and movement where possible. Some faces, clothing and forms still depend on what the client can reproduce.'},
 {'Built around the gathering','Movement and connection health come first. Shared pages catch up in small steps when there is room. Other players need to be reachable; Aether cannot promise a permanent online archive.'},
 {'One Aetheria. One Olympus.','The separate Relay connection has retired. Your saved records and sharing choices are kept. Meet someone, discover their story and keep building this world with us. Keep the Fire Alive.'}}

local previous=ns.InstalledUpdate;if previous then previous.version='1.1.4-unified-2.11.8-overnight1' end
ns.InstalledUpdate={version=P.version,subtitle=P.subtitle,cards={}}
for _,v in ipairs(P.cards) do ns.InstalledUpdate.cards[#ns.InstalledUpdate.cards+1]={v[1],v[2],'settings'} end
if ns.UpdateHistory then table.insert(ns.UpdateHistory,1,ns.InstalledUpdate) elseif previous then ns.UpdateHistory={ns.InstalledUpdate,previous} end
function P.Open()
 if not ns.DB or busy() or not ns.Membership.Allowed() then return false end
 if not P.window then
  local f=C.Card(UIParent,'What’s new in Fireside',false);P.window=f;f:SetSize(960,710);f:SetPoint('CENTER');f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetFrameLevel(190);f:EnableMouse(true);f:SetClampedToScreen(true)
  text(f,P.subtitle,23,C.colors.gold,26,-54,900,44)
  text(f,'Your existing history and settings are kept.',13,C.colors.muted,26,-105,900,30)
  for i,v in ipairs(P.cards) do local col=(i-1)%2;local row=math.floor((i-1)/2);local panel=C.Card(f,v[1],false);panel:SetPoint('TOPLEFT',26+col*460,-153-row*142);panel:SetSize(448,130);text(panel,v[2],14,C.colors.text,14,-45,420,76) end
  P.preference=C.Button(f,'',function() ns.DB.showUpdates=ns.DB.showUpdates==false;P.preference:SetLabel(ns.DB.showUpdates and 'Show future patch notes: On' or 'Show future patch notes: Off') end,270);P.preference:SetPoint('BOTTOMLEFT',26,31)
  C.Button(f,'Review setup',function() f:Hide();O.Open(true) end,180):SetPoint('BOTTOMRIGHT',-200,31)
  C.Button(f,'Close',function() f:Hide() end,140):SetPoint('BOTTOMRIGHT',-26,31)
  f:SetScript('OnShow',function() T.FitWindow(f,960,710) end);f:Hide()
 end
 P.preference:SetLabel(ns.DB.showUpdates~=false and 'Show future patch notes: On' or 'Show future patch notes: Off')
 P.window:Show();if P.window:IsShown() then ns.DB.updateSeen=P.version end;return true
end
ns.OpenUpdates=P.Open
function ns.CheckUpdateScreen(event)
 if event=='PLAYER_LOGIN' or event=='PLAYER_ENTERING_WORLD' then P.loginReady=true end
 if not P.loginReady then P.loginReady=ns.Checked(ns.SafeCall(IsLoggedIn)) end
 if not P.loginReady or not ns.DB or not ns.Membership.Allowed() or ns.Modules.needsWelcome or O.window and O.window:IsShown() or P.queued or busy() or not UIParent:IsVisible() or ns.DB.showUpdates==false or ns.DB.updateSeen==P.version then return end
 local function show()
  P.queued=nil
  if ns.DB and ns.DB.showUpdates~=false and ns.DB.updateSeen~=P.version and not ns.Modules.needsWelcome and not (O.window and O.window:IsShown()) then P.Open() end
 end
 P.queued=true;if C_Timer and C_Timer.After then C_Timer.After(.2,show) else show() end
end
