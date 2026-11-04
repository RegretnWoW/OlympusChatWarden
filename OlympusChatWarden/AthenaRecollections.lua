-- Player-authored perspective. This store never writes Chronicle evidence,
-- supplies quest credit, verifies another player or enters Relay/report exports.
local _,ns=...
local R={VERSION=1,MAX_NOTES=128,MAX_TEXT=2000};ns.AthenaRecollections=R
ns.WardenDB=ns.WardenDB or {};ns.WardenDB.Recollections=R
R.feelings={unsaid='Leave open',joyful='Joyful',difficult='Difficult',tense='Tense',funny='Funny',mixed='Mixed',quiet='Quiet'}
R.company={unsaid='Leave open',welcoming='Welcoming',strained='Strained',quiet='Quiet',alone='I felt alone'}
local eligible={instance_enter='adventure',instance_exit='adventure',battleground_enter='adventure',battleground_exit='adventure',
 quest_turnin='quest',quest_accepted='quest',adventure_combat_summary='combat',guild_affiliation='guild',friend_status='friend',group_roster='group',encounter_ended='adventure'}
local function Copy(t) return ns.Athena.Copy(t) end
function R.NewStore() return {version=1,owners={},revision=0} end
function R.Store(provider,owner)
 if not provider or not provider:Allowed() then return end
 if provider.demo then return provider.RecollectionStore end
 if not ns.Chronicle or owner~=ns.Chronicle.Owner() then return end
 if ns.Storage.OlympusWardenRecollectionsDB==nil then ns.Storage.OlympusWardenRecollectionsDB=R.NewStore() end
 if type(ns.Storage.OlympusWardenRecollectionsDB)~='table' or getmetatable(ns.Storage.OlympusWardenRecollectionsDB) or ns.Storage.OlympusWardenRecollectionsDB.version~=1 or type(ns.Storage.OlympusWardenRecollectionsDB.owners)~='table' then return end
 return ns.Storage.OlympusWardenRecollectionsDB
end
function R.Signature(provider,owner)
 local store=R.Store(provider,owner);local row=store and store.owners[owner]
 return row and tostring(row.revision or 0) or '0'
end
local function Lineage(provider,owner)
 if provider.demo then return 'SYNTHETIC/'..owner end
 return ns.AthenaReadingSnapshots.Lineage(owner)
end
function R.Targets(plan)
 local out,seen={},{};local index=plan and plan.index
 if not index then return out end
 for _,b in ipairs(plan.episodes or {}) do
  -- The immutable source reference survives page breaks and scene regrouping.
  for _,ref in ipairs(b.sourceEvidenceRefs or b.node and b.node.factRefs or b.evidenceRefs or {}) do
   local f=index.byRef[ref];local kind=f and eligible[f.family]
   if kind and not seen[ref] and index.owner==plan.owner then
    seen[ref]=true;out[#out+1]={ref=ref,at=f.observedAt,kind=kind,storyId=b.storyId,
      label=(f.location and (f.location.instanceName or f.location.subzone or f.location.zone) or 'The journey')..' • '..kind,
      sourceRecordRef=f.sourceRecordRef}
   end
  end
 end
 table.sort(out,function(a,b) return a.at>b.at or a.at==b.at and a.ref<b.ref end)
 while #out>64 do table.remove(out) end
 return out
end
local function ValidTarget(provider,owner,target)
 if type(target)~='table' or type(target.ref)~='string' or #target.ref>1024 then return end
 local e=provider:Resolve(target.ref)
 local family=e and (e.family or e.details and e.details.recordType)
 if not e or e.observer~=owner or not eligible[family] or e.observedAt~=target.at then return end
 if target.sourceRecordRef and e.sourceRecordRef~=target.sourceRecordRef then return end
 return e
end
function R.Get(provider,owner,target)
 local store=R.Store(provider,owner);local row=store and store.owners[owner]
 if not row or row.lineage~=Lineage(provider,owner) or not ValidTarget(provider,owner,target) then return end
 local note=row.notes[target.ref]
 if note and note.at==target.at and (not note.sourceRecordRef or note.sourceRecordRef==target.sourceRecordRef) then return Copy(note) end
