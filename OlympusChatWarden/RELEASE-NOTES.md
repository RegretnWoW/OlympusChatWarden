# Olympus Warden 1.1.4 — cumulative patch notes

## RC3 — Intel retained-page hotfix

Clicking a player after reopening Intel now prepares the saved view before opening the dossier. If combat or indexing delays preparation, the selected player waits safely. Save note and Watch player also wait for the real player view, preserving existing notes and watch choices. No recording, collection, database or consent changes.

Changes since the supplied public 1.1.3 release. This package is 1.1.4-rc3, prepared for final live-client smoke testing.

## Athena: a connected local history

- Adds Athena, a shared evidence layer connecting Chronicle, Intel and permitted local protection/activity context. Modules reference original sources rather than copying private messages or reports into a general player database.
- Preserves source dates, observer and player identity, original evidence links and explicit uncertainty. A readable partial observation can remain provisional without inventing its missing details.
- Keeps personal Chronicle history, other-player intelligence and private incident evidence within their respective permission and access scopes.
- Sharing in this release is internal to your own Warden modules. Player-to-player and guild-wide synchronization are not enabled.

## IntelWarden: living player dossiers

- Adds richer source-linked dossiers with dated observations, relationship context and historical chapters alongside existing notes, equipment and talents.
- Watchlisting now initiates enrichment: checks what is already known, captures readable current identity/social facts and queues permitted gear/talent inspection when a legitimate opportunity is available.
- Continues enrichment through future supported encounters and events. The dossier explains missing, incomplete, stale or unavailable sources instead of implying that no data exists.
- Adds GUID-verified character-friend evidence. Missing or temporarily unreadable friend information is not automatically treated as a confirmed removal, and same-name players are not merged.
- Distinct source-backed shared activities can earn Important status. A single roster, city sighting or scoreboard appearance cannot promote an entire crowd to deep collection.
- Keeps independent watches, current verified friendship and earned relationships separate. Removing a watch stops future watch-only detail while preserving already accepted records and any independently valid eligibility.
- Adds eligible pet-unit links, group role/leadership assignments, contextual targeting and visible-state observations where native sources support them. These do not establish permanent pet ownership, actual combat contribution or private remote activity.
- Adds structured public achievement, guild association and supported personal interaction observations without turning raw chat into permanent quote history.
- Retains original evidence navigation and historical gear/talent sources. Unknown equipment, missing talents and incomplete observations remain explicitly unknown.

## Collection tiers: useful history without the crowd firehose

- Applies a consistent policy across 25 activity families and ten player categories.
- Keeps your own permitted history detailed. Current watches, GUID-verified friends and earned Important players qualify for richer future detail where supported and separately consented.
- Keeps ordinary BG participants lightweight: relevant match identity, context, readable score/objective observations and eligible totals, without a per-player spell-detail census just because they appear on the meter.
- Keeps ordinary party/raid relationships and meaningful encounter anchors so earlier meetings can still link to a later Important dossier.
- Guild membership alone does not grant deep collection. Incidental world contacts do not create unrelated meter, passive state-change or death streams.
- Ordinary duel opponents keep consented duel lifecycle, result and bounded summaries. Duel participation alone no longer starts automatic deep gear/talent inspection; independent eligibility or an explicit permitted manual action still works.
- First-contact inspection remains a separate option, off by default. Watching someone never reveals offline gear, hidden APIs or a complete remote activity history.

## Combat, casts and auras

- Expands your own source-backed combat history and observed combat detail for independently eligible players.
- Preserves readable native aura/effect observations, including partial or provisional facts. An effect on a player is not treated as proof that the player cast it; unavailable caster information stays unknown.
- Aggregates routine eligible cast START, STOP and SUCCEEDED notifications by subject, spell, phase, source epoch/context and short window. Counts retain first/last times and observation coverage.
- Keeps starts, stops and successful notifications separate. A start does not imply success; a successful notification does not prove damage, healing, a hit or a kill.
- Keeps significant interrupted and channel-phase observations individually qualified. No interrupter is named without independent evidence.
- Preserves uncertain notifications when a cast identity is unreadable rather than deduplicating merely by matching spell and timestamp.
- Retains your existing primary successful-spell counter. Separate exceptional-ability observations and duel summaries do not inflate the new primary routine counts.
- Gates expensive foreign spell-meter and death-recap detail before requesting it. Native credit, score and meter observations retain their source limits; no exact enemy rotation or complete combat log is claimed.
- Preserves all previously accepted individual cast records; new aggregation applies at intake rather than rewriting historical originals.

## Chronicle: timeline, highlights and source-backed stories

- Separates My Timeline's character events from curated Highlights. Routine configuration snapshots and talent-tree node observations no longer crowd the normal journey/highlights presentation; the original sources remain available.
- Adds Journey, All history, Guild history and My Combat views with paging, source links and explicit unknown states.
- Adds Athena's Journal/Storybook: source-linked chapters over your recorded adventures, with an explanation of the evidence behind each account.
- Keeps failed attempts, incomplete visits and no-recorded-victory histories. Story selection does not delete unfeatured evidence or invent boss success, attendance or loot recipients.
- Keeps dated guild context distinct from a claim of an official guild event or proof that every roster member participated in every attempt.

