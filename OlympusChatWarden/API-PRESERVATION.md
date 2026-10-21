# Final intelligence foundation: native limits

See [INTELLIGENCE.md](INTELLIGENCE.md) for this release's derived summaries,
measured-time rules, PvP visit scope and deliberately unknown values. Existing
collectors and consent are unchanged by this final pass.

# Activity correlation — 1.0.3

No native collector or API calls were added in this pass. The existing ledger is
indexed locally in bounded steps; dungeon/raid activity and player history do not
depend on damage meters. See [ACTIVITIES.md](ACTIVITIES.md) for the reviewed
EncounterInfo/DamageMeter contracts, source attribution and deferred capabilities.
Native event delivery and readability still need live Forever validation.

# Preservation coverage — 1.0.3

This release includes the existing preservation collectors and a derived-only intelligence layer.
It does not claim the entire 53-family research matrix is complete.

The adapter contracts were reviewed against Forever 1.60.1.70425, UI-source commit
`b401e0332adfbf0460d319b06d8ea29279a941f1`. The checked 70450 source revision changes
only version.txt. Synthetic tests establish behavior under those fixtures; native API
presence, event delivery, permitted field readability and game semantics still need
live validation. No installed client files, personal SavedVariables or logs were read.

## Encounter locations and retained history

Continuous other-player sampling is removed. Only new grouped visible encounters
read position once. GetBestMapForUnit is read without map writes; documented
GetPlayerMapPosition is used for player/party tokens only. Ordinary UnitPosition
values remain exact with their native map identifier and axis order. Availability
is not guaranteed. Missing/secret values stay absent, with no restricted fallback.
GUID, map, visibility and observer context are rechecked around the snapshot.
Observer and subject coordinates are separate; remote roster/public source data
does not establish proximity. Personal route collection is byte-identical to preview6.

Historical other-player routes and gaps retain their validators, codec and backup
readers. Storage accounts for them separately, including gap records. Profiles and
player-related event records form the Player Intelligence estimate; shared snapshot
objects remain other events. Stats are cached incrementally, not rescanned per frame.

## Preview5 additions and source boundaries

- Currency: C_CurrencyInfo ID-bound balances, known same-scope getter differences,
  and separate CURRENCY_DISPLAY_UPDATE payloads. Character/account/unknown scope
  is labelled. A new scope creates a baseline; no spending or reward cause is inferred.
- Lockouts: first ten GetSavedInstanceInfo returns and first three world-boss
  returns, verified against the pinned native RaidFrame. Preserve opaque identifiers,
  difficulty, flags and observed reset expiry. Do not guess undocumented later tuple
  fields, boss counts or personal completion. Cached server freshness is unknown;
  `complete` only describes coverage of readable cache rows. No RequestRaidInfo call.
- Collections: collected mount IDs, owned pet GUID/species/basic descriptors and
  owned toys from the existing filtered list. Explicit new-item events are separate
  from initial catalogs. No private pet custom names, forced filter changes or inferred
  removals. The collector never labels a catalog date as an earlier unlock date.
- Reporting: current native player-credit evidence and older records share one
  reporting path, with self/pet/group/unattributed and legacy fields kept separate.
- Evidence: new records distinguish native delivery, value snapshot and native
  source aggregate. Result labels apply only to their verified source contract/scope.
- Browsing: bounded scrollable multi-select event-type menu; filters never change
  retention or collector choices.

Additional primary references are pinned to commit
`b401e0332adfbf0460d319b06d8ea29279a941f1` in
[Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source/tree/b401e0332adfbf0460d319b06d8ea29279a941f1):
the generated CurrencyInfo, MountJournal, PetJournal and ToyBoxInfo documentation,
Blizzard_Collections/Classic/Blizzard_ToyBox.lua, and Blizzard_RaidFrame/Mainline
RaidFrame/RaidInfoFrame files. The evidence archive has URL/SHA256 catalogs;
source text was read as reference, not executed. Native Forever behavior remains
unverified. Older global toy getters are taken from actual Classic UI usage.

## Implemented foundation

