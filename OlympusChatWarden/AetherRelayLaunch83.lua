-- Launch readiness over the existing Relay adapter; no new store or protocol.
local _,ns=...;local R={VERSION=1};ns.AetherRelay=R
local N,A,C=ns.AetherNet,ns.AetherNative,ns.AetherCertificates
function R.Status()
 local c=N.Cached();local a=c and c.nativeController;local t=A.TransportCapabilities()
 local r={version=1,protocol=A.PROTOCOL,prefix=ns.RelayTransport.Aether.PREFIX,publicLiveEnabled=false,
  participation=N.Preference(),networkDenied=ns.Permissions.Denied('network'),nativeVerified=false,
  registered=a and a.registered==true or false,running=a and a.enabled==true or false,
  loggedAPI=t.loggedAvailable,ordinaryAPI=t.sendAvailable,registerAPI=t.registerAvailable,
  queued=a and type(a.queue)=='table'and #a.queue or 0,metrics=a and type(a.metrics)=='table'and ns.Athena.Copy(a.metrics)or{},
  recovery=c and c.RecoveryStatus and c:RecoveryStatus()or{state='NOT_STARTED'},
  lastStartupReason=R.lastStartupReason}
 if A.RelayPaused()then r.state='PAUSED_FOR_THIS_BUILD';r.detail=A.RelayPauseMessage
 elseif ns.MainStorageBlocked then r.state='DATA_PROTECTED';r.detail='Saved data needs recovery. Relay cannot start while protection is active.'
 elseif not r.participation then r.state='OPTED_OUT';r.detail='Relay is installed. Enable Participate in Aether Relay to consent to automatic community synchronization.'
 elseif r.networkDenied then r.state='PRIVACY_BLOCKED';r.detail='Network sharing is blocked by your privacy choice.'
 elseif r.recovery.state~='READY'and r.recovery.state~='NOT_STARTED'then r.state='LEDGER_RECOVERING';r.detail='Existing community records are being validated; originals remain protected.'
 elseif not t.available then r.state='TRANSPORT_UNAVAILABLE';r.detail='Required native API unavailable: '..t.reason
 elseif type(R.lastStartupReason or A.lastError)=='string'and(R.lastStartupReason or A.lastError):find('RECOVERY',1,true)then r.state='RELAY_RECOVERY_REQUIRED';r.detail='Relay saved records need review. They are kept unchanged; retrying does not replace them.'
 elseif not a or not r.running or not r.registered then r.state='START_REQUIRED';r.detail='Saved participation is on. Resume Relay or wait for startup validation.'
 else
  local cert,why=C.LocalCertificate(c);r.enrolled=cert~=nil;r.enrollmentReason=why
  local peers=0;for _,p in pairs(a.peers or{})do if p.ready and p.expires>(ns.SafeCall(GetServerTime)or 0)then peers=peers+1 end end;r.acknowledgedPeers=peers
  if not cert then r.state='ENROLLMENT_REQUIRED';r.detail='Joined Aether. Enrollment continues automatically when a trusted verifier can confirm your character. Your new records remain pending; eligible signed records can still be received and forwarded.'
  elseif peers>0 then r.state='PEER_ACKNOWLEDGED';r.detail='A peer session is acknowledged. Individual record delivery and wider reach require separate evidence.'
  else r.state='SEEKING_PEERS';r.detail='Relay adapter is running with a character certificate. No acknowledged peer is currently available.'end
 end
 return r
end
function R.Text()
 local s=R.Status();local lines={'Aether Relay · '..s.state,s.detail}
 for _,key in ipairs({'protocol','prefix','participation','networkDenied','running','registered','loggedAPI','ordinaryAPI','registerAPI','enrolled','enrollmentReason','acknowledgedPeers','queued','lastStartupReason'})do lines[#lines+1]=key..': '..tostring(s[key]==nil and'UNAVAILABLE'or s[key])end
 lines[#lines+1]='Native delivery: UNVERIFIED. API acceptance and cached records do not prove receiving-client delivery.'
 lines[#lines+1]='Aether Live gameplay: disabled. Readiness inspection changes no consent, history, keys or records.'
 return table.concat(lines,'\n')
end
function R.Resume()
 if A.RelayPaused()then return false,A.RelayPauseMessage end
 if not N.Preference()then return false,'Enable Participate in Aether Relay explicitly first.'end
 if ns.Permissions.Denied('network')or ns.MainStorageBlocked or ns.Initializing then return false,'Privacy, recovery or startup validation is blocking Relay.'end
 local c,why=A.EnsureLocal();R.lastStartupReason=why or(c and'Adapter resume requested'or'Adapter unavailable')
 return c~=nil,why or R.Status().detail
end
-- Retry only a previously consented adapter after normal login/world entry.
-- Bounded backoff handles late identity/APIs; no polling of historical data.
local f=CreateFrame('Frame');R.frame=f;local retryAt={2,10,30,90}
local function stop()f:SetScript('OnUpdate',nil);f.elapsed=0;f.attempt=0 end
local function schedule()
 stop();if A.RelayPaused()or not N.Preference()or ns.Permissions.Denied('network')or ns.MainStorageBlocked then return end
 local a=N.Current and N.Current.nativeController;if a and a.enabled and a.registered then return end
 f:SetScript('OnUpdate',function(_,dt)
  if ns.MainStorageBlocked then stop();return end
  f.elapsed=f.elapsed+(dt or 0);local at=retryAt[(f.attempt or 0)+1]
  if not at or f.elapsed<at then return end
  if not N.Preference()or ns.Permissions.Denied('network')then stop();return end
  f.attempt=(f.attempt or 0)+1;local ok,why=pcall(R.Resume);if not ok then R.lastStartupReason='Adapter startup failed; saved state retained.'end
  local a=N.Current and N.Current.nativeController;if a and a.enabled and a.registered or f.attempt>=4 then stop()end
 end)
end
for _,kind in ipairs({'PLAYER_LOGIN','PLAYER_ENTERING_WORLD','PLAYER_LOGOUT'})do pcall(f.RegisterEvent,f,kind)end
f:SetScript('OnEvent',function(_,kind)if kind=='PLAYER_LOGOUT'then stop()else schedule()end end)
