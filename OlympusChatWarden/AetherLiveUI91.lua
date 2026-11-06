-- Private developer-visible communications pane. No public chat or avatar gate.
local _,ns=...
local L,U,C=ns.AetherLive,ns.UI2,ns.UI2Components
function L.Open()
 if not ns.ClientBuild or ns.ClientBuild.releaseChannel~='private'and not(ns.WardenSimLab and ns.WardenSimLab.Enabled())then return false,'PRIVATE_DIAGNOSTICS_ONLY'end
 if not ns.Membership.Allowed()then U.ShowVerification();return false end
 U.Ensure();local f=L.panel
 if not f then
  f=C.Card(U.window,'Aether Live · developer transport diagnostics',false);L.panel=f
  f:SetSize(830,660);f:SetPoint('CENTER');f:SetFrameStrata('FULLSCREEN_DIALOG');f:SetFrameLevel(140);f:EnableMouse(true);ns.Theme.RegisterModal(f,U.window)
  local help=C.Text(f,'This pane exercises transport without entering the world. Use Enter Aether Live in the header for multiplayer. Relay keeps its own permissions. Current authority-issued credentials and verified native sessions are required. Native two-client qualification is still pending.',13,C.colors.muted)
  help:SetPoint('TOPLEFT',22,-48);help:SetSize(786,66);help:SetWordWrap(true)
  f.consent=ns.Art.Check(f,'I agree to advertise availability and exchange signed diagnostic packets this session.',22,-123,false,function(v)f.approved=v==true;if not f.approved then L.Runtime():Leave('Consent withdrawn')end end,780)
  local forever=ns.AetherCertificates.Namespace()=='forever'
  local label=C.Text(f,forever and'Known participant · first name and surname'or'Known participant · character name and realm',13);label:SetPoint('TOPLEFT',22,-159)
  f.peer=C.Edit(f,450,forever and'First name and surname'or'Character name and realm');f.peer:SetPoint('TOPLEFT',22,-183);f.peer:SetMaxLetters(180);f.peer.ChatWardenNoSpelling=true
  f.test=C.Edit(f,310,'TEST token · letters/digits/_/-');f.test:SetPoint('TOPLEFT',495,-183);f.test:SetMaxLetters(24);f.test.ChatWardenNoSpelling=true;f.test:SetText('FIRESIDE_1')
  local function action(fn)local ok,why=fn();f.status:SetText((ok and''or'Unavailable: ')..tostring(why or(ok and'Queued. Waiting for a signed application ACK.'or'Check the connection.')))end
  f.start=C.Button(f,'Start Live test',function()action(function()return L.Runtime():Start(f.approved==true)end)end,180);f.start:SetPoint('TOPLEFT',22,-231)
  f.connect=C.Button(f,'Connect known peer',function()action(function()return L.Runtime():Connect(f.peer:GetText())end)end,195);f.connect:SetPoint('TOPLEFT',211,-231)
  f.ping=C.Button(f,'PING',function()action(function()return L.Runtime():Ping(f.peer:GetText())end)end,100);f.ping:SetPoint('TOPLEFT',415,-231)
  f.sendTest=C.Button(f,'Send TEST',function()action(function()return L.Runtime():Test(f.peer:GetText(),f.test:GetText())end)end,130);f.sendTest:SetPoint('TOPLEFT',524,-231)
  f.leave=C.Button(f,'Leave Live',function()L.Runtime():Leave('Owner left');f.approved=false;f.consent:SetChecked(false);f.status:SetText('Live stopped. Relay and saved history are unchanged.')end,140);f.leave:SetPoint('TOPLEFT',663,-231)
  f.status=C.Text(f,'Stopped. Opening this pane sends nothing.',13,C.colors.blue);f.status:SetPoint('TOPLEFT',22,-276);f.status:SetSize(782,42);f.status:SetWordWrap(true)
  f.guild=ns.Art.Check(f,'Use same-guild discovery (turn off on all testers to isolate Relay topology).',22,-320,true,function(value)L.Runtime():SetGuildDiscovery(value==true)end,780)
  f.diagnostic=C.Text(f,'',13,C.colors.muted);f.diagnostic:SetPoint('TOPLEFT',22,-355);f.diagnostic:SetSize(782,196);f.diagnostic:SetWordWrap(true)
  f.copy=C.Button(f,'Copy diagnostics',function()
   local r=L.Runtime():Export();local lines={'FIRESIDE_AETHER_LIVE_1','Native tests: NOT TESTED. Shared avatars: gated.','Status: '..r.status..'; same-guild discovery: '..tostring(r.guildDiscovery),'API-enqueued: '..r.metrics.sent..'; ACKs: '..r.metrics.acked..'; retries: '..r.metrics.retries..'; bytes: '..r.metrics.bytes..'; drops: '..r.metrics.dropped}
   for _,p in ipairs(r.peers)do lines[#lines+1]=p.name..' | '..p.state..' | '..tostring(p.path)..' | '..tostring(p.enqueue)..' | RTT '..tostring(p.rttMS)..' ms | verified '..tostring(p.lastVerified)..' | TEST_ACK '..tostring(p.testACK)..' | '..tostring(p.detail)end
   ns.UI2Forms.Copy('Aether Live diagnostic evidence',table.concat(lines,'\n'),'Contains participant addresses and packet counts. No keys, certificate blobs, personal history or WoW locations.')
  end,210);f.copy:SetPoint('BOTTOMLEFT',22,22)
  C.Button(f,'Close pane',function()f:Hide()end,150):SetPoint('BOTTOMRIGHT',-22,22)
  f:HookScript('OnHide',function()f.peer:ClearFocus();f.test:ClearFocus()end)
  f:SetScript('OnUpdate',function(_,dt)
   f.elapsed=(f.elapsed or 0)+dt;if f.elapsed<.5 then return end;f.elapsed=0
   local s=L.Runtime();local lines={s.enabled and'Live communications test active · shared-world avatars remain gated.'or'Live is off · private remembered visitors remain local.',
    'Enqueued '..s.metrics.sent..' · application ACKs '..s.metrics.acked..' · retries '..s.metrics.retries..' · bytes '..s.metrics.bytes..' · queue '..#s.queue..'/32 · drops '..s.metrics.dropped}
   local n=0;for _,p in pairs(s.peers)do n=n+1;if n<=5 then lines[#lines+1]=p.name..' · '..p.status..(p.rttMS and(' · '..math.floor(p.rttMS)..' ms')or'')..'\n'..tostring(p.detail or p.path)end end
   if n==0 then lines[#lines+1]='No ACK-confirmed peers. Same-guild discovery is low-frequency; use Connect known peer for a deliberate WHISPER test.'end
   f.diagnostic:SetText(table.concat(lines,'\n'))
  end)
 end
 f:Show();return true
end
-- Keep the existing Join Aether header exclusively for Relay participation.
local old=U.OpenAetherTool
function U.OpenAetherTool(section)if section=='live-test'then L.Open();return true end;return old(section)end
if ns.ClientBuild and ns.ClientBuild.releaseChannel=='private'and U.aetherToolChoices then U.aetherToolChoices[#U.aetherToolChoices+1]={'live-test','Aether Live · private communications test'}end
