# Intelligence foundation — 1.0.3

Open Recording > Intelligence. This is an inspection browser over existing
history, not the finished Chronicle or dossier design. No new collectors,
API getters, schema, consent scope, outgoing communication or saved derived
history are introduced in this final foundation pass.

## Implemented and inspectable

- GUID-bound local sighting episodes, first/last episode, observer zones, dated
  aliases/classes/guilds, native credit direction, notes/watchlist and public
  Olympus row references. Fast player queries use the shared index. Exact known
  name resolution returns every matching GUID; it never merges same-name players.
- Credits distinguish our character, pet-associated, group-associated,
  unattributed and actor/target reports against our character. Same-instant native
  deliveries are deduplicated for counts while all originals stay in the ledger.
  NPC targets are excluded from player credit summaries.
- Shared group/dungeon/raid segments and boss attempts/results while listed in
  saved rosters reuse ChronicleActivities. First/last roster observations stay
  distinct from whole-segment start/end. Individual attendance, exact shared time,
  roles and matched performance remain unknown where not established.
- Battleground and arena entry/location/exit segments reuse instance boundaries,
  including conservative startup-pair handling. They are observed visits, not
  unique complete matches. Native completion reports retain their winner code and
  reported duration; neither proves our personal outcome or observed duration.
- Scoreboard objects are preserved as separate dated observations, with GUIDs
  when present and independently readable statistics. Identical content is shown
  once. Updates are never summed into lifetime totals. Original source drill-down
  retains content ID, source, clock, timestamp and imported-backup warning.
- Level chronology, observed XP changes, quest/skill/equipment/collection/
  achievement records, deaths by recorded zone and observed zone entries.
  Your own route recording is unchanged. No other-player movement is restored.
- Indexed queries support player GUID, activity, native encounter ID, map ID,
  zone, source, saved evidence label and time range, using original references.

## Time accounting

Measured spans and legacy slices are unioned within a recording clock domain.
Endpoint heaps and sweeps work cooperatively; conflicting overlap dimensions
become unknown. Identical coverage counts once. Location categories are mutually
exclusive; AFK, combat-window and roster-window dimensions overlap them.
Non-AFK means not flagged AFK, never proof of active gameplay.

Only contiguous measured elapsed intervals are positioned. A compacted total
with unlocated holes, a span crossing an explicit recording boundary, malformed
clock endpoints or a new clock range overlapping prior recorded wall coverage is
kept as unallocated reported time. Nothing is deleted or prorated. Aggregate
reported time and eligible unique measured time can therefore differ; both are
labelled. Pending unflushed time is not included until its source record is saved.

Combat time requires a matching native start/end in the same recording segment
and a consistent native duration. Only overlap with measured intervals counts.
Time outside such windows remains unclassified, not proven out of combat.
Group-context time uses observed roster segment windows; it does not establish
exact membership duration for any individual. Instance time uses recorded context.

Recording segments preserve partial starts, reload/loading/gap/clock boundaries.
Calendar summaries use recorded UTC day, Monday-based week and month. Intervals
crossing a calendar boundary or with inconsistent wall/elapsed duration remain
unassigned for that calendar dimension; no guessed per-second placement is added.

XP/hour requires consecutive value-linked XP changes in the same segment with
complete measured coverage between them. First/unmatched updates and gaps are
excluded. Quest reward fields are not double-added. Later flushed spans can
resolve pending windows. Level intervals show measured coverage and its limits.

## Deliberate unknowns

- Individual killing blows from PARTY_KILL, confirmed killer identity from nearby
  units/recap names, head-to-head K/D and automatic rivalry/threat scores.
- Unique native PvP match identity and reliable completion-to-scoreboard linkage.
  The existing collector's matchSequence resets on PVP_MATCH_ACTIVE without
  preserving that boundary. runID + sequence can therefore repeat. No name/time
  matching is used. Personal wins/losses, unique-match totals, comparable best-match
  rankings and repeated teammate/opponent classifications are deferred.
- Exact player attendance, exact grouped seconds, lifetime statistics and matched
  DPS/HPS/interrupt/dispelling performance. Boss failures are not attributed wipes.
- Historical class/guild snapshots do not establish present status or roles.
  Olympus records are dated public reports, never automatic local sightings.

Sighting episodes require a local observation plus the existing encounter marker
and separation of at least120 recorded seconds since the last local observation.
Rapid target changes/reloads do not create rivalries. Across different clocks,
only compatible server timestamps can establish that separation. An episode is
not a fight or proof of physical departure/re-entry. Watchlist is a personal choice.

## Rebuild and preservation

One original event ledger remains authoritative. Derived indexes, endpoint ranges,
player summaries and calendar projections exist only in memory. Original objects
are referenced, not copied into new saved incident databases. Append-only records
extend indexes; replaced/out-of-order ledgers rebuild. Late-flushed intervals may
rebuild the derived time sweep from interval references. Per-player selection
never rescans the raw history. Background routes do not trigger a time rebuild.

Activity feed and summary work is bounded to128 units per update and pauses in
combat. Large cold histories can take many frames; progress is shown. Source and
summary lists are paged. Clearing history cancels work and clears dependent UI.
Existing complete-file and history-text backups reconstruct these projections.
All12 collector/storage/codec modules remain byte-identical to Preview10.

Live Forever event semantics, visibility, clock behavior, roster timing, score
availability, native input/fonts/scaling and performance still need testing.
Synthetic tests establish behavior under supplied fixtures, not live compatibility.
