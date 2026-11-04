-- Developer-fixed field policy. Never serialize a profile/dossier transitively.
local _,ns=...
local R=ns.Athena2
local P={VERSION=4,CONSENT=4,MAX_BYTES=20000};ns.AthenaSharePolicy=P;ns.AthenaExchangeProjector=P
P.Disclosure='Aether is OFF by default. Only explicitly consented, authenticated current public projections may synchronize. Local historical gear, talents and observations never automatically federate. Public identity, coarse level/guild freshness, supported observed statistics, community stars and your optional self-selected Gamerzone may be exchanged. No private chat, notes, watch tiers, precise locations, contact graphs or raw scoreboards. No per-profile exclusions. Reachability is limited; sender identities are visible to transport peers. Remote copies cannot be guaranteed deleted. Leaving stops new queries, replies and votes immediately. Schema expansion requires renewed consent. This build has no verified live Aether transport. Olympus Bridge is only optional official guild integration.'
P.Disclosure=P.Disclosure..' Earlier versions cover per-match public observations, explicitly authored About Me, public guild observations, 1–10 guild opinions and verified-owner Guildzone. This checkpoint implements those categories only in isolated simulation; live service and owner proof remain blocked.'
P.Disclosure=P.Disclosure..' Aether Net schema 5 requires a new explicit opt-in: latest locally captured equipment IDs and talent choices/export may be shared with observation age and provenance. Older captures and recipient-imported builds never join this projection. Public member Wall blocks are scoped to Wall writing; votes and Shield are independent.'
P.Disclosure=P.Disclosure..' Consent 6 adds a community Wall on every resolved character, whether or not that subject participates or has an owner claim. Only authenticated, consenting authors may publish. Ownership grants biography and owner moderation rights, not creation of the Wall. Earlier consent does not enroll this version. Private drafts remain unsent until a separate deliberate review; reconnect never publishes them automatically. Legacy signed Wall policies remain enforced for legacy records.'
P.Disclosure=P.Disclosure..' Aether Net consent 7 additionally covers explicitly authorized shared event facts, event discussion and attributable participant feedback, plus permitted self-declared activity. A Fireside contributor principal is independent of Olympus membership. Third-party participant identifiers require separate publication authority; no named live party roster, private chat, notes, watch state or raw history is automatically shared. Native key provisioning, sender/character binding and delivery remain unverified. Prior consent 6 cannot enroll this scope.'
local identityKeys={schema=true,kind=true,personKey=true,name=true,realm=true,class=true,race=true,faction=true,levelBand=true,guild=true,guildDate=true,sourceClass=true,freshness=true,pvp=true,pve=true,rating=true}
local eventKeys={schema=true,kind=true,eventKey=true,activityType=true,mapID=true,mapName=true,dateBucket=true,outcome=true,coverage=true,sourceClass=true,matching=true}
local pvpKeys={scope=true,matchCount=true,killingBlows=true,honorableKills=true,deaths=true,damageDone=true,healingDone=true,honorGained=true,coverage=true}
local pveKeys={status=true,clears=true}
local ratingKeys={average=true,count=true,scope=true,identityGuarantee=true}
local declarationKeys={gamerzone=true,revision=true,declaredBy=true,cleared=true}
local function exact(t,keys)
 if type(t)~='table' or getmetatable(t) then return false end
 for k in pairs(t) do if not keys[k] then return false end end;return true
