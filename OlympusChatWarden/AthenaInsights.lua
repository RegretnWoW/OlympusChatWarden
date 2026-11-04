-- Small deterministic registry; values remain local, source-labelled and read-only.
local _,ns=...
local R=ns.Athena2
local I={VERSION=1,rules={},subscribers={},notifications=0};ns.AthenaInsights=I
function I.Register(kind,revision,fn)
 if not R.Text(kind,64) or not R.Number(revision,1,1000) or type(fn)~='function' or I.rules[kind] then return false end
 I.rules[kind]={revision=revision,fn=fn};return true
end
function I.Get(kind,key,opts)
 opts=opts or {};if not R.Permit(opts.consumer or 'intel') then return nil,'DENIED' end
 local rule=I.rules[kind];if not rule then return nil,'UNSUPPORTED' end
 local value,status=rule.fn(key,opts);if not value then return nil,status end
 local out=R.Copy(value);if not out then return nil,'BOUNDS' end
 out.insightType=kind;out.rulesVersion=rule.revision;out.visibility='local';return out
end
function I.Subscribe(key,fn) if R.Text(key,64) and type(fn)=='function' and (I.subscribers[key] or R.Count(I.subscribers)<16) then I.subscribers[key]=fn;return true end end
function I.Notify(kind,key,revision)
 I.notifications=I.notifications+1
 for _,fn in pairs(I.subscribers) do pcall(fn,kind,key,revision) end
end
I.Register('PVP_OBSERVED_SUMMARY',1,function(key,o) return ns.AthenaStats.Get(key,o.owner,o.consumer) end)
I.Register('PLAYER_PROFILE_UPDATED',1,function(key,o) return ns.AthenaProfiles.GetPlayer(key,o.owner,o.consumer) end)
I.Register('EVENT_PROFILE_UPDATED',1,function(key,o) return ns.AthenaProfiles.GetEvent(key,o.owner,o.consumer) end)
I.Register('VERIFIED_DUNGEON_CLEAR',1,function(key,o) return {subjectKey=key,value='unknown',certainty='unknown',evidenceRefs={},coverage='No supported complete-instance proof adapter validated'} end)
function I.Relationships(kind,key,owner,cursor)
 local refs,nextCursor=ns.AthenaProfiles.Sources(kind,key,owner,cursor,'intel');if not refs then return nil,nextCursor end
 local profile=kind=='event' and ns.AthenaProfiles.GetEvent(key,owner,'intel') or ns.AthenaProfiles.GetPlayer(key,owner,'intel')
 local out={};for _,ref in ipairs(refs) do out[#out+1]={relationship='OBSERVATION_SUPPORTS_CLAIM',subject=key,object=ref,sourceOrigin=profile and profile.sourceOrigin or 'unverified_archive',rulesVersion=1,noCausation=true} end
 return out,nextCursor
end
