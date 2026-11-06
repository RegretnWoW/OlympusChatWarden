-- Rebuildable whole-board observations. A capture is never a lifetime total.
local _,ns=...
local B={VERSION=1};ns.ChronicleScoreboards=B
local function State(st)
 if not st.scoreboards then st.scoreboards={objects={},byID={},order={}} end
 return st.scoreboards
end
local function Key(e,v) return e.session..'/'..v.runID..'/'..v.matchSequence end
local function Report(st,e,v,id,legacy)
 local state=State(st);local r=state.byID[id]
 if not r then
  r={id=id,owner=st.owner,firstAt=e.at,lastAt=e.at,instanceName=v.instanceName,instanceID=v.instanceID,
   instanceType=v.instanceType,phase=v.phase,reportKey=Key(e,v),rows={},refs={},refSet={},pages={},activityIDs={},legacy=legacy==true}
  state.byID[id]=r;state.order[#state.order+1]=r
 end
 if not r.refSet[e.id] then r.refSet[e.id]=true;r.refs[#r.refs+1]=e.id end
 r.lastAt=math.max(r.lastAt,e.at)
 return r
end
local function Bind(st,r,e)
 local v=e.capture.values;local a=st.active
 if a and (a.kind=='battleground' or a.kind=='arena') and a.session==e.session
  and a.context.instanceID==v.instanceID and a.context.instanceType==v.instanceType then r.activityIDs[a.id]=true end
end
function B.Feed(st,e)
 local cap=e.capture;if not cap then return end
 local state=State(st);local v=cap.values
 if cap.family=='scoreboard' then
  st.events[e.id]=e
  state.objects[e.details.contentID]=e
  if not v.runID or not v.matchSequence then return end
  local r=Report(st,e,v,Key(e,v)..'/legacy/'..(v.phase or '?'),true)
  local n=v.rowIndex or #r.rows+1;r.rows[n]={values=v,source=e};Bind(st,r,e)
 elseif cap.family=='scoreboard_page' then
  st.events[e.id]=e
  local id=Key(e,v)..'/'..v.captureSequence;local r=Report(st,e,v,id,false)
  r.expectedRows=v.expectedRows;r.expectedPages=v.parts;r.pages[v.part]=true;Bind(st,r,e)
  for n,hash in ipairs(v.rowRefs) do
   local at=(v.part-1)*32+n;local object=hash~=false and state.objects[hash]
   if object and object.capture.values.runID==v.runID and object.capture.values.matchSequence==v.matchSequence
    and object.capture.values.rowIndex==at then
    r.rows[at]={values=object.capture.values,source=object}
    if not r.refSet[object.id] then r.refSet[object.id]=true;r.refs[#r.refs+1]=object.id end
   end
  end
 end
end
function B.Rows(r)
 local out={};for n,row in pairs(r and r.rows or {}) do out[#out+1]={index=n,values=row.values,source=row.source} end
 table.sort(out,function(a,b) return a.index<b.index end);return out
end
function B.Complete(r)
 if not r or r.legacy or not r.expectedRows or #B.Rows(r)~=r.expectedRows then return false end
 for n=1,r.expectedPages do if not r.pages[n] then return false end end
 return true
end
function B.List(st,activity,guid)
 local out={};local state=st and State(st);if not state then return out end
 local native={};for _,r in ipairs(state.order) do if not r.legacy then native[r.reportKey]=true end end
 for _,r in ipairs(state.order) do
  local belongs=activity==nil
  if activity then
   for _,id in ipairs(activity.segmentIDs or {activity.id}) do if r.activityIDs[id] then belongs=true end end
  end
  local has=not guid;for _,row in pairs(r.rows) do if row.values.guid==guid then has=true;break end end
  -- Hide the per-row compatibility projection when the same report has a native whole-board manifest.
  if belongs and has and not (r.legacy and native[r.reportKey]) then out[#out+1]=r end
 end
 table.sort(out,function(a,b) return a.lastAt>b.lastAt or a.lastAt==b.lastAt and a.id>b.id end)
 return out
end
function B.Activity(st,r)
 local result
 for id in pairs(r and r.activityIDs or {}) do local a=ns.ChronicleActivities.View(st,id)
  if a then if result and result.id~=a.id then return end;result=a end
 end
 return result
end