end
function P.Validate(card)
 local clean=R.Copy(card,1000);if not clean then return nil,'UNSAFE_DATA' end
 local player=clean.schema=='PUBLIC_PLAYER_CARD_V2' or clean.schema=='PUBLIC_SELF_CARD_V2' or clean.schema=='PUBLIC_PLAYER_CARD_V3' or clean.schema=='PUBLIC_SELF_CARD_V3'
 if player then
  local keys=identityKeys
  if clean.schema=='PUBLIC_PLAYER_CARD_V3' or clean.schema=='PUBLIC_SELF_CARD_V3' then keys={};for k,v in pairs(identityKeys) do keys[k]=v end;keys.declaration=true end
  if not exact(clean,keys) or clean.kind~='player' or not R.GUID(clean.personKey) or not R.Text(clean.name) or not R.Text(clean.realm) then return nil,'INVALID_PLAYER_CARD' end
  if clean.declaration then
   local d=clean.declaration
   if clean.schema~='PUBLIC_SELF_CARD_V3' or not exact(d,declarationKeys) or not (d.cleared==true and d.gamerzone==nil or d.cleared==nil and ns.PlayerCard.Valid(d.gamerzone))
    or d.declaredBy~=clean.personKey or not R.Number(d.revision,1,1000000000) or d.revision%1~=0 then return nil,'OWNER_DECLARATION' end
  end
  if not ({self_record=true,local_observation=true,synthetic_fixture=WARDEN_SIMULATOR_ISOLATED==true})[clean.sourceClass] then return nil,'SOURCE_CLASS' end
  for _,k in ipairs({'class','race','faction','levelBand','guild','guildDate','sourceClass','freshness'}) do if clean[k]~=nil and not R.Text(clean[k]) then return nil,'IDENTITY_FIELD' end end
  if clean.pvp then
   if not exact(clean.pvp,pvpKeys) or clean.pvp.scope~='Observed in Fireside-recorded matches' then return nil,'PVP_SCOPE' end
   for k,v in pairs(clean.pvp) do if k~='scope' and k~='coverage' and not R.Number(v,0,1000000000000) then return nil,'PVP_NUMBER' end end
  end
  if clean.pve and (not exact(clean.pve,pveKeys) or clean.pve.status~='unknown' or type(clean.pve.clears)~='table' or next(clean.pve.clears)) then return nil,'UNSUPPORTED_CLEAR' end
  if clean.rating then
   local r=clean.rating;if not exact(r,ratingKeys) or not R.Number(r.count,0,1024) or r.count%1~=0 or r.average~=nil and not R.Number(r.average,1,5) or r.count==0 and r.average~=nil then return nil,'RATING' end
   if r.scope~='Reachable network opinions' or not R.Text(r.identityGuarantee,256) then return nil,'RATING_SCOPE' end
  end
 elseif clean.schema=='PUBLIC_EVENT_CARD_V1' then
  if not exact(clean,eventKeys) or clean.kind~='event' or not R.Text(clean.eventKey,128) or not R.Text(clean.activityType) or not R.Text(clean.dateBucket,16) or clean.outcome~='unknown' then return nil,'INVALID_EVENT_CARD' end
  if clean.mapID~=nil and not R.Number(clean.mapID,0,1000000000) then return nil,'MAP' end
  for _,k in ipairs({'mapName','coverage','sourceClass','matching'}) do if clean[k]~=nil and not R.Text(clean[k],256) then return nil,'EVENT_FIELD' end end
  if clean.sourceClass~='local_observation' and not (clean.sourceClass=='synthetic_fixture' and WARDEN_SIMULATOR_ISOLATED==true) then return nil,'SOURCE_CLASS' end
 else return nil,'SCHEMA_UNSUPPORTED' end
 local ok,wire=pcall(ns.ChronicleBackup.Encode,clean);if not ok or #wire>P.MAX_BYTES then return nil,'TOO_LARGE' end
 return clean,wire
