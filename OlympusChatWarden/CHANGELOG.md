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


# Earlier public release notes

# Olympus Warden 1.1.3



- Display historical talent trees with recorded native positions, connections and ranks. Unavailable geometry retains the selected-talent list.

- Zoom icons, ranks, headings and lines together from 75% to 200%. Reset always returns to 100% and the start of the tree; ordinary refreshes preserve the selected view.

- Remove the inline talent export backing panel, placeholder and permanent instructions. Original exports remain available through Copy native export.

- Add independent, default-off shop, minimap and native Inspect side-tab shortcuts with stock framing and Warden artwork.

- Make Olympus Inspect target use normal inspection and the exact recorded player, including new profiles after a valid response.

- Guard unreadable current and cached native tooltip strings before comparison or restoration.

- Show native equipment tooltips and labeled item-type links for ID-only observations; preserve exact historical modifiers when available. Brief owned-cache completion can retain late inspection links without another request.

- Populate My Reports and Developer Inbox on first opening after login, before any new report changes the store.

- Remove duplicate CommandWarden banner buttons. Preserve history, consent, module selections and complete-file backup compatibility.



# Olympus Warden 1.1.2



- Fix recording remaining inactive when Olympus access resolves during world entry. Previously consented Chronicle and Intel recording resumes after validation.

- Preserve native login/reload flags through deferred startup, without duplicating an already active session.

- Keep world readiness accurate when leaving the world or logging out.

- Add `/warden chronicle check`, a concise three-line recording diagnostic.

- Preserve existing history, notes, watchlists, module selections and consent. Missed events cannot be recovered retroactively.



# Olympus Warden 1.1.1



CommandWarden brings feature choices and performance controls together. RelayWarden adds in-game bug reporting, while current-character-first loading makes retained history available with less unnecessary startup work.



## CommandWarden and optional modules



- Choose Chat Only, Full Suite or individual features in CommandWarden > Modules. New installations start with Chat selected; existing selections are retained.

- Disable optional work without deleting history, dossiers, notes, watchlists or recording choices. Chat, Shield, Signal alerts and historical consumers have independent runtime gates.

- Overview, Modules, Performance and shared Settings sit in one control center. Module selection does not grant recording consent.

- Performance status separates Warden's client-attributed memory from the whole UI Lua heap. Profiling is optional and stays local to the current session.



## RelayWarden support



- Report a bug directly in game. Choose a module, enter a title and description, then Submit Report once. View Details is optional.

- My Reports shows Sending, Waiting to Deliver, Delivered and Needs Attention. Submitted reports retry automatically while you are online; Delivered requires a validated acknowledgment.

- Unfinished forms remain local across navigation and reload. Advanced Tools includes recovery of older unfinished text, diagnostics and developer self-tests.

- Optional Technical Details starts off for every new or switched form. Your report and native character name are shared with the developer. Chat, history, dossiers, locations and private notes are not silently attached.

- Support, Data & Backups and Help & Updates provide clear routes. Advanced delivery controls remain available when needed.



## Faster readiness and safer retained history



- Validate the current character first. Other packed archives remain intact until explicitly requested by a history view, search, backup or restore.

- Keep unopened character archives unchanged when saving. Invalid, duplicate, oversized or unsupported saved records fail explicitly instead of disappearing silently.

- Previously consented eligible startup observations use a separate local recovery journal. Normal logout/reload preserves accepted observations and retries recovery without duplicating committed records.

- Startup capture is bounded at 1,024 observations or 512 KiB of structural capture data. Recovery IDs add bounded metadata. Overflow is reported in chat and a saved coverage gap.

- Startup coverage remains partial: movement, inspection, scoreboard snapshots and complete duel sessions are not fully captured during validation. Missing events are not reconstructed. WoW must save normally; a crash can lose unsaved observations.

- Loading reports 25/50/75/100% for the current character without needing Warden open. Unloaded history is shown as unavailable rather than confirmed zero.



## Dossiers and interface polish



- Player menus can open exact retained Intel dossiers and shared Chronicle history using a ready identity index. Saved personal notes and watchlist entries now qualify for Intel shortcuts even without historical encounter events.

- Ambiguous names and different realms do not substitute another player. Menu opening starts no inspection, history scan or disabled module.

- Larger module crests, consistent activity artwork, explicit ON/OFF badges, adaptive Olympus navigation and clearer settings improve the suite's readability.

- Search uses CommandWarden wording and includes its module choices and performance controls. Chat Capture defaults off; existing preferences are preserved.



## Back up your history



The supplied Windows backup tool creates or restores one complete backup ZIP while WoW is closed. It includes main history, Relay reports and pending startup recovery in the existing account SavedVariables file. Text export waits for pending recovery and all requested archives.



