-- The Director grants scene scope; forms can never grant evidence or outcomes.
local _,ns=...
local D=ns.MetisCalliopeData
local C={VERSION=D.version};ns.Metis.Calliope=C
local numbers={'one','two','three','four','five','six','seven','eight','nine','ten','eleven','twelve'}
function C.Number(n) return numbers[n] or tostring(n) end
function C.Count(n,singular,plural) return C.Number(n)..' '..(n==1 and singular or plural or singular..'s') end
function C.Choose(scene,choices,salt)
 local owner=scene.story and scene.story.observerOwner or ''
 local edition=ns.DB and ns.DB.journalEditions and ns.DB.journalEditions[owner] or 0
 local key=D.version..'/'..owner..'/'..tostring(scene.sceneId)..'/'..tostring(salt or '')
 local hash=0;for i=1,#key do hash=(hash*33+key:byte(i))%2147483647 end
 return choices[(hash+edition)%#choices+1]
end
function C.Prepare(plan)
 local chapters={}
 for i,scene in ipairs(plan.novelScenes or {}) do
  local key=scene.chapterId or scene.sceneId
  chapters[key]=chapters[key] or {used={},last={},cast={}}
  scene.calliope={state=chapters[key],position=i}
 end
 plan.calliopeVersion=C.VERSION
end
local function safe(v) return type(v)=='string' and #v>0 and #v<=200 and not v:find('[{}|]') and not v:find('%c') end
function C.Render(kind,scene,claims)
 local recipe=D.recipes[kind];local c=type(claims)=='table' and claims[1]
 if not recipe or not c or c.claimType~=recipe.claimType or type(c.claimId)~='string'
  or type(c.evidenceRefs)~='table' or #c.evidenceRefs==0 then return nil,'PROOF_REQUIRED' end
 local values={actor=scene.story and scene.story.characterName};local v=c.value
 if kind=='recurring' then values.name=type(v)=='table' and v.name
 elseif kind=='return_place' then values.place=(scene.place or scene.story.node.place or {}).zone
 elseif kind=='close_call' or kind=='recovery' then
  if type(v)~='table' or (v.deaths or 0)>0 then return nil,'CLAIM_SEMANTICS' end
  if kind=='recovery' and v.recoveryObserved~=true then return nil,'RECOVERY_NOT_OBSERVED' end
  -- ChooseExperience is the sole significance gate; this function does not
  -- independently reinterpret normal combat samples as a close call.
  if ns.AthenaAdventureSummary.ChooseExperience(claims)~=c then return nil,'SIGNIFICANCE_REQUIRED' end
 end
 local scope=scene.calliope;local state=scope and scope.state
 local cast=kind=='recurring' and tostring(type(v)=='table' and (v.guid or v.name))
 if state and ((state.used[kind] or 0)>=recipe.limit or state.last[kind] and scope.position-state.last[kind]<recipe.gap or cast and state.cast[cast]) then return nil,'PACING_BUDGET' end
 local template=C.Choose(scene,recipe.forms,kind);local valid=true
 local text=template:gsub('{(%w+)}',function(key) local value=values[key];if not safe(value) then valid=false;return '' end;return value end)
 if not valid then return nil,'PARAMETER_REQUIRED' end
 if state then state.used[kind]=(state.used[kind] or 0)+1;state.last[kind]=scope.position;if cast then state.cast[cast]=true end end
 return {text=text,claims=claims,assertionStrength='DIRECT',recipeId=C.VERSION..'/'..kind}
end
function C.Language(text)
 local notes={}
 if text:find('%f[%w]one members%f[%W]') or text:find('%f[%w]one participants%f[%W]') then notes[#notes+1]='NUMBER_AGREEMENT' end
 if text:find('{[%w_]+}') or text:find('an unnamed errand',1,true) then notes[#notes+1]='PLACEHOLDER' end
 if text:find('was settled. ',1,true) and text:find('was settled.',(text:find('was settled.',1,true) or 0)+12,true) then notes[#notes+1]='REPEATED_LEAD' end
 return notes
end
