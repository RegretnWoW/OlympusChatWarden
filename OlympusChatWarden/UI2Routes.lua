-- Compatibility adapters preserve intent and arguments, never legacy frames.
local _,ns=...
local U,F=ns.UI2,ns.UI2Forms
local pageAliases={home='overview',chat='messages',signal='mentions',capture='messages',rules='messages',packs='messages',reports='messages',recording='chronicle',performance='settings',modules='settings',updates='settings'}
local subAliases={capture='capture',rules='rules',packs='packs',reports='reports',recording='life'}
local categories={shield='protections',spam='spam',languages='language',notifications='notifications',spelling='spelling',chronicle='recording',performance='data',modules='modules',updates='advanced'}
function U.Normalize(route)
 if type(route)~='table' then route={page=type(route)=='string' and route or 'overview'} end
 local out={};for k,v in pairs(route) do out[k]=v end
 local original=out.page or 'overview';out.page=pageAliases[original] or original
 out.subsection=out.subsection or subAliases[original];out.category=out.category or categories[original]
 if out.page=='mentions' and out.selectedID==nil then out.selectedID=out.notificationID end
 if not ({search=true,wiki=true,overview=true,journey=true,chronicle=true,intel=true,messages=true,shield=true,mentions=true,relay=true,settings=true})[out.page] then return nil,'Unknown Olympus destination.' end
 if out.kind and not ({player=true,activity=true,group=true,guild=true})[out.kind] then return nil,'Unknown subject type.' end
 for _,key in ipairs({'key','owner','query','messageID','activityID','selectedID','category','subsection','originGuild','room','post','view','cursor','authorGUID','roomCategory','draft'}) do local v=out[key];if v~=nil and (type(v)~='string' and type(v)~='number' or #tostring(v)>512) then return nil,'Invalid navigation argument: '..key end end
 if out.page=='wiki' or out.page=='search' then
  if out.key~=nil and (not ns.AthenaLivingWiki or not ns.AthenaLivingWiki.ValidKey(out.key)) then return nil,'Invalid Wiki article identity.' end
  if out.wikiKind~=nil and out.wikiKind~='ALL' and not ns.AthenaLivingWiki.types[out.wikiKind] then return nil,'Unknown Wiki category.' end
  for _,field in ipairs({'wikiOffset','discussionPage','storyOffset'}) do local v=out[field];if v~=nil and (type(v)~='number' or v~=v or v%1~=0 or v<0 or v>100000) then return nil,'Invalid search page.' end end
  out.owner=ns.Chronicle.Owner()
 end
 if out.originGuild and (out.page~='chronicle' or out.kind~='activity' or type(out.originGuild)~='string' or #out.originGuild>120 or not out.originGuild:match('^Guild%-[%w%-]+$')) then return nil,'Invalid guild presentation context.' end
 for _,key in ipairs({'revealSpoiler','publicEvent','preview'})do if out[key]~=nil and type(out[key])~='boolean'then return nil,'Invalid explicit preview flag.'end end
 if out.subsection=='agora'then
  if out.room and not ns.AetherPostRooms.Valid(out.room)then return nil,'Unknown predefined Agora room.'end
  if out.post and not ns.AetherPosts.ValidID(out.post)then return nil,'Invalid post identity.'end
  if out.view and not({recent=true,following=true,popular=true,mine=true,author=true,drafts=true,bookmarks=true,controls=true,rooms=true,archive=true})[out.view]then return nil,'Unknown post view.'end
 end
 out.owner=out.owner or ns.Chronicle.Owner();return out
end
local open=U.Open
function U.Open(route,replacing)
 local normalized,why=U.Normalize(route);if not normalized then return false,why end
 if ns.Checked(ns.SafeCall(InCombatLockdown)) then U.deferred={route=normalized,replacing=replacing};return false,'Olympus will open this destination after combat.' end
 if U.feedback and U.feedbackRoute and U.feedbackRoute~=normalized.page..'/'..tostring(normalized.category or normalized.subsection or '') then U.feedback=nil;U.feedbackRoute=nil end
 return open(normalized,replacing)
end
local queue=CreateFrame('Frame');queue:RegisterEvent('PLAYER_REGEN_ENABLED');queue:SetScript('OnEvent',function() if U.deferred then local request=U.deferred;U.deferred=nil;U.Open(request.route,request.replacing) end end)
local function settings(category,subsection) return U.Open({page='settings',category=categories[category] or category or 'general',subsection=subsection}) end
function ns.BuildOptions(requested)
 if not ns.DB then return false end
 if not U.optionsRegistered then
  -- The native category is a new, small integration entry to the same settings.
  local panel=CreateFrame('Frame','OlympusUI2NativeSettings',UIParent);panel.name='Fireside';panel:Hide()
  local C=ns.UI2Components;local title=C.Text(panel,'Fireside',22);title:SetPoint('TOPLEFT',24,-24);title:SetSize(520,35)
  local note=C.Text(panel,'Open the unified Settings page. Module selection, recording consent and sharing consent are separate choices.',14);note:SetPoint('TOPLEFT',24,-76);note:SetSize(540,70);note:SetWordWrap(true)
  C.Button(panel,'Open Olympus Settings',function() settings('general') end,260):SetPoint('TOPLEFT',24,-164)
  U.optionsPanel=panel
  if Settings and type(Settings.RegisterCanvasLayoutCategory)=='function' and type(Settings.RegisterAddOnCategory)=='function' then
   local ok,category=pcall(Settings.RegisterCanvasLayoutCategory,panel,'Fireside');if ok and category then local added=pcall(Settings.RegisterAddOnCategory,category);if added then U.optionsCategory=category;U.optionsRegistered='modern' end end
  elseif type(InterfaceOptions_AddCategory)=='function' then local ok=pcall(InterfaceOptions_AddCategory,panel);if ok then U.optionsRegistered='classic' end end
  if not U.optionsRegistered then U.optionsRegistered='command-fallback' end
 end
 if requested and requested~='all' then return settings(requested) end
 return true,U.optionsRegistered
end
ns.OpenOptions=function() return settings('general') end
for name,category in pairs({OpenChronicleOptions='recording',OpenShieldOptions='protections',OpenSpamOptions='spam',OpenSpellingOptions='spelling',OpenNotificationOptions='notifications',OpenLanguageOptions='language',OpenTextCoverage='coverage',OpenCategories='packs'}) do local target=category;ns[name]=function() return settings(target) end end
function ns.OpenPacks(section,id) return U.Open({page='messages',subsection='packs',mode=section,selectedID=id,postAction=section=='import' and 'pack-import' or section=='download' and 'pack-download' or nil}) end
function ns.OpenRules(id) return U.Open({page='messages',subsection='rules',selectedID=id}) end
function ns.OpenReports() return U.Open({page='messages',subsection='reports'}) end
function ns.OpenPersonal(mode) return U.Open({page='messages',subsection=mode=='rules' and 'rules' or 'reports'}) end
function ns.OpenShield() return U.Open({page='shield'}) end
function ns.OpenShieldPlayer(name) local key=ns.Shield.Key(name);if not key then return false,'Enter a valid player name.' end;return U.Open({page='shield',selectedID=key,contact=name}) end
function ns.OpenReview(mode,id) return U.Open({page=mode=='shield' and 'shield' or mode=='mentions' and 'mentions' or 'messages',subsection='review',messageID=id}) end
function ns.OpenCapture() return U.Open({page='messages',subsection='capture'}) end
function ns.OpenReport(entry,kind) return U.Open({page='messages',subsection='report',reportEntry=entry,reportKind=kind}) end
function ns.OpenReportExport(mode) return U.Open({page='messages',subsection='reports',mode=mode,exportRequested=true}) end
function ns.OpenShieldExport() return U.Open({page='shield',subsection='export'}) end
function ns.OpenExport(mode) return U.Open({page='settings',category='data',mode=mode}) end
ns.Workspace.Open=function(page,args) local route=type(page)=='table' and page or args or {};if type(page)=='string' then route.page=page end;return U.Open(route) end
ns.Workspace.Settings=settings
ns.WardenUI.Navigate=function(kind,owner,key,event)
 if kind=='story' then return U.Open({page='journey',owner=owner,storyId=key}) end
 if kind=='highlight' then
  if event then return ns.UI2Browse.OpenSearch({data={event=event,owner=owner}}) end
  return U.Open({page='chronicle',subsection='progress',owner=owner,selectedID=key})
 end
 if kind=='history' and not ns.Modules.Enabled('intel') then return U.Open({page='chronicle',owner=owner,guid=key,subsection='activities'}) end
 if kind=='player' or kind=='history' then return U.Open({page='intel',kind='player',owner=owner,key=key,jump=kind=='history' and 'activities' or nil}) end
 return U.Open({page='chronicle',kind='activity',owner=owner,key=key})
end
ns.OpenCapturePlayer=function(name) return U.Open({page='messages',subsection='capture',sender=name}) end
ns.OpenCaptureBookmark=function(id) return U.Open({page='messages',subsection='bookmarks',selectedID=id}) end
ns.Workspace.Destination=function(page) U.Open({page=page});return nil end -- no legacy page/frame handoff
local slash=SlashCmdList and SlashCmdList.OLYMPUSCHATWARDEN
if slash then SlashCmdList.OLYMPUSCHATWARDEN=function(message)
 local command,arg=(message or ''):match('^%s*(%S*)%s*(.-)%s*$');command=(command or ''):lower()
 if command=='relay' or command=='relaywarden' or command=='bug' then return U.Open({page='relay',subsection=arg~='' and arg or 'reports'}) end
 if command=='search' then return U.Open({page='overview',subsection='search',query=arg}) end
 if command=='journal' or command=='journey' or command=='athena' then return U.Open({page='journey'}) end
 if command=='packs' then return ns.OpenPacks(arg~='' and arg or nil) end
 if command=='feedback' then return ns.OpenReportLink() end
 if command=='rules' then return ns.OpenRules() end
 if command=='minimap' then return settings('appearance') end
 if command=='chronicle' and (arg=='events' or arg=='activities' or arg=='backup') then return U.Open({page=arg=='backup' and 'settings' or 'chronicle',category=arg=='backup' and 'data' or nil,subsection=arg=='events' and 'life' or arg}) end
 if command=='intel' and arg=='history' then return ns.Chronicle.IntelSlash('history') end
 if command=='options' or command=='' then return settings('general') end
 if command=='welcome' then return ns.OpenWelcome() end
 if command=='updates' then return ns.OpenUpdates() end
 if command=='help' or command=='tutorial' then return ns.OpenTutorial(arg~='' and arg or nil) end
 return slash(message)
end end
ns.OpenTutorial=function(section) return settings('advanced',section or 'help') end
ns.OpenUpdates=function() return settings('advanced','updates') end
ns.OpenWelcome=function() return settings('modules') end
ns.OpenReportLink=function() return U.Open({page='relay'}) end
