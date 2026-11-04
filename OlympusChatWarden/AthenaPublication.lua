-- Explicit, source-derived authoring through the existing signed Net ledger.
-- No passive upload, guessed run token, automatic roster or native trust shim.
local _,ns=...
local P={VERSION=1,reviews=setmetatable({},{__mode='k'})};ns.AthenaPublication=P
local function active() return ns.AetherNet.PublicationClient() end
local function firsthand(st,a,client)
 if not st.events[a.anchor] or #(a.evidence or {})>4096 then return false end
 for _,id in ipairs(a.evidence or {}) do
  local e=st.events[id];local origin=e and e.details and e.details.origin
  if not e or e.character~=st.owner or e.restored or origin=='imported' or origin=='aether' or origin=='direct_share' or origin=='replay'
   or origin=='synthetic' and client and client.options.fixture~=true then return false end
 end
 return true
end
function P.Event(owner,id)
 if not ns.Permissions.Decide('UIAccess') or owner~=ns.Chronicle.Owner() then return nil,'VERIFIED_LOCAL_OWNER_REQUIRED' end
 local st,why=ns.ChronicleActivities.Request(owner);if not st then return nil,why end
 local a=ns.ChronicleActivities.View(st,id);if not a then return nil,'LOCAL_RUN_UNAVAILABLE' end
 local ref=ns.AthenaHistoryGraph.LocalEvent(st,a)
 if not ref or not ({dungeon=true,raid=true,battleground=true,arena=true,duel=true,boss=true,guild=true,world=true})[a.kind] then return nil,'SUPPORTED_LOCAL_EVENT_REQUIRED' end
 local client=active();if not firsthand(st,a,client) then return nil,'FIRSTHAND_LOCAL_EVENT_REQUIRED' end
 local proof=client and client.options.resolveEvent and client.options.resolveEvent(st,a)
 local place=a.place or a.location or {};local name=ns.UI2Models.Title(a)
 local data={version=1,name=name,realm=proof and proof.realm or ns.SafeCall(GetRealmName),activityType=a.kind,
  runToken=proof and proof.runToken,instanceID=place.instanceID,difficulty=place.difficultyID,startAt=a.startAt or a.firstAt,
  endAt=a.endAt or a.lastAt,outcome='partial',participants={},sourceRef=ref.key}
 -- A source-qualified final victory is deliberately weaker than full clear.
 if a.finalEncounterWon==true then data.outcome='final_encounter_won' end
 local review={owner=owner,activity=id,sourceRef=ref.key,sourceAnchor=a.anchor,key=proof and proof.key,data=data,client=client,
  sourceCharacter=ns.ChronicleStore.Character(owner,false),sourceRevision=st.revision or st.processed,
  state=proof and 'REVIEW' or 'LOCAL_ONLY',reason=not proof and 'Common run identity and independent signer are not available. Nothing can be published.' or nil}
 P.reviews[review]=ns.Athena.Copy(data);return review
end
function P.Publish(review,explicit)
 if not P.reviews[review] or explicit~=true or not ns.Permissions.Decide('UIAccess') or review.owner~=ns.Chronicle.Owner() then return false,'EXPLICIT_CURRENT_REVIEW_REQUIRED' end
 if ns.ChronicleBackup.Encode(review.data)~=ns.ChronicleBackup.Encode(P.reviews[review]) then return false,'REVIEW_FIELDS_CHANGED' end
 local c=active();if not c or c~=review.client or not review.key or not review.data.runToken then return false,'INDEPENDENT_EVENT_PROOF_UNAVAILABLE' end
 if review.sourceCharacter~=ns.ChronicleStore.Character(review.owner,false) then return false,'SOURCE_CONTEXT_CHANGED' end
 local st=ns.ChronicleActivities.Peek(review.owner);local a=st and ns.ChronicleActivities.View(st,review.activity)
 if not a or a.anchor~=review.sourceAnchor or not firsthand(st,a,c) then return false,'SOURCE_CONTEXT_CHANGED' end
 local proof=c.options.resolveEvent and c.options.resolveEvent(st,a)
 if not proof or proof.key~=review.key or proof.runToken~=review.data.runToken then return false,'RUN_PROOF_CHANGED' end
 -- Empty participants is an explicit privacy scope, not a wildcard grant.
 local rows=c:View('EVENT',review.key);local revision=1
 for _,row in pairs(c.records) do local r=row.record;if r.kind=='EVENT_FACT' and r.origin==c.principal and r.subjectKey==review.key and r.slot==review.sourceRef then revision=math.max(revision,r.revision+1) end end
 local pair,why=c:Publish('EVENT',review.key,'EVENT_FACT',review.sourceRef,ns.Athena.Copy(review.data),revision,false,true)
 if not pair then return false,why end
 P.reviews[review]=nil;ns.UI2Models.Clear();return true,'Reviewed event published to the authorized Aether ledger. No participants or private history were included.'
