-- Branches remain branches. A reference link is never proof of an unseen step.
local _,ns=...
local C={VERSION=1};ns.AthenaQuestChains=C
local source
function C.SetSource(data) source=data end
local function Row(id)
 local value=ns.AthenaQuestChainsData[id];local meta=source and source.questMeta[id]
 if not value or not meta then return end
 local hash,previous,following=value:match('^([^\031]+)\031([^\031]*)\031([^\031]*)$')
 local fields={};for v in (meta..'\031'):gmatch('(.-)\031') do fields[#fields+1]=v end
 if fields[9]~=hash then return end
 return previous,following
end
function C.Previous(id)
 local previous=Row(id);local rows={}
 for v in (previous or ''):gmatch('(%d+):[BPN]') do rows[#rows+1]=tonumber(v) end
 return rows
end
function C.Following(id)
 local _,following=Row(id);local rows={}
 for v in (following or ''):gmatch('%d+') do rows[#rows+1]=tonumber(v) end
 return rows
end
function C.Members(id)
 if not Row(id) then return {} end
 local key=ns.AthenaQuestArcFor[id];return ns.Athena.Copy(ns.AthenaQuestArcMembers[key] or {})
end
function C.Link(beforeID,afterID,env)
 local prior=Row(afterID);local validBefore=Row(beforeID)
 if not prior or not validBefore then return nil,'SOURCE_CHANGED_OR_UNKNOWN' end
 local kind
 for id,tag in prior:gmatch('(%d+):([BPN])') do if tonumber(id)==beforeID then kind=tag end end
 if not kind then return nil,'NO_VERIFIED_REFERENCE_LINK' end
 local before=ns.AthenaWorldKnowledge.GetQuest(beforeID,env);local after=ns.AthenaWorldKnowledge.GetQuest(afterID,env)
 if not before or not after then return nil,'UNKNOWN' end
 return {before=before,after=after,relationship=kind,worldRefs={before.worldRef,after.worldRef},
  confidence='TYPED_SOURCE_REFERENCE_LINK',impliesPlayerCompletion=false,impliesCommonCause=false}
end
