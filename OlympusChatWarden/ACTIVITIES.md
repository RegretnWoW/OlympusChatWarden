# Shared activities — 1.0.3

Open Recording > Activities or /ocw chronicle activities. These views connect
existing dungeon, raid, group, battleground and arena visit evidence. A damage
meter is not required. Original source records remain accessible.

- A segment is an observed part of an activity, not guaranteed completion.
  Reload, recording/clock and real instance entry/exit boundaries stay separate.
  Explicit started-inside startup pairs share one partial segment, even when
  their clocks differ. Both originals are retained.
- Roster observations associate GUIDs with segments and boss attempts. Carried
  rosters are labelled. Neither remote membership nor a boss result establishes
  individual attendance, exact join/leave times or player-caused failure.
- Native starts/results preserve difficulty, success/failure and missing/conflicting
  boundaries. Boss-kill reports are not whole-dungeon completion. Unknown remains
  unknown; a failed attempt is not automatically a full-group wipe.
- Player queries use the same activity references, dated aliases and GUIDs.
  Same-name players are never merged; later names cannot rewrite older segments.
- The displayed measured duration uses unique eligible elapsed coverage inside
  the observed segment/context. Gaps and contradictory/unlocated intervals are
  not filled. It is not whole-run duration or exact time grouped with a player.
- Battleground/arena visits are not unique complete matches. Native completion
  reports preserve codes and reported duration. Scoreboard observations stay
  separate because the existing saved sequence may be reused.
- Performance observations remain unassigned until reliable native matching is
  validated. Individual attendance, DPS/HPS, interrupts and lifetime rankings
  are not invented.

Recording > Intelligence adds player/credit histories, time dimensions and UTC
periods, progression, deaths and zone entries. See [INTELLIGENCE.md](INTELLIGENCE.md)
for definitions, unknowns, query scope and rebuild/preservation rules.

Recorded Events starts with meaningful changes and visible local Wanted encounters.
All recorded data and multi-type selections retain access to observations/routes.
Native actions and background summaries have separate filters. Browse work yields
in small steps and never changes recording, consent or retention.

Derived activity/intelligence indexes exist only in memory. The authoritative
ledger and backups retain original records. Clear removes derived UI and cancels
work; imports/replacements/out-of-order records rebuild deterministically.
The final pass changes no collectors, schema, consent or outgoing communication.
Native Forever behavior still needs the RELEASE-CHECKS.md pass.

## Native API review

The pinned Forever 1.60.1.70425 contracts were read locally from UI-source commit
`b401e0332adfbf0460d319b06d8ea29279a941f1`. They are source contracts, not a live
client compatibility test. The activity layer calls no new native API.

| Source | Available contract / current evidence | Boundary |
| --- | --- | --- |
| EncounterInfo | ENCOUNTER_START has encounter ID/name, difficulty and group size; ENCOUNTER_END adds success and boss-unit status | Boss-unit status is not a player-participant list. The existing collector retains the first five fields. No confirmed individual attendance is derived. |
| BossKill | Encounter ID and name | No unique run or attempt ID, player roster or whole-dungeon completion field. |
| Existing group reader | GUID-bearing roster observations | Reads defer during combat, and no completeness guarantee is saved. No exact joins/leaves or continuous attendance is reconstructed. |
| Existing instance events | Local entry/exit and recorded instance context | No unique-run proof, and older entries can lack difficulty. Attempt difficulty remains attached to its own source. |
| DamageMeter | Available session ID/name/duration and readable source aggregates; source identity/name may be conditional-secret | No encounter ID in the reviewed available-session structure. No name/time-only boss matching, performance averages or rankings added. |
| Native kill credit and scoreboards | Existing actor/target credit classifications and match-specific objects | No new attacker inference, historical-level substitution or lifetime totals. Advanced PvP correlation is deferred. |
| Olympus 1.2.4 | Existing permitted Wanted/profile/public-ranking snapshots | No bridge changes. Public listings never create direct sightings or attributed combat. |

References:
[EncounterInfo](https://raw.githubusercontent.com/Gethe/wow-ui-source/b401e0332adfbf0460d319b06d8ea29279a941f1/Interface/AddOns/Blizzard_APIDocumentationGenerated/EncounterInfoDocumentation.lua),
[DamageMeter](https://raw.githubusercontent.com/Gethe/wow-ui-source/b401e0332adfbf0460d319b06d8ea29279a941f1/Interface/AddOns/Blizzard_APIDocumentationGenerated/DamageMeterDocumentation.lua).

The next passes can validate stronger participation/session matching, then attach
supported performance values. The full Chronicle timeline and player dossiers,
advanced PvP analysis and cross-player sharing are not implemented here.