end
function P.ReviewEvent(owner,id)
 local review,why=P.Event(owner,id);if not review then return false,why end
 local d=review.data
 return ns.UI2Forms.Form({title='Review event publication',help='Only the exact fields below may be sent. Participants, chat, loot recipients, private notes and raw history are excluded. No automatic publishing or retry.',
  paragraphs={'Event: '..d.name,'Activity: '..d.activityType,'From '..tostring(d.startAt)..' to '..tostring(d.endAt),'Outcome: '..d.outcome,'Participants shared: none',review.reason or ('Common event: '..review.key)},
  submitLabel='Publish reviewed event',submit=review.state=='REVIEW' and function() return P.Publish(review,true) end or nil})
end
function P.Presence()
 if not ns.Permissions.Decide('HistoryCollect') or not ns.Chronicle.InWorld() then return nil,'SELF_RECORDING_CONTEXT_REQUIRED' end
 local now=ns.SafeNumber(ns.SafeCall(GetServerTime));if not now then return nil,'SERVER_CLOCK_UNAVAILABLE' end
 local inside,kind;if type(IsInInstance)=='function' then local ok,x,y=pcall(IsInInstance);if ok and ns.Readable(x) and ns.Readable(y) then inside,kind=x,y end end;local activity=ns.Checked(inside) and ({party='dungeon',raid='raid',pvp='battleground',arena='arena'})[kind] or 'idle'
 -- Coarse activity only: deliberately no precise subzone, coordinates or party.
 local evidence=ns.Checked(inside) and 'instance_observed' or 'owner_declaration'
 if not ns.Checked(inside) and P.craft and P.craft.owner==ns.Chronicle.Owner() and now>=P.craft.at and now-P.craft.at<=30 then activity='crafting';evidence='successful_craft' end
 return {version=1,activity=activity or 'idle',place='',observedAt=now,validUntil=now+90,evidence=evidence}
end
function P.PublishPresence(review,explicit)
 local c=active();local own=ns.PlayerCard.Own()
 if explicit~=true or not c or not ns.Permissions.Decide('UIAccess') or not c.options.owns(c.principal,'CHARACTER',own) then return false,'INDEPENDENT_OWNER_PROOF_REQUIRED' end
 local latest,why=P.Presence();if not latest then return false,why end
 if type(review)~='table' or latest.activity~=review.activity or latest.observedAt-review.observedAt>30 or latest.observedAt<review.observedAt then return false,'PRESENCE_REVIEW_EXPIRED' end
 local revision=1;for _,row in pairs(c.records) do local r=row.record;if r.kind=='PRESENCE' and r.origin==c.principal and r.subjectKey==own then revision=math.max(revision,r.revision+1) end end
 local pair,reason=c:Publish('CHARACTER',own,'PRESENCE','presence',latest,revision,false,true)
 return pair~=nil,pair and 'Activity committed locally for at most 90 seconds; eligible for peer sync. No roster or precise location included.' or reason
end
function P.ReviewPresence()
 local review,why=P.Presence();if not review then return false,why end
 return ns.UI2Forms.Form({title='Share my activity for 90 seconds',help='Explicit self-declaration only. No automatic renewal, party members or precise location. Your local identity and recording scope are validated. This commits locally; available authorized peers may synchronize it.',
  paragraphs={'Activity: '..review.activity,'Expiry: '..tostring(review.validUntil),'Shared participants: none'},submitLabel='Share this activity',submit=function() return P.PublishPresence(review,true) end})
end

local nativeNotice=ns.Athena.NativeNotice
ns.Athena.NativeNotice=function(e,...)
 if nativeNotice then nativeNotice(e,...) end
 local d=e.details or {};if ns.Permissions.Decide('HistoryCollect') and e.character==ns.Chronicle.Owner() and e.source=='TRADE_SKILL_ITEM_CRAFTED_RESULT' and d.recordType=='native_craft_result' and ns.ChronicleStore.Integer(d.itemID,1) and ns.ChronicleStore.Integer(d.quantity,1) then P.craft={owner=e.character,at=e.at,source=e.id} end
end