| Family | Captured / boundary |
| --- | --- |
| Skills | C_SkillInfo structured rows keyed by skillID; validated legacy fallback. Headers/collapsed lists are not forcibly expanded. |
| Gear | All 19 slot states, readable full item payloads and own item GUIDs. Pending/unavailable differs from confirmed own empties. Recheck owner, IDs and links before committing. |
| Milestones | Recording, equipment, level/death, encounter, match and combat-exit checkpoints link dated known gear and appearance. Post-event samples are not fight-time equipment. |
| Traits | Active/Legacy configs with no staged changes; per-tree node chunks with native IDs/ranks, source/time and partial flags. Normal inspect may return a subject-bound export string. |
| Named sets / stats | Read-only equipment-manager definitions, actual equipped flag, own effective stats and durability; they are distinct from stable equipped gear. |
| Kill credit | PARTY_KILL readable attacker/target GUIDs, Player/Creature/Pet/Vehicle kinds; self/current pet/group/unattributed classifications. No automatic last-hit interpretation until live semantics are confirmed. |
| Combat / spell usage | Native combat boundaries and grouped own UNIT_SPELLCAST_SUCCEEDED counts with observed endpoints. Cast success is not damage/hit/kill. |
| Meter / recap | Out-of-combat supported session/source/spell aggregates and explicit recap IDs. Session/reset epochs and original recording sessions distinguish transient native IDs. Native log chronology or pairwise victim ledgers are not invented. |
| PvP | Correct lifetime/session/yesterday tuples; completion winner/duration and final readable score rows. Score totals are not victims. Camelot rank faction 2800 is read only on pinned builds 70425/70450. |
| Bosses / duels | Native encounter start/end/success and BOSS_KILL. Duels preserve lifecycle only. Failed encounter is not a wipe; boss result/instance exit is not whole-dungeon completion. |
| Reputation / crafting | Known before/after faction standings; simple delta only when the native faction API identifies a non-major faction. Learned recipes and actual craft-result payloads are separate evidence. No inferred cause for standing or inventory changes. |
| Important players | Friendly teammates, encountered character friends, bookmarks, Wanted and kill subjects. Optional normal inspection with one owned request, backoff, timeout, GUID rechecks and shared-cache invalidation. No passerby sweep, private notes or Battle.net identity copy. |
| Appearance | Readable race/class/body and own display IDs; applied barber option/choice IDs. Opponent gear provides a partial reconstruction descriptor. No serialized portrait pixels or fabricated face/hair. |
| Existing preservation | Exact own routes/lossless packing, measured time/AFK/gaps, quests/bags/spells/achievements/state and permitted Olympus full/delta archives remain. |

## Storage and validation

Schema6 accepts schemas1–5. Consent scope5 retains preview6 opt-ins and pauses older opt-ins
without deleting data. Native objects are immutable SHA256-addressed event payloads;
unchanged content is reused. References carry their actual observation times. Each
text-backup part carries its dependencies; import validates content hash, family,
references, original event identity and conflicts before committing that part.

Long-history synthetic checks cover 180 modeled days / 720 recorded hours:
48,251 total records, 1,296,000 precise route samples and 2,001 profiles. The test
first reproduces standard Lua 5.1 constant-table overflow in a flat literal, then
loads the bounded saved representation and validates every record plus its byte
estimate. This is a synthetic host benchmark, not a Forever startup/FPS guarantee.
Multipart text restore is tested separately at 2,012 records / 72 parts. Use complete
SavedVariables backups for large histories rather than thousands of manual parts.

On normal logout, the persisted representation uses validated typed event/profile
chunks (normally around 20 KB, with a bounded larger-record exception). The in-session
ledger stays unchanged. Corrupt, unsupported or conflicting chunks block that
container from loading; they are not silently discarded. Decoding never executes
chunk text. Old flat history remains accepted. Neither this format nor size notices
remove the practical memory, disk and load-time limits of the game.

Only explicit Clear deletes history. Runtime queues bound work per frame; a full
enrichment queue retains the original native event and reports missing detail. This
is not a history-retention cap. No raw combat-log event is registered, no secure/internal
combat getter is used, and no protected-data rendering workaround or upload was added.

## Still partial or deferred

- Live confirmation of all new native event/getter semantics and inspection ownership.
- Full cross-tree talent export/definitions/tree-hash serialization and all loadout systems;
  chunked observations are not a single atomic complete multi-tree build.
- Complete opponent face/hair/customization/transmog/model data and actual image rendering.
- A definitive named-victim ledger where native identity/credit fields are hidden.
- A structured duel winner and fully verified whole-dungeon completion.
- Exhaustive battleground objective/reward/queue history and every historical recap.
- Full loot-acquisition provenance, all gathering/repair/enchant changes and every transaction.
- Comprehensive lockouts, currencies, mounts/pets, transport/NPC/social metadata adapters.
- External post-session log importer, local image renderer and screenshot attachments.

No alternate getter is used to circumvent secrecy. Unavailable detail stays absent;
Collection Status reports family-level observations/errors rather than claiming every
supported source is complete. Group and friend associations remain distinct from actual
nearby sightings, encounter participation and independent verified claims.

## Primary references

[Unit events](https://raw.githubusercontent.com/Gethe/wow-ui-source/b401e0332adfbf0460d319b06d8ea29279a941f1/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua),
[Skills](https://raw.githubusercontent.com/Gethe/wow-ui-source/b401e0332adfbf0460d319b06d8ea29279a941f1/Interface/AddOns/Blizzard_APIDocumentationGenerated/SkillInfoDocumentation.lua),
[Damage meter](https://raw.githubusercontent.com/Gethe/wow-ui-source/b401e0332adfbf0460d319b06d8ea29279a941f1/Interface/AddOns/Blizzard_APIDocumentationGenerated/DamageMeterDocumentation.lua),
[Traits](https://raw.githubusercontent.com/Gethe/wow-ui-source/b401e0332adfbf0460d319b06d8ea29279a941f1/Interface/AddOns/Blizzard_APIDocumentationGenerated/SharedTraitsDocumentation.lua),
[Death-recap UI field usage](https://raw.githubusercontent.com/Gethe/wow-ui-source/b401e0332adfbf0460d319b06d8ea29279a941f1/Interface/AddOns/Blizzard_DeathRecap/Mainline/Blizzard_DeathRecap.lua).
