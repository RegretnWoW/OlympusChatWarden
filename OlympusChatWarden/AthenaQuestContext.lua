-- Individual quest-source circumstances, not claims about the character.
-- Built on demand from every profile; no selected-quest fallback vocabulary.
local _,ns=...
local Q={VERSION='quest-context-1.6'};ns.AthenaQuestContext=Q
local imperatives={bring=true,kill=true,slay=true,defeat=true,go=true,travel=true,take=true,collect=true,gather=true,find=true,
 search=true,explore=true,report=true,['return']=true,seek=true,speak=true,talk=true,meet=true,use=true,escort=true,steal=true,
 deliver=true,recover=true,obtain=true,venture=true,journey=true,help=true,look=true,['break']=true,let=true,waste=true,watch=true}
local function Has(text,word) return text:find('%f[%a]'..word..'%f[%A]')~=nil end
local function Contains(text,words)
 for _,w in ipairs(words) do if text:find(w,1,true) then return true end end
end
local function Personal(text)
 for _,w in ipairs({'you','your','yours','we','our','ours','us','i','me','my'}) do if Has(text,w) then return true end end
 if text:find('is mine',1,true) or text:find('was mine',1,true) then return true end
end
local Score
local function Normalize(atom,ref)
 local text=atom.text
 if type(text)~='string' or #text<24 or #text>330 or text:find('[<>|]') or text:find('%[') then return end
 text=text:gsub('’',"'"):gsub('^[Rr]ecently,%s*',''):gsub('^[Nn]ow,%s*','')
 text=text:gsub('^[Tt]he adventurer,%s*','')
 if text:find('the adventurer',1,true) then return end
 local lower=text:lower();local first=lower:match('^(%a+)')
 if imperatives[first] or Contains(lower,{'thanks to you','your previous','you have','you are','you did','you brought','you killed','reward','for your time'}) then return end
 if atom.modality~='SOURCE_STATEMENT' then return end -- Questions, plans and conditions stay in their own source fields.
 local speaker=ref.giverName
 if speaker and (not atom.speakerNPCID or ref.giverIDs and atom.speakerNPCID==ref.giverIDs[1]) then
  text=text:gsub('^[Mm]y scouts tell me that ',speaker..'’s scouts reported that ')
  text=text:gsub('^I need you to ',speaker..' needed someone to '):gsub('^I want you to ',speaker..' wanted someone to ')
  text=text:gsub('^We need you to ',speaker..' needed someone to '):gsub('^We need to ',speaker..' needed to ')
  text=text:gsub('^I wonder what ',speaker..' wondered what ')
  text=text:gsub(' than we had thought',' than expected')
  text=text:gsub("%f[%a]I'm%f[%A]",speaker..' was'):gsub("%f[%a]I've%f[%A]",speaker..' had')
  text=text:gsub('%f[%a]I am%f[%A]',speaker..' was'):gsub('%f[%a]I have%f[%A]',speaker..' had')
  text=text:gsub('%f[%a]I need%f[%A]',speaker..' needed'):gsub('%f[%a]I want%f[%A]',speaker..' wanted')
  text=text:gsub('%f[%a]I hope%f[%A]',speaker..' hoped'):gsub('%f[%a]I fear%f[%A]',speaker..' feared')
  text=text:gsub('%f[%a][Mm]y%f[%A]',speaker..'’s')
 end
 lower=text:lower()
 if Personal(lower) or Has(lower,'therefore') and first=='therefore' then return end
 if ({he=true,she=true,his=true,her=true,they=true,their=true,it=true,its=true,this=true,that=true,those=true,these=true,
  which=true,who=true,because=true,well=true,but=true,['and']=true,so=true})[first] then return end
 text=text:gsub(' has camped ',' had camped '):gsub(' has become ',' had become '):gsub(' has taken ',' had taken ')
 text=text:gsub(' has been ',' had been '):gsub(' have been ',' had been '):gsub(' have infested ',' had infested ')
 text=text:gsub(' is ',' was '):gsub(' are ',' were '):gsub(' threatens ',' threatened '):gsub(' needs ',' needed ')
 text=text:gsub('^%l',string.upper)
 return text
