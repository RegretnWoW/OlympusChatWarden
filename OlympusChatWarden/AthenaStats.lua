-- Idempotent, per-observed-match counters. No lifetime inference or entry=clear.
local _,ns=...
local R=ns.Athena2
local T={VERSION=1};ns.AthenaStats=T
local counters={'killingBlows','honorableKills','deaths','damageDone','healingDone','honorGained'}
function T.Feed(st,e)
 local v=e.capture and e.capture.values;local family=e.capture and e.capture.family
 if family~='scoreboard' or not R.GUID(v.guid) or not R.Text(v.runID,128) or not R.Number(v.matchSequence) then return end
 -- Run/session-scoped native rows; a later observation replaces, never sums.
 local key=e.session..'/'..v.runID..'/'..v.matchSequence
 st.athena2.stats=st.athena2.stats or {};local p=st.athena2.stats[v.guid]
 if not p then p={matches={},count=0,totals={},revision=0};st.athena2.stats[v.guid]=p end
 local old=p.matches[key];if old and (old.at>e.at or old.at==e.at and old.ref>=e.id) then return end
 if not old then p.count=p.count+1 end
 local row={at=e.at,ref=e.id,scope='observed_match',terminalVerified=false}
 for _,k in ipairs(counters) do
  local value=R.Number(v[k],0,1000000000000);row[k]=value
  if old and old[k] then p.totals[k]=(p.totals[k] or 0)-old[k] end
  if value then p.totals[k]=(p.totals[k] or 0)+value end
 end
 p.matches[key]=row;p.revision=p.revision+1
end
function T.Get(guid,owner,consumer)
 if not R.Permit(consumer or 'intel') or not R.GUID(guid) then return nil,'DENIED' end
 local st,state=ns.AthenaActivityIndex.Request(owner);if not st then return nil,state end
 local ready,pending=ns.AthenaActivityIndex.Ensure(st,owner);if not ready then return nil,pending end
 local p=st.athena2 and st.athena2.stats and st.athena2.stats[guid]
 return {schema=1,subject=guid,sourceOrigin=R.Origin(st),scope='Observed in Fireside-recorded matches',matchCount=p and p.count or 0,coverage=p and 'Latest readable snapshots; terminal result unverified' or 'No qualifying observations',counters=p and R.Copy(p.totals) or {},wins='unknown',losses='unknown',nativeLifetime='unknown',pveClears={},pveStatus='No verified complete-instance policy; boss or entry is not a clear',revision=p and p.revision or 0}
end
-- Used by verified future adapters only, never by guessed final-boss/lockout data.
function T.QualifiesClear(proof)
 return type(proof)=='table' and proof.origin=='native_local' and proof.complete==true and proof.participantVerified==true
  and proof.nativeScope=='character_instance_complete' and R.GUID(proof.subject)~=nil and R.Text(proof.sourceRef,512)~=nil
  and (proof.method=='native_completed_instance' or proof.method=='native_scoped_achievement')
end
