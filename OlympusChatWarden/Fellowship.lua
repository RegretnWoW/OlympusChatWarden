-- Delivered recruitment and roster candidacy; independent of chat archiving/Aether.
local _,ns=...
local R=ns.Athena2
local F={VERSION=2,TTL=600,LIMIT=256,CONTEXT_TTL=1800,requests={},roster={},revision=0,seen=0};ns.Fellowship=F
local aliases={{'deadmines',36},{' vc ',36},{'stockades',34},{'stocks',34},{'sm cath',189},{'molten core',409},{'wailing caverns',43}}
local function Words(s) return type(s)=='string' and (' '..s:lower():gsub('[^%w%s]',' '):gsub('%s+',' '):match('^%s*(.-)%s*$')..' ') or '' end
local function ExpireContext()
 for id,q in pairs(F.activeQuests or {}) do if R.Now()-q.at>F.CONTEXT_TTL then F.activeQuests[id]=nil;F.revision=F.revision+1 end end
end
-- Reuse fresh, accepted quest observations. This is a transient local context,
-- not a second quest collector, archive or declaration of another player's log.
function F.Notice(e)
 if not R.Permit('intel') or type(e)~='table' or e.character~=R.Owner() or type(e.at)~='number' or R.Now()-e.at>15 or e.at>R.Now()+5 then return false end
 local d=e.details or {};local kind=e.kind=='native_event' and d.recordType or e.kind
 if not ({quest_accepted=true,quest_observed=true,quest_objective=true,quest_turnin=true,quest_removed=true})[kind] then return false end
 local id=R.Number(d.questID,1,10000000);if not id or id%1~=0 then return false end
 if F.contextOwner~=e.character then F.contextOwner=e.character;F.activeQuests={} end
 ExpireContext()
 local quests=F.activeQuests
 if kind=='quest_turnin' or kind=='quest_removed' then quests[id]=nil;F.revision=F.revision+1;return true end
 if not quests[id] and R.Count(quests)>=100 then return false end
 local previous=quests[id];local title=kind~='quest_objective' and R.Text(d.title,256) or previous and previous.title
 if not title then local row=ns.AthenaQuestData and ns.AthenaQuestData.quests[id];title=type(row)=='string' and row:match('^[^\031]+') or nil end
 local related={};local members=ns.AthenaQuestChains and ns.AthenaQuestChains.Members(id) or {}
 for n,other in ipairs(members) do if n>128 then break end;if other~=id then related[other]=true end end
 quests[id]={title=title,words=Words(title),at=e.at,sourceRef=e.id,related=related}
 F.revision=F.revision+1;return true
end
function F.Context()
 ExpireContext()
 local owner=R.Owner();local guid=owner and owner:match('/(Player%-.+)$')
 local p=guid and ns.AthenaProfiles.GetPlayer(guid,owner,'intel')
 local objectives,chains={},{}
 if F.contextOwner==owner then for id,q in pairs(F.activeQuests or {}) do
  if R.Now()-q.at<=F.CONTEXT_TTL then objectives[id]=true;for other in pairs(q.related) do chains[other]=true end end
 end end
 return {owner=owner,level=p and p.identity.level,faction=p and p.identity.faction,role=F.preferredRole,activityID=F.activityID,objectives=objectives,questChains=chains}
end
function F.Parse(message)
 if not R.Read(message) or type(message)~='string' or #message>512 or #message==0 or message:find('[%z\1-\31\127]') then return end
 local text=' '..message:lower()..' '
 for _,bad in ipairs({'wtb','wts','boost','carry','selling','gold per'}) do if text:find(bad,1,true) then return end end
 local intent=text:find('%f[%w]lf%d*m%f[%W]') and 'LFM' or text:find('%f[%w]lfg%f[%W]') and 'LFG' or text:find('%f[%w]need help%f[%W]') and 'QUEST_HELP'
 if not intent then return end
 local activity;for _,a in ipairs(aliases) do if text:find(a[1],1,true) then activity=a[2];break end end
 local role=text:find('heal',1,true) and 'HEALER' or text:find('tank',1,true) and 'TANK' or text:find('dps',1,true) and 'DAMAGER'
 local quest=tonumber(text:match('quest:(%d+)'))
 local named=false
 if not quest and F.contextOwner==R.Owner() then
  local words=Words(message)
  for id,q in pairs(F.activeQuests or {}) do if R.Now()-q.at<=F.CONTEXT_TTL and #q.words>=10 and words:find(q.words,1,true) then
   if quest then quest=nil;named=false;break end -- ambiguous names do not pick a step
   quest=id;named=true
  end end
 end
 return {intent=intent,activityID=activity,role=role,questID=quest,questResolution=named and 'local_title' or quest and 'quest_link',confidence=(activity or quest) and 'resolved' or 'general',full=text:find('%f[%a]full%f[%A]')~=nil}