end
-- A source summary is reference material. Only the author's separately proven
-- turn-in may turn its instruction into a completed action. Do not guess from
-- labels, objective counts, neighbouring quests or a manually revealed ending.
local gerunds={Bring='bringing',Deliver='delivering',Take='taking',Collect='collecting',Gather='gathering',Recover='recovering',
 Retrieve='retrieving',Obtain='obtaining',Acquire='acquiring',Find='finding',Kill='confronting',Slay='confronting',Defeat='confronting',
 Destroy='destroying',Speak='speaking',Talk='talking',Report='reporting',Return='returning',Travel='traveling',Search='searching',
 Explore='exploring',Investigate='investigating',Escort='escorting',Use='using',Read='reading',Give='giving',Seek='seeking',
 Locate='locating',Visit='visiting',Enter='entering',Protect='protecting',Defend='defending',Free='freeing',Capture='capturing',
 Examine='examining',Follow='following',Learn='learning',Meet='meeting',Help='helping',Cleanse='cleansing',Win='winning',
 Check='checking',See='finding out',Ensure='ensuring',Consume='drinking',Climb='climbing',Summon='summoning',
 Place='placing',Speak='speaking',Offer='offering',Complete='completing',Accept='accepting',Light='lighting',Show='showing',
 Collect='collecting',Gather='gathering',Destroy='destroying',Investigate='investigating',Perform='performing',
 Trade='trading',Repair='repairing',Donate='donating',Pay='paying'}
function Q.Purpose(ref)
 local text=ref and ref.premise
 -- Some exchanges only state their instructions in progress dialogue. Their
 -- authored objective is usable only with the exact, permitted source atoms;
 -- it must never manufacture a stage-two acceptance scene.
 if ref and (type(text)~='string' or text=='' or text:lower()=='null' or text=='UNKNOWN') then
  local card=ref.storyContext or Q.Build(ref);local edited=card and card.editorial
  if edited and edited.sourceHash==ref.sourceHash and type(edited.objectiveSummary)=='string' then
   local seen={};for _,a in ipairs(ref.narrative and ref.narrative.atoms or {}) do seen[a.id]=true end
   local valid=true;for _,id in ipairs(edited.atomIDs or {}) do if not seen[id] then valid=false end end
   if valid then text=edited.objectiveSummary end
  end
 end
 if type(text)~='string' or #text<8 or #text>700 or text:find('[<>|%[%]]') then return end
 text=text:match('^.- wants you to (.+)$') or text:match('^.- asks you to (.+)$') or text:match('^.- has commissioned you to (.+)$') or text
 text=text:gsub('^%l',string.upper)
 -- Conditional/alternative instructions are not a single fulfilled deed.
 local lower=text:lower()
 if Contains(lower,{'you may','either ',' or you ','if ','should you ','null','unknown','the adventurer'}) then return end
 local first=text:match('^(%a+)');if not gerunds[first] then return end
 text=text:gsub('[%.%s]+$','')
 for verb,gerund in pairs(gerunds) do
  text=text:gsub('^'..verb..'%f[%A]',gerund)
  text=text:gsub('([%.!]%s*)'..verb..'%f[%A]',function() return '; '..gerund end)
  text=text:gsub('then '..verb:lower()..'%f[%A]','then '..gerund):gsub('and '..verb:lower()..'%f[%A]','and '..gerund)
 end
 -- Remaining second-person instructions cannot safely be recast this way.
 if Personal(text:lower()) then return end
 return text
end
local function EndingStatement(text)
 local lower=text:lower();local first=lower:match('^(%a+)')
 if lower:find("let's",1,true) or lower:find('let’s',1,true) or lower:find('let us ',1,true) then return false end
 -- A finisher may give the next instruction at hand-in. That is a new
 -- request, not the consequence of the deed just completed. Preserve it in
 -- the source account without repeating it as the old episode's ending.
 if imperatives[first] or Contains(lower,{'i need you','i want you','we need you','you must','you should','you can','so he can','so she can','so they can'}) then return false end
 return true
