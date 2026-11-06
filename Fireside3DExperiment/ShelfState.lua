-- Existing WardenShelfShowcase Validate/Swap; session state replaces owner/history access.
local _,ns=...
local S={SLOTS=7};ns.ExperimentShelfState=S
local B=ns.WardenComposition
local function plain(v)return type(v)=='table'and not getmetatable(v)end
function S.Validate(v)
 if not plain(v)or v.version~=1 or not plain(v.slots)then return nil,'Invalid showcase'end
 for k in pairs(v)do if k~='version'and k~='slots'then return nil,'Unknown showcase field'end end
 local out={version=1,slots={}};local seen={}
 for k,id in pairs(v.slots)do
  if type(k)~='number'or k%1~=0 or k<1 or k>S.SLOTS or type(id)~='string'or not B.catalog[id]or not B.catalog[id].activity or seen[id]then return nil,'Use seven distinct activity badges'end
  seen[id]=true;out.slots[k]=id
 end;return out
end
function S.Swap(work,a,b)
 if not S.Validate(work)or type(a)~='number'or type(b)~='number'or a%1~=0 or b%1~=0 or a<1 or b<1 or a>7 or b>7 then return false end
 work.slots[a],work.slots[b]=work.slots[b],work.slots[a];return true
end