end
local function bucket(at) return type(at)=='number' and tostring(math.floor(at/86400)) or 'unknown' end
function P.ProjectPublic(profile,stats,rating,now)
 local mock=type(profile)=='table' and profile.sourceOrigin=='synthetic_fixture' and WARDEN_SIMULATOR_ISOLATED==true
 if type(profile)~='table' or profile.sourceOrigin~='native_local' and not mock then return nil,'NO_ELIGIBLE_PUBLIC_DATA' end
 now=now or R.Now()
 if profile.kind=='player' then
  local f=profile.identity or {};local dates=profile.freshness or {}
  if not R.GUID(profile.personKey) or not R.Text(f.name) or not R.Text(f.realm) then return nil,'NO_ELIGIBLE_PUBLIC_DATA' end
  local out={schema=profile.self and 'PUBLIC_SELF_CARD_V3' or 'PUBLIC_PLAYER_CARD_V3',kind='player',personKey=profile.personKey,name=f.name,realm=f.realm,sourceClass=profile.self and 'self_record' or 'local_observation',freshness='dated',pve={status='unknown',clears={}}}
  -- Owner declarations are Aether Net records; unpublished local drafts are never projected here.
  if mock then out.sourceClass='synthetic_fixture' end
  for _,k in ipairs({'class','race','faction'}) do out[k]=R.Text(f[k]) end
  if R.Number(f.level,1,1000) and dates.level and now-dates.level<=7*86400 then local lo=math.floor((f.level-1)/10)*10+1;out.levelBand=lo..'-'..(lo+9) end
  if R.Text(f.guild) and dates.guild and now-dates.guild<=7*86400 then out.guild=f.guild;out.guildDate=bucket(dates.guild) end
  if stats and stats.scope=='Observed in Fireside-recorded matches' and stats.matchCount>0 then
   out.pvp={scope=stats.scope,matchCount=stats.matchCount,coverage='Partial observed matches; not lifetime totals'}
   for _,k in ipairs({'killingBlows','honorableKills','deaths','damageDone','healingDone','honorGained'}) do out.pvp[k]=R.Number(stats.counters and stats.counters[k]) end
  end
  if rating then out.rating={average=rating.average,count=rating.count,scope='Reachable network opinions',identityGuarantee=rating.identityGuarantee} end
  return P.Validate(out)
 elseif profile.kind=='event' then
  local digest=ns.PackCrypto.Hex(ns.PackCrypto.SHA256(profile.ownerKey..'/'..profile.eventKey))
  return P.Validate({schema='PUBLIC_EVENT_CARD_V1',kind='event',eventKey=digest:sub(1,32),activityType=profile.activityType,mapID=profile.mapID,mapName=profile.mapName,dateBucket=bucket(profile.firstAt),outcome='unknown',coverage='Partial local observations',sourceClass=mock and 'synthetic_fixture' or 'local_observation',matching='Local opaque key; cross-client identity unverified'})
 end
 return nil,'NO_ELIGIBLE_PUBLIC_DATA'
end
function P.ProjectDirect(profile,recipient,preset,stats)
 if type(profile)=='table' and profile.kind=='historical' and preset=='historical' then
  local data={schema='DIRECT_HISTORICAL_V1',recipient=recipient,scope='historical',snapshot=profile.snapshot}
  local clean,why=P.ValidateDirect(data,recipient);if not clean then return nil,why or 'Selected snapshot is invalid.' end
  return clean,ns.ChronicleBackup.Encode(clean)
 end
 if not R.GUID(recipient) or not ({identity=true,career=true,event=true})[preset] then return nil,'INVALID_DIRECT_SCOPE' end
 local card,why=P.ProjectPublic(profile,preset=='career' and stats or nil)
 if not card then return nil,why end
 if preset=='identity' and card.kind~='player' or preset=='event' and card.kind~='event' then return nil,'SCOPE_MISMATCH' end
 local out={schema='DIRECT_SHARE_V1',recipient=recipient,scope=preset,card=card};return out,ns.ChronicleBackup.Encode(out)
end
function P.ValidateDirect(data,recipient)
 if type(data)=='table' and data.schema=='DIRECT_HISTORICAL_V1' then
  if not exact(data,{schema=true,recipient=true,scope=true,snapshot=true}) or not R.GUID(recipient) or data.recipient~=recipient or data.scope~='historical' then return nil,'HISTORICAL_SCOPE' end
  local snapshot,why=P.ValidateHistorical(data.snapshot);if not snapshot then return nil,why end
  local out={schema=data.schema,recipient=recipient,scope='historical',snapshot=snapshot}
  local ok,wire=pcall(ns.ChronicleBackup.Encode,out);if not ok or #wire>18000 then return nil,'This selected capture exceeds the addressed payload limit. No fields were truncated or sent.' end
  return out
 end
 if not exact(data,{schema=true,recipient=true,scope=true,card=true}) or data.schema~='DIRECT_SHARE_V1' or data.recipient~=recipient or not ({identity=true,career=true,event=true})[data.scope] then return nil end
 local card=P.Validate(data.card);if not card then return nil end
 if data.scope=='event' and card.kind~='event' or data.scope~='event' and card.kind~='player' then return nil end
 return {schema=data.schema,recipient=recipient,scope=data.scope,card=card}
