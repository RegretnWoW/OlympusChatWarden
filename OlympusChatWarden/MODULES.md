# Module independence audit and implementation contract — 1.1.1

Baseline lifecycle: private 1.1.1-preview2. Preview 4 hardening is recorded below.

| Producer / service | Existing consumers | Boundary and required change |
| --- | --- | --- |
| Core `ns.Active` and `DB.enabled` | Chat, Shield, alerts, historical recording | Accidental global dependency. Preserve the saved filtering pause; give Shield, alerts and recording their own module gates. |
| Chat filter and ChatReports | Shield.FilterChat, Mentions.Observe, Capture, manual report menu | Synchronous filtering decisions stay synchronous. Publish observed/displayed events to optional alert/capture subscribers; retain minimal manual-report evidence without running disabled classifiers. |
| Shield identity helpers | Virtually every module, including Relay receiver checks | Essential stateless identity service. Retain helpers without starting Shield enforcement, timers or contact caches. |
| Shield and Spam | Chat filter, contact events, Activity | Independent contact protection stays available with Chat off. Wording classifications require Chat. Stop request handlers and discard pending enforcement on disable. Never publish a block that did not happen. |
| Mentions, Wanted, OlympusMuteSignal | Activity, toasts, tooltips, chat decoration | Optional Signal alerts. No optional monitoring or alert processing when disabled. Essential manual reporting and the Core router remain accessible. No new outbound Signal traffic. |
| Relay store/transport | Report UI, native addon whispers | Essential support. Preserve submitted retry schedules, identity checks and privacy. UI remains lazy; no module change transmits a draft. |
| Chronicle evidence host / store | Chronicle, Intel, backup viewer | Shared consented evidence substrate, not an instruction to enable Chronicle. Load retained history only for an enabled historical consumer or an explicit Relay data/backup operation. Keep original archive untouched when unused. |
| Personal route, time, progression, statistics | Chronicle | Chronicle-only work; stop subscriptions, checkpoints and queues when off. |
| Player observations, inspection, personal dossiers | Intel | Intel-only work; no new dossiers, inspection queue or model work when off. Chronicle retains identity/context needed by its own recorded shared activities. |
| Shared rosters, encounters, combat/duel evidence, configurations | Chronicle and Intel | Required shared evidence, subject to existing recording and duel consent. Select appropriate collectors per consumer. Intel-only must not start personal routes, quest or lifetime-statistic collectors. |
| Activities projection | Chronicle, Intel, Home, compact panel | Bounded reconstructible projection. Gate consumers, cancel jobs and release caches on scope changes. Do not start indexes merely to fill disabled dashboard cards. |
| Dossier projection / native model | Intel, search deep links | Intel capability required. Hide/clear model and temporary caches on disable; retain saved notes, watchlists and evidence. |
| RulePacks / matcher / spelling | Chat, reports, typo filtering | Keep author verification unchanged. Delay matcher restoration and spelling expansion for disabled Chat; never replace signed vocabulary. |
| Workspace, search, Olympus panel | All modules | Adaptive routes/navigation; disabled destinations redirect to Modules & Performance. Skip disabled sources and UI construction. Relay data recovery stays available. |

## Lifecycle and preservation

Requested selection and runtime state are distinct. Optional frames are owned,
unregistered and have update callbacks detached while inactive. Stable identity,
permission, report and backup services remain reachable. Disable clears disposable
work and pending enforcement, never historical data or consent. Re-enable may
rebuild indexes cooperatively; it never replays old enforcement. Combat-sensitive
presentation changes wait until safe. Failures are isolated and reported locally.

New installations start with Chat selected and show module selection. Existing
installations migrate their prior effective choices without onboarding or enabling
recording. Module selection is not collection consent. Full Suite retains the
baseline feature set. No new collectors, network protocol or storage migration is
part of this pass.

Native frame timing, memory and gameplay remain separate validation requirements.
SavedVariables and loaded Lua source cannot be unloaded; no unmeasured RAM-saving
percentage is promised. Disabled archives remain backed up in the original file.

## Preview 4 safety follow-up

- CommandWarden is the always-accessible UI for Overview, Modules, Performance
  and shared Settings. Chat-only navigation keeps Command, Chat and Relay.
- Startup preservation uses selected historical scopes, existing consent and
  membership rather than Chat's filtering pause. Intel-only startup excludes
  personal quest and achievement payloads while preserving shared encounter facts.
- Workspace.Open returns destination success and its page; Destination refuses
  stale/redirected pages. Cold and previously opened disabled links are tested.
  Search jobs drop old references when the module revision changes.
- New/copied/switched report reviews explicitly exclude diagnostic attachments.
  Structured display changes neither frozen wire payloads nor native transport.
- Cleanup clears only unused caches. Active dictionaries and protection counters
  are preserved. Chat's covered native display cleanup waits for combat to end;
  optional processing stops immediately, and pending presentation is labeled.
- Legacy configured selections survive migration separately from the old global
  pause. An explicit resume is required before those paused historical/protection
  selections run. Preview 3's already-saved explicit selections are honored.
- The history validation worker is independent of workspace visibility and is
  explicitly shown. RunAlways is used only if the native method and enum exist.
  Quarter messages derive from validated saved chunks; 100% requires success.
  Client suspension/throttling is not overridden. Timings stay session-only.

## Signal Core limits

The router is local and synchronous: 32 topics, 16 handlers per topic, 64 total
handlers and eight nested dispatches. Subscribers have module owners and stable
keys. Eligibility is checked at delivery, errors are isolated, and temporary
dispatch buffers release payload references. It has no persistent event queue,
presence probes, network protocol or new automatic sharing.

## Dependency details and rollback

Preview 5 retains `OptionalDeps: Olympus` for load ordering. Existing Olympus API
permission and membership gates remain required for normal protected workflows.
Changing this to a hard dependency would also prevent Core/Relay initialization
and local recovery access whenever Olympus is missing or disabled. The existing
legacy connection/fallback paths have not been removed. Native dependency-screen
behavior has not been tested, so the review suggestion is deferred rather than
silently changing this startup contract in a routing/polish patch.

Chronicle retains participant identity and combat context needed to describe the
player's own adventures. Intel is required for player dossiers and deliberate or
automatic important-player inspection; selecting Chronicle alone does not silently
enable Intel. Shared gear/duel evidence still uses the existing consent boundaries.
Shield contact/repetition protection works without Chat; its optional wording
classification needs Chat. Essential legacy nameplate-CVar recovery stays in Core.

The source files remain loaded by the existing TOC. Disabling releases work and
reconstructible runtime structures, not all memory. Explicit Data & Backups can
load an archive even with both historical modules off, without starting collection.
History loaded during a session still uses chunked saving when logging out with
the modules disabled. A cold unopened archive is left untouched.

Back up the complete account save before upgrading and before rollback. Preview 2
ignores module selection and resumes its previous full-suite behavior. Published
1.1.0 does not declare the Relay saved variable; keep a post-test full-file backup
to preserve reports when changing back. Do not restore while WoW is open.
