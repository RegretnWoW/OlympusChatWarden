-- Retention is a source policy, never a side effect of a timeline filter.
local _,ns=...
local R={version=1,classes={HISTORY_EVENT=true,HISTORY_STATE_CHANGE=true,HISTORY_SESSION_DETAIL=true,
    OPERATIONAL_SUMMARY=true,TRANSIENT=true,LAB_EXPERIMENTAL=true},matrix={}};ns.AthenaRetention=R
local function Rule(keys,class,proof,dedupe,display)
    for key in keys:gmatch('%S+') do R.matrix[key]={class=class,proof=proof,dedupe=dedupe,display=display,
        privacy='local-only; owning module and recording consent',storage='original canonical source; reference projections'} end
end
Rule('quest_turnin quest_accepted quest_removed quest_item_received quest_currency_received achievement level_up skill_change spell_learned collection_added',
    'HISTORY_EVENT','Native occurrence; removal is not abandonment; reward recipient must be established','source observation ID; never item ID alone','milestone')
Rule('equipment_changed traits_changed currency_changed reputation_changed character_snapshot',
    'HISTORY_STATE_CHANGE','Readable before/after; unknown is not empty','unchanged polls only; retain A to B to A','dated change')
Rule('group_roster instance_enter instance_exit encounter_start encounter_end boss_kill duel_session_start duel_session_end duel_session_result native_kill_credit witness_death witness_recovery public_achievement',
    'HISTORY_EVENT','Native identity and event-specific claims; credit is not a killing blow','observation ID; separate context identity','activity / source evidence')
Rule('spellcast_success damage_meter_session combat_summary route_segment player_route',
    'HISTORY_SESSION_DETAIL','Owner/subject, source, session and interval; no inferred effects','existing versioned session aggregates / route codec','expandable detail')
Rule('player_observed witness_state witness_ability important_player',
    'HISTORY_STATE_CHANGE','Verified GUID; visibility and field availability remain distinct','identity/context baseline then verified changes; bounded cast IDs','compact player history')
Rule('chat_decision shield_action correction assessment signal_action relay_health command_health',
    'OPERATIONAL_SUMMARY','Typed source/action/correction with exact dependencies; no raw private content','bounded correctable source window; horizon always disclosed','local operational context')
Rule('ui_cache query_page', 'TRANSIENT','Rebuildable from canonical source','page lifetime','none')
Rule('lab_probe', 'LAB_EXPERIMENTAL','Explicit developer arm; manual watched subjects or separately armed self',
    'every permitted occurrence until visible capacity stop','developer Lab only')
Rule('lab_nameplate_added lab_nameplate_removed','LAB_EXPERIMENTAL',
    'Native plate token; removal uses prior capture-scoped verified subject binding, never fresh unit state or death/range proof',
    'Every matching armed add/remove; unmatched arrivals are counters only; 256 active bindings then visible incomplete stop','developer Lab coverage/export only')
Rule('session_start recording_start recording_stop quest_turnin quest_accepted quest_removed level_change achievement_earned spell_learned recipe_learned native_craft_result quest_item_received quest_currency_received encounter_loot_delivery loot_offered collection_added player_death collection_gap player_route_gap duel_session_request duel_session_start duel_session_end duel_session_result duel_capture duel_capture_missed duel_requested duel_finished duel_inbounds duel_outofbounds boss_kill_event encounter_started encounter_ended boss_status_observed pvp_match_complete score_capture_status public_achievement',
    'HISTORY_EVENT','Existing typed native validator; only the source-specific occurrence is claimed',
    'Canonical observation ID; no content-only collapse of independent occurrences','source browser / qualified milestones')
Rule('character_snapshot character_detail skill_observed skill_change equipment_observed equipment_change inventory_observed reputation_observed reputation_standing_changed bind_observed player_state spell_observed currency_observed currency_changed collection_observed lockout_observed lockout_list_observed equipment_set_observed forever_rank_observed stats_observed gear_condition_observed barber_choices_applied trait_tree_nodes loadout_observed native_snapshot olympus_snapshot statistic_observed pvp_counter_snapshot location',
    'HISTORY_STATE_CHANGE','Readable dated state; baseline is not an acquired unlock; unavailable is not empty',
    'Existing per-source equality and immutable snapshot reuse; dated A to B to A references survive','baseline / dated transition')
Rule('time_slice time_span route_segment player_route own_spell_success_count damage_meter_source damage_meter_spell damage_meter_session native_meter_reset combat_started combat_ended duel_combat_summary native_death_recap player_combat player_kill_credit collector_session pvp_score_row',
    'HISTORY_SESSION_DETAIL','Original source, owner, activity/session, interval and count; evolving meter/score rows are observations',
    'Existing session aggregation / content-addressed snapshots; no sums across cumulative score refreshes','expandable session detail')
for _,key in ipairs({'loadout_observed','trait_tree_nodes','character_snapshot','native_snapshot'}) do
    R.matrix[key].display='detailed source / configuration views; not character Timeline or curated Highlights'
end
Rule('friend_status', 'HISTORY_STATE_CHANGE','GUID-verified ordinary character friendship; dated baseline or change, never perpetual authorization','unchanged current state only; retain remove and re-add','social history')
Rule('guild_affiliation guild_member_observed','HISTORY_STATE_CHANGE','Own native membership baseline/change or GUID-bearing guild roster; observation is not a join date','unchanged readable affiliation/rank only; retain A to B to A','guild history')
Rule('item_received','HISTORY_EVENT','Exact localized native SELF receipt template with coherent item link and quantity; not inventory cause inference','native line ID only; separate sources are receipt observations, not additive transactions','ordinary personal history')
function R.Classify(e)
    local key=e.details and e.details.recordType or e.kind
    local row=R.matrix[key] or R.matrix[e.kind]
    -- Grandfather old and unknown accepted records. This function cannot delete.
    return row or {class='HISTORY_EVENT',proof='Existing source validator; provisional source-qualified history',
        dedupe='canonical observation ID only',display='source browser',privacy='local-only',storage='unchanged original'}
end
Rule('pet_link group_assignment visible_use','HISTORY_STATE_CHANGE','Verified eligible player and same-read native pet/roster/mounted state; no permanent ownership, actual role or collection inferred',
    'Only readable changed state; A to B to A retained; live coalescer never removes originals','Observed history / personal and qualified guild references')
Rule('target_episode cast_observation group_transition personal_source','HISTORY_SESSION_DETAIL','Typed native occurrence with verified identity and explicit verified/provisional meaning; no inferred attack, learned spell or item transfer',
    'Cast GUID plus native phase where available; each notification retained when native identity unknown; contextual target pair once per 60-second source window','Source-linked observed history; provisional qualifier remains')
Rule('aura_effect','HISTORY_STATE_CHANGE','Native readable instance/spell on a verified subject; source unit only when independently readable; never proof of recipient casting',
    'Owner/run + subject token epoch + instance + transition; unchanged refresh only; each real return retained','My Combat / Observed Combat / complete source history')
Rule('aura_partial','HISTORY_STATE_CHANGE','Readable native instance on verified subject; spell/actor may remain unknown; no cast inference',
    'Existing live aura equality; original distinct native transitions retained','Provisional effect history')
Rule('contact_observed contact_inspection_attempt match_observed historical_incident incident_correction','HISTORY_EVENT',
    'Validated source-qualified observation; minimal private incidents require independent explicit opt-in',
    'Canonical observation ID; optional cached grouping cannot expire originals','Source history / scoped private query; no automatic canonical expiry')
