-- Small, shared semantic keys into existing atlases. Module crests stay separate.
local _,ns=...
local E={};ns.EventIcons=E
local records={level_change='star',achievement_earned='star',quest_turnin='capture',quest_accepted='create',quest_removed='delete',
    quest_objective='capture',quest_log='capture',skill_change='rules',spell_learned='rules',equipment_change='packs',
    loadout_observed='packs',important_player='reports',player_observed='reports',group_roster='party',
    player_death='shieldOff',instance_enter='party',instance_exit='export',loot_offered='trade',bag_item='packs',
    olympus_snapshot='olympus',collection_gap='help',recording_start='create',recording_stop='enabledOff',
    location='general',route_segment='general',time_span='recording',time_slice='recording',native_statistic='star'}
local activities={duel='shield',battleground='shield',arena='shield',boss='shield',raid='party',dungeon='party',group='party'}
function E.Key(name) return 'event:'..(name or 'messages') end
function E.Activity(a) return E.Key(activities[a and a.kind] or 'capture') end
function E.Record(e)
    local d=e and e.details or {};local kind=e and e.kind
    local r=d.recordType or ''
    if r=='witness_death' then return E.Key('shieldOff') end
    if r=='witness_recovery' then return E.Key('create') end
    if r=='witness_ability' then return E.Key('rules') end
    if r=='witness_state' then return E.Key('general') end
    if r:find('duel',1,true) or r:find('encounter',1,true) or r=='boss_kill_event' or r=='native_kill_credit' then return E.Key('shield') end
    if r:find('pvp',1,true) or e and e.capture and e.capture.family=='scoreboard' then return E.Key('shield') end
    if e and e.capture and (e.capture.family=='gear' or e.capture.family=='traits') then return E.Key(e.capture.family=='gear' and 'packs' or 'rules') end
    return E.Key(records[kind] or 'messages')
end
function E.Chat(item)
    local c=item and item.categories or {}
    if c.shield then return E.Key('shield') end
    if c.wanted then return E.Key('reports') end
    if c.olympusmute then return E.Key('enabledOff') end
    if c.mentions then return E.Key('mentions') end
    local action=item and (item.action or item.reviewAction)
    if action=='hide' or action=='hidden' then return E.Key('enabledOff') end
    if action=='redact' or action=='redacted' then return E.Key('messages') end
    return E.Key('messages')
end
function E.Relay(r)
    return E.Key(r and r.state=='received' and 'export' or r and r.state=='failed' and 'help' or r and r.state=='sending' and 'whisper' or 'messages')
end
