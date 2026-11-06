-- Shared local intelligence utilities. No network, new collectors or raw-history schema.
local _,ns=...
local R={VERSION=2,RELEASE='2.9-offline1',NATIVE='NATIVE-PENDING'};ns.Athena2=R
function R.Read(v) return (not ns.Readable or ns.Readable(v)) end
function R.Field(t,k)
 if not R.Read(t) or type(t)~='table' then return nil end
 local ok,v=pcall(function() return t[k] end);if ok and R.Read(v) then return v end;return nil
end
function R.Text(v,limit)
 if R.Read(v) and type(v)=='string' and #v>0 and #v<=(limit or 128) and not v:find('[%z\1-\31\127|]') then return v end
end
function R.Number(v,lo,hi)
 if R.Read(v) and type(v)=='number' and v==v and v~=math.huge and v~=-math.huge and v>=(lo or 0) and v<=(hi or 1000000000000) then return v end
end
function R.GUID(v) return R.Text(v,64) and v:match('^Player%-%w[%w%-]*$') and v or nil end
function R.Now() return ns.SafeNumber(ns.SafeCall(GetServerTime)) or ns.SafeNumber(ns.SafeCall(time)) or 0 end
function R.Owner() return ns.Chronicle and ns.Chronicle.Owner() end
function R.Origin(st) return (WARDEN_SIMULATOR_ISOLATED==true or st and st.syntheticEvidence) and 'synthetic' or 'native_local' end
function R.Permit(module)
 if not ns.Membership or not ns.Membership.Allowed() then return false end
 return not ns.Modules or module=='relay' or module=='command' or ns.Modules.Enabled(module)
end
-- A caller receives fresh bounded values, never mutable cache/canonical tables.
function R.Copy(v,limit)
 local count,seen=0,{};limit=limit or 4096
 local function copy(x,depth)
  count=count+1;if count>limit or depth>8 or not R.Read(x) then error('BOUNDS') end
  if type(x)=='string' then if #x>4096 then error('STRING') end;return x end
  if type(x)=='number' then if not R.Number(x,-1000000000000) then error('NUMBER') end;return x end
  if type(x)=='boolean' or x==nil then return x end
  if type(x)~='table' or getmetatable(x) or seen[x] then error('PLAIN_DATA_REQUIRED') end
  seen[x]=true;local out={};for k,val in pairs(x) do
   if not (type(k)=='string' and #k<=128 or R.Number(k,1,10000) and k%1==0) then error('KEY') end
   out[k]=copy(val,depth+1)
  end;seen[x]=nil;return out
 end
 local ok,result=pcall(copy,v,0);if ok then return result end
end
function R.Count(t) local n=0;for _ in pairs(t or {}) do n=n+1 end;return n end
function R.Cache(cap)
 local c={values={},clock=0,hits=0,misses=0,evictions=0,cap=cap or 64}
 function c:Get(key,revision)
  local row=self.values[key];if row and row.revision==revision then self.clock=self.clock+1;row.used=self.clock;self.hits=self.hits+1;return row.value end
  self.misses=self.misses+1
 end
 function c:Put(key,revision,value)
  self.clock=self.clock+1;self.values[key]={value=value,revision=revision,used=self.clock}
  if R.Count(self.values)>self.cap then local oldest,at;for k,row in pairs(self.values) do if k~=key and (not at or row.used<at) then oldest,at=k,row.used end end;if oldest then self.values[oldest]=nil;self.evictions=self.evictions+1 end end
  return value
 end
 function c:Clear() self.values={} end
 return c
end
-- No persisted boolean can unlock native transport, sort, whisper, Apply or Invite.
R.NativeCapabilities={searchRead='NATIVE-PENDING',members='NATIVE-PENDING',rowAnchor='NATIVE-PENDING',sort='NATIVE-PENDING',apply='NATIVE-PENDING',invite='NATIVE-PENDING',whisper='NATIVE-PENDING',bridge='NATIVE-PENDING',principal='NATIVE-PENDING'}