end
function Q.Aftermath(ref)
 if not ref or not ref.narrative then return end
 local card=ref.storyContext or Q.Build(ref);local edited=card and card.editorial
 if edited and edited.aftermath and edited.endingAtomIDs then
  local seen={};for _,a in ipairs(ref.narrative.atoms) do seen[a.id]=true end
  local valid=true;for _,id in ipairs(edited.endingAtomIDs) do if not seen[id] then valid=false end end
  if valid then return edited.aftermath,edited.endingAtomIDs end
 end
 local candidates={}
 -- The finisher speaks at the hand-in, and can differ from the original giver.
 local speaker=ref.finisherName or ref.giverName
 for index,atom in ipairs(ref.narrative.atoms or {}) do
  if atom.field=='completion' and atom.minimumStage==4 and atom.modality=='SOURCE_STATEMENT' and EndingStatement(atom.text) then
   local text=Normalize(atom,{giverName=speaker,giverIDs=ref.finisherIDs})
   if text and Score(atom,text)>=4 and not Contains(text:lower(),{'thank','impressive','well done','proud','brave','reward','now that','with this','with these'}) then
    candidates[#candidates+1]={text=text,atomID=atom.id,score=Score(atom,text),index=index}
   end
  end
 end
 table.sort(candidates,function(a,b) return a.score>b.score or a.score==b.score and a.index<b.index end)
 local row=candidates[1];if row then return row.text,{row.atomID} end
end
-- First-person motives are often the heart of a quest. Preserve the speaker's
-- actual account rather than discarding it or guessing a third-person motive.
-- No dialogue encounter is claimed; this is the quest's source voice.
function Q.Account(ref,field)
 if not ref or not ref.narrative then return end
 local rows={}
 for index,a in ipairs(ref.narrative.atoms or {}) do
  if a.field==field and type(a.text)=='string' and #a.text>=16 and #a.text<=520
   and not a.text:find('[<>|%[%]]') and not Contains(a.text:lower(),{'the adventurer','reward','thanks to you','thank you','well done'}) then
   local score=Score(a,a.text)
   if field=='description' and (a.minimumStage or 99)<=2 or field=='requestItems' and (a.minimumStage or 99)<=3 or field=='completion' and a.minimumStage==4 then
    rows[#rows+1]={atom=a,index=index,score=score}
   end
  end
 end
 table.sort(rows,function(a,b) return a.score>b.score or a.score==b.score and a.index<b.index end)
 local chosen=rows[1];if not chosen then return end
 local speaker=field=='completion' and (ref.finisherName or ref.giverName) or ref.giverName
 local text=chosen.atom.text
 local subject=speaker and speaker..'’s account' or 'The account'
 local lead=field=='completion' and ' ended with these words: “' or ' put the matter plainly: “'
 return subject..lead..text..'”',{chosen.atom.id},chosen.score
end
function Q.ObjectiveAccount(ref)
 if not ref or not ref.narrative then return end
 local texts,ids={},{}
 for _,a in ipairs(ref.narrative.atoms or {}) do if a.field=='objective' and (a.minimumStage or 99)<=2 and #a.text>=8
  and not a.text:find('[<>|%[%]]') and not a.text:lower():find('the adventurer',1,true) then texts[#texts+1]=a.text;ids[#ids+1]=a.id end end
 if #texts>0 then return table.concat(texts,' '),ids end
end
function Q.Summary(ref)
 if not ref then return end
 local problem,why=Q.Opening(ref);local aftermath,ending=Q.Aftermath(ref)
 local reply,replyIDs=Q.Account(ref,'completion')
 local purpose=Q.Purpose(ref);local objective,objectiveIDs=Q.ObjectiveAccount(ref)
 local subject=ref.subject or ns.AthenaQuestSubjects.Build(ref)
 local card=ref.storyContext or Q.Build(ref)
 return {version=Q.VERSION,questID=ref.questID or ref.id,worldRef=ref.worldRef,sourceHash=ref.sourceHash,
  problem=problem,problemAtomIDs=why or {},purpose=purpose,objectiveAccount=objective,objectiveAtomIDs=objectiveIDs or {},subject=subject,aftermath=aftermath,aftermathAtomIDs=ending or {},sourceReplyAccount=reply,sourceReplyAtomIDs=replyIDs or {},
  status=problem and (purpose or subject or objective) and 'CONTEXT_AND_OBJECTIVE' or (purpose or subject or objective) and 'OBJECTIVE_ONLY' or problem and 'CONTEXT_ONLY' or (aftermath or reply) and 'ENDING_ONLY' or 'UNKNOWN',
  reasonStatus=card and card.reasonStatus or 'UNKNOWN',outcomeStatus=aftermath and 'SOURCE_REPLY_AVAILABLE' or 'UNKNOWN',
  truthScope='QUEST_SOURCE_ACCOUNT',personalCompletionProven=false}
end
Score=function(atom,text)
 local score=0;local lower=text:lower()
 for _,category in ipairs(atom.categories or {}) do
  if category=='motivations' then score=score+5 elseif category=='conflict' then score=score+5 elseif category=='stakes' then score=score+4 end
 end
 if Contains(lower,{'because','so that','in order to','threat','infest','stole','stolen','danger','foothold','short on','protect','missing','disappear','overrun','depleted','too large','plague','terror','attacks','suffer','corrupt','driving','fled','starv','destroy'}) then score=score+5 end
 if Contains(lower,{'need supplies','need the supplies','task left','good luck','greetings','prize-winning'}) then score=score-8 end
 return score
end
function Q.Build(ref)
 if not ref or not ref.narrative then return end
 local fields=ref.narrative.fields or {}
 local out={version=Q.VERSION,questID=ref.questID or ref.id,worldRef=ref.worldRef,sourceURL=ref.sourceURL,
  characters=ref.narrative.characters or {},relationships=ref.narrative.relationships or {},
  reasons={},circumstances={},objectives=fields.objectives or {},
  motivations=fields.motivations or {},conflicts=fields.conflict or {},
  stakes=fields.stakes or {},conclusions=fields.conclusion or {},
  truthScope='QUEST_SOURCE_ACCOUNT',personalOutcomeProven=false}
 for index,atom in ipairs(ref.narrative.atoms or {}) do
  if (atom.minimumStage or 999)<=2 and atom.field=='description' then
   local text=Normalize(atom,ref)
   if text then
    local row={text=text,atomID=atom.id,sourceProof=atom.sourceProof,sourceURL=ref.sourceURL,index=index,score=Score(atom,text)}
    out.circumstances[#out.circumstances+1]=row
    if row.score>=5 then out.reasons[#out.reasons+1]=row end
   end
  end
 end
 table.sort(out.reasons,function(a,b) return a.score>b.score or a.score==b.score and a.index<b.index end)
 -- Edited passages are useful only for the exact source they were reviewed
 -- against. Every supporting atom must be present in this permitted stage.
 local edited=ns.AthenaQuestContextData and ns.AthenaQuestContextData[out.questID]
 local sameEdit=edited and (not ref.overrideRevision and not edited.baseOverrideRevision
  or ref.overrideRevision==edited.baseOverrideRevision and ref.setup==edited.baseOverrideSetup)
 if edited and sameEdit and edited.sourceHash==ref.sourceHash then
  local seen={};for _,atom in ipairs(ref.narrative.atoms or {}) do seen[atom.id]=true end
  local valid=true;for _,id in ipairs(edited.atomIDs) do if not seen[id] then valid=false end end
  if valid then out.editorial=edited end
 end
 out.reasonStatus=(out.editorial or #out.reasons>0) and 'SUPPORTED_SOURCE_CONTEXT' or 'UNKNOWN'
 out.circumstanceStatus=(out.editorial or #out.circumstances>0) and 'SUPPORTED_SOURCE_CONTEXT' or 'UNKNOWN'
 return out
end
function Q.Opening(ref)
 local card=ref and (ref.storyContext or Q.Build(ref));if not card then return end
 if card.editorial then return card.editorial.opening,card.editorial.atomIDs end
 if #card.reasons==0 then local account,ids,score=Q.Account(ref,'description');if account and score>=5 then return account,ids end end
 local best=card.reasons[1] or card.circumstances[1]
 if not best then
  local account,ids=Q.Account(ref,'description');if account then return account,ids end
  return Q.Account(ref,'requestItems')
 end
 local chosen={best};local prior=card.circumstances
 -- Keep a defining sentence immediately before a danger when it supplies the
 -- proper name. Never attach pronoun-only text to an unrelated source excerpt.
 for _,row in ipairs(prior) do if row.index==best.index-1 and row.score>=0 and #row.text+#best.text<400 then table.insert(chosen,1,row);break end end
 table.sort(chosen,function(a,b) return a.index<b.index end)
 local texts,atoms={},{}
 for _,row in ipairs(chosen) do texts[#texts+1]=row.text;atoms[#atoms+1]=row.atomID end
 return table.concat(texts,' '),atoms
end
function Q.Action(ref,done,actor)
 local card=ref and (ref.storyContext or Q.Build(ref));local edited=card and card.editorial
 local text=edited and edited[done and 'result' or 'pending']
 if text then return (text:gsub('{actor}',function() return actor end)) end
end
function Q.Mandate(ref,done,actor)
 local purpose=Q.Purpose(ref)
 if not purpose then
  local objective=Q.ObjectiveAccount(ref)
  if objective and objective~=ref.title then return 'The charge was explicit: “'..objective..'”'..(done and (' '..actor..' had seen that task through.') or '') end
  return
 end
 local giver=ref.giverName
 if done then return actor..' had fulfilled '..(giver and giver..'’s charge' or 'the charge')..': '..purpose..'.' end
 return (giver and giver..'’s charge concerned ' or 'The task ahead concerned ')..purpose..'.'
end
function Q.Bridge(ref,connection)
 local card=ref and (ref.storyContext or Q.Build(ref));local edited=card and card.editorial
 if edited and edited.bridge and connection and connection.value.previousID==edited.bridgeFrom then return edited.bridge,edited.bridgeReplacesSetup==true end
end
function Q.ExpeditionTarget(ref,place)
 if not ref or not place or not place.instanceID then return end
 -- Match an explicit quest objective to a verified finishing encounter on the
 -- observed native map. A general mention of a place cannot bind an errand.
 local subject=ref.subject or ns.AthenaQuestSubjects.Build(ref)
 if not subject or subject.kind~='CONFLICT' and subject.kind~='COMPOUND' then return end
 local objective=(subject.target or subject.subject or ''):lower()
 for _,endpoint in ipairs(ns.ChronicleRunEndpoints or {}) do
  if endpoint.mapID==place.instanceID and objective:find(endpoint.name:lower(),1,true) then return endpoint.name end
 end
end