The addon folder remains `OlympusChatWarden`; main history schema and consent stay compatible. Before switching to an older build, finish pending recovery and make a complete backup. Older TOCs do not declare the new startup journal and may omit it on a later save. Use isolated copies for rollback testing.



Olympus remains required for permitted gameplay access. It is an optional load dependency intentionally, allowing Warden to show missing-Olympus/access guidance instead of being disabled silently by the client.



---



# 1.1.0



Olympus Warden suite release. Chronicle and Intel lead the sidebar; 50px sidebar

crests, 56px page crests and larger buttons retain existing module IDs/deep links.

Status aliases use the same current crest when on and off, with explicit badges,

paused dimming and aligned summaries. Home identity gets a taller banner; talent

names/ranks get full-height rows and complete bottom scrolling. RC5 scale, welcome,

privacy, source-return and history-preservation fixes are retained. No collection

or SavedVariables change since RC5. See RELEASE-NOTES.md for changes since 1.0.3.



# 1.1.0-rc5



Staged, reusable window-size editor; stable screen-safe sizing across navigation;

current six-module suite introduction; complete scrolling-document sizing;

distinct selection/unread styling; compact sparse Home highlights; grouped unknown

duel gear with an all-slots option; clearer settings and recording state labels.

All collectors, history, privacy scope, signed packs and backups are unchanged.



# 1.1.0-rc4



Shared UI readability/scaling, story-first dossiers, readable PvP/duel presentation, offline help, evidence return, consent/tour copy and isolated deletion warning. Collection and backups unchanged.



# 1.1.0-rc3



Conditional native reward/boss evidence, in-progress battleground observations, bounded durable failure summaries, and clearer configuration provenance. RC2 optimizations/history/consent retained.



# Olympus Warden 1.1.0-rc2



- Reuse unchanged profile metadata while preserving every latest observation time,

  source, changed fact, encounter episode and location.

- Maintain recent-player counts directly; retain the same 600-player transient cap.

- Reuse verified nameplate bindings with native-text fallback, GUID/generation and

  policy invalidation. Existing discovery frequency and protection remain intact.

- Avoid idle capture/evidence work; queued enrichment still wakes next frame.

- Defer spelling dictionary expansion until eligible input, retaining complete

  incoming known-word lookup and normal suggestions after first-use warmup.

- Extend optional aggregate profiling with function timings, call counts,

  UI-open/closed classification and honestly labelled heap samples.

- Add consent-gated bounded startup preservation for selected native payloads;

  explicitly mark partial coverage, overflow and unsupported startup periods.

- Preserve historical data, signed packs, backup compatibility and route accuracy.



Private candidate; actual Stormwind CPU/memory comparison and native gates pending.



# Olympus Warden 1.1.0-rc1



- Accelerate checksum validation using supported native rotate and three-input

  XOR operations; preserve identical hashes and signature verification.

- Use elapsed time rather than eight resumes as the main loading limit: a 4 ms

  soft target outside combat, 2 ms during combat, with bounded work per frame.

- Show checked/total chunks and progress; queue requested recording explanations

  until saved history finishes validation.

- Correct scroll offsets in offline screenshots; native list behavior is unchanged.

- Retain every historical record, profile, consent and chunked backup format.



Private candidate for live testing. Preview 9 login and reload/logout are confirmed

by the user; this candidate's live speed and remaining gameplay gates are pending.



# Olympus Warden 1.1.0-preview9



- Cooperatively load retained history and validate snapshot checksums without

  leaving one long login callback. Original data is committed only after validation.

- Distinguish loading, failed initialization, paused recording and inactive duels.

- Correct native Chronicle settings category/canvas argument order.

- Keep independent startup modules from stranding the suite after an error.

- Simplify duel and talent labels; restore small icons in offline previews.

- Preserve existing collectors, consent, saved format, signed packs and backups.



Internal beta. Successful native login and gameplay checks are still release gates.



# Olympus Warden 1.1.0-preview8



- Fix locale-dependent Unicode validation that could block intact saved history.

- Explain failed recording choices and keep failed duel opt-in prompts open.

- Discover supported native statistics cooperatively, preserving dated exact

  values and uncertainty without replacing historical encounters.

- Preserve native scoreboard objectives, metadata and partial coverage; limit

  final-score retries and reject observations after context changes.

- Retain confirmed NPC IDs and exact-unit creature metadata on native credits.

- Reuse unchanged personal PvP counters across recording restarts.

- Keep duel deduplication, chunked saving, consent, signed packs and backups.



Internal beta; native Statistics scope and score freshness require live testing.



# Olympus Warden 1.1.0-preview7



 Install over the existing **OlympusChatWarden** addon folder; keep

the folder name and SavedVariables. Back up before testing.



