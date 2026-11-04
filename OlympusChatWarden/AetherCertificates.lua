-- One authority chain and character credentials over the existing Aether ledger.
-- The authority signing key NEVER enters WoW. Only public roots are pinned here.
local _,ns=...
local X,P,B=ns.AetherCrypto,ns.PackCrypto,ns.ChronicleBackup
local C={VERSION=1,AUTHORITY='OlympusWardenAuthority',LABEL='Olympus Warden Authority',MAX_PROOF=4096,MAX_LIFE=2592000};ns.AetherCertificates=C
local function now()return math.floor(ns.SafeNumber(ns.SafeCall(GetServerTime))or 0)end
local function hash(s)return P.Hex(P.SHA256(s))end
local function plain(t)return ns.Readable(t)and type(t)=='table'and not getmetatable(t)end
local function hex(s,n)return type(s)=='string'and #s==n and not s:find('[^a-f0-9]')end
local function integer(s)local n=tonumber(s);return n and n%1==0 and n>=0 and tostring(n)==s and n or nil end
local function text(s,n)return type(s)=='string'and #s>0 and #s<=n and not s:find('[|%c]')end
local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
function C.Namespace()return ns.ClientBuild and ns.ClientBuild.target=='retail-test'and'retail-test'or'forever'end
function C.Encode(s)return(P.Base64Encode(s):gsub('%+','-'):gsub('/','_'):gsub('=',''))end
function C.Decode(s,limit)
 if type(s)~='string'or #s>(limit or 12000)or s:find('[^%w_%-]')or #s%4==1 then return end
 local raw=P.Base64Decode((s:gsub('%-','+'):gsub('_','/'))..string.rep('=',(4-#s%4)%4),limit or 12000)
 if raw and C.Encode(raw)==s then return raw end
end
function C.Principal(name,realm)
 if not text(name,96)or not text(realm,96)then return end
 return 'Native/'..hash(name:lower()..'-'..realm:gsub('%s',''):lower()):sub(1,40)
end
local function fields(wire,n)
 if type(wire)~='string'or #wire>4096 then return end
 local out={};for line in (wire..'\n'):gmatch('(.-)\n')do if line:find('[\r|%z]')then return end;out[#out+1]=line end
 if #out~=n then return end;return out
end
local authorityCache={}
function C.Authority(key,chain,depth)
 if not hex(key,64)then return end
 local roots=ns.AetherIssuerKeys and ns.AetherIssuerKeys.roots or{}
 local root=roots[key];if root and hex(root.public,64)and hash(root.public)==key then return root end
 depth=depth or 0;if depth>=3 or type(chain)~='string'or #chain>5000 then return end
 local body,sig=chain:match('^I1:([%w_%-]+):([a-f0-9]+)$');local wire=body and C.Decode(body,4096);local f=fields(wire,8)
 if not f or f[1]~='WAI1'or f[2]~=C.AUTHORITY or f[4]~=key or hash(f[5])~=key or not hex(f[5],64)or not hex(sig,128)then return end
 local parent=C.Authority(f[3],f[8],depth+1);local epoch,at=integer(f[6]),integer(f[7])
 if not parent or not epoch or epoch~=parent.epoch+1 or not at or at>now()+5 then return end
 local cache=hash(chain);if authorityCache[cache]then return authorityCache[cache]end
 if not X.Verify(parent.public,'AETHER-ISSUER-ROTATION/1\n'..wire,sig)then return end
 local result={public=f[5],epoch=epoch,notBefore=at,chain=chain};if count(authorityCache)>=16 then authorityCache={}end;authorityCache[cache]=result;return result
end
local certificateCache={}
function C.Certificate(blob,historical)
 if type(blob)~='string'or #blob>3000 then return nil,'CERTIFICATE_BOUND'end
 local encoded,sig,chain=blob:match('^WAC1|([%w_%-]+)|([a-f0-9]+)|([%w_%-]+)$')
 local wire=encoded and C.Decode(encoded,2048);local f=fields(wire,13)
 if not f or f[1]~='WAC1'or not hex(sig,128)then return nil,'CERTIFICATE_FORMAT'end
 local cached=certificateCache[blob];local root=C.Authority(f[2],chain=='none'and'-'or C.Decode(chain,4096))
 if not root then return nil,'UNTRUSTED_ISSUER'end
 local epoch,before,after=integer(f[10]),integer(f[11]),integer(f[12])
 if not hex(f[3],32)or f[4]~=C.Namespace()or not text(f[6],96)or not text(f[7],96)
  or f[5]~=C.Principal(f[6],f[7])or not ns.ChronicleStore.GUID(f[8])or not hex(f[9],64)
  or not epoch or epoch<1 or not before or not after or after<=before or after-before>C.MAX_LIFE or before>now()+5 then return nil,'CERTIFICATE_IDENTITY_OR_VALIDITY'end
 local scopes={};for scope in f[13]:gmatch('[^,]+')do if not({community=true,self=true,enroll=true})[scope]or scopes[scope]then return nil,'CERTIFICATE_SCOPE'end;scopes[scope]=true end
 if not next(scopes)or scopes.enroll and after-before>86400 then return nil,'CERTIFICATE_SCOPE'end
 if not cached then
  if not X.Verify(root.public,'AETHER-CHARACTER-CERTIFICATE/1\n'..wire,sig)then return nil,'FORGED_CERTIFICATE'end
  cached={issuer=f[2],serial=f[3],namespace=f[4],principal=f[5],name=f[6],realm=f[7],guid=f[8],public=f[9],epoch=epoch,
   notBefore=before,notAfter=after,scopes=scopes,keyID=hash(f[9]),id=hash(blob),blob=blob}
  if count(certificateCache)>=128 then certificateCache={}end;certificateCache[blob]=cached
 end
 if not historical and now()>cached.notAfter then return nil,'CERTIFICATE_EXPIRED'end
 return cached
end
local revocations=setmetatable({},{__mode='k'})
function C.IsRevoked(ledger,cert)
 if not ledger then return false end
 local cache=revocations[ledger]
 if not cache or cache.revision~=ledger.revision then
  cache={revision=ledger.revision,keys={}}
  for _,rows in ipairs({ledger.records or{},ledger.floors or{}})do for _,row in pairs(rows)do
   local r=row.record or row.pair and(B.DecodeChunk(row.pair.wire)or{})[1]
   if r and r.kind=='KEY_REVOCATION'and r.data.issuer==C.AUTHORITY then cache.keys[r.subjectKey..'/'..r.data.keyID]=true end
  end end
  revocations[ledger]=cache
 end
 return cache.keys[cert.guid..'/'..cert.keyID]==true
end
local function storage(create)
 local s=ns.Storage.OlympusWardenExchangeDB
 if s==nil and create then s={schema=1,characters={}};ns.Storage.OlympusWardenExchangeDB=s end
 if not plain(s)or s.schema~=1 or not plain(s.characters)then return nil,'EXCHANGE_RECOVERY_REQUIRED'end
 if s.aetherCredentials==nil and create then s.aetherCredentials={schema=1,owners={}}end
 local k=s.aetherCredentials;if k==nil then return end
 if not plain(k)or k.schema~=1 or not plain(k.owners)or count(k.owners)>64 then return nil,'CREDENTIAL_RECOVERY_REQUIRED'end
 return k
end
function C.LocalMaterial()local s=storage(false);local own=ns.PlayerCard.Own();local row=s and s.owners[own];return plain(row)and row.namespace==C.Namespace()and row or nil end
function C.LocalCertificate(ledger)
 local row=C.LocalMaterial();local me=ns.AetherNative and ns.AetherNative.NativeUnit('player')
 local cert,why;if row then cert,why=C.Certificate(row.certificate)end;if not cert then return nil,why or'PENDING_ENROLLMENT'end
 if not me or cert.guid~=me.guid or cert.principal~=C.Principal(me.base,me.realm)or cert.public~=row.public then return nil,'NATIVE_CHARACTER_BINDING_CHANGED'end
 if C.IsRevoked(ledger,cert)then return nil,'KEY_REVOKED'end;return cert
end
function C.ImportKey(value)
 if not ns.Permissions.Decide('UIAccess')then return false,'UI_ACCESS_REQUIRED'end
 local nskey,pub,seed
 if type(value)=='string'then nskey,pub,seed=value:match('^WAK1|([%w_%-]+)|([a-f0-9]+)|([a-f0-9]+)$')end
 if nskey~=C.Namespace()or not hex(pub,64)or not hex(seed,64)or X.Public(seed)~=pub then return false,'PRIVATE_KEY_IMPORT_INVALID'end
 local s,why=storage(true);if not s then return false,why end;local own=ns.PlayerCard.Own();if not own then return false,'NATIVE_OWNER_REQUIRED'end
 if not s.owners[own]and count(s.owners)>=64 then return false,'CREDENTIAL_OWNER_BOUND'end
 local old=s.owners[own];s.owners[own]={namespace=nskey,public=pub,seed=seed,certificate=old and old.public==pub and old.certificate or nil}
 return true,'Character key imported. Existing posts and drafts are kept; enrollment is pending.'
end
function C.ImportCertificate(value,ledger)
 local cert,why=C.Certificate(value);if not cert then return false,why end
 local row=C.LocalMaterial();local me=ns.AetherNative and ns.AetherNative.NativeUnit('player')
 if not row or not me or cert.guid~=me.guid or cert.public~=row.public or cert.principal~=C.Principal(me.base,me.realm)or C.IsRevoked(ledger,cert)then return false,'CERTIFICATE_NOT_FOR_THIS_NATIVE_CHARACTER_KEY'end
 local prior=row.certificate and C.Certificate(row.certificate,true)
 if prior and cert.epoch<prior.epoch then return false,'CERTIFICATE_KEY_EPOCH_ROLLBACK'end
 row.certificate=value;return true,'Character enrollment certificate installed.'
end
function C.SignRecord(wire,ledger)
 local cert,why=C.LocalCertificate(ledger);if not cert or not cert.scopes.community then return nil,why or'COMMUNITY_AUTHORITY_REQUIRED'end
 local row=C.LocalMaterial();local at=now();local signature=X.Sign(row.seed,'AETHER-RECORD/1\n'..cert.id..'\n'..at..'\n'..wire)
 return signature and('P1:'..C.Encode(cert.blob)..':'..at..':'..signature)or nil
end
local proofCache={}
function C.VerifyRecord(principal,wire,proof,ledger,historical)
 if type(proof)~='string'or #proof>C.MAX_PROOF then return nil,'ORIGIN_PROOF_BOUND'end
 local cb,ts,sig=proof:match('^P1:([%w_%-]+):(%d+):([a-f0-9]+)$');local blob=cb and C.Decode(cb,4000)
 local cert,why=C.Certificate(blob,historical);local at=ts and integer(ts)
 if not cert then return nil,why end
 if cert.principal~=principal or not cert.scopes.community or not at or at<cert.notBefore or at>cert.notAfter or at>now()+5 or not hex(sig,128)then return nil,'ORIGIN_AUTHORITY_SCOPE'end
 if not historical and C.IsRevoked(ledger,cert)then return nil,'KEY_REVOKED'end
 local digest=hash(wire..proof)
 if not proofCache[digest]then
  if not X.Verify(cert.public,'AETHER-RECORD/1\n'..cert.id..'\n'..at..'\n'..wire,sig)then return nil,'ORIGIN_SIGNATURE'end
  if count(proofCache)>=4096 then proofCache={}end;proofCache[digest]=true
 end
 return cert
end
function C.VerifyIssuer(principal,wire,proof)
 if type(proof)~='string'or #proof>C.MAX_PROOF then return false end
 local key,chain,sig=proof:match('^R1:([a-f0-9]+):([%w_%-]+):([a-f0-9]+)$')
 local root=key and C.Authority(key,chain=='none'and'-'or C.Decode(chain,4096))
 return principal=='Issuer/'..C.AUTHORITY and root and hex(sig,128)and X.Verify(root.public,'AETHER-AUTHORITY-RECORD/1\n'..wire,sig)and key or nil
end
function C.RootRecordPolicy(r,issuer,historical)
 if r.origin~='Issuer/'..C.AUTHORITY or r.subjectType~='CHARACTER'or not issuer then return false end
 local d=r.data
 if r.kind=='CHARACTER_CERTIFICATE'then
  local cert=C.Certificate(d.certificate,historical);return d.version==1 and cert and cert.guid==r.subjectKey and cert.keyID==r.slot and r.expiresAt<=cert.notAfter or false
 elseif r.kind=='KEY_REVOCATION'then
  return d.version==1 and d.issuer==C.AUTHORITY and hex(d.keyID,64)and r.slot==d.keyID and r.removed==true and ns.ChronicleStore.Integer(d.revokedAt,1,now()+5)and text(d.reason,120)or false
 end
 return false
end
function C.Status(row,ledger,own)
 if row.record.origin=='Issuer/'..C.AUTHORITY then return 'AUTHORITY_SIGNED'end
 local cert=C.VerifyRecord(row.record.origin,row.pair.wire,row.pair.signature,ledger,true)
 if cert then if C.IsRevoked(ledger,cert)then return 'HISTORICAL_KEY_REVOKED'elseif now()>cert.notAfter then return 'HISTORICAL_CERTIFICATE_EXPIRED'end;return 'AUTHENTICATED'end
 return row.record.origin==own and'PENDING_ENROLLMENT'or'UNVERIFIED_LEGACY'
end
function C.UpgradePending(client)
 local cert=C.LocalCertificate(client);if not cert then return false end
 local changed=0
 for _,row in pairs(client.records)do if row.record.origin==client.principal and row.record.expiresAt>now()then
  local old=C.VerifyRecord(row.record.origin,row.pair.wire,row.pair.signature,client,true)
  if not old or old.id~=cert.id then local proof=C.SignRecord(row.pair.wire,client)
   if proof then local ok=client:Accept({wire=row.pair.wire,signature=proof},'live');if ok then changed=changed+1 end end
   if changed>=2 then break end
  end
 end end
 return changed>0
end
function C.AdoptIssued(client)
 for _,row in pairs(client.records)do local r=row.record
  if r.kind=='CHARACTER_CERTIFICATE'and r.subjectKey==ns.PlayerCard.Own()and r.expiresAt>now()then C.ImportCertificate(r.data.certificate,client)end
 end
end
function C.ImportAuthorityRecord(text,client)
 local encoded=type(text)=='string'and text:match('^WAR1:([%w_%-]+)$');local bytes=encoded and C.Decode(encoded,15000);local pair=bytes and(B.DecodeChunk(bytes)or{})[1]
 if not plain(pair)then return false,'AUTHORITY_RECORD_FORMAT'end
 local ok,why=client:Accept(pair,'live');if ok then C.AdoptIssued(client);if client.Save then local saved,err=client:Save();if not saved then return false,err end end end
 return ok,why
end
function C.ImportAuthorityBatch(text,client)
 if type(text)~='string'or #text>200000 then return false,'AUTHORITY_IMPORT_BOUND'end
 local lines={};for line in text:gmatch('[^\r\n]+')do if #lines>=32 then return false,'AUTHORITY_IMPORT_BOUND'end;lines[#lines+1]=line end
 if #lines==0 then return false,'AUTHORITY_RECORD_FORMAT'end
 local accepted,held=0,0
 for _,line in ipairs(lines)do local ok=C.ImportAuthorityRecord(line,client);if ok then accepted=accepted+1 else held=held+1 end end
 return held==0,tostring(accepted)..' public authority records imported; '..held..' held. No private signing key was imported.'
end
function C.ImportUI()
 return ns.UI2Forms.Form({title='Aether character enrollment',help='Local posts, comments, ratings and drafts work before enrollment. Import your helper-generated character key privately, then allow a trusted Hephaestus verifier to enroll it. Never share the WAK1 key text. The Fireside Authority private key is never imported here.',fields={{key='value',label='Character key, public certificate, or signed authority records',multiline=true,height=150,value='',limit=200000,code=true}},submitLabel='Import enrollment material',submit=function(v,form)
  if v.value:match('^WAK1|')then local ok,why=C.ImportKey(v.value);v.value='';if form and form.inputs.value then form.inputs.value:SetText('')end;return ok,why end
  local client,why=ns.AetherNet.PublicationClient();if not client then return false,why end
  if v.value:match('^WAR1:')then return C.ImportAuthorityBatch(v.value,client)end
  return C.ImportCertificate(v.value,client)
 end})
end
