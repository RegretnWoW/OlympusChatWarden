-- Reviewed sentence forms, not world knowledge or observed events.
local _,ns=...
ns.MetisCalliopeData={version='calliope-1.1.0',recipes={
 recurring={claimType='recurring_companion',limit=1,gap=3,forms={
  '{name} was among the company once more.',
  '{name}, who had shared an earlier adventure, was present again.',
  'Among the returning companions was {name}.',
  '{name} shared this passage of the journey, as on an earlier occasion.',
  'The company included a familiar name: {name}.'}},
 close_call={claimType='owner_combat_experience',limit=2,gap=2,forms={
  'One clash brought {actor} perilously close to death.',
  'In one bout of fighting, {actor} had little strength remaining.',
  '{actor} came close to death during the fighting.',
  'In the fighting, {actor} was left with little strength.',
  'One struggle left {actor} dangerously weakened.'}},
 recovery={claimType='owner_combat_experience',limit=2,gap=2,forms={
  'Strength returned before that passage was over.',
  'Recovery followed before that bout was over.',
  'Before the fighting ended, some strength had returned.',
  'That bout of fighting also saw a recovery.'}},
 return_place={claimType='zone_return',limit=2,gap=2,forms={
  'The journey brought {actor} back to {place}.',
  '{place} entered {actor}’s story once more.',
  '{actor} returned to {place}.',
  'Once again, {actor}’s path led through {place}.'}},
}}
