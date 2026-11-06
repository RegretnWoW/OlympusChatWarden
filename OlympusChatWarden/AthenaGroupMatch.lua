-- Listing fit, not player quality, invitation probability or Aether stars.
local _,ns=...
local R=ns.Athena2
local M={VERSION=1};ns.AthenaGroupMatch=M
function M.Score(viewer,listing,now)
 viewer=viewer or {};now=now or R.Now()
 local out={algorithm=1,state='Unknown',reasons={},blockers={},missing={},coverage=0,updatedAt=now,kind='GROUP_LISTING_FIT'}
 if type(listing)~='table' then return out end
 local function block(text) out.blockers[#out.blockers+1]=text end
 if listing.expiresAt<=now or listing.delisted then block('Listing expired or delisted') end
 if listing.full==true or listing.spaces==0 then block('Group is full') end
 if listing.eligible==false then block('Activity is inaccessible') end
 if listing.faction and viewer.faction and listing.faction~=viewer.faction and not listing.crossFaction then block('Faction restriction') end
 if viewer.level and (listing.minLevel and viewer.level<listing.minLevel or listing.maxLevel and viewer.level>listing.maxLevel) then block('Level requirement') end
 if viewer.role and listing.roles and listing.roles[viewer.role]==0 then block('No opening for your selected role') end
 if #out.blockers>0 then out.state='Ineligible';return out end
 local earned,known=0,0
 local function component(weight,fit,text) known=known+weight;earned=earned+weight*fit;out.reasons[#out.reasons+1]=text end
 if listing.activityID and viewer.activityID then component(30,listing.activityID==viewer.activityID and 1 or 0,'Advertised activity compared with your selected activity') else out.missing[#out.missing+1]='Activity preference unknown' end
 if viewer.role and listing.roles and listing.roles[viewer.role]~=nil then component(30,listing.roles[viewer.role]>0 and 1 or 0,'Opening for your declared '..viewer.role..' role') else out.missing[#out.missing+1]='Role opening unknown' end
 if viewer.playstyle and listing.playstyle then component(15,viewer.playstyle==listing.playstyle and 1 or 0,'Advertised playstyle') else out.missing[#out.missing+1]='Playstyle not declared' end
 if viewer.objectives and listing.objectives then
  local overlap=false;for _,id in ipairs(listing.objectives) do if viewer.objectives[id] then overlap=true end end
  component(10,overlap and 1 or 0,'Supported objective alignment')
 end
 -- Unknown members are neutral: absent familiarity is omitted, never a penalty.
 if listing.familiarity~=nil then component(10,math.min(1,math.max(0,listing.familiarity)),'Previously recorded grouping context') end
 component(5,math.max(.2,1-(now-listing.observedAt)/math.max(1,listing.expiresAt-listing.observedAt)),'Current listing freshness')
 out.coverage=known;out.memberCoverage=listing.knownMembers or 0
 if known>=30 then out.score=math.floor(earned/known*100+.5);out.state='Scored' end
 out.prerequisites=listing.eligible==nil and 'Unverified' or 'Known';return out
end
ns.AthenaInsights.Register('GROUP_COMPATIBILITY',1,function(key,o)
 local listing=ns.AthenaNativeLFGAdapter.Current:Get(key);if not listing then return nil,'EXPIRED' end
 return M.Score(o.viewer or ns.Fellowship.Context(),listing)
end)
