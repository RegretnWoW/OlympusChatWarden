-- Shared, ephemeral interpretation of accepted adventure evidence. The UI and
-- Metis use these facts; this service never collects, shares or grants a clear.
local _,ns=...
local S={VERSION=1,cache=setmetatable({},{__mode='k'})};ns.AthenaAdventureSummary=S
function S.Encounters(a,state)
 local result,byKey={},{}
 for index,t in ipairs(a.attempts or {}) do
  local key=t.encounterID and 'id/'..t.encounterID or t.name and 'name/'..t.name or 'attempt/'..index
  key=key..'/'..tostring(t.difficultyID or a.context and a.context.difficultyID or 'unknown')
  local row=byKey[key]
  if not row then row={key=key,title=t.name or 'Unidentified encounter',encounterID=t.encounterID,difficultyID=t.difficultyID,firstAt=t.startAt,lastAt=t.endAt or t.startAt,state=state,attempts={},victories=0,defeats=0,unresolved=0};byKey[key]=row;result[#result+1]=row end
  row.attempts[#row.attempts+1]=t
  row.firstAt=math.min(row.firstAt or t.startAt or 0,t.startAt or row.firstAt or 0);row.lastAt=math.max(row.lastAt or 0,t.endAt or t.startAt or 0)
  if t.outcome=='success' or t.outcome=='native boss kill' then row.victories=row.victories+1
  elseif t.outcome=='failure' or t.outcome=='failed' or t.outcome=='wipe' then row.defeats=row.defeats+1
  else row.unresolved=row.unresolved+1 end
  row.lastOutcome=t.outcome;row.interruption=row.interruption or t.interruption
 end
 return result
end
function S.Combat(observations)
 local result={windows={},overlap=false,recoveryObserved=false};local byWindow={}
 for _,row in ipairs(observations or {}) do local d=row.value or row.details or row
  if ns.AthenaAdventureEvidence.Valid(d) then local old=byWindow[d.windowRef]
   if not old or d.revision>old.value.revision then byWindow[d.windowRef]={value=d,ref=row.evidenceRef or row._ref or row.ref,claim=row.claim or row.claimType and row} end
  end
 end
 for _,row in pairs(byWindow) do result.windows[#result.windows+1]=row end
 table.sort(result.windows,function(a,b) return a.value.firstAt<b.value.firstAt or a.value.firstAt==b.value.firstAt and a.value.windowRef<b.value.windowRef end)
 local lastAt
 for _,row in ipairs(result.windows) do local d=row.value
  if lastAt and d.firstAt<lastAt then result.overlap=true end;lastAt=math.max(lastAt or 0,d.lastAt)
  if d.minHealthPercent and (result.minimum==nil or d.minHealthPercent<result.minimum) then result.minimum=d.minHealthPercent end
  if d.lowHealthObserved then
   local score=120-(d.minHealthPercent or 20)+(d.recoveryObserved and .1 or 0)
   if not result.closeCall or score>result.closeCall.score then result.closeCall={score=score,value=d,ref=row.ref,claim=row.claim} end
  end
 end
 -- Recovery belongs to the selected low-health window. A later, unrelated
 -- healthy sample must never turn an unresolved close call into a recovery.
 result.recoveryObserved=result.closeCall and result.closeCall.value.recoveryObserved==true or false
 return result
end
function S.Compose(a,observations,quests,rewards,actor)
 local out={activityKey=a.id,encounters=S.Encounters(a),combat=S.Combat(observations),attemptCount=#(a.attempts or {}),questCount=quests or 0,rewardCount=rewards or 0,fullClearVerified=false}
 local text={}
 for n,boss in ipairs(out.encounters) do if n<=3 then
  if boss.defeats>0 and (boss.lastOutcome=='success' or boss.lastOutcome=='native boss kill') then text[#text+1]='An unsuccessful attempt against '..boss.title..' was followed by victory.'
  elseif boss.victories>0 then text[#text+1]=boss.title..' was defeated during the expedition.'
  elseif boss.defeats>0 then text[#text+1]='The expedition confronted '..boss.title..' without a recorded victory.' end
 end end
 local close=out.combat.closeCall
 if close then text[#text+1]=(actor or 'The observing character')..'’s health fell to '..close.value.minHealthPercent..'%'..(out.combat.recoveryObserved and ', followed by recovery.' or '.') end
 if out.questCount>0 and out.rewardCount>0 then text[#text+1]='Quest progress and a reward were also observed.'
 elseif out.questCount>0 then text[#text+1]='Related quest progress was observed.'
 elseif out.rewardCount>0 then text[#text+1]='A reward was observed.' end
 out.text=table.concat(text,' ');out.brief=text[1] or '';out.summary=table.concat(text,' ',1,math.min(2,#text));out.story=out.text
 if out.attemptCount>0 then out.story=out.story..' '..out.attemptCount..' encounter attempt'..(out.attemptCount==1 and ' was' or 's were')..' recorded in this expedition.' end
 return out
end
function S.Get(st,a)
 local bucket=S.cache[st];if not bucket then bucket={entries={},order={}};S.cache[st]=bucket end
 local revision=ns.ChronicleBackup.Encode({attempts=a.attempts or {},evidence=a.evidence or {},lastAt=a.lastAt,status=a.status});local cached=bucket.entries[a.id]
 if cached and cached.revision==revision then return cached.value end
 local observations,quests,rewards={}, {},0;local own=st.owner:match('/(Player%-.+)$')
 for index,ref in ipairs(a.evidence or {}) do local e=st.events[ref];if e then local d=e.details or {};local k=d.recordType or e.kind
  if k=='adventure_combat_summary' and ns.AthenaAdventureEvidence.ValidRecord(e,st.owner) then observations[#observations+1]={details=d,ref=e.id} end
  if (k=='quest_accepted' or k=='quest_objective' or k=='quest_turnin') and d.questID then quests[d.questOccurrenceRef or d.questID]=true end
  if k=='item_received' or k=='quest_item_received' or k=='encounter_loot_delivery' then rewards=rewards+1 end
 end;if index%64==0 then coroutine.yield() end end
 local n=0;for _ in pairs(quests) do n=n+1 end
 local character=ns.ChronicleStore.Character(st.owner,false);local profile=character and character.profiles[own]
 local actor=not st.asOf and profile and profile.facts and profile.facts.name and profile.facts.name.value
 local value=S.Compose(a,observations,n,rewards,actor)
 if not cached then bucket.order[#bucket.order+1]=a.id end;bucket.entries[a.id]={revision=revision,value=value}
 while #bucket.order>32 do bucket.entries[table.remove(bucket.order,1)]=nil end
 return value
end
function S.FromClaims(story)
 local a={id=story.storyId,context=story.node and story.node.place or {},attempts={}};local windows,quests,rewards={}, {},0
 for _,c in ipairs(story.factualClaims or {}) do local d=c.value
  if c.claimType=='encounter_attempt' then a.attempts[#a.attempts+1]={encounterID=d.boss,name=d.name,startAt=d.at,outcome=({SUCCESS='success',FAILURE='failure'})[d.outcome] or 'unknown'}
  elseif c.claimType=='owner_combat_experience' then windows[#windows+1]=c
  elseif c.claimType:match('^owner_quest_') and type(d)=='table' and d.questID then quests[d.questID]=true
  elseif c.claimType=='owner_item_receipt' then rewards=rewards+1 end
 end
 local n=0;for _ in pairs(quests) do n=n+1 end
 return S.Compose(a,windows,n,rewards,story.characterName)
end
function S.ChooseExperience(claims)
 local combat=S.Combat(claims);local chosen,score
 for _,window in ipairs(combat.windows) do local d=window.value
  local weight=(d.deaths or 0)>0 and 200 or d.lowHealthObserved and 120-(d.minHealthPercent or 20) or 0
  if weight>0 and (not score or weight>score) then chosen=window.claim;score=weight end
 end
 return chosen
end

-- Shared claims use the same fact-summary boundary; they do not become the
-- observer's Metis history. Opinions never enter these factual tiers.
function S.Shared(event)
 local outcome=({final_encounter_won='The final encounter was reported won.',full_clear='An authorized complete-event result was reported.',partial='The event was reported as partial.',unknown='The outcome remains unknown.'})[event.outcome] or 'The reported outcome conflicts.'
 local text='Authorized contributors reported '..(event.name or 'this event')..'. '..outcome..' Encounters, rewards and unshared participants remain unknown.'
 return {activityKey=event.key,text=text,brief=outcome,summary=text,story=text,sourceClass='authorized_shared',coverage=event.scope}
end
