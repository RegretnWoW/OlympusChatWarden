-- Remote claims stay outside canonical WardenDB. Copies do not become witnesses.
local _,ns=...
local R=ns.Athena2
local S={VERSION=1};ns.AthenaSharedStore=S
function S.New(clock)
 local c={claims={},order={},bytes=0,limit=256,byteLimit=262144,clock=clock or R.Now,conflicts=0,revision=0}
 function c:Expire()
  for i=#self.order,1,-1 do local k=self.order[i];local r=self.claims[k]
   if not r or r.expiresAt<=self.clock() then if r then self.bytes=self.bytes-r.bytes end;self.claims[k]=nil;table.remove(self.order,i);self.revision=self.revision+1 end
  end
 end
 function c:Put(origin,observation,revision,expiresAt,card,publisherGUID)
  self:Expire();if not R.Text(origin,128) or not R.Text(observation,128) or not R.Number(revision,1) or not R.Number(expiresAt,self.clock()+1,self.clock()+86400) then return false,'CLAIM_METADATA' end
  local clean,wire=ns.AthenaSharePolicy.Validate(card);if not clean then return false,'INVALID_CARD' end
  if clean.declaration and publisherGUID~=clean.personKey then return false,'DECLARATION_OWNER_REQUIRED' end
  local key=origin..'/'..observation;local old=self.claims[key]
  if old and old.revision>revision then return false,'OLD_REVISION' end
  if old and old.revision==revision then if old.wire~=wire then old.conflict=true;self.conflicts=self.conflicts+1;return false,'CONFLICT' end;return true,'DUPLICATE' end
  if old then self.bytes=self.bytes-old.bytes else self.order[#self.order+1]=key end
  self.claims[key]={origin=origin,publisherGUID=R.GUID(publisherGUID),observation=observation,revision=revision,expiresAt=expiresAt,card=clean,wire=wire,bytes=#wire,sourceClass='remote_report'};self.bytes=self.bytes+#wire
  self.revision=self.revision+1
  while #self.order>self.limit or self.bytes>self.byteLimit do local k=table.remove(self.order,1);local row=self.claims[k];if row then self.bytes=self.bytes-row.bytes;self.claims[k]=nil end end
  return true
 end
 function c:Get(kind,key)
  self:Expire();local out={};for _,id in ipairs(self.order) do local r=self.claims[id]
   if r and r.card.kind==kind and (r.card.personKey or r.card.eventKey)==key then out[#out+1]=R.Copy(r) end
  end;return out
 end
 function c:Clear() self.claims={};self.order={};self.bytes=0;self.revision=self.revision+1 end
 function c:Snapshot()
  self:Expire();local rows={}
  for _,key in ipairs(self.order) do local r=self.claims[key]
   rows[#rows+1]={origin=r.origin,publisherGUID=r.publisherGUID,observation=r.observation,revision=r.revision,expiresAt=r.expiresAt,card=R.Copy(r.card)}
  end
  return rows
 end
 function c:Restore(rows,authority)
  if type(rows)~='table' or getmetatable(rows) or #rows>self.limit then return false,'CLAIM_STATE_BOUNDS' end
  local candidate=S.New(self.clock)
  for key,row in pairs(rows) do
   if not R.Number(key,1,#rows) or key%1~=0 or type(row)~='table' then return false,'CLAIM_STATE_SHAPE' end
   for field in pairs(row) do if not ({origin=true,publisherGUID=true,observation=true,revision=true,expiresAt=true,card=true})[field] then return false,'CLAIM_STATE_FIELD' end end
   if not R.Number(row.expiresAt,0) then return false,'CLAIM_STATE_EXPIRY' end
   if row.expiresAt>self.clock() then
    if row.card and row.card.declaration then local a=authority and authority(row.publisherGUID)
     if not a or not a.verified or a.guid~=row.publisherGUID or a.principal~=row.origin then return false,'DECLARATION_AUTHORITY_PENDING' end
    end
    local ok,why=candidate:Put(row.origin,row.observation,row.revision,row.expiresAt,row.card,row.publisherGUID);if not ok then return false,why end
   end
  end
  self.claims=candidate.claims;self.order=candidate.order;self.bytes=candidate.bytes;self.revision=self.revision+1;return true
 end
 return c
end
local V={VERSION=1};ns.AthenaRatingStore=V
function V.New(clock)
 local c={votes={},targets={},limit=1024,clock=clock or R.Now}
 function c:Apply(authority,vote)
  if not authority or not authority.verified or not R.Text(authority.principal,128) or not R.GUID(authority.guid) or type(vote)~='table' then return false,'UNVERIFIED_PRINCIPAL' end
  for k in pairs(vote) do if not ({subject=true,stars=true,revision=true,revoked=true})[k] then return false,'UNKNOWN_VOTE_FIELD' end end
  if not R.GUID(vote.subject) or vote.subject==authority.guid or authority.owned and authority.owned[vote.subject] then return false,'SELF_OR_IDENTITY' end
  if not R.Number(vote.revision,1,1000000000) or vote.revision%1~=0 or type(vote.revoked)~='boolean' then return false,'REVISION' end
  if not vote.revoked and (not R.Number(vote.stars,1,5) or vote.stars%1~=0) or vote.revoked and vote.stars~=nil then return false,'STARS' end
  local key=authority.principal..'/'..vote.subject;local old=self.votes[key]
  if old and old.revision>vote.revision then return false,'OLD_REVISION' end
  if old and old.revision==vote.revision then return old.stars==vote.stars and old.revoked==vote.revoked,'DUPLICATE_OR_CONFLICT' end
  if not old and R.Count(self.votes)>=self.limit then return false,'VOTE_CAPACITY' end
  local t=self.targets[vote.subject] or {count=0,sum=0};self.targets[vote.subject]=t
  if old and not old.revoked then t.count=t.count-1;t.sum=t.sum-old.stars end
  local clean=R.Copy(vote);clean.principal=authority.principal;clean.raterGUID=authority.guid;clean.guarantee=authority.accountVerified and 'Verified member principal (mock authority)' or 'Per-character only; account uniqueness unverified'
  self.votes[key]=clean
  if not clean.revoked then t.count=t.count+1;t.sum=t.sum+clean.stars end
  return true
 end
 function c:Get(subject)
  local t=self.targets[subject];return {count=t and t.count or 0,average=t and t.count>0 and t.sum/t.count or nil,identityGuarantee='Only as strong as the verified transport principal; live Bridge pending'}
 end
 function c:Snapshot()
  local out={};for _,v in pairs(self.votes) do out[#out+1]={subject=v.subject,stars=v.stars,revision=v.revision,revoked=v.revoked,principal=v.principal,raterGUID=v.raterGUID} end
  table.sort(out,function(a,b) return a.principal..'/'..a.subject<b.principal..'/'..b.subject end);return out
 end
 function c:Restore(rows,authority)
  if type(rows)~='table' or getmetatable(rows) or #rows>self.limit then return false,'VOTE_STATE_BOUNDS' end
  local candidate=V.New(self.clock)
  for key,v in pairs(rows) do
   if not R.Number(key,1,#rows) or key%1~=0 or type(v)~='table' then return false,'VOTE_STATE_SHAPE' end
   for field in pairs(v) do if not ({subject=true,stars=true,revision=true,revoked=true,principal=true,raterGUID=true})[field] then return false,'VOTE_STATE_FIELD' end end
   local a=authority and authority(v.raterGUID)
   if not a or a.principal~=v.principal then return false,'VOTE_AUTHORITY_PENDING' end
   local ok,why=candidate:Apply(a,{subject=v.subject,stars=v.stars,revision=v.revision,revoked=v.revoked});if not ok then return false,why end
  end
  self.votes=candidate.votes;self.targets=candidate.targets;return true
 end
 return c
end
