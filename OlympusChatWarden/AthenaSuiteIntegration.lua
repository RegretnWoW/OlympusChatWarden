-- Consume existing accepted observations and delivered chat. No new raw producer.
local _,ns=...
local R,F=ns.Athena2,ns.Fellowship
local function Candidate(e)
 if not R.Permit('intel') or not R.GUID(e.subject) then return end
 local d=e.details or {};local own=ns.OlympusConnection.Profile()
 -- Legacy guild-name admission is not official third-party membership proof.
 if not own or not own.member or not R.Text(own.guild) then return end
 local guild=d.guild or d.guildName
 if guild~=own.guild or not (e.kind=='player_observed' and d.localSighting==true or d.recordType=='guild_member_observed') then return end
 if R.Now()-e.at>15 or e.at>R.Now()+5 then return end
 local c=ns.ChronicleStore.Character(e.character,false);local p=c and c.profiles[e.subject];local facts=p and p.facts or {}
 local name=R.Text(d.name) or facts.name and R.Text(facts.name.value)
 local realm=R.Text(d.realm) or facts.realm and R.Text(facts.realm.value)
 if not name or not realm then return end
 if not F.roster[e.subject] and R.Count(F.roster)>=2000 then return end
 F.roster[e.subject]={guid=e.subject,name=name,realm=realm,level=R.Number(d.level,1,1000),class=R.Text(d.class),olympusVerified=true,
  online=e.kind=='player_observed' and d.localSighting==true or nil,at=e.at,expiresAt=e.at+600,sourceRef=e.id,proof='Native guild membership in current officially verified owner guild'}
 F.revision=F.revision+1
end
local original=ns.Athena.NativeNotice
ns.Athena.NativeNotice=function(e,status,generation)
 if original then original(e,status,generation) end
 local contextOK,contextError=pcall(F.Notice,e);if not contextOK then F.sourceErrors=(F.sourceErrors or 0)+1;F.lastContextError=tostring(contextError):sub(1,180) end
 local ok=pcall(Candidate,e);if not ok then F.sourceErrors=(F.sourceErrors or 0)+1 end
 if e.kind=='group_roster' then
  local session=ns.RelayOutreach.Current.session
  if session and not session.closed then for _,guid in ipairs(e.details.members or {}) do
   if guid==session.target.guid then ns.RelayOutreach.Current:Party({joinedGUID=guid});break end
  end end
 end
 if e.subject then ns.AthenaInsights.Notify('PLAYER_PROFILE_UPDATED',e.subject,e.id) end
end
ns.SignalCore.Subscribe('chat.displayed','chat','fellowship-delivered',function(message)
 local e=message.entry;local source=message.source or {};local outcome=e and e.captureSnapshot and e.captureSnapshot.actualAction
 if not e or source.shield or source.spam or (outcome~='Unchanged' and outcome~='Warning') then return end
 local guid=ns.Athena.ResolveContact(e.sender);if not guid then return end
 local c=F.roster[guid]
 if e.event=='CHAT_MSG_WHISPER' then
  local session=ns.RelayOutreach.Current.session
  if session and session.target.guid==guid then
   ns.RelayOutreach.Current:Reply({channel='WHISPER',guid=guid,realm=session.target.realm,id=e.captureID,at=e.timestamp,message=e.original})
  end
  return
 end
 if not c or not c.expiresAt or c.expiresAt<=R.Now() then return end
 local channel=e.event and e.event:match('^CHAT_MSG_(.+)$')
 F.Observe({delivered=true,olympusVerified=c.olympusVerified,guid=guid,name=c.name,realm=c.realm,message=e.original,channel=channel,sourceID=e.captureID})
end)
function F.Top(viewer)
 viewer=viewer or F.Context();F.Expire()
 local key=table.concat({viewer.owner or '',viewer.level or '',viewer.role or '',viewer.activityID or '',F.revision},'/')
 if F.topKey==key then return R.Copy(F.topRows) end
 local rows={};for _,ad in pairs(F.requests) do
  local candidate=F.roster[ad.guid]
  if candidate and (not candidate.expiresAt or candidate.expiresAt>R.Now()) then
   local match=F.Score(viewer,candidate,ad)
   if match.score and match.score>=70 then rows[#rows+1]={id='fellowship/'..ad.guid,guid=ad.guid,name=candidate.name,score=match.score,source=ad.source} end
  end
 end
 table.sort(rows,function(a,b) return a.score>b.score or a.score==b.score and a.guid<b.guid end)
 local used,out={},{};for _,r in ipairs(rows) do if not used[r.guid] then used[r.guid]=true;out[#out+1]=r;if #out==3 then break end end end
 F.topKey=key;F.topRows=out;return R.Copy(out)
end
function F.HomeRows(rows)
 local opportunities=F.Top();for n=#opportunities,1,-1 do local p=opportunities[n]
  table.insert(rows,1,{id=p.id,title=p.name..' · '..p.score..'% Player Match',sub='Fresh eligible request · open existing Intel dossier',group='Olympus Fellowship',icon='intel',data={page='intel',guid=p.guid,owner=R.Owner()}})
 end
 return rows
end
ns.OlympusConnection.Subscribe(function()
 if not ns.Membership.Allowed() then F.requests={};F.roster={};F.revision=F.revision+1;ns.RelayOutreach.Current:Cancel('Membership changed') end
end)
ns.AthenaInsights.Register('MATCH_COMPLETION',1,function(key,o)
 local p,status=ns.AthenaProfiles.GetEvent(key,o.owner,o.consumer);if not p then return nil,status end
 return {subjectKey=key,value=p.status,certainty='observed',coverage='Recording boundary, not a verified personal win/loss',sourceOrigin=p.sourceOrigin,evidenceRefs=ns.AthenaProfiles.Sources('event',key,o.owner,0,o.consumer) or {}}
end)
ns.AthenaInsights.Register('RECURRING_COMPANION',1,function(key,o)
 local st,status=ns.AthenaActivityIndex.Request(o.owner);if not st then return nil,status end
 local ready=ns.AthenaProfiles.Ensure(st,o.owner);local p=st.players[key]
 return {subjectKey=key,value=p and #p.activities>=3 or false,certainty='observed',coverage='Repeated listed activity contexts; attendance at each boss unknown',sourceOrigin=ready and R.Origin(st) or 'unverified_archive',evidenceRefs=ns.AthenaProfiles.Sources('player',key,o.owner,0,o.consumer) or {}}
end)