end

-- Deliberately separate from PUBLIC_* validators. One selected capture and its
-- exact geometry dependencies; never a profile, archive or editable dossier.
function P.ValidateHistorical(value)
 local s=R.Copy(value,4000)
 if not s or not exact(s,{guid=true,realm=true,observerOwner=true,observedAt=true,source=true,family=true,contentID=true,eventID=true,captureWire=true,dependencies=true})
  or not R.GUID(s.guid) or not R.Text(s.realm,128) or not R.Text(s.observerOwner,256)
  or not R.GUID(s.observerOwner:match('/(Player%-.+)$')) or not R.Number(s.observedAt,0,4102444800)
  or not R.Text(s.source,128) or not R.Text(s.eventID,256) or not ({gear=true,traits=true})[s.family]
  or type(s.contentID)~='string' or #s.contentID~=64 or s.contentID:find('[^a-f0-9]')
  or not R.Text(s.captureWire,16000) or not ns.ChronicleStore.Array(s.dependencies,8) then return nil,'HISTORICAL_FIELDS' end
 local function payload(wire,hash)
  local list=ns.ChronicleBackup.DecodeChunk(wire)
  if not list or #list~=1 then return end
  local cap=ns.ChronicleCapture.Validate(list[1]);if not cap or ns.ChronicleCapture.Hash(cap)~=hash then return end
  return cap
 end
 local cap=payload(s.captureWire,s.contentID)
 if not cap or cap.family~=s.family or cap.values.guid~=s.guid then return nil,'HISTORICAL_IDENTITY_OR_HASH' end
 local objects,seen={},{}
 for _,dep in ipairs(s.dependencies) do
  if not exact(dep,{contentID=true,captureWire=true}) or type(dep.contentID)~='string' or #dep.contentID~=64 or seen[dep.contentID] or not R.Text(dep.captureWire,16000) then return nil,'HISTORICAL_DEPENDENCY' end
  local d=payload(dep.captureWire,dep.contentID)
  if not d or d.family~='traits' or not d.values.layoutTree then return nil,'HISTORICAL_LAYOUT' end
  objects[dep.contentID]={capture=d};seen[dep.contentID]=true
 end
 local expected=0;for _,hash in ipairs(cap.values.layoutRefs or {}) do if not seen[hash] then return nil,'HISTORICAL_MISSING_LAYOUT' end;expected=expected+1 end
 if expected~=#s.dependencies then return nil,'HISTORICAL_EXTRA_DATA' end
 if expected>0 and not ns.WardenTalents.Projection(cap.values,objects) then return nil,'HISTORICAL_PARTIAL_LAYOUT' end
 return s
end
function P.HistoricalSnapshot(owner,guid,realm,row,objects)
 if not row or not row.object or not row.object.capture or row.object.capture.values.guid~=guid then return nil,'Choose a recorded capture for this exact character.' end
 local event=row.event or row.object;local deps={};local cap=row.object.capture
 for _,hash in ipairs(cap.values.layoutRefs or {}) do
  local object=objects and objects[hash];if not object then return nil,'Recorded layout dependency is unavailable.' end
  deps[#deps+1]={contentID=hash,captureWire=ns.ChronicleBackup.Encode({object.capture})}
 end
 return P.ValidateHistorical({guid=guid,realm=realm,observerOwner=owner,observedAt=row.at,source=event.source,family=cap.family,contentID=row.hash,eventID=event.id,captureWire=ns.ChronicleBackup.Encode({cap}),dependencies=deps})
end