- **Optional duel history:** individual accepted duels, verified wins/losses and

  unknown results now appear in ChronicleWarden > Activities. Challenge requests

  are separate from accepted duels.

- **Duel Analysis:** compare both players’ available before/after equipment,

  recorded talents and dated evidence. Click a gear slot with your normal item

  modifier keys; use Recorded talents for selections and native export text.

- **Rival histories:** IntelWarden dossiers show verified head-to-head results,

  unknowns and recent duels. Shared activities opens the full linked history.

- **Smarter snapshots:** unchanged gear and talents reuse immutable content,

  including when a player returns to an earlier configuration. Observation dates

  and distinct duels remain separate. Missing slots never imply removed gear.

- **Historical gear gallery:** browse unique configurations and cycle their

  individual observation dates. Offline characters get a recorded identity card;

  a native live model still requires that exact GUID to be available.

- **Performance foundation retained:** cooperative indexes, chunked saving,

  bounded caches and `/warden perf start|status|stop` remain in place.





# Olympus Warden 1.1.0 preview 6



- Lower temporary memory use when loading large saved histories.

- Faster chunked saving without changing the saved format or evidence.

- Chronicle, Intel, search and equipment indexing now yield on a time budget as

  well as a record limit. The normal record limits remain the fallback.

- Intel reuses unchanged results and statistics instead of repeatedly building

  player lists. Empty lists create rows only when there is something to show.

- Closed pages release their results and skip queued refreshes. At most two

  character activity indexes are kept warm; older indexes rebuild when needed.

- Optional diagnostics: /warden perf start, then /warden perf status or

  /warden perf stop. Measurements stay in memory for the current login.



Replace the existing OlympusChatWarden folder; keep your saved file. History,

gear, talents, player relationships, notes, settings, signed packs and backups

are preserved. Schema 6, consent scope 5 and the chunked save format stay the same.

This build adds no new collection, automatic expiration or outgoing sharing.



The performance comparison uses synthetic Lua 5.1 fixtures, not live Forever

memory or FPS measurements. Large histories still require substantial memory.

The 2 ms work budget is a target: an individual operation or garbage collection

can take longer. Native gameplay, models and readable talents still need live

verification. See the separate Performance Report for numbers and limits.



# Archived: Olympus Warden 1.1.0 preview 5



- IntelWarden explains why a player is Important, an Activity participant, or a

  Casual observation. Repeated sightings do not automatically promote players.

- Dossiers show dated, GUID-linked PvP reports, including unavailable counters.

  Report refreshes are not added together or treated as unique matches.

- Compact Intel activity opens player dossiers. Chronicle highlights open the

  exact event or shared adventure, with a route back to the original evidence.

- Recent highlights use a cooperative index, so background records no longer

  push meaningful events out of the compact feed.

- Talents shows readable recorded choices, icons and ranks when the native

  inspection configuration supports them. Older exports remain available;

  reinspect to collect readable choices. The original export is always kept.

- Automatic inspections have a five-minute per-player backoff. Manual Inspect

  remains available. ShieldWarden now uses its own emblem throughout the page.



Replace the existing `OlympusChatWarden` folder and keep your saved file.

Recording must be enabled before collecting new inspections. Opening a dossier

does not request another inspection or enable recording.



Your live beta result confirms gear saves through reload, and the previous

Talents page retained a native export. Preview 5's readable choices, live models,

model controls, and Olympus navigation still need in-game verification.

There is no guessed offline appearance or talent tree. Player tiers describe

recorded relationships, not danger or certainty. Public Olympus-only records

remain external sources. Inspected honor and reputation remain unsupported.



History, schema 6, consent scope 5, signed packs, addon identity and complete-file

backups remain compatible. No inspection sweep or outgoing sharing was added.



# Archived: Olympus Warden 1.1.0 preview 4



- Native manual Inspect and existing automatic important-player inspections share GUID, ownership, readiness and cancellation checks.

- Completed manual inspections create an important-player interaction while recording, without implying combat participation or queuing another inspect.

- Native model is visible before SetUnit; optional keep-on-hide support remains guarded, and hides/target changes clear the model.

- IntelWarden Talents shows dated native exports, readable inspected specialization IDs, older builds and original evidence.

- Missing or invalid talent data stays unknown. No local-player talent fallback, unverified honor attribution or other-player reputation collection.

- Compact Olympus panel uses Warden/module crests, named status chips, five filters, timestamps, target access and recent meaningful recording events.

- New recording recents are a bounded local projection, with no new persistent feed, sounds or outgoing sharing.

- Existing folder, SavedVariables schema 6, consent scope 5, signed packs and complete-file backup tool stay compatible.



# Olympus Warden 1.1.0 preview 3



- Historical search results validate their saved position without scanning the full history on click.

