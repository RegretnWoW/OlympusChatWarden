-- Transient projections of supplied/current results. This file NEVER initiates searches.
local _,ns=...
local R=ns.Athena2
local L={VERSION=1,MAX_RESULTS=128,MAX_MEMBERS=40,TTL=180};ns.AthenaNativeLFGAdapter=L
local fields={'name','realm','class','role'}
local roles={TANK=true,HEALER=true,DAMAGER=true}
local function member(raw)
 local m={};for _,k in ipairs(fields) do m[k]=R.Text(R.Field(raw,k)) end
 m.guid=R.GUID(R.Field(raw,'guid'));m.level=R.Number(R.Field(raw,'level'),1,1000)
 if not roles[m.role] then m.role=nil end
 -- GUID is the only supported dossier identity proof in this offline candidate.
 m.resolved=m.guid~=nil;m.identityStatus=m.resolved and 'GUID supplied by source' or 'Unresolved native member';return m
end
function L.New(clock)
 local a={generation=0,results={},order={},revision=0,clock=clock or R.Now,expired=0,rejected=0,source='OFFICIAL_BLIZZARD_LFG'}
 function a:Reclaim()
  local order={};for _,key in ipairs(self.order) do local s=self.results[key]
   if s and s.expiresAt>self.clock() and not s.delisted then order[#order+1]=key
   else if s then self.expired=self.expired+1 end;self.results[key]=nil end
  end;self.order=order
 end
 function a:Begin(generation)
  if not R.Number(generation,1,1000000000) or generation%1~=0 or generation<=self.generation then return false end
  self.generation=generation;self.results={};self.order={};self.revision=self.revision+1;return true
 end
 function a:Observe(id,raw,generation)
  self:Reclaim()
  if generation~=self.generation or not R.Number(id,1,1000000000) or id%1~=0 then return nil,'WRONG_GENERATION' end
  local activity=R.Number(R.Field(raw,'activityID'),1,1000000000)
  if not activity then self.rejected=self.rejected+1;return nil,'ACTIVITY_UNAVAILABLE' end
  local key=generation..':'..id;local previous=self.results[key]
  if not previous and #self.order>=L.MAX_RESULTS then return nil,'CACHE_FULL' end
  local now=self.clock();local s={key=key,resultID=id,generation=generation,activityID=activity,activityName=R.Text(R.Field(raw,'activityName')),title=R.Text(R.Field(raw,'title'),160),observedAt=now,expiresAt=now+L.TTL,revision=(previous and previous.revision or 0)+1,members={},roles={},knownMembers=0,source=self.source}
  for _,k in ipairs({'spaces','minLevel','maxLevel','numMembers'}) do s[k]=R.Number(R.Field(raw,k),0,k=='numMembers' and 100 or 1000) end
  for _,k in ipairs({'eligible','full','crossFaction'}) do local v=R.Field(raw,k);if type(v)=='boolean' then s[k]=v end end
  s.faction=R.Text(R.Field(raw,'faction'));s.playstyle=R.Text(R.Field(raw,'playstyle'))
  local roleInput=R.Field(raw,'roles');for role in pairs(roles) do s.roles[role]=R.Number(R.Field(roleInput,role),0,40) end
  if not next(s.roles) then s.roles=nil end
  local members=R.Field(raw,'members')
  for i=1,math.min(s.numMembers or 0,L.MAX_MEMBERS) do
   local m=member(R.Field(members,i));s.members[i]=m;if m.guid then s.knownMembers=s.knownMembers+1 end
  end
  s.leader=member(R.Field(raw,'leader'));s.leader.name=s.leader.name or R.Text(R.Field(raw,'leaderName'))
  s.memberCoverage=s.numMembers and #s.members..' / '..s.numMembers..' exposed slots' or 'Roster size unknown'
  if not previous then self.order[#self.order+1]=key end
  self.results[key]=s;self.revision=self.revision+1;return R.Copy(s)
 end
 function a:Get(key)
  local row=self.results[key];if not row then return end
  if row.expiresAt<=self.clock() or row.delisted then self.results[key]=nil;self.revision=self.revision+1;self.expired=self.expired+1;return end
  return R.Copy(row)
 end
 function a:Remove(id,generation)
  local key=generation..':'..id;if self.results[key] then self.results[key]=nil;self.revision=self.revision+1;self:Reclaim();return true end
 end
 function a:Page(key,offset)
  local s=self:Get(key);if not s then return nil,'EXPIRED' end
  offset=R.Number(offset,0,40) or 0;local rows={};for n=offset+1,math.min(#s.members,offset+10) do rows[#rows+1]=s.members[n] end
  return rows,offset+10<#s.members and offset+10 or nil,s
 end
 function a:LeaderListing(guid)
  if not R.GUID(guid) then return end
  for n=#self.order,1,-1 do local s=self:Get(self.order[n]);if s and s.leader.guid==guid then return s end end
 end
 function a:Rank(viewer,sort)
  local rows={};for n,key in ipairs(self.order) do local s=self:Get(key);if s then rows[#rows+1]={key=key,original=n,listing=s,match=ns.AthenaGroupMatch.Score(viewer,s,self.clock())} end end
  if sort then table.sort(rows,function(x,y)
   local xs,ys=x.match.score or -1,y.match.score or -1;if xs~=ys then return xs>ys end;return x.original<y.original
  end) end
  return rows
 end
 return a
end
L.Current=L.New()
function L.Capabilities()
 local api=C_LFGList
 return {info=type(R.Field(api,'GetSearchResultInfo'))=='function' and 'PRESENT / NATIVE-PENDING' or 'UNAVAILABLE',leader=type(R.Field(api,'GetSearchResultLeaderInfo'))=='function' and 'PRESENT / NATIVE-PENDING' or 'UNAVAILABLE',member=type(R.Field(api,'GetSearchResultPlayerInfo'))=='function' and 'PRESENT / NATIVE-PENDING' or 'UNAVAILABLE',sort='NATIVE-PENDING / disabled',apply='NATIVE-PENDING / Blizzard user action',transport='NATIVE-PENDING / disabled'}
end
function L.ReadCurrentResults() return nil,'NATIVE-PENDING: this build does not read native search results until the adapter is validated.' end
