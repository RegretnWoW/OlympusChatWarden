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