- Older links without a position resolve cooperatively, with combat pause and cancellation when history or navigation changes.

- Gear slots use native icon fallbacks, bounded visible-item cache requests and deferred item-data refreshes.

- Standard modified item clicks preserve original recorded item payloads. Missing full links stay unavailable.

- Existing layout, collectors, consent and SavedVariables contracts retained.



# Olympus Warden 1.1.0 preview 2



- Refined bronze hierarchy, navy rows, contrast and small-icon padding.

- Separate Home statuses and navigable data statistics; dynamic character banner.

- Module-grouped search with names, dates, places and unavailable-source handling.

- Intel dossier Appearance & Gear: GUID-bound native model, controls and dated paper doll.

- Reused equipment evidence with older-loadout navigation and original references.

- Distinct Chronicle milestone icons and clearer adventure/roster details.

- Private notes and watchlist edits no longer require recording to be enabled.

- No new collectors, inspection requests, schema changes or outgoing sharing.



# Olympus Warden 1.1.0 preview 1



- New Warden umbrella brand, Zeus crest and five matching feature emblems.

- ChatWarden groups Messages, Capture, Rules, Packs and Reports.

- SignalWarden includes personal mentions, Wanted encounters and passive OlympusMute observations.

- ShieldWarden retains contact protection and allowed players.

- IntelWarden adds recently met players, saved profiles and private notes/watchlist.

- ChronicleWarden adds personal highlights, measured time and shared adventures.

- Home adds a data overview and local search across the suite.

- Existing addon identity, saved history, signed imports and backup contracts remain compatible.



# Olympus ChatWarden 1.0.3



Changes since 1.0.2.



- **Optional history recording:** Preserve your own travels, progress, equipment,

  important player encounters and permitted Olympus records. Recording starts

  only after you opt in. Your saved history stays on your computer.

- **Shared adventures:** Browse dungeon, raid and group segments, supported boss

  attempts and the original evidence behind them. A damage meter is not required.

- **Player histories:** Review recorded local encounters, native credit evidence,

  roster relationships, dated Olympus information and your own notes/watchlist.

- **Measured time and milestones:** See recorded time, AFK flags, activity and zone

  summaries, UTC calendar views, levels, quests, professions, deaths and exploration.

- **Battleground history:** Browse observed battleground/arena visits and preserved

  scoreboard observations. Uncertain match assignments and outcomes remain unknown.

- **A quieter event browser:** Events highlights meaningful changes and visible

  local Wanted encounters. Multiple filters, separate native action/background

  choices and All recorded data keep detailed history accessible. Large histories

  load in small steps.

- **Long-term retention and backups:** No automatic history expiry. Complete-file

  backups are recommended; the optional Windows tool makes one checked backup ZIP

  and keeps a safety copy before restoring. In-game text merge remains available.

- **Collection explanations and safeguards:** Click collection items to read what

  they save and their limits. Existing protection, Olympus access, saved settings,

  notes and earlier history remain supported.



Recording is separate from Chat Capture. It does not upload your history or

continuously track other players. Some preserved facts come from Olympus public

information. Native API availability varies; missing facts remain unknown.

Roster lists do not prove individual boss attendance. Native credits are not

solo victories, and a death does not identify its killer. The full Chronicle

visual experience, reliable performance matching and shared intelligence are

future work.



# 1.0.2



- Preserve original 1.0.1 and 1.0.0 update pages with Previous/Next navigation.

- Refresh the Updates screen with all six highlights since 1.0.1, keeping the Launch Tour and User Guide separate.



- Aligned the gold edges of the Zeus artwork with the panel trim; selected titles retain a smaller, aligned ornament.

- Corrected compact icon atlas fitting, tightened toggle spacing and marked compact selections read.

- Added the native Olympus panel and authoritative permission/membership checks.

- Reduced the compact header and controls; three complete recent entries fit the stock viewport.

- Renamed Mentions to Alerts, with independent Mentions and Wanted views/settings and a shared pause switch.

- Added Wanted encounter alerts and quiet chat icons with current bounty details on hover. Chat names never create Wanted notifications.

- Show actual guild rank alone; hide an unavailable Title row. Keep connection status in the full header.

- Updated the guide, tour and patch highlights. Existing packs and filtering policy are unchanged.





# 1.0.1



- Context filtering, first-name Mentions, clearer optional pack names and a larger WoW spelling vocabulary.

- Saved settings and history are retained.





# 1.0.0



- Adopt launch defaults; Gommage/Capture off, core protection and Mentions on.

- Split Hidden/Redacted alerts; context handling always active.

- Lower dumb criticism to Balanced warning; sign USA Protection v5.

- Fix reported conditional-question false positive; use bronze redaction bars.

- Preserve earlier icon, name, feed and persistence fixes.