end
function F.Observe(e)
 if not R.Permit('chat') or type(e)~='table' or not e.delivered or e.suppressed or e.blocked or not e.olympusVerified or not R.GUID(e.guid) or not R.Text(e.realm) then return false end
 if not ({GUILD=true,CHANNEL=true,SAY=true,YELL=true,PARTY=true,RAID=true})[e.channel] then return false end
 local p=F.Parse(e.message);if not p then return false end
 if p.full then for key,ad in pairs(F.requests) do if ad.guid==e.guid and (not p.activityID or ad.activityID==p.activityID) then F.requests[key]=nil end end;F.revision=F.revision+1;return true end
 local key=e.guid..'/'..(p.activityID or p.questID or 'general')..'/'..p.intent
 if not F.requests[key] and R.Count(F.requests)>=F.LIMIT then F.Expire();if R.Count(F.requests)>=F.LIMIT then return false end end
 p.guid=e.guid;p.realm=e.realm;p.name=R.Text(e.name);p.sourceID=R.Text(e.sourceID,256);p.source='CHAT_DELIVERED';p.channel=e.channel;p.at=R.Now();p.expiresAt=p.at+F.TTL;p.olympusVerified=true
 F.requests[key]=p;F.revision=F.revision+1;F.seen=F.seen+1;return true
end
function F.Expire()
 local now=R.Now();for key,p in pairs(F.requests) do if p.expiresAt<=now then F.requests[key]=nil;F.revision=F.revision+1 end end
 for key,p in pairs(F.roster) do if p.expiresAt and p.expiresAt<=now then F.roster[key]=nil;F.revision=F.revision+1 end end
 ExpireContext()
end
function F.Score(viewer,candidate,ad,now)
 now=now or R.Now();local out={kind='PLAYER_COMPATIBILITY',algorithm=1,state='Unknown',reasons={},contributions={},source='local',score=nil}
 if not candidate or not candidate.olympusVerified or not R.GUID(candidate.guid) then return out end
 if candidate.faction and viewer.faction and candidate.faction~=viewer.faction then out.state='Ineligible';out.blocker='Faction';return out end
 if ad and ad.expiresAt<=now then ad=nil end
 local score=0;local explicit=ad~=nil;local exact=false
 local function add(points,reason) score=score+points;out.reasons[#out.reasons+1]=reason;out.contributions[#out.contributions+1]={points=points,reason=reason} end
 if ad then add(35,'Fresh declared '..ad.intent)
  exact=viewer.activityID and viewer.activityID==ad.activityID or ad.questID and viewer.objectives and viewer.objectives[ad.questID]
  if exact then add(30,'Exact advertised activity') end
  if not exact and ad.questID and viewer.questChains and viewer.questChains[ad.questID] then add(15,'Related source-backed quest chain; active step unconfirmed') end
  if ad.role and viewer.role==ad.role then add(10,'Declared role fit') end
 end
 if candidate.level and viewer.level and math.abs(candidate.level-viewer.level)<=5 then add(10,'Similar progression') end
 if candidate.online or ad then add(10,candidate.online and 'Online in the eligible roster' or 'Recently active request') end
 if candidate.familiar==true then add(5,'Recorded familiar companion') end
 if not explicit and not candidate.online then return out end
 out.state=explicit and 'Active request' or 'Possible companion (unconfirmed)'
 out.score=math.min(score,not explicit and 45 or not exact and 70 or 100);out.explicitInterest=explicit;return out
end
function F.GetPlayerMatch(guid,viewer)
 if not R.Permit('intel') then return nil,'DENIED' end;F.Expire();local candidate=F.roster[guid]
 if not candidate then return {state='Unknown',reasons={},kind='PLAYER_COMPATIBILITY'} end
 local best
 for _,ad in pairs(F.requests) do if ad.guid==guid then local s=F.Score(viewer or F.Context(),candidate,ad);if not best or (s.score or -1)>(best.score or -1) then best=s end end end
 return best or F.Score(viewer or F.Context(),candidate)
end
ns.AthenaMatch={VERSION=1,Score=F.Score,Get=F.GetPlayerMatch}
ns.AthenaInsights.Register('PLAYER_COMPATIBILITY',1,function(key,o) return F.GetPlayerMatch(key,o.viewer) end)
