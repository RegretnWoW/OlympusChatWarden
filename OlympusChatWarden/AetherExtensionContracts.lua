-- Host-owned, data-only wire contracts. Received data never registers code.
local _,ns=...
local K={VERSION=1};ns.AetherExtensionContracts=K
function K.Plain(v)return type(v)=='table'and getmetatable(v)==nil and ns.Readable(v)end
function K.Keys(v,keys)
 if not K.Plain(v)then return false end
 for k in pairs(v)do if not keys[k]then return false end end;return true
end
function K.Set(s)local out={};for k in s:gmatch('%S+')do out[k]=true end;return out end
function K.ID(s,n)return type(s)=='string'and #s>=3 and #s<=(n or 64)and s:match('^[a-z0-9][a-z0-9_.%-]+$')~=nil end
function K.Token(s,n)return type(s)=='string'and #s>0 and #s<=(n or 96)and s:match('^[%w_:/%.%-]+$')~=nil end
function K.Int(v,a,b)return type(v)=='number'and v==v and v%1==0 and v>=a and v<=b end
function K.Text(v,n)return ns.AetherNet.Text(v,n)end
function K.Array(v,n)
 if not K.Plain(v)then return false end;local count=0
 for k in pairs(v)do if not K.Int(k,1,n)then return false end;count=count+1 end
 for i=1,count do if v[i]==nil then return false end end;return true
end
K.cardFields=K.Set('version extension cardID schemaVersion title text icon score activityType available invitations')
K.envelopeFields=K.Set('version extension activityID rulesVersion envelopeID kind sessionID actorGUID targetGUID sequence prior issuedAt expiresAt body')
K.bodyFields=K.Set('authority holder nextHolder ruleset stateHash action proofRef proofClass award receipt replyTo participants')
K.icons={torch='IconAether',book='IconJournal',banner='IconHall',star='IconDossiers',shield='IconShield'}
K.kinds=K.Set('INVITE ACCEPT DECLINE CANCEL SESSION TURN RESULT RECEIPT')
function K.Card(d,removed)
 if not K.Keys(d,K.cardFields)then return false,'CARD_FIELDS'end
 if removed then return next(d)==nil,'CARD_TOMBSTONE'end
 if d.version~=1 or d.schemaVersion~=1 or not K.ID(d.extension)or not K.ID(d.cardID,24)or not K.Text(d.title,48)or #d.title==0 or not K.Text(d.text,320)or not K.icons[d.icon]
  or d.score~=nil and not K.Int(d.score,-1000000,1000000)or d.activityType~=nil and not K.ID(d.activityType)
  or d.available~=nil and type(d.available)~='boolean'or d.invitations~=nil and type(d.invitations)~='boolean'then return false,'CARD_SCHEMA'end
 return true
end
function K.Envelope(d,at,archived)
 if not K.Keys(d,K.envelopeFields)or d.version~=1 or not K.ID(d.extension)or not K.ID(d.activityID)or not K.Int(d.rulesVersion,1,1000)
  or not K.Token(d.envelopeID,64)or not K.kinds[d.kind]or not K.Token(d.sessionID,64)
  or not ns.ChronicleStore.GUID(d.actorGUID)or not ns.ChronicleStore.GUID(d.targetGUID)
  or not K.Int(d.sequence,0,1000000)or not K.Token(d.prior,96)or not K.Int(d.issuedAt,1,at+5)
  or not K.Int(d.expiresAt,d.issuedAt+1,d.issuedAt+604800)or not archived and d.expiresAt<=at
  or not K.Keys(d.body,K.bodyFields)then return false,'ENVELOPE_SCHEMA'end
 local b=d.body
 for _,key in ipairs({'authority','holder','nextHolder'})do if b[key]~=nil and not ns.ChronicleStore.GUID(b[key])then return false,'ENVELOPE_IDENTITY'end end
 for _,key in ipairs({'ruleset','stateHash','action','proofRef','award','receipt','replyTo'})do if b[key]~=nil and not K.Token(b[key],96)then return false,'ENVELOPE_BODY'end end
 if b.proofClass~=nil and not({LOCAL_CLIENT_OBSERVED=true,PEER_CORROBORATED=true,UNKNOWN=true})[b.proofClass]then return false,'PROOF_CLASS'end
 if b.participants~=nil then
  if not K.Array(b.participants,8)then return false,'PARTICIPANTS'end
  local seen={};for _,g in ipairs(b.participants)do if not ns.ChronicleStore.GUID(g)or seen[g]then return false,'PARTICIPANTS'end;seen[g]=true end
 end
 return true
end