## Startup, recording and recovery

- Starts eligible collection through the local recovery journal while retained history validates, instead of relying only on a small temporary startup buffer.
- Expands startup coverage across the existing production collectors while retaining their individual consent and source checks.
- Keeps pending startup operations across normal logout/reload and safely reconciles them with validated history. Original archive data remains preserved when recovery cannot complete.
- Keeps your current character first and other archives on demand. Validation progresses with the Warden window closed; game-side background throttling and source delivery still depend on the client.
- Distinguishes archive validation from reading-view preparation and summary finalization. Chat progress and short diagnostics make those stages easier to follow.
- Fixes recording and duel-consent controls that could appear checked but fail to update during loading/recovery states, and reduces repeated readiness/status messages.
- Retains qualified uncommitted cast batches in a bounded local pending queue. Denied personal cast-count writes can use the same durable fallback; exact already-committed batches reconcile without creating another copy.
- Reports capacity failures and incomplete coverage. It does not delete accepted history or claim that undelivered native events, unavailable fields, exhausted storage or an interrupted disk save were losslessly captured.

## Player-owned retention and backups

- Makes the distinction between permanent accepted evidence, rebuildable views, temporary collection state and operational summaries explicit.
- Keeps accepted character/player history until you explicitly clear it. No new age, tier, success or capacity-based automatic deletion is introduced.
- Coalesces unchanged intake and reuses identical snapshots without erasing dated changes or a genuine A → B → A return.
- Preserves existing event/source identities and original retained records through supported upgrades. Numeric snapshot verification accepts supported serialization round trips only when the original checksum still matches; it does not bypass verification or rewrite the evidence.
- Protects pending recovery from identifier collisions and interrupted handoffs. Unrecognized archives/pending formats remain preserved with an explanation.
- Text backup and restore wait while startup or cast evidence cannot safely commit, avoiding an apparently complete export that omits pending observations.
- Complete SavedVariables backups include accepted history and pending local recovery. Keep a matching backup before upgrading or rolling back; older readers may not understand newer additive record types.

## Performance and everyday browsing

- Reduces repeated history-summary work. Late combat/group intervals update the affected recording-clock suffix instead of replaying unrelated completed clocks.
- Uses cooperative indexing and distinct reading/finalization stages, with expensive view preparation deferred during combat.
- Keeps a completed page visible while new observations queue, so continuous recording does not starve the reader of a usable result.
- Stabilizes busy lists, including PvP reports, and keeps selections, page/scroll state and draft notes through supported navigation/reopening paths.
- Releases disposable projections/caches when appropriate while keeping canonical history and active protection state.
- Uses typed meter updates to request the changed session/type rather than repeatedly enumerating unrelated sessions. Independent updates keep their own jobs.
- Retains module isolation: disabling a feature keeps its data and consent choices, while Chronicle does not depend on ChatWarden's master switch.
- Expands short recording, recovery, pending-cast and optional performance diagnostics. Desktop benchmark results are kept separate from live WoW CPU, memory and frame-time measurements.

## Interface, alerts and fixes

- Uses the client's supported Blizzard UI sound kits for window, tab and button interactions. Unsupported clients remain silent instead of using guessed sound IDs.
- Makes the optional shop shortcut toggle Warden open/closed. Existing shortcut opt-ins remain unchanged.
- Fixes the page-hide nil-store error encountered when switching or closing Chronicle/Intel.
- Fixes the BG Intel “My target” error when the saved view has no intelligence projection. Existing cooperative navigation waits when necessary and keeps the clicked GUID even if your target changes.
- Guards Original record against a temporarily missing view and explains when its source is not ready.
- Rejects inaccessible native tables before reading/iterating them in supported paths. Actual secure/secret-client behavior still needs native testing.
- Adds separately opted-in activity notices for watched and earned Important players. Replaying old history does not replay those notices.
- Keeps local filter advice correctable: marking an eligible decision as a false positive retracts its advisory contribution without rewriting the original source. Athena does not automatically shield a player.
- Keeps optional historical incident evidence scoped and consented; normal filtering, Shield, spelling, Alerts and Relay retain their own settings and action rules.

## Privacy and compatibility

- No new indefinite raw-chat, quote or whisper retention. Chat Capture keeps its existing independent settings and default behavior.
- No health/power monitoring stream, continuous tracking of other players, hidden-value extraction, name-only identity guessing or automatic guild/player history transfer.
- No automatic Relay submission. Reports and retries retain the existing explicit submission rules.
- The release-pass changes do not change the stored schema, consent revision, addon folder, SavedVariables identity or approved collection policy.

## Before updating

1. Fully close WoW and back up the complete SavedVariables files, including recovery data.
2. Keep the original working addon ZIP and matching backup. Install the `OlympusChatWarden` folder from this clean user package.
3. Confirm startup/readiness, Intel target browsing, your recording/module choices and a normal logout/login readback on this exact candidate.

Native API availability varies by client. Unknown evidence stays unknown. This RC2 has offline validation; final native startup/UI, BG performance and physical save/readback checks remain pending. These notes do not certify every gameplay API or promise complete recording under native restrictions.
