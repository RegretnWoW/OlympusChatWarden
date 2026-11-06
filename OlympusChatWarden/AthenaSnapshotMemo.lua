-- Memoize only the result of the unchanged snapshot hash over exact bytes.
-- No caller-supplied expected hash, mutable object or validation decision is cached.
local _,ns=...
local X,B=ns.ChronicleCapture,ns.ChronicleBackup
local M={VERSION=1,LIMIT=32,BYTE_LIMIT=65536,ITEM_LIMIT=8192,hits=0,misses=0,bytes=0,count=0};ns.AthenaSnapshotMemo=M
local values,order={},{}
local original=X.Hash
function M.Clear() values={};order={};M.bytes=0;M.count=0 end
function X.Hash(payload,checkpoint)
 local encoded=B.Encode(payload)
 local cached=values[encoded]
 if cached then M.hits=M.hits+1;return cached end
 M.misses=M.misses+1
 local digest=original(payload,checkpoint)
 if #encoded<=M.ITEM_LIMIT and type(digest)=='string' then
  while #order>=M.LIMIT or M.bytes+#encoded>M.BYTE_LIMIT do
   local oldest=table.remove(order,1);values[oldest]=nil;M.bytes=M.bytes-#oldest
  end
  values[encoded]=digest;order[#order+1]=encoded;M.bytes=M.bytes+#encoded;M.count=#order
 end
 return digest
end
local initialize=ns.ChronicleStore.Initialize
function ns.ChronicleStore.Initialize(...) M.Clear();return initialize(...) end
