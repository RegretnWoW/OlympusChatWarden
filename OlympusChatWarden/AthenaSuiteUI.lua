-- Contextual pages inside the existing Olympus workspace, never a second finder.
local _,ns=...
local U={VERSION=1};ns.AthenaSuiteUI=U
local R,V=ns.Athena2,ns.Art
local function text(t) return ns.WardenBrand.Text(tostring(t or 'Unknown')) end
local shareLabels={personKey='Character identity',name='Name',realm='Realm',class='Class',race='Race',faction='Faction',levelBand='Level band',guild='Guild',guildDate='Guild observation day',sourceClass='Source',freshness='Freshness',pvp='Observed PvP',pve='PvE evidence',rating='Community opinions',status='Status',clears='Verified clears',scope='Scope',matchCount='Observed match boundaries',killingBlows='Killing blows',honorableKills='Honorable kills',deaths='Deaths',damageDone='Damage',healingDone='Healing',honorGained='Honor gained',coverage='Coverage',average='Average stars',count='Votes',identityGuarantee='Voter identity guarantee',eventKey='Event identity',activityType='Activity',mapID='Map identity',mapName='Place',dateBucket='Observation day',outcome='Outcome',matching='Event matching'}
local function shareText(projection)
 local card=projection and projection.card;if not card then return 'Choose Review offer to prepare the information for this recipient.' end
 local lines={}
 local function fields(value,prefix,depth)
  local keys={};for key in pairs(value) do if key~='schema' and key~='kind' then keys[#keys+1]=key end end;table.sort(keys)
  for _,key in ipairs(keys) do
   local label=(prefix or '')..(shareLabels[key] or tostring(key));local v=value[key]
   if type(v)=='table' and depth<4 then
    if next(v) then fields(v,label..' · ',depth+1) else lines[#lines+1]=label..': none included' end
   elseif type(v)~='table' then
    if key=='sourceClass' then v=v=='synthetic_fixture' and 'Synthetic test data; not native verified' or v=='self_record' and 'Self-recorded observation' or v=='local_observation' and 'Local observation' or v end
    lines[#lines+1]=label..': '..text(v)
   end
  end
 end
 fields(card,'',0);return table.concat(lines,'\n')
end
local function base(page,title,subtitle)
 local p=page.athenaSuite
 if not p then
  p=CreateFrame('Frame',nil,page);p:SetAllPoints(page);p:SetFrameLevel(page:GetFrameLevel()+20);p:EnableMouse(true)
  local bg=p:CreateTexture(nil,'BACKGROUND');bg:SetAllPoints();bg:SetColorTexture(.035,.058,.082,1)
  local relay=page==ns.Workspace.pages.relay
  local hero=V.Panel(p,0,0,1136,relay and 64 or 88,'header');V.Icon(hero,'intel',relay and 48 or 64,14,relay and -8 or -12)
  p.title=V.Text(hero,'Athena',92,relay and -7 or -15,790,25,V.gold);p.title:SetHeight(relay and 30 or 34)
  p.subtitle=V.Text(hero,'',94,relay and -41 or -52,790,13,V.muted);p.subtitle:SetHeight(relay and 18 or 24)
  V.Button(hero,'Back',964,relay and -15 or -25,152,34,function() p:Hide() end,'neutral')
  p.content=CreateFrame('Frame',nil,p);p.content:SetPoint('TOPLEFT',0,relay and -76 or -102);p.content:SetSize(1136,relay and 568 or 582)
  p.sections={};p.ownerPage=page;page.athenaSuite=p
  local refresh,activate=page.Refresh,page.Activate
  if refresh then page.Refresh=function(self,...) if self.athenaSuite:IsShown() then return end;return refresh(self,...) end end
  if activate then page.Activate=function(self,...) self.athenaSuite:Hide();return activate(self,...) end end
  p:HookScript('OnHide',function()
   for _,child in ipairs(p.covered or {}) do child:Show() end
   p.covered=nil
  end)
  page:HookScript('OnHide',function() p:Hide() end)
 end
 -- Hide the covered page's actual widgets. An opaque texture alone does not
 -- retire their focus targets, and retained child labels can overlap overlays.
 if not p.covered then
  p.covered={}
  for _,child in ipairs({page:GetChildren()}) do if child~=p and child:IsShown() then p.covered[#p.covered+1]=child;child:Hide() end end
  for _,region in ipairs({page:GetRegions()}) do if region:IsShown() then p.covered[#p.covered+1]=region;region:Hide() end end
 end
 for _,section in pairs(p.sections) do section:Hide() end
 p.title:SetText(text(title));p.subtitle:SetText(text(subtitle));p:Show();return p
end
local function section(p,key)
 if not p.sections[key] then local f=CreateFrame('Frame',nil,p.content);f:SetAllPoints();p.sections[key]=f end
 local f=p.sections[key];f:Show();return f
end
function U.OpenPlayer(guid,owner)
 if not R.GUID(guid) or not ns.AthenaProfiles.GetPlayer(guid,owner,'intel') then return false end
 if guid==(owner or R.Owner() or ''):match('/(Player%-.+)$') then return U.Profile(guid,owner) end
 if ns.Workspace.pages.intel and ns.Workspace.pages.intel.athenaSuite then ns.Workspace.pages.intel.athenaSuite:Hide() end
 return ns.WardenUI.Navigate('player',owner or R.Owner(),guid)
end
function U.Group(key,adapter,viewer)
 if not R.Permit('intel') then return false end
 adapter=adapter or ns.AthenaNativeLFGAdapter.Current;local listing=adapter:Get(key)
 local page=ns.Workspace.Destination('intel');if not page then return false end
 local p=base(page,'Group Intelligence','Native listing context · read only · no automatic Aether lookups')
 local f=section(p,'group');f.adapter=adapter;f.key=key;f.viewer=viewer or ns.Fellowship.Context();f.offset=0
 if not f.header then
  local card=V.Panel(f,0,0,1136,128,'dark')
  f.header=V.Text(card,'',20,-14,1090,21,V.gold);f.header:SetHeight(30)
  f.score=V.Text(card,'',20,-52,1090,16,V.blue);f.score:SetHeight(28)
  f.reason=V.Text(card,'',20,-86,1090,13,V.muted);f.reason:SetHeight(34)
  V.Text(f,'Member / identity',20,-145,390,14,V.gold);V.Text(f,'Class · role · level',430,-145,320,14,V.gold);V.Text(f,'Recorded context',770,-145,340,14,V.gold)
  f.rows={}
  for i=1,10 do
   local row=V.Panel(f,0,-168-(i-1)*31,1136,29,'minimal')
   row.name=V.Text(row,'',16,-5,396,13,V.gold);row.name:SetHeight(22)
   row.role=V.Text(row,'',430,-5,326,13,V.muted);row.role:SetHeight(22)
   row.context=V.Text(row,'',770,-5,190,12,V.muted);row.context:SetHeight(22)
   row.open=V.Button(row,'Intel',980,-1,140,27,function() if row.guid then U.OpenPlayer(row.guid) end end,'neutral');f.rows[i]=row
  end
  f.status=V.Text(f,'',18,-486,1094,12,V.muted);f.status:SetHeight(38)
  V.Button(f,'Previous',0,-539,180,34,function() f.offset=math.max(0,f.offset-10);f:Refresh() end,'neutral')
  V.Button(f,'Next members',190,-539,180,34,function() if f.nextOffset then f.offset=f.nextOffset;f:Refresh() end end,'neutral')
  f.roleChoice=V.Dropdown(f,384,-539,274,{{'UNKNOWN','My role: undecided'},{'TANK','My role: tank'},{'HEALER','My role: healer'},{'DAMAGER','My role: damage'}},
   function() return f.viewer.role or 'UNKNOWN' end,function(value)
    f.viewer.role=value~='UNKNOWN' and value or nil;ns.Fellowship.preferredRole=f.viewer.role;ns.Fellowship.revision=ns.Fellowship.revision+1;f:Refresh()
   end)
  f.returnButton=V.Button(f,'Return to native listing',674,-539,230,34,function()
   local current=f.adapter:Get(f.key);if not current then f:Refresh();return end
   if f.nativeReturn then f.nativeReturn(current) else f.status:SetText('NATIVE-PENDING · Open Blizzard Group Finder normally. No Apply action was sent.') end
  end,'neutral')
  f.outreach=V.Button(f,'Review contact',916,-539,220,34,function()
   local s=f.adapter:Get(f.key);if s and s.leader.guid and s.leader.name and s.leader.realm then
    local target=R.Copy(s.leader);target.nativeListing=true;target.expiresAt=s.expiresAt;target.intent='LFM';target.listingKey=s.key;target.listingRevision=s.revision
    ns.RelayOutreach.Current:Cancel('New user-selected listing')
    ns.RelayOutreach.Current=ns.RelayOutreach.New({validateTarget=function(t)
     local current=f.adapter:Get(t.listingKey);return current and current.revision==t.listingRevision and current.leader.guid==t.guid and not current.full and current.spaces~=0
    end})
    U.Outreach(target,{activityName=s.activityName,role=f.viewer.role})
   end
  end,'neutral')
  function f:Refresh()
   local rows,nextOffset,s=self.adapter:Page(self.key,self.offset);self.nextOffset=nextOffset
   self.lastRevision=self.adapter.revision;self.expiresAt=s and s.expiresAt
   for _,row in ipairs(self.rows) do row:Hide() end
   self.returnButton:SetEnabled(s~=nil);self.outreach:SetEnabled(s and not s.full and s.spaces~=0 and s.eligible~=false and s.leader.guid and s.leader.realm and s.leader.name and true or false)
   if not s then self.header:SetText('Expired listing');self.score:SetText('This search result is no longer current.');self.reason:SetText('Return to Blizzard Group Finder for its current results.');self.status:SetText('No stale member or Apply links remain active.');return end
   local m=ns.AthenaGroupMatch.Score(self.viewer,s,self.adapter.clock())
   self.header:SetText(text(s.activityName or ('Activity '..s.activityID))..' · '..text(s.title or 'Native group'))
   self.score:SetText(m.score and ('Group Match '..m.score..'% · evidence coverage '..m.coverage..'% · '..s.memberCoverage) or (m.state..' · '..table.concat(m.blockers,', ')))
   self.reason:SetText(text(table.concat(m.reasons,' · ')))
   for i,member in ipairs(rows or {}) do local row=self.rows[i];row:Show();row.guid=member.guid
    row.name:SetText(text(member.name or ('Unknown member '..(self.offset+i))))
    row.role:SetText(text((member.class or 'Class unknown')..' · '..(member.role or 'Role unknown')..' · '..(member.level or '?')))
    local profile=member.guid and ns.AthenaProfiles.GetPlayer(member.guid,nil,'intel')
    row.open:SetEnabled(profile~=nil);row.context:SetText(profile and 'Local observations' or member.guid and 'No local dossier' or 'Identity unavailable')
   end
   self.status:SetText((s.source=='SYNTHETIC_BLIZZARD_LFG_FIXTURE' and 'SYNTHETIC listing · ' or 'Official listing · ')..'generation '..s.generation..' · leader '..text(s.leader.name or 'unavailable')..' · missing member data is neutral. Stars, Player Match and Group Match are separate.')
  end
  f:SetScript('OnUpdate',function(self,elapsed)
   self.tick=(self.tick or 0)+elapsed;if self.tick<.5 then return end;self.tick=0
   if self.lastRevision~=self.adapter.revision or self.expiresAt and self.adapter.clock()>=self.expiresAt then self:Refresh() end
  end)
 end
 f:Refresh();return true,f
end
function U.Profile(guid,owner,client)
 if not R.Permit('intel') then return false end
 owner=owner or R.Owner();local profile,status=ns.AthenaProfiles.GetPlayer(guid,owner,'intel')
 local page=ns.Workspace.Destination('intel');if not page then return false end
 local p=base(page,'Athena Insights',profile and (profile.identity.name or guid)..' · local evidence / imported claims kept separate' or 'Profile '..tostring(status))
 local f=section(p,'profile');f.guid=guid;f.owner=owner
 if not f.document then
  local panel=V.Panel(f,0,0,1136,474,'dark');f.document=V.Document(panel,22,-20,1092,428)
  f.listing=V.Button(f,'Inspect active listing',0,-528,240,36,function() local s=ns.AthenaNativeLFGAdapter.Current:LeaderListing(f.guid);if s then U.Group(s.key) end end,'neutral')
  V.Button(f,'Direct Share',256,-528,220,36,function() U.Direct(f.guid,f.owner) end,'neutral')
  V.Button(f,'Search Aether',492,-528,220,36,function() U.Aether() end,'neutral')
  f.contact=V.Button(f,'Review group contact',728,-528,272,36,function() local target=ns.Fellowship.roster[f.guid];if target then U.Outreach(target,{}) end end,'neutral')
 end
 local stats=profile and ns.AthenaInsights.Get('PVP_OBSERVED_SUMMARY',guid,{owner=owner,consumer='intel'})
 client=client or ns.AthenaExchange.Current
 local rating=client and client.ratings:Get(guid)
 local claims=client and client.shared:Get('player',guid) or {}
 local match=ns.Fellowship.GetPlayerMatch(guid);local listing=ns.AthenaNativeLFGAdapter.Current:LeaderListing(guid)
 f.listing:SetEnabled(listing~=nil);f.contact:SetEnabled(ns.Fellowship.roster[guid]~=nil)
 f.document:SetBlocks({{kind='heading',text='Local player profile'},
  {text=profile and text((profile.identity.name or guid)..' · '..(profile.identity.class or 'Class unknown')..' · '..profile.coverage..(profile.sourceOrigin=='synthetic' and ' · SYNTHETIC / NOT VERIFIED' or '')) or 'Local profile is not ready.'},
  {kind='heading',text='Fellowship Player Match'},
  {text=match and (match.score and match.score..'% · ' or '')..match.state..'\n'..table.concat(match.reasons or {},' · ') or 'Match unknown'},
  {kind='heading',text='PvP · observed matches'},
  {text=stats and (stats.matchCount..' recorded match boundaries · '..(stats.counters.killingBlows or 'Unknown')..' observed killing blows · '..(stats.counters.deaths or 'Unknown')..' observed deaths\n'..stats.coverage) or 'No supported counters available'},
  {kind='heading',text='PvE · verified accomplishments'}, {text='Whole-instance clears: Unknown. Entry, roster and final boss alone are not complete-instance proof.'},
  {kind='heading',text='Aether Community Rating'},
  {text=rating and rating.average and (string.format('%.1f / 5 stars · %d effective votes\n',rating.average,rating.count)..rating.identityGuarantee) or 'Not yet rated in the reachable validated view. Public opinions use 1–5 stars; they do not change Match % or Shield.'},
  {kind='heading',text='Received public claims'}, {text=#claims..' unexpired received cards · remote reports remain separate from the local profile.'},
  {kind='meta',text='Live Aether transport and account vote identity: NATIVE-PENDING. No request is issued by opening this dossier.'}})
 return true,f
end
function U.Health()
 if not R.Permit('command') then return false end
 local page=ns.Workspace.SettingsDestination('health');if not page then return false end
 local p=base(page,'Database Health','Read-only archive and shared intelligence status')
 local f=section(p,'health')
 if not f.document then local panel=V.Panel(f,0,0,1136,566,'dark');f.document=V.Document(panel,22,-20,1092,522) end
 local residency=ns.ChronicleStore.Residency();local jobs=ns.WardenScheduler.Health();local cache=ns.AthenaProfiles.cache
 f.document:SetBlocks({{kind='heading',text='Canonical history'},
  {text=(ns.ChronicleStore.loading and 'History validation pending; new capture retains its existing startup journal.' or ns.ChronicleStore.blocked and 'Readback unavailable; original archive kept.' or 'History ready for existing read paths.')..'\n'..residency.loadedCharacters..' loaded characters · '..residency.packedCharacters..' compact characters · '..residency.loadedEvents..' loaded events'},
  {kind='heading',text='Hot / warm / cold'}, {text='Hot: active capture and unsaved observations. Warm: bounded activity/profile views. Cold: existing packed SavedVariables strings, still parsed by WoW at login. No archive format migration or pruning.'},
  {kind='heading',text='Derived work'}, {text=jobs.pending..' queued tasks · '..jobs.completed..' completed · '..jobs.errors..' task errors\nProfile cache '..R.Count(cache.values)..' / '..cache.cap..' · hits '..cache.hits..' · misses '..cache.misses..' · evictions '..cache.evictions},
  {kind='heading',text='Native capabilities'}, {text='Group Finder ingestion / row anchors / sorting / Apply / Invite / whisper / Bridge: NATIVE-PENDING. No live exchange traffic. Existing Relay bug reports remain separate.'},
  {kind='heading',text='Durability and rollback'}, {text='Canonical Chronicle storage and conversation consent are unchanged. Keep the complete SavedVariables backup for rollback. This panel does not create or certify a backup.'},
  {kind='meta',text='Synthetic benchmark timings are not native FPS or addon-attributed RAM measurements.'}})
 return true,f
end
function U.Aether(client)
 if not R.Permit('relay') then return false end
 client=client or ns.AthenaExchange.Current
 if not client then
  client=ns.AthenaExchange.New({owner=(R.Owner() or ''):match('/(Player%-.+)$')});ns.AthenaExchange.Current=client
  local ok,why=ns.AthenaExchangeState.Bind(client);client.persistenceStatus=ok and 'Separate character-scoped local state' or tostring(why)
 end
 local page=ns.Workspace.SettingsDestination('relay');if not page then return false end
 local p=base(page,'Aether','Reciprocal public intelligence · Direct Share stays independent')
 local f=section(p,'aether');f.client=client
 if not f.document then
  local panel=V.Panel(f,0,0,1136,430,'dark');f.document=V.Document(panel,22,-20,1092,386)
  f.confirm=V.Check(f,'I reviewed the fixed public fields and character-scoped participation',12,-455,false,function(value) f.accepted=value end,1090)
  f.join=V.Button(f,'Join Aether',0,-530,260,36,function()
   local ok,why=f.client:Join(2,f.accepted==true);f.status:SetText(ok and 'Mock participation enabled. No live network.' or tostring(why));f:Refresh()
  end)
  V.Button(f,'Leave Aether',276,-530,240,36,function() f.client:Leave();f:Refresh() end,'neutral')
  V.Button(f,'Clear received cache',532,-530,270,36,function() f.client.shared:Clear();if f.client.SaveState then f.client:SaveState() end;f:Refresh() end,'neutral')
  V.Button(f,'Preview public card',818,-530,318,36,function()
   local profile=ns.AthenaProfiles.GetMyProfile('intel');local card,wire;if profile then card,wire=ns.AthenaSharePolicy.ProjectPublic(profile) end
   if wire then ns.Workspace.Copy(wire,'Public card preview') else f.status:SetText('No eligible resolved self identity is ready. Nothing was sent.') end
  end,'neutral')
  f.status=V.Text(f,'',14,-490,1090,13,V.blue);f.status:SetHeight(32)
  function f:Refresh()
   local demo=self.client.options.mockTransport~=nil
   self.join:SetEnabled(demo)
   self.document:SetBlocks({{kind='heading',text=self.client:Joined() and 'Contributing public cards · Queries enabled · Automatic mock replies' or 'Aether OFF · No contributions or network searches'},
    {text=ns.AthenaSharePolicy.Disclosure},
    {kind='heading',text='Public cards, source and limits'}, {text='Identity and dated guild · coarse level bands · supported observed statistics · public 1–5-star opinions. Unknown stays unknown. Rich history, raw scoreboards and private player recollections stay local.'},
    {kind='heading',text='Transport status'}, {text=demo and 'ISOLATED MOCK TRANSPORT · no game messages or external service' or 'NATIVE-PENDING · live Bridge transport and verified member/account authority are unavailable in this build. Join remains locked.'},
    {kind='meta',text='Remote cache '..#self.client.shared.order..' / 256 claims · '..self.client.shared.bytes..' / 262144 bytes. Received projections remain remote claims.'}})
  end
 end
 f:Refresh();return true,f
end
function U.DirectLanding()
 if not R.Permit('relay') then return false end
 local page=ns.Workspace.Destination('relay');if not page then return false end
 local p=base(page,'Direct Share','Addressed sharing · separate from Aether participation')
 local f=section(p,'directLanding')
 if not f.document then
  local panel=V.Panel(f,0,0,1136,430,'dark');f.document=V.Document(panel,22,-20,1092,386)
  V.Button(f,'Choose a recorded player in Intel',0,-470,460,36,function() ns.Workspace.Open('intel') end,'neutral')
 end
 f.document:SetBlocks({{kind='heading',text='Choose the person and review the exact information'},
  {text='Player-specific sharing starts from the recorded Intel dossier. Only supported identity or observed-career fields are eligible. Private notes, raw chat and full named scoreboards remain excluded.'},
  {kind='heading',text='Current transport'},
  {text='NATIVE-PENDING. Production recipient resolution and approved Bridge transport remain unavailable. The private simulator exercises explicit offer, acceptance and final receipt using isolated mock clients.'},
  {kind='meta',text='Opening Direct Share sends nothing and does not join Aether.'}})
 return true,f
end
function U.Direct(guid,owner)
 local profile=ns.AthenaProfiles.GetPlayer(guid,owner,'intel');if not profile then return false end
 local page=ns.Workspace.Destination('relay');if not page then return false end
 local p=base(page,'Direct Share','Addressed, reviewed and separate from Aether membership')
 local f=section(p,'direct')
 if not f.document then
  local panel=V.Panel(f,0,0,1136,552,'dark');f.document=V.Document(panel,22,-20,1092,508)
 end
 local card=ns.AthenaSharePolicy.ProjectPublic(profile)
 f.document:SetBlocks({{kind='heading',text='Review a safe player card'}, {text=text(profile.identity.name or guid)..' · '..text(profile.identity.realm)},
  {text='Presets: Identity or observed career summary. The recipient must be exactly resolved and receive the same reviewed payload. Accept/reject and a final receipt are required.'},
  {kind='heading',text='Actual public-scope preview'}, {text=card and ns.ChronicleBackup.Encode(card) or 'No eligible public identity'},
  {kind='heading',text='Delivery held'}, {text='NATIVE-PENDING · no approved live profile transport. Direct Share offer/review/accept/receipt is implemented in the isolated multi-client fixture. No message has been sent.'},
  {kind='meta',text='Direct Share does not enable Aether or export private notes, exact movements, conversations or full named scoreboards.'}})
 return true,f
end
function U.Outreach(target,context,coordinator)
 if not R.Permit('intel') then return false end
 coordinator=coordinator or ns.RelayOutreach.Current
 local session,why=coordinator:Prepare(target,context,{userInitiated=true})
 local page=ns.Workspace.Destination('intel');if not page then return false end
 local p=base(page,'Review group contact','One selected player · no automatic reminders or unsolicited messages')
 local f=section(p,'outreach');f.coordinator=coordinator
 if not f.document then
  local panel=V.Panel(f,0,0,1136,440,'dark');f.document=V.Document(panel,22,-20,1092,396)
  f.send=V.Button(f,'Continue reviewed contact',0,-530,350,36,function()
   local s=f.coordinator.session;local ok,status=f.coordinator:Send(true,s and s.message)
   f.status:SetText(status or (ok and 'Mock contact sent; awaiting exact target reply.' or 'Contact unavailable.'))
  end)
  V.Button(f,'Cancel',370,-530,230,36,function() f.coordinator:Cancel();f.status:SetText('Cancelled. No unsent action can proceed.') end,'neutral')
  f.status=V.Text(f,'',16,-470,1090,14,V.blue);f.status:SetHeight(44)
 end
 f.send:SetEnabled(session~=nil);f.status:SetText(session and session.state or why)
 f.document:SetBlocks({{kind='heading',text=session and text(session.target.name)..' — '..text(session.target.realm) or 'Contact unavailable'},
  {text=session and session.message or tostring(why)}, {kind='heading',text='Route and evidence'}, {text=session and session.route or 'Identity / eligibility check required'},
  {kind='meta',text='Native Apply, Invite and whisper sending remain gated. Positive replies are not proof of joining; only a roster event confirms membership. Aether and a target addon are not required.'}})
 return true,f
end
function U.DirectReview(client,profile,recipient)
 if not R.Permit('relay') or not client or not recipient or not R.GUID(recipient.guid) or not R.Text(recipient.name) or not R.Text(recipient.realm) then return false end
 local page=ns.Workspace.Destination('relay');if not page then return false end
 local p=base(page,'Direct Share','One recipient · exact outgoing preview · explicit acceptance and receipt')
 local f=section(p,'directReview');f.client=client;f.profile=profile;f.recipient=R.Copy(recipient);f.scope='identity';f.offerID=nil;f.wire=nil
 if not f.document then
  local panel=V.Panel(f,0,0,1136,420,'dark');f.document=V.Document(panel,22,-20,1092,376)
  f.scopeChoice=V.Dropdown(f,0,-440,300,{{'identity','Identity'},{'career','Observed career'}},function() return f.scope end,function(value) f.scope=value;f.offerID=nil;f.wire=nil;f:Refresh() end)
  f.preview=V.Button(f,'Review exact offer',316,-440,280,34,function()
   local projection,why=ns.AthenaSharePolicy.ProjectDirect(f.profile,f.recipient.guid,f.scope)
   if projection then f.offerID,f.wire=f.client:PreviewDirect(f.recipient.guid,projection) end
   f:Refresh(f.offerID and 'Review the information and recipient, then choose Send.' or why or 'No eligible data')
  end,'neutral')
  f.send=V.Button(f,'Send reviewed offer',0,-530,300,36,function()
   local ok,why=f.client:SendDirect(f.offerID,f.wire,true)
   f:Refresh(not ok and tostring(why) or nil)
  end)
  V.Button(f,'Cancel offer',316,-530,240,36,function()
   local row=f.offerID and f.client.outbox[f.offerID]
   if row and row.state=='REVIEW' then f.client.outbox[f.offerID]=nil end
   f.offerID=nil;f.wire=nil;f:Refresh('Unsent offer cleared. Delivered messages cannot be recalled.')
  end,'neutral')
  f.status=V.Text(f,'',14,-487,1090,13,V.blue);f.status:SetHeight(32)
  function f:Refresh(statusMessage)
   local row=self.offerID and self.client.outbox[self.offerID];local transport=self.client.options.mockTransport~=nil
   self.send:SetEnabled(transport and row and row.state=='REVIEW' and true or false)
   local states={REVIEW='Offer prepared. Review the information and recipient before sending.',OFFERED='Waiting for the recipient to review this offer.',RECEIVED='Accepted and received. The recipient returned a final receipt.',DECLINED='The recipient declined. No profile data was transferred.'}
   self.status:SetText(statusMessage or row and states[row.state] or 'Choose a scope and review the addressed information.')
   self.document:SetBlocks({{kind='heading',text='To '..text(self.recipient.name)..' · '..text(self.recipient.realm)},
    {text='Subject: '..text(self.profile.identity and self.profile.identity.name or self.profile.personKey)..' · '..self.scope..'\n'..(transport and 'ISOLATED MOCK TRANSPORT · synthetic fixture, no game or Bridge messages' or 'NATIVE-PENDING · delivery disabled')},
    {kind='heading',text='Information in this offer'}, {text=shareText(row and row.packet.body.projection)},
    {kind='heading',text='Delivery state'}, {text=row and states[row.state] or 'No offer sent'},
    {kind='meta',text='Aether participation is unchanged. Private notes, conversations, precise routes and raw named scoreboards are excluded.'}})
  end
 end
 f:Refresh();return true,f
end
function U.DirectInbox(client,id)
 if not R.Permit('relay') then return false end
 local offer=client and client.inbox[id];if not offer or offer.kind~='OFFER' then return false end
 local page=ns.Workspace.Destination('relay');if not page then return false end
 local p=base(page,'Incoming Direct Share','Your decision applies only to this addressed offer')
 local f=section(p,'directInbox');f.client=client;f.id=id
 if not f.document then
  local panel=V.Panel(f,0,0,1136,470,'dark');f.document=V.Document(panel,22,-20,1092,426)
  f.accept=V.Button(f,'Accept reviewed data',0,-530,310,36,function() f.client:Decide(f.id,true,true);f:Refresh() end)
  f.decline=V.Button(f,'Decline',326,-530,240,36,function() f.client:Decide(f.id,false,true);f:Refresh() end,'neutral')
  function f:Refresh()
   local row=self.client.inbox[self.id];local clock=self.client.options.clock or R.Now;local active=row and not row.decision and row.expiresAt>clock()
   self.accept:SetEnabled(active and true or false);self.decline:SetEnabled(active and true or false)
   self.document:SetBlocks({{kind='heading',text=row and 'Offer from '..text(row.sender) or 'Offer expired'},
    {text='This isolated fixture exercises the same review, decision and receipt protocol. It cannot grant native proof or add facts to Chronicle.'},
    {kind='heading',text='Information offered to you'}, {text=shareText(row and row.body.projection)},
    {kind='heading',text='State'}, {text=row and (row.received and 'Received · final receipt returned' or row.decision or 'Waiting for your review') or 'Offer expired'}})
  end
 end
 f:Refresh();return true,f
end
function U.AppendProfile(st,row,blocks)
 local match=ns.Fellowship.GetPlayerMatch(row.id)
 blocks[#blocks+1]={kind='heading',text='Athena · local compatibility'}
 blocks[#blocks+1]={text=match and ((match.score and match.score..'% Player Match · ' or '')..match.state) or 'Player Match unknown'}
 blocks[#blocks+1]={kind='meta',text='Group Match concerns one advertised group. Aether stars are community opinions. No lookup or contact is triggered by this view.'}
end