end
function R.Save(provider,owner,target,values)
 local store=R.Store(provider,owner);local e=store and ValidTarget(provider,owner,target);local lineage=store and Lineage(provider,owner)
 if not e or not lineage or type(values)~='table' then return nil,'This moment is unavailable.' end
 local text=values.text or '';local feeling=values.feeling or 'unsaid';local company=values.company or 'unsaid'
 if type(text)~='string' or #text>R.MAX_TEXT or text:find('[%z\1-\8\11\12\14-\31]') or not R.feelings[feeling] or not R.company[company] then return nil,'Choose a feeling and keep your recollection under 2,000 bytes.' end
 if not text:find('%S') and feeling=='unsaid' and company=='unsaid' then return nil,'Write a recollection or choose an answer, or skip this moment.' end
 local row=store.owners[owner]
 if row and row.lineage~=lineage then return nil,'This archive has a different origin. Older recollections are kept separately and cannot be attached here.' end
 if not row then row={lineage=lineage,revision=0,notes={}};store.owners[owner]=row end
 local count=0;for _ in pairs(row.notes) do count=count+1 end
 if not row.notes[target.ref] and count>=R.MAX_NOTES then return nil,'This character has 128 recollections. Remove one before adding another.' end
 row.notes[target.ref]={text=text,feeling=feeling,company=company,at=e.observedAt,sourceRecordRef=e.sourceRecordRef,
  sourceRef=target.ref,kind=eligible[e.family or e.details and e.details.recordType],authorship='PLAYER_AUTHORED',privacy='OWNER_PRIVATE',personalFactsVerified=false}
 row.revision=row.revision+1;store.revision=(store.revision or 0)+1
 if not provider.demo then ns.AthenaReadingSnapshots.Clear(owner) end
 return true
end
function R.Delete(provider,owner,target)
 local store=R.Store(provider,owner);local row=store and store.owners[owner]
 if not row or row.lineage~=Lineage(provider,owner) or not ValidTarget(provider,owner,target) then return end
 if not provider.demo and ns.FiresideSavedData then ns.FiresideSavedData.PurgeRecovery()end
 row.notes[target.ref]=nil;row.revision=row.revision+1;store.revision=(store.revision or 0)+1
 if not provider.demo then ns.AthenaReadingSnapshots.Clear(owner) end
 return true
end
function R.Apply(plan,blocks)
 local provider=plan.index and plan.index.provider;local targets=R.Targets(plan);local wanted={}
 for _,t in ipairs(targets) do local note=R.Get(provider,plan.owner,t);if note then wanted[t.ref]={note=note,target=t} end end
 local out={};local used={}
 for _,b in ipairs(blocks) do
  out[#out+1]=b
  for _,ref in ipairs(b.evidenceRefs or {}) do local row=wanted[ref]
   if row and not used[ref] then
    used[ref]=true;local note=row.note;local parts={};local actor=plan.index.ownerIdentity and plan.index.ownerIdentity.name or 'The adventurer'
    if note.feeling~='unsaid' then parts[#parts+1]=actor..' remembered this passage as '..R.feelings[note.feeling]:lower()..'.' end
    if note.company~='unsaid' then parts[#parts+1]=note.company=='alone' and (actor..' recalled feeling alone.') or ('In '..actor..'’s recollection, the company felt '..R.company[note.company]:lower()..'.') end
    if note.text:find('%S') then parts[#parts+1]=actor..' wrote: “'..note.text..'”' end
    local text=table.concat(parts,' ')
    out[#out+1]={blockId=b.blockId..'/recollection/'..ref,chapterId=b.chapterId,storyId=b.storyId,at=b.at,title=b.title,
     text=text,recollectionText=note.text,kind='body',recipeId='recollection/1',claimIds={},evidenceRefs={ref},worldRefs={},worldFacts={},developmentIds={},
     ownerPrivate=true,recollection=true,literal=true,clauses={{text=text,claimIds={},sourceRefs={ref},worldRefs={},
       ownerPrivate=true,assertionStrength='PLAYER_RECOLLECTION'}}}
   end
  end
 end
 return out
end
